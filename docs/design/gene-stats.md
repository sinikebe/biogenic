# Gene stats: the numbers behind every gene

The owner, 2026-09-29:

> We should see details of the stats in the gene description. Energy
> consumption, range when applicable, etc. Everything must be explained to
> players for those who wants to master the game, but not impose and overwhelm
> players willing to learn by playing, without numbers.

Earlier the same day: "focus on the energy consumption. We will deal with gene
stats later". This is the later. `energy.md` §5 is the hand-off it starts from.

**Status: designed, prototyped and photographed.** The prototype was a scratch
copy of the game outside the repository, on `a483fd7`. Every frame and every
measurement below comes from it, at 1280x720 and at 2400x1080. The builder
builds it for real and shoots §8 again.

> **Built, 2026-09-29** (PR #138), and §8 shot again on the build. §11's two
> calls are built with the recommended options, pending the owner's answer.
> What the build and its review changed is in dated notes: §3.3 (the dim),
> §5.1 (the bite line), §5.3 (a worn gene in hand), §8 (`S04`), §11 (the way
> back from call 2).

---

## 1. Decided, in one place

1. **Numbers are one switch, off by default and remembered.** It is a quiet
   `numbers` chip to the right of the gene's line on the pause screen. A player
   who never taps it gets today's screen to the pixel, plus that one word (§2).
2. **When it is on, every gene description carries its numbers.** Two lines go
   under the gene's line: first *what it does*, then *what it costs*. This
   happens on the pause screen, on the fork's cards and on the choosing screen.
   The odds line gains its percentage, and the caption gains the cell's size and
   its tank (§5).
3. **Nothing moves.** The figure, the tray, the caption, the gene's line and the
   switch stay where they are, in both states and at both shapes. The two lines
   below the numbers slide down into the empty canvas under the column (§3).
4. **The numbers are this body's own.** They come from the copies it wears (or
   the beam's level and way), its own `crista` and `vacuole`, and its own size.
   A gene it does not wear is shown at the copies it would be worn with, drawn
   dimmer (§5.3).
5. **Energy is in seconds.** These are `energy.md`'s seconds of rest, read
   against `a full tank: 36 s` in the caption. **Distance is in µm** (owner's
   call 1). Time is in seconds, and size is `× your size` (§4).
6. **Every number is computed from the game's constants.** It goes through one
   generic formatter and one table at the edge, so a rebalance updates the
   screen by itself (§6).

The playfield never shows a number; `diegetic-hud.md` §3 is untouched. It ships
as a content pack: GDScript, one scene and a `user://` key. There is no wire
change and no rule the referee copies (§9).

---

## 2. The switch

### 2.1 What it is

| | |
| --- | --- |
| node | `Genome/Lines/NumbersToggle`: a `Control` drawn by hand, like the tray's chips |
| hit rect | 96 x 48, anchored to the right edge of `Lines` (the genome column), offsets `(16, -11, 112, 37)`, so it is centred on the gene's line |
| where | canvas x 1084..1180, y 541..589 at 1280x720; x 1244..1340 at 2400x1080, which is 144 x 72 device px |
| slab | `Rect2(0, 9, 96, 30)`, radius 6: canvas y 550..580 |
| word | `numbers`, 14 px, centred in the slab |
| focus | `FOCUS_ALL`, with the chips' mark: a `FOCUS_TINT` underline, 2 px, inset 14, at y 44 |

| state | slab | border | word |
| --- | --- | --- | --- |
| off | `Color(0.063, 0.141, 0.125, 0.35)` | 1 px `Color(0.12, 0.70, 0.58, 0.22)` | `Color(0.588, 1.0, 0.859, 0.50)` |
| off, hovered or focused | alpha 0.55 | 1 px, alpha 0.40 | alpha 0.72 |
| **on** | `Color(0.086, 0.204, 0.176, 0.80)` | **2 px**, alpha 0.62 | alpha 0.80 |
| on, hovered or focused | the same | 2 px, alpha 0.78 | alpha 0.92 |

- **On differs from hovered by its 2 px border.** That is this screen's
  grammar for an armed tile (`genes-and-cilia.md` §5.2), so the difference is a
  shape and survives greyscale. The four states were rendered side by side
  (`T1`–`T4`) and separate in colour and in luminance.
- **The switch is teal** because on this column teal means *this responds*.

**Why it is here.** It sits beside the line it opens, because that is where a
player who wants more is already looking. The settings column is full: a
fourth 101 px panel would stretch it to 648 of the 720 px.

**Why it is a word.** A `+` beside a gene, on a screen about placing genes,
reads as *add a copy*.

**Why it is a switch rather than a gesture.** The owner's two audiences are two
kinds of player, not two moods. The one who wants mastery turns it on once and
reads numbers from then on. The one who never asks never sees one.

Two alternatives were rejected:

- **A long-press** cannot be found.
- **A second tap on a slot** already places the gene in hand.

### 2.2 How it answers

| | touch | mouse | keyboard |
| --- | --- | --- | --- |
| turn numbers on or off | tap it | click it | Tab to it, then Enter or Space; or press `N` anywhere on the pause screen |
| read a gene's numbers | tap its slot, or a waiting gene | hover, or click | arrows or Tab to a slot |

- **It answers on the lift, inside the chip, once a frame.** A key answers on
  the press. This is the fork chip's rule (`beam-levels.md` §8.3), and for the
  same reason: a touch arrives twice, once as itself and once as the click
  Godot emulates from it. A cancelled lift changes nothing. The prototype's tap
  (`S08`) turned numbers on exactly once.
- **It is remembered** in `RunState` under `[run] numbers`: a bool, default
  `false`, written on every toggle and read in `_ready()`, like
  `camera_locked`.
- **For the harness**, `--numbers=0|1` sets a new `numbers` var on the run
  before it enters the tree, as `--scheme=` does. A run pinned that way never
  writes the key, so one tapped frame cannot leak numbers into every later
  render.
- **Focus order:** the ring's last live slot, then `numbers`, then `light`, and
  back the same way. Its four arrow neighbours are itself, which is the ring's
  own rule that no arrow falls off. From `resume` with five live slots, that is
  seven Tabs (`S09`).
- **`N` is read raw** in `_unhandled_input` while the menu is open, pressed and
  not an echo, like the `Shift`+arrow moves: a content pack cannot add an
  action. Nothing else reads `N`.

### 2.3 What it leaves alone

Each of these was checked on the prototype.

- **Hover** still moves the lines under the figure, and the numbers move with
  them. They are recomputed in `_update_explain()` from the same `_reading()`.
- **Tap-to-arm.** The switch is a control of its own. Tapping it never arms,
  disarms or places anything; the gene in hand stays in hand, and an armed slot
  keeps its 300 ms guard and its timeout.
- **Drag.** It neither starts a drag nor takes a drop. A gene carried over it is
  over nothing (`ACT_CARRY`).
- **The fork's cards.** The switch stays, and the numbers follow the way that
  is hovered or armed (§5.2).
- **`Esc`, Android Back and placing from the water** (`dna-body.md` §8) are
  unchanged.

---

## 3. Layout

### 3.1 The tree

```
Hud/Pause/Center/Columns/Genome        VBoxContainer, unchanged
  Caption                              Label -- gains the cell's clause when on (§5.4)
  Waiting, Figure, Fork                unchanged
  Lines            Control             NEW  min (0, 82), MOUSE_FILTER_IGNORE
    Stack          VBoxContainer       NEW  top-wide anchors, grows down, separation 8, IGNORE
      Explain                          moved, unchanged
      Numbers      Control             NEW  min (0, 38), IGNORE, hidden while off
      Hint                             moved, unchanged
      Act                              moved, unchanged
    NumbersToggle  Control             NEW  §2.1
Hud/Choosing/Says                      VBoxContainer, unchanged
  Explain                              unchanged
  Numbers          Control             NEW  min (0, 38), IGNORE, hidden while off
  Hint                                 unchanged
```

**`Lines` is a plain `Control`, and that is the whole trick.**

- A plain `Control` does not take its minimum size from its children, so the
  column lays out as if the numbers did not exist. `Lines` is 82 tall: the
  three rows and their two gaps, exactly as today.
- Set `Lines.custom_minimum_size.y` in `_ready()` from `Stack`'s combined
  minimum with `Numbers` hidden. It then follows if a row ever changes height.
- When numbers are turned on, `Stack` grows past its parent into the empty
  canvas under the column. Nothing a finger is on moves. Only `Hint` and `Act`,
  which are text, slide down, by 46 px.

### 3.2 Measured

1280x720, with `--rects=`. At 2400x1080 every x is 160 further right and every
y is the same.

| | numbers off | numbers on |
| --- | --- | --- |
| `Columns` | x 212..1068, y 86..634 | the same |
| `Figure` | y 172..544 | the same |
| `Explain` | y 552..578 | the same |
| `Numbers` | hidden | y 586..624 |
| `Hint` / `Act` | y 586..606 / 614..634 | y 632..652 / 660..680 |
| `NumbersToggle` | x 1084..1180, y 541..589 | the same |
| **tightest:** five waiting genes, two tray rows (`S07`) | `Columns` y 58..662 | `Act` ends at y **708**, 12 px above the edge |

```
1280x720, numbers on, `swim` read                          column x 508 ... 1068      1084 .. 1180
y 552   [organ] flagellum · your tail beats harder, and more often                  [ numbers ]
y 586          swims about 111 µm a second · a beat every 1.2–2.5 s
y 605    beating burns 0.99 s a second, 1.8 s a beat · wearing it burns 0.36 s a second
y 632                 three copies · a daughter always wears it
y 660                          drag it to another slot
```

- **The widest numbers line is 538 px**: the costs of a three-copy `turn`. That
  is inside the 560 px column, so a line never widens the column. Centred, its
  ink ends 28 px short of the switch (`S13`).
- **With numbers off, the screen is today's screen to the pixel**, except the
  switch's own slab:
  - at 1280x720, 2,856 pixels differ, all inside canvas x 1084..1179,
    y 550..579;
  - at 2400x1080, 6,412 differ, all inside x 1244..1339;
  - on the choosing screen, 0 differ.
- **On the choosing screen**, `Says` keeps its top at 552 and its `Hint` moves
  down by 42 px: `Explain` 552..578, `Numbers` 582..620, `Hint` 624..643. That
  is clear of the membrane's contour at about y 690, at both shapes.
- **Full vision** (`S14`): the ghost still sits in the ring's empty cell
  (`dna-body.md` §7), because the figure has not moved.

### 3.3 How the two lines are drawn

| | value |
| --- | --- |
| lines | two, centred on the column, 14 px, pitch 19, first baseline 14 px into `Numbers` |
| words | `Color(0.855, 0.953, 0.933, 0.42)` |
| values | `Color(0.855, 0.953, 0.933, 0.70)`, for the number only; its unit keeps the words' tint |
| a gene this body does not wear | both colours × 0.85 (§5.3, and the note below: it was 0.62) |
| separator | ` · `, in the words' tint |
| drawn by | `Readout.draw()` in `Numbers`' `draw` signal, the way the cards draw their lines (`_draw_centred`) |

**The values are brighter than the words, so the eye finds them. They are not
brighter than the line they explain.** Peak glyph luminance at 1280x720
(Rec.709 on the 8-bit frame):

| text | peak |
| --- | --- |
| the gene's name, in its hue | 131 |
| the gene's sentence | 152 |
| the values | 170 |
| the verb line | 122 |
| the hint | 98 |
| the switch, on | 192 |

The first cut drew the values at alpha 0.88. They peaked at 211, louder than
the sentence they explain, which put the details above the headline. At 0.70
they read as the details of that sentence.

> **A gene this body does not wear is × 0.85, not × 0.62** (the build's
> review, 2026-09-29). The table above measured the full register only. At the
> figure's own 0.62 the words peaked at 71, fainter than the hint's 98 and the
> faintest text on the screen -- on exactly the gene a player holds while
> deciding where it goes, which is what pause opens on whenever a gene is
> waiting (§10.6). At 0.85 the words peak at 92, beside the hint, and the values
> at 145 against a worn gene's 170, so the dimmer register still reads.
> `NUMBERS_DIM` in `normal_mode.gd`.

---

## 4. Units

| kind | reads | format | from |
| --- | --- | --- | --- |
| energy | `burns 1.3 s`, `burns 0.50 s a second`, `a full tank: 36 s` | an amount to 1 decimal, whole from 10; a rate to 2 decimals | `energy.md` §1.1, *seconds of rest* |
| distance | `620 µm` | whole | the world unit |
| speed | `57 µm a second` | whole | the world unit, per second |
| time | `every 8.8 s`, `in 5.07 s`, `every 1.45–3 s` | up to 2 decimals, trailing zeros dropped | seconds |
| size | `0.82 × your size` | 2 decimals | a ratio of radii, as the gape rule is |
| share | `7%` | whole | |
| angle | `26°` | whole | |
| count | `3` | whole | |

**Energy is in seconds, because the game's economy already is.** Every cost in
the game is priced in seconds of rest (`energy.md` §1.1): how long a resting
newborn takes to burn as much.

- The caption states what this body's full tank holds, in the same seconds:
  `a full tank: 36 s`. So `burns 1.3 s` is read against 36.
- The caption also gives how long that tank lasts drifting. That is the one
  number all the costs add up to.
- Rates are *seconds per second*. `beating burns 0.50 s a second` is half
  again a resting newborn's burn, so a player can add rates together.

**Two kinds of second are told apart by their verb.** An energy second always
follows *burns*, *worth*, *holds* or *makes*. A time second always follows
*every*, *in*, *after* or *over*. New copy keeps that rule.

**Distance is in µm (owner's call 1).** The world has always had a unit that
nobody named.

- A newborn is 52 µm across, which is what a real ciliate measures. Calling
  the unit a micrometre costs nothing and turns every range into a real length.
- It is anchored twice. The caption's `68 µm across` describes the body the
  player is looking at. In full vision one µm is one canvas pixel
  (`vision.gd`'s `ZOOM` is 1.0), so the screen is 720 µm tall at every shape.
- So `reaches 620 µm` is most of a screen's height, and `out to 1100 µm` is
  past its edge.

**The formatter.** In Godot 4.7, `String.num` keeps a whole number's `.0`, and
`"%.1f" % 1.45` prints `1.4`. So the formatter is
`String.num(v, d).trim_suffix(".0")`.

---

## 5. The stats

### 5.1 Gene by gene

Each row gives the value at 1, 2 and 3 worn copies, for a newborn with no
`crista` and no `vacuole` (burn 1, reserve 1). `{}` marks a value.

- Every value was printed from the constants by the prototype. They were
  checked against `energy.md` §2 (0.50/0.70/0.99, flat out 0.81/1.04/1.33,
  pushing 0.68/0.96/1.30, a beat at 1.3 and 1.8 s, a half turn at 4.1 s) and
  against `beam-levels.md` §4–5.
- Constants are in `cell.gd` unless a file is named.
- `burn`, `reserve` and `tank` are §6.2's.
- In the second column, **1** means the *what it does* line and **2** the
  *what it costs* line.

| gene | | words | 1 | 2 | 3 | from |
| --- | --- | --- | --- | --- | --- | --- |
| `cytostome` *eat* | 1 | `swallows whole under {} × your size` | 0.82 | 1.05 | 1.40 | `GAPE_BY_TIER` |
| | 1 | `bites take {} head-on, {} from behind` | 7%, 15% | 10%, 21% | 14%, 29% | `BITE_BY_TIER` × `FLANK_AHEAD`, and × `FLANK_ASTERN` |
| | 2 | `its biggest meal is worth {} s` or `its biggest meal fills you` | 30 s | fills you | fills you | `MEAL × clamp(GAPE, MEAL_MIN, MEAL_MAX)` (metabolism.gd, food.gd) × tank; "fills you" when `MEAL × clamp(…) ≥ 1` |
| `cirrus` *turn* | 1 | `a half turn in {} s` | 5.07 | 3.93 | 3.08 | `PI / TURN_RATE_BY_TIER` |
| | 1 | `the turn builds over {} s` | 1.1 | 0.85 | 0.65 | `TURN_RESPONSE_BY_TIER` |
| | 2 | `turning burns {} s a second, {} s a half turn` | 0.81, 4.1 | 1.04, 4.1 | 1.33, 4.1 | `TURN_RATE × TURN_COST × burn`, flat out; `PI × TURN_COST × burn` |
| `flagellum` *swim* | 1 | `swims about {} µm a second` | 57 | 79 | 111 | `speed_for(copies)` |
| | 1 | `a beat every {}–{} s` | 1.7–3.6 | 1.45–3 | 1.2–2.5 | `IMPULSE_GAP_MIN_BY_TIER`, `IMPULSE_GAP_MAX_BY_TIER` |
| | 2 | `beating burns {} s a second, {} s a beat` | 0.50, 1.3 | 0.70, 1.6 | 0.99, 1.8 | a beat ÷ the mean gap; a beat is `IMPULSE_SPEED × IMPULSE_MEAN × STROKE_COST × burn` |
| `stigma` *see* | 1 | `feels bodies over {} × your size` | 0.80 | 0.80 | 0.80 | food.gd `SHADOW_MIN_RATIO` |
| | 1 | `out to {} µm` | 620 | 620 | 620 | food.gd `SHADOW_RANGE` |
| | 1 | `a bearing to within {}` | 26° | 19° | 13° | signal_bus.gd `LIGHT_HALFWIDTH_DEG` |
| `chemocyte` *smell* | 1 | `smells food out to {} µm` | 1100 | 1350 | 1600 | `SMELL_RANGE_BY_TIER` |
| | 1 | `{} as strong behind it` | 22% | 22% | 22% | food.gd `SMELL_BEHIND` |
| `ampulla` *ping* | 1 | `a ping every {} s` | 8.8 | 12 | 15.2 | `PING_PERIOD_BY_TIER` |
| | 1 | `out to {} µm` | 1100 | 1500 | 1900 | `PING_RANGE_BY_TIER` |
| | 1 | `the nearest {} answer` | 3 | 4 | 5 | food.gd `PING_RETURNS_BY_TIER` |
| | 1 | `stopped by any body` or `{} passes a body` | stopped | 34% | 58% | `PING_THROUGH_BY_TIER` |
| `axoneme` *push* | 1 | `holding on adds up to {} µm a second` | 81 | 115 | 155 | `PUSH_ACCEL_BY_TIER / DRAG` |
| | 2 | `pushing burns {} s a second` | 0.68 | 0.96 | 1.30 | `PUSH_ACCEL_BY_TIER × STROKE_COST × burn` |
| `palp` *touch* | 1 | `feels a body within {} µm of your skin` | 150 | 230 | 330 | `TOUCH_RANGE_BY_TIER` |
| `myoneme` *dash* | 1 | `a burst of {} µm a second, about {} µm in all` | 190, 257 | 240, 324 | 300, 405 | `DASH_SPEED_BY_TIER`, and that ÷ `DRAG` |
| | 1 | `again after {} s` | 1.4 | 1.4 | 1.4 | `DASH_COOLDOWN` |
| | 2 | `each dash burns {} s` | 2.2 | 1.6 | 1.2 | `DASH_COST_BY_TIER × HUNGER_SECONDS × reserve` (× burn instead, if call 2 is yes) |
| `trichocyst` *sting* | 1 | `a dart at a hunter within {} µm, {} either side` | 130, 55° | 190, 55° | 260, 55° | `DART_RANGE_BY_TIER`; `DART_ARC_DEG / 2` |
| | 1 | `again after {} s` | 26 | 18 | 11 | `DART_COOLDOWN_BY_TIER` |
| `pellicle` *armor* | 1 | `to a mouth you are {} × your size` | 1.14 | 1.30 | 1.52 | `ARMOR_BY_TIER` |
| | 1 | `bites take {} less` | 12% | 23% | 34% | `1 − 1 / ARMOR_BY_TIER` |
| `toxicyst` *venom* | 1 | `a biter takes back {} of its bite` | 35% | 55% | 80% | `VENOM_BITE_BACK_BY_TIER` |
| | 1 | `a swallower dies, and you are spat out` | | | | words only |
| | 2 | `being spat out burns {} s` | 17 | 12 | 7.9 | `VENOM_COST_BY_TIER × HUNGER_SECONDS × reserve` (× burn instead, if call 2 is yes) |
| `plastid` *sun* | 1 | `makes {} s of food every second` | 0.12 | 0.22 | 0.34 | `SUN_BY_TIER` (not scaled by burn, as metabolism.gd pays it) |
| `vacuole` *store* | 1 | `a full tank holds {} s, not {}` | 46 | 58 | 72 | `HUNGER_SECONDS × STORE_BY_TIER`; `HUNGER_SECONDS` |
| `crista` *burn* | 1 | `living, swimming, turning and pushing burn {} less` (becomes `everything burns {} less` if call 2 is yes) | 12% | 23% | 34% | `1 − BURN_BY_TIER` |
| **every gene** | 2, last | `free to wear` or `wearing it burns {} s a second` | free | 0.18 | 0.36 | `UPKEEP_PER_TIER × (copies − 1) × burn` (genome.gd): its own price |

- **Line 2 always exists.** For most genes it is only the wear item, and
  `free to wear` is worth reading: one copy costs nothing to wear.
- **A bite is said at both ends** (the build's review, 2026-09-29). The first
  words were `bites take {} of a body, {} at its tail`, which offered the least
  a bite takes, at the nose, as if it were the usual one: cell.gd's `flank` runs
  from `FLANK_AHEAD` at the nose through 1.55 on the flank to `FLANK_ASTERN` at
  the tail. `head-on` and `from behind` fit where `of a body` did not. It is
  now the widest line the table makes, at two copies: 550 px, inside the 560 px
  column, its ink 23 px from the switch at both shapes (`S13`'s 538 px line was
  the widest before).
- **The dash and venom** are shown in seconds for this body. While call 2
  stands as built, a bigger tank makes them cost more seconds, because they are
  a share of it. `S04` shows this: a three-copy venom in a `vacuole`-3 body
  reads `being spat out burns 16 s`, against 7.9 for a newborn.

  > **Built with call 2's *yes*, 2026-09-29** (§11): they cost the same seconds
  > in any tank and fewer with `crista`, so `S04`'s `crista`-2 body reads
  > `being spat out burns 6.1 s`.

### 5.2 The beam, by level and way

The beam is read at its **effective level**, which is held at 3 while the fork
is open, and at the way it took. This is what `EXPLAINS_PATH` follows too.

| level, way | line 1: what it does | line 2: what it costs |
| --- | --- | --- |
| 1 | `1 ray · reaches 620 µm` | `free to wear` |
| 2 | `2 rays across 44° · reaches 900 µm` | `wearing it burns 0.18 s a second` |
| 3, or any level with the fork still open | `3 rays across 100° · reaches 1240 µm` | 0.36 |
| `extend` at 4 / 5 / 8 / 12 / 20 | `{} rays across 100°, one every {}` (33° / 25° / 14° / 9° / 5°) `· reaches 1240 µm` | 0.54 / 0.72 / 1.26 / 1.98 / 3.42 |
| `sweep` at 4 / 5 / 8 / 12 / 20 | `3 rays sweeping 100° · every bearing lit within {} s` (2 / 1 / 0.4 / 0.22 / 0.12) `· reaches 1240 µm` | 0.45 / 0.54 / 0.81 / 1.17 / 1.89 |

- **The sources:**
  - `CellBody.beam_shape(level, path)` gives the rays, the half-span, the sweep
    rate and the reach. The fan is `2 × half`, and the spacing is
    `fan ÷ (rays − 1)`.
  - Every bearing is lit within `RayFan.revisit_of(rays, half, sweep)`, in
    radians.
  - The price is `CellBody.beam_upkeep(level, path) × burn`, which is
    genome.gd's own price for the beam.
- **The next level.** When the body wears the beam and it is read on the
  figure, line 2 ends with `· level {} after {} strikes`: the next level, and
  `ceil(progression.to_next())`. A fresh beam reads `level 2 after 40 strikes`.
  - A strike is one different body in the beam in one second, at most
    `BEAM_XP_CAP` (3) a second. That is exactly what earns experience
    (`beam-levels.md` §2).
  - The item is left off the cards, and off a beam the body does not wear,
    because such a beam earns nothing.
- **On the cards**, a way that is hovered or armed is shown at the cards' level
  (`_way_level()`). So `costs less to keep` gets its number: `S06` reads
  `3 rays sweeping 100° · every bearing lit within 1 s · reaches 1240 µm` and
  `wearing it burns 0.54 s a second`, where `fill` at the same level burns
  0.72.

### 5.3 Which copies, and which body

| what is read | shown at | drawn |
| --- | --- | --- |
| a slot whose gene the body wears | the copies it wears (`_genome.tier`). Not the DNA's, which are the daughters' | full |
| a slot the DNA carries and the body does not wear | the DNA's copies | × 0.85 (§3.3's note) |
| a waiting gene, in hand | the copies it waits with (`_copies_of`) | × 0.85 |
| a levelled gene | its effective level and its way | as above |
| a way on the fork's cards | that way, at the cards' level | full |
| a daughter's locus, on the choosing screen | that locus's copies, in **her** body's `crista` and `vacuole` | full if she wears it, × 0.85 if she only carries it |
| an empty slot, or nothing selected | nothing; the block keeps its height, so `Hint` and `Act` do not jump | |

Why these choices:

- **The figure's colours.** The dim register is the one the figure already uses
  for a gene the body does not wear (`ORGAN_UNEXPRESSED`, `WORD_UNEXPRESSED`).
  The same numbers dimmed say *what a body wearing it would have*.
- **The worn copies, not the DNA's.** The body wears what it was born with, so
  a gene eaten again this life shows today's numbers. Its extra copy is still
  shown in the pips as a ring.
- **A gene in hand that the body also wears reads as worn** (the build's
  review, 2026-09-29). It happens when a slot is written over while the body
  still wears its old gene, and that gene is eaten again and waits. Its numbers
  are the copies the body wears, at full brightness, as its slot's are: they are
  this body's own (§1.4). The odds under them are the waiting copies', because
  the odds are the DNA's.
- **The numbers dim less than the figure** (§3.3's note): × 0.85 against the
  figure's 0.62, so the words stay as legible as the hint.

### 5.4 The caption and the odds

- **The caption**, when numbers are on:
  `genome · first generation · 52 µm across · a full tank: 36 s, 24 s drifting`.
  It keeps the caption's own size and tint (15 px, `CAPTION_TINT`). It is at
  most 542 px wide (`seventh generation`, 80 µm, three-digit seconds), inside
  the 560 px column.
- **The odds**, when numbers are on:
  - one copy: `one copy · 55% of daughters wear it`;
  - two copies: `two copies · 80% of daughters wear it`;
  - three copies, and the mouth: unchanged, `a daughter always wears it`
    (`GenomeNode.EXPRESS_CHANCE`).
  - On the choosing screen the same clause comes after `worn ·` or
    `carried ·`.

---

## 6. How it is computed

### 6.1 Two files, and the gene names stay at the edge

```gdscript
# game/mechanics/readout.gd -- NEW. Generic: it knows units and never genes. No class_name.
enum Unit { DISTANCE, SPEED, TIME, ENERGY, RATE, TIMES, SHARE, ANGLE, COUNT }
static func format(value: float, unit: int) -> String          # §4's rules
static func item(text: String, values := [], units := []) -> Dictionary   # "out to {} µm"
static func runs(items: Array) -> Array    # [[text, is_value], ...], " · " between items
static func draw(canvas: CanvasItem, font: Font, size: int, runs: Array,
		centre_x: float, baseline: float, word: Color, value: Color) -> void

# game/normal/gene_stats.gd -- NEW. The edge: gene names meet the readout here and nowhere else.
static func context(body: Dictionary) -> Dictionary     # burn, reserve, sun, from a {gene: copies} body
static func lines(gene: StringName, copies: int, level: int, path: StringName,
		ctx: Dictionary) -> Array                          # [line 1 items, line 2 items]
static func cell_items(radius: float, body: Dictionary, upkeep: float) -> Array   # the caption's clause
static func odds_text(copies: int) -> String
static func progress_item(level: int, to_next: float) -> Dictionary
```

- **The table is data.** A row is a template and its values, and every value
  is read off a constant or a static in `cell.gd`, `genome.gd`,
  `metabolism.gd`, `food.gd` or `signal_bus.gd`. Change a number there and the
  screen follows.
- **An unknown gene draws nothing.** A gene with no row (a later gene arriving
  over older content, or a retired one) returns `[[], []]`, just as
  `_explains()` says nothing for a gene with no line.
- **No `class_name`** on either file, for `signal_bus.gd`'s reason. Preload
  them by path.

### 6.2 The body's own terms

| term | value |
| --- | --- |
| burn | `BURN_BY_TIER[copies of crista]` |
| reserve | `STORE_BY_TIER[copies of vacuole]` |
| sun | `SUN_BY_TIER[copies of plastid]` |
| tank | `HUNGER_SECONDS × reserve` |

These are read from the body being described: `_genome.tiers()` on the pause
screen, and `_daughters[side]["body"]` on the choosing screen.

The caption's clause:

| part | value |
| --- | --- |
| size | `2 × cell.radius` |
| drifting | `tank ÷ (max(_genome.upkeep() − sun, 0) + the tail's rate)` |
| the tail's rate | `IMPULSE_SPEED × IMPULSE_MEAN × STROKE_COST × burn ÷ mean gap`, at the body's `flagellum` copies |

This is the sum metabolism.gd pays each second when there is no steering. A
newborn gets `36 ÷ (1 + 0.50)` = **24 s**, which is `energy.md` §7.2's
measured 24.0 s to empty. `S04`'s `crista` 2 and `vacuole` 3 body reads
`72 s, 39 s drifting`, which was checked by hand.

### 6.3 When it is refreshed

| event | refreshes |
| --- | --- |
| `_update_explain()`: every change of selection, hover, hand, drag or way | the numbers, through a new `_update_numbers()` |
| `_build_genome_strip()` | the caption, through a new `_update_caption()` that replaces its one line |
| the switch | the numbers, the caption, `_update_hint()` and `_choose_say()` |
| `_step_levels_shown()`, under a pond's menu where the beam earns | the numbers and the caption as well. Add the cell's radius to what it watches, so a meal eaten under the menu updates the size |

---

## 7. What the words are for

Each line answers a question a player about to master the game actually asks.

- *Can I eat that?* The gape, in `× your size`.
- *Can I outswim it?* The speeds, in µm a second.
- *How far do I feel?* The reaches, in µm.
- *How often does it answer?* The periods and cooldowns.
- *What does it cost me?* The burns, in seconds of a tank whose size the
  caption states.

No line explains a mechanic in the abstract. The sentence above the numbers
already says what the organ does in words, and the numbers only make it exact.

---

## 8. Rendered

Every frame is `tools/shot.tscn` driving `tools/drive.tscn` under
`--rendering-driver opengl3 --fixed-fps 60`, on the prototype, at 1280x720 and
at 2400x1080. At 2400x1080 every touch's x is 160 further right. The prototype
read `--numbers`; the build takes `--numbers=1` (§2.2).

```
G  = --genome=cytostome:2,cirrus:1,flagellum:3,ocellus:1:3 --radius=34 --esc-at=1.0 --seed=7 --mode=0
F5 = --level=ocellus:5 --earn=0.5:ocellus:100 --touch=1.5:938,204 --touch=2.0:898,358
CH = --seed=12345 --radius=40 --mode=0 --dna=cytostome:3:0,cirrus:2:1,flagellum:3:2,ocellus:1:3,ampulla:2:4,pellicle:1:5,toxicyst:2:6
```

| frame | wait, flags | shows | judgement |
| --- | --- | --- | --- |
| `S01` both | 2.0 `G --touch=1.4:938,204` | numbers off: today's screen and the quiet switch | passes; §3.2's diff |
| `S02` both | `S01 --numbers=1` | the beam: `1 ray · reaches 620 µm` / `free to wear · level 2 after 40 strikes`, the odds at 55%, the caption | passes |
| `S03` both | 2.0 `G --numbers=1 --touch=1.4:788,510` | a three-copy tail, both lines full | passes |
| `S04` both | 2.0 `--genome=cytostome:1,cirrus:1,flagellum:1,toxicyst:3:3,crista:2:4,vacuole:3:1 --radius=34 --esc-at=1.0 --seed=7 --mode=0 --numbers=1 --touch=1.4:938,204` | venom in a body with `crista` and `vacuole`: `burns 16 s`, `0.28 s a second`, `72 s, 39 s drifting` | passes, and shows call 2's loose end. **On the build** (call 2's *yes*): `burns 6.1 s` |
| `S05` both | 2.0 `G --sample=ampulla --numbers=1` | a waiting gene in hand, dimmed; `one copy · 55% of daughters wear it` | passes |
| `S06` both | 2.4 `G F5 --numbers=1` | the cards, with `sweep` armed at level 5 | passes |
| `S07` both | 2.0 `G --sample=ampulla,trichocyst:2,chemocyte,pellicle,stigma:3 --numbers=1` | two tray rows, the tightest case: `Act` ends at y 708 | passes, with 12 px to spare |
| `S08` both | 2.0 `G --touch=1.4:938,204 --touch=1.7:1132,565` | numbers off, then one real tap on the switch | passes: on, once |
| `S09` both | 3.2 `G`, seven `--tap=…:tab`, then `--tap=2.5:enter` | the keyboard alone, from `resume` | passes |
| `S10` both | 2.0 `G --touch=1.4:938,204 --hover=1.7:1132,565` | the switch off and hovered | passes |
| `S11`, `S12` both | 6.0 `CH --numbers=1 --touch=5.5:340,376` and `…:340,472` | choosing: a worn `ping`, and a carried `venom` dimmed | passes, centred, clear of both strands and the contour |
| `S13` both | 2.0 `--genome=cytostome:1,cirrus:3,flagellum:1 --radius=34 --esc-at=1.0 --seed=7 --mode=0 --numbers=1 --touch=1.4:938,342` | the widest line, 538 px | passes, its ink 28 px from the switch. **On the build** the bite line is wider: 550 px, 23 px (§5.1's note) |
| `S14` both | `S03` with `--mode=1` | full vision: the ghost still in the ring's empty cell | passes |
| `T1`–`T4` | `S01`/`S02`, each with and without `--hover=1.7:1132,565` | the switch's four states, zoomed, in colour and in greyscale | passes |

**The frames reproduce first.** `S03` rendered three times differs by
**0 pixels**, so the diffs in §3.2 measure the design and not noise.

---

## 9. What changes, file by file

| file | change |
| --- | --- |
| `game/mechanics/readout.gd` | **new**: §6.1 |
| `game/normal/gene_stats.gd` | **new**: §5's table and §6's arithmetic |
| `game/normal/normal_mode.tscn` | §3.1's tree: `Lines`/`Stack` wrapping the three rows, two `Numbers` controls, and `NumbersToggle` |
| `game/normal/normal_mode.gd` | the new `@onready` paths; the switch (drawing, input, hover, and the two focus links in `_wire_focus()`); `var numbers := -1` for the harness; `_update_numbers()`, called from `_update_explain()`; `_update_caption()`; the odds in `_update_hint()` and `_choose_say()`; the numbers in `_choose_say()`; §6.3's refreshes; `N` |
| `game/run_state.gd` | `load_numbers()` and `save_numbers()`: `[run] numbers`, default `false` |
| `tools/drive.gd` | `--rects=` names `Genome/Lines/Stack/Explain`, `…/Hint`, `…/Act`, plus `Numbers` and `NumbersToggle`; a new `--numbers=0\|1` |
| only if call 2 is yes: `normal_mode.gd` | `_on_dashed` pays `spend(cost × HUNGER_SECONDS)` and `_on_stung` pays `spend(venom_cost × HUNGER_SECONDS)`, instead of `feed(-…)`; `crista`'s words become `everything burns {} less`; the dash and venom rows take `× burn` in place of `× reserve` |

**What it does not touch:**

- No constant moves.
- Nothing crosses the wire. Hunger and the pause screen are each player's own,
  and `VENOM_COST_BY_TIER` keeps its values: the host only asks
  `venom_cost >= 0`.
- There is no `Wire.PROTOCOL` or `Wire.RULES` change, no `project.godot`
  change, no binary change, no `addons/` and no `ci/`. Run net_probe anyway.
- It ships as a content pack.

---

## 10. Left open

1. **Two cell-wide rules no gene carries.** These are the grace (10 s at empty,
   `STARVE_GRACE`) and what a meal is worth (`MEAL`: a meal your own size fills
   you). The caption could carry them, but a gene can be read without them.
2. **The dart is measured centre to centre** and the palp skin to skin, because
   that is how the game measures them. Only the palp's line says
   `of your skin`.
3. **How a view draws a sense is not listed.** That covers the beam's and the
   ping's width on the membrane (`BEAM_HALFWIDTH_DEG`, `PING_WIDTH_FLOOR`),
   which describe the drawing, not what the organ reaches.
4. **A third tray row would push `Act` off the screen with numbers on.** That
   needs nine waiting genes, which is not reachable in play: genes lapse after
   45 s.
5. **The choosing screen has no switch.** Its loci are `FOCUS_NONE`, and pause
   is refused during a division, so its numbers follow the setting made on the
   pause screen.
6. **The tray's chips carry no numbers.** A waiting gene's numbers show when it
   is in hand, and the head is in hand whenever pause opens.

---

## 11. Owner's calls

| # | Question | Options | What it means |
| --- | --- | --- | --- |
| 1 | What unit should distances and speeds use? | **micrometres, `620 µm` ✓ recommended** · your own widths, `12 × you` · bare numbers, `620` | µm is what real cells are measured in. You are born 52 µm across, and in full vision the screen is 720 µm tall, so a range reads as a real length you can picture. Your own widths read instantly, but every range shrinks as you grow: one beam says 12 at birth and 8 before you divide. Bare numbers are exact but mean nothing until you have learnt the scale. |
| 2 | Should a dash and being spat out cost less with `burn` and `store`, like everything else does? | **yes ✓ recommended** · no, keep them a fixed share of the tank | Today `burn` makes being alive, swimming, turning and pushing cheaper, but not a dash or venom's price. A bigger `store` tank even makes a dash cost more seconds. So the numbers have to say `living, swimming, turning and pushing burn 12% less`. With yes, `burn` really does make everything cheaper, and a bigger tank makes every cost a smaller share of it. A newborn pays exactly what it pays now. With no, nothing changes but the words. |

**Row 2 is the loose end `energy.md` §1.3 left for this work by name.** It is
two lines in `normal_mode.gd`, and no constant moves. Each player's own device
pays its own hunger, so it crosses no wire (§9).

> **Row 2 is built with the recommended option, 2026-09-29, pending the owner's
> answer.** `_on_dashed` and `_on_stung` pay through `spend`, `crista` reads
> `everything burns {} less`, and the dash and venom rows take `× burn`. A
> newborn pays what it did; `S04` reads `6.1 s` where it read 16. Row 1 is
> built as recommended too: µm.
>
> To take *no* instead:
> - put back the two `feed(-…)` lines in `_on_dashed` and `_on_stung`;
> - put back `× reserve` in `gene_stats.gd`'s dash and venom rows, and
>   `crista`'s old words (`living, swimming, turning and pushing burn {} less`);
> - turn round the three `levels_probe.gd` checks that pin the *yes* (`with
>   crista 2…`, `with vacuole 3…`, `and the numbers say what is paid…`), which
>   fail without it;
> - and take back what describes it: `DASH_COST_BY_TIER`, `VENOM_COST_BY_TIER`
>   and `STROKE_COST` in `cell.gd`, `spend()` in `metabolism.gd`, `_on_dashed`
>   and `_on_stung` in `normal_mode.gd`, and the dated notes in `energy.md`
>   §1.3, §2 and §7.1.
