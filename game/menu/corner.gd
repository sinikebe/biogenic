extends Control
## **The corner every screen carries** (docs/design/settings.md §1): a gear in the
## top-right corner, one launcher edge margin in -- the pause tap's mirror -- and,
## where a drop can be chosen, a chip beside it with the selected drop's name; and
## the sheets the two open. The gear opens settings, which holds the language list
## (§2, §3). The chip opens "your worlds" (§4): one tap selects a drop, an empty row
## makes a new one through the naming sheet (§5), and a row's own buttons rename it
## or, through a confirm, delete it. **The player's word for a drop is "world"**
## (owner's row 5): every word on screen says world, and the code says drop, as
## ocean.md and drops.gd do. **And "your cells"** (docs/design/cells-ux.md §2, §3),
## which a view's chevron on the chooser opens ([method open_cells]): one view's
## slots, one tap to select one, and each cell's **detailed view**, a layer of its
## own over the sheet, where it can be renamed and deleted. The player's word for
## a slot is never "slot": they read `your cells`, a row and `new cell`.
##
## It is the **last child** of the view chooser and of the earshot screen (so of
## far.tscn too), and of the pause screen in a run, where it hides with the screen.
## Last, because input goes to the last child first: Esc reaches the corner before
## the screen under it, and the corner takes it while something is open. Android
## Back is a notification, which goes to the parent first, so **every screen's Back
## asks [method close_top] before doing what Back does**, and stops when it says
## true. The corner never listens for Back itself: if it did, one Back would close
## two things. **One Back closes one layer**: naming and the confirm go back to the
## drop menu, or to the cell's detailed view they were opened from; the detailed
## view back to "your cells"; and a menu or the settings sheet back to the screen.
##
## **Every layer is a node of corner.tscn, hidden until it is opened**, and the one
## thing built in code is the language list, once, in `_ready()`. So a change of
## language only ever sets words again, deferred, and never adds a node from inside
## the notification -- which the tree refuses, and the sheet vanished when it was
## tried (§3.3).
##
## **The drops are game/normal/drops.gd's**: this reads them as a menu opens and
## asks it to change them, and never keeps a copy of its own across a change. A
## typed name is the player's words and is never translated, so every Label and
## the field that shows a name has auto-translate off, and nothing passes one to
## `tr()`. A default name is translated by drops.gd as it is said (owner's row 6),
## and said again here on a change of language like every other word.
##
## **The owner answered §11 as recommended** but for row 5, "world", and both of
## these stay one line to change. What the sheet holds besides the language (row
## 1, nothing for now): a section is a node of `Box`, between `Languages` and
## `Warn`. Where the gear is in a run (row 2, on the pause screen): the pause
## screen instances this with [member show_cluster]; with it off, a button of the
## pause column calls [method open_settings] instead.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## **Everything the corner had open is closed**: by Back, Esc, `close`, the veil, or
## a screen closing it. game/boot.gd hears it to let Back quit the launcher again.
signal closed

const I18n := preload("res://game/i18n/i18n.gd")
const Drops := preload("res://game/normal/drops.gd")
## **Your cells** (docs/design/cells.md): each view's slots, read as the sheet opens
## and changed only by a choice, a rename or a delete.
const Cells := preload("res://game/normal/cells.gd")
## For the views: the name each keeps its cells under, and its words.
const RunState := preload("res://game/run_state.gd")
## For [constant Readout.SEP]: the sheet's caption is a list, `your cells · full vision`.
const Readout := preload("res://game/mechanics/readout.gd")
## **A cell's figure, read-only**, loaded the first time a detailed view opens
## (cell_figure.gd says why).
const CELL_FIGURE := "res://game/menu/cell_figure.gd"

## The width of a language row: the sheet's 520 less its two margins of 24.
const ROW_SIZE := Vector2(472.0, 56.0)
## Where a row's words start, and where its mark sits -- a language row's and a
## drop row's alike.
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

## **The chip** (§1.2): as wide as its words and no wider than this, after which
## the name ends in "…". Its words start 18 px in, the caption and the name are
## 10 px apart, and the right 44 px are the chevron's.
const CHIP_MAX := 340.0
const CHIP_LEFT := 18.0
const CHIP_GAP := 10.0
const CHIP_RIGHT := 44.0
const CHIP_FONT := 17
## The chevron: its three points round (width - 26, height / 2).
const CHEVRON_IN := 26.0
const CHEVRON: Array[Vector2] = [Vector2(-5.5, -2.5), Vector2(0.0, 3.0), Vector2(5.5, -2.5)]
const CHEVRON_ALPHA := 0.8
## An empty row's mark, a plus, and its words, dimmer than a drop's name (§4.2).
const PLUS_ARM := 6.0
const PLUS_ALPHA := 0.6
const EMPTY_ALPHA := 0.82
## **A record's row** (cells-ux.md §2.2): its name and its lines fainter -- it is
## past -- under the plus of the new cell that starts there.
const RECORD_NAME_ALPHA := 0.6
const RECORD_LINE_ALPHA := 0.75
## "your cells" scrolls past this many rows (cells-ux.md §2.1): a fourth exists
## only after a rare migration, and from a fifth the rows scroll, four high.
const CELL_ROWS_SHOWN := 4
## A row's own buttons sit in the pause screen's quiet slab, with room for French
## `renommer` inside 112 px (§9).
const QUIET_MARGIN := Vector2(12.0, 10.0)

## **The gear and whatever joins it**, top right. Off where a screen opens the
## sheet itself: the launcher's own menu, once #68 lets the game reach it (§1.4),
## or a pause screen that puts settings in its column instead (owner's row 2).
@export var show_cluster := true:
	set(value):
		show_cluster = value
		if is_node_ready():
			_cluster.visible = value and not (_open != null
				and (_open == _naming or _open == _confirm))
## **The pause screen's own warning, repeated in the sheet that covers it**: in a
## pond the water keeps moving under the menu (shared-pond.md §1.7). The pause
## screen sets it whenever its own warning changes.
@export var warn := false:
	set(value):
		warn = value
		if is_node_ready():
			_warn.visible = value
## **The drop chip, beside the gear** (§1.1): wherever the drop a run will play
## can still be chosen -- the view chooser, and an earshot page while this phone
## is or may become the host. Off in a run, which plays the drop it opened on, on
## a guest's pages, whose cell comes from the drop already chosen, and on every far
## page, which is always a guest's. Turning it off closes the drop menu.
@export var show_drop := true:
	set(value):
		show_drop = value
		if is_node_ready():
			_chip.visible = value
			if value and _index.is_empty():
				_read_drops()
				_say_chip()
			if not value and _in_drops():
				close_all()
			_link_cluster()

## The row's box while it is the language in use, or the drop you are in: the
## pressed fill, the hover rim held (§2, §4.2). Set in corner.tscn.
@export var current_box: StyleBox
## An empty drop row's box: barely filled, a faint rim (§4.2).
@export var empty_box: StyleBox
## A drop row's rename and delete: the pause screen's toggle slab (§4.2).
@export var quiet_box: StyleBox

## **Where the drops are kept**: the player's own in `user://`, or a probe's
## folder, set before a menu opens. Nothing in the game changes it.
var drops_root := Drops.ROOT:
	set(value):
		drops_root = value
		if is_node_ready() and show_drop:
			_read_drops()
			_say_chip()
## **Where the cells are kept** (docs/design/cells.md §3): the player's own, or a
## tool's folder, set before a sheet opens. Nothing in the game changes it.
var cells_root := Cells.ROOT

@onready var _cluster: Control = $Cluster
@onready var _chip: Button = $Cluster/Chip
@onready var _chip_caption: Label = $Cluster/Chip/Inside/Caption
@onready var _chip_name: Label = $Cluster/Chip/Inside/Name
@onready var _gear: Button = $Cluster/Gear
@onready var _veil: ColorRect = $Veil
@onready var _settings: Control = $Settings
@onready var _title: Label = $Settings/Panel/Box/Title
@onready var _caption: Label = $Settings/Panel/Box/Caption
@onready var _languages: ScrollContainer = $Settings/Panel/Box/Languages
@onready var _rows: VBoxContainer = $Settings/Panel/Box/Languages/Rows
@onready var _warn: Label = $Settings/Panel/Box/Warn
@onready var _close: Button = $Settings/Panel/Box/Close
@onready var _drops: Control = $Drops
@onready var _drops_caption: Label = $Drops/Panel/Box/Caption
@onready var _drops_note: Label = $Drops/Panel/Box/Note
@onready var _naming: Control = $Naming
@onready var _naming_title: Label = $Naming/Panel/Box/Title
@onready var _field: LineEdit = $Naming/Panel/Box/Field
@onready var _naming_back: Button = $Naming/Panel/Box/Actions/Back
@onready var _make: Button = $Naming/Panel/Box/Actions/Make
@onready var _confirm: Control = $Confirm
@onready var _confirm_title: Label = $Confirm/Panel/Box/Title
@onready var _confirm_line: Label = $Confirm/Panel/Box/Line
@onready var _keep: Button = $Confirm/Panel/Box/Actions/Keep
@onready var _delete: Button = $Confirm/Panel/Box/Actions/Delete
@onready var _cells: Control = $Cells
@onready var _cells_panel: PanelContainer = $Cells/Panel
@onready var _cells_caption: Label = $Cells/Panel/Box/Caption
@onready var _cells_scroll: ScrollContainer = $Cells/Panel/Box/Scroll
@onready var _cell_rows: VBoxContainer = $Cells/Panel/Box/Scroll/Rows
@onready var _cells_note: Label = $Cells/Panel/Box/Note
@onready var _cell: Control = $Cell
@onready var _cell_name: Label = $Cell/Center/Columns/Side/Name
@onready var _cell_kind: Label = $Cell/Center/Columns/Side/Kind
@onready var _cell_age: Label = $Cell/Center/Columns/Side/Age
@onready var _cell_where: HBoxContainer = $Cell/Center/Columns/Side/Where
@onready var _cell_where_caption: Label = $Cell/Center/Columns/Side/Where/Caption
@onready var _cell_where_value: Label = $Cell/Center/Columns/Side/Where/Value
@onready var _cell_then: Label = $Cell/Center/Columns/Side/Then
@onready var _cell_actions: HBoxContainer = $Cell/Center/Columns/Side/Actions
@onready var _cell_rename: Button = $Cell/Center/Columns/Side/Actions/Rename
@onready var _cell_delete: Button = $Cell/Center/Columns/Side/Actions/Delete
@onready var _cell_close: Button = $Cell/Center/Columns/Side/Close
@onready var _cell_seat: CenterContainer = $Cell/Center/Columns/Figure

## The layer on top, or null: settings or the drop menu, or naming or the
## confirm over the menu.
var _open: Control = null
## What had the focus when the first layer opened, which gets it back.
var _opener: Control = null
## What opened naming or the confirm in the menu, which gets the focus back when
## they go back to it.
var _layer_opener: Control = null
## The frame something was last closed by the player, so the other door the same
## Back comes through finds it already answered (see [method close_top]).
var _closed_frame := -1
## The language rows, by locale, and the locale of the one in use.
var _row_of := {}
var _in_use := ""
## **The drops as the menu last read them** (drops.gd's `read`), and the slot
## naming or the confirm is about, whether naming makes it or renames it, the
## default an empty name keeps, and the default's words the field was given --
## "" when it was given a typed name -- said again on a change of language for as
## long as nothing has been typed over them.
var _index := {}
## A row's height with one line under its name, as corner.tscn gives it: read off
## the first row the first time one is fitted ([method _fit_row]).
var _row_height := 0.0
var _slot := 0
var _making := false
var _naming_default := 0
var _offered := ""
## The screen's topmost control, and the ones in a row with it, which Up leaves
## for the cluster ([method link_focus]).
var _below: Control = null
var _beside: Array = []
## **Naming or the confirm opened for a screen's own thing** -- a program, on the
## pause screen (automation-ux.md §2.5) -- rather than for a world: what to do with
## the answer, called with the name typed, or with nothing for a delete. Empty
## while the sheets serve worlds. A sheet opened this way sits over the screen and
## not over the drop menu, so Back and `back` go back to the screen.
var _answer := Callable()
## **The layer naming or the confirm goes back to** when it was opened over one
## that is not the drop menu: a cell's detailed view (cells-ux.md §3.4). Null for
## the drop menu's own, and for a screen's.
var _under: Control = null
## **The sheet "your cells" is about**: the view, by the mode the chooser offers it
## as and by the name its cells are kept under; the cells as the sheet last read
## them (cells.gd's `read`), the worlds they are measured against, and the slot the
## detailed view shows, with its entry.
var _cells_mode := 0
var _cells_view := ""
var _cells_index := {}
var _cells_worlds := {}
var _cell_slot := 0
var _cell_entry := {}
## **The detailed view's figure** (cell_figure.gd), made the first time it opens.
var _cell_figure: Control = null
## A row's height with one line under its name, read off the first one fitted.
var _cell_row_height := 0.0
## What gets the focus back when the detailed view goes back to the sheet -- the
## row's `look` -- and when naming or the confirm goes back to the detailed view:
## `rename` or `delete`.
var _cell_opener: Control = null
var _cell_action: Control = null


func _ready() -> void:
	_cluster.visible = show_cluster
	_veil.hide()
	for layer: Control in _layers():
		layer.hide()
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
	_ready_chip()
	_ready_drops()
	_ready_naming()
	_ready_confirm()
	_ready_cells()
	_ready_cell()
	if show_drop:
		_read_drops()
	_say()


func _notification(what: int) -> void:
	# **Deferred, and it has to be** (§3.3): the engine sends this down the tree
	# while it walks the children, and nothing may be added from inside it. A node
	# also hears it once as it enters the tree, before any change: `_ready` says
	# the words then, so that one is let go.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_say.call_deferred()


## **Esc in the naming field does what Back does** (§5.1). The field takes Esc
## for itself before any unhandled pass -- a LineEdit that is being typed in only
## stops editing on it (4.7's `LineEdit::gui_input`) -- so the corner asks first,
## here, while the field has the keyboard.
func _input(event: InputEvent) -> void:
	if _open == _naming and _field.has_focus() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_top()


## **Esc closes what is open**, and while anything is, no key reaches the screen
## under it: the sheets are modal, and a key read under one -- a paste on the far
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
## Every screen's Back asks this first and stops when it is true. Naming and the
## confirm go back to what they opened over -- the drop menu, or a cell's detailed
## view (docs/design/cells-ux.md §3.4) -- Back meaning "nothing changed" on the one
## and "keep" on the other; the detailed view goes back to your cells; and your
## cells, the menu and the settings sheet go back to the screen.
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
	if _over_menu():
		_back_to_drops()
	elif _over_cell():
		_back_to_cell()
	elif _open == _cell:
		_back_to_cells()
	else:
		_shut(true)
	return true


## **Closes everything, at once and quietly**: for a screen that is going away,
## a pause screen a death or a takeover shut, or a chip that has just gone, so a
## layer left open is not still open the next time. The focus is not moved: the
## screen is deciding where it goes.
func close_all() -> void:
	if _open != null:
		_shut(false)


## True while a layer is open over the screen.
func is_open() -> bool:
	return _open != null


## **The keyboard's way into the corner and back** (§1.3): Up from [param below]
## -- the screen's topmost control -- reaches the chip, or the gear where the chip
## is hidden, and Down from either goes back to it. Up from each of
## [param beside], the controls in a row with it, reaches it too. A screen whose
## topmost control changes calls this again; the chip coming and going re-links
## the same ones.
func link_focus(below: Control, beside: Array = []) -> void:
	_below = below
	_beside = beside
	_link_cluster()


func _link_cluster() -> void:
	var top: Control = _chip if _chip.visible else _gear
	for end: Control in [_chip, _gear]:
		end.focus_neighbor_top = end.get_path_to(end)
	_chip.focus_neighbor_left = _chip.get_path_to(_chip)
	_chip.focus_neighbor_right = _chip.get_path_to(_gear)
	_gear.focus_neighbor_left = _gear.get_path_to(top)
	_gear.focus_neighbor_right = _gear.get_path_to(_gear)
	if _below == null or not is_instance_valid(_below):
		return
	for control: Control in [_below] + _beside:
		control.focus_neighbor_top = control.get_path_to(top)
	for end: Control in [_chip, _gear]:
		end.focus_neighbor_bottom = end.get_path_to(_below)


# ---------------------------------------------------------------------------
# Opening and closing the layers.
# ---------------------------------------------------------------------------

## The layers, in the order they are drawn.
func _layers() -> Array[Control]:
	return [_settings, _drops, _cells, _cell, _naming, _confirm]


## True while naming or the confirm is open over the drop menu -- and not over a
## screen that opened it for its own thing ([member _answer]), nor over a cell.
func _over_menu() -> bool:
	return _open != null and (_open == _naming or _open == _confirm) and not _answer.is_valid()


## True while naming or the confirm is open over a cell's detailed view.
func _over_cell() -> bool:
	return _open != null and (_open == _naming or _open == _confirm) and _under == _cell


## True while the drop menu, or a layer over it, is open.
func _in_drops() -> bool:
	return _open != null and (_open == _drops or _over_menu())


## **[param layer] on top**, the others hidden, the veil under it. Naming and the
## confirm hide the cluster: naming's panel spans the top of the screen to x 920,
## and a wide chip starts at 824 (§9). So does a cell's detailed view, which is
## the whole screen (cells-ux.md §3.1).
func _show_layer(layer: Control) -> void:
	for each: Control in _layers():
		each.visible = each == layer
	_veil.show()
	_open = layer
	_cluster.visible = show_cluster \
		and not (layer == _naming or layer == _confirm or layer == _cell)


## Remembers what had the focus as the first layer opens, so closing gives it
## back -- or [param fallback], the button that opens the layer, when the focus is
## on nothing or inside the corner.
func _remember_opener(fallback: Control) -> void:
	if _open != null:
		return
	var focused := get_viewport().gui_get_focus_owner()
	_opener = focused if focused != null and not is_ancestor_of(focused) else fallback


## What opens naming or the confirm in the menu, for the focus to go back to: a
## row's own button, or null when the focus is anywhere else.
func _menu_focus() -> Control:
	var focused := get_viewport().gui_get_focus_owner()
	return focused if focused != null and _drops.is_ancestor_of(focused) else null


## Hides every layer, and when the player closed it, hands the focus back to
## whatever opened it -- or to the chip or the gear, when that has gone from the
## screen since: a page can change under the sheet.
func _shut(give_focus_back: bool) -> void:
	for each: Control in _layers():
		each.hide()
	_open = null
	_answer = Callable()
	_under = null
	_veil.hide()
	_cluster.visible = show_cluster
	if give_focus_back:
		var back_to := _opener if is_instance_valid(_opener) and _opener.is_visible_in_tree() \
			else null
		for button: Control in [_chip, _gear]:
			if back_to == null and button.is_visible_in_tree():
				back_to = button
		if back_to != null:
			back_to.grab_focus()
	_opener = null
	_layer_opener = null
	closed.emit()


## **A press on the veil closes the top layer** -- the press of a finger, or of a
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


# ---------------------------------------------------------------------------
# The settings sheet (§2).
# ---------------------------------------------------------------------------

## **Opens the settings sheet**, with the focus on the language in use (§2). The
## gear calls it; so can a screen that puts settings somewhere of its own.
func open_settings() -> void:
	if _open == _settings:
		return
	_remember_opener(_gear)
	_show_layer(_settings)
	_mark_in_use()
	var row: Button = _row_of.get(_in_use)
	if row != null:
		row.grab_focus()
	else:
		_close.grab_focus()


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
		_restyle(row, Vector2(ROW_TEXT_X, -1.0))
		row.draw.connect(_draw_mark.bind(row, locale))
		row.pressed.connect(_choose.bind(locale))
		_rows.add_child(row)
		_row_of[locale] = row
	# Six at once, and from the seventh the list scrolls (§2).
	var shown := mini(languages.size(), ROWS_SHOWN)
	_languages.custom_minimum_size = Vector2(ROW_SIZE.x,
		ROW_PITCH * shown - (ROW_PITCH - ROW_SIZE.y))
	var ring: Array[Control] = []
	for row: Button in _rows.get_children():
		ring.append(row)
	ring.append(_close)
	_trap_column(ring)


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
# The chip, and "your worlds" (§4.2-§4.4).
# ---------------------------------------------------------------------------

func _ready_chip() -> void:
	_chip.visible = show_drop
	_chip.focus_mode = Control.FOCUS_ALL
	_chip.pressed.connect(open_drops)
	_chip.draw.connect(_draw_chevron)
	_link_cluster()


## The rows' buttons, once: what each press does, the launcher's boxes with room
## for the mark, and the quiet slab on a row's own two.
func _ready_drops() -> void:
	for slot in range(1, Drops.SLOTS + 1):
		var pick := _pick(slot)
		pick.focus_mode = Control.FOCUS_ALL
		_restyle(pick, Vector2(ROW_TEXT_X, -1.0))
		pick.pressed.connect(_on_pick.bind(slot))
		pick.draw.connect(_draw_slot_mark.bind(pick, slot))
		for action: Button in [_rename_of(slot), _delete_of(slot)]:
			action.focus_mode = Control.FOCUS_ALL
			_restyle(action, QUIET_MARGIN)
			if quiet_box != null:
				action.add_theme_stylebox_override(&"normal", quiet_box)
		_rename_of(slot).pressed.connect(open_naming.bind(slot))
		_delete_of(slot).pressed.connect(open_confirm.bind(slot))


## **Opens "your worlds"** under the chip (§4.2), read afresh, with the focus on
## the drop you are in.
func open_drops() -> void:
	if _open == _drops:
		return
	_remember_opener(_chip)
	_read_drops()
	_say_chip()
	_show_layer(_drops)
	_say_drops()
	_pick(int(_index["selected"])).grab_focus()


## **Back from naming or the confirm to the menu**, which says the drops as they
## now are, with the focus where it was when it left.
func _back_to_drops() -> void:
	_read_drops()
	_say_chip()
	_show_layer(_drops)
	_say_drops()
	var back_to := _layer_opener if is_instance_valid(_layer_opener) \
		and _layer_opener.is_visible_in_tree() else null
	if back_to == null:
		back_to = _pick(_slot if _slot >= 1 else int(_index["selected"]))
	back_to.grab_focus()
	_layer_opener = null


## **A row tapped** (§4.4): an empty one opens naming for a new drop; a drop is
## selected, in one tap, because choosing is what the menu is for -- and the menu
## closes, and the chip says it.
func _on_pick(slot: int) -> void:
	if bool(Drops.entry_of(_index, slot)["empty"]):
		open_naming(slot)
		return
	if slot != int(_index["selected"]):
		var done := Drops.select(slot, drops_root)
		if done != OK:
			push_warning("[Corner] drop %d was not selected (%s)" % [slot, error_string(done)])
			_read_drops()
			_say_drops()
			return
	_read_drops()
	_say_chip()
	_shut(true)


func _read_drops() -> void:
	_index = Drops.read(drops_root)


## **The menu's rows** (§4.2, §4.3): a drop's name and its line; "new world" on an
## empty row, which has no buttons of its own; rename on every drop; and delete
## on every drop but the one you are in, whose place is kept by an empty box so
## the columns stay put.
func _say_drops() -> void:
	# TRANSLATORS: The caption at the top of the menu of the player's worlds, in
	# 16 px type; also the tooltip of the button that opens it. A "world" is one of
	# the three the player keeps: a drop of water with everything living in it.
	# ROOM: 592 px at 16 px
	_drops_caption.text = tr("your worlds")
	# TRANSLATORS: The footnote under the menu of the player's worlds, in 15 px
	# type. "Water" is what everything in a world swims in. The player's cells are
	# kept apart from the worlds, so a world keeps only that.
	# ROOM: 592 px at 15 px
	_drops_note.text = tr("each world keeps its own water")
	if _index.is_empty():
		return
	for slot in range(1, Drops.SLOTS + 1):
		var entry := Drops.entry_of(_index, slot)
		var empty := bool(entry["empty"])
		var current := slot == int(_index["selected"]) and not empty
		var pick := _pick(slot)
		var called: Label = pick.get_node(^"Lines/Name")
		var stats: Label = pick.get_node(^"Lines/Stats")
		# TRANSLATORS: An empty row in the menu of the player's worlds, in 20 px
		# type: tap it to make a new world there and name it.
		# ROOM: 280 px at 20 px
		called.text = tr("new world") if empty else Drops.name_of(entry)
		called.add_theme_color_override(&"font_color", Color(INK, EMPTY_ALPHA if empty else 1.0))
		var lines := Drops.lines_of(entry)
		stats.text = "\n".join(lines)
		stats.visible = not empty
		_fit_row(slot, lines.size())
		pick.accessibility_name = called.text
		var box: StyleBox = empty_box if empty else (current_box if current else null)
		if box == null:
			box = _moved(get_theme_stylebox(&"normal", &"Button"), Vector2(ROW_TEXT_X, -1.0))
		pick.add_theme_stylebox_override(&"normal", box)
		pick.queue_redraw()
		var rename := _rename_of(slot)
		var delete := _delete_of(slot)
		# TRANSLATORS: A small button on a world's row in the menu of the player's
		# worlds, in 15 px type, 112 px wide: give the world a new name. Also the
		# confirming button of the naming sheet, in 20 px type, 232 px wide.
		# ROOM: 88 px at 15 px
		rename.text = tr("rename")
		# TRANSLATORS: A small button on a world's row, in 15 px type, 112 px wide:
		# delete the world (it asks first). Also the confirming button of that
		# question, in 20 px type, 208 px wide.
		# ROOM: 88 px at 15 px
		delete.text = tr("delete")
		rename.visible = not empty
		delete.visible = not empty and not current
		_hold_of(slot).visible = current
	_trap_drops()


## **A row as tall as its lines** (§4.3): a name and one line under it fit the
## height corner.tscn gives every row, and each line more adds one line of the
## Stats label's own type, so the row grows and its lines never crowd. A world's
## row has one line, its age (cells-ux.md §5); a cell's has two.
func _fit_row(slot: int, lines: int) -> void:
	var pick := _pick(slot)
	if _row_height <= 0.0:
		_row_height = pick.custom_minimum_size.y
	var stats: Label = pick.get_node(^"Lines/Stats")
	var step := stats.get_theme_font(&"font").get_height(stats.get_theme_font_size(&"font_size")) \
		+ float(stats.get_theme_constant(&"line_spacing"))
	pick.custom_minimum_size.y = _row_height + step * float(maxi(lines - 1, 0))


## **The mark at a row's left** (§4.2): the filled dot of the drop you are in,
## the empty ring of another, the plus of an empty row.
func _draw_slot_mark(pick: Button, slot: int) -> void:
	if _index.is_empty():
		return
	var at := Vector2(MARK_X, pick.size.y * 0.5)
	if bool(Drops.entry_of(_index, slot)["empty"]):
		var ink := Color(INK, PLUS_ALPHA)
		pick.draw_line(at - Vector2(PLUS_ARM, 0.0), at + Vector2(PLUS_ARM, 0.0), ink, 2.0, true)
		pick.draw_line(at - Vector2(0.0, PLUS_ARM), at + Vector2(0.0, PLUS_ARM), ink, 2.0, true)
	elif slot == int(_index["selected"]):
		pick.draw_circle(at, MARK_R, BRIGHT, true, -1.0, true)
	else:
		pick.draw_arc(at, MARK_R, 0.0, TAU, 32, Color(INK, RING_ALPHA), RING_WIDTH, true)


## **The keyboard stays in the menu**: Up and Down walk the rows, keeping to a
## column where the next row has one; Left and Right walk a row; Tab goes round
## them all in reading order.
func _trap_drops() -> void:
	var grid: Array = []
	for slot in range(1, Drops.SLOTS + 1):
		var row: Array[Control] = []
		for control: Control in [_pick(slot), _rename_of(slot), _delete_of(slot)]:
			if control.visible:
				row.append(control)
		grid.append(row)
	_trap_grid(grid)


## **A grid of rows kept on its sheet** ([method _trap_drops] and
## [method _trap_cells]): [param grid] is its rows, each its controls left to
## right. Up and Down keep to a column where the next row has one, Left and Right
## walk a row, and Tab goes round them all in reading order.
func _trap_grid(grid: Array) -> void:
	var ring: Array[Control] = []
	for r in grid.size():
		var row: Array[Control] = grid[r]
		for c in row.size():
			var control := row[c]
			var above: Array[Control] = grid[maxi(r - 1, 0)]
			var below: Array[Control] = grid[mini(r + 1, grid.size() - 1)]
			control.focus_neighbor_top = control.get_path_to(above[mini(c, above.size() - 1)])
			control.focus_neighbor_bottom = control.get_path_to(below[mini(c, below.size() - 1)])
			control.focus_neighbor_left = control.get_path_to(row[maxi(c - 1, 0)])
			control.focus_neighbor_right = control.get_path_to(row[mini(c + 1, row.size() - 1)])
			ring.append(control)
	for i in ring.size():
		ring[i].focus_previous = ring[i].get_path_to(ring[posmod(i - 1, ring.size())])
		ring[i].focus_next = ring[i].get_path_to(ring[(i + 1) % ring.size()])


func _row(slot: int) -> HBoxContainer:
	return _drops.get_node("Panel/Box/Row%d" % slot)


func _pick(slot: int) -> Button:
	return _row(slot).get_node(^"Pick")


func _rename_of(slot: int) -> Button:
	return _row(slot).get_node(^"Rename")


func _delete_of(slot: int) -> Button:
	return _row(slot).get_node(^"Delete")


func _hold_of(slot: int) -> Control:
	return _row(slot).get_node(^"Hold")


# ---------------------------------------------------------------------------
# Naming a drop (§5).
# ---------------------------------------------------------------------------

func _ready_naming() -> void:
	_field.max_length = Drops.NAME_MAX
	_field.text_submitted.connect(_on_named.unbind(1))
	_naming_back.pressed.connect(close_top)
	_make.pressed.connect(_on_named)
	for button: Button in [_naming_back, _make]:
		button.focus_mode = Control.FOCUS_ALL
	# Up from the buttons is the field, and Tab goes round the three.
	_trap_column([_field, _naming_back])
	_naming_back.focus_neighbor_right = _naming_back.get_path_to(_make)
	_make.focus_neighbor_left = _make.get_path_to(_naming_back)
	_make.focus_neighbor_right = _make.get_path_to(_make)
	_make.focus_neighbor_top = _make.get_path_to(_field)
	_make.focus_neighbor_bottom = _make.get_path_to(_make)
	_field.focus_neighbor_bottom = _field.get_path_to(_make)
	_field.focus_next = _field.get_path_to(_naming_back)
	_field.focus_previous = _field.get_path_to(_make)
	_naming_back.focus_next = _naming_back.get_path_to(_make)
	_make.focus_next = _make.get_path_to(_field)
	_make.focus_previous = _make.get_path_to(_naming_back)


## **Opens naming for [param slot]** (§5.1): a new drop on an empty slot, with the
## next default name, or that drop's name to rename it -- selected, so typing
## replaces it and the confirm keeps it. The panel is at the top of the screen on
## purpose: an Android keyboard covers about the bottom half of a landscape phone.
func open_naming(slot: int) -> void:
	_remember_opener(_chip)
	_layer_opener = _menu_focus()
	_read_drops()
	var entry := Drops.entry_of(_index, slot)
	_slot = slot
	_making = bool(entry["empty"])
	_naming_default = Drops.next_default(_index, slot) if _making else int(entry["default"])
	_field.text = Drops.default_name(_naming_default) if _making else Drops.name_of(entry)
	_offered = _field.text if _making or str(entry["name"]).is_empty() else ""
	_say_naming()
	_show_layer(_naming)
	_field.grab_focus()
	_field.select_all()


func _say_naming() -> void:
	if _making:
		# TRANSLATORS: The title of the sheet that names a new world, in 22 px type.
		# A "world" is one of the three the player keeps: a drop of water with
		# everything living in it.
		# ROOM: 512 px at 22 px
		_naming_title.text = tr("a new world")
		# TRANSLATORS: The confirming button of the sheet that names a new world, in
		# 20 px type, 232 px wide: make the new world, with the name typed above.
		# "It" is the world.
		# ROOM: 188 px at 20 px
		_make.text = tr("make it")
	else:
		# TRANSLATORS: The title of the sheet that renames one of the player's
		# worlds, in 22 px type.
		# ROOM: 512 px at 22 px
		_naming_title.text = tr("rename this world")
		_make.text = tr("rename")
	# TRANSLATORS: A button on the naming sheet, in 20 px type, 160 px wide: go back
	# to the menu of worlds, changing nothing.
	# ROOM: 116 px at 20 px
	_naming_back.text = tr("back")
	# What an empty name will be: the default, in the language of the moment. A
	# default the field was given and still holds, untouched, is said again in it
	# too; anything typed there is the player's own, and stays.
	var offered := Drops.default_name(_naming_default)
	_field.placeholder_text = offered
	if not _offered.is_empty() and _field.text == _offered and offered != _offered:
		_field.text = offered
		_field.select_all()
		_offered = offered


## **Naming opened for a screen's own thing** (automation-ux.md §2.5): the world's
## sheet with [param title] over the field, [param name] in it and selected, and
## [param fallback] -- what an empty name keeps -- shown when it is emptied; `back`
## and `rename` under it. [param answer] is called with what was typed when it is
## kept, and the sheet closes back to the screen. **At the top of the screen**, as
## for a world: an Android keyboard covers the bottom half.
func open_naming_for(title: String, name: String, fallback: String,
		answer: Callable) -> void:
	_remember_opener(null)
	_layer_opener = null
	_answer = answer
	_making = false
	_offered = ""
	_naming_title.text = title
	_make.text = tr("rename")
	_naming_back.text = tr("back")
	_field.text = name
	_field.placeholder_text = fallback
	_show_layer(_naming)
	_field.grab_focus()
	_field.select_all()


## **The confirm opened for a screen's own thing** (automation-ux.md §2.5): a
## world's own question, `delete <name>?`, over [param line], with `keep` focused
## and `delete` beside it. [param answer] is called on `delete`, and the sheet
## closes back to the screen. There is no undo, as for a world.
func open_confirm_for(name: String, line: String, answer: Callable) -> void:
	_remember_opener(null)
	_layer_opener = null
	_answer = answer
	_confirm_title.text = tr("delete %s?") % name
	_confirm_line.text = line
	_keep.text = tr("keep")
	_delete.text = tr("delete")
	_show_layer(_confirm)
	_keep.grab_focus()


## **The name is kept** (§4.4, §5.2), from the button or the field's Enter: a new
## drop is made, selected, and everything closes; a renamed one goes back to the
## menu, which shows the new name. Trimmed, and the default name when empty. A
## sheet opened for a screen's own thing hands the name to its answer instead.
func _on_named() -> void:
	if _open != _naming:
		return
	var typed := _field.text
	if _answer.is_valid():
		var answer := _answer
		_closed_frame = Engine.get_process_frames()
		if _under == _cell:
			# **Kept, and back to the cell, which shows it** (cells-ux.md §3.4).
			answer.call(typed)
			_back_to_cell()
			return
		_shut(true)
		answer.call(typed)
		return
	if _making:
		var done := Drops.make(_slot, typed, drops_root)
		if done == OK:
			_read_drops()
			_say_chip()
			_closed_frame = Engine.get_process_frames()
			_shut(true)
			return
		push_warning("[Corner] drop %d was not made (%s)" % [_slot, error_string(done)])
	else:
		var done := Drops.rename(_slot, typed, drops_root)
		if done != OK:
			push_warning("[Corner] drop %d was not renamed (%s)" % [_slot, error_string(done)])
	_closed_frame = Engine.get_process_frames()
	_back_to_drops()


# ---------------------------------------------------------------------------
# Deleting a drop (§4.4).
# ---------------------------------------------------------------------------

func _ready_confirm() -> void:
	_keep.pressed.connect(close_top)
	_delete.pressed.connect(_on_delete)
	for button: Button in [_keep, _delete]:
		button.focus_mode = Control.FOCUS_ALL
	for one: Array in [[_keep, _delete], [_delete, _keep]]:
		var button: Button = one[0]
		var other: Button = one[1]
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
	_keep.focus_neighbor_left = _keep.get_path_to(_keep)
	_keep.focus_neighbor_right = _keep.get_path_to(_delete)
	_delete.focus_neighbor_left = _delete.get_path_to(_keep)
	_delete.focus_neighbor_right = _delete.get_path_to(_delete)


## **Asks before deleting [param slot]** (§4.4), with the focus on `keep`, the
## safe answer, as Back is. **Never for the drop you are in**, which has no
## delete: asked for it anyway, this does nothing.
func open_confirm(slot: int) -> void:
	_read_drops()
	if bool(Drops.entry_of(_index, slot)["empty"]) or slot == int(_index["selected"]):
		return
	_remember_opener(_chip)
	_layer_opener = _menu_focus()
	_slot = slot
	_say_confirm()
	_show_layer(_confirm)
	_keep.grab_focus()


func _say_confirm() -> void:
	if _index.is_empty() or _slot < 1:
		return
	# TRANSLATORS: The question asked before a world is deleted, in 22 px type,
	# wrapping onto two lines if it must. %s is the world's name, in the player's
	# own words or a default name such as "pond water": keep %s.
	_confirm_title.text = tr("delete %s?") % Drops.name_of(Drops.entry_of(_index, _slot))
	# TRANSLATORS: Under that question, in 17 px type, wrapping onto a second line
	# if it must: what deleting the world does. Two short sentences with full
	# stops. "It" is the world; "your cells" are the player's creatures, which are
	# kept apart from the worlds, so deleting one does not touch them (French
	# "vos cellules, non.").
	_confirm_line.text = tr("everything living in it is gone for good. your cells are not.")
	# TRANSLATORS: The safe answer to "delete pond water?" -- keep the world -- on a
	# button 208 px wide in 20 px type, beside "delete". The same word answers
	# "forget this invite?" on another screen.
	# ROOM: 164 px at 20 px
	_keep.text = tr("keep")
	_delete.text = tr("delete")


## **Deleted** (§4.4): the row is empty, and the menu says so. A confirm opened
## for a screen's own thing calls its answer instead.
func _on_delete() -> void:
	if _open != _confirm:
		return
	if _answer.is_valid():
		var answer := _answer
		_closed_frame = Engine.get_process_frames()
		if _under == _cell:
			# **Deleted, and back to the sheet**, whose row is empty now
			# (cells-ux.md §3.4).
			answer.call()
			_back_to_cells()
			return
		_shut(true)
		answer.call()
		return
	var done := Drops.delete(_slot, drops_root)
	if done != OK:
		push_warning("[Corner] drop %d was not deleted (%s)" % [_slot, error_string(done)])
	_closed_frame = Engine.get_process_frames()
	_back_to_drops()


# ---------------------------------------------------------------------------
# "Your cells", and a cell's detailed view (docs/design/cells-ux.md §2, §3).
# ---------------------------------------------------------------------------

## The rows corner.tscn gives the sheet, wired once: what each press does, the
## launcher's boxes with room for the mark, and the quiet slab on `look`.
func _ready_cells() -> void:
	for row: Node in _cell_rows.get_children():
		_wire_cell_row(row as HBoxContainer)


func _wire_cell_row(row: HBoxContainer) -> void:
	var pick: Button = row.get_node(^"Pick")
	var look: Button = row.get_node(^"Look")
	pick.focus_mode = Control.FOCUS_ALL
	_restyle(pick, Vector2(ROW_TEXT_X, -1.0))
	pick.pressed.connect(_on_cell_pick.bind(row))
	pick.draw.connect(_draw_cell_mark.bind(pick, row))
	look.focus_mode = Control.FOCUS_ALL
	_restyle(look, QUIET_MARGIN)
	if quiet_box != null:
		look.add_theme_stylebox_override(&"normal", quiet_box)
	look.pressed.connect(_open_cell.bind(row))


## **Opens "your cells" for [param mode]'s view** (cells-ux.md §2): that view's
## slots, read afresh, centred under the veil, with the focus on the one its
## button plays. The chooser's chevron beside the view calls it.
func open_cells(mode: int) -> void:
	if _open == _cells and _cells_mode == mode:
		return
	_remember_opener(null)
	_cells_mode = mode
	_cells_view = RunState.cell_key(mode)
	_read_cells()
	_show_layer(_cells)
	_say_cells()
	_focus_cell_row(int(_cells_index["selected"]))


func _read_cells() -> void:
	_cells_index = Cells.read(_cells_view, cells_root)
	_cells_worlds = Drops.read(drops_root)


## **The sheet's words and rows** (cells-ux.md §2.2): each slot's name and its two
## lines, its mark, its box and its `look` -- an empty slot says `new cell`, holds
## the place of a `look` it does not have, and starts a cell when its view is
## pressed; a record is its name and lines, fainter, under the plus of the cell
## that starts there.
func _say_cells() -> void:
	# TRANSLATORS: The caption at the top of the menu of the player's cells for one
	# of the two views, in 16 px type, before the view's name: "your cells · full
	# vision". Also the tooltip of the button beside each view that opens it. A
	# "cell" is the player's creature (French: une cellule, feminine); the player
	# keeps three for each view.
	_cells_caption.text = tr("your cells") + Readout.SEP + tr(RunState.VIEW_WORDS[_cells_mode])
	# TRANSLATORS: The footnote under the menu of the player's cells, in 15 px type:
	# a cell grown in one view (full vision, or point of view) can never be played
	# in the other, because they are not the same game. "It" is the cell (French
	# "née" agrees with "cellule").
	# ROOM: 592 px at 15 px
	_cells_note.text = tr("a cell is played only in the view it was born in")
	if _cells_index.is_empty():
		return
	var slots: Array = _cells_index["slots"]
	_grow_cell_rows(slots.size())
	var selected := int(_cells_index["selected"])
	for i in _cell_rows.get_child_count():
		var row := _cell_rows.get_child(i) as HBoxContainer
		row.visible = i < slots.size()
		if not row.visible:
			continue
		var entry: Dictionary = slots[i]
		var slot := int(entry["slot"])
		row.set_meta(&"slot", slot)
		var empty := bool(entry["empty"])
		var record := bool(entry["record"])
		var current := slot == selected
		var pick: Button = row.get_node(^"Pick")
		var called: Label = pick.get_node(^"Lines/Name")
		var stats: Label = pick.get_node(^"Lines/Stats")
		# TRANSLATORS: An empty row in the menu of the player's cells, in 20 px
		# type: tap it to choose it, and pressing the view then starts a new cell
		# there. A "cell" is the player's creature (French: une nouvelle cellule).
		# ROOM: 402 px at 20 px
		called.text = tr("new cell") if empty else Cells.name_of(entry)
		called.add_theme_color_override(&"font_color", Color(INK, EMPTY_ALPHA if empty
			else (RECORD_NAME_ALPHA if record else 1.0)))
		var lines := Cells.row_lines(entry, _cells_worlds, drops_root)
		stats.text = "\n".join(lines)
		stats.visible = not empty
		stats.add_theme_color_override(&"font_color", Color(NOTE_INK,
			RECORD_LINE_ALPHA if record else 1.0))
		_fit_cell_row(row, lines.size())
		pick.accessibility_name = called.text
		var box: StyleBox = (current_box if current else empty_box) if record \
			else (empty_box if empty and not current else (current_box if current else null))
		if box == null:
			box = _moved(get_theme_stylebox(&"normal", &"Button"), Vector2(ROW_TEXT_X, -1.0))
		pick.add_theme_stylebox_override(&"normal", box)
		pick.queue_redraw()
		var look: Button = row.get_node(^"Look")
		# TRANSLATORS: A small button on a cell's row in the menu of the player's
		# cells, in 15 px type, 112 px wide: open the cell's detailed view, to see
		# its body and its genes (French "voir").
		# ROOM: 88 px at 15 px
		look.text = tr("look")
		look.visible = not empty
		(row.get_node(^"Hold") as Control).visible = empty
	_size_cell_scroll(slots.size())
	_trap_cells()
	# **The sheet as tall as its rows.** A panel grows to fit by itself, and is
	# told to shrink: three empty slots are shorter than three cells, and shorter
	# than the panel corner.tscn draws. Deferred, so the rows' new heights are in.
	_cells_panel.reset_size.call_deferred()


## A cell's line ink, from corner.tscn's Stats labels.
const NOTE_INK := Color(0.482, 0.686, 0.643, 1.0)


## **Enough rows for [param count] slots**: the three corner.tscn has, and one
## more for each slot past them -- a cell an older build kept after the migration
## (cells.md §4) -- made like the third, and wired as the others are.
func _grow_cell_rows(count: int) -> void:
	while _cell_rows.get_child_count() < count:
		var model := _cell_rows.get_child(_cell_rows.get_child_count() - 1) as HBoxContainer
		var row := model.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
			| Node.DUPLICATE_USE_INSTANTIATION) as HBoxContainer
		row.name = "Row%d" % (_cell_rows.get_child_count() + 1)
		_cell_rows.add_child(row)
		_wire_cell_row(row)


## A row as tall as its lines, as a world's row is ([method _fit_row]): `look` and
## the hold beside it follow, as the box's other children.
func _fit_cell_row(row: HBoxContainer, lines: int) -> void:
	var pick: Button = row.get_node(^"Pick")
	if _cell_row_height <= 0.0:
		_cell_row_height = pick.custom_minimum_size.y
	var stats: Label = pick.get_node(^"Lines/Stats")
	var step := stats.get_theme_font(&"font").get_height(stats.get_theme_font_size(&"font_size")) \
		+ float(stats.get_theme_constant(&"line_spacing"))
	pick.custom_minimum_size.y = _cell_row_height + step * float(maxi(lines - 1, 0))


## **The rows show four at most** (cells-ux.md §2.1): as tall as they are up to
## [constant CELL_ROWS_SHOWN], after which they scroll.
func _size_cell_scroll(count: int) -> void:
	var height := 0.0
	var gap := float(_cell_rows.get_theme_constant(&"separation"))
	for i in mini(count, CELL_ROWS_SHOWN):
		var pick: Button = _cell_rows.get_child(i).get_node(^"Pick")
		height += pick.custom_minimum_size.y + (gap if i > 0 else 0.0)
	_cells_scroll.custom_minimum_size = Vector2(0.0, height)


## **The mark at a row's left** (cells-ux.md §2.2): the filled dot of the cell the
## view plays, the empty ring of another, and the plus of an empty slot -- and of
## a record, where a new cell starts.
func _draw_cell_mark(pick: Button, row: HBoxContainer) -> void:
	if _cells_index.is_empty() or not row.has_meta(&"slot"):
		return
	var slot := int(row.get_meta(&"slot"))
	var entry := Cells.entry_of(_cells_index, slot)
	var at := Vector2(MARK_X, pick.size.y * 0.5)
	if bool(entry["empty"]) or bool(entry["record"]):
		var ink := Color(INK, PLUS_ALPHA)
		pick.draw_line(at - Vector2(PLUS_ARM, 0.0), at + Vector2(PLUS_ARM, 0.0), ink, 2.0, true)
		pick.draw_line(at - Vector2(0.0, PLUS_ARM), at + Vector2(0.0, PLUS_ARM), ink, 2.0, true)
	elif slot == int(_cells_index["selected"]):
		pick.draw_circle(at, MARK_R, BRIGHT, true, -1.0, true)
	else:
		pick.draw_arc(at, MARK_R, 0.0, TAU, 32, Color(INK, RING_ALPHA), RING_WIDTH, true)


## Up and Down walk the rows, Left and Right a row's `Pick` and `look`, and Tab
## goes round (cells-ux.md §2.3): [method _trap_drops], one more time.
func _trap_cells() -> void:
	var grid: Array = []
	for row: Node in _cell_rows.get_children():
		if not (row as Control).visible:
			continue
		var line: Array[Control] = [row.get_node(^"Pick") as Control]
		var look := row.get_node(^"Look") as Control
		if look.visible:
			line.append(look)
		grid.append(line)
	_trap_grid(grid)


## The focus on [param slot]'s row, or the first row's when it is not shown.
func _focus_cell_row(slot: int) -> void:
	for row: Node in _cell_rows.get_children():
		if (row as Control).visible and int(row.get_meta(&"slot", 0)) == slot:
			(row.get_node(^"Pick") as Control).grab_focus()
			return
	(_cell_rows.get_child(0).get_node(^"Pick") as Control).grab_focus()


## **A row tapped** (cells-ux.md §2.3): that slot becomes the one its view plays,
## and the sheet closes -- the view's button then says its cell. An empty slot is
## chosen too: a new cell is born there when the view is pressed. Tapping the row
## already chosen just closes the sheet.
func _on_cell_pick(row: HBoxContainer) -> void:
	var slot := int(row.get_meta(&"slot", 0))
	if slot < 1 or _open != _cells:
		return
	if slot != int(_cells_index["selected"]):
		var done := Cells.select(_cells_view, slot, cells_root)
		if done != OK:
			push_warning("[Corner] cell slot %d was not chosen (%s)" % [slot, error_string(done)])
			_read_cells()
			_say_cells()
			return
	_shut(true)


## **`look`: the cell's detailed view** (cells-ux.md §3), over the sheet, with the
## focus on `close`, so a stray Enter only closes it.
func _open_cell(row: HBoxContainer) -> void:
	var slot := int(row.get_meta(&"slot", 0))
	var entry := Cells.entry_of_slot(_cells_view, slot, cells_root)
	if bool(entry["empty"]) or _open != _cells:
		return
	_cell_slot = slot
	_cell_entry = entry
	_cell_opener = row.get_node(^"Look")
	_cell_action = null
	_make_cell_figure()
	_show_layer(_cell)
	_say_cell()
	_trap_cell()
	_cell_close.grab_focus()


## **The figure is made the first time a detailed view opens** (cell_figure.gd
## says why), and kept.
func _make_cell_figure() -> void:
	if _cell_figure != null and is_instance_valid(_cell_figure):
		return
	var script := load(CELL_FIGURE) as GDScript
	if script == null:
		push_warning("[Corner] no cell figure at %s" % CELL_FIGURE)
		return
	_cell_figure = script.new() as Control
	_cell_seat.add_child(_cell_figure)


## **The detailed view's words** (cells-ux.md §3.2, §3.5): the name; the view and
## the generation; the line's age and its hunger, hidden when neither is known;
## for a living cell, where it is and **what pressing its view will do** -- the one
## place the player is told about a place given up -- and for a record, where it
## died, with nothing to rename or delete. Then the figure.
func _say_cell() -> void:
	if _cell_entry.is_empty():
		return
	var record := bool(_cell_entry["record"])
	_cell_name.text = Cells.name_of(_cell_entry)
	_cell_kind.text = Drops.cell_line(_cells_mode, Cells.generation_of(_cell_entry))
	var age := Cells.age_and_hunger(_cell_entry)
	_cell_age.text = age
	_cell_age.visible = not age.is_empty()
	_cell_where.visible = not record
	var place := Cells.place_of(_cell_entry, _cells_worlds, drops_root)
	if record:
		_cell_then.text = Cells.where_line(_cell_entry, _cells_worlds, drops_root)
	else:
		var in_world := place == Cells.Place.HERE or place == Cells.Place.THERE
		_cell_where_caption.visible = in_world
		_cell_where_caption.text = tr("world")
		_cell_where_value.text = Cells.world_name_of(_cell_entry, _cells_worlds) if in_world \
			else (Cells.friends_water() if place == Cells.Place.FRIEND else Cells.gone_world())
		if place == Cells.Place.HERE:
			# TRANSLATORS: In a cell's detailed view, in 15 px type under where the
			# cell is: pressing its view will play it where the player left it. A
			# "cell" is the player's creature (French "là où vous l'avez laissée":
			# "laissée" agrees with "cellule").
			# ROOM: 280 px at 15 px
			_cell_then.text = tr("where you left it")
		else:
			# TRANSLATORS: The same, when the cell's place is not in the world that
			# is selected now: pressing its view brings it into that world, at a
			# quiet place. %s is that world's name in quotation marks ("comes into
			# “pond water” at a quiet place"). It may wrap onto a second line of
			# 280 px, and no more.
			_cell_then.text = tr("comes into %s at a quiet place") % Cells.quoted(
				Drops.name_of(Drops.entry_of(_cells_worlds, int(_cells_worlds["selected"]))))
	_cell_actions.visible = not record
	_cell_rename.text = tr("rename")
	_cell_delete.text = tr("delete")
	_cell_close.text = tr("close")
	if _cell_figure != null and is_instance_valid(_cell_figure):
		_cell_figure.call(&"show_cell", _cell_entry["data"]["cell"], record)


## **The detailed view's keyboard** (cells-ux.md §3.4): Tab goes from `close` to
## `rename`, `delete`, the ring of slots from the nose, `numbers`, and back to
## `close`; the arrows walk the side's buttons, and on the ring go where they
## point, as on pause. Nothing leads off the layer.
func _trap_cell() -> void:
	var record := bool(_cell_entry.get("record", false))
	var side: Array[Control] = [_cell_close]
	if not record:
		side = [_cell_close, _cell_rename, _cell_delete]
	var figure := _cell_figure if _cell_figure != null and is_instance_valid(_cell_figure) else null
	var first: Control = figure.call(&"first_chip") if figure != null else _cell_close
	var last: Control = figure.call(&"toggle") if figure != null else side[side.size() - 1]
	for i in side.size():
		var control := side[i]
		control.focus_next = control.get_path_to(side[i + 1] if i + 1 < side.size() else first)
		control.focus_previous = control.get_path_to(side[i - 1] if i > 0 else last)
		for way in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			control.set_focus_neighbor(way, control.get_path_to(control))
	if figure != null:
		figure.call(&"link_tab", side[side.size() - 1], _cell_close)
	if not record:
		_cell_close.focus_neighbor_top = _cell_close.get_path_to(_cell_rename)
		_cell_rename.focus_neighbor_bottom = _cell_rename.get_path_to(_cell_close)
		_cell_rename.focus_neighbor_right = _cell_rename.get_path_to(_cell_delete)
		_cell_delete.focus_neighbor_bottom = _cell_delete.get_path_to(_cell_close)
		_cell_delete.focus_neighbor_left = _cell_delete.get_path_to(_cell_rename)


## **Back from the detailed view to the sheet**, which says the cells as they now
## are, with the focus where it left: the row's `look`, or its row when the cell
## has gone.
func _back_to_cells() -> void:
	_under = null
	_answer = Callable()
	_read_cells()
	_show_layer(_cells)
	_say_cells()
	if is_instance_valid(_cell_opener) and _cell_opener.is_visible_in_tree():
		_cell_opener.grab_focus()
	else:
		_focus_cell_row(_cell_slot)
	_cell_opener = null


## **Back from naming or the confirm to the detailed view**, which says the cell
## as it now is, with the focus on the button that opened them -- or back to the
## sheet, when the cell is no longer there.
func _back_to_cell() -> void:
	_under = null
	_answer = Callable()
	var entry := Cells.entry_of_slot(_cells_view, _cell_slot, cells_root)
	if bool(entry["empty"]):
		_back_to_cells()
		return
	_cell_entry = entry
	_cells_worlds = Drops.read(drops_root)
	_show_layer(_cell)
	_say_cell()
	_trap_cell()
	var back_to := _cell_action if is_instance_valid(_cell_action) \
		and _cell_action.is_visible_in_tree() else _cell_close
	back_to.grab_focus()
	_cell_action = null


func _ready_cell() -> void:
	for button: Button in [_cell_rename, _cell_delete]:
		button.focus_mode = Control.FOCUS_ALL
		_restyle(button, QUIET_MARGIN)
		if quiet_box != null:
			button.add_theme_stylebox_override(&"normal", quiet_box)
	_cell_close.focus_mode = Control.FOCUS_ALL
	_cell_rename.pressed.connect(_on_cell_rename)
	_cell_delete.pressed.connect(_on_cell_delete)
	_cell_close.pressed.connect(close_top)


## **`rename`** (cells-ux.md §3.4): the corner's own naming sheet, its name in the
## field and selected, so typing replaces it; a default's own words keep the
## default, as for a world. Kept, it goes back to this view, which shows it.
func _on_cell_rename() -> void:
	if _open != _cell or bool(_cell_entry.get("record", true)):
		return
	var view := _cells_view
	var slot := _cell_slot
	var root := cells_root
	open_naming_for(_cell_naming_title(), Cells.name_of(_cell_entry),
		Cells.default_name(int(_cell_entry["data"]["default"])),
		func(typed: String) -> void:
			var done := Cells.rename(view, slot, typed, root)
			if done != OK:
				push_warning("[Corner] cell slot %d was not renamed (%s)" % [slot,
					error_string(done)]))
	_under = _cell
	_cell_action = _cell_rename


## **`delete`** (cells-ux.md §3.4): the corner's confirm, `keep` focused and Back
## meaning keep; `delete` empties the slot and goes back to the sheet. **The cell
## a view plays can be deleted**: its slot stays chosen, and the view starts a new
## cell there.
func _on_cell_delete() -> void:
	if _open != _cell or bool(_cell_entry.get("record", true)):
		return
	var view := _cells_view
	var slot := _cell_slot
	var root := cells_root
	open_confirm_for(Cells.name_of(_cell_entry), _cell_gone_line(),
		func() -> void:
			var done := Cells.delete(view, slot, root)
			if done != OK:
				push_warning("[Corner] cell slot %d was not deleted (%s)" % [slot,
					error_string(done)]))
	_under = _cell
	_cell_action = _cell_delete


func _cell_naming_title() -> String:
	# TRANSLATORS: The title of the sheet that renames one of the player's cells, in
	# 22 px type. A "cell" is the player's creature (French: renommer cette
	# cellule).
	# ROOM: 512 px at 22 px
	return tr("rename this cell")


func _cell_gone_line() -> String:
	# TRANSLATORS: Under the question "delete slipper?" (slipper being a cell's
	# name), in 17 px type, wrapping if it must: what deleting one of the player's
	# cells does. A full sentence with a full stop. "Its" is the cell's: its body
	# and the genes it carries.
	return tr("its body and its genes are gone for good.")


## The cell's naming sheet, said again in the language of the moment.
func _say_cell_naming() -> void:
	_naming_title.text = _cell_naming_title()
	_make.text = tr("rename")
	_naming_back.text = tr("back")
	if not _cell_entry.is_empty() and not bool(_cell_entry["empty"]):
		_field.placeholder_text = Cells.default_name(int(_cell_entry["data"]["default"]))


## The cell's confirm, said again in the language of the moment.
func _say_cell_confirm() -> void:
	# TRANSLATORS: The question asked before one of the player's cells is deleted,
	# in 22 px type: %s is the cell's name, the player's own words or a default
	# such as "slipper".
	_confirm_title.text = tr("delete %s?") % Cells.name_of(_cell_entry)
	_confirm_line.text = _cell_gone_line()
	_keep.text = tr("keep")
	_delete.text = tr("delete")


# ---------------------------------------------------------------------------
# The words, said again whenever the language changes (§3.3).
# ---------------------------------------------------------------------------

## Every word the corner shows. A Label given `tr()` of a message keeps the words
## and not the message, so it would stay in the language it was given (§3.3):
## this is called from `_ready` and, deferred, on every change of language.
func _say() -> void:
	# TRANSLATORS: The title of the settings sheet, which opens from a gear in the
	# top-right corner of every screen; also that gear's tooltip, and the 300 px
	# button between play and quit on the launcher's first screen. One lowercase
	# word: the app's settings (here only the language, for now).
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
	_say_chip()
	if _in_drops():
		_say_drops()
	if _open == _cells:
		_say_cells()
	elif _open == _cell:
		_say_cell()
	# A sheet opened for a screen's own thing was given its words by that screen,
	# which says them again itself; one opened over a cell is the corner's own.
	if _open == _naming and _under == _cell:
		_say_cell_naming()
	elif _open == _confirm and _under == _cell:
		_say_cell_confirm()
	elif _open == _naming and not _answer.is_valid():
		_say_naming()
	elif _open == _confirm and not _answer.is_valid():
		_say_confirm()


## **The chip's words** (§1.2): `world`, then the selected world's name, the chip
## as wide as they are up to [constant CHIP_MAX].
func _say_chip() -> void:
	# TRANSLATORS: The caption on a button in the top-right corner, in 17 px type,
	# before the name of the world that is selected ("world  pond water"). A
	# "world" is one of the three the player keeps: a drop of water and everything
	# in it, named by the player. One lowercase word.
	# ROOM: 80 px at 17 px
	_chip_caption.text = tr("world")
	_chip.tooltip_text = tr("your worlds")
	if _index.is_empty():
		return
	var called := Drops.name_of(Drops.entry_of(_index, int(_index["selected"])))
	_chip_name.text = called
	_chip.accessibility_name = "%s %s" % [_chip_caption.text, called]
	var font := _chip_name.get_theme_font(&"font")
	var words := font.get_string_size(_chip_caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		CHIP_FONT).x + CHIP_GAP + font.get_string_size(called, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		CHIP_FONT).x
	# Two px over the words, so a name that fits is never shortened by rounding.
	_chip.custom_minimum_size.x = minf(ceilf(CHIP_LEFT + words + CHIP_RIGHT) + 2.0, CHIP_MAX)


## **The chevron, drawn**, as the gear is: it says the chip opens a menu.
func _draw_chevron() -> void:
	var at := Vector2(_chip.size.x - CHEVRON_IN, _chip.size.y * 0.5)
	var points := PackedVector2Array()
	for point: Vector2 in CHEVRON:
		points.append(at + point)
	_chip.draw_polyline(points, Color(INK, CHEVRON_ALPHA), 2.0, true)


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


# ---------------------------------------------------------------------------
# Shared.
# ---------------------------------------------------------------------------

## **The keyboard stays on a sheet while it is open.** Godot looks for the next
## control by where it is on the screen and by the order of the tree, and both
## lead off the sheet: Up from the first row to whatever is above it under the
## veil, Tab from the last button to the screen's own first. So every way out of
## [param column] is named: Up and Down within it, Tab round it, and nothing to
## either side.
func _trap_column(column: Array) -> void:
	for i in column.size():
		var control: Control = column[i]
		var before: Control = column[maxi(i - 1, 0)]
		var after: Control = column[mini(i + 1, column.size() - 1)]
		control.focus_neighbor_top = control.get_path_to(before)
		control.focus_neighbor_bottom = control.get_path_to(after)
		control.focus_neighbor_left = control.get_path_to(control)
		control.focus_neighbor_right = control.get_path_to(control)
		control.focus_previous = control.get_path_to(column[posmod(i - 1, column.size())])
		control.focus_next = control.get_path_to(column[(i + 1) % column.size()])


## Gives [param button] the launcher's own boxes, each moved to [param margin]:
## x for both sides (the left only, when y is negative) and y for top and bottom.
func _restyle(button: Button, margin: Vector2) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state,
			_moved(get_theme_stylebox(state, &"Button"), margin))


## A copy of [param box] with its words moved to [param margin] (see [method _restyle]).
func _moved(box: StyleBox, margin: Vector2) -> StyleBox:
	var moved := box.duplicate() as StyleBox
	moved.content_margin_left = margin.x
	if margin.y >= 0.0:
		moved.content_margin_right = margin.x
		moved.content_margin_top = margin.y
		moved.content_margin_bottom = margin.y
	return moved
