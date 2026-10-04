extends RefCounted
## **Your cells: three slots for each view, apart from the worlds**
## (docs/design/cells.md). A cell is its own save, one small file a slot
## (cell_save.gd), and **a cell belongs to the view it was born in**: each view
## keeps its own slots, by the name its cells are kept under (run_state.gd's
## `CELL_KEYS`: full vision's is "", point of view's `pov`), and its own
## selection -- the slot its button plays. A view's button can only ever list,
## and play, that view's cells.
##
## **The files.** `cells/cell_<n>.save` for the first view's slot `n`, and
## `cells/cell_<view>_<n>.save` for every other view's, under the folder they are
## kept in -- `user://` unless a tool points it at a folder of its own -- and
## `cells.cfg` beside the folder, which holds the selection and nothing else.
## A slot's name, line and place are in its file, and a menu reads them there.
##
## **Reading never writes.** Every menu, tool and probe leaves `cells.cfg` and the
## folder as it found them: only a choice writes, and a keep, a rename, a delete
## or the migration ([method migrate]).
##
## **Nothing here knows a menu or a run.** The chooser, the corner's sheets and
## the run all read it and ask it to change things; it knows no gene, and a view
## only by its name -- and, to say a cell's lines, by its words.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const CellSave := preload("res://game/normal/cell_save.gd")
const DropSave := preload("res://game/normal/drop_save.gd")
## The worlds a cell is kept in: their names, their numbers, and which is selected.
const Drops := preload("res://game/normal/drops.gd")
## **The views, by name and in order**: the order a migration moves a world's
## cells in, and which views a selection is settled for. Their words, only for
## the log.
const RunState := preload("res://game/run_state.gd")
## For [constant Readout.SEP]: a cell's lines are lists, as a world's line is.
const Readout := preload("res://game/mechanics/readout.gd")
## For [method I18n.catalogs]: a default name's words in every language the game has.
const I18n := preload("res://game/i18n/i18n.gd")
## For [constant Metabolism.HUNGRY_FROM], which is where `hungry` starts.
const Metabolism := preload("res://game/normal/metabolism.gd")

## **How many slots each view has** (cells.md §1.2): exactly enough for the
## migration, and a sheet that never scrolls on a phone. A later build can raise
## it. A slot past it exists only while a file holds it (§4).
const SLOTS := 3
## Where the cells are kept, by default: the player's own.
const ROOT := "user://"
## The folder the slots' files are in, under the root, and the index beside it.
const FOLDER := "cells"
const INDEX := "cells.cfg"
const INDEX_TMP := "cells.tmp"
const SECTION := "cells"
## A view's selection in the index: `selected` for the first view's, and
## `selected_<view>` for every other's.
const SELECTED_KEY := "selected"

## **What a run's `cells_at` says to mean "each view's selected slot"**
## (normal_mode.gd), then the folder the cells are in. Never a path, so a run
## handed nothing keeps no cell.
const MARK := "selected:"
## The selected slots of the player's own cells: what a run plays by default.
const SELECTED := MARK + ROOT

## How long a typed name can be: a world's rule (settings.md §5.2).
const NAME_MAX := Drops.NAME_MAX

## **A cell's name until the player types one** (owner's rows 2 and 3, cells.md
## §1.7): the names the first microscopists gave the animalcules they found in a
## drop. A new cell gets the first one no cell in any slot, living or recorded,
## wears or is called. **Said in the language of the moment**, as a world's
## default is: a slot keeps which one, not its words. **Append only**: a cell's
## default is its place in this list. The sun animalcule is left out on purpose:
## `sun` is a gene's word on the pause screen.
##
## TRANSLATORS: A cell's name until the player types one: the old nickname of a
## little animal the first microscopists found in a drop of pond water --
## "slipper" is the paramecium, "bell" the vorticella, "trumpet" the stentor,
## "proteus" the amoeba, "swan" Lacrymaria olor, "wheel" the rotifer, "sparkle"
## the sea sparkle (Noctiluca). Use your language's own old name where it has
## one. A "cell" is the player's creature, and French makes it feminine
## (cellule). Short and lowercase, as a player would name it; at most 20
## characters, as a typed name is. Shown on a view's button in 15 px type, in
## the "your cells" menu in 20 px type, and as the title of a cell's detailed
## view in 28 px type.
## ROOM: 220 px at 20 px
const CELL_NAMES: Array[String] = ["slipper", "bell", "trumpet", "proteus", "swan",
	"wheel", "sparkle"]

## **Where a cell is, against the worlds** ([method place_of]): `HERE`, in the
## selected world's drop; `THERE`, in another world that still holds its drop;
## `FRIEND`, kept in a friend's water; `GONE`, in a world deleted, made again or
## set aside since; `NONE` for no cell.
enum Place { NONE, HERE, THERE, FRIEND, GONE }


# --- Files and the selection ----------------------------------------------------------

## The folder the slots are in, under [param root].
static func folder_of(root := ROOT) -> String:
	return root.path_join(FOLDER)


## **The file [param view]'s slot [param slot] lives in.** The name is built from
## the view's name, so a view a later build adds is kept by this one.
static func path_of(view: String, slot: int, root := ROOT) -> String:
	var file := "cell_%d.save" % slot if view.is_empty() else "cell_%s_%d.save" % [view, slot]
	return folder_of(root).path_join(file)


## **What a run's `cells_at` says to play the selected slots of the cells in
## [param root]**: [constant SELECTED] for the player's own.
static func selected_in(root: String) -> String:
	return MARK + root


## **The folder a run's `cells_at` names**, or "" for anything that is not a
## [constant MARK]: a run that keeps no cell.
static func resolve(cells_at: String) -> String:
	return cells_at.trim_prefix(MARK) if cells_at.begins_with(MARK) else ""


## **The slots [param view] has**: 1 to [constant SLOTS], and any past them that a
## file holds -- a cell an older build kept after the migration, which took a
## slot rather than be left behind (cells.md §4). Such a slot closes when it
## empties.
static func slots_of(view: String, root := ROOT) -> Array[int]:
	var out: Array[int] = []
	for slot in range(1, SLOTS + 1):
		out.append(slot)
	var past: Array[int] = []
	var head := "cell_" if view.is_empty() else "cell_%s_" % view
	for file: String in _files_in(folder_of(root)):
		if not file.begins_with(head) or not file.ends_with(".save"):
			continue
		var number := file.trim_prefix(head).trim_suffix(".save")
		if number.is_valid_int() and int(number) > SLOTS and not int(number) in past:
			past.append(int(number))
	past.sort()
	out.append_array(past)
	return out


## **[param view]'s selected slot**, from 1: the index's, or slot 1 when there is
## no index, it cannot be read, it names none for this view, or it names a slot
## past the slots that exist.
static func selected(view: String, root := ROOT) -> int:
	var config := ConfigFile.new()
	if config.load(root.path_join(INDEX)) != OK:
		return 1
	var key := _key(view)
	if not config.has_section_key(SECTION, key):
		return 1
	var slot := _int_of(config.get_value(SECTION, key, 1))
	if slot < 1 or (slot > SLOTS and not FileAccess.file_exists(path_of(view, slot, root))):
		return 1
	return slot


## **[param slot] becomes the one [param view]'s button plays** (cells-ux.md
## §2.3): written to the index, every other view's selection kept. An empty slot
## can be selected too -- a new cell is born there when the view is pressed.
## Refused for a slot that does not exist.
static func select(view: String, slot: int, root := ROOT) -> Error:
	if slot < 1 or (slot > SLOTS and not FileAccess.file_exists(path_of(view, slot, root))):
		return ERR_DOES_NOT_EXIST
	var config := _index(root)
	config.set_value(SECTION, _key(view), slot)
	return _write_index(config, root)


## **A slot's name is [param typed] from now on**: trimmed, at most
## [constant NAME_MAX] characters, and its default again when it is empty or that
## default's words, in any of its languages -- a world's rules (settings.md §5.2).
## A record has nothing to rename: it goes when a new cell starts in its slot.
static func rename(view: String, slot: int, typed: String, root := ROOT) -> Error:
	var path := path_of(view, slot, root)
	var data := CellSave.peek(path)
	if data.is_empty() or str(data["view"]) != view or CellSave.is_record(data):
		return ERR_DOES_NOT_EXIST
	data["name"] = typed_name(typed, int(data["default"]))
	return CellSave.write(path, data)


## **[param view]'s slot [param slot] is emptied** (cells-ux.md §3.4): its file
## goes, with the `.tmp` and the `.old` beside it. **The selection is not moved**:
## a selected slot emptied stays selected, and its view starts a new cell there.
## A file that would not go says so.
static func delete(view: String, slot: int, root := ROOT) -> Error:
	var path := path_of(view, slot, root)
	if not FileAccess.file_exists(path):
		return ERR_DOES_NOT_EXIST
	for each: String in [path, path.get_basename() + ".tmp", path + ".old"]:
		if FileAccess.file_exists(each):
			DirAccess.remove_absolute(each)
	return ERR_FILE_CANT_WRITE if FileAccess.file_exists(path) else OK


# --- What a menu reads --------------------------------------------------------------

## **[param view]'s cells as a menu shows them**, read and never written:
## `{view, selected, slots}`, `slots` one entry a slot in order, as
## [method entry_of_slot] gives it.
static func read(view: String, root := ROOT) -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot: int in slots_of(view, root):
		slots.append(entry_of_slot(view, slot, root))
	return {"view": view, "selected": selected(view, root), "slots": slots}


## **One slot as a menu shows it**: `{view, slot, empty, record, data}`, `data`
## the file as cell_save.gd's `peek` gives it. **A file this build cannot read,
## or another view's, is shown as empty** and left where it is: only the run that
## would play the slot sets a file aside.
static func entry_of_slot(view: String, slot: int, root := ROOT) -> Dictionary:
	var data := CellSave.peek(path_of(view, slot, root))
	if not data.is_empty() and str(data["view"]) != view:
		data = {}
	return {"view": view, "slot": slot, "empty": data.is_empty(),
		"record": CellSave.is_record(data) if not data.is_empty() else false, "data": data}


## [param slot]'s entry in [param index], as [method read] gives it -- an empty
## one for a slot it does not list.
static func entry_of(index: Dictionary, slot: int) -> Dictionary:
	for entry: Dictionary in index["slots"]:
		if int(entry["slot"]) == slot:
			return entry
	return {"view": str(index.get("view", "")), "slot": slot, "empty": true,
		"record": false, "data": {}}


## **What [param entry]'s cell is called**: the player's words, as typed, or its
## default name in the language of the moment. "" for an empty slot.
static func name_of(entry: Dictionary) -> String:
	var data: Dictionary = entry.get("data", {})
	if data.is_empty():
		return ""
	var typed := str(data.get("name", ""))
	return typed if not typed.is_empty() else default_name(int(data.get("default", 0)))


## [param entry]'s cell's generation, 0 for none.
static func generation_of(entry: Dictionary) -> int:
	var data: Dictionary = entry.get("data", {})
	return int((data["cell"] as Dictionary).get("generation", 1)) if not data.is_empty() else 0


## **How long [param entry]'s line has been played**, in seconds, or -1 when
## nobody knows: a cell kept before there were slots (cells.md §4).
static func lived_of(entry: Dictionary) -> float:
	var data: Dictionary = entry.get("data", {})
	return float(data[CellSave.LIVED]) if data.has(CellSave.LIVED) else -1.0


## **Where [param entry]'s cell is**, as [enum Place], against [param worlds] --
## drops.gd's `read` of the folder at [param drops_root]: in the selected world's
## drop, in another world that still holds its drop, in a friend's water, or in a
## world that is gone -- deleted, made again, or set aside since.
static func place_of(entry: Dictionary, worlds: Dictionary, drops_root := Drops.ROOT) -> int:
	var data: Dictionary = entry.get("data", {})
	if data.is_empty():
		return Place.NONE
	if bool((data["cell"] as Dictionary).get("elsewhere", false)):
		return Place.FRIEND
	var where: Dictionary = data["where"]
	if where.is_empty():
		return Place.GONE
	var world := int(where["world"])
	if world < 1 or world > Drops.SLOTS:
		return Place.GONE
	if Drops.seed_in(Drops.entry_of(worlds, world), drops_root) != int(where["drop"]):
		return Place.GONE
	return Place.HERE if world == int(worlds["selected"]) else Place.THERE


## The name of the world [param entry]'s cell is in, from [param worlds]; "" for
## a cell in no world of the player's.
static func world_name_of(entry: Dictionary, worlds: Dictionary) -> String:
	var data: Dictionary = entry.get("data", {})
	if data.is_empty() or (data["where"] as Dictionary).is_empty():
		return ""
	var world := int(data["where"]["world"])
	if world < 1 or world > Drops.SLOTS:
		return ""
	return Drops.name_of(Drops.entry_of(worlds, world))


# --- What a menu says -----------------------------------------------------------------

## **The line under a view's name on its button** (cells-ux.md §1.2), built whole
## and handed back in three parts, `[before, name, after]`, so a screen can let
## the name alone give way to "…" ([method fit]): `slipper · fourth generation`,
## then `· from “rain barrel”` for a cell whose place is in another world or
## `· from a friend's water`; `a new cell` for an empty slot, and `a new cell ·
## slipper died` over a record. **[param with_from] off** is the TOGETHER page's
## line (§4): a pond is a friend's water whatever the place was, so it says no
## `from`, and over a record it says `a new cell` alone.
static func button_line(entry: Dictionary, worlds: Dictionary, with_from := true,
		drops_root := Drops.ROOT) -> PackedStringArray:
	if bool(entry.get("empty", true)) or (bool(entry.get("record", false)) and not with_from):
		# TRANSLATORS: The second line of a button that starts a game in one of the
		# two views, in 15 px type under the view's name: pressing it starts a new
		# cell. A "cell" is the player's creature (French: une cellule, feminine).
		# The button on the earshot screen leaves 236 px for it.
		# ROOM: 236 px at 15 px
		return PackedStringArray([String(TranslationServer.translate("a new cell")), "", ""])
	var name := name_of(entry)
	if bool(entry.get("record", false)):
		# TRANSLATORS: The same line, when the cell that was played in this view
		# died and the player left before a new one started: pressing the button
		# starts a new cell. %s is the dead cell's name, the player's own words or a
		# default such as "slipper" (French "une nouvelle cellule · %s est morte":
		# "morte" agrees with "cellule"). A long name is shortened with "…" so the
		# line fits the 420 px it has.
		# ROOM: 420 px at 15 px with name
		var said := String(TranslationServer.translate("a new cell · %s died"))
		var cut := said.find("%s")
		if cut < 0:
			return PackedStringArray([said, "", ""])
		return PackedStringArray([said.left(cut), name, said.substr(cut + 2)])
	var after := Readout.SEP + Drops.generation_text(generation_of(entry))
	if with_from:
		match place_of(entry, worlds, drops_root):
			Place.FRIEND:
				# TRANSLATORS: The end of the line under a view's name on its button,
				# after the cell's name and generation, in 15 px type: the cell was
				# left while it swam in a friend's game ("water"), and pressing the
				# button brings it home. The whole line has 420 px.
				after += Readout.SEP + String(TranslationServer.translate(
					"from a friend's water"))
			Place.THERE:
				# TRANSLATORS: The same, for a cell left in another of the player's
				# worlds than the one selected: pressing the button brings it from
				# there. %s is that world's name in quotation marks ("“rain barrel”").
				# The whole line has 420 px.
				# ROOM: 420 px at 15 px with world
				after += Readout.SEP + String(TranslationServer.translate("from %s")) \
					% quoted(world_name_of(entry, worlds))
	return PackedStringArray(["", name, after])


## **[param parts] as one line in [param room] px**, as [method button_line]
## gives them: whole when it fits, and otherwise **the name alone shortened**,
## ending in "…", until it does -- the generation and the world are what the line
## is for, and are never cut (cells-ux.md §1.2).
static func fit(parts: PackedStringArray, font: Font, size: int, room: float) -> String:
	var whole := parts[0] + parts[1] + parts[2]
	if parts[1].is_empty() or font == null \
			or font.get_string_size(whole, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room:
		return whole
	var name := parts[1]
	for n in range(name.length() - 1, 0, -1):
		var line := parts[0] + name.left(n).strip_edges(false, true) + "…" + parts[2]
		if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room:
			return line
	return parts[0] + "…" + parts[2]


## **A row's two lines in "your cells"** (cells-ux.md §2.2), in the language of
## the moment: its generation, its line's age and its hunger; then where it is.
## None for an empty slot.
static func row_lines(entry: Dictionary, worlds: Dictionary,
		drops_root := Drops.ROOT) -> PackedStringArray:
	if bool(entry.get("empty", true)):
		return PackedStringArray()
	var first := PackedStringArray([Drops.generation_text(generation_of(entry))])
	var said := age_and_hunger(entry)
	if not said.is_empty():
		first.append(said)
	return PackedStringArray([Readout.SEP.join(first), where_line(entry, worlds, drops_root)])


## **Its line's age and its hunger**, joined, or "" when neither is known: the
## detailed view's line under the view (cells-ux.md §3.2), and a row's first line
## after its generation. A record keeps its last age, and says no hunger.
static func age_and_hunger(entry: Dictionary) -> String:
	var parts := PackedStringArray()
	var lived := lived_of(entry)
	if lived >= 0.0:
		parts.append(age_text(lived))
	if not bool(entry.get("record", false)):
		var data: Dictionary = entry.get("data", {})
		var hunger := hunger_text(float((data.get("cell", {}) as Dictionary).get("hunger", 0.0)))
		if not hunger.is_empty():
			parts.append(hunger)
	return Readout.SEP.join(parts)


## **Where [param entry]'s cell is, in words** (cells-ux.md §2.2): `world · pond
## water`, the chip's own grammar; `a friend's water`; `a world that is gone`;
## and for a record, `died in “pond water”` or `died in a friend's water`.
static func where_line(entry: Dictionary, worlds: Dictionary, drops_root := Drops.ROOT) -> String:
	var place := place_of(entry, worlds, drops_root)
	if bool(entry.get("record", false)):
		return died_line(place, world_name_of(entry, worlds))
	match place:
		Place.FRIEND:
			return friends_water()
		Place.GONE:
			return gone_world()
		Place.HERE, Place.THERE:
			# The chip's own caption, "world", and the world's name.
			return String(TranslationServer.translate("world")) + Readout.SEP \
				+ world_name_of(entry, worlds)
	return ""


## **Where a record's cell died** (cells-ux.md §2.2, §3.5), for [param place] and
## the name of the world it died in, [param world].
static func died_line(place: int, world: String) -> String:
	match place:
		Place.FRIEND:
			# TRANSLATORS: Where a cell died, in 15 px type, on its row in "your
			# cells" and in its detailed view: in a friend's game ("water"). A
			# "cell" is the player's creature (French: une cellule, feminine, so
			# "morte").
			# ROOM: 402 px at 15 px
			return String(TranslationServer.translate("died in a friend's water"))
		Place.GONE:
			# TRANSLATORS: The same, for a cell that died in one of the player's
			# worlds that has since been deleted or made again (French: "morte").
			# ROOM: 402 px at 15 px
			return String(TranslationServer.translate("died in a world that is gone"))
	# TRANSLATORS: The same, in one of the player's worlds: %s is its name in
	# quotation marks ("died in “pond water”"). French "morte dans %s" agrees with
	# "cellule". In the detailed view it may wrap onto a second line of 280 px.
	# ROOM: 402 px at 15 px with world
	return String(TranslationServer.translate("died in %s")) % quoted(world)


## **A name inside a line, in the language's own quotation marks**:
## `“rain barrel”`. The same message as a program's name in a sentence
## (program_words.gd's `QUOTED`), said here so that no menu loads the programs'
## words to quote a world.
static func quoted(name: String) -> String:
	# TRANSLATORS: A name inside a sentence, in your language's quotation marks:
	# here a world's name in a cell's line ("slipper · fourth generation · from
	# “rain barrel”"; French « eau de mare »). %s is the name, the player's own
	# words or a default name.
	return String(TranslationServer.translate("“%s”")) % name


## **A cell kept in a friend's water**, as a row and the detailed view say where
## it is.
static func friends_water() -> String:
	# TRANSLATORS: Where a cell is, in 15 px type on its row in "your cells", and in
	# 17 px in its detailed view: it was left while it swam in a friend's game,
	# which the game calls their "water". A "cell" is the player's creature.
	# ROOM: 280 px at 17 px
	return String(TranslationServer.translate("a friend's water"))


## **A cell whose world is gone**: deleted or made again since it was kept there.
static func gone_world() -> String:
	# TRANSLATORS: Where a cell is, in 15 px type on its row in "your cells", and in
	# 17 px in its detailed view: the world it was kept in has been deleted or made
	# again since, so it will come into another at a quiet place. A "world" is one
	# of the three the player keeps.
	# ROOM: 280 px at 17 px
	return String(TranslationServer.translate("a world that is gone"))


## **A cell's hunger in a word** (cells-ux.md §2.2): `hungry` from half a tank
## (Metabolism.HUNGRY_FROM), `starving` once the tank is empty, and nothing for a
## cell that is fed. It is shown because a cell left starving resumes starving.
static func hunger_text(hunger: float) -> String:
	if hunger >= 1.0:
		# TRANSLATORS: The end of a cell's line, in 15 px type: its tank is empty
		# and it is dying of hunger. A "cell" is the player's creature (French: une
		# cellule, feminine).
		# ROOM: 160 px at 15 px
		return String(TranslationServer.translate("starving"))
	if hunger >= Metabolism.HUNGRY_FROM:
		# TRANSLATORS: The same, when its tank is half empty or less: it is hungry
		# (French "affamée", agreeing with "cellule").
		# ROOM: 160 px at 15 px
		return String(TranslationServer.translate("hungry"))
	return ""


## **A cell's line's age in words** (cells-ux.md §2.2): as a world's
## (drops.gd's `age_text`) -- minutes under an hour, hours under 48, then days --
## **in words of its own, under the context `cell`**, because a language agrees
## the word with the noun: French says a world is `âgé`, and a cell `âgée`.
static func age_text(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 60:
		minutes = maxi(minutes, 1)
		# TRANSLATORS: How long a cell's line has been played, in 15 px type on its
		# row in "your cells" and in its detailed view: "25 minutes old". A "cell" is
		# the player's creature, and its daughters are the same line; French makes
		# it feminine, so "âgée de %d minutes". Keep %d.
		# ROOM: 300 px at 15 px with 99
		return String(TranslationServer.translate_plural("%d minute old", "%d minutes old",
			minutes, "cell")) % minutes
	var hours := int(seconds / 3600.0)
	if hours < 48:
		# TRANSLATORS: The same, in hours: "2 hours old" (French "âgée de 2 heures").
		# Keep %d.
		# ROOM: 300 px at 15 px with 99
		return String(TranslationServer.translate_plural("%d hour old", "%d hours old",
			hours, "cell")) % hours
	var days := int(seconds / 86400.0)
	# TRANSLATORS: The same, in days: "3 days old" (French "âgée de 3 jours").
	# Keep %d.
	# ROOM: 300 px at 15 px with 999
	return String(TranslationServer.translate_plural("%d day old", "%d days old", days,
		"cell")) % days


# --- Names (owner's rows 2 and 3) ------------------------------------------------------

## **The [param which]th default name, in the language of the moment**: translated
## each time it is said, so a cell that keeps its default follows the language.
static func default_name(which: int) -> String:
	var at := posmod(which, CELL_NAMES.size())
	return String(TranslationServer.translate(CELL_NAMES[at]))


## **Every way the [param which]th default name is written**: its English, its
## words now, and its words in every catalog the game has, each as a typed name
## is kept -- so typing a default's words, in any of its languages, keeps the cell
## wearing it (settings.md §5.2). [param catalogs] is [method I18n.catalogs]'
## answer, for a caller that asks about every default at once.
static func default_words(which: int, catalogs: Array = []) -> PackedStringArray:
	var at := posmod(which, CELL_NAMES.size())
	var words := PackedStringArray([Drops.clean(CELL_NAMES[at])])
	var now := Drops.clean(default_name(at))
	if not now in words:
		words.append(now)
	for found: Dictionary in (catalogs if not catalogs.is_empty() else I18n.catalogs()):
		var said := Drops.clean(String((found["catalog"] as Translation).get_message(
			CELL_NAMES[at])))
		if not said.is_empty() and not said in words:
			words.append(said)
	return words


## **The default a new cell takes** (cells.md §1.7): the first one no cell in any
## slot of any view, living or recorded, wears or is called -- a record still
## counts until a new cell starts in its slot, so the cell that follows a death is
## not given the dead one's name. [param except] is a file whose cell does not
## count. The first of all when every one is taken.
static func next_default(root := ROOT, except := "") -> int:
	var worn := {}
	var called := {}
	for file: String in _files_in(folder_of(root)):
		if not file.begins_with("cell_") or not file.ends_with(".save"):
			continue
		var path := folder_of(root).path_join(file)
		if path == except:
			continue
		var data := CellSave.peek(path)
		if data.is_empty():
			continue
		var typed := str(data["name"])
		if not typed.is_empty():
			called[typed.to_lower()] = true
		else:
			worn[posmod(int(data["default"]), CELL_NAMES.size())] = true
	var catalogs := I18n.catalogs()
	for which in CELL_NAMES.size():
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


## What a slot keeps as [param typed]'s name for a cell wearing default
## [param which]: "" -- the default -- for nothing typed, or for that default's
## very words in any of its languages, so it goes on following the language.
static func typed_name(typed: String, which: int) -> String:
	var called := Drops.clean(typed)
	if called.is_empty() or called in default_words(which):
		return ""
	return called


# --- The migration (cells.md §4) -------------------------------------------------------

## **The chooser's migration** (cells.md §4): every world whose index names a
## cell -- a `generation` key, or one peeked from a file the index does not name
## -- has its cells moved into slots, **the selected world first**, then the
## others in slot order; then each view with no selection yet selects the slot
## that took the selected world's cell, or its first empty slot. Returns how many
## cells it moved. Nothing to move writes nothing.
static func migrate(drops_root := Drops.ROOT, cells_root := ROOT) -> int:
	var index := Drops.read(drops_root)
	var first := int(index["selected"])
	var order: Array[int] = [first]
	for slot in range(1, Drops.SLOTS + 1):
		if slot != first:
			order.append(slot)
	var took := {}
	var ran := false
	var moved := 0
	for slot: int in order:
		var entry := Drops.entry_of(index, slot)
		if bool(entry["empty"]) or (entry["generations"] as Dictionary).is_empty():
			continue
		var path := Drops.path_of(slot, drops_root)
		# Read and never moved: a world this build cannot read is set aside by the
		# run that plays it, not by a menu.
		var data := DropSave.look(path)
		if data.is_empty():
			continue
		var done := migrate_world(data, path, slot, drops_root, cells_root)
		ran = true
		moved += int(done["wrote"])
		if slot == first:
			took = done["moved"]
	if ran:
		settle_selection(took, cells_root)
	return moved


## **One world's cells into slots** (cells.md §4): [param data] is the file at
## [param path] -- slot [param world] of the worlds in [param drops_root], 0 for a
## file of a tool's own -- as drop_save.gd reads it. Each view's cell, full
## vision's first, then point of view's, then any other's by name:
##
## 1. **a slot of its view that already holds this very cell** -- this world's,
##    this drop's, byte for byte, which a migration killed before step 3 leaves --
##    keeps it, and nothing is written;
## 2. **otherwise its view's first empty slot takes it**, its place this world's
##    -- its slot, its drop's number, its rim and its age, so its first resume is
##    the one it would have had before the update -- no name typed, the next free
##    default, its line's birth and age unknown; written, and read back;
## 3. **once every cell is in a slot, the world is written again without them**,
##    and read back, and its index forgets them. **Nothing leaves a world until
##    its slot has been read back**: a cell that could not be written is left in
##    it, and handed back for the run to carry.
##
## Returns `{moved, wrote, left, cleaned}`: the slot each view's cell is in now,
## how many it wrote -- a cell found in its slot already is not written again --
## the cells that could not be moved, and whether the world keeps no cell any more.
static func migrate_world(data: Dictionary, path: String, world: int, drops_root: String,
		cells_root: String) -> Dictionary:
	var cells := DropSave.cells_of(data)
	var drop: Dictionary = data["drop"]
	var where := {"world": world, "drop": int(drop["seed"]), "rim": drop["rim_centre"],
		"age": float(drop["age"])}
	var moved := {}
	var wrote := 0
	var left := {}
	for view: String in _in_view_order(cells.keys()):
		var cell: Dictionary = cells[view]
		var slot := _holding(view, cell, where, cells_root)
		if slot > 0:
			moved[view] = slot
			print("[cells] %s's cell from world %d (drop %d) is in slot %d already" % [
				_view_said(view), world, int(drop["seed"]), slot])
			continue
		slot = first_empty(view, cells_root)
		var file := CellSave.compose(view, "", next_default(cells_root), 0, -1.0, where, cell)
		# **The rules it was kept under go with it**, so a content pack that changed
		# what a body means since converts it as it would have converted the world.
		for key: String in ["rules", "content", "commit"]:
			file[key] = data[key]
		var done := CellSave.write(path_of(view, slot, cells_root), file)
		if done == OK:
			moved[view] = slot
			wrote += 1
			print("[cells] %s's cell from world %d (drop %d, %.0f s) into slot %d" % [
				_view_said(view), world, int(drop["seed"]), float(drop["age"]), slot])
		else:
			left[view] = cell
			print("[cells] %s's cell from world %d could not be moved (%s): it stays there" % [
				_view_said(view), world, error_string(done)])
	var cleaned := left.is_empty()
	if cleaned and not cells.is_empty():
		var bare := data.duplicate()
		bare["cell"] = {}
		bare.erase(DropSave.CELLS)
		var rewritten := DropSave.write(path, bare)
		if rewritten != OK:
			cleaned = false
			print("[cells] world %d keeps its cells for now: it was not written (%s)" % [
				world, error_string(rewritten)])
	if cleaned and world >= 1:
		Drops.forget_cells(world, int(drop["seed"]), drops_root)
	return {"moved": moved, "wrote": wrote, "left": left, "cleaned": cleaned}


## **Each view with no selection yet selects** (cells.md §4): the slot that took
## the selected world's cell of that view, in [param took], or the view's first
## empty slot -- so the first press of each view plays exactly what it played
## before. A view that has one keeps it: a later migration never moves a
## selection. Only the views this build has are selected.
static func settle_selection(took: Dictionary, root := ROOT) -> Error:
	var config := _index(root)
	var changed := false
	for mode: int in RunState.VIEW_ORDER:
		var view := RunState.cell_key(mode)
		if config.has_section_key(SECTION, _key(view)):
			continue
		config.set_value(SECTION, _key(view), int(took.get(view, first_empty(view, root))))
		changed = true
	return _write_index(config, root) if changed else OK


## **[param view]'s first empty slot**: the first, from 1, with no file -- past
## [constant SLOTS] when they are all taken, and nothing is ever deleted to make
## room. A file this build cannot read still holds its slot: it is never written
## over.
static func first_empty(view: String, root := ROOT) -> int:
	var slot := 1
	while FileAccess.file_exists(path_of(view, slot, root)):
		slot += 1
	return slot


## The slot of [param view] that holds [param cell] from [param where] already,
## byte for byte, or 0.
static func _holding(view: String, cell: Dictionary, where: Dictionary, root: String) -> int:
	var bytes := var_to_bytes(cell)
	for slot: int in slots_of(view, root):
		var data := CellSave.peek(path_of(view, slot, root))
		if data.is_empty() or str(data["view"]) != view:
			continue
		var at: Dictionary = data["where"]
		if at.is_empty() or int(at["world"]) != int(where["world"]) \
				or int(at["drop"]) != int(where["drop"]):
			continue
		if var_to_bytes(data["cell"]) == bytes:
			return slot
	return 0


## **The views of a world's cells, in the order they move**: full vision's, then
## point of view's -- the mode select's -- then any other view's by name.
static func _in_view_order(views: Array) -> Array[String]:
	var out: Array[String] = []
	for mode: int in RunState.VIEW_ORDER:
		var view := RunState.cell_key(mode)
		if view in views:
			out.append(view)
	var rest: Array[String] = []
	for view: Variant in views:
		if not str(view) in out:
			rest.append(str(view))
	rest.sort()
	out.append_array(rest)
	return out


## A view's words, in English, for the log: never translated (game/i18n/README.md).
static func _view_said(view: String) -> String:
	for mode: Variant in RunState.CELL_KEYS:
		if str(RunState.CELL_KEYS[mode]) == view:
			return str(RunState.VIEW_WORDS.get(mode, view))
	return view


## The files in [param folder], or none when there is no folder yet: asked of a
## folder that is not there, the engine says so in the log.
static func _files_in(folder: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(folder):
		return PackedStringArray()
	return DirAccess.get_files_at(folder)


# --- The index file -------------------------------------------------------------------

## A view's selection key in the index.
static func _key(view: String) -> String:
	return SELECTED_KEY if view.is_empty() else SELECTED_KEY + "_" + view


## The index as it is, or an empty one when there is none or it does not read.
static func _index(root: String) -> ConfigFile:
	var config := ConfigFile.new()
	if config.load(root.path_join(INDEX)) != OK:
		config = ConfigFile.new()
	return config


## **Writes [param config] as the index**: to `cells.tmp` beside it, read back and
## compared with the bytes meant, and renamed over `cells.cfg` only then -- as
## `drops.cfg` is, so a phone killed mid-write keeps the last good selection.
static func _write_index(config: ConfigFile, root: String) -> Error:
	if not DirAccess.dir_exists_absolute(root):
		var made := DirAccess.make_dir_recursive_absolute(root)
		if made != OK:
			return made
	var tmp := root.path_join(INDEX_TMP)
	var saved := config.save(tmp)
	if saved != OK:
		return saved
	if FileAccess.get_file_as_string(tmp) != config.encode_to_text():
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(tmp, root.path_join(INDEX))


## A number the index holds, whatever a hand or a later build left there.
static func _int_of(value: Variant) -> int:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return int(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return int(str(value)) if str(value).is_valid_int() else 0
	return 0
