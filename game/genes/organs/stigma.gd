extends "res://game/genes/gene.gd"
## `stigma`: **the eyespot**. What it buys is the membrane's light lobe -- a
## sharp, certain bearing on **mass**, at its tier's width at every range, which
## dread cannot muffle. It is silent about the two cells genes-and-cilia.md §1.1
## exists to create, and deliberately: a shadow is a fact about a body, not about
## a mouth.
##
## It provides no number: how far a shade reaches is the water's (`food.gd`'s
## SHADOW_RANGE) and how wide its lobe is the membrane's, by its tier
## (`signal_bus.gd`'s LIGHT_HALFWIDTH_DEG). A mechanic finds it by its channel.
##
## The weakest opening of the four free senses -- a shadow is mass, and the
## authored first arrival is a drifter with almost none -- but a real sense, and
## what it does see is the half of the water that can eat you.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit


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
const WORDS := {&"stigma": "see"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"stigma": "feels the shadow of anything big, however dark"}
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
const GENE_SENSES := {&"stigma.shadow": "shadow"}
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
	&"stigma.shadow": "shadow · the shade of anything your size or bigger: where, and how dark.",
}


func _init() -> void:
	organ = &"stigma"
	order = 3
	water = {"weight": 3, "drifter": true}
	tags = [SENSE, GIFT]
	channel = LIGHT
	declares = {"in": [{"name": &"shadow", "bearing": true,
		"values": {&"level": &"level"}}]}
	# **Its look** (gene-catalogue.md §7.1): a tuft of four over its pigment.
	look = {"shape": TUFT, "hue": Color(0.98, 0.78, 0.30), "count": 4}  # see, 45 deg


## **Its numbers on the pause screen** (gene.gd's `lines`): what it feels the shadow of,
## how far, and how finely.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var food: Variant = ctx["food"]
	var bus: Variant = ctx["bus"]
	# TRANSLATORS: The shadow-sensing gene (`stigma`, shown as `see`): it feels
	# the shadow of large bodies. "A bearing to within {}" means the direction
	# of a body is known to within that many degrees.
	return [[Readout.item("feels bodies over {} × your size",
			[food.SHADOW_MIN_RATIO], [U.TIMES]),
		Readout.item("out to {} µm", [food.SHADOW_RANGE], [U.DISTANCE]),
		Readout.item("a bearing to within {}", [bus.LIGHT_HALFWIDTH_DEG[t]],
			[U.ANGLE])],
		[wear]]
