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

## **Seams, set before this node enters the tree.** A test runs the pond and
## not the update loop, not at this node's frame rate, and stops it without
## ending the process it shares.
var check_updates := true
var stop_file := ""
var own_frame_rate := true
var quits := true

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


func _ready() -> void:
	_read_args()
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
		if now >= _next_announce:
			_announce(false)
	if _updater != null:
		_updater.tick(int(_net.peer_count()))


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
			return
		print("[server] to join: a phone on this wi-fi (%sx) opens within earshot,"
			% Lan.prefix_of(address) + " taps answer, and taps the ring at %s, in"
			% code + " that order. LAN only: do not forward this port.")
		return
	print("[server] listening on %s port %d/udp, code %s -- %d of %d guests, %d in"
		% [address, Lan.PORT, code, _net.guests().size(), FoodField.GUESTS_MAX,
			_pond.guests_in_water()] + " the water")


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
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--no-update":
			check_updates = false
		elif arg.begins_with("--stop-file="):
			stop_file = arg.trim_prefix("--stop-file=")


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
