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
const SomaLayer := preload("res://game/perception/soma.gd")
const ReturnsLayer := preload("res://game/perception/returns.gd")
const RunState := preload("res://game/run_state.gd")
## The last sixty seconds of the run, kept in memory by the last child of this
## node. **Preloaded for the type only**, and it is safe to preload precisely
## because the recorder knows nothing about this file: the replay *screen* is
## the one that reads back the other way, so it is reached by path and loaded
## when the button is pressed. docs/design/replay.md §4.5.
const RecorderNode := preload("res://game/replay/recorder.gd")
## Loaded on the press, never preloaded: `replay.gd` reads this file's division
## fades, and a preload back would be a cycle GDScript will not resolve.
const REPLAY_SCENE := "res://game/replay/replay.tscn"
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
## How long the "a sense grew" line holds before it fades on its own. It has no
## verb to wait for the way the steering line does -- the gene may be placed now
## or in forty seconds -- so it is a notice with a timer on it.
const SENSE_LINE_HOLD := 7.0

# --- The free opening sense -------------------------------------------------
# **An invariant against blindness, which is what it always meant.** A born cell
# has no sense of any kind since `chemocyte` took taste behind a gene, so an
# unhelped opening is a cell wandering an invisible ocean until something eats
# it. Five seconds after any birth, *if the cell has no sensing gene at all*, it
# is handed one, free, drawn at random, and told so in the one line of text this
# mode has. Generation 1 always qualifies; a daughter qualifies only if the
# player built a blind lineage, and granting unconditionally would hand out a
# free gene every two minutes. lifecycle.md §6.
#
# It arrives as a **held sample the player places**, not as an auto-placement:
# the `ocellus` is directional and worthless unplaced, and this makes the free
# gene the natural first lesson in the one placement decision the game has.
# genome.gd's `bonus_slots` is what guarantees it lands -- the born genome is
# already full at three, so the gift comes with somewhere to put it, and a
# player who never opens the pause screen still gets the gene when the sample
# lapses into that slot.

## About five seconds of swimming, which is two involuntary impulses -- long
## enough to have felt the cell move and be wondering what to do with it.
const FIRST_SENSE_AT := 5.0
## The four senses that answer *where is something*. Drawn flat. `stigma` is the
## weakest opening of the four -- a shadow is mass, and the authored first
## arrival is a drifter with almost none -- but it is a real sense, and what it
## does see is the half of the water that can eat you.
const FIRST_SENSES: Array[StringName] = [
	&"ocellus", &"ampulla", &"chemocyte", &"stigma"]

## The pause scrim, in the launcher's base colour, at two strengths. Point of
## view keeps Phase 4's half-veil because the membrane behind it is the live
## preview of the light slider. Full vision needs far more, because behind it is
## a lit world with the player's own cell pinned dead centre by the camera --
## exactly where the centred pause column has to sit. See _toggle_pause.
const SCRIM_POV := Color(0.023, 0.055, 0.05, 0.5)
const SCRIM_FULL_VISION := Color(0.023, 0.055, 0.05, 0.86)

## **What "selected" means on the strand**, and it is three values rather than
## two because a held sample with no locus chosen yet is a real state: it waits
## off the head of the chromosome and is selected there, and there is nothing to
## place it into. Declared up here because [member _armed] is initialised from
## it. See the strand's own section for what selection buys.
const SLOT_NONE := -9
const SLOT_SAMPLE := -1

enum Onboard { OFF, WAITING, FADE_IN, HOLD, FADE_OUT }
## ALIVE, then the collapse, then the black that holds until they touch it,
## then the aperture opening on a new cell.
enum Life { ALIVE, DYING, WAITING, RETURNING }

# --- The division (docs/design/lifecycle.md §4) ------------------------------
# **The largest dramatic beat the game will have, drawn entirely in the
# vocabulary that already exists**: bodies, the fringe, the nucleus, the
# aperture. No number, no icon, no text in the playfield beyond one onboarding
# line, and no new shader uniform.
#
# The warning is not a phase: it is continuous in radius, from
# DIVIDE_WARN_RADIUS, and it is the nucleus doubling. Everything below is what
# happens once the body has run out of arcs.

## QUICKEN still steers; PINCH stops the simulation, exactly as a death does.
enum Split { NONE, QUICKEN, PINCH, PART, CHOOSING, COMMIT }

## The beat runs up to RICH_PERIOD at full amplitude. Nothing is taken away.
const DIVIDE_QUICKEN := 2.4
## The body elongates along the heading and narrows at the waist.
const DIVIDE_PINCH := 1.5
## Two bodies, separating.
const DIVIDE_PART := 1.0
## The chosen one holds; the other falls to nothing and takes her own colour.
const DIVIDE_COMMIT := 0.9
## How long a lean has to be held before it commits. The commitment is drawn as
## it accrues, so releasing early undoes it.
const CHOOSE_HOLD := 1.0
## How far either side of centre the daughters are seated, in canvas px on the
## point-of-view figure and in world units in full vision. Both were rendered;
## neither needs a camera zoom.
const DIVIDE_SEAT_POV := 132.0
const DIVIDE_SPREAD_WORLD := 160.0
## What the world goes down to while the two of them are on screen. Through
## vision.gd's existing fade, so it costs no uniform.
const DIVIDE_WORLD_FADE := 0.22
## The figures are drawn at this rather than at soma.gd's FADE: rendered at 0.34
## the difference between two daughters is not callable. For the only time in
## the game the middle of the screen is the loudest thing on it, and that
## inversion is the beat.
##
## **These three are read by the replay, and the coupling is not visible from
## here.** `recorder.gd` records the whole of a division choice as *one* float:
## the difference between the two daughters' brightnesses, which `replay.gd`
## divides by `DIVIDE_FADE - DIVIDE_FADE_DIM` to recover how far the lean has
## accrued. That round-trip is exact only because of what [method _side_fade]
## below does with these numbers -- both daughters leave the same
## `DIVIDE_FADE_IDLE` on the same clock, so the leaned one's rise
## `(DIVIDE_FADE - DIVIDE_FADE_IDLE)` plus the declined one's fall
## `(DIVIDE_FADE_IDLE - DIVIDE_FADE_DIM)` is exactly the span the replay
## divides by. Move one of the three, or give either daughter a different base
## or a different curve, and the replay reconstructs the wrong pair of
## brightnesses: **no error anywhere, and a division that replays differently
## from the one the player watched.** Change these and re-render a POV
## division against the replay of the same run. docs/design/replay.md §4.1.
##
## The other half of that float is the shed, which is signed and offset past 2.
## It cannot collide with a lean, because the widest a lean can make the
## difference is `DIVIDE_FADE - DIVIDE_FADE_DIM` = 0.66 -- 1.34 clear of 2.0,
## which is a gulf in float32 rather than a rounding question.
const DIVIDE_FADE := 1.0
## Before a lean, and after one, for the daughter being declined.
const DIVIDE_FADE_IDLE := 0.82
const DIVIDE_FADE_DIM := 0.34
## How far off the sister is left, on the side she was drawn on. Far enough not
## to be a fight at birth, near enough to be met -- and inside the frame in full
## vision, so the answer to "what happened to the other one" is visible.
const SISTER_DISTANCE := 560.0
## The one line, at the first division of a run only.
const DIVIDE_LINE := "lean into one of them"

# --- The offer (docs/design/replay.md §4.5) ---------------------------------
# **One centred button, on every death, and a tap anywhere else still
# restarts.** The button consumes its own press, so `_unhandled_input` never
# sees it and a player who does not want a replay experiences no change at all.
# Owner's calls 3 and 4 in §7.
#
# It is offered on a first-generation death as well, and that is the point:
# dying in the first thirty seconds is the death a new player most needs
# explained.
const WATCH_WIDTH := 232.0
const WATCH_HEIGHT := 56.0
## Nothing to watch below this, which is a death inside the first breath.
const WATCH_MIN_SECONDS := 2.0

## Which view this run is drawn with, as [enum RunState.Mode]. Set it before the
## scene enters the tree to override the remembered choice; left alone it picks
## up whatever the mode select last stored.
var mode := -1

@onready var _membrane: MembraneLayer = $Membrane
@onready var _soma: SomaLayer = $Soma
@onready var _returns: ReturnsLayer = $Returns
@onready var _bus := _membrane.bus
@onready var _cell: CellBody = $Cell
@onready var _metabolism: MetabolismNode = $Metabolism
@onready var _motes: MotesField = $Motes
@onready var _food: FoodField = $Food
@onready var _genome: GenomeNode = $Genome
@onready var _vision: VisionLayer = $Vision
@onready var _onboarding: Label = $Hud/Onboarding
@onready var _pause_ui: Control = $Hud/Pause
@onready var _scrim: ColorRect = $Hud/Pause/Scrim
@onready var _resume_button: Button = $Hud/Pause/Center/Buttons/Resume
@onready var _leave_button: Button = $Hud/Pause/Center/Buttons/Leave
## The two settings panels share a row now: the second strand and the `Act`
## line cost 94 px on a column that had 36 px of slack, and stacking two
## identical 232 x 101 panels was the only reason the column was as tall as it
## was. Side by side they are 512 px wide, narrower than the strand block, so
## the column gains no new outer edge.
@onready var _light_panel: PanelContainer = $Hud/Pause/Center/Buttons/Settings/Light
@onready var _gain_caption: Label = $Hud/Pause/Center/Buttons/Settings/Light/Box/Caption
@onready var _gain_slider: HSlider = $Hud/Pause/Center/Buttons/Settings/Light/Box/Slider
@onready var _view_panel: PanelContainer = $Hud/Pause/Center/Buttons/Settings/View
@onready var _view_caption: Label = $Hud/Pause/Center/Buttons/Settings/View/Box/Caption
@onready var _view_button: Button = $Hud/Pause/Center/Buttons/Settings/View/Box/Toggle
@onready var _genome_caption: Label = $Hud/Pause/Center/Buttons/Genome/Caption
## **The body above and the DNA below**, at identical pitch and identical x, so
## column *i* is arc *i* on both rows and a comparison is a vertical scan. Only
## the lower one takes input: a row you cannot change must not look like one you
## can, and the asymmetry is drawn by what responds rather than by a tint.
@onready var _body_row: HBoxContainer = $Hud/Pause/Center/Buttons/Genome/Body
@onready var _genome_row: HBoxContainer = $Hud/Pause/Center/Buttons/Genome/Row
@onready var _explain_organ: Control = $Hud/Pause/Center/Buttons/Genome/Explain/Organ
@onready var _explain_name: Label = $Hud/Pause/Center/Buttons/Genome/Explain/Gene
@onready var _explain_says: Label = $Hud/Pause/Center/Buttons/Genome/Explain/Says
@onready var _genome_hint: Label = $Hud/Pause/Center/Buttons/Genome/Hint
@onready var _genome_act: Label = $Hud/Pause/Center/Buttons/Genome/Act
## The division's reading surface. Built once in [method _ready] and then only
## ever redrawn: seven loci a side is an invariant, not a maximum.
@onready var _choosing: Control = $Hud/Choosing
@onready var _choose_port: VBoxContainer = $Hud/Choosing/Port
@onready var _choose_starboard: VBoxContainer = $Hud/Choosing/Starboard
@onready var _choose_says: Control = $Hud/Choosing/Says
@onready var _choose_organ: Control = $Hud/Choosing/Says/Explain/Organ
@onready var _choose_name: Label = $Hud/Choosing/Says/Explain/Gene
@onready var _choose_line: Label = $Hud/Choosing/Says/Explain/Line
@onready var _choose_hint: Label = $Hud/Choosing/Says/Hint
@onready var _pause_tap: Control = $Hud/PauseTap
@onready var _recorder: RecorderNode = $Recorder
@onready var _watch_ui: CenterContainer = $Hud/Watch
@onready var _watch_button: Button = $Hud/Watch/Button
## The replay screen while it is up, as a child of this run so that the ring is
## never freed and no scene change happens.
var _replay: Node = null

## Which locus is selected, or [constant SLOT_NONE]. Selecting is reversible and
## that is why a mis-tap costs nothing, which is in turn why no gap between loci
## is acceptable.
var _armed := SLOT_NONE
## Which locus the mouse is over, or [constant SLOT_NONE]. Desktop only by
## nature: a phone has no hover, which is exactly why the tap path above exists.
var _hovered := SLOT_NONE

## The pause target's two states and the four styleboxes they are made of,
## built once in [method _style_pause] rather than per draw.
var _pause_hot := false
var _pause_well_rest: StyleBoxFlat = null
var _pause_well_hot: StyleBoxFlat = null
var _pause_bar_rest: StyleBoxFlat = null
var _pause_bar_hot: StyleBoxFlat = null
## Milliseconds, from Time, not an accumulated delta: the strip only exists
## while the tree is paused, and a paused tree hands this node a delta for a
## frame in which nothing else moved.
var _armed_at := 0
## The gene in each slot, left to right, index-matched to the loci in Row.
var _slot_genes: Array[StringName] = []
## Which DNA locus a gene has been lifted out of while a move is in the air, or
## [constant SLOT_NONE]. Set by `_get_drag_data` and cleared by the drop or by
## `NOTIFICATION_DRAG_END`, whichever arrives -- and one of them always does.
var _dragging := SLOT_NONE
## Which locus a finger is holding down with a placement waiting on the lift,
## or [constant SLOT_NONE].
##
## **The confirming gesture and the drag-starting gesture cannot be the same
## event, and this variable is what keeps them apart.** A pointer going *down*
## on an armed locus is ambiguous by construction: it is the second tap of
## §9.7's placement and it is also how a move begins, and both readings are
## live at the same instant on the same pixel. Committing on the down-stroke
## resolved that by the clock -- the same finger, the same two points on
## screen, placed a gene or moved one depending on whether the press landed
## more or less than [constant ARM_GUARD_MS] after the arming tap -- and one of
## those two outcomes evicts a gene from the lineage for good.
##
## So the down-stroke only **primes**: it says *a placement is waiting on this
## locus*, changes nothing, and is cancelled by the one thing that proves the
## finger meant a move, which is the drag actually starting ([method
## _locus_drag]). The irreversible half happens on the up-stroke, and only if
## the finger is still inside the locus it pressed. A drag can no longer
## perform a placement, because by the time a placement could happen the drag
## has already claimed the gesture and cleared this.
##
## The 300 ms guard is unmoved and still measured press-to-press, so §9.7's
## contract -- *two taps, and the second cannot follow the first inside
## 300 ms* -- is what it always was. What changed is which half of the second
## tap the DNA is written on.
var _primed := SLOT_NONE

var _last_toggle_frame := -1
## The frame Back was last answered on, whichever door it came through. See
## [method _back_once].
var _last_back_frame := -1
var _onboard := Onboard.OFF
var _onboard_clock := 0.0
var _onboard_from := 0.0
## Seconds HOLD lasts before fading on its own; 0 means "wait for the verb",
## which is what the steering line does.
var _onboard_hold := 0.0
## True while the line on screen is the steering one, which is the only line
## that is onboarding rather than a notice.
var _onboard_steer := false

## Seconds swum this life, against FIRST_SENSE_AT, and whether the free sense
## has already been handed over. Both reset with the cell.
var _sense_clock := 0.0
var _sensed := false

## **Forward is always up.** The world turns instead of the cell, which is the
## other way of reading a heading and the one a player who has been staring at
## a body-relative membrane already has. Full vision only -- point of view is
## body-relative by construction, so the toggle is a no-op there and says so by
## simply not changing anything. Off by default.
var _camera_locked := false

var _life := Life.ALIVE
## A tap that arrived during the collapse, waiting for the black to be ready.
var _tap_pending := false
var _death_clock := 0.0
var _death_loud := true
var _vision_cut := false

# --- The division -----------------------------------------------------------
var _split := Split.NONE
var _split_clock := 0.0
## How deep into the run the lineage is. Reset by death and by nothing else:
## **a run keeps nothing; a lineage keeps everything.**
var _generation := 1
## The two of them, port first: `{"tiers": {}, "order": [], "mutation": &""}`.
## Which is on which side is random, so the choice is made by reading rather
## than by remembering.
var _daughters: Array = []
## -1 port, +1 starboard, 0 not leaning, and how long it has been held.
var _lean := 0
var _lean_clock := 0.0
var _chosen := -1
## A finger on one half of the screen, as a signed lean past the deadzone.
var _touch_lean := 0.0
var _touch_index := -2
## The two sentinels [member _touch_index] has always used, named, because
## [member _choose_gesture] keys on the same numbers: **-1 is the mouse** and
## **-2 is nobody**. A real touch index is never negative, so one keyspace holds
## every pointer the game can be driven by.
const POINTER_MOUSE := -1
const POINTER_NONE := -2
## **What each pointer's gesture is, keyed by its index: `true` a read, `false`
## a lean** (§4.1). Written by [method _input] on the press and overwritten by
## [method _on_choose_locus_input] on the same event when the press landed on a
## locus; erased on the release.
##
## **Absent means a lean**, and that is the case that matters rather than a
## default chosen for tidiness: a finger that was already down before the two
## daughters existed has no press for this screen to have seen, and it is the
## one [method _read_touch_lean]'s drag branch exists for.
var _choose_gesture: Dictionary = {}
## Whether this run has said the one line yet.
var _said_divide := false
## What the two views are drawing this frame. Empty means an ordinary body; see
## [method _push_division] for the contract.
var _division := {}


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
	_food.bitten.connect(_on_bitten)
	_food.stung.connect(_on_stung)
	_food.darted.connect(_on_darted)
	_cell.dashed.connect(_on_dashed)
	# The two halves of one cell, introduced here and nowhere else: the body
	# reads its drive constants out of the genome, and the genome takes its
	# capacity from the body's radius.
	_cell.genome = _genome
	_motes.setup(_cell)
	_food.setup(_cell)
	_genome.setup(_cell)
	_soma.setup(_cell, _genome)
	# Once, and only here: the marks layer holds the body and the water, and
	# neither node is ever replaced -- a death and a birth reset those two rather
	# than building new ones, which is why the figure is re-bound at both and
	# this is not.
	_returns.setup(_cell, _food)

	# Read before _apply_mode(), which is what carries it into the world view: a
	# player who chose "forward up" last run must not have to choose it again.
	_camera_locked = RunState.load_camera_locked()
	if mode < 0:
		mode = RunState.load_mode()
	_apply_mode()

	_style_pause()
	_explain_organ.custom_minimum_size = EXPLAIN_ORGAN_SIZE
	_explain_organ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_explain_organ.draw.connect(_draw_explain_organ)
	_pause_ui.hide()
	# Eighteen Controls and two rows of text, built once. Nothing here asks for
	# a window, an input device or a network, so a headless boot pays one
	# allocation and draws nothing.
	_build_choosing()
	_resume_button.pressed.connect(_toggle_pause)
	_leave_button.pressed.connect(_leave)

	# The offer, hidden until there is something to watch. Styled like the pause
	# column because that is the register: a panel the player consults.
	_watch_ui.hide()
	_watch_button.custom_minimum_size = Vector2(WATCH_WIDTH, WATCH_HEIGHT)
	_watch_button.focus_mode = Control.FOCUS_NONE
	_watch_button.add_theme_font_size_override("font_size", 20)
	_watch_button.add_theme_color_override("font_color",
		Color(0.855, 0.953, 0.933, 0.82))
	_watch_button.add_theme_color_override("font_hover_color",
		Color(0.855, 0.953, 0.933, 1.0))
	_watch_button.add_theme_color_override("font_pressed_color",
		Color(1.0, 1.0, 1.0, 1.0))
	_watch_button.add_theme_stylebox_override("normal", _slab(0.0))
	_watch_button.add_theme_stylebox_override("hover", _slab(0.35))
	_watch_button.add_theme_stylebox_override("pressed", _slab(0.5))
	_watch_button.pressed.connect(_watch)

	# **No focus.** The playfield has no other focusable control, so giving this
	# one a focus ring would put arrow keys on GUI navigation the moment anyone
	# pressed Tab -- and the arrow keys are how the cell is steered. Desktop has
	# Esc; this target is for the thumb that has no Back gesture to find.
	_pause_tap.focus_mode = Control.FOCUS_NONE
	_pause_tap.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_tap.custom_minimum_size = Vector2(PAUSE_TAP_SIZE, PAUSE_TAP_SIZE)
	_pause_tap.draw.connect(_draw_pause_tap)
	_pause_tap.gui_input.connect(_on_pause_tap)
	_pause_tap.mouse_entered.connect(_set_pause_hot.bind(true))
	_pause_tap.mouse_exited.connect(_set_pause_hot.bind(false))
	_update_pause_tap()

	_view_button.pressed.connect(_toggle_camera)
	_update_view_button()

	_bus.gain = clampf(RunState.load_gain(SignalBus.GAIN_DEFAULT),
		SignalBus.GAIN_MIN, SignalBus.GAIN_MAX)
	_gain_slider.value = _bus.gain
	_gain_slider.value_changed.connect(_on_gain_changed)
	_gain_slider.drag_ended.connect(_on_gain_settled)

	_begin_onboarding()
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())


func _process(delta: float) -> void:
	# Before every early return below, because the states those returns lead to
	# -- dying, dividing, paused -- are exactly the ones with no button.
	_update_pause_tap()
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
		# running: a slot armed *over a held sample* lapses after four seconds
		# whether or not the simulation is moving. §5.2. A selection with
		# nothing to commit has no clock -- see [method _step_arming].
		_step_arming()
		return
	# The division. Its first phase leaves the simulation running -- steering
	# still works and nothing is taken away -- and every phase after it has
	# called _set_simulating(false), exactly as a death does, so there is
	# nothing below here left to post.
	if _split != Split.NONE:
		_step_split(delta)
		if _split >= Split.PINCH:
			return

	# Read once, post once. Nothing below carries a position.
	_metabolism.concentration = _food.concentration
	_metabolism.upkeep = _genome.upkeep()
	# `vacuole` and `plastid`: a bigger tank and a body that makes some of its
	# own. Both land on the beat, which is where every cost in this game lands.
	_metabolism.reserve = CellBody.STORE_BY_TIER[
		mini(_cell.extra(&"vacuole"), CellBody.STORE_BY_TIER.size() - 1)]
	_metabolism.photosynthesis = CellBody.SUN_BY_TIER[
		mini(_cell.extra(&"plastid"), CellBody.SUN_BY_TIER.size() - 1)]
	# What the water has to be told about this body before it answers. All
	# scalars about the cell's own anatomy; the field turns them into bearings.
	_food.touch_range = CellBody.TOUCH_RANGE_BY_TIER[
		mini(_cell.extra(&"palp"), CellBody.TOUCH_RANGE_BY_TIER.size() - 1)]
	var dart := mini(_cell.extra(&"trichocyst"),
		CellBody.DART_RANGE_BY_TIER.size() - 1)
	_food.dart_range = CellBody.DART_RANGE_BY_TIER[dart]
	_food.dart_cooldown = CellBody.DART_COOLDOWN_BY_TIER[dart]
	# **The dart looks along the arc it is worn on**, exactly as the beam does
	# and resolved in the same place for the same reason: this file has both the
	# genome and cilia.gd's arc table. A rear dart answers a flank, which is what
	# makes `trichocyst` a placement decision instead of a radius.
	_food.dart_bearing = _slot_bearing_of(&"trichocyst")
	var venom := mini(_cell.extra(&"toxicyst"),
		CellBody.VENOM_COST_BY_TIER.size() - 1)
	_food.venom_cost = CellBody.VENOM_COST_BY_TIER[venom] if venom > 0 else -1.0
	_food.beam_range = _cell.beam_range()
	_food.beam_bearings = _beam_bearings()
	# `chemocyte` and `ampulla`: how far this nose reaches and how often this
	# electroreceptor fires. Scalars about the cell's own anatomy, handed to the
	# field so it can answer in bearings -- the same contract as beam_range.
	_food.smell_range = _cell.smell_range()
	_food.ping_range = _cell.ping_range()
	_food.ping_period = _cell.ping_period()
	# **`taste_level`, not `concentration`.** The first is what this nose picks
	# up and the second is what the water is like; the beat above reads the
	# water, the membrane reads the organ. A cell with no chemocyte hands over a
	# flat zero and gets no green band at all -- which is the whole change, and
	# is enforced again inside the bus.
	_bus.taste(_food.taste_bearing, _food.taste_level)
	_bus.dread(_food.dread_level)
	# **What body this membrane is attached to** (§2.1). One post a frame, beside
	# the beat, and it is what makes a tier change something point of view can
	# feel: the thrust bloom, the turn shear and the ingest flood are the same
	# three organs the fringe draws, seen from inside.
	_bus.organs(_cell.tier(&"cytostome"), _cell.tier(&"cirrus"),
		_cell.tier(&"flagellum"), _cell.tier(&"stigma"))
	# The stigma only reports if the cell has grown one. The field works out
	# what the water is doing either way -- what is out there is not a function
	# of which organs are watching -- but a cell with no eye is handed **no
	# bearing**, not a zero-strength reading at a real one. The bearing is
	# derived from ground truth, the post gate fires on bearing movement as well
	# as on strength, and an ungated eyeless cell posted forty `light`
	# sensations a minute for an organ it does not have.
	var eye := _cell.tier(&"stigma") > 0
	_bus.light(_food.shadow_bearing if eye else 0.0, _food.shadow if eye else 0.0)
	# The earned senses, beside organs() and for the same reason: a tier is a
	# property of the organ, not of what it senses.
	_bus.sense_organs(_cell.extra(&"ocellus"), _cell.extra(&"statocyst"),
		_cell.extra(&"rhabdom"), _cell.extra(&"chemocyte"),
		_cell.extra(&"ampulla"))
	_post_beam()
	_post_pings()
	# `statocyst`: absolute up, as a bearing this body reads it -- which is
	# minus the heading, and the one bearing on the membrane that moves when the
	# cell turns rather than when the water does.
	_bus.level(-_cell.heading, 1.0 if _cell.extra(&"statocyst") > 0 else 0.0)
	# `palp`: something solid, right there, felt with no light at all.
	if _food.touch_level > 0.0:
		_bus.touch(_food.touch_bearing, _food.touch_level)
	_bus.hold(_genome.held_remaining if _genome.held_sample != &"" else 0.0)
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
	_bus.shear(_cell.shear_rate())
	# Proprioception is not a sensation and does not go on the bus: it is a
	# view, and it is handed the one number it cannot derive for itself.
	_soma.beat = _bus.pulse()
	_step_sense_grant(delta)
	_step_onboarding(delta)
	# After the beat above, because it replaces it: the quickening is the beat
	# running up to RICH_PERIOD at full strength, and posting the metabolic one
	# afterwards would undo it every frame.
	if _split == Split.QUICKEN:
		_bus.set_beat(lerpf(_metabolism.beat_period(), MetabolismNode.RICH_PERIOD,
			clampf(_split_clock / DIVIDE_QUICKEN, 0.0, 1.0)), 1.0)
	_push_division()

	if _metabolism.starved():
		_die(false, 0.0)
		return
	# **Seven arcs, and no room for an eighth organ.** Checked after the meal
	# that grew the body, so the division is the consequence of the mouthful
	# rather than of the frame after it.
	if _split == Split.NONE and _cell.radius >= CellBody.DIVIDE_RADIUS:
		_begin_split()


## Which way this cell's beams look. **The slot is the arc and the arc is the
## bearing** -- that is the whole of placement mattering, and it is resolved
## here because this file has both the genome and cilia.gd's arc table. cell.gd
## cannot: cilia.gd preloads genome.gd, which preloads cell.gd, so a preload
## back the other way would be a cycle GDScript will not resolve.
func _beam_bearings() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var tier := mini(_cell.extra(&"ocellus"), CellBody.BEAM_COUNT_BY_TIER.size() - 1)
	var count := CellBody.BEAM_COUNT_BY_TIER[tier]
	if count <= 0:
		return out
	var slot := _genome.slot_of(&"ocellus")
	if slot < 0:
		return out
	var middle := Cilia.slot_bearing(slot)
	var fan := deg_to_rad(CellBody.BEAM_FAN_DEG_BY_TIER[tier])
	for i in count:
		var u := 0.0 if count < 2 else -1.0 + 2.0 * float(i) / float(count - 1)
		out.append(wrapf(middle + u * fan, -PI, PI))
	return out


## Which way a directional organ looks: the bearing of the arc it is worn on,
## dead ahead for a gene this body does not wear. **The body's slot, not the
## DNA's** -- the organ is on the body, and the DNA is what the daughters get.
func _slot_bearing_of(gene: StringName) -> float:
	var slot := _genome.slot_of(gene)
	return Cilia.slot_bearing(slot) if slot >= 0 else 0.0


## The one beam the membrane hears about: the nearest hit. There is one glow
## lobe left in the shader and three beams at tier 3, so they compete rather
## than sum -- the closest surface is the one worth telling a blind cell about.
## Full vision draws all of them, which is what full vision is for.
func _post_beam() -> void:
	var best := 0.0
	var bearing := 0.0
	var reach := _food.beam_range
	for beam: Array in _food.beams:
		if not bool(beam[2]):
			continue
		var near := 1.0 - clampf(float(beam[1]) / maxf(reach, 1.0), 0.0, 1.0)
		if near > best:
			best = near
			bearing = float(beam[0])
	_bus.beam(bearing, best)


## **The ping's returns**, drained from the field and posted one at a time.
##
## Unlike the beam these do not compete before they reach the bus: each return
## is a separate event at a separate bearing, and the membrane's envelope is
## what resolves two that land in the same instant. Spacing them out in *time*
## is the field's job, and it is what makes one pulse read as a sweep.
func _post_pings() -> void:
	for echo: Array in _food.pings:
		_bus.ping(float(echo[0]), float(echo[1]))


# ---------------------------------------------------------------------------
# The free opening sense.
# ---------------------------------------------------------------------------

## Five seconds after any birth -- a run's first cell or a daughter -- one
## sensing gene, free, as a sample waiting for a slot.
##
## **It stops being "every run" and becomes what it always meant: an invariant
## against blindness.** The precondition that was already false for generation 1
## is the one that decides it now: *if the cell has no sensing gene at all*. A
## born cell always qualifies. A daughter qualifies only if the player built a
## blind lineage, which is a real and rare thing to have done, and being rescued
## from it is right -- granting unconditionally would hand out a free gene every
## two minutes. lifecycle.md §6.
func _step_sense_grant(delta: float) -> void:
	if _sensed:
		return
	_sense_clock += delta
	if _sense_clock < FIRST_SENSE_AT:
		return
	_sensed = true
	for sense: StringName in FIRST_SENSES:
		if _cell.extra(sense) > 0:
			return
	var gene: StringName = FIRST_SENSES[randi() % FIRST_SENSES.size()]
	# It is in the DNA already but not on this body -- a lineage that wrote a
	# sense down and then never expressed it. Nothing to give.
	if _genome.dna_tier(gene) > 0:
		return
	# The gift comes with somewhere to put it, but only when there is nowhere:
	# a cell that has grown itself a spare slot does not need a second one.
	if not _genome.layout().has(&""):
		_genome.bonus_slots += 1
	if _genome.gift(gene) != GenomeNode.Result.HELD:
		return
	# The strip is built when the pause screen opens, so there is nothing to
	# rebuild here -- but the echo behind the beat starts on the next frame's
	# hold(), and the line says what the echo cannot.
	_say_sense()


# ---------------------------------------------------------------------------
# The division. docs/design/lifecycle.md §4.
#
# One state machine, six phases, and not one new node or pixel: the bodies are
# cilia.gd's, the parting is two constants on the ovoid, the choice is the
# gesture the game already has for every other decision, and the newborn's first
# moment is the aperture envelope a revival was already written for.
# ---------------------------------------------------------------------------

## The body has run out of arcs. Nothing is taken away yet -- QUICKEN still
## steers, and the player has 2.4 seconds of a body beating faster to read
## before anything stops.
func _begin_split() -> void:
	_split = Split.QUICKEN
	_split_clock = 0.0
	_chosen = -1
	_lean = 0
	_lean_clock = 0.0
	_touch_lean = 0.0
	_touch_index = -2
	# Every finger on the glass is now a lean that has not been pressed. That is
	# the rule, not an accident of clearing: a thumb that was steering when the
	# body ran out of arcs is holding a gesture this screen never saw begin, and
	# §4.1 gives it to the lean.
	_choose_gesture.clear()
	_daughters = _make_daughters()


## Two daughters of equal mass, one faithful and one with a single sideways
## mutation, **both drawn as real bodies before the player commits**. It is not
## a gamble: you can see exactly what the mutation did.
##
## **And what expressed.** Each daughter's DNA is rolled into a body of her own
## (`Genome.expressed`), so the two differ in which organs they wear as well as
## in the one mutation. `body` is what she is drawn as and what she wakes with;
## `tiers` stays the whole DNA, because a gene that did not express is carried
## and not lost -- it rolls again in her own daughters.
func _make_daughters() -> Array:
	var faithful := {
		"tiers": _genome.dna().duplicate(),
		"order": _genome.layout().duplicate(),
		"mutation": &"",
	}
	var rolled: Array = GenomeNode.mutated(_genome.dna(), _genome.layout())
	var changed := {"tiers": rolled[0], "order": rolled[1], "mutation": rolled[2]}
	faithful["body"] = GenomeNode.expressed(faithful["tiers"])
	changed["body"] = GenomeNode.expressed(changed["tiers"])
	# Which one is on which side is random, so the choice is made by reading the
	# two bodies rather than by remembering which side the safe one is on.
	return [faithful, changed] if randf() < 0.5 else [changed, faithful]


func _step_split(delta: float) -> void:
	_split_clock += delta
	# The line and its fade keep running: _step_onboarding is only called from
	# the live branch of _process, which stops at the pinch.
	if _split >= Split.PINCH:
		_step_onboarding(delta)
	match _split:
		Split.QUICKEN:
			if _split_clock >= DIVIDE_QUICKEN:
				_split = Split.PINCH
				_split_clock = 0.0
				# The same call a death makes. The water stops, the body does
				# not: what is left moving is the division itself.
				_set_simulating(false)
				_cell.release()
		Split.PINCH:
			_hush()
			if _split_clock >= DIVIDE_PINCH:
				_split = Split.PART
				_split_clock = 0.0
		Split.PART:
			_hush()
			if _split_clock >= DIVIDE_PART:
				_split = Split.CHOOSING
				_split_clock = 0.0
				if not _said_divide:
					_said_divide = true
					# Hold 0 is "wait for the verb", and the verb is the lean.
					_say(DIVIDE_LINE, 0.0)
		Split.CHOOSING:
			_hush()
			_step_choosing(delta)
		Split.COMMIT:
			# The aperture shutting on one cell and opening on another, which is
			# exactly the envelope this was written for.
			_bus.revive(_split_clock)
			if _split_clock >= DIVIDE_COMMIT:
				_be_born()
		_:
			pass
	_push_division()


## **No sensations, for the only time in the game.** Everything the membrane is
## holding is let go so the two bodies in the middle of the screen are the whole
## of what is on it. Posted rather than switched off: the bus owns every
## envelope, and this is the run telling it the truth about a cell that is
## no longer swimming in anything.
func _hush() -> void:
	_bus.dread(0.0)
	_bus.taste(0.0, 0.0)
	_bus.light(0.0, 0.0)
	_bus.beam(0.0, 0.0)
	_bus.level(0.0, 0.0)
	_bus.hold(0.0)
	_bus.shear(0.0)


## **You lean into one**, and the commitment is drawn as it accrues. Releasing
## early undoes it; a tap commits nothing; there is no timeout and no default,
## so a player who puts the phone down comes back to the same two bodies.
func _step_choosing(delta: float) -> void:
	var lean := _read_lean()
	if lean != _lean:
		_lean = lean
		_lean_clock = 0.0
		# The line has done its job the moment they lean, whichever way -- from
		# wherever it had got to, which may be part way in: a player still
		# holding a drag from before the pinch leans on the first frame there is
		# anything to lean at, and the line must not stick at half brightness
		# for the rest of the division.
		if lean != 0 and not _onboard_steer \
				and _onboard != Onboard.OFF and _onboard != Onboard.FADE_OUT:
			_onboard_from = _onboarding.modulate.a
			_onboard_clock = 0.0
			_onboard = Onboard.FADE_OUT
		return
	if _lean == 0:
		return
	_lean_clock += delta
	if _lean_clock < CHOOSE_HOLD:
		return
	_chosen = 0 if _lean < 0 else 1
	_split = Split.COMMIT
	_split_clock = 0.0


## Which way the player is leaning, -1 port and +1 starboard.
##
## Read here rather than off the cell, because the cell's input has been
## switched off with the rest of the simulation -- and because the target is a
## screen half rather than a body: a 96 px daughter is not a 48 px target with a
## thumb over it.
func _read_lean() -> int:
	if Input.is_action_pressed(&"ui_left") or Input.is_key_pressed(KEY_A):
		return -1
	if Input.is_action_pressed(&"ui_right") or Input.is_key_pressed(KEY_D):
		return 1
	if absf(_touch_lean) > CellBody.STEER_DEADZONE:
		return -1 if _touch_lean < 0.0 else 1
	return 0


## **What the two views draw this frame, and the only thing either is told.**
##
## Empty is an ordinary body. `double` and `pinch` are the mother becoming two;
## `bodies` is present only once there are two of them, and its presence is what
## tells a view to stop drawing the cell and draw the pair.
func _push_division() -> void:
	var double := smoothstep(CellBody.DIVIDE_WARN_RADIUS, CellBody.DIVIDE_RADIUS,
		_cell.radius)
	if _split == Split.NONE and double <= 0.0:
		if not _division.is_empty():
			_division = {}
			_hand_division()
		return
	_division = {"double": double, "pinch": 0.0}
	match _split:
		Split.PINCH:
			_division["pinch"] = clampf(_split_clock / DIVIDE_PINCH, 0.0, 1.0)
		Split.PART, Split.CHOOSING, Split.COMMIT:
			_division["pinch"] = 1.0
		_:
			pass
	if _split >= Split.PART and _daughters.size() == 2:
		var spread := 1.0
		if _split == Split.PART:
			spread = clampf(_split_clock / DIVIDE_PART, 0.0, 1.0)
		_division["spread"] = spread
		_division["radius"] = CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)
		var pair: Array = []
		for side in 2:
			pair.append({
				# **The body she wears, not the DNA she carries.** The two are
				# no longer the same map: expression is a roll, and the whole
				# point of drawing both daughters before the choice is that the
				# roll is something the player reads rather than is told.
				"tiers": _daughters[side]["body"],
				"order": _daughters[side]["order"],
				"fade": _side_fade(side),
				"shed": _side_shed(side),
			})
		_division["bodies"] = pair
	_hand_division()


func _hand_division() -> void:
	_soma.division = _division
	_vision.division = _division
	_vision.set_dim(DIVIDE_WORLD_FADE if _division.has("bodies") else 1.0)
	# The strands are handed the same state at the same moment as the bodies,
	# from the one place that hands it anywhere, so they cannot get out of step
	# with the pair they belong to -- including the death that clears a division
	# mid-quickening, which comes through here too.
	_update_choosing()


## How bright daughter [param side] is: both up while nothing is being asked,
## the one being leaned into rising and the other falling as the second of
## commitment accrues, and then one of them going out.
func _side_fade(side: int) -> float:
	if _split == Split.COMMIT:
		if side == _chosen:
			return DIVIDE_FADE
		return DIVIDE_FADE_DIM * (1.0 - clampf(_split_clock / DIVIDE_COMMIT,
			0.0, 1.0))
	if _lean == 0:
		return DIVIDE_FADE_IDLE
	var t := clampf(_lean_clock / CHOOSE_HOLD, 0.0, 1.0)
	var leaned := 0 if _lean < 0 else 1
	if side == leaned:
		return lerpf(DIVIDE_FADE_IDLE, DIVIDE_FADE, t)
	return lerpf(DIVIDE_FADE_IDLE, DIVIDE_FADE_DIM, t)


## How far daughter [param side] has stopped being you. Only ever the one you
## declined, and only on the way out.
func _side_shed(side: int) -> float:
	if _split != Split.COMMIT or side == _chosen:
		return 0.0
	return clampf(_split_clock / DIVIDE_COMMIT, 0.0, 1.0)


## **What the newborn wakes into.** The same calls a revival makes, with one
## substitution: she is a new body rather than a born one, and she is made of
## the DNA her mother spent a life writing.
func _be_born() -> void:
	var pick: Dictionary = _daughters[_chosen]
	var other: Dictionary = _daughters[1 - _chosen]
	_generation += 1
	# A new body, not a starving one: the mother spent herself. Her place and
	# her heading are kept, so nothing about the frame jumps.
	_cell.reset(true)
	_cell.radius = CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)
	_metabolism.reset()
	# The DNA becomes both registers again: expressed whole, at birth, which is
	# the whole of INHERIT_TIER_LOSS being zero.
	_genome.express(pick["tiers"], pick["order"], pick["body"])
	_soma.setup(_cell, _genome)
	_motes.setup(_cell)
	# **The field is reseeded.** The water around you was sized to a 40-unit body
	# and the newborn is 28; the field is a treadmill already, so this is that
	# treadmill taking one large step. It re-fires the drifter-floor invariant,
	# which is what guarantees the newborn a first meal she can certainly take.
	_food.setup(_cell)
	# And the one you did not take is left in it.
	# The body she wears, again: a cell in the water is an organism, and what it
	# is carrying and not wearing is not a thing anything out there can read.
	_food.put_sister(-PI * 0.5 if _chosen == 1 else PI * 0.5, SISTER_DISTANCE,
		_cell.radius, other["body"])
	# A daughter is a birth, so the anti-blindness grant's clock starts again --
	# but the grant itself now asks whether she can sense anything at all, and a
	# daughter almost always can. §6.
	_sense_clock = 0.0
	_sensed = false
	_split = Split.NONE
	_split_clock = 0.0
	_daughters = []
	_chosen = -1
	_lean = 0
	_touch_lean = 0.0
	_touch_index = -2
	_choose_gesture.clear()
	_division = {}
	_hand_division()
	_set_simulating(true)
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
	_bus.pulse_now()


func _on_impulsed(strength: float) -> void:
	_bus.thrust(strength)


## `myoneme`. The cell asked for the burst and cannot spend hunger itself.
func _on_dashed(cost: float) -> void:
	if _life != Life.ALIVE:
		return
	_metabolism.feed(-cost)


## `trichocyst`. The dart went off; something that was committed to you is not
## any more. Felt as a shove at its bearing -- it is a thing that happened out
## there, at a direction, which is exactly what a shove says.
func _on_darted(bearing: float) -> void:
	_bus.shove(bearing, 0.7)


## `toxicyst`. It swallowed you and died of it, and you are starving for it.
func _on_stung(bearing: float) -> void:
	if _life != Life.ALIVE:
		return
	_bus.hit(bearing, 1.0)
	_metabolism.feed(-_food.venom_cost)


## A mouth closed on a body it could not swallow -- yours on something too big,
## or something's on you. **The same `hit` a mote gives**, and deliberately not
## a channel of its own: contact at a bearing is a sensation this membrane has
## had since Phase 1, and a bite is contact. There is no readout of how much of
## you is left, because there is no organ that could report it; a player learns
## they are in trouble by being bitten, repeatedly, from the same direction.
func _on_bitten(bearing: float, strength: float) -> void:
	if _life != Life.ALIVE:
		return
	_bus.hit(bearing, strength)


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
	#
	# **And it stops at DIVIDE_RADIUS**, because that is where the body runs out
	# of arcs. A field cell is not clamped -- edibility.md §7 keeps the runaway
	# and makes it killable from astern instead -- but the player's growth has
	# somewhere else to go now, and it goes there.
	_cell.radius = minf(_cell.radius + CellBody.GROWTH_PER_MEAL,
		CellBody.DIVIDE_RADIUS)
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
	# A death during the quickening -- the one phase the water is still moving
	# in -- takes the division with it. The collapse owns the screen, and two
	# daughters drawn under it would be the game contradicting itself twice.
	_split = Split.NONE
	_daughters = []
	_division = {}
	_hand_division()
	_set_simulating(false)
	# **The ring is sealed here**, before the collapse writes a single frame of
	# itself into it. What the player is offered is the run, not the dying.
	_recorder.seal()
	_cell.release()
	# The collapse owns the screen. A body still swimming calmly in the middle
	# of a membrane slamming shut is the game contradicting itself.
	_show_self(false)
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
				else:
					_offer_replay(true)
		Life.RETURNING:
			_bus.revive(_death_clock)
			if _death_clock >= SignalBus.DEATH_RETURN:
				_life = Life.ALIVE
				# The body comes back with the light. _apply_mode() ran while
				# this was still RETURNING, so the figure is still hidden and
				# nothing else will ever turn it back on.
				_show_self(not _vision_active())
				# The first beat on arrival: 2.4s and full strength, after
				# minutes of a slow faint one.
				_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
				_bus.pulse_now()
		_:
			pass


# ---------------------------------------------------------------------------
# The replay. docs/design/replay.md §4.5: four edits, none of them inside
# _process, and the screen itself is a child of this run so that the recorder's
# ring is never freed and no scene change happens.
# ---------------------------------------------------------------------------

## Puts the offer up, or takes it and the screen behind it down.
func _offer_replay(on: bool) -> void:
	if on:
		# A death inside the first breath has nothing to show, and an offer
		# that opens on two frames of water is worse than no offer.
		_watch_ui.visible = _recorder.span() >= WATCH_MIN_SECONDS
		return
	_watch_ui.hide()
	_close_replay()
	_recorder.clear()


## The button. Instances the screen as a child of this run -- never a scene
## change, because the buffer it is playing back lives in a sibling node.
##
## **Detaching the bus is not housekeeping.** `_step_death` goes on calling
## `collapse()` for as long as the black holds, and `collapse()` writes every
## uniform on the membrane; the replay writes the same uniforms out of the
## recording. Two writers on one material is a flicker at best. So the run's
## membrane is unplugged for exactly as long as the screen is up -- and not a
## frame longer, because the thing it is doing underneath is the invitation to
## touch it, and a frozen invitation is the one thing a waiting screen may not
## look like.
func _watch() -> void:
	if _replay != null:
		return
	# **Only over a run that has finished dying.** The screen writes recorded
	# state onto the live nodes and stops the field processing on the way in;
	# both are free once `_die()` has stopped the simulation for good and
	# neither is free a frame earlier. Today nothing can reach here otherwise --
	# the offer only goes up in WAITING -- which is exactly the kind of thing
	# that stays true until a second caller appears.
	if _life != Life.WAITING:
		return
	if not ResourceLoader.exists(REPLAY_SCENE):
		push_error("[NormalMode] No replay screen at %s" % REPLAY_SCENE)
		return
	var packed: PackedScene = load(REPLAY_SCENE)
	if packed == null:
		return
	_watch_ui.hide()
	_bus.attach(null)
	_replay = packed.instantiate()
	_replay.set(&"recorder", _recorder)
	# **The re-attach rides on the screen's own lifetime, not on this file's
	# discipline.** The detach above and the attach in `_close_replay` were a
	# hand-maintained pair, and a pair is only as good as the routes that
	# honour it: the replay frees itself when its parent has no
	# `_replay_closed`, and that route would have left `_replay` pointing at a
	# freed object with the bus still unplugged -- a permanently frozen death
	# screen, silent until somebody reported that the game had stopped.
	# `tree_exited` fires however the screen goes away, including that one.
	# Bound to the screen it came from so a late signal from a replaced one
	# cannot take the new one down with it.
	_replay.tree_exited.connect(_close_replay.bind(_replay))
	add_child(_replay)


## Closing the screen puts the offer back: the run has not restarted, and a
## second watch costs nothing.
func _replay_closed() -> void:
	_close_replay()
	if _life == Life.WAITING:
		_offer_replay(true)


## **Idempotent, and it has to be**, because it is now reached twice on the
## ordinary path: once from `_replay_closed` and again when the node it just
## freed leaves the tree. Clearing the handle *before* freeing is what makes
## that safe -- the `tree_exited` that `queue_free` eventually causes finds a
## null handle and returns, so there is no way round the loop a second time.
##
## [param from] is set only by that signal, and only to say which screen sent
## it; anything else means the screen has already been replaced and the signal
## is stale.
func _close_replay(from: Node = null) -> void:
	if _replay == null or (from != null and from != _replay):
		return
	var screen: Node = _replay
	_replay = null
	if is_instance_valid(screen) and not screen.is_queued_for_deletion():
		screen.queue_free()
	# Reached during this run's own teardown as well, when a scene change takes
	# the whole tree out: everything has exited the tree by then but nothing has
	# been freed, so the material is still there to write to. Guarded anyway,
	# because a null uniform write is not worth a crash on the way out.
	if is_instance_valid(_membrane) and is_instance_valid(_bus):
		_bus.attach(_membrane.field.material as ShaderMaterial)


## A touch, a click or a key on the held black. Anything at all, because there
## is nothing on screen to aim at.
func _wake_up() -> void:
	# Before anything is rebuilt: the screen is reading the nodes below, and
	# **a run keeps nothing** -- the replay is the last thing this run has and
	# it dies with it.
	_offer_replay(false)
	_life = Life.RETURNING
	_death_clock = 0.0
	_cell.reset()
	_metabolism.reset()
	_motes.setup(_cell)
	_food.setup(_cell)
	_genome.setup(_cell)
	_soma.setup(_cell, _genome)
	# A new cell is a born cell, and a born cell has no senses: the five-second
	# clock starts again, and so does the line that announces it. **A run keeps
	# nothing** -- and that has to include the leg-up and the lineage.
	_sense_clock = 0.0
	_sensed = false
	_generation = 1
	_said_divide = false
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
	_vision.set_active(_vision_active())
	_vision.set_camera_locked(_camera_locked)
	# The self-figure is the point-of-view answer to "where am I facing". Full
	# vision already draws the real body at the real place, so a second, scaled,
	# screen-centred copy of it would be two cells claiming to be the player --
	# and the same argument retires the beam pointer and the ping wave, which
	# full vision has been drawing in the water since Phase 5.
	_show_self(not _vision_active() and _life == Life.ALIVE)


## **The two point-of-view layers that draw over the membrane**, switched
## together because they are on screen under exactly the same conditions: the
## figure in the middle and the marks the senses leave in the water around it.
## Four call sites had the condition written out; one of them drifting would be
## a body with no returns or returns with no body, and neither is a picture.
func _show_self(on: bool) -> void:
	_soma.set_active(on)
	_returns.set_active(on)


## **Forward is always up.** Beside `light` on the pause column, same slab, same
## 48px gap, because it is the same kind of thing: how this player wants the
## game presented, not a property of the run. Remembered, so a player who wants
## it does not re-choose it every launch.
func _toggle_camera() -> void:
	_camera_locked = not _camera_locked
	_vision.set_camera_locked(_camera_locked)
	RunState.save_camera_locked(_camera_locked)
	_update_view_button()


func _update_view_button() -> void:
	_view_button.text = "forward up" if _camera_locked else "north up"


## True while the world layer is the thing behind the Hud. Read by the pause
## scrim as well as by the mode seam, because how much has to be covered up
## depends entirely on whether there is a lit world under it.
func _vision_active() -> bool:
	return mode == RunState.Mode.FULL_VISION


## Flips the view without leaving the run, so blind and sighted can be compared
## on the same cell in the same water. Deliberately not remembered: the mode
## select is the supported way to choose, and this is a comparison.
func _toggle_mode() -> void:
	mode = RunState.Mode.POV if mode == RunState.Mode.FULL_VISION else RunState.Mode.FULL_VISION
	if _life == Life.ALIVE:
		_apply_mode()


# ---------------------------------------------------------------------------
# The one line of text in normal mode. It carries two things now.
#
# The steering line is onboarding: first run only, held until the player turns.
# The sense line is a **notice** -- something happened to your body a moment
# ago -- and it shows on every run, because the thing it announces happens on
# every run and a player who missed it once is a player swimming blind. It is
# short, lowercase and in the same voice, and it is gone seven seconds later.
#
# perception.md §6.1's "one string in normal mode" is stretched to two by this,
# and deliberately: the alternative to telling the player a gene is waiting is
# a second heartbeat they have never been taught to read.
# ---------------------------------------------------------------------------

func _begin_onboarding() -> void:
	_onboarding.modulate.a = 0.0
	_onboard_from = 0.0
	_onboard_hold = 0.0
	if _seen_onboarding():
		_onboarding.hide()
		_onboard = Onboard.OFF
		return
	_onboard_steer = true
	_onboarding.text = "drag to turn" if _touch_first() else "A · D to turn"
	_onboarding.show()
	_onboard = Onboard.WAITING
	_onboard_clock = 0.0


## **A sense arrived, and here is where to put it.** The pause screen is the
## only place a sample can be placed, so the line names the gesture that gets
## there -- Back on the one touch platform we ship, Escape everywhere else --
## and the strip's own hint takes over from there.
func _say_sense() -> void:
	_say("a sense grew · back to place it" if _touch_first()
		else "a sense grew · esc to place it", SENSE_LINE_HOLD)


## Puts [param text] on the line and fades it in from wherever the line already
## is, so a notice arriving over the steering line is a change of words and not
## a blink. [param hold] is how long it stays once it is up.
func _say(text: String, hold: float) -> void:
	_onboard_steer = false
	_onboard_from = _onboarding.modulate.a
	_onboard_hold = hold
	_onboarding.text = text
	_onboarding.show()
	_onboard_clock = 0.0
	_onboard = Onboard.FADE_IN


func _step_onboarding(delta: float) -> void:
	if _onboard == Onboard.OFF:
		return

	# The instant they first turn, whatever the line is doing, it goes -- but
	# only while the line is the one that is teaching them to turn. A notice
	# about their own body must not vanish because they happened to be steering
	# when it arrived, which at five seconds in they usually are.
	if _onboard_steer and _onboard != Onboard.FADE_OUT \
			and absf(_cell.steer) > CellBody.STEER_DEADZONE:
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
			_onboarding.modulate.a = lerpf(_onboard_from, 1.0,
				minf(_onboard_clock / ONBOARD_FADE_IN, 1.0))
			if _onboard_clock >= ONBOARD_FADE_IN:
				# It has been read. Even if they quit now, do not nag next run.
				if _onboard_steer:
					_mark_onboarding_seen()
				_onboard_clock = 0.0
				_onboard = Onboard.HOLD
		Onboard.HOLD:
			# The steering line stays until they turn -- they have not learned
			# the verb yet. A notice has no verb to wait for, so it times out.
			if _onboard_hold > 0.0 and _onboard_clock >= _onboard_hold:
				_onboard_from = _onboarding.modulate.a
				_onboard_clock = 0.0
				_onboard = Onboard.FADE_OUT
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
# Reaching pause without the gesture that hides itself.
#
# **The problem is Android and it is real.** Back is the only way in on a phone,
# and in a fullscreen app the gesture bar is hidden -- so reaching pause is a
# swipe to reveal it and then a swipe to use it. Two actions for the one control
# that every other control lives behind.
#
# **This is an addition, not a replacement.** Back and Esc are untouched; they
# are still the fast path for anyone who has them. What is added is a target.
#
# docs/design/diegetic-hud.md §3 bans numbers, letters and icons in the
# playfield. That rule is about *readouts* -- it exists so the HUD cannot
# compete with the senses -- and a control the player presses is not a readout.
# The lead has resolved the collision in favour of the control. What the rule
# still binds is the volume: this is the quietest thing on the screen that can
# still be found and hit.
#
# Three decisions and the argument for each:
#
# - **A geometric mark, in a corner.** The water contains no straight lines and
#   no right angles -- that is precisely what the diegetic rule bought -- so a
#   rounded slab with two bars in it cannot be mistaken for a sensation. The
#   grammar that says *this is interface* was already paid for.
# - **Quiet, and always there.** A phone has no hover, so a control that
#   appeared on touch would need a touch to find, and a touch in the playfield
#   already steers and dashes. It is visible at all times and faint enough to
#   ignore; the mouse gets the bright state on hover, which costs a touch player
#   nothing.
# - **Top left, one launcher edge margin in.** The launcher puts BIOGENIC in
#   that corner at `edge_margin = 48`, so the corner the player has already seen
#   carrying this game's chrome is the corner the game keeps it in. Away from
#   where a thumb rests in landscape, which is the bottom two corners, so the
#   steering gesture cannot fire it by accident.
# ---------------------------------------------------------------------------

## 56 canvas px: above CLAUDE.md's 48, and 84 device px at 2400x1080, which is
## about 7 mm of thumb.
const PAUSE_TAP_SIZE := 56.0
## Two bars, sized off the slab rather than off a glyph sheet: a third of it
## tall, and far enough apart to still read as two at 1:1.
const PAUSE_BAR_W := 4.0
const PAUSE_BAR_H := 18.0
const PAUSE_BAR_GAP := 6.0
## The whole of the "quietest thing that is still hittable" decision. Rest is
## what a touch player always sees; hot is the mouse hovering it.
const PAUSE_REST := 0.17
const PAUSE_HOT := 0.92

func _update_pause_tap() -> void:
	# **Hidden wherever pause cannot be reached**, which is not a nicety: a
	# control that is drawn and does nothing teaches the player that tapping it
	# does nothing. Pause is refused during a division (the choice has no
	# default) and a dead cell's Back is the exit rather than the pause, so
	# neither state gets a button.
	var wanted := _life == Life.ALIVE and _split == Split.NONE \
		and not get_tree().paused
	if _pause_tap.visible == wanted:
		return
	_pause_tap.visible = wanted
	if not wanted:
		_pause_hot = false


func _on_pause_tap(event: InputEvent) -> void:
	if not _is_widget_tap(event):
		return
	# Swallowed, and it has to be: an unclaimed press in the playfield is a
	# steer, and a short unclaimed press is a `myoneme` dash that costs hunger.
	# Godot delivers a phone touch twice -- once as itself and once as an
	# emulated click -- so both copies are claimed here and [method
	# _toggle_pause]'s same-frame guard is what stops the pair toggling twice.
	_pause_tap.accept_event()
	_toggle_pause()


func _set_pause_hot(hot: bool) -> void:
	if _pause_hot == hot:
		return
	_pause_hot = hot
	_pause_tap.queue_redraw()


func _draw_pause_tap() -> void:
	var box := _pause_tap.size
	var well := _pause_well_hot if _pause_hot else _pause_well_rest
	var bar := _pause_bar_hot if _pause_hot else _pause_bar_rest
	_pause_tap.draw_style_box(well, Rect2(Vector2.ZERO, box))
	var mid := box * 0.5
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var left := mid.x + side * (PAUSE_BAR_GAP + PAUSE_BAR_W) * 0.5 \
			- PAUSE_BAR_W * 0.5
		_pause_tap.draw_style_box(bar, Rect2(
			Vector2(left, mid.y - PAUSE_BAR_H * 0.5),
			Vector2(PAUSE_BAR_W, PAUSE_BAR_H)))


## The slab, in the pause column's own colours: what you tap looks like a piece
## of the surface it opens.
func _well(fill: float, edge: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.063, 0.141, 0.125, fill)
	box.border_color = Color(0.12, 0.70, 0.58, edge)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	return box


func _bar(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.855, 0.953, 0.933, alpha)
	box.set_corner_radius_all(2)
	return box


# ---------------------------------------------------------------------------
# Leaving. Back on Android, Esc on desktop; neither costs a pixel.
# ---------------------------------------------------------------------------

## **One Back per frame, whichever way it arrives.**
##
## Android has historically delivered Back as a notification, as a key event, or
## as both, depending on the version -- which is why `_toggle_pause` has carried
## a same-frame latch since Phase 2. The replay gave that hazard a second and
## worse ending: this notification closes the replay *synchronously*, so a
## duplicate `ui_cancel` arriving behind it in the same frame finds `_replay`
## already null and `_life` not ALIVE, and leaves the run. The player asked to
## close a screen and lost the death screen under it.
##
## Latched here rather than by dropping the notification branch, because
## dropping it is the version-dependent answer: on a build that delivers only
## the notification, Back inside the replay would stop working altogether unless
## the screen grew a `_notification` of its own -- which puts an Android quirk
## inside a file that knows nothing about Android. One counter, both doors.
##
## Both doors are read inside the same engine iteration, so they see the same
## `get_process_frames()`. That is the assumption `_toggle_pause`'s own latch
## has been shipping on.
func _back_once() -> bool:
	var frame := Engine.get_process_frames()
	if frame == _last_back_frame:
		return false
	_last_back_frame = frame
	return true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if not _back_once():
				return
			# Back out of the replay first: it is a screen the player opened,
			# and the gesture that closes a screen closes the top one.
			if _replay != null:
				_replay_closed()
			# Pausing a dead cell is nonsense, so Back during a death is the
			# exit -- straight out, skipping the pause screen.
			elif _life != Life.ALIVE:
				_leave()
			else:
				_toggle_pause()
		NOTIFICATION_DRAG_END:
			# **A drag that ends on nothing is a move that did not happen.**
			# Godot posts this to the whole tree whether the release landed on a
			# drop target or on open screen, so the one place the lifted gene
			# goes back into its locus is here -- and a mis-drag costs exactly
			# what a mis-tap costs, which is nothing.
			if _dragging != SLOT_NONE:
				_dragging = SLOT_NONE
				_redraw_strand()
				_update_explain()
				_update_hint()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Switching apps mid-drag never delivers the release, and a pointer
			# stuck down means a cell that turns forever. Deliberately does not
			# pause: a pause screen nobody asked for is its own bug.
			_cell.release()
			# The same argument for the strand: a finger that left with the
			# app never lifts, so the placement it was holding is abandoned
			# rather than left waiting for a release that cannot come.
			_primed = SLOT_NONE


## **First contact decides the gesture, and this is the function that makes that
## true** (§4.1). It is here rather than in [method _unhandled_input] because
## the unhandled pass cannot see the events it would have to decide about, and
## that is a hole in the GUI layer no `MOUSE_FILTER` gets you out of.
##
## **What the engine does.** `Viewport::push_input` runs the `_input` group
## first, then `_gui_input_event`, then the unhandled pass -- Godot's documented
## propagation order, not an implementation detail. At the
## `InputEventScreenDrag` branch of `_gui_input_event`, 4.7 reads
## `gui.touch_focus[index]` and, **when it is null, hit-tests the drag afresh at
## wherever the finger is now**. `touch_focus` is only written when the *press*
## landed on a `Control`. A lean's press lands on the playfield, on nothing --
## so it has no focus, every one of its drags gets hit-tested, and the first one
## that passes over a locus is marked handled, because a `MOUSE_FILTER_STOP`
## control that is handed a pointer event consumes it whether it wanted it or
## not. `_unhandled_input` never sees that drag. The mouse has the same hole by
## the same mechanism: motion is hit-tested whenever `gui.mouse_focus` is null.
##
## **What that cost, measured on the code before this existed**, at
## `--fixed-fps 60`: a finger pressed at canvas 930,300 -- resting on the
## starboard block -- and slid two pixels **never leans at all**. No timeout, no
## default, no feedback; only lifting and pressing again outside the block
## recovers it. The same finger 170 px outboard, in open water, commits at
## 7.92 s. And a lean begun in port water that slides onto the starboard block
## commits the **port** daughter while sitting on the starboard side, because
## the drag that would have moved it was eaten in transit. One hole, both
## symptoms.
##
## **Why claiming it here is proof rather than a thing that happens to work.**
## The hit-test fallback lives inside `_gui_input_event`. An event consumed in
## the `_input` pass never reaches `_gui_input_event` at all, so the fallback
## cannot run -- and that holds for any control, any mouse filter, any focus
## state, and it goes on holding if the GUI's routing changes again, because it
## does not depend on the routing. Nothing below asks the engine what is under a
## drag: ownership is decided once, at first contact, keyed by pointer index,
## and every later event of that gesture is dispatched on **whose finger it is**
## rather than on what it is over. The rect the loci occupy is never consulted
## here, so it cannot disagree with the one the player sees light up.
##
## **The one engine behaviour this does lean on** is the one the same reading of
## the source settles: a press and its release route strictly by `touch_focus`
## and are never hit-tested. That is what lets the press decide -- a locus is
## handed the press only when the press was really on it -- and it is what lets
## both fall through untouched: the press so that a locus can claim the gesture
## from its own `gui_input`, which runs after this function and before the
## unhandled pass, and the release so that [method _read_touch_lean] can undo a
## lean. A locus can never be handed another finger's release, so letting go is
## safe to leave where it already was.
## **The paused test is the gate's own safety argument, made local.** Inside
## this gate the function swallows every held pointer motion, and `NormalMode`
## is `process_mode = 3`, so `_input` fires through a pause. What makes that
## harmless today is a fact in a different function: [method _toggle_pause]
## returns early while `_split != Split.NONE`, so the pause screen provably
## cannot be open during a division. That is true, and it is the kind of true
## that stops being true silently -- anyone who later allows pausing mid-split
## would find the light slider had stopped dragging, with no error and nothing
## to grep for. `paused` is false for the whole of a division (`_set_simulating`
## stops nodes with `set_process`, it does not pause the tree), so this test
## costs nothing now and holds the invariant where it is used.
func _input(event: InputEvent) -> void:
	if _replay != null or _split < Split.PART or get_tree().paused:
		return
	var index := _pointer_index(event)
	if index == POINTER_NONE:
		return
	if event is InputEventScreenTouch:
		# A lean until a locus says otherwise, which it does on this same event,
		# microseconds from now, in the GUI pass.
		if (event as InputEventScreenTouch).pressed:
			_choose_gesture[index] = false
		else:
			_choose_gesture.erase(index)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_choose_gesture[index] = false
		else:
			_choose_gesture.erase(index)
		return
	if event is InputEventMouseMotion \
			and ((event as InputEventMouseMotion).button_mask \
				& MOUSE_BUTTON_MASK_LEFT) == 0:
		# A bare hover is not a gesture and is left entirely alone, so the
		# desktop read -- point at a locus, get its line -- still works (§4.4).
		return
	# Everything past here is a drag or a held motion: exactly the events the
	# fallback above can reach, and therefore the only ones that have to be
	# claimed before the GUI is given the chance.
	if _choose_gesture.get(index, false):
		# A read, for the life of the gesture, however far it slides -- into
		# open water and back again included. Swallowed rather than forwarded:
		# a locus does nothing with a drag but consume it, and one owner is
		# easier to reason about than two.
		get_viewport().set_input_as_handled()
		return
	if _read_touch_lean(event):
		get_viewport().set_input_as_handled()


## Which pointer an event belongs to: a touch index, [constant POINTER_MOUSE]
## for anything the mouse produces, or [constant POINTER_NONE] for an event with
## no pointer behind it -- a key, a pad button, `ui_accept`.
func _pointer_index(event: InputEvent) -> int:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).index
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).index
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return POINTER_MOUSE
	return POINTER_NONE


func _unhandled_input(event: InputEvent) -> void:
	# **While the replay is up, this run is not listening.** The screen consumes
	# everything it is handed and is deeper in the tree, so nothing should reach
	# here at all -- but the failure if one ever did is that watching a replay
	# restarts the run under it, which is not a failure to leave to tree order.
	if _replay != null:
		return
	if event.is_action_pressed(&"ui_cancel"):
		# The other door Back comes through. Consumed either way: a Back already
		# answered this frame is still a Back, and letting it fall through to
		# the branches below would restart the run.
		if _back_once():
			if _life != Life.ALIVE:
				_leave()
			else:
				_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	# **Leaning into one of them.** The screen halves are the targets, because a
	# 96 px body is not a 48 px target with a thumb over it, and a lean has to be
	# *held* -- so a tap commits nothing and there is no arming pattern in the
	# playfield. Read here rather than on the cell, whose input has stopped with
	# the rest of the simulation.
	#
	# **Presses and releases, in practice.** [method _input] has already claimed
	# every drag and every held motion of a division, because those are the ones
	# the GUI hit-tests and steals. What still arrives here is a press in open
	# water, which starts a lean, and a release, which ends one -- both route
	# strictly by `touch_focus` and reach the unhandled pass untouched. Left
	# whole rather than split further: this is the same call either way, and the
	# gesture it reads is the same gesture.
	if _split >= Split.PART and _read_touch_lean(event):
		get_viewport().set_input_as_handled()
		return

	# The dead membrane is waiting to be touched, and there is nothing on it to
	# aim at, so anything counts.
	if _life == Life.WAITING and _is_tap(event):
		# **Except the one thing there now is to aim at.** A `Button` consumes
		# its own press, so this branch should never see it -- and measured,
		# under a real window, it does not. It is written down anyway because
		# the cost of being wrong is the worst one on this screen: the offer
		# would open the replay and start the next cell underneath it in the
		# same frame, and whether a finger reaches here at all is a question
		# about Godot's touch-to-mouse emulation rather than about this file.
		# `_watch()` is idempotent, so the two paths agreeing costs nothing.
		if _over_watch(event):
			_watch()
		else:
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


## A finger or a held click on one half of the screen, as a signed lean: -1 at
## the port edge, +1 at the starboard edge, 0 at the exact middle. Returns true
## when the event was one of ours.
##
## Absolute positions rather than relative, and the mouse only claims the lean
## when touch has not -- the same two rules cell.gd's steering obeys, for the
## same reason: Godot emulates a mouse from every touch, so the two arrive as a
## pair on Android.
func _read_touch_lean(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -2:
				_touch_index = touch.index
				_touch_lean = _lean_at(touch.position)
		elif _touch_index == touch.index:
			_touch_index = -2
			_touch_lean = 0.0
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		# **A thumb that was already down is adopted here**, and it has to be:
		# the steering gesture is a finger on the screen, so a player who was
		# steering when the body pinched is still holding one when the two of
		# them appear. Their press happened before there was anything to lean
		# at, so the only event we will ever see from that finger is a drag --
		# and asking them to lift and press again to answer the biggest beat in
		# the game is the kind of thing that only looks fine in code.
		#
		# **It only fires because [method _input] calls this before the GUI
		# pass.** Reached from the unhandled pass it was unreachable the moment
		# that thumb was resting anywhere on a strand block, because the block
		# ate the drag on the way past -- which is a player who cannot answer
		# the division at all. Measured; see [method _input].
		if _touch_index == -2:
			_touch_index = drag.index
		if _touch_index == drag.index:
			_touch_lean = _lean_at(drag.position)
		return true
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return false
		if click.pressed:
			if _touch_index == -2:
				_touch_index = -1
				_touch_lean = _lean_at(click.position)
		elif _touch_index == -1:
			_touch_index = -2
			_touch_lean = 0.0
		return true
	if event is InputEventMouseMotion:
		var moved := event as InputEventMouseMotion
		# The same adoption, for a button that went down before there was
		# anything to press it at.
		if _touch_index == -2 \
				and (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_touch_index = -1
		if _touch_index != -1:
			return false
		_touch_lean = _lean_at(moved.position)
		return true
	return false


## Where a point on the screen falls, as a lean.
func _lean_at(at: Vector2) -> float:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if half <= 0.0:
		return 0.0
	return clampf((at.x - half) / half, -1.0, 1.0)


## Whether a tap landed on the `watch` offer. False for anything with no
## position -- a key or a pad button on the held black is the *anything at all*
## the death screen has always accepted, and it still starts the next cell.
func _over_watch(event: InputEvent) -> bool:
	if not _watch_ui.visible:
		return false
	if event is InputEventScreenTouch:
		return _watch_button.get_global_rect().has_point(
			(event as InputEventScreenTouch).position)
	if event is InputEventMouseButton:
		return _watch_button.get_global_rect().has_point(
			(event as InputEventMouseButton).position)
	return false


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
	# **Not during a division.** The tree is already stopped, the choice has no
	# timeout and no default, and a pause screen over two daughters would put
	# the DNA strip on top of the one moment it is a picture of. Back and Esc do
	# nothing for the six seconds it takes; leaving is one lean away.
	if _split != Split.NONE:
		return
	var frame := Engine.get_process_frames()
	if frame == _last_toggle_frame:
		return
	_last_toggle_frame = frame

	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_ui.visible = paused
	# **A gene in the air does not survive the screen closing.** Godot's drag
	# preview is parented to the viewport and not to this column, so closing
	# pause with a gene lifted would leave a base pair floating over open water
	# until the finger came up.
	#
	# **This is reachable on Android and unreachable by Esc, which is the
	# opposite of what it looks like.** Both halves were posed and traced.
	# `Esc` mid-drag never gets here at all: `Viewport` consumes `ui_cancel`
	# while `gui.dragging` and cancels the drag itself, so the key never
	# reaches `_unhandled_input` and the guard is dead code on that path.
	# Android Back does get here mid-drag, because it arrives as
	# `NOTIFICATION_WM_GO_BACK_REQUEST` and not as an input event -- nothing
	# consumes a notification -- and a thumb dragging a base pair can reach the
	# Back gesture with its other hand or with the navigation bar. So this
	# call is the only thing standing between a one-handed Back and a gene left
	# hanging over the water, and it must not be deleted as desktop-only
	# tidiness.
	if get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	# In the same frame rather than on the next one: the button is what was just
	# tapped, and a frame of it still sitting there under the scrim is a frame of
	# the game looking like it did not hear.
	_update_pause_tap()
	# **Both of these are the scrim argument again.** The pause column is
	# centred and so is the self-figure, so the light slider's track ran
	# straight through the cell's own cilia -- the exact failure that took the
	# world view down to a ghost behind SCRIM_FULL_VISION. The membrane stays,
	# because it is the live preview of the slider; the body and the line are
	# not, and the strip above is a better mirror than either. Rendered.
	_show_self(not paused and not _vision_active() and _life == Life.ALIVE)
	_onboarding.visible = not paused and _onboard != Onboard.OFF
	if paused:
		# A finger still down when the pause opened must not keep steering.
		_cell.release()
		# **The scrim is set per view, and the reason is the camera.** The
		# camera holds the player's cell at the exact centre of the screen and
		# the pause column is centred too, so in full vision the light control
		# is always drawn across the player's own body. Nothing can move: the
		# cell is pinned by the camera and the column is pinned by the house
		# style. Since Phase 5 gave every body a bright multicoloured fringe and
		# a gape bow, that overlap stopped being quiet and started being
		# unreadable -- the slider track runs through the cilia and `light`
		# lands on the mouth.
		#
		# So the world is taken down to a ghost instead. Nothing is lost: pause
		# is a surface the *player* consults (§5.1) and the water is not what
		# they came to read. In point of view the scrim stays where Phase 4 put
		# it, because there the membrane is the live preview of the very slider
		# below it -- and that costs nothing, because the membrane only ever
		# draws in the outer ~150px of the viewport, which the column never
		# reaches. Measured, at both shapes.
		_scrim.color = SCRIM_FULL_VISION if _vision_active() else SCRIM_POV
		# Built on opening rather than kept in step: the genome cannot change
		# while the tree is paused except by the two taps below, and a strip
		# rebuilt sixty times a second to say the same thing is five nodes of
		# churn a frame for nothing.
		# Nothing can be in the air on a screen that was not open, and a stale
		# source locus would draw a hole in the strand.
		_dragging = SLOT_NONE
		_primed = SLOT_NONE
		_select_default()
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
## in it -- and with a seven-locus strand above them that is 800px. Rendered,
## and it looked wrong; at 232 they stay the buttons Phase 4 shipped whatever is
## above them.
func _style_pause() -> void:
	for control: Control in [_light_panel, _view_panel, _resume_button,
			_leave_button]:
		control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# **Every group on the pause column is a surface, and `light` was the one
	# that was not.** `resume` and `leave` are slabs, the strand is a drawn
	# object of its own, and the light caption and its track were bare strokes
	# floating on
	# the water -- which is why they were the pair the player's own cell tangled
	# with. Same slab, same border, same radius -- but fainter than a button on
	# purpose, because it is a surface and not a third thing to press. One rule
	# a later screen can apply without asking: every group on this column is a
	# surface.
	_light_panel.add_theme_stylebox_override("panel", _slab(-0.2))
	# Same slab, same rule: every group on this column is a surface.
	_view_panel.add_theme_stylebox_override("panel", _slab(-0.2))
	_view_caption.add_theme_font_size_override("font_size", 16)
	_view_caption.add_theme_color_override("font_color",
		Color(0.855, 0.953, 0.933, 0.52))

	_genome_caption.add_theme_font_size_override("font_size", 15)
	_genome_caption.add_theme_color_override("font_color",
		Color(0.855, 0.953, 0.933, 0.45))
	_genome_hint.add_theme_font_size_override("font_size", 14)
	_genome_hint.add_theme_color_override("font_color",
		Color(0.855, 0.953, 0.933, 0.38))

	for label: Label in [_explain_name, _explain_says]:
		label.add_theme_font_size_override("font_size", 15)
	_explain_says.add_theme_color_override("font_color", EXPLAIN_TINT)

	_pause_well_rest = _well(0.13, 0.09)
	_pause_well_hot = _well(0.58, 0.48)
	_pause_bar_rest = _bar(PAUSE_REST)
	_pause_bar_hot = _bar(PAUSE_HOT)

	# The camera toggle is a button, so it is styled like one -- but narrower and
	# shorter than `resume`, because it is a setting inside a surface and not a
	# thing that ends the run. Still 48 tall, which is the touch rule.
	_view_button.custom_minimum_size = Vector2(192.0, 48.0)
	_view_button.focus_mode = Control.FOCUS_ALL
	_view_button.add_theme_font_size_override("font_size", 16)
	for state: String in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color"]:
		_view_button.add_theme_color_override(state,
			Color(0.855, 0.953, 0.933, 0.92))
	_view_button.add_theme_stylebox_override("normal", _slab(0.0))
	_view_button.add_theme_stylebox_override("hover", _slab(0.35))
	_view_button.add_theme_stylebox_override("pressed", _slab(0.5))
	_view_button.add_theme_stylebox_override("focus", _slab(0.35))

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
	# 192 plus the slab's 20px side margins is 232 -- exactly the button width,
	# so the column has one edge rather than two. Still 48 tall, and 192 canvas
	# px is 18mm of travel on a 2400x1080 phone.
	_gain_slider.custom_minimum_size = Vector2(192.0, 48.0)
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
# The strand, on the pause screen. docs/design/dna-strand.md.
#
# **It is a chromosome, not a row of boxes.** A real chromosome is a strand,
# genes sit at loci along it, and a locus is exactly the slot-is-an-arc idea the
# game already had -- so the biology handed the layout over and the row of
# square tiles was the thing that had been invented. Every channel the tiles
# carried has a place on a strand that is more literal than the place it had on
# a tile:
#
#   the plain word    under its own locus, where a chromosome map puts it
#   the tier          **copies**: one, two or three rungs at the locus. Gene
#                     dosage is real, it is why the tier now decides how likely
#                     a daughter is to wear the organ, and it is countable
#   which arc         the dart, beside the word, unchanged and still the reason
#                     placement is a decision
#   the two registers a rung that reaches both backbones is an organ this body
#                     wears; one floating clear in the middle is one the DNA
#                     carries and the body does not. Shape, so it survives a
#                     luminance-only render
#   the selection     the lens between the backbones fills, and the word goes
#                     loud. The explanation line below is unchanged
#   the held sample   a loose base pair floating over the locus it is being
#                     placed into, on a thread. The two taps are unchanged
#
# **A launcher-themed surface, not the membrane aesthetic.** The membrane is
# what the cell feels; this is what the player consults. It lives on pause
# because pause already has widgets, already has the house style and is already
# reachable by a gesture the player knows.
# ---------------------------------------------------------------------------

## One locus: 96 canvas px of strand, 86 tall, and the **whole block** is the
## touch target -- sample band, weave and label. That is 144 x 129 device px at
## 2400x1080 against a 48 px rule.
const LOCUS_W := 96.0
const LOCUS_H := 86.0
## Half-lenses per locus. **Odd on purpose, and that is geometry rather than
## taste**: a locus has to begin and end at a crossing so neighbours join with
## no seam, and its centre has to be at maximum separation so the rungs are the
## same length at every locus. Only an odd count does both. One lobe of 96 px
## against 36 of swing is a 2.7:1 lens and reads as two crossing waves;
## three of 32 against 36 of swing is round, and reads as DNA.
const LOCUS_LOBES := 3
const LOBE_W := LOCUS_W / float(LOCUS_LOBES)
## The lead-in and the tail, in lobes: the chromosome arrives and leaves rather
## than starting mid-lens. Two, because the head is where a held sample waits
## before a locus has been chosen and it needs room for the bar and its word;
## the tail matches so the loci stay centred in the row whatever is held.
const CAP_LOBES := 2
const CAP_W := LOBE_W * float(CAP_LOBES)

## Inside a locus, measured from its top edge.
const BAND_MID := 13.0     ## the held sample floats here, over its destination
const HELIX_MID := 47.0
const HELIX_AMP := 18.0
const LABEL_MID := 76.0    ## the dart's centre
const LABEL_BASE := 81.0   ## the word's baseline

## **The backbone, the depth alpha, the rung states and the segment count all
## live in `cilia.gd` now**, because the division's choosing screen draws the
## same helix on its side and two copies of a drawing drift apart. See
## `Cilia.STRAND_*` and choosing.md §9.1; what stays here is this surface's own
## geometry, which is the only thing the two screens disagree about.
##
## The selected locus's own stretch of backbone, brighter.
const BACKBONE_LIT := 1.25

## The lens between the backbones, filled on the selected locus. Area, not a
## border -- there is no box to put a border on any more, and a filled lens is
## the one mark that cannot be confused with a rung.
const LENS_SELECTED := 0.20
## An empty locus has no gene, so its selection and its dart are the column's
## own pale tint.
const PALE := Color(0.855, 0.953, 0.933)

## The held sample: a base pair that is not in a ladder yet.
const SAMPLE_BAR := 15.0
const SAMPLE_WIDTH := 2.6
const SAMPLE_CAP := 2.5
const SAMPLE_GAP := 6.0    ## between the bar and its word
const SAMPLE_WORD := 13
## Two rings, not a disc: a crisp-edged disc of even tone is the silhouette of a
## widget, which diegetic-hud.md §2 spent three passes establishing.
const SAMPLE_HALO: Array[float] = [9.0, 13.5]
const SAMPLE_HALO_ALPHA: Array[float] = [0.11, 0.05]
const SAMPLE_THREAD_ALPHA := 0.38

## **The body strand: the same weave at the same pitch**, with no sample band
## and its label row *above* its helix. `HELIX_AMP` is shared, so the two rows
## are the same object at the same scale and a rung on one is comparable with a
## rung on the other by eye.
##
## **The labels go outboard of the pair, and it was built both ways.** With both
## label rows under their own helix, the DNA row's 26 px sample band sits
## beneath the body's words -- a held sample and a body dissent land 25 px apart
## in one column -- and the two weaves end up 77 px apart instead of 37.
## Outboard puts the sample alone in the band it owns and halves the distance
## the eye travels to compare two rungs.
const BODY_LOCUS_H := 58.0
const BODY_HELIX_MID := 40.0     ## the helix spans 22 .. 58 of its own control
const BODY_LABEL_MID := 11.0     ## the dart's centre
const BODY_LABEL_BASE := 16.0    ## the word's baseline

## How far above the pointer the travelling gene rides during a move.
##
## **Above the finger, not under it.** A fingertip is about 9 mm, which at
## 2400x1080 is roughly 100 canvas units -- one whole locus -- so a preview
## centred on the pointer and a lens filling beneath it are both under the thumb
## on a phone. 34 px lifts the base pair into the band a DNA locus already
## reserves for a held sample, which is as far as it can go before it collides
## with the body row. It is drawn because a mouse can see it; the `Act` line is
## what a thumb reads.
const DRAG_LIFT := 34.0

## The row label gutter: `body` over `dna`, right-aligned against the lead-in.
## One caption per row, where a second `Label` row of the column would cost a
## whole line of height to say two words.
##
## **Each row ends with the same width, invisible**, or the strand sits half a
## gutter left of the centre every other group on this column is centred on.
## Measured at 7 px, and visible against the `Explain` line below it. This is
## genes-and-cilia.md §5.2's trailing-spacer trick, deleted by dna-strand.md
## §1.4 when the sample stopped changing the strand's width, and earned again
## here for a different reason.
const GUTTER_W := 64.0
const GUTTER_TINT := Color(0.855, 0.953, 0.933, 0.45)
const GUTTER_SIZE := 15

const DART_R := 6.5
const DART_GAP := 4.0
## The second tap cannot land sooner than this after the first, so a double-tap
## -- or the mouse event Godot emulates from a touch -- cannot commit.
const ARM_GUARD_MS := 300
## Arming lapses on its own, so a strip left armed is not a trap.
const ARM_TIMEOUT_MS := 4000

## Every word Phase 5 adds to the screen is here, under a locus, or on the
## explanation line below the strand. perception.md §6.1's one string in normal
## mode is untouched.
##
## **"place", not "replace".** Every new gene is a placement decision now, and
## most of them land in an empty slot -- the slot is the arc, so which empty one
## is the whole question. The dart under each locus is what answers it.
## **"your daughters wear it", because placing no longer changes you.** One word
## of difference, and it is the whole of lifecycle.md §1 said on the one surface
## that can say it.
const HINT_ARM := "tap a locus · your daughters may wear it"
const HINT_COMMIT := "tap again to place"
## **What the hint says when nothing is held: how likely the selected locus is
## to reach a daughter.** Eating a gene writes it into the DNA; a daughter is a
## roll against that DNA, and copy number is the odds -- so the one line under
## the strand is where the rungs are put into words. It is said *before* the
## division, on the surface the player is already reading, which is the whole of
## "the chance must be legible before, not announced after".
const HINT_CHANCE: Array[String] = [
	"",
	"one copy · a daughter may not wear it",
	"two copies · a daughter probably wears it",
	"three copies · a daughter always wears it",
]
## The mouth is the one gene that always expresses (genome.gd's
## ALWAYS_EXPRESSED), so it says so instead of quoting odds it does not obey.
const HINT_CERTAIN := "the mouth · a daughter always wears it"
const HINT_EMPTY := "an empty locus · nothing to pass on from here"

## **The verb line: what you can do about the locus you are reading.**
##
## The two placement instructions moved here out of the hint, which is where
## they always belonged -- the hint's job is a readout and theirs is a verb --
## and the move's own instructions join them.
##
## **It is the third row down and it is *not* the third loudest, and that is
## deliberate rather than an oversight.** Measured off the render at 1280x720,
## peak glyph luminance: `Explain` 213, `Act` 122, `Hint` 98. The reading order
## down the column is still *what this is* -> *what it is worth* -> *what you
## can do*, but only the first step of it is a step down in loudness; the third
## row is separated from the second by **hue** instead. Two reasons, and the
## second is the one that would make dimming it a bug:
##
## - Teal is this surface's colour for *this responds*: the focus underline,
##   both buttons and the camera toggle are all the same green. A fourth pale
##   line would have read as a paragraph with the readouts above it.
## - **This is the only row that changes during a gesture, and on touch it is
##   the only feedback a thumb cannot cover.** `DRAG_LIFT` puts the travelling
##   base pair 34 px above the pointer and the destination lens fills *under*
##   it; at 2400x1080 a fingertip is about one whole locus wide, so both of
##   those are under the hand that is making the move. Making the line that
##   says `let go to swap eat and ping` the quietest thing on the column would
##   be quieting the one part of the move that is legible while it happens.
##
## It is empty when the selected locus is empty and nothing is held: there is
## nothing to do there, and a line that said so would be an instruction to read
## rather than a thing to act on.
const ACT_ARM := "tap a locus · your daughters may wear it"
const ACT_COMMIT := "tap again to place"
const ACT_MOVE := "drag it to another locus"
const ACT_CARRY := "%s · let go over a locus to move it there"
const ACT_LAND := "let go to move %s here"
const ACT_SWAP := "let go to swap %s and %s"
## **Letting go where you picked up is a real answer, not a missed drop.** It
## is the first thing a nervous player tries -- lift a gene, think better of
## it, put it back -- and it was silent: the source locus said exactly what open
## water said, so the one gesture whose whole point is *undo this* got no
## acknowledgement at all. The locus already draws the picture (its lens fills
## in the gene's own hue, which is that gene coming home); this is the sentence
## for it, and it fires while the finger is still down, which is when the
## player is still deciding.
const ACT_KEEP := "let go to leave %s where it is"

## How deep the lineage is: the only readout of how far into the run the player
## is, and the nearest thing the game has to a score. It moved from the hint to
## the caption when the hint took on the odds -- zero pixels either way.
const ORDINALS: Array[String] = ["first", "second", "third", "fourth", "fifth",
	"sixth", "seventh", "eighth", "ninth", "tenth"]

## The second, weaker channel behind the rungs: a gene the body does not wear
## draws its word and its organ fainter. Honest about which one does the work.
const ORGAN_UNEXPRESSED := 0.52
const WORD_UNEXPRESSED := 0.42

## **The plain word, never the biological name.** Four short verbs are parsed
## instantly at arm's length; nine letters of Greek are not, on the one screen
## whose whole job is a quick decision. §5.2, and the nine-character ceiling it
## sets is why a new gene needs a short word as well as a real organ name.
const WORDS := {
	&"cytostome": "eat", &"cirrus": "turn", &"flagellum": "swim",
	&"stigma": "see", &"ocellus": "beam", &"axoneme": "push",
	&"statocyst": "level", &"rhabdom": "focus", &"palp": "touch",
	&"myoneme": "dash", &"trichocyst": "sting", &"pellicle": "armor",
	&"toxicyst": "venom", &"plastid": "sun", &"vacuole": "store",
	&"crista": "burn", &"chemocyte": "smell", &"ampulla": "ping",
}

## **One line per gene, and it says what the gene does to the player** -- not
## what the organelle is. Eighteen tiles carrying one word each are enough to
## recognise a gene you already know and not enough to learn one, which is the
## whole of the owner's ask.
##
## The voice is the screen's: lowercase, plain, no jargon, one clause and then
## its consequence. No line names another gene, because a player reading `armor`
## has not necessarily met `cytostome` yet. No line carries a number: tiers are
## the pips' job and a line that said "+30%" would be the classic HUD this game
## spent two phases not building.
##
## `that side` in `ocellus` and `trichocyst` is deliberate and it points at the
## dart already drawn under the same locus -- the two directional genes are the
## two whose line has to explain why the locus mattered.
##
## **This line is also the one place the biological name reaches the screen, and
## that is a deliberate reading of §8 rather than a breach of it.** The rule §8
## states is that *the locus* wears the plain word, and the argument it gives is
## the glance: four short verbs are parsed at arm's length and nine letters of
## Greek are not, on the surface whose whole job is a quick decision. This line
## is not a glance -- it is read because the player stopped to read it -- so the
## name sits at the head of it and the plain word keeps the locus. §9.1 gives
## every gene two names on purpose; a name no player ever meets is a convention
## for the compiler, and CLAUDE.md's *realism is a tool* is the argument that
## `ampulla` is worth meeting.
const EXPLAINS := {
	&"cytostome": "a wider mouth swallows bigger things whole",
	&"cirrus": "turns you faster, and sooner after you ask",
	&"flagellum": "your tail beats harder, and more often",
	&"stigma": "feels the shadow of anything big, however dark",
	&"ocellus": "a ray out of that side, marking whatever it strikes",
	&"chemocyte": "smells food, and which way it is",
	&"ampulla": "a pulse that answers off everything, not just food",
	&"axoneme": "holding on pushes you, instead of only steering",
	&"statocyst": "always knows which way is up, however you turn",
	&"rhabdom": "sharpens where a smell is coming from",
	&"palp": "feels what is against you, with no light at all",
	&"myoneme": "tap for a burst of speed, paid for in hunger",
	&"trichocyst": "a dart at whatever closes in on that side",
	&"pellicle": "thicker skin, so bites take less and fewer mouths fit",
	&"toxicyst": "whatever bites you pays, and whatever swallows you dies",
	&"plastid": "makes a little of its own food, so you starve slower",
	&"vacuole": "a bigger tank, so hunger takes longer to reach you",
	&"crista": "burns cleaner, so everything you carry costs less",
}
## An empty locus has no gene to explain, so it explains the one thing it does
## have: a direction. The dart under it is what "this way" refers to.
const EXPLAIN_EMPTY := "nothing here yet · an organ here would look this way"
## Loud enough to be the thing you are reading, quieter than the word on the
## strand: caption 0.45, hint 0.38, locus word 0.66, this 0.62.
const EXPLAIN_TINT := Color(0.855, 0.953, 0.933, 0.62)
## The name is drawn in the gene's own hue, which is the hue of the rungs the
## player just tapped -- that is what ties the line to the locus with no arrow
## and no animation.
const EXPLAIN_NAME_ALPHA := 0.95

const LABEL_TINT := Color(0.855, 0.953, 0.933, 0.66)
const LABEL_TINT_LOUD := Color(0.855, 0.953, 0.933, 0.92)
const LABEL_SIZE := 13
## Focus has to be drawn, and it must not be a box: the whole point of the
## strand is that a locus is a place on a thread and not a square. An underline
## under the locus says where the keyboard is standing without rebuilding the
## thing that was replaced.
const FOCUS_TINT := Color(0.588, 1.0, 0.859, 0.85)
const FOCUS_INSET := 14.0
const FOCUS_WIDTH := 2.0

## What the explanation line is currently explaining, so the organ beside it can
## be redrawn from the same answer rather than deriving it a second time.
var _explain_gene: StringName = &""
var _explain_tier := 0
## The organ drawn beside the explanation, in canvas px of its own box.
const EXPLAIN_ORGAN_SIZE := Vector2(34.0, 26.0)
const EXPLAIN_ORGAN_SCALE := 0.60
## Where in that box the organ's own centre sits. **Measured, not chosen**: the
## tallest organ is `flagellum`, whose strokes reach `TILE_ARC_RADIUS +
## TILE_LEN` above the centre -- 18 px at this scale -- so any seat above 18.5
## puts the tuft outside its own row.
const EXPLAIN_ORGAN_SEAT := Vector2(17.0, 18.5)


## Rebuilds the strand from the genome as it is right now. Cheap and total:
## five to nine tiny nodes, built on opening the pause screen, on arming, on the
## arm lapsing and after a swap.
##
## **Every rebuild frees the locus the keyboard was standing on, so every rebuild
## has to hand the keyboard somewhere.** Godot does no focus navigation from a
## null focus: with `gui.key_focus` cleared, Tab does nothing, Enter does
## nothing, and `resume` and `leave` are unreachable until the player finds a
## mouse or presses Esc -- which resumes the run, which is not what they asked
## for. That is a dead pause screen, and it sits on top of the one irreversible
## action in the game.
##
## It lives here rather than at the call sites because there are four of them
## and the first attempt got three. [method _commit_slot] carried its own copy
## and [method _step_arming] did not, three lines apart; measured on a real
## display, arming a locus and then simply reading it for four seconds -- which
## is the behaviour §9.7 asks for when it sells *"three pips going dark before
## it is confirmed"* -- killed the keyboard.
func _build_genome_strip() -> void:
	# Taken before anything is freed. -1 means the keyboard was not on the
	# strip at all, and then nothing here should move it: the player is on
	# `resume`, or on the slider, or is using a thumb and has no focus ring to
	# lose.
	var keeping := _focused_slot()
	# Every locus about to be freed takes its hover with it, and Godot will not
	# re-enter a control the cursor never left. The selection carries the line
	# until the mouse moves again, which is the same locus either way.
	_hovered = SLOT_NONE
	# And with it goes any placement waiting on a finger: the control that took
	# that press is about to be freed, so the lift it was waiting for will
	# never arrive here. This is what makes the four-second lapse safe under a
	# held finger -- the arm went, so the confirmation goes with it.
	_primed = SLOT_NONE
	for row: HBoxContainer in [_body_row, _genome_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	_slot_genes.clear()

	# **The strip is the DNA**, and the body is the other register -- it is the
	# thing in the middle of the screen the rest of the time. What the body
	# dissents about is carried by the pips, which is where the tier is already
	# read. lifecycle.md §3.
	var dna := _genome.dna()
	var body := _genome.tiers()
	# **The layout, not the dictionary.** Slot index is the arc a gene is worn
	# on, and the layout is the only thing that knows about holes -- a genome
	# with the beam in slot 6 and nothing in slots 3 to 5 is a genome the player
	# built on purpose.
	_slot_genes.assign(_genome.layout())

	# maxi, not slots(), so a genome can never be longer than the strand that
	# claims to show it. **A newborn is over capacity and that is intended**: she
	# carries up to seven genes on a body whose slots() is 3, so she may replace
	# but not add until she grows.
	var count := maxi(_genome.slots(), _slot_genes.size())

	# **Nothing in either row moves when a sample arrives or lapses.** The old
	# strip grew a tile and an arrow on the left and needed an invisible
	# trailing spacer to stop the slots sliding 73 px; the sample now floats in
	# a band the locus already reserves, so the strand is the same width held or
	# not. The lead-in is where it waits before a locus has been chosen: off the
	# head of the chromosome, attached to nothing, which is exactly what a held
	# sample is.
	#
	# A trailing spacer is back, and for a different job: it mirrors the row's
	# label gutter so the weave stays centred on the column rather than sitting
	# half a gutter left of everything else. See GUTTER_W.
	#
	# **The body row first, because it is what you are.** Read top to bottom the
	# surface says *this is you* and then *this is what you are writing*, and
	# that is the order the owner's two sentences are in.
	var worn: Array[StringName] = _genome.body_layout()
	_body_row.add_child(_make_gutter("body", BODY_LOCUS_H))
	_body_row.add_child(_make_cap(0, 1, BODY_HELIX_MID, BODY_LOCUS_H))
	for i in count:
		var mine: StringName = worn[i] if i < worn.size() else &""
		var written: StringName = _slot_genes[i] if i < _slot_genes.size() \
			else &""
		_body_row.add_child(_make_body_locus(mine, int(body.get(mine, 0)), i,
			CAP_LOBES + i * LOCUS_LOBES, mine != written))
	_body_row.add_child(_make_cap(CAP_LOBES + count * LOCUS_LOBES, -1,
		BODY_HELIX_MID, BODY_LOCUS_H))
	_body_row.add_child(_make_spacer(BODY_LOCUS_H))

	_genome_row.add_child(_make_gutter("dna", LOCUS_H))
	_genome_row.add_child(_make_cap(0, 1, HELIX_MID, LOCUS_H))
	for i in count:
		var gene: StringName = _slot_genes[i] if i < _slot_genes.size() else &""
		# **A rung answers *do I express this gene at all*, and the row above
		# answers *where*.** `dna-strand.md` §1.2 defines worn against carried
		# as exactly that question, and it stays that question.
		#
		# It was briefly narrowed to *worn on this arc* -- `body.get(gene, 0)
		# if slot_of(gene) == i else 0` -- to close a lie the one-row strand
		# told: a gene the body wears at arc 1 drew a full rung at DNA locus 3
		# and looked like it was claiming arc 3. **The body row closes that lie
		# by existing**, because the rows are labelled and the upper one prints
		# the organ under the arc it is actually on. Narrowing the rung as well
		# put two different facts on one mark: a gene moved and a gene that
		# missed its expression roll drew the same floating bar, and rendered
		# at the same locus with the same hue they were **0 differing pixels**
		# apart -- the only evidence 232 px away on the other row. Worse, it
		# contradicted the line under the strand in an ordinary frame: move
		# `cytostome` and locus 4 drew *the body does not have this* directly
		# above `the mouth · a daughter always wears it`.
		#
		# So: carried means the roll missed, worn means the body expresses it,
		# and both questions stay local to the mark that answers them.
		# `moving-a-gene.md` §2.4.
		var here := int(body.get(gene, 0))
		_genome_row.add_child(_make_locus(gene, int(dna.get(gene, 0)),
			here, i, CAP_LOBES + i * LOCUS_LOBES))
	_genome_row.add_child(_make_cap(CAP_LOBES + count * LOCUS_LOBES, -1,
		HELIX_MID, LOCUS_H))
	_genome_row.add_child(_make_spacer(LOCUS_H))

	# **The caption carries the generation now**, because the hint below the
	# strand took on what a locus is worth to a daughter. Zero pixels either
	# way: both lines already existed. It says `genome` rather than `dna`
	# because the group is now two registers and only one of them is the DNA --
	# that word moved down to the row it actually names, with `body` above it,
	# so both are on screen instead of one.
	_genome_caption.text = "genome · %s" % _generation_text()
	_update_hint()
	_update_explain()
	_restore_focus(keeping)


## Which slot the keyboard is on, or -1 for "not on the strand".
##
## Read off a meta rather than off the child's position in Row. The row carries
## a lead-in and a tail as well as the loci, so a child index is not a slot
## index and never was; a locus carrying its own slot number cannot be wrong
## about it, whatever else the row grows.
func _focused_slot() -> int:
	for child in _genome_row.get_children():
		var tile := child as Control
		if tile != null and tile.has_focus():
			return int(tile.get_meta(&"slot", SLOT_NONE))
	return SLOT_NONE


## Puts the keyboard back on [param slot] after a rebuild.
##
## **Which slot, rather than `resume`, and the distinction is the whole fix.**
## An arm that lapses does not lapse the sample -- ARM_TIMEOUT_MS is four
## seconds and SAMPLE_SECONDS is forty-five -- so the loci are still live and
## the player is still mid-decision, in front of the same locus they were
## reading. Sending them to `resume` would answer "can I still use the
## keyboard" with yes and "am I where I was" with no. A commit is the same case
## now that every locus stays selectable: the sample is spent, but the slot it
## landed in is still a locus to stand on and still the one being read, so the
## keyboard stays there too. The `resume` fallback below is what catches a slot
## that no longer exists.
func _restore_focus(slot: int) -> void:
	if slot == SLOT_NONE:
		return
	for child in _genome_row.get_children():
		var tile := child as Control
		if tile != null and tile.focus_mode == Control.FOCUS_ALL \
				and int(tile.get_meta(&"slot", SLOT_NONE)) == slot:
			tile.grab_focus()
			return
	_resume_button.grab_focus()


## **One line, two jobs, and they never overlap.** While a sample is held the
## line is the instruction, because a decision is waiting. The rest of the time
## -- which is most of a run -- it is what the selected locus is worth to a
## daughter, which is the one thing the strand draws (copies) and cannot say in
## words on its own.
func _update_hint() -> void:
	_update_act()
	var slot := _hovered if _hovered != SLOT_NONE else _armed
	if slot == SLOT_NONE:
		_genome_hint.text = ""
		return
	# **The same gene the explanation line is describing**, through the same
	# resolution, because the two rows are read together and a pair that
	# disagrees about its subject is worse than either alone. The shipped code
	# could not disagree -- both of its fallbacks were behind an early return
	# that fired whenever a sample was held -- and moving the instruction to
	# `Act` took that return away. Posed and it showed: a gene in the air over
	# an empty locus explained the travelling gene and priced the hole.
	var gene := _reading()
	if gene == &"":
		_genome_hint.text = HINT_EMPTY
		return
	if GenomeNode.ALWAYS_EXPRESSED.has(gene):
		_genome_hint.text = HINT_CERTAIN
		return
	# **`maxi(.., 1)` because a held sample is worth one copy, not none.** A
	# locus always carries at least one, so this never used to matter; a sample
	# has `dna_tier == 0`, which indexes the empty string, and the held-sample
	# branch returning first is the only reason nobody ever saw it. Now that the
	# instruction has moved to `Act` this line is reached while a sample is
	# selected -- so without the clamp the odds go blank at exactly the moment
	# the player is deciding what a placement is worth.
	_genome_hint.text = HINT_CHANCE[clampi(maxi(_genome.dna_tier(gene), 1), 0,
		HINT_CHANCE.size() - 1)]


## **The verb line**, kept in step with the hint because the two are read
## together and the state they read is the same. It is a separate row for the
## reason gene-lines-and-the-pause-target.md §3 made the explanation one: both
## are wanted at once, and the moment one would have to be chosen over the other
## is the moment the player is about to change their daughters.
func _update_act() -> void:
	# A gene in the air outranks a held sample: the sample is not going anywhere
	# while a move is in flight (see [method _draw_cap]), so the line reports
	# the gesture that is actually happening.
	if _dragging != SLOT_NONE:
		# **The one piece of feedback a thumb cannot cover.** The travelling
		# base pair rides above the finger and the lens fills under it; both are
		# within a fingertip of the pointer on a phone. This line is not.
		var flying := _gene_at(_dragging)
		if _hovered == _dragging:
			# Back over the locus it came out of: a drop here is refused by
			# [method _locus_can_drop] and the gene simply stays, which is the
			# gesture's own cancel and now says so.
			_genome_act.text = ACT_KEEP % _word(flying)
		elif _hovered >= 0:
			var displaced := _gene_at(_hovered)
			_genome_act.text = ACT_SWAP % [_word(flying), _word(displaced)] \
				if displaced != &"" else ACT_LAND % _word(flying)
		else:
			_genome_act.text = ACT_CARRY % _word(flying)
		return
	if _genome.held_sample != &"":
		# `_armed >= 0` and not `!= SLOT_NONE`: a sample waiting off the head of
		# the strand is selected and not placeable, so it must not promise a
		# second tap that does nothing.
		_genome_act.text = ACT_COMMIT if _armed >= 0 else ACT_ARM
		return
	var slot := _hovered if _hovered != SLOT_NONE else _armed
	_genome_act.text = ACT_MOVE if _movable(slot) else ""


## The plain word a gene is read by on this surface. A gene this build has no
## word for -- a later phase's, arriving over an older binary in a content pack
## -- falls back to its own name rather than to nothing.
func _word(gene: StringName) -> String:
	return String(WORDS.get(gene, String(gene)))


## True when [param slot] is a DNA locus with a gene in it, which is the only
## thing a move can pick up.
##
## **No guard, no timeout and no second tap**, deliberately: that machinery
## belongs to placement, which evicts a gene from the lineage for good. A move
## creates nothing and destroys nothing, it cannot undo a placement -- the
## evicted gene is not in the DNA for any rearrangement to find -- and it only
## reaches the player's daughters, so it is free, repeatable and
## self-cancelling.
func _movable(slot: int) -> bool:
	return slot >= 0 and _gene_at(slot) != &""


## **The answer line: what the selected gene does, in the player's terms.**
##
## Two labels rather than one, because the two halves are different kinds of
## thing and the hue is what says so: the biological name in the gene's own
## colour -- the colour of the tile border the player just tapped, and of the
## organ on their own body -- and then the sentence in the pale tint every other
## word on this column wears.
##
## Hover wins over selection, and only on desktop: a mouse can ask about a locus
## without committing to it, which is the cheapest possible way to read all
## eighteen. A thumb has no hover, so the tap path is the one that has to work,
## and it is the one that is tested.
##
## **An empty locus with a sample held explains the sample**, which is the one
## rule that changed when the sample stopped being a tile of its own. There is
## nothing in that locus to describe and the gene about to land in it is the
## decision; an *occupied* locus still describes its own gene, because that is
## what a second tap would overwrite and the player should read it first.
func _update_explain() -> void:
	var slot := _hovered if _hovered != SLOT_NONE else _armed
	var gene := _reading()
	_explain_gene = gene
	_explain_tier = maxi(_genome.dna_tier(gene), 1) if gene != &"" else 0
	if _explain_organ != null:
		_explain_organ.queue_redraw()
	if gene == &"":
		_explain_name.text = ""
		# Two different silences: no locus chosen says nothing at all; a chosen
		# empty locus still has a direction to explain.
		_explain_says.text = "" if slot == SLOT_NONE else EXPLAIN_EMPTY
		return
	_explain_name.text = String(gene)
	_explain_name.add_theme_color_override("font_color",
		Color(Cilia.hue(gene), EXPLAIN_NAME_ALPHA))
	# A gene this build has no line for -- a later phase's, arriving over an
	# older binary in a content pack -- shows its name and says nothing, rather
	# than showing a bare separator.
	var says := String(EXPLAINS.get(gene, ""))
	_explain_says.text = "" if says.is_empty() else "· " + says


## **What the three lines under the strand are about**, resolved once.
##
## The locus being read -- hovered first, because a mouse can ask about a locus
## without committing to it -- and then two fallbacks for the two ways a locus
## can be empty while something is still in hand. An **occupied** locus always
## describes its own gene: with a sample held that is what a second tap would
## overwrite, and under a gene in the air that is what a drop would displace,
## and either way it should be read before it goes.
func _reading() -> StringName:
	var slot := _hovered if _hovered != SLOT_NONE else _armed
	var gene := _gene_at(slot)
	if gene == &"" and _dragging != SLOT_NONE:
		gene = _gene_at(_dragging)
	if gene == &"":
		gene = _genome.held_sample
	return gene


## The gene a locus stands for: the held sample, the gene in that slot, or &"".
func _gene_at(slot: int) -> StringName:
	if slot == SLOT_SAMPLE:
		return _genome.held_sample
	if slot >= 0 and slot < _slot_genes.size():
		return _slot_genes[slot]
	return &""


## True when a second tap on [param slot] would place the held sample into it --
## which is the only case that is irreversible, and therefore the only case that
## needs the guard, the timeout and the confirming second tap.
func _committable(slot: int) -> bool:
	return slot >= 0 and _genome.held_sample != &""


## What is selected when the pause screen opens, and after an arm lapses.
##
## **Never nothing.** A strand that opens with no line under it would have to
## teach the tap with a line of instructions; one that opens with a locus lit
## and its sentence underneath has already shown what tapping a locus does, and
## the player's next tap is on a different one. The held sample first,
## because that is the decision they came here to make; otherwise the first gene
## they actually carry, which on a born cell is the mouth.
func _select_default() -> void:
	_hovered = SLOT_NONE
	_armed_at = Time.get_ticks_msec()
	if _genome.held_sample != &"":
		_armed = SLOT_SAMPLE
		return
	_armed = SLOT_NONE
	var layout := _genome.layout()
	for i in layout.size():
		if layout[i] != &"":
			_armed = i
			return


func _generation_text() -> String:
	if _generation >= 1 and _generation <= ORDINALS.size():
		return "%s generation" % ORDINALS[_generation - 1]
	return "generation %d" % _generation


## One locus: its slice of the weave, its copies, its word and its dart, and --
## when the sample is bound for it -- the loose base pair floating above.
##
## [param tier] is the DNA's copy count and [param body_tier] is how many of
## those copies this body expressed. The rungs draw both, which is what makes
## the strand the two registers rather than one.
##
## [param lobe0] is the locus's first half-lens in the strand's own phase, so
## neighbours join with no seam and the locus's centre is always a maximum.
func _make_locus(gene: StringName, tier: int, body_tier: int, slot: int,
		lobe0: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(LOCUS_W, LOCUS_H)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Its own slot number, so a rebuild can find the node that replaced it
	# without re-deriving an offset that may have changed underneath.
	node.set_meta(&"slot", slot)

	# **Every locus is live, sample or no sample.** Selecting is what the
	# explanation line and the odds line hang off; *committing* is still gated
	# on a sample being held ([method _committable]), so nothing became easier
	# to do by accident: the one irreversible action in the game needs the same
	# two taps, the same 300 ms guard and the same held sample it always did.
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.focus_mode = Control.FOCUS_ALL

	node.draw.connect(_draw_locus.bind(node, gene, tier, body_tier, slot, lobe0))
	node.gui_input.connect(_on_locus_input.bind(node, slot))
	node.focus_entered.connect(node.queue_redraw)
	node.focus_exited.connect(node.queue_redraw)
	# Hover only moves the two lines below the strand; it deliberately does not
	# light the locus and deliberately does not rebuild. A strand rebuilt on
	# every mouse crossing would be ten nodes a frame to say nothing, and a
	# locus that lit under the cursor would promise a tap it has not been given.
	node.mouse_entered.connect(_on_locus_hover.bind(slot))
	node.mouse_exited.connect(_on_locus_unhover.bind(slot))
	# **The move is Godot's own drag, not a hand-rolled one, and the reason is
	# choosing.md §4.2.** The engine records which control owns a pointer only
	# when the *press* landed on a control, and re-hit-tests every drag
	# otherwise; the built-in path is the one written around that. It also gets
	# touch for free -- `emulate_mouse_from_touch` turns an
	# `InputEventScreenDrag` into a motion, so the same machinery runs on a
	# phone -- and it clears `gui.mouse_focus` when a drag begins, which is why
	# `mouse_entered` keeps firing and the drop target is knowable at all.
	node.set_drag_forwarding(_locus_drag.bind(node, slot),
		_locus_can_drop.bind(slot), _locus_drop.bind(slot))
	return node


## The lead-in and the tail: the chromosome arriving and leaving. [param taper]
## is +1 at the head and -1 at the tail; both ramp amplitude and alpha so the
## strand does not begin mid-lens. Neither takes input -- there is nothing at
## either end to choose.
##
## [param mid] and [param height] are the row's, because both rows have caps and
## they sit at different seats in controls of different heights.
func _make_cap(lobe0: int, taper: int, mid: float, height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(CAP_W, height)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.draw.connect(_draw_cap.bind(node, lobe0, taper, mid))
	return node


## The row's own name, in the gutter left of its lead-in. Two words name the two
## registers where a second caption would cost a whole row of the column.
func _make_gutter(text: String, height: float) -> Control:
	var node := Label.new()
	node.custom_minimum_size = Vector2(GUTTER_W, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", GUTTER_SIZE)
	node.add_theme_color_override("font_color", GUTTER_TINT)
	return node


## The gutter mirrored on the right, invisible, so the strand stays centred on
## the column the `Explain` line below it is centred on. Without it the weave
## sits 7 px left of everything else, which is small and is visible.
func _make_spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(GUTTER_W, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## One locus of the **body** row: what this cell is wearing, on the arc it is
## wearing it on.
##
## **Every rung is worn, by definition** -- a body has no carried copies, since
## `Genome.expressed()` writes the DNA's whole copy count or none of it. And
## nothing here takes input or takes focus: the body is fixed, so a row that
## responded would promise an edit of a thing that cannot be edited, and it adds
## no Tab stops to the six to eight this screen already costs.
##
## [param dissents] is whether the two rows disagree at this locus, which is the
## only case that draws a word. See [method _draw_body_locus].
func _make_body_locus(gene: StringName, tier: int, slot: int, lobe0: int,
		dissents: bool) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(LOCUS_W, BODY_LOCUS_H)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	node.draw.connect(_draw_body_locus.bind(node, gene, tier, slot, lobe0,
		dissents))
	return node


## **A word on the body row only where the two rows disagree**, and it was
## measured both ways. A word under every body locus is the same seven verbs
## printed twice -- rendered, and it is a wall of text in which the one line
## that is news disappears. Where the rows agree the DNA row's word sits in the
## same column and names both. Where they disagree the body has something on
## screen that nothing else says, so it says it -- and the dart comes with the
## word, which is the first time this game has drawn *where an organ actually
## is*. The row reserves its full height either way, so nothing moves when a
## disagreement appears.
func _draw_body_locus(node: Control, gene: StringName, tier: int, slot: int,
		lobe0: int, dissents: bool) -> void:
	Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, LOBE_W, BODY_HELIX_MID,
		HELIX_AMP, LOCUS_LOBES, lobe0, 1.0, 0)
	if gene != &"":
		Cilia.draw_rungs(node, Cilia.STRAND_ALONG_X, LOBE_W, BODY_HELIX_MID,
			HELIX_AMP, lobe0, LOCUS_W * 0.5, Cilia.hue(gene), tier, tier)
	# **The dart comes with the word and never on its own.** A locus the body
	# leaves empty while the DNA fills it disagrees, but it has nothing to name,
	# and a bare arrow over a bare weave is a mark with nothing to anchor to.
	# `maxi(tier, 1)` is the word's tint rather than its count: a gene on the
	# body row is worn by definition, so its word is never the dim one.
	if dissents and gene != &"":
		_draw_locus_label(node, gene, maxi(tier, 1), slot, false,
			BODY_LABEL_MID, BODY_LABEL_BASE)


func _on_locus_hover(index: int) -> void:
	_hovered = index
	_update_explain()
	_update_hint()
	# Hover deliberately does not light a locus -- except while a gene is in the
	# air, when the locus under the pointer is where it would land and has to
	# say so. Godot clears the pointer's captured control the moment a drag
	# begins, which is exactly why hover keeps tracking through one.
	if _dragging != SLOT_NONE:
		_redraw_strand()


func _on_locus_unhover(index: int) -> void:
	if _hovered != index:
		return
	_hovered = SLOT_NONE
	_update_explain()
	_update_hint()
	if _dragging != SLOT_NONE:
		_redraw_strand()


func _draw_cap(node: Control, lobe0: int, taper: int, mid: float) -> void:
	Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, LOBE_W, mid,
		HELIX_AMP, CAP_LOBES, lobe0, 1.0, taper)
	# The body row has no sample band; only the DNA row's head can hold one.
	if mid != HELIX_MID:
		return
	# A sample that has not been given a locus yet waits off the head, on
	# nothing. That is the truthful picture and it is also the one that makes
	# the first tap obvious: it is not anywhere until you say where.
	#
	# **A sample waits off the lead-in whenever no locus is bound for it, and a
	# gene in the air unbinds it.** That is the rule this surface already had,
	# extended by one clause, and it is what stops a move and a placement from
	# claiming the same locus: while a move is in flight the selection is the
	# move's own source, which is not where the sample is going. Posed on
	# purpose and it collided -- two base pairs and two words at one locus, and
	# a line naming the wrong gesture. The sample goes back to hanging on
	# nothing, which is what it is, and rebinds on release.
	if taper > 0 and _genome.held_sample != &"" \
			and (_armed == SLOT_SAMPLE or _dragging != SLOT_NONE):
		_draw_sample(node, _genome.held_sample, CAP_W * 0.5, -1.0)


func _draw_locus(node: Control, gene: StringName, tier: int, body_tier: int,
		slot: int, lobe0: int) -> void:
	var selected := _armed == slot
	var held := _genome.held_sample
	var tone := Cilia.hue(gene) if gene != &"" else PALE
	# An empty locus with the sample bound for it wears the hue of what is
	# coming, so the second tap confirms something the strand is already
	# showing. An *occupied* one keeps its own: that hue is what a second tap
	# would erase, and it should be the last thing the player sees before it
	# goes.
	if gene == &"" and selected and held != &"":
		tone = Cilia.hue(held)

	# **Both ends of a swap show what would arrive at them, and nothing moves
	# until the finger lifts.** The lens is the only mark that changes and it is
	# the mark selection already uses, so the destination keeps drawing its own
	# copies: what is about to be displaced stays readable right up to the drop.
	if _dragging != SLOT_NONE:
		if slot >= 0 and slot == _hovered and slot != _dragging:
			var flying := _gene_at(_dragging)
			if flying != &"":
				selected = true
				tone = Cilia.hue(flying)
		elif slot == _dragging and _hovered >= 0 and _hovered != slot:
			# The hole the gene came out of, filled with the hue of whatever is
			# coming back into it -- the displaced gene, or the column's own
			# pale if the destination is empty.
			var displaced := _gene_at(_hovered)
			tone = Cilia.hue(displaced) if displaced != &"" else PALE

	# **The lens fills, and that is the whole of "selected".** There is no box
	# to put a border on any more; area between the backbones is the one mark on
	# this surface that cannot be mistaken for a rung or for a strand.
	if selected:
		# 1.0: a locus is three lobes wide and the lens is its middle one.
		Cilia.draw_lens(node, Cilia.STRAND_ALONG_X, LOBE_W, HELIX_MID,
			HELIX_AMP, lobe0, 1.0, Color(tone, LENS_SELECTED))
	Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, LOBE_W, HELIX_MID, HELIX_AMP,
		LOCUS_LOBES, lobe0, BACKBONE_LIT if selected else 1.0, 0)

	# The gene is in the air: the locus it came out of has nothing in it until
	# it lands, and drawing its rungs in both places would be the one lie a
	# drag can tell.
	if _dragging == slot:
		gene = &""
	if gene != &"":
		Cilia.draw_rungs(node, Cilia.STRAND_ALONG_X, LOBE_W, HELIX_MID,
			HELIX_AMP, lobe0, LOCUS_W * 0.5, Cilia.hue(gene), tier, body_tier)
	elif selected and held != &"" and _dragging == SLOT_NONE:
		# What a second tap would do, drawn before it is done: a placed gene is
		# written to the DNA and **not** to this body, so the preview is a
		# carried rung and not a worn one. That is not a nicety -- it is the one
		# frame where the player can see that placing changes their daughters
		# and not themselves.
		Cilia.draw_rungs(node, Cilia.STRAND_ALONG_X, LOBE_W, HELIX_MID,
			HELIX_AMP, lobe0, LOCUS_W * 0.5, Cilia.hue(held), 1, 0)

	if selected and held != &"" and slot >= 0 and _dragging == SLOT_NONE:
		_draw_sample(node, held, LOCUS_W * 0.5, HELIX_MID - HELIX_AMP)

	_draw_locus_label(node, gene, body_tier, slot, selected)

	if node.has_focus():
		node.draw_line(Vector2(FOCUS_INSET, LOCUS_H - 1.0),
			Vector2(LOCUS_W - FOCUS_INSET, LOCUS_H - 1.0),
			FOCUS_TINT, FOCUS_WIDTH, true)


## The plain word and the dart, centred under the locus as one group so a long
## word and a short one both sit under their own stretch of strand.
##
## **The word is the strip's word, unchanged**: four short verbs parsed at arm's
## length, never the biological name. That belongs to the explanation line,
## which is read rather than glanced at.
##
## [param label_mid] and [param label_base] default to the DNA row's seats,
## under its helix; the body row passes its own, which are above.
func _draw_locus_label(node: Control, gene: StringName, body_tier: int,
		slot: int, selected: bool, label_mid := LABEL_MID,
		label_base := LABEL_BASE) -> void:
	var font := node.get_theme_default_font()
	var word := String(WORDS.get(gene, String(gene))) if gene != &"" else ""
	var width := 0.0
	if font != null and not word.is_empty():
		width = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			LABEL_SIZE).x
	var group := DART_R * 2.0
	if width > 0.0:
		group += DART_GAP + width
	var dart_x := LOCUS_W * 0.5 - group * 0.5 + DART_R
	Cilia.draw_slot_dart(node, slot,
		Cilia.hue(gene) if gene != &"" else Color(PALE, 0.6),
		Vector2(dart_x, label_mid), DART_R)
	if width <= 0.0 or font == null:
		return
	var tint := LABEL_TINT
	if selected:
		tint = LABEL_TINT_LOUD
	elif body_tier <= 0:
		# The third channel, agreeing with the floating rungs: a word for an
		# organ this body does not wear is quieter than one it does.
		tint = Color(PALE, WORD_UNEXPRESSED)
	node.draw_string(font, Vector2(dart_x + DART_R + DART_GAP, label_base),
		word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, tint)


## **The held sample: a base pair that is not in a ladder yet.** A bar with a
## base at each end, floating in the band above the locus it is bound for, with
## a thread down to where its rung would go. Off the head of the strand -- with
## [param thread_to] negative -- it hangs on nothing at all, which is the
## picture of a gene that has not been given a place.
##
## It keeps the plain word beside it, because the word is what the strand is
## built to be read by and a sample with no word is a coloured dot.
func _draw_sample(node: Control, gene: StringName, centre_x: float,
		thread_to: float) -> void:
	var tone := Cilia.hue(gene)
	var font := node.get_theme_default_font()
	var word := String(WORDS.get(gene, String(gene)))
	var width := 0.0
	if font != null:
		width = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			SAMPLE_WORD).x
	var group := SAMPLE_WIDTH + SAMPLE_GAP + width
	var bar_x := centre_x - group * 0.5 + SAMPLE_WIDTH * 0.5
	var top := Vector2(bar_x, BAND_MID - SAMPLE_BAR * 0.5)
	var bottom := Vector2(bar_x, BAND_MID + SAMPLE_BAR * 0.5)

	for i in SAMPLE_HALO.size():
		node.draw_arc(Vector2(bar_x, BAND_MID), SAMPLE_HALO[i], 0.0, TAU, 24,
			Color(tone, SAMPLE_HALO_ALPHA[i]), 1.4, true)
	if thread_to >= 0.0:
		# One bowed strand from the base pair to the locus it is reaching for.
		var thread := PackedVector2Array()
		for i in 7:
			var u := float(i) / 6.0
			thread.append(Vector2(
				lerpf(bar_x, centre_x, u) + sin(u * PI) * 5.0,
				lerpf(bottom.y, thread_to, u)))
		node.draw_polyline(thread, Color(tone, SAMPLE_THREAD_ALPHA), 1.4, true)
	node.draw_line(top, bottom, Color(tone, 0.94), SAMPLE_WIDTH, true)
	node.draw_circle(top, SAMPLE_CAP, Color(tone, 0.94), true, -1.0, true)
	node.draw_circle(bottom, SAMPLE_CAP, Color(tone, 0.94), true, -1.0, true)
	if font != null:
		node.draw_string(font,
			Vector2(bar_x + SAMPLE_WIDTH * 0.5 + SAMPLE_GAP,
				BAND_MID + SAMPLE_WORD * 0.38),
			word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SAMPLE_WORD,
			LABEL_TINT_LOUD)


## **The one organ on the pause screen, beside the sentence that explains it.**
##
## The old tiles drew an organ each, which is what taught a point-of-view
## player the cilia vocabulary (genes-and-cilia.md §2.4). A strand has nowhere
## to put seven of them, and seven small tufts over a chromosome would be the
## four-tuft mistake diegetic-hud.md §2 already made and measured. One, at the
## thing the player is reading, in the row that already exists, keeps the
## vocabulary and spends 30 px.
func _draw_explain_organ() -> void:
	if _explain_gene == &"" or _explain_organ == null:
		return
	var worn := _genome.tier(_explain_gene) > 0 \
		or _explain_gene == _genome.held_sample
	Cilia.draw_tile_organ(_explain_organ, _explain_gene, _explain_tier,
		EXPLAIN_ORGAN_SEAT,
		Cilia.TILE_STROKE_ALPHA if worn else ORGAN_UNEXPRESSED,
		EXPLAIN_ORGAN_SCALE)


# --- Two taps on the same target -------------------------------------------
# The only pattern that is safe on touch and navigable by keyboard. A mis-tap
# costs nothing because arming is reversible, and that is the argument that
# makes 20px between tiles acceptable even though it is about 1.5mm on a phone.
# The destructive control here is not adjacent to `resume`.

## **[param tile] is dead after [method _build_genome_strip] runs.** A rebuild
## removes and frees every tile -- including the one whose `gui_input` we are
## standing inside. That is legal (`queue_free` is deferred and `remove_child`
## during emission is fine) and it is exercised on both the touch path and the
## keyboard path, but it means nothing may touch `tile` after the rebuild. Read
## the new node out of Row instead, the way the focus line does.
##
## Two of the branches below rebuild -- a move and a commit -- and **selecting
## does not**, because a press that selects may still become a drag and Godot
## hangs the drag off the control that took the press. Everything `tile` is
## used for happens before either rebuild: `accept_event()`, and the rect the
## up-stroke is tested against.
func _on_locus_input(event: InputEvent, tile: Control, index: int) -> void:
	var step := _move_key(event)
	if step != 0:
		# `accept_event()` on the chord, or GUI focus navigation runs as well
		# and the keyboard walks off the locus the gene just moved to.
		tile.accept_event()
		_move_slot(index, index + step)
		return
	# **The up-stroke, which is where a placement lands now.** See [member
	# _primed] for why it cannot land on the down-stroke any more.
	if _is_pointer_lift(event):
		tile.accept_event()
		var was_primed := _primed == index
		_primed = SLOT_NONE
		# `has_point` and not simply "this locus got the release": Godot keeps
		# delivering to the control the press landed on, so a finger that
		# pressed an armed locus, slid four loci away and lifted there gets its
		# release *here*, with a local x of -336. That is a gesture the player
		# aborted, and aborting by sliding off is the oldest cancel there is.
		if was_primed and _dragging == SLOT_NONE \
				and Rect2(Vector2.ZERO, tile.size).has_point(
					_pointer_at(event)):
			_commit_slot(index)
		return
	if not _is_widget_tap(event):
		return
	tile.accept_event()
	# Any fresh down-stroke replaces whatever the last one was waiting to do.
	_primed = SLOT_NONE
	if _armed == index:
		if _committable(index):
			# **The guard is not politeness, it is the touch path working.**
			# Godot emulates a mouse click from every screen touch, so one thumb
			# press arrives here twice; without this the second copy would
			# arm and prime in the same frame, and the one irreversible action
			# in the game would need no confirmation at all.
			if Time.get_ticks_msec() - _armed_at < ARM_GUARD_MS:
				return
			if _is_pointer_press(event):
				# Primed, not placed: a finger that goes down here may still be
				# starting a move, and nothing may be written until it has said
				# which.
				_primed = index
				return
			# **A key is not ambiguous.** `ui_accept` is Enter, KP-Enter and
			# Space; no drag can grow out of any of them, so the keyboard's
			# confirm stays on the press where it always was. [method
			# _commit_slot] carries the guard for the one way a key can still
			# arrive mid-gesture: a mouse drag in flight while the other hand
			# presses Enter.
			_commit_slot(index)
			return
		# Nothing to commit -- no sample, or this is the sample itself -- so the
		# second tap is simply the first one again and the tile stays selected.
		#
		# **It used to deselect, and the render is what killed that.** Godot
		# focuses a control on click, so the tile a thumb has just tapped keeps
		# a focus ring whether or not it is selected: deselecting left a tile
		# ringed in pale teal with an empty sentence under it, which is the
		# surface pointing at something and then refusing to say what. Blanking
		# the one line the player came for is a worse answer than doing nothing.
		return
	_armed = index
	_armed_at = Time.get_ticks_msec()
	# **A selection redraws; it does not rebuild.** Freeing and remaking ten
	# nodes to move one lens was always waste, and once a press can become a
	# drag it is a bug rather than waste: Godot hangs a drag off the control
	# that took the *press*, and this handler used to free that control before
	# the finger had moved -- so the drag could never start and the gesture
	# looked unimplemented. Nothing about the genome changed here, so nothing
	# has to be rebuilt; the loci read [member _armed] at draw time. It also
	# removes the focus churn [method _restore_focus] exists to repair.
	_redraw_strand()
	_update_explain()
	_update_hint()


## Every control on both rows, redrawn. The loci read the selection and the
## drag out of [member _armed] and [member _dragging] at draw time, so this is
## all either of them ever needs.
func _redraw_strand() -> void:
	for row: HBoxContainer in [_body_row, _genome_row]:
		for child in row.get_children():
			var node := child as CanvasItem
			if node != null:
				node.queue_redraw()


# --- The move: a drag, because nothing is destroyed by one ------------------
# A placement evicts a gene from the lineage and cannot be undone, so it is two
# taps with a 300 ms guard. A move rearranges what is already there, destroys
# nothing and only ever reaches the player's daughters, so it is a drag:
# self-cancelling, repeatable, and over the moment the finger lifts. The two
# consequences get two gestures, which is the cheapest possible way to say that
# one of them is heavier than the other.
#
# Tap-then-tap was not available: a tap already selects a locus and reads it,
# and a second tap already places a held sample. Redefining the pair as a move
# would cost the ability to read a second gene, which is most of what the strand
# is for.

## The gene leaves its locus. Returning `null` refuses the drag, which is what
## an empty locus does.
func _locus_drag(_at: Vector2, node: Control, slot: int) -> Variant:
	if not _movable(slot):
		return null
	var gene := _gene_at(slot)
	# **The drag is what proves the press was not a tap**, so whatever that
	# press primed is cancelled here. This is the line that makes a placement
	# unreachable from a gesture the player made as a move; see [member
	# _primed].
	_primed = SLOT_NONE
	_dragging = slot
	_armed = slot
	_armed_at = Time.get_ticks_msec()
	# The travelling gene is the held sample's own base pair, because that is
	# already this surface's picture of a gene that is not in a ladder: a bar,
	# two halo rings and the plain word. Nothing new to learn.
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = Vector2(LOCUS_W, BAND_MID * 2.0)
	preview.size = Vector2(LOCUS_W, BAND_MID * 2.0)
	preview.position = Vector2(-LOCUS_W * 0.5, -BAND_MID - DRAG_LIFT)
	preview.draw.connect(_draw_sample.bind(preview, gene, LOCUS_W * 0.5, -1.0))
	# Godot seats a drag preview's *root* on the pointer, so the offset has to
	# live on a child of it; a wrapper is the one way to lift the picture off
	# the thumb.
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(preview)
	node.set_drag_preview(wrap)
	_redraw_strand()
	_update_explain()
	_update_hint()
	return {&"move_from": slot, &"gene": gene}


## Every DNA locus but the one the gene came out of. **Not refused on an
## occupied one**: a late-game strand is dense, so refusing would fail most
## drops and a gesture that usually does nothing reads as broken. An occupied
## destination swaps, which is the same operation `Genome._mutate_shift`
## already performs at every division -- and an empty one is the degenerate
## case of that same swap, so there is one rule and not two.
func _locus_can_drop(_at: Vector2, data: Variant, slot: int) -> bool:
	if not (data is Dictionary) or not (data as Dictionary).has(&"move_from"):
		return false
	return slot >= 0 and slot < _slot_genes.size() \
		and slot != int((data as Dictionary)[&"move_from"])


func _locus_drop(_at: Vector2, data: Variant, slot: int) -> void:
	_dragging = SLOT_NONE
	# The moved gene stays selected and the keyboard follows it, so the three
	# lines under the strand are a receipt for what moved and where it now
	# points. That is the rule a commit already has.
	_move_slot(int((data as Dictionary)[&"move_from"]), slot)


## **`Shift` and an arrow, read raw.** A content pack cannot add an `InputMap`
## action, and the bare arrows are how the GUI is navigated -- so the chord is
## read off the key event itself rather than through an action. Returns -1, +1
## or 0 for anything else.
func _move_key(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or not key.shift_pressed:
		return 0
	if key.keycode == KEY_LEFT:
		return -1
	return 1 if key.keycode == KEY_RIGHT else 0


## One move, from either gesture.
##
## [param to] is **clamped rather than wrapped**: a gene that walked off the end
## of the strand and reappeared at the other end would land on a different arc
## from the one being aimed at, which is the whole thing a move is for.
func _move_slot(from: int, to: int) -> void:
	var target := clampi(to, 0, maxi(_slot_genes.size() - 1, 0))
	if not _genome.move(from, target):
		return
	_armed = target
	_armed_at = Time.get_ticks_msec()
	_hovered = SLOT_NONE
	# The genome really did change, so this one is a rebuild: both rows read
	# their genes and their copy counts at build time, and the move changed
	# both rows at once.
	_build_genome_strip()
	# The strip's own focus restore only fires for a locus that *had* focus, and
	# a mouse drag never gave one to anything. Sending the keyboard after the
	# gene it just moved is what makes `Shift`+arrow repeatable.
	_restore_focus(target)


func _is_widget_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return event.is_action_pressed(&"ui_accept")


## The down-stroke of a **pointer** specifically, which is the half of
## [method _is_widget_tap] that can turn into a drag. Both copies of a thumb
## press answer true: Godot emulates a mouse button from every screen touch and
## the locus is handed both.
func _is_pointer_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return false


## The matching up-stroke. **Measured, not assumed**: with no drag in flight
## Godot delivers the release to the control the press landed on -- as both an
## emulated mouse button and a screen touch, in that order, one millisecond
## apart -- and when a drag *is* in flight it delivers no release here at all,
## because the release is the drop. That is exactly the discrimination
## [member _primed] needs, and it is free.
func _is_pointer_lift(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		return not click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return false


## Where a pointer event landed, in the locus's own coordinates. Off the end of
## the strand is a legal answer and the reason this is asked at all.
func _pointer_at(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	return Vector2(-1.0, -1.0)


## The one irreversible action in the game (§9.7). A genome you cannot ruin is
## not a choice, and §1.3's drifter floor is what makes even the worst swap --
## dropping a fourth gene over your own mouth -- survivable rather than a soft
## lock.
## **Gated on the strip, not on the ladder.** `_genome.slots()` is the capacity
## the *body* earned, and a newborn carries her mother's whole DNA on a body two
## thirds the size -- so gating on it would silently deaden four of seven live
## tiles for the commonest state in the late game. The strip is the DNA and the
## DNA is what is being placed into.
func _commit_slot(index: int) -> void:
	# **Nothing is written while a gesture is in flight**, which is the guard
	# [method _step_arming] already carries three functions down and this one
	# was missing. The reachable case is desktop and it is one hand on each
	# device: a mouse drag lifting `eat` out of locus 0 while the other hand
	# presses Enter -- `ui_accept` is Enter, KP-Enter *and* Space -- on a
	# focused locus with a sample held. Without this the sample lands, the
	# strip rebuilds mid-drag, [member _dragging] still points at a locus that
	# now holds a different gene, and the release moves the gene that was just
	# placed rather than the one the drag picked up.
	if _dragging != SLOT_NONE:
		return
	if index < 0 or index >= _slot_genes.size():
		return
	_genome.place(index)
	# **The placed slot stays selected**, so the line under the strip is now the
	# gene that just landed and the tile it landed in. The sample is spent, so
	# nothing about that selection is committable any more -- it is a receipt,
	# and the one moment in a run where the player most wants to know what they
	# have just given their daughters.
	_armed = index
	_armed_at = Time.get_ticks_msec()
	_hovered = SLOT_NONE
	# The bus is told now rather than on the next unpaused frame: the membrane
	# keeps beating under the scrim, and an echo for a sample that no longer
	# exists is the game lying about the player's own body.
	_bus.hold(0.0)
	_build_genome_strip()


## The armed slot lapses on its own, so a strip left armed is not a trap.
##
## **This does not lapse the sample.** Four seconds is a hesitation; the sample
## has forty-five, and its clock is not even running -- `Genome` is
## `process_mode = 1`, so it stops with the rest of the simulation while the
## pause screen is open. So the player is still holding a gene, the tiles are
## still live, and the rebuild puts them back on the tile they were reading.
## **Only a committable selection lapses**, which is the one rule that had to
## change when selecting became something you do to read rather than only to
## place. The timeout exists to make sure a strip left armed is not a trap; a
## selection with no sample behind it is not a trap, it is a player reading a
## sentence, and four seconds is not long enough to read one twice. So a tile
## selected with nothing held stays selected until another tile is, and an arm
## that does lapse falls back to the sample rather than to nothing.
func _step_arming() -> void:
	# **Nothing lapses while a gesture is in flight.** A lapse rebuilds the
	# strand, which frees the locus the drag came out of and the one under the
	# pointer -- and four seconds is an easy hold for a thumb that is choosing
	# between seven destinations.
	if _dragging != SLOT_NONE:
		return
	# **A finger already down counts as a gesture in flight**, and this one was
	# found by posing the move at 2400x1080, where the renderer is slow enough
	# that the wall clock outran the harness's own clock. A press lands on an
	# armed locus, the four seconds run out before the finger has moved the ten
	# pixels Godot needs to call `_get_drag_data`, the lapse rebuilds the strand
	# and frees the control the press landed on -- and the drag can never start.
	# The player's finger is on the strand and the gesture silently does
	# nothing, which is the same failure the select-redraws change fixed at the
	# other end. The window is narrow (the press has to land in the last frames
	# of the timeout) and the cure is one line: a strip with a finger on it is
	# not a strip left armed, which is the only thing the timeout is for.
	if _primed != SLOT_NONE:
		return
	if not _committable(_armed):
		return
	if Time.get_ticks_msec() - _armed_at < ARM_TIMEOUT_MS:
		return
	_select_default()
	_build_genome_strip()


# ---------------------------------------------------------------------------
# Choosing a daughter (docs/design/choosing.md)
#
# **Two vertical strands, one outboard of each daughter, drawn by the same code
# as the pause screen's horizontal one.** The owner's ask was that the choice be
# readable: the two bodies already draw what each daughter *wears*, and the one
# thing they cannot draw is what she *carries* -- a gene that lost its
# expression roll is still in her DNA and rolls again in her own daughters. A
# port daughter wearing three organs against a starboard one wearing six reads
# as a broken cell, and she is not; she carries the same seven genes.
#
# So the answer is the DNA and not a second picture of the body, and the
# vocabulary is `dna-strand.md`'s, unchanged: hue is the gene, a rung is a copy,
# a full rung is worn and a floating bar is carried, the dart is the arc, the
# word is the plain verb, the lens fills on the locus being read. **The player
# learns all of that on the pause screen and spends it here.** The only new mark
# is the caret (§6), and it exists because the expression roll would otherwise
# be indistinguishable from the mutation.
#
# Three things about the geometry are worth stating rather than deriving:
#
# - **Seven loci, always.** A division fires only at `DIVIDE_RADIUS` 40, where
#   `slots_for(40)` is 7, and `Genome.mutated()` never changes the order's
#   length. So the column is a fixed 432 px at every division of every
#   generation and nothing ever reflows. Empty loci are drawn -- weave and pale
#   dart, no rungs, no word -- because locus *i* has to sit at the same canvas y
#   on both sides or the comparison stops being a horizontal scan, and that scan
#   is the whole mechanism.
# - **One lobe per locus, at 48 px.** The pause strand is 800 canvas px wide and
#   the space beside a daughter is 335; it does not fit at either shape, so the
#   pitch shrinks and the lobe count with it. A locus must begin and end at a
#   crossing with its centre at maximum separation, which needs an odd count --
#   and one is odd. At 48 : 36 the lens is 1.33:1, between the 2.67:1 that
#   `dna-strand.md` §1.1 rejected as two crossing waves and the 0.89:1 that
#   reads as DNA. Three lobes here would be 16 px against 36, which is the braid
#   the same section rejected from the other side.
# - **The two blocks are identical, not mirrored.** Mirrored, the two strands
#   would be different drawings and a player comparing them has to un-mirror
#   one. Identical, every corresponding mark is the same distance from its
#   opposite number at every locus, which is what makes one disagreement pop out
#   of six agreements.
#
# The one number that is not `dna-strand.md`'s and not measured off a body is
# `CHOOSE_BLOCK_W`, and it was 118 until a five-letter word at `LABEL_SIZE` 13
# was measured bleeding one pixel of antialiasing past the block's edge. The six
# extra pixels go on the **outboard** side, so the inboard edge -- the one with
# a daughter next to it -- does not move.
# ---------------------------------------------------------------------------

## §3.1 -- an invariant, not a maximum. See the note above.
const CHOOSE_LOCI := 7
## One locus, along the strand, and therefore one lobe of the weave.
const CHOOSE_PITCH := 48.0
## The lead-in and the tail, in lobes: the chromosome arrives and leaves rather
## than starting mid-lens. One each, against the pause strand's two, because
## there is no held sample to park off the head of this one.
const CHOOSE_CAP_LOBES := 1
## **124 and not 118.** Rendered at 118, `armor` -- five letters at
## `LABEL_SIZE` -- ran one pixel past the block's own edge, which collides with
## nothing today and would overflow silently. The six pixels are added
## outboard, so the gap to the daughter is unchanged and the block's outboard
## edge lands at canvas x 284 -- still 180 px clear of the membrane's nominal
## 104 px band at 1280x720. What it buys is measured beside
## [constant CHOOSE_WORD_X], and it is 3 px, not six letters: the font is
## proportional, so letter count is not the test.
##
## **This may not be widened on its own.** `CHOOSE_SEAT + CHOOSE_BLOCK_W` must
## stay at or under half the canvas width, or a block crosses the midline and
## every gesture on this screen reads the wrong side. The invariant, and what
## exactly breaks, is beside [constant CHOOSE_SEAT].
const CHOOSE_BLOCK_W := 124.0
## The column's top edge. Its ink starts 6 px lower -- the cap tapers in -- so
## the strand clears the membrane's nominal 104 px band, which in any case is
## not lit during a division: `_hush()` has zeroed every lobe.
const CHOOSE_COLUMN_TOP := 112.0
## Canvas px from the screen's centre to the block's **inboard** edge. A
## daughter reaches about 201 px from centre in point of view and 202 in full
## vision -- the seat and the body scale cancel -- so one placement serves both
## views, and this is 31 px outboard of that.
##
## **The midline invariant, which binds this to [constant CHOOSE_BLOCK_W] and is
## the reason neither may be raised on its own:**
##
##     CHOOSE_SEAT + CHOOSE_BLOCK_W <= half the canvas width
##
## 232 + 124 = **356 against a 640 px half** at 1280x720, the narrowest shape
## the game can be in -- the canvas only ever gets wider, because Android is
## landscape locked and the stretch is `expand`, so 1280x720 is the only shape
## to check. Each block therefore lies wholly inside its own screen half.
##
## **What breaks if it stops holding.** [method _lean_at] reads the sign of
## `x - half` and nothing else, so a block that crossed the midline would put
## part of one daughter's strand in the *other* daughter's half: a finger
## leaning across that overhang would read the wrong side, and a press that
## landed on it would light the port strand while sitting in starboard water.
## The invariant is what makes "which half is the finger in" and "which daughter
## is this strand" the same question, and every gesture on this screen -- the
## whole of [method _input] included -- assumes they are.
const CHOOSE_SEAT := 232.0
## The weave's axis and its swing, inside the block. The swing is the pause
## strand's own [constant HELIX_AMP]: same helix, different pitch.
const CHOOSE_HELIX_MID := 34.0
const CHOOSE_HELIX_AMP := HELIX_AMP
## Left to right inside a block: the caret, the weave at 16 .. 52, the dart, the
## word. The word gets everything from [constant CHOOSE_WORD_X] to the block's
## edge.
const CHOOSE_DART_X := 66.0
## **The word budget, measured, because it is the number this block ran out of
## once already.** `CHOOSE_BLOCK_W - CHOOSE_WORD_X` = **47 px**, and at
## [constant LABEL_SIZE] 13 in the fallback font the widest of
## [constant WORDS]'s eighteen is `venom` at **44.00**. Three pixels of tail,
## and that is the whole of it: the next word to need more has nowhere to go
## and will run past the block's own edge, silently, because nothing clips it.
##
## **Letters are not the measure -- the font is proportional.** `shield` is six
## letters and 38.00; `poison` is six and 43.00; `venom` is five and 44.00. What
## has to be checked when [constant WORDS] gains an entry is
## `get_string_size(word, ..., LABEL_SIZE).x <= 47`, not a letter count. The
## answer if it fails is to add the difference to [constant CHOOSE_BLOCK_W] on
## the **outboard** side, the way the 118 -> 124 widen already did, so the gap
## to the daughter does not move -- bounded by
## [constant CHOOSE_SEAT]'s midline invariant, which leaves 640 - 232 = 408 to
## grow into and not one pixel more.
const CHOOSE_WORD_X := 77.0
## The word's baseline below the locus's centre, so its x-height straddles the
## rung row rather than sitting under it.
const CHOOSE_WORD_LIFT := 4.7
## The mutation mark's seat and size (§6). Its point is 4.5 px inboard of the
## seat and its base 4.5 px outboard, so it occupies x 2.5 .. 11.5 of a block
## whose weave starts at 16.
const CHOOSE_CARET_X := 7.0
const CHOOSE_CARET := Vector2(9.0, 12.0)
const CHOOSE_CARET_ALPHA := 0.85
## The two shared rows, under both columns. 8 px below the strands' box, and
## tall enough for the 26 px explanation row, 4 of separation and the hint.
const CHOOSE_SAYS_GAP := 8.0
const CHOOSE_SAYS_H := 58.0

## The hint gains one clause at the front and invents no words. The copy count
## cannot say **whether this daughter got it**, and that is the register the
## rung shape is already drawing -- said out loud for the same reason the pause
## screen says the odds out loud.
const CHOOSE_WORN := "worn"
const CHOOSE_CARRIED := "carried"

## Which locus is lit, as `[side, slot]`, and which one the mouse is over.
## -1 for none. Hover wins over selection for the two lines below and never for
## the lens: a mouse can ask about a locus without taking the selection off the
## one the player chose.
var _choose_side := -1
var _choose_slot := -1
var _choose_hot_side := -1
var _choose_hot_slot := -1
## The loci the two DNAs disagree at, as a set of slot indices. Recomputed once
## per division; see [method _choose_differences].
var _choose_diff: Dictionary = {}
## What the explanation row is explaining. Deliberately **not** the pause
## screen's [member _explain_gene]: the two surfaces are never up at the same
## time, but sharing the variable would make that a rule rather than a fact.
var _choose_gene: StringName = &""
var _choose_tier := 0
var _choose_worn := false


## Built once, on the frame the scene enters the tree, and never rebuilt.
## **The count is an invariant** (§3.1), so a division changes what a locus
## draws and never how many there are -- which is also why nothing here reads
## the genome: the draw handler does, when there is one.
func _build_choosing() -> void:
	# **The rect is computed here and not left to the scene**, the same way the
	# explanation organ's box already is. Three of these numbers are derived --
	# the column's height from the locus count, the outboard edge from the seat
	# plus the block -- and a `.tscn` cannot add. Two places that have to agree
	# about `CHOOSE_BLOCK_W` is one place too many; the scene carries the same
	# figures so the tree is readable in an editor, and this is what binds.
	var bottom := CHOOSE_COLUMN_TOP \
		+ float(CHOOSE_LOCI + 2 * CHOOSE_CAP_LOBES) * CHOOSE_PITCH
	for side in 2:
		var column: VBoxContainer = _choose_port if side == 0 \
			else _choose_starboard
		column.anchor_left = 0.5
		column.anchor_right = 0.5
		# Identical, not mirrored (§3.3): the starboard block is the port one
		# translated, so every corresponding mark on the two strands is the same
		# distance from its opposite number at every locus.
		column.offset_left = CHOOSE_SEAT if side == 1 \
			else -CHOOSE_SEAT - CHOOSE_BLOCK_W
		column.offset_right = column.offset_left + CHOOSE_BLOCK_W
		column.offset_top = CHOOSE_COLUMN_TOP
		column.offset_bottom = bottom
		column.add_child(_make_choose_cap(0, 1))
		for slot in CHOOSE_LOCI:
			column.add_child(_make_choose_locus(side, slot))
		column.add_child(_make_choose_cap(CHOOSE_CAP_LOBES + CHOOSE_LOCI, -1))
	_choose_says.offset_top = bottom + CHOOSE_SAYS_GAP
	_choose_says.offset_bottom = _choose_says.offset_top + CHOOSE_SAYS_H
	_choose_organ.custom_minimum_size = EXPLAIN_ORGAN_SIZE
	_choose_organ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choose_organ.draw.connect(_draw_choose_organ)


## The lead-in and the tail. Neither takes input: there is nothing at either end
## to read.
func _make_choose_cap(lobe0: int, taper: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(CHOOSE_BLOCK_W,
		CHOOSE_PITCH * float(CHOOSE_CAP_LOBES))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.draw.connect(_draw_choose_cap.bind(node, lobe0, taper))
	return node


## One locus: 124 x 48 canvas px, which is 186 x 72 device px at 2400x1080 and
## exactly the 48 px floor on a 1280x720 handset.
##
## **`FOCUS_NONE`, and on this screen that is sharper than it was for the pause
## target**: the arrow keys *are* the decision here, so a focusable control would
## hand them to GUI navigation the moment anyone pressed Tab and the player
## would be unable to choose a daughter at all.
##
## Separation is 0 so the weave is continuous and adjacent targets touch. A
## mis-tap costs nothing, because selecting is free, reversible and commits
## nothing -- there is no irreversible action anywhere on this surface.
func _make_choose_locus(side: int, slot: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(CHOOSE_BLOCK_W, CHOOSE_PITCH)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.focus_mode = Control.FOCUS_NONE
	node.draw.connect(_draw_choose_locus.bind(node, side, slot))
	node.gui_input.connect(_on_choose_locus_input.bind(node, side, slot))
	node.mouse_entered.connect(_on_choose_hover.bind(side, slot))
	node.mouse_exited.connect(_on_choose_unhover.bind(side, slot))
	return node


## **What is drawn when** (§8). Called from [method _hand_division], which is
## the one place the two daughters are handed anywhere, so the strands cannot
## get out of step with the bodies they belong to.
##
## Each column takes its daughter's own [method _side_fade], which is read and
## never recomputed: a lean brightens one strand and dims the other on exactly
## the curve the bodies use, the declined strand goes out with her, and
## `replay.md` §4.1's brightness round-trip is untouched because no constant
## moved.
func _update_choosing() -> void:
	var on := _split >= Split.PART and _daughters.size() == 2
	if not on:
		if _choosing.visible:
			_choosing.visible = false
			_choose_hot_side = -1
			_choose_hot_slot = -1
		return
	if not _choosing.visible:
		_choosing.visible = true
		_choose_begin()
	# In with the daughters at PART, out with the whole surface at COMMIT.
	var whole := 1.0
	if _split == Split.PART:
		whole = clampf(_split_clock / DIVIDE_PART, 0.0, 1.0)
	elif _split == Split.COMMIT:
		whole = 1.0 - clampf(_split_clock / DIVIDE_COMMIT, 0.0, 1.0)
	_choosing.modulate.a = whole
	_choose_port.modulate.a = _side_fade(0)
	_choose_starboard.modulate.a = _side_fade(1)


## The first frame of a pair: work out where the two DNAs disagree, light the
## first locus that does, and redraw everything.
##
## **The screen opens with a locus already selected**, which is the pause
## strand's own *never nothing* rule -- a surface that opens blank has to teach
## the tap with a line of instructions, and normal mode is allowed exactly one
## authored string. The locus it opens on is the first the two daughters
## disagree at, because that is the locus that most wants reading and it
## demonstrates the tap, the caret and the hint in one frame.
func _choose_begin() -> void:
	# Godot does not re-enter a control the cursor never left, so a screen that
	# opens under a resting cursor has to start with no hover of its own.
	_choose_hot_side = -1
	_choose_hot_slot = -1
	_choose_diff = _choose_differences()
	_choose_side = 0
	_choose_slot = -1
	var order: Array = _daughters[0]["order"]
	for i in CHOOSE_LOCI:
		if _choose_diff.has(i):
			_choose_slot = i
			break
	# A lineage with one gene can mutate into itself (`mutated()` returns &""),
	# and then there is nothing to point at: fall back to the first locus that
	# carries anything, and to locus 0 if even that fails.
	if _choose_slot < 0:
		for i in CHOOSE_LOCI:
			if i < order.size() and order[i] != &"":
				_choose_slot = i
				break
	if _choose_slot < 0:
		_choose_slot = 0
	_choose_say()
	_redraw_choosing()


## **The set of loci at which the two DNAs disagree**, computed by comparing
## them rather than by asking `mutated()` which kind fired. That covers all
## three kinds with no special cases -- `shift` marks the two slots that
## swapped, `trade` the two whose counts moved, `drift` the one whose gene was
## replaced -- and it stays correct if a fourth kind is ever added.
func _choose_differences() -> Dictionary:
	var out := {}
	if _daughters.size() != 2:
		return out
	var port_order: Array = _daughters[0]["order"]
	var stbd_order: Array = _daughters[1]["order"]
	var port_dna: Dictionary = _daughters[0]["tiers"]
	var stbd_dna: Dictionary = _daughters[1]["tiers"]
	for i in CHOOSE_LOCI:
		var a: StringName = port_order[i] if i < port_order.size() else &""
		var b: StringName = stbd_order[i] if i < stbd_order.size() else &""
		if a != b or int(port_dna.get(a, 0)) != int(stbd_dna.get(b, 0)):
			out[i] = true
	return out


func _redraw_choosing() -> void:
	for side in 2:
		var column: Control = _choose_port if side == 0 else _choose_starboard
		for child in column.get_children():
			(child as Control).queue_redraw()


## The gene a locus stands for, and what the daughter on that side does with it.
## Returns `[gene, copies, worn copies]`.
func _choose_at(side: int, slot: int) -> Array:
	if side < 0 or slot < 0 or _daughters.size() != 2:
		return [&"", 0, 0]
	var order: Array = _daughters[side]["order"]
	var gene: StringName = order[slot] if slot < order.size() else &""
	if gene == &"":
		return [&"", 0, 0]
	var dna: Dictionary = _daughters[side]["tiers"]
	var body: Dictionary = _daughters[side]["body"]
	return [gene, int(dna.get(gene, 0)), int(body.get(gene, 0))]


## **The two lines below, and they are shared rather than one per side.** The
## eighteen gene lines are about the gene, and both strands carry the same gene
## at five or six of seven loci, so a per-side line would be the same sentence
## twice in most frames -- and the longest of them is 519 px, which two of,
## centred under daughters 264 px apart, overlap by 255. Which strand is being
## read is carried by the lit lens, on the thing the finger just touched.
##
## The hint's extra clause is the one thing the copy count cannot say: whether
## *this* daughter got it.
func _choose_say() -> void:
	var side := _choose_hot_side if _choose_hot_slot >= 0 else _choose_side
	var slot := _choose_hot_slot if _choose_hot_slot >= 0 else _choose_slot
	var found := _choose_at(side, slot)
	var gene: StringName = found[0]
	_choose_gene = gene
	_choose_tier = maxi(int(found[1]), 1) if gene != &"" else 0
	_choose_worn = int(found[2]) > 0
	_choose_organ.queue_redraw()
	if gene == &"":
		_choose_name.text = ""
		# A locus with nothing in it still has a direction to explain, which is
		# what the dart under it is for.
		_choose_line.text = "" if slot < 0 else EXPLAIN_EMPTY
		_choose_hint.text = "" if slot < 0 else HINT_EMPTY
		return
	_choose_name.text = String(gene)
	_choose_name.add_theme_color_override("font_color",
		Color(Cilia.hue(gene), EXPLAIN_NAME_ALPHA))
	var says := String(EXPLAINS.get(gene, ""))
	_choose_line.text = "" if says.is_empty() else "· " + says
	var register := CHOOSE_WORN if _choose_worn else CHOOSE_CARRIED
	if GenomeNode.ALWAYS_EXPRESSED.has(gene):
		_choose_hint.text = "%s · %s" % [register, HINT_CERTAIN]
	else:
		_choose_hint.text = "%s · %s" % [register,
			HINT_CHANCE[clampi(int(found[1]), 0, HINT_CHANCE.size() - 1)]]


## The one organ, beside the sentence that explains it -- the pause screen's own
## row, unchanged, including the weaker strokes for a gene the daughter carries
## and does not wear.
func _draw_choose_organ() -> void:
	if _choose_gene == &"":
		return
	Cilia.draw_tile_organ(_choose_organ, _choose_gene, _choose_tier,
		EXPLAIN_ORGAN_SEAT,
		Cilia.TILE_STROKE_ALPHA if _choose_worn else ORGAN_UNEXPRESSED,
		EXPLAIN_ORGAN_SCALE)


func _draw_choose_cap(node: Control, lobe0: int, taper: int) -> void:
	Cilia.draw_weave(node, Cilia.STRAND_ALONG_Y, CHOOSE_PITCH,
		CHOOSE_HELIX_MID, CHOOSE_HELIX_AMP, CHOOSE_CAP_LOBES, lobe0, 1.0, taper)


func _draw_choose_locus(node: Control, side: int, slot: int) -> void:
	if _daughters.size() != 2:
		return
	var found := _choose_at(side, slot)
	var gene: StringName = found[0]
	var selected := _choose_side == side and _choose_slot == slot
	var tone := Cilia.hue(gene) if gene != &"" else PALE
	var lobe0 := CHOOSE_CAP_LOBES + slot
	var mid := CHOOSE_PITCH * 0.5

	# 0.0: a locus is one lobe wide and the lens is that lobe.
	if selected:
		Cilia.draw_lens(node, Cilia.STRAND_ALONG_Y, CHOOSE_PITCH,
			CHOOSE_HELIX_MID, CHOOSE_HELIX_AMP, lobe0, 0.0,
			Color(tone, LENS_SELECTED))
	Cilia.draw_weave(node, Cilia.STRAND_ALONG_Y, CHOOSE_PITCH,
		CHOOSE_HELIX_MID, CHOOSE_HELIX_AMP, 1, lobe0,
		BACKBONE_LIT if selected else 1.0, 0)
	if gene != &"":
		Cilia.draw_rungs(node, Cilia.STRAND_ALONG_Y, CHOOSE_PITCH,
			CHOOSE_HELIX_MID, CHOOSE_HELIX_AMP, lobe0, mid, tone,
			int(found[1]), int(found[2]))

	# **An empty locus is drawn, and that invariant is the mechanism.** Weave
	# and a pale dart, no rungs and no word: dropping it would break the
	# alignment that makes the comparison a horizontal scan.
	Cilia.draw_slot_dart(node, slot,
		tone if gene != &"" else Color(PALE, 0.6),
		Vector2(CHOOSE_DART_X, mid), DART_R)

	var font := node.get_theme_default_font()
	if gene != &"" and font != null:
		var tint := LABEL_TINT
		if selected:
			tint = LABEL_TINT_LOUD
		elif int(found[2]) <= 0:
			# The third channel, agreeing with the floating rungs: a word for an
			# organ this daughter does not wear is quieter than one she does.
			tint = Color(PALE, WORD_UNEXPRESSED)
		node.draw_string(font,
			Vector2(CHOOSE_WORD_X, mid + CHOOSE_WORD_LIFT),
			String(WORDS.get(gene, String(gene))), HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, LABEL_SIZE, tint)

	# **The mutation, marked on both strands at every locus where the two DNAs
	# disagree** (§6). Not because comparison is too much work -- `lifecycle.md`
	# §2.2 is right that it is the skill -- but because the expression roll lands
	# on the same seven rows and means the opposite thing. A hue, a word or a
	# rung *count* is the mutation and is heritable; a rung *shape* is the roll
	# and rolls again. Without the caret those two channels read as one.
	#
	# It marks difference and never says which is better, because nothing here
	# is.
	if _choose_diff.has(slot):
		var half := CHOOSE_CARET * 0.5
		node.draw_colored_polygon(PackedVector2Array([
			Vector2(CHOOSE_CARET_X + half.x, mid),
			Vector2(CHOOSE_CARET_X - half.x, mid - half.y),
			Vector2(CHOOSE_CARET_X - half.x, mid + half.y)]),
			Color(tone, CHOOSE_CARET_ALPHA))


## **Where a gesture becomes a read** (§4.1), and the only place it can. This
## runs in the GUI pass, which is after [method _input] and before the unhandled
## one, so the index is already in [member _choose_gesture] as a lean and the
## line below overwrites it **on the same event**. That is "first contact
## decides", written where the decision is actually available: a locus is handed
## a press only when the press really was on it, because presses route by
## `touch_focus` and are never hit-tested afresh. No rect is measured twice, so
## what claims the gesture and what lights up cannot disagree.
##
## Everything after the press is [method _input]'s, and has to be. A locus
## cannot defend the drags of a gesture it never received: a lean's press lands
## on nothing, so its drags are hit-tested at their current position and this
## function is handed them by the engine anyway -- which is precisely the
## blocker that put `_input` in this file. See there for the mechanism and the
## measurements.
##
## **Honest about what the `accept_event()` is buying here.** Measured on 4.7,
## `MOUSE_FILTER_STOP` alone already keeps these events out of
## [method _unhandled_input]: with every `accept_event()` deleted, a press held
## on a locus and a press plus three drags both still leave the run in CHOOSING.
## It is kept anyway, for two reasons and neither is superstition. It is this
## file's own precedent -- `PauseTap` and the pause strand's loci both consume
## their own press explicitly -- and the thing it is guarding is the one
## irreversible action in the game, which should not rest on which of two engine
## mechanisms happens to fire first. What is *not* claimed is that it is what
## makes the drags safe: `_input` is.
##
## What this must **not** do: start a lean, alter one in progress, arm or commit
## anything, take keyboard focus, or change the DNA. Nothing on this screen is
## committable -- there is no held sample and no placement here -- so none of
## the pause screen's guard and timeout machinery is wanted. A second tap on the
## same locus is a no-op rather than a deselect, which is the pause screen's
## rule for the pause screen's reason.
func _on_choose_locus_input(event: InputEvent, node: Control, side: int,
		slot: int) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag \
			or event is InputEventMouseButton or event is InputEventMouseMotion:
		node.accept_event()
	if not _is_widget_tap(event):
		return
	# Claimed before the selection changes rather than after, and outside
	# [method _choose_pick]'s early-out: pressing the locus that is *already*
	# lit is still a read, and it is the one a thumb resting on the opening
	# selection makes.
	var index := _pointer_index(event)
	if index != POINTER_NONE:
		_choose_gesture[index] = true
	_choose_pick(side, slot)


func _choose_pick(side: int, slot: int) -> void:
	if _choose_side == side and _choose_slot == slot:
		return
	_choose_side = side
	_choose_slot = slot
	_choose_say()
	_redraw_choosing()


## Desktop reads by hovering, which is free and gets all seven loci with no
## clicks. It moves the two lines and deliberately not the lens: the selection
## belongs to the thing the player actually touched.
func _on_choose_hover(side: int, slot: int) -> void:
	_choose_hot_side = side
	_choose_hot_slot = slot
	_choose_say()


func _on_choose_unhover(side: int, slot: int) -> void:
	if _choose_hot_side != side or _choose_hot_slot != slot:
		return
	_choose_hot_side = -1
	_choose_hot_slot = -1
	_choose_say()
