extends CanvasLayer
## **The returns**: the two senses that come back with a *place*, drawn in point
## of view at the place they came back from.
##
## `genes-and-cilia.md` §2.3 says point of view never gets a position. The owner
## has overridden that for exactly these two senses, and the override is
## recorded there rather than left as a contradiction between a document and a
## build. It is principled and not a convenience: an `ocellus` beam that is
## *stopped* by a surface has genuinely measured where that surface is, and an
## `ampulla` call is a thing this cell emitted, so it knows when the call left, and
## an echo's delay is the distance to what answered.
##
## **Nothing else follows them in.** No bodies, no silhouettes, no scent bloom,
## no wounds, no threat colour, nothing a sense did not touch. Only the returns
## themselves, and only while the sense is actually returning them. If this file
## ever draws a cell, it has gone past the line. The one outline it draws is a
## return too: at three copies the ping draws the side of a body its call
## reached, and nothing the call did not (ping-as-outline.md §13).
##
## **And the eyespot's picture, since it sees** (docs/design/sight.md, the owner,
## 2026-10-16: *"It will act like real vision"*). It is the interior perception.md
## kept for vision: the water lit in the eye's field, as bright as the light lets
## it, out to where the eye sees and stopped wherever a body is in the way -- so a
## body is the dark notch it cuts, and what is behind it stays dark. Blurred by the
## eye's level. Still no body is drawn: what is drawn is the light that reached the
## eye, and a body is where it did not.
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
## The membrane's channels, whose organs' hues the marks are drawn in.
const Catalogue := preload("res://game/genes/catalogue.gd")
const SomaLayer := preload("res://game/perception/soma.gd")
const Afterglow := preload("res://game/mechanics/afterglow.gd")
## How far a sweeping ray turns between two of the marks it holds: 2 degrees,
## the field's own sub-step, in radians.
const GLOW_SPACING := 0.034906585

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

# --- The ping (`ampulla`) ---------------------------------------------------
## **What the ping placed as an echo landed** (ping-as-outline.md §13): at two
## copies a point, the pointer's size and a little quieter, because it says where
## something was and not what; at three the side of the body the call reached, a
## thin outline. Both in the ping's hue, whatever answered.
const FIX_HALO := 11.0
const FIX_HALO_ALPHA := 0.14
const FIX_CORE := 3.4
const FIX_CORE_ALPHA := 0.80
const OUTLINE_WIDTH := 2.4
const OUTLINE_ALPHA := 0.78

# --- The eyespot's picture (`stigma`, docs/design/sight.md) ---------------
## **How bright the water in its field is**, at the eye in full light: dimmer with
## the light (`food.gd`'s `sight_seeing`) and fading out with the haze to where the
## eye stops seeing. Low, because it fills a third of the screen and the marks and
## the membrane have to read over it.
const SIGHT_ALPHA := 0.16
## Where the picture starts, in body radii: just off the skin, so it never lies over
## the figure.
const SIGHT_SKIN := 1.12
## The shader's array (sight.gdshader's `runs`), which has to be the field's.
const SIGHT_RAYS := FoodField.SIGHT_FAN_RAYS
const SIGHT_SHADER := preload("res://game/perception/sight.gdshader")

## **Whether something other than the field is stepping the water.** Left false
## by the run, where [method FoodField.is_processing] and the cell being in the
## water are the whole answer -- a division and a death both stop the field or,
## in a pond, take the cell out of it, and then its beams and echoes are last
## frame's claims about a place that is no longer true.
##
## The replay screen sets it, because there the field is stepped from a
## recording instead of from its own `_process`: the beams and the echoes are as
## live as they ever were, they are simply being written by something else.
## docs/design/replay.md §4.5.
var driven := false

var _cell: CellBody = null
var _food: FoodField = null
## A sweep's hits, held and fading (beam-levels.md §4.3).
var _glow := _new_glow()
## [[mark, age], ...] -- what the ping placed (§13), each held for its `life`.
var _echo_marks: Array = []
@onready var _marks: Control = $Marks
## **The eyespot's picture**, under the marks: a rect as big as theirs that
## sight.gdshader draws into ([method _update_sight]).
var _sight := ColorRect.new()


func _ready() -> void:
	_marks.draw.connect(_draw_marks)
	var m := ShaderMaterial.new()
	m.shader = SIGHT_SHADER
	_sight.material = m
	_sight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sight.visible = false
	add_child(_sight)
	move_child(_sight, _marks.get_index())


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
	if _sight != null:
		_sight.visible = false
	if not on:
		# Held marks are claims about a moment; one that was hidden through a
		# pause or full vision is stale when it comes back.
		_glow.clear()
		_echo_marks.clear()


## **What the ping placed as an echo landed** (ping-as-outline.md §13), from the
## run as it happens and from the replay as it was recorded. Held for the mark's
## own `life`, one call, fading; not taken while the layer is off.
func mark_echo(mark: Dictionary) -> void:
	if not visible:
		return
	_echo_marks.append([mark, 0.0])


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
	_sight.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_sight.position = rect.position
	_sight.size = rect.size


func _process(delta: float) -> void:
	if not visible:
		return
	_catch_hits(delta)
	for i in range(_echo_marks.size() - 1, -1, -1):
		var held: Array = _echo_marks[i]
		held[1] = float(held[1]) + delta
		if float(held[1]) >= float((held[0] as Dictionary).get("life", 0.0)):
			_echo_marks.remove_at(i)
	_marks.queue_redraw()
	_update_sight()


func _draw_marks() -> void:
	if _cell == null or _food == null:
		return
	# **Only while the water is actually being stepped.** A division and a death
	# both stop the field without pausing the tree, and a field that has stopped
	# keeps last frame's beams and last frame's echoes -- which would leave a
	# frozen pointer sitting over the division beat, claiming a place that is no
	# longer true. This is the same silence `normal_mode._hush()` puts on the
	# bus, said in the one register that does not go through the bus.
	#
	# **And only while this cell is in it** (shared-pond.md §3). In a pond the
	# field goes on stepping through a death and a division, for the other
	# player, while this cell's organs stop with it out of the water -- so the
	# field running is no longer the answer; this cell being in it is. Always
	# in the water in single player.
	if not (driven or (_food.is_processing() and _food.in_water)):
		return
	var centre := _marks.size * 0.5
	_draw_echo_marks(centre)
	_draw_pointers(centre)


## **What the eyespot sees** (docs/design/sight.md): the field's rays handed to
## sight.gdshader, which lights the water in the eye's field out to where each ray
## stopped, per pixel and across the eye's blur. Hidden while there is no eye, the
## water is not being stepped or this layer is off.
func _update_sight() -> void:
	var fan := _food.sight_fan if _food != null else PackedFloat32Array()
	var live := _cell != null and _food != null \
		and (driven or (_food.is_processing() and _food.in_water))
	_sight.visible = live and fan.size() == SIGHT_RAYS and _food.sight_reach > 0.0
	if not _sight.visible:
		return
	var m := _sight.material as ShaderMaterial
	var size := _marks.size
	m.set_shader_parameter("runs", fan)
	m.set_shader_parameter("count", fan.size())
	m.set_shader_parameter("mid", _food.sight_mid)
	m.set_shader_parameter("half_field", _food.sight_half)
	m.set_shader_parameter("blur", _food.sight_blur)
	m.set_shader_parameter("reach", _food.sight_reach)
	m.set_shader_parameter("core", _food.sight_core * _food.sight_seeing)
	m.set_shader_parameter("skin", _cell.radius * SIGHT_SKIN)
	m.set_shader_parameter("scale", SCALE)
	m.set_shader_parameter("centre", size * 0.5)
	m.set_shader_parameter("frame", size)
	m.set_shader_parameter("lit", SIGHT_ALPHA * _food.sight_seeing)
	var tone := Cilia.hue_on(Catalogue.LIGHT)
	m.set_shader_parameter("tone", Vector3(tone.r, tone.g, tone.b))


## How far from [param centre] along [param dir], in pixels, the edge fade reaches
## nothing: [constant EDGE_HIDE] in from the frame.
func _to_frame(centre: Vector2, dir: Vector2) -> float:
	var size := _marks.size
	var best := INF
	if dir.x > 0.0001:
		best = minf(best, (size.x - EDGE_HIDE - centre.x) / dir.x)
	elif dir.x < -0.0001:
		best = minf(best, (EDGE_HIDE - centre.x) / dir.x)
	if dir.y > 0.0001:
		best = minf(best, (size.y - EDGE_HIDE - centre.y) / dir.y)
	elif dir.y < -0.0001:
		best = minf(best, (EDGE_HIDE - centre.y) / dir.y)
	return maxf(best, 0.0)


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
	var tone := Cilia.hue_on(Catalogue.BEAM)
	# **A sweep draws what it has held** (beam-levels.md §4.3): every hit of the
	# last pass, where the body was when the ray crossed it, fading until the
	# ray comes back. This frame's hits are the newest of them.
	var life := _food.beam_hold
	if life > 0.0:
		for i in _glow.count():
			var rel := _glow.point(i) - _cell.position
			_draw_pointer(centre, _cell.bearing_to(_glow.point(i)), rel.length(),
				tone, _glow.strength(i, life))
		return
	for beam: Array in _food.beams:
		if not bool(beam[2]):
			continue
		# `beam[1]` is how far along the ray the surface was, from the centre of
		# this body -- not the beam's range, which is what it holds when nothing
		# was hit and `beam[2]` is false.
		_draw_pointer(centre, float(beam[0]), float(beam[1]), tone, 1.0)


## One mark, [param distance] out along [param bearing], at [param fade] of its
## full strength.
func _draw_pointer(centre: Vector2, bearing: float, distance: float, tone: Color,
		fade: float) -> void:
	var at := centre + _ray(bearing) * distance * SCALE
	var vis := fade * _edge_fade(at) * smoothstep(
		_cell.radius * POINT_SKIN, _cell.radius * POINT_CLEAR, distance)
	if vis <= 0.0:
		return
	_marks.draw_circle(at, POINT_HALO, Color(tone, POINT_HALO_ALPHA * vis),
		true, -1.0, true)
	_marks.draw_circle(at, POINT_CORE, Color(tone, POINT_CORE_ALPHA * vis),
		true, -1.0, true)


## **A sweep's hits, caught as they happen**, in the water's own coordinates so
## they stay where the body was while this cell turns and moves. A fan that does
## not sweep holds nothing: its rays never leave, so this frame's hits are the
## whole truth.
func _catch_hits(delta: float) -> void:
	if _cell == null or _food == null:
		return
	var live := driven or (_food.is_processing() and _food.in_water)
	var life := _food.beam_hold if live else 0.0
	_glow.step(delta, life, _cell.position)
	if life <= 0.0:
		return
	for k in _food.beams.size():
		var beam: Array = _food.beams[k]
		if not bool(beam[2]):
			continue
		var bearing := float(beam[0])
		_glow.add(_cell.position + (_cell.forward() * cos(bearing)
			+ _cell.starboard() * sin(bearing)) * float(beam[1]), k, bearing)


## **What the ping placed** (ping-as-outline.md §13), where the call met it and
## fading over one call: a plain point at two copies -- the same for a meal, a
## hunter or the rim, because nothing in an echo says which -- and at three the
## side of the body the call reached, through the points the field worked out on
## its rim.
func _draw_echo_marks(centre: Vector2) -> void:
	if _echo_marks.is_empty():
		return
	var tone := Cilia.hue_on(Catalogue.PING)
	for held: Array in _echo_marks:
		var mark: Dictionary = held[0]
		var life := maxf(float(mark.get("life", 0.0)), 0.001)
		var fade := 1.0 - clampf(float(held[1]) / life, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var lines: Array = mark.get("lines", [])
		if lines.is_empty():
			_draw_fix(centre, mark.get("at", Vector2.ZERO), tone, fade)
			continue
		for line: PackedVector2Array in lines:
			_draw_outline(centre, line, tone, fade)


## One placed point, at [param fade]: hidden inside the skin, as a pointer is.
func _draw_fix(centre: Vector2, point: Vector2, tone: Color, fade: float) -> void:
	var at := _on_screen(centre, point)
	var vis := fade * _edge_fade(at) * smoothstep(_cell.radius * POINT_SKIN,
		_cell.radius * POINT_CLEAR, point.distance_to(_cell.position))
	if vis <= 0.0:
		return
	_marks.draw_circle(at, FIX_HALO, Color(tone, FIX_HALO_ALPHA * vis), true, -1.0, true)
	_marks.draw_circle(at, FIX_CORE, Color(tone, FIX_CORE_ALPHA * vis), true, -1.0, true)


## One run of an outline, points in the water's own coordinates, carried to this
## screen point by point -- so it stays where the body was while this cell turns
## and moves -- and faded at each point by the membrane's edge, as a pointer is.
func _draw_outline(centre: Vector2, line: PackedVector2Array, tone: Color,
		fade: float) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	points.resize(line.size())
	colors.resize(line.size())
	var seen := false
	for i in line.size():
		var p := _on_screen(centre, line[i])
		var vis := _edge_fade(p) * fade
		points[i] = p
		colors[i] = Color(tone, OUTLINE_ALPHA * vis)
		seen = seen or vis > 0.0
	if seen:
		_marks.draw_polyline_colors(points, colors, OUTLINE_WIDTH, true)


## A place in the water, on this screen: at its bearing from the cell and its
## distance, at the figure's scale -- front up, as every mark here is.
func _on_screen(centre: Vector2, point: Vector2) -> Vector2:
	return centre + _ray(_cell.bearing_to(point)) * point.distance_to(_cell.position) * SCALE


## A body-relative bearing as a direction on this screen. **Front is up**, the
## same frame the membrane's bearing 0 and the soma figure are both already in.
func _ray(bearing: float) -> Vector2:
	return Vector2(sin(bearing), -cos(bearing))


## 1 well inside the frame, 0 on the contour and outside it.
func _edge_fade(at: Vector2) -> float:
	var size := _marks.size
	var edge := minf(minf(at.x, size.x - at.x), minf(at.y, size.y - at.y))
	return smoothstep(EDGE_HIDE, EDGE_SHOW, edge)


## A sweep's held marks, one per [constant GLOW_SPACING] of each ray's travel
## (beam-levels.md §4.3): the same trail at any frame rate.
static func _new_glow() -> Afterglow:
	var glow := Afterglow.new()
	glow.spacing = GLOW_SPACING
	return glow
