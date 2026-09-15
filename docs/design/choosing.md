# Choosing a daughter

The owner, in three sentences:

> "When there's a cell split, we get to choose between 2 cells. But it is nearly
> impossible to read its characteristics from the selection screen. Simply add an
> interactive genome by their side, so we can see and interact with it. This will
> make the choice real."

Extends `lifecycle.md` §4.1 and `dna-strand.md`; it changes nothing either of them
says and adds a surface neither had. Every number below was rendered under GL
Compatibility at 1280x720 **and** 2400x1080, in **both** views, and looked at;
§10 lists the frames. The prototype was built in the repository and reverted.

## 0. What the frame actually showed, before anything was designed

`before_m0_1280x720.png`, the shipped CHOOSING phase with a seven-locus DNA:

| | measured |
| --- | --- |
| everything on screen, point of view, 1280x720 | canvas x **448 .. 832**, y **284 .. 537** |
| everything on screen, point of view, 2400x1080 | canvas x **607 .. 993**, y 284 .. 537 |
| black outboard of the pair, 1280x720 | **448 px** each side |
| black outboard of the pair, 2400x1080 | **607 px** each side |

The brief said the readable difference was "one daughter had blue cilia". The
render is worse than that and in an instructive way. In `before_m0_1280x720.png`
the port daughter wears three organs and the starboard one wears six — so the
port daughter reads as **a broken cell**. She is not. She carries the same seven
genes; five of them lost an expression roll. **The screen was not merely
uninformative, it was actively misleading**, and the thing it was lying about is
the one thing `dna-strand.md` §3 exists to make legible: a gene that misses is
carried, not lost.

That is the strongest argument for the strand and it is stronger than the one in
the brief.

## 1. The decisions, in one place

1. **Two vertical strands, one outboard of each daughter.** The horizontal
   pause-screen strand cannot fit; the space beside the daughters is a tall
   space, not a wide one (§3).
2. **Seven loci, always** — not "at worst". A division can only happen at
   `radius == 40`, where `slots_for(40)` is 7, so the column is a fixed 432 px
   at every division of every generation (§3.1). Nothing reflows, ever.
3. **Both strands draw the same seven loci in the same order at the same
   heights.** Locus *i* is at the same canvas y on both, so comparing the two
   daughters is a horizontal scan at a fixed height. This is the whole
   mechanism.
4. **The strand shows the whole DNA** — worn and carried, in `dna-strand.md`
   §1.2's existing shape distinction (§2).
5. **The mutation is marked**, on both strands, at every locus where the two
   DNAs disagree. Not because comparison is too much work, but because the
   expression roll otherwise *confounds* it: the two kinds of difference would
   be indistinguishable and they mean opposite things (§6).
6. **First contact decides the gesture**, and *we* decide it, keyed by pointer
   index, before the GUI sees the event. A press that lands on a locus is a read
   and never becomes a lean, however far the finger slides; a press that lands
   anywhere else — **including a finger that was already down before the two
   daughters existed** — is a lean and stays one, over a locus, across the
   midline, on either block. Measured on the touch path *and* the mouse path
   (§4.2), where the first attempt at this rule left a thumb resting on a block
   unable to answer the division at all.
7. **One shared explanation row and one shared hint row**, centred below the
   bodies, in the pause screen's own grammar (§5).
8. **Identical in both views and at both shapes**, because the two daughters
   occupy the same screen rectangle in both — measured to within 2 px (§3.4).

## 2. What a strand shows

The whole DNA the daughter carries, at `dna-strand.md`'s vocabulary unchanged:

| channel | mark | same as pause? |
| --- | --- | --- |
| which gene | hue of the rungs + the plain word under it | yes |
| copy number | one, two or three rungs | yes |
| **worn** — she expresses it | full rung, backbone to backbone | yes |
| **carried** — her DNA has it, her body does not | a bar floating clear of both, `0.42` of the swing | yes |
| which locus / which arc | the dart | yes |
| selection | the lens between the backbones fills | yes |
| a gene she does not wear | its word at `WORD_UNEXPRESSED` 0.42 | yes |
| **the mutation** | a caret in the block's left-hand margin, on both strands | **new**, §6 |

**Carried is the whole point and it is why the answer is the DNA and not the
body.** The bodies already draw what each daughter wears; a strand that drew
only the worn genes would be a second copy of a picture the screen already has.

**One thing this screen gets that the pause screen does not: a locus is worn or
carried, never partly.** `Genome.expressed()` rolls once per gene and writes the
DNA's full copy count, so a daughter's `body[gene]` is either 0 or `dna[gene]`.
Every rung at a locus is therefore the same state, which makes a locus callable
without counting. (The pause strand can show a mixed locus, because a body can
lag its own DNA after a swap.)

## 3. Where the strands go

### 3.1 It is exactly seven loci, always

The brief asked for the true worst case rather than an assumption. It is not a
worst case; it is an invariant, and that is better:

- A division fires only at `cell.radius >= CellBody.DIVIDE_RADIUS` (40), and
  `radius` clamps there. `slots_for(40)` is **7**.
- `Genome._sync_order()` pads `_order` up to `slots()` and never truncates, so
  at a division `layout().size() >= 7`.
- `_order` can only exceed `slots()` if `_dna` holds more genes than there are
  filled slots, and it cannot: `_dna` only grows through `place(slot)`, which
  writes at an existing index and **evicts** whatever was there. So
  `_dna.size() <= filled slots <= _order.size()`, and `_order.size() == 7`.
- `Genome.mutated()` copies the order and never changes its length: `_mutate_shift`
  swaps in place, `_mutate_drift` replaces in place, `_mutate_trade` touches
  only tiers.

Measured to confirm, with a print in `_make_daughters()`:
`order=7 dna=4 slots=7 radius=40.00`.

**So the column is a fixed height and there is no layout that ever reflows.**
Empty loci are drawn — weave and pale dart, no rungs, no word — because dropping
them would break §1.3's alignment, which is the only reason the comparison works.

### 3.2 Why the pause strand cannot be reused as it stands

`LOCUS_W` 96 x 7 = 672, plus two 64 px caps = **800 canvas px**. The clear space
outboard of a daughter is **335 px** at 1280x720 (the band ends at 104, the
daughter's widest ink starts at 439) and 495 px at 2400x1080. It does not fit
horizontally at either shape. Rotated, 800 px does not fit in the **512 px** of
canvas height that clears the band (720 - 2 x 104) either.

So the pitch has to shrink, and the constraint `dna-strand.md` §1.1 states is
geometric: a locus must **begin and end at a crossing** and have its **centre at
maximum separation**, which needs an odd lobe count. **One lobe is odd.** The
proportion it was rejected on at 96 px — `96 : 36`, 2.67:1, "reads as two
crossing sine waves" — is not the proportion here:

| | lobe : swing | verdict |
| --- | --- | --- |
| one lobe of 96 (rejected in `dna-strand.md`) | 2.67 : 1 | reads as crossing waves |
| three lobes of 32 (the pause strand) | 0.89 : 1 | reads as DNA |
| **one lobe of 48 (this screen)** | **1.33 : 1** | **reads as DNA — rendered, §10** |

Three lobes at this pitch would be 16 px against 36 of swing, 0.44:1, which is
the braid the same section rejected in the other direction.

The two surfaces therefore share every mark and differ in pitch. That is worth
saying out loud: **the player learns the vocabulary on the pause screen and reads
it here**, and what carries the vocabulary is the rung states, the count, the
word, the dart and the hue — none of which changes.

### 3.3 The geometry

All canvas px. Everything not listed is `dna-strand.md`'s constant, unchanged.

```gdscript
# normal_mode.gd, under *Choosing a daughter*
const CHOOSE_LOCI := 7            ## §3.1 -- an invariant, not a maximum
const CHOOSE_PITCH := 48.0        ## one locus, along the strand
const CHOOSE_CAP_LOBES := 1       ## the lead-in and the tail
const CHOOSE_BLOCK_W := 124.0    ## 118 in the frames of §10; see the note below
const CHOOSE_COLUMN_TOP := 112.0
const CHOOSE_SEAT := 232.0        ## centre to the block's inboard edge
const CHOOSE_HELIX_MID := 34.0    ## the weave's axis, in the block
const CHOOSE_HELIX_AMP := 18.0    ## = dna-strand.md's HELIX_AMP
const CHOOSE_DART_X := 66.0
const CHOOSE_WORD_X := 77.0
const CHOOSE_CARET_X := 7.0
const CHOOSE_CARET := Vector2(9.0, 12.0)
```

Column height is `(CHOOSE_LOCI + 2 * CHOOSE_CAP_LOBES) * CHOOSE_PITCH` = **432**,
box y 112 .. 544, **ink measured at y 118 .. 537** (the caps taper in).

The weave runs down `x = CHOOSE_HELIX_MID ± HELIX_AMP * sin(PI * (lobe0 + y / CHOOSE_PITCH))`
— the pause screen's own expression with x and y exchanged. Rungs are horizontal
lines at `y = PITCH * 0.5 + (i - seat) * RUNG_GAP`, `RUNG_GAP` 8 unchanged: at
48 px of lobe the outer rung of a three-copy cluster comes out at **87%** of the
centre rung (`sin(PI/2 ± PI/6)`), against 71% on the pause strand. Flatter,
which is right at a smaller scale; the cluster still follows the lens.

Inside a block, left to right: the caret at x 2.5..11.5, the weave at 16..52,
the dart at 59..73, the word from 77 to the block's edge at 124 (§3.3's word
budget).

> **One thing the render caught and the number above does not fix.** Measured,
> the port block's ink runs x 293 .. **409** against a block whose right edge is
> at 408 — a five-letter word at `LABEL_SIZE` 13 uses the whole width and bleeds
> a pixel of antialiasing past it. Nothing collides (the daughter is 30 px
> further out) but there is no slack, and a future gene with a six-letter word
> would overflow silently. **Build it at `CHOOSE_BLOCK_W = 124`**, adding the
> 6 px on the outboard side (`offset_left = -356`, `offset_right = -232`), which
> costs nothing: the block's outboard edge lands at canvas x 284, which is still
> 180 px clear of the membrane's nominal 104 px band at 1280x720.
>
> Every frame in §10 was rendered at 118. **Built at 124** — and the tail it
> leaves is 3 px, not the 11 this note first claimed. See the word budget below,
> and note that "a six-letter word" was the wrong thing to be afraid of.

**The word budget, and it is 3 px.** `CHOOSE_BLOCK_W - CHOOSE_WORD_X` = **47 px**
of room for the word. Measured with `Font.get_string_size` at `LABEL_SIZE` 13 in
the fallback font, the widest of the eighteen in `WORDS` is `venom` at **44.00**.
Letters are not the measure — the font is proportional, and `shield` is six
letters at 38.00 against `poison`'s six at 43.00 — so what a new gene has to pass
is `get_string_size(word, ..., LABEL_SIZE).x <= 47`, not a letter count. Nothing
clips the word, so the failure is silent ink past the block's edge.

**The two blocks are identical, not mirrored**, and that is the one layout choice
with a real argument behind it. Mirrored, the two strands would be different
drawings and a player comparing them has to un-mirror one. Identical, **every
corresponding mark on the two strands is exactly `2 * CHOOSE_SEAT + CHOOSE_BLOCK_W`
= 232 + 232 + 124 = 588 px apart, horizontally, at every locus** — the eye
travels the same distance for every row, at both shapes, which is what makes a
one-locus disagreement pop out of six agreements. (`2 * CHOOSE_SEAT` = 464 is a
different number and a real one: it is the gap between the two blocks' *inboard*
edges, which is where the daughters sit. It is not the mark spacing, because
identical blocks put corresponding marks a whole block width further apart than
their facing edges are.)

> **The consequence of identical, written down so nobody "fixes" it.** The two
> blocks are the same drawing translated, so **every mark is in the same place
> within its own block on both sides** — including the caret at
> `CHOOSE_CARET_X` 7, which is therefore in the port block's *outboard* margin
> and the starboard block's *inboard* one. That reads as an oversight and is
> not. The spacing above is the mechanism of the whole screen, and mirroring the
> starboard block to put its caret outboard would destroy it: mirrored, a mark
> at x within one block faces one at `CHOOSE_BLOCK_W - x` in the other, so the
> spacing between corresponding marks would change from 588 to
> `464 + 2 * (CHOOSE_BLOCK_W - x)` — a *different distance for every column* of
> the block. The word column and the caret column would scan at different
> pitches and §1.3's fixed horizontal scan would be gone.
>
> The cost of leaving it is a caret 9 px wide sitting between the starboard
> daughter and her strand, and it was measured rather than argued: on the widest
> genome the game can produce (`cytostome 3, cirrus 3, flagellum 3`) the
> starboard daughter's outermost ink ends at canvas x 840 and the caret's base
> is the block's first ink at 874 — **33 px of clear black**, at 1280x720 in
> point of view, and 30 px in full vision where the body reads 3 px wider. It
> does not move over the beat (§3.4).

### 3.4 Why one placement serves both views

`lifecycle.md` §4 seats the daughters at `DIVIDE_SEAT_POV` 132 canvas px in point
of view and `DIVIDE_SPREAD_WORLD` 160 world units in full vision, on bodies at
`SCALE` 1.7 and at world scale respectively. Different seats, different body
sizes — and, measured, the same envelope, on the widest genome the game can
produce (`cytostome 3, cirrus 3, flagellum 3`):

| frame | port daughter's outer ink | reach from centre |
| --- | --- | --- |
| point of view, 1280x720 | x 439 | **201** |
| full vision, 1280x720 | x 438 | **202** |
| point of view, 2400x1080 | x 600 | **200** |
| full vision, 2400x1080 | x 601 | **199** |

**Within 3 px across both views and both shapes**, and it is not a coincidence:
a body reaches about `1.47 r` abeam (`OVOID_ACROSS`'s widest 0.9785 plus a tier-3
`cirrus` at `0.34 x 1.46`), so point of view gives `132 + 1.47 x 48.08 = 203` and
full vision `160 + 1.47 x 28.28 = 202`. The seat and the scale cancel. Whether
that was designed or fell out of two independently rendered numbers, it is what
lets one placement serve both views — and it is the thing to re-measure if either
constant ever moves. `CHOOSE_SEAT` 232 puts the
block's inboard edge 31 px outboard of that.

**The ink-to-ink clearance, re-measured, because it was reported three different
ways.** On the widest genome, with the ink threshold four levels above the
field's own median (14 of 255), sampled at five points across the beat in each of
four frames:

| frame | starboard, daughter ink → block ink | port |
| --- | --- | --- |
| point of view, 1280x720 | **33** | 43 |
| full vision, 1280x720 | **30** | 46 |
| point of view, 2400x1080 | **34** | 43 |
| full vision, 2400x1080 | 31–34 | 43–46 |

So **30–34 px, tightest in full vision on the starboard side**, and §3.4's
original 33 is accurate for the frame it names. Two corrections to things
written down elsewhere:

- **It does not vary over the beat.** The membrane keeps beating during
  CHOOSING and 300 000 pixels change between two samples 0.2 s apart, but a
  daughter's outermost ink stays at exactly x 840 (starboard) and x 439 (port)
  in every sample. A figure of "22 px over the beat" does not reproduce; the
  daughters' envelope is not what the beat moves.
- **The starboard side is tighter than the port side and always will be**,
  because the blocks are identical: the port block's inboard margin is the tail
  of the word, which stops early, and the starboard block's inboard margin is
  the caret column, which starts at x 2.5. That is the price §3.3 names and it
  is 10–13 px, not a collision.

The last digit of any of these is a threshold choice over a field of 14, so read
them as a range and not as a constant. On a typical genome the port figure rises
with the shorter word.

So the answer to "what does the strand do in each view" is *the same thing, in
the same place*, and it is right rather than convenient for three reasons:

- **It is measured, not assumed.** The pair occupies the same rectangle in both.
- **The DNA is not something a sense returns.** `perception.md` §4 licenses full
  vision to draw what is there and forbids point of view identity; neither is at
  issue, because a cell's own DNA is not a fact about the water. The pause strand
  already draws it identically over both views, and has since it shipped.
- **Making it view-dependent would be the novel thing.** There is no fact about
  the DNA that one view knows and the other does not.

What *is* different is what it is drawn over: full vision has the world at
`DIVIDE_WORLD_FADE` 0.22 behind it. Measured under the port block in full
vision, the field is flat at **12.1 – 15.0** of 255 from y 80 to y 160, against
a backbone at 0.66 alpha that peaks around 135. No contest.

### 3.5 What reflows at 2400x1080: nothing

The canvas is 1600x720 there, so the blocks anchor to the canvas centre and move
outward with it; the vertical stack is byte-identical. Measured:

| | 1280x720 | 2400x1080 |
| --- | --- | --- |
| strand ink, y | 118 .. 537 | 117 .. 537 |
| `lean into one of them`, y | 524 .. 538 | 524 .. 538 |
| explanation row, y | 554 .. 573 | 554 .. 575 |
| hint row, y | 586 .. 599 | 586 .. 600 |
| port block box, x (at `CHOOSE_BLOCK_W` 124) | 284 .. 408 | 444 .. 568 |
| glance peak of a strand block (σ = 6) | **62.0** | **62.0** |

The `x` row is the box the built code lays out; the rows above it were measured
at 118, where the box ran 290 .. 408. The six pixels went on outboard, so only
the left edge moved.

The extra 320 canvas px at 2400x1080 becomes margin, which is the correct thing
for a phone to do with it.

### 3.6 The membrane band

The nominal rule is 104 px from every edge. The strand's ink starts at y 118 —
**14 px clear at the top, 79 px at the bottom**. Measured rather than left at
that, because 14 is thin:

| frame | field under the port block, mean lum, y 20 / 60 / 80 / 120 |
| --- | --- |
| PART (the contour at full beat) | 39.0 / 14.4 / 13.0 / 12.2 |
| CHOOSING, full vision, 2400x1080 | — / — / 12.7 / 12.6 |
| COMMIT (the aperture shutting) | 4.3 / 4.3 / 4.3 / 4.8 |

Against a field median of 12.2. **The membrane's light stops at y ≈ 60–80 during
a division and contributes nothing measurable where the strand is**, because
`_hush()` zeroes every lobe and the band term is only 5% of the beat
(`pulse * (line * 0.50 + band * 0.05)`). The 14 px is a nominal margin over an
envelope that is not lit.

## 4. The gesture

### 4.1 The rule: first contact decides

`_read_lean()` sets `_touch_lean` from `_lean_at(position)` for a press anywhere,
and `_step_choosing` commits after `CHOOSE_HOLD` 1.0 s. A finger resting on a
locus to read it is therefore a lean, and one second later it takes the daughter.
The fix is `normal_mode.gd`'s own precedent — `PauseTap` calls `accept_event()`
so an unclaimed press in the playfield stays a steer and a claimed one does not —
generalised into one sentence:

> **The finger's first contact decides what the gesture is, and nothing after it
> can change that.** A press that lands on a locus is a read, and it stays a read
> however far the finger slides. A press that lands anywhere else is a lean, and
> it stays a lean even when it slides over a locus.

**That is not what Godot's GUI capture implements, and assuming it was is what
made the first build of this screen unanswerable with a thumb already on the
glass.** See §4.2: capture is real for the press and for the release, and absent
for the drag — which is the one event the rule is about. The rule needs a flag
per pointer and a handler that runs before the GUI does.

### 4.2 What a press on a locus must and must not do

Each locus is a `Control`, `MOUSE_FILTER_STOP`, `FOCUS_NONE`, inside a
`MOUSE_FILTER_IGNORE` column.

**Must**, on `InputEventScreenTouch.pressed` or a left `InputEventMouseButton.pressed`:
select the locus, fill its lens, set the explanation row and the hint row, and
call `accept_event()`.

**Must not**: start a lean, cancel or alter a lean already in progress, arm
anything, commit anything, take keyboard focus, or change the DNA. Nothing on
this screen is committable: there is no held sample and no placement here, so
none of the pause screen's `ARM_GUARD_MS` / `ARM_TIMEOUT_MS` machinery is needed
or wanted. A second tap on the same locus is a no-op, not a deselect — the pause
screen's rule, for the pause screen's reason.

#### What the engine actually does with a drag

The first version of this section said a locus must also consume every
`InputEventScreenDrag` it is handed, because otherwise the drag reaches
`_unhandled_input` and is adopted as a lean. **Both halves of that are wrong on
4.7**, and the second half is wrong in the direction that breaks the screen.

Read from `scene/main/viewport.cpp`:

- `Viewport::push_input` runs the **`_input` group first**, then
  `_gui_input_event`, then the unhandled pass. That order is documented
  propagation, and it is the hook this screen needs.
- At the `InputEventScreenDrag` branch of `_gui_input_event`, `gui.touch_focus`
  is looked up for the drag's index and, **when it is null, the drag is
  hit-tested afresh at its current position**. `touch_focus` is only written
  when the *press* landed on a `Control`.
- A `MOUSE_FILTER_STOP` control that is handed any pointer event has it marked
  handled one line later, whether the handler wanted it or not.

Put together: a **lean's** press lands on the playfield, on nothing, so it has no
`touch_focus`; every one of its drags is therefore hit-tested; and the first one
that passes over a locus is eaten. `_unhandled_input` never sees it. The mouse
has the same hole by the same mechanism — a motion is hit-tested whenever
`gui.mouse_focus` is null.

So the direction that was measured and fixed is the opposite of the one this
section first described. Measured at `--fixed-fps 60`, on the code as first
built:

| gesture | result |
| --- | --- |
| press at 930,300 (**on** the starboard block), slide 2 px | **never leans. Ever.** No timeout, no default, no feedback |
| press at 1100,400 (starboard open water), slide 2 px | commits at 7.92 s |
| press at 200,400 (port water), then slide to 930,300 | commits the **port** daughter while the finger sits on the starboard side |

A player whose thumb is already on the glass when the body pinches — which is
every player who was steering, and the case §4.1 exists for — could not answer
the division at all if their thumb happened to be where a block appeared.

**What the built code does instead.** Ownership is a dictionary keyed by pointer
index: `true` a read, `false` a lean, **absent a lean**. An `_input` handler,
live only while `_split >= PART`:

- registers a press as a lean and lets it through, so the GUI can route it; a
  locus that is handed it claims the index as a read from its own `gui_input`,
  on the same event, before the unhandled pass;
- lets a release through, and erases the index;
- **claims every drag and every held motion itself**, dispatching on who owns
  the pointer and never on what is under it, and consuming it so
  `_gui_input_event` is never reached.

`accept_event()` on the locus stays, because this file's other consult surfaces
consume their own press and the thing it guards is the one irreversible action
in the game — but it is **not** what makes the drags safe, and neither is
`MOUSE_FILTER_STOP`. Running before the GUI is.

**Why that is proof and not a thing that happens to work.** The hit-test fallback
lives inside `_gui_input_event`. An event consumed in the `_input` pass never
reaches `_gui_input_event`, so the fallback cannot run — for any control, any
mouse filter, any focus state, and still if the GUI's routing changes again,
because nothing here depends on the routing. The only engine behaviour relied on
is the one the same source settles: a press and its release route strictly by
`touch_focus` and are never hit-tested, so the press really does decide and a
locus can never be handed another finger's release.

#### The permanent set

Every row below is posed through `tools/drive.gd` on the input path a phone or a
desktop actually produces, and re-run whenever this screen is touched. The recipe
is §10.1; the detector is *any non-`beat` sensation after t=7.4*, and which
daughter committed is read off `--trace`'s `dna`, which differs between the two
at this seed.

Touch, a locus at (350,232) and open water at (200,400):

| | gesture | result |
| --- | --- | --- |
| **T1** | press a locus, hold | still CHOOSING |
| **T2** | press open water, hold | commits **7.92 s** |
| **T3** | tap a locus at 6.0, press water at 6.6 | commits **8.52 s** |
| **T4** | press a locus, three jitter drags of ±2 px | still CHOOSING |
| **T5** | press water, slide onto a locus | commits **7.92 s** |
| **T6** | press a locus, slide into open water | still CHOOSING |
| **T7** | press water, slide onto a locus, lift there | still CHOOSING — letting go undoes the lean, and the locus does not steal the release |
| **T8** | press water, lift before `CHOOSE_HOLD` | still CHOOSING |

**Already down before the surface existed** — pressed at t=1.0, during QUICKEN,
and slid 2 px at t=6.0. The first four are the blocker and they are why this
set exists at all:

| | gesture | result |
| --- | --- | --- |
| **A1** | press 930,300 — **on the starboard block** | commits **7.92 s**, starboard |
| **A2** | press 1100,400 — starboard open water | commits **7.92 s**, starboard |
| **A3** | press 350,300 — **on the port block** | commits **7.92 s**, port |
| **A4** | press 180,400 — port open water | commits **7.92 s**, port |
| **A5** | A1, then lift at 6.3 | still CHOOSING — rule 4 holds for an adopted lean too |
| **A6** | press port water at 6.0, slide to 930,300 at 6.3 — **arrives** on the far block | commits **8.22 s**, **starboard** |
| **A7** | press the starboard block at 1.0, slide to port water at 6.0 | commits **7.92 s**, port |
| **A8** | press port water, crossing the midline in five sampled steps | commits **8.17 s**, starboard |

**A1 and A3 never committed at all before the fix** — still CHOOSING at 9.5 s
and for as long as the thumb stayed down — and A6 committed the wrong daughter.
A2, A4, A7 and A8 are the controls that were already passing, and they still
pass unchanged.

**Desktop**, through `--mouse-press=` / `--mouse-slide=` / `--mouse-lift=`, which
exist because nothing in the harness could pose a held button before:

| | gesture | result |
| --- | --- | --- |
| **D1** | button down at 1.0 on the starboard block, moved 2 px at 6.0 | commits **7.92 s**, starboard (**never leaned** before the fix) |
| **D2** | button down on a locus at 6.0, moved 2 px | still CHOOSING |
| **D3** | button down in open water, held | commits **7.92 s**, port |
| **D4** | button down in port water, moved onto the starboard block | commits **8.22 s**, **starboard** (committed port before the fix) |
| **D5** | button down in open water, released at 6.5 | still CHOOSING |
| **D6** | `--hover=` a locus, no button | still CHOOSING; the line follows the cursor and the lens does not move |
| **K1** | `--hold=d` — the key, from before the division | commits **6.85 s**, starboard |
| **K2** | `--hold=a` | commits **6.85 s**, port |

K1 and K2 commit at 6.85 rather than 7.92 because the key is already down when
CHOOSING opens at 4.9, so the hold begins there: `4.9 + 1.0 + 0.9`. **They are
also the row that calibrates the detector** — a t > 7.4 window built around a
lean that starts at 6.0 steps straight over a commit at 6.85 and reports the
next unrelated `thrust`. Read the whole sensation log for anything that leans
earlier than 6.0.

`7.92 s` is exactly right: lean at 6.0, `CHOOSE_HOLD` 1.0, `DIVIDE_COMMIT` 0.9.
`8.22` is the same arithmetic from a lean that changed direction at 6.3.

### 4.3 What leaning costs, and it must stay cheap

`lifecycle.md` §4.1 makes the lean target a whole screen half because "a 96 px
daughter is not a 48 px target with a thumb over it". Two blocks take some of
that back. How much:

| | canvas px² | share of the half |
| --- | --- | --- |
| screen half, 1280x720 | 460 800 | — |
| one block, 124 x 432 | 53 568 | **11.6%** |
| screen half, 2400x1080 (canvas 1600 wide) | 576 000 | — |
| one block | 53 568 | **9.3%** |

And it is the *right* 11.6%. The block sits at x 284 .. 408 in the port half, so
the **outer 284 px of the half, full height, is untouched** — 204 480 px², and
that is where a thumb rests in a two-handed landscape grip. The inboard 232 px
is untouched too. Nothing is taken from either corner a thumb can reach without
moving.

And since §4.2, the 11.6% is not taken away from leaning either: a gesture that
began in open water goes on leaning across a block, and a gesture that began on
a block before the blocks existed leans from where it is. What a block costs is
only the ability to *start* a new lean by pressing on it, and the corner a thumb
can actually reach is not one of those places.

### 4.4 The keyboard, and what it does not get

The loci are **`FOCUS_NONE`**, and that is the same call
`gene-lines-and-the-pause-target.md` §4.1 made for `PauseTap`, for a sharper
reason: on this screen the arrow keys **are** the decision. A focusable control
would hand them to GUI navigation the moment anyone pressed Tab, and the player
would be unable to choose a daughter.

So: touch reads by tapping, desktop reads by hovering — which is free and
gets all seven loci with no clicks — and `A`/`D`/arrows still lean. **A desktop
player with a keyboard and no mouse cannot read a locus.** They can still make
the choice, and they can still read every gene on the pause screen. That is the
price and it is named rather than hidden; see §11.

## 5. The two lines below

The pause screen's grammar, transplanted whole: `Explain` (organ · name · line)
over `Hint`. Reading order is *strand → what this one does → what it is worth*,
which is the order the player already knows.

**This is allowed in the playfield because during CHOOSING there is no
playfield.** `_set_simulating(false)` has stopped the water, `_hush()` has
zeroed every sensation, and `lifecycle.md` §4 already says this is the one time
the middle of the screen is the loudest thing on it. It is a modal screen wearing
the playfield's clothes, so `diegetic-hud.md` §3's ban on letters — which exists
so a HUD cannot compete with the senses — has nothing to bind here.

| | |
| --- | --- |
| `Explain/Organ` | 34 x 26, `Cilia.draw_tile_organ` at scale 0.60, seat (17, 18.5) — `dna-strand.md` §1.3 unchanged |
| `Explain/Gene` | 15 px, `Color(Cilia.hue(gene), 0.95)` |
| `Explain/Line` | 15 px, `EXPLAIN_TINT` `Color(0.855, 0.953, 0.933, 0.62)`, `"· " + EXPLAINS[gene]` |
| `Hint` | 14 px, `Color(0.855, 0.953, 0.933, 0.38)`, centred |

The hint gains one clause at the front and invents no words:

```
worn · two copies · a daughter probably wears it
carried · one copy · a daughter may not wear it
worn · the mouth · a daughter always wears it
an empty locus · nothing to pass on from here
```

`HINT_CHANCE`, `HINT_CERTAIN` and `HINT_EMPTY` are `dna-strand.md`'s, verbatim.
The new clause is the one thing the copy count cannot say — **whether this
daughter got it** — and it is the register the rung shape is drawing, in words,
for the same reason the pause screen says the odds out loud.

**One row, shared, not one per side.** The eighteen lines are about the gene, and
both strands carry the same gene at five or six of seven loci, so a per-side line
would be the same sentence twice in most frames. The arithmetic agrees: the
longest line, `toxicyst`, measures **519 px** with its organ; two of them
centred under daughters 264 px apart overlap by 255 px. Which strand is being
read is carried by the lit lens, on the thing the finger just touched.

Measured, on the longest line at 1280x720: explanation ink x 381 .. 900,
y 556 .. 573, against the blocks' lowest ink at y 537. **19 px of vertical
clearance**, and the horizontal overlap is therefore not a collision.

**The screen opens with a locus already selected**, and the locus it opens on is
**the first one the two DNAs disagree at, on the port daughter.** The pause
strand's rule — *never nothing*, because a surface that opens blank has to teach
the tap with a line of instructions — and here the locus that most wants reading
is the reason there are two daughters at all. It demonstrates the tap, the caret
and the hint in one frame, and it is why normal mode needs **no second authored
string**: `lean into one of them` is still the only one. If a DNA has no
disagreement at all (a one-gene lineage, where `mutated()` returns `&""`), it
opens on the first locus that carries anything.

## 6. The mutation mark

**The set of loci at which the two DNAs disagree, marked on both strands.** A
solid caret, 9 x 12, at `CHOOSE_CARET_X` 7 — the block's **left-hand** margin,
x 2.5 .. 11.5 of a block whose weave starts at 16 — pointing right at the weave,
in that locus's own hue on that strand (`PALE` where the locus is empty).

**"Left-hand", not "outer", and the difference matters.** The two blocks are the
same drawing translated, not mirrored (§3.3), so the caret is in the *outboard*
margin on the port strand and the *inboard* margin on the starboard one, where it
sits between the daughter and her own strand. That looks like a mirroring bug and
is the opposite: mirroring the starboard block would give every column of the
block a different spacing to its opposite number — 588 px for the caret, more for
the weave, more again for the word — and the constant 588 is the mechanism §1.3
names. §3.3 has the arithmetic and the 33 px of measured clearance that pays for
it. **Do not "fix" the mirroring.**

Computed by comparing, not by asking `mutated()` which kind fired:

```gdscript
for i in CHOOSE_LOCI:
    if port.order[i] != starboard.order[i] \
            or port.tiers.get(port.order[i], 0) != starboard.tiers.get(starboard.order[i], 0):
        diff[i] = true
```

That covers all three kinds with no special cases — `shift` marks the two slots
that swapped, `trade` the two whose counts moved, `drift` the one whose gene was
replaced — and it stays correct if a fourth kind is ever added.

**Why it is drawn at all, when `lifecycle.md` §2.2 says comparison is the skill.**
Because the expression roll confounds it. Both kinds of difference land on the
same seven rows, and they mean opposite things:

| difference between the strands | what it is | heritable? |
| --- | --- | --- |
| a hue, a word, or a rung **count** | the mutation | **yes** |
| a rung **shape** — full against floating | the expression roll | no, it rolls again |

Rendered, `p3_seed2`: the port daughter disagrees with the starboard one at
**four** of seven loci. Two of those are the trade (`eat` 2→1, `ping` 1→2) and
two are expression. Without the caret the player is asked to find a ±1 rung count
at 464 px of separation inside four other disagreements that look just as loud.
With it, the answer is two triangles. **The caret is not doing the comparison for
the player; it is separating two channels that would otherwise be one.**

And it is honest about what it claims: it marks *difference*, which is exactly
what the player is choosing between. It never says which is better, because
`lifecycle.md` is right that nothing here is.

## 7. Colour, and the check that matters

Every hue on this surface is `Cilia.hue(gene)` — unchanged, and already bound by
`genes-and-cilia.md` §4.4's 30° rule. Nothing new is introduced. The backbone
stays `BACKBONE` `Color(0.24, 0.80, 0.68)` — the cell's own teal, because the
strand is her and the rungs are what she is made of.

**Rendered in pure luminance, with no colour at all** (`cb_grey.png`): worn
against carried, the copy count, the caret, the selected lens, the dart and the
dim/bright word all separate cleanly. The only channel that dies is gene
identity by hue — and the plain word is under every locus, which is precisely
the mitigation §4.4 names. The mark does not depend on colour anywhere.

## 8. What is drawn when

| phase | the strands |
| --- | --- |
| `QUICKEN`, `PINCH` | not drawn — there are not two bodies yet |
| `PART` (1.0 s) | fade in on `_split_clock / DIVIDE_PART`, arriving with the daughters |
| `CHOOSING` | full, each block at `_side_fade(side)` |
| `COMMIT` (0.9 s) | the whole surface fades on `1 - _split_clock / DIVIDE_COMMIT`, each block still at `_side_fade(side)`, so the declined strand goes out with her body |
| `_be_born()` | gone |

**Each block takes its daughter's `_side_fade(side)`.** A lean brightens one
strand and dims the other on exactly the curve the bodies use, so the commitment
is drawn as it accrues on the reading surface too, and a declined daughter is not
left half-drawn. `_side_fade` is read, not recomputed, so
`lifecycle.md`/`replay.md`'s brightness round-trip is untouched — **no shipped
constant moves and the replay reconstructs the same pair of brightnesses it did
before.**

Glance, σ = 6 on the 8-bit output, the measurement `diegetic-hud.md` §4 uses:

| | 1280x720 | 2400x1080 |
| --- | --- | --- |
| a daughter's body, point of view | **113 – 114** | 113 – 114 |
| a daughter's body, full vision | **112 – 122** | 112 – 122 |
| a strand block | **62.0** | 62.0 |
| explanation row | 44 – 45 | 45 – 46 |
| `lean into one of them` | 44 | 44 – 45 |
| hint row | 34 | 34 |

`lifecycle.md` §4's inversion survives: **the bodies are still the loudest thing
on the screen, by nearly two to one.** The strands are what you consult; the
bodies are what you choose.

## 9. The node tree

```
Hud  (CanvasLayer)
  Onboarding        Label             unchanged
  Choosing          Control           NEW -- PRESET_FULL_RECT, MOUSE_FILTER_IGNORE
    Port            VBoxContainer     separation 0, MOUSE_FILTER_IGNORE
      Head          Control           124 x 48, IGNORE
      Locus0..6     Control           124 x 48, STOP, FOCUS_NONE
      Tail          Control           124 x 48, IGNORE
    Starboard       VBoxContainer     identical
    Says            VBoxContainer     separation 4, MOUSE_FILTER_IGNORE
      Explain       HBoxContainer     separation 4, ALIGNMENT_CENTER, min (0, 26)
        Organ       Control           34 x 26
        Gene        Label             15 px
        Line        Label             15 px -- see the note below
      Hint          Label             14 px, centred
  PauseTap          Control           unchanged -- hidden during a division
  Watch, Pause                        unchanged; Pause's scrim covers Choosing
```

`Port`: `anchor_left = anchor_right = 0.5`, `offset_left = -356`,
`offset_right = -232`, `offset_top = 112`, `offset_bottom = 544`.
`Starboard`: `offset_left = 232`, `offset_right = 356`, same y.
`Says`: `anchor_right = 1.0`, `offset_top = 552`, `offset_bottom = 610`.

**The explanation's second label is `Explain/Line`.** This section first called
it `Explain/Says`, inside a container also called `Says`, which is two different
things with one name at two depths of the same path — `Hud/Choosing/Says/Explain/Says`.
The container keeps the name (it is the pause screen's, and both rows under it
are things the screen says); the label is `Line`, which is what the eighteen
authored strings are called everywhere else in this document.

A locus target is **124 x 48 canvas px** = 186 x 72 device px at 2400x1080, and
124 x 48 on a 1280x720 handset — the floor case, exactly at the 48 px rule.
Separation is 0 so the weave is continuous and adjacent targets touch; a mis-tap
costs nothing, because selection is free, reversible, and commits nothing. That
is the pause strand's argument and it is stronger here, since there is no
irreversible action on this screen at all.

### 9.1 One thing to build, not to copy

**`_draw_weave`, `_draw_lens`, `_draw_rungs` and `_cap_fade` live in
`normal_mode.gd`, not in `cilia.gd`.** The brief assumed otherwise. They must be
lifted to `static func`s that take an axis — `cilia.gd` is the right home, since
it already carries `draw_slot_dart` and `draw_tile_organ`, which are the strand's
other furniture — and **both** surfaces must call them. The prototype duplicated
them to get a render; shipping that duplication would mean two helixes drifting
apart, which is the exact failure `diegetic-hud.md` avoided by making the vesicle
one routine called from two views.

### 9.2 The harness flags this needs

`tools/drive.gd` had only `--touch=`, which presses **and releases** in one
frame. A tap commits nothing by design, so the rule in §4 — *a finger resting on
a locus is not a lean* — cannot be posed with it at all. Six flags were added;
`tools/` is export-excluded, so they cost nothing:

```
--press=<seconds>:<x>,<y>         one finger down there, never released
--slide=<seconds>:<x>,<y>         finger 0 moves there, with no fresh press
--lift=<seconds>                  finger 0 lets go, wherever it has got to
--mouse-press=<seconds>:<x>,<y>   left button down there, held
--mouse-slide=<seconds>:<x>,<y>   the cursor moves with the button still down
--mouse-lift=<seconds>            the button is released
```

Same convention as `--touch=` throughout: **seconds first, canvas coordinates,
unscaled.** Every measurement in §4.2 was taken through them.

**The three `--mouse-` flags were added by the fix in §4.2**, because the desktop
has the same hole the touch path did and nothing in the harness could pose a
*held* button: `--hover=` warps the cursor with no button down, which is the one
case that was never broken. Their absence is why "desktop still works" was a
sentence nothing here could check.

## 10. What was rendered, and judged

At 1280x720 **and** 2400x1080, `--rendering-driver opengl3`, through
`tools/shot.tscn` with `tools/drive.tscn`.

### 10.1 The recipe, and it does not reproduce without `--fixed-fps 60`

```
xvfb-run -a -s "-screen 0 1280x720x24" ~/godot/godot --path . \
    --rendering-driver opengl3 --fixed-fps 60 res://tools/shot.tscn -- \
    --scene=res://tools/drive.tscn --out=/tmp/x.png --size=1280x720 \
    --wait=6.0 --seed=12345 --mode=0 --radius=40 \
    --dna=cytostome:3:0,cirrus:2:1,flagellum:3:2,stigma:1:3,ampulla:2:4,pellicle:1:5,toxicyst:2:6
```

Every clause earns its place:

| | why |
| --- | --- |
| `--fixed-fps 60` | **The one that was missing.** Without it, two runs of byte-identical code on this exact frame differ by **239 010 pixels, max delta 50** — the membrane's beat phase lands wherever the wall clock left it. (A quieter frame was measured at 21 834 and delta 3; the number is the frame's, the fault is the same.) With the flag, the two runs are **0 pixels apart**. Every "byte-identical" claim in this document is void without it |
| `--radius=40` | puts the body at `DIVIDE_RADIUS`, so the split begins on the first frame: QUICKEN 2.4 + PINCH 1.5 + PART 1.0 means **CHOOSING opens at t ≈ 4.9** and a `--wait=6.0` lands in the middle of it |
| `--seed=12345` | fixes the drift and the impulses, and therefore which daughter is the mutant. At this seed the port daughter is the faithful one |
| `--mode=0` | full vision runs its water shader on `TIME`, which no seed reaches |
| `--dna=` and not `--genome=` | raises the DNA and leaves the **body** alone, so the expression roll cannot change what is worn between runs. This is what makes a dense strand reproducible at all |
| no `--touch=`, no held sample | both move state the strand draws |
| `--size=` on the harness **and** the matching `-screen` on xvfb | the window and the X display have to agree or the shot is letterboxed |

**For a gesture rather than a frame**, the PNG is beside the point and the log is
the measurement: add `--wait=11.0 --trace=0.5` and the gesture flags. The commit
time is the first non-`beat` sensation after t=7.4, and which daughter committed
is `--trace`'s `dna` after t=8.3 — at seed 12345 the port daughter prints
`[cir1 cyt1 fla1]` and the starboard one `[cyt1 fla1 pel1]`.

**Use `[trace]` and not `[drive]`'s sensation log** for anything about the
simulation itself: the bus prints the beat every 0.55 s, which is a noise floor
above the signal, and two runs that differ can look identical in it.

| frame | judgement |
| --- | --- |
| **before**, both views, both shapes | the record: two bodies and 448–607 px of black either side, and a port daughter who reads as broken and is not |
| seven loci, both strands, point of view, 1280x720 | passes — the two ladders line up and the disagreement is two rows |
| the same, 2400x1080 | passes; identical stack, 320 px more margin |
| the same, full vision, both shapes | passes; the dimmed world reads 12–15 of 255 under the block |
| **the same, in pure luminance, no colour at all** | passes; worn/carried, the count, the caret, the lens and the dart are all shape |
| a `trade` (`p3_seed2`) | passes, and it is **the frame that justifies the caret**: four loci disagree, two of them are the mutation |
| a `shift` (`p3_seed4`, `long_1280x720`) | passes; two words and two darts trade places, both marked |
| a `drift` (`p3_sparse`, `p3_dense`) | passes; unmistakable without the caret, confirmed by it |
| a sparse DNA — four genes in seven loci | passes; the empty loci draw weave and dart and keep the ladders aligned |
| the densest DNA — seven genes, 3/3/3/2/2/1/1 | passes; three rungs at 8 px inside a 36 px lens are countable |
| the widest genome — `cytostome 3, cirrus 3, flagellum 3` | passes; **30–34 px** ink-to-ink, starboard side, across both views and both shapes, and it does not move over the beat (§3.4) |
| a locus selected, port and starboard | passes; lens, loud word, organ, name, line and hint all land |
| the longest line, `toxicyst`, 519 px | passes; 19 px clear of the strands' lowest ink |
| hover, desktop, while a different locus is selected | passes; the line follows the cursor, the selection keeps its lens |
| **press a locus and hold 3 s** | passes — still CHOOSING, nothing on the bus |
| **press a locus, finger jitters 2 px** | passes — still CHOOSING |
| **press a locus, slide into open water** | passes — still CHOOSING |
| **press open water, hold** | passes — commits at exactly 7.92 s |
| **press open water, slide onto a locus** | passes — commits; the strand does not steal a lean in progress |
| **a thumb already down on a strand block when the daughters appear** | passes — the lean accrues from where the thumb is, the leaned strand rises and the declined one falls. **This frame was identical to no input at all before §4.2's fix** |
| **the same thumb, on the opposite block from where the lean began** | passes — the lean follows the finger across the midline and commits the side it ended on |
| tap a locus, then lean | passes |
| leaning, part way | passes; the leaned strand rises and the declined one falls with its body |
| `PART`, fading in | passes |
| `COMMIT` | passes; the declined strand goes out with her, the whole surface fades |
| the membrane band under the block, PART / CHOOSING / COMMIT | passes; 12.2 / 12.6 / 4.8 against a 12.2 median |

## 11. Considered and rejected

- **Two horizontal strands under the daughters.** 800 px each into 640 px of
  half-screen. Arithmetic, not taste.
- **One shared horizontal strand across the bottom**, two daughters as two rows
  of rungs on one backbone — literally sister chromatids, and genuinely
  tempting. Rejected: 800 px fits at 1280x720 with 240 to spare, but it puts the
  reading 300 px from either body, it is not "by their side", and the
  worn/carried register has to be doubled onto one locus, which is the one thing
  the rung shape cannot say twice.
- **Drawing only the worn genes.** That is a second copy of the bodies. The
  carried register is the entire new information and it is what the owner asked
  for.
- **Not marking the mutation.** Right in principle (`lifecycle.md` §2.2), wrong
  once the expression roll is on the same seven rows — §6's four-disagreements
  frame is the evidence.
- **Marking the mutation by brightening its stretch of backbone, or its word.**
  Both collide with selection, which already owns `BACKBONE_LIT` and
  `LABEL_TINT_LOUD` on the pause screen. Reassigning a mark's meaning between two
  surfaces is worse than adding one.
- **Mirroring the two blocks** so both word columns face inward. Costs the equal
  464 px spacing that makes the row-by-row scan work.
- **A per-side explanation line.** §5: the same sentence twice, and two 519 px
  lines centred under daughters 264 px apart overlap by 255 px.
- **Focusable loci with Tab navigation.** Takes the arrow keys away from the
  decision itself.
- **Three lobes per locus at this pitch.** 16 px against 36 of swing is the
  braid `dna-strand.md` §1.1 rejected, seen from the other side.
- **A 44 px pitch** (a shorter column, more air). 44 canvas px is under the 48 px
  touch rule on a 1280x720 handset.
- **Moving `DIVIDE_SEAT_POV` or `DIVIDE_SPREAD_WORLD` to make room.** No room was
  needed, and `replay.md` §4.1 makes those numbers expensive to touch.

## 12. Left open

1. **The replay will not show the strands.** `recorder.gd` records a division as
   one float — the brightness difference — and `panes.gd` replays two bodies with
   no DNA behind them. So a replayed division is the *old* frame, which is the
   thing `replay.md` §4.8 says this screen may not do. It is not a regression
   (nothing changed there) but it is a new divergence. Recording two seven-locus
   genomes per division is the fix and it is not free; not built here, and not
   this spec's call.
2. **Discoverability of the tap, on a player who has never opened pause.** The
   screen opens with a locus lit and its sentence underneath, which is the pause
   strand's own answer, and no instruction is authored. Whether that is enough is
   a thing only a player can say.
3. **The keyboard-only desktop player cannot read a locus** (§4.4). Hover covers
   the mouse; `A`/`D` still decide. Re-judge if anyone plays this game on a
   laptop with no trackpad.
4. **The default selection lands on the port daughter.** Which daughter is
   faithful is already random, so it carries no bias about the *choice* — but it
   does put one lit lens on one side from the first frame. Cheap to flip to
   "whichever side the mutation is louder on" if it ever reads as a nudge.
5. **`rhabdom` (`focus`) and `cytostome` (`eat`) are close in hue**, and on a
   dense strand they can sit at adjacent loci (`p3_dense_1280.png`). Both obey
   §4.4's 30° rule and both carry a word, so nothing here fails — but it is the
   tightest pair on the wheel and this is the first surface that ever puts them
   48 px apart.
6. **On Android a thumb that is leaning re-labels the explanation row**, because
   Godot emulates a mouse from every touch and the emulated motion raises
   `mouse_entered` on whatever locus the thumb is over. The lens does not move
   and nothing commits; only the two lines below change, to the gene the thumb
   happens to be resting on. **Pre-existing** — rendered on the code before
   §4.2's fix and after, and identical in both — and not the same on desktop,
   where §4.2 claims a held motion before the GUI sees it and hover therefore
   stops while a lean is in progress. One gesture, two platforms, two answers.
   Left alone because it is a divergence in the *quietest* channel on the screen
   and closing it means consuming the emulated echo of a finger, which is a
   change to how this file treats touch-to-mouse emulation everywhere. Worth
   fixing the day anyone finds it distracting.

## 13. Owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | Should the screen say which daughter is the mutant? | **no — mark only the loci where the two disagree ✓ recommended** / name one of them the mutant / mark nothing at all | Recommended: the screen points at the rows that differ and lets you decide which you want. Naming one "the mutant" would tell you which is the safe one, and the safe one is not always the better one. Marking nothing means finding a one-copy difference by eye, among differences that look identical and mean something else. |
| 2 | Should reading a locus be possible at all during the choice, or should the strands just be a picture? | **interactive — tap or hover a locus for its line ✓ recommended** / a picture only, no touch | Recommended: the eighteen gene lines already exist and this is the moment they are worth most. The cost is that about a tenth of each screen half stops being a place you can lean from — the outer third, where a thumb rests, is untouched. A picture-only strand keeps the whole screen leanable and makes a player who has forgotten what `ampulla` does guess. |
| 3 | Should a division be replayable with its strands? | **no — leave the replay as it is ✓ recommended** / record both daughters' DNA so the replay matches | Recommended: watching a run back shows what you felt and what you did, and consulting a surface is neither — the replay already skips the pause screen for the same reason. The alternative makes the replay of a division match the division exactly, and costs the recorder two whole genomes at every split. |
