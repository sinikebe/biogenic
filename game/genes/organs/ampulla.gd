extends "res://game/genes/gene.gd"
## `ampulla`: **the ping**, after the ampullae of Lorenzini -- electroreception,
## a shark's sixth sense, nature's radar. A pulse every so often, and the bearing
## of **every** body it comes back off, edible or not. That is the difference
## from `chemocyte`: the scent field can only ever describe a meal, and most of
## what matters in this water is not a meal.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **How far it calls, and how often**, by tier. **Range climbs. Rate does not,
## and that is the whole of the owner's answer to ping-as-outline.md §10 row 1.**
## Each period is exactly the round trip at that tier -- `2 x PING_RANGE_BY_TIER[t]
## / food.gd's PING_SPEED`, which is 2x1100/250, 2x1500/250 and 2x1900/250 -- so
## the organ does not call again until its own echo is home.
##
## A bat does not shout over its own returns. The ones that do are the
## high-duty-cycle horseshoe bats, and they get away with it only because they
## have Doppler-shift compensation to separate the call from the echo; this
## cell has no such machinery, so an overlapping pulse is not a harder problem
## for it, it is an unanswerable one. With period equal to the round trip there
## is **exactly one pulse in the water at every tier** -- counted, not argued:
## `--pings=` puts the peak outgoing front count at **1 at all three tiers**,
## against 2 / 3 / 6 under the period this replaces. Nothing a mark could have
## come from but the one call, so *when it came back* means *how far away it
## is* again, which is the reading ping-as-outline.md §3.1 is built on.
##
## **Two costs, both measured on the built code**, 60 s at seed 7, `--radius=30`
## with the organ in slot 0:
##
## - **Refresh stops climbing with tier.** 21 / 20 / 19 marks a minute at tiers
##   1 / 2 / 3, against 55 / 104 / 168 under the old 3.2 / 2.2 / 1.4. Upgrading
##   the organ now buys reach and resolution -- how far it sees and how many
##   bodies one sweep answers for -- and not frequency.
## - **The water is no longer always ringing.** A front or an echo is somewhere
##   in the water 70% / 54% / 64% of the time, against 100% at every tier
##   before. The gap is not the period -- the last possible echo lands exactly
##   as the next call goes out -- it is that the front is culled at its own
##   reach, half a round trip in, and the bodies it actually found are far
##   nearer than that, so their echoes are all home early. The skin is quiet
##   85% / 86% / 88% of the minute, against 63% / 40% / 36%.
##
## One thing improved rather than cost: `ping_listen` is `1 - age / trip`, so
## the hum now breathes from full to empty exactly once per call at **every**
## tier. Under the old ladder a tier-3 period was a tenth of its trip and the
## hum sat nearly flat. ping-as-outline.md §10 row 1 is the table.
## The host's referee judges by these: change them with Wire.PROTOCOL and Wire.RULES (wire.gd).
const PING_RANGE_BY_TIER: Array[float] = [0.0, 1100.0, 1500.0, 1900.0]
const PING_PERIOD_BY_TIER: Array[float] = [0.0, 8.8, 12.0, 15.2]

## **How much of the pulse survives one body in the way, including your own.**
## The pulse leaves the membrane at the organ's own arc and stops on everything
## it meets, so the body it left is the first thing in the way: a tier-1
## `ampulla` is stone blind astern of the slot it is worn in, which is the whole
## of the owner's *"not at the first level of the gene"*.
##
## Applied **once per occluder, multiplying**, so a return two bodies deep at
## tier 3 comes back at 0.58 x 0.58 = 0.34 and three deep at 0.20. A dimmer
## echo rather than a range or a depth count: the membrane has intensity and
## intensity is what a fainter echo is, a count is a step the player cannot
## count, and this one needs no rule for *how deep* -- four bodies deep at tier
## 3 is 0.11 of an echo the range has already faded, which is a mark nobody
## reads, and at tier 1 the first body ends it.
##
## The ambiguity it makes -- a shadowed near body and a clear far body both read
## faint -- is already answered in a channel that exists: returns are staggered
## by their own flight time, so the shadowed near body still answers *early*.
const PING_THROUGH_BY_TIER: Array[float] = [0.0, 0.0, 0.34, 0.58]


func _init() -> void:
	organ = &"ampulla"
	order = 6
	provides = {&"ping_range": PING_RANGE_BY_TIER, &"ping_period": PING_PERIOD_BY_TIER,
		&"ping_through": PING_THROUGH_BY_TIER}
	water = {"weight": 3, "drifter": true}
	tags = [SENSE, GIFT]
	channel = PING
	declares = {"in": [{"name": &"echo", "bearing": true,
		"values": {&"distance": &"distance", &"size": &"size"}}]}
