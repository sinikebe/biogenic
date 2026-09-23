extends CanvasLayer
## Full vision: the water the cell is actually swimming in.
##
## The game has two views of one simulation. Point of view draws nothing but the
## membrane -- that is the premise, and the game the design is built around.
## Full vision draws the world underneath it and leaves the membrane running on
## top, untouched, so the blind signals can be checked against the truth: does
## the bruise land on the bearing the mote was really on, does the taste wash
## really point at the cell it came off.
##
## **Nothing in here writes to the simulation.** The cell, the motes and the
## signal bus are read exactly as they are, and the two views must never differ
## by anything except what is drawn -- otherwise full vision stops being
## evidence about point of view and there is no reason to have it.
##
## **The other player is drawn here and only here**, which is the one place the
## two views are *supposed* to differ. Point of view is unchanged and must stay
## unchanged: there a friend is heard when their `ampulla` fires and not
## otherwise, and that is the game. Full vision already draws every body in the
## water from ground truth, so adding one more body to that list is a drawing
## difference and nothing else -- the simulation is not told, the bus is not
## told, and [method set_session] is a read handle on a socket, never a write
## one. See [method _step_peer].
##
## Additive, not underneath. The membrane's ColorRect is opaque and belongs to
## game/perception/, which this file may not restructure. But the membrane is
## already a near-black base (5,13,12) with every signal added on top of it, so
## drawing the world additively *over* the membrane composes to the same picture
## as sliding it underneath -- and costs game/perception/ nothing.
##
## The one thing this file exists to get right is that motion is legible. A
## camera locked to the cell makes the cell look still and only the motes look
## alive, which would make the drift impossible to tune. Four separate devices
## fight that: the water is anchored to world coordinates (water.gdshader), the
## camera lags and leads so the cell moves inside the frame, the cell drags a
## trail of where it has actually been, and heading and velocity are drawn in
## two different registers so their disagreement is visible.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")
const MotesField := preload("res://game/normal/motes.gd")
const FoodField := preload("res://game/normal/food.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
const Cilia := preload("res://game/vision/cilia.gd")
## **For one constant, and never for a session.** TRACK_GAP is the length of
## silence after which a friend's next frame lands as a step; the view decides
## that for itself and must agree with the session on the number. It still
## never looks a session up: see [method set_session] for why the handle is
## handed in rather than found.
const NetSession := preload("res://game/net/net_session.gd")

## Master switch. False takes the world view out everywhere, including from
## full-vision mode, which then renders as point of view. For when something in
## here has to be turned off in a hurry without a new binary.
const ENABLED := true

# --- Camera ----------------------------------------------------------------
## Canvas pixels per world unit. The cell's body radius is 26 world units.
const ZOOM := 1.0
## Seconds the camera takes to catch up, and how far ahead of the cell it aims
## per unit of speed. Both are small on purpose: they let the cell move inside
## the frame without pulling it far enough off centre to spoil the comparison
## with the membrane, whose bearings are measured from the centre of the screen.
const CAM_LAG := 0.30
const CAM_LEAD := 0.16
## How far off centre the camera is ever allowed to leave the cell.
const CAM_MAX_OFFSET := 72.0
## Seconds the *rotation* takes to catch up when the camera is locked to the
## body. Slower than the position lag on purpose: the heading wanders
## constantly, and a world that answered it frame for frame would be a world
## that never stops rocking.
const CAM_TURN_LAG := 0.22

# --- Fade ------------------------------------------------------------------
## Switching views is a dissolve, not a cut.
const FADE_SECONDS := 0.22

# --- Trail -----------------------------------------------------------------
const TRAIL_STEP := 0.05
const TRAIL_MAX := 140
const TRAIL_WIDTH := 3.0
const TRAIL_PEAK_ALPHA := 0.20

# --- Marks -----------------------------------------------------------------
## An impulse leaves a ring on the water where it fired, so the kick can be seen
## against the path it produced.
const KICK_LIFE := 5.0
## A contact leaves the bearing it reported, drawn as a ray from the cell, and
## the mote it hit is held for a moment after the field recycles it. Those two
## plus the membrane's bruise are the three things that have to agree.
const HIT_LIFE := 2.4
const GHOST_LIFE := 2.4
## The reported wake bearing, drawn as a ray from the cell. If it does not point
## at the cell that is hunting, the membrane is lying -- and catching exactly
## that is the only reason this view exists.
const WAKE_LIFE := 1.45

# --- Threshold rings -------------------------------------------------------
## A ring is a measuring instrument, so it is shown at the moment of
## measurement. Drawn always they are larger than the screen and the world reads
## as a radar plot; this is how far either side of a threshold they fade in.
const RING_WINDOW := 130.0
## Only the arc near the cell is worth drawing: the rest is off-screen, and
## drawing only the visible part also keeps a 1400-unit circle from looking
## visibly polygonal at a sane segment count.
const RING_ARC_MIN := 0.22
const RING_ARC_MAX := 0.95
const RING_STEPS := 64

# --- The wave (`ampulla`) ---------------------------------------------------
## Points on each half of the wavefront, matching `returns.gd`'s `WAVE_STEPS`:
## the two views draw one picture at two scales and the segment count is part
## of the picture.
const PING_STEPS := Cilia.WAVE_STEPS
## Half the angle between two of those points, taken off both ends of the far
## half so the two arcs do not share a vertex with the near one. A vertex drawn
## by two draw calls composites twice; measured in point of view, the ring's
## 257 and 150 summed sRGB above base met in a 407 bead at each seam.
const PING_SEAM := Cilia.WAVE_SEAM

# --- The other player -------------------------------------------------------
## **How far past the newest frame the friend is carried: a fifth of a second,
## and never further.** Drawn where the newest frame says the body is *now* --
## its place carried forward along the velocity and turn rate that came with it.
##
## **This reverses #50, on evidence, and only for a peer that is still
## talking.** #50 drew the friend half a second behind the newest frame, so
## that there was always a real sample on either side of the moment drawn and
## the marker never guessed. That was careful and it was slow: the owner played
## it on two phones and said a friend who jumped or turned showed it late
## enough to be called a second. `tools/net_lag.gd` put a number on it with no
## network in the way at all -- loopback, one process -- and the drawn friend
## ran about 0.55 s behind the real one on every jump and every turn, all of it
## this delay and the 2 Hz beat it was paired with. Now frames come twenty
## times a second carrying the body's own motion, and the marker is drawn on
## time; the price is that it is sometimes wrong for a moment, which
## [constant PEER_BLEND] takes back out without a jump.
##
## **#50's reason still holds, and this is where.** A cell that has *stopped*
## sending may equally have stopped swimming, turned, or been eaten, and a
## marker carried on by an old velocity is confidently wrong in a brand new
## place every frame. So the carry is capped here, and past the cap the marker
## freezes where the carry left it: four frame intervals, enough to ride over
## two lost frames and still land the third, and 38 units of travel at the top
## impulse speed -- the same 190 units a second the doubt ring below calls the
## fastest a cell swims. **Silence is still #50's to handle, and
## handles it unchanged**: [constant PEER_FRESH] still starts the squared fade
## and the dashed ring, at the same moment, at the same rates. Both policies
## live in one marker and they do not overlap -- a peer is carried for 0.2 s
## after each frame, and nothing about the fade starts before 1.2 s of quiet.
##
## **multiplayer.md §4.10 is still not contradicted.** Its measured rule --
## never interpolate the sensation stream -- is about a stream whose maxima are
## steps; this is a swimming body's place, which is continuous by construction
## and has a bounded speed. Nothing here touches the sensation stream.
const PEER_REACH := 0.2
## **How fast a correction is taken back out**: the time constant, in seconds,
## of the exponential a correction decays on -- 86% of it gone in 100 ms. When a
## new frame disagrees with where the marker is (a jump landed between two
## frames, a frame came late), the marker does not jump to the new answer: the
## difference is kept as an offset and bled away, so the body slides the last
## few units over a few frames instead of teleporting them in one.
##
## A time constant rather than a fixed-length slide, because frames arrive every
## 50 ms and a new correction lands before an old one has finished: an
## exponential restarted from wherever the marker is has no seam, and a fixed
## ramp restarted halfway has one.
const PEER_BLEND := 0.05
## Below this much silence the marker is at full confidence. **Unchanged from
## #50, and on purpose**: the quiet state has to look exactly as it did, and 1.2
## s is still the right length -- two dozen lost frames at 20 Hz, or two missed
## beats of the 2 Hz a paused run sends, is not a phone in a pocket yet.
## Everything after it is [method _step_peer]'s decay.
const PEER_FRESH := 1.2
## Where the decay bottoms out. Not disconnection and not disappearance: the
## session deliberately keeps a quiet peer (net_session.gd's SILENCE note), and
## a mark that vanished would say *they left*, which is a different and usually
## false statement.
const PEER_LOST := 9.0
## **What the marker never fades below**, so that "I do not know where they
## are" is still drawn as something rather than as nothing -- they have not
## left, and a mark that vanished would say they had.
##
## **Measured, not chosen.** At 0.16, which is where this was first written,
## the ghost's brightest rim pixel came out **34 of 255 green** against water
## whose own organic wash reaches 39 at the 95th percentile of the frame -- so
## the floor was under the texture it was drawn on, and a marker nobody can
## find is a marker that is not there. At 0.30 the same rim measures 65, which
## is a little under twice the wash's peak: quiet, unmistakably faded against
## the 1.0 it starts at, and findable.
const PEER_FLOOR := 0.30
## How wide the circle of *could be anywhere in here by now* is allowed to get.
##
## **A drawing limit, not a claim about the water.** The circle keeps being
## honest as it grows and stops being *legible* the moment it is larger than
## the frame -- at which point it is an arc crossing the screen rather than a
## circle round a place, and the thing carrying the message is the fade. 560 is
## a little over three quarters of the 720-unit canvas, so it still reads as a
## ring at the base shape. Past it the mark goes on fading and the ring holds.
const PEER_DOUBT_MAX := 560.0
## **The magnification on the edge mark.** The mark is the angular size the
## friend's body actually subtends from this cell -- `asin(r / d)`, which is
## the same arithmetic `normal_mode.gd`'s `_hear_others` runs to decide how
## wide a heard pulse lands -- and at 2000 units that is 0.8 of a degree, which
## is not a mark. Multiplied it runs from a broad cup a body-length off the
## frame to a short tick a long way out, which is the reading the mark is for.
const PEER_MARK_GAIN := 6.0
## Floor and ceiling on that, in radians of arc. The floor keeps somebody four
## thousand units away visible at all; the ceiling stops somebody just past the
## corner from wrapping a third of the frame.
const PEER_MARK_MIN := 0.028
const PEER_MARK_MAX := 0.62
## **How far inside the frame the edge mark sits, in canvas pixels.**
##
## 64 rather than something tighter, and it was rendered: the membrane's own
## contour is a rounded rectangle in the same self teal a few tens of pixels in
## from the edge, and it is *on top* of this view by construction. At 26 the
## mark sat inside it and the two read as one wobbling line. At 64 the mark is
## clearly a separate object inside the ring, which is also the truer picture --
## the friend is in the water, not on the skin.
const PEER_MARK_INSET := 64.0
## How many points across the arc are tested for fit. See [method
## _draw_peer_mark]: the arc is centred on the body and its ends can stand
## further out than its middle, so the middle alone is not the constraint.
const PEER_MARK_FITS := 5
## The band, in canvas pixels, over which the edge mark fades up as the friend
## leaves the frame. Without it the mark pops on the pixel they cross.
const PEER_MARK_BAND := 90.0
## Trail cadence and length for the friend. Shorter and fainter than the
## player's own: it is the same instrument saying the same thing, and the path
## that has to stay primary is the one the player is steering.
const PEER_TRAIL_MAX := 64
const PEER_TRAIL_ALPHA := 0.13
## Stable breath offset, so the friend and the player do not inhale in unison.
const PEER_PHASE := 5.3

# --- The friend in one pond (shared-pond-ux.md §0-§3, §5) --------------------
# **A friend in the same water is a body**, drawn by the routine that draws
# every body, from the field's own slot 68 -- worn tiers, order, gape, wound,
# the nucleus doubling -- untinted, because no cell the water makes is pure
# self teal, and able to threaten, because their mouth can reach you now.
# What fades is presence -- halo, trail, edge mark -- on #50's own curve; a body
# in the water is always drawn at 1.0, because it can bite. No doubt ring: in
# one pond every body is equally out of date, and a ring round one would claim
# the rest are current.

## How the friend left the water for good, as the run tells this view.
enum Gone { LEFT, STARVED, EATEN, EATEN_BY_YOU }
## What this view is doing with the friend: nobody; a body from the field; a
## body the field has just stopped holding, waiting a moment for why; a
## departure being drawn from the last pose.
enum Friend { ABSENT, PRESENT, VANISHED, DEPARTING }
## Out of the water is a ghost at the alpha the division gives the daughter you
## decline -- normal_mode.gd's DIVIDE_FADE_DIM, written out because that file
## preloads this one.
const FRIEND_GHOST := 0.34
## They leave the water over the division's pinch and come back over its
## commit: normal_mode.gd's DIVIDE_PINCH and DIVIDE_COMMIT.
const FRIEND_PINCH := 1.5
const FRIEND_COMMIT := 0.9
## How long a friend the field has stopped holding waits for the run to say
## why, before it is faded out as a friend who left. The reason travels on the
## reliable stream and the body on the unreliable one, so on a real link either
## can arrive first.
const FRIEND_PENDING := 0.3

## **This cell drawn outside the dim**, at full, as the daughters are: the run
## sets it while the pond is held and through its own pinch in a pond, when the
## world behind it is at DIVIDE_WORLD_FADE and this cell is what is happening.
var own_full := false
## The pond is held: the velocity plume goes, because the cell is not going
## anywhere and the plume would be a stale one.
var _held := false
var _fr := Friend.ABSENT
var _fr_clock := 0.0
## Seconds into the arrival fade, -1 when not arriving.
var _fr_arrive := -1.0
## Seen in the water since arriving: until then, out of it is arriving and not
## dividing, and draws no ghost.
var _fr_seen_in := false
var _fr_in := true
var _fr_out_clock := 0.0
## Seconds into the commit, when they come back into the water; -1 otherwise.
var _fr_back := -1.0
var _fr_out_r := 0.0
var _fr_gone := Gone.LEFT
## The friend as last drawn, for a departure to be drawn from.
var _fr_last: Dictionary = {}
## After a departure the field has to be seen without them once before a body
## there is an arrival: the body and the reason take different routes.
var _fr_need_absence := false
## Frames this view has run since it came on: a friend there on the first one
## is in the first frame, not arriving.
var _fr_frames := 0
## A body that appears inside the frame fades in: a sister, left in the water.
## Slot -> seconds, and the serials that say a slot has a new body.
var _fade_in := {}
var _slot_serials := PackedInt64Array()

# --- Body ------------------------------------------------------------------
## Decay of the beat echo, matching the membrane's own pulse decay.
const BEAT_DECAY := 0.42

const MOTE_STEPS := 22
const HALO_STEPS := 7
## Fixed length, always: this is where the cell is pointing, never how fast.
const HEADING_LEN := 46.0
## Where the heading needle starts, as a multiple of radius. **Moved from 1.55
## to 1.80 by §4.6**: a tier-3 `cytostome` crest reaches r * 1.61 and collided
## with the chevron. The 32-cilium bearing rose that used to live under it is
## retired with it -- under a tier-2 fringe its pale cardinal ticks were
## invisible at both sizes, and the fringe now carries meaning that a protractor
## laid over it only muddles. The bearing checks this view exists for are drawn
## as rays from the cell (_draw_hits, _draw_wakes) and are their own instrument.
const HEADING_BASE := 1.80
## Variable length: how far ahead the current velocity reaches. Scaled so it is
## almost never the same length as the heading needle, because the one thing
## these two must never do is be mistaken for each other.
const VELOCITY_SCALE := 0.82
const VELOCITY_MAX := 240.0

# --- Palette (docs/design/perception.md §3) --------------------------------
## Self, and everything the cell is made of. The launcher's rim colour.
const SELF_TINT := Color(0.12, 0.70, 0.58)
## Mechanics: motion, contact, pressure. Pale, exactly as on the membrane, where
## a dent and a flash are pale and chemistry glows.
const MOTION_TINT := Color(0.78, 0.94, 0.90)
## Contact, at the moment it happens.
const IMPACT_TINT := Color(0.90, 1.0, 0.97)
## Inert matter. Dull and slightly off the cell's own hue -- a mote is not
## chemistry and must never be mistaken for food when food arrives.
const MATTER_TINT := Color(0.46, 0.72, 0.62)
## The water's own structure, and the cull boundary drawn in it.
const WATER_TINT := Color(0.10, 0.62, 0.52)
## Food, in exactly the green the taste lobe uses, so "the green on my rim" and
## "the green thing out there" are visibly one substance.
const FOOD_TINT := Color(0.35, 0.88, 0.42)
## The colour of the thing that can eat you. Full vision only, never on the
## membrane -- which is the whole point of it. It no longer belongs to a species:
## §1.1.1 moves it onto the mouth, so a cell that grows its cytostome past your
## radius turns red in front of you.
const PREDATOR_TINT := Color(0.78, 0.24, 0.30)

@onready var _water: ColorRect = $Water
## **The clip.** `$World` is a `Node2D` and draws out past 1900 world units, so
## anchors cannot hold it: put this view in half a screen and it would spill
## across whatever is in the other half. A `Control` with `clip_contents` clips
## its own canvas item and every child of it, which is the one part of
## docs/design/replay.md §4.3 that had to be rendered rather than reasoned
## about. It is the whole viewport in normal mode and clips nothing there.
@onready var _frame: Control = $Frame
@onready var _world: Node2D = $Frame/World

var _cell: CellBody = null
var _motes_node: MotesField = null
var _food_node: FoodField = null
var _genome_node: GenomeNode = null
var _bus: SignalBus = null
var _shader: ShaderMaterial = null

## Starts off and is switched on by whoever owns the run, so point of view
## never flashes a frame of world before it is told which view it is.
var _active := false
var _amount := 0.0
## What the world is allowed to reach. 1 normally; taken down to
## DIVIDE_WORLD_FADE while two daughters are on screen, **through the fade this
## view already has** -- so the beat costs no uniform and no new binary.
var _dim := 1.0

## **The division**, written once a frame by the run; same contract as
## soma.gd's. Empty is an ordinary body. docs/design/lifecycle.md §4.
var division := {}

## How far apart the two of them are seated, in world units. Rendered at 1:1
## with 160 between them, two r28 bodies read -- so no camera zoom, which would
## touch a dozen call sites in a shipped file for a beat that does not need it.
const DIVIDE_SPREAD := 160.0
var _clock := 0.0
var _camera := Vector2.ZERO
var _view := Vector2(1280.0, 720.0)
## **Forward is always up.** The world turns instead of the cell. Off by
## default; the pause screen owns the switch.
var _locked := false
var _spin := 0.0

## Beat echo, so the body swells on the same beat the contour does. Deliberately
## a copy rather than a reach into the bus's envelopes: this is decoration, and
## it must not become something game/perception/ has to keep working for.
var _beat := 0.0

var _trail := PackedVector2Array()
var _trail_clock := 0.0

## **The live session, or null in every single-player run.** Untyped on purpose,
## exactly like `normal_mode.gd`'s own handle: net_session.gd carries no
## class_name, so there is no type to declare.
##
## Read-only, always. This view reads the simulation and never writes it, and a
## socket is held to the same rule -- nothing in this file calls anything on
## the session but [code]peer_track()[/code], [code]quiet_for()[/code] and
## [code]clock()[/code].
var _session: Node = null
## What to draw for the friend this frame, or empty. Written by
## [method _step_peer] and read by the two draw routines, so that everything
## with arithmetic in it happens somewhere a headless probe can read it. A
## `_draw` does run under `--headless`, but what it draws goes to a renderer
## that keeps no pixels: a number worked out inside one is checked by nothing,
## and only a script error there would ever show in CI.
## `{at, heading, radius, confidence, doubt}`.
var _peer: Dictionary = {}
var _peer_trail := PackedVector2Array()
var _peer_trail_clock := 0.0
## **The frame the marker is being carried from**, one of the session's track
## entries, held so the next frame can be told apart from it -- by identity,
## because two frames can land inside one millisecond of the session's clock.
var _peer_basis: Array = []
## The correction still being bled out, in world units and radians. See
## [constant PEER_BLEND]. `tools/net_lag.gd` reads both, which is how the size
## of every correction a real run asks for gets measured rather than guessed.
var _peer_offset := Vector2.ZERO
var _peer_twist := 0.0
## [[world position, strength, age], ...]
var _kicks: Array[Array] = []
## [[world position, world direction, strength, age], ...]
var _hits: Array[Array] = []
## [[world position, age], ...] -- motes the field has already recycled.
var _ghosts: Array[Array] = []
## [[world position, radius, age, gene hue], ...] -- cells eaten since, held so
## the ingest flood has something to be checked against.
var _meals: Array[Array] = []
## [[world position, world direction, strength, age], ...] -- reported wakes.
var _wakes: Array[Array] = []


func _ready() -> void:
	_shader = _water.material as ShaderMaterial
	_world.draw.connect(_on_world_draw)
	_world.scale = Vector2(ZOOM, ZOOM)

	# Bound already means somebody instanced this view on purpose and told it
	# what to look at ([method bind]); the search below is for the ordinary
	# case, where this node is a child of the run and nothing hands it anything.
	if _cell == null:
		_find_simulation()
	if _cell != null:
		_camera = _cell.position
	if _bus != null:
		_bus.sensation.connect(_on_sensation)
	# Ground truth comes from the field, not from the bus. The bus carries what
	# the cell FEELS -- a bearing and an intensity, never a position -- so the
	# view that is allowed to know where the mote actually was has to ask the
	# thing that knows.
	if _motes_node != null:
		_motes_node.struck.connect(_on_mote_struck)
	if _food_node != null:
		_food_node.eaten.connect(_on_eaten)

	_apply_visibility()


## **What this view is a view of**, for a second copy of it that is not a child
## of the run. Called before [method Node.add_child], which is the only moment
## it can be: [method _ready] falls back to searching the tree, and the search
## finds the run's own nodes -- including the run's bus, which is the wrong bus
## for a screen that re-plays recorded sensations of its own.
##
## The run itself never calls this and is unchanged by it. docs/design/replay.md
## §4.5.
func bind(cell: CellBody, motes: MotesField, food: FoodField,
		genome: GenomeNode, bus: SignalBus) -> void:
	_cell = cell
	_motes_node = motes
	_food_node = food
	_genome_node = genome
	_bus = bus


## **The socket the other player is on the far end of**, handed over by the run
## rather than looked up, and that is deliberate on two counts.
##
## `net_session.gd` has a static `current`, so this file could find one for
## itself -- and then the two-pane replay screen, which instances a second copy
## of this view and binds it to a recording, would draw a live friend swimming
## through last week's water. A recording has no peer in it. So the handle
## arrives from the one node that knows whether what it is showing is happening
## now, and `panes.gd` simply never calls this.
##
## The second count is the direction of the arrow. Nothing here writes to the
## session and nothing here can: it is read three times a frame for a track, a
## silence and a clock. The run still owns every byte that leaves.
func set_session(session: Node) -> void:
	_session = session if (session != null and is_instance_valid(session)) else null
	_forget_peer()


## **Which part of the screen this view occupies.** The whole viewport in normal
## mode, where nothing calls this; half of it, less the transport band, on the
## two-pane replay screen.
##
## Both rects, and they are deliberately the same one: `Water` is what the water
## shader fills and what sets the world-to-screen scale, and `Frame` is what
## clips the drawing to it. replay.md §4.3.
func set_frame(rect: Rect2) -> void:
	for control: Control in [_water, _frame]:
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		control.position = rect.position
		control.size = rect.size
	_view = rect.size


## The one thing the rest of the game says to this node. [param on] is true in
## full vision and false in point of view.
func set_active(on: bool) -> void:
	var want := on and ENABLED
	if want == _active:
		return
	_active = want
	if _active:
		# Come back at the camera the cell is at now, not where it was left, and
		# with no history: nothing ages while the view is off, so anything kept
		# would reappear frozen at whatever age it had when it went dark.
		if _cell != null:
			_camera = _cell.position
		_trail.clear()
		_trail_clock = 0.0
		_forget_peer()
		_peer_trail_clock = 0.0
		_forget_friend()
		_kicks.clear()
		_hits.clear()
		_ghosts.clear()
		_meals.clear()
		_wakes.clear()
	_apply_visibility()


func is_active() -> bool:
	return _active


## **Forward is always up**, or the world is north-up. Set from the pause
## screen. The cell is already pinned to the centre of the frame by the camera,
## so this is the only other thing a camera can be.
##
## The water shader is deliberately **not** turned with it: it is anchored to
## world coordinates by an origin and a scale, with no rotation term, and giving
## it one would be a new uniform and therefore a new binary. Locked, the wash
## still slides with the camera and stops turning with it -- which costs one of
## the four motion cues in the header and keeps the other three.
func set_camera_locked(on: bool) -> void:
	if on == _locked:
		return
	_locked = on
	# No easing in from whatever the old spin was: the switch happens under a
	# pause scrim, where nothing is moving and a 180-degree slew would be the
	# only thing on screen.
	_spin = -_cell.heading if (_locked and _cell != null) else 0.0


## How bright the world is allowed to be. The run takes it down while the two
## daughters are drawn over it, and puts it back afterwards.
func set_dim(level: float) -> void:
	_dim = clampf(level, 0.0, 1.0)


## **The pond is held** (shared-pond-ux.md §5): the host's phone has gone
## quiet and the water with it. The run dims the world; this cell is drawn
## outside the dim through [member own_full], heading needle kept.
func set_held(on: bool) -> void:
	_held = on


## **The friend left the water for good, and how** (shared-pond-ux.md §3, §5):
## eaten by the water, a SELF_TINT meal ring where they were and the body gone
## in that frame; starved, a fade over FAINT_COLLAPSE; eaten by you, nothing
## added -- your own meal ring and flood are already firing; gone from the
## wire, the arrival fade reversed. [param at] is where the body was.
func friend_gone(how: int, at: Vector2) -> void:
	_fr_need_absence = true
	if not _active:
		return
	var r := float(_fr_last.get("radius", 0.0))
	if how == Gone.EATEN:
		_meals.append([at, r if r > 0.0 else FoodField.DRIFTER_MAX, 0.0, SELF_TINT])
	if _fr == Friend.PRESENT or _fr == Friend.VANISHED:
		_depart(how)


func _process(delta: float) -> void:
	_amount = move_toward(_amount, _dim if _active else 0.0, delta / FADE_SECONDS)
	if _amount <= 0.0 and not _active:
		_apply_visibility()
		return

	_clock += delta
	_beat = maxf(_beat - delta / BEAT_DECAY, 0.0)
	_age(_kicks, 2, delta, KICK_LIFE)
	_age(_hits, 3, delta, HIT_LIFE)
	_age(_ghosts, 1, delta, GHOST_LIFE)
	_age(_meals, 2, delta, GHOST_LIFE)
	_age(_wakes, 3, delta, WAKE_LIFE)

	if _water.size.x > 1.0:
		_view = _water.size
	_step_camera(delta)
	_step_trail(delta)
	_step_peer(delta)

	# The world-to-screen transform, in one place. Unlocked it is a translation
	# and nothing else, exactly as it has always been; locked, the whole world
	# turns about the camera so that the cell's nose points up the screen.
	if _locked and _cell != null:
		_spin = lerp_angle(_spin, -_cell.heading, 1.0 - exp(-delta / CAM_TURN_LAG))
	else:
		_spin = 0.0
	_world.rotation = _spin
	# **Where the middle of the water is, in the frame's own coordinates.** The
	# first term used to be missing, which assumed the water rect started at the
	# viewport origin and that `$World` hung directly off the canvas layer. Both
	# are true in normal mode and the term is exactly zero there -- it is the
	# split screen, where the rect is half a viewport wide and sits at an
	# offset, that needs it written down. replay.md §4.3.
	_world.position = (_water.position - _frame.position) \
		+ _view * 0.5 - (_camera * ZOOM).rotated(_spin)
	_push_shader()
	_world.queue_redraw()


# ---------------------------------------------------------------------------
# Camera. Lag plus lead, both clamped: the cell has to move inside the frame or
# the drift is invisible, but it must stay close enough to the centre that the
# membrane's bearings can still be read against it.
# ---------------------------------------------------------------------------

func _step_camera(delta: float) -> void:
	if _cell == null:
		return
	var aim := _cell.position + _cell.velocity * CAM_LEAD
	_camera = _camera.lerp(aim, 1.0 - exp(-delta / CAM_LAG))
	var offset := _camera - _cell.position
	if offset.length() > CAM_MAX_OFFSET:
		_camera = _cell.position + offset.normalized() * CAM_MAX_OFFSET


func _step_trail(delta: float) -> void:
	if _cell == null:
		return
	_trail_clock += delta
	if _trail_clock < TRAIL_STEP and not _trail.is_empty():
		return
	_trail_clock = 0.0
	_trail.push_back(_cell.position)
	if _trail.size() > TRAIL_MAX:
		_trail = _trail.slice(_trail.size() - TRAIL_MAX)


## **Where the friend is this frame, and how much of that is still true.**
##
## Every number the two draw routines below use is worked out here, and that is
## not tidiness. **`_draw` does run under `--headless`** -- measured on a
## full-vision run, 1,920 `draw` signals from `$Frame/World` in 1,920 frames --
## but into a renderer that keeps no pixels, so arithmetic that lived inside one
## would execute in CI and be checked by nothing: a script error there shows,
## a wrong number never does. Here it is in a `_process`, where
## `tools/net_probe.gd` can read it off a real run and assert on it.
##
## **Nothing in this function touches the simulation.** It reads a track, a
## silence and a clock off the session, and writes one dictionary of its own.
func _step_peer(delta: float) -> void:
	# **In a pond the friend is the field's body in slot 68**, and the session's
	# track is not drawn (shared-pond.md §3): the same place, but the field's is
	# the one every sense and every mouth is using.
	if _cell != null and _food_node != null and _food_node.pond_open():
		_step_friend(delta)
		return
	if _cell == null or _session == null or not is_instance_valid(_session):
		_forget_peer()
		return
	var track: Array = _session.peer_track()
	if track.is_empty():
		_forget_peer()
		return
	var now := float(_session.clock())
	_follow(track, now, delta)
	var body := carry(_peer_basis, now)
	if body.is_empty():
		_forget_peer()
		return
	var at: Vector2 = body[0] + _peer_offset
	# **How old this is, on the wire's terms and not the tree's.**
	# `quiet_for()` counts every byte that has arrived, not only state frames,
	# so a peer that is saying anything at all reads as present -- and it is
	# wall time, so a phone that stopped the main loop is aged honestly.
	var quiet: float = float(_session.quiet_for())
	var doubt := maxf(quiet - PEER_FRESH, 0.0)
	# **Squared, because what is growing is an area.** The circle they could be
	# anywhere in widens with the silence, so how much of a *place* this mark is
	# still describing falls with that circle's area rather than with its
	# radius. Straight, the mark was still at four fifths brightness after two
	# and a half seconds of nothing, which is a confident-looking marker saying
	# something it no longer knows. This is a curve judged against the renders
	# and not a measurement -- there is nothing here to measure it against.
	var slip := 1.0 - clampf(doubt / maxf(PEER_LOST - PEER_FRESH, 0.001), 0.0, 1.0)
	slip *= slip
	# **How far they could have got since, at the fastest a cell swims.** Read
	# off the ladder rather than written down, so a tuning pass on the drive
	# cannot leave a circle here claiming a speed the game no longer has.
	var ladder := CellBody.IMPULSE_SPEED_BY_TIER
	var top: float = ladder[ladder.size() - 1]
	_peer = {
		"at": at,
		"heading": wrapf(float(body[1]) + _peer_twist, -PI, PI),
		"radius": float(body[2]),
		"confidence": PEER_FLOOR + (1.0 - PEER_FLOOR) * slip,
		"doubt": minf(doubt * top, PEER_DOUBT_MAX),
	}
	_step_peer_trail(delta, at,
		doubt <= 0.0 and now - float(_peer_basis[0]) <= PEER_REACH)


## **Which frame the marker is carried from, and what to do when a new one
## lands.** Three cases, and the middle one is the feature:
##
## - **nothing new**: the correction in flight decays a little, and that is all;
## - **a new frame continuing the stream**: the marker stays exactly where it
##   is drawn this frame -- the difference between the old frame's carry and
##   the new one's becomes the offset, and [constant PEER_BLEND] takes it out
##   over the next few frames. That is the whole of "blend, do not snap";
## - **a new frame that continues nothing** -- the first one, or one landing
##   more than `net_session.gd`'s TRACK_GAP after the frame the marker was
##   carried from: it lands as a step, as it did in #50. Blending across a
##   pocket would animate a journey nobody made.
##
## The gap is measured from the marker's own frame and not read off the
## track's length, and the difference is a real case: a phone coming out of a
## pocket can find two or more frames waiting in one poll, and the track then
## holds two entries that continue *each other* while the marker is still on a
## frame from before the silence.
func _follow(track: Array, now: float, delta: float) -> void:
	var keep := exp(-maxf(delta, 0.0) / PEER_BLEND)
	_peer_offset *= keep
	_peer_twist *= keep
	var newest: Array = track[track.size() - 1]
	if is_same(newest, _peer_basis):
		return
	var was := carry(_peer_basis, now)
	var fresh := carry(newest, now)
	var bridged := not was.is_empty() and not fresh.is_empty() \
		and float(newest[0]) - float(_peer_basis[0]) <= NetSession.TRACK_GAP
	_peer_basis = newest
	if not bridged:
		_peer_offset = Vector2.ZERO
		_peer_twist = 0.0
		return
	_peer_offset = ((was[0] as Vector2) + _peer_offset) - (fresh[0] as Vector2)
	_peer_twist = angle_difference(float(fresh[1]),
		float(was[1]) + _peer_twist)


func _forget_peer() -> void:
	if not _peer.is_empty():
		_peer = {}
	if not _peer_trail.is_empty():
		_peer_trail.clear()
	_peer_basis = []
	_peer_offset = Vector2.ZERO
	_peer_twist = 0.0


func _forget_friend() -> void:
	_fr = Friend.ABSENT
	_fr_frames = 0
	_fr_arrive = -1.0
	_fr_back = -1.0
	_fr_need_absence = false
	_fr_last = {}
	_fade_in.clear()
	_slot_serials.resize(0)


## **The friend, this frame, in a pond** (shared-pond-ux.md §0-§3): the body
## the field holds in slot 68, the arrival fade, the ghost of a friend out of
## the water and the commit that brings them back, a departure drawn from the
## last pose, and presence on #50's curve. Worked out here and not in a
## `_draw`, for the reason [method _step_peer] gives: a headless probe can read
## `_peer`, and nothing can read a draw.
func _step_friend(delta: float) -> void:
	_fr_frames += 1
	_step_fade_ins(delta)
	var bodies := _food_node.bodies()
	var pb: Object = bodies[FoodField.PERSON_SLOT] \
		if bodies.size() > FoodField.PERSON_SLOT else null
	var person: Object = _food_node.person()
	var here := person != null and pb != null and float(pb.radius) > 0.0
	if not here:
		_fr_need_absence = false
	match _fr:
		Friend.DEPARTING:
			_fr_clock += delta
			if _fr_clock < _departure_length(_fr_gone):
				_peer = _departing_mark()
				return
			_fr = Friend.ABSENT
			_peer = {}
			_peer_trail.clear()
			return
		Friend.VANISHED:
			_fr_clock += delta
			if not here:
				if _fr_clock >= FRIEND_PENDING:
					_depart(Gone.LEFT)
				else:
					_peer = _fr_last
				return
			_fr = Friend.PRESENT
		Friend.ABSENT:
			if not here or _fr_need_absence:
				if not _peer.is_empty():
					_peer = {}
				return
			# **An arrival** (UX §1, §3): body, halo and edge mark fade in over
			# the 0.9 s every return takes, the trail empty -- unless this is
			# the view's first frame, and then they are simply in it.
			_fr = Friend.PRESENT
			_fr_arrive = 0.0 if _fr_frames > 1 else -1.0
			_fr_seen_in = false
			_fr_in = true
			_fr_back = -1.0
			_peer_trail.clear()
			_peer_trail_clock = 0.0
	if not here:
		_fr = Friend.VANISHED
		_fr_clock = 0.0
		_peer = _fr_last
		return

	var r := float(pb.radius)
	var wet := bool(person.in_water)
	if _fr_arrive >= 0.0:
		_fr_arrive += delta
		if _fr_arrive >= SignalBus.DEATH_RETURN:
			_fr_arrive = -1.0
	# In and out of the water. Before they have been seen in it, out of it is a
	# friend being placed rather than one dividing, and draws no ghost.
	if wet:
		if _fr_seen_in and not _fr_in:
			_fr_back = 0.0
		_fr_seen_in = true
		_fr_in = true
	elif _fr_seen_in:
		if _fr_in:
			_fr_out_clock = 0.0
			_fr_back = -1.0
		_fr_in = false
		_fr_out_clock += delta
		_fr_out_r = r
	if _fr_back >= 0.0:
		_fr_back += delta
		if _fr_back >= FRIEND_COMMIT:
			_fr_back = -1.0
	var ghost := _fr_seen_in and not _fr_in
	var alpha := 1.0
	var pinch := 0.0
	var drawn := r
	if ghost:
		# **The pinch** (UX §2): the body narrows and falls to the ghost's 0.34
		# over the division's own 1.5 s, and holds there while they choose.
		var t := clampf(_fr_out_clock / FRIEND_PINCH, 0.0, 1.0)
		alpha = lerpf(1.0, FRIEND_GHOST, t)
		pinch = t
	elif _fr_back >= 0.0:
		# **The commit**: the ghost becomes the daughter where it stood --
		# 0.34 to 1, pinch 1 to 0, radius from the mother's to hers.
		var t := clampf(_fr_back / FRIEND_COMMIT, 0.0, 1.0)
		alpha = lerpf(FRIEND_GHOST, 1.0, t)
		pinch = 1.0 - t
		drawn = lerpf(_fr_out_r, r, t)
	if _fr_arrive >= 0.0:
		alpha *= clampf(_fr_arrive / SignalBus.DEATH_RETURN, 0.0, 1.0)
	var at: Vector2 = pb.pos
	_peer = {
		"at": at,
		"heading": float(pb.heading),
		"radius": drawn,
		"confidence": _presence() * alpha,
		"doubt": 0.0,
		"alpha": alpha,
		"pinch": pinch,
		"double": smoothstep(CellBody.DIVIDE_WARN_RADIUS, CellBody.DIVIDE_RADIUS, drawn),
		"tiers": pb.genome,
		"order": pb.order,
		"gape": _food_node.gape_at(FoodField.PERSON_SLOT),
		"wound": float(pb.wound),
		"ghost": ghost,
	}
	_fr_last = _peer
	# No new trail points from a ghost (UX §0.3), nor while a friend is arriving.
	_step_peer_trail(delta, at, not ghost and _fr_arrive < 0.0)


## **Presence** (UX §0.2): #50's confidence curve on the silence, squared, down
## to [constant PEER_FLOOR] -- for the halo, the trail and the edge mark, never
## the body.
func _presence() -> float:
	if _session == null or not is_instance_valid(_session):
		return 1.0
	var quiet := float(_session.quiet_for())
	var doubt := maxf(quiet - PEER_FRESH, 0.0)
	var slip := 1.0 - clampf(doubt / maxf(PEER_LOST - PEER_FRESH, 0.001), 0.0, 1.0)
	return PEER_FLOOR + (1.0 - PEER_FLOOR) * slip * slip


func _depart(how: int) -> void:
	_fr = Friend.DEPARTING
	_fr_gone = how
	_fr_clock = 0.0
	_peer = _departing_mark()


## How long a departure is drawn for: at once for a body eaten, the starving
## faint's own tempo, and the arrival fade reversed for a friend who left.
func _departure_length(how: int) -> float:
	match how:
		Gone.STARVED:
			return SignalBus.FAINT_COLLAPSE
		Gone.LEFT:
			return SignalBus.DEATH_RETURN
	return 0.0


## The last pose, fading as the departure says. Empty for a body that goes at
## once.
func _departing_mark() -> Dictionary:
	var length := _departure_length(_fr_gone)
	if length <= 0.0 or _fr_last.is_empty():
		return {}
	var keep := 1.0 - clampf(_fr_clock / length, 0.0, 1.0)
	var mark := _fr_last.duplicate()
	mark["alpha"] = float(_fr_last.get("alpha", 1.0)) * keep
	mark["confidence"] = float(_fr_last.get("confidence", 1.0)) * keep
	return mark


## **A new body inside the frame fades in** (UX §2's sister): the water seeds
## nothing inside RING_MIN of anybody, and the mirror is sent nothing new from
## that close, so a new serial in view is a placed body -- a sister, left in
## the water -- and it arrives with the arrival's own fade. The first frame the
## view is on sees the water as it is.
func _step_fade_ins(delta: float) -> void:
	for slot: int in _fade_in.keys():
		var t := float(_fade_in[slot]) + delta
		if t >= SignalBus.DEATH_RETURN:
			_fade_in.erase(slot)
		else:
			_fade_in[slot] = t
	var bodies := _food_node.bodies()
	var fresh := _slot_serials.size() != bodies.size()
	if fresh:
		_slot_serials.resize(bodies.size())
	var reach := _view.length() * 0.5 / ZOOM
	for i in bodies.size():
		var b: Object = bodies[i]
		var serial := int(b.serial)
		if not fresh and serial == _slot_serials[i]:
			continue
		_slot_serials[i] = serial
		if fresh or _fr_frames <= 1 or i == FoodField.PERSON_SLOT or not bool(b.seeded):
			continue
		if (b.pos as Vector2).distance_to(_camera) <= reach + float(b.radius) * CULL_REACH:
			_fade_in[i] = 0.0


## **One frame, carried forward to now, and no further than [constant
## PEER_REACH].** Static and dependency-free on purpose: this is the only
## arithmetic in the feature that can be wrong in a way a render would not
## show, so `tools/net_probe.gd` checks it against frames it makes up rather
## than against a screen nobody can see.
##
## [param frame] is one of `net_session.gd`'s track entries, `[when, at,
## heading, radius, velocity, turning]`. Returns `[at, heading, radius]`, or an
## empty array when there is no frame. A frame with no motion in it -- or an
## old four-entry one -- is drawn exactly where it says, which is what a held
## body is.
##
## **A straight line, and that is enough.** The velocity decays with the
## water's drag and the turn rate eases toward the steering, and neither is
## modelled: over the 50 ms between two frames the drag is a few hundredths of a
## unit and the easing a thousandth of a radian, and the next frame corrects
## both. Running `cell.gd`'s own motion model here would need the sender's genes
## and its inputs, and the corrections `tools/net_lag.gd` measures are what
## says whether that is ever worth it.
static func carry(frame: Array, now: float) -> Array:
	if frame.size() < 4:
		return []
	var at: Vector2 = frame[1]
	var heading := float(frame[2])
	if frame.size() >= 6:
		var ahead := clampf(now - float(frame[0]), 0.0, PEER_REACH)
		at += (frame[4] as Vector2) * ahead
		heading += float(frame[5]) * ahead
	return [at, heading, float(frame[3])]


## Their path, on the same cadence as the player's own. **It stops the moment
## the marker stops being carried on live frames**: past that the drawn position
## is a held one, and a trail that kept sampling it would draw a cell standing
## still in open water -- which is a claim, and a false one.
func _step_peer_trail(delta: float, at: Vector2, live: bool) -> void:
	if not live:
		return
	_peer_trail_clock += delta
	if _peer_trail_clock < TRAIL_STEP and not _peer_trail.is_empty():
		return
	_peer_trail_clock = 0.0
	_peer_trail.push_back(at)
	if _peer_trail.size() > PEER_TRAIL_MAX:
		_peer_trail = _peer_trail.slice(_peer_trail.size() - PEER_TRAIL_MAX)


func _push_shader() -> void:
	if _shader == null:
		return
	_shader.set_shader_parameter("rect_px", _view)
	_shader.set_shader_parameter("world_origin", _camera - _view * 0.5 / ZOOM)
	_shader.set_shader_parameter("world_per_px", 1.0 / ZOOM)
	_shader.set_shader_parameter("amount", _amount)


func _apply_visibility() -> void:
	var showing := _active or _amount > 0.0
	visible = showing
	set_process(showing)


# ---------------------------------------------------------------------------
# Listening. Everything below is read-only: the bus posts what the membrane is
# already being told, and vision draws the same events in world space.
# ---------------------------------------------------------------------------

func _on_sensation(kind: StringName, info: Dictionary) -> void:
	if not _active or _cell == null:
		return
	match kind:
		&"beat":
			_beat = float(info.get("strength", 1.0))
		&"thrust":
			_kicks.append([_cell.position, float(info.get("strength", 1.0)), 0.0])
		&"hit":
			var bearing := float(info.get("bearing", 0.0))
			_hits.append([_cell.position, _ray(bearing),
				float(info.get("strength", 1.0)), 0.0])
		&"shove":
			var wake_bearing := float(info.get("bearing", 0.0))
			_wakes.append([_cell.position, _ray(wake_bearing),
				float(info.get("strength", 1.0)), 0.0])
		_:
			pass


## Holds the struck mote where it actually was, because the field recycles it to
## the far side of the water immediately and by the next frame there would be
## nothing left to check a bearing against.
##
## The position is handed over by the field. This used to infer it instead --
## searching the field's private array for whatever was within reach — which
## depended on the emit happening before the recycle and picked the wrong mote
## whenever two were in contact range. The whole point of this view is to catch
## the membrane lying; a ghost in the wrong place would have made it lie too,
## silently, on the one screen built to detect exactly that.
func _on_mote_struck(_bearing: float, _strength: float, at: Vector2) -> void:
	if not _active:
		return
	_ghosts.append([at, 0.0])


## Same contract, same reason: the field hands over where the meal was, because
## by the next frame it has been recycled to the far side of the water.
func _on_eaten(nutrition: float, gene: StringName, at: Vector2) -> void:
	if not _active:
		return
	# The meal signal still carries no radius, and it does not need to:
	# `nutrition` is the prey's radius over this body's, and food.gd clamps it
	# only at MEAL_MIN 0.35 and MEAL_MAX 1.40. The upper clamp is unreachable --
	# a gape of 1.40r is the widest mouth there is, so nothing eaten was ever
	# wider than that -- and the lower one is off by at most a pixel on the
	# smallest drifter swallowed by the largest cell. Adding a fourth argument
	# to a signal three files forward it would cost more than a pixel is worth.
	var r := clampf(nutrition * _cell.radius,
		FoodField.DRIFTER_MIN, FoodField.ARRIVAL_RADIUS_MAX)
	_meals.append([at, r, 0.0, Cilia.hue(gene) if gene != &"" else FOOD_TINT])


## **A recorded contact, replayed into this view's own marks.** Two lines, and
## they exist so the replay screen never fires [signal MotesField.struck] or
## [signal FoodField.eaten] to get a ghost drawn: those signals belong to the
## live water, and the run sitting behind the replay screen is still subscribed
## to them. docs/design/replay.md §4.5.
##
## The bearing and the strength are not passed because the handler drops them --
## a ghost is a place, and the place is all that is held.
func mark_struck(at: Vector2) -> void:
	_on_mote_struck(0.0, 0.0, at)


func mark_meal(nutrition: float, gene: StringName, at: Vector2) -> void:
	_on_eaten(nutrition, gene, at)


## A body-relative bearing turned back into a world direction. The one place
## this view undoes what the membrane did, which is exactly what makes the
## membrane checkable.
func _ray(bearing: float) -> Vector2:
	return _cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)


func _age(marks: Array, age_index: int, delta: float, life: float) -> void:
	for i in range(marks.size() - 1, -1, -1):
		var mark: Array = marks[i]
		mark[age_index] = float(mark[age_index]) + delta
		if float(mark[age_index]) >= life:
			marks.remove_at(i)


# ---------------------------------------------------------------------------
# Drawing. $World carries the world-to-screen transform, so everything below is
# in world coordinates and world units.
# ---------------------------------------------------------------------------

func _on_world_draw() -> void:
	if _cell == null or _amount <= 0.0:
		return
	var a := _amount
	_draw_cull_ring(a)
	_draw_thresholds(a)
	_draw_trail(a)
	_draw_kicks(a)
	_draw_motes(a)
	_draw_cells(a)
	_draw_peer(a)
	_draw_ghosts(a)
	_draw_meals(a)
	_draw_hits(a)
	_draw_wakes(a)
	_draw_beams(a)
	_draw_ping(a)
	_draw_cell(a)
	_draw_peer_mark(a)


## Why motes vanish: past this radius the field recycles them to the far edge.
## It is far outside the frame at ZOOM 1, so it is only drawn when it could
## actually be seen.
func _draw_cull_ring(a: float) -> void:
	if _motes_node == null:
		return
	if MotesField.CULL * ZOOM > _view.length() * 0.5 + 64.0:
		return
	_world.draw_arc(_cell.position, MotesField.CULL, 0.0, TAU, 128,
		Color(WATER_TINT, 0.10 * a), 1.5 / ZOOM, true)


## Where the cell has actually been. This is the reading that the drift, the
## slow turn and the impulse kick are all tuned against.
func _draw_trail(a: float) -> void:
	if _trail.size() < 2:
		return
	# Cut the newest end back to the rim: a wake drawn straight through the cell
	# reads as a scratch across it, not as a path behind it.
	var p := _cell.position
	var edge := _cell.radius * 1.12
	var cut := _trail.size()
	while cut > 0 and _trail[cut - 1].distance_to(p) < edge:
		cut -= 1
	if cut < 2:
		return
	var points := _trail.slice(0, cut)
	points.push_back(p + (points[cut - 1] - p).normalized() * edge)
	var colors := PackedColorArray()
	colors.resize(points.size())
	var last := float(points.size() - 1)
	for i in points.size():
		var t := float(i) / maxf(last, 1.0)
		colors[i] = Color(MOTION_TINT, TRAIL_PEAK_ALPHA * t * a)
	_world.draw_polyline_colors(points, colors, TRAIL_WIDTH / ZOOM, true)


## Each flagellar impulse, marked on the water where it fired.
func _draw_kicks(a: float) -> void:
	for kick: Array in _kicks:
		var at: Vector2 = kick[0]
		var strength: float = float(kick[1])
		var t: float = float(kick[2]) / KICK_LIFE
		var radius := 5.0 + 26.0 * t * strength
		var alpha := (1.0 - t) * (1.0 - t) * 0.30 * strength * a
		_world.draw_arc(at, radius, 0.0, TAU, 28,
			Color(MOTION_TINT, alpha), 1.4 / ZOOM, true)


## Inert specks, at the radius they actually collide at.
func _draw_motes(a: float) -> void:
	if _motes_node == null:
		return
	var r := MotesField.MOTE_RADIUS
	var index := 0
	for point: Vector2 in _motes_node.points():
		# Stable per-slot grain, so the field is not a row of identical discs.
		var grit := float(index) * 3.7
		var grain := 0.60 + 0.40 * _noise(grit)
		_world.draw_circle(point, r * 0.72, Color(MATTER_TINT, 0.05 * grain * a), true)
		_world.draw_circle(point, r * 0.34, Color(MATTER_TINT, 0.09 * grain * a), true)
		# The outline is at the radius it actually collides at, but knocked out of
		# round so a speck of grit does not read as a drawn circle.
		var shell := PackedVector2Array()
		shell.resize(MOTE_STEPS + 1)
		for i in MOTE_STEPS + 1:
			var t := TAU * float(i % MOTE_STEPS) / float(MOTE_STEPS)
			var wobble := 1.0 + 0.10 * (_noise(grit + float(i % MOTE_STEPS) * 1.3) - 0.5) * 2.0
			shell[i] = point + Vector2(cos(t), sin(t)) * r * wobble
		_world.draw_polyline(shell, Color(MATTER_TINT, 0.40 * grain * a), 1.5 / ZOOM, true)
		index += 1


## A mote the field has recycled since it was hit, held long enough that the
## bruise on the membrane has something to be checked against.
func _draw_ghosts(a: float) -> void:
	for ghost: Array in _ghosts:
		var at: Vector2 = ghost[0]
		var t: float = float(ghost[1]) / GHOST_LIFE
		var alpha := (1.0 - t) * 0.34 * a
		_world.draw_arc(at, MotesField.MOTE_RADIUS, 0.0, TAU, 34,
			Color(MATTER_TINT, alpha), 1.6 / ZOOM, true)
		_world.draw_circle(at, MotesField.MOTE_RADIUS * 0.4,
			Color(MATTER_TINT, alpha * 0.35), true)


## The bearing a contact reported, drawn from the cell that felt it. If this ray
## does not point at the mote, the membrane is lying.
func _draw_hits(a: float) -> void:
	for hit: Array in _hits:
		var origin: Vector2 = hit[0]
		var dir: Vector2 = hit[1]
		var strength: float = float(hit[2])
		var t: float = float(hit[3]) / HIT_LIFE
		var fade := (1.0 - t) * (1.0 - t) * a
		var tint := Color(IMPACT_TINT, 0.55 * fade * strength)
		_world.draw_line(origin + dir * (_cell.radius * 0.45),
			origin + dir * (_cell.radius + MotesField.MOTE_RADIUS),
			tint, 1.8 / ZOOM, true)
		# The shock, expanding from where the two surfaces met.
		var contact := origin + dir * _cell.radius
		_world.draw_arc(contact, 5.0 + 34.0 * t, 0.0, TAU, 30,
			Color(IMPACT_TINT, 0.42 * fade * strength), 1.6 / ZOOM, true)


## **How far from its centre a body can draw anything**, as a multiple of its
## radius, and the margin on top in canvas pixels. [method _draw_cells] skips a
## body only when that far from it is still off the frame.
##
## Measured off the drawing rather than chosen. The widest thing a body draws
## is its scent haze, a [constant HAZE_OUTER] `3 r` bloom whose texture corners
## are transparent -- `3.05 r` counting the filter's last texel. Everything
## cilia.gd draws lies inside `mouth_reach` at the widest gape in the game,
## `1.24 r + 1.3 x 1.40 r = 3.06 r`; searched over every tier-3 organ, clock
## and steer, the lip tips reach `1.87 r`, the flagellum `2.18 r` and the oral
## mat `1.66 r`. Four radii clears all of them by most of a radius, and 32
## pixels covers the widest stroke and its antialiasing many times over.
const CULL_REACH := 4.0
const CULL_MARGIN := 32.0


## Every cell in the water, drawn by exactly the routine that draws the player
## (§4.5). There is no species branch here and there must never be one: two
## drawing paths would drift, and the thing the player reads off a body would
## stop being true of their own.
##
## What this file still owns is the **scent haze**, because the haze is not a
## property of the cell -- it is the drawn form of the scent field the
## membrane's green band is reading, and it is therefore a property of the
## relationship between that cell and this one.
##
## Only bodies that can reach the frame are drawn: see [constant CULL_REACH].
## The rings, wakes, meals and ghosts are other functions and are not culled.
func _draw_cells(a: float) -> void:
	if _food_node == null:
		return
	var points := _food_node.points()
	var radii := _food_node.radii()
	var headings := _food_node.headings()
	var genomes := _food_node.genomes()
	var wounds := _food_node.wounds()
	# **The cull** (shared-pond.md §3, Phase 0). Every body in the water used to
	# be drawn every frame, on screen or not, and that drawing -- not the
	# simulation -- was the largest cost a second ring of bodies would add.
	# A body is skipped only when nothing it draws can reach the frame: the
	# test is against the circle round the whole frame, so it holds at any
	# camera spin, and against the body's drawn extent rather than its centre,
	# so a haze or a mouth hanging into the frame from a body just outside it
	# is still drawn. The circle is found through `$World`'s own transform, the
	# one these draws are about to be placed by, rather than off `_camera`.
	var frame := _frame.size
	var culling := frame.x > 1.0 and frame.y > 1.0
	var middle := Vector2.ZERO
	var half := 0.0
	if culling:
		middle = _world.transform.affine_inverse() * (frame * 0.5)
		half = frame.length() * 0.5 / ZOOM
	# **In a pond the friend is drawn by [method _draw_peer]**, as a person and
	# not as a water cell, and a slot nobody is in -- retired, or not sent -- is
	# nothing at all (shared-pond.md §3).
	var pond := _food_node.pond_open()
	var bodies: Array = _food_node.bodies() if pond else []
	for i in points.size():
		if pond and (i == FoodField.PERSON_SLOT or not bool(bodies[i].seeded)):
			continue
		var p: Vector2 = points[i]
		var r: float = float(radii[i]) if i < radii.size() else FoodField.DRIFTER_MAX
		if culling:
			var reach := half + r * CULL_REACH + CULL_MARGIN / ZOOM
			if p.distance_squared_to(middle) > reach * reach:
				continue
		# A sister placed in view arrives with the arrival's fade (UX §2). Never
		# set in single player, where every body is drawn at `a` exactly.
		var ab := a
		if _fade_in.has(i):
			ab = a * clampf(float(_fade_in[i]) / SignalBus.DEATH_RETURN, 0.0, 1.0)
		# The scent as a soft haze rather than a ring: a ring here would be a
		# boundary, and the cell cannot perceive a boundary.
		#
		# **Gene-blind, and it stays gene-blind** -- always FOOD_TINT, never the
		# body's colour -- but weighted by exactly what the taste field weights
		# the body by, so a cell too big to fit in the mouth fades out of the
		# drawn scent as it fades out of the smelled one. If it were gene
		# coloured, full vision would be showing a distinction point of view
		# cannot make, in the one channel where the two views must agree.
		# food.gd owns the curve; this reads it. §4.5, last paragraph.
		var smell := smoothstep(FoodField.EDIBLE_FADE_OUT, FoodField.EDIBLE_FADE_IN,
			r / maxf(_cell.gape(), 0.001))
		_draw_scent(p, r, smell * ab)

		# The wound is drawn here and nowhere else in the game: full vision is
		# entitled to ground truth, and point of view finds out by biting and
		# by being bitten.
		Cilia.draw_cell(_world, p,
			float(headings[i]) if i < headings.size() else 0.0, r,
			genomes[i] if i < genomes.size() else {},
			_food_node.gape_at(i), _cell.radius, false, _clock, ab,
			0.0, 0.0, float(i) * 1.9, 1.0 / ZOOM, [],
			float(wounds[i]) if i < wounds.size() else 0.0)


## **"I can eat it", drawn loudly enough to be seen.** This is the only mark
## full vision has for the commonest decision in the game, and as shipped it was
## not a weak mark, it was no mark: measured off the render, the haze ring
## around an edible cell came out **0.5 of 255 greener than empty water**, while
## the water shader's own organic wash swings through ±25 in the same channel.
## The three defects were all arithmetic and all in one line:
##
## - the outermost of the three rings was drawn at alpha exactly zero, every
##   frame, for every cell -- `(1 - t)` with `t` reaching 1;
## - the largest ring was the faintest, so what ink there was got spread from
##   2.9 to 6.0 body radii, a cloud twelve bodies wide and dense nowhere;
## - the peak alpha, 0.0093, was a third of what the dithering can even carry.
##
## **Nothing about what it means has changed, and nothing may.** It is still
## `FOOD_TINT` on every edible cell whatever gene it carries, still weighted by
## exactly `food.gd`'s taste curve, so it still says precisely what the
## membrane's green band says and never more. What changed is that it is now a
## bloom that hugs the body -- brightest at the rim, gone by three radii --
## instead of a wash spread so thin it fell under the water's own texture.
## Hugging the body is also what keeps it from being mistaken for that texture:
## the wash is hundreds of pixels across and attached to nothing, and this is
## concentric with a cell and the size of that cell.
##
## **One texture, not a stack of discs**, and the reason is the sentence the old
## code wrote and then broke: *a ring here would be a boundary, and the cell
## cannot perceive a boundary.* Six concentric `draw_circle`s at a visible alpha
## are six boundaries -- built that way first, rendered, and it banded at
## 1280x720 and worse at 2400x1080, where the canvas scale makes each band half
## again as wide. A radial `GradientTexture2D` drawn once per cell has no edge
## anywhere, costs one `draw_texture_rect` instead of six polygons, and is plain
## `ImageTexture` under GL Compatibility.
##
## The ramp holds flat out to 0.42 and then falls away, so the brightest part of
## the bloom is the annulus **just outside the rim** rather than the middle --
## the middle is behind the body and cannot be seen anyway. Measured after, in
## median green of 255 out from a r18 edible cell: **99** at the rim, 36 at
## 1.3 r, 24 at 1.65 r, water by 2.7 r. An inedible cell of any size stays flat
## at 10-12, which is the water.
const HAZE_OUTER := 3.0
## Alpha at the plateau, before the edibility weight.
const HAZE_PEAK := 0.24
const HAZE_TEXTURE_SIZE := 128

var _haze: GradientTexture2D = null


## Built once. A run draws it four times a frame and never changes it.
func _build_haze() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.42, 0.62, 0.82, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 1.00), Color(1, 1, 1, 0.90), Color(1, 1, 1, 0.42),
		Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = HAZE_TEXTURE_SIZE
	tex.height = HAZE_TEXTURE_SIZE
	return tex


func _draw_scent(at: Vector2, r: float, strength: float) -> void:
	if strength <= 0.0:
		return
	if _haze == null:
		_haze = _build_haze()
	var reach := r * HAZE_OUTER
	_world.draw_texture_rect(_haze,
		Rect2(at - Vector2(reach, reach), Vector2(reach, reach) * 2.0), false,
		Color(FOOD_TINT, HAZE_PEAK * strength))


## A meal, held where it was long enough that the interior flood has something
## to be checked against.
##
## **In the gene's hue, and this is not the scent haze.** The haze is gene-blind
## because it is the drawn form of something point of view genuinely cannot
## resolve. The instant of swallowing is the opposite case: §2.2 makes the
## interior flood the gene's colour, which is `perception.md`'s one licensed
## exception, and this ring is the only thing that flood can be checked
## against. Drawing it green while the membrane floods amber would leave the
## one breach in the rule unverifiable by the view that exists to verify.
func _draw_meals(a: float) -> void:
	for meal: Array in _meals:
		var at: Vector2 = meal[0]
		var t: float = float(meal[2]) / GHOST_LIFE
		var fade := (1.0 - t) * (1.0 - t) * a
		var tint: Color = meal[3]
		_world.draw_arc(at, float(meal[1]) * (1.0 + 2.6 * t), 0.0, TAU, 34,
			Color(tint, 0.45 * fade), 1.6 / ZOOM, true)


## The bearing each pressure wake reported, drawn from the cell that felt it.
##
## This is the Phase 4 version of the bruise ray, and it is the check the whole
## view exists for: the hunter is usually off-screen when a wake lands, so the
## ray is drawn long and faded out along its length, and it has to run through
## the hunting cell when that cell is visible. If it does not, the membrane is
## lying about the only direction it ever gives for the thing hunting you.
func _draw_wakes(a: float) -> void:
	var reach := _view.length()
	for wake: Array in _wakes:
		var origin: Vector2 = wake[0]
		var dir: Vector2 = wake[1]
		var strength: float = float(wake[2])
		var t: float = float(wake[3]) / WAKE_LIFE
		var fade := (1.0 - t) * (1.0 - t) * a * strength
		var line := PackedVector2Array([
			origin + dir * (_cell.radius * 1.15), origin + dir * reach])
		_world.draw_polyline_colors(line, PackedColorArray([
			Color(PREDATOR_TINT, 0.60 * fade), Color(PREDATOR_TINT, 0.0)]),
			1.8 / ZOOM, true)


## **The `ocellus`.** One line per beam, from the rim out to whatever it found,
## and a bright point where it found it.
##
## This is the gene drawn literally, and the two views say the same thing in
## their own register: the membrane gets a lobe at that bearing and nothing
## else, and here the line that produced it is on screen -- so "the beam is
## pointing backwards because I put it in a rear slot" is a thing that can be
## seen rather than deduced. The fiction is that the hit point is *all* you can
## see; full vision draws the water anyway, because that is what full vision is
## for.
##
## A beam that hits nothing is drawn faint and short of its reach: a laser in
## open water is not nothing, it is the absence of anything, and the absence has
## to be visible or the gene reads as broken.
func _draw_beams(a: float) -> void:
	if _food_node == null:
		return
	var tone := Cilia.hue(&"ocellus")
	var origin := _cell.position
	for beam: Array in _food_node.beams:
		var dir := _ray(float(beam[0]))
		var reach := float(beam[1])
		var found := bool(beam[2])
		var root := origin + dir * (_cell.radius * 1.06)
		var tip := origin + dir * maxf(reach, _cell.radius * 1.2)
		var head := Color(tone, (0.62 if found else 0.16) * a)
		_world.draw_polyline_colors(PackedVector2Array([root, tip]),
			PackedColorArray([Color(tone, (0.34 if found else 0.10) * a), head]),
			(1.8 if found else 1.2) / ZOOM, true)
		if not found:
			continue
		# The hit. A filled point with a halo, because it is the one thing in
		# this view the blind cell can also see.
		_world.draw_circle(tip, 9.0, Color(tone, 0.16 * a), true, -1.0, true)
		_world.draw_circle(tip, 3.4, Color(tone, 0.92 * a), true, -1.0, true)


## **The `ampulla`.** Every wavefront currently in flight, as a half-ring
## expanding out of **the organ's own point on the membrane** and fading as it
## goes -- and every echo on its way back, as a short arc contracting onto the
## same point.
##
## The same two-register agreement the beam has: point of view gets a run of
## marks on the contour as each body answers, and here the thing that produced
## them is on screen -- so "the blips stopped because nothing is within reach"
## is visible rather than deduced. The bodies the echoes came off need no mark
## of their own, because full vision draws them already.
##
## **This is where the round trip gets checked.** Full vision exists to prove
## point of view is telling the truth, and the claim to check is that the skin
## lights at the same instant, at the same bearing, over the same span, that an
## echo lands on the organ. Both are drawn here off the same four numbers, so a
## disagreement is visible in one frame rather than inferred.
##
## The half is the hull: a source on the skin radiates into the hemisphere it
## faces and the rest goes into the body. Where the gene has grown enough to
## hear through a body, the other half is drawn at `ping_through` of the lit
## one -- which is the same picture point of view gets, in world space instead
## of at the figure's scale, and it is drawn off the same two numbers.
func _draw_ping(a: float) -> void:
	if _food_node == null:
		return
	var reach: float = _food_node.ping_range
	if reach <= 0.0:
		return
	var dir := _ray(_food_node.ping_bearing)
	var origin := _cell.position + dir * _cell.radius
	var mid := dir.angle()
	var tone := Cilia.hue(&"ampulla")
	var through := clampf(_food_node.ping_through, 0.0, 1.0)
	# **All of them, not just the newest.** Up to eleven pulses are in this
	# water at once at tier 3, and drawing one while the skin reported another
	# was the contradiction ping-as-outline.md §7 photographed.
	for front: float in _food_node.ping_fronts:
		if front <= 0.0:
			continue
		# Off the top of the screen long before it reaches its range, so the
		# fade is the thing that has to sell "it is still going".
		var fade := 1.0 - clampf(front / reach, 0.0, 1.0)
		# Brighter than a threshold ring, because those are measuring
		# instruments and this is a thing the cell actually did.
		_world.draw_arc(origin, front, mid - PI * 0.5, mid + PI * 0.5,
			PING_STEPS, Color(tone, 0.46 * fade * a), 1.8 / ZOOM, true)
		if through > 0.0:
			# Inset by half a step at both ends, the same half step
			# `returns.gd` takes off its own far half and for the same reason:
			# two arcs meeting at a shared vertex composite that vertex twice,
			# and the bead it makes is brighter than either half of the ring.
			_world.draw_arc(origin, front, mid + PI * 0.5 + PING_SEAM,
				mid + PI * 1.5 - PING_SEAM, PING_STEPS,
				Color(tone, 0.46 * fade * a * through), 1.8 / ZOOM, true)
	# The echoes. Brighter and thicker than the front that started them: the
	# front is the question going out and this is the answer coming back, and
	# the moment the mechanic becomes legible is the moment one of these lands.
	for echo: Array in _food_node.ping_echoes:
		var r: float = float(echo[0])
		if r <= 0.0:
			continue
		var level := clampf(float(echo[3]), 0.0, 1.0)
		if level <= 0.0:
			continue
		var span := deg_to_rad(clampf(float(echo[2]), 1.0, 180.0))
		var at := float(echo[1]) - PI * 0.5
		_world.draw_arc(origin, r, at - span, at + span, PING_STEPS,
			Color(tone, 0.80 * level * a), 2.6 / ZOOM, true)


## Threshold rings, drawn only while the cell is within RING_WINDOW of crossing
## one and faded out either side.
##
## Drawn always they are larger than the screen and the world reads as a radar
## plot -- that was rendered and it was bad. A ring is a measuring instrument,
## so it is shown at the moment of measurement and not otherwise.
func _draw_thresholds(a: float) -> void:
	if _food_node != null:
		var points := _food_node.points()
		# **Only bodies in the water** (shared-pond.md §3): a retired slot keeps
		# its last place, and in a pond the nearest "body" was sometimes one that
		# had been eaten. Every body is seeded in single player.
		var bodies := _food_node.bodies()
		var nearest := -1
		var nearest_d := INF
		for i in points.size():
			if not bool(bodies[i].seeded):
				continue
			var d := points[i].distance_to(_cell.position)
			if d < nearest_d:
				nearest_d = d
				nearest = i
		if nearest >= 0:
			_threshold(points[nearest], nearest_d, FoodField.BEARING_RANGE, FOOD_TINT, a)
			_threshold(points[nearest], nearest_d, FoodField.CORE_RANGE, FOOD_TINT, a)

	if _food_node != null:
		var hunter := _food_node.hunter()
		if hunter >= 0:
			var at: Vector2 = _food_node.points()[hunter]
			var pd := at.distance_to(_cell.position)
			_threshold(at, pd, FoodField.DREAD_RANGE, PREDATOR_TINT, a)
			_threshold(at, pd, FoodField.WAKE_RANGE, PREDATOR_TINT, a)
			_threshold(at, pd, FoodField.LUNGE_RANGE, PREDATOR_TINT, a)


func _threshold(centre: Vector2, d: float, radius: float, tint: Color, a: float) -> void:
	var near := 1.0 - smoothstep(0.0, RING_WINDOW, absf(d - radius))
	if near <= 0.02:
		return
	# Only the arc the cell is actually near. A full 1400-unit circle is mostly
	# off-screen, and the part that is on-screen is the part being measured --
	# so the span is whatever subtends the frame, not a fixed angle that reaches
	# corner to corner on the big rings and vanishes on the small ones.
	var span := clampf(_view.length() * 0.5 / maxf(radius * ZOOM, 1.0),
		RING_ARC_MIN, RING_ARC_MAX)
	var mid := (_cell.position - centre).angle()
	_world.draw_arc(centre, radius, mid - span, mid + span, RING_STEPS,
		Color(tint, 0.14 * near * a), 1.3 / ZOOM, true)


## The player's cell: the same routine as every other body in the water, plus
## the three instruments that are about *this* cell rather than about being a
## cell -- the beat halo, the heading needle and the velocity plume. The
## organism is drawn by cilia.gd; the measurements are drawn here.
func _draw_cell(a: float) -> void:
	var p := _cell.position
	var fwd := _cell.forward()
	var stb := _cell.starboard()
	var r := _cell.radius
	var beat := clampf(_beat, 0.0, 1.0)

	# **Two bodies where there was one**, drawn outside the dim the rest of the
	# world is under and with none of the three instruments below: a heading
	# needle and a velocity plume belong to a cell that is going somewhere, and
	# for these two seconds nothing is.
	if division.has("bodies"):
		_draw_daughters(p, beat)
		return

	# **Outside the dim**, when the run asks (shared-pond-ux.md §2, §5): a held
	# pond, and this cell's own pinch in a pond, dim the world behind a cell that
	# is still the thing happening. Never asked in single player, where this is
	# `a`, as it always was.
	var ca := 1.0 if own_full else a

	# Halo. Swells on the metabolic beat, which is the same beat the contour
	# brightens on -- one organism, two ways of looking at it.
	var lift := 0.6 + 0.9 * beat
	for i in HALO_STEPS:
		var k := 1.0 - float(i) / float(HALO_STEPS)
		_world.draw_circle(p, r * (1.05 + 1.75 * k),
			Color(SELF_TINT, 0.013 * (1.0 - k) * lift * ca), true, -1.0, true)

	var tiers := _genome_node.tiers() if _genome_node != null else GenomeNode.BORN
	# `is_self` is what keeps the player's own body pure SELF_TINT and its own
	# lip bow green: you are the one cell in the water whose identity you do not
	# have to read, and your own mouth cannot swallow you.
	Cilia.draw_cell(_world, p, _cell.heading, r, tiers, _cell.gape(),
		r, true, _clock, ca, _cell.steer, beat, 0.0, 1.0 / ZOOM,
		_genome_node.body_layout() if _genome_node != null else [], _cell.wound,
		float(division.get("double", 0.0)), float(division.get("pinch", 0.0)))
	_draw_held_sample(p, r, beat, ca)

	_draw_heading(p, fwd, stb, r, ca)
	# Held, the cell is going nowhere, and a plume would be the last one it had.
	if not _held:
		_draw_velocity(p, r, ca)


## The two of them, at world scale and at their own brightness. Both are
## `is_self`, so both stay pure SELF_TINT and neither takes a gene tint: they are
## still you, right up until one of them is not.
##
## **They part along the screen's horizontal, not along the body's beam**, and
## that is not a liberty -- the gesture that chooses between them is *lean left
## or lean right*. Parted abeam they land on whatever diagonal the cell happened
## to be heading on, and a player leaning left at a daughter that is up and to
## the right is being asked to read a picture that disagrees with the control.
## Undoing the world's own rotation is what keeps the two views saying the same
## thing, in the one frame where point of view is the body-relative one.
func _draw_daughters(p: Vector2, beat: float) -> void:
	var bodies: Array = division["bodies"]
	var r := float(division.get("radius", 28.28))
	var spread := float(division.get("spread", 1.0)) * DIVIDE_SPREAD
	var across := Vector2.RIGHT.rotated(-_spin)
	for side in bodies.size():
		var one: Dictionary = bodies[side]
		var tiers: Dictionary = one["tiers"]
		var seat := p + across * (spread * (-1.0 if side == 0 else 1.0))
		Cilia.draw_cell(_world, seat, _cell.heading, r, tiers,
			CellBody.gape_of(int(tiers.get(&"cytostome", 0)), r), r, true,
			_clock, float(one["fade"]), 0.0, beat, float(side) * 2.7,
			1.0 / ZOOM, one["order"], 0.0, 0.0, 0.0, float(one["shed"]))


## A gene swallowed with nowhere to put it yet, and the empty arcs it could go
## on. §3.3 gave this a disc inside the body and the owner played a run and
## never saw it; docs/design/diegetic-hud.md replaces the disc with a vesicle
## adrift, a tuft of the organ it would become floating clear of the skin, and a
## thread between them. **The routine is cilia.gd's and it is the same one the
## point-of-view figure calls**, so the two views are one picture at two scales
## rather than two drawings that have to be kept in step by hand.
##
## Point of view still gets the second, smaller heartbeat as well. The rhythm
## says *something in you is unresolved*; the body says what it is and where it
## could go, which is the discipline of having two views.
func _draw_held_sample(p: Vector2, r: float, beat: float, a: float) -> void:
	Cilia.draw_pending(_world, p, _cell.heading, r,
		_genome_node.layout() if _genome_node != null else [],
		_genome_node.held_sample if _genome_node != null else &"",
		_genome_node.held_remaining if _genome_node != null else 0.0,
		beat, _clock, a, 1.0 / ZOOM)


## Where the cell is pointing. Teal, thin, and always exactly the same length --
## it carries direction and nothing else.
func _draw_heading(p: Vector2, fwd: Vector2, stb: Vector2, r: float, a: float) -> void:
	var tint := Color(SELF_TINT, 0.62 * a)
	# Starts clear of the rim, the fringe and the lip bow. Three teal things
	# stacked on one pixel clip to white, and white belongs to impact.
	var base := p + fwd * (r * HEADING_BASE)
	var tip := p + fwd * (r * HEADING_BASE + HEADING_LEN)
	_world.draw_line(base, tip - fwd * 4.0, tint, 1.7 / ZOOM, true)
	# An open chevron, sitting off the end of the needle: nothing else in the
	# world view has this shape.
	var wing := 10.0
	_world.draw_line(tip, tip - fwd * wing + stb * (wing * 0.66), tint, 1.7 / ZOOM, true)
	_world.draw_line(tip, tip - fwd * wing - stb * (wing * 0.66), tint, 1.7 / ZOOM, true)


## Where the cell is actually going. Pale, tapered, and as long as the cell is
## fast. It disagrees with the heading most of the time, and that disagreement
## is the entire feel of the drive -- so the two are drawn in colours and shapes
## that cannot be mistaken for one another.
func _draw_velocity(p: Vector2, r: float, a: float) -> void:
	var speed := _cell.velocity.length()
	if speed < 5.0:
		return
	var dir := _cell.velocity / speed
	var side := Vector2(-dir.y, dir.x)
	var reach := minf(speed * VELOCITY_SCALE, VELOCITY_MAX)
	var norm := clampf(speed / _cell.impulse_speed(), 0.0, 1.0)
	# Starts at the rim, never over the body: a pale wedge laid across a teal
	# cell just turns both of them grey.
	var root := p + dir * (r * 1.02)
	var tip := root + dir * reach

	var wide := r * 0.38
	var plume := PackedVector2Array([
		root + side * wide, tip + side * 1.0, tip - side * 1.0, root - side * wide])
	_world.draw_colored_polygon(plume, Color(MOTION_TINT, (0.045 + 0.055 * norm) * a))
	_world.draw_line(root, tip, Color(MOTION_TINT, (0.26 + 0.22 * norm) * a), 1.5 / ZOOM, true)
	# A head, not a chevron. Shape alone separates velocity from heading even
	# where the two point the same way.
	_world.draw_circle(tip, 3.2, Color(MOTION_TINT, (0.20 + 0.16 * norm) * a), true, -1.0, true)


## **The other player, where they actually are.**
##
## Three marks, and all three are borrowed rather than invented -- every one of
## them is something this view already draws for exactly one cell in the water,
## which is the player's own:
##
## - **the halo**, the soft swell of self teal that [method _draw_cell] puts
##   under the player and under nothing else;
## - **the body in pure `SELF_TINT`**, which is `is_self` in cilia.gd and is
##   described there as *"you are the one cell in the water whose identity you
##   do not have to read"*. There are now two of those, and that is the whole
##   statement. It is also true rather than convenient: every seeded cell in
##   this water carries at least one gene (`food.gd`'s `_seed_drifter` gives a
##   drifter one at tier 1), so `body_tint` pulls every one of them 55% toward
##   a gene hue and **no cell the water makes is ever pure self teal**. An
##   untinted body is a person, by construction;
## - **the trail**, which is the other player-only instrument.
##
## What is deliberately *not* drawn is a fringe, a mouth, a heading needle or a
## velocity plume. The first two because no genome crosses the wire and a drawn
## organ would be an invented one; the last two because they are measurements of
## a cell you are steering, and nobody is steering this one from here.
##
## **`is_self` also suppresses the threat bow**, which is right for a reason
## worth writing down rather than inheriting: their mouth cannot reach you.
## The waters are not shared yet -- what crosses is a place and a pulse -- so
## drawing a friend in predator red would be the one colour in this game whose
## meaning is a relationship, asserting a relationship that does not exist.
func _draw_peer(a: float) -> void:
	if _peer.is_empty() or _cell == null:
		return
	# In a pond the friend is a body, not a marker: see [method _draw_friend].
	if _peer.has("tiers"):
		_draw_friend(a)
		return
	var at: Vector2 = _peer["at"]
	var r: float = float(_peer["radius"])
	var sure: float = float(_peer["confidence"])
	var fade := sure * a
	if fade <= 0.0 or r <= 0.0:
		return

	_draw_peer_trail(fade)

	# **The circle of "somewhere in here by now".** Drawn instead of pretending,
	# and it is the honest half of a marker that has stopped being fed: the body
	# below is the last place they were seen and this is how far they could have
	# swum since. It is not modulated by `sure` as hard as the body is -- the
	# body's confidence is falling, which is exactly when the circle is the part
	# worth reading.
	var doubt: float = float(_peer["doubt"])
	if doubt > 1.0:
		# **Drawn while it is still a circle, and not one second longer.**
		# Rendered at 400 units of doubt and the ring is wider than half the
		# frame: what is on screen is four unrelated arcs in four corners, which
		# reads as clutter rather than as a bound. Past that the honest picture
		# is the faded body on its own -- *I do not know where they are* -- and
		# off the frame the same doubt goes on working, as the width of the edge
		# mark, where a large number is still legible.
		_draw_doubt(at, doubt, 0.30 * (0.45 + 0.55 * sure) * a
			* (1.0 - smoothstep(DOUBT_READABLE, DOUBT_UNREADABLE, doubt)))

	for i in HALO_STEPS:
		var k := 1.0 - float(i) / float(HALO_STEPS)
		_world.draw_circle(at, r * (1.05 + 1.75 * k),
			Color(SELF_TINT, 0.013 * (1.0 - k) * 0.6 * fade), true, -1.0, true)

	# Empty tiers and a zero gape: cilia.gd draws no fringe for the first and
	# returns before the lip bow for the second, so this is a body and nothing
	# claimed about what is on it.
	Cilia.draw_cell(_world, at, float(_peer["heading"]), r, {}, 0.0,
		_cell.radius, true, _clock, fade, 0.0, 0.0, PEER_PHASE, 1.0 / ZOOM)


## **The friend, in one pond** (shared-pond-ux.md §0.1-§0.3): drawn by
## [method Cilia.draw_cell] like every body -- their worn tiers and order, their
## gape, their wound, the nucleus doubling from r32 -- with `is_self` false, so
## the red toothed bow shows whenever their gape exceeds your radius, and
## `untinted` true, so the body stays SELF_TINT: no cell the water makes is.
## The scent haze on the same curve as anything you could swallow. The person
## marks stay as shipped -- halo, trail, edge mark -- and carry presence.
##
## **A ghost out of the water** (§0.3): body, halo and edge mark at 0.34, no
## threat bow, no haze and no new trail points, because nothing can reach it.
func _draw_friend(a: float) -> void:
	var at: Vector2 = _peer["at"]
	var r := float(_peer["radius"])
	var alpha := float(_peer["alpha"])
	var presence := float(_peer["confidence"])
	if r <= 0.0 or alpha <= 0.0:
		return
	var ghost := bool(_peer["ghost"])
	_draw_peer_trail(presence * a)
	for i in HALO_STEPS:
		var k := 1.0 - float(i) / float(HALO_STEPS)
		_world.draw_circle(at, r * (1.05 + 1.75 * k),
			Color(SELF_TINT, 0.013 * (1.0 - k) * 0.6 * presence * a), true, -1.0, true)
	if not ghost:
		_draw_scent(at, r, smoothstep(FoodField.EDIBLE_FADE_OUT,
			FoodField.EDIBLE_FADE_IN, r / maxf(_cell.gape(), 0.001)) * alpha * a)
	# The viewer's radius decides the threat bow; a ghost's mouth can reach
	# nobody, so it is measured against a radius nothing exceeds.
	Cilia.draw_cell(_world, at, float(_peer["heading"]), r, _peer["tiers"],
		float(_peer["gape"]), INF if ghost else _cell.radius, false, _clock,
		alpha * a, 0.0, 0.0, PEER_PHASE, 1.0 / ZOOM, _peer["order"],
		float(_peer["wound"]), float(_peer["double"]), float(_peer["pinch"]), 0.0,
		true)


## **Broken, and that is the whole of what it says.** Every other ring in this
## view is solid and every one of them is a measurement -- a threshold, a cull
## boundary, a shock front -- and this is the opposite of a measurement. A solid
## circle here would be read as a boundary something is inside, which is the
## same mistake `_draw_scent` was written to avoid one function up; a broken one
## cannot be read as a boundary at all.
##
## A fixed number of dashes rather than a fixed dash length, so it stays one
## object as it grows instead of turning into a dotted line.
const DOUBT_DASHES := 20
const DOUBT_DUTY := 0.55
## Where it starts fading out and where it is gone, in world units of radius.
## The canvas is 720 units tall, so a 300-unit radius is a ring most of the
## frame high and still obviously a ring; by 460 its nearest arc and its
## farthest are on opposite sides of the screen.
const DOUBT_READABLE := 300.0
const DOUBT_UNREADABLE := 460.0


func _draw_doubt(at: Vector2, radius: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var tone := Color(SELF_TINT, alpha)
	var step := TAU / float(DOUBT_DASHES)
	for i in DOUBT_DASHES:
		var from := float(i) * step
		_world.draw_arc(at, radius, from, from + step * DOUBT_DUTY, 6,
			tone, 1.6 / ZOOM, true)


func _draw_peer_trail(fade: float) -> void:
	if _peer_trail.size() < 2:
		return
	var colors := PackedColorArray()
	colors.resize(_peer_trail.size())
	var last := float(_peer_trail.size() - 1)
	for i in _peer_trail.size():
		var t := float(i) / maxf(last, 1.0)
		colors[i] = Color(MOTION_TINT, PEER_TRAIL_ALPHA * t * fade)
	_world.draw_polyline_colors(_peer_trail, colors, TRAIL_WIDTH / ZOOM, true)


## **The half of this that is actually a locator.** The camera lags and leads
## around your own cell, so a friend swimming anywhere but alongside you is off
## the frame most of the time, and a marker you can only read when you can
## already see them is not a marker.
##
## **Bearing** is the place on the frame edge: the mark is an arc of a circle
## centred on your own body, cut where the ray to them leaves the frame, so it
## sits on the true bearing and runs *through* them the moment they come back
## into view. That is the same construction [method _draw_thresholds] uses and
## for the same reason -- only the arc near the thing being measured is worth
## drawing.
##
## **Range** is the arc's angular width, and this is the one encoding decision
## in the feature. It is not invented: it is `asin(r / d)`, the angle their body
## actually subtends from here, which is the identical arithmetic
## `normal_mode.gd`'s `_hear_others` runs to decide how wide a heard pulse lands
## on the membrane. So near is a broad cup and far is a short tick, for the same
## reason a near thing looks big -- and the two views are once again one
## picture in two registers. The only liberty is [constant PEER_MARK_GAIN],
## which is a magnification and nothing else: eight tenths of a degree is the
## truth at 2000 units and it is also not a mark.
##
## **Staleness** widens it as well as fading it, which is the part that keeps
## it from lying. The bearing to a place you last saw them five seconds ago is
## not a bearing to them, it is a bearing to the middle of a circle they could
## be anywhere in, and `atan(doubt / d)` is exactly how wide that circle looks
## from here. A quiet friend's mark goes broad, soft and vague, which is a
## sentence a player can read without being taught it.
func _draw_peer_mark(a: float) -> void:
	if _peer.is_empty() or _cell == null or _view.x <= 1.0:
		return
	var at: Vector2 = _peer["at"]
	var inset := Vector2(PEER_MARK_INSET, PEER_MARK_INSET)
	var box := Rect2(inset, (_view - inset * 2.0).max(Vector2.ONE))
	# `$World` carries the camera, the zoom and the north-up spin together, so
	# asking it is the only way to be right in all three at once.
	var to_frame := _world.transform
	var seen := to_frame * at
	var outside := seen.distance_to(seen.clamp(box.position, box.end))
	var show := smoothstep(0.0, PEER_MARK_BAND, outside)
	if show <= 0.01:
		return

	var toward := at - _cell.position
	if toward.length_squared() < 1.0:
		return
	var apart := maxf(toward.length(), float(_peer["radius"]))
	var span := clampf(
		asin(clampf(float(_peer["radius"]) / apart, 0.0, 1.0)) * PEER_MARK_GAIN
			+ atan(float(_peer["doubt"]) / apart),
		PEER_MARK_MIN, PEER_MARK_MAX)

	# **How far out to draw it, and it is the whole arc that has to fit.**
	# The arc is centred on the body, not on the frame, so its far end is not
	# its nearest point to the edge: on an oblique bearing the end nearer the
	# top of the circle stands higher than the middle does, and taking the
	# exit distance along the middle alone ran the mark off the top of a
	# 2400x1080 frame -- rendered, and that is the only way it was going to be
	# found. So the radius is the *smallest* exit over the span.
	var home := to_frame * _cell.position
	var mid_seen := to_frame.basis_xform(toward).angle()
	var reach_seen := INF
	for k in PEER_MARK_FITS:
		var off := span * (2.0 * float(k) / float(PEER_MARK_FITS - 1) - 1.0)
		reach_seen = minf(reach_seen, _exit_at(box, home, mid_seen + off))
	if not is_finite(reach_seen) or reach_seen <= 1.0:
		return
	var reach := reach_seen / ZOOM
	var mid := toward.angle()
	var fade := show * a * float(_peer["confidence"])
	var tone := Color(SELF_TINT, 0.78 * fade)
	# Thickness is the same quantity said twice, so the reading survives a
	# colour-blindness simulation and a phone in sunlight.
	var heft := lerpf(1.4, 3.4, clampf(span / PEER_MARK_MAX, 0.0, 1.0))
	_world.draw_arc(_cell.position, reach, mid - span, mid + span, 40,
		tone, heft / ZOOM, true)
	# A filled barb sitting outside the arc, pointing the way they are. Filled
	# rather than open on purpose: the open chevron is the heading needle's and
	# means *this is where I point*, which is a different sentence.
	var out := Vector2(cos(mid), sin(mid))
	var side := Vector2(-out.y, out.x)
	var root := _cell.position + out * reach
	_world.draw_colored_polygon(PackedVector2Array([
		root + out * (13.0 / ZOOM),
		root + side * (5.0 / ZOOM),
		root - side * (5.0 / ZOOM)]), Color(SELF_TINT, 0.85 * fade))


## How far the ray from [param from] on [param angle] runs before it leaves
## [param box], in the frame's own coordinates. Zero for an origin the box does
## not contain, which the camera lag cannot produce and a half-width pane could:
## a mark of no length draws nothing, which is the right answer to a question
## with no answer.
static func _exit_at(box: Rect2, from: Vector2, angle: float) -> float:
	var d := Vector2(cos(angle), sin(angle))
	var t := INF
	if absf(d.x) > 0.0001:
		t = minf(t, ((box.position.x if d.x < 0.0 else box.end.x) - from.x) / d.x)
	if absf(d.y) > 0.0001:
		t = minf(t, ((box.position.y if d.y < 0.0 else box.end.y) - from.y) / d.y)
	return 0.0 if not is_finite(t) else maxf(t, 0.0)


## Deterministic 0..1 hash. Appearance that has to stay put between frames
## cannot come from randf().
func _noise(x: float) -> float:
	return absf(fmod(sin(x * 12.9898) * 43758.5453, 1.0))


# ---------------------------------------------------------------------------
# Finding the simulation. By type, from the tree, so nothing has to hand this
# node anything and nothing else has to know it is here.
# ---------------------------------------------------------------------------

func _find_simulation() -> void:
	var root: Node = get_parent()
	if root == null:
		root = get_tree().root
	_walk(root)
	if _cell == null or _motes_node == null or _bus == null or _food_node == null \
			or _genome_node == null:
		# Instanced somewhere unusual: widen the search once before giving up.
		_walk(get_tree().root)
	if _cell == null:
		push_warning("[Vision] No cell found; the world view has nothing to draw.")


func _walk(node: Node) -> void:
	if _cell == null and node is CellBody:
		_cell = node as CellBody
	elif _motes_node == null and node is MotesField:
		_motes_node = node as MotesField
	elif _food_node == null and node is FoodField:
		_food_node = node as FoodField
	elif _genome_node == null and node is GenomeNode:
		_genome_node = node as GenomeNode
	elif _bus == null and node is SignalBus:
		_bus = node as SignalBus
	for child in node.get_children():
		_walk(child)
