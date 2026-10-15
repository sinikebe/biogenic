extends "res://game/genes/gene.gd"
## `haptonema`: **the grip**, after the haptonema of the haptophyte algae -- the
## thread between their two flagella that coils, sticks and holds on to what it
## touches. While it clings, a cell holds on to what it touches -- the drop's edge,
## where it stops, or another cell, which it draws back to touching while it lies
## within its tether -- and lets go past that. Any cell that carries it can cling
## (level 1): its instincts, with `cling`, or your hand, on its button
## (docs/design/haptonema.md).
##
## Tier 0 is the cell that has lost this organ entirely (§9.7 allows it): no grip,
## no tether; its tables start at zero on purpose.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **How hard the hold draws a held cell back**, by tier: the share of the gap past
## touching it closes each step (game/mechanics/grip.gd's `tether_pull`), so at full
## grip a cell that drifts off is back against the skin within a few frames, and at
## half it is drawn back half as hard. Tier 0 is no organ, which holds nothing.
## Starting values; balance waits for players.
const GRIP_BY_TIER: Array[float] = [0.0, 0.5, 0.75, 1.0]
## **How far past touching the hold reaches before it lets go**, in µm (world
## units), by tier: a cell farther off than this is not held, and one held that
## breaks away past it is let go. Starting values; balance waits for players.
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
	# **Common, for now** (the owner, 2026-10-13: "Make it common for now"): the
	# water makes it as it makes a mouth or a tail, and drift may bring it, so a
	# player meets it in the first minutes of a run (haptonema.md §2).
	water = {"rarity": &"common", "drifter": true}
	born = 0
	# **The cling** (automation.md §4.3): it holds on to what the cell touches, a
	# claim of its own, from level 1 -- any cell that carries it can use it.
	# Declared last of every gene's parts, so its owner's bits come after every
	# other. **A button** (gene.gd's `declares`): your hand clings too, on its pad
	# or its key, while it is held.
	declares = {"out": [{"name": &"cling", "claims": [&"cling"], "button": &"held"}]}
	# **Its look** (gene-looks.md §6): a coil that wraps -- the grip is more wrap,
	# so four turns where myoneme's default two reads as a spring. In moving's shade
	# 1: one step off the tail's shade 0, so a tile with both tells them apart.
	family = MOVING
	look = {"shape": COIL, "shade": 1, "turns": 4}


## **Its numbers on the pause screen** (gene.gd's `lines`): how hard it holds, and
## how far past touching it lets go.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var grip := stat_at(&"grip", t)
	var tether := stat_at(&"tether", t)
	# TRANSLATORS: The grip gene (`haptonema`, shown as `cling`), which holds on to
	# what the cell touches. "Grips at {} strength": how hard it draws a held cell
	# back, as a percentage; "lets go {} µm past touching": how far a held cell can
	# move off the skin before the hold breaks.
	return [[Readout.item("grips at {} strength", [grip], [U.SHARE]),
			Readout.item("lets go {} µm past touching", [tether], [U.DISTANCE])],
		[wear]]
