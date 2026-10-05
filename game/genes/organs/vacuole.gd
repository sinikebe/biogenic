extends "res://game/genes/gene.gd"
## `vacuole`: **a bigger tank**. Hunger rises more slowly, because there is more
## of you to run down.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **How much bigger the tank is**, by tier.
const STORE_BY_TIER: Array[float] = [1.0, 1.28, 1.60, 2.00]


func _init() -> void:
	organ = &"vacuole"
	order = 14
	provides = {&"store": STORE_BY_TIER}
	water = {"weight": 2, "drifter": true}
