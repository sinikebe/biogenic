extends "res://game/genes/gene.gd"
## `trichocyst`: **the dart**. It goes off on its own at what comes for its body,
## on the arc it is worn on -- **a dart in a rear slot is the answer to being
## flanked**, so placing it is a defensive decision (`cell.gd`'s DART_ARC_DEG).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **How close a cell hunting you gets before the dart goes off, and how long
## before there is another one**, by tier.
const DART_RANGE_BY_TIER: Array[float] = [0.0, 130.0, 190.0, 260.0]
const DART_COOLDOWN_BY_TIER: Array[float] = [0.0, 26.0, 18.0, 11.0]
## **What a dart does to what it hits** (docs/design/behaviour.md §4.3): it rests
## this long with its rules unread, and feels the dart as a `hit` at its
## bearing. Today's darts broke off a run and left the hunter resting for the
## same five seconds; with no run to break, the dart stuns. A starting value.
const DART_STUN := 5.0


func _init() -> void:
	organ = &"trichocyst"
	order = 10
	provides = {&"dart_range": DART_RANGE_BY_TIER, &"dart_cooldown": DART_COOLDOWN_BY_TIER}
	numbers = {&"stun": DART_STUN}
	water = {"weight": 2, "drifter": true}
