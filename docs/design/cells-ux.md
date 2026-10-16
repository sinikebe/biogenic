# Your cells, on screen

The screens for `cells.md`: where a cell is picked, the list of your cells, a cell's
detailed view, and what changes on the pages around them. The rules, the files and the build plan are in
`cells.md`. This file says what is drawn and what it says.

**Status: built** (`cells.md` §6.6), and photographed again on the build: every frame
of §7 and more, at both shapes and in both languages (§9). It was first mocked on the
real scenes and photographed at 1280x720 and 2400x1080, in English and French (§7).
The mock was a scratch scene, `tools/cells_mock.tscn`, and it is not in the
repository. It added these screens to the real `mode_select.tscn`, `earshot.tscn` and
corner, in the corner's own styles, and its figure was cropped from a real render of
the pause screen.

---

## 0. Decided, in one place

1. **Each view's button names the cell it plays**, on a second line under the view:
   `slipper · fourth generation`, or `a new cell`. A chevron beside it opens that
   view's cells. The button and its cell can never disagree, because each view
   only ever lists its own cells (§1).
2. **"Your cells" is "your worlds" for one view**: three rows, one tap to choose, a
   plus on an empty one. Each row has a `look` button, where a world's row has
   `rename` (§2).
3. **The detailed view is the pause screen's composition with the cell's facts in
   the left column**: name, view, generation, age, world and what happens on play. The
   figure is the pause screen's own, read-only: its slots can be read, never moved.
   Rename and delete live here (§3).
4. **It opens from a cell's row only, never from the pause screen.** The pause screen
   already *is* the live view of that cell, and the editable one (§3.6).
5. **The TOGETHER page's two view buttons carry the cell's line too**, with no
   chevrons there (§4).
6. **"Your worlds" says only the water now.** Each row shows its age, and the footnote
   and the delete line change (§5).
7. **Content only.** There is no new scene file for the menus; the sheets are layers
   of `corner.tscn`, as the worlds' are.

---

## 1. The view chooser: a cell on each view

### 1.1 The tree

Each view's block in `mode_select.tscn` changes as follows. Point of view's is
identical.

```
FullBlock      VBoxContainer, separation 10, SHRINK_CENTER                        (unchanged)
├─ Row         HBoxContainer, separation 24, SHRINK_CENTER, mouse IGNORE           new
│  ├─ Balance  Control 64 x 0, mouse IGNORE: as wide as Cells, so Full stays on the
│  │           screen's centre line, under the heading and over its note          new
│  ├─ Full     Button 460 x 80 (was 64), text "", clip_contents, FOCUS_ALL
│  │  └─ Lines  VBoxContainer, full rect, offsets 20 / -20, centred, separation 0,
│  │     │      mouse IGNORE                                                       new
│  │     ├─ View  Label 20 px, centred: "full vision", in the Button's font colour
│  │     │        for its state (normal, hover, focus, pressed)
│  │     └─ Cell  Label 15 px Color(0.482, 0.686, 0.643, 1), centred,
│  │              auto-translate off, the line of §1.2
│  └─ Cells    Button 64 x 80, no text, FOCUS_ALL, tooltip "your cells", the
│              chevron drawn                                                      new
└─ FullNote    (unchanged)
```

- **`OPTION_SIZE` becomes 460 x 80.** Two lines of 20 and 15 px need 48, and the
  margins take the rest.
- **The View label follows the button's states** (the colours `font_color`,
  `font_hover_color`, `font_focus_color` and `font_pressed_color` of the launcher
  theme) through `mouse_entered` and `mouse_exited`, `focus_entered` and
  `focus_exited`, and `button_down` and `button_up`. That way it behaves as the
  button's own text did.
- **The chevron** is the world chip's: (−5.5, −2.5) → (0, 3) → (5.5, −2.5) round the
  button's centre, 2 px and antialiased, in `Color(0.855, 0.953, 0.933, 0.8)`, and
  alpha 0.95 while hovered or focused (the gear's rule).

**Where it lands**, in canvas px. Every y is the same at both shapes.

| | 1280x720 | 2400x1080 (canvas 1600x720) |
|---|---|---|
| heading | y 127..151 | same |
| full vision / its chevron | x 410..870 / 894..958, y 194..274 | x 570..1030 / 1054..1118 |
| its note | y 284..306 | same |
| point of view / its chevron | x 410..870 / 894..958, y 350..430 | x 570..1030 / 1054..1118 |
| its note | y 440..462 | same |
| within earshot, by invite | y 506..562, notes 572..594 | same, x + 160 |
| hint | y 672..696 | same |

**What reflows on a phone: nothing vertically.** The column is 32 px taller than
today's, and still centred. The extra width only widens the margins. Against today's
chooser, full vision's button grows 16 px upward and point of view's 16 px downward,
and the company row drops 16 px. TOGETHER's buttons grow 8 px (§4). Nothing else
moves.

### 1.2 What the cell line says

| the view's selected slot holds | the line |
|---|---|
| a cell whose place is in the selected world | `slipper · fourth generation` |
| a cell whose place is in another world | `slipper · fourth generation · from “rain barrel”` |
| a cell kept in a friend's water | `slipper · fourth generation · from a friend's water` |
| a cell whose world is gone | `slipper · fourth generation`. It comes in at a quiet place, and there is nowhere to name |
| nothing | `a new cell` |
| a record (owner's row 1) | `a new cell · slipper died` |

- **Every line is built whole**, with `Readout.SEP` (` · `), as a world's lines are.
  The world's name sits in the language's own quotes, `“%s”` (the msgid exists), as a
  name inside a sentence does elsewhere (`automation-ux.md` §8).
- **The name gives way.** The line has 420 px. If it is wider, the name alone is
  shortened with `…` until the line fits. The generation and the world are never cut,
  because they are what the line is for. Measured, the widest ordinary line is 394 px
  (French `pantoufle · 4e génération · depuis « tonneau de pluie »`). Only a name of
  very wide letters ever gives way.
- **"from" says where it comes from and what will happen**, in one word. The first
  draft said `in “rain barrel”`, which reads as a promise to go there, and that is not
  what the button does.

### 1.3 Touch, mouse, keyboard

- **Touch.** The view button is 460 x 80 and the chevron 64 x 80: 96 x 120 device
  px on a 2400x1080 phone. They are 24 px apart, as `call` and `answer` are on the
  earshot page. A mis-tap from the chevron starts the game, and that costs one Back:
  the cell is kept the moment the run opens.
- **Mouse.** The tooltip `your cells` is on the chevron, and both boxes have the
  theme's hover.
- **Keyboard.** Right from a view goes to its chevron, and Left comes back. Down and
  Up walk the views, keeping the column: full vision ↔ point of view, chevron ↔
  chevron. Down from point of view goes to `within earshot`, and from its chevron to
  `by invite`. Up from either top control goes to the corner's chip (`link_focus(_full,
  [_full_cells])`). **The remembered view still takes the focus** when the screen
  opens.

---

## 2. Your cells: the sheet

### 2.1 The tree

A new layer of `corner.tscn`, `Cells`, between `Drops` and `Naming`. It is built as a
static node, as the other layers are, so a change of language only ever sets words.

```
Cells        Control, full rect, IGNORE, hidden
└─ Panel     PanelContainer, min width 640, anchors (0.5,0)-(0.5,0), offset_top 112,
   │         grow_horizontal BOTH, the sheet's opaque panel (settings.md §2)
   └─ Box    VBoxContainer, separation 10
      ├─ Caption   Label 16 px Color(0.855, 0.953, 0.933, 0.52)   "your cells · full vision"
      ├─ Rows      VBoxContainer, separation 10, in a ScrollContainer four rows high
      │  └─ Row1..3  HBoxContainer, separation 10
      │     ├─ Pick   Button EXPAND x 68, + 25 a line past the first; the worlds' row exactly
      │     │  └─ Lines  VBoxContainer, offsets 52 / -16, centred, IGNORE
      │     │     ├─ Name   Label 20 px INK, ellipsis, auto-translate off
      │     │     └─ Stats  Label 15 px Color(0.482, 0.686, 0.643, 1), ellipsis, a line each
      │     └─ Look   Button 112 x the row's height, 15 px, the quiet slab    "look"
      └─ Note      Label 15 px Color(0.318, 0.463, 0.435, 1)
                   "a cell is played only in the view it was born in"
```

It spans x 320..960 at 1280x720 and x 480..1120 at 2400x1080. With two cells and an
empty slot it runs from y 112 to 490; with three cells, to 515. **It is centred,
not hung from the corner**, because it opens from mid-screen. **The corner's cluster
stays up under the veil**, as it does under "your worlds".

**A fourth row exists only after a rare migration** (`cells.md` §4). From a fifth row
on, `Rows` scrolls, four rows high, as the language list scrolls from its seventh.

### 2.2 A row

| row | mark at x 26 | box | Name | lines | `look` |
|---|---|---|---|---|---|
| the view's selected cell | filled dot | "current" | its name | line 1, line 2 | yes |
| another cell | empty ring | the launcher's Button | its name | line 1, line 2 | yes |
| an empty slot | plus | the faint empty box | `new cell`, alpha 0.82 | none | an empty 112 px hold, as a selected world's missing delete |
| a record (owner's row 1) | plus: a new cell starts here | "current" if selected, else the faint box | its name, alpha 0.6 | line 1, then `died in “pond water”`, at alpha 0.75 | yes |

- **Line 1: the generation, its line's age, and its hunger**, built whole:
  `fourth generation · 2 hours old · hungry`.
  - **The age** is the line's `lived`, in the world's words for minutes, hours and
    days, translated under the context `cell`. French agrees with the noun: a world is
    `âgé`, a cell `âgée`.
  - **Not shown when the age is unknown**: a cell from before the update.
  - **The hunger** is `hungry` from half a tank (`Metabolism.HUNGRY_FROM`), and
    `starving` once the tank is empty. It is shown because a cell left starving
    resumes starving.
- **Line 2: where it is**:
  - `world · pond water`, the chip's own grammar;
  - `a friend's water`;
  - `a world that is gone`;
  - for a record, `died in “pond water”` or `died in a friend's water`.
- **Measured** at their widest (§6): line 1 is 359 px (French, `47 heures · meurt de
  faim`) and line 2 is 347 px (a twenty-`W` world). The lines have 402 px.

### 2.3 What a tap does

- **A row** selects that slot for this view, writes `cells.cfg` and closes the sheet.
  The view's button then says the new line. Tapping the selected row just closes it.
  **An empty row is selected too**, and nothing is made until the view is pressed. A
  new cell is born in play (`cells.md` §1.7), so unlike a world it needs no naming
  before it exists.
- **`look`** opens the detailed view over the sheet (§3).
- **Back, Esc, the veil:** each closes one layer, the detailed view first. Back asks
  `corner.close_top()` first, as every screen already does (`settings.md` §1.3).
- **Keys:** Up and Down walk the rows, Left and Right walk `Pick` ↔ `look`, and Tab
  goes round. It opens with the focus on the selected row. This is `_trap_drops`, one
  more time.

---

## 3. The detailed view

### 3.1 The tree

**A full-screen layer of the corner, `Cell`, opaque in the base colour.** It is the
pause screen's own backdrop in point of view. A cell is shown as the pause screen
shows yours: settings on the left there, the cell's facts on the left here, and the
same figure on the right. The corner's cluster hides while it is up, as it does under
naming.

```
Cell        Control, full rect, mouse STOP, hidden
├─ Back     ColorRect, full rect, Color(0.023, 0.055, 0.05, 1)
└─ Center   CenterContainer, full rect, IGNORE
   └─ Columns  HBoxContainer, separation 48
      ├─ Side      VBoxContainer, 280 x 535, SHRINK_CENTER, separation 0
      │  ├─ Name      Label 28 px INK, ellipsis, auto-translate off       "slipper"
      │  ├─ (4)
      │  ├─ Kind      Label 15 px Color(0.482, 0.686, 0.643, 1)          "point of view · fourth generation"
      │  ├─ (2)
      │  ├─ Age       Label 15 px, the same ink                          "2 hours old · hungry"
      │  ├─ (28)
      │  ├─ Where     HBoxContainer, separation 10
      │  │  ├─ Caption  Label 17 px Color(0.855, 0.953, 0.933, 0.52)     "world"
      │  │  └─ Value    Label 17 px INK, ellipsis, auto-translate off    "pond water"
      │  ├─ (2)
      │  ├─ Then      Label 15 px, the same ink, autowrap, width 280      "where you left it"
      │  ├─ Fill      Control, EXPAND
      │  ├─ Actions   HBoxContainer, separation 16
      │  │  ├─ Rename   Button 132 x 56, 15 px, the quiet slab           "rename"
      │  │  └─ Delete   Button 132 x 56, 15 px, the quiet slab           "delete"
      │  ├─ (48)
      │  └─ Close     Button 280 x 56, 20 px                             "close"
      └─ Figure    cell_figure.gd: the pause screen's genome group, read-only (§3.3), 560 wide
```

| | 1280x720 | 2400x1080 (canvas 1600x720) |
|---|---|---|
| `Side` | x 196..476, y 92..627 | x 356..636 |
| `Figure` (caption, tray, figure, lines) | x 524..1084, y 86..634 | x 684..1244 |
| its `numbers` switch | x 1100..1196, y 541..589 | x 1260..1356 |
| `Rename` and `Delete` / `Close` | y 467..523 / 571..627, where `resume` and `leave` sit | same |

**What reflows on a phone: nothing.** `Columns` slides to the centre of the wider
canvas, as the pause screen's does. The empty band in `Side` between the facts and
the actions is the pause column's own rhythm, with the actions where `resume` and
`leave` are (§7 judged it).

### 3.2 The facts

| line | says | when |
|---|---|---|
| `Name` | the cell's name | always |
| `Kind` | the view and the generation: `Drops.cell_line`'s words, `point of view · fourth generation` | always |
| `Age` | its line's age and its hunger, as line 1 of a row without the generation | hidden when neither is known |
| `Where` | `world` + the world's name; or `a friend's water`, or `a world that is gone`, with the caption hidden | a living cell |
| `Then` | **what pressing its view will do**: `where you left it` when its place is in the selected world, `comes into “pond water” at a quiet place` otherwise (named for the selected world) | a living cell |

`Then` wraps to two lines at 280 px, as in French: `arrive dans « eau de mare », à un
endroit calme`. It is the one place the player is told about a place given up. The
view's button says only `from “rain barrel”` (§1.2).

**What is not here, and why:**

- **Families.** They are owner's row 21 of `lineage.md`, "not yet". The cell's own
  line is its generation and its age, both shown.
- **Its instincts.** The library is the player's, the same for every cell
  (`cells.md` §1.8). Which instincts sleep in a body is the programs page's to say,
  where they can be changed.
- **What it carries.** The figure already shows it, as the pause screen does: the
  waiting genes in the tray, carried copies as rings, and a dose as the stain and the
  pits of `dna-slots-ux.md` §4. Words for them would be a second way of saying the
  same thing.

### 3.3 The figure, read-only

`cell_figure.gd` draws the cell's file through `figure.gd`, the pause screen's own
drawing, made callable from plain values in phase 1 of `cells.md` §6.2. The menu
never instances a `Genome` or a `CellBody`. It shows:

- **the caption**, `genome · fourth generation`, and with numbers on, the cell's size
  and tank from its kept radius (`GeneStats.cell_items`), as on pause;
- **the tray**: its waiting genes and a fork, drawn and never pressed. Their clocks
  are frozen, as the save froze them;
- **the figure**: the body as kept (slack if it was hungry, its dose stain if dosed),
  the tethers, and the eight chips;
- **reading, and only reading.** Hovering, focusing or tapping a live slot reads it.
  The arc lights on the body, and the `Explain` and `Hint` lines say what that gene
  does and what passes on, as on pause. A slot never arms, nothing drags, and there is
  no `Act` line, because there is nothing to do;
- **the `numbers` switch**, as on pause, which turns on the same remembered
  preference (`gene-stats.md` §2.2).

### 3.4 Rename, delete, close

- **`rename`** opens the corner's own naming sheet (`open_naming_for`). Its title is
  `rename this cell` and its button `rename`, with the name selected, so typing
  replaces it. Default names behave as a world's (`settings.md` §5.2). Keeping the
  name returns to this view, which shows it.
- **`delete`** opens the corner's confirm (`open_confirm_for`): `delete slipper?`,
  over `its body and its genes are gone for good.`. `keep` has the focus, and Back
  means keep. `delete` empties the slot and returns to the sheet. **The selected cell
  can be deleted:** its slot stays selected, and its view then says `a new cell`.
- **`close`**, Back, Esc: back to the sheet. **It opens with the focus on `close`**,
  so a stray Enter only closes it. Tab goes from `close` to `rename`, `delete`, the
  ring of slots from the nose, `numbers`, and back to `close`. On the ring, the
  arrows go where they point, as on pause.

### 3.5 A record (owner's row 1)

The same layer, for a cell that died:

- `Age` keeps its last age;
- `Where` hides, and `Then` says `died in “pond water”`;
- the figure is drawn at alpha 0.55: a memory, not a cell;
- **only `close`** is offered. A record goes by itself when a new cell starts in its
  slot, so it has nothing to rename and nothing to delete.

### 3.6 Why it is not on the pause screen

**The pause screen is already the detailed view of the cell in play**, and the only
one where it can be changed: its genome, its programs and its numbers. A read-only
copy one tap from the editable one would be two views of one cell that can drift
apart. Every fact the detailed view adds is about a cell you are *not* playing:

- where it is;
- what pressing its view will do;
- its age next to the others'.

So the detailed view lives where the cells you are not playing are listed.

---

## 4. The TOGETHER page

**After `answered`, the two view buttons carry the cell's line too**, so a guest or a
host sees which of their cells is about to go in:

```
Buttons   offsets -420 / 598 / 420 / 662 (was 602 / 658)
First, Second   Button 264 x 64 (was 56), text ""; the chooser's Lines (§1.1),
                offsets 14 / -14, in the same two sizes
```

- **The line is the chooser's, without `from …`.** A pond is a friend's water
  whatever the cell's place was, so where it comes from says nothing here. The
  record's line is `a new cell` alone: `une nouvelle cellule · pantoufle est morte`
  measured 301 px, against the 236 the button has.
- **No chevrons here.** The mock put one after each button. The second chevron then
  sat between the two views, 24 px from both, and belonged to neither (§7). To change
  a cell, a player goes Back to the chooser.
- **Geometry:** x 364..628 and 652..916 at 1280x720, and 160 px further right at
  2400x1080. y 598..662, 10 px over the hint (672..696), which does not move.

---

## 5. Your worlds, after

A world keeps only its water now, so the worlds' words follow:

- **A world's row says its age, and only its age**: one line, and every row is 68 px
  again. The cell lines of `settings.md` §4.3 go.
- **The footnote** becomes `each world keeps its own water` (229 px; French 258 px,
  of 592).
- **The delete line** becomes `everything living in it is gone for good. your cells
  are not.` A world's delete no longer touches a cell. A cell whose place was there
  comes in at a quiet place in the next world it plays (`cells.md` §1.4).

---

## 6. Words, and their room

Every new string goes through `tr()` with a `TRANSLATORS:` note, and with a `ROOM:`
line where room is tight. **Every note says "a cell" is the player's creature, and
that French makes it feminine (`cellule`)**: `morte`, `âgée` and `laissée` agree with
it. The French below is this spec's proposal for `fr.po`. Widths were measured in the
game's font. The room is in canvas px at 1280x720.

| msgid | French | where | EN / FR | room |
|---|---|---|---|---|
| `a new cell` | `une nouvelle cellule` | a view's cell line (15) | 72 / 145 | 420; 236 on TOGETHER |
| `from %s` | `depuis %s` | the end of a cell line; `%s` is `“%s”` round a world's name | in 331 / 394 | 420 for the whole line |
| `from a friend's water` | `depuis l'eau d'un ami` | the same | in 377 / 353 | the same |
| `a new cell · %s died` | `une nouvelle cellule · %s est morte` | a view's line, over a record | 169 / 301 | 420 |
| `your cells` | `vos cellules` | the sheet's caption, before ` · <view>` (16); the chevron's tooltip | 187 / 223 whole | 592 |
| `new cell` | `nouvelle cellule` | an empty row (20) | 79 / 151 | 402 |
| `look` | `voir` | a row's button (15, 112 wide) | 32 / 28 | 88 |
| (no new msgid) `world` · the world's name, built | | a row's line 2 | 347 widest | 402 |
| `a friend's water` | `l'eau d'un ami` | a row's line 2; the detailed view's `Where` | 113 / 102 | 402; 280 |
| `a world that is gone` | `un monde disparu` | the same | 143 / 133 | the same |
| `hungry`, `starving` | `affamée`, `meurt de faim` | the end of a row's line 1 and of `Age` | 59 / 104 | in 402 and 280 |
| `died in %s`, `died in a friend's water` | `morte dans %s`, `morte dans l'eau d'un ami` | a record's line 2, and its `Then` | 349 / 396 widest | 402; wraps in 280 |
| `where you left it` | `là où vous l'avez laissée` | `Then` (15) | 119 / 171 | 280 |
| `comes into %s at a quiet place` | `arrive dans %s, à un endroit calme` | `Then` (15) | 294 / 345 | wraps in 280 |
| `a cell is played only in the view it was born in` | `une cellule ne se joue que dans la vue où elle est née` | the sheet's footnote (15) | 325 / 382 | 592 |
| `rename this cell` | `renommer cette cellule` | naming's title (22) | 170 / 247 | 512 |
| `its body and its genes are gone for good.` | `son corps et ses gènes disparaissent pour de bon.` | the confirm's line (17; a sentence, with a full stop) | 332 / 407 | wraps in 512 |
| `each world keeps its own water` | `chaque monde garde sa propre eau` | "your worlds"' footnote, **replacing** the old one | 229 / 258 | 592 |
| `everything living in it is gone for good. your cells are not.` | `tout ce qui y vit disparaît pour de bon. vos cellules, non.` | a world's delete line, **replacing** the old one | 463 / 457 | wraps in 512 |
| `%d minute old`, `%d hour old`, `%d day old` and their plurals, **context `cell`** | `âgée de %d minute(s)`, `heure(s)`, `jour(s)` | a cell's age (15) | in line 1 | in 402 |
| the seven default names (`cells.md` §1.7) | `pantoufle`, `cloche`, `trompette`, `protée`, `cygne`, `roue`, `étincelle` | names (20 in a row, 28 in the detailed view, 15 in a line) | 36..81 / 46..100 | 220 at 20, as a world's |

**Reused as they are:**

- `full vision`, `point of view`;
- the ten generation phrases and `generation %d`;
- `world`, `rename`, `delete`, `keep`, `back`, `close`, `delete %s?`;
- `“%s”`, `genome · %s`, `numbers`;
- the pause screen's gene words and lines.

Their notes gain this screen's uses.

**Retired:**

- `each world keeps its own water, and your cell in it`;
- `everything living in it, and your cell with it, is gone for good.`

**"Slot" is never a player's word for a cell's place.** On screen, and to a
translator, a slot is one of the body's places for a gene (the README's glossary).
The player reads `your cells`, a row and `new cell`, and the code alone says slot.
**The README's glossary gains one sentence:** "The player keeps **cells**, three
for each view, each with a **name**: their own words, or one of the game's default
names (`slipper`, `bell`...), which are translated like a world's and follow the
language."

**Lint rooms** (`tools/i18n_pot.gd`), in every catalog:

- a view's cell line at 420 px. The name may give way; the rest may not;
- a row's two lines at 402 px;
- `Then` at two lines of 280 px;
- the sheet's caption with each view at 592 px.

---

## 7. Rendered, and judged

The mock's frames are in the design session's notes (`notes/mocks/`), not in the
repository, as `settings.md`'s prototype was. Every state below was shot at 1280x720,
and the ones marked "both" at 2400x1080 too:

| frame | what it shows | judged |
|---|---|---|
| `chooser`, both, EN | a cell on full vision, a new cell on point of view | **Reads at once.** The cell is the button's second line, and the chevron hangs to the right with the view still centred over its note |
| `chooser_fr` | the longest ordinary line, `… · depuis « tonneau de pluie »` | 394 of 420 px; fits |
| `chooser_wide` | a twenty-`W` name with `generation 12` and a `from` | 606 px: overflows, hence the rule that the name gives way (§1.2) |
| `chooser_dead`, both | `a new cell · slipper died` | clear about what pressing does, and about what happened |
| `sheet`, `sheet_fr` | a selected cell, another, an empty slot | **the twin of "your worlds"**: the same rows, marks and slabs; `look` reads as secondary |
| `sheet_dead` | a selected record | the plus says *a new cell starts here*, and the faint name and lines say it is past |
| `sheet_wide` (2400, FR) | twenty `W`s; `meurt de faim`; a friend's water; a gone world | everything fits: the widest name is 379 of 402 px |
| `detail`, both, EN; `detail_fr` | the facts and the figure | **it reads as the pause screen for a cell you are not playing**. The facts sit at the top, and the actions where `resume` and `leave` are |
| `detail_elsewhere_fr` (2400) | `Then` wrapping | two lines, readable |
| `confirm`, `confirm_fr`, `naming` | the corner's own sheets | unchanged sheets, new words; the French line fits in one line of 512 px |
| `together`, `together_nochev` (1280; 2400 FR) | the TOGETHER buttons with and without chevrons | without chevrons, chosen (§4) |
| `worlds` | the new footnote | fits |

**What judging changed:**

| first version | what it looked like | now |
|---|---|---|
| a record row read `fourth generation · died` over `died in “pond water”` | "died" twice | line 1 is its generation and age; line 2 says where it died |
| a record row in the faint box even when selected | nothing said which slot the view plays | the "current" box when selected, the plus for what starts there |
| chevrons on TOGETHER | the second chevron sat between the two views, belonging to neither | none there |
| a cell line saying `in “rain barrel”` (paper) | promised a trip the button does not make | `from “rain barrel”` |

**Not shown by the mock, and to be shot on the build:**

- the read-only figure with a waiting gene, a fork and numbers on (the mock's figure
  was a crop of a real pause render, `cytostome` selected, numbers off);
- the record's figure at alpha 0.55;
- the French gene words in the figure (the crop was an English render);
- every frame in motion: hover, focus rings, the chevron's hover.

---

## 8. Left open

1. **TOGETHER cannot change the cell.** Back leaves the call, and a LAN call is four
   taps to make again. If players miss it, the page needs a way into each view's sheet
   that plainly belongs to one button. The chevrons tried beside the buttons did not
   (§7).
2. **The pause screen does not name the cell.** Its caption stays `genome ·
   <generation>`.
3. **The world rows no longer say which cells are in a world.** A line naming them
   (`slipper · bell`) would fit, if players look for one.
4. **A phone's keyboard over `rename this cell`** is the worlds' open question
   (`settings.md` §12 item 1): the sheet is the same and sits at the top.

---

## 9. As built: phase 2, 2026-10-04

**Photographed on the build**, through the harnesses' own input paths:
`tools/corner_shot.tscn` for the chooser, the sheet, the detailed view, the corner's
sheets and "your worlds", and `tools/earshot_shot.tscn --cells=` for TOGETHER. Each of
25 states at 1280x720 and 2400x1080, in English and in French: 100 frames, kept in the
build session's notes, as the mock's were. They are §7's frames, and with them a view
whose selected slot holds the other's cell (`chooser_pov`), nothing anywhere
(`chooser_fresh`), the widest name in a gone world (`chooser_wide_gone`), the chevron
and the view hovered, point of view's empty sheet, and the detailed view wide, dead,
at a fork with the numbers on, and with a slot read by touch.

**Where it lands**, measured on the build: every rect of §1.1, §2.1 and §3.1 to the
pixel, at both shapes. The sheet runs from y 112 to 491 with two cells and an empty
slot, to 516 with three cells, and to 441 with three empty slots. The widest lines:
`pantoufle · 4e génération · depuis « tonneau de pluie »`, 394 of 420 px; twenty `W`s
from "hay infusion", the name given way, 419 and 420 of 420; a row's French line 1, 368
of 402; `Then` in French, two lines of 280.

**What judging the build changed:**

| first build | what it looked like | now |
|---|---|---|
| the sheet's panel as tall as corner.tscn draws it | three empty slots left 50 px of empty panel under the footnote | the panel shrinks to its rows each time they are filled |
| a record's whole figure at alpha 0.55 | its `numbers` switch looked switched off, and still worked | the caption, the tray, the figure and its lines at 0.55; the switch as on any cell |

**Where it differs from the sections above, and why:**

- **A selected empty slot has the "current" box** (§2.2 gives an empty slot the faint
  box). It is §7's own fix for a selected record: otherwise nothing says which slot the
  view plays, and point of view's sheet, three empty slots, would show none.
- **A record whose world is gone says `died in a world that is gone`** (one msgid more
  than §6), since that world cannot be named.
- **The figure's first `look` in a session compiles it** (`cells.md` §6.6): on a slow
  phone, the first detailed view may take a moment longer to open than the next.
