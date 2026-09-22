extends Node
## Photographs the earshot screen in each of the states a player can be in, and
## **drives it with real input events to get there** -- a touch, a mouse click
## and a keyboard chord, one of each, so the shot is evidence about the input
## path as well as about the layout.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##       --rendering-driver opengl3 res://tools/earshot_shot.tscn -- \
##       --page=answering --out=/tmp/a.png --size=1280x720
##
## Pages: `choose`, `calling`, `answering`, `together`, `refused`.
##
## `together` and `refused` need somebody on the other end, so this opens a
## second session of its own on the same machine and lets the screen's own tap
## code find it -- which makes those two shots an end-to-end test of the join
## and not a mock of it.
##
## Excluded from export (`tools/*` on both presets), so none of it ships.

const SCREEN := "res://game/net/earshot.tscn"
const NetSession := preload("res://game/net/net_session.gd")
const Lan := preload("res://game/net/lan.gd")
const Wire := preload("res://game/net/wire.gd")

var _screen: Control = null
var _other: Node = null


## A hard stop, so a harness that gets stuck is a failed run rather than a job
## that hangs until something kills it.
func _init() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 40.0
	watchdog.one_shot = true
	watchdog.autostart = true
	watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	watchdog.timeout.connect(_overran)
	add_child(watchdog)


func _overran() -> void:
	push_error("[earshot-shot] gave up waiting")
	get_tree().quit(1)


func _ready() -> void:
	var page := "choose"
	var out_path := "user://earshot.png"
	var wait := 1.0
	var size := Vector2i.ZERO
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--page="):
			page = text.trim_prefix("--page=")
		elif text.begins_with("--out="):
			out_path = text.trim_prefix("--out=")
		elif text.begins_with("--wait="):
			wait = float(text.trim_prefix("--wait="))
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				size = Vector2i(int(parts[0]), int(parts[1]))
	# Window only. Touching content_scale_size would override the project's
	# canvas_items/expand stretch and render 1:1 -- tools/shot.gd's own note.
	if size != Vector2i.ZERO:
		get_window().size = size

	var packed: PackedScene = load(SCREEN)
	_screen = packed.instantiate()
	get_tree().root.add_child.call_deferred(_screen)
	await _screen.ready
	get_tree().current_scene = _screen
	await _settle(0.4)

	match page:
		"calling":
			await _calling()
		"answering":
			await _answering()
		"together":
			await _together(Wire.PROTOCOL)
		"refused":
			await _together(Wire.PROTOCOL + 1)
		_:
			pass

	await _settle(wait)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_path) != OK:
		push_error("[earshot-shot] could not write %s" % out_path)
		get_tree().quit(1)
		return
	print("[earshot-shot] %s  %dx%d  page=%s" % [
		out_path, image.get_width(), image.get_height(), page])
	get_tree().quit()


## Press `call` with the mouse. A real click, through the theme's own button.
func _calling() -> void:
	await _click(_screen.get_node(^"Buttons/First"))
	await _settle(0.5)


## Press `answer` with a touch, then tap two bearings -- one with a finger, one
## with the keyboard -- so the half-finished code in the shot got there the way
## a player's would.
func _answering() -> void:
	await _touch(_screen.get_node(^"Buttons/Second"))
	await _settle(0.3)
	await _tap_bearing(7)
	await _settle(0.2)
	await _key_to(2)
	await _settle(0.3)


## Somebody on the other end: a second session, hosting, on this same machine.
## The screen then finds it with nothing but its own tap code and its own /24
## derivation, which is the whole join path end to end.
func _together(their_protocol: int) -> void:
	var host: Node = NetSession.new()
	host.name = "Other"
	host.protocol_override = their_protocol
	get_tree().root.add_child.call_deferred(host)
	await host.ready
	_other = host
	if not host.host():
		push_error("[earshot-shot] nothing to host on")
		return
	var code := Lan.code_for(Lan.octet_of(host.address))
	await _touch(_screen.get_node(^"Buttons/Second"))
	await _settle(0.3)
	for digit: int in code:
		await _tap_bearing(digit)
		await _settle(0.12)
	await _settle(2.0)


# ---------------------------------------------------------------------------
# Input, sent the way a device sends it.
# ---------------------------------------------------------------------------

func _tap_bearing(digit: int) -> void:
	var ring: Control = _screen.get_node(^"Ring")
	var bearing := Lan.bearing_of(digit)
	var radius := float(_screen.RING_RADIUS)
	var at: Vector2 = ring.global_position + ring.size * 0.5 \
		+ Vector2(sin(bearing), -cos(bearing)) * radius
	await _touch_at(at)


func _click(control: Control) -> void:
	var at := control.global_position + control.size * 0.5
	var where := _to_window(at)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = where
		event.global_position = where
		Input.parse_input_event(event)
		await get_tree().process_frame
	print("[earshot-shot] click at canvas %.0f,%.0f" % [at.x, at.y])


func _touch(control: Control) -> void:
	await _touch_at(control.global_position + control.size * 0.5)


func _touch_at(canvas: Vector2) -> void:
	var where := _to_window(canvas)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = where
		Input.parse_input_event(event)
		await get_tree().process_frame
	print("[earshot-shot] touch at canvas %.0f,%.0f" % [canvas.x, canvas.y])


## The keyboard path: walk the cursor round the ring with `ui_right` and commit
## with `ui_accept`. Built-in actions only -- a new InputMap action would be a
## project.godot change and therefore a binary bump.
func _key_to(digit: int) -> void:
	var ring: Control = _screen.get_node(^"Ring")
	ring.grab_focus()
	await get_tree().process_frame
	for i in Lan.BEARINGS:
		if int(_screen._cursor) == digit:
			break
		await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	print("[earshot-shot] keyed a tap at bearing %d" % digit)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _to_window(canvas: Vector2) -> Vector2:
	return canvas * get_viewport().get_screen_transform().get_scale() \
		+ get_viewport().get_screen_transform().get_origin()


func _settle(seconds: float) -> void:
	var spent := 0.0
	while spent < seconds:
		await get_tree().process_frame
		spent += 1.0 / 60.0
