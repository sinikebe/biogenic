extends Control
## Where Play lands: the one screen that asks which of the game's two views this
## run is played in -- **and which of your cells** (docs/design/cells-ux.md §1):
## each view's button names the cell it plays, on a second line under the view,
## and a chevron beside it opens that view's cells. A view only ever lists its
## own, so the button and its cell can never disagree.
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

## **Loading this is what registers the game's languages** (game/i18n/README.md),
## and it has to happen before this scene's nodes exist, which is why it is a
## preload and not a call. Not unused: do not remove it.
const I18n := preload("res://game/i18n/i18n.gd")
const RunState := preload("res://game/run_state.gd")
## Preloaded for one call and one constant. This screen is the boundary of a
## session: everything on the far side of Play is either in one or is not, and
## this is where one is torn down.
const NetSession := preload("res://game/net/net_session.gd")
## For one constant: what the way in by invite is called on screen.
const Invite := preload("res://game/net/invite.gd")
## **Your cells and your worlds** (docs/design/cells.md): the cell each view plays,
## and the world it is measured against, for the line under the view's name.
const Cells := preload("res://game/normal/cells.gd")
const Drops := preload("res://game/normal/drops.gd")

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
## tap on one must land in dead space, not on the other. **80 tall since each
## carries its cell's line** (cells-ux.md §1.1): two lines of 20 and 15 px need
## 48, and the margins take the rest.
const OPTION_SIZE := Vector2(460.0, 80.0)
const COMPANION_SIZE := Vector2(320.0, 52.0)
## **The line under a view's name has this much room** (cells-ux.md §1.2): the
## button's 460 less its two margins of 20. Wider, the cell's name alone gives
## way to "…".
const CELL_LINE_ROOM := 420.0
const CELL_LINE_SIZE := 15
## **The chevron beside each view**, the world chip's: its three points round the
## button's middle, 2 px, at the gear's two alphas (cells-ux.md §1.1).
const CHEVRON: Array[Vector2] = [Vector2(-5.5, -2.5), Vector2(0.0, 3.0), Vector2(5.5, -2.5)]
const CHEVRON_INK := Color(0.855, 0.953, 0.933)
const CHEVRON_REST := 0.8
const CHEVRON_HOT := 0.95

# --- The words in mode_select.tscn ---------------------------------------------
# A scene's text is translated by the Control that shows it, and the template reads
# it from the scene file; a scene has no place for a note, so the notes are here.
#
# TRANSLATORS "choose a view": The heading of the screen where a game is started, in
# 17 px type. The player chooses how the water is drawn for this game: a "view".
#
# TRANSLATORS "full vision": The first line of a button 460 px wide, in 20 px type: the
# view that draws the water the cell swims in, and the membrane (the cell's skin, which
# senses) over it. The cell that view plays is named on the line under it.
#
# TRANSLATORS "the water the cell is swimming in, and the membrane over it": A note in
# 15 px type under the "full vision" button, on one line: about 60 characters at most.
#
# TRANSLATORS "point of view": The first line of a button 460 px wide, in 20 px type: the
# view that shows only what the cell itself can feel, as if the player were inside it.
# The cell that view plays is named on the line under it.
#
# TRANSLATORS "only what the cell itself can feel": A note in 15 px type under the
# "point of view" button: about 40 characters at most.
#
# TRANSLATORS "a friend on the same wi-fi": A note in 15 px type under the "within
# earshot" button, which is 320 px wide: about 35 characters at most.
@onready var _full: Button = $Center/Column/FullBlock/Row/Full
@onready var _pov: Button = $Center/Column/PovBlock/Row/Pov
## **Each view's chevron**, which opens that view's cells, and the two lines its
## button says: the view, and the cell it plays (cells-ux.md §1.1).
@onready var _full_cells: Button = $Center/Column/FullBlock/Row/Cells
@onready var _pov_cells: Button = $Center/Column/PovBlock/Row/Cells
@onready var _full_view: Label = $Center/Column/FullBlock/Row/Full/Lines/View
@onready var _pov_view: Label = $Center/Column/PovBlock/Row/Pov/Lines/View
@onready var _full_line: Label = $Center/Column/FullBlock/Row/Full/Lines/Cell
@onready var _pov_line: Label = $Center/Column/PovBlock/Row/Pov/Lines/Cell
@onready var _net: Button = $Center/Column/Company/NetBlock/Net
@onready var _far: Button = $Center/Column/Company/FarBlock/Far
@onready var _far_note: Label = $Center/Column/Company/FarBlock/FarNote
@onready var _hint: Label = $Hint
## **Settings, from the gear in the top-right corner** (docs/design/settings.md
## §1): the last child, so Esc reaches it before this screen does.
@onready var _corner: Control = $Corner

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
	# **A chevron opens its own view's cells** (cells-ux.md §2), in the corner's sheet.
	_full_cells.pressed.connect(_corner.open_cells.bind(RunState.Mode.FULL_VISION))
	_pov_cells.pressed.connect(_corner.open_cells.bind(RunState.Mode.POV))

	for button: Button in [_full, _pov]:
		button.custom_minimum_size = OPTION_SIZE
		button.focus_mode = Control.FOCUS_ALL
	# **The view's name follows its button's states** (cells-ux.md §1.1), as the
	# button's own text did before it had two lines.
	for pair: Array in [[_full, _full_view], [_pov, _pov_view]]:
		var button: Button = pair[0]
		var said: Label = pair[1]
		for change: Signal in [button.mouse_entered, button.mouse_exited,
				button.focus_entered, button.focus_exited, button.button_down,
				button.button_up]:
			# Deferred: a button takes in that it is hovered or pressed after it
			# says so, and the colour is read off what it then is.
			change.connect(_tint_view.bind(button, said), CONNECT_DEFERRED)
		_tint_view(button, said)
	for chevron: Button in [_full_cells, _pov_cells]:
		chevron.focus_mode = Control.FOCUS_ALL
		chevron.draw.connect(_draw_chevron.bind(chevron))
		for change: Signal in [chevron.mouse_entered, chevron.mouse_exited,
				chevron.focus_entered, chevron.focus_exited]:
			change.connect(chevron.queue_redraw)
	# **Your cells first leave your worlds here** (cells.md §4): on this screen's
	# first frame, for every world whose index still names a cell -- once, after
	# the update, and nothing at all from then on. Before the lines are said, so
	# each view's button names the cell the migration selected for it.
	Cells.migrate(_corner.drops_root, _corner.cells_root)
	# Each view's line is said again whenever the corner closes: a cell chosen,
	# renamed or deleted in its sheet, or another world chosen with the chip.
	_corner.closed.connect(_say_cells)
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
	_say()

	# **The keyboard walks the views keeping its column** (cells-ux.md §1.3):
	# Right from a view is its chevron and Left comes back; Down and Up go between
	# full vision and point of view, and between their chevrons. **Down from point
	# of view lands on within earshot**, and from its chevron on by invite: the
	# pair sits under them, and a tie-break is not a decision. Up from the pair
	# comes back to the column it left; left and right walk the pair.
	for row: Array in [[_full, _full_cells], [_pov, _pov_cells]]:
		var view: Button = row[0]
		var chevron: Button = row[1]
		view.focus_neighbor_right = view.get_path_to(chevron)
		view.focus_neighbor_left = view.get_path_to(view)
		chevron.focus_neighbor_left = chevron.get_path_to(view)
		chevron.focus_neighbor_right = chevron.get_path_to(chevron)
	_full.focus_neighbor_bottom = _full.get_path_to(_pov)
	_pov.focus_neighbor_top = _pov.get_path_to(_full)
	_full_cells.focus_neighbor_bottom = _full_cells.get_path_to(_pov_cells)
	_pov_cells.focus_neighbor_top = _pov_cells.get_path_to(_full_cells)
	_pov.focus_neighbor_bottom = _pov.get_path_to(_net)
	_pov_cells.focus_neighbor_bottom = _pov_cells.get_path_to(_far)
	_net.focus_neighbor_top = _net.get_path_to(_pov)
	_far.focus_neighbor_top = _far.get_path_to(_pov_cells)
	_net.focus_neighbor_right = _net.get_path_to(_far)
	_far.focus_neighbor_left = _far.get_path_to(_net)
	# **Up from full vision is the gear**, and from its chevron too; Down from the
	# gear comes back.
	_corner.link_focus(_full, [_full_cells])

	# The remembered choice is the focused one, so the keyboard path is one key
	# and the returning player can see what they picked last time.
	var last := RunState.load_mode()
	var start: Button = _pov if last == RunState.Mode.POV else _full
	start.grab_focus()


## **Every word this screen sets from code**, said again whenever the language
## changes (docs/design/settings.md §3.3). The words in the scene file translate
## themselves; these were given as `tr()` of a message, which keeps the words and
## not the message, so they would stay in the language they were said in.
func _say() -> void:
	# TRANSLATORS: The hint along the bottom edge of the screen, in small type. It
	# names the key that goes back, and the key differs by device: `back` is the
	# Android Back button or gesture, `esc` is the Escape key. The launcher is the
	# app's main menu, the screen with the play button.
	_hint.text = tr("back returns to the launcher") if _touch_first() \
		else tr("esc returns to the launcher")
	# **The owner has not named the way in yet** (invites-ux.md §11): the button
	# and the far page's heading both read Invite.DOOR_NAME, so a rename is one
	# constant.
	_far.text = tr(Invite.DOOR_NAME)
	_far_note.text = far_note(Invite.DOOR_NAME)
	# The chevrons' tooltip is the sheet's own caption (cells-ux.md §1.3).
	for chevron: Button in [_full_cells, _pov_cells]:
		chevron.tooltip_text = tr("your cells")
		chevron.accessibility_name = chevron.tooltip_text
	_say_cells()


## **The cell each view plays, on the line under its name** (cells-ux.md §1.2):
## `slipper · fourth generation`, with where it comes from when its place is not
## in the selected world, `a new cell` for an empty slot, and `a new cell ·
## slipper died` over a record -- read afresh, never written. The name alone gives
## way to "…" when the line is wider than the button.
func _say_cells() -> void:
	if not is_node_ready():
		return
	var worlds := Drops.read(_corner.drops_root)
	for row: Array in [[RunState.Mode.FULL_VISION, _full, _full_line],
			[RunState.Mode.POV, _pov, _pov_line]]:
		var mode := int(row[0])
		var button: Button = row[1]
		var line: Label = row[2]
		var index := Cells.read(RunState.cell_key(mode), _corner.cells_root)
		var entry := Cells.entry_of(index, int(index["selected"]))
		line.text = Cells.fit(Cells.button_line(entry, worlds, true, _corner.drops_root),
			line.get_theme_font(&"font"), CELL_LINE_SIZE, CELL_LINE_ROOM)
		# The button's own text is empty now: what it says is its two lines.
		button.accessibility_name = "%s, %s" % [tr(RunState.VIEW_WORDS[mode]), line.text]


## **A view's name in its button's font colour for the state it is in**: pressed,
## hovered, focused or at rest, as the launcher theme colours a button's own text.
func _tint_view(button: Button, said: Label) -> void:
	var state := &"font_color"
	match button.get_draw_mode():
		BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
			state = &"font_pressed_color"
		BaseButton.DRAW_HOVER:
			state = &"font_hover_color"
		_:
			if button.has_focus():
				state = &"font_focus_color"
	said.add_theme_color_override(&"font_color", button.get_theme_color(state, &"Button"))


## **The chevron, drawn** as the world chip's is: it says the button opens a list.
## Brighter while hovered or focused, as the gear is.
func _draw_chevron(chevron: Button) -> void:
	var hot := chevron.is_hovered() or chevron.has_focus()
	var at := chevron.size * 0.5
	var points := PackedVector2Array()
	for point: Vector2 in CHEVRON:
		points.append(at + point)
	chevron.draw_polyline(points, Color(CHEVRON_INK, CHEVRON_HOT if hot else CHEVRON_REST),
		2.0, true)


## **The note under the far button** (invites-ux.md §6.1). "by invite" already
## says how, so its note says who; any other name gets the how in its note.
##
## [param door] is the way in's name **in English, as `Invite.DOOR_NAME` has it**:
## which note to give is decided by reading it, and a translated name would be
## read for a word it does not have. The note comes back translated.
static func far_note(door: String) -> String:
	if door.contains("invite"):
		# TRANSLATORS: A note in 15 px type under a button. The button is "by invite"
		# (the way to reach a friend's game by an invite they sent you), so this
		# says who: someone who is not in the same house, and who sent you an
		# invite. Under a button 320 px wide: about 40 characters at most.
		return TranslationServer.translate("a friend far away, who sent you one")
	# TRANSLATORS: Same note, for the case where the button's own name does not
	# mention an invite, so the note says how instead. About 45 characters at most.
	return TranslationServer.translate("a friend far away, by the invite they sent")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# **The corner first** (settings.md §1.3): Android Back reaches this
			# screen before the sheet over it, so a sheet that is open is what Back
			# closes, and the view chooser stays.
			if _corner.close_top():
				return
			_back()
		NOTIFICATION_TRANSLATION_CHANGED:
			# Deferred: the tree is still telling every node, and nothing may be
			# changed under it. The first one comes as the node enters the tree,
			# before `_ready` has said anything, and is let go.
			if is_node_ready():
				_say.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		# Marked handled before leaving: by the time _back() returns this node
		# may already be out of the tree and get_viewport() null.
		get_viewport().set_input_as_handled()
		# The corner is the last child, so an open sheet has had Esc already;
		# asked again in case the same Back reached it by the other door.
		if _corner.close_top():
			return
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
