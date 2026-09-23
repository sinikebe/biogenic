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
## Half a ring rather than a whole one, so 64 points where the circle had 96 --
## the same spacing on half the arc.
const WAVE_STEPS := Cilia.WAVE_STEPS
## Half the angle between two of those points. The far half is inset by it at
## both ends so that the two arcs do not **share** their endpoints: a vertex
## drawn by two draw calls composites twice, and measured on a tier-3 frame the
## ring's two plateaus of 257 and 150 summed sRGB above base met in a bead of
## 407 -- brighter than the lit half, at the one place on the picture that is
## supposed to say *here is where the wave stops being loud*.
##
## It leaves a notch instead, and a notch is the better artefact: a bright dot
## on the wavefront reads as a *mark*, which in this layer means a body. An
## angle rather than a distance, so the notch grows with the ring -- 5 canvas px
## at r212, about 10 by the radius at which the arc is fading into the band
## anyway. Rendered at three radii and at both shapes; it reads as the boundary
## between the loud half and the quiet one.
const WAVE_SEAM := Cilia.WAVE_SEAM
## Quieter than the pointer on purpose: the pointer is an answer and this is the
## question going out. Measured on a frame with a taste band and dread present,
## low-passed at sigma 6 against the local level -- band 96, soma figure 52,
## pointer 46, the beat's own contour 33, this ring 8. Everything the membrane
## does beats it, which is the order it has to be in. **Those five numbers were
## taken on the full ring this arc replaced**; the width and the alpha are
## unchanged, so the order still holds, but the ring's own 8 is the circle's and
## has not been re-measured on the arc.
const WAVE_WIDTH := 2.2
const WAVE_ALPHA := 0.52
## **The echo coming home**, and the reason this layer draws anything new.
##
## Brighter than the outgoing front, because the front is the question and this
## is the answer arriving: the membrane lights at the instant this collapses
## onto the organ, and a player who watched it walk in never has to work out
## which pulse the mark belongs to. That is the whole of the bounce, drawn.
##
## Short, not a half-ring: an echo comes off one body over one span of bearings,
## and drawing it any wider would say the whole hemisphere answered.
const ECHO_WIDTH := 2.6
const ECHO_ALPHA := 0.74
## Points on one returning arc. Fewer than [constant WAVE_STEPS] because an echo
## spans tens of degrees where the front spans 180, and the spacing is what
## keeps a polyline from looking polygonal.
const ECHO_STEPS := 18
## **How many echoes this layer will draw at once**, nearest home first, off
## screen ones skipped before any of them counts against it.
##
## There is no hard cap in the field -- at tier 3 eleven pulses are in the water
## at once and each answers for five bodies -- and a screen with fifty
## contracting arcs on it is not a sense, it is weather. Measured on the tier-3
## ambiguity pose: at any instant three or four are inside the frame, so this
## cuts a tail that is mostly off screen anyway.
const ECHO_DRAWN := 6

## **Whether something other than the field is stepping the water.** Left false
## by the run, where [method FoodField.is_processing] and the cell being in the
## water are the whole answer -- a division and a death both stop the field or,
## in a pond, take the cell out of it, and then its beams and wavefront are last
## frame's claims about a place that is no longer true.
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
	#
	# **And only while this cell is in it** (shared-pond.md §3). In a pond the
	# field goes on stepping through a death and a division, for the other
	# player, while this cell's organs stop with it out of the water -- so the
	# field running is no longer the answer; this cell being in it is. Always
	# in the water in single player.
	if not (driven or (_food.is_processing() and _food.in_water)):
		return
	var centre := _marks.size * 0.5
	_draw_wave(centre)
	_draw_echoes(centre)
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
## the organ, exactly as full vision draws it -- a thing the cell emitted, so the
## cell knows where it has got to.
##
## **A half-ring centred on the organ's own point on the membrane**, not a circle
## centred on the cell, because that is where the pulse left from and the hull
## takes the other half. Its centre lands on the violet tuft the soma figure
## already draws for the `ampulla`, for free: both are read off the same arc.
## That is the mechanic taught with no text at all -- the water behind your own
## body is not being asked, and the way to ask it is to turn.
##
## **On, not exactly on.** The wave leaves a circle of `cell.radius` and the
## figure is an ovoid ([constant Cilia.OVOID_ALONG] 1.18 against
## [constant Cilia.OVOID_ACROSS] 0.94), so the two agree to about a pixel on the
## four diagonals -- 1.3 canvas px at slot 3, r26 -- and part by up to 8 px at
## the nose and astern, where the ovoid is longest and the origin sits that far
## inside the drawn rim. The eye reads one place; the arithmetic does not, and
## it is the arithmetic that would have to change to make it.
##
## Where the gene has grown enough to hear through a body the far half is drawn
## too, at `alpha x ping_through`. The picture is the constant: the dim half is
## exactly as much of the lit half as the simulation lets through -- measured on
## the tier-3 frame, 150 against 257 summed sRGB above base, a ratio of 0.584
## against a constant of 0.58.
##
## **The drawn boundary is a step and the simulation's is not.** `PING_GRAZE`
## gives the hull shadow a 27.8-degree fade -- `acos(-0.24)` is 103.9 degrees --
## and [constant FoodField.PING_SILENT] cuts what is left of it at about 101, so
## at tier 1 the field still answers for a body ten degrees behind the tangent
## while this arc has stopped dead at 90. The arc is where the pulse is *loud*,
## not where it is *zero*, and it is drawn the same way in both views --
## `vision.gd` uses `draw_arc`, which takes one colour and cannot carry a fade.
## Softening it is a change to both files and to §1.4 of the spec, not a
## constant.
##
## Per-vertex alpha rather than one colour, so the arc dissolves into the
## membrane band as it passes out through it instead of being clipped at a
## rectangle. The corners hold it a moment longer than the top edge does, which
## is what the screen actually is.
##
## The bodies the wave finds are *not* drawn: their marks stay on the contour. A
## return is a body somewhere out there, and a body is the first thing on the
## list this layer may not draw. What [method _draw_echoes] adds is the pulse's
## **own** echo walking home, which is the same class of thing as the front --
## the cell emitted it and knows where it has got to.
##
## **Every live front, not just the newest.** A pulse is in the water for up to
## 7.6 s and fires again after 1.4, so one scalar drew the new front over the
## old one's returns -- a picture saying *the wave has just left* over a skin
## saying *something is out there*. ping-as-outline.md §7 photographed exactly
## that; this is the half of the fix that lives in a view. Only one or two are
## ever on screen: a front leaves the frame in under a second.
func _draw_wave(centre: Vector2) -> void:
	var reach: float = _food.ping_range
	if reach <= 0.0:
		return
	var origin := centre + _ray(_food.ping_bearing) * _cell.radius * SCALE
	# Once the whole arc is past the far corner there is none of it left to
	# see, and a 64-point arc three screens wide is drawn for nobody.
	var horizon := _marks.size.length() * 0.5 + origin.distance_to(centre)
	# Screen angle of the organ's own ray. `_ray` is (sin, -cos), which is
	# `bearing - PI/2` once atan2 has it, and the lit half is the hemisphere
	# either side of it.
	var mid := _food.ping_bearing - PI * 0.5
	var through := clampf(_food.ping_through, 0.0, 1.0)
	for front: float in _food.ping_fronts:
		if front <= 0.0:
			continue
		var r := front * SCALE
		if r > horizon:
			continue
		# Fades with how much of its reach it has spent, the same way full
		# vision fades it: the arc is off the screen long before it is out of
		# range, so this is the only thing that can say *it is still going*.
		var carry := 1.0 - clampf(front / reach, 0.0, 1.0)
		_wave_arc(origin, r, mid - PI * 0.5, mid + PI * 0.5, carry)
		if through > 0.0:
			# Inset by [constant WAVE_SEAM] at both ends: flush, the two arcs
			# share a vertex at each seam and it composites twice.
			_wave_arc(origin, r, mid + PI * 0.5 + WAVE_SEAM,
				mid + PI * 1.5 - WAVE_SEAM, carry * through)


## **The echoes coming home.** One short arc per return still in flight, at the
## bearing it will land on and over the span the membrane is about to open to,
## contracting onto the organ at the instant the mark appears on the skin.
##
## This is what "it bounces" buys, and it is the answer to the ambiguity §7
## photographs. Under a round trip a mark lands at `2d / PING_SPEED` while the
## drawn front is out at `2d` -- twice the body's distance -- so arrival time on
## its own no longer tells a player which pulse answered. It does not have to:
## the echo is *visible* for the last second of its journey, so the mark arrives
## attached to something the player has been watching walk in.
##
## **It is not the outline drawn at its place**, which is §10 row 3 and the next
## gene's to sell. It is a wavelet collapsing onto the organ: it is only ever at
## the body's own distance for the instant it leaves, it carries no shape, and
## it is gone the moment it lands. What stays on the skin is still a bearing.
func _draw_echoes(centre: Vector2) -> void:
	if _food.ping_echoes.is_empty():
		return
	var tone := Cilia.hue(&"ampulla")
	var origin := centre + _ray(_food.ping_bearing) * _cell.radius * SCALE
	var horizon := _marks.size.length() * 0.5 + origin.distance_to(centre)
	var drawn := 0
	for echo: Array in _food.ping_echoes:
		if drawn >= ECHO_DRAWN:
			break
		var r: float = float(echo[0]) * SCALE
		if r > horizon:
			continue
		var level := clampf(float(echo[3]), 0.0, 1.0)
		if level <= 0.0:
			continue
		drawn += 1
		var span := deg_to_rad(clampf(float(echo[2]), 1.0, 180.0))
		var mid := float(echo[1]) - PI * 0.5
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		points.resize(ECHO_STEPS + 1)
		colors.resize(ECHO_STEPS + 1)
		var seen := false
		for i in ECHO_STEPS + 1:
			var t := mid + lerpf(-span, span, float(i) / float(ECHO_STEPS))
			var p := origin + Vector2(cos(t), sin(t)) * r
			var vis := _edge_fade(p) * level
			points[i] = p
			colors[i] = Color(tone, ECHO_ALPHA * vis)
			seen = seen or vis > 0.0
		if seen:
			_marks.draw_polyline_colors(points, colors, ECHO_WIDTH, true)


## One half of the wavefront, from [param from] to [param to] in screen angles,
## at [param level] of the wave's own alpha. Per-vertex, so the edge fade is
## taken at each point rather than at the arc.
func _wave_arc(origin: Vector2, r: float, from: float, to: float, level: float) -> void:
	if level <= 0.0:
		return
	var tone := Cilia.hue(&"ampulla")
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	points.resize(WAVE_STEPS + 1)
	colors.resize(WAVE_STEPS + 1)
	var seen := false
	for i in WAVE_STEPS + 1:
		var t := lerpf(from, to, float(i) / float(WAVE_STEPS))
		var p := origin + Vector2(cos(t), sin(t)) * r
		var vis := _edge_fade(p) * level
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
