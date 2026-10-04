extends "res://game/genes/gene.gd"
## `palp`: **touch**. How far a cell can feel a body with no light at all. A sense
## the water does not count as sight: it finds what is already against you.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **How far it feels**, by tier.
const TOUCH_RANGE_BY_TIER: Array[float] = [0.0, 150.0, 230.0, 330.0]


func _init() -> void:
	organ = &"palp"
	order = 8
	provides = {&"touch_range": TOUCH_RANGE_BY_TIER}
	water = {"weight": 2, "drifter": true}
	channel = TOUCH
	declares = {"in": [{"name": &"touch", "bearing": true,
		"values": {&"closeness": &"level"}}]}
