extends RefCounted
## **Marks that stay a while and fade.** A place is added, it is drawn at full
## strength, and it fades to nothing over a lifetime the caller chooses. Nothing
## here knows what made the mark. The beam's sweep is the first user: a ray that
## passes a body once a pass leaves a mark where it passed, and the mark sits
## there until the ray comes back (beam-levels.md §4.3).
##
## **It is honest about staleness, and that is the point.** A mark is where the
## thing *was* when it was seen, not where it is now, so a fast body leaves its
## mark behind it -- which is exactly the price the sweep is meant to pay.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The most marks held at once. The oldest go first. A guard, never the thing
## that decides what is shown: [member spacing] keeps a sweep well under it.
var most := 160

## **The grid a lane's marks are laid on**, in whatever unit its `along` is --
## radians of bearing, for the beam. A lane leaves a mark each time it enters a
## new cell of this size, and none while it stays in one. 0 marks every add.
##
## This is what keeps the count a property of the sweep and not of the frame
## rate. One mark per frame gave a 60 fps phone twice a 30 fps one's marks, so
## the cap cut the faster phone's pass short first. Spacing each mark from the
## last one was not enough either: the remainder of every step carried over,
## and the probe measured 13 marks over one arc at 60 steps against 12 at 30.
## Cells are fixed, so the same arc crosses the same cells at any rate.
var spacing := 0.0

## **A jump bigger than this clears everything**, measured on the anchor handed
## to [method step]. A replay looping back to its start, or a newborn put
## somewhere new, is a new place, and marks from the old one are false there.
var jump := 400.0

var _points := PackedVector2Array()
var _ages := PackedFloat32Array()
var _anchor := Vector2.INF
## Lane to the cell that lane last left a mark in.
var _lanes := {}


## A new mark at [param at], at full strength. [param lane] is what made it --
## the beam's ray -- and [param along] is where that is on its way: a lane
## still in the [member spacing] cell of its last mark leaves none. A negative
## lane is always marked.
func add(at: Vector2, lane: int = -1, along: float = 0.0) -> void:
	if lane >= 0 and spacing > 0.0:
		var cell := floori(along / spacing)
		if _lanes.has(lane) and int(_lanes[lane]) == cell:
			return
		_lanes[lane] = cell
	_points.append(at)
	_ages.append(0.0)
	while _points.size() > most:
		_points.remove_at(0)
		_ages.remove_at(0)


## Ages every mark by [param delta] and drops the ones older than [param life].
## A [param life] of 0 or less holds nothing, and clears what was held.
## [param anchor] is whatever the marks are near -- a jump away from where it
## was last step clears them all.
func step(delta: float, life: float, anchor: Vector2) -> void:
	if life <= 0.0 or (_anchor != Vector2.INF and anchor.distance_to(_anchor) > jump):
		clear()
	_anchor = anchor
	if life <= 0.0:
		return
	var keep := 0
	for i in _points.size():
		var age := _ages[i] + maxf(delta, 0.0)
		if age >= life:
			continue
		_points[keep] = _points[i]
		_ages[keep] = age
		keep += 1
	_points.resize(keep)
	_ages.resize(keep)


## Forgets every mark, and where every lane was.
func clear() -> void:
	_points.clear()
	_ages.clear()
	_lanes.clear()


func count() -> int:
	return _points.size()


func point(i: int) -> Vector2:
	return _points[i]


## How much of mark [param i] is left, 1 when new and 0 at the end of
## [param life].
func strength(i: int, life: float) -> float:
	if life <= 0.0:
		return 0.0
	return clampf(1.0 - _ages[i] / life, 0.0, 1.0)
