extends "res://game/genes/gene.gd"
## `cytostome`: **the mouth**. Every peer in the water has one and no drifter
## does (docs/design/genes-and-cilia.md §1.3), and §9.7 lets a player put another
## gene over their own and live with it.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

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
## The host decides every contact by this: change it with Wire.PROTOCOL, by hand (wire.gd).
const GAPE_BY_TIER: Array[float] = [0.58, 0.82, 1.05, 1.40]

## **What one bite takes out of a body too big to swallow**, before the target's
## skin is taken into account. Tier 0 is a cell with no mouth at all and it is a
## hard zero, not an extrapolated step: drifters have no cytostome, and a floor
## that could chew on you would not be a floor.
## The host decides every contact by this: change it with Wire.PROTOCOL, by hand (wire.gd).
const BITE_BY_TIER: Array[float] = [0.0, 0.07, 0.10, 0.14]


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
