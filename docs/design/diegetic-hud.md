# The diegetic HUD

The owner's ask, in one sentence:

> "Now, a HUD. But not a classic one, with numbers and symbols. It must be
> integrated to the actual designs. For example, we should easily see that we
> have a waiting gene to be assigned. I started a game, and I don't see any hint
> except the text for the first grown gene in blind mode."

The last sentence is the acceptance test and it is the only one worth writing
down: **a player who has been given a gene and has not placed it must notice,
without being told, in both views.** Everything below is subordinate to it.

Extends `genes-and-cilia.md` §3.3, which it replaces in full vision and adds to
in point of view; §4.4's colour rules bind it; `perception.md`'s line about what
point of view may say bounds it.

## 1. The decisions

0. **There is no HUD surface.** No panel, no corner, no bar, no glyph. Every
   state is a mark on the body the game already draws — `soma.gd`'s figure in
   point of view, the real cell in full vision — through **one routine**,
   `cilia.gd`'s `draw_pending`, called by both. Two views, one picture, at two
   scales.
1. **The vocabulary is the one the body already has.** An *integrated* earned
   gene is a pigment organelle: seated under its arc, a filled disc in a soft
   cloud, with a tuft of bristles rooted in the skin above it. A *held* gene is
   the negative of that on every axis, which is what makes it readable with no
   legend and no hue at all:

   | integrated | held |
   | --- | --- |
   | seated under an arc | adrift inside the body |
   | a filled disc | a hollow ring with an off-centre core |
   | bristles rooted in the skin | a tuft floating clear of it |
   | permanent | its ring tears open, the way a dying body's rim does |

   Filled-and-seated against hollow-and-adrift is **shape**, so it survives
   §4.4's deuteranope check and it survives the held gene being the same green
   as the mouth it is sitting next to. Rendered side by side on one body it is
   unmistakable; see §5.
2. **Vacancy and destination are one mark at two intensities.** Empty sockets
   are beads just off the skin at the exact points an earned gene's bristles
   would root. On their own they are quiet — *there is room in you* is worth
   about that much ink. The socket the sample is currently reaching for is the
   one that brightens and grows the floating tuft.
3. **The rhythm and the picture are the same event.** `signal_bus.gd` already
   fires a second, smaller heartbeat while a sample is held (§3.3), and
   `normal_mode.gd` feeds `_bus.pulse()` — the composite envelope the beat *and*
   the echo both pump — straight into `soma.beat`. So the mark flares on the
   echo as well as on the beat. The contour says *something in you is
   unresolved*; the body says *what*, and *where*. This was verified in the code
   rather than assumed; nothing was added to make it true.
4. **The clock is decay, not a countdown.** Two clocks, on purpose: `left` runs
   the whole 45 s and shrinks the vesicle, so early and mid are different
   pictures; `wilt` is flat until the last 15 s and then falls, so *about to
   lapse* is an event rather than a slope nobody notices they are on. 15 s is
   `HELD_WILT` and **it must stay the twin of `signal_bus.gd`'s `HELD_FADE`** —
   a player who feels the rhythm weaken while the organ is still bright is
   reading two clocks.
5. **Player only.** Every body in the water has a genome, but what is loose
   inside one is not something a cell could see from outside, and a water full
   of vacancy beads would be ink spent on nothing anyone can act on.

## 2. What the marks are

All lengths are fractions of the body radius `r`, so a grown cell is not a small
cell with stubble. Constants are in `cilia.gd` under *A gene with nowhere to be
yet*; only the ones a later designer would want to move are repeated here.

| mark | geometry | when |
| --- | --- | --- |
| **socket beads** | 4 dots of `0.038 r` (floor 1.6 canvas px), lifted `0.055 r` off the skin along the normal, spread across the free arc at the seats `_draw_earned` would use | any empty slot, always |
| **ghost tuft** | 4 strokes, `0.74` of `LEN_EARNED`, starting `0.24 r` **off** the skin | only the socket being reached for, only while a sample is held |
| **vesicle** | ring of `0.21 r`, orbiting the nucleus at `0.34 r`, one lap ≈ 14 s | while a sample is held |
| **thread** | one bowed strand from the vesicle's edge, `0.62` of the way to that socket | while a sample is held and a socket exists |

- **The beads are lifted off the skin, not seated on it.** Seated they were
  invisible at both shapes, and the reason was not alpha: the rim is a 2.2 px
  stroke of the same teal running straight through them, so a socket bead was a
  teal dot drawn on a teal line.
- **The tuft's gap is not a margin, it is the message.** At `0.13 r` it sat
  inside the cirrus oars and the gape's starboard stem — which is seated at
  `t 54`, the exact middle of free arc 1 — and the one thing it had to say,
  *this is not attached*, was what the crowding took away. At `0.24 r` it floats
  outboard of every rowing cilium and inboard of the flagellum, in a band of the
  body nothing else uses.
- **The tuft is drawn on one socket, not all of them.** On a grown cell with
  four holes, four tufts was a halo of sixteen pale spikes standing off every
  diagonal — louder than the real fringe, and it read as *this cell has four new
  organs* rather than as *one gene is waiting*. One tuft on the socket the
  thread points at is the same sentence at a quarter of the ink, and because the
  vesicle drifts, a genome with three holes is still shown trying each in turn.
- **The vesicle is the whole reason this is not an icon, and it took three
  passes.** A flat circle reads as a widget. A single `sin(3a)` wobble is
  threefold symmetry, which at this size is a crest on a shield — rendered, it
  was a heraldic badge sitting on the body. A thread struck from the centre
  passes through the ring wall and makes the pair a lollipop. The shipped mark
  is: two incommensurate wobble harmonics (2 and 5, drifting at unrelated
  rates), the whole outline drawn out `0.16` toward whatever it is reaching for,
  the core offset `0.34` the other way, and the thread leaving the *edge*. **A
  symbol is the same shape whichever way it is facing; this one is not.**
- **The cloud is three stacked rings, not one disc**, at `1.0 … 2.07` of the
  vesicle radius and alphas `0.13 … 0.043`. That is `_draw_earned`'s own
  construction, so a held sample's cloud and an integrated gene's cloud are
  literally the same object. One `draw_circle` at a flat alpha has a crisp edge,
  and a crisp-edged disc of even tone is the silhouette of a widget.
- **Nothing leaves the body.** The orbit came in from `0.52 r` to `0.34 r`
  because the cloud's far edge was reaching `1.22 r` from the nucleus against a
  `0.94 r` half-width — a grey bloom hanging off the flank, contradicting the
  one thing the mark exists to say. Worst case is now `0.34 + 0.26 + 0.40 =
  0.86 r` abeam.

### 2.1 The four states, ranked

| rank | state | what is drawn | where it lives |
| --- | --- | --- | --- |
| 1 | **a gene is waiting** | vesicle + thread + one bright socket + ghost tuft | `draw_pending` |
| 2 | **a free slot exists** | socket beads only, in `SELF_TINT`, at `0.52` alpha | `draw_pending` |
| 3 | **wound** | the rim tears open one gap at a time, a flap hangs into each, the fill empties | `draw_cell`, already shipped |
| 4 | **hunger** | the metabolic beat — Phase 1's design, untouched | `signal_bus.gd` |

Rank 2 is teal because nothing is asking for it; rank 1 takes the gene's hue,
which is the same hue the organ will wear when it is placed. **A full genome
with a sample held draws the vesicle and nothing else** — there is no socket, so
there is no socket mark, and the picture correctly says *this has nowhere to go,
go and swap something*.

## 3. What this costs, and what it may not do

- No numbers, letters or icons in the playfield. The pause screen keeps its
  words; `genes-and-cilia.md` §8's text budget is untouched, and the onboarding
  line is unchanged — it is no longer the only signal, which was the point.
- Point of view shows only facts about this body: held sample, empty slot,
  wound, hunger. Nothing about the water, no position of anything. The vesicle's
  lean when there is nowhere to reach is **body-relative aft**, not screen-down,
  so the figure never leaks which way north is.
- No new uniform, no new shader, no new node, no `class_name`. Two files change
  and both are drawing code.
- **The HUD loses to the signals**, and §4 is the measurement rather than an
  assertion about an alpha.

## 4. Measured

Rendered under GL Compatibility at 1280x720 **and** 2400x1080, driven by
`tools/drive.tscn`. Luminance is Rec.709 on the 8-bit output; *glance* is the
peak after a σ = 6 px Gaussian, which is roughly what a look integrates over at
1280x720 and is the only fair way to compare a 1.6 px ring stroke against a
200 px swell.

**The acceptance test.** Point of view, calm water, the figure a player has been
staring at for five seconds:

| | glance peak |
| --- | --- |
| the figure with nothing pending | **27.8** |
| the same figure the instant a gene is waiting | **57.0** |

The one object on the screen doubles in weight and grows a mark in a hue the
body does not otherwise contain. That is the answer to *notice without being
told*, and it holds at both shapes.

**The HUD loses.** One frame, point of view, containing a saturated taste band,
a beam/ping return and a held sample at once:

| | glance peak | ink |
| --- | --- | --- |
| taste band | 168.8 | 2,930,492 |
| beam / ping return | 160.5 | 1,112,788 |
| every held-sample mark together | **62.9** | **166,524** |

2.6x and 2.5x under on glance, 18x and 6.7x under on ink. Under dread the
membrane takes the whole screen and the comparison stops being interesting.

> **`FADE_PENDING` moved from 0.78 to 0.68 on this measurement and only this
> one.** At 0.78 a dread lobe came to 60.4 and the mark to 60.8 — a dead heat,
> and a dead heat is not losing. Peak pixel had said the opposite, which is why
> it is not the test.

**Full vision.** The mark is 20% of its own body's ink and sits below a
neighbouring cell's fringe (468k) and below an edible cell's scent bloom (704k),
so it does not dominate the water. Both integrated genes and the held one are
visible on the player's body in the same frame, and the filled-versus-hollow
contrast carries with no colour at all.

**What is honestly weak, and not hidden:**

- On a phone the socket beads and the ghost tuft are a *detail*, not a signal:
  at 2400x1080 the canvas scales 1.5x, so a bead is about 4 device px and the
  tuft strokes about 2 px wide. The vesicle is what carries the message at that
  size, which is what the cloud is for. In full vision the same is true at 1:1 —
  the beads sit among the fringe and are read only when looked at.
- At the very end of the clock the mark is nearly gone. That is decay and it is
  the brief, and with a free slot a lapse is not a loss — `genome.gd` settles
  the gene into the first free slot. With a **full** genome a lapse destroys the
  sample, and that is the one case where a dying signal is quiet at exactly the
  moment it matters most. Left as it is, because the alternative is a countdown.
- Under dread the membrane dims and the figure does not, so the mark becomes the
  brightest thing on a dark screen. That is a property `soma.gd` already had;
  making the figure fade with dread would be a separate change with its own
  argument, and is not made here.

## 5. What was rendered

At both 1280x720 and 2400x1080 unless noted. Point of view is `--mode=0`, full
vision `--mode=1`; the clock is posed with `--sample=` and `--sample-left=`, the
wound with `--wound=`.

| frame | judgement |
| --- | --- |
| held sample, early (43 s), both views | passes; the mark is the brightest thing on the figure and nothing else changed |
| held sample, mid (22 s) | smaller vesicle, shorter tuft, thread intact — visibly a different picture, no second clock needed |
| held sample, about to lapse (2.5 s) | ring torn, tuft a stub, thread nearly gone; the socket beads stay bright, which is right — the hole is still there |
| taste band + beam return + held sample, one frame | the HUD loses, 2.5x on glance, measured above |
| dread at close range + held sample | the membrane takes the screen; the mark survives faintly and does not compete |
| wounded cell, with and without a sample | the torn rim reads as damage; with a sample the sample wins, which is the ranking |
| clean cell, full genome, nothing pending | nothing drawn at all — the body is exactly as it was |
| free slot, nothing held | four quiet teal beads and nothing else |
| four free slots, sample held | one tuft, one thread, three quiet bead rows; this is the frame that killed the four-tuft version |

## 6. Left open

1. **The soma figure's `SCALE` (1.7).** Everything above inherits it. On a phone
   a larger figure would make every one of these marks easier, and would also
   make the body a bigger object in the middle of a screen whose emptiness is
   the design. Not changed here; it is a `soma.gd` decision with its own render
   evidence behind it and it should be re-judged on its own terms.
2. **Whether the figure should fade under dread.** See §4.
3. **Hunger.** Rank 4 is carried entirely by the beat, which is Phase 1's design
   and is not replaced. It was not re-judged here: it cannot be photographed,
   because it is a period and not a picture.
