extends "res://game/genes/gene.gd"
## `cytostome`: **the mouth**. Every peer in the water has one and no drifter
## does (docs/design/genes-and-cilia.md §1.3), and §9.7 lets a player put another
## gene over their own and live with it.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **How wide the mouth opens**, as a multiple of body radius, by tier. Index 0
## is a cell with no mouth at all, which is a real state: drifters have no
## cytostome, and §9.7 lets the player put a fourth gene over their own.
##
## **The gape keeps its job and loses its veto.** It used to be the whole
## edibility rule; docs/design/edibility.md §1 withdraws that. You can attack
## anything -- the gape decides whether you swallow it whole (`B.radius <
## A.gape()`, evaluated in both directions independently) or have to take it
## apart a bite at a time, and `cell.gd`'s `bite_damage`'s `min(gape / radius,
## 1)` keeps the two continuous with each other.
## The host decides every contact by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const GAPE_BY_TIER: Array[float] = [0.58, 0.82, 1.05, 1.40]

## **What one bite takes out of a body too big to swallow**, before the target's
## skin is taken into account. Tier 0 is a cell with no mouth at all and it is a
## hard zero, not an extrapolated step: drifters have no cytostome, and a floor
## that could chew on you would not be a floor.
## The host decides every contact by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const BITE_BY_TIER: Array[float] = [0.0, 0.07, 0.10, 0.14]


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
const WORDS := {&"cytostome": "eat"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"cytostome": "a wider mouth swallows bigger things whole"}


func _init() -> void:
	organ = &"cytostome"
	order = 0
	provides = {&"gape": GAPE_BY_TIER, &"bite": BITE_BY_TIER}
	# **Never drawn from**: §1.3 gives every peer a mouth and no drifter one, so
	# the only pool a weight is ever read from has none. Kept because it is §3.4's
	# number, and the genome strip uses the same four.
	water = {"weight": 3, "drifter": false}
	# **Always expressed, never drifted**: a daughter born with no mouth is not
	# one of two builds to choose between, it is a body that cannot feed itself,
	# and nobody would pick it.
	tags = [ALWAYS_EXPRESSED, NEVER_DRIFTS]
	born = 1
	# **Its look** (gene-looks.md §6): the oral mat, eating's one build -- dense fine
	# cilia with a beat travelling along them -- whose kind's defaults are the mat it
	# always drew. Eating's shade 2, the end of the band nearest food green: the mouth
	# *is* nutrition.
	family = EATING
	look = {"shape": MAT, "shade": 2}


## **Its numbers on the pause screen** (gene.gd's `lines`): what it swallows and bites,
## and what its biggest meal is worth.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var cell: Variant = ctx["cell"]
	var metabolism: Variant = ctx["metabolism"]
	var food: Variant = ctx["food"]
	var gape := stat_at(&"gape", t)
	var bite := stat_at(&"bite", t)
	# The biggest meal is a body just inside the gape, and a meal is
	# worth its size against yours, clamped as food.gd clamps it.
	var share: float = metabolism.meal(clampf(gape, food.MEAL_MIN,
		food.MEAL_MAX))
	# What a bite takes depends on where it lands (cell.gd's `flank`):
	# the least at the nose, the most at the tail, so the line says both.
	#
	# TRANSLATORS: The mouth gene (`cytostome`, shown as `eat`). "Its biggest
	# meal" is the largest body this mouth can swallow; "worth {} s" is how
	# many seconds of food it gives the cell. "Your size" is the cell's own
	# size. "Head-on" is when the bitten body faces the mouth, "from behind"
	# when it turns away.
	return [[Readout.item("swallows whole under {} × your size", [gape], [U.TIMES]),
		Readout.item("bites take {} head-on, {} from behind",
			[bite * cell.FLANK_AHEAD, bite * cell.FLANK_ASTERN],
			[U.SHARE, U.SHARE])],
		[Readout.item("its biggest meal fills you") if share >= 1.0
			else Readout.item("its biggest meal is worth {} s", [share * float(ctx["tank"])],
				[U.ENERGY]), wear]]
