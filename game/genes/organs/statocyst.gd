extends "res://game/genes/gene.gd"
## `statocyst` / level, **retired** (2026-09-28). It bought no number, only a lobe
## on the membrane at a bearing that did not turn with the body, and the owner
## judged it useless: knowing which way is up says nothing about the water.
## Nothing replaced it.
##
## **Known, drawn and inert** (gene-catalogue.md §4.4), as `rhabdom` is: a host
## on an older build can still hand one over in a shared pond, and it arrives
## kept and drawn, doing nothing. It left the order before there was a catalogue,
## so it has no place in it.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.


func _init() -> void:
	organ = &"statocyst"
	tags = [RETIRED]
	# **Its class, for the record** (gene-rarity.md §4): uncommon, as its weight of 2
	# was while the water made it. No pool reads it, and its weight is 0.
	water = {"rarity": &"uncommon"}
