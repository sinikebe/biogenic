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
## screen's drops are: `three` (the default: "pond
## water", fourth generation and two hours old and selected; "rain barrel", 25
## minutes old; and slot 3 empty), `long` (an ordinary twenty-letter name
## selected), `wide` (twenty `W`s, the widest name there is) or `wide-other`
## (the same on slot 2, which `--open=confirm` asks about). Add `--language
## fr` before `--` for French.
##
## **The drops are the harness's own**: a folder in `user://`, made as the run
## starts and removed when it ends, which the screen's corner is pointed at before
## it is built. The player's own drops are never read or written. Every run prints
## what is on screen -- the layer, the focus, the chip's and the panel's rects, and
## each name and line with its width in its own font against the room it has.
##
## Excluded from export (`tools/*` on every preset), so none of it ships.

const Drops := preload("res://game/normal/drops.gd")
const RunState := preload("res://game/run_state.gd")
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


func _ready() -> void:
	var screen := "mode_select"
	var open := "none"
	var drops := "three"
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

	_screen = (load(SCREENS[screen]) as PackedScene).instantiate()
	# far.tscn holds an earshot instance, and the corner is that one's.
	_corner = _screen.get_node(^"Earshot/Corner") if _screen.has_node(^"Earshot/Corner") \
		else _screen.get_node(^"Corner")
	_corner.set(&"drops_root", ROOT)
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
		"three":
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
	Drops.note_kept(2, 25.0 * 60.0 + 12.0, 0, ROOT)
	Drops.note_kept(1, 2.0 * 3600.0 + 340.0, 4, ROOT)
	Drops.select(1, ROOT)
	if not first.is_empty():
		Drops.rename(1, first, ROOT)
	if not second.is_empty():
		Drops.rename(2, second, ROOT)
	for slot in [1, 2]:
		var file := FileAccess.open(Drops.path_of(slot, ROOT), FileAccess.WRITE)
		if file != null:
			file.store_8(0)
			file.close()
	return true


func _row(slot: int) -> Node:
	return _corner.get_node("Drops/Panel/Box/Row%d" % slot)


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
	for path: String in ["Cluster/Chip", "Cluster/Gear", "Drops/Panel", "Naming/Panel",
			"Confirm/Panel", "Settings/Panel"]:
		var control := _corner.get_node(path) as Control
		if control.is_visible_in_tree():
			var box := control.get_global_rect()
			print("[corner-shot]   %-14s x %4.0f-%4.0f, y %3.0f-%3.0f, %.0fx%.0f" % [path,
				box.position.x, box.end.x, box.position.y, box.end.y, box.size.x, box.size.y])
	var labels: Array[String] = ["Cluster/Chip/Inside/Caption", "Cluster/Chip/Inside/Name"]
	for slot in range(1, Drops.SLOTS + 1):
		labels.append("Drops/Panel/Box/Row%d/Pick/Lines/Name" % slot)
		labels.append("Drops/Panel/Box/Row%d/Pick/Lines/Stats" % slot)
	labels.append_array(["Naming/Panel/Box/Title", "Confirm/Panel/Box/Title",
		"Confirm/Panel/Box/Line"])
	for path: String in labels:
		var label := _corner.get_node(path) as Label
		if not label.is_visible_in_tree():
			continue
		var font := label.get_theme_font(&"font")
		var px := label.get_theme_font_size(&"font_size")
		var wide := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var trimmed := wide > label.size.x + 0.5 and label.autowrap_mode == TextServer.AUTOWRAP_OFF
		print("[corner-shot]   %-40s %2d px '%s'  %.0f of %.0f px%s" % [path.get_slice("/", 0) + "/…/"
			+ path.get_file() if path.count("/") > 2 else path, px, label.text, wide,
			label.size.x, "  TRIMMED" if trimmed else ""])
	for path: String in ["Drops/Panel/Box/Row1/Rename", "Drops/Panel/Box/Row2/Delete",
			"Naming/Panel/Box/Actions/Back", "Naming/Panel/Box/Actions/Make",
			"Confirm/Panel/Box/Actions/Keep", "Confirm/Panel/Box/Actions/Delete"]:
		var button := _corner.get_node(path) as Button
		if button.is_visible_in_tree():
			var box := button.get_global_rect()
			print("[corner-shot]   %-40s '%s' %.0fx%.0f at x %.0f, y %.0f" % [path, button.text,
				box.size.x, box.size.y, box.position.x, box.position.y])
	var field := _corner.get_node(^"Naming/Panel/Box/Field") as LineEdit
	if field.is_visible_in_tree():
		print("[corner-shot]   field '%s', selected '%s', placeholder '%s', editing %s" % [
			field.text, field.get_selected_text(), field.placeholder_text, str(field.is_editing())])


func _finish(code: int) -> void:
	_forget()
	if _picked:
		RunState.save_locale(_kept_locale)
	get_tree().quit(code)


func _forget() -> void:
	if not DirAccess.dir_exists_absolute(ROOT):
		return
	for file: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(file))
	DirAccess.remove_absolute(ROOT)


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
