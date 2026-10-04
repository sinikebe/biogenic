extends "res://game/genes/gene.gd"
## `ocellus`: **the beam**. A real eyespot carrying an ability no eyespot has: a
## fan of rays out of the arc it is worn on, marking whatever each strikes. The
## pattern this project names organs by -- an invented ability on a real organ.
##
## **Its strength is its level, not its copies** (docs/design/beam-levels.md
## §4.1). The first design asked for one beam per copy; a genome is a `{gene:
## tier}` map and cannot hold the same gene twice, so for a while the tier bought
## the beams and the fan widened with it, so that three beams covered 100 degrees
## rather than sitting on top of each other. Levels replaced that: copies are how
## likely a daughter is to grow the organ, and the level -- earned by using it --
## is how strong it is. Levels 1 to 3 are exactly its tables' three rungs.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **How far the beam reaches, how many rays there are, and how wide they fan**
## either side of the arc it is worn on, by rung.
const BEAM_RANGE_BY_TIER: Array[float] = [0.0, 620.0, 900.0, 1240.0]
const BEAM_COUNT_BY_TIER: Array[int] = [0, 1, 2, 3]
const BEAM_FAN_DEG_BY_TIER: Array[float] = [0.0, 0.0, 22.0, 50.0]

## **Past level 3 the beam forks, for good** (beam-levels.md §1, §4). `extend`
## adds a ray per level and the fan fills in; `sweep` keeps three rays and
## swings each across its own third of the fan, faster every level. Until one
## is taken the levels bank and the beam stays at level 3.
const BEAM_FORK_LEVEL := 3
const BEAM_PATHS: Array[StringName] = [&"extend", &"sweep"]
## What going from level L to L + 1 costs, divided by L: level 2 at one
## `STEP`, the fork at three. Set off an instrumented run so that ordinary play
## reaches level 2 in about a minute and the fork in about three --
## beam-levels.md §9 is the run.
const BEAM_XP_STEP := 40.0
## Experience comes from every different body the beam touched in a second,
## and no more than this many a second (§2).
const BEAM_XP_CAP := 3
## **x and y, the owner's two prices** (§5): upkeep for every ray after the
## first, and for every degree a second of sweep. X is the old per-tier price,
## so levels 1 to 3 cost exactly what tiers 1 to 3 did; Y makes a level of
## sweep cost half a level of extension. Balance numbers, judged by playing.
const BEAM_RAY_COST := 0.18
const BEAM_SWEEP_COST := 0.0027
## How much faster each sweeping ray crosses its sector per level past the
## fork, in degrees a second: one sector a second at level 4.
const BEAM_SWEEP_STEP_DEG := 100.0 / 3.0
## A ceiling on the rays one fan casts, which no player reaches -- level 64 is
## tens of hours of use -- and which keeps the run's `_step_beams` bounded if one
## does.
const BEAM_RAYS_MAX := 64


func _init() -> void:
	organ = &"ocellus"
	order = 4
	provides = {&"beam_range": BEAM_RANGE_BY_TIER, &"beam_count": BEAM_COUNT_BY_TIER,
		&"beam_fan_deg": BEAM_FAN_DEG_BY_TIER}
	levels = {"step": BEAM_XP_STEP, "fork": BEAM_FORK_LEVEL, "paths": BEAM_PATHS}
	numbers = {&"xp_cap": BEAM_XP_CAP, &"ray_cost": BEAM_RAY_COST,
		&"sweep_cost": BEAM_SWEEP_COST, &"sweep_step_deg": BEAM_SWEEP_STEP_DEG,
		&"rays_max": BEAM_RAYS_MAX}
	# **The beam and the voluntary push are the rarest things in the water**: the
	# two that change the most about a run.
	water = {"weight": 2, "drifter": true}
	tags = [SENSE, GIFT]
	channel = BEAM
	declares = {"in": [{"name": &"beam", "bearing": true,
		"values": {&"distance": &"distance"}}]}


## **The beam at [param level] down [param path]**: `[rays, half-span in degrees,
## sweep in degrees a second, reach]`. Before the fork, and down a path this
## build does not know, it is the three-rung ladder, held at the top rung.
## beam-levels.md §4. `cell.gd`'s `beam_shape` asks the organ that casts the beam.
func shape_at(level: int, path: StringName) -> Array:
	if level <= 0:
		return [0, 0.0, 0.0, 0.0]
	var count: Array = provides[&"beam_count"]
	var fan: Array = provides[&"beam_fan_deg"]
	var top := mini(int(levels["fork"]), count.size() - 1)
	var rung := mini(level, top)
	var reach: float = (provides[&"beam_range"] as Array)[rung]
	var past := level - top
	if past <= 0 or not (levels["paths"] as Array).has(path):
		return [count[rung], fan[rung], 0.0, reach]
	var half: float = fan[top]
	if path == &"sweep":
		return [count[top], half, float(numbers[&"sweep_step_deg"]) * float(past), reach]
	return [mini(level, int(numbers[&"rays_max"])), half, 0.0, reach]


## **What the beam at [param level] down [param path] adds to the metabolic
## multiplier**: x for every ray after the first, y for every degree a second
## of sweep. beam-levels.md §5.
func upkeep_at(level: int, path: StringName) -> float:
	var shape := shape_at(level, path)
	return float(numbers[&"ray_cost"]) * float(maxi(int(shape[0]) - 1, 0)) \
		+ float(numbers[&"sweep_cost"]) * float(shape[2])
