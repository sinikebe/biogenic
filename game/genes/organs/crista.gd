extends "res://game/genes/gene.gd"
## `crista`: **burn**, the folds of a mitochondrion. The only gene that makes a
## strong build cheaper to carry.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **A multiplier on upkeep**, by tier, applied in `genome.gd` where upkeep is
## computed: on the whole bill rather than as a subtraction, so it is worth most
## to the expensive build, which is the one that needs it. What moving costs is
## multiplied by it too (`normal_mode.gd`, metabolism.gd's `spend`).
const BURN_BY_TIER: Array[float] = [1.0, 0.88, 0.77, 0.66]


func _init() -> void:
	organ = &"crista"
	order = 15
	provides = {&"burn": BURN_BY_TIER}
	water = {"weight": 2, "drifter": true}
