extends "res://game/genes/gene.gd"
## `stigma`: **the eyespot**. What it buys is the membrane's light lobe -- a
## sharp, certain bearing on **mass**, at its tier's width at every range, which
## dread cannot muffle. It is silent about the two cells genes-and-cilia.md §1.1
## exists to create, and deliberately: a shadow is a fact about a body, not about
## a mouth.
##
## It provides no number: how far a shade reaches is the water's (`food.gd`'s
## SHADOW_RANGE) and how wide its lobe is the membrane's, by its tier
## (`signal_bus.gd`'s LIGHT_HALFWIDTH_DEG). A mechanic finds it by its channel.
##
## The weakest opening of the four free senses -- a shadow is mass, and the
## authored first arrival is a drifter with almost none -- but a real sense, and
## what it does see is the half of the water that can eat you.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.


func _init() -> void:
	organ = &"stigma"
	order = 3
	water = {"weight": 3, "drifter": true}
	tags = [SENSE, GIFT]
	channel = LIGHT
	declares = {"in": [{"name": &"shadow", "bearing": true,
		"values": {&"level": &"level"}}]}
