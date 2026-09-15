extends CanvasLayer
## **The returns**: the two senses that come back with a *place*, drawn in point
## of view at the place they came back from.
##
## `genes-and-cilia.md` §2.3 says point of view never gets a position. The owner
## has overridden that for exactly these two senses, and the override is
## recorded there rather than left as a contradiction between a document and a
## build. It is principled and not a convenience: an `ocellus` beam that is
## *stopped* by a surface has genuinely measured where that surface is, and an
## `ampulla` pulse is a thing this cell emitted, so this cell knows where its own
## wavefront has got to.
##
## **Nothing else follows them in.** No bodies, no silhouettes, no scent bloom,
## no wounds, no threat colour, nothing a sense did not touch. Only the returns
## themselves, and only while the sense is actually returning them. If this file
## ever draws a cell, it has gone past the line.
##
## **A drawing change, not a simulation change.** Everything here is read out of
## `food.gd` exactly as it stands, the same way `vision.gd` reads it, and nothing
## here posts, writes or is subscribed to. In particular no position reaches the
## signal bus: `normal_mode.gd` is still the only node that talks to it and it
## still carries bearings and intensities alone.
##
## **The membrane keeps its lobes.** A return that has scrolled off the screen
## still has a bearing worth having; at this scale that is most of a beam's
## reach. And the lobe is a *sensation* -- the thing audio and haptics will
## subscribe to -- so removing it would change what the cell feels, which is the
## one thing "one simulation, two views" forbids. Lobe and mark come off the same
## numbers and say the same thing in two registers.
##
## **Drawn at soma.gd's scale, not at vision.gd's**, and that is the whole of why
## a place is legible here. The only object on this screen with a known size is
## your own body, so a mark has to be at the body's scale or *"two body-widths
## ahead of me"* -- the one reading a blind cell can actually take off this
## picture -- is a lie. It buys a second thing for free: the figure's fringe is
## drawn in the same true-circular space, so the pointer lies exactly along the
## ray out of the ocellus arc it came from, and *"the beam is in a rear slot"*
## stops being something a point-of-view player has to deduce.
##
## The cost is that the far half of a beam's reach is off screen: full strength
## reaches 134 world units dead ahead and 299 abeam at 1280x720, against a
## tier-2 beam's 900. Measured over a minute of foraging, 29% of hits drew a
## mark. That is the owner's constraint restated rather than a shortfall -- the
## pointer is the arrival instrument and the membrane's lobe is the approach one.
##
## It is not a bearing rose and it never agrees with the lobes by angle. The
## shader measures bearing on an *aspect-corrected* ellipse, so its 45 degrees
## lands in the corner of whatever screen it is on; a position cannot be drawn
## in that space without distorting the distance. The two agree by quadrant and
## by which way to swim, which is what they are for.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")
const FoodField := preload("res://game/normal/food.gd")
const Cilia := preload("res://game/vision/cilia.gd")
const SomaLayer := preload("res://game/perception/soma.gd")

## Canvas pixels per world unit. **The figure's, taken from the figure**, so the
## two can never drift apart -- see the header.
const SCALE := SomaLayer.SCALE

## **How "on screen" is decided**, in pixels from the nearest edge: nothing at
## all below EDGE_HIDE, full strength at EDGE_SHOW, a ramp between.
##
## Both are the membrane's own geometry rather than taste. The contour sits 28px
## in (`membrane.gd` BASE_INSET_PX), wobbles by up to 22px (`membrane.gdshader`
## wobble_px) and is 9px thick, so it can reach 6px from the edge -- a mark
## outside it, or sitting on it, would read as a fault in the membrane and not as
## a thing in the water, and EDGE_HIDE is clear of the whole of that. The signal
## band reaches 104px further in (band_px), and EDGE_SHOW is the inner lip of it:
## across the band the mark is present but dimming, which is the pointer handing
## the bearing back to the lobe that carries it the rest of the way.
##
## The ramp is also what keeps the owner's *"only when that point is on screen"*
## from being a hard pop every time a body crosses the edge of the frame.
const EDGE_HIDE := 56.0
const EDGE_SHOW := 132.0

# --- The pointer (`ocellus`) ------------------------------------------------
## **Constant brightness, deliberately.** The lobe on the membrane carries how
## near the hit is, because a bearing is all it has room for. Here the distance
## is carried by *where the mark is*, which is the entire point of it; making the
## mark dim with range as well would spend the one thing this drawing adds.
const POINT_HALO := 13.0
const POINT_HALO_ALPHA := 0.16
const POINT_CORE := 3.8
const POINT_CORE_ALPHA := 0.86
## **No mark inside your own skin.** Bodies overlap in this water -- being eaten
## and eating both happen at nought distance -- and a beam is cast from the
## centre of the cell, so a body pressed against you returns a distance shorter
## than your own radius. Drawn honestly at that distance the pointer lands on the
## nucleus, which is a mark sitting on top of the figure it is supposed to lose
## to, and a place in the water that is *inside you* is not a place you can do
## anything with. Rendered, and that is how it was found: a minute of foraging
## put two of them on the soma's own nucleus.
##
## Hidden at the body's outline and full by the second number, so nothing pops on
## and nothing is drawn over the solid part of the figure. Contact already has
## three senses of its own -- `palp`, the bruise and dread.
const POINT_SKIN := 1.0
const POINT_CLEAR := 1.3

# --- The wave (`ampulla`) ---------------------------------------------------
## Quieter than the pointer on purpose: the pointer is an answer and this is the
## question going out. Measured on a frame with a taste band and dread present,
## low-passed at sigma 6 against the local level -- band 96, soma figure 52,
## pointer 46, the beat's own contour 33, this ring 8. Everything the membrane
## does beats it, which is the order it has to be in.
const WAVE_STEPS := 96
const WAVE_WIDTH := 2.2
const WAVE_ALPHA := 0.52

## **Whether something other than the field is stepping the water.** Left false
## by the run, where [method FoodField.is_processing] is the whole answer -- a
## division and a death both stop the field, and a stopped field's beams and
## wavefront are last frame's claims about a place that is no longer true.
##
## The replay screen sets it, because there the field is stepped from a
## recording instead of from its own `_process`: the beams and the front are as
## live as they ever were, they are simply being written by something else.
## docs/design/replay.md §4.5.
var driven := false

var _cell: CellBody = null
var _food: FoodField = null
@onready var _marks: Control = $Marks


func _ready() -> void:
	_marks.draw.connect(_draw_marks)


## Binds the layer to the body and the water it is reading. Nothing here assumes
## the wiring has happened: a headless boot builds this node before the run wires
## it, and [method _draw_marks] leaves early on a null. The two node references
## never change for the life of a run -- a death and a birth reset those nodes
## rather than replacing them -- so this is called once.
func setup(cell: CellBody, food: FoodField) -> void:
	_cell = cell
	_food = food
	_marks.queue_redraw()


## Off in full vision, which draws both of these in the water already, and off
## through a death and under the pause screen. Switched with the soma figure and
## under exactly the same conditions; `normal_mode.gd` owns the switch.
func set_active(on: bool) -> void:
	visible = on


## **Which part of the screen the marks are drawn in.** The whole viewport in
## normal mode, where nothing calls this; the left pane on the replay screen.
## The edge fade reads its distances off this rect, so a mark near the middle of
## the pane is near the middle of a membrane that is exactly that size.
func set_frame(rect: Rect2) -> void:
	_marks.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_marks.position = rect.position
	_marks.size = rect.size
	_marks.clip_contents = true
	_marks.queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	_marks.queue_redraw()


func _draw_marks() -> void:
	if _cell == null or _food == null:
		return
	# **Only while the water is actually being stepped.** A division and a death
	# both stop the field without pausing the tree, and a field that has stopped
	# keeps last frame's beams and last frame's wavefront -- which would leave a
	# frozen pointer sitting over the division beat, claiming a place that is no
	# longer true. This is the same silence `normal_mode._hush()` puts on the
	# bus, said in the one register that does not go through the bus.
	if not (driven or _food.is_processing()):
		return
	var centre := _marks.size * 0.5
	_draw_wave(centre)
	_draw_pointers(centre)


## **The pointer.** Where a beam was *stopped*, and nowhere else.
##
## The owner's original words for this gene were *"you don't see nothing but the
## point where the laser touches something"*, so there is no line drawn from the
## body and there is no mark at all for a beam that ran its whole reach into open
## water. The beam's existence is not the return; the return is the return.
##
## Every beam that landed gets one, not just the nearest. The membrane posts only
## the nearest because there is one glow lobe and a tier-3 `ocellus` has three
## beams; three beams that each stopped on something have each measured a place,
## and this is the register with room to say so.
func _draw_pointers(centre: Vector2) -> void:
	var tone := Cilia.hue(&"ocellus")
	for beam: Array in _food.beams:
		if not bool(beam[2]):
			continue
		# `beam[1]` is how far along the ray the surface was, from the centre of
		# this body -- not the beam's range, which is what it holds when nothing
		# was hit and `beam[2]` is false.
		var distance := float(beam[1])
		var at := centre + _ray(float(beam[0])) * distance * SCALE
		var vis := _edge_fade(at) * smoothstep(
			_cell.radius * POINT_SKIN, _cell.radius * POINT_CLEAR, distance)
		if vis <= 0.0:
			continue
		_marks.draw_circle(at, POINT_HALO, Color(tone, POINT_HALO_ALPHA * vis),
			true, -1.0, true)
		_marks.draw_circle(at, POINT_CORE, Color(tone, POINT_CORE_ALPHA * vis),
			true, -1.0, true)


## **The wave.** The wavefront of the pulse currently in flight, expanding out of
## the body, exactly as full vision draws it -- a thing the cell emitted, so the
## cell knows where it has got to.
##
## Per-vertex alpha rather than one colour, so the ring dissolves into the
## membrane band as it passes out through it instead of being clipped at a
## rectangle. The corners hold it a moment longer than the top edge does, which
## is what the screen actually is.
##
## The returns the wave brings back are *not* drawn: they stay marks on the
## contour. A return is a body somewhere out there, and a body is the first thing
## on the list this layer may not draw.
func _draw_wave(centre: Vector2) -> void:
	var front: float = _food.ping_front
	var reach: float = _food.ping_range
	if front <= 0.0 or reach <= 0.0:
		return
	var r := front * SCALE
	# Once the whole ring is past the far corner there is none of it left to
	# see, and a 96-point circle three screens wide is drawn for nobody.
	if r > _marks.size.length() * 0.5:
		return
	# Fades with how much of its reach it has spent, the same way full vision
	# fades it: the ring is off the screen long before it is out of range, so
	# this is the only thing that can say *it is still going*.
	var carry := 1.0 - clampf(front / reach, 0.0, 1.0)
	var tone := Cilia.hue(&"ampulla")
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	points.resize(WAVE_STEPS + 1)
	colors.resize(WAVE_STEPS + 1)
	var seen := false
	for i in WAVE_STEPS + 1:
		var t := TAU * float(i % WAVE_STEPS) / float(WAVE_STEPS)
		var p := centre + Vector2(sin(t), -cos(t)) * r
		var vis := _edge_fade(p) * carry
		points[i] = p
		colors[i] = Color(tone, WAVE_ALPHA * vis)
		seen = seen or vis > 0.0
	if seen:
		_marks.draw_polyline_colors(points, colors, WAVE_WIDTH, true)


## A body-relative bearing as a direction on this screen. **Front is up**, the
## same frame the membrane's bearing 0 and the soma figure are both already in.
func _ray(bearing: float) -> Vector2:
	return Vector2(sin(bearing), -cos(bearing))


## 1 well inside the frame, 0 on the contour and outside it.
func _edge_fade(at: Vector2) -> float:
	var size := _marks.size
	var edge := minf(minf(at.x, size.x - at.x), minf(at.y, size.y - at.y))
	return smoothstep(EDGE_HIDE, EDGE_SHOW, edge)
