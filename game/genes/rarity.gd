extends RefCounted
## **How often the water makes a gene** (docs/design/gene-rarity.md §2): the classes a
## gene's `water.rarity` names, commonest first -- what each weighs in the water's draw,
## and how many living carriers the drop's floor keeps of each (§2.1, §3.3). **A class
## is a row, and nothing else names one**: the catalogue asks this ladder in its order,
## so "the commons" are its first row wherever a reader means them, and a fourth class
## later is one row more -- a name, a weight and a floor.
##
## **What it does not know**: genes, waters, or how the floor works. The catalogue
## resolves each key's class, weight and floor from it once (`catalogue.gd`'s
## `rarity_of`, `water_weight` and `floor_of`), and nothing reads the weights here
## directly.
##
## **Starting values** (CLAUDE.md, "Balance waits for players"; gene-rarity.md §14):
## common and uncommon weigh what today's water weighs most, 4 and 2, so today's genes
## keep them; rare is an eighth of a common, a body a player sees now and then and may
## chase, never a crowd. The floor keeps two of what a run is built from, as it always
## has, and one of the long tail, whose genes a player cannot tell kept at one from kept
## at two. Each number is one line, and a lever, not a measurement.
##
## Loads nothing. No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **The ladder, commonest first**: each class's name, its weight in the water's draw
## (§2.2: a variety's share of its organ's, the organ's against the others), and the
## living carriers the floor keeps of each variety of it (§3.3).
const LADDER: Array[Dictionary] = [
	{"class": &"common", "weight": 4.0, "floor": 2},
	{"class": &"uncommon", "weight": 2.0, "floor": 2},
	{"class": &"rare", "weight": 0.5, "floor": 1},
]
## **The share of the drifters' draw the first class always holds** (§2.3): what the
## born organs and the nose hold today. Where the ladder would give the commons less,
## everything else shares the rest by its weights.
const COMMON_SHARE := 1.0 / 3.0


## Whether [param name] is a class on the ladder.
static func has(name: StringName) -> bool:
	return rank(name) >= 0


## **[param name]'s place on the ladder**: 0 for the commonest, one more for each
## class rarer; -1 for a name no row has.
static func rank(name: StringName) -> int:
	for k in LADDER.size():
		if LADDER[k]["class"] == name:
			return k
	return -1


## **The classes, commonest first.**
static func classes() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in LADDER:
		out.append(row["class"])
	return out


## The commonest class: the ladder's first row, the one [constant COMMON_SHARE] keeps.
static func commonest() -> StringName:
	return LADDER[0]["class"]


## **What [param name] weighs in the water's draw**; 0 for a name no row has, which
## the water then never draws.
static func weight(name: StringName) -> float:
	var at := rank(name)
	return float(LADDER[at]["weight"]) if at >= 0 else 0.0


## **The living carriers the floor keeps of a variety of class [param name]**; 0 for a
## name no row has, which the floor then never keeps.
static func least(name: StringName) -> int:
	var at := rank(name)
	return int(LADDER[at]["floor"]) if at >= 0 else 0


## **The rarer of [param a] and [param b]**: the one further down the ladder, and
## whichever is a class where the other is none; `&""` where neither is.
static func rarer(a: StringName, b: StringName) -> StringName:
	var ra := rank(a)
	var rb := rank(b)
	if ra < 0:
		return b if rb >= 0 else &""
	if rb < 0:
		return a
	return a if ra >= rb else b
