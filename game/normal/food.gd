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
## The cell reads two scalars out of this field with no bearing in them: its
## **taste level**, which sets the green band wash, and **dread**. A third, the
## water's **total scent concentration**, set the beat rate until the owner took
## food off the beat on 2026-09-29 (metabolism.gd): food is found with the
## senses. [member concentration] is still worked out, as a fact about the water
## the dev tools dump and diff, and nothing in a run reads it.
##
## This node computes; it does not post. [member taste_level] and [member
## dread_level] are read once a frame by whoever owns the run, which is the only
## place allowed to talk to the signal bus; discrete events are signals. A
## per-frame signal here would allocate a dictionary sixty times a second to say
## the same thing.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")
const Genome := preload("res://game/normal/genome.gd")
## **Every gene there is, and the stats it buys** (docs/design/gene-catalogue.md):
## the water's draws, its senses and every body's numbers are read through these,
## by key and by stat, and this file names no gene to work them out.
const Catalogue := preload("res://game/genes/catalogue.gd")
const Stats := preload("res://game/genes/stats.gd")
## **Only for [method Cilia.mouth_touches]**, which is where the lip bow's
## geometry is defined and therefore where the water has to ask whether a mouth
## is actually on something. Nothing else in that file is read from here and
## nothing here draws. The preload chain is cilia -> genome -> cell, so this
## adds no cycle.
const Cilia := preload("res://game/vision/cilia.gd")
## **The drop**, this water's environment file (docs/design/ocean.md §13), and
## two of the generic mechanics it is built on that this file asks directly. A
## run in the drop holds one [Drop]; today's water holds none.
const Drop := preload("res://game/normal/drop.gd")
const Replenish := preload("res://game/mechanics/replenish.gd")
## **Lineage** (docs/design/lineage.md §4): a body's record of descent, which
## the drop keeps on every body and draws nowhere.
const Descent := preload("res://game/mechanics/descent.gd")
## The arithmetic of a tank, which every body in the drop runs as the player's
## node does (§5.2). Its static functions only: this file never makes the node.
const Metabolism := preload("res://game/normal/metabolism.gd")
## **Rules a body carries** (docs/design/behaviour.md §10): the generic mechanic
## a water cell decides by, which knows inputs, outputs, kinds and tests and
## nothing of cells or genes. Which name is which organ is wired here.
const Rulebook := preload("res://game/mechanics/rulebook.gd")
## A fan of rays: how a water cell's beam is spread, as the run spreads yours.
const RayFan := preload("res://game/mechanics/ray_fan.gd")
## The file a drop is kept in, for the layout of pack 3's entries in it
## ([method drop_state]). It preloads nothing of this file's, so no cycle.
const DropSave := preload("res://game/normal/drop_save.gd")
## **Doses** (docs/design/dna-slots.md §6): how a load wears and what each kind
## is. This file decides where a dose is delivered and when a body dies of one;
## the arithmetic is doses.gd's, and the numbers cell.gd's.
const Doses := preload("res://game/mechanics/doses.gd")

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
## The membrane closes and you are gone. [param bearing] is where it came from;
## [member died_of] and [member died_by], written just before this goes, are
## how and by whose mouth.
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
## **A dose went into this cell** (docs/design/dna-slots.md §7): [param stacks] of
## doses.gd's [param kind], felt from [param bearing] -- a mouth's venom where it
## bit you, a sting or a poison where your own bite landed -- or swallowed, when
## [param meal] is true: the poison of what you just ate. Said **before** the
## bite's `bitten` or the meal's `eaten`, in the same frame, so the run can tint
## the sensation the dose arrived with. Nothing in the water rides on it.
##
## (`veneneux`'s `stung` -- swallowed, and spat out alive -- is gone with the
## spitting: a poisonous body is eaten, as anyone is, and its swallower takes the
## dose. `Contact.STUNG` keeps its number and is never sent.)
signal dosed(bearing: float, kind: int, stacks: float, meal: bool)
## **This cell's toxin went into something** (§10.1, item 12): [param how] is
## [constant FIRED_VENOM] -- its venom rode in on its bite -- [constant
## FIRED_STING], a venom on a side stung a mouth biting there, or [constant
## FIRED_POISON], its poison was taken by a biter or a swallower. For the view's
## flare and nothing else.
signal toxin_fired(how: int)
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
## `pond.gd` sends it to the other player as CONTACT. A `KILLED` is always
## followed at once by [signal person_died], which carries the cause. On a
## dedicated host, which has two people, [member touched_slot] says which.
signal person_touched(what: int, at: Vector2, level: float, by: int, gene: StringName)
## **The other player died in this water**: swallowed, chewed apart, or
## poisoned by what it bit or swallowed -- a [enum Cause], by a [enum By], at
## the place it was. Emitted after [signal person_touched] has said `KILLED` and
## after the person has left their slot, so a listener that puts them straight
## back finds it empty -- and after [member touched_slot] names it.
signal person_died(cause: int, by: int, at: Vector2)
## **The cell met the edge of the drop** (docs/design/ocean.md §3.1): held at
## the meniscus and knocked, at the rim's bearing, as grit knocks it -- the run
## posts it as the same `hit`. [param at] is the rim's nearest point, for the
## view only, and the same contract as [signal eaten]'s: it stops at the run.
## Only a run in the drop emits it.
signal shored(bearing: float, strength: float, at: Vector2)
## **The cell swallowed something that was not alive**: a floc (§7.3). Food,
## worth [param nutrition] of one whole meal, and nothing else -- no growth and
## no gene, which is why it is not [signal eaten]. [param at] is for the view
## only. Only a run in the drop emits it.
signal grazed(nutrition: float, at: Vector2)

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
## **The most people one field holds**: a dedicated host's two guests
## (`game/server/`), in [constant PERSON_SLOT] and the slot after it. A phone's
## pond and every mirror hold one. The wire never carries a slot past
## [constant PERSON_SLOT]: each guest is sent the other one *as* slot 68, the
## place a phone host puts itself, so a guest cannot tell the two hosts apart.
const GUESTS_MAX := 2
## How far past a snapshot the mirror carries anything, in seconds: the view's
## own `PEER_REACH`, for the same reason. A body carried further than this on
## an old heading is a guess, and the mirror holds rather than guesses.
const CARRY_MAX := 0.2
## **The send set** (§2): every body whose surface lies within this of the
## guest -- the reach of a tier-3 `ampulla`, measured to the surface exactly as
## [method _cast_ping] measures it. Scent, dread, beams and the frame all lie
## inside it, so nothing outside it can change a sense.
const SEND_REACH := 1900.0
## **...and no more than this many of them, nearest first** (ocean.md §10.4),
## with every body hunting the guest in whatever the count: 58 lie within
## [constant SEND_REACH] on average at the drop's density, and a snapshot of
## sixty and the person is one datagram. wire.gd's SEND_MAX, which the probe
## holds to this.
const SEND_MAX := 60
## How far clear of a player a sister is put, surface to surface, when the
## place she was meant for is on them: pond.gd's own ARRIVAL_CLEAR.
const SISTER_CLEAR := 20.0
## How many angles [method _seed_for] draws before it gives up looking for a
## point clear of every anchor and takes the one straight away from the other.
const SEED_TRIES := 8
## Genomes the mirror remembers by version before it forgets the oldest: four
## pond's worth, which is more than the send set can reference at once.
const BOOK_MAX := 4 * POND_SLOTS

## What happened to a person, on [signal person_touched] and into
## [method hear_contact]. The numbers are the wire's (shared-pond.md §2's
## CONTACT), so they are written out rather than left to count.
## `GRAZED` is a floc swallowed, in the drop (ocean.md §7.3, §10.4): food, and
## no growth and no gene, so it is never a meal to the referee.
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
enum Contact { WAKED = 1, BITTEN = 2, STUNG = 3, DARTED = 4, ATE = 5, KILLED = 6,
	GRAZED = 7 }
## How a person died, on [signal person_died]. `POISONED` is a dose: the harm a
## venom or a poison left in it made its wound whole (docs/design/dna-slots.md
## §6.2), which §2's three-cause DIED did not name.
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
enum Cause { SWALLOWED = 1, CHEWED = 2, STARVED = 3, POISONED = 4 }
## Whose mouth it was.
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
enum By { WATER = 1, FRIEND = 2 }
## The anchors a pond can have (§1.4): this device's own cell and the person --
## and on a dedicated host, which has no cell, the person in each of its slots:
## `PERSON + k` is the person in `PERSON_SLOT + k`.
enum Anchor { LOCAL = 0, PERSON = 1 }

## **Whether a water mouth swallows a player it is on** (rows 15 and 5): from a
## run at them ([param committed]), or on contact alone where [param on_contact]
## -- the drop's rule -- and only a body its [param gape] takes, [param size]
## being theirs as a mouth measures it, `pellicle` and all.
static func swallows_player(committed: bool, on_contact: bool, size: float,
		gape: float) -> bool:
	return (committed or on_contact) and size < gape


## **How big a body of [param radius] is to a mouth** (row 5): its radius times
## the [param armour] its `pellicle` gives it -- its `armor` stat -- where
## [param armoured]; its bare radius otherwise.
static func armoured_size(radius: float, armour: float, armoured: bool) -> float:
	return radius * armour if armoured else radius


## One body in a snapshot, as [method pond_entries] builds it and
## [method apply_pond] reads it: an Array indexed by these. `VELOCITY` and
## `TURNING` are the person's alone and read zero for a water cell. `ID` is the
## body's id on the wire (ocean.md §10.4): in the drop its own, which it keeps
## for its life; in today's water its serial, which is as unique and as never
## reused; and the person's is [constant PERSON_ID].
enum Entry { ID, MEALS, FLAGS, AT, HEADING, RADIUS, WOUND, SPEED,
	VELOCITY, TURNING }
## **Past the wire's fields, the host's own slot for the body** -- what
## `pond.gd` finds its genome by. Never written; -1 for the person.
const ENTRY_SLOT := Entry.TURNING + 1
## The person's id in a snapshot. No water body has it: the drop numbers its
## bodies from 1, and today's water its serials.
const PERSON_ID := 0
## [enum Entry] `FLAGS`, bit by bit -- the wire's POND flags (§2).
const FLAG_STALKING := 1
const FLAG_PERSON := 2
const FLAG_IN_WATER := 4
## **The body carries a load past `DOSE_GONE`** (docs/design/dna-slots.md §14.2):
## harm, paralysis -- or, for the third, is asleep. A guest draws the doses of
## the water and of the other player from these: a mirror is never told a body's
## stacks, only that it carries some. Protocol 7; phase 1 writes harm's.
const FLAG_HARMED := 8
const FLAG_PARALYSED := 16
const FLAG_ASLEEP := 32
## How many stacks a mirrored body flagged with a load is drawn carrying, felt:
## one stack's worth on a born cell -- enough to be seen, and nothing a guest
## could read a number off.
const MIRROR_SHOWN := 1.0

# --- What a body's toxins deliver (docs/design/dna-slots.md §7) -----------------
## A body's toxins, as [method toxins_of] reads them off what it wears: records
## of [constant TOX_STRIDE] floats, `[how, kind, stacks, bearing]` -- how it is
## delivered, doses.gd's kind, how many stacks, and for a sting the
## body-relative bearing it guards. Read once whenever a body changes, never at
## a bite.
##
## [constant HOW_BITE]: venom at the front, into whatever its bite lands on.
## [constant HOW_STING]: venom on a side or the stern, into a mouth biting
## within `VENOM_ARC_DEG / 2` of its bearing. [constant HOW_POISON]: poison,
## into whatever bites it, anywhere. [constant HOW_SWALLOW]: poison, into
## whatever swallows it.
const HOW_BITE := 0
const HOW_STING := 1
const HOW_POISON := 2
const HOW_SWALLOW := 3
const TOX_STRIDE := 4
## [signal toxin_fired]'s three: this cell's venom on its bite, its sting, its
## poison taken.
const FIRED_VENOM := 0
const FIRED_STING := 1
const FIRED_POISON := 2

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

# **What a seeded cell is made of.** §3.4: a genome is fixed when it is seeded
# and full vision draws it, so informed foraging is possible -- a roll on eating
# could not be seen in advance. **Each gene's place in the water is its own**
# (gene-catalogue.md §9): how often a draw takes it, the catalogue's `weight()`,
# and whether a drifter may be made of it, its `drifters()` -- everything a
# drifter can be, and therefore everything the player can ever eat their way
# into. The mouth is on no such list, and a retired gene neither: those lists
# are the only places a gene is *produced*, and every table that *consumes* a
# gene name still answers for one it has never heard of, so an old map that
# names one loads and draws rather than crashing.

## How likely each tier is in the peer band, weighted so most cells are
## mediocre and a few are terrifying. Index 0 is unused: every peer has at least
## tier 1 of whatever it carries.
##
## **A divergence, flagged.** §9.6 leaves "the cytostome weights inside the peer
## band" open and §1.3 reads as though the genes' weights cover it -- but a
## weight is per *gene*, not per *tier*, and says nothing about how good a
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
# No new lever. A drifter has no mouth and a body with none bites for a hard
# zero, so a drifter is *literally* defenceless food; the two numbers that decide
# how much of the water is one are the two §9.6 already named.
#
# **What counts as sight** is the genes tagged `sense` (the catalogue's
# `tagged()`): the ones that answer *where is something*, which the run's free
# sense is drawn from too. Nothing else counts: the ones left out sharpen or
# steady what these find.

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
## reads what is inside its own nose's reach (the stat `smell_range`), which is a
## different and much larger radius.
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
## (the genes tagged `gift`), which is what moved it down from 1400. The
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
#   Feeding it the real angle would make dread swing as the player turns, and
#   fear is not a compass.
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

# --- The beam (`ocellus`, beam-levels.md) -----------------------------------

## The widest step a sweeping ray takes between two casts inside the arc it
## crossed this frame: 2 degrees, in radians. At a level-10 sweep a ray moves
## 3.9 degrees a frame at 60 fps and 7.8 at 30, so this is two casts a frame on
## a fast phone and four on a slow one, and the slow one misses nothing extra.
const BEAM_SUBSTEP := 0.034906585
## A hair of angle added to the fan's reach before a body is skipped for being
## outside it, so a body exactly at the edge is still cast at.
const BEAM_SLACK := 0.001

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
##
## **Counted on the path the wave travels, not on the range** (issue #45): see
## [method ping_level]. An echo's path is out and back, so the fade is exactly
## what it was; [constant PING_ATTENUATION] takes the water's share on top of
## it, and at tier 1 that 0.30 lands at 0.29 and the 0.66 at 0.63.
const PING_FALLOFF := 0.6
## **What the water itself takes out of the wave, per unit of path.**
## Beer-Lambert: a wave crossing an absorbing medium keeps `exp(-k * path)` of
## itself, and the path is the distance the wave actually covers -- out and
## back for an echo, one way for a friend's call. It multiplies into
## [constant PING_FALLOFF]'s fade and into every occluder's bite rather than
## replacing either, so each of the three keeps meaning one thing: how far the
## wave went, what the water took, and what was in the way.
##
## **Gentle, by the owner's bound, and measured against it**: no echo off a body
## at the distances this water keeps them, 900 to 1400 units out, may come home
## more than 10% fainter than it did. 1400 is a 2800-unit round trip and
## `exp(-3.75e-5 * 2800)` is 0.900, so this is the bound and not a guess near
## it; the edge of tier-3 reach keeps 0.867. **Measured** over 300 s of the
## sighted forager at six seeds and every tier, 1,089 echoes heard: each kept
## 0.922 to 0.998 of its old level, and not one left or joined the heard set --
## the echo that lands is nearer than the seeding band, median 426 to 493 units.
## ping-as-outline.md §2.2 has the tables, a friend's call by distance included.
const PING_ATTENUATION := 3.75e-5
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

# --- How a hunter in the drop eats (docs/design/ocean.md §5.4) ----------------
# **Behaviour, not a rule of the body**: the hand-written state machine's own
# defaults, chosen so that a cell under the player's metabolism can live on what
# the drop holds, and each one constant. Pack 3's blocks replace all four. None
# of them is read in today's water.

## A fed hunter rests; it hunts once its hunger reaches this.
const HUNT_AT := 0.3
## After a meal it digests this long, whatever its hunger says.
const REST_MEAL := 5.0
## **A miss costs a moment, whoever was missed**: this long where it is, and
## then its hunger decides again -- after a run at a cell, at you, or one a
## dart broke. Today's flight of up to twenty seconds at a lunge is gone: paid
## for at a hunter's own speed it would cost most of a tank.
const REST_MISS := 5.0
## It turns to face what it found at its own cirrus's rate before the run
## begins, and gives up after this long: a half turn at the slowest cirrus is
## 6.5 s.
const ORIENT_SECONDS := 8.0
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
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
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
	## `{gene: tier}`, fixed at seeding and grown by eating. Never null. **Written
	## whole, what it buys is read again** ([method derive], the `stat_` fields
	## below); whoever edits it in place calls that itself.
	var genome := {}:
		set(value):
			genome = value
			derive()
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
	## [constant CellBody.MEND_SECONDS], exactly as the player's does -- except
	## while it carries harm (docs/design/dna-slots.md §6.2).
	var wound := 0.0
	## **Its loads**, stacks of each of doses.gd's kinds -- the venom and poison
	## it took, wearing off -- and the body whose stacks it took last, a slot or
	## [constant TARGET_PLAYER] for the cell on this device: who killed it, if a
	## dose does (§6.2). Every body, a person's included.
	var loads := Doses.none()
	var dosed_by := -1
	## **What its own toxins deliver** ([method FoodField.toxins_of]), and what it
	## was read off: the genome and the worn order, hashed. Read again only when
	## that changes -- whichever door changed it, a meal, a seed or a tool -- and
	## never at a bite that finds it unchanged. Empty for a body with no toxin.
	var toxins := PackedFloat64Array()
	var toxins_key := 0
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

	# --- The drop only (docs/design/ocean.md §14.1). Today's water never reads
	# or writes any of these, so a body there is exactly the body it was.
	## Unique for the life of the drop and never reused: pack 2's lineage.
	var id := 0
	## **The tank**, 0 fed .. 1 empty, run as the player's is (§5.2); and the
	## seconds spent empty, against metabolism.gd's STARVE_GRACE.
	var hunger := 0.0
	var starve := 0.0
	## Seconds of rest spent doing something since the tank last paid: strokes
	## held against the drag, radians steered, a dash.
	var effort := 0.0
	## Seconds since it was made.
	var age := 0.0
	## **The drop's clock when this body was last stepped**: a body stepped at a
	## lower rate is owed the time since (§4.3).
	var last_t := 0.0
	## The frame the LOD found it near a player, and the frame it was last
	## stepped; and whether this step falls on its tick, the one moment a mouth
	## decides anything, near or far.
	var near_frame := -1
	var stepped := -1
	var look := false
	## **Not alive: a floc** of detritus (§7). No genome, no mouth, never moves.
	## A floc is also [member drifter], so every pass that asks for a mouth
	## passes it over.
	var inert := false
	## How far a floc has settled into the focal plane, 0..1: its scent, its
	## drawing and its edibility ramp with it; and the seconds left before it
	## begins to dissolve.
	var settle := 1.0
	var life := 0.0
	## `trichocyst`: seconds until its dart can fire again. `myoneme`: the burst
	## left from its last dash, and the seconds until the next one.
	var dart_clock := 0.0
	var dash_v := 0.0
	var dash_clock := 0.0
	## Turning to face what it found, before the run begins (§5.4); hungry and
	## finding nothing, swimming to look.
	var orienting := false
	var searching := false
	# Read once, whenever the genome or the radius changes (_refresh_body).
	## How far its own senses find prey -- the reach of its nose, radar, beam or
	## palp -- and a floc, which a radar and an eyespot do not see (§7.5); the
	## eyespot's reach, for bodies big enough to cast a shadow.
	var notice := 0.0
	var notice_floc := 0.0
	var see_big := 0.0
	## `pellicle`'s multiple on its radius, as a mouth measures it (row 5).
	var armour := 1.0
	## Where its `trichocyst` is worn, as a body-relative bearing.
	var dart_bearing := 0.0
	## The tank's terms: `vacuole`'s store, `plastid`'s light, all it takes in
	## without eating (light, and what a body with no `cytostome` absorbs),
	## `crista`'s burn and the upkeep of what it wears.
	var reserve := 1.0
	var sun := 0.0
	var income := 0.0
	var burn := 1.0
	var upkeep := 1.0
	## Its own tail's speed: what it cruises at, and searches at (row 14).
	var cruise := 0.0
	## **Its rules** (docs/design/behaviour.md §6.4): a list (`rulebook.gd`'s
	## Behaviour) it shares with the family that carries it unchanged, or null
	## for the founders' -- drop.gd's FOUNDERS -- which a founder, a sister, a
	## posed body and a body from an old save carry without a copy.
	var brain: Variant = null
	# --- Lineage (docs/design/lineage.md §4): kept with the drop, drawn nowhere.
	# [member id] above, these three and [member dna] are a body's record and what
	# it passes on, written as it comes in by [method _spawn].
	## The id of the body it was born of; 0 for one the water made.
	var parent := 0
	## 1 for a body the water made; a daughter is her mother's and one.
	var generation := 1
	## The id of the founder its line began with -- its own, for a founder.
	var lineage := 0
	## **The DNA** (§3.2): what it writes by eating and what its daughters are
	## made of, `{gene: copies}`, beside [member genome], the body it was born
	## wearing. The two are equal for a body the water makes. **A meal in the
	## drop writes the DNA alone** ([method _grow]): the body is fixed at birth,
	## as yours is, and what it eats reaches its daughters ([method _divide]).
	var dna := {}
	## **The newborn grace** (§3.4): seconds left in which no mouth begins a run
	## at it -- [member newborn_grace] for every daughter, water or sister, and
	## none for a body the water makes. Not armour: a mouth it touches still
	## swallows it ([method _look_in_drop]).
	var grace := 0.0
	# --- Pack 3 (docs/design/behaviour.md §4): what a body on rules is doing.
	# Today's water and a drop with `rules` off never read any of these.
	## **The heading it steers for** (§4.2): set by a turn on a tick and held,
	## turned toward between ticks, until a later turn sets another or a rest
	## clears it. [member holding] says whether it holds one.
	var steer := 0.0
	var holding := false
	## What its rules claimed on its last tick, held until its next: a rest, a
	## swim, and a push's strength, 0 for none (§4.1).
	var resting := false
	var swimming := false
	var push := 0.0
	## **Its tail held still** (automation.md §5.2, §5.3), claimed on its last
	## tick and held until its next: by the flagellum's `hold`, or by a rest at
	## [method CellBody.hold_level]. Under [member tails_beat] a tail beats
	## unless this holds it.
	var tail_held := false
	## **The level its tail works at**: the worn copies of the organ that beats --
	## the best of any key of it, as its rules count it -- as its beam's level is its
	## copies (`_eye_of`). Made with its body ([method _refresh_body]).
	var tail_level := 0
	## **The random turn it holds**: the rule that drew it and the tick it last
	## fired on, -1 for none. While that rule keeps firing, the heading it drew
	## is kept: a run of falling smell is one tumble, not a spin (§4.2).
	var tumble := -1
	var tumble_tick := -1
	## **Stunned** (§4.3): seconds left resting with its rules unread, after a
	## dart.
	var stun := 0.0
	## **When it last ate**, on the drop's clock -- a cell, a floc or a player --
	## and -INF for a body that has not: its `fed` is the time since (§3.2).
	var ate_at := -INF
	## **A hit it has not yet felt on a tick** (§3.2): how hard, 0 for none, and
	## the world direction it came from -- a bite on its membrane, or a dart.
	var hit := 0.0
	var hit_from := 0.0
	## **Its own call** (`ampulla`, §3.2): when it calls next, on the drop's clock,
	## and every return of its own on its way home or ringing, as `[lands, at,
	## distance, size, rings until]` -- the place it came off, the distance its
	## time home gives and the size its ring gives.
	var call_at := 0.0
	var echoes: Array = []
	## **What its rules last read**: input name to `[tick, reports]`, the tick it
	## was last read on and what it reported -- what rising, falling and leading
	## are measured against (rulebook.gd's `choose`).
	var memory := {}
	## Its tail's own speed, without the push its `axoneme` now gives as a trigger
	## of its own (§4.5); its `cirrus`'s turn rate; its `axoneme`'s thrust at full
	## strength; and its `trichocyst`'s tier, 0 for none. Made with its body.
	var tail := 0.0
	var turn_rate := 0.0
	var thrust := 0.0
	var dart_tier := 0
	## **Its organs as its senses read them** (§4.4, §12.1): each at its tier on
	## the arc the default order puts it, made by [method _refresh_body] for a
	## body with a mouth in a drop of this field's own; null otherwise. And what
	## of the rulebook's vocabulary it has, as rulebook.gd's bits: what it wears
	## and what every body has (`Rulebook.worn`), a mask of the vocabulary's words.
	var eye: Observer = null
	var worn := PackedInt64Array()
	## **What its genome buys it, read when the genome is written**
	## (docs/design/gene-catalogue.md §15, as built 1a) and never on a tick: its
	## mouth's gape, as a multiple of its radius, and its bite; its armour; its
	## turn; its tail's realised speed ([method CellBody.speed_of]) and the level
	## that tail can be held still from; its dart -- tier, reach, cooldown and
	## stun -- and its dash -- tier, burst and price. **Every body has them** -- a
	## person's, a floc's, a replay's and today's water's -- which [member tail]
	## and the rest above, made only by [method _refresh_body], are not.
	var stat_gape := 0.0
	var stat_bite := 0.0
	var stat_armor := 1.0
	var stat_turn := 0.0
	var stat_speed := 0.0
	var stat_hold := 0
	var stat_dart_tier := 0
	var stat_dart_range := 0.0
	var stat_dart_cooldown := 0.0
	var stat_dart_stun := 0.0
	var stat_dash_tier := 0
	var stat_dash_speed := 0.0
	var stat_dash_cost := 0.0

	func _init() -> void:
		derive()

	## **Reads what [member genome] buys into the `stat_` fields**: by its setter
	## whenever it is written whole, and by whoever edits it in place.
	func derive() -> void:
		var g := genome
		stat_gape = Stats.of(g, &"gape")
		stat_bite = Stats.of(g, &"bite")
		stat_armor = Stats.of(g, &"armor")
		stat_turn = Stats.of(g, &"turn_rate")
		stat_speed = CellBody.speed_of(g)
		stat_hold = CellBody.hold_level(g)
		# The dart that fires does all of it -- its arc, its reach, its rest and its
		# stun -- the first in slot order, where it wears several (stats.gd's
		# `seated`; gene-catalogue.md §5.2).
		var layout: Array = seats() if Stats.seats_decide(g) else []
		stat_dart_tier = Stats.seated_tier(layout, g, &"dart_range")
		stat_dart_range = Stats.seated(layout, g, &"dart_range")
		stat_dart_cooldown = Stats.seated(layout, g, &"dart_cooldown")
		stat_dart_stun = CellBody.dart_stun(g, layout) if stat_dart_tier > 0 \
			else CellBody.dart_stun(g)
		stat_dash_tier = Stats.tier(g, &"dash_speed")
		stat_dash_speed = Stats.of(g, &"dash_speed")
		stat_dash_cost = Stats.of(g, &"dash_cost")

	## **The slots it wears its organs in**: a person's worn order, as they sent it,
	## or the default order a water cell is drawn in (cilia.gd) -- where a mechanic
	## with a place finds the organ it acts from (stats.gd's `SEATED`).
	func seats() -> Array:
		return order if not order.is_empty() else Cilia.default_order(genome)


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
	## Its own [constant FIRST_DELAY], granted at every arrival.
	var first_hunt := 0.0
	## Out of the water is a player dividing: still an anchor, and nothing in
	## the water can see it, touch it or chase it.
	var in_water := true
	## Their phone has gone quiet. Nothing in the field reads it -- a quiet
	## body still drifts, bites and can be eaten (§1.8) -- it is kept for the
	## view, which fades their presence.
	var quiet := false
	## **Which slot their body is in**: [constant PERSON_SLOT] on a phone's
	## pond and in every mirror; a dedicated host's second guest is in the one
	## after it. Every rule that reaches for a person's body reaches through
	## this, so a rule is written once for however many people there are.
	var slot := PERSON_SLOT


## **Whoever is sensing** (docs/design/behaviour.md §12.1): the player on this
## device or any body in the water, by its place, heading, size, mouth and the
## arcs its organs are worn on. **Every sense in this file is one function of
## one of these** and of the bodies its organ reaches -- the nose, the beam, the
## shadow, the touch and the call -- so the player's membrane and a water cell
## read the water by one arithmetic, and neither is handed anything the other
## is not (§3.2: no magic). Plain data, refilled where it is used.
##
## What a sense finds comes back on it too, beside what it was asked with: a
## reading belongs to whoever took it.
class Observer:
	var pos := Vector2.ZERO
	## Radians clockwise from world north, and the two directions it makes --
	## built exactly as `cell.gd`'s `forward()` and `starboard()` build theirs,
	## so a bearing from here is the cell's own `bearing_to`, to the bit.
	var heading := 0.0
	var forward := Vector2(0.0, -1.0)
	var starboard := Vector2(1.0, 0.0)
	var radius := 0.0
	## How wide its mouth opens: what its nose weighs a body by.
	var gape := 0.0
	## Its own body as a mouth measures it, its armour and its wound: what the
	## player's dread is felt against, and nothing else reads them.
	var swallow := 0.0
	var armour := 1.0
	var wound := 0.0
	## `chemocyte`: how far the nose reaches and the arc it is worn on.
	var smell_range := 0.0
	var smell_bearing := 0.0
	## `palp`.
	var touch_range := 0.0
	## `stigma`: whether it wears one. The player's shadow is summed whatever it
	## wears, and its membrane is gated downstream; a water cell's eyespot reads
	## only when it is worn.
	var eyespot := false
	## `ocellus`: each ray's bearing, the arc a sweeping one crossed, how far the
	## rays reach, and where the fan points and how far it spreads.
	var beam_range := 0.0
	var beam_bearings := PackedFloat32Array()
	var beam_arcs := PackedFloat32Array()
	var beam_fan_mid := 0.0
	var beam_fan_half := -1.0
	## `ampulla`: how far a call carries, where on the skin it leaves, how much
	## of it a body in the way lets through, and the organ's tier -- and, for a
	## water cell's eye, the seconds between its calls, read as yours are: by
	## the organ it wears, at its copies (`cell.gd`'s `ping_period`).
	var ping_range := 0.0
	var ping_bearing := 0.0
	var ping_through := 0.0
	var ping_tier := 0
	var ping_period := 0.0
	## Its own slot, which none of its senses ever reports; -1 for the player on
	## this device, who is in no slot of the water's.
	var slot := -1
	# --- What [method _feel] found.
	## The nose's reading, 0..1, and the scent of everything edible it summed on
	## the way (the player's `concentration`) -- of what lay inside its reach
	## alone, when the nose was asked alone.
	var smell := 0.0
	var scent := 0.0
	## Light blocked, summed, and the direction it is blocked from.
	var shade := 0.0
	var shade_pull := Vector2.ZERO
	## The player's dread, and the worst threat in it (§3.4: no water cell
	## feels either).
	var dread := 0.0
	var worst := 0.0
	# --- What [method _touch_of] found.
	var touched := false
	var touch := 0.0
	var touch_bearing := 0.0

	## Puts it at [param at], facing [param toward].
	func face(at: Vector2, toward: float) -> void:
		pos = at
		heading = toward
		forward = Vector2(sin(toward), -cos(toward))
		starboard = Vector2(cos(toward), sin(toward))

	## The body-relative bearing of [param point]: `cell.gd`'s `bearing_to`, from
	## here.
	func bearing_to(point: Vector2) -> float:
		var offset := point - pos
		return atan2(offset.dot(starboard), offset.dot(forward))


## Total scent concentration at the cell, 0..1. What the water is like, and no
## longer what the beat is: it was the other half of metabolism's beat mapping
## until 2026-09-29. Kept because the dev tools dump and diff it with the rest
## of the field; nothing in a run reads it.
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
## **What arc each sweeping beam crossed this frame**, as `[low, high]` pairs of
## body-relative bearings index-matched to [member beam_bearings], written by
## the run; empty for a fan that does not sweep. A sweeping beam is tested
## across its whole arc (beam-levels.md §4.3), so a slow phone does not see
## less than a fast one.
var beam_arcs := PackedFloat32Array()
## **Where the fan points and how far either side it reaches**, written by the
## run, so a body nowhere near it is skipped before any ray is cast (§4.4).
## A negative half-width skips nothing, which is what a caller that never wrote
## it gets.
var beam_fan_mid := 0.0
var beam_fan_half := -1.0
## **How long a sweep's hit stays on screen**, the time the sweep takes to come
## back; 0 for a fan that does not sweep. Written by the run for the two views,
## which hold and fade each hit over it. The field itself holds nothing.
var beam_hold := 0.0
## Answered here, index-matched to [member beam_bearings]:
## `[bearing, distance, hit, body]` -- `distance` is the full reach when nothing
## was hit and `hit` is false then, and `body` is the slot of the body it
## stopped on, -1 for none. A sweeping beam's bearing is where in its arc it hit.
var beams: Array = []
## **Every body a beam touched this frame**, by slot, once each: the beam's
## experience is counted off this (beam-levels.md §2).
var beam_touched := PackedInt32Array()
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
## concentration] is what the *water* is like; this is what the *organ* picks
## up, and it is the only one of the two that reaches the membrane. The water's
## own richness used to reach it too, through the beat -- an eyeless, noseless
## cell beat faster in rich water -- until the owner took food off the beat on
## 2026-09-29. Food is found with the senses.
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
## the stat `ping_through` of the organ this cell calls with. 0 is a
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
## **The player's own call, as their instincts read it** (automation.md §4.1):
## every return of it, `[lands, at, distance, size, rings until]` on
## [member _call_t], kept from the moment it is cast until it rings out --
## exactly as a water cell keeps its own ([member Body.echoes]).
var player_calls: Array = []
## Seconds the player's organs have run, the clock [member player_calls] is
## kept on: the drop's own clock runs only in the drop.
var _call_t := 0.0
## **A bite the player has not yet felt on a tick of their instincts**
## (automation.md §4.1): how hard -- the hardest since the last tick -- and the
## world direction it came from. Taken at [method hear_contact]'s `BITTEN`, the
## one door a mouth's bite reaches the player by, from the water or a friend;
## let go by the instincts' tick. Never a mote, never the feel of the player's
## own bite.
var player_hit := 0.0
var player_hit_from := 0.0
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
## **What this cell's toxins deliver** -- its venom, where it is worn, and its
## poison -- as [method toxins_of] reads them off its worn body, written once a
## frame by the run where the dart's arc is (docs/design/dna-slots.md §7.2).
## Empty is a cell with no toxin.
var toxins := PackedFloat64Array()
## **Whether a venom on a side or the stern stings** (cell.gd's `VENOM_SIDES`),
## as this water reads its bodies' toxins: the design's switch, held here so a
## probe can turn it off on one field and see a side venom leave nothing
## (dna-slots.md §20.3 check 7). This cell's own follow it through
## [method toxins_of], which the run hands the same constant.
var venom_sides := CellBody.VENOM_SIDES
## **The body whose stacks this cell took last**: a slot, or -1. Who a death by
## a dose is the death of ([member died_to], [member died_by]); with
## [member _dosed_serial], the serial that slot held then, since a swallowed
## poisonous body's slot goes to another while its dose still works.
var _dosed_by := -1
var _dosed_serial := 0
var _dart_clock := 0.0
## The player's own mouth, reloading. Here and not on the cell for the same
## reason [member _dart_clock] is: the encounter lives in this file.
var _bite_clock := 0.0
## **The player on this device as an observer**, refilled by
## [method _player_eye] for every sense it takes (behaviour.md §12.1).
var _eye := Observer.new()
## **The player on this device as the water finds it**: its place, size and
## armour, as a body that is in no slot -- never in [member _cells] and never
## in the grid -- refilled before the water senses, and handed to a water
## cell's senses as [constant TARGET_PLAYER] (behaviour.md §12.1).
var _me := Body.new()

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
## **How this cell last died, and by whose mouth**: a [enum Cause] and a
## [enum By], written in the instant before [signal killed] is emitted, so a
## listener reads them inside its handler. [signal killed] carries only a
## bearing, because the membrane needs nothing more; the pond's DIED needs the
## rest (shared-pond.md §2), and only the field knows it. Nothing in single
## player reads them.
var died_of := 0
var died_by := 0
## **In the drop, the body that killed this cell**: the slot of what swallowed it
## or chewed it through, or of the one whose dose finished it, written beside
## [member died_of]; -1 from every arrival until then, and always in today's
## water, which never writes it. The replay's recorder reads it once, as it
## seals the ring, to say which body the killer was (ocean.md §11).
var died_to := -1
## **Which person the last [signal person_touched] or [signal person_died] was
## about** -- the slot, written in the instant before either is emitted, so a
## listener reads it inside its handler the way the run reads [member died_of].
## Always [constant PERSON_SLOT] on a phone's pond; a dedicated host has two
## people and asks. The signals themselves are unchanged.
var touched_slot := PERSON_SLOT
var _pond := false
## How many people this pond holds, in [constant PERSON_SLOT] onwards: one,
## except on a dedicated host ([method open_dedicated]).
var _guests := 1
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
## The mirror's genomes by body version -- the body's id and its meals
## ([method _book_key]) -- so one can arrive before or after its body.
var _book := {}
## **The mirror's bodies by their id on the wire** (ocean.md §10.4): the slot
## each came into this mirror in, kept while it is sent; and its flocs, by id,
## as `[slot, settle, life, told at]`; and the slots either left.
var _mirror_slots := {}
var _mirror_flocs := {}
var _mirror_free := PackedInt32Array()
## The mirror's own clock: how far a floc has settled since it was told.
var _mirror_t := 0.0
## The bodies a snapshot's send set, or the flocs in a guest's reach, are
## chosen from: one grid answer, never shared with another pass.
var _send_ids := PackedInt32Array()


## Seeds the water around [param cell]. Cell 0 is held back until the cell is
## actually moving, for the same reason mote 0 is.
##
## **Always a single-player water**, whatever came before: a pond or a mirror
## is closed by this, which is what [method leave_mirror] is. **And always
## today's water**: a run in the drop is made by [method setup_drop] instead,
## and one that comes here has left the drop for good.
func setup(cell: CellBody) -> void:
	_drop = null
	_cell = cell
	_pond = false
	_mirror = false
	_guests = 1
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
	beam_touched.clear()
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
	_dosed_by = -1
	_dosed_serial = 0


func _process(delta: float) -> void:
	if _cell == null:
		return
	if _mirror:
		_step_mirror(delta)
		return
	# **The drop's frame is its own** (docs/design/ocean.md §4), chosen once for
	# the run by [method setup_drop]: nothing below this line runs in it.
	if _drop != null:
		_process_drop(delta)
		return

	# The drift path does not exist until the cell drifts. Placing the first
	# body along the real velocity vector is what puts it where a first nose or
	# ampulla can find it (FIRST_DISTANCE), instead of wherever the wander
	# happens to point.
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
		for k in _guests:
			_step_person(delta, PERSON_SLOT + k)
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
	# behaviour: a cell does not decide to heal. **Its loads wear with its wound**
	# (docs/design/dna-slots.md §6.2) -- here in today's water; the drop wears
	# them in [method _step_one], with the time a body is owed -- and a body
	# carrying harm does not mend. Made whole by it, it dies of poison.
	if _drop == null and _dose_step(index, b, delta):
		return
	b.bite = maxf(b.bite - delta, 0.0)
	# In the drop the dart and the dash reload too, as the player's do: every
	# body defends and lunges with its own organs there (§5.7).
	if _drop != null:
		b.dart_clock = maxf(b.dart_clock - delta, 0.0)
		b.dash_clock = maxf(b.dash_clock - delta, 0.0)
		# **Pack 3: in the drop every body runs on rules** (behaviour.md §4),
		# and the hand-written hunter below is the reference alone.
		if rules:
			_step_ruled(index, b, delta)
			return
	match b.state:
		State.STALK:
			_step_stalk(index, b, delta)
		State.BREAK:
			_step_break(b, delta)
		_:
			_step_drift(index, b, delta)


func _step_drift(index: int, b: Body, delta: float) -> void:
	if _drop != null:
		_drift_in_drop(index, b, delta)
		return
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
	if _drop != null:
		_look_in_drop(index, b, reach)
		return
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
	return target_wound >= CHEW_INVITE and b.stat_bite > 0.0


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
	# **In the drop a run is made by a body** (§5.4, §5.7): a water cell's own
	# dart can break it, and it turns onto what it found at its own cirrus's
	# rate before it begins -- today's hunter snapped its nose round.
	if _drop != null:
		if _darted_off(b, d):
			return
		if b.orienting and _orient(b, offset, delta):
			return
	_step_aim(b, d, offset, delta)
	if b.state != State.STALK:
		return
	# And a lunge is a `myoneme` dash, at its price and on its cooldown, or
	# nothing: its own tail is all a body without one has (row 14).
	if _drop != null and d < LUNGE_RANGE:
		_dash(b)
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
		# A floc never moves (the drop only: today's water has none).
		if prey.inert:
			return prey.pos
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
	# **In the drop a miss costs a moment, whoever was missed** (§5.4): no
	# flight, REST_MISS where it is, and then its hunger decides again.
	# `flight` puts today's back, for playing the owner's other answer.
	if _drop != null and not flight:
		_rest(b, REST_MISS)
		_stat(&"misses")
		return
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
	var rate := b.stat_turn
	var want := _angle_of(b.aim - b.pos, b.heading)
	var turn := clampf(angle_difference(b.heading, want), -rate * delta, rate * delta)
	b.wander = lerpf(b.wander, randf_range(-WANDER_RATE, WANDER_RATE),
		1.0 - exp(-delta / WANDER_TAU))
	b.heading = wrapf(b.heading + turn + b.wander * delta, -PI, PI)
	b.pos += _forward(b.heading) * speed * delta
	b.speed = speed
	# **In the drop a swim is paid for** (§5.2): holding its speed against the
	# drag, at the player's own price, and every radian it steered. The wander
	# is the water's, and free. A dash's burst fades with the drag.
	if _drop != null:
		b.effort += CellBody.stroke_cost(speed) * delta + absf(turn) * CellBody.TURN_COST
		if b.dash_v > 0.0:
			b.dash_v *= exp(-CellBody.DRAG * delta)
			if b.dash_v < 1.0:
				b.dash_v = 0.0


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
#    makes `pellicle` a real defence (it divides the bite), and the toxin's
#    doses ride on the same bite (docs/design/dna-slots.md §7): venom from the
#    biter, poison and a side's sting from the bitten.
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
		for k in _guests:
			_contacts_person(PERSON_SLOT + k)
		# **A dedicated host's two guests, on each other**: the last row of
		# §1.3, after both have met the water -- as a phone host's own cell
		# meets the water before its guest does.
		if _guests > 1:
			_guests_meet()
	_contacts_water()
	return true


## **A player's mouth, and the water's mouths, on each other** -- one rule with
## two callers (shared-pond.md §1.3). [param p] null is the cell on this device,
## told through the shipped signals; a person is another player, in
## [member Person.slot], told through [signal person_touched]. Returns true
## when that player has just died here.
##
## For the local cell this is the shipped pass, in the shipped order, with the
## water's own kind of pre-check in front of it. Its place and its radius are
## read afresh for every body, and that is load-bearing: `eaten` is handled by
## the run before the next body is looked at, and the run grows the cell, so the
## next contact meets the bigger body -- while `my_gape` stays the one it had
## when the pass began, exactly as it always has.
func _contacts_with(p: Person) -> bool:
	var pb: Body = null if p == null else _cells[p.slot]
	# **A death by a dose, first** (docs/design/dna-slots.md §6.2): a wound the
	# harm in it made whole, worn by `cell.gd` for this cell and by
	# [method _step_person] for a person. Told here, at the top of the one pass
	# both waters call for each player, and returned as a contact death is -- so
	# nothing touches the field after it. A mirror never runs this: its cell's
	# death is the host's, and arrives as a KILLED.
	if (_cell.wound if p == null else pb.wound) >= 1.0:
		_dose_death(p)
		return true
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
	# In the drop, the bodies near this player the frame gathered -- this
	# cell's, or the person's own; in today's water, every water slot in order,
	# as it always was.
	var scan := _water_ids()
	if _drop != null:
		scan = _near if p == null else _person_near[p.slot - PERSON_SLOT]
	for i: int in scan:
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
		# **A floc** (the drop's): no mouth, so only this one's matters, and it
		# is food and nothing else -- once it has settled and if it fits (§7.3).
		# The other player's graze is theirs to eat: said to them as GRAZED.
		if b.inert:
			if b.settle >= 1.0 and b.radius < my_gape \
					and Cilia.mouth_touches(at, _cell.heading if p == null else pb.heading,
						r, my_gape, b.pos, b.radius):
				var worth := _meal_value_for(b.radius, r)
				var where := b.pos
				if p == null:
					_stat(&"player_grazed")
					grazed.emit(worth, where)
				else:
					_stat(&"friend_grazed")
					_tell(p, Contact.GRAZED, where, worth, By.WATER, &"")
				_consume(i)
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
		#
		# **Not in the drop** (row 15): there a mouth swallows what fits on
		# contact, whoever it is, as this cell's own always has. Dread still
		# warns of it, because dread never depended on the run.
		# **On rules nothing is on a run** (behaviour.md §4.3): what was committed
		# is a cell coming for that player -- which the switch that lets only a
		# run swallow a player asks, and nothing else does.
		var committed := _coming_for_player(b, p) if _ruled() \
			else b.state == State.STALK and _hunts(b, p)
		if its_mouth and swallows_player(committed, _drop != null and contact_swallow,
				_armoured(p), _gape(b)):
			# **Your poison goes into what swallows you** (dna-slots.md §7,
			# owner's row 5): a big dose, before the death is told -- after it,
			# nothing may touch the field. You are eaten, as anyone is: nobody is
			# spat out any more, and what ate you may die of it seconds later.
			_swallow_doses(i, _who(p), 0.0)
			# **In the drop the cell that eats you is fed by it** (§5.6), before
			# the death is told: after it, nothing may touch the field. The
			# other player likewise, and then out of their slot.
			if _drop != null:
				if not committed:
					_stat(&"player_swallowed_uncommitted")
				if p == null:
					_fed_on_player(b)
					died_to = i
					_tell(p, Contact.KILLED, b.pos, 0.0, By.WATER, &"", Cause.SWALLOWED)
					return true
				_fed_on(b, pb.radius, Genome.dominant_of(pb.genome))
				_tell(p, Contact.KILLED, b.pos, 0.0, By.WATER, &"", Cause.SWALLOWED)
				_person_gone(Cause.SWALLOWED, By.WATER, p)
				return true
			_tell(p, Contact.KILLED, b.pos, 0.0, By.WATER, &"", Cause.SWALLOWED)
			_break_off(b)
			if p != null:
				_person_gone(Cause.SWALLOWED, By.WATER, p)
			return true
		# In the drop a body's `pellicle` makes it bigger to this mouth too, as
		# this cell's own always has to theirs (row 5).
		if my_mouth and (b.radius if _drop == null else _swallow_r(b)) < my_gape:
			# Its poison into you first, then the meal: the run hears the dose
			# before it hears what it ate, so the flood can say what it was.
			_swallow_doses(_who(p), i,
				_cell.bearing_to(b.pos) if p == null else 0.0)
			# Emit where it was before recycling it, so a listener never has to
			# work out which one this was -- the mistake motes.gd documents.
			# Nutrition is against the eater's own radius, whoever that is.
			_tell(p, Contact.ATE, b.pos, _meal_value_for(b.radius, r), By.WATER,
				Genome.dominant_of(b.genome))
			_consume(i, Cause.SWALLOWED)
			continue
		# Not swallowed, either way round. What used to be a standoff with
		# nothing in it is now two mouths doing what mouths do.
		var serial := b.serial
		if its_mouth and _bitten_by(i, b, p):
			return true
		# A listener of the bite may have taken that body out of the water, and
		# then this slot is a different cell somewhere else entirely. The
		# player's mouth was measured against the one that has gone.
		if my_mouth and b.serial == serial and _bite_from(i, b, p):
			return true
	return false


## **The other player, in this water**: against the cells, then against the
## cell on this device. Host only; the mirror's contacts are the host's, heard.
## [param slot] is which person, on a dedicated host that has two.
func _contacts_person(slot: int = PERSON_SLOT) -> void:
	var pb := _cells[slot]
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
	if _drop != null:
		return _mouth_on_drop(i, b, j, other, gape)
	if other.radius >= gape:
		# Too big to swallow, so it gets chewed instead. Same clock, same table
		# and same two defending genes as the player's -- and the same toxins,
		# which go in as stacks and work over the next seconds, so neither
		# body leaves the water at the bite.
		if _chew(i, b, j, other) >= 1.0:
			_devour(b, other)
			_consume(j)
		return false
	# Its poison into the swallower, before it is gone (dna-slots.md §7.1).
	_swallow_doses(i, j, 0.0)
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
##
## **In the drop it is retired, and [param cause] says how** -- a [enum Cause],
## or 0 for a floc eaten or dissolved, which was never alive (§5.6). Nothing is
## made in its place: the spawner pays the shortfall back somewhere thin.
## Today's water ignores the cause.
func _consume(index: int, cause: int = 0) -> void:
	if _drop != null:
		_drop_lose(index, cause)
		return
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
## [param i] and [param j] are the two slots, which a dose names its doser by.
func _chew(i: int, b: Body, j: int, other: Body) -> float:
	if b.bite > 0.0:
		return other.wound
	var damage := CellBody.bite_damage(b.stat_bite,
		_gape(b), other.radius, other.stat_armor,
		_flank_theta(other.heading, other.pos, b.pos))
	if damage <= 0.0:
		return other.wound
	b.bite = CellBody.BITE_GAP
	other.wound = clampf(other.wound + damage, 0.0, 1.0)
	# Felt as a `hit` on its membrane, from the mouth (behaviour.md §3.2).
	_feel_hit(other, b.pos, _felt(damage))
	# The biter's venom into the bitten, and the bitten's poison -- and a sting,
	# if the bite landed on the side it guards -- into the biter
	# (dna-slots.md §7.2).
	_bite_doses(i, j, _bite_bearing(other.heading, other.pos, b.pos), 0.0)
	return other.wound


## **Where a bite landed, measured at the body it landed on**: the angle between
## that body's own heading and the direction the mouth arrived from. 0 is dead
## ahead, PI is dead astern. One definition, so a cell being flanked and the
## player being flanked are the same arithmetic. §1.2.
func _flank_theta(target_heading: float, target_pos: Vector2,
		mouth_pos: Vector2) -> float:
	return absf(_bite_bearing(target_heading, target_pos, mouth_pos))


## **The same angle, signed** (docs/design/dna-slots.md §7.2): clockwise from
## the target's nose, positive to its starboard -- the convention every bearing
## in this game is written in, so it is the side a sting's slot guards.
func _bite_bearing(target_heading: float, target_pos: Vector2,
		mouth_pos: Vector2) -> float:
	var from := mouth_pos - target_pos
	if from.length_squared() <= 0.0001:
		return 0.0
	return angle_difference(target_heading, _angle_of(from, target_heading))


## **Something has its mouth on a player and cannot swallow them.** Returns true
## when that bite was the one that finished them, on the same contract as the
## kill above: the caller stops touching that player immediately. One rule with
## two callers (shared-pond.md §1.3); [param p] null is the cell on this device.
func _bitten_by(index: int, b: Body, p: Person = null) -> bool:
	if b.bite > 0.0:
		return false
	var pb: Body = null if p == null else _cells[p.slot]
	# Where the mouth was when it closed: every event below is told from here,
	# even after a listener has taken that body somewhere else.
	var at := b.pos
	# Measured at the player, who is the target here: the bearing the mouth is
	# on *is* theta, because a body-relative bearing is already the angle from
	# its own heading. A mouth astern is the 2.10. For the person the same
	# angle is worked out the way the water measures every other body. Kept
	# signed, which is the side a sting guards (dna-slots.md §7.2).
	var landed := _cell.bearing_to(at) if p == null \
		else _bite_bearing(pb.heading, pb.pos, at)
	var damage := CellBody.bite_damage(b.stat_bite,
		_gape(b), _cell.radius if p == null else pb.radius,
		_cell.stat(&"armor") if p == null else pb.stat_armor,
		absf(landed))
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
	# **The toxins of a bite** (dna-slots.md §7.2): its venom into the player,
	# and the player's poison -- and a sting, on the side it guards -- into the
	# mouth. Stacks that work over the next seconds: nobody leaves the water at
	# the bite. **The bite that finishes the player carries them too**, as a
	# water body's last bite on another does ([method _chew]) -- every cell alike
	# (§20.3 check 6) -- and before anything is told, so the run hears the dose
	# first and nothing touches the field after the death.
	_bite_doses(index, _who(p), landed, landed)
	if hurt >= 1.0:
		# Chewed through rather than swallowed, and it ends the same way. The
		# player has felt every one of the bites that got here, at this bearing.
		# In the drop the mouth that finished it is fed by it, before the death
		# is told (§5.6).
		if _drop != null and p == null:
			_fed_on_player(b)
			died_to = index
			_tell(p, Contact.KILLED, at, 0.0, By.WATER, &"", Cause.CHEWED)
			return true
		if _drop != null:
			_fed_on(b, pb.radius, Genome.dominant_of(pb.genome))
			_tell(p, Contact.KILLED, at, 0.0, By.WATER, &"", Cause.CHEWED)
			_person_gone(Cause.CHEWED, By.WATER, p)
			return true
		_tell(p, Contact.KILLED, at, 0.0, By.WATER, &"", Cause.CHEWED)
		if b.state == State.STALK:
			_break_off(b)
		if p != null:
			_person_gone(Cause.CHEWED, By.WATER, p)
		return true
	_tell(p, Contact.BITTEN, at, _felt(damage), By.WATER, &"")
	return false


## **A player's own mouth on a body too big to swallow.** The option the player
## never had: whittle it down and it comes apart, and then it is a meal on
## exactly the terms a swallowed one is. One rule with two callers, [param p]
## null being this device's cell. **It no longer kills the biter**: a poisonous
## body's poison goes in as stacks and works over the next seconds
## (docs/design/dna-slots.md §7.2), so this returns false; the return is kept for
## the contact pass's contract, a death of the player's ending it.
func _bite_from(index: int, b: Body, p: Person = null) -> bool:
	var pb: Body = null if p == null else _cells[p.slot]
	if (_bite_clock if p == null else pb.bite) > 0.0:
		return false
	# Measured at the body being chewed: its own heading against the direction
	# this mouth arrived from. Holding your nose on a cell's stern is worth 2.10
	# times holding it on its nose, and that is the owner's sentence made true.
	var damage := CellBody.bite_damage(
		_cell.stat(&"bite") if p == null else pb.stat_bite,
		_cell.gape() if p == null else _gape(pb),
		b.radius, b.stat_armor,
		_flank_theta(b.heading, b.pos, _cell.position if p == null else pb.pos))
	if damage <= 0.0:
		return false
	if p == null:
		_bite_clock = CellBody.BITE_GAP
	else:
		pb.bite = CellBody.BITE_GAP
	var at := b.pos
	# **The bearing the bite is felt at, taken before anything is said**, which
	# is where the shipped `_bite_from_me` took it. The ATE below runs the
	# run's `eaten` handler before the BITTEN goes, and a handler that moved or
	# turned this cell would otherwise move this bite with it -- none does today,
	# and the gate cannot see the difference, so the order is held here rather
	# than left to be true (shared-pond.md §3). A person's bearing is worked out
	# on their own device, from the place.
	var felt_at := _cell.bearing_to(at) if p == null else 0.0
	var mouth_at := _cell.position if p == null else pb.pos
	b.wound = clampf(b.wound + damage, 0.0, 1.0)
	# Felt as a `hit` on its membrane, from the player's mouth (behaviour.md §3.2).
	_feel_hit(b, mouth_at, _felt(damage))
	# **The toxins of a bite** (dna-slots.md §7.2): the player's venom into the
	# body, and its poison -- and a sting, if the bite landed on the side it
	# guards -- into the player, felt where the bite landed.
	_bite_doses(_who(p), index, _bite_bearing(b.heading, b.pos, mouth_at), felt_at)
	if b.wound >= 1.0:
		_tell(p, Contact.ATE, at,
			_meal_value_for(b.radius, _cell.radius if p == null else pb.radius),
			By.WATER, Genome.dominant_of(b.genome))
		_consume(index, Cause.CHEWED)
	var level := _felt(damage) * BITE_FELT_SHARE
	if p == null:
		bitten.emit(felt_at, level)
	else:
		_tell(p, Contact.BITTEN, at, level, By.WATER, &"")
	return false


# ---------------------------------------------------------------------------
# One player's mouth on the other (shared-pond.md §1.3, the last row).
#
# **Today's rule, without the commitment**: a human's mouth on you is the
# commitment, and the only warning you get is the dread their gape raises.
# Resolved on the host, from its own cell's side, exactly as a water cell's
# contact with that cell is -- with the person in the water cell's place:
#
#   their mouth on me and I fit it (armoured) -> I am swallowed, and they take
#                                                my poison
#   my mouth on them and they fit (armoured)  -> they are, and I take theirs
#   otherwise                                 -> each mouth chews, in its own
#                                                direction's order, and each
#                                                bite carries its toxins
#
# So a pair that could each swallow the other is decided the way the shipped
# pass decides a water cell against this cell: the other mouth is asked first.
#
# **A dedicated host has no cell of its own and two guests** (`game/server/`),
# so the same three functions take the "me" side as a person too: [param me]
# null is this device's cell, exactly as it always was, and a person is the
# guest in [constant PERSON_SLOT], meeting the one after it -- whose mouth is
# therefore the one asked first. Everything "me" is read through the helpers
# below at the moment the shipped code read it, so this cell's path makes the
# same calls in the same order: `hear_contact()` is `_tell(null)`, and
# `_lose_local()` is `_lose(null)`.
# ---------------------------------------------------------------------------

func _players_meet(p: Person, me: Person = null) -> void:
	var pb := _cells[p.slot]
	var mb: Body = null if me == null else _cells[me.slot]
	var their_gape := _gape(pb)
	var my_gape := _cell.gape() if me == null else _gape(mb)
	var their_mouth := Cilia.mouth_touches(pb.pos, pb.heading, pb.radius,
		their_gape, _my_pos(me), _my_radius(me))
	var my_mouth := Cilia.mouth_touches(_my_pos(me),
		_cell.heading if me == null else mb.heading,
		_my_radius(me), my_gape, pb.pos, pb.radius)
	if not (their_mouth or my_mouth):
		return
	var here := _my_pos(me)
	var there := pb.pos
	if their_mouth and _armoured(me) < their_gape:
		# Eaten, as anyone is, and they take my poison before it is told
		# (dna-slots.md §7.1, owner's row 5).
		_swallow_doses(p.slot, _who(me), 0.0)
		_tell(me, Contact.KILLED, there, 0.0, By.FRIEND, &"", Cause.SWALLOWED)
		_tell(p, Contact.ATE, here, _meal_value_for(_my_radius(me), pb.radius),
			By.FRIEND, _my_dominant(me))
		_lose(me, Cause.SWALLOWED, By.FRIEND)
		return
	if my_mouth and pb.radius * p.armour < my_gape:
		# And the other way: their poison into me, felt as a meal, then the meal.
		_swallow_doses(_who(me), p.slot,
			_cell.bearing_to(there) if me == null else 0.0)
		_tell(me, Contact.ATE, there, _meal_value_for(pb.radius, _my_radius(me)),
			By.FRIEND, Genome.dominant_of(pb.genome))
		_tell(p, Contact.KILLED, here, 0.0, By.FRIEND, &"", Cause.SWALLOWED)
		_person_gone(Cause.SWALLOWED, By.FRIEND, p)
		return
	if their_mouth and _chewed_by_friend(p, me):
		return
	if my_mouth and pb.person == p and pb.seeded:
		_chew_friend(p, me)


## Their mouth on this cell, and it cannot swallow it: [method _bitten_by]'s
## order, the victim's death first. Returns true when this cell died.
func _chewed_by_friend(p: Person, me: Person = null) -> bool:
	var pb := _cells[p.slot]
	var mb: Body = null if me == null else _cells[me.slot]
	if pb.bite > 0.0:
		return false
	var there := pb.pos
	var here := _my_pos(me)
	# The flank at this cell, as the water measures it at a person -- signed,
	# for the side a sting guards.
	var landed := _cell.bearing_to(there) if me == null \
		else _bite_bearing(mb.heading, mb.pos, there)
	var damage := CellBody.bite_damage(pb.stat_bite,
		_gape(pb), _my_radius(me),
		_cell.stat(&"armor") if me == null else mb.stat_armor,
		absf(landed))
	if damage <= 0.0:
		return false
	pb.bite = CellBody.BITE_GAP
	var hurt := 0.0
	if me == null:
		_cell.wound = clampf(_cell.wound + damage, 0.0, 1.0)
		hurt = _cell.wound
	else:
		mb.wound = clampf(mb.wound + damage, 0.0, 1.0)
		hurt = mb.wound
	# Their venom into me, and my poison -- and my sting, on that side -- into
	# them (dna-slots.md §7.2). Stacks: nobody leaves the water at the bite --
	# and the bite that finishes me carries them too, before it is told.
	_bite_doses(p.slot, _who(me), landed, landed)
	if hurt >= 1.0:
		_tell(me, Contact.KILLED, there, 0.0, By.FRIEND, &"", Cause.CHEWED)
		_tell(p, Contact.ATE, here, _meal_value_for(_my_radius(me), pb.radius),
			By.FRIEND, _my_dominant(me))
		_lose(me, Cause.CHEWED, By.FRIEND)
		return true
	_tell(me, Contact.BITTEN, there, _felt(damage), By.FRIEND, &"")
	_tell(p, Contact.BITTEN, here, _felt(damage) * BITE_FELT_SHARE, By.FRIEND, &"")
	return false


## This cell's mouth on them, and they are too big to swallow:
## [method _bite_from]'s order, the eater's death first.
func _chew_friend(p: Person, me: Person = null) -> void:
	var mb: Body = null if me == null else _cells[me.slot]
	if (_bite_clock if me == null else mb.bite) > 0.0:
		return
	var pb := _cells[p.slot]
	var there := pb.pos
	var here := _my_pos(me)
	var damage := CellBody.bite_damage(
		_cell.stat(&"bite") if me == null else mb.stat_bite,
		_cell.gape() if me == null else _gape(mb),
		pb.radius, pb.stat_armor,
		_flank_theta(pb.heading, there, here))
	if damage <= 0.0:
		return
	if me == null:
		_bite_clock = CellBody.BITE_GAP
	else:
		mb.bite = CellBody.BITE_GAP
	pb.wound = clampf(pb.wound + damage, 0.0, 1.0)
	# My venom into them, and their poison -- and their sting, on the side my
	# bite landed -- into me, felt where it landed (dna-slots.md §7.2).
	_bite_doses(_who(me), p.slot, _bite_bearing(pb.heading, there, here),
		_cell.bearing_to(there) if me == null else 0.0)
	if pb.wound >= 1.0:
		_tell(me, Contact.ATE, there, _meal_value_for(pb.radius, _my_radius(me)),
			By.FRIEND, Genome.dominant_of(pb.genome))
		_tell(p, Contact.KILLED, here, 0.0, By.FRIEND, &"", Cause.CHEWED)
		_person_gone(Cause.CHEWED, By.FRIEND, p)
	else:
		_tell(p, Contact.BITTEN, here, _felt(damage), By.FRIEND, &"")
	_tell(me, Contact.BITTEN, there, _felt(damage) * BITE_FELT_SHARE, By.FRIEND, &"")


## **A dedicated host's two guests, mouth to mouth** -- [method _players_meet]
## with the guest in [constant PERSON_SLOT] on this cell's side of it, both
## told through [signal person_touched]. Nothing here if either is out of the
## water, dead, or not there at all.
func _guests_meet() -> void:
	var ab := _cells[PERSON_SLOT]
	var bb := _cells[PERSON_SLOT + 1]
	if ab.person == null or bb.person == null or not ab.seeded or not bb.seeded:
		return
	_players_meet(bb.person, ab.person)


## Where "me" is in the three functions above: this cell, or that person.
func _my_pos(me: Person) -> Vector2:
	return _cell.position if me == null else _cells[me.slot].pos


func _my_radius(me: Person) -> float:
	return _cell.radius if me == null else _cells[me.slot].radius


## What "me" was most made of, for the friend who ate it.
func _my_dominant(me: Person) -> StringName:
	return _local_dominant() if me == null \
		else Genome.dominant_of(_cells[me.slot].genome)


## "Me" died here, this frame: this cell leaves the water, a person leaves
## their slot and is said to have gone.
func _lose(me: Person, cause: int, by: int) -> void:
	if me == null:
		_lose_local()
	else:
		_person_gone(cause, by, me)


## How loud a wound of [param damage] is on the skin, 0..1, against the worst
## bite any mouth in the game can land. The cap that matters is the signal
## bus's; this is only the shape of it.
func _felt(damage: float) -> float:
	if damage <= 0.0:
		return 0.0
	var worst := Stats.top(&"bite")
	return clampf(damage / maxf(worst, 0.001), BITE_HIT_FLOOR, 1.0)


# ---------------------------------------------------------------------------
# **Venom and poison: how a dose arrives** (docs/design/dna-slots.md §7). Every
# place above where a bite or a swallow is resolved hands its two bodies here,
# in one shape, so a player and a water cell in either role take the same
# stacks from the same contact. A body is named by its slot, and the cell on
# this device -- which is in no slot -- by [constant TARGET_PLAYER].
#
# | form   | where         | when                                   | who takes it |
# | venom  | the front     | a bite its mouth lands                 | the bitten   |
# | venom  | a side, stern | a bite landing within VENOM_ARC_DEG / 2 | the biter    |
# | poison | inside        | a bite landing anywhere                | the biter    |
# | poison | inside        | it is swallowed                        | the swallower|
#
# Armour does not stop venom: `pellicle` divides a bite's damage and the stacks
# ride in whole. A dose is stacks in a body's loads; what they do is the dose
# step's, over the seconds that follow -- nobody leaves the water at the bite.
# ---------------------------------------------------------------------------

## **What a body wearing [param tiers] delivers** -- its toxins' forms, by where
## each sits -- as records of [constant TOX_STRIDE] floats `[how, kind, stacks,
## bearing]` ([constant HOW_BITE] and the rest). [param order] is where its
## outside forms are worn, slot by slot; empty, the default order every water
## cell is drawn and senses in ([method Cilia.default_order]). A venom with no
## seat rides on the bite. Empty for a body with no toxin, which is most of the
## water. Read once, whenever what a body wears changes. [param sides] false is
## a venom on a side or the stern that stings nothing ([member venom_sides]).
static func toxins_of(tiers: Dictionary, order: Array = [],
		sides := CellBody.VENOM_SIDES) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var seats: Array = order
	for gene: Variant in tiers:
		var form := StringName(gene)
		# **A toxin is a key with a dose**, whatever its places: a strain of one place,
		# outside alone, is venom too (gene-catalogue.md §6.4).
		var copies := clampi(int(tiers[gene]), 0, Genome.TIER_MAX)
		var kind := Doses.kind_of(Genome.strain_of(form))
		if copies <= 0 or kind < 0:
			continue
		if Genome.is_inside_form(form):
			_toxin_record(out, HOW_POISON, kind, Stats.value(form, &"poison_stacks", copies))
			_toxin_record(out, HOW_SWALLOW, kind, Stats.value(form, &"swallow_stacks", copies))
			continue
		if seats.is_empty():
			seats = Cilia.default_order(tiers)
		var slot := seats.find(form)
		if slot < 0 or Genome.is_front(slot):
			_toxin_record(out, HOW_BITE, kind, Stats.value(form, &"venom_stacks", copies))
		elif sides:
			_toxin_record(out, HOW_STING, kind, Stats.value(form, &"venom_stacks", copies),
				Cilia.slot_bearing(slot))
	return out


## One record of [method toxins_of], onto [param out].
static func _toxin_record(out: PackedFloat64Array, how: int, kind: int, stacks: float,
		bearing: float = 0.0) -> void:
	out.append(float(how))
	out.append(float(kind))
	out.append(stacks)
	out.append(bearing)


## **Who [param p] is, as a dose names a body**: [constant TARGET_PLAYER] for
## the cell on this device, a person's slot for a person.
func _who(p: Person) -> int:
	return TARGET_PLAYER if p == null else p.slot


## **What the body [param who] names delivers**: this cell's as the run wrote
## them, or a body's own, read again off what it wears if that changed since
## they were last read -- whichever door changed it.
func _toxins_at(who: int) -> PackedFloat64Array:
	if who == TARGET_PLAYER:
		return toxins
	if who < 0 or who >= _cells.size():
		return PackedFloat64Array()
	var b := _cells[who]
	var key := hash(b.genome) ^ (hash(b.order) * 31 if not b.order.is_empty() else 0) \
		^ (0 if venom_sides else 0x5157)
	if key != b.toxins_key:
		b.toxins = toxins_of(b.genome, b.order, venom_sides)
		b.toxins_key = key
	return b.toxins


## **A bite's toxins** (§7.1): [param biter] bit [param target], landing at
## [param landed] -- the signed bearing at the target, clockwise from its nose.
## The biter's front venom goes into the target; the target's poison, and its
## sting if the bite landed within `VENOM_ARC_DEG / 2` of the bearing it guards,
## go into the biter. [param felt] is the bearing the cell on this device feels
## its own dose from, when it is one of the two.
func _bite_doses(biter: int, target: int, landed: float, felt: float) -> void:
	var into_target := _toxins_at(biter)
	for r in range(0, into_target.size(), TOX_STRIDE):
		if int(into_target[r]) == HOW_BITE:
			_dose(target, int(into_target[r + 1]), into_target[r + 2], biter, felt, false)
			if biter == TARGET_PLAYER:
				toxin_fired.emit(FIRED_VENOM)
	var into_biter := _toxins_at(target)
	var reach := deg_to_rad(CellBody.VENOM_ARC_DEG) * 0.5
	for r in range(0, into_biter.size(), TOX_STRIDE):
		var how := int(into_biter[r])
		if how == HOW_POISON:
			_dose(biter, int(into_biter[r + 1]), into_biter[r + 2], target, felt, false)
			if target == TARGET_PLAYER:
				toxin_fired.emit(FIRED_POISON)
		elif how == HOW_STING and absf(angle_difference(into_biter[r + 3], landed)) <= reach:
			_dose(biter, int(into_biter[r + 1]), into_biter[r + 2], target, felt, false)
			if target == TARGET_PLAYER:
				toxin_fired.emit(FIRED_STING)


## **A swallow's toxin** (§7.1): [param eater] swallowed [param eaten], and takes
## its poison -- **before** the death is told, which is the order every contact
## keeps. Venom does nothing on a swallow: what it would poison is already dead.
## [param felt] is the bearing the cell on this device feels a meal's dose from.
func _swallow_doses(eater: int, eaten: int, felt: float) -> void:
	var into_eater := _toxins_at(eaten)
	for r in range(0, into_eater.size(), TOX_STRIDE):
		if int(into_eater[r]) == HOW_SWALLOW:
			_dose(eater, int(into_eater[r + 1]), into_eater[r + 2], eaten, felt, true)
			if eaten == TARGET_PLAYER:
				toxin_fired.emit(FIRED_POISON)


## **[param stacks] of [param kind] into the body [param who] names**, the last
## of them [param by]'s. The cell on this device is told, from [param felt] and
## as a [param meal] or not, before whatever sensation the dose arrived with.
func _dose(who: int, kind: int, stacks: float, by: int, felt: float, meal: bool) -> void:
	if stacks <= 0.0 or kind < 0 or kind >= Doses.KINDS:
		return
	if who == TARGET_PLAYER:
		if _cell == null:
			return
		_cell.loads[kind] += stacks
		_dosed_by = by
		_dosed_serial = _cells[by].serial if by >= 0 and by < _cells.size() else 0
		dosed.emit(felt, kind, stacks, meal)
		return
	if who < 0 or who >= _cells.size():
		return
	var b := _cells[who]
	b.loads[kind] += stacks
	b.dosed_by = by
	_stat(&"doses")


## **Whose mouth a death by a dose was**, for the pond (shared-pond.md §2): a
## friend's -- the cell on this device, or a person -- or the water's.
func _by_of(doser: int) -> int:
	return By.FRIEND if doser == TARGET_PLAYER or _is_person_slot(doser) else By.WATER


## **A player died of a dose** (docs/design/dna-slots.md §6.2): its wound made
## whole by the harm in it. **Quiet**: told as a KILLED from where it was, with
## no bearing in it -- nothing hit it -- caused `POISONED`, by the water or a
## friend as its last doser was. For this cell the doser is [member died_to],
## the killer the replay rings, while that slot still holds the body that dosed
## it; a person leaves its slot, its remains left in the drop.
func _dose_death(p: Person) -> void:
	if p == null:
		var doser := _dosed_by
		died_to = doser if doser >= 0 and doser < _cells.size() \
			and not _is_person_slot(doser) and _cells[doser].seeded \
			and _cells[doser].serial == _dosed_serial else -1
		_tell(null, Contact.KILLED, _cell.position, 0.0, _by_of(doser), &"", Cause.POISONED)
		return
	var pb := _cells[p.slot]
	var by := _by_of(pb.dosed_by)
	_tell(p, Contact.KILLED, pb.pos, 0.0, by, &"", Cause.POISONED)
	_person_gone(Cause.POISONED, by, p)


## **What one body carries**, stacks of each of doses.gd's kinds, index-matched
## to [method points] -- for the views, which draw every load on every body.
## The live array: read it, and do not write through it.
func loads_of(index: int) -> PackedFloat64Array:
	if index < 0 or index >= _cells.size():
		return Doses.none()
	return _cells[index].loads


## **What one body's loads come to on that body**: each kind's stacks felt at
## its radius, `Vector3(harm, paralysis, sleep)`, as cilia.gd's `dose` takes
## them -- zero for a body that carries nothing, which is nearly every body.
func felt_at(index: int) -> Vector3:
	if index < 0 or index >= _cells.size():
		return Vector3.ZERO
	var b := _cells[index]
	return felt_of(b.loads, b.radius)


## [param loads] felt by a body of [param body_radius], as a `Vector3` of
## doses.gd's three kinds. Static, for the player's own cell and the replay.
static func felt_of(loads: PackedFloat64Array, body_radius: float) -> Vector3:
	if not Doses.any(loads):
		return Vector3.ZERO
	var out := Vector3.ZERO
	for k in mini(loads.size(), Doses.KINDS):
		out[k] = Doses.felt(loads[k], body_radius, CellBody.DOSE_SIZE)
	return out


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
		if _pond:
			for k in _guests:
				if _cells[PERSON_SLOT + k].seeded:
					_push_local(_cells[PERSON_SLOT + k], false)
	if _pond:
		for k in _guests:
			_push_person(PERSON_SLOT + k)

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
## them. Their own half, and their knock, happen on their device -- and so do
## two guests' halves of their overlap with each other, on a dedicated host.
func _push_person(slot: int = PERSON_SLOT) -> void:
	var pb := _cells[slot]
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
##
## In the drop it is kept as it grows ([member _widest_now]): a scan of six
## hundred bodies after every contact is what the drop cannot afford.
func _widest() -> float:
	if _drop != null:
		return _widest_now
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
## bound for the widest body at the widest gape any mouth opens --
## both of which [method Cilia.mouth_touches] refuses beyond, because it grows
## with the radius and the gape. NaN in, NaN out, which skips nothing.
static func _player_bound(r: float, gape: float, widest: float) -> float:
	var top := Stats.top(&"gape")
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
##
## **In the drop everything is simulated, so growth stops where the player's
## does** (§5.5): at DIVIDE_RADIUS. The mouth keeps whatever it grows (row 5).
func _devour(b: Body, prey: Body) -> void:
	if _drop != null:
		_grow(b, Genome.dominant_of(prey.genome))
		return
	b.radius += CellBody.GROWTH_PER_MEAL
	b.meals += 1
	Genome.integrate_into(b.genome, Genome.dominant_of(prey.genome),
		CellBody.slots_for(b.radius))
	b.derive()
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
	if not _pond:
		return
	for k in _guests:
		var slot := PERSON_SLOT + k
		if _cells.size() > slot and _cells[slot].person != null:
			_anchor_ids.append(Anchor.PERSON + k)
			_anchor_at.append(_cells[slot].pos)


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
		and (b.target == TARGET_PLAYER or _is_person_slot(b.target))


## Is [param index] a slot this pond keeps a person in.
func _is_person_slot(index: int) -> bool:
	return index >= PERSON_SLOT and index < PERSON_SLOT + _guests


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
	b.loads.fill(0.0)
	b.dosed_by = -1
	b.bite = 0.0
	_serial += 1
	b.serial = _serial
	_changes += 1


# ---------------------------------------------------------------------------
# What the cell can actually sense: a summed concentration, a level with no
# bearing in it at all, and a scalar with no bearing in it.
# ---------------------------------------------------------------------------

## **The player on this device, as an observer** (behaviour.md §12.1): its body
## off the cell, and its organs as the run wrote them this frame -- what every
## sense of the membrane is asked through.
func _player_eye() -> Observer:
	var o := _eye
	o.face(_cell.position, _cell.heading)
	o.radius = _cell.radius
	o.gape = _cell.gape()
	o.swallow = _cell.swallow_radius()
	o.armour = _cell.stat(&"armor")
	o.wound = _cell.wound
	o.smell_range = smell_range
	o.smell_bearing = smell_bearing
	o.touch_range = touch_range
	o.beam_range = beam_range
	o.beam_bearings = beam_bearings
	o.beam_arcs = beam_arcs
	o.beam_fan_mid = beam_fan_mid
	o.beam_fan_half = beam_fan_half
	o.ping_range = ping_range
	o.ping_bearing = ping_bearing
	o.ping_through = ping_through
	o.ping_tier = ping_tier
	o.slot = -1
	return o


## **The player's organs as their membrane last read them** (automation.md
## §4.1): the observer every sense of this frame was asked through, with what
## each found on it -- the nose's level, the shade and its pull, the touch --
## and whether the body wears an eyespot, which the membrane's shadow is gated
## by downstream and an instinct's by this. What the player's instincts are
## reported from (game/normal/own_rules.gd); nothing here is sensed again.
func own_eye() -> Observer:
	if _cell != null:
		_eye.eyespot = _cell.on_channel(Catalogue.LIGHT) != &""
	return _eye


## The clock [member player_calls] is kept on.
func call_clock() -> float:
	return _call_t


## **The player's nose, shadow and dread**, through [method _feel] -- the one
## function every observer smells and sees by -- over the bodies the frame
## gathered round the cell, written where the run reads them. The shadow's
## bearing is left where it was when the last shadow faded.
func _step_sense() -> void:
	var o := _player_eye()
	# In the drop, the bodies near this cell the frame gathered: nothing past
	# them reaches any sense (§4.2) -- and in a pond the people in the water.
	# In today's water, every body.
	_feel(o, _sense_ids(), true, true, true)
	concentration = minf(o.scent, 1.0)
	# **There is no bearing here any more, and that is the change.** A cell with
	# no chemocyte leaves with [member smell_range] 0, so nothing is ever inside
	# the nose and it leaves with taste_level 0 -- which is what makes "an organ
	# you have not grown is silent" true at the source as well as at the two
	# gates downstream of it.
	taste_level = o.smell
	shadow = minf(o.shade, 1.0)
	# Deliberately left where it was when the last shadow faded rather than
	# snapped to dead ahead: the lobe is already dark at strength 0, and a
	# bearing that resets would swing the amber round to the nose on its way
	# out -- a movement the player would read as something passing in front of
	# them, at the moment nothing is.
	if shadow > 0.0 and o.shade_pull.length_squared() > 0.0:
		shadow_bearing = o.bearing_to(o.pos + o.shade_pull)
	threat = o.worst
	dread_level = minf(o.dread, 1.0) * DREAD_CAP


## **What an observer smells, the shadow it stands in, and -- for the player
## alone -- its dread** (behaviour.md §12.1), over the bodies in [param scan]:
## one pass, as the player's membrane has always made it, read off the observer
## and those bodies and nothing else. [param smell] asks the nose, [param shade]
## the eyespot, and [param fear] the dread only a player's membrane feels: no
## organ reports another cell's mouth, so no water cell is ever asked it (§3.4).
## What it finds is written on [param o]; a sense not asked is left at nothing.
##
## [param scan] holds slots, and [constant TARGET_PLAYER] for the player on this
## device as a water cell finds it ([member _me]). The observer's own slot is
## passed over.
func _feel(o: Observer, scan: PackedInt32Array, smell: bool, shade: bool, fear: bool) -> void:
	var total := 0.0
	var dread := 0.0
	var worst := 0.0
	var gape := o.gape
	var shaded := 0.0
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
	# **A nose asked alone sums only what lies inside its reach**: a water cell's
	# `smell` is the level, which nothing past it reaches, and no organ of its
	# reads the raw sum ([member Observer.scent]) the player's membrane does.
	var nose_only := smell and not shade and not fear

	for i: int in scan:
		if i == o.slot:
			continue
		var b := _cells[i] if i >= 0 else _me
		if not b.seeded:
			continue
		var offset := b.pos - o.pos
		var d := offset.length()
		if nose_only and d >= o.smell_range:
			continue

		# Taste, over everything I can eat, weighted so a body crossing my gape
		# limit fades rather than pops.
		#
		# **In the drop the cue follows the mouth** (§14.1): a body's `pellicle`
		# protects it from every mouth there, so the scent weighs it by the size
		# the mouth measures -- or it would call edible a cell the mouth cannot
		# take. A floc smells in as it settles, never in a step (§7.2).
		#
		# The size is the one a mouth measures: [method _swallow_r]'s, and the
		# player on this device ([member _me]) as its own cell measures itself.
		#
		# **Written out rather than called**, because every nose in the water runs
		# this loop over every body it reaches: that size, [method taste_weight],
		# [method scent] and the observer's `bearing_to`, each to the bit --
		# drop_probe's checks 1 and 2 hold the two spellings together.
		if smell:
			var size := b.radius
			if _drop != null:
				size = _cell.swallow_radius() if b == _me \
					else (b.radius * b.armour if armour_swallow else b.radius)
			var edible := smoothstep(EDIBLE_FADE_OUT, EDIBLE_FADE_IN, size / maxf(gape, 0.001))
			if b.inert:
				edible *= b.settle
			if edible > 0.0:
				var c := 0.0
				if d < SCENT_RANGE:
					c = minf(1.0, pow(CORE_RANGE / maxf(d, CORE_RANGE), SCENT_FALLOFF)
						* smoothstep(SCENT_RANGE, SCENT_RANGE - SCENT_WINDOW, d))
				c *= edible
				if c > 0.0:
					total += c
					if d < o.smell_range:
						# The whole of "orientation should count": a cosine lobe
						# about the arc the organ is worn on, never falling below
						# SMELL_BEHIND. A cone with a tier-scaled width was
						# measured and buys under 2% of swing -- three-senses.md
						# §7.4.
						var lobe := 0.5 + 0.5 * cos(angle_difference(o.smell_bearing,
							atan2(offset.dot(o.starboard), offset.dot(o.forward))))
						var w := c * (SMELL_BEHIND + (1.0 - SMELL_BEHIND) * lobe)
						# Loudest and rest, in one pass and with no sort: the new
						# maximum demotes the old one into the tail.
						if w > smelt_top:
							smelt_rest += smelt_top
							smelt_top = w
						else:
							smelt_rest += w

		# A floc is smell and nothing more: no mass to cast a shadow and no
		# mouth to dread (§7.5).
		if b.inert:
			continue

		# The shadow, over every body big enough to cast one. Summed and given a
		# bearing exactly the way taste is, for the same reason: two bodies
		# blocking the light really do block more of it than one, and a summed
		# vector moves continuously where a pick-the-biggest would jump the
		# bearing across the screen the frame two shadows swapped rank.
		if shade:
			var mass := smoothstep(SHADOW_MIN_RATIO, SHADOW_FULL_RATIO,
				b.radius / maxf(o.radius, 0.001))
			if mass > 0.0 and d < SHADOW_RANGE:
				var near := clampf((SHADOW_RANGE - d) / (SHADOW_RANGE - SHADOW_CORE),
					0.0, 1.0)
				var blocked := mass * near
				if blocked > 0.0:
					shaded += blocked
					shade_pull += offset / maxf(d, 0.001) * blocked

		if not fear:
			continue
		# Dread, over **every** body, with no question asked that has a yes/no
		# answer -- see THREAT_LOW for the three steps that gating this put into
		# the one readout §7.0 exists to protect. A body too small-mouthed to
		# matter scores 0.0 on the curve and drops out on its own, continuously,
		# which is what the curve is for.
		#
		# Nine seconds of closing still separate the first dread from the first
		# wake: ten seconds of the water simply being wrong, then a direction.
		var level := smoothstep(THREAT_LOW, THREAT_HIGH,
			_gape(b) / maxf(o.swallow, 0.001))
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
		var rate := CellBody.bite_damage(b.stat_bite,
			_gape(b), o.radius, o.armour, PI) \
			/ CellBody.BITE_GAP
		if rate <= 0.0:
			continue
		var urgency := clampf(rate * CHEW_FULL_SECONDS, 0.0, 1.0)
		dread += CHEW_SHARE * urgency \
			* clampf((CHEW_RANGE - d) / (CHEW_RANGE - DREAD_CORE), 0.0, 1.0) \
			* (CHEW_HURT_FLOOR + (1.0 - CHEW_HURT_FLOOR) * o.wound)

	# **The meniscus bends the light away** (§3.2): a curved surface is a lens,
	# and the stretch of it nearest the cell reads to an eyespot as a shadow at
	# its bearing, EDGE_SHADOW of a body's at the closest, falling to nothing
	# at SHADOW_RANGE. Summed with the bodies' like one more, so it moves the
	# lobe as continuously as they do. The drop only.
	if shade and _drop != null:
		var edge := _drop.meniscus.depth(o.pos)
		if edge < SHADOW_RANGE:
			var blocked := Drop.EDGE_SHADOW * clampf((SHADOW_RANGE - edge)
				/ (SHADOW_RANGE - SHADOW_CORE), 0.0, 1.0)
			shaded += blocked
			shade_pull += (_drop.meniscus.nearest_rim(o.pos) - o.pos) \
				.normalized() * blocked

	o.scent = total
	# **A receptor saturates; it does not clip.** The clamp that used to be on
	# this line was the actual fault three-senses.md §7.5 blamed on the sum:
	# above 1.0 its slope is zero, and a readout with no slope in it is a
	# readout a forager cannot climb. See [constant SMELL_HALF]. A nose with no
	# reach sums nothing, and `0 / (0 + K)` is 0.
	var s := smelt_top + SMELL_TAIL * smelt_rest
	o.smell = s / (s + SMELL_HALF)
	o.shade = shaded
	o.shade_pull = shade_pull
	o.worst = worst
	o.dread = dread


## **The player's beams**, through [method _beams_of] -- the one function every
## observer's rays are cast by -- over the bodies the frame gathered round the
## cell: [member beams] answered, and [member beam_touched] counted.
##
## Deliberately blind to the motes: they are inert dust with no chemistry and no
## genome, and a beam that stopped on grit would spend the one clear signal the
## player owns on something that does not matter.
func _step_beams() -> void:
	beams.clear()
	beam_touched.clear()
	if beam_range <= 0.0 or beam_bearings.is_empty() or _cell == null:
		return
	_beams_of(_player_eye(), _sense_ids(), beams, true)


## **An observer's beams** (behaviour.md §12.1): each of its rays cast against
## the bodies in [param scan] its fan can reach -- the nearest surface along the
## ray, or nothing -- appended to [param out] as `[bearing, distance, hit,
## body]`, index-matched to its bearings. [param touches] is the player's beam
## experience: every body a ray stops on goes into [member beam_touched], and no
## other observer's ever does.
##
## **Bodies nowhere near the fan are skipped first**, by one range test and one
## angle test against the fan's middle and half-width. Past the fork there can
## be twenty rays, and twenty rays against 34 bodies is 680 ray tests a frame
## (three-senses.md §3.4); most of the water is behind or beside a 100-degree
## fan. A body that passes is tested exactly as it always was, so the answer
## does not change.
##
## **A sweeping ray is cast across the whole arc it crossed this frame**, in
## sub-steps no wider than [constant BEAM_SUBSTEP], and answers with the
## nearest hit in that arc (beam-levels.md §4.3).
func _beams_of(o: Observer, scan: PackedInt32Array, out: Array, touches: bool) -> void:
	if o.beam_range <= 0.0 or o.beam_bearings.is_empty():
		return
	var origin := o.pos
	var near: Array[int] = []
	for i: int in scan:
		if i == o.slot:
			continue
		var b := _cells[i] if i >= 0 else _me
		if not b.seeded:
			continue
		var to := b.pos - origin
		var d := to.length()
		if d - b.radius > o.beam_range:
			continue
		if o.beam_fan_half >= 0.0 and d > b.radius:
			var at := atan2(to.dot(o.starboard), to.dot(o.forward))
			var reach := asin(clampf(b.radius / d, 0.0, 1.0))
			if absf(angle_difference(o.beam_fan_mid, at)) \
					> o.beam_fan_half + reach + BEAM_SLACK:
				continue
		near.append(i)
	var sweeping := o.beam_arcs.size() == o.beam_bearings.size() * 2
	for k in o.beam_bearings.size():
		var bearing := o.beam_bearings[k]
		if not sweeping:
			out.append(_cast_ray(o, origin, bearing, near, touches))
			continue
		var low := o.beam_arcs[2 * k]
		var span := angle_difference(low, o.beam_arcs[2 * k + 1])
		var steps := maxi(int(ceilf(absf(span) / BEAM_SUBSTEP)), 1)
		var best: Array = [bearing, o.beam_range, false, -1]
		for s in steps + 1:
			var ray := _cast_ray(o, origin, low + span * float(s) / float(steps), near,
				touches)
			if bool(ray[2]) and (not bool(best[2]) or float(ray[1]) < float(best[1])):
				best = ray
		out.append(best)


## **One ray** of [param o]'s: the nearest surface of the bodies in [param near]
## along [param bearing], as `[bearing, distance, hit, body]` -- `body` the slot
## it stopped on, [constant EDGE_BODY] for the rim, [constant TARGET_PLAYER] for
## the player on this device, -1 for nothing. With [param touches], whatever it
## stops on is counted as touched.
func _cast_ray(o: Observer, origin: Vector2, bearing: float, near: Array[int],
		touches: bool) -> Array:
	var dir := o.forward * cos(bearing) + o.starboard * sin(bearing)
	var best := o.beam_range
	var found := false
	var body := -1
	for i: int in near:
		var b := _cells[i] if i >= 0 else _me
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
			body = i
	# **The meniscus stops a ray** (the drop, §3.2), and it is no body: the ray
	# reports its distance and it earns the beam nothing, which counts bodies.
	# Nor does a floc, which is matter and stops it, and was never alive.
	if _drop != null:
		var edge := _drop.meniscus.exit_along(origin, dir)
		if edge < best:
			best = edge
			found = true
			body = EDGE_BODY
	if touches and found and body >= 0 and not _cells[body].inert \
			and not beam_touched.has(body):
		beam_touched.append(body)
	return [bearing, best, found, body]


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
	_call_t += delta
	if ping_range <= 0.0 or ping_period <= 0.0:
		# The organ was lost, or was never grown. Anything still in flight is
		# dropped rather than delivered: it was never heard.
		_echoes.clear()
		_pulses.clear()
		ping_fronts.clear()
		ping_listen = 0.0
		_ping_clock = 0.0
		_ping_age = -1.0
		if not player_calls.is_empty():
			player_calls.clear()
		return
	# **The player's returns, kept for their instincts until they ring out**
	# (automation.md §4.1), as a water cell keeps its own: at most five, once a
	# call. Let go here as well as where they are read, so a run whose instincts
	# never read them keeps no more than one call's worth.
	for k in range(player_calls.size() - 1, -1, -1):
		if float((player_calls[k] as Array)[4]) <= _call_t:
			player_calls.remove_at(k)

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


## **How loud a pulse is once its wave has travelled [param path] units**, from
## an organ whose echoes carry [param reach]: 1 at the skin, 0 when the path is
## `2 * reach`. The one law every ping is heard by -- this cell's echoes in
## [method _cast_ping], and a friend's call in `normal_mode.gd`'s
## `_hear_others` -- so the two cannot drift apart. [param reach] must be above
## zero, which both callers already see to.
##
## Two terms, both about the path and nothing else:
##
## - [constant PING_FALLOFF]'s fade. An echo's path is out and back, `2d`, so
##   `1 - 2d / (2 * reach)` is the `1 - d / reach` it always was and no echo
##   moves by it. A friend's call comes one way, `d`, so the same law hears it
##   louder and to twice the reach her own echoes come home from.
## - [constant PING_ATTENUATION], the water's own absorption.
##
## Occlusion is not in here. It is about what is in the way, not how far the
## wave went, and it multiplies on at the call site.
static func ping_level(path: float, reach: float) -> float:
	return pow(clampf(1.0 - path / (2.0 * reach), 0.0, 1.0), PING_FALLOFF) \
		* exp(-PING_ATTENUATION * path)


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
##
## What they multiply into is [method ping_level] over the echo's whole path,
## out and back.
##
## **The player's call**, through [method _call_of], the one function every
## observer calls by: its returns go into [member _echoes], where they fly home
## -- and into [member player_calls] as a water cell keeps its own
## ([method _call_now]), for the player's instincts to read from the moment each
## lands until it rings out (automation.md §4.1).
func _cast_ping() -> void:
	var from := _echoes.size()
	_call_of(_player_eye(), _sense_ids(), _echoes)
	for k in range(from, _echoes.size()):
		var one: Array = _echoes[k]
		var due := float(one[0])
		var hold := float(one[4])
		player_calls.append([_call_t + due, one[1], due * PING_SPEED * 0.5,
			hold * PING_SPEED / (2.0 * PING_RING), _call_t + due + hold])


## **An observer's call** (behaviour.md §12.1): the returns its pulse would
## bring home off the bodies in [param scan], appended to [param out] as `[due,
## at, level, width, hold]` -- seconds until it lands, the place it came off,
## how loud, how wide the organ reports it and how long it rings -- as
## [method _cast_ping] above describes. Read off the observer and those bodies
## and nothing else.
func _call_of(o: Observer, scan: PackedInt32Array, out: Array) -> void:
	# Clamped here and not trusted: the run writes it every frame, and a headless
	# boot casts a pulse before the first write lands.
	var tier := clampi(o.ping_tier, 0, PING_RETURNS_BY_TIER.size() - 1)
	if PING_RETURNS_BY_TIER[tier] <= 0:
		return
	var dir := o.forward * cos(o.ping_bearing) + o.starboard * sin(o.ping_bearing)
	var origin := o.pos + dir * o.radius
	var found: Array = []
	for i: int in scan:
		if i == o.slot:
			continue
		var b := _cells[i] if i >= 0 else _me
		if not b.seeded:
			continue
		# A floc is far smaller than the wave: a speck does not echo, and the
		# pulse's few returns stay for bodies (§7.5). The drop only has them.
		if b.inert:
			continue
		# Reach is still measured from the middle of the cell, as it always has
		# been: moving the origin is about what the pulse can *see*, not about
		# how far it carries or how a return fades, and a range that changed
		# with the slot would make one slot strictly the best place for a radar.
		var d := b.pos.distance_to(o.pos) - b.radius
		if d >= o.ping_range:
			continue
		found.append([maxf(d, 0.0), b.pos, b.radius])
	# **The meniscus answers** (the drop, §3.2): the largest reflector a pulse
	# can meet, heard from its nearest point as one body EDGE_ECHO_RADIUS wide
	# -- the widest, longest echo in the game. The hull, the bodies in the way
	# and the returns' cap take their share of it exactly as of a body's.
	if _drop != null:
		var edge := _drop.meniscus.depth(o.pos)
		if edge < o.ping_range:
			found.append([maxf(edge, 0.0), _drop.meniscus.nearest_rim(o.pos),
				Drop.EDGE_ECHO_RADIUS])
	if found.is_empty():
		return
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var heard: Array = []
	for i in found.size():
		var at: Vector2 = found[i][1]
		# **Out and back**: to the near edge and home again, so the wave has
		# travelled `2d` by the time the organ hears it.
		var level := ping_level(2.0 * float(found[i][0]), o.ping_range)
		var path := at - origin
		var reach := path.length()
		# The hull. A body touching the organ has no direction to be on either
		# side of, and `normalized()` on a zero vector is zero: the smoothstep
		# lands mid-fade, which is the only honest answer to "which side".
		var open := smoothstep(-PING_GRAZE, PING_GRAZE,
			path.normalized().dot(dir))
		level *= lerpf(o.ping_through, 1.0, open)
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
			level *= lerpf(o.ping_through, 1.0, clear)
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
		out.append([due, heard[i][1], heard[i][2], heard[i][3], heard[i][4]])


## `palp`. The nearest body inside touch range, as a bearing and a closeness --
## 1 against the skin, 0 at the edge of reach. No light, no chemistry, no size:
## touching something tells you it is there and nothing else, which is exactly
## what makes it worth a slot to a cell that cannot see.
##
## **The player's touch**, through [method _touch_of], the one function every
## observer touches by. The bearing is left where it was while nothing is near.
func _step_touch() -> void:
	touch_level = 0.0
	if touch_range <= 0.0 or _cell == null:
		return
	var o := _player_eye()
	_touch_of(o, _sense_ids())
	if not o.touched:
		return
	touch_level = o.touch
	touch_bearing = o.touch_bearing


## **What an observer touches** (behaviour.md §12.1): the nearest surface of the
## bodies in [param scan] -- and of the rim -- within its `palp`'s reach of its
## skin, as a closeness and a bearing on [param o], or nothing.
func _touch_of(o: Observer, scan: PackedInt32Array) -> void:
	o.touched = false
	o.touch = 0.0
	if o.touch_range <= 0.0:
		return
	var best := INF
	var at := Vector2.ZERO
	# A floc is touched too (§7.5): it is there.
	for i: int in scan:
		if i == o.slot:
			continue
		var b := _cells[i] if i >= 0 else _me
		if not b.seeded:
			continue
		var d := b.pos.distance_to(o.pos) - b.radius - o.radius
		if d < best:
			best = d
			at = b.pos
	# **And so is the meniscus** (the drop, §3.2): the nearest thing there is.
	if _drop != null:
		var edge := _drop.meniscus.depth(o.pos) - o.radius
		if edge < best:
			best = edge
			at = _drop.meniscus.nearest_rim(o.pos)
	if best >= o.touch_range:
		return
	o.touched = true
	o.touch = clampf(1.0 - maxf(best, 0.0) / o.touch_range, 0.0, 1.0)
	o.touch_bearing = o.bearing_to(at)


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


# ---------------------------------------------------------------------------
# **A field a replay writes into** (docs/design/ocean.md §11, replay.md §3).
# The replay binds one of these of its own and never the run's: the drop
# outlives the run and the player goes back into it after watching, so the
# recording is written onto a field that is nothing but a picture of it. It is
# never processed; every number in it arrives from the recording, and the views
# read it exactly as they read a live one.
# ---------------------------------------------------------------------------

## True for a field [method open_replay] made. Nothing in a run reads it.
var _replay := false
## How many recorded bodies it holds. Its flocs are in the slots after them.
var _replay_slots := 0
## Each floc the recording has settled and not yet cleared, by its id: its slot.
var _replay_flocs := {}
## Who the recording says killed the player, as a slot; -1 for nobody.
var _killer := -1


## **Makes this a replay's field**: [param slots] bodies, every one of them
## empty until the recording writes it, no rim until [method restore_rim], and
## [param cell] as the player -- the run's own cell, which the replay writes
## the recorded player onto. Call it on a field no run owns, and keep that field
## from processing: nothing here may step.
func open_replay(cell: CellBody, slots: int) -> void:
	_cell = cell
	_replay = true
	_replay_slots = maxi(slots, 0)
	_drop = null
	_pond = false
	_mirror = false
	_guests = 1
	_water = 0
	in_water = true
	anchored = false
	_book.clear()
	_cells.clear()
	for i in _replay_slots:
		_cells.append(Body.new())
	_replay_flocs.clear()
	_killer = -1
	died_to = -1
	_fresh_senses()


## **The drop's rim, written back from a recording**: this field is in the drop
## from here, with its meniscus at [param center] and [param radius], and every
## body in it filed in a grid of its own -- which is what the view asks what is
## on screen. Nothing happens if the rim is already there. **Never the friend**,
## who is in no grid in a live pond either (ocean.md §10.2): filed, they would be
## drawn a second time, as a water cell.
func restore_rim(center: Vector2, radius: float) -> void:
	if _drop != null and _drop.meniscus.center == center \
			and _drop.meniscus.radius == radius:
		return
	_drop = Drop.new(center)
	_drop.meniscus.radius = radius
	for i in _cells.size():
		if _cells[i].seeded and _cells[i].person == null:
			_drop.grid.insert(i, _cells[i].pos)


## **A replay's field with the other player in it** (shared-pond.md §5, Phase
## 3): a pond's, so the view draws the friend as it does in a live one -- from
## [constant PERSON_SLOT], where every client keeps them -- with nobody there
## until [method restore_person]. Its flocs go past the slot, and the slots
## between the recorded bodies and it stay empty. A field [method open_replay]
## made only.
func open_replay_person() -> void:
	if not _replay:
		return
	_pond = true
	while _cells.size() <= PERSON_SLOT:
		_cells.append(Body.new())
	_replay_slots = maxi(_replay_slots, PERSON_SLOT + 1)


## **The friend, written back from a recording**: their body in
## [constant PERSON_SLOT] -- where, which way, how big, their wound, what they
## carry as [method pack_loads] packed it, and whether they are in the water,
## which is what unseeds a person here as it does live. [param radius] 0 is
## nobody, and then there is no person at all. Out of every grid, as a person
## always is. A field [method open_replay_person] made only, never a run's.
func restore_person(at: Vector2, heading: float, radius: float, wound: float,
		packed_loads: float, wet: bool) -> void:
	if not _replay or not _pond or _cells.size() <= PERSON_SLOT:
		return
	var pb := _cells[PERSON_SLOT]
	if radius <= 0.0:
		pb.person = null
		pb.seeded = false
		pb.radius = 0.0
		pb.loads.fill(0.0)
		return
	if pb.person == null:
		pb.person = Person.new()
		pb.drifter = false
	pb.person.in_water = wet
	pb.pos = at
	pb.heading = heading
	pb.radius = radius
	pb.wound = wound
	pb.seeded = wet
	unpack_loads(packed_loads, pb.loads)


## What the friend wears, written back from a recording: their worn tiers and
## the slot each is worn in, as PERSON said them -- the fringe the view draws, and
## the mouth that decides their threat bow. Stepped, never interpolated.
func restore_person_genome(tiers: Dictionary, order: Array) -> void:
	if not _replay or not _pond or _cells.size() <= PERSON_SLOT:
		return
	var pb := _cells[PERSON_SLOT]
	# The order first: writing the genome reads what it buys, the seated dart's stun
	# among it, under the order it is worn in (gene-catalogue.md §15.6).
	pb.order = order
	pb.genome = tiers


## **Where a body was, written back from a recording.** The one thing in this
## file that is not simulation, and it is only ever done to a replay's own field
## ([method open_replay]): the views read these bodies exactly as they read a
## live field's.
##
## It deliberately writes only what the trace carries. Nothing here touches a
## state machine, a target, a serial or a clock -- a body being replayed is not
## deciding anything. **A radius of 0 is nobody**, as a retired slot is in a
## mirror: the slot is empty, and neither view draws it.
func restore_body(index: int, pos: Vector2, heading: float, radius: float,
		wound: float) -> void:
	if index < 0 or index >= _cells.size():
		return
	var b := _cells[index]
	b.pos = pos
	b.heading = heading
	b.radius = maxf(radius, 0.0)
	b.wound = wound
	b.seeded = radius > 0.0
	if _drop == null:
		return
	if b.seeded:
		_drop.grid.move(index, pos)
	else:
		_drop.grid.remove(index)


## **What a body carried, written back from a recording** (docs/design/
## dna-slots.md §13): its loads, as [method pack_loads] packed them into one
## float. A replay's field only, as [method restore_body] is.
func restore_loads(index: int, packed: float) -> void:
	if index < 0 or index >= _cells.size():
		return
	unpack_loads(packed, _cells[index].loads)


## **A body's three loads in one float** (docs/design/dna-slots.md §13), for the
## replay: `h + 256 p + 65536 s`, each `round(stacks x 4)` clamped to 0..255 -- a
## quarter of a stack, to 63.75 stacks, against the largest swallow dose of 48. A
## float32 holds 24 bits exactly, so nothing is lost in the ring.
static func pack_loads(loads: PackedFloat64Array) -> float:
	var packed := 0
	var place := 1
	for k in mini(loads.size(), Doses.KINDS):
		packed += clampi(roundi(loads[k] * 4.0), 0, 255) * place
		place *= 256
	return float(packed)


## [method pack_loads] undone, into [param into]'s three kinds.
static func unpack_loads(packed: float, into: PackedFloat64Array) -> void:
	var left := maxi(roundi(packed), 0)
	for k in mini(into.size(), Doses.KINDS):
		into[k] = float(left % 256) / 4.0
		left /= 256


## **Who was hunting the player, written back from a recording.**
##
## [method restore_body] deliberately writes no state machine, which is right --
## a body being replayed is not deciding anything. But [method hunter] *is* a
## question about the state machine, and `vision.gd` draws the dread, wake and
## lunge rings off its answer. Left alone, every replayed body answers DRIFT and
## the rings never draw at all: the truth pane loses the one instrument that
## explains a predation death, in exactly the case it exists for.
##
## So the recording carries the slot and this puts it back, on these two fields
## and nothing else -- the two [method hunter] reads. [param index] is -1 for
## nobody, which is also what a frame with no stalker recorded.
##
## Every other claim on the player is cleared on the way past, because a slot
## that held a stalker a moment ago may hold another body now, and a replayed
## frame must not inherit the last one's answer.
func restore_hunter(index: int) -> void:
	for i in _cells.size():
		var b := _cells[i]
		if i == index:
			b.state = State.STALK
			b.target = TARGET_PLAYER
		elif b.state == State.STALK and b.target == TARGET_PLAYER:
			b.state = State.DRIFT
			b.target = TARGET_NONE


## **Who killed the player, written back from a recording** (ocean.md §11):
## the slot of the body that swallowed or chewed the cell, or whose dose finished
## it, on the frames the recording names it; -1 on every other. [method
## hunter] answers only for a stalker, and in the drop most deaths by mouth are
## not a stalker's, so this is what the view draws the predator rings round when
## nothing is hunting.
func restore_killer(index: int) -> void:
	_killer = index if index >= 0 and index < _cells.size() else -1


## The slot [method restore_killer] last wrote, when that body is there; -1
## otherwise, and always in a run's own field, which is never written one.
func killer() -> int:
	if _killer < 0 or _killer >= _cells.size() or not _cells[_killer].seeded:
		return -1
	return _killer


## The same, for the one part of a body that is not a float. Stepped at the
## moments the recording says it changed, never interpolated -- and what the
## body's organs buy is read again from it, so the view measures its mouth and
## its armour as the live one did.
func restore_genome(index: int, genome: Dictionary) -> void:
	if index < 0 or index >= _cells.size():
		return
	var b := _cells[index]
	b.genome = genome
	b.inert = false
	_refresh_body(b)


## **A floc, written back from a recording** (ocean.md §11): made in a slot past
## the recorded bodies the first time its [param id] is seen, and set to lie at
## [param at], [param radius] across, [param settle] of the way into focus. A
## floc never moves, and how far it has settled is a function of time, so the
## replay works [param settle] out and hands it over every frame. The id is the
## floc's own, which is what its drawn shape is made from.
func restore_floc(id: int, at: Vector2, radius: float, settle: float) -> void:
	var index: int = int(_replay_flocs.get(id, -1))
	if index < 0:
		index = _replay_slots
		while index < _cells.size() and _cells[index].seeded:
			index += 1
		if index >= _cells.size():
			_cells.append(Body.new())
		_replay_flocs[id] = index
	var b := _cells[index]
	b.id = id
	b.inert = true
	b.drifter = true
	b.genome = {}
	b.radius = radius
	b.pos = at
	b.settle = clampf(settle, 0.0, 1.0)
	b.state = State.DRIFT
	b.target = TARGET_NONE
	b.seeded = true
	if _drop != null:
		_drop.grid.move(index, at)


## A floc the recording cleared: eaten, dissolved, or out of the recorder's reach.
func clear_floc(id: int) -> void:
	var index: int = int(_replay_flocs.get(id, -1))
	if index < 0:
		return
	_replay_flocs.erase(id)
	_cells[index].seeded = false
	_cells[index].radius = 0.0
	if _drop != null:
		_drop.grid.remove(index)


## Every floc cleared, for a replay starting its window again.
func clear_flocs() -> void:
	for id: int in _replay_flocs.keys():
		clear_floc(id)


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
##
## In the drop it asks the bodies near the cell the frame gathered: a body
## farther than every sense can reach is hunting nothing it can find. A replay's
## field gathers nothing -- it is never stepped -- and asks every body it holds,
## which are the recorded ones near the cell.
##
## **On rules there is no run** (behaviour.md §4.3), and this is the nearest
## cell coming for you: swimming, you within 35 degrees of its heading, a mouth
## that could take you. A mirror reads it off the host's flag and a replay off
## the recording, as before.
func hunter() -> int:
	if _ruled():
		return _nearest_coming()
	var best := -1
	var best_d := INF
	for i: int in (_near if _drop != null and not _replay else _all_ids()):
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
##
## **In the drop the pond is the drop** (ocean.md §10.2): the host's own, with
## everything in it, and the other player's body in [constant PERSON_SLOT] as
## everywhere -- see [method _open_drop_pond].
func open_pond() -> void:
	if _pond or _cell == null:
		return
	if _drop != null:
		_open_drop_pond(1)
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


## **A dedicated host's water** (`game/server/`): **the room** (ocean.md
## §10.3) -- a drop that is nobody's, loaded from [param state] as drop_save.gd
## reads one, or made anew when it is empty -- with a slot for each of
## [constant GUESTS_MAX] guests and no body of its own. [param cell] stands in
## for the cell every rule here reads, and it is out of the water and no anchor
## for good -- every rule that asks about "this cell" asks [member in_water] or
## [member anchored] first -- so the water is its guests' alone. **It lives while
## nobody is in it**: with no anchor, every body is on its tick (§4.3), and
## [method empty_water] lets nothing go. Returns what [method load_drop] said,
## or nothing for a room made anew.
func open_dedicated(cell: CellBody, state: Dictionary = {}) -> Dictionary:
	var done := {}
	if state.is_empty():
		_make_room(cell)
	else:
		done = load_drop(cell, state)
	in_water = false
	anchored = false
	_first_pending = false
	_first_hunt = FIRST_DELAY
	_open_drop_pond(GUESTS_MAX)
	_fresh_senses()
	return done


## **Today's water, as a dedicated host kept it before the room** -- an empty
## pond that seeds round whoever arrives and lets its water go when the last
## guest leaves. Nothing ships it: a tool's reference for the bubble.
func open_bubble_dedicated(cell: CellBody) -> void:
	_drop = null
	_cell = cell
	_pond = true
	_mirror = false
	_guests = GUESTS_MAX
	in_water = false
	anchored = false
	_first_pending = false
	_first_hunt = FIRST_DELAY
	_snap_at = PackedVector2Array()
	_snap_age = 0.0
	_book.clear()
	_cells.clear()
	for i in PERSON_SLOT + GUESTS_MAX:
		_cells.append(Body.new())
	_water = PERSON_SLOT
	_seeded_for = PackedInt64Array()
	_seeded_for.resize(Anchor.PERSON + GUESTS_MAX)
	_stamp = 0
	_fresh_senses()
	_changes += 1


## **A dedicated host with nobody left on it** lets its water go: every cell
## retired, so an empty server simulates nothing and the next guest meets water
## made for them. A guest who is only dead keeps theirs -- they are coming back
## to it -- so this is for the last one leaving, and never for a phone's pond.
##
## **The room lets nothing go** (ocean.md §10.3): a drop lives on with nobody
## in it, so in the drop this does nothing at all.
func empty_water() -> void:
	if not _pond or _mirror or _drop != null:
		return
	for i in _water:
		if _cells[i].seeded:
			_retire(i)


func pond_open() -> bool:
	return _pond


func mirroring() -> bool:
	return _mirror


## The other player's record, or null when nobody else is in this water.
## [param slot] is which person, on a dedicated host that has two; every call
## below takes it the same way, last and defaulted, so a phone's pond reads
## exactly as it always has.
func person(slot: int = PERSON_SLOT) -> Person:
	if not _pond or not _is_person_slot(slot) or _cells.size() <= slot:
		return null
	return _cells[slot].person


## **Where the other player is**, as they last reported it: place, heading,
## radius, and the velocity and turn rate the field carries them on by until the
## next report -- under the water's own drag, so a phone that goes quiet leaves
## a body that coasts and stops, still edible and still biting (§1.8).
##
## The first call is an **arrival**: a new body, a new serial and
## [constant FIRST_DELAY] of grace, which is what every [method setup] grants
## this cell. Anything not finite is refused whole, as the wire refuses it.
func place_person(at: Vector2, heading: float, body_radius: float,
		velocity: Vector2 = Vector2.ZERO, turning: float = 0.0,
		slot: int = PERSON_SLOT) -> void:
	if not _pond or _mirror:
		return
	if not _is_person_slot(slot) or _cells.size() <= slot:
		return
	if not at.is_finite() or not is_finite(heading) or not is_finite(body_radius) \
			or body_radius <= 0.0:
		return
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	if not is_finite(turning):
		turning = 0.0
	# **Held inside the drop's rim** (ocean.md §10.5), as everything in it is:
	# an honest guest's own run contains its cell the same way.
	if _drop != null:
		at = _drop.meniscus.contain(at, body_radius)
	var pb := _cells[slot]
	if pb.person == null:
		pb.person = Person.new()
		pb.person.slot = slot
		pb.person.first_hunt = FIRST_DELAY
		_serial += 1
		pb.serial = _serial
		pb.meals = 0
		pb.wound = 0.0
		pb.loads.fill(0.0)
		pb.dosed_by = -1
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
func set_person_genome(tiers: Dictionary, order: Array,
		slot: int = PERSON_SLOT) -> void:
	if not _pond or not _is_person_slot(slot) or _cells.size() <= slot:
		return
	var pb := _cells[slot]
	# The order first: writing the genome reads what it buys, the seated dart's stun
	# among it, under the order it is worn in (gene-catalogue.md §15.6).
	pb.order = order.duplicate()
	pb.genome = tiers.duplicate()
	if pb.person != null:
		_derive_person(pb)
	_changes += 1


func _derive_person(pb: Body) -> void:
	var p := pb.person
	var tiers := pb.genome
	p.swim_speed = CellBody.swim_speed_of(tiers)
	p.armour = Stats.of(tiers, &"armor")
	# The dart that fires, all of it (stats.gd's `seated`): the first in their order.
	p.dart_range = Stats.seated(pb.order, tiers, &"dart_range")
	p.dart_cooldown = Stats.seated(pb.order, tiers, &"dart_cooldown")
	var slot := _seat_of(pb.order, tiers, &"dart_range")
	p.dart_bearing = Cilia.slot_bearing(slot) if slot >= 0 else 0.0
	# Their toxins are read off their body and its worn order where a bite asks
	# for them ([method _toxins_at]), as every body's are: a venom on a side
	# guards the side of the slot they wear it in (dna-slots.md §7.2).
	# The body carries it too, so a sense that weighs every body by the size a
	# mouth measures -- the drop's taste (§14.1) -- weighs a person as one.
	pb.armour = p.armour


## The other player has left the water, dividing, or come back into it. Out
## of it they are still an anchor, and nothing in the water can see them, touch
## them or go on chasing them (§1.5).
func set_person_in_water(on: bool, slot: int = PERSON_SLOT) -> void:
	var p := person(slot)
	if p == null:
		return
	p.in_water = on
	_cells[slot].seeded = on


## Their phone has gone quiet, or been heard again. Nothing here changes: see
## [member Person.quiet].
func set_person_quiet(on: bool, slot: int = PERSON_SLOT) -> void:
	var p := person(slot)
	if p != null:
		p.quiet = on


## **The other player is gone from this water** -- dead, or no longer on the
## wire. The slot empties and takes a new serial, so nothing still chasing them
## can carry on against whoever arrives next. Their genome is kept for the next
## arrival, which a new PERSON replaces.
func remove_person(slot: int = PERSON_SLOT) -> void:
	if not _pond or not _is_person_slot(slot) or _cells.size() <= slot:
		return
	var pb := _cells[slot]
	pb.person = null
	pb.seeded = false
	pb.radius = 0.0
	pb.speed = 0.0
	pb.wound = 0.0
	pb.loads.fill(0.0)
	pb.dosed_by = -1
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
##
## **In the drop this is a division** (§8.2): the daughter is where her mother
## was, in her mother's water, with the grace a birth gives -- and no first
## drifter placed for her: her mother's water is round her. A return after a
## death is [method return_to_drop].
func enter_water() -> void:
	in_water = true
	anchored = true
	# **Nothing has killed this cell**, as every arrival says ([method _arrive]):
	# a return in a pond comes back here and not through one, and a killer left
	# over from the last death would be named again by the recorder at the next
	# -- rings round an innocent body in its replay (shared-pond.md Phase 3).
	died_to = -1
	_first_hunt = FIRST_DELAY if _drop == null else grace
	if _drop != null:
		_first_pending = false
	_fresh_senses()


## **A sister, in a pond** (§1.5): the declined daughter left in the water at
## [param at] with [param heading], in the first free slot -- or, with none free,
## in place of the body farthest from every anchor that is neither a drifter nor
## hunting a player. For this cell's own birth through [method put_sister], and
## for the other player's through SISTER. Returns the slot she took, or -1.
##
## **In the drop she is a daughter** (lineage.md §4), wearing [param tiers] and
## carrying [param dna], the child of [param mother] -- see [method _born_of].
## **A guest's sister** comes by SISTER, which since protocol 6 says what she
## wears, the DNA she was made of and the list her cell ran (automation.md
## §10.3), and never her record: ids are per drop, so she arrives as the founder
## of a line of her own. A protocol-5 SISTER said her body alone, and she came
## with her DNA equal to it -- the one place a newborn's genes were not all
## passed on (lineage.md §8).
func place_sister(at: Vector2, heading: float, body_radius: float,
		tiers: Dictionary, dna := {}, mother := PackedInt32Array(),
		brain: Variant = null) -> int:
	if not _pond or _mirror or _cell == null:
		return -1
	at = _clear_of_players(at, body_radius)
	# **In the drop she comes in by the one door every body does**, held inside
	# the rim, a water cell from then on -- as the host's own sister does --
	# carrying [param brain], the list her cell ran (automation.md §6.3), or the
	# founders' for null.
	if _drop != null:
		var index := _spawn(_drop.meniscus.contain(at, body_radius), false, _sensed(),
			false, body_radius, tiers)
		_cells[index].heading = heading
		_cells[index].brain = brain
		_born_of(_cells[index], dna, mother)
		_stat(&"sisters")
		return index
	var slot := _free_slot()
	if slot < 0:
		slot = _farthest_spare()
	if slot < 0:
		return -1
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
	return slot


## **A sister never lands on a player.** She goes SISTER_DISTANCE to her side,
## wherever that is, and the other player can be standing there: found by
## `net_probe`, when an arrival still landed at the same 560 along the world
## horizontal and she landed on the host, shoving it 14 units in its own
## daughter's first frame. She is moved straight out from any player she would
## overlap until the two are [constant SISTER_CLEAR] apart, and no further, so
## she stays on her side.
func _clear_of_players(at: Vector2, body_radius: float) -> Vector2:
	var players: Array = []
	if anchored:
		players.append([_cell.position, _cell.radius])
	for k in _guests:
		var pb := _cells[PERSON_SLOT + k]
		if pb.person != null:
			players.append([pb.pos, pb.radius])
	for each: Array in players:
		var centre: Vector2 = each[0]
		var reach := float(each[1]) + body_radius + SISTER_CLEAR
		var away := at - centre
		if away.length() >= reach:
			continue
		at = centre + (away.normalized() if away.length() > 0.001 else Vector2.RIGHT) \
			* reach
	return at


## **The other player's new body**, where the old one divided (shared-pond.md
## §1.5): a new serial -- so nothing that was chasing the mother carries on
## against the daughter -- no wound, a reloaded mouth and dart, and a new
## cell's grace, which is what [method enter_water] gives this cell at its own
## birth. Their place and what they wear arrive as ever, by [method
## place_person] and [method set_person_genome]. Host only.
func renew_person(slot: int = PERSON_SLOT) -> void:
	if _mirror:
		return
	var p := person(slot)
	if p == null:
		return
	var pb := _cells[slot]
	_serial += 1
	pb.serial = _serial
	pb.meals = 0
	pb.wound = 0.0
	# A daughter is a new body: she carries none of her mother's doses.
	pb.loads.fill(0.0)
	pb.dosed_by = -1
	pb.bite = 0.0
	p.first_hunt = FIRST_DELAY
	p.dart_clock = 0.0
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
## -- and so is everything its organs were still listening for. **A drop it was
## in is the caller's to set aside first** (ocean.md §9.1): `drop_state()`,
## taken up again by [method leave_mirror]. The host's rim comes with its
## ARRIVE ([method mirror_rim]); until then this mirror is in no drop.
func become_mirror() -> void:
	if _cell == null:
		return
	_mirror = true
	_pond = true
	_guests = 1
	_first_pending = false
	in_water = true
	anchored = true
	_drop = null
	_cells.clear()
	for i in POND_SLOTS:
		_cells.append(Body.new())
	_water = PERSON_SLOT
	_snap_at = PackedVector2Array()
	_snap_at.resize(POND_SLOTS)
	_snap_age = 0.0
	_book.clear()
	_mirror_slots.clear()
	_mirror_flocs.clear()
	_mirror_free.resize(0)
	for i in range(PERSON_SLOT - 1, -1, -1):
		_mirror_free.append(i)
	_mirror_t = 0.0
	_near.resize(0)
	_stepped.resize(0)
	_fresh_senses()
	_changes += 1


## **The drop the host's water is** (ocean.md §10.4), from its ARRIVE: this
## mirror's meniscus at [param center] and [param radius] -- drawn, holding this
## cell inside it, and heard and seen with this cell's own organs -- and every
## body it holds filed in a grid of its own, which is what the view asks what is
## on screen. A radius of 0 is a host in today's water: no rim.
func mirror_rim(center: Vector2, radius: float) -> void:
	if not _mirror:
		return
	if not (radius > 0.0) or not is_finite(radius) or not center.is_finite():
		_drop = null
		return
	if _drop != null and _drop.meniscus.center == center \
			and _drop.meniscus.radius == radius:
		return
	_drop = Drop.new(center)
	_drop.meniscus.radius = radius
	for i in _cells.size():
		if i != PERSON_SLOT and _cells[i].seeded:
			_drop.grid.insert(i, _cells[i].pos)


## **The host's rim, for its ARRIVE**: `[center, radius]`, radius 0 for today's
## water.
func rim() -> Array:
	if _drop == null:
		return [Vector2.ZERO, 0.0]
	return [_drop.meniscus.center, _drop.meniscus.radius]


## **The host is gone, and this water is yours** (§1.8): a fresh single-player
## water round this cell, which is [method setup] -- what every new water has
## always been -- or, given [param state], **your own drop, taken up again**
## (ocean.md §9.1): as it was set aside, with this cell come back into it at a
## quiet place ([method return_to_drop]). The body, the genome, the generation
## and the hunger are not this node's, and nothing here touches them. Returns
## what [method load_drop] said, or nothing.
func leave_mirror(state: Dictionary = {}) -> Dictionary:
	if not _mirror:
		return {}
	_mirror_slots.clear()
	_mirror_flocs.clear()
	if state.is_empty():
		setup(_cell)
		return {}
	var done := load_drop(_cell, state)
	return_to_drop()
	return done


## **One snapshot of this water, as a mirror reads it** (§2's POND, ocean.md
## §10.4): an Array per body, indexed by [enum Entry], with this field's own slot
## for it after them at [constant ENTRY_SLOT].
##
## [param for_person] true is the snapshot for the guest: "stalking you" means
## stalking them, the send set is measured from them, and the person in it is
## this cell. False is a snapshot for a mirror of this very cell, which is how
## Phase 1 proves the mirror senses exactly what the field does.
##
## The send set is [method _send_set]'s: every body hunting the recipient,
## wherever it is, so that the mirror's [method hunter] always agrees with the
## host's, and the nearest of the rest whose surface lies within [param reach]
## -- [constant SEND_MAX] in all.
func pond_entries(for_person: bool, reach: float = SEND_REACH) -> Array:
	var out: Array = []
	if not _pond or _mirror or _cell == null:
		return out
	var pb := _cells[PERSON_SLOT]
	if for_person and pb.person == null:
		return out
	if for_person:
		out = _send_set(pb.pos, PERSON_SLOT, pb.serial, reach)
		if anchored:
			out.append([PERSON_ID, 0,
				FLAG_PERSON | (FLAG_IN_WATER if in_water else 0) | dose_flags(_cell.loads),
				_cell.position, _cell.heading, _cell.radius, _cell.wound,
				_cell.velocity.length(), _cell.velocity, _cell.heading_rate(), -1])
		return out
	out = _send_set(_cell.position, TARGET_PLAYER, 0, reach)
	if pb.person != null:
		out.append([PERSON_ID, pb.meals,
			FLAG_PERSON | (FLAG_IN_WATER if pb.person.in_water else 0) | dose_flags(pb.loads),
			pb.pos, pb.heading, pb.radius, pb.wound, pb.person.velocity.length(),
			pb.person.velocity, pb.person.turning, -1])
	return out


## **What a snapshot says of a body's loads** (docs/design/dna-slots.md
## §14.2): [constant FLAG_HARMED] for harm past `DOSE_GONE`, and the two later
## kinds' bits the same way. Never how many stacks: a guest draws a dose, it does
## not read one.
static func dose_flags(loads: PackedFloat64Array) -> int:
	var flags := 0
	if loads.size() > Doses.Kind.HARM and loads[Doses.Kind.HARM] > CellBody.DOSE_GONE:
		flags |= FLAG_HARMED
	if loads.size() > Doses.Kind.PARALYSIS \
			and loads[Doses.Kind.PARALYSIS] > CellBody.DOSE_GONE:
		flags |= FLAG_PARALYSED
	if loads.size() > Doses.Kind.SLEEP and loads[Doses.Kind.SLEEP] > CellBody.DOSE_GONE:
		flags |= FLAG_ASLEEP
	return flags


## **A mirrored body's loads, from a snapshot's flags**: one stack's worth
## ([constant MIRROR_SHOWN], felt) of each kind its flags say it carries, none of
## the rest -- what a guest's views draw it with.
static func _loads_from_flags(into: PackedFloat64Array, flags: int, radius: float) -> void:
	var shown := MIRROR_SHOWN * (radius / CellBody.DOSE_SIZE) * (radius / CellBody.DOSE_SIZE)
	into[Doses.Kind.HARM] = shown if (flags & FLAG_HARMED) != 0 else 0.0
	into[Doses.Kind.PARALYSIS] = shown if (flags & FLAG_PARALYSED) != 0 else 0.0
	into[Doses.Kind.SLEEP] = shown if (flags & FLAG_ASLEEP) != 0 else 0.0


## **A dedicated host's snapshot for the guest in [param slot]** -- the same
## send set, measured from them, and "stalking you" meaning stalking them; and
## the other guest, if there is one with a body, **as the person** -- id
## [constant PERSON_ID], whichever slot they have here, meals 0 -- exactly the
## entry a phone host writes for its own cell. So a guest of a dedicated host
## mirrors its friend where a guest of a phone mirrors the host, and needs
## nothing a phone's guest does not (`game/server/`).
func pond_entries_for(slot: int, reach: float = SEND_REACH) -> Array:
	var out: Array = []
	if not _pond or _mirror or not _is_person_slot(slot) or _cells.size() <= slot:
		return out
	var pb := _cells[slot]
	if pb.person == null:
		return out
	out = _send_set(pb.pos, slot, pb.serial, reach)
	for k in _guests:
		var ob := _cells[PERSON_SLOT + k]
		if PERSON_SLOT + k == slot or ob.person == null:
			continue
		out.append([PERSON_ID, 0,
			FLAG_PERSON | (FLAG_IN_WATER if ob.person.in_water else 0) | dose_flags(ob.loads),
			ob.pos, ob.heading, ob.radius, ob.wound, ob.person.velocity.length(),
			ob.person.velocity, ob.person.turning, -1])
		break
	return out


## **The water bodies one snapshot carries**, for a recipient at [param you]
## whom a hunt names as [param target] -- a person's slot, or TARGET_PLAYER for
## this cell -- and, for a person, [param serial]. Every body hunting it goes
## first, wherever it is; then the rest whose surface lies within [param reach],
## nearest surface first, ties by slot; [constant SEND_MAX] in all. Never a
## person, and never a floc: a floc is told once, by SETTLE ([method flocs_in_reach]).
##
## **On rules the flag says "coming for you"** (behaviour.md §4.3, §8),
## computed here for each recipient as the run was: every body within reach that
## is coming for them goes first, by slot, then the rest as before. A body
## farther than every sense of theirs can reach is coming at nothing they can
## sense, and is not sent.
func _send_set(you: Vector2, target: int, serial: int, reach: float) -> Array:
	var out: Array = []
	var keys := PackedInt64Array()
	var scan := _water_ids()
	if _drop != null:
		_send_ids.resize(0)
		_drop.grid.query(you, reach + _widest_now + Drop.GRID_SLACK, _send_ids)
		scan = _send_ids
	if _ruled():
		return _send_coming(you, target, reach, scan)
	for i: int in scan:
		var b := _cells[i]
		if not b.seeded or b.inert or b.person != null or _stalks(b, target, serial):
			continue
		var gap := b.pos.distance_to(you) - b.radius
		if not (gap <= reach):
			continue
		keys.append((int(clampf(gap, 0.0, 1.0e6) * 16.0) << 24) | i)
	# **Every hunter, wherever it is**: a run outlives the send reach.
	var every := _cells.size() if _drop != null else _water
	for i in every:
		var b := _cells[i]
		if b.seeded and not b.inert and b.person == null and _stalks(b, target, serial):
			out.append(_entry_of(i, true))
			if out.size() >= SEND_MAX:
				return out
	keys.sort()
	for key: int in keys:
		if out.size() >= SEND_MAX:
			break
		out.append(_entry_of(key & 0xFFFFFF, false))
	return out


## [method _send_set] on rules: of the bodies in [param scan] within
## [param reach] of [param you], those coming for the recipient [param target]
## names first, by slot and flagged, then the rest nearest first.
func _send_coming(you: Vector2, target: int, reach: float, scan: PackedInt32Array) -> Array:
	var out: Array = []
	var keys := PackedInt64Array()
	var coming := PackedInt32Array()
	var p: Person = _cells[target].person if target >= 0 else null
	for i: int in scan:
		var b := _cells[i]
		if not b.seeded or b.inert or b.person != null:
			continue
		var gap := b.pos.distance_to(you) - b.radius
		if not (gap <= reach):
			continue
		if (target < 0 or p != null) and _coming_for_player(b, p):
			coming.append(i)
		else:
			keys.append((int(clampf(gap, 0.0, 1.0e6) * 16.0) << 24) | i)
	coming.sort()
	for i: int in coming:
		out.append(_entry_of(i, true))
		if out.size() >= SEND_MAX:
			return out
	keys.sort()
	for key: int in keys:
		if out.size() >= SEND_MAX:
			break
		out.append(_entry_of(key & 0xFFFFFF, false))
	return out


## Whether [param b] is on a run at the recipient a hunt names as [param target]
## (and, for a person, [param serial]).
func _stalks(b: Body, target: int, serial: int) -> bool:
	return b.state == State.STALK and b.target == target \
		and (target == TARGET_PLAYER or b.target_serial == serial)


## One water body's snapshot entry, [param stalking] the recipient or not, and
## whether it carries a dose.
func _entry_of(i: int, stalking: bool) -> Array:
	var b := _cells[i]
	return [_wire_id(b), b.meals, (FLAG_STALKING if stalking else 0) | dose_flags(b.loads),
		b.pos, b.heading, b.radius, b.wound, b.speed, Vector2.ZERO, 0.0, i]


## **A body's id on the wire** (ocean.md §10.4): in the drop the id it keeps for
## its life; in today's water its serial, which is as unique and never reused.
func _wire_id(b: Body) -> int:
	return b.id if _drop != null else b.serial


## **The flocs within [param reach] of [param point]**, surface to point, as
## SETTLE tells them: `[id, place, radius, settle, life]` each. Only the drop has
## flocs; a mirror's are the host's, and it is asked nothing.
func flocs_in_reach(point: Vector2, reach: float = SEND_REACH) -> Array:
	var out: Array = []
	if _drop == null or _mirror or not point.is_finite():
		return out
	_send_ids.resize(0)
	_drop.grid.query(point, reach + Drop.REMAINS_MAX + Drop.GRID_SLACK, _send_ids)
	for i: int in _send_ids:
		var b := _cells[i]
		if b.seeded and b.inert and b.pos.distance_to(point) - b.radius <= reach:
			out.append([b.id, b.pos, b.radius, b.settle, b.life])
	return out


## **A snapshot of the host's water arrives** (mirror only). Every body in it is
## put where the host had it, and carried on from there along its heading at the
## speed it was swimming -- for at most [constant CARRY_MAX], after which it
## holds -- and the person by the closed form of the water's drag. A body keeps
## the slot it came into this mirror in for as long as it is sent, found by its
## id; one that is not in the snapshot leaves this water, and its slot is free:
## out of the send set is out of every sense. [param your_wound] is this cell's
## own wound as the host last bit it (§0.1); this cell mends it itself until the
## next one. A floc is not in a snapshot: SETTLE and CLEAR tell those.
##
## **[param your_loads] are this cell's own loads as the host keeps them**
## (docs/design/dna-slots.md §14.1), stacks of each kind: this cell wears them,
## and is harmed by them, until the next snapshot says again -- and never dies of
## its own count, since the host owns that death. Empty says nothing. Every other
## body's loads are only its flags, drawn at [constant MIRROR_SHOWN].
func apply_pond(your_wound: float, entries: Array,
		your_loads := PackedFloat64Array()) -> void:
	if not _mirror:
		return
	if is_finite(your_wound):
		_cell.wound = clampf(your_wound, 0.0, 1.0)
	if not your_loads.is_empty():
		_cell.restore_loads(your_loads)
	var sent := {}
	var person_sent := false
	for entry: Array in entries:
		if entry.size() <= Entry.TURNING:
			continue
		var id := int(entry[Entry.ID])
		var flags := int(entry[Entry.FLAGS])
		var is_person := (flags & FLAG_PERSON) != 0
		if is_person != (id == PERSON_ID):
			continue
		if is_person:
			person_sent = true
			_mirror_person(_cells[PERSON_SLOT], entry, (flags & FLAG_IN_WATER) != 0)
			continue
		if sent.has(id) or _mirror_flocs.has(id):
			continue
		sent[id] = true
		var slot := int(_mirror_slots.get(id, -1))
		var b: Body = null
		if slot < 0:
			slot = _mirror_take_slot()
			_mirror_slots[id] = slot
			b = _cells[slot]
			# **A new body in this slot**: a new serial, so the view and the
			# recorder know it for another body, and nothing of the last.
			_serial += 1
			b.serial = _serial
			b.id = id
			b.inert = false
			b.meals = -1
			b.genome = {}
		b = _cells[slot]
		var meals := int(entry[Entry.MEALS])
		if meals != b.meals:
			# A new body version: its genome, if it has already come, and
			# otherwise what it had -- an unknown genome is inert in every rule,
			# and the same body grown keeps what it had until its GENOME lands.
			var key := _book_key(id, meals)
			if _book.has(key):
				b.genome = _book[key]
			b.meals = meals
			_mirror_refresh(b)
		b.pos = entry[Entry.AT]
		b.heading = float(entry[Entry.HEADING])
		b.radius = float(entry[Entry.RADIUS])
		b.wound = float(entry[Entry.WOUND])
		b.speed = float(entry[Entry.SPEED])
		b.seeded = true
		_loads_from_flags(b.loads, flags, b.radius)
		# **The stalking bit is the hunt, for everything this side reads:**
		# [method hunter], and through it the view's rings and the recorder.
		var stalking := (flags & FLAG_STALKING) != 0
		b.state = State.STALK if stalking else State.DRIFT
		b.target = TARGET_PLAYER if stalking else TARGET_NONE
		_snap_at[slot] = b.pos
		if _drop != null:
			_drop.grid.move(slot, b.pos)
	# Out of the snapshot is out of this water, and out of every hunt too: a
	# body the host retired stops being sent, and one left in STALK here would
	# go on answering [method hunter] for a hunter that no longer exists.
	#
	# **And it is drawn as nothing: radius 0, as the host's [method _retire]
	# leaves it.** A view that reads `points()` and `radii()` never asks
	# `seeded`, so a body eaten near the guest would otherwise stay drawn where
	# it died, a ghost in full vision.
	for id: int in _mirror_slots.keys():
		if not sent.has(id):
			_mirror_release(int(_mirror_slots[id]))
			_mirror_slots.erase(id)
	if not person_sent:
		var pb := _cells[PERSON_SLOT]
		pb.seeded = false
		pb.radius = 0.0
		pb.speed = 0.0
		pb.loads.fill(0.0)
		pb.state = State.DRIFT
		pb.target = TARGET_NONE
		pb.person = null
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
	pb.meals = int(entry[Entry.MEALS])
	pb.pos = p.at
	pb.heading = p.facing
	pb.radius = float(entry[Entry.RADIUS])
	pb.wound = float(entry[Entry.WOUND])
	pb.speed = float(entry[Entry.SPEED])
	pb.seeded = wet
	_loads_from_flags(pb.loads, int(entry[Entry.FLAGS]), pb.radius)


## **A body version's genome** (mirror only), as GENOME carries it once per
## version: remembered by the body's id and its meals, and worn at once if that
## body is already here at that version -- so it can arrive before its body or
## after it.
func apply_genome(id: int, meals: int, tiers: Dictionary) -> void:
	if not _mirror:
		return
	_book[_book_key(id, meals)] = tiers
	while _book.size() > BOOK_MAX:
		_book.erase(_book.keys()[0])
	var slot := int(_mirror_slots.get(id, -1))
	if slot >= 0:
		var b := _cells[slot]
		if b.meals == meals:
			b.genome = tiers
			_mirror_refresh(b)
			_changes += 1


## **A floc in this guest's reach, told by the host** (ocean.md §10.4): made
## in a slot of its own the first time its id is heard, and lying at
## [param at], [param radius] across, [param settle] of the way into focus with
## [param life] seconds left -- from which this mirror's own clock works out how
## far it has settled at every frame since, as the host's floc does
## ([method floc_settle_after]). A floc never moves. Mirror only.
func mirror_floc(id: int, at: Vector2, radius: float, settle: float,
		life: float) -> void:
	if not _mirror or id == PERSON_ID or not at.is_finite():
		return
	var slot := -1
	if _mirror_flocs.has(id):
		slot = int((_mirror_flocs[id] as Array)[0])
	elif _mirror_slots.has(id):
		return
	else:
		slot = _mirror_take_slot()
		_serial += 1
		_cells[slot].serial = _serial
	_mirror_flocs[id] = [slot, clampf(settle, 0.0, 1.0), maxf(life, 0.0), _mirror_t]
	var b := _cells[slot]
	b.id = id
	b.inert = true
	b.drifter = true
	b.genome = {}
	b.meals = 0
	b.radius = maxf(radius, 0.0)
	b.pos = at
	b.heading = 0.0
	b.wound = 0.0
	b.speed = 0.0
	b.settle = clampf(settle, 0.0, 1.0)
	b.life = maxf(life, 0.0)
	b.state = State.DRIFT
	b.target = TARGET_NONE
	b.seeded = true
	_refresh_body(b)
	_snap_at[slot] = at
	if _drop != null:
		_drop.grid.move(slot, at)
	_changes += 1


## A floc told by [method mirror_floc] is gone: eaten, dissolved, or out of
## reach. Mirror only.
func mirror_unfloc(id: int) -> void:
	if not _mirror or not _mirror_flocs.has(id):
		return
	_mirror_release(int((_mirror_flocs[id] as Array)[0]))
	_mirror_flocs.erase(id)
	_changes += 1


## **Every floc this mirror holds, gone** -- at an arrival, where the host starts
## telling this cell's flocs afresh (ocean.md §10.4). What it told before then
## and never took back -- eaten or dissolved while this cell was in the black,
## or left behind where it died -- is nothing this mirror should keep. Mirror
## only.
func mirror_forget_flocs() -> void:
	if not _mirror:
		return
	for id: int in _mirror_flocs.keys():
		mirror_unfloc(id)


## The mirror's genome book's key for body [param id] at [param meals] meals.
static func _book_key(id: int, meals: int) -> int:
	return (id << 8) | (meals & 0xFF)


## A free slot for a body or floc coming into this mirror: one a body left,
## or a new one past the person's. Never [constant PERSON_SLOT].
func _mirror_take_slot() -> int:
	if not _mirror_free.is_empty():
		var slot := _mirror_free[_mirror_free.size() - 1]
		_mirror_free.resize(_mirror_free.size() - 1)
		return slot
	_cells.append(Body.new())
	_snap_at.resize(_cells.size())
	return _cells.size() - 1


## A body or floc leaves this mirror: nobody, drawn as nothing, and its slot
## free for the next.
func _mirror_release(slot: int) -> void:
	var b := _cells[slot]
	b.seeded = false
	b.radius = 0.0
	b.speed = 0.0
	b.loads.fill(0.0)
	b.inert = false
	b.state = State.DRIFT
	b.target = TARGET_NONE
	if _drop != null:
		_drop.grid.remove(slot)
	_mirror_free.append(slot)


## What a mirrored body's organs buy, read again when its genome changes -- its
## mouth and its armour, which the drop's senses and the view weigh it by. A body
## with no mouth is a drifter.
func _mirror_refresh(b: Body) -> void:
	b.drifter = Catalogue.worn_provider(b.genome, &"gape") == &""
	_refresh_body(b)


## **A contact, told to this cell** (§1.3): the shipped signal, with the bearing
## worked out here from [param at] -- a place crosses the wire and a bearing
## never does (§0.2), because only this device knows which way its cell is
## facing now. The field's own contacts with this cell are told through here as
## well, so the run's handlers cannot tell a pond from single player.
## [param level] is the strength, or the nutrition for `ATE` and `GRAZED`. For `KILLED`,
## [param by] and [param cause] become [member died_by] and [member died_of]
## before [signal killed] goes, which is how the run learns its own cause of
## death (shared-pond.md §3); for anything else they change nothing here.
func hear_contact(what: int, at: Vector2, level: float = 0.0,
		by: int = By.WATER, gene: StringName = &"", cause: int = 0) -> void:
	match what:
		Contact.WAKED:
			waked.emit(_cell.bearing_to(at), level)
		Contact.BITTEN:
			# Felt by the player's instincts on their next tick, as a water
			# cell feels a bite on its own (`_feel_hit`): the hardest since.
			if level >= player_hit:
				player_hit = level
				player_hit_from = _angle_of(at - _cell.position, _cell.heading)
			bitten.emit(_cell.bearing_to(at), level)
		# `Contact.STUNG` keeps its number and is never sent since the toxin's
		# doses (docs/design/dna-slots.md §7.2): nobody is spat out any more.
		# One heard is from no build this one speaks to, and changes nothing.
		Contact.DARTED:
			darted.emit(_cell.bearing_to(at))
		Contact.ATE:
			eaten.emit(level, gene, at)
		# **A floc the host's water let this cell graze** (ocean.md §10.4): food
		# and no growth, as this cell's own graze is in its own drop.
		Contact.GRAZED:
			grazed.emit(level, at)
		Contact.KILLED:
			died_of = cause
			died_by = by
			killed.emit(_cell.bearing_to(at))


## One contact, to whichever player it happened to: this cell through the
## shipped signals, the person through [signal person_touched]. [param cause]
## is a `KILLED`'s [enum Cause]; the person's goes out on [signal person_died].
func _tell(p: Person, what: int, at: Vector2, level: float, by: int,
		gene: StringName, cause: int = 0) -> void:
	if p == null:
		hear_contact(what, at, level, by, gene, cause)
	else:
		touched_slot = p.slot
		person_touched.emit(what, at, level, by, gene)


## Is [param b] on a run at player [param p] -- null being this cell.
func _hunts(b: Body, p: Person) -> bool:
	if p == null:
		return b.target == TARGET_PLAYER
	return b.target == p.slot and b.target_serial == _cells[p.slot].serial


## A player's body as a mouth measures it, `pellicle` and all.
func _armoured(p: Person) -> float:
	return _cell.swallow_radius() if p == null \
		else _cells[p.slot].radius * p.armour


## [method CellBody.bearing_to], asked of either player.
func _bearing_for(p: Person, point: Vector2) -> float:
	if p == null:
		return _cell.bearing_to(point)
	var pb := _cells[p.slot]
	var offset := point - pb.pos
	return atan2(offset.dot(Vector2(cos(pb.heading), sin(pb.heading))),
		offset.dot(_forward(pb.heading)))


## The person [param b] is on a run at, or null.
func _hunted_person(b: Body) -> Person:
	if not _is_person_slot(b.target):
		return null
	var prey := _target_body(b)
	return prey.person if prey != null else null


## The other player died here: out of the slot, then said -- so a listener that
## brings them straight back finds it empty. [param p] is which of them. **In
## the drop one that starved or was poisoned leaves its remains** (ocean.md
## §7.4), as every body there does.
func _person_gone(cause: int, by: int, p: Person) -> void:
	var at := _cells[p.slot].pos
	var r := _cells[p.slot].radius
	remove_person(p.slot)
	if cause == Cause.STARVED or cause == Cause.POISONED:
		leave_remains(at, r)
	touched_slot = p.slot
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
func _step_person(delta: float, slot: int = PERSON_SLOT) -> void:
	var pb := _cells[slot]
	var p := pb.person
	if p == null:
		return
	# Their loads wear with their wound, by the one dose step every body takes:
	# the host decides every dose and owns their death (dna-slots.md §14.1),
	# found at the top of their contacts, and POND tells their device what they
	# carry.
	pb.wound = CellBody.dosed(pb.loads, pb.wound, pb.radius, delta)
	pb.bite = maxf(pb.bite - delta, 0.0)
	p.dart_clock = maxf(p.dart_clock - delta, 0.0)
	if p.first_hunt > 0.0:
		p.first_hunt -= delta
	_carry_person(pb, p.age)
	# Carried, and held inside the drop's rim, as their own run holds them.
	if _drop != null:
		pb.pos = _drop.meniscus.contain(pb.pos, pb.radius)
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
## the host's, and arrives. **In the host's drop** this cell is held inside the
## rim and knocked by it, as in its own (ocean.md §10.4), a floc settles by this
## mirror's own clock, and every body here is what the senses scan: the send set
## is what reaches them.
func _step_mirror(delta: float) -> void:
	# **Carried to the end of this frame, not to its start.** A snapshot is the
	# host's water as the host's last frame ended, and it is applied before this
	# node runs; by the time this frame ends the host's water has run on by one
	# more frame, and so does this. Carried to the start instead, the mirror
	# stood a whole frame behind the water it mirrors -- 1.6 units on a lunging
	# hunter at 60 frames a second -- in every frame, on a link with no latency
	# at all.
	_snap_age += delta
	_mirror_t += delta
	var ahead := minf(_snap_age, CARRY_MAX)
	for id: int in _mirror_slots:
		var i := int(_mirror_slots[id])
		var b := _cells[i]
		if b.seeded:
			b.pos = _snap_at[i] + _forward(b.heading) * (b.speed * ahead)
			if _drop != null:
				_drop.grid.move(i, b.pos)
	for id: int in _mirror_flocs:
		var told: Array = _mirror_flocs[id]
		var since := _mirror_t - float(told[3])
		var b := _cells[int(told[0])]
		b.settle = floc_settle_after(float(told[1]), float(told[2]), since)
		b.life = maxf(float(told[2]) - since, 0.0)
	var pb := _cells[PERSON_SLOT]
	if pb.person != null:
		_carry_person(pb, ahead)
	# **What the senses scan is everything here** -- the send set and the flocs
	# in reach, and the person -- gathered as the host gathers what is near.
	_near.resize(0)
	for i in _cells.size():
		if _cells[i].seeded:
			_near.append(i)
	if not in_water:
		return
	if _drop != null:
		_shore_clock = maxf(_shore_clock - delta, 0.0)
		_contain_player(true)
	for i: int in _near:
		var b := _cells[i]
		# A floc is not solid: a cell swims over it (ocean.md §7.5).
		if b.seeded and not b.inert:
			_push_local(b, false)
	if _drop != null:
		_contain_player(false)
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
	b.loads.fill(0.0)
	b.dosed_by = -1
	b.bite = 0.0
	b.speed = 0.0
	b.tuned = -1
	if not b.order.is_empty():
		b.order = []
	# And nothing of what a body on rules was doing (behaviour.md §4): no heading
	# held, no claim, no stun, no meal yet, no hit, its own call due at once and
	# nothing in flight or remembered. No number is drawn for any of it.
	b.holding = false
	b.resting = false
	b.swimming = false
	b.push = 0.0
	b.tail_held = false
	b.tumble = -1
	b.tumble_tick = -1
	b.stun = 0.0
	b.ate_at = -INF
	b.hit = 0.0
	b.call_at = 0.0
	if not b.echoes.is_empty():
		b.echoes.clear()
	if not b.memory.is_empty():
		b.memory.clear()
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
	# Written as the negation of the clear test it replaces, so a NaN place is
	# refused exactly where it always was.
	for k in _guests:
		var pb := _cells[PERSON_SLOT + k] if _cells.size() > PERSON_SLOT + k else null
		if pb != null and pb.person != null \
				and not (point.distance_squared_to(pb.pos) >= ring):
			return false
	return true


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
	return _cells[_anchor_slot(anchor)].pos if anchor >= Anchor.PERSON \
		else _cell.position


func _anchor_radius(anchor: int) -> float:
	return _cells[_anchor_slot(anchor)].radius if anchor >= Anchor.PERSON \
		else _cell.radius


## The slot of the person anchor [param anchor] is: [enum Anchor]'s `PERSON`
## is [constant PERSON_SLOT], and a dedicated host's second guest the next.
static func _anchor_slot(anchor: int) -> int:
	return PERSON_SLOT + anchor - Anchor.PERSON


## [method _sensed], for either player: the person's is read off the tiers they
## wear, exactly as this cell's is read off its genome.
func _anchor_sensed(anchor: int) -> float:
	if anchor < Anchor.PERSON:
		return _sensed()
	var tiers := _cells[_anchor_slot(anchor)].genome
	var sum := 0.0
	for gene: StringName in Catalogue.tagged(Catalogue.SENSE):
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
##
## **In the drop she is a daughter in full** (lineage.md §4): [param tiers] is
## the body she wears, [param dna] the DNA she carries -- the declined
## daughter's, her body where it is empty -- and [param mother] the record of
## the cell she and you divided from, so her parent is your mother's id and her
## family is yours ([method _born_of]). Today's water keeps no record.
##
## **And she carries [param brain]** (automation.md §6.3): the list her cell
## ran -- the programs that were on, merged in the library's order -- or null
## for the founders', as every sister did in pack 3. From her birth it is a
## water cell's list, hers, which her line's divisions change.
func put_sister(bearing: float, distance: float, body_radius: float,
		tiers: Dictionary, dna := {}, mother := PackedInt32Array(),
		brain: Variant = null) -> void:
	# **In the drop she comes in by the one door every body does** (§8.2,
	# §12): [method _spawn], born fed, a water cell under every rule of §5 from
	# then on -- and held inside the rim if her side of her mother is past it.
	if _drop != null and _cell != null:
		var side := _cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)
		var at := _cell.position + side * distance
		# **In a pond, as a guest's sister is** ([method place_sister]): never on
		# the other player, and inside the rim.
		if _pond:
			place_sister(at, _angle_of(side, 0.0), body_radius, tiers, dna, mother, brain)
			return
		at = _drop.meniscus.contain(at, body_radius)
		var index := _spawn(at, false, _sensed(), false, body_radius, tiers)
		_cells[index].heading = _angle_of(side, _cells[index].heading)
		_cells[index].brain = brain
		_born_of(_cells[index], dna, mother)
		_stat(&"sisters")
		return
	if _cell == null or _cells.size() < 2:
		return
	if _pond:
		var side := _cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)
		place_sister(_cell.position + side * distance, _angle_of(side, 0.0),
			body_radius, tiers, dna, mother, brain)
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
	# genome with would make the early game a dead end. **Written whole**, so
	# what it buys is read with it (`Body.derive`).
	# **In the drop** (§5.8, §6.4): the gene the drop is down to its last
	# carriers of, if one is -- and never the toxin, which comes back through a
	# peer instead: the drop's drifters are its defenceless food (row 13).
	if _drop != null:
		var wanted := Drop.take_drifter_gene(_gene_short)
		if wanted != &"":
			b.genome = {wanted: 1}
			_stat(&"gene_floor")
			return
		b.genome = {_place_toxin(_draw_gene(Catalogue.drifters() if drifter_toxin
			else _drifter_pool)): 1}
		return
	# **Drifters carry neither form in today's water either** (docs/design/
	# dna-slots.md §0 item 12): the first water's drifter could carry the old
	# `veneneux` and be swallowed safely, but poison now doses whatever swallows
	# it, and a drifter is the food. Drawn by today's weights as it always was, and
	# a toxin drawn is drawn again from the rest -- one more number, on that
	# drifter alone.
	var gene := _draw_gene(Catalogue.drifters())
	if Catalogue.has_tag(gene, Catalogue.NOT_ON_DRIFTERS):
		gene = _draw_gene(Drop.drifter_genes(Catalogue.drifters()))
	b.genome = {gene: 1}


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
	if _drop != null:
		return _draw_living(body_radius, sensed)
	# The mouth: what provides a gape.
	var mouth := Catalogue.first_provider(&"gape")
	var tiers := {mouth: _draw_tier(sensed)}
	var capacity := CellBody.slots_for(body_radius)
	var pool: Array[StringName] = Catalogue.drifters().duplicate()
	# **Room is by place** (docs/design/dna-slots.md §9): the toxin is drawn as
	# one gene and a coin puts it inside or out, and poison takes no arc, so the
	# loop fills the outside to its capacity as it always did.
	while Genome.count_outside(tiers) < capacity and not pool.is_empty():
		var gene := _draw_gene(pool)
		_erase_organ(pool, gene)
		var tier := _draw_tier(sensed)
		tiers[_place_toxin(gene)] = tier
	# The ceiling, applied where §1.3 puts it: on the mouth, by taking tiers off
	# until it fits. A radius-40 arrival comes out at cytostome 1; a radius-28
	# one can keep cytostome 3.
	while tiers[mouth] > 0 and CellBody.gape_of(tiers, body_radius) > ARRIVAL_GAPE_MAX:
		tiers[mouth] = int(tiers[mouth]) - 1
	return tiers


## **Where a toxin the water draws goes** (docs/design/dna-slots.md §9): the
## water draws it as one gene, by its variety's name and weight, and a coin puts
## it inside, as poison, or outside, as venom -- the two places are equal. Any
## other gene is itself, and no number is drawn for it.
func _place_toxin(gene: StringName) -> StringName:
	if not Genome.has_forms(gene):
		return gene
	return gene if randi() % 2 == 0 else Genome.form_in(gene, Genome.OUTSIDE_PLACE)


## **A gene drawn from [param pool]**, varieties all: **an organ first, by its
## weight, then one of its varieties by theirs** (docs/design/gene-catalogue.md §6.1;
## dna-slots.md §8.3) -- one roll for the organ, and a second only for an organ the
## pool holds more than one variety of. Every organ has one today, so this draws
## what drawing the varieties by their own weights always drew, roll for roll.
static func _draw_gene(pool: Array[StringName]) -> StringName:
	var organs := Catalogue.organs_in(pool)
	var total := 0
	for organ: StringName in organs:
		total += Catalogue.organ_weight(organ)
	var roll := randi_range(1, maxi(total, 1))
	var drawn: StringName = organs[organs.size() - 1] if not organs.is_empty() else &""
	for organ: StringName in organs:
		roll -= Catalogue.organ_weight(organ)
		if roll <= 0:
			drawn = organ
			break
	return Catalogue.pick_variety(Catalogue.of_organ(pool, drawn))


## **[param gene]'s organ, out of [param pool]**: every variety of it, so one body's
## draws never take the same organ twice -- it counts as one gene wherever the water
## counts genes (dna-slots.md §8.3). Every key filed under the organ, and a name no
## gene goes by as itself, as [method Catalogue.organ_of] answers for one: the pool
## keeps its order.
static func _erase_organ(pool: Array[StringName], gene: StringName) -> void:
	var organ := Catalogue.organ_of(gene)
	for key: StringName in Catalogue.keys_of_organ(organ):
		while pool.has(key):
			pool.erase(key)
	if not Catalogue.known(organ):
		while pool.has(organ):
			pool.erase(organ)


## **[param gene]'s variety, out of [param pool]**, in every form: what a body that
## wears it already may not draw again. The organ's other varieties stay, and the
## pool keeps its order. One organ of one variety today, so this takes out what
## [method _erase_organ] takes out.
static func _erase_variety(pool: Array[StringName], gene: StringName) -> void:
	for key: StringName in Catalogue.forms_of(gene):
		while pool.has(key):
			pool.erase(key)


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
# see. See the block on what counts as sight: keyed on the player's own organs, never on
# which view is drawing them.
# ---------------------------------------------------------------------------

## **How much this cell can see coming**, 0 for blind and 1 for the water as
## shipped. The sum of the four sensing tiers over [constant SENSE_FULL], which
## is the least invented mapping available: every tier of every sense moves it,
## and none of them moves it in a step.
func _sensed() -> float:
	# A tool's water made for a player of that much sight (the drop only).
	if _drop != null and sensed_override >= 0.0:
		return sensed_override
	if _cell == null:
		return 1.0
	var tiers := 0.0
	for gene: StringName in Catalogue.tagged(Catalogue.SENSE):
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
	return b.stat_gape * b.radius


## What this cell swims at while chasing: the chase's reference speed times the
## margin Phase 4 measured. A hunter is faster than what it is chasing, always,
## which is why dread does not mean "flee" -- it means commit away from that
## bearing now, before it lunges.
##
## **In the drop a hunter swims only as fast as its own tail** (row 14): the
## realised speed of its `flagellum` and `axoneme`, the arithmetic the water
## already leads a player with. `own_speed` off puts today's back.
func _cruise_speed(b: Body) -> float:
	if _drop != null and own_speed:
		return b.cruise
	return _reference_speed(b) * CRUISE_OVER_PREY


## In the drop, its cruise and whatever is left of its last dash: a body with
## no `myoneme` has no lunge but its tail.
func _lunge_speed(b: Body) -> float:
	if _drop != null and own_speed:
		return b.cruise + b.dash_v
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


## A cell's own natural speed, derived from its tail through the same model the
## player's is -- so a chase between two field cells is the same chase the player
## is in.
func _own_speed(b: Body) -> float:
	return b.stat_speed


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
	# is; a water cell's is its bare radius (shared-pond.md §0.5), and in the
	# drop armoured too (row 5).
	return _worth_committing_to(b, gape,
		(prey.radius if _drop == null else _swallow_r(prey)) if prey.person == null
			else prey.radius * prey.person.armour,
		prey.wound)


## Same convention as the cell: radians clockwise from world north, front is the
## top of the screen.
func _forward(heading: float) -> Vector2:
	return Vector2(sin(heading), -cos(heading))


func _angle_of(v: Vector2, fallback: float) -> float:
	if v.length_squared() <= 0.0:
		return fallback
	return atan2(v.x, -v.y)



# ===========================================================================
# **The drop** (docs/design/ocean.md): a round drop of pond water twelve
# millimetres across, and everything in it all the time. A run with no session
# up is made here by [method setup_drop]; a run with one plays today's water,
# above, which never sets [member _drop] and so reaches nothing below (§10.1).
# That is the whole of the identity gate's promise (§14.4): every function above
# that the drop changes asks `_drop != null` first, and draws no number from the
# random stream it did not draw before.
#
# **What this section is**: one body for every cell (§5) -- the player's tank,
# prices, growth, senses and tail -- stepped at three rates by distance from the
# player (§4.3), every pass that was all-pairs asked of the grid (§4.2), the rim
# in every sense (§3), the spawner and its floors, the snow and the remains (§6,
# §7), and where a run starts (§8.1). **What it is not**: this water's numbers
# and decisions, which are drop.gd's, and the arithmetic of a grid, a rim, a
# debt or a snowfall, which is game/mechanics/'s and knows nothing of cells.
# ===========================================================================

## A beam's `body` when what it stopped on was the meniscus: no body at all.
const EDGE_BODY := -3
## How many of a body's run's clocks a kept drop holds, one after another:
## calm, stale, aim, lost, rush, best, break, stroke, wander and speed.
const RUN_CLOCKS := 10
## **The two eating rules a guest in a shared drop is held to** (ocean.md §10.5,
## rows 15 and 5), as the build ships them: a mouth swallows a player that fits
## on contact, hunting or not; and `pellicle` makes every body bigger to a mouth.
## The host decides both and tells the guest, so the referee judges neither --
## but the rules the handshake carries hold a sample of each (game/net/rules.gd),
## through [method swallows_player] and [method armoured_size], which the field
## itself decides by, so two builds that disagree on them refuse each other at HELLO.
const CONTACT_SWALLOW := true
const ARMOUR_SWALLOW := true
## **Where the authored first drifter may be placed**: not within this of the
## rim, so a run that starts moving toward the edge meets it toward the middle
## instead. The prototype's number, never measured on its own.
const FIRST_INSET := 200.0
## How many headings round its nose the drifter floor tries for a place ahead
## of the cell, each wider than the last by this many radians of spread.
const AHEAD_TRIES := 12
const AHEAD_SPREAD := 0.35
const AHEAD_WIDEN := 0.25
## What [method _make_one] returns when nothing is short (lineage.md §5): a unit
## the spawner owed that births have already paid. Not -1, which is nowhere to
## put a body that was wanted.
const NOTHING_SHORT := -2

# --- Switches (§14.1): one per body rule, so the owner's other answers can be
# played, and §4.4's. Set by tools/drive.gd before the run enters the tree, as
# `--mode` is; nothing in the game writes them, and each reads as the drop's
# rule as it stands.

## Row 11: seconds of rest a second that a body with no `cytostome` absorbs.
var absorb := Metabolism.ABSORB
## Row 13, the other way: drifters may carry the toxin, either form, as the
## first water's did (docs/design/dna-slots.md §9).
var drifter_toxin := false
## Row 14: a hunter swims at its own tail's speed. Off, today's 1.2 and 1.7
## times its prey's.
var own_speed := true
## Row 5: a hunter notices only what its own senses find. Off, today's
## NOTICE_RANGE whatever it carries.
var notice_by_senses := true
## Row 15: a mouth swallows a player that fits on contact. Off, only from a run.
var contact_swallow := CONTACT_SWALLOW
## Row 5: `pellicle` armours every body against a swallow. Off, a player only.
var armour_swallow := ARMOUR_SWALLOW
## Row 16: nothing may hunt the player for this long after a birth, a division
## or a return.
var grace := FIRST_DELAY
## §5.4 the other way: a miss ends in today's flight and calm.
var flight := false
## §4.2: a prey search asks the buckets within PREY_NEAR before its whole reach.
var near_first := true
## §4.3: far bodies are stepped at a lower rate. Off, every body every frame.
var lod := true
## §4.3: from LOD_FULL to LOD_NEAR every second frame. Off, every frame.
var half_rate := true
## §4.4: a tank that cannot move is not stepped -- which changes no number.
var skip_still := true
## A water made for a player this sighted, 0..1; negative, the player's own.
var sensed_override := -1.0
## Where a run starts: `quiet` (§8.1), `centre`, or `edge` -- [member edge_gap]
## inside the rim, facing it -- for the renders.
var start_mode := &"quiet"
var edge_gap := 380.0
## For the renders and the probes: this many flocs round the start, the last
## caught settling; everything alive within [member desert] of it taken away;
## and the drop left to live alone this many seconds before the cell arrives.
var flocs_near := 0
var desert := 0.0
var age_first := 0.0
# --- Pack 2's rules, one switch each (docs/design/lineage.md §11.1, §12), set by
# tools/drive.gd and tools/eco_probe.gd as the ones above are. Nothing in the game
# writes them, and each reads as the drop's rule as it stands.
## **Bodies divide** (§2-§5): a water body at DIVIDE_RADIUS divides on its tick,
## a meal writes its DNA and not its body, every newborn has the grace, and the
## spawner keeps the food to its count and today's hunters as a floor. **Off is
## pack 1, to the census line**: nothing divides, a meal grows the body as well,
## no sister has a grace and the spawner keeps the whole drop at its size.
var births := true
## **A tool's rate**: the share of divisions in which one daughter is changed.
## The game has none -- every division changes one, as yours does (row 19) --
## and only `--mutate=` plays another (§3.3).
var mutate := 1.0
## The share of today's hunters the spawner keeps at least (§5): SPAWN_SHARE.
var floor_share := Drop.SPAWN_SHARE
## Seconds within which the hunters' shortfall is paid back (§5): FLOOR_TAU.
var floor_tau := Drop.FLOOR_TAU
## Seconds of grace every newborn gets (§3.4): the player's FIRST_DELAY.
var newborn_grace := FIRST_DELAY
# --- Pack 3's (docs/design/behaviour.md §12.1), set by tools/drive.gd and
# tools/eco_probe.gd as the ones above are. Nothing in the game writes them.
## **The water's cells decide by the rules they carry** (§4, §5): every hunter
## reads its rules, on its tick, over what its own senses report, and acts
## through the triggers its body has. **Off is pack 2, to the byte** (§12.3
## check 1): today's hand-written hunter, which once it has found its prey knows
## where it is -- the reference `--rules=0` plays. Today's water never reads it.
var rules := true
## **Every division changes one daughter's rules** (§6): the daughter whose DNA
## changed carries her mother's list with one change. **Off is phase 3-1, to the
## byte** (§12.3 check 6): both daughters carry their mother's list and nothing
## is drawn for it -- what `--rule-change=0` plays. Read only while [member rules]
## is on.
var rule_change := true
# --- Pack 4's (docs/design/automation.md §5.4), set by tools/drive.gd and
# tools/eco_probe.gd as the ones above are, before the water is made. Nothing in
# the game writes it.
## **A tail beats unless it is held** (row 37, §5.3): every body that swims --
## every water cell with a mouth -- swims at its tail's speed and pays for it
## unless the flagellum's `hold`, or a rest at [method CellBody.hold_level],
## holds it, or a dart stuns it; a drifter is carried, as ever. **Off is pack 3,
## to the byte** (§18.3 check 1): a body swims only while a swim rule fires, a
## rest stops its tail at every level, and no part a level brings is there or
## drawn by a change -- pack 3 had none -- what `--water-tail=pack3` plays.
var tails_beat := true

## **The drop this run is in**, or null for today's water.
var _drop: Drop = null
## **Which drop this is** (§9.2's header): a number drawn when the drop is made
## and kept with it for its life, for the log. Drawn from a generator of its
## own, so making a drop draws nothing from the stream `--seed=` seeds; the drop
## itself is made from that stream, so this seeds nothing.
var drop_seed := 0
## How long the drop has lived, and in how many frames. Only a frame the drop
## runs counts: frozen while the cell is dead or dividing, it has not aged.
var _t := 0.0
var _frame := 0
## Slots with nobody in them, reused last in, first out.
var _free := PackedInt32Array()
## Living bodies, how many of them have no mouth, and flocs.
var _living := 0
var _drifters := 0
var _flocs := 0
var _next_id := 1
## **The widest body there has been.** A bound only ever has to be too big, so
## it only grows.
var _widest_now := 0.0
## **The bodies near the player this frame**, gathered once after the step:
## every sense, the player's contacts and [method hunter] read these and
## nothing else, because nothing past them reaches any of it.
var _near := PackedInt32Array()
## What was stepped this frame: the mouths that can close and the bodies that
## are pushed apart, near and on their ticks alike.
var _stepped := PackedInt32Array()
# **One array per pass that asks the grid, never shared** (§4.2's trap): a pass
# that loops over an answer and calls something that asks again must not be
# handed its own answer back.
var _lod_ids := PackedInt32Array()
var _prey_ids := PackedInt32Array()
var _pair_ids := PackedInt32Array()
var _count_ids := PackedInt32Array()
var _graze_ids := PackedInt32Array()
var _view_ids := PackedInt32Array()
## `0 .. n - 1`, kept for today's loops over every body and every water slot,
## which the same functions run as the drop's lists.
var _ids := PackedInt32Array()
var _water_idx := PackedInt32Array()
## What a drifter's gene is drawn from: every gene but the toxin (row 13).
var _drifter_pool: Array[StringName] = []
## The genes the drop is down to its last carriers of, at the last count.
var _gene_short: Array[StringName] = []
var _eco_clock := 0.0
var _gene_clock := 0.0
var _floor_clock := 0.0
var _shore_clock := 0.0
## The authored first drifter, and its serial, until the cell first moves.
var _first_index := -1
var _first_serial := -1
## **What the drop did**, by name: counts for the probes and the census. Never
## read by a rule.
var stats := {}
# --- The pond on the drop (ocean.md §10.2) -------------------------------------
## **What this cell's senses scan in a pond on the drop**: the bodies near it,
## and the people in the water -- who are never in the grid, because no water
## rule may treat one as a water body.
var _seen := PackedInt32Array()
## The bodies near each person this frame, by [constant GUESTS_MAX]'s index:
## what their contacts and the water giving way to them scan.
var _person_near: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
## Where every player with a body is, this frame: the anchors of the LOD.
var _anchors_now := PackedVector2Array()
## **Whom the water is made for** (§10.3): `[radius, sensed]` for each player
## it was last made for, in turn -- the players while anyone is in it, and kept
## with the drop, so an empty room keeps the water its visitors had. Empty is a
## newborn's.
var _made_for := PackedFloat64Array()
## Whose turn the next body is made for, among them (§10.2).
var _turn := 0
# --- Rules (docs/design/behaviour.md §3.5, §10): the wiring --------------------
## **What a body's rules can name**: every input and output the body, the
## metabolism and the genes declare (cell.gd's, metabolism.gd's and genome.gd's
## DECLARES), made once a process.
static var _vocabulary: Rulebook.Vocabulary = null
## **The founders' rules** (drop.gd's FOUNDERS), read once against it: what a
## body whose `brain` is null carries.
static var _founders: Rulebook.Behaviour = null
## Declaration tables a tool added to the game's own ([method declare]): none,
## in the game.
static var _declared: Array = []
## **Each declared input to what reads it for a body, and each declared output
## to what performs it** (§3.5 step 3) -- the one place a name meets an organ.
## Made on first use ([method _wire]).
var _readers := {}
var _triggers := {}
var _read_with := Callable()
## **The parts every body has** -- the body's own and its metabolism's (cell.gd's
## and metabolism.gd's DECLARES) -- beside the genes it wears.
static var _everybody := {}
## The body whose rules are being read, and its slot: what the readers read for.
var _reading: Body = null
var _reading_slot := -1
## The sizes a rule's size is measured against, the body's own (§3.1).
var _sizes := {&"mouth": 0.0, &"body": 0.0}
## One tick's winners; a beam's rays; a call's returns -- reused, never held.
var _fired: Array = []
var _rays: Array = []
var _returns: Array = []
## **The bodies one organ of one water cell can reach**, asked of the grid; and a
## dart's -- each pass its own array (§4.2's trap).
var _organ_ids := PackedInt32Array()
var _dart_ids := PackedInt32Array()


# --- Made once a run, entered at every birth ----------------------------------------

## **Makes the drop round [param cell]** (§2-§8): its population anywhere in
## it, at the composition this player's senses call for, and its flocs; then the
## run started somewhere quiet, with the drop placed so that that point is
## where the cell already is -- the camera does not move -- and whatever could
## swallow the cell moved out of dread's reach of it. Once a run: a division
## and a return come back into the same drop ([method enter_water],
## [method return_to_drop]).
func setup_drop(cell: CellBody) -> void:
	_cell = cell
	_reset_drop()
	_made_for = PackedFloat64Array([_cell.radius, _sensed()])
	# A drop being made for the first time is a drop that was already there:
	# every body drawn by the share the player's senses call for, its tank at
	# any level up to FIRST_HUNGER_MAX (§5.8), and some flocs already settled.
	var sensed := _sensed()
	var share := _drifter_share(sensed)
	for k in Drop.target():
		_spawn(_drop.uniform_point(Drop.FILL_INSET), randf() < share, sensed, true)
	for k in Drop.FIRST_FLOCS:
		_spawn_floc(_drop.uniform_point(Drop.SNOW_INSET), Drop.floc_radius(), true)
	_count_genes()
	_shift_drop(_cell.position - _start_point())
	if age_first > 0.0:
		_age_alone(age_first)
		_shift_drop(_cell.position - _start_point())
	if desert > 0.0:
		for i in _cells.size():
			var b := _cells[i]
			if b.seeded and not b.inert and b.pos.distance_to(_cell.position) < desert:
				_stat(&"deserted")
				_consume(i)
	_clear_round(_cell.position)
	if start_mode == &"edge":
		_cell.heading = _angle_of(_cell.position - _drop.meniscus.center, _cell.heading)
	for k in flocs_near:
		var dir := Vector2.from_angle(randf_range(-PI, PI))
		var at := _cell.position + dir * randf_range(220.0, 520.0)
		if not _drop.meniscus.inside(at, Drop.FILL_INSET):
			at = _cell.position - dir * randf_range(220.0, 520.0)
		var fi := _spawn_floc(at, Drop.floc_radius(), k < flocs_near - 1)
		if k == flocs_near - 1:
			_cells[fi].settle = 0.45
	_arrive()


## **A return after a death, in the same drop** (§8.1, §8.2): a born cell at a
## quiet start in the water it died in -- the same choice a run's start is,
## made behind the black -- with the same clearing, its own first drifter and
## the grace of a birth. Nothing in the water changes but that: the drop was
## frozen while the cell was dead, and wakes as it was. A watched replay wrote
## nothing here -- it has a field of its own (§11).
func return_to_drop() -> void:
	in_water = true
	anchored = true
	_shift_drop(_cell.position - _start_point())
	_clear_round(_cell.position)
	_arrive()


## Whether this run is in the drop -- its own, or, as a guest, the host's
## (a mirror with the host's rim).
func in_drop() -> bool:
	return _drop != null


## **Whether the drop this field holds is its own to keep** -- a solo run's, a
## host's, a room -- and not a mirror of the host's or a replay's picture.
func owns_drop() -> bool:
	return _drop != null and not _mirror and not _replay


## **The drop, as it is to be set aside or kept** (ocean.md §9.1): its
## [method drop_state], or nothing when this field has no drop of its own.
func set_aside() -> Dictionary:
	return drop_state() if owns_drop() else {}


# --- The pond on the drop (§10.2), and the room (§10.3) ---------------------------------

## **The drop becomes a pond**: [param guests] people, each in a slot from
## [constant PERSON_SLOT] on, as in every pond -- so the view, the wire's end
## and every rule that reaches for a person reach the same place. Whatever the
## drop kept in those slots moves to one of its own first ([method _move_body]),
## and they are never handed to a body the drop makes while the pond is open.
## The authored first drifter is single player's: it is where it was.
func _open_drop_pond(guests: int) -> void:
	_pond = true
	_mirror = false
	_guests = guests
	_first_pending = false
	while _cells.size() < PERSON_SLOT + _guests:
		_cells.append(Body.new())
	for k in _guests:
		var slot := PERSON_SLOT + k
		var at := _free.find(slot)
		while at >= 0:
			_free.remove_at(at)
			at = _free.find(slot)
		if _cells[slot].seeded:
			_move_body(slot, _cells.size())
		else:
			_drop.grid.remove(slot)
			_cells[slot] = Body.new()
	_changes += 1


## **A body moves from slot [param from] to [param to]** -- appended when
## [param to] is past the end -- and a fresh nobody takes its place: filed again
## in the grid, and every run at it, the authored first drifter and a killer
## named to the recorder following it there. Its serial goes with it, so a chase
## of it carries on.
func _move_body(from: int, to: int) -> void:
	var b := _cells[from]
	if to >= _cells.size():
		_cells.append(b)
		to = _cells.size() - 1
	else:
		_cells[to] = b
	_cells[from] = Body.new()
	_drop.grid.remove(from)
	_drop.grid.insert(to, b.pos)
	for other in _cells:
		if other.target == from:
			other.target = to
	if _first_index == from:
		_first_index = to
	if died_to == from:
		died_to = to


## **A room made anew** (§10.3): the drop's population anywhere in it, drawn
## for a newborn -- nobody has visited it -- and its first flocs, round the
## origin. Nobody arrives: no start, no clearing, no first drifter.
func _make_room(cell: CellBody) -> void:
	_cell = cell
	_reset_drop()
	_made_for = PackedFloat64Array([CellBody.BASE_RADIUS, 0.0])
	var share := _drifter_share(0.0)
	for k in Drop.target():
		_spawn(_drop.uniform_point(Drop.FILL_INSET), randf() < share, 0.0, true, 0.0, {},
			CellBody.BASE_RADIUS)
	for k in Drop.FIRST_FLOCS:
		_spawn_floc(_drop.uniform_point(Drop.SNOW_INSET), Drop.floc_radius(), true)
	_count_genes()
	died_to = -1


## Everything a drop being made starts from: no pond, no mirror, nobody in its
## slots, its clocks and counts at nothing, a new rim round the origin and a
## number of its own.
func _reset_drop() -> void:
	_pond = false
	_mirror = false
	_guests = 1
	_water = 0
	in_water = true
	anchored = true
	_snap_at = PackedVector2Array()
	_snap_age = 0.0
	_book.clear()
	_cells.clear()
	_free.resize(0)
	_near.resize(0)
	_stepped.resize(0)
	stats.clear()
	_t = 0.0
	_frame = 0
	_living = 0
	_drifters = 0
	_flocs = 0
	_next_id = 1
	_widest_now = 0.0
	_eco_clock = 0.0
	_gene_clock = 0.0
	_floor_clock = 0.0
	_shore_clock = 0.0
	_first_pending = false
	_first_index = -1
	_turn = 0
	_made_for = PackedFloat64Array()
	_drop = Drop.new(Vector2.ZERO)
	var numbers := RandomNumberGenerator.new()
	numbers.randomize()
	drop_seed = numbers.randi()
	_drifter_pool = Drop.drifter_genes(Catalogue.drifters())
	_gene_short.clear()


## **Where every player with a body is this frame** -- this cell, while it is an
## anchor, and each person in the pond: the anchors of the LOD (§10.2).
func _anchor_points() -> PackedVector2Array:
	_anchors_now.resize(0)
	if anchored:
		_anchors_now.append(_cell.position)
	if _pond and not _mirror:
		for k in _guests:
			var pb := _cells[PERSON_SLOT + k]
			if pb.person != null:
				_anchors_now.append(pb.pos)
	return _anchors_now


## **What each player's senses and contacts are asked of this frame**: the
## people in the water join this cell's scan ([member _seen]), and each person
## gets the bodies near enough for a mouth either way ([member _person_near]).
func _gather_people() -> void:
	_seen.resize(0)
	_seen.append_array(_near)
	for k in _guests:
		_person_near[k].resize(0)
		var pb := _cells[PERSON_SLOT + k]
		if pb.person == null:
			continue
		if pb.seeded:
			_seen.append(PERSON_SLOT + k)
		var reach := sqrt(_player_bound(pb.radius, _gape(pb), _widest_now))
		_drop.grid.query(pb.pos, reach + Drop.GRID_SLACK, _person_near[k])


## What this cell's senses scan: every body in today's water; in the drop the
## bodies the frame gathered near it -- and the people in the water, in a pond.
func _sense_ids() -> PackedInt32Array:
	if _drop == null:
		return _all_ids()
	return _seen if _pond and not _mirror else _near


## **The water gives way to a person** (the drop's [method _push_person]):
## its half of every overlap with the bodies near them, held inside the rim.
## Their own half, and their knock, happen on their device.
func _push_person_drop(k: int) -> void:
	var pb := _cells[PERSON_SLOT + k]
	if pb.person == null or not pb.seeded:
		return
	var m := _drop.meniscus
	for i: int in _person_near[k]:
		var b := _cells[i]
		if not b.seeded or b.inert:
			continue
		var offset := pb.pos - b.pos
		var d := offset.length()
		var overlap := b.radius + pb.radius - d
		if overlap <= 0.0:
			continue
		var normal := offset / d if d > 0.001 else -_forward(b.heading)
		b.pos = m.contain(b.pos - normal * (overlap * (1.0 - _give_way(b.radius, pb.radius))
			* PUSH_SHARE), b.radius)


## **How far a person's senses reach**, for the spawner's hide reach round
## them: the widest of the nose, the radar and the beam their tiers carry -- a bound,
## so the most any of their organs gives (stats.gd's `of`), not the one that acts.
func _person_senses(pb: Body) -> float:
	var g := pb.genome
	return maxf(maxf(Stats.of(g, &"smell_range"), Stats.of(g, &"ping_range")),
		Stats.of(g, &"beam_range"))


## **A quiet place in this drop for a born cell** (§8.1), without moving the
## drop or anything in it but what could swallow a born cell there: where a
## guest arrives in a room nobody is in (§10.3). Nobody watches an empty room,
## so the clearing is seen by no one.
func quiet_place() -> Vector2:
	if _drop == null:
		return Vector2.ZERO
	var at := _drop.quiet_start(_food_for_born, _dread_for_born)
	var mine := CellBody.swallow_radius_of(CellBody.BASE_RADIUS, Catalogue.born())
	_count_ids.resize(0)
	_drop.grid.query(at, DREAD_RANGE + Drop.GRID_SLACK, _count_ids)
	for i: int in _count_ids:
		var b := _cells[i]
		if not b.seeded or b.inert or b.person != null or _gape(b) <= mine:
			continue
		if b.pos.distance_to(at) >= DREAD_RANGE:
			continue
		b.pos = _drop.pushed_clear(at, b.pos, DREAD_RANGE, b.radius)
		b.aim = b.pos
		b.flee_from = b.pos
		_drop.grid.move(i, b.pos)
	return at


## **The drop's rim**, a `basin.gd`, for whoever keeps things inside it -- the
## grit and the view. Null for today's water.
func basin() -> RefCounted:
	return _drop.meniscus if _drop != null else null


## **How long the drop has lived**, in the seconds it has run.
func drop_age() -> float:
	return _t


## **How many bodies the drop holds**: the living and the flocs, never a person.
func drop_bodies() -> int:
	return _living + _flocs if owns_drop() else 0


## What a run starts with, at its start: the authored first drifter, held until
## the cell first moves (§6.4), the grace of a birth, senses that have heard
## nothing yet, and nothing that has killed it.
func _arrive() -> void:
	died_to = -1
	var at := _drop.meniscus.contain(_cell.position + Vector2(0.0, -FIRST_DISTANCE),
		DRIFTER_MAX)
	_first_index = _spawn(at, true, _sensed())
	_first_serial = _cells[_first_index].serial
	_first_pending = true
	_first_hunt = grace
	_near.resize(0)
	_fresh_senses()


## **Where the run starts**, before the drop is moved under it.
func _start_point() -> Vector2:
	match start_mode:
		&"centre":
			return _drop.meniscus.center
		&"edge":
			return _drop.meniscus.center + Vector2.from_angle(randf_range(-PI, PI)) \
				* (Drop.RADIUS - edge_gap)
	return _drop.quiet_start(_food_for_born, _dread_for_born)


## **The drop moves by [param by]**, every body with it, and the grid is filed
## again from nothing: how a start is put under a cell that stays where it is.
func _shift_drop(by: Vector2) -> void:
	_drop.shift(by)
	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded:
			continue
		b.pos += by
		b.aim += by
		b.flee_from += by
		_drop.grid.insert(i, b.pos)


## **Nothing that could swallow the cell starts inside dread's reach of it**
## (§8.1): today's rule on top of the quiet start. Whatever could is moved
## straight out, and slid along the rim if the rim holds it back (drop.gd).
func _clear_round(at: Vector2) -> void:
	var mine := _cell.swallow_radius()
	var moved := 0
	_count_ids.resize(0)
	_drop.grid.query(at, DREAD_RANGE + Drop.GRID_SLACK, _count_ids)
	for i: int in _count_ids:
		var b := _cells[i]
		if not b.seeded or b.inert or _gape(b) <= mine:
			continue
		if b.pos.distance_to(at) >= DREAD_RANGE:
			continue
		b.pos = _drop.pushed_clear(at, b.pos, DREAD_RANGE, b.radius)
		b.aim = b.pos
		b.flee_from = b.pos
		_drop.grid.move(i, b.pos)
		moved += 1
	_stat(&"cleared", moved)


## A drop aged before anyone is in it (a tool's `--age=`): stepped alone for
## [param seconds], nobody near and nobody hunted.
func _age_alone(seconds: float) -> void:
	in_water = false
	anchored = false
	for f in roundi(seconds * 60.0):
		_process_drop(1.0 / 60.0)
	in_water = true
	anchored = true


# --- Kept across launches (§9) -------------------------------------------------------------
# game/normal/drop_save.gd is the file and says what it holds (its SHAPE); this
# is the drop gathered into it and made again from it.

## **The drop as plain types** (§9.2): its number, age and frame, its next id,
## its rim, the spawner's debt and the three floors' and the shore's clocks,
## whom its water is made for, which slots are free -- and every body by its
## slot, one column a field, its genome by gene name. Empty outside the drop.
##
## **And, since 1b-2, what every body is doing** (`runs`: a chase and whom at,
## by id, a rest, where it was aiming and every clock of it), which genes the
## floor is short of, the grid as a query finds it, the census's counts and
## whose turn it is -- everything a drop reads that the bodies do not say -- so
## a drop kept and loaded goes on as one that never stopped (ocean.md §14.3
## check 12, the room's case). The people in a pond are nobody's to keep: they
## are left out, and a chase of one is kept as a chase of nobody, which ends on
## its next step as it would have.
##
## **And, since pack 2, every body's lineage** (lineage.md §4): its generation,
## its line, its grace, and its DNA by gene name -- empty where the DNA is the
## body, as it is for every body the water makes, so the column costs a body
## that has not diverged nothing but an empty entry.
##
## **And, since pack 3, every body's rules and what they had it doing**
## (behaviour.md §8): which list it carries -- each list kept once, by its lines
## -- and its held heading, its claims, its random turn, its stun, its last meal,
## a hit it has not felt, its call's clock, its echoes in flight and what its
## rules last read (drop_save.gd's BEHAVIOUR). The runs are still written, for a
## pack-2 build reading this file.
##
## **And, since the toxin's doses, every body's loads** (docs/design/dna-slots.md
## §12): `harm`, `paralysis` and `sleep`, a column a kind, in 64 bits -- they wear
## down like the clocks kept here -- so a dose survives the app being closed
## mid-fight (drop_save.gd's DOSES). A build before them loads the rest.
func drop_state() -> Dictionary:
	if _drop == null:
		return {}
	var slot := PackedInt32Array()
	var ids := PackedInt32Array()
	var parent := PackedInt32Array()
	var generation := PackedInt32Array()
	var lineage := PackedInt32Array()
	var graces := PackedFloat64Array()
	var dna: Array = []
	var kind := PackedByteArray()
	var meals := PackedInt32Array()
	var at := PackedVector2Array()
	var heading := PackedFloat64Array()
	var radius := PackedFloat64Array()
	var wound := PackedFloat64Array()
	var age := PackedFloat64Array()
	var last_t := PackedFloat64Array()
	var hunger := PackedFloat64Array()
	var starve := PackedFloat64Array()
	var effort := PackedFloat64Array()
	var bite := PackedFloat64Array()
	var dart := PackedFloat64Array()
	var dash := PackedFloat64Array()
	var dash_v := PackedFloat64Array()
	var settle := PackedFloat64Array()
	var life := PackedFloat64Array()
	var genome: Array = []
	var run_state := PackedByteArray()
	var run_target := PackedInt64Array()
	var run_flags := PackedByteArray()
	var run_clocks := PackedFloat64Array()
	var run_points := PackedVector2Array()
	var lists: Array = []
	var list_of := {}
	var behaviour := PackedInt32Array()
	var steer := PackedFloat64Array()
	var acts := PackedByteArray()
	var push := PackedFloat64Array()
	var tumble := PackedInt32Array()
	var tumble_tick := PackedInt64Array()
	var stun := PackedFloat64Array()
	var ate := PackedFloat64Array()
	var hit := PackedFloat64Array()
	var hit_from := PackedFloat64Array()
	var calls := PackedFloat64Array()
	var echoes: Array = []
	var memory: Array = []
	var harm := PackedFloat64Array()
	var paralysis := PackedFloat64Array()
	var sleep := PackedFloat64Array()
	for i in _cells.size():
		var b := _cells[i]
		if not b.seeded or b.person != null:
			continue
		slot.append(i)
		harm.append(b.loads[Doses.Kind.HARM])
		paralysis.append(b.loads[Doses.Kind.PARALYSIS])
		sleep.append(b.loads[Doses.Kind.SLEEP])
		ids.append(b.id)
		parent.append(b.parent)
		generation.append(b.generation)
		lineage.append(b.lineage)
		graces.append(b.grace)
		# The DNA is the body when the two hold the same genes at the same copies
		# **in the same order** -- which a load makes again by copying the body --
		# since the order is what a mutation draws from.
		dna.append({} if b.dna == b.genome and b.dna.keys() == b.genome.keys()
			else Genome.tiers_by_name(b.dna))
		kind.append((1 if b.drifter else 0) | (2 if b.inert else 0))
		meals.append(b.meals)
		at.append(b.pos)
		heading.append(b.heading)
		radius.append(b.radius)
		wound.append(b.wound)
		age.append(b.age)
		last_t.append(b.last_t)
		hunger.append(b.hunger)
		starve.append(b.starve)
		effort.append(b.effort)
		bite.append(b.bite)
		dart.append(b.dart_clock)
		dash.append(b.dash_clock)
		dash_v.append(b.dash_v)
		settle.append(b.settle)
		life.append(b.life)
		var genes := {}
		for gene: StringName in b.genome:
			genes[String(gene)] = int(b.genome[gene])
		genome.append(genes)
		run_state.append(b.state)
		run_target.append(_run_target_id(b))
		run_flags.append((1 if b.lunging else 0) | (2 if b.orienting else 0)
			| (4 if b.searching else 0))
		run_clocks.append_array([b.calm, b.stale, b.aim_clock, b.lost, b.rush, b.best,
			b.break_clock, b.stroke, b.wander, b.speed])
		run_points.append(b.aim)
		run_points.append(b.flee_from)
		# Its rules, by the list's place among those kept: a family's once.
		if b.brain == null:
			behaviour.append(-1)
		else:
			if not list_of.has(b.brain):
				list_of[b.brain] = lists.size()
				lists.append(Rulebook.lines_of(b.brain))
			behaviour.append(int(list_of[b.brain]))
		steer.append(b.steer)
		# Bit 3 since pack 4, a held tail (automation.md §5.3, §9.2): optional, so a
		# pack-3 build reading it ignores it.
		acts.append((1 if b.holding else 0) | (2 if b.resting else 0)
			| (4 if b.swimming else 0) | (8 if b.tail_held else 0))
		push.append(b.push)
		tumble.append(b.tumble)
		tumble_tick.append(b.tumble_tick)
		stun.append(b.stun)
		ate.append(b.ate_at)
		hit.append(b.hit)
		hit_from.append(b.hit_from)
		calls.append(b.call_at)
		var flying := PackedFloat64Array()
		for echo: Array in b.echoes:
			var at_: Vector2 = echo[1]
			flying.append_array([float(echo[0]), at_.x, at_.y, float(echo[2]),
				float(echo[3]), float(echo[4])])
		echoes.append(flying)
		var read := {}
		for input: StringName in b.memory:
			var was: Array = b.memory[input]
			var reports: Array = []
			for report: Array in was[1]:
				reports.append(PackedFloat64Array(report))
			read[String(input)] = [int(was[0]), reports]
		memory.append(read)
	var counts := {}
	for what: StringName in stats:
		counts[String(what)] = int(stats[what])
	var short := PackedStringArray()
	for gene: StringName in _gene_short:
		short.append(String(gene))
	return {
		"seed": drop_seed,
		"age": _t,
		"frame": _frame,
		"next_id": _next_id,
		"rim_centre": _drop.meniscus.center,
		"rim_radius": _drop.meniscus.radius,
		"debt": _drop.spawner.debt,
		"widest": _widest_now,
		"clocks": PackedFloat64Array([_eco_clock, _gene_clock, _floor_clock, _shore_clock]),
		"made_for": _made_for_now(),
		"slots": _cells.size(),
		"free": _free.duplicate(),
		"bodies": {"slot": slot, "id": ids, "parent": parent, "kind": kind,
			"meals": meals, "at": at, "heading": heading, "radius": radius,
			"wound": wound, "age": age, "last_t": last_t, "hunger": hunger,
			"starve": starve, "effort": effort, "bite": bite, "dart": dart,
			"dash": dash, "dash_v": dash_v, "settle": settle, "life": life,
			"genome": genome, "generation": generation, "lineage": lineage,
			"grace": graces, "dna": dna, "behaviour": behaviour, "steer": steer,
			"acts": acts, "push": push, "tumble": tumble, "tumble_tick": tumble_tick,
			"stun": stun, "ate": ate, "hit": hit, "hit_from": hit_from, "call": calls,
			"echoes": echoes, "memory": memory, "harm": harm, "paralysis": paralysis,
			"sleep": sleep},
		"behaviours": {"version": DropSave.BEHAVIOURS_VERSION, "lists": lists},
		"runs": {"state": run_state, "target": run_target, "flags": run_flags,
			"clocks": run_clocks, "points": run_points},
		"gene_short": short,
		"grid": _drop.grid.state(),
		"stats": counts,
		"turn": _turn,
	}


## **Whom the water is made for, as the drop keeps it** (§10.3): the players in
## it now, or the last it was made for.
func _made_for_now() -> PackedFloat64Array:
	var tunes := PackedFloat64Array()
	if anchored and _cell != null:
		tunes.append_array([_cell.radius, _sensed()])
	if _pond and not _mirror:
		for k in _guests:
			var pb := _cells[PERSON_SLOT + k]
			if pb.person != null:
				tunes.append_array([pb.radius, _anchor_sensed(Anchor.PERSON + k)])
	if tunes.is_empty():
		tunes = _made_for.duplicate()
	if tunes.size() < 2:
		tunes = PackedFloat64Array([CellBody.BASE_RADIUS, 0.0])
	return tunes


## **Whom a body's run is at, as a file keeps it**: the id of the water body it
## chases, [constant TARGET_PLAYER] for this cell, and [constant TARGET_NONE]
## for nobody -- or for a body the file does not keep: a person, or one gone
## since the run began, whose chase ends on its next step either way.
func _run_target_id(b: Body) -> int:
	if b.target == TARGET_PLAYER:
		return TARGET_PLAYER
	if b.target < 0 or b.target >= _cells.size():
		return TARGET_NONE
	var prey := _cells[b.target]
	if not prey.seeded or prey.person != null or prey.serial != b.target_serial:
		return TARGET_NONE
	return prey.id


## **The drop [param state] holds, made again round [param cell]** (§9.4): the
## drop where it was, every body in its slot with its place, body, tank and
## clocks -- and, from a file that keeps them (1b-2 on), what each was doing,
## the floor's short genes, the grid's order and the counts, so it goes on as it
## would have; from one that does not, drifting. Nobody in it yet -- the caller
## puts the cell back ([method restore_player]) or brings a new one
## ([method return_to_drop]).
##
## **Every body is re-derived from its genome by name** -- upkeep, gape, speed,
## reach -- by this build's tables, which are the save's own unless a content
## pack changed them since: so whatever changed, a radius over this build's cap
## is trimmed to it and a body past its rim is put back inside, while a tank is
## kept as the share it was and the spawner converges on a changed density by
## itself. [param state] must fit drop_save.gd's SHAPE -- its `read` hands over
## nothing else. Returns how many bodies it put back, and how many of them it
## trimmed and contained.
##
## **Every body's rules come back by name** (pack 3, behaviour.md §8), with
## what they had it doing. A file from before keeps none: every hunter loads on
## the founders' rules, its `fed` set from its `calm` so a body resting after a
## meal or a miss rests on.
func load_drop(cell: CellBody, state: Dictionary) -> Dictionary:
	_cell = cell
	_pond = false
	_mirror = false
	_guests = 1
	_water = 0
	in_water = true
	anchored = true
	_snap_at = PackedVector2Array()
	_snap_age = 0.0
	_book.clear()
	_cells.clear()
	_free.resize(0)
	_near.resize(0)
	_stepped.resize(0)
	stats.clear()
	_first_pending = false
	_first_index = -1
	_turn = int(state.get("turn", 0))
	_made_for = PackedFloat64Array(state["made_for"])
	if _made_for.size() < 2 or _made_for.size() % 2 != 0:
		_made_for = PackedFloat64Array([CellBody.BASE_RADIUS, 0.0])
	drop_seed = int(state["seed"])
	_t = float(state["age"])
	_frame = int(state["frame"])
	_next_id = int(state["next_id"])
	var clocks: PackedFloat64Array = state["clocks"]
	_eco_clock = clocks[0]
	_gene_clock = clocks[1]
	_floor_clock = clocks[2]
	_shore_clock = clocks[3]
	_drop = Drop.new(state["rim_centre"])
	_drop.spawner.debt = float(state["debt"])
	_drifter_pool = Drop.drifter_genes(Catalogue.drifters())
	_widest_now = float(state["widest"])
	_living = 0
	_drifters = 0
	_flocs = 0
	for i in int(state["slots"]):
		_cells.append(Body.new())
	var rows: Dictionary = state["bodies"]
	var slot: PackedInt32Array = rows["slot"]
	var ids: PackedInt32Array = rows["id"]
	var parent: PackedInt32Array = rows["parent"]
	var kind: PackedByteArray = rows["kind"]
	var meals: PackedInt32Array = rows["meals"]
	var at: PackedVector2Array = rows["at"]
	var heading: PackedFloat64Array = rows["heading"]
	var radius: PackedFloat64Array = rows["radius"]
	var wound: PackedFloat64Array = rows["wound"]
	var age: PackedFloat64Array = rows["age"]
	var last_t: PackedFloat64Array = rows["last_t"]
	var hunger: PackedFloat64Array = rows["hunger"]
	var starve: PackedFloat64Array = rows["starve"]
	var effort: PackedFloat64Array = rows["effort"]
	var bite: PackedFloat64Array = rows["bite"]
	var dart: PackedFloat64Array = rows["dart"]
	var dash: PackedFloat64Array = rows["dash"]
	var dash_v: PackedFloat64Array = rows["dash_v"]
	var settle: PackedFloat64Array = rows["settle"]
	var life: PackedFloat64Array = rows["life"]
	var genome: Array = rows["genome"]
	# **The lineage, where the file keeps it** (pack 2, lineage.md §4). A file
	# from before has none, and every body in it comes back a founder: generation
	# 1, its own line, its DNA its body and no grace -- as the water made them all.
	var generation: PackedInt32Array = rows.get("generation", PackedInt32Array())
	var lineage: PackedInt32Array = rows.get("lineage", PackedInt32Array())
	var graces: PackedFloat64Array = rows.get("grace", PackedFloat64Array())
	var dna: Array = rows.get("dna", [])
	# **Its loads, where the file keeps them** (docs/design/dna-slots.md §12). A
	# file from before has none, and every body in it comes back carrying none.
	var kept_loads: Array = [rows.get("harm", PackedFloat64Array()),
		rows.get("paralysis", PackedFloat64Array()), rows.get("sleep", PackedFloat64Array())]
	var trimmed := 0
	var contained := 0
	for k in slot.size():
		var b := _cells[slot[k]]
		_serial += 1
		b.serial = _serial
		b.id = ids[k]
		b.parent = parent[k]
		b.generation = generation[k] if not generation.is_empty() else 1
		b.lineage = lineage[k] if not lineage.is_empty() else b.id
		b.grace = graces[k] if not graces.is_empty() else 0.0
		b.drifter = (kind[k] & 1) != 0
		b.inert = (kind[k] & 2) != 0
		b.meals = meals[k]
		b.pos = at[k]
		b.heading = heading[k]
		b.radius = radius[k]
		b.wound = wound[k]
		b.age = age[k]
		b.last_t = last_t[k]
		b.hunger = hunger[k]
		b.starve = starve[k]
		b.effort = effort[k]
		b.bite = bite[k]
		b.dart_clock = dart[k]
		b.dash_clock = dash[k]
		b.dash_v = dash_v[k]
		b.settle = settle[k]
		b.life = life[k]
		for dose in Doses.KINDS:
			var column: PackedFloat64Array = kept_loads[dose]
			b.loads[dose] = maxf(column[k], 0.0) if not column.is_empty() else 0.0
		# **By name**: a gene this build does not know is kept as the name it is,
		# and costs and draws as a retired `rhabdom` always has (the catalogue).
		var genes: Dictionary = genome[k]
		var tiers := {}
		for gene: String in genes:
			tiers[StringName(gene)] = int(genes[gene])
		b.genome = tiers
		# An empty entry is a DNA that is the body: copied, so in the body's order.
		var carried: Dictionary = dna[k] if not dna.is_empty() else {}
		b.dna = b.genome.duplicate() if carried.is_empty() \
			else Genome.tiers_from_names(carried)
		if not b.inert and b.radius > CellBody.DIVIDE_RADIUS:
			b.radius = CellBody.DIVIDE_RADIUS
			trimmed += 1
		# Held inside by the test the running drop holds a body by (see
		# [method _step_one]), so a body it left on the rim is not moved by a
		# hair here: only a rim that is smaller than the one it was kept under.
		var room := _drop.meniscus.radius - b.radius
		if b.pos.distance_squared_to(_drop.meniscus.center) > room * room:
			b.pos = _drop.meniscus.contain(b.pos, b.radius)
			contained += 1
		b.aim = b.pos
		b.flee_from = b.pos
		b.seeded = true
		_refresh_body(b)
		if b.inert:
			_flocs += 1
		else:
			_living += 1
			if b.drifter:
				_drifters += 1
		_drop.grid.insert(slot[k], b.pos)
	_load_runs(state, slot)
	_load_rules(state, slot)
	# The free slots in the order they would have been reused -- and ahead of
	# them, reused last, any empty slot the list had lost track of.
	var listed := {}
	for i: int in state["free"]:
		if i >= 0 and i < _cells.size() and not _cells[i].seeded and not listed.has(i):
			listed[i] = true
			_free.append(i)
	for i in range(_cells.size() - 1, -1, -1):
		if not _cells[i].seeded and not listed.has(i):
			_free.insert(0, i)
	# **What a drop reads that its bodies do not say**, where the file keeps it
	# (1b-2): the genes the floor was short of at its last count, the census's
	# counts, and the grid as its queries found the bodies -- in which order,
	# too, which is what the passes that step, push and eat go by. The grid only
	# for a drop loaded as it was kept: one a conversion moved is filed anew.
	if state.has("gene_short"):
		_gene_short.clear()
		for gene: String in state["gene_short"]:
			_gene_short.append(StringName(gene))
	else:
		_count_genes()
	if state.has("stats"):
		for what: String in state["stats"]:
			stats[StringName(what)] = int(state["stats"][what])
	if state.has("grid") and trimmed == 0 and contained == 0:
		var grid: Array = state["grid"]
		var filed := PackedInt32Array(grid[0])
		var sorted_filed := filed.duplicate()
		sorted_filed.sort()
		var sorted_slots := slot.duplicate()
		sorted_slots.sort()
		if sorted_filed == sorted_slots:
			_drop.grid.restore(filed, PackedInt32Array(grid[1]))
	died_to = -1
	_first_hunt = grace
	_fresh_senses()
	return {"bodies": slot.size(), "trimmed": trimmed, "contained": contained}


## **Every body's rules and what they had it doing, as [param state] keeps
## them** (pack 3), for the bodies in [param slots]: each list read again from
## its lines by declared name -- a name this build does not know is a rule that
## never fires, kept to be written back as it came -- and shared again by the
## bodies that shared it. Lists of a version this build does not know are not
## read: every body is on the founders' rules, doing what it was. **A file from
## before pack 3 keeps none of it**: every hunter on the founders' rules, and a
## body resting after a meal or a miss -- its `calm`, which [method _load_runs]
## gave back -- having eaten as long ago as leaves it resting as long again
## under the founders' `fed below 5` ([constant REST_MEAL]).
func _load_rules(state: Dictionary, slots: PackedInt32Array) -> void:
	var rows: Dictionary = state["bodies"]
	if not rows.has("behaviour"):
		for i: int in slots:
			var b := _cells[i]
			b.brain = null
			b.ate_at = _t - (REST_MEAL - b.calm) if b.calm > 0.0 else -INF
		return
	var kept: Dictionary = state.get("behaviours", {})
	var lists: Array = []
	if int(kept.get("version", DropSave.BEHAVIOURS_VERSION)) == DropSave.BEHAVIOURS_VERSION:
		for lines: PackedStringArray in kept.get("lists", []):
			lists.append(behaviour_from(lines))
	var behaviour: PackedInt32Array = rows["behaviour"]
	var steer: PackedFloat64Array = rows.get("steer", PackedFloat64Array())
	var acts: PackedByteArray = rows.get("acts", PackedByteArray())
	var push: PackedFloat64Array = rows.get("push", PackedFloat64Array())
	var tumble: PackedInt32Array = rows.get("tumble", PackedInt32Array())
	var tumble_tick: PackedInt64Array = rows.get("tumble_tick", PackedInt64Array())
	var stun: PackedFloat64Array = rows.get("stun", PackedFloat64Array())
	var ate: PackedFloat64Array = rows.get("ate", PackedFloat64Array())
	var hit: PackedFloat64Array = rows.get("hit", PackedFloat64Array())
	var hit_from: PackedFloat64Array = rows.get("hit_from", PackedFloat64Array())
	var calls: PackedFloat64Array = rows.get("call", PackedFloat64Array())
	var echoes: Array = rows.get("echoes", [])
	var memory: Array = rows.get("memory", [])
	for k in slots.size():
		var b := _cells[slots[k]]
		b.brain = lists[behaviour[k]] if behaviour[k] >= 0 and behaviour[k] < lists.size() \
			else null
		if not steer.is_empty():
			b.steer = steer[k]
		if not acts.is_empty():
			b.holding = (acts[k] & 1) != 0
			b.resting = (acts[k] & 2) != 0
			b.swimming = (acts[k] & 4) != 0
			b.tail_held = (acts[k] & 8) != 0
		if not push.is_empty():
			b.push = push[k]
		if not tumble.is_empty():
			b.tumble = tumble[k]
		if not tumble_tick.is_empty():
			b.tumble_tick = tumble_tick[k]
		if not stun.is_empty():
			b.stun = stun[k]
		if not ate.is_empty():
			b.ate_at = ate[k]
		if not hit.is_empty():
			b.hit = hit[k]
		if not hit_from.is_empty():
			b.hit_from = hit_from[k]
		if not calls.is_empty():
			b.call_at = calls[k]
		b.echoes = []
		if not echoes.is_empty():
			var flying: PackedFloat64Array = echoes[k]
			for e in range(0, flying.size(), DropSave.ECHO_NUMBERS):
				b.echoes.append([flying[e], Vector2(flying[e + 1], flying[e + 2]),
					flying[e + 3], flying[e + 4], flying[e + 5]])
		b.memory = {}
		if not memory.is_empty():
			var read: Dictionary = memory[k]
			for input: String in read:
				var was: Array = read[input]
				var reports: Array = []
				for report: PackedFloat64Array in was[1]:
					reports.append(Array(report))
				b.memory[StringName(input)] = [int(was[0]), reports]


## **What every body was doing, as [param state] keeps it** (1b-2 on), for the
## bodies in [param slots]: its run's state, whom at -- found again by id --
## its three switches, its clocks and where it was aiming and fleeing from. A
## file without it leaves every body drifting, as 1b-1's did.
func _load_runs(state: Dictionary, slots: PackedInt32Array) -> void:
	if not state.has("runs"):
		return
	var runs: Dictionary = state["runs"]
	var run_state: PackedByteArray = runs["state"]
	var run_target: PackedInt64Array = runs["target"]
	var run_flags: PackedByteArray = runs["flags"]
	var clocks: PackedFloat64Array = runs["clocks"]
	var points: PackedVector2Array = runs["points"]
	var by_id := {}
	for i: int in slots:
		by_id[_cells[i].id] = i
	for k in slots.size():
		var b := _cells[slots[k]]
		b.state = run_state[k]
		var target := run_target[k]
		b.target = TARGET_NONE
		b.target_serial = 0
		if target == TARGET_PLAYER:
			b.target = TARGET_PLAYER
		elif target > 0 and by_id.has(target):
			b.target = int(by_id[target])
			b.target_serial = _cells[b.target].serial
		b.lunging = (run_flags[k] & 1) != 0
		b.orienting = (run_flags[k] & 2) != 0
		b.searching = (run_flags[k] & 4) != 0
		var c := k * RUN_CLOCKS
		b.calm = clocks[c]
		b.stale = clocks[c + 1]
		b.aim_clock = clocks[c + 2]
		b.lost = clocks[c + 3]
		b.rush = clocks[c + 4]
		b.best = clocks[c + 5]
		b.break_clock = clocks[c + 6]
		b.stroke = clocks[c + 7]
		b.wander = clocks[c + 8]
		b.speed = clocks[c + 9]
		b.aim = points[2 * k]
		b.flee_from = points[2 * k + 1]


## **What the water keeps of the cell in it** (§9.2): its grace (row 16), the
## clocks of its dart and its bite, and the authored first drifter while the
## cell has still not moved -- by its id, since its slot is the drop's to
## reuse. The part of a cell left mid-run that is the field's and not the body's.
func player_state() -> Dictionary:
	var first := 0
	if _first_pending and _first_index >= 0 and _first_index < _cells.size() \
			and _cells[_first_index].seeded \
			and _cells[_first_index].serial == _first_serial:
		first = _cells[_first_index].id
	return {"grace": _first_hunt, "dart": _dart_clock, "bite": _bite_clock,
		"first": first}


## **The cell left mid-run is back in the drop [method load_drop] made**, where
## it was: its grace and its clocks as [method player_state] took them, and its
## first drifter, if it had one waiting, still waiting. Nothing is cleared round
## it and nothing moved: closing the app was a pause (row 17).
func restore_player(state: Dictionary) -> void:
	in_water = true
	anchored = true
	_first_hunt = float(state["grace"])
	_dart_clock = float(state["dart"])
	_bite_clock = float(state["bite"])
	var first := int(state["first"])
	for i in _cells.size():
		if first > 0 and _cells[i].seeded and _cells[i].id == first:
			_first_index = i
			_first_serial = _cells[i].serial
			_first_pending = true
			break


## **A cell kept with the frame its place was measured in comes back to it**
## (docs/design/cells.md §1.4): [method restore_player], and -- when
## [param moved_on], the water having run on since it was kept, under another
## cell -- whatever could swallow it is moved out of dread's reach of where it
## is, as a quiet start clears round a born cell ([method _clear_round]). The
## caller has put the body back at its place, moved by however far the drop has
## moved under it since.
func resume_player(state: Dictionary, moved_on: bool) -> void:
	restore_player(state)
	if moved_on:
		_clear_round(_cell.position)


# --- The frame (§4) ----------------------------------------------------------------------

func _process_drop(delta: float) -> void:
	_frame += 1
	_t += delta
	_shore_clock = maxf(_shore_clock - delta, 0.0)
	if in_water:
		_contain_player(true)
	# The drift path does not exist until the cell drifts: the first drifter
	# is put along it then, as today's water puts it (§6.4).
	if _first_pending and in_water and _cell.velocity.length_squared() > 1.0:
		_first_pending = false
		_place_first()
	if _first_hunt > 0.0:
		_first_hunt -= delta
	_dart_clock = maxf(_dart_clock - delta, 0.0)
	_bite_clock = maxf(_bite_clock - delta, 0.0)
	# **The people first, in a pond** (§10.2): carried to where they are now,
	# so every chase this frame leads the place they are, as this cell has
	# already moved by the time this node runs.
	if _pond:
		for k in _guests:
			_step_person(delta, PERSON_SLOT + k)
	# On rules, the water senses this cell where it is now (behaviour.md §12.1).
	if rules:
		_refresh_me()
	_step_drop_bodies()
	_near.resize(0)
	if anchored:
		_drop.grid.query(_cell.position, _scan_reach() + _widest_now + Drop.GRID_SLACK,
			_near)
	if _pond:
		_gather_people()
	# Contact first, then separation, for the reason today's frame gives; and
	# a death stops the frame where it lands, as it does there -- **but not in a
	# pond**, where the water goes on for the other player, and this cell leaves
	# it instead (shared-pond.md §1.5).
	if in_water and _contacts_with(null):
		if not _pond:
			return
		_lose_local()
	if _pond:
		for k in _guests:
			_contacts_person(PERSON_SLOT + k)
		if _guests > 1:
			_guests_meet()
	_contacts_drop()
	_separate_drop()
	if in_water:
		_contain_player(false)
	_eco_clock += delta
	if _eco_clock >= Drop.SPAWN_TICK:
		_ecology(_eco_clock)
		_eco_clock = 0.0
	if in_water:
		_step_organs(delta)


## **The same rules at a lower rate** (§4.3). Within LOD_FULL of the player,
## every frame; out to LOD_NEAR, every second frame; past it, on the body's
## tick -- its slot modulo LOD_EVERY, a stride through the array and never a
## scan of it -- and a body with no mouth once in LOD_SLOW ticks. Each is
## stepped with all the time it is owed. Every mouth decides on its tick and
## only then, near or far, so a decision is made at one rate everywhere.
func _step_drop_bodies() -> void:
	var tick := _frame % Drop.LOD_EVERY
	_stepped.resize(0)
	# A person is stepped as a person ([method _step_person]), never as water.
	if not lod:
		for i in _cells.size():
			if _cells[i].seeded and _cells[i].person == null:
				_step_one(i, _cells[i], tick)
		return
	# **Every player is an anchor** (§10.2): near means near any of them.
	var anchors := _anchor_points()
	_lod_ids.resize(0)
	for a: Vector2 in anchors:
		_drop.grid.query(a, Drop.LOD_NEAR + Drop.GRID_SLACK, _lod_ids)
	var near2 := Drop.LOD_NEAR * Drop.LOD_NEAR
	var full2 := Drop.LOD_FULL * Drop.LOD_FULL
	var half := _frame % 2
	for i: int in _lod_ids:
		var b := _cells[i]
		# Asked twice, by two players, it is stepped once.
		if not b.seeded or b.near_frame == _frame:
			continue
		var d2 := INF
		for a: Vector2 in anchors:
			d2 = minf(d2, b.pos.distance_squared_to(a))
		if d2 > near2:
			continue
		b.near_frame = _frame
		# LOD_EVERY is even, so a body's tick is always one of its half-rate
		# frames: no decision is ever skipped.
		if half_rate and d2 > full2 and (i % 2) != half:
			continue
		_step_one(i, b, tick)
	var slow := (_frame / Drop.LOD_EVERY) % Drop.LOD_SLOW
	var i := tick
	var n := _cells.size()
	while i < n:
		var b := _cells[i]
		if b.seeded and b.near_frame != _frame and b.person == null \
				and (not b.drifter or ((i / Drop.LOD_EVERY) % Drop.LOD_SLOW) == slow):
			_step_one(i, b, tick)
		i += Drop.LOD_EVERY


## One body, with the time it is owed: its grace, its tank, then what it does --
## or, at DIVIDE_RADIUS on its tick, two daughters where it was -- then held
## inside the rim and filed again if it crossed a bucket line.
##
## **A body at DIVIDE_RADIUS divides on its tick** (lineage.md §2.1), the 7.5
## times a second every mouth decides, near the player or far from it: the first
## tick it is at forty, whatever it was doing -- a run, a rest after the meal
## that grew it, a search. Nothing makes it wait. A tank that ran out first is a
## death, and there is nobody left to divide.
func _step_one(i: int, b: Body, tick: int) -> void:
	var dt := _t - b.last_t
	b.last_t = _t
	b.stepped = _frame
	_stepped.append(i)
	if b.inert:
		_age_floc(i, b, dt)
		return
	b.look = (i % Drop.LOD_EVERY) == tick
	b.age += dt
	if b.grace > 0.0:
		b.grace = maxf(b.grace - dt, 0.0)
	if _tank(i, b, dt):
		return
	# **Its loads wear, with all the time it is owed** (docs/design/dna-slots.md
	# §6.2): exact for any step, so a far body stepped on its tick ends where a
	# near one does. A wound made whole by harm is a death by poison, and it
	# returns as a starvation does: nothing here files a body it has retired.
	if _dose_step(i, b, dt):
		return
	if births and b.look and not b.drifter and b.radius >= CellBody.DIVIDE_RADIUS - 0.01:
		_divide(i, b)
		return
	_step_body(i, dt)
	var m := _drop.meniscus
	var room := m.radius - b.radius
	if b.pos.distance_squared_to(m.center) > room * room:
		b.pos = m.contain(b.pos, b.radius)
	_drop.grid.move(i, b.pos)


# --- One body for every cell (§5) ------------------------------------------------------

## **The player's tank, line for line** (§5.2, metabolism.gd): being alive at
## its upkeep less what it takes in without eating, over its store, and what
## it did since it last paid, at its burn. Empty for STARVE_GRACE and it dies
## of hunger, leaving its remains. Returns whether it did.
##
## **A tank that cannot move is not stepped**: taking in at least its upkeep
## and having done nothing, its hunger cannot change until it eats -- which is
## most drifters, most of the time -- so skipping it changes no number (§4.4).
func _tank(i: int, b: Body, dt: float) -> bool:
	if skip_still and b.effort == 0.0 and b.starve == 0.0 and b.hunger < 1.0 \
			and b.upkeep <= b.income:
		return false
	b.hunger = clampf(b.hunger
		+ dt * Metabolism.rest_rate(b.upkeep, b.income, b.reserve) / Metabolism.HUNGER_SECONDS
		+ Metabolism.effort_cost(b.effort, b.burn, b.reserve), 0.0, 1.0)
	b.effort = 0.0
	if b.hunger < 1.0:
		b.starve = 0.0
		return false
	b.starve += dt
	if b.starve < Metabolism.STARVE_GRACE:
		return false
	_consume(i, Cause.STARVED)
	return true


## **One body's loads, worn over [param dt]** (docs/design/dna-slots.md §6.2),
## through cell.gd's one dose step every body takes: the harm that wore off goes
## into its wound, and it mends only for the part of the step after the harm ran
## out. Returns true when harm made the wound whole -- **a death by poison**: the
## body leaves the water with its remains, and the caller stops touching it. A
## body carrying nothing is mended as it always was, for one test.
func _dose_step(i: int, b: Body, dt: float) -> bool:
	b.wound = CellBody.dosed(b.loads, b.wound, b.radius, dt)
	if b.wound < 1.0:
		return false
	_consume(i, Cause.POISONED)
	return true


## A meal worth [param nutrition] of one whole meal, by the one definition every
## body's goes through (metabolism.gd).
func _feed_water(b: Body, nutrition: float) -> void:
	b.hunger = maxf(b.hunger - Metabolism.meal(nutrition), 0.0)
	b.starve = 0.0
	# **What `fed` counts from** (behaviour.md §3.2): a cell, a floc or a player.
	b.ate_at = _t
	# And, on rules, which senses fed the water (§12.3 check 9): every meal of a
	# hunter wearing a nose, a radar or a laser.
	if _ruled() and not b.drifter:
		if Catalogue.worn_provider(b.genome, &"smell_range") != &"":
			_stat(&"meals_nose")
		if Catalogue.worn_provider(b.genome, &"ping_range") != &"":
			_stat(&"meals_radar")
		if Catalogue.worn_provider(b.genome, &"beam_range") != &"":
			_stat(&"meals_laser")


## **Growth, as the player grows** (§5.5): a unit of radius a meal to
## DIVIDE_RADIUS and no further, and the meal's gene into the slots that radius
## has. The mouth keeps whatever it grows (row 5).
##
## **The meal is written to the DNA** (lineage.md §3.2), by the rule the
## player's lapsed sample follows: a copy more of a gene it carries, up to three,
## or a new one into a free slot, or lost. **Never to the body**, which is fixed
## at birth, as yours is: what it eats reaches its daughters, and it hunts and
## pays and is drawn as what it was born wearing. Where nothing divides --
## [member births] off, which is pack 1, and today's water -- the body grows the
## organ as well, as it always did.
func _grow(b: Body, gene: StringName) -> void:
	b.radius = minf(b.radius + CellBody.GROWTH_PER_MEAL, CellBody.DIVIDE_RADIUS)
	b.meals += 1
	var slots := CellBody.slots_for(b.radius)
	Genome.integrate_into(b.dna, gene, slots)
	if not (births and _drop != null):
		Genome.integrate_into(b.genome, gene, slots)
		b.derive()
	_refresh_body(b)
	_changes += 1


## **The cell that eats you is fed by it** (§5.6): your size against its own,
## a unit of growth and your dominant gene, then REST_MEAL as after any meal.
func _fed_on_player(b: Body) -> void:
	_fed_on(b, _cell.radius, _local_dominant())


## [method _fed_on_player] for any player: one of [param radius], most made of
## [param gene] -- this cell, or the other player in a pond.
func _fed_on(b: Body, radius: float, gene: StringName) -> void:
	_feed_water(b, _meal_value_for(radius, b.radius))
	_grow(b, gene)
	_rest(b, REST_MEAL)
	_stat(&"ate_player")


## How big [param b] is to a mouth: its radius, times its `pellicle`'s armour
## (row 5).
func _swallow_r(b: Body) -> float:
	return armoured_size(b.radius, b.armour, armour_swallow)


## **Where the run stops**: no target, and this long before its hunger decides
## again -- REST_MEAL after a meal, REST_MISS after a miss (§5.4).
func _rest(b: Body, seconds: float) -> void:
	b.state = State.DRIFT
	b.target = TARGET_NONE
	b.target_serial = 0
	b.lost = 0.0
	b.rush = 0.0
	b.stale = 0.0
	b.break_clock = 0.0
	b.lunging = false
	b.orienting = false
	b.searching = false
	b.calm = seconds


## What its organs buy, read once whenever its genome or its radius changes. Its
## `stat_` fields are already read ([method Body.derive]): by the genome's setter,
## or by whoever edited the genome in place on its way here -- a meal, a drop's
## load, the toxin given back.
func _refresh_body(b: Body) -> void:
	var g := b.genome
	b.upkeep = Genome.upkeep_of(g)
	b.reserve = Stats.of(g, &"store")
	b.sun = Stats.of(g, &"sun")
	# **A body with no mouth absorbs** (§5.3, row 11): an income like light, keyed
	# on the organ and not on what made the body.
	b.income = b.sun + (absorb if Catalogue.worn_provider(g, &"gape") == &"" else 0.0)
	b.burn = Stats.of(g, &"burn")
	b.armour = b.stat_armor
	b.cruise = CellBody.swim_speed_of(g)
	# Pack 3 (behaviour.md §4.5): its tail alone, the push being a trigger of
	# its own -- and, for a mouth in a drop of this field's own, its organs as its
	# senses read them (§12.1).
	b.tail = b.stat_speed
	b.turn_rate = b.stat_turn
	b.thrust = Stats.of(g, &"push_accel")
	b.dart_tier = b.stat_dart_tier
	# Pack 4 (automation.md §5.3): its tail's level is its copies, as its beam's is --
	# the level its rules count the tail's organ at, the best of any key of it worn
	# (catalogue.gd's `organ_level`; gene-catalogue.md §15.6).
	b.tail_level = Catalogue.organ_level(g,
		Catalogue.organ_of(Catalogue.worn_provider(g, &"impulse_speed")))
	b.eye = _eye_of(b) if _drop != null and not _mirror and not _replay \
		and not b.drifter and not b.inert else null
	b.worn = _worn_of(g) if b.eye != null else PackedInt64Array()
	# Each sense's reach is the organ that senses (stats.gd's `seated`): the first in
	# the default order's slots where it wears two noses, two radars or two eyes.
	var order: Array = Cilia.default_order(g) if Stats.seats_decide(g) else []
	var smell := Stats.seated(order, g, &"smell_range")
	var ping := Stats.seated(order, g, &"ping_range")
	var beam := Stats.seated(order, g, &"beam_range")
	var touch := Stats.of(g, &"touch_range")
	b.notice = maxf(maxf(smell, ping), maxf(beam, touch))
	# A radar does not hear a floc and an eyespot does not see one (§7.5): a
	# floc is found by the nose, the beam or the palp.
	b.notice_floc = maxf(smell, maxf(beam, touch))
	b.see_big = SHADOW_RANGE if Catalogue.worn_on(g, Catalogue.LIGHT) != &"" else 0.0
	b.dart_bearing = 0.0
	if b.dart_tier > 0:
		b.dart_bearing = Cilia.slot_bearing(_seat_of(Cilia.default_order(g), g, &"dart_range"))
	_widest_now = maxf(_widest_now, b.radius)


# --- Behaviour, the hand-written kind (§5.4): pack 3's blocks replace it ----------------

## **Drifting, or swimming to look.** A body at rest is carried at DRIFT_SPEED,
## which is free -- the water carries it -- and turns off the shore. A hungry
## hunter that found nothing swims at its own speed instead, and pays for it.
## A mouth decides on its tick.
func _drift_in_drop(index: int, b: Body, delta: float) -> void:
	b.calm = maxf(b.calm - delta, 0.0)
	b.heading = wrapf(b.heading + randf_range(-DRIFT_TURN, DRIFT_TURN) * delta, -PI, PI)
	_shore_turn(b, delta)
	var pace := DRIFT_SPEED
	if b.searching:
		pace = _cruise_speed(b)
		b.effort += CellBody.stroke_cost(pace) * delta
	b.pos += _forward(b.heading) * pace * delta
	b.speed = pace
	if b.drifter or not b.look:
		return
	_decide(index, b)


## **What a mouth does, decided on its tick** (§5.4, §12): rest while it is fed
## or digesting -- which still leaves what is touching it -- and otherwise look
## for the nearest thing its own senses find and its mouth can take; swim to
## look when there is nothing. The entry pack 3's blocks take over.
func _decide(index: int, b: Body) -> void:
	var resting := b.calm > 0.0 or b.hunger < HUNT_AT
	var reach := 0.0
	if not resting:
		reach = maxf(b.notice, b.see_big) if notice_by_senses else NOTICE_RANGE
	_look_for_prey(index, b, reach)
	b.searching = not resting and b.state == State.DRIFT


## **The nearest thing it can eat that its own senses find** (§4.2, §5.7): the
## player, a body or a settled floc, asked of the grid -- the buckets within
## PREY_NEAR first, and the whole reach only when nothing that near answered,
## since nearest wins and anything nearer lay in those buckets.
##
## **Nothing in its grace is a run's beginning** (lineage.md §3.4): the player
## for FIRST_DELAY after a birth, a division or a return, the other players for
## theirs, and every newborn in the water -- a daughter, water or sister -- for
## [member newborn_grace]. It is not armour: what a mouth touches is decided by
## the contacts, and a newborn that drifts into one that fits is swallowed.
func _look_in_drop(index: int, b: Body, reach: float) -> void:
	var gape := _gape(b)
	var best := TARGET_NONE
	var best_serial := 0
	var best_d := INF
	if in_water and _first_hunt <= 0.0 and _worth_committing_to(b, gape,
			_cell.swallow_radius(), _cell.wound):
		var d := b.pos.distance_to(_cell.position)
		if d <= maxf(reach, b.radius + _cell.radius) \
				and _senses_find(b, d, _cell.radius, false):
			best = TARGET_PLAYER
			best_d = d
	# **The other players, in a pond, by the same rule** (§10.2): nothing
	# before their own grace, their armoured body against this mouth, and only
	# what this body's own senses find. This cell, tested first, keeps a tie.
	if _pond:
		for k in _guests:
			var slot := PERSON_SLOT + k
			var pb := _cells[slot]
			var p := pb.person
			if p == null or not pb.seeded or p.first_hunt > 0.0:
				continue
			if not _worth_committing_to(b, gape, pb.radius * p.armour, pb.wound):
				continue
			var d := b.pos.distance_to(pb.pos)
			if d <= maxf(reach, b.radius + pb.radius) and d < best_d \
					and _senses_find(b, d, pb.radius, false):
				best = slot
				best_serial = pb.serial
				best_d = d
	var full := maxf(reach, b.radius + _widest_now)
	var passes := 2 if (near_first and full > Drop.PREY_NEAR) else 1
	for pass_k in passes:
		_prey_ids.resize(0)
		_drop.grid.query(b.pos, (Drop.PREY_NEAR if pass_k < passes - 1 else full)
			+ Drop.GRID_SLACK, _prey_ids)
		for j: int in _prey_ids:
			if j == index:
				continue
			var other := _cells[j]
			if not other.seeded or other.grace > 0.0:
				continue
			var d := b.pos.distance_to(other.pos)
			if not (d <= maxf(reach, b.radius + other.radius) and d < best_d):
				continue
			if other.inert:
				if other.settle < 1.0 or other.radius >= gape:
					continue
			elif not _worth_committing_to(b, gape, _swallow_r(other), other.wound):
				continue
			if not _senses_find(b, d, other.radius, other.inert):
				continue
			best = j
			best_serial = other.serial
			best_d = d
		if pass_k < passes - 1 and best_d <= Drop.PREY_NEAR:
			break
	if best == TARGET_NONE:
		return
	_start_run(b, best, best_serial)


## **Whether its own senses find something [param body_radius] big at
## [param d]** (§5.7): what touches it, always; else within the reach of its
## nose, radar, beam or palp -- a floc only by nose, beam or palp -- or of its
## eyespot, for a body big enough to cast a shadow.
func _senses_find(b: Body, d: float, body_radius: float, floc: bool) -> bool:
	if not notice_by_senses or d <= b.radius + body_radius:
		return true
	if floc:
		return d <= b.notice_floc
	if d <= b.notice:
		return true
	return d <= b.see_big and body_radius >= SHADOW_MIN_RATIO * b.radius


## **A run begins**, at [param target]. A body spotted from afar is turned onto
## first, at its own cirrus's rate (§5.4); today's snapped its nose round.
func _start_run(b: Body, target: int, serial: int) -> void:
	b.target = target
	b.target_serial = serial
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
	b.searching = false
	b.orienting = false
	b.aim = _target_pos(b)
	b.flee_from = b.aim
	if b.pos.distance_to(b.aim) > LUNGE_RANGE:
		if own_speed:
			b.orienting = true
		else:
			b.heading = _angle_of(b.aim - b.pos, b.heading)
	_stat(&"runs_at_player" if target == TARGET_PLAYER else &"runs")


## **Turning onto what it found**, drifting meanwhile, at its cirrus's rate and
## price. Returns false once the prey is inside half the lock cone, when the
## run's clocks begin; true for a frame spent turning, or given up after
## ORIENT_SECONDS.
func _orient(b: Body, offset: Vector2, delta: float) -> bool:
	if absf(angle_difference(b.heading, _angle_of(offset, b.heading))) \
			<= deg_to_rad(LOCK_CONE_DEG) * 0.5:
		b.orienting = false
		b.lost = 0.0
		b.rush = 0.0
		b.best = INF
		b.aim_clock = 0.0
		b.break_clock = 0.0
		return false
	b.break_clock += delta
	if b.break_clock > ORIENT_SECONDS:
		b.orienting = false
		_break_off(b)
		return true
	b.aim = _target_pos(b)
	_swim(b, delta, DRIFT_SPEED)
	return true


## **`trichocyst` defends every body** (§5.7): a run at a water cell breaks as a
## run at the player does -- inside the dart's range, on the arc it is worn on,
## and then its cooldown. Returns whether this run was broken.
func _darted_off(b: Body, d: float) -> bool:
	if b.target < 0:
		return false
	var prey := _target_body(b)
	if prey == null or prey.person != null or prey.inert:
		return false
	if prey.stat_dart_tier <= 0 or prey.dart_clock > 0.0 or d >= prey.stat_dart_range:
		return false
	var from := _angle_of(b.pos - prey.pos, prey.heading)
	if absf(angle_difference(prey.heading + prey.dart_bearing, from)) \
			> deg_to_rad(CellBody.DART_ARC_DEG) * 0.5:
		return false
	prey.dart_clock = prey.stat_dart_cooldown
	_stat(&"water_darts")
	_break_off(b)
	return true


## **A lunge is a `myoneme` dash** (row 14): the player's own burst, at its price
## and on its cooldown -- or nothing, for a body without one.
func _dash(b: Body) -> void:
	if not own_speed or b.dash_clock > 0.0:
		return
	if b.stat_dash_tier <= 0:
		return
	b.dash_v = b.stat_dash_speed
	b.dash_clock = CellBody.DASH_COOLDOWN
	b.effort += b.stat_dash_cost * Metabolism.HUNGER_SECONDS
	_stat(&"water_dashes")


## **A drifting body turns off the shore** (§3.1): heading outward inside the
## shallows, toward the middle at up to SHORE_TURN, by how deep it is in them.
func _shore_turn(b: Body, delta: float) -> void:
	var depth := _drop.meniscus.depth(b.pos)
	if depth > Drop.SHALLOWS:
		return
	var out := b.pos - _drop.meniscus.center
	if out.length_squared() <= 0.0 or _forward(b.heading).dot(out) <= 0.0:
		return
	b.heading = wrapf(rotate_toward(b.heading, _angle_of(-out, b.heading),
		Drop.shore_turn(depth) * delta), -PI, PI)


# --- Behaviour by rules (docs/design/behaviour.md §3-§5): pack 3's ----------------------
# Every body in a drop of this field's own runs here while [member rules] is on.
# The rules' arithmetic -- reading from the top, one winner for each trigger --
# is rulebook.gd's, which knows no organ. This is the wiring: each declared name
# to the function that reads it for a body or performs it, the body's triggers,
# and what the water reads off a body coming for someone.

## **Leading** (§4.2, §6.5): a turn toward an input that also reported last
## tick aims ahead of its bearing by this many times how far the bearing
## drifted since -- the textbook navigation constant, a starting value.
const LEAD := 3.0
## **A bearing that jumps belongs to a new target** and is aimed at straight
## (§4.2): a drift wider than this, in radians, between one tick and the next.
## Not in the spec's table: a starting value, 30 degrees.
const LEAD_JUMP := 0.5235987755982988
## **Coming for you** (§4.3, §6.5): a cell swimming with you within this many
## degrees of its heading, half today's LOCK_CONE_DEG -- and its cosine.
const COMING_CONE_DEG := 35.0
const COMING_COS := 0.8191520442889918
## The census's names for the founders' rules firing, one each (§12.3 check 9).
const FIRED: Array[StringName] = [&"fired_1", &"fired_2", &"fired_3", &"fired_4",
	&"fired_5", &"fired_6", &"fired_7", &"fired_8"]


## **Every input and output a body's rules can name** (behaviour.md §3): the
## body's, the metabolism's and the genes' -- and any a tool declared
## ([method declare]) -- made once a process.
static func vocabulary() -> Rulebook.Vocabulary:
	if _vocabulary == null:
		var tables: Array = [CellBody.DECLARES, Metabolism.DECLARES, Catalogue.declares()]
		tables.append_array(_declared)
		_vocabulary = Rulebook.vocabulary(tables)
		for owner: StringName in CellBody.DECLARES:
			_everybody[owner] = true
		for owner: StringName in Metabolism.DECLARES:
			_everybody[owner] = true
	return _vocabulary


## **A tool's seam: genes of its own, declared** (behaviour.md §3.5, §12.3 check
## 8) -- [param tables] in the shape the genes declare in, read after the game's
## own, as a new gene's entry there would be. The vocabulary and the founders'
## rules are made again at once; a list read before keeps the bits it was read
## with, so a tool declares before it makes the water it plays, and declares
## nothing again before it plays another. Its organs' readers and triggers it
## wires itself, as a subclass's `_wire`. Nothing in the game calls this.
static func declare(tables: Array) -> void:
	_declared = tables.duplicate()
	_vocabulary = null
	_founders = null
	founders()


## **The founders' rules** (drop.gd's FOUNDERS, behaviour.md §5.1), read once.
static func founders() -> Rulebook.Behaviour:
	if _founders == null:
		_founders = Rulebook.from_lines(PackedStringArray(Drop.FOUNDERS), vocabulary())
	return _founders


## **A list from its lines**, by declared name (§8): what a body carries, for a
## save or a tool. A line this build cannot read is a rule that never fires.
static func behaviour_from(lines: PackedStringArray) -> Rulebook.Behaviour:
	return Rulebook.from_lines(lines, vocabulary())


## Whether this field's own drop runs on rules: not a mirror's picture of
## another's, nor a replay's.
func _ruled() -> bool:
	return rules and _drop != null and not _mirror and not _replay


## **What of the vocabulary a body with [param parts] has, as the rulebook's
## bits** (§3.5): `Rulebook.worn` over a gene to the level it works at -- a water
## cell's worn copies, or a daughter's DNA copies for what a change may draw --
## counted by organ (catalogue.gd's `by_organ`), and what every body has. **Pack
## 3's water has no part at a level** ([member tails_beat] off): those bits are
## never there, so nothing a level brings fires, nor is drawn by a change, and the
## drop is pack 3's to the byte.
func _worn_of(parts: Dictionary) -> PackedInt64Array:
	var mask := Rulebook.worn(vocabulary(), Catalogue.by_organ(parts), _everybody)
	return mask if tails_beat else Rulebook.without(mask, vocabulary().levelled)


## **The wiring** (§3.5 step 3), made on first use: each declared input to the
## function that reads it for any body, and each declared output to the one
## that performs it, under the declared names.
func _wire() -> void:
	if not _readers.is_empty():
		return
	_readers = {
		&"metabolism.hunger": _read_hunger,
		&"metabolism.fed": _read_fed,
		&"body.hit": _read_hit,
	}
	_triggers = {
		&"body.turn-toward": _turn_toward,
		&"body.turn-away": _turn_away,
		&"body.turn-random": _turn_random,
		&"body.swim": _swim_on,
		&"body.rest": _rest_on,
	}
	wire_parts(_readers, {&"smell": _read_smell, &"shadow": _read_shadow,
		&"touch": _read_touch, &"beam": _read_beam, &"echo": _read_echo}, true)
	wire_parts(_triggers, {&"dash": _dash_on, &"push": _push_on, &"hold": _hold_on}, false)
	_read_with = _read_input
	founders()


## **The genes' parts, wired by the names their organs declare them by**
## (gene-catalogue.md §6): [param by_part] -- a part as it is declared, `smell`,
## `dash` -- to the function that reads it or performs it, written into
## [param into] under the qualified name each organ of [method Catalogue.declares]
## has it by, `chemocyte.smell`. The parts are the organ's, so every variant of it
## is read and performed as its organ is, and no gene is named here. [param inputs]
## for what a body reads, else what it does. Your own instincts are wired the same
## way (own_rules.gd).
static func wire_parts(into: Dictionary, by_part: Dictionary, inputs: bool) -> void:
	var vocab := vocabulary()
	var declared: Dictionary = vocab.inputs if inputs else vocab.outputs
	var organs := Catalogue.declares()
	for name: StringName in declared:
		var decl: Variant = declared[name]
		if not organs.has(decl.owner):
			continue
		var part := Rulebook.part_of(name)
		if by_part.has(part):
			into[name] = by_part[part]


## **The trigger this field performs [param output] with**, for a body it does
## not step: the player's, whose instincts run on the water's own triggers
## (game/normal/own_rules.gd, automation.md §13) -- the held heading, the random
## turn, the claims -- so an instinct means the same in both bodies. An invalid
## callable for a name nothing performs.
func trigger(output: StringName) -> Callable:
	if _readers.is_empty():
		_wire()
	return _triggers.get(output, Callable())


## **What every body has**, owner to true: the body's own parts and its
## metabolism's, which `Rulebook.worn` counts at the first level whatever a body
## wears.
static func everybody() -> Dictionary:
	vocabulary()
	return _everybody


## **What the body whose rules are being read reports on [param input]**, by
## the function wired to the name: reports nearest first, each its declared
## values in order -- its bearing first where it has one, and after them, for
## the steering alone, the world direction of that bearing. A name with nothing
## wired to it reports nothing.
func _read_input(input: StringName) -> Array:
	var reader: Callable = _readers.get(input, Callable())
	if not reader.is_valid():
		return []
	return reader.call(_reading_slot, _reading)


## **A body's organs as its senses read them** (§4.4, §12.1): each at its tier
## -- a beam by its copies, as a water cell has no levels -- on the arc the
## default order puts it on, as the run aims yours, and its mouth. Kept on the
## body and made again whenever what it wears or its size changes: in the drop
## a radius moves only through a door that refreshes the body.
func _eye_of(b: Body) -> Observer:
	var g := b.genome
	var o := b.eye if b.eye != null else Observer.new()
	o.radius = b.radius
	o.gape = _gape(b)
	var order := Cilia.default_order(g)
	# A seated sense is all one organ's (stats.gd's `seated`): its reach, its period,
	# its pass and its copies, the first in slot order where it wears several.
	o.smell_range = Stats.seated(order, g, &"smell_range")
	o.smell_bearing = _arc_in(order, g, &"smell_range")
	o.touch_range = Stats.of(g, &"touch_range")
	o.eyespot = Catalogue.worn_on(g, Catalogue.LIGHT) != &""
	o.ping_range = Stats.seated(order, g, &"ping_range")
	o.ping_tier = Stats.seated_tier(order, g, &"ping_range")
	o.ping_period = Stats.seated(order, g, &"ping_period")
	o.ping_through = Stats.seated(order, g, &"ping_through")
	o.ping_bearing = _arc_in(order, g, &"ping_range")
	# The beam as the run aims yours below its fork (normal_mode.gd's
	# `_aim_beam`): a fixed fan of its rung's rays, spread about the arc.
	var beam := Stats.organ(order, g, &"beam_range")
	var shape := CellBody.beam_shape(Stats.tier_of(g, beam, &"beam_range"), &"", beam)
	o.beam_range = float(shape[3])
	o.beam_arcs = PackedFloat32Array()
	var bearings := PackedFloat32Array()
	var slot := _seat_of(order, g, &"beam_range")
	if int(shape[0]) > 0 and slot >= 0:
		var half := deg_to_rad(float(shape[1]))
		var fan := RayFan.new()
		fan.configure(int(shape[0]), half, 0.0)
		fan.step(0.0)
		var middle := Cilia.slot_bearing(slot)
		var offsets := fan.offsets()
		for k in offsets.size():
			bearings.append(wrapf(middle + offsets[k], -PI, PI))
		o.beam_fan_mid = middle
		o.beam_fan_half = half
	else:
		o.beam_fan_half = -1.0
	o.beam_bearings = bearings
	return o


## Where the organ that provides [param stat] is worn in [param order], as a
## bearing: dead ahead for a body that wears none, as `Cilia.bearing_of` answers
## the run.
static func _arc_in(order: Array, tiers: Dictionary, stat: StringName) -> float:
	var slot := _seat_of(order, tiers, stat)
	return Cilia.slot_bearing(slot) if slot >= 0 else 0.0


## **The slot of [param order] the organ that provides [param stat] is worn in**,
## of those [param tiers] wears; -1 for none. One instance per mechanic
## (gene-catalogue.md §5.2): the one it acts from, the first in slot order for a
## mechanic with a place (stats.gd's `organ`).
static func _seat_of(order: Array, tiers: Dictionary, stat: StringName) -> int:
	var organ := Stats.organ(order, tiers, stat)
	return order.find(organ) if organ != &"" else -1


## **Body [param b] in slot [param i], as an observer**: its organs and its
## mouth from its eye, at its place and heading now.
func _body_eye(i: int, b: Body) -> Observer:
	var o := b.eye
	o.face(b.pos, b.heading)
	o.slot = i
	return o


## **The bodies an organ of body [param b] reaching [param reach] can find**,
## asked of the grid round it -- and the player on this device and the people
## in a pond, who are never in the grid, while they are in the water. Every
## sense filters this to exactly what its organ reaches.
func _scan_for(b: Body, reach: float) -> PackedInt32Array:
	_organ_ids.resize(0)
	_drop.grid.query(b.pos, reach + Drop.GRID_SLACK, _organ_ids)
	if _me.seeded:
		_organ_ids.append(TARGET_PLAYER)
	if _pond:
		for k in _guests:
			if _cells[PERSON_SLOT + k].seeded:
				_organ_ids.append(PERSON_SLOT + k)
	return _organ_ids


## **The player on this device, as the water finds it** ([member _me]): made
## again before the water senses -- where it is, how big, and whether it is in
## the water at all.
func _refresh_me() -> void:
	_me.seeded = in_water and anchored and _cell != null
	if not _me.seeded:
		return
	_me.pos = _cell.position
	_me.heading = _cell.heading
	_me.radius = _cell.radius
	_me.inert = false
	_me.settle = 1.0
	_me.drifter = false


# --- The inputs (§3.2): one function each, from the senses as they are ------------
#
# **Each reader is the sensing it does for a water body and a report**
# (automation.md §4.1): the reader senses from where the body is, and the report
# -- a static `report_*` below it, shared -- formats what the sense found. The
# player's instincts get the same reports of what their membrane's frame already
# sensed (game/normal/own_rules.gd), so the report an instinct reads is one
# function for both bodies, and drop_probe's check 9 holds the two equal.

## `metabolism.hunger`: its tank, a level, always.
func _read_hunger(_i: int, b: Body) -> Array:
	return report_hunger(b.hunger)


## The report of a tank at [param level]: always one.
static func report_hunger(level: float) -> Array:
	return [[level]]


## `metabolism.fed`: seconds since it last ate, always -- INF for a body that
## never has.
func _read_fed(_i: int, b: Body) -> Array:
	return report_fed(_t - b.ate_at)


## The report of [param seconds] since a meal: always one, INF for none yet.
static func report_fed(seconds: float) -> Array:
	return [[seconds]]


## `body.hit`: a bite or a dart that landed on it since its last tick, at its
## bearing now and how hard.
func _read_hit(_i: int, b: Body) -> Array:
	return report_hit(b.hit, b.hit_from, b.heading)


## The report of a hit [param hit] hard from the world direction [param from],
## felt by a body facing [param heading] now: nothing for no hit.
static func report_hit(hit: float, from: float, heading: float) -> Array:
	if hit <= 0.0:
		return []
	return [[angle_difference(heading, from), hit, from]]


## `chemocyte.smell`: the level its nose reads, always while it wears one --
## the player's own nose, run from where this body is (§12.1).
func _read_smell(i: int, b: Body) -> Array:
	var o := _body_eye(i, b)
	if o.smell_range <= 0.0:
		return []
	_feel(o, _scan_for(b, o.smell_range), true, false, false)
	return report_smell(o)


## The report of what [param o]'s nose read: its level, while it has a nose.
static func report_smell(o: Observer) -> Array:
	if o.smell_range <= 0.0:
		return []
	return [[o.smell]]


## `stigma.shadow`: the light blocked by bodies about its size or bigger and by
## the rim, summed with a bearing, while any is.
func _read_shadow(i: int, b: Body) -> Array:
	var o := _body_eye(i, b)
	if not o.eyespot:
		return []
	_feel(o, _scan_for(b, SHADOW_RANGE), false, true, false)
	return report_shadow(o)


## The report of the shade on [param o]'s eyespot: its bearing, how dark, and
## that bearing in the world, while there is any and it wears an eyespot.
static func report_shadow(o: Observer) -> Array:
	if not o.eyespot:
		return []
	var level := minf(o.shade, 1.0)
	if level <= 0.0 or o.shade_pull.length_squared() <= 0.0:
		return []
	var bearing := o.bearing_to(o.pos + o.shade_pull)
	return [[bearing, level, wrapf(o.heading + bearing, -PI, PI)]]


## `palp.touch`: the nearest thing within its reach of its skin, the rim
## included, as a bearing and a closeness.
func _read_touch(i: int, b: Body) -> Array:
	var o := _body_eye(i, b)
	if o.touch_range <= 0.0:
		return []
	_touch_of(o, _scan_for(b, o.touch_range + o.radius + _widest_now))
	return report_touch(o)


## The report of what [param o]'s palps touched: its bearing, how close, and
## that bearing in the world, while it has palps and touched anything.
static func report_touch(o: Observer) -> Array:
	if o.touch_range <= 0.0 or not o.touched:
		return []
	return [[o.touch_bearing, o.touch, wrapf(o.heading + o.touch_bearing, -PI, PI)]]


## `ocellus.beam`: each ray that stops on something -- a cell, a floc, you or the
## rim -- as its bearing and how far, nearest first. What it hit is not reported.
func _read_beam(i: int, b: Body) -> Array:
	var o := _body_eye(i, b)
	if o.beam_range <= 0.0:
		return []
	_rays.clear()
	_beams_of(o, _scan_for(b, o.beam_range + _widest_now), _rays, false)
	return report_beam(_rays, o.heading)


## The report of [param rays], cast as `[bearing, distance, hit, body]` by a body
## facing [param heading]: every ray that stopped on something, as its bearing,
## how far and that bearing in the world, nearest first.
static func report_beam(rays: Array, heading: float) -> Array:
	var out: Array = []
	for ray: Array in rays:
		if bool(ray[2]):
			out.append([float(ray[0]), float(ray[1]),
				wrapf(heading + float(ray[0]), -PI, PI)])
	if out.size() > 1:
		out.sort_custom(func(x: Array, y: Array) -> bool: return x[1] < y[1])
	return out


## `ampulla.echo`: each return of its own call while it rings -- its bearing to
## where the body it came off was, its distance from when it came back, and its
## size from how long it rings -- nearest first. A return that has rung out is
## let go.
func _read_echo(i: int, b: Body) -> Array:
	if b.echoes.is_empty():
		return []
	return report_echo(b.echoes, _body_eye(i, b), _t)


## The report of the returns of a call, kept as `[lands, at, distance, size,
## rings until]` in [param echoes], heard by [param o] at [param now]: each that
## has landed and rings still, as its bearing, distance, size and that bearing in
## the world, nearest first. **A return that has rung out is let go** from
## [param echoes] as it is read.
static func report_echo(echoes: Array, o: Observer, now: float) -> Array:
	var out: Array = []
	for k in range(echoes.size() - 1, -1, -1):
		var echo: Array = echoes[k]
		if float(echo[4]) <= now:
			echoes.remove_at(k)
		elif float(echo[0]) <= now:
			var bearing := o.bearing_to(echo[1])
			out.append([bearing, float(echo[2]), float(echo[3]),
				wrapf(o.heading + bearing, -PI, PI)])
	if out.size() > 1:
		out.sort_custom(func(x: Array, y: Array) -> bool: return x[1] < y[1])
	return out


## **Its own call goes out** when its clock says (§3.2): once a round trip, by
## the player's own arithmetic ([method _call_of]), from where it is now. Each
## return is kept as the place it came off, the distance its time home says
## and the size its ring says, to be read from when it lands until it rings out.
func _call_now(i: int, b: Body) -> void:
	if b.eye == null or b.eye.ping_range <= 0.0 or _t < b.call_at:
		return
	b.call_at = _t + b.eye.ping_period
	for k in range(b.echoes.size() - 1, -1, -1):
		if float((b.echoes[k] as Array)[4]) <= _t:
			b.echoes.remove_at(k)
	var o := _body_eye(i, b)
	_returns.clear()
	_call_of(o, _scan_for(b, o.ping_range + _widest_now), _returns)
	for one: Array in _returns:
		var due := float(one[0])
		var hold := float(one[4])
		b.echoes.append([_t + due, one[1], due * PING_SPEED * 0.5,
			hold * PING_SPEED / (2.0 * PING_RING), _t + due + hold])


# --- The outputs (§3.3): the triggers a body has --------------------------------

## `body.turn-toward`: the heading it steers for becomes the report's bearing --
## led, when the input also reported last tick, by three times how far that
## bearing drifted since: constant-bearing pursuit (§4.2).
func _turn_toward(_i: int, b: Body, _k: int, report: Array, before: Variant, _tick: int) -> void:
	var toward := float(report[report.size() - 1])
	var lead := 0.0
	if before != null:
		var nearest := INF
		for was: Array in before:
			var drift := angle_difference(float(was[was.size() - 1]), toward)
			if absf(drift) < absf(nearest):
				nearest = drift
		if absf(nearest) <= LEAD_JUMP:
			lead = LEAD * nearest
	b.steer = wrapf(toward + lead, -PI, PI)
	b.holding = true


## `body.turn-away`: the opposite heading.
func _turn_away(_i: int, b: Body, _k: int, report: Array, _before: Variant, _tick: int) -> void:
	b.steer = wrapf(float(report[report.size() - 1]) + PI, -PI, PI)
	b.holding = true


## `body.turn-random`: a heading 90 to 180 degrees to a random side, drawn when
## the rule starts firing, from the stream `--seed=` seeds, and kept while it
## keeps firing (§4.2).
func _turn_random(_i: int, b: Body, k: int, _report: Array, _before: Variant, tick: int) -> void:
	if not (b.tumble == k and b.tumble_tick == tick - 1 and b.holding):
		var side := 1.0 if randf() < 0.5 else -1.0
		b.steer = wrapf(b.heading + side * randf_range(PI * 0.5, PI), -PI, PI)
	b.tumble = k
	b.tumble_tick = tick
	b.holding = true


## `body.swim`: it beats its flagellum at its tail's speed, paying for it. Under
## [member tails_beat] the tail beats anyway: a swim claims it, so no rule below
## may hold it (automation.md §5.3).
func _swim_on(_i: int, b: Body, _k: int, _report: Array, _before: Variant, _tick: int) -> void:
	b.swimming = true


## `body.rest`: steering, the push and the dash stop, and the heading it held is
## let go -- and **at its tail's hold level ([method CellBody.hold_level]) its tail
## is held still too**
## (automation.md §5.3), so it is carried, for free. Under a level-1 tail it
## swims on, under [member tails_beat]; pack 3's water carries every resting body.
func _rest_on(_i: int, b: Body, _k: int, _report: Array, _before: Variant, _tick: int) -> void:
	b.resting = true
	b.holding = false
	b.tail_held = tails_beat and b.tail_level >= b.stat_hold


## `flagellum.hold`, declared at the tail's hold level: its tail is held
## still, and only its tail -- a rule below may still steer, push and dash
## (automation.md §4.2).
func _hold_on(_i: int, b: Body, _k: int, _report: Array, _before: Variant, _tick: int) -> void:
	b.tail_held = true


## `myoneme.dash`: a burst forward, on its cooldown and at its price.
func _dash_on(_i: int, b: Body, _k: int, _report: Array, _before: Variant, _tick: int) -> void:
	_dash(b)


## `axoneme.push`: its axoneme's thrust at the rule's strength while it holds.
func _push_on(_i: int, b: Body, k: int, _report: Array, _before: Variant, _tick: int) -> void:
	var list: Rulebook.Behaviour = b.brain if b.brain != null else founders()
	b.push = list.rules[k].option


# --- A body on rules, stepped (§4) ----------------------------------------------------

## **A body on rules** (§4): on its tick its rules are read -- unless it is
## stunned -- and between ticks it does what they claimed; then what defends it
## defends it, its own call goes out when it is due, and a player it is coming
## for feels it. A body with no mouth decides nothing and drifts, as today's.
func _step_ruled(index: int, b: Body, delta: float) -> void:
	if b.stun > 0.0:
		b.stun = maxf(b.stun - delta, 0.0)
	if b.look and not b.drifter:
		_decide_by_rules(index, b)
	_move_ruled(b, delta)
	# Each asked only of a body it can concern, here rather than inside: these
	# run on every step of every body.
	if b.dart_tier > 0 and b.dart_clock <= 0.0 and not b.inert:
		_darts_of(index, b)
	if b.drifter:
		return
	if b.eye != null and b.eye.ping_range > 0.0 and _t >= b.call_at:
		_call_now(index, b)
	if _under_power(b):
		_felt_coming(b, delta)


## **One tick of its rules** (§4.1): read from the top, one winner for each
## trigger, by rulebook.gd -- each input read at most once and only for an organ
## it wears -- and each winner performed. A trigger nothing claimed does what a
## body does on its own: no new heading, no push, and its tail beats under
## [member tails_beat] -- in pack 3's water, no swim. A hit is felt on the
## tick it is read, acted on or not. **A stunned body reads nothing**, and keeps
## what hit it for the tick it reads again: the dart that stunned it is felt
## then, at its bearing.
func _decide_by_rules(index: int, b: Body) -> void:
	if b.stun > 0.0:
		return
	if _readers.is_empty():
		_wire()
	var list: Rulebook.Behaviour = b.brain if b.brain != null else _founders
	var tick := _frame / Drop.LOD_EVERY
	_reading = b
	_reading_slot = index
	_sizes[&"mouth"] = b.eye.gape
	_sizes[&"body"] = b.radius
	# What it wears is its genome; what every body has, it has ([member Body.worn]).
	# A gene its DNA carries and its body does not wear is not there: its inputs
	# never report and its outputs never fire (§3.5, §12.3 check 3).
	Rulebook.choose(list, _read_with, b.worn, _sizes, b.memory, tick, _fired)
	b.resting = false
	b.swimming = false
	b.push = 0.0
	b.tail_held = false
	for won: Array in _fired:
		var k := int(won[0])
		var act: Callable = _triggers.get(list.rules[k].output, Callable())
		if act.is_valid():
			act.call(index, b, k, won[1], won[2], tick)
		if b.brain == null and k < FIRED.size():
			_stat(FIRED[k])
	b.hit = 0.0
	_reading = null


## **How a body on rules moves** (§4.2, §4.5): toward the heading it holds at
## its own cirrus's rate, paying TURN_COST a radian, the water's wander on top --
## or, holding none, on the water's heading: the free wander and the turn off
## the shore. At its tail's speed while its tail beats ([method _tail_beats])
## and with its axoneme's thrust while it pushes, each paid at the player's
## prices, a dash's burst fading with the drag; its tail still and pushing
## nothing, carried at DRIFT_SPEED for free. A swimming body slides along the
## rim. **Under row 37** (automation.md §5.3) a resting body with a level-1 tail
## swims on: its rest stops its steering, its push and its dash, not its tail.
func _move_ruled(b: Body, delta: float) -> void:
	var still := b.resting or b.stun > 0.0
	if b.holding and not still:
		var rate := b.turn_rate
		var turn := clampf(angle_difference(b.heading, b.steer), -rate * delta, rate * delta)
		b.wander = lerpf(b.wander, randf_range(-WANDER_RATE, WANDER_RATE),
			1.0 - exp(-delta / WANDER_TAU))
		b.heading = wrapf(b.heading + turn + b.wander * delta, -PI, PI)
		b.effort += absf(turn) * CellBody.TURN_COST
	else:
		b.heading = wrapf(b.heading + randf_range(-DRIFT_TURN, DRIFT_TURN) * delta, -PI, PI)
		_shore_turn(b, delta)
	var pace := DRIFT_SPEED
	if _tail_beats(b):
		pace = b.tail
		b.effort += CellBody.stroke_cost(b.tail) * delta
	if not still and b.push > 0.0:
		var thrust := b.thrust * b.push
		pace += thrust / CellBody.DRAG
		b.effort += thrust * CellBody.STROKE_COST * delta
	if b.dash_v > 0.0:
		pace += b.dash_v
		b.dash_v *= exp(-CellBody.DRAG * delta)
		if b.dash_v < 1.0:
			b.dash_v = 0.0
	b.pos += _forward(b.heading) * pace * delta
	b.speed = pace


## **Whether [param b]'s tail beats this step** (automation.md §5.3). Under
## [member tails_beat], for every body that swims unless it is held -- by the
## flagellum's `hold`, or a rest at [method CellBody.hold_level] -- or a dart
## has stunned it: a stun is done to a body, not an ability it has. A drifter
## has no mouth, decides nothing and is carried, as pack 1's row 11 keeps it.
## In pack 3's water only while a swim rule fires and it neither rests nor is
## stunned.
func _tail_beats(b: Body) -> bool:
	if b.stun > 0.0:
		return false
	if not tails_beat:
		return b.swimming and not b.resting
	return not b.drifter and not b.tail_held


## **Whether [param b] moves under its own power** -- what "coming for you"
## asks first (§4.3): its tail beating, a push, or a dash's burst while it does
## not rest. So under row 37 a resting one-copy hunter swimming at you is coming
## for you, and a two-copy hunter holding still is not (automation.md §5.3).
func _under_power(b: Body) -> bool:
	if b.stun > 0.0:
		return false
	return _tail_beats(b) or (not b.resting and (b.push > 0.0 or b.dash_v > 0.0))


# --- Coming for you (§4.3) -------------------------------------------------------------

## **Whether [param a] is coming for a body at [param at]** (behaviour.md §4.3):
## it is swimming, has that body within [constant COMING_CONE_DEG] of its
## heading, and has a mouth that could swallow it -- [param size] being that
## body as a mouth measures it -- or chew it, opened up past CHEW_INVITE
## ([param wound]): today's test for starting a run. What a membrane and an
## organ read the water by -- the wake, a dart, full vision's rings, the
## replay's hunter and the pond's flag -- and never an input to a rule (§14).
func _coming_for(a: Body, at: Vector2, size: float, wound: float) -> bool:
	if not _under_power(a):
		return false
	var to := at - a.pos
	var d2 := to.length_squared()
	if d2 <= 0.0 or _forward(a.heading).dot(to) < COMING_COS * sqrt(d2):
		return false
	return _worth_committing_to(a, _gape(a), size, wound)


## **Whether [param a] is coming for player [param p]** -- null the cell on this
## device -- who has to be in the water. **Their grace is not asked**: no sense
## reports one, so a rule may turn a cell onto a player in it, and the wake and
## the dart that warn of it and answer it are what the player is left with.
func _coming_for_player(a: Body, p: Person) -> bool:
	if p == null:
		return in_water \
			and _coming_for(a, _cell.position, _cell.swallow_radius(), _cell.wound)
	var pb := _cells[p.slot]
	return pb.seeded and _coming_for(a, pb.pos, pb.radius * p.armour, pb.wound)


## **The nearest cell coming for the player on this device**, among the bodies
## the frame gathered round it; -1 for none. [method hunter], on rules.
func _nearest_coming() -> int:
	if not in_water:
		return -1
	var best := -1
	var best_d := INF
	var size := _cell.swallow_radius()
	for i: int in _near:
		var b := _cells[i]
		if not b.seeded or b.inert or b.drifter or b.person != null or not _under_power(b):
			continue
		var d := b.pos.distance_to(_cell.position)
		if d < best_d and _coming_for(b, _cell.position, size, _cell.wound):
			best_d = d
			best = i
	return best


## **What a cell coming for a player does to them** (§4.3): their dart, if it
## is ready and looks its way, stuns it; otherwise its strokes are their wake,
## at its true bearing -- the run's own `_felt_hunting`, with "on a run at you"
## read as "coming for you". The nearest player within the wake's reach it is
## coming for: the strokes are one flagellum's, counted once.
func _felt_coming(b: Body, delta: float) -> void:
	if not _under_power(b):
		return
	var found := false
	var to: Person = null
	var d := WAKE_RANGE
	if in_water:
		var mine := b.pos.distance_to(_cell.position)
		if mine < d and _coming_for(b, _cell.position, _cell.swallow_radius(), _cell.wound):
			d = mine
			found = true
	if _pond:
		for k in _guests:
			var pb := _cells[PERSON_SLOT + k]
			var p := pb.person
			if p == null or not pb.seeded:
				continue
			var theirs := b.pos.distance_to(pb.pos)
			if theirs < d and _coming_for(b, pb.pos, pb.radius * p.armour, pb.wound):
				d = theirs
				to = p
				found = true
	if not found:
		return
	var reach := dart_range if to == null else to.dart_range
	var clock := _dart_clock if to == null else to.dart_clock
	if reach > 0.0 and d < reach and clock <= 0.0:
		var facing := dart_bearing if to == null else to.dart_bearing
		if absf(angle_difference(facing, _bearing_for(to, b.pos))) \
				<= deg_to_rad(CellBody.DART_ARC_DEG) * 0.5:
			if to == null:
				_dart_clock = dart_cooldown
			else:
				to.dart_clock = to.dart_cooldown
			_tell(to, Contact.DARTED, b.pos, 0.0, By.WATER, &"")
			_stun(b, _cell.position if to == null else _cells[to.slot].pos,
				CellBody.dart_stun(_cell.worn(), _cell.seats()) if to == null
					else CellBody.dart_stun(_cells[to.slot].genome, _cells[to.slot].seats()))
			return
	b.stroke -= delta
	if b.stroke > 0.0:
		return
	var committed := d < LUNGE_RANGE
	b.stroke = STROKE_GAP * (0.5 if committed else 1.0) \
		+ randf_range(-STROKE_JITTER, STROKE_JITTER) * (0.5 if committed else 1.0)
	_stat(&"wakes")
	_tell(to, Contact.WAKED, b.pos, 1.0 if committed else smoothstep(WAKE_RANGE, WAKE_CORE, d),
		By.WATER, &"")


## **`trichocyst` defends every body** (§4.3): its dart goes off on its own at
## the nearest cell coming for it -- inside its range and on the arc it is worn
## on, once a cooldown -- and stuns it. Never at a player, as today: a player's
## dart is the player's own ([method _felt_coming]).
##
## Asked by [method _step_ruled] only of a body that wears one, whose dart is
## ready and which is no floc.
func _darts_of(index: int, b: Body) -> void:
	var reach := b.stat_dart_range
	_dart_ids.resize(0)
	_drop.grid.query(b.pos, reach + Drop.GRID_SLACK, _dart_ids)
	var size := _swallow_r(b)
	var best := -1
	var best_d := reach
	for j: int in _dart_ids:
		if j == index:
			continue
		var a := _cells[j]
		if not a.seeded or a.inert or a.drifter or a.person != null:
			continue
		var d := a.pos.distance_to(b.pos)
		if d >= best_d or not _coming_for(a, b.pos, size, b.wound):
			continue
		if absf(angle_difference(b.heading + b.dart_bearing, _angle_of(a.pos - b.pos,
				b.heading))) > deg_to_rad(CellBody.DART_ARC_DEG) * 0.5:
			continue
		best = j
		best_d = d
	if best < 0:
		return
	b.dart_clock = b.stat_dart_cooldown
	_stun(_cells[best], b.pos, b.stat_dart_stun)
	_stat(&"water_darts")


## **A dart stuns what it hits** (§4.3): it rests for [param seconds] -- the
## dart's own stun ([method CellBody.dart_stun]) -- with its rules unread -- no
## heading held, no stroke, no push -- and feels the dart as a `hit` at its
## bearing, on the first tick it reads its rules again.
func _stun(b: Body, from: Vector2, seconds: float) -> void:
	b.stun = maxf(b.stun, seconds)
	b.holding = false
	b.swimming = false
	b.push = 0.0
	b.resting = true
	# Resting until its next tick reads its rules again, as `_rest_on` rests it:
	# with a level-2 tail, held. The stun itself stops every tail, whatever its
	# level ([method _tail_beats]).
	b.tail_held = tails_beat and b.tail_level >= b.stat_hold
	_feel_hit(b, from, 1.0)
	_stat(&"stuns")


## **A hit lands on body [param b]**, from [param from]: a bite on its membrane
## or a dart, [param level] 0..1 hard. Felt on its next tick (§3.2): the
## hardest since its last, from where that one came.
func _feel_hit(b: Body, from: Vector2, level: float) -> void:
	if level < b.hit:
		return
	b.hit = level
	b.hit_from = _angle_of(from - b.pos, b.heading)


# --- Mouths (§5.6) --------------------------------------------------------------------------

## **A water mouth on another body, in the drop**: the one mouth rule every body
## obeys. A settled floc that fits is food and nothing else; a body too big for
## the mouth -- its `pellicle` counted -- is chewed, and fed on once it comes
## apart; one that fits is swallowed. **The toxins are every cell's alike**
## (docs/design/dna-slots.md §7): a bite carries its venom in and takes the
## bitten's poison -- and its sting, on that side -- back, and a swallowed
## poisonous cell is eaten and doses what ate it.
## Returns true when this mouth is finished for the frame.
func _mouth_on_drop(i: int, b: Body, j: int, other: Body, gape: float) -> bool:
	if other.inert:
		if other.settle < 1.0 or other.radius >= gape:
			return false
		_feed_water(b, _meal_value_for(other.radius, b.radius))
		_stat(&"water_grazed")
		_consume(j)
		_rest(b, REST_MEAL)
		return true
	if _swallow_r(other) >= gape:
		var through := _chew(i, b, j, other) >= 1.0
		if through:
			_feed_water(b, _meal_value_for(other.radius, b.radius))
			_devour(b, other)
			_stat(&"water_chewed")
			_consume(j, Cause.CHEWED)
			_rest(b, REST_MEAL)
			return true
		return false
	_swallow_doses(i, j, 0.0)
	_feed_water(b, _meal_value_for(other.radius, b.radius))
	_devour(b, other)
	_stat(&"water_ate_drifter" if other.drifter else &"water_ate_hunter")
	_consume(j, Cause.SWALLOWED)
	_rest(b, REST_MEAL)
	return true


## **A body leaves the drop**, and [param cause] says how: a [enum Cause] for a
## living one -- and only those four (§5.6) -- or 0 for a floc eaten or
## dissolved. One that starved or was poisoned leaves its remains where it
## died, made before its slot is let go.
func _drop_lose(index: int, cause: int) -> void:
	var b := _cells[index]
	if not b.seeded:
		return
	if b.inert:
		_flocs -= 1
	else:
		_living -= 1
		if b.drifter:
			_drifters -= 1
		match cause:
			Cause.SWALLOWED:
				_stat(&"died_swallowed")
			Cause.CHEWED:
				_stat(&"died_chewed")
			Cause.STARVED:
				_stat(&"died_starved")
				if b.radius >= CellBody.DIVIDE_RADIUS - 0.01:
					_stat(&"died_starved_r40")
			Cause.POISONED:
				_stat(&"died_poisoned")
			_:
				_stat(&"removed")
		if cause == Cause.STARVED or cause == Cause.POISONED:
			_spawn_floc(b.pos, Drop.remains_radius(b.radius), true)
			_stat(&"remains")
	_retire(index)
	b.inert = false
	b.searching = false
	b.orienting = false
	b.dash_v = 0.0
	_drop.grid.remove(index)
	_free.append(index)


## **The mouths stepped this frame, on whatever they touch**, each asking the
## grid for its own reach. A far mouth closes on its tick, as it decides then.
func _contacts_drop() -> void:
	for i: int in _stepped:
		var b := _cells[i]
		if not b.seeded or b.drifter:
			continue
		var gape := _gape(b)
		var reach := Cilia.mouth_reach(b.radius, gape) + gape * Cilia.MOUTH_BITE \
			+ _widest_now
		var bound := _pair_bound(reach)
		_pair_ids.resize(0)
		_drop.grid.query(b.pos, reach + Drop.GRID_SLACK, _pair_ids)
		for j: int in _pair_ids:
			if j == i:
				continue
			var other := _cells[j]
			if not other.seeded or (other.inert and other.settle < 1.0):
				continue
			if b.pos.distance_squared_to(other.pos) > bound:
				continue
			if not _mouth_reaches(b, gape, other.pos, other.radius):
				continue
			if _mouth_on(i, b, j, other, gape) or not b.seeded:
				break


## **Bodies are solid** (today's rule): the player against the bodies near it,
## and every body stepped this frame against its neighbours, each pair of two
## stepped bodies once. A floc is not solid -- a cell swims over it (§7.5).
func _separate_drop() -> void:
	var m := _drop.meniscus
	if in_water:
		for i: int in _near:
			var b := _cells[i]
			if b.seeded and not b.inert:
				_push_local(b, true)
				# A body the cell shoulders at the rim is held there too.
				b.pos = m.contain(b.pos, b.radius)
		# **Each device moves only what it owns** (shared-pond.md §1.2): the
		# other player gives way on their own device, by the same area share.
		if _pond:
			for k in _guests:
				if _cells[PERSON_SLOT + k].seeded:
					_push_local(_cells[PERSON_SLOT + k], false)
	if _pond:
		for k in _guests:
			_push_person_drop(k)
	for i: int in _stepped:
		var b := _cells[i]
		if not b.seeded or b.inert:
			continue
		var reach := b.radius + _widest_now
		var bound := _pair_bound(reach)
		_pair_ids.resize(0)
		_drop.grid.query(b.pos, reach + Drop.GRID_SLACK, _pair_ids)
		for j: int in _pair_ids:
			if j == i:
				continue
			var other := _cells[j]
			if not other.seeded or other.inert or (other.stepped == _frame and j < i):
				continue
			if b.pos.distance_squared_to(other.pos) > bound:
				continue
			var offset := b.pos - other.pos
			var d := offset.length()
			var overlap := b.radius + other.radius - d
			if overlap <= 0.0:
				continue
			var normal := offset / d if d > 0.001 else _forward(b.heading)
			var share := _give_way(other.radius, b.radius)
			b.pos = m.contain(b.pos + normal * (overlap * share * PUSH_SHARE), b.radius)
			other.pos = m.contain(other.pos - normal * (overlap * (1.0 - share) * PUSH_SHARE),
				other.radius)


## **The player is held and knocked** (§3.1): a centre past the rim is put
## back, the speed into it reflected at SHORE_RESTITUTION, and -- when
## [param knock], and it was going fast enough -- felt as a `hit` at the rim's
## bearing, as grit is, at most once in SHORE_GAP. Pressing on keeps knocking.
func _contain_player(knock: bool) -> void:
	var m := _drop.meniscus
	if m.inside(_cell.position, _cell.radius):
		return
	var out := (_cell.position - m.center).normalized()
	var into := _cell.velocity.dot(out)
	_cell.position = m.contain(_cell.position, _cell.radius)
	if not knock:
		return
	_cell.bump(-out, Drop.SHORE_RESTITUTION)
	_cell.position = m.contain(_cell.position, _cell.radius)
	_stat(&"shore_frames")
	if into > Drop.SHORE_FELT_SPEED and _shore_clock <= 0.0:
		_shore_clock = Drop.SHORE_GAP
		var rim := m.nearest_rim(_cell.position)
		_stat(&"shored")
		shored.emit(_cell.bearing_to(rim),
			clampf(sqrt(into / maxf(_cell.impulse_speed(), 1.0)), 0.35, 1.0), rim)


## **The authored first drifter**, put FIRST_DISTANCE along the cell's first
## motion -- or toward the middle, if that is at the rim.
func _place_first() -> void:
	if _first_index < 0 or _first_index >= _cells.size():
		return
	var b := _cells[_first_index]
	if not b.seeded or b.serial != _first_serial:
		return
	var at := _cell.position + _cell.velocity.normalized() * FIRST_DISTANCE
	if not _drop.meniscus.inside(at, FIRST_INSET):
		at = _cell.position + (_drop.meniscus.center - _cell.position).normalized() \
			* FIRST_DISTANCE
	b.pos = at
	b.aim = at
	b.flee_from = at
	_drop.grid.move(_first_index, at)


# --- Flocs (§7) --------------------------------------------------------------------------

## **A floc lives out its time**: settles into focus over FLOC_SETTLE, lasts its
## life, and dissolves over the same five seconds in reverse. Settled, a
## drifter's mouth may close on it -- a mouth with no `cytostome` is still a
## mouth (§5.3) -- asked from the floc's side, which is the rarer.
func _age_floc(i: int, b: Body, dt: float) -> void:
	b.age += dt
	if b.life > 0.0:
		b.life -= dt
		if b.settle < 1.0:
			b.settle = minf(b.settle + dt / Drop.FLOC_SETTLE, 1.0)
			return
		_grazed_by_drifter(i, b)
		return
	b.settle -= dt / Drop.FLOC_SETTLE
	if b.settle <= 0.0:
		_stat(&"flocs_dissolved")
		_consume(i)


## **[method _age_floc]'s fade, as a function of time** (ocean.md §11): how far
## a floc that had settled [param settle] of the way with [param life] seconds
## left has settled [param seconds] later -- into focus while it has life left,
## out again after. What a replay draws a floc by, since it records a floc once.
static func floc_settle_after(settle: float, life: float, seconds: float) -> float:
	var left := maxf(life, 0.0)
	if seconds < left:
		return minf(settle + seconds / Drop.FLOC_SETTLE, 1.0)
	var top := minf(settle + left / Drop.FLOC_SETTLE, 1.0)
	return maxf(top - (seconds - left) / Drop.FLOC_SETTLE, 0.0)


## **The widest mouth a drifter has**: the gape of a body with none, at the
## largest a drifter grows -- a number of the genes', read once, not each step of
## each floc.
static var _drifter_mouth := CellBody.gape_of({}, DRIFTER_MAX)


func _grazed_by_drifter(i: int, b: Body) -> void:
	var mouth := _drifter_mouth
	var reach := b.radius + Cilia.mouth_reach(DRIFTER_MAX, mouth) + mouth * Cilia.MOUTH_BITE
	_graze_ids.resize(0)
	_drop.grid.query(b.pos, reach + Drop.GRID_SLACK, _graze_ids)
	for j: int in _graze_ids:
		var o := _cells[j]
		if not o.seeded or not o.drifter or o.inert:
			continue
		var gape := _gape(o)
		if b.radius >= gape or not _mouth_reaches(o, gape, b.pos, b.radius):
			continue
		_feed_water(o, _meal_value_for(b.radius, o.radius))
		_stat(&"drifter_grazed")
		_consume(i)
		return


## **Remains** (§7.4): the floc a player that starved or was poisoned leaves
## where it died, as every body does. The drop outlives the cell.
func leave_remains(at: Vector2, body_radius: float) -> void:
	if _drop == null or _mirror or _replay:
		return
	_spawn_floc(at, Drop.remains_radius(body_radius), true)
	_stat(&"remains")


# --- What the water makes (§6) --------------------------------------------------------------

## Twice a second: the spawner, the gene floor, the drifter floor and the snow.
func _ecology(dt: float) -> void:
	# **Every player, and what the water is made for** (§10.2, §10.3): this cell
	# while it has a body, and each person in a pond -- where each is, which way
	# it faces, how far its senses reach, and its radius and sight for a body
	# made for it. With nobody in, the players it was last made for.
	var players := PackedVector2Array()
	var facing := PackedFloat32Array()
	var reaches := PackedFloat32Array()
	var wet: Array[bool] = []
	var tunes := PackedFloat64Array()
	if anchored:
		players.append(_cell.position)
		facing.append(_cell.heading)
		reaches.append(maxf(maxf(smell_range, ping_range), beam_range))
		wet.append(in_water)
		tunes.append_array([_cell.radius, _sensed()])
	if _pond and not _mirror:
		for k in _guests:
			var pb := _cells[PERSON_SLOT + k]
			if pb.person == null:
				continue
			players.append(pb.pos)
			facing.append(pb.heading)
			reaches.append(_person_senses(pb))
			wet.append(pb.seeded)
			tunes.append_array([pb.radius, _anchor_sensed(Anchor.PERSON + k)])
	if not tunes.is_empty():
		_made_for = tunes
	elif _made_for.size() < 2:
		_made_for = PackedFloat64Array([CellBody.BASE_RADIUS, 0.0])
	# **The shortfall, paid back over SPAWN_TAU** (§6.2), one body at a time,
	# each at the thinnest of its candidate places (§6.3), made for the players
	# in turn. **Since bodies divide, each kind's own** (lineage.md §5): the food
	# against its count over SPAWN_TAU, the hunters against today's count within
	# [member floor_tau], and the toxin whenever it is short -- summed into the one
	# debt, and each body made the kind that is short ([method _make_one]). A
	# unit owed when nothing is short any more is not a body: births made it.
	var due := _drop.spawner.due_for(_shortfall(), dt) if births \
		else _drop.spawner.due(_living, dt)
	for k in due:
		var made := _make_one(players, reaches)
		if made == NOTHING_SHORT:
			_stat(&"spawn_left_to_births")
			continue
		if made < 0:
			_drop.spawner.refund(due - k)
			_stat(&"spawn_no_room")
			break
	_gene_clock += dt
	if _gene_clock >= Drop.GENE_FLOOR_EVERY:
		_gene_clock = 0.0
		_count_genes()
	# **The drifter floor** (§6.4): no living drifter within the hide reach and
	# DRIFTER_FLOOR_SLACK more of a player, and one is made just past its
	# horizon, ahead of it -- per player (§10.2), one a tick. With the ring it
	# has nothing to do; it stays as the invariant it always was.
	_floor_clock = maxf(_floor_clock - dt, 0.0)
	if _floor_clock <= 0.0:
		for k in players.size():
			var hide := Drop.hide_reach(reaches[k], DREAD_RANGE, true)
			if _count_drifters_at(players[k], hide + Drop.DRIFTER_FLOOR_SLACK) != 0:
				continue
			_floor_clock = Drop.DRIFTER_FLOOR_GAP
			if _spawn_ahead(players[k], facing[k], hide + randf_range(
					Drop.DRIFTER_FLOOR_NEAR, Drop.DRIFTER_FLOOR_FAR), tunes[2 * k + 1]) >= 0:
				_stat(&"drifter_floor")
			break
	# **The snow** (§7.2): flakes fall everywhere at one rate, and each stays
	# with a chance that falls as the living round it -- the players among them
	# -- rise toward the drop's share.
	var area := PI * _drop.meniscus.radius * _drop.meniscus.radius
	var expected := Drop.snow_expected()
	var scan2 := Drop.SNOW_SCAN * Drop.SNOW_SCAN
	for k in _drop.snow.falls(area, dt):
		var at := _drop.uniform_point(Drop.SNOW_INSET)
		var here := _count_living_at(at, Drop.SNOW_SCAN)
		for j in players.size():
			if wet[j] and players[j].distance_squared_to(at) <= scan2:
				here += 1
		if _drop.snow.keeps(float(here), expected):
			_spawn_floc(at, Drop.floc_radius(), false)
			_stat(&"snow_kept")


## **One body, made where it cannot be seen** (§6.3, §6.4), **for the player
## whose turn it is** (§10.2): a drifter if the standing drop is short of the
## share that player's sight calls for, a peer if not, drawn for their radius and
## sight; placed at the thinnest of drop.gd's candidates, every one of them out
## of every player's hide reach for its kind. [param players] are where they are
## and [param reaches] how far each one's senses reach; with nobody there, it is
## made for the players [member _made_for] keeps, in turn, anywhere. -1 if there
## was nowhere to put it.
##
## **Since bodies divide, it makes only what is short** (lineage.md §5): a
## peer carrying the toxin while the drop is down to its last carriers of it,
## whatever the count;
## a drifter while the food is under its own count; a peer while the hunters are
## under today's; and otherwise nothing -- [constant NOTHING_SHORT] -- since
## above the floor how many hunters there are is how many their families feed.
## **The food goes first.** The two are one debt, and the hunters' part of it
## is weighed up to be paid back within [member floor_tau]: a hunter short
## pays back five times what a drifter short does, so the hunters take the
## difference and stand about a second of deaths under today's count, where the
## food made last would stand five seconds of them under its own.
func _make_one(players: PackedVector2Array, reaches: PackedFloat32Array) -> int:
	var turns := maxi(_made_for.size() / 2, 1)
	var turn := posmod(_turn, turns)
	var mine := _made_for[2 * turn]
	var sensed := _made_for[2 * turn + 1]
	var drifter := false
	var venom := false
	if births:
		var share := _made_share()
		venom = _peer_short() != &""
		if not venom:
			drifter = float(_drifters) < Drop.food_count(share)
			if not drifter \
					and float(_living - _drifters) >= Drop.hunter_floor(share, floor_share):
				return NOTHING_SHORT
	else:
		drifter = Drop.wants_drifter(_living, _drifters, _drifter_share(sensed))
	_turn = Drop.next_turn(turn, turns)
	var hides := PackedFloat32Array()
	for k in players.size():
		hides.append(Drop.hide_reach(reaches[k], DREAD_RANGE, not drifter))
	var candidates := _drop.spawn_candidates(players, hides,
		turn if turn < players.size() else 0)
	var pick := Replenish.thinnest(candidates, _thinness)
	if pick < 0:
		return -1
	var index := _spawn(candidates[pick], drifter, sensed, false, 0.0, {}, mine)
	if births:
		_stat(&"made_for_food" if drifter else (&"made_for_venom" if venom
			else &"made_for_floor"))
	return index


## **What the spawner owes now, since bodies divide** (lineage.md §5): the
## food's shortfall against its count, the hunters' under today's count weighed
## up by the spawner's tau over [member floor_tau] -- so the one debt pays it
## back that much sooner -- and one more while the toxin is short.
func _shortfall() -> float:
	var share := _made_share()
	var food := maxf(Drop.food_count(share) - float(_drifters), 0.0)
	var hunters := maxf(Drop.hunter_floor(share, floor_share) - float(_living - _drifters),
		0.0)
	return food + hunters * _drop.spawner.tau / maxf(floor_tau, 1e-3) \
		+ (1.0 if _peer_short() != &"" else 0.0)


## **The drifter share of the water the spawner keeps**: the share each player
## it is made for calls for, averaged over them -- one player's own, alone.
func _made_share() -> float:
	var turns := maxi(_made_for.size() / 2, 1)
	var sum := 0.0
	for k in turns:
		sum += _drifter_share(_made_for[2 * k + 1] if 2 * k + 1 < _made_for.size() else 0.0)
	return sum / float(turns)


## **The gene the drop is down to its last carriers of that only a peer brings
## back** (gene-catalogue.md §6.4): the first short variety tagged
## `floor_by_peers` -- the toxin's, in either form -- or `&""` for none (row 13; a
## tool's `--drifter-toxin=1` lets a drifter carry it, and then none waits on a
## peer).
func _peer_short() -> StringName:
	if drifter_toxin:
		return &""
	for gene: StringName in _gene_short:
		if Catalogue.has_tag(gene, Catalogue.FLOOR_BY_PEERS):
			return gene
	return &""


## A drifter [param reach] from a player at [param from], ahead of its
## [param heading] where the drop allows.
func _spawn_ahead(from: Vector2, heading: float, reach: float, sensed: float) -> int:
	for attempt in AHEAD_TRIES:
		var spread := AHEAD_SPREAD + AHEAD_WIDEN * float(attempt)
		var at := from + _forward(heading + randf_range(-1.0, 1.0) * spread) * reach
		if _drop.meniscus.inside(at, Drop.SPAWN_INSET):
			return _spawn(at, true, sensed)
	return -1


## **The one door every new body comes in by** (§12) -- the spawner, the first
## fill, the floors, a sister, the first drifter -- so a birth, in pack 2, is a
## spawn with a parent. A drifter, or a peer made to live for a player of
## [param sensed] (§5.8) and of radius [param mine] -- this cell's, unless
## given; or, given [param body_radius] and [param tiers], that body: a sister,
## or one a tool poses. Fed, unless it is part of a drop's first [param fill].
## **Every one a founder** (lineage.md §4): a new id, generation 1, its own
## lineage and its DNA equal to its body, with no grace -- what the water makes
## was already there. A sister is made a daughter after ([method _born_of]).
## Returns its slot.
func _spawn(at: Vector2, drifter: bool, sensed: float, fill := false,
		body_radius := 0.0, tiers := {}, mine := -1.0) -> int:
	var index := _free_slot_drop()
	var b := _cells[index]
	_renew(b)
	b.id = _next_id
	_next_id += 1
	b.inert = false
	b.settle = 1.0
	b.life = 0.0
	b.age = 0.0
	b.hunger = Drop.made_hunger(fill)
	b.starve = 0.0
	b.effort = 0.0
	b.dart_clock = 0.0
	b.dash_v = 0.0
	b.dash_clock = 0.0
	b.orienting = false
	b.searching = false
	b.look = false
	b.near_frame = -1
	b.stepped = -1
	b.last_t = _t
	b.brain = null
	_record_onto(b, Descent.founder(b.id))
	b.grace = 0.0
	if body_radius > 0.0:
		b.drifter = tiers.is_empty()
		b.radius = body_radius
		b.genome = tiers.duplicate()
	elif drifter:
		_seed_drifter(b)
	else:
		if mine <= 0.0:
			mine = _cell.radius if _cell != null else CellBody.BASE_RADIUS
		_seed_peer(b, mine, sensed)
		_give_back_by_peer(b)
	# Expressed whole, as a run's first cell is: after the toxin, which is worn.
	b.dna = b.genome.duplicate()
	b.pos = at
	b.aim = at
	b.flee_from = at
	b.seeded = true
	_refresh_body(b)
	_living += 1
	if b.drifter:
		_drifters += 1
	_drop.grid.insert(index, at)
	_stat(&"spawned")
	return index


# --- Lineage (docs/design/lineage.md §4): a record on every body, drawn nowhere --------

## **An id from the drop's count for a body it did not make: the player's
## cell**, at every birth and return, so that the cell is in the record as every
## body is and its sister can name it as her parent. 0 outside a drop of this
## field's own -- today's water, a friend's drop, a replay -- none of which keeps
## a record. Moves nothing else: no rule reads an id.
func take_id() -> int:
	if not owns_drop():
		return 0
	var id := _next_id
	_next_id += 1
	return id


## [param record], a descent.gd one numbered for [param b], written onto it:
## whose it is, its generation and its line. Its id is the drop's, given as it
## came in.
func _record_onto(b: Body, record: PackedInt32Array) -> void:
	b.parent = record[Descent.PARENT]
	b.generation = record[Descent.GENERATION]
	b.lineage = record[Descent.LINEAGE]


## **A sister, made a daughter** (lineage.md §4): she carries [param dna] --
## the daughter she was -- and is the child of [param mother]: its id her
## parent, its generation and one, its line. With no DNA she carries what she
## wears, and with no record she stays the founder [method _spawn] made her: a
## guest's sister, whom SISTER brings with her DNA and never her record
## (automation.md §10.3). **And she has a
## newborn's grace** (§3.4), as every daughter does -- a guest's too, who is
## no less newborn for arriving without her record.
func _born_of(b: Body, dna: Dictionary, mother: PackedInt32Array) -> void:
	if not dna.is_empty():
		b.dna = dna.duplicate()
	_record_onto(b, Descent.child(b.id, mother))
	b.grace = newborn_grace if births else 0.0


## **A water cell divides** (lineage.md §3.1): the player's division with nobody
## to choose -- the one place a water body becomes two.
##
## 1. **The mother leaves the water with no cause.** A division is not a death:
##    nothing swallowed, chewed, starved or poisoned her, so she leaves no remains
##    and adds no `Cause`, and whatever was chasing her has nothing to chase.
## 2. **Two DNAs** ([method Drop.daughter_dna]): hers, and hers with one
##    mutation, every division, as yours are (row 19). A coin says which daughter
##    carries which, as on the choosing screen.
## 3. **Two bodies**: each daughter wears what her own roll of her DNA expresses
##    (`Genome.expressed`, the mouth always worn), and one who wears no sense is
##    given one at tier 1 -- the grant every peer and every daughter of yours
##    gets (`Drop.give_sense`) -- on her body and in her DNA.
## 4. **Side by side, touching** (descent.gd's `split`): at half her area, either
##    side of where she was across her heading, held inside the rim, both facing
##    her way. Not nose to tail, where the back one's mouth would sit on her
##    sister. Each comes in by the one door every body does, fed, with a new id,
##    her mother's child, and the newborn grace.
## 5. **Her rules** (behaviour.md §6.1-§6.3): the daughter who carries the
##    changed DNA also carries her mother's list with one change
##    (`Drop.daughter_behaviours`), drawn from what the body, the metabolism and
##    every gene of her own DNA declare; her sister carries her mother's list
##    itself, shared -- null for the founders'. Only on rules with
##    [member rule_change] on; otherwise both carry it and nothing is drawn.
##
## **Both stay**: the water does the choosing. Returns the two daughters' slots.
func _divide(i: int, b: Body) -> PackedInt32Array:
	var mother := Descent.of(b.id, b.parent, b.generation, b.lineage)
	var at := b.pos
	var heading := b.heading
	var brain: Variant = b.brain
	var r := CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)
	var changes := mutate >= 1.0 or randf() < mutate
	var pair: Array = Drop.daughter_dna(b.dna) if changes \
		else [b.dna.duplicate(), b.dna.duplicate(), &""]
	_stat(&"divisions")
	_stat(StringName("divided_" + (String(pair[2]) if pair[2] != &"" else "faithfully")))
	var coin := randf() < 0.5
	var carried: Array = [pair[0], pair[1]] if coin else [pair[1], pair[0]]
	# The daughter the coin gave the changed DNA, who carries the changed rules.
	var changed := 1 if coin else 0
	var points := Descent.split(at, _forward(heading).orthogonal(), r)
	# She was stepped this frame and her daughters were not: neither mouth closes,
	# nor pushes, before the next frame -- the first takes her slot, which is the
	# last one stepped.
	if not _stepped.is_empty() and _stepped[_stepped.size() - 1] == i:
		_stepped.resize(_stepped.size() - 1)
	_drop_lose(i, 0)
	var daughters := PackedInt32Array()
	for k in 2:
		var dna: Dictionary = carried[k]
		var body := Genome.expressed(dna)
		if Drop.give_sense(body, Catalogue.tagged(Catalogue.SENSE), randi()):
			for gene: StringName in Catalogue.tagged(Catalogue.SENSE):
				if body.has(gene) and not dna.has(gene):
					dna[gene] = int(body[gene])
			_stat(&"born_gifted")
		var j := _spawn(_drop.meniscus.contain(points[k], r), false, 0.0, false, r, body)
		var d := _cells[j]
		d.heading = heading
		d.dna = dna
		d.brain = brain
		if k == changed and changes and rules and rule_change:
			var rolled: Array = Drop.daughter_behaviours(founders() if brain == null else brain,
				vocabulary(), _worn_of(dna))
			if rolled[2] != &"":
				d.brain = rolled[1]
				_stat(StringName("rules_" + String(rolled[2])))
		_record_onto(d, Descent.child(d.id, mother))
		d.grace = newborn_grace
		# Her own first step is the next frame's, whichever pass would have
		# reached her slot in this one.
		d.near_frame = _frame
		# Born, not made: the census's `spawned` is what the spawner and the
		# other doors made.
		_stat(&"spawned", -1)
		_stat(&"born")
		if Catalogue.worn_provider(body, &"impulse_speed") == &"":
			_stat(&"born_tailless")
		daughters.append(j)
	return daughters


## **A floc** at [param at], of [param body_radius]: settled already -- remains,
## or a drop's first -- or [param settled] false, a flake just landed.
func _spawn_floc(at: Vector2, body_radius: float, settled: bool) -> int:
	var index := _free_slot_drop()
	var b := _cells[index]
	_renew(b)
	b.id = _next_id
	_next_id += 1
	b.inert = true
	b.drifter = true
	b.genome = {}
	# Nobody's daughter and nothing to pass on, but a record like every body's,
	# so a slot it reuses keeps nothing of the body that was there.
	b.dna = {}
	_record_onto(b, Descent.founder(b.id))
	b.grace = 0.0
	b.radius = body_radius
	b.settle = 1.0 if settled else 0.0
	b.life = Drop.floc_life()
	b.age = 0.0
	b.hunger = 0.0
	b.starve = 0.0
	b.effort = 0.0
	b.dash_v = 0.0
	b.orienting = false
	b.searching = false
	b.look = false
	b.near_frame = -1
	b.stepped = -1
	b.last_t = _t
	b.pos = at
	b.aim = at
	b.flee_from = at
	b.seeded = true
	_refresh_body(b)
	_flocs += 1
	_drop.grid.insert(index, at)
	return index


func _free_slot_drop() -> int:
	while not _free.is_empty():
		var index := _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
		if index < _cells.size() and not _cells[index].seeded:
			return index
	_cells.append(Body.new())
	return _cells.size() - 1


## **What a peer is made of in the drop** (§5.8): a born cell's body plan -- a
## mouth, a `cirrus` and a `flagellum`, at tiers drawn as today -- then the rest
## drawn as today up to the slots its radius has, the ceiling on what the water
## makes kept on the mouth, and a sense given in a bonus slot to a peer that
## drew none, as the player's newborn is given one.
##
## **Its born organs are the born keys** (gene-catalogue.md §15.6), and each takes
## only its own variety out of the pool: the organ's other variants stay in it, so a
## peer may draw a faster tail beside the tail it was born with -- unless the organ
## holds one variant to a body, which takes the whole organ out, as any draw does.
func _draw_living(body_radius: float, sensed: float) -> Dictionary:
	var tiers := {}
	for gene: StringName in Drop.peer_plan():
		tiers[gene] = _draw_tier(sensed)
	var capacity := CellBody.slots_for(body_radius)
	var pool: Array[StringName] = Catalogue.drifters().duplicate()
	for gene: StringName in tiers:
		if Catalogue.one_variant(Catalogue.organ_of(gene)):
			_erase_organ(pool, gene)
		else:
			_erase_variety(pool, gene)
	# The toxin drawn as one gene, its place by a coin, and poison taking no arc
	# ([method _place_toxin]): a peer's draw differs from before only on a peer
	# that drew the toxin.
	while Genome.count_outside(tiers) < capacity and not pool.is_empty():
		var gene := _draw_gene(pool)
		_erase_organ(pool, gene)
		var tier := _draw_tier(sensed)
		tiers[_place_toxin(gene)] = tier
	var mouth := Catalogue.worn_provider(tiers, &"gape")
	while mouth != &"" and int(tiers[mouth]) > 0 \
			and CellBody.gape_of(tiers, body_radius) > ARRIVAL_GAPE_MAX:
		tiers[mouth] = int(tiers[mouth]) - 1
	if Drop.give_sense(tiers, Catalogue.tagged(Catalogue.SENSE), randi()):
		_stat(&"sense_given")
	return tiers


## **A gene back through a peer** (§6.4, docs/design/dna-slots.md §9;
## gene-catalogue.md §6.4): a drop down to its last carriers of a gene tagged
## `floor_by_peers` -- the toxin's, in either form -- gives the next peer that
## gene, its place by a coin, since no drifter may carry it. A peer that carries it,
## or another strain of an organ held to one a body, is passed over
## (`Drop.takes_back`), and the gene waits for the next.
func _give_back_by_peer(b: Body) -> void:
	var gene := _peer_short()
	if gene == &"" or not Drop.takes_back(b.genome, gene):
		return
	_gene_short.erase(gene)
	Drop.give_back(b.genome, gene, CellBody.slots_for(b.radius),
		Catalogue.tagged(Catalogue.SENSE), randi(), randi() % 2 == 0)
	b.derive()
	_stat(&"gene_floor_peer")


## **The gene floor's count** (§6.4): who carries what, and which genes the
## drop is down to its last GENE_FLOOR carriers of. **A form counts as its
## variety** (docs/design/dna-slots.md §9): a venom and a poison are two carriers
## of one toxin, which is the gene the floor keeps.
func _count_genes() -> void:
	var counts := {}
	for b in _cells:
		if not b.seeded or b.inert:
			continue
		for gene: StringName in b.genome:
			var kind := Genome.variety(gene)
			counts[kind] = int(counts.get(kind, 0)) + 1
	_gene_short = Drop.short_genes(counts, Catalogue.drifters())


## **The player's hide reach for a body with a mouth, or without** (§6.3): the
## view on the widest phone and every reach its own senses have, and dread's
## for a mouth.
func _hide_reach(mouth: bool) -> float:
	return Drop.hide_reach(maxf(maxf(smell_range, ping_range), beam_range),
		DREAD_RANGE, mouth)


## How far round the player a body can reach any sense: the scent, dread, the
## ping and the beam, whichever is farthest.
func _scan_reach() -> float:
	return maxf(maxf(SCENT_RANGE, DREAD_RANGE), maxf(ping_range, beam_range))


# --- Counting places, for the spawner, the snow and the start --------------------------------

func _thinness(at: Vector2) -> int:
	return _count_living_at(at, Drop.SPAWN_SCAN)


func _count_living_at(at: Vector2, reach: float) -> int:
	_count_ids.resize(0)
	_drop.grid.query(at, reach, _count_ids)
	var reach2 := reach * reach
	var n := 0
	for j: int in _count_ids:
		var o := _cells[j]
		if o.seeded and not o.inert and o.pos.distance_squared_to(at) <= reach2:
			n += 1
	return n


func _count_drifters_at(at: Vector2, reach: float) -> int:
	_count_ids.resize(0)
	_drop.grid.query(at, reach, _count_ids)
	var reach2 := reach * reach
	var n := 0
	for j: int in _count_ids:
		var o := _cells[j]
		if o.seeded and o.drifter and not o.inert and o.pos.distance_squared_to(at) <= reach2:
			n += 1
	return n


## **How much a born cell could eat within [param reach] of [param at]**: every
## living body and settled floc its mouth could take, armour counted.
func _food_for_born(at: Vector2, reach: float) -> int:
	var gape := CellBody.gape_of(Catalogue.born(), CellBody.BASE_RADIUS)
	_count_ids.resize(0)
	_drop.grid.query(at, reach, _count_ids)
	var reach2 := reach * reach
	var n := 0
	for j: int in _count_ids:
		var o := _cells[j]
		if not o.seeded or o.pos.distance_squared_to(at) > reach2:
			continue
		if o.inert and o.settle < 1.0:
			continue
		if _swallow_r(o) < gape:
			n += 1
	return n


func _dread_for_born(at: Vector2) -> float:
	return _dread_at(at, CellBody.BASE_RADIUS)


## **The dread a body of [param mine] would feel at [param at]**: the membrane's
## own sum over whatever could swallow it, on distance -- what a start is
## chosen by, and what the census samples.
func _dread_at(at: Vector2, mine: float) -> float:
	_count_ids.resize(0)
	_drop.grid.query(at, DREAD_RANGE, _count_ids)
	var dread := 0.0
	for j: int in _count_ids:
		var b := _cells[j]
		if not b.seeded or b.inert:
			continue
		var level := smoothstep(THREAT_LOW, THREAT_HIGH, _gape(b) / maxf(mine, 0.001))
		if level > 0.0:
			dread += clampf((DREAD_RANGE - b.pos.distance_to(at))
				/ (DREAD_RANGE - DREAD_CORE), 0.0, 1.0) * level
	return dread


# --- For the view, the readout and the tools ----------------------------------------------

## **How much of a body the mouth's scent weighs** (§7.0's curve): 1 for a body
## comfortably inside [param gape], fading to nothing as [param size] -- the
## size the mouth measures -- crosses it. The taste field and the view's bloom
## both read it, so the two cannot disagree (§14.1).
static func taste_weight(size: float, gape: float) -> float:
	return smoothstep(EDIBLE_FADE_OUT, EDIBLE_FADE_IN, size / maxf(gape, 0.001))


## **The bodies within [param reach] of [param point]**, by slot: in the drop
## asked of the grid, so the view draws the dozen on screen and never walks six
## hundred (§4.4). Retired slots are never in it.
func bodies_near(point: Vector2, reach: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var reach2 := reach * reach
	if _drop != null:
		_view_ids.resize(0)
		_drop.grid.query(point, reach + Drop.GRID_SLACK, _view_ids)
		for i: int in _view_ids:
			if _cells[i].seeded and _cells[i].pos.distance_squared_to(point) <= reach2:
				out.append(i)
		return out
	for i in _cells.size():
		if _cells[i].seeded and _cells[i].pos.distance_squared_to(point) <= reach2:
			out.append(i)
	return out


## **How big body [param index] is to a mouth**: in the drop its radius with its
## `pellicle` counted, as every mouth there measures it (row 5); in today's
## water its bare radius, as a water cell's always was. The view's bloom reads
## it, so it weighs a body as the taste field does.
func swallow_size_of(index: int) -> float:
	if index < 0 or index >= _cells.size():
		return 0.0
	return _swallow_r(_cells[index]) if _drop != null else _cells[index].radius


## **How many bodies the water stepped this frame**, for the dev app's readout:
## in the drop, near and far on their ticks, flocs among them; today's water
## steps every body it holds.
func stepped_bodies() -> int:
	if _drop != null:
		return _stepped.size()
	var n := 0
	for b in _cells:
		if b.seeded:
			n += 1
	return n


## **A body a tool moved by hand is filed again**, so the drop's senses and
## passes find it where it now is. Nothing in the game calls this.
func refile(index: int) -> void:
	if _drop != null and index >= 0 and index < _cells.size() and _cells[index].seeded:
		_drop.grid.insert(index, _cells[index].pos)


## **A body a tool wrote a genome or a radius into** has what its organs buy
## read again, and is filed where it is. Nothing in the game calls this.
func refresh(index: int) -> void:
	if _drop == null or index < 0 or index >= _cells.size():
		return
	_refresh_body(_cells[index])
	refile(index)


## **A body for a tool**, at [param at], with [param body_radius] and
## [param tiers], in a slot nobody else uses: through the one door every body
## comes in by. The chase probe's hunter. Nothing in the game calls this.
func pose_body(at: Vector2, body_radius: float, tiers: Dictionary) -> int:
	if _drop == null:
		return -1
	return _spawn(at, false, _sensed(), false, body_radius, tiers)


## **A body for a tool in slot [param index]**, which a probe names: whatever
## lived there leaves the drop, and a new body -- a new id -- comes in by the one
## door every body does, at [param at] with [param body_radius] and
## [param tiers]. Never a person's slot. Returns the slot, or -1. Nothing in the
## game calls this.
func pose_at(index: int, at: Vector2, body_radius: float, tiers: Dictionary) -> int:
	if not owns_drop() or index < 0 or _is_person_slot(index):
		return -1
	while _cells.size() <= index:
		_cells.append(Body.new())
		_free.insert(0, _cells.size() - 1)
	if _cells[index].seeded:
		_drop_lose(index, 0)
	else:
		var was := _free.find(index)
		if was >= 0:
			_free.remove_at(was)
		_free.append(index)
	return _spawn(at, false, _sensed(), false, body_radius, tiers)


## **A body a tool takes out of the drop** -- gone, as a floc eaten is: no cause,
## no remains. Nothing in the game calls this.
func take_out(index: int) -> void:
	if owns_drop() and index >= 0 and index < _cells.size() \
			and not _is_person_slot(index) and _cells[index].seeded:
		_drop_lose(index, 0)


## **One line about the whole drop**, for the probes: its population, what it
## is made of, what it could do to a player of three sizes, how its bodies have
## ended, and a checksum of every body's place, size and tank -- so two runs
## that print the same line ran the same drop. Its dread is sampled at the same
## 64 points every time, from a stream of its own: asking never moves the drop.
func census_line() -> String:
	if _drop == null:
		return "[census] not in the drop"
	var drifters := 0
	var hunters := 0
	var flocs := 0
	var big := 0
	var threats := PackedInt32Array([0, 0, 0])
	var sizes := PackedFloat32Array([26.0, 34.0, 40.0])
	var radius_sum := 0.0
	var hunger_sum := 0.0
	var genes := {}
	var sums := PackedFloat64Array()
	for b in _cells:
		if not b.seeded:
			continue
		sums.append(b.pos.x)
		sums.append(b.pos.y)
		sums.append(b.radius)
		sums.append(b.hunger)
		if b.inert:
			flocs += 1
			continue
		for gene: StringName in b.genome:
			genes[gene] = true
		if b.drifter:
			drifters += 1
			continue
		hunters += 1
		radius_sum += b.radius
		hunger_sum += b.hunger
		var gape := _gape(b)
		for k in sizes.size():
			if gape > sizes[k]:
				threats[k] += 1
		if b.radius >= CellBody.DIVIDE_RADIUS - 0.01:
			big += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260930
	var dread := PackedFloat32Array([0.0, 0.0, 0.0])
	for k in 64:
		var at := _drop.meniscus.center + Vector2.from_angle(rng.randf_range(-PI, PI)) \
			* (Drop.RADIUS - 200.0) * sqrt(rng.randf())
		for s in sizes.size():
			dread[s] += _dread_at(at, sizes[s]) / 64.0
	return ("[census] t %.0f  living %d (drifters %d, hunters %d)  flocs %d  | hunters"
		+ " at r40 %d, mean r %.1f, hunger %.2f  | could swallow r26/r34/r40 %d/%d/%d"
		+ "  dread %.2f/%.2f/%.2f  genes %d  | spawned %d  died: swallowed %d chewed %d"
		+ " starved %d (r40 %d) poisoned %d  | grazed by the water %d, by drifters %d,"
		+ " dissolved %d, snow kept %d, remains %d  | runs %d at you %d misses %d darts %d"
		+ " dashes %d  floors: gene %d+%d drifter %d  | sum %d") % [
		_t, drifters + hunters, drifters, hunters, flocs, big,
		radius_sum / maxf(hunters, 1), hunger_sum / maxf(hunters, 1),
		threats[0], threats[1], threats[2], dread[0], dread[1], dread[2], genes.size(),
		_n(&"spawned"), _n(&"died_swallowed"), _n(&"died_chewed"), _n(&"died_starved"),
		_n(&"died_starved_r40"), _n(&"died_poisoned"), _n(&"water_grazed"),
		_n(&"drifter_grazed"), _n(&"flocs_dissolved"), _n(&"snow_kept"), _n(&"remains"),
		_n(&"runs"), _n(&"runs_at_player"), _n(&"misses"), _n(&"water_darts"),
		_n(&"water_dashes"), _n(&"gene_floor"), _n(&"gene_floor_peer"), _n(&"drifter_floor"),
		hash(sums)]


## **The drop's families, in one line** (lineage.md §4, §6.1), for the probes,
## beside [method census_line] and never in it: the hunters -- how many were
## born rather than made, their generation, how many founders they descend from
## and the largest family, and how many carry a DNA that is not their body --
## and what they have become: their cruise, reach, mouth and upkeep, the genes
## they wear and carry, how many have a tail, a sense, or are at r40; then each
## gene's mean tier worn, by its key (gene-catalogue.md §13: four letters of it named
## two genes as soon as two keys began alike), and the three commonest bodies. Asking
## moves nothing.
func lineage_line() -> String:
	if _drop == null or _mirror:
		return "[lineage] not in a drop of its own"
	var n := 0
	var born := 0
	var generations := 0
	var deepest := 0
	var families := {}
	var apart := 0
	var cruise := 0.0
	var notice := 0.0
	var mouth := 0.0
	var upkeep := 0.0
	var worn := 0
	var carried := 0
	var tails := 0
	var sighted := 0
	var big := 0
	var tiers := {}
	var kinds := {}
	for b in _cells:
		if not b.seeded or b.inert or b.drifter or b.person != null:
			continue
		n += 1
		if b.generation > 1:
			born += 1
		generations += b.generation
		deepest = maxi(deepest, b.generation)
		families[b.lineage] = int(families.get(b.lineage, 0)) + 1
		if b.dna != b.genome:
			apart += 1
		cruise += b.cruise
		notice += b.notice
		mouth += Stats.tier(b.genome, &"gape")
		upkeep += b.upkeep
		worn += b.genome.size()
		carried += b.dna.size()
		if Stats.tier(b.genome, &"impulse_speed") > 0:
			tails += 1
		if b.notice > 0.0 or b.see_big > 0.0:
			sighted += 1
		if b.radius >= CellBody.DIVIDE_RADIUS - 0.01:
			big += 1
		var parts := PackedStringArray()
		for gene: StringName in Catalogue.live():
			var tier := Genome.tier_of(b.genome, gene)
			if tier > 0:
				tiers[gene] = int(tiers.get(gene, 0)) + tier
				parts.append("%s:%d" % [gene, tier])
		var kind := ",".join(parts)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	var largest := 0
	for line: int in families:
		largest = maxi(largest, int(families[line]))
	var common: Array = kinds.keys()
	common.sort_custom(func(x: String, y: String) -> bool:
		return int(kinds[x]) > int(kinds[y]) or (int(kinds[x]) == int(kinds[y]) and x < y))
	var commonest := PackedStringArray()
	for k in mini(3, common.size()):
		commonest.append("%dx %s" % [int(kinds[common[k]]), common[k]])
	var m := float(maxi(n, 1))
	var means := PackedStringArray()
	for gene: StringName in Catalogue.live():
		means.append("%s %.2f" % [gene, float(tiers.get(gene, 0)) / m])
	return ("[lineage] t %.0f  hunters %d, born %d  generation mean %.2f max %d  families %d"
		+ " (largest %d)  dna apart %d  | cruise %.1f notice %.0f mouth %.2f upkeep %.2f"
		+ " genes worn %.2f carried %.2f  tails %d sighted %d at r40 %d  | divisions %d"
		+ " (trade %d drift %d faithfully %d), daughters %d: tailless %d, given a sense %d"
		+ "  | the spawner's peers %d (for the floor %d, for venom %d), drifters %d, left to"
		+ " births %d  | worn %s  | commonest %s") % [_t, n, born, float(generations) / m,
		deepest, families.size(), largest, apart, cruise / m, notice / m, mouth / m,
		upkeep / m, float(worn) / m, float(carried) / m, tails, sighted, big,
		_n(&"divisions"), _n(&"divided_trade"), _n(&"divided_drift"),
		_n(&"divided_faithfully"), _n(&"born"), _n(&"born_tailless"), _n(&"born_gifted"),
		_n(&"made_for_floor") + _n(&"made_for_venom"), _n(&"made_for_floor"),
		_n(&"made_for_venom"), _n(&"made_for_food"), _n(&"spawn_left_to_births"),
		" ".join(means), " ; ".join(commonest)]


## **The water's families, for the dev app's readout** (lineage.md §4, §6.4):
## `[the hunters' mean generation, how many founders they descend from]` -- or
## nothing where the water keeps no record (today's water, a friend's drop seen
## from inside it, a replay) or holds no hunter. Asking moves nothing.
func lineage_counts() -> Array:
	if not owns_drop():
		return []
	var n := 0
	var generations := 0
	var families := {}
	for b in _cells:
		if not b.seeded or b.inert or b.drifter or b.person != null:
			continue
		n += 1
		generations += b.generation
		families[b.lineage] = true
	if n == 0:
		return []
	return [float(generations) / float(n), families.size()]


## **The water's behaviours, for the dev app's readout** (behaviour.md §7.3):
## `[how many different lists its hunters carry, the share of them on the
## founders' rules, in percent]` -- or nothing where the water keeps no record
## (today's water, a friend's drop seen from inside it, a replay), where its
## hunters run pack 2's hand-written hunter ([member rules] off), or where it
## holds no hunter. **Two lists are one behaviour when they say the same**
## (rulebook.gd's `key_of`): a family shares one list, and a line whose changes
## have come back round to the founders' rules is on them again. Asking moves
## nothing.
func behaviour_counts() -> Array:
	if not owns_drop() or not rules:
		return []
	# The hunters on each list a family shares, by the list itself; then what
	# each of those lists says, once a list.
	var n := 0
	var unchanged := 0
	var on := {}
	for b in _cells:
		if not b.seeded or b.inert or b.drifter or b.person != null:
			continue
		n += 1
		if b.brain == null:
			unchanged += 1
		else:
			on[b.brain] = int(on.get(b.brain, 0)) + 1
	if n == 0:
		return []
	var theirs := Rulebook.key_of(founders())
	var lists := {}
	if unchanged > 0:
		lists[theirs] = true
	for list: Variant in on:
		var key := Rulebook.key_of(list)
		lists[key] = true
		if key == theirs:
			unchanged += int(on[list])
	return [lists.size(), 100.0 * float(unchanged) / float(n)]


## **One line on how the water's hunters behave** (behaviour.md §12.1), beside
## the lineage line, for `tools/eco_probe.gd` and `tools/drive.gd`: its hunters,
## how many of them are on the founders' rules and how many lists the rest
## carry; how often each of the founders' rules has fired; the meals of hunters
## wearing a nose, a radar and a laser; the darts the water fired, the stuns and
## your wakes; and what its hunters are doing now. With [member rules] off,
## that it runs pack 2's hunter. Asking moves nothing.
##
## **And, last, what the rules' changes have made of it** (phase 3-2, §7.3): how
## many behaviours its hunters carry and the share still on the founders' rules,
## as the dev app's readout counts them ([method behaviour_counts]) -- lists that
## say the same as one, where the counts before it go by the list each family
## shares -- and the changes made at division, by kind. Last, so that phase
## 3-1's line is this one's beginning, to the byte, with the changes off.
func behaviour_line() -> String:
	if _drop == null or _mirror:
		return "[behaviour] not in a drop of its own"
	if not rules:
		return "[behaviour] t %.0f  rules off: pack 2's hunter" % _t
	var n := 0
	var on_founders := 0
	var lists := {}
	var holding := 0
	var resting := 0
	var swimming := 0
	var pushing := 0
	var stunned := 0
	var echoes := 0
	for b in _cells:
		if not b.seeded or b.inert or b.drifter or b.person != null:
			continue
		n += 1
		if b.brain == null:
			on_founders += 1
		else:
			lists[b.brain] = true
		holding += 1 if b.holding else 0
		resting += 1 if b.resting else 0
		# **Swimming is its tail beating** (automation.md §5.3): a swim rule's
		# claim in pack 3's water, where the two are the same body for body, and
		# under row 37 every tail that is not held.
		swimming += 1 if _tail_beats(b) else 0
		pushing += 1 if b.push > 0.0 else 0
		stunned += 1 if b.stun > 0.0 else 0
		echoes += b.echoes.size()
	var fired := PackedStringArray()
	for k in Drop.FOUNDERS.size():
		fired.append(str(_n(FIRED[k])))
	var kinds := behaviour_counts()
	var changed := 0
	var each := PackedStringArray()
	for kind: StringName in Drop.CHANGES:
		var made := _n(StringName("rules_" + String(kind)))
		changed += made
		each.append("%s %d" % [kind, made])
	return ("[behaviour] t %.0f  hunters %d: on the founders' rules %d, other lists %d"
		+ "  | founders' rules fired %s  | meals of hunters with a nose %d, radar %d,"
		+ " laser %d  | water darts %d, stuns %d, your wakes %d  | now holding a heading"
		+ " %d, resting %d, swimming %d, pushing %d, stunned %d, echoes in flight %d"
		+ "  | behaviours %d, unchanged %s  | rules changed %d: %s") % [
		_t, n, on_founders, lists.size(), "/".join(fired), _n(&"meals_nose"),
		_n(&"meals_radar"), _n(&"meals_laser"), _n(&"water_darts"), _n(&"stuns"),
		_n(&"wakes"), holding, resting, swimming, pushing, stunned, echoes,
		int(kinds[0]) if kinds.size() == 2 else 0,
		"%.1f %%" % float(kinds[1]) if kinds.size() == 2 else "-", changed, ", ".join(each)]


func _n(what: StringName) -> int:
	return int(stats.get(what, 0))


func _stat(what: StringName, by: int = 1) -> void:
	stats[what] = int(stats.get(what, 0)) + by


## `0 .. _cells.size() - 1`: today's loop over every body, for the functions it
## shares with the drop's lists.
func _all_ids() -> PackedInt32Array:
	var n := _cells.size()
	if _ids.size() != n:
		_ids.resize(n)
		for i in n:
			_ids[i] = i
	return _ids


## `0 .. _water - 1`: today's loop over the water slots, the same way.
func _water_ids() -> PackedInt32Array:
	if _water_idx.size() != _water:
		_water_idx.resize(_water)
		for i in _water:
			_water_idx[i] = i
	return _water_idx
