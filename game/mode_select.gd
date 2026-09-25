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
## Preloaded for one call and one constant. This screen is the boundary of a
## session: everything on the far side of Play is either in one or is not, and
## this is where one is torn down.
const NetSession := preload("res://game/net/net_session.gd")
## For one constant: what the way in by invite is called on screen.
const Invite := preload("res://game/net/invite.gd")

const NORMAL_SCENE := "res://game/normal/normal_mode.tscn"
## Two phones on one wi-fi, one of them hosting. docs/design/multiplayer.md
## §4.2 -- and it is a third option here rather than a mode, because the view
## is still chosen the same way once the two of you have found each other.
const EARSHOT_SCENE := "res://game/net/earshot.tscn"
## **A friend's dedicated server, from far away, by the invite they sent**
## (docs/design/invites-ux.md §1): the same screen, opened at its own page by an
## inherited scene that sets `far` and nothing else. Reached by string like the
## one above, which is why ci.yml boots both.
const FAR_SCENE := "res://game/net/far.tscn"
## Hardcoded because the launcher offers no "go back" API. Known template gap,
## filed as template#18 and accepted for now.
const LAUNCHER_SCENE := "res://addons/launcher/launcher.tscn"

## Both options are well over the 48px minimum, and the pair is separated by far
## more than 48 canvas px -- for the same reason the pause buttons are. A low
## tap on one must land in dead space, not on the other.
const OPTION_SIZE := Vector2(460.0, 64.0)
const COMPANION_SIZE := Vector2(320.0, 52.0)

@onready var _full: Button = $Center/Column/FullBlock/Full
@onready var _pov: Button = $Center/Column/PovBlock/Pov
@onready var _net: Button = $Center/Column/Company/NetBlock/Net
@onready var _far: Button = $Center/Column/Company/FarBlock/Far
@onready var _far_note: Label = $Center/Column/Company/FarBlock/FarNote
@onready var _hint: Label = $Hint

var _leaving := false


func _ready() -> void:
	# Android Back must return to the launcher, not kill the app.
	get_tree().quit_on_go_back = false

	# **The one place a session ends.** Every way out of a run and every way out
	# of the earshot screen arrives here, so closing whatever is open here means
	# no other screen has to remember to. A solo player never has one, and
	# closing nothing costs nothing.
	NetSession.close_current()

	_full.pressed.connect(_choose.bind(RunState.Mode.FULL_VISION))
	_pov.pressed.connect(_choose.bind(RunState.Mode.POV))
	_net.pressed.connect(_company.bind(EARSHOT_SCENE))
	_far.pressed.connect(_company.bind(FAR_SCENE))

	_hint.text = "back returns to the launcher" if _touch_first() else "esc returns to the launcher"

	for button: Button in [_full, _pov]:
		button.custom_minimum_size = OPTION_SIZE
		button.focus_mode = Control.FOCUS_ALL
	# Subordinate on purpose: this screen's question is still "which view", and
	# the company options are a different question asked underneath it --
	# narrower and shorter than the two views, side by side in one row, and
	# still 52px tall against a 48px minimum.
	# **The scene sets `size_flags_horizontal` to shrink-centre and that is load-
	# bearing**: a VBoxContainer stretches its children to the widest one, so a
	# minimum size alone left this button exactly as wide as the two above it --
	# rendered, seen, fixed. The pair made the same trap twice over: the column
	# is now as wide as the pair, 704px, so FullBlock and PovBlock carry the flag
	# as well, or full vision and point of view stretch to it.
	for button: Button in [_net, _far]:
		button.custom_minimum_size = COMPANION_SIZE
		button.focus_mode = Control.FOCUS_ALL
	# **The owner has not named the way in yet** (invites-ux.md §11): the button
	# and the far page's heading both read Invite.DOOR_NAME, so a rename is one
	# constant.
	_far.text = Invite.DOOR_NAME
	_far_note.text = far_note(Invite.DOOR_NAME)

	# **Down from point of view lands on within earshot.** The pair sits
	# symmetrically under it, so the automatic pick is a tie, and a tie-break is
	# not a decision. Up from either comes back to point of view; left and right
	# walk the pair.
	_pov.focus_neighbor_bottom = _pov.get_path_to(_net)
	_net.focus_neighbor_top = _net.get_path_to(_pov)
	_far.focus_neighbor_top = _far.get_path_to(_pov)
	_net.focus_neighbor_right = _net.get_path_to(_far)
	_far.focus_neighbor_left = _far.get_path_to(_net)

	# The remembered choice is the focused one, so the keyboard path is one key
	# and the returning player can see what they picked last time.
	var last := RunState.load_mode()
	var start: Button = _pov if last == RunState.Mode.POV else _full
	start.grab_focus()


## **The note under the far button** (invites-ux.md §6.1). "by invite" already
## says how, so its note says who; any other name gets the how in its note.
static func far_note(door: String) -> String:
	if door.contains("invite"):
		return "a friend far away, who sent you one"
	return "a friend far away, by the invite they sent"


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


## Within earshot, or from far away: the same screen, at the page [param scene]
## opens it on.
func _company(scene: String) -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(scene):
		push_error("[ModeSelect] No earshot screen at %s" % scene)
		return
	_leaving = true
	_go(scene)


func _back() -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(LAUNCHER_SCENE):
		push_error("[ModeSelect] No launcher at %s" % LAUNCHER_SCENE)
		return
	_leaving = true
	# Deferred, and the deferral is the whole of issue #23. The window
	# propagates NOTIFICATION_WM_GO_BACK_REQUEST and *then* emits
	# `go_back_requested`, which SceneTree has connected to its own quit check.
	# Setting this directly here is therefore read microseconds later, by the
	# same Back we are still inside, and the app dies with the launcher one
	# frame old -- which is exactly what the issue describes. Deferring puts
	# the restore after that read, so it means "from the next Back onwards".
	get_tree().set_deferred(&"quit_on_go_back", true)
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
