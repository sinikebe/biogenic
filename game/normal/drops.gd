extends RefCounted
## **Your drops: three worlds, and the one you are in** (docs/design/settings.md
## §4, §6). A drop is one water with everything living in it, kept between
## launches (ocean.md §9). **Your cells are kept apart from it** (docs/design/
## cells.md): a world keeps its water and nothing else. A player keeps up to
## [constant SLOTS] and is in one at a time: the **selected** drop is the one a
## run plays in, a host serves to a friend, and a guest's cell comes from and
## goes back to.
##
## **Three files and an index.** Slot 1 is today's `user://drop.save`, at the
## same path, and nothing here ever moves or rewrites it: there is no migration
## that could fail half-way, and a build without this file -- an APK running its
## own content because a pack did not mount -- still finds the player's drop
## where it always was. Slots 2 and 3 are `drop_2.save` and `drop_3.save`, in
## drop_save.gd's format, untouched. `drops.cfg` beside them says which slot is
## selected, what each is called, and each drop's age and number at its last
## keep, which a run reports with [method note_kept] -- so no menu opens a drop to
## say how old it is, or to tell whether a cell's world is still the one it was
## kept in (cells.md §1.4). **A world's cells, by view, are only ever a build
## before cells.md's** (`generation` for the first view, `generation_<view>` for
## every other, by the names run_state.gd's `CELL_KEYS` gives them): this reads
## them, so the chooser can tell which worlds still hold a cell to move into a
## slot (cells.md §4), and keeps them until [method forget_cells] says it has.
##
## **The index is never trusted over the files** (§6.3). A slot is a drop when
## it has a section or a file, and empty when it has neither. A file the index
## does not name -- the first launch after this file came, an index lost or older
## than the file, one that does not read -- gets the next free default name and
## its line from [method DropSave.peek], which never sets a file aside; a section
## with no file is a drop not swum in yet. **Reading never writes**: whatever had
## to be rebuilt is written with the next change -- a selection, a name, a delete
## or a run's keep -- so a screen that only shows the drops, and every tool and
## probe, leaves `drops.cfg` as it found it. Until then a rebuild is made again
## from the same files, the same way.
##
## **Nothing here knows a menu or a run**: the menu (game/menu/corner.gd) and the
## run (normal_mode.gd's `keep`) both read it. Every function takes the folder
## the drops are in, `user://` unless a probe points it at a folder of its own;
## the dedicated server keeps its room elsewhere (`server.gd`'s `ROOM_PATH`) and
## never loads this file.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const DropSave := preload("res://game/normal/drop_save.gd")
## For [constant Readout.SEP]: a drop's line is a list, as a gene's numbers are.
const Readout := preload("res://game/mechanics/readout.gd")
## For [method I18n.catalogs]: a default name's words in every language the game has.
const I18n := preload("res://game/i18n/i18n.gd")
## **For the views, and only to say them** ([method cell_line]): the words of
## each. The index itself knows a view only by the name its cell is kept under.
const RunState := preload("res://game/run_state.gd")

## How many drops a player keeps.
const SLOTS := 3
## Where the drops are kept.
const ROOT := "user://"
## Each slot's file, under the root. **Slot 1's is today's drop**, so that
## `path_of(1)` is `DropSave.PATH` exactly; drop_probe.gd holds the two together.
const FILES: Array[String] = ["drop.save", "drop_2.save", "drop_3.save"]
## The index, and what it is written as before it is renamed over itself.
const INDEX := "drops.cfg"
const INDEX_TMP := "drops.tmp"
## **A drop's generations in the index**: the first view's under this key, as
## before there was a cell per view, and every other view's under this, `_`, and
## the view's name.
const GENERATION := "generation"
## **A drop's number in the index**, `drop.seed` at its last keep (cells.md §1.4):
## what a cell's place is checked against, so no menu decodes a world to tell
## whether it is still the drop a cell was kept in.
const SEED := "seed"

## **What a run's `keep` says to mean "the selected drop"** (normal_mode.gd):
## this, then the folder the drops are in. [method resolve] turns it into the
## selected slot and its file as the run opens. Never a path, so a run handed a
## file of its own -- every tool's -- never touches the index.
const MARK := "selected:"
## The selected drop of the player's own drops: what a run keeps by default.
const SELECTED := MARK + ROOT

## **How long a typed name can be** (owner's row 7): the widest ordinary name
## fits whole on the chip and in the menu; a name of very wide letters ends in
## "…" there, and never in the naming field.
const NAME_MAX := 20

## **A drop's name until the player types one** (owner's row 6, §5.2): the water a
## microscopist takes a drop from -- pepper water is Leeuwenhoek's, 1676. A new
## drop gets the first one no other drop wears or is called.
##
## **Said in the language of the moment, as a typed name never is.** The index
## keeps which one a drop wears, not its words, and [method default_name]
## translates it each time it is shown, so a drop that keeps its default follows
## the language. **Append only**: a drop's default is its place in this list.
##
## TRANSLATORS: A world's name until the player types one: a real place a
## microscopist takes a water sample from ("pond water"). A "world" is one of the
## three the player keeps: a drop of water and everything living in it. Short and
## lowercase, as a player would name it; at most 20 characters, as a typed name
## is. Shown in the top-right corner after the word "world", in 17 px type, and in
## the "your worlds" menu, in 20 px type.
## ROOM: 220 px at 20 px
const DEFAULT_NAMES: Array[String] = ["pond water", "rain barrel", "hay infusion",
	"ditch water", "birdbath", "tide pool", "puddle", "vase water", "wet moss",
	"pepper water"]

## How a cell's generation is said: the pause caption's own phrases, and a
## cell's lines in the menus (cells-ux.md §1.2, §2.2). **Whole phrases and not an
## ordinal and a noun**, so a language that makes the ordinal agree with the noun
## can. Past the tenth the line counts ([method generation_text]). Here and not
## in normal_mode.gd, so the menu never loads a run to say one.
##
## TRANSLATORS: Part of the pause screen's caption, in 15 px type: "genome ·
## first generation". A "generation" is how many times the cell has divided: the
## first cell is the first generation, its chosen daughter the second. The
## caption's own wording is "genome · %s", translated separately. Also part of a
## cell's lines, in 15 px type: on a view's button, after its name ("slipper ·
## fourth generation", 420 px for the whole line); at the start of a row in "your
## cells" ("fourth generation · 2 hours old", 402 px); and after the view in a
## cell's detailed view ("point of view · fourth generation").
const GENERATIONS: Array[String] = ["first generation", "second generation",
	"third generation", "fourth generation", "fifth generation",
	"sixth generation", "seventh generation", "eighth generation",
	"ninth generation", "tenth generation"]


# --- Reading ---------------------------------------------------------------------

## **The drops as they are**, from the index and the files, rebuilt where the
## two disagree (§6.3) and never written: `{selected, slots}`, where `selected`
## is a slot from 1 and `slots` holds one entry a slot, in order --
## `{slot, empty, file, name, default, lived, seed, generations}`. `name` is the
## player's words, or "" while the drop wears its default, `default`; `lived` is
## its age in seconds at its last keep, and `seed` its number, -1 where the index
## does not hold it; `generations` is the generation of each cell a build before
## cells.md left in it, by view, a view with none not in it; `file` is whether
## the drop has been swum in and kept.
##
## **There is always a selected drop.** When the index names none that exists,
## the first drop there is is selected -- slot 1 on a fresh install and on the
## first launch after this file came -- and slot 1 is made when there is no drop
## at all. So an index lost while slot 1 was empty lands on a drop the player
## has, never on a new one made in its place. **A drop is never garbage for
## having no name**: an index lost, unreadable or older than a file rebuilds that
## drop's section, its line peeked from the file.
static func read(root := ROOT) -> Dictionary:
	var config := ConfigFile.new()
	var indexed := config.load(root.path_join(INDEX)) == OK
	var slots: Array[Dictionary] = []
	for slot in range(1, SLOTS + 1):
		var path := path_of(slot, root)
		var entry := {"slot": slot, "empty": true, "file": FileAccess.file_exists(path),
			"name": "", "default": -1, "lived": 0.0, "seed": -1, "generations": {}}
		var section := str(slot)
		if indexed and config.has_section(section):
			entry["empty"] = false
			entry["name"] = clean(str(config.get_value(section, "name", "")))
			entry["default"] = posmod(_int_of(config.get_value(section, "default", 0)),
				DEFAULT_NAMES.size())
			entry["lived"] = maxf(_float_of(config.get_value(section, "lived", 0.0)), 0.0)
			entry["seed"] = _seed_of(config.get_value(section, SEED, -1))
			entry["generations"] = _generations_in(config, section)
		elif bool(entry["file"]):
			# A drop the index does not name: its line from the file itself, once.
			entry["empty"] = false
			var summary := DropSave.peek(path)
			entry["lived"] = maxf(float(summary.get("lived", 0.0)), 0.0)
			entry["seed"] = _seed_of(summary.get("seed", -1))
			var generations: Dictionary = summary.get("generations", {})
			for view: String in generations:
				if int(generations[view]) > 0:
					entry["generations"][view] = int(generations[view])
		slots.append(entry)
	if slots.all(func(entry: Dictionary) -> bool: return bool(entry["empty"])):
		# Nobody's drop yet: slot 1, which its first keep makes.
		slots[0]["empty"] = false
	# A drop with no section takes the first default nobody shows, in slot order.
	for entry: Dictionary in slots:
		if not bool(entry["empty"]) and int(entry["default"]) < 0:
			entry["default"] = _free_default(slots, int(entry["slot"]))
	var selected := _int_of(config.get_value("drops", "selected", 1)) if indexed else 1
	if selected < 1 or selected > SLOTS or bool(slots[selected - 1]["empty"]):
		for entry: Dictionary in slots:
			if not bool(entry["empty"]):
				selected = int(entry["slot"])
				break
	return {"selected": selected, "slots": slots}


## The selected slot, from 1.
static func selected(root := ROOT) -> int:
	return int(read(root)["selected"])


## **The number of the drop [param entry] holds**, as [method read] gives it, or
## -1 for none: the index's, or -- for a drop kept by a build that did not write
## it there -- the file's own, peeked and never moved. A slot never swum in has no
## drop yet, and so no number (cells.md §1.4: a cell kept in the drop that slot
## held before is in a world that is gone).
static func seed_in(entry: Dictionary, root := ROOT) -> int:
	if bool(entry.get("empty", true)) or not bool(entry.get("file", false)):
		return -1
	var seed := int(entry.get("seed", -1))
	if seed >= 0:
		return seed
	return _seed_of(DropSave.peek(path_of(int(entry["slot"]), root)).get("seed", -1))


## [param slot]'s entry in [param index], as [method read] gives it.
static func entry_of(index: Dictionary, slot: int) -> Dictionary:
	return (index["slots"] as Array)[slot - 1]


## **The file [param slot] lives in**, from 1.
static func path_of(slot: int, root := ROOT) -> String:
	return root.path_join(FILES[clampi(slot, 1, SLOTS) - 1])


## **What a run's `keep` says to keep the selected drop of the drops in
## [param root]**: [constant SELECTED] for the player's own.
static func selected_in(root: String) -> String:
	return MARK + root


## **Where a run keeps its drop**, from what its `keep` says: `{slot, path, root}`
## for a [constant MARK] -- the slot selected now, and its file -- or an empty
## Dictionary for anything else, which is a file of a tool's own, or nothing.
static func resolve(keep: String) -> Dictionary:
	if not keep.begins_with(MARK):
		return {}
	var root := keep.trim_prefix(MARK)
	var slot := selected(root)
	return {"slot": slot, "path": path_of(slot, root), "root": root}


# --- Changing them -----------------------------------------------------------------

## **[param slot] becomes the drop a run plays in.** Refused for an empty slot.
static func select(slot: int, root := ROOT) -> Error:
	var index := read(root)
	if not _is_slot(slot) or bool(entry_of(index, slot)["empty"]):
		return ERR_DOES_NOT_EXIST
	index["selected"] = slot
	return _write(index, root)


## **A new drop in the empty [param slot], called [param typed], and selected**
## (§4.4). It takes the first default name no other drop shows; [param typed]
## empty, or that default's words in any of its languages, keeps it wearing that
## default. Its water is made the first time it is played, as a fresh install's is.
static func make(slot: int, typed: String, root := ROOT) -> Error:
	var index := read(root)
	if not _is_slot(slot):
		return ERR_DOES_NOT_EXIST
	var entry := entry_of(index, slot)
	if not bool(entry["empty"]):
		return ERR_ALREADY_EXISTS
	entry["empty"] = false
	entry["default"] = _free_default(index["slots"], slot)
	entry["name"] = _typed_name(typed, int(entry["default"]))
	entry["lived"] = 0.0
	entry["seed"] = -1
	entry["generations"] = {}
	index["selected"] = slot
	return _write(index, root)


## **[param slot] is called [param typed] from now on**: trimmed, at most
## [constant NAME_MAX] characters, and its default again when it is empty or is
## that default's words, in any of its languages.
static func rename(slot: int, typed: String, root := ROOT) -> Error:
	var index := read(root)
	if not _is_slot(slot) or bool(entry_of(index, slot)["empty"]):
		return ERR_DOES_NOT_EXIST
	var entry := entry_of(index, slot)
	entry["name"] = _typed_name(typed, int(entry["default"]))
	return _write(index, root)


## **[param slot] is emptied** (§4.4, §6.4): its file goes, with the `.tmp` and
## the `.save.old` drop_save.gd leaves beside it, and then its section. **Never
## the selected drop** (owner's row 8): the drop you are in cannot be deleted, so
## there is always one to play, and no mis-tap costs the drop about to be played.
## A file that would not go leaves the index as it was.
static func delete(slot: int, root := ROOT) -> Error:
	var index := read(root)
	if not _is_slot(slot) or bool(entry_of(index, slot)["empty"]):
		return ERR_DOES_NOT_EXIST
	if slot == int(index["selected"]):
		return ERR_LOCKED
	var path := path_of(slot, root)
	for each: String in [path, path.get_basename() + ".tmp", path + ".old"]:
		if FileAccess.file_exists(each):
			DirAccess.remove_absolute(each)
	if FileAccess.file_exists(path):
		return ERR_FILE_CANT_WRITE
	var entry := entry_of(index, slot)
	entry["empty"] = true
	entry["file"] = false
	return _write(index, root)


## **A run kept [param slot]'s drop** at [param lived] seconds old, and its
## number is [param seed] (§6.4; cells.md §3.3): the line the menu says, and the
## number a cell's place is checked against, so no menu opens a drop to say
## either. **It says nothing of a cell**, which is kept apart: whatever a build
## before cells.md said of the cells in it is left as it was, for the migration
## to forget once they are in slots ([method forget_cells]). Writes whatever else
## had to be rebuilt.
##
## [param seed] is an int before the folder on purpose: a call written when this
## took a view and a generation, with the folder fifth, is an error here, and
## never a keep told to the player's own index.
static func note_kept(slot: int, lived: float, seed: int, root := ROOT) -> Error:
	if not _is_slot(slot):
		return ERR_DOES_NOT_EXIST
	var index := read(root)
	var entry := entry_of(index, slot)
	if bool(entry["empty"]):
		# Its section went while it was played -- the index lost under a run.
		entry["empty"] = false
		entry["default"] = _free_default(index["slots"], slot)
	entry["file"] = true
	entry["lived"] = maxf(lived, 0.0)
	entry["seed"] = seed if seed >= 0 else int(entry["seed"])
	return _write(index, root)


## **[param slot]'s drop keeps no cell any more** (cells.md §4, step 3): its
## generations go from the index, once its file has been written again without
## them, and its number, [param seed], is kept while the section is written.
## Nothing for a slot the index does not name and has no file.
static func forget_cells(slot: int, seed: int, root := ROOT) -> Error:
	if not _is_slot(slot):
		return ERR_DOES_NOT_EXIST
	var index := read(root)
	var entry := entry_of(index, slot)
	if bool(entry["empty"]):
		return ERR_DOES_NOT_EXIST
	entry["generations"] = {}
	if seed >= 0:
		entry["seed"] = seed
	return _write(index, root)


# --- What a drop is called, and what its line says ----------------------------------

## **What [param entry] is called**: the player's words, as typed, or its default
## name in the language of the moment.
static func name_of(entry: Dictionary) -> String:
	var typed := str(entry.get("name", ""))
	return typed if not typed.is_empty() else default_name(int(entry.get("default", 0)))


## **The [param which]th default name, in the language of the moment** (§5.2):
## translated each time it is said, so a screen that says it again on a change of
## language says it in the new one.
static func default_name(which: int) -> String:
	var at := posmod(which, DEFAULT_NAMES.size())
	return String(TranslationServer.translate(DEFAULT_NAMES[at]))


## **Every way the [param which]th default name is written**: its English, its
## words in the language of the moment, and its words in every catalog the game
## has ([method I18n.catalogs]), each as [method clean] would keep it typed. So
## typing a default's words, in any of its languages, keeps the drop wearing it
## (§5.2). Read from the files, so a process that registered no catalog -- a
## probe -- answers as a phone does. [param catalogs] is [method I18n.catalogs]'
## answer, for a caller that asks about every default at once.
static func default_words(which: int, catalogs: Array = []) -> PackedStringArray:
	var at := posmod(which, DEFAULT_NAMES.size())
	var words := PackedStringArray([clean(DEFAULT_NAMES[at])])
	var now := clean(default_name(at))
	if not now in words:
		words.append(now)
	for found: Dictionary in (catalogs if not catalogs.is_empty() else I18n.catalogs()):
		var said := clean(String((found["catalog"] as Translation).get_message(DEFAULT_NAMES[at])))
		if not said.is_empty() and not said in words:
			words.append(said)
	return words


## **The default name [param slot] would get if it were made now**: the first
## one no other drop in [param index] shows.
static func next_default(index: Dictionary, slot: int) -> int:
	return _free_default(index["slots"], slot)


## **A name as the player typed it, made fit to keep**: a control character -- a
## tab or a line break pasted in -- is a space, and the name is trimmed at both
## ends and at most [constant NAME_MAX] characters.
static func clean(typed: String) -> String:
	var kept := ""
	for i in typed.length():
		var code := typed.unicode_at(i)
		kept += " " if code < 0x20 or code == 0x7f else typed[i]
	return kept.strip_edges().left(NAME_MAX).strip_edges()


## **[param entry]'s line in the menu** (§4.3; cells-ux.md §5), in the language
## of the moment: **the drop's age, and only its age** -- a world keeps only its
## water now -- or "not swum in yet" for a drop never kept. "" for an empty slot.
static func line_of(entry: Dictionary) -> String:
	return "\n".join(lines_of(entry))


## [method line_of] as its lines, one to each string, for a caller that sizes a
## row to them: one, or none for an empty slot.
static func lines_of(entry: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if bool(entry.get("empty", true)):
		return out
	var lived := float(entry.get("lived", 0.0))
	if not bool(entry.get("file", false)) or lived <= 0.0:
		# TRANSLATORS: A world's line in the "your worlds" menu, in 15 px type, for
		# a world that has never been played in. A "world" is one of the three the
		# player keeps: a drop of water and everything living in it.
		# ROOM: 280 px at 15 px
		out.append(String(TranslationServer.translate("not swum in yet")))
		return out
	out.append(age_text(lived))
	return out


## **A cell's view and generation, built whole** (cells-ux.md §3.2): the view as
## the mode select's button names it, a middle dot, and the cell's generation --
## "point of view · fourth generation" -- the detailed view's line under a cell's
## name. tools/i18n_pot.gd builds it with this, in every language.
static func cell_line(mode: int, generation: int) -> String:
	return String(TranslationServer.translate(RunState.VIEW_WORDS[mode])) \
		+ Readout.SEP + generation_text(generation)


## **A generation in words**: "fourth generation", and past the tenth
## "generation 12".
static func generation_text(generation: int) -> String:
	if generation >= 1 and generation <= GENERATIONS.size():
		return String(TranslationServer.translate(GENERATIONS[generation - 1]))
	# TRANSLATORS: The generation, counted past the tenth: "generation 12". Keep %d.
	# Used wherever the ten phrases are: "genome · generation 12", "slipper ·
	# generation 12", "point of view · generation 12".
	return String(TranslationServer.translate("generation %d")) % generation


## **A drop's age in words** (§4.3): minutes under an hour, hours under 48, then
## days -- the drop's own clock, which runs only while it is played. Under a
## minute is "1 minute old": a drop that has been swum in is never nothing old.
## The player's word for it is "world" (§4.1), and so is the translators'. A
## cell's age is said the same way, in words of its own (cells.gd's `age_text`).
static func age_text(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 60:
		minutes = maxi(minutes, 1)
		# TRANSLATORS: A world's line in the "your worlds" menu, in 15 px type, under
		# its name: how long the world has been played, "25 minutes old". A world is
		# one of the three the player keeps, and "old" agrees with it. A cell's age
		# is a message of its own, under the context "cell". Keep %d.
		# ROOM: 280 px at 15 px with 99
		return String(TranslationServer.translate_plural("%d minute old", "%d minutes old",
			minutes)) % minutes
	var hours := int(seconds / 3600.0)
	if hours < 48:
		# TRANSLATORS: The same, in hours: "2 hours old". Keep %d.
		# ROOM: 280 px at 15 px with 99
		return String(TranslationServer.translate_plural("%d hour old", "%d hours old",
			hours)) % hours
	var days := int(seconds / 86400.0)
	# TRANSLATORS: The same, in days: "3 days old". Keep %d.
	# ROOM: 280 px at 15 px with 999
	return String(TranslationServer.translate_plural("%d day old", "%d days old", days)) % days


# --- The index file ------------------------------------------------------------------

## **Writes [param index] whole** (§6.2): to `drops.tmp` beside it, read back and
## compared with the bytes meant, and renamed over `drops.cfg` only then -- as a
## drop is written, so a phone killed mid-write keeps the last good index, and a
## full disk never passes for a write. An empty slot has no section.
##
## **A drop's age is kept in whole seconds**: the engine's text reader does not
## give back every double it wrote (measured on 4.7.2: 7,581 of 20,000 came back
## a last digit off), and the menu says nothing finer than a minute. A whole
## number of seconds comes back exactly.
static func _write(index: Dictionary, root: String) -> Error:
	if not DirAccess.dir_exists_absolute(root):
		var made := DirAccess.make_dir_recursive_absolute(root)
		if made != OK:
			return made
	var config := ConfigFile.new()
	config.set_value("drops", "selected", int(index["selected"]))
	for entry: Dictionary in index["slots"]:
		if bool(entry["empty"]):
			continue
		var section := str(entry["slot"])
		config.set_value(section, "name", str(entry["name"]))
		config.set_value(section, "default", int(entry["default"]))
		config.set_value(section, "lived", floorf(float(entry["lived"])))
		if int(entry.get("seed", -1)) >= 0:
			config.set_value(section, SEED, int(entry["seed"]))
		# **The first view's generation always, as it always was** -- a build
		# before there was a cell per view reads it and nothing else -- and every
		# other view's only while a cell of it waits, in the views' order by name.
		var generations: Dictionary = entry["generations"]
		config.set_value(section, GENERATION, maxi(int(generations.get("", 0)), 0))
		var views: Array = generations.keys()
		views.sort()
		for view: String in views:
			if not view.is_empty() and int(generations[view]) > 0:
				config.set_value(section, GENERATION + "_" + view, int(generations[view]))
	var tmp := root.path_join(INDEX_TMP)
	var saved := config.save(tmp)
	if saved != OK:
		return saved
	if FileAccess.get_file_as_string(tmp) != config.encode_to_text():
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(tmp, root.path_join(INDEX))


## **The first default no drop but [param slot] shows**, among [param slots]; the
## first of all when every one is taken. A default is shown by a drop that wears
## it -- told by which one, so the answer is the same in every language -- or by a
## drop the player called by its words, in any of its languages
## ([method default_words]).
static func _free_default(slots: Array, slot: int) -> int:
	var worn := {}
	var called := {}
	for entry: Dictionary in slots:
		if int(entry["slot"]) == slot or bool(entry["empty"]):
			continue
		var typed := str(entry["name"])
		if not typed.is_empty():
			called[typed.to_lower()] = true
		elif int(entry["default"]) >= 0:
			worn[int(entry["default"])] = true
	var catalogs := I18n.catalogs()
	for which in DEFAULT_NAMES.size():
		if worn.has(which):
			continue
		var free := true
		for words: String in default_words(which, catalogs):
			if called.has(words.to_lower()):
				free = false
				break
		if free:
			return which
	return 0


## What the index keeps as [param typed]'s name for a drop wearing default
## [param which]: "" -- the default -- for nothing typed, or for that default's
## very words in any of its languages, so it goes on following the language.
static func _typed_name(typed: String, which: int) -> String:
	var called := clean(typed)
	if called.is_empty() or called in default_words(which):
		return ""
	return called


static func _is_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOTS


## **Each view's generation in [param section]**, by view: [constant GENERATION]
## is the first view's and `generation_<view>` every other's -- read by the
## pattern, so a view a later build adds is kept by this one, not lost on its next
## write. A cell's only: 0 and below, or what is not a number, is none.
static func _generations_in(config: ConfigFile, section: String) -> Dictionary:
	var out := {}
	for key: String in config.get_section_keys(section):
		var view := ""
		if key != GENERATION:
			if not key.begins_with(GENERATION + "_") or key.length() <= GENERATION.length() + 1:
				continue
			view = key.trim_prefix(GENERATION + "_")
		var generation := _int_of(config.get_value(section, key, 0))
		if generation > 0:
			out[view] = generation
	return out


## **A drop's number as the index holds it**, or -1 for none: a drop's number is
## never below 0 (food.gd draws it with `randi()`).
static func _seed_of(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value) if int(value) >= 0 else -1
		TYPE_STRING, TYPE_STRING_NAME:
			return int(str(value)) if str(value).is_valid_int() and int(str(value)) >= 0 else -1
	return -1


## A number the index holds, whatever a hand or a later build left there.
static func _int_of(value: Variant) -> int:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return int(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return int(str(value)) if str(value).is_valid_int() else 0
	return 0


static func _float_of(value: Variant) -> float:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			var number := float(value)
			return number if is_finite(number) else 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			return float(str(value)) if str(value).is_valid_float() else 0.0
	return 0.0
