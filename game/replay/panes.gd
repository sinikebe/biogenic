extends Node
## **The two panes**: what you felt on the left, what was actually there on the
## right, side by side, drawn by the two shipped views over one body.
##
## The value of a replay is precisely the gap between them -- the green band
## pointing one way and the food sitting the other -- so this file is the whole
## feature and the transport bolted underneath it is not. It is built and
## photographed on its own before anything records anything, because it is the
## only part of docs/design/replay.md that can fail for reasons a document
## cannot predict. §5, last bullet.
##
## **No SubViewport, and the reason is sharpness.** A SubViewportContainer sizes
## its viewport in canvas pixels, so at 2400x1080 each pane would render at
## 800x720 and be upscaled 1.5x -- the 9px contour becoming a soft 13.5px,
## against a shipped game that draws it crisply because `canvas_items` stretch
## scales the transform and not a render target. Sizing the SubViewport in
## device pixels instead fixes the sharpness and breaks the membrane, whose
## `band_px`, `line_px` and `inset_px` are canvas constants. Neither branch is
## acceptable, and neither is needed: the membrane already takes its rect from
## GDScript, so a 640-wide ColorRect draws a complete 640-wide membrane. §4.3.
##
## What this node does NOT do is decide what the panes show. It owns geometry
## and wiring; the state arrives through [method push_block] and the writers on
## the simulation nodes, from the replay driver or -- while this was being
## rendered -- straight off the live run.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const MembraneLayer := preload("res://game/perception/membrane.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
const VisionLayer := preload("res://game/vision/vision.gd")
const SomaLayer := preload("res://game/perception/soma.gd")
const ReturnsLayer := preload("res://game/perception/returns.gd")
const CellBody := preload("res://game/normal/cell.gd")
const MotesField := preload("res://game/normal/motes.gd")
const FoodField := preload("res://game/normal/food.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const RunState := preload("res://game/run_state.gd")

const MEMBRANE_SCENE := preload("res://game/perception/membrane.tscn")
const VISION_SCENE := preload("res://game/vision/vision.tscn")
const SOMA_SCENE := preload("res://game/perception/soma.tscn")
const RETURNS_SCENE := preload("res://game/perception/returns.tscn")

## **The panes are 624 tall, not 720, and the 96 the transport takes is taken
## off them rather than laid over them.** The membrane's band is 104px deep from
## every edge; a bar floating over the bottom would sit exactly on the astern
## channel, which is where *it ate me from behind* is written. §4.4.
##
## **Ninety-six and not the eighty-eight this was designed at, because of the
## gesture bar.** At 88 the transport row's bottom edge landed 8 canvas px from
## the bottom of the screen -- 12 device px on a 2400x1080 phone -- and in
## Android's sensor landscape that is where the system gesture handle lives.
## This is the first control in the game to sit on that edge; `membrane.gd`'s
## safe-area inset is about the contour and does not reach a Control. Eight more
## pixels of band lifts the whole assembly by eight and costs the panes eight
## rows of water, which is the cheap side of that trade. The captions keep the
## designer's spacing exactly: the gap between a caption's box and the row below
## it is 4 canvas px before and after, because both are measured off the band.
const BAND := 96.0

## Where the two layers of this screen sit. The run underneath is on canvas
## layers 0 and 1, and every pixel of it is covered.
const LAYER_BACK := 10
const LAYER_MEMBRANE := 11
const LAYER_RETURNS := 12
const LAYER_SOMA := 13
const LAYER_VISION := 14
const LAYER_LEGEND := 15

## The launcher's base colour, which is the membrane's own and the colour behind
## every screen in the game.
const BACK_COLOR := Color(0.023, 0.055, 0.05, 1.0)

## **The legend, and it is also the thesis.** The feature does not work if the
## player has to be told which pane is which, so the two captions say it in the
## player's own terms rather than in the project's.
const FELT_TEXT := "what you felt"
const TRUTH_TEXT := "what was there"
## **Louder than the transport, because the captions are the thesis and the
## transport is chrome.** Measured off a 2400x1080 render: at 15px and 0.45
## alpha the glyphs came out at 5.05:1 against the band, while `pause` at 17px
## and 0.82 on a lit slab came out at 7.71:1. Both clear AA -- the readability
## was never the problem -- but the hierarchy was upside down: the video-player
## buttons were the loudest thing on the screen and the one sentence the feature
## exists to say was the quietest. 16px at 0.60 measures 6.39:1, which puts the
## legend above the chrome and still under everything inside a pane.
const CAPTION_SIZE := 16
const CAPTION_COLOR := Color(0.855, 0.953, 0.933, 0.60)
const CAPTION_TOP := 6.0
const CAPTION_HEIGHT := 22.0

## **The panes need an edge that does not depend on being felt.**
##
## The membrane's contour is the frame when there is something to feel, and on
## a quiet frame it is not a frame at all: measured across the middle of a
## resting replay, the contour peaks at G=14 against a G=13 background -- one
## level out of 255, which is nothing. On the shipped one-pane screen that
## costs exactly nothing, because the edge of the pane is the edge of the
## screen and the player already knows where that is.
##
## Here it costs the whole reading. The world pane is clipped at the seam, so
## on a quiet frame a body sliced vertically in half at x=640 with no line
## beside it reads as a fault in the picture rather than as the edge of a
## window -- and the two panes read as one wide field with two cells adrift in
## it. The gap between what you felt and what was there cannot be read off a
## picture whose two halves have no boundary. Rendered, at both shapes, and
## that is how it was found.
##
## Quiet on purpose: at 0.20 over the base the rule lands near G=47, well under
## the contour's own peak of 112, so the membrane still wins every frame it has
## anything to say. It is a sill, not a chrome divider.
const SEAM_WIDTH := 2.0
const SEAM_COLOR := Color(0.12, 0.70, 0.58, 0.20)
## The same line under both panes, fainter. It closes the bottom of each window
## -- the other edge the world layer is clipped against -- and it is what makes
## the transport band read as a surface the player consults rather than as more
## water. §4.4's register, drawn rather than asserted.
const SILL_HEIGHT := 1.0
const SILL_COLOR := Color(0.12, 0.70, 0.58, 0.13)

## True while this screen is mirroring a run that is still being played, which
## is how it was first rendered and how the harness photographs it. The replay
## drives it the other way: nothing is stepping, and every frame is written.
var live := false

var _cell: CellBody = null
var _motes: MotesField = null
var _food: FoodField = null
var _genome: GenomeNode = null
## The run's bus. Never written to: [member live] copies its block across, and
## every path reads [member SignalBus.gain] off it. See [method _apply_gain].
var _run_bus: SignalBus = null
var _run_soma: SomaLayer = null

var _membrane: MembraneLayer = null
var _bus: SignalBus = null
var _truth: ColorRect = null
var _vision: VisionLayer = null
var _soma: SomaLayer = null
var _returns: ReturnsLayer = null
var _felt_caption: Label = null
var _truth_caption: Label = null
var _seam: ColorRect = null
var _sill: ColorRect = null

var _view := Vector2(1280.0, 720.0)
var _block := PackedFloat32Array()


func _ready() -> void:
	_block.resize(SignalBus.BLOCK_FLOATS)
	# Nothing here touches a window, an input device or a network. The search is
	# harmless when [method watch] has already said what to look at -- it finds
	# the same nodes -- and it is the whole of the wiring when it has not.
	_find(get_parent())
	_build()
	_apply_gain()
	_relayout()
	get_viewport().size_changed.connect(_relayout)


## **What these panes are panes of.** Called before [method Node.add_child], the
## same way [method VisionLayer.bind] is and for the same reason: the views
## inside search the tree when nobody tells them, and the tree has a run in it.
##
## [param bus] is the run's own, and it is handed over for one number: see
## [method _apply_gain]. Optional because the harness raises these panes over a
## live run without calling this at all, and finds it by walking instead.
func watch(cell: CellBody, motes: MotesField, food: FoodField,
		genome: GenomeNode, bus: SignalBus = null) -> void:
	_cell = cell
	_motes = motes
	_food = food
	_genome = genome
	_run_bus = bus


## **The light setting is the player's, and this screen has to ask for it.**
##
## `signal_bus.gd` keeps `gain` out of the recorded block on purpose, and the
## reason written there is right: it is a setting the player owns *now*, not a
## fact about the run that ended. But out of the block means it has to arrive
## by some other route, and these panes build a bus of their own. Left alone it
## sits at `GAIN_DEFAULT`, which is also `GAIN_MIN`; [method
## SignalBus.write_block] ends in an apply, so every replay frame would stamp
## 1.0 onto the pane material and read nothing.
##
## That is an accessibility bug on a phone rather than a nicety. `normal_mode`
## writes down the case the control exists for: a starving, hunted cell renders
## at (6,23,23), and on an LCD phone in daylight that is close to invisible. A
## player who turned the light up to see it would lose it again the moment they
## pressed `watch` -- on the one screen built to explain the death.
##
## The run's own bus first, because that is the live value and includes a drag
## the pause screen has not written to `user://` yet; the stored setting when
## there is no run to ask. One write covers both panes: they share a material.
func _apply_gain() -> void:
	if _bus == null:
		return
	_bus.apply_gain(_run_bus.gain if _run_bus != null
		else RunState.load_gain(SignalBus.GAIN_DEFAULT))


## The last thing the shipped views need that is not a node: the membrane, as a
## block of numbers rather than as the sensations that made it. [method
## SignalBus.write_block] is the only thing that knows what is in it.
func push_block(block: PackedFloat32Array, at: int) -> void:
	if _bus == null:
		return
	_bus.write_block(block, at)
	# Proprioception is not a sensation and does not go on the bus: the figure
	# is handed the one number it cannot derive for itself, exactly as the run
	# hands it over.
	if _soma != null:
		_soma.beat = _bus.pulse()


## A recorded sensation, back on this screen's own bus so that the world view
## draws its kick rings, bruise rays and wake rays unchanged. Bearings and
## intensities only; a position has never been allowed on a bus and is not now.
func feel(kind: StringName, info: Dictionary) -> void:
	if _bus != null:
		_bus.sensation.emit(kind, info)


## Ground truth about a contact and a meal, which the world pane needs and the
## bus may not carry. Straight into the view's own marks -- never through the
## fields' signals, which the run behind this screen is still subscribed to.
func mark_struck(at: Vector2) -> void:
	if _vision != null:
		_vision.mark_struck(at)


func mark_meal(nutrition: float, gene: StringName, at: Vector2) -> void:
	if _vision != null:
		_vision.mark_meal(nutrition, gene, at)


## What the two views draw this frame when the body is becoming two. Same
## contract as the run's: empty is an ordinary body.
func set_division(division: Dictionary) -> void:
	if _soma != null:
		_soma.division = division
	if _vision != null:
		_vision.division = division
		_vision.set_dim(0.22 if division.has("bodies") else 1.0)
	# **The water stops at the pinch**, exactly as it does in a run, and the
	# returns layer has to know: a beam that was last cast three seconds ago is
	# a frozen pointer claiming a place that is no longer true, sitting over the
	# one beat that owns the middle of the screen. The field's own
	# `is_processing()` cannot answer here because nothing is processing.
	if _returns != null:
		_returns.driven = not (division.has("bodies")
			or float(division.get("pinch", 0.0)) > 0.0)


func _process(_delta: float) -> void:
	if not live:
		return
	# The harness path, and the only thing it has to do by hand: both panes
	# carry a membrane of their own, so the live one has to be copied across.
	# Everything else in the two panes is reading the run's own nodes.
	if _run_bus != null:
		_run_bus.capture_block(_block, 0)
		push_block(_block, 0)
	if _run_soma != null:
		set_division(_run_soma.division)


# ---------------------------------------------------------------------------
# Building. Four shipped scenes, instanced and told where to draw. Not one of
# them is modified by this file and not one of them knows it is in a pane.
# ---------------------------------------------------------------------------

func _build() -> void:
	var back := CanvasLayer.new()
	back.name = "Back"
	back.layer = LAYER_BACK
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = BACK_COLOR
	back.add_child(fill)
	add_child(back)

	_membrane = MEMBRANE_SCENE.instantiate()
	_membrane.name = "Membrane"
	_membrane.layer = LAYER_MEMBRANE
	add_child(_membrane)
	_bus = _membrane.bus
	# **Nothing steps here.** Every uniform arrives written; an envelope running
	# underneath would fight the block for the same uniforms the way the death
	# frames would, and would re-roll a jitter the recording exists to preserve.
	_bus.set_process(false)
	# One material, two rects: the panes are the same size, so the whole block
	# is the same for both and the truth pane keeps its membrane under the
	# world. Owner's call 2 in §7.
	_truth = ColorRect.new()
	_truth.name = "Truth"
	_truth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_truth.color = BACK_COLOR
	_truth.material = _membrane.field.material
	_membrane.add_child(_truth)

	_returns = RETURNS_SCENE.instantiate()
	_returns.name = "Returns"
	_returns.layer = LAYER_RETURNS
	_returns.driven = true
	add_child(_returns)
	_returns.setup(_cell, _food)
	_returns.set_active(true)

	_soma = SOMA_SCENE.instantiate()
	_soma.name = "Soma"
	_soma.layer = LAYER_SOMA
	add_child(_soma)
	_soma.setup(_cell, _genome)
	_soma.set_active(true)

	_vision = VISION_SCENE.instantiate()
	_vision.name = "Vision"
	_vision.layer = LAYER_VISION
	_vision.bind(_cell, _motes, _food, _genome, _bus)
	add_child(_vision)
	_vision.set_active(true)

	var legend := CanvasLayer.new()
	legend.name = "Legend"
	legend.layer = LAYER_LEGEND
	# Above the world layer, because the thing being marked is where the world
	# layer stops.
	_seam = _rule("Seam", SEAM_COLOR)
	_sill = _rule("Sill", SILL_COLOR)
	legend.add_child(_sill)
	legend.add_child(_seam)
	_felt_caption = _caption(FELT_TEXT)
	_truth_caption = _caption(TRUTH_TEXT)
	legend.add_child(_felt_caption)
	legend.add_child(_truth_caption)
	add_child(legend)


func _rule(name: String, tint: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = tint
	return rect


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", CAPTION_SIZE)
	label.add_theme_color_override("font_color", CAPTION_COLOR)
	return label


# ---------------------------------------------------------------------------
# Geometry. Two panes, no gap, 624 tall at every shape:
#
#   1280x720   pane 640x624   black middle 425 x 410
#   2400x1080  pane 800x624   black middle 585 x 409
#
# The bearing map survives untouched because the shader's bearing is
# aspect-corrected: a lobe at -42 degrees lands at the same relative spot on
# 640x624 as on 1280x720, so the panes agree with each other and with the
# shipped game by construction. §4.3.
# ---------------------------------------------------------------------------

## The left pane, in canvas pixels. Public because the transport lays itself out
## against the band underneath them.
func felt_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_view.x * 0.5, pane_height()))


func truth_rect() -> Rect2:
	return Rect2(Vector2(_view.x * 0.5, 0.0),
		Vector2(_view.x - _view.x * 0.5, pane_height()))


func pane_height() -> float:
	return maxf(_view.y - BAND, 1.0)


func _relayout() -> void:
	var rect := get_viewport().get_visible_rect()
	if rect.size.x > 1.0 and rect.size.y > 1.0:
		_view = rect.size
	var felt := felt_rect()
	var truth := truth_rect()

	_membrane.field.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_membrane.field.position = felt.position
	_membrane.field.size = felt.size
	_truth.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_truth.position = truth.position
	_truth.size = truth.size

	_soma.set_frame(felt)
	_returns.set_frame(felt)
	_vision.set_frame(truth)

	_seam.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_seam.position = Vector2(truth.position.x - SEAM_WIDTH * 0.5, 0.0)
	_seam.size = Vector2(SEAM_WIDTH, pane_height())
	_sill.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_sill.position = Vector2(0.0, pane_height())
	_sill.size = Vector2(_view.x, SILL_HEIGHT)

	for pair: Array in [[_felt_caption, felt], [_truth_caption, truth]]:
		var label: Label = pair[0]
		var pane: Rect2 = pair[1]
		label.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		label.position = Vector2(pane.position.x,
			pane.size.y + CAPTION_TOP)
		label.size = Vector2(pane.size.x, CAPTION_HEIGHT)


# ---------------------------------------------------------------------------
# Finding the run, by type, the way vision.gd already does. Only used when
# nobody has called [method watch] -- which is the harness booting these panes
# over a live run.
# ---------------------------------------------------------------------------

func _find(root: Node) -> void:
	if root == null:
		return
	_walk(root)


func _walk(node: Node) -> void:
	if _cell == null and node is CellBody:
		_cell = node as CellBody
	elif _motes == null and node is MotesField:
		_motes = node as MotesField
	elif _food == null and node is FoodField:
		_food = node as FoodField
	elif _genome == null and node is GenomeNode:
		_genome = node as GenomeNode
	elif _run_bus == null and node is SignalBus:
		_run_bus = node as SignalBus
	elif _run_soma == null and node is SomaLayer:
		_run_soma = node as SomaLayer
	for child in node.get_children():
		_walk(child)
