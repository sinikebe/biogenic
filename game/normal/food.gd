extends Node
## The nutrient field: four small cells, drifting, and the chemistry they leak.
##
## The cell reads exactly two things out of this field and nothing else: its
## **total** concentration, which sets the beat rate, and its **gradient
## bearing**, which sets the green band wash. Concentrations sum and bearings
## average, so two sources either side give a bearing that points between them
## at a strength neither one has. Swimming into the middle and finding nothing
## is a correct outcome of a crude sense and is not designed out.
##
## That is why foraging is run-and-tumble, which is what a cell actually does:
## the player's only verb is turning and the cell fires its own impulses, so the
## loop is turn, wait for an impulse, did the beat quicken, keep or change. It
## teaches itself because it is the only thing that can be done.
##
## This node computes; it does not post. [member concentration] and
## [member taste_bearing] are read once a frame by whoever owns the run, which
## is the only place allowed to talk to the signal bus. A per-frame signal here
## would allocate a dictionary sixty times a second to say the same thing.
##
## docs/design/food-and-predators.md §2 and §3.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")

## A meal, in the cell's own terms.
##
## [param nutrition] is a portion of one meal, so a later flavour can be worth
## more or less without touching the balance number in metabolism.gd.
## [param gene] is the **Phase 5 seam** and is always &"" here; Phase 5 rolls it
## on eating, subscribes to this same signal and needs no refactor.
## [param at] is the food's world position and is emphatically NOT part of the
## sensation -- the cell cannot know where anything is, and nothing that reaches
## the signal bus may carry a position. It is here for the full-vision view,
## which is entitled to ground truth precisely because it is not the organism.
## The same contract as motes.struck: whoever forwards this to the bus drops it.
signal eaten(nutrition: float, gene: StringName, at: Vector2)

const COUNT := 4
const RADIUS_MIN := 14.0
const RADIUS_MAX := 20.0
## Smaller than you, passive, does not flee. Slow enough that it is never a
## chase and never a fixed target either.
const DRIFT_SPEED := 9.0
const DRIFT_TURN := 1.1

## Inverse-power falloff, the shape a diffusing metabolite actually has.
const CORE_RANGE := 130.0      ## c = 1 at or inside this
const SCENT_RANGE := 1600.0    ## c = 0 at or outside this
const SCENT_FALLOFF := 1.7
const SCENT_WINDOW := 250.0    ## smooth the outer cutoff so it cannot pop
## Where [method scent] crosses the bus's TASTE_FLOOR and a direction first
## exists at all -- about twelve seconds of swimming. Everything outside it is
## hot-and-cold with no bearing in it. Named here because it is a property of
## the field, and the full-vision view draws it as a threshold ring.
const BEARING_RANGE := 680.0

## Ring placement, exactly like motes.gd: recycled to the far edge when culled.
const RING_MIN := 800.0
const RING_MAX := 2200.0
const CULL := 3000.0
## Authored, like mote 0: placed along the cell's real velocity once it moves,
## just outside scent range, so the beat quickens at about 0:12.
const FIRST_DISTANCE := 2200.0

## What one whole food cell is worth, as a portion of metabolism.MEAL. Phase 4
## has one flavour and it is a whole meal; Phase 5's flavours are what make this
## anything else.
const NUTRITION := 1.0

## Total concentration at the cell, 0..1. The other half of metabolism's beat
## mapping, and the reason the outer kilometre is hot-and-cold with no direction
## in it.
var concentration := 0.0
## Body-relative bearing of the summed gradient, radians clockwise from the
## cell's front. Meaningless when [member concentration] is 0.
var taste_bearing := 0.0

var _cell: CellBody = null
var _pos := PackedVector2Array()
var _radius := PackedFloat32Array()
var _drift := PackedFloat32Array()
var _first_pending := false


## Seeds the field around [param cell]. Food 0 is held back until the cell is
## actually moving, for the same reason mote 0 is.
func setup(cell: CellBody) -> void:
	_cell = cell
	_pos.resize(COUNT)
	_radius.resize(COUNT)
	_drift.resize(COUNT)
	for i in COUNT:
		_seed(i)
	_first_pending = true
	concentration = 0.0
	taste_bearing = 0.0


func _process(delta: float) -> void:
	if _cell == null:
		return

	# The drift path does not exist until the cell drifts. Placing the first
	# food along the real velocity vector is what makes the beat quicken at
	# about 0:12 instead of whenever the wander happens to point at something.
	if _first_pending and _cell.velocity.length_squared() > 1.0:
		_first_pending = false
		_pos[0] = _cell.position + _cell.velocity.normalized() * FIRST_DISTANCE

	var total := 0.0
	var pull := Vector2.ZERO
	for i in _pos.size():
		_drift[i] = wrapf(_drift[i] + randf_range(-DRIFT_TURN, DRIFT_TURN) * delta, -PI, PI)
		_pos[i] += Vector2(cos(_drift[i]), sin(_drift[i])) * DRIFT_SPEED * delta

		var offset := _pos[i] - _cell.position
		var d := offset.length()
		if d > CULL:
			_seed(i)
			continue
		if d < _cell.radius + _radius[i]:
			# Emit where it was before recycling it, so a listener never has to
			# work out which one this was -- the mistake motes.gd documents.
			eaten.emit(NUTRITION, &"", _pos[i])
			_seed(i)
			continue

		var c := scent(d)
		if c <= 0.0:
			continue
		total += c
		pull += offset / maxf(d, 0.001) * c

	concentration = minf(total, 1.0)
	if concentration > 0.0 and pull.length_squared() > 0.0:
		taste_bearing = _cell.bearing_to(_cell.position + pull)
	else:
		taste_bearing = 0.0


## Concentration contributed by one source at distance [param d].
func scent(d: float) -> float:
	if d >= SCENT_RANGE:
		return 0.0
	var v := pow(CORE_RANGE / maxf(d, CORE_RANGE), SCENT_FALLOFF)
	return minf(1.0, v * smoothstep(SCENT_RANGE, SCENT_RANGE - SCENT_WINDOW, d))


## Where the food currently is, for an observer entitled to ground truth --
## which is the full-vision view and nothing the organism can sense. Returns the
## live array, so read it and do not hold it across frames.
func points() -> PackedVector2Array:
	return _pos


## Body radii, index-matched to [method points].
func radii() -> PackedFloat32Array:
	return _radius


func _seed(index: int) -> void:
	var angle := randf_range(-PI, PI)
	var distance := randf_range(RING_MIN, RING_MAX)
	var origin := _cell.position if _cell != null else Vector2.ZERO
	_pos[index] = origin + Vector2(cos(angle), sin(angle)) * distance
	_radius[index] = randf_range(RADIUS_MIN, RADIUS_MAX)
	_drift[index] = randf_range(-PI, PI)
