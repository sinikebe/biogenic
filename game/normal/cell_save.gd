extends RefCounted
## **A cell, kept** (docs/design/cells.md §1.1, §3.1): the file one of your cells
## lives in between two launches, apart from every world. It keeps everything a
## world kept for its cell -- **`DropSave.CELL`, exactly as a world kept it**, and
## checked by the same code -- and what is new: the view it was born in, its
## name, when its line was born and how long it has been played, and where it is.
##
## **The file**: one `store_var` of plain types through `open_compressed`, written
## to a `.tmp`, read back, compared and renamed over -- `DropSave.write`, called as
## it is -- so a phone killed mid-write keeps the last good cell.
##
## **What a cell is, this file does not know.** It holds no gene name and no view
## by meaning: a view is a name, compared with a name (run_state.gd's
## `CELL_KEYS`), and a cell is the Dictionary a world used to keep. normal_mode.gd
## decides when a cell is kept and what its place means; cells.gd keeps the slots.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const DropSave := preload("res://game/normal/drop_save.gd")

## **How the file is laid out**: this file's own, not a drop's. Bumped only when
## [constant SHAPE] changes.
const FORMAT := 1

## **What a file of this format holds**, key by key, and each value's type.
## `name` is the player's words, or "" while the cell wears its default,
## `default`; `born` is the unix second its line's first cell was born, 0 when
## nobody knows (a cell kept before there were slots); `where` is
## [constant WHERE], or `{}` for nowhere; `cell` is [constant DropSave.CELL]; and
## `died` is `{}` for a living cell and [constant DIED] for a record (owner's
## row 1). **`lived`**, the seconds its line has been played, is a float beside
## them when it is known, and absent when it is not ([constant LIVED]).
const SHAPE := {
	"format": TYPE_INT,
	"rules": TYPE_STRING,
	"content": TYPE_INT,
	"commit": TYPE_STRING,
	"view": TYPE_STRING,
	"name": TYPE_STRING,
	"default": TYPE_INT,
	"born": TYPE_INT,
	"where": TYPE_DICTIONARY,
	"cell": TYPE_DICTIONARY,
	"died": TYPE_DICTIONARY,
}
## **How long its line has been played**, in seconds: every second a cell of the
## line was alive in the water, across its divisions. Absent for a line whose age
## nobody knows, which no age is ever shown for.
const LIVED := "lived"

## **Where a cell is** (cells.md §1.4): the world's slot, from 1 -- 0 for a world
## kept in a file of a tool's own -- that drop's number, its rim's centre at the
## keep, and its age. The cell's `body.at` is in the frame of `rim`.
const WHERE := {
	"world": TYPE_INT,
	"drop": TYPE_INT,
	"rim": TYPE_VECTOR2,
	"age": TYPE_FLOAT,
}
## **A record** (cells.md §1.5): how the cell died, as food.gd's `Cause`, and the
## unix second it did.
const DIED := {
	"cause": TYPE_INT,
	"at": TYPE_INT,
}


## **A file's worth**, under this build's format, rules, content version and
## commit: [param cell] is a cell as a world kept one ([constant DropSave.CELL]),
## [param view] the view's name, [param named] the player's words or "",
## [param default] the default it wears, [param born] its line's first second,
## [param lived] its line's seconds -- below 0 for unknown, which writes none --
## [param where] its place, and [param died] `{}` or a record's [constant DIED].
static func compose(view: String, named: String, default: int, born: int, lived: float,
		where: Dictionary, cell: Dictionary, died: Dictionary = {}) -> Dictionary:
	var stamp := DropSave.build()
	var data := {
		"format": FORMAT,
		"rules": DropSave.rules(),
		"content": int(stamp[0]),
		"commit": str(stamp[1]),
		"view": view,
		"name": named,
		"default": default,
		"born": born,
		"where": where,
		"cell": cell,
		"died": died,
	}
	if lived >= 0.0 and is_finite(lived):
		data[LIVED] = lived
	return data


## **Keeps [param data] at [param path]**: `DropSave.write`, called as it is --
## a `.tmp` beside it, read back, compared and renamed over.
static func write(path: String, data: Dictionary) -> Error:
	return DropSave.write(path, data)


## **The cell kept at [param path]**, or an empty Dictionary: none there, or one
## this build cannot use. **One it cannot use is set aside** as `<path>.old`,
## over any older one, and said in the log: only a run that is about to play the
## slot calls this. A menu calls [method peek], which never moves a file.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = _decoded(path)
	var why := unusable(data)
	if why.is_empty():
		return data
	set_aside(path, why)
	return {}


## **What the file at [param path] holds, read and never moved**: the file as
## [method read] gives it, or an empty Dictionary for none and for one this build
## cannot use, which stays where it is. What every menu and tool reads a slot by.
static func peek(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = _decoded(path)
	return data if unusable(data).is_empty() else {}


## **[param path] set aside as `<path>.old`**, over any older one, because of
## [param why]; the log says so.
static func set_aside(path: String, why: String) -> void:
	var old := path + ".old"
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
	var moved := DirAccess.rename_absolute(path, old)
	print("[cell-save] %s is %s: kept as %s, and a new cell starts there" % [path, why,
		old if moved == OK else "nothing (%s)" % error_string(moved)])


## **Why [param data] cannot be used by this build**, or "" when it can: the
## format, then [constant SHAPE], then a known `lived`, `where` and `died`, then
## the cell -- [constant DropSave.CELL] and everything `DropSave.bad_cell` asks of
## a world's.
static func unusable(data: Variant) -> String:
	if not data is Dictionary:
		return "not a cell this build can read"
	var file := data as Dictionary
	if typeof(file.get("format")) != TYPE_INT:
		return "not a cell this build can read"
	if int(file["format"]) != FORMAT:
		return "format %d, which this build (format %d) does not know" % [
			int(file["format"]), FORMAT]
	var bad := DropSave.misfit(file, SHAPE)
	if bad.is_empty() and file.has(LIVED) and (typeof(file[LIVED]) != TYPE_FLOAT
			or not is_finite(float(file[LIVED])) or float(file[LIVED]) < 0.0):
		bad = "lived is not seconds"
	if bad.is_empty() and not (file["where"] as Dictionary).is_empty():
		bad = DropSave.misfit(file["where"], WHERE, "where.")
	if bad.is_empty() and not (file["died"] as Dictionary).is_empty():
		bad = DropSave.misfit(file["died"], DIED, "died.")
	if bad.is_empty():
		bad = DropSave.bad_cell(file["cell"], "cell.")
	return "" if bad.is_empty() else "format %d but unreadable (%s)" % [FORMAT, bad]


## Whether [param data] was written under other rules than this build's: a
## content pack changed what a body means since, and its cell is re-derived from
## its genome by name, as a world's is.
static func converted(data: Dictionary) -> bool:
	return str(data.get("rules", "")) != DropSave.rules()


## Whether [param data] is a record: a cell that died, kept until a new cell
## starts in its slot (cells.md §1.5).
static func is_record(data: Dictionary) -> bool:
	return not (data.get("died", {}) as Dictionary).is_empty()


## The one value the file at [param path] holds, or null when it would not open.
static func _decoded(path: String) -> Variant:
	var data: Variant = null
	var file := FileAccess.open_compressed(path, FileAccess.READ,
		FileAccess.COMPRESSION_ZSTD)
	if file != null:
		data = file.get_var()
		file.close()
	return data

