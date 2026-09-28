# Levels, and the beam that grows two ways

The owner, on 2026-09-28:

> Beam is the first to be reworked. it should level up to way more that just 3
> beams. There could 2 upgrade paths : We could imagine the genes able to earn
> xp forever, gaining LVLs as we play. Then, at some point, you can choose
> between 2 paths : beam extension : for each lvl, you gain one more beam. Or
> beam sweep. For each level, each beam sweeps at a speed proportional to the
> lvl. Both end to a similar result, with one taking more energy than the other
> (could be x energy per beam, with a negative effect of y energy per unit of
> beam sweep speed)

and, the same day, on why:

> I need senses that has pros and cons (not one sense that can do all) to really
> make the choice important.

This spec is the mechanics. §8, the screens, is the UX designer's.

Status: **specified, not built.**

---

## 0. Decided

Put to the owner as five rows; the answer was *recommended for all five*.

| # | Question | Decided |
|---|---|---|
| 1 | What earns a gene XP? | **Using it.** For the beam: each body it touches, capped per second. |
| 2 | Does a gene's level pass to your daughter? | **Yes.** The level is the lineage's, not the body's (§3). |
| 3 | When does the fork come? | **Level 3**, where today's ladder ends. |
| 4 | Which path costs more energy? | **More beams costs more.** Sweep is cheaper and leaves gaps. |
| 5 | What do the 1–3 copies do once levels exist? | **Copies decide whether a daughter grows the gene; the level decides how strong it is.** |

One thing the owner was told turned out to be wrong, and it is wrong in the
game's favour: **levels do not need a protocol change.** §6 is why.

---

## 1. A level is general; the beam is its first user

The owner also said the game will come in other scales — naval, space — with
*components* instead of genes, and CLAUDE.md now asks for mechanics that do not
know about cells. So there are two new pieces, and neither names a gene:

- **`game/mechanics/progression.gd`** — experience, a level, and one fork. It
  knows nothing about what earns it or what the level buys.
- **`game/mechanics/ray_fan.gd`** — a fan of rays: how many, how wide, and
  whether they sweep. It knows nothing about eyes.

The beam is the edge where the two meet the cell: `cell.gd` holds the beam's
numbers (it is already where "what the genome buys" lives), `genome.gd` holds
one progression per gene, and `normal_mode.gd` wires them together, because it
is the one file that has the genome, the field and `cilia.gd`'s arc table.

**No `class_name`** on either new script, for the reason `signal_bus.gd` gives:
a content pack mounts over an older binary, and a global class a pack
introduces is not in that binary's class list. Preload by path.

### 1.1 The progression

| field | meaning |
|---|---|
| `xp` | experience earned, a float, never spent |
| `level` | derived from `xp`, never stored: 1 at `xp` 0 |
| `path` | `&""` until chosen; then one of the ability's paths, for good |

**The curve.** Going from level L to L+1 costs `STEP × L` experience, so
reaching level L takes `STEP × L(L−1)/2` in total. Each level takes a little
longer than the last and none is ever the last.

**The fork.** At `FORK_LEVEL` the progression offers its paths. Until one is
chosen, **experience keeps counting but the ability stays at the fork level**:
the levels are banked and all of them arrive the moment a path is chosen. So
choosing late costs nothing but the time spent without the benefit, and a
player who never opens the pause screen still keeps a working level-3 beam.

A path, once chosen, is permanent for as long as the lineage carries the gene
(§3). There is no respec: the choice is supposed to matter.

### 1.2 Numbers for the beam

| constant | value | where it lives |
|---|---|---|
| `FORK_LEVEL` | 3 | `cell.gd`, beside the beam tables |
| paths | `&"extend"`, `&"sweep"` | `cell.gd` |
| `STEP` | **measured at build**: the value that takes ordinary play to level 2 in about a minute and to the fork in about three | `cell.gd` |
| experience cap | 3 per second | `cell.gd` |

`STEP` is set off an instrumented run, not guessed, and the run is written into
§9 when it is.

---

## 2. Earning: every body the beam touches, capped per second

Decision 1. Each second, the beam earns **one point for each different body any
of its rays touched during that second**, at most 3. A body held in the beam
for the whole second is one point, not sixty; three bodies swept past in one
pass are three.

- **Only a worn organ earns.** The beam exists only on a body that wears it.
- **Anything with a body counts** — food, a hunter, a sister, the other player.
  The motes do not, because the beam already passes through them.
- **Counting different bodies, not ray-frames**, is what makes the two paths
  earn at comparable rates. Extension touches more at once; sweep touches the
  same bodies in turn. Per second they come to about the same, which keeps the
  path from being a choice about levelling speed.
- A pond's pause screen does not stop the water, so a beam earns there too.
  Single player stops every clock while the screen is open, this one included.

The field reports which body each ray stopped on (§4.4), and the count lives in
a small general tally: *different targets touched this second, capped*.

---

## 3. The lineage: the level belongs to the gene, not the body

Decision 2, and the rule that makes it hold.

`genome.gd` keeps one progression per gene, **kept while the body wears the gene
or the DNA carries it**, and dropped when neither does.

| event | what happens to the progression |
|---|---|
| a division | each daughter gets a copy for every gene in **her own DNA**, worn or not |
| a daughter who carries the gene but did not grow it | keeps the level, dormant; she earns nothing, and her daughters inherit it |
| a drift mutation replaces the gene | the new gene starts at level 1 |
| a trade mutation moves copies | the level is untouched |
| a placement writes another gene over it | dropped once the body no longer wears it either |
| a move | untouched: the progression follows the gene, not the slot |
| death | everything resets, as it always has: a run keeps nothing |
| a gene arriving fresh (eaten and placed, drifted in, the free sense) | level 1, no experience |
| eating more copies of a gene you carry | the level is untouched; copies are odds (§5) |

**Why dormant levels are kept.** Expression is a coin toss at one copy
(`EXPRESS_CHANCE` 0.55). Losing twenty minutes of levels to one failed toss
would make the copies the thing that matters again, which is decision 5 in
reverse. A daughter who didn't grow the beam still passes its level on.

The body keeps what it wears for its whole life, as it always has. If the DNA
drops the beam, the body keeps using it and keeps its level until that body
divides or dies. Its daughters don't carry the gene, so they don't inherit it.

---

## 4. The beam, by level

`E` is the **effective level**: the level, held at `FORK_LEVEL` until a path is
chosen.

### 4.1 Before the fork: today's beam, exactly

| E | rays | fan (either side) | reach |
|---|---|---|---|
| 1 | 1 | 0° | 620 |
| 2 | 2 | 22° | 900 |
| 3 | 3 | 50° | 1240 |

This is `BEAM_COUNT_BY_TIER`, `BEAM_FAN_DEG_BY_TIER` and `BEAM_RANGE_BY_TIER`,
indexed by level instead of by copies. A level-3 beam is the tier-3 beam
players have now.

### 4.2 Extension: one more ray per level

| E | rays | spacing across 100° |
|---|---|---|
| 3 | 3 | 50° |
| 4 | 4 | 33° |
| 6 | 6 | 20° |
| 10 | 10 | 11° |
| 20 | 20 | 5.3° |

**The fan does not widen; it fills in** — the owner's *fill the space in
between* from `three-senses.md` §3, which this replaces. Reach stays 1240.

- **Pro:** every ray is lit all the time. A body on a ray is tracked
  continuously, and what you see is where it is now.
- **Con:** a body narrower than the spacing can sit between two rays and not be
  seen until it crosses one; and it is the expensive path (§5).

At 20 rays, `three-senses.md` §3.1's table applies: a radius-26 body is caught
reliably out to about 566 units.

### 4.3 Sweep: the same three rays, moving

At E ≥ 3 the sweep path keeps three rays. Each one sweeps its own third of the
100° fan — a 33⅓° sector, centred at −33⅓°, 0 and +33⅓° — back and forth, all
three in step.

`ω = 33⅓ × (E − 3)` degrees a second, so one pass across a sector takes
`33⅓ / ω` seconds, and each bearing is visited twice per period:

| E | ω | a sector crossed in | every bearing revisited within |
|---|---|---|---|
| 3 | 0 | — (at rest, identical to extension) | — |
| 4 | 33°/s | 1.0 s | 2.0 s |
| 5 | 67°/s | 0.5 s | 1.0 s |
| 6 | 100°/s | 0.33 s | 0.67 s |
| 10 | 233°/s | 0.14 s | 0.29 s |

- **Pro:** no spatial gaps. Everything in the fan is found within the revisit
  time, however thin it is, and it is the cheap path (§5).
- **Con:** gaps in time. Each thing is seen once per pass, so what the beam
  shows is where it *was*. A fast body moves between passes, and a small one
  can be in the fan and unlit for most of a second at low levels.

**Both converge,** which is the owner's *both end to a similar result*: at high
level the extension fan is solid with rays and the sweep fan is crossed several
times a second. They get there by different routes and at different prices.

**Frame-rate independence.** A sweep at 233°/s moves 3.9° a frame at 60 fps and
7.8° at 30. So the field tests a sweeping ray across **the whole arc it swept
this frame**, in sub-steps no wider than 2°, and reports the nearest hit in
that arc as the ray's. A slow phone must not see less than a fast one.

**What the sweep leaves behind.** A hit that is only lit once a pass has to stay
visible between passes, or the sweep reads as flicker. Each sweep hit **holds
and fades over the revisit time** in both views: point of view's pointer marks
(`returns.gd`) and full vision's hit dots. So does the membrane's beam lobe,
which already carries only the nearest hit. The result reads as a radar scope,
and it is honest about staleness: the mark sits where the body was when the ray
last passed. Extension has no fade, because its rays are always on.

### 4.4 What the field reports

`food.gd`'s `beams` entries gain a fourth field: **which body the ray stopped
on**. The recorder copies only the first three, so recording is unaffected
(§7). The tally in §2 reads the fourth.

`_step_beams` is `rays × bodies` ray tests a frame. At 20 rays and 34 bodies
that is 680, as `three-senses.md` §3.4 warned. Add the cheap rejection it
proposed: one dot product per body against the fan's angular bounds, before
the ray loop. Measure a frame before and after.

---

## 5. What it costs: x per ray, y per unit of sweep

Decision 4. The beam's upkeep term **replaces** its old `0.18 × (copies − 1)`.
Copies no longer buy strength (decision 5), so they no longer cost anything
either: a gene's copies are its odds.

    beam upkeep = X × (rays − 1)  +  Y × ω

| | value | per level past the fork |
|---|---|---|
| `X` | 0.18 per ray after the first | extension: **+0.18** |
| `Y` | 0.0027 per °/s | sweep: **+0.09** |

`X` is today's per-tier price, so levels 1–3 cost exactly what tiers 1–3 cost
now. `Y` makes a sweep level half the price of an extension level. That was the
starting point the owner was offered: *sweep about half as much, at equal
coverage*.

| E | extension | sweep |
|---|---|---|
| 3 | 0.36 | 0.36 |
| 5 | 0.72 | 0.54 |
| 10 | 1.62 | 0.99 |

The term goes into the same multiplier every other gene's upkeep does
(`genome.gd` `upkeep()`), `crista` still discounts the whole bill, and it
reaches the player as the beat, like any other cost. A cell with nothing else
above tier 1 starves in `420 / (1 + term)` seconds: 309 s at level 3, 244 s
(extension) or 273 s (sweep) at level 5, and 160 s against 211 s at level 10.

**`X` and `Y` are balance numbers, and the owner judges them by playing** on the
dev app. They are constants with this paragraph beside them.

---

## 6. The network sees none of it

This is why there is no protocol bump, which the owner was told to expect.

- **What crosses the wire is the worn body's `{gene: copies}` map and its slot
  order** (`PERSON`, `SISTER`, `GENOME`). The referee holds that map fixed for
  a whole life and fouls any change but the free sense. **A level lives beside
  the map, never in it**, so levelling up mid-life changes nothing the host can
  see. If a level were written into that dictionary, the first level-up would
  be a foul.
- **No machine casts or draws another player's beam.** `_step_beams` casts only
  from this device's own cell, and a dedicated server never runs it.
- **The host never computes anyone's upkeep or hunger.** The beam's cost is the
  device's own business.
- **What eating a body gives, its drawn organs, its gape**: all read copies,
  which do not change.

So `Wire.PROTOCOL` stays 4, `Wire.RULES` is unchanged, and a player on this
build shares a pond with one on the last release. The referee copies no rule
this spec touches. **Check it anyway**: net_probe's `referee` section
recomputes the fingerprint, and it must pass untouched.

The friend's organ is still drawn by its copies. If the owner wants a
high-level beam to look different to the other player, *that* would need its
level on the wire. It is not asked for here.

---

## 7. Replay

- **The level and path are genome state.** They go into the recorder's `PLAYER`
  delta and into `_sign_genome()`, or a level-up records nothing. `replay.gd`
  restores them after its `express()`.
- **More rays than the ring has room for.** `recorder.gd` stores exactly
  `BEAMS = 3` rays a frame. Raise it to **24**, capturing hits first so a
  crowded fan keeps what it found. That is 63 more floats a frame, about
  0.9 MB more ring over a 60-second window. The ring lives in RAM and is never
  saved, so no old recording is at risk. `three-senses.md` §3.3 named this and
  left it to the builder; this is the decision.
- A sweep's fade is drawn by the views from the frames they are given, so a
  replay shows it too. On a seek, the views drop their held marks rather than
  fading ones from another moment.

---

## 8. The screens

*The UX designer's.* Decided here and **not built**. Every picture below is a
mock: a scratch overlay, kept outside the repository with its frames, drew over
the real pause and choosing screens at 1280x720 and 2400x1080 through the real
harness. With nothing mocked, it reproduces `tools/shot.tscn` to 0 pixels. §8.7
names the frames and says what the build has to shoot again.

**The pips stay the copies. The level is a number, and the number never sits
in the pips' row.** (`dna-body.md` §3.1 calls the pips "the level"; they were a
copy count then and still are. From here on *level* means only the number.)

### 8.1 The level, on its slot

A gene with a progression (`_genome.progression(gene) != null`; today only
`ocellus`) draws its **level as a numeral inside the third lobe of its slot's
helix**, the one right of the rungs. That lobe is empty on every chip, and no
tether crosses it. Computed from `_chip_edge()` for all seven seats, tethers
start on the bottom edge (nose, forward diagonals), on the top edge (tail, and
the rear diagonals at x 28.5 and 67.5, rising away), or on the left (flank).
Every other gene draws exactly what it draws today.

| | value |
| --- | --- |
| text | `str(progression.level())`: the **banked** level. Not `level_of()`, which is held at the fork |
| font | the Hud's default (Open Sans SemiBold), `LEVEL_SIZE` 12 px; 10 px from 100 up |
| seat | centred on x `LEVEL_X` 76 (`CHIP_X + 2.5 × CHIP_LOBE`), baseline `LEVEL_BASE` 23.5: the digits' ink spans chip y 14..22, centred in the lens. At an open fork, x `LEVEL_FORK_X` 81 (§8.3) |
| tint | the word's own: `LABEL_TINT`, `LABEL_TINT_LOUD` when selected, `Color(PALE, WORD_UNEXPRESSED)` when not worn. `Color(hue, 0.95)` while the fork is open |
| drawn | wherever the chip draws its word: its slot, and the armed preview of a gene in hand. Not on a drag source, an empty slot, an unearned one, **or a waiting chip in the tray**. A waiting gene has earned nothing; if its body still wears a level, the line below says so (§8.2) |

**1–99 fits, measured on the widest chip the game can make** (`M08`): `venom`,
the widest word, three worn copies, level 99. Digits are tabular, 7 px at 12 px,
so `99` is 14 px. Its ink runs chip x 70..81, y 14..22: 2.6 px inside the
lobe's backbones at the tightest corner, and 12 px clear of the third rung. The
word and pips are untouched (7.6 px margins, as today), so the level costs the
chip no width. At 2400x1080 the chip is 144 x 84 device px and the digits 13 px
tall. The 10 px fallback is a guard: level 100 is about 80 hours of use at
`BEAM_XP_STEP` 40.

- **Not after the pips** (`M03`, built and rejected): `beam ●•• 12` reads as a
  count of the dots, fills 94 of 96 px, and `venom` with two digits is 101 px.
  In the lobe the two numbers differ by row, shape and tint, and the lobe is
  the truthful place: the level is inherited with the gene (§3), which is what
  the strand draws.
- **A `1` is not a rung** (`M02`): a rung is a 22 px bar in the gene's hue; the
  digit is 9 px, pale, and has a flag.

### 8.2 The line under the figure: level and progress

`Genome/Hint` becomes an `HBoxContainer` (separation 6, `ALIGNMENT_CENTER`,
min height 20). Its existing label moves inside as `Text`, and two children go
in front of it:

| child | what | shown |
| --- | --- | --- |
| `Level` | `Label`, 14 px, `LABEL_TINT`: `level %d` | a levelled gene is read |
| `Gauge` | `Control` 36 x 20 drawing a 36 x 4 bar at y 9, radius 2: track `Color(PALE, 0.14)`, fill `Color(hue, 0.85)` `round(36 × progress())` px wide | the same |
| `Text` | the hint as today, 14 px at 0.38 | always |

So `level 7 ▰▰▱ · two copies · a daughter probably wears it` (`M05`): the
level is what a daughter inherits, and the copies are whether she wears it,
which is §0 row 5 in one line. The widest, `level 99`, the gauge and
`· three copies · a daughter always wears it`, is 383 of 560 px. It is a gauge
and not a number because experience means nothing to a player, and
`progress()` is already a fraction: one pixel is 1/36 of a level.

**Armed over a levelled gene, the warning names the level** (no gauge):

| constant | text |
| --- | --- |
| `HINT_LOSES_LEVEL` | `%s leaves your dna · level %d ends with this body` |
| `HINT_LOSES_LEVEL_CARRIED` | `%s leaves your dna · its level %d is lost` |

The body keeps a gene it wears, level and all, for this life (§3). Its daughters
never get it. At most 355 px.

**In a pond the level moves under an open menu**, because the beam earns there
(§2). Redraw the read chip and this row when `level()` changes or the gauge
would move a pixel. Nothing rebuilds.

### 8.3 The fork

The fork is open while `_genome.can_choose(gene)`: level at or past
`FORK_LEVEL`, no path. It shows in three places and is chosen in one.

**The slot: its strands part** (`M04`). The helix stops halfway through its
third lobe and the two strands separate, like a replication fork. Lobes 0–1
draw as today. From `along` 56 to 70 the weave continues, and from 70 to 88
the strands leave it: swing `CHIP_AMP + 6.5 u²`, `u = (along − 70) / 18`,
2 px, blending from their depth colour to `Color(hue, 0.9)` at the tips. The
tips land at chip x 94, y 1.5 and 36.5, inside the box. The numeral moves into
the fork's mouth and takes the hue. The chip's outline changes, not only its
colour, so it survives greyscale. Put it in `cilia.gd` beside `draw_weave`, as
a static `draw_fork(canvas, axis, lobe, mid, amp, from, to, spread, tone,
bright)`, because the tray draws the same fork.

**The tray: the fork waits with the genes.** `Genome/Waiting` gets **one fork
chip per open fork, after the waiting genes**. The tray is where this screen
keeps what waits for the player, and a fork does. The chip is 116 x 48,
`FOCUS_ALL`, `MOUSE_FILTER_STOP`, **not draggable and never a drop target**:

| part | value |
| --- | --- |
| glyph | `draw_fork` over `along` 28..88 (a lobe, a half, the parting) at scale 0.5, origin (7, 22): chip x 7..37 |
| word | 14 px at x 44, baseline 27, `LABEL_TINT`; loud while the view is open |
| level | 12 px, `Color(hue, 0.95)`, 6 px after the word. `venom 99` ends at 111 of 116 |
| open | underline x 6..110, y 45, 1.5 px, `Color(hue, 0.55)`: the gene-in-hand mark |
| dim | `WAIT_DIM` while a waiting gene is in hand, like every other chip in the tray |

`waiting` captions the tray whenever anything is in it, a fork included. Four
genes and a fork wrap to a second row: `A08`'s height, which fits.

**The fork view.** A tap on the fork chip swaps the figure for two cards
(`M06`, `M07`). So does a second tap on the forking slot, when nothing is in
hand. `Genome/Fork`, a `Control` 420 x 372 beside `Figure`, takes its place,
and exactly one of the two is visible, so the column does not move:

```
Genome/Fork   Control 420 x 372, MOUSE_FILTER_IGNORE, hidden unless open
  Way0        Control 200 x 290 at (0, 41), STOP, FOCUS_ALL   paths[0], extend
  Way1        Control 200 x 290 at (220, 41)                  paths[1], sweep
```

The cards sit at canvas x 578..778 and 798..998, y 213..503 (x +160 at
2400x1080), 49 px clear of the tray and of `Explain`. They are 300 x 435 device
px on a phone.

| a card | value |
| --- | --- |
| surface | `StyleBoxFlat` bg `Color(0.063, 0.141, 0.125, 0.90)`, border 1 px `Color(0.12, 0.70, 0.58, 0.26)`, radius 6. **Opaque on purpose.** Full vision pins the ghost of the player's cell to x 640, inside the left card. On a clear patch of that card, at the slab's usual 0.45, it reads 23.5 with a 36.5 peak where the ghost's rim shows through (`M06_fv`). At 0.90 it reads 29.9, peak 32.5, against a flat 29.7 in point of view |
| picture | the tile organ (`draw_tile_organ`, scale 1.0) at (100, 154); rays from (100, 146), drawn 16..110 px out, 2 px, `hue` 0.30 at the root to 0.85 at a 2.2 px tip dot |
| its content | **the beam that path gives at `max(level(), FORK_LEVEL + 1)`**, from `CellBody.beam_shape()` and stepped by a `ray_fan.gd`, so the card is the water's own beam. Fill: that many rays, still. Sweep: three rays at the real rate, each over its sector (filled `hue` 0.06), with three trailing copies 0.03 s apart at 0.45, 0.25 and 0.12 of the ray's ink. Stepped on wall time while open, because single player has stopped the tree |
| title | 20 px, `Color(hue, 0.95)`, centred, baseline 188 |
| pro, con | 14 px, `EXPLAIN_TINT`, centred, baselines 216 and 238 |
| cost | 14 px, 0.38, centred, baseline 266 |
| focus | `FOCUS_TINT` underline, inset 14, y 284: the chips' mark, not a box |
| armed | border 2 px `Color(hue, 0.85)`; the other card's ink x 0.55 |
| hover | no restyle, as a chip: the lines below describe the hovered way |

Its words belong at the edge (`normal_mode.gd`), not in `progression.gd`. The
two names are the owner's call (§8.9):

| path | title | pro | con | cost |
| --- | --- | --- | --- | --- |
| `extend` | `fill` | `every ray lit, all the time` | `small things slip between` | `costs more to keep` |
| `sweep` | `sweep` | `no gaps between rays` | `shows where things were` | `costs less to keep` |

**The three lines keep their jobs** while the view is open:

| | nothing armed | a way hovered or armed |
| --- | --- | --- |
| `Explain` | the gene's own line | `fill · a new ray every level, filling the fan` / `sweep · your three rays swing, faster every level` |
| `Hint` | `level 5 ▰▱ · works as level 3 until you choose`; at level 3 itself, `level 3 ▱ · both ways start at the next level` | `level 5 ▰▱ · costs more to keep than sweep` / `· costs less to keep than fill` |
| `Act` | `tap a way to choose it` | armed: `tap again to choose sweep · for good` |

**At level 3 the two ways draw the same beam**: three rays, and a sweep of 0°/s
(§4.1–§4.3). That is why the cards draw level 4 there, and why the hint says a
choice made at 3 changes nothing until 4.

**Choosing is the pause screen's one confirm, unchanged in kind.** Tap a way to
arm it; tap it again to choose it for good. `ARM_GUARD_MS` 300 lies between the
two taps, and `ARM_TIMEOUT_MS` 4000 disarms it on its own. The second tap
commits on the **lift, inside the card**, like a slot's, so sliding off
cancels. A tap on the other way arms that one instead.

| | touch | mouse | keyboard |
| --- | --- | --- | --- |
| open | tap the fork chip; or, nothing in hand, tap the forking slot again once it is selected | click, the same | `Enter` on the fork chip (Tab reaches it after the waiting genes), or on the selected forking slot. Focus goes to `Way0` |
| read a way | tap it: it arms, which is harmless | hover | `←` `→` between the cards |
| choose | tap the armed way again | click it again | `Enter` on the armed way |
| leave it | tap the fork chip, or any waiting gene (it goes in hand) | the same | `Esc` shuts the view only; a second `Esc` resumes (`dna-body.md` §8's rule). Focus returns to the fork chip |

**What it cannot collide with:**

- **Placement.** The view hides every slot, so nothing can be armed or written
  while it is open; opening it disarms any armed slot, and the gene in hand
  comes back with the figure. With a gene in hand, a tap on the forking *slot*
  is the placement's first tap, as it is today, and §8.2's warning names the
  level at stake. The fork is reached from the tray then. That is why the tray
  carries it.
- **The drag.** The fork chip neither drags nor takes a drop. A press on a
  waiting gene shuts the view first, so its drag lands on the figure.
- **The slot's second tap.** With a gene in hand it places; with none, and the
  slot's fork open, it opens the view; otherwise it does nothing, as today. The
  300 ms guard covers both, so a touch and the mouse click Godot emulates from
  it cannot select and open in one press.
- **A pond.** The view is held by gene, like the gene in hand (`dna-body.md`
  §5.1), so a tray rebuilt under it keeps it open.

**After choosing**: `_genome.choose(gene, path)`. The view shuts and the figure
comes back with that slot selected, as a receipt, the way a placement leaves
one. Its strands close, its numeral goes pale, and its tray chip leaves (the
tray keeps its height). `Explain` gives the path's line, a new
`EXPLAINS_PATH`: `ocellus · a fan of rays out of that side, one more every
level` and `ocellus · three rays sweeping that side, faster every level`, 464
and 446 px with their names.

**What pause opens on.** With a gene waiting, the head in hand, as today.
Otherwise the first slot with an open fork, selected, with `Act` reading
`tap again to choose how beam grows`. Otherwise the first gene carried, as
today (§8.9 row 3).

### 8.4 In play: a choice is waiting, and the eye buds

No word, and no rhythm: the second heartbeat means a gene is waiting, which
lapses, and a fork never does. **The eyespot doubles**, like an organelle
about to divide. The single pigment disc that `_draw_earned` draws becomes
two, side by side along the arc (`E02`, `F02`). It is `cilia.gd`'s one routine,
so both views draw it. It is passed only for the player's own cell, by a new
`eye` argument to `draw_cell`, as `draw_pending` takes `offer`: no other
cell's level is known, and the friend's is not on the wire (§6).

| | value |
| --- | --- |
| lobes | two, `0.15 r` each (core `0.075 r`), at `± r × (0.10 + 0.02 × min(banked, 4))` along the arc from the usual seat; `banked = level() − FORK_LEVEL` |
| ink | the pigment's own, x `BUD_INK` 1.2 |
| shimmer | in antiphase, x `1 ± 0.2 sin(2π t / 2.4)`, on the body's own `clock` |
| while | the body wears the gene and its fork is open |

**Measured, it loses to every sensation** (point of view, 1280x720, σ = 6
glance, frames reproduced to 0 pixels). The eye at rest is 55.6. Budding, it
is 56.5, and **58.9 at its brightest phase**: under dread's 60 and a beam
return's 67. A ±0.3 shimmer reached 60.9, a dead heat with dread, which is the
measurement `soma.gd` moved `FADE_PENDING` for. So it says *changed* by shape,
not loudness, and the longer a fork is left, the further apart the lobes sit.

**The pause target breathes once when a fork opens** (§8.9 row 4). That is on
the level-up that reaches `FORK_LEVEL`, once per lineage: a daughter who
inherits an open fork is not told again. It goes to its hot state
(`gene-lines-and-the-pause-target.md` §4.1) over 0.3 s, holds one beat, and
settles over 1.5 s. It is the only thing in the water that points at pause.

### 8.5 In play: a level up, and the eye flares

On the first beat after `level()` rises, and after a path is chosen, when the
banked levels land at once, the eyespot flares for 1.2 s: 0.15 s up, then
1.05 s down on `1 − smoothstep` (`E03`, `F03`). At the peak the pigment is
drawn solid, the whole organ's ink x 1.35, its haze 1.5x wider and twice as
dense, and its bristles 30 % longer. Same routine, both views, own cell only.

Measured at the peak: 86.6, against the resting eye's 55.6. That is a clear
flicker on your own body, above a beam return for a second and far under a
taste band's 136. The first cut, ink x 2, reached 111: a flash, not a feeling.
Past the fork, the beam changes too: full vision draws one more ray or a faster
sweep, and point of view gets more marks. A banked level flares as well. The
replay flares when the level it is handed rises, never on a seek.

### 8.6 The choosing screen

**The level goes in the lines, not on the strands** (`C01`). Both daughters
carry the same level for every gene they share. A mark on both strands would
say that twice (`choosing.md` §5's reason for one shared row), and the block
has 3 px of word budget left.

- `Hint`: `worn · level 7 · one copy · a daughter may not wear it`, from the
  mother's `level()`; a gene drifted in reads `level 1`. The widest,
  `carried · level 12 · two copies · a daughter probably wears it`, is 400 px,
  centred and clear of both blocks.
- `Explain`: the chosen path's line (§8.3). An open fork reads as no path yet.

The daughters differ in level only when **a drift replaced the levelled gene**
in one of them: that daughter has lost it. Her strand already shows a
different word and hue with the caret, and reading the other daughter's locus
gives the level at stake. §8.8 leaves open whether that is enough.

### 8.7 Rendered

Mocks, point of view unless noted. `G` is `dna-body.md` §11's; the choosing
frames use `choosing.md` §10.1's recipe with `ocellus:1:3` in the DNA.

| frame | shows | judgement |
| --- | --- | --- |
| `pause`, `choose` | the screens as shipped, and the space measured here | baseline |
| `ctl` | the harness with nothing mocked | 0 px from `pause`: the overlay moves nothing |
| `M01` (both shapes) | `7` in the beam chip's third lobe, selected | passes |
| `M02` | 1, 11 and 99 | passes |
| `M03` | the numeral after the pips | rejected, §8.1 |
| `M04` (both) | the fork open: strands parted, tray chip, level and gauge, the `Act` line | passes |
| `M04b` | the same with `ping` waiting: `waiting`, `ping`, then the fork chip | the tray passes; its lines are the mock's, not the design's |
| `M05` | level, gauge and odds | passes |
| `M06` (both; full vision) | the fork view, nothing armed | **failed first**: in full vision the player's ghost showed through the left card. Passes opaque |
| `M07` (both) | `sweep` armed | passes |
| `M08`, `M09` (both) | `venom`, three copies, 99, with and without the fork | passes, once the prong tips came in 2 px |
| `C01` (both) | the choosing lines with level 7 and a path | passes |
| `E01`–`E04`, `F01`–`F03` | the eye at rest, budding and flaring, in point of view and full vision | pass at §8.4–§8.5's numbers. Full vision was judged by eye |

**The build shoots these again** on the real code, at both shapes and in both
views, with `--level=ocellus:5` (fork open, two banked) and
`--level=ocellus:8:sweep` / `:extend`. That includes the gestures: `--touch=`
the selected beam chip (938,204; 1098,204 on a phone) to open the view, a card
twice, 0.3–4 s apart (678,358 and 898,358, +160), to choose, and `Enter`, `←`
`→` and `Esc` by `--tap=`. `--rects=` gains `Fork`, both ways and the fork
chip. It measures the glance of §8.4–§8.5 again, from its own frames. The
pause target's breath was not mocked; its hot state is §4.3's measured 87.

### 8.8 Left open

1. **A drift that takes a levelled gene** is marked the way any drift is
   (§8.6). If a lost level 12 reads too quietly, the replacement's hint could
   say so.
2. **A levelled gene only the body wears**, after the DNA wrote over it, keeps
   its level for this life and has no slot. The body's word names it
   (`dna-body.md` §4) without a level. An open fork it has is still in the
   tray.
3. **More than two paths** would need narrower cards. Nothing specified needs
   them.

### 8.9 Owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | What are the two ways called? | **fill and sweep ✓ recommended** · extension and sweep · more rays and sweep | The two words on the choice cards. "fill" says what happens: each level adds a ray between the ones you have, so the fan fills in and never gets wider. "extension" is your word, but it can read as a longer beam, and neither way makes it longer |
| 2 | Where does a gene's level show on its slot? | **a small number inside the slot's twist of DNA ✓ recommended** · a number after the three dots · no number on the slot, only in the line below | You see `7` framed by the DNA beside its rungs, apart from the dots, which stay the copies. After the dots, `●•• 7` looks like a count of dots, and the longest gene name leaves no room for two digits |
| 3 | When a choice is waiting and no gene is, what does pause open on? | **your body, with the beam already picked ✓ recommended** · straight onto the two choice cards | Recommended: pause looks as it does now, with the beam lit, and one more tap brings up the two ways. Opening on the cards puts the choice in front of you on every pause, even one to change the light |
| 4 | Should the pause button glow once when your beam can grow? | **yes, once per choice ✓ recommended** · no, the eye alone | For about two heartbeats the pause button in the corner lights up. It is the only sign in the water that pause has something new. Without it the only sign is your eye doubling, which you may not connect with pause |

---

## 9. Measured

*Filled in by the build.* It will cover:

- the run that sets `STEP`;
- the frame cost of `_step_beams` at 3, 10 and 20 rays;
- 0-pixel reproducibility before any A/B;
- both paths at level 8 in both views at both shapes;
- the pause screen with the fork offered;
- net_probe's `referee` section passing untouched.
