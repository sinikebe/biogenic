extends "res://game/genes/gene.gd"
## `crista`: **burn**, the folds of a mitochondrion. The only gene that makes a
## strong build cheaper to carry.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **A multiplier on upkeep**, by tier, applied in `genome.gd` where upkeep is
## computed: on the whole bill rather than as a subtraction, so it is worth most
## to the expensive build, which is the one that needs it. What moving costs is
## multiplied by it too (`normal_mode.gd`, metabolism.gd's `spend`).
const BURN_BY_TIER: Array[float] = [1.0, 0.88, 0.77, 0.66]


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
const WORDS := {&"crista": "burn"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"crista": "burns cleaner, so everything you carry costs less"}


func _init() -> void:
	organ = &"crista"
	order = 15
	provides = {&"burn": BURN_BY_TIER}
	water = {"weight": 2, "drifter": true}
	# **Its look** (gene-catalogue.md §7.1): a tuft of six, darker than the palp.
	look = {"shape": TUFT, "hue": Color(0.86, 0.50, 0.22), "count": 6}  # burn, 26 deg


## **Its numbers on the pause screen** (gene.gd's `lines`): how much less everything burns.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var burn := float(ctx.get("burn", 1.0))
	# TRANSLATORS: The cleaner-burning gene (`crista`, shown as `burn`): everything
	# the cell carries costs less energy to keep.
	return [[Readout.item("everything burns {} less", [1.0 - stat_at(&"burn", t)],
			[U.SHARE])],
		[wear]]
