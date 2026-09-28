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

## The most marks held at once. The oldest go first.
var most := 96

## **A jump bigger than this clears everything**, measured on the anchor handed
## to [method step]. A replay looping back to its start, or a newborn put
## somewhere new, is a new place, and marks from the old one are false there.
var jump := 400.0

var _points := PackedVector2Array()
var _ages := PackedFloat32Array()
var _anchor := Vector2.INF


## A new mark at [param at], at full strength.
func add(at: Vector2) -> void:
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


## Forgets every mark.
func clear() -> void:
	_points.clear()
	_ages.clear()


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
