extends "res://game/genes/gene.gd"
## `chemocyte`: **the nose**. How far a cell's chemoreceptors reach. The scent
## field itself is the water's -- what the water is doing is not a function of
## who is sniffing it -- but only sources inside this radius reach the taste lobe,
## so a poor nose smells what is near and a good one smells the whole field.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **How far it smells**, by tier. Tier 0 is a cell with no chemoreceptor at all,
## and it is **not** the extrapolated step the drive tables use: it is a hard
## zero, because taste is a gene and a cell without it gets no bearing to food
## whatsoever. Tier 3 is `food.gd`'s SCENT_RANGE, so a saturated nose is exactly
## the always-on taste every build before it shipped with.
const SMELL_RANGE_BY_TIER: Array[float] = [0.0, 1100.0, 1350.0, 1600.0]


func _init() -> void:
	organ = &"chemocyte"
	order = 5
	provides = {&"smell_range": SMELL_RANGE_BY_TIER}
	# **Weighted like a starting organ, and that is deliberate.** Taste stopped
	# being innate when it became this gene, so a nose is the difference between a
	# run and a wander -- it has to be the commonest thing the water can hand you,
	# on a par with the three organs you are born with.
	water = {"weight": 4, "drifter": true}
	tags = [SENSE, GIFT]
	channel = SMELL
	declares = {"in": [{"name": &"smell", "bearing": false,
		"values": {&"level": &"level"}}]}
