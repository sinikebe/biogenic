extends "res://game/genes/gene.gd"
## `trichocyst`: **the dart**. It goes off on its own at what comes for its body,
## on the arc it is worn on -- **a dart in a rear slot is the answer to being
## flanked**, so placing it is a defensive decision (`cell.gd`'s DART_ARC_DEG).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **How close a cell hunting you gets before the dart goes off, and how long
## before there is another one**, by tier.
## The host decides every contact by these: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const DART_RANGE_BY_TIER: Array[float] = [0.0, 130.0, 190.0, 260.0]
const DART_COOLDOWN_BY_TIER: Array[float] = [0.0, 26.0, 18.0, 11.0]
## **What a dart does to what it hits** (docs/design/behaviour.md §4.3): it rests
## this long with its rules unread, and feels the dart as a `hit` at its
## bearing. Today's darts broke off a run and left the hunter resting for the
## same five seconds; with no run to break, the dart stuns. A starting value.
## The host decides every contact by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const DART_STUN := 5.0


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
const WORDS := {&"trichocyst": "sting"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"trichocyst": "a dart at whatever closes in on that side"}


func _init() -> void:
	organ = &"trichocyst"
	order = 10
	provides = {&"dart_range": DART_RANGE_BY_TIER, &"dart_cooldown": DART_COOLDOWN_BY_TIER}
	numbers = {&"stun": DART_STUN}
	water = {"weight": 2, "drifter": true}
	# **Its look** (gene-looks.md §6): spear-headed spines, darts -- a trichocyst's
	# real spindles -- in defending's orange.
	family = DEFENDING
	look = {"shape": SPINES, "shade": 2, "length": 0.32, "tip": Kinds.TIP_SPEAR}


## **Its numbers on the pause screen** (gene.gd's `lines`): how far its dart reaches,
## how wide, and how often.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var cell: Variant = ctx["cell"]
	# TRANSLATORS: The dart gene (`trichocyst`, shown as `sting`): it fires a dart
	# at a hunter that closes in on that side of the body. "{} either side" is
	# the angle, in degrees, to each side of straight ahead that it covers.
	return [[Readout.item("a dart at a hunter within {} µm, {} either side",
			[stat_at(&"dart_range", t), cell.DART_ARC_DEG * 0.5],
			[U.DISTANCE, U.ANGLE]),
		Readout.item("again after {} s", [stat_at(&"dart_cooldown", t)],
			[U.TIME])],
		[wear]]
