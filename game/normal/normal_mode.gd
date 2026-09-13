extends Node
## Normal mode: one cell, alone, in water. Drawn one of two ways.
##
## This node is only wiring. The cell knows nothing about the membrane, the
## membrane knows nothing about the cell, and everything that passes between
## them goes through the signal bus as a sensation -- which is what lets audio
## and haptics subscribe later without touching any of this.
##
## It also owns [member mode], and that is the whole of the mode seam: the
## simulation is identical in both views and only the drawing differs. If a view
## ever changes how the cell behaves, full vision stops being evidence about
## point of view and there is no reason to have two.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const MembraneLayer := preload("res://game/perception/membrane.gd")
const VisionLayer := preload("res://game/vision/vision.gd")
const CellBody := preload("res://game/normal/cell.gd")
const MetabolismNode := preload("res://game/normal/metabolism.gd")
const MotesField := preload("res://game/normal/motes.gd")
const RunState := preload("res://game/run_state.gd")

## Leaving a run goes back one step, to the screen that chose the view.
const MODE_SELECT_SCENE := "res://game/mode_select.tscn"

## The opening belongs to the beat alone, so the line waits its turn.
const ONBOARD_DELAY := 2.2
const ONBOARD_FADE_IN := 1.1
## Specced: fades over 0.8s the instant they first turn, never shown again.
const ONBOARD_FADE_OUT := 0.8

enum Onboard { OFF, WAITING, FADE_IN, HOLD, FADE_OUT }

## Which view this run is drawn with, as [enum RunState.Mode]. Set it before the
## scene enters the tree to override the remembered choice; left alone it picks
## up whatever the mode select last stored.
var mode := -1

@onready var _membrane: MembraneLayer = $Membrane
@onready var _bus := _membrane.bus
@onready var _cell: CellBody = $Cell
@onready var _metabolism: MetabolismNode = $Metabolism
@onready var _motes: MotesField = $Motes
@onready var _vision: VisionLayer = $Vision
@onready var _onboarding: Label = $Hud/Onboarding
@onready var _pause_ui: Control = $Hud/Pause
@onready var _resume_button: Button = $Hud/Pause/Center/Buttons/Resume
@onready var _leave_button: Button = $Hud/Pause/Center/Buttons/Leave

var _last_toggle_frame := -1
var _onboard := Onboard.OFF
var _onboard_clock := 0.0
var _onboard_from := 0.0


func _ready() -> void:
	# Android Back must pause, not kill the app. quit_on_go_back is a SceneTree
	# property as well as a project setting, so setting it here costs no project
	# setting change and therefore no binary_version bump.
	get_tree().quit_on_go_back = false

	_cell.impulsed.connect(_on_impulsed)
	_motes.struck.connect(_on_struck)
	_motes.setup(_cell)

	if mode < 0:
		mode = RunState.load_mode()
	_apply_mode()

	_style_pause()
	_pause_ui.hide()
	_resume_button.pressed.connect(_toggle_pause)
	_leave_button.pressed.connect(_leave)

	_begin_onboarding()
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())


func _process(delta: float) -> void:
	# This node runs while paused so it can hear Esc and Back, and the membrane
	# layer keeps beating under the pause scrim -- the cell is still alive, it is
	# just not going anywhere. Everything else below here stops.
	if get_tree().paused:
		return
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
	_bus.shear(_cell.shear_rate())
	_step_onboarding(delta)


func _on_impulsed(strength: float) -> void:
	_bus.thrust(strength)


## The mote's world position arrives with this and is deliberately dropped here.
## The bus carries sensations, and a sensation is a bearing and an intensity --
## never a position. The view that is allowed to know where things are listens
## to the field directly.
func _on_struck(bearing: float, strength: float, _at: Vector2) -> void:
	_bus.hit(bearing, strength)


# ---------------------------------------------------------------------------
# The mode seam. Two views, one simulation: the only thing that changes here is
# whether the world layer draws.
# ---------------------------------------------------------------------------

func _apply_mode() -> void:
	_vision.set_active(mode == RunState.Mode.FULL_VISION)


## Flips the view without leaving the run, so blind and sighted can be compared
## on the same cell in the same water. Deliberately not remembered: the mode
## select is the supported way to choose, and this is a comparison.
func _toggle_mode() -> void:
	mode = RunState.Mode.POV if mode == RunState.Mode.FULL_VISION else RunState.Mode.FULL_VISION
	_apply_mode()


# ---------------------------------------------------------------------------
# Onboarding: one line, first run only, and the only text in normal mode.
# ---------------------------------------------------------------------------

func _begin_onboarding() -> void:
	_onboarding.modulate.a = 0.0
	if _seen_onboarding():
		_onboarding.hide()
		_onboard = Onboard.OFF
		return
	_onboarding.text = "drag to turn" if _touch_first() else "A · D to turn"
	_onboarding.show()
	_onboard = Onboard.WAITING
	_onboard_clock = 0.0


func _step_onboarding(delta: float) -> void:
	if _onboard == Onboard.OFF:
		return

	# The instant they first turn, whatever the line is doing, it goes.
	if _onboard != Onboard.FADE_OUT and absf(_cell.steer) > CellBody.STEER_DEADZONE:
		_mark_onboarding_seen()
		_onboard_from = _onboarding.modulate.a
		_onboard_clock = 0.0
		_onboard = Onboard.FADE_OUT

	_onboard_clock += delta
	match _onboard:
		Onboard.WAITING:
			if _onboard_clock >= ONBOARD_DELAY:
				_onboard_clock = 0.0
				_onboard = Onboard.FADE_IN
		Onboard.FADE_IN:
			_onboarding.modulate.a = minf(_onboard_clock / ONBOARD_FADE_IN, 1.0)
			if _onboard_clock >= ONBOARD_FADE_IN:
				# It has been read. Even if they quit now, do not nag next run.
				_mark_onboarding_seen()
				_onboard_clock = 0.0
				_onboard = Onboard.HOLD
		Onboard.HOLD:
			# Stays until they turn. They have not learned the verb yet.
			pass
		Onboard.FADE_OUT:
			var t := minf(_onboard_clock / ONBOARD_FADE_OUT, 1.0)
			_onboarding.modulate.a = _onboard_from * (1.0 - t)
			if t >= 1.0:
				_onboarding.hide()
				_onboard = Onboard.OFF
		_:
			pass


## Which verb to name. Android is the only touch target we ship; a Windows
## machine with a touchscreen still has the keys, and the keys are the surer
## instruction there. Deliberately not asking the DisplayServer, which has no
## answer at all on a headless boot.
func _touch_first() -> bool:
	return OS.has_feature("mobile")


func _seen_onboarding() -> bool:
	return RunState.onboarding_seen()


func _mark_onboarding_seen() -> void:
	RunState.mark_onboarding_seen()


# ---------------------------------------------------------------------------
# Leaving. Back on Android, Esc on desktop; neither costs a pixel.
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_toggle_pause()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Switching apps mid-drag never delivers the release, and a pointer
			# stuck down means a cell that turns forever. Deliberately does not
			# pause: a pause screen nobody asked for is its own bug.
			_cell.release()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	# V flips the view. Desktop only by nature -- it costs no pixel and there is
	# no key on a phone, where the mode select is the way in.
	if get_tree().paused or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo \
			and (key.keycode == KEY_V or key.physical_keycode == KEY_V):
		_toggle_mode()
		get_viewport().set_input_as_handled()


## Guarded against arriving twice in one frame. Android has historically
## delivered Back as both a notification and a key event depending on the
## version, and two toggles in a frame would mean the pause screen never
## appears at all.
func _toggle_pause() -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_toggle_frame:
		return
	_last_toggle_frame = frame

	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_ui.visible = paused
	if paused:
		# A finger still down when the pause opened must not keep steering.
		_cell.release()
		_resume_button.grab_focus()


## Back one step, to the view chooser. The launcher is one more Back from
## there, which keeps the whole stack reachable by the same gesture.
func _leave() -> void:
	get_tree().paused = false
	if not ResourceLoader.exists(MODE_SELECT_SCENE):
		push_error("[NormalMode] No mode select at %s" % MODE_SELECT_SCENE)
		_toggle_pause()
		return
	# Deferred: this arrives from a button press inside input propagation, and
	# the tree will not swap scenes out from under itself while it is busy.
	get_tree().change_scene_to_file.call_deferred(MODE_SELECT_SCENE)


## Pause is the one screen in normal mode with widgets on it, so it is also the
## only place the 48px touch-target rule applies.
##
## The gap between the two buttons matters more than either button's size. They
## are 56 canvas px tall, which on a 2400x1080 phone is about 5.3mm -- under the
## ~9mm a thumb actually needs -- and the thing directly below "resume" is the
## one that ends the run. The VBox separation is 48 canvas px for that reason
## alone: it puts roughly 4.5mm of dead space between a safe tap and a
## destructive one, so a low tap on resume misses into nothing instead of
## leaving. Do not tighten it back up for looks.
func _style_pause() -> void:
	for button: Button in [_resume_button, _leave_button]:
		button.custom_minimum_size = Vector2(232.0, 56.0)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color(0.855, 0.953, 0.933, 0.82))
		button.add_theme_color_override("font_hover_color", Color(0.855, 0.953, 0.933, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.855, 0.953, 0.933, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_stylebox_override("normal", _slab(0.0))
		button.add_theme_stylebox_override("hover", _slab(0.35))
		button.add_theme_stylebox_override("pressed", _slab(0.5))
		button.add_theme_stylebox_override("focus", _slab(0.35))


func _slab(lift: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.063, 0.141, 0.125, 0.55 + lift * 0.5)
	box.border_color = Color(0.12, 0.70, 0.58, 0.35 + lift * 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box
