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
@onready var _light_panel: PanelContainer = $Hud/Pause/Center/Buttons/Light
@onready var _gain_caption: Label = $Hud/Pause/Center/Buttons/Light/Box/Caption
@onready var _gain_slider: HSlider = $Hud/Pause/Center/Buttons/Light/Box/Slider
@onready var _view_panel: PanelContainer = $Hud/Pause/Center/Buttons/View
@onready var _view_caption: Label = $Hud/Pause/Center/Buttons/View/Box/Caption
@onready var _view_button: Button = $Hud/Pause/Center/Buttons/View/Box/Toggle
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
	_pause_ui.hide()
	_resume_button.pressed.connect(_toggle_pause)
	_leave_button.pressed.connect(_leave)

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
	_daughters = _make_daughters()


## Two daughters of equal mass, one faithful and one with a single sideways
## mutation, **both drawn as real bodies before the player commits**. It is not
## a gamble: you can see exactly what the mutation did.
func _make_daughters() -> Array:
	var faithful := {
		"tiers": _genome.dna().duplicate(),
		"order": _genome.layout().duplicate(),
		"mutation": &"",
	}
	var rolled: Array = GenomeNode.mutated(_genome.dna(), _genome.layout())
	var changed := {"tiers": rolled[0], "order": rolled[1], "mutation": rolled[2]}
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
				"tiers": _daughters[side]["tiers"],
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
	_genome.express(pick["tiers"], pick["order"])
	_soma.setup(_cell, _genome)
	_motes.setup(_cell)
	# **The field is reseeded.** The water around you was sized to a 40-unit body
	# and the newborn is 28; the field is a treadmill already, so this is that
	# treadmill taking one large step. It re-fires the drifter-floor invariant,
	# which is what guarantees the newborn a first meal she can certainly take.
	_food.setup(_cell)
	# And the one you did not take is left in it.
	_food.put_sister(-PI * 0.5 if _chosen == 1 else PI * 0.5, SISTER_DISTANCE,
		_cell.radius, other["tiers"])
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

	# **Leaning into one of them.** The screen halves are the targets, because a
	# 96 px body is not a 48 px target with a thumb over it, and a lean has to be
	# *held* -- so a tap commits nothing and there is no arming pattern in the
	# playfield. Read here rather than on the cell, whose input has stopped with
	# the rest of the simulation.
	if _split >= Split.PART and _read_touch_lean(event):
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
	for control: Control in [_light_panel, _view_panel, _resume_button,
			_leave_button]:
		control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# **Every group on the pause column is a surface, and `light` was the one
	# that was not.** The genome tiles are panels, `resume` and `leave` are
	# slabs, and the light caption and its track were bare strokes floating on
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
##
## **"place", not "replace".** Every new gene is a placement decision now, and
## most of them land in an empty slot -- the slot is the arc, so which empty one
## is the whole question. The compass on each tile is what answers it.
## **"your daughters wear it", because placing no longer changes you.** One word
## of difference, and it is the whole of lifecycle.md §1 said on the one surface
## that can say it.
const HINT_ARM := "tap a slot · your daughters wear it"
const HINT_COMMIT := "tap again to place"
## What the line says when nothing is held: how deep the lineage is, which is
## the only readout of how far into the run the player is and the nearest thing
## the game has to a score. Zero pixels -- Hint is already allocated 19 and is
## usually empty.
const ORDINALS: Array[String] = ["first", "second", "third", "fourth", "fifth",
	"sixth", "seventh", "eighth", "ninth", "tenth"]

## Three pip states, and the load-bearing distinction is shape: filled is an
## organ you wear, a ring is one the DNA carries and you do not, faint is
## neither. Under a luminance-only render -- no colour at all -- the three
## separate cleanly at 1:1.
const PIP_DNA_ALPHA := 0.85
const PIP_DNA_WIDTH := 1.4
## The second, weaker channel behind the pips: a gene the body does not wear
## draws its organ fainter. Honest about which one does the work.
const ORGAN_UNEXPRESSED := 0.52

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
## to nine tiny nodes, built on opening the pause screen, on arming, on the arm
## lapsing and after a swap.
##
## **Every rebuild frees the tile the keyboard was standing on, so every rebuild
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
## display, arming a tile and then simply reading it for four seconds -- which
## is the behaviour §9.7 asks for when it sells *"three pips going dark before
## it is confirmed"* -- killed the keyboard.
func _build_genome_strip() -> void:
	# Taken before anything is freed. -1 means the keyboard was not on the
	# strip at all, and then nothing here should move it: the player is on
	# `resume`, or on the slider, or is using a thumb and has no focus ring to
	# lose.
	var keeping := _focused_slot()
	for child in _genome_row.get_children():
		_genome_row.remove_child(child)
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

	var held := _genome.held_sample
	if held != &"":
		# The sample and its arrow only exist while one is held.
		_genome_row.add_child(_make_tile(held, 1, 0, Tile.HELD, -1))
		_genome_row.add_child(_make_arrow())

	# maxi, not slots(), so a genome can never be wider than the strip that
	# claims to show it. **A newborn is over capacity and that is intended**: she
	# carries up to seven genes on a body whose slots() is 3, so she may replace
	# but not add until she grows.
	var count := maxi(_genome.slots(), _slot_genes.size())
	for i in count:
		var gene: StringName = _slot_genes[i] if i < _slot_genes.size() else &""
		if gene == &"":
			# **An empty slot is armable now.** It was inert when the only thing
			# a sample could do was overwrite; it is the common case now that
			# every gene is placed by hand.
			var blank := Tile.ARMED if i == _armed else Tile.EMPTY
			_genome_row.add_child(_make_tile(&"", 0, 0, blank, i))
		else:
			var state := Tile.ARMED if i == _armed else Tile.OCCUPIED
			_genome_row.add_child(_make_tile(gene, int(dna.get(gene, 0)),
				int(body.get(gene, 0)), state, i))

	# **The slots do not move when the sample block appears or goes, and that is
	# worth one invisible node.** Row is centred, so without this the whole slot
	# block sat 73px right of where it sits with no sample -- and it snapped
	# back across that 73px the frame a swap was committed, which is the frame
	# the player is looking hardest at the tile they just changed.
	#
	# The sample cannot *lapse* under the open pause screen, whatever §5.3
	# assumed: `Genome` is `process_mode = 1`, so its 45-second clock stops with
	# the rest of the simulation. Committing is the only thing that can change
	# this strip while it is on screen, and committing is exactly the moment
	# that must not move.
	#
	# A trailing spacer the width of the sample block, minus the separation the
	# box adds in front of it, makes the row symmetric about the slots, so
	# centring the row centres the slots. The sample and its arrow hang off to
	# the left, which is the right emphasis anyway: the slots are the thing that
	# is always true.
	if held != &"":
		var gap := float(_genome_row.get_theme_constant(&"separation"))
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.custom_minimum_size = Vector2(TILE_SIZE + gap + ARROW_SIZE.x, 0.0)
		_genome_row.add_child(spacer)

	_update_hint()
	_restore_focus(keeping)


## Which slot the keyboard is on, or -1 for "not on the strip".
##
## Read off a meta rather than off the child's position in Row, because the two
## disagree at exactly the moment this is called: a slot's index among Row's
## children depends on whether a sample and its arrow sit in front of it, and
## [method _commit_slot] clears the sample *before* rebuilding -- so the offset
## that describes the strip being torn down is not the offset the genome would
## compute. A tile carrying its own slot number cannot be wrong about it.
func _focused_slot() -> int:
	for child in _genome_row.get_children():
		var tile := child as Control
		if tile != null and tile.has_focus():
			return int(tile.get_meta(&"slot", -1))
	return -1


## Puts the keyboard back on [param slot] after a rebuild.
##
## **Which slot, rather than `resume`, and the distinction is the whole fix.**
## An arm that lapses does not lapse the sample -- ARM_TIMEOUT_MS is four
## seconds and SAMPLE_SECONDS is forty-five -- so the tiles are still live and
## the player is still mid-decision, in front of the same tile they were
## reading. Sending them to `resume` would answer "can I still use the
## keyboard" with yes and "am I where I was" with no. A commit is the opposite
## case: the sample is spent, every tile has gone inert, and there is nothing on
## the strip left to stand on, so the fallback below carries it to `resume`.
func _restore_focus(slot: int) -> void:
	if slot < 0:
		return
	for child in _genome_row.get_children():
		var tile := child as Control
		if tile != null and tile.focus_mode == Control.FOCUS_ALL \
				and int(tile.get_meta(&"slot", -1)) == slot:
			tile.grab_focus()
			return
	_resume_button.grab_focus()


func _update_hint() -> void:
	if _genome.held_sample == &"":
		_genome_hint.text = _generation_text()
		return
	_genome_hint.text = HINT_COMMIT if _armed >= 0 else HINT_ARM


func _generation_text() -> String:
	if _generation >= 1 and _generation <= ORDINALS.size():
		return "%s generation" % ORDINALS[_generation - 1]
	return "generation %d" % _generation


## [param tier] is the DNA's and [param body_tier] is what this body wears. The
## tile draws the first and the pips carry both.
func _make_tile(gene: StringName, tier: int, body_tier: int, state: int,
		index: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override("panel", _tile_box(gene, state))

	# Its own slot number, so a rebuild can find the tile that replaced it
	# without re-deriving an offset that may have changed underneath.
	tile.set_meta(&"slot", index)

	var live := index >= 0 and _genome.held_sample != &""
	tile.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	tile.focus_mode = Control.FOCUS_ALL if live else Control.FOCUS_NONE

	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(_draw_tile_face.bind(face, tile, gene, tier, body_tier,
		state))
	tile.add_child(face)

	if live:
		tile.gui_input.connect(_on_tile_input.bind(tile, index))
		tile.focus_entered.connect(face.queue_redraw)
		tile.focus_exited.connect(face.queue_redraw)
	return tile


func _tile_box(gene: StringName, state: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = TILE_BG[state]
	# An armed empty slot borders in the hue of the gene about to go into it, so
	# the second tap is confirming something the tile is already showing.
	var edge := gene
	if gene == &"" and state == Tile.ARMED:
		edge = _genome.held_sample
	box.border_color = EMPTY_BORDER if edge == &"" \
		else Color(Cilia.hue(edge), TILE_BORDER_ALPHA[state])
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
		body_tier: int, state: int) -> void:
	var box := face.size
	var slot := int(tile.get_meta(&"slot", -1))
	if gene == &"":
		var mid := box * 0.5
		var arm := PLUS_ARM * 0.5
		var plus := EMPTY_PLUS
		if state == Tile.ARMED and _genome.held_sample != &"":
			plus = Color(Cilia.hue(_genome.held_sample), 0.85)
		face.draw_line(mid - Vector2(arm, 0.0), mid + Vector2(arm, 0.0),
			plus, 1.6, true)
		face.draw_line(mid - Vector2(0.0, arm), mid + Vector2(0.0, arm),
			plus, 1.6, true)
		# **The compass is on the empty tiles too, and that is the point.** The
		# player is choosing a direction, not a box, so an empty slot has to say
		# which way it looks before anything is in it.
		Cilia.draw_tile_direction(face, slot, Color(0.855, 0.953, 0.933, 0.6), box)
		if tile.has_focus():
			face.draw_rect(Rect2(Vector2(2.0, 2.0), box - Vector2(4.0, 4.0)),
				FOCUS_TINT, false, 1.5)
		return

	var font := face.get_theme_default_font()
	var loud := state == Tile.ARMED or state == Tile.HELD
	if font != null:
		face.draw_string(font, Vector2(0.0, LABEL_BASELINE),
			WORDS.get(gene, String(gene)), HORIZONTAL_ALIGNMENT_CENTER,
			box.x, LABEL_SIZE, LABEL_TINT_LOUD if loud else LABEL_TINT)

	# The organ keeps its geometry and stays rooted; a gene the body does not
	# wear simply draws fainter. That is the weaker of the two channels and the
	# first version of it -- an organ lifted off its seat -- was photographed and
	# dropped: at 76 px a 4 px lift is invisible and the tile read as *broken*.
	var worn := state == Tile.HELD or body_tier > 0
	Cilia.draw_tile_organ(face, gene, tier, box,
		Cilia.TILE_STROKE_ALPHA if worn else ORGAN_UNEXPRESSED)
	# Which arc this slot is -- the whole of why placement is a choice.
	Cilia.draw_tile_direction(face, slot, Cilia.hue(gene), box)

	# **Three pips, and two registers on them.** Filled is an organ you wear at
	# that tier, a ring is one the DNA carries and you do not, faint is neither.
	# One gene one filled pip and two rings against two filled and one faint is
	# readable at a glance at both shapes, and it is shape rather than hue that
	# carries it. The one thing on the tile that is a count rather than a
	# magnitude: at 13 pixels the 22% length step §4.3 uses on a body is a single
	# pixel, so the tile spells it out instead.
	var tone := Cilia.hue(gene)
	var y := box.y - PIP_BOTTOM
	var mine := tier if state == Tile.HELD else body_tier
	for i in 3:
		var at := Vector2(box.x * 0.5 + (float(i) - 1.0) * PIP_GAP, y)
		if i < mine:
			face.draw_circle(at, PIP_RADIUS, Color(tone, 0.92), true, -1.0, true)
		elif i < tier:
			face.draw_circle(at, PIP_RADIUS, Color(tone, PIP_DNA_ALPHA), false,
				PIP_DNA_WIDTH, true)
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
	# The rebuild frees the node this event arrived on and hands the keyboard
	# back to the tile that replaced it. Nothing to do here: that is one rule
	# in one place, and it is the rule this function used to carry a private
	# and slightly different copy of.
	_build_genome_strip()


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
## **Gated on the strip, not on the ladder.** `_genome.slots()` is the capacity
## the *body* earned, and a newborn carries her mother's whole DNA on a body two
## thirds the size -- so gating on it would silently deaden four of seven live
## tiles for the commonest state in the late game. The strip is the DNA and the
## DNA is what is being placed into.
func _commit_slot(index: int) -> void:
	if index < 0 or index >= _slot_genes.size():
		return
	_genome.place(index)
	_disarm()
	# The bus is told now rather than on the next unpaused frame: the membrane
	# keeps beating under the scrim, and an echo for a sample that no longer
	# exists is the game lying about the player's own body.
	_bus.hold(0.0)
	# The rebuild carries the keyboard: every tile has gone inert, so
	# [method _restore_focus] falls through to `resume`.
	_build_genome_strip()


## The armed slot lapses on its own, so a strip left armed is not a trap.
##
## **This does not lapse the sample.** Four seconds is a hesitation; the sample
## has forty-five, and its clock is not even running -- `Genome` is
## `process_mode = 1`, so it stops with the rest of the simulation while the
## pause screen is open. So the player is still holding a gene, the tiles are
## still live, and the rebuild puts them back on the tile they were reading.
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
