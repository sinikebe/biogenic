extends "res://game/genes/gene.gd"
## `cirrus`: **steering**, a tuft of fused cilia on each flank. It only makes a
## body's turns faster, so it declares nothing to a body's rules.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **Flat out, the cell turns this fast**, by tier. Tier 1 is about 35 deg/s, so
## a half turn costs five seconds: slow on purpose. Tier 3 is 58 deg/s, and §7.1
## gives the whole of the improved dodge to this one number.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const TURN_RATE_BY_TIER: Array[float] = [0.48, 0.62, 0.80, 1.02]
## **Seconds for the turn to actually build.** The lag is what makes steering feel
## like leaning on something rather than driving it; a better cirrus shortens it.
const TURN_RESPONSE_BY_TIER: Array[float] = [1.43, 1.10, 0.85, 0.65]


func _init() -> void:
	organ = &"cirrus"
	order = 1
	provides = {&"turn_rate": TURN_RATE_BY_TIER, &"turn_response": TURN_RESPONSE_BY_TIER}
	# **The three starting organs stay the commonest thing in the water**: a genome
	# that fills up with exotica before it has a mouth is a run that cannot eat.
	water = {"weight": 4, "drifter": true}
	born = 1
