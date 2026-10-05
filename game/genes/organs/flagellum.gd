extends "res://game/genes/gene.gd"
## `flagellum`: **the tail**. It fires a random forward impulse on its own
## schedule and the cell coasts (docs/design/perception.md §2): sluggish and
## slippery on purpose.
##
## Tier 0 is the cell that has lost this organ entirely (§9.7 allows it). It is
## **not in the design**: its tables are extrapolated one step below tier 1 on the
## ladder's own spacing, which is the least invented answer available.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **Speed added along the heading by one beat**, by tier.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const IMPULSE_SPEED_BY_TIER: Array[float] = [118.0, 138.0, 162.0, 190.0]
## **Seconds between impulses**, resampled after each one, by tier.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const IMPULSE_GAP_MIN_BY_TIER: Array[float] = [2.00, 1.70, 1.45, 1.20]
const IMPULSE_GAP_MAX_BY_TIER: Array[float] = [4.30, 3.60, 3.00, 2.50]

## **A tail can be held still from its second copy** (docs/design/
## automation.md §5.2, rows 29, 37 and 38): the one number the hand's hold and
## a body's rules both ask, of the tail's level -- `genome.gd`'s `level_of`,
## which for every gene but the beam is its worn copies. A held tail does not
## beat, costs nothing, and **keeps its clock**: the stroke clock stands still
## and is never reset, so two strokes are never closer than the shortest gap
## above however a hold comes and goes (`cell.gd`'s `_process`). Below it the
## tail beats on its own, for every body that swims. Not a table a host's
## referee judges by: a held tail only ever makes a body slower.
const HOLD_LEVEL := 2


func _init() -> void:
	organ = &"flagellum"
	order = 2
	provides = {&"impulse_speed": IMPULSE_SPEED_BY_TIER,
		&"impulse_gap_min": IMPULSE_GAP_MIN_BY_TIER,
		&"impulse_gap_max": IMPULSE_GAP_MAX_BY_TIER}
	numbers = {&"hold_level": HOLD_LEVEL}
	water = {"weight": 4, "drifter": true}
	born = 1
	# **The hold** (automation.md §4.3): it holds the tail still and only the
	# tail, claiming the `swimming` trigger `body.swim` claims, from the second
	# copy (rows 29 and 38). Declared last of every gene's parts, so its owner's
	# bits come after every other.
	declares = {"out": [{"name": &"hold", "claims": [&"swimming"], "level": HOLD_LEVEL}]}
