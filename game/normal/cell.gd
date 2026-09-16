extends Node
## The player's cell: a position, a heading, and a drive that is not obedient.
##
## The basic cell has one organelle and no steering muscle worth the name. It
## fires a random forward impulse on its own schedule and coasts; the player can
## lean on its orientation, slowly. Movement being sluggish and slippery is the
## design, not a bug to be tuned out -- see docs/design/perception.md §2, where
## the whole opening depends on drift the player does not command.
##
## Nothing here is drawn. The cell *is* the viewport; what it feels comes out on
## the membrane.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## Emitted when an impulse fires, so the membrane can bloom at the front.
signal impulsed(strength: float)
## `myoneme` -- a burst of speed the player asked for, and what it cost. The
## cell cannot spend hunger itself: metabolism belongs to the run, so the price
## rides out on the signal and the run pays it.
signal dashed(cost: float)

## Body radius in world units. A variable, not a constant, because it is the one
## number in the game that means three things at once: what can eat me, what I
## can eat, and how much genome I can carry.
## docs/design/genes-and-cilia.md §1.1 and §3.1.
const BASE_RADIUS := 26.0
## One meal, four units of radius. **A generation is three meals**, which is the
## owner's "divide the split requirements by four": a daughter is born at 28.28
## and divides at 40, so `(40 - 28.28) / 4` is 2.93.
##
## This is the dial and [constant DIVIDE_RADIUS] is not, because forty carries
## three couplings a smaller number would break: `slots_for(40)` is 7, the body
## has exactly seven arcs, and `food.ARRIVAL_GAPE_MAX` is 40 so the water never
## seeds a mouth that can swallow a full-grown cell in one contact.
##
## **It is the whole water's growth, not the player's.** food.gd's `_devour`
## reads the same constant, so a cell that has been feeding grows four times
## faster too -- docs/design/genes-and-cilia.md §1.2 gets louder rather than
## being switched off for everything except the player, which is the one thing
## §1.3 forbids.
const GROWTH_PER_MEAL := 4.0

var radius := BASE_RADIUS

# --- Integrity -------------------------------------------------------------
# **What a mouth does to a body it cannot swallow.** The gape rule still decides
# *swallowed whole* against *bitten*, so everything §1.1.1 draws still means what
# it meant; this is what happens on the other side of that line. It is a
# property of a body and not of the player, so every cell in the water carries
# one -- food.gd's Body has the same field, mended by the same static below.

## How long a body takes to knit a whole wound back up, in seconds of not being
## bitten. Slow enough that a fight is not undone by swimming away for a moment,
## fast enough that surviving one means something. **The first number to move if
## biting feels wrong**, ahead of the bite table below.
const MEND_SECONDS := 75.0

## `cytostome` / bite. What one bite takes out of a body too big to swallow,
## before the target's skin is taken into account. Tier 0 is a cell with no
## mouth at all and it is a hard zero, not an extrapolated step: drifters have
## no cytostome, and a floor that could chew on you would not be a floor.
const BITE_BY_TIER: Array[float] = [0.0, 0.07, 0.10, 0.14]
## Seconds between bites from one mouth. One mouth, one bite, whatever it is
## resting against -- so a cell wedged between two others does not chew both.
const BITE_GAP := 0.85
## `toxicyst` / venom, from the other end. Swallowing a venomous cell already
## kills the swallower; *biting* one costs this share of the damage just dealt,
## which makes venom the answer to being gnawed as well as to being eaten.
const VENOM_BITE_BACK_BY_TIER: Array[float] = [0.0, 0.35, 0.55, 0.80]

## Where on a body a bite lands, and therefore how much of it lands. The nose is
## 1.0 because that is where the target's own mouth is and where it is thickest;
## astern nothing it has can answer. A cosine, so there is no angle at which the
## damage steps. docs/design/edibility.md §1.2.
##
## **2.10 is the number to move, and it is the whole difficulty of flanking.**
## It is not measurable from a still frame; it is the first thing to change if
## taking a big cell apart feels either hopeless or free.
const FLANK_AHEAD := 1.00
const FLANK_ASTERN := 2.10

## How far off the arc it is worn on a `trichocyst` can answer. The dart used to
## be a scalar range and fired at whatever was near, which under a positional
## rule is a defence with no position: **a dart in a rear slot is the answer to
## being flanked**, and placement becomes a defensive decision rather than only
## an offensive one. §2.
const DART_ARC_DEG := 110.0

## 0 is whole and 1 is a body that has come apart. There is no bar for this
## anywhere: point of view feels each bite as a `hit` at the bearing it came
## from, and full vision draws the tears (cilia.gd).
var wound := 0.0

## The genome this cell wears. Written by normal_mode.gd, which is the only
## place the two halves are introduced to each other.
##
## Deliberately typed as plain [Node]: genome.gd preloads *this* file for the
## slot ladder, and a preload back the other way is a cycle GDScript will not
## resolve. Null is legal and means the born cell -- nothing in here may assume
## the wiring has happened, because a headless boot builds this node first.
var genome: Node = null

# --- The gape --------------------------------------------------------------
## How wide the mouth opens, as a multiple of body radius, by cytostome tier.
## Index 0 is a cell with no mouth at all, which is a real state: drifters have
## no cytostome, and §9.7 lets the player put a fourth gene over their own.
##
## **The gape keeps its job and loses its veto.** It used to be the whole
## edibility rule; docs/design/edibility.md §1 withdraws that. You can attack
## anything -- the gape decides whether you swallow it whole (`B.radius <
## A.gape()`, evaluated in both directions independently) or have to take it
## apart a bite at a time, and [method bite_damage]'s `min(gape / radius, 1)`
## keeps the two continuous with each other.
const GAPE_BY_TIER: Array[float] = [0.58, 0.82, 1.05, 1.40]

# --- Slots -----------------------------------------------------------------
## Genome size is capacity, not currency: one more slot per this much growth.
## Three slots at birth, seven at radius 40 -- and seven is every arc a body
## has, which is why [constant DIVIDE_RADIUS] is where it divides. §3.1.
##
## **Unchanged by the four-times growth, and the interval is why.** Two fixed
## points pin it: `slots_for(26)` must be 3 and `slots_for(40)` must be 7, which
## needs `14 / SLOT_RADIUS` in `[4, 5)` -- so the only legal values are
## `(2.8, 3.5]` and 3.5 is already the top of that range. There is no dial here
## to compensate with; what four-times growth really changes is that **capacity
## stops being the binding constraint in the first generation** and the seven
## arcs and the expression roll become it instead. From generation two a newborn
## is over capacity anyway (lifecycle.md §3.1), which is where the swap
## decision lives now.
const SLOT_RADIUS := 3.5
const SLOT_MIN := 3
const SLOT_MAX := 7

# --- The end of a body, and the beginning of two -----------------------------
# docs/design/lifecycle.md §2. **Forty is where a body runs out of places to put
# an organ**: SLOT_MAX is 7, the body has exactly seven arcs, and slots_for(40)
# is 7. Growth past it is the one thing a cell can do that buys nothing it can
# pass on, so the player's radius clamps here and the body divides instead.
#
# The old justifications for 40 -- "nothing left in the water can eat you" and
# "the genome fills on the same meal" -- are both withdrawn by
# docs/design/edibility.md §4 and by measurement respectively. The capacity
# argument stands on its own and is the only one left.

## Where a body divides, and where its radius stops.
const DIVIDE_RADIUS := 40.0
## Two meals out, and where the nucleus starts to double.
##
## **Moved from 37 with [constant GROWTH_PER_MEAL], because it is written in
## meals and not in units.** At four units a meal, a warning starting at 37 is
## three quarters of one meal wide: a cell at 36.28 shows nothing and the next
## mouthful takes it straight to 40, so the most legible "about to divide"
## image in the game would have fired on no frame anybody saw.
const DIVIDE_WARN_RADIUS := 32.0
## Of the mother's **area**, not her radius -- so a daughter is 40/sqrt(2) and
## slots_for(28.28) is 3, the same room to manoeuvre a run starts with. None of
## that was arranged; it falls out of conserving area on a ladder that was
## already there.
const DIVIDE_SPLIT := 0.5


## What each daughter of a body of [param mother_radius] is born at.
static func daughter_radius(mother_radius: float = DIVIDE_RADIUS) -> float:
	return mother_radius * sqrt(DIVIDE_SPLIT)

# --- Drive -----------------------------------------------------------------
# Every number in this block is indexed by a gene tier rather than fixed, and
# the mapping lives here -- next to the constant it replaces -- for the same
# reason perception.md §6.2 put the hunger-to-beat mapping in one place. §7.2.
#
# Tier 0 is the cell that has lost this organ entirely (§9.7 allows it). It is
# **not in the design**: it is extrapolated one step below tier 1 on the
# ladder's own spacing, which is the least invented answer available.

## Speed added along the heading by one flagellar beat, by `flagellum` tier.
const IMPULSE_SPEED_BY_TIER: Array[float] = [118.0, 138.0, 162.0, 190.0]
## Seconds between impulses, resampled after each one, by `flagellum` tier.
const IMPULSE_GAP_MIN_BY_TIER: Array[float] = [2.00, 1.70, 1.45, 1.20]
const IMPULSE_GAP_MAX_BY_TIER: Array[float] = [4.30, 3.60, 3.00, 2.50]
## Mean of the per-impulse strength roll below, for [method speed_for].
const IMPULSE_MEAN := 0.85
## Net speed over path speed. One impulse of v0 decaying at DRAG contributes
## exactly v0/DRAG of displacement however long it is left to, so a train of
## them every T seconds makes v0/(DRAG*T) along the heading and there is no free
## parameter in it -- except that the heading is not straight. This is the
## measured shortfall, set so a tier-1 cell comes out at the 56.5 u/s that
## Phase 4 measured over 40 seeds and hard-coded into the pursuit.
const SPREAD_LOSS := 0.945
## The organelle does not aim well: each impulse strays this far off the heading
## and kicks the heading itself by about this much.
const IMPULSE_SPREAD := 0.24
const IMPULSE_KICK := 0.16
## Water is thick at this scale. Velocity loses 1/e of itself every 1/DRAG s.
const DRAG := 0.74

# --- What the earned genes buy ----------------------------------------------
# Same shape as the three ladders above: index by tier, index 0 is "does not
# have this organ". They live here because this is where "what the genome buys"
# lives; the *effects* land in food.gd (what the water does to you), in
# metabolism.gd (what it costs) and on the signal bus (what it feels like).

## `ocellus` / beam. How far the beam reaches, how many of them there are, and
## how wide they fan either side of the arc they are worn on.
##
## **Count is tier, not copies, and that is a divergence worth writing down.**
## The design asks for one beam per copy of the gene in the genome, so a genome
## full of ocelli approaches full vision. A genome is a `{gene: tier}` map, so
## it cannot hold the same gene twice -- a second one raises the tier instead.
## Tier therefore buys the beams, and the fan widens with it so that three beams
## sweep 100 degrees rather than sitting on top of each other. Real per-copy
## stacking needs a slot-keyed genome, which is a refactor and not a speed run.
const BEAM_RANGE_BY_TIER: Array[float] = [0.0, 620.0, 900.0, 1240.0]
const BEAM_COUNT_BY_TIER: Array[int] = [0, 1, 2, 3]
const BEAM_FAN_DEG_BY_TIER: Array[float] = [0.0, 0.0, 22.0, 50.0]

## `chemocyte` / smell. **How far this cell's chemoreceptors reach.** The scent
## field itself is unchanged -- what the water is doing is not a function of who
## is sniffing it -- but only sources inside this radius reach the taste lobe,
## so a poor nose smells what is near and a good one smells the whole field.
##
## Tier 0 is a cell with no chemoreceptor at all, and it is **not** the
## extrapolated step the drive tables use: it is a hard zero, because taste is
## now a gene and a cell without it gets no bearing to food whatsoever. Tier 3
## is food.gd's SCENT_RANGE, so a saturated nose is exactly the always-on taste
## every build before this one shipped with.
const SMELL_RANGE_BY_TIER: Array[float] = [0.0, 1100.0, 1350.0, 1600.0]

## `ampulla` / ping. Electroreception: a pulse every so often, and the bearing
## of **every** body it comes back off, edible or not. That is the difference
## from `chemocyte` -- the scent field can only ever describe a meal, and most
## of what matters in this water is not a meal.
##
## Range and rate both climb, because a radar is worth having for how far it
## reaches and for how often it tells you.
const PING_RANGE_BY_TIER: Array[float] = [0.0, 1100.0, 1500.0, 1900.0]
const PING_PERIOD_BY_TIER: Array[float] = [0.0, 3.2, 2.2, 1.4]

## `axoneme` / push. Acceleration along the heading while the player holds, in
## units per second squared. **This is the flagellum made voluntary**: the
## random involuntary impulse keeps firing underneath it at whatever tier the
## flagellum is, and this adds a push you asked for on top.
##
## Held against DRAG these settle at 81 / 115 / 155 units per second, against a
## born cell's realised 56.5. **Measured, and the first numbers were wrong by a
## factor of two**: at 230 the terminal speed is 310, and since the chase scales
## its cruise off the prey's own speed, a hunter could not physically close on a
## pushing cell at any tier. Dread stopped meaning anything, which is most of
## the game.
const PUSH_ACCEL_BY_TIER: Array[float] = [0.0, 60.0, 85.0, 115.0]
## How much of that terminal speed the water assumes you are using when it leads
## a chase. **The other half of the same fix**: a hunter that scaled to your
## flagellum alone would be outrun by a gene it cannot see. Half, because you
## are not pushing all of the time -- so a pushing cell is still faster than the
## lead it is given, and a coasting one is over-led and easier to dodge. Both of
## those are the right way round.
const PUSH_CHASE_SHARE := 0.5

## `myoneme` / dash. A burst of speed for a tap, paid for in hunger -- a better
## myoneme is a cheaper dash, not a bigger one, so it stays a decision.
const DASH_SPEED_BY_TIER: Array[float] = [0.0, 190.0, 240.0, 300.0]
const DASH_COST_BY_TIER: Array[float] = [0.0, 0.060, 0.045, 0.032]
const DASH_COOLDOWN := 1.4
## A press shorter than this, that moved less than this far, is a tap and not a
## steer. Both halves matter: a thumb that slid is steering.
const TAP_SECONDS := 0.28
const TAP_SLOP := 26.0

## `pellicle` / armor. Your body as another cell's mouth measures it, so a gape
## that could just swallow you no longer can.
const ARMOR_BY_TIER: Array[float] = [1.0, 1.14, 1.30, 1.52]

## `vacuole` / store. Hunger rises this much more slowly, because there is more
## of you to run down.
const STORE_BY_TIER: Array[float] = [1.0, 1.28, 1.60, 2.00]

## `crista` / burn. A multiplier on upkeep, applied in genome.gd where upkeep is
## computed -- the only gene that makes a strong build cheaper to carry.
const BURN_BY_TIER: Array[float] = [1.0, 0.88, 0.77, 0.66]

## `plastid` / sun. Passive feeding, as a fraction of one upkeep unit cancelled
## outright. At tier 3 a third of a resting cell's hunger never happens.
const SUN_BY_TIER: Array[float] = [0.0, 0.12, 0.22, 0.34]

## `palp` / touch. How far the cell can feel a body with no light at all.
const TOUCH_RANGE_BY_TIER: Array[float] = [0.0, 150.0, 230.0, 330.0]

## `trichocyst` / sting. How close a cell hunting you gets before the dart goes
## off, and how long before there is another one.
const DART_RANGE_BY_TIER: Array[float] = [0.0, 130.0, 190.0, 260.0]
const DART_COOLDOWN_BY_TIER: Array[float] = [0.0, 26.0, 18.0, 11.0]

## `toxicyst` / venom. What surviving being eaten costs, in hunger. A cell that
## swallows you dies of it and you are spat out starving.
const VENOM_COST_BY_TIER: Array[float] = [0.0, 0.46, 0.34, 0.22]

## `statocyst` / level and `rhabdom` / focus buy no number here: one is a lobe
## on the membrane at a bearing that does not turn with the body, the other
## narrows a lobe that already exists. Both live in signal_bus.gd, which owns
## every envelope and every lobe.

# --- Steering --------------------------------------------------------------
## Flat out, the cell turns this fast, by `cirrus` tier. Tier 1 is about
## 35 deg/s, so a half turn costs five seconds: slow on purpose. Tier 3 is
## 58 deg/s, and §7.1 gives the whole of the improved dodge to this one number.
const TURN_RATE_BY_TIER: Array[float] = [0.48, 0.62, 0.80, 1.02]
## Seconds for the turn to actually build. The lag is what makes steering feel
## like leaning on something rather than driving it; a better cirrus shortens it.
const TURN_RESPONSE_BY_TIER: Array[float] = [1.43, 1.10, 0.85, 0.65]
## The water pushes back: a slow random walk on the heading the player never
## asked for and cannot switch off.
const WANDER_RATE := 0.13
const WANDER_TAU := 2.6

# --- Input -----------------------------------------------------------------
## Canvas pixels of drag for a full-rate turn.
const DRAG_SPAN := 190.0
## Below this the player is not really steering, so onboarding stays up.
const STEER_DEADZONE := 0.12

## Nothing held. Touch indices are >= 0 and the mouse is -1, so -2 is free.
const POINTER_NONE := -2
const POINTER_MOUSE := -1

var position := Vector2.ZERO
## Radians, clockwise from world north. Front is the top of the screen.
var heading := 0.0
var velocity := Vector2.ZERO
## Signed steering demand, -1 hard to port .. +1 hard to starboard.
var steer := 0.0

var _omega := 0.0
var _wander := 0.0
var _impulse_timer := 0.0
var _dash_timer := 0.0
## When the current press started and where, so a tap can be told from a steer.
var _pointer_at := 0.0
var _pointer_from := 0.0
## -2 nothing held, -1 the mouse, >= 0 the touch index that owns the drag.
## **One slot, and that is correct for `anywhere` and only for `anywhere`**: a
## resting palm must not fight the steering thumb when the whole screen is the
## control. The other two schemes need a finger per control, and that lives in
## [member controls], keyed by pointer index -- so `port` and `push` can be held
## at once, and a dash can be fired while the stick is deflected.
var _pointer := POINTER_NONE
var _pointer_anchor := 0.0
var _pointer_x := 0.0

## The drawn controls, or null under `anywhere` and in any scene that has none.
## **Untyped on purpose.** cilia.gd preloads genome.gd, which preloads this
## file, and controls.gd preloads cilia.gd -- so a preload back the other way
## would be a cycle GDScript will not resolve.
var controls: Node = null


func _ready() -> void:
	_impulse_timer = randf_range(0.6, 1.4)


## A new cell in new water, for the restart after a death.
##
## [param keep_place] is a birth rather than a restart: a daughter carries on
## from where her mother was and pointing the way her mother pointed, so the
## world view's camera does not jump at the one moment the player is looking
## hardest at the middle of the screen. Everything else about her is new.
func reset(keep_place: bool = false) -> void:
	if not keep_place:
		position = Vector2.ZERO
		heading = randf_range(-PI, PI)
	velocity = Vector2.ZERO
	radius = BASE_RADIUS
	wound = 0.0
	_omega = 0.0
	_wander = 0.0
	_impulse_timer = randf_range(0.6, 1.4)
	_dash_timer = 0.0
	release()


func _process(delta: float) -> void:
	steer = _read_steer()

	# The body knits itself back up whenever nothing is chewing on it. Here
	# rather than in the water, because it is a thing a body does and not a
	# thing that happens to it -- and because _set_simulating() stops this node
	# on a death, which is exactly when it should stop.
	wound = mended(wound, delta)

	_omega = lerpf(_omega, steer * turn_rate(), 1.0 - exp(-delta / turn_response()))
	# Ornstein-Uhlenbeck-ish drift: a heading nudge that wanders instead of
	# buzzing, so it reads as current rather than as noise.
	var pull := 1.0 - exp(-delta / WANDER_TAU)
	_wander = lerpf(_wander, randf_range(-WANDER_RATE, WANDER_RATE), pull)
	heading = wrapf(heading + (_omega + _wander) * delta, -PI, PI)

	_impulse_timer -= delta
	if _impulse_timer <= 0.0:
		_fire_impulse()

	# `axoneme`: thrust you asked for, on top of the involuntary one. Held keys
	# on desktop, a finger on the screen anywhere on touch -- the same gesture
	# that steers, because pushing and turning are things you do together and a
	# second control would cost a pixel of screen the design does not have.
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	var push := PUSH_ACCEL_BY_TIER[_tier_index(extra(&"axoneme"))]
	if push > 0.0 and _pushing():
		velocity += forward() * push * delta

	velocity *= exp(-DRAG * delta)
	position += velocity * delta


func _fire_impulse() -> void:
	_impulse_timer = randf_range(impulse_gap_min(), impulse_gap_max())
	heading = wrapf(heading + randf_range(-IMPULSE_KICK, IMPULSE_KICK), -PI, PI)
	var strength := randf_range(0.7, 1.0)
	var aim := heading + randf_range(-IMPULSE_SPREAD, IMPULSE_SPREAD)
	velocity += Vector2(sin(aim), -cos(aim)) * impulse_speed() * strength
	impulsed.emit(strength)


# ---------------------------------------------------------------------------
# What the genome buys. Every one of these is a read, not a stored value: a
# gene integrated mid-run has to take effect on the next frame, and a cached
# copy is one more thing that can be stale when it matters.
# ---------------------------------------------------------------------------

## Tier of one gene, 1 if there is no genome attached yet -- the born cell is
## tier 1 across the board, so an unwired cell behaves exactly as Phase 4 did.
func tier(gene: StringName) -> int:
	return genome.tier(gene) if genome != null else 1


## Tier of an **earned** gene, 0 if there is no genome attached yet. Separate
## from [method tier] on purpose: that one answers 1 for an unwired cell because
## the born cell is tier 1 at the three home organs, and answering 1 for a gene
## nobody has grown would hand a headless boot a laser.
func extra(gene: StringName) -> int:
	return genome.tier(gene) if genome != null else 0


## How wide this cell's mouth opens, in world units. Anything whose radius is
## below this fits in it, and nothing else does.
func gape() -> float:
	return gape_of(tier(&"cytostome"), radius)


## **How big this body is to a mouth**, which `pellicle` makes larger than it
## looks. Every "can that eat me" test in the water reads this and not
## [member radius]; every "how much is that worth" test reads the radius, so
## armour never made you a bigger meal.
func swallow_radius() -> float:
	return radius * ARMOR_BY_TIER[_tier_index(extra(&"pellicle"))]


## How far this cell's beams reach, 0 for a cell with no ocellus. Which way
## they point is a question about the genome's *layout*, and it is asked where
## the arc table lives -- this file cannot preload cilia.gd, because
## cilia -> genome -> cell would be a preload cycle.
func beam_range() -> float:
	return BEAM_RANGE_BY_TIER[_tier_index(extra(&"ocellus"))]


## How far this cell can smell, 0 for a cell with no `chemocyte`.
func smell_range() -> float:
	return SMELL_RANGE_BY_TIER[_tier_index(extra(&"chemocyte"))]


## How far a ping carries, 0 for a cell with no `ampulla`.
func ping_range() -> float:
	return PING_RANGE_BY_TIER[_tier_index(extra(&"ampulla"))]


## Seconds between pings, 0 for a cell with no `ampulla`.
func ping_period() -> float:
	return PING_PERIOD_BY_TIER[_tier_index(extra(&"ampulla"))]


## How many genes this body can carry.
func slots() -> int:
	return slots_for(radius)


func impulse_speed() -> float:
	return IMPULSE_SPEED_BY_TIER[_tier_index(tier(&"flagellum"))]


func impulse_gap_min() -> float:
	return IMPULSE_GAP_MIN_BY_TIER[_tier_index(tier(&"flagellum"))]


func impulse_gap_max() -> float:
	return IMPULSE_GAP_MAX_BY_TIER[_tier_index(tier(&"flagellum"))]


func turn_rate() -> float:
	return TURN_RATE_BY_TIER[_tier_index(tier(&"cirrus"))]


func turn_response() -> float:
	return TURN_RESPONSE_BY_TIER[_tier_index(tier(&"cirrus"))]


## The net speed this cell actually makes, which is what anything chasing it
## has to lead. §7.1: this replaces Phase 4's hard-coded 56.5, so the chase
## stays a chase at every tier and only `cirrus` improves the dodge.
func swim_speed() -> float:
	return speed_for(tier(&"flagellum")) + PUSH_CHASE_SHARE \
		* PUSH_ACCEL_BY_TIER[_tier_index(extra(&"axoneme"))] / DRAG


# --- The same, for a cell that is not this one -----------------------------
# Every other body in the water is a `{gene: tier}` dictionary in food.gd, not
# a node. These are how it asks the same questions, so there is exactly one
# definition of what a tier buys.

static func gape_of(cytostome_tier: int, body_radius: float) -> float:
	return GAPE_BY_TIER[_tier_index(cytostome_tier)] * body_radius


## **What one bite is worth.** One definition, asked in both directions: the
## water runs it for a cell chewing on the player and for the player chewing on
## a cell, and neither gets its own arithmetic.
##
## Three terms, and none of them is a new stat:
##
## - the **tier** of the mouth doing it ([constant BITE_BY_TIER]);
## - **how near the target came to fitting in it** -- `gape / radius`, which is
##   1 for a body that has only just outgrown this mouth and falls away as it
##   grows. That is what keeps the bite continuous with the swallow instead of
##   making a mouth equally dangerous to everything it cannot eat;
## - the target's **`pellicle`**, which already means "how hard this body is to
##   get down" and now also means how much of a bite it turns away.
##
## [param target_radius] is the body, not its swallow radius: armour is counted
## once, on the bottom of this expression, and counting it twice would make
## pellicle the only gene in the game with a square in it.
##
## [param theta] is **where on the body it landed**, measured at the target
## between its own heading and the direction the mouth arrived from: 0 is dead
## ahead and PI is dead astern. One definition, asked in both directions, so the
## water chewing on the player and the player chewing on the water read the same
## table. §1.2.
static func bite_damage(cytostome_tier: int, gape: float, target_radius: float,
		target_pellicle_tier: int, theta: float) -> float:
	var base := BITE_BY_TIER[_tier_index(cytostome_tier)]
	if base <= 0.0:
		return 0.0
	return base * minf(gape / maxf(target_radius, 0.001), 1.0) * flank(theta) \
		/ ARMOR_BY_TIER[_tier_index(target_pellicle_tier)]


## How much of a bite arriving on bearing [param theta] actually lands. A
## cosine: there is no angle at which the damage steps, and turning your nose
## onto an attacker is what takes it back to 1.0 -- which is `cirrus`'s new job
## and the whole of §2.
static func flank(theta: float) -> float:
	return lerpf(FLANK_AHEAD, FLANK_ASTERN, 0.5 - 0.5 * cos(theta))


## What a venomous body does back to the mouth that just bit it.
static func venom_back(toxicyst_tier: int, damage: float) -> float:
	return damage * VENOM_BITE_BACK_BY_TIER[_tier_index(toxicyst_tier)]


## A wound knitting up over [param delta] seconds. Every body in the water uses
## this one -- the player's through [method _process], the field's through
## food.gd -- so there is one definition of how fast a cell recovers.
static func mended(hurt: float, delta: float) -> float:
	return clampf(hurt - delta / MEND_SECONDS, 0.0, 1.0)


static func slots_for(body_radius: float) -> int:
	return clampi(SLOT_MIN + int((body_radius - BASE_RADIUS) / SLOT_RADIUS),
		SLOT_MIN, SLOT_MAX)


static func turn_rate_for(cirrus_tier: int) -> float:
	return TURN_RATE_BY_TIER[_tier_index(cirrus_tier)]


static func speed_for(flagellum_tier: int) -> float:
	var index := _tier_index(flagellum_tier)
	var gap := (IMPULSE_GAP_MIN_BY_TIER[index] + IMPULSE_GAP_MAX_BY_TIER[index]) * 0.5
	return IMPULSE_SPEED_BY_TIER[index] * IMPULSE_MEAN * SPREAD_LOSS / (DRAG * gap)


static func _tier_index(value: int) -> int:
	return clampi(value, 0, GAPE_BY_TIER.size() - 1)


## World direction the cell is facing.
func forward() -> Vector2:
	return Vector2(sin(heading), -cos(heading))


## World direction off the cell's right flank.
func starboard() -> Vector2:
	return Vector2(cos(heading), sin(heading))


## Body-relative bearing of a world point: radians clockwise from the front,
## which is the only way this game is allowed to describe a direction.
func bearing_to(point: Vector2) -> float:
	var offset := point - position
	return atan2(offset.dot(starboard()), offset.dot(forward()))


## How hard the membrane should be shearing right now, signed and normalised.
##
## Takes the larger of demand and actual rotation on purpose. The turn itself
## builds over about a second, but the wash has to answer the same frame the
## player pushes -- that answer is the only proof they are connected to
## anything, and a second of lag destroys it.
func shear_rate() -> float:
	var turning := _omega / turn_rate()
	return steer if absf(steer) > absf(turning) else turning


## Knocked off course by something solid. [param normal] points from the thing
## into the cell.
func bump(normal: Vector2, restitution: float = 0.55) -> void:
	var into := velocity.dot(-normal)
	if into <= 0.0:
		return
	velocity += normal * into * (1.0 + restitution)
	position += normal * 2.0


## Drops any held drag. Called when the game pauses, so a finger still down when
## the pause opened does not keep steering afterwards.
##
## **The drawn controls are not dropped here**, and that is deliberate: this is
## also what the pinch of a division calls, and the steering control has to
## survive it. `controls.let_go()` is the other half, called from the two places
## that really do mean *every finger stops counting* -- the pause screen opening
## and the app losing focus.
func release() -> void:
	_pointer = POINTER_NONE
	steer = 0.0


# ---------------------------------------------------------------------------
# Input. Drag on touch, A/D or the arrows on desktop; both work at once and
# neither costs a pixel of screen.
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Touch is read straight, and the mouse only claims the pointer when touch
	# has not. Godot emulates mouse events from touch by default, so the two
	# arrive as a pair on Android; this is what stops them fighting. Positions
	# are absolute rather than relative for the same reason -- a duplicated
	# event then changes nothing.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_claim(touch.index, touch.position)
			return
		# **`_dropped()` is not a predicate -- it lets the control go.** It has
		# to run on every release, whoever owned the pointer, and only then does
		# its answer decide whether this was also the floating stick's gesture.
		# Written as `not _dropped(i) and _pointer == i` that was correct by
		# evaluation order alone: reverse the two and a pad is never released at
		# all, because the cheap-looking test in front would skip the call. The
		# named local says which of those two lines this is, and this is the
		# input path every player is on.
		var released_a_control := _dropped(touch.index)
		if not released_a_control and _pointer == touch.index:
			_let_go()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _moved(drag.index, drag.position):
			return
		if _pointer == drag.index:
			_pointer_x = drag.position.x
		return

	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_claim(POINTER_MOUSE, click.position)
			return
		# The same release, the same reason it is named. See the touch branch.
		var released_a_control := _dropped(POINTER_MOUSE)
		if not released_a_control and _pointer == POINTER_MOUSE:
			_let_go()
		return

	if event is InputEventKey:
		# `myoneme` on desktop. Space is the only key normal mode spends besides
		# the steer keys and V, and it is the one key nothing else wants.
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_SPACE:
			_dash()
		return

	if event is InputEventMouseMotion:
		var moved := event as InputEventMouseMotion
		if _moved(POINTER_MOUSE, moved.position):
			return
		if _pointer == POINTER_MOUSE:
			_pointer_x = moved.position.x


## **A press, offered to the drawn controls first.** Under `anywhere` there are
## none, [method Controls.press] answers `NONE` on every point, and what follows
## is exactly the floating stick this file has always been. Under `stick` and
## `pads` a press that misses every control is **nothing at all**: no steer, no
## thrust, no dash. The water is inert under those schemes, which is the scheme
## the player chose.
##
## The dash fires here, on the press, and never on the release -- a dash that
## waits for a lift is a dash that arrives after the thing that was chasing you.
func _claim(index: int, at: Vector2) -> void:
	if controls != null:
		var id: int = controls.press(index, at)
		if id == controls.DASH:
			_dash()
			return
		if id != controls.NONE:
			return
		if not controls.floating():
			return
	if _pointer == POINTER_NONE:
		_grab(index, at.x)


## True when that pointer belongs to a drawn control, which owns every later
## event of its gesture. Ownership is decided once, at the press, and keyed by
## pointer index -- nothing here ever asks what is under a finger now.
func _moved(index: int, at: Vector2) -> bool:
	return controls != null and controls.move(index, at)


func _dropped(index: int) -> bool:
	return controls != null and controls.release(index) != controls.NONE


func _grab(index: int, x: float) -> void:
	_pointer = index
	_pointer_anchor = x
	_pointer_x = x
	_pointer_at = float(Time.get_ticks_msec()) * 0.001
	_pointer_from = x


## A press ending. **Short and still is a tap, which is `myoneme`; anything
## else was a steer.** One gesture carries both, so the dash costs no pixel of
## screen and no second finger -- and a player with no myoneme just lifts their
## thumb, exactly as they always have.
func _let_go() -> void:
	var held := float(Time.get_ticks_msec()) * 0.001 - _pointer_at
	var moved := absf(_pointer_x - _pointer_from)
	release()
	if held <= TAP_SECONDS and moved <= TAP_SLOP:
		_dash()


## True while the player is asking for thrust: a key down, or a finger on the
## screen. Deliberately the same gesture that steers -- pushing and turning are
## things you do at the same time.
func _pushing() -> bool:
	if Input.is_action_pressed(&"ui_up") or Input.is_key_pressed(KEY_W):
		return true
	if controls != null and not controls.floating():
		# Touching the stick, under `stick`; the `push` pad, under `pads`.
		return controls.pushing()
	return _pointer != POINTER_NONE


## The burst. Costs hunger, which the cell does not own, so the price leaves on
## a signal and the run pays it.
func _dash() -> void:
	var tier := _tier_index(extra(&"myoneme"))
	var speed := DASH_SPEED_BY_TIER[tier]
	if speed <= 0.0 or _dash_timer > 0.0:
		return
	_dash_timer = DASH_COOLDOWN
	velocity += forward() * speed
	dashed.emit(DASH_COST_BY_TIER[tier])
	impulsed.emit(1.0)


func _read_steer() -> float:
	var keys := 0.0
	if Input.is_action_pressed(&"ui_left") or Input.is_key_pressed(KEY_A):
		keys -= 1.0
	if Input.is_action_pressed(&"ui_right") or Input.is_key_pressed(KEY_D):
		keys += 1.0
	if keys != 0.0:
		return keys
	# **Keys are unchanged under every scheme.** The scheme is a touch choice; a
	# desktop player who picks `pads` gets the pads *and* the keys.
	if controls != null and not controls.floating():
		return controls.steer()
	if _pointer == POINTER_NONE:
		return 0.0
	return clampf((_pointer_x - _pointer_anchor) / DRAG_SPAN, -1.0, 1.0)
