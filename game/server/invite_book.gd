extends RefCounted
## **The dedicated server's invites** (docs/design/net-hardening.md, part C;
## docs/server.md, "Internet play"): its key and certificate, one secret per
## friend, the lines to send them, and the command-line jobs that look after
## all of it.
##
## **Where it all lives**, under `user://` -- which for the service is
## `/var/lib/biogenic/.local/share/godot/app_userdata/Biogenic`, never the
## repository:
##
##   - `pond/key.pem`, the server's RSA-2048 key, `rw-------`;
##   - `pond/cert.pem`, its self-signed certificate, named `biogenic-pond`,
##     which every invite carries whole;
##   - `pond/invites.cfg`, **the book**: one section per friend's label, with
##     its key id, its secret and when it was made, `rw-------`. Only the
##     command line writes it;
##   - `pond/joined.cfg`, when each invite last came in. Only the running server
##     writes it, so the two never write one file;
##   - `pond/reach.cfg`, the address friends dial (`--reach`);
##   - `invites/<label>.txt`, the line to send, `rw-------`, in a directory
##     that is `rwx------`.
##
## **Nothing here prints a secret.** A mint says where the line was written and
## nothing else about it; `--invites` lists labels and dates.
##
## Every function takes the directory to work under, so `tools/net_probe.gd`
## runs a book of its own beside a real one.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Invite := preload("res://game/net/invite.gd")
const Lan := preload("res://game/net/lan.gd")

const ROOT := "user://"
## **Valid from 2020 to 2099, whatever today is.** mbedTLS checks both dates
## against the device's clock -- measured on 4.7-stable: a certificate that
## starts in 2090, and one that ended in 2021, both fail the pin -- so a phone
## whose clock is years out still reaches its friend's pond. The pin is the
## certificate itself; the dates protect nothing here.
const VALID_FROM := "20200101000000"
const VALID_TO := "20991231235959"
## `biogenic-pond`: [constant Invite.NAME], which the call checks.
const SUBJECT := "CN=" + Invite.NAME
const KEY_BITS := 2048
## A label names a friend: 1 to 24 of `a-z 0-9 - _`, so it is also a file name
## that needs no quoting.
const LABEL_MAX := 24
## The jobs, after `--`. Each does what it says and exits, without hosting,
## without the updater and without binding a port.
const JOBS := ["--reach=", "--new-key", "--revoke=", "--invite=", "--invites"]


## Every path under [param root].
static func paths(root: String = ROOT) -> Dictionary:
	var pond := root.path_join("pond")
	return {"pond": pond, "key": pond.path_join("key.pem"),
		"cert": pond.path_join("cert.pem"), "book": pond.path_join("invites.cfg"),
		"joined": pond.path_join("joined.cfg"), "reach": pond.path_join("reach.cfg"),
		"lines": root.path_join("invites")}


## The file a label's line is written to.
static func line_path(label: String, root: String = ROOT) -> String:
	return str(paths(root)["lines"]).path_join(label + ".txt")


## **True when [param args] asks for one of the jobs** rather than a server.
static func is_job(args: PackedStringArray) -> bool:
	for arg: String in args:
		for job: String in JOBS:
			if arg == job or (job.ends_with("=") and arg.begins_with(job)):
				return true
	return false


## **Every job [param args] asks for, in a sensible order** -- the address
## first, then a new key, then revoking, then minting, then the list -- as
## `[exit code, lines to print]`. 0 when every job did what it was asked, 1 when
## one was refused; each refusal is a sentence that names the fix.
##
## **Run as root into another user's files, none of them runs**
## ([method ownership_refusal]): what root writes there is root's, `rw-------`,
## and a server running as the service's user could not read it -- measured in
## review, a revoke so written was never seen, and the friend swam on. Root's
## own `user://` is its own business, and gets a note.
static func run(args: PackedStringArray, root: String = ROOT) -> Array:
	var lines: PackedStringArray = []
	var code := 0
	var whose := owners(root)
	var refusal := ownership_refusal(int(whose["uid"]), whose["owners"], args,
		OS.get_executable_path(), OS.get_environment("HOME"))
	if not refusal.is_empty():
		return [1, [refusal]]
	if int(whose["uid"]) == 0 or (int(whose["uid"]) < 0 and OS.get_environment("USER") == "root"):
		lines.append("note: this runs as root, so it keeps root's own book, in %s, which the"
			% _real(root).trim_suffix("/") + " service never reads. For the service's, run the"
			+ " job as its user: runuser -u biogenic -- env HOME=/var/lib/biogenic"
			+ " /opt/biogenic/biogenic-server.x86_64 --headless -- <job> (docs/server.md §9.1)")
	for job: String in JOBS:
		for arg: String in args:
			if not (arg == job or (job.ends_with("=") and arg.begins_with(job))):
				continue
			var got: Array = [0, []]
			match job:
				"--reach=":
					got = set_reach(arg.trim_prefix(job), root)
				"--new-key":
					got = new_key(root)
				"--revoke=":
					got = revoke(arg.trim_prefix(job), root)
				"--invite=":
					got = mint(arg.trim_prefix(job), root)
				"--invites":
					got = listing(root)
			if int(got[0]) != 0:
				code = 1
			for said: String in got[1]:
				# Two jobs can warn the same thing -- a --reach inside the house,
				# then the --invite that calls it -- and once is enough.
				if not lines.has(said):
					lines.append(said)
	return [code, lines]


## **Who runs this, and who owns what a job would write**: `{uid, owners}`,
## `uid` from `id -u` (-1 where there is none to ask: not Linux, or it failed)
## and `owners` each path that exists -- the book, `pond/`, `invites/`,
## `user://`, the directory it sits in, and `$HOME` -- as `[uid, name]`, from
## one `stat`, which only root is asked for. One process for anybody else, two
## for root -- about 6-17 ms here -- once per job run, and never by a running
## server.
static func owners(root: String = ROOT) -> Dictionary:
	var out := {"uid": -1, "owners": {}}
	if OS.get_name() != "Linux":
		return out
	var said: Array = []
	if OS.execute("id", ["-u"], said) != 0 or said.is_empty() \
			or not str(said[0]).strip_edges().is_valid_int():
		return out
	out["uid"] = int(str(said[0]).strip_edges())
	if int(out["uid"]) != 0:
		return out
	var where := paths(root)
	var dir := _real(root).trim_suffix("/")
	var looked: PackedStringArray = []
	for each: String in [_real(str(where["book"])), _real(str(where["pond"])),
			_real(str(where["lines"])), dir, dir.get_base_dir(), OS.get_environment("HOME")]:
		if each.is_empty() or looked.has(each):
			continue
		if FileAccess.file_exists(each) or DirAccess.dir_exists_absolute(each):
			looked.append(each)
	said = []
	if looked.is_empty():
		return out
	# Each line names its path, so one that went between the look and the
	# `stat` -- which then exits 1 -- costs only its own line.
	OS.execute("stat", PackedStringArray(["-c", "%u %U %n"]) + looked, said)
	for row: String in (str(said[0]) if not said.is_empty() else "").split("\n", false):
		var parts := row.split(" ", false, 2)
		if parts.size() == 3 and parts[0].is_valid_int() and looked.has(parts[2]):
			(out["owners"] as Dictionary)[parts[2]] = [int(parts[0]), parts[1]]
	return out


## **The refusal for a job root would run into another user's files**, or ""
## to go on. [param uid] is who runs it (0 is root; -1 unknown), [param found]
## what [method owners] found, and [param args], [param exe] and [param home]
## what the sentence gives back as the command to run instead -- as the owner
## of what it found, with the same home, which is how docs/server.md §9.1 says
## to run every job.
static func ownership_refusal(uid: int, found: Dictionary, args: PackedStringArray,
		exe: String, home: String) -> String:
	if uid != 0:
		return ""
	for path: String in found.keys():
		var owner: Array = found[path]
		if int(owner[0]) == 0:
			continue
		var name := str(owner[1])
		return ("refused: this runs as root, but %s belongs to %s, and %s could not read"
			% [path, name, name] + " what root wrote there -- a revoke the server would"
			+ " never see. Run it as %s: runuser -u %s -- env HOME=%s %s --headless -- %s"
			% [name, name, home, exe, " ".join(args)] + " (or sudo -u %s, the same way;"
			% name + " docs/server.md §9.1)")
	return ""


# ---------------------------------------------------------------------------
# The jobs. Each returns `[exit code, lines]`.
# ---------------------------------------------------------------------------

## `--reach=<host>[:<port>]`: the address friends dial, as the owner types it:
## a public address, or a name that leads to one, and the port the router
## forwards to [constant Invite.PORT] -- that port unless it says otherwise.
static func set_reach(text: String, root: String = ROOT) -> Array:
	var said := Invite.parse_reach(text)
	if said.has("error"):
		return [1, ["--reach: %s. For example --reach=203.0.113.7 or" % said["error"]
			+ " --reach=pond.example.net:45772 (both placeholders)."]]
	var before := reach(root)
	# `pond/` made `rwx------` now, when `--reach` is the first job: the key
	# and the book will go in it, and a directory made in passing is `rwxr-xr-x`.
	var made := Invite.make_private_dir(str(paths(root)["pond"]))
	if made != OK:
		return [1, ["--reach: could not make %s (error %d)" % [_real(str(paths(root)["pond"])),
			made]]]
	var file := ConfigFile.new()
	file.set_value("reach", "address", said["address"])
	file.set_value("reach", "port", said["port"])
	var err := Invite.write_private(str(paths(root)["reach"]),
		file.encode_to_text().to_utf8_buffer())
	if err != OK:
		return [1, ["--reach: could not write %s (error %d)" % [_real(str(paths(root)
			["reach"])), err]]]
	var at := Invite.reach_text(str(said["address"]), int(said["port"]))
	var out: PackedStringArray = ["friends will call %s. Forward UDP %d on your router to"
		% [at, int(said["port"])] + " this machine's port %d/udp, and nothing else."
		% Invite.PORT]
	var near := _near_warning(str(said["address"]))
	if not near.is_empty():
		out.append(near)
	if not before.is_empty() and not entries(root).is_empty() \
			and (str(before["address"]) != str(said["address"])
				or int(before["port"]) != int(said["port"])):
		out.append("invites already sent still call %s: mint them again (--invite=<name>)"
			% Invite.reach_text(str(before["address"]), int(before["port"]))
			+ " for anyone who has one.")
	return [0, out]


## **`--invite=<label>`: a new invite.** The first one also makes the server's
## key and certificate. An existing label gets a new key id and secret, and the
## line sent before stops working. Refused, with a sentence naming `--reach`,
## until friends have an address to call.
static func mint(text: String, root: String = ROOT) -> Array:
	var name := _label_of(text)
	if name.begins_with("!"):
		return [1, [name.substr(1)]]
	var where := reach(root)
	if where.is_empty():
		return [1, ["--invite: friends need an address to call first. Set it with"
			+ " --reach=<your public address or name>[:<port>] -- where your router"
			+ " answers, and the port it forwards to this machine's %d/udp." % Invite.PORT]]
	var out: PackedStringArray = []
	if name != text.strip_edges():
		out.append("labels are lowercase: this one is %s" % name)
	var book := entries(root)
	var identity := load_identity(root)
	if identity.is_empty():
		var made := make_identity(root)
		if int(made[0]) != 0:
			return [1, out + PackedStringArray(made[1])]
		out.append_array(made[1])
		identity = load_identity(root)
		if identity.is_empty():
			return [1, out + PackedStringArray(["--invite: the new key could not be read"
				+ " back"])]
		# A new key voids every invite made with the old one: they pin a
		# certificate that is gone.
		if not book.is_empty():
			out.append("the key is new, so every invite made before it no longer works:"
				+ " %s. Mint each of them again." % ", ".join(PackedStringArray(book.keys())))
			for old: String in book.keys():
				DirAccess.remove_absolute(line_path(old, root))
			book.clear()
	var crypto := Crypto.new()
	var key_id := crypto.generate_random_bytes(Invite.KEY_ID_SIZE)
	while _key_in_use(book, key_id.hex_encode()):
		key_id = crypto.generate_random_bytes(Invite.KEY_ID_SIZE)
	var secret := crypto.generate_random_bytes(Invite.SECRET_SIZE)
	var line := Invite.format(str(where["address"]), int(where["port"]), key_id, secret,
		identity[2])
	if line.is_empty():
		return [1, out + PackedStringArray(["--invite: %s cannot be written into an invite"
			% Invite.reach_text(str(where["address"]), int(where["port"]))])]
	var replaced := book.has(name)
	book[name] = {"key_id": key_id.hex_encode(), "secret": secret,
		"created": int(Time.get_unix_time_from_system())}
	var err := _write_book(book, root)
	if err != OK:
		return [1, out + PackedStringArray(["--invite: could not write the book at %s"
			% _real(str(paths(root)["book"])) + " (error %d)" % err])]
	var lines_dir := str(paths(root)["lines"])
	err = Invite.make_private_dir(lines_dir)
	if err != OK:
		return [1, out + PackedStringArray(["--invite: could not make %s (error %d) -- the"
			% [_real(lines_dir), err] + " book has the invite, so --revoke=%s takes it back"
			% name])]
	err = Invite.write_private(line_path(name, root), (line + "\n").to_utf8_buffer())
	if err != OK:
		return [1, out + PackedStringArray(["--invite: could not write the invite to %s"
			% _real(line_path(name, root)) + " (error %d) -- the book has it, so" % err
			+ " --revoke=%s takes it back" % name])]
	if replaced:
		out.append("replaced the invite for %s: the line sent before stops working." % name)
	# docs/design/invites-ux.md §9: the path, never the line, and the address
	# it calls, so a wrong --reach shows now and not as a friend's "no answer".
	out.append("invite for %s written to %s, calling %s -- send its one line to %s and"
		% [name, _real(line_path(name, root)), Invite.reach_text(str(where["address"]),
			int(where["port"])), name] + " nobody else, and in Biogenic they tap play,"
		+ " then %s, then paste invite." % Invite.DOOR_NAME)
	var near := _near_warning(str(where["address"]))
	if not near.is_empty():
		out.append(near)
	out.append("a running server takes it within seconds.")
	return [0, out]


## **A warning for an address only the house can reach**: loopback, private,
## link-local or carrier-grade NAT -- `Lan.is_local_source` with no address of
## its own, so it asks about the ranges alone. Said at minting as well as by
## `--reach`, because an invite that calls one can only ever say "no answer"
## to a friend outside (docs/design/invites-ux.md §9 and §11). "" for any
## other, and for a name, which only its lookup could place.
static func _near_warning(address: String) -> String:
	if not Lan.is_local_source(address, ""):
		return ""
	return ("note: %s is a home-network address, so friends outside the house can never"
		% address + " reach it. Use the address your router has on the internet, or a"
		+ " name pointing at it: set --reach to that, and mint again.")


## **`--revoke=<label>`**: that invite stops working. A running server notices
## within seconds and cuts the friend if they are swimming.
static func revoke(text: String, root: String = ROOT) -> Array:
	var name := _label_of(text)
	if name.begins_with("!"):
		return [1, [name.substr(1)]]
	var book := entries(root)
	if not book.has(name):
		return [1, ["--revoke: there is no invite for %s. --invites lists them." % name]]
	book.erase(name)
	var err := _write_book(book, root)
	if err != OK:
		return [1, ["--revoke: could not write the book at %s (error %d)"
			% [_real(str(paths(root)["book"])), err]]]
	DirAccess.remove_absolute(line_path(name, root))
	var out: PackedStringArray = ["revoked the invite for %s. A running server drops them"
		% name + " within seconds if they are swimming."]
	if book.is_empty():
		out.append("no invites are left, so nothing will listen for the internet.")
	return [0, out]


## **`--invites`**: every label, when it was made and when it last came in.
## Never a secret.
static func listing(root: String = ROOT) -> Array:
	var book := entries(root)
	var where := reach(root)
	var out: PackedStringArray = []
	out.append("friends call %s; the server listens on %d/udp for them."
		% [Invite.reach_text(str(where["address"]), int(where["port"]))
			if not where.is_empty() else "(nowhere yet: set --reach)", Invite.PORT])
	if book.is_empty():
		out.append("no invites. --invite=<name> makes one.")
		return [0, out]
	var joined := _joined(root)
	var names: Array = book.keys()
	names.sort()
	out.append("%d invite%s:" % [names.size(), "" if names.size() == 1 else "s"])
	for name: String in names:
		var entry: Dictionary = book[name]
		var last := int(joined.get(str(entry["key_id"]), 0))
		out.append("  %s -- made %s, last joined %s" % [name, _date(int(entry["created"])),
			_date(last) if last > 0 else "never"])
	return [0, out]


## **`--new-key`**: a new key and certificate, and every invite void -- for a
## key that may have been seen by anybody else. Each friend needs a new invite.
static func new_key(root: String = ROOT) -> Array:
	var book := entries(root)
	var made := make_identity(root)
	if int(made[0]) != 0:
		return made
	var out := PackedStringArray(made[1])
	for name: String in book.keys():
		DirAccess.remove_absolute(line_path(name, root))
	var err := _write_book({}, root)
	if err != OK:
		return [1, out + PackedStringArray(["--new-key: could not empty the book (error %d)"
			% err])]
	if book.is_empty():
		out.append("no invites were made with the old key.")
	else:
		out.append("every invite made with the old key no longer works: %s. Mint each"
			% ", ".join(PackedStringArray(book.keys())) + " of them again.")
	return [0, out]


# ---------------------------------------------------------------------------
# What the running server reads.
# ---------------------------------------------------------------------------

## **The book as the session takes it**: key id in hex -> `[label, secret]`.
static func table(root: String = ROOT) -> Dictionary:
	return table_of(entries(root))


static func table_of(book: Dictionary) -> Dictionary:
	var out := {}
	for name: String in book.keys():
		var entry: Dictionary = book[name]
		out[str(entry["key_id"])] = [name, entry["secret"]]
	return out


## **The book**: label -> `{key_id (hex), secret, created}`. An entry that does
## not read -- a key id or a secret of the wrong size -- is left out.
static func entries(root: String = ROOT) -> Dictionary:
	return entries_of(_read(str(paths(root)["book"])))


static func entries_of(text: String) -> Dictionary:
	var out := {}
	if text.is_empty():
		return out
	var file := ConfigFile.new()
	if file.parse(text) != OK:
		return out
	for name: String in file.get_sections():
		var key_hex := str(file.get_value(name, "key_id", ""))
		var secret := Marshalls.base64_to_raw(str(file.get_value(name, "secret", ""))) \
			if not str(file.get_value(name, "secret", "")).is_empty() else PackedByteArray()
		if key_hex.length() != Invite.KEY_ID_SIZE * 2 or not key_hex.is_valid_hex_number() \
				or secret.size() != Invite.SECRET_SIZE or _label_of(name) != name:
			continue
		out[name] = {"key_id": key_hex.to_lower(), "secret": secret,
			"created": int(file.get_value(name, "created", 0))}
	return out


## `{address, port}` friends dial, or empty before `--reach`.
static func reach(root: String = ROOT) -> Dictionary:
	var text := _read(str(paths(root)["reach"]))
	if text.is_empty():
		return {}
	var file := ConfigFile.new()
	if file.parse(text) != OK:
		return {}
	var address := str(file.get_value("reach", "address", ""))
	var port := int(file.get_value("reach", "port", Invite.PORT))
	if not Invite.address_ok(address) or port < 1 or port > 65535:
		return {}
	return {"address": address, "port": port}


## **`[key, certificate, certificate DER]`**, or empty while there is none, or
## while the two files do not read.
static func load_identity(root: String = ROOT) -> Array:
	var where := paths(root)
	if not FileAccess.file_exists(str(where["key"])) \
			or not FileAccess.file_exists(str(where["cert"])):
		return []
	var key := CryptoKey.new()
	if key.load(str(where["key"])) != OK:
		return []
	var certificate := X509Certificate.new()
	if certificate.load(str(where["cert"])) != OK:
		return []
	var der := Invite.der_of_pem(_read(str(where["cert"])))
	if der.is_empty():
		return []
	return [key, certificate, der]


## **A new key and certificate**, over any old ones. The key is written
## `rw-------` before a byte of it lands; the certificate is public -- every
## invite carries it -- and is written the same way, whole or not at all: each
## is renamed over the old in one step, which is Linux's rename, where the
## server runs (on Windows, Godot 4.7 deletes the old file and then moves the
## new one).
static func make_identity(root: String = ROOT) -> Array:
	var where := paths(root)
	var made := Invite.make_private_dir(str(where["pond"]))
	if made != OK:
		return [1, ["could not make %s (error %d)" % [_real(str(where["pond"])), made]]]
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(KEY_BITS)
	var certificate: X509Certificate = null
	if key != null:
		certificate = crypto.generate_self_signed_certificate(key, SUBJECT, VALID_FROM,
			VALID_TO)
	if key == null or certificate == null:
		return [1, ["could not make a key and a certificate here"]]
	# `save()` writes the PEM without the closing NUL that `save_to_string()`
	# hands back (and warns about); it goes through a scratch file, and the
	# real one is then written through `Invite.write_private`.
	var scratch := str(where["cert"]) + ".tmp"
	if certificate.save(scratch) != OK:
		return [1, ["could not write the certificate to %s" % _real(scratch)]]
	var pem := _read(scratch)
	DirAccess.remove_absolute(scratch)
	var err := Invite.write_private(str(where["key"]),
		key.save_to_string(false).to_utf8_buffer())
	if err == OK:
		err = Invite.write_private(str(where["cert"]), pem.to_utf8_buffer())
	if err != OK:
		return [1, ["could not write the key to %s (error %d)" % [_real(str(where["key"])),
			err]]]
	return [0, ["made the server's key and certificate: %s (only this user can read it)"
		% _real(str(where["key"]))]]


## **When invite [param key_id] last came in**, written by the running server
## as it happens. Kept for the key ids still in [param live] alone.
static func note_joined(key_id: String, live: Array, root: String = ROOT) -> void:
	var joined := _joined(root)
	joined[key_id] = int(Time.get_unix_time_from_system())
	var file := ConfigFile.new()
	for kept: String in joined.keys():
		if live.has(kept):
			file.set_value("joined", kept, joined[kept])
	Invite.write_private(str(paths(root)["joined"]), file.encode_to_text().to_utf8_buffer())


# ---------------------------------------------------------------------------
# Plumbing.
# ---------------------------------------------------------------------------

## The label [param text] names, lowercased -- or a refusal, starting `!`.
static func _label_of(text: String) -> String:
	var name := text.strip_edges().to_lower()
	if name.is_empty() or name.length() > LABEL_MAX:
		return "!a label is 1 to %d characters: a-z, 0-9, - and _" % LABEL_MAX
	for i in name.length():
		var c := name.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 45 or c == 95):
			return "!a label is 1 to %d characters: a-z, 0-9, - and _" % LABEL_MAX
	return name


static func _key_in_use(book: Dictionary, key_hex: String) -> bool:
	for name: String in book.keys():
		if str((book[name] as Dictionary)["key_id"]) == key_hex:
			return true
	return false


static func _write_book(book: Dictionary, root: String) -> Error:
	var made := Invite.make_private_dir(str(paths(root)["pond"]))
	if made != OK:
		return made
	var file := ConfigFile.new()
	var names: Array = book.keys()
	names.sort()
	for name: String in names:
		var entry: Dictionary = book[name]
		file.set_value(name, "key_id", str(entry["key_id"]))
		file.set_value(name, "secret", Marshalls.raw_to_base64(entry["secret"]))
		file.set_value(name, "created", int(entry["created"]))
	return Invite.write_private(str(paths(root)["book"]),
		file.encode_to_text().to_utf8_buffer())


static func _joined(root: String) -> Dictionary:
	var out := {}
	var text := _read(str(paths(root)["joined"]))
	if text.is_empty():
		return out
	var file := ConfigFile.new()
	if file.parse(text) != OK or not file.has_section("joined"):
		return out
	for key: String in file.get_section_keys("joined"):
		out[key] = int(file.get_value("joined", key, 0))
	return out


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## `2026-09-25 14:03 UTC`.
static func _date(unix: int) -> String:
	return Time.get_datetime_string_from_unix_time(unix, true).substr(0, 16) + " UTC"


## The path as the owner types it: `user://` spelled out.
static func _real(path: String) -> String:
	return ProjectSettings.globalize_path(path)
