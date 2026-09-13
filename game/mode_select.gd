extends Control
## Where Play lands: the one screen that asks which of the game's two views this
## run is played in.
##
## It exists because the launcher cannot ask. Its extra buttons emit a signal
## only the launcher scene itself can receive, and addons/launcher/ is synced
## wholesale from the template and may not be edited -- so the choice has to
## live on our side of play_scene.
##
## Same visual language as the launcher, deliberately: the launcher's theme, the
## launcher's background shader turned down, the same near-black green. Pressing
## Play should feel like walking into the next room, not like a scene change.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const RunState := preload("res://game/run_state.gd")

const NORMAL_SCENE := "res://game/normal/normal_mode.tscn"
## Hardcoded because the launcher offers no "go back" API. Known template gap,
## filed as template#18 and accepted for now.
const LAUNCHER_SCENE := "res://addons/launcher/launcher.tscn"

## Both options are well over the 48px minimum, and the pair is separated by far
## more than 48 canvas px -- for the same reason the pause buttons are. A low
## tap on one must land in dead space, not on the other.
const OPTION_SIZE := Vector2(460.0, 64.0)

@onready var _full: Button = $Center/Column/FullBlock/Full
@onready var _pov: Button = $Center/Column/PovBlock/Pov
@onready var _hint: Label = $Hint

var _leaving := false


func _ready() -> void:
	# Android Back must return to the launcher, not kill the app.
	get_tree().quit_on_go_back = false

	_full.pressed.connect(_choose.bind(RunState.Mode.FULL_VISION))
	_pov.pressed.connect(_choose.bind(RunState.Mode.POV))

	_hint.text = "back returns to the launcher" if _touch_first() else "esc returns to the launcher"

	for button: Button in [_full, _pov]:
		button.custom_minimum_size = OPTION_SIZE
		button.focus_mode = Control.FOCUS_ALL

	# The remembered choice is the focused one, so the keyboard path is one key
	# and the returning player can see what they picked last time.
	var last := RunState.load_mode()
	var start: Button = _pov if last == RunState.Mode.POV else _full
	start.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		# Marked handled before leaving: by the time _back() returns this node
		# may already be out of the tree and get_viewport() null.
		get_viewport().set_input_as_handled()
		_back()


func _choose(mode: int) -> void:
	if _leaving:
		return
	RunState.save_mode(mode)
	if not ResourceLoader.exists(NORMAL_SCENE):
		push_error("[ModeSelect] No game at %s" % NORMAL_SCENE)
		return
	_leaving = true
	_go(NORMAL_SCENE)


func _back() -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(LAUNCHER_SCENE):
		push_error("[ModeSelect] No launcher at %s" % LAUNCHER_SCENE)
		return
	_leaving = true
	# Back behaves normally again once the launcher owns the screen.
	get_tree().quit_on_go_back = true
	_go(LAUNCHER_SCENE)


## Deferred on purpose. Android Back arrives as a notification propagated
## through the tree, and swapping the scene from inside that propagation is the
## tree telling you it is busy adding and removing children.
func _go(scene: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene)


## Which verb to name. Deliberately not asking the DisplayServer, which has no
## answer at all on a headless boot.
func _touch_first() -> bool:
	return OS.has_feature("mobile")
