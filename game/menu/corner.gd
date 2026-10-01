extends Control
## **The corner every screen carries** (docs/design/settings.md §1): a gear in the
## top-right corner, one launcher edge margin in -- the pause tap's mirror -- and,
## where a drop can be chosen, a chip beside it with the selected drop's name; and
## the sheets the two open. The gear opens settings, which holds the language list
## (§2, §3). The chip opens "your worlds" (§4): one tap selects a drop, an empty row
## makes a new one through the naming sheet (§5), and a row's own buttons rename it
## or, through a confirm, delete it. **The player's word for a drop is "world"**
## (owner's row 5): every word on screen says world, and the code says drop, as
## ocean.md and drops.gd do.
##
## It is the **last child** of the view chooser and of the earshot screen (so of
## far.tscn too), and of the pause screen in a run, where it hides with the screen.
## Last, because input goes to the last child first: Esc reaches the corner before
## the screen under it, and the corner takes it while something is open. Android
## Back is a notification, which goes to the parent first, so **every screen's Back
## asks [method close_top] before doing what Back does**, and stops when it says
## true. The corner never listens for Back itself: if it did, one Back would close
## two things. **One Back closes one layer**: naming and the confirm go back to the
## drop menu, and the menu or the settings sheet back to the screen.
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
			_cluster.visible = value and not _over_menu()
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
var _slot := 0
var _making := false
var _naming_default := 0
var _offered := ""
## The screen's topmost control, and the ones in a row with it, which Up leaves
## for the cluster ([method link_focus]).
var _below: Control = null
var _beside: Array = []


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
## confirm go back to the drop menu -- Back means "nothing changed" on the one,
## and "keep" on the other -- and the menu and the settings sheet to the screen.
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

## The four layers, in the order they are drawn.
func _layers() -> Array[Control]:
	return [_settings, _drops, _naming, _confirm]


## True while naming or the confirm is open over the drop menu.
func _over_menu() -> bool:
	return _open != null and (_open == _naming or _open == _confirm)


## True while the drop menu, or a layer over it, is open.
func _in_drops() -> bool:
	return _open != null and (_open == _drops or _over_menu())


## **[param layer] on top**, the others hidden, the veil under it. Naming and the
## confirm hide the cluster: naming's panel spans the top of the screen to x 920,
## and a wide chip starts at 824 (§9).
func _show_layer(layer: Control) -> void:
	for each: Control in _layers():
		each.visible = each == layer
	_veil.show()
	_open = layer
	_cluster.visible = show_cluster and not _over_menu()


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
	# type. "Water" is what everything in a world swims in; "your cell" is the
	# player's creature, which waits in the world it was left in.
	# ROOM: 592 px at 15 px
	_drops_note.text = tr("each world keeps its own water, and your cell in it")
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
		stats.text = Drops.line_of(entry)
		stats.visible = not empty
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


## **The name is kept** (§4.4, §5.2), from the button or the field's Enter: a new
## drop is made, selected, and everything closes; a renamed one goes back to the
## menu, which shows the new name. Trimmed, and the default name when empty.
func _on_named() -> void:
	if _open != _naming:
		return
	var typed := _field.text
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
	# TRANSLATORS: Under that question, in 17 px type, wrapping: what deleting the
	# world does. A full sentence with a full stop. "It" is the world; "your cell"
	# is the player's creature, which waits in the world it was left in.
	_confirm_line.text = tr("everything living in it, and your cell with it, is gone for good.")
	# TRANSLATORS: The safe answer to "delete pond water?" -- keep the world -- on a
	# button 208 px wide in 20 px type, beside "delete". The same word answers
	# "forget this invite?" on another screen.
	# ROOM: 164 px at 20 px
	_keep.text = tr("keep")
	_delete.text = tr("delete")


## **Deleted** (§4.4): the row is empty, and the menu says so.
func _on_delete() -> void:
	if _open != _confirm:
		return
	var done := Drops.delete(_slot, drops_root)
	if done != OK:
		push_warning("[Corner] drop %d was not deleted (%s)" % [_slot, error_string(done)])
	_closed_frame = Engine.get_process_frames()
	_back_to_drops()


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
	if _open == _naming:
		_say_naming()
	elif _open == _confirm:
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
