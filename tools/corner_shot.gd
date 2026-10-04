extends Node
## Photographs the corner's menu of worlds -- drops, in the code -- on a real
## screen (docs/design/settings.md §4, §5), and **gets there with real touches**
## -- the chip, then a row's own button -- so a shot is evidence about the input
## path as well as the layout.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##       --rendering-driver opengl3 res://tools/corner_shot.tscn -- \
##       --open=drops --out=/tmp/drops.png --size=1280x720
##
## `--screen=` is `mode_select` (the default), `earshot` or `far`. `--open=` is
## `none`, `drops`, `new` (the empty row, so naming a new drop), `rename` (the
## first row's rename), `confirm` (the second row's delete) or `settings` (the
## gear). `--type=<text>` types into the naming field, a key at a time, after it
## opens. `--pick=<locale>` touches that language's row in the settings sheet
## (`--open=settings`), and `--close` then touches `close`: the chip behind the
## sheet has to say its words again, French to English included (§3.3). The
## language this machine keeps is put back afterwards. `--drops=` is what the
## screen's drops are: `three` (the default: "pond water", two hours old and
## selected; "rain barrel", 25 minutes old; and slot 3 empty), `long` (an
## ordinary twenty-letter name selected), `wide` (twenty `W`s, the widest name
## there is), `wide-other` (the same on slot 2, which `--open=confirm` asks
## about) or `views` (all three: "hay infusion" too, three days old). Add
## `--language fr` before `--` for French.
##
## **Your cells** (docs/design/cells-ux.md §7): `--cells=` is what the screen's
## cells are, in the same folder -- `two` (the default: full vision's slot 1 a
## slipper of the fourth generation, two hours old and hungry, in "pond water",
## and chosen; slot 2 a trumpet of the second, 25 minutes old, in "rain barrel";
## slot 3 empty; point of view's none), `elsewhere` (the slipper kept in "rain
## barrel", so its button says `from`), `dead` (the slipper died in "pond water":
## its record, chosen), `wide` (twenty `W`s at generation 12, 47 hours old and
## starving, in "hay infusion" -- with `--drops=views`; without, that world is gone
## -- a trumpet in a friend's water, and a proteus in a world that is gone), `fork`
## (the slipper with a gene waiting, its beam's fork open and a dose in it),
## `fresh` (no cell anywhere) or `pov` (the slipper is point of view's, a bell full
## vision's). `--open=cells` touches full vision's chevron,
## `cells-pov` point of view's; `look` (and `look2`, `look3`) then a row's `look`;
## `cell-rename` and `cell-delete` the detailed view's own. `--numbers=1` turns the
## figure's switch on first, `--read=<slot>` reads a slot of it by touch, and
## `--hover=<chevron|full>` leaves the mouse over the full vision chevron or button.
##
## **The drops are the harness's own**: a folder in `user://`, made as the run
## starts and removed when it ends, which the screen's corner is pointed at before
## it is built -- and so are the cells, in it. The player's own drops and cells are
## never read or written. Every run prints what is on screen -- the layer, the
## focus, the chip's and the panel's rects, and each name and line with its width
## in its own font against the room it has.
##
## Excluded from export (`tools/*` on every preset), so none of it ships.

const Drops := preload("res://game/normal/drops.gd")
const RunState := preload("res://game/run_state.gd")
const Cells := preload("res://game/normal/cells.gd")
const CellSave := preload("res://game/normal/cell_save.gd")
## The worlds' numbers, as the harness's index gives them: a cell's place is
## checked against them (cells.md §1.4).
const SEEDS: Array[int] = [1111, 2222, 3333]
const SCREENS := {
	"mode_select": "res://game/mode_select.tscn",
	"earshot": "res://game/net/earshot.tscn",
	"far": "res://game/net/far.tscn",
}
const ROOT := "user://corner_shot"
## An ordinary long name, at the limit, and the widest one there is.
const LONG_NAME := "the old birdbath, ii"
const WIDE_NAME := "WWWWWWWWWWWWWWWWWWWW"

var _screen: Control = null
var _corner: Control = null
## The language this machine kept before a `--pick`, put back at the end.
var _kept_locale := ""
var _picked := false
## The numbers switch this machine kept, put back at the end.
var _numbers_before := false


func _ready() -> void:
	var screen := "mode_select"
	var open := "none"
	var drops := "three"
	var cells := "two"
	var numbers := -1
	var read := -1
	var hover := ""
	var typed := ""
	var pick := ""
	var close := false
	var out_path := "user://corner_shot.png"
	var wait := 1.0
	var size := Vector2i.ZERO
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--screen="):
			screen = text.trim_prefix("--screen=")
		elif text.begins_with("--open="):
			open = text.trim_prefix("--open=")
		elif text.begins_with("--drops="):
			drops = text.trim_prefix("--drops=")
		elif text.begins_with("--cells="):
			cells = text.trim_prefix("--cells=")
		elif text.begins_with("--numbers="):
			numbers = int(text.trim_prefix("--numbers="))
		elif text.begins_with("--read="):
			read = int(text.trim_prefix("--read="))
		elif text.begins_with("--hover="):
			hover = text.trim_prefix("--hover=")
		elif text.begins_with("--type="):
			typed = text.trim_prefix("--type=")
		elif text.begins_with("--pick="):
			pick = text.trim_prefix("--pick=")
		elif text == "--close":
			close = true
		elif text.begins_with("--out="):
			out_path = text.trim_prefix("--out=")
		elif text.begins_with("--wait="):
			wait = float(text.trim_prefix("--wait="))
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				size = Vector2i(int(parts[0]), int(parts[1]))
	# Window only: content_scale_size would override the project's expand stretch
	# and render 1:1 -- tools/shot.gd's own note.
	if size != Vector2i.ZERO:
		get_window().size = size
	if not SCREENS.has(screen):
		push_error("[corner-shot] no screen called %s" % screen)
		get_tree().quit(1)
		return
	_forget()
	if not _make_drops(drops):
		push_error("[corner-shot] no drops called %s" % drops)
		get_tree().quit(1)
		return
	if not _make_cells(cells):
		push_error("[corner-shot] no cells called %s" % cells)
		get_tree().quit(1)
		return
	# The switch the figure turns on is the player's remembered preference: kept
	# here, and put back.
	_numbers_before = RunState.load_numbers()
	if numbers >= 0:
		RunState.save_numbers(numbers > 0)

	_screen = (load(SCREENS[screen]) as PackedScene).instantiate()
	# far.tscn holds an earshot instance, and the corner is that one's.
	_corner = _screen.get_node(^"Earshot/Corner") if _screen.has_node(^"Earshot/Corner") \
		else _screen.get_node(^"Corner")
	_corner.set(&"drops_root", ROOT)
	_corner.set(&"cells_root", ROOT)
	get_tree().root.add_child.call_deferred(_screen)
	await _screen.ready
	get_tree().current_scene = _screen
	await _settle(0.4)

	match open:
		"none":
			pass
		"settings":
			await _touch(_corner.get_node(^"Cluster/Gear"))
		"drops", "new", "rename", "confirm":
			await _touch(_corner.get_node(^"Cluster/Chip"))
			await _settle(0.3)
			match open:
				"new":
					await _touch(_row(3).get_node(^"Pick"))
				"rename":
					await _touch(_row(1).get_node(^"Rename"))
				"confirm":
					await _touch(_row(2).get_node(^"Delete"))
		"cells", "cells-pov", "look", "look2", "look3", "cell-rename", "cell-delete":
			var block := "PovBlock" if open == "cells-pov" else "FullBlock"
			await _touch(_screen.get_node("Center/Column/%s/Row/Cells" % block))
			await _settle(0.3)
			if open.begins_with("look") or open.begins_with("cell-"):
				var which := 1 if open.length() <= 4 or open.begins_with("cell-") \
					else int(open.right(1))
				await _touch(_cell_row(which).get_node(^"Look"))
				await _settle(0.4)
				if read >= 0:
					await _touch(_corner.get_node(
						"Cell/Center/Columns/Figure/CellFigure/Figure/Slots/Slot%d" % read))
				match open:
					"cell-rename":
						await _touch(_corner.get_node(^"Cell/Center/Columns/Side/Actions/Rename"))
					"cell-delete":
						await _touch(_corner.get_node(^"Cell/Center/Columns/Side/Actions/Delete"))
		_:
			push_error("[corner-shot] nothing to open called %s" % open)
			await _finish(1)
			return
	if not typed.is_empty():
		await _settle(0.2)
		for character in typed:
			await _key_text(character)
	if not pick.is_empty():
		_kept_locale = RunState.load_locale()
		_picked = true
		await _settle(0.2)
		await _touch(_corner.get_node("Settings/Panel/Box/Languages/Rows/Row_%s" % pick))
		await _settle(0.3)
	if close:
		await _touch(_corner.get_node(^"Settings/Panel/Box/Close"))
	await _park_mouse()
	if hover == "chevron":
		await _hover(_screen.get_node(^"Center/Column/FullBlock/Row/Cells"))
	elif hover == "full":
		await _hover(_screen.get_node(^"Center/Column/FullBlock/Row/Full"))
	await _settle(wait)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_path) != OK:
		push_error("[corner-shot] could not write %s" % out_path)
		await _finish(1)
		return
	print("[corner-shot] %s  %dx%d  screen=%s open=%s drops=%s" % [out_path, image.get_width(),
		image.get_height(), screen, open, drops])
	_report()
	await _finish(0)


## **The harness's drops**, in its own folder: an index written through drops.gd,
## and a file for each drop that has been swum in, so its line says its age.
func _make_drops(which: String) -> bool:
	var first := ""
	var second := ""
	match which:
		"three", "views":
			pass
		"long":
			first = LONG_NAME
		"wide":
			first = WIDE_NAME
		"wide-other":
			second = WIDE_NAME
		_:
			return false
	Drops.make(2, "", ROOT)
	Drops.note_kept(2, 25.0 * 60.0 + 12.0, SEEDS[1], ROOT)
	if which == "views":
		Drops.make(3, "", ROOT)
		Drops.note_kept(3, 3.0 * 86400.0 + 600.0, SEEDS[2], ROOT)
	Drops.note_kept(1, 2.0 * 3600.0 + 340.0, SEEDS[0], ROOT)
	Drops.select(1, ROOT)
	if not first.is_empty():
		Drops.rename(1, first, ROOT)
	if not second.is_empty():
		Drops.rename(2, second, ROOT)
	for slot: int in ([1, 2, 3] if which == "views" else [1, 2]):
		var file := FileAccess.open(Drops.path_of(slot, ROOT), FileAccess.WRITE)
		if file != null:
			file.store_8(0)
			file.close()
	return true


## **The harness's cells** (cells-ux.md §7), in the drops' folder: each slot a
## real file, through cell_save.gd, its place in one of the harness's worlds by
## that world's number.
func _make_cells(which: String) -> bool:
	var full := RunState.cell_key(RunState.Mode.FULL_VISION)
	var pov := RunState.cell_key(RunState.Mode.POV)
	var slipper := _cell(4, 34.0, 0.62, false)
	var trumpet := _cell(2, 30.0, 0.2, false)
	match which:
		"two":
			_keep_cell(full, 1, "", 0, 2.0 * 3600.0 + 340.0, 1, slipper)
			_keep_cell(full, 2, "", 2, 25.0 * 60.0 + 12.0, 2, trumpet)
		"elsewhere":
			_keep_cell(full, 1, "", 0, 2.0 * 3600.0 + 340.0, 2, slipper)
			_keep_cell(full, 2, "", 2, 25.0 * 60.0 + 12.0, 2, trumpet)
		"dead":
			_keep_cell(full, 1, "", 0, 2.0 * 3600.0 + 340.0, 1, slipper,
				{"cause": 0, "at": 1759500000})
			_keep_cell(full, 2, "", 2, 25.0 * 60.0 + 12.0, 2, trumpet)
		"wide":
			var wide := _cell(12, 38.0, 1.0, false)
			_keep_cell(full, 1, WIDE_NAME, 0, 47.0 * 3600.0 + 60.0, 3, wide)
			var away := _cell(2, 30.0, 0.2, false)
			away["elsewhere"] = true
			_keep_cell(full, 2, "", 2, 25.0 * 60.0 + 12.0, 1, away)
			_keep_cell(full, 3, "", 3, 3.0 * 60.0 + 5.0, -1, _cell(1, 26.0, 0.1, false))
		"fork":
			_keep_cell(full, 1, "", 0, 2.0 * 3600.0 + 340.0, 1, _cell(4, 34.0, 0.62, true))
			_keep_cell(full, 2, "", 2, 25.0 * 60.0 + 12.0, 2, trumpet)
		"pov":
			_keep_cell(pov, 1, "", 0, 2.0 * 3600.0 + 340.0, 1, slipper)
			_keep_cell(full, 1, "", 1, 25.0 * 60.0 + 12.0, 2, trumpet)
		"fresh":
			pass
		_:
			return false
	return true


## One slot's file: [param view]'s slot [param slot], called [param named] or
## wearing default [param which], [param lived] seconds old, kept in world
## [param world] -- -1 for a world that is gone -- and [param died] a record's.
func _keep_cell(view: String, slot: int, named: String, which: int, lived: float,
		world: int, cell: Dictionary, died: Dictionary = {}) -> void:
	var where := {"world": maxi(world, 1), "drop": SEEDS[world - 1] if world >= 1 else 9999,
		"rim": Vector2.ZERO, "age": 120.0}
	var data := CellSave.compose(view, named, which, 1759400000, lived, where, cell, died)
	var done := CellSave.write(Cells.path_of(view, slot, ROOT), data)
	if done != OK:
		push_error("[corner-shot] cell %s/%d not kept: %s" % [view, slot, error_string(done)])


## **A cell as a slot keeps it**: the mock's own (cells-ux.md §7) -- a mouth of two
## copies at the nose, a cirrus on the flank, a tail of three, a beam at level 1
## forward to starboard and a poison inside -- at [param generation], [param radius]
## and [param hunger]. [param fork] has its beam at the fork, a gene waiting and a
## dose taken.
static func _cell(generation: int, radius: float, hunger: float, fork: bool) -> Dictionary:
	var dna := {"cytostome": 2, "cirrus": 1, "flagellum": 3, "ocellus": 1, "veneneux": 1}
	var order := PackedStringArray(["cytostome", "cirrus", "flagellum", "ocellus", "", "", ""])
	var waiting: Array = []
	var levels := {"ocellus": [12.0, ""]}
	var loads := PackedFloat64Array([0.0, 0.0, 0.0])
	if fork:
		waiting = [["chemocyte", 1, 31.5]]
		levels = {"ocellus": [125.0, ""]}
		loads = PackedFloat64Array([3.0, 0.0, 0.0])
	return {
		"body": {"at": Vector2(40.0, -120.0), "heading": 0.3, "velocity": Vector2.ZERO,
			"radius": radius, "wound": 0.0, "omega": 0.0, "wander": 0.0, "impulse": 0.0,
			"dash": 0.0, "effort": 0.0},
		"genome": {"dna": dna, "order": order, "body": dna.duplicate(), "worn": order,
			"bonus": 0, "gift": "", "waiting": waiting, "levels": levels},
		"hunger": hunger,
		"starve": 0.0,
		"generation": generation,
		"id": 40 + generation,
		"parent": 39 + generation,
		"lineage": 7,
		"sense_clock": 30.0,
		"sensed": true,
		"said_divide": true,
		"daughters": [],
		"water": {"grace": 0.0, "dart": 0.0, "bite": 0.0, "first": 0},
		"loads": loads,
	}


func _row(slot: int) -> Node:
	return _corner.get_node("Drops/Panel/Box/Row%d" % slot)


func _cell_row(slot: int) -> Node:
	return _corner.get_node("Cells/Panel/Box/Scroll/Rows/Row%d" % slot)


## **What is on screen, measured**: the layer on top and the focus; the chip, the
## gear and the open panel against the canvas; and every name and line with its
## width in its own font against the width its label has, "TRIMMED" where the
## words do not fit and end in "…".
func _report() -> void:
	var canvas := get_viewport().get_visible_rect().size
	var open: Variant = _corner.get(&"_open")
	var focus := get_viewport().gui_get_focus_owner()
	print("[corner-shot]   canvas %dx%d, layer %s, focus %s" % [roundi(canvas.x), roundi(canvas.y),
		"none" if open == null else str((open as Node).name),
		"nothing" if focus == null else str(focus.get_path()).trim_prefix(str(_screen.get_path()) + "/")])
	for path: String in ["Cluster/Chip", "Cluster/Gear", "Drops/Panel",
			"Drops/Panel/Box/Row1/Pick", "Drops/Panel/Box/Row2/Pick", "Drops/Panel/Box/Row3/Pick",
			"Cells/Panel", "Cells/Panel/Box/Scroll/Rows/Row1/Pick",
			"Cells/Panel/Box/Scroll/Rows/Row2/Pick", "Cells/Panel/Box/Scroll/Rows/Row3/Pick",
			"Cell/Center/Columns/Side", "Cell/Center/Columns/Figure",
			"Cell/Center/Columns/Side/Actions/Rename", "Cell/Center/Columns/Side/Close",
			"Cell/Center/Columns/Figure/CellFigure/Lines/NumbersToggle",
			"Naming/Panel", "Confirm/Panel", "Settings/Panel"]:
		if not _corner.has_node(path):
			continue
		var control := _corner.get_node(path) as Control
		if control.is_visible_in_tree():
			var box := control.get_global_rect()
			print("[corner-shot]   %-14s x %4.0f-%4.0f, y %3.0f-%3.0f, %.0fx%.0f" % [path,
				box.position.x, box.end.x, box.position.y, box.end.y, box.size.x, box.size.y])
	var labels: Array[String] = ["Cluster/Chip/Inside/Caption", "Cluster/Chip/Inside/Name"]
	for slot in range(1, Drops.SLOTS + 1):
		labels.append("Drops/Panel/Box/Row%d/Pick/Lines/Name" % slot)
		labels.append("Drops/Panel/Box/Row%d/Pick/Lines/Stats" % slot)
	labels.append_array(["Cells/Panel/Box/Caption", "Cells/Panel/Box/Note"])
	for slot in range(1, 4):
		labels.append("Cells/Panel/Box/Scroll/Rows/Row%d/Pick/Lines/Name" % slot)
		labels.append("Cells/Panel/Box/Scroll/Rows/Row%d/Pick/Lines/Stats" % slot)
	labels.append_array(["Cell/Center/Columns/Side/Name", "Cell/Center/Columns/Side/Kind",
		"Cell/Center/Columns/Side/Age", "Cell/Center/Columns/Side/Where/Caption",
		"Cell/Center/Columns/Side/Where/Value", "Cell/Center/Columns/Side/Then",
		"Naming/Panel/Box/Title", "Confirm/Panel/Box/Title", "Confirm/Panel/Box/Line"])
	for path: String in labels:
		var label := _corner.get_node(path) as Label
		if not label.is_visible_in_tree():
			continue
		var font := label.get_theme_font(&"font")
		var px := label.get_theme_font_size(&"font_size")
		# A label may say more than one line: each is measured against the width
		# on its own, and each said.
		for said: String in label.text.split("\n"):
			var wide := font.get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var trimmed := wide > label.size.x + 0.5 \
				and label.autowrap_mode == TextServer.AUTOWRAP_OFF
			print("[corner-shot]   %-40s %2d px '%s'  %.0f of %.0f px%s" % [
				path.get_slice("/", 0) + "/…/" + path.get_file() if path.count("/") > 2 else path,
				px, said, wide, label.size.x, "  TRIMMED" if trimmed else ""])
	for path: String in ["Drops/Panel/Box/Row1/Rename", "Drops/Panel/Box/Row2/Delete",
			"Naming/Panel/Box/Actions/Back", "Naming/Panel/Box/Actions/Make",
			"Confirm/Panel/Box/Actions/Keep", "Confirm/Panel/Box/Actions/Delete"]:
		var button := _corner.get_node(path) as Button
		if button.is_visible_in_tree():
			var box := button.get_global_rect()
			print("[corner-shot]   %-40s '%s' %.0fx%.0f at x %.0f, y %.0f" % [path, button.text,
				box.size.x, box.size.y, box.position.x, box.position.y])
	for path: String in ["Center/Column/FullBlock/Row/Full/Lines/Cell",
			"Center/Column/PovBlock/Row/Pov/Lines/Cell", "Buttons/First/Lines/Cell",
			"Buttons/Second/Lines/Cell"]:
		var line := _screen.get_node_or_null(path) as Label
		if line == null or not line.is_visible_in_tree():
			continue
		var font := line.get_theme_font(&"font")
		var px := line.get_theme_font_size(&"font_size")
		print("[corner-shot]   %-40s %2d px '%s'  %.0f of %.0f px" % [path.get_file()
			+ " of " + path.get_slice("/", 2), px, line.text, font.get_string_size(line.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, line.size.x])
	for path: String in ["Center/Column/FullBlock/Row/Full", "Center/Column/FullBlock/Row/Cells",
			"Center/Column/PovBlock/Row/Pov", "Center/Column/PovBlock/Row/Cells"]:
		var button := _screen.get_node_or_null(path) as Control
		if button != null and button.is_visible_in_tree():
			var box := button.get_global_rect()
			print("[corner-shot]   %-40s x %4.0f-%4.0f, y %3.0f-%3.0f" % [path.get_slice("/", 2)
				+ "/" + path.get_file(), box.position.x, box.end.x, box.position.y, box.end.y])
	var field := _corner.get_node(^"Naming/Panel/Box/Field") as LineEdit
	if field.is_visible_in_tree():
		print("[corner-shot]   field '%s', selected '%s', placeholder '%s', editing %s" % [
			field.text, field.get_selected_text(), field.placeholder_text, str(field.is_editing())])


func _finish(code: int) -> void:
	_forget()
	if _picked:
		RunState.save_locale(_kept_locale)
	if RunState.load_numbers() != _numbers_before:
		RunState.save_numbers(_numbers_before)
	get_tree().quit(code)


func _forget() -> void:
	var folder := Cells.folder_of(ROOT)
	for dir: String in [folder, ROOT]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)


# ---------------------------------------------------------------------------
# Input, sent the way a device sends it.
# ---------------------------------------------------------------------------

func _touch(control: Control) -> void:
	if control == null or not control.is_visible_in_tree():
		push_error("[corner-shot] nothing to touch there")
		return
	var at := control.global_position + control.size * 0.5
	var where := at * get_viewport().get_screen_transform().get_scale() \
		+ get_viewport().get_screen_transform().get_origin()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = where
		Input.parse_input_event(event)
		await get_tree().process_frame
	print("[corner-shot] touch at canvas %.0f,%.0f" % [at.x, at.y])


## One character typed, as a keyboard sends it.
func _key_text(character: String) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


## The mouse moved over [param control] and left there, for a hover's frame.
func _hover(control: Control) -> void:
	if control == null:
		return
	var at := control.global_position + control.size * 0.5
	var event := InputEventMouseMotion.new()
	event.position = at * get_viewport().get_screen_transform().get_scale() \
		+ get_viewport().get_screen_transform().get_origin()
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame


## **A lifted finger leaves no hover on a phone**, and the mouse a touch is
## emulated as would: it is moved off the corner before the shot.
func _park_mouse() -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(4.0, 4.0) * get_viewport().get_screen_transform().get_scale()
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame


func _settle(seconds: float) -> void:
	var spent := 0.0
	while spent < seconds:
		await get_tree().process_frame
		spent += 1.0 / 60.0
