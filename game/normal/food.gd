extends Node
## The water and everything alive in it: four cells, each with its own genome,
## each eating whatever fits in its mouth.
##
## There is no food species and no predator species. **"Predator" is a
## relationship, read off a body, and it changes in both directions during a
## run**: you can eat a cell whose body fits in your gape, it can eat you if
## yours fits in its, and both can be true at once. One rule, evaluated per pair.
## docs/design/genes-and-cilia.md §1.1 and §7.0.
##
## This file is Phase 4's food field and Phase 4's predator merged, because they
## were always two names for one object. What came across unchanged: the scent
## field and its inverse-power falloff, the ring recycling, the authored first
## arrival, the aim state machine, COMMIT_RANGE, the lunge and the break-off.
## What died: a fixed predator RADIUS and a hard-coded PREY_SPEED, both of which
## assumed the hunter and the hunted were different kinds of thing.
##
## The cell reads exactly three things out of this field: its **total scent
## concentration**, which sets the beat rate, its **gradient bearing**, which
## sets the green band wash, and **dread**, a scalar with no bearing at all.
## Everything else it learns by being hit.
##
## This node computes; it does not post. [member concentration],
## [member taste_bearing] and [member dread_level] are read once a frame by
## whoever owns the run, which is the only place allowed to talk to the signal
## bus; discrete events are signals. A per-frame signal here would allocate a
## dictionary sixty times a second to say the same thing.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")
const Genome := preload("res://game/normal/genome.gd")

## A meal, in the cell's own terms.
##
## [param nutrition] is the portion of one whole meal this body was worth, and
## §3.2 makes it the prey's size measured **against your own body, not against
## your gape**: against the gape every cytostome tier would normalise away and a
## wider mouth would buy no bigger dinner. Against the body, a wider mouth lets
## you reach a bigger dinner and you have to go and take it.
## [param gene] is the prey's dominant gene -- what it was most made of (§3.4).
## [param at] is the prey's world position and is emphatically NOT part of the
## sensation -- the cell cannot know where anything is, and nothing that reaches
## the signal bus may carry a position. It is here for the full-vision view,
## which is entitled to ground truth precisely because it is not the organism.
## The same contract as motes.struck: whoever forwards this to the bus drops it.
signal eaten(nutrition: float, gene: StringName, at: Vector2)
## One stroke of a hunting cell's flagellum, felt at its true bearing.
## [param strength] is 0..1; the cap lives in the signal bus, which owns every
## envelope. The only directional information a hunter ever gives.
signal waked(bearing: float, strength: float)
## The membrane closes and you are gone. [param bearing] is where it came from.
signal killed(bearing: float)
## `toxicyst`: it swallowed you and died of it. You are alive, at a bearing and
## a price the run pays out of hunger.
signal stung(bearing: float)
## `trichocyst`: the dart went off and something hunting you broke away.
signal darted(bearing: float)

const COUNT := 34

# --- Seeding (§1.3) ---------------------------------------------------------
# A floor that never moves, a middle that tracks you, and a ceiling you can
# reach. Three constants and a coin flip, in the function that already reseeds
# a culled cell. These are the three numbers to move if the water feels wrong,
# in this order; §9.6 leaves all of them open to play-testing.

## Share of arrivals drawn absolutely rather than relative to the player.
const DRIFTER_SHARE := 0.45
## The Phase 4 food band, unchanged. Drifters have **no cytostome**, so their
## gape tops out at 12.2 and they eat nothing, including each other. They are
## edible at every player radius and at every cytostome tier, which is what
## makes "there is always a way back from a bad run" a fact rather than a hope.
const DRIFTER_MIN := 13.0
const DRIFTER_MAX := 21.0
## Everything else is the player's own radius, give or take this much. These are
## what keep pace, and they are where danger and the mutual band live.
const PEER_SPREAD := 0.34

## **The ceiling is on the gape, not on the body.** A seeded cell takes its
## radius from the draw and then has its cytostome tier reduced until its mouth
## fits under this. At radius 40 nothing the water seeds can swallow you, which
## is the exact meal at which the genome fills (§3.1) -- dread stops arriving,
## and that is the readout that the run is won.
##
## Capping the gape also shapes the population for free: a radius-40 arrival can
## carry at most cytostome 1, while a radius-28 one can carry cytostome 3. Big
## bodies get small mouths and small bodies get big mouths.
##
## **§9.8 is binding: this is a property of THIS water, not of the species.** It
## lives on the field that seeds the water, so a second environment writes its
## own seeder with its own ceiling and nothing here has to change. Do not lift it
## into cell.gd or into genome.gd, where it would become a rule about what a cell
## can ever be.
const ARRIVAL_GAPE_MAX := 40.0
const ARRIVAL_RADIUS_MAX := 40.0

## What a seeded cell is made of. §3.4: a genome is fixed when it is seeded and
## full vision draws it, so informed foraging is possible -- a roll on eating
## could not be seen in advance.
##
## **The `cytostome` entry is never drawn from.** Quoted whole from §3.4 because
## it is that document's constant and the genome strip uses the same four keys,
## but the mouth is not a weighted outcome here: §1.3 gives every peer
## one and no drifter one, so the only pool this is ever consulted with is
## [constant DRIFTER_GENES], which excludes it by construction.
## **Weights, not a list**: the three starting organs stay the commonest thing
## in the water, because a genome that fills up with exotica before it has a
## mouth is a run that cannot eat. Everything earned is rarer, and the two that
## change the most about a run -- the beam and the voluntary push -- are the
## rarest of all.
const GENE_WEIGHTS := {
	&"cytostome": 3, &"cirrus": 4, &"flagellum": 4, &"stigma": 3,
	&"ocellus": 2, &"axoneme": 2,
	&"statocyst": 2, &"rhabdom": 2, &"palp": 2, &"myoneme": 2,
	&"trichocyst": 2, &"pellicle": 2, &"toxicyst": 2,
	&"plastid": 2, &"vacuole": 2, &"crista": 2,
}
## Everything a drifter can be, and therefore everything the player can ever
## eat their way into. The mouth is not on this list by construction.
const DRIFTER_GENES: Array[StringName] = [
	&"cirrus", &"flagellum", &"stigma",
	&"ocellus", &"axoneme", &"statocyst", &"rhabdom", &"palp", &"myoneme",
	&"trichocyst", &"pellicle", &"toxicyst", &"plastid", &"vacuole", &"crista"]
## How likely each tier is in the peer band, weighted so most cells are
## mediocre and a few are terrifying. Index 0 is unused: every peer has at least
## tier 1 of whatever it carries.
##
## **A divergence, flagged.** §9.6 leaves "the cytostome weights inside the peer
## band" open and §1.3 reads as though GENE_WEIGHTS covers it -- but that
## constant is per *gene*, not per *tier*, and says nothing about how good a
## mouth an arrival gets. This is the missing distribution, invented here. It is
## the number that sets how much of the water can eat you (about a fifth of it
## at r26), so it is the first thing to move if the water feels wrong, ahead of
## DRIFTER_SHARE and PEER_SPREAD.
const TIER_WEIGHTS: Array[int] = [0, 3, 2, 1]

## Smaller than you, passive, does not flee: a cell that is not hunting anything
## drifts exactly as Phase 4's food did. Slow enough that it is never a chase and
## never a fixed target either.
const DRIFT_SPEED := 9.0
const DRIFT_TURN := 1.1

# --- Scent (unchanged from Phase 4) -----------------------------------------
## Inverse-power falloff, the shape a diffusing metabolite actually has.
const CORE_RANGE := 130.0      ## c = 1 at or inside this
const SCENT_RANGE := 1600.0    ## c = 0 at or outside this
const SCENT_FALLOFF := 1.7
const SCENT_WINDOW := 250.0    ## smooth the outer cutoff so it cannot pop
## Where [method scent] crosses the bus's TASTE_FLOOR and a direction first
## exists at all -- about twelve seconds of swimming. Everything outside it is
## hot-and-cold with no bearing in it. Named here because it is a property of
## the field, and the full-vision view draws it as a threshold ring.
const BEARING_RANGE := 680.0

## How a body fades out of the scent as it stops fitting in your mouth. §7.0 is
## explicit that this must not be a boolean: a body drifting across your gape
## limit has to fade out of the taste field rather than pop out of it, exactly
## as dread fades rather than snapping. The ratio is `radius / my gape`, so 1.0
## is a body exactly the width of the mouth and it smells half as strong as one
## comfortably inside it.
const EDIBLE_FADE_OUT := 1.15
const EDIBLE_FADE_IN := 0.85

## A meal is worth what it weighs, as a fraction of one whole meal. §3.2: this
## is what stops `cytostome` being a strictly dominant gene -- a big mouth is a
## loss if you keep eating drifters and a win only if you use it, and using it
## means eating bodies near your own size, whose own mouths may take you.
const MEAL_MIN := 0.35
const MEAL_MAX := 1.40

# --- Ring placement ---------------------------------------------------------
## Recycled to the far edge when culled, and the field now lives at the same
## scale as motes.gd's dust rather than eight times wider.
##
## The old numbers (COUNT 4, ring 800-2200, cull 3000) spread four bodies over a
## disc of radius 3000 -- 28 million square units against a viewport of 0.92
## million, so the expected number of cells on screen was **0.13**. One sighting
## every eight screens, which is the "swim for minutes without seeing anything"
## the owner reported and the review measured from the other direction.
##
## RING_MIN is also a visibility bound, and 800 was wrong for it. The half
## diagonal of the base viewport is 734, and of a 20:9 phone canvas 877 -- so at
## 800 a recycled body could appear *on screen*, which is most of the time on the
## shape the owner actually plays. 920 clears both.
const RING_MIN := 920.0
const RING_MAX := 1350.0
const CULL := 1700.0
## Authored, like mote 0: placed along the cell's real velocity once it moves,
## just outside scent range, so the beat quickens at about 0:12. The drifter
## floor guarantees cell 0 is a drifter at setup, so the first thing the player
## ever meets is always something it can eat.
const FIRST_DISTANCE := 1400.0

# --- Dread ------------------------------------------------------------------
const DREAD_RANGE := 1400.0
const DREAD_CORE := 240.0
const DREAD_CAP := 0.95
## The ratio window, unchanged from Phase 4 -- same two constants, same curve,
## same feel. What changed is the ratio: it was the predator's fixed radius over
## yours, and it is now **the other cell's gape over your radius**, which is the
## same question asked of a body that can grow a mouth.
##
## Summing booleans would make dread a step function that snaps 0 -> 1 the frame
## a cell's gape crosses your radius, and the most-praised readout in Phase 4
## would be gone. Substituted into the curve instead, a cell growing its
## cytostome becomes frightening *gradually*, which is the Phase 4 experience
## run backwards. §7.0's blockquote.
##
## **Dread is therefore a pure relation: this curve, times distance, summed over
## every body in the water.** It asks no question with a yes/no answer -- not
## "can it eat me", not "is it hunting me" -- because every such question is a
## boolean, and a boolean anywhere in this sum puts a step back into the one
## readout §7.0 exists to protect. Three steps were found by gating it:
##
## - gating on `_state == STALK` made dread jump by up to 0.90 the frame a close
##   cell acquired you, which is why acquisition used to be forbidden inside
##   DREAD_RANGE -- and forbidding it is what made the player untouchable at
##   contact range (nothing could ever commit from close in).
## - gating on `_target == player` made dread fall to zero the frame its owner
##   broke off, which is every frame the player ate something: a 0.30 drop on
##   the most common action in the game.
## - gating on "can eat me" left a 0.216 floor at ratio 1.0, so dread still
##   stepped at the moment a mouth crossed your radius.
##
## Ungated, all three are gone and nothing was lost: a body below THREAT_LOW
## contributes exactly 0.0, so the curve does its own gating, continuously.
## Phase 4 already decoupled dread from lethality in precisely this way -- its
## predator could kill you at every ratio, including ratios this window scores
## at zero -- so "the water is wrong" has never meant "that one can eat me".
const THREAT_LOW := 0.85
const THREAT_HIGH := 1.35

# --- The shadow, for the stigma (§6) ----------------------------------------
# A body passing between the cell and the light above occludes it. That costs
# no new world content -- no sun, no lamp -- and it gives point of view a
# sharp, certain, continuous bearing on **mass**, where before it had only
# intermittent wakes and directionless dread.
#
# **Mass, not danger, and after §1.1 those are no longer the same thing.** The
# ratio is on the radius, so the stigma is silent about the two cells §1.1
# exists to create: the small cell with a huge mouth casts no shadow and the
# mouthless giant casts a large one. That is honest optics, it keeps
# perception.md's "never an identity", and it is the gap §2.3's reserved
# chemoreceptor gene is there to sell later.

## Inside WAKE_RANGE 760 on purpose: the gene sharpens what the cell knows, it
## never extends how far it knows it.
const SHADOW_RANGE := 620.0
const SHADOW_CORE := 180.0
## Bodies below this fraction of your own radius cast nothing.
const SHADOW_MIN_RATIO := 0.8
## **A divergence from §6, and the same one §7.0 forced on dread.** The design
## writes the ratio as a threshold -- "any cell with radius >= SHADOW_MIN_RATIO
## * cell.radius" -- and a threshold is a boolean, so a body drifting across it
## would pop the amber lobe on and off. Every gate in this file has been taken
## off exactly that argument. So 0.8 is where a shadow starts and a body your
## own size casts a whole one, with a curve in between; nothing below 0.8 casts
## anything, which is what the number in §6 actually means.
const SHADOW_FULL_RATIO := 1.05

# --- The wake ---------------------------------------------------------------
const WAKE_RANGE := 760.0
const WAKE_CORE := 170.0
const STROKE_GAP := 1.45
const STROKE_JITTER := 0.35
## Inside this the stroke gap halves, the wake strength pins and it swims at its
## lunge speed. This is the sprint, not the decision.
const LUNGE_RANGE := 220.0
## Inside this it stops correcting: one solution, then a straight line through
## whatever happens next. The decision is made well before the sprint, which is
## why the skill the encounter tests is committing early.
##
## Everything about the dodge lives in this number, and it was measured against
## a tier-1 cell, not chosen. At 220 the run is only 2.3s and a committed turn
## was eaten about a third of the time. At 420 a cell swimming straight stops
## being caught. At 310, over 14 seeds each: never-steers caught 11/14,
## commits-away escapes 13/14. **§7.1 hands the re-measurement against a tier-3
## cell to Phase 6; it is deliberately not re-tuned here.**
const COMMIT_RANGE := 310.0

# --- Swimming ---------------------------------------------------------------
## A hunter cruises this much faster than its prey's realised speed, and lunges
## this much faster. Both were 68 and 96 against Phase 4's hard-coded 56.5, and
## they still are for a tier-1 cell -- but the reference is now **the prey's own
## speed**, so the chase stays a chase at every `flagellum` tier and only
## `cirrus` improves the dodge. The owner's call, recorded in §7.1.
const CRUISE_OVER_PREY := 1.20
const LUNGE_OVER_PREY := 1.70
const WANDER_RATE := 0.09
const WANDER_TAU := 3.2

# --- The chase --------------------------------------------------------------
## Free tracking, out where the cell has no bearing to act on anyway.
const AIM_GAP := 1.45
## **The window.** Once it is inside wake range it has committed to an attack
## run, and it swims at a solution this many seconds old. Seven is not a guess:
## it is the p90 time for a tier-1 cell to swing its velocity 120 degrees.
const LOCK_SECONDS := 7.0
## It re-acquires only while the prey is still roughly where it is swimming.
const LOCK_CONE_DEG := 70.0
## How many times to settle the intercept. The time to reach the aim depends on
## where the aim is, which depends on the time: three passes is convergence.
const INTERCEPT_STEPS := 3
## Long enough that one frame of geometry cannot end a chase.
const LOST_GRACE := 0.8
## **How the escape is actually paid off.** An attack run only ever closes; the
## moment the prey has taken this much ground back off the closest approach, the
## run has failed and the hunter sheers off. It reads as the only thing it could
## read as -- it stopped gaining -- and it is what turns a committed turn into
## relief within a few seconds rather than at the end of a timeout.
const LOST_GROUND := 90.0
## The backstop under that, for a stern chase that neither closes nor opens.
## Longer dread is longer taste blackout, which starves a player for being good
## at the game, so it is a cap and not a mechanic.
const RUSH_SECONDS := 24.0
## How far along its own heading a break-off aims. Only has to be past the
## horizon; the run ends at DREAD_RANGE, not here.
const BREAK_AWAY := 3000.0
## Hard ceiling on a break-off, as a guard rather than a mechanism.
const BREAK_TIMEOUT := 20.0
## Long enough to get a meal in before the next one.
const CALM_MIN := 30.0
const CALM_MAX := 55.0
## How far off a cell notices something it could eat. Phase 4's predator spawned
## at 1400-1900 and hunted from there, so this is the range the shipped chase
## was actually measured over.
const NOTICE_RANGE := 1900.0
## **The authored opening survives as an opening, not as a species spawn.**
## Nothing may commit to the *player* before this, so the opening has no chase,
## no wake and no death in it -- which is the part of perception.md §2 that
## matters. Dread no longer waits on it, because dread no longer waits on
## anything (see THREAT_LOW); what keeps the opening quiet instead is [method
## _seed]'s rule that **nothing seeded at setup that could eat you starts inside
## DREAD_RANGE**. Danger has to arrive, and arriving is continuous.
const FIRST_DELAY := 42.0
## How long a hunter keeps swimming at prey that has just outgrown its mouth.
##
## Without it a cell abandons its run on the exact frame the player eats
## something, because one meal is a whole unit of radius and a gape sitting
## anywhere in `(radius, radius + 1)` loses its claim in a single step. Losing
## interest over a moment is both more believable and less abrupt. It cannot
## turn into a kill it should not have: contact re-checks the gape every frame,
## so a hunter inside this grace can reach the player and simply fail.
const OUTGROWN_GRACE := 1.5

enum State { DRIFT, STALK, BREAK }

## [member Body.target] when there is nothing to chase, and when the thing being
## chased is the player. Anything >= 0 is an index into the field itself.
const TARGET_NONE := -1
const TARGET_PLAYER := -2


## One body in the water. Plain data: every rule that acts on it is a function
## on the field, so there is one place to read the behaviour rather than one
## per state. Four of these exist at a time.
class Body:
	var pos := Vector2.ZERO
	## Radians clockwise from world north, the cell's own convention.
	var heading := 0.0
	var radius := 0.0
	## `{gene: tier}`, fixed at seeding and grown by eating. Never null.
	var genome := {}
	## No cytostome, r13-21, eats nothing: the floor of §1.3.
	var drifter := true
	## False until _seed() has run, so the drifter counter cannot mistake an
	## uninitialised slot for a drifter.
	var seeded := false
	## Bumped on every reseed, so a chase cannot silently transfer to whatever
	## body landed in the index its prey used to occupy.
	var serial := 0
	var meals := 0

	var state := 0  # State.DRIFT
	var target := -1  # TARGET_NONE
	var target_serial := 0
	var calm := 0.0
	## Seconds this run has been swimming at prey it can no longer swallow,
	## against OUTGROWN_GRACE.
	var stale := 0.0
	## Last known position of the prey, and therefore the point a break-off
	## flees from. Held separately because the prey may be gone by then, and
	## "gone" used to fall back to the player -- which sent every cell that
	## finished a meal bolting away from you for no reason it could explain.
	var flee_from := Vector2.ZERO
	var aim := Vector2.ZERO
	var aim_clock := 0.0
	var lost := 0.0
	var rush := 0.0
	var best := INF
	var lunging := false
	var break_clock := 0.0
	var stroke := 0.0
	var wander := 0.0


## Total scent concentration at the cell, 0..1. The other half of metabolism's
## beat mapping, and the reason the outer kilometre is hot-and-cold with no
## direction in it.
var concentration := 0.0
## Body-relative bearing of the summed gradient, radians clockwise from the
## cell's front. Meaningless when [member concentration] is 0.
var taste_bearing := 0.0
## What the membrane should be told, 0..1. No bearing, ever: a hunter's
## metabolites saturate the chemoreceptor, and a blocked receptor has no
## differential to read a direction from.
var dread_level := 0.0
## The largest gape-over-radius threat weight in the water, run through the same
## window dread is, ignoring distance. Public for the dev harness, which needs
## to be able to show that this varies continuously rather than stepping.
var threat := 0.0
## How much light is being blocked, 0..1, and from where. Read by whoever owns
## the run and posted to the bus as the `stigma`'s lobe -- but only if the cell
## has grown one. The field computes it either way: what the water is doing is
## not a function of which organs are watching it. §6.
var shadow := 0.0
## Body-relative bearing of the summed occlusion. Meaningless when [member
## shadow] is 0.
var shadow_bearing := 0.0

# --- The earned senses, computed here and posted by the run -----------------
# Same contract as everything above: this node computes and does not post, and
# not one of these is a position. Bearings are body-relative and distances are
# scalars along a bearing the cell chose.

## `ocellus`. Written once a frame by the run: the body-relative bearings this
## cell's beams point along, and how far they reach.
var beam_bearings := PackedFloat32Array()
var beam_range := 0.0
## Answered here, index-matched to [member beam_bearings]:
## `[bearing, distance, hit]` -- `distance` is the full reach when nothing was
## hit and `hit` is false then.
var beams: Array = []
## `palp`. Range in, bearing and strength out: the nearest body inside touch
## range, which is the one thing a blind cell can know for certain.
var touch_range := 0.0
var touch_level := 0.0
var touch_bearing := 0.0
## `trichocyst`. How close something hunting you gets before the dart fires, and
## how long until there is another one. The clock lives here because the
## encounter lives here.
var dart_range := 0.0
var dart_cooldown := 0.0
## `toxicyst`. Negative means the cell has no venom and a kill is a kill.
var venom_cost := -1.0
var _dart_clock := 0.0

var _cell: CellBody = null
var _cells: Array[Body] = []
var _first_pending := false
var _first_hunt := FIRST_DELAY
## True only while [method setup] is laying the opening field out. See _seed().
var _opening := false
var _serial := 0
var _points := PackedVector2Array()
var _radii := PackedFloat32Array()
var _headings := PackedFloat32Array()


## Seeds the water around [param cell]. Cell 0 is held back until the cell is
## actually moving, for the same reason mote 0 is.
func setup(cell: CellBody) -> void:
	_cell = cell
	_cells.clear()
	for i in COUNT:
		_cells.append(Body.new())
	_opening = true
	for i in COUNT:
		_seed(i)
	_opening = false
	_first_pending = true
	_first_hunt = FIRST_DELAY
	concentration = 0.0
	taste_bearing = 0.0
	dread_level = 0.0
	threat = 0.0
	beams.clear()
	touch_level = 0.0
	_dart_clock = 0.0


func _process(delta: float) -> void:
	if _cell == null:
		return

	# The drift path does not exist until the cell drifts. Placing the first
	# body along the real velocity vector is what makes the beat quicken at
	# about 0:12 instead of whenever the wander happens to point at something.
	if _first_pending and _cell.velocity.length_squared() > 1.0:
		_first_pending = false
		_cells[0].pos = _cell.position + _cell.velocity.normalized() * FIRST_DISTANCE
	if _first_hunt > 0.0:
		_first_hunt -= delta

	_dart_clock = maxf(_dart_clock - delta, 0.0)
	for i in _cells.size():
		_step_body(i, delta)
	_step_recycle()
	if not _step_contacts():
		return
	_step_sense()
	_step_beams()
	_step_touch()


# ---------------------------------------------------------------------------
# Behaviour. A cell that is not hunting drifts, which is exactly what Phase 4's
# food did; a cell that is hunting runs Phase 4's predator. Same object, two
# states, and the transition between them is the gape rule.
# ---------------------------------------------------------------------------

func _step_body(index: int, delta: float) -> void:
	var b := _cells[index]
	match b.state:
		State.STALK:
			_step_stalk(index, b, delta)
		State.BREAK:
			_step_break(b, delta)
		_:
			_step_drift(index, b, delta)


func _step_drift(index: int, b: Body, delta: float) -> void:
	b.calm = maxf(b.calm - delta, 0.0)
	b.heading = wrapf(b.heading + randf_range(-DRIFT_TURN, DRIFT_TURN) * delta, -PI, PI)
	b.pos += _forward(b.heading) * DRIFT_SPEED * delta
	if b.drifter:
		return
	# **Calm suppresses seeking, not opportunity.** The calm after an encounter
	# is there so a failed run is not retried on the spot; it was never meant to
	# make a mouth decline a body that has drifted into it. Left as a blanket
	# gate it reproduced the original defect in a slower form: a lethal cell
	# resting for fifty seconds was found pressed against the player, inert, at
	# contact range. Resting means it will not cross the water for you. It does
	# not mean it will not close.
	_look_for_prey(index, b, NOTICE_RANGE if b.calm <= 0.0 else 0.0)


## The nearest thing this cell can swallow inside [param reach], if anything.
## [param reach] is 0 for a cell that is resting, which leaves only what is
## already touching it -- and touching is never out of reach.
func _look_for_prey(index: int, b: Body, reach: float) -> void:
	var gape := _gape(b)
	var best := TARGET_NONE
	var best_serial := 0
	var best_d := INF

	# The player, at any range, once the opening is over.
	#
	# This used to require `d >= DREAD_RANGE`, so that dread could only ever
	# begin at the distance where its range weight is zero. The cost was
	# absurd and was measured: a cell that could swallow the player and was
	# *already close* could never acquire them at all, so it drifted through
	# their body indefinitely and nothing happened -- 96% of the time a lethal
	# cell was in range it was harmless, and a red-rimmed mouth passing straight
	# through you is the most obvious lie the game could tell. The floor is gone
	# and the continuity it was protecting is now protected properly, by dread
	# not being a function of this decision at all (see THREAT_LOW).
	if _first_hunt <= 0.0 and _cell.swallow_radius() < gape:
		var d := b.pos.distance_to(_cell.position)
		if d <= maxf(reach, b.radius + _cell.radius):
			best = TARGET_PLAYER
			best_d = d

	for j in _cells.size():
		if j == index:
			continue
		var other := _cells[j]
		if not other.seeded or other.radius >= gape:
			continue
		var d := b.pos.distance_to(other.pos)
		if d <= maxf(reach, b.radius + other.radius) and d < best_d:
			best = j
			best_serial = other.serial
			best_d = d

	if best == TARGET_NONE:
		return
	b.target = best
	b.target_serial = best_serial
	b.state = State.STALK
	b.lost = 0.0
	b.rush = 0.0
	b.aim_clock = 0.0
	b.lunging = false
	b.best = INF
	b.break_clock = 0.0
	b.stroke = randf_range(0.2, STROKE_GAP)
	b.wander = 0.0
	b.stale = 0.0
	b.aim = _target_pos(b)
	b.flee_from = b.aim
	# Only swing the nose onto a target it has spotted from a distance. A cell
	# that acquires something already touching it keeps the heading it had:
	# snapping to face the prey would be an instant handbrake turn, and the
	# rate-limited turn in _swim() is the whole reason a lunge can be dodged.
	if b.pos.distance_to(b.aim) > LUNGE_RANGE:
		b.heading = _angle_of(b.aim - b.pos, b.heading)


func _step_stalk(index: int, b: Body, delta: float) -> void:
	# The prey may simply not be there any more: eaten by something else, or
	# culled and recycled into a different body. Nothing to chase, so the run
	# ends at once -- and it ends fleeing the place the prey last was, not the
	# player.
	if not _target_present(index, b):
		_break_off(b)
		return

	b.flee_from = _target_pos(b)

	# Or it may still be there and have outgrown this mouth, which is §1.2 in
	# one line: a cell you were prey to can stop being able to eat you without
	# leaving the screen. That deserves a moment rather than a frame. The
	# player's radius moves a whole unit per meal, so a gape anywhere inside
	# `(radius, radius + 1)` loses its claim on the exact frame they swallow
	# something, and a hunter that vanishes off your back at that instant reads
	# as the game reacting to your inventory rather than to your body.
	if _target_edible(b):
		b.stale = 0.0
	else:
		b.stale += delta
		if b.stale >= OUTGROWN_GRACE:
			_break_off(b)
			return

	var offset := _target_pos(b) - b.pos
	var d := offset.length()
	_step_aim(b, d, offset, delta)
	if b.state != State.STALK:
		return
	_swim(b, delta, _lunge_speed(b) if d < LUNGE_RANGE else _cruise_speed(b))

	# The wake. One dent per stroke of its flagellum, at its true bearing, and
	# only ever felt from a cell that is hunting *you*.
	if b.target != TARGET_PLAYER:
		return
	# **`trichocyst`. It came inside dart range and it is leaving.** Automatic
	# rather than a button: the design has no second control to spend and the
	# whole of the gene is the cooldown -- one run broken off, then a long wait,
	# so it buys an escape and never safety.
	if dart_range > 0.0 and d < dart_range and _dart_clock <= 0.0:
		_dart_clock = dart_cooldown
		darted.emit(_cell.bearing_to(b.pos))
		_break_off(b)
		return
	b.stroke -= delta
	if b.stroke > 0.0:
		return
	var committed := d < LUNGE_RANGE
	b.stroke = STROKE_GAP * (0.5 if committed else 1.0) \
		+ randf_range(-STROKE_JITTER, STROKE_JITTER) * (0.5 if committed else 1.0)
	if d < WAKE_RANGE:
		# No bearing jitter. The imprecision is in the interval.
		var push := 1.0 if committed else smoothstep(WAKE_RANGE, WAKE_CORE, d)
		waked.emit(_cell.bearing_to(b.pos), push)


func _step_break(b: Body, delta: float) -> void:
	# Aim away from where the PREY was, recomputed every frame.
	#
	# "Where the prey was" and not "where the prey is": by the time a run ends
	# the prey has often been eaten or recycled, and asking for its position
	# then used to answer with the *player's* -- so every cell that finished a
	# meal turned and fled from the player at lunge speed, straight out past the
	# dread radius, and sat calm for the next fifty seconds. A cell that had
	# just grown and just become more dangerous was systematically removed from
	# the water, which is the exact inverse of §1.2.
	#
	# This used to freeze one world point at break-off and steer at it. The
	# hunter then *reached* that point, the direction to it flipped through 180
	# degrees, and it turned around and came back -- oscillating about a stale
	# marker, passing through the cell again and again, unable to frighten, wake
	# or kill for up to eighty seconds. Aiming away from the prey instead makes
	# the distance monotonic.
	var away := _away_from(b)
	b.aim = b.pos + away * BREAK_AWAY
	# It leaves at a lunge, not a saunter. A hunter that sheers off at cruise
	# stays inside dread range for a minute and a half, which is a minute and a
	# half of nothing happening to a player who just earned something.
	#
	# The target is dropped at break-off, so this is its *own* lunge speed
	# rather than its prey's -- its own body is what does the swimming, and it
	# no longer has a prey to scale against. The slowest possible cell
	# (flagellum 0, 70 u/s) covers 1394 units in the 20s of BREAK_TIMEOUT, a
	# whisker short of DREAD_RANGE, so that guard is the one that ends its run
	# rather than the distance test. Both end in DRIFT; neither can strand it.
	_swim(b, delta, _lunge_speed(b))
	b.break_clock += delta
	# Belt and braces. The line above should make the timeout unreachable, and
	# if it ever fires the hunter has still stopped being a ghost.
	if b.pos.distance_to(b.flee_from) > DREAD_RANGE or b.break_clock > BREAK_TIMEOUT:
		b.state = State.DRIFT
		b.target = TARGET_NONE
		b.calm = randf_range(CALM_MIN, CALM_MAX)


## Course corrections, and the one way out of them.
##
## Outside wake range it tracks freely -- there is nothing the prey could do
## about it anyway, because there is no bearing yet. Inside, it has committed to
## an attack run: it swims at a solution that goes stale, and it only re-acquires
## while the prey is still roughly ahead of it. A cell that turns hard and keeps
## turning walks out of that cone while the hunter is still swimming at where it
## would have been.
func _step_aim(b: Body, d: float, offset: Vector2, delta: float) -> void:
	if d > WAKE_RANGE:
		b.lost = 0.0
		b.rush = 0.0
		b.lunging = false
		b.best = INF
		b.aim_clock -= delta
		if b.aim_clock <= 0.0:
			b.aim_clock = AIM_GAP
			b.aim = _intercept(b, d)
		return

	b.rush += delta
	b.best = minf(b.best, d)
	var off := absf(angle_difference(b.heading, _angle_of(offset, b.heading)))
	if off > deg_to_rad(LOCK_CONE_DEG):
		b.lost += delta
	else:
		b.lost = 0.0

	if b.lost >= LOST_GRACE or b.rush >= RUSH_SECONDS or d > b.best + LOST_GROUND:
		_break_off(b)
		return

	if d > COMMIT_RANGE:
		b.lunging = false
		b.aim_clock -= delta
		if b.aim_clock <= 0.0:
			b.aim_clock = LOCK_SECONDS
			b.aim = _intercept(b, d)
		return

	# Committed. One fresh solution at the moment the run starts, and then
	# nothing: once it begins at 220 units the encounter is over in 2.3 seconds,
	# and a hunter that corrects through the lunge cannot be dodged at all.
	if not b.lunging:
		b.lunging = true
		b.aim = _intercept(b, d)
		return
	# The pass is over the moment the aim point is behind it. No contact by then
	# is a clean miss, and a clean miss ends the encounter.
	if (b.aim - b.pos).dot(_forward(b.heading)) <= 0.0:
		_break_off(b)


## Where the prey will be, if it keeps doing what it is doing.
func _intercept(b: Body, d: float) -> Vector2:
	var speed := maxf(_lunge_speed(b) if d < LUNGE_RANGE else _cruise_speed(b), 1.0)
	var t := clampf(d / speed, 0.0, 9.0)
	var aim := _predict(b, t)
	# Settle it: how long the swim takes depends on where the aim is, and where
	# the aim is depends on how long the swim takes.
	for i in INTERCEPT_STEPS:
		t = clampf(b.pos.distance_to(aim) / speed, 0.0, 9.0)
		aim = _predict(b, t)
	return aim


## Where the prey drifts to in [param t] seconds if it keeps this heading.
##
## For the player there are two terms, because its motion has two parts: the
## average drift along the heading it is holding, and the transient of being
## faster or slower than that average right now. The first is made along its
## *heading* -- precisely the thing a turning player changes, and therefore the
## whole of the dodge. The answer is always a straight line, and a cell that
## keeps turning is never on one.
##
## **The average is the prey's own realised speed** (§7.1), not a constant: a
## flagellum-3 cell that outswims a hard-coded 56.5 would otherwise be led at
## the wrong point and could not be caught at all.
func _predict(b: Body, t: float) -> Vector2:
	if b.target != TARGET_PLAYER:
		var prey := _target_body(b)
		if prey == null:
			return _target_pos(b)
		var speed := DRIFT_SPEED if prey.state == State.DRIFT else _cruise_speed(prey)
		return prey.pos + _forward(prey.heading) * speed * t
	var cruise := _cell.forward() * _cell.swim_speed()
	var k := maxf(CellBody.DRAG, 0.001)
	return _cell.position + cruise * t + (_cell.velocity - cruise) * ((1.0 - exp(-k * t)) / k)


func _break_off(b: Body) -> void:
	b.state = State.BREAK
	b.lost = 0.0
	b.rush = 0.0
	b.stale = 0.0
	b.break_clock = 0.0
	# The chase is over, so the target is dropped here rather than left behind
	# for something else to read. Everything the break-off needs is in
	# [member Body.flee_from], which is the last place the prey actually was.
	b.target = TARGET_NONE
	b.target_serial = 0
	# Still not a handbrake turn: the aim is away from the prey, but _swim()
	# rate-limits the turn, so it sheers off the line it was on rather than
	# spinning. _step_break() recomputes this every frame -- see the note there
	# for why a frozen point was a bug.
	b.aim = b.pos + _away_from(b) * BREAK_AWAY


## Unit vector pointing from the prey to the hunter, i.e. straight away. Falls
## back to its own heading in the degenerate case where the two bodies are at
## exactly the same point, which contact makes reachable.
func _away_from(b: Body) -> Vector2:
	var offset := b.pos - b.flee_from
	return offset.normalized() if offset.length_squared() > 0.0001 \
		else _forward(b.heading)


func _swim(b: Body, delta: float, speed: float) -> void:
	var rate := CellBody.turn_rate_for(Genome.tier_of(b.genome, &"cirrus"))
	var want := _angle_of(b.aim - b.pos, b.heading)
	var turn := clampf(angle_difference(b.heading, want), -rate * delta, rate * delta)
	b.wander = lerpf(b.wander, randf_range(-WANDER_RATE, WANDER_RATE),
		1.0 - exp(-delta / WANDER_TAU))
	b.heading = wrapf(b.heading + turn + b.wander * delta, -PI, PI)
	b.pos += _forward(b.heading) * speed * delta


# ---------------------------------------------------------------------------
# Eating. The same rule for every pair in the water, including the player: B is
# food to A when B's body fits in A's mouth. §1.3's "inside the field, cells
# genuinely eat each other" is the whole of it -- no special case, no abstraction
# of the ecosystem, and no difficulty curve anyone had to author.
# ---------------------------------------------------------------------------

## Returns false when the player has just been killed.
##
## `killed` is emitted from inside this node's own _process, and the run handles
## it synchronously: by the time the signal returns, the cell is dying and this
## node has had set_process(false) called on it. Returning immediately is not
## about the stale [member dread_level] -- the run stops reading that on the
## next frame anyway. It is about **everything below this line**. `eaten` is not
## idempotent: emitting it after the death would feed and grow a corpse, and the
## cell-against-cell pass below would go on reshaping a field nobody is in any
## more.
##
## The one line that does sit between the emit and the return is the killer's
## own `_break_off`, and it is there on purpose: without it that cell is left in
## STALK against a player who no longer exists, and the next run starts with it
## already committed. It touches nothing but the body that just ate. **Nothing
## else may be added there** -- the rule is "no second effect on the field", not
## "no statements".
func _step_contacts() -> bool:
	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		if b.pos.distance_to(_cell.position) >= b.radius + _cell.radius:
			continue
		# Both directions can be true at once, and then it is whoever committed
		# first -- which is the cell in the middle of an attack run.
		#
		# **The one asymmetry in the water, and it is deliberate.** Cell eats
		# cell on contact alone; cell eats player only from a committed run. It
		# is written down here because §1.3 says there is no special case for
		# the player, and this is one: it buys the guarantee that a death is
		# always preceded by a commitment the player could feel -- dread rising
		# and a wake at a true bearing -- rather than by a body that happened to
		# drift into them. perception.md §2 sells that guarantee and it is worth
		# an asymmetry.
		#
		# It costs almost nothing now that a cell can commit from any range: the
		# only window in which a lethal body is touching the player and not
		# hunting them is the calm after it has just broken off one run, and a
		# hunter that has just given up and swum through you is a fair reading
		# of that moment. It used to cost everything -- commitment was forbidden
		# inside DREAD_RANGE, so a close mouth could never commit at all.
		if b.state == State.STALK and b.target == TARGET_PLAYER \
				and _cell.swallow_radius() < _gape(b):
			# **`toxicyst`. It got you and it dies of it.** The one thing in the
			# game that undoes a death, and it is not free: the run pays for it
			# in hunger, which is the channel every other cost is paid in. The
			# body that swallowed you is reseeded -- it is gone, not fleeing.
			if venom_cost >= 0.0:
				stung.emit(_cell.bearing_to(b.pos))
				_seed(i)
				continue
			killed.emit(_cell.bearing_to(b.pos))
			_break_off(b)
			return false
		if b.radius < _cell.gape():
			# Emit where it was before recycling it, so a listener never has to
			# work out which one this was -- the mistake motes.gd documents.
			eaten.emit(_meal_value(b.radius), Genome.dominant_of(b.genome), b.pos)
			_seed(i)
		# Otherwise a standoff at contact, and there is nothing for either of
		# them to do about it.
		#
		# **The view has now been asked and it says yes, this wants a bump.**
		# Rendered: two r28-r30 bodies that cannot swallow each other, posed 25
		# units apart, draw as two crossing rims with one cell's cirrus tuft
		# inside the other's body and two nuclei side by side. It reads as a
		# drawing fault rather than as two organisms, which is exactly the
		# failure §1.3 warns about when it refuses to take a cytostome tier off
		# a living cell. It is uncommon -- four bodies in a 3000-unit field --
		# but §1.1's whole point is that standoffs are the most numerous
		# relationship at every radius, so it will be seen.
		#
		# Left alone deliberately: cell.gd already has [method CellBody.bump]
		# and giving bodies the same treatment is a change to how the water
		# moves, not to how it is drawn. It belongs to whoever owns the
		# simulation, with a re-measurement of COMMIT_RANGE behind it, because
		# a body that can be shouldered is a body a chase can be blocked by.

	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded or b.drifter:
			continue
		var gape := _gape(b)
		for j in _cells.size():
			if j == i:
				continue
			var other := _cells[j]
			if not other.seeded or other.radius >= gape:
				continue
			if b.pos.distance_to(other.pos) >= b.radius + other.radius:
				continue
			_devour(b, other)
			_seed(j)
			# It has just eaten, so the run is over -- ended here, as a meal,
			# rather than left to unravel as a broken-off chase against a slot
			# that has since been recycled into somebody else. That route took
			# it through BREAK, which fled the prey that was no longer there,
			# which used to resolve to the player: every cell-against-cell meal
			# ejected a newly grown, newly dangerous cell out past the dread
			# radius. It stays where it is, bigger, and it is the player's
			# problem now. §1.2.
			b.state = State.DRIFT
			b.target = TARGET_NONE
			b.target_serial = 0
			b.stale = 0.0
			b.calm = randf_range(CALM_MIN, CALM_MAX)
			break  # One meal per cell per frame. It has to swallow.
	return true


## What one cell gains by eating another: a unit of radius, and whatever the
## prey was most made of, by exactly the rules the player's genome obeys.
##
## Note that this is **not** clamped to ARRIVAL_GAPE_MAX. The ceiling is a
## property of what the water *seeds* (§1.3/§9.8); a cell that has been feeding
## is allowed past it, which is §1.2's "the longest-lived cells become the most
## dangerous without anyone authoring a difficulty curve". The bound on it is
## that nothing outside CULL is simulated at all.
func _devour(b: Body, prey: Body) -> void:
	b.radius += CellBody.GROWTH_PER_MEAL
	b.meals += 1
	Genome.integrate_into(b.genome, Genome.dominant_of(prey.genome),
		CellBody.slots_for(b.radius))


func _meal_value(prey_radius: float) -> float:
	return clampf(prey_radius / maxf(_cell.radius, 0.001), MEAL_MIN, MEAL_MAX)


func _step_recycle() -> void:
	for i in _cells.size():
		if _cells[i].pos.distance_to(_cell.position) > CULL:
			_seed(i)


# ---------------------------------------------------------------------------
# What the cell can actually sense: a summed concentration, a summed bearing,
# and a scalar with no bearing in it.
# ---------------------------------------------------------------------------

func _step_sense() -> void:
	var total := 0.0
	var pull := Vector2.ZERO
	var dread := 0.0
	var worst := 0.0
	var gape := _cell.gape()
	var shade := 0.0
	var shade_pull := Vector2.ZERO

	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		var offset := b.pos - _cell.position
		var d := offset.length()

		# Taste, over everything I can eat, weighted so a body crossing my gape
		# limit fades rather than pops.
		var edible := smoothstep(EDIBLE_FADE_OUT, EDIBLE_FADE_IN,
			b.radius / maxf(gape, 0.001))
		if edible > 0.0:
			var c := scent(d) * edible
			if c > 0.0:
				total += c
				pull += offset / maxf(d, 0.001) * c

		# The shadow, over every body big enough to cast one. Summed and given a
		# bearing exactly the way taste is, for the same reason: two bodies
		# blocking the light really do block more of it than one, and a summed
		# vector moves continuously where a pick-the-biggest would jump the
		# bearing across the screen the frame two shadows swapped rank.
		var mass := smoothstep(SHADOW_MIN_RATIO, SHADOW_FULL_RATIO,
			b.radius / maxf(_cell.radius, 0.001))
		if mass > 0.0 and d < SHADOW_RANGE:
			var near := clampf((SHADOW_RANGE - d) / (SHADOW_RANGE - SHADOW_CORE),
				0.0, 1.0)
			var blocked := mass * near
			if blocked > 0.0:
				shade += blocked
				shade_pull += offset / maxf(d, 0.001) * blocked

		# Dread, over **every** body, with no question asked that has a yes/no
		# answer -- see THREAT_LOW for the three steps that gating this put into
		# the one readout §7.0 exists to protect. A body too small-mouthed to
		# matter scores 0.0 on the curve and drops out on its own, continuously,
		# which is what the curve is for.
		#
		# Nine seconds of closing still separate the first dread from the first
		# wake: ten seconds of the water simply being wrong, then a direction.
		var level := smoothstep(THREAT_LOW, THREAT_HIGH,
			_gape(b) / maxf(_cell.swallow_radius(), 0.001))
		if level <= 0.0:
			continue
		worst = maxf(worst, level)
		dread += clampf((DREAD_RANGE - d) / (DREAD_RANGE - DREAD_CORE), 0.0, 1.0) * level

	concentration = minf(total, 1.0)
	if concentration > 0.0 and pull.length_squared() > 0.0:
		taste_bearing = _cell.bearing_to(_cell.position + pull)
	else:
		taste_bearing = 0.0
	shadow = minf(shade, 1.0)
	# Deliberately left where it was when the last shadow faded rather than
	# snapped to dead ahead: the lobe is already dark at strength 0, and a
	# bearing that resets would swing the amber round to the nose on its way
	# out -- a movement the player would read as something passing in front of
	# them, at the moment nothing is.
	if shadow > 0.0 and shade_pull.length_squared() > 0.0:
		shadow_bearing = _cell.bearing_to(_cell.position + shade_pull)
	threat = worst
	dread_level = minf(dread, 1.0) * DREAD_CAP


## **The beams.** One ray per ocellus, cast against every body in the water:
## the nearest surface along the ray, or nothing. Sixteen ray-circle tests a
## frame at the very worst, which is four bodies by four beams.
##
## Deliberately blind to the motes: they are inert dust with no chemistry and no
## genome, and a beam that stopped on grit would spend the one clear signal the
## player owns on something that does not matter.
func _step_beams() -> void:
	beams.clear()
	if beam_range <= 0.0 or beam_bearings.is_empty() or _cell == null:
		return
	var origin := _cell.position
	for bearing: float in beam_bearings:
		var dir := _cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)
		var best := beam_range
		var found := false
		for i in _cells.size():
			var b := _cells[i]
			if not b.seeded:
				continue
			var to := b.pos - origin
			var along := to.dot(dir)
			if along <= 0.0 or along - b.radius > best:
				continue
			var perp := (to - dir * along).length()
			if perp >= b.radius:
				continue
			var hit := along - sqrt(maxf(b.radius * b.radius - perp * perp, 0.0))
			if hit >= 0.0 and hit < best:
				best = hit
				found = true
		beams.append([bearing, best, found])


## `palp`. The nearest body inside touch range, as a bearing and a closeness --
## 1 against the skin, 0 at the edge of reach. No light, no chemistry, no size:
## touching something tells you it is there and nothing else, which is exactly
## what makes it worth a slot to a cell that cannot see.
func _step_touch() -> void:
	touch_level = 0.0
	if touch_range <= 0.0 or _cell == null:
		return
	var best := INF
	var at := Vector2.ZERO
	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		var d := b.pos.distance_to(_cell.position) - b.radius - _cell.radius
		if d < best:
			best = d
			at = b.pos
	if best >= touch_range:
		return
	touch_level = clampf(1.0 - maxf(best, 0.0) / touch_range, 0.0, 1.0)
	touch_bearing = _cell.bearing_to(at)


## Concentration contributed by one source at distance [param d].
func scent(d: float) -> float:
	if d >= SCENT_RANGE:
		return 0.0
	var v := pow(CORE_RANGE / maxf(d, CORE_RANGE), SCENT_FALLOFF)
	return minf(1.0, v * smoothstep(SCENT_RANGE, SCENT_RANGE - SCENT_WINDOW, d))


# ---------------------------------------------------------------------------
# Ground truth, for an observer entitled to it -- which is the full-vision view
# and nothing the organism can sense.
# ---------------------------------------------------------------------------

## Where the cells currently are. Rebuilt on the spot rather than kept in step,
## so it is never one frame stale; read it and do not hold it across frames.
func points() -> PackedVector2Array:
	if _points.size() != _cells.size():
		_points.resize(_cells.size())
	for i in _cells.size():
		_points[i] = _cells[i].pos
	return _points


## Body radii, index-matched to [method points].
func radii() -> PackedFloat32Array:
	if _radii.size() != _cells.size():
		_radii.resize(_cells.size())
	for i in _cells.size():
		_radii[i] = _cells[i].radius
	return _radii


## Which way each body is pointing, index-matched to [method points]. Radians
## clockwise from world north, the cell's own convention.
##
## Only the view wants this, and it wants it because §4.1 places cilia by the
## ovoid's own parameter rather than by bearing: a fringe with an anterior arc
## and a posterior arc is meaningless on a body with no front. It is ground
## truth, like [method points] -- nothing the organism can sense.
func headings() -> PackedFloat32Array:
	if _headings.size() != _cells.size():
		_headings.resize(_cells.size())
	for i in _cells.size():
		_headings[i] = _cells[i].heading
	return _headings


## Each cell's `{gene: tier}`, index-matched to [method points]. The live
## dictionaries: read them, and do not write through them.
func genomes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.resize(_cells.size())
	for i in _cells.size():
		out[i] = _cells[i].genome
	return out


## How wide cell [param index]'s mouth opens, in world units. Anything whose
## radius is below this fits in it -- including, sometimes, the player.
func gape_at(index: int) -> float:
	return _gape(_cells[index]) if index >= 0 and index < _cells.size() else 0.0


## Is anything hunting the player at all, and which one. -1 for none; the
## nearest when there is more than one.
func hunter() -> int:
	var best := -1
	var best_d := INF
	for i in _cells.size():
		var b := _cells[i]
		if b.state != State.STALK or b.target != TARGET_PLAYER:
			continue
		var d := b.pos.distance_to(_cell.position)
		if d < best_d:
			best_d = d
			best = i
	return best


func hunting() -> bool:
	return hunter() >= 0


# ---------------------------------------------------------------------------
# Seeding. §1.3: a floor that never moves, a middle that tracks you, and a
# ceiling you can reach.
# ---------------------------------------------------------------------------

func _seed(index: int) -> void:
	var b := _cells[index]
	var angle := randf_range(-PI, PI)
	var distance := randf_range(RING_MIN, RING_MAX)
	var origin := _cell.position if _cell != null else Vector2.ZERO
	b.heading = randf_range(-PI, PI)
	b.state = State.DRIFT
	b.target = TARGET_NONE
	b.target_serial = 0
	b.calm = 0.0
	b.aim_clock = 0.0
	b.lost = 0.0
	b.rush = 0.0
	b.best = INF
	b.lunging = false
	b.break_clock = 0.0
	b.stale = 0.0
	b.stroke = randf_range(0.2, STROKE_GAP)
	b.wander = 0.0
	b.meals = 0
	_serial += 1
	b.serial = _serial

	# **The floor is an invariant, not a probability.** COUNT is 4, so a 0.45
	# coin lands zero drifters in the whole field about 9% of the time. One
	# counter fixes it: if seeding this cell would leave no drifter in the
	# field, it is a drifter. "The world cannot degenerate" then stops being a
	# statistical claim -- there is always something edible at every radius and
	# at every cytostome tier, so there is always a way back from a bad run.
	#
	# At setup this makes cell 0 a drifter, because nothing else is seeded yet,
	# and cell 0 is the authored first arrival. The opening is therefore always
	# something the player can eat, which is the right way round.
	if randf() < DRIFTER_SHARE or not _other_drifter(index):
		_seed_drifter(b)
	else:
		_seed_peer(b)

	# **The opening, and the only thing left that is authored.** Nothing that
	# could swallow the player begins the run already inside the range dread is
	# measured over, so a run opens on water that is quiet because it is quiet,
	# not because a timer says so. Danger then has to *arrive*, and arriving is
	# continuous -- which is the whole reason this is a placement rule and not a
	# gate on dread. It applies at setup only: a recycled cell is free to come
	# back anywhere in the ring, by which point the player has been swimming for
	# a while and knows what the water does.
	if _opening and _cell != null and _gape(b) > _cell.radius:
		distance = randf_range(maxf(DREAD_RANGE, RING_MIN), RING_MAX)

	b.pos = origin + Vector2(cos(angle), sin(angle)) * distance
	b.aim = b.pos
	b.flee_from = b.pos
	b.seeded = true


func _other_drifter(index: int) -> bool:
	for i in _cells.size():
		if i != index and _cells[i].seeded and _cells[i].drifter:
			return true
	return false


func _seed_drifter(b: Body) -> void:
	b.drifter = true
	b.radius = randf_range(DRIFTER_MIN, DRIFTER_MAX)
	# One gene at tier 1 and no mouth. It still carries something worth eating:
	# drifters are half the water, and a floor that fed you nothing to grow a
	# genome with would make the early game a dead end.
	b.genome = {}
	b.genome[_draw_gene(DRIFTER_GENES)] = 1


func _seed_peer(b: Body) -> void:
	b.drifter = false
	var mine := _cell.radius if _cell != null else CellBody.BASE_RADIUS
	# The floor of the drifter band is a guard, not a rule: the player only ever
	# grows, so in practice this clamp is the ceiling doing the work.
	b.radius = clampf(mine * (1.0 + randf_range(-PEER_SPREAD, PEER_SPREAD)),
		DRIFTER_MIN, ARRIVAL_RADIUS_MAX)
	b.genome = _draw_genome(b.radius)


## A real genome: a mouth, then as many other organs as the body has slots for.
## Every cell in the water is full to its own capacity, which is what makes
## §1's "the starting cell is already full" a property of cells rather than a
## special case for the player.
func _draw_genome(body_radius: float) -> Dictionary:
	var tiers := {&"cytostome": _draw_tier()}
	var capacity := CellBody.slots_for(body_radius)
	var pool: Array[StringName] = DRIFTER_GENES.duplicate()
	while tiers.size() < capacity and not pool.is_empty():
		var gene := _draw_gene(pool)
		pool.erase(gene)
		tiers[gene] = _draw_tier()
	# The ceiling, applied where §1.3 puts it: on the mouth, by taking tiers off
	# until it fits. A radius-40 arrival comes out at cytostome 1; a radius-28
	# one can keep cytostome 3.
	while tiers[&"cytostome"] > 0 \
			and CellBody.gape_of(int(tiers[&"cytostome"]), body_radius) > ARRIVAL_GAPE_MAX:
		tiers[&"cytostome"] = int(tiers[&"cytostome"]) - 1
	return tiers


func _draw_gene(pool: Array[StringName]) -> StringName:
	var total := 0
	for gene: StringName in pool:
		total += int(GENE_WEIGHTS.get(gene, 1))
	var roll := randi_range(1, maxi(total, 1))
	for gene: StringName in pool:
		roll -= int(GENE_WEIGHTS.get(gene, 1))
		if roll <= 0:
			return gene
	return pool[pool.size() - 1]


func _draw_tier() -> int:
	var total := 0
	for weight: int in TIER_WEIGHTS:
		total += weight
	var roll := randi_range(1, maxi(total, 1))
	for tier in TIER_WEIGHTS.size():
		roll -= TIER_WEIGHTS[tier]
		if roll <= 0:
			return tier
	return 1


# ---------------------------------------------------------------------------
# Small shared arithmetic.
# ---------------------------------------------------------------------------

func _gape(b: Body) -> float:
	return CellBody.gape_of(Genome.tier_of(b.genome, &"cytostome"), b.radius)


## What this cell swims at while chasing: the chase's reference speed times the
## margin Phase 4 measured. A hunter is faster than what it is chasing, always,
## which is why dread does not mean "flee" -- it means commit away from that
## bearing now, before it lunges.
func _cruise_speed(b: Body) -> float:
	return _reference_speed(b) * CRUISE_OVER_PREY


func _lunge_speed(b: Body) -> float:
	return _reference_speed(b) * LUNGE_OVER_PREY


## The speed the chase is scaled to.
##
## **Against the player this is exactly §7.1's settled contract**: the prey's own
## realised speed, so the chase stays a chase at every `flagellum` tier and only
## `cirrus` improves the dodge. Nothing here re-tunes that; §7.1's measurement is
## Phase 6's.
##
## Against another cell in the field it is the larger of the prey's speed and the
## hunter's own, and it has to be. A drifter moves at 9 u/s, and 1.2x9 is not a
## chase -- it is two objects converging at walking pace for three minutes, and
## §1.3's "cells genuinely eat each other" would be a thing that is technically
## possible and never observed. The player is never on this branch.
func _reference_speed(b: Body) -> float:
	if b.target == TARGET_PLAYER:
		return _cell.swim_speed()
	var mine := _own_speed(b)
	var prey := _target_body(b)
	if prey == null:
		return mine
	return maxf(mine, DRIFT_SPEED if prey.state == State.DRIFT else _own_speed(prey))


## A cell's own natural speed, derived from its flagellum tier through the same
## model the player's is -- so a chase between two field cells is the same chase
## the player is in.
func _own_speed(b: Body) -> float:
	return CellBody.speed_for(Genome.tier_of(b.genome, &"flagellum"))


func _target_body(b: Body) -> Body:
	if b.target < 0 or b.target >= _cells.size():
		return null
	var prey := _cells[b.target]
	return prey if prey.serial == b.target_serial else null


## Where the prey is. Falls back to the hunter's own position, which steers
## nothing anywhere -- deliberately not the player's, which is what turned a
## missing prey into a cell fleeing from the player.
func _target_pos(b: Body) -> Vector2:
	if b.target == TARGET_PLAYER:
		return _cell.position
	var prey := _target_body(b)
	return prey.pos if prey != null else b.pos


## Is there still a body at the other end of this chase at all.
func _target_present(index: int, b: Body) -> bool:
	if b.target == TARGET_PLAYER:
		return true
	return _target_body(b) != null and b.target != index


## Does it still fit in this mouth. Separate from [method _target_present]
## because the two deserve different answers: a prey that has gone is a chase
## with nothing in it, and a prey that has outgrown the mouth is a chase that is
## about to be given up on -- over OUTGROWN_GRACE, not instantly.
func _target_edible(b: Body) -> bool:
	if b.target == TARGET_PLAYER:
		return _cell.swallow_radius() < _gape(b)
	var prey := _target_body(b)
	return prey != null and prey.radius < _gape(b)


## Same convention as the cell: radians clockwise from world north, front is the
## top of the screen.
func _forward(heading: float) -> Vector2:
	return Vector2(sin(heading), -cos(heading))


func _angle_of(v: Vector2, fallback: float) -> float:
	if v.length_squared() <= 0.0:
		return fallback
	return atan2(v.x, -v.y)
