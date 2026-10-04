extends "res://game/genes/gene.gd"
## `plastid`: **light**. Passive feeding, as a fraction of one upkeep unit
## cancelled outright.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **What it makes**, by tier: at tier 3 a third of a resting cell's hunger never
## happens.
const SUN_BY_TIER: Array[float] = [0.0, 0.12, 0.22, 0.34]


func _init() -> void:
	organ = &"plastid"
	order = 13
	provides = {&"sun": SUN_BY_TIER}
	water = {"weight": 2, "drifter": true}
