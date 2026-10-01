extends Control
## **The corner every screen carries** (docs/design/settings.md §1): a gear in the
## top-right corner, one launcher edge margin in -- the pause tap's mirror -- and
## the settings sheet it opens, which holds the language list (§2, §3).
##
## It is the **last child** of the view chooser and of the earshot screen (so of
## far.tscn too), and of the pause screen in a run, where it hides with the screen.
## Last, because input goes to the last child first: Esc reaches the corner before
## the screen under it, and the corner takes it while something is open. Android
## Back is a notification, which goes to the parent first, so **every screen's Back
## asks [method close_top] before doing what Back does**, and stops when it says
## true. The corner never listens for Back itself: if it did, one Back would close
## two things.
##
## **Every layer is a node of corner.tscn, hidden until it is opened**, and the one
## thing built in code is the language list, once, in `_ready()`. So a change of
## language only ever sets words again, deferred, and never adds a node from inside
## the notification -- which the tree refuses, and the sheet vanished when it was
## tried (§3.3).
##
## **Two of the owner's questions are open** (§11), and both are one line to
## change. What the sheet holds besides the language (row 1): a section is a node
## of `Box`, between `Languages` and `Warn`. Where the gear is in a run (row 2):
## the pause screen instances this with [member show_cluster]; with it off, a
## button of the pause column calls [method open_settings] instead.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const I18n := preload("res://game/i18n/i18n.gd")

## The width of a language row: the sheet's 520 less its two margins of 24.
const ROW_SIZE := Vector2(472.0, 56.0)
## Where a row's words start, and where its mark sits.
const ROW_TEXT_X := 52.0
const MARK_X := 26.0
const MARK_R := 6.0
## How many rows show before the list scrolls, and how far apart they are.
const ROWS_SHOWN := 6
const ROW_PITCH := 64.0
## The gear: one closed line through eight teeth, and a ring (§1.2).
const GEAR_TEETH := 8
const GEAR_TIP_R := 11.0
const GEAR_ROOT_R := 8.2
const GEAR_TIP_SPAN := 0.17
const GEAR_ROOT_SPAN := 0.30
const GEAR_RING_R := 3.4
const GEAR_WIDTH := 2.0
## The launcher's button ink, and the brightest teal the focus ring wears.
const INK := Color(0.855, 0.953, 0.933, 1.0)
const BRIGHT := Color(0.490, 1.0, 0.831, 1.0)
const GEAR_REST := 0.8
const GEAR_HOT := 0.95
const RING_ALPHA := 0.35
const RING_WIDTH := 1.5

## **The gear and whatever joins it**, top right. Off where a screen opens the
## sheet itself: the launcher's own menu, once #68 lets the game reach it (§1.4),
## or a pause screen that puts settings in its column instead (owner's row 2).
@export var show_cluster := true:
	set(value):
		show_cluster = value
		if is_node_ready():
			_cluster.visible = value
## **The pause screen's own warning, repeated in the sheet that covers it**: in a
## pond the water keeps moving under the menu (shared-pond.md §1.7). The pause
## screen sets it whenever its own warning changes.
@export var warn := false:
	set(value):
		warn = value
		if is_node_ready():
			_warn.visible = value

## The row's box while it is the language in use: the pressed fill, the hover rim
## held (§2). Set in corner.tscn.
@export var current_box: StyleBox

@onready var _cluster: Control = $Cluster
@onready var _gear: Button = $Cluster/Gear
@onready var _veil: ColorRect = $Veil
@onready var _settings: Control = $Settings
@onready var _title: Label = $Settings/Panel/Box/Title
@onready var _caption: Label = $Settings/Panel/Box/Caption
@onready var _languages: ScrollContainer = $Settings/Panel/Box/Languages
@onready var _rows: VBoxContainer = $Settings/Panel/Box/Languages/Rows
@onready var _warn: Label = $Settings/Panel/Box/Warn
@onready var _close: Button = $Settings/Panel/Box/Close

## The layer on top, or null. Phase 1 has one, the settings sheet.
var _open: Control = null
## What had the focus when the sheet opened, which gets it back.
var _opener: Control = null
## The frame something was last closed by the player, so the other door the same
## Back comes through finds it already answered (see [method close_top]).
var _closed_frame := -1
## The language rows, by locale, and the locale of the one in use.
var _row_of := {}
var _in_use := ""


func _ready() -> void:
	_cluster.visible = show_cluster
	_veil.hide()
	_settings.hide()
	_warn.visible = warn
	_gear.focus_mode = Control.FOCUS_ALL
	_gear.pressed.connect(open_settings)
	_gear.draw.connect(_draw_gear)
	for redraw: Signal in [_gear.mouse_entered, _gear.mouse_exited, _gear.focus_entered,
			_gear.focus_exited]:
		redraw.connect(_gear.queue_redraw)
	_veil.gui_input.connect(_on_veil_input)
	_close.pressed.connect(close_top)
	_build_rows()
	_say()


func _notification(what: int) -> void:
	# **Deferred, and it has to be** (§3.3): the engine sends this down the tree
	# while it walks the children, and nothing may be added from inside it. A node
	# also hears it once as it enters the tree, before any change: `_ready` says
	# the words then, so that one is let go.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_say.call_deferred()


## **Esc closes what is open**, and while anything is, no key reaches the screen
## under it: the sheet is modal, and a key read under it -- a paste on the far
## page, `N` on the pause screen -- would change what the sheet is hiding.
func _unhandled_input(event: InputEvent) -> void:
	var answered := _closed_frame == Engine.get_process_frames()
	if _open == null and not answered:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_top()
		return
	if _open != null and (event is InputEventKey or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()


## **Closes the top layer, and says whether Back or Esc has been answered.**
## Every screen's Back asks this first and stops when it is true.
##
## **True as well when something was closed this frame.** Back can arrive twice
## in one frame, as the notification and as Esc (normal_mode.gd, `_back_once`),
## and the two come in either order: the second must not close the screen
## under the sheet the first one closed.
func close_top() -> bool:
	if _closed_frame == Engine.get_process_frames():
		return true
	if _open == null:
		return false
	_closed_frame = Engine.get_process_frames()
	_shut(true)
	return true


## **Closes everything, at once and quietly**: for a screen that is going away,
## or a pause screen a death or a takeover shut, so a sheet left open is not still
## open the next time it is shown. The focus is not moved: the screen is deciding
## where it goes.
func close_all() -> void:
	if _open != null:
		_shut(false)


## True while a layer is open over the screen.
func is_open() -> bool:
	return _open != null


## **The keyboard's way into the corner and back** (§1.3): Up from [param below]
## -- the screen's topmost control -- reaches the gear, and Down from the gear
## goes back to it. Up from each of [param beside], the controls in a row with
## it, reaches the gear too. A screen whose topmost control changes calls this
## again.
func link_focus(below: Control, beside: Array = []) -> void:
	if below == null:
		return
	for control: Control in [below] + beside:
		control.focus_neighbor_top = control.get_path_to(_gear)
	_gear.focus_neighbor_bottom = _gear.get_path_to(below)


# ---------------------------------------------------------------------------
# The settings sheet (§2).
# ---------------------------------------------------------------------------

## **Opens the settings sheet**, with the focus on the language in use (§2). The
## gear calls it; so can a screen that puts settings somewhere of its own.
func open_settings() -> void:
	if _open == _settings:
		return
	var focused := get_viewport().gui_get_focus_owner()
	_opener = focused if focused != null and not is_ancestor_of(focused) else _gear
	_open = _settings
	_veil.show()
	_settings.show()
	_mark_in_use()
	var row: Button = _row_of.get(_in_use)
	if row != null:
		row.grab_focus()
	else:
		_close.grab_focus()


## Hides the open layer, and when the player closed it, hands the focus back to
## whatever opened it -- or to the gear, when that has gone from the screen since:
## a page can change under the sheet.
func _shut(give_focus_back: bool) -> void:
	_open.hide()
	_open = null
	_veil.hide()
	if give_focus_back:
		var back_to := _opener if is_instance_valid(_opener) and _opener.is_visible_in_tree() \
			else null
		if back_to == null and _gear.is_visible_in_tree():
			back_to = _gear
		if back_to != null:
			back_to.grab_focus()
	_opener = null


## **A press on the veil closes the sheet** -- the press of a finger, or of a
## real mouse, and never the click Godot makes up from a finger. That one arrives
## first; closing on it would hide the veil, and the finger's own press would then
## land on whatever is under it: a mark on the earshot ring, a slot on the pause
## screen. Every pointer event on the veil is its own, so nothing passes through.
func _on_veil_input(event: InputEvent) -> void:
	_veil.accept_event()
	var press := false
	if event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		press = (event as InputEventMouseButton).pressed \
			and event.device != InputEvent.DEVICE_ID_EMULATION
	if press:
		close_top()


## **One row per language** (§3.1), built once: their words never change, because
## each is in its own language. **Auto-translate is off on every row**: a row's
## text is a catalog's answer to the msgid "English", and a Button whose text is a
## msgid translates it -- left on, the English row would read "Français" in French.
func _build_rows() -> void:
	var languages := I18n.languages()
	for language: Dictionary in languages:
		var locale := str(language["locale"])
		var row := Button.new()
		row.name = "Row_%s" % locale
		row.text = str(language["name"])
		row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.custom_minimum_size = ROW_SIZE
		row.focus_mode = Control.FOCUS_ALL
		# The launcher's own boxes, with the words moved over for the mark.
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			var box := get_theme_stylebox(state, &"Button").duplicate() as StyleBox
			box.content_margin_left = ROW_TEXT_X
			row.add_theme_stylebox_override(state, box)
		row.draw.connect(_draw_mark.bind(row, locale))
		row.pressed.connect(_choose.bind(locale))
		_rows.add_child(row)
		_row_of[locale] = row
	# Six at once, and from the seventh the list scrolls (§2).
	var shown := mini(languages.size(), ROWS_SHOWN)
	_languages.custom_minimum_size = Vector2(ROW_SIZE.x,
		ROW_PITCH * shown - (ROW_PITCH - ROW_SIZE.y))
	_trap_focus()


## **The keyboard stays on the sheet while it is open.** Godot looks for the
## next control by where it is on the screen and by the order of the tree, and
## both lead off the sheet: Up from the first row to whatever is above it under
## the veil, Tab from `close` to the screen's own first button. So every way out
## is named: the rows and `close` in a column, Tab round them, and nothing to
## either side.
func _trap_focus() -> void:
	var ring: Array[Control] = []
	for row: Button in _rows.get_children():
		ring.append(row)
	ring.append(_close)
	for i in ring.size():
		var control := ring[i]
		var before := ring[maxi(i - 1, 0)]
		var after := ring[mini(i + 1, ring.size() - 1)]
		control.focus_neighbor_top = control.get_path_to(before)
		control.focus_neighbor_bottom = control.get_path_to(after)
		control.focus_neighbor_left = control.get_path_to(control)
		control.focus_neighbor_right = control.get_path_to(control)
		control.focus_previous = control.get_path_to(ring[posmod(i - 1, ring.size())])
		control.focus_next = control.get_path_to(ring[(i + 1) % ring.size()])


## **A row tapped: that language, at once, and kept** (§2). The sheet stays open,
## now in that language, which is the best confirmation there is, and there is no
## apply button. The words are said again on the notification the change sends.
func _choose(locale: String) -> void:
	I18n.choose(locale)
	_mark_in_use()


## The row of the language in use wears the "current" box and a filled dot.
func _mark_in_use() -> void:
	_in_use = I18n.in_use()
	for locale: String in _row_of:
		var row: Button = _row_of[locale]
		var box: StyleBox = current_box if locale == _in_use and current_box != null \
			else get_theme_stylebox(&"normal", &"Button")
		box = box.duplicate() as StyleBox
		box.content_margin_left = ROW_TEXT_X
		row.add_theme_stylebox_override(&"normal", box)
		row.queue_redraw()


func _draw_mark(row: Button, locale: String) -> void:
	var at := Vector2(MARK_X, row.size.y * 0.5)
	if locale == _in_use:
		row.draw_circle(at, MARK_R, BRIGHT, true, -1.0, true)
	else:
		row.draw_arc(at, MARK_R, 0.0, TAU, 32, Color(INK, RING_ALPHA), RING_WIDTH, true)


# ---------------------------------------------------------------------------
# The words, said again whenever the language changes (§3.3).
# ---------------------------------------------------------------------------

## Every word the corner shows. A Label given `tr()` of a message keeps the words
## and not the message, so it would stay in the language it was given (§3.3):
## this is called from `_ready` and, deferred, on every change of language.
func _say() -> void:
	# TRANSLATORS: The title of the settings sheet, which opens from a gear in the
	# top-right corner of every screen; also that gear's tooltip, and, in a later
	# version, a 300 px button on the launcher's first screen. One lowercase word:
	# the app's settings (here only the language, for now).
	# ROOM: 250 px at 20 px
	var settings := tr("settings")
	_title.text = settings
	_gear.tooltip_text = settings
	_gear.accessibility_name = settings
	# TRANSLATORS: A caption in 16 px type above the list of languages on the
	# settings sheet. One lowercase word.
	# ROOM: 472 px at 16 px
	_caption.text = tr("language")
	# TRANSLATORS: A button at the bottom of the settings sheet: close the sheet
	# and go back to the screen under it. One lowercase word, in 20 px type on a
	# button 232 px wide.
	# ROOM: 180 px at 20 px
	_close.text = tr("close")
	# TRANSLATORS: Also shown on the settings sheet, in 15 px type, when it is
	# opened from the pause screen of a game shared with a friend: it covers the
	# pause screen's own warning, so it says it again.
	# ROOM: 472 px at 15 px
	_warn.text = tr("the water is still moving · you can still be eaten")
	_mark_in_use()


## **The gear, drawn and not textured**, as the pause tap is (§1.2): an outline,
## because the filled version read as a blob at 1:1.
func _draw_gear() -> void:
	var hot := _gear.is_hovered() or _gear.has_focus()
	var ink := Color(INK, GEAR_HOT if hot else GEAR_REST)
	var middle := _gear.size * 0.5
	_gear.draw_polyline(gear_outline(middle, GEAR_TIP_R, GEAR_ROOT_R, GEAR_TEETH), ink,
		GEAR_WIDTH, true)
	_gear.draw_arc(middle, GEAR_RING_R, 0.0, TAU, 24, ink, GEAR_WIDTH, true)


## **A gear's outline as one closed line**: [param teeth] teeth reaching
## [param tip] from [param root] round [param middle], each spanning
## [constant GEAR_TIP_SPAN] of a step either side at the tip and
## [constant GEAR_ROOT_SPAN] at the root.
static func gear_outline(middle: Vector2, tip: float, root: float, teeth: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var step := TAU / float(teeth)
	for i in teeth:
		var at := step * float(i)
		points.append(middle + Vector2.from_angle(at - GEAR_ROOT_SPAN * step) * root)
		points.append(middle + Vector2.from_angle(at - GEAR_TIP_SPAN * step) * tip)
		points.append(middle + Vector2.from_angle(at + GEAR_TIP_SPAN * step) * tip)
		points.append(middle + Vector2.from_angle(at + GEAR_ROOT_SPAN * step) * root)
		points.append(middle + Vector2.from_angle(at + 0.5 * step) * root)
	points.append(points[0])
	return points
