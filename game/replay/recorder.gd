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
## back into the real `Cell` / `Genome` / `Motes` nodes, and into a `Food` of its
## own, and lets `soma.gd`, `returns.gd` and `vision.gd` read them exactly as they
## do now. *A run keeps nothing* of its cell, so scribbling on the cell's nodes
## at the end of it is free. **The water is kept** since the drop -- it outlives
## the run and the player goes back into it -- so the replay binds a field of its
## own and never writes to the run's (docs/design/ocean.md §11).
##
## **Which bodies, since the drop.** A drop holds six hundred, so what is kept is
## the 48 living bodies nearest the cell each frame, each in a slot it keeps for
## as long as it stays among them; the flocs near it, told once as they settle or
## come into reach and once as they go, since they never move; and the drop's rim,
## once. Today's water, which a run with a session still plays, is recorded the
## same way and comes out as it always did: its 34 bodies are always the nearest,
## and take the slots of their own indices.
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
# 472 float32 a frame is 1,888 bytes, which is 113 KB a second at 60 fps. A
# four-hundred-second run would be 45 MB and mostly empty water; sixty seconds
# is 6.8 MB, allocated once here and never grown. Nobody rewatches seven
# minutes -- the mistake that killed you is in the last twenty seconds. The
# constant below is the knob and the arithmetic is 113 KB per second bought.
#
# It was 296 floats and 69 KB/s until the wave bounced. Two more glow lobes and
# their hollowness are eight and one, and the pulse out and back is eighteen:
# two front radii and four echoes of four scalars each. Measured on the new
# stride, one capture() costs 186 us at its worst and 104 us on average. The
# beam's twenty-four rays took it to 385, and the drop to 470: fourteen more
# bodies of six floats, and the killer's slot (docs/design/ocean.md §11).
# Hunger took it to 472: how far the membrane had fallen in, inside the
# membrane's block, and how slack the body was (docs/design/hunger.md §2.5).
# §3.1 and owner's call 1 in §7.
# ---------------------------------------------------------------------------

const SECONDS := 60
const RATE := 60
const CAPACITY := SECONDS * RATE

## What one frame is made of. Every offset below is checked by [constant
## STRIDE] adding up, and the replay reads the same constants.
##
## **Forty-eight bodies: the living ones nearest the cell, each frame** (ocean.md
## §11). At the drop's density they reach about 1,770 µm, which is the frame,
## dread, scent and the beam; today's water has 34 and every one of them fits.
const BODIES := 48
const MOTES := MotesField.COUNT
## **How far a body may be and still be kept**: where the drop steps every body
## every frame, and past which no sense reaches -- `drop_probe`'s check 7 holds
## every reach in the tables inside it. Near the rim, or in water the dead have
## thinned, fewer than [constant BODIES] may be this close, and the rest of the
## slots are empty: nothing past it is anything either pane could show. Today's
## water keeps every body well inside it (`food.gd`'s `CULL`).
const REACH := FoodField.Drop.LOD_NEAR
## A body's place in the field, packed under its distance so one native sort
## orders a frame's candidates: the index in the low bits.
const INDEX_BITS := 16
const INDEX_MASK := (1 << INDEX_BITS) - 1
## **Twenty-four rays a frame**, not three: past its fork the beam grows a ray a
## level (beam-levels.md §7). That is 63 more floats a frame than three -- about
## 0.9 MB more ring over the minute -- and the ring lives in RAM and is never
## saved, so no older recording has to be read. A fan wider than this, which is
## tens of hours of use away, keeps its hits first and drops misses.
const BEAMS := 24

## player: pos, heading, velocity, radius, wound, steer
const AT_PLAYER := 0
const PLAYER_FLOATS := 8
## 48 bodies x (pos, heading, radius, wound, gape). **A radius of 0 is an empty
## slot**, which both views draw as nothing -- the mirror's convention.
const AT_BODIES := AT_PLAYER + PLAYER_FLOATS
const BODY_FLOATS := 6
## 14 motes x pos
const AT_MOTES := AT_BODIES + BODIES * BODY_FLOATS
## The membrane, as uniforms. signal_bus.gd is the only file that knows which.
const AT_MEMBRANE := AT_MOTES + MOTES * 2
## 24 x (bearing, distance, hit)
const AT_BEAMS := AT_MEMBRANE + SignalBus.BLOCK_FLOATS
const BEAM_FLOATS := 3
## **The ping, out and back.** Two outgoing fronts and four returning echoes,
## then ping_range, held_remaining, the division's four, the frame's own delta,
## the beat, the hunter, the killer and the slack.
##
## Two and four, and both numbers were measured rather than chosen. The field
## can hold eleven fronts and fifty-five echoes at tier 3, and recording all of
## them would cost 200 floats a frame for a picture that is mostly off screen: a
## front leaves the frame in under a second against a 1.4 s period, so at most
## two are ever inside it, and four echoes covers every instant of the tier-3
## ambiguity pose. `food.gd` sorts the echoes nearest-home first, so the four
## kept are the four about to land -- which are the ones a viewer is watching.
const AT_TAIL := AT_BEAMS + BEAMS * BEAM_FLOATS
const PING_FRONTS := 2
const PING_ECHOES := 4
## `[radius, bearing, halfwidth_deg, level]`.
const ECHO_FLOATS := 4
const AT_PING_FRONTS := AT_TAIL
const AT_PING_ECHOES := AT_TAIL + PING_FRONTS
const AT_PING_RANGE := AT_PING_ECHOES + PING_ECHOES * ECHO_FLOATS
const AT_HELD := AT_PING_RANGE + 1
const AT_DOUBLE := AT_PING_RANGE + 2
const AT_PINCH := AT_PING_RANGE + 3
const AT_SPREAD := AT_PING_RANGE + 4
const AT_COMMIT := AT_PING_RANGE + 5
const AT_DELTA := AT_PING_RANGE + 6
## The beat, and it is the same number as the membrane block's `pulse` -- §3.1's
## table names both and they are one value seen twice. The playback takes the
## one inside the block, because that is the one that reached the shader.
const AT_BEAT := AT_PING_RANGE + 7
## **Who was hunting you, as one float, and it is the whole of the reason this
## column exists.** `hunter()` is a question about a state machine -- STALK, and
## the target being the player -- and a state machine is the one thing
## [method FoodField.restore_body] deliberately does not write. So in a replay
## every body answers DRIFT and `vision.gd`'s predator rings do not draw at all:
## the dread, wake and lunge circles are missing from the replay of a run that
## ended in being eaten, which is the case the truth pane exists for. It is
## worse than a stale ring, because the body that swallowed you is *reseeded* on
## contact -- `food.gd` says "it is gone, not fleeing" -- so there is no stale
## answer to fall back on either.
##
## Recorded rather than suppressed, and it costs one float: the rings are drawn
## for the single nearest stalker and never for more than one. -1 is nobody, and
## it is stepped rather than lerped at playback the way [constant AT_COMMIT] is
## -- a slot halfway between slot 3 and slot 9 is slot 6, which is a different
## cell in a different place. 4 bytes a frame is 0.24 KB/s against 113. **It is
## a recorder slot, not a field index** (ocean.md §11): the field's index means
## nothing to a replay that has a field of its own.
const AT_HUNTER := AT_PING_RANGE + 8
## **Who killed you, as a slot** (ocean.md §11): the body that swallowed you or
## chewed you through, or the venomous one you bit. [method FoodField.hunter]
## answers only for a stalker, and in the drop most deaths by mouth are by a cell
## that was not hunting you, so without this the truth pane would draw no
## predator for them. -1 is nobody, and stepped like [constant AT_HUNTER].
##
## **Written at the seal, over every frame that body held its slot**, not on the
## frame of the death alone, and the reason is two measurements. The ring is
## sealed before the death is captured and the replay loops as its cursor
## reaches the last frame, so a stepped float on the last frame is never on
## screen; and a predator ring is drawn only while the cell is within
## `vision.gd`'s `RING_WINDOW`, 130, of crossing it -- at contact, some 60 from
## the killer's centre, the nearest of the three rings, 220, is 160 away. So the
## killer is named on the frames of its approach, and its rings are drawn as the
## cell crossed them, whenever nothing was hunting it.
const AT_KILLER := AT_PING_RANGE + 9
## **How slack the body was** (docs/design/hunger.md §2.5): the drawn slack the
## run handed both views, so the replay crumples the body exactly as the run
## did -- the membrane's fall rides in its block, and this is the body's half.
## A quantity, so it lerps.
const AT_SLACK := AT_PING_RANGE + 10
const STRIDE := AT_PING_RANGE + 11

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
#
# **And the drop's** (ocean.md §11). A body's genome is written when a body
# takes a slot and when it eats, keyed on the body itself, so a slot that
# changes hands never shows the last one's genes. A floc is SETTLE and CLEAR,
# like the wire's: its place, its radius, how far it had settled and how long it
# had to live, once as it comes into reach or lands in it, and once as it goes --
# it never moves, and its fade is a function of time. A cell that starves or is
# poisoned in view is its slot emptying and a SETTLE where it was, already
# settled, so the replay shows the death as it happened with nothing new
# recorded. The drop's centre and radius are one RIM, at the start.
#
# **And your programs** (docs/design/automation.md §11): your instincts move
# nothing that is not already recorded, but *why* has to be recorded to be
# drawn. PROGRAMS is the programs that are on, in order, `[name, lines]` each --
# at the start of the window and at every edit, switch and reorder -- and ACTS
# is `[the autopilot drives, the tail is held, a mask of the instincts that acted
# on the last tick, by their place in the merged list]`, whenever any of them
# changes: at most 7.5 a second. A run with nothing on records ACTS only for the
# hand's holds. Both are dictionaries' worth in a row, so [constant STRIDE] does
# not move.

enum Delta { PLAYER, BODY, DAUGHTERS, RIM, SETTLE, CLEAR, PROGRAMS, ACTS }

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

## 60 x 60 x 322 float32, allocated once and never grown.
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
## [[t, Delta, index, payload], ...] -- the index a slot for BODY, a floc's id
## for SETTLE and CLEAR, and 0 for the rest; a BODY row carries the body's id
## after its genome.
var _deltas: Array = []

## What the last captured frame's player genome hashed to, so a change is one
## integer compare rather than a dictionary walk. The first frame of a run always
## writes a delta, whatever the numbers happen to hash to -- the state at the
## start of the window is what every later delta is a change *from*, so it is
## the one that cannot be allowed to depend on a hash collision with zero. A
## body's is two integers, its serial and its meals, kept by slot below.
var _player_seen := false
var _player_sig := 0
var _had_daughters := false
## The programs last written, and the last `[drives, held, mask]` as one int:
## what a PROGRAMS and an ACTS are changes from. Nothing on and nothing held is
## where a run starts, and writes nothing.
var _programs_kept: Array = []
var _acts_kept := 0
## `CellBody.GAPE_BY_TIER[cytostome]` per slot, refreshed only when the genome
## in it changes. See the note at the write site.
var _gape_scale := PackedFloat32Array()

# --- The slots (ocean.md §11) ------------------------------------------------
## Who is in each slot: the body's serial -- new for every body the water makes,
## as its id is in the drop, and there in today's water too -- or -1 for an
## empty slot; and its index in the field, -1 as well.
var _slot_serial := PackedInt64Array()
var _slot_index := PackedInt32Array()
## Its meals when its genome was last written, -1 to write it on the next frame.
var _slot_meals := PackedInt32Array()
## The capture it took the slot on, counted since the ring was cleared.
var _slot_since := PackedInt64Array()
## The frame it was last found among the nearest.
var _slot_stamp := PackedInt64Array()
## Each field index's slot, or -1: the other way round, so a body found this
## frame is looked up rather than searched for.
var _slot_by_index := PackedInt32Array()
## Every capture since the ring was cleared, and this one's stamp.
var _captures := 0
var _stamp := 0
## One frame's candidates, as distance and index packed together; and the ones
## new to the slots, by index.
var _keys := PackedInt64Array()
var _fresh := PackedInt32Array()
var _no_bodies: Array[FoodField.Body] = []
## Each floc in reach at the last capture, by its id: the stamp that found it.
var _floc_stamp := {}
## The rim last written, so a RIM goes in once.
var _rim_seen := false
var _rim_center := Vector2.ZERO
var _rim_radius := 0.0
## How big the deltas may get before the next prune. Grows with what a prune
## keeps, so a window that holds more than [constant PRUNE_ABOVE] rows is pruned
## now and then rather than every frame.
var _prune_at := PRUNE_ABOVE


func _ready() -> void:
	# 6.8 MB, once. Nothing here touches a window, an input device or a
	# network: a headless boot allocates the ring and records nothing anybody
	# will ever look at, which costs one allocation and no frames.
	_ring.resize(CAPACITY * STRIDE)
	_when.resize(CAPACITY)
	_gape_scale.resize(BODIES)
	_slot_serial.resize(BODIES)
	_slot_index.resize(BODIES)
	_slot_meals.resize(BODIES)
	_slot_since.resize(BODIES)
	_slot_stamp.resize(BODIES)
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

	_capture_bodies(at)

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
	var kept := _kept_beams()
	for slot in BEAMS:
		var hit := 0.0
		var bearing := 0.0
		var distance := 0.0
		if slot < kept.size():
			var beam: Array = _food.beams[kept[slot]]
			bearing = float(beam[0])
			distance = float(beam[1])
			hit = 1.0 if bool(beam[2]) else 0.0
		_ring[beam_at] = bearing
		_ring[beam_at + 1] = distance
		_ring[beam_at + 2] = hit
		beam_at += BEAM_FLOATS

	_capture_ping(at)
	_ring[at + AT_PING_RANGE] = _food.ping_range if _food != null else 0.0
	_ring[at + AT_HELD] = _genome.held_remaining if _genome != null else 0.0
	# One integer-valued float, and the only thing in this loop that asks the
	# field a question rather than reading a number off it. See AT_HUNTER.
	_ring[at + AT_HUNTER] = float(_slot_of(_food.hunter())) if _food != null else -1.0
	# Nobody, until the seal says who. See AT_KILLER.
	_ring[at + AT_KILLER] = -1.0
	_ring[at + AT_SLACK] = _soma.slack if _soma != null else 0.0
	_ring[at + AT_DELTA] = delta
	_capture_division(at)

	_when[_head] = _clock
	_head = (_head + 1) % CAPACITY
	_count = mini(_count + 1, CAPACITY)
	_captures += 1
	if _deltas.size() > _prune_at:
		_prune_deltas()


## **The 48 living bodies nearest the cell, each in a slot it keeps** (ocean.md
## §11), and the flocs in reach as deltas.
##
## One grid question a frame, through the field's own `bodies_near()`, out to
## [constant REACH]; the candidates ordered by one native sort of their
## distances. A body found again keeps its slot. One gone -- out of the nearest,
## eaten, starved -- empties its slot, which writes radius 0 from this frame. A
## newcomer takes the lowest empty slot, newcomers in the order of the field's
## own slots, which is what leaves today's water exactly where it always was:
## its 34 bodies are always the nearest, a reseed is a body gone and one come in
## the same field slot, and each lands in the slot of its own index.
##
## A slot that changes hands in one frame is two bodies, possibly far apart, in
## the same six floats. [method sample] holds such a jump rather than drawing a
## body sliding between them; a newcomer is on the edge of the nearest, so the
## two are nearly always further apart than [constant JUMP], and on the rare
## frame they are not, both are far off the edge of any pane.
func _capture_bodies(at: int) -> void:
	_stamp += 1
	_keys.resize(0)
	_fresh.resize(0)
	# Typed, because it is read some two hundred times a frame: a property of
	# a typed body is a direct read, of an untyped one a lookup by name.
	var cells: Array[FoodField.Body] = _food.bodies() if _food != null else _no_bodies
	if _food != null:
		var here := _cell.position
		for index: int in _food.bodies_near(here, REACH):
			var b := cells[index]
			# The other player, in a pond: never a water body. A pond's
			# replay is withheld anyway (normal_mode `_offer_replay`).
			if b.person != null:
				continue
			if b.inert:
				_floc_found(b)
				continue
			var pos: Vector2 = b.pos
			_keys.append((int(pos.distance_squared_to(here)) << INDEX_BITS) | index)
		_keys.sort()
		_flocs_gone()
	if _slot_by_index.size() < cells.size():
		var old := _slot_by_index.size()
		_slot_by_index.resize(cells.size())
		for k in range(old, cells.size()):
			_slot_by_index[k] = -1
	var n := mini(_keys.size(), BODIES)
	# Still here: the same slot.
	for k in n:
		var index := int(_keys[k] & INDEX_MASK)
		var slot := _slot_by_index[index]
		if slot >= 0 and _slot_serial[slot] == cells[index].serial:
			_slot_stamp[slot] = _stamp
		else:
			_fresh.append(index)
	# Gone: the slot empties.
	for slot in BODIES:
		if _slot_serial[slot] >= 0 and _slot_stamp[slot] != _stamp:
			var was := _slot_index[slot]
			if was >= 0 and was < _slot_by_index.size() and _slot_by_index[was] == slot:
				_slot_by_index[was] = -1
			_slot_serial[slot] = -1
			_slot_index[slot] = -1
	# New: the lowest empty slot, in the field's order.
	_fresh.sort()
	var free := 0
	for index: int in _fresh:
		while free < BODIES and _slot_serial[free] >= 0:
			free += 1
		if free >= BODIES:
			break
		_slot_serial[free] = cells[index].serial
		_slot_index[free] = index
		_slot_by_index[index] = free
		_slot_since[free] = _captures
		_slot_meals[free] = -1
		_slot_stamp[free] = _stamp
	# **`bodies()`, not `points()` and the six other rebuilds.** Every accessor
	# on the field builds a fresh array on the spot, and `genomes()` allocates
	# one every call; an eighth rebuild in the hot loop is exactly the thing the
	# ring exists to avoid. This is the live array, read and not held. §4.6.
	var i := at + AT_BODIES
	for slot in BODIES:
		var index := _slot_index[slot]
		if index < 0:
			for k in BODY_FLOATS:
				_ring[i + k] = 0.0
			i += BODY_FLOATS
			continue
		var b := cells[index]
		# **Its genome, keyed on the body**: when it takes the slot, and when
		# it eats -- a meal is the only thing that moves a genome in either
		# water. Stepped at playback, and carrying the body's id.
		var meals := b.meals
		if meals != _slot_meals[slot]:
			_slot_meals[slot] = meals
			_gape_scale[slot] = CellBody.gape_of(
				GenomeNode.tier_of(b.genome, &"cytostome"), 1.0)
			_deltas.append([_clock, Delta.BODY, slot, b.genome.duplicate(), b.id])
		var pos := b.pos
		_ring[i] = pos.x
		_ring[i + 1] = pos.y
		_ring[i + 2] = b.heading
		_ring[i + 3] = b.radius
		_ring[i + 4] = b.wound
		# **The gape, without three calls per body to get it.**
		# `food.gape_at()` resolves to `gape_of(tier_of(genome))`, which is a
		# dictionary lookup and two static calls -- 102 of them a frame, and
		# measured at 34 of the 80 microseconds this function costs. A gape is
		# `GAPE_BY_TIER[tier] * radius` and the tier only changes when the
		# genome does, which is a thing this file already watches, so the
		# multiplier is cached there and this is a multiply. The float it writes
		# is bit-identical to `gape_at()`'s.
		_ring[i + 5] = _gape_scale[slot] * b.radius
		i += BODY_FLOATS


## A floc in reach this frame: told the first frame it is, with where it lies,
## how big it is, how far it has settled and how long it has left.
func _floc_found(b: FoodField.Body) -> void:
	if not _floc_stamp.has(b.id):
		_deltas.append([_clock, Delta.SETTLE, b.id, [b.pos, b.radius, b.settle, b.life]])
	_floc_stamp[b.id] = _stamp


## Every floc in reach last frame and not this one: eaten, dissolved, or left
## behind.
func _flocs_gone() -> void:
	if _floc_stamp.is_empty():
		return
	for id: int in _floc_stamp.keys():
		if int(_floc_stamp[id]) != _stamp:
			_floc_stamp.erase(id)
			_deltas.append([_clock, Delta.CLEAR, id, null])


## The slot the body at field index [param index] is in this frame, or -1.
func _slot_of(index: int) -> int:
	if index < 0 or index >= _slot_by_index.size():
		return -1
	return _slot_by_index[index]


## **The pulse, out and back**, in eighteen floats. A radius per outgoing front
## and four scalars per returning echo, both already sorted by the field -- the
## fronts oldest first, so the newest and therefore smallest two are kept; the
## echoes nearest-home first, so the four about to land are.
##
## A radius of -1 is an empty slot, which is the same convention the single
## `ping_front` used for "nothing in flight". An echo with level 0 is empty and
## neither view draws it.
func _capture_ping(at: int) -> void:
	for i in PING_FRONTS:
		_ring[at + AT_PING_FRONTS + i] = -1.0
	for i in PING_ECHOES:
		var e := at + AT_PING_ECHOES + i * ECHO_FLOATS
		_ring[e] = -1.0
		_ring[e + 1] = 0.0
		_ring[e + 2] = 0.0
		_ring[e + 3] = 0.0
	if _food == null:
		return
	var fronts: Array = _food.ping_fronts
	# From the end: the fronts are oldest first and the newest are the ones
	# still inside the frame.
	for i in mini(fronts.size(), PING_FRONTS):
		_ring[at + AT_PING_FRONTS + i] = float(fronts[fronts.size() - 1 - i])
	var echoes: Array = _food.ping_echoes
	for i in mini(echoes.size(), PING_ECHOES):
		var echo: Array = echoes[i]
		var e := at + AT_PING_ECHOES + i * ECHO_FLOATS
		_ring[e] = float(echo[0])
		_ring[e + 1] = float(echo[1])
		_ring[e + 2] = float(echo[2])
		_ring[e + 3] = float(echo[3])


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


## **Which of the field's beams get a slot**, in the field's own order while
## they fit -- a slot has to be the same ray frame after frame, or playback
## would lerp one ray's bearing into another's. Only a fan wider than
## [constant BEAMS] is reordered, hits first, so what it found survives.
func _kept_beams() -> PackedInt32Array:
	var out := PackedInt32Array()
	if _food == null:
		return out
	var total: int = _food.beams.size()
	if total <= BEAMS:
		for i in total:
			out.append(i)
		return out
	for i in total:
		if bool(_food.beams[i][2]):
			out.append(i)
	for i in total:
		if out.size() >= BEAMS:
			break
		if not bool(_food.beams[i][2]):
			out.append(i)
	out.resize(mini(out.size(), BEAMS))
	return out


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
				# **Where the organs are worn, and it cannot be derived.**
				# `order` is the DNA's layout; this is the body's, and a gene
				# move parts them -- `move()` swaps two loci in the DNA and
				# leaves the body exactly where it is. Rebuilding this from
				# `order` at playback drew every organ at the slot the DNA has
				# it in rather than the slot it was grown in: the soma figure's
				# fringe and the `ampulla`'s wavefront both read it, so a
				# watched run put the tuft and the wave on the wrong arc from
				# the moment the player moved a gene. A delta is a dictionary,
				# so the one key costs nothing in [constant STRIDE].
				# `body_layout()` builds a fresh array, hence no duplicate.
				"worn": _genome.body_layout(),
				"bonus": _genome.bonus_slots,
				"sample": _genome.held_sample,
				# **The lineage's levels** (beam-levels.md §7): what the beam's
				# shape and a sweep's hold are read off at playback.
				"levels": _genome.level_state(),
			}])
	# **The drop's rim**, once: it moves only when a run starts in it, and the
	# ring is cleared then. Today's water has none, and writes none.
	var rim: RefCounted = _food.basin() if _food != null else null
	if rim != null:
		var center: Vector2 = rim.get(&"center")
		var radius := float(rim.get(&"radius"))
		if not _rim_seen or center != _rim_center or radius != _rim_radius:
			_rim_seen = true
			_rim_center = center
			_rim_radius = radius
			_deltas.append([_clock, Delta.RIM, 0, [center, radius]])
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
	_watch_programs()


## **Your programs, and what drove your cell** (automation.md §11): read off the
## cell -- whether the autopilot has it, whether its tail is held -- and off the
## instincts it is handed, which say what is on and what acted.
func _watch_programs() -> void:
	if _cell == null:
		return
	var instincts: RefCounted = _cell.instincts
	if instincts != null:
		var on: Array = instincts.get(&"programs")
		if on != _programs_kept:
			_programs_kept = on.duplicate(true)
			_deltas.append([_clock, Delta.PROGRAMS, 0, _programs_kept.duplicate(true)])
	var driving: bool = _cell.autopilot
	var held: bool = _cell.tail_held()
	var mask := int(instincts.get(&"acted")) if driving and instincts != null else 0
	var acts := (1 if driving else 0) | (2 if held else 0) | (mask << 2)
	if acts != _acts_kept:
		_acts_kept = acts
		_deltas.append([_clock, Delta.ACTS, 0, [driving, held, mask]])


## One integer for the whole genome: the body, the DNA, where the genes sit on
## each of them, and what is loose inside. Tier changes, a gene arriving, two
## genes swapping slots and a sample being taken all move it.
##
## **Both layouts, because they are two facts.** A daughter can be expressed
## from her mother's DNA unchanged and still wear an organ somewhere else --
## the mother's move wrote the DNA and left her own body alone, and the birth
## expresses that DNA onto a fresh body -- so a signature over the DNA alone
## would find nothing changed on the one frame the arcs move. The worn slots go
## in as `hash x slot` rather than as a bare slot number, so two organs trading
## places cannot cancel each other out.
func _sign_genome() -> int:
	var sig: int = _genome.held_sample.hash()
	for gene: StringName in _genome.tiers():
		# Distinct primes on the two terms. Summed onto one multiplier they
		# were `hash * (tier + slot + 12)`, so a tier rising by one while the
		# worn slot fell by one in the same frame -- a birth after a move and
		# a meal -- cancelled to the same integer, wrote no delta, and the
		# replay drew the mother's organ on the old arc for the daughter's
		# whole life.
		sig += gene.hash() * (int(_genome.tiers()[gene]) + 1) * 31
		sig += gene.hash() * (_genome.slot_of(gene) + 11) * 101
	for gene: StringName in _genome.dna():
		sig += gene.hash() * (int(_genome.dna()[gene]) + 3)
	var order: Array = _genome.layout()
	for slot in order.size():
		sig += (order[slot] as StringName).hash() * (slot + 7)
	# **A level, not its experience.** Experience moves every second the beam
	# touches something, and a delta a second is a delta nobody needs; what
	# playback reads is the shape, which moves on a level or a path.
	#
	# **The banked level, not the one held at the fork.** Signed by the held
	# one, a level earned past an open fork wrote nothing, so a watched run
	# never saw the eye flare for it or its lobes move apart
	# (beam-levels.md §8.4-§8.5) -- the shape alone did not need it; the eye
	# does. The held level moves only when this one does, or with the path.
	var levels: Dictionary = _genome.levels()
	for gene: StringName in levels:
		var grown: RefCounted = levels[gene]
		sig += gene.hash() * (int(grown.level()) + 13) * 307
		sig += StringName(grown.path).hash() * 17
	return sig


# ---------------------------------------------------------------------------
# Events. Off signals, never polled, and pruned where they arrive rather than
# in the hot loop.
# ---------------------------------------------------------------------------

func _on_sensation(kind: StringName, info: Dictionary) -> void:
	if not _recording:
		return
	# **Nothing happens on the pause screen, and the bus does not agree.**
	# `Membrane` is PROCESS_MODE_ALWAYS so the bus keeps beating through a
	# pause; this node is PROCESS_MODE_PAUSABLE so `_clock` does not move. Left
	# alone, a thirty-second pause files about forty-two `beat` rows at one
	# identical timestamp, and `replay._fire_events()` fires every one of them
	# in a single frame -- a burst of wake rays the player never saw. The same
	# hazard §2 found in the random stream, in the one place it still reaches.
	if get_tree().paused:
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
## inside it: the last genome a slot had before the window opened is the genome
## it has at the start of the replay, and dropping it would leave that body
## drawn as whatever it was born as.
##
## **A floc is keyed on its id**, and kept only if the last word on it before
## the window was that it settled: one cleared before the window opened is not
## there at its start.
func _prune_deltas() -> void:
	var cutoff := _clock - float(SECONDS)
	var keep: Array = []
	var latest := {}
	var flocs := {}
	for row: Array in _deltas:
		if float(row[0]) >= cutoff:
			keep.append(row)
			continue
		var kind := int(row[1])
		if kind == Delta.SETTLE or kind == Delta.CLEAR:
			flocs[int(row[2])] = row
		else:
			latest[kind * 100 + int(row[2])] = row
	var head: Array = []
	for key: int in latest:
		head.append(latest[key])
	for id: int in flocs:
		if int(flocs[id][1]) == Delta.SETTLE:
			head.append(flocs[id])
	head.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]))
	head.append_array(keep)
	_deltas = head
	_prune_at = maxi(PRUNE_ABOVE, _deltas.size() * 2)


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
	_mark_killer()
	_prune_deltas()
	_sensations = _slice_from(_sensations, _origin)
	_marks = _slice_from(_marks, _origin)


## **Who killed the cell, named in the ring** (see [constant AT_KILLER]): the
## field says which body did it, and that body's slot is written into every
## frame since it took the slot. A death with no mouth in it -- hunger -- names
## nobody, and neither does today's water, whose field never says.
func _mark_killer() -> void:
	if _food == null or _count <= 0:
		return
	var index: int = _food.died_to
	var slot := _slot_of(index)
	if slot < 0:
		return
	var cells: Array[FoodField.Body] = _food.bodies()
	if index >= cells.size() or _slot_serial[slot] != cells[index].serial:
		return
	for n in range(maxi(_slot_since[slot], _captures - _count), _captures):
		_ring[(n % CAPACITY) * STRIDE + AT_KILLER] = float(slot)


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


## Back to knowing nothing about any genome, any slot, any floc or the rim, so
## the next frame writes the opening delta for every one of them.
func _forget() -> void:
	_player_seen = false
	_player_sig = 0
	_had_daughters = false
	_programs_kept = []
	_acts_kept = 0
	# -1 is impossible for a real body: serial and meals are both non-negative.
	_slot_serial.fill(-1)
	_slot_index.fill(-1)
	_slot_meals.fill(-1)
	_slot_since.fill(0)
	_slot_stamp.fill(0)
	_slot_by_index.fill(-1)
	_gape_scale.fill(0.0)
	_captures = 0
	_stamp = 0
	_floc_stamp.clear()
	_rim_seen = false
	_prune_at = PRUNE_ABOVE


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


## **The drop's rim at the start of the window**, `[centre, radius]`, or empty
## for a recording of today's water: what a replay's field is made round.
func rim() -> Array:
	for row: Array in _deltas:
		if int(row[1]) == Delta.RIM:
			return row[3]
	return []


## Seconds into the window that recorded frame [param i] happened at.
func time_of(i: int) -> float:
	if _count <= 0:
		return 0.0
	return _when[(_start + clampi(i, 0, _count - 1)) % CAPACITY] - _origin


## **One frame, interpolated**, into a [constant STRIDE]-float array the caller
## owns.
##
## Everything lerps except the things that would lie if they did: the
## division's `commit`, which jumps when a daughter is chosen; the hunter and
## the killer, which are slots and not quantities; a beam's hit flag, which is a
## boolean; any position that moved further than [constant JUMP] between two
## frames, which is a body or a mote being recycled to the far side of the water
## rather than swimming there; and a slot that is empty in either frame, which is
## a body arriving or going and not one growing out of nothing.
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
		if _ring[from + head + 3] <= 0.0 or _ring[to + head + 3] <= 0.0:
			var whole := from if t < 1.0 else to
			for k in BODY_FLOATS:
				out[head + k] = _ring[whole + head + k]
			continue
		out[head + 2] = lerp_angle(_ring[from + head + 2],
			_ring[to + head + 2], t)
		_hold_jump(out, from, to, head, t)
	for index in MOTES:
		_hold_jump(out, from, to, AT_MOTES + index * 2, t)
	for slot in BEAMS:
		var head := AT_BEAMS + slot * BEAM_FLOATS
		out[head + 2] = _ring[from + head + 2]
	out[AT_COMMIT] = _ring[from + AT_COMMIT]
	out[AT_HUNTER] = _ring[from + AT_HUNTER]
	out[AT_KILLER] = _ring[from + AT_KILLER]
	# **The ping's slots are not identities**, which is the same fault the
	# hunter index has. The field re-sorts its echoes nearest-home every frame
	# and a return that lands vacates one, so slot 2 in two consecutive frames
	# is routinely two different bodies -- and lerping between them would slide
	# one arc across the water to where another one was. A bearing cannot be
	# lerped through the wrap at +-PI either. Stepped, therefore, whole.
	for k in range(AT_TAIL, AT_PING_RANGE):
		out[k] = _ring[from + k]


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
