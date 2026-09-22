extends Control
## Within earshot: the screen where two cells find each other, and the only
## place in this game that has ever asked a player for an address.
##
## **It asks for it in bearings.** There is no `LineEdit` here and there will
## not be one: the reasoning is in lan.gd, and the short version is that the
## launcher's theme has no style for a text field and Android would raise a soft
## keyboard over a landscape-locked canvas to fill it. So the host shows four
## marks on a ring and the guest taps them back. Four taps, twelve bearings, and
## the fourth is a check digit -- a mis-tap is caught here, instantly, instead of
## becoming a four-second wait for an address nobody is at.
##
## The ring is drawn in `ampulla` violet on purpose. It is the same colour the
## ping wears everywhere else in the game, because it is the same thing: one
## cell saying *here* in the only vocabulary the fiction has.
##
## Same visual language as the launcher and the view chooser, deliberately.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const RunState := preload("res://game/run_state.gd")
const NetSession := preload("res://game/net/net_session.gd")
const Lan := preload("res://game/net/lan.gd")

const NORMAL_SCENE := "res://game/normal/normal_mode.tscn"
const MODE_SELECT_SCENE := "res://game/mode_select.tscn"

## Which of the five things this screen is at any moment.
enum Page { CHOOSE, CALLING, ANSWERING, TOGETHER, TROUBLE }

## Well over the 48px minimum, and paired far enough apart that a low tap on one
## lands in dead space rather than on the other -- the same rule the view
## chooser and the pause column are built to.
const BUTTON_SIZE := Vector2(264.0, 56.0)

## The ring the code is written on. 160px puts 84px of arc under each of the
## twelve bearings and 156px of radial band behind it, so every target is over
## three times the 48px minimum in its tight direction.
const RING_RADIUS := 160.0
const HIT_INNER := 62.0
const HIT_OUTER := 218.0
## Half the arc a code mark is drawn over: 11 degrees inside a 30 degree sector,
## so two adjacent marks never touch and the gaps read as gaps.
const MARK_HALF_DEG := 11.0

# --- The palette, and it is the membrane's ----------------------------------
## `ampulla`'s violet, copied from signal_bus.gd's PING_COLOR rather than
## imported: this is a menu, and a menu may not preload the perception stack.
const CODE_COLOR := Color(0.655, 0.44, 1.0)
## The launcher's dim rim green, the same one the view chooser's heading wears.
const RING_COLOR := Color(0.404, 0.639, 0.588)

## How long each mark of the code is lit as the walk goes round, and how long
## the walk rests at the end before starting again. The rest is what tells a
## reader where the code begins.
const WALK_STEP := 0.62
const WALK_REST := 1.1

@onready var _heading: Label = $Heading
@onready var _ring: Control = $Ring
@onready var _line: Label = $Line
@onready var _receipt: Label = $Receipt
@onready var _first: Button = $Buttons/First
@onready var _second: Button = $Buttons/Second
@onready var _hint: Label = $Hint

var _page := Page.CHOOSE
var _session: Node = null
## The four digits the host is showing, or empty.
var _code := PackedInt32Array()
## The digits the guest has tapped so far, up to four.
var _taps := PackedInt32Array()
## Where the keyboard's cursor is sitting on the ring.
var _cursor := 0
var _keyed := false
var _clock := 0.0
var _leaving := false


func _ready() -> void:
	# Android Back must walk back to the view chooser, not kill the app.
	get_tree().quit_on_go_back = false

	_ring.mouse_filter = Control.MOUSE_FILTER_STOP
	_ring.focus_mode = Control.FOCUS_ALL
	_ring.draw.connect(_draw_ring)
	_ring.gui_input.connect(_on_ring_input)

	for button: Button in [_first, _second]:
		button.custom_minimum_size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_ALL
	_first.pressed.connect(_on_first)
	_second.pressed.connect(_on_second)

	_hint.text = "back leaves" if _touch_first() else "esc leaves"
	# A session can already be open: leaving a run walks back through the view
	# chooser, which closes it, but arriving here twice in one sitting must not
	# find a stale one either.
	_session = NetSession.current
	if _session != null and is_instance_valid(_session):
		_session.link_changed.connect(_on_link_changed)
		_follow_link()
	else:
		_go_to(Page.CHOOSE)


func _process(delta: float) -> void:
	_clock += delta
	# The walking mark, the quiet-peer clock and nothing else. One redraw a
	# frame on a menu with an animated background already behind it.
	if _page == Page.CALLING or _page == Page.TOGETHER:
		_ring.queue_redraw()
	if _page == Page.CALLING or _page == Page.TOGETHER:
		_say_line()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _page == Page.ANSWERING and not _taps.is_empty():
		_undo_tap()
		return
	_back()


# ---------------------------------------------------------------------------
# The pages.
# ---------------------------------------------------------------------------

func _go_to(page: int) -> void:
	_page = page
	_clock = 0.0
	match page:
		Page.CHOOSE:
			_heading.text = "within earshot"
			_line.text = "two cells on one wi-fi, one of them calling"
			_receipt.text = _here_says()
			_button(_first, "call")
			_button(_second, "answer")
			_first.grab_focus()
		Page.CALLING:
			_heading.text = "show this"
			_line.text = "waiting for an answer"
			_receipt.text = _here_says()
			_button(_first, "stop")
			_button(_second, "")
			_first.grab_focus()
		Page.ANSWERING:
			_heading.text = "tap their code"
			_receipt.text = ""
			_button(_first, "back one")
			_button(_second, "")
			_ring.grab_focus()
			_say_taps()
		Page.TOGETHER:
			_heading.text = "answered"
			_line.text = "within earshot"
			_receipt.text = ""
			_button(_first, "full vision")
			_button(_second, "point of view")
			var last := RunState.load_mode()
			var start: Button = _second if last == RunState.Mode.POV else _first
			start.grab_focus()
		Page.TROUBLE:
			var said := ""
			var why := ""
			if _session != null and is_instance_valid(_session):
				said = _session.trouble
				why = _session.because
			_heading.text = said if not said.is_empty() else "no answer"
			_line.text = why
			_receipt.text = ""
			_button(_first, "again")
			_button(_second, "leave")
			_first.grab_focus()
	_ring.queue_redraw()


## What the link is doing, turned into which page is on screen. The screen reads
## the session and never the other way round, so a link that drops for any
## reason lands the player somewhere that explains itself.
func _follow_link() -> void:
	if _session == null or not is_instance_valid(_session):
		_go_to(Page.CHOOSE)
		return
	match int(_session.link):
		NetSession.Link.LISTENING:
			_go_to(Page.CALLING)
		NetSession.Link.REACHING:
			_go_to(Page.ANSWERING)
		NetSession.Link.TOGETHER:
			_go_to(Page.TOGETHER)
		NetSession.Link.REFUSED, NetSession.Link.FAILED:
			_go_to(Page.TROUBLE)
		_:
			_go_to(Page.CHOOSE)


func _on_link_changed(_link: int) -> void:
	_follow_link()


func _on_first() -> void:
	match _page:
		Page.CHOOSE:
			_call_out()
		Page.CALLING:
			_stop()
		Page.ANSWERING:
			_undo_tap()
		Page.TOGETHER:
			_play(RunState.Mode.FULL_VISION)
		Page.TROUBLE:
			_again()


func _on_second() -> void:
	match _page:
		Page.CHOOSE:
			_answer()
		Page.TOGETHER:
			_play(RunState.Mode.POV)
		Page.TROUBLE:
			_back()


# ---------------------------------------------------------------------------
# Calling and answering.
# ---------------------------------------------------------------------------

func _open_session() -> Node:
	if _session != null and is_instance_valid(_session):
		return _session
	var node: Node = NetSession.new()
	node.name = "NetSession"
	# Parented to the window root rather than to this scene, so it outlives the
	# change into the run. Not deferred: this only ever runs from a button
	# press, and root is not busy adding children then.
	get_tree().root.add_child(node)
	node.link_changed.connect(_on_link_changed)
	_session = node
	return node


func _call_out() -> void:
	var session := _open_session()
	if not session.host():
		_go_to(Page.TROUBLE)
		return
	_code = Lan.code_for(Lan.octet_of(session.address))
	_go_to(Page.CALLING)


func _answer() -> void:
	_open_session()
	_taps = PackedInt32Array()
	_cursor = 0
	_go_to(Page.ANSWERING)


## Try the same thing again rather than dropping the player back at the fork:
## whichever half of the call they were on is the half they still want, and
## after a version refusal they are going to want it once more after an update.
func _again() -> void:
	var was_host := false
	if _session != null and is_instance_valid(_session):
		was_host = bool(_session.hosting)
	_stop()
	if was_host:
		_call_out()
	else:
		_answer()


func _stop() -> void:
	NetSession.close_current()
	_session = null
	_code = PackedInt32Array()
	_taps = PackedInt32Array()
	_go_to(Page.CHOOSE)


func _tap(digit: int) -> void:
	if _page != Page.ANSWERING or _taps.size() >= Lan.DIGITS:
		return
	_taps.append(digit)
	_cursor = digit
	if _taps.size() < Lan.DIGITS:
		_say_taps()
		_ring.queue_redraw()
		return
	var octet := Lan.octet_for(_taps)
	if octet < 0:
		# The check digit earning its tap: a mis-tap dies here, in front of the
		# player, instead of two seconds later as "no answer".
		_taps = PackedInt32Array()
		_line.text = "that is not a code. tap it again."
		_ring.queue_redraw()
		return
	_line.text = "reaching"
	_ring.queue_redraw()
	# An empty address is handed straight to `join`, which owns the sentence for
	# a device that has no network to be on. The screen does not write the
	# session's messages; it reads them.
	_session.join(Lan.host_address(Lan.local_address(), octet))


func _undo_tap() -> void:
	if _taps.is_empty():
		return
	_taps.remove_at(_taps.size() - 1)
	_say_taps()
	_ring.queue_redraw()


func _say_taps() -> void:
	if _session != null and is_instance_valid(_session) \
			and int(_session.link) == NetSession.Link.REACHING:
		# The taps are all in and the socket is out looking. Saying so beats
		# four filled dots, which look like a screen that has stopped.
		_line.text = "reaching"
		return
	var dots := ""
	for i in Lan.DIGITS:
		dots += "●" if i < _taps.size() else "○"
		if i < Lan.DIGITS - 1:
			dots += "  "
	_line.text = dots


func _say_line() -> void:
	if _session == null or not is_instance_valid(_session):
		return
	if _page == Page.TOGETHER:
		var says: String = _session.peers_say()
		_line.text = says if not says.is_empty() else "within earshot"
		return
	# Hosting. A refusal we handed out is worth saying: it is the only way the
	# person with the update to install finds out they need it.
	var trouble: String = _session.trouble
	_line.text = trouble if not trouble.is_empty() else "waiting for an answer"


func _here_says() -> String:
	var here := Lan.local_address()
	if here.is_empty():
		return "no network here"
	return "%s · %d" % [here, Lan.PORT]


# ---------------------------------------------------------------------------
# Leaving.
# ---------------------------------------------------------------------------

func _play(mode: int) -> void:
	if _leaving:
		return
	RunState.save_mode(mode)
	if not ResourceLoader.exists(NORMAL_SCENE):
		push_error("[Earshot] No game at %s" % NORMAL_SCENE)
		return
	_leaving = true
	# The session is deliberately left open and under `/root`: it is what the
	# run picks up, and closing it here would be closing the feature.
	get_tree().change_scene_to_file.call_deferred(NORMAL_SCENE)


func _back() -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(MODE_SELECT_SCENE):
		push_error("[Earshot] No chooser at %s" % MODE_SELECT_SCENE)
		return
	_leaving = true
	NetSession.close_current()
	_session = null
	# Deferred for the reason mode_select.gd's own _back() documents at length:
	# swapping the scene from inside Back's own notification propagation is the
	# tree telling you it is busy.
	get_tree().change_scene_to_file.call_deferred(MODE_SELECT_SCENE)


# ---------------------------------------------------------------------------
# The ring: drawing it, and being tapped on it.
# ---------------------------------------------------------------------------

func _on_ring_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _emulated(touch):
			_tap_at(touch.position)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
				and not _emulated(click):
			_tap_at(click.position)
		return
	# The keyboard and the joypad walk the cursor round the ring. No new
	# InputMap action: `ui_left`, `ui_right` and `ui_accept` are engine
	# built-ins, and a new action would be a project.godot change and therefore
	# a binary bump.
	if not event.is_pressed():
		return
	if event.is_action(&"ui_left") or event.is_action(&"ui_right"):
		var step := -1 if event.is_action(&"ui_left") else 1
		_cursor = posmod(_cursor + step, Lan.BEARINGS)
		_keyed = true
		_ring.accept_event()
		_ring.queue_redraw()
	elif event.is_action(&"ui_accept"):
		_keyed = true
		_ring.accept_event()
		_tap(_cursor)


## **One finger is one tap.** `emulate_mouse_from_touch` is on by default, so a
## single touch on Android arrives here twice -- once as the touch and once as a
## mouse button synthesised from it -- and a discrete action taken twice enters
## the wrong code and blames the player. Rendered and counted: the answering
## screen showed three taps for two fingers before this line existed.
##
## Both real paths stay live rather than leaning on the emulation, so this is
## still right if the setting is ever off.
func _emulated(event: InputEvent) -> bool:
	return event.device == InputEvent.DEVICE_ID_EMULATION


func _tap_at(where: Vector2) -> void:
	if _page != Page.ANSWERING:
		return
	var offset := where - _ring.size * 0.5
	var distance := offset.length()
	if distance < HIT_INNER or distance > HIT_OUTER:
		return
	_keyed = false
	# Bearing clockwise from straight up, which is `cell.gd`'s convention and
	# the membrane's: the ring reads the way the water does.
	_tap(Lan.digit_at(atan2(offset.x, -offset.y)))


func _draw_ring() -> void:
	var middle := _ring.size * 0.5
	var half := deg_to_rad(MARK_HALF_DEG)
	# The ring, and then the twelve places on it, drawn as segments rather than
	# as ticks: a tap target the player cannot see is a tap target they will not
	# use, and a dial of twelve reads as *choose one of these* at a glance.
	# Rendered first as hairline ticks, which read as decoration.
	# Halved on the trouble page: there is nothing to tap there and the sentence
	# under it is the only thing worth reading.
	var dial := 0.16 if _page == Page.TROUBLE else 0.32
	_ring.draw_arc(middle, RING_RADIUS, 0.0, TAU, 96,
		Color(RING_COLOR, dial * 0.5), 2.0, true)
	for digit in Lan.BEARINGS:
		var mid := _arc_of(digit)
		_ring.draw_arc(middle, RING_RADIUS, mid - half, mid + half, 16,
			Color(RING_COLOR, dial), 6.0, true)
		if _page == Page.ANSWERING and _keyed and digit == _cursor:
			# Where the keyboard is standing. Outside the ring, so it never
			# covers a mark, and drawn only once a key has been pressed.
			_ring.draw_line(_point(middle, digit, RING_RADIUS + 12.0),
				_point(middle, digit, RING_RADIUS + 26.0),
				Color(RING_COLOR, 0.85), 3.0, true)

	var marks := _marks()
	if marks.is_empty():
		return
	var walking := _walking(marks.size())
	# The thread, inside the ring, in tapping order. It is what says which mark
	# is first without putting a number anywhere near the code.
	for i in marks.size() - 1:
		_ring.draw_line(_point(middle, marks[i], RING_RADIUS - 30.0),
			_point(middle, marks[i + 1], RING_RADIUS - 30.0),
			Color(CODE_COLOR, 0.26), 2.0, true)
	for i in marks.size():
		# Brightest first, dimmest last: a second, static reading of the order,
		# for anyone who does not wait for the walk to come round.
		var fade := 1.0 - 0.16 * float(i)
		var alpha := 1.0 if i == walking else 0.80 * fade
		var width := 12.0 if i == walking else 8.0
		var mid := _arc_of(marks[i])
		_ring.draw_arc(middle, RING_RADIUS, mid - half, mid + half, 20,
			Color(CODE_COLOR, alpha), width, true)


## A digit's bearing, in the angle `draw_arc` measures in.
##
## `draw_arc` places a point at `cos(t), sin(t)`; a ring bearing places one at
## `sin(b), -cos(b)`, clockwise from straight up. Those are the same point when
## `t = b - PI/2`, and the quarter turn is the whole of the conversion. Getting
## the sign of `b` wrong here mirrors the code about the vertical axis, which
## draws a perfectly plausible pattern that is not the one the thread runs
## through -- rendered, seen, fixed.
func _arc_of(digit: int) -> float:
	return Lan.bearing_of(digit) - PI * 0.5


## The digits to draw: the host's code, or the guest's taps so far.
func _marks() -> PackedInt32Array:
	if _page == Page.CALLING or (_page == Page.TOGETHER and not _code.is_empty()):
		return _code
	if _page == Page.ANSWERING or _page == Page.TOGETHER:
		return _taps
	return PackedInt32Array()


## Which mark the walk is on, or -1 while it is resting. The rest is the whole
## of how a reader knows where the code starts.
func _walking(count: int) -> int:
	if count <= 0 or _page == Page.ANSWERING:
		return -1
	var cycle := WALK_STEP * float(count) + WALK_REST
	var at := fmod(_clock, cycle)
	var step := int(at / WALK_STEP)
	return step if step < count else -1


func _point(middle: Vector2, digit: int, radius: float) -> Vector2:
	var bearing := Lan.bearing_of(digit)
	# Straight up is digit 0, and clockwise from there -- `cell.gd`'s forward().
	return middle + Vector2(sin(bearing), -cos(bearing)) * radius


func _button(button: Button, text: String) -> void:
	button.text = text
	button.visible = not text.is_empty()


## Which verb to name. Deliberately not asking the DisplayServer, which has no
## answer at all on a headless boot.
func _touch_first() -> bool:
	return OS.has_feature("mobile")
