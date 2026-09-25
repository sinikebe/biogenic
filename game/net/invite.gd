extends RefCounted
## **The invite: one line that lets a friend outside the house into the
## dedicated server's pond** (docs/design/net-hardening.md, part C).
##
## The owner mints one per friend on the server (`game/server/invite_book.gd`)
## and sends it in any messaging app; the friend pastes it once, and it is kept
## in `user://` from then on. It carries everything the call needs and nothing
## a stranger could use without it:
##
##   - **where to call**: the address and port the owner said friends dial
##     (`--reach`), which is the owner's, typed on the server and never in the
##     repository;
##   - **who will answer**: the server's certificate, whole. The call pins it
##     (`TLSOptions.client(certificate, NAME)`), so the server is proven from
##     the first packet, not trusted on first contact -- a man in the middle
##     has no key for it;
##   - **who is calling**: a key id and a 128-bit secret, this friend's alone.
##     The secret never crosses the wire: the guest proves it holds it with an
##     HMAC over two fresh nonces ([method proof_mac]).
##
## **The line**, as a messaging app will carry it:
##
##     biogenic-invite:<version>.<payload in base64>.<check>
##
## `<check>` is eight hex characters of SHA-256 over `<version>.<payload>`, so
## a paste cut short or garbled on the way is caught here, before any call, and
## never costs a refused proof and a barred address. **That envelope is frozen
## for good**: a later format changes the version and the payload and nothing
## else, so this build can always tell a newer invite from a damaged one and
## say which ([enum Read]).
##
## **Pasted, never typed**: lan.gd's reasons for having no text field still
## hold, and `DisplayServer.clipboard_get()` works on Android and Windows.
## Whatever a messaging app does to a long line -- breaks it, pads it with
## spaces or invisible joiners, wraps it in a sentence -- [method parse] reads
## through, and it finds the invite by its prefix wherever it sits.
##
## **Every sentence a player is shown about an internet call is here**, in
## [constant SAYS], so the screens' final wording goes in one place.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Wire := preload("res://game/net/wire.gd")

const PREFIX := "biogenic-invite:"
## **The one format this build writes and reads.** Anything else that checks
## out is a newer build's invite: [constant Read.UNKNOWN_VERSION].
const VERSION := 1
## **The internet listener's port**: the one port an owner forwards, next to
## the LAN's `Lan.PORT`, 45771, which stays unforwarded. The port in an invite
## is the one friends *dial*, which a router may map onto this one.
const PORT := 45772
## **The server certificate's fixed name.** Every server's certificate is
## self-signed with this name, and the call checks it
## (`TLSOptions.client(pinned, NAME)`): the pin is the certificate itself, and
## the name is a second, free check that it was minted for this game.
const NAME := "biogenic-pond"
## What the proof's HMAC is over, first: so a mac made for this cannot be
## replayed as anything else, and a later proof can change what follows it.
const DOMAIN := "biogenic proof 1"
const KEY_ID_SIZE := Wire.KEY_ID_SIZE
const SECRET_SIZE := 16
const CHECK_CHARS := 8
## A paste longer than this is not an invite and a message around one; nothing
## past it is read.
const PASTE_MAX := 65536
## `rw-------`: every file here that holds a secret.
const PRIVATE := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
## `rwx------`: the directory the owner's invite lines are written to.
const PRIVATE_DIR := PRIVATE | FileAccess.UNIX_EXECUTE_OWNER
## **Where a guest keeps the invite it was given.** One: a phone joins one
## friend's server.
const KEPT := "user://invite.txt"

## **What [method parse] made of a paste.** Each has its own sentence in
## [constant SAYS], so the screen can say what to do about it.
enum Read {
	## An invite this build can call with.
	OK,
	## No `biogenic-invite:` anywhere in it.
	NOT_FOUND,
	## One was there, but not whole: cut short, a character changed, or a
	## check that does not match.
	DAMAGED,
	## Whole, and made by a newer build than this one.
	UNKNOWN_VERSION,
}

## **Every sentence a player is shown about an invite or an internet call**:
## `[heading, what to do]`, in the house style -- lowercase, the fix named, no
## word a player would have to look up. Placeholders until the screens' spec
## (docs/design/invites-ux.md) gives the final wording; nothing else holds one.
const SAYS := {
	# Pasting.
	&"not_found": ["no invite there",
		"copy the whole invite your friend sent, then paste it here."],
	&"damaged": ["that invite is damaged",
		"part of it went missing on the way. ask your friend to send it again,"
			+ " and copy all of it."],
	&"unknown_version": ["that invite is newer than this game",
		"take the update from the launcher, restart, and paste it again."],
	# Calling.
	&"no_invite": ["no invite yet",
		"paste the invite your friend sent first."],
	&"could_not_call": ["could not call",
		"this device could not open a call. check it is online, then try again."],
	&"no_such_place": ["nowhere by that name",
		"the address in that invite does not lead anywhere right now. check this"
			+ " device is online, then call again."],
	&"no_answer": ["no answer",
		"their pond did not answer. check it is running and this device is"
			+ " online, then call again."],
	&"not_running": ["no pond there",
		"their address answered, but no pond is listening. ask your friend to"
			+ " check it is running, then call again."],
	&"not_this_pond": ["not their pond",
		"a different pond answered at that address. ask your friend for a new"
			+ " invite."],
	&"invite_refused": ["that invite no longer works",
		"it was taken back or replaced. ask your friend for a new one, then call"
			+ " again in a minute."],
}


## `[heading, sentence]` for [param key] in [constant SAYS].
static func says(key: StringName) -> Array:
	return SAYS.get(key, SAYS[&"no_answer"])


## `[heading, sentence]` for what [method parse] said, or empty for [constant
## Read.OK].
static func says_read(read: int) -> Array:
	match read:
		Read.NOT_FOUND:
			return says(&"not_found")
		Read.DAMAGED:
			return says(&"damaged")
		Read.UNKNOWN_VERSION:
			return says(&"unknown_version")
	return []


# ---------------------------------------------------------------------------
# The line.
# ---------------------------------------------------------------------------

## **One invite, as one line.** [param der] is the server certificate in DER,
## [param key_id] and [param secret] this friend's. `""` for anything that
## would not read back: an address no call can use, or pieces of the wrong
## size.
static func format(address: String, port: int, key_id: PackedByteArray,
		secret: PackedByteArray, der: PackedByteArray) -> String:
	if not address_ok(address) or port < 1 or port > 65535 \
			or key_id.size() != KEY_ID_SIZE or secret.size() != SECRET_SIZE \
			or der.is_empty() or der.size() > 0xFFFF:
		return ""
	var payload := PackedByteArray()
	payload.append_array(key_id)
	payload.append_array(secret)
	payload.append(port & 0xFF)
	payload.append((port >> 8) & 0xFF)
	var host := address.to_ascii_buffer()
	payload.append(host.size())
	payload.append_array(host)
	payload.append(der.size() & 0xFF)
	payload.append((der.size() >> 8) & 0xFF)
	payload.append_array(der)
	var inner := "%d.%s" % [VERSION, Marshalls.raw_to_base64(payload)]
	return PREFIX + inner + "." + _check_of(inner)


## **Whatever was pasted, read.** Always a Dictionary with `read`, one of
## [enum Read]. On [constant Read.OK] it also has `address`, `port`, `key_id`,
## `secret`, `der`, `certificate` (an `X509Certificate`) and `line`, the
## invite written out clean -- what [method keep] stores.
##
## Everything a messaging app might have put inside it goes first -- spaces,
## line breaks, tabs, and the invisible joiners and no-break spaces some insert
## to wrap a long word -- and then every `biogenic-invite:` in what is left is
## tried in turn: the first that reads whole wins. A message around it, before
## or after, is never read. If none reads, the answer is the most useful
## failure seen: a newer version over damage, damage over nothing.
static func parse(text: String) -> Dictionary:
	var flat := _squeeze(text.substr(0, PASTE_MAX))
	var lower := flat.to_lower()
	var best := Read.NOT_FOUND
	var from := 0
	while true:
		var at := lower.find(PREFIX, from)
		if at < 0:
			break
		var got := _read_at(flat, at + PREFIX.length())
		if int(got["read"]) == Read.OK:
			return got
		if int(got["read"]) == Read.UNKNOWN_VERSION or best == Read.NOT_FOUND:
			best = int(got["read"])
		from = at + 1
	return {"read": best}


## One invite read from [param at], just past its prefix, in [param flat],
## which has had everything invisible taken out.
static func _read_at(flat: String, at: int) -> Dictionary:
	var damaged := {"read": Read.DAMAGED}
	var n := flat.length()
	var i := at
	while i < n and i - at < 4 and _is_digit(flat.unicode_at(i)):
		i += 1
	if i == at or i >= n or flat[i] != ".":
		return damaged
	var version_text := flat.substr(at, i - at)
	var body_at := i + 1
	var j := body_at
	while j < n and _is_base64(flat.unicode_at(j)):
		j += 1
	if j == body_at or j >= n or flat[j] != "." or j + 1 + CHECK_CHARS > n:
		return damaged
	var inner := version_text + "." + flat.substr(body_at, j - body_at)
	# **The check first**, over the version too: a garbled version digit is
	# damage, not a newer build.
	if flat.substr(j + 1, CHECK_CHARS).to_lower() != _check_of(inner):
		return damaged
	if int(version_text) != VERSION:
		return {"read": Read.UNKNOWN_VERSION}
	var payload := Marshalls.base64_to_raw(flat.substr(body_at, j - body_at))
	var fixed := KEY_ID_SIZE + SECRET_SIZE + 2 + 1
	if payload.size() < fixed:
		return damaged
	var key_id := payload.slice(0, KEY_ID_SIZE)
	var secret := payload.slice(KEY_ID_SIZE, KEY_ID_SIZE + SECRET_SIZE)
	var k := KEY_ID_SIZE + SECRET_SIZE
	var port: int = payload[k] | (payload[k + 1] << 8)
	var host_size: int = payload[k + 2]
	k += 3
	if payload.size() < k + host_size + 2:
		return damaged
	var address := payload.slice(k, k + host_size).get_string_from_ascii()
	k += host_size
	var der_size: int = payload[k] | (payload[k + 1] << 8)
	k += 2
	if payload.size() != k + der_size or der_size == 0 or port < 1 \
			or address.length() != host_size or not address_ok(address):
		return damaged
	var der := payload.slice(k)
	var certificate := certificate_of(der)
	if certificate == null:
		return damaged
	return {"read": Read.OK, "version": VERSION, "address": address, "port": port,
		"key_id": key_id, "secret": secret, "der": der, "certificate": certificate,
		"line": PREFIX + inner + "." + _check_of(inner)}


static func _check_of(inner: String) -> String:
	return inner.sha256_text().substr(0, CHECK_CHARS)


## **What a messaging app may have put inside a line**, taken out: ASCII
## controls and space, DEL and the C1 controls, the no-break and soft-hyphen
## characters, every Unicode space and zero-width character, the line and
## paragraph separators, the bidirectional marks, and the byte-order mark.
static func _squeeze(text: String) -> String:
	var out := PackedStringArray()
	for i in text.length():
		var c := text.unicode_at(i)
		if c <= 0x20 or (c >= 0x7F and c <= 0xA0) or c == 0xAD or c == 0x1680 \
				or c == 0x180E or (c >= 0x2000 and c <= 0x200F) \
				or (c >= 0x2028 and c <= 0x202F) or (c >= 0x205F and c <= 0x206F) \
				or c == 0x3000 or c == 0xFEFF:
			continue
		out.append(String.chr(c))
	return "".join(out)


static func _is_digit(c: int) -> bool:
	return c >= 48 and c <= 57


## Standard base64 -- `A-Z a-z 0-9 + / =` -- and not base64url, because `_` is
## italics in several messaging apps and would not survive being shown.
static func _is_base64(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or _is_digit(c) \
		or c == 43 or c == 47 or c == 61


# ---------------------------------------------------------------------------
# The certificate, as the line carries it.
# ---------------------------------------------------------------------------

## A certificate from its DER bytes, or null. Built through PEM, which is what
## `X509Certificate` reads from memory.
static func certificate_of(der: PackedByteArray) -> X509Certificate:
	if der.is_empty():
		return null
	var b64 := Marshalls.raw_to_base64(der)
	var lines := PackedStringArray()
	for at in range(0, b64.length(), 64):
		lines.append(b64.substr(at, 64))
	var certificate := X509Certificate.new()
	if certificate.load_from_string("-----BEGIN CERTIFICATE-----\n" + "\n".join(lines)
			+ "\n-----END CERTIFICATE-----\n") != OK:
		return null
	return certificate


## **The DER bytes inside a PEM certificate**, or empty. Read from a file the
## server wrote with `X509Certificate.save()`: `save_to_string()` would do, but
## hands back its buffer's closing NUL and prints a Unicode warning for it
## every time -- measured on 4.7-stable.
static func der_of_pem(pem: String) -> PackedByteArray:
	var body := pem.get_slice("-----BEGIN CERTIFICATE-----", 1) \
		.get_slice("-----END CERTIFICATE-----", 0)
	var b64 := PackedStringArray()
	for i in body.length():
		var c := body.unicode_at(i)
		if _is_base64(c):
			b64.append(String.chr(c))
	if b64.is_empty():
		return PackedByteArray()
	return Marshalls.base64_to_raw("".join(b64))


# ---------------------------------------------------------------------------
# The proof.
# ---------------------------------------------------------------------------

## **The mac a guest proves an invite with, and a host checks it against**:
## HMAC-SHA256, keyed with the invite's [param secret], over [constant DOMAIN],
## the [param protocol] (two bytes, little-endian, like the handshake's),
## the host's nonce, the guest's, and the [param key_id]. Every piece is a
## fixed size, so no two different sets of them are ever the same message.
static func proof_mac(secret: PackedByteArray, protocol: int,
		host_nonce: PackedByteArray, guest_nonce: PackedByteArray,
		key_id: PackedByteArray) -> PackedByteArray:
	if secret.is_empty():
		return PackedByteArray()
	var message := DOMAIN.to_ascii_buffer()
	message.append(protocol & 0xFF)
	message.append((protocol >> 8) & 0xFF)
	message.append_array(host_nonce)
	message.append_array(guest_nonce)
	message.append_array(key_id)
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, secret, message)


# ---------------------------------------------------------------------------
# Where friends call: an address a line can carry.
# ---------------------------------------------------------------------------

## True for an address a call can dial: an IP literal, IPv4 or IPv6 -- with no
## zone, which names an adapter on the owner's machine and nothing a friend has
## -- or a host name of 1-253 characters in labels of 1-63 letters, digits and
## inner hyphens.
static func address_ok(address: String) -> bool:
	if address.is_empty() or address.length() > 253 or address.contains("%"):
		return false
	if address.is_valid_ip_address():
		return true
	if address.contains(":"):
		return false
	for label: String in address.split("."):
		if label.is_empty() or label.length() > 63 or label.begins_with("-") \
				or label.ends_with("-"):
			return false
		for i in label.length():
			var c := label.unicode_at(i)
			if not (_is_digit(c) or (c >= 97 and c <= 122) or (c >= 65 and c <= 90)
					or c == 45):
				return false
	return true


## **`--reach`, read**: `host`, `host:port`, `[v6]` or `[v6]:port`; a bare
## IPv6 address is taken whole, with the default port. A host name is
## lowercased and loses a trailing dot. `{"address", "port"}`, or
## `{"error": sentence}`.
static func parse_reach(text: String) -> Dictionary:
	var t := text.strip_edges()
	var host := t
	var port := PORT
	if t.begins_with("["):
		var close := t.find("]")
		if close < 0:
			return {"error": "an IPv6 address in brackets needs its closing bracket"}
		host = t.substr(1, close - 1)
		var rest := t.substr(close + 1)
		if not rest.is_empty():
			if not rest.begins_with(":") or not rest.substr(1).is_valid_int():
				return {"error": "after ] comes :port, or nothing"}
			port = int(rest.substr(1))
	elif t.count(":") == 1:
		host = t.get_slice(":", 0)
		var number := t.get_slice(":", 1)
		if not number.is_valid_int():
			return {"error": "the port after : must be a number"}
		port = int(number)
	if not host.is_valid_ip_address():
		host = host.to_lower().trim_suffix(".")
	if port < 1 or port > 65535:
		return {"error": "a port is a number from 1 to 65535"}
	if not address_ok(host):
		return {"error": "%s is not an address or a host name" % host}
	return {"address": host, "port": port}


## `host:port`, or `[v6]:port`: how an address is written back to the owner.
static func reach_text(address: String, port: int) -> String:
	if address.contains(":"):
		return "[%s]:%d" % [address, port]
	return "%s:%d" % [address, port]


# ---------------------------------------------------------------------------
# **The guest's invite**, kept once pasted.
# ---------------------------------------------------------------------------

## **Keep [param invite]** -- what [method parse] returned, or a line -- where
## [method kept] finds it, readable by this user alone. False if it does not
## read, or cannot be written.
static func keep(invite: Variant, path: String = KEPT) -> bool:
	var read: Dictionary = {}
	if invite is String:
		read = parse(invite)
	elif invite is Dictionary:
		read = invite
	if int(read.get("read", Read.NOT_FOUND)) != Read.OK:
		return false
	return write_private(path, (str(read["line"]) + "\n").to_utf8_buffer()) == OK


## The invite kept here, read -- `read` is [constant Read.OK] -- or an empty
## Dictionary for none, or one that no longer reads.
static func kept(path: String = KEPT) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var read := parse(FileAccess.get_file_as_string(path))
	return read if int(read["read"]) == Read.OK else {}


static func forget(path: String = KEPT) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# ---------------------------------------------------------------------------
# Files only their owner may read.
# ---------------------------------------------------------------------------

## **[param data] into [param path], `rw-------` before a byte of it lands.**
## Made empty first and closed, so what the permission is set on holds
## nothing yet -- `FileAccess` may write through a temporary file of its own,
## and it takes that file's mode from the one it replaces -- then filled in
## place, which creates nothing, and renamed over [param path] in one step, so
## a reader sees the old file or the new one and never half of either. Where
## there are no Unix permissions (Windows), the rest still holds.
static func write_private(path: String, data: PackedByteArray) -> Error:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	var fresh := path + ".new"
	var empty := FileAccess.open(fresh, FileAccess.WRITE)
	if empty == null:
		return FileAccess.get_open_error()
	empty.close()
	var mode := FileAccess.set_unix_permissions(fresh, PRIVATE)
	if mode != OK and mode != ERR_UNAVAILABLE:
		DirAccess.remove_absolute(fresh)
		return mode
	var file := FileAccess.open(fresh, FileAccess.READ_WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(data)
	file.close()
	return DirAccess.rename_absolute(fresh, path)


## [param dir], made if it is not there, `rwx------`.
static func make_private_dir(dir: String) -> Error:
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	var mode := FileAccess.set_unix_permissions(dir, PRIVATE_DIR)
	return OK if mode == ERR_UNAVAILABLE else mode
