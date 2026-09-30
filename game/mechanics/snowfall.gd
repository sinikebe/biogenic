extends RefCounted
## **Something falling everywhere at one rate, and staying where there is
## little else**: how many fall on an area in a tick, and whether each one
## that lands is kept. The drop's snow of detritus is the first user
## (docs/design/ocean.md §7.2).
##
## **Nothing here knows what falls.** It knows a rate per unit of area and time,
## and a chance of staying against a count the caller takes where a flake
## landed -- how many of something are near it -- and how many would be near it
## at the mean. Where it lands, and what it becomes, are the caller's.
##
## **The chance is `1 - count / (share * expected)`**, clamped: an empty place
## keeps every flake, and a place holding [member share] of its mean keeps none.
## That is "where there's few cells" as a chance rather than as a placement, so
## nothing is ever put where the game decided food should go.
##
## Draws come from the global random stream, which `drive.gd --seed=` seeds.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## How many fall per unit of area per second.
var rate := 0.0
## A place keeps nothing once its count reaches this share of its mean.
var share := 0.5


func _init(per_area_second := 0.0, keep_share := 0.5) -> void:
	rate = maxf(per_area_second, 0.0)
	share = maxf(keep_share, 0.0)


## **How many fall on [param area] in [param dt] seconds**: a Poisson draw
## whose mean is `rate * area * dt`, so over any stretch of time exactly the
## rate falls, however the ticks are cut.
func falls(area: float, dt: float) -> int:
	return poisson(rate * maxf(area, 0.0) * maxf(dt, 0.0))


## **The chance a flake is kept** where [param count] things are near it and
## [param expected] would be at the mean.
func keep_chance(count: float, expected: float) -> float:
	var full := share * expected
	if full <= 0.0:
		return 1.0 if count <= 0.0 else 0.0
	return clampf(1.0 - count / full, 0.0, 1.0)


## Whether one flake that landed where [param count] things are near it stays.
func keeps(count: float, expected: float) -> bool:
	return randf() < keep_chance(count, expected)


## **A Poisson draw with mean [param mean].** Knuth's product of uniforms, in
## pieces of at most 16 -- a sum of Poisson draws is a Poisson draw of the
## summed means -- so `exp(-mean)` never underflows and a large mean is not cut
## short.
static func poisson(mean: float) -> int:
	var total := 0
	var left := maxf(mean, 0.0)
	while left > 0.0:
		var part := minf(left, 16.0)
		left -= part
		var floor_p := exp(-part)
		var p := randf()
		while p > floor_p:
			total += 1
			p *= randf()
	return total
