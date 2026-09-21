# The lifecycle: a cell divides, and you take one of the daughters

The owner, in three sentences, each of which is load-bearing:

> "A cell has a lifecycle. A gene change in dna is only visible on to the next
> generation. You take control of one of the daughter cells."

**Read `edibility.md` first.** The owner overturned the gape rule in the same
breath, and two things this spec would otherwise have leaned on are gone with
it: there is no radius at which the water cannot kill you, and radius 40 is not
a safe harbour. The division trigger is re-derived in §2 without appealing to
either.

## 1. The shape

**A body is fixed; a genome is not.** The cell you are swimming is the genome
you were born with, expressed whole, and nothing you eat this life changes it.
What you eat writes **DNA**, and DNA is what your daughters are made of. At
`DIVIDE_RADIUS` the body splits into two, each carrying that DNA — one faithful,
one with a single mutation — and you take one of them.

Five consequences, and they are the design:

1. **Growth stops meaning "become better" and starts meaning "become able".**
   Meals still buy radius, and radius still buys the slot ladder, the gape and a
   body that takes longer to chew through. What they no longer buy is a new
   organ this life.
2. **The run becomes a loop with a ratchet in it.** Size resets every
   generation; DNA does not. Generation five is born small and formidable.
3. **You are never safe, and you are least safe just after succeeding.** A
   newborn carries her mother's whole genome on a body two thirds the size, and
   `edibility.md`'s bite is proportional to how much of you a mouth can reach.
4. **The pause strip stops being a mirror and becomes a plan.** It always showed
   what you are; it now mostly shows what your children will be. §3.
5. **§9.4 — "a run keeps nothing" — is replaced, not deleted:** *a run keeps
   nothing; a lineage keeps everything.* Death is still a clean restart as the
   born cell, three organs, all tier 1. What was added is persistence **inside**
   one run, which is what turns a sawtooth into an arc.

## 2. The four parameters

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | What triggers division? | **`DIVIDE_RADIUS = 40`, automatic ✓ recommended** / player chooses / a timer / food banked | At radius 40 the slot ladder saturates at seven and the body can hold no more genome — it can get bigger but it cannot become anything it is not already. So it divides. The player's control is *when to take the last meal*, and the body tells them two meals out (§4). |
| 2 | Do daughters inherit tiers? | **inherit the DNA exactly, `INHERIT_TIER_LOSS = 0` ✓ recommended** (and see `dna-strand.md` §3: the DNA is inherited exactly, but each locus now *rolls* for whether the daughter wears it) / every gene drops one tier / all tier 1 | Inherit and the run compounds: each generation starts as the thing you spent the last one designing, and the price is upkeep on a small body. Drop a tier and every generation re-earns the same ground. Tier 1 makes generations a series of fresh starts with a costume change. |
| 3 | How do the daughters differ? | **same mass, one faithful and one with a single visible mutation ✓ recommended** / asymmetric mass / both mutated / identical | Your plan against one sideways variation of it, both drawn as real bodies before you choose. It is not a gamble — you can see exactly what the mutation did. Both mutated would mean your plan never survives; identical would mean there is no choice. |
| 4 | What does death cost? | **the run ends; restart as the born cell ✓ recommended** / you wake as the sister | A generation measures about two minutes (§5), so a run that reaches generation five is roughly ten and restarting is quick. Waking as the sister halves the stakes and doubles the run; it is the mercy option, and it is one saved snapshot if the owner wants it. |

### 2.1 Why radius 40 survives losing its old reason

`genes-and-cilia.md` justified 40 twice, and both are withdrawn by
`edibility.md` §4: *"nothing left in the water can eat you"* and *"the genome
fills on the same meal"*. The second is also **false in the shipped build** —
measured, a real forager reaches r40 carrying four or five genes in seven slots,
because tiers absorb meals faster than new genes arrive.

What is left is enough on its own: `SLOT_MAX` is 7, the body has exactly seven
arcs, and `slots_for(40) = 7`. **Forty is where a body runs out of places to put
an organ.** Growth past it is the one thing a cell can do that buys nothing it
can pass on, which is why growth clamps there — and clamping it deletes the
runaway I measured, an `r82` body with a gape of 114 four minutes into a run
with no terminal state of any kind.

### 2.2 The split, and the three mutations

```gdscript
const DIVIDE_RADIUS := 40.0        ## and cell.radius clamps here
const DIVIDE_WARN_RADIUS := 32.0   ## two meals out; the nucleus starts to double
const DIVIDE_SPLIT := 0.5          ## of the mother's AREA, not her radius
const MUTATION_COUNT := 1
```

> **`DIVIDE_WARN_RADIUS` was 37 and moved with `GROWTH_PER_MEAL`
> (`dna-strand.md` §4).** It is written in meals, not in units: at four units a
> meal, a warning starting at 37 is three quarters of one meal wide and the
> doubling nucleus fires on no frame anybody sees. 32 is two meals again.

Area halves, so a daughter is `40 / sqrt(2) = 28.28` — and `slots_for(28.28)` is
3, the same capacity a run starts with. The lineage begins each generation four
units ahead of where the run began and with exactly the room to manoeuvre it had
on day one. None of that was arranged; it falls out of conserving area on a
ladder that was already there.

The mutation is drawn from three kinds, all **sideways** — none is better or
worse than the DNA it came from, or the choice collapses:

| kind | what it does | why it is legible |
| --- | --- | --- |
| **shift** | one gene moves to a different slot | the slot is the arc, so an organ appears somewhere else on the body |
| **trade** | one gene +1 tier, another −1 | one fringe is longer and denser, another shorter and sparser |
| **drift** | one gene is replaced by one the lineage does not carry, at the same tier | a whole organ changes colour and shape |

Rendered, all three at both shapes: **drift is unmistakable, shift and trade
read on comparison.** That is the right ordering — comparison is the only thing
the player is being asked to do.

## 3. Two registers on one strip

> **The pips are superseded by `docs/design/dna-strand.md` §1.2.** The argument
> below is unchanged and is the reason the strand has the mark it has: the DNA is
> the strip, the body is the other register, and the distinction has to be
> **shape**. What changed is where it lives. A copy the body expresses is a rung
> that reaches both backbones; one the DNA carries and the body does not floats
> clear of them — which is the rooted-against-adrift vocabulary this section
> rejected at 76 px and which works at a rung's scale. The 635-of-720 column
> measurement is re-taken there: it is 678 of 720 now, with the camera panel that
> shipped after this was written.

The hard part. The panel has to say what you *are* and what your children *will
be*, and the space it has to say it in is measured rather than assumed.

> **Measured, at 1280x720 and at 2400x1080, and identical at both because the
> canvas is 720 tall either way.** The pause column runs from y=46 to y=681 —
> **635 of 720 px, 46 clear above it and 39 below.** A second row of tiles costs
> 76 plus 10 of separation and there are 85 px of slack in the whole screen.
> **It does not fit.** That measurement, not taste, is why everything below
> happens inside the tiles that already exist.

**The strip is the DNA. The body is the other register, and it is already drawn
— it is the thing in the middle of the screen the rest of the time.** The
caption changes from `genome` to `dna`, which is the owner's own word.

**What the body dissents about is carried by the pips, which is where the tier
is already read.** Three states, and the load-bearing distinction is shape:

| pip | means | draw |
| --- | --- | --- |
| **filled** | you wear this, at this tier | `Color(hue, 0.92)`, filled — unchanged |
| **ring** | the DNA carries it, you do not | `Color(hue, 0.85)`, outline, width **1.4** |
| **faint** | neither | `Color(hue, 0.22)`, outline, width 1.2 — unchanged |

> **Rendered, then re-rendered, because the first answer failed.** The first
> version drew an unexpressed organ *lifted off its seat* — `diegetic-hud.md`
> §1's rooted-against-floating vocabulary, which is the right idea in the wrong
> place. At 76 px a 4 px lift is invisible and the tile read as *broken*, not as
> *not yours*. Photographed, dropped. The pips carry it instead, and under a
> luminance-only render — no colour at all — filled, ring and faint separate
> cleanly at 1:1. **One gene one filled pip and two rings** against **two filled
> and one faint** is readable at a glance at both shapes.

The organ picture stays rooted and keeps its geometry; a gene the body does not
wear draws its strokes at `ORGAN_UNEXPRESSED := 0.52` instead of
`Cilia.TILE_STROKE_ALPHA` 0.88. That is a second, weaker channel behind the pips
— honest about which one does the work.

```gdscript
# normal_mode.gd, _draw_tile_face -- replacing the pip loop
const PIP_DNA_ALPHA := 0.85
const PIP_DNA_WIDTH := 1.4
const ORGAN_UNEXPRESSED := 0.52
# Cilia.draw_tile_organ() gains a final `alpha := TILE_STROKE_ALPHA` argument.
```

**No new node, no new pixel, no new width.** The tile face is
`MOUSE_FILTER_IGNORE`, 76 x 76, everything else unchanged.

### 3.1 The rest of the panel

- **`Hint`** (14 px, `Color(0.855, 0.953, 0.933, 0.38)`, already allocated 19 px
  and usually empty) carries the generation when nothing is held —
  `third generation` — and the placement hint when something is. Zero pixels,
  and it is the only readout of how far into the run you are.
- **The placement hint changes one word**, because placing no longer changes
  you: `tap a slot · your daughters wear it`. Measured at 14 px in the 652 px
  column: fits with room at both shapes.
- **A newborn is over capacity and that is intended.** She carries up to seven
  genes on a body whose `slots()` is 3, so she may replace but not add until she
  grows. **Implementation trap:** `_commit_slot()` gates on
  `index >= _genome.slots()`, which would silently deaden four of seven tiles.
  It must gate on `_slot_genes.size()`.
- **The widest strip — seven slots plus a held sample — is 798 canvas px and it
  fits**, rendered at 1280x720: the block runs x=168 to x=966, because the
  trailing spacer keeps the slots centred and hangs the sample off to the left.
  `genes-and-cilia.md` §5.3 says this state "cannot happen"; that was true of
  four genes and has been false since the build shipped eighteen — seventeen
  now, since `rhabdom` was retired, which changes nothing about this.

## 4. The boundary

The largest dramatic beat the game will have, drawn entirely in the vocabulary
that exists: bodies, the fringe, the nucleus, the aperture. **No number, no
icon, no text in the playfield** beyond one onboarding line.

| phase | seconds | what happens |
| --- | --- | --- |
| **warning** | from `r37` | the nucleus **doubles**: `_draw_nucleus` draws a second core, the pair separating from 0 to `NUCLEUS_SPLIT_MAX := 0.52 r` as radius runs 37 → 40. The most legible "about to divide" image in biology, for one extra `draw_circle` pair. **0.52 was chosen by rendering it:** below about 0.40 the two cores overlap into one brighter disc, and a brighter nucleus already means the beat. |
| **quicken** | 2.4 | the beat runs up to `RICH_PERIOD 0.55` at full amplitude. Steering still works; nothing is taken away. |
| **pinch** | 1.5 | `_set_simulating(false)` — the same call a death makes. The body elongates along the heading and narrows at the waist: `OVOID_ALONG` 1.18 → 1.62 under a new `split` argument to `draw_cell`. |
| **part** | 1.0 | two bodies, each drawn by `draw_cell` from its own genome at `r28.28`, separating to `DIVIDE_SEAT_POV := 132.0` canvas px either side of centre, or `DIVIDE_SPREAD_WORLD := 160.0` world units in full vision. **Both are `is_self`**, so both are pure `SELF_TINT` and neither takes a gene tint: they are still you. |
| **choosing** | until the player acts | §4.1 |
| **commit** | 0.9 | the chosen one holds at fade 1.0, the other falls to 0 **and takes her dominant gene's tint on the way out** — the moment she stops being you is the moment she gets a colour. `_bus.revive(t)` runs the aperture open on the newborn, which is exactly the envelope it was written for. |

**Point of view may draw all of this**, and the reason is not a loophole: during
the parting both bodies are self, and `soma.gd`'s licence is *what a cell can
know about itself*. After the commit the sister is another body in the water and
point of view never draws her again.

**The figures are drawn at fade 1.0, not `soma.gd`'s `FADE 0.34`.** Rendered at
0.34 the difference between two daughters is not callable; at 1.0 it is. The
0.34 exists so the figure loses to sensations, and during the division there are
no sensations — for the only time in the game **the middle of the screen is the
loudest thing on it**, and that inversion is the beat. In full vision the world
goes to `DIVIDE_WORLD_FADE := 0.22` through `vision.gd`'s existing `_amount`,
with the two daughters drawn outside it. No camera zoom: rendered at 1:1 with
160 units between them, two `r28` bodies read, and making `ZOOM` dynamic would
touch a dozen call sites in a shipped file for a beat that does not need it.

### 4.1 Choosing, on both targets

**You lean into one.** The gesture the game already has for every other
decision — drag on touch, `A`/`D` or arrows on desktop — held past
`STEER_DEADZONE` 0.12 for `CHOOSE_HOLD := 1.0 s`. The daughter you are leaning
into rises to fade 1.0 and the other falls to 0.34 over that second, so the
commitment is drawn as it accrues and releasing early undoes it. Rendered: the
lit/dimmed pair is instantly readable at both shapes, and the dimmed one is
still legible enough to change your mind.

- **No timeout and no default.** The tree is stopped, exactly as it is during a
  death, so the choice can wait as long as it likes. A player who puts the phone
  down comes back to the same two bodies.
- **Touch targets are the screen halves** — 640 x 720 canvas px each — because
  a 96 px body is not a 48 px target with a thumb over it.
- **A tap commits nothing.** Lean only, one rule, no arming pattern in the
  playfield.
- **Which daughter is on which side is random**, so the choice is made by
  reading rather than by remembering.
- **One line of text, at the first division of a run only**, on the single
  string `perception.md` §6.1 allows: `lean into one of them`. It fades on the
  first lean, on the same state machine the steering line uses.

### 4.2 What the newborn wakes into

`_wake_up()` already does nearly all of it; division calls the same things with
one substitution.

- `cell.radius = 28.28`, `wound = 0.0`, `metabolism.reset()` — a new body, not a
  starving one. The mother spent herself.
- `genome` takes the chosen DNA as **both** body and DNA. `bonus_slots = 0`.
- **`food.setup(cell)` — the field is reseeded.** `DIVIDE_RESEEDS_FIELD := true`.
  The water around you was sized to a 40-unit body and the newborn is 28; the
  field is a treadmill already (cull at 1700, recycle to 920–1350), so this is
  that treadmill taking one large step. It re-fires the drifter-floor invariant,
  which is what guarantees the newborn a first meal she can certainly take.
- **`SISTER_STAYS := true`.** The daughter you did not take is written into field
  cell 1 as an ordinary body with her own DNA. She is your size, your mouth and
  your armour — **the one cell in the water that is an exact match for you** —
  and under `edibility.md` that is a fight decided by facing and nerve rather
  than by size. It costs one seeded body and no new system, and it answers
  "what happened to the other one" without a word.

## 5. The arc of a run

> **Re-measured after the owner's ÷4 — see `dna-strand.md` §4.** A generation is
> **three meals** now (four in the first), not twelve, because
> `GROWTH_PER_MEAL` is 4.0. In wall clock that is roughly 30–45 seconds rather
> than two minutes. The prediction below — that if a generation got much shorter
> `GROWTH_PER_MEAL` was the dial and not `DIVIDE_RADIUS` — is exactly what
> happened, in the other direction.

Measured, not estimated: a competent forager takes **ten meals in 101 seconds**
in the shipped water, and a generation is 11.7 units of radius — about twelve
meals. **A generation is roughly two minutes.** (`genes-and-cilia.md` §3.1's
"14–21 minute arc" was computed when `food.COUNT` was 4. It is 34 now, and the
figure is stale by an order of magnitude.)

**One caveat on that number, and it is `edibility.md`'s fault.** Twelve meals
was measured against a water in which most bodies could not be eaten at all.
Once anything can be taken apart the menu is the whole field, and a generation
may be considerably shorter — which is the one thing in this spec that a still
frame cannot answer and that only playing can. If two minutes becomes forty
seconds, `GROWTH_PER_MEAL` is the dial, not `DIVIDE_RADIUS`: the ladder is a
count of meals and seven arcs is not negotiable.

| generation | what it is | the question it asks |
| --- | --- | --- |
| **1** | the born cell, three organs, three slots, `r26` | what is out there |
| **2–3** | born at `r28`, wearing everything the last life wrote | can I survive being small while carrying this |
| **4–5** | dense DNA, high upkeep, over capacity from birth | **what do I drop** |

The late game is a subtraction problem and it arrives with no new system: a
seven-gene DNA at tier 2 costs `upkeep 2.26` and at tier 3 costs `3.52`, paid on
a body that started at 28 units, and a newborn over capacity cannot add a gene
without giving one up. §9.8's *"overpowered builds are allowed to exist; they
must be hard to assemble"* becomes *hard to carry*, which is better — the cost
is paid continuously instead of once.

`UPKEEP_PER_TIER` (0.18) is the dial, and generations make it matter far more
than the single-life game did. It stays the number that can only be judged by
playing.

## 6. The opening, on generation two

`genes-and-cilia.md` §11.3 grants a free sense at five seconds, unconditionally,
because *"a born cell now has no sense of any kind"*. A daughter inherits her
mother's genome and almost always has one, so the precondition is already false
and granting anyway would hand out a free gene every two minutes.

**The grant stops being "every run" and becomes what it always meant: an
invariant against blindness.** At five seconds after any birth — a run's first
cell or a daughter — *if the cell has no sensing gene at all*, one is granted as
a held sample, with `bonus_slots` if there is nowhere to put it, and the line is
said. Generation 1 always qualifies. A daughter qualifies only if the player
built a blind lineage, which is a real and rare thing to have done, and being
rescued from it is right.

The **authored first drifter** (`FIRST_DISTANCE 1000`) is not an opening
flourish — it is the drifter-floor invariant, and it re-fires with the field at
every division. Every generation is guaranteed one meal it can certainly take.
Keep it, say nothing about it.

## 7. What this changes elsewhere

- **`diegetic-hud.md` §2.1 rank 2 needs one geometric change.** Empty-slot
  socket beads sit on the skin, at the seat where the organ's bristles would
  root. Under this design the organ never roots there *for you* — it roots on
  your daughter. The beads and the held sample's thread should move **inward**:
  a ring of beads around the nucleus, one per free DNA slot, each still placed
  at the bearing of the arc it stands for, and the vesicle's thread reaching to
  the nucleus rather than to the skin. The DNA is the nucleus; that is where a
  loose gene is going. It also declutters the skin, which §2 already called
  crowded. Everything else in that document — the vesicle, the two clocks, the
  echo, `FADE_PENDING 0.68` — is untouched.
- **`genes-and-cilia.md` §3.2's four integration cases** are unchanged in
  mechanism and changed in meaning: all four now write DNA. §3.3's held sample,
  its 45-second clock and its second heartbeat are unchanged.
- **§9.4** is replaced by §1.5 above.
- **§9.7** — the player may drop a gene over their own `cytostome` — gets
  gentler and better: the mistake now costs your *daughters* a mouth, and you
  have a whole generation to see it coming on the strip and put it right.
- **`roadmap.md`'s "what the ending is for"** needs rewriting: there is no
  ending. Phase 8's bosses now have a natural place — a lineage deep enough to
  go looking for them.

## 8. What was rendered

At 1280x720 **and** 2400x1080, `--rendering-driver opengl3`, through
`tools/shot.tscn`. The three probes were throwaway and are deleted.

| frame | judgement |
| --- | --- |
| the pause column, seven slots, both shapes | fits, 635 of 720 px, 46 clear above and 39 below. **This is the measurement the whole of §3 rests on.** |
| the widest strip — seven slots, sample, arrow | 798 px, fits at 1280x720; x=168 to x=966 |
| two daughters, point of view, `trade` mutation, fade 0.34 | **fails** — the difference is not callable at the soma figure's fade |
| the same at fade 1.0 | passes; the traded tiers read as a fuller blue fringe and a shorter violet one |
| `drift` and `shift` at fade 1.0, both shapes | drift is unmistakable; shift reads as an organ in a different place |
| the leaning state, 2400x1080 | the lit/dimmed pair is immediate, and the dimmed one is still readable |
| two daughters at world scale, 160 units apart | readable at 1:1; no camera zoom needed |
| the strip with three pip states and one unexpressed organ | passes at both shapes |
| the same, luminance only, no colour | filled / ring / faint all separate. The mark does not depend on hue. |
| the doubling nucleus at `0.34 r` against a whole one | reads as one wide bright core — **too close to the beat**, rejected |
| the same at `0.52 r` | two distinct cores; unmistakable, and nothing else on the body does that |

## 9. Left open — owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | Does a run have a win, or only a depth? | **only a depth — the generation you reached ✓ recommended** / a win at some generation | A loop with no finish line suits a session game with no save, and the generation word on the pause screen is the score. A win condition would need a number on a screen that has none. |
| 2 | Is the sister left in the water? | **yes ✓ recommended** / no | Yes puts one cell out there that matches you exactly, made of the decision you just declined. No is one line simpler and loses the best free encounter in the design. |
