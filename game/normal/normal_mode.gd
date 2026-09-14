extends Node
## Normal mode: one cell, alone, in water. Drawn one of two ways.
##
## This node is only wiring. The cell knows nothing about the membrane, the
## membrane knows nothing about the cell, and everything that passes between
## them goes through the signal bus as a sensation -- which is what lets audio
## and haptics subscribe later without touching any of this.
##
## It is also the only place allowed to talk to the bus, which is why the food
## field and the genome compute their state and post nothing: the discipline
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
const GenomeNode := preload("res://game/normal/genome.gd")
const RunState := preload("res://game/run_state.gd")
## The genome strip draws the same organs, in the same hues, as the water does.
## One vocabulary: §2.4's promise is that a point-of-view player who looks in
## the mirror already speaks the language if they ever switch views.
const Cilia := preload("res://game/vision/cilia.gd")

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
@onready var _genome: GenomeNode = $Genome
@onready var _vision: VisionLayer = $Vision
@onready var _onboarding: Label = $Hud/Onboarding
@onready var _pause_ui: Control = $Hud/Pause
@onready var _resume_button: Button = $Hud/Pause/Center/Buttons/Resume
@onready var _leave_button: Button = $Hud/Pause/Center/Buttons/Leave
@onready var _gain_caption: Label = $Hud/Pause/Center/Buttons/Light/Caption
@onready var _gain_slider: HSlider = $Hud/Pause/Center/Buttons/Light/Slider
@onready var _genome_caption: Label = $Hud/Pause/Center/Buttons/Genome/Caption
@onready var _genome_row: HBoxContainer = $Hud/Pause/Center/Buttons/Genome/Row
@onready var _genome_hint: Label = $Hud/Pause/Center/Buttons/Genome/Hint

## Which slot is armed, or -1. Arming is reversible and that is why a mis-tap
## costs nothing, which is in turn why 20px between tiles is acceptable.
var _armed := -1
## Milliseconds, from Time, not an accumulated delta: the strip only exists
## while the tree is paused, and a paused tree hands this node a delta for a
## frame in which nothing else moved.
var _armed_at := 0
## The gene in each slot, left to right, index-matched to the tiles in Row.
var _slot_genes: Array[StringName] = []

var _last_toggle_frame := -1
var _onboard := Onboard.OFF
var _onboard_clock := 0.0
var _onboard_from := 0.0

var _life := Life.ALIVE
## A tap that arrived during the collapse, waiting for the black to be ready.
var _tap_pending := false
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
	_food.waked.connect(_on_waked)
	_food.killed.connect(_on_killed)
	# The two halves of one cell, introduced here and nowhere else: the body
	# reads its drive constants out of the genome, and the genome takes its
	# capacity from the body's radius.
	_cell.genome = _genome
	_motes.setup(_cell)
	_food.setup(_cell)
	_genome.setup(_cell)

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
	# Death is checked BEFORE pause, and the order is the point. The bus stops
	# stepping its own envelopes while dying, so collapse()/revive() are the only
	# writers of every uniform -- which means a frame that skips them does not
	# pause the death, it freezes the membrane mid-collapse with nothing left to
	# move it. Pausing while dying is not reachable today, but it is one stray
	# code path away, and the failure is permanent rather than cosmetic.
	if _life != Life.ALIVE:
		_step_death(delta)
		return
	if get_tree().paused:
		# The genome strip is the one thing on screen that still has a clock
		# running: an armed slot lapses after four seconds whether or not the
		# simulation is moving. §5.2.
		_step_arming()
		return

	# Read once, post once. Nothing below carries a position.
	_metabolism.concentration = _food.concentration
	_metabolism.upkeep = _genome.upkeep()
	_bus.taste(_food.taste_bearing, _food.concentration)
	_bus.dread(_food.dread_level)
	# The stigma only reports if the cell has grown one. The field works out
	# what the water is doing either way -- what is out there is not a function
	# of which organs are watching -- and this is where the organ is consulted.
	var eye := _cell.tier(&"stigma")
	_bus.light(_food.shadow_bearing, _food.shadow if eye > 0 else 0.0, eye)
	_bus.hold(_genome.held_remaining if _genome.held_sample != &"" else 0.0)
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
## [param gene] is what the prey was most made of (§3.4), and it is the only
## thing about the meal the cell is entitled to know besides how much of it
## there was. It goes into the genome and into the ingest payload, which is
## where the flood picks up its colour (§2.2) -- a payload is still not a
## position, so it is allowed on the bus.
##
## [param nutrition] is already the prey's size measured against this body and
## clamped (food.gd, §3.2). MEAL stays the constant it always was and this is
## the call site that scales it: a big meal fills more of the bar, and the bar
## is the beat.
func _on_eaten(nutrition: float, gene: StringName, _at: Vector2) -> void:
	# A meal cannot arrive for a cell that is already dying. Not reachable
	# today -- the field stops the frame the kill lands -- but this signal is
	# not idempotent, and feeding and growing a corpse would be silent.
	if _life != Life.ALIVE:
		return
	# **Grow, then integrate, in that order.** The radius is the slot ladder, so
	# taking the meal's gene against the pre-meal radius means the meal that
	# unlocks a slot is exactly the meal that cannot fill it: it comes back with
	# nowhere to go, becomes a held sample, and lapses beside an empty slot --
	# a state §3.3 and §5.2 both assume cannot happen. food.gd's _devour() grows
	# first for the same reason, and genome.gd's docstring promises there is
	# only one definition of this rule.
	_cell.radius += CellBody.GROWTH_PER_MEAL
	_genome.integrate(gene)
	# The flood takes the gene's hue (§2.2), which is the one place a gene is
	# ever identified on the sensory screen -- a contact event, chemistry
	# already inside you, bounded to this one signal and this one frame. The
	# colour is resolved here rather than in the bus so there stays exactly one
	# table of gene hues, and it is the table the body is drawn from.
	var payload := {"gene": gene}
	if gene != &"":
		payload["color"] = Cilia.hue(gene)
	_bus.ingest(payload)
	_metabolism.feed(MetabolismNode.MEAL * nutrition)


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
	_tap_pending = false
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
				# Someone already reached for it mid-collapse. Honour it now
				# rather than making them tap a second time.
				if _tap_pending:
					_tap_pending = false
					_wake_up()
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
	_genome.setup(_cell)
	_set_simulating(true)
	_apply_mode()


## Stops the simulation without pausing the tree: the membrane layer and the
## world view both have to keep running through a death, one to draw it and one
## to fade out of it.
func _set_simulating(on: bool) -> void:
	for node: Node in [_cell, _metabolism, _motes, _food, _genome]:
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
	# A tap during the collapse is latched rather than dropped. Being killed is
	# the most startling thing in the game and the likeliest moment for a reflex
	# tap, and the aperture takes up to 2.6s to shut -- long enough that a player
	# who reacts immediately would otherwise get no response at all and conclude
	# the game had stopped listening. Honoured the instant WAITING begins.
	if _life == Life.DYING and _is_tap(event):
		_tap_pending = true
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
		# Built on opening rather than kept in step: the genome cannot change
		# while the tree is paused except by the two taps below, and a strip
		# rebuilt sixty times a second to say the same thing is five nodes of
		# churn a frame for nothing.
		_disarm()
		_build_genome_strip()
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
##
## **`Light`, `Resume` and `Leave` are shrink-centred**, here and in the scene.
## They used to inherit the VBox's width, which is the width of the widest thing
## in it -- and with a seven-slot genome strip above them that is 652px.
## Rendered, and it looked wrong; at 232 they stay the buttons Phase 4 shipped
## whatever is above them.
func _style_pause() -> void:
	for control: Control in [_gain_slider.get_parent(), _resume_button, _leave_button]:
		control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_genome_caption.add_theme_font_size_override("font_size", 15)
	_genome_caption.add_theme_color_override("font_color",
		Color(0.855, 0.953, 0.933, 0.45))
	_genome_hint.add_theme_font_size_override("font_size", 14)
	_genome_hint.add_theme_color_override("font_color",
		Color(0.855, 0.953, 0.933, 0.38))

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


# ---------------------------------------------------------------------------
# The genome strip, on the pause screen. docs/design/genes-and-cilia.md §5.
#
# **A launcher-themed panel, not the membrane aesthetic.** The membrane is what
# the cell feels; a panel is what the player consults, and the launcher theme
# marks every surface where the player rather than the cell is being addressed.
# This surface is not sensory -- it is a representation, it needs touch targets
# and it needs words, all three of which the sensory screen forbids.
#
# It lives on pause because pause already has widgets, already has the house
# style and is already reachable by a gesture the player knows. It costs no new
# input, no new pixels in play and no new binary.
#
# Always visible as a readout; interactive only while a sample is held.
# ---------------------------------------------------------------------------

## Touch rule is 48; 76 is what the organ needs to be legible under a word.
const TILE_SIZE := 76.0
const ARROW_SIZE := Vector2(30.0, 76.0)
## The second tap cannot land sooner than this after the first, so a double-tap
## -- or the mouse event Godot emulates from a touch -- cannot commit.
const ARM_GUARD_MS := 300
## Arming lapses on its own, so a strip left armed is not a trap.
const ARM_TIMEOUT_MS := 4000

## Every word Phase 5 adds to the screen is here or on a tile. perception.md
## §6.1's one string in normal mode is untouched.
const HINT_ARM := "tap a slot to replace it"
const HINT_COMMIT := "tap again to integrate"

## **The plain word, never the biological name.** Four short verbs are parsed
## instantly at arm's length; nine letters of Greek are not, on the one screen
## whose whole job is a quick decision. §5.2, and the nine-character ceiling it
## sets is why a new gene needs a short word as well as a real organ name.
const WORDS := {
	&"cytostome": "eat", &"cirrus": "turn", &"flagellum": "swim",
	&"stigma": "see",
}

enum Tile { OCCUPIED, EMPTY, HELD, ARMED }

## Tile states (§5.2). PanelContainer plus StyleBoxFlat, corner radius 8.
const TILE_BG: Array[Color] = [
	Color(0.063, 0.141, 0.125, 0.62),  # occupied
	Color(0.047, 0.082, 0.075, 0.50),  # empty
	Color(0.063, 0.141, 0.125, 0.80),  # held sample
	Color(0.086, 0.204, 0.176, 0.80),  # armed
]
const TILE_BORDER: Array[int] = [1, 1, 2, 2]
const TILE_BORDER_ALPHA: Array[float] = [0.45, 1.0, 0.90, 0.85]
## The one state whose border is not the gene's hue: an empty slot has no gene.
const EMPTY_BORDER := Color(0.141, 0.278, 0.247, 0.85)
const EMPTY_PLUS := Color(0.141, 0.278, 0.247, 0.75)
const PLUS_ARM := 16.0

const LABEL_TINT := Color(0.855, 0.953, 0.933, 0.66)
const LABEL_TINT_LOUD := Color(0.855, 0.953, 0.933, 0.92)
const LABEL_SIZE := 13
const LABEL_BASELINE := 15.0
const PIP_RADIUS := 2.6
const PIP_GAP := 9.0
const PIP_BOTTOM := 9.0
## Focus has to be drawn: a PanelContainer has no focus stylebox, and the strip
## is navigable by keyboard as well as by thumb.
const FOCUS_TINT := Color(0.588, 1.0, 0.859, 0.85)


## Rebuilds the strip from the genome as it is right now. Cheap and total: five
## to nine tiny nodes, built on opening the pause screen and after a swap, which
## are the only two moments the answer can have changed.
func _build_genome_strip() -> void:
	for child in _genome_row.get_children():
		_genome_row.remove_child(child)
		child.queue_free()
	_slot_genes.clear()

	var tiers := _genome.tiers()
	for gene: StringName in tiers:
		_slot_genes.append(gene)

	var held := _genome.held_sample
	if held != &"":
		# The sample and its arrow only exist while one is held. The whole Row
		# is centred, so the slots shift right when they appear -- harmless,
		# because the strip is only interactive while a sample is held, so
		# nothing moves under a finger that was about to press it.
		_genome_row.add_child(_make_tile(held, 1, Tile.HELD, -1))
		_genome_row.add_child(_make_arrow())

	# maxi, not slots(), so a genome can never be wider than the strip that
	# claims to show it. It cannot happen today; a strip that quietly hid a gene
	# could not be noticed if it ever did.
	var count := maxi(_genome.slots(), _slot_genes.size())
	for i in count:
		if i < _slot_genes.size():
			var gene: StringName = _slot_genes[i]
			var state := Tile.ARMED if i == _armed else Tile.OCCUPIED
			_genome_row.add_child(_make_tile(gene, int(tiers[gene]), state, i))
		else:
			_genome_row.add_child(_make_tile(&"", 0, Tile.EMPTY, i))

	_update_hint()


func _update_hint() -> void:
	if _genome.held_sample == &"":
		_genome_hint.text = ""
		return
	_genome_hint.text = HINT_COMMIT if _armed >= 0 else HINT_ARM


func _make_tile(gene: StringName, tier: int, state: int, index: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override("panel", _tile_box(gene, state))

	var live := index >= 0 and _genome.held_sample != &""
	tile.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	tile.focus_mode = Control.FOCUS_ALL if live else Control.FOCUS_NONE

	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(_draw_tile_face.bind(face, tile, gene, tier, state))
	tile.add_child(face)

	if live:
		tile.gui_input.connect(_on_tile_input.bind(tile, index))
		tile.focus_entered.connect(face.queue_redraw)
		tile.focus_exited.connect(face.queue_redraw)
	return tile


func _tile_box(gene: StringName, state: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = TILE_BG[state]
	box.border_color = EMPTY_BORDER if state == Tile.EMPTY \
		else Color(Cilia.hue(gene), TILE_BORDER_ALPHA[state])
	box.set_border_width_all(TILE_BORDER[state])
	box.set_corner_radius_all(8)
	# The tile is measured in §5.3 at exactly 76 square, so the panel adds no
	# margins of its own and the face gets the whole of it.
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	return box


## The tile face (§5.3): the word, the organ, and the tier as pips.
##
## The organ comes from cilia.gd, which is what draws it on a body -- one
## vocabulary, so a player who learns it here can read the water, and a player
## who learns it in the water can read this.
func _draw_tile_face(face: Control, tile: Control, gene: StringName, tier: int,
		state: int) -> void:
	var box := face.size
	if state == Tile.EMPTY:
		var mid := box * 0.5
		var arm := PLUS_ARM * 0.5
		face.draw_line(mid - Vector2(arm, 0.0), mid + Vector2(arm, 0.0),
			EMPTY_PLUS, 1.6, true)
		face.draw_line(mid - Vector2(0.0, arm), mid + Vector2(0.0, arm),
			EMPTY_PLUS, 1.6, true)
		return

	var font := face.get_theme_default_font()
	var loud := state == Tile.ARMED or state == Tile.HELD
	if font != null:
		face.draw_string(font, Vector2(0.0, LABEL_BASELINE),
			WORDS.get(gene, String(gene)), HORIZONTAL_ALIGNMENT_CENTER,
			box.x, LABEL_SIZE, LABEL_TINT_LOUD if loud else LABEL_TINT)

	Cilia.draw_tile_organ(face, gene, tier, box)

	# Three pips, filled to the tier. The one thing on the tile that is a count
	# rather than a magnitude: at 13 pixels the 22% length step §4.3 uses on a
	# body is a single pixel, so the tile spells it out instead.
	var tone := Cilia.hue(gene)
	var y := box.y - PIP_BOTTOM
	for i in 3:
		var at := Vector2(box.x * 0.5 + (float(i) - 1.0) * PIP_GAP, y)
		if i < tier:
			face.draw_circle(at, PIP_RADIUS, Color(tone, 0.92), true, -1.0, true)
		else:
			face.draw_circle(at, PIP_RADIUS, Color(tone, 0.22), false, 1.2, true)

	if tile.has_focus():
		face.draw_rect(Rect2(Vector2(2.0, 2.0), box - Vector2(4.0, 4.0)),
			FOCUS_TINT, false, 1.5)


## Thirty pixels of "this goes into one of those". Drawn rather than written,
## because §8's text budget is spent and an arrow is not a word.
func _make_arrow() -> Control:
	var arrow := Control.new()
	arrow.custom_minimum_size = ARROW_SIZE
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(_draw_arrow.bind(arrow))
	return arrow


func _draw_arrow(arrow: Control) -> void:
	var mid := arrow.size * 0.5
	var tint := Color(0.855, 0.953, 0.933, 0.34)
	arrow.draw_line(mid - Vector2(11.0, 0.0), mid + Vector2(9.0, 0.0), tint, 1.6, true)
	arrow.draw_line(mid + Vector2(9.0, 0.0), mid + Vector2(2.0, -6.0), tint, 1.6, true)
	arrow.draw_line(mid + Vector2(9.0, 0.0), mid + Vector2(2.0, 6.0), tint, 1.6, true)


# --- Two taps on the same target -------------------------------------------
# The only pattern that is safe on touch and navigable by keyboard. A mis-tap
# costs nothing because arming is reversible, and that is the argument that
# makes 20px between tiles acceptable even though it is about 1.5mm on a phone.
# The destructive control here is not adjacent to `resume`.

## **[param tile] is dead after [method _build_genome_strip] runs below.** Both
## branches of this handler rebuild the strip, which removes and frees every
## tile -- including the one whose `gui_input` we are standing inside. That is
## legal (`queue_free` is deferred and `remove_child` during emission is fine)
## and it is exercised on both the touch path and the keyboard path, but it
## means nothing may touch `tile` after the rebuild. Read the new node out of
## Row instead, the way the focus line does.
func _on_tile_input(event: InputEvent, tile: Control, index: int) -> void:
	if not _is_tile_tap(event):
		return
	tile.accept_event()
	if _armed == index:
		# **The guard is not politeness, it is the touch path working.** Godot
		# emulates a mouse click from every screen touch, so one thumb press
		# arrives here twice; without this the second copy would commit the
		# swap in the same frame the first one armed it, and the one
		# irreversible action in the game would need no confirmation at all.
		if Time.get_ticks_msec() - _armed_at < ARM_GUARD_MS:
			return
		_commit_slot(index)
		return
	_armed = index
	_armed_at = Time.get_ticks_msec()
	# Rebuilding frees the node this event arrived on, so anything that was
	# focused has to be put back afterwards -- but only for a key press. A thumb
	# does not want a focus ring, and the armed tile already says it is armed.
	var by_key := event is InputEventKey
	_build_genome_strip()
	if by_key:
		var armed := _genome_row.get_child(_row_child_of(index)) as Control
		if armed != null and armed.focus_mode == Control.FOCUS_ALL:
			armed.grab_focus()


## Where slot [param index] sits among Row's children: two nodes further along
## whenever a sample and its arrow are in front of it.
func _row_child_of(index: int) -> int:
	return index + (2 if _genome.held_sample != &"" else 0)


func _is_tile_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return event.is_action_pressed(&"ui_accept")


## The one irreversible action in the game (§9.7). A genome you cannot ruin is
## not a choice, and §1.3's drifter floor is what makes even the worst swap --
## dropping a fourth gene over your own mouth -- survivable rather than a soft
## lock.
func _commit_slot(index: int) -> void:
	if index < 0 or index >= _slot_genes.size():
		return
	_genome.replace(_slot_genes[index])
	_disarm()
	# The bus is told now rather than on the next unpaused frame: the membrane
	# keeps beating under the scrim, and an echo for a sample that no longer
	# exists is the game lying about the player's own body.
	_bus.hold(0.0)
	_build_genome_strip()
	# Every tile has just been freed and the strip is no longer interactive, so
	# a keyboard player would be left with nothing focused at all.
	_resume_button.grab_focus()


func _step_arming() -> void:
	if _armed < 0:
		return
	if Time.get_ticks_msec() - _armed_at < ARM_TIMEOUT_MS:
		return
	_disarm()
	_build_genome_strip()


func _disarm() -> void:
	_armed = -1
	_armed_at = 0
