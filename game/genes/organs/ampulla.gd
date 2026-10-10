extends "res://game/genes/gene.gd"
## `ampulla`: **the ping**, after the ampullae of Lorenzini -- electroreception,
## a shark's sixth sense, nature's radar. A pulse every so often, and the bearing
## of **every** body it comes back off, edible or not. That is the difference
## from `chemocyte`: the scent field can only ever describe a meal, and most of
## what matters in this water is not a meal.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

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
## The host's referee judges by these: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
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
const WORDS := {&"ampulla": "ping"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"ampulla": "a pulse that answers off everything, not just food"}
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
const GENE_SENSES := {&"ampulla.echo": "echo"}
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
	&"ampulla.echo": "echo · what your ping hears back: where it came from, how far, and how big"
		+ " it rings.",
}


func _init() -> void:
	organ = &"ampulla"
	order = 6
	provides = {&"ping_range": PING_RANGE_BY_TIER, &"ping_period": PING_PERIOD_BY_TIER,
		&"ping_through": PING_THROUGH_BY_TIER}
	# **Uncommon, as every organ a run is built from** (gene-rarity.md §4). Its
	# weight of 3, a step the ladder does not have, is what the water draws by until
	# phase 7-2 draws every gene by its class, when it weighs an uncommon's 2.
	water = {"rarity": &"uncommon", "weight": 3, "drifter": true}
	tags = [SENSE, GIFT]
	channel = PING
	declares = {"in": [{"name": &"echo", "bearing": true,
		"values": {&"distance": &"distance", &"size": &"size"}}]}
	# **Its look** (gene-looks.md §6): short bristles each ending in a ring -- the
	# pores of a cluster of ampullae of Lorenzini -- over its pigment. Sensing's shade
	# 2, which the ping's lobes and wave are drawn in, a shade apart from the beam's.
	family = SENSING
	look = {"shape": TUFT, "shade": 2, "length": 0.24, "tip": Kinds.TIP_RING}


## **Its numbers on the pause screen** (gene.gd's `lines`): how often it pings, how far,
## and how much of a pulse passes a body.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var food: Variant = ctx["food"]
	var through := stat_at(&"ping_through", t)
	# TRANSLATORS: The pulse gene (`ampulla`, shown as `ping`): a pulse that
	# answers back off every body it meets. "The nearest {} answer" means the
	# {} closest bodies send an answer (three to five, so always several);
	# "passes a body" is how much of the pulse goes on past a body in its way.
	return [[Readout.item("a ping every {} s", [stat_at(&"ping_period", t)],
			[U.TIME]),
		Readout.item("out to {} µm", [stat_at(&"ping_range", t)], [U.DISTANCE]),
		Readout.item("the nearest {} answer", [food.PING_RETURNS_BY_TIER[t]],
			[U.COUNT]),
		Readout.item("stopped by any body") if through <= 0.0
			else Readout.item("{} passes a body", [through], [U.SHARE])],
		[wear]]
