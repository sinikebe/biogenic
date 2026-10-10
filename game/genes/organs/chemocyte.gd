extends "res://game/genes/gene.gd"
## `chemocyte`: **the nose**. How far a cell's chemoreceptors reach. The scent
## field itself is the water's -- what the water is doing is not a function of
## who is sniffing it -- but only sources inside this radius reach the taste lobe,
## so a poor nose smells what is near and a good one smells the whole field.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **How far it smells**, by tier. Tier 0 is a cell with no chemoreceptor at all,
## and it is **not** the extrapolated step the drive tables use: it is a hard
## zero, because taste is a gene and a cell without it gets no bearing to food
## whatsoever. Tier 3 is `food.gd`'s SCENT_RANGE, so a saturated nose is exactly
## the always-on taste every build before it shipped with.
const SMELL_RANGE_BY_TIER: Array[float] = [0.0, 1100.0, 1350.0, 1600.0]


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
const WORDS := {&"chemocyte": "smell"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"chemocyte": "smells food, strongest where your nose is pointed"}
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
const GENE_SENSES := {&"chemocyte.smell": "smell"}
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
	&"chemocyte.smell": "smell · how strongly food your mouth could take smells, along your nose.",
}


func _init() -> void:
	organ = &"chemocyte"
	order = 5
	provides = {&"smell_range": SMELL_RANGE_BY_TIER}
	# **Common, like a starting organ, and that is deliberate.** Taste stopped
	# being innate when it became this gene, so a nose is the difference between a
	# run and a wander -- it has to be the commonest thing the water can hand you,
	# on a par with the three organs you are born with (gene-rarity.md §4).
	water = {"rarity": &"common", "drifter": true}
	tags = [SENSE, GIFT]
	channel = SMELL
	declares = {"in": [{"name": &"smell", "bearing": false,
		"values": {&"level": &"level"}}]}
	# **Its look** (gene-looks.md §6): forked bristles, a chemoreceptor's pores, over
	# its pigment.
	family = SENSING
	look = {"shape": TUFT, "tip": Kinds.TIP_FORK}


## **Its numbers on the pause screen** (gene.gd's `lines`): how far it smells, and how
## much behind it.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var food: Variant = ctx["food"]
	# TRANSLATORS: The smell gene (`chemocyte`, shown as `smell`). "{} as strong
	# behind it" compares what it smells behind the cell with what it smells in
	# front, as a percentage.
	return [[Readout.item("smells food out to {} µm",
			[stat_at(&"smell_range", t)], [U.DISTANCE]),
		Readout.item("{} as strong behind it", [food.SMELL_BEHIND], [U.SHARE])],
		[wear]]
