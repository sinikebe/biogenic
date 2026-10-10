extends "res://game/genes/gene.gd"
## `plastid`: **light**. Passive feeding, as a fraction of one upkeep unit
## cancelled outright.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **What it makes**, by tier: at tier 3 a third of a resting cell's hunger never
## happens.
const SUN_BY_TIER: Array[float] = [0.0, 0.12, 0.22, 0.34]


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
const WORDS := {&"plastid": "sun"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"plastid": "makes a little of its own food, so you starve slower"}


func _init() -> void:
	organ = &"plastid"
	order = 13
	provides = {&"sun": SUN_BY_TIER}
	water = {"rarity": &"uncommon", "drifter": true}
	# **Its look** (gene-looks.md §6): a solid lens-shaped body under the skin, a
	# chloroplast, one for each copy and nothing outside the skin: metabolism is
	# drawn inside, which tells it from the mouth's mat where colour cannot.
	family = METABOLISM
	look = {"shape": ORGANELLE, "form": Kinds.FORM_LENS}


## **Its numbers on the pause screen** (gene.gd's `lines`): how much food it makes.
func lines(t: int, _level: int, _path: StringName, _ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	# Not scaled by `crista`: metabolism.gd takes the sun off the bill
	# as it is, after the bill has been discounted.
	#
	# TRANSLATORS: The light-eating gene (`plastid`, shown as `sun`): the cell
	# makes a little food of its own from light.
	return [[Readout.item("makes {} s of food every second", [stat_at(&"sun", t)],
			[U.RATE])],
		[wear]]
