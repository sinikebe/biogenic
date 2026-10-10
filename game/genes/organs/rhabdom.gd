extends "res://game/genes/gene.gd"
## `rhabdom` / focus, **retired** (three-senses.md §8 row 2, option C). It
## narrowed a lobe that already existed: the taste lobe's width and its bearing
## jitter. Both went with three-senses.md §2 -- there is no width left to sharpen
## and no bearing left to steady -- and the owner retired the gene rather than
## re-aim it at the nose's floor, a gene whose whole effect would be a number
## nobody can see move.
##
## **Known, drawn and inert** (gene-catalogue.md §4.4): an old `{gene: tier}` map
## that names it -- a save, or a guest on an older build -- keeps it, pays upkeep
## on it and draws it as a gene it does not know, a plain tuft in no family's
## colour (`cilia.gd`'s UNKNOWN_TINT), and no water, drift or gift ever makes one. It left the order before there was a catalogue, so it has no
## place in it: `dominant_of` ranks it as a name it does not know, as it always
## has.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.


func _init() -> void:
	organ = &"rhabdom"
	tags = [RETIRED]
	# **Its class, for the record** (gene-rarity.md §4): uncommon, as its weight of 2
	# was while the water made it. No pool reads it, and its weight is 0.
	water = {"rarity": &"uncommon"}
