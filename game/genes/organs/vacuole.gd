extends "res://game/genes/gene.gd"
## `vacuole`: **a bigger tank**. Hunger rises more slowly, because there is more
## of you to run down.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **How much bigger the tank is**, by tier.
const STORE_BY_TIER: Array[float] = [1.0, 1.28, 1.60, 2.00]


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
const WORDS := {&"vacuole": "store"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"vacuole": "a bigger tank, so hunger takes longer to reach you"}


func _init() -> void:
	organ = &"vacuole"
	order = 14
	provides = {&"store": STORE_BY_TIER}
	water = {"rarity": &"uncommon", "drifter": true}
	# **Its look** (gene-looks.md §6): a clear bubble under the skin, one for each
	# copy. Metabolism's shade 0.
	family = METABOLISM
	look = {"shape": ORGANELLE, "shade": 0, "form": Kinds.FORM_BUBBLE}


## **Its numbers on the pause screen** (gene.gd's `lines`): how much the tank holds.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var metabolism: Variant = ctx["metabolism"]
	# TRANSLATORS: The bigger-tank gene (`vacuole`, shown as `store`): the cell can
	# keep more food, so hunger takes longer to arrive. "A full tank holds {} s,
	# not {}" compares with the tank of a cell without it, in seconds of food.
	return [[Readout.item("a full tank holds {} s, not {}",
			[metabolism.HUNGER_SECONDS * stat_at(&"store", t),
				metabolism.HUNGER_SECONDS], [U.ENERGY, U.ENERGY])],
		[wear]]
