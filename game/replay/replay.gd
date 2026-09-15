extends Node
## **Watching the run back, from both sides.**
##
## The owner's sentence: *record a run, then when you die let me watch a 2-sided
## replay, one normal view and the other with full vision, so I can see what I
## did given my sensors.* The value is precisely the gap between the two panes
## -- what you perceived against what was actually there -- which is the
## principle the project has held since Phase 3, full vision exists to catch the
## membrane lying, turned round and aimed at the player's own mistakes.
##
## This file is the small half of the feature. `panes.gd` is the screen;
## `recorder.gd` is the sixty seconds; this reads one out into the other, and
## hangs two buttons underneath.
##
## **The transport is minimal on purpose.** Play/pause with a loop, one speed
## toggle through 1x, 1/2x and 1/4x, and `leave`. No scrub bar, no jump buttons,
## no frame step: the panes are the feature and a video editor grafted onto them
## is the part of the ask that is disproportionate. A button tapped sixty times
## to cross a second is not a control; 1/4x with a pause does the same job in
## one tap. docs/design/replay.md §5 and owner's call 5 in §7.
##
## Nothing here is freed on a death and nothing here is written to disk. Closing
## it is `queue_free()`; the ring dies with the run that made it.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Panes := preload("res://game/replay/panes.gd")
const RecorderNode := preload("res://game/replay/recorder.gd")
const CellBody := preload("res://game/normal/cell.gd")
const MotesField := preload("res://game/normal/motes.gd")
const FoodField := preload("res://game/normal/food.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
## **For three numbers**, and they have to be these three: the daughters'
## brightnesses are what the recorder wrote a single `commit` float out of, and
## a second table of them here would be a division that looks different in the
## replay from the one the player just watched. Safe to preload because
## `normal_mode.gd` reaches this file by path and loads it on the press.
const Run := preload("res://game/normal/normal_mode.gd")

## Where the transport sits, which is the band the panes gave up. Never over
## them: the membrane's band is 104px deep from every edge, and a bar floating
## over the bottom would sit exactly on the astern channel -- which is where
## *it ate me from behind* is written. §4.4.
const BUTTON_HEIGHT := 48.0
const PLAY_WIDTH := 112.0
const SPEED_WIDTH := 96.0
const LEAVE_WIDTH := 96.0
## **Not 12, and the number comes from the pause screen's own note.** That file
## measured its 56px buttons at about 5.3mm on a 2400x1080 phone and put *48*
## canvas px of dead water between the safe control and the destructive one --
## "do not tighten it back up for looks". Twelve canvas px is 18 device px on
## that phone, about 1.1mm: a thumb going for the speed toggle lands on `leave`.
## `leave` here is reversible -- closing the screen puts the `watch` offer back,
## so a mis-tap costs one tap and not the replay -- which is why this is 32 and
## not the pause screen's 48. Thirty-two is 2.9mm, and the row still clears both
## captions at 1280x720 and at 2400x1080.
const BUTTON_GAP := 32.0
## How far up the band the row of controls starts, under the captions.
const ROW_TOP := 32.0

## 1x, then half, then a quarter. Three, because slower than a quarter is a
## still and there is a pause button for that.
const SPEEDS: Array[float] = [1.0, 0.5, 0.25]
const SPEED_TEXT: Array[String] = ["1x", "1/2x", "1/4x"]

## Set by the run before this scene enters the tree.
var recorder: RecorderNode = null

var _panes: Panes = null
var _cell: CellBody = null
var _motes: MotesField = null
var _food: FoodField = null
var _genome: GenomeNode = null
## The run's bus, found only so the panes can read the player's light setting
## off it. Nothing here writes to it -- the run's membrane is detached while
## this screen is up and the panes have a bus of their own.
var _bus: SignalBus = null

var _ui: CanvasLayer = null
var _blocker: Control = null
var _play_button: Button = null
var _speed_button: Button = null
var _leave_button: Button = null

var _frame := PackedFloat32Array()
## Seconds into the window, and the recorded frame the cursor is sitting on.
var _at := 0.0
var _index := 0
var _speed := 0
var _playing := true
## How far each event stream has been replayed, so an event fires once per pass.
var _sensation_at := 0
var _mark_at := 0
var _delta_at := 0
var _daughters: Array = []
var _view := Vector2(1280.0, 720.0)


func _ready() -> void:
	_frame.resize(RecorderNode.STRIDE)
	_find(get_parent())
	_panes = Panes.new()
	_panes.name = "Panes"
	_panes.watch(_cell, _motes, _food, _genome, _bus)
	add_child(_panes)
	_build_transport()
	_rewind()
	# Ahead of the panes' own layers, which is what makes the first frame the
	# recording's rather than the dead run's.
	process_priority = -10


func _process(delta: float) -> void:
	if recorder == null or recorder.frames() < 2:
		return
	if _playing:
		_at += delta * SPEEDS[_speed]
		var span := recorder.span()
		if _at >= span:
			# **Looping, not stopping.** The mistake is usually three seconds
			# long and nobody finds it the first time through.
			_at = 0.0
			_rewind()
	_seek()


# ---------------------------------------------------------------------------
# Playback. The recorded per-frame delta paces this, so a stretch the phone
# rendered at 30 fps replays at the speed it happened.
# ---------------------------------------------------------------------------

func _seek() -> void:
	while _index + 1 < recorder.frames() and recorder.time_of(_index + 1) <= _at:
		_index += 1
	var here := recorder.time_of(_index)
	var next := recorder.time_of(mini(_index + 1, recorder.frames() - 1))
	var u := 0.0 if next <= here else (_at - here) / (next - here)
	recorder.sample(_index, u, _frame)
	_apply_deltas()
	_write_state()
	_fire_events()


## The recorded state, written straight onto the run's own frozen nodes. They
## are not simulating and never will again: *a run keeps nothing*, and
## `_wake_up()` builds every one of them afresh.
func _write_state() -> void:
	if _cell != null:
		_cell.position = Vector2(_frame[0], _frame[1])
		_cell.heading = _frame[2]
		_cell.velocity = Vector2(_frame[3], _frame[4])
		_cell.radius = _frame[5]
		_cell.wound = _frame[6]
		_cell.steer = _frame[7]
	if _food != null:
		for i in RecorderNode.BODIES:
			var at := RecorderNode.AT_BODIES + i * RecorderNode.BODY_FLOATS
			_food.restore_body(i, Vector2(_frame[at], _frame[at + 1]),
				_frame[at + 2], _frame[at + 3], _frame[at + 4])
		_food.beams = _read_beams()
		_food.ping_front = _frame[RecorderNode.AT_PING_FRONT]
		_food.ping_range = _frame[RecorderNode.AT_PING_RANGE]
		# **Before the world pane draws**, which is what `process_priority`
		# -10 buys: `vision.gd` asks the field who is hunting and draws the
		# three predator rings round the answer. Rounded rather than cast --
		# the float is an index and the lerp is stepped, but -1.0 arriving as
		# -0.9999 would truncate to 0 and put rings on an innocent drifter.
		_food.restore_hunter(int(roundf(_frame[RecorderNode.AT_HUNTER])))
	if _motes != null:
		for i in RecorderNode.MOTES:
			var at := RecorderNode.AT_MOTES + i * 2
			_motes.restore_point(i, Vector2(_frame[at], _frame[at + 1]))
	if _genome != null:
		_genome.held_remaining = _frame[RecorderNode.AT_HELD]
	_panes.set_division(_read_division())
	_panes.push_block(_frame, RecorderNode.AT_MEMBRANE)


func _read_beams() -> Array:
	var out: Array = []
	for slot in RecorderNode.BEAMS:
		var at := RecorderNode.AT_BEAMS + slot * RecorderNode.BEAM_FLOATS
		if _frame[at + 1] <= 0.0 and _frame[at + 2] <= 0.0:
			continue
		out.append([_frame[at], _frame[at + 1], _frame[at + 2] > 0.5])
	return out


## The four recorded floats turned back into the dictionary the two views read.
## `commit` is unpacked here and nowhere else -- see [method
## RecorderNode._capture_division] for what is in it.
func _read_division() -> Dictionary:
	var double := _frame[RecorderNode.AT_DOUBLE]
	var pinch := _frame[RecorderNode.AT_PINCH]
	if double <= 0.0 and pinch <= 0.0 and _daughters.is_empty():
		return {}
	var out := {"double": double, "pinch": pinch}
	if _daughters.size() != 2:
		return out
	var commit := _frame[RecorderNode.AT_COMMIT]
	out["spread"] = _frame[RecorderNode.AT_SPREAD]
	out["radius"] = CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)
	var fades := [Run.DIVIDE_FADE_IDLE, Run.DIVIDE_FADE_IDLE]
	var sheds := [0.0, 0.0]
	if absf(commit) >= 2.0:
		var going := 0 if commit > 0.0 else 1
		sheds[going] = absf(commit) - 2.0
		fades[going] = Run.DIVIDE_FADE_DIM * (1.0 - sheds[going])
		fades[1 - going] = Run.DIVIDE_FADE
	elif absf(commit) > 0.0:
		var t := clampf(absf(commit)
			/ maxf(Run.DIVIDE_FADE - Run.DIVIDE_FADE_DIM, 0.001), 0.0, 1.0)
		var leaned := 0 if commit > 0.0 else 1
		fades[leaned] = lerpf(Run.DIVIDE_FADE_IDLE, Run.DIVIDE_FADE, t)
		fades[1 - leaned] = lerpf(Run.DIVIDE_FADE_IDLE, Run.DIVIDE_FADE_DIM, t)
	var pair: Array = []
	for side in 2:
		var one: Dictionary = _daughters[side]
		pair.append({
			"tiers": one["tiers"],
			"order": one["order"],
			"fade": fades[side],
			"shed": sheds[side],
		})
	out["bodies"] = pair
	return out


## Genomes, layouts, held samples and the two daughters: stepped at the
## timestamps the recorder wrote them, never interpolated.
func _apply_deltas() -> void:
	var rows: Array = recorder.deltas()
	while _delta_at < rows.size() and float(rows[_delta_at][0]) <= _window(_at):
		var row: Array = rows[_delta_at]
		_delta_at += 1
		match int(row[1]):
			RecorderNode.Delta.PLAYER:
				var state: Dictionary = row[3]
				if _genome != null:
					_genome.express(state["dna"], state["order"], state["body"])
					_genome.bonus_slots = int(state["bonus"])
					_genome.held_sample = state["sample"]
			RecorderNode.Delta.BODY:
				if _food != null:
					_food.restore_genome(int(row[2]), row[3])
			RecorderNode.Delta.DAUGHTERS:
				_daughters = row[3]
			_:
				pass


## Sensations back on the replay's own bus, and ground truth straight into the
## world pane's marks. Both are one pass per loop.
func _fire_events() -> void:
	var t := _window(_at)
	var sens: Array = recorder.sensations()
	while _sensation_at < sens.size() and float(sens[_sensation_at][0]) <= t:
		var row: Array = sens[_sensation_at]
		_sensation_at += 1
		_panes.feel(row[1], {"bearing": row[2], "strength": row[3]})
	var marks: Array = recorder.marks()
	while _mark_at < marks.size() and float(marks[_mark_at][0]) <= t:
		var row: Array = marks[_mark_at]
		_mark_at += 1
		if row[1] == &"struck":
			_panes.mark_struck(row[2])
		else:
			_panes.mark_meal(float(row[3]), row[4], row[2])


## Event timestamps are in the run's clock and the cursor runs from zero at the
## start of the window, so everything that reads one against the other goes
## through here.
func _window(at: float) -> float:
	return at + recorder.origin()


func _rewind() -> void:
	_index = 0
	_sensation_at = 0
	_mark_at = 0
	_delta_at = 0
	_daughters = []


# ---------------------------------------------------------------------------
# The transport. Three controls, all at least 48px, in the 96px band the panes
# gave up. The register is the pause screen's exactly: this is a panel the
# player consults, not a sensory screen.
# ---------------------------------------------------------------------------

func _build_transport() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "Transport"
	_ui.layer = Panes.LAYER_LEGEND + 1

	# **Nothing behind this screen is listening.** A tap anywhere on the black
	# still restarts the run, and the run is still in WAITING behind these
	# panes; a full-rect control that stops the pointer is what keeps a tap
	# meant for `pause` from being a tap meant for `another cell`.
	_blocker = Control.new()
	_blocker.name = "Blocker"
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_blocker)

	_play_button = _button("pause", PLAY_WIDTH)
	_play_button.pressed.connect(_toggle_play)
	_speed_button = _button(SPEED_TEXT[0], SPEED_WIDTH)
	_speed_button.pressed.connect(_cycle_speed)
	_leave_button = _button("leave", LEAVE_WIDTH)
	_leave_button.pressed.connect(_close)
	for control: Button in [_play_button, _speed_button, _leave_button]:
		_ui.add_child(control)
	add_child(_ui)

	_relayout()
	get_viewport().size_changed.connect(_relayout)


func _button(text: String, width: float) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_font_size_override("font_size", 17)
	control.add_theme_color_override("font_color",
		Color(0.855, 0.953, 0.933, 0.82))
	control.add_theme_color_override("font_hover_color",
		Color(0.855, 0.953, 0.933, 1.0))
	control.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	control.add_theme_stylebox_override("normal", _slab(0.0))
	control.add_theme_stylebox_override("hover", _slab(0.35))
	control.add_theme_stylebox_override("pressed", _slab(0.5))
	return control


## The pause screen's slab, and the same one: every group on a panel the player
## consults is a surface, with one edge and one radius.
func _slab(lift: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.063, 0.141, 0.125, 0.55 + lift * 0.5)
	box.border_color = Color(0.12, 0.70, 0.58, 0.35 + lift * 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


func _relayout() -> void:
	var rect := get_viewport().get_visible_rect()
	if rect.size.x > 1.0 and rect.size.y > 1.0:
		_view = rect.size
	var total := PLAY_WIDTH + SPEED_WIDTH + LEAVE_WIDTH + BUTTON_GAP * 2.0
	var x := (_view.x - total) * 0.5
	var y := _view.y - Panes.BAND + ROW_TOP
	for pair: Array in [[_play_button, PLAY_WIDTH], [_speed_button, SPEED_WIDTH],
			[_leave_button, LEAVE_WIDTH]]:
		var control: Button = pair[0]
		var width: float = pair[1]
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		control.position = Vector2(x, y)
		control.size = Vector2(width, BUTTON_HEIGHT)
		x += width + BUTTON_GAP


func _toggle_play() -> void:
	_playing = not _playing
	_play_button.text = "pause" if _playing else "play"


func _cycle_speed() -> void:
	_speed = (_speed + 1) % SPEEDS.size()
	_speed_button.text = SPEED_TEXT[_speed]


func _close() -> void:
	var run := get_parent()
	if run != null and run.has_method(&"_replay_closed"):
		run.call_deferred(&"_replay_closed")
	else:
		queue_free()


## **Modal.** Everything is consumed while this screen is up: behind it is a run
## in WAITING, where any tap at all starts the next cell.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_close()
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Finding the run's frozen nodes. By type, from the parent, exactly as
# vision.gd does -- nothing has to hand this screen anything.
# ---------------------------------------------------------------------------

func _find(root: Node) -> void:
	if root == null:
		return
	_walk(root)
	if recorder == null:
		for child in root.get_children():
			if child is RecorderNode:
				recorder = child as RecorderNode
				break
	# The marks layer reads the field's own clock to decide whether a beam is
	# still true. Here the field is stepped from a recording, so it is told.
	if _food != null and _food.is_processing():
		_food.set_process(false)


func _walk(node: Node) -> void:
	if _cell == null and node is CellBody:
		_cell = node as CellBody
	elif _motes == null and node is MotesField:
		_motes = node as MotesField
	elif _food == null and node is FoodField:
		_food = node as FoodField
	elif _genome == null and node is GenomeNode:
		_genome = node as GenomeNode
	elif _bus == null and node is SignalBus:
		_bus = node as SignalBus
	for child in node.get_children():
		_walk(child)
