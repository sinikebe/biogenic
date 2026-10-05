extends "res://game/genes/gene.gd"
## `axoneme`: **the push**. Thrust along the heading while the player holds, in
## units per second squared. **The flagellum made voluntary**: the random
## involuntary impulse keeps firing underneath it at whatever tier the tail is,
## and this adds a push you asked for on top.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **The push's acceleration**, by tier. Held against DRAG these settle at 81 /
## 115 / 155 units per second, against a born cell's realised 56.5. **Measured,
## and the first numbers were wrong by a factor of two**: at 230 the terminal
## speed is 310, and since the chase scales its cruise off the prey's own speed,
## a hunter could not physically close on a pushing cell at any tier. Dread
## stopped meaning anything, which is most of the game.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const PUSH_ACCEL_BY_TIER: Array[float] = [0.0, 60.0, 85.0, 115.0]


func _init() -> void:
	organ = &"axoneme"
	order = 7
	provides = {&"push_accel": PUSH_ACCEL_BY_TIER}
	# **The beam and the voluntary push are the rarest things in the water**: the
	# two that change the most about a run.
	water = {"weight": 2, "drifter": true}
	declares = {"out": [{"name": &"push", "claims": [&"push"], "options": [0.5, 1.0]}]}
