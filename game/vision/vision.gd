extends CanvasLayer
## Full vision: the water the cell is actually swimming in.
##
## The game has two views of one simulation. Point of view draws nothing but the
## membrane -- that is the premise, and the game the design is built around.
## Full vision draws the world underneath it and leaves the membrane running on
## top, untouched, so the blind signals can be checked against the truth: does
## the bruise land on the bearing the mote was really on, does the taste wash
## really point at the food.
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
const SignalBus := preload("res://game/perception/signal_bus.gd")

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

# --- Body ------------------------------------------------------------------
## Decay of the beat echo, matching the membrane's own pulse decay.
const BEAT_DECAY := 0.42

const OVOID_STEPS := 40
const MOTE_STEPS := 22
const HALO_STEPS := 7
const CILIA := 32
## Fixed length, always: this is where the cell is pointing, never how fast.
const HEADING_LEN := 46.0
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

@onready var _water: ColorRect = $Water
@onready var _world: Node2D = $World

var _cell: CellBody = null
var _motes_node: MotesField = null
var _bus: SignalBus = null
var _shader: ShaderMaterial = null

## Starts off and is switched on by whoever owns the run, so point of view
## never flashes a frame of world before it is told which view it is.
var _active := false
var _amount := 0.0
var _clock := 0.0
var _camera := Vector2.ZERO
var _view := Vector2(1280.0, 720.0)

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


func _ready() -> void:
	_shader = _water.material as ShaderMaterial
	_world.draw.connect(_on_world_draw)
	_world.scale = Vector2(ZOOM, ZOOM)

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

	_apply_visibility()


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
	_apply_visibility()


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_amount = move_toward(_amount, 1.0 if _active else 0.0, delta / FADE_SECONDS)
	if _amount <= 0.0 and not _active:
		_apply_visibility()
		return

	_clock += delta
	_beat = maxf(_beat - delta / BEAT_DECAY, 0.0)
	_age(_kicks, 2, delta, KICK_LIFE)
	_age(_hits, 3, delta, HIT_LIFE)
	_age(_ghosts, 1, delta, GHOST_LIFE)

	if _water.size.x > 1.0:
		_view = _water.size
	_step_camera(delta)
	_step_trail(delta)

	_world.position = _view * 0.5 - _camera * ZOOM
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
			var dir := _cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)
			_hits.append([_cell.position, dir, float(info.get("strength", 1.0)), 0.0])
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
	_draw_trail(a)
	_draw_kicks(a)
	_draw_motes(a)
	_draw_ghosts(a)
	_draw_hits(a)
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
	var edge := CellBody.RADIUS * 1.12
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
		_world.draw_line(origin + dir * (CellBody.RADIUS * 0.45),
			origin + dir * (CellBody.RADIUS + MotesField.MOTE_RADIUS),
			tint, 1.8 / ZOOM, true)
		# The shock, expanding from where the two surfaces met.
		var contact := origin + dir * CellBody.RADIUS
		_world.draw_arc(contact, 5.0 + 34.0 * t, 0.0, TAU, 30,
			Color(IMPACT_TINT, 0.42 * fade * strength), 1.6 / ZOOM, true)


func _draw_cell(a: float) -> void:
	var p := _cell.position
	var fwd := _cell.forward()
	var stb := _cell.starboard()
	var r := CellBody.RADIUS
	var beat := clampf(_beat, 0.0, 1.0)

	# Halo. Swells on the metabolic beat, which is the same beat the contour
	# brightens on -- one organism, two ways of looking at it.
	var lift := 0.6 + 0.9 * beat
	for i in HALO_STEPS:
		var k := 1.0 - float(i) / float(HALO_STEPS)
		_world.draw_circle(p, r * (1.05 + 1.75 * k),
			Color(SELF_TINT, 0.013 * (1.0 - k) * lift * a), true, -1.0, true)

	# Body: an ovoid, narrower at the front, so the cell has a nose even before
	# the heading needle is read.
	var body := PackedVector2Array()
	body.resize(OVOID_STEPS)
	for i in OVOID_STEPS:
		var t := TAU * float(i) / float(OVOID_STEPS)
		var along := cos(t)
		var across := sin(t) * (1.0 - 0.30 * along)
		# A slow breath, so it never looks like a drawn shape.
		var breathe := 1.0 + 0.035 * sin(t * 3.0 + _clock * 1.7)
		body[i] = p + fwd * (along * r * 1.18 * breathe) + stb * (across * r * 0.94 * breathe)
	_world.draw_colored_polygon(body, Color(SELF_TINT, 0.15 * a))
	var rim := body.duplicate()
	rim.push_back(body[0])
	_world.draw_polyline(rim, Color(SELF_TINT, 0.66 * a), 2.2 / ZOOM, true)

	# Cilia, and the bearing rose hiding inside them: the four cardinals are
	# marked and everything between is even. Reading "45 degrees off my nose"
	# off the water by eye is what makes the membrane's bearings checkable.
	for i in CILIA:
		var bearing := TAU * float(i) / float(CILIA)
		var dir := fwd * cos(bearing) + stb * sin(bearing)
		var wave := 1.0 + 0.30 * sin(bearing * 3.0 + _clock * 2.1)
		var length := 6.5 * wave
		var alpha := 0.20
		if i % (CILIA / 4) == 0:
			# The four cardinals. Front, starboard, aft, port: enough to read a
			# bearing off the water by eye without a protractor on screen.
			length = 10.0
			alpha = 0.42
		_world.draw_line(p + dir * (r * 1.04), p + dir * (r * 1.04 + length),
			Color(SELF_TINT, alpha * a), 1.4 / ZOOM, true)

	# Nucleus, sitting back from the nose.
	var core := p - fwd * (r * 0.26)
	_world.draw_circle(core, r * 0.46, Color(SELF_TINT, (0.07 + 0.15 * beat) * a), true, -1.0, true)
	_world.draw_circle(core, r * 0.22, Color(SELF_TINT, (0.20 + 0.40 * beat) * a), true, -1.0, true)

	_draw_heading(p, fwd, stb, r, a)
	_draw_velocity(p, r, a)


## Where the cell is pointing. Teal, thin, and always exactly the same length --
## it carries direction and nothing else.
func _draw_heading(p: Vector2, fwd: Vector2, stb: Vector2, r: float, a: float) -> void:
	var tint := Color(SELF_TINT, 0.62 * a)
	# Starts clear of the rim and the cilia. Three teal things stacked on one
	# pixel clip to white, and white belongs to impact.
	var base := p + fwd * (r * 1.55)
	var tip := p + fwd * (r * 1.55 + HEADING_LEN)
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
	var norm := clampf(speed / CellBody.IMPULSE_SPEED, 0.0, 1.0)
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
	if _cell == null or _motes_node == null or _bus == null:
		# Instanced somewhere unusual: widen the search once before giving up.
		_walk(get_tree().root)
	if _cell == null:
		push_warning("[Vision] No cell found; the world view has nothing to draw.")


func _walk(node: Node) -> void:
	if _cell == null and node is CellBody:
		_cell = node as CellBody
	elif _motes_node == null and node is MotesField:
		_motes_node = node as MotesField
	elif _bus == null and node is SignalBus:
		_bus = node as SignalBus
	for child in node.get_children():
		_walk(child)
