# DNA slots: the screen and the look

The owner, 2026-10-03:

> "When put in a dna slot that expresses inside the cell, it becomes
> poisonous. But when attached to the mouth, it becomes venom."
>
> "The toxic gene or whatever we call it could have even more variations.
> Paralyze, sleep, damage over time, etc"

and, answering the first drafts:

> "All recommended"
>
> "Just a precision for 3 : We need add body internal slots. Those express
> inside the body. The direction slots express outside the body."

This is the screen and the look for `dna-slots.md` (the mechanics, revision 3),
its §10 item by item and its §10.2 redo list. Every owner's row, 1 to 15, is
answered as recommended. Row 3's precision makes the two places **outside**
(the seven direction slots) and **inside** (one new slot), and row 9's words
are now the owner's own: `outside` and `inside`.

**Status.** Designed from the code at `d08b0c3` and from `dna-slots.md` rev 3.
Mocked in a throwaway scratch copy over a real run (`tools/shot.tscn` driving
`tools/drive.tscn`, `--rendering-driver opengl3 --fixed-fps 60`, `--seed=`),
with an absolute `XDG_DATA_HOME`. Every frame in §10 was rendered at 1280x720
and 2400x1080, in English and French where words appear, and looked at. Frames
were rendered three times and diffed to **0 differing pixels** before any
comparison. Nothing was built in the repo. The numbers here set how a dose and
a form *look*; how strong they are is the mechanics' (§15 there).

**What revision 3 changed** against the screen the owner answered:

- the mouth's arc and its three threads are gone; the **inside slot sits in
  the body's middle** on the pause figure (§3.1);
- venom draws **where it works**: fangs on the lips at the front, barbs on the
  arc at a side or the stern (§2.2, §2.3);
- poison is granules with **no arc mark**, because the inside has no arc (§2.4);
- a gene that faces out is **refused inside, in words** (§3.4);
- the quick placement reaches the inside: **slide out, then back in** (§3.7);
- the choosing screen gains **an inside locus** (§3.8).

The look of a dose in the water and in point of view (§4, §5), the death (§6),
lime, and the corrections already sent are unchanged.

---

## 0. Decided, in one place

1. **The colour is the strain, the shape is where it works.** Venom and poison
   of one strain wear one hue. Venom at the front is **fangs on the lips**;
   venom on a side or the stern is **barbs standing out of that arc**; poison
   is **granules under the whole skin**, with nothing at any one arc. A
   full-vision player tells all three apart at a glance and with no colour.
   §2.
2. **The corrosive toxin leaves nutrient green for lime**,
   `Color(0.84, 0.98, 0.22)`. §2.1.
3. **A load is drawn inside the body that carries it**, by the one routine
   every cell is drawn with, in both views and the replay: a stain whose
   outline is its kind, and for harm pits in the rim. §4.
4. **Your own dose in point of view lives on the figure**, at `FADE_DOSE` 0.68;
   its arrival rides on what brought it (a lime bruise at the bite's bearing, a
   lime meal flood). No rhythm, no beat, no contour change. §5.
5. **A death by poison is the quiet close, lit in the strain's hue.** §6.
6. **The inside slot is a chip like the seven, sitting in the body's middle**,
   on a window of the base colour. The ring round the body is outside, the
   chip in it is inside: the figure says the rule without a word. While a toxin
   is in hand, every empty outside slot ghosts `venom` and the inside ghosts
   `poison`. §3.1, §3.2.
7. **Nothing on this screen refuses silently.** A move that would make a form
   you carry, a copy to a form at three, and any gene that faces out, armed or
   dropped inside, each dim the slot and say why while the finger is down. §3.4.
8. **A waiting toxin is called `toxin`** until it lands. §3.5.
9. **The quick placement reaches the inside**: hold your body, slide out, and
   come back in to keep it inside. Letting go without leaving still places
   nothing. §3.7.
10. **No words in the playfield, no HUD surface, no new scene node** (the
    inside chip is an eighth chip built in code, as the seven are). One new
    shader uniform, in phase 4 (the sleep veil). Everything is GDScript and
    one `.gdshader`, so it ships as content; `binary_version` does not move.

**Owner's calls: none new** (§12). Rows 9 and 10, this screen's two, are
answered: `outside` / `inside` in the owner's words, and `toxin`.

---

## 1. Words

Every word is the game's register: lowercase, `vous` in French, a gene word in a
sentence with no article. Measured in the game's own font
(`ThemeDB.fallback_font`, as the lint measures). Widths are EN / FR.

| constant | English | French | room | EN / FR | phase |
|---|---|---|---|---|---|
| `WORDS[veneneux]` | poison | poison | 47 at 13 | 43 / 43 | 1 |
| `WORDS[toxicyst]` | venom | venin | 47 at 13 | 44 / 35 | 1 |
| `TOXIN_WORD` (tray, hand, drag) | toxin | toxine | 47 at 13 | 33 / 40 | 1 |
| `EXPLAINS[toxicyst]`, venom at the front | your bite leaves venom, which goes on hurting | votre morsure laisse du venin, qui continue de faire mal | 440 at 15 | 345 / 412 | 1 |
| `EXPLAINS_SIDE` **new**, venom on a side | whatever bites you on that side takes venom | ce qui vous mord de ce côté prend du venin | 440 at 15 | 333 / 323 | 1 |
| `EXPLAINS_STERN` **new**, venom at the stern | whatever bites you from behind takes venom | ce qui vous mord par-derrière prend du venin | 440 at 15 | 337 / 338 | 1 |
| `EXPLAINS[veneneux]`, poison | whatever bites or swallows you takes your poison | ce qui vous mord ou vous avale prend votre poison | 440 at 15 | 368 / 377 | 1 |
| `EXPLAIN_TOXIN`, a toxin in hand, no slot chosen | a toxin that goes on hurting, as venom or as poison | une toxine qui fait mal longtemps, en venin ou en poison | 440 at 15 | 379 / 420 | 1 |
| `EXPLAIN_INSIDE` **new**, the empty inside read | nothing inside yet · a toxin here becomes poison | rien dedans pour l'instant · une toxine ici devient du poison | 520 at 15 | 349 / 429 | 1 |
| `HINT_INSIDE` **new**, under it | inside your body · only a toxin goes here | dans votre corps · seule une toxine va ici | 560 at 14 | 272 / 273 | 1 |
| `ACT_ARM_FORMS` (for `ACT_ARM`, a toxin in hand) | tap a slot · venom outside, poison inside | appuyez sur un emplacement · venin dehors, poison dedans | 560 at 14 | 271 / 406 | 1 |
| `ACT_FACES_OUT` **new** | %s works only outside | %s ne fonctionne que dehors | 560 at 14 with word | 174 / 229 at worst | 1 |
| `ACT_COMMIT_FORM` | tap again to place %s here | appuyez à nouveau pour placer %s ici | 560 at 14 | 204 / 280 | 1 |
| `ACT_RAISE` | tap again to add a copy to %s | appuyez à nouveau : %s gagne une copie | 560 at 14 | 224 / 302 | 1 |
| `ACT_RAISE_FULL` | %s has three copies already | %s a déjà trois copies | 560 at 14 | 214 / 171 | 1 |
| `ACT_DROP_RAISE` | let go, then tap again to add a copy to %s | lâchez, puis appuyez à nouveau : %s gagne une copie | 560 at 14 | 304 / 384 | 1 |
| `ACT_REFUSE` | here it would become %s, which you already carry | ici il deviendrait %s, que vous portez déjà | 560 at 14 | 365 / 305 | 1 |
| `ACT_LAND_FORM` | let go to move %s here · it becomes %s | lâchez pour déplacer %s ici · il y devient %s | 560 at 14 | 315 / 334 | 1 |
| `ACT_SWAP_FORM` | let go to swap %s and %s · %s becomes %s | lâchez pour échanger %s et %s · %s devient %s | 560 at 14 | 388 / 426 | 1 |
| `ACT_SWAP_COPIES` | let go to swap %s and %s · they trade copies | lâchez pour échanger %s et %s · ils échangent leurs copies | 560 at 14 | 350 / 445 | 1 |
| `STRAIN_WORDS` | corrosive · paralysing · sleeping | corrosif · paralysant · endormant | in the name, §3.6 | 58 / 65 / 53 at 13 | 3, 4 |

- **`dehors` / `dedans`, not `à l'extérieur` / `à l'intérieur`.** The owner's
  words are plain, and so are these: `rien dedans pour l'instant` is already
  in the game's French. On screen the longer pair is 469 px against 406, and
  reads as a manual.
- **`ACT_FACES_OUT` says what the gene does, not what the slot refuses.**
  `swim works only outside` is true, short, and teaches the rule from the
  other side. `fonctionne`, not `marche`: `works as level %d` is already
  `fonctionne comme niveau %d`.
- **`EXPLAINS_STERN` is new to the mechanics' list.** `that side` read wrong
  for the tail, which is the side a player least thinks of as one.
- **The numbers lines** (§3.3 there), with `{} stack` / `{} stacks`:

  | form | English, widest | French, widest | of 650 |
  |---|---|---|---|
  | venom at the front | `each bite leaves 3 stacks of venom · a stack takes 5% of a body your size over 9.7 s` | `chaque morsure laisse 3 doses de venin · une dose prend 5 % d'un corps de votre taille en 9,7 s` | 553 / 638 |
  | venom on a side | `whatever bites you on that side takes 3 stacks · a stack takes …` | `qui vous mord de ce côté prend 3 doses · une dose prend …` | 631 / 638 |
  | poison | `whatever bites you takes 3 stacks a bite · a swallower takes 48 stacks` | `qui vous mord prend 3 doses par morsure · qui vous avale prend 48 doses` | 466 / 498 |

  The numbers say `qui vous mord`, as the shipped `qui vous mord subit {} de sa
  morsure` does; the gene lines say `ce qui vous mord`, as the shipped `ce qui
  vous mord paie` does. `ce qui vous mord de ce côté` in the numbers came to
  656, six over.
- **`HINT_SISTER` goes.** A shift no longer crosses between inside and outside,
  so it never changes a form; where a shifted venom works is said by each
  daughter's own line (§3.8).

---

## 2. The look

### 2.1 Colour: one hue a strain

```gdscript
# cilia.gd, HUES -- both forms of a strain wear its hue
&"veneneux": Color(0.84, 0.98, 0.22),   # poison, corrosive -- lime, 71 deg (was 128)
&"toxicyst": Color(0.84, 0.98, 0.22),   # venom, corrosive
# phase 3: &"paraneux", &"paracyst": Color(0.42, 0.84, 1.00)   # ice, 197 deg
# phase 4: &"hypnoneux", &"hypnocyst": Color(0.80, 0.78, 1.00) # pale moon, low saturation
```

- **Why lime.** `veneneux`'s 128° is the nutrient green of the scent bloom and
  the taste ring, within a degree: a poison drawn in it looks like food, and a
  dose felt in it would read as a smell. Lime is the free 72° the retired
  `rhabdom` left, acid by every convention, and the only lime on either screen.
  It is 24° from the mouth's green and 19° from `plastid`'s gold, so where it
  works is carried by shape (§2.2 to §2.4), the rule `cilia.gd` keeps for
  sixteen hues.
- **Ice and pale moon** are starting values for phases 3 and 4, to be
  re-rendered then; shape carries the kind anyway (§4.4).
- `signal_bus.gd` copies the three hues as `STRAIN_COLORS`.

### 2.2 Venom at the front: fangs on the lips

At the front (slots 0, 3 and 4) venom rides on the bite, so it is drawn on the
organ every encounter is read off: **the lip bow**. Barbs stand out of the
bow's two corners, splayed away from the centreline, a bead at each tip; the
threat bow's teeth point in.

```gdscript
# cilia.gd -- drawn after draw_gape, for a mouth form whose worn slot is in FRONT
const FANG_FROM := 0.50          ## of the bow's half-span, from the apex
const FANG_TO := 0.96
const FANG_SPLAY := 28.0         ## degrees further out than the bow's normal
const FANG_LEN := 0.24           ## of the gape, x TIER_LEN[copies]; floor FANG_MIN
const FANG_MIN := 5.0            ## canvas px, through `unit`
const FANG_WIDTH := 1.9
const FANG_ALPHA := 0.95
const FANG_BEAD := 0.06          ## of the gape; floor 1.4 canvas px
# pairs: one a side per copy (1, 2, 3), evenly from FANG_FROM to FANG_TO
```

- **On the lips whichever front slot holds it**, because at full vision's true
  size a forward-diagonal venom drawn at its arc was a lime smudge beside the
  mouth. A body with no mouth (gape 0) draws no fangs: its front venom bites
  nothing, and the slot still says `venom`.
- **Clearance**, measured by differencing a frame against the same frame drawn
  without fangs: 36 px from every word and pip in `U01`; in the worst figure
  (`S02`: every gene at three) 19 px from `venom`, 16 px from its underline
  when it is selected. A side venom's barbs at three copies, on the flank,
  stand 25 px from the flank chip, the nearest (`I05b`).

### 2.3 Venom on a side or the stern: barbs on that arc

A side venom stings the mouth that bites that side, so **it is drawn on the side
it guards**: beaded barbs standing out of the slot's arc, fanned, the
extrusomes a real ciliate fires where it is touched.

```gdscript
# cilia.gd -- drawn with the fringe, for a mouth form whose worn slot is not in FRONT
const GUARD_FROM := 0.15         ## of the arc left bare at each end
const GUARD_LEN := 0.26          ## of r past the skin, x TIER_LEN[copies]; floor GUARD_MIN
const GUARD_MIN := 5.0           ## canvas px
const GUARD_FAN := 16.0          ## degrees either side of the normal, at the end barbs
const GUARD_WIDTH := 1.9
const GUARD_ALPHA := 0.95
const GUARD_BEAD := 0.055        ## of r; floor 1.4 canvas px
# barbs: two a copy (2, 4, 6), evenly across the arc's middle
```

- **Two a copy, not a pair a copy**: one arc has no left and right, and two
  barbs is the fewest that read as a row of points rather than one bristle.
- **No haze and no pigment**: an organ at an arc has both, and this is a
  weapon, not an organ. Fanned, it reads as spines (`W20`, `W21`).
- **The pause figure lights the arc it guards** when the slot is read or armed,
  with the arc mark every slot already has (`I05`).

### 2.4 Poison inside: granules, no arc

Inside has no arc, so poison draws **no pigment and no haze at any one place**:
only its granules, scattered just inside the rim round the whole body, the mouth's
arc left clear.

```gdscript
const GRANULE_FROM := 74.0       ## degrees either side of the nose left clear
const GRANULE_COUNT := 12        ## x TIER_COUNT[copies]: 12, 16, 20
const GRANULE_SEAT := 0.84       ## of r, jittered by 0.07 sin(2.3 i + 1.1) - 0.02
const GRANULE_SPREAD := 0.38     ## of one step, sin(3.7 i): scattered, never strung
const GRANULE_R := 0.045         ## of r; floor 1.5 canvas px
const GRANULE_ALPHA := 0.80
```

`_draw_fringe` draws every inside form in `tiers` after the outside layout, so
nothing inside is ever drawn at `arc_for_slot`. `arc_for_slot` is never asked
for an inside index. `default_order` leaves inside forms out and seats a water
cell's venom at slot 3.

### 2.5 Tiles

`draw_tile_organ`, the glyph beside the gene's line and the bud of the quick
placement: **venom** four beaded rods standing out of the dome; **poison** the
dome, the pigment and seven dots on an arc 4.5 px outside it. A toxin in hand
with no slot chosen has no form, and its line draws no organ.

### 2.6 The strain's shape (phase 3)

A strain must survive greyscale on the slot. **The shape is the bead**: the
fangs', barbs' and granules' beads are discs for corrosive, diamonds for
paralysing and rings for sleeping, and the same 10 px bead sits in the slot
chip's third lobe in the strain's hue at 0.9. The stain inside a dosed body
echoes it (§4: lump, shard, haze). A starting design for the phase-3 build to
shoot.

---

## 3. The pause screen

### 3.1 The inside slot

**The seven slots round the body are outside; the inside slot sits in the
body.** The figure already draws the body in the ring's middle cell
(`FIGURE_R` 60); the eighth chip is seated on it.

```gdscript
# normal_mode.gd
const SLOT_SEAT: Array[Vector2] = [ ...seven as today...,
	Vector2(0.0, 6.0),        # 7 inside: on the body, 6 px aft of its centre
]
const SLOT_RING: Array[int] = [0, 3, 1, 5, 2, 6, 4, 7]   # Tab: round, then in
const SLOT_NEIGHBOUR: Array = [
	[4, -1, 3, 7],    # 0 nose: down goes in
	[7, 3, -1, 5],    # 1 starboard flank: left goes in
	[6, 7, 5, -1],    # 2 tail: up goes in
	[0, -1, -1, 1], [-1, -1, 0, 6], [2, 1, -1, -1], [-1, 4, 2, -1],   # 3 to 6, as today
	[-1, 0, 1, 2],    # 7 inside: up the nose, right the flank, down the tail
]
```

| | value |
|---|---|
| **seat** | `FIGURE_AT + (0, 6)`: canvas (788, 348) at 1280x720, (948, 348) at 2400x1080 |
| **size and touch target** | `SLOT_SIZE` 96 x 56, as every slot: **144 x 84 device px** at 2400x1080. 54 px from the flank chip, 88 from the nose's, 106 from the tail's. The body under it takes no input, so the chip is the whole target |
| **the window** | an ellipse 50 x 29 (radii) on the chip's centre, `Color(0.023, 0.055, 0.05)` at 0.62, drawn first. The nucleus and a stain sit behind it, not through the word |
| **the chip** | today's chip grammar unchanged: helix (lobe 28, three lobes), rungs, word at 14 px, pips, focus underline. **No tether**: it is already where it acts |
| **the lit mark** | read, hovered, armed or a drop target, it lights **the whole inside**: the ovoid at 0.88 r, 64 steps, 2 px, in the hue of what is or would be there, at 0.55. Every outside slot lights its arc |
| **live** | always: every cell has its inside from birth. Never drawn unearned |

| state | the inside chip shows | phase |
|---|---|---|
| empty | the helix on its window | 1 |
| ghost: a toxin in hand, nothing armed | `poison` and ring pips at `GHOST_INK` 0.42 (`U03`) | 2 |
| armed with a toxin, empty | the preview `poison`, carried rungs and ring pips; lens in the hue; the inside lit (`U05`) | 1 |
| occupied | `poison` and its pips; the body's granules (`U02`) | 1 |
| armed with a toxin, poison inside | the copy lands here: lit as the target, the new copies as ring pips (`U06b`) | 1 |
| **refused**: a gene that faces out, armed, dragged or dropped over it | no lens, the weave at 0.45, no preview; `ACT_FACES_OUT` (`I02` to `I04`) | 1 |
| drag source / drop target | as every slot: the travelling hue, the inside lit | 1 |

- **In the body, not in the empty port-flank cell.** That cell is where full
  vision's own ghost lands (`dna-body.md` §7), and a chip there would read as a
  port-flank slot: a place on the skin. In the body it is the only chip with no
  thread to the skin, and that is the whole difference between the two places.
- **A window, not a box.** Without one the word sat on the nucleus's teal
  glow: the word's contrast with its ground is **3.7:1** without the window and
  **5.1:1** with it (`U02`, against the same frame drawn without one). An
  ellipse echoes the body round it and has no edge to read as a button.
- **The pause figure carries your loads**, as it carries hunger's crumple
  (`hunger.md` §2.4): a reminder when paused, and live in a pond, where a dose
  goes on hurting under the menu. The stain shows round the window and the pits
  stay in the rim; the word stays on the window (`I09`).
- **The keyboard reaches it from the three slots beside it**, and Tab after
  the ring. `Shift`+arrow from it reaches only the nose, the flank and the
  tail, which are rarely empty, so moving poison out to a diagonal is a drag or
  two placements; a keyboard player loses nothing they cannot do another way.

### 3.2 What a toxin becomes before it lands

| state | the slot shows | phase |
|---|---|---|
| a toxin in hand, an **empty** slot not armed, whose form you do not carry | a ghost: `venom` on every empty live outside slot, `poison` inside, ring pips at the hand's copies, at `GHOST_INK` 0.42, no rungs | 2 |
| the same, whose form you **do** carry | nothing: a tap there adds a copy, and says so when armed (§3.3) | 2 |
| **armed**, empty | the armed preview, as the form of this place | 1 |
| **armed**, occupied by a gene of one form | the occupant stays; `ACT_COMMIT_OVER` names the form (`tap again to write venom over sting`) | 1 |
| a drag from a slot over an empty slot | the form it lands as, at 0.75; `ACT_LAND_FORM` when it converts (`U09`, `U09b`) | 1 line, 2 ghost |
| a drag over an occupied slot | the occupant stays; `ACT_SWAP_FORM` or `ACT_SWAP_COPIES` (`U10`) | 1 |
| a tray drag over an empty slot | the form at 0.75; the travelling pair says `toxin` (`U11`) | 1 line, 2 ghost |

The Explain line reads the same way: an empty slot armed or under the finger
explains **the form it would make, where it would work**: the front's line at
0, 3 or 4, `EXPLAINS_SIDE` at 1, 5 or 6, `EXPLAINS_STERN` at 2, poison's
inside. A toxin in hand with nothing chosen explains `EXPLAIN_TOXIN`, with no
organ.

### 3.3 Add a copy (phase 1 line, phase 2 picture)

Armed over a slot whose form you carry, **elsewhere or here** (`eat` is not
written over, `dna-slots.md` §5.2):

- the tapped chip keeps what it has; its lens is a trace (`CHIP_LENS` x 0.35);
- the chip the copy goes to is drawn as the target: lens and lit backbone in
  its hue, its copies as they will be, the new ones as **carried rungs and ring
  pips**;
- the mark lit on the body is the target's: its arc, or the inside;
- `Hint` prices the copy where it lands; `Explain` is the target's form;
  `Act` is `ACT_RAISE`.

`U06`: slot 4 tapped, `venom ●●○` lights at slot 3. `U06b`: the inside tapped
with poison in it, and the copy lands in place: `tap again to add a copy to
poison`.

### 3.4 Refusals, while the finger is down

| case | slot under the finger | line | the second tap / the drop |
|---|---|---|---|
| a move that would make a form you carry | no lens; its weave at 0.45 | `ACT_REFUSE` | refused by `_slot_can_drop` (`U08`) |
| a copy to a form at three copies | the target's weave at 0.45, no lens | `ACT_RAISE_FULL` | refused; the gene stays in hand (`U07`) |
| **a gene that faces out**, armed on the inside | the inside's weave at 0.45, no lens, no preview | `ACT_FACES_OUT` with the hand's word | not committable (`I03`) |
| **a gene that faces out**, dragged or dropped on the inside, from a slot or the tray | the same | `ACT_FACES_OUT` with its word | refused (`I02`, `I04`) |
| **a swap that would put a gene that faces out inside** (poison dragged onto `eat`) | the same, on the target | `ACT_FACES_OUT` with the occupant's word | refused |
| `Shift`+arrow onto any of these | the focus stays | the same line, for 2 s | refused (`I08`) |

The full case is a screen rule (`Genome.placing()` says so, and `_commit_slot`
and the tray drop both ask it): `_settle` would add nothing and spend the
sample.

### 3.5 The tray

A waiting toxin is **`toxin`** on its chip, in the strain's hue, with its copies
as rings: it is neither form until it lands. The base pair riding a tray drag
says `toxin` too. Two meals of one variety are one chip, unchanged.

### 3.6 The gene's line and its numbers

- **The name is `Genome.name_of(gene)`**, `toxicyst`, for both forms, in the
  strain's hue; the sentence is the form's, and venom's says where it works
  (§1). It follows the slot being read, or for a copy landing elsewhere the
  target's.
- **Phase 3 adds the strain to the name label**, `toxicyst · paralysing`, and
  shortens the front's venom lines (`your bite leaves a venom that eats on` /
  `… that stops what it bit` / `… that puts it to sleep`; French `… un venin
  qui ronge` / `qui paralyse` / `qui endort`): widest row 525 English, 500
  French. The side and stern lines keep their words.
- **Numbers** (`U12`, `U13`, `I06`): the rows of §1, side and stern by the slot.

### 3.7 The quick placement

The bloom (`dna-body.md` §8) offers every free outside slot as today, each as
the tile of the form it would make, and a free slot whose form you carry does
not bloom. **The inside is offered too, while a toxin waits and the inside is
empty.** The body opens if anything is offered, the inside alone included.

| | outside | inside |
|---|---|---|
| **its bud** | the form's tile at `OFFER_REACH`, along the slot's bearing | the poison it would make, drawn where poison is: the granule field inside the body, at `OFFER_ALPHA` 0.34 |
| **aimed** | the finger outside the body, nearest bearing (as today) | the finger **back inside the body after leaving it** |
| **lit** | the bud at 0.95, its line from the skin | the granules at 0.95; **a halo** at `max(1.45 r, 62 px)`, 2.5 px, the hue at 0.55, which clears a thumb; every outside bud x 0.45; the vesicle's thread to the nucleus (`W14b`) |
| **let go** | placed in the lit slot | placed inside |
| **keys** | hold `E`; `A`/`D` walk the ring | `S` or `↓` aims inside, `W` or `↑` back out to the slot nearest the nose (`W14k`). With no free outside slot, `E` aims inside at once |

```gdscript
var _offer_left := false   # set when the finger first leaves the hit circle
# in _offer_aim_at(at): inside the hit circle ->
#     INSIDE if _offer_left and _offer_inside() else -1
```

- **Letting go without leaving the body still places nothing.** That is what
  makes an accidental hold safe under `anywhere`, where resting a finger on
  your body opens it.
- **What it costs**: today a finger that slid out and came back in cancelled.
  While a toxin is offered inside, that same path places it inside, and the
  halo says so before the finger lifts. The inside slot is empty whenever it is
  offered, so nothing is written over, and the pause screen moves it back out.
  Every other gene's gesture is exactly today's.
- **Why not a bud outside.** The one bearing no slot uses is the port flank,
  and a bud there would teach that the inside is your left side. *Out to grow
  it on that side, back in to keep it inside* is the rule itself.

### 3.8 The choosing screen

- **An eighth locus, the inside, last on each strand** (`CHOOSE_LOCI` 8): the
  column grows by one pitch, 48 px, and the shared rows move down with it.
  Its mark, where every other locus has its slot's dart, is **a ring with a
  seed in it** (dart radius, 1.4 px at 0.80, seed 0.38 of it at 0.95): a body
  with something inside, pointing nowhere (`U14`).
- Each locus says its form (`venom`, `poison`) and its rungs take the strain's
  hue; the daughters' bodies show fangs, barbs and granules.
- **A shift moves a venom between front and side** (it never crosses inside).
  The caret marks both loci, as for any shift, and each daughter's line says
  where hers works: the front's sentence on one, `EXPLAINS_SIDE` on the other.

---
## 4. Loads on every body

**One routine, every body, both views, the replay.** `Cilia.draw_cell` gains a
`dose` dictionary (`NO_DOSE` when empty, as `eye` does): `"felt"` is
`Vector3(harm, paralysis, sleep)` in **felt stacks** (`Doses.felt`, already
diluted by the body's own size, because a drawing's radius is canvas px), and
the player's own body adds the keys of §5. Each kind's intensity is
`sqrt(clamp(felt / FULL, 0, 1))`: one stack already shows at half.

| | `FULL` (felt stacks) | the stain's outline | its motion | its hue | and on the body |
|---|---|---|---|---|---|
| **harm** | 4 | a lump: `1 + 0.20 sin(2a + φ + 0.9c) + 0.13 sin(5a − 1.7φ − 1.7c) + 0.07 sin(9a + 2.3φ + 2.9c)` | **roils**, never in step | lime | **pits** (§4.1) |
| **paralysis** (3) | 4 (`PARALYSIS_FULL`) | a seven-facet shard, vertex radii `1 + 0.30 sin(2.7k + φ)` | **still** | ice | every cilium droops (§4.2) |
| **sleep** (4) | 2 (`SLEEP_AT`) | a soft haze: a smooth oval, **two layers and no core** | swells slowly, `1 + 0.10 sin(0.55c + φ)` | pale moon | senses go dark (§4.3) |

`φ` is the body's `phase`, `c` its clock, `a` the angle round the stain.

**The stain**: three nested polygons of 36 points, scales 1.28 / 1.0 / 0.58 of
`r x 0.58 x lerp(0.62, 1, h)`, alphas 0.35 / 1 / 1 of `0.40 x h x marks`;
seated `0.10 r` aft of the middle and drifting `0.16 r` round it at 0.13 rad/s;
along the heading 1.1, across 0.9. Drawn after the nucleus and before the
fringe, so organs stay on top. **Sleep draws the outer two only, at 0.45 and
0.55**: with a core, the pale hue stacked into a lit egg that read as a glowing
nucleus (`z_W17_egg_2400.png`); as a haze the nucleus shows through it and the
body reads clouded (`W17`).

- **A pool and not a disc.** Drawn first as three stacked haze rings, the
  stain read as three glowing organelles (`z_D07_blobs.png`): the pigment
  organelle's own construction, saying the wrong thing. A lumpy pool reads as
  something spilled inside the cell (`z_D07_spill.png`).
- **No rhythm.** A first version flared the stain in pangs about every second.
  A pulse at that rate is what hunger's racing beat looks like; harm *churns*
  instead.

### 4.1 Harm's pits

Up to three pits, `ceil(3h)` of them live. Pit `k` sits at
`2.3φ + 2.1k + c(0.21 + 0.07k)` round the ovoid and opens as
`clamp(sin(c(1.3 + 0.23k) + 1.7k + φ), 0, 1) x clamp(1.4h, 0.35, 1)`:

- a gap in the rim of `±13° x open`;
- its **lips**, 12° either side, in the strain's hue at
  `0.95 x clamp(0.4 + open, 0, 1) x marks`, `BODY_RIM_WIDTH x 1.3`;
- a **curl** of eaten membrane from the gap's middle inward, `0.16 r x open`, in
  the hue;
- the rim drawn in **runs** of a 120-step ovoid while pitted (40 steps cannot
  hold a 13° gap, and per-segment strokes beaded the rim).

The wound's tears stay exactly as they are: still, untinted, flapped. A body
being eaten now and a body that was bitten once are two different pictures
(`W03`).

### 4.2 Paralysis (phase 3)

`droop = 1 − still`: every cilium (mat, oars, tail, bristles, fangs, barbs) turns
aft by `72° x droop` and shortens by `0.45 x droop`; the tail's lash falls by
`0.85 x droop`; **the fringe's clock runs at `still`**, so a stopped body's
cilia stop where they were (the views keep one fringe clock per dosed body,
dropped when its load clears). The shard stain does not move. The water still
moves the body. `W17`, top right.

### 4.3 Sleep (phase 4)

Sense organs (every earned gene's pigment and bristles) at `1 − 0.72 x sleep`;
the oral mat folded flat (`0.75 x sleep` of the droop, on the mouth only); the
breath becomes a slow swell of the whole body; the tail beats on (it swims on
blind, as the mechanics have it). `W17`, bottom left.

- **The swell is the whole body, never lobes.** Deepened three-lobed, the
  first breath crumpled the outline into hunger's creases (`z_P34_controls`
  first pass).

### 4.4 Kept apart

| on a body | colour | outline | motion | rim |
|---|---|---|---|---|
| harm | strain hue | roiling lump | churns | pits with lit lips, opening and closing |
| paralysis | strain hue | shard | none; the fringe drooped and stopped | whole |
| sleep | strain hue | soft haze, nucleus showing through | slow swell; tail still beats | whole; sense organs dark |
| a wound | none | none | none | still gaps, flaps |
| hunger (yours only) | none | none | none | nine creases inward |
| a waiting gene (yours only) | gene hue | ring with an off-centre core and a thread | slow orbit | none |

In greyscale the three stains are a lump, a shard and a haze, and the wound is
tears alone (`W17` grey, `shots/sheet_w17h.png`).

---

## 5. Your own load, in point of view

**This is the riskiest part, by the mechanics designer's account, and where the
care went.** The constraint is the brief's: harm must read as *a hurt that goes
on*, not *a bite at a bearing* and not *hunger*.

### 5.1 Harm

| moment | what you see | where | phase |
|---|---|---|---|
| **it arrives by a bite** (venom into you, or poison from what you bit) | today's hit (flash, bruise at the bearing), **its bruise in the strain's hue** instead of teal, for its 0.6 s | the edge, at the bite's bearing | 1 |
| **it arrives by a meal** (you swallowed a poisonous body) | the ingest flood **in the strain's hue** instead of the prey's | the interior, the one licensed flood | 1 |
| **it gets in** | the stain grows from 0.3 of its size at the skin on the arrival's bearing to its seat, over `SEEP` 0.8 s | the figure | 1 |
| **it goes on** | the stain churns and the pits open and close, as on every body (§4) — **drawn at `FADE_DOSE` 0.68**, the figure's other licence beside the waiting gene's | the figure, the middle of the screen | 1 |
| **it wears off** | the stain shrinks with `h`, the pits stop, the wound's tears stay | the figure | 1 |
| **your venom lands** | your fangs **flare**: x 1.35 long, beads x 1.5 with a three-ring haze, on the eye flare's envelope (`EYE_FLARE_RISE` 0.15, `EYE_FLARE_FALL` 1.05) | your body, both views | 1 |
| **your side venom stings** (a mouth bit the side it guards) | its barbs **flare** on the same envelope: x 1.35 long, beads x 1.5 with the haze (`W22`, `W23`) | your body, at that arc, both views | 1 |
| **your poison is taken** (a biter, or a swallower, takes it) | your granules **flare** on the same envelope: each x 1.5, alpha x 1.6, with the same three-ring haze (`W18`, `W19`) | your body, both views | 1 |

- **The arrival is at a bearing because a bite is.** The ongoing harm has no
  bearing because it is inside you. The two halves of the brief land in two
  places: the lime bruise says *that one was venomous*, from where it was; the
  stain says *and it is in you now*.
- **The flood is the right place for a poisonous meal**: it is already the one
  place point of view names what you ate (`signal_bus.gd`'s `ingest`). You ate
  poison.
- **Your fangs firing is a fact about your body**, so it is inside the figure's
  licence; it is how venom stops feeling like nothing happened in a view that
  cannot see the prey. The barbs and the granules flaring are the same answer
  for side venom and poison, which work only when you are being bitten and
  otherwise never say so.

**Rejected, and rendered: pits in the screen's contour.** A shader version
put the figure's pits on the membrane itself (`X01`). At a beat peak they read
as two lime sparks on the line at two bearings: a sensation *from there*, which
is exactly *a bite at a bearing*, and the contour is where hunger already
speaks. The edge carries the arrival; the body carries the rest.

### 5.2 Measured

`controls.md` §3.2's glance (σ 6 Gaussian peak of Rec.709 on the 8-bit frame)
in its figure box (`W/2±200`, y 180..500), three renders diffed to 0 px first.
`POV` = `--genome=cytostome:1,cirrus:1,flagellum:1,stigma:1 --radius=30
--seed=12345 --mode=0 --wound=0.2`; one stack at r30 is 0.75 felt. The two
shapes agree to 0.1, so one column:

| frame | figure | the contour (top band) |
|---|---|---|
| no load, beat trough (`W05`) | 64.1 (the eyespot) | 12.1 |
| a gene waiting, no load (`S01`) | 64.2 | 12.1 |
| harm, 0.6 felt (`W07`) | 68.6 | 12.1 |
| **harm, one stack** | **73.1** | 12.1 |
| **harm, three stacks, trough** (`W04`) | **105.8** | 12.1 |
| harm, three stacks, beat peak (`W06`) | 113.4 | 54.1 |
| harm, a full load (4 felt) | 128.6 | 12.1 |

The signals, same harness, 1280x720: a hunter's lobe at bearing 220 reads
**49.5** at 250 units, **57.1** at 150 and **145.4** at 110; `diegetic-hud.md` §4
has the taste band at 168.8 and a beam return at 160.5. By ink at the beat
peak, the contour carries **3.17 M** against the whole figure's 0.34 M (0.15 M
without the dose).

- **One stack tops the figure's brightest organ** (73 against the eyespot's
  64), so the first dose is seen. That is what sets `FADE_DOSE`: at 0.45 and
  0.55 one stack reads 65.0 and 65.2, a dead heat with the eyespot's 64.1, and
  is lost.
- **Three stacks are the brightest point of a calm screen** (106, twice a beat
  peak's 54 by glance), while the beat still carries ten times its light. It
  is meant: a load that can kill you is the loudest thing about your body.
- **It loses to every signal that asks you to act**: a hunter closing in (145),
  the taste band, a beam return. It beats a far hunter's lobe (57), which the
  quiet figure's own eyespot (62 in that frame) already does today.
- The lever, three stacks / full: `FADE_DOSE` 0.34 gives 69 / 83, 0.45 gives
  81 / 99, 0.55 gives 92 / 112, 0.68 gives 106 / 129.

### 5.3 Paralysis (phase 3)

- **The figure** droops and stops (§4.2) with the shard stain.
- **A body that will not answer**: whenever the hand asks for a steer, a push
  or a dash that `still` cuts, the shard stain flares by
  `0.9 x (1 − still)` for 0.4 s. The cause shows up exactly when you try.
- **The drawn controls go numb** (`P02`, `P03`): a mark's ink is
  `lerp(NUMB_FLOOR 0.12, ink, still)`, and a held control does not light while
  `still < 0.5`. The stick's knob still moves under the thumb: the hand is read
  and the body does not answer, which is the truth.

### 5.4 Sleep (phase 4)

- **The skin goes numb**: a `veil` uniform darkens the band to 0.35 of the base
  and nothing glows in it; the contour line still beats (`P04` against `P05`).
  Dread darkens the whole field and drains the beat; sleep keeps a bright beat
  round a dark edge.
- **The figure**: the moon haze, dark sense organs, the slow swell.
- **The drawn controls** sit at 0.08 and never light (row 7: the hand is
  ignored).
- **Waking**: the bite's hit clears the veil in 0.25 s with its flash. The first
  time it happens teaches it; no word says it in advance (the playfield's text
  budget stands).

### 5.5 Kept apart from hunger and dread

| | harm | hunger (`hunger.md`) | dread |
|---|---|---|---|
| the beat | untouched | races | stumbles, dims |
| the contour | untouched (only the arrival's bruise) | falls in at empty | dents at the wake's bearing |
| the base | untouched | untouched | darker, colder |
| the figure | lime stain, lit pits | nine creases | untouched |
| colour | lime | teal | none |
| rhythm | none (it churns) | a racing beat | an irregular beat |

---

## 6. The death and the replay

- **A death by poison is quiet**: `_die(false, …)` for a dose death, so no hit
  and no bearing (nothing hit you). The close is the starving one
  (`FAINT_COLLAPSE`), from wherever hunger's fall left the contour, **lit in the
  strain's hue** through `pulse_color` for the collapse (`W13`). Three deaths,
  three pictures: a white slam at a bearing (eaten), a teal sink (starved), a
  lime close (poisoned).
- **The replay shows whose dose it was**:
  - the felt pane: the tinted bruise at the dosing bite's bearing and the stain
    on the figure, from the recorded loads (`W16`);
  - the truth pane: your stained body, the speckled or barbed cell beside it,
    the killer's rings round `died_to` as today, and **the dosing contact's
    bruise ray in the strain's hue** (the hit sensation carries `tint`, the
    recorder keeps it with the event).
- **A friend in a pond who dies of a dose** is drawn as `Gone.STARVED` (nothing
  ate them: they stop where they were), not as today's default `EATEN`, and the
  line is today's `died`. Not rendered.

---

## 7. The owner's answers, and the one switch left

All fifteen rows are answered as recommended (`dna-slots.md` §22): the name
`toxicyst`; corrosive, paralysing and sleeping; row 3 made precise into outside
and inside, which this revision draws; once in each form; row 9 overtaken by
the owner's `outside` / `inside`; `toxin`; a mouth at birth; the skin's
*engulf* in phase 5; and one inside slot.

**The one switch.** `VENOM_SIDES := false` (`dna-slots.md` §2.3) makes a side
venom inert if the owner reads row 3 as *venom through the mouth alone*. Then
a side or stern venom draws **no barbs**, its slot still says `venom`, and its
line is `on this side it does nothing · venom works at your front` (to be
measured if it is ever thrown).

**Hooks for phase 5** (`feeding.md` §5.5), not designed here: the figure's nose
without a mouth, *engulf* (*englober*) where `eat` and its line were, and the
water's engulf at a bearing. The inside slot, the bloom and the refusals do not
change for a mouthless cell; a front venom on one draws no fangs (§2.2).

---

## 8. Phases

| phase | the screen and the look |
|---|---|
| **1** (with the mechanics) | **The minimum honest screen.** The inside chip in its seat, with its empty, armed, occupied and refused states, its keys (`SLOT_NEIGHBOUR`, Tab) and its drags. The armed preview and a drag show the form a slot would make. `ACT_RAISE` when a tap adds a copy, here or elsewhere; a tray drop onto such a slot arms it. `ACT_RAISE_FULL`, `ACT_REFUSE` and `ACT_FACES_OUT`, armed and in the air. `ACT_ARM_FORMS`. The gene's line with `name_of` and the front's, side's or stern's sentence; `EXPLAIN_INSIDE`, `HINT_INSIDE`; the numbers rows. The quick placement skips a carried form, and offers outside slots only. **The look**: lime; fangs at the front, barbs on a side, granules inside with no arc; harm's stain and pits on every body, both views, the replay; `FADE_DOSE`; the lime bruise and meal flood; the seep; the three flares; the quiet lime close |
| **2** | the ghosts; the add-a-copy target lit with its new copies; the inside lit as a whole; the form ghost under a drag; the inside in the quick placement (§3.7); the choosing screen's inside locus |
| **3** | ice; the bead shapes; the shard, the droop and the stopped fringe; the flare on a cut input; numb controls; the strain in the name label and the short venom lines |
| **4** | moon; the haze, dark senses and swell; the veil and waking; dead controls |

**If phase 1 has to shrink**, the seep and the three flares can wait for phase
2. Nothing else can: without the inside chip a toxin cannot be put inside at
all, without the words a toxin lands somewhere the player did not mean, and
without the stain a dose is a wound that will not mend for no visible reason.

---

## 9. What the build changes, checks and shoots

### 9.1 Files

| file | change | phase |
|---|---|---|
| `game/vision/cilia.gd` | `HUES`; `dose` on `draw_cell`; `_draw_fangs` for a front venom, `_draw_guard` for a side or stern one, the granule field for every inside form after the outside layout, nothing inside at an arc; `arc_for_slot` never given an inside index; `default_order` without inside forms; the stain and the pitted rim; droop and sleep (3, 4); form tiles; `_draw_offer` with the inside bud and halo, and the vesicle's thread to the nucleus when aimed inside; `draw_slot_dart`'s ring-and-seed for the inside | 1, 2, 3, 4 |
| `game/perception/soma.gd` | `FADE_DOSE := 0.68`; the player's `dose` (loads, entry, the three flares) | 1 |
| `game/vision/vision.gd` | `dose` for every body and the player; a fringe clock per paralysed body; the dosing contact's ray in its tint | 1, 3 |
| `game/perception/signal_bus.gd`, `membrane.gdshader` | `STRAIN_COLORS`; `hit(…, tint)`, `collapse(…, tint)`; `veil()` and `uniform float veil` | 1, 4 |
| `game/normal/normal_mode.gd` | the words of §1; `_draw_figure_body` passes the player's `dose` beside `_slack`; the eighth seat, `SLOT_RING`, `SLOT_NEIGHBOUR`; the inside chip's window, states and lit mark; `_slot_live`, `_committable`, `_slot_can_drop` and the act line asking `Genome.placing()`/`can_move()` for the inside; the refused `Shift`+arrow line; the quick placement's `_offer_inside`, `_offer_left` and the `S`/`W` keys; `CHOOSE_LOCI` 8 and `_choose_at` for the inside; the bus tints | 1, 2 |
| `game/normal/gene_stats.gd` | §1's numbers rows, side and stern by the slot | 1 |
| `game/normal/controls.gd` | numb and dead marks from the cell's loads | 3, 4 |
| `game/replay/recorder.gd`, `panes.gd` | the hit's tint kept with the event; the panes pass `dose` | 1 |
| `game/i18n/biogenic.pot`, `fr.po` | §1, each with its `TRANSLATORS:` note and `ROOM:` | each |
| `tools/drive.gd` | beside the mechanics' `--dose=`: `--dose-hit=<t>:<bearing>`, `--poison-meal=<t>`, `--venom-lands=<t>`, `--sting=<t>` (a side venom fires), `--poison-taken=<t>`, `--dose-death`, `--shift=<from>:<to>` | 1, 2 |

### 9.2 Checks

- The lint, with every `ROOM` of §1, French included.
- **The inside is reachable every way**: by a tap, a drag from a slot, a tray
  drop, the keyboard (`SLOT_NEIGHBOUR` from 0, 1 and 2; Tab after 4), and the
  quick placement (a slide out and back, and `E` then `S`). Every arrow in the
  eight rows of `SLOT_NEIGHBOUR` has its way back (checked).
- **Nothing that faces out lands inside**, by any of those paths, and each one
  says `ACT_FACES_OUT` while the finger or the key is down.
- **The bloom's old cancel holds** for every gene but a toxin offered inside: a
  slide out and back in places nothing.
- **Glance** (`controls.md` §3.2's method, three renders at 0 px first), in the
  `POV` pose of §5.2: one stack tops the figure with no load; a full load stays
  under a hunter's lobe at 110 units; the contour's ink at a beat peak stays
  above the figure's. Report the numbers.
- `W17` in greyscale: lump, shard, haze and tears are four pictures.

### 9.3 Frames the build shoots

The mock's frames, under the mock's names, so each build frame is set beside
its mock in `ux/shots/final/` (`ux/frames_r3.py` and `ux/frames.py` hold every
mock command). Both shapes; English and French where a word appears; taps at
2.5 s where a slot is armed, because the arm's timeout runs on the wall clock.

- `T` = the mechanics' (`toxicyst:2:3,veneneux:1:7`); `S` = the same with the
  venom at slot 5; `B3` = the born three at r39.5; `POV` = §5.2's.
- Chip centres at 1280x720: slot 0 (788, 204), 1 (938, 342), 2 (788, 510),
  3 (938, 204), 4 (638, 204), 5 (938, 510), 6 (638, 510), **inside (788, 348)**,
  the tray's first chip (810, 140). Add 160 to x at 2400x1080.

| frames | pose | phase |
|---|---|---|
| `U01`, `U02`, `U12`, `U13` | `T`, slot 3 or the inside read; `--numbers=1` for 12 and 13 | 1 |
| `U03`, `U04`, `U05` | `B3 --sample=veneneux`; nothing, slot 3, the inside armed | 1, 2 |
| `U06`, `U06b`, `U07` | `T --sample=veneneux`; slot 4 armed (copy to slot 3), the inside armed (copy in place); `U07` with `toxicyst:3:3` | 1, 2 |
| `U08`, `U09`, `U09b`, `U10` | the poison dragged out to slot 4 (refused); the venom dragged in (it becomes poison); the poison dragged out with no venom carried (it becomes venom); the venom onto the poison (they trade copies) | 1 |
| `U11` | `B3 --sample=veneneux,ampulla`, the toxin dragged from the tray onto the inside | 1 |
| `U14` | `--dna=…,toxicyst:2:3,…,veneneux:2:7 --shift=3:5`, the shifted venom read | 2 |
| `U15`, `S02` | `B3 --sample=veneneux --mode=1`; the worst figure (every gene at three, poison read) | 2, 1 |
| `I01` | `B3`, the empty inside read | 1 |
| `I02`, `I03`, `I04` | the tail dragged onto the inside; `ampulla` waiting, the inside armed; `ampulla` dragged from the tray onto the inside | 1 |
| `I05`, `I05b`, `I05c`, `I06` | `S`, slot 5 read; venom at three copies at the flank (slot 1) and at the stern (slot 2); `S` with `--numbers=1` | 1 |
| `I07`, `I08` | `T`: `Tab`, `Tab` (to the nose), `↓`, `Enter`; the tail tapped, then `Shift`+`↑` | 1 |
| `I09` | `T --dose=harm:4`, the pause figure dosed | 1 |
| `W01`, `W20` | full vision: a venom cell and a poison cell; your own body with `S`'s side venom | 1 |
| `W14`, `W14b`, `W14k`, `W15` | the body held open with a toxin waiting; slid out and back in; `E` then `S`; with venom carried, the inside alone | 2 |
| `W11`, `W21`, `W22`, `W23` | front fangs firing; `S` in point of view; its barbs firing in both views | 1 |
| `W16`, `W18`, `W19` | the replay beside a poison cell; your poison taken, both views | 1 |
| `W02` to `W10`, `W12`, `W13`, `W17`, `P01` to `P05`, `S01` | unchanged from revision 2 (§10) | 1, 3, 4 |

---

## 10. Rendered and judged

From the mock (its frames were made in a scratch copy and are not kept in the repo): 180 frames, named
`<frame>_<en|fr>_<1280x720|2400x1080>.png`, every one looked at. Revision 3
re-shot every frame the inside touches and added the `I` frames; revision 2's
frames that nothing here changed stay beside them (revision 2's whole set is
kept in `shots/final_r2/`).
Contact sheets: `ux/shots/sheet_r3_pause.png`, `sheet_r3_inside.png`,
`sheet_r3_water.png`. Two new frames were rendered three times each (`I02`, a
drag refused over the inside; `W14b`, the bloom aimed inside): **0 differing
pixels**.

| frame | judged |
|---|---|
| `U01`, `U02` | **pass.** Venom at the front with its fangs; poison read through the inside chip, the whole inside lit. Both lines inside their room in French |
| `U03` | **pass.** The tray says `toxin`; every empty live outside slot ghosts `venom`, the inside ghosts `poison`; `tap a slot · venom outside, poison inside`. The rule is on the figure before it is in the line |
| `U04`, `U05` | **pass.** Armed outside: `venom`, its arc lit. Armed inside: `poison`, the inside lit as a ring just inside the rim |
| `U06`, `U06b` | **pass**, `U06b` after a fix: the first render lost the arm, because the screen's check that the genome had not changed compared the seven-long layout with the eight chips. Now the copy lands in place and says so |
| `U07` | **pass, the weakest pause frame**, as in revision 2: the full target's dim weave is subtle and the line carries it |
| `U08` | **pass**, after a fix: a refused drop lit the target's arc in the travelling hue, which said *yes* while the line said *no*. A refused target now lights nothing |
| `U09`, `U09b`, `U10` | **pass.** Into the inside: `it becomes poison`. Out of it: `it becomes venom`, the front arc lit. Venom onto poison: `they trade copies` |
| `U11` | **pass.** The pair riding the finger says `toxin`; the inside ghosts `poison` and lights |
| `U12`, `U13`, `I06` | **pass.** The French numbers rows fit (638 of 650 at worst) with `qui vous mord` |
| `U14` | **pass.** The eighth locus, last, with its ring-and-seed; the shifted daughter's venom on her side, with barbs, and her line says so. The longer column keeps clear of the shared rows |
| `U15` | **pass.** Over full vision the real cell's ghost lands in the empty port-flank cell, as `dna-body.md` §7 meant, and the inside chip is nowhere near it: the reason the inside is not there |
| `S02` | **pass, the most crowded frame.** Every gene at three: the inside chip reads on its window over twenty granules, with the armour's pigment at the window's lower-left edge, beside the word and not on it; the fangs stand 19 px from `venom` |
| `I01` | **pass.** The empty inside read: `nothing inside yet · a toxin here becomes poison`, the inside lit pale |
| `I02`, `I03`, `I04` | **pass.** A gene that faces out, dragged, armed or carried from the tray onto the inside: no lens, no light, no preview, and `swim works only outside` / `ping works only outside` in both languages. The refusal is the line, as every refusal on this screen is |
| `I05`, `I05b`, `I05c` | **pass.** Venom on a side, on the flank and at the stern, as fanned beaded barbs on that arc, the arc lit; the side's and the stern's lines. At the stern the barbs stand among the tail's cilia and still read: lime beads, not purple |
| `I07`, `I08` | **pass**, `I07` re-posed: the first mixed a tap and keys, and the mouse left over the nose kept the lines on the nose (hover wins, as on desktop it should). By keys alone the inside is focused, selected and read; `Shift`+`↑` from the tail is refused in words for 2 s |
| `I09` | **pass.** A dosed body on the pause figure: the stain shows round the window, the pits stay in the rim, the word stays on the window |
| `W01`, `W20` | **pass.** In full vision a poison cell is speckled with no organ at any arc; a venom cell is fanged; your own side venom stands out of your rear flank |
| `W11`, `W21`, `W22`, `W23` | **pass.** Front fangs firing; side barbs in point of view, still and firing. Shot still, not in motion |
| `W14`, `W14b`, `W14k`, `W15` | **pass.** The inside offered as dim granules; aimed by coming back in, or by `E` then `S`: the halo, the lit granules, the outside buds dimmed, the thread to the nucleus. With venom carried, the body opens for the inside alone |
| `W16`, `W18`, `W19` | **pass.** The poison cell in the replay and your own poison taken, both with no arc mark |
| revision 2's `W02` to `W10`, `W12`, `W13`, `W17`, `P01` to `P05`, `S01`, `X01` | unchanged and still **pass**; `X01` is the rejected contour pits, kept for the record |

---

### 10.1 As built: phase 1, 2026-10-03

The build's frames were shot at both shapes in English and French and judged
against the mock's: 170 of them, plus four of D09p. Three renders of a frame
differ by 0 pixels. Where they differ:

- **Phase 2's items are not built yet:** the empty slots' ghosts, the form's
  ghost under a drag, the inside in the bloom, and the choosing screen's inside
  locus.
- **`9.66 s`, not the mock's `9.7 s`.** That is the game's own formatter.
- **D09 became D09p.** §9.3's `--hunt=900` left the hunter off the screen, so
  the dosed and undosed frames were identical. It is posed with `--stalk`
  instead.
- **W16's replay panes showed no dose at first.** `panes.gd`'s live mirror now
  draws it.
- **W10's stain is smaller than the mock's**, because `--poison-meal` is a real
  meal: the cell grows, and the dose is diluted in it.
- **The stern's French numbers row** says `de dos`. `par-derrière` came to 658
  px against 650; the gene's line keeps `par-derrière`.

## 11. Left open

What to watch when it is played, with the lever for each. None of these is a
reason to hold the build.

1. **The riskiest: is your own dose noticed in a fight?** The stain is on the
   figure, and in a fight the eyes are on the edge. §5.2 says one stack tops
   the figure and three are the brightest point of a calm screen; it cannot say
   that a player with a hunter on one side looks at the middle. The arrival (the
   lime bruise, the lime flood) is at the edge, the half most likely to be seen.
   Watch for *I didn't know I was poisoned*. Levers, in order: `FADE_DOSE` up;
   hunger's haptic step on a dose's arrival; last, `X01`'s contour pits.
2. **Does the inside read as *inside your body*, and is it hit on a phone?**
   The figure shows it: a ring of chips outside, one chip on the body, every
   empty one ghosting what it would make, and the `Act` line naming the form
   and the place before the second tap. But the inside chip sits on the drawing
   it describes, so it can be taken for part of the body rather than a slot,
   and the thumb covers it while it is tapped. Watch for a toxin placed in the
   wrong place twice running. Levers: `GHOST_INK` up; `INSIDE_BACK_ALPHA` up;
   the inside lit whenever a toxin is in hand.
3. **The bloom's lost cancel.** While a toxin is offered inside, a slide out
   and back in places it inside. Watch for a toxin put inside by a player who
   meant to change their mind. The lever: aim the inside only from the inner
   half of the hit circle, and keep the rim as a cancel.
4. **Too loud for ten seconds?** At 0.68, three stacks are twice a beat peak
   for the life of the dose. Lever: `FADE_DOSE` (§5.2's table).
5. **Lime fangs and barbs against the mouth's green** (24° apart) at full
   vision's range. Shape carries it in every frame here; watch a crowded water.
6. **The flares were shot still**: on a moving body, in a fight, unmeasured.
7. **Phases 3 and 4 are starting values**: ice near `pellicle`'s cyan, moon near
   `ocellus`'s violet, the bead shapes unrendered. Both phases re-shoot `W17`
   and `P01` to `P05`.
8. **The sleep veil outdoors** may read as no band at all. Unmeasured.
9. **Not rendered here**: a friend's death by a dose; the replay's tinted
   bruise and the seep in the felt pane.

---

## 12. Owner's calls

**None new.** This screen's two rows (9 and 10) are answered, and nothing in
this revision is a name or changes what the game is. Three wordings are this
screen's to set and are set in §1: `dehors` / `dedans`, `ACT_FACES_OUT`, and
`EXPLAINS_STERN`.
