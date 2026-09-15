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
	_draw_ghosts(a)
	_draw_meals(a)
	_draw_hits(a)
	_draw_wakes(a)
	_draw_beams(a)
	_draw_ping(a)
	_draw_cell(a)


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


## Every cell in the water, drawn by exactly the routine that draws the player
## (§4.5). There is no species branch here and there must never be one: two
## drawing paths would drift, and the thing the player reads off a body would
## stop being true of their own.
##
## What this file still owns is the **scent haze**, because the haze is not a
## property of the cell -- it is the drawn form of the scent field the
## membrane's green band is reading, and it is therefore a property of the
## relationship between that cell and this one.
func _draw_cells(a: float) -> void:
	if _food_node == null:
		return
	var points := _food_node.points()
	var radii := _food_node.radii()
	var headings := _food_node.headings()
	var genomes := _food_node.genomes()
	var wounds := _food_node.wounds()
	for i in points.size():
		var p: Vector2 = points[i]
		var r: float = float(radii[i]) if i < radii.size() else FoodField.DRIFTER_MAX
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
		_draw_scent(p, r, smell * a)

		# The wound is drawn here and nowhere else in the game: full vision is
		# entitled to ground truth, and point of view finds out by biting and
		# by being bitten.
		Cilia.draw_cell(_world, p,
			float(headings[i]) if i < headings.size() else 0.0, r,
			genomes[i] if i < genomes.size() else {},
			_food_node.gape_at(i), _cell.radius, false, _clock, a,
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


## **The `ampulla`.** The wavefront of the pulse that is currently in flight, as
## a ring expanding out of the cell and fading as it goes.
##
## The same two-register agreement the beam has: point of view gets a run of
## marks on the contour as each body answers, and here the thing that produced
## them is on screen -- so "the blips stopped because nothing is within reach"
## is visible rather than deduced. The returns themselves need no mark of their
## own, because in full vision the bodies they came off are already drawn.
func _draw_ping(a: float) -> void:
	if _food_node == null:
		return
	var front: float = _food_node.ping_front
	var reach: float = _food_node.ping_range
	if front <= 0.0 or reach <= 0.0:
		return
	# Off the top of the screen long before it reaches its range, so the fade is
	# the thing that has to sell "it is still going".
	var fade := 1.0 - clampf(front / reach, 0.0, 1.0)
	# Brighter than a threshold ring, because those are measuring instruments
	# and this is a thing the cell actually did. Rendered against them.
	_world.draw_arc(_cell.position, front, 0.0, TAU, 96,
		Color(Cilia.hue(&"ampulla"), 0.46 * fade * a), 1.8 / ZOOM, true)


## Threshold rings, drawn only while the cell is within RING_WINDOW of crossing
## one and faded out either side.
##
## Drawn always they are larger than the screen and the world reads as a radar
## plot -- that was rendered and it was bad. A ring is a measuring instrument,
## so it is shown at the moment of measurement and not otherwise.
func _draw_thresholds(a: float) -> void:
	if _food_node != null:
		var points := _food_node.points()
		var nearest := -1
		var nearest_d := INF
		for i in points.size():
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

	# Halo. Swells on the metabolic beat, which is the same beat the contour
	# brightens on -- one organism, two ways of looking at it.
	var lift := 0.6 + 0.9 * beat
	for i in HALO_STEPS:
		var k := 1.0 - float(i) / float(HALO_STEPS)
		_world.draw_circle(p, r * (1.05 + 1.75 * k),
			Color(SELF_TINT, 0.013 * (1.0 - k) * lift * a), true, -1.0, true)

	var tiers := _genome_node.tiers() if _genome_node != null else GenomeNode.BORN
	# `is_self` is what keeps the player's own body pure SELF_TINT and its own
	# lip bow green: you are the one cell in the water whose identity you do not
	# have to read, and your own mouth cannot swallow you.
	Cilia.draw_cell(_world, p, _cell.heading, r, tiers, _cell.gape(),
		r, true, _clock, a, _cell.steer, beat, 0.0, 1.0 / ZOOM,
		_genome_node.body_layout() if _genome_node != null else [], _cell.wound,
		float(division.get("double", 0.0)), float(division.get("pinch", 0.0)))
	_draw_held_sample(p, r, beat, a)

	_draw_heading(p, fwd, stb, r, a)
	_draw_velocity(p, r, a)


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
