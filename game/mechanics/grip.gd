extends RefCounted
## **A hold on what a body touches**: the drop's rim today, a cell next
## (docs/design: the haptonema's `cling`). Nothing here knows about genes,
## water or cells: a rim (a `basin.gd`), points, radii and the two stats a
## hold is made of -- `grip`, the share of a held body's push-off it takes,
## and `tether`, how far past touching it still holds.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.


## **Whether a body of radius [param r] at [param p] holds the rim**: it lies
## within [param reach] of it -- touching, or as far past touching as its
## tether goes. No reach, no hold.
static func at_rim(rim: RefCounted, p: Vector2, r: float, reach: float) -> bool:
	if reach <= 0.0:
		return false
	return not rim.call(&"inside", p, r + reach)


## **The pace a body moves at this step**: none while it holds the rim, else
## [param pace] as it was.
static func held_pace(pace: float, holding: bool) -> float:
	return 0.0 if holding else pace
