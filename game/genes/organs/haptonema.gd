extends "res://game/genes/gene.gd"
## `haptonema`: **the grip**. It holds on to what it touches -- the drop's edge or
## another cell -- absorbing a share of any push-off and keeping the hold for a
## little slack past touching. Any cell that carries it can use it (level 1).
##
## Tier 0 is the cell that has lost this organ entirely (§9.7 allows it): no grip,
## no tether; its tables start at zero on purpose.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **Share of a held cell's push-off absorbed**, by tier; tier 0 = no organ, so it
## starts at zero and climbs to full absorption -- starting values; balance waits
## for players.
const GRIP_BY_TIER: Array[float] = [0.0, 0.5, 0.75, 1.0]
## **Px of slack beyond touching before the hold breaks**, by tier; zero with no
## organ, a few px at tier 1 -- starting values; balance waits for players.
const TETHER_BY_TIER: Array[float] = [0.0, 6.0, 9.0, 12.0]


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
const WORDS := {&"haptonema": "cling"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. The `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"haptonema": "holds on to what it touches: the drop's edge or another cell"}
## **What its action is called** on an instinct's chip (automation.md §13.1).
##
## TRANSLATORS: The name of an action the player's cell can be told to do by one
## of its "instincts" (rules the player writes: "when <a sense reports
## something> -> <do this>"), on a small chip. Lowercase, a few short words.
## "cling": hold on to what you touch and keep it close.
## ROOM: 112 px at 15 px
const GENE_SAYS := {&"haptonema.cling": "cling"}
## **The line that explains it** on the instincts page.
##
## TRANSLATORS: Explains one sense, action or value of the player's "instincts",
## on one line under them: its name (the same words as on its chip), a middle
## dot, then what it is or does, lowercase. "Your cling" is the cell's haptonema,
## which holds on to what it touches. Lowercase.
## ROOM: 856 px at 15 px
const GENE_EXPLAINS := {&"haptonema.cling": "cling · hold on to what you touch, and keep it close"}


func _init() -> void:
	organ = &"haptonema"
	order = 17
	provides = {&"grip": GRIP_BY_TIER, &"tether": TETHER_BY_TIER}
	water = {"rarity": &"rare", "drifter": false}
	tags = [NEVER_DRIFTS]
	born = 0
	# **The cling** (automation.md §4.3): it holds on to what the cell touches,
	# claiming the `swimming` trigger like the flagellum's hold does, from level 1:
	# any cell that carries it can use it. Declared last of every gene's parts, so
	# its owner's bits come after every other.
	declares = {"out": [{"name": &"cling", "claims": [&"cling"]}]}
	# **Its look** (gene-looks.md §6): a coil that wraps -- the grip is more wrap,
	# so four turns where myoneme's default two reads as a spring. In moving's shade
	# 1: one step off the tail's shade 0, so a tile with both tells them apart.
	family = MOVING
	look = {"shape": COIL, "shade": 1, "turns": 4}


## **Its numbers on the pause screen** (gene.gd's `lines`): how much of a push-off it
## absorbs, and how far past touching it holds.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var grip := stat_at(&"grip", t)
	var tether := stat_at(&"tether", t)
	# TRANSLATORS: The grip gene (`haptonema`, shown as `cling`). "A held push-off"
	# is the shove a cell gives to let go; "past touching" is how far beyond just
	# touching it keeps holding.
	return [[Readout.item("absorbs {} of a held push-off", [grip], [U.SHARE]),
			Readout.item("holds on {} px past touching", [tether], [U.DISTANCE])],
		[wear]]
