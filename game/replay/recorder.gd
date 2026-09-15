extends Node
## **The last sixty seconds of the run, as data.**
##
## docs/design/replay.md settles the shape of this by measurement rather than
## from first principles. The simulation *is* bit-exactly reproducible from a
## seed at a fixed timestep -- so recording the seed and the input stream would
## work, today, and it was measured working over two hundred seconds of real
## foraging. It is still the wrong answer: the global random stream is shared
## with the perception layer, a two-pane screen would be a second consumer of
## it, and a keyframe cannot restore a stream GDScript exposes no getter for.
## *It works as long as nobody adds a `randf()` anywhere, including in a view*
## is the worst failure mode a debugging tool can have. §3.
##
## So: a state trace. It cannot desync by construction, it seeks in O(1), and --
## the part that decides it -- it needs no change to how anything simulates and
## almost none to the four view files, because the replay writes recorded state
## back into the real `Cell` / `Food` / `Genome` / `Motes` nodes and lets
## `soma.gd`, `returns.gd` and `vision.gd` read them exactly as they do now.
## *A run keeps nothing*, so scribbling on those nodes at the end of it is free.
##
## **This node is the last child of `NormalMode` on purpose**, so its `_process`
## runs after every other node's and it sees the finished frame. Nothing was
## added to `normal_mode.gd`'s `_process` to make that happen, and nothing may
## be. §4.1.
##
## **In memory and nowhere else.** No file, no `user://`, no serialisation, no
## version field, no Android storage question. The ring survives the death
## because the death does not free the scene; `_wake_up()` clears it. §4.2.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")
const MotesField := preload("res://game/normal/motes.gd")
const FoodField := preload("res://game/normal/food.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
const SomaLayer := preload("res://game/perception/soma.gd")

# ---------------------------------------------------------------------------
# The window, and it is the design rather than an optimisation.
#
# 295 float32 a frame is 1,180 bytes, which is 69 KB a second at 60 fps. A
# four-hundred-second run would be 27.7 MB and mostly empty water; sixty
# seconds is 4.1 MB, allocated once here and never grown. Nobody rewatches
# seven minutes -- the mistake that killed you is in the last twenty seconds.
# The constant below is the knob and the arithmetic is 69 KB per second bought.
# §3.1 and owner's call 1 in §7.
# ---------------------------------------------------------------------------

const SECONDS := 60
const RATE := 60
const CAPACITY := SECONDS * RATE

## What one frame is made of. Every offset below is checked by [constant
## STRIDE] adding up, and the replay reads the same constants.
const BODIES := FoodField.COUNT
const MOTES := MotesField.COUNT
const BEAMS := 3

## player: pos, heading, velocity, radius, wound, steer
const AT_PLAYER := 0
const PLAYER_FLOATS := 8
## 34 bodies x (pos, heading, radius, wound, gape)
const AT_BODIES := AT_PLAYER + PLAYER_FLOATS
const BODY_FLOATS := 6
## 14 motes x pos
const AT_MOTES := AT_BODIES + BODIES * BODY_FLOATS
## The membrane, as uniforms. signal_bus.gd is the only file that knows which.
const AT_MEMBRANE := AT_MOTES + MOTES * 2
## 3 x (bearing, distance, hit)
const AT_BEAMS := AT_MEMBRANE + SignalBus.BLOCK_FLOATS
const BEAM_FLOATS := 3
## ping_front, ping_range, held_remaining, then the division's four, then the
## frame's own delta and the beat.
const AT_TAIL := AT_BEAMS + BEAMS * BEAM_FLOATS
const AT_PING_FRONT := AT_TAIL
const AT_PING_RANGE := AT_TAIL + 1
const AT_HELD := AT_TAIL + 2
const AT_DOUBLE := AT_TAIL + 3
const AT_PINCH := AT_TAIL + 4
const AT_SPREAD := AT_TAIL + 5
const AT_COMMIT := AT_TAIL + 6
const AT_DELTA := AT_TAIL + 7
## The beat, and it is the same number as the membrane block's `pulse` -- §3.1's
## table names both and they are one value seen twice. The playback takes the
## one inside the block, because that is the one that reached the shader.
const AT_BEAT := AT_TAIL + 8
const STRIDE := AT_TAIL + 9

## Further than this between two recorded frames is a body being recycled to the
## far side of the water, not a body moving. Lerping across it would draw a
## streak; at 1/4x it would be four frames of one.
const JUMP := 400.0

## Events are pruned to the window on arrival rather than every frame, and only
## once the array is big enough for the slice to be worth doing.
const PRUNE_ABOVE := 512

# --- What the trace cannot carry, as timestamped deltas ---------------------
# Genomes, layouts, held samples and the two daughters are dictionaries and
# arrays, not floats. They change rarely and they change in steps, so they are
# recorded when they change and stepped -- never interpolated -- at playback.

enum Delta { PLAYER, BODY, DAUGHTERS }

## Measured, not estimated. §4.6 asks for `Time.get_ticks_usec()` around
## [method capture] as a rolling maximum and refuses to let the estimate be
## cited as a measurement.
var peak_usec := 0
var last_usec := 0
var _usec_total := 0
var _usec_frames := 0

var _cell: CellBody = null
var _motes: MotesField = null
var _food: FoodField = null
var _genome: GenomeNode = null
var _bus: SignalBus = null
var _soma: SomaLayer = null

## 60 x 60 x 295 float32, allocated once and never grown.
var _ring := PackedFloat32Array()
## When each ring slot was recorded, in seconds since the run began.
var _when := PackedFloat32Array()
var _head := 0
var _count := 0
var _clock := 0.0
var _recording := true
## Where the window starts once the ring is sealed: a slot and a time.
var _start := 0
var _origin := 0.0

## [[t, kind, bearing, strength], ...] -- `thrust`, `hit`, `shove` and `beat`
## off the bus, re-emitted on the replay's own bus so the world pane draws its
## kick rings, bruise rays and wake rays unchanged.
var _sensations: Array = []
## [[t, kind, at, nutrition, gene], ...] -- `motes.struck` and `food.eaten`,
## with the world positions the bus is not allowed to carry.
var _marks: Array = []
## [[t, Delta, index, payload], ...]
var _deltas: Array = []

## What the last captured frame's genomes hashed to, so a change is one integer
## compare rather than a dictionary walk. The first frame of a run always writes
## a delta, whatever the numbers happen to hash to -- the state at the start of
## the window is what every later delta is a change *from*, so it is the one
## that cannot be allowed to depend on a hash collision with zero.
var _player_seen := false
var _player_sig := 0
var _body_sig := PackedInt64Array()
var _had_daughters := false
## `CellBody.GAPE_BY_TIER[cytostome]` per body, refreshed only when that body's
## genome changes. See the note at the write site.
var _gape_scale := PackedFloat32Array()


func _ready() -> void:
	# 4.25 MB, once. Nothing here touches a window, an input device or a
	# network: a headless boot allocates the ring and records nothing anybody
	# will ever look at, which costs one allocation and no frames.
	_ring.resize(CAPACITY * STRIDE)
	_when.resize(CAPACITY)
	_body_sig.resize(BODIES)
	_gape_scale.resize(BODIES)
	_forget()

	_find(get_parent())
	if _bus != null:
		_bus.sensation.connect(_on_sensation)
	if _motes != null:
		_motes.struck.connect(_on_struck)
	if _food != null:
		_food.eaten.connect(_on_eaten)


## **After every other node in the run**, which is what being its last child
## buys. The frame is finished: the cell has moved, the water has been stepped
## and the bus has already written this frame's uniforms.
func _process(delta: float) -> void:
	if not _recording or _cell == null:
		return
	_clock += delta
	var began := Time.get_ticks_usec()
	capture(delta)
	last_usec = Time.get_ticks_usec() - began
	peak_usec = maxi(peak_usec, last_usec)
	_usec_total += last_usec
	_usec_frames += 1


## One frame, into one preallocated array. No allocation, no dictionary, no
## signal -- which is the whole reason the ring exists rather than an append.
func capture(delta: float) -> void:
	# First, so the gape multipliers below are this frame's and not last
	# frame's. It is the only part of this function that touches a dictionary,
	# and it only does so on the frames a genome actually moved.
	_watch_state()
	var at := _head * STRIDE

	_ring[at] = _cell.position.x
	_ring[at + 1] = _cell.position.y
	_ring[at + 2] = _cell.heading
	_ring[at + 3] = _cell.velocity.x
	_ring[at + 4] = _cell.velocity.y
	_ring[at + 5] = _cell.radius
	_ring[at + 6] = _cell.wound
	_ring[at + 7] = _cell.steer

	# **`bodies()`, not `points()` and the six other rebuilds.** Every accessor
	# on the field builds a fresh array on the spot, and `genomes()` allocates
	# one every call; an eighth rebuild in the hot loop is exactly the thing the
	# ring exists to avoid. This is the live array, read and not held. §4.6.
	if _food != null:
		var cells: Array = _food.bodies()
		var i := at + AT_BODIES
		for index in mini(cells.size(), BODIES):
			var b: Object = cells[index]
			var pos: Vector2 = b.pos
			_ring[i] = pos.x
			_ring[i + 1] = pos.y
			_ring[i + 2] = b.heading
			_ring[i + 3] = b.radius
			_ring[i + 4] = b.wound
			# **The gape, without three calls per body to get it.**
			# `food.gape_at()` resolves to `gape_of(tier_of(genome))`, which is
			# a dictionary lookup and two static calls -- 102 of them a frame,
			# and measured at 34 of the 80 microseconds this function costs. A
			# gape is `GAPE_BY_TIER[tier] * radius` and the tier only changes
			# when the genome does, which is a thing this file already watches,
			# so the multiplier is cached there and this is a multiply. The
			# float it writes is bit-identical to `gape_at()`'s.
			_ring[i + 5] = _gape_scale[index] * float(b.radius)
			i += BODY_FLOATS

	if _motes != null:
		var points := _motes.points()
		var i := at + AT_MOTES
		for index in mini(points.size(), MOTES):
			_ring[i] = points[index].x
			_ring[i + 1] = points[index].y
			i += 2

	if _bus != null:
		_bus.capture_block(_ring, at + AT_MEMBRANE)
		_ring[at + AT_BEAT] = _bus.pulse()

	var beam_at := at + AT_BEAMS
	for slot in BEAMS:
		var hit := 0.0
		var bearing := 0.0
		var distance := 0.0
		if _food != null and slot < _food.beams.size():
			var beam: Array = _food.beams[slot]
			bearing = float(beam[0])
			distance = float(beam[1])
			hit = 1.0 if bool(beam[2]) else 0.0
		_ring[beam_at] = bearing
		_ring[beam_at + 1] = distance
		_ring[beam_at + 2] = hit
		beam_at += BEAM_FLOATS

	_ring[at + AT_PING_FRONT] = _food.ping_front if _food != null else -1.0
	_ring[at + AT_PING_RANGE] = _food.ping_range if _food != null else 0.0
	_ring[at + AT_HELD] = _genome.held_remaining if _genome != null else 0.0
	_ring[at + AT_DELTA] = delta
	_capture_division(at)

	_when[_head] = _clock
	_head = (_head + 1) % CAPACITY
	_count = mini(_count + 1, CAPACITY)


## The division, in four floats. `double` and `pinch` are the mother becoming
## two and `spread` is how far apart they have got; `commit` is the whole of the
## choice, and it is one number because the two fades and the two sheds are one
## number wearing four coats:
##
## - **under 2 in size** it is the *difference* between the two daughters'
##   brightness -- zero while nothing is being asked, positive while the player
##   is leaning to port, negative to starboard, growing as the second of
##   commitment accrues;
## - **2 or more** one of them has been chosen, its size past 2 is how far the
##   other has gone, and its sign says which one is going.
##
## Written as a difference rather than as a pair so that no constant from
## `normal_mode.gd` is needed here; the replay, which may read that file,
## turns it back into two fades and two sheds.
func _capture_division(at: int) -> void:
	var division: Dictionary = _soma.division if _soma != null else {}
	_ring[at + AT_DOUBLE] = float(division.get("double", 0.0))
	_ring[at + AT_PINCH] = float(division.get("pinch", 0.0))
	_ring[at + AT_SPREAD] = float(division.get("spread", 0.0))
	var commit := 0.0
	if division.has("bodies"):
		var pair: Array = division["bodies"]
		if pair.size() == 2:
			var port: Dictionary = pair[0]
			var starboard: Dictionary = pair[1]
			var shed_port := float(port.get("shed", 0.0))
			var shed_starboard := float(starboard.get("shed", 0.0))
			if shed_port > 0.0:
				commit = 2.0 + shed_port
			elif shed_starboard > 0.0:
				commit = -2.0 - shed_starboard
			else:
				commit = float(port.get("fade", 0.0)) \
					- float(starboard.get("fade", 0.0))
	_ring[at + AT_COMMIT] = commit


# ---------------------------------------------------------------------------
# What the floats cannot carry. Genomes are dictionaries and layouts are
# arrays; both change in steps and rarely, so they are recorded when they
# change. Detecting the change is an integer compare, never a dictionary walk
# in the hot loop.
# ---------------------------------------------------------------------------

func _watch_state() -> void:
	if _genome != null:
		var sig := _sign_genome()
		if sig != _player_sig or not _player_seen:
			_player_seen = true
			_player_sig = sig
			_deltas.append([_clock, Delta.PLAYER, 0, {
				"dna": _genome.dna().duplicate(),
				"order": _genome.layout().duplicate(),
				"body": _genome.tiers().duplicate(),
				"bonus": _genome.bonus_slots,
				"sample": _genome.held_sample,
			}])
	if _food != null:
		var cells: Array = _food.bodies()
		for index in mini(cells.size(), BODIES):
			var b: Object = cells[index]
			# A reseed is a different body in the same slot, and a meal is the
			# same body with a new genome. Two integers catch both.
			var sig: int = int(b.serial) * 1000 + int(b.meals)
			if sig != _body_sig[index]:
				_body_sig[index] = sig
				_gape_scale[index] = CellBody.gape_of(
					GenomeNode.tier_of(b.genome, &"cytostome"), 1.0)
				_deltas.append([_clock, Delta.BODY, index,
					(b.genome as Dictionary).duplicate()])
	var has: bool = _soma != null and _soma.division.has("bodies")
	if has != _had_daughters:
		_had_daughters = has
		var pair: Array = []
		if has:
			for one: Dictionary in _soma.division["bodies"]:
				pair.append({
					"tiers": (one["tiers"] as Dictionary).duplicate(),
					"order": (one["order"] as Array).duplicate(),
				})
		_deltas.append([_clock, Delta.DAUGHTERS, 0, pair])
	if _deltas.size() > PRUNE_ABOVE:
		_prune_deltas()


## One integer for the whole genome: the body, the DNA, where the genes sit and
## what is loose inside. Tier changes, a gene arriving, two genes swapping slots
## and a sample being taken all move it.
func _sign_genome() -> int:
	var sig: int = _genome.held_sample.hash()
	for gene: StringName in _genome.tiers():
		sig += gene.hash() * (int(_genome.tiers()[gene]) + 1)
	for gene: StringName in _genome.dna():
		sig += gene.hash() * (int(_genome.dna()[gene]) + 3)
	var order: Array = _genome.layout()
	for slot in order.size():
		sig += (order[slot] as StringName).hash() * (slot + 7)
	return sig


# ---------------------------------------------------------------------------
# Events. Off signals, never polled, and pruned where they arrive rather than
# in the hot loop.
# ---------------------------------------------------------------------------

func _on_sensation(kind: StringName, info: Dictionary) -> void:
	if not _recording:
		return
	match kind:
		&"thrust", &"hit", &"shove", &"beat":
			_sensations.append([_clock, kind,
				float(info.get("bearing", 0.0)),
				float(info.get("strength", 1.0))])
			if _sensations.size() > PRUNE_ABOVE:
				_sensations = _slice_from(_sensations, _clock - float(SECONDS))
		_:
			pass


func _on_struck(_bearing: float, _strength: float, at: Vector2) -> void:
	if _recording:
		_mark(&"struck", at, 0.0, &"")


func _on_eaten(nutrition: float, gene: StringName, at: Vector2) -> void:
	if _recording:
		_mark(&"eaten", at, nutrition, gene)


func _mark(kind: StringName, at: Vector2, nutrition: float,
		gene: StringName) -> void:
	_marks.append([_clock, kind, at, nutrition, gene])
	if _marks.size() > PRUNE_ABOVE:
		_marks = _slice_from(_marks, _clock - float(SECONDS))


func _slice_from(rows: Array, cutoff: float) -> Array:
	for i in rows.size():
		if float(rows[i][0]) >= cutoff:
			return rows.slice(i) if i > 0 else rows
	return []


## Deltas are kept **one per key** before the window as well as every one
## inside it: the last genome a body had before the window opened is the genome
## it has at the start of the replay, and dropping it would leave that body
## drawn as whatever it was born as.
func _prune_deltas() -> void:
	var cutoff := _clock - float(SECONDS)
	var keep: Array = []
	var latest := {}
	for row: Array in _deltas:
		if float(row[0]) >= cutoff:
			keep.append(row)
		else:
			latest[int(row[1]) * 100 + int(row[2])] = row
	var head: Array = []
	for key: int in latest:
		head.append(latest[key])
	head.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]))
	head.append_array(keep)
	_deltas = head


# ---------------------------------------------------------------------------
# Sealing, reading, clearing.
# ---------------------------------------------------------------------------

## The run is over. Nothing more is written, and the window is fixed where it
## stands. Called from `_die()`, which is not in `_process`.
func seal() -> void:
	if not _recording:
		return
	_recording = false
	_start = (_head - _count + CAPACITY) % CAPACITY
	_origin = _when[_start] if _count > 0 else 0.0
	_prune_deltas()
	_sensations = _slice_from(_sensations, _origin)
	_marks = _slice_from(_marks, _origin)


## **A run keeps nothing.** Called from `_wake_up()`, and the only thing that
## ever empties the ring.
func clear() -> void:
	_head = 0
	_count = 0
	_clock = 0.0
	_start = 0
	_origin = 0.0
	_recording = true
	_sensations.clear()
	_marks.clear()
	_deltas.clear()
	_forget()


## Back to knowing nothing about any genome, so the next frame writes the
## opening delta for every one of them.
func _forget() -> void:
	_player_seen = false
	_player_sig = 0
	_had_daughters = false
	for i in _body_sig.size():
		# Impossible for a real body: serial and meals are both non-negative.
		_body_sig[i] = -1
		_gape_scale[i] = 0.0


func frames() -> int:
	return _count


## When the window starts, on the run's own clock. Every event in the three
## arrays below is timestamped against that clock and the playback cursor runs
## from zero, so this is what converts between them.
func origin() -> float:
	return _origin


## Seconds the window covers. Zero means there is nothing to watch.
func span() -> float:
	if _count < 2:
		return 0.0
	return _when[(_start + _count - 1) % CAPACITY] - _origin


func mean_usec() -> float:
	return float(_usec_total) / maxf(float(_usec_frames), 1.0)


func sensations() -> Array:
	return _sensations


func marks() -> Array:
	return _marks


func deltas() -> Array:
	return _deltas


## Seconds into the window that recorded frame [param i] happened at.
func time_of(i: int) -> float:
	if _count <= 0:
		return 0.0
	return _when[(_start + clampi(i, 0, _count - 1)) % CAPACITY] - _origin


## **One frame, interpolated**, into a 295-float array the caller owns.
##
## Everything lerps except the three things that would lie if they did: the
## division's `commit`, which jumps when a daughter is chosen; a beam's hit
## flag, which is a boolean; and any position that moved further than [constant
## JUMP] between two frames, which is a body or a mote being recycled to the far
## side of the water rather than swimming there.
func sample(i: int, u: float, out: PackedFloat32Array) -> void:
	if _count <= 0:
		return
	var a := clampi(i, 0, _count - 1)
	var b := mini(a + 1, _count - 1)
	var from := ((_start + a) % CAPACITY) * STRIDE
	var to := ((_start + b) % CAPACITY) * STRIDE
	var t := clampf(u, 0.0, 1.0)
	for k in STRIDE:
		out[k] = lerpf(_ring[from + k], _ring[to + k], t)
	# Angles, which cannot be lerped through the wrap at +/-PI.
	out[AT_PLAYER + 2] = lerp_angle(_ring[from + AT_PLAYER + 2],
		_ring[to + AT_PLAYER + 2], t)
	_hold_jump(out, from, to, AT_PLAYER, t)
	for index in BODIES:
		var head := AT_BODIES + index * BODY_FLOATS
		out[head + 2] = lerp_angle(_ring[from + head + 2],
			_ring[to + head + 2], t)
		_hold_jump(out, from, to, head, t)
	for index in MOTES:
		_hold_jump(out, from, to, AT_MOTES + index * 2, t)
	for slot in BEAMS:
		var head := AT_BEAMS + slot * BEAM_FLOATS
		out[head + 2] = _ring[from + head + 2]
	out[AT_COMMIT] = _ring[from + AT_COMMIT]


## A position that jumped is held at the frame it jumped from until the frame it
## jumped to, rather than drawn sliding between the two.
func _hold_jump(out: PackedFloat32Array, from: int, to: int, head: int,
		t: float) -> void:
	var dx := _ring[to + head] - _ring[from + head]
	var dy := _ring[to + head + 1] - _ring[from + head + 1]
	if dx * dx + dy * dy <= JUMP * JUMP:
		return
	out[head] = _ring[from + head] if t < 1.0 else _ring[to + head]
	out[head + 1] = _ring[from + head + 1] if t < 1.0 else _ring[to + head + 1]


# ---------------------------------------------------------------------------
# Finding the run, by type, the way vision.gd already does. Nothing hands this
# node anything and nothing else has to know it is here.
# ---------------------------------------------------------------------------

func _find(root: Node) -> void:
	if root == null:
		return
	_walk(root)


func _walk(node: Node) -> void:
	if _cell == null and node is CellBody:
		_cell = node as CellBody
	elif _motes == null and node is MotesField:
		_motes = node as MotesField
	elif _food == null and node is FoodField:
		_food = node as FoodField
	elif _genome == null and node is GenomeNode:
		_genome = node as GenomeNode
	elif _bus == null and node is SignalBus:
		_bus = node as SignalBus
	elif _soma == null and node is SomaLayer:
		_soma = node as SomaLayer
	for child in node.get_children():
		_walk(child)
