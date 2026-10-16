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


## **How far a hold draws two bodies together this step**: a gap of
## [param gap] past touching, held by a tether of [param tether] at a grip of
## [param grip] -- none past the tether, where the hold breaks, nor when they
## already touch. The held body pushing away is what the grip does not take.
static func tether_pull(gap: float, tether: float, grip: float) -> float:
	if gap <= 0.0 or gap > tether:
		return 0.0
	return gap * clampf(grip, 0.0, 1.0)


## **The stronger of two bodies' holds on each other**: each holds only while
## it clings, by its own tether and grip.
static func pair_pull(gap: float, a_clings: bool, a_tether: float, a_grip: float,
		b_clings: bool, b_tether: float, b_grip: float) -> float:
	return maxf(tether_pull(gap, a_tether if a_clings else 0.0, a_grip),
		tether_pull(gap, b_tether if b_clings else 0.0, b_grip))
