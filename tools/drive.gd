extends Node
## Dev harness: boots a game scene and feeds it synthetic input, so states that
## only exist mid-play can be photographed and the input path itself gets
## exercised rather than assumed.
##
## Sits between tools/shot.tscn and the game:
##
##   godot --path . --rendering-driver opengl3 res://tools/shot.tscn -- \
##       --scene=res://tools/drive.tscn --hold=d --out=/tmp/turn.png --wait=4
##
## Arguments (all optional, all after the -- that shot.gd also reads):
##   --play=res://...        scene to drive, default normal mode
##   --mode=0|1              force the view: 0 point of view, 1 full vision
##   --hold=a|d              hold a steering key for the whole run
##   --drag=<pixels>         press near the middle and drag this far sideways
##   --drag-at=<seconds>     when to start that drag, default 0.5
##   --arm-at=<seconds>      ignore --freeze-on before this time
##   --esc-at=<seconds>      send Escape once, at this time
##   --back-at=<seconds>     fire NOTIFICATION_WM_GO_BACK_REQUEST exactly the
##                           way SceneTree does when Android Back is pressed
##   --tap=<seconds>:<key>   tap a key once at that time; repeatable. Keys are
##                           esc, enter, up, down, left, right, v
##   --freeze-on=<kind>      pause the tree a few frames after this sensation,
##                           so a flash or a beat can be caught at its peak
##   --freeze-delay=<n>      how many frames after it, default 2
##   --freeze-after=<secs>   seconds after it instead of frames, which is the
##                           only frame-rate-independent way to catch an
##                           envelope at its peak
##   --freeze-at=<seconds>   pause the tree at this time
##   --hunger=<0..1>         force the cell's hunger, to photograph what the
##                           starvation floor actually leaves on screen
##   --starve=<seconds>      seconds already spent at full hunger, so the end of
##                           the forty-second grace can be reached in one frame
##   --stalk=<units>         park the predator this far off the cell's front
##                           quarter and hold it there, so dread, a wake and a
##                           lunge can each be photographed at a known range
##   --food-at=<units>       same, for one food cell
##   --gain=<0.7..2.4>       hold membrane sensitivity here, to photograph what
##                           the pause screen's light slider actually buys
##   --hunt=<units>          spawn the predator this far off, once, and then let
##                           it hunt for itself. This is how the escape-window
##                           contract in the design doc gets measured, since it
##                           is made of time and cannot be photographed.
##   --trace=<seconds>       print range, state and dread on that interval
##   --forage                steer up the taste gradient, to measure §3.3's
##                           "a meal every 60 to 90 seconds" without a human
##   --evade                 play the escape contract in §5.4: hold full steer
##                           while the last wake bearing is ahead, release once
##                           it is astern, and do not waver. This is the only
##                           way to test a window that is made of time.
##   --seed=<int>            deterministic drift and impulses
##
## Prints every sensation the membrane bus receives with its timestamp, which is
## how the event bus gets checked end to end. Lives in tools/, which the export
## presets exclude, so none of this ships.

const DEFAULT_SCENE := "res://game/normal/normal_mode.tscn"

var _clock := 0.0
var _esc_at := -1.0
var _esc_sent := false
var _back_at := -1.0
## [[seconds, keycode], ...], consumed as the clock passes each one.
var _taps: Array = []
var _freeze_at := -1.0
var _freeze_on := ""
var _freeze_countdown := -1
var _freeze_delay := 2
var _freeze_after := -1.0
var _bus: Node = null
var _run: Node = null
var _metabolism: Node = null
var _predator: Node = null
var _food: Node = null
var _hunger := -1.0
var _starve := -1.0
var _stalk := -1.0
var _food_at := -1.0
var _gain := -1.0
var _hunt := -1.0
var _trace := -1.0
var _trace_clock := 0.0
var _evade := false
## World angle of the last wake, so the body-relative bearing can be recomputed
## as the cell turns instead of going stale the moment it does.
var _wake_world := 0.0
var _have_wake := false
var _evade_key := KEY_NONE
var _forage := false
var _taste_bearing := 0.0
var _taste_c := 0.0
var _forage_key := KEY_NONE
var _meals := 0
var _drag_px := 0.0
var _drag_at := 0.5
var _drag_step := 0
## The freeze-on trigger ignores sensations before this time, so a later beat
## can be caught instead of the first one.
var _arm_at := 0.0
## -1 leaves the scene to pick up whatever the mode select last stored.
var _mode := -1


func _ready() -> void:
	# The game pauses the tree; the driver has to keep running through it or it
	# could never press anything on a pause screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# And it has to run *after* the game, so that anything it holds in place --
	# a parked predator, a forced hunger -- survives the frame it set it in.
	process_priority = 1000

	var scene_path := DEFAULT_SCENE
	var hold := ""
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--play="):
			scene_path = text.trim_prefix("--play=")
		elif text.begins_with("--hold="):
			hold = text.trim_prefix("--hold=").to_lower()
		elif text.begins_with("--drag="):
			_drag_px = float(text.trim_prefix("--drag="))
		elif text.begins_with("--drag-at="):
			_drag_at = float(text.trim_prefix("--drag-at="))
		elif text.begins_with("--arm-at="):
			_arm_at = float(text.trim_prefix("--arm-at="))
		elif text.begins_with("--esc-at="):
			_esc_at = float(text.trim_prefix("--esc-at="))
		elif text.begins_with("--back-at="):
			_back_at = float(text.trim_prefix("--back-at="))
		elif text.begins_with("--tap="):
			var parts := text.trim_prefix("--tap=").split(":")
			if parts.size() == 2:
				_taps.append([float(parts[0]), _keycode(parts[1])])
		elif text.begins_with("--freeze-at="):
			_freeze_at = float(text.trim_prefix("--freeze-at="))
		elif text.begins_with("--freeze-on="):
			_freeze_on = text.trim_prefix("--freeze-on=")
		elif text.begins_with("--freeze-delay="):
			_freeze_delay = int(text.trim_prefix("--freeze-delay="))
		elif text.begins_with("--freeze-after="):
			_freeze_after = float(text.trim_prefix("--freeze-after="))
		elif text.begins_with("--mode="):
			_mode = int(text.trim_prefix("--mode="))
		elif text.begins_with("--hunger="):
			_hunger = float(text.trim_prefix("--hunger="))
		elif text.begins_with("--starve="):
			_starve = float(text.trim_prefix("--starve="))
		elif text.begins_with("--stalk="):
			_stalk = float(text.trim_prefix("--stalk="))
		elif text.begins_with("--food-at="):
			_food_at = float(text.trim_prefix("--food-at="))
		elif text.begins_with("--gain="):
			_gain = float(text.trim_prefix("--gain="))
		elif text.begins_with("--hunt="):
			_hunt = float(text.trim_prefix("--hunt="))
		elif text.begins_with("--trace="):
			_trace = float(text.trim_prefix("--trace="))
		elif text == "--evade":
			_evade = true
		elif text == "--forage":
			_forage = true
		elif text.begins_with("--seed="):
			seed(int(text.trim_prefix("--seed=")))

	if not ResourceLoader.exists(scene_path):
		push_error("[drive] no scene at %s" % scene_path)
		get_tree().quit(1)
		return
	var scene: PackedScene = load(scene_path)
	var run := scene.instantiate()
	if _mode >= 0:
		# Set before the scene enters the tree, which is where it is read.
		run.set("mode", _mode)
		print("[drive] mode forced to ", _mode)
	add_child(run)
	_run = run
	_metabolism = _find_script(self, "res://game/normal/metabolism.gd")
	_predator = _find_script(self, "res://game/normal/predator.gd")
	_food = _find_script(self, "res://game/normal/food.gd")

	_bus = _find_bus(self)
	if _bus != null:
		_bus.sensation.connect(_on_sensation)
	else:
		print("[drive] no membrane bus found under ", scene_path)

	if _hunger >= 0.0 and _metabolism != null:
		_metabolism.set_hunger(_hunger)
		if _starve >= 0.0:
			_metabolism.starve_seconds = _starve
		print("[drive] hunger forced to %.2f -> beat %.2fs at %.2f strength" % [
			_hunger, _metabolism.beat_period(), _metabolism.beat_amplitude()])

	if _stalk >= 0.0 and _predator != null:
		_predator.enter(_hold_point(_stalk, 40.0))
		print("[drive] predator parked at %.0f units" % _stalk)
	if _hunt >= 0.0 and _predator != null:
		_predator.enter(_hold_point(_hunt, 40.0))
		print("[drive] predator hunting from %.0f units" % _hunt)
	if _food_at >= 0.0 and _food != null:
		print("[drive] food parked at %.0f units" % _food_at)

	if hold == "a" or hold == "d":
		_send_key(KEY_A if hold == "a" else KEY_D, true)
		print("[drive] holding ", hold.to_upper())


func _process(delta: float) -> void:
	_clock += delta
	_hold_world()
	_step_forage()
	_step_evade()
	_step_trace(delta)

	if _freeze_countdown > 0:
		_freeze_countdown -= 1
		if _freeze_countdown == 0:
			_freeze()

	if _esc_at >= 0.0 and not _esc_sent and _clock >= _esc_at:
		_esc_sent = true
		_send_key(KEY_ESCAPE, true)
		_send_key(KEY_ESCAPE, false)
		print("[drive] %5.2f  esc" % _clock)

	for i in range(_taps.size() - 1, -1, -1):
		if _clock >= float(_taps[i][0]):
			var code: Key = _taps[i][1]
			_send_key(code, true)
			_send_key(code, false)
			print("[drive] %5.2f  tap %d" % [_clock, code])
			_taps.remove_at(i)

	if _back_at >= 0.0 and _clock >= _back_at:
		_back_at = -1.0
		print("[drive] %5.2f  back (quit_on_go_back=%s)" % [
			_clock, get_tree().quit_on_go_back])
		get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)

	if _drag_px != 0.0 and _clock >= _drag_at:
		_step_drag()

	if _freeze_at >= 0.0 and _clock >= _freeze_at:
		_freeze_at = -1.0
		_freeze()


## Turn until the taste sits at the top. The dumbest possible forager, which is
## the point: if this cannot feed itself the field is too thin for a person.
func _step_forage() -> void:
	if not _forage:
		return
	# Evading wins. A hunted cell cannot smell its way out of the problem, and
	# it should not try to eat its way out either.
	var want := KEY_NONE
	if _evade_key == KEY_NONE and _taste_c > 0.06 and absf(_taste_bearing) > 0.15:
		want = KEY_D if _taste_bearing > 0.0 else KEY_A
	if want == _forage_key:
		return
	if _forage_key != KEY_NONE:
		_send_key(_forage_key, false)
	if want != KEY_NONE:
		_send_key(want, true)
	_forage_key = want


## Commit away from the wake and stay committed. Turns until the threat is 130
## degrees off the nose, then holds course until it drifts back inside 100 --
## the hysteresis is what "does not waver" means, and wavering is what §5.4 says
## actually costs players the window.
func _step_evade() -> void:
	if not _evade or not _have_wake or _run == null:
		return
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null:
		return
	var rel: float = angle_difference(cell.heading, _wake_world)
	var want := KEY_NONE
	if _evade_key != KEY_NONE:
		if absf(rel) < deg_to_rad(130.0):
			want = _evade_key
	elif absf(rel) < deg_to_rad(100.0):
		# Wake to starboard: turn to port, and the other way round.
		want = KEY_A if rel > 0.0 else KEY_D
	if want == _evade_key:
		return
	if _evade_key != KEY_NONE:
		_send_key(_evade_key, false)
	if want != KEY_NONE:
		_send_key(want, true)
		print("[drive] %5.2f  evade %s (threat %+6.1f deg)" % [
			_clock, "port" if want == KEY_A else "starboard", rad_to_deg(rel)])
	else:
		print("[drive] %5.2f  evade committed (threat %+6.1f deg)" % [
			_clock, rad_to_deg(rel)])
	_evade_key = want


func _step_trace(delta: float) -> void:
	if _trace <= 0.0 or _predator == null or _run == null:
		return
	_trace_clock += delta
	if _trace_clock < _trace:
		return
	_trace_clock = 0.0
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null:
		return
	var d: float = cell.position.distance_to(_predator.position)
	print("[trace] %6.2f  range %7.1f  dread %.3f  hunting %s  heading %+6.1f" % [
		_clock, d, _predator.dread_level, _predator.hunting(),
		rad_to_deg(cell.heading)])


## Parks whatever the shot needs at a fixed body-relative bearing and range.
## Runs after the simulation has moved, so the range is exact in the frame that
## is photographed. This is the harness reaching into the world on purpose; the
## game itself has no such hook and must not grow one.
func _hold_world() -> void:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return
	if _stalk >= 0.0 and _predator != null:
		_predator.position = _hold_point(_stalk, 40.0)
	if _food_at >= 0.0 and _food != null:
		# Packed arrays are copy-on-write, so the accessor cannot be written
		# through -- the harness has to hand a whole array back. Reaching for a
		# private member is a thing only tools/ is allowed to do.
		var points: PackedVector2Array = _food.get("_pos")
		if points.size() > 0:
			points[0] = _hold_point(_food_at, -35.0)
			_food.set("_pos", points)
	if _starve >= 0.0 and _metabolism != null:
		_metabolism.starve_seconds = maxf(_metabolism.starve_seconds, _starve)
	if _gain >= 0.0 and _bus != null:
		_bus.gain = _gain


func _hold_point(distance: float, bearing_deg: float) -> Vector2:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return Vector2.ZERO
	var b := deg_to_rad(bearing_deg)
	var dir: Vector2 = cell.forward() * cos(b) + cell.starboard() * sin(b)
	return cell.position + dir * distance


## Press once, then walk sideways a few frames: the same shape of event stream a
## thumb produces, including the mouse events Godot emulates from touch.
func _step_drag() -> void:
	var mid := get_viewport().get_visible_rect().size * 0.5
	if _drag_step == 0:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.pressed = true
		down.position = mid
		Input.parse_input_event(down)
	elif _drag_step <= 8:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = mid + Vector2(_drag_px * _drag_step / 8.0, 0.0)
		Input.parse_input_event(drag)
	_drag_step += 1


## Pausing the tree freezes the simulation, but the membrane layer deliberately
## keeps beating through a pause -- so for a photograph the bus has to be made
## pausable first, or the envelopes decay away while the shot harness waits.
func _freeze() -> void:
	if get_tree().paused:
		return
	# The game deliberately keeps its membrane and its run node alive through a
	# pause. For a photograph everything under the scene has to stop, or the
	# envelopes decay and the death sequence runs on while the shot harness is
	# still waiting.
	if _run != null:
		_make_pausable(_run)
	if _bus != null:
		_bus.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	print("[drive] %5.2f  frozen" % _clock)


func _make_pausable(node: Node) -> void:
	if node.process_mode == Node.PROCESS_MODE_ALWAYS:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	for child in node.get_children():
		_make_pausable(child)


func _on_sensation(kind: StringName, info: Dictionary) -> void:
	var bearing := ""
	if info.has("bearing"):
		bearing = "  bearing %+6.1f deg" % rad_to_deg(float(info["bearing"]))
	var strength := ""
	if info.has("strength"):
		strength = "  strength %.2f" % float(info["strength"])
	# Parked food would be eaten again every frame, which grows the cell and
	# empties its hunger while the shot harness is still waiting. One meal is
	# what was wanted.
	if kind == &"ingest":
		_food_at = -1.0
		_meals += 1
		print("[drive] %5.2f  meal %d" % [_clock, _meals])
	if kind == &"taste":
		_taste_bearing = float(info.get("bearing", 0.0))
		_taste_c = float(info.get("strength", 0.0))
	if kind == &"shove" and _run != null:
		var cell := _find_node_with(_run, &"bearing_to")
		if cell != null:
			_wake_world = cell.heading + float(info.get("bearing", 0.0))
			_have_wake = true
	# taste fires every frame by design; only the interesting ones are worth a line.
	if kind == &"taste" or kind == &"shear":
		return
	print("[drive] %5.2f  %-7s%s%s" % [_clock, kind, bearing, strength])
	if _freeze_on != "" and str(kind) == _freeze_on and _clock >= _arm_at:
		if _freeze_after >= 0.0:
			if _freeze_at < 0.0:
				_freeze_at = _clock + _freeze_after
		elif _freeze_countdown < 0:
			_freeze_countdown = maxi(_freeze_delay, 1)


func _keycode(name: String) -> Key:
	match name.to_lower():
		"esc": return KEY_ESCAPE
		"enter": return KEY_ENTER
		"up": return KEY_UP
		"down": return KEY_DOWN
		"left": return KEY_LEFT
		"right": return KEY_RIGHT
		"v": return KEY_V
		_: return KEY_NONE


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


## The bus is a node called Signals under the membrane layer; found by walking
## rather than by path so this keeps working if the scene is rearranged.
func _find_bus(node: Node) -> Node:
	return _find_node_with(node, &"set_beat")


## By script path, because two fields can share a method name and the harness
## needs a specific one.
func _find_script(node: Node, path: String) -> Node:
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path == path:
		return node
	for child in node.get_children():
		var found := _find_script(child, path)
		if found != null:
			return found
	return null


func _find_node_with(node: Node, method: StringName) -> Node:
	if node.has_method(method):
		return node
	for child in node.get_children():
		var found := _find_node_with(child, method)
		if found != null:
			return found
	return null
