extends RefCounted
## **A closed region with an edge**: how deep inside it a point is, where a
## ray leaves it, the nearest point of its rim, and where a body that has
## pushed past the rim is held. The drop is the first user
## (docs/design/ocean.md §3.1): a disc of water on a slide.
##
## **Nothing here knows about water, glass or cells.** It knows a centre, a
## radius and points. This file is a disc; another shape is another script
## with the same five calls -- [method contain], [method depth],
## [method exit_along], [method nearest_rim] and [method inside] -- and nothing
## that asks them has to change.
##
## **Worked in doubles.** A Vector2 holds 32-bit floats, which at a drop's
## size are a thousandth of a unit apart; every distance here is taken from
## the stored components in 64 bits, so the answers are as exact as the points
## they were asked about. And a point [method contain] hands back is one
## [method inside] accepts, after its own rounding to 32 bits -- drop_probe's
## basin check holds both.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The middle of the region.
var center := Vector2.ZERO
## How far the rim is from [member center].
var radius := 0.0


func _init(at := Vector2.ZERO, reach := 0.0) -> void:
	center = at
	radius = maxf(reach, 0.0)


## **Where a body of radius [param r] centred at [param p] is held**: at
## [param p] while it lies wholly inside, and otherwise put back on the circle
## `radius - r` along the line from the centre through it. Nothing is lost and
## nothing bounces. A body wider than the whole region is held at the centre.
func contain(p: Vector2, r: float = 0.0) -> Vector2:
	var limit := _limit(r)
	var dx := p.x - center.x
	var dy := p.y - center.y
	var d := sqrt(dx * dx + dy * dy)
	if d <= limit:
		return p
	if limit <= 0.0 or d <= 0.0:
		return center
	# On the circle, then pulled in a few 32-bit steps at a time until the
	# stored point is on the inside of it: storing rounds each component, and a
	# body put back on the rim must not be left a thousandth of a unit past it.
	var step := (maxf(absf(center.x), absf(center.y)) + limit) * 2.4e-7
	var along := limit
	for attempt in 8:
		var q := Vector2(center.x + dx * along / d, center.y + dy * along / d)
		if _distance(q) <= limit:
			return q
		along = maxf(along - step, 0.0)
		step *= 2.0
	return center


## **How far inside the rim [param p] is**: positive inside, 0 on the rim and
## negative past it.
func depth(p: Vector2) -> float:
	return radius - _distance(p)


## **How far a ray from [param origin] along [param dir] runs before it leaves
## the region.** From inside, the distance to the rim along it. From outside,
## the far crossing when the ray passes through the region, and 0 when it never
## reaches it. 0 for a direction of no length.
func exit_along(origin: Vector2, dir: Vector2) -> float:
	var length := sqrt(dir.x * dir.x + dir.y * dir.y)
	if length <= 0.0:
		return 0.0
	var ux := dir.x / length
	var uy := dir.y / length
	var mx := origin.x - center.x
	var my := origin.y - center.y
	# |m + t u| = radius: t² + 2bt + c = 0, and the far root is the exit.
	var b := mx * ux + my * uy
	var c := mx * mx + my * my - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return 0.0
	var root := sqrt(disc)
	# The far root, -b + root, without losing it to cancellation when the ray
	# heads out from just inside the rim: there (-b + root)(b + root) = -c.
	var t := -b + root if b <= 0.0 else -c / (b + root)
	return maxf(t, 0.0)


## **The point of the rim nearest [param p].** From the centre every point is
## nearest; the one straight up the page is taken.
func nearest_rim(p: Vector2) -> Vector2:
	var dx := p.x - center.x
	var dy := p.y - center.y
	var d := sqrt(dx * dx + dy * dy)
	if d <= 0.0:
		return Vector2(center.x, center.y - radius)
	return Vector2(center.x + dx * radius / d, center.y + dy * radius / d)


## **Whether a body of radius [param r] centred at [param p] lies wholly
## inside the rim** -- which is where [method contain] holds it. A body wider
## than the whole region is inside only at the centre.
func inside(p: Vector2, r: float = 0.0) -> bool:
	return _distance(p) <= _limit(r)


## How far from the centre a body of radius [param r] may be.
func _limit(r: float) -> float:
	return maxf(radius - maxf(r, 0.0), 0.0)


func _distance(p: Vector2) -> float:
	var dx := p.x - center.x
	var dy := p.y - center.y
	return sqrt(dx * dx + dy * dy)
