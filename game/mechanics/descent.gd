extends RefCounted
## **A record of descent** (docs/design/lineage.md §4, §9): who a body is, whose
## it is, how many births it is from the first of its line, and which first --
## `[id, parent, generation, lineage]`, four ints in a PackedInt32Array. A body
## made from nothing is a **founder**: nobody's, generation 1, its own id its
## lineage. A body born of another is that record's **child**: an id of its own,
## the other's id as its parent, one generation more, and the same lineage. So a
## lineage is the id of the founder a body descends from, and a family is every
## body that shares one.
##
## **And where a body splits** into two that touch: the two points either side
## of where it was, across an axis.
##
## **Nothing here knows what descends.** An id is whatever the caller counts --
## the drop's are unique for the drop's life -- and a radius is a number. Cells,
## genes and the water are named by the callers (game/normal/food.gd,
## game/normal/normal_mode.gd).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## Where each of the four sits in a record.
const ID := 0
const PARENT := 1
const GENERATION := 2
const LINEAGE := 3
## How many ints a record is.
const SIZE := 4
## A founder's parent: nobody.
const NOBODY := 0


## **A founder**: the first of its line, so [param id] is its lineage too.
static func founder(id: int) -> PackedInt32Array:
	return PackedInt32Array([id, NOBODY, 1, id])


## **A child of [param parent]**, numbered [param id]: the parent's id, its
## generation and one, and its lineage. Given no record to descend from -- an
## empty one, or one that is not four ints -- the record starts again, and the
## child is a founder.
static func child(id: int, parent: PackedInt32Array) -> PackedInt32Array:
	if parent.size() != SIZE:
		return founder(id)
	return PackedInt32Array([id, parent[ID], parent[GENERATION] + 1, parent[LINEAGE]])


## A record from its four ints, for a caller that keeps them apart.
static func of(id: int, parent: int, generation: int, lineage: int) -> PackedInt32Array:
	return PackedInt32Array([id, parent, generation, lineage])


## **The two points a body splits into**: either side of [param at] along
## [param axis], each [param r] from it -- so two bodies of radius [param r]
## there touch at [param at], side by side. [param axis] is a direction and is
## normalised here; a zero one is taken as +x. Keeping the two inside anything
## is the caller's.
static func split(at: Vector2, axis: Vector2, r: float) -> PackedVector2Array:
	var across := axis.normalized() if axis.length_squared() > 0.0 else Vector2.RIGHT
	return PackedVector2Array([at + across * r, at - across * r])
