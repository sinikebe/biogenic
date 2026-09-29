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
## The pause screen draws the player's own body with the water's own routine,
## and the same organs, in the same hues, beside every gene it names. One
## vocabulary: §2.4's promise is that a point-of-view player who looks in the
## mirror already speaks the language if they ever switch views.
const Cilia := preload("res://game/vision/cilia.gd")
## **The other cell, if there is one.** Preloaded for one static lookup: the
## session is a node under `/root` that the earshot screen left there, and a run
## reached any other way finds nothing and is the game that already shipped.
const NetSession := preload("res://game/net/net_session.gd")
## **The shared pond on the wire** (shared-pond.md §3). Built only by a run that
## began inside a session; a solo run never makes one.
const Pond := preload("res://game/net/pond.gd")
## **The beam's fan, and the count that earns it levels** (beam-levels.md). Both
## are general pieces that know nothing about eyes; this file is the edge that
## gives them a gene, because it is the one with the genome, the field and
## cilia.gd's arc table all in reach.
const RayFan := preload("res://game/mechanics/ray_fan.gd")
const Tally := preload("res://game/mechanics/tally.gd")
## **A level, and what it shows** (beam-levels.md §8): the progression is read
## on the pause screen and the choosing screen, and the swell is what a level-up
## looks like -- the eye's flare, and the pause target's one breath.
const Progression := preload("res://game/mechanics/progression.gd")
const Swell := preload("res://game/mechanics/swell.gd")

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
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const FIRST_SENSES: Array[StringName] = [
	&"ocellus", &"ampulla", &"chemocyte", &"stigma"]

## The pause scrim, in the launcher's base colour, at two strengths. Point of
## view keeps Phase 4's half-veil because the membrane behind it is the live
## preview of the light slider. Full vision needs far more, because behind it is
## a lit world with the player's own cell pinned dead centre by the camera --
## exactly where the centred pause column has to sit. See _toggle_pause.
const SCRIM_POV := Color(0.023, 0.055, 0.05, 0.5)
const SCRIM_FULL_VISION := Color(0.023, 0.055, 0.05, 0.86)
## **Full vision's scrim while pause stops nothing** (shared-pond-ux.md §6).
## 0.86 exists because *the water is not what they came to read*; under B it is
## -- a hunter can reach you with the menu up -- so the water stays legible
## behind the column. A mock's number; judge it in motion on a phone.
const SCRIM_POND := Color(0.023, 0.055, 0.05, 0.70)

## **What "selected" means on the pause screen**, and it is three values rather
## than two because a gene in hand with no slot chosen yet is a real state: it is
## selected in the tray, and there is nothing yet to place it into. Declared up
## here because [member _armed] is initialised from it. See the figure's own
## section for what selection buys.
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
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
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

## Which control scheme this run is played with, as [enum RunState.Scheme]. Set
## it before the scene enters the tree to override the remembered choice --
## which is what `tools/drive.gd --scheme=` does, because the choice lives in
## `user://` and a harness that had to write one would leave it for the next
## run to inherit.
var scheme := -1

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
@onready var _resume_button: Button = $Hud/Pause/Center/Columns/Side/Resume
@onready var _leave_button: Button = $Hud/Pause/Center/Columns/Side/Leave
## **What pause means in a pond, said once, where it cannot be missed**
## (shared-pond-ux.md §6): a child of `resume` so the column never lays it out,
## in the 48 px gap above it. Hidden everywhere else.
@onready var _warn: Label = $Hud/Pause/Center/Columns/Side/Resume/Warn
## **The settings stack in a column of their own, left of the genome, and it
## was measured rather than preferred** (dna-body.md §7). Full vision's camera
## pins the player's own cell to the middle of the screen, behind the scrim.
## With the settings on the right the ghost of it sat behind the `turn` slot and
## raised the light under that chip by 29%; with them on the left the centred
## row puts the ring's one empty cell -- the port flank, which has no slot --
## within 2 px of the screen's centre at any width, so the ghost lands in the
## one place with nothing in it. Three 232 x 101 panels, unchanged, stacked.
@onready var _light_panel: PanelContainer = $Hud/Pause/Center/Columns/Side/Settings/Light
@onready var _gain_caption: Label = $Hud/Pause/Center/Columns/Side/Settings/Light/Box/Caption
@onready var _gain_slider: HSlider = $Hud/Pause/Center/Columns/Side/Settings/Light/Box/Slider
@onready var _view_panel: PanelContainer = $Hud/Pause/Center/Columns/Side/Settings/View
@onready var _view_caption: Label = $Hud/Pause/Center/Columns/Side/Settings/View/Box/Caption
@onready var _view_button: Button = $Hud/Pause/Center/Columns/Side/Settings/View/Box/Toggle
@onready var _feel_panel: PanelContainer = $Hud/Pause/Center/Columns/Side/Settings/Feel
@onready var _feel_caption: Label = $Hud/Pause/Center/Columns/Side/Settings/Feel/Box/Caption
@onready var _feel_button: Button = $Hud/Pause/Center/Columns/Side/Settings/Feel/Box/Toggle
@onready var _genome_caption: Label = $Hud/Pause/Center/Columns/Genome/Caption
## **The waiting genes, head first** (#118), one chip each above the figure --
## which is the queue, drawn, and why the verb line no longer counts it.
@onready var _tray: HFlowContainer = $Hud/Pause/Center/Columns/Genome/Waiting
## **The body, and the DNA at each part of it** (dna-body.md). Two layers of one
## box: `Body` draws the cell, its tethers, its own words and the arc being
## read, and takes no input; `Slots` holds the seven chips, the only things on
## the figure a finger can change. A drawing you cannot change must not look
## like one you can, and the asymmetry is drawn by what responds rather than by
## a tint -- the rule the two strands had, kept.
@onready var _figure: Control = $Hud/Pause/Center/Columns/Genome/Figure
@onready var _figure_body: Control = $Hud/Pause/Center/Columns/Genome/Figure/Body
@onready var _figure_slots: Control = $Hud/Pause/Center/Columns/Genome/Figure/Slots
@onready var _explain_organ: Control = $Hud/Pause/Center/Columns/Genome/Explain/Organ
@onready var _explain_name: Label = $Hud/Pause/Center/Columns/Genome/Explain/Gene
@onready var _explain_says: Label = $Hud/Pause/Center/Columns/Genome/Explain/Says
## **The line under the figure is a row now** (beam-levels.md §8.2): a levelled
## gene's level and its gauge in front of the words it always had. `Text` is
## that label, moved inside; the other two are hidden for every gene that does
## not level, which is every gene but the beam.
@onready var _hint_row: HBoxContainer = $Hud/Pause/Center/Columns/Genome/Hint
@onready var _hint_level: Label = $Hud/Pause/Center/Columns/Genome/Hint/Level
@onready var _hint_gauge: Control = $Hud/Pause/Center/Columns/Genome/Hint/Gauge
@onready var _genome_hint: Label = $Hud/Pause/Center/Columns/Genome/Hint/Text
@onready var _genome_act: Label = $Hud/Pause/Center/Columns/Genome/Act
## **The fork view** (beam-levels.md §8.3): two cards, one per way, in the
## figure's own place. Exactly one of `Figure` and `Fork` is visible, and both
## are 420 x 372, so the column never moves when one takes over.
@onready var _fork_view: Control = $Hud/Pause/Center/Columns/Genome/Fork
@onready var _ways: Array[Control] = [
	$Hud/Pause/Center/Columns/Genome/Fork/Way0,
	$Hud/Pause/Center/Columns/Genome/Fork/Way1]
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
## The drawn controls, under `Hud` and **before** `PauseTap` in the tree so the
## pause scrim covers them -- they stay drawn while paused, dead to input, which
## is the whole wordless explanation of the chooser below them (§5.1).
@onready var _controls: Control = $Hud/Controls
@onready var _recorder: RecorderNode = $Recorder
@onready var _watch_ui: CenterContainer = $Hud/Watch
@onready var _watch_button: Button = $Hud/Watch/Button
## The replay screen while it is up, as a child of this run so that the ring is
## never freed and no scene change happens.
var _replay: Node = null

## Which slot is selected, [constant SLOT_SAMPLE] for the gene in hand with no
## slot chosen, or [constant SLOT_NONE]. Selecting is reversible and that is why
## a mis-tap costs nothing, which is in turn why chips this close are acceptable.
var _armed := SLOT_NONE
## Which slot the mouse is over, or [constant SLOT_NONE]. Desktop only by
## nature: a phone has no hover, which is exactly why the tap path above exists.
var _hovered := SLOT_NONE

## The pause target's two states and the four styleboxes they are made of,
## built once in [method _style_pause] rather than per draw.
var _pause_hot := false
var _pause_well_rest: StyleBoxFlat = null
var _pause_well_hot: StyleBoxFlat = null
var _pause_bar_rest: StyleBoxFlat = null
var _pause_bar_hot: StyleBoxFlat = null
## Milliseconds, from Time, not an accumulated delta: the genome screen only
## exists while the menu is up, and in single player that is a paused tree
## handing this node a delta for a frame in which nothing else moved.
var _armed_at := 0
## The gene in each DNA slot as the chips were last built, by slot index --
## which is how the chips are seated, not the order they sit in on screen. Also
## the screen's record of the layout it is showing: see [method _strip_current].
var _slot_genes: Array[StringName] = []
## **The waiting gene in hand, by name**: the one a placement writes, the head
## of the queue unless the player picked another from the tray, &"" for none.
##
## A placement may only ever write the gene the screen is showing in hand. In a
## pond the menu stops nothing, so the queue can change under an open screen
## (#118's review): the gene in hand can lapse, or be eaten again and go to the
## back, while a slot is armed for it. **So it is held by gene and never by its
## place in the queue**, because a place in the queue is exactly what those two
## change: remembered as an index, a lapse turns "the second gene" into the next
## gene in line -- one the player never picked -- and the confirming tap writes
## it over whatever the slot held, for good. The index is looked up with
## `Genome.waiting_index()` at the moment of placing; a gene that is no longer
## waiting places nothing ([method _committable]), and [method _catch_up] puts
## the head in hand the first frame no gesture is in flight.
var _in_hand: StringName = &""
## **The queue the tray was built around**, head first. When the genome's own
## queue stops matching it -- a gene lapsed or arrived under an open screen in a
## pond -- no tap places anything until [method _catch_up] has rebuilt the
## screen around what waits now, keeping the hand if it still waits.
var _strip_waiting: Array[StringName] = []
## Which DNA slot a gene has been lifted out of while a move is in the air,
## [constant SLOT_SAMPLE] while a waiting gene is carried out of the tray, or
## [constant SLOT_NONE]. Set by `_get_drag_data` and cleared by the drop or by
## `NOTIFICATION_DRAG_END`, whichever arrives -- and one of them always does.
var _dragging := SLOT_NONE
## Which slot a finger is holding down with a placement waiting on the lift,
## or [constant SLOT_NONE].
##
## **The confirming gesture and the drag-starting gesture cannot be the same
## event, and this variable is what keeps them apart.** A pointer going *down*
## on an armed slot is ambiguous by construction: it is the second tap of
## §9.7's placement and it is also how a move begins, and both readings are
## live at the same instant on the same pixel. Committing on the down-stroke
## resolved that by the clock -- the same finger, the same two points on
## screen, placed a gene or moved one depending on whether the press landed
## more or less than [constant ARM_GUARD_MS] after the arming tap -- and one of
## those two outcomes evicts a gene from the lineage for good.
##
## So the down-stroke only **primes**: it says *a placement is waiting on this
## slot*, changes nothing, and is cancelled by the one thing that proves the
## finger meant a move, which is the drag actually starting ([method
## _slot_drag]). The irreversible half happens on the up-stroke, and only if
## the finger is still inside the chip it pressed. A drag can no longer
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

## The live session, or null in every single-player run. **Untyped on purpose**,
## like `cell.gd`'s `controls`: net_session.gd carries no class_name, so there
## is no type to declare, and a run that never had a session must not care.
##
## Read once in [method _ready] and never again: a run either began inside a
## session or it did not, and nothing about it changes mid-run.
var _net: Node = null

# --- The shared pond (shared-pond.md, shared-pond-ux.md) -----------------------
# **None of this is touched by a run with no session**: [member _pond] is null
# there, every function below returns on its first line, and the four places
# the pond changes a shipped path ask [method FoodField.pond_open] first, which
# a solo field always answers false.

## The wire's end of the pond, or null.
var _pond: Pond = null
## **The pause menu is open.** In single player this is exactly
## `get_tree().paused`, which is what it replaced (§1.7); in a session the tree
## is never paused and this is the only thing that says the menu is up.
var _menu_open := false
## The guest's pond is held: the host has gone quiet, so nothing here moves.
var _held := false
## **The water changes** (UX §0.5): seconds into the beat, or -1 for none. The
## swap runs at [member _beat_swap_at] seconds, and [member _beat_line] is said
## once the beat is over.
var _water_beat := -1.0
var _beat_swap := Callable()
var _beat_swap_at := 0.0
var _beat_swapped := false
var _beat_line := ""
## The guest's three ways of waiting for ARRIVE: a run that opened inside the
## pond and is held for the round trip, a solo run swapping in, and a tap on the
## black.
var _entering_held := false
var _swap_pending := false
var _wake_pending := false
## **The one-slot line queue** (UX §0.4): what waits, since when it may be said,
## and which fact it reports -- so it is dropped the moment that stops being
## true. [member _line_shown] is the pond line on the label now, or "".
var _line_key := ""
var _line_text := ""
var _line_after := 0.0
var _line_hold := SENSE_LINE_HOLD
var _line_shown := ""
## Seconds this run has lived, for the lines' not-before times.
var _run_clock := 0.0
## The friend died and has not come back yet; they have been in this water at
## all this run; their phone's silence has been announced.
var _friend_dead := false
var _friend_ever := false
var _quiet_said := false
## This run's recording holds pond frames, so there is no replay to offer yet
## (shared-pond.md §5, Phase 3).
var _ponded := false

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

# --- The beam (beam-levels.md) ----------------------------------------------
## Where the beam's rays are and what arc each crossed this frame. Kept from
## frame to frame because a sweep is a place in a cycle.
var _beam_fan := RayFan.new()
## Different bodies the beam touched this second, which is its experience.
var _beam_tally := Tally.new(CellBody.BEAM_XP_CAP)
## **What the membrane's beam lobe is still holding**, for a sweep: a hit that
## is only lit once a pass stays on the skin and fades over the revisit time,
## or a sweep reads as flicker (§4.3). Strength and bearing, as the bus takes
## them, and how long ago that hit was.
var _beam_held := 0.0
var _beam_held_bearing := 0.0
var _beam_held_age := 0.0

## **A level arriving: the eyespot flares** (beam-levels.md §8.5). Armed by the
## level-up, and by a path taken with levels banked behind it, and cued by the
## next heartbeat, because the beat is the one rhythm the player is already
## watching: 0.15 s up, then 1.05 s down on `1 - smoothstep`. Own cell only,
## both views; cilia.gd draws it. The replay flares the same way, off the same
## two numbers.
const EYE_FLARE_RISE := 0.15
const EYE_FLARE_FALL := 1.05
var _eye_flare := Swell.new(EYE_FLARE_RISE, 0.0, EYE_FLARE_FALL)
## Which gene's pigment the flare is on: the one that levelled.
var _eye_gene: StringName = &""

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
## default chosen for tidiness: a finger that was already down before this
## screen started listening -- before the pinch, on the cell's watch -- has no
## press for it to have seen, and it is the one [method _read_touch_lean]'s drag
## branch exists for.
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
	# **The one wire out of this water.** Connected unconditionally: an emit
	# with nothing on the far end is free, and a branch here would be a branch
	# in the frame loop of a game that is single-player almost all the time.
	_food.pulsed.connect(_on_pulsed)
	_net = NetSession.current
	if _net != null and not is_instance_valid(_net):
		_net = null
	# **The shared pond, if this run began inside a session** (shared-pond.md
	# §3). Built before anything is seeded; opened below, once the water is.
	if _net != null:
		_pond = Pond.new(_net, _food, _cell, _genome)
		_pond.arrived.connect(_on_pond_arrived)
		_pond.friend_entered.connect(_on_friend_entered)
		_pond.friend_died.connect(_on_friend_died)
		_pond.friend_left.connect(_on_friend_left)
		_pond.friend_renewed.connect(_on_friend_renewed)
	# **The one thing the world view is told about the wire**, and it is a read
	# handle: full vision draws the other player where they are, and point of
	# view does not and must not. `panes.gd` builds its own copy of that view
	# for a recording and deliberately never calls this -- a replay has no peer
	# in it. See vision.gd's `set_session`.
	_vision.set_session(_net)
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
	# Read in the same breath and for the same reason: a player who chose
	# `stick` last run must not have to choose it again.
	if scheme < 0:
		scheme = RunState.load_scheme()
	_apply_mode()

	_style_pause()
	_explain_organ.custom_minimum_size = EXPLAIN_ORGAN_SIZE
	_explain_organ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_explain_organ.draw.connect(_draw_explain_organ)
	# The figure's box and its body layer. The chips and the tray are built when
	# the screen opens; nothing here draws until then, so a headless boot pays
	# for two signal connections.
	_figure.custom_minimum_size = FIGURE_SIZE
	_figure_body.draw.connect(_draw_figure_body)
	_tray.resized.connect(_latch_tray)
	# The level's row and the fork's two cards: a few connections and four
	# styleboxes, drawn only once the screen opens on a gene that levels.
	_build_level_row()
	_build_fork_view()
	# **The heartbeat is the flare's cue** (beam-levels.md §8.5), and the pause
	# target's breath rides the same beat. Listening is not posting: this file
	# is still the only one that writes to the bus.
	_bus.sensation.connect(_on_bus_sensation)
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

	# **The wells a thumb presses are the pause target's own slab**, built by the
	# one function that knows what a slab is. What you press looks like a piece
	# of the surface the pause target opens.
	_controls.setup({
		&"well": _well(0.13, 0.09),
		&"well_lit": _well(0.58, 0.48),
		# A knob at 0.20 / 0.30 rendered as a solid grey block -- the loudest
		# interface object on the screen and brighter than the cell. This is a
		# watermark with an edge, which is what a control at the rim may be.
		&"knob": _well(0.045, 0.28),
		&"knob_lit": _well(0.16, 0.80),
	})
	_controls.set_scheme(scheme)
	# The cell asks the controls what it is being told to do; the controls never
	# reach back. Set after _ready has built them and before the first frame.
	_cell.controls = _controls
	_feel_button.pressed.connect(_cycle_scheme)
	_update_scheme_button()
	_update_controls()

	_bus.gain = clampf(RunState.load_gain(SignalBus.GAIN_DEFAULT),
		SignalBus.GAIN_MIN, SignalBus.GAIN_MAX)
	_gain_slider.value = _bus.gain
	_gain_slider.value_changed.connect(_on_gain_changed)
	_gain_slider.drag_ended.connect(_on_gain_settled)

	_begin_onboarding()
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
	if _pond != null:
		_begin_pond()


func _exit_tree() -> void:
	# The session outlives the run by a frame on the way to the chooser, which
	# closes it; until then it must not say this run's pond is still open.
	if _net != null and is_instance_valid(_net):
		_net.set_pond(false, false)


func _process(delta: float) -> void:
	# **The pond first, before every early return** (shared-pond.md §3): its
	# intake goes on while this cell is dead, dividing or held, because the
	# water it is part of does.
	if _pond != null:
		_step_pond(delta)
	# **What is simulated is decided from state every frame**, as well as the
	# moment any of it changes (_update_simulating): no frame can leave a body
	# running that its state says is still. In single player every change is
	# already made where it happens, so this one never changes anything there.
	_update_simulating()
	# Before every early return below, because the states those returns lead to
	# -- dying, dividing, paused -- are exactly the ones with no button.
	_update_pause_tap()
	# And before them for the opposite reason: the controls are drawn through a
	# division and through a pause, and what changes is *which* of them.
	_update_controls()
	# Before them too: the states they lead to -- dead, paused, held, divided --
	# are exactly the ones the body held open has to shut in. dna-body.md §8.
	_step_offer(delta)
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
	if _menu_open and not _session_up():
		# The genome screen is the one thing on screen that still has a clock
		# running: a slot armed for the gene in hand lapses after four seconds
		# whether or not the simulation is moving. §5.2. A selection with
		# nothing to commit has no clock -- see [method _step_arming].
		#
		# **Single player only.** With a session up the tree is never paused
		# (shared-pond.md §1.7, owner's B): the menu is open over a live water,
		# and everything below still runs, the screen's clock included.
		_step_arming()
		# The fork's cards move on this node's own frame delta, which a paused
		# tree still hands it: the one picture on the screen that is alive.
		_step_fork_view(delta)
		return
	# The pond's three still moments: held while the host is quiet, the beat of
	# the water changing, and a run opening inside the pond waiting for its
	# arrival. Nothing is simulated in any of them, so there is nothing to post.
	if _held or _water_beat >= 0.0 or _entering_held:
		return
	if _menu_open:
		_step_arming()
		# The waiting genes' own clocks run under an open menu here, and the
		# tray shows the last fifteen seconds of each.
		_step_tray()
		_step_fork_view(delta)
		# And the beam earns under it (beam-levels.md §2), so the level and
		# its gauge move while the screen is up.
		_step_levels_shown()
	# The division. Its first phase leaves the simulation running -- steering
	# still works and nothing is taken away -- and from the pinch on
	# _update_simulating() stops it, exactly as it does for a death, so there
	# is nothing below here left to post.
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
	_aim_beam(delta)
	# `chemocyte` and `ampulla`: how far this nose reaches and how often this
	# electroreceptor fires. Scalars about the cell's own anatomy, handed to the
	# field so it can answer in bearings -- the same contract as beam_range.
	_food.smell_range = _cell.smell_range()
	# **Where the nose is**, resolved here for the same reason the pulse's arc
	# below is: this file has both the genome and cilia.gd's arc table. Smell
	# stopped being a bearing (three-senses.md §2) -- what the field answers is
	# a level, and this is the arc that level is weighted about.
	_food.smell_bearing = _slot_bearing_of(&"chemocyte")
	_food.ping_range = _cell.ping_range()
	_food.ping_period = _cell.ping_period()
	# **Where the pulse leaves from**, resolved here for the same reason the
	# beam's fan and the dart's arc are: this file has both the genome and
	# cilia.gd's arc table. It is a bearing, not a place -- the field turns it
	# into the one world position it needs and spends it inside `_cast_ping`.
	_food.ping_bearing = _slot_bearing_of(&"ampulla")
	_food.ping_through = _cell.ping_through()
	# The organ's own resolution, beside its reach and its rate: how many bodies
	# one pulse answers for and how much of each body's true angular extent
	# survives into the readout. ping-as-outline.md §4.
	_food.ping_tier = _cell.ping_tier()
	# **`taste_level`, not `concentration`.** The first is what this nose picks
	# up and the second is what the water is like; the beat above reads the
	# water, the membrane reads the organ. A cell with no chemocyte hands over a
	# flat zero and gets no green band at all -- which is the whole change, and
	# is enforced again inside the bus.
	#
	# **The bearing is the organ's own arc and comes from this file, not from
	# the field.** Nothing about the water reaches the membrane through this
	# channel any more: the same number was written into `smell_bearing` above,
	# and all it does downstream is tell the shader which side of the ring is
	# the bright one. It is the same value every frame of a run unless the
	# player moves the gene. three-senses.md §2.2.
	_bus.taste(_food.smell_bearing, _food.taste_level)
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
	# The beam's by its level, held to the three rungs the membrane's lobe
	# widths are written for; the other two are still their copies.
	_bus.sense_organs(mini(_cell.beam_level(), CellBody.BEAM_FORK_LEVEL),
		_cell.extra(&"chemocyte"), _cell.extra(&"ampulla"))
	_post_beam(delta)
	_earn_beam(delta)
	_post_pings()
	_tell_others()
	# `palp`: something solid, right there, felt with no light at all.
	if _food.touch_level > 0.0:
		_bus.touch(_food.touch_bearing, _food.touch_level)
	_bus.hold(_genome.held_remaining if _genome.held_sample != &"" else 0.0)
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
	_bus.shear(_cell.shear_rate())
	# Proprioception is not a sensation and does not go on the bus: it is a
	# view, and it is handed the one number it cannot derive for itself.
	_soma.beat = _bus.pulse()
	# The eye and the pause target: a choice waiting, a level arriving.
	_step_eye(delta)
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


## **Where this cell's beams look, and the arc each one crossed this frame.**
## The slot is the arc and the arc is the bearing -- that is the whole of
## placement mattering, and it is resolved here because this file has both the
## genome and cilia.gd's arc table. cell.gd cannot: cilia.gd preloads
## genome.gd, which preloads cell.gd, so a preload back the other way would be
## a cycle GDScript will not resolve.
##
## The fan's shape is the beam's level and path (cell.gd's `beam_shape`); the
## fan works out where each ray is; this adds where the organ is worn. The field
## is handed each sweeping ray's arc as well as its bearing, because a sweep has
## to be tested across everything it crossed (beam-levels.md §4.3), and the
## fan's middle and half-width, so it can skip bodies nowhere near it (§4.4).
func _aim_beam(delta: float) -> void:
	var shape := CellBody.beam_shape(_cell.beam_level(), _cell.beam_path())
	var slot := _genome.slot_of(&"ocellus")
	_food.beam_range = float(shape[3])
	var bearings := PackedFloat32Array()
	var arcs := PackedFloat32Array()
	if int(shape[0]) <= 0 or slot < 0:
		_food.beam_bearings = bearings
		_food.beam_arcs = arcs
		_food.beam_hold = 0.0
		_food.beam_fan_half = -1.0
		return
	var half := deg_to_rad(float(shape[1]))
	_beam_fan.configure(int(shape[0]), half, deg_to_rad(float(shape[2])))
	_beam_fan.step(delta)
	var middle := Cilia.slot_bearing(slot)
	var offsets := _beam_fan.offsets()
	var low := _beam_fan.arc_low()
	var high := _beam_fan.arc_high()
	var hold := _beam_fan.revisit()
	for i in offsets.size():
		bearings.append(wrapf(middle + offsets[i], -PI, PI))
		if hold > 0.0:
			arcs.append(wrapf(middle + low[i], -PI, PI))
			arcs.append(wrapf(middle + high[i], -PI, PI))
	_food.beam_bearings = bearings
	_food.beam_arcs = arcs
	_food.beam_hold = hold
	_food.beam_fan_mid = middle
	_food.beam_fan_half = half


## **The beam's experience** (beam-levels.md §2): one for every different body
## its rays touched in a second, capped, and only while this body wears it.
## Every body counts -- food, a hunter, a sister, the other player -- because
## the beam's job is to find surfaces, not to judge them.
func _earn_beam(delta: float) -> void:
	if _cell.extra(&"ocellus") <= 0:
		_beam_tally.reset()
		return
	for index: int in _food.beam_touched:
		_beam_tally.touch(index)
	var earned := _beam_tally.step(delta)
	if earned > 0:
		_earn(&"ocellus", float(earned))


## **Experience for [param gene], and what a level-up shows** (beam-levels.md
## §8.4-§8.5). The genome keeps the level; this is the edge that makes it seen:
## the eye flares on the next beat, and a level-up that opens the fork has the
## pause target breathe once. **Once per lineage** falls out of where it is
## asked: a daughter who inherits an open fork never levels into it, so she is
## not told again.
##
## The one door experience comes in by -- the beam's tally, and
## `tools/drive.gd --earn=`, which poses a level-up through it.
func _earn(gene: StringName, amount: float) -> void:
	var grown := _genome.progression(gene)
	if grown == null:
		return
	var before := grown.level()
	if not _genome.earn(gene, amount):
		return
	_eye_gene = gene
	_eye_flare.arm()
	if PAUSE_BREATHES_AT_FORK and before < grown.fork_level \
			and _genome.can_choose(gene):
		_pause_breath.arm()


## **A new body starts with an ordinary eye and a quiet pause target**: a
## death, a birth and a return. A flare or a breath armed for the body that
## just ended is about that body, and a daughter who inherits an open fork is
## not told about it again.
func _forget_eye() -> void:
	_eye_flare.clear()
	_eye_gene = &""
	if _pause_breath.running():
		_pause_tap.queue_redraw()
	_pause_breath.clear()
	_soma.eye = {}
	_vision.eye = {}


## The heartbeat, heard. It cues what a level-up armed -- **but only a beat the
## body is on screen for**: a pause over it in single player, where the bus
## keeps beating under the scrim, would spend the flare where nobody can see
## it, so it waits for the first beat back in the water.
func _on_bus_sensation(kind: StringName, _info: Dictionary) -> void:
	if kind != &"beat":
		return
	if _menu_open or _life != Life.ALIVE or _split >= Split.PINCH:
		return
	_eye_flare.cue()
	if _pause_breath.armed():
		# It holds for one beat, and the beat is whatever the body is beating
		# at now: a starving cell's breath is slower, as its heart is.
		_pause_breath.hold = _metabolism.beat_period()
		_pause_breath.cue()


## Once a frame, in the water: the flare and the breath move on, and both views
## are handed the eye. The pause target is redrawn for as long as it breathes,
## and once more after, to lay it back at rest.
func _step_eye(delta: float) -> void:
	_eye_flare.step(delta)
	var breathing := _pause_breath.running()
	_pause_breath.step(delta)
	if breathing:
		_pause_tap.queue_redraw()
	var eye := eye_of(_genome, _eye_gene, _eye_flare.value())
	_soma.eye = eye
	_vision.eye = eye


## **What the eye is doing, for cilia.gd** (beam-levels.md §8.4-§8.5):
## `{"gene": g, "bud": n, "flare": f}`, or empty for an ordinary eye.
##
## It buds for the first levelled gene **this body wears** whose fork is open --
## the pigment is on the body, so a gene only the DNA carries has none to bud --
## with `bud` the levels banked since the fork. [param flaring] is the gene a
## level just arrived for and [param flare] how far through its swell it is.
## Static, because the replay asks the same question of the genome it restored
## and must get the same answer.
static func eye_of(genome: GenomeNode, flaring: StringName,
		flare: float) -> Dictionary:
	if genome == null:
		return {}
	for gene: StringName in genome.levels():
		if genome.tier(gene) <= 0:
			continue
		var grown := genome.progression(gene)
		var bud := grown.level() - grown.fork_level if grown.can_choose() else -1
		var lit := flare if gene == flaring else 0.0
		if bud < 0 and lit <= 0.0:
			continue
		return {"gene": gene, "bud": bud, "flare": lit}
	return {}


## Which way a directional organ looks: the bearing of the arc it is worn on,
## dead ahead for a gene this body does not wear. **The body's slot, not the
## DNA's** -- the organ is on the body, and the DNA is what the daughters get.
func _slot_bearing_of(gene: StringName) -> float:
	return Cilia.bearing_of(_genome, gene)


## The one beam the membrane hears about: the nearest hit. There is one glow
## lobe left in the shader and many rays past the fork, so they compete rather
## than sum -- the closest surface is the one worth telling a blind cell about.
## Full vision draws all of them, which is what full vision is for.
##
## **A sweep's hit is held**, fading over the time the sweep takes to come back
## (beam-levels.md §4.3): a ray that passes a body once a pass would otherwise
## light the skin for one frame in thirty. A nearer hit takes over at once. A
## fixed fan's hold is 0, and then this is the post it always was.
func _post_beam(delta: float) -> void:
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
	var hold := _food.beam_hold
	if hold > 0.0:
		_beam_held_age += delta
		var fading := _beam_held * clampf(1.0 - _beam_held_age / hold, 0.0, 1.0)
		if best >= fading and best > 0.0:
			_beam_held = best
			_beam_held_bearing = bearing
			_beam_held_age = 0.0
		else:
			best = fading
			bearing = _beam_held_bearing
	else:
		_beam_held = 0.0
		_beam_held_age = 0.0
	_bus.beam(bearing, best)


## **The ping's returns**, drained from the field and posted one at a time.
##
## Unlike the beam these do not compete before they reach the bus: each return
## is a separate event at a separate bearing, and the membrane's arcs are what
## resolve two that land in the same instant. Spacing them out in *time* is the
## field's job, and it is what makes one pulse read as a sweep.
##
## **Four scalars, and still not one of them is a place.** A bearing, a level,
## an angular half-width and a hold time: the width conflates size with distance
## on purpose and the hold is a duration, so no arrangement of the four recovers
## a position. ping-as-outline.md §0.
##
## Plus the organ's own arc, humming while its pulse is still in the water --
## a bearing and a scalar, like everything else that reaches the bus. It is what
## makes an eight-second wait read as *listening* rather than as nothing, and it
## draws the blind arc for free: the hum is where the pulse went, so the half of
## the water you are not asking is the half that is dark.
func _post_pings() -> void:
	for echo: Array in _food.pings:
		_bus.ping(float(echo[0]), float(echo[1]), float(echo[2]), float(echo[3]))
	_hear_others()
	_bus.ping_out(_food.ping_bearing, _food.ping_listen)


## **Somebody else's pulse, arriving.** Drained here rather than handled on the
## signal, so a shout off the network reaches the membrane through exactly the
## door every other mark does -- the same loop, the same frame, the same four
## scalars.
##
## **This is where a place stops being a place.** The wire carries where the
## other cell was, because one water means one frame of reference and a bearing
## cannot be computed without an origin; `bearing_to` turns it into an angle off
## this body's own nose and nothing downstream ever sees the Vector2. That is
## the identical conversion `food.gd` does to every body in the water at
## `_step_pings`, done on the same side of the same seam.
##
## Every scalar below comes out of `food.gd`'s own tables, and that is the
## point: a shout is heard by the law an echo is, [method FoodField.ping_level],
## over the path it actually travelled -- **one way**, where an echo's is out
## and back. So a friend's call is louder than an echo off a body that size at
## that distance, and carries to twice the reach her own echoes come home from,
## and it arrives at once rather than after its flight (the owner's call, issue
## #45). There is not one tuning number in this function.
func _hear_others() -> void:
	if _net == null or not is_instance_valid(_net):
		return
	for said: Array in _net.drain_heard():
		var at: Vector2 = said[0]
		# **No bigger than a body, no further than an organ calls** (#102): the
		# mark is held for as long as the caller's size says, and a host's
		# referee is the only thing between a guest's call and here -- a guest
		# has none over its host. Honest calls are never over either.
		var radius := minf(float(said[1]), CellBody.DIVIDE_RADIUS)
		var reach := minf(float(said[2]),
			CellBody.PING_RANGE_BY_TIER[CellBody.PING_RANGE_BY_TIER.size() - 1])
		# A bodiless or organless shouter is not a thing a cell can hear, and
		# it is also the one input that would divide by zero below. Both
		# answered by not hearing it.
		if not (radius > 0.0) or not (reach > 0.0):
			continue
		var apart := _cell.position.distance_to(at)
		# Surface to surface, the way `_cast_ping` measures everything.
		var gap := maxf(apart - radius, 0.0)
		# Her organ's reach, not this cell's: it is her pulse. One way, so it
		# runs out of water at twice that -- and a call the water has taken
		# down to what `_cast_ping` would not spend a slot on is not played
		# either. Written so a NaN is refused rather than posted.
		var level := FoodField.ping_level(gap, reach)
		if not (level > FoodField.PING_SILENT):
			continue
		var tier := clampi(_food.ping_tier, 0,
			FoodField.PING_WIDTH_FLOOR.size() - 1)
		# `span` floored at the radius so `asin` is never asked for more than 1
		# -- the same guard, for the same reason, as the field's own.
		var alpha := rad_to_deg(asin(clampf(radius / maxf(apart, radius), 0.0,
			1.0)))
		var width := minf(FoodField.PING_WIDTH_FLOOR[tier]
			+ FoodField.PING_WIDTH_GAIN[tier] * alpha, FoodField.PING_WIDTH_MAX)
		var hold := FoodField.PING_RING * 2.0 * radius / FoodField.PING_SPEED
		_bus.ping(_cell.bearing_to(at), level, width, hold)


## **This cell's `ampulla` fired.** The other player hears it, and what crosses
## is three facts about this body: where the pulse left from, how big it is, how
## far its organ carries. No heading, no velocity, no genome, no name.
##
## Free in single player: `shout()` returns on its first line when there is
## nobody on the wire, and there is no session at all in a run reached any way
## but through the earshot screen.
##
## **Not from out of the water** (shared-pond.md §3): the field runs on through
## a death or a division in a pond, and a cell that is not in it does not shout.
## Always in the water in single player.
func _on_pulsed() -> void:
	if not _food.in_water:
		return
	if _net == null or not is_instance_valid(_net):
		return
	_net.shout(_cell.position, _cell.radius, _cell.ping_range())


## **Where this cell is and how it is moving, for the other player's screen.**
## Handed to the session once a frame -- and once more from [method
## _on_impulsed] the instant the body jumps -- and the session decides what
## leaves: twenty frames a second, and one at once whenever the other screen's
## picture would otherwise be wrong. That is the right way round, because the
## alternative is a session reaching into a scene at a moment of its own
## choosing.
##
## The velocity and the turn rate are the body's own, straight off `cell.gd`,
## so the other screen can draw the body where it is rather than where it last
## was. They are motion, not sensation: nothing here reaches `_bus`.
##
## **This changes nothing about what anybody feels.** It is the same seam
## `_on_pulsed` already crosses: a place goes on the wire, because one water
## means one frame of reference and neither a bearing nor a marker can be had
## without an origin. Nothing comes back through `_bus` because of it -- what a
## remote position reaches is `vision.gd`, which draws, and the rule that no
## position reaches the signal bus is exactly as intact as it was. The other
## player is still only *heard* in point of view, and only when their `ampulla`
## fires.
##
## Free in single player, like the shout: the session is null and this is one
## comparison.
func _tell_others() -> void:
	if _net == null or not is_instance_valid(_net):
		return
	_net.report_body(_cell.position, _cell.heading, _cell.radius,
		_cell.velocity, _cell.heading_rate())


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
	# **A division closes the menu** (shared-pond.md §1.7). Only reachable with
	# a session up, where the menu no longer stops the water; in single player
	# the menu pauses the tree and nothing here runs under it.
	if _menu_open:
		_set_menu(false)
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
	# **The daughters are not rolled yet** -- that waits for the pinch
	# ([method _step_split]). The quickening is 2.4 seconds of a body that still
	# swims and still eats, and a DNA rolled at its first frame never saw a
	# copy it swallowed or a waiting gene that lapsed into a free slot in the
	# rest of it (#118). Nothing draws a daughter before PART, so rolling at
	# the pinch changes nothing on screen.
	_daughters = []


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
				# From the DNA as it stands at the end of the quickening, the
				# last frame anything can still write it. See [method
				# _begin_split].
				_daughters = _make_daughters()
				# The same call a death makes. The water stops, the body does
				# not: what is left moving is the division itself.
				_update_simulating()
				# **In a pond the water does not stop** (shared-pond.md §1.5):
				# this cell leaves it instead, still an anchor, so what the
				# daughter comes back to is still there -- and from this frame
				# nothing in it can see, touch or chase this cell.
				if _food.pond_open():
					_food.leave_water(false)
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
	_bus.ping_out(0.0, 0.0)
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
	# **A drawn control that is being held decides it.** A thumb parked on the
	# stick sits at canvas x 144, which is the port half *whichever way it is
	# pushing*, and under `pads` both turn pads are in the port half -- so the
	# screen half cannot be the only read once anything is drawn down there. A
	# steering control that is held and centred therefore means *no lean*, and
	# does not fall through.
	if _controls.steering():
		var want: float = _controls.steer()
		if absf(want) > CellBody.STEER_DEADZONE:
			return -1 if want < 0.0 else 1
		return 0
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
	_update_dim()
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
	# the whole of INHERIT_TIER_LOSS being zero. **And what her mother had not
	# placed yet goes with her, still waiting** (#118) -- `express()` empties
	# the queue, so it is taken first and handed back after.
	var carried := _genome.take_waiting()
	# **And her mother's levels** (beam-levels.md §3): a copy of each one for a
	# gene in her own DNA, grown or not. The same copies her sister would have
	# had, so which daughter is chosen never changes a level.
	_genome.express(pick["tiers"], pick["order"], pick["body"], null,
		_genome.levels())
	_genome.carry(carried)
	_forget_eye()
	_soma.setup(_cell, _genome)
	_motes.setup(_cell)
	var side := -PI * 0.5 if _chosen == 1 else PI * 0.5
	if _food.pond_open():
		# **In a pond there is no reseed** (shared-pond.md §1.5, UX §2): the
		# water this daughter comes back to is the one her mother left, still
		# moving, and it is the other player's water as much as hers. She comes
		# back into it with a new cell's organs and grace, and the sister goes
		# into a free slot -- by SISTER, from a guest, because a guest's water
		# is the host's.
		_food.enter_water()
		_leave_sister(side, other["body"])
		_pond.person_changed(true)
	else:
		# **The field is reseeded.** The water around you was sized to a
		# 40-unit body and the newborn is 28; the field is a treadmill already,
		# so this is that treadmill taking one large step. It re-fires the
		# drifter-floor invariant, which is what guarantees the newborn a first
		# meal she can certainly take.
		_food.setup(_cell)
		# And the one you did not take is left in it.
		# The body she wears, again: a cell in the water is an organism, and
		# what it is carrying and not wearing is not a thing anything out there
		# can read.
		_food.put_sister(side, SISTER_DISTANCE, _cell.radius, other["body"])
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
	_update_simulating()
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
	_bus.pulse_now()


func _on_impulsed(strength: float) -> void:
	_bus.thrust(strength)
	# **The jump leaves in the frame it happens.** The once-a-frame report below
	# runs before the body steps, so without this the other screen would hear
	# of an impulse a frame late -- and a jump is precisely the moment the owner
	# said arrived late. The session decides whether it is worth a frame; an
	# impulse always is.
	if _life == Life.ALIVE:
		_tell_others()


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
	if not _in_the_water():
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
	# **The genome screen rebuilds on a meal** (shared-pond.md §1.7): with the
	# menu open over a live pond the genome can change under it. Unreachable in
	# single player, where the menu stops the water.
	if _menu_open:
		# A meal that brought the first gene to wait is a new decision, and the
		# head goes in hand as it does when the screen opens. **A gene eaten
		# again stays in hand**: it is still waiting -- one copy more, at the
		# back of the queue -- and it is still the gene the player picked. See
		# [member _in_hand] and [method _catch_up]. Rebuilt whatever that says:
		# a meal can raise a copy without moving anything.
		_catch_up()
		_build_genome_strip()


func _on_waked(bearing: float, strength: float) -> void:
	_bus.shove(bearing, strength)


func _on_killed(bearing: float) -> void:
	_die(true, bearing)


## **Whether what the water does to this cell happens to it**: alive -- or, in a
## pond, returning, because a returning cell is in the water from the tap
## (owner's row A) and the host's water can feed it or kill it there. The host
## is the authority on both, so a mirror that ignored them would leave a cell
## alive on its own screen and gone from everybody else's. Solo, a returning
## cell's water is freshly seeded and nothing in it can reach it, and this is
## exactly the shipped `_life == Life.ALIVE`.
func _in_the_water() -> bool:
	return _life == Life.ALIVE or (_life == Life.RETURNING and _food.pond_open())


# ---------------------------------------------------------------------------
# Death. Two of them, and they feel opposite: predation slams the membrane shut
# at a bearing, starvation lets it sink with no bearing at all. Both end at the
# same black, which holds until the player touches the screen -- so there is a
# natural place to put the phone down. docs/design/food-and-predators.md §6.
# ---------------------------------------------------------------------------

func _die(loud: bool, bearing: float) -> void:
	if not _in_the_water():
		return
	# **A death closes the menu** (shared-pond.md §1.7): reachable only with a
	# session up, where the menu no longer stops the water and a hunter can
	# reach this cell under it.
	if _menu_open:
		_set_menu(false)
	_life = Life.DYING
	# **The black has no text** (shared-pond-ux.md §0.4, §4): whatever the line
	# was saying goes with the light, stepped by _step_death -- the label is
	# stepped only while alive, and rendered, a line up at the hit stood on the
	# black beside `watch`, in single player as well as in a pond.
	if _onboard != Onboard.OFF and _onboard != Onboard.FADE_OUT:
		_onboard_from = _onboarding.modulate.a
		_onboard_clock = 0.0
		_onboard = Onboard.FADE_OUT
	_line_shown = ""
	# **The marker on the other screen goes out here.** Not a disconnection --
	# the link is fine and so is the person -- but there is no longer a cell to
	# draw, and a marker left pointing at a corpse is the exact failure the
	# quiet decay exists to avoid, with none of the honesty.
	if _net != null and is_instance_valid(_net):
		_net.forget_body()
	_death_loud = loud
	_death_clock = 0.0
	_vision_cut = false
	_tap_pending = false
	_forget_eye()
	# A death during the quickening -- the one phase the water is still moving
	# in -- takes the division with it. The collapse owns the screen, and two
	# daughters drawn under it would be the game contradicting itself twice.
	_split = Split.NONE
	_daughters = []
	_division = {}
	_hand_division()
	# **A death ends the water's beat** (shared-pond.md §3): the collapse owns
	# the screen from here, and the beat's revive, its world coming back in and
	# its first pulse would all fight it. Reachable in a pond only, where the
	# host's water can kill a cell that is still in the second half of the beat
	# that put it there.
	if _water_beat >= 0.0:
		_end_water_beat()
	_update_simulating()
	# **In a pond the water runs on under the black** (owner's row A,
	# shared-pond.md §1.5): only this cell stops, leaving the water and no
	# longer an anchor -- for the kills the field makes itself it already has,
	# in the same frame -- and the other player is told how. Loud is the field's
	# own kill, and it has just said why; quiet is starving, which is this run's.
	if _food.pond_open():
		_food.leave_water(true)
		_pond.died(_food.died_of if loud else FoodField.Cause.STARVED,
			_food.died_by if loud else 0, _cell.position)
	# **The ring is sealed here**, before the collapse writes a single frame of
	# itself into it. What the player is offered is the run, not the dying.
	_recorder.seal()
	# The body held open goes with the steering, nothing placed.
	_offer_close(false)
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
	_step_onboarding(delta)
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
			# **The new cell is in the water from the tap**, simulated and
			# edible, so the other player is told where it is from the tap too:
			# in a pond the host only puts a returning guest in the water once
			# a state frame says where it is. Nothing is sent with no session.
			_tell_others()
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
		#
		# **Withheld while the recording holds a pond** (shared-pond.md §5):
		# the ring records the first thirty-four slots and no person, and the
		# replay would bind the live field, which in a pond is still running
		# for the other player. Phase 3 gives it private nodes and 69 slots.
		_watch_ui.visible = _recorder.span() >= WATCH_MIN_SECONDS \
			and not (_ponded or _food.pond_open())
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
	# **A guest whose host has a pond open wakes into it** (owner's row A, UX
	# §4): the tap asks the host where, and the black holds for the round trip.
	if _pond != null and not _pond.hosting and _pond.together() \
			and _net.peer_pond_open():
		_enter_from_black()
		return
	_return(_home_after_black())


## **The return itself**: a new cell at generation 1, at [param place] --
## `[at, heading]`, or empty for wherever the run puts a new cell.
##
## In a pond there is **no reseed** (owner's row A): the pond was never this
## cell's to reset, the other player may be in it, and a returning cell comes
## back into it where the host says, near its friend. Otherwise every line is
## the shipped return, in the shipped order.
func _return(place: Array) -> void:
	# Before anything is rebuilt: the screen is reading the nodes below, and
	# **a run keeps nothing** -- the replay is the last thing this run has and
	# it dies with it.
	_offer_replay(false)
	_life = Life.RETURNING
	_death_clock = 0.0
	var pond := _food.pond_open()
	_cell.reset(pond)
	if not place.is_empty():
		_cell.position = place[0]
		_cell.heading = float(place[1])
	_metabolism.reset()
	_motes.setup(_cell)
	if pond:
		_food.enter_water()
	else:
		_food.setup(_cell)
		_ponded = false
	_genome.setup(_cell)
	_soma.setup(_cell, _genome)
	_forget_eye()
	# A new cell is a born cell, and a born cell has no senses: the five-second
	# clock starts again, and so does the line that announces it. **A run keeps
	# nothing** -- and that has to include the leg-up and the lineage.
	_sense_clock = 0.0
	_sensed = false
	_generation = 1
	_said_divide = false
	_update_simulating()
	_apply_mode()
	# **The steering line comes back with the next cell if it was never read.**
	# A death fades whatever the line was saying (_die), and the steering line
	# is armed once a run: a new player who died before ever turning -- or
	# before the line had even faded in -- would swim the rest of the run
	# untaught. Read once, it is marked seen and never armed again.
	if not _seen_onboarding():
		_begin_onboarding()
	# The host tells a guest its new body here. A guest said so with its ENTER,
	# before the host placed it, so its friend could meet what was arriving.
	if pond and _pond.hosting:
		_pond.person_changed(true)


## **The one place that decides what is simulated**, and it decides from state
## alone: whether this cell is alive, returning, past its pinch, held, inside
## the water's beat or waiting to arrive. Every change to any of those calls
## this, and so does every frame, so no caller turns the simulation on or off
## by itself -- and a death, a hold and a beat can overlap in any order without
## one of them restarting a body another has stopped (shared-pond.md §3). It
## stops the simulation without pausing the tree: the membrane layer and the
## world view both have to keep running through a death, one to draw it and one
## to fade out of it.
##
## **This cell's own nodes** run while it is alive and short of the pinch, or
## returning -- a returning cell is simulated from the tap -- and never in the
## pond's still moments. **The water** runs with them in single player, exactly
## as it always has: a death or a division stops it and a return or a birth
## starts it. In a pond it is not this cell's to stop (§1.5): it runs on for the
## other player through a death or a division, and stops only while the pond is
## held. Through the water's beat it runs from the swap on, whatever the water
## is by then -- the host's, or the fresh one a takeover leaves.
func _update_simulating() -> void:
	var still := _held or _water_beat >= 0.0 or _entering_held
	var cell_on := not still and (_life == Life.RETURNING
		or (_life == Life.ALIVE and _split < Split.PINCH))
	for node: Node in [_cell, _metabolism, _motes, _genome]:
		node.set_process(cell_on)
	_cell.set_process_unhandled_input(cell_on)
	var water_on := cell_on
	if _held:
		water_on = false
	elif _food.pond_open() or (_water_beat >= 0.0 and _beat_swapped):
		water_on = true
	_food.set_process(water_on)


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


# ---------------------------------------------------------------------------
# Where the player's thumbs live. docs/design/controls.md.
#
# The owner asked for "more control options ... a left right joystick and
# buttons. We can choose from the pause menu". Three schemes, one cycling
# button beside `light` and `camera`, and the explanation is that **the controls
# themselves stay drawn behind the pause scrim**, so cycling the word changes
# the corners in front of the player. That costs no string, and today the game
# has exactly one authored sentence.
#
# The scheme that ships is the default and is not touched: under `anywhere`
# nothing is drawn, cell.gd's input path is exactly what it was, and a player
# who never opens pause never sees any of this.
# ---------------------------------------------------------------------------

## The word on the button, and the whole of the chooser's vocabulary. Each says
## what is on screen; `anywhere` also states the rule it names.
const SCHEME_WORDS: Array[String] = ["anywhere", "stick", "pads"]


## **No confirmation and no apply.** Cycling takes effect immediately and
## `RunState` writes it, so the corners under the scrim are the preview and the
## preview is the game.
func _cycle_scheme() -> void:
	scheme = (scheme + 1) % SCHEME_WORDS.size()
	_controls.set_scheme(scheme)
	RunState.save_scheme(scheme)
	_update_scheme_button()
	_update_controls()
	# A finger still down when the scheme changed is not steering the new one.
	_cell.release()
	_controls.let_go()
	# **The drawn control is the onboarding**, so the authored line is not shown
	# under the two schemes that have one. `RunState`'s seen-flag is untouched:
	# a player who switches back to `anywhere` still gets it if they never had
	# it.
	if _onboard_steer and _onboard != Onboard.OFF and not _floating():
		_onboarding.hide()
		_onboard = Onboard.OFF


func _update_scheme_button() -> void:
	_feel_button.text = SCHEME_WORDS[clampi(scheme, 0, SCHEME_WORDS.size() - 1)]


## True while the water itself is the control. The one test anything outside
## controls.gd makes about the scheme.
func _floating() -> bool:
	return scheme == RunState.Scheme.ANYWHERE


## What is drawn in the corners this frame.
##
## **The controls are a readout of the genome** (`gene-lines-and-the-pause-target.md`
## §4.1): a pad exists only when the organ that works it does, so a newborn on
## `pads` has two controls and grows into four. Positions never move, so growing
## a gene adds a control and never relocates one.
##
## **Only the two action pads go at the pinch**, and the steering control stays
## for the whole division. A first build hid everything from `QUICKEN` to `PART`
## and took steering away from a cell that was still swimming -- `QUICKEN` is
## still simulating -- and a target that vanishes from under a thumb and returns
## 1.5 s later is a target the player has to find twice at the one beat in a run
## that cannot be replayed.
func _update_controls() -> void:
	# The pond's still moments behave as a pinch does (UX §0.5, §5): the
	# steering control stays drawn and dead, and the action pads go.
	_controls.update(not _floating() and _life == Life.ALIVE,
		_split >= Split.PINCH or _held or _water_beat >= 0.0 or _entering_held,
		_cell.extra(&"axoneme") > 0, _cell.extra(&"myoneme") > 0)


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
	# **The drawn control is the onboarding.** Under `stick` and `pads` there is
	# a picture in the corner saying what the sentence would have said, and the
	# game keeps its one authored line. The seen-flag is deliberately not
	# marked: a player who switches to `anywhere` later still gets it.
	if not _floating():
		_onboarding.hide()
		_onboard = Onboard.OFF
		return
	_onboard_steer = true
	_onboarding.text = "drag to turn" if _touch_first() else "A · D to turn"
	_onboarding.show()
	_onboard = Onboard.WAITING
	_onboard_clock = 0.0


## **A sense arrived, and here is where to put it.** The line names the quick
## way (dna-body.md §8) -- hold your own body on the one touch platform we
## ship, hold `E` everywhere else -- and it is there whenever this is said: the
## grant comes with a free slot of its own. The gesture places the gene the
## body is showing, which is the sense unless an earlier meal is still waiting
## ahead of it. Back and Escape still open the pause screen, the one place a
## gene can be written over another. Owner's call 4.
func _say_sense() -> void:
	_say("a sense grew · hold your body to place it" if _touch_first()
		else "a sense grew · hold e to place it", SENSE_LINE_HOLD)


## Puts [param text] on the line and fades it in from wherever the line already
## is, so a notice arriving over the steering line is a change of words and not
## a blink. [param hold] is how long it stays once it is up.
func _say(text: String, hold: float) -> void:
	_onboard_steer = false
	_onboard_from = _onboarding.modulate.a
	_onboard_hold = hold
	_onboarding.text = text
	# **Not over the menu** (shared-pond.md §1.7): under B the run goes on with
	# the menu open, and a sense can arrive under it -- rendered, the line stood
	# through the scrim behind `resume`. It is still said, and the menu shows it
	# on closing, as it shows every line a pause hid. Single player says nothing
	# with the menu open, where the tree is paused, so this is `show()` there.
	_onboarding.visible = not _menu_open
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

## **The one breath** (beam-levels.md §8.4): when the beam's fork opens, the
## target goes to its hot state over [constant BREATH_RISE], holds for one
## heartbeat and settles over [constant BREATH_FALL]. It is the only thing in
## the water that points at pause, and the only time it moves on its own -- a
## touch player has no hover, so this is the one time they see the hot state.
## Hot is gene-lines-and-the-pause-target.md §4.3's measured 87 of glance, for
## about two heartbeats and then never again that lineage.
const BREATH_RISE := 0.3
const BREATH_FALL := 1.5
var _pause_breath := Swell.new(BREATH_RISE, 0.0, BREATH_FALL)
## **Owner's call 4** (beam-levels.md §8.9): whether it breathes at all. Off,
## the eye budding is the only sign that pause has something new.
const PAUSE_BREATHES_AT_FORK := true
## The in-between states, one stylebox each, recoloured as it breathes.
var _pause_well_breath: StyleBoxFlat = null
var _pause_bar_breath: StyleBoxFlat = null

func _update_pause_tap() -> void:
	# **Hidden wherever pause cannot be reached**, which is not a nicety: a
	# control that is drawn and does nothing teaches the player that tapping it
	# does nothing. Pause is refused during a division (the choice has no
	# default) and a dead cell's Back is the exit rather than the pause, so
	# neither state gets a button.
	var wanted := _life == Life.ALIVE and _split == Split.NONE \
		and not _menu_open
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
	# Breathing, it is somewhere between the two, on the same four colours.
	var lift := _pause_breath.value()
	if lift > 0.0 and not _pause_hot:
		_pause_well_breath.bg_color = _pause_well_rest.bg_color.lerp(
			_pause_well_hot.bg_color, lift)
		_pause_well_breath.border_color = _pause_well_rest.border_color.lerp(
			_pause_well_hot.border_color, lift)
		_pause_bar_breath.bg_color = _pause_bar_rest.bg_color.lerp(
			_pause_bar_hot.bg_color, lift)
		well = _pause_well_breath
		bar = _pause_bar_breath
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
			# The fork's two cards are a screen over the figure, and Back shuts
			# the top one: the view, and only the view.
			elif _fork_open():
				_close_fork(true)
			else:
				_toggle_pause()
		NOTIFICATION_DRAG_END:
			# **A drag that ends on nothing is a move that did not happen.**
			# Godot posts this to the whole tree whether the release landed on a
			# drop target or on open screen, so the one place the lifted gene
			# goes back into its slot is here -- and a mis-drag costs exactly
			# what a mis-tap costs, which is nothing. A waiting gene carried out
			# of the tray and let go on nothing stays in hand, unplaced.
			if _dragging != SLOT_NONE:
				# **And a gene let go on nothing, or back where it came from,
				# leaves its slot unarmed when a gene is in hand.** The press
				# that lifted it began a drag, not a first tap, so the slot
				# must not be one tap from the gene in hand writing over it --
				# the rule [method _move_slot] keeps for a move that landed.
				if _dragging >= 0 and _hand() != &"":
					_armed = SLOT_SAMPLE
					_armed_at = Time.get_ticks_msec()
				_dragging = SLOT_NONE
				_redraw_figure()
				_update_explain()
				_update_hint()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Switching apps mid-drag never delivers the release, and a pointer
			# stuck down means a cell that turns forever. Deliberately does not
			# pause: a pause screen nobody asked for is its own bug.
			_cell.release()
			_controls.let_go()
			# The same argument for the genome screen: a finger that left with
			# the app never lifts, so the placement it was holding is abandoned
			# rather than left waiting for a release that cannot come.
			_primed = SLOT_NONE
			# And for the body held open (dna-body.md §8), nothing placed. The
			# emulated mouse's finger goes with it: its release may never come.
			_offer_close(false)
			_mouse_twin = POINTER_NONE
			_mouse_twin_next = false


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
##
## **The gate opens at the pinch, not at PART, and that is the hole §6 left.**
## The pinch is where `_update_simulating()` stops `cell.gd`'s own input, so
## from there to PART -- `DIVIDE_PINCH`, a second and a half -- **no node in the
## tree consumed a pointer press at all.** Measured before the change, at
## `--fixed-fps 60`: `--scheme=2 --radius=40 --press=3.0:216,624,0` logged
## `held []  steer +0.00` for the whole run and never committed, while the same
## press at 2.0 s -- one phase earlier, on the cell's own watch -- logged
## `held [starboard#0]  steer +1.00` and committed. The turn pad stayed drawn
## through all of it, which is exactly what §6 promises and exactly what makes
## the hole a defect: a control that is drawn, unlit and inert is the thing
## `gene-lines-and-the-pause-target.md` §4.1 forbids. It recovered on the first
## pixel of movement, so a jittering thumb escaped and a still mouse did not.
##
## Two phases own pointer input and their boundary is the pinch: `cell.gd` up
## to it, this file from it. There is no frame where both are listening and no
## frame where neither is. Claiming drags a phase earlier costs nothing --
## `_choosing` is not visible until PART, so there is no locus in the tree to
## hit-test a drag against yet -- and it buys the other half of the same hole,
## which is the worse half. **A release that arrived during the pinch was
## nobody's either.** Measured: a turn pad pressed at 2.0 s and let go at 3.0 s
## kept its owner, stayed lit, held `steer +1.00` with nothing on the glass, and
## **committed a daughter on a lean the player had already abandoned** -- on a
## screen whose own rule is that releasing early undoes it. Now the lift lands
## where the press does, and neither commits anything on its own.
func _input(event: InputEvent) -> void:
	# **The body held open to place a gene goes first** (dna-body.md §8): it is
	# the one gesture in the playfield that starts on the body, and a pointer it
	# has claimed must reach neither the GUI nor cell.gd. It claims nothing
	# unless a live cell is swimming with a gene waiting and a slot free, so
	# from the pinch on -- everything below -- it is never the one answering.
	if _offer_input(event):
		get_viewport().set_input_as_handled()
		return
	if _replay != null or _split < Split.PINCH or _menu_open:
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
			# **`Esc` shuts the fork view only; a second one resumes** -- the
			# rule dna-body.md §8 set for the body held open, for the same
			# reason: one key, one step back.
			elif _fork_open():
				_close_fork(true)
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
	#
	# **From the pinch, not from PART.** The pinch is where the cell's own input
	# stops, and until this matched it there was a second and a half in which a
	# press reached nothing -- with the turn pads still drawn in the corner. See
	# [method _input] for the measurement. A press landing here during the pinch
	# does the same two things it does at PART: a drawn control claims it, or the
	# screen half remembers where it was. Neither is read until `CHOOSING` asks,
	# so arriving early only means the answer is ready when the question is.
	if _split >= Split.PINCH and _read_touch_lean(event):
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
	if _menu_open or not (event is InputEventKey):
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
			# The drawn controls own the corners for the whole division. A
			# finger they claim never reaches the screen half, which is the
			# point: under `stick` it would be reading the wrong side.
			if _controls.press(touch.index, touch.position) != _controls.NONE:
				return true
			if _touch_index == -2:
				_touch_index = touch.index
				_touch_lean = _lean_at(touch.position)
			return true
		# **`release()` is not a test, it lets the control go**, so it runs on
		# every lift before anything decides what that lift meant. Named rather
		# than left as an `elif` condition: a chain whose test does the work is
		# one reordering away from a pad that can never be released, and nothing
		# about the line says so.
		#
		# Typed rather than inferred: `_controls` is a `Control` and `release`
		# is controls.gd's, so the call is dynamic and the comparison has no
		# static type for `:=` to take.
		var released_a_control: bool = \
			_controls.release(touch.index) != _controls.NONE
		if not released_a_control and _touch_index == touch.index:
			_touch_index = -2
			_touch_lean = 0.0
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _controls.move(drag.index, drag.position):
			return true
		# **A thumb already down is adopted**, here as much as below: its press
		# happened during the quickening, before this screen was listening, so
		# the only event it will ever produce is a drag. Steering controls only
		# -- `push` and `dash` are not leans.
		#
		# **And only a thumb this screen never saw press.** `_choose_gesture`
		# holds every pointer that went down from the pinch onward, so a lean
		# begun in open water and slid into the corner keeps its screen half
		# rather than being taken over by the control it passed across -- the
		# same rule the strand blocks already obey in the other direction.
		if not _choose_gesture.has(drag.index) \
				and _controls.adopt(drag.index, drag.position) \
					!= _controls.NONE:
			return true
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
			if _controls.press(POINTER_MOUSE, click.position) != _controls.NONE:
				return true
			if _touch_index == -2:
				_touch_index = -1
				_touch_lean = _lean_at(click.position)
			return true
		# The same release, named for the same reason. See the touch branch.
		var released_a_control: bool = \
			_controls.release(POINTER_MOUSE) != _controls.NONE
		if not released_a_control and _touch_index == -1:
			_touch_index = -2
			_touch_lean = 0.0
		return true
	if event is InputEventMouseMotion:
		var moved := event as InputEventMouseMotion
		if _controls.move(POINTER_MOUSE, moved.position):
			return true
		# The same adoption, and the same refusal, for a button that went down
		# before there was anything to press it at.
		if (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 \
				and not _choose_gesture.has(POINTER_MOUSE) \
				and _controls.adopt(POINTER_MOUSE, moved.position) \
					!= _controls.NONE:
			return true
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
	_set_menu(not _menu_open)


## **The menu, open or shut.** [method _toggle_pause] is the player's way here,
## latched to one toggle a frame; a death, a division and a takeover close it
## directly.
##
## **Owner's B: in a session the menu stops nothing** (shared-pond.md §1.7).
## The tree is never paused while a session is up, on either seat -- the host's
## water has to keep running to take a dead friend back, and a guest's paused
## tree would stop its own reports -- so the menu opens over a live water: the
## cell is let go and drifts, it can be eaten, hunger burns. What stops is the
## cell's own steering, because the arrows are moving menu focus. With no
## session up, this is the shipped pause exactly.
func _set_menu(open: bool) -> void:
	# **The body held open shuts first** (dna-body.md §8), nothing placed, and
	# before this function decides what `steering_off` is: the `E` key holds
	# the flag while it has the body, and handing it back after the lines below
	# had set it would undo a pond's deaf menu.
	_offer_close(false)
	var paused := open
	_menu_open = open
	var live := _session_up()
	var deaf := open and live
	if deaf or _cell.steering_off:
		# Flipped both ways, and let go both ways -- the pair the pause screen
		# and a lost focus already call: `steering_off` silences what the cell
		# does with a pointer, not whether it takes one (cell.gd), so a finger
		# already down would steer the moment the flag cleared. Checked on the
		# flag rather than on the session, so a menu opened in a pond and shut
		# after the pond has gone still gives the cell its steering back.
		_cell.steering_off = deaf
		_cell.release()
		_controls.let_go()
	if live:
		if get_tree().paused:
			get_tree().paused = false
	else:
		get_tree().paused = paused
	_pause_ui.visible = paused
	_update_warn()
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
	# centred and so is the self-figure, so the light slider's track once ran
	# straight through the cell's own cilia -- the exact failure that took the
	# world view down to a ghost behind SCRIM_FULL_VISION -- and today the
	# figure would land in the ring's empty cell, a second body beside the one
	# the screen draws. The membrane stays, because it is the live preview of
	# the slider; the body and the line are not, and the body drawn on this
	# screen is a better mirror than either. Rendered.
	_show_self(not paused and not _vision_active() and _life == Life.ALIVE)
	_onboarding.visible = not paused and _onboard != Onboard.OFF
	if paused:
		# A finger still down when the pause opened must not keep steering.
		_cell.release()
		# Both halves: the free drag under `anywhere`, and every finger on a
		# drawn control under the other two. The controls stay *drawn* behind
		# the scrim -- that is the chooser's own explanation -- and they are
		# dead to input there, because the `Cell` node is PAUSABLE and this run
		# is only awake to hear Esc and Back.
		_controls.let_go()
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
		#
		# **The column is shaped round the ghost now as well** (dna-body.md §7):
		# with the settings on the left, the one cell of the ring with no slot
		# in it sits over the middle of the screen, so what shows through the
		# scrim there is the cell itself, faintly, in the one place nothing is
		# drawn on top of it.
		#
		# **Under B the water is what they came to read** (UX §6): a hunter can
		# reach this cell with the menu up, so full vision keeps it legible.
		_scrim.color = (SCRIM_POND if live else SCRIM_FULL_VISION) \
			if _vision_active() else SCRIM_POV
		# Built on opening rather than kept in step: the genome cannot change
		# while the tree is paused except by the placements and moves this
		# screen makes itself, and a figure rebuilt sixty times a second to say
		# the same thing is a dozen nodes of churn a frame for nothing.
		# Nothing can be in the air on a screen that was not open, and a stale
		# source slot would draw a hole in the figure.
		_dragging = SLOT_NONE
		_primed = SLOT_NONE
		# The tray's held height is let go here and only here: it never shrinks
		# while the screen is open. See [method _latch_tray].
		_tray.custom_minimum_size.y = WAIT_SIZE.y
		# Every opening starts on the figure: a fork view left open last time
		# is a question from another moment.
		_reset_fork_view()
		_select_default()
		_build_genome_strip()
		_resume_button.grab_focus()
		# **Owner's call 3** (beam-levels.md §8.9): the figure, with the forking
		# slot selected, is what pause opens on. The other answer is this.
		if PAUSE_OPENS_ON_CARDS and _hand() == &"" and not _strip_forks.is_empty():
			_open_fork(_strip_forks[0], false)
	else:
		_reset_fork_view()
		RunState.save_gain(_bus.gain)


## Back one step, to the view chooser. The launcher is one more Back from
## there, which keeps the whole stack reachable by the same gesture.
func _leave() -> void:
	get_tree().paused = false
	_menu_open = false
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
## in it -- and with a seven-locus strand above them that was 800px. Rendered,
## and it looked wrong; at 232 they stay the buttons Phase 4 shipped whatever is
## beside them, and the column they share now is exactly that wide.
func _style_pause() -> void:
	for control: Control in [_light_panel, _view_panel, _feel_panel,
			_resume_button, _leave_button]:
		control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# **Every group on the pause column is a surface, and `light` was the one
	# that was not.** `resume` and `leave` are slabs, the figure is a drawn
	# object of its own, and the light caption and its track were bare strokes
	# floating on the water -- which is why they were the pair the player's own
	# cell tangled with. Same slab, same border, same radius -- but fainter than
	# a button on purpose, because it is a surface and not a third thing to
	# press. One rule a later screen can apply without asking: every group on
	# this column is a surface.
	_light_panel.add_theme_stylebox_override("panel", _slab(-0.2))
	# Same slab, same rule: every group on this column is a surface.
	for panel: PanelContainer in [_view_panel, _feel_panel]:
		panel.add_theme_stylebox_override("panel", _slab(-0.2))
	for caption: Label in [_view_caption, _feel_caption]:
		caption.add_theme_font_size_override("font_size", 16)
		caption.add_theme_color_override("font_color",
			Color(0.855, 0.953, 0.933, 0.52))

	# The tray's `waiting` wears the same, so the genome's two captions are one
	# voice. See [method _make_tray_caption].
	_genome_caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	_genome_caption.add_theme_color_override("font_color", CAPTION_TINT)
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
	_pause_well_breath = _well(0.13, 0.09)
	_pause_bar_breath = _bar(PAUSE_REST)

	# The camera toggle and the control-scheme toggle are buttons, so they are
	# styled like ones -- but narrower and shorter than `resume`, because they
	# are settings inside a surface and not things that end the run. Still 48
	# tall, which is the touch rule. **One loop over both**, because they are
	# the same kind of thing and a second copy is how two settings drift apart.
	for toggle: Button in [_view_button, _feel_button]:
		toggle.custom_minimum_size = Vector2(192.0, 48.0)
		toggle.focus_mode = Control.FOCUS_ALL
		toggle.add_theme_font_size_override("font_size", 16)
		for state: String in ["font_color", "font_hover_color",
				"font_focus_color", "font_pressed_color"]:
			toggle.add_theme_color_override(state,
				Color(0.855, 0.953, 0.933, 0.92))
		toggle.add_theme_stylebox_override("normal", _slab(0.0))
		toggle.add_theme_stylebox_override("hover", _slab(0.35))
		toggle.add_theme_stylebox_override("pressed", _slab(0.5))
		toggle.add_theme_stylebox_override("focus", _slab(0.35))

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
# The body and its slots, on the pause screen. docs/design/dna-body.md.
#
# **The owner could not read which part of the body an arrow meant, so the
# screen draws the body and puts each slot beside the part it is.** The slot is
# the arc, and the arc is a place on a body the player has been looking at for
# the whole run -- so reading a slot is pointing at it rather than decoding a
# bearing. The figure is the water's own drawing, `Cilia.draw_cell`, nose up and
# still: no second drawing of a cell exists anywhere, and this is not one. Every
# channel the strand carried has a place, and most of them are more literal
# than the place they had:
#
#   which arc         where the chip sits on the 3 x 3 ring, and the faint
#                     tether from it to its arc on the skin
#   the plain word    under the chip's own three-lobe piece of helix
#   the copies        rungs, as on the strand: they are the picture -- and
#                     three pips after the word, which are the reading: a
#                     disc for a copy this body wears, a ring for a copy only
#                     the DNA carries, a dot for room to grow
#   the level         a numeral in the helix's third lobe, for a gene that
#                     levels; its strands part while its fork waits
#                     (beam-levels.md §8)
#   the two registers the drawing is the body and the chips are the DNA; where
#                     the two disagree at an arc, the body names what it wears
#   the selection     the lens fills, the word goes loud, and the arc lights on
#                     the skin -- the owner's sentence answered on the body
#   waiting genes     a tray above the figure, soonest to lapse first, one of
#                     them in hand; the two taps place it, as they always have
#
# **A launcher-themed surface, not the membrane aesthetic.** The membrane is
# what the cell feels; this is what the player consults. It lives on pause
# because pause already has widgets, already has the house style and is already
# reachable by a gesture the player knows.
# ---------------------------------------------------------------------------

## The figure's own box, and where the body sits in it. **Set in code, as the
## choosing screen's column is**: every seat below is measured from
## [constant FIGURE_AT], and a `.tscn` cannot add. The scene carries the same
## size so the tree reads right in an editor; this is what binds.
const FIGURE_SIZE := Vector2(420.0, 372.0)
const FIGURE_AT := Vector2(210.0, 170.0)
## **A fixed radius, not the cell's.** Drawn at the cell's own size the ring of
## slots would move between two pauses as the body grew, and growth is already
## said by the slots that light up. Sixty is what the worst body the game can
## make -- every born organ and four earned ones at level 3 -- leaves room
## around: the mouth's bow clears the nose row by 9 px, the flank oars by 17,
## the tail by 21 (dna-body.md §2).
const FIGURE_R := 60.0
## A mirror is read, so it is drawn nearly whole: quieter than the chips beside
## it, and far louder than the water behind the scrim.
const FIGURE_FADE := 0.85
## One slot, and the whole of its touch target: 144 x 84 device px at
## 2400x1080. Neighbours are 54 px apart across and 82 and 112 down.
const SLOT_SIZE := Vector2(96.0, 56.0)
## Chip centres from the body's centre, by slot index. **A 3 x 3 ring, not a
## circle at true bearings**: words are horizontal, rows and columns give the
## arrow keys a meaning, and every chip still sits within 5.3 degrees of its
## arc's true bearing -- the forward diagonals at 47.4 against 42.1, the rear
## ones at 138.2 against 133.3, the flank at 90 against 92.5.
##
## **There is no port-flank seat, and the empty cell says so.** Slot 1 is the
## flank pair: the cirrus wears both flanks, anything else the starboard one
## (cilia.gd). The hole is truthful, and it has a job: see [member _light_panel].
const SLOT_SEAT: Array[Vector2] = [
	Vector2(0.0, -138.0),     # 0 nose
	Vector2(150.0, 0.0),      # 1 starboard flank
	Vector2(0.0, 168.0),      # 2 tail
	Vector2(150.0, -138.0),   # 3 forward starboard
	Vector2(-150.0, -138.0),  # 4 forward port
	Vector2(150.0, 168.0),    # 5 rear starboard
	Vector2(-150.0, 168.0),   # 6 rear port
]
## Where a plain arrow takes the keyboard, and where `Shift` and that arrow take
## the gene, from each slot: `[left, up, right, down]`, -1 for nothing that way.
## **One table for both**, so the key that looks at a slot is the key that moves
## a gene into it. Down from the nose crosses the body to the tail -- down the
## body is down the screen -- and nothing wraps: a gene that left one edge of
## the ring and came back in at the other would land on an arc nobody aimed at,
## which is the strand's clamp argument in two dimensions.
const SLOT_NEIGHBOUR: Array = [
	[4, -1, 3, 2],    # 0 nose
	[-1, 3, -1, 5],   # 1 starboard flank
	[6, 0, 5, -1],    # 2 tail
	[0, -1, -1, 1],   # 3 forward starboard
	[-1, -1, 0, 6],   # 4 forward port
	[2, 1, -1, -1],   # 5 rear starboard
	[-1, 4, 2, -1],   # 6 rear port
]
## The four sides of [constant SLOT_NEIGHBOUR], in its order, as Godot names
## them for a focus neighbour.
const NEIGHBOUR_SIDES: Array = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
## Tab order: clockwise round the body from the nose, and then on to `light`.
const SLOT_RING: Array[int] = [0, 3, 1, 5, 2, 6, 4]

## **A tether per live slot**, from the chip's edge to the middle of its arc on
## the skin, drawn under the body so the body wins wherever the two cross. It is
## what makes a diagonal exact -- rendered without, a corner chip is only an
## approximation of an arc -- and it is the line the body's own word sits on
## (dna-body.md §4). A thread and not a leader line: 1.2 px at 0.16, in the
## slot's hue, and bowed, because a ruled line would be the one piece of chart
## furniture on a surface that has none.
const TETHER_WIDTH := 1.2
const TETHER_ALPHA := 0.16
const TETHER_BOW := 0.06
## How far off the skin a tether stops, and how far inside the chip's box it
## starts, so it ends clear of the fringe and begins clear of the chip's word.
const TETHER_LIFT := 4.0
const TETHER_INSET := Vector2(10.0, 4.0)
## **The part being read lights up on the body**: the arc of the selected,
## hovered, armed or drop-target slot, traced on the skin in the hue of whatever
## would be there -- the gene in hand while a slot is armed, the travelling gene
## while one is dragged. The owner's sentence, answered on the body itself.
const ARC_MARK_WIDTH := 3.0
const ARC_MARK_LIFT := 5.0
const ARC_MARK_ALPHA := 0.85
const ARC_MARK_STEPS := 12
## **Where the body wears a different organ from the gene its slot now carries,
## the body names it**: that organ's own word, in its own hue, on the tether
## this far out from the skin. The word is needed and a render proved it -- a
## newborn whose forward-starboard slot holds `sting` while her body wears
## `beam` there draws two violet, three-stroke organs, and without the word the
## figure cannot say which one that is (dna-body.md §4). `moving-a-gene.md`
## §2.3's rule, a word only where the two registers disagree, moved from a
## second strand onto the body it describes.
const DISSENT_ALONG := 0.56
const DISSENT_SIZE := 12
const DISSENT_ALPHA := 0.92

## A slot's own piece of helix, inside its 96 x 56 box: three lobes of 28 px,
## from x 6 to 90, the middle one the slot. **An odd count, for the strand's
## reason** -- it begins and ends at a crossing and is widest in the middle, so
## the rungs sit where the backbones are furthest apart. 28 against 22 of swing
## is a 1.27:1 lens, between the choosing screen's 1.33 and the old strand's
## 0.89: it still reads as DNA at a third of the strand's height.
const CHIP_LOBE := 28.0
const CHIP_LOBES := 3
const CHIP_X := 6.0
const CHIP_MID := 19.0
const CHIP_AMP := 11.0
## The word's baseline, and its size -- one up from the strand's 13, because a
## chip is read on its own rather than along a row of neighbours.
const CHIP_BASE := 50.0
const CHIP_WORD := 14
## **The copies are three pips**, after the word, at its x-height. Built three
## ways on one frame (dna-body.md §3.1): seats for three rungs inside the helix
## read as grit at a 28 px lobe, and a digit has no scale -- two of what? -- and
## cannot say worn against carried. Three marks are read without counting, the
## scale is on screen, and filled against hollow is diegetic-hud.md §1's
## integrated against held: the same shape meaning the same thing in the water
## and here, which is shape and so survives greyscale. A gene's *level* is a
## different number and never sits in this row (beam-levels.md §8.1).
##
## **The rungs stay.** They are the same count, and they are what makes a slot a
## piece of DNA rather than a label. The rungs are the picture; the pips are the
## reading.
const PIP_R := 3.4
const PIP_PITCH := 10.0
const PIP_GAP := 7.0
const PIP_LIFT := 4.6
const PIP_RING := 1.4
## Room to grow, as a dot too faint to count as a copy -- which is what puts the
## whole scale on screen whatever the copy count is.
const PIP_ROOM_R := 1.6
const PIP_ROOM_ALPHA := 0.30

## **The level, on its slot** (beam-levels.md §8.1): a numeral for a gene that
## levels, which today is only the beam. Every other chip draws what it always
## drew.
##
## **Owner's call 2** (§8.9): where it sits. `LOBE`, recommended, puts it inside
## the third lobe of the chip's helix, the one right of the rungs -- empty on
## every chip, crossed by no tether, and truthful, because the level is
## inherited with the gene, which is what the strand draws. `AFTER_PIPS` is the
## built-and-rejected `M03`: `beam ●•• 12` reads as a count of the dots, and
## `venom` with two digits is 101 px on a 96 px chip. `NONE` leaves the level to
## the line under the figure.
enum LevelSeat { LOBE, AFTER_PIPS, NONE }
const LEVEL_SEAT := LevelSeat.LOBE
## The numeral: the Hud's own font at 12 px, and 10 from level 100 up -- about
## eighty hours of use, so a guard rather than a case. Digits are tabular, 7 px
## each at 12, so `99` is 14 px and fits the widest chip the game makes with
## 2.6 px to spare inside the lobe's backbones.
const LEVEL_SIZE := 12
const LEVEL_SIZE_SMALL := 10
const LEVEL_SMALL_FROM := 100
## Centred on the third lobe, `CHIP_X + 2.5 lobes`, on a baseline that puts
## the digits' ink across the middle of the lens.
const LEVEL_X := CHIP_X + 2.5 * CHIP_LOBE
const LEVEL_BASE := 23.5
## At an open fork the numeral moves into the fork's mouth, and takes the hue.
const LEVEL_FORK_X := 81.0
const LEVEL_FORK_ALPHA := 0.95
## `AFTER_PIPS` only: the gap between the last pip and the numeral.
const LEVEL_AFTER_GAP := 6.0

## **The fork on the slot** (§8.3): lobes 0 and 1 as ever, and then the helix
## stops halfway through its third and its strands part, like a replication
## fork. The weave runs on from `along` 56 to the crest at 70, and from there
## to [constant FORK_TIPS] each strand swings a further [constant FORK_SPREAD]
## as the square of the way out. The tips land at chip x 94, y 1.5 and 36.5 --
## inside the box. The outline changes, not only the colour, so it survives
## greyscale.
const FORK_FROM := 2.0 * CHIP_LOBE
const FORK_TIPS := 88.0
const FORK_SPREAD := 6.5
## **A slot the body has not earned yet** is its helix at this brightness and
## nothing else: no rungs, no word, no tether, no focus and no input. Only the
## first generation shows any -- a daughter inherits a seven-long layout, so
## hers are all live -- and that is exactly when *your body will grow a slot
## here* is news. Empty (bright, live) and unearned (faint, dead) read apart at
## both shapes.
const UNEARNED_INK := 0.32

## **The backbone, the depth alpha, the rung states and the segment count all
## live in `cilia.gd`**, because the division's choosing screen draws the same
## helix on its side and two copies of a drawing drift apart. See
## `Cilia.STRAND_*` and choosing.md §9.1; what stays here is this surface's own
## geometry, which is the only thing the two screens disagree about.
##
## The selected slot's own stretch of backbone, brighter.
const BACKBONE_LIT := 1.25

## The lens between the backbones, filled on the selected slot. Area, not a
## border -- there is no box to put a border on, and a filled lens is the one
## mark that cannot be confused with a rung.
const LENS_SELECTED := 0.20
## A chip's lens is a third the size of the choosing screen's, and needs a
## little more fill to read as selected at all.
const CHIP_LENS := LENS_SELECTED + 0.08
## An empty slot has no gene, so its selection and its tether are the column's
## own pale tint.
const PALE := Color(0.855, 0.953, 0.933)

## **A waiting gene: a base pair that is not in a ladder yet.** A bar with a
## base at each end -- in the tray, and riding a finger across the figure.
const SAMPLE_BAR := 15.0
const SAMPLE_WIDTH := 2.6
const SAMPLE_CAP := 2.5
const SAMPLE_GAP := 6.0    ## between the bar and its word
const SAMPLE_WORD := 13
## Two rings, not a disc: a crisp-edged disc of even tone is the silhouette of a
## widget, which diegetic-hud.md §2 spent three passes establishing.
const SAMPLE_HALO: Array[float] = [9.0, 13.5]
const SAMPLE_HALO_ALPHA: Array[float] = [0.11, 0.05]
## The travelling gene's own box: the width of a chip, and the height of the
## band the strand once reserved for it.
const SAMPLE_BOX := Vector2(96.0, 26.0)

## How far above the pointer the travelling gene rides during a drag.
##
## **Above the finger, not under it.** A fingertip is about 9 mm, which at
## 2400x1080 is roughly 100 canvas units -- a whole chip -- so a preview centred
## on the pointer and a lens filling beneath it are both under the thumb on a
## phone. 34 px lifts the base pair clear of a 56 px chip being pressed from its
## middle. It is drawn because a mouse can see it; the `Act` line is what a
## thumb reads.
const DRAG_LIFT := 34.0

## **The tray above the figure: every gene waiting for a slot, head first**
## (dna-body.md §5), soonest to lapse first -- #118's order. A tray chip is the
## gene's loose base pair, its word and its level as ring pips, because a
## waiting gene is carried by definition: `sting` eaten twice reads two rings
## and a dot, and lands at two.
##
## 48 tall is the touch rule and 116 wide fits the longest word with its pips
## and air either side. **Four fit on a row beside the caption and a fifth
## wraps**: the tray is 560 wide, and five genes at once have been posed and
## still fit the column with 58 px to spare above and below.
const WAIT_SIZE := Vector2(116.0, 48.0)
const WAIT_BAR_X := 16.0
const WAIT_WORD_X := 32.0
## The air right of a chip's last pip: what `venom`, the widest word, leaves at
## 116. A gene this build has no word for is read by its own name, and a name is
## wider than any word -- `statocyst`'s reaches 128 with its pips -- so its chip
## grows to keep this much rather than land its pips on the next chip. See
## [method _waiting_width].
const WAIT_AIR := 3.0
## Every gene not in hand is drawn down to this; the one in hand goes loud and
## gains an underline in its own hue.
const WAIT_DIM := 0.55
## The tray's caption, in the voice of every other caption on this column.
const WAIT_CAPTION := "waiting"
const CAPTION_TINT := Color(0.855, 0.953, 0.933, 0.45)
const CAPTION_SIZE := 15

## **A fork waits with the genes** (beam-levels.md §8.3): one chip per open
## fork, after the waiting genes, because the tray is where this screen keeps
## what waits for the player. It is [constant WAIT_SIZE], and it **neither drags
## nor takes a drop**: it opens the fork's two cards. Its glyph is the slot's
## fork -- a lobe, a half and the parting, `along` 28 to 88 -- at half size, its
## axis on the base pairs' line.
const FORK_GLYPH_FROM := CHIP_LOBE
const FORK_GLYPH_SCALE := 0.5
const FORK_GLYPH_AT := Vector2(7.0, 22.0)
## The gene's word and its level after it, in the level's hue.
const FORK_WORD_X := 44.0
const FORK_WORD_BASE := 27.0
const FORK_LEVEL_GAP := 6.0
## While its cards are up, the chip carries the gene-in-hand mark.
const FORK_OPEN_Y := 45.0

## The strand's dart, sized for the choosing screen, which still draws one under
## each locus (dna-body.md §9).
const DART_R := 6.5
## The second tap cannot land sooner than this after the first, so a double-tap
## -- or the mouse event Godot emulates from a touch -- cannot commit.
const ARM_GUARD_MS := 300
## Arming lapses on its own, so a slot left armed is not a trap.
const ARM_TIMEOUT_MS := 4000

## **What the hint says: how likely the selected slot is to reach a daughter.**
## Eating a gene writes it into the DNA; a daughter is a roll against that DNA,
## and copy number is the odds -- so the one line under the figure is where the
## pips are put into words. It is said *before* the division, on the surface the
## player is already reading, which is the whole of "the chance must be legible
## before, not announced after". The pips draw the level; this line says why it
## matters, which is the owner's call 2 (dna-body.md §13).
const HINT_CHANCE: Array[String] = [
	"",
	"one copy · a daughter may not wear it",
	"two copies · a daughter probably wears it",
	"three copies · a daughter always wears it",
]
## The mouth is the one gene that always expresses (genome.gd's
## ALWAYS_EXPRESSED), so it says so instead of quoting odds it does not obey.
const HINT_CERTAIN := "the mouth · a daughter always wears it"
## The choosing screen reads this one as well, under an empty locus of its own.
const HINT_EMPTY := "an empty slot · nothing to pass on from here"
## **Armed over a gene, the hint says what the next tap costs** instead of what
## the gene is worth. Reading *a daughter always wears it* about the gene the
## tap is about to erase was the wrong sentence at the worst moment
## (dna-body.md §6). The second clause is only true of an organ this body
## actually wears, so a gene the DNA carries and the body does not says the
## first half and stops.
const HINT_LOSES := "%s leaves your dna · your body keeps it"
const HINT_LOSES_CARRIED := "%s leaves your dna"
## **And over a gene that levels, the warning names the level** (beam-levels.md
## §8.2). The body keeps a gene it wears, level and all, for this life; its
## daughters never get it. At most 355 px.
const HINT_LOSES_LEVEL := "%s leaves your dna · level %d ends with this body"
const HINT_LOSES_LEVEL_CARRIED := "%s leaves your dna · its level %d is lost"

## **The level, in front of the odds** (§8.2): `level 7 ▰▰▱ · two copies · a
## daughter probably wears it`. The level is what a daughter inherits and the
## copies are whether she wears it -- decision 5 of beam-levels.md §0 in one
## line. The banked level, never the one held at the fork.
const HINT_LEVEL := "level %d"
## **A gauge and not a number**, because experience means nothing to a player
## and `progress()` is already a fraction: a 36 x 4 bar at y 9 in its own
## 36 x 20 box, one pixel a thirty-sixth of a level.
const GAUGE_SIZE := Vector2(36.0, 20.0)
const GAUGE_BAR := Rect2(0.0, 9.0, 36.0, 4.0)
const GAUGE_RADIUS := 2
const GAUGE_TRACK := Color(0.855, 0.953, 0.933, 0.14)
const GAUGE_FILL_ALPHA := 0.85
## The row itself: the level, the gauge and the words, centred as one.
const HINT_ROW_SEPARATION := 6
const HINT_ROW_HEIGHT := 20.0

## **The verb line: what you can do about the slot you are reading.**
##
## **"place", not "replace".** Every new gene is a placement decision, and most
## of them land in an empty slot -- the slot is the arc, so which empty one is
## the whole question, and the figure is what answers it. **"your daughters
## wear it", because placing does not change you.** One word of difference, and
## it is the whole of lifecycle.md §1 said on the one surface that can say it.
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
##   it; at 2400x1080 a fingertip is about one whole chip wide, so both of
##   those are under the hand that is making the move. Making the line that
##   says `let go to swap eat and ping` the quietest thing on the column would
##   be quieting the one part of the move that is legible while it happens.
##
## It is empty when the selected slot is empty and nothing is in hand: there is
## nothing to do there, and a line that said so would be an instruction to read
## rather than a thing to act on.
##
## **The queue has no clause here any more**: #118 added `· 2 more after it`
## because the strand could only show the head. The tray is the queue, on
## screen, so the count would be a sentence about a picture directly above it.
const ACT_ARM := "tap a slot · your daughters may wear it"
const ACT_COMMIT := "tap again to place"
## Armed over a gene, the verb names both genes: what the tap writes and what it
## writes over. `tap again to place` alone read as harmless over `eat`.
const ACT_COMMIT_OVER := "tap again to write %s over %s"
## **A waiting gene carried out of the tray** lands on an empty slot when it is
## let go -- nothing is evicted and a move can still take it anywhere, so one
## gesture is enough (owner's call 6). Over a gene it only arms: the drop is the
## first tap, and the eviction still needs the second.
const ACT_DROP := "let go to place %s here"
const ACT_DROP_OVER := "let go, then tap again to place %s over %s"
const ACT_MOVE := "drag it to another slot"
const ACT_CARRY := "%s · let go over a slot to put it there"
const ACT_LAND := "let go to move %s here"
const ACT_SWAP := "let go to swap %s and %s"
## **Letting go where you picked up is a real answer, not a missed drop.** It
## is the first thing a nervous player tries -- lift a gene, think better of
## it, put it back -- and it was silent: the source slot said exactly what open
## water said, so the one gesture whose whole point is *undo this* got no
## acknowledgement at all. The chip already draws the picture (its lens fills
## in the gene's own hue, which is that gene coming home); this is the sentence
## for it, and it fires while the finger is still down, which is when the
## player is still deciding.
const ACT_KEEP := "let go to leave %s where it is"
## **A slot whose fork is open, selected with nothing in hand**: its second tap
## brings up the two ways (beam-levels.md §8.3), and this is the one line that
## says so. It is what pause opens on when a fork waits and no gene does.
const ACT_FORK := "tap again to choose how %s grows"

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
	&"palp": "touch",
	&"myoneme": "dash", &"trichocyst": "sting", &"pellicle": "armor",
	&"toxicyst": "venom", &"plastid": "sun", &"vacuole": "store",
	&"crista": "burn", &"chemocyte": "smell", &"ampulla": "ping",
}

## **One line per gene, and it says what the gene does to the player** -- not
## what the organelle is. Sixteen tiles carrying one word each are enough to
## recognise a gene you already know and not enough to learn one, which is the
## whole of the owner's ask.
##
## The voice is the screen's: lowercase, plain, no jargon, one clause and then
## its consequence. No line names another gene, because a player reading `armor`
## has not necessarily met `cytostome` yet. No line carries a number: levels are
## the pips' job and a line that said "+30%" would be the classic HUD this game
## spent two phases not building.
##
## `that side` in `ocellus` and `trichocyst` is deliberate and it points at the
## arc the slot is tethered to -- the two directional genes are the two whose
## line has to explain why the slot mattered.
##
## **This line is also the one place the biological name reaches the screen, and
## that is a deliberate reading of §8 rather than a breach of it.** The rule §8
## states is that *the slot* wears the plain word, and the argument it gives is
## the glance: four short verbs are parsed at arm's length and nine letters of
## Greek are not, on the surface whose whole job is a quick decision. This line
## is not a glance -- it is read because the player stopped to read it -- so the
## name sits at the head of it and the plain word keeps the slot. §9.1 gives
## every gene two names on purpose; a name no player ever meets is a convention
## for the compiler, and CLAUDE.md's *realism is a tool* is the argument that
## `ampulla` is worth meeting.
const EXPLAINS := {
	&"cytostome": "a wider mouth swallows bigger things whole",
	&"cirrus": "turns you faster, and sooner after you ask",
	&"flagellum": "your tail beats harder, and more often",
	&"stigma": "feels the shadow of anything big, however dark",
	&"ocellus": "a ray out of that side, marking whatever it strikes",
	&"chemocyte": "smells food, strongest where your nose is pointed",
	&"ampulla": "a pulse that answers off everything, not just food",
	&"axoneme": "holding on pushes you, instead of only steering",
	&"palp": "feels what is against you, with no light at all",
	&"myoneme": "tap for a burst of speed, paid for in hunger",
	&"trichocyst": "a dart at whatever closes in on that side",
	&"pellicle": "thicker skin, so bites take less and fewer mouths fit",
	&"toxicyst": "whatever bites you pays, and whatever swallows you dies",
	&"plastid": "makes a little of its own food, so you starve slower",
	&"vacuole": "a bigger tank, so hunger takes longer to reach you",
	&"crista": "burns cleaner, so everything you carry costs less",
}
## **Once a way is taken, the gene's line says which** (beam-levels.md §8.3):
## gene, then path, then what the organ now does -- the pause screen's receipt
## for the choice, and the choosing screen's line for a daughter who inherits
## it. 464 and 446 px with the name in front. A fork still open reads as no
## path yet: the gene's own line above.
const EXPLAINS_PATH := {
	&"ocellus": {
		&"extend": "a fan of rays out of that side, one more every level",
		&"sweep": "three rays sweeping that side, faster every level",
	},
}
## An empty slot has no gene to explain, so it explains the one thing it does
## have: a side of the body. The tether from it is what "this side" refers to,
## and on the choosing screen, which reads this line too, the dart is.
const EXPLAIN_EMPTY := "nothing here yet · an organ here grows on this side"
## Loud enough to be the thing you are reading, quieter than the word on the
## chip: caption 0.45, hint 0.38, slot word 0.66, this 0.62.
const EXPLAIN_TINT := Color(0.855, 0.953, 0.933, 0.62)
## The name is drawn in the gene's own hue, which is the hue of the rungs the
## player just tapped -- that is what ties the line to the slot with no arrow
## and no animation.
const EXPLAIN_NAME_ALPHA := 0.95

const LABEL_TINT := Color(0.855, 0.953, 0.933, 0.66)
const LABEL_TINT_LOUD := Color(0.855, 0.953, 0.933, 0.92)
## The choosing screen's word size. A slot's word is [constant CHIP_WORD].
const LABEL_SIZE := 13
## Focus has to be drawn, and it must not be a box: a slot is a piece of DNA and
## not a square. An underline under the chip says where the keyboard is
## standing without rebuilding the thing that was replaced.
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

## The seven chips, by slot index, as last built; null only before the first
## build.
var _slot_chips: Array[Control] = []
## How many of the seven slots are live: the ones the body has earned, or the
## whole layout a newborn inherits. The rest are drawn and dead.
var _slot_count := 0


## Rebuilds the figure's chips and the tray from the genome as it is right now.
## Cheap and total: seven chips and a tray of a handful, built on opening the
## pause screen, after a placement or a move, and when the genome changes under
## an open screen in a pond.
##
## **Every rebuild frees the control the keyboard was standing on, so every
## rebuild has to hand the keyboard somewhere.** Godot does no focus navigation
## from a null focus: with `gui.key_focus` cleared, Tab does nothing, Enter does
## nothing, and `resume` and `leave` are unreachable until the player finds a
## mouse or presses Esc -- which resumes the run, which is not what they asked
## for. That is a dead pause screen, and it sits on top of the one irreversible
## action in the game.
##
## It lives here rather than at the call sites because there were four of them
## and the first attempt got three. [method _commit_slot] carried its own copy
## and [method _step_arming] did not, three lines apart; measured on a real
## display, arming a locus of the old strand and then simply reading it for four
## seconds killed the keyboard. The tray is a second place for the keyboard to
## stand, so it gets the same treatment.
func _build_genome_strip() -> void:
	# Taken before anything is freed. SLOT_NONE means the keyboard was not on a
	# slot at all, and then nothing here should move it: the player is on
	# `resume`, or on the slider, or on the tray, or is using a thumb and has no
	# focus ring to lose.
	var keeping := _focused_slot()
	# The tray's own, by gene, because the chip it was on is about to be freed
	# and the gene may since have moved in the queue or left it.
	var keeping_gene := _focused_waiting()
	# And a fork chip's, by the gene whose fork it is.
	var keeping_fork := _focused_fork()
	# Every chip about to be freed takes its hover with it, and Godot will not
	# re-enter a control the cursor never left. The selection carries the lines
	# until the mouse moves again, which is the same slot either way.
	_hovered = SLOT_NONE
	# And with it goes any placement waiting on a finger: the control that took
	# that press is about to be freed, so the lift it was waiting for will never
	# arrive here.
	_primed = SLOT_NONE
	for layer: Control in [_figure_slots, _tray]:
		for child in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_slot_genes.clear()
	_strip_waiting = _genome.waiting()
	_strip_forks = _open_forks()

	# **The chips are the DNA**, and the body is the other register -- it is the
	# drawing they sit around. lifecycle.md §3.
	var dna := _genome.dna()
	var body := _genome.tiers()
	# **The layout, not the dictionary.** Slot index is the arc a gene is worn
	# on, and the layout is the only thing that knows about holes -- a genome
	# with the beam in slot 6 and nothing in slots 3 to 5 is a genome the player
	# built on purpose.
	_slot_genes.assign(_genome.layout())

	# maxi, not slots(), so a genome can never be longer than the figure that
	# claims to show it. **A newborn is over capacity and that is intended**: she
	# carries up to seven genes on a body whose slots() is 3, so she may replace
	# but not add until she grows -- and every slot her DNA has is live.
	_slot_count = mini(maxi(_genome.slots(), _slot_genes.size()),
		SLOT_SEAT.size())
	_slot_chips.clear()
	_slot_chips.resize(SLOT_SEAT.size())
	for slot in SLOT_SEAT.size():
		var gene: StringName = _slot_genes[slot] if slot < _slot_genes.size() \
			else &""
		# **A rung answers *do I express this gene at all*, and the figure
		# answers *where*.** `dna-strand.md` §1.2 defines worn against carried as
		# exactly that question, and it stays that question: carried means the
		# roll missed, worn means the body expresses it. Narrowing it to *worn on
		# this arc* put two different facts on one mark once already --
		# `moving-a-gene.md` §2.4 -- and the body drawn in the middle now says
		# where every organ is, with a word wherever that disagrees.
		var chip := _make_slot(gene, int(dna.get(gene, 0)),
			int(body.get(gene, 0)), slot, slot < _slot_count)
		_figure_slots.add_child(chip)
		_slot_chips[slot] = chip
	_wire_focus()

	# **The tray, head first.** Its caption only while something waits: an
	# empty tray is 48 px of nothing, which is what the space above a body
	# with nothing loose in it should be. **A fork waits too** (beam-levels.md
	# §8.3), after the genes, and captions the tray like one.
	if not _strip_waiting.is_empty() or not _strip_forks.is_empty():
		_tray.add_child(_make_tray_caption())
	for gene: StringName in _strip_waiting:
		_tray.add_child(_make_waiting(gene))
	for gene: StringName in _strip_forks:
		_tray.add_child(_make_fork_chip(gene))
	# **The view is held by gene** (dna-body.md §5.1's rule for the hand), so a
	# tray rebuilt under it in a pond keeps it open -- unless the fork it shows
	# is no longer there to choose.
	if _fork_gene != &"" and not _strip_forks.has(_fork_gene):
		_reset_fork_view()
	_show_fork_view()
	_levels_seen = _levels_sign()

	_figure_body.queue_redraw()
	# **The caption carries the generation**, because the hint below the figure
	# carries what a slot is worth to a daughter. It says `genome` because the
	# group is two registers, and only the chips are the DNA.
	_genome_caption.text = "genome · %s" % _generation_text()
	_update_hint()
	_update_explain()
	_restore_focus(keeping)
	_restore_tray_focus(keeping_gene)
	_restore_fork_focus(keeping_fork)


## **The ring's keyboard**: a plain arrow goes where it points, Tab goes round
## clockwise from the nose and then on to `light`, and no arrow leaves the ring.
## Set on every rebuild, because every rebuild makes new chips.
##
## **A direction with no live slot that way points the chip at itself**, which
## Godot takes as *stay here*. Left unset, its geometric search would carry the
## focus off the ring to whatever control happens to lie that way -- and an
## unearned slot would be a hole the arrow fell straight through, which is the
## one thing [constant SLOT_NEIGHBOUR] says a move into it is not.
func _wire_focus() -> void:
	var live: Array[Control] = []
	for slot: int in SLOT_RING:
		if _slot_live(slot):
			live.append(_slot_chips[slot])
	for i in live.size():
		var chip := live[i]
		var slot := int(chip.get_meta(&"slot"))
		for way in NEIGHBOUR_SIDES.size():
			var to := int(SLOT_NEIGHBOUR[slot][way])
			var neighbour: Control = _slot_chips[to] if _slot_live(to) else chip
			chip.set_focus_neighbor(NEIGHBOUR_SIDES[way],
				chip.get_path_to(neighbour))
		chip.focus_next = chip.get_path_to(
			live[i + 1] if i + 1 < live.size() else _gain_slider)
		# The nose's previous is left to the tree: the last waiting gene if
		# there is one, and `leave` if not -- which is where Tab came from.
		if i > 0:
			chip.focus_previous = chip.get_path_to(live[i - 1])
	# And `light` backs into the ring where Tab left it, not at whichever chip
	# happens to be last in the tree.
	if not live.is_empty():
		_gain_slider.focus_previous = _gain_slider.get_path_to(
			live[live.size() - 1])


## True when [param slot] is one of this figure's live slots: earned, or
## inherited. The keys' one test, and a drop's.
func _slot_live(slot: int) -> bool:
	return slot >= 0 and slot < _slot_count and slot < _slot_chips.size() \
		and _slot_chips[slot] != null


## Which slot the keyboard is on, or [constant SLOT_NONE] for "not on a slot".
##
## Read off a meta rather than off the child's position, so a chip carrying its
## own slot number cannot be wrong about it whatever else the layer grows.
func _focused_slot() -> int:
	for child in _figure_slots.get_children():
		var chip := child as Control
		if chip != null and chip.has_focus():
			return int(chip.get_meta(&"slot", SLOT_NONE))
	return SLOT_NONE


## Which waiting gene the keyboard is on, or &"" for "not on the tray".
func _focused_waiting() -> StringName:
	for child in _tray.get_children():
		var chip := child as Control
		if chip != null and chip.has_focus():
			return StringName(chip.get_meta(&"waiting", &""))
	return &""


## Puts the keyboard back on [param slot] after a rebuild.
##
## **Which slot, rather than `resume`, and the distinction is the whole fix.** A
## placement spends the gene in hand, but the slot it landed in is still a slot
## to stand on and still the one being read, and a move sends the keyboard after
## the gene it moved, which is what makes `Shift`+arrow repeatable. Sending them
## to `resume` would answer "can I still use the keyboard" with yes and "am I
## where I was" with no. The `resume` fallback below is what catches a slot that
## no longer exists.
func _restore_focus(slot: int) -> void:
	if slot == SLOT_NONE:
		return
	for child in _figure_slots.get_children():
		var chip := child as Control
		if chip != null and chip.focus_mode == Control.FOCUS_ALL \
				and int(chip.get_meta(&"slot", SLOT_NONE)) == slot:
			chip.grab_focus()
			return
	_resume_button.grab_focus()


## The same for the tray: back onto [param gene] if it still waits, else onto
## the tray's first gene -- it lapsed or was placed, and the tray is where the
## player was -- else onto `resume`.
func _restore_tray_focus(gene: StringName) -> void:
	if gene == &"":
		return
	var first: Control = null
	for child in _tray.get_children():
		var chip := child as Control
		if chip == null or chip.focus_mode != Control.FOCUS_ALL:
			continue
		if StringName(chip.get_meta(&"waiting", &"")) == gene:
			chip.grab_focus()
			return
		if first == null:
			first = chip
	if first != null:
		first.grab_focus()
	else:
		_resume_button.grab_focus()


## **One line, one job**: what the slot being read is worth to a daughter,
## which is the one thing the pips draw and cannot say in words on their own --
## or, armed over a gene, what the next tap costs.
func _update_hint() -> void:
	_update_act()
	# The fork's cards have lines of their own (beam-levels.md §8.3).
	if _fork_open():
		_set_hint(_fork_hint(), _fork_gene)
		return
	var slot := _hovered if _hovered != SLOT_NONE else _armed
	if slot == SLOT_NONE:
		_set_hint("")
		return
	# **The same gene the explanation line is describing**, through the same
	# resolution, because the two rows are read together and a pair that
	# disagrees about its subject is worse than either alone. Posed and it
	# showed once: a gene in the air over an empty locus explained the
	# travelling gene and priced the hole.
	var gene := _reading()
	if gene == &"":
		_set_hint(HINT_EMPTY)
		return
	if slot >= 0 and slot == _armed and _dragging == SLOT_NONE \
			and _hand() != &"" and _gene_at(slot) != &"":
		var under := _gene_at(slot)
		var worn := _genome.tier(under) > 0
		# **A level at stake is named**, and the gauge stays out of it: the
		# line is a warning, and what it warns about is the number.
		var grown := _genome.progression(under)
		if grown != null:
			_set_hint((HINT_LOSES_LEVEL if worn else HINT_LOSES_LEVEL_CARRIED)
				% [_word(under), grown.level()])
		else:
			_set_hint((HINT_LOSES if worn else HINT_LOSES_CARRIED)
				% _word(under))
		return
	if GenomeNode.ALWAYS_EXPRESSED.has(gene):
		_set_hint(HINT_CERTAIN, gene)
		return
	# **[method _copies_of] and never the bare DNA tier**, because a waiting
	# gene is worth the copies it waited with, not none. A slot always carries
	# at least one; a waiting gene has `dna_tier == 0`, which indexes the empty
	# string -- so without this the odds go blank at exactly the moment the
	# player is deciding what a placement is worth.
	_set_hint(HINT_CHANCE[clampi(_copies_of(gene), 0, HINT_CHANCE.size() - 1)],
		gene)


## **The row under the figure, whole** (beam-levels.md §8.2): [param text], and
## -- when [param gene] levels -- its level and its gauge in front of it, the
## three centred as one group. A waiting gene that the body still wears a level
## for shows it too; one that has earned nothing has no progression and shows
## none.
##
## **Alone, the words span the row and centre themselves**, exactly as the
## label they were did before the row existed -- so every screen with no level
## on it lays out to the pixel as it always has. Beside a level they shrink to
## their own width, and the row centres the group.
func _set_hint(text: String, gene: StringName = &"") -> void:
	var grown: Progression = _genome.progression(gene) if gene != &"" else null
	var levelled := grown != null
	_hint_level.visible = levelled
	_hint_gauge.visible = levelled
	_genome_hint.size_flags_horizontal = Control.SIZE_FILL if levelled \
		else Control.SIZE_EXPAND_FILL
	_gauge_gene = gene if levelled else &""
	if not levelled:
		_genome_hint.text = text
		return
	_hint_level.text = HINT_LEVEL % grown.level()
	_hint_gauge.queue_redraw()
	_genome_hint.text = "· " + text if text != "" else ""


## **The verb line**, kept in step with the hint because the two are read
## together and the state they read is the same. It is a separate row for the
## reason gene-lines-and-the-pause-target.md §3 made the explanation one: both
## are wanted at once, and the moment one would have to be chosen over the other
## is the moment the player is about to change their daughters.
func _update_act() -> void:
	# The fork's cards: pick a way, then take it (beam-levels.md §8.3).
	if _fork_open():
		_genome_act.text = ACT_CHOOSE_WAY % _path_title(_way_path(_way_armed)) \
			if _way_armed >= 0 else ACT_PICK_WAY
		return
	# A gene in the air outranks the gene in hand: the line reports the gesture
	# that is actually happening.
	if _dragging != SLOT_NONE:
		# **The one piece of feedback a thumb cannot cover.** The travelling
		# base pair rides above the finger and the lens fills under it; both are
		# within a fingertip of the pointer on a phone. This line is not.
		var flying := _gene_at(_dragging)
		var under := _gene_at(_hovered) if _hovered >= 0 else &""
		if _dragging == SLOT_SAMPLE:
			# Out of the tray: a drop on an empty slot places it, a drop on a
			# gene arms that slot for the second tap.
			if _hovered < 0:
				_genome_act.text = ACT_CARRY % _word(flying)
			elif under == &"":
				_genome_act.text = ACT_DROP % _word(flying)
			else:
				_genome_act.text = ACT_DROP_OVER % [_word(flying), _word(under)]
			return
		if _hovered == _dragging:
			# Back over the slot it came out of: a drop here is refused by
			# [method _slot_can_drop] and the gene simply stays, which is the
			# gesture's own cancel and now says so.
			_genome_act.text = ACT_KEEP % _word(flying)
		elif _hovered >= 0:
			_genome_act.text = ACT_SWAP % [_word(flying), _word(under)] \
				if under != &"" else ACT_LAND % _word(flying)
		else:
			_genome_act.text = ACT_CARRY % _word(flying)
		return
	var hand := _hand()
	if hand != &"":
		# `_armed >= 0` and not `!= SLOT_NONE`: the hand with no slot chosen is
		# selected and not placeable, so it must not promise a second tap that
		# does nothing.
		if _armed < 0:
			_genome_act.text = ACT_ARM
			return
		var under := _gene_at(_armed)
		_genome_act.text = ACT_COMMIT if under == &"" \
			else ACT_COMMIT_OVER % [_word(hand), _word(under)]
		return
	var slot := _hovered if _hovered != SLOT_NONE else _armed
	# **The selected slot's fork is open, so its second tap opens the cards.**
	# Only the selected one: a slot being hovered has not had its first tap.
	if slot >= 0 and slot == _armed and _forks_at(slot):
		_genome_act.text = ACT_FORK % _word(_gene_at(slot))
		return
	_genome_act.text = ACT_MOVE if _movable(slot) else ""


## The plain word a gene is read by on this surface. A gene this build has no
## word for -- a later phase's, arriving over an older binary in a content pack
## -- falls back to its own name rather than to nothing.
func _word(gene: StringName) -> String:
	return String(WORDS.get(gene, String(gene)))


## How many copies [param gene] is read at on this surface: the DNA's for a gene
## it carries, and for a waiting one the copies it will be written with -- eaten
## twice before it was placed, it lands at two (#118). **At least one**: a
## waiting gene has `dna_tier == 0`, which indexes the empty string of the odds
## table, and it is worth a copy the moment it is placed.
func _copies_of(gene: StringName) -> int:
	return maxi(maxi(_genome.dna_tier(gene), _genome.waiting_copies(gene)), 1)


## True when [param slot] is a DNA slot with a gene in it, which is the only
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


## **The gene in hand, if it is still waiting**, and &"" if not. Everything that
## reads the hand reads it through here -- every chip, every line, and the tap
## that places -- so a gene that lapses under an open screen stops being in hand
## everywhere in the same frame it stops being placeable. See [member _in_hand].
func _hand() -> StringName:
	if _in_hand != &"" and _genome.waiting_index(_in_hand) >= 0:
		return _in_hand
	return &""


## True when the hand no longer matches the queue: the gene in hand stopped
## waiting -- it lapsed, or settled on its own -- or nothing was in hand and a
## gene waits now. Either is a new decision, and the head goes in hand, as it
## does when the screen opens. Only a pond reaches this, where the menu stops
## nothing; paused, nothing moves the queue but a placement, which rebuilds for
## itself.
func _hand_lost() -> bool:
	if _in_hand == &"":
		return _genome.held_sample != &""
	return _genome.waiting_index(_in_hand) < 0


## **The answer line: what the selected gene does, in the player's terms.**
##
## Two labels rather than one, because the two halves are different kinds of
## thing and the hue is what says so: the biological name in the gene's own
## colour -- the colour of the rungs the player just tapped, and of the organ on
## their own body -- and then the sentence in the pale tint every other word on
## this column wears.
##
## Hover wins over selection, and only on desktop: a mouse can ask about a slot
## without committing to it, which is the cheapest possible way to read all
## seven. A thumb has no hover, so the tap path is the one that has to work, and
## it is the one that is tested.
##
## **An empty slot with a gene in hand explains the gene in hand.** There is
## nothing in that slot to describe and the gene about to land in it is the
## decision; an *occupied* slot still describes its own gene, because that is
## what a second tap would overwrite and the player should read it first.
func _update_explain() -> void:
	var slot := _hovered if _hovered != SLOT_NONE else _armed
	var gene := _fork_gene if _fork_open() else _reading()
	_explain_gene = gene
	_explain_tier = _copies_of(gene) if gene != &"" else 0
	if _explain_organ != null:
		_explain_organ.queue_redraw()
	# The arc on the skin follows the same reading.
	_figure_body.queue_redraw()
	if gene == &"":
		_explain_name.text = ""
		# Two different silences: no slot chosen says nothing at all; a chosen
		# empty slot still has a side of the body to explain.
		_explain_says.text = "" if slot == SLOT_NONE else EXPLAIN_EMPTY
		return
	_explain_name.text = String(gene)
	_explain_name.add_theme_color_override("font_color",
		Color(Cilia.hue(gene), EXPLAIN_NAME_ALPHA))
	# **The cards keep this line's job** (beam-levels.md §8.3): the gene's own
	# line until a way is hovered or armed, and then that way, by its name.
	var way := _way_reading()
	if _fork_open() and way >= 0:
		_explain_name.text = _path_title(_way_path(way))
		_explain_says.text = "· " + String(PATH_SAYS.get(_way_path(way), ""))
		return
	# A gene this build has no line for -- a later phase's, arriving over an
	# older binary in a content pack -- shows its name and says nothing, rather
	# than showing a bare separator.
	var says := _explains(gene)
	_explain_says.text = "" if says.is_empty() else "· " + says


## **What [param gene] does, in the player's terms**: its line, or -- once its
## fork is behind it -- the line for the way it took (beam-levels.md §8.3). The
## pause screen and the choosing screen both read it, so a daughter reads what
## her mother chose.
func _explains(gene: StringName) -> String:
	var grown := _genome.progression(gene)
	var taken: Dictionary = EXPLAINS_PATH.get(gene, {})
	if grown != null and taken.has(grown.path):
		return String(taken[grown.path])
	return String(EXPLAINS.get(gene, ""))


## **What the three lines under the figure are about**, resolved once.
##
## The slot being read -- hovered first, because a mouse can ask about a slot
## without committing to it -- and then two fallbacks for the two ways a slot
## can be empty while something is still in hand. An **occupied** slot always
## describes its own gene: with a gene in hand that is what a second tap would
## overwrite, and under a gene in the air that is what a drop would displace,
## and either way it should be read before it goes.
func _reading() -> StringName:
	var slot := _hovered if _hovered != SLOT_NONE else _armed
	var gene := _gene_at(slot)
	if gene == &"" and _dragging != SLOT_NONE:
		gene = _gene_at(_dragging)
	if gene == &"":
		gene = _hand()
	return gene


## The gene a selection stands for: the gene in hand, the gene in that slot, or
## &"".
func _gene_at(slot: int) -> StringName:
	if slot == SLOT_SAMPLE:
		return _hand()
	if slot >= 0 and slot < _slot_genes.size():
		return _slot_genes[slot]
	return &""


## True when a second tap on [param slot] would place the gene in hand into it --
## which is the only case that is irreversible, and therefore the only case that
## needs the guard, the timeout and the confirming second tap.
##
## **The gene in hand has to still be waiting**, which [method _hand] asks by
## gene and never by place in the queue -- see [member _in_hand]. **And the
## screen has to still be the genome** ([method _strip_current]): with a queue,
## a *different* gene can lapse under an open menu into the very empty slot a
## tap is confirming, and that tap would write over a gene the player never saw
## there. Either way the tap does nothing, and [method _catch_up] shows what
## changed the first frame no finger is down.
func _committable(slot: int) -> bool:
	return slot >= 0 and _hand() != &"" and _strip_current()


## True while the queue, the DNA's layout and the open forks are what the chips
## and the tray were built from. Always true in single player, where only this
## screen changes them and every change rebuilds. In a pond a fork can open
## under the menu, because the beam earns there (beam-levels.md §2), and then
## the tray has a chip to grow.
func _strip_current() -> bool:
	return _genome.waiting() == _strip_waiting \
		and _genome.layout() == _slot_genes and _open_forks() == _strip_forks


## **The screen catches up with a genome that changed under it** -- only in a
## pond, where the menu stops nothing. A hand that stopped waiting goes back to
## the head, as the screen opening would put it. A slot armed for the hand whose
## own gene changed is disarmed: the arm was a first tap on a different decision
## -- `place into an empty slot` is not `write over ping` -- and the one
## irreversible action must never be a tap away without a first tap on what it
## would actually do. Returns true when the figure needs rebuilding, which the
## caller does, because only the caller knows whether a finger is on a chip.
func _catch_up() -> bool:
	if not _hand_lost() and _strip_current():
		return false
	if _hand_lost():
		_select_default()
		return true
	# A selection with nothing in hand is a reading, not an arm, and stays.
	if _armed >= 0 and _hand() != &"":
		var layout := _genome.layout()
		var there: StringName = layout[_armed] if _armed < layout.size() else &""
		if there != _gene_at(_armed):
			_armed = SLOT_SAMPLE
			_armed_at = Time.get_ticks_msec()
	return true


## What is selected when the pause screen opens, when a placement leaves more
## waiting, and when the gene in hand stops being there.
##
## **Never nothing.** A figure that opens with no line under it would have to
## teach the tap with a line of instructions; one that opens with something lit
## and its sentence underneath has already shown what tapping does, and the
## player's next tap is on a different one. **The head goes in hand**, because
## the soonest to lapse is the decision they came here to make (#118's order);
## **otherwise the first slot whose fork is open** (beam-levels.md §8.3, owner's
## call 3), one tap from its two ways; otherwise the first gene they actually
## carry, which on a born cell is the mouth.
func _select_default() -> void:
	_hovered = SLOT_NONE
	_armed_at = Time.get_ticks_msec()
	_in_hand = _genome.held_sample
	if _in_hand != &"":
		_armed = SLOT_SAMPLE
		return
	_armed = SLOT_NONE
	var layout := _genome.layout()
	for i in layout.size():
		if layout[i] != &"" and _genome.can_choose(layout[i]):
			_armed = i
			return
	for i in layout.size():
		if layout[i] != &"":
			_armed = i
			return


func _generation_text() -> String:
	if _generation >= 1 and _generation <= ORDINALS.size():
		return "%s generation" % ORDINALS[_generation - 1]
	return "generation %d" % _generation


## One chip, seated at its arc: its piece of helix, its copies, its word and its
## level -- and, while the gene in hand is bound for an empty one, that gene as
## it would land.
##
## [param tier] is the DNA's copy count and [param body_tier] is how many of
## those copies this body expressed. The rungs and the pips draw both, which is
## what makes a chip the two registers rather than one. [param live] is false
## for a slot the body has not earned yet: drawn faint, and it takes no input
## and no focus.
func _make_slot(gene: StringName, tier: int, body_tier: int, slot: int,
		live: bool) -> Control:
	var node := Control.new()
	# Named, so a focus path and a harness's `--rects=` both read as what they
	# are. The chip it replaces has already left the tree, so the name is free.
	node.name = "Slot%d" % slot
	node.custom_minimum_size = SLOT_SIZE
	node.size = SLOT_SIZE
	node.position = FIGURE_AT + SLOT_SEAT[slot] - SLOT_SIZE * 0.5
	# Its own slot number, so a rebuild can find the node that replaced it
	# without re-deriving where it was.
	node.set_meta(&"slot", slot)
	if not live:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
		node.draw.connect(_draw_unearned.bind(node))
		return node

	# **Every live slot takes input, gene in hand or not.** Selecting is what the
	# explanation line and the odds line hang off; *committing* is still gated
	# on a gene in hand ([method _committable]), so nothing became easier to do
	# by accident: the one irreversible action in the game needs the same two
	# taps and the same 300 ms guard it always did.
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.focus_mode = Control.FOCUS_ALL
	node.draw.connect(_draw_slot.bind(node, gene, tier, body_tier, slot))
	node.gui_input.connect(_on_slot_input.bind(node, slot))
	node.focus_entered.connect(node.queue_redraw)
	node.focus_exited.connect(node.queue_redraw)
	# Hover moves the lines below the figure and the arc on the body; it
	# deliberately does not light the chip and deliberately does not rebuild. A
	# chip that lit under the cursor would promise a tap it has not been given.
	node.mouse_entered.connect(_on_slot_hover.bind(slot))
	node.mouse_exited.connect(_on_slot_unhover.bind(slot))
	# **The move is Godot's own drag, not a hand-rolled one, and the reason is
	# choosing.md §4.2.** The engine records which control owns a pointer only
	# when the *press* landed on a control, and re-hit-tests every drag
	# otherwise; the built-in path is the one written around that. It also gets
	# touch for free -- `emulate_mouse_from_touch` turns an
	# `InputEventScreenDrag` into a motion, so the same machinery runs on a
	# phone -- and it clears `gui.mouse_focus` when a drag begins, which is why
	# `mouse_entered` keeps firing and the drop target is knowable at all.
	node.set_drag_forwarding(_slot_drag.bind(node, slot),
		_slot_can_drop.bind(slot), _slot_drop.bind(slot))
	return node


## The tray's caption, the height of a chip so the row centres on it.
func _make_tray_caption() -> Control:
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = WAIT_CAPTION
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.custom_minimum_size = Vector2(0.0, WAIT_SIZE.y)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	caption.add_theme_color_override("font_color", CAPTION_TINT)
	return caption


## One waiting gene in the tray. **Carries its gene, not its place in the
## queue**: a place is exactly what a lapse or a second meal changes under an
## open screen. See [member _in_hand].
func _make_waiting(gene: StringName) -> Control:
	var node := Control.new()
	node.name = "Waiting_%s" % gene
	node.custom_minimum_size = Vector2(_waiting_width(gene), WAIT_SIZE.y)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.focus_mode = Control.FOCUS_ALL
	node.set_meta(&"waiting", gene)
	node.draw.connect(_draw_waiting.bind(node, gene))
	node.gui_input.connect(_on_waiting_input.bind(node, gene))
	node.focus_entered.connect(node.queue_redraw)
	node.focus_exited.connect(node.queue_redraw)
	# Dragged out, it is carried; nothing is ever dropped onto the tray.
	node.set_drag_forwarding(_waiting_drag.bind(node, gene), Callable(),
		Callable())
	return node


## How wide [param gene]'s chip is: [constant WAIT_SIZE] for every word in
## [constant WORDS], and wider for a name that is not one -- a retired gene's,
## handed over by a host on older content. The tray is a flow, so a wide chip
## can cost a row but never lands on its neighbour.
func _waiting_width(gene: StringName) -> float:
	var font := _tray.get_theme_default_font()
	if font == null:
		return WAIT_SIZE.x
	var word := font.get_string_size(_word(gene), HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, CHIP_WORD).x
	return maxf(WAIT_SIZE.x, ceilf(WAIT_WORD_X + word + PIP_GAP + PIP_R * 2.0
		+ PIP_PITCH * float(GenomeNode.TIER_MAX - 1) + WAIT_AIR))


func _on_slot_hover(slot: int) -> void:
	_hovered = slot
	_update_explain()
	_update_hint()
	# Hover deliberately does not light a chip -- except while a gene is in the
	# air, when the chip under the pointer is where it would land and has to say
	# so. Godot clears the pointer's captured control the moment a drag begins,
	# which is exactly why hover keeps tracking through one.
	if _dragging != SLOT_NONE:
		_redraw_figure()


func _on_slot_unhover(slot: int) -> void:
	if _hovered != slot:
		return
	_hovered = SLOT_NONE
	_update_explain()
	_update_hint()
	if _dragging != SLOT_NONE:
		_redraw_figure()


## **The body register, drawn as a body**: what she wears and where she wears
## it, fixed at birth -- the routine the water uses, nose up, `clock` 0, a still
## mirror. The tethers go first so the body wins where they cross; then the cell;
## then the body's own words where it disagrees with its DNA; then the arc being
## read, last, so nothing covers it.
func _draw_figure_body() -> void:
	if _genome == null:
		return
	var tiers := _genome.tiers()
	var worn: Array[StringName] = _genome.body_layout()
	for slot in _slot_count:
		_draw_tether(slot)
	Cilia.draw_cell(_figure_body, FIGURE_AT, 0.0, FIGURE_R, tiers,
		CellBody.gape_of(int(tiers.get(&"cytostome", 0)), FIGURE_R), FIGURE_R,
		true, 0.0, FIGURE_FADE, 0.0, 0.0, 0.0, 1.0, worn)
	_draw_dissent(worn)
	_draw_arc_mark()


## One slot's thread, from its chip to the middle of its arc, in its gene's hue
## -- or the column's pale, for a slot with nothing in it yet.
func _draw_tether(slot: int) -> void:
	var gene := _gene_at(slot)
	var tone := Cilia.hue(gene) if gene != &"" else PALE
	var to := _skin_at(slot, TETHER_LIFT)
	var from := _chip_edge(slot, to)
	var bow := (to - from).orthogonal() * TETHER_BOW
	_figure_body.draw_polyline(
		PackedVector2Array([from, from.lerp(to, 0.5) + bow, to]),
		Color(tone, TETHER_ALPHA), TETHER_WIDTH, true)


## **Where the body disagrees with its DNA, the body says what it wears**: a
## word at every arc whose organ is not the gene the slot now carries. A slot
## the body leaves empty says nothing -- there is no organ to name, and the
## chip's own floating rungs already say the DNA's gene is not worn.
func _draw_dissent(worn: Array[StringName]) -> void:
	var font := _figure_body.get_theme_default_font()
	if font == null:
		return
	for slot in mini(worn.size(), _slot_count):
		var mine := worn[slot]
		if mine == &"" or mine == _gene_at(slot):
			continue
		var near := _skin_at(slot, TETHER_LIFT)
		var at := near.lerp(_chip_edge(slot, near), DISSENT_ALONG)
		var word := _word(mine)
		var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			DISSENT_SIZE).x
		_figure_body.draw_string(font,
			at + Vector2(-width * 0.5, DISSENT_SIZE * 0.36), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, DISSENT_SIZE,
			Color(Cilia.hue(mine), DISSENT_ALPHA))


## **The part being read, lit on the skin.** Hovered first, like every line
## under the figure; the travelling gene's hue over a drop target, the hand's
## over the slot armed for it, and otherwise the slot's own.
func _draw_arc_mark() -> void:
	var slot := _hovered if _hovered >= 0 else _armed
	if slot < 0 or slot >= _slot_count:
		return
	var gene := _gene_at(slot)
	if _dragging != SLOT_NONE and slot == _hovered and slot != _dragging:
		gene = _gene_at(_dragging)
	elif _dragging == SLOT_NONE and slot == _armed and _hand() != &"":
		gene = _hand()
	var arc := Cilia.arc_for_slot(slot)
	var points := PackedVector2Array()
	for i in ARC_MARK_STEPS + 1:
		var t := deg_to_rad(lerpf(arc.x, arc.y,
			float(i) / float(ARC_MARK_STEPS)))
		points.append(Cilia.skin_point(FIGURE_AT, 0.0, FIGURE_R, t,
			ARC_MARK_LIFT))
	_figure_body.draw_polyline(points,
		Color(Cilia.hue(gene) if gene != &"" else PALE, ARC_MARK_ALPHA),
		ARC_MARK_WIDTH, true)


## The middle of [param slot]'s arc on this figure's skin, [param lift] off it.
## Slot 1 is the flank pair: its chip and its thread are on the starboard side,
## where anything but the cirrus is worn.
func _skin_at(slot: int, lift: float) -> Vector2:
	var arc := Cilia.arc_for_slot(slot)
	return Cilia.skin_point(FIGURE_AT, 0.0, FIGURE_R,
		deg_to_rad((arc.x + arc.y) * 0.5), lift)


## Where a line from [param slot]'s chip toward [param to] leaves the chip, inset
## so it starts clear of the chip's own word and helix.
func _chip_edge(slot: int, to: Vector2) -> Vector2:
	var centre := FIGURE_AT + SLOT_SEAT[slot]
	var d := to - centre
	var half := SLOT_SIZE * 0.5 - TETHER_INSET
	var k := 1.0
	if absf(d.x) > 0.001:
		k = minf(k, half.x / absf(d.x))
	if absf(d.y) > 0.001:
		k = minf(k, half.y / absf(d.y))
	return centre + d * k


func _draw_slot(node: Control, gene: StringName, tier: int, body_tier: int,
		slot: int) -> void:
	var selected := _armed == slot
	var hand := _hand()
	var tone := Cilia.hue(gene) if gene != &"" else PALE
	# **Armed for the gene in hand, the lens takes the incoming hue**, as the arc
	# on the body does. An empty slot also shows the gene as it would land; an
	# *occupied* one keeps drawing its own, because that is what the tap
	# erases and it should be the last thing read before it goes. The first
	# build previewed the incoming gene over an occupant too: rendered, `eat`
	# vanished from the screen while the line under it still read *the mouth · a
	# daughter always wears it*.
	var armed := selected and hand != &"" and _dragging == SLOT_NONE
	if armed:
		tone = Cilia.hue(hand)

	# **Both ends of a drag show what would arrive at them, and nothing moves
	# until the finger lifts.** The lens is the only mark that changes and it is
	# the mark selection already uses, so the destination keeps drawing its own
	# copies: what is about to be displaced stays readable right up to the drop.
	if _dragging != SLOT_NONE:
		if slot == _hovered and slot != _dragging:
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

	var shown := gene
	var copies := tier
	# Worn copies are a subset of the DNA's: a body that kept an organ at two
	# while its slot was written with the same gene at one draws one, worn.
	var worn := mini(body_tier, tier)
	if _dragging == slot:
		# The gene is in the air: the slot it came out of has nothing in it
		# until it lands, and drawing its rungs in both places would be the one
		# lie a drag can tell.
		shown = &""
	elif armed and gene == &"":
		# What a second tap would write, drawn before it is written: a placed
		# gene reaches the DNA and **not** this body, so the preview is carried
		# rungs and ring pips. It is the one frame where the player can see that
		# placing changes their daughters and not themselves.
		shown = hand
		copies = _copies_of(hand)
		worn = 0

	node.draw_set_transform(Vector2(CHIP_X, 0.0))
	# **The lens fills, and that is the whole of "selected".** The middle lobe
	# of three is the slot's own.
	if selected:
		Cilia.draw_lens(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, 0, 1.0, Color(tone, CHIP_LENS))
	var bright := BACKBONE_LIT if selected else 1.0
	# **A fork waiting here parts the strands** (beam-levels.md §8.3): the first
	# two lobes as ever, and then the fork where the third one was.
	var forking := shown != &"" and _genome.can_choose(shown)
	if forking:
		Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, CHIP_LOBES - 1, 0, bright, 0)
		Cilia.draw_fork(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, FORK_FROM, FORK_TIPS, FORK_SPREAD, Cilia.hue(shown), bright)
	else:
		Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, CHIP_LOBES, 0, bright, 0)
	if shown != &"":
		Cilia.draw_rungs(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, 0, CHIP_LOBE * 1.5, Cilia.hue(shown), copies, worn)
	node.draw_set_transform(Vector2.ZERO)

	_draw_chip_label(node, shown, copies, worn, selected)
	if LEVEL_SEAT == LevelSeat.LOBE:
		_draw_chip_level(node, shown, worn, selected, forking)

	if node.has_focus():
		node.draw_line(Vector2(FOCUS_INSET, SLOT_SIZE.y - 1.0),
			Vector2(SLOT_SIZE.x - FOCUS_INSET, SLOT_SIZE.y - 1.0),
			FOCUS_TINT, FOCUS_WIDTH, true)


## A slot the body has not earned: its helix, faint, and nothing else.
func _draw_unearned(node: Control) -> void:
	node.draw_set_transform(Vector2(CHIP_X, 0.0))
	Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID, CHIP_AMP,
		CHIP_LOBES, 0, UNEARNED_INK, 0)
	node.draw_set_transform(Vector2.ZERO)


## The plain word and the level, centred under the chip as one group so a long
## word and a short one both sit under their own piece of helix.
##
## **The word is the slot's word**: a short verb parsed at arm's length, never
## the biological name. That belongs to the explanation line, which is read
## rather than glanced at.
func _draw_chip_label(node: Control, gene: StringName, copies: int, worn: int,
		selected: bool) -> void:
	if gene == &"":
		return
	var font := node.get_theme_default_font()
	if font == null:
		return
	var word := _word(gene)
	var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		CHIP_WORD).x
	var group := width + PIP_GAP + PIP_PITCH * float(GenomeNode.TIER_MAX - 1) \
		+ PIP_R * 2.0
	# Owner's call 2 answered the other way: the level after the pips, in the
	# group, so the whole reading stays centred under its helix.
	var level := ""
	var level_size := LEVEL_SIZE
	var grown := _genome.progression(gene)
	if LEVEL_SEAT == LevelSeat.AFTER_PIPS and grown != null:
		level = str(grown.level())
		level_size = _level_size(grown.level())
		group += LEVEL_AFTER_GAP + font.get_string_size(level,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, level_size).x
	var left := (SLOT_SIZE.x - group) * 0.5
	var tint := _word_tint(selected, worn)
	node.draw_string(font, Vector2(left, CHIP_BASE), word,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_WORD, tint)
	_draw_pips(node,
		Vector2(left + width + PIP_GAP + PIP_R, CHIP_BASE - PIP_LIFT),
		Cilia.hue(gene), copies, worn, 1.0)
	if level != "":
		node.draw_string(font, Vector2(left + width + PIP_GAP
			+ PIP_PITCH * float(GenomeNode.TIER_MAX - 1) + PIP_R * 2.0
			+ LEVEL_AFTER_GAP, CHIP_BASE), level, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, level_size, tint)


## The tint a chip's word is drawn in -- and its level, which reads with it.
## Loud while selected; quieter for an organ this body does not wear, the third
## channel agreeing with the floating rungs and the rings.
func _word_tint(selected: bool, worn: int) -> Color:
	if selected:
		return LABEL_TINT_LOUD
	if worn <= 0:
		return Color(PALE, WORD_UNEXPRESSED)
	return LABEL_TINT


## **The level, in the third lobe** (beam-levels.md §8.1): the banked level --
## `level()`, never the one held at the fork -- centred in the lens right of the
## rungs, in the word's own tint. At an open fork it moves into the fork's mouth
## and takes the gene's hue, so the one chip that is asking for something is the
## one whose number is coloured. Drawn wherever the chip draws its word, and so
## never on a drag source or an empty slot.
func _draw_chip_level(node: Control, gene: StringName, worn: int,
		selected: bool, forking: bool) -> void:
	if gene == &"":
		return
	var grown := _genome.progression(gene)
	var font := node.get_theme_default_font()
	if grown == null or font == null:
		return
	var text := str(grown.level())
	var size := _level_size(grown.level())
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		size).x
	var at := LEVEL_FORK_X if forking else LEVEL_X
	node.draw_string(font, Vector2(at - width * 0.5, LEVEL_BASE), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size,
		Color(Cilia.hue(gene), LEVEL_FORK_ALPHA) if forking
			else _word_tint(selected, worn))


## The numeral's size: [constant LEVEL_SIZE], and one step down from three
## digits, which the lobe was measured to hold at two.
func _level_size(level: int) -> int:
	return LEVEL_SIZE if level < LEVEL_SMALL_FROM else LEVEL_SIZE_SMALL


## Three pips from [param first], a pitch apart: a disc for each copy worn, a
## ring for each copy only carried, a dot for each copy there is still room for.
## [param ink] is the tray's dim; a chip passes 1.
func _draw_pips(node: Control, first: Vector2, tone: Color, copies: int,
		worn: int, ink: float) -> void:
	for i in GenomeNode.TIER_MAX:
		var at := first + Vector2(PIP_PITCH * float(i), 0.0)
		if i < worn:
			node.draw_circle(at, PIP_R, Color(tone, 0.95 * ink), true, -1.0, true)
		elif i < copies:
			# Stroked inside the disc's radius, so a ring and a disc are the
			# same size and only their fill differs.
			node.draw_arc(at, PIP_R - PIP_RING * 0.5, 0.0, TAU, 16,
				Color(tone, 0.95 * ink), PIP_RING, true)
		else:
			node.draw_circle(at, PIP_ROOM_R, Color(PALE, PIP_ROOM_ALPHA * ink),
				true, -1.0, true)


## One waiting gene: its loose base pair, its word and its level as rings.
##
## **The wilt** (dna-body.md §5): its halos fade over its last
## [constant Cilia.HELD_WILT] seconds, the vesicle's own clock on the body, so
## the tray and the figure in the water say *about to lapse* the same way. Only
## a pond shows it -- single player stops every clock while this screen is open
## -- and [method _step_tray] redraws it there.
func _draw_waiting(node: Control, gene: StringName) -> void:
	# While a fork's cards are up the fork chip carries the in-hand mark: one
	# thing in the tray is being decided at a time. The hand is kept, and it is
	# drawn in hand again the moment the figure comes back.
	var in_hand := gene == _hand() and _dragging != SLOT_SAMPLE \
		and not _fork_open()
	var ink := 1.0 if in_hand else WAIT_DIM
	var tone := Cilia.hue(gene)
	var mid := WAIT_SIZE.y * 0.5 - 2.0
	var wilt := clampf(_genome.waiting_left(gene) / Cilia.HELD_WILT, 0.0, 1.0)
	_draw_base_pair(node, Vector2(WAIT_BAR_X, mid), tone, ink,
		(1.6 if in_hand else 1.0) * (0.40 + 0.60 * wilt))
	var font := node.get_theme_default_font()
	if font != null:
		var word := _word(gene)
		node.draw_string(font, Vector2(WAIT_WORD_X, mid + 5.0), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_WORD,
			LABEL_TINT_LOUD if in_hand else LABEL_TINT)
		var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			CHIP_WORD).x
		# Carried by definition, so rings and never a disc.
		_draw_pips(node, Vector2(WAIT_WORD_X + width + PIP_GAP + PIP_R, mid),
			tone, _genome.waiting_copies(gene), 0, ink)
	# The chip's own width, not WAIT_SIZE's: a name wider than any word grows
	# its chip, and the underline is under the whole of it.
	if in_hand:
		node.draw_line(Vector2(6.0, WAIT_SIZE.y - 3.0),
			Vector2(node.size.x - 6.0, WAIT_SIZE.y - 3.0), Color(tone, 0.55),
			1.5, true)
	if node.has_focus():
		node.draw_line(Vector2(FOCUS_INSET, WAIT_SIZE.y - 1.0),
			Vector2(node.size.x - FOCUS_INSET, WAIT_SIZE.y - 1.0),
			FOCUS_TINT, FOCUS_WIDTH, true)


## **A base pair that is not in a ladder yet**: a bar with a base at each end,
## inside two faint rings -- the picture of a gene that has not been given a
## place, in the tray and on a finger alike. [param halo] scales the rings.
func _draw_base_pair(node: CanvasItem, bar: Vector2, tone: Color, ink: float,
		halo: float) -> void:
	for i in SAMPLE_HALO.size():
		node.draw_arc(bar, SAMPLE_HALO[i], 0.0, TAU, 24,
			Color(tone, SAMPLE_HALO_ALPHA[i] * halo), 1.4, true)
	var top := bar - Vector2(0.0, SAMPLE_BAR * 0.5)
	var bottom := bar + Vector2(0.0, SAMPLE_BAR * 0.5)
	node.draw_line(top, bottom, Color(tone, 0.94 * ink), SAMPLE_WIDTH, true)
	node.draw_circle(top, SAMPLE_CAP, Color(tone, 0.94 * ink), true, -1.0, true)
	node.draw_circle(bottom, SAMPLE_CAP, Color(tone, 0.94 * ink), true, -1.0,
		true)


## **The travelling gene**: the base pair with its plain word beside it, centred
## as a group on [param centre]. The word stays, because a base pair with no
## word is a coloured dot.
func _draw_sample(node: Control, gene: StringName, centre: Vector2) -> void:
	var tone := Cilia.hue(gene)
	var font := node.get_theme_default_font()
	var word := _word(gene)
	var width := 0.0
	if font != null:
		width = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			SAMPLE_WORD).x
	var group := SAMPLE_WIDTH + SAMPLE_GAP + width
	var bar := Vector2(centre.x - group * 0.5 + SAMPLE_WIDTH * 0.5, centre.y)
	_draw_base_pair(node, bar, tone, 1.0, 1.0)
	if font != null:
		node.draw_string(font,
			Vector2(bar.x + SAMPLE_WIDTH * 0.5 + SAMPLE_GAP,
				centre.y + SAMPLE_WORD * 0.38),
			word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SAMPLE_WORD, LABEL_TINT_LOUD)


## **The one organ beside a sentence on the pause screen.**
##
## The old tiles drew an organ each, which is what taught a point-of-view
## player the cilia vocabulary (genes-and-cilia.md §2.4). The figure now draws
## every organ the body wears, where it wears it; what it cannot draw is a gene
## the body does not wear -- a waiting one, or one only the DNA carries -- and
## seven small tufts round a ring of chips would be the four-tuft mistake
## diegetic-hud.md §2 already made and measured. One, at the thing the player
## is reading, in the row that already exists, keeps the vocabulary and spends
## 30 px.
func _draw_explain_organ() -> void:
	if _explain_gene == &"" or _explain_organ == null:
		return
	var worn := _genome.tier(_explain_gene) > 0 \
		or _genome.waiting_index(_explain_gene) >= 0
	Cilia.draw_tile_organ(_explain_organ, _explain_gene, _explain_tier,
		EXPLAIN_ORGAN_SEAT,
		Cilia.TILE_STROKE_ALPHA if worn else ORGAN_UNEXPRESSED,
		EXPLAIN_ORGAN_SCALE)


# --- Two taps on the same target -------------------------------------------
# The only pattern that is safe on touch and navigable by keyboard. A mis-tap
# costs nothing because arming is reversible, and that is the argument that
# makes neighbouring chips acceptable on a phone. The destructive control here
# is not adjacent to `resume`: they are in different columns.

## **Picking a waiting gene.** A tap takes it in hand, and any armed slot
## disarms: a slot armed for one gene must never be a tap away from writing a
## different one. Tapping the gene already in hand disarms too, which is how a
## thumb with no Escape takes an arm back.
func _on_waiting_input(event: InputEvent, node: Control,
		gene: StringName) -> void:
	if not _is_widget_tap(event):
		return
	node.accept_event()
	_primed = SLOT_NONE
	# **A waiting gene is one way out of the fork's cards** (beam-levels.md
	# §8.3): the view shuts on the press, so the gene goes in hand on the figure
	# and a drag that grows out of this press lands on the slots.
	var was_open := _fork_open()
	if was_open:
		_close_fork(false)
	# Lapsed under the tray in a pond: the rebuild that shows it gone is a frame
	# away, and picking a gene that is not waiting would put nothing in hand.
	if _genome.waiting_index(gene) < 0:
		return
	if _in_hand == gene and _armed == SLOT_SAMPLE and not was_open:
		return
	_in_hand = gene
	_armed = SLOT_SAMPLE
	_armed_at = Time.get_ticks_msec()
	_hovered = SLOT_NONE
	_redraw_figure()
	_update_explain()
	_update_hint()


## **[param tile] is dead after [method _build_genome_strip] runs.** A rebuild
## removes and frees every chip -- including the one whose `gui_input` we are
## standing inside. That is legal (`queue_free` is deferred and `remove_child`
## during emission is fine) and it is exercised on both the touch path and the
## keyboard path, but it means nothing may touch `tile` after the rebuild. Read
## the new node out of the layer instead, the way the focus line does.
##
## Two of the branches below rebuild -- a move and a commit -- and **selecting
## does not**, because a press that selects may still become a drag and Godot
## hangs the drag off the control that took the press. Everything `tile` is
## used for happens before either rebuild: `accept_event()`, and the rect the
## up-stroke is tested against.
func _on_slot_input(event: InputEvent, tile: Control, index: int) -> void:
	var way := _move_key(event)
	if way >= 0:
		# `accept_event()` on the chord, or GUI focus navigation runs as well
		# and the keyboard walks off the slot the gene just moved to.
		tile.accept_event()
		var to := int(SLOT_NEIGHBOUR[index][way])
		if _slot_live(to):
			_move_slot(index, to)
		return
	# **The up-stroke, which is where a placement lands.** See [member _primed]
	# for why it cannot land on the down-stroke.
	if _is_pointer_lift(event):
		tile.accept_event()
		var was_primed := _primed == index
		_primed = SLOT_NONE
		# `has_point` and not simply "this slot got the release": Godot keeps
		# delivering to the control the press landed on, so a finger that
		# pressed an armed slot, slid off it and lifted elsewhere gets its
		# release *here*, outside the chip's rect. That is a gesture the player
		# aborted, and aborting by sliding off is the oldest cancel there is.
		if was_primed and _dragging == SLOT_NONE \
				and Rect2(Vector2.ZERO, tile.size).has_point(
					_pointer_at(event)):
			_second_tap(index, false)
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
		# **With nothing in hand, a slot whose fork is open opens its two ways**
		# (beam-levels.md §8.3). The same guard, so a touch and the click Godot
		# emulates from it cannot select and open in one press; primed on the
		# press and landing on the lift, because the press may still become a
		# move -- the slot's gene is as movable as any other.
		if _hand() == &"" and _forks_at(index):
			if Time.get_ticks_msec() - _armed_at < ARM_GUARD_MS:
				return
			if _is_pointer_press(event):
				_primed = index
				return
			_second_tap(index, true)
			return
		# Nothing to commit -- nothing in hand, or, in a pond, a screen the
		# genome has moved on from -- so the second tap is simply the first one
		# again and the slot stays selected.
		#
		# **It used to deselect, and the render is what killed that.** Godot
		# focuses a control on click, so the chip a thumb has just tapped keeps
		# a focus ring whether or not it is selected: deselecting left a chip
		# underlined in pale teal with an empty sentence under it, which is the
		# surface pointing at something and then refusing to say what. Blanking
		# the one line the player came for is a worse answer than doing nothing.
		return
	_armed = index
	_armed_at = Time.get_ticks_msec()
	# **A selection redraws; it does not rebuild.** Freeing and remaking the
	# chips to move one lens was always waste, and once a press can become a
	# drag it is a bug rather than waste: Godot hangs a drag off the control
	# that took the *press*, and freeing that control before the finger had
	# moved meant the drag could never start. Nothing about the genome changed
	# here, so nothing has to be rebuilt; the chips read [member _armed] at draw
	# time. It also removes the focus churn [method _restore_focus] exists to
	# repair.
	_redraw_figure()
	_update_explain()
	_update_hint()


## Every chip, every tray chip and the body, redrawn. They read the selection,
## the hand and the drag out of [member _armed], [member _in_hand] and
## [member _dragging] at draw time, so this is all a change of any of them needs.
func _redraw_figure() -> void:
	_figure_body.queue_redraw()
	for layer: Control in [_figure_slots, _tray]:
		for child in layer.get_children():
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
# Tap-then-tap was not available: a tap already selects a slot and reads it,
# and a second tap already places the gene in hand. Redefining the pair as a
# move would cost the ability to read a second gene, which is most of what the
# figure is for.

## The gene leaves its slot. Returning `null` refuses the drag, which is what
## an empty slot does.
func _slot_drag(_at: Vector2, node: Control, slot: int) -> Variant:
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
	node.set_drag_preview(_drag_preview(gene))
	_redraw_figure()
	_update_explain()
	_update_hint()
	return {&"move_from": slot, &"gene": gene}


## **A waiting gene, carried out of the tray** (dna-body.md §5). It is in hand
## from the moment it leaves: onto an empty slot it lands on the drop, and onto
## an occupied one the drop is only the first tap. The data carries the gene,
## never its place in the queue -- see [member _in_hand].
func _waiting_drag(_at: Vector2, node: Control, gene: StringName) -> Variant:
	if _genome.waiting_index(gene) < 0:
		return null
	_in_hand = gene
	_primed = SLOT_NONE
	_dragging = SLOT_SAMPLE
	_armed = SLOT_SAMPLE
	_armed_at = Time.get_ticks_msec()
	node.set_drag_preview(_drag_preview(gene))
	_redraw_figure()
	_update_explain()
	_update_hint()
	return {&"place": gene}


## The travelling gene's picture, lifted off the pointer.
##
## Godot seats a drag preview's *root* on the pointer, so the offset has to live
## on a child of it; a wrapper is the one way to lift the picture off the thumb.
func _drag_preview(gene: StringName) -> Control:
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = SAMPLE_BOX
	preview.size = SAMPLE_BOX
	preview.position = Vector2(-SAMPLE_BOX.x * 0.5,
		-SAMPLE_BOX.y * 0.5 - DRAG_LIFT)
	preview.draw.connect(_draw_sample.bind(preview, gene, SAMPLE_BOX * 0.5))
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(preview)
	return wrap


## **A move lands on every live slot but the one it came out of, and a waiting
## gene on every live slot.** Not refused on an occupied one: a late-game ring
## is dense, so refusing would fail most drops and a gesture that usually does
## nothing reads as broken. An occupied destination swaps, which is the same
## operation `Genome._mutate_shift` already performs at every division -- and an
## empty one is the degenerate case of that same swap, so there is one rule and
## not two. A waiting gene that lapsed while it was being carried lands nowhere.
func _slot_can_drop(_at: Vector2, data: Variant, slot: int) -> bool:
	if not (data is Dictionary) or not _slot_live(slot):
		return false
	var carried := data as Dictionary
	if carried.has(&"place"):
		return _genome.waiting_index(StringName(carried[&"place"])) >= 0
	if not carried.has(&"move_from"):
		return false
	return slot != int(carried[&"move_from"])


func _slot_drop(_at: Vector2, data: Variant, slot: int) -> void:
	_dragging = SLOT_NONE
	var carried := data as Dictionary
	if carried.has(&"place"):
		_drop_waiting(StringName(carried[&"place"]), slot)
		return
	# The keyboard follows the moved gene, and with nothing in hand the gene
	# stays selected too, so the three lines under the figure are a receipt for
	# what moved and where it now points. With a gene in hand the selection
	# goes back to the hand -- see [method _move_slot].
	_move_slot(int(carried[&"move_from"]), slot)


## **A waiting gene let go over a slot.** Onto an empty one it is placed there
## and then: nothing is evicted, and a move can still take it anywhere, so the
## second tap would confirm nothing (owner's call 6). Onto a gene the drop is
## the first tap and the slot arms, with the guard and the timeout running from
## now -- the eviction still needs its own second tap.
func _drop_waiting(gene: StringName, slot: int) -> void:
	_in_hand = gene
	if _gene_at(slot) == &"":
		_commit_slot(slot)
		return
	_armed = slot
	_armed_at = Time.get_ticks_msec()
	_redraw_figure()
	_update_explain()
	_update_hint()


## **`Shift` and an arrow, read raw.** A content pack cannot add an `InputMap`
## action, and the bare arrows are how the GUI is navigated -- so the chord is
## read off the key event itself rather than through an action. Returns the
## arrow's side in [constant SLOT_NEIGHBOUR] -- 0 left, 1 up, 2 right, 3 down --
## or -1 for anything else. Directions on the ring, not steps along a strand.
func _move_key(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or not key.shift_pressed:
		return -1
	match key.keycode:
		KEY_LEFT:
			return 0
		KEY_UP:
			return 1
		KEY_RIGHT:
			return 2
		KEY_DOWN:
			return 3
	return -1


## One move, from either gesture. [param to] is taken or refused, never
## adjusted: the table in [constant SLOT_NEIGHBOUR] and the drop target both
## name an exact arc, and a gene that landed on a different one would defeat the
## whole thing a move is for.
func _move_slot(from: int, to: int) -> void:
	if not _genome.move(from, to):
		return
	# **The moved gene is selected -- unless a gene is in hand.** Then the
	# selection goes back to the hand, and the keyboard alone follows the move
	# (below). Left on the destination, the selection would be an *arm* for the
	# gene in hand that no tap ever made: a drop, or a `Shift`+arrow, is not a
	# first tap on that slot, and the next tap there would write the gene in
	# hand over the one that just moved in -- a player tapping to read what they
	# moved would lose it. The one irreversible action takes two taps on the
	# slot it writes, both of them the player's.
	if _hand() != &"":
		_armed = SLOT_SAMPLE
	else:
		_armed = to
	_armed_at = Time.get_ticks_msec()
	_hovered = SLOT_NONE
	# The genome really did change, so this one is a rebuild: the chips read
	# their genes and their copy counts at build time, and the tethers, the
	# body's words and the arc all follow the new layout.
	_build_genome_strip()
	# The rebuild's own focus restore only fires for a slot that *had* focus,
	# and a mouse drag never gave one to anything. Sending the keyboard after
	# the gene it just moved is what makes `Shift`+arrow repeatable.
	_restore_focus(to)


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
## the chip is handed both.
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


## Where a pointer event landed, in the chip's own coordinates. Off the chip is
## a legal answer and the reason this is asked at all.
func _pointer_at(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	return Vector2(-1.0, -1.0)


## **A second tap that landed on the selected slot**, by the lift inside the
## chip or by a key. With a gene in hand it places it, as it always has; with
## none, on a slot whose fork is open, it opens that fork's two ways
## (beam-levels.md §8.3). [param by_key] says the keyboard asked, which is what
## sends focus onto the first card.
func _second_tap(index: int, by_key: bool) -> void:
	if _hand() == &"" and _forks_at(index):
		_open_fork(_gene_at(index), by_key)
		return
	_commit_slot(index)


## The one irreversible action in the game (§9.7). A genome you cannot ruin is
## not a choice, and §1.3's drifter floor is what makes even the worst swap --
## dropping a fourth gene over your own mouth -- survivable rather than a soft
## lock.
##
## **Gated on the figure, not on the ladder.** `_genome.slots()` is the capacity
## the *body* earned, and a newborn carries her mother's whole DNA on a body two
## thirds the size -- so gating on it would silently deaden four of seven live
## slots for the commonest state in the late game. The chips are the DNA and the
## DNA is what is being placed into.
func _commit_slot(index: int) -> void:
	# **Nothing is written while a gesture is in flight**, which is the guard
	# [method _step_arming] already carries and this one was missing once. The
	# reachable case is desktop and it is one hand on each device: a mouse drag
	# lifting `eat` out of slot 0 while the other hand presses Enter --
	# `ui_accept` is Enter, KP-Enter *and* Space -- on a focused slot with a gene
	# in hand. Without this the gene lands, the figure rebuilds mid-drag,
	# [member _dragging] still points at a slot that now holds a different gene,
	# and the release moves the gene that was just placed rather than the one
	# the drag picked up.
	if _dragging != SLOT_NONE:
		return
	if index < 0 or index >= _slot_genes.size():
		return
	# **Asked again here, on every path that writes the DNA.** A lift commits on
	# the strength of a press made earlier, and in a pond the genome can change
	# between the two -- the gene in hand can lapse, or another can lapse into
	# this slot. Then nothing is written, and the screen catches up now rather
	# than a frame later.
	if not _committable(index):
		if _catch_up():
			_build_genome_strip()
		return
	# **Looked up by gene, now, and never remembered as a place in the queue.**
	_genome.place(index, _genome.waiting_index(_in_hand))
	# **The placed slot stays selected**, so the lines under the figure are now
	# the gene that just landed and the slot it landed in. The gene is spent, so
	# nothing about that selection is committable any more -- it is a receipt,
	# and the one moment in a run where the player most wants to know what they
	# have just given their daughters.
	#
	# **Unless another gene is waiting behind it** (#118), and then the head
	# goes in hand, unplaced. Left on the slot it would be armed for the *next*
	# gene -- drawn over the gene that just landed, one more tap from writing
	# over it. The one irreversible action in the game must never be a tap away
	# without a fresh first tap to arm it.
	_in_hand = &""
	_armed = index
	_armed_at = Time.get_ticks_msec()
	_hovered = SLOT_NONE
	if _genome.held_sample != &"":
		_select_default()
	# The bus is told now rather than on the next unpaused frame: the membrane
	# keeps beating under the scrim, and an echo for a gene that no longer waits
	# is the game lying about the player's own body. **Or for one that does**:
	# with another gene still waiting the echo goes on, now for it.
	_bus.hold(_genome.held_remaining if _genome.held_sample != &"" else 0.0)
	_build_genome_strip()


## The armed slot lapses on its own, so a screen left armed is not a trap -- and,
## in a pond, the queue can change under it, which this is where the screen
## catches up with.
##
## **This does not lapse the gene.** Four seconds is a hesitation; the gene has
## forty-five, and in single player its clock is not even running -- `Genome` is
## `process_mode = 1`, so it stops with the rest of the simulation while the
## pause screen is open. **An arm that lapses goes back to the gene in hand, not
## to the head**: the player picked that gene, and four seconds of reading is
## not a reason to take it off them. It is a redraw and not a rebuild -- nothing
## in the genome changed -- so the chip under a resting mouse keeps its hover
## and the keyboard stays where it was.
##
## **Only a committable selection lapses.** The timeout exists to make sure a
## slot left armed is not a trap; a selection with nothing in hand behind it is
## not a trap, it is a player reading a sentence, and four seconds is not long
## enough to read one twice.
func _step_arming() -> void:
	# **Nothing lapses while a gesture is in flight.** A rebuild frees the chip
	# a drag came out of and the one under the pointer -- and four seconds is an
	# easy hold for a thumb that is choosing between seven destinations.
	if _dragging != SLOT_NONE:
		return
	# **A finger already down counts as a gesture in flight**, and this one was
	# found by posing the move at 2400x1080, where the renderer is slow enough
	# that the wall clock outran the harness's own clock. A press lands on an
	# armed slot, the four seconds run out before the finger has moved the ten
	# pixels Godot needs to call `_get_drag_data`, a rebuild frees the control
	# the press landed on -- and the drag can never start. The cure is one line:
	# a slot with a finger on it is not a slot left armed.
	if _primed != SLOT_NONE:
		return
	# **A genome that changed under the screen is a new picture, and sometimes
	# a new decision** (#118): the gene in hand lapsed and the head goes in hand;
	# a gene behind it lapsed or a new one arrived, and the hand stays, because
	# the gene the player picked is still the one they are placing; a slot armed
	# over a gene that changed is disarmed. Only reachable in a pond, where the
	# menu stops nothing. See [method _catch_up].
	if _catch_up():
		_build_genome_strip()
		return
	if not _committable(_armed):
		return
	if Time.get_ticks_msec() - _armed_at < ARM_TIMEOUT_MS:
		return
	_armed = SLOT_SAMPLE
	_armed_at = Time.get_ticks_msec()
	_redraw_figure()
	_update_explain()
	_update_hint()


## **The wilt, kept moving** (dna-body.md §5): the tray is redrawn while any
## waiting gene is inside its last [constant Cilia.HELD_WILT] seconds, so its
## halos fade on the vesicle's clock. A pond only -- single player stops every
## clock while this screen is open, and redrawing a still picture is waste.
func _step_tray() -> void:
	for gene: StringName in _strip_waiting:
		if _genome.waiting_left(gene) < Cilia.HELD_WILT:
			for child in _tray.get_children():
				(child as CanvasItem).queue_redraw()
			return


## **The tray never shrinks while the screen is open** (dna-body.md §5). Four
## genes fit beside the caption and a fifth wraps, so placing the fifth would
## otherwise pull the whole figure 56 px up under the finger that just placed
## it. Whatever height the tray reaches is held until the screen opens again,
## which is where [method _set_menu] lets it go.
func _latch_tray() -> void:
	if _tray.size.y > _tray.custom_minimum_size.y:
		_tray.custom_minimum_size.y = _tray.size.y


# ---------------------------------------------------------------------------
# The level and the fork, on the pause screen (docs/design/beam-levels.md §8).
#
# **A gene that levels carries two numbers, and they never share a row.** The
# pips are its copies -- whether a daughter wears it -- and the level is how
# strong it is, which a daughter inherits whether she wears it or not. The
# level sits in the third lobe of the slot's helix and at the front of the line
# under the figure. At the fork three places say a choice waits -- the slot's
# strands part, the tray holds a chip for it, and the eye buds in the water --
# and one place takes it: two cards, one per way, in the figure's own place.
#
# **Choosing is the pause screen's one confirm, unchanged in kind.** Tap a way
# to arm it; tap it again to take it, for good. The guard and the timeout are
# the slot's, and the second tap lands on the lift inside the card, so sliding
# off cancels. The words for the ways live here, at the edge, and nothing in
# progression.gd knows them.
# ---------------------------------------------------------------------------

## **Owner's call 1** (beam-levels.md §8.9): what the two ways are called. The
## cards' titles, and the name every line about a way uses, so a different
## answer is this line. `fill`, recommended, says what happens: each level adds
## a ray between the ones there are, so the fan fills in and never widens.
## `extension`, the owner's own word, can read as a longer beam, and neither way
## is longer.
const PATH_TITLES := {&"extend": "fill", &"sweep": "sweep"}
## What each way is good and bad at: one clause each, no numbers, in the gene
## lines' voice.
const PATH_LINES := {
	&"extend": ["every ray lit, all the time", "small things slip between"],
	&"sweep": ["no gaps between rays", "shows where things were"],
}
## What a way does as it grows, after its name on the explanation line.
const PATH_SAYS := {
	&"extend": "a new ray every level, filling the fan",
	&"sweep": "your three rays swing, faster every level",
}
## **What a way costs is read off the prices, never written down.** X and Y are
## balance numbers the owner judges by playing (beam-levels.md §5); if they
## ever move so far that the two ways trade places, the words trade with them.
const COST_MORE := "costs more to keep"
const COST_LESS := "costs less to keep"
const COST_SAME := "costs the same to keep"
## The hint while the cards are up: what the banked levels do until a way is
## taken -- and at the fork itself, why a choice changes nothing yet -- and, a
## way hovered or armed, what it costs beside the other.
const HINT_WORKS_AS := "works as level %d until you choose"
const HINT_BOTH_NEXT := "both ways start at the next level"
const HINT_COSTS := "%s than %s"
## The verbs: arming is harmless, and taking is for good.
const ACT_PICK_WAY := "tap a way to choose it"
const ACT_CHOOSE_WAY := "tap again to choose %s · for good"

## **Owner's call 3** (§8.9): what pause opens on with a fork open and no gene
## waiting. `false`, recommended: the figure, with the forking slot selected
## and one tap from the cards -- pause looks as it does now, and a pause to
## change the light is still that. `true` opens straight onto the cards.
const PAUSE_OPENS_ON_CARDS := false

## The cards, in the view's own 420 x 372: 200 x 290, 20 apart, 41 down, which
## is 49 px clear of the tray above and of `Explain` below, and 300 x 435 device
## px on a phone. `Way0` is the progression's first path, `Way1` its second.
const WAY_SIZE := Vector2(200.0, 290.0)
const WAY_SEAT: Array[Vector2] = [Vector2(0.0, 41.0), Vector2(220.0, 41.0)]
## **Opaque on purpose.** Full vision pins the ghost of the player's cell to
## canvas x 640, inside the left card. At the slab's usual 0.45 the design's
## mock saw its rim through the card, 36.5 of glance on a card that read 23.5;
## at 0.90, over the ghost's seat, the card reads 30.8 in full vision against
## 30.5 in point of view, and no pixel of it is more than 6 of 255 apart.
const WAY_FILL := Color(0.063, 0.141, 0.125, 0.90)
const WAY_EDGE := Color(0.12, 0.70, 0.58, 0.26)
const WAY_CORNER := 6
## Armed: a 2 px border in the gene's hue, and the other card steps back.
const WAY_EDGE_ARMED := 2
const WAY_EDGE_ARMED_ALPHA := 0.85
const WAY_OTHER_INK := 0.55
## **The picture is the water's own beam**: the organ, and the fan that way
## gives at the next level it will have, from `CellBody.beam_shape()` and
## stepped by a ray fan -- so what the card shows is what the beam will do.
const WAY_ORGAN_AT := Vector2(100.0, 154.0)
const WAY_RAY_ROOT := Vector2(100.0, 146.0)
const WAY_RAY_FROM := 16.0
const WAY_RAY_TO := 110.0
const WAY_RAY_WIDTH := 2.0
const WAY_RAY_ROOT_ALPHA := 0.30
const WAY_RAY_TIP_ALPHA := 0.85
const WAY_RAY_DOT := 2.2
## A sweeping ray's own share of the fan, filled faintly, and the three copies
## it trails -- where it was 0.03, 0.06 and 0.09 s ago -- at these shares of its
## ink. Still rays trail nothing.
const WAY_SECTOR_ALPHA := 0.06
const WAY_TRAIL_STEP := 0.03
const WAY_TRAIL: Array[float] = [0.45, 0.25, 0.12]
const WAY_SECTOR_STEPS := 8
## The words: the way's name in the gene's hue, the good and the bad in the
## explanation's tint, and the price in the hint's.
const WAY_TITLE_SIZE := 20
const WAY_TITLE_BASE := 188.0
const WAY_TITLE_ALPHA := 0.95
const WAY_LINE_SIZE := 14
const WAY_PRO_BASE := 216.0
const WAY_CON_BASE := 238.0
const WAY_COST_BASE := 266.0
const WAY_COST_ALPHA := 0.38
## Focus is the chips' own underline, never a box.
const WAY_FOCUS_Y := 284.0

## **The gene whose fork's cards are up**, &"" while the figure is. Held by
## gene, as the gene in hand is (dna-body.md §5.1), so a tray rebuilt under it
## in a pond keeps it open.
var _fork_gene: StringName = &""
## The armed way, since when, and the way a finger is holding its confirm on:
## [member _armed], [member _armed_at] and [member _primed], for the cards. -1
## is none.
var _way_armed := -1
var _way_armed_at := 0
var _way_primed := -1
## The way the mouse is over, -1 for none. Desktop's read, as on the slots.
var _way_hovered := -1
## Each card's fans, stepped while the view is up: one for a still way; for a
## sweeping one, the fan and the three that trail it.
var _way_fans: Array = []
## The open forks the tray was built with, in the order their chips stand.
var _strip_forks: Array[StringName] = []
## Every level and gauge last drawn, as one number. In a pond they move under
## an open menu, and a change is a redraw, never a rebuild (§8.2).
var _levels_seen := 0
## Whose progress the gauge draws, &"" for none.
var _gauge_gene: StringName = &""
## The frame the fork chip last answered on. A touch arrives twice -- as itself
## and as the click Godot emulates from it -- and a toggle answered twice is
## no toggle.
var _fork_chip_frame := -1
var _way_box: StyleBoxFlat = null
var _way_box_armed: StyleBoxFlat = null
var _gauge_track: StyleBoxFlat = null
var _gauge_fill: StyleBoxFlat = null


## The row under the figure: the level's label and the gauge's box, beside the
## words that were the whole row before (§8.2). The scene carries the same
## numbers; this is what binds, as it is for the figure.
func _build_level_row() -> void:
	_hint_row.add_theme_constant_override("separation", HINT_ROW_SEPARATION)
	_hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint_row.custom_minimum_size = Vector2(0.0, HINT_ROW_HEIGHT)
	_hint_level.add_theme_font_size_override("font_size", 14)
	_hint_level.add_theme_color_override("font_color", LABEL_TINT)
	_hint_level.hide()
	_hint_gauge.custom_minimum_size = GAUGE_SIZE
	_hint_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_gauge.hide()
	_hint_gauge.draw.connect(_draw_gauge)
	_gauge_track = _flat(GAUGE_TRACK, GAUGE_RADIUS)
	_gauge_fill = _flat(GAUGE_TRACK, GAUGE_RADIUS)


## The gauge: a track, and the share of the level already earned in the gene's
## hue. One pixel is a thirty-sixth of a level.
func _draw_gauge() -> void:
	var grown: Progression = _genome.progression(_gauge_gene) \
		if _gauge_gene != &"" else null
	if grown == null:
		return
	_hint_gauge.draw_style_box(_gauge_track, GAUGE_BAR)
	var fill := roundf(GAUGE_BAR.size.x * grown.progress())
	if fill <= 0.0:
		return
	_gauge_fill.bg_color = Color(Cilia.hue(_gauge_gene), GAUGE_FILL_ALPHA)
	_hint_gauge.draw_style_box(_gauge_fill,
		Rect2(GAUGE_BAR.position, Vector2(fill, GAUGE_BAR.size.y)))


## A plain rounded box, filled, with an edge if one is asked for.
func _flat(fill: Color, radius: int, edge := Color(0.0, 0.0, 0.0, 0.0),
		width := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	if width > 0:
		box.border_color = edge
		box.set_border_width_all(width)
	return box


## The fork view's two cards. Their places are set here, as the figure's are;
## the scene carries the same numbers so the tree reads right in an editor.
func _build_fork_view() -> void:
	_fork_view.custom_minimum_size = FIGURE_SIZE
	_fork_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fork_view.hide()
	_way_box = _flat(WAY_FILL, WAY_CORNER, WAY_EDGE, 1)
	_way_box_armed = _flat(WAY_FILL, WAY_CORNER, WAY_EDGE, WAY_EDGE_ARMED)
	for way in _ways.size():
		var card := _ways[way]
		card.position = WAY_SEAT[way]
		card.size = WAY_SIZE
		card.custom_minimum_size = WAY_SIZE
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.focus_mode = Control.FOCUS_ALL
		card.draw.connect(_draw_way.bind(card, way))
		card.gui_input.connect(_on_way_input.bind(card, way))
		card.mouse_entered.connect(_on_way_hover.bind(way))
		card.mouse_exited.connect(_on_way_unhover.bind(way))
		card.focus_entered.connect(_on_way_focus)
		card.focus_exited.connect(_on_way_focus)
	# **`←` and `→` go between the two and no further**: no arrow leaves the
	# cards, as none leaves the ring. Tab goes on to `light`, as it does from
	# the ring's last slot, and back from the first card to the fork's chip,
	# which is where the tree already puts it.
	for way in _ways.size():
		var card := _ways[way]
		var other := _ways[1 - way]
		card.focus_neighbor_left = card.get_path_to(other if way == 1 else card)
		card.focus_neighbor_right = card.get_path_to(other if way == 0 else card)
		card.focus_neighbor_top = card.get_path_to(card)
		card.focus_neighbor_bottom = card.get_path_to(card)
	_ways[_ways.size() - 1].focus_next = _ways[_ways.size() - 1].get_path_to(
		_gain_slider)


## True while a fork's cards are up in place of the figure.
func _fork_open() -> bool:
	return _fork_gene != &""


## True when [param slot] carries a gene whose fork is open.
func _forks_at(slot: int) -> bool:
	var gene := _gene_at(slot)
	return slot >= 0 and gene != &"" and _genome.can_choose(gene)


## Every gene whose fork is open, in the order the tray stands their chips:
## the genome's own order of levelled genes.
func _open_forks() -> Array[StringName]:
	var out: Array[StringName] = []
	for gene: StringName in _genome.levels():
		if _genome.can_choose(gene):
			out.append(gene)
	return out


## Every level and gauge width, as one number that moves when either would
## change a pixel.
func _levels_sign() -> int:
	var sig := 0
	for gene: StringName in _genome.levels():
		var grown := _genome.progression(gene)
		sig += gene.hash() * (grown.level() * 64
			+ int(roundf(GAUGE_BAR.size.x * grown.progress())) + 1)
	return sig


## **In a pond the level moves under an open menu**, because the beam earns
## there (beam-levels.md §2): the chips, the fork's chip and the row are
## redrawn when a level or the gauge would change a pixel. Nothing rebuilds; a
## fork opening under the menu is [method _catch_up]'s, because the tray has a
## chip to grow.
func _step_levels_shown() -> void:
	var seen := _levels_sign()
	if seen == _levels_seen:
		return
	_levels_seen = seen
	_redraw_figure()
	_update_hint()
	if _fork_open():
		_reshape_way_fans()


## One chip per open fork, after the waiting genes (§8.3). **It neither drags
## nor takes a drop** -- no forwarding at all -- because what it opens is the
## cards, and a gene carried out of the tray must land on the figure.
func _make_fork_chip(gene: StringName) -> Control:
	var node := Control.new()
	node.name = "Fork_%s" % gene
	node.custom_minimum_size = Vector2(_fork_chip_width(gene), WAIT_SIZE.y)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.focus_mode = Control.FOCUS_ALL
	node.set_meta(&"fork", gene)
	node.draw.connect(_draw_fork_chip.bind(node, gene))
	node.gui_input.connect(_on_fork_chip_input.bind(node, gene))
	node.focus_entered.connect(node.queue_redraw)
	node.focus_exited.connect(node.queue_redraw)
	return node


## [constant WAIT_SIZE], and wider only for a name no word was written for --
## `venom 99`, the widest the game makes, ends at 111 of 116.
func _fork_chip_width(gene: StringName) -> float:
	var font := _tray.get_theme_default_font()
	var grown := _genome.progression(gene)
	if font == null or grown == null:
		return WAIT_SIZE.x
	var word := font.get_string_size(_word(gene), HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, CHIP_WORD).x
	var digits := font.get_string_size(str(grown.level()),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, _level_size(grown.level())).x
	return maxf(WAIT_SIZE.x, ceilf(FORK_WORD_X + word + FORK_LEVEL_GAP + digits
		+ WAIT_AIR))


## The fork's chip: the slot's fork, half size, then the gene's word and its
## level in its hue. Loud, and carrying the gene-in-hand mark, while its cards
## are up; stepped back, like every other chip in the tray, while a waiting
## gene is in hand.
func _draw_fork_chip(node: Control, gene: StringName) -> void:
	var grown := _genome.progression(gene)
	if grown == null:
		return
	var open := _fork_gene == gene
	var tone := Cilia.hue(gene)
	var ink := 1.0 if open or _hand() == &"" else WAIT_DIM
	node.draw_set_transform(FORK_GLYPH_AT
		- Vector2(FORK_GLYPH_FROM, CHIP_MID) * FORK_GLYPH_SCALE, 0.0,
		Vector2.ONE * FORK_GLYPH_SCALE)
	Cilia.draw_fork(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID, CHIP_AMP,
		FORK_GLYPH_FROM, FORK_TIPS, FORK_SPREAD, tone, ink)
	node.draw_set_transform(Vector2.ZERO)
	var font := node.get_theme_default_font()
	if font != null:
		var word := _word(gene)
		node.draw_string(font, Vector2(FORK_WORD_X, FORK_WORD_BASE), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_WORD,
			LABEL_TINT_LOUD if open else LABEL_TINT)
		var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			CHIP_WORD).x
		node.draw_string(font,
			Vector2(FORK_WORD_X + width + FORK_LEVEL_GAP, FORK_WORD_BASE),
			str(grown.level()), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			_level_size(grown.level()), Color(tone, LEVEL_FORK_ALPHA * ink))
	if open:
		node.draw_line(Vector2(6.0, FORK_OPEN_Y),
			Vector2(node.size.x - 6.0, FORK_OPEN_Y), Color(tone, 0.55), 1.5, true)
	if node.has_focus():
		node.draw_line(Vector2(FOCUS_INSET, WAIT_SIZE.y - 1.0),
			Vector2(node.size.x - FOCUS_INSET, WAIT_SIZE.y - 1.0),
			FOCUS_TINT, FOCUS_WIDTH, true)


## **A tap on the fork's chip opens its cards, and a second shuts them.** On the
## press: nothing here is irreversible, and the view is the chip's own. Enter
## opens with the keyboard on the first card.
func _on_fork_chip_input(event: InputEvent, node: Control,
		gene: StringName) -> void:
	if not _is_widget_tap(event):
		return
	node.accept_event()
	var frame := Engine.get_process_frames()
	if frame == _fork_chip_frame:
		return
	_fork_chip_frame = frame
	_primed = SLOT_NONE
	if _fork_gene == gene:
		_close_fork(false)
		return
	_open_fork(gene, not _is_pointer_press(event))


## Which gene's fork chip the keyboard is on, or &"".
func _focused_fork() -> StringName:
	for child in _tray.get_children():
		var chip := child as Control
		if chip != null and chip.has_focus():
			return StringName(chip.get_meta(&"fork", &""))
	return &""


## Puts the keyboard back on [param gene]'s fork chip after a rebuild, if it was
## there and the chip still is.
func _restore_fork_focus(gene: StringName) -> void:
	if gene != &"":
		_focus_fork_chip(gene)


## The keyboard onto [param gene]'s fork chip, or onto `resume` when there is
## none -- a fork just taken takes its chip with it.
func _focus_fork_chip(gene: StringName) -> void:
	for child in _tray.get_children():
		var chip := child as Control
		if chip != null and StringName(chip.get_meta(&"fork", &"")) == gene:
			chip.grab_focus()
			return
	_resume_button.grab_focus()


## **The cards come up in the figure's place.** Nothing can be armed or written
## while they are: the view hides every slot, so a slot armed for the gene in
## hand is disarmed and the hand is kept -- it comes back with the figure.
## [param by_key] puts the keyboard on the first card; a tap leaves it where it
## was, unless that was a slot, which has just been hidden, and then it goes to
## the fork's chip, the view's own way back.
func _open_fork(gene: StringName, by_key: bool) -> void:
	if not _genome.can_choose(gene):
		return
	if _armed >= 0 and _hand() != &"":
		_armed = SLOT_SAMPLE
		_armed_at = Time.get_ticks_msec()
	_primed = SLOT_NONE
	_hovered = SLOT_NONE
	_fork_gene = gene
	_way_armed = -1
	_way_primed = -1
	_way_hovered = -1
	_start_way_fans()
	_show_fork_view()
	var focused := get_viewport().gui_get_focus_owner()
	if by_key:
		_ways[0].grab_focus()
	elif focused == null or not focused.is_visible_in_tree():
		_focus_fork_chip(gene)
	_redraw_figure()
	_redraw_ways()
	_update_explain()
	_update_hint()


## **The cards go, nothing taken, and the figure comes back.** [param to_chip]
## sends the keyboard to the fork's chip -- `Esc`'s way back -- and so does a
## card that had it, which has just been hidden.
func _close_fork(to_chip: bool) -> void:
	if not _fork_open():
		return
	var gene := _fork_gene
	var had_focus := false
	for card in _ways:
		had_focus = had_focus or card.has_focus()
	_reset_fork_view()
	if to_chip or had_focus:
		_focus_fork_chip(gene)
	_redraw_figure()
	_update_explain()
	_update_hint()


## Back to the figure, with nothing armed on the cards. The menu opening and
## shutting both come through here, as does a fork that stopped being there.
func _reset_fork_view() -> void:
	_fork_gene = &""
	_way_armed = -1
	_way_primed = -1
	_way_hovered = -1
	_way_fans.clear()
	_show_fork_view()


## Exactly one of the two is visible, and they are the same size, so the column
## does not move when one takes over from the other. **`light` backs into
## whichever is showing**: Shift-Tab from it must not land on a hidden chip, or
## the keyboard is standing on something nobody can see.
func _show_fork_view() -> void:
	var open := _fork_open()
	_figure.visible = not open
	_fork_view.visible = open
	if open:
		_gain_slider.focus_previous = _gain_slider.get_path_to(
			_ways[_ways.size() - 1])
	else:
		_wire_focus()


func _redraw_ways() -> void:
	for card in _ways:
		card.queue_redraw()


## The path way [param way] stands for, &"" for none.
func _way_path(way: int) -> StringName:
	var grown := _genome.progression(_fork_gene) if _fork_open() else null
	if grown == null or way < 0 or way >= grown.paths.size():
		return &""
	return grown.paths[way]


## A way's name, from [constant PATH_TITLES]; a path this build has no word for
## is read by its own name rather than by nothing.
func _path_title(path: StringName) -> String:
	return String(PATH_TITLES.get(path, String(path)))


## **The way the lines below describe**: the one the mouse is over, then the one
## the keyboard is on -- `←` and `→` read the cards as hover does -- then the
## armed one, and -1 for none.
func _way_reading() -> int:
	if not _fork_open():
		return -1
	if _way_hovered >= 0:
		return _way_hovered
	for way in _ways.size():
		if _ways[way].has_focus():
			return way
	return _way_armed


## **The level the cards draw**: the next the gene will have, and never the fork
## itself -- at the fork both ways draw the same beam, three rays at rest, which
## is why the hint says a choice made there changes nothing until the next.
func _way_level() -> int:
	var grown := _genome.progression(_fork_gene) if _fork_open() else null
	if grown == null:
		return 0
	return maxi(grown.level(), grown.fork_level + 1)


## `[rays, half-span deg, sweep deg/s, reach]` for [param gene] at [param level]
## down [param path], or empty for a gene whose cards have no fan to show. The
## beam is the only gene that forks, and this is where it is named.
func _way_shape(gene: StringName, level: int, path: StringName) -> Array:
	if gene == &"ocellus":
		return CellBody.beam_shape(level, path)
	return []


## Each card's fan, from the shape its way gives at [method _way_level]. A
## sweeping way gets three more fans, each started one trail step behind the
## last, so its trail is where the ray really was.
func _start_way_fans() -> void:
	_way_fans.clear()
	var at := _way_level()
	for way in _ways.size():
		var fans: Array = []
		var shape := _way_shape(_fork_gene, at, _way_path(way))
		if not shape.is_empty():
			var copies := 1 + (WAY_TRAIL.size() if float(shape[2]) > 0.0 else 0)
			for k in copies:
				var fan := RayFan.new()
				fan.configure(int(shape[0]), deg_to_rad(float(shape[1])),
					deg_to_rad(float(shape[2])))
				fan.step(WAY_TRAIL_STEP * float(copies - 1 - k))
				fans.append(fan)
		_way_fans.append(fans)


## A level that rose under the open cards in a pond: the fans take the new shape
## and keep their place in their sweep.
func _reshape_way_fans() -> void:
	var at := _way_level()
	for way in mini(_way_fans.size(), _ways.size()):
		var shape := _way_shape(_fork_gene, at, _way_path(way))
		if shape.is_empty():
			continue
		for fan: RayFan in _way_fans[way]:
			fan.configure(int(shape[0]), deg_to_rad(float(shape[1])),
				deg_to_rad(float(shape[2])))


## **The cards, alive**: their fans step on this node's own frame delta, which
## a paused tree still hands it, and an armed way lapses on its own after
## [constant ARM_TIMEOUT_MS] -- the slot's rule, so a card left armed is not a
## trap. Not while a finger is holding its confirm.
func _step_fork_view(delta: float) -> void:
	if not _fork_open():
		return
	for fans: Array in _way_fans:
		for fan: RayFan in fans:
			fan.step(delta)
	if _way_armed >= 0 and _way_primed < 0 \
			and Time.get_ticks_msec() - _way_armed_at >= ARM_TIMEOUT_MS:
		_way_armed = -1
		_update_explain()
		_update_hint()
	_redraw_ways()


## **The two taps, on a card.** The first arms it, which is harmless and is how
## a thumb reads a way; a tap on the other card arms that one instead. The
## second, [constant ARM_GUARD_MS] or more later, takes it for good -- primed on
## the press and landing on the lift inside the card, so sliding off cancels.
## A key is not ambiguous and lands on the press.
func _on_way_input(event: InputEvent, card: Control, way: int) -> void:
	if _is_pointer_lift(event):
		card.accept_event()
		var was_primed := _way_primed == way
		_way_primed = -1
		if was_primed and Rect2(Vector2.ZERO, card.size).has_point(
				_pointer_at(event)):
			_choose_way(way)
		return
	if not _is_widget_tap(event):
		return
	card.accept_event()
	_way_primed = -1
	if _way_armed == way:
		# The guard, for the reason the slot gives: one thumb press arrives
		# twice, and the second copy must not take what the first just armed.
		if Time.get_ticks_msec() - _way_armed_at < ARM_GUARD_MS:
			return
		if _is_pointer_press(event):
			_way_primed = way
			return
		_choose_way(way)
		return
	_way_armed = way
	_way_armed_at = Time.get_ticks_msec()
	_redraw_ways()
	_update_explain()
	_update_hint()


func _on_way_hover(way: int) -> void:
	_way_hovered = way
	_update_explain()
	_update_hint()


func _on_way_unhover(way: int) -> void:
	if _way_hovered != way:
		return
	_way_hovered = -1
	_update_explain()
	_update_hint()


## The keyboard moved onto a card or off one: it reads the card it is on.
func _on_way_focus() -> void:
	_redraw_ways()
	if _fork_open():
		_update_explain()
		_update_hint()


## **A way, taken for good** (§8.3). The cards go and the figure comes back
## with that slot selected, as a receipt, the way a placement leaves one: its
## strands closed, its numeral pale, its tray chip gone and the tray holding
## its height. With a gene in hand the hand keeps the selection instead, since
## a slot armed for it without a tap on that slot would be one tap from writing
## over the gene that just grew.
##
## **The banked levels land at once**, and the eye flares for them on the first
## beat back in the water (§8.5). At the fork itself nothing lands: both ways
## start at the next level.
func _choose_way(way: int) -> void:
	var gene := _fork_gene
	var path := _way_path(way)
	var grown := _genome.progression(gene)
	if grown == null or path == &"":
		return
	var banked := grown.level() > grown.fork_level
	if not _genome.choose(gene, path):
		_close_fork(false)
		return
	if banked:
		_eye_gene = gene
		_eye_flare.arm()
	_reset_fork_view()
	var slot := _genome.layout().find(gene)
	if _hand() != &"":
		_armed = SLOT_SAMPLE
	elif slot >= 0:
		_armed = slot
	_armed_at = Time.get_ticks_msec()
	_hovered = SLOT_NONE
	_build_genome_strip()
	# The card that had the keyboard has gone; the slot that now reads the way
	# it took is where the player is.
	if slot >= 0:
		_restore_focus(slot)
	else:
		_resume_button.grab_focus()


## The hint while the cards are up (§8.3).
func _fork_hint() -> String:
	var grown := _genome.progression(_fork_gene)
	if grown == null:
		return ""
	var way := _way_reading()
	if way >= 0 and grown.paths.size() == 2:
		return HINT_COSTS % [_cost_words(way), _path_title(_way_path(1 - way))]
	if grown.level() > grown.fork_level:
		return HINT_WORKS_AS % grown.fork_level
	return HINT_BOTH_NEXT


## What way [param way] costs beside the other, at the level the cards draw --
## out of the gene's own prices.
func _cost_words(way: int) -> String:
	var at := _way_level()
	var mine := CellBody.levelled_upkeep(_fork_gene, at, _way_path(way))
	var theirs := CellBody.levelled_upkeep(_fork_gene, at, _way_path(1 - way))
	if is_equal_approx(mine, theirs):
		return COST_SAME
	return COST_MORE if mine > theirs else COST_LESS


## **One card**: the slab, opaque; the organ and the beam this way gives,
## rising out of it; its name, what it is good and bad at, and its price. Armed,
## a border in the gene's hue and the other card at [constant WAY_OTHER_INK].
## Hover restyles nothing, as on a chip: the lines below say which way is read.
func _draw_way(card: Control, way: int) -> void:
	var path := _way_path(way)
	if path == &"":
		return
	var gene := _fork_gene
	var tone := Cilia.hue(gene)
	var armed := _way_armed == way
	var ink := WAY_OTHER_INK if _way_armed >= 0 and not armed else 1.0
	var box := _way_box
	if armed:
		_way_box_armed.border_color = Color(tone, WAY_EDGE_ARMED_ALPHA)
		box = _way_box_armed
	card.draw_style_box(box, Rect2(Vector2.ZERO, card.size))
	Cilia.draw_tile_organ(card, gene, _copies_of(gene), WAY_ORGAN_AT,
		Cilia.TILE_STROKE_ALPHA * ink)
	_draw_way_beam(card, way, tone, ink)
	var font := card.get_theme_default_font()
	if font != null:
		var lines: Array = PATH_LINES.get(path, ["", ""])
		_draw_centred(card, font, _path_title(path), WAY_TITLE_BASE,
			WAY_TITLE_SIZE, Color(tone, WAY_TITLE_ALPHA * ink))
		_draw_centred(card, font, String(lines[0]), WAY_PRO_BASE, WAY_LINE_SIZE,
			Color(EXPLAIN_TINT, EXPLAIN_TINT.a * ink))
		_draw_centred(card, font, String(lines[1]), WAY_CON_BASE, WAY_LINE_SIZE,
			Color(EXPLAIN_TINT, EXPLAIN_TINT.a * ink))
		_draw_centred(card, font, _cost_words(way), WAY_COST_BASE,
			WAY_LINE_SIZE, Color(PALE, WAY_COST_ALPHA * ink))
	if card.has_focus():
		card.draw_line(Vector2(FOCUS_INSET, WAY_FOCUS_Y),
			Vector2(card.size.x - FOCUS_INSET, WAY_FOCUS_Y), FOCUS_TINT,
			FOCUS_WIDTH, true)


## The beam a way gives: still rays for a still way; for a sweeping one each
## ray's own share of the fan, faintly filled, and the ray with its trail.
func _draw_way_beam(card: Control, way: int, tone: Color, ink: float) -> void:
	if way >= _way_fans.size():
		return
	var fans: Array = _way_fans[way]
	if fans.is_empty():
		return
	var lead: RayFan = fans[0]
	if lead.sweep > 0.0 and lead.half_span > 0.0 and lead.count > 0:
		var width := 2.0 * lead.half_span / float(lead.count)
		for i in lead.count:
			var low := -lead.half_span + width * float(i)
			_draw_way_sector(card, low, low + width,
				Color(tone, WAY_SECTOR_ALPHA * ink))
		# Oldest first, so each copy lies under the one after it.
		for k in range(fans.size() - 1, 0, -1):
			var trail: RayFan = fans[k]
			for offset: float in trail.offsets():
				_draw_way_ray(card, offset, tone, ink * WAY_TRAIL[k - 1])
	for offset: float in lead.offsets():
		_draw_way_ray(card, offset, tone, ink)


## One ray, out of the organ at [param offset] radians from straight up: faint
## at the root, bright at a round tip.
func _draw_way_ray(card: Control, offset: float, tone: Color,
		ink: float) -> void:
	var dir := Vector2(sin(offset), -cos(offset))
	var tip := WAY_RAY_ROOT + dir * WAY_RAY_TO
	card.draw_polyline_colors(
		PackedVector2Array([WAY_RAY_ROOT + dir * WAY_RAY_FROM, tip]),
		PackedColorArray([Color(tone, WAY_RAY_ROOT_ALPHA * ink),
			Color(tone, WAY_RAY_TIP_ALPHA * ink)]), WAY_RAY_WIDTH, true)
	card.draw_circle(tip, WAY_RAY_DOT, Color(tone, WAY_RAY_TIP_ALPHA * ink),
		true, -1.0, true)


## A sweeping ray's share of the fan, from [param from] to [param to] radians,
## over the stretch its ray is drawn along.
func _draw_way_sector(card: Control, from: float, to: float,
		tint: Color) -> void:
	var points := PackedVector2Array()
	for i in WAY_SECTOR_STEPS + 1:
		var a := lerpf(from, to, float(i) / float(WAY_SECTOR_STEPS))
		points.append(WAY_RAY_ROOT + Vector2(sin(a), -cos(a)) * WAY_RAY_TO)
	for i in range(WAY_SECTOR_STEPS, -1, -1):
		var a := lerpf(from, to, float(i) / float(WAY_SECTOR_STEPS))
		points.append(WAY_RAY_ROOT + Vector2(sin(a), -cos(a)) * WAY_RAY_FROM)
	card.draw_colored_polygon(points, tint)


## One line of a card's words, centred across it on [param base].
func _draw_centred(card: Control, font: Font, text: String, base: float,
		size: int, tint: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		size).x
	card.draw_string(font, Vector2((card.size.x - width) * 0.5, base), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, tint)


# ---------------------------------------------------------------------------
# Placing a waiting gene without the pause screen (docs/design/dna-body.md §8).
#
# **Hold your own body, slide the gene out toward the side it should grow on,
# and let go.** The slot is the arc, so the gesture is literally *push it that
# way*: the direction chooses the slot, and the gene is the head of the queue --
# the one the body is already showing.
#
# **Free slots only, never an eviction.** Placing into an empty slot destroys
# nothing and a move can still change it, so one gesture is enough; the one
# irreversible action in the game keeps its two taps on the pause screen. With
# no free slot the body does not open, and a press on it is an ordinary steer.
#
# **The water keeps moving.** A pond cannot stop, and a shortcut that paused
# would be the pause screen again. The price is the flick: about 0.6 s under
# `anywhere`, when that finger is not steering, and about 0.25 s under `stick`
# and `pads`, where the other thumb still is. When to place becomes a choice,
# which is the game rather than a cost to design away.
#
# **Hand-hit-tested in `_input`, before the GUI and before cell.gd**, for the
# reason controls.gd gives at its top: no `Control` in the playfield and no
# `MOUSE_FILTER_STOP`. A pointer this claims is swallowed whole; one it has not
# claimed reaches cell.gd untouched.
# ---------------------------------------------------------------------------

## Under `anywhere` a finger resting on the body becomes this gesture after this
## long. Past cell.gd's TAP_SECONDS (0.28), so a tap on the body is still a
## dash, and a finger that moves first is still a steer. Owner's call 5.
const OFFER_HOLD := 0.35
## Further than this from where it pressed, before the hold, and the finger is
## steering: the gesture lets go of it for good. Stricter than cell.gd's
## TAP_SLOP (26) on purpose -- a slow lean that starts on the body has to read
## as the steer it is.
const OFFER_SLOP := 14.0
## The body's hit circle: its drawn radius and a little, and never a radius
## under [constant OFFER_HIT_MIN] canvas px. Full vision draws a born cell at
## r26, which alone would be a hit radius of 30; the floor keeps the target a
## thumb's at both views, and far over CLAUDE.md's 48 px.
const OFFER_HIT := 1.15
const OFFER_HIT_MIN := 56.0

## The finger on the body -- a touch index, or [constant POINTER_MOUSE] for a
## real mouse -- or [constant POINTER_NONE]. Under `anywhere` it is still
## steering until [constant OFFER_HOLD] has passed with it resting.
var _offer_pointer := POINTER_NONE
## The body is open: the bloom is drawn, and letting go places.
var _offer_open := false
## Opened by holding `E` rather than by a finger.
var _offer_key := false
## Where the finger pressed, and where it is now, in canvas px.
var _offer_from := Vector2.ZERO
var _offer_at := Vector2.ZERO
## Seconds the finger has rested, toward [constant OFFER_HOLD].
var _offer_clock := 0.0
## **True from the press until the first frame after it has been skipped.** The
## frame that delivers a press steps with the whole delta since the frame
## before, and most of that passed before the finger touched glass: summed in,
## a stall at the press -- a GC, a shader compiled on first use -- counted
## toward the hold, and one of 0.35 s opened the body on the first frame under
## a tap that then neither dashed (cell.gd times its tap on the wall clock, from
## the press) nor placed. Skipping that one delta keeps the hold measured from
## the press on the frame clock, which is what keeps a `--fixed-fps` run
## repeatable.
var _offer_fresh := false
## The free slot that is lit, or -1 for none -- a finger back inside the body.
var _offer_aim := -1
## **The gene the body opened for, held by name** -- the guarantee [member
## _in_hand] keeps on the pause screen. It is the head when the body opens, and
## if it stops being waiting while the body is open, nothing is placed.
var _offer_gene: StringName = &""
## **Which finger Godot's emulated mouse is following**, or [constant
## POINTER_NONE]. `emulate_mouse_from_touch` is on, so the first finger down
## arrives twice: as itself, and a moment before, as a mouse with `device`
## `DEVICE_ID_EMULATION`. cell.gd's one slot usually holds that mouse copy, so
## taking the finger off the steering means releasing its twin -- and only when
## it *is* its twin. **Read off the events, not assumed to be touch 0**: probed
## at 4.7, each emulated press, drag and release is dispatched just before the
## touch it copies, the copy follows whichever finger went down first, and a
## second finger gets none -- so the touch press after an emulated press is the
## finger it follows, and the emulated release is where it stops.
var _mouse_twin := POINTER_NONE
var _mouse_twin_next := false


## Whether the body can be held open at all.
func _offer_allowed() -> bool:
	if _life != Life.ALIVE or _menu_open or _replay != null:
		return false
	# The quickening still swims, and the daughters are rolled from the DNA as
	# it stands at the pinch, so a gene placed in it reaches them. From the
	# pinch on, the division owns every pointer.
	if _split >= Split.PINCH:
		return false
	# The pond's three still moments, when nothing is simulated.
	if _held or _water_beat >= 0.0 or _entering_held:
		return false
	return _genome.held_sample != &"" and not _offer_free().is_empty()


## The DNA's free slots, in slot order. The layout is exactly the figure's live
## slots -- earned, or inherited by a newborn -- so a hole in it is a slot the
## pause screen would take a gene into, and nothing outside it is.
func _offer_free() -> Array[int]:
	var out: Array[int] = []
	var layout := _genome.layout()
	for slot in mini(layout.size(), SLOT_SEAT.size()):
		if layout[slot] == &"":
			out.append(slot)
	return out


## `[centre, heading, radius]` of the player's body on the screen, in canvas px,
## from whichever view is drawing it; empty when neither can say.
func _offer_body() -> Array:
	return _vision.self_on_screen() if _vision_active() \
		else _soma.self_on_screen()


func _offer_hit(body: Array) -> float:
	return maxf(float(body[2]) * OFFER_HIT, OFFER_HIT_MIN)


func _offer_on_body(at: Vector2) -> bool:
	var body := _offer_body()
	return not body.is_empty() and at.distance_to(body[0]) <= _offer_hit(body)


## The free slot a finger at [param at] points at: the one whose bearing is
## nearest the finger's, **in the body's own frame**. So it follows the body and
## not the screen -- with the nose pointing east, a finger slid straight up
## lights the forward-port slot. Inside the hit circle it points at nothing, and
## letting go there places nothing: that is how a player changes their mind.
func _offer_aim_at(at: Vector2) -> int:
	var body := _offer_body()
	if body.is_empty():
		return -1
	var reach: Vector2 = at - body[0]
	if reach.length() <= _offer_hit(body):
		return -1
	var bearing := atan2(reach.x, -reach.y) - float(body[1])
	var best := -1
	var best_off := INF
	for slot in _offer_free():
		var off := absf(angle_difference(bearing, Cilia.slot_bearing(slot)))
		if off < best_off:
			best_off = off
			best = slot
	return best


## The keyboard's first aim: the free slot nearest the nose, and the starboard
## one when two are level -- the forward diagonals are mirror images, and the
## first aim should be the same slot every time.
func _offer_default() -> int:
	var best := -1
	var best_off := INF
	for slot in _offer_free():
		var bearing := Cilia.slot_bearing(slot)
		var off := absf(bearing) - (0.001 if bearing > 0.0 else 0.0)
		if off < best_off:
			best_off = off
			best = slot
	return best


## One step round the body through the free slots: clockwise for +1, which is
## `D` and the right arrow -- the way a nose-up body turns to starboard.
func _offer_walk(step: int) -> void:
	var free := _offer_free()
	if free.is_empty():
		return
	free.sort_custom(_offer_clockwise)
	var at := free.find(_offer_aim)
	_offer_aim = free[posmod(at + step, free.size())] if at >= 0 else free[0]


func _offer_clockwise(a: int, b: int) -> bool:
	return wrapf(Cilia.slot_bearing(a), 0.0, TAU) \
		< wrapf(Cilia.slot_bearing(b), 0.0, TAU)


## Opens the body. The bloom is drawn from this frame's `_process`, and the
## finger that opened it stops steering -- that finger and no other.
func _offer_begin() -> void:
	_offer_open = true
	_offer_gene = _genome.held_sample
	_offer_aim = _offer_default() if _offer_key else _offer_aim_at(_offer_at)
	if _offer_key:
		# `A` and `D` walk the lit slot while `E` is down, so they must not also
		# turn the cell; `steering_off` silences the keys cell.gd polls itself.
		# Flipped with the release and the let-go, both ways round, as cell.gd
		# asks of whoever flips it.
		_cell.steering_off = true
		_cell.release()
		_controls.let_go()
		return
	# **Only this finger stops steering.** A thumb steering elsewhere keeps its
	# turn: releasing the whole cell was measured taking a second finger's press
	# on the body as a reason to drop the first finger's steer, +0.42 to 0.
	# Under `stick` and `pads` cell.gd never grabs a press that misses the drawn
	# controls, so neither of these finds anything to let go of.
	_cell.release_pointer(_offer_pointer)
	if _offer_pointer >= 0 and _offer_pointer == _mouse_twin:
		_cell.release_pointer(POINTER_MOUSE)


## Shuts the body, and places the gene first when [param place] says so and the
## genome still allows it.
func _offer_close(place: bool) -> void:
	if place and _offer_open:
		_offer_place()
	if _offer_key:
		# Handed back as the menu would have it: a menu open over a live pond
		# is the one other thing that holds the cell deaf.
		_cell.steering_off = _menu_open and _session_up()
		_cell.release()
		_controls.let_go()
	_offer_open = false
	_offer_key = false
	_offer_pointer = POINTER_NONE
	_offer_aim = -1
	_offer_clock = 0.0
	_offer_fresh = false
	_offer_gene = &""
	# Now, not on the next frame: a death draws its first frame of collapse
	# this one, and the bloom must not be on it.
	_soma.offer = {}
	_vision.offer = {}


## **Into the slot that is lit, if it is still free, and the gene the body
## opened for, if it is still waiting** -- both asked now, never remembered from
## the press. The water keeps moving under a held finger, and the gene can lapse
## into the first free slot a frame before the lift. Then nothing is written:
## the pause screen's own guarantee (#118), that a gene which lapsed in hand
## never lets a gesture place a different one.
func _offer_place() -> void:
	var slot := _offer_aim
	var which := _genome.waiting_index(_offer_gene)
	if slot < 0 or which < 0 or not _offer_free().has(slot):
		return
	_genome.place(slot, which)


## Called first in `_input`. True when the event was this gesture's, and then
## nothing after it -- the GUI, cell.gd, the drawn controls -- sees it at all.
func _offer_input(event: InputEvent) -> bool:
	# The emulated mouse before anything can return: which finger it follows
	# has to be known whether or not the body can open right now.
	if event.device == InputEvent.DEVICE_ID_EMULATION and (
			event is InputEventMouseButton or event is InputEventMouseMotion):
		return _offer_emulated(event)
	if _mouse_twin_next and event is InputEventScreenTouch \
			and (event as InputEventScreenTouch).pressed:
		_mouse_twin = (event as InputEventScreenTouch).index
		_mouse_twin_next = false
	if not _offer_allowed():
		if _offer_open or _offer_pointer != POINTER_NONE:
			_offer_close(false)
		return false
	if event is InputEventKey:
		return _offer_keys(event as InputEventKey)
	return _offer_pointer_input(event)


## One of Godot's emulated mouse events: the finger in [member _mouse_twin],
## seen twice. Swallowed when that finger is holding the body open -- it is the
## same gesture, and cell.gd must not see half of it -- and passed on untouched
## otherwise: every other finger, and every press, which arrives before its
## touch and before anything can say whose it is.
func _offer_emulated(event: InputEvent) -> bool:
	var ours := _offer_open and _offer_pointer >= 0 \
		and _offer_pointer == _mouse_twin
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return false
		if click.pressed:
			_mouse_twin_next = true
			return false
		_mouse_twin = POINTER_NONE
	return ours


## `E` held opens the body; `A` / `D` or the arrows walk the lit slot round it;
## letting go of `E` places. `Esc` cancels any open body, keyed or held by a
## finger, and is then not also a pause.
func _offer_keys(key: InputEventKey) -> bool:
	if key.keycode == KEY_E or key.physical_keycode == KEY_E:
		if key.echo:
			return _offer_key
		if key.pressed:
			# A finger has the body already, or is resting on it; the key does
			# not take it from them.
			if _offer_open or _offer_pointer != POINTER_NONE:
				return false
			_offer_key = true
			_offer_begin()
			return true
		if _offer_key:
			_offer_close(true)
			return true
		return false
	if _offer_open and key.pressed and not key.echo \
			and key.keycode == KEY_ESCAPE:
		_offer_close(false)
		return true
	if not _offer_key:
		return false
	var step := 0
	if key.keycode == KEY_A or key.keycode == KEY_LEFT:
		step = -1
	elif key.keycode == KEY_D or key.keycode == KEY_RIGHT:
		step = 1
	if step == 0:
		return false
	# One step a press. The repeats and the release are swallowed too: the
	# arrows are `ui_left` and `ui_right` as well, and nothing else should read
	# them while `E` is down.
	if key.pressed and not key.echo:
		_offer_walk(step)
	return true


## A finger or a real mouse: pressed on the body, rested, slid, let go.
func _offer_pointer_input(event: InputEvent) -> bool:
	# While `E` has the body, a finger is whatever it would have been.
	if _offer_key:
		return false
	var index := _pointer_index(event)
	if index == POINTER_NONE:
		return false
	var at := Vector2.ZERO
	var press := false
	var lift := false
	# **A touch the system took back is not a let-go.** Android cancels a
	# gesture for palm rejection, a system overlay or an OEM swipe, and Godot
	# delivers that as a release with `canceled` set. Read as a lift it placed
	# the gene into whatever slot happened to be lit -- a placement the player
	# never finished, and for the gift an organ fixed on this body at that arc.
	var canceled := false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		at = touch.position
		press = touch.pressed
		lift = not touch.pressed
		canceled = touch.canceled
	elif event is InputEventScreenDrag:
		at = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return false
		at = click.position
		press = click.pressed
		lift = not click.pressed
	else:
		var moved := event as InputEventMouseMotion
		if (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return false
		at = moved.position
	if press:
		# One finger holds the body. Any other is whatever it would have been:
		# the other thumb on the stick, or a steer.
		if _offer_pointer != POINTER_NONE or not _offer_on_body(at):
			return false
		_offer_pointer = index
		_offer_from = at
		_offer_at = at
		_offer_clock = 0.0
		_offer_fresh = true
		if _floating():
			# `anywhere`: a steer until the hold says otherwise. It goes on to
			# cell.gd, so a tap on the body is still a dash.
			return false
		# `stick` and `pads`: the water is inert under them, so a press on the
		# body means nothing else, and it opens at once.
		_offer_begin()
		return true
	if index != _offer_pointer:
		return false
	_offer_at = at
	if lift:
		if _offer_open:
			_offer_close(not canceled)
			return true
		# Let go before the hold: a tap or a short press, and cell.gd's.
		_offer_pointer = POINTER_NONE
		return false
	if _offer_open:
		_offer_aim = _offer_aim_at(at)
		return true
	if at.distance_to(_offer_from) > OFFER_SLOP:
		# Moved before the hold: a steer, and cell.gd's for good.
		_offer_pointer = POINTER_NONE
	return false


## Once a frame, before anything in `_process` can return: shutting the body
## when it can no longer be open, the hold's clock, the aim under a finger that
## is still while the body turns, and the bloom handed to both views.
func _step_offer(delta: float) -> void:
	if (_offer_open or _offer_pointer != POINTER_NONE) and (not _offer_allowed()
			or (_offer_open and _genome.held_sample != _offer_gene)):
		# A death, a menu, the pinch, a held pond -- or the gene lapsed while
		# the body was open. It shuts, and nothing is placed.
		_offer_close(false)
	if _offer_pointer != POINTER_NONE and not _offer_open:
		if _offer_fresh:
			_offer_fresh = false
		else:
			_offer_clock += delta
		if _offer_clock >= OFFER_HOLD:
			_offer_begin()
	if _offer_open:
		if _offer_key:
			if not _offer_free().has(_offer_aim):
				_offer_aim = _offer_default()
		else:
			# The body turns and, in full vision, drifts under a finger that has
			# not moved, and the slot lit is the one it points at now.
			_offer_aim = _offer_aim_at(_offer_at)
	var state := {}
	if _offer_open:
		state = {"aim": _offer_aim,
			"copies": _genome.waiting_copies(_offer_gene)}
	_soma.offer = state
	_vision.offer = state


# ---------------------------------------------------------------------------
# Choosing a daughter (docs/design/choosing.md)
#
# **Two vertical strands, one outboard of each daughter, drawn by the same code
# the pause screen's chips are** -- `Cilia.draw_weave`, its lens and its rungs.
# The pause screen drew a horizontal strand of its own until it drew the body
# instead (dna-body.md); this screen keeps its strands for now, and §9 there is
# why and what comes next. The owner's ask was that the choice be
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
# learns all of that on the pause screen and spends it here** -- all but the
# dart, which the pause screen no longer draws: there the arc is where the chip
# sits on the body. The only new mark is the caret (§6), and it exists because
# the expression roll would otherwise be indistinguishable from the mutation.
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
# - **One lobe per locus, at 48 px.** The pause strand was 800 canvas px wide and
#   the space beside a daughter is 335; it did not fit at either shape, so the
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
## than starting mid-lens. One each, against the old pause strand's two,
## because there is no held sample to park off the head of this one.
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
## The weave's axis and its swing, inside the block. The swing is the one the
## pause strand had before the pause screen drew the body (dna-body.md): same
## helix, different pitch, and kept so this screen did not change with it.
const CHOOSE_HELIX_MID := 34.0
const CHOOSE_HELIX_AMP := 18.0
## Left to right inside a block: the caret, the weave at 16 .. 52, the dart, the
## word. The word gets everything from [constant CHOOSE_WORD_X] to the block's
## edge.
const CHOOSE_DART_X := 66.0
## **The word budget, measured, because it is the number this block ran out of
## once already.** `CHOOSE_BLOCK_W - CHOOSE_WORD_X` = **47 px**, and at
## [constant LABEL_SIZE] 13 in the fallback font the widest of
## [constant WORDS]'s sixteen is `venom` at **44.00**. Three pixels of tail,
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
## screen's own *never nothing* rule -- a surface that opens blank has to teach
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
## sixteen gene lines are about the gene, and both strands carry the same gene
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
	# **The way her mother took, if she took one** (beam-levels.md §8.6): a
	# daughter inherits the path with the level, and an open fork reads as no
	# path yet.
	var says := _explains(gene)
	_choose_line.text = "" if says.is_empty() else "· " + says
	var register := CHOOSE_WORN if _choose_worn else CHOOSE_CARRIED
	var odds := HINT_CERTAIN if GenomeNode.ALWAYS_EXPRESSED.has(gene) \
		else HINT_CHANCE[clampi(int(found[1]), 0, HINT_CHANCE.size() - 1)]
	# **The level goes in the line, not on the strands** (§8.6): both daughters
	# carry the same level for every gene they share, so a mark on both strands
	# would say it twice. `worn · level 7 · one copy · a daughter may not wear
	# it`; the widest, 400 px, centres clear of both blocks.
	var level := _choose_level(gene)
	if level > 0:
		_choose_hint.text = "%s · %s · %s" % [register, HINT_LEVEL % level, odds]
	else:
		_choose_hint.text = "%s · %s" % [register, odds]


## **The level a daughter's gene will have**, which is her mother's -- the level
## is the lineage's (beam-levels.md §3) -- or 1 for a gene that drifted in,
## which the lineage never carried. 0 for a gene that does not level.
func _choose_level(gene: StringName) -> int:
	if not CellBody.LEVELLED.has(gene):
		return 0
	var grown := _genome.progression(gene)
	return grown.level() if grown != null else 1


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
## file's own precedent -- `PauseTap` and the pause screen's slots both consume
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


# ---------------------------------------------------------------------------
# **The shared pond** (shared-pond.md §1.5-§1.8, shared-pond-ux.md §0-§6).
#
# One water, two cells. The host's field is the water and a guest's field is a
# mirror of it. What is here is the run's half: the lifecycle -- entering,
# returning, dividing, dying, held and taken over -- the beat that says the
# water changed, and the line of text. `pond.gd` is the wire's half and
# `food.gd` owns every rule. A run with no session never reaches any of it:
# every entry point below is behind [member _pond], which is null there.
# ---------------------------------------------------------------------------

## The eight lines (UX §0.4), each a fact about another person no sense can
## carry.
const LINE_THEIRS := "you are in their water"
const LINE_YOURS := "they are in your water"
const LINE_DIED := "they died · they come back near you"
const LINE_ATE := "you ate them · they come back near you"
const LINE_QUIET := "their phone went quiet"
const LINE_GONE := "their water is gone · this one is yours"
## The same moment when the host did not go but hung up on this game -- its gate
## or its referee (net-hardening.md B), `REFUSE_BROKEN` -- so a player who was
## cut is not told the host left.
const LINE_CUT := "cut off from their water · this one is yours"
const LINE_LEFT := "they left"
## A born cell's layout, for the body a guest asks to arrive as from the black:
## genome.gd's own reset, written out because the body has not been reset yet.
const BORN_ORDER: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum"]

## The vision was switched back on half way through the beat.
var _beat_in := false
## The key of the line the beat says when it ends.
var _beat_key := ""
## What the pond line on the label says, so a line that replaced it is noticed.
var _line_shown_text := ""


## **Is a session up** (shared-pond.md §1.7): the link is together, or this is
## a host still taking calls. Pause stops nothing while it is -- wider than
## "while a friend is in the pond", on purpose: the host's water has to keep
## running to take a dead friend back, and a guest's paused tree would stop its
## own reports. A guest whose host has gone is alone again, and pauses as ever.
func _session_up() -> bool:
	if _net == null or not is_instance_valid(_net):
		return false
	var link := int(_net.link)
	return link == NetSession.Link.TOGETHER \
		or (bool(_net.hosting) and link == NetSession.Link.LISTENING)


## **The run's first frame in a session.** A host's water becomes the pond. A
## guest whose host's pond is already open opens inside it, held for the round
## trip (§1.6) -- no swap and no beat: the run opens as today, and says so once
## it has been placed. A guest whose host is not there yet swims alone and
## swaps in when the pond opens.
func _begin_pond() -> void:
	if _pond.hosting:
		_food.open_pond()
		_ponded = true
		return
	if not _pond.together() or not _net.peer_pond_open():
		return
	_food.become_mirror()
	_pond.mirror_began()
	_ponded = true
	_entering_held = true
	_update_simulating()
	_pond.enter(_cell.radius, _genome.tiers(), _genome.body_layout())


## **Once a frame, before every early return.** The wire's intake, the two bits
## the far end reads, and the lifecycle that runs whatever this cell is doing.
func _step_pond(delta: float) -> void:
	_run_clock += delta
	_pond.step()
	var member := _food.pond_open() if _pond.hosting \
		else (_food.mirroring() and _pond.in_pond)
	if is_instance_valid(_net):
		_net.set_pond(member, member and not _food.in_water)
	if not _pond.hosting:
		_step_guest_pond()
	_step_quiet()
	_step_water_beat(delta)
	if _held or _water_beat >= 0.0 or _entering_held:
		# The live branch is not running in any of the pond's still moments,
		# and the line is the one thing that still has something to do: a line
		# that just stopped being true -- `you are in their water`, the moment
		# that water goes -- fades out through the beat instead of standing on
		# screen for the whole of it. Asked after the beat has stepped, which is
		# the test the live branch asks, so no frame steps the label twice.
		_step_onboarding(delta)
	_step_lines()


## The guest's side: the link going, an ENTER nobody answered, the swap into a
## pond that has opened, and the pond held while the host is quiet.
func _step_guest_pond() -> void:
	var mirror := _food.mirroring()
	if not _pond.together():
		if mirror or _pond.entering or _swap_pending or _entering_held:
			_take_over()
		elif _menu_open and not get_tree().paused:
			# **Swimming alone when the host went, with the menu open** (§1.7):
			# nothing takes over, so nothing closes the menu -- and a menu that
			# was open over a live session is the shipped pause again, so the
			# tree stops under it, exactly as a menu opened now would. Left
			# alone, the water ran on under a menu this run no longer steps.
			_set_menu(true)
		return
	if _pond.entering and _pond.entering_for() >= NetSession.REACH_TIMEOUT:
		_enter_timed_out()
	# **A guest swimming alone when the pond opens swaps in** at the next
	# ordinary frame -- not dead, dividing, mid-beat or in the menu (§1.6).
	if not mirror and not _pond.entering and _net.peer_pond_open() \
			and _life == Life.ALIVE and _split == Split.NONE and not _menu_open \
			and _water_beat < 0.0:
		_swap_pending = true
		_pond.enter(_cell.radius, _genome.tiers(), _genome.body_layout())
	# **Held** (UX §5): the pond lives on the host's phone, so when that phone
	# goes quiet the pond stops. Only an ordinary frame is held -- a division
	# or a death goes on as it would.
	var hold := mirror and _pond.in_pond and _life == Life.ALIVE \
		and _split == Split.NONE and _water_beat < 0.0 and not _entering_held \
		and _pond.quiet_for() >= VisionLayer.PEER_FRESH
	if hold != _held:
		_set_held(hold)


## An ENTER that has waited [constant NetSession.REACH_TIMEOUT] for its ARRIVE.
func _enter_timed_out() -> void:
	_pond.mirror_ended()
	if _entering_held:
		# No answer: the run opens alone (§1.6).
		_entering_held = false
		_food.leave_mirror()
		_ponded = false
		_update_simulating()
	elif _wake_pending:
		# A tap nobody answered swims on alone, as a solo return does.
		_wake_pending = false
		_food.leave_mirror()
		_return([])
	else:
		# A swap nobody answered is tried again at the next ordinary frame.
		_swap_pending = false


## **The host put this cell in its water** (§1.6).
func _on_pond_arrived(at: Vector2, heading: float) -> void:
	if _wake_pending:
		_wake_pending = false
		_pond.in_pond = true
		_return([at, heading])
		return
	if _entering_held:
		_entering_held = false
		_place_arrival(at, heading)
		_motes.setup(_cell)
		_update_simulating()
		_pond_say("theirs", LINE_THEIRS, ONBOARD_DELAY)
		return
	if _swap_pending:
		_swap_pending = false
		if _life != Life.ALIVE or _split != Split.NONE or _menu_open:
			# **Not an ordinary frame any more** (UX §1: never dead, dividing
			# or in the menu): the cell died, began to divide or opened the
			# menu in the round trip -- and the beat would stop the water under
			# a death or a division that own it, or change the water under a
			# menu that is up. The swap is dropped. This run's POND bit never
			# goes up, so the host lets the body it placed go after
			# REACH_TIMEOUT, and the swap is asked again at the next ordinary
			# frame, or by the tap on the black.
			_pond.mirror_ended()
			return
		_begin_water_beat(_swap_in.bind(at, heading), VisionLayer.FADE_SECONDS,
			"theirs", LINE_THEIRS)


## **The swap, at the beat's dark middle** (§1.6, UX §1): this water becomes a
## mirror of the host's and the cell is placed where the host put it, keeping
## its body, its genome, its generation and its hunger.
func _swap_in(at: Vector2, heading: float) -> void:
	_food.become_mirror()
	_pond.mirror_began()
	_ponded = true
	_place_arrival(at, heading)
	_motes.setup(_cell)


func _place_arrival(at: Vector2, heading: float) -> void:
	_cell.position = at
	_cell.heading = heading
	_cell.velocity = Vector2.ZERO
	_pond.in_pond = true
	# Reported now, so the first state frame that says this cell is in the pond
	# carries this place and not the one it left.
	_tell_others()


## **A guest wakes into the host's pond** (owner's row A, UX §4): the tap asks
## where, as the born cell it is about to be, and the black holds for the
## round trip. A guest that died swimming alone begins the mirror here.
func _enter_from_black() -> void:
	if _wake_pending:
		return
	if not _food.mirroring():
		_food.become_mirror()
		_pond.mirror_began()
		_food.leave_water(true)
		_ponded = true
		# A mirror's water runs under the black, as the host's does.
		_update_simulating()
	_wake_pending = true
	_pond.enter(CellBody.BASE_RADIUS, GenomeNode.BORN, BORN_ORDER)


## **Where the host comes back from the black** (owner's row A): near its
## friend -- alive, or where they last were -- by the arrival rule; with no
## friend ever in the pond, where it died. Empty for anything but a pond host,
## which is every other return, where a new cell goes where it always has.
func _home_after_black() -> Array:
	if _pond == null or not _pond.hosting or not _food.pond_open():
		return []
	var friend: Array = _pond.friend_place()
	if not bool(friend[1]):
		return []
	return [_pond.arrival_point(friend[0], CellBody.BASE_RADIUS), 0.0]


## **The declined daughter, in a pond** (§1.5): a host leaves her in its own
## water, in a free slot; a guest's water is the host's, so it asks the host to.
func _leave_sister(bearing: float, body: Dictionary) -> void:
	if _pond.hosting:
		_food.put_sister(bearing, SISTER_DISTANCE, _cell.radius, body)
		return
	var dir := _cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)
	_pond.sister(_cell.position + dir * SISTER_DISTANCE, atan2(dir.x, -dir.y),
		_cell.radius, body)


## **The host is gone, and this water is yours** (§1.8, UX §5): fresh water
## round this cell, which keeps its body, its genome, its generation and its
## hunger -- `leave_mirror()` is the same `setup()` every new water is. Said
## once. Pause is ordinary again, so the menu closes if it was open.
func _take_over() -> void:
	var was_in := _food.mirroring()
	var gone_line := LINE_CUT if _pond.cut_off() else LINE_GONE
	_pond.mirror_ended()
	_swap_pending = false
	if _held:
		_set_held(false)
	if _menu_open:
		_set_menu(false)
	if _entering_held:
		_entering_held = false
		_food.leave_mirror()
		_ponded = false
		_update_simulating()
		return
	if _wake_pending:
		_wake_pending = false
		_food.leave_mirror()
		_return([])
		return
	if not was_in:
		return
	if _life != Life.ALIVE or _split >= Split.PINCH:
		# No beat for a cell that is not swimming: on the black or between two
		# daughters it meets the fresh water when it comes back, and a solo
		# water stands still under both, as it always has -- and a cell still
		# RETURNING is in it already, simulated from its tap, with the aperture
		# opening round it as it would on any new water. Which of those this
		# is, _update_simulating() reads off the cell: before, this stopped the
		# water outright and left a returning cell alive in a water that never
		# moved again.
		_food.leave_mirror()
		_update_simulating()
		_pond_say("gone", gone_line)
		return
	_begin_water_beat(_food.leave_mirror, 0.0, "gone", gone_line)


## **Held, or heard again** (UX §5). Held, nothing of this cell moves --
## simulation, water and every sensation stop, the beat goes on -- and the
## world dims with the view's own fade while this cell is drawn outside it.
func _set_held(on: bool) -> void:
	_held = on
	_update_simulating()
	if on:
		_cell.release()
		_controls.let_go()
		_hush()
	_vision.set_held(on)
	_update_dim()
	_update_warn()


## **How bright the world is allowed to be, from everything that dims it**:
## two daughters on screen, as ever; in a pond, this cell's own division from
## the pinch, where it leaves the water (UX §2); and a held pond. In single
## player only the first is ever true, which is the shipped line exactly.
func _update_dim() -> void:
	var pond := _food.pond_open()
	var out := pond and _split >= Split.PINCH
	_vision.set_dim(DIVIDE_WORLD_FADE
		if _division.has("bodies") or _held or out else 1.0)
	_vision.own_full = _held or out


## The warning over `resume` is true while the menu is open over a live pond,
## and false while that pond is held (UX §6).
func _update_warn() -> void:
	_warn.visible = _menu_open and _session_up() and not _held


# --- The water changes (UX §0.5) -----------------------------------------------

## **One beat, for entering and for swimming on alone**: every sensation lets
## go, the world goes out and back in through the view's own fade with the
## camera snapped between, and the aperture opens over DEATH_RETURN as it does
## on every new water. It never closes first, because closing means death.
## [param swap] runs at [param swap_at] seconds: the dark middle for a swap,
## at once for a takeover, which must not leave a cell in a water that has gone.
func _begin_water_beat(swap: Callable, swap_at: float, key: String,
		line: String) -> void:
	_water_beat = 0.0
	_beat_swap = swap
	_beat_swap_at = swap_at
	_beat_swapped = false
	_beat_in = false
	_beat_key = key
	_beat_line = line
	_update_simulating()
	_cell.release()
	_controls.let_go()
	_hush()
	_vision.set_active(false)
	if swap_at <= 0.0:
		_run_beat_swap()


func _run_beat_swap() -> void:
	_beat_swapped = true
	if _beat_swap.is_valid():
		_beat_swap.call()
	# Whatever the water is now, it runs through the rest of the beat:
	# _update_simulating() reads `_beat_swapped`.
	_update_simulating()


## **The beat, cut short by a death** (from [method _die], and only from
## there): the swap happens if it has not, so the cell dies in the water it was
## being put in; the world comes back so the collapse can take it the way it
## takes every death; and the beat's line goes into the queue, where the black
## holds it until the next cell. Nothing is restarted -- the caller's
## [method _update_simulating] sees a dead cell.
func _end_water_beat() -> void:
	if not _beat_swapped:
		_run_beat_swap()
	_water_beat = -1.0
	if not _beat_in:
		_vision.set_active(_vision_active())
	if not _beat_line.is_empty():
		_pond_say(_beat_key, _beat_line)


func _step_water_beat(delta: float) -> void:
	if _water_beat < 0.0:
		return
	_water_beat += delta
	if not _beat_swapped and _water_beat >= _beat_swap_at:
		_run_beat_swap()
	if _beat_swapped and not _beat_in and _water_beat >= VisionLayer.FADE_SECONDS:
		_beat_in = true
		_vision.set_active(_vision_active())
	_bus.revive(minf(_water_beat, SignalBus.DEATH_RETURN))
	if _water_beat < SignalBus.DEATH_RETURN:
		return
	# Only a living cell reaches this line: a death inside the beat ends it
	# (_end_water_beat), and a division cannot begin inside one -- the live
	# branch that starts them does not run while it does.
	_water_beat = -1.0
	if not _beat_in:
		_vision.set_active(_vision_active())
	_update_simulating()
	_bus.set_beat(_metabolism.beat_period(), _metabolism.beat_amplitude())
	_bus.pulse_now()
	if not _beat_line.is_empty():
		_pond_say(_beat_key, _beat_line)


# --- The friend, and the line (UX §0.4, §1-§5) ----------------------------------

## Host: a guest has just been put in this water. The line waits out the
## arrival fade and is said the first time only: a friend coming back from the
## black has already been told about.
func _on_friend_entered() -> void:
	_friend_dead = false
	if not _friend_ever:
		_friend_ever = true
		_pond_say("yours", LINE_YOURS, SignalBus.DEATH_RETURN)


## Either seat: the other player's cell died, and how decides what is drawn
## (UX §3) and which line is said.
func _on_friend_died(cause: int, _by: int, at: Vector2, eaten_by_me: bool) -> void:
	_friend_dead = true
	var how: int = VisionLayer.Gone.EATEN
	if eaten_by_me:
		how = VisionLayer.Gone.EATEN_BY_YOU
	elif cause == FoodField.Cause.STARVED:
		how = VisionLayer.Gone.STARVED
	_vision.friend_gone(how, at)
	_pond_say("dead", LINE_ATE if eaten_by_me else LINE_DIED)


## Host: the guest is gone from this water.
func _on_friend_left() -> void:
	_friend_dead = false
	_friend_ever = false
	_vision.friend_gone(VisionLayer.Gone.LEFT, Vector2.ZERO)
	_pond_say("left", LINE_LEFT)


## Either seat: the other player has a new body -- back from the black, or born.
func _on_friend_renewed() -> void:
	_friend_dead = false


## "their phone went quiet" at SILENCE, once for each silence (UX §0.4, §5).
func _step_quiet() -> void:
	var present := _pond.together() and (
		(_pond.hosting and _food.person() != null)
		or (not _pond.hosting and _pond.in_pond))
	if present and _pond.quiet_for() >= NetSession.SILENCE:
		if not _quiet_said:
			_quiet_said = true
			# No timer: it goes when they are heard.
			_pond_say("quiet", LINE_QUIET, 0.0, 0.0)
	else:
		_quiet_said = false


## **Into the one-slot queue**, where the newest wins (UX §0.4). [param key]
## names the fact it reports; [param delay] is how long before it may be said
## and [param hold] how long it stays, 0 for until it stops being true.
func _pond_say(key: String, text: String, delay: float = 0.0,
		hold: float = SENSE_LINE_HOLD) -> void:
	_line_key = key
	_line_text = text
	_line_after = _run_clock + delay
	_line_hold = hold


## Is the fact a line reports still true.
func _line_true(key: String) -> bool:
	match key:
		"theirs":
			return _food.mirroring() and _pond.in_pond
		"yours":
			return _food.person() != null
		"dead":
			return _friend_dead
		"quiet":
			return _pond.together() and _pond.quiet_for() >= NetSession.SILENCE
		"left":
			return _food.person() == null
	return true


## **The line, when the label is free.** It never covers the steering line, a
## division, the black, the replay, the open menu or the beat; it waits in one
## slot, and it is dropped -- or faded out early -- the moment what it reports
## stops being true.
func _step_lines() -> void:
	if not _line_shown.is_empty():
		if _onboard == Onboard.OFF or _onboarding.text != _line_shown_text:
			_line_shown = ""
		elif not _line_true(_line_shown):
			if _onboard != Onboard.FADE_OUT:
				_onboard_from = _onboarding.modulate.a
				_onboard_clock = 0.0
				_onboard = Onboard.FADE_OUT
			_line_shown = ""
	if _line_key.is_empty():
		return
	if not _line_true(_line_key):
		_line_key = ""
		return
	if _run_clock < _line_after:
		return
	# A division from its pinch (UX §0.4): the quicken still swims, and a meal
	# big enough to start one is when `you ate them` is due.
	if _menu_open or _split >= Split.PINCH or _life != Life.ALIVE \
			or _replay != null or _water_beat >= 0.0:
		return
	if _onboard != Onboard.OFF:
		# **The newest wins on the label too**: a pond line still up is an
		# older fact about the same person, so it makes way early, the way an
		# untrue one does. Anything else on the label -- the steering line, a
		# sense arriving -- is waited out.
		if not _line_shown.is_empty() and _onboard != Onboard.FADE_OUT:
			_onboard_from = _onboarding.modulate.a
			_onboard_clock = 0.0
			_onboard = Onboard.FADE_OUT
			_line_shown = ""
		return
	_say(_line_text, _line_hold)
	_line_shown = _line_key
	_line_shown_text = _line_text
	_line_key = ""
