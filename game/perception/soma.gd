extends CanvasLayer
## **Proprioception**: the cell's own body, drawn faintly at the middle of the
## point-of-view screen, always, with no gene behind it.
##
## The owner's call, and it overturns part of genes-and-cilia.md §2 -- see the
## note added there. The argument for it is short: a screen with nothing at all
## on it is disorienting rather than tense, and this phase makes that worse by
## taking the always-on scent field away and putting it behind `chemocyte`. A
## blind cell needs a frame of reference, and the least invented one available
## is the only object it is entitled to know about with no organ at all: itself.
##
## **It may only show what a cell can know about its own body.** Shape, heading,
## which organs it has and how good they are -- nothing about the water, nothing
## about any other body, and no position of anything, ever. That is not a style
## rule here, it is the whole reason this is proprioception and not a minimap.
##
## Front is up, because in point of view the whole screen is body-relative: the
## membrane's bearing 0 is the top edge and this figure has to agree with it. The
## camera toggle is a full-vision control and is a no-op here for the same
## reason it is a no-op for the membrane.
##
## Drawn by the run rather than by the bus: this is a *view*, exactly like
## vision.gd, and it takes its references directly the way vision.gd does. It
## posts nothing and it reads no uniform.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Cilia := preload("res://game/vision/cilia.gd")
const CellBody := preload("res://game/normal/cell.gd")
const GenomeNode := preload("res://game/normal/genome.gd")

## Canvas pixels per world unit. A born cell is radius 26 and a full-grown one
## 40, so the figure runs about 44 to 68 pixels across the body with the
## flagellum reaching half as far again past that. Big enough to read its own
## fringe, small enough that the middle of the screen is still mostly empty --
## which is where every signal that matters is *not*, so nothing is covered.
const SCALE := 1.7

## How faint. Judged by rendering at both shapes, not picked: the rim lands at
## about (14,50,42) against the membrane's own (6,14,13) base, which is present
## without being the subject, and every lobe on the contour stays brighter than
## any part of it. Raise this and the figure starts competing with the `stigma`.
const FADE := 0.34

## The nucleus takes the beat, so the figure breathes on the same heart the
## contour does rather than on a clock of its own.
var beat := 0.0

var _cell: CellBody = null
var _genome: GenomeNode = null
var _clock := 0.0
@onready var _figure: Control = $Figure


func _ready() -> void:
	_figure.draw.connect(_draw_figure)


## Binds the figure to the body it is a figure of. Nothing here assumes the
## wiring has happened: a headless boot builds this node before the run wires
## it, and [method _draw_figure] leaves early on a null.
func setup(cell: CellBody, genome: GenomeNode) -> void:
	_cell = cell
	_genome = genome
	_figure.queue_redraw()


## Off while full vision is drawing the real body, and off through a death --
## the membrane's collapse owns the screen then, and a body still swimming
## calmly in the middle of it would be the game contradicting itself.
func set_active(on: bool) -> void:
	visible = on


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_figure.queue_redraw()


func _draw_figure() -> void:
	if _cell == null:
		return
	var tiers := _genome.tiers() if _genome != null else GenomeNode.BORN
	var order: Array = _genome.layout() if _genome != null else []
	var r := _cell.radius * SCALE
	# Front is up: heading 0 in the figure's own frame, which is the frame the
	# whole point-of-view screen is already in.
	Cilia.draw_cell(_figure, _figure.size * 0.5, 0.0, r, tiers,
		_cell.gape() * SCALE, r, true, _clock, FADE, _cell.steer,
		clampf(beat, 0.0, 1.0), 0.0, 1.0, order)
