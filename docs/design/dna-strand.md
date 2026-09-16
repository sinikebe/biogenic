# The DNA strand

The owner, in three sentences:

> "Now, genome rework. Instead of square slots, draw a dna. When ingesting a
> gene, it gets a chance to be expressed in an offspring. Divide the split
> requirements by 4 since it's too long before having a division."

Three changes, and only the first is a drawing. Replaces `genes-and-cilia.md`
§5.2–5.3 (the tile strip) and `lifecycle.md` §3 (the pips); everything else in
both stands.

**Which reading of the middle sentence was built, up front: (a).** Eating a gene
writes it into the DNA exactly as before, and **each locus then rolls for
expression in each daughter**. A gene that misses is not lost — it stays in the
DNA and rolls again in the next generation, which is what a recessive trait is.

## 1. The strand

**A chromosome, not a row of boxes.** A real chromosome is a strand, genes sit at
loci along it, and a locus is exactly the slot-is-an-arc idea the game already
had. The biology handed the layout over; the row of squares was the invented
thing. Every channel the tiles carried moves to a place on the strand that is
more literal than the place it had on a tile:

| carried | on the strand |
| --- | --- |
| the plain word | under its own locus, where a chromosome map puts it |
| **tier** | **copies**: one, two or three rungs at the locus |
| which arc | the dart, beside the word — unchanged geometry, new seat |
| the two registers | a rung that reaches both backbones is worn; one floating clear in the middle is carried and not worn |
| selection | the lens between the backbones fills; the word goes loud |
| the held sample | a loose base pair floating over the locus it is bound for, on a thread |

**Tier became copy number, and that is the change everything else hangs off.**
Gene dosage is real — more copies of a gene means more of it is transcribed — so
copy number is what decides the expression chance in §3. One channel, three
meanings, and the count is the picture.

### 1.1 Geometry

All in canvas px, in `normal_mode.gd` under *The strand*.

```
LOCUS_W 96   LOCUS_H 86   LOCUS_LOBES 3   LOBE_W 32   CAP_LOBES 2   CAP_W 64
BAND_MID 13   HELIX_MID 47   HELIX_AMP 18   LABEL_MID 76   LABEL_BASE 81
```

A locus draws its own slice of the weave, from global lobe `lobe0`:

```gdscript
s = sin(PI * (lobe0 + x / LOBE_W))      # x is local to the control
y_a = HELIX_MID - HELIX_AMP * s
y_b = HELIX_MID + HELIX_AMP * s
```

**`LOCUS_LOBES` must be odd, and that is geometry rather than taste.** A locus
has to begin and end at a crossing so neighbours join with no seam, and its
centre has to be at maximum separation so every rung is the same length wherever
it sits. Only an odd count does both — which is why a locus cannot be one flat
lens at any width you like. One lobe of 96 px against 36 of swing is 2.7:1 and
reads as two crossing sine waves; three of 32 is round and reads as DNA. Built
both ways.

**Depth is alpha, per point.** `draw_polyline_colors`, one call per strand per
control, with `lerp(BACKBONE_BACK 0.13, BACKBONE_FRONT 0.66, (cos t + 1) / 2)`
and the complement on the other strand. At a crossing one strand is bright and
the other faint, and they trade every half turn — that is what makes it a helix
instead of a braid. No node, no texture, no shader, **no new uniform**.

The lead-in and the tail ramp both amplitude and alpha to nothing over two
lobes, so the chromosome arrives and leaves rather than starting mid-lens.

### 1.2 The three rung states

| state | draw |
| --- | --- |
| **worn** — this body expresses this copy | `Color(hue, 0.92)`, width 3.0, backbone to backbone |
| **carried** — the DNA has it, the body does not | `Color(hue, 0.88)`, width 2.6, centred, `0.42` of the swing each side, touching neither |
| — | there is no third mark; a locus draws exactly as many rungs as it has copies |

Worn against carried is **shape**, so it survives a luminance-only render and
`genes-and-cilia.md` §4.4's deuteranope rule. Rendered in greyscale with no
colour at all: a full rung and a floating bar are still two different objects.

> **`lifecycle.md` §3 rejected floating-against-seated and it was right to.** At
> 76 px a 4 px lift is invisible, and the tile read as broken rather than as not
> yours. Here the gap is a third of a 32 px rung and the mark is the rung itself,
> not a decoration on it. Same idea, a scale at which it works.

> **A rung answers *does this body express this gene*, and nothing narrower.**
> `moving-a-gene.md` added a second strand above this one, labelled `body`, and
> tried narrowing this row's rung to *worn on **this** arc* at the same time.
> That put two facts on one mark — a gene you own and moved drew exactly what a
> gene that missed its roll draws, **0 differing pixels** at the locus — and it
> contradicted the line under the strand for `cytostome`, which `ALWAYS_EXPRESSED`
> guarantees. Reverted. *Where* an organ is worn is the body row's question and
> the body row answers it in words; this row answers *whether*.

> **The cluster is centred on the copies it has**, not on three fixed places with
> the empty ones ghosted. The ghosts were built and photographed: at 1 px and 15%
> alpha they were invisible, and paying for them cost a one-copy locus its
> centring — its single rung sat a third of a lens off the maximum and came out
> shorter than every other one-copy locus on the strand. Centred, one copy is the
> longest rung the strand can draw, which is the right emphasis.

### 1.3 The one organ

The tiles each drew their gene's organ, which is what taught a point-of-view
player the cilia vocabulary (`genes-and-cilia.md` §2.4). A strand has nowhere to
put seven of them, and seven small tufts over a chromosome is the four-tuft
mistake `diegetic-hud.md` §2 already made and measured.

**One organ, at the thing the player is reading**, in the explanation row that
already existed: `Explain/Organ`, a 34 x 26 `Control` before the name, drawing
`Cilia.draw_tile_organ` at `scale 0.60` seated at `(17, 18.5)`. The seat is
measured, not chosen — `flagellum` reaches `TILE_ARC_RADIUS + TILE_LEN` above its
centre, 18 px at this scale, so any seat above 18.5 puts the tuft outside its own
row.

### 1.4 Touch, focus and the two taps

- **The whole locus is the target**: 96 x 86, which is 144 x 129 device px at
  2400x1080 against a 48 px rule. `Row` separation is **0** so the weave is
  continuous; adjacent targets touch, and a mis-tap still costs nothing because
  arming is reversible — the same argument the 20 px tile gap was made on.
- **Focus is an underline**, not a box: `FOCUS_INSET 14`, width 2, at the
  locus's bottom edge. A focus rectangle would put the square back.
- **The two taps, the 300 ms guard and the 4 s timeout are unchanged.** The
  guard is still measured press-to-press; what `moving-a-gene.md` §3.7 moved is
  which half of the second tap the DNA is written on, because once a locus can
  also be dragged, a press on it is two gestures at once. The placement lands on
  the lift.
- **Nothing in the row moves when a sample arrives or lapses.** The strand is the
  same width held or not, so `genes-and-cilia.md` §5.2's invisible trailing
  spacer is deleted rather than kept.

## 2. The held sample

A base pair that is not in a ladder yet: a bar with a base at each end, two
halo rings (not a disc — `diegetic-hud.md` §2's argument), and the plain word
beside it, in the band the locus already reserves above the weave.

- **Nothing selected** — it waits over the **lead-in**, off the head of the
  chromosome, attached to nothing and with no thread. That is the truthful
  picture of a gene with no place yet, and it makes the first tap obvious.
- **A locus armed** — it sits over that locus with a bowed thread down to where
  its rung would go, and the locus shows a **carried** ghost rung in the sample's
  hue. A placed gene is written to the DNA and not to this body, so the preview
  is a floating bar: the one frame in the game where the player can see that
  placing changes their daughters and not themselves.

The sample is no longer a target of its own. Instead: **an empty locus explains
the sample; an occupied one explains its own gene**, because that is what a
second tap would overwrite and it should be read first.

## 3. A copy is a chance

```gdscript
# genome.gd
const EXPRESS_CHANCE: Array[float] = [0.0, 0.55, 0.80, 1.00]   # by copies
const ALWAYS_EXPRESSED: Array[StringName] = [&"cytostome"]
static func expressed(dna: Dictionary) -> Dictionary
```

`express(dna, order, body)` takes what expressed as a third argument; `null`
means *expressed whole*, which is what a run's first cell and a forced genome
are. **`null` and not an empty dictionary**, because "nothing expressed" is a
real roll.

**One copy is a coin toss, two is likely, three is certain.** A player who wants
a gene guaranteed can buy the guarantee by feeding it, which is the answer to the
obvious objection — that a chance takes determinism out of the build. It does
not remove determinism; it prices it.

**The mouth always expresses.** The same argument `_mutate_drift` already makes:
a daughter with no cytostome is not one of two builds to choose between, it is a
body that cannot feed itself.

**A gene that misses is not lost.** It stays in the DNA, draws a carried rung,
and rolls again in the next generation. The lineage only ever loses a gene by
being overwritten.

### 3.1 Why this is not a gamble the player is told about afterwards

Three things, and the third is the one that makes it work:

1. **The strand draws the odds** — copies are rungs, and rungs are countable.
2. **The hint line says them in words.** Below the strand, on the line that used
   to carry the generation: `two copies · a daughter probably wears it`. It fires
   on selection and on hover, so it also fires **the instant a gene is placed** —
   the receipt for a placement is what that placement is worth. The generation
   moved up into the caption (`dna · third generation`), which costs no pixels.
3. **Both daughters are drawn as real bodies before the choice** — that is
   `lifecycle.md` §4, unchanged, and it converts the roll from a hidden dice into
   a **draft**. Each daughter rolls independently, so the odds the player acts on
   are `1 - (1 - p)^2` across the pair: **0.80 at one copy, 0.96 at two.** A
   failed roll is not a punishment, it is one of the two options on screen.

Consequences worth naming rather than discovering:

- **Upkeep is paid on the body, so an unexpressed gene is a free carry.** The
  late game stays a subtraction problem but a gentler one.
- **A directional gene that did not express has no slot on the body**
  (`slot_of` returns −1), so it draws nothing and fires nothing. Correct: the
  organ is not there.
- **Placement is untouched.** The player still chooses the locus, the locus is
  still the arc, and expression decides *whether*, never *where*.

## 4. Divide by four

```gdscript
# cell.gd
const GROWTH_PER_MEAL := 4.0      # was 1.0
const DIVIDE_WARN_RADIUS := 32.0  # was 37.0
const DIVIDE_RADIUS := 40.0       # unchanged, and it is not the dial
const SLOT_RADIUS := 3.5          # unchanged, and it cannot be the dial -- §4.1
```

A daughter is born at 28.28 and divides at 40, so a generation is
`(40 − 28.28) / 4 = 2.93` → **3 meals**, from twelve. The first generation is
`(40 − 26) / 4 = 3.5` → **4 meals**, from fourteen.

`DIVIDE_RADIUS` stays 40 because it carries three couplings a smaller number
breaks: `slots_for(40)` is 7, the body has exactly seven arcs, and
`food.ARRIVAL_GAPE_MAX` is 40 so the water never seeds a mouth that can swallow a
full-grown cell in one contact.

**`DIVIDE_WARN_RADIUS` had to move with it, and nearly did not.** It is written
in meals, not in units: at four units a meal, a warning starting at 37 is three
quarters of one meal wide, so a cell at 36.28 shows nothing and the next mouthful
takes it straight to 40. The doubling nucleus — the best warning in the game —
would have fired on no frame anybody saw. At 32 it is exactly two meals and the
pair of cores separates over the last two.

### 4.1 `SLOT_RADIUS`: measured, and there is no dial there

The brief asked what to compensate with. Nothing, and the interval is why. Two
fixed points pin it — `slots_for(26) = 3` and `slots_for(40) = 7` — which needs
`14 / SLOT_RADIUS` in `[4, 5)`, so the only legal values are `(2.8, 3.5]` and
**3.5 is already the top of that range.** Moving it down makes the ladder finer,
which is the wrong direction; moving it up breaks the seven arcs.

What four-times growth really changes is that **capacity stops being the binding
constraint in the first generation** — every meal now grants at least one slot,
so an empty locus is essentially always available. From generation two a newborn
is over capacity anyway (`lifecycle.md` §3.1), which is where the swap decision
lives now. The binding constraints became the seven arcs and the expression roll.

### 4.2 What was measured

- **The field does not run away.** `food.gd`'s `_devour` reads the same constant,
  so every cell in the water grows four times faster too — which is right, since
  `genes-and-cilia.md` §1.3 forbids a growth rule that exempts the player.
  Traced over 200 s with 34 seeded bodies: **max radius 39.8, mean 18.7, nothing
  over 40, flat from t=40 onward.** The recycle treadmill culls faster than
  feeding compounds.
- **Generation 1, played by the forage harness:** four meals, at t = 45.7, 51.5,
  61.2, 65.6 s. The first is the find-the-food latency; the last three are **20
  seconds**.

> **The honest caveat, and it is the one thing a still frame cannot answer.**
> `lifecycle.md` §5 measured ten meals in 101 s for a competent forager, so a
> generation is now roughly **30–45 seconds** against two minutes — the ÷4 is
> exact in meals and closer to ÷3 in wall clock. The division ceremony is about
> five seconds plus the player's choice, so it is now a noticeably larger share
> of the run. That may be exactly the pace the owner asked for, or one step too
> far; `GROWTH_PER_MEAL` is the single dial either way and every coupling above
> survives moving it to 3.0 or 2.0. It cannot be judged by looking at it.

## 5. What was rendered, and judged

At 1280x720 **and** 2400x1080, GL Compatibility, through `tools/shot.tscn` with
`tools/drive.tscn`.

| frame | judgement |
| --- | --- |
| the born cell, three loci | passes — three bright rungs on a short strand, words under each |
| seven loci, full column | passes; **the column is 678 of 720 px**, 24 clear above and 18 below, identical at both shapes |
| seven loci at 2400x1080 | passes; strand 800 of 1600 canvas px, 400 each side, nothing near the membrane band |
| the two registers disagreeing | passes — worn rungs reach the strands, carried ones float, and the unworn words are dimmer |
| **the same, greyscale, no colour at all** | passes; the distinction is entirely shape |
| a held sample, nothing selected | passes — it hangs off the lead-in on nothing |
| a held sample over an armed locus, by synthetic **touch at 2400x1080** | passes; the thread, the filled lens and the ghost rung all land, and the loci did not move |
| the second tap, committed | passes — and the hint immediately reads `one copy · a daughter may not wear it`, which is the mechanic taught at the moment it is bought |
| the keyboard path: tab, arrows, enter | passes; the focus underline is legible and is not a box |
| seven loci **plus** a held sample — the widest reachable state | passes; 800 px of strand, the sample inside its 64 px cap with 4 px to spare |
| all seven darts at once | passes at 3x; the four diagonals are four different marks |
| the explanation organ at `flagellum`, the tallest | passes; not clipped by its row |
| pause over point of view, calm and under dread | passes; the membrane only ever draws in the outer band and never reaches the strand |
| the division, choosing phase, two daughters | passes — **the two bodies are visibly different organisms**, which is the whole of §3.1 |

## 6. Left open

1. **`EXPRESS_CHANCE` at `0.55 / 0.80 / 1.00`.** A still frame cannot say whether
   a coin toss at one copy feels like variety or like theft. It is the first dial
   after `GROWTH_PER_MEAL`.
2. **`GROWTH_PER_MEAL` at 4.0** — §4.2's caveat.
3. **A sample is still replaced by the next thing you eat**, and at three meals a
   generation that is a larger share of what you swallow than it was at twelve.
   Shipped behaviour, not touched here, and the case for a second held slot is
   now stronger than it was.
4. **`body_tier > dna_tier` cannot happen in the game** and the strand does not
   draw it. Only `--genome=` followed by `--dna=` can pose it, and there it
   under-draws. Left alone rather than spending a branch on a harness artefact.
