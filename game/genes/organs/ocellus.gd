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

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit
## How long a sweep takes to light every bearing (game/mechanics/ray_fan.gd,
## which preloads nothing).
const RayFan := preload("res://game/mechanics/ray_fan.gd")

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


# --- Its words (gene.gd; gene-catalogue.md §8.1) -------------------------------------

## **Its chip word** (gene.gd's word tables): the plain word, never the biological
## name -- one short word for what it does, read at arm's length (figure.gd).
##
## TRANSLATORS: A gene's name as the player reads it on a chip beside three small
## dots: one short lowercase word, a verb or a noun for what the gene does. The
## `entry` line says which gene it names (its scientific name, never translated).
## It has to be short: prefer the shortest everyday word. The same words appear
## inside sentences such as "let go to swap eat and ping".
## ROOM: 47 px at 13 px
const WORDS := {&"ocellus": "beam"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"ocellus": "a ray out of that side, marking whatever it strikes"}
## **Once a way is taken, its line says which** (beam-levels.md §8.3).
##
## TRANSLATORS: As the gene lines above, for a gene that can grow in two ways and
## has been given one: what it does now. The `entry` line gives the gene and the
## way. Same limit: no longer than the English, which is 464 px at most with the
## gene's name in front.
## ROOM: 470 px at 15 px
const EXPLAINS_PATH := {
	&"ocellus": {
		&"extend": "a fan of rays out of that side, one more every level",
		&"sweep": "three rays sweeping that side, faster every level",
	},
}
## **The ways its levels fork into** (beam-levels.md §1): each way's name, its two
## card lines and what it does as it grows, by way, for normal_mode.gd's cards and
## lines (the catalogue's way words).
##
## **Owner's call 1** (beam-levels.md §8.9), answered on 2026-09-29 with the
## recommended option: what the two ways are called. The
## cards' titles, and the name every line about a way uses, so a different
## answer is this line. `fill`, recommended, says what happens: each level adds
## a ray between the ones there are, so the fan fills in and never widens.
## `extension`, the owner's own word, can read as a longer beam, and neither way
## is longer.
##
## TRANSLATORS: The name of one of the two ways a levelled gene can grow, as the
## title of its card (20 px type on a card 200 px wide) and inside sentences such
## as "tap again to choose sweep · for good". The beam gene: `fill` = each level
## adds one more ray between the ones there are, so the fan fills in and never
## widens; `sweep` = the three rays swing from side to side, faster each level.
## One lowercase word, about 12 characters at most.
## ROOM: 180 px at 20 px
const PATH_TITLES := {&"extend": "fill", &"sweep": "sweep"}
## What each way is good and bad at: one clause each, no numbers, in the gene
## lines' voice.
##
## TRANSLATORS: Two short lines on a card, in 14 px type, centred: the first what
## that way is good at, the second what it is bad at. **At most 185 px each** --
## the card is 200 px wide and nothing wraps -- and the longest English line is
## 172 px (about 25 characters). The `entry` line gives the way. "Rays" are the
## beams of light the gene fires.
## ROOM: 185 px at 14 px
const PATH_LINES := {
	&"extend": ["every ray lit, all the time", "small things slip between"],
	&"sweep": ["no gaps between rays", "shows where things were"],
}
## What a way does as it grows, after its name on the explanation line.
##
## TRANSLATORS: One line in 15 px type after the way's name and a middle dot,
## saying what that way does as the gene levels up. Same limit as the gene lines
## elsewhere: no longer than the English (288 px, 41 characters). The `entry`
## line gives the way.
## ROOM: 470 px at 15 px
const PATH_SAYS := {
	&"extend": "a new ray every level, filling the fan",
	&"sweep": "your three rays swing, faster every level",
}
## **What its sense is called** on an instinct's chip: what the organ reports, as
## the player knows it -- a word of its own, apart from its chip word.
##
## TRANSLATORS: The name of a sense on a small chip of the player's "instincts"
## (rules: "when <a sense reports something> -> <do this>"): what one organ of the
## cell reports. "beam": what the light the cell's ocellus casts lands on; "echo":
## what comes back of the cell's ping; "smell": the smell of food; "shadow": the
## shade of something big; "touch": something against the cell's skin, felt by
## its palps. Lowercase, one short word.
## ROOM: 112 px at 15 px
## CONTEXT: sense
const GENE_SENSES := {&"ocellus.beam": "beam"}
## **The line that explains it** on the instincts page.
##
## TRANSLATORS: Explains one sense, action or value of the player's "instincts",
## on one line under them: its name (the same words as on its chip), a middle
## dot, then what it is or does, lowercase. "Your ping" is the cell's ampulla,
## which calls and listens; "your beam" its ocellus; "your nose" its chemocyte;
## "your eyespot" its stigma; "your palps" its palp. "Your tail" is the cell's
## flagellum, which swims; "two copies" means the gene is carried twice in the
## cell's DNA, which is what lets the tail be held still. "For free" means it
## costs no food.
## ROOM: 856 px at 15 px
const GENE_EXPLAINS := {
	&"ocellus.beam": "beam · the nearest thing each ray of your beam stops on: where, and how far.",
}


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
	# **Its look** (gene-looks.md §6): a lens standing on the skin over its pigment --
	# the ocellus is a real camera eye, and a lens is what no bristle organ has.
	# Sensing's shade 0, which the beam's lobe and rays are drawn in. Its pigment buds
	# at a fork and flares as a level arrives (cilia.gd's `_draw_bud`).
	family = SENSING
	look = {"shape": LENS, "shade": 0}


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


## **Its numbers on the pause screen** (gene.gd's `lines`): **the beam, by its level
## and its way** (gene-stats.md §5.2) -- the fan it casts ([method shape_at]) and the
## price it charges for it ([method upkeep_at]).
##
## TRANSLATORS: The light-ray gene (`ocellus`, shown as `beam`): it fires "rays",
## thin beams of light that mark whatever they strike. The number of rays is the
## count (2 to 64): give the forms your language needs for it. The singular of
## the two-part phrases is never shown in English, since a fan has at least two
## rays, but give it anyway. "{} rays across {}" is the angle the fan of rays
## covers, in degrees. "Every bearing lit within {} s" means the sweep has
## covered every direction of the fan within that many seconds.
func lines(_t: int, level: int, path: StringName, ctx: Dictionary, _slot: int,
		_wear: Dictionary) -> Array:
	var burn := float(ctx.get("burn", 1.0))
	var at := maxi(level, 1)
	var shape := shape_at(at, path)
	var rays := int(shape[0])
	var half := float(shape[1])
	var sweep := float(shape[2])
	var fan := 2.0 * half
	var reach := Readout.item("reaches {} µm", [shape[3]], [U.DISTANCE])
	var costs := [(ctx["wear_item"] as Callable).call(upkeep_at(at, path), burn)]
	if rays <= 1:
		return [[Readout.item("{} ray", [rays], [U.COUNT]), reach], costs]
	if sweep > 0.0:
		var lit := RayFan.revisit_of(rays, deg_to_rad(half), deg_to_rad(sweep))
		return [[Readout.item_n("{} ray sweeping {}", "{} rays sweeping {}", rays,
				[rays, fan], [U.COUNT, U.ANGLE]),
			Readout.item("every bearing lit within {} s", [lit], [U.TIME]), reach], costs]
	# Past the fork, extending: more rays than the top rung has, so the spacing
	# between them is what a level buys, and it is said.
	var count: Array = provides.get(&"beam_count", [])
	var top := mini(int(levels.get("fork", 0)), count.size() - 1)
	if top >= 0 and rays > int(count[top]):
		return [[Readout.item_n("{} ray across {}, one every {}",
			"{} rays across {}, one every {}", rays,
			[rays, fan, fan / float(rays - 1)], [U.COUNT, U.ANGLE, U.ANGLE]), reach], costs]
	return [[Readout.item_n("{} ray across {}", "{} rays across {}", rays,
			[rays, fan], [U.COUNT, U.ANGLE]), reach],
		costs]
