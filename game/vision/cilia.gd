extends RefCounted
## What a cell looks like: one drawing routine, one subject.
##
## **Every cell in the water is drawn by this file, from its own genome, at its
## own tiers, plus its gape -- the player's cell included.** There is no second
## code path and no species branch, which is the whole reason §7.0 collapsed two
## simulation files into one: two routines would drift apart, and the moment
## they drift the thing the player reads off a body stops being true.
## docs/design/genes-and-cilia.md §4.
##
## The genome tiles on the pause screen draw their organ through
## [method draw_tile_organ], which shares this file's hues and this file's
## stroke shapes. A tile and a body must be the same vocabulary or §2.4's
## promise -- *"a point-of-view player learns the cilia vocabulary from the
## mirror, so if they ever switch views the language is already theirs"* -- is
## a lie the first time they look at the water.
##
## Nothing here reads the simulation and nothing here writes it. Everything
## arrives as arguments, so the same call draws a live body, a paused body and a
## 76-pixel tile.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Genome := preload("res://game/normal/genome.gd")

# --- Palette (§4.4) ---------------------------------------------------------
# A new gene hue must sit >= 30 degrees from every other gene hue and >= 40
# degrees from self teal and threat red. Feed breaks the first rule on purpose:
# the mouth *is* nutrition and the taste lobe is already that green.

## Gene identity, one hue used in four places: the cilia on your body, the cilia
## on the cell that carries it, the ingest flood at the instant you eat it, and
## the slot on the genome strip. No legend, no lookup.
## **§4.4's 30-degree separation rule is broken here, deliberately, and it had
## to be.** The rule was written for adding *one* gene to four. Sixteen genes
## cannot sit 30 degrees apart on a wheel that also forbids 40 degrees either
## side of self teal and threat red -- that leaves about 200 usable degrees, so
## the real spacing is 12. What still carries identity is what §4.4 said carries
## it when colour fails: **shape**. Every gene has its own stroke count on the
## body and on the tile ([constant EARNED_COUNT]), and every tile is labelled
## with a word. The hue is now the coarse channel, not the only one.
##
## What is *not* relaxed: nothing sits within 25 degrees of self teal (168) or
## of threat red (355), because those two are the only colours in the game whose
## meaning is a relationship rather than a name.
const HUES := {
	&"cytostome": Color(0.62, 1.00, 0.38),   # eat, 95 deg
	&"cirrus": Color(0.36, 0.62, 0.98),      # turn, 216 deg
	&"flagellum": Color(0.80, 0.42, 0.95),   # swim, 291 deg
	&"stigma": Color(0.98, 0.78, 0.30),      # see, 45 deg
	# The headline gene: a beam, so it is drawn as light. Indigo-violet is the
	# one hue that is far from teal, far from red, far from the nutrient greens
	# and still bright enough to be a line on near-black water.
	&"ocellus": Color(0.62, 0.55, 1.00),     # beam, 251 deg
	# The nose. It owns the scent band, and the scent band has been nutrient
	# green since Phase 1 -- so the gene that grants it is a green, sitting in
	# the one wide gap the wheel still had (97 to 136). Same argument as
	# `axoneme` below: a gene whose whole job is one existing signal wears that
	# signal's family.
	&"chemocyte": Color(0.405, 1.00, 0.30),  # smell, 111 deg
	# The ping shares the beam's glow lobe -- both mean *a hard surface, that
	# way* -- so it shares the beam's family too, deeper and more saturated than
	# the ocellus's pale periwinkle. Six pores against the ocellus's three
	# strokes is what actually tells them apart; see EARNED_COUNT.
	&"ampulla": Color(0.655, 0.44, 1.00),    # ping, 263 deg
	# The flagellum's evolution, so it keeps the flagellum's family: orchid ->
	# magenta. Close on purpose -- these two are the same organ, twice.
	&"axoneme": Color(0.98, 0.44, 0.90),     # push, 306 deg
	&"statocyst": Color(0.38, 0.76, 1.00),   # level, 202 deg
	&"rhabdom": Color(0.84, 0.98, 0.28),     # focus, 72 deg
	&"palp": Color(1.00, 0.68, 0.48),        # touch, 23 deg
	&"myoneme": Color(0.94, 0.42, 0.68),     # dash, 333 deg (§4.4's reserved rose)
	&"trichocyst": Color(0.76, 0.42, 1.00),  # sting, 276 deg
	&"pellicle": Color(0.36, 0.88, 0.96),    # armor, 186 deg
	&"toxicyst": Color(0.34, 1.00, 0.52),    # venom, 128 deg
	&"plastid": Color(1.00, 0.86, 0.26),     # sun, 52 deg
	&"vacuole": Color(0.44, 0.58, 1.00),     # store, 232 deg
	&"crista": Color(0.86, 0.50, 0.22),      # burn, 26 deg, darker than palp
}

## Stroke count on the arc and on the tile, per gene. **This is what actually
## separates one earned gene from another**, now that sixteen hues cannot be 30
## degrees apart: a three-bristle tuft and a nine-bristle tuft are different
## objects at a glance and stay different under any colour-blindness simulation.
## Anything not listed falls back to [constant COUNT_EARNED].
const EARNED_COUNT := {
	&"stigma": 4,
	&"ocellus": 3,
	# A chemoreceptor is a *field* of pores, so it wears the densest tuft in the
	# water -- 8 is the rendered ceiling documented under `plastid` below.
	&"chemocyte": 8,
	# Ampullae of Lorenzini come in clusters of pores, and six of them next to
	# the ocellus's three is the whole of what separates two neighbouring
	# violets at a glance.
	&"ampulla": 6,
	&"axoneme": 8,
	&"statocyst": 2,
	&"rhabdom": 6,
	&"palp": 8,
	&"myoneme": 5,
	&"trichocyst": 3,
	&"pellicle": 7,
	&"toxicyst": 6,
	# 8 is the ceiling, found by rendering: a tier-3 tuft multiplies the count
	# by 1.70, and above about 14 strokes a 24-degree arc closes up into a solid
	# flag and stops being a texture -- the same failure the oral mat documents.
	&"plastid": 8,
	&"vacuole": 2,
	&"crista": 6,
}
## Held for the next gene, in wheel order, so a later phase does not have to
## re-derive the separation rule. An unknown gene draws in the first of these
## rather than in nothing at all -- a body with an invisible organ would be a
## body the player cannot read, which is worse than a body in a strange colour.
const RESERVED_HUES: Array[Color] = [
	Color(0.48, 0.42, 0.95),  # indigo, 250 deg
	Color(0.94, 0.42, 0.68),  # rose, 333 deg
]

## Self, and everything the cell is made of. Also in vision.gd and (as a
## Vector3) in signal_bus.gd: it is the launcher's rim colour, and all three
## copies are that same one colour.
const SELF_TINT := Color(0.12, 0.70, 0.58)
## The colour of the thing that can eat you. Phase 4's predator body; §1.1.1
## moves it onto the mouth, where it is still the only red in the water.
const PREDATOR_TINT := Color(0.78, 0.24, 0.30)

## How far a cell's fill and rim are pulled toward its dominant gene's hue, so
## the largest coloured area on screen agrees with the fringe rather than
## fighting it. **The player's own cell is always pure SELF_TINT** -- you are
## the one cell in the water whose identity you do not have to read.
const TINT_TOWARD_GENE := 0.55

# --- The ovoid --------------------------------------------------------------
# The body vision.gd has drawn since Phase 2, lifted here because the cilia are
# placed by the ovoid's own parameter `t` rather than by bearing (§4.1) and the
# two have to be the same curve to the pixel.

const OVOID_STEPS := 40
const OVOID_ALONG := 1.18
const OVOID_ACROSS := 0.94
## How much narrower the nose is than the tail.
const OVOID_PINCH := 0.30
## A slow breath, so a body never looks like a drawn shape.
const BREATHE := 0.035

const BODY_FILL_ALPHA := 0.16
const BODY_RIM_ALPHA := 0.66
const BODY_RIM_WIDTH := 2.2

# --- A body that has been bitten --------------------------------------------
# **No health bar and no new colour.** A wound is drawn as what it is: the
# membrane is open, so the rim has holes in it and what was inside has mostly
# gone. It has to survive the same test §4.4 sets for the threat bow -- readable
# with the colour taken away -- which is why it is entirely shape.

## How many tears a body can have. They open one at a time (see [method
## _tear_at]), so this is also how many steps of damage the drawing resolves.
const WOUND_TEARS := 5
## Where the first tear sits, in ovoid parameter radians, before the per-cell
## offset. **Not zero, and the render is why**: at zero the first tear opens
## across the nose, which is where the lip bow, the oral mat and the heading
## needle all already are, and the body came out reading as *pointed* rather
## than as torn. 0.9 puts it on the starboard bow, in the diagonal gap, and the
## other four follow it round.
const WOUND_TEAR_SEAT := 0.9
## How wide one fully open tear is, in ovoid parameter degrees. The ovoid is
## drawn in [constant OVOID_STEPS] segments of 9 degrees, so a full tear takes
## about three of them out of the rim, and five full tears take 39% of it.
## **Measured off the render at half a wound**, where 22 left a body that had
## been chewed to the middle of its life looking very nearly intact.
const WOUND_TEAR_DEG := 28.0
## How much of the rim's brightness a whole wound takes with it. The second
## channel, and the one that works below the first tear: a body starts to go
## faint before it starts to come apart.
const WOUND_DIM := 0.32
## How much of the fill a whole wound takes away. Not all of it: an empty
## outline would read as a ghost, and the fill is also how a body is told apart
## from the water behind it.
const WOUND_FILL := 0.72
## How far the torn flap hangs inward, as a share of the radius.
const WOUND_GASH := 0.24

## The nucleus, sitting back from the nose. Brightens on the beat, which only
## the player has a reading of; everything else draws it at rest.
const NUCLEUS_BACK := 0.26
const NUCLEUS_OUTER := 0.46
const NUCLEUS_INNER := 0.22

# --- A body about to become two (lifecycle.md §4) ----------------------------
## How far apart the two cores get, as a share of the radius. See
## [method _draw_nucleus] for why it is not smaller.
const NUCLEUS_SPLIT_MAX := 0.52
## What the ovoid becomes at the pinch: longer along the heading, and with a
## waist. 1.62 against OVOID_ALONG's 1.18.
const OVOID_SPLIT_ALONG := 1.62
## How much of the half-width the waist takes, at the beam and nowhere else.
const OVOID_SPLIT_WAIST := 0.46

# --- Seven arcs, three of them spoken for (§4.1) ----------------------------
# In ovoid parameter t, degrees: 0 is the nose, +90 starboard, 180 aft. The
# free arcs are also the bearing rose -- while empty they are visible gaps at
# roughly the four diagonals, which is a 45-degree reference read off the
# organism rather than painted over it.

const ARC_CYTOSTOME := Vector2(-42.0, 42.0)
const ARC_CIRRUS_STARBOARD := Vector2(66.0, 118.0)
const ARC_CIRRUS_PORT := Vector2(-118.0, -66.0)
const ARC_FLAGELLUM := Vector2(146.0, 214.0)
## Genome slots 4..7 (zero-based 3..6) land on these, one each, in order.
## Three home arcs plus four free arcs is cell.gd's SLOT_MAX of 7, which is not
## a coincidence.
const ARC_FREE: Array[Vector2] = [
	Vector2(42.0, 66.0),
	Vector2(-66.0, -42.0),
	Vector2(118.0, 146.0),
	Vector2(-146.0, -118.0),
]

## **The genome slot IS the arc.** Slot 0 is the anterior arc, 1 the lateral
## pair, 2 the posterior, and 3..6 the four diagonals in [constant ARC_FREE] --
## two forward, two rear. That is the whole of placement being a choice: the
## two-tap on the pause strip already lets the player pick which slot a gene
## goes into, and a directional gene reads its facing off the arc it landed on.
## A laser in slot 5 looks backwards and cannot show you where you are going.
static func arc_for_slot(slot: int) -> Vector2:
	match slot:
		0:
			return ARC_CYTOSTOME
		1:
			return ARC_CIRRUS_STARBOARD
		2:
			return ARC_FLAGELLUM
		_:
			return ARC_FREE[clampi(slot - 3, 0, ARC_FREE.size() - 1)]


## The body-relative bearing an arc looks along: radians clockwise from the
## front, which is the only way this game is allowed to describe a direction.
##
## Derived from the ovoid rather than from the arc's own degrees, because the
## two are not the same number -- the parameter `t` runs faster than the bearing
## near the nose. §4.1's table is what this reproduces: the middle of free arc 1
## is `t` 54 and bearing 42.
static func arc_bearing(arc: Vector2) -> float:
	var t := deg_to_rad((arc.x + arc.y) * 0.5)
	return atan2(sin(t) * (1.0 - OVOID_PINCH * cos(t)) * OVOID_ACROSS,
		cos(t) * OVOID_ALONG)


## Where a gene in [param slot] points. The one call a directional gene makes.
static func slot_bearing(slot: int) -> float:
	return arc_bearing(arc_for_slot(slot))


# --- Geometry, at tier 1 (§4.2) ---------------------------------------------
# All lengths are fractions of the body radius, so a grown cell is not a small
# cell with stubble. **Nothing is clamped for small bodies**: on an r13-21
# drifter a tier-1 fringe really is a 4px stub, and the render says that is the
# useful division rather than a defect -- at drifter size the tier stops being
# readable and the gape does not, which is the right way round, because the
# gape is what decides the encounter and the tier is only how it got that way.

const COUNT_CYTOSTOME := 15
const COUNT_CIRRUS := 5  ## per side
const COUNT_FLAGELLUM := 6
const COUNT_EARNED := 4

const LEN_CYTOSTOME := 0.27
const LEN_CIRRUS := 0.34
const LEN_FLAGELLUM := 0.62
const LEN_EARNED := 0.30

const WIDTH_CYTOSTOME := 1.3
const WIDTH_CIRRUS := 2.0
const WIDTH_FLAGELLUM := 1.8
const WIDTH_EARNED := 1.6

const ALPHA_CYTOSTOME := 0.62
const ALPHA_CIRRUS := 0.66
const ALPHA_FLAGELLUM := 0.62
const ALPHA_EARNED := 0.72

## The oral mat stands just off the surface; everything else is rooted in it.
const CYTOSTOME_LIFT := 0.06
## Metachronal wave: a beat that travels along the mat instead of flapping it.
const CYTOSTOME_WAVE_U := 7.4
const CYTOSTOME_WAVE_HZ := 5.6
const CYTOSTOME_SWING_DEG := 26.0
## How much of the swing the middle of the stroke has taken up. Below 1 the
## cilium is a curve rather than a straight leaning stick.
const CYTOSTOME_CURVE := 0.40

const CIRRUS_HZ := 2.4
const CIRRUS_WAVE_U := 0.9
const CIRRUS_SWING_DEG := 30.0
## The bend in the oar, past the shaft.
const CIRRUS_KNEE := 0.62
const CIRRUS_BEND_DEG := 34.0
## **The cirrus leans with the steer**: the outboard side of the turn works
## harder. A motion cue, not a still-frame cue -- it does not show in a
## screenshot and is not claimed to.
const CIRRUS_STEER_BIAS := 0.55

const FLAGELLUM_POINTS := 6
const FLAGELLUM_WAVE_V := 3.0
const FLAGELLUM_WAVE_HZ := 5.2
const FLAGELLUM_WAVE_U := 0.45
const FLAGELLUM_LASH := 0.26

## The pigment organelle an earned gene carries, at the middle of its arc.
const PIGMENT_SEAT := 0.80
const PIGMENT_OUTER := 0.20
const PIGMENT_INNER := 0.10
const PIGMENT_HAZE := 0.30

# --- Tier is magnitude, not a badge (§4.3) ----------------------------------
## Longer, denser, brighter. Countable without counting.
const TIER_LEN: Array[float] = [0.0, 1.00, 1.22, 1.46]
const TIER_COUNT: Array[float] = [0.0, 1.00, 1.35, 1.70]
const TIER_ALPHA: Array[float] = [0.0, 1.00, 1.12, 1.24]

# --- The gape (§1.1.1) ------------------------------------------------------
## Where the lip bow is seated, as a multiple of **the nose**, and how far
## forward it bulges as a multiple of the gape.
##
## §1.1.1 writes the seat as `r * 1.05`, which is a body radius and a bit -- and
## that is correct for a round cell and wrong for this one. The ovoid reaches
## `r * 1.18` along the heading, so a bow seated at `1.05 r` is *inside the
## nose*: rendered, it is a flat brim lying across the top of the body with the
## oral mat sticking out through it, and it reads as a hat rather than as a
## mouth. Taken as 1.05 of the surface instead -- `1.18 * 1.05 = 1.24 r` -- the
## bow clears the nose, the stems have something to span, and at tier 3 the mat
## crest (1.67 r) converges on the apex (1.66 r at gape 1.40 r) instead of
## crossing it. The heading needle's new base at 1.80 r (§4.6) still clears
## both, which is the check that says 1.24 is the number the design meant.
const GAPE_SEAT := 1.05
const GAPE_BULGE := 0.30
const GAPE_STEPS := 20
## Where the two stems meet the body: the **middle of the first two free arcs**,
## 54 degrees, which is the diagonal gap between the anterior mat and the
## lateral oars. Landing them on the ends of the anterior arc instead was
## rendered and it was wrong -- at a tier-3 gape the tips are 1.4 r out to the
## side, so the stems run back almost horizontally and saw straight through the
## mat. From the shoulder they pass outside it at every tier.
const GAPE_STEM_T := 54.0
const GAPE_STEM_ALPHA := 0.55

const LIP_ALPHA_BASE := 0.30
const LIP_ALPHA_PER_TIER := 0.16
const LIP_WIDTH := 1.7
## A safe bow and a threat bow are the same shape in the same place with
## opposite meanings, which is the worst case for a colour-only signal: under a
## deuteranope simulation both collapse to one olive and the dangerous one ends
## up five times darker. **Shape is what carries it** -- seven teeth and a
## heavier stroke. §4.4's rule for the next designer: any signal whose opposite
## is drawn on the same shape must differ in shape, not only in colour.
const THREAT_ALPHA_MIN := 0.72
const THREAT_WIDTH := 2.6
const TEETH := 7
const TOOTH_SPAN := 0.86
const TOOTH_LEN := 0.22
const TOOTH_ALPHA := 0.9

## How thick the bow is, as a fraction of the gape -- a lip has a body, and the
## threat bow's teeth already hang [constant TOOTH_LEN] back into the mouth at
## exactly this depth. Anything within this of the bow curve is in the mouth,
## which is the whole of what the water asks ([method mouth_touches]).
const MOUTH_BITE := TOOTH_LEN
## Segments the bow is measured in. Twenty is what [method draw_gape] draws it
## with; eight is indistinguishable at the widest gape in the game (a 36-unit
## bow has a 0.6-unit sagitta per segment) and this runs against every pair of
## bodies in the water, every frame.
const MOUTH_STEPS := 8

# --- The tile face (§5.3) ---------------------------------------------------
# The genome strip is 76 canvas pixels of panel, not a body, so the organ on it
# is measured in pixels. The *shapes* are the ones above -- the same generator
# draws both -- and only the scale is local.
const TILE_ARC_RADIUS := 13.0
const TILE_ARC_FROM := 1.04 * PI
const TILE_ARC_TO := 1.96 * PI
const TILE_ARC_ALPHA := 0.30
const TILE_ARC_WIDTH := 1.7
const TILE_STROKE_ALPHA := 0.88
const TILE_CENTRE_Y := 0.66
const TILE_PIGMENT := 4.2

const TILE_COUNT := {
	&"cytostome": 9, &"cirrus": 5, &"flagellum": 6,
}
const TILE_LEN := {
	&"cytostome": 8.0, &"cirrus": 13.0, &"flagellum": 17.0,
}
const TILE_COUNT_EARNED := 5
const TILE_LEN_EARNED := 11.0
## The slot compass, in the tile's own pixels.
const TILE_COMPASS_X := 12.0
const TILE_COMPASS_Y := 13.0
const TILE_COMPASS_R := 6.5


# ---------------------------------------------------------------------------
# What a gene looks like. Asked by the body, by the tile, by the ingest flood
# and by the held-sample disc -- one answer to all four.
# ---------------------------------------------------------------------------

## The hue of one gene. An unknown gene -- a later phase's, arriving over an
## older binary in a content pack -- takes the first reserved hue rather than
## drawing as nothing.
static func hue(gene: StringName) -> Color:
	return HUES[gene] if HUES.has(gene) else RESERVED_HUES[0]


## A cell's fill and rim: self teal pulled toward whatever the body is most
## made of. [param is_self] is the player's own cell, which never takes a tint.
static func body_tint(tiers: Dictionary, is_self: bool) -> Color:
	if is_self:
		return SELF_TINT
	var gene := Genome.dominant_of(tiers)
	if gene == &"":
		return SELF_TINT
	return SELF_TINT.lerp(hue(gene), TINT_TOWARD_GENE)


# ---------------------------------------------------------------------------
# The body
# ---------------------------------------------------------------------------

## Draws one cell, whole: body, nucleus, the seven-arc fringe and the gape.
##
## [param canvas] is drawn into directly, in whatever space it is already in;
## [param unit] is how many of that space's units make one canvas pixel, so
## stroke widths come out the same thickness at any zoom.
## [param viewer_radius] is the radius of the cell doing the looking, and the
## only thing it decides is whether this cell's lip bow is the threat one:
## `other.gape > my.radius` is the whole comparison (§1.1.1).
## [param is_self] suppresses both the gene tint and the threat bow -- your own
## mouth cannot swallow you, and you already know what you are.
## [param beat] is 0..1 and brightens the nucleus; only the player has a reading
## of its own beat, so everything else passes 0.
## [param phase] is any stable per-cell number: it offsets the breath so four
## bodies do not inhale in unison.
## [param order] is the cell's slot layout -- slot index to gene, `&""` for an
## empty slot -- and it is what decides which arc each earned gene wears
## ([method arc_for_slot]). Left empty it is derived from [param tiers], which
## is what every cell in the water does: only the player has a layout the player
## chose.
## [param wound] is 0..1 and is how far through this body a mouth has chewed:
## at 1 it comes apart. **Drawn as damage to the membrane and in no new colour**
## -- the rim tears open and the body leaks out of the gaps. §4.4 forbids a red
## here: threat red means "that can eat you", and a wounded cell is very often
## the opposite of that.
##
## The last three are the division (docs/design/lifecycle.md §4) and every one
## of them is 0 for every body in the water:
## [param double] is 0..1 and pulls the nucleus apart into two cores -- the most
## legible *about to divide* image in biology, for one extra pair of circles.
## [param pinch] is 0..1 and stretches the body along its heading and narrows
## its waist, which is the parting itself.
## [param shed] is 0..1 and is **how far this body has stopped being you**: the
## daughter you did not choose takes her own dominant gene's tint on the way
## out, and the moment she stops being you is the moment she gets a colour.
static func draw_cell(canvas: CanvasItem, at: Vector2, heading: float,
		r: float, tiers: Dictionary, gape: float, viewer_radius: float,
		is_self: bool, clock: float, fade: float = 1.0, steer: float = 0.0,
		beat: float = 0.0, phase: float = 0.0, unit: float = 1.0,
		order: Array = [], wound: float = 0.0, double: float = 0.0,
		pinch: float = 0.0, shed: float = 0.0) -> void:
	if fade <= 0.0 or r <= 0.0:
		return
	var fwd := Vector2(sin(heading), -cos(heading))
	var stb := Vector2(cos(heading), sin(heading))
	var tint := body_tint(tiers, is_self)
	if shed > 0.0:
		tint = tint.lerp(body_tint(tiers, false), clampf(shed, 0.0, 1.0))

	_draw_ovoid(canvas, at, fwd, stb, r, tint, clock, fade, phase, unit, wound,
		pinch)
	_draw_nucleus(canvas, at, fwd, r, tint, beat, fade, double)
	_draw_fringe(canvas, at, fwd, stb, r, tiers, clock, fade, steer, unit, order)
	draw_gape(canvas, at, fwd, stb, r, gape,
		Genome.tier_of(tiers, &"cytostome"),
		not is_self and gape > viewer_radius, fade, unit)


## The body: an ovoid, narrower at the front, so the cell has a nose even before
## the heading needle is read -- and, once something has been biting it, a rim
## with holes in it.
static func _draw_ovoid(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, tint: Color, clock: float, fade: float,
		phase: float, unit: float, wound: float = 0.0,
		pinch: float = 0.0) -> void:
	var body := PackedVector2Array()
	body.resize(OVOID_STEPS)
	var squeeze := clampf(pinch, 0.0, 1.0)
	for i in OVOID_STEPS:
		var t := TAU * float(i) / float(OVOID_STEPS)
		var breathe := 1.0 + BREATHE * sin(t * 3.0 + clock * 1.7 + phase)
		body[i] = _surface(at, fwd, stb, r * breathe, t, squeeze)

	# **The body is not drawn smaller.** The radius is what decides every
	# encounter in the water, so a wounded cell that looked smaller would be
	# lying about the one number that matters. It holds less instead.
	var hurt := clampf(wound, 0.0, 1.0)
	canvas.draw_colored_polygon(body,
		Color(tint, BODY_FILL_ALPHA * (1.0 - WOUND_FILL * hurt) * fade))
	if hurt <= 0.0:
		var whole := body.duplicate()
		whole.push_back(body[0])
		canvas.draw_polyline(whole, Color(tint, BODY_RIM_ALPHA * fade),
			BODY_RIM_WIDTH * unit, true)
		return

	# Torn. The tears open **one at a time** rather than all together, so the
	# damage is legible as a quantity and not only as a state: one gap at a
	# fifth gone, five at the end. Their seats come off `phase`, which is
	# already the per-cell number the breath uses, so a given body's tears stay
	# in the same places for as long as it lives.
	var rim := PackedVector2Array()
	var flaps := PackedVector2Array()
	var ink := BODY_RIM_ALPHA * (1.0 - WOUND_DIM * hurt) * fade
	for i in OVOID_STEPS:
		var t := TAU * (float(i) + 0.5) / float(OVOID_STEPS)
		if _tear_at(t, phase, hurt) <= 0.0:
			rim.append(body[i])
			rim.append(body[(i + 1) % OVOID_STEPS])
	_stroke(canvas, rim, tint, ink, BODY_RIM_WIDTH * unit)

	# A flap of membrane hanging into each tear, so a gap reads as a hole in a
	# body rather than as a dashed line.
	for k in WOUND_TEARS:
		var open := clampf(hurt * float(WOUND_TEARS) - float(k), 0.0, 1.0)
		if open <= 0.0:
			continue
		var t := _tear_seat(phase, k)
		var edge := _surface(at, fwd, stb, r, t)
		flaps.append(edge)
		flaps.append(edge + (at - edge).normalized() * (r * WOUND_GASH * open))
	_stroke(canvas, flaps, tint, ink, BODY_RIM_WIDTH * unit)


## How far open the tear nearest ovoid parameter [param t] is, 0 for intact rim.
static func _tear_at(t: float, phase: float, hurt: float) -> float:
	for k in WOUND_TEARS:
		var open := clampf(hurt * float(WOUND_TEARS) - float(k), 0.0, 1.0)
		if open <= 0.0:
			continue
		if absf(angle_difference(t, _tear_seat(phase, k))) \
				< deg_to_rad(WOUND_TEAR_DEG) * open:
			return open
	return 0.0


## Where tear [param k] sits on a body whose breath offset is [param phase].
static func _tear_seat(phase: float, k: int) -> float:
	return phase + WOUND_TEAR_SEAT + TAU * float(k) / float(WOUND_TEARS)


## The nucleus, and -- while [param double] is above zero -- the two it is
## becoming.
##
## **0.52 was chosen by rendering it:** below about 0.40 the two cores overlap
## into one brighter disc, and a brighter nucleus already means the beat. Two
## distinct cores is a thing nothing else on a body does.
static func _draw_nucleus(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		r: float, tint: Color, beat: float, fade: float,
		double: float = 0.0) -> void:
	var core := at - fwd * (r * NUCLEUS_BACK)
	var b := clampf(beat, 0.0, 1.0)
	var apart := fwd * (r * NUCLEUS_SPLIT_MAX * clampf(double, 0.0, 1.0) * 0.5)
	var haze := Color(tint, (0.07 + 0.15 * b) * fade)
	var lit := Color(tint, (0.20 + 0.40 * b) * fade)
	canvas.draw_circle(core + apart, r * NUCLEUS_OUTER, haze, true, -1.0, true)
	canvas.draw_circle(core + apart, r * NUCLEUS_INNER, lit, true, -1.0, true)
	if apart.length_squared() <= 0.0:
		return
	canvas.draw_circle(core - apart, r * NUCLEUS_OUTER, haze, true, -1.0, true)
	canvas.draw_circle(core - apart, r * NUCLEUS_INNER, lit, true, -1.0, true)


## A point on the ovoid at parameter [param t] (radians), and the outward
## normal there. The normal is the analytic one rather than a difference of two
## samples: a fringe rooted on a polygon's chords leans visibly at the joints.
##
## [param pinch] is the division: the body lengthens along its heading and
## narrows at the waist. It is applied to the two ovoid constants rather than as
## a second shape, so the fringe, the tears and the gape all follow the skin
## they are rooted in for free.
static func _surface(at: Vector2, fwd: Vector2, stb: Vector2, r: float,
		t: float, pinch: float = 0.0) -> Vector2:
	var along := cos(t)
	var across := sin(t) * (1.0 - OVOID_PINCH * along)
	var long := lerpf(OVOID_ALONG, OVOID_SPLIT_ALONG, pinch)
	var wide := OVOID_ACROSS * lerpf(1.0, 1.0 - OVOID_SPLIT_WAIST
		* (1.0 - absf(along)), pinch)
	return at + fwd * (along * r * long) + stb * (across * r * wide)


static func _normal(fwd: Vector2, stb: Vector2, t: float) -> Vector2:
	# The outward normal of x = A cos t, y = B sin t (1 - k cos t), which is
	# (dy/dt, -dx/dt) normalised. At t = 0 it is the nose; at t = PI/2 it leans
	# 13 degrees forward, because the widest point of an egg is aft of its beam.
	var n_along := OVOID_ACROSS * (cos(t) - OVOID_PINCH * cos(2.0 * t))
	var n_across := OVOID_ALONG * sin(t)
	var n := fwd * n_along + stb * n_across
	return n.normalized() if n.length_squared() > 0.0 else fwd


# ---------------------------------------------------------------------------
# The fringe. One draw_multiline per gene rather than one draw_polyline per
# cilium: a tier-3 cell wears 82 of them and there are five cells in the water,
# and 400 draw calls a frame is not a thing to ask of a phone.
# ---------------------------------------------------------------------------

## The slot layout of a cell that has never been given one: the three home
## organs in their home arcs, everything else in the free arcs in whatever order
## the dictionary holds it. Every cell in the water but the player is this.
static func default_order(tiers: Dictionary) -> Array:
	var out: Array[StringName] = [&"", &"", &""]
	if tiers.has(&"cytostome"):
		out[0] = &"cytostome"
	if tiers.has(&"cirrus"):
		out[1] = &"cirrus"
	if tiers.has(&"flagellum"):
		out[2] = &"flagellum"
	for gene: StringName in tiers:
		if gene != &"cytostome" and gene != &"cirrus" and gene != &"flagellum":
			out.append(gene)
	return out


static func _draw_fringe(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, tiers: Dictionary, clock: float, fade: float,
		steer: float, unit: float, order: Array = []) -> void:
	if tiers.is_empty():
		return

	var eat := Genome.tier_of(tiers, &"cytostome")
	if eat > 0:
		var mat := PackedVector2Array()
		_gather_cytostome(mat, at, fwd, stb, r, eat, clock)
		_stroke(canvas, mat, hue(&"cytostome"),
			ALPHA_CYTOSTOME * _tier(TIER_ALPHA, eat) * fade,
			WIDTH_CYTOSTOME * unit)

	var turn := Genome.tier_of(tiers, &"cirrus")
	if turn > 0:
		var oars := PackedVector2Array()
		_gather_cirrus(oars, at, fwd, stb, r, turn, clock, steer, 1.0)
		_gather_cirrus(oars, at, fwd, stb, r, turn, clock, steer, -1.0)
		_stroke(canvas, oars, hue(&"cirrus"),
			ALPHA_CIRRUS * _tier(TIER_ALPHA, turn) * fade, WIDTH_CIRRUS * unit)

	var swim := Genome.tier_of(tiers, &"flagellum")
	if swim > 0:
		var tails := PackedVector2Array()
		_gather_flagellum(tails, at, fwd, stb, r, swim, clock)
		_stroke(canvas, tails, hue(&"flagellum"),
			ALPHA_FLAGELLUM * _tier(TIER_ALPHA, swim) * fade,
			WIDTH_FLAGELLUM * unit)

	# **The slot is the arc.** Walked by slot rather than by dictionary order, so
	# a gene the player placed in the rear-left diagonal is drawn -- and aimed --
	# in the rear-left diagonal.
	var layout := order if not order.is_empty() else default_order(tiers)
	for slot in layout.size():
		var gene: StringName = layout[slot]
		if gene == &"" or gene == &"cytostome" or gene == &"cirrus" \
				or gene == &"flagellum":
			continue
		var tier := int(tiers.get(gene, 0))
		if tier > 0:
			_draw_earned(canvas, at, fwd, stb, r, gene, tier,
				arc_for_slot(slot), fade, unit)


## The oral mat: dense, fine, standing just off the surface, with a beat that
## travels along it. It is the only dense fine mat in the vocabulary, and that
## texture is `cytostome`'s positive tell -- its hue is deliberately in the
## nutrient green family and so is the least legible of the four at range.
static func _gather_cytostome(into: PackedVector2Array, at: Vector2,
		fwd: Vector2, stb: Vector2, r: float, tier: int, clock: float) -> void:
	var count := _count(COUNT_CYTOSTOME, tier)
	var scale := _tier(TIER_LEN, tier)
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var t := deg_to_rad(lerpf(ARC_CYTOSTOME.x, ARC_CYTOSTOME.y, u))
		var wave := sin(u * CYTOSTOME_WAVE_U - clock * CYTOSTOME_WAVE_HZ)
		var length := LEN_CYTOSTOME * r * (0.80 + 0.30 * wave) * scale
		var normal := _normal(fwd, stb, t)
		var nose := _toward_nose(fwd, stb, t)
		var swing := deg_to_rad(CYTOSTOME_SWING_DEG) * wave
		var root := _surface(at, fwd, stb, r, t) + normal * (r * CYTOSTOME_LIFT)
		# Three points, **curved**: radial where it leaves the skin and at the
		# full swing only by the tip. Rendered as a straight stroke plus a lean
		# it was much worse -- at tier 3 the roots are two pixels apart, so a
		# mat of 26 leaning strokes closes up into a solid green flag and stops
		# being a texture at all. Curving it keeps every stroke separate at the
		# root, which is where density is actually read.
		var mid := root + _swung(normal, nose, swing * CYTOSTOME_CURVE) \
			* (length * 0.55)
		var tip := mid + _swung(normal, nose, swing) * (length * 0.45)
		into.append(root)
		into.append(mid)
		into.append(mid)
		into.append(tip)


## Two oars, beating in antiphase, five per side at tier 1. The bend is what
## separates it from the flagellum at a glance: an oar has a knee, a tail does
## not.
static func _gather_cirrus(into: PackedVector2Array, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, tier: int, clock: float, steer: float,
		side: float) -> void:
	var arc := ARC_CIRRUS_STARBOARD if side > 0.0 else ARC_CIRRUS_PORT
	var count := _count(COUNT_CIRRUS, tier)
	var scale := _tier(TIER_LEN, tier)
	# The outboard side of the turn works harder.
	var bias := 1.0 + CIRRUS_STEER_BIAS * clampf(-steer * side, -1.0, 1.0)
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var t := deg_to_rad(lerpf(arc.x, arc.y, u))
		var phase := clock * CIRRUS_HZ + u * CIRRUS_WAVE_U
		if side < 0.0:
			phase += PI
		var length := LEN_CIRRUS * r * (0.86 + 0.22 * cos(phase)) * scale
		var normal := _normal(fwd, stb, t)
		var nose := _toward_nose(fwd, stb, t)
		var swing := deg_to_rad(CIRRUS_SWING_DEG) * sin(phase) * bias
		var bend := swing + deg_to_rad(CIRRUS_BEND_DEG) * signf(sin(phase))
		var bent := _swung(normal, nose, bend)
		var root := _surface(at, fwd, stb, r, t)
		var knee := root + _swung(normal, nose, swing) * (length * CIRRUS_KNEE)
		into.append(root)
		into.append(knee)
		into.append(knee)
		into.append(knee + bent * (length * (1.0 - CIRRUS_KNEE)))


## The tail: long, smooth, and carrying a wave that travels out to the tip. The
## only stroke in the vocabulary that is longer than half the body.
static func _gather_flagellum(into: PackedVector2Array, at: Vector2,
		fwd: Vector2, stb: Vector2, r: float, tier: int, clock: float) -> void:
	var count := _count(COUNT_FLAGELLUM, tier)
	var scale := _tier(TIER_LEN, tier)
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var t := deg_to_rad(lerpf(ARC_FLAGELLUM.x, ARC_FLAGELLUM.y, u))
		var base := sin(u * FLAGELLUM_WAVE_U - clock * FLAGELLUM_WAVE_HZ)
		var length := LEN_FLAGELLUM * r * (0.82 + 0.26 * base) * scale
		var dir := _normal(fwd, stb, t)
		var side := Vector2(-dir.y, dir.x)
		var root := _surface(at, fwd, stb, r, t)
		var previous := root
		for j in range(1, FLAGELLUM_POINTS):
			var v := float(j) / float(FLAGELLUM_POINTS - 1)
			var lash := sin(v * FLAGELLUM_WAVE_V - clock * FLAGELLUM_WAVE_HZ
				+ u * FLAGELLUM_WAVE_U) * length * FLAGELLUM_LASH * v
			var point := root + dir * (length * v) + side * lash
			into.append(previous)
			into.append(point)
			previous = point


## An earned gene: stiff sensory bristles that do not row, over a pigment
## organelle that is the one filled spot of gene colour on a body.
static func _draw_earned(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, gene: StringName, tier: int, arc: Vector2,
		fade: float, unit: float) -> void:
	var tone := hue(gene)
	var mid := deg_to_rad((arc.x + arc.y) * 0.5)
	var seat := _surface(at, fwd, stb, r * PIGMENT_SEAT, mid)
	for k in 3:
		var q := float(k) / 3.0
		canvas.draw_circle(seat, r * PIGMENT_HAZE * (1.0 + 1.6 * q),
			Color(tone, 0.030 * (1.0 - q) * fade), true, -1.0, true)
	canvas.draw_circle(seat, r * PIGMENT_OUTER, Color(tone, 0.55 * fade),
		true, -1.0, true)
	canvas.draw_circle(seat, r * PIGMENT_INNER, Color(tone, 0.85 * fade),
		true, -1.0, true)

	var count := _count(int(EARNED_COUNT.get(gene, COUNT_EARNED)), tier)
	var scale := _tier(TIER_LEN, tier)
	var strokes := PackedVector2Array()
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var t := deg_to_rad(lerpf(arc.x, arc.y, u))
		# No clock: a sensory cilium does not row. The variation across the arc
		# is a standing bow rather than a wave, so the arc reads as a tuft and
		# not as a picket fence.
		var length := LEN_EARNED * r * (0.88 + 0.14 * sin(u * PI)) * scale
		var dir := _normal(fwd, stb, t)
		var root := _surface(at, fwd, stb, r, t)
		strokes.append(root)
		strokes.append(root + dir * length)
	_stroke(canvas, strokes, tone,
		ALPHA_EARNED * _tier(TIER_ALPHA, tier) * fade, WIDTH_EARNED * unit)


# ---------------------------------------------------------------------------
# The gape (§1.1.1)
# ---------------------------------------------------------------------------

## The mouth. **The clear span between the lip tips is exactly `2 * gape`** by
## construction -- [method _lip] puts them at `+-gape` across the heading -- so
## the span is the same number of pixels whichever way the cell is pointing and
## a cell cannot hide its mouth by turning.
##
## > **§1.1.1's "drawn at 1:1 and needs no legend" does not survive the render,
## > and the reason is the body rather than the bow.** The caliper is exact
## > against a *radius*, and a body is not drawn as a circle of its radius: the
## > ovoid is `1.18 r` along the heading and `0.94 r` across it, so a cell
## > presents anywhere from `1.88 r` to `2.36 r` wide depending on which way it
## > happens to be pointing. The measurement is therefore off by up to +18% or
## > -6% on the thing being measured, which at r26 is wider than the whole
## > tier-1-to-tier-2 gape step. Rendered against an r20 body (fits) and an r23
## > body (does not) at 150 units, neither could be called by eye. **The bow
## > carries the relationship, which is colour and teeth; it does not carry the
## > measurement.** Do not remove the teeth on the strength of the caliper.
##
## [param threat] is the one comparison that matters, `other.gape > my.radius`,
## and it is legal in full vision and only in full vision. The membrane is not
## told: point of view reads danger the way it always has, and identity on the
## skin is still forbidden.
static func draw_gape(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, gape: float, cytostome_tier: int,
		threat: bool, fade: float = 1.0, unit: float = 1.0) -> void:
	if gape <= 0.0 or fade <= 0.0:
		return
	var base := at + fwd * (r * OVOID_ALONG * GAPE_SEAT)
	var tone := hue(&"cytostome") if cytostome_tier > 0 else SELF_TINT
	var alpha := LIP_ALPHA_BASE + LIP_ALPHA_PER_TIER * float(cytostome_tier)
	var width := LIP_WIDTH
	if threat:
		tone = PREDATOR_TINT
		alpha = maxf(THREAT_ALPHA_MIN, alpha)
		width = THREAT_WIDTH

	var bow := PackedVector2Array()
	bow.resize(GAPE_STEPS + 1)
	for i in GAPE_STEPS + 1:
		bow[i] = _lip(base, fwd, stb, gape, -1.0 + 2.0 * float(i) / float(GAPE_STEPS))
	canvas.draw_polyline(bow, Color(tone, alpha * fade), width * unit, true)

	# Two stems back to the shoulder, so the bow reads as an organ rather than
	# as a floating bracket -- and back to the *shoulder* rather than to the
	# ends of the anterior arc, which is where they were first drawn and where
	# a tier-3 gape ran them straight through the oral mat.
	var stems := PackedVector2Array()
	for k in 2:
		var edge := -1.0 + 2.0 * float(k)
		stems.append(_lip(base, fwd, stb, gape, edge))
		stems.append(_surface(at, fwd, stb, r, deg_to_rad(GAPE_STEM_T * edge)))
	_stroke(canvas, stems, tone, alpha * GAPE_STEM_ALPHA * fade, width * unit)

	if not threat:
		return
	# Seven teeth, pointing back into the mouth. They are not decoration: a safe
	# bow and a threat bow are the same shape in the same place, and under a
	# deuteranope simulation they are the same colour too. The hook is what
	# survives.
	var teeth := PackedVector2Array()
	for i in TEETH:
		var s := lerpf(-TOOTH_SPAN, TOOTH_SPAN, float(i) / float(TEETH - 1))
		var root := _lip(base, fwd, stb, gape, s)
		teeth.append(root)
		teeth.append(root - fwd * (gape * TOOTH_LEN))
	_stroke(canvas, teeth, tone, alpha * TOOTH_ALPHA * fade, width * unit)


## A point on the lip bow. [param s] runs -1 to 1 across the heading, so the
## clear span is 2 * gape by construction rather than by arithmetic.
static func _lip(base: Vector2, fwd: Vector2, stb: Vector2, gape: float,
		s: float) -> Vector2:
	return base + stb * (s * gape) + fwd * (GAPE_BULGE * gape * (1.0 - s * s))


# ---------------------------------------------------------------------------
# A gene with nowhere to be yet, and the places it could go
# (docs/design/diegetic-hud.md; extends genes-and-cilia.md section 3.3)
# ---------------------------------------------------------------------------
#
# **The body is the readout.** A held sample is a fact about your own body, so
# it is drawn on the body rather than in a corner, in exactly the vocabulary the
# body already has -- and the vocabulary already contains the thing it needs.
# An *integrated* gene is a pigment organelle: seated on the skin, filled, with
# a tuft of bristles growing out of the arc. So an unintegrated one is the
# negative of that on every axis, which is what makes it readable with no legend
# and no colour at all:
#
# | integrated | held |
# | --- | --- |
# | seated on an arc | adrift inside the body |
# | a filled disc | a ring with a small core -- a vesicle, not a spot |
# | bristles rooted in the skin | a tuft floating clear of the skin, not rooted |
# | permanent | its ring tears open, the way a dying body's rim does |
#
# The gap under the floating tuft is the whole signal: **it is the organ you
# would have, drawn not touching you.** That is shape, not hue, so it survives
# the deuteranope check section 4.4 sets, and it survives being the same green
# as the mouth it may be sitting next to.

## The empty DNA slots a gene could be written into: one bead each, on a ring
## about the nucleus, at the bearing of the arc it stands for. **They moved
## inward with lifecycle.md** -- the organ never roots on this body, it roots on
## your daughter, and the DNA is the nucleus. Quiet on their
## own -- "there is room in you" is worth about as much ink as that sentence
## deserves -- and they are the thing the ghost tuft grows out of, so the
## vacancy and the destination are one mark at two intensities rather than two
## marks that have to be related by the player.
## **They are no longer on the skin at all.** They were lifted `0.055 r` clear
## of it, because seated exactly on the surface they were invisible at both
## shapes -- the rim is a 2.2px stroke of the same teal running straight through
## them, so a socket bead was a teal dot drawn on a teal line. lifecycle.md §7
## moves them further still, off the rim entirely and in to the nucleus: the
## organ never roots on this body, it roots on your daughter, and the hole it is
## going into is in the DNA. The old lift is gone with them.
##
## How far the bead ring sits from the nucleus, as a share of the radius. Just
## outside NUCLEUS_OUTER 0.46 so the beads read as *around* the nucleus rather
## than on it, and well inside the skin so the mark is a thing in the middle of
## the body. lifecycle.md §7.
const VACANCY_RING := 0.62
## of r. One bead per free slot now rather than four per arc, so each is bigger:
## at 0.062 a born cell's spare hole is about 3.2 canvas px on the soma figure,
## against 2.0 for one of the four it replaces.
const VACANCY_DOT := 0.062       ## of r
## A floor in canvas pixels, which section 4.5 refused for cilia and is right
## for this: a 4.0px stroke moved to 4.5 is a no-op, a 1.0px dot moved to 1.6 is
## the difference between a mark and a smudge. Full vision draws the body at
## r26 against the figure's r44, so this only ever bites there.
const VACANCY_DOT_MIN := 1.6     ## canvas px
const VACANCY_ALPHA := 0.52
const VACANCY_HELD := 1.7        ## how much brighter the one socket being tried gets

## The organ that is not there yet. Same strokes as [constant LEN_EARNED], at a
## fraction of the length, standing off the skin by [constant GHOST_GAP] -- and
## that gap is not a margin, it is the message.
## Measured, not chosen: at 0.13 the tuft sat inside the cirrus oars and the
## gape's starboard stem -- which is seated at t 54, the exact middle of free
## arc 1 -- and the one thing it had to say, *this is not attached*, was the
## thing the crowding took away. At 0.24 it floats outboard of every rowing
## cilium and inboard of the flagellum, in a band of the body nothing else uses.
const GHOST_GAP := 0.24          ## of r, skin to the root of the floating tuft
const GHOST_LEN := 0.74          ## of LEN_EARNED
const GHOST_ALPHA := 0.74
const GHOST_BEAT := 0.5          ## extra on the beat, as a fraction of the base
const GHOST_WIDTH := 1.7

## The vesicle itself, adrift. It circles the nucleus rather than sitting
## anywhere: a slow lap is about fourteen seconds, which is three laps in a
## sample's life -- far slower than any cilium, so it never reads as one.
const VESICLE_R := 0.21          ## of r
## **Pulled in from 0.52 by the render.** The haze below is drawn about this
## point, and at 0.52 the far edge of the cloud reached `1.22 r` from the
## nucleus -- outside the `1.18 r / 0.94 r` ovoid, so the one thing this mark
## exists to say, *it is loose inside you*, was contradicted by a grey bloom
## hanging off the flank. 0.42 still clipped the rim on the beam; at 0.34 the
## cloud's worst case is `0.34 + 0.26 + 0.40 = 0.86 r` abeam against a half
## width of `0.94 r`, and it stays under the skin whichever way it has drifted.
const VESICLE_ORBIT := 0.34      ## of r, about the nucleus
const VESICLE_RATE := 0.45       ## radians a second, before the wilt slows it
const VESICLE_RING_ALPHA := 0.85
const VESICLE_CORE := 0.36       ## of the vesicle radius
## **The core is off centre, and that is not decoration.** Centred inside its
## own ring it was a bullseye, and a bullseye is an icon; §4.4's rule that a
## mark must differ in shape applies here against the whole class of widgets.
## Offset away from the reach it becomes a dense end and a straining end, which
## is an organelle under tension rather than a target.
const VESICLE_CORE_OFF := 0.34   ## of the vesicle radius, opposite the reach
## The haze is doing more work than it looks like it is, and full vision is
## why. There the body is drawn at its real r26 against the figure's r44, so
## every stroke on it is small; a soft warm cloud the width of a third of the
## body is a **low-frequency** cue, which is the kind that survives being small.
## Tightened from 2.9 and brightened to match: the wide version spread the same
## ink over four times the area and read as a smudge over the nucleus, and it
## was what leaked past the rim.
##
## **Three stacked rings, not one flat disc, and it is the pigment organelle's
## own construction** -- [method _draw_earned] builds an integrated gene's cloud
## exactly this way. One `draw_circle` at a flat alpha has a crisp edge, and a
## crisp-edged disc of even tone is the silhouette of a widget; stacked, the
## falloff reads as something wet diffusing into the cytoplasm. Three is the
## count the body already uses and it does not band; §4.5 measured six and it
## did. Accumulated centre alpha is 0.24, the outermost band 0.04.
const VESICLE_HAZE := 1.0        ## of the vesicle radius, innermost ring
const VESICLE_HAZE_GROW := 1.6   ## how much wider the outermost ring is
const VESICLE_HAZE_RINGS := 3
const VESICLE_HAZE_ALPHA := 0.13
const VESICLE_WIDTH := 1.6
const VESICLE_STEPS := 28
## **Two harmonics, not one, and neither of them three.** A single `sin(3a)`
## wobble is threefold symmetry, which at this size is a crest on a shield --
## rendered, the held sample read as a heraldic badge sitting on the body, the
## exact thing a playfield with no icons in it cannot have. Two incommensurate
## lobes drifting at different rates never settle into a symmetry, so the
## outline stays a small wet thing that is never quite the same shape twice.
const VESICLE_WOBBLE := 0.09     ## the slow two-lobed squash
const VESICLE_WOBBLE_FINE := 0.06  ## the faster five-lobed ripple over it
## How far the outline is drawn out toward the socket it is reaching for: a
## teardrop with its tip at the thread and its fat end where the core is. This
## is the last of the three things that stop it being a symbol -- a symbol is
## the same shape whichever way it is facing, and this one is not.
const VESICLE_DRAWN := 0.16      ## of the vesicle radius
## It comes apart the way a body does, and for the same reason: a broken outline
## is the one damage signal this game has already taught, and a player who has
## seen a chewed cell needs nothing explained.
const VESICLE_TEARS := 4
const VESICLE_TEAR_DEG := 38.0

## The reach: one thread from the vesicle toward the nearest empty socket,
## stopping short of it. Carries direction and nothing else, and it swings as
## the vesicle drifts, so a genome with three holes in it is shown trying each.
## **It leaves the vesicle's edge, not its middle.** Struck from the centre it
## passed through the ring wall and the whole mark became a lollipop -- a loop
## on a stick, which is a widget with a handle. From the edge it is a strand
## coming off a droplet.
const THREAD_REACH := 0.62       ## of the way there
const THREAD_ALPHA := 0.42
const THREAD_WIDTH := 1.3
const THREAD_BOW := 0.09         ## of the chord, perpendicular to it

## Seconds of the sample's life over which the picture wilts. **The twin of
## signal_bus.gd's `HELD_FADE`, and it must stay the twin**: the second
## heartbeat and the picture on the body are one event seen twice, and a player
## who feels the rhythm weaken while the organ is still bright is reading two
## clocks. It is a constant here rather than an import because this file draws
## and must not depend on the sensory bus.
const HELD_WILT := 15.0


## Everything the body has to say about its own genome that is not an organ it
## already wears: which slots are empty, and whether something is loose inside
## looking for one.
##
## [param order] is **the DNA's** slot layout -- slot index to gene, `&""` for
## empty. Not the body's, which is what [method draw_cell] takes: what is loose
## in you is going into the DNA, and a hole in the DNA is the hole it can go in.
## [param gene] is the held sample or `&""`, and [param remaining] its seconds. [param beat] is 0..1 and is the
## same heartbeat the nucleus takes, so the reach and the tuft breathe on the
## body's own clock rather than on one of their own.
##
## Drawn after the body, by whichever view is drawing it, and **only for the
## player's own cell**: every other body in the water has a genome too, but what
## is loose inside it is not something a cell could see from outside, and a
## water full of vacancy beads would be ink spent on nothing anyone can act on.
static func draw_pending(canvas: CanvasItem, at: Vector2, heading: float,
		r: float, order: Array, gene: StringName, remaining: float,
		beat: float, clock: float, fade: float = 1.0,
		unit: float = 1.0) -> void:
	if fade <= 0.0 or r <= 0.0:
		return
	var free := free_arcs(order)
	var held := gene != &"" and remaining > 0.0
	if free.is_empty() and not held:
		return
	var fwd := Vector2(sin(heading), -cos(heading))
	var stb := Vector2(cos(heading), sin(heading))
	var tone := hue(gene) if held else SELF_TINT
	# Two clocks, on purpose. `left` runs the whole forty-five seconds and is
	# what shrinks the vesicle, so early and mid-clock are different pictures;
	# `wilt` is flat until the last fifteen and then falls, so *about to lapse*
	# is an event rather than a slope nobody notices they are on.
	var left := clampf(remaining / Genome.SAMPLE_SECONDS, 0.0, 1.0) if held else 0.0
	var wilt := clampf(remaining / HELD_WILT, 0.0, 1.0) if held else 0.0
	var pulse := clampf(beat, 0.0, 1.0)

	# Where the sample is this instant, and which empty socket it is nearest.
	# Both are wanted before anything is drawn, because the tuft and the thread
	# have to agree about which hole is being tried.
	var seat := at
	var size := 0.0
	var tried := -1
	if held:
		var core := at - fwd * (r * NUCLEUS_BACK)
		var spin := clock * VESICLE_RATE * (0.40 + 0.60 * wilt)
		seat = core + (fwd * cos(spin) + stb * sin(spin)) * (r * VESICLE_ORBIT)
		size = VESICLE_R * r * (0.60 + 0.40 * left) * (1.0 + 0.14 * pulse)
		var near := INF
		for i in free.size():
			var d := seat.distance_squared_to(_socket_bead(at, fwd, stb, r,
				free[i]))
			if d < near:
				near = d
				tried = i

	for i in free.size():
		_draw_socket(canvas, at, fwd, stb, r, free[i], tone, i == tried,
			wilt, pulse, fade, unit)
	if not held:
		return
	var target := seat
	if tried >= 0:
		target = _socket_bead(at, fwd, stb, r, free[tried])
	_draw_vesicle(canvas, seat, size, target, tried >= 0, -fwd, tone, wilt,
		pulse, clock, fade, unit)


## **Where an empty DNA slot is drawn, and it is not on the skin.** The beads
## used to sit at the seat where that organ's bristles would root; under
## lifecycle.md §7 the organ never roots there *for you* -- it roots on your
## daughter. **The DNA is the nucleus, and that is where a loose gene is going**,
## so the beads are a ring about the nucleus, one per free slot, each still at
## the bearing of the arc it stands for. It also declutters the skin, which
## diegetic-hud.md §2 already called crowded.
static func _socket_bead(at: Vector2, fwd: Vector2, stb: Vector2, r: float,
		arc: Vector2) -> Vector2:
	var bearing := arc_bearing(arc)
	var core := at - fwd * (r * NUCLEUS_BACK)
	return core + (fwd * cos(bearing) + stb * sin(bearing)) * (r * VACANCY_RING)


## The slots this genome has and has not filled, as arcs. Empty on a cell whose
## layout is unknown, which is every cell but the player's.
static func free_arcs(order: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for slot in mini(order.size(), 3 + ARC_FREE.size()):
		if StringName(order[slot]) == &"":
			out.append(arc_for_slot(slot))
	return out


## One empty socket: the beads that are always there, and -- on the one socket
## the sample is currently reaching for -- the tuft it would become, floating
## clear of the skin.
##
## **[param tuft] is one socket's privilege, not every free socket's, and the
## render is why.** Drawn on all four holes of a grown cell it was a halo of
## sixteen pale spikes standing off the skin at every diagonal: louder than the
## real fringe, and it read as *this cell has four new organs* rather than as
## *one gene is waiting*. One tuft, on the hole the thread is pointing at, is
## the same sentence at a quarter of the ink -- and because the vesicle drifts,
## a genome with three holes in it is still shown trying each of them in turn,
## which is what the four at once were trying to say and could not.
static func _draw_socket(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, arc: Vector2, tone: Color, tuft: bool,
		wilt: float, beat: float, fade: float, unit: float) -> void:
	var strokes := PackedVector2Array()
	# **The tuft stays on the skin and the bead has moved off it.** The two say
	# different things now: the bead is the hole in the DNA, by the nucleus,
	# where the gene is actually going; the tuft is the organ that hole would
	# become, drawn where an organ would stand and not touching the body. They
	# are on the same bearing, so the thread, the bead and the tuft read as one
	# line out from the middle.
	if tuft:
		for i in COUNT_EARNED:
			var u := (float(i) + 0.5) / float(COUNT_EARNED)
			var t := deg_to_rad(lerpf(arc.x, arc.y, u))
			var dir := _normal(fwd, stb, t)
			var root := _surface(at, fwd, stb, r, t)
			# It starts *off* the body and ends short of where a real one
			# would. Both halves of that are the reading: it is not rooted, and
			# it is not finished.
			var length := LEN_EARNED * r * GHOST_LEN * (0.30 + 0.70 * wilt) \
				* (0.86 + 0.14 * sin(u * PI))
			var lift := root + dir * (r * GHOST_GAP)
			strokes.append(lift)
			strokes.append(lift + dir * length)
	var dot := maxf(r * VACANCY_DOT, VACANCY_DOT_MIN * unit)
	# **Only the socket being tried brightens.** Lifting every free socket when
	# a sample arrived put sixteen bright beads round the rim of a grown cell
	# and the figure grew a necklace; the quiet ones stay quiet, which is what
	# *there is also room over here* is worth.
	var ink := clampf(VACANCY_ALPHA * (VACANCY_HELD if tuft else 1.0), 0.0, 1.0)
	canvas.draw_circle(_socket_bead(at, fwd, stb, r, arc), dot,
		Color(tone, ink * fade), true, -1.0, true)
	if tuft:
		_stroke(canvas, strokes, tone,
			GHOST_ALPHA * (0.34 + 0.66 * wilt) * (1.0 + GHOST_BEAT * beat) * fade,
			GHOST_WIDTH * unit)


## The sample: a vesicle circling the nucleus, with a thread out toward the
## nearest socket it has not managed to reach.
static func _draw_vesicle(canvas: CanvasItem, seat: Vector2, size: float,
		target: Vector2, reaching: bool, aft: Vector2, tone: Color, wilt: float,
		beat: float, clock: float, fade: float, unit: float) -> void:
	if size <= 0.0:
		return
	# Which way it is straining. With nowhere to go -- a full genome, where the
	# only way out is a swap on the strip -- there is no thread, and it leans
	# aft instead of at a socket: **the body's own aft, not the screen's down**,
	# so the shape is body-relative in full vision exactly as it is in point of
	# view, and the figure never says anything about which way north is.
	var out := (target - seat).normalized() if reaching else aft

	# The thread first, so the vesicle sits on top of its own reach.
	if reaching:
		var reach := THREAD_REACH * (0.55 + 0.45 * wilt) * (0.86 + 0.28 * beat)
		var to := seat.lerp(target, clampf(reach, 0.0, 1.0))
		var from := seat + out * _vesicle_edge(size, out, out.angle(), clock)
		if seat.distance_squared_to(to) > seat.distance_squared_to(from):
			# Bowed, not ruled. A dead straight line between two marks is a
			# leader line, which is the one piece of chart furniture this screen
			# must never grow; one control point off the chord makes it a
			# strand being pulled between them.
			var bow := (to - from).orthogonal() * THREAD_BOW
			canvas.draw_polyline(PackedVector2Array([
					from, from.lerp(to, 0.5) + bow, to]),
				Color(tone, THREAD_ALPHA * (0.30 + 0.70 * wilt) * fade),
				THREAD_WIDTH * unit, true)

	for k in VESICLE_HAZE_RINGS:
		var q := float(k) / float(VESICLE_HAZE_RINGS)
		canvas.draw_circle(seat,
			size * VESICLE_HAZE * (1.0 + VESICLE_HAZE_GROW * q),
			Color(tone, VESICLE_HAZE_ALPHA * (1.0 - q)
				* (0.40 + 0.60 * wilt) * fade), true, -1.0, true)
	# **Not a circle, and not a crest either.** A true circle at this size reads
	# as a widget; a single three-lobed wobble read as a shield. Two lobes under
	# five, drifting at unrelated rates, and the whole outline drawn out toward
	# whatever it is reaching for, is a small wet thing that is never the same
	# shape twice and never the same shape in two directions -- at the cost of
	# one more sine and one dot product.
	var ring := PackedVector2Array()
	var open := 1.0 - wilt
	for i in VESICLE_STEPS:
		var a0 := TAU * float(i) / float(VESICLE_STEPS)
		var a1 := TAU * float(i + 1) / float(VESICLE_STEPS)
		if _vesicle_torn((a0 + a1) * 0.5, open):
			continue
		ring.append(seat + Vector2(cos(a0), sin(a0))
			* _vesicle_edge(size, out, a0, clock))
		ring.append(seat + Vector2(cos(a1), sin(a1))
			* _vesicle_edge(size, out, a1, clock))
	_stroke(canvas, ring, tone, VESICLE_RING_ALPHA * (0.45 + 0.55 * wilt) * fade,
		VESICLE_WIDTH * unit)
	canvas.draw_circle(seat - out * (size * VESICLE_CORE_OFF), size * VESICLE_CORE,
		Color(tone, (0.42 + 0.34 * beat) * (0.35 + 0.65 * wilt) * fade),
		true, -1.0, true)


## How far the membrane is from [param seat] at angle [param a], given that the
## whole drop is being pulled toward [param out].
static func _vesicle_edge(size: float, out: Vector2, a: float,
		clock: float) -> float:
	var dir := Vector2(cos(a), sin(a))
	return size * (1.0 + VESICLE_WOBBLE * sin(a * 2.0 + clock * 0.9)
		+ VESICLE_WOBBLE_FINE * sin(a * 5.0 - clock * 1.4)
		- VESICLE_DRAWN * dir.dot(out))


## Whether the vesicle's own membrane is open at [param a]. The same one-at-a-
## time rule the body's tears use, so the two read as the same kind of damage.
static func _vesicle_torn(a: float, open: float) -> bool:
	for k in VESICLE_TEARS:
		var amount := clampf(open * float(VESICLE_TEARS) - float(k), 0.0, 1.0)
		if amount <= 0.0:
			continue
		var centre := TAU * float(k) / float(VESICLE_TEARS) + 0.6
		if absf(angle_difference(a, centre)) \
				< deg_to_rad(VESICLE_TEAR_DEG) * amount:
			return true
	return false


# ---------------------------------------------------------------------------
# Where the mouth is -- the one thing in this file the *simulation* asks.
#
# **The bow is not decoration.** Eating used to be a proximity test, `distance <
# a.radius + b.radius`, so a cell ate you by bumping you anywhere -- with its
# tail, with its flank, while swimming away from you -- and the art had spent
# the whole of §1.1.1 promising that the organ on the nose is the thing that
# eats. The water now asks this file where that organ actually is, rather than
# keeping a second copy of GAPE_SEAT, GAPE_BULGE and the span; two copies would
# drift, and the frame they drift is the frame the drawn mouth stops being the
# mouth that ate you.
#
# The rest of this file is drawing and reads nothing; these three functions read
# nothing either. Geometry is not a view.
# ---------------------------------------------------------------------------

## How far the bow can possibly reach from the body's own centre. A bound for
## the broad phase and nothing else: the farthest point of the bow is the apex
## or a lip tip, and this is comfortably above both.
static func mouth_reach(r: float, gape: float) -> float:
	return r * OVOID_ALONG * GAPE_SEAT + gape * (1.0 + GAPE_BULGE)


## Distance from [param body] to the nearest point of this cell's lip bow, in
## world units. The measurement the water runs both ways round: it is the same
## number whether the question is "can it eat me" or "can I eat it".
static func mouth_gap(at: Vector2, heading: float, r: float, gape: float,
		body: Vector2) -> float:
	var fwd := Vector2(sin(heading), -cos(heading))
	var stb := Vector2(cos(heading), sin(heading))
	var base := at + fwd * (r * OVOID_ALONG * GAPE_SEAT)
	var near := INF
	var last := _lip(base, fwd, stb, gape, -1.0)
	for i in range(1, MOUTH_STEPS + 1):
		var next := _lip(base, fwd, stb, gape,
			-1.0 + 2.0 * float(i) / float(MOUTH_STEPS))
		near = minf(near, _to_segment(body, last, next))
		last = next
	return near


## **Is that body in this mouth.** The whole of contact, in both directions.
##
## A body counts as in the mouth when its disc overlaps the bow -- so a cell is
## eaten by the organ that eats and not by the tail of the thing that owns it.
## The disc is the body's [member radius] and not its swallow radius: `pellicle`
## makes you harder to *get down*, not harder to reach.
static func mouth_touches(at: Vector2, heading: float, r: float, gape: float,
		body: Vector2, body_radius: float) -> bool:
	if gape <= 0.0:
		return false
	var slack := body_radius + gape * MOUTH_BITE
	var bound := mouth_reach(r, gape) + slack
	# The broad phase, and it is why this is affordable at 34 bodies squared.
	if at.distance_squared_to(body) > bound * bound:
		return false
	return mouth_gap(at, heading, r, gape, body) <= slack


## Distance from a point to a segment. Local because nothing else in the game
## has ever needed it.
static func _to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	var length := span.length_squared()
	if length <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(span) / length, 0.0, 1.0)
	return point.distance_to(a + span * t)


# ---------------------------------------------------------------------------
# The tile face (§5.3). The same shapes at 76 pixels, frozen: a mirror is
# something you consult, and a still one is easier to read than a live one.
# ---------------------------------------------------------------------------

## The organ on a genome tile: a dome of the gene's own strokes, so the tile and
## the body are one vocabulary. [param size] is the tile's own rect.
##
## [param alpha] is the second, weaker channel behind the pips: a gene the DNA
## carries and the body does not wear draws its strokes fainter. The pips do the
## work -- see normal_mode.gd's tile face -- and this is honest about which one
## is which.
## [param scale] shrinks the whole drawing about [param centre]. The strand has
## no 76px tile to put an organ in, so the one organ on the pause screen is the
## **selected** gene's, drawn once beside the sentence that explains it -- which
## is a smaller row than a tile and needs the geometry to come with it.
static func draw_tile_organ(canvas: CanvasItem, gene: StringName, tier: int,
		centre: Vector2, alpha: float = TILE_STROKE_ALPHA,
		scale: float = 1.0) -> void:
	var tone := hue(gene)
	var ink := alpha / TILE_STROKE_ALPHA
	var arc_r := TILE_ARC_RADIUS * scale
	canvas.draw_arc(centre, arc_r, TILE_ARC_FROM, TILE_ARC_TO, 32,
		Color(tone, TILE_ARC_ALPHA * ink), TILE_ARC_WIDTH * scale, true)

	var count := int(TILE_COUNT.get(gene,
		EARNED_COUNT.get(gene, TILE_COUNT_EARNED)))
	var length := float(TILE_LEN.get(gene, TILE_LEN_EARNED)) * scale
	var earned := not TILE_COUNT.has(gene)
	if earned:
		canvas.draw_circle(centre + Vector2(0.0, -arc_r * PIGMENT_SEAT),
			TILE_PIGMENT * scale, Color(tone, 0.85 * ink), true, -1.0, true)

	var strokes := PackedVector2Array()
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var angle := lerpf(TILE_ARC_FROM, TILE_ARC_TO, u)
		var dir := Vector2(cos(angle), sin(angle))
		var root := centre + dir * arc_r
		var span := length
		if gene == &"cytostome":
			# The same metachronal wave the body wears, held still at clock 0.
			span *= 0.80 + 0.30 * sin(u * CYTOSTOME_WAVE_U)
		elif gene == &"cirrus":
			span *= 0.86 + 0.22 * cos(u * CIRRUS_WAVE_U)
		elif gene == &"flagellum":
			span *= 0.82 + 0.26 * sin(u * FLAGELLUM_WAVE_U)
		else:
			span *= 0.88 + 0.14 * sin(u * PI)
		strokes.append(root)
		strokes.append(root + dir * span)
	_stroke(canvas, strokes, tone, alpha, TILE_ARC_WIDTH * scale)
	# Tier is drawn as rungs by the strand itself: at 13 pixels a 22% length
	# difference is one pixel, so magnitude cannot carry it here the way it does
	# on a body. This is the one place the two vocabularies deliberately differ,
	# and the tile says why -- it is a label, not an organism.


## **Which arc this slot is, drawn small.** A compass with one dart on it,
## pointing the way the locus looks -- screen up is the cell's front, exactly as
## every bearing in this game is read.
##
## It is on empty loci too, and that is the point: the player is choosing where
## to put a gene, so the empty ones are the part of the strand they are actually
## reading. Two forward diagonals and two rear ones look nothing alike here, and
## "placed behind, it does not let you see where you are going" becomes a thing
## you can see before you commit rather than after.
## [param centre] and [param radius] are given rather than taken from a tile
## corner, because the strand has no corners: the dart sits under its own locus,
## in the label row beside the plain word.
static func draw_slot_dart(canvas: CanvasItem, slot: int, tone: Color,
		centre: Vector2, radius: float = TILE_COMPASS_R) -> void:
	if slot < 0:
		return
	canvas.draw_arc(centre, radius, 0.0, TAU, 20, Color(tone, 0.28), 1.0, true)
	var bearing := slot_bearing(slot)
	var dir := Vector2(sin(bearing), -cos(bearing))
	var side := Vector2(-dir.y, dir.x)
	# **A dart, not a needle.** A needle was built first and it fails at exactly
	# the distinction this mark exists to make: forward-starboard and rear-port
	# are the same 45-degree line, so which end is the point has to be carried by
	# the shape and not by which end is brighter. Rendered at 13 pixels, a dot on
	# one end is not enough and a filled dart is unmistakable.
	var head := centre + dir * radius
	var tail := centre - dir * (radius * 0.55)
	canvas.draw_colored_polygon(PackedVector2Array([
		head,
		tail + side * (radius * 0.70),
		centre - dir * (radius * 0.10),
		tail - side * (radius * 0.70)]), Color(tone, 0.95))


# ---------------------------------------------------------------------------
# The strand (docs/design/dna-strand.md §1, docs/design/choosing.md §9.1)
#
# **Two surfaces draw this helix and there is one copy of it.** The pause
# screen draws it horizontally at a 32px lobe; the division's choosing screen
# draws it vertically, outboard of each daughter, at a 48px one. Everything
# between those two facts is identical -- the depth-per-point backbone, the
# filled lens, the three rung states -- so it lives here, beside
# [method draw_slot_dart] and [method draw_tile_organ], which are the strand's
# other furniture and were already shared for the same reason.
#
# It is here rather than in `normal_mode.gd` because the choosing screen is the
# second caller and a second copy is how two helixes drift apart. That is the
# failure diegetic-hud.md §2 avoided by making the vesicle one routine called
# from two views, and the pause strand is a surface two releases have been
# spent getting right.
#
# **The axis is an argument and nothing else is.** A vertical strand is the
# horizontal one with x and y exchanged: `along` runs down the strand and
# `across` is the swing, and [method strand_point] is the only place that knows
# which is which. The per-surface geometry -- lobe length, the axis's seat, the
# swing -- arrives as three floats, because those are the only numbers the two
# surfaces disagree about.
#
# Nothing here reads the simulation and nothing here writes it, which is this
# file's rule and is what lets the replay call the same routines later.
# ---------------------------------------------------------------------------

## Which way the strand runs. `ALONG_X` is the pause screen's row; `ALONG_Y` is
## the choosing screen's column.
const STRAND_ALONG_X := 0
const STRAND_ALONG_Y := 1

## The backbone is the cell's own teal, not a gene's hue: the strand is you and
## the rungs are what you are made of.
const STRAND_BACKBONE := Color(0.24, 0.80, 0.68)
## Depth, drawn as alpha along the strand. A helix that is two crossing sine
## waves is flat; the strand in front at a crossing is what makes it a helix,
## and per-point colours on a polyline cost nothing to say so.
const STRAND_FRONT := 0.66
const STRAND_BACK := 0.13
const STRAND_WIDTH := 2.0
## Segments per lobe. Ten over 32 px leaves a 0.2 px sagitta, and over 48 a
## 0.3 px one.
const STRAND_STEPS := 10

## Copies, along the strand. 8 px is 45 degrees of a 32px lobe, so the outer
## pair come out at 71% of the centre rung's length -- the cluster follows the
## lens, which is what a base pair near the edge of a turn actually does. At the
## choosing screen's 48px lobe the same 8 px is 30 degrees and the outer pair
## reach 87%: flatter, which is right at a smaller scale.
const STRAND_RUNG_GAP := 8.0
const STRAND_WORN_ALPHA := 0.92
const STRAND_WORN_WIDTH := 3.0
## A copy the DNA carries and the body does not wear: the rung does not reach
## either backbone. Floating against seated, which is diegetic-hud.md §1's own
## vocabulary -- rejected on a 76px tile because a 4px lift is invisible, and
## right here because the gap is a third of a rung.
const STRAND_CARRIED_ALPHA := 0.88
const STRAND_CARRIED_WIDTH := 2.6
const STRAND_CARRIED_SPAN := 0.42


## A point on the strand: [param along] runs down it and [param across] is the
## swing off its axis. The one place either surface's handedness is decided.
static func strand_point(axis: int, along: float, across: float) -> Vector2:
	return Vector2(along, across) if axis == STRAND_ALONG_X \
		else Vector2(across, along)


## Where the two strands are at [param along], for a control whose first
## half-lens is [param lobe0]. [param along] is in that control's own pixels and
## [param lobe] is how long one half-lens is.
static func strand_phase(along: float, lobe0: int, lobe: float) -> float:
	return PI * (float(lobe0) + along / lobe)


## How much of the strand a control draws at [param along]: 1 everywhere on a
## locus, ramping from nothing at the outer end of a cap. [param taper] is +1 at
## the head, -1 at the tail and 0 for a locus.
static func strand_fade(along: float, span: float, taper: int) -> float:
	if taper == 0:
		return 1.0
	var t := clampf(along / maxf(span, 0.001), 0.0, 1.0)
	return t if taper > 0 else 1.0 - t


## Two sine strands a half-period out of phase, drawn as polylines with a
## colour per point. **The colour per point is what makes it a helix**: depth is
## `cos(t)`, so the strand in front at a crossing is bright and the one behind
## it is faint, and they trade places every half turn. Two crossing sine waves
## at one alpha are flat and read as a ribbon, not as DNA -- rendered both ways.
##
## No new node, no texture, no shader: `draw_polyline_colors` is one call per
## strand per control.
static func draw_weave(canvas: CanvasItem, axis: int, lobe: float, mid: float,
		amp: float, lobes: int, lobe0: int, bright: float,
		taper: int) -> void:
	var span := float(lobes) * lobe
	var steps := lobes * STRAND_STEPS
	var a_pts := PackedVector2Array()
	var b_pts := PackedVector2Array()
	var a_col := PackedColorArray()
	var b_col := PackedColorArray()
	for i in steps + 1:
		var along := span * float(i) / float(steps)
		var t := strand_phase(along, lobe0, lobe)
		var fade := strand_fade(along, span, taper)
		var swing := amp * sin(t) * fade
		a_pts.append(strand_point(axis, along, mid - swing))
		b_pts.append(strand_point(axis, along, mid + swing))
		# depth runs -1 (behind) to 1 (in front); the two strands are opposite.
		var near := 0.5 * (cos(t) + 1.0)
		a_col.append(Color(STRAND_BACKBONE, lerpf(STRAND_BACK, STRAND_FRONT,
			near) * fade * bright))
		b_col.append(Color(STRAND_BACKBONE, lerpf(STRAND_FRONT, STRAND_BACK,
			near) * fade * bright))
	canvas.draw_polyline_colors(a_pts, a_col, STRAND_WIDTH, true)
	canvas.draw_polyline_colors(b_pts, b_col, STRAND_WIDTH, true)


## One lens of the weave, filled. Built from the same two strands, so the
## selection is exactly the shape of the thing being selected.
##
## [param lens_lobe] is which half-lens of the control to fill, counted from its
## own origin: the pause screen's locus is three lobes wide and fills its middle
## one, and the choosing screen's is one lobe and fills that.
static func draw_lens(canvas: CanvasItem, axis: int, lobe: float, mid: float,
		amp: float, lobe0: int, lens_lobe: float, tone: Color) -> void:
	var poly := PackedVector2Array()
	var back := PackedVector2Array()
	for i in STRAND_STEPS + 1:
		var along := lobe * (lens_lobe + float(i) / float(STRAND_STEPS))
		var swing := amp * sin(strand_phase(along, lobe0, lobe))
		poly.append(strand_point(axis, along, mid - swing))
		back.append(strand_point(axis, along, mid + swing))
	back.reverse()
	poly.append_array(back)
	canvas.draw_colored_polygon(poly, tone)


## **Copies, as rungs.** One, two or three of them at [param centre] along the
## strand, in the gene's own hue, and each in one of two states:
##
##   worn     a complete rung, backbone to backbone -- this body expresses it
##   carried  a bar floating clear of both -- the DNA has it, the body does not
##
## Worn against carried is **shape** and not hue, so it survives a
## luminance-only render and a deuteranope one, which is the rule
## genes-and-cilia.md §4.4 sets for any pair of marks whose opposites share a
## place.
##
## **The cluster is centred on the copies it has, not on three places with the
## empty ones ghosted.** The ghosts were built and photographed: at 1 px and 15%
## they were invisible, and paying for them cost a one-copy locus its centring --
## its single rung sat a third of a lens off the maximum and hung shorter than
## every other one-copy locus on the strand. Centred, a single copy is the
## longest rung the strand can draw, which is the right emphasis: it is the
## whole of that gene.
static func draw_rungs(canvas: CanvasItem, axis: int, lobe: float, mid: float,
		amp: float, lobe0: int, centre: float, tone: Color, tier: int,
		body_tier: int) -> void:
	var seat := (float(tier) - 1.0) * 0.5
	for i in tier:
		var along := centre + (float(i) - seat) * STRAND_RUNG_GAP
		var swing := absf(amp * sin(strand_phase(along, lobe0, lobe)))
		if i < body_tier:
			canvas.draw_line(strand_point(axis, along, mid - swing),
				strand_point(axis, along, mid + swing),
				Color(tone, STRAND_WORN_ALPHA), STRAND_WORN_WIDTH, true)
		else:
			var reach := swing * STRAND_CARRIED_SPAN
			canvas.draw_line(strand_point(axis, along, mid - reach),
				strand_point(axis, along, mid + reach),
				Color(tone, STRAND_CARRIED_ALPHA), STRAND_CARRIED_WIDTH, true)


# ---------------------------------------------------------------------------
# Small shared arithmetic
# ---------------------------------------------------------------------------

## Every stroke of one gene in a single call. `draw_multiline` takes point pairs
## and draws them disconnected, so a three-point cilium goes in as two segments
## and a whole arc collapses into one draw item -- which is why the fringe costs
## four calls a cell rather than eighty.
static func _stroke(canvas: CanvasItem, points: PackedVector2Array, tone: Color,
		alpha: float, width: float) -> void:
	if points.is_empty() or alpha <= 0.0:
		return
	canvas.draw_multiline(points, Color(tone, alpha), width, true)


## The unit tangent at [param t] that points toward the nose, which is the
## direction every swing in §4.2 is measured in.
## The outward normal turned [param angle] toward the nose. Every swing in §4.2
## is measured this way, so there is one definition of which way a cilium leans.
static func _swung(normal: Vector2, nose: Vector2, angle: float) -> Vector2:
	return (normal * cos(angle) + nose * sin(angle)).normalized()


static func _toward_nose(fwd: Vector2, stb: Vector2, t: float) -> Vector2:
	var n := _normal(fwd, stb, t)
	# Rotate the normal a quarter turn, in whichever sense reduces |t|. On the
	# starboard flank that is one way round and on the port flank the other, so
	# the two sides lean toward the same nose rather than mirroring each other
	# into a shape that has no front.
	return Vector2(n.y, -n.x) if wrapf(t, -PI, PI) >= 0.0 else Vector2(-n.y, n.x)


static func _tier(ladder: Array[float], tier: int) -> float:
	return ladder[clampi(tier, 0, ladder.size() - 1)]


static func _count(base: int, tier: int) -> int:
	return maxi(1, int(roundf(float(base) * _tier(TIER_COUNT, tier))))
