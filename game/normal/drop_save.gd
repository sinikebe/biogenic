extends RefCounted
## **A drop, kept** (docs/design/ocean.md §9): the file a drop lives in between
## two launches, and what a build does with one that another build wrote. A
## personal drop and a room are the same file (§9.1, §10.3) -- a drop, and the
## cell of whoever left it mid-run, if anyone did.
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

## **How the file is laid out.** Bumped only when [constant SHAPE] changes; a
## content pack that changes a number changes [method rules] instead.
const FORMAT := 1

## **Your drop: one per device** (§9.1). The dev app has its own package id and
## so its own `user://`: the owner's drop there never touches a player's.
const PATH := "user://drop.save"

## **What a file of this format holds**, key by key, and each value's type. A
## nested Dictionary is a Dictionary that must hold its own keys; `cell` is
## checked against [constant CELL] unless it is empty -- a drop left after a
## death, or by nobody, has no cell in it (§9.2).
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
## that leaves the pond.
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

## **What a file of this format may also hold** (1b-2 on), and a file without
## them loads as 1b-1's did -- every body drifting, the floor counted again, the
## grid filed by place -- so no drop kept before them is set aside. With them, a
## drop goes on exactly as one that never stopped (ocean.md §14.3 check 12):
## `runs`, one entry a body in the order of `bodies` -- its run's state, whom at
## by id (-1 nobody, -2 the player), its three switches, `RUN_CLOCKS` clocks
## and two points -- the genes the floor is short of, the grid as `[ids,
## buckets]`, the census's counts and whose turn it is. Each is checked as
## [constant SHAPE] is when it is there: one that does not hold what it says
## makes the file unreadable, never half-loaded.
const RUNS := {
	"state": TYPE_PACKED_BYTE_ARRAY,
	"target": TYPE_PACKED_INT64_ARRAY,
	"flags": TYPE_PACKED_BYTE_ARRAY,
	"clocks": TYPE_PACKED_FLOAT64_ARRAY,
	"points": TYPE_PACKED_VECTOR2_ARRAY,
}
const EXTRA := {
	"gene_short": TYPE_PACKED_STRING_ARRAY,
	"grid": TYPE_ARRAY,
	"stats": TYPE_DICTIONARY,
	"turn": TYPE_INT,
}
## A run's clocks, a body's worth: food.gd's RUN_CLOCKS.
const RUN_CLOCKS := 10

## One of the two daughters a division offers, by gene name: the DNA she is
## made of, its layout, the body that expressed, and the mutation that made her
## -- empty for the faithful one.
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

## [method rules], worked out once a process: the constants cannot change under it.
static var _rules := ""


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
## gene list and the tiers, **every tier table cell.gd has** -- found by name, so
## a table added later is in it without anyone remembering -- the slot ladder,
## growth and division, the metabolism every body runs, and the rim.
static func rules_text() -> String:
	var lines := PackedStringArray()
	var put := func(name: String, value: Variant) -> void:
		lines.append("%s=%s" % [name, _rule_value(value)])
	put.call("genome.GENE_ORDER", Genome.GENE_ORDER)
	put.call("genome.TIER_MAX", Genome.TIER_MAX)
	put.call("genome.UPKEEP_PER_TIER", Genome.UPKEEP_PER_TIER)
	# **Every name a String before anything is sorted.** The map's keys are
	# StringNames, and Godot orders two StringNames by where they happen to sit
	# in memory, not by name: sorted as they came, the same constants
	# fingerprinted differently from one process to the next, and a launch could
	# have read its own drop as converted.
	var cell := {}
	var constants: Dictionary = (CellBody as Script).get_script_constant_map()
	for key: Variant in constants:
		cell[String(key)] = constants[key]
	var tables: Array = cell.keys().filter(
		func(name: String) -> bool: return name.ends_with("_BY_TIER"))
	tables.sort()
	for name: String in tables:
		put.call("cell." + name, cell[name])
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

## **A file's worth**: [param drop] as food.gd's `drop_state` gives it, and
## [param cell] -- empty after a death, or with nobody in it -- under this
## build's format, rules, content version and commit.
static func compose(drop: Dictionary, cell: Dictionary) -> Dictionary:
	var build := _build()
	return {
		"format": FORMAT,
		"rules": rules(),
		"content": int(build[0]),
		"commit": str(build[1]),
		"drop": drop,
		"cell": cell,
	}


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
	var data: Variant = null
	var file := FileAccess.open_compressed(path, FileAccess.READ,
		FileAccess.COMPRESSION_ZSTD)
	if file != null:
		data = file.get_var()
		file.close()
	var why := unusable(data)
	if why.is_empty():
		return data
	var old := path + ".old"
	var moved := DirAccess.rename_absolute(path, old)
	print("[drop-save] %s is %s: kept as %s, and a new drop is made" % [path, why,
		old if moved == OK else "nothing (%s)" % error_string(moved)])
	return {}


## **Why [param data] cannot be loaded by this build**, or "" when it can: the
## format, then [constant SHAPE], then what a type cannot say -- every column as
## long as the others, every slot inside the count and used once, every genome
## a gene name to a tier.
static func unusable(data: Variant) -> String:
	if not data is Dictionary:
		return "not a drop this build can read"
	var file := data as Dictionary
	if typeof(file.get("format")) != TYPE_INT:
		return "not a drop this build can read"
	if int(file["format"]) != FORMAT:
		return "format %d, which this build (format %d) does not know" % [
			int(file["format"]), FORMAT]
	var bad := _misfit(file, SHAPE)
	if bad.is_empty() and not (file["cell"] as Dictionary).is_empty():
		bad = _misfit(file["cell"], CELL, "cell.")
	if bad.is_empty():
		bad = _bad_bodies(file["drop"])
	if bad.is_empty():
		bad = _bad_extra(file["drop"])
	if bad.is_empty() and not (file["cell"] as Dictionary).is_empty():
		bad = _bad_cell(file["cell"])
	return "" if bad.is_empty() else "format %d but unreadable (%s)" % [FORMAT, bad]


## The first key of [param shape] that [param value] does not hold as the type
## it says, by its path; "" when every one is.
static func _misfit(value: Dictionary, shape: Dictionary, at := "") -> String:
	for key: String in shape:
		if not value.has(key):
			return at + key + " missing"
		var want: Variant = shape[key]
		if want is Dictionary:
			if not value[key] is Dictionary:
				return at + key + " is not a dictionary"
			var inner := _misfit(value[key], want, at + key + ".")
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
	return ""


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
		var bad := _misfit(runs, RUNS, "drop.runs.")
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


static func _bad_cell(cell: Dictionary) -> String:
	if cell.has("elsewhere") and typeof(cell["elsewhere"]) != TYPE_BOOL:
		return "cell.elsewhere is the wrong type"
	var pair: Array = cell["daughters"]
	if not pair.is_empty() and pair.size() != 2:
		return "cell.daughters is not two daughters"
	for one: Variant in pair:
		if not one is Dictionary or not _misfit(one, DAUGHTER).is_empty() \
				or not _is_genes(one["tiers"]) or not _is_genes(one["body"]):
			return "cell.daughters is not two daughters by gene name"
	var genome: Dictionary = cell["genome"]
	if not _is_genes(genome["dna"]) or not _is_genes(genome["body"]):
		return "cell.genome is not gene names to tiers"
	for one: Variant in genome["waiting"]:
		if not one is Array or (one as Array).size() != 3 \
				or typeof(one[0]) != TYPE_STRING or typeof(one[1]) != TYPE_INT \
				or typeof(one[2]) != TYPE_FLOAT:
			return "cell.genome.waiting is not gene, copies and seconds"
	var levels: Dictionary = genome["levels"]
	for gene: Variant in levels:
		var level: Variant = levels[gene]
		if typeof(gene) != TYPE_STRING or not level is Array \
				or (level as Array).size() != 2 or typeof(level[0]) != TYPE_FLOAT \
				or typeof(level[1]) != TYPE_STRING:
			return "cell.genome.levels is not gene names to experience and path"
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
## resumed one: the drop's age and bodies, whether a cell came back with it, and
## under other rules what the conversion did -- [param done] is what food.gd's
## `load_drop` returns. Content and commit are the build that wrote it.
static func note(data: Dictionary, done: Dictionary) -> String:
	var drop: Dictionary = data["drop"]
	var line := "[drop-save] your drop, %d bodies, %.0f s old, %s" % [
		int(done.get("bodies", 0)), float(drop["age"]),
		"and your cell in it" if not (data["cell"] as Dictionary).is_empty()
			else "and a new cell"]
	if not converted(data):
		return line + ", as you left it"
	return line + (", CONVERTED: written by content %d (%s) under rules %s, read under %s;"
		+ " every body re-derived from its genome, %d trimmed to r%.0f, %d put back inside"
		+ " the rim") % [int(data["content"]), str(data["commit"]),
		str(data["rules"]).left(12), rules().left(12), int(done.get("trimmed", 0)),
		CellBody.DIVIDE_RADIUS, int(done.get("contained", 0))]


## `[content version, commit]` of this build, from the launcher's BuildInfo --
## `[0, ""]` with none to ask, as in a tool's run.
static func _build() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var info: Node = tree.root.get_node_or_null(^"BuildInfo") if tree != null else null
	if info == null:
		return [0, ""]
	return [int(info.get("content_version")), str(info.get("commit"))]
