extends RefCounted
## **The families** (docs/design/gene-looks.md §1, §7; the owner's row 2 of
## gene-catalogue.md §1): *colour shows the family, shape shows the organ, the pause
## screen names the exact gene.* Every organ's file names its family, and its hue is
## one of that family's three shades -- never a colour of its own. A family is a
## colour **and a build** (`kinds`, the shapes it may be drawn as), so a player who
## cannot see the colour still sees the family: the movers beat, the senses stand
## still over a pigment, the defences are armed or plated, metabolism sits inside
## the skin, the mouth is a mat.
##
## **Data only**, so the catalogue validates a look without preloading a view
## (gene-catalogue.md §4.1). It preloads nothing of the game but the kinds, which
## preload nothing. Family names never reach the screen: a gene's own word already
## says its family, and the colour is the mark (gene-looks.md §1.1, §4).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Kinds := preload("res://game/genes/kinds.gd")

## The five, by the names an organ's file gives them. `metabolism` and not `inside`:
## `inside` is the slot only a toxin goes in, and on screen (the owner, 2026-10-05).
const EATING := &"eating"
const MOVING := &"moving"
const SENSING := &"sensing"
const DEFENDING := &"defending"
const METABOLISM := &"metabolism"

## **The shade an organ takes where its look names none** (gene-looks.md §1.4): the
## middle of three.
const DEFAULT_SHADE := 1

## **Each family: its three shades and the kinds it is built as** (gene-looks.md
## §1.3, §7). The shades of one family share a lightness and a chroma and step in
## OKLCH hue, so a shade never reads as a tier -- two of them are about one
## just-noticeable difference apart, a whisper for where two organs of one family
## meet side by side (the beam's and the ping's lobes, the flood), never an
## identity. Measured on these very colours, and held by the gene probe: every band
## at least 20 degrees of OKLCH hue from every other, at least 30 from self teal and
## threat red, no family but eating within 30 of food green, and any two families
## at least 0.04 apart in lightness -- moving 0.10 lighter than sensing, the pair
## colour blindness merges. HSV hue, as `cilia.gd`'s comments wrote hues, beside each.
##
## - **eating** keeps the mouth's green (78 to 97; the mouth is shade 2, two degrees
##   off the 95 it wore): the mouth *is* nutrition. The band reaches toward yellow
##   and never toward food green.
## - **moving** is sky blue (198 to 207) and **sensing** violet (249 to 268): the two
##   every cell wears.
## - **defending** is orange (26 to 35), the colour of warning; 33 degrees of OKLCH
##   from threat red, and lighter.
## - **metabolism** is gold (47 to 56), told from eating by its build: bodies inside
##   the skin against a mat at the nose.
##
## Free for a sixth family: rose, OKLCH 324 to 348 (HSV about 315 to 340), the only
## band left that keeps 20 degrees from sensing and 30 from red.
const FAMILIES := {
	EATING: {"shades": [Color(0.75, 0.97, 0.22), Color(0.69, 0.99, 0.31),
		Color(0.63, 1.00, 0.40)], "kinds": [Kinds.MAT]},
	MOVING: {"shades": [Color(0.33, 0.79, 0.98), Color(0.41, 0.78, 0.99),
		Color(0.48, 0.76, 0.99)], "kinds": [Kinds.OARS, Kinds.LASH, Kinds.COIL]},
	SENSING: {"shades": [Color(0.60, 0.53, 0.99), Color(0.65, 0.50, 0.98),
		Color(0.70, 0.48, 0.95)], "kinds": [Kinds.TUFT, Kinds.LENS]},
	DEFENDING: {"shades": [Color(1.00, 0.52, 0.16), Color(0.98, 0.54, 0.04),
		Color(0.94, 0.57, 0.05)], "kinds": [Kinds.SPINES, Kinds.PLATES]},
	METABOLISM: {"shades": [Color(0.97, 0.80, 0.18), Color(0.93, 0.82, 0.20),
		Color(0.89, 0.84, 0.23)], "kinds": [Kinds.ORGANELLE]},
}


## Whether [param family] is one of [constant FAMILIES].
static func has(family: StringName) -> bool:
	return FAMILIES.has(family)


## **[param family]'s shade [param index]**, 0 to 2; transparent black for a family
## there is not, or a shade it has not, which the gene probe fails.
static func shade(family: StringName, index: int = DEFAULT_SHADE) -> Color:
	var row: Variant = FAMILIES.get(family)
	if row == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var shades: Array = (row as Dictionary)["shades"]
	if index < 0 or index >= shades.size():
		return Color(0.0, 0.0, 0.0, 0.0)
	return shades[index]


## Whether [param family] is built as [param kind] (gene-looks.md §1.2).
static func allows(family: StringName, kind: StringName) -> bool:
	var row: Variant = FAMILIES.get(family)
	return row != null and ((row as Dictionary)["kinds"] as Array).has(kind)
