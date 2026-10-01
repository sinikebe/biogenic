extends Node
## **The dedicated server: the shared pond, with nobody hosting it from a phone.**
##
## A headless process that keeps the water for two guests, on the home LAN, on
## the same port and the same protocol a phone host speaks -- so a phone
## joins it exactly as it joins a friend, with the four taps of the code this
## prints. It has no cell of its own: its field's cell is out of the water and
## no anchor for good, its water is its room -- one drop, which lives whether
## anyone is in it or not (below) -- and each guest is told the other one is
## the friend (`game/net/pond.gd`, `food.gd`'s `open_dedicated()`).
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
##   `--no-upnp`          beside either of those: ask the router for nothing,
##                        this run alone -- see "Its port on the router"
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
##   `--no-upnp`, `--upnp`  whether the server asks the router to forward its
##                          internet port, remembered -- see below
## The running server looks at its invites every [constant INVITES_POLL]
## seconds: the first one opens the internet listener, a revoked one cuts its
## guest, and none left closes it again.
##
## **Its port on the router** (`game/net/port_forward.gd`; docs/server.md
## §9.3). From its first READY until it stops, the server asks the home router
## to forward UDP [method Invite.channel_port] to it by UPnP -- whatever the
## invites: the owner's call, "the server should be always exposed". What
## listens there does not change: nothing, until there is an invite.
## [method Lan.channel_port], the house's, is never forwarded, and the forward
## refuses it where each call to the router is made. Every such call is on a
## worker thread, and what happened is one `[upnp]` line. `--no-upnp` as a job
## turns it off and is remembered in `user://`, the way `--reach` is; `--upnp`
## turns it back on; a running server takes either within
## [member invites_poll] seconds. On the service's own command line -- beside
## `--stop-file=` or `--no-update` -- `--no-upnp` holds for that run and writes
## nothing.
##
## **Stopping cleanly.** Godot 4.7 does not catch SIGTERM, SIGINT or SIGQUIT --
## measured on the exported template: the process dies at once, exit status
## 143, no notification reaches a script, and stdout still in its buffer is
## lost. So the service's `ExecStop=` touches a file first and waits, and this
## polls for it: the guests are told the host has gone (a closed ENet peer
## reaches the far end in milliseconds, where a vanished one takes ENet's
## timeout of several seconds), the forward is taken off the router, and the
## process exits 0 before `systemd` needs to send anything -- in well under a
## second, with a router that answers. One that does not is waited for
## [constant UPNP_STOP_WAIT] s, then as the process ends for each call still
## under way, [constant PortForward.EXIT_WAIT_MS] ms at most -- 5 + 15 + 15 s
## at worst -- and past that the process ends itself. Under `systemd`, SIGTERM
## comes ten seconds after the stop was asked, whatever is still waiting: still
## a clean stop to `systemd`, and the forward's lease is the backstop, gone
## within the hour.
##
## **The room** (docs/design/ocean.md §10.3): the server's own drop, one of
## them, nobody's personal drop. Made on the first start and kept at
## [constant ROOM_PATH], loaded on every start after; **it lives while nobody is
## in it** -- its cells hunt, grow, starve and are replaced whether anyone is
## watching or not -- and it is kept every [constant ROOM_KEEP_EVERY] seconds
## and before every stop, the update's restart among them, so a crash costs it
## at most five minutes of its life. A guest arrives beside the other one, as
## ever, or at a quiet place when the room is empty.
##
## **Updates** are `updater.gd`'s: every ten minutes, and never with anyone
## connected.
##
## **A build for a branch is that branch's server** (channel.gd): the dev
## server, which follows `dev` and hosts the dev app's pond before a release.
## Its ports are its channel's, 45781 and 45782, so it runs beside the live
## server -- on one machine, if need be -- and the two never meet. Its lines
## that name the LAN's port say it is a dev build, and its forward on the router
## is named for its branch.
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
const PortForward := preload("res://game/net/port_forward.gd")
const Channel := preload("res://game/net/channel.gd")
const DropSave := preload("res://game/normal/drop_save.gd")

## **Where the room is kept** (ocean.md §10.3): the server's own `user://`,
## beside its invites. One room, `1`; more rooms are later, and would be more
## files beside it.
const ROOM_PATH := "user://rooms/1.save"
## **How often the room is kept while it runs**: a crash costs it at most this
## much of its life. Nobody is watching a server's frame, so the save's few
## milliseconds hitch nothing a player sees.
const ROOM_KEEP_EVERY := 300.0

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
## **How long a clean stop waits for the router to take the forward off**
## before it goes on to exit. A router on the LAN answers in milliseconds; one
## that has not in five is said to, and then waited for as the process ends
## ([constant PortForward.EXIT_WAIT_MS] a call) -- unless the unit's SIGTERM,
## ten seconds after the stop was asked, comes first.
const UPNP_STOP_WAIT := 5.0
## What the router's own list of forwards calls this one -- the release
## channel's; a branch's names its branch after it ([method upnp_description]).
const UPNP_DESCRIPTION := "Biogenic server"

## **Seams, set before this node enters the tree.** A test runs the pond and
## not the update loop, not at this node's frame rate, and stops it without
## ending the process it shares -- and keeps its invites, and looks at them,
## where and as often as it says -- and hands an invite job its arguments in
## [member job_args], in place of the command line's -- and hands the forward
## a router of its own in [member upnp_router], so no test asks the real one.
var check_updates := true
var stop_file := ""
var own_frame_rate := true
var quits := true
var pond_root := InviteBook.ROOT
var invites_poll := INVITES_POLL
## Where this server keeps its room -- [constant ROOM_PATH], or a test's own
## file; empty keeps none, and makes the room anew at every start.
var room_path := ROOM_PATH
var room_keep_every := ROOM_KEEP_EVERY
var job_args := PackedStringArray()
var upnp_router: Object = null

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
## **The certificate the internet listener answers with**, as
## [method InviteBook.fingerprint] prints it -- the listening line names it, so
## an owner can match it with the one `--new-key` printed (issue #89).
var _answering_with := ""
## **The book or the certificate could not be read at the last look**, so the
## next looks at it again whatever its time says: the `chown` that fixes it
## changes no modification time.
var _unreadable := false
## This server's user's name, once asked ([method _user_name]).
var _user := ""
## **The forward of the internet port on the router**, made at the first READY.
var _forward: PortForward = null
## What the command line said about UPnP for this run: -1 `--no-upnp`, 1
## `--upnp`, 0 neither -- which leaves it to the remembered switch.
var _upnp_this_run := 0
## The switch as last looked at: 1 on, 0 off, -1 unreadable, -2 not yet.
var _upnp_setting := -2
var _next_upnp := 0.0
## When the room is next kept, and how many times it has been.
var _next_room_keep := 0.0
var rooms_kept := 0


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
	_open_room()

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
	if not room_path.is_empty() and now >= _next_room_keep:
		keep_room("every %d s" % roundi(room_keep_every))
	if not _listening:
		if now >= _next_listen:
			_listen()
	else:
		_pond.step()
		if now >= _next_invites:
			_watch_invites(false)
		if _forward != null and now >= _next_upnp:
			_watch_upnp(false)
		if now >= _next_announce:
			_announce(false)
	if _updater != null:
		# **Who a restart would interrupt**: the guests, and a phone in the house
		# still joining -- never a caller on the internet listener that has
		# proved nothing, which could otherwise hold an update off for good.
		_updater.tick(int(_net.company()))


## **Put the pond down and go**: the guests are told, the forward is taken off
## the router -- waited for [constant UPNP_STOP_WAIT] s here, and for a call
## still under way as the process ends -- then the process exits 0. For a stop,
## and for an update's restart, which `systemd` turns into a start of the new
## build.
func shut_down(code: int = 0) -> void:
	if _stopping:
		return
	# **The room is kept before anything else goes** (ocean.md §10.3): its
	# guests are nobody the file keeps, and a stop is the one moment it is sure
	# to be written.
	if not room_path.is_empty() and _food != null:
		keep_room("before stopping")
	_stopping = true
	var guests: int = _net.guests().size() if _net != null else 0
	if _net != null:
		_net.close()
		_net = null
	print("[server] stopped -- %d guest%s told" % [guests, "" if guests == 1 else "s"])
	if _forward != null:
		_forward.stop()
	if not quits:
		return
	if _forward != null:
		var until := _now() + UPNP_STOP_WAIT
		while not _forward.is_stopped() and _now() < until:
			await get_tree().process_frame
		if not _forward.is_stopped():
			# **Said now, not after the wait at the end**: its call goes on, and
			# the node waits it out as the process ends -- which, from a device
			# that trickles bytes, is the whole of [constant PortForward.EXIT_WAIT_MS].
			print("[upnp] " + upnp_said(&"stop_timeout", {"port": _forward.port,
				"protocol": _forward.protocol, "holds": _forward.holds(),
				"permanent": _forward.is_permanent(), "lease": _forward.lease,
				"waited": UPNP_STOP_WAIT, "exit_wait_ms": _forward.exit_wait_ms}))
	await get_tree().create_timer(STOP_LINGER).timeout
	get_tree().quit(code)


## **The room, loaded or made** (ocean.md §10.3): the drop kept at
## [member room_path] if there is one this build can read -- converted, and
## said, if a content pack changed its rules since -- and otherwise a new one,
## made for a newborn and kept at once, so it is the room from its first start.
func _open_room() -> void:
	var kept := DropSave.read(room_path) if not room_path.is_empty() else {}
	var started := Time.get_ticks_usec()
	if kept.is_empty():
		_food.open_dedicated(_cell)
		print("[server] room: a new one is made -- %d bodies (%.0f ms)%s" % [
			_food.drop_bodies(), float(Time.get_ticks_usec() - started) / 1000.0,
			"" if not room_path.is_empty() else ", kept nowhere"])
		if not room_path.is_empty():
			keep_room("made")
		return
	var done := _food.open_dedicated(_cell, kept["drop"])
	var line := "[server] room: loaded from %s -- %d bodies, %.0f s old (%.0f ms)" % [
		room_path, int(done.get("bodies", 0)), _food.drop_age(),
		float(Time.get_ticks_usec() - started) / 1000.0]
	if DropSave.converted(kept):
		line += ", CONVERTED from rules %s: every body re-derived, %d trimmed, %d put back" \
			% [str(kept.get("rules", "")).left(12), int(done.get("trimmed", 0)),
				int(done.get("contained", 0))] + " inside the rim"
	else:
		line += ", as it was kept"
	print(line)
	_next_room_keep = _now() + room_keep_every


## **The room, kept at [member room_path]** (ocean.md §10.3): every body and
## everything it is doing -- its guests are nobody's to keep -- written beside
## the last good file, read back and put over it. [param why] is said with it.
## Returns whether it was.
func keep_room(why: String) -> bool:
	_next_room_keep = _now() + room_keep_every
	if room_path.is_empty() or _food == null or not _food.owns_drop():
		return false
	var started := Time.get_ticks_usec()
	var state := _food.drop_state()
	var done := DropSave.write(room_path, DropSave.compose(state, {}))
	var ms := float(Time.get_ticks_usec() - started) / 1000.0
	if done != OK:
		print("[server] room: NOT kept (%s): %s -- the last good one stands"
			% [why, error_string(done)])
		return false
	rooms_kept += 1
	print("[server] room: kept (%s) -- %d bodies, %.0f s old, %d guest%s in it (%.1f ms)"
		% [why, (state["bodies"]["slot"] as PackedInt32Array).size(), _food.drop_age(),
			_pond.guests_in_water() if _pond != null else 0,
			"" if _pond != null and _pond.guests_in_water() == 1 else "s", ms])
	return true


## The field and the session, for tools.
func food() -> FoodField:
	return _food


func session() -> Node:
	return _net


func pond() -> Pond:
	return _pond


func updater() -> Node:
	return _updater


func forward() -> PortForward:
	return _forward


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
		# **The router asked from the first READY on**, whatever the invites
		# (the owner's call: always exposed), and never before this listens:
		# a server that cannot hold its own port holds no forward either.
		if _forward == null:
			_open_forward()
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
			% [address, Lan.channel_port(), code] + channel_said(true))
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
				% Lan.prefix_of(address) + ("" if not Channel.is_branch()
					else " in the %s app," % Channel.branch()) + " taps answer, and taps"
				+ " the ring at %s, in that order. LAN only: do not forward this port." % code)
		_internet_said = _internet_status()
		print("[server] internet: " + _internet_said)
		return
	print("[server] listening on %s port %d/udp, code %s -- %d of %d guests, %d in"
		% [address, Lan.channel_port(), code, _net.guests().size(), FoodField.GUESTS_MAX,
			_pond.guests_in_water()] + " the water -- internet: %s"
		% ("%d invite%s" % [_labels.size(), "" if _labels.size() == 1 else "s"]
			if _net.internet_listening() else "off") + " -- upnp: %s" % _forward_state()
		+ channel_said(false))


## **What a line naming the LAN's port adds on a branch's channel**: that this
## is that branch's build, and -- [param whole] -- that only that branch's app
## finds it. "" on the release channel, whose lines are as they always were.
static func channel_said(whole: bool) -> String:
	if not Channel.is_branch():
		return ""
	return " -- a %s build" % Channel.branch() + (": only the %s app finds it"
		% Channel.branch() if whole else "")


## **What listens for the internet, in a sentence** -- the READY line's, and
## the line said whenever it changes. Trouble first: whatever else is true, a
## listener that should be up and is not says why.
func _internet_status() -> String:
	if not _internet_trouble.is_empty():
		return "not listening for the internet: " + _internet_trouble
	var names: Array = _labels.keys()
	names.sort()
	if _net.internet_listening():
		return ("listening on port %d/udp for %d invite%s (%s), certificate %s. Friends"
			% [Invite.channel_port(), names.size(), "" if names.size() == 1 else "s",
				", ".join(PackedStringArray(names)), _answering_with]
			+ " call %s, which must reach this machine's %d/udp: the [upnp] lines say"
			% [InviteBook.reach_said(pond_root, "(no --reach set)"), Invite.channel_port()]
			+ " whether the router forwards it, and if not, forward it by hand -- the one"
			+ " port to forward (docs/server.md §9.3).")
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
				% Invite.channel_port() + " yet. Trying again in %d s." % roundi(invites_poll)
			# Looked at again next time, whatever the files say.
			_book_bytes = PackedByteArray()
			_settled = false
			_say_internet(first)
			return
		_answering_with = InviteBook.fingerprint(identity[2])
	_internet_trouble = ""
	_net.set_invites(table)
	_say_internet(first)


## **Who this server runs as**, by name, for a sentence that tells the owner
## what to `chown` to: `$USER`, which systemd sets from the unit's `User=`, then
## `$LOGNAME`, then this process's uid looked up in `/etc/passwd` -- asked once.
func _user_name() -> String:
	if _user.is_empty():
		_user = OS.get_environment("USER")
	if _user.is_empty():
		_user = OS.get_environment("LOGNAME")
	if _user.is_empty():
		# No shell-out to `id`: this process's real uid from /proc, and its name
		# from /etc/passwd, both read with FileAccess so nothing on PATH decides
		# it (issues #84, #71). A hint for a `chown`, so the uid alone will do if
		# the name is not there.
		var uid := InviteBook._proc_uid()
		if uid >= 0:
			for line: String in FileAccess.get_file_as_string("/etc/passwd").split("\n", false):
				var f := line.split(":")
				if f.size() > 2 and str(f[2]).strip_edges().is_valid_int() \
						and int(str(f[2]).strip_edges()) == uid:
					_user = str(f[0])
					break
			if _user.is_empty():
				_user = "uid %d" % uid
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


# ---------------------------------------------------------------------------
# The internet port on the router (docs/server.md §9.3).
# ---------------------------------------------------------------------------

## **The forward, made** for [method Invite.channel_port] and never
## [method Lan.channel_port]: the house's port, which no router may ever
## forward (docs/server.md §5). Its never-list is where that is held, at every
## call. Named on the router as [method upnp_description] says.
func _open_forward() -> void:
	_forward = PortForward.new(Invite.channel_port(), upnp_description(),
		PackedInt32Array([Lan.channel_port()]), upnp_router)
	_forward.name = "PortForward"
	_forward.reported.connect(_on_forward_reported)
	add_child(_forward)
	_watch_upnp(true)


## **The forward's name on the router's list**: [constant UPNP_DESCRIPTION] on
## the release channel, and the branch's after it on a branch's --
## `Biogenic server (dev)` -- so an owner with both servers can tell which
## forward is which.
static func upnp_description() -> String:
	if not Channel.is_branch():
		return UPNP_DESCRIPTION
	return "%s (%s)" % [UPNP_DESCRIPTION, Channel.branch()]


## **The UPnP switch, looked at** -- this run's, when the command line gave
## one, and otherwise the one `--no-upnp` and `--upnp` remember -- every
## [member invites_poll], and at once with [param first]. A change starts or
## stops the forward, and says so in a line.
func _watch_upnp(first: bool) -> void:
	_next_upnp = _now() + invites_poll
	var setting := InviteBook.upnp_setting(pond_root) if _upnp_this_run == 0 \
		else (1 if _upnp_this_run > 0 else 0)
	if not first and setting == _upnp_setting:
		return
	var turned_on := not first and _upnp_setting <= 0 and setting > 0
	_upnp_setting = setting
	if setting > 0:
		_forward.start()
	else:
		_forward.stop()
	print("[upnp] " + _upnp_switch_said(setting, turned_on))


## What the switch at [param setting] says: on, off -- remembered, or for this
## run -- or unreadable.
func _upnp_switch_said(setting: int, turned_on: bool) -> String:
	var what := "UDP %d" % Invite.channel_port()
	var by_hand := "for friends outside the house, forward %s to this machine by hand" % what \
		+ " (docs/server.md §9.3)"
	if setting > 0:
		return ("%slooking for the router, to forward %s to this machine for as long as the"
			% ["on again (--upnp): " if turned_on else "", what] + " server runs -- nothing"
			+ " answers there without an invite")
	if setting == 0 and _upnp_this_run < 0:
		return ("off for this run (--no-upnp on the command line): nothing is asked of the"
			+ " router -- %s" % by_hand)
	if setting == 0:
		return ("off (--no-upnp): nothing is asked of the router, and a forward it held is"
			+ " taken off -- %s; --upnp turns it back on" % by_hand)
	var user := _user_name()
	return ("off: %s cannot be read by %s, so nothing is asked of the router until it can"
		% [ProjectSettings.globalize_path(str(InviteBook.paths(pond_root)["upnp"])), user]
		+ " -- another user wrote it. Give the files back with chown -R %s: %s (docs/server.md"
		% [user, ProjectSettings.globalize_path(pond_root).trim_suffix("/")] + " §9.1)")


## The forward in a word or two, for the line said every few minutes.
func _forward_state() -> String:
	if _forward == null or _upnp_setting <= 0:
		return "off"
	if _forward.holds():
		return "forwarded, no time limit" if _forward.is_permanent() else "forwarded"
	return "not forwarded"


func _on_forward_reported(event: StringName, facts: Dictionary) -> void:
	var line := upnp_said(event, facts, InviteBook.reach(pond_root))
	if not line.is_empty():
		print("[upnp] " + line)


## **What the forward's [param event] says, as a line** -- after `[upnp] `, one
## an event ([signal PortForward.reported]'s, and `stop_timeout`, this
## scene's own). [param reach] is `--reach`'s `{address, port}`, or empty, for
## the public address's hint. "" for an event with nothing to say.
static func upnp_said(event: StringName, facts: Dictionary, reach: Dictionary = {}) -> String:
	var what := "%s %d" % [str(facts.get("protocol", "UDP")), int(facts.get("port",
		Invite.channel_port()))]
	var by_hand := "forward %s to this machine by hand (docs/server.md §9.3)" % what
	var again := "it looks again within %d minutes" % roundi(PortForward.LOOK_AGAIN_MAX / 60.0)
	var lease := int(facts.get("lease", PortForward.LEASE))
	match event:
		&"no_upnp":
			return "this build has no UPnP, so nothing is asked of the router: " + by_hand
		&"forbidden":
			return "refused to forward %s: that port is never forwarded" % what
		&"no_router":
			if not bool(facts.get("network", true)):
				return ("this machine has no network a router could be on, so %s is not"
					% what + " forwarded -- %s" % again)
			return ("no router answered, so %s is not forwarded: UPnP is off in the router," % what
				+ " most likely -- turn it on, or %s. In a Proxmox container, the" % by_hand
				+ " router is found only from the LAN bridge, and a firewall must let its"
				+ " answer in (docs/server.md §9.3) -- %s" % again)
		&"no_gateway":
			if StringName(facts.get("why", &"")) == &"offline":
				return ("the router answered, but says it is not connected to the internet, so"
					+ " %s is not forwarded -- %s" % [what, again])
			return ("a router answered the search -- UPnP is on -- but what it says it is could"
				+ " not be read, or is not a router that forwards ports, so %s is not" % what
				+ " forwarded: %s; if that goes on, %s" % [again, by_hand])
		&"cannot_help":
			return _cannot_reach(str(facts.get("wan", "")),
				StringName(facts.get("kind", &"unknown")), what)
		&"mapped":
			var internal := "%s:%d" % [str(facts.get("internal", "?")),
				int(facts.get("port", Invite.channel_port()))]
			if bool(facts.get("permanent", false)):
				return ("forwarded %s on the router to this machine, %s, with no time limit --"
					% [what, internal] + " the router takes no other kind: put again every"
					+ " %s, and taken off when the server stops. A server killed instead"
					% _span(roundi(PortForward.PERMANENT_CHECK)) + " leaves it there until"
					+ " you take it off the router")
			return ("forwarded %s on the router to this machine, %s, for %s at a time --"
				% [what, internal, _span(lease)] + " renewed every %s while the server"
				% _span(roundi(lease * PortForward.RENEW_AT)) + " runs, and taken off when it"
				+ " stops")
		&"address":
			var kind := StringName(facts.get("kind", &"unknown"))
			if kind != &"public":
				return _cannot_reach(str(facts.get("address", "")), kind, what)
			if not bool(facts.get("held", true)):
				return ("the router says this network's public address is %s -- the one for"
					% str(facts.get("address", "")) + " --reach once %s reaches this" % what
					+ " machine, which this server's own forward does not (docs/server.md §9.3)")
			return _address_hint(str(facts.get("address", "")), reach,
				int(facts.get("port", Invite.channel_port())))
		&"conflict":
			return ("the router already forwards %s elsewhere -- to another machine, or by a"
				% what + " forward made by hand -- so it was left alone: this server never takes"
				+ " a forward it did not make. If that one leads to this machine, %s, friends"
				% str(facts.get("internal", "?")) + " get in anyway, and --no-upnp stops the"
				+ " asking; if not, take it off the router, and the server takes the port -- %s"
				% again + " (docs/server.md §9.3)")
		&"refused":
			return ("the router would not forward %s (%s): %s -- %s"
				% [what, str(facts.get("name", "?")), by_hand, again])
		&"renew_failed":
			var retry := _span(roundi(float(facts.get("retry", 60.0))))
			if bool(facts.get("permanent", false)):
				return ("the router did not take the forward of %s again (%s): asking again in"
					% [what, str(facts.get("name", "?"))] + " %s" % retry)
			return ("the router did not renew the forward of %s (%s): asking again in %s --"
				% [what, str(facts.get("name", "?")), retry] + " it holds until %s UTC"
				% Time.get_datetime_string_from_unix_time(int(facts.get("until", 0)), true)
					.substr(11, 5))
		&"renewed":
			return "the router renewed the forward of %s again" % what
		&"lapsed":
			return ("the forward of %s lapsed -- the router did not renew it in time: looking"
				% what + " for the router again")
		&"removed":
			return "took the forward of %s off the router" % what
		&"not_ours":
			return ("left %s on the router: asked for it again before taking it off, the router"
				% what + " answered that another machine holds it now -- it gave the port away,"
				+ " after a restart most likely -- and that one is not this server's to take")
		&"remove_failed":
			if bool(facts.get("permanent", false)):
				return ("could not take the forward of %s off the router (%s), and it has no"
					% [what, str(facts.get("name", "?"))] + " time limit: it stays until you"
					+ " take it off the router")
			return ("could not take the forward of %s off the router (%s): it lapses by itself"
				% [what, str(facts.get("name", "?"))] + " within %s" % _span(lease))
		&"stop_timeout":
			var waited := _span(roundi(float(facts.get("waited", UPNP_STOP_WAIT))))
			var exit_wait := _span(roundi(float(facts.get("exit_wait_ms",
				PortForward.EXIT_WAIT_MS)) / 1000.0))
			var goes := ("the process waits for it as it ends, %s at most for each call, and"
				% exit_wait + " past that ends itself (under systemd, SIGTERM comes sooner)")
			if not bool(facts.get("holds", false)):
				return ("the router has not answered within %s, and nothing is forwarded yet:"
					% waited + " %s" % goes)
			if bool(facts.get("permanent", false)):
				return ("the router has not answered within %s: %s. Unless it answers, the" % [
					waited, goes] + " forward of %s, which has no time limit, stays until" % what
					+ " you take it off the router")
			return ("the router has not answered within %s: %s. Unless it answers, the" % [waited,
				goes] + " forward of %s is left to its lease, and lapses within %s" % [what,
					_span(lease)])
	return ""


## **A router whose own internet address, [param address] of [param kind], no
## friend can call**: what that means, and what to do.
static func _cannot_reach(address: String, kind: StringName, what: String) -> String:
	match kind:
		&"shared":
			return ("the router's own internet address is %s, a shared one (100.64.0.0/10):"
				% address + " your internet provider shares one address among many homes --"
				+ " carrier-grade NAT -- and a forward on this router cannot reach you. Ask"
				+ " the provider for a public IPv4 address; over IPv6, friends need a firewall"
				+ " rule on the router, not a forward (docs/server.md §9.3)")
		&"private":
			return ("the router's own internet address is %s, a private one: two routers in a"
				% address + " row -- this one sits behind another, your provider's box most"
				+ " likely -- so a forward on this one alone cannot reach you. Forward %s on"
				% what + " the outer router to this one, and on this one to this machine, by"
				+ " hand -- or put the outer one in bridge mode. If your provider shares one"
				+ " address among many homes instead, no forward can (docs/server.md §9.3)")
		&"unusable":
			return ("the router's own internet address is %s, which the internet cannot call,"
				% address + " so %s is not forwarded -- it is not connected, most likely"
				% what)
	return ("a router answered whose own internet address is not one the internet can call --"
		+ " private, shared, or none -- so a forward on it cannot reach you, and it is not"
		+ " asked for one: two routers in a row, or an internet provider that shares one"
		+ " address among many homes (docs/server.md §9.3)")


## **The router's public address, as a hint for `--reach`** -- which is set by
## hand, always: the server never fills it in (the owner's call).
static func _address_hint(address: String, reach: Dictionary, forwarded: int) -> String:
	var said := "the router says this network's public address is %s" % address
	if reach.is_empty():
		return said + " -- set --reach=%s to let friends in (docs/server.md §9.2)" % address
	var named := str(reach["address"])
	var port := int(reach["port"])
	var elsewhere := "" if port == forwarded else (" -- and --reach's port, %d, must be" % port
		+ " forwarded to this machine's %d by hand: the forward here is of %d" % [forwarded,
			forwarded])
	if named.contains(":"):
		return (said + "; --reach names %s, an IPv6 address, which no forward reaches:" % named
			+ " friends reach it only if the router's firewall lets UDP %d in over IPv6 --" % port
			+ " a firewall rule, not a forward (docs/server.md §9.2)")
	if named == address:
		return said + ", which --reach names" + elsewhere
	if PortForward.kind_of(named) != &"unknown":
		return (said + ", but --reach names %s, which every invite calls: if the address" % named
			+ " changed, set --reach=%s and mint again (docs/server.md §9.2)" % address
			+ elsewhere)
	return said + "; --reach names %s, which must lead there" % named + elsewhere


## "an hour", "30 minutes", "5 s": a span of [param seconds], as a line says it.
static func _span(seconds: int) -> String:
	if seconds == 3600:
		return "an hour"
	if seconds > 3600 and seconds % 3600 == 0:
		return "%d hours" % (seconds / 3600)
	if seconds >= 120 and seconds % 60 == 0:
		return "%d minutes" % (seconds / 60)
	if seconds == 60:
		return "a minute"
	return "%d s" % seconds


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
	# **The UPnP switch rides along a run**: beside the service's own flags it
	# is this run's, and never a job -- `InviteBook.is_job` agrees.
	var runs := InviteBook.is_run(_args)
	for arg: String in _args:
		if arg == "--no-update":
			check_updates = false
		elif arg.begins_with("--stop-file="):
			stop_file = arg.trim_prefix("--stop-file=")
		elif runs and arg == "--no-upnp":
			_upnp_this_run = -1
		elif runs and arg == "--upnp" and _upnp_this_run == 0:
			_upnp_this_run = 1


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
