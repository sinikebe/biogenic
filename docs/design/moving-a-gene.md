# Moving a gene

The owner, in two sentences:

> "Allow us to move genes from a slot to another one. The current creature
> genome is read only, but when we add a gene or move them, it will apply to the
> next generation."

and then, after the first pass:

> "We should see both the current gene and the edited one at the same time."

The second sentence is the larger change. The first is a new verb on the pause
strand; the second says the strand has been telling half a truth since
`lifecycle.md` shipped, and makes the divergence between what you wear and what
you are writing **the picture** rather than a thing to signal.

Extends `dna-strand.md` (the strand), `lifecycle.md` §3 (two registers) and
`gene-lines-and-the-pause-target.md` §3 (the lines under it). Nothing in
`genes-and-cilia.md` §9.7 changes, and §4 says why that is not an accident.

Everything below was built in the working tree, photographed at 1280x720 **and**
2400x1080 under `--rendering-driver opengl3`, and reverted. §9 lists the frames.

---

## 1. The decisions, in one place

1. **The pause strand becomes two strands: `body` above, `dna` below**, at
   identical locus pitch and identical x, so column *i* is arc *i* on both. §2.
2. **Only the lower strand takes input.** The body is fixed; a row you cannot
   change must not look like one you can. That is the asymmetry, and it is drawn
   by what responds rather than by a tint. §2.3.
3. **A move is a drag**, through Godot's own `_get_drag_data` /
   `_can_drop_data` / `_drop_data`, on the DNA row only. §3.
4. **A move onto an occupied locus swaps.** Nothing is created, nothing is
   destroyed, and it is the same operation `Genome._mutate_shift` already
   performs on the player's behalf at every division. §3.4.
5. **A move is free, repeatable and reversible.** It is not §9.7's irreversible
   action and it does not weaken it. §4.
6. **A move needs no new mark.** A gene that has moved is the same hue at two
   different x on two rows, `worn` on one and `carried` on the other. The
   vocabulary already had it. §2.4.
7. **One new text row, `Act`**, carrying the verb. The hint keeps the odds. §5.
8. **`light` and `camera` pair up side by side**, because the column has to find
   94 px for the second strand and it does not have them. §6.

---

## 2. Two strands

### 2.1 Why it is two strands and not a mark

`genome.gd` already holds the two registers and already answers both questions:

| | the body | the DNA |
| --- | --- | --- |
| which gene, where | `body_layout()` | `layout()` |
| at what tier | `tiers()` | `dna()` |
| which arc an organ is on | `slot_of(gene)` | its index in `layout()` |

They are two arrays of the same length, and the shipped strand draws one of
them. Everything the player cannot currently see — a moved gene, an evicted
organ still worn, a gene the DNA raised that the body did not — is the
difference between the two arrays.

`choosing.md` §3.1 already proved the reading: two strands at **identical locus
heights**, empty loci still drawn, so a comparison is a scan at a fixed offset.
This is that argument turned ninety degrees — identical locus **x**, so the scan
is vertical. The difference from that screen is that there, two candidates were
equals; here one of them is a readout.

### 2.2 Geometry

The DNA row is `dna-strand.md` §1.1 unchanged: `LOCUS_W 96`, `LOCUS_H 86`,
`LOCUS_LOBES 3`, `BAND_MID 13`, `HELIX_MID 47`, `HELIX_AMP 18`, `LABEL_MID 76`,
`LABEL_BASE 81`, caps `CAP_LOBES 2` / `CAP_W 64`.

The body row is the same weave at the same pitch, with **no sample band** and
its label row **above** its helix:

```gdscript
# normal_mode.gd, under *The strand*
const BODY_LOCUS_H  := 58.0
const BODY_HELIX_MID := 40.0     ## helix spans 22 .. 58 of its own control
const BODY_LABEL_MID := 11.0     ## the dart's centre
const BODY_LABEL_BASE := 16.0    ## the word's baseline
```

**The body's label goes above and the DNA's stays below, so the words are
outboard of the pair and the two helices are adjacent.** Built the other way
first — both label rows under their own helix — and photographed: with the DNA
row's 26 px sample band beneath the body's words, a held sample and a body
dissent word land 25 px apart in the same column, and the two helices sit 77 px
apart instead of 37. Labels outboard puts the sample alone in the band it owns
and halves the distance the eye travels to compare two rungs.

`HELIX_AMP` is shared, so the two weaves are the same object at the same scale.
`Cilia.draw_weave / draw_lens / draw_rungs / strand_point` are used unchanged —
the body row passes its own `mid` and `height` and nothing forks.

### 2.3 What each row draws

| | body row | dna row |
| --- | --- | --- |
| source | `body_layout()`, tiers from `tiers()` | `layout()`, copies from `dna()` |
| rungs | always **worn** — a body has no carried copies | worn or carried, §2.4 |
| word | **only where the two rows disagree at that locus** | always |
| dart | with the word, so only on a disagreement | always |
| sample band | none | `dna-strand.md` §2, unchanged |
| lens / selection | never | unchanged |
| focus underline | never | unchanged |
| `mouse_filter` | `IGNORE`, on the row **and** every locus | `STOP`, unchanged |
| `focus_mode` | none — no new Tab stops | `FOCUS_ALL`, unchanged |

**A word only on disagreement, and it was measured both ways.** Words under
every body locus is the same seven verbs twice — rendered, and it is a wall of
text in which the one line that is news disappears. Where the rows agree, the
DNA row's word sits in the same column and names both. Where they disagree the
body has something on screen that nothing else says, so it says it. The row
still reserves the full 58 px, so nothing moves when a disagreement appears.

The gutters: one `Label` per row, `GUTTER_W 64` wide, right-aligned, vertically
centred, 15 px, `Color(0.855, 0.953, 0.933, 0.45)` — the caption's own tint,
because that is what they are. Text `body` and `dna`.

**Each row ends with a 64 px invisible `Control`**, mirroring the gutter, or the
strand sits half a gutter left of the column everything else is centred on.
Measured: 7 px, and visible against the centred `Explain` line below it. This is
`genes-and-cilia.md` §5.2's trailing-spacer trick, deleted by `dna-strand.md`
§1.4 for a different job and earned again here.

### 2.4 Worn means worn *here*

The shipped strand computes a locus's worn/carried split as
`body.get(gene, 0)` — *does this body have this gene at all*. With one strand
that was the only question available. With two it is a lie the moment a gene
moves: the DNA has it at locus 3, the organ is on arc 1, and locus 3 draws a
full rung claiming otherwise.

```gdscript
# _build_genome_strip, the dna row
var here := int(body.get(gene, 0)) if _genome.slot_of(gene) == i else 0
```

So a moved gene draws **carried** on the DNA row — a bar floating clear of both
backbones — and **worn** on the body row, a full rung, at a different x. Three
channels agree without a new mark being invented:

- **position** — same hue, two columns
- **shape** — full rung against floating bar, which survives greyscale
- **word tint** — the DNA row's word drops to `WORD_UNEXPRESSED 0.42`, which is
  the existing "the body does not wear this" channel, now narrowed to "not here"

Rendered in greyscale with no colour at all (§9): all three still read.

---

## 3. The gesture

### 3.1 Why a drag, and why not the alternatives

Tap-then-tap is taken twice over: a tap selects a locus and reads it
(`gene-lines-and-the-pause-target.md` §2), and a second tap on the same locus
places a held sample. Redefining "tap A then tap B" as *move A to B* costs the
ability to read a second gene, which is most of what the strand is for.

- **An explicit `move` control** needs a destination after it, so it is a mode:
  three taps, a state to escape, and a 48 px control on a column that had 18 px
  of slack. Rejected on cost, not on principle.
- **Long-press to pick up** is invisible, needs a timer, and teaches nothing.
- **Drag** is the universal verb for *move this there*, it is **self-cancelling**
  — letting go anywhere else is a no-op — and self-cancelling is exactly the
  property §4 wants a move to have. The two consequences get two gestures, which
  is the cheapest possible way to say that one of them is heavier.

### 3.2 It is Godot's drag, not a hand-rolled one

```gdscript
# _make_locus, dna row only
node.set_drag_forwarding(_locus_drag.bind(node, slot),
    _locus_can_drop.bind(slot), _locus_drop.bind(slot))
```

`choosing.md` §4.2 is the reason this is not built by hand: Godot records which
control owns a pointer **only when the press landed on a control**, and
re-hit-tests every drag otherwise. The built-in path is written around that.
Three things it gives for free, all confirmed on the render:

- **Touch works.** `emulate_mouse_from_touch` is on by default, so an
  `InputEventScreenDrag` becomes an `InputEventMouseMotion` and the GUI drag
  machinery runs. Posed through `--press=` / `--slide=` and photographed.
- **Hover keeps tracking.** Godot clears `gui.mouse_focus` when a drag begins, so
  `mouse_entered` / `mouse_exited` continue to fire on the locus under the
  pointer — which is how the drop target is known, on both platforms.
- **A drag that ends on nothing does nothing**, and `NOTIFICATION_DRAG_END`
  arrives at the scene either way.

**One prerequisite, and without it the drag cannot start at all.**
`_on_locus_input` currently calls `_build_genome_strip()` when a tap selects a
locus — which frees the control the press landed on, before the finger has
moved. Selection must become a redraw:

```gdscript
# replacing the rebuild in _on_locus_input's select branch
_redraw_strand()          # queue_redraw on every child of both rows
_update_explain()
_update_hint()
```

Nothing about the genome changed, so nothing has to be rebuilt; the loci already
read `_armed` at draw time. This also stops the strand throwing away and
remaking ten nodes on every tap, and removes the focus churn `_restore_focus`
exists to repair.

### 3.3 What the player sees while a gene is in the air

| | draw |
| --- | --- |
| **the travelling gene** | `set_drag_preview` — the held sample's own base pair (`_draw_sample`, bar, two halo rings, plain word), riding **`DRAG_LIFT 34` px above the pointer** |
| **the locus it came out of** | no rungs, no word: the gene is not there. Its lens fills in the hue of whatever would come back into it — the displaced gene, or `PALE` if the destination is empty |
| **the locus under the pointer** | `selected` — brighter backbone (`BACKBONE_LIT 1.25`) and lens filled at `LENS_SELECTED 0.20` **in the travelling gene's hue**. It keeps drawing its own copies, so what is about to be displaced stays readable |
| **the `Act` line** | `let go to swap eat and ping` / `let go to move beam here` / `eat · let go over a locus to move it there` |
| **the `Explain` line** | the gene under the pointer — what you are about to displace — or the travelling gene if that locus is empty |

**`DRAG_LIFT` is why the `Act` line carries the state.** A fingertip is about
9 mm, which at 2400x1080 is roughly 100 canvas units — one whole locus. A
preview riding the pointer and a lens filling under it are both *under the
thumb* on a phone. 34 px lifts the base pair into the band the DNA locus already
reserves for a sample, which is as far as it can go before it collides with the
body row, and the line below the strand is the one piece of feedback a thumb
cannot cover. Both are drawn; only one of them is load-bearing on touch.

### 3.4 Swap, not refuse

```gdscript
# genome.gd
func move(from: int, to: int) -> bool
```

Two loci trade places in `_order`. `_dna`, `_body`, `_body_slots` and every tier
are untouched, so `slot_of()`, `tiers()`, `upkeep()` and every directional gene's
bearing are unchanged, and `_make_daughters()` copies the new order. Refuses
`from == to`, either index out of range, and an empty `from`. Verified headless:

```
before  dna=[cytostome, cirrus, flagellum, ocellus]  body=[same]  slot_of(ocellus)=3
move(3,0) -> true
after   dna=[ocellus, cirrus, flagellum, cytostome]  body=[unchanged]  slot_of(ocellus)=3
        upkeep 1.36 (unchanged)      daughter order = [ocellus, cirrus, flagellum, cytostome]
```

Swapping rather than refusing, for three reasons and the third is the one that
settles it:

- Refusing fails most drops, because a late-game strand is dense. A gesture that
  usually does nothing reads as broken.
- An empty destination is the degenerate case of the same swap, so there is one
  rule and not two.
- **The game already does exactly this.** `_mutate_shift` — one of the three
  mutations a daughter can carry — "moves one gene to a different slot, swapping
  with whatever was there". Letting the player do deliberately what the mutation
  does at random is not a new power; it is the same power made legible.

### 3.5 The keyboard

**`Shift` + `←` / `→` on a focused locus moves that gene one place**, clamped at
the ends rather than wrapped — a gene that walked off the strand and reappeared
at the other end would land on a different arc from the one being aimed at.

Read as a raw `InputEventKey` inside `gui_input`, because **a content pack
cannot add an `InputMap` action** and the bare arrows are how the GUI is
navigated. `accept_event()` on the chord stops focus navigation from also
running. No `project.godot` change, no new binding to document.

Rendered: three `Tab`s onto locus 1, then two `Shift`+`→` walked `turn` from
slot 1 to slot 3 and slid `swim` and `see` back one each, with the body row
growing three dissent words as it went.

### 3.6 A move and a placement cannot both be in flight

Posed on purpose, because it is the one state where two gestures meet: a held
sample bound for locus 4, and a gene dragged onto locus 4. Rendered, and the
first build **collided** — two base pairs and two words at one locus, and an
`Act` line still saying `tap again to place`.

The rule that fixes it is one the surface already had: **a sample waits off the
lead-in whenever no locus is bound for it, and a gene in the air unbinds it.**
While `_dragging` is set, the sample draws on the head cap (its "no place yet"
picture, which is true), no locus draws the sample or its ghost rung, and the
`Act` line reports the move. On release the sample rebinds to the selection as
usual.

---

## 4. A move is not §9.7's irreversible action, and does not weaken it

`genes-and-cilia.md` §9.7 rests on placement **evicting** a gene: `_write` does
`_dna.erase(old)` and the gene is gone from the lineage. That is the one
irreversible action in the game and the reason a genome is something you can
ruin.

A move creates nothing and destroys nothing. It cannot undo a placement — the
evicted gene is not in `_dna` and no rearrangement brings it back. So the two
are independent and a move can be free, repeatable and self-cancelling without
touching §9.7's weight.

**The one thing that does get cheaper, named rather than discovered.** Placement
today bundles two decisions: *which gene dies* and *which bearing the new one
gets*. Free moves unbundle them — the eviction stays permanent, the bearing
becomes adjustable. That is the right half to make cheap:

- The bearing only pays off on the **next** generation, because the organ is
  worn by your daughters and not by you (`lifecycle.md` §1). A permanent aiming
  mistake made in a few seconds against a 45-second sample clock is a gotcha,
  not a choice.
- The lineage already rearranges itself for free: every division rolls
  `_mutate_shift` as one of three equally likely mutations, so a bearing the
  player agonised over survives to generation three by luck anyway.
- §9.8 requires the genome to stay "swappable at maximum", because what is
  interesting past radius 40 is *which* seven. A seven-slot genome with no free
  slots and no moves is a genome whose only remaining verb is destruction.

---

## 5. The lines under the strand

`gene-lines-and-the-pause-target.md` §3 put two rows there and argued that both
are wanted at once. The move needs a third clause and the same argument applies
again, so it gets the same answer: **one more row, not a fight over one.**

```
Explain   what this gene does          15px   name in the gene's hue + sentence at 0.62
Hint      what it is worth to a daughter  14px  Color(0.855, 0.953, 0.933, 0.38)
Act       what you can do about it     14px   Color(0.588, 1.0, 0.859, 0.50)     <-- NEW
```

The two placement instructions move out of `Hint` and into `Act`, which is where
they always belonged — `Hint`'s job is a readout and theirs is a verb:

```gdscript
const ACT_ARM    := "tap a locus · your daughters may wear it"    # moved from HINT_ARM
const ACT_COMMIT := "tap again to place"                          # moved from HINT_COMMIT
const ACT_MOVE   := "drag it to another locus"
const ACT_CARRY  := "%s · let go over a locus to move it there"
const ACT_LAND   := "let go to move %s here"
const ACT_SWAP   := "let go to swap %s and %s"
```

`Act` is empty when the selected locus is empty and nothing is held — there is
nothing to do there.

**A bug the split exposes, and it must be fixed with it.** `_update_hint` reads
`HINT_CHANCE[dna_tier(gene)]`, and a *held sample* has `dna_tier == 0`, which is
the empty string. Today that never shows, because the held-sample branch returns
first; once the instruction moves to `Act` the odds line goes blank at exactly
the moment the player is deciding. `maxi(dna_tier(gene), 1)` — a sample is worth
one copy if placed, which is what the line is for. Photographed both ways.

**`Act` is teal and the other two are pale**, so the ordering on the column is
*what this is* (loudest, with a coloured name) → *what it is worth* → *what you
can do*. A fourth pale line would have read as a paragraph.

### 5.1 The move surface does not teach why a slot matters

`ocellus` and `trichocyst` already say **that side** in their own lines, the dart
is under every locus, and the dart is now under the body row's disagreements too
— which is the first time the game has ever drawn *where an organ actually is*.
`Act` says what the gesture does and not why anyone would want it. Left to
discovery deliberately: a player who has not yet met a directional gene has
nothing to aim, and one who has is told by that gene's own line.

---

## 6. It does not fit, so the column changes shape

Measured on the shipped build, through `get_global_rect()` on a paused
`normal_mode` with seven loci, **identical at 1280x720 and 2400x1080**:

| | y | height |
| --- | --- | --- |
| `Buttons` | 18 .. 702 | **684 of 720**, 18 clear above and 18 below |
| `Genome` | 18 .. 196 | 178 |
| `Light` | 244 .. 345 | 101 |
| `View` | 393 .. 494 | 101 |
| `Resume` / `Leave` | 542 .. 598 / 646 .. 702 | 56 each |

(The brief's 678 is the ink; 684 is the container. Same answer.)

A second strand costs `BODY_LOCUS_H 58` plus 8 of separation, and `Act` costs 20
plus 8: **94 px against 36 px of total slack. It does not fit, and it must not be
squeezed.**

**`light` and `camera` go side by side.** They are two `PanelContainer`s of
identical size (232 x 101), both settings, both non-destructive, and stacking
them is the only reason the column is as tall as it is. An `HBoxContainer`
`Settings`, separation 48, `SIZE_SHRINK_CENTER`, 512 px wide — narrower than the
strand block, so the column gains no new outer edge and §5.2's "one edge rather
than two" survives. **`resume` and `leave` stay stacked**: `leave` ends the run,
and the 48 px of vertical air between it and `resume` is the separation
`genes-and-cilia.md` §5.2 argued for.

That frees 149 px for 94 px of new content. Re-measured on the built screen,
again identical at both shapes:

| | y | height |
| --- | --- | --- |
| `Buttons` | **45 .. 674** | **629 of 720**, 45 clear above and 46 below |
| `Genome` | 45 .. 317 | 272 |
| ├ `Caption` | 45 .. 67 | 22 |
| ├ `Body` | 75 .. 133 | 58 |
| ├ `Row` | 141 .. 227 | 86 |
| ├ `Explain` | 235 .. 261 | 26 |
| ├ `Hint` | 269 .. 289 | 20 |
| └ `Act` | 297 .. 317 | 20 |
| `Settings` | 365 .. 466 | 101 |
| `Resume` / `Leave` | 514 .. 570 / 618 .. 674 | 56 each |

**The column is 55 px shorter than it is today and has two and a half times the
clearance**, with a whole strand and a text row added.

Width: the block is `64 + 64 + 7*96 + 64 + 64 = 928`, x 176 .. 1104 at 1280x720
and x 336 .. 1264 on the 1600-wide canvas at 2400x1080. **Reflow on a tall
phone: none vertically** — the canvas is 720 tall at both shapes — and the
margins grow from 176 to 336 a side.

### 6.1 The node tree

```
Hud/Pause/Center/Buttons               VBoxContainer  separation = 48
  ├── Genome                           VBoxContainer  separation = 8
  │     ├── Caption  Label  "genome · third generation"  15px  (0.855,0.953,0.933,0.45)
  │     ├── Body     HBoxContainer  separation = 0  alignment = CENTER  MOUSE_FILTER_IGNORE
  │     │     ├── Gutter  Label   64 x 58   "body"  right-aligned, vcentre
  │     │     ├── Cap     Control 64 x 58   taper +1
  │     │     ├── Locus   Control 96 x 58   x count            <-- IGNORE, no focus
  │     │     ├── Cap     Control 64 x 58   taper -1
  │     │     └── Spacer  Control 64 x 58
  │     ├── Row      HBoxContainer  separation = 0  alignment = CENTER
  │     │     ├── Gutter  Label   64 x 86   "dna"
  │     │     ├── Cap     Control 64 x 86   taper +1
  │     │     ├── Locus   Control 96 x 86   x count            <-- STOP, FOCUS_ALL, drag
  │     │     ├── Cap     Control 64 x 86   taper -1
  │     │     └── Spacer  Control 64 x 86                       <-- NEW
  │     ├── Explain  HBoxContainer  min (0, 26)   unchanged
  │     ├── Hint     Label  14px  (0.855,0.953,0.933,0.38)  min (0, 19)
  │     └── Act      Label  14px  (0.588,1.0,0.859,0.50)    min (0, 19)   <-- NEW
  ├── Settings                         HBoxContainer  separation = 48  SIZE_SHRINK_CENTER
  │     ├── Light   PanelContainer  232 x 101   (unchanged, re-parented)
  │     └── View    PanelContainer  232 x 101   (unchanged, re-parented)
  ├── Resume   Button  232 x 56
  └── Leave    Button  232 x 56
```

The six `@onready` paths for `Light` and `View` gain `Settings/`. `_focused_slot`
and `_restore_focus` already read `get_meta(&"slot", SLOT_NONE)` and check
`focus_mode`, so the gutters and spacers are invisible to them with no change.

**The caption becomes `genome · third generation`.** The group is the genome
surface; `dna` — the owner's own word, which `lifecycle.md` §3 put on the caption
— moves down to the row it actually names, with `body` above it. Both words are
now on screen instead of one.

### 6.2 Touch

Unchanged: the whole 96 x 86 DNA locus is the target, 144 x 129 device px at
2400x1080 against a 48 px rule, loci adjacent with no gap because a mis-tap and
a mis-drag both cost nothing. The body row is `MOUSE_FILTER_IGNORE` end to end,
so a thumb landing on it does nothing rather than something surprising, and it
adds **no** Tab stops to the six to eight
`gene-lines-and-the-pause-target.md` §6.4 already complains about.

---

## 7. What was rejected

- **Redefining the two taps as a move.** Costs the ability to read a second
  gene, which is what the tap was generalised for one release ago.
- **A `move` control on the column.** A mode, three taps, an escape, and a 48 px
  control on a surface that had 18 px of slack before any of this.
- **Long-press to pick up.** Invisible, needs a timer, teaches nothing, and
  every touch gesture on this screen so far is a press or a drag.
- **Refusing a move onto an occupied locus.** Most drops fail on a dense strand;
  a gesture that usually does nothing reads as broken.
- **Dragging between the two rows.** Reading order says it should mean
  something, and it must not: the body is fixed, so a drag from it would promise
  an edit of a thing that cannot be edited, and a drag to it would be a way to
  put an organ on yourself that the whole of `lifecycle.md` forbids.
- **Making the body row selectable for reading.** Doubles the targets and the
  Tab stops to reach identities the disagreement words already put on screen.
- **A connector drawn between a moved gene's two positions.** Pretty with one
  move; spaghetti with four, which is a state the keyboard path reaches in two
  seconds. Cross-container drawing besides.
- **A new mark for "this locus has moved".** Position, rung shape and word tint
  already say it three times.
- **Words under every body locus.** Seven verbs twice; rendered, and the news
  disappears into the repetition.
- **Body labels under the body helix.** Puts them in the band the held sample
  owns and doubles the gap between the two weaves. Rendered both ways.
- **A shared row of darts between the strands.** Non-redundant and tempting, but
  it leaves each row's words with nothing to anchor to and makes two label
  groups that centre differently.
- **Pairing `resume` and `leave` to save more height.** Not needed once `light`
  and `camera` pair, and `leave` ends the run.

---

## 8. What the game developer has to change

| file | change |
| --- | --- |
| `game/normal/genome.gd` | `move(from, to) -> bool`, §3.4. Nothing else. |
| `game/normal/normal_mode.tscn` | `Genome/Body` before `Row`; `Genome/Act` after `Hint`; `Light` and `View` into a new `Settings` HBox |
| `game/normal/normal_mode.gd` | the body row's constants and draw; `here` in §2.4; selection redraws instead of rebuilding (§3.2); the three drag callbacks; `Shift`+arrow; `Act`; the `maxi(dna_tier, 1)` fix; six `@onready` paths |
| `game/vision/cilia.gd` | **nothing.** The statics already take an axis, a mid and an amplitude |
| `tools/drive.gd` | `--slide=` must set `relative`; `--tap=shift-left` / `shift-right`. §9.1 |

No `project.godot`, no `version.json`, no `export_presets.cfg`, no `addons/`, no
`ci/`. **This ships as a content pack.**

---

## 9. What was rendered, and judged

At 1280x720 **and** 2400x1080, GL Compatibility, through `tools/shot.tscn` with
`tools/drive.tscn`, at `--fixed-fps 60`. The pause screen is the one
deterministic surface in the game, so these reproduce.

| frame | judgement |
| --- | --- |
| the shipped strand, seven loci, the body dissenting at one | **this is the frame the spec exists because of** — the strand draws `ping` at slot 4 and says nothing at all about the `beam` on the player's own flank |
| the pair, born cell, three loci, both shapes | passes. Two identical strands, the upper one wordless, which reads as *these agree* |
| the pair, seven loci, one disagreement, both shapes | passes. `beam` on the body row and `ping` on the dna row in the same column, and they are the only two words that are not in a pair |
| a gene lifted, mid-drag, **touch**, both shapes | passes. Base pair above the finger, source lens in the displaced hue, destination backbone lit and lens tinted, `let go to swap eat and ping` |
| the same on the **desktop** path (`--mouse-press/slide`) | passes, identically |
| the drop committed, both shapes | passes. `eat` is worn at body slot 0 and carried at dna slot 4; `ping` is carried at dna slot 0; four words, two rows, one hue each |
| **the same, greyscale, no colour at all** | passes. Full rung against floating bar at 42% length, and every gene named |
| a drag onto an **empty** locus | passes. `let go to move beam here`, and the explanation row describes the travelling gene rather than the hole |
| a drag **released over open screen** | passes. Nothing moved, and all three lines return to the selection |
| a **held sample** bound for a locus, seven loci | passes. `sting` in the band, lens filled, `one copy · a daughter may not wear it`, `tap again to place` |
| a drag **while a sample is held** | **failed first** — two base pairs and two words at one locus, and an `Act` line naming the wrong gesture. Fixed by §3.6; re-rendered, passes |
| the held sample selected, odds line | **failed first** — blank, because `dna_tier` is 0 for a sample. Fixed by `maxi(.., 1)` |
| `Tab` x3 then `Shift`+`→` x2 | passes. `turn` walks from slot 1 to slot 3, `swim` and `see` slide back, three dissent words appear on the body row |
| the whole column, seven loci, both shapes | passes. 629 of 720, 45 clear above and 46 below, against 684 with 18 today |
| pause over **point of view**, scrim 0.50 | passes. The membrane draws in the outer band and never reaches the gutter, which is the leftmost new ink on the screen |

### 9.1 Two harness findings, and one of them blocks the test set

- **`--slide=` cannot pose a Godot drag as it stands.** It sends an
  `InputEventScreenDrag` with `relative` left at `Vector2.ZERO`; the emulated
  mouse motion inherits it; `gui.drag_accum` never grows; the 10 px threshold is
  never crossed and `_get_drag_data` is never called. The touch path looks dead
  and is not. `_send_slide` must carry `relative = at - <last point>`, with
  `_send_press` seeding it. **Every touch row in the table above needed this**,
  and without it nobody can re-run them. It is the harness's own lesson again —
  check the tool before believing the frame.
- **`--tap=` has no modifier**, so `Shift`+arrow could not be posed. Added
  `shift-left` / `shift-right`; `_send_key` masks `KEY_MASK_SHIFT` off the
  keycode and sets `shift_pressed`.

---

## 10. Left open

1. **After a move, the destination is selected — and if a sample is held, one
   more tap would place it there.** That is the shipped two-tap rule reached by a
   new road, and the 300 ms guard still applies, but the finger is already on the
   locus. Judged consistent rather than safe; re-judge if anyone overwrites a
   gene they had just finished positioning.
2. **The body row's words on a busy strand.** Four moves in one generation puts
   four words on the upper row and it starts to look like two full label rows.
   True, self-limiting, and erased by the next division — but it is the state
   this design is least sure of, and it cannot be judged without a player who
   rearranges habitually.
3. **The drop target's mark is the selection's mark.** Brighter backbone plus a
   0.20 lens in the arriving hue, behind a rung that may be brighter than both.
   It reads at 1280x720; if a player ever drops on the wrong locus, raising the
   lens for a drop target specifically is the cheapest fix.
4. **No animation on the landing.** The rungs are simply somewhere else on the
   next frame. A 150 ms slide would say *it moved* rather than *it is elsewhere*,
   and the pause screen has no tween in it today.
5. **`Cilia.draw_weave` is now called twice per locus column.** At seven loci
   the strip goes from nine controls to twenty-two, on a paused,
   redraw-on-demand surface; not measured, because nothing here runs during
   play, but it is the first time this surface has doubled.

---

## 11. Owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | Should moving a gene be free and unlimited? | **free, repeatable, nothing is spent ✓ recommended** / one move per generation / a move costs hunger | Recommended: you can rearrange which side each organ sits on as often as you like, and it only ever reaches your daughters. Eating a gene over another one still destroys that other one for good — that stays the decision you cannot take back. Limiting moves would make aiming a beam a thing you get one shot at, decided in the seconds before a sample expires, for an organ you will not even wear this life. |
| 2 | What is the surface called now that it has two rows? | **`genome` on top, rows labelled `body` and `dna` ✓ recommended** / keep `dna` as the title and label the rows something else | Recommended: the title names the whole thing and your own word, `dna`, sits on the row it actually means — the one your children are made of. The other row is your body, and it now says so. The alternative has the word `dna` labelling a block that is half body. |
