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
##   --hold=a|d              hold a steering key for the whole run
##   --drag=<pixels>         press near the middle and drag this far sideways
##   --drag-at=<seconds>     when to start that drag, default 0.5
##   --arm-at=<seconds>      ignore --freeze-on before this time
##   --esc-at=<seconds>      send Escape once, at this time
##   --back-at=<seconds>     fire NOTIFICATION_WM_GO_BACK_REQUEST exactly the
##                           way SceneTree does when Android Back is pressed
##   --tap=<seconds>:<key>   tap a key once at that time; repeatable. Keys are
##                           esc, enter, up, down, left, right
##   --freeze-on=<kind>      pause the tree a few frames after this sensation,
##                           so a flash or a beat can be caught at its peak
##   --freeze-delay=<n>      how many frames after it, default 2
##   --freeze-at=<seconds>   pause the tree at this time
##   --hunger=<0..1>         force the cell's hunger, to photograph what the
##                           starvation floor actually leaves on screen
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
var _bus: Node = null
var _hunger := -1.0
var _drag_px := 0.0
var _drag_at := 0.5
var _drag_step := 0
## The freeze-on trigger ignores sensations before this time, so a later beat
## can be caught instead of the first one.
var _arm_at := 0.0


func _ready() -> void:
	# The game pauses the tree; the driver has to keep running through it or it
	# could never press anything on a pause screen.
	process_mode = Node.PROCESS_MODE_ALWAYS

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
		elif text.begins_with("--hunger="):
			_hunger = float(text.trim_prefix("--hunger="))
		elif text.begins_with("--seed="):
			seed(int(text.trim_prefix("--seed=")))

	if not ResourceLoader.exists(scene_path):
		push_error("[drive] no scene at %s" % scene_path)
		get_tree().quit(1)
		return
	var scene: PackedScene = load(scene_path)
	add_child(scene.instantiate())

	_bus = _find_bus(self)
	if _bus != null:
		_bus.sensation.connect(_on_sensation)
	else:
		print("[drive] no membrane bus found under ", scene_path)

	if _hunger >= 0.0:
		var metabolism := _find_node_with(self, &"beat_period")
		if metabolism != null:
			metabolism.set_hunger(_hunger)
			print("[drive] hunger forced to %.2f -> beat %.2fs at %.2f strength" % [
				_hunger, metabolism.beat_period(), metabolism.beat_amplitude()])

	if hold == "a" or hold == "d":
		_send_key(KEY_A if hold == "a" else KEY_D, true)
		print("[drive] holding ", hold.to_upper())


func _process(delta: float) -> void:
	_clock += delta

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
	if _bus != null:
		_bus.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	print("[drive] %5.2f  frozen" % _clock)


func _on_sensation(kind: StringName, info: Dictionary) -> void:
	var bearing := ""
	if info.has("bearing"):
		bearing = "  bearing %+6.1f deg" % rad_to_deg(float(info["bearing"]))
	var strength := ""
	if info.has("strength"):
		strength = "  strength %.2f" % float(info["strength"])
	# taste fires every frame by design; only the interesting ones are worth a line.
	if kind == &"taste" or kind == &"shear":
		return
	print("[drive] %5.2f  %-7s%s%s" % [_clock, kind, bearing, strength])
	if _freeze_on != "" and str(kind) == _freeze_on and _freeze_countdown < 0 \
			and _clock >= _arm_at:
		_freeze_countdown = maxi(_freeze_delay, 1)


func _keycode(name: String) -> Key:
	match name.to_lower():
		"esc": return KEY_ESCAPE
		"enter": return KEY_ENTER
		"up": return KEY_UP
		"down": return KEY_DOWN
		"left": return KEY_LEFT
		"right": return KEY_RIGHT
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


func _find_node_with(node: Node, method: StringName) -> Node:
	if node.has_method(method):
		return node
	for child in node.get_children():
		var found := _find_node_with(child, method)
		if found != null:
			return found
	return null
