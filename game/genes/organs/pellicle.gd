extends "res://game/genes/gene.gd"
## `pellicle`: **armour**. Your body as another cell's mouth measures it, so a
## gape that could just swallow you no longer can -- and every bite that lands is
## divided by it (`cell.gd`'s `bite_damage`).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **How much bigger a body is to a mouth**, by tier.
## The host decides every contact by this: change it with Wire.PROTOCOL, by hand (wire.gd).
## Wire.RULES holds its second copy's alone.
const ARMOR_BY_TIER: Array[float] = [1.0, 1.14, 1.30, 1.52]


func _init() -> void:
	organ = &"pellicle"
	order = 11
	provides = {&"armor": ARMOR_BY_TIER}
	water = {"weight": 2, "drifter": true}
