extends "res://game/genes/gene.gd"
## `myoneme`: **the dash**. A burst of speed for a tap, paid for in hunger -- a
## better myoneme is a cheaper dash, not a bigger one, so it stays a decision.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **The burst**, by tier.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const DASH_SPEED_BY_TIER: Array[float] = [0.0, 190.0, 240.0, 300.0]
## **What a dash costs, as a share of a born cell's tank**: 2.2, 1.6 and 1.2 s
## of rest. The run pays it as those seconds, through metabolism.gd's `spend`,
## like every other cost, so `crista` makes it cheaper and a bigger `vacuole`
## tank makes it a smaller share (gene-stats.md §11, owner's call 2, answered
## *yes* on 2026-09-29). It was a fixed share of the bar that neither softened;
## a born cell pays what it did.
const DASH_COST_BY_TIER: Array[float] = [0.0, 0.060, 0.045, 0.032]


func _init() -> void:
	organ = &"myoneme"
	order = 9
	provides = {&"dash_speed": DASH_SPEED_BY_TIER, &"dash_cost": DASH_COST_BY_TIER}
	water = {"weight": 2, "drifter": true}
	declares = {"out": [{"name": &"dash", "claims": [&"dash"]}]}
