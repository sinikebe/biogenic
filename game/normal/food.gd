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
## **Only for [method Cilia.mouth_touches]**, which is where the lip bow's
## geometry is defined and therefore where the water has to ask whether a mouth
## is actually on something. Nothing else in that file is read from here and
## nothing here draws. The preload chain is cilia -> genome -> cell, so this
## adds no cycle.
const Cilia := preload("res://game/vision/cilia.gd")

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
## A mouth closed on something and could not swallow it. [param bearing] is
## where it happened -- a mouth on your skin, or your own mouth on a body it is
## chewing through -- and [param strength] is 0..1, how hard.
##
## **Deliberately not a new channel.** The run posts this as the `hit` the
## membrane has had since Phase 1, which is the sensation that already means
## *contact, there*. A wound is learnt by being bitten at a bearing enough
## times, which is the same way everything else in this game is learnt.
signal bitten(bearing: float, strength: float)
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

## Share of arrivals drawn absolutely rather than relative to the player, for a
## cell that can see what is coming. [method _drifter_share] is what the seeder
## actually asks; a blind one gets [constant BLIND_DRIFTER_SHARE].
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
## fits under this.
##
## **It stops meaning "at r40 nothing can eat you" and starts meaning "the water
## never seeds a mouth that can end you in one contact"** (edibility.md §4).
## That claim is still true and still a real bound on the worst arrival. What is
## gone is the safe harbour: anything with a mouth can take you apart given time
## and position, so there is no radius at which the water cannot kill you -- and
## therefore no won state. lifecycle.md §2 rebuilds the arc on capacity instead.
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
## **`chemocyte` is weighted like a starting organ, and that is deliberate.**
## Taste stopped being innate with this phase, so a nose is the difference
## between a run and a wander -- it has to be the commonest thing the water can
## hand you, on a par with the three organs you are born with.
const GENE_WEIGHTS := {
	&"cytostome": 3, &"cirrus": 4, &"flagellum": 4, &"stigma": 3,
	&"chemocyte": 4, &"ampulla": 3,
	&"ocellus": 2, &"axoneme": 2,
	&"statocyst": 2, &"rhabdom": 2, &"palp": 2, &"myoneme": 2,
	&"trichocyst": 2, &"pellicle": 2, &"toxicyst": 2,
	&"plastid": 2, &"vacuole": 2, &"crista": 2,
}
## Everything a drifter can be, and therefore everything the player can ever
## eat their way into. The mouth is not on this list by construction.
const DRIFTER_GENES: Array[StringName] = [
	&"cirrus", &"flagellum", &"stigma", &"chemocyte", &"ampulla",
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
const TIER_WEIGHTS: Array[float] = [0.0, 3.0, 2.0, 1.0]

# --- What a cell that cannot see meets ---------------------------------------
# The owner: *"When blind, we have to make stronger enemies very rare. It must
# be mostly defenceless food."*
#
# **Keyed on the player's own senses, never on the view.** "One simulation, two
# views" has been load-bearing since Phase 3 -- the two views differ only in
# what is drawn, and full vision exists to catch the membrane lying. A water
# that were gentler in point of view would destroy that. Keyed on the genome
# instead it reads identically in both views, because it depends on what the
# body is and not on which camera is pointed at it.
#
# It is also fair in a way a difficulty slider is not: **the danger you face is
# always danger you could have seen coming.** And it makes a slot spent on a
# sense open up a richer world rather than merely reveal the same one.
#
# No new lever. A drifter has no cytostome and BITE_BY_TIER[0] is a hard zero,
# so a drifter is *literally* defenceless food; the two numbers that decide how
# much of the water is one are the two §9.6 already named.

## The four genes that answer *where is something* -- the same four
## normal_mode.gd hands out at five seconds. Nothing else counts as sight: the
## ones left out sharpen or steady what these find.
const SENSE_GENES: Array[StringName] = [
	&"chemocyte", &"ampulla", &"ocellus", &"stigma"]
## Summed sensory tiers at which the water is the shipped one. Five is a real
## investment -- two organs, one of them grown -- and not the free tier-1 sense
## every run is handed at five seconds, which lands this at 0.2.
const SENSE_FULL := 5.0
## Blind: nine bodies in ten have no mouth at all, and the rare peer that does
## has the poorest one. Neither is a rule -- both are lerped toward the numbers
## above by [method _sensed], so a cell growing its first eye watches the water
## get worse continuously rather than in a step.
const BLIND_DRIFTER_SHARE := 0.92
const BLIND_TIER_WEIGHTS: Array[float] = [0.0, 8.0, 1.0, 0.0]

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
##
## **It is one source's contribution, not the whole field.** Thirty-four bodies
## sum, so a bearing exists long before any single one crosses this -- and since
## `chemocyte` arrived, a cell only sums what is inside its own nose's reach
## ([constant CellBody.SMELL_RANGE_BY_TIER]). The ring stays what it always was:
## where one body on its own becomes worth smelling.
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

# --- The bite ---------------------------------------------------------------
# **What the mouth does to what it cannot swallow.** The gape rule is untouched
# and still decides which of the two happens: a body that fits is swallowed
# whole exactly as before, and a body that does not is bitten. cell.gd owns what
# a bite is worth ([method CellBody.bite_damage]); this owns how loud it is.

## How loud the worst bite in the game is on the skin. Everything else is
## measured against it, so a tier-1 mouth gnawing an armoured body reads as the
## small thing it is and a tier-3 mouth on bare membrane reads as the end.
const BITE_HIT_FLOOR := 0.22
## A bite you land is felt through your own mouth rather than through your skin,
## so it is the same sensation at a fraction of the strength. It has to be felt
## at all: point of view cannot see that its mouth is on something, and a
## mechanic with no readout is not a mechanic.
const BITE_FELT_SHARE := 0.45

# --- Bodies are solid -------------------------------------------------------
## How much of an overlap is pushed out per frame. Below 1 on purpose: a full
## resolve every frame makes three stacked bodies jitter against each other,
## and a cell is a soft thing in thick water rather than a billiard ball. At
## 0.5 an overlap is 97% gone in five frames.
const PUSH_SHARE := 0.5
## How much a shoulder-charge bounces, against [method CellBody.bump]'s 0.55 for
## a grain of grit. Low because this has to leave the player able to *hold* its
## nose against something it is biting -- a bouncy collision would spit them off
## the thing they are trying to chew through, and the whittle is the one new
## option the player gets out of all this.
const PUSH_RESTITUTION := 0.12

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
## Authored, like mote 0: placed along the cell's real velocity once it moves.
## The drifter floor guarantees cell 0 is a drifter at setup, so the first thing
## the player ever meets is always something it can eat.
##
## **It has to be findable with whatever sense you were handed at five seconds**
## (normal_mode.gd's FIRST_SENSES), which is what moved it down from 1400. The
## weakest of the two senses that can actually reach a drifter is a tier-1
## `chemocyte` at 1100; a tier-1 `ampulla` pings to 1100 as well. 1000 sits
## inside both, and still outside the frame -- the half-diagonal of a 20:9
## canvas is 877 -- so the opening is not a body sitting in the corner at t=0.
##
## The other two draws are allowed to miss it, and that is the cost of the
## placement decision: an `ocellus` reaches 620 and only along the arc it was
## put on, and a `stigma` sees mass, which a drifter does not have.
const FIRST_DISTANCE := 1000.0

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

# --- Dread, and the hole in it that was measured -----------------------------
# **A second term SUMMED onto the one above, never branched against it.** Two
# r40 cells with cytostome 1 parked with their mouths 43 units off an r40
# player's skin score a ratio of 0.82, which is below THREAT_LOW, so they
# contributed *exactly zero* -- and they can chew that player to death in
# eighteen seconds. The membrane was silent about a body that could kill you in
# eighteen seconds. It was silent about it before edibility.md too, because the
# bite has been shipped for a release: this is a defect being fixed rather than
# a cost being paid. §3.
#
# Four properties, each of which is the reason for one constant:
#
# - **continuous everywhere.** bite_damage is continuous in every argument and
#   clampf is continuous, so a body's contribution moves smoothly as its mouth
#   grows, as you grow and as you are hurt. There is no question here with a
#   yes/no answer, which is the rule the whole of THREAT_LOW's note defends.
# - **theta = PI, not the live bearing.** Dread is what a body *could* do.
#   Feeding it the real angle would make dread swing as the player turns, which
#   is `statocyst`'s job and not fear's.
# - **it keys on your own wound**, continuously: a whole body feels a third of
#   it, a chewed one all of it. Being hurt genuinely does make the water more
#   dangerous and the membrane should say so. It adds no state and no gate --
#   it is a fact about your own body.
# - **520, not 1400.** Something that needs twelve seconds of unbroken contact
#   is not a threat at a kilometre. The short range is what stops seventeen
#   mouthed peers raising the floor of the readout: the term is quiet almost
#   always and loud exactly when something is on you.

## A chewer never reads as loud as a swallower.
const CHEW_SHARE := 0.55
## The rate at which the term saturates: a mouth that could open you in twelve
## seconds of contact is reading its whole share.
const CHEW_FULL_SECONDS := 12.0
## What a whole body feels of it, against a body already half eaten.
const CHEW_HURT_FLOOR := 0.35
## And its own, much shorter, distance falloff.
const CHEW_RANGE := 520.0

# --- Blood in the water ------------------------------------------------------
## How far through a body something has to be before the rest of the water will
## commit to finishing it. The owner's sentence from the other side -- *a body
## that has been opened up is a body that could not defend itself* -- and it
## produces the best emergent moment available: **you get hurt, and the water
## changes its mind about you.** The wound is drawn on every body already, so
## the player watches it happen to somebody else before it happens to them. §5.
const CHEW_INVITE := 0.35
## A committed hunter leads the point this far behind its target's nucleus
## rather than the nucleus itself, so it arrives on the quarter and the water
## plays by the rule it teaches. **The change with the largest felt effect in
## edibility.md and the one most likely to be too strong**; it is the second
## dial after FLANK_ASTERN and the first thing to turn off if the water feels
## unfair.
const AIM_STERN_SHARE := 0.6

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

# --- The ping (`ampulla`) ---------------------------------------------------
## How fast a return comes back, in world units per second. **This is the whole
## reason the ping reads as a sweep rather than as a chord**: the nearest body
## answers first and the farthest last, so one pulse arrives on the membrane as
## a series of separate marks walking outward in time. At 1250 a tier-1 return
## from the edge of reach lands 0.88s after the pulse left, which is comfortably
## longer than the mark it fires takes to decay.
const PING_SPEED := 1250.0
## How many bodies one pulse may answer for, nearest first. A cap rather than a
## rule: thirty-four bodies inside reach would be a strobe, and the far half of
## them would be inaudible under the near half anyway.
const PING_RETURNS := 5
## How a return fades with range. **Deliberately not linear**, and measured: the
## water keeps most of its bodies between 900 and 1400 units out, so a linear
## fall put nearly every tier-1 return at strength 0.14 -- a mark too faint to
## be a mark, for the one gene whose whole promise is *there is something over
## there*. At 0.6 the same return reads 0.30 and a body at half reach reads
## 0.66, so distance is still legible and nothing is silent.
const PING_FALLOFF := 0.6
## **The smallest gap between two returns of one pulse.** Flight time alone does
## not carry the sweep, and that was measured rather than assumed: the water
## keeps its bodies in a band, so four of them routinely answered within 30ms of
## each other and the membrane's one envelope collapsed the lot into a single
## mark. A return is pushed back to at least this far behind the one in front of
## it, so a pulse is always heard as a series. The fiction is the organ's, not
## the water's -- an ear resolves one thing at a time.
const PING_MIN_GAP := 0.17

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
	## How far through this body something has chewed, 0..1. Mends on its own at
	## [constant CellBody.MEND_SECONDS], exactly as the player's does.
	var wound := 0.0
	## Seconds until this mouth can bite again, against [constant
	## CellBody.BITE_GAP].
	var bite := 0.0

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
## `chemocyte`. How far this cell's chemoreceptors reach, written once a frame
## by the run. 0 is a cell with no nose, and a cell with no nose gets no
## bearing to anything edible at all.
var smell_range := 0.0
## **What the scent field is worth to this particular nose**: the same sum as
## [member concentration], restricted to sources inside [member smell_range].
##
## Two numbers rather than one, and the split is the point. [member
## concentration] is what the *water* is like, and it drives the metabolic beat,
## which is a property of the body and not of its senses -- an eyeless, noseless
## cell still beats faster in rich water. This is what the *organ* picks up, and
## it is the only one of the two that reaches the membrane.
var taste_level := 0.0
## `ampulla`. How far a pulse carries and how often one goes out, written once a
## frame by the run. Either at 0 is a cell with no electroreceptor.
var ping_range := 0.0
var ping_period := 0.0
## Returns that became due **this frame**: `[bearing, strength]`, nearest first,
## strength 1 against the skin and 0 at the edge of reach. Drained by the run,
## which is the only thing allowed to post them. Bodies, not meals: a ping
## answers off anything with a body in it, which is exactly what the scent field
## can never do.
var pings: Array = []
## How far the newest wavefront has travelled, or -1 for nothing in flight.
## Ground truth for the full-vision view, which draws the sweep; the organism
## only ever gets [member pings].
var ping_front := -1.0
## `[seconds until due, world position, strength]` for returns still in flight.
## The position stops here: [method _step_pings] turns it into a bearing at the
## moment the return lands, exactly as [method _step_touch] does.
var _echoes: Array = []
var _ping_clock := 0.0
var _ping_age := -1.0
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
## **Which way the dart looks**: the body-relative bearing of the arc the gene
## is worn on, written once a frame by the run exactly as [member beam_bearings]
## is. The organ answers only inside [constant CellBody.DART_ARC_DEG] of it, so
## a dart in a rear slot is the answer to being flanked and placement becomes a
## defensive decision. Meaningless while [member dart_range] is 0.
var dart_bearing := 0.0
## `toxicyst`. Negative means the cell has no venom and a kill is a kill.
var venom_cost := -1.0
var _dart_clock := 0.0
## The player's own mouth, reloading. Here and not on the cell for the same
## reason [member _dart_clock] is: the encounter lives in this file.
var _bite_clock := 0.0

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
var _wounds := PackedFloat32Array()


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
	taste_level = 0.0
	pings.clear()
	_echoes.clear()
	_ping_clock = 0.0
	_ping_age = -1.0
	ping_front = -1.0
	_dart_clock = 0.0
	_bite_clock = 0.0


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
	_bite_clock = maxf(_bite_clock - delta, 0.0)
	for i in _cells.size():
		_step_body(i, delta)
	_step_recycle()
	# Contact first, then separation: a body is eaten or bitten on the frame it
	# arrives in a mouth, and only then pushed back out of the one it is in.
	# The other order would make the mouth chase a body it has just shoved away.
	if not _step_contacts():
		return
	_step_separate()
	_step_sense()
	_step_beams()
	_step_pings(delta)
	_step_touch()


# ---------------------------------------------------------------------------
# Behaviour. A cell that is not hunting drifts, which is exactly what Phase 4's
# food did; a cell that is hunting runs Phase 4's predator. Same object, two
# states, and the transition between them is the gape rule.
# ---------------------------------------------------------------------------

func _step_body(index: int, delta: float) -> void:
	var b := _cells[index]
	# Every body knits and every mouth reloads, in every state. Neither is
	# behaviour: a cell does not decide to heal.
	b.wound = CellBody.mended(b.wound, delta)
	b.bite = maxf(b.bite - delta, 0.0)
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
	if _first_hunt <= 0.0 and _worth_committing_to(b, gape,
			_cell.swallow_radius(), _cell.wound):
		var d := b.pos.distance_to(_cell.position)
		if d <= maxf(reach, b.radius + _cell.radius):
			best = TARGET_PLAYER
			best_d = d

	for j in _cells.size():
		if j == index:
			continue
		var other := _cells[j]
		if not other.seeded \
				or not _worth_committing_to(b, gape, other.radius, other.wound):
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


## **What a cell will cross the water for.** The rules are symmetric; the
## behaviour is not, and must not be, or the water becomes a brawl in which
## every cell gnaws every other one. A cell still commits only to what it can
## swallow -- plus the one addition edibility.md §5 makes: a body already opened
## up past [constant CHEW_INVITE]. Blood in the water.
##
## Biting what it bumps into is unchanged and is not decided here: contact is
## contact, and a mouth closing on something is always worth a bite.
func _worth_committing_to(b: Body, gape: float, target_radius: float,
		target_wound: float) -> bool:
	if target_radius < gape:
		return true
	# It cannot swallow it, so the only reason to go is that somebody else has
	# already opened it -- and only a mouth that could actually finish the job.
	return target_wound >= CHEW_INVITE \
		and CellBody.BITE_BY_TIER[clampi(Genome.tier_of(b.genome, &"cytostome"),
			0, CellBody.BITE_BY_TIER.size() - 1)] > 0.0


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
	# **`trichocyst`. It came inside dart range, on the arc the organ is on, and
	# it is leaving.** Automatic rather than a button: the design has no second
	# control to spend and the whole of the gene is the cooldown -- one run
	# broken off, then a long wait, so it buys an escape and never safety.
	#
	# **The arc is the point, and it is the one fix §2 calls required.** A dart
	# that fired at whatever was near was a defence with no position, on a rule
	# that is now entirely about position. The same wiring the `ocellus` already
	# has: the slot is the arc, the arc is the bearing, and the run posts it.
	if dart_range > 0.0 and d < dart_range and _dart_clock <= 0.0:
		var off := absf(angle_difference(dart_bearing, _cell.bearing_to(b.pos)))
		if off <= deg_to_rad(CellBody.DART_ARC_DEG) * 0.5:
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
## **It aims for the quarter, not the nucleus** ([constant AIM_STERN_SHARE]).
## The water plays by the rule it teaches, and being flanked is how a player
## learns to flank.
func _predict(b: Body, t: float) -> Vector2:
	if b.target != TARGET_PLAYER:
		var prey := _target_body(b)
		if prey == null:
			return _target_pos(b)
		var speed := DRIFT_SPEED if prey.state == State.DRIFT else _cruise_speed(prey)
		var ahead := _forward(prey.heading)
		return prey.pos + ahead * (speed * t - prey.radius * AIM_STERN_SHARE)
	var cruise := _cell.forward() * _cell.swim_speed()
	var k := maxf(CellBody.DRAG, 0.001)
	return _cell.position + cruise * t \
		+ (_cell.velocity - cruise) * ((1.0 - exp(-k * t)) / k) \
		- _cell.forward() * (_cell.radius * AIM_STERN_SHARE)


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
#
# **Two things changed here and both are about the mouth being an organ.**
#
# 1. *Where* contact is. It used to be `distance < a.radius + b.radius`, which
#    is proximity: a cell ate you by bumping you anywhere, with its flank, with
#    its tail, while swimming away from you. The art had spent the whole of
#    §1.1.1 promising the opposite -- a bow across the nose with a measured span
#    -- so the game was contradicting its own drawing, and being eaten from
#    behind was the commonest way that showed. Contact is now
#    [method Cilia.mouth_touches]: the other body has to overlap the region the
#    lip bow actually occupies. One function, asked in both directions.
#
# 2. *What happens* when the mouth is on something it cannot swallow. It used to
#    be nothing at all -- a standoff at contact, with neither cell able to do
#    anything about the other. The gape still decides which of the two happens,
#    which is what keeps every mark §1.1.1 draws meaning what it meant:
#
#      mouth on it, body fits the gape -> swallowed whole, exactly as before
#      mouth on it, body too big       -> a bite, and bites accumulate
#
#    A body bitten to nothing comes apart and feeds whoever finished it. That
#    makes `pellicle` a real defence (it divides the bite) and `toxicyst` a real
#    punishment (it charges the biter a share of what it just did), using the
#    two genes that already meant exactly those things.
#
# **Nothing here is gated on state except the one asymmetry that was already
# here**, and nothing here reaches dread. A bite asks no question with a yes/no
# answer that dread can see; the sum in _step_sense() is untouched.
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
	var my_gape := _cell.gape()
	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		# **The whole of the fix, and it is two lines.** Its mouth on me, and my
		# mouth on it, measured against the bow each of us is drawn with. Both
		# can be false while the two bodies are overlapping -- that is two cells
		# barging each other, and it is now a thing that can happen.
		var its_mouth := _mouth_reaches(b, _gape(b), _cell.position, _cell.radius)
		var my_mouth := Cilia.mouth_touches(_cell.position, _cell.heading,
			_cell.radius, my_gape, b.pos, b.radius)
		if not (its_mouth or my_mouth):
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
		if its_mouth and b.state == State.STALK and b.target == TARGET_PLAYER \
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
		if my_mouth and b.radius < my_gape:
			# Emit where it was before recycling it, so a listener never has to
			# work out which one this was -- the mistake motes.gd documents.
			eaten.emit(_meal_value(b.radius), Genome.dominant_of(b.genome), b.pos)
			_seed(i)
			continue
		# Not swallowed, either way round. What used to be a standoff with
		# nothing in it is now two mouths doing what mouths do.
		var serial := b.serial
		if its_mouth and _bitten_by(i, b):
			return false
		# Its own venom may have just taken that body out of the water, and
		# then this slot is a different cell somewhere else entirely. The
		# player's mouth was measured against the one that has gone.
		if my_mouth and b.serial == serial and _bite_from_me(i, b):
			return false

	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded or b.drifter:
			continue
		var gape := _gape(b)
		for j in _cells.size():
			if j == i:
				continue
			var other := _cells[j]
			if not other.seeded:
				continue
			if not _mouth_reaches(b, gape, other.pos, other.radius):
				continue
			if other.radius >= gape:
				# Too big to swallow, so it gets chewed instead. Same clock,
				# same table and same two defending genes as the player's.
				if _chew(b, other) >= 1.0:
					_devour(b, other)
					_seed(j)
				if b.wound >= 1.0:
					# Its own venom finished the biter. Nothing feeds on that.
					_seed(i)
					break
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


## Is [param b]'s mouth on a body of [param body_radius] centred at [param at].
## [param gape] is passed in rather than looked up because the cell-against-cell
## pass asks this of one mouth against every body in the water.
func _mouth_reaches(b: Body, gape: float, at: Vector2, body_radius: float) -> bool:
	return Cilia.mouth_touches(b.pos, b.heading, b.radius, gape, at, body_radius)


## One cell's mouth closing on another it cannot swallow. Returns the target's
## wound afterwards, so the caller can see whether that was the last bite.
## Does nothing at all, and costs nothing, while the mouth is still reloading.
func _chew(b: Body, other: Body) -> float:
	if b.bite > 0.0:
		return other.wound
	var damage := CellBody.bite_damage(Genome.tier_of(b.genome, &"cytostome"),
		_gape(b), other.radius, Genome.tier_of(other.genome, &"pellicle"),
		_flank_theta(other.heading, other.pos, b.pos))
	if damage <= 0.0:
		return other.wound
	b.bite = CellBody.BITE_GAP
	other.wound = clampf(other.wound + damage, 0.0, 1.0)
	b.wound = clampf(b.wound + CellBody.venom_back(
		Genome.tier_of(other.genome, &"toxicyst"), damage), 0.0, 1.0)
	return other.wound


## **Where a bite landed, measured at the body it landed on**: the angle between
## that body's own heading and the direction the mouth arrived from. 0 is dead
## ahead, PI is dead astern. One definition, so a cell being flanked and the
## player being flanked are the same arithmetic. §1.2.
func _flank_theta(target_heading: float, target_pos: Vector2,
		mouth_pos: Vector2) -> float:
	var from := mouth_pos - target_pos
	if from.length_squared() <= 0.0001:
		return 0.0
	return absf(angle_difference(target_heading, _angle_of(from, target_heading)))


## **Something has its mouth on you and cannot swallow you.** Returns true when
## that bite was the one that finished the player, on the same contract as the
## kill above: the caller stops touching the field immediately.
func _bitten_by(index: int, b: Body) -> bool:
	if b.bite > 0.0:
		return false
	var bearing := _cell.bearing_to(b.pos)
	# Measured at the player, who is the target here: the bearing the mouth is
	# on *is* theta, because a body-relative bearing is already the angle from
	# its own heading. A mouth astern is the 2.10.
	var damage := CellBody.bite_damage(Genome.tier_of(b.genome, &"cytostome"),
		_gape(b), _cell.radius, _cell.extra(&"pellicle"), absf(bearing))
	if damage <= 0.0:
		return false
	b.bite = CellBody.BITE_GAP
	_cell.wound = clampf(_cell.wound + damage, 0.0, 1.0)
	if _cell.wound >= 1.0:
		# Chewed through rather than swallowed, and it ends the same way. The
		# player has felt every one of the bites that got here, at this bearing.
		killed.emit(bearing)
		if b.state == State.STALK:
			_break_off(b)
		return true
	# `toxicyst` from the other end: biting a venomous body costs the mouth a
	# share of what it just did, and enough of them kill it.
	b.wound = clampf(b.wound + CellBody.venom_back(
		_cell.extra(&"toxicyst"), damage), 0.0, 1.0)
	if b.wound >= 1.0:
		_seed(index)
	bitten.emit(bearing, _felt(damage))
	return false


## **Your own mouth on a body too big to swallow.** The option the player never
## had: whittle it down and it comes apart, and then it is a meal on exactly the
## terms a swallowed one is. Returns true when the venom in it finished you.
func _bite_from_me(index: int, b: Body) -> bool:
	if _bite_clock > 0.0:
		return false
	# Measured at the body being chewed: its own heading against the direction
	# this mouth arrived from. Holding your nose on a cell's stern is worth 2.10
	# times holding it on its nose, and that is the owner's sentence made true.
	var damage := CellBody.bite_damage(_cell.tier(&"cytostome"), _cell.gape(),
		b.radius, Genome.tier_of(b.genome, &"pellicle"),
		_flank_theta(b.heading, b.pos, _cell.position))
	if damage <= 0.0:
		return false
	_bite_clock = CellBody.BITE_GAP
	var bearing := _cell.bearing_to(b.pos)
	b.wound = clampf(b.wound + damage, 0.0, 1.0)
	var back := CellBody.venom_back(Genome.tier_of(b.genome, &"toxicyst"), damage)
	_cell.wound = clampf(_cell.wound + back, 0.0, 1.0)
	# The death is checked before the meal, and in that order on purpose:
	# `eaten` is not idempotent and feeding a corpse would be silent.
	if _cell.wound >= 1.0:
		killed.emit(bearing)
		return true
	if b.wound >= 1.0:
		eaten.emit(_meal_value(b.radius), Genome.dominant_of(b.genome), b.pos)
		_seed(index)
	bitten.emit(bearing,
		maxf(_felt(damage) * BITE_FELT_SHARE, _felt(back)))
	return false


## How loud a wound of [param damage] is on the skin, 0..1, against the worst
## bite any mouth in the game can land. The cap that matters is the signal
## bus's; this is only the shape of it.
func _felt(damage: float) -> float:
	if damage <= 0.0:
		return 0.0
	var worst: float = CellBody.BITE_BY_TIER[CellBody.BITE_BY_TIER.size() - 1]
	return clampf(damage / maxf(worst, 0.001), BITE_HIT_FLOOR, 1.0)


# ---------------------------------------------------------------------------
# Bodies are solid.
#
# Cells used to pass through each other, and the designer's note on the
# standoff branch above is what this answers: two bodies posed at contact drew
# as crossing rims with one cell's cilia inside the other's body, which reads as
# a drawing fault rather than as two organisms.
#
# **This is a change to how the water moves and not only to how it is drawn.**
# A body that can be shouldered is a body a chase can be blocked by. Nothing
# here re-tunes COMMIT_RANGE or the escape contract to compensate -- §7.1 hands
# that measurement to Phase 6, and it has to be made against this, not guessed
# at from here.
#
# It runs *after* contact, so a mouth still gets the frame in which something
# arrived in it. That is not a nicety: the lip bow reaches past the nose
# (1.24 r + 0.3 gape against a body of 1.18 r), so a mouth closes on prey
# **before** the two bodies touch at all, and eating survives solid bodies for
# exactly that reason.
# ---------------------------------------------------------------------------

func _step_separate() -> void:
	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		var offset := _cell.position - b.pos
		var d := offset.length()
		var overlap := b.radius + _cell.radius - d
		if overlap <= 0.0:
			continue
		var normal := offset / d if d > 0.001 else -_forward(b.heading)
		# Share it by **area**, so a big body shoulders a small one aside
		# instead of the two meeting in the middle. A drifter bounces off the
		# player; a grown cell moves them.
		var share := _give_way(b.radius, _cell.radius)
		_cell.position += normal * (overlap * share * PUSH_SHARE)
		b.pos -= normal * (overlap * (1.0 - share) * PUSH_SHARE)
		# And it is felt as motion, not only as a position: the same knock a
		# mote gives, softer, because a cell is not a grain of grit.
		_cell.bump(normal, PUSH_RESTITUTION)

	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		for j in range(i + 1, _cells.size()):
			var other := _cells[j]
			if not other.seeded:
				continue
			var offset := b.pos - other.pos
			var d := offset.length()
			var overlap := b.radius + other.radius - d
			if overlap <= 0.0:
				continue
			var normal := offset / d if d > 0.001 else _forward(b.heading)
			var share := _give_way(other.radius, b.radius)
			b.pos += normal * (overlap * share * PUSH_SHARE)
			other.pos -= normal * (overlap * (1.0 - share) * PUSH_SHARE)


## What share of an overlap the second body gives up, by area.
func _give_way(theirs: float, mine: float) -> float:
	var them := theirs * theirs
	var me := mine * mine
	return them / maxf(them + me, 0.001)


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
	# The same sum again, over only what this cell's nose reaches. Kept apart
	# from `total` on purpose: see [member taste_level].
	var smelt := 0.0
	var smelt_pull := Vector2.ZERO

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
				if d < smell_range:
					smelt += c
					smelt_pull += offset / maxf(d, 0.001) * c

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
		worst = maxf(worst, level)
		if level > 0.0:
			dread += clampf((DREAD_RANGE - d) / (DREAD_RANGE - DREAD_CORE),
				0.0, 1.0) * level

		# **And what it could chew through, added to that and never substituted
		# for it.** The hole THREAT_LOW leaves: a mouth that cannot swallow you
		# can still take you apart, and the membrane used to say nothing at all
		# about one parked on your skin. See the CHEW_ block for why each of the
		# four constants is there and why not one of them is a gate.
		if d >= CHEW_RANGE:
			continue
		var rate := CellBody.bite_damage(Genome.tier_of(b.genome, &"cytostome"),
			_gape(b), _cell.radius, _cell.extra(&"pellicle"), PI) \
			/ CellBody.BITE_GAP
		if rate <= 0.0:
			continue
		var urgency := clampf(rate * CHEW_FULL_SECONDS, 0.0, 1.0)
		dread += CHEW_SHARE * urgency \
			* clampf((CHEW_RANGE - d) / (CHEW_RANGE - DREAD_CORE), 0.0, 1.0) \
			* (CHEW_HURT_FLOOR + (1.0 - CHEW_HURT_FLOOR) * _cell.wound)

	concentration = minf(total, 1.0)
	# **The bearing is the nose's, not the water's.** A cell with no chemocyte
	# leaves here with taste_level 0 and taste_bearing 0, which is what makes
	# "an organ you have not grown is silent" true at the source as well as at
	# the two gates downstream of it.
	taste_level = minf(smelt, 1.0)
	if taste_level > 0.0 and smelt_pull.length_squared() > 0.0:
		taste_bearing = _cell.bearing_to(_cell.position + smelt_pull)
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


## **The ping.** `ampulla`: a pulse on its own clock, and a bearing for every
## body it comes back off -- edible, inedible, hunting you or asleep. That is
## the whole of what makes it a different sense from `chemocyte` rather than a
## second skin on it: the scent field is a statement about food, and most of
## what is out there is not food.
##
## Returns are staggered by their own flight time, which is what turns one pulse
## into a sweep: the nearest body answers at `d / PING_SPEED` and the farthest
## almost a second later. Nothing here posts and nothing here keeps a position
## past the frame it becomes a bearing.
func _step_pings(delta: float) -> void:
	pings.clear()
	if _cell == null:
		return
	if ping_range <= 0.0 or ping_period <= 0.0:
		# The organ was lost, or was never grown. Anything still in flight is
		# dropped rather than delivered: it was never heard.
		_echoes.clear()
		_ping_clock = 0.0
		_ping_age = -1.0
		ping_front = -1.0
		return

	_ping_clock -= delta
	if _ping_clock <= 0.0:
		_ping_clock = ping_period
		_ping_age = 0.0
		_cast_ping()
	elif _ping_age >= 0.0:
		_ping_age += delta

	var front := _ping_age * PING_SPEED
	ping_front = front if _ping_age >= 0.0 and front <= ping_range else -1.0

	# Backwards, so removing one does not skip the next.
	for i in range(_echoes.size() - 1, -1, -1):
		var echo: Array = _echoes[i]
		echo[0] -= delta
		if echo[0] > 0.0:
			continue
		pings.append([_cell.bearing_to(echo[1]), echo[2]])
		_echoes.remove_at(i)
	# Loudest first. The membrane has one envelope for this and it keeps the
	# loudest mark, so the order only matters to a later subscriber -- but
	# "nearest thing first" is the only order a radar return has.
	pings.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])


## Everything inside reach, nearest first, capped at [constant PING_RETURNS].
func _cast_ping() -> void:
	var found: Array = []
	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		var d := b.pos.distance_to(_cell.position) - b.radius
		if d >= ping_range:
			continue
		found.append([maxf(d, 0.0), b.pos])
	if found.is_empty():
		return
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var due := 0.0
	for i in mini(found.size(), PING_RETURNS):
		var d: float = found[i][0]
		var flight := d / PING_SPEED
		due = flight if i == 0 else maxf(flight, due + PING_MIN_GAP)
		_echoes.append([due, found[i][1],
			pow(clampf(1.0 - d / ping_range, 0.0, 1.0), PING_FALLOFF)])


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

## **The bodies themselves**, live, with nothing rebuilt. Every other accessor
## here copies out the one column it is asked for, which is right for a view
## that wants positions and wrong for anything that wants all of them at once:
## `genomes()` allocates a fresh array on every call, and the replay recorder
## reads six numbers off every body sixty times a second.
##
## Read it, and do not hold it across frames. docs/design/replay.md §4.6.
func bodies() -> Array[Body]:
	return _cells


## **Where a body was, written back from a recording.** The one thing in this
## file that is not simulation, and it is only reachable when the simulation has
## stopped for good: a run keeps nothing, so the replay scribbles the recorded
## state onto these bodies and lets `vision.gd` read them exactly as it does
## now, and `_wake_up()` builds all thirty-four again. §3.
##
## It deliberately writes only what the trace carries. Nothing here touches a
## state machine, a target, a serial or a clock -- a body being replayed is not
## deciding anything.
func restore_body(index: int, pos: Vector2, heading: float, radius: float,
		wound: float) -> void:
	if index < 0 or index >= _cells.size():
		return
	var b := _cells[index]
	b.pos = pos
	b.heading = heading
	b.radius = radius
	b.wound = wound


## The same, for the one part of a body that is not a float. Stepped at the
## moments the recording says it changed, never interpolated.
func restore_genome(index: int, genome: Dictionary) -> void:
	if index < 0 or index >= _cells.size():
		return
	_cells[index].genome = genome
	_cells[index].seeded = true


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


## How far through each body something has chewed, 0..1, index-matched to
## [method points]. Ground truth, like [method points]: point of view learns it
## by being bitten, and full vision draws the tears.
func wounds() -> PackedFloat32Array:
	if _wounds.size() != _cells.size():
		_wounds.resize(_cells.size())
	for i in _cells.size():
		_wounds[i] = _cells[i].wound
	return _wounds


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
	b.wound = 0.0
	b.bite = 0.0
	_serial += 1
	b.serial = _serial

	# **The floor is an invariant, not a probability.** A coin, however weighted,
	# lands zero drifters in the whole field some of the time. One counter fixes
	# it: if seeding this cell would leave no drifter in the field, it is a
	# drifter. "The world cannot degenerate" then stops being a statistical
	# claim -- there is always something edible at every radius and at every
	# cytostome tier, so there is always a way back from a bad run.
	#
	# **It has to hold at both ends of the sensory scale**, and it does, because
	# it is downstream of the share rather than part of it: the counter is the
	# same test whether the coin is 0.45 or 0.92.
	#
	# At setup this makes cell 0 a drifter, because nothing else is seeded yet,
	# and cell 0 is the authored first arrival. The opening is therefore always
	# something the player can eat, which is the right way round.
	if randf() < _drifter_share() or not _other_drifter(index):
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


## **The daughter you did not take, left in the water as an ordinary body.**
## lifecycle.md §4.2: she is your size, your mouth and your armour -- the one
## cell in the water that is an exact match for you -- and under edibility.md
## that is a fight decided by facing and nerve rather than by size. It costs one
## seeded body and no new system, and it answers "what happened to the other
## one" without a word.
##
## [param bearing] is body-relative, and it is the side she was drawn on, so she
## is where the player last saw her.
func put_sister(bearing: float, distance: float, body_radius: float,
		tiers: Dictionary) -> void:
	if _cell == null or _cells.size() < 2:
		return
	var index := 1
	# Seeded first, so every clock, counter and serial on that slot is reset by
	# the one function that knows what a fresh body is; then made the sister.
	_seed(index)
	var b := _cells[index]
	b.drifter = false
	b.radius = body_radius
	b.genome = tiers.duplicate()
	var dir := _cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)
	b.pos = _cell.position + dir * distance
	b.heading = _angle_of(dir, b.heading)
	b.aim = b.pos
	b.flee_from = b.pos
	# **The floor is an invariant and this just took a body out of the water.**
	# _seed() may have made that slot the only drifter in the field.
	if not _other_drifter(index):
		_seed_drifter(_cells[(index + 1) % _cells.size()])


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
	var total := 0.0
	for tier in TIER_WEIGHTS.size():
		total += _tier_weight(tier)
	var roll := randf() * maxf(total, 0.001)
	for tier in TIER_WEIGHTS.size():
		roll -= _tier_weight(tier)
		if roll <= 0.0:
			return tier
	return 1


# ---------------------------------------------------------------------------
# How much of the water can hurt you, as one readable function of what you can
# see. See the SENSE_GENES block: keyed on the player's own organs, never on
# which view is drawing them.
# ---------------------------------------------------------------------------

## **How much this cell can see coming**, 0 for blind and 1 for the water as
## shipped. The sum of the four sensing tiers over [constant SENSE_FULL], which
## is the least invented mapping available: every tier of every sense moves it,
## and none of them moves it in a step.
func _sensed() -> float:
	if _cell == null:
		return 1.0
	var tiers := 0.0
	for gene: StringName in SENSE_GENES:
		tiers += float(_cell.extra(gene))
	return clampf(tiers / SENSE_FULL, 0.0, 1.0)


## Share of arrivals that are drifters -- no cytostome, no bite, edible at every
## radius. A blind cell's water is nearly all of them.
func _drifter_share() -> float:
	return lerpf(BLIND_DRIFTER_SHARE, DRIFTER_SHARE, _sensed())


## How likely one cytostome tier is inside the peer band. The rare peer a blind
## cell meets carries the poorest mouth in the game.
func _tier_weight(tier: int) -> float:
	var i := clampi(tier, 0, TIER_WEIGHTS.size() - 1)
	return lerpf(BLIND_TIER_WEIGHTS[i], TIER_WEIGHTS[i], _sensed())


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
	var gape := _gape(b)
	if b.target == TARGET_PLAYER:
		return _worth_committing_to(b, gape, _cell.swallow_radius(), _cell.wound)
	var prey := _target_body(b)
	return prey != null \
		and _worth_committing_to(b, gape, prey.radius, prey.wound)


## Same convention as the cell: radians clockwise from world north, front is the
## top of the screen.
func _forward(heading: float) -> Vector2:
	return Vector2(sin(heading), -cos(heading))


func _angle_of(v: Vector2, fallback: float) -> float:
	if v.length_squared() <= 0.0:
		return fallback
	return atan2(v.x, -v.y)
