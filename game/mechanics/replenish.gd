extends RefCounted
## **Keeping a population at its size**: how many to make now, which of some
## candidate places is emptiest, and whether a place is out of sight. The
## drop's spawner is the first user (docs/design/ocean.md §6).
##
## **Nothing here knows what is being made, or for whom.** A population is a
## count against a target; a place is a point, and how full it is is whatever a
## counting callback says; an observer is a point with a reach. The drop decides
## what a new body is and whose turn it is (game/normal/drop.gd).
##
## **The debt.** A shortfall is paid back over [member tau] seconds: each call
## adds `shortfall * dt / tau` to a debt, and every whole unit of it is one to
## make, at most [member burst] a call. So a population losing `k` a second
## settles `k * tau` short of its target -- the drop's 95 % and 91 % (§6.2) --
## and one that stops losing refills along `1 - exp(-t / tau)`.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## How many the population should hold.
var target := 0
## Seconds over which a shortfall is paid back.
var tau := 5.0
## The most [method due] hands out in one call.
var burst := 8
## What is owed and not yet made, in units. Never more than the shortfall it
## came from.
var debt := 0.0


func _init(size := 0, seconds := 5.0, most := 8) -> void:
	target = maxi(size, 0)
	tau = maxf(seconds, 0.0)
	burst = maxi(most, 0)


## **How many to make now**, for a population of [param living] after
## [param dt] seconds. Nothing is owed at or over the target, and what is owed
## never exceeds the shortfall, so a debt that could not be paid -- nowhere to
## put anything -- does not pile up.
func due(living: int, dt: float) -> int:
	var short := target - living
	if short <= 0:
		debt = 0.0
		return 0
	if tau <= 0.0:
		debt = float(short)
	else:
		debt = minf(debt + float(short) * maxf(dt, 0.0) / tau, float(short))
	var n := mini(floori(debt), burst)
	debt -= float(n)
	return n


## **Gives back [param n] that [method due] handed out and could not be
## made**, to be tried again next time.
func refund(n: int) -> void:
	debt += float(maxi(n, 0))


## Nothing owed.
func reset() -> void:
	debt = 0.0


## **The thinnest of [param candidates]**: the index of the one
## [param count] -- a callable taking a point and returning how full it is --
## says holds the fewest, the first of them on a tie; -1 for none.
static func thinnest(candidates: PackedVector2Array, count: Callable) -> int:
	var best := -1
	var fewest := 0
	for i in candidates.size():
		var n := int(count.call(candidates[i]))
		if best < 0 or n < fewest:
			best = i
			fewest = n
	return best


## **Whether [param point] is out of reach of every observer**: at least
## `reaches[k]` from `observers[k]`, for every `k`. With no observers every
## point is hidden. A missing reach is taken as 0.
static func hidden(point: Vector2, observers: PackedVector2Array,
		reaches: PackedFloat32Array) -> bool:
	for k in observers.size():
		var reach := float(reaches[k]) if k < reaches.size() else 0.0
		var dx := point.x - observers[k].x
		var dy := point.y - observers[k].y
		if dx * dx + dy * dy < reach * reach:
			return false
	return true
