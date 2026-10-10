extends RefCounted
## **A drop, kept** (docs/design/ocean.md §9): the file a drop lives in between
## two launches, and what a build does with one that another build wrote. A
## personal drop and a room are the same file (§9.1, §10.3). **A world keeps only
## its water** (docs/design/cells.md §3.3): your cells have files of their own
## (cell_save.gd), and `cell` is written `{}`. A file a build before them wrote
## may still hold its cells -- **one for each view** (ocean.md §9.5), `cell` and
## [constant CELLS] -- which this still reads, checks and composes, for the
## migration that moves them into slots (cells.gd) and for the run that has to
## carry one it could not move.
##
## **The file** (§9.3): one `store_var` of plain types -- Dictionaries, Arrays
## and Packed arrays, never an object -- through `open_compressed`, written to a
## `.tmp` beside it, read back and compared, and only then renamed over it. A
## phone killed mid-write keeps the last good drop, and a full disk never
## passes for a save: `close()` does not report a lost write (invites-ux.md §2),
## so the read-back is the only proof a write landed.
##
## **Against content packs** (§9.4). `format` is how the file is laid out, and
## moves only when that does: a format this build does not know -- or a file it
## cannot read at all -- is not read. It is moved aside as `.old`, once, and
## the drop starts fresh. `rules` is a fingerprint of what the drop's bodies
## mean, written the way `Wire.RULES` is; a different one converts the drop
## rather than discarding it, and says so in the log. The content version and
## the commit that wrote it are for the log alone.
##
## **What a drop is, this file does not know.** food.gd gathers the drop and
## puts it back (`drop_state`, `load_drop`), the cell and its genome their own
## (`body_state`, `to_state`), and normal_mode.gd decides when. This is the layout,
## the file and the versioning -- and the one place that says what a file of
## this format holds, so a file that does not hold it is set aside instead of
## half-loaded into a run.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const CellBody := preload("res://game/normal/cell.gd")
const Genome := preload("res://game/normal/genome.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")
const Drop := preload("res://game/normal/drop.gd")
## The genes (docs/design/gene-catalogue.md): what [method rules_text] lists of
## them, the order and every table any organ provides.
const Catalogue := preload("res://game/genes/catalogue.gd")
## The body plan (gene-catalogue.md §10): the slot ladder [method rules_text]
## lists, under the names it had when it was `cell.gd`'s.
const BodyPlan := preload("res://game/genes/body_plan.gd")
const Stats := preload("res://game/genes/stats.gd")

## **How the file is laid out.** Bumped only when [constant SHAPE] changes; a
## content pack that changes a number changes [method rules] instead.
const FORMAT := 1

## **Your first drop** (§9.1): the one every device had before there were three,
## and slot 1 of game/normal/drops.gd, which keeps the other two beside it. The
## dev app has its own package id and so its own `user://`: the owner's drops
## there never touch a player's.
const PATH := "user://drop.save"

## **What a file of this format holds**, key by key, and each value's type. A
## nested Dictionary is a Dictionary that must hold its own keys; `cell` is
## checked against [constant CELL] unless it is empty -- a drop left after a
## death, or by nobody, has no cell in it (§9.2). `cell` is the cell of the
## first view, the one every file kept before there was a cell per view; every
## other view's is in [constant CELLS], beside it.
##
## `drop.bodies` is **one column a field**, every column one entry a body, in
## slot order: a Packed array compresses a column of clocks that are mostly
## zero to almost nothing, where a row a body would not. `kind` is bit 0 for no
## mouth -- a drifter -- and bit 1 for a floc. A genome is a Dictionary from
## gene **name** to tier, never an index, so a retired gene loads as a name this
## build does not know, kept and inert (§9.2). `clocks` are the spawner's, the
## gene floor's, the drifter floor's and the shore's; `made_for` whom its water
## is made for when nobody is in it, a radius and a sight a player (§10.3).
## `rim_radius` is the rim it was kept under, for the record: a load makes the
## drop at this build's `RADIUS` round `rim_centre`, and a body past a smaller
## rim is put back inside it (§9.4).
const SHAPE := {
	"format": TYPE_INT,
	"rules": TYPE_STRING,
	"content": TYPE_INT,
	"commit": TYPE_STRING,
	"drop": {
		"seed": TYPE_INT,
		"age": TYPE_FLOAT,
		"frame": TYPE_INT,
		"next_id": TYPE_INT,
		"rim_centre": TYPE_VECTOR2,
		"rim_radius": TYPE_FLOAT,
		"debt": TYPE_FLOAT,
		"widest": TYPE_FLOAT,
		"clocks": TYPE_PACKED_FLOAT64_ARRAY,
		"made_for": TYPE_PACKED_FLOAT64_ARRAY,
		"slots": TYPE_INT,
		"free": TYPE_PACKED_INT32_ARRAY,
		"bodies": {
			"slot": TYPE_PACKED_INT32_ARRAY,
			"id": TYPE_PACKED_INT32_ARRAY,
			"parent": TYPE_PACKED_INT32_ARRAY,
			"kind": TYPE_PACKED_BYTE_ARRAY,
			"meals": TYPE_PACKED_INT32_ARRAY,
			"at": TYPE_PACKED_VECTOR2_ARRAY,
			"heading": TYPE_PACKED_FLOAT64_ARRAY,
			"radius": TYPE_PACKED_FLOAT64_ARRAY,
			"wound": TYPE_PACKED_FLOAT64_ARRAY,
			"age": TYPE_PACKED_FLOAT64_ARRAY,
			"last_t": TYPE_PACKED_FLOAT64_ARRAY,
			"hunger": TYPE_PACKED_FLOAT64_ARRAY,
			"starve": TYPE_PACKED_FLOAT64_ARRAY,
			"effort": TYPE_PACKED_FLOAT64_ARRAY,
			"bite": TYPE_PACKED_FLOAT64_ARRAY,
			"dart": TYPE_PACKED_FLOAT64_ARRAY,
			"dash": TYPE_PACKED_FLOAT64_ARRAY,
			"dash_v": TYPE_PACKED_FLOAT64_ARRAY,
			"settle": TYPE_PACKED_FLOAT64_ARRAY,
			"life": TYPE_PACKED_FLOAT64_ARRAY,
			"genome": TYPE_ARRAY,
		},
	},
	"cell": TYPE_DICTIONARY,
}

## **The cell left mid-run** (row 17): its body -- place, heading, motion, size,
## wound and the clocks of its tail and dash -- its genome by gene name, both
## registers and the queue, its tank, its generation, what the run has told it,
## the two daughters its division had rolled if it was left choosing (each as
## [constant DAUGHTER]; none before the pinch), and the water's part of it: its
## grace, the clocks of its dart and its bite, and the authored first drifter it
## had not met yet. What a guest's cell already carries across the wire, and a
## little more. **And, when it is there, `elsewhere`** (1b-2): true for a cell
## left while it swam in a friend's drop (ocean.md §9.1), whose place is not in
## this one -- it comes back into this drop at a quiet place, as a guest does
## that leaves the pond. **And `fed`** (pack 4, docs/design/automation.md §9.2):
## the seconds since it last ate, for its instincts, absent for one that never
## has. Your programs are not here: they are the device's (`library.gd`). **And
## `genome.plan`** (docs/design/gene-catalogue.md §10.3): the body plan's slot ids
## its two layouts are kept under, absent from a file kept before there was one.
##
## **This is every view's cell** ([constant CELLS]): what a view keeps is the
## same whichever view it is.
const CELL := {
	"body": {
		"at": TYPE_VECTOR2,
		"heading": TYPE_FLOAT,
		"velocity": TYPE_VECTOR2,
		"radius": TYPE_FLOAT,
		"wound": TYPE_FLOAT,
		"omega": TYPE_FLOAT,
		"wander": TYPE_FLOAT,
		"impulse": TYPE_FLOAT,
		"dash": TYPE_FLOAT,
		"effort": TYPE_FLOAT,
	},
	"genome": {
		"dna": TYPE_DICTIONARY,
		"order": TYPE_PACKED_STRING_ARRAY,
		"body": TYPE_DICTIONARY,
		"worn": TYPE_PACKED_STRING_ARRAY,
		"bonus": TYPE_INT,
		"gift": TYPE_STRING,
		"waiting": TYPE_ARRAY,
		"levels": TYPE_DICTIONARY,
	},
	"hunger": TYPE_FLOAT,
	"starve": TYPE_FLOAT,
	"generation": TYPE_INT,
	"sense_clock": TYPE_FLOAT,
	"sensed": TYPE_BOOL,
	"said_divide": TYPE_BOOL,
	"daughters": TYPE_ARRAY,
	"water": {
		"grace": TYPE_FLOAT,
		"dart": TYPE_FLOAT,
		"bite": TYPE_FLOAT,
		"first": TYPE_INT,
	},
}

## **Every other view's cell** (ocean.md §9.5): beside `cell`, a file may hold
## `cells`, a Dictionary from a view's name to that view's cell -- each as
## [constant CELL] says, and checked as `cell` is. A world keeps one cell for
## each view, and never plays one in another: `cell` is the first view's, the
## only one a file held before there were more, and every other view's is here,
## under the name the views are kept by (run_state.gd's `CELL_KEYS`, where the
## views are named; this file knows none). A view with no cell -- never played
## in, or its last cell dead -- is not in it, and a file with no other view's
## cell has no `cells` at all: it is laid out as one written before them, which
## every build reads. **No new format**, as `cell.loads` was none: a build before
## them loads `cell` and never asks for `cells` -- and keeps only `cell` the next
## time it writes.
const CELLS := "cells"

## **What a file of this format may also hold** (1b-2 on), and a file without
## them loads as 1b-1's did -- every body drifting, the floor counted again, the
## grid filed by place -- so no drop kept before them is set aside. With them, a
## drop goes on exactly as one that never stopped (ocean.md §14.3 check 12):
## `runs`, one entry a body in the order of `bodies` -- its run's state, whom at
## by id (-1 nobody, -2 the player), its three switches, `RUN_CLOCKS` clocks
## and two points -- the genes the floor is short of, the grid as `[ids,
## buckets]`, the census's counts and whose turn it is. Each is checked as
## [constant SHAPE] is when it is there: one that does not hold what it says
## makes the file unreadable, never half-loaded. **And, since the floor took turns
## within a budget** (docs/design/gene-rarity.md §3.3), its queue and its budget:
## `gene_queue`, every gene the floor found short at its last count in the order it
## gives them back -- `gene_short` is those due and not given yet, in the same order; a
## peer-borne one the one-a-count rule holds back is in `gene_queue` alone -- and
## `gene_since`, the drifters made since the floor's last. A file without them
## loads with its short genes queued in the order kept and the budget full; a build
## before them reads `gene_short` alone, as it always has.
const RUNS := {
	"state": TYPE_PACKED_BYTE_ARRAY,
	"target": TYPE_PACKED_INT64_ARRAY,
	"flags": TYPE_PACKED_BYTE_ARRAY,
	"clocks": TYPE_PACKED_FLOAT64_ARRAY,
	"points": TYPE_PACKED_VECTOR2_ARRAY,
}
const EXTRA := {
	"gene_short": TYPE_PACKED_STRING_ARRAY,
	"gene_queue": TYPE_PACKED_STRING_ARRAY,
	"gene_since": TYPE_INT,
	"grid": TYPE_ARRAY,
	"stats": TYPE_DICTIONARY,
	"turn": TYPE_INT,
}
## A run's clocks, a body's worth: food.gd's RUN_CLOCKS.
const RUN_CLOCKS := 10

## **What `drop.bodies` may also hold** (pack 2, docs/design/lineage.md §4):
## every body's lineage, a column a field like the rest -- its generation, the
## founder its line began with, its newborn grace, and its DNA, a genome by gene
## name or empty where the DNA is the body. **And what `cell` may hold**: the
## cell's own record, its id, its mother's and its line's. A file without them
## loads as one written before pack 2 -- every body a founder, generation 1, its
## own line, its DNA its body and no grace -- and a pack-1 build reading one
## with them loads the rest, as it never asks for them. Each is checked as
## [constant SHAPE] is when it is there, and every column one entry a body.
##
## `grace` is a clock, so it is kept as every clock here is, in 64 bits: a
## countdown kept in 32 comes back a few millionths off, and a grace that ends
## a frame early or late is a drop that does not go on as it was kept.
const LINEAGE := {
	"generation": TYPE_PACKED_INT32_ARRAY,
	"lineage": TYPE_PACKED_INT32_ARRAY,
	"grace": TYPE_PACKED_FLOAT64_ARRAY,
	"dna": TYPE_ARRAY,
}
const CELL_LINEAGE := {
	"id": TYPE_INT,
	"parent": TYPE_INT,
	"lineage": TYPE_INT,
}

## **What `drop.bodies` may also hold** (pack 3, docs/design/behaviour.md §8):
## every body's rules and what they had it doing, a column a field like the
## rest. `behaviour` is -1 for the founders' rules -- a drifter's, a floc's and
## every body's still on them -- and otherwise which list of `drop.behaviours`
## it carries, so a family's shared list is kept once. Then the heading it steers
## for; what its rules claimed (`acts`: bit 0 a heading held, bit 1 a rest, bit 2
## a swim, and since pack 4 bit 3 a held tail, which a pack-3 build ignores --
## docs/design/automation.md §9.2) and its push's strength; the random turn it
## holds -- the rule that drew it and the tick that rule last fired on, -1 for
## none; its stun; when it last ate, on the drop's clock, -INF for never -- its
## `fed` is `age` less this,
## kept as the time it happened so a round trip is exact; a hit it has not yet
## felt, and the direction it came from; when it calls next; its echoes in
## flight, [constant ECHO_NUMBERS] numbers each -- when it lands, where it came
## off, its distance, its size and when it rings out; and what its rules last
## read, input name to `[tick, reports]`, each report its numbers. Clocks in 64
## bits, as every clock here is.
##
## A file without them is pack 2's, and loads every hunter on the founders'
## rules, resting on as it was (food.gd's `load_drop`); a pack-2 build reading
## one with them loads the rest and runs its own hunter. Each is checked as
## [constant SHAPE] is when it is there, and every column one entry a body.
const BEHAVIOUR := {
	"behaviour": TYPE_PACKED_INT32_ARRAY,
	"steer": TYPE_PACKED_FLOAT64_ARRAY,
	"acts": TYPE_PACKED_BYTE_ARRAY,
	"push": TYPE_PACKED_FLOAT64_ARRAY,
	"tumble": TYPE_PACKED_INT32_ARRAY,
	"tumble_tick": TYPE_PACKED_INT64_ARRAY,
	"stun": TYPE_PACKED_FLOAT64_ARRAY,
	"ate": TYPE_PACKED_FLOAT64_ARRAY,
	"hit": TYPE_PACKED_FLOAT64_ARRAY,
	"hit_from": TYPE_PACKED_FLOAT64_ARRAY,
	"call": TYPE_PACKED_FLOAT64_ARRAY,
	"echoes": TYPE_ARRAY,
	"memory": TYPE_ARRAY,
}
## A kept echo's numbers: when it lands, where it came off (two), its distance,
## its size and when it rings out.
const ECHO_NUMBERS := 6
## **What `drop.bodies` may also hold** (the toxin's doses, docs/design/
## dna-slots.md §12): every body's loads, a column a kind -- stacks of harm,
## paralysis and sleep, in 64 bits, because they wear down like the clocks kept
## here -- so a dose survives the app being closed mid-fight. **And `cell.loads`**,
## the cell's own three, the same way. Absent means none: a file from before
## loads every body carrying nothing, and a build before them loads the rest, as
## it does pack 2's columns. Each is checked when it is there, every column one
## entry a body and every entry a finite count of stacks, none below nothing.
const DOSES := {
	"harm": TYPE_PACKED_FLOAT64_ARRAY,
	"paralysis": TYPE_PACKED_FLOAT64_ARRAY,
	"sleep": TYPE_PACKED_FLOAT64_ARRAY,
}
## The kinds a cell's `loads` holds: doses.gd's three.
const LOADS := 3
## **The lists those bodies carry** (`drop.behaviours`, §8): `{"version": 1,
## "lists": [...]}`, each list its rules' lines as behaviour.md §5.1 writes them,
## by declared name -- so a name this build does not know is kept, a rule that
## never fires, and written back as it came. Under a version this build does not
## know, the lists are not read, and every body loads on the founders' rules.
const BEHAVIOURS := {
	"version": TYPE_INT,
	"lists": TYPE_ARRAY,
}
const BEHAVIOURS_VERSION := 1

## One of the two daughters a division offers, by gene name: the DNA she is
## made of, its layout, the body that expressed, and the mutation that made her
## -- empty for the faithful one. **And, since the body plan, `plan`**: the slot
## ids her layout is kept under (gene-catalogue.md §10.3), checked when it is
## there, as the genome's is ([method bad_cell]).
const DAUGHTER := {
	"tiers": TYPE_DICTIONARY,
	"order": TYPE_PACKED_STRING_ARRAY,
	"body": TYPE_DICTIONARY,
	"mutation": TYPE_STRING,
}

## Far more slots than a drop ever holds -- about 600 bodies and flocs, the
## slots as many as there have been at once -- so a count past it is a file gone
## wrong, not a drop, and is not allocated.
const SLOTS_MAX := 1 << 16

## [method rules], worked out once a process: the constants cannot change under it,
## and the body plan changes only when a tool swaps one in -- which forgets it
## ([method _read_plan]).
static var _rules := ""


static func _static_init() -> void:
	BodyPlan.listen(_read_plan)


## **Another plan means other rules**: the slot ladder is in [method rules_text], so
## a plan a tool swaps in is worked out again on the next [method rules].
static func _read_plan() -> void:
	_rules = ""


# --- What the bodies mean (§9.4) ---------------------------------------------------

## **The fingerprint of what a drop's bodies mean**: SHA-256 of
## [method rules_text]. A save carries the one it was written under; a load under
## another converts the drop and logs it.
static func rules() -> String:
	if _rules.is_empty():
		_rules = rules_text().sha256_text()
	return _rules


## **Every value a body is read by**, one a line, where it is defined, written
## the way `tools/net_probe.gd` writes the lines `Wire.RULES` fingerprints: the
## gene list and the tiers, **every table any gene provides** -- found by stat,
## so a table added later is in it without anyone remembering, each under the
## name it had when it was `cell.gd`'s (stats.gd's `label`) -- the slot ladder,
## growth and division, the metabolism every body runs, and the rim.
static func rules_text() -> String:
	var lines := PackedStringArray()
	var put := func(name: String, value: Variant) -> void:
		lines.append("%s=%s" % [name, _rule_value(value)])
	put.call("genome.GENE_ORDER", Catalogue.live())
	put.call("genome.TIER_MAX", Genome.TIER_MAX)
	put.call("genome.UPKEEP_PER_TIER", Genome.UPKEEP_PER_TIER)
	# One line a provider, sorted by label: a stat's first provider under the
	# stat's own label, any other after it with its key, so two providers of one
	# stat are two lines. **Every label a String before anything is sorted**:
	# Godot orders two StringNames by where they happen to sit in memory, not by
	# name, and sorted as they came the same tables would fingerprint differently
	# from one process to the next, and a launch could read its own drop as
	# converted.
	var cell := {}
	var constants: Dictionary = (CellBody as Script).get_script_constant_map()
	for key: Variant in constants:
		cell[String(key)] = constants[key]
	var tables := {}
	for stat: StringName in Stats.ROWS:
		var providers := Catalogue.providers(stat)
		for k in providers.size():
			var label := Stats.label(stat) + ("" if k == 0 else "." + String(providers[k]))
			tables[label] = Catalogue.table(providers[k], stat)
	# And any table by tier cell.gd still has of its own, found by name as every
	# one used to be: none today, and one added there later is in it without anyone
	# remembering.
	for name: String in cell:
		if name.ends_with("_BY_TIER") and not tables.has("cell." + name):
			tables["cell." + name] = cell[name]
	var labels: Array = tables.keys()
	labels.sort()
	for label: String in labels:
		put.call(label, tables[label])
	# **The slot ladder is the body plan's** (gene-catalogue.md §10.2), written
	# under the names it had as `cell.gd`'s constants, so today's plan writes the
	# lines it always did: `cell.SLOT_RADIUS` the radius one more slot costs --
	# 3.5, or every rung for a plan whose ladder is not even -- and the fewest and
	# the most slots outside.
	cell["SLOT_RADIUS"] = BodyPlan.ladder()
	cell["SLOT_MIN"] = BodyPlan.SLOT_MIN
	cell["SLOT_MAX"] = BodyPlan.SLOT_MAX
	for name: String in ["BASE_RADIUS", "SLOT_RADIUS", "SLOT_MIN", "SLOT_MAX",
			"GROWTH_PER_MEAL", "DIVIDE_RADIUS", "STROKE_COST", "TURN_COST"]:
		put.call("cell." + name, cell[name])
	put.call("metabolism.HUNGER_SECONDS", Metabolism.HUNGER_SECONDS)
	put.call("metabolism.STARVE_GRACE", Metabolism.STARVE_GRACE)
	put.call("metabolism.MEAL", Metabolism.MEAL)
	put.call("metabolism.ABSORB", Metabolism.ABSORB)
	put.call("drop.RADIUS", Drop.RADIUS)
	return "\n".join(lines)


## One value, written the same way on every machine: six places for a float, a
## list comma-joined, a dictionary by its keys in order. `net_probe.gd`'s
## `_rule_value`, so the two fingerprints read alike.
static func _rule_value(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return "%.6f" % float(value)
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
				TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			var parts: PackedStringArray = []
			for each: Variant in value:
				parts.append(_rule_value(each))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = (value as Dictionary).keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var parts: PackedStringArray = []
			for key: Variant in keys:
				parts.append("%s:%s" % [str(key), _rule_value(value[key])])
			return "{" + ",".join(parts) + "}"
	return str(value)


# --- The file (§9.3) ----------------------------------------------------------------

## **A file's worth**: [param drop] as food.gd's `drop_state` gives it, under
## this build's format, rules, content version and commit, **with no cell in it**
## (cells.md §3.3): `cell` is `{}` and there is no [constant CELLS]. [param cells]
## is for the one case that still writes some -- **cells a migration could not
## move yet** (§4), a view's name to its cell, the first view's under "", which a
## run carries aside and writes back so that nothing is lost.
static func compose(drop: Dictionary, cells: Dictionary = {}) -> Dictionary:
	var stamp := build()
	var data := {
		"format": FORMAT,
		"rules": rules(),
		"content": int(stamp[0]),
		"commit": str(stamp[1]),
		"drop": drop,
		"cell": cells.get("", {}),
	}
	var others := {}
	for view: String in cells:
		if not view.is_empty() and not (cells[view] as Dictionary).is_empty():
			others[view] = cells[view]
	if not others.is_empty():
		data[CELLS] = others
	return data


## **[param view]'s cell in [param data]** -- a file as [method read] gives it,
## the first view's for "" -- or an empty Dictionary for none.
static func cell_of(data: Dictionary, view: String) -> Dictionary:
	if view.is_empty():
		return data.get("cell", {})
	var others: Dictionary = data.get(CELLS, {})
	return others.get(view, {})


## **Every cell [param data] keeps, by view**: the first view's under "", and
## only the views that left one.
static func cells_of(data: Dictionary) -> Dictionary:
	var out := {}
	var first: Dictionary = data.get("cell", {})
	if not first.is_empty():
		out[""] = first
	var others: Dictionary = data.get(CELLS, {})
	for view: String in others:
		if not (others[view] as Dictionary).is_empty():
			out[view] = others[view]
	return out


## **Keeps [param data] at [param path]** (§9.3): written to the `.tmp` beside
## it, read back and compared with what was meant, and renamed over it only
## then. Returns OK, or why the last good file was left where it was.
static func write(path: String, data: Dictionary) -> Error:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	var tmp := path.get_basename() + ".tmp"
	var meant := var_to_bytes(data)
	var out := FileAccess.open_compressed(tmp, FileAccess.WRITE,
		FileAccess.COMPRESSION_ZSTD)
	if out == null:
		return FileAccess.get_open_error()
	out.store_var(data)
	out.close()
	var back := FileAccess.open_compressed(tmp, FileAccess.READ,
		FileAccess.COMPRESSION_ZSTD)
	if back == null:
		return ERR_FILE_CANT_READ
	var got: Variant = back.get_var()
	back.close()
	if var_to_bytes(got) != meant:
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(tmp, path)


## **The drop kept at [param path]**, or an empty Dictionary: none there, or
## one this build cannot use. **One it cannot use is not read** (§9.4) -- a
## format it does not know, a file it cannot decode, one that does not hold what
## its format says -- and is moved aside as `<path>.old`, over any older one:
## kept, once, and never read again, while the caller starts a fresh drop. Said
## in the log either way.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = _decoded(path)
	var why := unusable(data)
	if why.is_empty():
		return data
	var old := path + ".old"
	var moved := DirAccess.rename_absolute(path, old)
	print("[drop-save] %s is %s: kept as %s, and a new drop is made" % [path, why,
		old if moved == OK else "nothing (%s)" % error_string(moved)])
	return {}


## **What the drop at [param path] would say about itself, read and never
## moved** (docs/design/settings.md §6.3): `{lived, seed, generations}` -- the
## drop's age in seconds, its number, and the generation of each cell a build
## before cells.md left in it, by view, a view that left none not in it -- or an
## empty Dictionary for none, and for one this build cannot use. Decoded and
## checked as [method read] does, but **a file it cannot use stays where it is**:
## only a run that is about to play a drop may set its file aside, and the drop
## menu, which asks this of a drop its index does not name, is not one.
## It costs a whole decode -- 2 ms on a desktop for a drop of 600 bodies, more on
## a phone -- so it is asked only of a file the index does not name, or whose
## number it does not hold, and the index keeps the answer from its next write on.
static func peek(path: String) -> Dictionary:
	var data := look(path)
	if data.is_empty():
		return {}
	var drop: Dictionary = data["drop"]
	var generations := {}
	var cells := cells_of(data)
	for view: String in cells:
		generations[view] = int(cells[view]["generation"])
	return {"lived": float(drop["age"]), "seed": int(drop["seed"]),
		"generations": generations}


## **The drop at [param path], read and never moved**: the file as [method read]
## gives it, or an empty Dictionary for none and for one this build cannot use,
## which stays where it is. What the chooser's migration reads a world by
## (cells.md §4): it is no run, and only a run about to play a drop sets a file
## aside.
static func look(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = _decoded(path)
	return data if unusable(data).is_empty() else {}


## The one value the file at [param path] holds, or null when it would not open.
static func _decoded(path: String) -> Variant:
	var data: Variant = null
	var file := FileAccess.open_compressed(path, FileAccess.READ,
		FileAccess.COMPRESSION_ZSTD)
	if file != null:
		data = file.get_var()
		file.close()
	return data


## **Why [param data] cannot be loaded by this build**, or "" when it can: the
## format, then [constant SHAPE], then what a type cannot say -- every column as
## long as the others, every slot inside the count and used once, every genome
## a gene name to a tier -- and every view's cell, `cell` and [constant CELLS]
## alike.
static func unusable(data: Variant) -> String:
	if not data is Dictionary:
		return "not a drop this build can read"
	var file := data as Dictionary
	if typeof(file.get("format")) != TYPE_INT:
		return "not a drop this build can read"
	if int(file["format"]) != FORMAT:
		return "format %d, which this build (format %d) does not know" % [
			int(file["format"]), FORMAT]
	var bad := misfit(file, SHAPE)
	if bad.is_empty() and not (file["cell"] as Dictionary).is_empty():
		bad = misfit(file["cell"], CELL, "cell.")
	if bad.is_empty():
		bad = _bad_bodies(file["drop"])
	if bad.is_empty():
		bad = _bad_extra(file["drop"])
	if bad.is_empty() and not (file["cell"] as Dictionary).is_empty():
		bad = bad_cell(file["cell"], "cell.")
	if bad.is_empty():
		bad = _bad_cells(file)
	return "" if bad.is_empty() else "format %d but unreadable (%s)" % [FORMAT, bad]


## What a cell per view added, when it is there ([constant CELLS]): a Dictionary
## from a view's name -- never "", which is `cell` -- to a cell, each checked as
## `cell` is, and an empty one taken for none.
static func _bad_cells(file: Dictionary) -> String:
	if not file.has(CELLS):
		return ""
	if not file[CELLS] is Dictionary:
		return "cells is not a dictionary"
	var cells: Dictionary = file[CELLS]
	for view: Variant in cells:
		if typeof(view) != TYPE_STRING or (view as String).is_empty():
			return "cells holds a view that is not a name"
		if not cells[view] is Dictionary:
			return "cells.%s is not a cell" % view
		var cell: Dictionary = cells[view]
		if cell.is_empty():
			continue
		var bad := bad_cell(cell, "cells.%s." % view)
		if not bad.is_empty():
			return bad
	return ""


## The first key of [param shape] that [param value] does not hold as the type
## it says, by its path; "" when every one is. cell_save.gd checks its own file
## with it too.
static func misfit(value: Dictionary, shape: Dictionary, at := "") -> String:
	for key: String in shape:
		if not value.has(key):
			return at + key + " missing"
		var want: Variant = shape[key]
		if want is Dictionary:
			if not value[key] is Dictionary:
				return at + key + " is not a dictionary"
			var inner := misfit(value[key], want, at + key + ".")
			if not inner.is_empty():
				return inner
		elif typeof(value[key]) != int(want):
			return at + key + " is the wrong type"
	return ""


static func _bad_bodies(drop: Dictionary) -> String:
	var slots := int(drop["slots"])
	var bodies: Dictionary = drop["bodies"]
	var slot: PackedInt32Array = bodies["slot"]
	var n := slot.size()
	if slots < n or slots > SLOTS_MAX:
		return "drop.slots %d for %d bodies" % [slots, n]
	# The columns this format names, whatever else a file carries.
	for key: String in SHAPE["drop"]["bodies"]:
		var entries: int = bodies[key].size()
		if entries != n:
			return "drop.bodies.%s has %d entries for %d bodies" % [key, entries, n]
	var used := {}
	for i: int in slot:
		if i < 0 or i >= slots or used.has(i):
			return "drop.bodies.slot %d twice or out of the drop" % i
		used[i] = true
	for genome: Variant in bodies["genome"]:
		if not _is_genes(genome):
			return "a body's genome is not gene names to tiers"
	if (drop["clocks"] as PackedFloat64Array).size() != 4:
		return "drop.clocks is not four clocks"
	var bad := _bad_lineage(bodies, n)
	if bad.is_empty():
		bad = _bad_behaviour(drop, bodies, n)
	if bad.is_empty():
		bad = _bad_doses(bodies, n)
	return bad


## What the toxin's doses added, when it is there: each column the type it says,
## one entry a body, and every entry a finite count of stacks, none below nothing.
static func _bad_doses(bodies: Dictionary, n: int) -> String:
	for key: String in DOSES:
		if not bodies.has(key):
			continue
		if typeof(bodies[key]) != int(DOSES[key]):
			return "drop.bodies.%s is the wrong type" % key
		var column: PackedFloat64Array = bodies[key]
		if column.size() != n:
			return "drop.bodies.%s has %d entries for %d bodies" % [key, column.size(), n]
		if not _are_stacks(column):
			return "drop.bodies.%s is not stacks" % key
	return ""


## Whether every entry of [param column] is a finite count of stacks, none
## below nothing.
static func _are_stacks(column: PackedFloat64Array) -> bool:
	for stacks: float in column:
		if not is_finite(stacks) or stacks < 0.0:
			return false
	return true


## What pack 2 added to the bodies, when it is there: each column the type it
## says and one entry a body, and every DNA gene names to copies -- or empty,
## the body's own.
static func _bad_lineage(bodies: Dictionary, n: int) -> String:
	for key: String in LINEAGE:
		if not bodies.has(key):
			continue
		if typeof(bodies[key]) != int(LINEAGE[key]):
			return "drop.bodies.%s is the wrong type" % key
		var entries: int = bodies[key].size()
		if entries != n:
			return "drop.bodies.%s has %d entries for %d bodies" % [key, entries, n]
	if bodies.has("dna"):
		for dna: Variant in bodies["dna"]:
			if not _is_genes(dna):
				return "a body's DNA is not gene names to copies"
	return ""


## What pack 3 added, when it is there: the lists, each its lines, under a
## version this build reads; and each column the type it says, one entry a body,
## every body's list one the drop keeps, its echoes whole and its memory input
## names to a tick and reports of numbers.
static func _bad_behaviour(drop: Dictionary, bodies: Dictionary, n: int) -> String:
	var lists := 0
	var unread := false
	if drop.has("behaviours"):
		if not drop["behaviours"] is Dictionary:
			return "drop.behaviours is not a dictionary"
		var kept: Dictionary = drop["behaviours"]
		var bad := misfit(kept, BEHAVIOURS, "drop.behaviours.")
		if not bad.is_empty():
			return bad
		unread = int(kept["version"]) != BEHAVIOURS_VERSION
		if not unread:
			for list: Variant in kept["lists"]:
				if typeof(list) != TYPE_PACKED_STRING_ARRAY:
					return "drop.behaviours.lists is not lists of rules"
			lists = (kept["lists"] as Array).size()
	for key: String in BEHAVIOUR:
		if not bodies.has(key):
			continue
		if typeof(bodies[key]) != int(BEHAVIOUR[key]):
			return "drop.bodies.%s is the wrong type" % key
		var entries: int = bodies[key].size()
		if entries != n:
			return "drop.bodies.%s has %d entries for %d bodies" % [key, entries, n]
	if bodies.has("behaviour") and not unread:
		for index: int in bodies["behaviour"]:
			if index < -1 or index >= lists:
				return "drop.bodies.behaviour %d is not a list the drop keeps" % index
	if bodies.has("echoes"):
		for echoes: Variant in bodies["echoes"]:
			if typeof(echoes) != TYPE_PACKED_FLOAT64_ARRAY \
					or (echoes as PackedFloat64Array).size() % ECHO_NUMBERS != 0:
				return "a body's echoes are not echoes"
	if bodies.has("memory"):
		for memory: Variant in bodies["memory"]:
			if not _is_memory(memory):
				return "a body's memory is not input names to what they read"
	return ""


## Whether [param value] is a body's memory as the file keeps it: input names to
## `[tick, reports]`, each report its numbers.
static func _is_memory(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for input: Variant in value:
		var read: Variant = value[input]
		if typeof(input) != TYPE_STRING or not read is Array or (read as Array).size() != 2 \
				or typeof(read[0]) != TYPE_INT or not read[1] is Array:
			return false
		for report: Variant in read[1]:
			if typeof(report) != TYPE_PACKED_FLOAT64_ARRAY:
				return false
	return true


## What 1b-2 added, when it is there: every part the type it says, and the runs
## one entry a body.
static func _bad_extra(drop: Dictionary) -> String:
	var n: int = (drop["bodies"]["slot"] as PackedInt32Array).size()
	for key: String in EXTRA:
		if drop.has(key) and typeof(drop[key]) != int(EXTRA[key]):
			return "drop.%s is the wrong type" % key
	if drop.has("runs"):
		if not drop["runs"] is Dictionary:
			return "drop.runs is not a dictionary"
		var runs: Dictionary = drop["runs"]
		var bad := misfit(runs, RUNS, "drop.runs.")
		if not bad.is_empty():
			return bad
		if (runs["state"] as PackedByteArray).size() != n \
				or (runs["target"] as PackedInt64Array).size() != n \
				or (runs["flags"] as PackedByteArray).size() != n \
				or (runs["clocks"] as PackedFloat64Array).size() != n * RUN_CLOCKS \
				or (runs["points"] as PackedVector2Array).size() != n * 2:
			return "drop.runs is not one run a body"
	if drop.has("grid"):
		var grid: Array = drop["grid"]
		if grid.size() != 2 or typeof(grid[0]) != TYPE_PACKED_INT32_ARRAY \
				or typeof(grid[1]) != TYPE_PACKED_INT32_ARRAY \
				or (grid[0] as PackedInt32Array).size() != (grid[1] as PackedInt32Array).size():
			return "drop.grid is not ids and their buckets"
	if drop.has("stats"):
		for what: Variant in drop["stats"]:
			if typeof(what) != TYPE_STRING or typeof(drop["stats"][what]) != TYPE_INT:
				return "drop.stats is not names to counts"
	return ""


## **Why [param cell] is not a cell this build can load**, or "" when it is:
## [constant CELL], key by key, then what a type cannot say -- `elsewhere`, `fed`,
## the record, the loads, two daughters by gene name, a genome of gene names to
## tiers, its waiting genes and its levels. A world's `cell` and [constant CELLS]
## are checked with it, and so is a slot's (cell_save.gd), so a cell is one thing
## wherever it is kept. [param at] is where it sits, for the reason given.
static func bad_cell(cell: Dictionary, at := "cell.") -> String:
	var bad := misfit(cell, CELL, at)
	if not bad.is_empty():
		return bad
	if cell.has("elsewhere") and typeof(cell["elsewhere"]) != TYPE_BOOL:
		return at + "elsewhere is the wrong type"
	# **Seconds since the cell last ate** (docs/design/automation.md §9.2), for its
	# instincts' `fed`: since pack 4's programs, and absent for a cell that never
	# ate. A build before them loads the rest and never asks.
	if cell.has("fed") and (typeof(cell["fed"]) != TYPE_FLOAT or not is_finite(float(cell["fed"]))):
		return at + "fed is not seconds"
	for key: String in CELL_LINEAGE:
		if cell.has(key) and typeof(cell[key]) != int(CELL_LINEAGE[key]):
			return at + "%s is the wrong type" % key
	# **The cell's own loads** (the toxin's doses): three counts of stacks.
	if cell.has("loads") and (typeof(cell["loads"]) != TYPE_PACKED_FLOAT64_ARRAY
			or (cell["loads"] as PackedFloat64Array).size() != LOADS
			or not _are_stacks(cell["loads"])):
		return at + "loads is not three counts of stacks"
	var pair: Array = cell["daughters"]
	if not pair.is_empty() and pair.size() != 2:
		return at + "daughters is not two daughters"
	for one: Variant in pair:
		if not one is Dictionary or not misfit(one, DAUGHTER).is_empty() \
				or not _is_genes(one["tiers"]) or not _is_genes(one["body"]) \
				or (one.has("plan") and not BodyPlan.is_stamp(one["plan"])):
			return at + "daughters is not two daughters by gene name"
	var genome: Dictionary = cell["genome"]
	if not _is_genes(genome["dna"]) or not _is_genes(genome["body"]):
		return at + "genome is not gene names to tiers"
	# **The body plan's slot ids, beside every layout** (gene-catalogue.md §10.3),
	# the genome's and each daughter's: absent from a file kept before them, which
	# was kept under today's plan. A build before them never asks -- a shape is
	# checked key by key, and a key it does not name is not looked at.
	if genome.has("plan") and not BodyPlan.is_stamp(genome["plan"]):
		return at + "genome.plan is not slot ids"
	for one: Variant in genome["waiting"]:
		if not one is Array or (one as Array).size() != 3 \
				or typeof(one[0]) != TYPE_STRING or typeof(one[1]) != TYPE_INT \
				or typeof(one[2]) != TYPE_FLOAT:
			return at + "genome.waiting is not gene, copies and seconds"
	var levels: Dictionary = genome["levels"]
	for gene: Variant in levels:
		var level: Variant = levels[gene]
		if typeof(gene) != TYPE_STRING or not level is Array \
				or (level as Array).size() != 2 or typeof(level[0]) != TYPE_FLOAT \
				or typeof(level[1]) != TYPE_STRING:
			return at + "genome.levels is not gene names to experience and path"
	return ""


## Whether [param value] is a genome as the file keeps one: gene names to tiers.
static func _is_genes(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for gene: Variant in value:
		if typeof(gene) != TYPE_STRING or typeof(value[gene]) != TYPE_INT:
			return false
	return true


# --- The log (§9.4) -----------------------------------------------------------------

## **Whether [param data] was written under other rules than this build's**: a
## content pack changed what its bodies mean since, and the load converts it.
static func converted(data: Dictionary) -> bool:
	return str(data.get("rules", "")) != rules()


## **What a load says in the log**, so a tester can tell a converted drop from a
## resumed one: the drop's age and bodies, the cells a build before cells.md
## still keeps in it -- none once they are in slots (cells.md §4) -- and under
## other rules what the conversion did: [param done] is what food.gd's
## `load_drop` returns. Content and commit are the build that wrote it. **Your
## cell is cells.gd's to say**: it is no longer in this file.
static func note(data: Dictionary, done: Dictionary) -> String:
	var drop: Dictionary = data["drop"]
	var kept := cells_of(data).size()
	var line := "[drop-save] your drop, %d bodies, %.0f s old%s" % [
		int(done.get("bodies", 0)), float(drop["age"]),
		"" if kept == 0 else (", a cell from before the slots still in it" if kept == 1
			else ", %d cells from before the slots still in it" % kept)]
	if not converted(data):
		return line + ", as you left it"
	return line + (", CONVERTED: written by content %d (%s) under rules %s, read under %s;"
		+ " every body re-derived from its genome, %d trimmed to r%.0f, %d put back inside"
		+ " the rim") % [int(data["content"]), str(data["commit"]),
		str(data["rules"]).left(12), rules().left(12), int(done.get("trimmed", 0)),
		CellBody.DIVIDE_RADIUS, int(done.get("contained", 0))]


## `[content version, commit]` of this build, from the launcher's BuildInfo --
## `[0, ""]` with none to ask, as in a tool's run. cell_save.gd stamps a cell
## with it too.
static func build() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var info: Node = tree.root.get_node_or_null(^"BuildInfo") if tree != null else null
	if info == null:
		return [0, ""]
	return [int(info.get("content_version")), str(info.get("commit"))]
