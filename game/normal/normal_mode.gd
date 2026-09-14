extends Node
## Normal mode: one cell, alone, in water. Drawn one of two ways.
##
## This node is only wiring. The cell knows nothing about the membrane, the
## membrane knows nothing about the cell, and everything that passes between
## them goes through the signal bus as a sensation -- which is what lets audio
## and haptics subscribe later without touching any of this.
##
## It is also the only place allowed to talk to the bus, which is why the food
## field and the predator compute their state and post nothing: the discipline
## that keeps positions off the bus is easier to hold when there is one door.
##
## It also owns [member mode], and that is the whole of the mode seam: the
## simulation is identical in both views and only the drawing differs. If a view
## ever changes how the cell behaves, full vision stops being evidence about
## point of view and there is no reason to have two.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const MembraneLayer := preload("res://game/perception/membrane.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
const VisionLayer := preload("res://game/vision/vision.gd")
const CellBody := preload("res://game/normal/cell.gd")
const MetabolismNode := preload("res://game/normal/metabolism.gd")
const MotesField := preload("res://game/normal/motes.gd")
const FoodField := preload("res://game/normal/food.gd")
const PredatorBody := preload("res://game/normal/predator.gd")
const RunState := preload("res://game/run_state.gd")

## Leaving a run goes back one step, to the screen that chose the view.
const MODE_SELECT_SCENE := "res://game/mode_select.tscn"

## The opening belongs to the beat alone, so the line waits its turn.
const ONBOARD_DELAY := 2.2
const ONBOARD_FADE_IN := 1.1
## Specced: fades over 0.8s the instant they first turn, never shown again.
const ONBOARD_FADE_OUT := 0.8

enum Onboard { OFF, WAITING, FADE_IN, HOLD, FADE_OUT }
## ALIVE, then the collapse, then the black that holds until they touch it,
## then the aperture opening on a new cell.
enum Life { ALIVE, DYING, WAITING, RETURNING }

## Which view this run is drawn with, as [enum RunState.Mode]. Set it before the
## scene enters the tree to override the remembered choice; left alone it picks
## up whatever the mode select last stored.
var mode := -1

@onready var _membrane: MembraneLayer = $Membrane
@onready var _bus := _membrane.bus
@onready var _cell: CellBody = $Cell
@onready var _metabolism: MetabolismNode = $Metabolism
@onready var _motes: MotesField = $Motes
@onready var _food: FoodField = $Food
@onready var _predator: PredatorBody = $Predator
@onready var _vision: VisionLayer = $Vision
@onready var _onboarding: Label = $Hud/Onboarding
@onready var _pause_ui: Control = $Hud/Pause
@onready var _resume_button: Button = $Hud/Pause/Center/Buttons/Resume
@onready var _leave_button: Button = $Hud/Pause/Center/Buttons/Leave
@onready var _gain_caption: Label = $Hud/Pause/Center/Buttons/Light/Caption
@onready var _gain_slider: HSlider = $Hud/Pause/Center/Buttons/Light/Slider

var _last_toggle_frame := -1
var _onboard := Onboard.OFF
var _onboard_clock := 0.0
var _onboard_from := 0.0

var _life := Life.ALIVE
var _death_clock := 0.0
var _death_loud := true
var _vision_cut := false


func _ready() -> void:
	# Android Back must pause, not kill the app. quit_on_go_back is a SceneTree
	# property as well as a project setting, so setting it here costs no project
	# setting change and therefore no binary_version bump.
	get_tree().quit_on_go_back = false

	_cell.impulsed.connect(_on_impulsed)
	_motes.struck.connect(_on_struck)
	_food.eaten.connect(_on_eaten)
	_predator.waked.connect(_on_waked)
	_predator.killed.connect(_on_killed)
	_motes.setup(_cell)
	_food.setup(_cell)
	_predator.setup(_cell)

	if mode < 0:
		mode = RunState.load_mode()
	_apply_mode()

	_style_pause()
	_pause_ui.hide()
	_resume_button.pressed.connect(_toggle_pause)
	_leave_button.pressed.connect(_leave)

	_bus.gain = clampf(RunState.load_gain(SignalBus.GAIN_DEFAULT),
		SignalBus.GAIN_MIN, SignalBus.GAIN_MAX)
	_gain_slider.value = _bus.gain
	_gain_slider.value_changed.connect(_on_gain_changed)
	_gain_slider.drag_ended.connect(_on_gain_settled)

	_begin_onboarding()
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())


func _process(delta: float) -> void:
	# This node runs while paused so it can hear Esc and Back, and the membrane
	# layer keeps beating under the pause scrim -- the cell is still alive, it is
	# just not going anywhere. Everything else below here stops.
	if get_tree().paused:
		return
	if _life != Life.ALIVE:
		_step_death(delta)
		return

	# Read once, post once. Nothing below carries a position.
	_metabolism.concentration = _food.concentration
	_bus.taste(_food.taste_bearing, _food.concentration)
	_bus.dread(_predator.dread_level)
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
	_bus.shear(_cell.shear_rate())
	_step_onboarding(delta)

	if _metabolism.starved():
		_die(false, 0.0)


func _on_impulsed(strength: float) -> void:
	_bus.thrust(strength)


## The mote's world position arrives with this and is deliberately dropped here.
## The bus carries sensations, and a sensation is a bearing and an intensity --
## never a position. The view that is allowed to know where things are listens
## to the field directly.
func _on_struck(bearing: float, strength: float, _at: Vector2) -> void:
	_bus.hit(bearing, strength)


## The moment of eating. Same contract: [param at] stops here.
##
## [param gene] is the **Phase 5 seam**. It is always &"" in Phase 4; when it is
## not, it goes into the ingest payload and tints the flood, and nothing else on
## this line moves.
func _on_eaten(nutrition: float, gene: StringName, _at: Vector2) -> void:
	if gene != &"":
		push_warning("[NormalMode] gene %s rolled, but Phase 5 is not built" % gene)
	_bus.ingest()
	_metabolism.feed(MetabolismNode.MEAL * nutrition)
	_cell.radius += CellBody.GROWTH_PER_MEAL


func _on_waked(bearing: float, strength: float) -> void:
	_bus.shove(bearing, strength)


func _on_killed(bearing: float) -> void:
	_die(true, bearing)


# ---------------------------------------------------------------------------
# Death. Two of them, and they feel opposite: predation slams the membrane shut
# at a bearing, starvation lets it sink with no bearing at all. Both end at the
# same black, which holds until the player touches the screen -- so there is a
# natural place to put the phone down. docs/design/food-and-predators.md §6.
# ---------------------------------------------------------------------------

func _die(loud: bool, bearing: float) -> void:
	if _life != Life.ALIVE:
		return
	_life = Life.DYING
	_death_loud = loud
	_death_clock = 0.0
	_vision_cut = false
	_set_simulating(false)
	_cell.release()
	if loud:
		# The sensation they already know, one last time.
		_bus.hit(bearing, 1.0)
	_bus.collapse(0.0, loud)


func _step_death(delta: float) -> void:
	_death_clock += delta
	match _life:
		Life.DYING, Life.WAITING:
			_bus.collapse(_death_clock, _death_loud)
			if not _vision_cut and _death_clock >= SignalBus.death_shut_at(_death_loud):
				# The world goes with the light, not before it: in full vision
				# the last thing on screen should be what killed you.
				_vision_cut = true
				_vision.set_active(false)
				_life = Life.WAITING
		Life.RETURNING:
			_bus.revive(_death_clock)
			if _death_clock >= SignalBus.DEATH_RETURN:
				_life = Life.ALIVE
				# The first beat on arrival: 2.4s and full strength, after
				# minutes of a slow faint one.
				_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
				_bus.pulse_now()
		_:
			pass


## A touch, a click or a key on the held black. Anything at all, because there
## is nothing on screen to aim at.
func _wake_up() -> void:
	_life = Life.RETURNING
	_death_clock = 0.0
	_cell.reset()
	_metabolism.reset()
	_motes.setup(_cell)
	_food.setup(_cell)
	_predator.setup(_cell)
	_set_simulating(true)
	_apply_mode()


## Stops the simulation without pausing the tree: the membrane layer and the
## world view both have to keep running through a death, one to draw it and one
## to fade out of it.
func _set_simulating(on: bool) -> void:
	for node: Node in [_cell, _metabolism, _motes, _food, _predator]:
		node.set_process(on)
	_cell.set_process_unhandled_input(on)


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
	if _life == Life.ALIVE:
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
			# Pausing a dead cell is nonsense, so Back during a death is the
			# exit -- straight out, skipping the pause screen.
			if _life != Life.ALIVE:
				_leave()
			else:
				_toggle_pause()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Switching apps mid-drag never delivers the release, and a pointer
			# stuck down means a cell that turns forever. Deliberately does not
			# pause: a pause screen nobody asked for is its own bug.
			_cell.release()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if _life != Life.ALIVE:
			_leave()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	# The dead membrane is waiting to be touched, and there is nothing on it to
	# aim at, so anything counts.
	if _life == Life.WAITING and _is_tap(event):
		_wake_up()
		get_viewport().set_input_as_handled()
		return
	if _life != Life.ALIVE:
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


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


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
	else:
		RunState.save_gain(_bus.gain)


## Back one step, to the view chooser. The launcher is one more Back from
## there, which keeps the whole stack reachable by the same gesture.
func _leave() -> void:
	get_tree().paused = false
	RunState.save_gain(_bus.gain)
	if not ResourceLoader.exists(MODE_SELECT_SCENE):
		push_error("[NormalMode] No mode select at %s" % MODE_SELECT_SCENE)
		_toggle_pause()
		return
	# Deferred: this arrives from a button press inside input propagation, and
	# the tree will not swap scenes out from under itself while it is busy.
	get_tree().change_scene_to_file.call_deferred(MODE_SELECT_SCENE)


# ---------------------------------------------------------------------------
# Membrane sensitivity, on the pause screen.
#
# Phase 4 is the first state where dimness is a *failure* rather than a mood: a
# starving, hunted cell renders at (6,23,23), and on an LCD phone in daylight
# that is close to invisible. The escape hatch already existed in the shader and
# in the bus; this is the first control that reaches it.
#
# It lives here rather than on a settings screen because this is where the
# problem is felt: the membrane is still beating behind the scrim, so the effect
# is visible live as the player drags, and it costs no new surface.
# ---------------------------------------------------------------------------

func _on_gain_changed(value: float) -> void:
	_bus.gain = clampf(value, SignalBus.GAIN_MIN, SignalBus.GAIN_MAX)


## Written once the thumb comes off, not sixty times a second on the way.
func _on_gain_settled(changed: bool) -> void:
	if changed:
		RunState.save_gain(_bus.gain)


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
##
## The light slider sits **above** resume in the same box, so it inherits the
## same 48px gap and nothing destructive ever sits under a dragging thumb.
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

	_gain_caption.add_theme_font_size_override("font_size", 16)
	_gain_caption.add_theme_color_override("font_color", Color(0.855, 0.953, 0.933, 0.52))

	_gain_slider.min_value = SignalBus.GAIN_MIN
	_gain_slider.max_value = SignalBus.GAIN_MAX
	_gain_slider.step = SignalBus.GAIN_STEP
	_gain_slider.custom_minimum_size = Vector2(232.0, 48.0)
	_gain_slider.focus_mode = Control.FOCUS_ALL
	_gain_slider.add_theme_constant_override("center_grabber", 1)
	_gain_slider.add_theme_stylebox_override("slider", _track(
		Color(0.063, 0.141, 0.125, 0.85), Color(0.12, 0.70, 0.58, 0.35)))
	# The filled part is the launcher's rim teal, so more light looks like more
	# membrane rather than like a progress bar.
	_gain_slider.add_theme_stylebox_override("grabber_area", _track(
		Color(0.12, 0.70, 0.58, 0.45), Color(0.12, 0.70, 0.58, 0.55)))
	_gain_slider.add_theme_stylebox_override("grabber_area_highlight", _track(
		Color(0.12, 0.70, 0.58, 0.70), Color(0.35, 0.88, 0.78, 0.85)))


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


func _track(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
	return box
