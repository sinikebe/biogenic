# Your instincts, on screen

Pack 4's block screen. The owner, 2026-09-29:

> And while we're at it, we could propose to players a screen where they can use
> the same logic blocks to automate their cell ! Offering a new gameplay type.
> Both should use the same logic system.

`automation.md` owns the rules of the game: what your instincts read and do, when
they act, the switch, the save, the wire. **This document owns the screen**:
where it lives, the eight rows, picking and setting, adding, removing and
reordering, live feedback on the page and in play, both shapes, touch, mouse and
keyboard, and French. Where the two meet, `automation.md` §8 says what must be
seen and this says how. The rules' text, ladders and vocabulary are
`behaviour.md` §3's, unchanged.

**Status: designed; a throwaway mock was built over the real paused run in a
scratch worktree, photographed at 1280x720 and 2400x1080 in English and French,
judged, and changed until it held (§10). Nothing is built.** The mock used the
real `rulebook.gd` to parse `drop.gd`'s `FOUNDERS`, the real fonts, scrim,
membrane and gear. Code references are to `dev` at `df45f82`.

**Put to the owner on 2026-10-02**, in one table with the mechanics' calls:
`automation.md` §17, rows 27 to 35 (§12).

---

## 0. Decided, in one place

1. **A second page of the pause screen, `instincts`, beside the genome** (§1).
   A chip under the gear switches between the two. Single player pauses under
   it; in a pond the water moves and your instincts drive while you edit, and
   the page says so.
2. **Rows on the left, tools on the right** (§2). Eight rows of 48 px chips. The
   right-hand column is one stack under the gear: the page chip, the inspector,
   then `resume`. `Explain`, `Hint` and `Act` sit under the rows, as under the
   genome figure.
3. **A row reads as a sentence with a nerve in it** (§3): the sense chip, its
   tests, an arc, then the action in a column of its own. The arc lights when
   the instinct acts. It ends in a T-bar (⊣, biology's mark for inhibition)
   when an instinct above holds it back.
4. **Tap a chip to edit it; the inspector offers only what fits** (§4). A choice
   applies at once. **Drag any chip to move its instinct**; `Shift`+`↑`/`↓` does
   the same at a keyboard. **No keyboard is ever needed**: a test's value sits on
   a ladder, a rail with one rung per step, with what your sense reports now
   marked on it.
5. **The empty page** offers `+ add an instinct` and `copy a water cell's
   instincts`, and lists what your body can sense and do (§5).
6. **In play, the organ that is deciding draws a thread to the nucleus**, in
   both views (§6.2). The senses your instincts listen to show the thread's root
   while they have your cell. A resting tail is drawn still. **No number goes in
   the water** (row 32).
7. **French fits everywhere** (§7). The tightest gap is 62 px, on the widest
   French row at 1280.
8. **Content only**: scenes, GDScript and words. No `binary_version` bump, no
   `project.godot`, no `addons/` or `ci/`.

---

## 1. Where it lives

### 1.1 Three candidates

| | how it plays | what it costs |
|---|---|---|
| **a page of the pause screen, beside the genome** | pause, tap `instincts`, edit, tap `resume`, let go and watch. Alone, the water waits while you think. In a pond nothing pauses; the open menu already silences your hand (`steering_off`), so your instincts drive while you edit, which is the feature working | the loop is edit, resume, let go, so you see the result after the menu rather than under it |
| an overlay over the water that never pauses | watch your instincts act while you edit | on a phone eight rows cover the water you would be watching; it needs a second control in the water beside the pause tap (`diegetic-hud.md` §3, `settings.md` §1.1: the water carries one); alone, you can be eaten mid-edit |
| a screen before the run, beside the view chooser | plan once, then play | you cannot fix an instinct when you see it fail, and row 31 recommends editing at any time |

**The pause page is recommended** (row 31). It is where you already edit your cell,
it is one tap from the water by the pause tap, and it costs the water nothing.
Placing a gene without pausing (`dna-body.md` §8) is a one-gesture act; writing
an instinct is a decision of several taps, which is what pause is for.

### 1.2 The page chip

`instincts ›` on the genome page and `genome ›` on the instincts page, **under
the gear**, right-aligned with it. The chip never moves when it is tapped.

- **Not left of the gear.** That is where the world chip sits on other screens,
  but on the pause screen at 1280 a tray of five waiting genes reaches x 1045 at
  y 88..136 and met the chip's corner. Rendered (`genome_chip_five_waiting`,
  and the iteration frame that failed).
- **Never in the top-left corner.** The pause tap lives there in play, and one
  phone touch arrives twice, as itself and as an emulated click
  (`gene-lines-and-the-pause-target.md` §4.2). Once the first copy opens pause,
  the second copy lands on whatever is under it. **Rule for every pause page: no
  control in x 48..112, y 48..112.** Only inert text may sit there, such as this
  page's title at 1280.

**Which page opens.** Pause opens on the genome page whenever a gene is waiting,
because a waiting gene has a clock and your instincts do not. Otherwise it opens
on the page you left in this run (the genome page at a run's start).

**Back and `Esc`** do what they do today on either page: they close the
corner's top layer first, then resume (`settings.md` §1.3). A drag in flight is
cancelled, as on the genome page (`moving-a-gene.md` §9).

**A division or a death closes the menu**, as today in a pond (shared-pond.md
§1.7). An instinct half-built at that moment is dropped (§4.5). In a pond that
is now likelier, because your instincts can feed your cell to 40 while you edit.

---

## 2. The page

```
1280 x 720 (canvas)                                                   x 1176..1232
 y 48..104   instincts  [● on]  what your cell does by itself when you let go    [⚙]
 y 116..172                                                           [ genome › ]
 y 120..574  ┌ 8 rows, 48 tall, 10 apart, x 48..904 ┐   y 184..604  ┌ inspector  ┐
             │ [meal][under 5 s] ───────────→ [rest]│               │ x 936..1232│
             │ ...                                   │               └────────────┘
 y 586..664  Explain / Hint / Act, centred on the rows  y 616..672    [  resume  ]
```

### 2.1 The node tree

```
Hud/Pause                       Control (existing)
├─ Scrim, Center                existing; Center is the genome page, hidden while the instincts page shows
├─ Instincts                    Control, full rect, mouse IGNORE, hidden        NEW
│  ├─ Head                      HBoxContainer, separation 16, IGNORE; position (rows_x, 48), size (rows_w, 56)
│  │  ├─ Title                  Label 16 px  Color(0.855, 0.953, 0.933, 0.80)  "instincts"
│  │  ├─ Switch                 Control, FOCUS_ALL, mouse STOP, min (max(word + 32, 72), 48)   §3.4
│  │  └─ Note                   Label 15 px, CAPTION_TINT Color(0.855, 0.953, 0.933, 0.45), or WARN §6.1
│  ├─ Rows                      VBoxContainer, separation 10, IGNORE; position (rows_x, 120), width rows_w
│  │  └─ Row0..Row7             Control, rows_w x 48, IGNORE: lays its chips out in code (§3.1)
│  │     ├─ Sense               Control input_w x 48, STOP, FOCUS_ALL, drag forwarding
│  │     ├─ Test0..Test2        Control w x 48, STOP, FOCUS_ALL, drag forwarding
│  │     ├─ AddTest             Control 48 x 48, STOP; on the selected row only
│  │     ├─ Arc                 Control, IGNORE, drawn
│  │     └─ Action              Control output_w x 48, STOP, FOCUS_ALL, drag forwarding
│  ├─ Lines                     VBoxContainer, separation 6, IGNORE; position (rows_x, 586), width rows_w
│  │  ├─ Explain                HBoxContainer, min (0, 26), centred: Name Label 15 px (hue) + Says Label 15 px EXPLAIN_TINT
│  │  ├─ Hint                   Label 14 px Color(0.855, 0.953, 0.933, 0.38), centred, min (0, 20)
│  │  └─ Act                    Label 14 px Color(0.588, 1.0, 0.859, 0.50), centred, min (0, 20)
│  └─ Tools                     VBoxContainer, separation 12, IGNORE; anchors (1,0)-(1,0),
│     │                         offset_left -344, offset_right -48, offset_top 184, offset_bottom 672
│     ├─ Inspector              PanelContainer, min (296, 420); content margins 16 / 14            §4.1
│     └─ Resume                 Button 296 x 56, the genome page's resume style; same handler
├─ PageChip                     Button, anchors (1,0)-(1,0), offset_right -48, offset_top 116,
│                               offset_bottom 172, grow_horizontal BEGIN, FOCUS_ALL                NEW
└─ Corner                       existing, still the last child
```

**`rows_w = min(W - 424, 900)`** and **`rows_x = 48 + floor((W - 424 - rows_w) /
2)`**, where `W` is the canvas width and 424 is the two margins (96), the tools
column (296) and the gap (32). `Instincts` lays out `Head`, `Rows` and `Lines`
from these in code, on resize, as the genome page lays out its figure. The tools
column hangs from the right margin, so the page chip, the inspector and `resume`
stay one stack at every width.

### 2.2 Both shapes, measured off the renders

| | 1280x720 | 2400x1080 (canvas 1600x720) |
|---|---|---|
| rows | x 48..904, 856 wide | x 186..1086, 900 wide |
| tools column | x 936..1232 | x 1256..1552 |
| page chip | x 1104..1232 (EN `genome`) | x 1424..1552 |
| room left for the arc on the widest row | English 180 px, **French 62 px** | English 224, French 106 |
| inspector, tallest content | 380 of 420 px rendered (the empty page in French); about 392 computed for a body with all five senses | the same |

**Reflow on a phone: none vertically.** The canvas is 720 tall at every shape.
Horizontally the rows grow to 900 and then centre in the room left of the tools
column. A taller-than-16:9 screen (a 4:3 tablet) only adds height below `resume`.

**The controls preview** (`controls.md` §5.1) is drawn behind the scrim on the
genome page only, where the scheme is chosen. On the instincts page, `Hud/Controls`
is hidden, so `resume` and the bottom lines never sit on a pad's ghost.

---

## 3. A row

### 3.1 Its chips

| part | geometry | draws |
|---|---|---|
| **sense** | `input_w` = the widest sense word at 15 px + 30 + 24 (EN 111, FR 116), 48 tall, at x 0 | the organ that reports it, `Cilia.draw_tile_organ(gene, 1, (22, 31), alpha, 0.55)`; the cell's own mark for the body's and the metabolism's parts (§3.3); nothing for `always`. Then the word, 15 px, at x 42 |
| **test**, up to one per value the sense carries | the phrase at 14 px + 24, at least 48, 6 apart | the phrase, centred (§7) |
| **add a test** | 48 x 48 | dashed 1 px `Color(0.855, 0.953, 0.933, 0.26)`, dash 4, and a 12 px plus at 0.42. **On the selected row only**, while the sense has an untested value |
| **arc** | from the last chip's end + 10 to the action's x − 8, at y 24 | §3.2 |
| **action** | `output_w` = the widest action word at 15 px, `push · full` included, + 30 + 24 (EN 142, FR 164), right-aligned to the row's end | the organ that does it (turns: `cirrus`; swim: `flagellum`; dash: `myoneme`; push: `axoneme`; rest: the cell's own mark), then the word. `push` shows its option: `push · half` |

Senses and actions sit in aligned columns, so *what does my cell do* is one
glance down the right edge. Every sense and action chip wears its organ's hue
(`Cilia.hue()`, never a copy of the table), so a rule's colours are the same
colours as that organ on your body and on the genome page.

### 3.2 Its states

`automation.md` §8.2 item 3 names them; `Rulebook.choose`'s per-rule state
supplies them.

| state | sense | tests | arc | action | Hint, when the row is selected |
|---|---|---|---|---|---|
| **acting** | lit | lit | 2 px `LIT` 0.85, chevron head 2 px 0.95 | lit | `acting now` |
| **held back**: an instinct above took its trigger | lit | lit | 1.6 px `LIT` 0.45, ending in a **T-bar** 2.4 x 16 px at 0.80 | at rest | `held back: an instinct above already steers` (swims, pushes, dashes, acts) |
| **reported, no report passed** | edge only, at its hue 0.60 | at rest | 1.2 px `PALE` 0.10, head 1.5 px 0.28 | at rest | `waiting: your ping reports, the test is not met` |
| **quiet**: its sense reported nothing | at rest | at rest | the same | at rest | `waiting: your ping reports nothing` |
| **asleep**: an organ it needs is not worn | everything at x 0.42 | | | | `asleep: your body does not wear push` |
| **unreadable**: a name from a later pack | one wide chip, its saved line at 0.42 | | | | `this version cannot read this instinct · it is kept` |
| **half-built** (§4.5) | as chosen; blanks dashed | | none | dashed blank | `pick what it does · until then it does nothing` |
| **switched off** | at rest | at rest | waiting style | at rest | `your instincts are off` |

An acting row also gets an underlay, radius 10, `Color(0.49, 1.0, 0.831, 0.045)`,
6 px wider than the row each side and 4 px taller, so it reads from across the
room. **Every state differs by shape as well as light**: fill against edge, a
line and a head against a T-bar, a full row against a fade. Nothing depends on
hue, which `genes-and-cilia.md` §4.4's colour-blind rule requires. State changes
cross-fade over 0.12 s, so a pond's 7.5 ticks a second never flicker.

### 3.3 Colours and boxes

`FILL` is `Color(0.063, 0.141, 0.125)`, `PALE` `Color(0.855, 0.953, 0.933)`,
`LIT` `Color(0.49, 1.0, 0.831)`, `TEAL` `Color(0.12, 0.70, 0.58)`, `SELECT`
`Color(0.588, 1.0, 0.859, 0.85)` (the screen's `FOCUS_TINT`). Radius 6, 1 px
edges, unless said.

| chip | fill | edge | word |
|---|---|---|---|
| sense or action, at rest | `FILL` 0.55 | its hue 0.38 | `PALE` 0.80 |
| lit | `Color(FILL, 0.70).lerp(Color(hue, 0.70), 0.16)` | its hue 0.85 | `PALE` 0.95 |
| selected | `Color(0.086, 0.204, 0.176, 0.85)` | **2 px** `SELECT` | `PALE` 0.95 |
| test, at rest / lit | `FILL` 0.40 / 0.62 | `PALE` 0.16 / `LIT` 0.55 | 0.78 / 0.95 |
| hovered (mouse) | as its state | its edge + 0.25, at most 0.95 | as its state |
| focused (keys) | as its state | as its state | plus the strand's underline: inset 14, y 44, 2 px `SELECT` |

The hue of a body or metabolism part is the cell's own, `Cilia.SELF_TINT`. Its
mark is a small egg, 13 px tall (fill `SELF_TINT` 0.30, rim 1.4 px at 0.95).
**Not a ring and not a dot**: in this game a ring is a carried copy or a held
gene, and a dot is a worn copy (`dna-body.md` §3.1). `always` has no mark and
`Color(0.42, 0.80, 0.72)` as its edge.

### 3.4 The head row

`instincts`, then the switch, then one line.

- **The switch** is the `numbers` switch's slab (`gene-stats.md`): 30 tall inside
  a 48 px target. On: fill `Color(0.086, 0.204, 0.176, 0.80)`, 2 px edge `TEAL`
  0.62, a filled dot r 4 `LIT` 0.95, word `on` at 14 px
  `Color(0.588, 1.0, 0.859, 0.80)`. Off: fill `FILL` 0.35, 1 px edge 0.22, no
  dot, word `off` at 0.50. It answers on the lift, inside it, once a frame,
  exactly as `_on_numbers_toggle_input` does. It is hidden while there are no
  instincts.
- **The line** says the most important true thing (§6.1).

### 3.5 Empty places

Under eight instincts, one slot is the **add row**: `+ add an instinct`, dashed
1.2 px `LIT` 0.40, text 15 px `Color(0.588, 1.0, 0.859, 0.70)` at x 40. **It sits
just above a trailing `always -> body.swim`, otherwise after the last instinct.**
A list starts as that one rule (`automation.md` §5), so the first instinct you
add goes above it, as that document intends. Slots below the add row are dashed
1 px `PALE` 0.09, dash 6: room, at about the ink `diegetic-hud.md` §1 gives
*there is room in you*.

---

## 4. Editing

### 4.1 Selection is editing, and the inspector

**A press selects the chip under it.** That is harmless and idempotent, so the
duplicate press of one touch changes nothing. The inspector, under the page chip,
then shows only what that chip can become:

| inspector part | geometry |
|---|---|
| panel | fill `FILL` 0.45, edge `TEAL` 0.26, radius 6, margins 16 / 14, `VBoxContainer` separation 8 |
| head, 28 tall | the organ (scale 0.55) and the word, 17 px, its hue toward `PALE` by 0.25. A test reads `echo · size`: two words joined by ` · `, a list and not a sentence, so it translates |
| choices | `GridContainer`, 2 columns, separation 8: cells **128 x 48** (glyph at (19, 24), word 14 px at x 36) |
| remove | 264 x 48, fill `FILL` 0.35, edge `TEAL` 0.22, 15 px `PALE` 0.70: `remove this test` on a test, `remove this instinct` on a sense or an action |

**A choice applies on the lift, inside it**, once a frame, and a cancelled touch
changes nothing: the numbers switch's rule, for the same doubled touch. The row
updates where it stands; nothing moves; there is no apply. The current choice
wears the selected box. On a mouse, hovering a chip puts its sentence on
`Explain` without selecting it, and leaving gives the selection's back
(`gene-lines-and-the-pause-target.md` §2).

**The page opens with something selected**, never nothing (the genome page's and
`choosing.md`'s rule): the sense of the first acting instinct, else of the first
instinct, else the add row.

### 4.2 Picking a sense or an action

- **Offered**: what the body and the metabolism declare, and every gene in your
  DNA (`automation.md` §3.1). **A gene your DNA carries and your body does not
  wear is offered, marked carried**: glyph at 0.40, word at 0.42, and the genome's
  own ring pip after it (r 3.4, 1.4 px, its hue 0.85). Choosing it makes an
  asleep instinct, which wakes in a daughter who wears the organ. Nothing is
  offered for a gene your DNA has never had.
- **Dimmed, x 0.35, and inert, when it cannot fit**: a sense with no bearing
  under `turn toward` or `turn away`, and those two turns under a sense with no
  bearing. Tapping one says why on `Hint`: `turn toward needs a sense that says
  where`.
- **Changing the sense** keeps the tests the new sense can carry, by value name,
  and drops the rest.
- **`push`** adds a row under the grid when current: `half` and `full`, two cells.

### 4.3 Setting a test, with no keyboard

`+` on the selected row adds a test. If the sense carries more than one untested
value, the inspector first asks `test what?` with one cell per value (3 across,
82 wide). The test starts as `below` the ladder's middle rung, index n / 2
rounded down (50 %, 8 s, 350 µm, 60°; a size: `smaller than my mouth`), and is
selected. **The value is fixed once chosen**: to test something
else, remove the test and add another. That keeps the editor three blocks tall:

1. **The comparison**, 2 x 2 cells of 128 x 48, in the kind's own words (§7):
   *below, above, rising, falling* for a level; *within, beyond, going away,
   closing in* for a distance.
2. **The step: a ladder.** A 6 px rail (fill `FILL` 0.85, edge `TEAL` 0.35,
   radius 3) with one 18 px tick per rung of the kind's ladder (`Rulebook.LADDERS`),
   evenly spaced, `LIT` 0.55 up to the rung in use and `PALE` 0.25 after it. A
   knob, **a rounded square, never a circle** (`controls.md` §4), 24 x 28,
   radius 6, fill `Color(0.086, 0.204, 0.176, 1)`, 2 px `SELECT` edge, on that
   rung. Its value in 15 px over the knob; the two ends in 12 px at 0.40. 264 x
   74, of which the rail's band is the 48 px target. A tap on the rail moves the
   knob to the nearest rung, a drag snaps rung to rung, and `←`/`→` step one.
   Rising and falling have no step and no ladder. A size has two cells instead:
   `my mouth` and `me`.
3. **What your sense reports now** (`automation.md` §8.2 item 4): a teal tick
   under the rail for each current report (an 8 px triangle, `LIT` 0.85),
   between the two rungs it falls between, and one line under it in 14 px
   `Color(0.588, 1.0, 0.859, 0.62)`: `now: one echo, 350 µm away`, `now: 62%`,
   `now: nothing`. Alone, the water waits, so these are the readings of the
   frame it stopped on, the same the dry run uses (§6.1).

`behaviour.md` §3.1's rungs are the only values on offer, so a value the
water's changes could not reach is never on screen, and a division's nudge
(`automation.md` §6) moves your value exactly one rung.

### 4.4 Removing

`remove this test` or `remove this instinct`, in the inspector, on the lift. No
confirmation: an instinct is a few taps to rebuild, and nothing outside the list
is lost. The selection moves to the sense of whatever now holds that slot, or to
the add row. Undo is left open (§11).

### 4.5 Adding

**Tap the add row.** It becomes a half-built instinct where it stands, its sense
selected and the senses on offer. Pick one, and the selection moves to the
action; pick one, and the instinct is whole and runs from the next tick.

- **On an empty list, the first tap makes two rows**: the new one, then
  `always -> body.swim` under it, `automation.md` §5's starting list. `Hint`
  explains it once: `your tail beats whenever nothing above stops it`.
- **A half-built instinct never acts and is never saved** (`automation.md` §4).
  Leaving the page, a division or a death drops it, and `Hint` says so while it
  is half-built.
- **At eight** there is no add row.

**Copy a water cell's instincts** loads `drop.gd`'s `FOUNDERS`. It is offered
only on an empty list, so it never overwrites one. Rules for organs you do not
wear arrive asleep and show you what a sense would add. Its second rule rests
your cell while it is fed (`automation.md` §5), and the rows say so plainly.

### 4.6 Reordering

**Drag any chip of an instinct** to move the whole instinct: Godot's own drag
(`set_drag_forwarding` on every chip, `moving-a-gene.md` §3.2), which works for
touch through the emulated mouse.

| while dragging | draws |
|---|---|
| the instinct in the air | a pill: its sense chip, a 36 px arrow, its action chip, both lit, on a shadow (radius 10, `Color(0, 0, 0, 0.40)`), riding **`DRAG_LIFT` 34 px above the pointer** (`moving-a-gene.md` §3.3) |
| where it came from | the row's outline only, dashed 1.2 px `PALE` 0.30 |
| where it would land | a 2.5 px `LIT` 0.95 line in the 10 px gap nearest the pointer, from x −10 to `rows_w` + 10, a dot r 4.5 at each end |
| `Act` | `let go to move this instinct here`, or `let go to leave it where it is` over its own place |

Rows never move during a drag; they reorder on the drop. A drop outside the rows
does nothing. **The order is what decides which instinct wins**, so this is the
one gesture that changes behaviour without changing a word; `Act` teaches it on
the idle page: `tap a block to change it · drag an instinct up or down to change
which wins`.

### 4.7 Touch, mouse, keys

| | touch | mouse | keys |
|---|---|---|---|
| select a chip | tap | click | arrows: `←`/`→` along a row, `↑`/`↓` to the same place in the next row; `Enter`/`Space` selects |
| pick a choice | tap | click | `Tab` or `→` from the action into the inspector; arrows; `Enter` |
| set a step | tap or drag the rail | the same | `←`/`→` on the ladder |
| add | tap the add row, or `+` | click | `Enter` on them |
| remove | tap `remove` | click | `Enter` on it |
| move an instinct | drag a chip | drag | **`Shift`+`↑`/`↓`** on a focused chip, read raw as the genome's `Shift`+arrow is (a content pack cannot add an `InputMap` action) |
| switch, page, resume | tap | click | `Tab`; `Enter` |

Every target is at least 48 canvas px: 72 device px at 2400x1080. Rows are 10
apart and chips 6. A mis-tap only selects, and selecting is free.

---

## 5. The empty page

Rendered: `instincts_empty_en_1280x720`, `instincts_empty_fr_2400x1080`.

- **Row 1, the invitation**: `+ add an instinct`, fill `FILL` 0.55, dashed 1.4 px
  `LIT` 0.55, text 16 px `Color(0.588, 1.0, 0.859, 0.85)`, the full row wide.
- **Row 2**: `copy a water cell's instincts`, a quiet slab as wide as its words
  plus 40 (fill `FILL` 0.40, edge `TEAL` 0.30, 15 px at 0.78).
- **Rows 3 to 8**: the empty places, so eight is on screen from the first look.
- **The inspector** heads `no instincts yet` and explains, wrapped, 14 px
  `EXPLAIN_TINT`: *an instinct is something your cell does by itself when you
  let go: when a sense reports something, it acts. the first instinct that fits,
  from the top, wins.* Under it, `what you can sense` and `what you can do`
  (14 px, caption tint), each a flow of the words in their organs' hues
  (`hue.lerp(PALE, 0.45)` at 0.92) with their marks, h 14 / v 2 apart. **This
  is the palette before you pick**: your vocabulary, read off your own genes. A
  new gene's words appear here the moment you carry it.
- `Act`: `tap + to give your cell its first instinct`. No switch in the head.

---

## 6. Live feedback

### 6.1 On the page

**Each row shows its state** (§3.2), from the per-rule state `automation.md`
§13 adds to `Rulebook.choose`.

- **In a pond** the open menu silences your hand, so your instincts are read at
  every tick and the rows update with them, 7.5 times a second.
- **Alone, the water waits**, and there may be no last tick to show: while your
  hand held the cell, your instincts were not read at all (`automation.md`
  §2.4). So the page shows **a dry run: what your instincts would do now if you
  let go**. It reads the last frame's reports, which your membrane took whoever
  had the cell, acts on nothing and writes no memory. It runs when the page
  opens and after every edit, so changing 30 % to 50 % shows at once whether
  that instinct would act. A rising or falling test with no tick before it to
  compare with reads as not met, which is true.
- **Fallback**, if the dry run proves fiddly: rows drawn at rest until the water
  moves. **Watch for:** a dry run that advances the rules' memory would change
  what they do after resume.

**The head's line**, in this order of priority:

| when | the line, 15 px | tint |
|---|---|---|
| a pond, instincts on and present | `the water is still moving · your instincts have your cell` | `Color(0.855, 0.953, 0.933, 0.82)`, the genome page's `Warn` |
| a pond otherwise | `the water is still moving · you can still be eaten` (exists) | the same |
| no instinct you wear can swim (`automation.md` §8.2 item 5) | `nothing here swims: when you let go, your cell drifts, its tail still` | the same |
| switched off | `off: letting go does what it always did` | caption |
| otherwise | `what your cell does by itself when you let go` | caption |

### 6.2 In play, in both views: the organ that is deciding

`automation.md` §8.1 asks for three things: who has your cell, which instinct
acts, and a resting tail. This game's HUD is the organism (`diegetic-hud.md` §1:
no panel, no number, every state a mark on the body, one routine for both
views). So all three are drawn on the body, by `cilia.gd` for the player's own
cell only, as `eye` and `offer` are.

| mark | geometry | when |
|---|---|---|
| **the thread** | a bowed line (bow 0.18 of its length) from the organ's pigment seat (`r * PIGMENT_SEAT` on its arc's middle) to the edge of the nucleus's inner disc (`at - fwd * r * NUCLEUS_BACK`, then `r * NUCLEUS_INNER` toward the seat). Width 2.0 x `unit`, the organ's hue at **0.62** x fade. Drawn after the nucleus, before the pigments | an instinct whose sense is that organ won a trigger on the last tick |
| **its root** | the first **32 %** of the same line, at **0.30** | your instincts have your cell, and some instinct of yours reads that organ: *listening* |
| **a still tail** | the flagellum's strokes drawn with their own clock stopped | your instincts rest the tail (`automation.md` §3.3) |

Fade in 0.15 s, fade out 0.30 s. **Touching takes everything away on that
frame**: no thread, no root, the tail on its clock. That is *you have the cell*.
The roots return at the tick your instincts take back. In point of view the
thread is drawn on the soma figure, in full vision on your cell, at their own
scales. The replay's `what you felt` pane draws it from `Delta.ACTS`.

- **Why a thread to the nucleus.** A sense driving the cell is a sense wired to
  its centre: the reflex arc of every textbook figure, drawn once. The thread
  shares its organ's hue with that organ's signal on the membrane. A violet echo
  arc in the water and a violet thread from the ping is the sentence *my ping
  heard that, and that is what turned me*.
- **Not a ring, a halo or a flare.** A ring round an organ is the held-gene
  vocabulary, and a brightening pigment is a level arriving (`beam-levels.md`
  §8.5). A first build put a ring on the pigment and it was taken off.
- **What it does not show.** An instinct on `hunger`, `meal`, `hit` or `always`
  has no organ to light. Its effect is the motion itself: a stop, a still tail, a
  tumble. Its place in the list, 1 to 8, which `automation.md` §8.1 asks for, is
  not drawn in the water (row 32). It is on the page and in the replay.
- **It must lose to the signals** (`diegetic-hud.md` §4). Starting value 0.62.
  The build measures it (§9.3); it was not measured here, by the owner's rule.

Rendered: `play_thread_pov_*`, `play_thread_fv_*` (+ `_zoom`). The ping acts,
and the beam and the nose listen.

---

## 7. Words, and their room

**The names are the owner's** (row 35). This is the recommended set. The page's own
name follows row 34, which recommends **instincts**: these pass
to your daughters and evolve, and *always swim* is an instinct but not a reflex.
French: the game's register, lowercase, `vous`.

| | English | French | room |
|---|---|---|---|
| senses | always, hit, hunger, **meal** (seconds since you ate), echo, beam, smell, shadow, touch | toujours, coup, faim, repas, écho, rayon, odeur, ombre, contact | 72 px at 15 |
| values | bearing, distance, size, level, closeness, strength, seconds | angle, distance, taille, niveau, proximité, force, secondes | 70 px at 14 |
| actions | turn toward, turn away, **tumble**, swim, rest, dash, push; half, full | tourne vers, se détourne, culbute, nage, repos, bond, pousse; moitié, à fond | 84 px at 14 (cells), 112 px at 15 with `push · full` |
| a level | below %s, above %s, rising, falling | moins de %s, plus de %s, monte, baisse | 140 at 14 |
| seconds | under %s, over %s, rising, falling | moins de %s, plus de %s, monte, baisse | 140 |
| a distance | within %s, beyond %s, going away, closing in | à moins de %s, à plus de %s, s'éloigne, s'approche | 140 |
| a bearing | within %s, beyond %s, moving aside, moving ahead | à moins de %s, à plus de %s, s'écarte, se recentre | 140 |
| a size | smaller than %s, bigger than %s, growing, shrinking; my mouth, me | plus petit que %s, plus grand que %s, grossit, rapetisse; ma bouche, moi | 184 |
| units | `30%`, `5 s`, `220 µm`, `30°` | `30 %`, `5 s`, `220 µm`, `30°` | |

The comparison's words alone (`within`, `smaller than`) are separate messages
from the chip's templates (`within %s`), so a translator may move the `%s`.
*Tumble* is the real name: *E. coli* runs and tumbles (`behaviour.md` §2.2).
*Meal* says what `fed` counts.

**Sentences** (each one message, `TRANSLATORS:` notes as the README asks):
the head's lines (§6.1); `add an instinct`, `copy a water cell's instincts`, `no
instincts yet`, the empty page's explanation, `what you can sense`, `what you can
do`, `test what?`, `remove this test`, `remove this instinct`; the `Hint`
states (§3.2), one per trigger word for *held back*; `now: %s`; the `Act` lines
(§4); and one `Explain` sentence for every sense, value and action. The mock's
are in its tables. Examples: `echo · what your ping hears back: where it came
from, how far, and how big it rings.` and `tumble · a quarter to a half turn, to
a random side.`

**Words live beside the declarations** (`automation.md` §13.1), so a new gene
brings its words, not a screen. A part with no words yet shows its declared name
rather than nothing.

**Room the lint must hold** (README, "Room"; `tools/i18n_pot.gd`):

- **a built row**, the new `ROW_ROOM`: for every sense, its widest test on each
  value it carries, plus the widest action, must leave **≥ 40 px of arc in 856**.
  This is the 1280 row (`input_w + tests + 6 each + 40 + output_w ≤ 856`). French
  today: 62, the echo with three tests;
- **the page chip's word**: ≤ 94 px at 17 px, or it reaches a tray of four
  waiting genes at 1280;
- **the head's line**: ≤ 676 px at 15 px (French no-swim today: about 570);
- **`Explain`**: ≤ 856 at 15 (French longest today, *taille*: about 630).

---

## 8. If row 27 is answered (b) or (c)

**(b), a way to play chosen before a run.** The view chooser gains the choice.
The switch leaves the head, because the run decides. An empty list cannot start
a rules run, so the empty page's `copy a water cell's instincts` becomes the way
in. The in-play mark carries the whole show, so it would want to be louder: the
acting instinct named in the water, which row 32's second option already drafts. The
page is the same.

**(c), a switch in the run.** The switch is the mechanic, so it has to be in
reach while playing: either a second control in the water beside the pause tap
(the cost `gene-lines-and-the-pause-target.md` §4 measured once), or the switch
on this page and a trip through pause each time. The roots (§6.2) would then
also mean *switched on*, drawn even while nothing acts. The page is the same.

---

## 9. What the build needs

### 9.1 What this screen assumes of the mechanics

All of these are `automation.md`'s and agree with it: (a), with `HAND_LETS_GO` 0.5 s;
no instincts at the start; the switch; at most eight; a list starting as
`always -> body.swim`; carried genes offered and asleep; edits at the next tick;
the per-rule state out of `choose`; the open pond menu silencing the hand. **Two
are the screen's own:** the dry run while the water waits, on opening and after every edit (§6.1),
and a half-built instinct being the page's alone, never the list's.

### 9.2 Files

| file | change |
|---|---|
| `game/normal/normal_mode.tscn` | `Hud/Pause/Instincts` and `Hud/Pause/PageChip` (§2.1) |
| `game/normal/instincts_page.gd` **new** | the page: layout from `W`, the rows and their states, the inspector, the ladder, the drag, the keys, the words said again on `NOTIFICATION_TRANSLATION_CHANGED` (deferred: `settings.md` §3.3). It reads a vocabulary and a list; it does no rule arithmetic |
| `game/normal/normal_mode.gd` | the page switch and which page opens (§1.2); `Hud/Controls` hidden on this page; resume, Back and `Esc` from it |
| `game/vision/cilia.gd` | `draw_cell(..., instincts := [])`: per organ, `{"gene", "lit"}`, the thread or its root; a still flagellum. Player only |
| `game/perception/soma.gd`, `game/vision/vision.gd`, the replay's panes | pass both through |
| `game/normal/genome.gd`, `cell.gd`, `metabolism.gd` | the words tables (`automation.md` §13.1); the rulebook's own words with the page |
| `game/i18n/biogenic.pot`, `fr.po` | every word above |
| `tools/i18n_pot.gd` | `ROW_ROOM`, built from the vocabulary in each language (§7) |
| `tools/drive.gd` | `--page=instincts`, and selection and drag poses on top of `--own-rules=` (`automation.md` §18.1), so every frame in §10 can be shot from the real build |

### 9.3 What the build checks

- **Every frame in §10, from the real build**, at both shapes, English and French,
  and judged. Then a keyboard-only pass and a mouse-hover pass, which the mock
  did not render.
- **The pause-tap corner**: a tap at (76, 76) that opens pause, its emulated
  twin included, changes nothing on either page.
- **Drag** on the touch path (`--press`/`--slide`) and the mouse path; `Esc`
  and Android Back mid-drag cancel it, as on the genome page.
- **The lint**: `ROW_ROOM` and the rooms of §7; then `--lint-all`.
- **The thread loses to the signals**: `diegetic-hud.md` §4's glance test, the
  thread against a beam return and a taste band in one seeded frame, three
  renders diffed to 0 pixels first (`CLAUDE.md`). If it ties, lower 0.62, as
  `FADE_PENDING` was lowered there.

---

## 10. Rendered and judged

From the throwaway mock over a real paused run, `--rendering-driver opengl3
--fixed-fps 60 --seed=7`. The shots went to the owner with this spec and are not
kept in the repository: the build shoots every frame again from the real build
(§9.3).

| frame | judgement |
|---|---|
| `instincts_founders_{en,fr}_{1280x720,2400x1080}` | passes. The seven founders plus the widest French row (an echo with three tests). Two rows act, one is held back, one is asleep. The size test is selected with its editor and `now` line |
| `instincts_ladder_fr_1280x720` | passes. A distance on its rail, the knob at 1,450 µm, the echo's tick at 350 |
| `instincts_input_en_1280x720` | passes. The senses on offer under `turn away`: four dimmed for having no bearing, `shadow` carried with its ring pip |
| `instincts_output_fr_1280x720` | passes. `se détourne` fits a 128 px cell beside its glyph |
| `instincts_drag_fr_1280x720`, `instincts_drag_en_2400x1080` | passes. The pill rides above the finger, the drop line is clear, the source is hollow |
| `instincts_empty_en_1280x720`, `instincts_empty_fr_2400x1080` | passes. The invitation, the copy, eight places, the vocabulary |
| `instincts_pond_fr_1280x720`, `instincts_noswim_fr_1280x720` | passes. The head's line warns; the French no-swim line ends about 100 px short of the row's end |
| `genome_chip_five_waiting_en_1280x720`, `genome_chip_fr_2400x1080` | passes. The chip under the gear clears a tray of five by about 60 px |
| `play_thread_{pov,fv}_{1280x720,2400x1080}` and zooms | passes. Quiet in point of view and a detail in full vision, which is `diegetic-hud.md` §4's own finding for small body marks |

**What judging changed** (frames in `shots/iterations/`):

| first version | what it looked like | now |
|---|---|---|
| every input lit whenever its sense reported | most rows half-lit; the acting ones did not stand out | lit means acting or held back; *reported* is an edge at 0.60 |
| a `+` on every row that could take a test | dashed boxes everywhere | on the selected row only |
| the body's mark as a ring and a dot | a radio button | a small egg |
| inspector on the left, chip left of the gear | collided with a tray of five genes at 1280 | chip under the gear, tools column on the right |
| rows and tools centred as a pair at 1600 | the chip floated apart from the inspector | tools hung from the right margin |
| a short arrow before each action | short rules left a 600 px gap at 1600 | one arc from condition to action |
| the empty page's vocabulary as boxed chips | ran over `resume` | coloured words |
| explanations inside the inspector, the ladder as a 3 x 3 grid | `retirer ce test` fell out of its panel | `Explain` under the rows; the ladder a rail; the value picked at `+` |
| a full-width row as the drag preview | covered the drop line and poked out of the column | a sense → action pill |
| a ring round the deciding organ | the held-gene vocabulary | the thread alone, ending on the nucleus's disc |
| `reflexes` | `automation.md` argues `instincts` (row 34) | `instincts`, and every string with it |

---

## 11. Left open

1. **The choosing screen's change mark** (`automation.md` §6.3, phase 4-2). Not
   designed here, and it needs its own render: the choosing screen is the
   tightest layout in the game (`choosing.md` §3). Its constraints: compare the
   two lists, never ask which change was drawn; one line in the instincts' own
   words; nothing new without instincts.
2. **Undo** after `remove`. Not built; an instinct is a few taps.
3. **An instinct switched off on its own**, as Final Fantasy XII's gambits each
   had. Only the whole list has a switch, and the save has no place for one.
4. **The thread next to the held gene's thread.** Both are lines inside the body:
   one from a hollow vesicle out to the skin, one from a filled pigment in to the
   nucleus. Judged distinct; watch for players reading one as the other.
5. **The dry run after an edit** (§6.1), if it proves fiddly.
6. **Keyboard focus and mouse hover** are specified, not rendered.
7. **Punch-hole cameras**: the page chip has the gear's exposure (`settings.md`
   §12).

**No launcher problem found.** Nothing in this work touched or needed the
template.

---

## 12. Owner's calls

Asked with the mechanics' calls in one table, `automation.md` §17, numbered on
from `behaviour.md`'s row 26:

- **row 28**, what a new cell starts with, carries this page's copy of the
  water's seven (§5);
- **row 31**, when and where you edit, is this page's place (§1) with
  `automation.md`'s when;
- **row 32**, how you see in play which instinct acts (§6.2);
- **row 34**, the name of the whole, which every string here follows;
- **row 35**, the words (§7).

**Under the table.** Row 35's set is long, and the table in §7 is the whole of
it; a single word can change without touching the others. Row 28's copy is what
makes the water's own behaviour visible to a player at all. Pack 3 kept it
hidden (row 24), and a copy shows only the founders, never what a family
evolved, so row 24 stands. Row 32's second option answers `automation.md` §8.1's
"by its place, 1 to 8" literally; the recommendation answers it by organ,
because a place in a list is a number and this game's water carries none.
