extends Node
## **How late is the friend?** Times the gap between a cell doing something on
## one screen and the other screen drawing it, over many trials, so the answer
## is a distribution rather than an anecdote.
##
##   godot --headless --path . res://tools/net_lag.tscn -- \
##       --link=loopback --trials=40 --seed=7
##
## **The same recipe as `tools/net_probe.gd`, taken all the way to the drawing.**
## Two `net_session.gd` nodes in one process on ENet loopback; the far cell is a
## real `cell.gd` body, run by its own physics and reported to its session in
## the same order `normal_mode.gd` does it (the run first, then the body steps);
## the near screen is a real `vision.tscn`, and what is timed is its `_peer` --
## the numbers its draw routines actually use, not what the session buffered.
##
## **What an event is.** `impulse` is the jump the owner named: the far body at
## rest fires `cell.gd`'s own `_fire_impulse()`, 97-138 units/s along a nose it
## kicks by up to nine degrees. `turn` is the sharpest turn a born cell has: at
## rest, steering goes from nothing to hard over, through a stand-in for the
## drawn stick so that only that one body is steered. Each trial waits a random
## 1.2-1.8 s first, so the event lands at a random phase of the send clock.
##
## **What latency means here, and it is one definition for both ends.** For a
## level X, the far body's own time to move X from where it rested -- which is
## when its own player saw it start -- against the near screen's time to *draw*
## it X from where it drew it resting. The difference is how much later one
## screen shows what the other already has. Two levels each: a small one for
## *first visible* and a large one for *unmistakable*. Crossings are
## interpolated between frames.
##
## **And a time shift, which needs no level.** The single delay that best lines
## the drawn curve up with the true one over the whole event, by least squares.
## It is the robust number for the turn, where a one-byte heading puts +/-0.7
## degrees of quantization on any single crossing.
##
## Arguments, all optional, after the `--`:
##   --link=loopback|wifi|rough
##                           loopback is ENet on 127.0.0.1 and nothing else, so
##                           it measures exactly the self-inflicted part. `wifi`
##                           runs every frame the near session receives through
##                           an in-process queue: 10-50 ms of flight, uniform, and
##                           2% loss. `rough` adds a 5% chance of a 100-250 ms
##                           spike and 5% loss. **Both are models of a network,
##                           not a network** -- nothing in this container can
##                           reproduce two phones on real Wi-Fi.
##   --reliable              deliver every frame the way ENet delivers a reliable
##                           one, whatever the session asked for: a lost frame is
##                           resent after an RTO and **everything behind it on
##                           that channel waits for it**. The old wire, on the new
##                           send rate -- which is what makes the price of head-
##                           of-line blocking a number. Frames the session sends
##                           reliably are always delivered this way.
##   --rto=<ms>              the retransmission timeout that model uses, default
##                           150: ENet's own `roundTripTime + 4 x variance` on a
##                           link like `wifi`, which is an estimate, not a reading
##   --trials=<n>            per event, default 40
##   --events=impulse,turn   which events to time
##   --swim=<seconds>        then let the far cell swim freely -- its own
##                           impulses, and a steering demand that changes every
##                           0.4-2.0 s -- and measure how far the drawn friend is
##                           from the real one, frame by frame, and how big the
##                           corrections the view blends out actually are
##   --fps=<n>               frame cap for the one process both screens share,
##                           default 60. Wall time matters: every clock in
##                           `net_session.gd` is wall time
##   --seed=<int>            the body's own drift and impulses, the trial timing
##                           and the link's dice. ENet's timing is not seeded and
##                           cannot be, so two runs agree as distributions, not
##                           frame for frame
##   --each                  print every trial's numbers as well
##   --pond                  **the shared pond** (shared-pond.md §5, Phase 2):
##                           two real runs of `normal_mode.tscn`, the host's and
##                           the guest's, and the friend timed is the host's own
##                           cell as the guest's screen draws it -- off the
##                           mirror's slot 68, which POND carries, not off the
##                           state track. `--link` models the guest's intake.
##                           Adds `bite` to `--events` (a chewer posed on the
##                           guest, timed from the host's bite to the guest's
##                           `hit`), and samples every frame how far each water
##                           body in the guest's water is from the host's, and
##                           the largest POND frame sent
##   --swimmer=host|guest    with --pond: whose cell swims. `host`, the default,
##                           is all of the above. **`guest` turns it round for
##                           the host's referee** (net-hardening.md part B): the
##                           guest's cell swims for --swim seconds on its own
##                           impulses and a steering demand that changes every
##                           0.4-2.0 s, with its free sense an `ampulla` so it
##                           calls, the host's cell is held still, and the link
##                           model sits on the host's intake as well as the
##                           guest's -- so every frame the referee judges has
##                           crossed it. No events are timed unless --events
##                           names them. Ends with every foul the referee
##                           called, which an honest guest never earns, and the
##                           closest call on each of its budgets
##
## Prints `[net-lag]` lines. Excluded from export (`tools/*`), so none of it
## ships.

const NetSession := preload("res://game/net/net_session.gd")
const Wire := preload("res://game/net/wire.gd")
const CellBody := preload("res://game/normal/cell.gd")
const VISION := "res://game/vision/vision.tscn"
const RUN := "res://game/normal/normal_mode.tscn"
const FoodField := preload("res://game/normal/food.gd")

## Where the far cell rests between trials, off the near cell's nose. Where it
## is does not matter to a latency; that it is the same place every time does.
const REST := Vector2(0.0, -300.0)
const SETTLE_MIN := 1.2
const SETTLE_MAX := 1.8
const IMPULSE_WINDOW := 1.6
const TURN_WINDOW := 2.0
## The two levels, in world units of place and radians of heading. 2 units is a
## couple of pixels at the base shape; 20 is most of a body radius.
const PLACE_FIRST := 2.0
const PLACE_PLAIN := 20.0
## 0.05 rad is two steps of the wire's one-byte heading; 0.15 is nine degrees.
const TURN_FIRST := 0.05
const TURN_PLAIN := 0.15


## **`cell.gd`'s drawn controls, reduced to a steering demand.** The body reads
## `floating()`, `steer()` and `pushing()` off its `controls` every frame, which
## is the one way to steer one cell without steering every cell in the process
## through the global `Input`.
class Stick extends Node:
	const NONE := 0
	const DASH := 1
	var demand := 0.0

	func floating() -> bool:
		return false

	func steer() -> float:
		return demand

	func pushing() -> bool:
		return false

	func press(_index: int, _at: Vector2) -> int:
		return NONE

	func move(_index: int, _at: Vector2) -> bool:
		return false

	func release(_index: int) -> int:
		return NONE


## **The far run, reduced to the one thing a run does for the wire.** Its body
## is its child, so this reports before the body steps, exactly as
## `normal_mode.gd` -- the parent -- reports before its `Cell` child does.
class Reporter extends Node:
	var session: Node = null
	var cell: Node = null
	## True when the session takes a motion as well as a place: protocol 3.
	var rich := false

	func _process(_delta: float) -> void:
		report()

	func report() -> void:
		if rich:
			session.report_body(cell.position, cell.heading, cell.radius,
				cell.velocity, cell.heading_rate())
		else:
			session.report_body(cell.position, cell.heading, cell.radius)

	## `normal_mode.gd`'s `_on_impulsed`, which reports the body the moment it
	## jumps. Only on the new wire, because only the new run does it.
	func on_impulsed(_strength: float) -> void:
		report()


## **A network that is not a network.** Everything the near session receives
## comes through here instead of straight off ENet: held for a flight time,
## sometimes lost, and -- for a frame sent reliably -- resent after a timeout
## with everything behind it on the channel waiting for it, which is what ENet
## does and what a reliable heartbeat pays on a lossy link.
class Link extends Node:
	var target: Node = null
	var sender: Node = null
	var rng := RandomNumberGenerator.new()
	var flight_min := 0.010
	var flight_max := 0.050
	var loss := 0.02
	var spike_chance := 0.0
	var spike_min := 0.100
	var spike_max := 0.250
	var rto := 0.150
	var all_reliable := false
	var queue: Array = []
	var ticket := 0
	var reliable_free_at := 0.0
	var lost := 0
	var resent := 0
	var passed := 0

	func _init() -> void:
		process_priority = -1000

	func take(id: int, frame: PackedByteArray) -> void:
		var now := float(Time.get_ticks_usec()) / 1e6
		var reliable := all_reliable or not sender.has_method(&"_mode_for") \
			or int(sender.call(&"_mode_for", frame)) \
				== MultiplayerPeer.TRANSFER_MODE_RELIABLE
		var leaves := now
		var tries := 0
		while rng.randf() < loss:
			if not reliable:
				lost += 1
				return
			leaves += rto * pow(2.0, float(tries))
			tries += 1
			resent += 1
		var lands := leaves + _flight()
		if reliable:
			lands = maxf(lands, reliable_free_at)
			reliable_free_at = lands
		queue.append([lands, ticket, id, frame])
		ticket += 1

	func _flight() -> float:
		var d := rng.randf_range(flight_min, flight_max)
		if rng.randf() < spike_chance:
			d += rng.randf_range(spike_min, spike_max)
		return d

	func _process(_delta: float) -> void:
		if queue.is_empty():
			return
		var now := float(Time.get_ticks_usec()) / 1e6
		queue.sort_custom(func(a: Array, b: Array) -> bool:
			return float(a[0]) < float(b[0]) \
				or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
		while not queue.is_empty() and float(queue[0][0]) <= now:
			var due: Array = queue.pop_front()
			passed += 1
			target.call(&"_on_peer_packet", int(due[2]), due[3])


## **A host whose intake crosses the link model** (--swimmer=guest). A host
## reads its own socket (net-hardening.md A.1), so there is no signal to put
## the model on: each datagram it reads is handed to [member intake] instead,
## RAW byte taken off as the host would, and the link hands the frame to
## `_on_peer_packet` -- whose first statement is the gate -- when it lands.
class LaggedHost extends "res://game/net/net_session.gd":
	var intake: Node = null

	## [param via] is the listener it came in on (net-hardening.md C): this
	## tool's host has the LAN's alone, and anything else goes straight on.
	func _take_datagram(id: int, bytes: PackedByteArray, via: int = VIA_LAN) -> void:
		if intake == null or via != VIA_LAN or bytes.size() < 2 or bytes[0] != RAW:
			super._take_datagram(id, bytes, via)
			return
		intake.take(id, bytes.slice(1))


## **--pond: the two players kept safe and still, and the water watched.**
## First in every frame. The guest's cell is held where it was put, so the
## camera the timed view draws from does not wander; nothing is allowed to hunt
## or starve either player, and the guest's wound is the host's to reset, so a
## ten-minute measurement is not ended by the water. And every frame, while
## sampling: how far each water body in the guest's water is from where the
## host's water has it -- bodies well inside the send set, the version the
## mirror has, so a body not yet sent is not counted as a place error.
## **With --swimmer=guest it holds the host's cell instead**, and the guest's
## swims.
class Keeper extends Node:
	var guest_cell: Node = null
	var guest_at := Vector2.ZERO
	var hold_host := false
	var host_at := Vector2.ZERO
	var host_cell: Node = null
	var host_food: Node = null
	var guest_food: Node = null
	var host_metabolism: Node = null
	var guest_metabolism: Node = null
	var sampling := true
	var keep_wound := true
	var errors := PackedFloat32Array()
	## Both bodies' sizes, held: a meal grows a cell, and four of them divide
	## it, which takes it out of the water and ends every trial after.
	var guest_radius := 0.0
	var host_radius := 0.0

	func _init() -> void:
		process_priority = -500

	func _process(_delta: float) -> void:
		var held: Node = host_cell if hold_host else guest_cell
		held.position = host_at if hold_host else guest_at
		held.heading = 0.0
		held.velocity = Vector2.ZERO
		guest_cell.radius = guest_radius
		host_cell.radius = host_radius
		host_food.set(&"_first_hunt", FoodField.FIRST_DELAY)
		var p: Object = host_food.person()
		if p != null:
			p.set(&"first_hunt", FoodField.FIRST_DELAY)
			if keep_wound:
				host_food.bodies()[FoodField.PERSON_SLOT].wound = 0.0
		host_cell.wound = 0.0
		host_metabolism.set_hunger(0.0)
		guest_metabolism.set_hunger(0.0)
		if sampling:
			_sample()

	func _sample() -> void:
		var hosts: Array = host_food.bodies()
		var mirror: Array = guest_food.bodies()
		if mirror.size() < hosts.size() or hosts.size() <= FoodField.PERSON_SLOT:
			return
		var guest: Vector2 = hosts[FoodField.PERSON_SLOT].pos
		for i in FoodField.PERSON_SLOT:
			var h: Object = hosts[i]
			if not h.seeded:
				continue
			if (h.pos as Vector2).distance_to(guest) - float(h.radius) \
					> FoodField.SEND_REACH - 50.0:
				continue
			var m: Object = mirror[i]
			if not m.seeded or int(m.serial) != int(h.serial) & 0xFFFF:
				continue
			errors.append((m.pos as Vector2).distance_to(h.pos))


var _rng := RandomNumberGenerator.new()
var _far: Node = null
var _near: Node = null
var _reporter: Reporter = null
var _body: CellBody = null
var _stick: Stick = null
var _me: CellBody = null
var _view: Node = null
var _link: Link = null
var _each := false
var _rich := false
## --pond: the two runs, and what keeps them measurable.
var _pond := false
var _host_run: Node = null
var _guest_run: Node = null
var _keeper: Keeper = null
## --swimmer=guest: the guest's cell swims, and the host's intake has a link.
var _guest_swims := false
var _host_link: Link = null


func _ready() -> void:
	var link := "loopback"
	var trials := 40
	var events := PackedStringArray(["impulse", "turn"])
	var events_given := false
	var swim := 0.0
	var fps := 60
	var seed_value := 1
	var reliable := false
	var rto := 150.0
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--link="):
			link = text.trim_prefix("--link=")
		elif text.begins_with("--trials="):
			trials = int(text.trim_prefix("--trials="))
		elif text.begins_with("--events="):
			events = text.trim_prefix("--events=").split(",", false)
			events_given = true
		elif text.begins_with("--swim="):
			swim = float(text.trim_prefix("--swim="))
		elif text.begins_with("--fps="):
			fps = int(text.trim_prefix("--fps="))
		elif text.begins_with("--seed="):
			seed_value = int(text.trim_prefix("--seed="))
		elif text.begins_with("--rto="):
			rto = float(text.trim_prefix("--rto="))
		elif text == "--reliable":
			reliable = true
		elif text == "--each":
			_each = true
		elif text == "--pond":
			_pond = true
		elif text == "--swimmer=guest":
			_guest_swims = true
		elif text == "--swimmer=host":
			_guest_swims = false
	_guest_swims = _guest_swims and _pond
	Engine.max_fps = fps
	seed(seed_value)
	_rng.seed = seed_value

	if not await _open():
		print("[net-lag] FAILED to open a session")
		get_tree().quit(1)
		return
	_rich = _far.get_method_argument_count(&"report_body") >= 5
	print("[net-lag] protocol %d, %s wire, link %s%s, %d fps cap, seed %d%s"
		% [Wire.PROTOCOL, "motion-carrying" if _rich else "place-only", link,
			" (every frame reliable)" if reliable else "", fps, seed_value,
			" -- the shared pond, two real runs" if _pond else ""]
		+ (" -- the guest swims, and the host's intake crosses the link too"
			if _guest_swims else ""))
	if _pond:
		if not await _build_pond(link, reliable, rto / 1000.0):
			print("[net-lag] FAILED to put the guest in the pond")
			get_tree().quit(1)
			return
		if _guest_swims:
			if not events_given:
				events.clear()
		elif not events_given:
			events.append("bite")
	else:
		_build(link, reliable, rto / 1000.0)

	if events.has("impulse"):
		await _time_impulses(trials)
	if events.has("turn"):
		await _time_turns(trials)
	if _pond and events.has("bite"):
		await _time_bites(trials)
	if swim > 0.0 and _guest_swims:
		await _swim_guest(swim)
	elif swim > 0.0:
		await _swim(swim)
	if _pond:
		_summary("water, guest's body to host's", Array(_keeper.errors), "u")
		var sorted := Array(_keeper.errors)
		sorted.sort()
		if not sorted.is_empty():
			print("[net-lag] water p99 %.3f u, p99.9 %.3f u over %d body-frames"
				% [_pick(sorted, 0.99), _pick(sorted, 0.999), sorted.size()])
		var pond: Object = _host_run.get("_pond")
		print("[net-lag] POND: largest %d bytes of %d allowed, %d sent, %d genomes"
			% [int(pond.get("pond_bytes_max")), Wire.POND_MAX, int(pond.get("ponds_sent")),
				int(pond.get("genomes_sent"))])
	if _link != null:
		print("[net-lag] link: %d frames delivered, %d lost, %d resent"
			% [_link.passed, _link.lost, _link.resent])
	if _host_link != null:
		print("[net-lag] link into the host: %d frames delivered, %d lost, %d resent"
			% [_host_link.passed, _host_link.lost, _host_link.resent])
	print("[net-lag] done")
	get_tree().quit(0)


# ---------------------------------------------------------------------------
# Setting up: two sessions, one far body, one near screen.
# ---------------------------------------------------------------------------

func _open() -> bool:
	_far = LaggedHost.new() if _guest_swims else NetSession.new()
	_far.name = "Far"
	add_child(_far)
	_near = NetSession.new()
	_near.name = "Near"
	add_child(_near)
	if not _far.host() or not _near.join("127.0.0.1"):
		return false
	var until := _now() + 6.0
	while _now() < until:
		if int(_far.link) == NetSession.Link.TOGETHER \
				and int(_near.link) == NetSession.Link.TOGETHER:
			return true
		await get_tree().process_frame
	return false


func _build(link: String, reliable: bool, rto: float) -> void:
	_reporter = Reporter.new()
	_reporter.name = "FarRun"
	_reporter.session = _far
	_reporter.rich = _rich
	add_child(_reporter)
	_stick = Stick.new()
	_stick.name = "Stick"
	add_child(_stick)
	_body = CellBody.new()
	_body.name = "FarCell"
	_reporter.add_child(_body)
	_reporter.cell = _body
	_body.controls = _stick
	_body.set_process_unhandled_input(false)
	if _rich:
		_body.impulsed.connect(_reporter.on_impulsed)
	_rest()

	# The near player's own body: the view needs one to stand on, and it must
	# not swim, or the camera would wander off the thing being timed.
	_me = CellBody.new()
	_me.name = "NearCell"
	add_child(_me)
	_me.set_process(false)
	_me.set_process_unhandled_input(false)

	_view = (load(VISION) as PackedScene).instantiate()
	_view.bind(_me, null, null, null, null)
	add_child(_view)
	_view.set_session(_near)
	_view.set_active(true)
	_install_link(link, reliable, rto)


## The near session's intake, through the model -- or straight off ENet for
## plain loopback.
func _install_link(link: String, reliable: bool, rto: float) -> void:
	if link == "loopback" and not reliable:
		return
	_link = Link.new()
	_link.name = "Link"
	_link.rng.seed = _rng.randi()
	_link.target = _near
	_link.sender = _far
	_link.all_reliable = reliable
	_link.rto = rto
	if link == "rough":
		_link.loss = 0.05
		_link.spike_chance = 0.05
	elif link == "loopback":
		_link.flight_min = 0.0
		_link.flight_max = 0.0
		_link.loss = 0.0
	add_child(_link)
	var api: Object = _near.get(&"_api")
	api.disconnect(&"peer_packet", Callable(_near, &"_on_peer_packet"))
	api.connect(&"peer_packet", _link.take)


## **--pond: two real runs, one water.** The host's run first, on the far
## session, whose water becomes the pond; then the guest's on the near one,
## which opens inside it, held for the round trip. The link is in place before
## either, so every byte the guest takes in -- ARRIVE, the genomes, every POND
## and CONTACT -- crosses it. The host's run is in point of view, which costs no
## drawing; the guest's is in full vision, because its `_peer` is what is timed.
## The friend timed is the host's own cell, steered by the stick like the
## plain mode's far body.
func _build_pond(link: String, reliable: bool, rto: float) -> bool:
	_install_link(link, reliable, rto)
	if _guest_swims and link != "loopback":
		# The same model, dice of its own, on what the host reads.
		_host_link = Link.new()
		_host_link.name = "HostLink"
		_host_link.rng.seed = _rng.randi()
		_host_link.target = _far
		_host_link.sender = _near
		_host_link.all_reliable = reliable
		_host_link.rto = rto
		if link == "rough":
			_host_link.loss = 0.05
			_host_link.spike_chance = 0.05
		add_child(_host_link)
		(_far as LaggedHost).intake = _host_link
	NetSession.current = _far
	_host_run = (load(RUN) as PackedScene).instantiate()
	_host_run.set("mode", 0)
	_host_run.set("scheme", 0)
	add_child(_host_run)
	var until := _now() + 4.0
	while _now() < until and not bool(_near.peer_pond_open()):
		await get_tree().process_frame
	NetSession.current = _near
	_guest_run = (load(RUN) as PackedScene).instantiate()
	_guest_run.set("mode", 1)
	_guest_run.set("scheme", 0)
	add_child(_guest_run)
	var guest_pond: Object = _guest_run.get("_pond")
	until = _now() + 6.0
	while _now() < until and not bool(guest_pond.get("in_pond")):
		await get_tree().process_frame
	if not bool(guest_pond.get("in_pond")):
		return false
	_body = _host_run.get_node(^"Cell")
	_me = _guest_run.get_node(^"Cell")
	_view = _guest_run.get_node(^"Vision")
	_stick = Stick.new()
	_stick.name = "Stick"
	add_child(_stick)
	_body.controls = _stick
	_keeper = Keeper.new()
	_keeper.name = "Keeper"
	_keeper.guest_cell = _me
	_keeper.guest_at = _me.position
	_keeper.guest_radius = _me.radius
	_keeper.host_radius = _body.radius
	_keeper.host_cell = _body
	_keeper.host_food = _host_run.get_node(^"Food")
	_keeper.guest_food = _guest_run.get_node(^"Food")
	_keeper.host_metabolism = _host_run.get_node(^"Metabolism")
	_keeper.guest_metabolism = _guest_run.get_node(^"Metabolism")
	if _guest_swims:
		# The guest's cell is the one steered; the host's is held.
		_keeper.hold_host = true
		_keeper.host_at = _body.position
		_body.controls = _host_run.get(&"_controls")
		_me.controls = _stick
		add_child(_keeper)
		return true
	add_child(_keeper)
	_rest()
	return true


## The far body at rest, pointing somewhere new, with its own impulses held
## off so the only thing it does is the thing being timed. In a pond the rest
## is off the guest's nose, and the water is cleared round both players so a
## body drifting into either does not move the thing being timed.
func _rest() -> void:
	_stick.demand = 0.0
	if _pond:
		_body.position = _keeper.guest_at + REST
		_clear_round([_keeper.guest_at, _keeper.guest_at + REST], 150.0)
	else:
		_body.position = REST
	_body.velocity = Vector2.ZERO
	_body.heading = _rng.randf_range(-PI, PI)
	_body.set(&"_omega", 0.0)
	_body.set(&"_wander", 0.0)
	_body.set(&"_impulse_timer", 1e9)


# ---------------------------------------------------------------------------
# The two events.
# ---------------------------------------------------------------------------

func _time_impulses(trials: int) -> void:
	var first := []
	var plain := []
	var shift := []
	var fix := []
	var surge := []
	for trial in trials:
		_rest()
		await _wait(_rng.randf_range(SETTLE_MIN, SETTLE_MAX))
		var at := _now()
		var rest: Vector2 = _body.position
		var drawn_rest: Vector2 = _drawn_at()
		_body.call(&"_fire_impulse")
		_body.set(&"_impulse_timer", 1e9)
		var run := await _record(IMPULSE_WINDOW)
		var t: PackedFloat64Array = run[0]
		var truth: PackedVector2Array = run[1]
		var drawn: PackedVector2Array = run[3]
		var went := PackedFloat32Array()
		var seen := PackedFloat32Array()
		for i in t.size():
			went.append(truth[i].distance_to(rest))
			seen.append(drawn[i].distance_to(drawn_rest) if drawn[i].is_finite() else 0.0)
		var lag_first := _cross(t, seen, PLACE_FIRST, at) - _cross(t, went, PLACE_FIRST, at)
		var lag_plain := _cross(t, seen, PLACE_PLAIN, at) - _cross(t, went, PLACE_PLAIN, at)
		var best := _shift_place(t, truth, drawn, at, rest)
		first.append(lag_first * 1000.0)
		plain.append(lag_plain * 1000.0)
		shift.append(best * 1000.0)
		fix.append(float(run[5]))
		surge.append(float(run[6]))
		if _each:
			print("[net-lag]   impulse %2d  first %4.0f ms  plain %4.0f ms  shift %4.0f ms"
				% [trial, lag_first * 1000.0, lag_plain * 1000.0, best * 1000.0]
				+ "  largest correction %.2f u, largest leap %.2f u"
				% [float(run[5]), float(run[6])])
	_summary("impulse, first 2 u", first, "ms")
	_summary("impulse, plain 20 u", plain, "ms")
	_summary("impulse, best shift", shift, "ms")
	_summary("impulse, largest correction", fix, "u")
	_summary("impulse, largest leap", surge, "u/frame")


func _time_turns(trials: int) -> void:
	var first := []
	var plain := []
	var shift := []
	var fix := []
	for trial in trials:
		_rest()
		await _wait(_rng.randf_range(SETTLE_MIN, SETTLE_MAX))
		var at := _now()
		var rest: float = _body.heading
		var drawn_rest: float = _drawn_heading()
		_stick.demand = 1.0 if _rng.randf() < 0.5 else -1.0
		var run := await _record(TURN_WINDOW)
		_stick.demand = 0.0
		var t: PackedFloat64Array = run[0]
		var truth: PackedFloat32Array = run[2]
		var drawn: PackedFloat32Array = run[4]
		var went := PackedFloat32Array()
		var seen := PackedFloat32Array()
		for i in t.size():
			went.append(absf(angle_difference(rest, truth[i])))
			seen.append(absf(angle_difference(drawn_rest, drawn[i]))
				if is_finite(drawn[i]) else 0.0)
		var lag_first := _cross(t, seen, TURN_FIRST, at) - _cross(t, went, TURN_FIRST, at)
		var lag_plain := _cross(t, seen, TURN_PLAIN, at) - _cross(t, went, TURN_PLAIN, at)
		var best := _shift_turn(t, truth, drawn, at, rest)
		first.append(lag_first * 1000.0)
		plain.append(lag_plain * 1000.0)
		shift.append(best * 1000.0)
		fix.append(float(run[7]))
		if _each:
			print("[net-lag]   turn %2d  first %4.0f ms  plain %4.0f ms  shift %4.0f ms"
				% [trial, lag_first * 1000.0, lag_plain * 1000.0, best * 1000.0]
				+ "  largest heading correction %.4f rad" % float(run[7]))
	_summary("turn, first 0.05 rad", first, "ms")
	_summary("turn, plain 0.15 rad", plain, "ms")
	_summary("turn, best shift", shift, "ms")
	_summary("turn, largest correction", fix, "rad")


## **The far cell swimming as a cell does**: its own impulses on its own clock,
## and a steering demand that changes every 0.4-2.0 s. Measured frame by frame:
## how far the drawn friend is from the real one, how big each correction the
## view blends out is, and whether any of them lands in a single frame.
func _swim(seconds: float) -> void:
	_rest()
	_body.set(&"_impulse_timer", _rng.randf_range(0.6, 1.4))
	await _wait(1.5)
	var place_off := []
	var turn_off := []
	var fix := []
	var twist := []
	var surge := []
	var until := _now() + seconds
	var steer_at := _now()
	var last_truth: Vector2 = _body.position
	var last_drawn: Vector2 = _drawn_at()
	var impulses := [0]
	var count := func(_s: float) -> void: impulses[0] += 1
	_body.impulsed.connect(count)
	while _now() < until:
		if _now() >= steer_at:
			_stick.demand = [-1.0, -0.5, 0.0, 0.5, 1.0][_rng.randi_range(0, 4)]
			steer_at = _now() + _rng.randf_range(0.4, 2.0)
		await get_tree().process_frame
		var truth: Vector2 = _body.position
		var drawn: Vector2 = _drawn_at()
		if not drawn.is_finite():
			continue
		place_off.append(truth.distance_to(drawn))
		turn_off.append(absf(angle_difference(_body.heading, _drawn_heading())))
		var offset: Variant = _view.get(&"_peer_offset")
		if offset is Vector2:
			fix.append((offset as Vector2).length())
		var spin: Variant = _view.get(&"_peer_twist")
		if spin is float:
			twist.append(absf(float(spin)))
		surge.append((drawn - last_drawn).length() - (truth - last_truth).length())
		last_truth = truth
		last_drawn = drawn
	_body.impulsed.disconnect(count)
	_stick.demand = 0.0
	print("[net-lag] swim: %.0f s, %d impulses" % [seconds, int(impulses[0])])
	_summary("swim, drawn-to-true place", place_off, "u")
	_summary("swim, drawn-to-true heading", turn_off, "rad")
	if not fix.is_empty():
		_summary("swim, correction in flight", fix, "u")
	if not twist.is_empty():
		_summary("swim, heading correction", twist, "rad")
	_summary("swim, leap per frame", surge, "u")


## **--swimmer=guest: the guest swims, and the host's referee judges it**
## through the link. Its free sense is handed to it as an `ampulla`, the way the
## run's own grant would if it drew that one -- a held sample, placed -- so it
## calls every 8.8 s and each call is judged too. Its own impulses on its own
## clock, a steering demand that changes every 0.4-2.0 s. Then every foul the
## referee called and the closest call on each budget it keeps.
func _swim_guest(seconds: float) -> void:
	var genome: Node = _guest_run.get_node(^"Genome")
	_guest_run.set(&"_sensed", true)
	if not (genome.layout() as Array).has(&""):
		genome.bonus_slots += 1
	genome.gift(&"ampulla")
	genome.place((genome.layout() as Array).find(&""))
	var until := _now() + seconds
	var steer_at := _now()
	var impulses := [0]
	var count := func(_s: float) -> void: impulses[0] += 1
	_me.impulsed.connect(count)
	var from: Vector2 = _me.position
	var travelled := 0.0
	var last: Vector2 = _me.position
	while _now() < until:
		if _now() >= steer_at:
			_stick.demand = [-1.0, -0.5, 0.0, 0.5, 1.0][_rng.randi_range(0, 4)]
			steer_at = _now() + _rng.randf_range(0.4, 2.0)
		await get_tree().process_frame
		travelled += (_me.position as Vector2).distance_to(last)
		last = _me.position
	_me.impulsed.disconnect(count)
	_stick.demand = 0.0
	var pond: Object = _host_run.get("_pond")
	var referee: Object = pond.call("referee_of", 0)
	var counts: Dictionary = _far.gate_counts
	print("[net-lag] swim: the guest, %.0f s, %d impulses, %.0f units swum, %.0f from"
		% [seconds, int(impulses[0]), travelled, (_me.position as Vector2).distance_to(from)]
		+ " where it began; it wears %s" % str(genome.tiers()))
	if referee == null:
		print("[net-lag] referee: none -- the guest was not in the host's water")
		return
	var judged: Dictionary = referee.get("judged")
	print("[net-lag] referee: %d fouls (%d enforced, %d watched) over %d state frames,"
		% [int(counts["fouls"]), int(counts["referee_strikes"]),
			int(counts["referee_would_strikes"]), int(judged["state"])]
		+ " %d calls, %d bodies, %d arrivals; ledger points %.0f; %s"
		% [int(judged["shout"]), int(judged["person"]), int(judged["enter"]),
			float(counts["points"]), str(referee.get("called"))])
	for pair: Array in [["movement", referee.move, "u"], ["heading", referee.turn, "rad"],
			["calls", referee.shouts, ""], ["arrivals", referee.enters, ""],
			["bodies", referee.bodies, ""]]:
		var budget: Object = pair[1]
		print("[net-lag] referee budget %-9s closest call %5.1f%% -- %.2f a second, %.2f"
			% [str(pair[0]), 100.0 * float(budget.closest), float(budget.rate),
				float(budget.hold)] + " %s banked" % str(pair[2]))
	print("[net-lag] referee: fastest claimed %.0f u/s of %.0f, sharpest turn %.2f rad/s"
		% [float(referee.get("worst_speed")), float(referee.SPEED_MAX),
			float(referee.get("worst_turning"))]
		+ " of %.2f, radius at most %+.2f of what the host fed it"
		% [float(referee.TURNING_MAX), float(referee.get("worst_radius"))])


## **Bite to `hit`** (--pond): a chewer posed on the guest's flank in the
## host's water, at a random bearing and a random phase of every clock. Timed
## from the host's field deciding the bite -- `person_touched` -- to the guest's
## own field saying it, `bitten`, which is the call that raises the `hit`. The
## CONTACT is a reliable event, so on a lossy link a lost one waits out a
## resend, and that tail is the number to read.
func _time_bites(trials: int) -> void:
	var host_food: Node = _keeper.host_food
	var guest_food: Node = _keeper.guest_food
	var bit := [-1.0]
	var felt := [-1.0]
	var on_touch := func(what: int, _at: Vector2, _level: float, _by: int,
			_gene: StringName) -> void:
		if what == FoodField.Contact.BITTEN and bit[0] < 0.0:
			bit[0] = _now()
	var on_bitten := func(_bearing: float, _strength: float) -> void:
		if felt[0] < 0.0:
			felt[0] = _now()
	host_food.person_touched.connect(on_touch)
	guest_food.bitten.connect(on_bitten)
	_keeper.sampling = false
	var lags := []
	var slot := 3
	for trial in trials:
		_rest()
		await _wait(_rng.randf_range(0.25, 0.6))
		bit[0] = -1.0
		felt[0] = -1.0
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var bearing := side * _rng.randf_range(deg_to_rad(60.0), deg_to_rad(150.0))
		var guest: Vector2 = _keeper.guest_at
		# **Too big for the guest's mouth, which is wider than a drifter**: a
		# chewer the guest could swallow is a meal and not a bite -- and four
		# meals are a division.
		var at := guest + Vector2(sin(bearing), -cos(bearing)) * (float(_me.radius) + 27.0)
		var face := atan2((guest - at).x, -(guest - at).y)
		slot = 3 + trial % 20
		var b: Object = host_food.bodies()[slot]
		var until := _now() + 1.0
		while _now() < until and felt[0] < 0.0:
			b.radius = 30.0
			b.genome = {&"cytostome": 1, &"flagellum": 1}
			b.drifter = false
			b.seeded = true
			b.pos = at
			b.heading = face
			b.state = FoodField.State.DRIFT
			b.target = FoodField.TARGET_NONE
			b.calm = 999.0
			await get_tree().process_frame
		lags.append((felt[0] - bit[0]) * 1000.0 if bit[0] > 0.0 and felt[0] > 0.0 else INF)
		if _each or not is_finite(float(lags.back())):
			var pb: Object = host_food.bodies()[FoodField.PERSON_SLOT]
			print("[net-lag]   bite %2d  %4.0f ms%s" % [trial, float(lags.back()),
				"" if is_finite(float(lags.back())) else (
					"  -- no bite: host said %s, guest %s; guest life %d split %d;"
					% [bit[0] > 0.0, felt[0] > 0.0, int(_guest_run.get("_life")),
						int(_guest_run.get("_split"))]
					+ " person %s in water %s at %.0f from the chewer, chewer bite %.2f"
					% [host_food.person() != null, bool(pb.seeded),
						(pb.pos as Vector2).distance_to(b.pos), float(b.bite)])])
		host_food.call(&"_retire", slot)
	host_food.person_touched.disconnect(on_touch)
	guest_food.bitten.disconnect(on_bitten)
	_keeper.sampling = true
	_summary("bite to hit", lags, "ms")
	var sorted: Array = lags.filter(func(v: float) -> bool: return is_finite(v))
	sorted.sort()
	if not sorted.is_empty():
		print("[net-lag] bite to hit p99 %.0f ms" % _pick(sorted, 0.99))


## Retires every water body within [param reach] of any of [param points], in
## the host's water -- the only water there is.
func _clear_round(points: Array, reach: float) -> void:
	var bodies: Array = _keeper.host_food.bodies()
	for i in FoodField.PERSON_SLOT:
		var b: Object = bodies[i]
		if not b.seeded:
			continue
		for point: Vector2 in points:
			if (b.pos as Vector2).distance_to(point) < reach + float(b.radius):
				_keeper.host_food.call(&"_retire", i)
				break


# ---------------------------------------------------------------------------
# Recording and arithmetic.
# ---------------------------------------------------------------------------

## Every frame for [param seconds]: wall time, the far body's true place and
## heading, what the near view is drawing, the largest correction the view had
## in flight, and **the largest leap**: how much further the drawn body moved
## in one frame than the real one did. That is what a snap is -- a correction
## taken in one frame is a leap of its whole size -- and it is signed, so a
## drawing that is merely late (moving *less* than the body) never counts as
## one.
func _record(seconds: float) -> Array:
	var t := PackedFloat64Array()
	var place := PackedVector2Array()
	var heading := PackedFloat32Array()
	var drawn := PackedVector2Array()
	var drawn_heading := PackedFloat32Array()
	var fix := 0.0
	var surge := 0.0
	var twist := 0.0
	var until := _now() + seconds
	var last_truth: Vector2 = _body.position
	var last_drawn: Vector2 = _drawn_at()
	while _now() < until:
		await get_tree().process_frame
		t.append(_now())
		place.append(_body.position)
		heading.append(_body.heading)
		var at := _drawn_at()
		drawn.append(at)
		drawn_heading.append(_drawn_heading())
		var offset: Variant = _view.get(&"_peer_offset")
		if offset is Vector2:
			fix = maxf(fix, (offset as Vector2).length())
		var spin: Variant = _view.get(&"_peer_twist")
		if spin is float:
			twist = maxf(twist, absf(float(spin)))
		if at.is_finite() and last_drawn.is_finite():
			surge = maxf(surge, (at - last_drawn).length()
				- (_body.position - last_truth).length())
		last_truth = _body.position
		last_drawn = at
	return [t, place, heading, drawn, drawn_heading, fix, surge, twist]


func _drawn_at() -> Vector2:
	var mark: Dictionary = _view.get(&"_peer")
	if mark.is_empty():
		return Vector2(NAN, NAN)
	return mark["at"]


func _drawn_heading() -> float:
	var mark: Dictionary = _view.get(&"_peer")
	if mark.is_empty():
		return NAN
	return float(mark["heading"])


## The first time at or after [param from] that [param level] is reached,
## interpolated between the two frames either side of it. NAN if never.
func _cross(t: PackedFloat64Array, values: PackedFloat32Array, level: float,
		from: float) -> float:
	for i in range(1, t.size()):
		if t[i] < from or values[i] < level:
			continue
		if values[i - 1] >= level or t[i - 1] < from:
			return t[i]
		var f := (level - values[i - 1]) / maxf(values[i] - values[i - 1], 1e-9)
		return t[i - 1] + f * (t[i] - t[i - 1])
	return NAN


## The delay that best lines the drawn place up with the true one after
## [param from], by least squares over 0-1000 ms in 2 ms steps. Before the
## event the true body was at [param rest]. One pass per candidate: the moment
## looked back to only ever moves forward, so the lookup walks with it.
func _shift_place(t: PackedFloat64Array, truth: PackedVector2Array,
		drawn: PackedVector2Array, from: float, rest: Vector2) -> float:
	var best := 0.0
	var least := INF
	for step in 501:
		var lag := float(step) * 0.002
		var cost := 0.0
		var n := 0
		var j := 1
		for i in t.size():
			if t[i] < from or not drawn[i].is_finite():
				continue
			var when := t[i] - lag
			var back := rest
			if when > from:
				while j < t.size() - 1 and t[j] < when:
					j += 1
				var span := t[j] - t[j - 1]
				var f := 0.0 if span <= 0.0 else clampf((when - t[j - 1]) / span, 0.0, 1.0)
				back = truth[j - 1].lerp(truth[j], f)
			cost += back.distance_squared_to(drawn[i])
			n += 1
		if n > 0 and cost / float(n) < least:
			least = cost / float(n)
			best = lag
	return best


## The same for the heading, against where it rested.
func _shift_turn(t: PackedFloat64Array, truth: PackedFloat32Array,
		drawn: PackedFloat32Array, from: float, rest: float) -> float:
	var best := 0.0
	var least := INF
	for step in 501:
		var lag := float(step) * 0.002
		var cost := 0.0
		var n := 0
		var j := 1
		for i in t.size():
			if t[i] < from or not is_finite(drawn[i]):
				continue
			var when := t[i] - lag
			var back := rest
			if when > from:
				while j < t.size() - 1 and t[j] < when:
					j += 1
				var span := t[j] - t[j - 1]
				var f := 0.0 if span <= 0.0 else clampf((when - t[j - 1]) / span, 0.0, 1.0)
				back = lerp_angle(truth[j - 1], truth[j], f)
			var off := angle_difference(back, drawn[i])
			cost += off * off
			n += 1
		if n > 0 and cost / float(n) < least:
			least = cost / float(n)
			best = lag
	return best


func _summary(what: String, values: Array, unit: String) -> void:
	var clean: Array = []
	var missed := 0
	for v: float in values:
		if is_finite(v):
			clean.append(v)
		else:
			missed += 1
	if clean.is_empty():
		print("[net-lag] %-30s nothing measured (%d missed)" % [what, missed])
		return
	clean.sort()
	var total := 0.0
	for v: float in clean:
		total += v
	var digits := "%7.0f" if unit == "ms" else "%7.3f"
	var cells := PackedStringArray()
	for p: float in [0.0, 0.10, 0.25, 0.50, 0.75, 0.90, 1.0]:
		cells.append(digits % _pick(clean, p))
	print("[net-lag] %-30s n=%3d  min/p10/p25/p50/p75/p90/max %s  mean %s %s%s"
		% [what, clean.size(), " ".join(cells), (digits % (total / clean.size())).strip_edges(),
			unit, "" if missed == 0 else "  (%d never crossed)" % missed])


func _pick(sorted: Array, p: float) -> float:
	var at := p * float(sorted.size() - 1)
	var lo := int(floorf(at))
	var hi := mini(lo + 1, sorted.size() - 1)
	return lerpf(float(sorted[lo]), float(sorted[hi]), at - float(lo))


func _wait(seconds: float) -> void:
	var until := _now() + seconds
	while _now() < until:
		await get_tree().process_frame


func _now() -> float:
	return float(Time.get_ticks_usec()) / 1e6
