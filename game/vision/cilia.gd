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
## For the venom switch and nothing else. cilia -> genome -> cell already runs
## this way, and cell.gd preloads no view, so there is no cycle.
const CellBody := preload("res://game/normal/cell.gd")
## The kinds of load, by name and index. doses.gd preloads nothing.
const Doses := preload("res://game/mechanics/doses.gd")
## Every gene, in order: which forms deliver a dose. Preloads nothing of game/.
const Catalogue := preload("res://game/genes/catalogue.gd")
## **The body plan** (docs/design/gene-catalogue.md §10): every slot's arc and
## bearing, the home seats and the body's shape. It preloads nothing.
const BodyPlan := preload("res://game/genes/body_plan.gd")
## **The plan's home seats and arcs**, held as the looks are: its own containers,
## refilled in place whenever the plan changes, read for every body drawn.
static var _homes: Dictionary = BodyPlan.homes()
static var _home_slots: Array[int] = BodyPlan.home_slots()
static var _home_genes: Array[StringName] = BodyPlan.home_genes()
static var _plan_arcs: Array[Vector2] = BodyPlan.arcs()

# --- Palette: families (docs/design/gene-looks.md §1) -------------------------
# Colour shows the family, shape shows the organ, the pause screen names the exact
# gene (the owner, 2026-10-04). Five families, each a band of the wheel and a way of
# being built: an organ's hue is one of its family's three shades, and two organs of
# one family are told apart by their kind (`kinds.gd`), never by colour.

## **Gene identity, one hue used in four places**: the organ on your body, the
## organ on the cell that carries it, the ingest flood at the instant you eat it,
## and the slot on the genome strip. No legend, no lookup. **Each is its family's**
## (`families.gd`): the shade its organ file's look picks, worked out by the
## catalogue and read through its looks, which this file holds as its own ([member
## _looks]). So the hue says the family -- violet a sense, orange armed or plated,
## gold inside -- and the **kind** says the organ: a lens or forks, darts or plates,
## a solid body or a clear one. Measured in OKLCH and held by the gene probe, every
## band stays at least 30 degrees from self teal and threat red, because those two
## are the only colours in the game whose meaning is a relationship rather than a
## name (gene-looks.md §1.3).
static var _looks: Dictionary = Catalogue.looks()
## **Each key's hue and each key's shape** (the catalogue's `hues` and
## `shape_by_key`), and **the live keys of each shape** (its `shapes`), held as the
## looks are: what a body is drawn by, every organ, every body, every frame, each one
## read of a dictionary this file already has -- as the old tables were.
static var _hues: Dictionary = Catalogue.hues()
static var _shape_of: Dictionary = Catalogue.shape_by_key()
static var _shaped: Dictionary = Catalogue.shapes()
## The kinds this file draws by (`kinds.gd`; gene.gd).
const Kinds := Catalogue.Kinds
const MAT := Catalogue.MAT
const OARS := Catalogue.OARS
const LASH := Catalogue.LASH
const COIL := Catalogue.COIL
const TUFT := Catalogue.TUFT
const LENS := Catalogue.LENS
const SPINES := Catalogue.SPINES
const PLATES := Catalogue.PLATES
const ORGANELLE := Catalogue.ORGANELLE
## An empty look: what a gene this build does not know has -- a retired one has the
## catalogue's own empty look -- and no keys of a shape nothing is drawn as.
const NO_LOOK := {}
const NO_KEYS: Array[StringName] = []

## **No eye**: what every cell but the player's own passes to [method
## draw_cell], and the organ drawn as it always was. One shared, read-only
## dictionary rather than a fresh `{}` per organ per body per frame.
const NO_EYE := {}

## **A gene this build does not know** -- a later content's, arriving over an older
## binary, or a retired one that kept no look -- is drawn rather than dropped: **a
## plain tuft in this tint** (gene-looks.md §2.5). Pale, low in chroma and in no
## family, so an unknown gene is never passed off as a sense, a mover or a weapon --
## the indigo it used to take now sits inside the sensing band. A body with an
## invisible organ would be a body the player cannot read, which is worse than a body
## with an organ in no colour of its own.
const UNKNOWN_TINT := Color(0.78, 0.84, 0.82)
## That plain tuft: the tuft kind's defaults over a pigment, resolved once.
static var UNKNOWN_LOOK: Dictionary = _frozen(Kinds.resolved({"shape": Kinds.TUFT}))

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
## **The body's shape is the plan's** (`body_plan.gd`): a slot's bearing is read
## off it, so the curve drawn here and the curve a slot points along are one.
const OVOID_ALONG := BodyPlan.OVOID_ALONG
const OVOID_ACROSS := BodyPlan.OVOID_ACROSS
## How much narrower the nose is than the tail.
const OVOID_PINCH := BodyPlan.OVOID_PINCH
## A slow breath, so a body never looks like a drawn shape.
const BREATHE := 0.035

const BODY_FILL_ALPHA := 0.16
const BODY_RIM_ALPHA := 0.66
const BODY_RIM_WIDTH := 2.2

# --- A starving body goes slack (docs/design/hunger.md §2.3) -----------------
# A cell running out of fuel loses turgor, and its rim crumples into creases
# that deepen as the tank empties. **Inward only**: a starving cell really does
# shrink, and this one is never drawn smaller than its radius, for the reason
# the wound gives in [method _draw_ovoid]. The fill, the rim's ink and the
# nucleus do not change: a thinner fill was tried, and it cost the figure the
# glance it needs against the controls (controls.md §3.2).

## Nine creases round the rim. Odd, so the body never reads as a symmetric
## badge.
const SLACK_FOLDS := 9.0
## How deep a crease goes at full slack, as a share of the radius: 5.3 canvas
## px on the born point-of-view figure, 3.1 in full vision.
const SLACK_DEPTH := 0.12
## Narrow creases between broad lobes, rather than a sine's even ripple.
const SLACK_SHARP := 2.0
## Radians a second the creases wander, wet and slow, so a still body is not a
## drawn shape. A clock of 0 holds them still, as the pause screen's figure is.
const SLACK_DRIFT := 0.15
## Rim points while the body is slack. [constant OVOID_STEPS]' forty cannot
## draw nine folds; a smooth body keeps its forty.
const SLACK_STEPS := 96

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

# --- The arcs (§4.1), the body plan's ---------------------------------------
# In ovoid parameter t, degrees: 0 is the nose, +90 starboard, 180 aft. Every
# slot's arc is a row of the body plan (`body_plan.gd`, gene-catalogue.md §10):
# the nose, the starboard flank and the tail are the home organs', and the four
# diagonals are earned. The diagonals are also the bearing rose -- while empty
# they are visible gaps at roughly the four diagonals, which is a 45-degree
# reference read off the organism rather than painted over it.

## **The genome slot IS the arc.** Slot 0 is the anterior arc, 1 the lateral
## pair, 2 the posterior, and 3..6 the four diagonals -- two forward, two rear --
## as the body plan lays them. That is the whole of placement being a choice: the
## two-tap on the pause strip already lets the player pick which slot a gene goes
## into, and a directional gene reads its facing off the arc it landed on. A laser
## in slot 5 looks backwards and cannot show you where you are going.
##
## **The inside has no arc** (docs/design/dna-slots.md §2.2): nothing inside
## faces anywhere, so nothing inside is ever asked for one -- [method
## _draw_fringe] draws an inside form round the whole body, and an inside form
## never has a slot in a layout. No layout holds an index past the outside now
## ([method default_order] keeps every outside gene on an arc); one that did
## would land on the last earned arc, as it always has (`body_plan.gd`'s `arc`).
static func arc_for_slot(slot: int) -> Vector2:
	return BodyPlan.arc(slot)


## The body-relative bearing an arc looks along: radians clockwise from the
## front, which is the only way this game is allowed to describe a direction --
## the body plan's, read off the ovoid this file draws.
static func arc_bearing(arc: Vector2) -> float:
	return BodyPlan.arc_bearing(arc)


## Where a gene in [param slot] points. The one call a directional gene makes.
static func slot_bearing(slot: int) -> float:
	return BodyPlan.bearing(slot)


# --- Geometry, at tier 1 (§4.2) ---------------------------------------------
# All lengths are fractions of the body radius, so a grown cell is not a small
# cell with stubble. **Nothing is clamped for small bodies**: on an r13-21
# drifter a tier-1 fringe really is a 4px stub, and the render says that is the
# useful division rather than a defect -- at drifter size the tier stops being
# readable and the gape does not, which is the right way round, because the
# gape is what decides the encounter and the tier is only how it got that way.

## **The home organs' counts and lengths are their kinds' defaults** (`kinds.gd`:
## the mat's 15 strokes of 0.27, the oars' 5 of 0.34 with a knee at 0.62 bent 34
## degrees, the lash's 6 of 0.62 swinging 0.26), so a born body draws exactly what
## it drew before there were kinds. What stays here is each kind's ink and width,
## and its beat. An earned stroke's length, a tuft's, is the tile's measure.
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
## **The cirrus leans with the steer**: the outboard side of the turn works
## harder. A motion cue, not a still-frame cue -- it does not show in a
## screenshot and is not claimed to.
const CIRRUS_STEER_BIAS := 0.55

const FLAGELLUM_POINTS := 6
const FLAGELLUM_WAVE_V := 3.0
const FLAGELLUM_WAVE_HZ := 5.2
const FLAGELLUM_WAVE_U := 0.45
## **A tail held still is drawn still** (docs/design/automation.md §8.1): its
## wave stops travelling and its lash goes slack over this many seconds, and
## comes back as fast when it is let go -- so a held tail reads as a body at
## rest in a still frame as well as in motion, and the wave stops where it was
## rather than snapping to a pose. Everything else on the body keeps its clock.
const TAIL_SETTLE := 0.3
## How much of its lash a tail held still keeps: a slack curve, not a rod.
const TAIL_HELD_LASH := 0.3
## [method draw_cell]'s tail when it is the body's own: drawn on the body's clock,
## beating, as every tail in the water is.
const NO_TAIL := Vector2(NAN, 0.0)

## The pigment organelle an earned gene carries, at the middle of its arc.
const PIGMENT_SEAT := 0.80
const PIGMENT_OUTER := 0.20
const PIGMENT_INNER := 0.10
const PIGMENT_HAZE := 0.30
## The organelle's two inks, rim and core. The core is what "drawn solid" fills
## the whole disc with, at the top of a flare.
const PIGMENT_RIM_ALPHA := 0.55
const PIGMENT_CORE_ALPHA := 0.85

# --- The eye: a choice waiting, and a level arriving (beam-levels.md §8.4-§8.5)
# Drawn on the player's own body only, because only the player's own level is
# known -- nothing about another cell's is on the wire (§6). See [param eye] on
# [method draw_cell].

## **A choice waiting: the eyespot doubles**, like an organelle about to divide.
## Two lobes of this size in place of the one disc, their cores half that, side
## by side along the arc -- and further apart the longer the fork is left, up
## to [constant BUD_BANKED_MAX] banked levels. It says *changed* by shape rather
## than by loudness: measured at σ 6 in point of view, 1280x720, the eye at rest
## reads 55 and budding 56, 59 at its brightest -- under dread's 60 and a beam
## return's 67. The design's mock put a ±0.3 shimmer at 60.9, a dead heat with
## dread, which is why it is 0.2.
const BUD_R := 0.15               ## of r, each lobe
const BUD_CORE := 0.075           ## of r
const BUD_APART := 0.10           ## of r, each lobe from the seat, at the fork
const BUD_APART_PER_LEVEL := 0.02 ## of r, more for every level banked since
const BUD_BANKED_MAX := 4
## The pigment's own ink, a little stronger for being two.
const BUD_INK := 1.2
## The lobes shimmer in antiphase, on the body's own clock.
const BUD_SHIMMER := 0.2
const BUD_SHIMMER_PERIOD := 2.4

## **A level arriving: the eyespot flares** for about a second. At the top the
## pigment is drawn solid, the whole organ is this much brighter, its haze this
## much wider and denser and its bristles this much longer. Measured at the
## peak, the same way, it reads 82 against the resting eye's 55: a clear
## flicker on your own body, above a beam return for a second and far under a
## taste band's 136. The mock's first cut, ink x 2, reached 111 -- a flash, not
## a feeling.
const FLARE_INK := 1.35
const FLARE_HAZE_WIDE := 1.5
const FLARE_HAZE_DENSE := 2.0
const FLARE_REACH := 1.30

# --- The toxin's two forms (docs/design/dna-slots-ux.md §2) -----------------
# **The colour is the family, the bead is the strain, the shape is where it
# works** (docs/design/gene-looks.md §2.1, §3.3). The toxin is one kind, `spines`
# with bead heads, in three places: at the front, fangs on the lips; on a side or
# the stern, barbs out of that arc; inside, its beads alone, granules under the
# whole skin and nothing at any one arc. A full-vision player tells the three
# apart at a glance and with no colour. The numbers below are the three places'.

## **Venom at the front is fangs on the lips.** It rides on the bite, so it is
## drawn on the organ every encounter is read off: barbs standing out of the lip
## bow's two corners, splayed away from the centreline, a bead at each tip --
## where the threat bow's teeth point in. One pair per copy, evenly from
## [constant FANG_FROM] to [constant FANG_TO] of the bow's half-span. On the
## lips whichever front slot holds it: at full vision's true size a
## forward-diagonal venom drawn at its own arc was a lime smudge beside the mouth.
const FANG_FROM := 0.50
const FANG_TO := 0.96
## Degrees further out than the bow's normal.
const FANG_SPLAY := 28.0
## Of the gape, x TIER_LEN[copies], and never under [constant FANG_MIN] canvas px.
const FANG_LEN := 0.24
const FANG_MIN := 5.0
const FANG_WIDTH := 1.9
const FANG_ALPHA := 0.95
## Of the gape, and never under [constant BEAD_MIN] canvas px.
const FANG_BEAD := 0.06

## **Venom on a side or the stern is barbs on that arc.** It stings the mouth
## that bites there, so it is drawn on the side it guards: beaded barbs standing
## out of the slot's arc, fanned -- the extrusomes a real ciliate fires where it
## is touched. Two a copy, evenly across the arc's middle: one arc has no left
## and right, and two is the fewest that read as a row of points rather than one
## bristle. No haze and no pigment -- an organ has both, and this is a weapon.
## Of the arc left bare at each end.
const GUARD_FROM := 0.15
## Of r past the skin, x TIER_LEN[copies], and never under
## [constant GUARD_MIN] canvas px.
const GUARD_LEN := 0.26
const GUARD_MIN := 5.0
## Degrees either side of the normal, at the end barbs.
const GUARD_FAN := 16.0
const GUARD_WIDTH := 1.9
const GUARD_ALPHA := 0.95
## Of r, and never under [constant BEAD_MIN] canvas px.
const GUARD_BEAD := 0.055

## **Poison is granules, and no arc.** Inside has no arc, so poison draws no
## pigment and no haze at any one place: only its granules, scattered just inside
## the rim round the whole body, the mouth's arc left clear. Defensive ciliates
## keep their toxins in cortical granules under the whole skin (Blepharisma,
## Stentor). Degrees either side of the nose left clear.
const GRANULE_FROM := 74.0
## x TIER_COUNT[copies]: 12, 16, 20.
const GRANULE_COUNT := 12
## Of r, jittered by `0.07 sin(2.3 i + 1.1) - 0.02` so they sit at different
## depths, and spread `0.38 sin(3.7 i)` of one step along the rim: scattered,
## never strung -- a necklace of even beads read as an ornament.
const GRANULE_SEAT := 0.84
const GRANULE_SPREAD := 0.38
## Of r, and never under 1.5 canvas px.
const GRANULE_R := 0.045
const GRANULE_MIN := 1.5
const GRANULE_ALPHA := 0.80

## The fangs' and the barbs' smallest bead, in canvas px.
const BEAD_MIN := 1.4

## **A toxin at work flares** (dna-slots-ux.md §5.1): your fangs as your venom
## lands, your barbs as a mouth bites the side they guard, your granules as your
## poison is taken. On the eye flare's envelope, which the caller runs: the
## fangs and barbs this much longer, every bead this much bigger and the organ
## this much brighter, with a three-ring haze round each bead.
const TOXIN_FLARE_LONG := 0.35
const TOXIN_FLARE_BEAD := 0.5
const TOXIN_FLARE_INK := 0.6
## The poison's granules carry more of the flare as ink: they have no length.
const GRANULE_FLARE_INK := 0.6

# --- A body carrying a load (docs/design/dna-slots-ux.md §4) -----------------
# **A load is drawn inside the body that carries it**, by this one routine, for
# every body, in both views and the replay: a stain in the strain's hue whose
# outline is its kind, and for harm pits in the rim. No rhythm: a hurt that goes
# on churns, because a pulse at about a second is what hunger's racing beat
# looks like.

## Felt stacks (doses.gd's `felt`) at which harm's marks are drawn whole.
## Square-rooted, so one stack already shows at half.
const HARM_FULL := 4.0
## **The stain**: a lumpy pool, not a disc -- three soft stacked rings read as
## three glowing organelles, which is the pigment's own construction saying the
## wrong thing; a pool reads as something spilled inside the cell. Three nested
## layers of [constant STAIN_STEPS] points at these scales, of
## `r x STAIN_R x lerp(STAIN_MIN, 1, h)`.
const STAIN_R := 0.58
const STAIN_MIN := 0.62
const STAIN_SCALES: Array[float] = [1.28, 1.0, 0.58]
## Each layer's share of `STAIN_ALPHA x h x marks`.
const STAIN_INKS: Array[float] = [0.35, 1.0, 1.0]
const STAIN_ALPHA := 0.40
const STAIN_STEPS := 36
## Seated this far aft of the middle, and drifting this far round it.
const STAIN_AFT := 0.10
const STAIN_WANDER := 0.16
## Radians a second: wet and slow.
const STAIN_DRIFT := 0.13
## Along the heading and across it: a pool lying in the body, not a coin on it.
const STAIN_ALONG := 1.1
const STAIN_ACROSS := 0.9
## **A new dose seeps in from where it came**: the stain grows from this share of
## its size, at the skin on the arrival's bearing, to its seat, over
## [constant SEEP] seconds (§5.1).
const SEEP := 0.8
const SEEP_FROM := 0.30
const SEEP_SKIN := 0.80

## **Harm's pits**: its own damage, in the rim. Up to three gaps, `ceil(3h)` of
## them live, that open and close and wander where they please, their lips lit
## in the strain's hue and a curl of eaten membrane hanging into each. A wound's
## tears are still, untinted and flapped; these move, glow and close -- a body
## being eaten now and a body bitten once are two different pictures.
const PITS := 3
## Half-width of a pit at its widest, and of the lit lip either side of it, in
## ovoid parameter degrees.
const PIT_DEG := 13.0
const PIT_LIP_DEG := 12.0
const PIT_LIP_ALPHA := 0.95
const PIT_LIP_WIDTH := 1.3       ## x BODY_RIM_WIDTH
## How far the curl of eaten membrane hangs in, as a share of the radius.
const PIT_CURL := 0.16
## Rim points while pitted. Forty cannot hold a 13-degree gap, and the rim is
## drawn in runs rather than per segment: per-segment strokes beaded the rim.
const PITTED_STEPS := 120

## **No dose**: what every body carrying nothing passes to [method draw_cell].
## One shared, read-only dictionary, as [constant NO_EYE] is.
const NO_DOSE := {}

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

## An earned stroke's length on a tile, 0.30 of a radius at the tile's scale: what
## the tile's px per body radius are measured by ([constant TILE_PER_R]).
const TILE_LEN_EARNED := 11.0
## An inside form's tile: its granules, on an arc this far outside the dome.
const TILE_GRANULES := 7
const TILE_GRANULE_OUT := 4.5
const TILE_GRANULE_R := 1.45
## The slot compass, in the tile's own pixels.
const TILE_COMPASS_X := 12.0
const TILE_COMPASS_Y := 13.0
const TILE_COMPASS_R := 6.5


# ---------------------------------------------------------------------------
# What a gene looks like. Asked by the body, by the tile, by the ingest flood
# and by the held-sample disc -- one answer to all four.
# ---------------------------------------------------------------------------

## **The hue of one gene: its family's**, at the shade its look picks. An unknown
## gene -- a later phase's, arriving over an older binary in a content pack -- or a
## retired one with no look takes [constant UNKNOWN_TINT] rather than drawing as
## nothing.
static func hue(gene: StringName) -> Color:
	return _hues.get(gene, UNKNOWN_TINT)


## **The hue of the organ that provides [param stat]** -- the first, where several
## do: what a mechanic's own marks are drawn in -- a pad's glyph, a part's chip --
## without naming the organ.
static func hue_for(stat: StringName) -> Color:
	return hue(Catalogue.first_provider(stat))


## **The hue of the organ that drives membrane [param channel]** -- the first, where
## several do: what that sense's marks are drawn in, the beam's rays and the ping's
## wave, and the hue its glow lobe is (signal_bus.gd reads the same organ).
static func hue_on(channel: StringName) -> Color:
	return hue(Catalogue.first_on(channel))



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

## Draws one cell, whole: body, nucleus, the fringe on every arc and the gape.
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
##
## [param untinted] keeps the body pure `SELF_TINT` **without** [param is_self]'s
## other half, so the threat bow can still show. It is for another player in the
## same water: a person, so never a gene tint -- no cell the water makes is
## untinted -- but a mouth that can reach you, so a threat when their gape
## exceeds your radius. shared-pond-ux.md §0.1 and §8.
##
## [param eye] is **one organ's pigment, about to change or just changed**
## (beam-levels.md §8.4-§8.5): `{"gene": g, "bud": n, "flare": f}`, or empty.
## `bud` is how many levels have banked at an open fork -- the pigment doubles,
## and the lobes sit further apart the higher it is -- or -1 for no fork; `flare`
## is 0..1, a level arriving. Passed **only for the player's own cell**, the
## way [method draw_pending] takes `offer`: no other cell's level is known, and
## a friend's is not on the wire. Empty draws exactly what it always drew.
##
## [param tail] is **the tail's own clock**, `(clock, still)` as [method
## step_tail] keeps it: the clock its wave is drawn on, and 0 beating to 1 held
## still (automation.md §8.1). Passed only for the player's own body, whose hold
## is known; [constant NO_TAIL] draws it on [param clock], beating.
##
## [param slack] is 0..1, **how far this body has gone slack with hunger**
## (docs/design/hunger.md): the rim crumples inward into [constant SLACK_FOLDS]
## creases. Passed only for the player's own body, as [param eye] is: hunger is
## each player's own and is not on the wire, so a friend is never drawn
## crumpled, and nothing in the water is either.
##
## [param dose] is **what this body carries, and what its toxins are doing**
## (docs/design/dna-slots-ux.md §4, §5), or [constant NO_DOSE]. Every body
## passes its loads, in both views and the replay, as `"felt"`:
## `Vector3(harm, paralysis, sleep)` in **felt stacks** -- doses.gd's `felt`,
## already diluted by the body's own size, because a drawing's radius is canvas
## px and not the body's. The player's own body adds `"fade"`, the marks' own
## fade where the figure has a licence to be louder than itself (soma.gd's
## FADE_DOSE); `"entry"`, `Vector2(bearing, seconds)` of the newest dose while it
## seeps in from the skin; and the three flares, `"fangs"`, `"guard"` and
## `"granules"`, 0..1, as its toxins fire. Phase 1 draws harm; the other two
## kinds are laid out for the strains that will deliver them.
static func draw_cell(canvas: CanvasItem, at: Vector2, heading: float,
		r: float, tiers: Dictionary, gape: float, viewer_radius: float,
		is_self: bool, clock: float, fade: float = 1.0, steer: float = 0.0,
		beat: float = 0.0, phase: float = 0.0, unit: float = 1.0,
		order: Array = [], wound: float = 0.0, double: float = 0.0,
		pinch: float = 0.0, shed: float = 0.0, untinted: bool = false,
		eye: Dictionary = NO_EYE, tail: Vector2 = NO_TAIL,
		slack: float = 0.0, dose: Dictionary = NO_DOSE) -> void:
	if fade <= 0.0 or r <= 0.0:
		return
	var fwd := Vector2(sin(heading), -cos(heading))
	var stb := Vector2(cos(heading), sin(heading))
	var tint := body_tint(tiers, is_self or untinted)
	if shed > 0.0:
		tint = tint.lerp(body_tint(tiers, false), clampf(shed, 0.0, 1.0))
	# What each load does to the drawing, 0..1, and the fade its marks are drawn
	# at. Nothing at all for a body that carries nothing, which is nearly all.
	var harm := 0.0
	var marks := fade
	if not dose.is_empty():
		var felt: Vector3 = dose.get("felt", Vector3.ZERO)
		harm = sqrt(clampf(felt.x / HARM_FULL, 0.0, 1.0))
		marks = float(dose.get("fade", fade))

	_draw_ovoid(canvas, at, fwd, stb, r, tint, clock, fade, phase, unit, wound,
		pinch, slack, harm, marks)
	_draw_nucleus(canvas, at, fwd, r, tint, beat, fade, double)
	if harm > 0.0:
		_draw_stain(canvas, at, fwd, stb, r, dose_hue(Doses.Kind.HARM), harm,
			clock, phase, marks, dose.get("entry", Vector2(0.0, INF)))
	# The layout once, for the fringe and the lips both: where a venom is worn
	# decides which of them draws it.
	var layout := order if not order.is_empty() else default_order(tiers)
	_draw_fringe(canvas, at, fwd, stb, r, tiers, clock, fade, steer, unit, layout,
		eye, tail, dose)
	var mouth := Catalogue.worn_provider(tiers, &"gape")
	draw_gape(canvas, at, fwd, stb, r, gape, mouth, int(tiers.get(mouth, 0)),
		not is_self and gape > viewer_radius, fade, unit)
	# **Venom at the front is on the lips**, drawn after them: a bite-riding organ
	# (a look's `lips`) worn in a front slot, or worn nowhere, rides on the bite
	# (food.gd's `toxins_of` reads the same layout the same way). A body with no
	# mouth draws none.
	if gape <= 0.0:
		return
	for gene: StringName in tiers:
		if not bool(_look_of(gene).get("lips", false)) or Genome.is_inside_form(gene):
			continue
		var tier := int(tiers[gene])
		var worn := layout.find(gene)
		if tier > 0 and (worn < 0 or Genome.is_front(worn)):
			_draw_fangs(canvas, at, fwd, stb, r, gape, gene, tier, fade, unit,
				float(dose.get("fangs", 0.0)))


## **The hue a load of [param kind] is drawn in**: the hue of the organ that
## delivered it (docs/design/gene-looks.md §3.3) -- the toxin's orange for harm, the
## first live form's that delivers it, as signal_bus.gd's STRAIN_COLORS reads it.
## Every strain of one organ wears its organ's colour, so the kinds of load are
## told apart by their marks -- a roiling lump, a still shard, a swelling haze --
## which never needed the hue. A kind no form delivers yet takes
## [constant UNKNOWN_TINT], as an unknown gene does, rather than drawing as nothing.
static func dose_hue(kind: int) -> Color:
	for form: StringName in Catalogue.live():
		var strain := Genome.strain_of(form)
		if strain != &"" and Doses.kind_of(strain) == kind:
			return hue(form)
	return UNKNOWN_TINT


## The body: an ovoid, narrower at the front, so the cell has a nose even before
## the heading needle is read -- and, once something has been biting it, a rim
## with holes in it; once it is starving, a rim with creases in it; while harm
## is in it, a rim with pits in it ([param harm] 0..1, its marks drawn at
## [param marks]).
static func _draw_ovoid(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, tint: Color, clock: float, fade: float,
		phase: float, unit: float, wound: float = 0.0,
		pinch: float = 0.0, slack: float = 0.0, harm: float = 0.0,
		marks: float = 1.0) -> void:
	var limp := clampf(slack, 0.0, 1.0)
	if harm > 0.0:
		_draw_ovoid_pitted(canvas, at, fwd, stb, r, tint, clock, fade, phase,
			unit, wound, pinch, limp, harm, marks)
		return
	var steps := OVOID_STEPS if limp <= 0.0 else SLACK_STEPS
	var body := PackedVector2Array()
	body.resize(steps)
	var squeeze := clampf(pinch, 0.0, 1.0)
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var breathe := 1.0 + BREATHE * sin(t * 3.0 + clock * 1.7 + phase)
		body[i] = _surface(at, fwd, stb,
			r * breathe * _crease(t, phase, clock, limp), t, squeeze)

	# **The body is not drawn smaller.** The radius is what decides every
	# encounter in the water, so a wounded cell that looked smaller would be
	# lying about the one number that matters. It holds less instead. A
	# starving one creases inward and keeps its extent, for the same reason.
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
	for i in steps:
		var t := TAU * (float(i) + 0.5) / float(steps)
		if _tear_at(t, phase, hurt) <= 0.0:
			rim.append(body[i])
			rim.append(body[(i + 1) % steps])
	_stroke(canvas, rim, tint, ink, BODY_RIM_WIDTH * unit)

	# A flap of membrane hanging into each tear, so a gap reads as a hole in a
	# body rather than as a dashed line. Rooted on the creased rim, not the
	# full one: a starving, bitten body's flaps would otherwise hang outside it.
	for k in WOUND_TEARS:
		var open := clampf(hurt * float(WOUND_TEARS) - float(k), 0.0, 1.0)
		if open <= 0.0:
			continue
		var t := _tear_seat(phase, k)
		var edge := _surface(at, fwd, stb, r * _crease(t, phase, clock, limp), t)
		flaps.append(edge)
		flaps.append(edge + (at - edge).normalized() * (r * WOUND_GASH * open))
	_stroke(canvas, flaps, tint, ink, BODY_RIM_WIDTH * unit)


## **How far the rim has fallen in** at ovoid parameter [param t], as a share
## of the radius: 1 everywhere on a body that is not slack, and down to
## `1 - SLACK_DEPTH` at the bottom of a crease on one that is [param limp] 1.
## The creases sit off [param phase], which is already the per-cell number the
## breath and the tears use, and wander on [param clock].
static func _crease(t: float, phase: float, clock: float, limp: float) -> float:
	if limp <= 0.0:
		return 1.0
	return 1.0 - SLACK_DEPTH * limp * pow(0.5 + 0.5 * cos(t * SLACK_FOLDS
		+ phase * 3.0 + clock * SLACK_DRIFT), SLACK_SHARP)


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


## How far open pit [param k] is, 0..1, on a body whose harm is [param harm]
## (dna-slots-ux.md §4.1): `ceil(3h)` of them live, each opening and closing on
## its own clock, never in step.
static func _pit_open(k: int, clock: float, phase: float, harm: float) -> float:
	if float(k) >= ceilf(harm * float(PITS)):
		return 0.0
	var s := sin(clock * (1.3 + 0.23 * float(k)) + 1.7 * float(k) + phase)
	return clampf(s, 0.0, 1.0) * clampf(1.4 * harm, 0.35, 1.0)


## Where pit [param k] sits, in ovoid parameter radians: it wanders round the
## body, each pit at its own rate.
static func _pit_seat(k: int, clock: float, phase: float) -> float:
	return 2.3 * phase + 2.1 * float(k) + clock * (0.21 + 0.07 * float(k))


## The rim's segments, by what each one is.
const _RIM := 0
const _GAP := 1
const _LIP := 2


## **The body with harm in it**: the ovoid of [method _draw_ovoid], creased and
## torn as that one is, with harm's pits in the rim -- each a gap with its lips
## lit in the strain's hue and a curl of eaten membrane hanging into it. The rim
## is drawn in **runs**, one polyline for each stretch of one kind, so it stays
## one stroke between its gaps.
static func _draw_ovoid_pitted(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, tint: Color, clock: float, fade: float,
		phase: float, unit: float, wound: float, pinch: float, limp: float,
		harm: float, marks: float) -> void:
	var n := PITTED_STEPS
	var squeeze := clampf(pinch, 0.0, 1.0)
	var body := PackedVector2Array()
	body.resize(n)
	for i in n:
		var t := TAU * float(i) / float(n)
		var breathe := 1.0 + BREATHE * sin(t * 3.0 + clock * 1.7 + phase)
		body[i] = _surface(at, fwd, stb,
			r * breathe * _crease(t, phase, clock, limp), t, squeeze)
	var hurt := clampf(wound, 0.0, 1.0)
	canvas.draw_colored_polygon(body,
		Color(tint, BODY_FILL_ALPHA * (1.0 - WOUND_FILL * hurt) * fade))

	var open: Array[float] = []
	var seats: Array[float] = []
	for k in PITS:
		open.append(_pit_open(k, clock, phase, harm))
		seats.append(_pit_seat(k, clock, phase))
	var kinds := PackedByteArray()
	kinds.resize(n)
	var lip_open := PackedFloat32Array()
	lip_open.resize(n)
	for i in n:
		var t := TAU * (float(i) + 0.5) / float(n)
		kinds[i] = _RIM
		if hurt > 0.0 and _tear_at(t, phase, hurt) > 0.0:
			kinds[i] = _GAP
			continue
		for k in PITS:
			if open[k] <= 0.0:
				continue
			var off := absf(angle_difference(t, seats[k]))
			var half := deg_to_rad(PIT_DEG) * open[k]
			if off < half:
				kinds[i] = _GAP
				break
			if off < half + deg_to_rad(PIT_LIP_DEG):
				kinds[i] = _LIP
				lip_open[i] = maxf(lip_open[i], open[k])
	var tone := dose_hue(Doses.Kind.HARM)
	var ink := BODY_RIM_ALPHA * (1.0 - WOUND_DIM * hurt) * fade
	_draw_rim_runs(canvas, body, kinds, lip_open, tint, ink, tone, marks, unit)

	# A curl of eaten membrane into each pit, in the strain's hue: the wound's
	# own flap, lit, so a pit reads as damage being done and not as a gap.
	var curls := PackedVector2Array()
	var curl_ink := 0.0
	for k in PITS:
		if open[k] <= 0.05:
			continue
		var edge := _surface(at, fwd, stb, r * _crease(seats[k], phase, clock, limp),
			seats[k], squeeze)
		curls.append(edge)
		curls.append(edge + (at - edge).normalized() * (r * PIT_CURL * open[k]))
		curl_ink = maxf(curl_ink, open[k])
	_stroke(canvas, curls, tone,
		PIT_LIP_ALPHA * clampf(0.4 + curl_ink, 0.0, 1.0) * marks,
		BODY_RIM_WIDTH * unit)
	if hurt <= 0.0:
		return
	# The wound's flaps, exactly as [method _draw_ovoid] hangs them.
	var flaps := PackedVector2Array()
	for k in WOUND_TEARS:
		var gash := clampf(hurt * float(WOUND_TEARS) - float(k), 0.0, 1.0)
		if gash <= 0.0:
			continue
		var t := _tear_seat(phase, k)
		var edge := _surface(at, fwd, stb, r * _crease(t, phase, clock, limp), t)
		flaps.append(edge)
		flaps.append(edge + (at - edge).normalized() * (r * WOUND_GASH * gash))
	_stroke(canvas, flaps, tint, ink, BODY_RIM_WIDTH * unit)


## The closed rim [param body], segment `i` running from point `i` to `i + 1`,
## drawn in runs by [param kinds]: rim in the body's [param tint], lips in the
## strain's [param tone], gaps not at all. Started at a change of kind, so no run
## is cut in two at the seam.
static func _draw_rim_runs(canvas: CanvasItem, body: PackedVector2Array,
		kinds: PackedByteArray, lip_open: PackedFloat32Array, tint: Color,
		ink: float, tone: Color, marks: float, unit: float) -> void:
	var n := body.size()
	var start := 0
	for i in n:
		if kinds[i] != kinds[(i + n - 1) % n]:
			start = i
			break
	var run := PackedVector2Array()
	var run_kind := int(kinds[start])
	var run_open := 0.0
	for j in n + 1:
		var i := (start + j) % n
		var kind := int(kinds[i]) if j < n else -1
		if kind != run_kind:
			if run.size() >= 2 and run_kind == _RIM:
				canvas.draw_polyline(run, Color(tint, ink), BODY_RIM_WIDTH * unit,
					true)
			elif run.size() >= 2 and run_kind == _LIP:
				canvas.draw_polyline(run, Color(tone, PIT_LIP_ALPHA
					* clampf(0.4 + run_open, 0.0, 1.0) * marks),
					BODY_RIM_WIDTH * PIT_LIP_WIDTH * unit, true)
			run = PackedVector2Array()
			run_kind = kind
			run_open = 0.0
		if j == n or kind == _GAP:
			continue
		if run.is_empty():
			run.append(body[i])
		run.append(body[(i + 1) % n])
		run_open = maxf(run_open, lip_open[i])


## **The stain**: harm in the body, a lumpy pool of the strain's [param tone],
## [param h] 0..1, off the body's middle -- its outline three incommensurate
## ripples, so it roils and is never the same shape twice: liquid inside the
## cell, not an organelle (dna-slots-ux.md §4). Drawn after the nucleus and
## before the fringe, so organs stay on top.
##
## [param entry] is `Vector2(bearing, seconds)` of the newest dose: for its
## first [constant SEEP] seconds the stain grows from the skin on that bearing
## to its seat (§5.1). Any other age draws the stain where it lives.
static func _draw_stain(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, tone: Color, h: float, clock: float, phase: float,
		marks: float, entry: Vector2) -> void:
	var size := r * STAIN_R * lerpf(STAIN_MIN, 1.0, h)
	var drift := phase * 1.3 + clock * STAIN_DRIFT
	var seat := at - fwd * (r * STAIN_AFT) \
		+ (fwd * cos(drift) * 0.9 + stb * sin(drift) * 0.7) * (r * STAIN_WANDER)
	if entry.y >= 0.0 and entry.y < SEEP:
		var u := smoothstep(0.0, SEEP, entry.y)
		var skin := at + (fwd * cos(entry.x) + stb * sin(entry.x)) * (r * SEEP_SKIN)
		seat = skin.lerp(seat, u)
		size *= lerpf(SEEP_FROM, 1.0, u)
	for layer in STAIN_SCALES.size():
		var reach := size * STAIN_SCALES[layer]
		var pool := PackedVector2Array()
		pool.resize(STAIN_STEPS)
		for i in STAIN_STEPS:
			var a := TAU * float(i) / float(STAIN_STEPS)
			# It roils, and never in step: a hurt that goes on is a churn, not a
			# rhythm -- a rhythm here would be read as hunger's racing beat.
			var edge := reach * (1.0
				+ 0.20 * sin(2.0 * a + phase + 0.9 * clock)
				+ 0.13 * sin(5.0 * a - 1.7 * phase - 1.7 * clock)
				+ 0.07 * sin(9.0 * a + 2.3 * phase + 2.9 * clock))
			pool[i] = seat + (fwd * (cos(a) * STAIN_ALONG)
				+ stb * (sin(a) * STAIN_ACROSS)) * edge
		canvas.draw_colored_polygon(pool, Color(tone,
			minf(STAIN_ALPHA * STAIN_INKS[layer] * h * marks, 1.0)))


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


## **A point on the skin**, at ovoid parameter [param t] -- radians, 0 the nose
## and +PI/2 starboard, the parameter every arc in this file is written in --
## pushed [param lift] out along the analytic normal. For a caller that has to
## meet a body exactly without drawing one: the pause screen's tethers end here
## and the arc it lights is traced here (dna-body.md §2). One curve, so the
## mark and the fringe it sits beside cannot drift apart.
static func skin_point(at: Vector2, heading: float, r: float, t: float,
		lift: float = 0.0) -> Vector2:
	var fwd := Vector2(sin(heading), -cos(heading))
	var stb := Vector2(cos(heading), sin(heading))
	return _surface(at, fwd, stb, r, t) + _normal(fwd, stb, t) * lift


# ---------------------------------------------------------------------------
# The fringe. One draw_multiline per gene rather than one draw_polyline per
# cilium: a tier-3 cell wears 82 of them and there are five cells in the water,
# and 400 draw calls a frame is not a thing to ask of a phone.
# ---------------------------------------------------------------------------

## The slot layout of a cell that has never been given one: the three home
## organs in their home arcs, everything else in the free arcs in whatever order
## the dictionary holds it. Every cell in the water but the player is this.
##
## **By place** (docs/design/dna-slots.md §5.7): a venom is seated first, at
## slot 3, the first front arc -- so a water hunter's venom rides on its bite --
## and the other outside genes after it. An inside form is left out: it is
## inside, and has no arc. food.gd reads a water cell's toxins off this same
## layout, so what is drawn is where it works.
##
## **Every outside gene on an arc of the skin, never at the inside's index.**
## A body missing a home organ -- a tailless daughter -- can carry more than the
## four free arcs hold, and the one past them used to sit at index 7, drawn and
## aimed on the last diagonal beside the gene already there. Index 7 is the
## inside now (§2.1), where nothing that faces out may sit, and a player's
## genome wears a gene posed there with no arc at all. So a gene past the free
## arcs takes a home arc its organ left empty, the first one free, as the
## genome's `_sync_order` seats one; and a tool's genome with more outside genes
## than a body has arcs wears the rest unseated, as a player's body wears an
## organ the gift took the arc of. No water cell carries more than the plan's
## slots outside.
static func default_order(tiers: Dictionary) -> Array:
	# **The home seats are the body plan's**: each home organ worn in its own slot,
	# the seats before the last of them held for them whether or not they are worn.
	var out: Array[StringName] = []
	out.resize(BodyPlan.HOME_SEATS)
	for k in _home_slots.size():
		if tiers.has(_home_genes[k]):
			out[_home_slots[k]] = _home_genes[k]
	for gene: StringName in tiers:
		if Genome.has_forms(gene) and not Genome.is_inside_form(gene):
			out.append(gene)
	for gene: StringName in tiers:
		if not _homes.has(gene) and not Genome.has_forms(gene):
			out.append(gene)
	var inside := BodyPlan.INSIDE
	for home: int in _home_slots:
		if out.size() <= inside:
			break
		if out[home] == &"":
			out[home] = out[inside]
			out.remove_at(inside)
	if out.size() > inside:
		out.resize(inside)
	return out


## **Every organ the body wears, drawn by its kind** (docs/design/gene-looks.md §2):
## the home organs first, each on its home slot's arc whatever slot holds it -- the
## mouth's mat at the nose, the cirrus's oars on both flanks, the tail's lash at the
## stern, in the order they always drew -- then every other organ on its own slot's
## arc, a bite-riding organ's barbs on the side it guards, and an inside form's
## granules round the whole body. [param layout] is resolved: the body's own order,
## or [method default_order]'s.
static func _draw_fringe(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, tiers: Dictionary, clock: float, fade: float,
		steer: float, unit: float, layout: Array,
		eye: Dictionary = NO_EYE, tail: Vector2 = NO_TAIL,
		dose: Dictionary = NO_DOSE) -> void:
	if tiers.is_empty():
		return
	var sk := _body_skin
	_on_body(sk, at, fwd, stb, r, unit)
	sk.steer = steer
	# **The home organs, found by the body plan and not by their name**: each on its
	# home slot's arc, in the plan's order -- the nose, the flank, the stern -- which
	# is the order the mat, the oars and the lash always drew in.
	for k in _home_genes.size():
		var home := _home_genes[k]
		var copies := int(tiers.get(home, 0))
		if copies > 0:
			_draw_worn(canvas, sk, home, copies, _home_arc(home, layout), clock, fade,
				eye if StringName(eye.get("gene", &"")) == home else NO_EYE, tail, 0.0)
	# **The slot is the arc.** Walked by slot rather than by dictionary order, so
	# a gene the player placed in the rear-left diagonal is drawn -- and aimed --
	# in the rear-left diagonal.
	for slot in layout.size():
		var gene: StringName = layout[slot]
		if gene == &"" or _homes.has(gene) or Genome.is_inside_form(gene):
			continue
		var copies := int(tiers.get(gene, 0))
		if copies <= 0:
			continue
		var flare := 0.0
		# **An organ that rides the bite is on the lips at the front** -- the toxin's
		# venom, today -- and is drawn with the gape; on a side or the stern it is
		# barbs on the arc it guards, unless the switch has made a side venom inert,
		# when it draws nothing.
		if bool(_look_of(gene).get("lips", false)):
			if slot >= Genome.INSIDE or Genome.is_front(slot) or not CellBody.VENOM_SIDES:
				continue
			flare = float(dose.get("guard", 0.0))
		_draw_worn(canvas, sk, gene, copies, arc_for_slot(slot), clock, fade,
			eye if StringName(eye.get("gene", &"")) == gene else NO_EYE, tail, flare)
	# **What is inside has no arc**: its beads are granules under the whole skin,
	# and nothing at any one place.
	for gene: StringName in tiers:
		if Genome.is_inside_form(gene) and int(tiers[gene]) > 0:
			_draw_granules(canvas, at, fwd, stb, r, gene, int(tiers[gene]), fade,
				unit, float(dose.get("granules", 0.0)))


## **One organ a body wears**, [param gene] at [param copies] on [param arc] of the
## body skin [param sk]: built by its kind and painted in its family's shade, at its
## kind's ink and width. [param eye] buds and flares a pigment, and lengthens and
## brightens the organ as a level arrives; [param flare] is a bite-riding organ's
## barbs firing, 0..1. **A tail is drawn on its own clock** where the body has one
## ([param tail], the player's): its wave stops when it is held still.
static func _draw_worn(canvas: CanvasItem, sk: Stretch, gene: StringName, copies: int,
		arc: Vector2, clock: float, fade: float, eye: Dictionary, tail: Vector2,
		flare: float) -> void:
	var look := _look_of(gene)
	sk.a0 = arc.x
	sk.a1 = arc.y
	sk.lit = clampf(flare, 0.0, 1.0)
	sk.still = 0.0
	var own := clock
	if not is_nan(tail.x) and look["shape"] == LASH \
			and Catalogue.provides(gene, &"impulse_speed"):
		own = tail.x
		sk.still = tail.y
	# Nothing to flare on nearly every organ drawn: no eye, no lookups.
	var lit := 1.0
	var reach := 1.0
	if not eye.is_empty():
		var arriving := clampf(float(eye.get("flare", 0.0)), 0.0, 1.0)
		lit = lerpf(1.0, FLARE_INK, arriving)
		reach = lerpf(1.0, FLARE_REACH, arriving)
	var d := _drawn
	d.clear()
	_build(d, sk, look, copies, own, reach)
	_paint(canvas, d, look, hue(gene), _kind_alpha(look) * _tier(TIER_ALPHA, copies) * lit
		* fade * (1.0 + TOXIN_FLARE_INK * sk.lit), _kind_width(look) * sk.px, sk, eye, own,
		fade, false)


## **The arc a home organ is drawn on**: its home slot's in the body plan --
## whatever slot holds it, which is what makes it a home organ -- or, for one the
## plan gives no home, the arc it is seated on in [param layout].
static func _home_arc(gene: StringName, layout: Array) -> Vector2:
	var home: int = _homes.get(gene, -1)
	if home >= 0 and home < _plan_arcs.size():
		return _plan_arcs[home]
	return BodyPlan.arc(layout.find(gene))


## **One step of a tail's own clock** (automation.md §8.1): `(clock, still)`,
## the clock its wave is drawn on and how far it has gone still, 0 beating to 1
## held, after [param delta] seconds with the tail [param held] or not. The clock
## slows to a stop as the tail goes still and picks up as it beats again, so the
## wave halts where it was. Both views keep one for the player's tail: the
## point-of-view figure and full vision draw the same tail.
static func step_tail(tail: Vector2, held: bool, delta: float) -> Vector2:
	var still := move_toward(tail.y, 1.0 if held else 0.0, delta / TAIL_SETTLE)
	return Vector2(tail.x + delta * (1.0 - still), still)


## **The pigment, doubled**: two lobes side by side along the arc, where the one
## disc was, and further apart for every level banked since the fork opened --
## an organelle about to divide, which is the one way a body can say *something
## here is waiting to be decided* without a word or a rhythm. [param normal] is
## the skin's outward normal at the seat; the lobes sit across it. A variant's
## lobes are its accent ([param mark]), each at the size its one mark has.
##
## They shimmer in antiphase on the body's own [param clock], so the pair
## breathes as one organ rather than as two lights.
static func _draw_bud(canvas: CanvasItem, seat: Vector2, normal: Vector2,
		r: float, tone: Color, banked: int, rim: float, core: float,
		clock: float, fade: float, mark: StringName = Kinds.MARK_DISC,
		px: float = 1.0) -> void:
	var along := normal.orthogonal()
	var apart := r * (BUD_APART
		+ BUD_APART_PER_LEVEL * float(clampi(banked, 0, BUD_BANKED_MAX)))
	var wave := BUD_SHIMMER * sin(TAU * clock / BUD_SHIMMER_PERIOD)
	for side: float in [-1.0, 1.0]:
		var lobe := seat + along * (apart * side)
		var shimmer := BUD_INK * (1.0 + wave * side)
		if mark != Kinds.MARK_DISC:
			_draw_mark(canvas, mark, lobe, r * BUD_R * ACCENT_PIGMENT, along, tone,
				minf(core * shimmer * fade, 1.0), px)
			continue
		canvas.draw_circle(lobe, r * BUD_R,
			Color(tone, minf(rim * shimmer * fade, 1.0)), true, -1.0, true)
		canvas.draw_circle(lobe, r * BUD_CORE,
			Color(tone, minf(core * shimmer * fade, 1.0)), true, -1.0, true)


## **Fangs on the lips** (dna-slots-ux.md §2.2): a bite-riding organ's spines in a
## front slot -- the toxin's venom -- one pair per copy, standing out of the lip
## bow's two corners and splayed away from the centreline, a bead at each tip in
## its seat's mark: a variant's accent, or the disc. [param flare] is 0..1, the
## venom landing.
static func _draw_fangs(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, gape: float, gene: StringName, tier: int,
		fade: float, unit: float, flare: float = 0.0) -> void:
	var tone := hue(gene)
	var mark := _bead_mark(_look_of(gene))
	var base := at + fwd * (r * OVOID_ALONG * GAPE_SEAT)
	var pairs := clampi(tier, 1, 3)
	var lit := clampf(flare, 0.0, 1.0)
	var length := maxf(gape * FANG_LEN * _tier(TIER_LEN, tier), FANG_MIN * unit) \
		* (1.0 + TOXIN_FLARE_LONG * lit)
	var bead := maxf(gape * FANG_BEAD, BEAD_MIN * unit) * (1.0 + TOXIN_FLARE_BEAD * lit)
	var ink := fade * (1.0 + TOXIN_FLARE_INK * lit)
	# Which way a positive turn takes a vector, on this canvas: toward starboard
	# on every canvas this game has, and the other way on a mirrored one.
	var hand := 1.0 if stb.cross(fwd) < 0.0 else -1.0
	var lines := PackedVector2Array()
	for side: float in [-1.0, 1.0]:
		for i in pairs:
			var u := (float(i) + 0.5) / float(pairs)
			var s := side * lerpf(FANG_FROM, FANG_TO, u)
			var root := _lip(base, fwd, stb, gape, s)
			var along := (_lip(base, fwd, stb, gape, s + 0.01)
				- _lip(base, fwd, stb, gape, s - 0.01)).normalized()
			var out := Vector2(-along.y, along.x)
			if out.dot(fwd) < 0.0:
				out = -out
			# Splayed outward, so the pair reads as fangs at the corners of the
			# mouth and stays out of the way ahead.
			out = out.rotated(deg_to_rad(FANG_SPLAY) * side * hand)
			var tip := root + out * length
			lines.append(root)
			lines.append(tip)
			_draw_bead(canvas, tip, bead, tone, FANG_ALPHA * ink, lit, mark,
				out.orthogonal(), unit)
	_stroke(canvas, lines, tone, FANG_ALPHA * ink, FANG_WIDTH * unit)


## **An inside form: its beads under the whole skin, and no arc**
## (dna-slots-ux.md §2.4; gene-looks.md §2.1) -- granules, [constant
## GRANULE_COUNT] by copies, scattered just inside the rim round the body, the
## mouth's arc left clear, each in its seat's mark: a variant's accent, or the
## disc. [param flare] is 0..1, the poison being taken.
static func _draw_granules(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, gene: StringName, tier: int, fade: float,
		unit: float, flare: float = 0.0) -> void:
	var tone := hue(gene)
	var mark := _bead_mark(_look_of(gene))
	var lit := clampf(flare, 0.0, 1.0)
	var count := _count(GRANULE_COUNT, tier)
	var dot := maxf(r * GRANULE_R, GRANULE_MIN * unit) * (1.0 + TOXIN_FLARE_BEAD * lit)
	var ink := GRANULE_ALPHA * fade * (1.0 + GRANULE_FLARE_INK * lit)
	for i in count:
		var u := (float(i) + 0.5 + GRANULE_SPREAD * sin(float(i) * 3.7)) / float(count)
		var t := deg_to_rad(lerpf(GRANULE_FROM, 360.0 - GRANULE_FROM, u))
		var jitter := 0.07 * sin(float(i) * 2.3 + 1.1) - 0.02
		_draw_bead(canvas, _surface(at, fwd, stb, r * (GRANULE_SEAT + jitter), t),
			dot, tone, ink, lit, mark, _normal(fwd, stb, t).orthogonal(), unit)


## **The mark a bead is drawn as**: its look's, where its seat is the beads -- a
## variant's accent, or the disc -- and the disc for any other inside form's.
static func _bead_mark(look: Dictionary) -> StringName:
	return look["mark"] if look["seat"] == Kinds.SEAT_BEADS else Kinds.MARK_DISC


## One bead of a toxin -- in [param mark], a disc unless a variant's accent says
## otherwise, never under [constant ACCENT_BEAD_MIN] canvas px then -- and, while
## it flares, a three-ring haze round it. [param along] is the way a diamond or a
## bar lies; [param px] is how many of the canvas's units make one pixel.
static func _draw_bead(canvas: CanvasItem, at: Vector2, size: float, tone: Color,
		alpha: float, flare: float, mark: StringName = Kinds.MARK_DISC,
		along: Vector2 = Vector2.RIGHT, px: float = 1.0) -> void:
	if flare > 0.0:
		for q in 3:
			var k := float(q) / 3.0
			canvas.draw_circle(at, size * (2.0 + 4.8 * k),
				Color(tone, 0.10 * (1.0 - k) * flare), true, -1.0, true)
	if mark == Kinds.MARK_DISC:
		canvas.draw_circle(at, size, Color(tone, minf(alpha, 1.0)), true, -1.0, true)
		return
	_draw_mark(canvas, mark, at, maxf(size, ACCENT_BEAD_MIN * px), along, tone,
		minf(alpha, 1.0), px)


# ---------------------------------------------------------------------------
# The kinds (docs/design/gene-looks.md §2, §3). **One generator per kind, drawn
# on a skin** -- a stretch of a body's arc, or a tile's dome -- so a body and a
# tile are one vocabulary, which is the promise this file makes at its top. A
# generator only builds: its strokes into one `draw_multiline`, as the fringe
# always was, its curves and closed outlines into one polyline each, its fills
# and its marks. [method _paint] draws what it built. A tile is the same organ
# at the tile's scale, so the explaining line's glyph and the quick placement's
# buds, which are tiles, follow every kind for nothing.
# ---------------------------------------------------------------------------

## **Where an organ is drawn, its skin** (gene-looks.md §2.2): a stretch of a body's
## arc, or a tile's dome.
## On a body, [member at], [member fwd], [member stb] and [member r] are the body
## and [member a0] to [member a1] the arc in ovoid degrees; on a tile [member at]
## is the dome's centre, [member r] its radius in px and the arc in radians.
## [member unit] is the length every kind's numbers are fractions of: the body's
## radius, or a tile's px per body radius. [member px] is how many of the
## canvas's units make one pixel, for the floors that are pixels. The rest is
## what the body is doing there: its [member steer], its tail held
## [member still], a weapon's flare ([member lit]).
class Stretch extends RefCounted:
	var tile := false
	var at := Vector2.ZERO
	var fwd := Vector2.UP
	var stb := Vector2.RIGHT
	var r := 1.0
	var a0 := 0.0
	var a1 := 0.0
	var unit := 1.0
	var px := 1.0
	var steer := 0.0
	var still := 0.0
	var lit := 0.0


## **One organ, built and not yet drawn**: the strokes of its one
## `draw_multiline`, its curves and closed outlines -- **a polyline each**: a
## continuous line built from separate segments shows a bright dot at every
## joint, and dots are what *armed* looks like (gene-looks.md §2.2) -- its fills,
## each a polygon and its share of the organ's ink, and its marks, each
## `[seat, at, size, along]`.
class Drawn extends RefCounted:
	var lines := PackedVector2Array()
	var paths: Array[PackedVector2Array] = []
	var fills: Array = []
	var marks: Array = []

	func clear() -> void:
		lines.clear()
		paths.clear()
		fills.clear()
		marks.clear()


## **The one skin and the one build every body's organs are drawn through**, each
## refilled for the next organ: nothing is made per organ per body per frame but
## the points themselves.
static var _body_skin := Stretch.new()
static var _drawn := Drawn.new()

## **Tile px per body radius**, so a tile organ is the body's organ at the tile's
## scale: 11 px for an earned stroke of 0.30 r, 36.7 for a whole radius.
const TILE_PER_R := TILE_LEN_EARNED / LEN_EARNED
## **What a tile holds** (gene-looks.md §2.2): no reach past this many body radii --
## 17 px, today's tallest, the tail's -- so the explaining line's row stays as it was
## measured; no more strands of a lash than this, or it tangles; no more strokes of
## a mat than this, or it closes into a flag on the dome.
const TILE_REACH_MAX := 0.46
const TILE_LASH_MAX := 3
const TILE_MAT_MAX := 11
## The tile's oars are held at this phase of their beat, where the knee shows.
const TILE_OARS_PHASE := 0.9
## A tile's skin stops this many radians short of the dome's ends.
const TILE_SKIN_INSET := 0.12
## A bead-headed spine's stroke on a tile, against the tile's own width: a weapon
## reads heavier.
const TILE_SPINE_WIDTH := 1.2

## **An accent** (gene-looks.md §3.1): at a pigment, a variant's mark at this share
## of the pigment's disc; a ring's stroke this share of its radius; a mark at the
## basal body or an organelle's centre at this share of the organ's ink, and every
## bead of an accent other than a disc never under [constant ACCENT_BEAD_MIN] canvas
## px, which is what a ring, a diamond or a bar needs to read as one.
const ACCENT_PIGMENT := 0.85
const ACCENT_RING := 0.42
const ACCENT_RING_MIN := 1.2
const ACCENT_INK := 1.15
const ACCENT_BEAD_MIN := 2.6
## **The basal body** (§3.1): where a cilium or a flagellum is rooted in a real
## cell, this far inside the skin at the arc's middle, and this big -- both of r.
const BASAL_DEPTH := 0.11
const BASAL_SIZE := 0.085

## **Tier is magnitude** (§2.3): a tuft's and a spine's fan opens this many degrees a
## copy past the first, so their tips stay apart as the count grows.
const FAN_PER_COPY := 6.0
## A tuft: its bent stems in this many steps; a fork's or a three-way tip's arms
## this far from the stem and this long, of the bristle; a ring tip's radius, of r
## and never under its floor in px; a hook's curl.
const TUFT_BEND_STEPS := 4
const TUFT_FORK_DEG := 34.0
const TUFT_ARM := 0.46
const TUFT_RING := 0.06
const TUFT_RING_MIN := 1.5
const TUFT_HOOK_DEG := 40.0
const TUFT_HOOK_STEP := 0.11
## A coil: how far its zigzag swings either side, of r; how far its springs lean
## apart; how fast it breathes, drawing up and letting go.
const COIL_AMP := 0.10
const COIL_LEAN := 20.0
const COIL_BREATH := 2.4
## A lens: standing this far off the skin, of r, over this share of the arc, filled
## at this share of the organ's ink, its outline in this many steps.
const LENS_LIFT := 0.04
const LENS_FROM := 0.10
const LENS_FILL := 0.80
const LENS_STEPS := 10
## A spear's head, of r and never under its floor in px, and how far back its
## barbs sweep.
const SPEAR_HEAD := 0.10
const SPEAR_HEAD_MIN := 2.6
const SPEAR_HEAD_DEG := 28.0
## A plate: how thick, how far off the skin, and how far each overlaps the next.
const PLATE_THICK := 0.075
const PLATE_LIFT := 0.035
const PLATE_OVERLAP := 1.45
## **An organelle is one a copy** (§2.3): where each sits along its arc and how
## much deeper, by how many there are -- three things are counted without counting;
## its outline in this many steps; its centre's mark, of its size.
const ORGANELLE_SEATS := {
	1: [[0.5, 0.0]],
	2: [[0.22, 0.0], [0.78, 0.10]],
	3: [[0.12, 0.0], [0.88, 0.04], [0.5, 0.36]],
}
const ORGANELLE_STEPS := 18
const ORGANELLE_MARK := 0.36


## [param look] drawn: [param gene]'s resolved look, or a plain tuft for a gene this
## build does not know.
static func _look_of(gene: StringName) -> Dictionary:
	var look: Dictionary = _looks.get(gene, NO_LOOK)
	return look if not look.is_empty() else UNKNOWN_LOOK


## [param sk] made a stretch of the body at [param at], its arc set per organ.
static func _on_body(sk: Stretch, at: Vector2, fwd: Vector2, stb: Vector2, r: float,
		px: float) -> void:
	sk.tile = false
	sk.at = at
	sk.fwd = fwd
	sk.stb = stb
	sk.r = r
	sk.unit = r
	sk.px = px
	sk.steer = 0.0
	sk.still = 0.0
	sk.lit = 0.0


## A tile's dome at [param centre], [param dome] px across the radius, its organ at
## [param scale].
static func _tile_skin(centre: Vector2, dome: float, scale: float) -> Stretch:
	var sk := Stretch.new()
	sk.tile = true
	sk.at = centre
	sk.r = dome
	sk.a0 = TILE_ARC_FROM + TILE_SKIN_INSET
	sk.a1 = TILE_ARC_TO - TILE_SKIN_INSET
	sk.unit = TILE_PER_R * scale
	return sk


## The point of [param sk] at [param u], 0 to 1 along its arc.
static func _sk_root(sk: Stretch, u: float) -> Vector2:
	if sk.tile:
		var a := lerpf(sk.a0, sk.a1, u)
		return sk.at + Vector2(cos(a), sin(a)) * sk.r
	return _surface(sk.at, sk.fwd, sk.stb, sk.r, deg_to_rad(lerpf(sk.a0, sk.a1, u)))


## **[param sk] at [param u], all at once**: its point ([member _at_root]), its
## outward normal ([member _at_normal]) and **the way a stroke there leans as it
## swings** ([member _at_lean]) -- toward the nose on a body, which is how every
## swing in genes-and-cilia.md §4.2 is measured, and one way round on a tile. The
## point is [method _sk_root]'s to the bit.
static func _frame(sk: Stretch, u: float) -> void:
	_frame_on(sk.tile, sk.at, sk.fwd, sk.stb, sk.r, sk.a0, sk.a1, u)


## **[method _frame], on a stretch already unpacked**: what the home organs' kinds
## call, a stroke at a time. Every body in the water wears them, so this is most of
## what a fringe costs to build (gene-looks.md §9.2), and a stretch's fields are
## looked up by name each time they are read: one call and one normal a stroke,
## from locals, where it was three calls, two normals and seventeen lookups.
static func _frame_on(tile: bool, at: Vector2, fwd: Vector2, stb: Vector2, r: float,
		a0: float, a1: float, u: float) -> void:
	if tile:
		var a := lerpf(a0, a1, u)
		var n := Vector2(cos(a), sin(a))
		_at_root = at + n * r
		_at_normal = n
		_at_lean = Vector2(n.y, -n.x)
		return
	var t := deg_to_rad(lerpf(a0, a1, u))
	var normal := _normal(fwd, stb, t)
	_at_root = _surface(at, fwd, stb, r, t)
	_at_normal = normal
	# The unit tangent toward the nose: the normal turned a quarter, in whichever
	# sense reduces |t|. On the starboard flank that is one way round and on the
	# port flank the other, so the two sides lean toward the same nose rather than
	# mirroring each other into a shape that has no front.
	_at_lean = Vector2(normal.y, -normal.x) if wrapf(t, -PI, PI) >= 0.0 \
		else Vector2(-normal.y, normal.x)


## What [method _frame] last found: read at once, before the next organ's.
static var _at_root := Vector2.ZERO
static var _at_normal := Vector2.UP
static var _at_lean := Vector2.RIGHT


## The way [param sk] runs at [param u], toward its arc's far end.
static func _sk_along(sk: Stretch, u: float) -> Vector2:
	var d := _sk_root(sk, u + 0.01) - _sk_root(sk, u - 0.01)
	return d.normalized() if d.length_squared() > 0.0 else Vector2.RIGHT


## +1 where a positive turn takes a normal toward the arc's far end, -1 where it
## takes it back: so a fan opens and a spring leans apart on any canvas.
static func _sk_hand(sk: Stretch) -> float:
	if sk.tile:
		return 1.0
	return 1.0 if sk.stb.cross(sk.fwd) < 0.0 else -1.0


## A point [param depth] body radii under [param sk] at [param u].
static func _sk_inner(sk: Stretch, u: float, depth: float) -> Vector2:
	_frame(sk, u)
	return _at_root - _at_normal * (depth * sk.unit)


## **A sense's pigment**, at the middle of its arc: the seat it has always had on a
## body, 0.80 of the way out, and the dome's on a tile.
static func _sk_seat(sk: Stretch) -> Vector2:
	if sk.tile:
		return sk.at + Vector2(0.0, -sk.r * PIGMENT_SEAT)
	return _surface(sk.at, sk.fwd, sk.stb, sk.r * PIGMENT_SEAT,
		deg_to_rad((sk.a0 + sk.a1) * 0.5))


## A length of [param look]'s at [param tier] copies, as a fraction of r: no more
## than [constant TILE_REACH_MAX] on a tile.
static func _length_of(sk: Stretch, look: Dictionary) -> float:
	var length := float(look["length"])
	return minf(length, TILE_REACH_MAX) if sk.tile else length


## **[param look]'s strokes' ink, by kind**: the home organs' kinds keep the ink
## they always had, so a variant of one is drawn as its organ is; a bead-headed
## spine is a weapon's, the guard's; every other kind an earned organ's.
static func _kind_alpha(look: Dictionary) -> float:
	match look["shape"]:
		MAT:
			return ALPHA_CYTOSTOME
		OARS:
			return ALPHA_CIRRUS
		LASH:
			return ALPHA_FLAGELLUM
		SPINES:
			if look["tip"] == Kinds.TIP_BEAD:
				return GUARD_ALPHA
	return ALPHA_EARNED


## **And their width, by kind**, as [method _kind_alpha] has their ink.
static func _kind_width(look: Dictionary) -> float:
	match look["shape"]:
		MAT:
			return WIDTH_CYTOSTOME
		OARS:
			return WIDTH_CIRRUS
		LASH:
			return WIDTH_FLAGELLUM
		SPINES:
			if look["tip"] == Kinds.TIP_BEAD:
				return GUARD_WIDTH
	return WIDTH_EARNED


## **Builds [param look] at [param tier] copies on [param sk] into [param d]**, on
## [param clock], its lengths times [param reach]: one generator per kind.
static func _build(d: Drawn, sk: Stretch, look: Dictionary, tier: int, clock: float,
		reach: float) -> void:
	match look["shape"]:
		MAT:
			_kind_mat(d, sk, look, tier, clock, reach)
		OARS:
			_kind_oars(d, sk, look, tier, clock, reach)
		LASH:
			_kind_lash(d, sk, look, tier, clock, reach)
		COIL:
			_kind_coil(d, sk, look, tier, clock, reach)
		LENS:
			_kind_lens(d, sk, look, tier, reach)
		SPINES:
			_kind_spines(d, sk, look, tier, reach)
		PLATES:
			_kind_plates(d, sk, look, tier, reach)
		ORGANELLE:
			_kind_organelle(d, sk, look, tier)
		_:
			_kind_tuft(d, sk, look, tier, reach)


## **Draws [param d]**, [param look]'s, in [param tone] at [param alpha] and
## [param width]: its fills, its strokes in one call, each curve and outline in
## one, then its marks. **A ghost** -- a hole being tried, not an organ -- is
## strokes and outlines only, its pigment at the [param fade] it is given.
static func _paint(canvas: CanvasItem, d: Drawn, look: Dictionary, tone: Color,
		alpha: float, width: float, sk: Stretch, eye: Dictionary, clock: float,
		fade: float, ghost: bool) -> void:
	if alpha <= 0.0:
		return
	if not ghost:
		for fill: Array in d.fills:
			canvas.draw_colored_polygon(fill[0], Color(tone, minf(alpha * float(fill[1]),
				1.0)))
	_stroke(canvas, d.lines, tone, alpha, width)
	for path: PackedVector2Array in d.paths:
		canvas.draw_polyline(path, Color(tone, minf(alpha, 1.0)), width, true)
	var mark: StringName = look["mark"]
	for one: Array in d.marks:
		var at: Vector2 = one[1]
		var size: float = one[2]
		var along: Vector2 = one[3]
		match one[0]:
			Kinds.SEAT_PIGMENT:
				_paint_pigment(canvas, at, size, along, tone, mark, alpha, sk, eye, clock,
					fade)
			Kinds.SEAT_BEADS:
				_draw_bead(canvas, at, size, tone, alpha, sk.lit, mark, along, sk.px)
			_:
				_draw_mark(canvas, mark, at, size, along, tone,
					minf(alpha * ACCENT_INK, 1.0), sk.px)


## **A sense's pigment**: on a body the organelle it has always been -- a three-ring
## haze, a rim and a core, or, at a fork, two lobes ([method _draw_bud]); brighter,
## wider and solid as a level arrives ([param eye]) -- and on a tile a plain disc.
## **A variant's accent takes the disc's place** ([param mark], at
## [constant ACCENT_PIGMENT] of it), over the same haze. [param size] is the body's
## radius, or the tile's disc.
static func _paint_pigment(canvas: CanvasItem, at: Vector2, size: float, along: Vector2,
		tone: Color, mark: StringName, alpha: float, sk: Stretch, eye: Dictionary,
		clock: float, fade: float) -> void:
	if sk.tile:
		var ink := minf(0.85 * alpha / TILE_STROKE_ALPHA, 1.0)
		if mark == Kinds.MARK_DISC:
			canvas.draw_circle(at, size, Color(tone, ink), true, -1.0, true)
		else:
			_draw_mark(canvas, mark, at, size * 1.1, along, tone, ink, sk.px)
		return
	var r := size
	var flare := clampf(float(eye.get("flare", 0.0)), 0.0, 1.0)
	var bud := int(eye.get("bud", -1))
	# The whole organ is brighter at the top of a flare, and the haze wider and
	# denser as well: the flare is the organ lighting up, not a disc on it.
	var lit := lerpf(1.0, FLARE_INK, flare)
	var wide := lerpf(1.0, FLARE_HAZE_WIDE, flare)
	var dense := lerpf(1.0, FLARE_HAZE_DENSE, flare)
	for k in 3:
		var q := float(k) / 3.0
		canvas.draw_circle(at, r * PIGMENT_HAZE * (1.0 + 1.6 * q) * wide,
			Color(tone, 0.030 * (1.0 - q) * dense * lit * fade), true, -1.0, true)
	# **Drawn solid at the top of a flare**: the rim rises to the core's ink, so
	# the pigment is one bright spot rather than a spot in a ring. Clamped only
	# once the view's fade is in: point of view draws this body at a third, and
	# a clamp before that would throw the brightening away.
	var rim := lerpf(PIGMENT_RIM_ALPHA, PIGMENT_CORE_ALPHA, flare) * lit
	var core := PIGMENT_CORE_ALPHA * lit
	if bud >= 0:
		_draw_bud(canvas, at, along.orthogonal(), r, tone, bud, rim, core, clock, fade,
			mark, sk.px)
		return
	if mark != Kinds.MARK_DISC:
		_draw_mark(canvas, mark, at, r * PIGMENT_OUTER * ACCENT_PIGMENT, along, tone,
			minf(core * fade, 1.0), sk.px)
		return
	canvas.draw_circle(at, r * PIGMENT_OUTER,
		Color(tone, minf(rim * fade, 1.0)), true, -1.0, true)
	canvas.draw_circle(at, r * PIGMENT_INNER,
		Color(tone, minf(core * fade, 1.0)), true, -1.0, true)


## **A mark** (gene-looks.md §3.1): a filled disc; a hollow ring, its stroke
## [constant ACCENT_RING] of its radius; a diamond, a square on its point, square to
## the skin; or a bar, a short slab lying along it -- at [param at], [param size]
## across the radius, [param along] the way the skin runs there. Nothing for none.
static func _draw_mark(canvas: CanvasItem, mark: StringName, at: Vector2, size: float,
		along: Vector2, tone: Color, alpha: float, px: float = 1.0) -> void:
	match mark:
		Kinds.MARK_DISC:
			canvas.draw_circle(at, size, Color(tone, alpha), true, -1.0, true)
		Kinds.MARK_RING:
			canvas.draw_arc(at, size * 1.05, 0.0, TAU, 16, Color(tone, alpha),
				maxf(size * ACCENT_RING, ACCENT_RING_MIN * px), true)
		Kinds.MARK_DIAMOND:
			var a := along * (size * 1.25)
			var b := along.orthogonal() * (size * 1.25)
			canvas.draw_colored_polygon(PackedVector2Array([at + a, at + b, at - a, at - b]),
				Color(tone, alpha))
		Kinds.MARK_BAR:
			var a := along * (size * 1.5)
			var b := along.orthogonal() * (size * 0.55)
			canvas.draw_colored_polygon(PackedVector2Array([at + a + b, at - a + b,
				at - a - b, at + a - b]), Color(tone, alpha))


## **A variant's accent, drawn on its own** -- in a chip's first lobe, before a
## waiting gene's word -- [param mark] at [param at], [param size] across the
## radius, in [param tone] at [param alpha]. Nothing for a gene with none.
static func draw_accent(canvas: CanvasItem, mark: StringName, at: Vector2, size: float,
		tone: Color, alpha: float) -> void:
	_draw_mark(canvas, mark, at, size, Vector2.RIGHT, tone, alpha)


## **[param gene]'s accent**: the mark a variant wears, `&""` for its organ as
## shipped and for a gene this build does not know.
static func accent_of(gene: StringName) -> StringName:
	return StringName(_look_of(gene).get("accent", &""))


## The basal body's mark, for a kind whose seat it is and a variant that wears one.
static func _basal(d: Drawn, sk: Stretch, look: Dictionary) -> void:
	if look["seat"] != Kinds.SEAT_BASAL or look["mark"] == Kinds.MARK_NONE:
		return
	d.marks.append([Kinds.SEAT_BASAL, _sk_inner(sk, 0.5, BASAL_DEPTH),
		BASAL_SIZE * sk.unit, _sk_along(sk, 0.5)])


## A sense's pigment mark: the body's radius on a body, the tile's disc on a tile.
static func _pigment(d: Drawn, sk: Stretch) -> void:
	d.marks.append([Kinds.SEAT_PIGMENT, _sk_seat(sk),
		TILE_PIGMENT * sk.unit / TILE_PER_R if sk.tile else sk.r, _sk_along(sk, 0.5)])


## **mat** -- the eating build: dense fine cilia standing just off the skin, a beat
## travelling along them -- the oral membranelles. **The mouth's own, exactly**:
## three points a cilium, curved -- radial where it leaves the skin and at the full
## swing only by the tip. Rendered as a straight stroke plus a lean it was much
## worse: at three copies the roots are two pixels apart, so a mat of 26 leaning
## strokes closes up into a solid flag and stops being a texture at all. Curving it
## keeps every stroke separate at the root, which is where density is read.
static func _kind_mat(d: Drawn, sk: Stretch, look: Dictionary, tier: int, clock: float,
		reach: float) -> void:
	var count := _count(int(look["count"]), tier)
	if sk.tile:
		count = mini(count, TILE_MAT_MAX)
	var length0 := _length_of(sk, look)
	var scale := _tier(TIER_LEN, tier) * reach
	var lines := d.lines
	var tile := sk.tile
	var at := sk.at
	var fwd := sk.fwd
	var stb := sk.stb
	var r := sk.r
	var unit := sk.unit
	var a0 := sk.a0
	var a1 := sk.a1
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var wave := sin(u * CYTOSTOME_WAVE_U - clock * CYTOSTOME_WAVE_HZ)
		var length := length0 * unit * (0.80 + 0.30 * wave) * scale
		_frame_on(tile, at, fwd, stb, r, a0, a1, u)
		var normal := _at_normal
		var nose := _at_lean
		var swing := deg_to_rad(CYTOSTOME_SWING_DEG) * wave
		var root := _at_root + normal * (unit * CYTOSTOME_LIFT)
		var mid := root + _swung(normal, nose, swing * CYTOSTOME_CURVE) \
			* (length * 0.55)
		var tip := mid + _swung(normal, nose, swing) * (length * 0.45)
		lines.append(root)
		lines.append(mid)
		lines.append(mid)
		lines.append(tip)
	_basal(d, sk, look)


## **oars** -- rowing strokes with a knee, beating in waves: the cirrus's build, and
## the knee is what separates it from a lash at a glance. **On a body both flanks**,
## the arc and its mirror, in antiphase -- the port oars the starboard ones mirrored,
## so the port arc is the kind's and never a slot's -- and the outboard side of a
## turn works harder ([member Stretch.steer]). On a tile, one dome.
static func _kind_oars(d: Drawn, sk: Stretch, look: Dictionary, tier: int, clock: float,
		reach: float) -> void:
	var count := _count(int(look["count"]), tier)
	var length0 := _length_of(sk, look)
	var scale := _tier(TIER_LEN, tier) * reach
	var knee := float(look["knee"])
	var bend := deg_to_rad(float(look["bend"]))
	var flank := Vector2(sk.a0, sk.a1)
	var lines := d.lines
	var tile := sk.tile
	var at := sk.at
	var fwd := sk.fwd
	var stb := sk.stb
	var r := sk.r
	var unit := sk.unit
	for side: float in ([1.0] if tile else [1.0, -1.0]):
		if side < 0.0:
			sk.a0 = -flank.y
			sk.a1 = -flank.x
		var a0 := sk.a0
		var a1 := sk.a1
		var bias := 1.0 + CIRRUS_STEER_BIAS * clampf(-sk.steer * side, -1.0, 1.0)
		for i in count:
			var u := (float(i) + 0.5) / float(count)
			var phase := clock * CIRRUS_HZ + u * CIRRUS_WAVE_U
			if side < 0.0:
				phase += PI
			if tile:
				phase += TILE_OARS_PHASE
			var length := length0 * unit * (0.86 + 0.22 * cos(phase)) * scale
			_frame_on(tile, at, fwd, stb, r, a0, a1, u)
			var normal := _at_normal
			var nose := _at_lean
			var swing := deg_to_rad(CIRRUS_SWING_DEG) * sin(phase) * bias
			var bent := _swung(normal, nose, swing + bend * signf(sin(phase)))
			var root := _at_root
			var at_knee := root + _swung(normal, nose, swing) * (length * knee)
			lines.append(root)
			lines.append(at_knee)
			lines.append(at_knee)
			lines.append(at_knee + bent * (length * (1.0 - knee)))
		_basal(d, sk, look)
	sk.a0 = flank.x
	sk.a1 = flank.y


## **lash** -- long smooth strands carrying a wave out to the tip, the only stroke
## in the vocabulary longer than half the body: the tail, and with two waves a whip.
## [member Stretch.still] is how far it is held still, 0 to 1: its lash goes slack
## toward [constant TAIL_HELD_LASH], its clock the caller's, stopping.
static func _kind_lash(d: Drawn, sk: Stretch, look: Dictionary, tier: int, clock: float,
		reach: float) -> void:
	var count := _count(int(look["count"]), tier)
	if sk.tile:
		count = mini(count, TILE_LASH_MAX)
	var length0 := _length_of(sk, look)
	var scale := _tier(TIER_LEN, tier) * reach
	var slack := lerpf(1.0, TAIL_HELD_LASH, clampf(sk.still, 0.0, 1.0))
	var wave := float(look["wave"])
	var waves := float(look["waves"])
	# Five segments a wave, the tail's own six points for one.
	var points := FLAGELLUM_POINTS
	if waves > 1.0:
		points = ceili(float(FLAGELLUM_POINTS - 1) * waves) + 1
	var lines := d.lines
	var tile := sk.tile
	var at := sk.at
	var fwd := sk.fwd
	var stb := sk.stb
	var r := sk.r
	var unit := sk.unit
	var a0 := sk.a0
	var a1 := sk.a1
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var base := sin(u * FLAGELLUM_WAVE_U - clock * FLAGELLUM_WAVE_HZ)
		var length := length0 * unit * (0.82 + 0.26 * base) * scale
		_frame_on(tile, at, fwd, stb, r, a0, a1, u)
		var dir := _at_normal
		var side := Vector2(-dir.y, dir.x)
		var root := _at_root
		var previous := root
		for j in range(1, points):
			var v := float(j) / float(points - 1)
			var lash := sin(v * waves * FLAGELLUM_WAVE_V - clock * FLAGELLUM_WAVE_HZ
				+ u * FLAGELLUM_WAVE_U) * length * wave * v * slack
			var point := root + dir * (length * v) + side * lash
			lines.append(previous)
			lines.append(point)
			previous = point
	_basal(d, sk, look)


## **coil** -- a contractile spring: a bold zigzag standing off the skin that draws
## up and lets go, slowly, on the body's clock. Small loops were tried first, and at
## body size loops read as beads, which mean *armed* (gene-looks.md §10).
static func _kind_coil(d: Drawn, sk: Stretch, look: Dictionary, tier: int, clock: float,
		reach: float) -> void:
	var count := _count(int(look["count"]), tier)
	var span := _length_of(sk, look) * _tier(TIER_LEN, tier) * reach * sk.unit
	var zigs := int(look["turns"]) * 2 + 1
	var amp := COIL_AMP * sk.unit
	var hand := _sk_hand(sk)
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		_frame(sk, u)
		var root := _at_root
		var dir := _at_normal.rotated(deg_to_rad(COIL_LEAN) * (u - 0.5) * 2.0 * hand)
		var across := dir.orthogonal()
		var length := span * (0.84 + 0.16 * sin(clock * COIL_BREATH + float(i) * 1.9))
		var spring := PackedVector2Array([root])
		for k in range(1, zigs + 1):
			var v := float(k) / float(zigs)
			var off := 0.0 if k == zigs else (1.0 if k % 2 == 1 else -1.0)
			spring.append(root + dir * (length * v) + across * (amp * off))
		d.paths.append(spring)
	_basal(d, sk, look)


## **tuft** -- the sensing build: stiff, still bristles fanned over a pigment, the
## one filled spot of a sense's colour on a body. No clock: a sensory cilium does not
## row, and the variation across the arc is a standing bow rather than a wave, so
## the arc reads as a tuft and not as a picket fence. Its tip is its identity --
## plain, forked, ringed, hooked, three-way -- and a bend splays the outer bristles
## away from the middle, as feelers do.
static func _kind_tuft(d: Drawn, sk: Stretch, look: Dictionary, tier: int,
		reach: float) -> void:
	var count := _count(int(look["count"]), tier)
	var span := _length_of(sk, look) * _tier(TIER_LEN, tier) * reach * sk.unit
	var tip: StringName = look["tip"]
	var bend := deg_to_rad(float(look["bend"]))
	var ring := maxf(TUFT_RING * sk.unit, TUFT_RING_MIN * sk.px)
	var fan := deg_to_rad(float(look["fan"]) + FAN_PER_COPY * float(maxi(tier - 1, 0)))
	var hand := _sk_hand(sk)
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		_frame(sk, u)
		var root := _at_root
		var normal := _at_normal.rotated(fan * (u - 0.5) * 2.0 * hand)
		var length := span * (0.88 + 0.14 * sin(u * PI))
		var stem := length
		match tip:
			Kinds.TIP_RING:
				stem = length - ring
			Kinds.TIP_FORK, Kinds.TIP_TRI:
				stem = length * 0.58
			Kinds.TIP_HOOK:
				stem = length * 0.66
		var dir := normal
		var end := root + normal * stem
		if bend == 0.0:
			d.lines.append(root)
			d.lines.append(end)
		else:
			var along := _sk_along(sk, u)
			var side := clampf((u - 0.5) * 2.0, -1.0, 1.0)
			var bent := PackedVector2Array([root])
			end = root
			for k in TUFT_BEND_STEPS:
				var angle := bend * side * float(k + 1) / float(TUFT_BEND_STEPS)
				dir = (normal * cos(angle) + along * sin(angle)).normalized()
				end += dir * (stem / float(TUFT_BEND_STEPS))
				bent.append(end)
			d.paths.append(bent)
		match tip:
			Kinds.TIP_FORK, Kinds.TIP_TRI:
				var arms: Array = [-1.0, 1.0] if tip == Kinds.TIP_FORK else [-1.0, 0.0, 1.0]
				for arm: float in arms:
					d.lines.append(end)
					d.lines.append(end + dir.rotated(deg_to_rad(TUFT_FORK_DEG) * arm)
						* (length * TUFT_ARM))
			Kinds.TIP_HOOK:
				# A crook: the last third curls back over the stem's outer side.
				var crook := PackedVector2Array([end])
				var turn := 1.0 if u >= 0.5 else -1.0
				for k in 5:
					crook.append(crook[crook.size() - 1] + dir.rotated(
						deg_to_rad(TUFT_HOOK_DEG * float(k + 1)) * turn * hand)
						* (length * TUFT_HOOK_STEP))
				d.paths.append(crook)
			Kinds.TIP_RING:
				var centre := end + dir * ring
				var loop := PackedVector2Array()
				for k in 13:
					var a := TAU * float(k) / 12.0
					loop.append(centre + Vector2(cos(a), sin(a)) * ring)
				d.paths.append(loop)
	_pigment(d, sk)


## **lens** -- an eye: a clear lens standing on the skin over a pigment. The ocellus
## is a real camera eye, and a lens is what no bristle organ has. Filled: as an
## outline it read as a hook, not an eye (gene-looks.md §10).
static func _kind_lens(d: Drawn, sk: Stretch, look: Dictionary, tier: int,
		reach: float) -> void:
	var bulge := float(look["bulge"]) * _tier(TIER_LEN, tier) * reach * sk.unit
	var lift := LENS_LIFT * sk.unit
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in LENS_STEPS + 1:
		var v := float(k) / float(LENS_STEPS)
		var u := lerpf(LENS_FROM, 1.0 - LENS_FROM, v)
		_frame(sk, u)
		var root := _at_root
		var normal := _at_normal
		inner.append(root + normal * lift)
		outer.append(root + normal * (lift + bulge * sin(v * PI)))
	inner.reverse()
	outer.append_array(inner)
	d.fills.append([outer.duplicate(), LENS_FILL])
	outer.append(outer[0])
	d.paths.append(outer)
	_pigment(d, sk)


## **spines** -- the armed build: hard straight shafts, fanned, each with a head --
## a spear for a dart (a trichocyst's real spindle), a bead for a toxin, a barbed
## hook. Never under [constant GUARD_MIN] canvas px. A bead-headed spine's accent is
## its beads; [member Stretch.lit] is it firing, longer, with bigger beads.
static func _kind_spines(d: Drawn, sk: Stretch, look: Dictionary, tier: int,
		reach: float) -> void:
	var per_copy := int(look["per_copy"])
	var count := per_copy * clampi(tier, 1, 3) if per_copy > 0 \
		else _count(int(look["count"]), tier)
	var length := maxf(_length_of(sk, look) * sk.unit * _tier(TIER_LEN, tier) * reach,
		GUARD_MIN * sk.px) * (1.0 + TOXIN_FLARE_LONG * sk.lit)
	var fan := deg_to_rad(float(look["fan"]) + FAN_PER_COPY * float(maxi(tier - 1, 0)))
	var hand := _sk_hand(sk)
	var tip: StringName = look["tip"]
	var head := maxf(SPEAR_HEAD * sk.unit, SPEAR_HEAD_MIN * sk.px)
	var bead := maxf(GUARD_BEAD * sk.unit, BEAD_MIN * sk.px) \
		* (1.0 + TOXIN_FLARE_BEAD * sk.lit)
	for i in count:
		var w := (float(i) + 0.5) / float(count)
		var u := lerpf(GUARD_FROM, 1.0 - GUARD_FROM, w)
		_frame(sk, u)
		var root := _at_root
		var dir := _at_normal.rotated(fan * lerpf(-1.0, 1.0, w) * hand)
		var end := root + dir * length
		d.lines.append(root)
		d.lines.append(end)
		match tip:
			Kinds.TIP_SPEAR:
				for s: float in [-1.0, 1.0]:
					d.lines.append(end)
					d.lines.append(end - dir.rotated(deg_to_rad(SPEAR_HEAD_DEG) * s) * head)
			Kinds.TIP_BARB:
				# A barbed hook: one barb back along a side, and the point bent over.
				d.lines.append(end)
				d.lines.append(end - dir.rotated(deg_to_rad(32.0) * hand) * head)
				d.lines.append(end)
				d.lines.append(end + dir.rotated(deg_to_rad(-110.0) * hand) * (head * 0.9))
			_:
				d.marks.append([Kinds.SEAT_BEADS, end, bead, dir.orthogonal()])
	_basal(d, sk, look)


## **plates** -- armour: overlapping scales lying along the skin over a thickened
## rim, the one build that runs along a body rather than out of it. The pellicle is
## a real layer of plates under the membrane.
static func _kind_plates(d: Drawn, sk: Stretch, look: Dictionary, tier: int,
		reach: float) -> void:
	var count := _count(int(look["count"]), tier)
	var thick := PLATE_THICK * sk.unit * _tier(TIER_LEN, tier) * reach
	var lift := PLATE_LIFT * sk.unit
	var width := PLATE_OVERLAP / float(count)
	for i in count:
		var c := (float(i) + 0.5) / float(count)
		var plate := PackedVector2Array()
		for k in 7:
			var v := float(k) / 6.0
			var u := clampf(c + (v - 0.5) * width, 0.0, 1.0)
			_frame(sk, u)
			plate.append(_at_root + _at_normal * (lift + thick * sin(v * PI)))
		d.paths.append(plate)
	# The skin under them, doubled: a thickened rim.
	var rim := PackedVector2Array()
	for k in 9:
		var u := float(k) / 8.0
		_frame(sk, u)
		rim.append(_at_root + _at_normal * lift)
	d.paths.append(rim)
	_basal(d, sk, look)


## **organelle** -- the metabolism build: bodies under the skin at the arc, and
## nothing outside it. **One a copy**: tier is how many. Its form is its identity --
## a plastid's solid lens, a vacuole's clear bubble, a mitochondrion's long rod with
## a fold, a stack of cisternae, a contractile vacuole's canals -- and its centre
## the seat of a variant's accent.
static func _kind_organelle(d: Drawn, sk: Stretch, look: Dictionary, tier: int) -> void:
	var form: StringName = look["form"]
	var size := float(look["size"]) * sk.unit
	var depth := float(look["depth"])
	for seat: Array in ORGANELLE_SEATS[clampi(tier, 1, 3)]:
		var u: float = seat[0]
		var at := _sk_inner(sk, u, depth + float(seat[1]))
		var along := _sk_along(sk, u)
		var across := along.orthogonal()
		var outline := PackedVector2Array()
		for k in ORGANELLE_STEPS:
			var a := TAU * float(k) / float(ORGANELLE_STEPS)
			var x := cos(a)
			var y := sin(a)
			match form:
				Kinds.FORM_LENS:
					outline.append(at + along * (x * size * 1.25) + across * (y * size * 0.80))
				Kinds.FORM_CAPSULE:
					# A stadium: flat sides, round ends.
					outline.append(at + along * (signf(x) * pow(absf(x), 0.45) * size * 1.75)
						+ across * (y * size * 0.50))
				Kinds.FORM_STAR:
					outline.append(at + Vector2(x, y) * (size * 0.70))
				_:
					outline.append(at + Vector2(x, y) * size)
		match form:
			Kinds.FORM_STACK:
				# Three flat cisternae, stacked: a Golgi body or a thylakoid stack.
				for k in 3:
					var off := (float(k) - 1.0) * size * 0.55
					var bow := 0.25 * size * (1.0 - absf(float(k) - 1.0) * 0.4)
					var cistern := PackedVector2Array()
					for j in 7:
						var v := float(j) / 6.0
						cistern.append(at + along * lerpf(-size * 1.3, size * 1.3, v)
							+ across * (off + bow * sin(v * PI)))
					d.paths.append(cistern)
			Kinds.FORM_STAR:
				# A contractile vacuole: a bubble with canals running out of it.
				d.fills.append([outline.duplicate(), 0.12])
				for k in 6:
					var out := Vector2.from_angle(TAU * float(k) / 6.0 + 0.3)
					d.lines.append(at + out * (size * 0.72))
					d.lines.append(at + out * (size * 1.45))
			Kinds.FORM_CAPSULE:
				d.fills.append([outline.duplicate(), 0.10])
				var folds := PackedVector2Array([at - along * (size * 1.35)])
				for k in range(1, 7):
					var v := float(k) / 6.0
					var off := 0.0 if k == 6 else (1.0 if k % 2 == 1 else -1.0)
					folds.append(at + along * lerpf(-size * 1.35, size * 1.35, v)
						+ across * (off * size * 0.34))
				d.paths.append(folds)
			Kinds.FORM_LENS:
				d.fills.append([outline.duplicate(), 0.85])
			_:
				d.fills.append([outline.duplicate(), 0.12])
		if form != Kinds.FORM_STACK:
			outline.append(outline[0])
			d.paths.append(outline)
		if look["mark"] != Kinds.MARK_NONE:
			d.marks.append([Kinds.SEAT_CENTRE, at, size * ORGANELLE_MARK, along])


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
## [param mouth] is the organ the body has its gape from, worn at [param
## mouth_tier]: the lips are its hue, and self teal on a body that wears none.
## [param threat] is the one comparison that matters, `other.gape > my.radius`,
## and it is legal in full vision and only in full vision. The membrane is not
## told: point of view reads danger the way it always has, and identity on the
## skin is still forbidden.
static func draw_gape(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, gape: float, mouth: StringName, mouth_tier: int,
		threat: bool, fade: float = 1.0, unit: float = 1.0) -> void:
	if gape <= 0.0 or fade <= 0.0:
		return
	var base := at + fwd * (r * OVOID_ALONG * GAPE_SEAT)
	var tone := hue(mouth) if mouth_tier > 0 else SELF_TINT
	var alpha := LIP_ALPHA_BASE + LIP_ALPHA_PER_TIER * float(mouth_tier)
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

## **The organ that is not there yet**: the waiting gene's own kind
## (docs/design/gene-looks.md §4), faint, on a skin lifted [constant GHOST_GAP]
## clear of the body -- and that gap is not a margin, it is the message.
## Measured, not chosen: at 0.13 the ghost sat inside the cirrus oars and the
## gape's starboard stem -- which is seated at t 54, the exact middle of free
## arc 1 -- and the one thing it had to say, *this is not attached*, was the
## thing the crowding took away. At 0.24 it floats outboard of every rowing
## cilium and inboard of the flagellum, in a band of the body nothing else uses.
## **Strokes and outlines only**: an organelle cannot float clear of the skin, so
## its ghost is its outline, unfilled, and a sense's pigment is at the ghost's
## own ink -- filled, the ghost read as an organ, not a hole.
const GHOST_GAP := 0.24          ## of r, skin to the lifted skin
const GHOST_ALPHA := 0.74
## The pigment of a ghost, as a share of its strokes' ink.
const GHOST_PIGMENT := 0.6
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

## Seconds of the sample's life over which the picture wilts. It had a twin in
## signal_bus.gd, `HELD_FADE`, which faded a second heartbeat on the same clock
## so the player never read two; that heartbeat came off the beat on 2026-09-29,
## and the picture is the one clock left.
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
##
## [param offer] is the body held open to place [param gene] (dna-body.md §8):
## `{"aim": slot, "copies": n, "inside": bool}`, or empty -- `aim` is
## [member Genome.INSIDE] for the inside, and `inside` whether it is offered at
## all (dna-slots-ux.md §3.7). See [method _draw_offer].
static func draw_pending(canvas: CanvasItem, at: Vector2, heading: float,
		r: float, order: Array, gene: StringName, remaining: float,
		beat: float, clock: float, fade: float = 1.0,
		unit: float = 1.0, offer: Dictionary = {}) -> void:
	if fade <= 0.0 or r <= 0.0:
		return
	var free := free_arcs(order)
	var aim := -1
	if not offer.is_empty() and gene != &"":
		aim = int(offer.get("aim", -1))
		_draw_offer(canvas, at, heading, r, order, gene,
			int(offer.get("copies", 1)), aim, fade, unit,
			bool(offer.get("inside", false)))
	# Aimed inside, no socket on the skin is being tried: the gene is going to
	# the DNA in the middle of the body, and the thread says so.
	var inward := Genome.is_inside(aim)
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
		# **Held open, the finger decides which hole is being tried**, not the
		# drift: the tuft on the skin and the thread move to the slot that is
		# lit, so the body says the same thing as the bloom outside it -- and
		# on a phone, where the lit bud is under the thumb, the tuft is the half
		# that stays visible. **The inside has no arc to ask for**, and no
		# socket is tried while it is aimed at.
		if inward:
			tried = -1
		elif aim >= 0:
			tried = free.find(arc_for_slot(aim))

	for i in free.size():
		_draw_socket(canvas, at, fwd, stb, r, free[i], tone, i == tried,
			wilt, pulse, fade, unit, gene if held else &"")
	if not held:
		return
	var target := seat
	if tried >= 0:
		target = _socket_bead(at, fwd, stb, r, free[tried])
	elif inward:
		# **Aimed inside, the thread goes to the nucleus** (dna-slots-ux.md
		# §3.7): the DNA, which is where the gene is going.
		target = at - fwd * (r * NUCLEUS_BACK)
	_draw_vesicle(canvas, seat, size, target, tried >= 0 or inward, -fwd, tone,
		wilt, pulse, clock, fade, unit)


## **The body held open** (dna-body.md §8), outboard of it. Every free slot
## blooms as the waiting gene's own organ -- the tile organ the pause screen
## draws, turned to point out along the slot's bearing -- and the one the finger
## is aimed at goes bright, with a line from the skin to it.
##
## **Out at [constant OFFER_REACH] radii and never nearer than
## [constant OFFER_REACH_MIN] canvas px, because the thumb is on the body**: on
## the skin, every bud would be under the finger doing the choosing. The floor
## is in canvas px, through [param unit], so full vision's real-size body blooms
## as far out as the figure's.
##
## **The organ, and not a box, a ring or an arrow**: there is no HUD surface in
## the playfield (diegetic-hud.md §1), and a bud of the gene's own strokes says
## what is being placed and where it will grow in one mark. Only for free slots
## -- nothing here ever offers to write over a gene.
const OFFER_REACH := 2.3
const OFFER_REACH_MIN := 118.0
## The buds not aimed at, then the one that is. Multiplied by the caller's fade,
## so the point-of-view figure's buds sit at its own FADE_PENDING.
const OFFER_ALPHA := 0.34
const OFFER_AIM_ALPHA := 0.95
const OFFER_SCALE := 1.15
## The line to the lit bud starts this share of the reach out, clear of the
## thumb. On a small body that is clear of the rim and the fringe too; once the
## body outgrows [constant OFFER_REACH_MIN] -- about r30 in point of view -- it
## starts just inside the rim (0.97 r), and reads as the bud's thread leaving
## the skin rather than a line laid over it.
const OFFER_LINE_FROM := 0.42
const OFFER_LINE_ALPHA := 0.55
const OFFER_LINE_WIDTH := 1.4
## **The inside, offered** (dna-slots-ux.md §3.7). Its bud is the poison it
## would make, drawn where poison is -- the granule field under the whole skin,
## at [constant OFFER_ALPHA], and at [constant OFFER_AIM_ALPHA] once aimed -- and
## not a bud outside: the one bearing no slot uses is the port flank, and a bud
## there would teach that the inside is your left side. **Aimed, a halo stands
## round the body** at this share of r and never nearer than this many canvas
## px, which clears a thumb resting on it, and every outside bud dims to this:
## the lit thing is under the finger, and the halo is the half of it a thumb
## does not cover.
const OFFER_HALO := 1.45
const OFFER_HALO_MIN := 62.0
const OFFER_HALO_WIDTH := 2.5
const OFFER_HALO_ALPHA := 0.55
const OFFER_HALO_STEPS := 64
const OFFER_OUT_DIM := 0.45


static func _draw_offer(canvas: CanvasItem, at: Vector2, heading: float,
		r: float, order: Array, gene: StringName, copies: int, aim: int,
		fade: float, unit: float, inside: bool = false) -> void:
	var reach := maxf(r * OFFER_REACH, OFFER_REACH_MIN * unit)
	var tone := hue(gene)
	var inward := inside and Genome.is_inside(aim)
	if inside:
		var form := Genome.form_in(gene, Genome.INSIDE_PLACE)
		if form != &"":
			_draw_granules(canvas, at, Vector2(sin(heading), -cos(heading)),
				Vector2(cos(heading), sin(heading)), r, form, copies,
				(OFFER_AIM_ALPHA if inward else OFFER_ALPHA) * fade, unit)
		if inward:
			canvas.draw_arc(at, maxf(r * OFFER_HALO, OFFER_HALO_MIN * unit), 0.0,
				TAU, OFFER_HALO_STEPS, Color(tone, OFFER_HALO_ALPHA * fade),
				OFFER_HALO_WIDTH * unit, true)
	var outside := OFFER_OUT_DIM if inward else 1.0
	for slot in mini(order.size(), BodyPlan.SLOT_MAX):
		if StringName(order[slot]) != &"":
			continue
		# **Each free slot blooms as the form it would make**, and a slot whose
		# form is already carried does not bloom at all: placed there, the gene
		# would add copies to that form where it is and leave this slot empty
		# (dna-slots.md §5.2), which is not what a bud here promises.
		var form := Genome.form_at(gene, slot)
		if form == &"" or (Genome.has_forms(gene) and order.has(form)):
			continue
		var bearing := slot_bearing(slot) + heading
		var dir := Vector2(sin(bearing), -cos(bearing))
		var seat := at + dir * reach
		var lit := slot == aim
		if lit:
			canvas.draw_line(at + dir * (reach * OFFER_LINE_FROM),
				seat - dir * (TILE_ARC_RADIUS * OFFER_SCALE * unit),
				Color(tone, OFFER_LINE_ALPHA * fade), OFFER_LINE_WIDTH * unit,
				true)
		# The tile organ is a dome that opens up the screen; turned by the
		# bearing it opens away from the body, and seated 4 px inboard of its
		# own centre so the strokes, not the arc, reach the seat.
		canvas.draw_set_transform(seat, bearing, Vector2.ONE * unit)
		draw_tile_organ(canvas, form, copies, Vector2(0.0, 4.0),
			(OFFER_AIM_ALPHA if lit else OFFER_ALPHA) * fade * outside, OFFER_SCALE)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	for slot in mini(order.size(), BodyPlan.SLOT_MAX):
		if StringName(order[slot]) == &"":
			out.append(arc_for_slot(slot))
	return out


## One empty socket: the beads that are always there, and -- on the one socket
## the sample is currently reaching for -- the organ it would become, [param gene]'s
## own kind, floating clear of the skin.
##
## **[param tuft] is one socket's privilege, not every free socket's, and the
## render is why.** Drawn on all four holes of a grown cell it was a halo of
## sixteen pale spikes standing off the skin at every diagonal: louder than the
## real fringe, and it read as *this cell has four new organs* rather than as
## *one gene is waiting*. One ghost, on the hole the thread is pointing at, is
## the same sentence at a quarter of the ink -- and because the vesicle drifts,
## a genome with three holes in it is still shown trying each of them in turn,
## which is what the four at once were trying to say and could not.
static func _draw_socket(canvas: CanvasItem, at: Vector2, fwd: Vector2,
		stb: Vector2, r: float, arc: Vector2, tone: Color, tuft: bool,
		wilt: float, beat: float, fade: float, unit: float,
		gene: StringName = &"") -> void:
	var dot := maxf(r * VACANCY_DOT, VACANCY_DOT_MIN * unit)
	# **Only the socket being tried brightens.** Lifting every free socket when
	# a sample arrived put sixteen bright beads round the rim of a grown cell
	# and the figure grew a necklace; the quiet ones stay quiet, which is what
	# *there is also room over here* is worth.
	var ink := clampf(VACANCY_ALPHA * (VACANCY_HELD if tuft else 1.0), 0.0, 1.0)
	canvas.draw_circle(_socket_bead(at, fwd, stb, r, arc), dot,
		Color(tone, ink * fade), true, -1.0, true)
	if not tuft or gene == &"":
		return
	# **The ghost stays on the skin and the bead has moved off it.** The two say
	# different things now: the bead is the hole in the DNA, by the nucleus,
	# where the gene is actually going; the ghost is the organ that hole would
	# become, drawn where an organ would stand and not touching the body -- on the
	# body's own skin lifted [constant GHOST_GAP] clear, at the body's own scale.
	# They are on the same bearing, so the thread, the bead and the ghost read as
	# one line out from the middle.
	var sk := Stretch.new()
	_on_body(sk, at, fwd, stb, r * (1.0 + GHOST_GAP), unit)
	sk.unit = r
	sk.a0 = arc.x
	sk.a1 = arc.y
	var ghost := GHOST_ALPHA * (0.34 + 0.66 * wilt) * (1.0 + GHOST_BEAT * beat) * fade
	var look := _look_of(gene)
	var d := Drawn.new()
	_build(d, sk, look, 1, 0.0, 1.0)
	_paint(canvas, d, look, tone, ghost, GHOST_WIDTH * unit, sk, NO_EYE, 0.0,
		ghost * GHOST_PIGMENT, true)


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

## The organ on a genome tile: **its own kind on the tile's dome** -- the same
## generator a body is drawn by, at the tile's scale (docs/design/gene-looks.md
## §2.2) -- so the tile and the body are one vocabulary. An inside form is the dome,
## a pigment and its beads on an arc just outside it: its granules, at a tile's
## size. [param size] is the tile's own rect.
##
## [param alpha] is the second, weaker channel behind the pips: a gene the DNA
## carries and the body does not wear draws its strokes fainter. The pips do the
## work -- see normal_mode.gd's tile face -- and this is honest about which one
## is which.
## [param scale] shrinks the whole drawing about [param centre]. The strand has
## no 76px tile to put an organ in, so the one organ on the pause screen is the
## **selected** gene's, drawn once beside the sentence that explains it -- which
## is a smaller row than a tile and needs the geometry to come with it.
##
## **Tier is drawn as rungs by the strand itself**, so a tile is always one copy:
## at 13 pixels a 22% length difference is one pixel, so magnitude cannot carry it
## here the way it does on a body. This is the one place the two vocabularies
## deliberately differ, and the tile says why -- it is a label, not an organism.
static func draw_tile_organ(canvas: CanvasItem, gene: StringName, _tier: int,
		centre: Vector2, alpha: float = TILE_STROKE_ALPHA,
		scale: float = 1.0) -> void:
	var tone := hue(gene)
	var ink := alpha / TILE_STROKE_ALPHA
	var arc_r := TILE_ARC_RADIUS * scale
	canvas.draw_arc(centre, arc_r, TILE_ARC_FROM, TILE_ARC_TO, 32,
		Color(tone, TILE_ARC_ALPHA * ink), TILE_ARC_WIDTH * scale, true)
	var look := _look_of(gene)
	if Genome.is_inside_form(gene):
		canvas.draw_circle(centre + Vector2(0.0, -arc_r * PIGMENT_SEAT),
			TILE_PIGMENT * scale, Color(tone, 0.85 * ink), true, -1.0, true)
		var mark := _bead_mark(look)
		for granule: Vector2 in _tile_granules(centre, arc_r, scale):
			_draw_bead(canvas, granule, TILE_GRANULE_R * scale, tone, alpha, 0.0, mark,
				(granule - centre).orthogonal().normalized())
		return
	var sk := _tile_skin(centre, arc_r, scale)
	var d := _drawn
	d.clear()
	_build(d, sk, look, 1, 0.0, 1.0)
	_paint(canvas, d, look, tone, alpha, TILE_ARC_WIDTH * scale * _tile_width(look), sk,
		NO_EYE, 0.0, 1.0, false)


## An inside form's granules on a tile: seven, on an arc just outside the dome.
static func _tile_granules(centre: Vector2, arc_r: float, scale: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in TILE_GRANULES:
		var u := (float(i) + 0.5) / float(TILE_GRANULES)
		var angle := lerpf(TILE_ARC_FROM - 0.15, TILE_ARC_TO + 0.15, u)
		out.append(centre + Vector2(cos(angle), sin(angle))
			* (arc_r + TILE_GRANULE_OUT * scale))
	return out


## A kind's stroke on a tile, against the tile's own width.
static func _tile_width(look: Dictionary) -> float:
	if look["shape"] == SPINES and look["tip"] == Kinds.TIP_BEAD:
		return TILE_SPINE_WIDTH
	return 1.0


## **Where [param gene]'s tile organ reaches**, at one scale, about its centre: the
## dome, every stroke, curve, fill and mark the tile draws -- with half a stroke's
## width and a mark's own reach -- built by the same generator and drawn on nothing.
## What the gene probe holds every live organ's tile to: inside a tile, and under
## the explaining line's row (gene-looks.md §8, check 4).
static func tile_bounds(gene: StringName) -> Rect2:
	var look := _look_of(gene)
	var width := TILE_ARC_WIDTH * _tile_width(look)
	var box := Rect2(Vector2(cos(TILE_ARC_FROM), sin(TILE_ARC_FROM)) * TILE_ARC_RADIUS,
		Vector2.ZERO)
	for k in 33:
		var a := lerpf(TILE_ARC_FROM, TILE_ARC_TO, float(k) / 32.0)
		box = box.expand(Vector2(cos(a), sin(a)) * TILE_ARC_RADIUS)
	box = box.grow(TILE_ARC_WIDTH * 0.5)
	if Genome.is_inside_form(gene):
		box = box.merge(Rect2(Vector2(0.0, -TILE_ARC_RADIUS * PIGMENT_SEAT), Vector2.ZERO)
			.grow(TILE_PIGMENT))
		for granule: Vector2 in _tile_granules(Vector2.ZERO, TILE_ARC_RADIUS, 1.0):
			box = box.merge(Rect2(granule, Vector2.ZERO).grow(maxf(TILE_GRANULE_R,
				ACCENT_BEAD_MIN) * 1.5))
		return box
	var sk := _tile_skin(Vector2.ZERO, TILE_ARC_RADIUS, 1.0)
	var d := Drawn.new()
	_build(d, sk, look, 1, 0.0, 1.0)
	var points := d.lines.duplicate()
	for path: PackedVector2Array in d.paths:
		points.append_array(path)
	for fill: Array in d.fills:
		points.append_array(fill[0])
	for point: Vector2 in points:
		box = box.merge(Rect2(point, Vector2.ZERO).grow(width * 0.5))
	for one: Array in d.marks:
		var reach := float(one[2])
		if one[0] == Kinds.SEAT_BEADS and look["mark"] != Kinds.MARK_DISC:
			reach = maxf(reach, ACCENT_BEAD_MIN)
		# A diamond reaches 1.25 of its size, a bar 1.5, a ring 1.05 and its stroke.
		box = box.merge(Rect2(one[1], Vector2.ZERO).grow(reach * 1.5))
	return box


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
##
## **[param ring] is the bezel, and it is only a bezel where there is a
## bearing.** On a locus the circle is the compass this dart is a needle on --
## it says *this is a direction around the body*, and without it the dart is an
## arrow floating in a label row. A turn pad borrows the dart for the opposite
## job: it is a caption under a tuft of oars, there is no compass and no
## bearing, and a circle there is the one shape diegetic-hud.md section 4 spends
## its rule against -- *rounded rectangles, never circles*, because a ring is
## what the water is made of. So the caller says whether its dart is on a
## compass. Every existing caller is, and passes nothing.
static func draw_slot_dart(canvas: CanvasItem, slot: int, tone: Color,
		centre: Vector2, radius: float = TILE_COMPASS_R,
		ring: bool = true) -> void:
	if slot < 0:
		return
	# **The inside points nowhere** (dna-slots-ux.md §3.8): its mark is a ring
	# with a seed in it -- a body with something inside -- where every outside
	# slot has a dart.
	if Genome.is_inside(slot):
		canvas.draw_arc(centre, radius, 0.0, TAU, 24, Color(tone, 0.80), 1.4, true)
		canvas.draw_circle(centre, radius * 0.38, Color(tone, 0.95), true, -1.0,
			true)
		return
	if ring:
		canvas.draw_arc(centre, radius, 0.0, TAU, 20, Color(tone, 0.28), 1.0,
			true)
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

## The ping wavefront's arc resolution, shared by both views so the seam inset
## that hides the double-composited vertex cannot drift between them.
const WAVE_STEPS := 64
const WAVE_SEAM := PI / (2.0 * WAVE_STEPS)


## **The slot is the arc is the bearing**, and there is one place that says so.
## The live run and the replay both resolve a directional organ's bearing here;
## an organ the body does not wear answers dead ahead.
static func bearing_of(genome: Genome, gene: StringName) -> float:
	if genome == null:
		return 0.0
	var slot: int = genome.slot_of(gene)
	return slot_bearing(slot) if slot >= 0 else 0.0


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


## **A replication fork**: the weave from [param from] onward, and then its two
## strands stop winding and part (beam-levels.md §8.3). It is how a slot says
## *a choice is waiting here*, and it changes the chip's outline rather than
## only its colour, so it survives greyscale. The pause screen's forking slot
## draws it, and so does the fork's chip in the tray, which is why it lives
## here and not with either of them.
##
## The strands part at **the last crest before [param to]**, where they are
## already furthest apart and running level -- so the parting leaves the helix
## without a kink. From there to [param to] each swings out by a further
## [param spread] as the square of the way along, and blends from its depth
## colour to [param tone] at 0.9, so the two tips carry the gene's hue.
## [param from], [param to] and the swing are in the same `along` units as
## [method draw_weave]'s, counted from the helix's own origin (its `lobe0` 0),
## so the two calls meet exactly when one takes over from the other.
## [param bright] is the weave's own, and dims the tips with it.
static func draw_fork(canvas: CanvasItem, axis: int, lobe: float, mid: float,
		amp: float, from: float, to: float, spread: float, tone: Color,
		bright: float) -> void:
	var split := lobe * (floorf(to / lobe - 0.5) + 0.5)
	if split < from:
		split = from
	# Which strand is on which side at the crest: the parting carries it on.
	var lean := signf(sin(strand_phase(split, 0, lobe)))
	if lean == 0.0:
		lean = 1.0
	var a_pts := PackedVector2Array()
	var b_pts := PackedVector2Array()
	var a_col := PackedColorArray()
	var b_col := PackedColorArray()
	var winding := maxi(int(ceilf((split - from) / lobe * float(STRAND_STEPS))),
		0)
	for i in winding + 1:
		var along := lerpf(from, split, float(i) / float(maxi(winding, 1)))
		var t := strand_phase(along, 0, lobe)
		var swing := amp * sin(t)
		a_pts.append(strand_point(axis, along, mid - swing))
		b_pts.append(strand_point(axis, along, mid + swing))
		var near := 0.5 * (cos(t) + 1.0)
		a_col.append(Color(STRAND_BACKBONE, lerpf(STRAND_BACK, STRAND_FRONT,
			near) * bright))
		b_col.append(Color(STRAND_BACKBONE, lerpf(STRAND_FRONT, STRAND_BACK,
			near) * bright))
	# The parting. Its first point is the crest the weave just reached, so the
	# polyline carries straight on; each strand's colour leaves the depth colour
	# it had there.
	var t0 := strand_phase(split, 0, lobe)
	var near0 := 0.5 * (cos(t0) + 1.0)
	var a_from := Color(STRAND_BACKBONE, lerpf(STRAND_BACK, STRAND_FRONT, near0)
		* bright)
	var b_from := Color(STRAND_BACKBONE, lerpf(STRAND_FRONT, STRAND_BACK, near0)
		* bright)
	var tip := Color(tone, 0.9 * minf(bright, 1.0))
	var parted := maxi(int(ceilf((to - split) / lobe * float(STRAND_STEPS))) * 2,
		1)
	for i in range(1, parted + 1):
		var u := float(i) / float(parted)
		var along := lerpf(split, to, u)
		var swing := lean * (amp + spread * u * u)
		a_pts.append(strand_point(axis, along, mid - swing))
		b_pts.append(strand_point(axis, along, mid + swing))
		a_col.append(a_from.lerp(tip, u))
		b_col.append(b_from.lerp(tip, u))
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


## The outward normal turned [param angle] toward the nose ([member _at_lean]).
## Every swing in §4.2 is measured this way, so there is one definition of which
## way a cilium leans.
static func _swung(normal: Vector2, nose: Vector2, angle: float) -> Vector2:
	return (normal * cos(angle) + nose * sin(angle)).normalized()


static func _tier(ladder: Array[float], tier: int) -> float:
	return ladder[clampi(tier, 0, ladder.size() - 1)]


static func _count(base: int, tier: int) -> int:
	return maxi(1, int(roundf(float(base) * _tier(TIER_COUNT, tier))))


## [param value] made read-only and handed back.
static func _frozen(value: Dictionary) -> Dictionary:
	value.make_read_only()
	return value
