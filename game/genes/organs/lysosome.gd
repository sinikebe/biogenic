extends "res://game/genes/gene.gd"
## `lysosome`: **mend**, inside the cell (docs/design/inside-genes.md §3; the owner,
## 2026-10-17). A real lysosome is the cell's repair kit as well as its stomach: a
## torn membrane is patched by lysosomes fusing into the tear, within seconds. Here
## it makes a wound knit back up faster, and nothing else.
##
## **Inside, and only inside**: it faces nowhere, so it sits in the inside slots
## and never on an arc.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **How much faster a wound mends**, by tier: a whole wound in `cell.gd`'s
## MEND_SECONDS (75 s) divided by this -- 50 s, 37.5 s and 30 s. Starting values
## (inside-genes.md §3.2): the first copy is worth having, and three still leave a
## fight something a cell has to get away from to recover. Mending stops while harm
## is in the body, whatever this says.
## The host decides every contact by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const MEND_BY_TIER: Array[float] = [1.0, 1.5, 2.0, 2.5]


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
const WORDS := {&"lysosome": "mend"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"lysosome": "patches your wounds, so a bite heals sooner"}


func _init() -> void:
	organ = &"lysosome"
	order = 18
	place = INSIDE
	provides = {&"mend": MEND_BY_TIER}
	# **Rare** (gene-rarity.md §4; the gene playbook's rule when unsure): a
	# recovery gene a run may lean on but is not built from. It drifts, so a
	# drifter can carry it and a meal can find it.
	water = {"rarity": &"rare", "drifter": true}
	# **Its look** (gene-looks.md §6): small dense bodies inside the cell, one for
	# each copy, as lysosomes look under a microscope. Metabolism's shade 2.
	family = METABOLISM
	look = {"shape": ORGANELLE, "shade": 2, "form": Kinds.FORM_DENSE, "size": 0.22}


## **Its numbers on the pause screen** (gene.gd's `lines`): how long a whole wound
## takes to mend.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var cell: Variant = ctx["cell"]
	# TRANSLATORS: The mending gene (`lysosome`, shown as `mend`): a wound heals
	# faster. "A wound mends in {} s, not {}" compares with a cell without it, in
	# seconds for a whole wound to heal.
	return [[Readout.item("a wound mends in {} s, not {}",
			[cell.MEND_SECONDS / stat_at(&"mend", t), cell.MEND_SECONDS],
			[U.TIME, U.TIME])],
		[wear]]
