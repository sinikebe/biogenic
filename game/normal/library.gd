extends RefCounted
## **Your library of programs** (docs/design/automation.md §3, §9.1): the
## player's programs, in the player's order, each with a name, its instincts as
## lines and a switch -- and the one list the programs that are on make, merged
## in that order, which is what the autopilot runs and what a sister carries.
##
## **What it knows**: programs with names, lines and switches; their order, which
## is the priority; [constant LIBRARY_MOST] programs; the eight instincts in all
## that the programs that are on share (row 39, [constant MOST]); the merged list
## and which program each of its rules came from; the file. **What it does not
## know**: how a list is read or changed (`rulebook.gd`'s), the cell, a division
## -- no division ever writes here (row 40) -- or a screen.
##
## **One library for the whole device** (§3.5), outliving every death and shared
## by every world. A run opens it from [constant PATH] unless a tool says
## otherwise (`normal_mode.gd`'s `library_at`), and writes it when the pause
## screen closes with a change, and only then.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Rulebook := preload("res://game/mechanics/rulebook.gd")
const Drop := preload("res://game/normal/drop.gd")

## **The most programs a library holds** (§3.2): one page of rows, as a program
## is one page of instincts.
const LIBRARY_MOST := 8
## **The most instincts the programs that are on hold between them** (row 39):
## a water cell's, so what your cell runs is what a water cell can run, and your
## sister takes exactly that into the water.
const MOST := Drop.MOST_RULES
## **The file** (§9.1): beside the worlds' index, the player's and no world's.
const PATH := "user://library.save"
## The file's layout. A file under another is not read: it is set aside once.
const VERSION := 1
## As long as a world's name may be, and cleaned the same way (`drops.gd`).
const NAME_MAX := 20
## **The defaults a program can wear**, by kind: a new one is `program 2`, a copy
## of the water's own is `water cell`, then `water cell 2` (automation-ux.md §2.5).
const NEW := "program"
const WATER := "water"

## TRANSLATORS: The automatic name of a program the player made and has not
## named: "program 2". A "program" is a list of the cell's "instincts" (rules the
## player writes); %d is the lowest number no other program uses. Lowercase.
## ROOM: 234 px at 15 px with 99
const NEW_NAME := "program %d"
## TRANSLATORS: The automatic name of a copy of the program the water's own cells
## are born with: "water cell". Lowercase.
## ROOM: 234 px at 15 px
const WATER_NAME := "water cell"
## TRANSLATORS: A name with a number after it, for a second copy of something:
## "water cell 2", "flee 2". %s is the name, %d the lowest number not in use.
## ROOM: 234 px at 15 px with water cell 9, 99
const NUMBERED := "%s %d"

## **One program** (§3.2): a name and the default it wears while that is "", its
## instincts as lines -- by declared name, as a list's file writes them, so a name
## this build does not know is kept and written back as it came -- and its
## switch.
class Program:
	## As typed; "" while it wears its default.
	var name := ""
	## The default it wears: `[kind, number]`, [constant NEW] or [constant WATER].
	var auto: Array = []
	var lines := PackedStringArray()
	var on := false


## The programs, in order: the first is the one whose instincts win.
var programs: Array[Program] = []
## **Bumped by every change**, so whoever keeps something made from the library
## -- the merged list, a page -- knows when to make it again.
var revision := 0
## Whether anything changed since the file was last written or read.
var dirty := false

## The merged list, and the revision and vocabulary it was made for.
var _merged: Rulebook.Behaviour = null
var _merged_at := -1
var _merged_vocab: Rulebook.Vocabulary = null
## Each program's lines read once, by the same three.
var _lists: Array = []


# --- Reading it ------------------------------------------------------------------

func size() -> int:
	return programs.size()


## **How many of the eight the programs that are on take** (row 39).
func taken() -> int:
	var n := 0
	for one: Program in programs:
		if one.on:
			n += one.lines.size()
	return n


## How many of the eight are free.
func room() -> int:
	return MOST - taken()


## **Whether program [param i] could be switched on now**: it is on already, or
## its instincts fit in the places free.
func fits(i: int) -> bool:
	var one := programs[i]
	return one.on or one.lines.size() <= room()


## **Whether there is anything to run** (§2.2): the programs that are on hold at
## least one instinct between them. What the autopilot's icon is there for.
func runnable() -> bool:
	return taken() > 0


## Whether any program is on.
func any_on() -> bool:
	for one: Program in programs:
		if one.on:
			return true
	return false


## **The programs that are on, merged in the library's order** (§3.3): one list,
## the first program's instincts from the top, then the second's, read with
## [param vocab]. Made again only after a change, as a new list -- `rulebook.gd`'s
## lists are shared and never written through, so a list a sister carries is
## never touched by an edit made after she left. Null while nothing is on.
func merged(vocab: Rulebook.Vocabulary) -> Rulebook.Behaviour:
	if _merged_at == revision and _merged_vocab == vocab:
		return _merged
	_merged_at = revision
	_merged_vocab = vocab
	_lists = []
	var on: Array = []
	for one: Program in programs:
		var list := Rulebook.from_lines(one.lines, vocab)
		_lists.append(list)
		if one.on and not one.lines.is_empty():
			on.append(list)
	_merged = Rulebook.merged(on) if not on.is_empty() else null
	return _merged


## **Program [param i]'s instincts, read** with [param vocab]: the very rules the
## merged list shares.
func list_of(i: int, vocab: Rulebook.Vocabulary) -> Rulebook.Behaviour:
	merged(vocab)
	return _lists[i]


## **Where rule [param k] of the merged list came from**: `[program, line]`, or
## `[-1, -1]` past its end.
func owner_of(k: int) -> Vector2i:
	var at := 0
	for i in programs.size():
		var one := programs[i]
		if not one.on:
			continue
		if k < at + one.lines.size():
			return Vector2i(i, k - at)
		at += one.lines.size()
	return Vector2i(-1, -1)


## **Where line [param line] of program [param i] sits in the merged list**, or -1
## for a program that is off.
func merged_index(i: int, line: int) -> int:
	if not programs[i].on:
		return -1
	var at := 0
	for k in i:
		if programs[k].on:
			at += programs[k].lines.size()
	return at + line


# --- What it is called -----------------------------------------------------------

## **Program [param i]'s name, in the language of the moment**: as typed, or the
## default it wears.
func name_of(i: int) -> String:
	var one := programs[i]
	if not one.name.is_empty():
		return one.name
	return default_name(one.auto)


## **A default's words**, in the language of the moment: `program 2`, `water
## cell`, `water cell 2`.
static func default_name(auto: Array) -> String:
	var kind := str(auto[0]) if auto.size() == 2 else NEW
	var n := int(auto[1]) if auto.size() == 2 else 1
	if kind == WATER:
		var water := String(TranslationServer.translate(WATER_NAME))
		return water if n <= 1 else String(TranslationServer.translate(NUMBERED)) % [water, n]
	return String(TranslationServer.translate(NEW_NAME)) % n


## The lowest number of default [param kind] no program wears, from [param from].
func _free_number(kind: String, from: int) -> int:
	var used := {}
	for one: Program in programs:
		if one.name.is_empty() and one.auto.size() == 2 and str(one.auto[0]) == kind:
			used[int(one.auto[1])] = true
	var n := from
	while used.has(n):
		n += 1
	return n


## The lowest number past 1 that makes `<typed> N` a name no program has.
func _free_suffix(typed: String) -> int:
	var n := 2
	while true:
		var name := NUMBERED % [typed, n]
		var taken_by := false
		for one: Program in programs:
			if one.name == name:
				taken_by = true
				break
		if not taken_by:
			return n
		n += 1
	return n


## **A name as typed, made fit to keep**: what `drops.gd` keeps of a world's.
static func clean(typed: String) -> String:
	var kept := ""
	for i in typed.length():
		var code := typed.unicode_at(i)
		kept += " " if code < 0x20 or code == 0x7f else typed[i]
	return kept.strip_edges().left(NAME_MAX).strip_edges()


# --- Changing it ------------------------------------------------------------------

## **A new program** (automation-ux.md §2.5): empty, `program N`, at the bottom.
## **It starts off**, so adding a program never changes what your cell does --
## unless no program is on, when it starts on. Its index, or -1 at
## [constant LIBRARY_MOST].
func add_new() -> int:
	if programs.size() >= LIBRARY_MOST:
		return -1
	var one := Program.new()
	one.auto = [NEW, _free_number(NEW, 1)]
	one.on = not any_on()
	programs.append(one)
	_changed()
	return programs.size() - 1


## **A copy of the water's own program** (automation.md §3.6): `drop.gd`'s
## founders, never what a family evolved, at the bottom -- on when no program is
## on and it fits. Its index, or -1 at [constant LIBRARY_MOST].
func add_founders() -> int:
	if programs.size() >= LIBRARY_MOST:
		return -1
	var one := Program.new()
	one.auto = [WATER, _free_number(WATER, 1)]
	one.lines = PackedStringArray(Drop.FOUNDERS)
	one.on = not any_on() and one.lines.size() <= room()
	programs.append(one)
	_changed()
	return programs.size() - 1


## **A copy of program [param i]**, right under it, holding the same lines: a typed
## name gets the next free number after it, a default the next of its kind. Off,
## as anything new is, unless no program is on and it fits. Its index, or -1.
func copy(i: int) -> int:
	if programs.size() >= LIBRARY_MOST or i < 0 or i >= programs.size():
		return -1
	var from := programs[i]
	var one := Program.new()
	if from.name.is_empty():
		var kind := str(from.auto[0]) if from.auto.size() == 2 else NEW
		one.auto = [kind, _free_number(kind, 2 if kind == WATER else 1)]
	else:
		one.name = clean(NUMBERED % [from.name, _free_suffix(from.name)])
		one.auto = from.auto.duplicate()
	one.lines = from.lines.duplicate()
	one.on = not any_on() and one.lines.size() <= room()
	programs.insert(i + 1, one)
	_changed()
	return i + 1


## Program [param i] goes, for good.
func delete(i: int) -> void:
	if i < 0 or i >= programs.size():
		return
	programs.remove_at(i)
	_changed()


## **Program [param i] named [param typed]**, cleaned; empty keeps its default.
func rename(i: int, typed: String) -> void:
	var name := clean(typed)
	var one := programs[i]
	if name == default_name(one.auto):
		name = ""
	if name == one.name:
		return
	if name.is_empty() and one.auto.size() != 2:
		one.auto = [NEW, _free_number(NEW, 1)]
	one.name = name
	_changed()


## **Program [param from] moved to [param to]**, the others closing up: the order
## is the priority, so this changes which program wins a contradiction.
func move(from: int, to: int) -> void:
	if from == to or from < 0 or from >= programs.size():
		return
	var one := programs[from]
	programs.remove_at(from)
	programs.insert(clampi(to, 0, programs.size()), one)
	_changed()


## **Program [param i] switched [param on]**. Refused, and false, when switching
## it on would take the cell past the eight (row 39): nothing is ever silently
## cut off.
func switch(i: int, on: bool) -> bool:
	var one := programs[i]
	if one.on == on:
		return true
	if on and not fits(i):
		return false
	one.on = on
	_changed()
	return true


## **Program [param i]'s instincts become [param lines]**. Refused, and false, when
## it is on and the new lines would take the cell past the eight, or a program
## past [constant MOST] instincts.
func set_lines(i: int, lines: PackedStringArray) -> bool:
	var one := programs[i]
	if lines.size() > MOST:
		return false
	if one.on and taken() - one.lines.size() + lines.size() > MOST:
		return false
	if lines == one.lines:
		return true
	one.lines = lines.duplicate()
	_changed()
	return true


## Whether program [param i] has room for one more instinct: under
## [constant MOST], and, while it is on, the eight not full.
func can_add(i: int) -> bool:
	var one := programs[i]
	if one.lines.size() >= MOST:
		return false
	return not one.on or room() > 0


func _changed() -> void:
	revision += 1
	dirty = true


# --- The file (§9.1) ----------------------------------------------------------------

## **The library as plain types**, as the file keeps it.
func to_state() -> Dictionary:
	var out: Array = []
	for one: Program in programs:
		var kept := {"name": one.name, "lines": one.lines.duplicate(), "on": one.on}
		if one.auto.size() == 2:
			kept["auto"] = [str(one.auto[0]), int(one.auto[1])]
		out.append(kept)
	return {"version": VERSION, "programs": out}


## **Puts back what [method to_state] gave**, or false -- and nothing changed --
## for one this build cannot read: another version, or not holding what it says.
## A program that would take the cell past the eight comes back off, so nothing
## past them ever runs.
func set_state(state: Dictionary) -> bool:
	if not readable(state).is_empty():
		return false
	var read: Array[Program] = []
	var on := 0
	for kept: Dictionary in state["programs"]:
		var one := Program.new()
		one.name = clean(str(kept["name"]))
		one.lines = (kept["lines"] as PackedStringArray).duplicate()
		one.on = bool(kept["on"]) and on + one.lines.size() <= MOST
		if one.on:
			on += one.lines.size()
		if kept.has("auto"):
			one.auto = [str(kept["auto"][0]), int(kept["auto"][1])]
		elif one.name.is_empty():
			one.auto = [NEW, 1]
		read.append(one)
	programs = read
	revision += 1
	dirty = false
	return true


## **Why [param data] is not a library this build can read**, or "" when it is.
static func readable(data: Variant) -> String:
	if not data is Dictionary:
		return "not a library this build can read"
	var file := data as Dictionary
	if typeof(file.get("version")) != TYPE_INT:
		return "not a library this build can read"
	if int(file["version"]) != VERSION:
		return "version %d, which this build (version %d) does not know" % [
			int(file["version"]), VERSION]
	if not file.get("programs") is Array:
		return "version %d but no programs" % VERSION
	var programs_kept: Array = file["programs"]
	if programs_kept.size() > LIBRARY_MOST:
		return "%d programs, past the %d a library holds" % [programs_kept.size(), LIBRARY_MOST]
	for kept: Variant in programs_kept:
		if not kept is Dictionary:
			return "a program that is not one"
		var one := kept as Dictionary
		if typeof(one.get("name")) != TYPE_STRING or typeof(one.get("lines")) \
				!= TYPE_PACKED_STRING_ARRAY or typeof(one.get("on")) != TYPE_BOOL:
			return "a program without its name, lines and switch"
		if (one["lines"] as PackedStringArray).size() > MOST:
			return "a program of %d instincts, past the %d it holds" % [
				(one["lines"] as PackedStringArray).size(), MOST]
		if one.has("auto"):
			var auto: Variant = one["auto"]
			if not auto is Array or (auto as Array).size() != 2 \
					or typeof(auto[0]) != TYPE_STRING or typeof(auto[1]) != TYPE_INT:
				return "a program's default name is not a kind and a number"
	return ""


## **The library kept at [param path]**: read into this one and true; false with
## none there -- this one left empty -- and false for one this build cannot read,
## which is moved aside as `<path>.old`, once, over any older one, and the
## library starts empty (§9.1). Said in the log either way.
func load_from(path: String) -> bool:
	programs = []
	revision += 1
	dirty = false
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var data: Variant = null
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file != null:
		data = file.get_var()
		file.close()
	var why := readable(data)
	if why.is_empty() and set_state(data):
		return true
	var old := path + ".old"
	var moved := DirAccess.rename_absolute(path, old)
	print("[library] %s is %s: kept as %s, and the library starts empty" % [path, why,
		old if moved == OK else "nothing (%s)" % error_string(moved)])
	programs = []
	return false


## **Keeps this library at [param path]** (§9.1), as a drop is kept: to a `.tmp`
## beside it, read back and compared, and renamed over it only then -- so a phone
## killed mid-write keeps the last good library. OK, or why the last one stands.
func save_to(path: String) -> Error:
	if path.is_empty():
		return ERR_FILE_BAD_PATH
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	var data := to_state()
	var meant := var_to_bytes(data)
	var tmp := path.get_basename() + ".tmp"
	var out := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if out == null:
		return FileAccess.get_open_error()
	out.store_var(data)
	out.close()
	var back := FileAccess.open_compressed(tmp, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if back == null:
		return ERR_FILE_CANT_READ
	var got: Variant = back.get_var()
	back.close()
	if var_to_bytes(got) != meant:
		return ERR_FILE_CORRUPT
	var done := DirAccess.rename_absolute(tmp, path)
	if done == OK:
		dirty = false
	return done
