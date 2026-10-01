extends Node
## CI probe: Android Back must walk back out of the game without killing the app.
##
## This exists because the bug it guards could not be reproduced in this repo.
## `tools/drive.gd --back-at=` fired only `NOTIFICATION_WM_GO_BACK_REQUEST`, and
## a real Back also emits `go_back_requested`, which `SceneTree` has connected to
## its own quit check. So a handler that flips `quit_on_go_back` while the
## notification is still propagating has it read microseconds later, by the same
## Back it is still inside, and the app dies with the next screen one frame old.
## That is issue #23 exactly: reproducible on a phone and nowhere else.
##
## The restore therefore has to be deferred, and a deferred restore is invisible
## to a harness that dies with the scene it was driving -- `tools/drive.gd` is
## `current_scene`, so `change_scene_to_file` frees it mid-test. This node
## reparents itself to the tree root and outlives the transition, which is the
## only vantage point from which "the flag came back" can be seen at all.
##
## **And the settings sheet is what Back closes first** (docs/design/settings.md
## §1.3), on the view chooser, the earshot screen and the pause screen. Android
## Back reaches a screen before the sheet over it, because a notification goes
## parent first, so each screen asks the corner before doing what Back does --
## and a Back that closed the sheet must not also leave the chooser, the earshot
## page or the pause screen. Esc reaches the corner first, and is checked too.
##
## **And the drop menu, one layer at a time** (settings.md §1.3, §4, §5): on the
## view chooser and the earshot screen, Back and Esc close the menu; over it, they
## take naming and the delete confirm back to the menu -- nothing made, nothing
## deleted -- and only the next one closes the menu. Esc does it from inside the
## naming field too, which keeps Esc for itself unless the corner asks first. The
## menu is opened on a folder of drops of the probe's own, never the player's. The
## drop chip shows on the chooser and on CHOOSE, and not on a far page or the pause
## screen.
##
## Prints one line per check and `ALL PASS` only if every one held. CI asserts on
## that marker rather than on the exit code: Godot exits 0 even after a parse
## error, and a tree that quits mid-probe never reaches the final print either.

const MODE_SELECT := "res://game/mode_select.tscn"
const EARSHOT := "res://game/net/earshot.tscn"
const NORMAL := "res://game/normal/normal_mode.tscn"
const LAUNCHER := "res://addons/launcher/launcher.tscn"
const FAR := "res://game/net/far.tscn"
const Drops := preload("res://game/normal/drops.gd")
## **The drops the menu is opened on**: a folder of the probe's own, with a drop in
## slot 1, selected, one in slot 2 and slot 3 empty -- never the player's.
const DROPS_ROOT := "user://back_probe_drops"

## Frames to let a deferred scene change flush and the new scene reach `_ready`.
const SETTLE_FRAMES := 4

var _failed := 0
var _started := false


func _ready() -> void:
	# Deferred: reparenting while the tree is still building this scene is the
	# tree telling you it is busy adding and removing children.
	_detach.call_deferred()


func _detach() -> void:
	if _started:
		return
	_started = true
	# The tree reference has to be taken before the reparent: `remove_child`
	# puts this node outside the tree, and `get_tree()` is null from there.
	var tree := get_tree()
	var parent := get_parent()
	if parent != null and parent != tree.root:
		parent.remove_child(self)
		tree.root.add_child(self)
	_run()


func _run() -> void:
	_forget_drops()
	Drops.make(2, "", DROPS_ROOT)
	Drops.select(1, DROPS_ROOT)
	get_tree().change_scene_to_file(MODE_SELECT)
	await _settle()
	_check("the view chooser is on screen", _scene_path() == MODE_SELECT)
	_check("the chooser has taken Back off the tree",
		not get_tree().quit_on_go_back)

	# **The sheet before the screen**, by both doors.
	await _sheet_first("the view chooser", MODE_SELECT)
	await _drops_first("the view chooser", MODE_SELECT)

	# The earshot screen: the sheet first, then Back is the way back out.
	get_tree().change_scene_to_file(EARSHOT)
	await _settle()
	_check("the earshot screen is on screen", _scene_path() == EARSHOT)
	await _sheet_first("the earshot screen", EARSHOT)
	await _drops_first("the earshot screen", EARSHOT)
	_press_back()
	await _settle()
	_check("then Back leaves the earshot screen for the view chooser",
		_scene_path() == MODE_SELECT)

	# A far page is always a guest's: its corner has the gear and no chip.
	get_tree().change_scene_to_file(FAR)
	await _settle()
	var far_corner := _corner()
	_check("a far page carries the gear and no drop chip", far_corner != null
		and (far_corner.get_node(^"Cluster/Gear") as Control).is_visible_in_tree()
		and not (far_corner.get_node(^"Cluster/Chip") as Control).is_visible_in_tree())
	_press_back()
	await _settle()
	_check("and Back leaves it for the view chooser", _scene_path() == MODE_SELECT)

	await _pause_sheet()

	get_tree().change_scene_to_file(MODE_SELECT)
	await _settle()
	_check("the view chooser is on screen again", _scene_path() == MODE_SELECT)
	_press_back()
	await _settle()

	# Reaching this line at all is the headline assertion. If the restore had
	# run inside the Back event, `SceneTree` would have set `_quit` during that
	# press and this await would never have resumed.
	_check("Back did not kill the app", true)
	_check("Back landed on the launcher", _scene_path() == LAUNCHER)
	# The restore, seen from outside the event that used to swallow it. This is
	# what makes Back quit from the launcher, which is where Android expects it
	# to quit -- and it is the single assertion no other harness here can make.
	_check("Back quits again now the launcher owns the screen",
		get_tree().quit_on_go_back)

	# **Settings from the launcher's own menu** (settings.md §1.4): the
	# "settings" button launcher_config.tres lists between play and quit, heard
	# by game/boot.gd, opens the sheet over the launcher. The launcher has no Back
	# of its own, so Back there quits the app -- and with the sheet up it must
	# only close the sheet: the probe pressing Back with the guard missing would
	# quit, and never print ALL PASS.
	var boot := get_tree().root.get_node_or_null(^"GameBoot")
	_check("the game's hook is loaded before the launcher", boot != null)
	for door: String in ["Back", "Esc"]:
		var button := _launcher_button("settings")
		_check("the launcher lists settings (%s)" % door, button != null)
		if boot == null or button == null:
			break
		button.pressed.emit()
		await _settle()
		_check("settings opens the sheet over the launcher (%s)" % door,
			bool(boot.call(&"is_sheet_open")) and _scene_path() == LAUNCHER)
		_check("and Back stops quitting while it is up (%s)" % door,
			not get_tree().quit_on_go_back)
		if door == "Back":
			_press_back()
		else:
			await _press_esc()
		await _settle()
		_check("%s closes the sheet and the app stays" % door,
			not bool(boot.call(&"is_sheet_open")) and _scene_path() == LAUNCHER)
		_check("and Back quits from the launcher again (%s)" % door,
			get_tree().quit_on_go_back)

	_forget_drops()
	if _failed == 0:
		print("[back-probe] ALL PASS")
	else:
		print("[back-probe] %d FAILED" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _settle() -> void:
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame


## **On [param screen], the sheet closes first**: opened from the corner, it is
## what Back closes, and then what Esc closes, and the screen at [param path]
## stays where it was each time.
func _sheet_first(screen: String, path: String) -> void:
	var corner := _corner()
	_check("%s carries the corner" % screen, corner != null)
	if corner == null:
		return
	corner.call(&"open_settings")
	await _settle()
	_check("the settings sheet opens over %s" % screen, bool(corner.call(&"is_open")))
	_press_back()
	await _settle()
	_check("Back closes the sheet over %s" % screen,
		is_instance_valid(corner) and not bool(corner.call(&"is_open")))
	_check("and %s stays on screen" % screen, _scene_path() == path)
	_check("and does not start leaving: Back still does not quit",
		not get_tree().quit_on_go_back)
	if not is_instance_valid(corner):
		# Back left the screen with the sheet: failed above, and nothing is left
		# to press Esc on.
		return
	corner.call(&"open_settings")
	await _settle()
	await _press_esc()
	_check("Esc closes the sheet over %s" % screen,
		is_instance_valid(corner) and not bool(corner.call(&"is_open")))
	_check("and %s stays on screen after Esc" % screen, _scene_path() == path)


## **The pause screen**: a run with nothing kept, paused by Esc, the sheet opened
## over it. Back closes the sheet and leaves pause open; the next Back resumes.
## And pause closing takes an open sheet with it, so it is not still open the
## next time pause is (settings.md §1.1).
func _pause_sheet() -> void:
	var tree := get_tree()
	var old := tree.current_scene
	# Built by hand rather than by path, so `keep` is set before the run reads it:
	# a probe must not open or write the player's own drop.
	var run := (load(NORMAL) as PackedScene).instantiate()
	run.set(&"keep", "")
	tree.root.add_child(run)
	tree.current_scene = run
	if old != null:
		old.queue_free()
	await _settle()
	await _press_esc()
	_check("Esc opens the pause screen", bool(run.get(&"_menu_open")))
	var corner := _corner()
	_check("the pause screen carries the corner", corner != null)
	if corner == null:
		return
	_check("and no drop chip: a run plays the drop it opened on",
		not (corner.get_node(^"Cluster/Chip") as Control).is_visible_in_tree())
	corner.call(&"open_settings")
	await _settle()
	_check("the settings sheet opens over the pause screen", bool(corner.call(&"is_open")))
	_press_back()
	await _settle()
	_check("Back closes the sheet over the pause screen", not bool(corner.call(&"is_open")))
	_check("and the pause screen stays open", bool(run.get(&"_menu_open")))
	if not bool(run.get(&"_menu_open")):
		# Back went through the sheet to the screen under it: failed above, and
		# the rest would be asked of a screen that is not there.
		return
	corner.call(&"open_settings")
	await _settle()
	await _press_esc()
	_check("Esc closes the sheet over the pause screen", not bool(corner.call(&"is_open")))
	_check("and the pause screen stays open after Esc", bool(run.get(&"_menu_open")))
	_press_back()
	await _settle()
	_check("the next Back resumes", not bool(run.get(&"_menu_open")))
	await _press_esc()
	corner.call(&"open_settings")
	await _settle()
	run.call(&"_set_menu", false)
	await _settle()
	_check("pause closing from under the sheet closes the sheet",
		not bool(corner.call(&"is_open")))


## **On [param screen], the drop menu closes one layer at a time**: Back and Esc
## close the menu, and the screen at [param path] stays; over the menu, naming a new
## drop and renaming one go back to the menu on Back and on Esc -- the Esc pressed
## inside the naming field -- with nothing made or renamed, and so does the delete
## confirm, with nothing deleted; only the next one closes the menu.
func _drops_first(screen: String, path: String) -> void:
	var corner := _corner()
	if corner == null:
		return
	_check("%s shows the drop chip" % screen,
		(corner.get_node(^"Cluster/Chip") as Control).is_visible_in_tree())
	corner.set(&"drops_root", DROPS_ROOT)
	var before := FileAccess.get_file_as_bytes(DROPS_ROOT.path_join(Drops.INDEX))
	corner.call(&"open_drops")
	await _settle()
	_check("the drop menu opens over %s" % screen, _layer(corner) == "Drops")
	_press_back()
	await _settle()
	_check("Back closes the drop menu over %s, and it stays" % screen,
		_layer(corner) == "" and _scene_path() == path and not get_tree().quit_on_go_back)
	corner.call(&"open_drops")
	await _settle()
	await _press_esc()
	_check("Esc closes the drop menu over %s, and it stays" % screen,
		_layer(corner) == "" and _scene_path() == path)
	for naming: Array in [[3, "naming a new drop"], [1, "renaming a drop"]]:
		if not is_instance_valid(corner):
			# Back left the screen with a layer open: failed above, and nothing is
			# left to open a layer on.
			return
		corner.call(&"open_drops")
		await _settle()
		corner.call(&"open_naming", naming[0])
		await _settle()
		var field := corner.get_node(^"Naming/Panel/Box/Field") as LineEdit
		_check("%s opens over the menu on %s, the field typing and its words selected" % [
			naming[1], screen], _layer(corner) == "Naming" and field.has_focus()
			and field.is_editing() and field.has_selection())
		_press_back()
		await _settle()
		_check("Back from %s goes back to the menu" % naming[1],
			_layer(corner) == "Drops" and _scene_path() == path)
		if not is_instance_valid(corner):
			return
		corner.call(&"open_naming", naming[0])
		await _settle()
		await _press_esc()
		_check("Esc in the field from %s goes back to the menu" % naming[1],
			_layer(corner) == "Drops" and _scene_path() == path)
		_press_back()
		await _settle()
		_check("and the next Back closes the menu, %s still there" % screen,
			_layer(corner) == "" and _scene_path() == path)
	if not is_instance_valid(corner):
		return
	corner.call(&"open_drops")
	await _settle()
	corner.call(&"open_confirm", 2)
	await _settle()
	_check("the delete confirm opens over the menu on %s" % screen, _layer(corner) == "Confirm")
	_press_back()
	await _settle()
	_check("Back from the confirm keeps the drop and goes back to the menu",
		_layer(corner) == "Drops"
		and not bool(Drops.entry_of(Drops.read(DROPS_ROOT), 2)["empty"]))
	if not is_instance_valid(corner):
		return
	corner.call(&"open_confirm", 2)
	await _settle()
	await _press_esc()
	_check("so does Esc", _layer(corner) == "Drops")
	await _press_esc()
	_check("and the next Esc closes the menu, %s still there" % screen,
		_layer(corner) == "" and _scene_path() == path)
	_check("none of it changed the drops",
		FileAccess.get_file_as_bytes(DROPS_ROOT.path_join(Drops.INDEX)) == before)


## Which of the corner's layers is on top: its node's name, "" for none, and
## "gone" when Back took the screen and its corner with it.
func _layer(corner: Variant) -> String:
	if not is_instance_valid(corner):
		return "gone"
	var open: Variant = (corner as Node).get(&"_open")
	return "" if open == null else str((open as Node).name)


## Nothing of the probe's drops left in `user://`.
func _forget_drops() -> void:
	if not DirAccess.dir_exists_absolute(DROPS_ROOT):
		return
	for file: String in DirAccess.get_files_at(DROPS_ROOT):
		DirAccess.remove_absolute(DROPS_ROOT.path_join(file))
	DirAccess.remove_absolute(DROPS_ROOT)


## The current scene's corner: the screen's last child, the pause screen's, or
## the one of the earshot screen far.tscn holds.
func _corner() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for path: NodePath in [^"Corner", ^"Hud/Pause/Corner", ^"Earshot/Corner"]:
		var found := scene.get_node_or_null(path)
		if found != null:
			return found
	return null


## Escape down and up, through the input path, as a keyboard sends it.
func _press_esc() -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = down
		Input.parse_input_event(key)
		await get_tree().process_frame
	await _settle()


## The launcher's menu button whose label, as launcher_config.tres spells it, is
## [param label] -- the Button translates it only as it draws.
func _launcher_button(label: String) -> Button:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for found: Node in scene.find_children("*", "Button", true, false):
		if (found as Button).text == label and (found as Button).is_visible_in_tree():
			return found as Button
	return null


## Both halves, in the engine's order -- see the note at the top.
func _press_back() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	get_tree().root.emit_signal(&"go_back_requested")


func _scene_path() -> String:
	var scene := get_tree().current_scene
	return "" if scene == null else scene.scene_file_path


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("[back-probe] %s  %s" % ["PASS" if ok else "FAIL", what])
