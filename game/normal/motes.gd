extends Node
## Inert specks of matter, hanging still in the water.
##
## Not food and not alive: a mote has no chemistry, cannot be eaten and does
## nothing but be in the way. It exists because docs/design/perception.md §2
## puts one on the cell's opening drift path at about 0:10 -- the bump is how
## the player learns that things exist out there, and that hitting one has a
## direction. Without it "hit" is a signal the game can never send.
##
## In practice the opening bump lands nearer 0:05-0:07 than 0:10: the placement
## below waits for the drift to exist, and by then the cell is already moving.
##
## The motes are invisible. Of course they are.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")

## Contact, in the cell's own terms: a bearing clockwise from its front.
##
## [param at] is the struck mote's world position, and it is emphatically NOT
## part of the sensation -- the cell cannot know where anything is, and nothing
## that reaches the signal bus may carry a position. It is here for an observer
## of the world (the full-vision view), which is entitled to ground truth
## precisely because it is not the organism. Whoever forwards this to the bus
## must drop it.
signal struck(bearing: float, strength: float, at: Vector2)

const COUNT := 14
const MOTE_RADIUS := 26.0
## Motes live in a ring around the cell; one that falls out the back of it is
## recycled to the far edge, so the water is neither empty nor a wall of debris.
const RING_MIN := 520.0
const RING_MAX := 1200.0
const CULL := 1900.0
## The authored first bump: far enough that it lands after an impulse or two,
## close enough that the cell's wander has not yet carried it off the line.
const FIRST_DISTANCE := 340.0

var _cell: CellBody = null
var _motes := PackedVector2Array()
var _first_pending := false


## Seeds the field around [param cell]. Mote 0 is held back until the cell is
## actually moving.
func setup(cell: CellBody) -> void:
	_cell = cell
	_motes.resize(COUNT)
	for i in COUNT:
		_motes[i] = _spawn_point()
	_first_pending = true


func _process(_delta: float) -> void:
	if _cell == null:
		return
	# The drift path does not exist until the cell drifts: the heading wanders,
	# so a mote aimed at the heading before the first impulse misses more often
	# than it hits. Placing it once the cell is actually moving is what makes
	# the opening bump in docs/design/perception.md §2 land.
	if _first_pending and _cell.velocity.length_squared() > 1.0:
		_first_pending = false
		_motes[0] = _cell.position + _cell.velocity.normalized() * FIRST_DISTANCE

	for i in _motes.size():
		var offset := _motes[i] - _cell.position
		var distance := offset.length()
		if distance > CULL:
			_motes[i] = _spawn_point()
			continue
		if distance >= _cell.radius + MOTE_RADIUS:
			continue

		var bearing := _cell.bearing_to(_motes[i])
		# A gentle drift into something is a nudge; a fresh impulse into it is a
		# knock. Square-rooted because the cell spends most of its time coasting
		# slowly and a linear reading makes almost every bump the same minimum
		# tap. Never less than a third, or the bruise has no bearing to read.
		var strength := clampf(
			sqrt(_cell.velocity.length() / _cell.impulse_speed()), 0.35, 1.0)
		var normal := -offset.normalized() if distance > 0.001 else -_cell.forward()
		_cell.bump(normal)
		# Emit the position rather than leaving a listener to work out which mote
		# this was before the next line recycles it. That inference used to live
		# in the vision layer and was wrong twice over: it depended on these two
		# statements staying in this order, and it re-identified the mote by
		# proximity, which picks the wrong one when two are in reach.
		struck.emit(bearing, strength, _motes[i])
		_motes[i] = _spawn_point()


## Where the motes currently are, for an observer entitled to ground truth --
## which is the full-vision view and nothing the organism can sense. Returns the
## live array, so read it and do not hold it across frames.
##
## This exists so no caller has to reach for the private `_motes`. Reading a
## private member across files is how the vision layer ended up silently
## coupled to the internals of this one.
func points() -> PackedVector2Array:
	return _motes


## **Where a mote was, written back from a recording.** Only the replay does
## this, and only once the run is over: *a run keeps nothing*, so the recorded
## state is scribbled onto the real field and `vision.gd` reads it exactly as it
## does now. `_wake_up()` seeds all fourteen again.
##
## It exists for the same reason [method points] does -- so no caller has to
## reach for the private array -- and it is the write half of that bargain.
## docs/design/replay.md §3.
func restore_point(index: int, at: Vector2) -> void:
	if index >= 0 and index < _motes.size():
		_motes[index] = at


func _spawn_point() -> Vector2:
	var angle := randf_range(-PI, PI)
	var distance := randf_range(RING_MIN, RING_MAX)
	var origin := _cell.position if _cell != null else Vector2.ZERO
	return origin + Vector2(cos(angle), sin(angle)) * distance
