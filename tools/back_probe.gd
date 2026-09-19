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
## Prints one line per check and `ALL PASS` only if every one held. CI asserts on
## that marker rather than on the exit code: Godot exits 0 even after a parse
## error, and a tree that quits mid-probe never reaches the final print either.

const MODE_SELECT := "res://game/mode_select.tscn"
const LAUNCHER := "res://addons/launcher/launcher.tscn"

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
	get_tree().change_scene_to_file(MODE_SELECT)
	await _settle()
	_check("the view chooser is on screen", _scene_path() == MODE_SELECT)
	_check("the chooser has taken Back off the tree",
		not get_tree().quit_on_go_back)

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

	if _failed == 0:
		print("[back-probe] ALL PASS")
	else:
		print("[back-probe] %d FAILED" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _settle() -> void:
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame


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
