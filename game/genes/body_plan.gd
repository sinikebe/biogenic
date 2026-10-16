extends RefCounted
## **The body plan** (docs/design/gene-catalogue.md §10): every slot a body has, a
## row each -- where it is, what anatomy it is, the arc of skin it is, the radius
## a body earns it at and the organ it is the home of -- and the shape of the body
## those arcs are read off. The owner, 2026-10-04: *"we may change slot number,
## slot positions, slot types, etc. later. So we'd better make it easy to work on
## today than later."* **A plan change is an edit to [constant TODAY]**, and
## everything a slot decides follows it.
##
## **Derived from it, and written nowhere else** (§10.2): how many slots a radius
## earns ([method slots_for]); the fewest and the most outside slots
## ([member SLOT_MIN], [member SLOT_MAX]); where the inside starts and how much room
## it has ([member INSIDE], [member INSIDE_SLOTS]); the front and the stern
## ([member FRONT], [member STERN]); each slot's arc and bearing ([method arc],
## [method bearing]); the home seats ([method home_slot], [method home_layout]).
## `cell.gd`, `genome.gd`, `figure.gd` and `wire.gd` keep their own names for some
## of these, and read them again whenever the plan changes ([method listen]);
## `cilia.gd` holds this file's own lists, which are refilled in place; and
## `drop_save.gd` forgets the rules it wrote the ladder into.
##
## **Ids are code only, and permanent** (§10.1), as a gene's key is: the player
## sees arcs and never an id. A save stamps the plan it was kept under by its ids
## (§10.3, [method stamp]), and a slot that leaves the plan stays known here
## ([constant RETIRED]), so a gene kept in it still has somewhere near to go
## ([method migrate]).
##
## **Preloads nothing**: cell.gd, genome.gd, cilia.gd, figure.gd, wire.gd and
## drop_save.gd preload it, and a preload back would be the cycle cell.gd warns
## about. No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **The two places** (docs/design/dna-slots.md §2), by the names genome.gd and
## gene.gd give them: round the body, and in it.
const OUTSIDE_PLACE := &"outside"
const INSIDE_PLACE := &"inside"
## **What an outside slot is to the body** (§10.1): the front, which touches the
## mouth's own arc -- a toxin there acts through the bite; a side; and the stern,
## behind, the tail's. Anatomy, not a place (dna-slots.md §2.3).
const FRONT_ANATOMY := &"front"
const SIDE_ANATOMY := &"side"
const STERN_ANATOMY := &"stern"
## **Earned at any radius**: a drifter of r13 has every slot this marks, as
## `slots_for`'s clamp to the fewest gave it before there was a plan.
const ALWAYS := 0.0

# --- The body's shape (moved from cilia.gd, which reads it back) ----------------------
# An ovoid, narrower at the front: a slot's bearing is read off it, so it is the
# plan's. cilia.gd draws the body by these same three numbers.

const OVOID_ALONG := 1.18
const OVOID_ACROSS := 0.94
## How much narrower the nose is than the tail.
const OVOID_PINCH := 0.30

# --- Today's plan (§10.1) ---------------------------------------------------------------

## **Every slot, in index order**: the outside ones first, as they are earned --
## the three every body has, then one a rung of the ladder `26 + 3.5k` -- and the
## inside after them. A slot's index is where a genome's layout keeps it, and a
## save's stamp says which id each index was ([method stamp]).
##
## **Today's ladder is pinned at both ends**: three slots at birth (r26) and all
## seven at forty, `cell.gd`'s DIVIDE_RADIUS -- every arc a body has, which is why
## forty is where a body divides -- and four rungs between need a step in `(2.8,
## 3.5]`, of which 3.5 is the top. **Four-times growth left it as it was**: what it
## changed is that capacity stops binding in the first generation, and the arcs and
## the expression roll bind instead; from generation two a newborn is over capacity
## anyway (lifecycle.md §3.1), which is where the swap decision lives. A plan with
## other rows says its own ladder here.
##
## - `id`: the slot's name, code only and permanent;
## - `place`: [constant OUTSIDE_PLACE] or [constant INSIDE_PLACE];
## - `anatomy`, outside: [constant FRONT_ANATOMY], [constant SIDE_ANATOMY] or
##   [constant STERN_ANATOMY];
## - `arc`, outside: the skin it is, in ovoid parameter `t` degrees from the nose,
##   +90 starboard, 180 aft (§4.1 of genes-and-cilia.md). The cirrus's oars also
##   draw on the port side of theirs: that is the `oars` shape's, not the slot's;
## - `earned`: the radius a body earns it at, [constant ALWAYS] for every body;
## - `home`, where there is one: the gene a body is born wearing there, and which
##   a layout seats there first.
##
## The host's referee and the wire read what this derives: a change to the outside
## slots changes `Wire.ORDER_MAX` and `Wire.GENES_MAX` with it. **A build on another
## plan is on other rules**: [method fingerprint] is in the rules the handshake
## carries (gene-catalogue.md §11.3; game/net/rules.gd), so two builds on different
## plans refuse each other there, by themselves, and no `Wire.PROTOCOL` moves. Any
## change here moves `Wire.RULES`' pin, as `net_probe` says; a change of the slots'
## count fails its wire sizes too; and every change moves the gene probe's
## SHIPPED_PLAN and the pins beside it, as its failure says.
const TODAY: Array[Dictionary] = [
	{"id": &"nose", "place": OUTSIDE_PLACE, "anatomy": FRONT_ANATOMY,
		"arc": Vector2(-42.0, 42.0), "earned": ALWAYS, "home": &"cytostome"},
	{"id": &"starboard", "place": OUTSIDE_PLACE, "anatomy": SIDE_ANATOMY,
		"arc": Vector2(66.0, 118.0), "earned": ALWAYS, "home": &"cirrus"},
	{"id": &"tail", "place": OUTSIDE_PLACE, "anatomy": STERN_ANATOMY,
		"arc": Vector2(146.0, 214.0), "earned": ALWAYS, "home": &"flagellum"},
	{"id": &"fore_starboard", "place": OUTSIDE_PLACE, "anatomy": FRONT_ANATOMY,
		"arc": Vector2(42.0, 66.0), "earned": 29.5},
	{"id": &"fore_port", "place": OUTSIDE_PLACE, "anatomy": FRONT_ANATOMY,
		"arc": Vector2(-66.0, -42.0), "earned": 33.0},
	{"id": &"aft_starboard", "place": OUTSIDE_PLACE, "anatomy": SIDE_ANATOMY,
		"arc": Vector2(118.0, 146.0), "earned": 36.5},
	{"id": &"aft_port", "place": OUTSIDE_PLACE, "anatomy": SIDE_ANATOMY,
		"arc": Vector2(-146.0, -118.0), "earned": 40.0},
	{"id": &"inside", "place": INSIDE_PLACE, "earned": ALWAYS},
]
## **Slots that have left the plan**, each its last row, kept so a save that seated
## a gene in one knows where it was. None yet: a slot leaving [constant TODAY] moves
## here, and its id is never used again.
const RETIRED: Array[Dictionary] = []
## **The plan every save before the stamp was kept under** (§10.3): today's ids,
## written out, because [constant TODAY] may change and this may not. A save with
## no stamp reads as one kept under these.
const BEFORE_STAMPS: Array[String] = ["nose", "starboard", "tail", "fore_starboard",
	"fore_port", "aft_starboard", "aft_port", "inside"]

# --- Derived (§10.2) --------------------------------------------------------------------
# Every value here is worked out from the plan in use, by [method _read] -- when
# this script loads, and again when a tool swaps a plan in ([method use]). The
# arrays and dictionaries are refilled in place, so a reader that holds one stays
# right; a reader of a plain number re-reads it on [method listen].

## **The fewest outside slots a body has**: those earned at any radius.
static var SLOT_MIN := 0
## **The most outside slots a body has**: every one -- so the outside layout's
## longest, and where the inside starts.
static var SLOT_MAX := 0
## **The first inside slot's index**: every slot from here on is inside the body,
## and every slot before it is an arc of the skin.
static var INSIDE := 0
## **How much room the inside has**: its slots.
static var INSIDE_SLOTS := 0
## Every slot, outside and in.
static var SLOTS := 0
## **The front**: the outside slots whose anatomy is the front, in index order.
static var FRONT: Array[int] = []
## **The stern**: the outside slot behind, -1 for a plan with none.
static var STERN := -1
## **How many seats a layout's home organs take before anything else is seated**:
## one past the last home slot -- three today, the nose, the flank and the tail.
static var HOME_SEATS := 0

## The plan in use, and its retired slots.
static var _rows: Array[Dictionary] = []
static var _retired: Array[Dictionary] = []
## Id by index; index by id; every id known -- in use or retired -- to its row.
static var _ids: Array[StringName] = []
static var _index := {}
static var _known := {}
## The radius each outside slot is earned at, by index.
static var _earned := PackedFloat64Array()
## Each outside slot's arc and bearing, by index; and the arcs of the slots past
## the always ones, which an index out of the outside's range is given
## ([method arc]).
static var _arcs: Array[Vector2] = []
static var _bearings := PackedFloat64Array()
static var _free_arcs: Array[Vector2] = []
## Home gene to its slot; the home slots in index order, and their genes.
static var _homes := {}
static var _home_slots: Array[int] = []
static var _home_genes: Array[StringName] = []
## [method stamp], once per plan.
static var _stamp := PackedStringArray()
## [constant BEFORE_STAMPS] as a stamp is kept.
static var _before := PackedStringArray(BEFORE_STAMPS)
## The radii past the always ones, in index order: [method ladder]'s.
static var _rungs := PackedFloat64Array()
## Who reads the plan again when it changes ([method listen]).
static var _listeners: Array[Callable] = []


static func _static_init() -> void:
	_read(TODAY, RETIRED)


# --- The plan in use ----------------------------------------------------------------------

## **Every slot of the plan in use**, in index order: [constant TODAY], unless a
## tool has swapped a plan in. Read it; never write it.
static func rows() -> Array[Dictionary]:
	return _rows


## **The slots that have left the plan in use**, each its last row: [constant
## RETIRED], unless a tool has swapped a plan in. Read it; never write it.
static func retired() -> Array[Dictionary]:
	return _retired


## **A plan of a tool's own** (gene-catalogue.md §12.3): [param plan] in place of
## today's, with [param gone] the slots that have left it, and everything derived
## from it worked out again -- here and in every file that listens. As the
## catalogue's `register` lets a probe put a synthetic gene through every system,
## this lets one put a synthetic body plan through them. Nothing in the game calls
## it.
static func use(plan: Array, gone: Array = []) -> void:
	_read(plan, gone)
	for changed: Callable in _listeners:
		changed.call()


## **Today's plan again**, after [method use].
static func restore() -> void:
	use(TODAY, RETIRED)


## **[param changed] is called whenever the plan changes**: a file that keeps its
## own copy of a number derived here -- `CellBody.SLOT_MAX`, `Wire.ORDER_MAX` --
## reads it again there. Called once, from that file's `_static_init`.
static func listen(changed: Callable) -> void:
	_listeners.append(changed)


# --- Slots ----------------------------------------------------------------------------------

## **How many outside slots a body of [param radius] has earned**: every slot
## earned at that radius or below, and never fewer than [member SLOT_MIN] or more
## than [member SLOT_MAX]. A genome adds the gift's bonus on top (`genome.gd`).
static func slots_for(radius: float) -> int:
	var count := 0
	for earned: float in _earned:
		if earned <= radius:
			count += 1
	return clampi(count, SLOT_MIN, SLOT_MAX)


## **The arc of skin [param slot] is**, in ovoid `t` degrees. An index past the
## outside -- the inside, which has no arc, or a layout longer than the body --
## is given the last slot past the always ones, and a negative one the first, as
## every index has been since before there was a plan: nothing that faces out is
## ever drawn at no arc at all.
static func arc(slot: int) -> Vector2:
	if slot >= 0 and slot < SLOT_MIN:
		return _arcs[slot]
	if _free_arcs.is_empty():
		return _arcs[_arcs.size() - 1] if not _arcs.is_empty() else Vector2.ZERO
	return _free_arcs[clampi(slot - SLOT_MIN, 0, _free_arcs.size() - 1)]


## **The body-relative bearing an arc looks along**: radians clockwise from the
## front, which is the only way this game describes a direction. Read off the
## ovoid rather than the arc's own degrees, because the two are not the same
## number -- `t` runs faster than the bearing near the nose: the middle of the
## forward-starboard arc is `t` 54 and bearing 42.
static func arc_bearing(of: Vector2) -> float:
	var t := deg_to_rad((of.x + of.y) * 0.5)
	return atan2(sin(t) * (1.0 - OVOID_PINCH * cos(t)) * OVOID_ACROSS,
		cos(t) * OVOID_ALONG)


## **Where a gene in [param slot] points**: its arc's bearing, worked out once a
## plan.
static func bearing(slot: int) -> float:
	if slot >= 0 and slot < _bearings.size():
		return _bearings[slot]
	return arc_bearing(arc(slot))


## **The radius one more slot costs**, as the rules a drop is kept under have always
## said it (`drop_save.gd`'s `cell.SLOT_RADIUS`): the gap from one earned slot to the
## next, when the plan earns them on an even ladder, as today's does -- 3.5 -- and
## otherwise every radius a slot is earned at, in index order, so that a plan with an
## uneven ladder is never read as an even one.
static func ladder() -> Variant:
	if _rungs.size() < 2:
		return _rungs
	var step := _rungs[1] - _rungs[0]
	for k in range(2, _rungs.size()):
		if not is_equal_approx(_rungs[k] - _rungs[k - 1], step):
			return _rungs
	return step


## **[param slot]'s id**, `&""` for an index the plan has no slot at.
static func id_of(slot: int) -> StringName:
	return _ids[slot] if slot >= 0 and slot < _ids.size() else &""


## **The index of the slot [param id] is**, -1 for an id the plan in use has none
## of -- retired, or never one.
static func slot_of(id: StringName) -> int:
	return int(_index.get(id, -1))


## **The place [param slot] is in**: inside from [member INSIDE] on.
static func place_of(slot: int) -> StringName:
	return INSIDE_PLACE if slot >= INSIDE else OUTSIDE_PLACE


## **The anatomy of [param slot]**, `&""` for the inside and for no slot.
static func anatomy_of(slot: int) -> StringName:
	if slot < 0 or slot >= SLOT_MAX:
		return &""
	return StringName(_rows[slot].get("anatomy", &""))


## **The gene [param slot] is the home of**, `&""` for none.
static func home_of(slot: int) -> StringName:
	if slot < 0 or slot >= _rows.size():
		return &""
	return StringName(_rows[slot].get("home", &""))


## **The slot [param gene] is the home of**, -1 for a gene with none.
static func home_slot(gene: StringName) -> int:
	return int(_homes.get(gene, -1))


## **The home slots, in index order**: where a layout seats its home organs first.
## The plan's own list, refilled in place: read it; never write it.
static func home_slots() -> Array[int]:
	return _home_slots


## **The home organs, in the order of [method home_slots]**, refilled in place.
static func home_genes() -> Array[StringName]:
	return _home_genes


## **Home gene to its slot**: the plan's own dictionary, refilled in place, which
## cilia.gd holds and reads for every body it draws. Read it; never write it.
static func homes() -> Dictionary:
	return _homes


## **Every outside slot's arc, by index**: the plan's own list, refilled in place.
static func arcs() -> Array[Vector2]:
	return _arcs


## **A born body's layout** (`genome.gd`'s newborn): each of [param genes] in its
## home slot, the slots between them empty, and any gene with no home after them,
## in the order given. Today: the mouth, the cirrus and the tail, in slots 0 to 2.
static func home_layout(genes: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	var homeless: Array[StringName] = []
	for gene: Variant in genes:
		var at := home_slot(StringName(gene))
		if at < 0:
			homeless.append(StringName(gene))
			continue
		while out.size() <= at:
			out.append(&"")
		out[at] = StringName(gene)
	out.append_array(homeless)
	return out


# --- Saves (§10.3) ----------------------------------------------------------------------------

## **The plan's ids, by index**: what a save keeps beside every slot order it
## writes, so a later plan can put each gene back by id.
static func stamp() -> PackedStringArray:
	return _stamp


## **The ids a save was kept under**: its stamp, [param kept], or
## [constant BEFORE_STAMPS] for a save with none -- one kept before there was a
## stamp, under today's plan.
static func written(kept: Variant) -> PackedStringArray:
	return kept if kept is PackedStringArray else _before


## Whether [param kept] is a stamp a save may hold: slot ids, at least one. Every
## plan has a slot, so a stamp of none is no plan's and a file holding one has gone
## wrong; a save kept before stamps holds no key at all ([method written]).
static func is_stamp(kept: Variant) -> bool:
	return kept is PackedStringArray and not (kept as PackedStringArray).is_empty()


## **An outside layout kept under [param kept], laid out on the plan in use**
## (§10.3). Under the same plan it is [param order] itself, untouched. Otherwise
## each gene goes back to its slot's id; one whose id has left the plan -- or whose
## slot another gene already took -- goes to the free outside slot nearest the one
## it was in by bearing, and one whose id this build never knew, a later plan's,
## to the first free one; and with none free it is left out of the layout,
## **unseated and never dropped**: the DNA still carries it, and `genome.gd` seats
## it as it seats any gene a layout lacks. A gene kept at an inside slot is left out
## too, because the inside keeps no order: the DNA says what is inside. The layout
## is as long as it was, and longer only as far as a gene's new slot is.
static func migrate(order: Array, kept: PackedStringArray) -> Array:
	if kept == _stamp:
		return order
	var out: Array[StringName] = []
	out.resize(SLOT_MAX)
	var left: Array = []
	for i in order.size():
		var gene := StringName(order[i]) if order[i] != null else &""
		if gene == &"":
			continue
		var id := StringName(kept[i]) if i < kept.size() else &""
		if _was_inside(id):
			continue
		var at := slot_of(id)
		if at >= 0 and at < SLOT_MAX and out[at] == &"":
			out[at] = gene
		else:
			left.append([gene, _bearing_of(id)])
	for one: Array in left:
		var to := _nearest_free(out, float(one[1]))
		if to >= 0:
			out[to] = one[0]
	var length := maxi(order.size(), _last_seated(out) + 1)
	if length < out.size():
		out.resize(length)
	return out


## **This plan's fingerprint**: SHA-256 of every row and the body's shape, so two
## builds on different plans can tell (§10.4). The rules the handshake carries hold it
## (§11.3; game/net/rules.gd), and nothing else in the game reads it. **Written as the
## rules are**, by Godot alone: every number a whole number of millionths, never
## through `%f`, which is the C library's printf on each platform -- and
## `tools/net_probe.gd` writes it again from the rows and holds the two equal.
static func fingerprint() -> String:
	var lines := PackedStringArray()
	lines.append("shape=%s,%s,%s" % [_millionths(OVOID_ALONG), _millionths(OVOID_ACROSS),
		_millionths(OVOID_PINCH)])
	for row: Dictionary in _rows:
		var arc_of: Vector2 = row.get("arc", Vector2.ZERO)
		lines.append("%s|%s|%s|%s,%s|%s|%s" % [row["id"], row["place"],
			row.get("anatomy", &""), _millionths(arc_of.x), _millionths(arc_of.y),
			_millionths(float(row["earned"])), row.get("home", &"")])
	return "\n".join(lines).sha256_text()


## [param x] as a whole number of millionths, as the rules write a float.
static func _millionths(x: float) -> String:
	return str(roundi(x * 1e6))


# --- Working it out -------------------------------------------------------------------------

## Reads [param plan] and the slots [param gone] from it into everything above.
static func _read(plan: Array, gone: Array) -> void:
	_rows.clear()
	for row: Variant in plan:
		_rows.append(row as Dictionary)
	_retired.clear()
	for row: Variant in gone:
		_retired.append(row as Dictionary)
	_ids.clear()
	_index.clear()
	_known.clear()
	_earned.clear()
	_rungs.clear()
	_arcs.clear()
	_bearings.clear()
	_free_arcs.clear()
	_homes.clear()
	_home_slots.clear()
	_home_genes.clear()
	FRONT.clear()
	STERN = -1
	SLOT_MIN = 0
	SLOT_MAX = 0
	INSIDE_SLOTS = 0
	HOME_SEATS = 0
	for row: Dictionary in _retired:
		_known[StringName(row["id"])] = row
	for slot in _rows.size():
		var row: Dictionary = _rows[slot]
		var id := StringName(row["id"])
		_ids.append(id)
		_index[id] = slot
		_known[id] = row
		var home := StringName(row.get("home", &""))
		if home != &"":
			_homes[home] = slot
			_home_slots.append(slot)
			_home_genes.append(home)
			HOME_SEATS = slot + 1
		if StringName(row["place"]) == INSIDE_PLACE:
			INSIDE_SLOTS += 1
			continue
		SLOT_MAX += 1
		var earned := float(row["earned"])
		_earned.append(earned)
		if earned <= ALWAYS:
			SLOT_MIN += 1
		else:
			_rungs.append(earned)
		var arc_of: Vector2 = row["arc"]
		_arcs.append(arc_of)
		_bearings.append(arc_bearing(arc_of))
		match StringName(row.get("anatomy", &"")):
			FRONT_ANATOMY:
				FRONT.append(slot)
			STERN_ANATOMY:
				if STERN < 0:
					STERN = slot
	INSIDE = SLOT_MAX
	SLOTS = _rows.size()
	for slot in range(SLOT_MIN, SLOT_MAX):
		_free_arcs.append(_arcs[slot])
	_stamp = PackedStringArray()
	for id: StringName in _ids:
		_stamp.append(String(id))


## The bearing of the slot [param id] was, in use or retired; NAN for an id this
## build never knew, or one with no arc.
static func _bearing_of(id: StringName) -> float:
	var row: Variant = _known.get(id)
	if row == null or not (row as Dictionary).has("arc"):
		return NAN
	return arc_bearing((row as Dictionary)["arc"])


## Whether [param id] is a slot inside the body, in use or retired.
static func _was_inside(id: StringName) -> bool:
	var row: Variant = _known.get(id)
	return row != null and StringName((row as Dictionary)["place"]) == INSIDE_PLACE


## The free outside slot of [param layout] nearest [param from] by bearing -- the
## first free one for a bearing nobody knows -- or -1.
static func _nearest_free(layout: Array[StringName], from: float) -> int:
	var best := -1
	var best_off := INF
	for slot in mini(layout.size(), _bearings.size()):
		if layout[slot] != &"":
			continue
		if is_nan(from):
			return slot
		var off := absf(angle_difference(from, _bearings[slot]))
		if off < best_off:
			best_off = off
			best = slot
	return best


## The last index of [param layout] that holds a gene, -1 for none.
static func _last_seated(layout: Array[StringName]) -> int:
	for slot in range(layout.size() - 1, -1, -1):
		if layout[slot] != &"":
			return slot
	return -1
