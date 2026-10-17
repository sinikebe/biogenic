extends RefCounted
## **A light that comes and goes on a cycle, and how much of it gets through**
## (docs/design/daylight.md §2). The cycle is four spans: a rise, a time at full,
## a fall and a time at its floor, over and over. The drop is the first user, and
## its day is ten minutes.
##
## **Nothing here knows what is lit or what lights it.** It knows four spans, a
## floor, seconds, and a share of the deepest place there is. What the light is for,
## and what follows it, is the caller's: an environment file builds the cycle from
## its own numbers, and whoever keeps the clock asks it.
##
## - [method surface]: the light at the top, `t` seconds into the cycle;
## - [method mean]: its exact mean over any stretch, whole cycles included, so a
##   step of any length is paid one light whatever its length;
## - [method through]: what gets through a share of the deepest, Beer-Lambert's
##   `e^(-k z)` stated by what reaches the deepest point.
##
## **The rise and the fall are a smoothstep**, `u²(3 - 2u)`, so the light never
## jumps and never stalls at a join; its integral over a span is `u³ - u⁴ / 2`,
## which is what [method mean] adds up.
##
## **Worked in doubles, and in the cycle's own seconds.** A time far into a long
## clock is folded into one cycle first, so the integral is taken over numbers
## under one cycle and a mean over one frame at a million seconds is as exact as
## one at the start.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## Seconds the light takes to come up from its floor to full.
var rise := 60.0
## Seconds at full.
var high := 300.0
## Seconds it takes to go back down.
var fall := 60.0
## Seconds at the floor.
var low := 180.0
## **The light at its lowest**, 0 to 1: what is left between a fall and the next
## rise.
var least := 0.0


func _init(rising := 60.0, full := 300.0, falling := 60.0, dark := 180.0,
		at_floor := 0.0) -> void:
	rise = maxf(rising, 0.0)
	high = maxf(full, 0.0)
	fall = maxf(falling, 0.0)
	low = maxf(dark, 0.0)
	least = clampf(at_floor, 0.0, 1.0)


## **How long one cycle is**, in seconds.
func period() -> float:
	return rise + high + fall + low


## **The light at the top, [param t] seconds into the cycle**, 0 to 1: rising
## from [member least] over [member rise], full over [member high], falling over
## [member fall], and at [member least] until the next rise. Any [param t], past a
## cycle or before one, is read where it falls in the cycle. A cycle of no length
## is always full.
func surface(t: float) -> float:
	var p := period()
	if p <= 0.0:
		return 1.0
	return least + (1.0 - least) * _shape(fposmod(t, p))


## **The light's exact mean over [param t0] to [param t1]** -- the integral of
## [method surface] over the stretch, over its length. A stretch of no length is
## the light at that moment, and one backwards is read forwards.
func mean(t0: float, t1: float) -> float:
	if t1 < t0:
		var swap := t0
		t0 = t1
		t1 = swap
	var p := period()
	if p <= 0.0:
		return 1.0
	if t1 - t0 <= 0.0:
		return surface(t0)
	# Each end as whole cycles and a remainder, so the integral is taken in the
	# cycle's own seconds. fposmod is exact, so each remainder is exactly where its
	# end falls in its cycle, and the cycles are counted from it: `t - u` is a
	# whole number of them to well under half of one, which rounding reads exactly
	# where `floor(t / p)` can land one off.
	var u0 := fposmod(t0, p)
	var u1 := fposmod(t1, p)
	var n0 := roundf((t0 - u0) / p)
	var n1 := roundf((t1 - u1) / p)
	var shape := 0.0
	if n1 == n0 and u1 >= u0:
		shape = _shape_integral(u1) - _shape_integral(u0)
	else:
		var whole := _shape_integral(p)
		shape = (whole - _shape_integral(u0)) + maxf(n1 - n0 - 1.0, 0.0) * whole \
			+ _shape_integral(u1)
	return least + (1.0 - least) * shape / (t1 - t0)


## **The cycle's mean over a whole cycle**: the share of full light it is worth.
func whole_mean() -> float:
	var p := period()
	if p <= 0.0:
		return 1.0
	return least + (1.0 - least) * _shape_integral(p) / p


## **What gets through [param column]** -- the share of the deepest that lies over
## a place, 0 to 1 -- when [param at_deepest] reaches the deepest point: `1` with
## nothing over it, [param at_deepest] under all of it. **Exactly 1 for no column
## and exactly [param at_deepest] for a whole one**, so the shallowest place and
## the deepest are the numbers they are said to be.
static func through(column: float, at_deepest: float) -> float:
	if column <= 0.0 or at_deepest >= 1.0:
		return 1.0
	if at_deepest <= 0.0:
		return 0.0
	return pow(at_deepest, minf(column, 1.0))


## The cycle's shape at [param u] seconds into it, 0 to 1, before the floor.
func _shape(u: float) -> float:
	if u < rise:
		return _smooth(u / rise)
	u -= rise
	if u < high:
		return 1.0
	u -= high
	if u < fall:
		return 1.0 - _smooth(u / fall)
	return 0.0


## The integral of [method _shape] from the cycle's start to [param u] seconds
## into it, in seconds of full light.
func _shape_integral(u: float) -> float:
	if u <= 0.0:
		return 0.0
	if u < rise:
		var x := u / rise
		return rise * _smooth_integral(x)
	var sum := rise * 0.5
	u -= rise
	if u < high:
		return sum + u
	sum += high
	u -= high
	if u < fall:
		var x := u / fall
		return sum + fall * (x - _smooth_integral(x))
	return sum + fall * 0.5


## `u²(3 - 2u)`.
static func _smooth(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## Its integral from 0 to [param u]: `u³ - u⁴ / 2`.
static func _smooth_integral(u: float) -> float:
	var u3 := u * u * u
	return u3 - 0.5 * u3 * u
