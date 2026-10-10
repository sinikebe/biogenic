extends "res://game/genes/gene.gd"
## `palp`: **touch**. How far a cell can feel a body with no light at all. A sense
## the water does not count as sight: it finds what is already against you.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **How far it feels**, by tier.
const TOUCH_RANGE_BY_TIER: Array[float] = [0.0, 150.0, 230.0, 330.0]


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
const WORDS := {&"palp": "touch"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"palp": "feels what is against you, with no light at all"}
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
const GENE_SENSES := {&"palp.touch": "touch"}
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
	&"palp.touch": "touch · the nearest thing against your skin: where, and how close.",
}


func _init() -> void:
	organ = &"palp"
	order = 8
	provides = {&"touch_range": TOUCH_RANGE_BY_TIER}
	water = {"rarity": &"uncommon", "weight": 2, "drifter": true}
	channel = TOUCH
	declares = {"in": [{"name": &"touch", "bearing": true,
		"values": {&"closeness": &"level"}}]}
	# **Its look** (gene-looks.md §6): two long feelers, splayed apart as feelers are.
	family = SENSING
	look = {"shape": TUFT, "shade": 2, "count": 2, "length": 0.54, "bend": 34.0}


## **Its numbers on the pause screen** (gene.gd's `lines`): how near a body it feels.
func lines(t: int, _level: int, _path: StringName, _ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	# TRANSLATORS: The touch gene (`palp`, shown as `touch`): it feels what is
	# against the cell with no light at all.
	return [[Readout.item("feels a body within {} µm of your skin",
			[stat_at(&"touch_range", t)], [U.DISTANCE])],
		[wear]]
