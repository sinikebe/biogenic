extends "res://game/genes/gene.gd"
## `pellicle`: **armour**. Your body as another cell's mouth measures it, so a
## gape that could just swallow you no longer can -- and every bite that lands is
## divided by it (`cell.gd`'s `bite_damage`).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **How much bigger a body is to a mouth**, by tier.
## The host decides every contact by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const ARMOR_BY_TIER: Array[float] = [1.0, 1.14, 1.30, 1.52]


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
const WORDS := {&"pellicle": "armor"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"pellicle": "thicker skin, so bites take less and fewer mouths fit"}


func _init() -> void:
	organ = &"pellicle"
	order = 11
	provides = {&"armor": ARMOR_BY_TIER}
	water = {"rarity": &"uncommon", "weight": 2, "drifter": true}
	# **Its look** (gene-looks.md §6): plates, overlapping scales lying along the skin
	# over a thickened rim -- the pellicle is a real layer of plates under the
	# membrane -- the one build that runs along a body rather than out of it.
	family = DEFENDING
	look = {"shape": PLATES, "count": 3}


## **Its numbers on the pause screen** (gene.gd's `lines`): how much bigger it makes you
## to a mouth, and how much less a bite takes.
func lines(t: int, _level: int, _path: StringName, _ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var armour := stat_at(&"armor", t)
	# TRANSLATORS: The thicker-skin gene (`pellicle`, shown as `armor`). "To a mouth
	# you are {} × your size" means a hunting mouth must be that much wider than
	# the cell to swallow it, because of the skin.
	return [[Readout.item("to a mouth you are {} × your size", [armour], [U.TIMES]),
		Readout.item("bites take {} less", [1.0 - 1.0 / armour], [U.SHARE])],
		[wear]]
