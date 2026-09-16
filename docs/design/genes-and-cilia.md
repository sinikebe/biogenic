# Genes and cilia

Phase 5. The cell stops being one thing and starts being a **choice**: a genome
with a fixed number of slots, filled by what you eat, worn on the outside as
cilia.

Extends `perception.md` and `food-and-predators.md`; it contradicts both in
places and says so where it does. Every number that can be *seen* was rendered
under GL Compatibility at 1280x720 **and** 2400x1080 and looked at; §10 lists
what, and the numbers that cannot be seen are flagged where they appear. The
prototype was built in a throwaway copy of the project outside the repository.

> **Reviewed after merge, and §1.1–1.3 did not survive intact.** The gape rule
> stands; the claim that it reads at a glance was withdrawn and replaced (§1.1.1),
> and the ecosystem bound was rewritten from an unparameterised sentence into a
> seeding function that can actually be built (§1.3). The economy in §3.2 made the
> mouth a strictly dominant gene and is corrected. Everything the review changed
> says so in place.

## 1. The decisions, in one place

0. **There is no predator and no food. There are cells with genomes.** The
   owner's revision, and the one every other decision now hangs off:

   > It's just a cell, with its own genes, and genes will tell if you can eat
   > another one or not by seeing their cilia.

   "Predator" is not a kind of thing; it is a **relationship**, it is read off a
   body, and it changes in both directions during a run. Other cells grow the
   way you do — by eating gene-carrying cells. See §1.1.
1. **Cilia are the visible expression of ability, and every cell wears them** —
   you and everything else. One drawing routine, one subject.
2. **The starting cell is already full.** Three slots, three organs:
   `cytostome` *eat*, `cirrus` *turn*, `flagellum` *swim*, all at tier 1 (§9.1).
   You are not an empty vessel; you are mediocre at three things, and becoming
   something means stopping being something.
3. **Genome size is capacity, not currency.** There are no genetic points.
   Slots come from body radius — the one number the game already has, which now
   means three things: what can eat me, what I can eat, and how much I can be.
4. **Gene identity is one hue used in four places** — the cilia on your body,
   the cilia on the prey that carries it, the ingest flood at the instant you
   eat it, and the slot on the genome strip. No legend, no lookup.
5. **Point of view forages blind and that is the point** (§2).
6. **The genome surface is a launcher-themed panel, and it lives on the pause
   screen.** This settles `perception.md` §6.4 (§5).
7. **"Synthesis" is not a Phase 5 word.** Phase 5 integrates genes into one
   cell. Making *other* cells belongs with multicellular bodies, which the owner
   deferred; see `roadmap.md`.

### 1.1 What decides whether you can eat something: the gape

**You can eat a cell whose body fits in your mouth.** That is the whole rule.

The mouth is an organ — the **cytostome** — and like every organ it has a tier
and it is drawn. Its tier sets how wide the mouth opens, as a multiple of your
own body radius:

| cytostome | gape | at r26 |
|---|---|---|
| none | `0.58 r` | 15 |
| tier 1 | `0.82 r` | 21 |
| tier 2 | `1.05 r` | 27 |
| tier 3 | `1.40 r` | 36 |

`A can eat B` is `B.radius < A.gape`. Nothing else. It is evaluated in both
directions independently, which is what makes it interesting: there are four
relationships, not two.

| | they fit in my mouth | they do not |
|---|---|---|
| **I fit in theirs** | **both** — whoever commits first | **it eats me** |
| **I do not** | **eat it** | **neither** — a standoff |

**Why the gape and not the radius.** A pure size comparison is a single number
with a single ordering: everything smaller is food, everything bigger is death,
and there is nothing to read because the answer is the silhouette. Splitting the
mouth out from the body makes the two independent, and the moment they are
independent the interesting cells exist — **a small cell with an enormous mouth
is both prey and predator**, and a large cell with no mouth is neither. That is
the cell you have to look at rather than glance at.

It also makes the owner's premise literally true: the thing that decides
edibility *is* an organ, and organs are worn on the outside.

**What the multipliers actually buy — tier 2 is a threshold, not a step.** Write
the rule as a ratio, `rho = B.radius / A.radius`, for two cells with the same
cytostome tier `g`. A eats B below `g`; B eats A above `1/g`. So:

| tier | `g` | two equal cells are… |
|---|---|---|
| none | 0.58 | standoff across `0.58 … 1.72` — a very wide safe band |
| 1 | 0.82 | standoff across `0.82 … 1.22` |
| 2 | 1.05 | **mutual** across `0.95 … 1.05` |
| 3 | 1.40 | **mutual** across `0.71 … 1.40` — almost everything near you |

**Cytostome 2 is where the water stops having standoffs in it.** Below it, a
peer is something you pass; at and above it, a peer is a fight neither of you can
walk away from, decided by who commits first. That is the most interesting thing
these four numbers do and it should be kept: it means specialising into the mouth
does not just widen the menu, it changes the *genre* of every encounter. It also
says where the ceiling is — tier 3 does not trivialise foraging so much as delete
safety, because nothing your own size is neutral any more.

### 1.1.1 How the gape is drawn, and the one thing the render caught

The mouth is a bow across the nose, seated at **`1.05` of the nose** along the
heading, bulging forward by `0.30 * gape`, with two stems back to the body so it
reads as an organ rather than a floating bracket. The clear span between the lip
tips is `2 * gape`, measured across the heading, so it is the same number of
pixels whichever way the cell is pointing; a cell cannot hide its mouth by
turning.

> **Corrected from `r * 1.05` by the build.** That number is right for a round
> cell and wrong for this one: §4.1's ovoid reaches `r * 1.18` along the heading,
> so a bow seated at `1.05 r` is *inside the nose*. Rendered, it was a flat brim
> lying across the top of the body with the oral mat poking through it, and it
> read as a hat. Taken as 1.05 of the surface instead — `1.18 * 1.05 = 1.24 r`,
> which is what the number means on a circle — the bow clears the nose, the
> stems have something to span, and at tier 3 the mat crest (`1.67 r`) converges
> on the bow's apex (`1.66 r`) rather than crossing it. §4.6's new needle base
> at `1.80 r` clears both, which is the arithmetic that says 1.24 is the number
> the design meant all along.
>
> The **stems** land at `t = ±54°` — the middle of free arcs 1 and 2, the
> diagonal gap — and not at the ends of the anterior arc. At a tier-3 gape the
> lip tips are `1.4 r` out to the side, so stems to `±42°` run back almost
> horizontally and saw straight through the oral mat. From the shoulder they
> pass outside it at every tier.

> **The caliper claim is withdrawn — the third pass measured it.** The previous
> draft said the span being `2 * gape` meant "the widest body that fits between
> the lips is the widest body it can swallow — drawn at 1:1, no legend needed."
> It is drawn at 1:1. It cannot be *read* at 1:1, for two measured reasons.
>
> The first is the body it has to be read against. The ovoid presents between
> **1.96 r and 2.36 r** of width depending on which way it is pointing (across
> the heading `2 x 0.9785 r`, along it `2 x 1.18 r`) — a **20% spread from
> orientation alone**, against a smallest tier step in the gape of 28%
> (`0.82 r` to `1.05 r`). The error is nearly the size of the thing being
> measured, and you cannot tell a cell's orientation well enough to correct for
> it at 400 units.
>
> The second is worse and is not a numbers problem: the caliper asks the player
> to compare **two lengths at two different places on the screen** with no shared
> baseline, at a glance, while swimming. That is a task people are bad at under
> laboratory conditions.
>
> So the span is a *truthful drawing of the mouth*, not an instrument. A bigger
> mouth looks bigger, which is worth having. What tells the player whether a body
> fits inside it is the scent bloom below, on the body, not the bow.

> **The previous draft's render claim was too kind and is withdrawn.** It said
> the small-body-huge-mouth case "reads as alarming rather than as prey". At the
> distance it was photographed — near frame centre, conveniently placed — that is
> true. Re-rendered at real foraging distance (250–640 world units, which at
> `ZOOM 1.0` is mid-screen to the frame edge) it is **false**: a cell of `r21`
> with a tier-3 mouth reads as lunch, because the only comparison on screen is
> the mouth against *its own* body, and against its own body it is merely
> frilly. The two cases the gape rule was invented for — the small cell that can
> swallow you, and the harmless giant — are exactly the two the silhouette gets
> wrong, and drawing the gape truthfully does not fix that on its own.

**So the gape carries the relationship, not just the measurement.** One
comparison, and a colour *and* a shape, on the organ that causes it:

| the other cell's gape | lip bow |
| --- | --- |
| `gape <= my.radius` — it cannot swallow me | cytostome green `Color(0.62, 1.00, 0.38)`, alpha `0.30 + 0.16 * tier`, width 1.7, smooth |
| `gape > my.radius` — it can | **`Color(0.78, 0.24, 0.30)`**, alpha `>= 0.72`, width 2.6, **and seven teeth** |

The teeth are 7 ticks spaced evenly along the bow at `s = -0.86 … 0.86`, each
`0.22 * gape` long, pointing **back into the mouth** along `-fwd`, same colour,
alpha `0.9 * bow`. They are not decoration — see the colour-vision note below.

That red is `PREDATOR_TINT`, unchanged from Phase 4. **It does not die with
`predator.gd` (§7.0); it moves from the body to the mouth.** The thing that can
kill you is still red, it is still the only red in the water, and now it is red
on the organ that does the killing rather than on a species. A cell that grows
its cytostome past your radius turns red in front of you.

This is legal in full vision and only in full vision: `perception.md` §4 says
full vision exists to show what is actually there, and "this can swallow you" is
a fact about what is there. **The membrane is not told.** Point of view reads
danger the way it always has — dread and the wake (§7.0) — and identity on the
skin is still forbidden.

**Why teeth and not just red — measured, because colour alone does not survive
the check.** A safe bow and a threat bow are the same shape in the same place
with opposite meanings, which is the worst case for a colour-only signal. Under a
Viénot deuteranope simulation of the actual render:

| | sRGB | as a deuteranope sees it | relative luminance |
| --- | --- | --- | --- |
| safe green | `(158, 255, 97)` | `(232, 232, 102)` | **0.797** |
| threat red | `(199, 61, 76)` | `(124, 124, 70)` | **0.160** |

Both collapse to the same yellow hue, and the dangerous one ends up **five times
darker than the harmless one** — the wrong way round for the more urgent signal.
Colour is therefore carrying nothing for roughly one man in twelve. The teeth fix
it on shape: rendered and simulated, a toothed bow reads as a distinct hooked
form at 500 units even when both bows are the same olive. Width helps too (2.6
against 1.7) but shape is what does the work.

Rendered with the threat colour and teeth at 1280x720 and 2400x1080, at 250–640
units and at the frame edge, in full colour and under the deuteranope
simulation: the `r21`/gape-29 cell reads as dangerous at a glance from across the
screen, and the `r33` mouthless giant stays blue and reads as something to
ignore. Both were wrong without it.

**And the third pass found the half that had no mark at all.** Everything above
is about *its* mouth. Nothing above is about *your* mouth — and "I can eat it"
is the commonest decision in the game. It was supposed to be carried by the
scent haze; measured off the built render, the haze was **0.6 of 255** brighter
around an edible cell than around an inedible one, which is not a weak readout,
it is none. §4.5 has the measurement and the fix. In one line: every cell that
fits in your mouth now wears a soft green bloom, gene-blind, weighted by exactly
the curve the membrane's taste band reads. All four relationships are then drawn,
each on the thing that causes it, and none of the four marks is in the same place
as another:

| relationship | what is drawn |
| --- | --- |
| **I can eat it** | a scent bloom around **its body**, `FOOD_TINT` |
| **It can eat me** | a red toothed lip bow on **its mouth** |
| **Both** | bloom *and* red toothed bow — different places, they do not fight |
| **Neither** | a plain tinted body: no bloom, and a green or absent bow |

Rendered at both sizes with all four posed at 400–560 units and at the frame
edge, which is the test the first pass skipped: all four are callable at a
glance.

### 1.2 Other cells evolve too

They eat what fits in their mouths, and they grow by it, on the same rules. A
cell that has been feeding is bigger and has a wider gape than it started with,
so **the longest-lived cells become the most dangerous without anyone authoring
a difficulty curve.**

That is the best thing in this idea and the one most able to go wrong, so it is
bounded rather than trusted. What that bound is — and whether other cells truly
eat each other or the ecosystem is abstracted — is §1.3.

**One consequence worth naming here rather than discovering in play:** because
gape and growth are both live, a cell you decided to ignore can become a cell
that eats you **without leaving the screen**. Its lip bow changes from green to
red in front of you (§1.1.1) the moment it crosses your radius. Nothing else in
the game changes state that way, and it is the strongest argument for drawing the
relationship rather than only the measurement.

### 1.3 Real where you can see it, a distribution where you cannot

A true ecosystem is a simulation that drifts. Left to run, it has three endings
and two of them are bad: it eats itself down to a few giants and the player
starves with nothing edible in reach; or nothing ever eats anything and the
water is inert; or one cell runs away with it. None of those announce
themselves — the run just quietly stops being a game.

So the rule is split by what can be observed:

**Inside the field, cells genuinely eat each other.** Same gape rule, same
growth, no special case for the player. In full vision you can watch a cell
close on a smaller one and come away bigger, and the cell that just ate is now
a cell you may no longer be able to eat. That is real, and it is the thing the
owner asked for. Unchanged, and the best idea in this document.

**Outside the field, nothing is simulated at all.** Cells are culled at
`food.CULL = 3000` and recycled to a ring at `RING_MIN 800 … RING_MAX 2200` —
shipped Phase 4 behaviour. (The previous draft cited `CULL = 1900`; that is
`motes.gd`, the inert dust, which is a different field and does not carry genes.)
The only change is **what a recycled cell comes back as.**

> **The previous draft said "a distribution centred on the player's current
> radius" and stopped there. That is not a bound, and it does not survive
> arithmetic.** Three things are wrong with it and all three are checkable.
>
> **It has no parameters, so it is not one design but a family of very different
> games.** Sampling `rho = arrival.radius / player.radius` uniformly about 1.0,
> with every cell at cytostome 1 and the player likewise:
>
> | spread | eat it | it eats me | both | **neither** |
> |---|---|---|---|---|
> | ±25% | 14% | 6% | 0% | **80%** |
> | ±40% | 28% | 22% | 0% | **50%** |
> | ±50% | 32% | 28% | 0% | **40%** |
>
> With `food.COUNT = 4`, a ±25% spread puts **0.6 edible cells in the entire
> field** against a 420-second hunger clock that wants a meal every 60–90s. The
> newborn cell starves surrounded by food it cannot fit in its mouth. Let the
> arrivals' cytostome tier vary 1:1:1 instead and the numbers invert: **50% of
> everything can eat you, permanently, at every radius.**
>
> **A player who does not grow cannot start.** At cytostome 1 the gape is
> `0.82 r`, which is *below* your own radius — so a distribution whose mode is
> your own radius puts its mode in the inedible zone. The failure is a loop: you
> cannot eat because you have not grown, and you cannot grow because you cannot
> eat. That is precisely the unwinnable state the section claims cannot exist.
>
> **And a player who grows fast gains nothing.** Every quantity in §1.1 is a
> ratio, so if arrivals scale with the player the ratio distribution is
> *invariant*: the fraction of the water you can eat, the fraction that can eat
> you, and the fraction that is a standoff are identical at your 1st meal and
> your 14th. **Rendered side by side — the born cell against its peers, and the
> full-grown cell against its peers — the two frames are the same picture at two
> zoom levels.** That is the rubber-band failure in one image, and it silently
> breaks three other claims in this document: §3.1's "the genome fills up at the
> moment you outgrow the thing that has been hunting you", §6's "it goes quiet
> when you outgrow the predator", and Phase 4's dread falling off with the size
> ratio. None of them can ever fire.

**The bound that does work: a floor that never moves, a middle that tracks you,
and a ceiling you can reach.** One seeding function, three constants, and a
coin flip:

```gdscript
# food.gd _seed() -- replaces RADIUS_MIN/RADIUS_MAX
const DRIFTER_SHARE := 0.45     # of arrivals, drawn absolutely
const DRIFTER_MIN := 13.0       # the Phase 4 food band, unchanged
const DRIFTER_MAX := 21.0
const PEER_SPREAD := 0.34       # of the player's radius, drawn relatively

## The ceiling is on the GAPE, not on the body. A seeded cell takes its radius
## from the draw, then has its cytostome tier reduced until it fits. 40.0 is the
## top of the slot ladder -- see section 3.1.
const ARRIVAL_GAPE_MAX := 40.0
const ARRIVAL_RADIUS_MAX := 40.0
```

- **Drifters — the floor.** Just under half of all arrivals are `r 13–21` with
  **no cytostome** (gape `0.58 r`, so at most 12 — they eat nothing, including
  each other). They are Phase 4's food cells, kept exactly as they are. They are
  edible at *every* player radius and at every cytostome tier, so **there is
  always a way back from a bad run, and it does not depend on tuning.** As you
  grow they get relatively smaller and safer, which is the felt reward for
  growing that the relative-only version deletes.

  **Make the floor a guarantee, not a probability.** `food.COUNT` is 4, so a
  0.45 coin lands zero drifters in the whole field about 9% of the time. One
  counter fixes it: *if seeding this cell would leave no drifter in the field, it
  is a drifter.* "The world cannot degenerate" then stops being a statistical
  claim and becomes an invariant, which is the only kind worth writing down.
- **Peers — the middle.** The rest are `player.radius * (1 ± PEER_SPREAD)` with a
  real genome, clamped to the ceiling. These are what keep pace, and they are
  where danger and the mutual band live.
- **The ceiling — the ending.** Capping the *gape* rather than the body is what
  makes the arc land on the number the slot ladder already uses. **At radius 40
  nothing in the water can swallow you**, because nothing in the water has a gape
  above 40 — which is the exact meal at which the genome fills. Dread stops
  arriving, and that is the readout that the run is won.

  **The ceiling binds what the water seeds, not what a cell becomes.** §1.2 lets
  every cell grow by eating, and growth is not clamped — a body that has been
  feeding passes `ARRIVAL_GAPE_MAX` and keeps hunting. The first draft did not
  notice that §1.2 and §1.3 contradict each other here, and the build measured
  it: bodies at gape 45.4 and 40.8, and a field cell reaching `r41` with the
  arrival ceiling at 40.

  **Settled by the owner: it stays unclamped, and it is the feature rather than
  the bug.** At radius 40 the *seeded* water goes quiet, which is the readout
  that the run is won; the only thing that can still threaten a full-grown cell
  is one that earned it by eating, in view, on the same rules. That is §9.8's
  legendary organism arriving for free, with no boss authored and no second
  system — and it is why the ending is a floor rather than a ceiling. The
  alternative was rejected on its cost: the only way to enforce an absolute
  ceiling is to take a cytostome tier *off* a living cell, and §4.3 draws that
  tier on the body, so the enforcement would read to the player as a rendering
  glitch.

  It needs no new art. §1.1.1 already turns the lip bow `PREDATOR_TINT` and adds
  teeth whenever `other.gape > my.radius`, so an over-ceiling feeder is drawn as
  exactly what it is the moment it becomes dangerous.

  Capping the gape also shapes the population for free, with no second constant:
  a radius-40 arrival can carry at most `cytostome 1` (`0.82 x 40 = 33`), while a
  radius-28 one can carry `cytostome 3` (`1.40 x 28 = 39`). **Big bodies get small
  mouths and small bodies get big mouths**, which is precisely the mix that makes
  §1.1 worth reading, and it falls out of one clamp rather than being authored.

**What the build measured against these numbers.** Two claims did not
survive contact and are corrected rather than quietly retuned:

- **§1.3's rendered table said `edible` moves 1 → 5 as you grow. It does not.**
  Measured over 16,000 seeded bodies, `edible` is flat near 60% at every player
  radius, because the drifter floor is half the water and edible at all sizes.
  What growth actually changes is **danger**: `eats me` falls 19% → 7% → 0% at
  r26 / r33 / r40, and `standoff` rises 17% → 34% → 38%. The two frames are
  still two different pictures — the axis is danger, not menu.
- **§7.2's `flagellum` ladder understates the top.** Measured straight-line net
  speed by tier is **41.0 / 56.8 / 80.1 / 111.1** u/s, not the ~78 the text
  extrapolated for tier 3. Tier 1 reproduces Phase 4's measured 56.5 exactly, so
  the constants are right and only the prose arithmetic was wrong. Phase 6
  re-measures the chase against this.

**Rendered, at both sizes, with §1.1.1's threat colour on.** The same seeded
water drawn against a born cell (`r26`, gape 21) and against a full cell (`r40`,
gape 32):

| | edible | can eat me | standoff |
| --- | --- | --- | --- |
| player `r26` | 1 | **1, drawn red** | 4 |
| player `r40` | 5 | **0** | 1 |

*One field of four is a small sample, and the `edible` column of it was
misleading — see the measurement above, taken over 16,000 bodies. The `can eat
me` column is the one that holds, and it is the column that matters.*

**The two frames are different pictures, which is the whole point** — put the
old rule's two frames beside them and they are the same picture at two zoom
levels. Growth now changes what the water is, not just how big it looks.

The three original claims now hold, for a reason rather than by assertion:

- **The world cannot degenerate** — because the drifter floor is absolute and
  does not consult the player at all.
- **Difficulty tracks growth** — because the peer band does, up to a ceiling
  that lets it stop. Tracking without a ceiling is not difficulty, it is
  rubber-banding.
- **It is cheap** — two draws and a `randf()`, in the function that already
  reseeds a culled cell.

**`TIER_WEIGHTS`, then `DRIFTER_SHARE`, `PEER_SPREAD`, `ARRIVAL_GAPE_MAX`** are
the numbers to move if the water feels wrong, in that order.

`TIER_WEIGHTS` is the one this section did not name and the one that matters
most. The text above reads as though `GENE_WEIGHTS` covers the cytostome
distribution inside the peer band, and it does not: that constant is per *gene*,
and says nothing about how good a mouth an arrival gets. The build had to invent
the missing one, `[0, 3, 2, 1]` over tiers 0-3, weighted so most cells are
mediocre and a few are terrifying. Measured over 16,000 seeded bodies it puts
**19% of the water able to eat a born cell at r26**, falling to 7% at r33 and 0%
at r40. Uniform tiers instead would put about half the water above you
permanently. It is one line and it is most of the difficulty curve.

**One knob is deliberately left open: the cytostome weights inside the peer
band.** How dangerous the water is turns almost entirely on them — with peers
uniform over tiers 1–3 about half of everything can eat a born cell, and with
peers mostly at tier 1 almost nothing can — and it is not a thing a still frame
can answer. Ship the same `GENE_WEIGHTS` the drop table uses (§3.4) and treat it
as the first dial after the three above. See §9.

**What this deliberately is not.** There is no persistent world, no lineage, no
species that remembers. A cell you flee from and never see again does not go on
existing. That is invisible from inside the game — you cannot observe the
absence of a thing you are not looking at — and it is the difference between a
phase that ships and one that becomes a research project.

## 2. The tension: point of view cannot see its own cilia

The viewport is the inside of the body. Cilia are a full-vision readout. So in
point of view the player can neither look at what they can do nor look at a prey
cell and read its gene.

**This is resolved by not solving it in the same place three times.**

> **Owner override, Phase 6: the premise above is partly withdrawn.** Point of
> view now draws the player's own body — the ovoid, the fringe and the gape, at
> `SELF_TINT`, faint, at the centre of the screen, always, with no gene behind
> it. `game/perception/soma.gd`.
>
> The reason is that a screen with nothing at all on it is disorienting rather
> than tense, and this phase makes that worse: taste stopped being innate and
> went behind `chemocyte`, so the opening minute of a run had no signal in it
> whatsoever. A blind cell needs a frame of reference, and the least invented
> one available is the only object it is entitled to know about with no organ at
> all — itself. What it shows is bounded by that: shape, heading, organs, tiers.
> Nothing about the water, nothing about any other body, no position of
> anything. Proprioception, not a minimap.
>
> **§2.1 to §2.4 still stand and are not rewritten.** Feeling a tier through
> thrust, shear and the flood is the only channel that works while you are
> actually moving and looking at the contour, and it is worth having whether or
> not there is a figure in the middle of the screen. §2.4's mirror argument
> loses its *necessity* and keeps its *content*: the pause strip is still the
> only surface that can say which slot a gene is in and what a tier is worth in
> words, and the figure is deliberately hidden while the pause screen is open —
> the column is centred and so is the body, and the light slider ran straight
> through the cilia.

### 2.1 What you can do — you already feel it, and always have

The three starting cilia are not new capabilities. They are `metabolism.gd` and
`cell.gd`, which have shipped since Phase 2. And the membrane has been drawing
all three since Phase 1, in its self-register:

| organ | what it is in code | what point of view already feels |
| --- | --- | --- |
| **`cytostome`** *eat* | `metabolism.beat_period/amplitude` | the metabolic beat |
| **`cirrus`** *turn* | `TURN_RATE_MAX`, `TURN_RESPONSE` | the turn shear on the outside of the turn |
| **`flagellum`** *swim* | `IMPULSE_SPEED`, `IMPULSE_GAP_*` | the thrust bloom at bearing 0° |

So the retrofit is the discovery that **the membrane's three self-signals and
the cell's three cilia are the same three organs seen from inside and from
outside.** Nothing new is needed in point of view to express ability — a tier
change is a change in the sensation the player already knows:

| gene | tier 0 | tier 1 | tier 2 | tier 3 | uniform |
| --- | --- | --- | --- | --- | --- |
| `flagellum` | bloom 0.10 / 68° | 0.14 / 60° | 0.19 / 52° | 0.25 / 44° | `glow_lobes[0]` (`THRUST_PEAK_BY_TIER`, `THRUST_HALFWIDTH_BY_TIER`) |
| `cirrus` | shear 0.07 | 0.10 | 0.14 | 0.19 | `glow_lobes[0]` (`SHEAR_PEAK_BY_TIER`) |
| `cytostome` | flood decay 1.0s | 1.2s | 1.5s | 1.9s | `INGEST_DECAY_BY_TIER` |

No new shader term, no new lobe, no HUD. A `flagellum`-specialised cell feels
its own push harder and more sharply; a big mouth savours the meal longer.

**Tier 0 is added by the build**, because §9.7 lets a fourth gene go over any of
the three and the first draft's table stopped at tier 1. It is not designed: it
is extrapolated one step below tier 1 on each ladder's own spacing, which is
what `cell.gd`'s drive tables already do and the least invented answer there is.

**How the tiers reach the bus.** One call a frame, `organs(cytostome, cirrus,
flagellum, stigma)`, beside `set_beat` — a continuous property of the body that
shapes the discrete events, rather than an argument riding on each one. That
keeps `thrust()`, `shear()` and `ingest()` about the sensation, which is what
the audio and haptics subscribers downstream of `sensation` will be reading, and
it is where the `stigma`'s lobe width comes from too. `normal_mode.gd` remains
the only node that talks to the bus. Four integers about this cell's own anatomy
are not a fact about anything else in the water, so `perception.md`'s "never an
identity" is untouched.

> **One thing the build had to check rather than assume: where the `cirrus`
> tier lands.** `cell.gd`'s `shear_rate()` returns demand-or-rotation normalised
> to `-1 … 1`, so it is the *same number at every tier* — which reads like a bug
> that makes this row a no-op, and is not. The table above is the whole of the
> difference, and it works: measured off the composed lobe at full steer, the
> shear peaks at **0.067 / 0.096 / 0.135 / 0.183** across tiers 0-3 against a
> designed 0.07 / 0.10 / 0.14 / 0.19. De-normalising `shear_rate()` as well
> would count the tier twice and put a tier-3 cirrus at 0.31, 58% over the
> number this section specifies. The normalisation stays.

### 2.2 What you just ate — the flood is the gene's colour

`food-and-predators.md` §3.4 already reserved this: *"`ingest_color` is already a
uniform, so a gene can tint the flood."* Phase 5 spends it.

The interior flood is `perception.md`'s one licensed exception, it lasts 1.2s,
and it is a *contact* event — chemistry you have absorbed, which is the one
moment a cell could plausibly tell what something was. It is also the only place
a gene is ever identified on the sensory screen.

> This is a deliberate, narrow breach of "never an identity". It is bounded to
> the one signal `perception.md` already exempted and to the one frame where
> the thing is inside you. Do not let it spread to the band.

Rendered, amber (`stigma`): interior centre **`(99, 88, 41)`**, against the
nutrient green flood's `(39, 98, 52)`. The rim survives the flood at
`(33, 121, 98)`, as in Phase 4.

### 2.3 What is out there — point of view does not get to know, deliberately

**Full vision plays selective foraging; point of view plays opportunistic
foraging.** You swim at the bearing your skin gives you and you take what is
there. That is the honest consequence of the premise, and it is the first time a
view's information advantage has become a strategic one.

> **Owner override, Phase 6: two senses now return a place, and point of view
> draws it.** `game/perception/returns.gd`, a third point-of-view layer beside
> the membrane and the soma figure.
>
> - **`ocellus` — the pointer.** Where a beam is *stopped* by a body, the hit
>   point is drawn in the water at the place it landed. Only when the beam is
>   stopped, and only when that place is on screen: a beam that runs its whole
>   reach into open water draws nothing, because the beam's existence is not the
>   return. It restores the gene's original brief — *"you don't see nothing but
>   the point where the laser touches something"* — which the shipped build had
>   lost to a glow lobe that gave a direction and never a place.
> - **`ampulla` — the wave.** The expanding wavefront is drawn in point of view
>   the way full vision already draws it.
>
> **Why this is not a hole in the premise.** A beam that is stopped has
> genuinely *measured* where a surface is; that is the difference between it and
> every other sense in the game, and it is what the player spent a slot on. A
> pulse is a thing this cell emitted, so this cell knows where its own
> wavefront has got to. Both are returns the organ actually came back with.
>
> **What must not follow them in**, and the list is the whole of the override's
> boundary: bodies, silhouettes, the scent bloom, wounds, threat colouring,
> ping returns, anything a sense did not touch. Only the returns themselves. If
> the layer ever draws a cell it has gone past the line.
>
> **"One simulation, two views" is untouched.** This is a drawing change: the
> marks are read out of `food.gd` by the view, exactly as `vision.gd` reads
> them, and no position reaches the signal bus — `normal_mode.gd` is still the
> only node that talks to it and it still carries bearings and intensities
> alone.
>
> **The membrane keeps its lobes.** The marks are drawn at
> `soma.gd`'s SCALE of 1.7 canvas px per world unit, because the figure is the
> only object on that screen with a known size and a mark at any other scale
> makes *"two body-widths ahead"* a lie. That puts the full-strength limit at
> 134 world units dead ahead, 299 abeam at 1280x720 and 393 abeam at 2400x1080,
> against a tier-2 beam's reach of 900. Measured over a minute of foraging with
> a tier-2 `ocellus`: 119 hits, 27 of them (23%) drawn at full strength and 35
> (29%) drawing a mark at all. So the lobe is not redundant: **it is the
> approach instrument and the pointer is the arrival instrument**, and a return
> that has scrolled off screen still has a bearing worth having. It is also a
> *sensation*, which is
> what audio and haptics will subscribe to; deleting it would change what the
> cell feels, and that is the one thing the two-views rule forbids.
>
> The two never agree by *angle*, and should not be expected to. The shader
> measures bearing on an aspect-corrected ellipse, so its 45° lands in the
> corner of whatever screen it is on; a position cannot be drawn in that space
> without distorting the distance. At 1280x720 a 45° mark sits about 16° off its
> own lobe, and about 21° at 2400x1080. They agree by quadrant and by which way
> to swim, which is what they are for.
>
> **One thing the render caught.** Bodies in this water overlap — being eaten
> and eating both happen at nought distance — and a beam is cast from the centre
> of the cell, so a body pressed against you returns a distance shorter than
> your own radius. Drawn honestly at that distance the pointer lands on the
> soma's nucleus. A minute of foraging put two of them there. A mark is now
> suppressed inside the body's own outline and fades in by 1.3 radii: a place in
> the water that is *inside you* is not a place you can do anything with, and
> contact already has three senses of its own.
>
> §2.3's argument below still stands for everything else. Neither of these
> senses tells you *what* the thing is, so the chemoreceptor-discrimination slot
> is still open and identity is still not something point of view can have.

Two things keep it from being a punishment:

- **The advantage is smaller than it sounds.** Measured: at ZOOM 1.0 the visible
  world is ±640 x ±360 world units at 1280x720 and ±800 x ±360 at 2400x1080.
  `food.BEARING_RANGE` is 680, so when the taste bearing first resolves the food
  is usually still off-screen. Full vision's real advantage is *"the wash points
  that way — is it worth going?"* over the last few hundred units, not a menu.
- **It is a gene's job to close the gap, and that is now a designed slot rather
  than a hole.** A later *chemoreceptor discrimination* gene lets the band
  distinguish flavours, giving point of view gene identity at range. Reserve it;
  do not build it now. It is exactly the kind of thing `perception.md` §4 said
  later genes should sell.

### 2.4 What am I — the mirror, on pause

Both modes read their genome on the pause screen (§5). That is also where a
point-of-view player learns the cilia vocabulary, because the slot tiles draw
the organ. If they ever switch views, the language is already theirs.

**You can look at yourself in the mirror; you cannot look at yourself while you
are swimming.**

## 3. The genome

### 3.1 Slots come from size

```gdscript
# cell.gd
const BASE_RADIUS := 26.0
const GROWTH_PER_MEAL := 1.0    # was 0.5 -- food-and-predators.md §9.3 gave
                                # this to Phase 5 as a placeholder
const SLOT_RADIUS := 3.5        # one more slot per this much growth
const SLOT_MIN := 3
const SLOT_MAX := 7

func slots() -> int:
    return clampi(SLOT_MIN + int((radius - BASE_RADIUS) / SLOT_RADIUS),
        SLOT_MIN, SLOT_MAX)
```

| radius | slots | meals |
| --- | --- | --- |
| 26.0 | 3 | 0 |
| 29.5 | 4 | 4 |
| 33.0 | 5 | 7 |
| 36.5 | 6 | 11 |
| **40.0** | **7** | **14** |

`SLOT_MAX = 7` is not arbitrary: the body has exactly seven arcs (§4.1), and 40
is `ARRIVAL_GAPE_MAX` — the widest mouth the water ever produces (§1.3). **The
genome fills up on the same meal that nothing left in the water can eat you.** (The previous draft anchored this to
`predator.RADIUS = 40`, a constant §7.0 deletes; the ceiling is what carries the
claim now.) At Phase 4 foraging rates — a meal every 60–90s — 14 meals is a
**14–21 minute arc**: a session, not a campaign, which is right for a game with
no save.

**"The run ends" is about this water, not about the game.** Radius 40 is where
*this* water runs out of things that can eat you; it is not a ceiling on the
species or a claim that a full genome is finished content. See §9.8, which the
owner attached to this decision and which binds how `ARRIVAL_GAPE_MAX` is
written.

### 3.2 A gene has a tier, and tiers cost upkeep

Eating a cell whose dominant gene is X (§3.4):

- **X not held, a slot free** → integrates at tier 1, immediately, no screen, no
  pause. The flood is X's colour and the cilia grow in over `GROW_SECONDS = 2.5`.
  This is the whole early game and it teaches the vocabulary by accident.
- **X already held below tier 3** → tier +1. Free, automatic.
- **X already at tier 3** → nutrition only. No sample, no echo.
- **X not held, no slot free** → the sample is **held** (§3.3). Nothing blocks.

**Every tier above 1 raises the metabolic rate.** This is the price of power and
it is paid in the channel the game already reads:

```gdscript
# genome.gd -- a new plain Node. It computes and does not post, exactly like
# food.gd and predator.gd; normal_mode.gd is still the only node that talks to
# the bus, and it is what carries this number across.
const UPKEEP_PER_TIER := 0.18

func upkeep() -> float:
    var extra := 0
    for tier: int in _slots.values():
        extra += maxi(tier - 1, 0)
    return 1.0 + UPKEEP_PER_TIER * float(extra)

# metabolism.gd -- one new public var, written once a frame by the run, exactly
# like `concentration` already is. The hunger mapping stays in this one file.
var upkeep := 1.0
# _process: set_hunger(hunger + delta * upkeep / HUNGER_SECONDS)

# normal_mode.gd _process, beside the existing read-once-post-once block:
_metabolism.upkeep = _genome.upkeep()
```

A cell with one tier-3 gene starves in 420 / 1.36 = **309s**; a late cell with
`cytostome 2, cirrus 3, flagellum 3, stigma 2` in 420 / 2.08 = **202s**.
Upkeep needs no number on screen: it is read off the beat, which has been the
hunger readout since `perception.md` §6.2.

> **Two things the previous draft claimed about this economy are false, and the
> arithmetic is short enough to check here.** The unit that matters is not
> "how long until I starve" but **how many seconds of life one meal buys**,
> `420 * MEAL / upkeep`.
>
> | build | upkeep | `MEAL` | seconds bought per meal |
> |---|---|---|---|
> | born, `cytostome 1` | 1.00 | 0.50 | **210** |
> | `cytostome 2` | 1.18 | 0.62 | **221** |
> | `cytostome 3` | 1.36 | 0.78 | **241** |
> | `cytostome 1, cirrus 3, flagellum 3` | 1.72 | 0.50 | **122** |
> | `cytostome 2, cirrus 2, flagellum 2, stigma 2` | 1.72 | 0.62 | **151** |
>
> **The mouth is free and everything else is expensive.** If `cytostome` tier
> raises `MEAL` as well as the gape, every tier of it *increases* your slack
> after upkeep — and it simultaneously widens the menu. It is a strictly dominant
> gene and there is no reason to ever put anything else in a slot until it is at
> 3. And the line "the specialist eats constantly and moves; the generalist is
> slow and lives" is backwards: the generalist buys the **fewest** seconds per
> meal of any sensible build.

**The fix, and it is one line: `MEAL` leaves the tier table, and a meal is worth
what it weighs.** `cytostome` tier buys the gape and nothing else:

```gdscript
# metabolism.gd
const MEAL := 0.50   # unchanged, and now the value of a meal your own size
# normal_mode.gd, on eaten():
_metabolism.feed(MEAL * clampf(prey.radius / cell.radius, 0.35, 1.40))
```

Measured against **your own body**, not against your gape — that distinction is
the whole fix. Against the gape, every cytostome tier would normalise away and a
wider mouth would buy no bigger dinner. Against the body, a wider mouth lets you
*reach* a bigger dinner, and you have to go and take it:

| what you eat | `cytostome 1` (upkeep 1.00) | `cytostome 3` (upkeep 1.36) |
|---|---|---|
| a drifter at `0.5 r` — safe | **105s** | **77s** |
| the biggest thing your gape allows | **172s** (at `0.82 r`) | **216s** (at `1.40 r`) |

**`cytostome` stops being dominant and becomes conditional.** A big mouth is a
loss if you keep eating drifters and a win only if you use it — and using it means
eating bodies near your own size, which by §1.1 are exactly the ones whose own
mouths may take you. The tier is now a bet on your nerve rather than a free
upgrade, and the timid player is correctly punished for buying it.

It also puts a **reward on the risk axis §1.1 created.** With a flat `MEAL` the
optimal play was always to eat the smallest thing in sight — that is, to avoid
the entire mechanic the phase is built on. And it makes growth legible: a big
meal fills more of the bar, and the bar is the beat.

`GROWTH_PER_MEAL` stays flat at 1.0 — radius is the slot ladder and the slot
ladder should be a count of meals, not a count of calories. The economy answers
*"was that worth it"*; the ladder answers *"how far along am I"*, and they should
not be the same number.

### 3.3 A held sample is a second heartbeat

The one new point-of-view signal Phase 5 adds, and the answer to "how does a
player with no HUD know a decision is waiting".

A sample is held for `SAMPLE_SECONDS = 45.0`. While it is held, **each metabolic
beat is followed by a smaller second one**:

```gdscript
const HELD_ECHO := 0.44          # of beat_strength()
const HELD_ECHO_DELAY := 0.58    # seconds after the beat
const HELD_FADE := 15.0          # the echo weakens over the last 15s

# in _step_beat, after pulse_now():
if held_sample != &"":
    _echo_at = HELD_ECHO * minf(remaining / HELD_FADE, 1.0)
    _echo_in = minf(HELD_ECHO_DELAY, 0.34 * _beat_this_period)
```

- **It is teal, not the gene's colour.** `perception.md`'s rule stands: the
  contour carries bearing and intensity, never identity. The echo says *there is
  something in you that is not resolved*, and nothing else.
- It costs **no interior** — `perception.md` §4's "the interior is currency" is
  not spent here; that is still reserved for the gene that buys a true image.
- It costs no new uniform: it is `pulse_now(HELD_ECHO)` on a delay.
- It survives dread and starvation, because it is **rhythm**, which
  `food-and-predators.md` §5.1 established as the channel that survives
  everything.
- 0.58s clears `PULSE_ATTACK + PULSE_DECAY = 0.51s`, so the two pulses are
  separate. Below a 1.7s beat period the delay compresses and at rich-food
  periods (0.55s) the two merge into a flutter. That is acceptable: it is still
  not the normal rhythm. Do not add a second uniform to fix it.

In full vision the same state is drawn literally: a disc of radius `0.16r` in
the gene's hue inside the body, offset `0.30r` to port of the nucleus, pulsing
on the beat and shrinking with `remaining`.

> **The disc is retired; see `diegetic-hud.md`.** The owner played a run, was
> given a gene and never saw it: the echo is a rhythm nobody has been taught to
> read, and the disc is one small mark inside a 60px body. Both views now draw
> the sample as a vesicle adrift, a tuft of the organ it would become floating
> clear of the skin, and a thread between them — through one routine that point
> of view and full vision both call. **The echo in this section stands and is
> unchanged**; what changed is that it now has a picture to belong to, and the
> two are already synchronised because `soma.beat` is `_bus.pulse()`, which the
> echo pumps. `HELD_FADE` here and `HELD_WILT` there must stay equal.

If the sample lapses it is simply gone. There is no discard control and there
does not need to be one.

### 3.4 Where the gene comes from — the body, not a roll

> **Contradicts `food-and-predators.md`**, which called this "the gene roll on
> eating". A roll cannot be seen in advance, and informed foraging requires that
> it can. **A cell's genome is fixed when it is seeded**, and full vision draws
> it.

```gdscript
# food.gd -- weights, drawn in _seed()
const GENE_WEIGHTS := {&"cytostome": 3, &"cirrus": 3, &"flagellum": 3, &"stigma": 2}
```

**A cell has a genome, not a gene, so a meal has to say which one you get.**
§1 requires this — every cell needs a `cytostome` tier or it has no gape — and
the previous draft left it open, which an engineer cannot.

> **You absorb what the cell was most made of: its highest-tier gene.** Ties are
> broken by the arc order in §4.1 — `cytostome`, `cirrus`, `flagellum`, then
> earned genes in genome order — so it is deterministic and it is the same order
> the body is drawn in.

That is the right answer rather than merely a workable one, because the dominant
gene is also **what the cell looks like**: it is the longest, densest, brightest
fringe on the body, and §4.5 makes it the body's tint. What you can see before
you commit is exactly what you get. A cell that is all tail gives you `flagellum`.

`eaten(nutrition, gene, at)` already exists with exactly this signature and
`normal_mode.gd` already forwards it. Phase 5 fills `gene` with the dominant and
removes the `push_warning` guard. No refactor.

## 4. Cilia

### 4.1 Seven arcs, three of them spoken for

Cilia are placed by the **ovoid's own parameter `t`**, not by bearing, because
the body is already drawn that way (`vision.gd`, `OVOID_STEPS`: along `cos(t)`,
across `sin(t) * (1 - 0.30 * cos t)`, scaled `1.18r` x `0.94r`).

| arc | `t` (deg) | bearing (deg) | occupant |
| --- | --- | --- | --- |
| anterior | −42 … 42 | ±29 | **`cytostome`** |
| lateral, starboard | 66 … 118 | 58 … 120 | **`cirrus`** |
| lateral, port | −118 … −66 | −120 … −58 | **`cirrus`** |
| posterior | 146 … 214 | 146 … 214 | **`flagellum`** |
| free 1 | 42 … 66 | 29 … 58 | earned |
| free 2 | −66 … −42 | −58 … −29 | earned |
| free 3 | 118 … 146 | 120 … 146 | earned |
| free 4 | −146 … −118 | −146 … −120 | earned |

Earned genes fill the free arcs in genome order. Three home arcs plus four free
arcs is `SLOT_MAX = 7`.

**The free arcs are also the bearing rose.** While empty they are visible gaps at
roughly the four diagonals, which is a 45° reference read off the organism
rather than painted over it.

> **The 32-cilium rose in `vision.gd` is retired.** It was a protractor of 32
> even cilia with four bright cardinals. Measured: under a tier-2 fringe the
> pale cardinal ticks are invisible at both sizes, and the fringe now carries
> meaning that a protractor laid over it only muddles. The bearing checks full
> vision exists for are drawn as *rays from the cell* (`_draw_hits`,
> `_draw_wakes`) and are their own instrument.

### 4.2 Geometry, at tier 1

All lengths are fractions of the body radius `r`, so a grown cell is not a small
cell with stubble. `clock` is `vision.gd`'s `_clock`; `u` runs 0→1 across the
arc; strokes are `draw_polyline` in world space.

| | **`cytostome`** | **`cirrus`** | **`flagellum`** | **earned** |
| --- | --- | --- | --- | --- |
| count | 15 across the arc | 5 per side | 6 | 4 |
| root | surface + `0.06r` | surface | surface | surface |
| length | `0.27r x (0.80 + 0.30w)` | `0.34r x (0.86 + 0.22c)` | `0.62r x (0.82 + 0.26s)` | `0.30r x (0.88 + 0.14s)` |
| width | 1.3 | 2.0 | 1.8 | 1.6 |
| alpha | 0.62 | 0.66 | 0.62 | 0.72 |
| points | 3 (curved inward) | 3 (bent oar) | 6 (travelling lash) | 2 (stiff) |
| motion | metachronal wave `w = sin(u·7.4 − clock·5.6)`, swing ±26°·w toward the nose | `phase = clock·2.4 + (0 or π) + u·0.9`, swing ±30°·sin(phase); the two sides are in **antiphase** | `lash = sin(v·3.0 − clock·5.2 + u·0.45) · length · 0.26 · v` along the stroke | none — a sensory cilium does not row |

The **earned** gene also carries a pigment organelle: filled discs of `0.20r` at
alpha 0.55 and `0.10r` at alpha 0.85, seated at `surface(r * 0.80, mid_t)`, over
three haze rings at `0.30r x (1 + 1.6q)`, alpha `0.030(1 − q)`.

**The `cirrus` leans with the steer.** The outboard side of the turn works harder:
`bias = 1.0 + 0.55 * clamp(-steer * side, -1, 1)` on the swing. This is a motion
cue, not a still-frame cue — it does not show in a screenshot and is not claimed
to.

### 4.3 Tier is magnitude, not a badge

```gdscript
const TIER_LEN:   Array[float] = [0.0, 1.00, 1.22, 1.46]
const TIER_COUNT: Array[float] = [0.0, 1.00, 1.35, 1.70]
const TIER_ALPHA: Array[float] = [0.0, 1.00, 1.12, 1.24]
```

Longer, denser, brighter. Countable without counting. Rendered at r26 and r40:
tier 1 against tier 3 is unmistakable in every arc.

### 4.4 Hues

| gene | `Color(r, g, b, a)` | wheel |
| --- | --- | --- |
| **`cytostome`** *eat* | `Color(0.62, 1.00, 0.38, 1)` | 95° |
| **`cirrus`** *turn* | `Color(0.36, 0.62, 0.98, 1)` | 216° |
| **`flagellum`** *swim* | `Color(0.80, 0.42, 0.95, 1)` | 291° |
| **`stigma`** *see* | `Color(0.98, 0.78, 0.30, 1)` | 45° |
| *reserved* | `Color(0.48, 0.42, 0.95, 1)` indigo | 250° |
| *reserved* | `Color(0.94, 0.42, 0.68, 1)` rose | 333° |

Rules for the next designer: a new gene hue must sit **≥30° from every other
gene hue** and **≥40° from self teal `(0.12, 0.70, 0.58)` and threat red
`(0.78, 0.24, 0.30)`** — the red that was the predator's body in Phase 4 and is
the dangerous lip bow in Phase 5 (§1.1.1). It is reserved, not retired.

**Feed breaks the first rule on purpose.** It is deliberately in the nutrient
green family, because the mouth *is* nutrition and the taste lobe is already that
green. It is brighter and yellower than both `FOOD_TINT (0.35, 0.88, 0.42)` and
the green-tinted body of a cytostome-dominant cell (§4.5), so it separates from
whatever it sits on — rendered at 1x, it does. It is the
least legible of the four at range and its positive tell is texture: `cytostome` is the
only dense fine mat.

> **Measured colour-blindness check.** A Viénot deuteranope simulation of the
> render collapses cytostome-green and stigma-amber onto the same yellow, and
> brings cirrus-blue and flagellum-orchid close. **On a body this does not matter** — a
> luminance-only render separates all four by arc, length and density with no
> ambiguity. It matters in exactly two places, and both are handled: every cell
> wears the organ as well as the hue (§4.5), and genome slots are labelled with a
> word (§5.2).
>
> **§1.1.1's threat red is a third place and it is the only one where colour
> genuinely fails.** Green lip bow and red lip bow are the same shape in the same
> place with opposite meanings; simulated, they collapse to one hue and the
> dangerous one is the darker. That is why the threat bow carries teeth. The rule
> the next designer should take from this is not *"check the hues"* — it is
> **any signal whose opposite is drawn on the same shape must differ in shape,
> not only in colour.**

### 4.5 One routine, one subject

> **Rewritten.** The previous draft was called *"Food and the predator wear cilia
> too"* and specified a food species drawn at fake tier-2 geometry and a predator
> hard-coded to `{flagellum: 3}` on a red body. §1 deletes both species, so both
> paragraphs described objects that no longer exist. The tier is information now
> and cannot be faked, and the red body has moved to the mouth (§1.1.1).

**Every cell in the water is drawn by the same routine from its own genome, at
its own tiers, plus its gape.** The player's cell included. There is no second
code path and no species branch, which is the whole reason §7.0 collapses two
files into one.

Three things the single routine has to be told, none of which were written down:

- **Body tint.** A cell's fill and rim are `SELF_TINT (0.12, 0.70, 0.58)` lerped
  **0.55** toward its dominant gene's hue (§3.4), so the largest coloured area on
  screen agrees with the fringe rather than fighting it. **The player's own cell
  is always pure `SELF_TINT`** — you are the one cell in the water whose identity
  you do not have to read. Rendered: a `flagellum`-dominant cell is a cold
  violet-grey, a `cytostome`-dominant one is green, and neither is mistakable for
  the player.
- **Nothing is clamped for small bodies, and the render says why.** Cilium
  lengths are fractions of `r`, so on a `r13–21` drifter a tier-1 fringe is a
  4px stub. The obvious fix is a minimum stroke in canvas px; **it was built and
  photographed and it is a no-op** — at `r14` the clamp moves a 3.8px stroke to
  4.5px and the frame is indistinguishable. Do not spend a constant on it.
  What the render shows instead is the useful division: at drifter size **the
  tier stops being readable and the gape does not**, because the gape is one long
  stroke (`2 x gape` is 23px at `r14` tier 1 and 39px at tier 3) while the tier is
  a 4px fringe. That is the right way round — the gape is what decides the
  encounter, the tier is only how the gape got that way — so it is a property to
  keep, not a defect to fix.
- **Drifters have no cytostome at all** (§1.3), so they draw no anterior mat and
  their lip bow is `SELF_TINT` at alpha 0.30 — effectively absent. **"No green at
  the nose" is the read for "this thing cannot eat anything"**, and it is the
  single most common cell in the water, so it is worth being the clearest signal
  in the vocabulary.

**What the scent haze means is unchanged and must stay unchanged. What it
measured was wrong by a factor of fifty, and the third pass fixed it.**

It is still `FOOD_TINT (0.35, 0.88, 0.42)` on every cell that fits in your
mouth, gene-blind, weighted by exactly `food.gd`'s `EDIBLE_FADE_IN/OUT` curve —
the drawn form of the scent field the membrane's green band is reading. If it
were gene-coloured, full vision would be showing a distinction point of view
cannot make, in the one channel where the two views must agree. **That rule is
not what was broken and nothing here touches it.**

What was broken was the alpha. Measured off the render, at both sizes:

| | median green, of 255 |
| --- | --- |
| empty water | 13–14 |
| the water shader's own organic wash, at its blobs | up to **79** |
| haze ring around an **edible** r18 cell, as shipped | **13.3** |
| the same ring around an **inedible** r33 cell | 12.7 |

**The edible/not distinction was 0.6 of 255 — six times smaller than the
dithering step, and thirty times smaller than the background's own texture in
the same channel.** It was not a weak signal, it was no signal, and it was
carrying the commonest decision in the game on its own. Three arithmetic faults
in one line did it:

- the outermost of the three rings was drawn at alpha **exactly zero** —
  `0.014 * (1 - t)` with `t` reaching 1. One of three draw calls, every frame,
  for every cell, painting nothing;
- the largest ring was the faintest, so the ink was spread from 2.9 to 6.0 body
  radii — a cloud twelve bodies wide and dense nowhere;
- peak alpha 0.0093, about a third of what 8-bit output can even represent.

**The replacement is one radial `GradientTexture2D`, drawn once per cell.** Not
more rings: six visible rings are six boundaries, and the code's own comment
already said why that is wrong — *a ring here would be a boundary, and the cell
cannot perceive a boundary*. Built and photographed with six rings first; it
banded at 1280x720 and worse at 2400x1080, where the canvas scale makes each
band half again as wide.

```gdscript
# vision.gd
const HAZE_OUTER := 3.0     # body radii
const HAZE_PEAK  := 0.24    # alpha at the plateau, before the edibility weight
const HAZE_TEXTURE_SIZE := 128
# Gradient, FILL_RADIAL, alpha by offset:
#   0.00 -> 1.00   0.42 -> 0.90   0.62 -> 0.42   0.82 -> 0.12   1.00 -> 0.00
```

Flat out to 0.42 and then away, so the brightest part is the annulus **just
outside the rim** — the middle is behind the body and cannot be seen. Measured
after, median green by distance from a r18 edible cell: **99** at the rim, 36 at
1.3 r, 24 at 1.65 r, background by 2.7 r; an inedible cell of any size stays flat
at 10–12. One `draw_texture_rect` instead of six polygons, plain `ImageTexture`
under GL Compatibility.

**Why a bloom on the body and not something cleverer.** It is attached: the
water's organic wash is hundreds of pixels across and attached to nothing, and
this is concentric with a cell and the size of that cell. Attachment, not
brightness, is what separates them — which matters, because the wash is the same
hue family and is sometimes brighter.

> **Add to §4.4's rule for the next designer.** Colour-blindness broke the
> safe/threat bow pair because both were *marks*, differing only in hue; the fix
> was shape. The edible mark is the other kind — **presence against absence** —
> and that is the one class of signal colour vision cannot break at all. Under
> the same Viénot deuteranope simulation the bloom is 9.5x the water's luminance
> at 1.3 r and 25x at the rim. If a later gene needs a readout and can be
> expressed as *there is a thing here / there is not*, spend that before
> spending a hue.

**One thing the bloom is deliberately not: range-attenuated.** The membrane
samples the scent field where the cell is standing, so its taste lobe fades with
distance; full vision draws the field where it is made, so the bloom is the same
strength at any distance on screen. This is not a divergence the two views can
be caught in — `BEARING_RANGE` is 680 and the visible half-width is 640 at
1280x720 and 800 at 2400x1080, so a cell that is on screen is essentially always
inside taste range anyway. §2.3's measured claim about the size of full vision's
advantage stands.

### 4.6 Two changes to shipped `vision.gd`

- `HEADING_LEN`'s needle base moves from `r * 1.55` to **`r * 1.80`**. A tier-3
  `cytostome` crest reaches `r * 1.61` and collided with the chevron. Rendered.
- The `CILIA = 32` block is replaced by the genome routine (§4.1–4.3).

## 5. The genome surface — `perception.md` §6.4, settled

> **§5.2's tiles and §5.3's measurements are superseded by
> `docs/design/dna-strand.md`.** The owner asked for a DNA rather than square
> slots, and the strip is now a chromosome: loci along a double helix, the tier
> drawn as **copies** (rungs) rather than pips, and the held sample a loose base
> pair floating over the locus it is bound for. §5.1's decision — that this is a
> launcher-themed surface and not the membrane aesthetic — is unchanged and is
> what the strand is drawn in. The two-tap placement, the 300 ms guard, the 4 s
> timeout, the plain word and the slot compass are all unchanged; only the shape
> they sit on is.

### 5.1 It is a launcher-themed panel, and the rule is general

**Decision: launcher theme, not the membrane aesthetic.**

`mode_select.tscn` and the pause screen already made this choice; this only
names it. Rendered side by side, both are the launcher's theme resource, the
launcher's organic wash at `intensity 0.5`, lowercase text, teal slabs. The
genome surface joins them.

> **The membrane is what the cell feels. A panel is what the player consults.
> The launcher theme marks every surface where the player, not the cell, is
> being addressed.**

The genome surface is not sensory — it is a representation, it needs touch
targets and it needs words, all three of which the sensory screen forbids and a
panel allows.

### 5.2 It lives on the pause screen

Not a new screen. Pause already has widgets, already has the house style, and is
already reachable by a gesture the player knows (Back on Android, `Esc` on
desktop). It costs no new input, no new pixels in play and no new binary.

Always visible as a readout; interactive only when a sample is held.

```
Hud/Pause/Scrim            ColorRect  Color(0.023, 0.055, 0.05, a)   <-- a is per view
Hud/Pause/Center/Buttons   VBoxContainer  separation = 48
  ├── Genome              VBoxContainer  separation = 10          <-- NEW
  │     ├── Caption       Label   "genome"  15px  Color(0.855, 0.953, 0.933, 0.45)
  │     ├── Row           HBoxContainer  separation = 20  alignment = CENTER
  │     │     ├── Sample  PanelContainer  76x76   (only while held)
  │     │     ├── Arrow   Control  30x76          (only while held)
  │     │     ├── Slot0.. PanelContainer  76x76 x slots()
  │     │     └── Tail    Control  126x0          (only while held)  <-- NEW
  │     └── Hint          Label   14px  Color(0.855, 0.953, 0.933, 0.38)
  ├── Light               PanelContainer  slab                        <-- CHANGED
  │     └── Box           VBoxContainer  separation = 6
  │           ├── Caption Label   "light"  15px
  │           └── Slider  HSlider  192 x 48
  ├── Resume              (unchanged)
  └── Leave               (unchanged)
```

**The scrim is set per view, and the reason is the camera (third pass).** The
camera holds the player's cell at the exact centre of the screen; the pause
column is centred too. In full vision the light control is therefore drawn
across the player's own body, always, and nothing can move — the cell is pinned
by the camera and the column by the house style. Phase 5 is what made it
intolerable rather than merely true: the cell acquired a bright multicoloured
fringe and a wide gape bow, the slider track started running through the cilia
and `light` landed on the mouth. Worse at 1280x720 than at 2400x1080, because
the cell is the same size in canvas units and the canvas is 320 px wider there.

| view | scrim alpha | why |
| --- | --- | --- |
| point of view | **0.50**, unchanged from Phase 4 | the membrane behind it is the live preview of the very slider below it, and it costs nothing: measured, the membrane only ever draws in the outer ~150 canvas px, which the column never reaches |
| full vision | **0.86** | takes the world to 14%. The cell becomes a watermark behind the mirror, which is what §2.4 says this screen is |

**And `Light` becomes a `PanelContainer` with the same slab as its neighbours.**
This was the real find: the genome tiles are panels, `resume` and `leave` are
slabs, and the light caption and its track were the one group on the column that
was bare strokes floating on the water — which is exactly why they were the pair
the cell tangled with. Slab at `_slab(-0.2)` (fainter than a button: it is a
surface, not a third thing to press), slider `192 x 48` so that 192 plus the
slab's 20px side margins is 232 — the button width, so the column has one edge
rather than two. **Rule for later screens: every group on the pause column is a
surface.**

**The slots do not move when a sample arrives.** `Row` is centred, so the slot
block used to slide 73px right the moment a sample appeared and 73px back when
it lapsed. §5.3 spotted the shift and argued it was harmless because nothing is
tappable once the sample is gone; that holds for taps and not for reading, and
a sample lapses on a 45-second timer that does not stop because the pause screen
is open. A trailing `Control` of `TILE + separation + ARROW = 126` px makes the
row symmetric about the slots, so centring the row centres the slots and the
sample and its arrow hang off to the left. One invisible node, no new anchor.

**Which name goes on the tile: the plain word.** §9.1 gives every gene two
names and §5.2 said only "the gene's name", which an engineer cannot act on.
**The tile reads `eat` / `turn` / `swim` / `see`; the biological name is what the
code calls it and never appears on screen in normal mode.** Rendered both ways at
both sizes: `cytostome` and `flagellum` *do* fit inside a 76px tile at 13px, with
about 2px of air either side, so the choice is not forced by layout — it is
forced by the glance. Four short verbs are parsed instantly at arm's length; nine
letters of Greek are not, on the one screen whose whole job is a quick decision.
Two consequences: **no gene name may exceed nine characters at 13px** or the tile
has to grow, and the biological names stay where they belong — in the code, in
this document, and in §9.1.

**`Light`, `Resume` and `Leave` must be given `size_flags_horizontal =
SIZE_SHRINK_CENTER`.** They currently inherit the VBox's width; with a seven-slot
strip above them they stretch to 652px. Rendered, and it looked wrong.

**Tile states** — `PanelContainer` + `StyleBoxFlat`, `corner_radius_all = 8`:

| state | bg | border |
| --- | --- | --- |
| occupied | `Color(0.063, 0.141, 0.125, 0.62)` | 1px, gene hue at `a = 0.45` |
| empty | `Color(0.047, 0.082, 0.075, 0.50)` | 1px, `Color(0.141, 0.278, 0.247, 0.85)` |
| held sample | `Color(0.063, 0.141, 0.125, 0.80)` | 2px, gene hue at `a = 0.90` |
| armed | `Color(0.086, 0.204, 0.176, 0.80)` | 2px, gene hue at `a = 0.85` |

**Tile face**, drawn in `_draw` on a `MOUSE_FILTER_IGNORE` child:

- the gene's name, 13px, `Color(0.855, 0.953, 0.933, 0.66)` (`0.92` when armed or
  held), centred at `y = 15`
- the organ: an arc of radius 13 at `centre = (w/2, 0.66h)`, spanning
  `1.04π … 1.96π`, gene hue at `a = 0.30`, with the gene's own stroke count and
  length (`cytostome` 9 x 8px, `cirrus` 5 x 13px, `flagellum` 6 x 17px, earned 5 x 11px plus a
  4.2px pigment disc), gene hue at `a = 0.88`, width 1.7
- tier pips: three dots radius 2.6 at `y = h − 9`, spaced 9px; filled at
  `a = 0.92`, outline at `a = 0.22`
- an empty slot draws a `+`: two 16px lines, `Color(0.141, 0.278, 0.247, 0.75)`

**Interaction** — two taps on the same target, which is the only pattern that is
safe on touch and navigable by keyboard:

1. A tap (or `Enter` on a focused tile) **arms** a slot. The hint changes from
   `tap a slot to replace it` to `tap again to integrate`.
2. A second tap on the **same** tile commits the swap, no sooner than
   `ARM_GUARD = 0.30s` after the first, so a double-tap cannot commit.
3. Arming lapses after `ARM_TIMEOUT = 4.0s`, or on arming a different slot.

A mis-tap costs nothing because arming is reversible. That is why the 20px gap
between tiles is acceptable even though it is ~1.5mm on a 2400x1080 phone — it
is the same argument the 48px `resume`/`leave` separation makes in reverse, and
the destructive control here is not adjacent to `resume`.

### 5.3 Measured layout

| | value |
| --- | --- |
| tile | 76 x 76 canvas px (touch rule: ≥48 ✓; 114 device px at 2400x1080) |
| tile gap | 20 |
| widest state **reachable in Phase 5** — 7 slots, no sample | **652** canvas px |
| widest *held* state — 3 slots + sample + arrow + tail | **560** canvas px |
| margin at 1280x720, 7 slots | 314 px each side |
| margin at 2400x1080 (canvas 1600x720), 7 slots | 474 px each side |
| tallest state (genome + hint + light slab + two buttons) | **489** canvas px of 720 |

> **The 798px "widest state" the second pass measured cannot happen.** A sample
> is only *held* when `filled() == slots()`, and Phase 5 ships four genes, so a
> genome can never be full at more than four slots — and a fifth gene would be
> needed to have something left over. The only held state the game can reach is
> **3 slots**, on a born r26 cell that has just eaten a `stigma`. Everything
> wider than that was measured against a state that does not exist. It fits
> anyway; the number was just not describing the game.

Rendered at both sizes at 3 slots, 7 slots, held, and armed — the armed state
driven by a synthetic **touch at 2400x1080**, which is the one input path a
phone actually uses and the one the canvas offset (a centred widget is 160 px
further right at 20:9) could have broken. It lands. Nothing overflows and
nothing collides.

**Reflow:** the canvas is 720 tall at both shapes, so the vertical stack is
identical. Only the horizontal margins change, and the strip is centred.

## 6. The one earned gene Phase 5 ships: `stigma`

`perception.md` §4 promised it: *"a new glow lobe in slot 2, in a colour not yet
used… sharper (half-width ~20°) and does not jitter… the moment the player
learns that direction can be certain."* Slot 2 has been reserved since Phase 1.

**What it sees: the shadow of anything bigger than you.** A body passing between
you and the light above occludes it. This costs no new world content — no sun,
no lamp — and it gives point of view a *sharp, certain, continuous* bearing on
**mass**, where before it had only intermittent wakes and directionless dread.

> **Mass, not danger — and after §1.1 those are no longer the same thing.** A
> shadow's size is a fact about a body, so `SHADOW_MIN_RATIO` stays on the radius
> and the `stigma` says nothing about the gape. It is therefore **silent about the
> two cells §1.1 exists to create**: the small cell with a huge mouth casts no
> shadow, and the mouthless giant casts a large one. That is not a bug to patch —
> it is honest optics, it keeps `perception.md`'s "never an identity", and it
> leaves the gap that §2.3's reserved chemoreceptor gene is there to sell. Say it
> plainly rather than letting a player assume the amber lobe means *predator*: the
> `stigma` tells you **where the big thing is**, and after Phase 5 big is only
> correlated with dangerous.

```gdscript
# signal_bus.gd
const LOBE_LIGHT := 2
const LIGHT_COLOR := Vector3(0.98, 0.78, 0.30)   # glow_colors[2], was ZERO
const LIGHT_PEAK := 0.28
const LIGHT_HALFWIDTH_DEG := [0.0, 26.0, 19.0, 13.0]   # by tier

# Size, not threat -- see the note above.
const SHADOW_RANGE := 620.0      # inside WAKE_RANGE 760: it sharpens, never extends
const SHADOW_CORE := 180.0
# A body this fraction of your radius starts casting; one your own size casts a
# whole shadow. A window, not a threshold -- see below.
const SHADOW_MIN_RATIO := 0.8
const SHADOW_FULL_RATIO := 1.05
```

> **`SHADOW_FULL_RATIO` is the build's correction and it is the same correction
> §7.0 spends a page making to dread.** The first draft wrote the rule as *"any
> cell with radius >= SHADOW_MIN_RATIO * cell.radius"*, and that is a boolean:
> a body drifting across ratio 0.8 would pop the amber lobe on and off, putting
> a step into a signal whose entire selling point is that it is steady. Every
> other gate in `food.gd` has been taken off exactly that argument. Built as
> `smoothstep(0.80, 1.05, ratio)`: nothing below 0.8 casts anything, which is
> what the number in this section actually means, and a body your own size casts
> a whole one.

Three properties, all load-bearing:

- **It does not jitter and it does not lag.** Taste is 78° wide at range and only
  26° on top of the food; the `stigma` is its tier's width at *every* range.
- **Dread cannot muffle it.** Dread is a blocked chemoreceptor; light is a
  different organ. `TASTE_DREAD_SUPPRESS` must not be applied to `LOBE_LIGHT`.
  This is the fiction and it is also the purchase: at the moment the player can
  see least, the thing they bought still works.
- **It fades out at the end of the run rather than announcing it.** The previous
  draft said the silence *is* the readout that you have won. Two corrections.
  First, it is false without §1.3's ceiling at all: under a distribution that
  scales with the player a ratio threshold is never crossed and the lobe never
  goes quiet. Second, even with the ceiling the arithmetic puts it in the wrong
  place — `ARRIVAL_RADIUS_MAX = 40` against `SHADOW_MIN_RATIO = 0.8` means the
  last shadow fades at radius **50**, ten meals *after* dread stops at 40.
  **Dread stopping is the readout that you have won**; the `stigma` going quiet is
  a late, quieter echo of it, and for those ten meals it is showing you giants
  that can no longer hurt you. That is acceptable and even nice — the water is
  still full, it just cannot reach you — but it must not be sold as the victory
  signal.

Rendered on a `dread = 0.95` frame at 1280x720: the amber lobe is the brightest
thing on screen at **`(77, 83, 48)`** against dread's own `(7, 27, 27)` — a
precise bearing on a drained membrane. Rendered beside a full-strength taste
lobe: amber and green read as two different substances with no ambiguity.

Re-measured by the third pass and it holds: peak **`(66, 71, 41)`** against a
membrane centre at `(4, 9, 11)`, and it is the brightest pixel in the frame. On
a calm frame the screen is black with one amber patch on the rim and nothing
else — which is also the check that point of view has not quietly acquired
anything §2 forbids. It has not: the scent bloom of §4.5 lives in `vision.gd`,
which does not draw in this view at all.

> **One property nobody had written down, and it is not Phase 5's to fix.** The
> membrane maps a bearing onto a rounded rectangle, so the *same* bearing lands
> in a visibly different place and shape at the two aspect ratios: at 1280x720,
> −60° sits in the top-left corner; at 2400x1080 it runs down the left edge. The
> direction still reads at both, and the mapping is monotonic and stable within
> one device, so a player learns one mapping and keeps it. But it is a property
> of **every** lobe since Phase 1, not of the `stigma`, and it is the reason the
> word "certain" in this section should be read as *does not jitter and does not
> lag* rather than as *degrees you could act on*.

## 7. What this breaks, and who owns it

### 7.0 `food.gd` and `predator.gd` become one thing

They are two classes describing one kind of object, and §1 collapses them. This
is rework on shipped, working code, and it should be done rather than deferred:
building the genome on top of a split that is about to close would mean writing
the gene system twice.

What carries over, because the behaviour was never really about being a
predator:

| shipped | becomes |
|---|---|
| `predator.gd`'s aim state machine, `COMMIT_RANGE`, the lunge, the break-off | how **any** cell pursues something it can eat. Was always general; only the name was specific. |
| `threat` — the `RADIUS / cell.radius` ratio | the **gape comparison** of §1.1, evaluated per cell and in both directions |
| `dread_level` | still a scalar, now summed over cells that can eat *me*. Dread was always a property of the relationship, not of a species. **It must stay continuous — see below.** |
| `food.gd`'s scent field, `concentration`, `taste_bearing` | unchanged in kind, but summed over everything **I** can eat rather than over a food species |
| `FIRST_DELAY`, `SPAWN_MIN/MAX`, the authored first arrival | the seeding distribution of §1.3. The authored first encounter survives as an authored *opening*, not as a species spawn. |
| `PREY_SPEED = 56.5`, hard-coded | dies. Every cell swims on its own `flagellum` tier. |
| `RADIUS = 40` — the predator's fixed size | dies. Size is per-cell and grows. |

> **The one place this collapse would have broken something.** `A can eat B` is a
> boolean, and Phase 4's dread is not: it is
> `smoothstep(THREAT_LOW 0.85, THREAT_HIGH 1.35, ratio)`, deliberately gradual so
> the player *feels themselves stop being afraid*. Summing booleans makes dread a
> step function that snaps 0 → 1 the frame a cell's gape crosses your radius, and
> the most-praised readout in Phase 4 is gone. **Substitute the gape into the
> existing formula rather than replacing it:**
>
> ```gdscript
> threat_of(other) = smoothstep(THREAT_LOW, THREAT_HIGH, other.gape() / my.radius)
> ```
>
> Same two constants, same curve, same feel; `other.gape()` simply replaces
> `predator.RADIUS`. A cell growing its cytostome now becomes frightening
> *gradually*, which is exactly the Phase 4 experience run backwards. Apply the
> same treatment to the taste field: weight each cell by
> `smoothstep(1.15, 0.85, other.radius / my.gape())` so a body drifting across
> your gape limit fades into and out of the scent rather than popping.

**Phase 4's perception design survives intact**, which is the reassuring part:
food quickens the beat and something dangerous makes it stumble, and both are
now computed from the same gape comparison instead of from two species. Nothing
in `perception.md` or in the membrane changes.

What genuinely dies is the *authored menace*: a single hand-placed hunter with a
scripted arrival. What replaces it is a field where the dangerous cell is
whichever one has been eating, which is better, and which is also why §1.3's
bound exists.

### 7.1 Two Phase 4 contracts, re-measured

Both are stated against a tier-1 cell and Phase 5 invalidates both. Neither is a
reason not to ship; both must be re-measured.

- **`cirrus` tier 3 sets `TURN_RATE_MAX = 1.02`** (58°/s, half-turn in 3.1s)
  against the 0.62 that `ESCAPE_SECONDS = 7.0` was derived from — and against
  `predator.TURN_RATE`, which is also 0.62, so a tier-3 cell out-turns its hunter
  by 1.65x. The dodge gets much easier. That is the reward; re-measure
  `predator.COMMIT_RANGE` (310) against a tier-3 cell with
  `tools/drive.gd --hunt --evade`, and check that *"a cell that does nothing must
  be caught"* still holds at tier 1.
- **`flagellum` tier 3 sets `IMPULSE_SPEED = 190`**, taking the cell's net speed
  from 56.5 to roughly 78 u/s — past `predator.CRUISE = 68`. *"You cannot outswim
  it"* stops being true, and `predator.PREY_SPEED` is a hard-coded `56.5` that
  the pursuit solution uses to aim, so it starts leading the wrong point.
  **Recommended: `PREY_SPEED` becomes the cell's realised speed and
  `CRUISE = PREY_SPEED * 1.20`**, so the chase stays a chase at every tier and
  only `cirrus` improves the dodge. Owner's call; recorded.

### 7.2 New and changed files

| file | change |
| --- | --- |
| `game/normal/genome.gd` | **new.** A plain `Node`, no `class_name`, same shape as `food.gd`: holds `{gene: tier}`, the held sample and its clock, `slots()`, `upkeep()`, `integrate()`. Computes; does not post. |
| `game/normal/normal_mode.tscn` | **new** `Genome` node, `process_mode = 1`; pause gains the `Genome` block (§5.2); `Light`/`Resume`/`Leave` get `size_flags_horizontal = 4`. **Third pass:** `Light` becomes a `PanelContainer` wrapping a `Box` VBox (§5.2) |
| `game/normal/normal_mode.gd` | fills `gene` from `_on_eaten`, writes `_metabolism.upkeep`, owns the strip and the two-tap arming. **Third pass:** `SCRIM_POV`/`SCRIM_FULL_VISION` set on opening pause, the `Light` slab, slider 192 wide, and the trailing spacer that pins the slots (§5.2) |
| `game/normal/food.gd` | `GENE_WEIGHTS`; a genome per cell, chosen in `_seed()`; the §1.3 seeding (drifters, peers, `ARRIVAL_GAPE_MAX`, the one-drifter floor); a `genomes()` accessor for full vision, index-matched to `points()` |
| `game/normal/cell.gd` | `GROWTH_PER_MEAL` 0.5 → 1.0; `SLOT_*`; `gape()`; drive constants read from the genome |
| `game/normal/metabolism.gd` | `upkeep`. **`MEAL` stays a `const`** — §3.2 takes it off the tier table and scales the meal by prey size at the call site instead |
| `game/normal/predator.gd` | **merged into `food.gd` and deleted** (§7.0). The aim machine, `COMMIT_RANGE`, the lunge and the break-off move across as how any cell pursues; `RADIUS` and `PREY_SPEED` do not. |
| `game/perception/signal_bus.gd` | `LOBE_LIGHT`/`LIGHT_COLOR` in `attach()`, `light()`, the `LOBE_LIGHT` branch in `_compose_lobes()`, `ingest()` writing `ingest_color`, the held echo in `_step_beat()` |
| `game/vision/cilia.gd` | **new.** The one drawing routine (§4.5): body tint, genome fringe, and the gape with its threat colour. Used by every cell in the water and by the genome tiles. |
| `game/vision/vision.gd` | §4.6. **Third pass:** `_draw_scent` replaces the three-ring haze with one radial `GradientTexture2D` -- `HAZE_OUTER`, `HAZE_PEAK`, `HAZE_TEXTURE_SIZE` (§4.5) |
| `game/perception/membrane.gdshader` | **no change.** Every uniform this phase needs already exists. |

Tier targets, for the engineer:

| gene | constant | t1 | t2 | t3 |
| --- | --- | --- | --- | --- |
| `cytostome` | gape, as `x radius` (§1.1) | 0.82 | 1.05 | 1.40 |
| `cirrus` | `cell.TURN_RATE_MAX` | 0.62 | 0.80 | 1.02 |
| `cirrus` | `cell.TURN_RESPONSE` | 1.10 | 0.85 | 0.65 |
| `flagellum` | `cell.IMPULSE_SPEED` | 138 | 162 | 190 |
| `flagellum` | `cell.IMPULSE_GAP_MIN/MAX` | 1.7 / 3.6 | 1.45 / 3.0 | 1.2 / 2.5 |
| `stigma` | `LIGHT_HALFWIDTH_DEG` | 26° | 19° | 13° |

These must be *read from the genome*, not stored as `const`. Put the mapping in
one place per file, next to the constant it replaces, for the same reason
`perception.md` §6.2 put the hunger→beat mapping in one place.

## 8. Text budget

`perception.md` §6.1 allows exactly one string in normal mode. **It is not
touched.** Phase 5 adds no text to the sensory screen in either mode, in any
state.

Every word Phase 5 adds is on the pause screen, which has carried words since
Phase 1 and carries `light` already: the caption `genome`, the hint
(`tap a slot to replace it` / `tap again to integrate`), and one lowercase word
per slot.

**Genes are named on the genome strip and nowhere else, and the name on the
tile is the plain word** — `eat`, `turn`, `swim`, `see` (§5.2). The biological
name is what the code calls it and never reaches the screen. A permanent,
irreversible swap needs an unambiguous label, and the deuteranope render in §4.4
shows that hue alone is not one; four short verbs are the cheapest label that
works at a glance and under any colour vision.

## 9. Left open — owner's call

1. ~~Gene names.~~ **DECIDED: the biological name, plus one plain word.** The
   biological name is the identity and what the code calls it; the one word is
   what a player reads. Nothing carries a sentence.

   | gene | word | what it is |
   |---|---|---|
   | **cytostome** | *eat* | the mouth. Its tier sets the gape, and the gape decides what you can swallow (§1.1). |
   | **cirrus** | *turn* | the tuft of fused cilia on the flank. Steering. |
   | **flagellum** | *swim* | the tail. Thrust. |
   | **stigma** | *see* | the light-sensitive spot. The first earned gene (§6). |

   These are the real terms for these organs, which is the point: the game is
   about being a cell, and a cell's parts have names. Extend the pattern rather
   than the list — a new gene gets a real organ name and one word, or it does
   not ship.

   > **The steering organ was `kinety` in the first draft; the owner renamed it.**
   > `kinety` is a real term and its gloss was accurate — a longitudinal row of
   > kinetosomes and their cilia. But kineties are the **somatic ciliature that
   > does the swimming**, all over the body, and this document gives swimming to
   > `flagellum`. The organ that actually steers a ciliate is the **`cirrus`** — a
   > tuft of fused cilia used for directional control, which is also exactly what
   > §4.2 already draws (*"two oars, beating in antiphase, five per side"*). It is
   > the more familiar word as well: `kinety` was the only one of the four a player
   > would read as a typo. **Renamed throughout.**

2. ~~Does the predator's cruise track the cell's speed?~~ **Moot, and better.**
   There is no predator to tune. Every cell swims on its own `flagellum` tier,
   so a cell that out-swims you does it because it has more tail than you, and
   you can see that before it happens. `PREY_SPEED` and its hard-coded 56.5 go
   with `predator.gd` (§7).
3. ~~`UPKEEP_PER_TIER = 0.18`.~~ **DECIDED: ships at 0.18**, to be judged by
   playing. Still the only number here that cannot be checked by looking, so it
   stays the first thing to move if the late game feels either free or airless;
   `HUNGER_SECONDS` second.
4. ~~Does a run remember its genome?~~ **DECIDED: it keeps nothing.** Every run
   starts as the basic cell — three organs, all tier 1. Death is a clean restart
   and the arc is one session. Lineage is a real design and it is not this one.
   Previously open as `food-and-predators.md` §9.2.
5. ~~A dedicated gesture for the genome~~ (two-finger tap / `G`) instead of
   going through pause. **DECIDED: pause only.** It already works on both targets
   and costs nothing; a dedicated gesture is one more thing to teach and one more
   thing to fire by accident on a touchscreen. Recorded because it will be asked
   again.
6. **The four seeding numbers of §1.3** — **`TIER_WEIGHTS`** first, then
   `DRIFTER_SHARE`, `PEER_SPREAD` and `ARRIVAL_GAPE_MAX`. `TIER_WEIGHTS` is the
   cytostome distribution inside the peer band, `[0, 3, 2, 1]` as built; it is
   the dial this list used to describe in words and not name, and it is the one
   that decides how much of the water can eat you — measured at 19% for a born
   cell. The shape is settled and defended; the values are the water's difficulty
   and can only be judged by swimming in it. They replace the old §9 entry that said the
   distribution was "centred on the player" and left it there.
7. ~~Can the player replace their own `cytostome`?~~ **DECIDED: yes, allow it.**
   §5.2's two-tap swap is unrestricted, so a player can put a fourth gene over
   their mouth and drop to
   gape `0.58 r` — at r26 that is 15, which eats only the smallest drifters, and
   it cannot be undone. It is either a real and interesting mistake or a soft
   lock, and which one it is depends entirely on §1.3's drifter floor holding.
   The floor guarantees the mistake is survivable, the tile shows three pips going
   dark before it is confirmed, and a genome you cannot ruin is not a choice. It
   is the one irreversible action in the game, and it stays in.

8. **What "the run ends" means, and what it does not.** §3.1 lands the arc on
   radius 40: the genome fills on the same meal that nothing left in the water has
   a gape wide enough for you. The owner has settled that this is the shape — and
   attached the reason it does not make a maxed cell the end of the game:

   > *"We will later add so much possibilities, bosses, legendary organisms that
   > it will still be fun even with a maxed out organism. The player can still
   > discover new combinations of genes that makes it very fun, or even become
   > cheated (that must stay hard to do tho)."*

   Three consequences, and they are binding on what gets built now:

   - **`ARRIVAL_GAPE_MAX` is a property of this water, not of the game.** It is
     the number that decides where this water stops *seeding* things that can
     threaten you, and a second water (roadmap §8) sets its own. Write it where
     an environment can override it, not as a global ceiling on the species.
     **It bounds arrivals only** — a cell that has been feeding grows past it,
     which §1.3 now records as deliberate: that cell is the first legendary
     organism, and it costs nothing to author.
   - **Seven full slots is a starting position, not a finish.** What is
     interesting past radius 40 is *which* seven, so the genome must stay
     swappable at maximum — which §9.7 has just guaranteed by leaving even the
     mouth replaceable. A design that locked the genome once full would close the
     door this note is holding open.
   - **Overpowered builds are allowed to exist; they must be hard to assemble.**
     Not gated by a rule that forbids them — gated by the cost of getting there.
     `UPKEEP_PER_TIER` (§9.3) is the lever: a build that is strong on every axis
     should be one that starves. Whenever a later phase adds a gene, the question
     to ask of it is not "is this too strong" but "is the strong combination it
     enables expensive enough to be an achievement".

## 10. What was rendered

Prototyped in a throwaway copy outside the repository, at 1280x720 and
2400x1080, under `--rendering-driver opengl3`.

From the first pass:

- the born cell (1/1/1, r26) and the maximum cell (3/3/3 + `stigma` 3, r40) in
  full vision, against the live halo, beat, trail, velocity plume and heading
- all three organs at all three tiers, side by side, at r26 / r30 / r34 / r40
- the same frame in luminance only and under a Viénot deuteranope simulation
- four gene-bearing cells at 250–300 units, and one at 430 canvas px
- the genome strip on the pause screen at 3 slots, at 7 slots, with a held
  sample, and armed — at both sizes
- point of view: the `stigma` lobe at 13° / 19° / 26° on a `dread = 0.95`
  frame, the `stigma` beside a full-strength taste lobe, and the amber ingest
  flood

Added by the review, because §1.1–1.3 had been written against two frames:

- **the cytostome ladder** — tiers 0/1/2/3 at r26 and r40, both sizes
- **all four relationships at real foraging distance** (250–640 units) and again
  **with every cell at the frame edge**, which is where the first-pass claim
  about the small-body-huge-mouth case failed (§1.1.1)
- the same two frames **with the threat colour and teeth on**, which is what
  fixed it, and both again under a Viénot deuteranope simulation — which is what
  proved the colour alone was not enough (§1.1.1)
- **drifter-sized bodies**, r14–20 at all three cytostome tiers, with and without
  a minimum-stroke clamp — the clamp is a no-op and was cut (§4.5)
- **the rubber-band frame**: the born cell among peers scaled to it, beside the
  full-grown cell among peers scaled to it. Identical pictures, which is what
  killed the first version of §1.3
- **the respecified water** (§1.3) seeded against a r26 player and a r40 player,
  both sizes — two different pictures, which is what the fix had to produce
- the genome strip labelled with the biological names and with the plain words,
  both sizes, at seven slots with a sample held (§5.2)

Added by the third pass, which photographed the **built** Phase 5 rather than a
prototype, at 1280x720 and 2400x1080, through `tools/drive.tscn`:

- **the four relationships posed on purpose** with `--cell=`, at 400–560 units
  and at the frame edge, before and after the scent fix. Before: the edible/not
  difference measured **0.6 of 255** and the two frames are indistinguishable.
  After: all four are callable at a glance at both shapes (§1.1.1, §4.5)
- **a real field of drifters**, r14–21, one gene each, at 300–600 units — "no
  green at the nose" holds, and every one of them now also says *edible*
- **the tier ladder** 1/2/3 at r26 and at r40, against a player whose gape puts
  the ladder on the safe side and against one it does not. Tier reads as
  magnitude at both body sizes, and the bloom does not swamp the fringe
- **the pause screen** at 3 and 7 slots, held, and armed, in **both views**, at
  both shapes — which is what found the scrim and the `light` slab (§5.2)
- **the armed state driven by a touch at 2400x1080**, to prove the input path
  lands where the canvas offset puts the tile
- **point of view** calm and at `dread = 0.95`, and the pause screen over a lit
  membrane, to check the light slider still previews what it changes

Three things in this document are made of time and cannot be photographed: **the
second heartbeat, the steering lean, and every number in §1.3.** They must be
judged by playing, and they are the things here most likely to be wrong.

**A fourth thing, found by looking and not by measuring:** in ordinary play the
water often has **no cell on screen at all** — `food.COUNT` is 4 and the field is
much larger than the viewport. Two unposed frames at 22 s and 30 s had one cell
and none. That is a §1.3 population question, not a drawing one, and it is
listed here only because it is invisible in every posed frame in this section.

---

## 11. Phase 6: taste becomes a gene, and the opening stops being empty

The owner's report was one sentence: *"When we start, we don't see anything."*
Three changes answer it, and the third is the point of the other two.

### 11.1 `chemocyte` — *smell*

**Taste stops being innate.** From Phase 1 to Phase 5 `normal_mode.gd` posted
`_bus.taste(...)` unconditionally: a free, always-on bearing to anything edible,
which is the single most useful piece of information in the game and the only
one nobody had to earn. It is now gated on `chemocyte` exactly the way the light
lobe is gated on `stigma` — at the call site, and again inside the bus, so *an
organ you have not grown is silent* is a property of the bus and not a
discipline four call sites have to remember.

The tier buys **reach**, and nothing else:

```
# cell.gd
const SMELL_RANGE_BY_TIER: Array[float] = [0.0, 1100.0, 1350.0, 1600.0]
```

Sharpness is deliberately left alone: `rhabdom` / *focus* already owns the taste
lobe's width and jitter, and a second gene doing the same thing would make one
of them pointless. Tier 3 is `food.gd`'s `SCENT_RANGE`, so a saturated nose is
exactly the always-on taste every build before this one shipped with.

Two numbers come out of the field where there was one. `concentration` is what
the *water* is like and still drives the metabolic beat — a noseless cell
still beats faster in rich water, because the beat is a property of the body and
not of its senses. `taste_level` is what the *organ* picks up, summed only over
sources inside `smell_range`, and it is the only one of the two that reaches the
membrane. A cell with no `chemocyte` leaves `_step_sense()` with `taste_level`
and `taste_bearing` both flat zero.

`dread` stays innate. Fear of being eaten is not a sense you grow.

### 11.2 `ampulla` — *ping*

Electroreception, and the first sense in the game that is **not about food**. A
pulse every `PING_PERIOD_BY_TIER` seconds out to `PING_RANGE_BY_TIER`, and a
bearing for every body it comes back off — edible, inedible, hunting you, or
asleep. That is the whole of why it is a different sense from `chemocyte` rather
than a second skin on it: the scent field can only ever describe a meal, and
most of what matters in this water is not a meal.

**Every body it comes back off, and not one behind a shadow.** The pulse leaves
the organ's own place on the skin and stops at the first thing it meets — your
own hull included — so a tier-1 `ampulla` is deaf through roughly the hemisphere
its organ faces away from. Higher tiers hear through an occluder at
`PING_THROUGH_BY_TIER`, dimmer rather than further. `docs/design/three-senses.md`
§1 is the whole of it, and §7.3.1 has the measurements. The consequence worth
knowing before you place one: **at tier 1 a cell pressed against you behind the
organ returns nothing at all** until you turn.

```
# cell.gd
const PING_RANGE_BY_TIER:  Array[float] = [0.0, 1100.0, 1500.0, 1900.0]
const PING_PERIOD_BY_TIER: Array[float] = [0.0,    3.2,    2.2,    1.4]
```

**It reads as a sweep because the returns are staggered by their own flight
time.** `food.gd` holds each echo for `distance / PING_SPEED` seconds before it
becomes a bearing, so one pulse arrives on the membrane as a run of separate
marks walking outward — nearest first, loudest first — over about a second. The
scent field is a steady wide band that lags and jitters; the ping is a burst of
tight marks that are exactly where they say they are and then gone. Nothing else
in the game behaves like either.

It shares `LOBE_BEAM` with the `ocellus`, which is not a compromise: there are
four glow lobes in the shader, a fifth is a new uniform and a new binary, and
both of these genes mean *a hard surface, that way, that far*. They compete
rather than sum, exactly as the three self-signals do in lobe 0.

Full vision draws the wavefront as a ring expanding out of the cell, for the
same reason it draws the beam's line: so that "the blips stopped because nothing
is in reach" is visible rather than deduced.

### 11.3 The free opening sense, at five seconds

A born cell now has **no sense of any kind**, which makes the opening minute
worse than it has ever been unless something is done about it. So, five seconds
in, unconditionally, once per life:

> one sensing gene, free, drawn flat at random from `ocellus`, `ampulla`,
> `chemocyte`, `stigma`.

**It arrives as a held sample the player places**, not as an auto-placement. Two
reasons: the `ocellus` is directional and worthless unplaced, and this makes the
free gene the natural first lesson in §5.2's placement mechanic — which was
previously first met about fourteen minutes into a run, at the one moment the
decision is also destructive.

It is announced on the one line of text this mode has (§8), in the same voice:
`a sense grew · esc to place it`, or `· back to place it` on touch. Unlike the
steering line this shows on **every** run, because the thing it announces
happens on every run and a player who missed it once is a player swimming blind.

**Guaranteeing it lands cost one new idea.** The born genome is already full —
three slots, three organs — so a sample granted into it has nowhere to lapse to
and evaporates after forty-five seconds, leaving exactly the state the grant
exists to prevent. `genome.gd` grows a `bonus_slots` counter, and the grant takes
one *only when there is no free slot*: the gift comes with somewhere to put it.
It is absorbed rather than permanent, because `slots()` still clamps at
`SLOT_MAX`. A player who never opens the pause screen gets the gene anyway, in
that slot, at fifty seconds.

`FIRST_DISTANCE` moves from 1400 to 1000 so the authored first arrival is inside
the reach of a tier-1 `chemocyte` (1100) and a tier-1 `ampulla` (1100), and still
outside the frame — the half-diagonal of a 20:9 canvas is 877. The other two
draws are allowed to miss it: an `ocellus` reaches 620 and only along the arc it
was put on, and a `stigma` sees mass, which a drifter does not have. **The
`stigma` draw is the weakest of the four and is known to be so** — it is a real
sense and what it does see is the half of the water that can eat you, but it
will not find the first meal, and if the opening still reads as empty one run in
four that is the row to change.

### 11.4 What was rendered

At 1280x720 and at 2400x1080, point of view, with `tools/drive.gd`:

- a **blind** cell — the three born organs and nothing else: no band, no mark,
  and the self-figure (§2) as the only thing on screen. This is the state the
  grant exists to end, and it is three seconds long
- a **`chemocyte`** cell: the green band, in the corner, at the bearing
- an **`ampulla`** cell frozen 45 ms after a return: one tight violet mark on the
  contour, brighter than anything else in frame
- the **pause screen at five seconds**: the held sample, the arrow, three
  occupied tiles and the one empty bonus slot with its compass
- the **whole placement path driven by two touches** at the tile, and the gene
  pinging three seconds later
- the **lapse path**, headless to ninety seconds: nothing placed, sample settles
  at 50.0 s, genome reads `[che1 cir1 cyt1 fla1]` at 60 s
- an **`ocellus` and an `ampulla` in one genome**, at slots 0 and 4, to check
  that sharing lobe 3 does not silence either: the beam holds the lobe between
  pulses and the returns punch through it
- a **death and a revive**, to check the figure comes back and the five-second
  clock starts again — `hold` fires 5.0 s after the aperture reopens
- **full vision**, frozen mid-pulse: the wavefront ring past the frame edge, and
  no self-figure — the real body is already drawn there
