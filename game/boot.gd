extends Node
## **The game's own hook on the launcher** (docs/design/settings.md §1.4, phase
## 3): an autoload, `GameBoot`, registered in project.godot after the template's
## two. It does what the launcher's first screen needs from the game and cannot
## ask for until template#68 gives games a hook of their own -- the cleaner path,
## and once it lands this can move onto it.
##
## **The language, before the launcher is built.** Preloading i18n.gd is all it
## takes: that script registers the game's catalogs and applies the player's saved
## language as it loads (`register`), and an autoload loads before the main scene.
## It loads after BuildInfo, autoload #1, has mounted the content pack, so this
## file and i18n.gd come out of the pack and a content update reaches them; only
## the registration in project.godot needs the APK. So the game's own words on the
## launcher -- play, settings, quit and the tagline, which launcher_config.tres
## holds and the launcher looks up in the game's catalog -- are in the player's
## language from the first frame. The launcher's own words, its update bar and its
## dialogs, wait for a launcher catalog in game/i18n/launcher/.
##
## **Settings, from the launcher's menu.** launcher_config.tres lists "settings" in
## `extra_buttons`: the launcher puts it between play and quit, shows its
## translation, and emits `custom_button_pressed("settings")` -- the English, so
## nothing here reads translated text. **Every launcher is watched**, not the first
## only: Back from the game builds a new one. The sheet is the corner's own
## (game/menu/corner.tscn), over the launcher, with no gear and no world chip
## (owner rows 3 and 4), and closing it gives the focus back to `settings`.
##
## **Back closes the sheet, and only the sheet.** The launcher has no Back of its
## own, so Back on Android quits the app through `quit_on_go_back`, which stays
## so with no sheet up. While the sheet is up the flag is off, and Back reaches
## this node -- an autoload, so before the launcher -- which closes the sheet. The
## flag comes back deferred, for issue #23's reason (mode_select.gd's `_back`):
## the engine reads it after the notification, inside the same Back, and a flag
## put back at once would quit the app the Back was only closing a sheet in.
##
## **Nothing here assumes a window, an input device or a network.** The dedicated
## server and every CI boot load it as well; with no launcher in the tree it only
## listens, and i18n.gd registers nothing in a process with no screen.
##
## No class_name, as nowhere in the game: it is reached as the autoload.

## Loading it registers the game's languages and applies the saved one. Not
## unused: do not remove it.
const I18n := preload("res://game/i18n/i18n.gd")
## Loaded only when the sheet is first wanted, so a process that never shows a
## launcher never loads the corner.
const CORNER := "res://game/menu/corner.tscn"
## The launcher button this answers, as launcher_config.tres spells it.
const SETTINGS := "settings"

## The sheet over the launcher on screen, while there is one.
var _corner: Control = null
## Whether `quit_on_go_back` is off because the sheet is up, and so is this
## node's to give back.
var _holding_back := false


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for child: Node in get_tree().root.get_children():
		_watch(child)


## **Back, while the sheet is up, closes it** -- the corner never listens for Back
## itself, and the launcher does not at all.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_sheet_open():
		_corner.call(&"close_top")


## True while the settings sheet is open over a launcher.
func is_sheet_open() -> bool:
	return _corner != null and is_instance_valid(_corner) and _corner.is_inside_tree() \
		and bool(_corner.call(&"is_open"))


## A scene is added to the tree. A scene's root is the root's child; nothing else
## is looked at.
func _on_node_added(node: Node) -> void:
	if node.get_parent() == get_tree().root:
		_watch(node)


## **A launcher is heard**: whatever has the launcher's signal.
func _watch(node: Node) -> void:
	if not node.has_signal(&"custom_button_pressed"):
		return
	var heard := _on_custom_button.bind(node)
	if not node.is_connected(&"custom_button_pressed", heard):
		node.connect(&"custom_button_pressed", heard)


## **[param label] was pressed on [param launcher]**: for "settings", the sheet
## opens over it, with the button that opened it holding the focus to come back to.
func _on_custom_button(label: String, launcher: Node) -> void:
	if label != SETTINGS or not (launcher is Control) or not launcher.is_inside_tree():
		return
	var corner := _corner_on(launcher as Control)
	if corner == null:
		return
	var button := _button_of(launcher, SETTINGS)
	if button != null and button.is_visible_in_tree():
		button.grab_focus()
	get_tree().quit_on_go_back = false
	_holding_back = true
	corner.call(&"open_settings")


## The sheet over [param launcher]: the one already there, or a new one, made
## with no gear and no world chip.
func _corner_on(launcher: Control) -> Control:
	if _corner != null and is_instance_valid(_corner) and _corner.get_parent() == launcher:
		return _corner
	var scene := load(CORNER) as PackedScene
	if scene == null:
		push_error("[GameBoot] no corner at %s" % CORNER)
		return null
	var corner := scene.instantiate() as Control
	corner.set(&"show_cluster", false)
	corner.set(&"show_drop", false)
	corner.connect(&"closed", _give_back)
	corner.tree_exiting.connect(_give_back)
	launcher.add_child(corner)
	_corner = corner
	return corner


## **The sheet closed, or went with its launcher**: Back quits again, from the
## next Back on -- deferred, see the note at the top.
func _give_back() -> void:
	if not _holding_back:
		return
	_holding_back = false
	get_tree().set_deferred(&"quit_on_go_back", true)


## The launcher's button for [param label]: its `text` is the label as the config
## spells it, which the Button translates only as it draws.
func _button_of(launcher: Node, label: String) -> Button:
	for found: Node in launcher.find_children("*", "Button", true, false):
		var button := found as Button
		if button.text == label and not (is_instance_valid(_corner) and _corner.is_ancestor_of(button)):
			return button
	return null
