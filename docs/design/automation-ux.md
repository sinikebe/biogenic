# Your programs, on screen

Pack 4's block screen, revised after the owner answered `automation.md` §17. The
owner, 2026-09-29:

> And while we're at it, we could propose to players a screen where they can use
> the same logic blocks to automate their cell ! Offering a new gameplay type.
> Both should use the same logic system.

And on 2026-10-02:

> 27 : auto pilot trigger on screen with an icon. Available even outside the menu
> since taking the control back can be a matter of life.
>
> 29 : yes, but then this must be doable by players too. This could be a lvl 2
> bonus of the tail
>
> 30: instincts are "programs". Players have a library of programs. They can, if
> they want, enable many at the same time, as long as they deal with
> contradiction between orders in their programs (there could be a kind of
> priority order when this happens)
>
> 32 : nothing yet. We'll see that later.

Rows 36 and 37 were confirmed the same day. Touching the steering controls while
the autopilot drives takes the cell back at once and switches the icon off.
Holding the tail still is a level-2 tail ability for every cell: `hold still`
holds it and is offered only to a body with a level-2 tail, and `rest` holds it
too only at level 2 (§9.1, item 3).

Rows 38 to 42 were answered the same day, all as recommended but one:

> 40 : no mutation to programs made by players. 100% manual.
> Rest as recommended

So a level-2 tail is a tail with two copies (38), the programs that are on share
eight instincts (39), the hold pad and the words stand as designed (41, 42), and
**no division ever changes a player's program** (40, §2.8).

`automation.md` owns the rules: what an instinct reads and does, how programs
merge, when they run, the save and the wire. **This document owns the screen**:
the library and the program on the pause screen, the autopilot icon, the hand's
hold, live feedback, both shapes, touch, mouse, keys and French. The rules' text,
ladders and vocabulary are `behaviour.md` §3's, unchanged.

**The words.** An **instinct** is one line (`echo, bigger than my mouth → turn
away`). A **program** is a named list of up to eight. The **library** is your
programs. The **autopilot** hands your cell to the programs that are on.

**Status: designed and mocked, not built.** A throwaway mock in a scratch worktree
at `dev` `47d2308` drew every frame in §10 over the real paused run and the real
water. It used the real rulebook parsing `drop.gd`'s founders, the real fonts,
scrim, membrane, gear and pads, and the corner's own naming and confirm sheets.
Every frame was shot at 1280x720 and 2400x1080, in English and French, judged, and
changed until it held. `automation.md`'s revision was drafted alongside, and the
two landed together; §9.1 lists where they meet, settled.

---

## 0. Decided, in one place

1. **The pause screen's second page is `programs`**, beside the genome. It has two
   views: the **library** (§2) and **a program** (§3). The page chip under the gear
   switches pages. Inside a program it reads `‹ programs` and goes back up.
2. **The library is eight rows.** Each row has a switch, the program's name, its
   count of instincts, one column per trigger it moves, and `›` to open it. **The
   order is the priority**: drag a program up to let it win. Two programs that are
   on and move one trigger both mark that column. A program that can never win
   there gets a T-bar over its mark (§2.3).
3. **A program is the old instincts page**: eight rows, the inspector and the
   ladder, doing what they did. Rows add two states, *held back by a program
   above*, which names that program, and *never acts* (§3.2).
4. **The autopilot is a 56 px well in the water's top-right corner**, mirroring the
   pause tap (§5). Its glyph is an instinct in miniature: a sense and its nerve.
   The nerve ends in a **chevron** when your programs have your cell and in a
   **T-bar** when your hand holds them back. Tap it, or press `R`. Touching any
   control takes the cell back and switches it off (row 36). It is hidden while
   no program is on. On the page it stands beside `resume`, dashed and explained
   when it cannot be used.
5. **The hand holds the tail still with a pad that exists only with a level-2
   tail** (rows 29 and 37, §6). Under `pads` it is inboard of push, under `stick`
   inboard of dash, and under `anywhere` in the place `pads` gives it (row 41). At a
   keyboard it is `S` or `↓`. It is held, like push. Its mark is one stroke of the
   tail running into a stop bar, and the instinct that holds the tail wears that
   mark on the page.
6. **The water gains the icon and the pad, and nothing else** (row 32). The organ
   thread is gone. The page's row states and the replay still show which instinct
   acted (§7).
7. **No keyboard is needed.** Programs get automatic names (`program 2`, `water
   cell`). `rename` opens the corner's own naming sheet, the one worlds use, and
   is optional.
8. **French fits everywhere** (§8). The tightest line is `rest`'s `Explain`, 816
   of 856 px.
9. **Content only**: scenes, GDScript and words. Keys are read raw, so
   `project.godot` is not touched and `binary_version` does not move. No `addons/`,
   no `ci/`.

---

## 1. Where it lives

The pause screen, beside the genome (rows 28 and 31, as recommended). Alone, the
water waits under it. In a pond it does not, and the page says so (§7.1).

### 1.1 The page chip

A `Button` under the gear, right-aligned with it: anchors (1,0)-(1,0),
offset_right −48, offset_top 116, offset_bottom 172, grow_horizontal BEGIN,
FOCUS_ALL, 17 px. Its word is `programs ›` on the genome page, `genome ›` in the
library, and `‹ programs` inside a program. It is never left of the gear, where a
tray of waiting genes runs. **No pause page puts a control in x 48..112,
y 48..112**: a phone touch arrives twice, and the twin of the press that opened
pause lands there (`gene-lines-and-the-pause-target.md` §4.2).

In French, `programmes ›` makes the chip 156 px wide, x 1076..1232 at 1280. A tray
of four waiting genes ends at x 1060 on the same line, 16 px clear. Five wrap to
a second line. Rendered: `genome_chip_four_fr`, `genome_chip_five_en`.

### 1.2 Opening and leaving

- Pause opens on the genome page whenever a gene is waiting, because a waiting
  gene has a clock. Otherwise it opens on the page and view you left in this run.
- Back and `Esc` first close the corner's top layer (settings, naming, confirm).
  Inside a program they go back to the library, and from there they resume
  (`settings.md` §1.3). A drag in flight is cancelled.
- A division or a death closes the menu, as today, and drops a half-built
  instinct.

---

## 2. The library

Rendered: `library_*` at both shapes and in both languages.

```
1280 x 720                                                            x 1176..1232
 y 48..104   programs  what your cell does on autopilot · the higher program wins   [⚙]
 y 116..172                                                           [ genome › ]
 y 120..574  ┌ rows, 48 tall, 10 apart, x 48..904 ──────────────┐  y 184..604 ┌ inspector ┐
             │ [■ ] flee        2 instincts  ▶              ›   │             │ x 936..1232│
             │ [■ ] water cell  7 instincts  ▶  ∿        ≋  ›   │             └────────────┘
             │ [■ ] careful     1 instinct      ⊤∿          ›   │
             │ [ +  new program               ][copy a water cell's program] │
 y 586..664  Explain / Hint / Act, centred under the rows   y 616..672 [ resume ][AP]
```

### 2.1 The node tree

`rows_w = min(W − 424, 900)` and `rows_x = 48 + floor((W − 424 − rows_w) / 2)`,
as before. `W` is the canvas width, and 424 is two margins, the 296 px tools
column and a 32 px gap. At 1280 the rows are x 48..904. At 2400x1080 (canvas 1600)
they are x 186..1086, and the tools are x 1256..1552. The canvas is 720 tall at
every shape, so nothing reflows vertically.

```
Hud/Pause                       Control (existing)
├─ Scrim, Center                existing; Center (the genome page) hidden while Programs shows
├─ Programs                     Control, full rect, mouse IGNORE, hidden                     NEW
│  ├─ Head                      HBoxContainer, separation 16, IGNORE; (rows_x, 48), (rows_w, 56)
│  │  ├─ Title                  Label 16 px, Color(0.855, 0.953, 0.933, 0.80): "programs", or the program's name
│  │  ├─ Switch                 Control 64 x 48, FOCUS_ALL, STOP: in a program only (§3.1)
│  │  ├─ Note                   Label 15 px, CAPTION Color(0.855, 0.953, 0.933, 0.45), or WARN (§7.1)
│  │  └─ Places                 Control 160 x 56, IGNORE: the library only (row 39, §2.8)
│  ├─ Library                   VBoxContainer, separation 10, IGNORE; (rows_x, 120), width rows_w
│  │  └─ Row0..Row7             Control rows_w x 48: a program, the add row, or an empty place
│  ├─ Program                   VBoxContainer, the same place, hidden: a program's instinct rows (§3)
│  ├─ Lines                     VBoxContainer, separation 6, IGNORE; (rows_x, 586), width rows_w
│  │  ├─ Explain                HBoxContainer, min height 26, centred: Name 15 px + Says 15 px EXPLAIN
│  │  ├─ Hint                   Label 14 px Color(0.855, 0.953, 0.933, 0.38), centred
│  │  └─ Act                    Label 14 px Color(0.588, 1.0, 0.859, 0.50), centred
│  └─ Tools                     VBoxContainer, separation 12; anchors (1,0)-(1,0),
│     │                         offset_left −344, offset_top 184, offset_right −48, offset_bottom 672
│     ├─ Inspector              PanelContainer min (296, 420); fill FILL 0.45, edge TEAL 0.26,
│     │                         radius 6, content margins 16 / 14; a VBoxContainer, separation 8
│     └─ Bottom                 HBoxContainer, separation 12
│        ├─ Resume              Button 228 x 56: the genome page's resume style and handler
│        └─ Autopilot           Control 56 x 56, FOCUS_ALL, STOP (§5.3)
├─ PageChip                     Button (§1.1)                                                  NEW
└─ Corner                       existing, still the last child; its Naming and Confirm sheets
                                serve programs as they serve worlds (§2.5)
```

The colours are those of the old page. `FILL` is `Color(0.063, 0.141, 0.125)`,
`PALE` `Color(0.855, 0.953, 0.933)`, `LIT` `Color(0.49, 1.0, 0.831)`, `TEAL`
`Color(0.12, 0.70, 0.58)`, `SELECT` `Color(0.588, 1.0, 0.859, 0.85)` (the screen's
`FOCUS_TINT`), and `WARN` `Color(0.855, 0.953, 0.933, 0.82)`, the genome page's
own. `EXPLAIN` is `PALE` at 0.62. Boxes have radius 6 and 1 px edges unless a row
says otherwise. On the programs page `Hud/Controls` is hidden, so no pad's ghost
sits under `resume`.

### 2.2 A program's row

| part | geometry | draws |
|---|---|---|
| row | rows_w x 48 | on: fill `FILL` 0.55, edge `TEAL` 0.30. Off: `FILL` 0.30, `PALE` 0.10. Selected: `Color(0.086, 0.204, 0.176, 0.85)` with a 2 px `SELECT` edge. Driving now: the acting underlay as well, `LIT` 0.045, radius 10, 6 px wider each side and 4 px taller |
| switch | x 0..64, its own 64 x 48 target | a track 40 x 20, radius 6, centred at (32, 24), with a square knob 14 x 14, radius 4. **On**: the track is `Color(0.086, 0.204, 0.176, 0.95)` with 1 px `TEAL` 0.80, and the knob sits at the right in `LIT` 0.95. **Off**: the track is `FILL` 0.60 with 1 px `PALE` 0.22, and the knob sits at the left in `PALE` 0.40. Rounded squares, never a circle (`controls.md` §4) |
| name | x 76, 15 px | `PALE` 0.92 on and 0.50 off, trimmed with an ellipsis 16 px before the count |
| count | 14 px, right-aligned 16 px before the trigger columns | `7 instincts`, `1 instinct` or `empty`, at `PALE` 0.45 on and 0.30 off |
| triggers | 4 columns of 44 px, ending 8 px before `›` | §2.3 |
| open | the last 48 x 48 | a chevron `›`, 2 px, 16 tall, `PALE` 0.70 on and 0.45 off |

A tap on the row selects it, and the inspector shows that program. A tap on `›`,
or on the inspector's `open`, opens it. A tap on the switch turns it on or off. It
acts on the lift, inside the switch, once a frame, which is the numbers switch's
rule for one phone touch arriving twice. A drag from any part of the row moves
the program (§2.6). The page opens with a program selected, never with nothing:
the one you last opened, else the first.

### 2.3 The trigger columns, and contradictions

The columns are the triggers the vocabulary declares as `claims`: **steering,
tail** (the `swimming` claim), **dash, push**, always in that order. A column read
downwards answers *who moves what*. **Each trigger is drawn as the pad that works
it by hand**, small:

- the turn pad's dart (`Cilia.draw_slot_dart`, slot 1, r 9, the cirrus hue);
- one stroke of the tail, a sine 24 px wide with amplitude 4.5, 2.2 px, in the
  flagellum hue;
- the myoneme burst (`Cilia.draw_tile_organ`, scale 0.75);
- the push pad's three waves, 22 px wide, 6.5 apart, amplitude 2.4, 1.6 px, in
  the axoneme hue.

The pads and these columns are one set of objects seen twice: what your hand
moves and what a program moves. A first build used the organs' tile glyphs. At
this size they were four look-alike bursts, two of them pink (§10).

A program puts a mark in each column that one of its instincts claims. A claim
of `all` marks every column.

| state | draws | when |
|---|---|---|
| **moves it** | the mark at 0.80 | an instinct of a program that is on claims that trigger |
| **moves it now** | the mark at 0.98 on a 34 x 34 box, radius 6, fill `LIT` 0.14, 1 px `LIT` 0.55 | its instinct won that trigger on the last tick in a pond, or would win now in the dry run (§7.1) |
| **never** | the mark at 0.34, with **a T-bar over it**: a stem from y 3 to 10 and a 16 px bar at y 10.5, 2.4 px, `PALE` 0.70 | a program above it that is on holds an instinct that always wins this trigger: an `always` with no test. Nothing this program does there can act |
| off, or asleep | the mark at 0.30 | the program is off, or the organ is not worn |

**Two programs that are on, with marks in one column, is the contradiction the
owner named.** Both want that trigger, and the higher one wins whenever its
instinct fits. The column shows the overlap at a glance. The inspector says it in
words (§2.4). Inside a program, the held-back row names the program that held it
(§3.2). The T-bar is kept for the one contradiction a player has to fix: a
program that can never act on a trigger. It is the page's mark for inhibition,
the same T-bar that ends a held-back row. The first build also drew it for *held
back right now*, and the two could not be told apart (§10).

### 2.4 The inspector, with a program selected

| part | geometry |
|---|---|
| name | 17 px `PALE` 0.98 |
| state | 14 px `CAPTION`: `on · 7 instincts` or `off · 2 instincts` |
| one line per trigger it moves | 30 tall: its mark at (12, 16), then 14 px `EXPLAIN` at x 30, reading `steering · first`, `steering · after “flee”`, `tail · never` (in `WARN`, with the T-bar over the mark) or `push · asleep`. For a program that is off, the trigger's word stands alone at `PALE` 0.45. Trimmed with an ellipsis at 234 px |
| `open ›` | 264 x 48: fill `Color(0.086, 0.204, 0.176, 0.80)`, 2 px `TEAL` 0.62, 15 px `Color(0.588, 1.0, 0.859, 0.92)` |
| `rename`, `copy` | 128 x 48 each, 8 apart: fill `FILL` 0.35, 1 px `TEAL` 0.22, 15 px `PALE` 0.70 |
| `delete this program` | 264 x 48, styled the same |

At its tallest, a program that moves all four triggers, the inspector is about
398 of 420 px: 360 rendered with three trigger lines, plus a fourth line of 30
and its gap of 8. Under the rows:

- **`Explain`** gives the program's name in `PALE` 0.95, then its place in the
  order: `· runs first of the 3 that are on`, `· runs after “flee”, before
  “careful”`, `· runs last, after “water cell”`, `· the only program on`, `· off:
  the autopilot skips it`, or `· empty: open it to give it instincts`.
- **`Hint`** says what holds it back. A live hold comes first: `held back now:
  “flee”, above, already steers`. Otherwise the line that cannot change: `“careful”
  never moves your tail: “water cell”, above, always swims`. When the live hold
  comes from the same `always` that makes the trigger `never`, the line that
  cannot change is said instead. It is one hold, and the reason that lasts is the
  one worth reading (found in `library_drag_*`, §10.1).
- **`Act`**: `tap a program to see it · drag a program up to let it win`.

### 2.5 New, copy, rename and delete

- **The add row** sits under the last program while there are fewer than eight.
  It holds two targets. `+ new program` is dashed 1.2 px `LIT` 0.40, in 15 px
  `Color(0.588, 1.0, 0.859, 0.70)`, with a 12 px plus at x 20. Its width is the
  row less the copy slab and 12. `copy a water cell's program` is right-aligned:
  as wide as its words plus 40, fill `FILL` 0.40, edge `TEAL` 0.30, 15 px `PALE`
  0.78. In French the dashed part is still 496 px at 1280.
- **New** makes `program N`, where N is the lowest number not in use. The program
  is empty, goes at the bottom, and opens with its add row selected.
- **Copy a water cell's** makes `water cell` (then `water cell 2`, and so on)
  holding `drop.gd`'s `FOUNDERS`, at the bottom. Rules for organs you do not wear
  arrive asleep, and show you what a sense would add.
- **Copy**, in the inspector, makes `<name> 2` (the next free number) right under
  the original, holding the same lines.
- **Anything new starts off**, so adding a program never changes what your cell
  does. The exception is a library with no program on: then the new program
  starts on, so the first one you write works the moment you switch the
  autopilot on. While a program is off, its head says so (§7.1).
- **Rename** opens the corner's `Naming` sheet, opened for a program instead of a
  world. Its title is `rename this program`. The field holds the name, selected,
  with `back` and `rename` under it. An empty name keeps the automatic one. It is
  the one place a keyboard appears, and it is optional. The sheet sits at the top
  of the screen because an Android keyboard covers the bottom half
  (`corner.gd`'s own note). Rendered: `library_rename_*`.
- **Delete** opens the corner's `Confirm` sheet with a world's own question:
  `delete hunt?` over `its 2 instincts are gone for good.`, with `keep` focused
  and `delete` beside it. Rendered: `library_delete_*`. There is no undo, as for a
  world.
- With eight programs there is no add row.

Both sheets are built around `Drops` slots today. The build opens them with a
title, a default name and a callback instead, so worlds and programs share one
sheet each.

### 2.6 Reordering, and the keys

The drag is Godot's own (`set_drag_forwarding` on the row), which reaches touch
through the emulated mouse (`moving-a-gene.md` §3.2). Instincts move the same way
(§4.5). While it runs:

- **the program in the air** is a pill: the switch, the name and its marks, on a
  shadow (radius 10, `Color(0, 0, 0, 0.40)`), filled `Color(0.086, 0.204, 0.176,
  0.95)` with 1 px `LIT` 0.70. It rides `DRAG_LIFT` 34 px above the pointer;
- **its place** is drawn as an outline only, dashed 1.2 px `PALE` 0.30;
- **where it would land** is a 2.5 px `LIT` 0.95 line in the gap nearest the
  pointer, with a dot of r 4.5 at each end;
- **`Act`** reads `let go to move this program here`.

Rows never move during a drag; they reorder on the drop. Rendered:
`library_drag_*`, which drags `careful` above `water cell`, the move that gives
it back its tail.

At a keyboard, `↑` and `↓` move along the rows and `→` goes from a row to its
`›`. `Enter` on a row opens it, and `Space` on the switch flips it. `Shift`+`↑`/`↓`
on a focused row moves the program. That chord is read raw, as the genome's
`Shift`+arrow is. `Tab` goes to the inspector.

### 2.7 The empty library

Rendered: `library_empty_en_1280x720`, `library_empty_fr_2400x1080`.

- **Row 1**, the invitation: `+ new program`, filled `FILL` 0.55, dashed 1.4 px
  `LIT` 0.55, 16 px `Color(0.588, 1.0, 0.859, 0.85)`.
- **Row 2**: `copy a water cell's program`, the quiet slab (row 28).
- **Rows 3 to 8**: empty places, dashed 1 px `PALE` 0.09, dash 6, so all eight
  slots show from the first look.
- **The inspector** reads `no programs yet`. Under it, wrapped in 14 px
  `EXPLAIN`: *a program is a list of instincts: when a sense reports something,
  your cell acts. turn programs on, then the autopilot, and they drive your cell.
  the higher program wins.* Then `what you can sense` and `what you can do`: your
  vocabulary, read off your own genes, each word in its organ's hue. In French it
  fills 399 of 420 px.
- **The autopilot beside `resume`** is disabled (§5.3). `Act` reads `tap + to
  write your first program`.

### 2.8 Rows 38 to 40, answered

Rendered: `library_more_*`, `badge_pips_*`. The library frames of §2.1 to §2.7 run
ten instincts at once, which row 39 does not allow; `library_more_*` is the same
page under it.

- **Row 39: eight instincts in all, shared by the programs that are on.** The
  library's head ends with **the places**: `6 of 8` in 14 px `CAPTION`, then eight
  slots, each 10 x 16 with radius 3, 4 apart, 108 px in all, right-aligned to the
  head. A taken slot is `LIT` 0.40. The selected program's slots are `LIT` 0.95,
  which answers *how many are taken, and by what*. A free slot is outlined 1 px
  `PALE` 0.30. A program that is off and does not fit says so in its count,
  `7 instincts · no room`. A tap on its switch changes nothing, and `Hint` says
  `no room: “water cell” needs 7 places, 2 are free · switch a program off first`.
  Inside a program that is on, the add row goes once the eight are full, and the
  empty place under the last instinct says `the 8 places are full: switch a
  program off, or remove an instinct` (not rendered).
- **Row 40: a program changes only by hand.** No division changes a program you
  wrote, so the page has no mark for a change and no undo of one, and the
  choosing screen shows nothing new for your programs.
- **Row 38: a level-2 tail is a tail with two copies.** The badge on a part that
  waits for its organ's copies (§4.2) is the genome page's own pips: two discs and
  a room dot, `●●•`, read exactly as that page reads a gene's copies. A numeral
  would name a level the genome page does not show for the tail. The words name
  copies too: `hold still needs two copies of your tail` (§8). Rendered as a
  component on the page's colours, not over the run: `badge_pips_*`.

---

## 3. A program

Rendered: `editor_*`, `editor_tail1_*`, `editor_never_*`, `editor_new_*`,
`editor_pond_fr`.

### 3.1 Its head

The title is the program's name, 16 px `PALE` 0.80, and it is not a control.
After it comes the program's switch, the same as a library row's. **The switch is
never left of x 124**: it starts at `max(name_w + 12, 124 − rows_x)` from the
head's left edge, so a short name never puts a control in the pause tap's corner.
Rendered: `editor_never_en`, where the switch sits at 124. Then the note (§7.1).
The page chip reads `‹ programs`. The back control lives under the gear, not at
the head's left, because that corner belongs to the pause tap.

### 3.2 Its rows

Each row is a sentence with a nerve in it: the sense chip in its organ's hue and
glyph, one chip per tested value, an arc, and the action in a column of its own on
the right, so *what does my cell do* is one glance down the right edge. **The
chips' geometry, colours, hover and focus are the landed spec's, unchanged**
(`automation-ux.md` at `dev` `47d2308`, §3.1 and §3.3): sense `input_w` EN 111 /
FR 116, action `output_w` EN 142 / FR 164, tests 14 px + 24, 48 tall, 6 apart.

The states. The ones in bold are new; the rest stand as they were.

| state | arc | `Hint` when the row is selected |
|---|---|---|
| acting | 2 px `LIT` 0.85, chevron 2 px 0.95, with the row underlay | `acting now` |
| held back by an instinct above in this program | 1.6 px `LIT` 0.45, ending in a T-bar 2.4 x 16 px at 0.80 | `held back: an instinct above already steers` (or swims, pushes, dashes) |
| **held back by a program above** | the same | `held back: “flee”, above, already steers` |
| **never acts**: an `always` above it, in this program or in a higher one that is on, claims the same trigger | 1.2 px `PALE` 0.14, ending in a T-bar at `PALE` 0.50 | `never acts: “water cell”, above, always swims` |
| reported, no report passed | the sense's edge at its hue 0.60; arc 1.2 px `PALE` 0.10, head 0.28 | `waiting: your ping hears it, the test is not met` |
| quiet | the same, the sense at rest | `waiting: your ping reports nothing` |
| asleep: an organ it needs is not worn | everything at x 0.42 | `asleep: your body does not wear push` |
| **asleep: its part waits for its organ's copies** | everything at x 0.42 | `asleep: needs two copies of your tail` |
| unreadable | one wide chip, its saved line at 0.42 | `this version cannot read this instinct · it is kept` |
| half-built | blanks dashed, no arc | `pick what it does · until then it does nothing` |
| the program off | everything at rest, waiting style | the head says it (§7.1) |

Every state differs by shape as well as light, which is `genes-and-cilia.md` §4.4's
colour-blind rule. A chevron is not a T-bar, and a lit T-bar is not a pale one on
a quiet line. States cross-fade over 0.12 s, so a pond's 7.5 ticks a second never
flicker.

### 3.3 The tail's hold wears the tail

The action that holds the tail still, `hold still` (`flagellum.hold`,
`automation.md` §4.2), takes the flagellum's hue and the hold mark (§6.2) at 0.30
scale: a 19 px stroke running into a 14 px bar, and the pips badge (§4.2). The page and
the pad use one picture. `rest` keeps the cell's egg: it stops everything you can,
at every level, and holds the tail too only at level 2 (§9.1, item 3). **The
frames were drawn before the two documents settled**, and show `rest` wearing the
hold mark in `hold still`'s place.

### 3.4 Empty places, and adding

Under eight instincts, one slot is the add row: `+ add an instinct`, dashed
1.2 px `LIT` 0.40. In a program with no instincts it is the invitation (§2.7's
style), and the inspector explains an instinct and lists your vocabulary
(rendered: `editor_new_*`). A tap makes a half-built instinct in that slot. Pick
its sense, then its action, and it is whole and runs from the next tick. A
half-built instinct never acts and is never saved. A new program is empty: a tail
beats unless something holds it, so nothing needs a starting `always -> swim`
(`automation.md` §3.6).

---

## 4. Editing an instinct

Unchanged from the landed spec, apart from the badge in §4.2.

### 4.1 Selection is editing

**A press selects the chip under it.** Selecting is harmless and idempotent, so
the second copy of a phone touch changes nothing. The inspector then offers only
what that chip can become:

| inspector part | geometry |
|---|---|
| head, 28 tall | the organ (scale 0.55) and the word, 17 px, its hue moved toward `PALE` by 0.25. A test reads as a list rather than a sentence, `echo · size`, so it translates |
| choices | `GridContainer`, 2 columns, separation 8, cells 128 x 48: glyph at (19, 24), word 14 px at x 36 |
| remove | 264 x 48, fill `FILL` 0.35, edge `TEAL` 0.22, 15 px `PALE` 0.70: `remove this test` or `remove this instinct` |

A choice applies on the lift, inside the cell, once a frame. The row updates in
place, and there is no apply button. The current choice wears the selected box.
A mouse hovering a chip puts its sentence on `Explain`, and leaving gives the
selection's sentence back.

### 4.2 Picking a sense or an action

- **What is offered**: whatever the body and the metabolism declare, plus every
  gene in your DNA. A gene you carry but do not wear is marked as carried:
  glyph at 0.40, word at 0.42, and the genome's ring pip after it. Choosing it
  makes an asleep instinct.
- **What cannot fit is dimmed to 0.35 and inert**: `turn toward` and `turn away`
  under a sense with no bearing, and the reverse. Tapping one says why on `Hint`,
  for example `turn toward needs a sense that says where`.
- **A part that waits for its organ's copies is offered dimmed and badged** (rows
  29, 37 and 38, `automation.md` §4.3). It is dimmed to 0.35 and inert. In the
  cell's top-right corner it carries **the genome page's pips** for the copies it
  needs, drawn by that page's `_draw_pips` in its organ's hue at ink 0.85: a disc
  of `PIP_R` 3.4 per copy, `PIP_PITCH` 10 apart, and a room dot of r 1.6 at
  `PALE` 0.30 after them. The first disc's centre is at (cw − 33.4, 10), so the
  pips span x 91..117, y 6..13 of a 128 x 48 cell: above the word, never on it,
  because the French `fige la queue` runs to x 123. Tapping the cell says `hold
  still needs two copies of your tail` on `Hint`. In `what you can do` the word
  is dimmed and the pips follow it, `PIP_GAP` 7 after. Rendered: `badge_pips_*`.
- **Changing the sense** keeps the tests the new sense can carry, matched by value
  name, and drops the rest.
- **`push`** adds a row of two cells under the grid when it is the current
  choice: `half` and `full`.

### 4.3 Setting a test, with no keyboard

`+` on the selected row adds a test. If the sense carries more than one value not
yet tested, the inspector asks `test what?` with one cell per value (3 across, 82
wide). The new test starts as `below` the ladder's middle rung, index n / 2
rounded down, and is selected. **The value is fixed once chosen**: to test
something else, remove the test and add another. The editor has three blocks:

1. **The comparison**: 2 x 2 cells of 128 x 48, in the kind's own words (§8).
2. **The step, on a ladder**: a rail with one tick per rung of
   `Rulebook.LADDERS` and a rounded-square knob, never a circle; a tap snaps to
   the nearest rung, a drag rung to rung, `←`/`→` one step. Rising and falling
   have no ladder; a size offers `my mouth` and `me`. Geometry as landed (§4.3 at
   `47d2308`): rail 6 px, ticks 18 px, knob 24 x 28 radius 6, block 264 x 74.
3. **What your sense reports now**: an 8 px `LIT` 0.85 triangle under the rail per
   report, and one 14 px line, `now: one echo, 350 µm away`.

### 4.4 Removing and adding

`remove this test` and `remove this instinct` act on the lift. There is no
confirmation: an instinct is a few taps to rebuild. The selection moves to
whatever now holds that slot. `Copy a water cell's program` lives in the library
now (§2.5), not in an empty program.

### 4.5 Moving an instinct

Drag any chip of an instinct to move the whole instinct. The pill is its sense
chip, a 36 px arrow and its action chip, both lit, on the same shadow and lift as
a program's pill. The drop line, the hollow source and `Act` (`let go to move this
instinct here`) work as in §2.6. At a keyboard, `Shift`+`↑`/`↓` on a focused chip.

### 4.6 Touch, mouse and keys

| | touch | mouse | keys |
|---|---|---|---|
| select a chip | tap | click | arrows, then `Enter`/`Space` |
| pick a choice | tap | click | `Tab` or `→` into the inspector, arrows, `Enter` |
| set a step | tap or drag the rail | the same | `←`/`→` |
| move an instinct | drag a chip | drag | `Shift`+`↑`/`↓`, read raw |
| switch, page chip, resume, autopilot | tap | click | `Tab`, `Enter`. `R` toggles the autopilot (§5.2) |

Every target is at least 48 canvas px, which is 72 device px at 2400x1080. A
mis-tap only selects, and selecting is free.

---

## 5. The autopilot

Rendered: `play_*` in both views and all three schemes, `zoom_icon_and_pads`.

### 5.1 In the water

`Hud/Autopilot` is a `Control` placed right after `PauseTap` in the tree. It
has anchors (1,0)-(1,0) with offset_left −104, offset_top 48, offset_right −48 and
offset_bottom 104, so it fills x W−104..W−48, y 48..104. Mouse STOP, focus NONE.
It is drawn with `_well()`, as the pause tap is.

**Why the top right.** It mirrors the pause tap, one launcher edge margin in from
the corner. Both corners keep the game's chrome, away from the bottom two
corners where thumbs rest (the pause tap's own argument) and outside the doubled
touch's corner. When the menu is up the gear stands in the same place, and the
two are never drawn together.

| state | well | glyph |
|---|---|---|
| **hidden** | | no program is on, or none has a whole instinct; the cell is not alive; from the pinch of a division to the birth; the menu is open. A control drawn where it does nothing teaches that it does nothing, the pause tap's rule |
| **off**: your hand has the cell | `_well(0.13, 0.09)`, the pause tap at rest | the nerve ends in a T-bar, in `PALE` 0.30 |
| **on**: your programs have it | `_well(0.58, 0.55)` | the nerve ends in a chevron, and the sense is filled at 0.35, in `LIT` 0.85 |
| **hot**: under the mouse, or pressed | `_well(0.58, 0.48)`, the pause tap hot | its own shape, in `PALE` 0.92 |
| **taken back** | the light falls from on to off over 0.6 s | the T-bar replaces the chevron on that frame |

**The glyph**, about the centre c of the 56 px box:

- the sense: `Rect2(c + (−17, −8), (11, 16))`, radius 3, 2 px stroke;
- the nerve: from x c−6 to c+15 at the centre line, 2.4 px;
- the chevron: arms from (c+9, c∓6.5) to (c+15.5, c);
- the T-bar: at x c+15, from −9 to +9, 2.8 px.

It is an instinct row in miniature: a sense, its nerve, and the page's two
endings, the chevron for *acting* and the T-bar for *held back*. The player
learns it beside `resume`, where it has words (§5.3). A first glyph had a block
at both ends of the nerve and read as a dumbbell (§10).

### 5.2 Pressing it, and taking back

- **A press toggles it**, the way the pause tap's press pauses. It goes through
  `_is_widget_tap` and `accept_event()`, because an unclaimed press in the water
  is a steer, and a short one is a dash. A same-frame guard stops a phone touch's
  emulated twin from toggling it straight back.
- **Pressing the icon is not the hand.** Switching on lets go of whatever the
  hand held (`automation.md` §2.2), and only a new press takes the cell back.
- **Touching any control takes the cell back at once and switches it off** (row
  36). A control is whatever the scheme reads as the hand (`automation.md` §2.3):
  a finger on the water under `anywhere`; the stick or any pad under `stick` and
  `pads`, the hold pad included; and the steer, push, dash and hold keys. The
  cell is yours on that frame and the glyph changes on that frame. Its light falls
  over 0.6 s (`Swell` 0, 0, 0.6), so a player who took the cell back by accident
  can see what happened. Rendered: `play_pov_anywhere_taken_*`, the hold pad
  pressed while the autopilot drove.
- **`R` toggles it at a keyboard**, in play and on the programs page. It is read
  raw (`keycode` or `physical_keycode`, as `N` and `V` are) because a content pack
  cannot add an action. `R` sits in the same place on QWERTY and AZERTY. `A`, `Q`,
  `W`, `Z` and `M` all move between the two layouts, and `A` already steers.
- **The first time it is drawn in a lineage, it breathes once**, with the pause
  tap's breath (`BREATH_RISE` 0.3, `BREATH_FALL` 1.5, `beam-levels.md` §8.4). It
  appears the moment a program is on, and the breath links the icon to the page
  you have just left.

### 5.3 On the page

The page's copy sits beside `resume`, at x W−104..W−48, y 616..672. It has the
same states, plus **disabled** while no program is on: no fill, a dashed 1 px
`PALE` 0.16 outline (dash 4), and the off glyph at 0.16.

- **Hover or focus** puts its sentence on `Explain`: `autopilot · hand your cell
  to your programs. tap it again, or steer, to take it back.`
- **A tap** while disabled says `turn a program on to use the autopilot` on
  `Hint`. Switched on, it says `autopilot on: your programs have your cell when
  you resume` (alone), or `… have your cell` (in a pond). Switched off, it says
  `autopilot off: your cell is yours`.

Alone, the water waits, so switching it on here means *when you resume*. In a
pond the open menu silences your hand (`steering_off`). With the autopilot on,
your programs drive while you edit. With it off, your cell drifts as it does
today, and the head line says which of the two is happening (§7.1).

---

## 6. Holding the tail still by hand

Rendered: `play_*`, `zoom_icon_and_pads`.

### 6.1 Where, scheme by scheme

`controls.gd` gains a sixth control, `HOLD`, drawn and held the way `push` is.

| scheme | rect (canvas) | why |
|---|---|---|
| `pads` | (W−384, H−144, 96, 96), inboard of push | the right-hand cluster is what you do. Hold is its innermost pad, and push, the more frequent, stays nearer the thumb |
| `stick` | (W−264, H−144, 96, 96), inboard of dash | the stick pushes under `stick`, so push's place is free. Left empty, it read as a missing pad (§10) |
| `anywhere` | (W−384, H−144, 96, 96), where `pads` puts it | the one control this scheme draws. Its thumbs rest in the bottom corners and steer from there, and a pad starts its gesture only where a finger first lands (`controls.gd` `hit`). Three pad widths in, it sits past a resting right thumb. The right edge's middle was tried first, but a top-centre punch-hole camera lands there in landscape (§10) |

- **It exists only while the tail is at level 2** (`level_of(&"flagellum") >=
  HOLD_LEVEL`), because a pad exists only when the organ that works it does
  (`controls.md` §1.1). It goes at the pinch of a division with the other action
  pads.
- **It is held, like push.** The tail is still while the pad is held and beats on
  its own clock once you let go. A toggle would leave a state in the water to
  forget, and a long hold is the autopilot's job.
- **At a keyboard it is `S` or `↓`, held**, the opposite of `W` and `↑`, which
  push. Read raw.
- **It is the hand** (row 36). Pressing it while the autopilot drives takes the
  cell back, then holds the tail still.
- **The pads show your hand only.** While your programs hold the tail, the hold
  pad stays dark (`automation.md` §4.2).
- **Under `anywhere`**, `controls.gd` stops being invisible for this one pad.
  `_live(HOLD)` is true under every scheme, and `cell.gd` asks `controls.press()`
  before it claims its single pointer, as it does under the drawn schemes. Row 41
  was answered that it does (§12).
- **The scheme chooser's preview** (`controls.md` §5.1) draws the pad where it
  will be, so the preview still explains the scheme.

### 6.2 The mark

The mark is one stroke of the tail's wave running into a stop bar. The stroke is
a polyline 64 px wide, 1.25 wavelengths, amplitude 8, damped to flat over its
first 62 %, 2.6 px thick. The bar is 26 tall and 3.2 px thick, 6 px past the
stroke's end. It is drawn in `Cilia.hue(&"flagellum")` at `MARK_REST` 0.36, or
`MARK_HELD` 0.92 when held, in the same `well` and `well_lit` as the other pads.
The push pad's wave marches; this one stops. Its hue is the flagellum's orchid
beside the axoneme's magenta, the family `cilia.gd` keeps on purpose, so shape is
what tells them apart.

---

## 7. Live feedback

### 7.1 On the page

- **In the library**, the trigger columns show *moves it now* and the acting
  underlay. **In a program**, the rows show their states.
- **Alone, the water waits**, and your programs were not read while your hand
  held the cell. The page shows **a dry run**: what your programs would do now if
  the autopilot were on, read from the last frame's reports. It acts on nothing
  and writes no memory. It runs when the page opens and after every edit, so
  moving a rung shows at once whether that instinct would act. If it proves
  fiddly, draw the rows at rest until the water moves. **Watch for** a dry run
  that advances the rules' memory and so changes what they do after resume.
- **In a pond**, with the autopilot on, the rows update 7.5 times a second.

The head's line, in this order of priority:

| when | line, 15 px | tint |
|---|---|---|
| a pond, autopilot on | `the water is still moving · your programs have your cell` | `WARN` |
| a pond otherwise | `the water is still moving · you can still be eaten` (exists) | `WARN` |
| in a program that is off | `off: this program does nothing until you turn it on` | `CAPTION` |
| otherwise, in the library | `what your cell does on autopilot · the higher program wins` | `CAPTION` |
| otherwise, in a program | `the first instinct that fits, from the top, wins` | `CAPTION` |

The landed spec's *nothing here swims* line goes: a tail beats unless something
holds it (`automation.md` §5.3), so a program with no swim no longer leaves the
cell drifting.

### 7.2 In the water

**The autopilot icon shows who has your cell.** Lit with a chevron, your
programs. Dark with a T-bar, you. **Nothing else is drawn** (row 32): no thread,
no root, no number. A tail held still is drawn still (`automation.md` §8.1), but
that is the body doing what it does, not an indicator.

### 7.3 In the replay

The `what you felt` pane draws the icon in its corner as it stood, from
`Delta.ACTS`, and draws a held tail still. While the autopilot had the cell, a
second line runs under the pane's caption: the program and the instinct that
steered, in a row's words, `“flee” · echo → turn away`, 14 px `CAPTION`. A death
then reads back as *flee turned me into it* (`automation.md` §8.4). It was not
rendered here; the build shoots it.

---

## 8. Words, and their room

The names are the owner's, and row 42 took this set as listed. Row 38 then moved
the three hold sentences from *level 2* to *two copies* (§2.8), and row 40 took the
change's words out. The set is in the game's
register: lowercase, `vous` in French, and names inside a sentence wearing their
language's quotes, “flee” and « fuite ». French figures are measured off the mock.

| | English | French | room |
|---|---|---|---|
| the page, the chip | programs | programmes | the chip's word ≤ 108 px at 17 (French 106) |
| new | new program; copy a water cell's program | nouveau programme; copier le programme d'une cellule de l'eau | the copy slab, 308 + 40 at 15 |
| automatic names | program %d; water cell; %s 2 | programme %d; cellule de l'eau; %s 2 | |
| count | 1 instinct; %d instincts; empty | 1 instinct; %d instincts; vide | ≤ 90 at 14 |
| inspector | on · %s; off · %s; open; rename; copy; delete this program | actif · %s; coupé · %s; ouvrir; renommer; copier; supprimer ce programme | 78 in a 128 cell |
| triggers | steering, tail, dash, push | direction, queue, bond, poussée | |
| order | first; after %s; never; asleep | en premier; après %s; jamais; endormi | a line ≤ 234 at 14, trimmed |
| places (`Explain`) | runs first of the %d that are on; runs after %s, before %s; runs last, after %s; the only program on; off: the autopilot skips it; empty: open it to give it instincts | passe en premier des %d actifs; passe après %s, avant %s; passe en dernier, après %s; le seul programme actif; coupé : le pilote automatique l'ignore; vide : ouvrez-le pour lui donner des instincts | ≤ 856 at 15 |
| sheets | rename this program; its %d instincts are gone for good. (`delete %s?`, `keep`, `delete`, `back` and `rename` exist) | renommer ce programme; ses %d instincts disparaissent pour de bon. | the sheets' own rooms |
| autopilot | autopilot · hand your cell to your programs. tap it again, or steer, to take it back. | pilote automatique · confiez votre cellule à vos programmes. touchez-le encore, ou dirigez, pour la reprendre. | 790 of 856 at 15 |
| rest | rest · stop steering, pushing and dashing, and drift. with two copies of your tail, hold it still too. | repos · cesser de se diriger, de pousser et de bondir, et dériver. avec deux copies de la queue, l'immobiliser aussi. | **816 of 856 at 15, the tightest line** |
| the hold, `flagellum.hold` | hold still · hold your tail still and keep steering, for free. needs two copies of your tail. | fige la queue · immobiliser la queue et continuer à se diriger, gratuitement. demande deux copies de la queue. | 797 |
| the places (row 39) | %d of 8; no room; no room: %s needs %d places, %d are free · switch a program off first; the 8 places are full: switch a program off, or remove an instinct | %d sur 8; pas de place; pas de place : %s demande %d places, %d sont libres · coupez d'abord un programme; les 8 places sont prises : coupez un programme, ou retirez un instinct | 653 at 14 |
| hints | held back: %s, above, already steers; never acts: %s, above, always swims; held back now: …; %s never moves your tail: %s, above, always swims; asleep: needs two copies of your tail; hold still needs two copies of your tail; turn a program on to use the autopilot | retenu : %s, au-dessus, dirige déjà; n'agit jamais : %s, au-dessus, nage toujours; retenu en ce moment : …; %s ne mène jamais votre queue : %s, au-dessus, nage toujours; endormi : demande deux copies de la queue; « fige la queue » demande deux copies de la queue; activez un programme pour utiliser le pilote automatique | ≤ 856 at 14, longest about 584 |
| head lines | §7.1 | l'eau bouge encore · vos programmes mènent votre cellule; coupé : ce programme ne fait rien tant que vous ne l'activez pas; ce que fait votre cellule en pilote automatique · le plus haut l'emporte; le premier instinct qui convient, en partant du haut, l'emporte | the library's French note ends at 621 of 856 |
| acts | tap a program to see it · drag a program up to let it win; let go to move this program here; tap + to write your first program; tap + to give this program its first instinct | touchez un programme pour le voir · glissez-le vers le haut pour qu'il l'emporte; lâchez pour placer ce programme ici; touchez + pour écrire votre premier programme; touchez + pour donner un premier instinct à ce programme | ≤ 856 at 14 |

The instincts' own vocabulary is the landed set, unchanged:

| | English | French | room |
|---|---|---|---|
| senses | always, hit, hunger, **meal**, echo, beam, smell, shadow, touch | toujours, coup, faim, repas, écho, rayon, odeur, ombre, contact | 72 px at 15 |
| values | bearing, distance, size, level, closeness, strength, seconds | angle, distance, taille, niveau, proximité, force, secondes | 70 at 14 |
| actions | turn toward, turn away, **tumble**, swim, rest, dash, push; half, full | tourne vers, se détourne, culbute, nage, repos, bond, pousse; moitié, à fond | 112 at 15 with `push · full` |
| a level | below %s, above %s, rising, falling | moins de %s, plus de %s, monte, baisse | 140 at 14 |
| seconds | under %s, over %s, rising, falling | moins de %s, plus de %s, monte, baisse | 140 |
| a distance | within %s, beyond %s, going away, closing in | à moins de %s, à plus de %s, s'éloigne, s'approche | 140 |
| a bearing | within %s, beyond %s, moving aside, moving ahead | à moins de %s, à plus de %s, s'écarte, se recentre | 140 |
| a size | smaller than %s, bigger than %s, growing, shrinking; my mouth, me | plus petit que %s, plus grand que %s, grossit, rapetisse; ma bouche, moi | 184 |
| units | `30%`, `5 s`, `220 µm`, `30°` | `30 %`, `5 s`, `220 µm`, `30°` | |

Every sentence is one message with a `TRANSLATORS:` note. Words live beside the
declarations, so a new gene brings its own words, not a screen.

**Rooms the lint must hold** (`tools/i18n_pot.gd`):

- **`ROW_ROOM`**: for every sense, its widest test on each value it carries, plus
  the widest action, must leave **≥ 40 px of arc in 856**. French today leaves 62,
  on an echo with three tests.
- the page chip's word **≤ 108 px at 17 px**;
- each head line **≤ 856 px at 15 px**, less the title, the switch and the places;
- **`Explain` ≤ 856 at 15**;
- each inspector trigger line ≤ 234 at 14 with a name of the default length.

---

## 9. What the build needs

### 9.1 Where the screen meets `automation.md`'s revision

That revision was drafted at the same time, and the two landed together. The
screen agrees with it on these points:

1. **Programs merge in library order** (its §3.3). One `choose` runs over the
   concatenation. *Held back* needs to know which rule held it, so the row can
   name the program. *Never* needs to know of an `always` with no test above it,
   claiming the same trigger.
2. **The autopilot** (its §2): off at every new cell, kept through a division,
   not saved, hidden while nothing can run. `HAND_LETS_GO` is gone. Agreed.
3. **The part that holds the tail: settled on `automation.md`'s model.** `rest`
   is offered at every level: it stops steering, the push and the dash, and holds
   the tail too only at level 2, so it claims `all` and marks every trigger
   column. `hold still` (`flagellum.hold`) holds the tail alone, is offered only
   with a level-2 tail, and claims the tail column. Whatever part waits for a
   level is badged (§4.2) and wears the hold mark (§3.3). Row 37 was first relayed
   to this screen as "`rest` only with a level-2 tail", and the frames show that:
   `rest` with the hold mark, claiming the tail alone. Read `hold still` there.
4. **A new program starts empty** (its §3.6). Agreed. The landed list's starting
   `always -> body.swim` would have left every program below it with a tail that
   never acts.
5. **Rows 38 to 40, answered** (§2.8): 38 and 39 as recommended. 40 the other
   way: no division changes a player's program, so the page has nothing for it.
6. **The dry run** while the water waits (§7.1), and a half-built instinct
   belonging to the page alone, are the screen's own.

### 9.2 Files

| file | change |
|---|---|
| `game/normal/normal_mode.tscn` | `Hud/Autopilot`; `Hud/Pause/Programs` and `Hud/Pause/PageChip` (§2.1) |
| `game/normal/programs_page.gd` **new** | both views: layout from `W`; the rows and their states; the trigger columns; the places; the inspectors; the ladder; the drags; the keys; the words said again on `NOTIFICATION_TRANSLATION_CHANGED`, deferred (`settings.md` §3.3). It reads a vocabulary, a library and per-rule states. It does no rule arithmetic |
| `game/normal/normal_mode.gd` | the autopilot's visibility, press, `R`, take-back hook and first breath; the page switch and which view opens; Back from a program to the library; `Hud/Controls` hidden on this page |
| `game/normal/controls.gd` | `HOLD`: its rect by scheme, `_live` gated on the tail's level, drawn under `anywhere`, the mark; `update(..., hold)` |
| `game/normal/cell.gd` | `S` and `↓` read raw; the hold as part of the hand; under `anywhere`, `controls.press()` before claiming the pointer |
| `game/menu/corner.gd` | `Naming` and `Confirm` opened with a title, a default and a callback, so programs use them |
| the replay's panes | the icon and the line of §7.3 |
| `genome.gd`, `cell.gd`, `metabolism.gd`; `game/i18n/biogenic.pot`, `fr.po`; `tools/i18n_pot.gd` | the words and their rooms (§8) |
| `tools/drive.gd` | `--page=programs`, `--autopilot=on\|off`, `--hold`, and selection and drag poses, so every frame in §10 can be shot from the real build |
| `game/vision/cilia.gd` | nothing: the thread is gone |

### 9.3 What the build checks

- **Every frame in §10, from the real build**, at both shapes in English and
  French, and judged. Then a keyboard-only pass and a mouse-hover pass, which the
  mock did not render.
- **The doubled touch.** A phone tap on the autopilot toggles it once. A tap at
  (76, 76) that opens pause, its emulated twin included, changes nothing in either
  view.
- **Row 36, under each scheme.** A press on each control while the autopilot
  drives gives the cell to the hand and switches the icon off, both on that frame.
  Pressing the icon itself steers nothing and dashes nothing under `anywhere`.
- **The hold pad under `anywhere`.** A finger that lands on it does not steer,
  and one that lands elsewhere and slides over it keeps steering.
- **The glance** (`controls.md` §3.2's method, three renders diffed to 0 pixels
  first). The autopilot on, and the hold pad, must lose to the soma figure. If
  the on state ties, lower its glyph from 0.85.
- **The lint**: the rooms of §8, then `--lint-all`.

---

## 10. Rendered and judged

These come from the throwaway mock over a real run: `--rendering-driver opengl3
--fixed-fps 60 --seed=7`. The page frames were shot over the paused run and the
play frames over the moving water, with axoneme and myoneme worn so every pad
appears. The shots went to the owner with this spec, and the build shoots each
frame again (§9.3).

| frame | judgement |
|---|---|
| `library_{en,fr}_{1280x720,2400x1080}` | passes. Five programs, three on. `flee` steers now. `water cell` steers after it, and its tail acts. `careful` can never move its tail and wears the T-bar. The inspector says *after “flee”*, `Explain` gives the place in the order, and `Hint` gives the hold |
| `library_empty_en_1280x720`, `library_empty_fr_2400x1080` | passes. The invitation, the copy and eight places. The autopilot is dashed beside `resume`. The French inspector fills 399 of 420 |
| `library_drag_fr_1280x720`, `library_drag_en_2400x1080` | passes. `careful` rides above the finger toward the gap over `water cell`, and its source is hollow |
| `library_rename_fr_1280x720`, `library_rename_en_2400x1080` | passes. The corner's own naming sheet at the top, its name selected |
| `library_delete_en_1280x720`, `library_delete_fr_2400x1080` | passes. The corner's own confirm, a world's question |
| `library_more_en_1280x720`, `library_more_fr_{1280x720,2400x1080}` | passes for row 39: `6 of 8` with `hunter`'s three slots bright, and `water cell` with no room. French: the note ends 70 px before the places. **Its caret, `changed at your last division`, `undo the change` and the change's `Hint` are void under row 40**; without them the inspector is 322 of 420 |
| `editor_{en,fr}_{1280x720,2400x1080}` | passes. `water cell`, its beam row held back by “flee”, `rest` wearing the hold mark, the autopilot on beside `resume` |
| `editor_tail1_fr_1280x720`, `editor_tail1_en_2400x1080` | passes. Under a level-1 tail both rests are asleep, and `rest` in the choices is dimmed and badged `2`. Drawn before §9.1 item 3 settled: it is `hold still` that sleeps and is badged, and `rest` stays awake. Its numeral is now the pips (`badge_pips_*`) |
| `badge_pips_{en,fr}_{1280x720,2400x1080}` | passes. A component render on the page's colours, not over the run: the inspector's choices with `hold still` dimmed and `●●•` in its corner, clear of `fige la queue`; the same pips after the word in `what you can do`; the genome page's `swim ●••` beside them, which is what a player matches them against |
| `editor_never_en_1280x720`, `editor_never_fr_2400x1080` | passes. `careful`'s one row ends in a pale T-bar, the `Hint` says why, and the switch sits at x 124 after a short name |
| `editor_new_en_1280x720`, `editor_new_fr_2400x1080` | passes. A new program, off, with the invitation and the vocabulary. French fills 404 of 420 |
| `editor_pond_fr_1280x720` | passes. The head warns that your programs have your cell |
| `genome_chip_four_fr_1280x720`, `genome_chip_five_en_1280x720`, `genome_chip_fr_2400x1080` | passes. `programmes ›` clears a tray of four by 16 px |
| `play_pov_pads_on_*`, `play_fv_stick_on_*`, `play_fv_anywhere_on_*` | passes. On, in both views and under all three schemes. It is the brightest control in point of view, and §9.3's glance decides whether it is too bright |
| `play_pov_stick_off_*`, `play_pov_anywhere_off_1280x720`, `play_fv_pads_off_held_*` | passes. Off, it is as quiet as the pause tap. The hold pad, held, is lit |
| `play_pov_anywhere_taken_*` | passes. The hold pad pressed while the autopilot drove: the T-bar shown at once, its light half fallen |
| `zoom_icon_and_pads_2400x1080` | passes. On, taken and off, then the hold pad alone and beside push and dash, at device pixels |

`editor_change_*` showed a division's change and its undo. Row 40 removes both, so
it no longer passes for anything.

**What judging changed** (frames in `shots/iterations/`; the two first versions
that later renders overwrote, the tile-glyph columns and the dumbbell, were drawn
again for the record as `*_FIRST`):

| first version | what it looked like | now |
|---|---|---|
| the trigger columns as the organs' tile glyphs | four look-alike bursts; flagellum and axoneme both pink | the pads' own marks: dart, stroke, burst, waves |
| a T-bar over a mark also for *held back now* | could not be told from *never* | the T-bar is *never* only. *Now* is the lit box, and the rows hold the live hold |
| the autopilot as a block at both ends of the nerve | a dumbbell | one block, the nerve, and its ending |
| the autopilot on with a 2 px edge at 0.70 | the loudest thing in point of view | 1 px at 0.55, glyph 0.85, and the glance check |
| `rename`, `copy` and `delete` in one row | `renommer` and `supprimer` touched their edges | `open`, then `rename` and `copy`, then `delete this program` |
| delete confirmed inside the inspector | a second way to ask a question the game already asks | the corner's sheet, as for a world |
| `Explain`: *moves your steering, tail and push* | repeated the columns, and its French was clumsy | the program's place in the order |
| the hold pad under `stick` where `pads` puts it | a hole where push would be | inboard of dash |
| the hold pad under `anywhere` at the right edge's middle | a good side button | a top-centre punch-hole lands there in landscape; it moved to where `pads` puts it |
| a frame of the autopilot on with the hold pad held | a state row 36 forbids | removed |
| a new program's `Hint` repeating that it is off | said twice | only the head says it |
| the badge as a numeral `2` at the cell's right end | in French, `fige la queue` runs to x 123 and the badge sat at x 101..119, on the word; found while folding row 38 | the genome page's pips, in the cell's top-right corner |

### 10.1 As built: phase 4-2, 2026-10-03

Every frame above was shot again from the build, in English and French at
1280x720 and 2400x1080. The build judged them, and a designer then reviewed all
of them before the merge. `badge_pips_*` became `editor_tail1_*` and
`editor_new_tail1_*`, which show the same pips on the real page.

**The review found two blockers, fixed before the merge:**

- **A focused library row showed nothing at a keyboard.** `↓` changed nothing on
  screen, and `Enter` then opened a program other than the one shown. Now a
  focused row underlines its name (2 px `SELECT`), and focus selects. `↑`/`↓`
  move the selection, and the inspector, `Explain` and the bright places follow
  the keyboard (§2.6).
- **One tap on `controls` brought the pause overlap back for good** (see the
  bottom edge, below). A tap left the button with hidden focus, and the emulated
  mouse left it hovered. Only focus a player can see keeps the pads up now.

**Six small ones were fixed in the same round:**

- a tap leaves no underline;
- `Enter` on a row's `›` opens it;
- the inspector's dash burst clears its word;
- a test's `Explain` gives its sentence, not a bare `level`;
- the replay line is placed on its caption (below);
- §2.4's hint, when a hold and a never come from one rule.

**Kept as the build made them:**

- **The places indicator is hidden while the library is empty.** `0 of 8` means
  nothing before a first program, and the indicator arrives with it.
- **The on glyph's ink is `LIT` 0.35**, lowered from 0.85 because §9.3's glance
  asked for it. On, the icon is 53/62 against the figure's 58/74. On and off still
  differ in light and in shape at device pixels.
- **The replay line is centred on its caption**, then slid left only as far as it
  must go to stay 16 px clear of `pause`. Under the caption alone it had about
  224 px, and most lines would have been cut.
- **`R` toggles while a sheet's button has focus.** A focused text field takes
  the key first, so a name can still have an `r` in it.
- **A gamepad stick's motion past its 0.5 dead zone counts as a new press.**
  Gamepads are not a target.
- **Default names are kept as a kind and a number** (`automation.md` §9.1), so
  `program 2` is said in the language of the moment, as « programme 2 ».

**The pause screen's bottom edge** (`automation.md` §5.5). On the genome page,
the dimmed pads now show only while the controls chooser is in use: while it
has a keyboard's focus, or for 4 s after it is cycled. They never show on the
programs page.

Hiding them on both pages would have been one line. They stay while choosing
because they are the chooser's only explanation (`controls.md` §5.1): without
them, `anywhere`, `stick` and `pads` are bare words until you resume. At rest
the edge is clear at both shapes in both languages.

The frames: `edge_before_*`, which is dev; `edge_after_*`, at rest;
`edge_after_chooser_*`, while choosing; and `edge_programs_*`.

---

## 11. Left open

1. **Undo** after `remove` or `delete`.
2. **An instinct switched off on its own**, as Final Fantasy XII's gambits had.
   Programs half answer it: put the instinct in a program of its own and switch
   that program off.
3. **The replay's line** (§7.3) is not rendered.
4. **Keyboard focus and mouse hover** are specified but not rendered.
5. **Cutouts.** The autopilot has the gear's exposure in a top corner
   (`settings.md` §12). Nothing here reads `DisplayServer.get_display_safe_area()`.
6. **Under `anywhere`**, whether the hold pad catches a steering thumb is a
   playtest question. **Watch for** a tail that stops when a player meant to
   steer.

**No launcher problem found.**

---

## 12. Owner's calls

**All answered; nothing is open for the owner.** The screen's two calls were asked
in `automation.md` §17.2, in one table with the mechanics', and answered on
2026-10-02 as recommended:

- **row 41**: an `anywhere` player holds the tail still with a pad, drawn only once
  the tail reaches level 2, where `pads` puts it (§6.1);
- **row 42**: the words as listed (§8).

Rows 28, 31, 32 and 35 were the screen's in the first table (§17.1 there). The
pad's place, and why it is held rather than tapped, are argued in §6.1. In French,
`pilote automatique` appears in sentences only; the icon carries no word.
