extends VBoxContainer
## **A cell's figure, read-only** (docs/design/cells-ux.md §3.3): the pause
## screen's genome group for a cell nobody is playing, drawn from its file through
## figure.gd -- the pause screen's own drawing, made callable from plain values
## (docs/design/cells.md §6.2, phase 1). It never makes a `Genome` or a
## `CellBody`: a cell here is the Dictionary its slot keeps (DropSave.CELL).
##
## It shows **the caption**, `genome · fourth generation`, with the numbers on
## the body's size and tank too; **the tray**, its waiting genes and its forks,
## drawn and never pressed, their clocks frozen as the save froze them; **the
## figure**, the body as kept -- slack if it was hungry, stained if dosed -- its
## tethers and its eight chips; and **the lines under it**. **Reading, and only
## reading**: hovering, focusing or tapping a live slot reads it -- the arc lights
## on the body, and the lines say what that gene does and what passes on -- and a
## slot never arms, nothing drags, and there is no verb line, because there is
## nothing to do. **The `numbers` switch** turns on the same remembered
## preference the pause screen's does (gene-stats.md §2.2).
##
## Built in code, as the pause screen builds its chips, and **loaded only when a
## cell's detailed view first opens** (game/menu/corner.gd): figure.gd brings the
## water's whole code with it, which no menu should pay for until it is asked.
##
## No class_name, for the reason signal_bus.gd gives. Load it by path.

const Figure := preload("res://game/normal/figure.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const CellBody := preload("res://game/normal/cell.gd")
const Catalogue := preload("res://game/genes/catalogue.gd")
const Cilia := preload("res://game/vision/cilia.gd")
const Progression := preload("res://game/mechanics/progression.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")
const FoodField := preload("res://game/normal/food.gd")
## For the `numbers` switch's one remembered preference.
const RunState := preload("res://game/run_state.gd")

## Nothing read: no slot hovered, none selected.
const SLOT_NONE := -9
## **The pause screen's genome group, to the pixel** (normal_mode.tscn's
## `Genome`): a column 560 px wide, its rows 8 apart, a tray at least 48 tall, and
## the lines under the figure as tall as their three rows -- so the figure sits
## exactly where the pause screen's does.
const WIDTH := 560.0
const SEPARATION := 8
const TRAY_HEIGHT := 48.0
const TRAY_GAP := 8
const LINES_GAP := 8
const EXPLAIN_HEIGHT := 26.0
const HINT_HEIGHT := 20.0
const HINT_GAP := 6
const ROW_HEIGHT := 19.0
## The switch, out to the right of the lines, where the pause screen has it.
const TOGGLE_RECT := Rect2(16.0, -11.0, 96.0, 48.0)

## **How much of the figure a record shows** (cells-ux.md §3.5): a memory, not a
## cell -- the caption, the tray, the figure and its lines. The `numbers` switch
## is not dimmed with them: it still works, and a faint switch reads as one that
## does not.
const RECORD_ALPHA := 0.55

var _caption: Label = null
var _tray: HFlowContainer = null
var _box: Control = null
var _body: Control = null
var _slots: Control = null
var _lines: Control = null
var _stack: VBoxContainer = null
var _organ: Control = null
var _gene: Label = null
var _says: Label = null
var _numbers: Control = null
var _hint_row: HBoxContainer = null
var _hint_level: Label = null
var _hint_gauge: Control = null
var _hint: Label = null
var _toggle: Control = null

## **The cell, as plain values**, read off its file by [method show_cell]: the
## eight genes the chips stand for (the DNA's outside layout and its inside), how
## many are live, the DNA and the body by gene, where the body wears each organ,
## the lineage's levels, what waits and which forks are open, its size, its
## generation, how slack and how dosed it is.
var _genes: Array[StringName] = []
var _live := 0
var _dna := {}
var _tiers := {}
var _worn: Array[StringName] = []
var _levels := {}
var _waiting: Array = []
var _forks: Array[StringName] = []
var _radius := CellBody.BASE_RADIUS
var _generation := 1
var _slack := 0.0
var _felt := Vector3.ZERO

## The chips, by slot; the slot being read by the pointer, and the one selected.
var _chips: Array[Control] = []
var _hovered := SLOT_NONE
var _selected := SLOT_NONE
## What the explanation line reads -- the gene, its copies, where -- and the
## numbers it gives; the gene the gauge draws.
var _explain_gene: StringName = &""
var _explain_tier := 0
var _explain_at := -1
var _numbers_lines: Array = [[], []]
var _numbers_dim := false
var _gauge_gene: StringName = &""
## The switch: on, hovered, and the frame it last answered on -- a touch arrives
## twice, as itself and as the click emulated from it.
var _show_numbers := false
var _numbers_hot := false
var _numbers_frame := -1
var _toggle_boxes: Array[StyleBoxFlat] = []
var _gauge_track: StyleBoxFlat = null
var _gauge_fill: StyleBoxFlat = null
## Where Tab goes before the ring and after the switch: the detailed view's own
## controls ([method link_tab]).
var _before: Control = null
var _after: Control = null


func _init() -> void:
	name = "CellFigure"
	custom_minimum_size = Vector2(WIDTH, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override(&"separation", SEPARATION)
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_color_override(&"font_color", Figure.CAPTION_TINT)
	_caption.add_theme_font_size_override(&"font_size", Figure.CAPTION_SIZE)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The caption is said in words built here, never a message of its own.
	_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_caption)
	_tray = HFlowContainer.new()
	_tray.name = "Waiting"
	_tray.custom_minimum_size = Vector2(0.0, TRAY_HEIGHT)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_theme_constant_override(&"h_separation", TRAY_GAP)
	_tray.add_theme_constant_override(&"v_separation", TRAY_GAP)
	_tray.alignment = FlowContainer.ALIGNMENT_CENTER
	add_child(_tray)
	_box = Control.new()
	_box.name = "Figure"
	_box.custom_minimum_size = Figure.FIGURE_SIZE
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_box)
	for layer: String in ["Body", "Slots"]:
		var each := Control.new()
		each.name = layer
		each.set_anchors_preset(Control.PRESET_FULL_RECT)
		each.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(each)
	_body = _box.get_node(^"Body")
	_slots = _box.get_node(^"Slots")
	_body.draw.connect(_draw_body)
	_build_lines()


## The three rows under the figure and the switch, as normal_mode.tscn lays them
## out: the explanation, the numbers, and the odds with a level and its gauge --
## and the verb line's room kept empty, so the figure stands where it stands on
## pause.
func _build_lines() -> void:
	_lines = Control.new()
	_lines.name = "Lines"
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)
	_stack = VBoxContainer.new()
	_stack.name = "Stack"
	_stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override(&"separation", LINES_GAP)
	_lines.add_child(_stack)
	var explain := HBoxContainer.new()
	explain.name = "Explain"
	explain.custom_minimum_size = Vector2(0.0, EXPLAIN_HEIGHT)
	explain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	explain.add_theme_constant_override(&"separation", 4)
	explain.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack.add_child(explain)
	_organ = Control.new()
	_organ.name = "Organ"
	_organ.custom_minimum_size = Figure.EXPLAIN_ORGAN_SIZE
	_organ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_organ.draw.connect(_draw_organ)
	explain.add_child(_organ)
	_gene = _label("Gene", 15, Figure.EXPLAIN_TINT)
	explain.add_child(_gene)
	_says = _label("Says", 15, Figure.EXPLAIN_TINT)
	explain.add_child(_says)
	_numbers = Control.new()
	_numbers.name = "Numbers"
	_numbers.custom_minimum_size = Vector2(0.0, Figure.NUMBERS_HEIGHT)
	_numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_numbers.draw.connect(_draw_numbers)
	_numbers.hide()
	_stack.add_child(_numbers)
	_hint_row = HBoxContainer.new()
	_hint_row.name = "Hint"
	_hint_row.custom_minimum_size = Vector2(0.0, HINT_HEIGHT)
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_row.add_theme_constant_override(&"separation", HINT_GAP)
	_hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack.add_child(_hint_row)
	_hint_level = _label("Level", 14, Figure.LABEL_TINT)
	_hint_level.hide()
	_hint_row.add_child(_hint_level)
	_hint_gauge = Control.new()
	_hint_gauge.name = "Gauge"
	_hint_gauge.custom_minimum_size = Figure.GAUGE_SIZE
	_hint_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_gauge.draw.connect(_draw_gauge)
	_hint_gauge.hide()
	_hint_row.add_child(_hint_gauge)
	_hint = _label("Text", 14, Color(0.855, 0.953, 0.933, 0.38))
	_hint.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_row.add_child(_hint)
	var act := _label("Act", 14, Color(0.0, 0.0, 0.0, 0.0))
	act.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_stack.add_child(act)
	_lines.custom_minimum_size = Vector2(0.0, EXPLAIN_HEIGHT + HINT_HEIGHT + ROW_HEIGHT
		+ 2.0 * LINES_GAP)
	_toggle = Control.new()
	_toggle.name = "NumbersToggle"
	_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle.offset_left = TOGGLE_RECT.position.x
	_toggle.offset_top = TOGGLE_RECT.position.y
	_toggle.offset_right = TOGGLE_RECT.end.x
	_toggle.offset_bottom = TOGGLE_RECT.end.y
	_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle.focus_mode = Control.FOCUS_ALL
	_toggle.draw.connect(_draw_toggle)
	_toggle.gui_input.connect(_on_toggle_input)
	_toggle.mouse_entered.connect(_set_toggle_hot.bind(true))
	_toggle.mouse_exited.connect(_set_toggle_hot.bind(false))
	_toggle.focus_entered.connect(_toggle.queue_redraw)
	_toggle.focus_exited.connect(_toggle.queue_redraw)
	_lines.add_child(_toggle)
	_toggle_boxes = Figure.toggle_boxes()
	_gauge_track = Figure.flat(Figure.GAUGE_TRACK, Figure.GAUGE_RADIUS)
	_gauge_fill = Figure.flat(Figure.GAUGE_TRACK, Figure.GAUGE_RADIUS)


func _label(called: String, size: int, ink: Color) -> Label:
	var label := Label.new()
	label.name = called
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", ink)
	# Every word here is said in code, in the language of the moment.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return label


func _notification(what: int) -> void:
	# Deferred, as every screen's words are (settings.md §3.3): the chips are
	# made again, and nothing may be added from inside the notification.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and not _genes.is_empty():
		_rebuild.call_deferred()


# ---------------------------------------------------------------------------
# The cell.
# ---------------------------------------------------------------------------

## **Shows [param cell]** -- a cell as a slot keeps it -- read from the top: the
## slot being read is the first fork waiting to be chosen, or the first gene the
## DNA carries, as the pause screen opens on (normal_mode.gd's `_select_default`).
## [param record] draws it at [constant RECORD_ALPHA]: a cell that died.
func show_cell(cell: Dictionary, record: bool) -> void:
	var genome: Dictionary = cell.get("genome", {})
	_dna = GenomeNode.tiers_from_names(genome.get("dna", {}))
	_tiers = GenomeNode.tiers_from_names(genome.get("body", {}))
	# Both layouts on the body plan in use, each gene in its slot by id
	# (gene-catalogue.md §10.3), as the cell would load.
	_worn.assign(GenomeNode.layout_from(genome.get("worn", PackedStringArray()),
		genome.get("plan")))
	var layout := GenomeNode.layout_from(genome.get("order", PackedStringArray()),
		genome.get("plan"))
	_levels = {}
	var kept: Dictionary = genome.get("levels", {})
	for gene: StringName in Catalogue.levelled():
		if not _dna.has(gene) and not _tiers.has(gene):
			continue
		var grown: Progression = GenomeNode.progression_for(gene)
		if kept.has(String(gene)):
			grown.set_state(kept[String(gene)] as Array)
		_levels[gene] = grown
	_waiting = []
	for one: Array in genome.get("waiting", []):
		_waiting.append([StringName(one[0]), clampi(int(one[1]), 1, GenomeNode.TIER_MAX),
			float(one[2])])
	var body: Dictionary = cell.get("body", {})
	_radius = float(body.get("radius", CellBody.BASE_RADIUS))
	_generation = int(cell.get("generation", 1))
	_slack = Metabolism.hungry_at(float(cell.get("hunger", 0.0)))
	var loads: PackedFloat64Array = cell.get("loads", PackedFloat64Array())
	_felt = FoodField.felt_of(loads, _radius)
	# **The chips are the DNA**: its outside layout padded to its seven, and the
	# inside after it (dna-slots-ux.md §3.1).
	_genes.clear()
	_genes.assign(layout)
	while _genes.size() < GenomeNode.INSIDE:
		_genes.append(&"")
	while _genes.size() > GenomeNode.INSIDE:
		_genes.pop_back()
	_genes.append_array(GenomeNode.inside_of(_dna))
	var slots := clampi(CellBody.slots_for(_radius) + int(genome.get("bonus", 0)),
		CellBody.SLOT_MIN, CellBody.SLOT_MAX)
	_live = mini(maxi(slots, layout.size()), GenomeNode.INSIDE)
	_forks.clear()
	for gene: StringName in _levels:
		if (_levels[gene] as Progression).can_choose():
			_forks.append(gene)
	var ink := Color(1.0, 1.0, 1.0, RECORD_ALPHA if record else 1.0)
	for part: Control in [_caption, _tray, _box, _stack]:
		part.modulate = ink
	_show_numbers = RunState.load_numbers()
	_hovered = SLOT_NONE
	_selected = _first_read()
	_rebuild()


## **What is read when the view opens**: the first slot whose fork is open, else
## the first gene the DNA carries -- never nothing, so the lines have already
## shown what reading does.
func _first_read() -> int:
	for slot in GenomeNode.INSIDE:
		if _genes[slot] != &"" and _forks.has(_genes[slot]):
			return slot
	for slot in _genes.size():
		if _genes[slot] != &"":
			return slot
	return SLOT_NONE


## **The chips and the tray, made again**: on [method show_cell], and on a change
## of language, which the chips draw their words in.
func _rebuild() -> void:
	var keeping := _focused_slot()
	for layer: Control in [_slots, _tray]:
		for child in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_chips.clear()
	_chips.resize(Figure.SLOT_SEAT.size())
	for slot in Figure.SLOT_SEAT.size():
		var chip := _make_chip(slot)
		_slots.add_child(chip)
		_chips[slot] = chip
	if not _waiting.is_empty() or not _forks.is_empty():
		_tray.add_child(Figure.make_tray_caption())
	for one: Array in _waiting:
		_tray.add_child(_make_waiting(one[0], int(one[1]), float(one[2])))
	for gene: StringName in _forks:
		_tray.add_child(_make_fork(gene))
	_wire_focus()
	_body.queue_redraw()
	_toggle.queue_redraw()
	_say()
	if keeping != SLOT_NONE and _live_at(keeping):
		_chips[keeping].grab_focus()


## **Every word, said again**: the caption, the explanation, the numbers and the
## odds, for the slot being read.
func _say() -> void:
	_caption.text = Figure.caption(_generation, _show_numbers, _radius, _tiers,
		GenomeNode.upkeep_with_levels(_tiers, _levels))
	_numbers.visible = _show_numbers
	_update_explain()
	_update_hint()


## One chip, seated at its arc: live -- earned, inherited or the inside -- and
## readable, or faint and out of reach.
func _make_chip(slot: int) -> Control:
	var node := Control.new()
	node.name = "Slot%d" % slot
	node.custom_minimum_size = Figure.SLOT_SIZE
	node.size = Figure.SLOT_SIZE
	node.position = Figure.chip_at(slot)
	node.set_meta(&"slot", slot)
	if not _live_at(slot):
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
		node.draw.connect(Figure.draw_unearned.bind(node))
		return node
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.focus_mode = Control.FOCUS_ALL
	node.draw.connect(_draw_chip.bind(node, slot))
	node.gui_input.connect(_on_chip_input.bind(slot))
	# **Focus reads**: a key that lands on a chip, and a click or a tap, which
	# focus it. Hover reads without selecting, as on pause.
	node.focus_entered.connect(_select.bind(slot))
	node.focus_exited.connect(node.queue_redraw)
	node.mouse_entered.connect(_on_hover.bind(slot))
	node.mouse_exited.connect(_on_unhover.bind(slot))
	return node


## One waiting gene, as the tray draws it with nothing in hand: never pressed,
## its clock where the save stopped it.
func _make_waiting(gene: StringName, copies: int, left: float) -> Control:
	var node := Control.new()
	node.name = "Waiting_%s" % gene
	node.custom_minimum_size = Vector2(Figure.waiting_width(_tray.get_theme_default_font(), gene),
		Figure.WAIT_SIZE.y)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	node.draw.connect(Figure.draw_waiting.bind(node, gene, copies, left, false))
	return node


## One fork waiting to be chosen, its chip as the tray draws it shut.
func _make_fork(gene: StringName) -> Control:
	var node := Control.new()
	node.name = "Fork_%s" % gene
	var level := (_levels[gene] as Progression).level()
	node.custom_minimum_size = Vector2(Figure.fork_chip_width(_tray.get_theme_default_font(),
		gene, level), Figure.WAIT_SIZE.y)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	node.draw.connect(Figure.draw_fork_chip.bind(node, gene, level, false, false))
	return node


## True for a slot the body has: earned or inherited, and the inside, which every
## cell has from birth.
func _live_at(slot: int) -> bool:
	return slot >= 0 and slot < Figure.SLOT_SEAT.size() \
		and (slot < _live or GenomeNode.is_inside(slot))


## The gene [param slot] carries, or &"".
func _gene_at(slot: int) -> StringName:
	return _genes[slot] if slot >= 0 and slot < _genes.size() else &""


## The slot being read: hovered first, then selected.
func _reading() -> int:
	return _hovered if _hovered != SLOT_NONE else _selected


func _focused_slot() -> int:
	for chip: Control in _chips:
		if chip != null and chip.has_focus():
			return int(chip.get_meta(&"slot", SLOT_NONE))
	return SLOT_NONE


# ---------------------------------------------------------------------------
# Reading.
# ---------------------------------------------------------------------------

func _select(slot: int) -> void:
	_selected = slot
	_redraw()
	_update_explain()
	_update_hint()


func _on_hover(slot: int) -> void:
	_hovered = slot
	_body.queue_redraw()
	_update_explain()
	_update_hint()


func _on_unhover(slot: int) -> void:
	if _hovered != slot:
		return
	_hovered = SLOT_NONE
	_body.queue_redraw()
	_update_explain()
	_update_hint()


## **A press reads the slot it lands on**, the keyboard's Enter included -- and
## nothing else: no arm, no drag, no place.
func _on_chip_input(event: InputEvent, slot: int) -> void:
	var pressed := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or event.is_action_pressed(&"ui_accept")
	if not pressed:
		return
	_chips[slot].accept_event()
	if _selected != slot:
		_select(slot)


func _redraw() -> void:
	_body.queue_redraw()
	for chip: Control in _chips:
		if chip != null:
			chip.queue_redraw()


## **The explanation line** (normal_mode.gd's `_update_explain`, read-only): the
## gene being read -- its one name for both forms, in its hue -- and what it
## does where it is; for an empty slot, what that side of the body is for.
func _update_explain() -> void:
	var slot := _reading()
	var gene := _gene_at(slot)
	_explain_gene = gene
	_explain_at = slot if gene != &"" else -1
	_explain_tier = int(_dna.get(gene, 0)) if gene != &"" else 0
	_update_numbers()
	_organ.queue_redraw()
	if gene == &"":
		_gene.text = ""
		_says.text = "" if slot == SLOT_NONE else Figure.explain_empty(slot)
		return
	_gene.text = GenomeNode.name_of(gene)
	_gene.add_theme_color_override(&"font_color", Color(Cilia.hue(gene), Figure.EXPLAIN_NAME_ALPHA))
	var says := Figure.explains(gene, slot, _path_of(gene))
	_says.text = "" if says.is_empty() else "· " + says


## **The row under it** (normal_mode.gd's `_update_hint` and `_set_hint`): what
## the slot is worth to a daughter, its odds -- with a level and its gauge in
## front for a gene that levels.
func _update_hint() -> void:
	var slot := _reading()
	var gene := _gene_at(slot)
	var text := ""
	if slot != SLOT_NONE and gene == &"":
		text = Figure.hint_empty(slot)
	elif gene != &"" and Catalogue.has_tag(gene, Catalogue.ALWAYS_EXPRESSED):
		text = tr(Figure.HINT_CERTAIN)
	elif gene != &"":
		text = Figure.odds(int(_dna.get(gene, 0)), _show_numbers)
	var grown: Progression = _levels.get(gene, null) as Progression if gene != &"" else null
	var levelled := grown != null
	_hint_level.visible = levelled
	_hint_gauge.visible = levelled
	_hint.size_flags_horizontal = Control.SIZE_FILL if levelled else Control.SIZE_EXPAND_FILL
	_gauge_gene = gene if levelled else &""
	if not levelled:
		_hint.text = text
		return
	_hint_level.text = Figure.level_text(grown.level())
	_hint_gauge.queue_redraw()
	_hint.text = "· " + text if text != "" else ""


## **Its numbers** (normal_mode.gd's `_update_numbers`): the copies this body
## wears -- or would be worn with, dimmer -- at the level it works at, and the
## next level at the end of the costs for a worn gene that earns.
func _update_numbers() -> void:
	_numbers_lines = [[], []]
	_numbers_dim = false
	var gene := _explain_gene
	if _show_numbers and gene != &"":
		var worn := int(_tiers.get(gene, 0))
		var copies := worn if worn > 0 else _explain_tier
		_numbers_dim = worn <= 0
		var level := 0
		var path: StringName = &""
		var grown: Progression = _levels.get(gene, null) as Progression
		if grown != null:
			level = grown.effective_level()
			path = grown.path
		elif Catalogue.has_levels(gene):
			level = 1
		_numbers_lines = Figure.numbers_lines(gene, copies, level, path, _tiers, _radius,
			_explain_at, grown if grown != null and worn > 0 else null)
	_numbers.queue_redraw()


func _path_of(gene: StringName) -> StringName:
	var grown: Progression = _levels.get(gene, null) as Progression
	return grown.path if grown != null else &""


# ---------------------------------------------------------------------------
# Drawing: figure.gd's, handed this cell's values.
# ---------------------------------------------------------------------------

func _draw_body() -> void:
	if _genes.is_empty():
		return
	Figure.draw_body(_body, _tiers, _worn, _genes, _live, _slack, _felt)
	var slot := _reading()
	if _live_at(slot):
		Figure.draw_mark(_body, slot, _gene_at(slot))


func _draw_chip(node: Control, slot: int) -> void:
	var gene := _gene_at(slot)
	var copies := int(_dna.get(gene, 0))
	var worn := mini(int(_tiers.get(gene, 0)), copies)
	var grown: Progression = _levels.get(gene, null) as Progression if gene != &"" else null
	Figure.draw_chip(node, slot, gene, copies, worn,
		Cilia.hue(gene) if gene != &"" else Figure.PALE,
		grown.level() if grown != null else 0,
		grown != null and grown.can_choose(), _selected == slot)


func _draw_organ() -> void:
	if _explain_gene == &"":
		return
	Figure.draw_explain_organ(_organ, _explain_gene, _explain_tier,
		int(_tiers.get(_explain_gene, 0)) > 0)


func _draw_numbers() -> void:
	Figure.draw_numbers(_numbers, _numbers_lines, _numbers_dim)


func _draw_gauge() -> void:
	var grown: Progression = _levels.get(_gauge_gene, null) as Progression \
		if _gauge_gene != &"" else null
	if grown != null:
		Figure.draw_gauge(_hint_gauge, _gauge_gene, grown.progress(), _gauge_track, _gauge_fill)


func _draw_toggle() -> void:
	Figure.draw_toggle(_toggle, _show_numbers, _numbers_hot, _toggle_boxes)


# ---------------------------------------------------------------------------
# The switch.
# ---------------------------------------------------------------------------

## **The switch answers on the lift, inside it, and a key on the press** -- the
## pause screen's rule: a touch arrives twice.
func _on_toggle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		_toggle.accept_event()
		_flip_numbers()
		return
	var lift := false
	var at := Vector2.ZERO
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT:
		_toggle.accept_event()
		lift = not (event as InputEventMouseButton).pressed
		at = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch:
		_toggle.accept_event()
		lift = not (event as InputEventScreenTouch).pressed
		at = (event as InputEventScreenTouch).position
	if lift and not event.is_canceled() and Rect2(Vector2.ZERO, _toggle.size).has_point(at):
		_flip_numbers()


## **One flip, from either door, once a frame**, kept as the pause screen keeps it.
func _flip_numbers() -> void:
	var frame := Engine.get_process_frames()
	if frame == _numbers_frame:
		return
	_numbers_frame = frame
	_show_numbers = not _show_numbers
	RunState.save_numbers(_show_numbers)
	_toggle.queue_redraw()
	_say()


func _set_toggle_hot(on: bool) -> void:
	_numbers_hot = on
	_toggle.queue_redraw()


# ---------------------------------------------------------------------------
# The keyboard.
# ---------------------------------------------------------------------------

## **Where Tab goes round**: from [param before] onto the ring at its nose, round
## it clockwise, on to the switch, and from the switch to [param after]. The
## detailed view links its own controls to these ends.
func link_tab(before: Control, after: Control) -> void:
	_before = before
	_after = after
	_wire_focus()


## The first chip Tab lands on: the nose's, or the first live one round the ring.
func first_chip() -> Control:
	for slot: int in Figure.SLOT_RING:
		if _live_at(slot) and slot < _chips.size() and _chips[slot] != null:
			return _chips[slot]
	return _toggle


## The switch, the last stop before Tab leaves the figure.
func toggle() -> Control:
	return _toggle


## **The ring's keyboard, as on pause**: an arrow goes where it points and never
## off the ring -- a direction with no live slot keeps the focus where it is -- and
## Tab goes round from the nose, then on to the switch, whose arrows go nowhere.
func _wire_focus() -> void:
	if _chips.is_empty():
		return
	var live: Array[Control] = []
	for slot: int in Figure.SLOT_RING:
		if _live_at(slot) and _chips[slot] != null:
			live.append(_chips[slot])
	for i in live.size():
		var chip := live[i]
		var slot := int(chip.get_meta(&"slot"))
		for way in Figure.NEIGHBOUR_SIDES.size():
			var to := int(Figure.SLOT_NEIGHBOUR[slot][way])
			var neighbour: Control = _chips[to] if _live_at(to) else chip
			chip.set_focus_neighbor(Figure.NEIGHBOUR_SIDES[way], chip.get_path_to(neighbour))
		chip.focus_next = chip.get_path_to(live[i + 1] if i + 1 < live.size() else _toggle)
		if i > 0:
			chip.focus_previous = chip.get_path_to(live[i - 1])
		elif _before != null and is_instance_valid(_before):
			chip.focus_previous = chip.get_path_to(_before)
	for side in Figure.NEIGHBOUR_SIDES:
		_toggle.set_focus_neighbor(side, _toggle.get_path_to(_toggle))
	if not live.is_empty():
		_toggle.focus_previous = _toggle.get_path_to(live[live.size() - 1])
	if _after != null and is_instance_valid(_after):
		_toggle.focus_next = _toggle.get_path_to(_after)
