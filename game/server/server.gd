extends Node
## **The dedicated server: the shared pond, with nobody hosting it from a phone.**
##
## A headless process that keeps the water for two guests, on the home LAN, on
## the same port and the same PROTOCOL 4 a phone host speaks -- so a phone
## joins it exactly as it joins a friend, with the four taps of the code this
## prints. It has no cell of its own: its field's cell is out of the water and
## no anchor for good, the water is seeded round whoever is in it, and each
## guest is told the other one is the friend (`game/net/pond.gd`, `food.gd`'s
## `open_dedicated()`).
##
## **It boots straight here.** An exported Godot 4.7 release build cannot be
## told which scene to run (multiplayer.md §4.4: `--scene` and friends are
## compiled out of official templates), so the "Linux Server" export preset
## carries the custom feature `server`, and `project.godot`'s
## `run/main_scene.server` points it at this scene. On Android and Windows that
## key is inert: neither build has the feature.
##
## **Run it headless**: `biogenic-server.x86_64 --headless`. After a `--`:
##   `--no-update`        never check for updates (CI's smoke boot, tools)
##   `--stop-file=PATH`   stop cleanly when PATH appears -- see below
##
## **And the invites, for friends outside the house** (docs/server.md,
## "Internet play"; `invite_book.gd`). Each of these does its job and exits --
## without hosting, without the updater and without binding a port -- so the
## owner runs them beside the service, as its user:
##   `--reach=HOST[:PORT]`  the address friends dial, `[v6]:PORT` for IPv6
##   `--invite=LABEL`       mint an invite, or replace one; the line goes to a
##                          file, and only its path is printed
##   `--revoke=LABEL`       that invite stops working
##   `--invites`            the labels, when each was made and last came in
##   `--new-key`            a new key and certificate; every invite void
## The running server looks at its invites every [constant INVITES_POLL]
## seconds: the first one opens the internet listener, a revoked one cuts its
## guest, and none left closes it again.
##
## **Stopping cleanly.** Godot 4.7 does not catch SIGTERM, SIGINT or SIGQUIT --
## measured on the exported template: the process dies at once, exit status
## 143, no notification reaches a script, and stdout still in its buffer is
## lost. So the service's `ExecStop=` touches a file first and waits, and this
## polls for it: the guests are told the host has gone (a closed ENet peer
## reaches the far end in milliseconds, where a vanished one takes ENet's
## timeout of several seconds), and the process exits 0 before `systemd` needs
## to send anything. SIGTERM is still the backstop, and a death by SIGTERM is
## still a clean stop to `systemd`.
##
## **Updates** are `updater.gd`'s: every ten minutes, and never with anyone
## connected.
##
## Every line it prints starts `[server]`, for `journalctl -u biogenic-server`.
## The log is not the repository: it names this machine's address on purpose.
##
## No class_name, and no autoload: see the note at the top of signal_bus.gd.

const NetSession := preload("res://game/net/net_session.gd")
const Pond := preload("res://game/net/pond.gd")
const Lan := preload("res://game/net/lan.gd")
const Wire := preload("res://game/net/wire.gd")
const FoodField := preload("res://game/normal/food.gd")
const CellBody := preload("res://game/normal/cell.gd")
const Updater := preload("res://game/server/updater.gd")
const InviteBook := preload("res://game/server/invite_book.gd")
const Invite := preload("res://game/net/invite.gd")

## **Sixty frames a second, not as many as the core will run.** The field is
## stepped at the game's own rate -- what the phones step theirs at -- and a
## headless process with no cap spins a whole core doing nothing.
const FPS := 60
## How often the address and the code are said again: often enough that the
## last screenful of the journal always has them.
const ANNOUNCE_EVERY := 300.0
## How long to wait before trying to listen again, at first: the network may
## not be up yet at boot, or the port may be held by a server that is still
## going down. Doubled at every failure after that, up to
## [constant LISTEN_RETRY_MAX], so a port that stays taken costs the journal a
## line every five minutes and not every five seconds; back to the start once
## it listens.
const LISTEN_RETRY := 5.0
const LISTEN_RETRY_MAX := 300.0
## How often the stop file is looked for, and how long the goodbyes get to
## leave before the process does.
const STOP_POLL := 0.25
const STOP_LINGER := 0.3
## **How often the running server looks at its invites.** A look is one
## `stat` of the book and the certificate, and a read only when either
## changed, so a mint or a revoke from the command line takes effect within
## this -- and a revoked friend is cut within it -- with no restart.
const INVITES_POLL := 2.0

## **Seams, set before this node enters the tree.** A test runs the pond and
## not the update loop, not at this node's frame rate, and stops it without
## ending the process it shares -- and keeps its invites, and looks at them,
## where and as often as it says -- and hands an invite job its arguments in
## [member job_args], in place of the command line's.
var check_updates := true
var stop_file := ""
var own_frame_rate := true
var quits := true
var pond_root := InviteBook.ROOT
var invites_poll := INVITES_POLL
var job_args := PackedStringArray()

var _net: Node = null
var _food: FoodField = null
var _cell: CellBody = null
var _pond: Pond = null
var _updater: Node = null
var _listening := false
var _next_listen := 0.0
var _listen_retry := LISTEN_RETRY
var _next_announce := 0.0
var _next_stop_poll := 0.0
var _stopping := false
## The arguments after `--`, for the invite jobs.
var _args := PackedStringArray()
## What the invite job this scene ran exits with, or -1 for none.
var _job_code := -1
## **What the last look at the invites saw**: the book's and the
## certificate's modification times, whether both were older than the second
## they were read in, and the bytes of each.
var _next_invites := 0.0
var _book_time := -1
var _cert_time := -1
var _settled := false
var _book_bytes := PackedByteArray()
var _cert_bytes := PackedByteArray()
## Label -> key id in hex, as last applied: what a change is told against.
var _labels: Dictionary = {}
## The last thing said about the internet listener, so a state that does not
## change is not said again every look.
var _internet_said := ""
## Why nothing listens for the internet though it should, for [method
## _internet_status]: "" when nothing is wrong.
var _internet_trouble := ""
## **The book or the certificate could not be read at the last look**, so the
## next looks at it again whatever its time says: the `chown` that fixes it
## changes no modification time.
var _unreadable := false
## This server's user's name, once asked ([method _user_name]).
var _user := ""


func _ready() -> void:
	_read_args()
	if InviteBook.is_job(_args):
		# **An invite job, not a server**: done, said, and gone -- before a
		# session, an updater or a port exists.
		set_process(false)
		var done: Array = InviteBook.run(_args, pond_root)
		_job_code = int(done[0])
		for line: String in done[1]:
			print("[server] " + line)
		if quits:
			get_tree().quit(_job_code)
		return
	if own_frame_rate:
		Engine.max_fps = FPS
	var info := get_node_or_null(^"/root/BuildInfo")
	print("[server] Biogenic dedicated server -- v%s, binary %d, content %d, %s,"
		% [str(info.version_name) if info != null else "?",
			int(info.binary_version) if info != null else 0,
			int(info.content_version) if info != null else 0,
			str(info.commit) if info != null else "?"]
		+ " protocol %d, Godot %s" % [Wire.PROTOCOL,
			str(Engine.get_version_info().get("string", "?"))])
	if info != null and not str(info.pack_error).is_empty():
		print("[server] the staged content pack did not mount: %s" % str(info.pack_error))
	if DisplayServer.get_name() != "headless":
		print("[server] not headless (%s): run it with --headless, it draws nothing"
			% DisplayServer.get_name())
	if not stop_file.is_empty() and FileAccess.file_exists(stop_file):
		# Left by a stop this process never saw: it is not this one's.
		DirAccess.remove_absolute(stop_file)

	# **The water, with nobody's cell in it.** The cell is a stand-in the field
	# reads and never moves: out of the tree's processing, out of the water.
	_cell = CellBody.new()
	_cell.name = "Nobody"
	_cell.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_cell)
	_food = FoodField.new()
	_food.name = "Food"
	add_child(_food)
	_food.open_dedicated(_cell)

	_net = NetSession.new()
	_net.name = "NetSession"
	add_child(_net)

	if check_updates:
		_updater = Updater.new()
		_updater.name = "Updater"
		_updater.can_apply = OS.has_feature("template") and OS.has_feature("server") \
			and not OS.has_feature("editor")
		_updater.restart_wanted.connect(_on_restart_wanted)
		add_child(_updater)
		if not _updater.can_apply:
			print("[server] update: checking only -- this is not an exported server"
				+ " build, so nothing will be applied")
	else:
		print("[server] update: off (--no-update)")

	print("[server] adapters: %s" % _adapters())
	_listen()


func _process(_delta: float) -> void:
	var now := _now()
	if not stop_file.is_empty() and now >= _next_stop_poll:
		_next_stop_poll = now + STOP_POLL
		if FileAccess.file_exists(stop_file):
			DirAccess.remove_absolute(stop_file)
			print("[server] stopping: the service manager asked (%s)" % stop_file)
			shut_down()
			return
	if _stopping:
		return
	if not _listening:
		if now >= _next_listen:
			_listen()
	else:
		_pond.step()
		if now >= _next_invites:
			_watch_invites(false)
		if now >= _next_announce:
			_announce(false)
	if _updater != null:
		# **Who a restart would interrupt**: the guests, and a phone in the house
		# still joining -- never a caller on the internet listener that has
		# proved nothing, which could otherwise hold an update off for good.
		_updater.tick(int(_net.company()))


## **Put the pond down and go**: the guests are told, then the process exits
## 0. For a stop, and for an update's restart, which `systemd` turns into a
## start of the new build.
func shut_down(code: int = 0) -> void:
	if _stopping:
		return
	_stopping = true
	var guests: int = _net.guests().size() if _net != null else 0
	if _net != null:
		_net.close()
		_net = null
	print("[server] stopped -- %d guest%s told" % [guests, "" if guests == 1 else "s"])
	if not quits:
		return
	await get_tree().create_timer(STOP_LINGER).timeout
	get_tree().quit(code)


## The field and the session, for tools.
func food() -> FoodField:
	return _food


func session() -> Node:
	return _net


func pond() -> Pond:
	return _pond


func updater() -> Node:
	return _updater


func _listen() -> void:
	if _net.host(FoodField.GUESTS_MAX):
		_listening = true
		_listen_retry = LISTEN_RETRY
		# Built once the session is hosting: the pond reads which side it is on
		# from the session, and a dedicated host from being given no cell.
		if _pond == null:
			_pond = Pond.new(_net, _food, null, null)
			_pond.noted.connect(func(line: String) -> void: print("[server] " + line))
		if not _net.invite_proved.is_connected(_on_invite_proved):
			_net.invite_proved.connect(_on_invite_proved)
		# The invites before READY, so READY can say what listens for the
		# internet. A new socket has none of the last one's.
		_labels = {}
		_internet_said = ""
		_watch_invites(true)
		_announce(true)
		return
	_next_listen = _now() + _listen_retry
	print("[server] could not listen: %s -- %s Trying again in %d s."
		% [str(_net.trouble), str(_net.because), roundi(_listen_retry)])
	_listen_retry = minf(_listen_retry * 2.0, LISTEN_RETRY_MAX)


## **The address and the code**, first as READY and then every
## [constant ANNOUNCE_EVERY]. The code is the four marks a phone taps on the
## earshot ring, written as the clock positions they sit at: the ring has
## twelve, the first is straight up, and they go clockwise -- so digit 0 is 12
## o'clock and digit 3 is 3 o'clock.
func _announce(first: bool) -> void:
	_next_announce = _now() + ANNOUNCE_EVERY
	var address := str(_net.address)
	var code := clock_code(address)
	if first:
		print("[server] READY -- listening on %s port %d/udp, code %s"
			% [address, Lan.PORT, code])
		if Lan.octet_of(address) < 0:
			# Listening all the same (NetSession.hostable): the log is where the
			# owner finds out, and a loop of "no wi-fi here" would not say why.
			print("[server] no phone can join by code: a code carries the last number"
				+ " of this machine's address, from 1 to 254, and %s ends in %s."
				% [address, address.substr(address.rfind(".") + 1)]
				+ " Give this machine another address (docs/server.md). LAN only:"
				+ " do not forward this port.")
		else:
			print("[server] to join: a phone on this wi-fi (%sx) opens within earshot,"
				% Lan.prefix_of(address) + " taps answer, and taps the ring at %s, in"
				% code + " that order. LAN only: do not forward this port.")
		_internet_said = _internet_status()
		print("[server] internet: " + _internet_said)
		return
	print("[server] listening on %s port %d/udp, code %s -- %d of %d guests, %d in"
		% [address, Lan.PORT, code, _net.guests().size(), FoodField.GUESTS_MAX,
			_pond.guests_in_water()] + " the water -- internet: %s"
		% ("%d invite%s" % [_labels.size(), "" if _labels.size() == 1 else "s"]
			if _net.internet_listening() else "off"))


## **What listens for the internet, in a sentence** -- the READY line's, and
## the line said whenever it changes. Trouble first: whatever else is true, a
## listener that should be up and is not says why.
func _internet_status() -> String:
	if not _internet_trouble.is_empty():
		return "not listening for the internet: " + _internet_trouble
	var names: Array = _labels.keys()
	names.sort()
	if _net.internet_listening():
		var where := InviteBook.reach(pond_root)
		return ("listening on port %d/udp for %d invite%s (%s). Friends call %s: forward"
			% [Invite.PORT, names.size(), "" if names.size() == 1 else "s",
				", ".join(PackedStringArray(names)), Invite.reach_text(str(where["address"]),
					int(where["port"])) if not where.is_empty() else "(no --reach set)"]
			+ " that port, UDP, to this machine's %d/udp -- the one port to forward."
			% Invite.PORT)
	if names.is_empty():
		return ("nothing listens for the internet: there are no invites. To let a"
			+ " friend in from outside, set --reach, then --invite=<name>"
			+ " (docs/server.md).")
	return "not listening for the internet: reopening"


## **The book and the certificate, looked at** -- every [member invites_poll],
## and at once with [param first]. A `stat` of each, and a read only when one
## changed, or was changed in the second it was last read in: a file's time is
## counted in whole seconds, so a second write inside that second leaves it as
## it was, and only the bytes can tell.
##
## Then: the first invite opens the internet listener, a revoked or replaced
## one cuts its guest, none left closes it, and a new certificate -- `--new-key`
## -- puts the old listener down, its guests told, and the next look opens one
## that answers with the new. **A book or certificate this user cannot read
## fails closed**: it may hold a revoke, so every guest on an invite is cut,
## nothing listens, and the log says why until it reads again.
func _watch_invites(first: bool) -> void:
	_next_invites = _now() + invites_poll
	if _net.internet_closing():
		# Its refusals are still leaving: a new listener now would put the old
		# one down under them. Looked at again the moment it has gone.
		_next_invites = _now() + 0.1
		return
	var where := InviteBook.paths(pond_root)
	var book_path := str(where["book"])
	var cert_path := str(where["cert"])
	var book_time := int(FileAccess.get_modified_time(book_path))
	var cert_time := int(FileAccess.get_modified_time(cert_path))
	# **Invites and nothing listening** -- a listener that could not open, one
	# ENet closed by itself, one put down for a new key -- and a file that could
	# not be read are looked at again whatever the files' times say.
	var down := not _labels.is_empty() and not bool(_net.internet_listening())
	if not first and not down and not _unreadable and _settled \
			and book_time == _book_time and cert_time == _cert_time:
		return
	_settled = maxi(book_time, cert_time) < int(Time.get_unix_time_from_system())
	_book_time = book_time
	_cert_time = cert_time
	var book_bytes := _bytes_of(book_path)
	var cert_bytes := _bytes_of(cert_path)
	var unread := book_path if book_bytes.size() == 1 \
		else (cert_path if cert_bytes.size() == 1 else "")
	if not unread.is_empty():
		# **Fail closed.** Written by another user -- an invite job run as root
		# -- it may hold a revoke this server cannot see, so no invite is taken
		# until it reads: every guest on one is cut, and nothing listens.
		_unreadable = true
		_book_bytes = PackedByteArray()
		_cert_bytes = PackedByteArray()
		_net.set_invites({}, "%s cannot be read, so no invite is taken" % unread.get_file())
		var user := _user_name()
		_internet_trouble = ("%s cannot be read by %s, so no invite is taken until it can --"
			% [ProjectSettings.globalize_path(unread), user] + " another user wrote it, an"
			+ " invite job run as root most likely. Give the files back with chown -R %s: %s,"
			% [user, ProjectSettings.globalize_path(pond_root).trim_suffix("/")]
			+ " and run the jobs as %s (docs/server.md §9.1)." % user)
		_say_internet(first)
		return
	_unreadable = false
	var cert_changed := cert_bytes != _cert_bytes
	if not first and not down and book_bytes == _book_bytes and not cert_changed:
		return
	_book_bytes = book_bytes
	_cert_bytes = cert_bytes
	var book := InviteBook.entries_of(book_bytes.get_string_from_utf8())
	var labels := {}
	for name: String in book.keys():
		labels[name] = str((book[name] as Dictionary)["key_id"])
	if not first:
		_tell_changes(labels)
	_labels = labels
	var table := InviteBook.table_of(book)
	if table.is_empty():
		_internet_trouble = ""
		_net.set_invites({})
		_say_internet(first)
		return
	if cert_changed and _net.internet_listening():
		# **A new key.** Every invite that pinned the old certificate is void:
		# its guests are told so, and the old socket goes once that has had
		# REFUSE_LINGER to leave -- put down at once, it would drop the
		# refusal, and they would read "they hung up". The next look, the
		# moment it has gone, opens one that answers with the new.
		print("[server] internet: the server's key changed -- every guest on an invite"
			+ " made with the old one is cut, and the listener reopens with the new one")
		_net.close_internet(false, "the server's key changed")
		_next_invites = _now() + NetSession.REFUSE_LINGER + 0.15
		return
	if not _net.internet_listening():
		var identity := InviteBook.load_identity(pond_root)
		if identity.is_empty():
			_internet_trouble = "there are invites, but the server's key or certificate is" \
				+ " missing or does not read -- run --new-key, then mint every invite again."
			_book_bytes = PackedByteArray()
			_say_internet(first)
			return
		if not _net.listen_internet(identity[0], identity[1]):
			_internet_trouble = "there are invites, but port %d/udp is taken, or not free" \
				% Invite.PORT + " yet. Trying again in %d s." % roundi(invites_poll)
			# Looked at again next time, whatever the files say.
			_book_bytes = PackedByteArray()
			_settled = false
			_say_internet(first)
			return
	_internet_trouble = ""
	_net.set_invites(table)
	_say_internet(first)


## **Who this server runs as**, by name, for a sentence that tells the owner
## what to `chown` to: `$USER`, which systemd sets from the unit's `User=`, and
## `id -un` where it is not -- asked once.
func _user_name() -> String:
	if _user.is_empty():
		_user = OS.get_environment("USER")
	if _user.is_empty():
		var said: Array = []
		if OS.execute("id", ["-un"], said) == 0 and not said.is_empty():
			_user = str(said[0]).strip_edges()
	if _user.is_empty():
		_user = "this server's user"
	return _user


## The whole file at [param path]: empty when nothing is there, and one zero
## byte when something is that this user cannot read -- a file it may not
## open, a directory where the file should be, or a directory it may not look
## into, which hides whether there is one.
static func _bytes_of(path: String) -> PackedByteArray:
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return PackedByteArray([0])
		return file.get_buffer(file.get_length())
	var dir := path.get_base_dir()
	if DirAccess.dir_exists_absolute(path) \
			or (DirAccess.dir_exists_absolute(dir) and DirAccess.open(dir) == null):
		return PackedByteArray([0])
	return PackedByteArray()


## One line for each invite added, revoked or replaced since the last look --
## by label.
func _tell_changes(labels: Dictionary) -> void:
	for name: String in labels.keys():
		if not _labels.has(name):
			print("[server] invites: %s added" % name)
		elif str(_labels[name]) != str(labels[name]):
			print("[server] invites: %s replaced -- the line sent before no longer works"
				% name)
	for name: String in _labels.keys():
		if not labels.has(name):
			print("[server] invites: %s revoked" % name)


## The internet status, said when it changed -- and not on the first look,
## whose READY says it.
func _say_internet(first: bool) -> void:
	var now := _internet_status()
	if first or now == _internet_said:
		return
	_internet_said = now
	print("[server] internet: " + now)


func _on_invite_proved(_label: String, key_id: String) -> void:
	InviteBook.note_joined(key_id, _labels.values(), pond_root)


## The code for [param address] as clock positions, "3, 11, 7, 12 o'clock" --
## or a sentence saying there is none.
static func clock_code(address: String) -> String:
	var code := Lan.code_for(Lan.octet_of(address))
	if code.is_empty():
		return "(none: %s has no final octet a phone can tap)" % address
	var hours: PackedStringArray = []
	for digit: int in code:
		hours.append(str(12 if digit == 0 else digit))
	return ", ".join(hours) + " o'clock"


## Every adapter Godot can see, and which one the code is for -- the first thing
## to read when a phone cannot find the server.
func _adapters() -> String:
	var said: PackedStringArray = []
	for iface: Dictionary in IP.get_local_interfaces():
		var addresses: PackedStringArray = []
		for address: String in PackedStringArray(iface.get("addresses",
				PackedStringArray())):
			if address.count(".") == 3:
				addresses.append(address)
		if addresses.is_empty():
			continue
		var name := str(iface.get("friendly", iface.get("name", "?")))
		said.append("%s %s" % [name, ",".join(addresses)])
	return "; ".join(said) + " -- the code is for %s" % Lan.local_address()


func _on_restart_wanted(why: String) -> void:
	print("[server] restarting for %s; the service manager starts it again" % why)
	shut_down(0)


func _read_args() -> void:
	_args = job_args if not job_args.is_empty() else OS.get_cmdline_user_args()
	for arg: String in _args:
		if arg == "--no-update":
			check_updates = false
		elif arg.begins_with("--stop-file="):
			stop_file = arg.trim_prefix("--stop-file=")


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
