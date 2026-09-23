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
## concentration**, which sets the beat rate, its **taste level**, which sets
## the green band wash and carries no direction at all, and **dread**, a scalar
## with no bearing either. Everything else it learns by being hit.
##
## This node computes; it does not post. [member concentration],
## [member taste_level] and [member dread_level] are read once a frame by
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
## **The `ampulla` just fired.** Not a sensation and not for the membrane: a
## pulse in the water is an event in the world, and this is the only moment the
## field knows about it. The run listens so it can tell another player, which is
## the one thing in this game that reaches past the edge of this water. It
## carries nothing, because everything a listener needs -- where the cell is,
## how big it is, how far the organ carries -- the run already has.
##
## Emitted once per pulse, every `ping_period` seconds: 8.8 at tier 1, 15.2 at
## tier 3, never at tier 0. Nothing is connected to it in single player and an
## unconnected emit is free.
signal pulsed
## **Something happened to the other player, in this water** -- shared-pond.md
## §1.3. The same six things the shipped signals above say to this cell, said
## about the person in [constant PERSON_SLOT] instead: [param what] is a
## [enum Contact], [param at] is where the other body was (never a bearing --
## §0.2: the far device turns it into one with its own heading), [param level]
## is the strength or the nutrition, [param by] is a [enum By] and [param gene]
## is the meal's gene for `ATE`. Only a field with a pond open emits it, and
## nothing in the shipped run is connected to it yet (Phase 2's `pond.gd` sends
## it as CONTACT).
signal person_touched(what: int, at: Vector2, level: float, by: int, gene: StringName)
## **The other player died in this water**: swallowed, chewed apart, or
## poisoned by what it bit or swallowed -- a [enum Cause], by a [enum By], at
## the place it was. Emitted after [signal person_touched] has said `KILLED` and
## after the person has left [constant PERSON_SLOT], so a listener that puts
## them straight back finds the slot empty.
signal person_died(cause: int, by: int, at: Vector2)

const COUNT := 34

# --- The shared pond (shared-pond.md §1) ------------------------------------
# **None of this is reached in single player.** A pond is opened by
# [method open_pond] or [method become_mirror] and by nothing else, and every
# rule below that differs from the solo water is behind that; the identity gate
# (shared-pond.md §5) is what holds this file to it.

## **The other player's slot, on both devices**: the guest in the host's field,
## the host in the guest's mirror. After every water slot, so that a loop over
## `range(_water)` is a loop over the water and nothing else. §1.2.
const PERSON_SLOT := 2 * COUNT
## Every slot a pond has: two waters' worth of cells -- one for each of you, when
## you are apart -- and the person.
const POND_SLOTS := 2 * COUNT + 1
## How far past a snapshot the mirror carries anything, in seconds: the view's
## own `PEER_REACH`, for the same reason. A body carried further than this on
## an old heading is a guess, and the mirror holds rather than guesses.
const CARRY_MAX := 0.2
## **The send set** (§2): every body whose surface lies within this of the
## guest -- the reach of a tier-3 `ampulla`, measured to the surface exactly as
## [method _cast_ping] measures it. Scent, dread, beams and the frame all lie
## inside it, so nothing outside it can change a sense.
const SEND_REACH := 1900.0
## How many angles [method _seed_for] draws before it gives up looking for a
## point clear of every anchor and takes the one straight away from the other.
const SEED_TRIES := 8
## Genomes the mirror remembers by version before it forgets the oldest: four
## pond's worth, which is more than the send set can reference at once.
const BOOK_MAX := 4 * POND_SLOTS

## What happened to a person, on [signal person_touched] and into
## [method hear_contact]. The numbers are the wire's (shared-pond.md §2's
## CONTACT), so they are written out rather than left to count.
enum Contact { WAKED = 1, BITTEN = 2, STUNG = 3, DARTED = 4, ATE = 5, KILLED = 6 }
## How a person died, on [signal person_died]. `POISONED` is the venom in
## something it swallowed or bit, which §2's three-cause DIED did not name.
enum Cause { SWALLOWED = 1, CHEWED = 2, STARVED = 3, POISONED = 4 }
## Whose mouth it was.
enum By { WATER = 1, FRIEND = 2 }
## The two anchors a pond can have (§1.4): this device's own cell and the person.
enum Anchor { LOCAL = 0, PERSON = 1 }

## One body in a snapshot, as [method pond_entries] builds it and
## [method apply_pond] reads it: an Array indexed by these. `VELOCITY` and
## `TURNING` are the person's alone and read zero for a water cell.
enum Entry { SLOT, SERIAL, MEALS, FLAGS, AT, HEADING, RADIUS, WOUND, SPEED,
	VELOCITY, TURNING }
## [enum Entry] `FLAGS`, bit by bit -- the wire's POND flags (§2).
const FLAG_STALKING := 1
const FLAG_PERSON := 2
const FLAG_IN_WATER := 4

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
	&"statocyst": 2, &"palp": 2, &"myoneme": 2,
	&"trichocyst": 2, &"pellicle": 2, &"toxicyst": 2,
	&"plastid": 2, &"vacuole": 2, &"crista": 2,
}
## Everything a drifter can be, and therefore everything the player can ever
## eat their way into. The mouth is not on this list by construction.
##
## **`rhabdom` is not on it either, and that is a retirement rather than an
## omission.** It bought the taste lobe's width and its bearing jitter, and
## three-senses.md §2 took both away: there is no width left to sharpen and no
## bearing left to steady. Rather than re-aim it at the nose's floor -- a gene
## whose whole effect would be a number nobody can see move -- the owner
## retired it (§8 row 2, option C). This list and [constant GENE_WEIGHTS] are
## the two places a gene can be *produced*, so taking it out of both is the
## whole of the retirement; every table that *consumes* a gene name still
## answers for one it has never heard of, which is why an old `{gene: tier}`
## map that still names it loads and draws rather than crashing.
const DRIFTER_GENES: Array[StringName] = [
	&"cirrus", &"flagellum", &"stigma", &"chemocyte", &"ampulla",
	&"ocellus", &"axoneme", &"statocyst", &"palp", &"myoneme",
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
## Where one body on its own becomes worth smelling -- about twelve seconds of
## swimming. Named here because it is a property of the field, and the
## full-vision view draws it as a threshold ring.
##
## **It is one source's contribution, not the whole field**, and it never was
## the whole field: thirty-four bodies contribute, so the readout is lit long
## before any single one crosses this. Since `chemocyte` arrived a cell only
## reads what is inside its own nose's reach ([constant
## CellBody.SMELL_RANGE_BY_TIER]), which is a different and much larger radius.
##
## **The name is historical and the comment used to be wrong.** It said this was
## where "a direction first exists at all", which was already only half true and
## is now false in both halves: three-senses.md §2 took the direction out of
## smell entirely, and the bus's TASTE_FLOOR this was fitted against moved from
## 0.06 to 0.02 in the same change. The number is left where it is because what
## it does today is draw one ring in full vision and that ring is unchanged;
## renaming it would touch vision.gd and two design documents for no difference
## a player could see.
const BEARING_RANGE := 680.0

# --- What the nose does with that field (three-senses.md §2) ----------------
# The owner: *"smell is not a directional sensor. It should only say whether the
# smell is strong or not. Orientation should count. If the smell sensor is
# facing towards nothing, the smell is less than when faced towards food."*
#
# Two constants, and both were measured rather than picked. The first is how
# much orientation counts; the second is what stops the answer being a number
# with no gradient in it.

## What a receptor pointed dead away still picks up, as a fraction of what one
## pointed straight at a source does -- the floor under the cosine lobe in
## [method _step_sense].
##
## **0.22 and not lower, for one reason: the band must never go out.** At 0.22
## the dimmest facing in every instrumented sample stays above the bus's
## TASTE_FLOOR. At 0.10 a cell facing away from everything drops through the
## floor and the green band disappears, which reads as *the gene has stopped
## working* rather than as *you are facing the wrong way*. Dimming is
## information; darkness is a bug report. three-senses.md §2.3.
##
## Mirrored, deliberately, by signal_bus.gd's SMELL_RING_FLOOR -- that file
## draws this curve on the skin and may not preload this one. The comment there
## says what breaks if the two drift.
const SMELL_BEHIND := 0.22
## How much of everything-but-the-loudest reaches the readout, and it is
## **1.0: every source counts, in full**.
##
## Odour from several sources *adds*. Each body's plume is a diffusion field
## and the fields superpose, so the water at one point has one concentration in
## it and a nose reads that total -- it cannot pick a favourite source out of a
## mixture it never resolved in the first place. Any tail below 1.0 is the
## readout throwing away information a real nose has, and the two tails this
## file has shipped (0.00 and 0.22) were both doing exactly that.
##
## **What made the full sum unnavigable was never the sum. It was the clamp.**
## three-senses.md §7.5 measured a plain sum that ended in `minf(..., 1.0)`,
## found that 13-19 sources in reach pinned it at 1.0 for much of a run, and
## concluded that the sum had no gradient in it. The gradient was there; the
## clamp was eating it. A receptor does not clip -- it *saturates* -- and
## [constant SMELL_HALF] is the one line that changes, below.
##
## **Measured on the built code, 24 seeds, 90 s cap** (three-senses.md §7.5.2),
## `--radius=30 --genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1 --sniff`:
## the 0.22 tail behind a clamp fed 16 of 24 in a median 56.6 s; this pair
## feeds **19 of 24 in a median 39.8 s**. More seeds eat and they eat sooner,
## which is not the trade §7.5.1 expected to have to make.
const SMELL_TAIL := 1.0
## The concentration at which the nose is **half** saturated: the `K` in the
## Langmuir isotherm `s / (s + K)`, which is also the Hill equation at n = 1
## and the Michaelis-Menten curve receptor binding actually follows.
##
## This is the constant that replaces the clamp. `minf(s, 1.0)` is a cliff: at
## and above 1.0 the derivative is zero, so two positions with different
## amounts of food in front of them read identically and there is nothing to
## climb. `s / (s + K)` is monotonically increasing for every s >= 0 and never
## reaches 1, so **a gradient survives at any concentration** -- it only gets
## shallower, which is what a nose in thick water is actually like.
##
## **K is chosen for the readout, and no navigation measurement constrains it.**
## `s / (s + K)` is a monotonic transform of `s`, and `--sniff` only ever
## compares one sample against the next, so the bot flies a byte-identical path
## at any K -- measured at 0.5, 0.9, 1.2 and 2.0 over eight seeds: the same
## raw sum and the same port/starboard decision at every one of the 1,728
## samples, and the same meal on the same hundredth of a second. What K decides is the absolute
## brightness of the ring on the membrane, and only a player reads that.
## Anyone re-tuning this should not expect the bot to have an opinion.
##
## **So it was measured off the distribution of `s` instead.** 1,690 samples
## over 8 seeded 90-second forages at `--radius=30` with a tier-1 nose:
##
##     p10  0.388     p50  0.887     p90  1.659     max  3.498
##
## K = 0.9 is that median, so **typical water half-saturates the nose** -- the
## textbook meaning of a half-saturation constant, and here it is a measured
## number rather than a borrowed one. The middle 80% of the water then reads
## 0.301 to 0.648 and the richest instant ever seen reads 0.795: a third of a
## unit of swing on the ring, nothing crushed at the bottom and nothing pinned
## at the top. The band is stable across the ladder too -- a tier-2 nose reads
## 0.350 / 0.516 / 0.614 and a tier-3 one 0.386 / 0.498 / 0.645 -- so one K
## serves all three.
##
## three-senses.md §7.5.3 renders p10, median and p90 at both shapes.
const SMELL_HALF := 0.9

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
## How fast the pulse travels, in world units per second -- **out and back**.
## This is the whole reason the ping reads as a sweep rather than as a chord:
## the nearest body answers first and the farthest last, so one pulse arrives on
## the membrane as a series of separate marks walking outward in time.
##
## **Slowed five-fold at the owner's word**, from 1250. Untested by instruction
## -- the change is one number and the owner wanted it shipped rather than
## measured -- and then measured here, because the round trip doubled every
## consequence of it. A tier-1 return from the edge of reach lands **8.8 s**
## after the pulse left rather than 4.4, and ping-as-outline.md §7 is what that
## costs.
const PING_SPEED := 250.0
## How many bodies one pulse may answer for, nearest first, **by `ampulla`
## tier**. A cap rather than a rule: thirty-four bodies inside reach would be a
## strobe, and the far half of them would be inaudible under the near half
## anyway. Was a flat five; the ladder is ping-as-outline.md §4, and how many
## things one pulse can resolve at once is most of what a better organ is.
const PING_RETURNS_BY_TIER: Array[int] = [0, 3, 4, 5]
## **How much longer the organ rings than the echo takes to pass**, §3.2. The
## bare geometry is 1.0; 2.0 is what shipped, because 0.104 s against 0.320 s is
## a real ratio hiding inside two numbers that are both "a blink". Measured over
## 60 s of foraging, holds land between 0.21 and 0.70 s.
const PING_RING := 2.0
## **The organ's own beamwidth**, in degrees: the finest extent it can report,
## and the floor every reported extent sits on. Was `signal_bus.gd`'s
## `PING_HALFWIDTH_DEG`, which was the whole of what a mark's width said; it is
## now the bottom of a measurement rather than the measurement.
const PING_WIDTH_FLOOR: Array[float] = [0.0, 17.0, 13.0, 10.0]
## **How much of a body's true angular half-width reaches the readout**, on top
## of that floor. A magnification, and §3.3 is why one is needed: at seeding
## distance every body in this water subtends under three degrees, so a literal
## width would report every one of them as the same hairline.
const PING_WIDTH_GAIN: Array[float] = [0.0, 1.5, 3.5, 6.0]
## Past this a lobe has stopped being a bearing and become a mood.
const PING_WIDTH_MAX := 52.0
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
##
## **Raised from 0.17** with ping-as-outline.md §3.2: a mark now lives 0.36 to
## 0.80 s instead of 0.19, and the membrane holds two of them at once rather
## than one. Two arcs and a 0.30 gap is the pair that keeps a sweep a series.
const PING_MIN_GAP := 0.30
## **The soft edge on the hull's own shadow, as a cosine.** A point source
## sitting on the skin radiates into half the plane and the rest goes into the
## body -- which is why a submarine has baffles, and why clearing them is done
## by turning the boat. Turning is this game's only verb, so the geometry hands
## over a mechanic with a counter the player already owns and no new control.
##
## A hard hemisphere would be a boolean, and a body drifting across the tangent
## would pop a mark on and off; every gate in this file has been taken off
## exactly that argument (genes-and-cilia.md §7.0). A ray leaving a few degrees
## under the tangent really does graze the body and come back weak, so the
## shadow gets a 27-degree soft edge instead: `acos(0.24)` is 76.1 degrees, so
## the fade runs +-13.9 degrees either side of the hemisphere.
const PING_GRAZE := 0.24
## **A return below this is not worth one of the three-to-five slots.**
## [constant PING_RETURNS_BY_TIER] is applied *after* occlusion, so a return a
## shadow has silenced stands aside for a fainter one in the lit half rather
## than spending a slot on nothing. That is the whole of the compensation, and
## it is enough because the cap was already discarding more than the shadow
## does.
const PING_SILENT := 0.03

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
	##
	## **In a pond it is also what "in this water" means.** A retired slot is
	## unseeded, and so is the person's slot while that player is out of the
	## water or has no body -- which is how every sense, every mouth and every
	## push skips them without a second test in any loop.
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

	# --- Pond only (shared-pond.md §1.2). Nothing in single player reads these.
	## The other player's record when this body is them, and null for every
	## cell the water made. The one test for "is this a person".
	var person: Person = null
	## How fast it is swimming along [member heading], written where bodies
	## move. What the mirror carries a body forward by between two snapshots.
	var speed := 0.0
	## The worn order, slot by slot, for a body whose arcs matter to the view --
	## the person's. Empty for a water cell, which is drawn in default order.
	var order: Array = []
	## Which player's water this cell was made for, as an [enum Anchor]; -1 for
	## a cell seeded before any pond, which is the local player's.
	var tuned := -1


## **What a body lacks, for the body that is another player** (§1.2): how it
## is moving, what its organs buy, and the three clocks the encounter keeps for
## it. The host keeps one for the guest; the guest's mirror keeps one for the
## host, and reads only its motion and whether it is in the water.
##
## Everything here is derived from what that player reports -- a pose from
## [method place_person] and a genome from [method set_person_genome] -- with
## the same arithmetic the local cell's own nodes use, so a person is chased,
## led, bitten and darted exactly as the player on this device is.
class Person:
	## The last reported place, heading and velocity, and how long ago.
	var at := Vector2.ZERO
	var facing := 0.0
	var launch := Vector2.ZERO
	var turning := 0.0
	var age := 0.0
	## Where that velocity has decayed to by now, under the water's own drag.
	var velocity := Vector2.ZERO
	## [method CellBody.swim_speed_of] for its `flagellum` and `axoneme`.
	var swim_speed := 0.0
	## Its body as a mouth measures it: `pellicle`'s multiple on its radius.
	var armour := 1.0
	## `trichocyst`: reach, cooldown and the arc the organ is worn on.
	var dart_range := 0.0
	var dart_cooldown := 0.0
	var dart_bearing := 0.0
	var dart_clock := 0.0
	## `toxicyst`, as the field's own `venom_cost` for this cell: negative is
	## no venom.
	var venom_cost := -1.0
	## Its own [constant FIRST_DELAY], granted at every arrival.
	var first_hunt := 0.0
	## Out of the water is a player dividing: still an anchor, and nothing in
	## the water can see it, touch it or chase it.
	var in_water := true
	## Their phone has gone quiet. Nothing in the field reads it -- a quiet
	## body still drifts, bites and can be eaten (§1.8) -- it is kept for the
	## view, which fades their presence.
	var quiet := false


## Total scent concentration at the cell, 0..1. The other half of metabolism's
## beat mapping, and the reason the outer kilometre is hot-and-cold with no
## direction in it.
var concentration := 0.0
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
## by the run. 0 is a cell with no nose, and a cell with no nose smells nothing
## edible at all.
var smell_range := 0.0
## **Where the nose is on the membrane**, as a body-relative bearing, written
## once a frame by the run exactly as [member ping_bearing] and [member
## dart_bearing] are.
##
## Smell has no direction of its own any more (three-senses.md §2). What the
## organ reports is a level, and how nearly a source lies along *this* arc is
## the whole of how much of that source reaches the level. So the slot the gene
## is worn in is the direction the player has to point to smell, and turning --
## the one verb this game has -- is how they sweep for it.
var smell_bearing := 0.0
## **What the scent field is worth to this particular nose**, 0..1: every
## source inside [member smell_range] weighted by facing and added up, then put
## through the receptor's own saturation curve, `s / (s + `[constant
## SMELL_HALF]`)`.
##
## **It approaches 1 and never arrives.** The old clamp could sit exactly at
## 1.0 for half a run; this cannot reach it at any concentration, which is the
## whole reason the gradient is still there to follow.
##
## Two numbers rather than one, and the split is the point. [member
## concentration] is what the *water* is like, and it drives the metabolic beat,
## which is a property of the body and not of its senses -- an eyeless, noseless
## cell still beats faster in rich water. This is what the *organ* picks up, and
## it is the only one of the two that reaches the membrane.
##
## **Nothing else leaves the nose.** There is no taste bearing any more: the
## organ answers *how strong*, and the player answers *which way* by turning.
var taste_level := 0.0
## `ampulla`. How far a pulse carries and how often one goes out, written once a
## frame by the run. Either at 0 is a cell with no electroreceptor.
var ping_range := 0.0
var ping_period := 0.0
## **Where the organ is on the membrane**, as a body-relative bearing, written
## once a frame by the run exactly as [member dart_bearing] is. The pulse leaves
## the skin at that arc rather than from the middle of the cell, so the slot the
## gene is worn in decides which half of the water your own body hides -- and
## the only way to see behind you is to turn.
var ping_bearing := 0.0
## How much of the pulse survives one body in the way, including your own:
## [constant CellBody.PING_THROUGH_BY_TIER] for the tier this cell wears. 0 is a
## body nothing gets past.
var ping_through := 0.0
## The `ampulla` tier, written once a frame by the run beside the three above.
## It decides how many bodies one pulse answers for and how much of a body's
## true angular extent survives into the readout. ping-as-outline.md §4.
var ping_tier := 0
## Returns that became due **this frame**: `[bearing, strength, halfwidth_deg,
## hold]`, loudest first. Strength is 1 against the skin and 0 at the edge of
## reach; `halfwidth_deg` is how wide the organ reports the body (§3.3) and
## `hold` is how long the echo takes to pass (§3.2). Drained by the run, which
## is the only thing allowed to post them.
##
## **Four scalars, and not one of them is a place.** The half-width conflates
## size with distance on purpose, exactly as an ear does; you cannot recover a
## position from the four of them. Bodies, not meals: a ping answers off
## anything with a body in it, which is exactly what the scent field can never
## do.
var pings: Array = []
## **Every outgoing wavefront still inside reach**, as radii from the organ,
## oldest first. Ground truth for the two views, which draw the sweep; the
## organism only ever gets [member pings].
##
## An array and not a scalar, and that is ping-as-outline.md §7 being fixed
## rather than photographed. The slow wave puts up to eleven pulses in the water
## at once at tier 3, and one `ping_front` drew the newest while the membrane
## was still reporting the oldest -- one frame saying *the wave has just left*
## over a skin saying *something is out there*.
var ping_fronts: Array = []
## **Every echo on its way home**, as `[radius, bearing, halfwidth_deg, level]`,
## nearest first. The radius is how far the echo still has to travel, so it
## collapses onto the organ at the instant the matching entry appears in
## [member pings] -- the wave coming back is the same event the skin reports.
##
## Recomputed every frame from the stored world position, so an echo that is
## eight seconds out still arrives on the bearing the body is on *now* rather
## than the one it was on when the pulse left.
var ping_echoes: Array = []
## **How much of the newest pulse's round trip is still to come**, 1 at the
## instant it leaves and 0 when it can no longer be answering. The organ's own
## arc hums at this while it listens (§6.2); it is a level and a bearing like
## everything else that reaches the membrane.
var ping_listen := 0.0
## `[seconds until due, world position, strength, halfwidth_deg, hold]` for
## returns still in flight. The position stops here: [method _step_pings] turns
## it into a bearing at the moment the return lands, exactly as [method
## _step_touch] does -- and into a bearing every frame for the drawn echo, which
## is the same conversion done twice and never handed on.
var _echoes: Array = []
## Ages of the outgoing fronts still inside reach, oldest first.
var _pulses: Array = []
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

# --- The shared pond (shared-pond.md §1). Untouched in single player. --------

## **Is this device's own cell in the water.** False while it is dead or
## dividing, in a pond (§1.5): the water goes on, and it skips this cell's
## contacts, its half of the pushing, every chase of it and its four organs, so
## a dead or dividing cell never pings or shouts. Always true in single player,
## where a death or a division stops this node instead.
var in_water := true
## **Does this device's own cell have a body at all** -- an anchor of the pond
## (§1.4). A dividing player still does, so what a daughter comes back to is
## still there; a dead one does not. The field clears both of these itself when
## it kills this cell in a pond; the run owns every other change.
var anchored := true
var _pond := false
## A mirror simulates nothing but its own cell's senses: the host's water
## arrives by [method apply_pond] and every contact by [method hear_contact].
var _mirror := false
## How many slots are water: every slot in single player, and all but the
## person's in a pond. Every loop over the water runs `range(_water)`.
var _water := COUNT
## **Bumped by everything that changes a radius** -- a seed, a retirement, a
## meal, a placement. The contact pass reads it to know its bound has gone
## stale; see [method _contacts_water].
var _changes := 0
## When each [enum Anchor] was last seeded for, against [member _stamp]; the
## oldest wins a tie for the next cell (§1.4, the owner's row 2: turns).
var _seeded_for := PackedInt64Array([0, 0])
var _stamp := 0
## The anchors of this frame, rebuilt by [method _find_anchors]: which, and
## where.
var _anchor_ids := PackedInt32Array()
var _anchor_at := PackedVector2Array()
## The mirror's last snapshot: where each slot was, and how long ago.
var _snap_at := PackedVector2Array()
var _snap_age := 0.0
## The mirror's genomes by body version, `serial * 1000 + meals` -- the
## recorder's own signature -- so one can arrive before or after its body.
var _book := {}


## Seeds the water around [param cell]. Cell 0 is held back until the cell is
## actually moving, for the same reason mote 0 is.
##
## **Always a single-player water**, whatever came before: a pond or a mirror
## is closed by this, which is what [method leave_mirror] is.
func setup(cell: CellBody) -> void:
	_cell = cell
	_pond = false
	_mirror = false
	_water = COUNT
	in_water = true
	anchored = true
	_snap_at = PackedVector2Array()
	_snap_age = 0.0
	_book.clear()
	_cells.clear()
	for i in COUNT:
		_cells.append(Body.new())
	_opening = true
	for i in COUNT:
		_seed(i)
	_opening = false
	_first_pending = true
	_first_hunt = FIRST_DELAY
	_fresh_senses()


## Every sense and every organ clock back to a new water's: what [method setup]
## has always done after the seeding, and what a mirror does on its first frame.
func _fresh_senses() -> void:
	concentration = 0.0
	dread_level = 0.0
	threat = 0.0
	beams.clear()
	touch_level = 0.0
	taste_level = 0.0
	pings.clear()
	_echoes.clear()
	_pulses.clear()
	_ping_clock = 0.0
	_ping_age = -1.0
	ping_fronts.clear()
	ping_echoes.clear()
	ping_listen = 0.0
	_dart_clock = 0.0
	_bite_clock = 0.0


func _process(delta: float) -> void:
	if _cell == null:
		return
	if _mirror:
		_step_mirror(delta)
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
	# The person first, so that every chase this frame leads the place they are
	# now -- as the local cell has already moved by the time this node runs.
	if _pond:
		_step_person(delta)
	for i in _water:
		_step_body(i, delta)
	# In a pond the water is kept at the end of the frame instead, where the
	# slots its meals emptied are filled again (§1.4).
	if not _pond:
		_step_recycle()
	# Contact first, then separation: a body is eaten or bitten on the frame it
	# arrives in a mouth, and only then pushed back out of the one it is in.
	# The other order would make the mouth chase a body it has just shoved away.
	if not _step_contacts():
		return
	_step_separate()
	if _pond:
		_step_pond()
	if in_water:
		_step_organs(delta)


## The four organs, in the order they have always run. The mirror runs exactly
## these over the water it was sent.
func _step_organs(delta: float) -> void:
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
	# A retired slot is nobody (§1.4). Asked only in a pond, where slots retire:
	# the solo water has none, and asks nothing new of any body.
	if _pond and not b.seeded:
		return
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
	b.speed = DRIFT_SPEED
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
	#
	# In a pond a player out of the water is nobody's prey (§1.5).
	if in_water and _first_hunt <= 0.0 and _worth_committing_to(b, gape,
			_cell.swallow_radius(), _cell.wound):
		var d := b.pos.distance_to(_cell.position)
		if d <= maxf(reach, b.radius + _cell.radius):
			best = TARGET_PLAYER
			best_d = d

	for j in _cells.size():
		if j == index:
			continue
		var other := _cells[j]
		if not other.seeded:
			continue
		# **Distance before appetite**, and it is the same test in a cheaper
		# order: both halves are pure, so asking the one that rejects most pairs
		# first changes which calls are made and never which body wins. Written
		# as the negation of the acceptance it replaces, so even a NaN is
		# refused exactly where it always was. shared-pond.md §3, Phase 0.
		var d := b.pos.distance_to(other.pos)
		if not (d <= maxf(reach, b.radius + other.radius) and d < best_d):
			continue
		# **The other player is asked what the player on this device is asked**
		# (§1.2): nothing before their own first-hunt grace, and a mouth is
		# measured against their armoured radius. Nearest still wins, and the
		# local cell, tested first, keeps an exact tie.
		if other.person != null:
			if other.person.first_hunt > 0.0 or not _worth_committing_to(b, gape,
					other.radius * other.person.armour, other.wound):
				continue
		elif not _worth_committing_to(b, gape, other.radius, other.wound):
			continue
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
	# only ever felt from a cell that is hunting *you* -- or, in a pond, the
	# other player, who feels it on their own device.
	if b.target == TARGET_PLAYER:
		_felt_hunting(b, d, delta, null)
		return
	var hunted := _hunted_person(b)
	if hunted != null:
		_felt_hunting(b, d, delta, hunted)


## **What a hunt does to the player it is aimed at**: the dart, and the wake.
## One rule with two callers (shared-pond.md §1.2) -- [param p] null is the
## cell on this device, told through the shipped signals; a person is told the
## same things through [signal person_touched], with their own organ, their
## own arc and their own clock.
func _felt_hunting(b: Body, d: float, delta: float, p: Person) -> void:
	# **`trichocyst`. It came inside dart range, on the arc the organ is on, and
	# it is leaving.** Automatic rather than a button: the design has no second
	# control to spend and the whole of the gene is the cooldown -- one run
	# broken off, then a long wait, so it buys an escape and never safety.
	#
	# **The arc is the point, and it is the one fix §2 calls required.** A dart
	# that fired at whatever was near was a defence with no position, on a rule
	# that is now entirely about position. The same wiring the `ocellus` already
	# has: the slot is the arc, the arc is the bearing, and the run posts it.
	var reach := dart_range if p == null else p.dart_range
	var clock := _dart_clock if p == null else p.dart_clock
	if reach > 0.0 and d < reach and clock <= 0.0:
		var facing := dart_bearing if p == null else p.dart_bearing
		var off := absf(angle_difference(facing, _bearing_for(p, b.pos)))
		if off <= deg_to_rad(CellBody.DART_ARC_DEG) * 0.5:
			if p == null:
				_dart_clock = dart_cooldown
			else:
				p.dart_clock = p.dart_cooldown
			_tell(p, Contact.DARTED, b.pos, 0.0, By.WATER, &"")
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
		_tell(p, Contact.WAKED, b.pos, push, By.WATER, &"")


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
		# The other player is led exactly as this one is (shared-pond.md §1.2):
		# the same closed form, fed their pose, their motion and their speed.
		if prey.person != null:
			return _lead(prey.pos, _forward(prey.heading), prey.person.velocity,
				prey.person.swim_speed, prey.radius, t)
		var speed := DRIFT_SPEED if prey.state == State.DRIFT else _cruise_speed(prey)
		var ahead := _forward(prey.heading)
		return prey.pos + ahead * (speed * t - prey.radius * AIM_STERN_SHARE)
	return _lead(_cell.position, _cell.forward(), _cell.velocity,
		_cell.swim_speed(), _cell.radius, t)


## **Where a player will be in [param t] seconds**: the two-term closed form
## [method _predict] documents, for a body at [param at] facing [param forward]
## with [param velocity] now and [param speed] its realised average. One
## definition, called for the player on this device and for the person.
static func _lead(at: Vector2, forward: Vector2, velocity: Vector2, speed: float,
		body_radius: float, t: float) -> Vector2:
	var cruise := forward * speed
	var k := maxf(CellBody.DRAG, 0.001)
	return at + cruise * t \
		+ (velocity - cruise) * ((1.0 - exp(-k * t)) / k) \
		- forward * (body_radius * AIM_STERN_SHARE)


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
	b.speed = speed


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
##
## **In a pond the frame goes on** (shared-pond.md §1.5): the water does not stop
## for one player's death, so this cell leaves the water instead -- nothing below
## touches it again, because everything that would is asked `in_water` first --
## and the other player, the cells and the pushing all still happen.
func _step_contacts() -> bool:
	if in_water and _contacts_with(null):
		if not _pond:
			return false
		_lose_local()
	if _pond:
		_contacts_person()
	_contacts_water()
	return true


## **A player's mouth, and the water's mouths, on each other** -- one rule with
## two callers (shared-pond.md §1.3). [param p] null is the cell on this device,
## told through the shipped signals; a person is the other player in
## [constant PERSON_SLOT], told through [signal person_touched]. Returns true
## when that player has just died here.
##
## For the local cell this is the shipped pass, in the shipped order, with the
## water's own kind of pre-check in front of it. Its place and its radius are
## read afresh for every body, and that is load-bearing: `eaten` is handled by
## the run before the next body is looked at, and the run grows the cell, so the
## next contact meets the bigger body -- while `my_gape` stays the one it had
## when the pass began, exactly as it always has.
func _contacts_with(p: Person) -> bool:
	var pb: Body = null if p == null else _cells[PERSON_SLOT]
	var my_gape := _cell.gape() if p == null else _gape(pb)
	# **The pre-check, and it skips only bodies the full test rejects** -- the
	# water's own kind, below, asked of a player. Neither mouth can be on the
	# other from farther than its own bow, teeth and the other body: this one's
	# against the widest body in the water, and the widest body's, at the widest
	# gape any tier opens, against this one. Worked out again whenever the
	# player grows (a meal the run hands it mid-pass) or anything in the water
	# changes a radius, which is the same structural guard the water's pass has.
	var widest := _widest()
	var made_at := _changes
	var made_for := NAN
	var near := 0.0
	for i in _water:
		var b := _cells[i]
		if not b.seeded:
			continue
		# A listener may not take the other player out of the water mid-pass,
		# and if one ever does, the pass stops touching them.
		if p != null and (pb.person != p or not pb.seeded):
			return false
		var at := _cell.position if p == null else pb.pos
		var r := _cell.radius if p == null else pb.radius
		if _changes != made_at:
			made_at = _changes
			widest = _widest()
			made_for = NAN
		# Not `!=`: a NaN radius is never equal to itself, so it is worked out
		# every time, and its NaN bound skips nothing.
		if not (r == made_for):
			made_for = r
			near = _player_bound(r, my_gape, widest)
		if b.pos.distance_squared_to(at) > near:
			continue
		# **The whole of the fix, and it is two lines.** Its mouth on me, and my
		# mouth on it, measured against the bow each of us is drawn with. Both
		# can be false while the two bodies are overlapping -- that is two cells
		# barging each other, and it is now a thing that can happen.
		var its_mouth := _mouth_reaches(b, _gape(b), at, r)
		var my_mouth := Cilia.mouth_touches(at,
			_cell.heading if p == null else pb.heading, r, my_gape, b.pos, b.radius)
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
		#
		# **Kept for both players until the gene phase** (shared-pond.md §6 row
		# 3): a water cell swallows either of you only from a run at that one.
		if its_mouth and b.state == State.STALK and _hunts(b, p) \
				and _armoured(p) < _gape(b):
			# **`toxicyst`. It got you and it dies of it.** The one thing in the
			# game that undoes a death, and it is not free: the run pays for it
			# in hunger, which is the channel every other cost is paid in. The
			# body that swallowed you is reseeded, or retired in a pond -- it is
			# gone, not fleeing.
			if (venom_cost if p == null else p.venom_cost) >= 0.0:
				_tell(p, Contact.STUNG, b.pos, 0.0, By.WATER, &"")
				_consume(i)
				continue
			_tell(p, Contact.KILLED, b.pos, 0.0, By.WATER, &"")
			_break_off(b)
			if p != null:
				_person_gone(Cause.SWALLOWED, By.WATER)
			return true
		if my_mouth and b.radius < my_gape:
			# Emit where it was before recycling it, so a listener never has to
			# work out which one this was -- the mistake motes.gd documents.
			# Nutrition is against the eater's own radius, whoever that is.
			_tell(p, Contact.ATE, b.pos, _meal_value_for(b.radius, r), By.WATER,
				Genome.dominant_of(b.genome))
			_consume(i)
			continue
		# Not swallowed, either way round. What used to be a standoff with
		# nothing in it is now two mouths doing what mouths do.
		var serial := b.serial
		if its_mouth and _bitten_by(i, b, p):
			return true
		# Its own venom may have just taken that body out of the water, and
		# then this slot is a different cell somewhere else entirely. The
		# player's mouth was measured against the one that has gone.
		if my_mouth and b.serial == serial and _bite_from(i, b, p):
			return true
	return false


## **The other player, in this water**: against the cells, then against the
## cell on this device. Host only; the mirror's contacts are the host's, heard.
func _contacts_person() -> void:
	var pb := _cells[PERSON_SLOT]
	var p := pb.person
	if p == null or not pb.seeded:
		return
	if _contacts_with(p):
		return
	if in_water and pb.person == p and pb.seeded:
		_players_meet(p)


## **The water's mouths on each other.** Nothing here is a player: the person
## is never a mouth in this pass and never food for one -- a water cell's mouth
## on either player is [method _contacts_with], where the commitment is asked.
##
## **The pre-check, and it skips only pairs the full test rejects.**
## [method Cilia.mouth_touches] already refuses anything farther than its own
## bound -- the bow's reach, the teeth and the other body's radius -- but it is
## two calls deep to find that out, for every pair in the water. Here the same
## bound is taken once per mouth against the widest body there is, with a tenth
## of a percent on top so rounding cannot put a pair on the wrong side of it,
## and compared squared. A pair outside it is outside the real one too, so the
## answer never changes; only the calls that could not have said yes are gone.
## shared-pond.md §3, Phase 0.
##
## **The bound cannot go stale, and that is structural rather than careful.**
## Everything that changes a radius -- a seed, a retirement, a meal -- bumps
## [member _changes], and after every contact this pass compares it with the
## count its bound was made at; if anything moved, the widest body is found
## again by a whole scan and the bound rebuilt from it before the next pair is
## looked at. A contact is rare and the scan is 34 to 69 bodies, so this costs
## nothing -- and a rule added to [method _mouth_on] tomorrow cannot leave a
## smaller bound behind it, because it cannot change a radius without saying so.
func _contacts_water() -> void:
	var widest := _widest()
	for i in _water:
		var b := _cells[i]
		if not b.seeded or b.drifter:
			continue
		var gape := _gape(b)
		var near := _mouth_bound(b.radius, gape, widest)
		var made_at := _changes
		for j in _water:
			if j == i:
				continue
			var other := _cells[j]
			if not other.seeded:
				continue
			if b.pos.distance_squared_to(other.pos) > near:
				continue
			if not _mouth_reaches(b, gape, other.pos, other.radius):
				continue
			var done := _mouth_on(i, b, j, other, gape)
			if _changes != made_at:
				made_at = _changes
				widest = _widest()
				near = _mouth_bound(b.radius, gape, widest)
			if done:
				break


## One water mouth closed on another body, [param gape] being the gape the pass
## measured it with. Returns true when this mouth is finished for the frame.
##
## **Change a radius here only through a function that bumps [member _changes]**
## -- [method _devour], [method _consume], [method _seed], [method _retire] --
## never by writing `radius` directly. That is the one precondition of the
## pass's structural bound: a raw write would leave it too small, and it would
## skip real contacts without a sound.
func _mouth_on(i: int, b: Body, j: int, other: Body, gape: float) -> bool:
	if other.radius >= gape:
		# Too big to swallow, so it gets chewed instead. Same clock, same table
		# and same two defending genes as the player's.
		if _chew(b, other) >= 1.0:
			_devour(b, other)
			_consume(j)
		if b.wound >= 1.0:
			# Its own venom finished the biter. Nothing feeds on that.
			_consume(i)
			return true
		return false
	_devour(b, other)
	_consume(j)
	# It has just eaten, so the run is over -- ended here, as a meal, rather
	# than left to unravel as a broken-off chase against a slot that has since
	# been recycled into somebody else. That route took it through BREAK, which
	# fled the prey that was no longer there, which used to resolve to the
	# player: every cell-against-cell meal ejected a newly grown, newly
	# dangerous cell out past the dread radius. It stays where it is, bigger,
	# and it is the player's problem now. §1.2.
	b.state = State.DRIFT
	b.target = TARGET_NONE
	b.target_serial = 0
	b.stale = 0.0
	b.calm = randf_range(CALM_MIN, CALM_MAX)
	return true  # One meal per cell per frame. It has to swallow.


## **A body the water has lost** -- eaten, or poisoned by what it bit. In single
## player it is reseeded in place, as it always has been; in a pond it is
## retired, and the end of the frame decides whose water the next one is
## (shared-pond.md §1.4).
func _consume(index: int) -> void:
	if _pond:
		_retire(index)
	else:
		_seed(index)


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


## **Something has its mouth on a player and cannot swallow them.** Returns true
## when that bite was the one that finished them, on the same contract as the
## kill above: the caller stops touching that player immediately. One rule with
## two callers (shared-pond.md §1.3); [param p] null is the cell on this device.
func _bitten_by(index: int, b: Body, p: Person = null) -> bool:
	if b.bite > 0.0:
		return false
	var pb: Body = null if p == null else _cells[PERSON_SLOT]
	# Where the mouth was when it closed: every event below is told from here,
	# even after the venom has taken that body somewhere else.
	var at := b.pos
	# Measured at the player, who is the target here: the bearing the mouth is
	# on *is* theta, because a body-relative bearing is already the angle from
	# its own heading. A mouth astern is the 2.10. For the person the same
	# angle is worked out the way the water measures every other body.
	var theta := absf(_cell.bearing_to(at)) if p == null \
		else _flank_theta(pb.heading, pb.pos, at)
	var damage := CellBody.bite_damage(Genome.tier_of(b.genome, &"cytostome"),
		_gape(b), _cell.radius if p == null else pb.radius,
		_cell.extra(&"pellicle") if p == null else Genome.tier_of(pb.genome, &"pellicle"),
		theta)
	if damage <= 0.0:
		return false
	b.bite = CellBody.BITE_GAP
	var hurt := 0.0
	if p == null:
		_cell.wound = clampf(_cell.wound + damage, 0.0, 1.0)
		hurt = _cell.wound
	else:
		pb.wound = clampf(pb.wound + damage, 0.0, 1.0)
		hurt = pb.wound
	if hurt >= 1.0:
		# Chewed through rather than swallowed, and it ends the same way. The
		# player has felt every one of the bites that got here, at this bearing.
		_tell(p, Contact.KILLED, at, 0.0, By.WATER, &"")
		if b.state == State.STALK:
			_break_off(b)
		if p != null:
			_person_gone(Cause.CHEWED, By.WATER)
		return true
	# `toxicyst` from the other end: biting a venomous body costs the mouth a
	# share of what it just did, and enough of them kill it.
	b.wound = clampf(b.wound + CellBody.venom_back(
		_cell.extra(&"toxicyst") if p == null else Genome.tier_of(pb.genome, &"toxicyst"),
		damage), 0.0, 1.0)
	if b.wound >= 1.0:
		_consume(index)
	_tell(p, Contact.BITTEN, at, _felt(damage), By.WATER, &"")
	return false


## **A player's own mouth on a body too big to swallow.** The option the player
## never had: whittle it down and it comes apart, and then it is a meal on
## exactly the terms a swallowed one is. Returns true when the venom in it
## finished them. One rule with two callers, [param p] null being this device's
## cell -- and its order is the one every contact in a pond keeps: the eater's
## death before the meal (shared-pond.md §1.3).
func _bite_from(index: int, b: Body, p: Person = null) -> bool:
	var pb: Body = null if p == null else _cells[PERSON_SLOT]
	if (_bite_clock if p == null else pb.bite) > 0.0:
		return false
	# Measured at the body being chewed: its own heading against the direction
	# this mouth arrived from. Holding your nose on a cell's stern is worth 2.10
	# times holding it on its nose, and that is the owner's sentence made true.
	var damage := CellBody.bite_damage(
		_cell.tier(&"cytostome") if p == null else Genome.tier_of(pb.genome, &"cytostome"),
		_cell.gape() if p == null else _gape(pb),
		b.radius, Genome.tier_of(b.genome, &"pellicle"),
		_flank_theta(b.heading, b.pos, _cell.position if p == null else pb.pos))
	if damage <= 0.0:
		return false
	if p == null:
		_bite_clock = CellBody.BITE_GAP
	else:
		pb.bite = CellBody.BITE_GAP
	var at := b.pos
	b.wound = clampf(b.wound + damage, 0.0, 1.0)
	var back := CellBody.venom_back(Genome.tier_of(b.genome, &"toxicyst"), damage)
	var hurt := 0.0
	if p == null:
		_cell.wound = clampf(_cell.wound + back, 0.0, 1.0)
		hurt = _cell.wound
	else:
		pb.wound = clampf(pb.wound + back, 0.0, 1.0)
		hurt = pb.wound
	# The death is checked before the meal, and in that order on purpose:
	# `eaten` is not idempotent and feeding a corpse would be silent.
	if hurt >= 1.0:
		_tell(p, Contact.KILLED, at, 0.0, By.WATER, &"")
		if p != null:
			_person_gone(Cause.POISONED, By.WATER)
		return true
	if b.wound >= 1.0:
		_tell(p, Contact.ATE, at,
			_meal_value_for(b.radius, _cell.radius if p == null else pb.radius),
			By.WATER, Genome.dominant_of(b.genome))
		_consume(index)
	_tell(p, Contact.BITTEN, at,
		maxf(_felt(damage) * BITE_FELT_SHARE, _felt(back)), By.WATER, &"")
	return false


# ---------------------------------------------------------------------------
# One player's mouth on the other (shared-pond.md §1.3, the last row).
#
# **Today's rule, without the commitment**: a human's mouth on you is the
# commitment, and the only warning you get is the dread their gape raises.
# Resolved on the host, from its own cell's side, exactly as a water cell's
# contact with that cell is -- with the person in the water cell's place:
#
#   their mouth on me and I fit it (armoured) -> I am swallowed, or they are
#                                                poisoned by my venom
#   my mouth on them and they fit (armoured)  -> they are, or I am
#   otherwise                                 -> each mouth chews, in its own
#                                                direction's order
#
# So a pair that could each swallow the other is decided the way the shipped
# pass decides a water cell against this cell: the other mouth is asked first.
# ---------------------------------------------------------------------------

func _players_meet(p: Person) -> void:
	var pb := _cells[PERSON_SLOT]
	var their_gape := _gape(pb)
	var my_gape := _cell.gape()
	var their_mouth := Cilia.mouth_touches(pb.pos, pb.heading, pb.radius,
		their_gape, _cell.position, _cell.radius)
	var my_mouth := Cilia.mouth_touches(_cell.position, _cell.heading,
		_cell.radius, my_gape, pb.pos, pb.radius)
	if not (their_mouth or my_mouth):
		return
	var here := _cell.position
	var there := pb.pos
	if their_mouth and _cell.swallow_radius() < their_gape:
		if venom_cost >= 0.0:
			# Spat out starving, and they die of it.
			hear_contact(Contact.STUNG, there, 0.0, By.FRIEND)
			_tell(p, Contact.KILLED, here, 0.0, By.FRIEND, &"")
			_person_gone(Cause.POISONED, By.FRIEND)
			return
		hear_contact(Contact.KILLED, there, 0.0, By.FRIEND)
		_tell(p, Contact.ATE, here, _meal_value_for(_cell.radius, pb.radius),
			By.FRIEND, _local_dominant())
		_lose_local()
		return
	if my_mouth and pb.radius * p.armour < my_gape:
		if p.venom_cost >= 0.0:
			_tell(p, Contact.STUNG, here, 0.0, By.FRIEND, &"")
			hear_contact(Contact.KILLED, there, 0.0, By.FRIEND)
			_lose_local()
			return
		hear_contact(Contact.ATE, there, _meal_value_for(pb.radius, _cell.radius),
			By.FRIEND, Genome.dominant_of(pb.genome))
		_tell(p, Contact.KILLED, here, 0.0, By.FRIEND, &"")
		_person_gone(Cause.SWALLOWED, By.FRIEND)
		return
	if their_mouth and _chewed_by_friend(p):
		return
	if my_mouth and pb.person == p and pb.seeded:
		_chew_friend(p)


## Their mouth on this cell, and it cannot swallow it: [method _bitten_by]'s
## order, the victim's death first. Returns true when this cell died.
func _chewed_by_friend(p: Person) -> bool:
	var pb := _cells[PERSON_SLOT]
	if pb.bite > 0.0:
		return false
	var there := pb.pos
	var here := _cell.position
	var damage := CellBody.bite_damage(Genome.tier_of(pb.genome, &"cytostome"),
		_gape(pb), _cell.radius, _cell.extra(&"pellicle"),
		absf(_cell.bearing_to(there)))
	if damage <= 0.0:
		return false
	pb.bite = CellBody.BITE_GAP
	_cell.wound = clampf(_cell.wound + damage, 0.0, 1.0)
	if _cell.wound >= 1.0:
		hear_contact(Contact.KILLED, there, 0.0, By.FRIEND)
		_tell(p, Contact.ATE, here, _meal_value_for(_cell.radius, pb.radius),
			By.FRIEND, _local_dominant())
		_lose_local()
		return true
	var back := CellBody.venom_back(_cell.extra(&"toxicyst"), damage)
	pb.wound = clampf(pb.wound + back, 0.0, 1.0)
	hear_contact(Contact.BITTEN, there, _felt(damage), By.FRIEND)
	if pb.wound >= 1.0:
		_tell(p, Contact.KILLED, here, 0.0, By.FRIEND, &"")
		_person_gone(Cause.POISONED, By.FRIEND)
		return false
	_tell(p, Contact.BITTEN, here,
		maxf(_felt(damage) * BITE_FELT_SHARE, _felt(back)), By.FRIEND, &"")
	return false


## This cell's mouth on them, and they are too big to swallow:
## [method _bite_from]'s order, the eater's death first.
func _chew_friend(p: Person) -> void:
	if _bite_clock > 0.0:
		return
	var pb := _cells[PERSON_SLOT]
	var there := pb.pos
	var here := _cell.position
	var damage := CellBody.bite_damage(_cell.tier(&"cytostome"), _cell.gape(),
		pb.radius, Genome.tier_of(pb.genome, &"pellicle"),
		_flank_theta(pb.heading, there, here))
	if damage <= 0.0:
		return
	_bite_clock = CellBody.BITE_GAP
	pb.wound = clampf(pb.wound + damage, 0.0, 1.0)
	var back := CellBody.venom_back(Genome.tier_of(pb.genome, &"toxicyst"), damage)
	_cell.wound = clampf(_cell.wound + back, 0.0, 1.0)
	if _cell.wound >= 1.0:
		hear_contact(Contact.KILLED, there, 0.0, By.FRIEND)
		_tell(p, Contact.BITTEN, here, _felt(damage), By.FRIEND, &"")
		_lose_local()
		return
	if pb.wound >= 1.0:
		hear_contact(Contact.ATE, there, _meal_value_for(pb.radius, _cell.radius),
			By.FRIEND, Genome.dominant_of(pb.genome))
		_tell(p, Contact.KILLED, here, 0.0, By.FRIEND, &"")
		_person_gone(Cause.CHEWED, By.FRIEND)
	else:
		_tell(p, Contact.BITTEN, here, _felt(damage), By.FRIEND, &"")
	hear_contact(Contact.BITTEN, there,
		maxf(_felt(damage) * BITE_FELT_SHARE, _felt(back)), By.FRIEND)


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
	if in_water:
		for i in _water:
			var b := _cells[i]
			if not b.seeded:
				continue
			_push_local(b, true)
		# **Each device moves only what it owns** (shared-pond.md §1.2). The
		# other player gives way on their own device, by the same area share;
		# here only this cell gives way to them.
		if _pond and _cells[PERSON_SLOT].seeded:
			_push_local(_cells[PERSON_SLOT], false)
	if _pond:
		_push_person()

	# The same kind of pre-check as the contact pass: two bodies farther apart
	# than this one's radius plus the widest in the water, with the same
	# rounding margin, cannot overlap, so the overlap is never worked out for
	# them. Nothing here changes a radius, so the bound holds for the pass.
	var widest := _widest()
	for i in _water:
		var b := _cells[i]
		if not b.seeded:
			continue
		var near := _pair_bound(b.radius + widest)
		for j in range(i + 1, _water):
			var other := _cells[j]
			if not other.seeded:
				continue
			if b.pos.distance_squared_to(other.pos) > near:
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


## This cell and body [param b], pushed apart if they overlap: this cell by its
## area share and felt as a knock, and the body by the rest -- if this device
## [param owns] it. A body this device does not own (the other player, or
## anything in a mirror) is moved by its owner, by the same share.
func _push_local(b: Body, owns: bool) -> void:
	var offset := _cell.position - b.pos
	var d := offset.length()
	var overlap := b.radius + _cell.radius - d
	if overlap <= 0.0:
		return
	var normal := offset / d if d > 0.001 else -_forward(b.heading)
	# Share it by **area**, so a big body shoulders a small one aside
	# instead of the two meeting in the middle. A drifter bounces off the
	# player; a grown cell moves them.
	var share := _give_way(b.radius, _cell.radius)
	_cell.position += normal * (overlap * share * PUSH_SHARE)
	if owns:
		b.pos -= normal * (overlap * (1.0 - share) * PUSH_SHARE)
	# And it is felt as motion, not only as a position: the same knock a
	# mote gives, softer, because a cell is not a grain of grit.
	_cell.bump(normal, PUSH_RESTITUTION)


## The water giving way to the other player: its half of every overlap with
## them. Their own half, and their knock, happen on their device.
func _push_person() -> void:
	var pb := _cells[PERSON_SLOT]
	if pb.person == null or not pb.seeded:
		return
	for i in _water:
		var b := _cells[i]
		if not b.seeded:
			continue
		var offset := pb.pos - b.pos
		var d := offset.length()
		var overlap := b.radius + pb.radius - d
		if overlap <= 0.0:
			continue
		var normal := offset / d if d > 0.001 else -_forward(b.heading)
		b.pos -= normal * (overlap * (1.0 - _give_way(b.radius, pb.radius)) * PUSH_SHARE)


## **The widest body in the water**, which is what lets each pair bound in the
## all-pairs passes be worked out once per body instead of once per pair.
## Every body counts, seeded or not: a bound only ever has to be too big.
func _widest() -> float:
	var widest := 0.0
	for b in _cells:
		var r := b.radius
		# See [method _wider]: a NaN anywhere makes every bound NaN.
		if is_nan(r):
			return NAN
		if r > widest:
			widest = r
	return widest


## The larger of two radii -- **and NaN if either is.** `maxf` would quietly
## drop a NaN, and a bound that dropped one could skip a pair the full test,
## which propagates it, does not; a NaN bound skips nothing, so a broken body
## is handled exactly as it was before the pre-checks existed.
static func _wider(a: float, b: float) -> float:
	return a if is_nan(a) or a >= b else b


## A separation, squared, that no rounding can take back under [param reach]:
## a tenth of a percent and a hundredth of a unit over it. `offset.length()`
## is a single-precision square root and this is compared in double, so the
## margin is ten thousand times what either can be out by.
static func _pair_bound(reach: float) -> float:
	var outer := reach * 1.001 + 0.01
	return outer * outer


## How far, squared, a body of radius [param r] and gape [param gape] can have
## its mouth on anything no wider than [param widest]: exactly the bound
## [method Cilia.mouth_touches] refuses beyond, taken for the widest body and
## then made rounding-proof by [method _pair_bound].
static func _mouth_bound(r: float, gape: float, widest: float) -> float:
	return _pair_bound(Cilia.mouth_reach(r, gape) + gape * Cilia.MOUTH_BITE + widest)


## How far, squared, a player of radius [param r] and gape [param gape] and any
## body no wider than [param widest] can be apart with either mouth on the
## other: the larger of [method _mouth_bound] for the player, and the same
## bound for the widest body at the widest gape any cytostome tier opens --
## both of which [method Cilia.mouth_touches] refuses beyond, because it grows
## with the radius and the gape. NaN in, NaN out, which skips nothing.
static func _player_bound(r: float, gape: float, widest: float) -> float:
	var top := 0.0
	for share: float in CellBody.GAPE_BY_TIER:
		top = maxf(top, share)
	var theirs := Cilia.mouth_reach(widest, widest * top) \
		+ widest * top * Cilia.MOUTH_BITE + r
	var mine := Cilia.mouth_reach(r, gape) + gape * Cilia.MOUTH_BITE + widest
	return _pair_bound(_wider(theirs, mine))


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
	_changes += 1


func _meal_value(prey_radius: float) -> float:
	return _meal_value_for(prey_radius, _cell.radius)


## What a body of [param prey_radius] is worth to an eater of [param eater_radius]
## -- §3.2's measure against the body, for whichever player is eating.
static func _meal_value_for(prey_radius: float, eater_radius: float) -> float:
	return clampf(prey_radius / maxf(eater_radius, 0.001), MEAL_MIN, MEAL_MAX)


func _step_recycle() -> void:
	for i in _cells.size():
		if _cells[i].pos.distance_to(_cell.position) > CULL:
			_seed(i)


# ---------------------------------------------------------------------------
# **The water is tuned to each cell** (shared-pond.md §1.4). Single player keeps
# the treadmill above, which reseeds a body in place the moment it is past
# CULL. A pond has two players to keep water round, and a body can be in both
# of their discs at once, so it runs four steps instead, once a frame, after
# the contacts -- which is where the slots its meals emptied are filled again.
#
# An **anchor** is a player with a body: in the water, out of it dividing, or
# quiet. A dead player is not one, and with no anchor at all nothing is culled
# and nothing seeded -- the water waits.
# ---------------------------------------------------------------------------

func _step_pond() -> void:
	_find_anchors()
	var n := _anchor_ids.size()
	if n == 0:
		return
	var reach := CULL * CULL
	# Each anchor's disc, counted once: how many cells, and how many drifters.
	var counts := PackedInt32Array()
	var drifters := PackedInt32Array()
	counts.resize(n)
	drifters.resize(n)
	# 1. **Cull.** A cell farther than CULL from every anchor is nobody's.
	for i in _water:
		var b := _cells[i]
		if not b.seeded:
			continue
		var inside := false
		for k in n:
			if b.pos.distance_squared_to(_anchor_at[k]) <= reach:
				inside = true
				counts[k] += 1
				if b.drifter:
					drifters[k] += 1
		if not inside:
			_retire(i)
	# 2. **Quota.** The anchor furthest short of COUNT gets the next free slot,
	# and a tie goes to the one seeded for least recently -- which is what makes
	# two players side by side take turns (§6 row 2). A new cell lands in every
	# disc it is inside, so the counts are kept rather than taken again.
	while true:
		var pick := -1
		for k in n:
			if counts[k] >= COUNT:
				continue
			if pick < 0 or counts[k] < counts[pick] or (counts[k] == counts[pick]
					and _seeded_for[_anchor_ids[k]] < _seeded_for[_anchor_ids[pick]]):
				pick = k
		if pick < 0:
			break
		var slot := _free_slot()
		if slot < 0:
			break
		_seed_for(slot, _anchor_ids[pick])
		_count_in(_cells[slot], reach, counts, drifters)
	# 3. **Excess.** Coming together, the two waters overlap and the disc
	# briefly holds both; while every anchor is over quota, one cell a frame that
	# lies beyond RING_MAX of everybody -- out of every frame -- is retired.
	var over := true
	for k in n:
		if counts[k] <= COUNT:
			over = false
	if over:
		var gone := _excess(reach, drifters)
		if gone >= 0:
			var b := _cells[gone]
			for k in n:
				if b.pos.distance_squared_to(_anchor_at[k]) <= reach:
					counts[k] -= 1
					if b.drifter:
						drifters[k] -= 1
			_retire(gone)
	# 4. **Floor.** A disc with no drifter in it gets one, quota or not: the
	# drifter floor of [method _seed], asked of each player's own water.
	for k in n:
		if drifters[k] > 0:
			continue
		var slot := _free_slot()
		if slot < 0:
			slot = _room_in(k, reach)
		if slot < 0:
			continue
		_seed_for(slot, _anchor_ids[k], true)
		_count_in(_cells[slot], reach, counts, drifters)


## The anchors this frame, into [member _anchor_ids] and [member _anchor_at].
func _find_anchors() -> void:
	_anchor_ids.resize(0)
	_anchor_at.resize(0)
	if anchored and _cell != null:
		_anchor_ids.append(Anchor.LOCAL)
		_anchor_at.append(_cell.position)
	if _pond and _cells.size() > PERSON_SLOT and _cells[PERSON_SLOT].person != null:
		_anchor_ids.append(Anchor.PERSON)
		_anchor_at.append(_cells[PERSON_SLOT].pos)


## Adds body [param b] to every disc it lies in.
func _count_in(b: Body, reach: float, counts: PackedInt32Array,
		drifters: PackedInt32Array) -> void:
	for k in _anchor_ids.size():
		if b.pos.distance_squared_to(_anchor_at[k]) <= reach:
			counts[k] += 1
			if b.drifter:
				drifters[k] += 1


## The first water slot with nobody in it, or -1.
func _free_slot() -> int:
	for i in _water:
		if not _cells[i].seeded:
			return i
	return -1


## Step 3's choice: of the cells beyond RING_MAX of every anchor, the one
## farthest from its nearest -- never one hunting a player, whose run would
## vanish from under their dread, and never the last drifter of any disc.
func _excess(reach: float, drifters: PackedInt32Array) -> int:
	var ring := RING_MAX * RING_MAX
	var best := -1
	var best_d := -1.0
	for i in _water:
		var b := _cells[i]
		if not b.seeded or _hunting_a_player(b):
			continue
		var nearest := INF
		var last_drifter := false
		for k in _anchor_ids.size():
			var d := b.pos.distance_squared_to(_anchor_at[k])
			nearest = minf(nearest, d)
			if b.drifter and d <= reach and drifters[k] <= 1:
				last_drifter = true
		if nearest <= ring or last_drifter:
			continue
		if nearest > best_d:
			best_d = nearest
			best = i
	return best


## Step 4 with every slot taken: one of anchor [param k]'s own cells makes room
## for its drifter -- the farthest one no other disc counts and that is not on a
## run at a player. -1 if there is none, and the floor waits a frame.
func _room_in(k: int, reach: float) -> int:
	var best := -1
	var best_d := -1.0
	for i in _water:
		var b := _cells[i]
		if not b.seeded or b.drifter or _hunting_a_player(b):
			continue
		var d := b.pos.distance_squared_to(_anchor_at[k])
		if d > reach:
			continue
		var shared := false
		for other in _anchor_ids.size():
			if other != k and b.pos.distance_squared_to(_anchor_at[other]) <= reach:
				shared = true
		if shared or d <= best_d:
			continue
		best_d = d
		best = i
	if best >= 0:
		_retire(best)
	return best


func _hunting_a_player(b: Body) -> bool:
	return b.state == State.STALK \
		and (b.target == TARGET_PLAYER or b.target == PERSON_SLOT)


## **A slot empties** (§1.4): nobody is in it until the quota fills it again.
## It takes a new serial on the way out, so a chase of the body that was here
## cannot carry on against the one that comes next.
func _retire(index: int) -> void:
	var b := _cells[index]
	b.seeded = false
	b.radius = 0.0
	b.speed = 0.0
	b.state = State.DRIFT
	b.target = TARGET_NONE
	b.target_serial = 0
	b.meals = 0
	b.wound = 0.0
	b.bite = 0.0
	_serial += 1
	b.serial = _serial
	_changes += 1


# ---------------------------------------------------------------------------
# What the cell can actually sense: a summed concentration, a level with no
# bearing in it at all, and a scalar with no bearing in it.
# ---------------------------------------------------------------------------

func _step_sense() -> void:
	var total := 0.0
	var dread := 0.0
	var worst := 0.0
	var gape := _cell.gape()
	var shade := 0.0
	var shade_pull := Vector2.ZERO
	# **What the nose picks up, which is not the same sum again.** Restricted to
	# sources inside [member smell_range] and weighted by how nearly each one
	# lies along the organ's own arc -- and then simply added up, because
	# concentration fields superpose. The split into loudest and rest is all
	# that survives of the tail: [constant SMELL_TAIL] is 1.0, so the two are
	# added back together below at full weight. It is kept because the split
	# costs nothing, needs no sort, and is the one line that would have to be
	# rewritten if the owner ever wanted a tail again.
	var smelt_top := 0.0
	var smelt_rest := 0.0

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
				if d < smell_range:
					# The whole of "orientation should count": a cosine lobe
					# about the arc the organ is worn on, never falling below
					# SMELL_BEHIND. A cone with a tier-scaled width was measured
					# and buys under 2% of swing -- three-senses.md §7.4.
					var lobe := 0.5 + 0.5 * cos(angle_difference(
						smell_bearing, _cell.bearing_to(b.pos)))
					var w := c * (SMELL_BEHIND + (1.0 - SMELL_BEHIND) * lobe)
					# Loudest and rest, in one pass and with no sort: the new
					# maximum demotes the old one into the tail.
					if w > smelt_top:
						smelt_rest += smelt_top
						smelt_top = w
					else:
						smelt_rest += w

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
	# **There is no bearing here any more, and that is the change.** A cell with
	# no chemocyte leaves with [member smell_range] 0, so nothing is ever inside
	# the nose and it leaves with taste_level 0 -- which is what makes "an organ
	# you have not grown is silent" true at the source as well as at the two
	# gates downstream of it. `s` is 0 there, and `0 / (0 + K)` is 0, so the
	# saturation costs that guarantee nothing.
	#
	# **A receptor saturates; it does not clip.** The clamp that used to be on
	# this line was the actual fault three-senses.md §7.5 blamed on the sum:
	# above 1.0 its slope is zero, and a readout with no slope in it is a
	# readout a forager cannot climb. See [constant SMELL_HALF].
	var s := smelt_top + SMELL_TAIL * smelt_rest
	taste_level = s / (s + SMELL_HALF)
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
## body it comes back off that is not in a shadow -- edible, inedible, hunting
## you or asleep. That is the whole of what makes it a different sense from
## `chemocyte` rather than a second skin on it: the scent field is a statement
## about food, and most of what is out there is not food.
##
## **It bounces.** The front travels out, reflects off the near edge of whatever
## it meets, and the echo travels home; the organ hears it when it gets back, at
## `2d / PING_SPEED`. That is the owner's word and it is also the only story
## that makes the drawn picture and the felt one the same event -- you watch the
## shout go out, you watch one piece of it come back, and the skin lights when
## it lands. A bat is not a thing that shouts; it is a thing that listens.
##
## Returns are staggered by their own round trip, which is what turns one pulse
## into a sweep: the nearest body answers at `2d / PING_SPEED` and the farthest
## seconds later -- **8.8 s** from the edge of tier-1 reach at 250. **That
## stagger is also what resolves the one ambiguity occlusion creates**: a
## shadowed near body and a clear far body both come back faint, but the near
## one still answers early. Nothing here posts and nothing here keeps a position
## past the frame it becomes a bearing.
##
## **What the round trip does not double is the duration.** Only the near
## hemisphere of a body answers -- the far side is in its own shadow -- so the
## echo is spread over the depth from the near pole to the limb, which is `R`,
## and arrives over `2R / PING_SPEED`. That is the same number the one-way front
## took to cross the whole body, so ping-as-outline.md §3.2's table survives the
## bounce untouched. Arrival time doubled; held time did not.
func _step_pings(delta: float) -> void:
	pings.clear()
	ping_echoes.clear()
	if _cell == null:
		return
	if ping_range <= 0.0 or ping_period <= 0.0:
		# The organ was lost, or was never grown. Anything still in flight is
		# dropped rather than delivered: it was never heard.
		_echoes.clear()
		_pulses.clear()
		ping_fronts.clear()
		ping_listen = 0.0
		_ping_clock = 0.0
		_ping_age = -1.0
		return

	_ping_clock -= delta
	if _ping_clock <= 0.0:
		_ping_clock = ping_period
		_ping_age = 0.0
		_pulses.append(0.0)
		_cast_ping()
		pulsed.emit()
	elif _ping_age >= 0.0:
		_ping_age += delta

	# Every front still inside reach, not just the newest. A front that has run
	# out of range is dropped; the echoes it started are in `_echoes` and live
	# their own lives from here. Aged in place and trimmed from the head, which
	# is where they always expire -- they were appended in order and they all
	# travel at the same speed, so the dead ones are always a prefix.
	for i in _pulses.size():
		_pulses[i] = float(_pulses[i]) + delta
	while not _pulses.is_empty() and float(_pulses[0]) * PING_SPEED > ping_range:
		_pulses.remove_at(0)
	ping_fronts.clear()
	for age: float in _pulses:
		ping_fronts.append(age * PING_SPEED)

	# The hum: how much of the newest pulse's **round trip** is still to come.
	# It breathes at tier 1, where a 3.2 s period sits inside an 8.8 s trip, and
	# it is nearly flat at tier 3, where the period is a tenth of the trip --
	# which is honest, because a tier-3 organ really is always listening.
	var trip := 2.0 * ping_range / PING_SPEED
	ping_listen = 0.0
	if _ping_age >= 0.0 and trip > 0.0:
		ping_listen = 1.0 - clampf(_ping_age / trip, 0.0, 1.0)

	# Backwards, so removing one does not skip the next.
	for i in range(_echoes.size() - 1, -1, -1):
		var echo: Array = _echoes[i]
		echo[0] -= delta
		if echo[0] > 0.0:
			# Still coming. Where it is, for the two views: the radius is how
			# far it still has to travel, so it walks in and lands on the organ
			# at the instant the mark appears on the skin.
			ping_echoes.append([float(echo[0]) * PING_SPEED,
				_cell.bearing_to(echo[1]), float(echo[3]), float(echo[2])])
			continue
		pings.append([_cell.bearing_to(echo[1]), echo[2], echo[3], echo[4]])
		_echoes.remove_at(i)
	# Nearest home first, so a view -- or the recorder, which has room for four
	# -- keeps the ones about to land. `_echoes` is in no useful order once two
	# pulses are overlapping in it, which at tier 3 is always.
	ping_echoes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	# Loudest first. The membrane has two arcs out of a pool of four and it keeps
	# the two loudest, so the order decides which pair is drawn when three land
	# inside one another's hold -- 23% of the time at tier 3, measured.
	pings.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])


## Everything inside reach the pulse can actually reach, nearest first, capped
## at [constant PING_RETURNS_BY_TIER] **after** the shadows have been taken off.
##
## Each one leaves with **two scalars beside its level**, both made out of
## numbers this function already holds and both spent before it returns
## (ping-as-outline.md §3):
##
## - `width`, how wide the organ reports it. The true angular half-width is
##   `asin(R / D)`, and at seeding distance that is under three degrees for
##   every body in this water -- invisible, and identical for a speck and a
##   whale. So the organ's own beamwidth is a **floor** and the true extent is
##   magnified on top of it. A transducer, not a camera; the mapping is monotone
##   and the beam is the resolution limit, which is what the tier ladder lowers.
## - `hold`, how long the echo takes to pass, which is `2R / PING_SPEED` and is
##   **independent of distance**. This is the bat reading: echo duration is
##   target depth.
##
## **The pulse leaves the skin, not the middle of the cell.** Its origin is the
## organ's own point on the membrane -- [member ping_bearing] out at the body's
## radius -- and every body in the way takes a bite out of what comes back,
## starting with the body it left. The origin is a world position and it is a
## local: it is made and spent inside this function, and what leaves this file
## is still a bearing and a strength.
##
## Two terms and one loop, both multiplying into the range falloff:
##
## - the **hull**, which is the emitter looking at the hemisphere it faces, with
##   [constant PING_GRAZE]'s soft edge on it;
## - every **nearer body**, by how centrally the path crosses it -- dead through
##   the middle takes the full bite, a graze past the rim takes none.
##
## Both survive at [member ping_through], per occluder, multiplying. So a
## tier-1 cell hears nothing at all behind its own organ, and a tier-3 one hears
## through itself at 0.58 and never quite as well as around itself, which is the
## right direction for a build that has spent three tiers on one gene.
func _cast_ping() -> void:
	# Clamped here and not trusted: the run writes it every frame, and a headless
	# boot casts a pulse before the first write lands.
	var tier := clampi(ping_tier, 0, PING_RETURNS_BY_TIER.size() - 1)
	if PING_RETURNS_BY_TIER[tier] <= 0:
		return
	var dir := _cell.forward() * cos(ping_bearing) + _cell.starboard() * sin(ping_bearing)
	var origin := _cell.position + dir * _cell.radius
	var found: Array = []
	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		# Reach is still measured from the middle of the cell, as it always has
		# been: moving the origin is about what the pulse can *see*, not about
		# how far it carries or how a return fades, and a range that changed
		# with the slot would make one slot strictly the best place for a radar.
		var d := b.pos.distance_to(_cell.position) - b.radius
		if d >= ping_range:
			continue
		found.append([maxf(d, 0.0), b.pos, b.radius])
	if found.is_empty():
		return
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var heard: Array = []
	for i in found.size():
		var at: Vector2 = found[i][1]
		var level: float = pow(clampf(1.0 - float(found[i][0]) / ping_range, 0.0, 1.0),
			PING_FALLOFF)
		var path := at - origin
		var reach := path.length()
		# The hull. A body touching the organ has no direction to be on either
		# side of, and `normalized()` on a zero vector is zero: the smoothstep
		# lands mid-fade, which is the only honest answer to "which side".
		var open := smoothstep(-PING_GRAZE, PING_GRAZE,
			path.normalized().dot(dir))
		level *= lerpf(ping_through, 1.0, open)
		# Everything nearer is in the way, and "nearer" is measured from the
		# cell while the path is measured from the organ -- so the two orders
		# are not quite the same order, and `for j in i` can skip a body that
		# was genuinely across this path.
		#
		# **What it skips is bounded, and the bound is the point.** A skipped
		# occluder is one that *overlaps the body it would have shadowed*:
		# 4,000,000 random configurations at r38 produced 44,096 occluding
		# pairs, 233 of them skipped, and **every one of the 233 overlapped its
		# target**, 99.6% with its own centre inside the target's disc. Seen
		# from the organ it sits a median 0.86 degrees and 5.5 units from the
		# body it would have dimmed -- far inside the lobe that body's own mark
		# is drawn with, whose half-width is 17, 13 or 10 degrees by tier. So it
		# is not a second thing out there being missed; it is the same mark.
		# Usually it is behind the very surface the echo comes off as well: the
		# mean surface gap is -7.1 units, negative on 98% of the 233.
		#
		# And the configuration is transient where the ping is not.
		# `_step_separate` halves every overlap in the water each frame at
		# [constant PUSH_SHARE], so 97% of one is gone in five frames, against
		# a pulse that fires once every 1.4 to 3.2 seconds.
		var axis := path / reach if reach > 0.001 else dir
		for j in i:
			if level <= PING_SILENT:
				break
			var other: Vector2 = found[j][1]
			var to_j := other - origin
			var along := to_j.dot(axis)
			# Not between the organ and the body: a body off the back of the
			# emitter or beyond the target is not in this path.
			if along <= 0.0 or along >= reach:
				continue
			var radius_j: float = found[j][2]
			if radius_j <= 0.0:
				continue
			var clear := clampf((to_j - axis * along).length() / radius_j, 0.0, 1.0)
			level *= lerpf(ping_through, 1.0, clear)
		if level <= PING_SILENT:
			continue
		# The two readings beside the level, out of numbers this loop already
		# has. `span` is organ-to-centre and is floored at the radius, so a body
		# the organ is inside does not ask `asin` for more than 1.
		var radius_i: float = found[i][2]
		var span := maxf(reach, radius_i)
		var alpha := rad_to_deg(asin(clampf(radius_i / span, 0.0, 1.0)))
		var width := minf(PING_WIDTH_FLOOR[tier] + PING_WIDTH_GAIN[tier] * alpha,
			PING_WIDTH_MAX)
		var hold := PING_RING * 2.0 * radius_i / PING_SPEED
		heard.append([float(found[i][0]), at, level, width, hold])
		if heard.size() >= PING_RETURNS_BY_TIER[tier]:
			break
	var due := 0.0
	for i in heard.size():
		var d: float = heard[i][0]
		# **Out and back.** The front reaches the near edge at `d / PING_SPEED`
		# and the echo takes as long again to get home.
		var flight := 2.0 * d / PING_SPEED
		due = flight if i == 0 else maxf(flight, due + PING_MIN_GAP)
		_echoes.append([due, heard[i][1], heard[i][2], heard[i][3], heard[i][4]])


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


## **Who was hunting the player, written back from a recording.**
##
## [method restore_body] deliberately writes no state machine, which is right --
## a body being replayed is not deciding anything. But [method hunter] *is* a
## question about the state machine, and `vision.gd` draws the dread, wake and
## lunge rings off its answer. Left alone, every replayed body answers DRIFT and
## the rings never draw at all: the truth pane loses the one instrument that
## explains a predation death, in exactly the case it exists for.
##
## So the recording carries the index and this puts it back, on these two fields
## and nothing else -- the two [method hunter] reads. [param index] is -1 for
## nobody, which is also what a frame with no stalker recorded.
##
## Every other claim on the player is cleared on the way past, because a field
## frozen at the moment of death still holds whatever was chasing you then, and
## a replayed frame from twenty seconds earlier must not inherit it.
func restore_hunter(index: int) -> void:
	for i in _cells.size():
		var b := _cells[i]
		if i == index:
			b.state = State.STALK
			b.target = TARGET_PLAYER
		elif b.state == State.STALK and b.target == TARGET_PLAYER:
			b.state = State.DRIFT
			b.target = TARGET_NONE


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
# **The shared pond** (shared-pond.md §1). What a host is told about the other
# player and what it says about them; what a mirror is sent and what it hears.
# Nothing here is called in single player -- in Phase 1 only tools call it --
# and a field that has never opened a pond answers every question in this file
# as if nobody else were in the water.
# ---------------------------------------------------------------------------

## **The host's water becomes a pond**: two waters' worth of slots, and a slot
## for the other player, empty until [method place_person]. Nothing already in
## the water moves or changes. Never called solo.
func open_pond() -> void:
	if _pond or _cell == null:
		return
	_pond = true
	# The authored first arrival is single-player authoring: it moves slot 0 in
	# front of this cell, and in a pond slot 0 may be somebody else's water.
	_first_pending = false
	for b in _cells:
		if b.seeded:
			b.tuned = Anchor.LOCAL
	while _cells.size() < POND_SLOTS:
		_cells.append(Body.new())
	_water = PERSON_SLOT
	_seeded_for = PackedInt64Array([0, 0])
	_stamp = 0
	_changes += 1


func pond_open() -> bool:
	return _pond


func mirroring() -> bool:
	return _mirror


## The other player's record, or null when nobody else is in this water.
func person() -> Person:
	if not _pond or _cells.size() <= PERSON_SLOT:
		return null
	return _cells[PERSON_SLOT].person


## **Where the other player is**, as they last reported it: place, heading,
## radius, and the velocity and turn rate the field carries them on by until the
## next report -- under the water's own drag, so a phone that goes quiet leaves
## a body that coasts and stops, still edible and still biting (§1.8).
##
## The first call is an **arrival**: a new body, a new serial and
## [constant FIRST_DELAY] of grace, which is what every [method setup] grants
## this cell. Anything not finite is refused whole, as the wire refuses it.
func place_person(at: Vector2, heading: float, body_radius: float,
		velocity: Vector2 = Vector2.ZERO, turning: float = 0.0) -> void:
	if not _pond or _mirror:
		return
	if not at.is_finite() or not is_finite(heading) or not is_finite(body_radius) \
			or body_radius <= 0.0:
		return
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	if not is_finite(turning):
		turning = 0.0
	var pb := _cells[PERSON_SLOT]
	if pb.person == null:
		pb.person = Person.new()
		pb.person.first_hunt = FIRST_DELAY
		_serial += 1
		pb.serial = _serial
		pb.meals = 0
		pb.wound = 0.0
		pb.bite = 0.0
		pb.state = State.DRIFT
		pb.target = TARGET_NONE
		pb.drifter = false
		_derive_person(pb)
	var p := pb.person
	p.at = at
	p.facing = heading
	p.launch = velocity
	p.velocity = velocity
	p.turning = turning
	p.age = 0.0
	pb.pos = at
	pb.heading = heading
	pb.radius = body_radius
	pb.seeded = p.in_water
	_changes += 1


## **What the other player wears**: [param tiers] as `{gene: tier}` and
## [param order] slot by slot, as PERSON carries them (§2). Everything their
## organs buy is worked out here, once, with the tables this cell's own nodes
## read -- so their dart looks along the arc it is worn on and their mouth is
## the width it is drawn.
func set_person_genome(tiers: Dictionary, order: Array) -> void:
	if not _pond or _cells.size() <= PERSON_SLOT:
		return
	var pb := _cells[PERSON_SLOT]
	pb.genome = tiers.duplicate()
	pb.order = order.duplicate()
	if pb.person != null:
		_derive_person(pb)
	_changes += 1


func _derive_person(pb: Body) -> void:
	var p := pb.person
	var tiers := pb.genome
	p.swim_speed = CellBody.swim_speed_of(Genome.tier_of(tiers, &"flagellum"),
		Genome.tier_of(tiers, &"axoneme"))
	p.armour = CellBody.ARMOR_BY_TIER[clampi(Genome.tier_of(tiers, &"pellicle"),
		0, CellBody.ARMOR_BY_TIER.size() - 1)]
	var dart := clampi(Genome.tier_of(tiers, &"trichocyst"), 0,
		CellBody.DART_RANGE_BY_TIER.size() - 1)
	p.dart_range = CellBody.DART_RANGE_BY_TIER[dart]
	p.dart_cooldown = CellBody.DART_COOLDOWN_BY_TIER[dart]
	var slot := pb.order.find(&"trichocyst")
	p.dart_bearing = Cilia.slot_bearing(slot) if slot >= 0 else 0.0
	var venom := clampi(Genome.tier_of(tiers, &"toxicyst"), 0,
		CellBody.VENOM_COST_BY_TIER.size() - 1)
	p.venom_cost = CellBody.VENOM_COST_BY_TIER[venom] if venom > 0 else -1.0


## The other player has left the water, dividing, or come back into it. Out
## of it they are still an anchor, and nothing in the water can see them, touch
## them or go on chasing them (§1.5).
func set_person_in_water(on: bool) -> void:
	var p := person()
	if p == null:
		return
	p.in_water = on
	_cells[PERSON_SLOT].seeded = on


## Their phone has gone quiet, or been heard again. Nothing here changes: see
## [member Person.quiet].
func set_person_quiet(on: bool) -> void:
	var p := person()
	if p != null:
		p.quiet = on


## **The other player is gone from this water** -- dead, or no longer on the
## wire. The slot empties and takes a new serial, so nothing still chasing them
## can carry on against whoever arrives next. Their genome is kept for the next
## arrival, which a new PERSON replaces.
func remove_person() -> void:
	if not _pond or _cells.size() <= PERSON_SLOT:
		return
	var pb := _cells[PERSON_SLOT]
	pb.person = null
	pb.seeded = false
	pb.radius = 0.0
	pb.speed = 0.0
	pb.wound = 0.0
	pb.bite = 0.0
	_serial += 1
	pb.serial = _serial
	_changes += 1


## **This cell leaves the water** (§1.5): dividing, when [param dead] is false,
## and still an anchor -- or dead, and not.
func leave_water(dead: bool) -> void:
	in_water = false
	anchored = not dead


## **This cell comes back into the water**, born or returned from the black,
## with a new cell's organs and a new cell's grace -- the part of [method setup]
## that is about the cell rather than the water. Nothing is reseeded: in a pond
## what it comes back to is still there.
func enter_water() -> void:
	in_water = true
	anchored = true
	_first_hunt = FIRST_DELAY
	_fresh_senses()


## **A sister, in a pond** (§1.5): the declined daughter left in the water at
## [param at] with [param heading], in the first free slot -- or, with none free,
## in place of the body farthest from every anchor that is neither a drifter nor
## hunting a player. For this cell's own birth through [method put_sister], and
## for the other player's through SISTER.
func place_sister(at: Vector2, heading: float, body_radius: float,
		tiers: Dictionary) -> void:
	if not _pond or _mirror or _cell == null:
		return
	var slot := _free_slot()
	if slot < 0:
		slot = _farthest_spare()
	if slot < 0:
		return
	# Made for whichever player she lies nearer: her own body replaces what is
	# drawn, but the slot's clocks, serial and turn are that water's.
	_find_anchors()
	var anchor: int = Anchor.LOCAL
	var nearest := INF
	for k in _anchor_ids.size():
		var d := at.distance_squared_to(_anchor_at[k])
		if d < nearest:
			nearest = d
			anchor = _anchor_ids[k]
	_seed_for(slot, anchor)
	var b := _cells[slot]
	b.drifter = false
	b.radius = body_radius
	b.genome = tiers.duplicate()
	b.pos = at
	b.heading = heading
	b.aim = at
	b.flee_from = at
	_changes += 1


## The seeded water cell farthest from its nearest anchor that is neither a
## drifter nor hunting a player, retired to make room; -1 if there is none.
func _farthest_spare() -> int:
	_find_anchors()
	var best := -1
	var best_d := -1.0
	for i in _water:
		var b := _cells[i]
		if not b.seeded or b.drifter or _hunting_a_player(b):
			continue
		var nearest := INF
		for at in _anchor_at:
			nearest = minf(nearest, b.pos.distance_squared_to(at))
		if nearest > best_d:
			best_d = nearest
			best = i
	if best >= 0:
		_retire(best)
	return best


## **This device's water becomes a mirror of the host's** (§1.1): the bodies
## arrive by [method apply_pond], their genomes by [method apply_genome] and
## every contact by [method hear_contact], and this field simulates nothing but
## what its own cell senses. The water it had is gone -- this is UX §0.5's beat
## -- and so is everything its organs were still listening for.
func become_mirror() -> void:
	if _cell == null:
		return
	_mirror = true
	_pond = true
	_first_pending = false
	in_water = true
	anchored = true
	_cells.clear()
	for i in POND_SLOTS:
		_cells.append(Body.new())
	_water = PERSON_SLOT
	_snap_at = PackedVector2Array()
	_snap_at.resize(POND_SLOTS)
	_snap_age = 0.0
	_book.clear()
	_fresh_senses()
	_changes += 1


## **The host is gone, and this water is yours** (§1.8): a fresh single-player
## water round this cell, which is [method setup] -- what every new water has
## always been. The body, the genome, the generation and the hunger are not this
## node's, and nothing here touches them.
func leave_mirror() -> void:
	if _mirror:
		setup(_cell)


## **One snapshot of this water, as a mirror reads it** (§2's POND): an Array
## per body, indexed by [enum Entry].
##
## [param for_person] true is the snapshot for the guest: "stalking you" means
## stalking them, the send set is measured from them, and the person in it is
## this cell. False is a snapshot for a mirror of this very cell, which is how
## Phase 1 proves the mirror senses exactly what the field does.
##
## The send set is every body whose surface lies within [param reach] of the
## recipient **and every body hunting them, wherever it is**, so that the
## mirror's [method hunter] always agrees with the host's.
func pond_entries(for_person: bool, reach: float = SEND_REACH) -> Array:
	var out: Array = []
	if not _pond or _mirror or _cell == null:
		return out
	var pb := _cells[PERSON_SLOT]
	if for_person and pb.person == null:
		return out
	var you := pb.pos if for_person else _cell.position
	for i in _water:
		var b := _cells[i]
		if not b.seeded:
			continue
		var stalking := b.state == State.STALK and (
			(b.target == PERSON_SLOT and b.target_serial == pb.serial) if for_person
			else b.target == TARGET_PLAYER)
		if not stalking and b.pos.distance_to(you) - b.radius > reach:
			continue
		out.append([i, b.serial, b.meals, FLAG_STALKING if stalking else 0,
			b.pos, b.heading, b.radius, b.wound, b.speed, Vector2.ZERO, 0.0])
	if for_person:
		if anchored:
			out.append([PERSON_SLOT, 0, 0,
				FLAG_PERSON | (FLAG_IN_WATER if in_water else 0),
				_cell.position, _cell.heading, _cell.radius, _cell.wound,
				_cell.velocity.length(), _cell.velocity, _cell.heading_rate()])
	elif pb.person != null:
		out.append([PERSON_SLOT, pb.serial, pb.meals,
			FLAG_PERSON | (FLAG_IN_WATER if pb.person.in_water else 0),
			pb.pos, pb.heading, pb.radius, pb.wound, pb.person.velocity.length(),
			pb.person.velocity, pb.person.turning])
	return out


## **A snapshot of the host's water arrives** (mirror only). Every body in it is
## put where the host had it, and carried on from there along its heading at the
## speed it was swimming -- for at most [constant CARRY_MAX], after which it
## holds -- and the person by the closed form of the water's drag. A slot that
## is not in the snapshot leaves this water: out of the send set is out of every
## sense. [param your_wound] is this cell's own wound as the host last bit it
## (§0.1); this cell mends it itself until the next one.
func apply_pond(your_wound: float, entries: Array) -> void:
	if not _mirror:
		return
	if is_finite(your_wound):
		_cell.wound = clampf(your_wound, 0.0, 1.0)
	var sent := PackedByteArray()
	sent.resize(POND_SLOTS)
	for entry: Array in entries:
		if entry.size() <= Entry.TURNING:
			continue
		var slot := int(entry[Entry.SLOT])
		if slot < 0 or slot >= POND_SLOTS:
			continue
		var flags := int(entry[Entry.FLAGS])
		var is_person := (flags & FLAG_PERSON) != 0
		if is_person != (slot == PERSON_SLOT):
			continue
		sent[slot] = 1
		var b := _cells[slot]
		if is_person:
			_mirror_person(b, entry, (flags & FLAG_IN_WATER) != 0)
			continue
		var serial := int(entry[Entry.SERIAL])
		var meals := int(entry[Entry.MEALS])
		if serial != b.serial or meals != b.meals:
			# A new body version: its genome, if it has already come, and
			# otherwise nothing -- an unknown genome is inert in every rule --
			# unless this is the same body grown, which keeps what it had.
			var sig := serial * 1000 + meals
			if _book.has(sig):
				b.genome = _book[sig]
			elif serial != b.serial:
				b.genome = {}
			b.serial = serial
			b.meals = meals
		b.pos = entry[Entry.AT]
		b.heading = float(entry[Entry.HEADING])
		b.radius = float(entry[Entry.RADIUS])
		b.wound = float(entry[Entry.WOUND])
		b.speed = float(entry[Entry.SPEED])
		b.seeded = true
		# **The stalking bit is the hunt, for everything this side reads:**
		# [method hunter], and through it the view's rings and the recorder.
		var stalking := (flags & FLAG_STALKING) != 0
		b.state = State.STALK if stalking else State.DRIFT
		b.target = TARGET_PLAYER if stalking else TARGET_NONE
		_snap_at[slot] = b.pos
	# Out of the snapshot is out of this water, and out of every hunt too: a
	# body the host retired stops being sent, and one left in STALK here would
	# go on answering [method hunter] for a hunter that no longer exists.
	#
	# **And it is drawn as nothing: radius 0, as the host's [method _retire]
	# leaves it.** `vision.gd` reads `points()` and `radii()` and never
	# `seeded`, so a body eaten near the guest and refilled on the host beyond
	# the send reach would otherwise stay drawn where it died, a ghost in full
	# vision. The next snapshot that carries the slot writes its radius back.
	for slot in POND_SLOTS:
		if sent[slot] == 0:
			var b := _cells[slot]
			b.seeded = false
			b.radius = 0.0
			b.speed = 0.0
			b.state = State.DRIFT
			b.target = TARGET_NONE
			if slot == PERSON_SLOT:
				b.person = null
	_snap_age = 0.0
	_changes += 1


func _mirror_person(pb: Body, entry: Array, wet: bool) -> void:
	if pb.person == null:
		pb.person = Person.new()
		_derive_person(pb)
	var p := pb.person
	p.at = entry[Entry.AT]
	p.facing = float(entry[Entry.HEADING])
	p.launch = entry[Entry.VELOCITY]
	p.velocity = p.launch
	p.turning = float(entry[Entry.TURNING])
	p.age = 0.0
	p.in_water = wet
	pb.serial = int(entry[Entry.SERIAL])
	pb.meals = int(entry[Entry.MEALS])
	pb.pos = p.at
	pb.heading = p.facing
	pb.radius = float(entry[Entry.RADIUS])
	pb.wound = float(entry[Entry.WOUND])
	pb.speed = float(entry[Entry.SPEED])
	pb.seeded = wet


## **A body version's genome** (mirror only), as GENOME carries it once per
## version: remembered by `serial * 1000 + meals`, and worn at once if that body
## is already here -- so it can arrive before its body or after it.
func apply_genome(slot: int, serial: int, meals: int, tiers: Dictionary) -> void:
	if not _mirror:
		return
	_book[serial * 1000 + meals] = tiers
	while _book.size() > BOOK_MAX:
		_book.erase(_book.keys()[0])
	if slot >= 0 and slot < _water:
		var b := _cells[slot]
		if b.serial == serial and b.meals == meals:
			b.genome = tiers
			_changes += 1


## **A contact, told to this cell** (§1.3): the shipped signal, with the bearing
## worked out here from [param at] -- a place crosses the wire and a bearing
## never does (§0.2), because only this device knows which way its cell is
## facing now. The field's own contacts with this cell are told through here as
## well, so the run's handlers cannot tell a pond from single player.
## [param level] is the strength, or the nutrition for `ATE`; [param _by] is
## carried for the run and changes nothing here.
func hear_contact(what: int, at: Vector2, level: float = 0.0,
		_by: int = By.WATER, gene: StringName = &"") -> void:
	match what:
		Contact.WAKED:
			waked.emit(_cell.bearing_to(at), level)
		Contact.BITTEN:
			bitten.emit(_cell.bearing_to(at), level)
		Contact.STUNG:
			stung.emit(_cell.bearing_to(at))
		Contact.DARTED:
			darted.emit(_cell.bearing_to(at))
		Contact.ATE:
			eaten.emit(level, gene, at)
		Contact.KILLED:
			killed.emit(_cell.bearing_to(at))


## One contact, to whichever player it happened to: this cell through the
## shipped signals, the person through [signal person_touched].
func _tell(p: Person, what: int, at: Vector2, level: float, by: int,
		gene: StringName) -> void:
	if p == null:
		hear_contact(what, at, level, by, gene)
	else:
		person_touched.emit(what, at, level, by, gene)


## Is [param b] on a run at player [param p] -- null being this cell.
func _hunts(b: Body, p: Person) -> bool:
	if p == null:
		return b.target == TARGET_PLAYER
	return b.target == PERSON_SLOT and b.target_serial == _cells[PERSON_SLOT].serial


## A player's body as a mouth measures it, `pellicle` and all.
func _armoured(p: Person) -> float:
	return _cell.swallow_radius() if p == null \
		else _cells[PERSON_SLOT].radius * p.armour


## [method CellBody.bearing_to], asked of either player.
func _bearing_for(p: Person, point: Vector2) -> float:
	if p == null:
		return _cell.bearing_to(point)
	var pb := _cells[PERSON_SLOT]
	var offset := point - pb.pos
	return atan2(offset.dot(Vector2(cos(pb.heading), sin(pb.heading))),
		offset.dot(_forward(pb.heading)))


## The person [param b] is on a run at, or null.
func _hunted_person(b: Body) -> Person:
	if b.target != PERSON_SLOT:
		return null
	var prey := _target_body(b)
	return prey.person if prey != null else null


## The other player died here: out of the slot, then said -- so a listener that
## brings them straight back finds it empty.
func _person_gone(cause: int, by: int) -> void:
	var at := _cells[PERSON_SLOT].pos
	remove_person()
	person_died.emit(cause, by, at)


## This cell died in a pond, in this frame: out of the water and no anchor.
func _lose_local() -> void:
	leave_water(true)


## What this cell was most made of, for the friend who ate it.
func _local_dominant() -> StringName:
	var genome: Node = _cell.genome
	if genome == null or not genome.has_method(&"tiers"):
		return &""
	return Genome.dominant_of(genome.tiers())


## **The other player's body between reports** (host): it knits and its mouth
## reloads exactly as a water cell's do -- §1.2's only rule for a person in
## `_step_body` -- its grace and its dart run down, and it is carried on from
## where it said it was.
func _step_person(delta: float) -> void:
	var pb := _cells[PERSON_SLOT]
	var p := pb.person
	if p == null:
		return
	pb.wound = CellBody.mended(pb.wound, delta)
	pb.bite = maxf(pb.bite - delta, 0.0)
	p.dart_clock = maxf(p.dart_clock - delta, 0.0)
	if p.first_hunt > 0.0:
		p.first_hunt -= delta
	_carry_person(pb, p.age)
	p.age += delta


## The person [param t] seconds past their last report: the water's own drag on
## the velocity they reported, in closed form -- `p0 + v0 (1 - e^(-kt)) / k`,
## multiplayer.md §5.4, exact for a body nobody is steering -- and the heading
## turned on for no longer than [constant CARRY_MAX].
func _carry_person(pb: Body, t: float) -> void:
	var p := pb.person
	var k := maxf(CellBody.DRAG, 0.001)
	var fade := exp(-k * t)
	pb.pos = p.at + p.launch * ((1.0 - fade) / k)
	p.velocity = p.launch * fade
	pb.heading = wrapf(p.facing + p.turning * minf(t, CARRY_MAX), -PI, PI)


## **A mirror's frame**: carry what the host sent, push this cell out of it, and
## sense it. Nothing here steps a body, seeds one or eats one -- all of that is
## the host's, and arrives.
func _step_mirror(delta: float) -> void:
	var ahead := minf(_snap_age, CARRY_MAX)
	for i in _water:
		var b := _cells[i]
		if b.seeded:
			b.pos = _snap_at[i] + _forward(b.heading) * (b.speed * ahead)
	var pb := _cells[PERSON_SLOT]
	if pb.person != null:
		_carry_person(pb, ahead)
	_snap_age += delta
	if not in_water:
		return
	for b in _cells:
		if b.seeded:
			_push_local(b, false)
	_step_organs(delta)


# ---------------------------------------------------------------------------
# Seeding. §1.3: a floor that never moves, a middle that tracks you, and a
# ceiling you can reach.
# ---------------------------------------------------------------------------

func _seed(index: int) -> void:
	var b := _cells[index]
	var angle := randf_range(-PI, PI)
	var distance := randf_range(RING_MIN, RING_MAX)
	var origin := _cell.position if _cell != null else Vector2.ZERO
	_renew(b)

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
	var sensed := _sensed()
	if randf() < _drifter_share(sensed) or not _other_drifter(index):
		_seed_drifter(b)
	else:
		_seed_peer(b, _cell.radius if _cell != null else CellBody.BASE_RADIUS, sensed)

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


## **A fresh body in slot [param b]**: every clock, counter and state a seed
## resets, and a new serial -- the part of [method _seed] that is not where the
## body goes or what it is made of, drawing the heading and the stroke in the
## order `_seed` always has.
func _renew(b: Body) -> void:
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
	b.speed = 0.0
	b.tuned = -1
	if not b.order.is_empty():
		b.order = []
	_serial += 1
	b.serial = _serial
	_changes += 1


## **Seeding for one player** (shared-pond.md §1.4): [method _seed] with that
## player substituted -- the ring round them, their radius for the peer band and
## their senses for how much of it can bite -- and one constraint more: the
## point is at least RING_MIN from every anchor, the visibility bound RING_MIN
## has always been, so a body is never born inside either player's view.
## [param drifter] is the floor insisting, whatever the coin says.
##
## The drifter floor is asked of that player's own disc rather than of the whole
## field: a drifter in the other player's water is no meal for this one.
func _seed_for(index: int, anchor: int, drifter: bool = false) -> void:
	var b := _cells[index]
	var angle := randf_range(-PI, PI)
	var distance := randf_range(RING_MIN, RING_MAX)
	var origin := _anchor_pos(anchor)
	_renew(b)
	b.tuned = anchor
	_stamp += 1
	_seeded_for[anchor] = _stamp
	var sensed := _anchor_sensed(anchor)
	if drifter or randf() < _drifter_share(sensed) or not _disc_drifter(index, origin):
		_seed_drifter(b)
	else:
		_seed_peer(b, _anchor_radius(anchor), sensed)
	b.pos = _clear_point(origin, angle, distance)
	b.aim = b.pos
	b.flee_from = b.pos
	b.seeded = true


## A point [param distance] from [param origin] at least RING_MIN from every
## anchor: the drawn [param angle] if it is clear, then up to
## [constant SEED_TRIES] draws in all, then the ring point straight away from
## the nearest other anchor -- which is always clear, because it is farther from
## that anchor than from its own.
func _clear_point(origin: Vector2, angle: float, distance: float) -> Vector2:
	var point := origin + Vector2(cos(angle), sin(angle)) * distance
	for attempt in range(1, SEED_TRIES):
		if _clear_of_anchors(point):
			return point
		angle = randf_range(-PI, PI)
		point = origin + Vector2(cos(angle), sin(angle)) * distance
	if _clear_of_anchors(point):
		return point
	var away := Vector2.ZERO
	var nearest := INF
	_find_anchors()
	for at in _anchor_at:
		var d := origin.distance_squared_to(at)
		if d > 0.0001 and d < nearest:
			nearest = d
			away = origin - at
	if away == Vector2.ZERO:
		return point
	return origin + away.normalized() * distance


func _clear_of_anchors(point: Vector2) -> bool:
	var ring := RING_MIN * RING_MIN
	if anchored and _cell != null and point.distance_squared_to(_cell.position) < ring:
		return false
	var pb := _cells[PERSON_SLOT] if _cells.size() > PERSON_SLOT else null
	return pb == null or pb.person == null or point.distance_squared_to(pb.pos) >= ring


## Is there a drifter other than [param index] in the disc round [param origin].
func _disc_drifter(index: int, origin: Vector2) -> bool:
	var reach := CULL * CULL
	for i in _water:
		var b := _cells[i]
		if i != index and b.seeded and b.drifter \
				and b.pos.distance_squared_to(origin) <= reach:
			return true
	return false


func _anchor_pos(anchor: int) -> Vector2:
	return _cells[PERSON_SLOT].pos if anchor == Anchor.PERSON else _cell.position


func _anchor_radius(anchor: int) -> float:
	return _cells[PERSON_SLOT].radius if anchor == Anchor.PERSON else _cell.radius


## [method _sensed], for either player: the person's is read off the tiers they
## wear, exactly as this cell's is read off its genome.
func _anchor_sensed(anchor: int) -> float:
	if anchor != Anchor.PERSON:
		return _sensed()
	var tiers := _cells[PERSON_SLOT].genome
	var sum := 0.0
	for gene: StringName in SENSE_GENES:
		sum += float(Genome.tier_of(tiers, gene))
	return clampf(sum / SENSE_FULL, 0.0, 1.0)


## **The daughter you did not take, left in the water as an ordinary body.**
## lifecycle.md §4.2: she is your size, your mouth and your armour -- the one
## cell in the water that is an exact match for you -- and under edibility.md
## that is a fight decided by facing and nerve rather than by size. It costs one
## seeded body and no new system, and it answers "what happened to the other
## one" without a word.
##
## [param bearing] is body-relative, and it is the side she was drawn on, so she
## is where the player last saw her.
##
## **In a pond she takes a free slot** rather than slot 1 (shared-pond.md
## §1.5), which may be anybody's: nothing is reseeded at a birth in a pond, and
## the body in slot 1 is somebody's cell in somebody's water.
func put_sister(bearing: float, distance: float, body_radius: float,
		tiers: Dictionary) -> void:
	if _cell == null or _cells.size() < 2:
		return
	if _pond:
		var side := _cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)
		place_sister(_cell.position + side * distance, _angle_of(side, 0.0),
			body_radius, tiers)
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


## A body in the peer band round a player of radius [param mine], whose senses
## read [param sensed] (see [method _sensed]).
func _seed_peer(b: Body, mine: float, sensed: float) -> void:
	b.drifter = false
	# The floor of the drifter band is a guard, not a rule: the player only ever
	# grows, so in practice this clamp is the ceiling doing the work.
	b.radius = clampf(mine * (1.0 + randf_range(-PEER_SPREAD, PEER_SPREAD)),
		DRIFTER_MIN, ARRIVAL_RADIUS_MAX)
	b.genome = _draw_genome(b.radius, sensed)


## A real genome: a mouth, then as many other organs as the body has slots for.
## Every cell in the water is full to its own capacity, which is what makes
## §1's "the starting cell is already full" a property of cells rather than a
## special case for the player.
func _draw_genome(body_radius: float, sensed: float) -> Dictionary:
	var tiers := {&"cytostome": _draw_tier(sensed)}
	var capacity := CellBody.slots_for(body_radius)
	var pool: Array[StringName] = DRIFTER_GENES.duplicate()
	while tiers.size() < capacity and not pool.is_empty():
		var gene := _draw_gene(pool)
		pool.erase(gene)
		tiers[gene] = _draw_tier(sensed)
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


func _draw_tier(sensed: float) -> int:
	var total := 0.0
	for tier in TIER_WEIGHTS.size():
		total += _tier_weight(tier, sensed)
	var roll := randf() * maxf(total, 0.001)
	for tier in TIER_WEIGHTS.size():
		roll -= _tier_weight(tier, sensed)
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
##
## [param sensed] is the player the water is being made for: [method _sensed]
## for this cell, and the same sum over the person's tiers in a pond.
func _drifter_share(sensed: float) -> float:
	return lerpf(BLIND_DRIFTER_SHARE, DRIFTER_SHARE, sensed)


## How likely one cytostome tier is inside the peer band. The rare peer a blind
## cell meets carries the poorest mouth in the game.
func _tier_weight(tier: int, sensed: float) -> float:
	var i := clampi(tier, 0, TIER_WEIGHTS.size() - 1)
	return lerpf(BLIND_TIER_WEIGHTS[i], TIER_WEIGHTS[i], sensed)


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
##
## **The other player is the player too** (shared-pond.md §1.2): a run at them is
## scaled to their own realised speed, by the same definition.
func _reference_speed(b: Body) -> float:
	if b.target == TARGET_PLAYER:
		return _cell.swim_speed()
	var prey := _target_body(b)
	if prey != null and prey.person != null:
		return prey.person.swim_speed
	var mine := _own_speed(b)
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
##
## **A player out of the water is not** (shared-pond.md §1.5), and neither is the
## one on this device: a run at a dividing or dead player ends on the next frame,
## so nothing is left committed to a body that cannot be reached.
func _target_present(index: int, b: Body) -> bool:
	if b.target == TARGET_PLAYER:
		return in_water
	var prey := _target_body(b)
	if prey == null or b.target == index:
		return false
	return prey.person == null or prey.seeded


## Does it still fit in this mouth. Separate from [method _target_present]
## because the two deserve different answers: a prey that has gone is a chase
## with nothing in it, and a prey that has outgrown the mouth is a chase that is
## about to be given up on -- over OUTGROWN_GRACE, not instantly.
func _target_edible(b: Body) -> bool:
	var gape := _gape(b)
	if b.target == TARGET_PLAYER:
		return _worth_committing_to(b, gape, _cell.swallow_radius(), _cell.wound)
	var prey := _target_body(b)
	if prey == null:
		return false
	# The other player's body as a mouth measures it -- armoured, as this one's
	# is; a water cell's is its bare radius (shared-pond.md §0.5).
	return _worth_committing_to(b, gape,
		prey.radius if prey.person == null else prey.radius * prey.person.armour,
		prey.wound)


## Same convention as the cell: radians clockwise from world north, front is the
## top of the screen.
func _forward(heading: float) -> Vector2:
	return Vector2(sin(heading), -cos(heading))


func _angle_of(v: Vector2, fallback: float) -> float:
	if v.length_squared() <= 0.0:
		return fallback
	return atan2(v.x, -v.y)
