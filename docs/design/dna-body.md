# The body and its slots

The owner, three times:

> "It is not practical to read the arrows to know which part of the body it is.
> Instead, draw the body, then for each part, a small DNA slot." — #119
>
> "the gene level. We should see the lvl of a gene." — #120
>
> "The gene attribution. Add a shortcut to assign a gene to an available slot
> without entering pause menu." — #121

The first two are one screen and the third is one gesture. Replaces
`dna-strand.md` §1 as a layout (the helix, the rungs and the worn/carried
shapes survive, one slot at a time) and `moving-a-gene.md` §2 and §6 (two
strands, and the column they needed). Every gesture in `moving-a-gene.md` §3
stands, in two dimensions now. Built on #118's queue.

The screen (§1–§7, #119 and #120) and the gesture (§8, #121) shipped as two
changes. Everything was rendered at 1280x720 **and** 2400x1080 under
`--rendering-driver opengl3 --fixed-fps 60`, and §11 lists every frame with the
command that makes it. The frames are deterministic under `--seed=`: one of
them rendered three times differs by 0 pixels.

---

## 1. The decisions, in one place

1. **The pause screen draws your own body, nose up, and puts one small DNA
   slot beside each part of it.** Which part is read off *where the slot is*.
   The compass darts are gone from this screen. §2.
2. **A slot is a piece of DNA**: a three-lobe helix whose rungs are the copies,
   the plain word, and the copies again as pips. §3.
3. **The copies are three pips** — filled for a copy the body wears, a ring for
   a copy only the DNA carries, a faint dot for room to grow. Not a digit. §3.1.
   A gene that earns levels shows its level as a number in the helix's third
   lobe, apart from the pips (`beam-levels.md` §8.1).
4. **The drawing is the body; the slots are the DNA.** Where the two disagree
   at an arc, the body names the organ it is actually wearing there. §4.
5. **Slots the body has not earned are drawn faint and take nothing.** §3.2.
6. **Waiting genes sit in a tray above the body, soonest to lapse first, each
   with its copies.** Tap one to take it in hand; place it with the same two
   taps as before, or drag it onto an empty slot. §5.
7. **Arrows go where they point.** `Shift` + arrow moves a gene to the slot
   that way; Tab goes round clockwise from the nose. §6.
8. **Settings and the two buttons move to a column on the left**, because that
   is what puts full vision's ghost of your own cell into the one empty cell of
   the ring. Measured, not preferred. §7.
9. **In play: hold your own body, slide the gene out toward the side it
   should grow on, let go.** Free slots only, the head of the queue, and the
   water keeps moving. `E` on desktop. §8.
10. **The choosing screen keeps its strands this round.** §9.

---

## 2. The figure

**The arrows asked the player to decode a bearing; the body lets them point
at one.** The slot *is* the arc, and the arc is a place on a body the player
has been looking at for the whole run. So the screen draws that body and puts
each slot next to the part it is.

**It is the water's own drawing.** `Cilia.draw_cell` with `tiers()` and
`body_layout()`, heading 0 (nose up), `clock` 0 (a still mirror, the tile
face's argument), `fade` 0.85, `is_self` true. No second drawing of a cell
exists anywhere, and this is not one.

```gdscript
# normal_mode.gd, under *The body and its slots*
const FIGURE_SIZE := Vector2(420.0, 372.0)    # Genome/Figure
const FIGURE_AT := Vector2(210.0, 170.0)      # body centre inside the figure
const FIGURE_R := 60.0     # drawn radius, whatever the cell's size
const SLOT_SIZE := Vector2(96.0, 56.0)        # one slot, and its whole touch target
const SLOT_SEAT: Array[Vector2] = [           # chip centres from the body centre
	Vector2(0.0, -138.0),     # 0 nose
	Vector2(150.0, 0.0),      # 1 starboard flank
	Vector2(0.0, 168.0),      # 2 tail
	Vector2(150.0, -138.0),   # 3 forward starboard
	Vector2(-150.0, -138.0),  # 4 forward port
	Vector2(150.0, 168.0),    # 5 rear starboard
	Vector2(-150.0, 168.0),   # 6 rear port
]
```

- **A fixed radius, not the cell's.** Drawn at the cell's size, the ring would
  move between two pauses as the body grows. Growth is already said by the
  slots that light up (§3.2).
- **A 3 x 3 ring, not a circle at true bearings.** Words are horizontal, rows
  and columns give the arrow keys a meaning (§6), and every chip centre sits
  within **5.3°** of its arc's true bearing (forward diagonals 47.4° against
  42.1°, rear 138.2° against 133.3°, the flank 90° against 92.5°).
- **There is no port-flank slot, and the empty cell says so.** Slot 1 is the
  flank pair: the cirrus wears both flanks, anything else the starboard one
  (`cilia.gd`). The hole is truthful, and §7 finds it a job.
- **Clearance, measured on the worst body the game can make** — every born
  organ and four earned ones at level 3, seven slots (`A15_worst_extent`):
  the mouth's bow is **9 px** under the nose row, the flank oars 17, the tail
  21. Nothing touches.
- **A tether per live slot**: 1.2 px, alpha 0.16, the slot's hue (pale when
  empty), bowed 6%, from the chip's edge to the middle of its arc on the skin,
  drawn *under* the body. It is what makes a diagonal exact, and it carries
  §4's word. Rendered with and without while it was designed; without, a
  diagonal chip is an approximation of an arc.
- **The part being read lights up on the body.** The selected, hovered, armed
  or drop-target slot draws its arc on the skin: 3 px, 5 px off the rim, alpha
  0.85, in the hue of whatever would be there — the gene in hand while armed,
  the travelling gene while dragged. This is the owner's sentence answered on
  the body itself.

The tethers and the lit arc meet the skin through `Cilia.skin_point()`, the
one public point on the ovoid, so a mark and the fringe beside it are the same
curve to the pixel.

---

## 3. A slot

Inside its 96 x 56 control:

| part | geometry | notes |
| --- | --- | --- |
| helix | `draw_weave`, lobe 28, 3 lobes, x 6..90, mid y 19, amp 11 | lens 28:22 = 1.27:1, between choosing's 1.33 and the strand's 0.89 |
| rungs | `draw_rungs` at the middle lens, unchanged | full = worn, floating = carried, one per copy |
| selection | `draw_lens` at `LENS_SELECTED + 0.08`, backbone at `BACKBONE_LIT` | unchanged grammar |
| word | 14 px, baseline 50, `LABEL_TINT` (loud when selected, `WORD_UNEXPRESSED` when not worn) | the plain word, never the Greek |
| copies | three pips after the word, §3.1 | |
| focus | underline, inset 14, y 55, `FOCUS_TINT` | still not a box |

| state | what changes |
| --- | --- |
| empty | helix only: no rungs, no word, no pips |
| worn / carried / mixed | rungs and pips per copy: see §3.1 |
| armed, **empty** slot | shows the gene in hand as it would land: carried rungs, ring pips, its word (`A02`) |
| armed, **occupied** slot | **keeps drawing its own gene** — that is what the tap erases; the lens and the arc on the body take the incoming hue (`A03`) |
| drag source | no rungs, no word; lens in the hue of whatever would come back |
| drop target | lens in the travelling hue, arc lit |
| unearned | §3.2 |

The first build previewed the incoming gene over an occupied slot too.
Rendered, `eat` vanished from the screen while the hint under it still read
*the mouth · a daughter always wears it*. The occupant stays.

### 3.1 The copies are three pips

`PIP_R 3.4`, pitch 10, 7 px after the word, vertically at the word's x-height.
A gene's *level* is a different number, drawn inside the helix
(`beam-levels.md` §8.1).

| pip | means |
| --- | --- |
| filled disc, gene hue | a copy **this body wears** |
| ring, 1.4 px, gene hue | a copy **the DNA carries and the body does not** |
| dot, r 1.6, pale at 0.30 | room: a copy this gene could still gain |

Worn copies are counted against the DNA's: a body that kept an organ at two
copies while its slot was written with the same gene at one draws one disc, as
its one rung is worn.

Three ways were built on the same frame while this was designed:

- **Three rung seats inside the helix, no pips.** At a 28 px lobe the empty
  seats are dots on the backbone and read as noise; `beam` and `turn` looked
  like one rung and some grit. It is also the reading the owner already could
  not make. Rejected.
- **A digit.** It reads — `eat 2`, `swim 3` — but it has no scale (two of
  what?), it cannot say worn against carried, and it is the first number this
  game would put on a gene. And `statocyst`'s plain word was **`level`**: a
  digit rendered `level 3`. `A08` has that gene waiting at three copies. (The
  owner retired `statocyst` on 2026-09-28; the other reasons stand on their own.)
- **Pips.** Three marks are read without counting, the scale is on screen, and
  filled against hollow is `diegetic-hud.md` §1's integrated against held — the
  same shape meaning the same thing in the water and on this screen. Shape, so
  it survives greyscale. **Shipped.**

**The rungs stay.** They are the same count, and they are what makes the slot
a piece of DNA rather than a label. The rungs are the picture; the pips are
the reading.

### 3.2 Slots not yet earned

The helix at 0.32 brightness, no rungs, word, tether or focus, and
`MOUSE_FILTER_IGNORE`. Only generation 1 shows them — a daughter inherits a
seven-long layout — which is exactly when *your body will grow a slot here* is
news. Empty (bright, live) and unearned (faint, dead) read apart at both
shapes (`A01`).

---

## 4. Body against DNA

The drawing is `tiers()` + `body_layout()`; the slots are `dna()` + `layout()`.
Three cases, three marks, all shape:

| case | mark |
| --- | --- |
| the DNA carries a gene the body does not wear | ring pips, dim word, floating rungs — `dna-strand.md` §1.2, unchanged |
| the body wears it, elsewhere (moved) | solid pips here; the organ is drawn where it really is |
| **the body wears a different organ at this arc** | **the body names it**: that organ's word, 12 px, its own hue at 0.92, on the tether 56% of the way out from the skin |

**The word is needed, and a render proved it.** `A09` poses a newborn whose
forward-starboard slot now holds `sting` while her body wears `beam` there.
Both are violet and both are three strokes; without the word the drawing
cannot say which organ that is. This is `moving-a-gene.md` §2.3's rule — a word
only where the two registers disagree — moved from a second strand onto the
body it describes. `A12` shows three of them after two moves.

---

## 5. The waiting genes

**A tray above the figure**, `Genome/Waiting`, an `HFlowContainer` (h and v
separation 8, centred, min height 48):

- a `waiting` caption (15 px, the genome caption's own tint), then one chip per
  waiting gene, **head first** — soonest to lapse, #118's order;
- a chip is 116 x 48: the waiting gene's loose base pair (a bar, two caps, two
  halo rings) at x 16, the word at 14 px, and the level as **ring pips** — a
  waiting gene is carried by definition. `sting` eaten twice reads `○○•` and
  lands at two (`A05`);
- **in hand**: its word goes loud and an underline runs under it in its hue.
  The others are drawn at 0.55;
- **the wilt**: a chip's halos fade over its last 15 s (`Cilia.HELD_WILT`, the
  vesicle's own clock), read through `Genome.waiting_left(gene)`. Single player
  stops every clock while the screen is open, so only a pond shows it, and only
  a pond redraws the tray for it.

**Picking and placing** — the two taps are `moving-a-gene.md` §3.7's, unchanged:

| gesture | result |
| --- | --- |
| screen opens | the head is in hand |
| tap a waiting gene | it is in hand; any armed slot disarms |
| tap a slot, then tap it again | placed on the second lift; 300 ms guard, 4 s arm timeout |
| an arm lapses | back to **the gene in hand**, not the head |
| placed, more waiting | the head goes in hand (#118's rule) |
| drag a waiting gene onto an **empty** slot | placed — nothing is evicted and a move can still take it anywhere (`A06`, `A07`) |
| drag it onto an **occupied** slot | that slot arms: the drop is the first tap, and eviction still needs the second |

**Four fit on a row beside the caption; a fifth wraps** (`A08`: the column
grows to 58..662 and still fits). **The tray never shrinks while the screen is
open**: placing the fifth would otherwise pull the figure 56 px up under the
finger that just placed it. Whatever height it reaches is held until the screen
opens again.

### 5.1 The gene in hand is held by name

In a pond the menu stops nothing, so the queue can change under an open screen
(#118's review): a gene lapses, or is eaten again and goes to the back. **The
gene in hand is remembered as a gene, never as its place in the queue**,
because a place is exactly what those two change — held as "the second gene",
a lapse turns it into the next gene in line, one the player never picked, and
the confirming tap writes that over whatever the slot held, for good. Its
index is looked up with `Genome.waiting_index()` at the moment of placing.

The tray adds a case the single head could not have: a *different* gene can
lapse into the very empty slot that is armed for the gene in hand, and the tap
that would have placed into an empty slot would evict a gene the player never
saw there. So a confirming tap also requires the screen to still be the genome
— the same queue and the same layout it was built from — and when it is not,
the screen catches up the first frame no finger is down: a lapsed hand goes
back to the head, and a slot whose gene changed under its arm is disarmed,
because writing over a gene needs a first tap on that decision.

Forced deterministically — a `--pond=host` run, the menu open over live water,
the genome stepped by hand between the arming tap and the confirming one:

| race | result |
| --- | --- |
| the head in hand, `eat` armed; the head lapses; the tap lands the same frame | nothing written; `eat` stays; the next gene still waits at two copies; the head is in hand a frame later, nothing armed |
| the same, with the press before the lapse and the lift after | nothing written |
| `sting` in hand, empty slot 4 armed; the head lapses **into slot 4**; the tap lands the same frame | nothing evicted; the arm drops; two fresh taps then write `sting` over it |
| `sting` in hand (second in the queue), `eat` armed; the head is eaten again and goes to the back | the tap writes `sting` — the gene picked — at two copies; the other still waits |

---

## 6. The lines, and the keys

`Explain`, `Hint` and `Act` keep their rows, rules and colours, centred under
the figure. The word *locus* leaves the screen with the strand.

| constant | text |
| --- | --- |
| `ACT_ARM` | `tap a slot · your daughters may wear it` |
| `ACT_COMMIT_OVER` **new** | `tap again to write %s over %s` |
| `HINT_LOSES` **new**, while armed over a gene the body wears | `%s leaves your dna · your body keeps it` |
| `HINT_LOSES_CARRIED` **new**, while armed over a gene the body does not wear | `%s leaves your dna` |
| `ACT_DROP` **new** | `let go to place %s here` |
| `ACT_DROP_OVER` **new** | `let go, then tap again to place %s over %s` |
| `ACT_MOVE` / `ACT_CARRY` | `drag it to another slot` / `%s · let go over a slot to put it there` |
| `HINT_EMPTY` / `EXPLAIN_EMPTY` | `an empty slot · nothing to pass on from here` / `nothing here yet · an organ here grows on this side` |
| `ACT_QUEUE`, `ACT_QUEUE_ONE` (#118) | **deleted** — the tray is the queue |

`HINT_LOSES` replaces the odds only while a slot is armed over a gene: reading
*a daughter always wears it* about the gene the next tap destroys was the
wrong sentence at the worst moment (`A03`). Its second clause is only true of
an organ the body wears, so over a gene the DNA carries and the body does not
it stops after the first. The choosing screen reads `HINT_EMPTY` and
`EXPLAIN_EMPTY` too, where `this side` is its dart.

**Keys.** Plain arrows move focus and `Shift` + arrow moves the gene, both by
one table (read raw, as before — a content pack cannot add an action):

| slot | ← | ↑ | → | ↓ |
| --- | --- | --- | --- | --- |
| 0 nose | 4 | — | 3 | 2 |
| 3 fwd stbd | 0 | — | — | 1 |
| 1 stbd flank | — | 3 | — | 5 |
| 5 rear stbd | 2 | 1 | — | — |
| 2 tail | 6 | 0 | 5 | — |
| 6 rear port | — | 4 | 2 | — |
| 4 fwd port | — | — | 0 | 6 |

`↓` from the nose crosses the body to the tail, and `↑` back — down the body is
down the screen. Nothing wraps, and an unearned or missing slot is no move, the
strand's clamp argument in two dimensions; for a plain arrow that means the
focus stays where it is rather than falling off the ring to whatever control
lies that way. **Tab** goes round clockwise from the nose (0, 3, 1, 5, 2, 6, 4,
live slots only), then to `light`, and `Shift`+Tab from `light` comes back to
the last of them. `A12`: two Tabs from `resume` reach the nose; `Shift`+`→`
then `Shift`+`↓` walk `eat` to the flank.

---

## 7. The column

```
Hud/Pause/Center                      CenterContainer (unchanged)
  Columns   HBoxContainer  separation 64          (was Buttons, a VBox)
    Side    VBoxContainer  separation 48, SHRINK_CENTER
      Settings  VBoxContainer separation 12: Light, View, Feel (232 x 101, unchanged)
      Resume    Button 232 x 56  (+ Warn, unchanged)
      Leave     Button 232 x 56
    Genome  VBoxContainer  separation 8, min width 560, SHRINK_CENTER
      Caption   Label 15 px            "genome · first generation"
      Waiting   HFlowContainer         §5
      Figure    Control 420 x 372, IGNORE
        Body    Control, full rect, IGNORE    tethers, body, dissent words, arc mark
        Slots   Control, full rect, IGNORE    seven 96 x 56 chips, placed by SLOT_SEAT
      Explain / Hint / Act             unchanged
```

Measured with `--rects=` (x at 1280x720; add 160 at 2400x1080; y identical):

| | x | y |
| --- | --- | --- |
| `Columns` | 212 .. 1068 | 86 .. 634 (548 of 720) |
| `Side` / `Light` / `View` / `Feel` | 212 .. 444 | 92..193 / 205..306 / 318..419 |
| `Resume` / `Leave` | 212 .. 444 | 467 .. 523 / 571 .. 627 |
| `Genome` / `Waiting` / `Figure` | 508 .. 1068 / — / 578 .. 998 | 86..634 / 116..164 / 172..544 |
| `Explain` / `Hint` / `Act` | 508 .. 1068 | 552..578 / 586..606 / 614..634 |

**Why settings go left.** Full vision's camera pins the player's cell to the
middle of the screen, behind the pause scrim at 14% of its light (30% in a
pond).
Settings on the right put that ghost behind the `turn` slot and raised the
mean under it by **29%**. On the left, the centred row puts the ring's empty
port-flank cell **within 2 px of the screen's centre at any width** (the row is
856 wide and the cell sits 426 px in), so the ghost lands in the one cell with
nothing in it (`A13`). Measured against point of view, which has no ghost:
every slot's peak is within 1 of it (122.7 against 122.7, 161.5 against
160.7), and the ghost peaks at 46.4 in its own cell against the drawn body's
160.8.

**Touch.** Slots are 96 x 56 (144 x 84 device px at 2400x1080) and apart:
54 px across, 82 and 112 down. Waiting chips 116 x 48. Buttons and toggles
unchanged. **Reflow on a phone: none vertically**, both groups slide inward
with the wider canvas, and the pond's `Warn` still fits in the 48 px above
`resume` with 12 px to spare before the genome (`A14`).

---

## 8. Placing without the pause screen

*Issue #121, the second of the two changes. `normal_mode.gd`, under* Placing a
waiting gene without the pause screen.

**Hold your own body, slide the gene out toward the side it should grow on,
and let go.** The slot is the arc, so the gesture is literally *push it that
way*: the direction chooses the slot.

| | |
| --- | --- |
| **where** | a press within `max(1.15 r, 56)` canvas px of the body as it is drawn — the soma figure in point of view, the real cell in full vision. Each view answers `self_on_screen()`: centre, heading on the screen, radius |
| **`anywhere`** | the press is still a steer; it becomes this gesture only if it stays within 14 px for **0.35 s** (past `TAP_SECONDS` 0.28, so a tap on the body is still a dash) |
| **`stick`, `pads`** | the water is inert there, so the press opens the body at once; the other thumb keeps its control |
| **while held** | every free slot blooms outward as the **waiting gene's own organ** (`draw_tile_organ`, scale 1.15, turned to point out) at `max(2.3 r, 118)` canvas px along its bearing, alpha 0.34; the one nearest the finger's body-relative bearing lights (0.95) with a reach line, and the skin's ghost tuft and the vesicle's thread move to it. The aim is taken again every frame, so a still finger over a turning body lights what it points at now |
| **let go** | outside the body: placed into the lit slot. Inside it: nothing |
| **which gene** | the head — the one the body is already showing — held by name from the moment the body opens |
| **desktop** | the mouse is the same gesture. Or hold **`E`**: the free slot nearest the nose lights (starboard when two are level), `A`/`D` or `←`/`→` walk it round, one step a press, and letting go of `E` places. Steering is off while `E` is held |
| **`Esc`** | shuts any open body, keyed or held by a finger, with nothing placed — and is then not also a pause |

**Free slots only, never an eviction.** Placing into an empty slot destroys
nothing and a move can still change it, so one gesture is enough. The one
irreversible action keeps its two taps on the pause screen. With no free slot
the body does not open, and a press on it is an ordinary steer.

**The water keeps moving.** A pond cannot stop and a shortcut that paused
would be the pause screen again. The flick costs about 0.6 s under `anywhere`,
during which that finger is not steering, and about 0.25 s under the other
two, where the other thumb is. When to place becomes a real choice — which is
the game, and not a cost to design away.

**The body shuts, with nothing placed**, on a death, the menu opening, the
pinch of a division, a pond going still, the app losing focus and a touch the
system cancels (`canceled` -- palm rejection, an overlay, an OEM swipe: a
placement the player did not finish) — and when the gene it opened for lapses.
**The hold is timed from the press**: the frame that delivers it does not
count, because its delta is mostly time from before the finger touched glass,
and a stall there would otherwise open the body under a tap. The quickening still swims, so the body opens
in it, and a gene placed there reaches the daughters: they are rolled at the
pinch. **Placement asks again at the lift**, by name: the slot must still be
free and the gene must still be waiting. A gene can lapse into the first free
slot a frame before the finger comes up, and then the lift writes nothing —
the pause screen's #118 guarantee, that a gene which lapsed in hand never lets
a gesture place a different one.

**It is hand-hit-tested in `_input`**, before the GUI and before `cell.gd`,
exactly as `controls.gd` explains: no `Control` in the playfield and no
`MOUSE_FILTER_STOP`. A claimed pointer's later events are swallowed; an
unclaimed one reaches `cell.gd` untouched.

**Only the finger on the body stops steering**, through `cell.gd`'s
`release_pointer()`. `release()` drops whatever is held, and the design's
first build used it: one finger steering, a second holding the body, and the
first finger's steer fell from +0.42 to 0. There is a second half to it.
`emulate_mouse_from_touch` is on, so the **first finger down** also arrives as
a mouse, dispatched just before each of its touch events, and `cell.gd`'s one
slot usually holds that copy. Probed at 4.7: the copy follows whichever finger
went down first — not touch 0 — and a second finger gets none. So the run
learns which finger the copy follows from the events themselves, and releases
the copy only when it is the copy of the finger on the body.

**What it does to steering**, from `tools/drive.gd --offer=` at
`--fixed-fps 60`, `B` below with `--size=1280x720 --mode=0`:

| gesture | log |
| --- | --- |
| `anywhere`: press on the body, slide 150 px right in 0.2 s | steer +0.11, then +0.79. Never opened |
| `anywhere`: tap on the body, `myoneme` worn | `thrust … strength 1.00` in the same frame — the dash. Never opened |
| `anywhere`: press on the body, hold, slide 80 px left, lift | steer 0 throughout; opens at 0.35 s; `ocellus` into slot 4; no dash |
| `anywhere`: one finger steering, a second holds the body, slides, lifts | the first finger holds +0.42 throughout; opens at 0.35 s; into slot 5 |
| `pads`: port held, a second finger on the body | steer −1.00 throughout; opens on the press; into slot 5 — in either finger order |
| `stick`: stick deflected, a second finger on the body | steer +0.81 throughout; opens on the press; into slot 3 |
| `E` down, `D` held 0.3 s, `E` up | opens on slot 3; `D` walks to 5 once and does not turn the cell — steer 0 while it is held, where the same `D` after `E` turns it at +1.00; letting go of `E` places into 5 |
| `E` down, `Esc` | shut, nothing placed, steering handed back; the menu stays shut, and a second `Esc` pauses as it always did |
| the mouse: press, hold, slide up and right, lift | opens at 0.35 s; into slot 3 |
| no free slot: press on the body and hold 0.8 s | never opens; an ordinary steer |
| full vision: press, hold, slide left, lift | opens at 0.35 s; into slot 4 |

And by hand, lapsing the gene under an open body: the body shuts, the gene
goes where a lapse puts it — the first free slot — and the slot that was lit
stays empty. With a second gene waiting, a lift that reaches the run *after*
the lapse — the body still open for the first gene, the second now the head —
places nothing, and the second gene waits on. The same with a pond up.

The one behaviour that changes: under `anywhere`, a finger held still on your
own body while a gene waits no longer means *swim straight* — it opens the
body, and the bloom says so.

**It follows the body, not the screen.** `B02`: nose pointing east, a finger
sliding straight up lands on the forward-port arc, drawn up and to the right.

**The line that teaches it is the one already there.** The five-second sense
grant said `a sense grew · back to place it`; it says `a sense grew · hold
your body to place it` on a phone and `a sense grew · hold e to place it` at a
keyboard. Nothing new is put on the screen. The grant always comes with a free
slot, so the line is true when it is said; the gesture places the head, which
is the sense unless an earlier meal is still waiting ahead of it. Owner's call
4.

---

## 9. The choosing screen

**Not changed, and not trivial.** Its strands still use darts, so the owner's
complaint stands there. Rings of 96-px slots around both daughters need about
400 px each and the daughters sit 264–320 px apart, so the bodies would have to
move — a redesign of `choosing.md` §3, not a restyle. The follow-up: each
daughter wears her own ring of slots, scaled down, when that screen is next
opened up. `draw_slot_dart` stays in `cilia.gd` for it.

---

## 10. What changed

| file | change |
| --- | --- |
| `normal_mode.tscn` | §7's tree |
| `normal_mode.gd` | the figure replaces the rows: `SLOT_SEAT`, `SLOT_NEIGHBOUR`, `SLOT_RING`, the chips (`_make_slot`, `_draw_slot`, the pips), `_draw_figure_body` with its tethers, the body's words and the lit arc, `_wire_focus`; the tray (`_in_hand` by gene, its chips, picking, dragging, the wilt, the no-shrink latch); `_move_key` returns a direction; `_commit_slot` places `waiting_index(_in_hand)`; `_catch_up` for a genome that changed under the screen; §6's strings. Deletes the caps, gutters, spacers, the body row and `_queue_text` |
| `cilia.gd` | `skin_point()`, the one public point on the ovoid, for the tethers and the lit arc |
| `tools/drive.gd` | `--body=`, the `shift-up` / `shift-down` chords, `--rects=` on the new tree, every chip included |
| §8: `normal_mode.gd` | the gesture, under *Placing a waiting gene without the pause screen*: `_offer_input` first in `_input`, `_step_offer` before every early return in `_process`, the emulated mouse's finger, and the body shut on a menu, a death and a lost focus; `_say_sense`'s two strings |
| §8: `cilia.gd` | `draw_pending(…, offer)` and `_draw_offer`, the bloom; the tuft and the thread follow the aim |
| §8: `soma.gd`, `vision.gd` | pass `offer` through, and answer `self_on_screen()` |
| §8: `cell.gd` | `release_pointer()`, which lets go of **one** pointer |
| §8: `tools/drive.gd` | `--key-down=` / `--key-up=`, keys `e a d`, and `--offer=`, the gesture's log |

`genome.gd` is unchanged: `waiting_index()` and `waiting_left()` were already
there. No `project.godot`, no `version.json`, no binary change, no `addons/`,
no `ci/`, no rule the referee copies. **Ships as a content pack.**

---

## 11. Rendered and judged

Point of view unless noted. Every frame is `tools/shot.tscn` driving
`tools/drive.tscn` at `--fixed-fps 60`, at both shapes; at 2400x1080 every
canvas x below is 160 further right. Common flags:

```
G = --genome=cytostome:2,cirrus:1,flagellum:3,ocellus:1:3 --radius=34 --esc-at=1.0 --seed=7
Q = --sample=ampulla,trichocyst:2,chemocyte
```

| frame | flags | judgement |
| --- | --- | --- |
| `A01_dna` | `G --sample=ampulla --mode=0` | passes — five live slots, two unearned, each part named where it is |
| `A02_arm_empty` | `A01` `--touch=1.4:638,204` | passes — the slot previews `ping ○••`, the forward-port arc lights |
| `A03_arm_over` | `A01` `--touch=1.4:788,204` | **failed first** (occupant vanished); passes — `eat` stays, lens and arc go violet, `eat leaves your dna · your body keeps it` |
| `A04_queue` | `G Q --mode=0` | passes — three waiting, head in hand, `sting ○○•` |
| `A05_pick_second` | `A04` `--touch=1.3:819,140 --touch=1.7:638,204` | passes — second gene in hand, armed, `two copies · a daughter probably wears it` |
| `A06_tray_drag`, `A07_tray_dropped` | `A04` `--press=1.3:943,140`, four `--slide=` to `638,204`, then `--lift=1.9` | passes — `let go to place smell here`, then `smell ○••` in place, the tray one shorter and the keyboard on its head |
| `A08_five_waiting` | `G --sample=ampulla,trichocyst:2,chemocyte,pellicle,statocyst:3 --mode=0` | passes — the fifth wraps, 58 px clear top and bottom |
| `A09_newborn` | `--radius=28.3 --dna=… --body=cytostome:2:0,cirrus:1:1,flagellum:2:2,ocellus:1:3,pellicle:2:5` | **failed first** (sting over a worn beam was invisible); passes with the body's word |
| `A10_seven` | seven genes, `--radius=39.5` | passes — seven slots, four earned organs, nothing crowds |
| `A11_move_drag` | `G --press=1.4:938,204`, five `--slide=` to `638,206` | passes — base pair over the finger, source hollow, target lit, arc lit |
| `A12_keys` | `G --tap=1.3:tab --tap=1.4:tab --tap=1.6:shift-right --tap=1.9:shift-down` | passes — `Shift`+`→`, `Shift`+`↓`, focus follows, three body words |
| `A13_fullvision` | `A01` with `--mode=1` | passes — the ghost sits in the empty cell (§7 numbers) |
| `A14_pond_warn` | `A13` with `--pond=host` | passes — a real pond: `Warn` above `resume`, 12 px clear |
| `A15_worst_extent` | seven level-3 genes, `--radius=39.5` | passes — 9 px at the nose is the tightest gap |

An arming frame at 2400x1080 wants the machine to itself: the 4 s arm timeout
is wall clock, and four software-GL renders in parallel stretched 0.9 s of game
time past it, so the arm had lapsed by the shot. Rendered alone it holds.

The gesture's frames, in play. The hold is counted in game time, so these hold
under any load:

```
B = --genome=cytostome:1,cirrus:1,flagellum:1 --radius=37 --sample=ocellus --seed=7
```

| frame | flags | judgement |
| --- | --- | --- |
| `B01_play_pov` | `B --mode=0 --scheme=0 --press=1.0:640,360`, three `--slide=` to `540,249` | passes — three buds, forward-port lit, the tuft on the skin agrees |
| `B02_play_fv_turned` | `B --mode=1 --scheme=0 --hold=d --press=2.2:640,360`, three `--slide=` straight up to `640,230` | passes — the bloom turns with the body: nose east, the finger up, forward-port lit |
| `B03_play_keys` | `B --mode=0 --scheme=0 --key-down=1.2:e --tap=1.5:d` | passes — `E` lit forward-starboard, `D` walked to rear-starboard |
| `B04_play_pads` | `B --mode=0 --scheme=2 --press=1.0:96,624,1 --press=1.2:640,360`, two `--slide=` to `760,470` | passes — the port pad held and the body open at once, rear-starboard lit |
| `B05_placed_then_paused` | `B01` then `--lift=1.9 --esc-at=2.4` | passes — the flicked gene is in the DNA at the forward-port slot, carried: `beam ○••` |
| `B06_gift_line` | `--genome=cytostome:1,cirrus:1,flagellum:1 --radius=30 --seed=7 --mode=0`, at 6.4 s | passes — `a sense grew · hold e to place it` under the body. The phone's `hold your body` wording is chosen by `OS.has_feature("mobile")`, and this container is not a phone |

`B01` to `B04` are the design's own frames to the pixel; `B05` differs by 32
pixels, inside one hollow pip.

---

## 12. Left open

1. **The born three draw at home whatever slot holds them.** `_draw_fringe`
   skips `cytostome`, `cirrus` and `flagellum` in its slot walk and the gape is
   always at the nose. The strand hid this; a body does not: `eat` moved to the
   flank (`A12`) tethers to an arc with no mouth on it, and a daughter born that
   way would draw her mouth at the nose beside a slot that says `eat` at the
   flank. Either those three are pinned to slots 0–2, or their slot is storage
   and says so. Not decided here.
2. **The body's word at the nose crosses the mouth's bow** at level 2 and up
   (`A12`). Readable; the tightest thing on the screen.
3. **On a phone the lit bud is under the thumb.** The reach line and the tuft
   on the skin are what stays visible; nothing animates the gene into its slot
   on release. A 0.3 s settle would close the loop.
4. **The bloom was not measured against the senses.** It only exists while a
   finger holds the body, but `diegetic-hud.md` §4's glance test has not been
   run on it.
5. **Tray hover on desktop** — pointing at a waiting gene to read it — is not
   built.
6. ~~**A move while a gene is in hand leaves its destination armed.**~~
   **Closed before it shipped** -- the strand had done the same. A drop, a
   `Shift`+arrow and a drag let go on nothing or back where it began are none
   of them a first tap on that slot, so with a gene in hand each of them now
   hands the selection back to the hand, and the keyboard alone follows the
   gene. Measured by mouse: the beam dragged to the empty forward-port slot and
   tapped once used to be written over by the waiting gene; now that tap only
   arms (`tap again to write ping over beam`). Writing over a gene takes two
   taps on its slot, both of them the player's, on every path.

7. **Body first, then a steering finger: the second finger does not steer.**
   cell.gd steers with one finger, the first down, and ignores any other. With
   the steering thumb down first -- the order this was designed for -- it keeps
   its steer while the other opens the body (+0.42 held). The reverse order is
   the gap: a finger resting on the body is cell.gd's steering finger until the
   hold takes it, and the second finger, pressed meanwhile, was ignored and
   stays ignored until it is lifted and put down again, placement or not.
   Closing it means cell.gd adopting a finger it never saw press, which is a
   change to steering itself and not to this gesture.

---

## 13. Owner's call

The lead took the recommended option in every row, and that is what shipped.
Each is a switch rather than a rewrite; the line under the table says where.

| # | Question | Options | What it means |
| --- | --- | --- | --- |
| 1 | How does a gene show its copies? | **three dots, filled up to its copies ✓ recommended** · a number · both | You see `●●○` beside `eat`: two of three, and room for one more. A hollow dot means your daughters carry it but you do not. A number says `2` but not *out of three*, and cannot tell those apart |
| 2 | What do the words under the body call it? | **keep `two copies` ✓ recommended** · `level two` | The dots are the copies at a glance; the line explains why it matters — more copies, more likely a daughter wears it. `level two` matches your word but loses the reason |
| 3 | How do you place a gene without pausing? | **hold your body, slide it where it should grow ✓ recommended** · a button that appears in a corner · double-tap your body | Recommended: nothing new on screen, the direction you push is the side it grows on, and a quick tap still dashes. A corner button is one more control in the water; a double-tap would steal the dash |
| 4 | What does the gift's line say? | **`a sense grew · hold your body to place it` ✓ recommended** · keep `back to place it` | The one sentence the game already shows when a free gene arrives, pointing at the new shortcut instead of the pause screen |
| 5 | How long must you hold your body? | **0.35 s ✓ recommended** · 0.5 s | Shorter than this and a quick tap stops being a dash. Longer is safer and slower. Only playing it will tell |
| 6 | Dropping a waiting gene on an empty slot | **places it at once ✓ recommended** · still asks for a tap | Nothing is destroyed and you can still move it later, so no confirmation is needed. Writing over a gene still takes two taps |

Where each switch is, all in `game/normal/normal_mode.gd`: 1, `_draw_pips`;
2, `HINT_CHANCE`; 3, the section *Placing a waiting gene without the pause
screen*, whose entry is `_offer_input`; 4, `_say_sense`; 5, `OFFER_HOLD`; 6,
`_drop_waiting`, which would arm an empty slot as it arms an occupied one.
