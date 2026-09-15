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

## The one part of the figure that is drawn brighter than the figure, and the
## reason is what it is for. The body is a frame of reference and should stay
## under everything; a gene loose inside you is a **decision that is waiting**,
## and the owner's complaint was that at the body's own fade nobody ever saw it.
## It is the only thing on this figure that is ever asking for anything, so it
## is the only thing allowed to be louder than the outline it sits in.
##
## **0.78 was too loud by one measurement and this is that measurement.** The
## rule the mark has to obey is that every *sensation* beats it, and a peak
## pixel is the wrong way to check that -- a 1.6px ring stroke out-peaks a
## 200px dread swell and is plainly not the louder thing. Low-passed at sigma 6,
## which is about what a glance integrates over at 1280x720, a dread lobe came
## to 60.4 and this mark to 60.8: a dead heat, and a dead heat is not losing.
## At 0.68 it reads 53 against dread's 60, a beam return's 67 and a taste
## band's 136, and the ordering is right in every pair.
const FADE_PENDING := 0.68

## The nucleus takes the beat, so the figure breathes on the same heart the
## contour does rather than on a clock of its own.
var beat := 0.0

## **The division**, written once a frame by the run. Empty is an ordinary body.
## `double` and `pinch` are the mother becoming two; `bodies` is present only
## once there are two of them, and its presence is what says to stop drawing one
## figure and draw the pair. docs/design/lifecycle.md §4.
##
## Point of view may draw all of this, and the reason is not a loophole: during
## the parting both bodies are self, and this layer's licence is *what a cell
## can know about itself*. After the commit the sister is another body in the
## water and this figure never draws her again.
var division := {}

## How far either side of centre the two of them are seated, in canvas px **at
## a 1280-wide canvas**, scaled by the width of the frame this figure is drawn
## in. It was a bare constant, and it was the one length on the figure that is
## not a fraction of something -- so at 2400x1080, where `canvas_items/expand`
## makes the canvas 1600 across, the daughters sat closer together relative to
## everything around them, and in a 640-wide replay pane two r28.28 bodies at
## +/-132 span 408px against a 425px black middle: eight pixels a side, with the
## outer flagellum tips in the faint tail of the band. docs/design/replay.md
## §4.3 and §6.2.
const DIVIDE_SEAT := 132.0
const DIVIDE_SEAT_WIDTH := 1280.0

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


## **Which part of the screen this figure is centred in.** The whole viewport in
## normal mode, where nothing calls this; the left pane on the replay screen,
## where *what you felt* is the point-of-view half. The figure is not scaled
## down with it: a fully grown cell is 204px across and a 640px pane has 110px
## of black either side of it. docs/design/replay.md §4.3.
func set_frame(rect: Rect2) -> void:
	_figure.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_figure.position = rect.position
	_figure.size = rect.size
	_figure.clip_contents = true
	_figure.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_figure.queue_redraw()


func _draw_figure() -> void:
	if _cell == null:
		return
	var tiers := _genome.tiers() if _genome != null else GenomeNode.BORN
	# **The body's layout for the body, the DNA's for what is loose in it.** The
	# organs are where they were grown; an empty socket is a hole in the DNA,
	# which is where a gene you are holding is actually going.
	var order: Array = _genome.body_layout() if _genome != null else []
	var dna: Array = _genome.layout() if _genome != null else []
	var r := _cell.radius * SCALE
	# Front is up: heading 0 in the figure's own frame, which is the frame the
	# whole point-of-view screen is already in.
	#
	# **The wound is shown, and it is not a health bar.** It is a fact about
	# this body and about nothing in the water, which is exactly the line this
	# figure is allowed to stand on -- the same line the gape and the fringe are
	# already over. Drawing the figure whole while the cell is coming apart
	# would be the one thing proprioception cannot do, which is lie about the
	# body it is a picture of.
	var centre := _figure.size * 0.5
	if division.has("bodies"):
		_draw_daughters(centre)
		return
	Cilia.draw_cell(_figure, centre, 0.0, r, tiers,
		_cell.gape() * SCALE, r, true, _clock, FADE, _cell.steer,
		clampf(beat, 0.0, 1.0), 0.0, 1.0, order, _cell.wound,
		float(division.get("double", 0.0)), float(division.get("pinch", 0.0)))
	# **What is loose in you, and where it could go.** Both are facts about this
	# body and about nothing in the water, so both are inside the line this
	# figure stands on -- and the second heartbeat the membrane already carries
	# now has a picture to belong to. The rhythm says *something is unresolved*;
	# this says *what*, and *where*.
	Cilia.draw_pending(_figure, centre, 0.0, r, dna,
		_genome.held_sample if _genome != null else &"",
		_genome.held_remaining if _genome != null else 0.0,
		clampf(beat, 0.0, 1.0), _clock, FADE_PENDING)


## **Two daughters, drawn as real bodies before the player commits.**
##
## At fade 1.0 rather than this layer's FADE: rendered at 0.34 the difference
## between the two is not callable, and at 1.0 it is. The 0.34 exists so the
## figure loses to sensations, and during a division there are no sensations --
## for the only time in the game the middle of the screen is the loudest thing
## on it, and that inversion is the beat.
func _draw_daughters(centre: Vector2) -> void:
	var bodies: Array = division["bodies"]
	var r := float(division.get("radius", 28.28)) * SCALE
	var spread := float(division.get("spread", 1.0)) * DIVIDE_SEAT \
		* (_figure.size.x / DIVIDE_SEAT_WIDTH)
	for side in bodies.size():
		var one: Dictionary = bodies[side]
		var tiers: Dictionary = one["tiers"]
		var seat := centre + Vector2(spread * (-1.0 if side == 0 else 1.0), 0.0)
		# Both are `is_self`: they are still you, so neither takes a gene tint
		# and neither draws a threat bow. The one being declined takes her own
		# colour on the way out, and that is `shed`.
		Cilia.draw_cell(_figure, seat, 0.0, r, tiers,
			CellBody.gape_of(int(tiers.get(&"cytostome", 0)), r), r, true,
			_clock, float(one["fade"]), 0.0, clampf(beat, 0.0, 1.0),
			float(side) * 2.7, 1.0, one["order"], 0.0, 0.0, 0.0,
			float(one["shed"]))
