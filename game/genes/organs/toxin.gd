extends "res://game/genes/gene.gd"
## **The toxin** (docs/design/dna-slots.md §3, §6): one organ in two places.
## Outside it is `toxicyst`, venom -- the real organ, the harpoon hunting ciliates
## fire from round their mouths -- on the bite at the front and a sting for what
## bites a side or the stern. Inside it is `veneneux`, poison -- French for
## *poisonous*, the name it shipped under -- for whatever bites or swallows the
## body. Doses replace both of what the old `veneneux` did: stacks that wear off
## over seconds and act while they last (`cell.gd`'s dose numbers).
##
## **Its one variant is its corrosive strain**, whose dose is harm. A second
## strain is a second entry in [member variants], with its own two keys
## (dna-slots.md §8.3): every rule that reads forms already covers it. The keys
## are permanent once shipped, because saves and the wire keep them, and the
## name on screen is `genome.gd`'s NAMES, not the key.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## `toxicyst` / **venom**, outside: the stacks its every bite leaves at the front,
## and its every sting on a side, by copies. One a copy, which the line can say as
## such. Armour does not stop them: they ride in whole.
const VENOM_STACKS_BY_TIER: Array[float] = [0.0, 1.0, 2.0, 3.0]
## `veneneux` / **poison**, inside: the stacks whatever bites the body takes, a
## bite, by copies -- the price of chewing a poisonous cell, in place of the old
## bite-back share.
const POISON_STACKS_BY_TIER: Array[float] = [0.0, 1.0, 2.0, 3.0]
## **And what whatever swallows it takes**, by copies: one copy takes 0.8 of a
## born swallower, three kill anything up to r40. The swallowed body is eaten all
## the same (owner's row 5): nobody is spat out any more.
const SWALLOW_STACKS_BY_TIER: Array[float] = [0.0, 16.0, 32.0, 48.0]


func _init() -> void:
	organ = &"toxin"
	variants = [
		# The first form listed is the variety: the name the toxin goes by where no
		# place is known yet -- the water's draws, the floor's count, and two meals
		# in the tray found to be one. `veneneux` was the gene before there were
		# places, so it is the inside form and comes first.
		{"variant": &"corrosive", "dose": &"harm",
			"water": {"weight": 2, "drifter": true},
			"forms": {
				INSIDE: {"key": &"veneneux", "order": 12,
					"provides": {&"poison_stacks": POISON_STACKS_BY_TIER,
						&"swallow_stacks": SWALLOW_STACKS_BY_TIER}},
				# Appended, last, when there came to be places: at the end so that
				# no tie between two genes that already existed changed.
				OUTSIDE: {"key": &"toxicyst", "order": 16,
					"provides": {&"venom_stacks": VENOM_STACKS_BY_TIER}},
			}},
	]
