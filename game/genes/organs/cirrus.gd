extends "res://game/genes/gene.gd"
## `cirrus`: **steering**, a tuft of fused cilia on each flank. It only makes a
## body's turns faster, so it declares nothing to a body's rules.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **Flat out, the cell turns this fast**, by tier. Tier 1 is about 35 deg/s, so
## a half turn costs five seconds: slow on purpose. Tier 3 is 58 deg/s, and §7.1
## gives the whole of the improved dodge to this one number.
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const TURN_RATE_BY_TIER: Array[float] = [0.48, 0.62, 0.80, 1.02]
## **Seconds for the turn to actually build.** The lag is what makes steering feel
## like leaning on something rather than driving it; a better cirrus shortens it.
const TURN_RESPONSE_BY_TIER: Array[float] = [1.43, 1.10, 0.85, 0.65]


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
const WORDS := {&"cirrus": "turn"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"cirrus": "turns you faster, and sooner after you ask"}


func _init() -> void:
	organ = &"cirrus"
	order = 1
	provides = {&"turn_rate": TURN_RATE_BY_TIER, &"turn_response": TURN_RESPONSE_BY_TIER}
	# **The three starting organs stay the commonest thing in the water**: a genome
	# that fills up with exotica before it has a mouth is a run that cannot eat.
	# Common: what every run needs (gene-rarity.md §4).
	water = {"rarity": &"common", "drifter": true}
	born = 1
	# **Its look** (gene-looks.md §6): oars, rowing strokes with a knee, on both flanks
	# whatever slot holds it -- the kind's defaults are the oars it always drew -- in
	# moving's sky blue.
	family = MOVING
	look = {"shape": OARS}


## **Its numbers on the pause screen** (gene.gd's `lines`): how fast it turns, and what
## turning burns.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var cell: Variant = ctx["cell"]
	var burn := float(ctx.get("burn", 1.0))
	var rate := stat_at(&"turn_rate", t)
	# TRANSLATORS: The steering gene (`cirrus`, shown as `turn`). "A half turn"
	# is turning round through 180 degrees; "burns {} s a second" is the
	# energy it uses, in seconds of the food tank, each second.
	return [[Readout.item("a half turn in {} s", [PI / rate], [U.TIME]),
		Readout.item("the turn builds over {} s", [stat_at(&"turn_response", t)],
			[U.TIME])],
		[Readout.item("turning burns {} s a second, {} s a half turn",
			[rate * cell.TURN_COST * burn, PI * cell.TURN_COST * burn],
			[U.RATE, U.ENERGY]), wear]]
