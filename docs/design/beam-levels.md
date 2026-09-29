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

Status: **built.** The mechanics (§1–§7) and the screens (§8) are in the game;
§9 is what was measured.

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
(`returns.gd`) and full vision's hit dots. A ray leaves **one mark per 2° of
its travel**, the field's own sub-step, not one a frame: per frame, a 60 fps
phone held twice a 30 fps one's marks and hit the cap first, so the faster
phone showed the shorter trail. So does the membrane's beam lobe,
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
  `BEAMS = 3` rays a frame. Raise it to **24**, in the field's own order while
  they fit -- a slot must be the same ray frame after frame, or playback lerps
  one ray into another -- and hits first only past 24, so a crowded fan keeps
  what it found. That is 63 more floats a frame, about
  0.9 MB more ring over a 60-second window. The ring lives in RAM and is never
  saved, so no old recording is at risk. `three-senses.md` §3.3 named this and
  left it to the builder; this is the decision.
- A sweep's fade is drawn by the views from the frames they are given, so a
  replay shows it too. On a seek, the views drop their held marks rather than
  fading ones from another moment.

---

## 8. The screens

*The UX designer's.* **Built**, on the recommended answer to every row of
§8.9, each behind one constant. It was designed on mocks -- a scratch overlay
drawn over the real screens -- and §8.7 is now the real code, shot again at
1280x720 and 2400x1080, with the command for every frame. Where the build had
to decide something this section left open, the paragraph says so under
**Built:**.

**The pips stay the copies. The level is a number, and the number never sits
in the pips' row.** (`dna-body.md` §3.1 called the pips "the level"; they were a
copy count then and still are, and it calls them the copies now. From here on
*level* means only the number.)

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

**Built:** the armed preview of a gene in hand draws a numeral only when that
gene already has a level -- its body still wears one -- because a gene arriving
fresh has none until it lands. The numeral and the word share one tint helper,
so the two cannot drift apart.

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

**Built:** alone, `Text` fills the row and centres itself, exactly as the label
it replaced did, so a screen with no level on it lays out to the pixel as it
always has (§8.7's A/B); beside a level it shrinks to its words and the row
centres the three. The one rebuild under a pond's menu is a fork opening there,
because the tray has a chip to grow (`P01`).

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

**Built:** where this section left something to decide, the build decided:

- `Cilia.draw_fork` parts the strands at **the last crest before `to`**, where
  they already run level, so the parting leaves the helix without a kink.
  `from` and `to` are in the helix's own `along`, so it meets `draw_weave`
  exactly.
- **A way's price is read off the prices**, not written down: the card's
  `costs more/less to keep` and the hint's comparison come from
  `CellBody.levelled_upkeep` at the cards' level, so if X and Y ever move so
  far that the ways trade places, the words trade with them.
- **The fork chip answers on the lift, inside the chip**, as a slot's second
  tap lands, and `Enter` on the press. It first answered on the press, and a
  review found one tap arming a card: a touch arrives twice -- the click Godot
  emulates from it first -- and the cards, hidden since the screen was built,
  had never been laid out, so the touch copy was hit-tested against a card
  still sitting at the column's origin, over the chip. A card now also takes no
  pointer event in the frame the view opened.
- **A cancelled lift commits nothing**, here or on a slot: Android ends a
  gesture the system takes away (a call, the shade, a back swipe) as every held
  finger lifting with `canceled` set, and the emulated click carries the flag.
- **While the cards are up the fork chip carries the in-hand mark**, and the
  waiting gene in hand is drawn stepped back: one thing in the tray is being
  decided at a time. The hand is kept, and comes back with the figure.
- A tap on the forking slot hides the slot the keyboard was on, so the keyboard
  goes to the fork chip, the view's way back; `Enter` puts it on `Way0`. A card
  the keyboard is on reads as a hovered one does: that is `←` `→` reading.
- **Android Back does what `Esc` does**: the view first, then pause.
- `light` backs into whichever of the figure and the cards is showing, so
  Shift-Tab never lands on a hidden chip.
- The cards' fans step on the run node's own frame delta, which a paused tree
  still hands it: they move while single player is stopped, and they repeat
  to the pixel under `--fixed-fps`, which a clock read by hand would not.

### 8.4 In play: a choice is waiting, and the eye buds

No word, and no rhythm: the beat carries hunger and nothing else (the owner,
2026-09-29), so a fork is read off the body, as a waiting gene and a coming
division are. **The eyespot doubles**, like an organelle
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

**Built:** the flare and the breath are armed by the level-up and cued by
**the first heartbeat the body is on screen for** -- no menu over it, alive,
short of the pinch -- so a level earned under a pond's menu, or a way taken on
the pause screen, flares on the first beat back in the water. The breath rises
on that same beat and holds for the period the body is beating at. Both are
`game/mechanics/swell.gd`, a one-shot envelope that knows nothing about eyes.
`tools/drive.gd --earn=` poses a level-up through the run's own door, `_earn()`,
which is how `E03`, `E04` and `B01` are shot.

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

**Built:** the organ's ink is clamped only once the view's fade is in: point of
view draws the body at a third, and clamped before that the flare measured 76
of glance rather than 82. **The replay needed one
line in `recorder.gd`**: it signed a genome by the level held at the fork, so a
level earned past an open fork wrote no delta and a watched run could neither
flare for it nor move the bud's lobes apart. It signs `level()` now; the held
level only ever moves when that one does, or with the path. The replay's flare
runs on the replay's clock, slower at ½x and ¼x, and a rewind learns the levels
afresh without flaring.

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

**On the real code.** Every frame is `tools/shot.tscn` driving
`tools/drive.tscn`, at 1280x720 and -- marked *both* -- at 2400x1080 as well,
where every canvas x below is 160 further right:

```
xvfb-run -a -s "-screen 0 1280x720x24" ~/godot/godot --path . \
    --rendering-driver opengl3 --fixed-fps 60 res://tools/shot.tscn -- \
    --scene=res://tools/drive.tscn --out=/tmp/frame.png --size=1280x720 \
    --wait=<wait> <flags>

G    = --genome=cytostome:2,cirrus:1,flagellum:3,ocellus:1:3 --radius=34 --esc-at=1.0 --seed=7
W    = G without --esc-at: in the water
F5   = --level=ocellus:5 --earn=0.5:ocellus:100     fork open, two banked, half a level on
CH   = --seed=12345 --radius=40 --dna=cytostome:3:0,cirrus:2:1,flagellum:3:2,
       ocellus:1:3,ampulla:2:4,pellicle:1:5,toxicyst:2:6    choosing.md §10.1, beam at 3
OPEN = --touch=1.5:938,204    ARM = --touch=2.0:898,358    TAKE = --touch=2.6:898,358
PEAK = --arm-at=2.0 --freeze-on=beat --freeze-after=0.15
```

Point of view (`--mode=0`) unless a frame says full vision (`--mode=1`).

**Reproducible first**, three runs each and 0 pixels apart: the shipped pause
screen, the fork view at both shapes in both views, the flare at both shapes,
and a real pond (`P01`). The cards' fans step on the run node's own frame
delta, so `--fixed-fps` holds them still between runs.

**Nothing changed for a player without a levelled gene.** Thirteen commands on
the commit this started from and on this build, diffed: **0 pixels in every
one** -- the pause screen for `cytostome:2,cirrus:1,flagellum:3` in both views
at both shapes, a pause with two genes waiting and an `ampulla` at both shapes,
the choosing screen on `choosing.md` §10.1's recipe in both views, and play in
both views at both shapes. Also 0: play with a level-1 beam in full vision, and
a level-2 beam's resting eye (`E01`) in point of view.

| frame | wait, flags | shows | judgement |
| --- | --- | --- | --- |
| `M01` *both* | 2.0 `G --level=ocellus:7:extend --touch=1.4:938,204` | `7`, pale, in the selected beam chip's third lobe; the path's line in `Explain` | passes |
| `M02` | 2.0 `G --level=ocellus:1` / `:11:extend` / `:99:sweep`, `--touch=1.4:938,204` | 1, 11 and 99 | passes: all inside the lobe, and a `1` is not a rung |
| `alt_after_pips` | `M01`, with `LEVEL_SEAT := LevelSeat.AFTER_PIPS` | owner's call 2 answered the other way: `beam ●•• 7` | renders; rejected, §8.1 |
| `M04` *both*, both views | 2.0 `G F5` | pause opened on the forking slot: strands parted, `5` in the hue in the fork's mouth, the tray chip, `level 5 ▰▱`, `tap again to choose how beam grows` | passes; in full vision the ghost buds too, in the ring's empty cell |
| `M04b` *both* | 2.0 `G F5 --sample=ampulla` | `waiting`, `ping` in hand, then the fork chip stepped back to `WAIT_DIM` | passes |
| `M04c` | 2.0 `G --level=ocellus:3 OPEN` | at the fork itself: both cards at level 4, `level 3 ▱ · both ways start at the next level` | passes |
| `M05` *both* | 2.0 `G` with `ocellus:2:3`, `--level=ocellus:7:extend --earn=0.5:ocellus:150 --touch=1.4:938,204` | `level 7 ▰▰▱ · two copies · a daughter probably wears it` | passes |
| `M06` *both*, both views | 2.0 `G F5 OPEN` | the cards, nothing armed: the gene's own line, `works as level 3 until you choose`, `tap a way to choose it` | passes. Full vision: the ghost is gone behind the left card, which reads 30.8 over its seat against point of view's 30.5, no pixel more than 6 of 255 apart |
| `M07` *both* | 2.4 `G F5 OPEN ARM` | `sweep` armed: 2 px border in the hue, `fill` at 0.55, `costs less to keep than fill`, `tap again to choose sweep · for good` | passes |
| `M07b` | 2.4 `M07 --hover=2.2:678,358` | the mouse reading `fill` while `sweep` is armed | passes: the two lines follow the hover, `Act` keeps the armed way, nothing restyles |
| `M07c` *both* | 3.0 `M07 TAKE` | taken: the figure back with the slot selected as a receipt, strands closed, numeral pale, the tray empty at its height, `ocellus · three rays sweeping that side, faster every level` | passes |
| `M08`, `M09` *both* | 2.0 `G` with `ocellus:3:3`, `--level=ocellus:99`, and `:99:sweep --touch=1.4:938,204` | the widest chip this build can make, `beam ●●● 99`, with and without its fork; `level 99` in the row | passes. `venom` does not level, so the mock's `venom 99` stays §8.1's arithmetic |
| `M10` | 2.0 `G --level=ocellus:7:extend --sample=ampulla --touch=1.4:938,204` | armed over the beam with `ping` in hand: `beam leaves your dna · level 7 ends with this body`, no gauge | passes |
| `M10b` | `M10 --body=cytostome:2:0,cirrus:1:1,flagellum:3:2` | the same over a beam only the DNA carries: `its level 7 is lost` | passes |
| `M11` | 2.0 `G F5 --sample=ampulla,trichocyst:2,chemocyte,pellicle` | four genes and a fork: the fork chip wraps to a second row | passes, at `A08`'s height |
| `K01`–`K05` | 1.8–3.1 `G F5` with `--tap=` | Tab Tab Enter on the chip opens with the keyboard on `fill`, reading it; `→` Enter arms `sweep`; `Esc` shuts the view, keyboard on the fork chip; `Esc` resumes; Tab x4 then Enter on the selected slot opens too | pass |
| `K06`, `K07` | 2.4 `G F5 OPEN ARM --back-at=2.2`; 2.9 the same and `--back-at=2.6` | Android Back with `sweep` armed shuts the view, nothing taken, keyboard on the fork chip; a second Back resumes, the eye still budding | pass |
| `alt_opens_on_cards` | `M04`, with `PAUSE_OPENS_ON_CARDS := true` | owner's call 3 answered the other way | renders |
| `P01` | 3.0 `W --level=ocellus:2 --pond=host --esc-at=1.0 --earn=2.0:ocellus:80` | a real pond: the fork opens under the open menu, the tray grows its chip and the slot parts; the selection stays where the player was reading | passes |
| `L8_*` *both*, both views | 2.0/3.0 `G`/`W --level=ocellus:8:extend` and `:8:sweep` | `8` on the chip and each path's line; in the water, eight rays filling the fan against three sweeping | pass |
| `C01` *both* | 6.0 `CH --level=ocellus:7:extend --touch=5.5:340,328` | `ocellus · a fan of rays out of that side, one more every level` over `worn · level 7 · one copy · a daughter may not wear it` | passes: centred, clear of both blocks |
| `C02` | 6.0 `CH --level=ocellus:5 --touch=5.5:340,328` | an open fork reads as no path yet, at `level 5` | passes |
| `E01`, `E02`, `E03` *both*; `E04` | 3.0 `W --level=ocellus:2 --freeze-at=2.5`; 3.5 `:5 --freeze-at=3.0`; 6.0 `:6:sweep --earn=2.0:ocellus:240 PEAK`; 6.0 `:4 --earn=2.0:ocellus:200 PEAK` | the eye at rest, budding at its brightest phase, at the top of a flare, and a banked level flaring on a budded eye | pass, at the numbers below |
| `F01`–`F03` *both* | the same, full vision | the same three | pass, by eye: one routine, both views |
| `B01` *both* | 6.0 `W --level=ocellus:2 --earn=2.0:ocellus:80 --arm-at=2.0 --freeze-on=beat --freeze-after=0.6` | the level-up that opens the fork: the eye flares as it buds, and the pause target is in its breath's hold | passes |
| `R01`, `R02` | 11.5 `W --level=ocellus:6:sweep --earn=2.0:ocellus:240 --kill-at=5.0 --touch=8.5:640,360 --freeze-at=10.45` / `10.75` | `watch`: the replay just before and at the recorded level-up's flare | pass: both panes flare |

**Measured**, the σ 6 glance, point of view, 1280x720, over the eye (x 650..700,
y 300..350) and, for the breath, over the pause target's corner:

| | the mock | this build |
| --- | --- | --- |
| the eye at rest | 55.6 | 55 |
| budding | 56.5 | 56 |
| budding, at its brightest phase | 58.9 | 59 |
| at the top of a flare | 86.6 | 82 |
| a banked level flaring on a budded eye | -- | 85 |
| the pause target breathing, its corner | hot 87 (§4.3) | 84, against 31 at rest |
| the replay's flare, point of view / full vision | -- | 56 to 83 / 120 to 159 |

The flare comes in 4.6 under the mock -- and still above a beam return's 67 and
far under a taste band's 136, which is what §8.5 asks of it. It measured 76
before the organ's ink was clamped after the view's fade rather than before
(§8.5, **Built**).

**The rects** (`--rects=`, 1280x720): `Fork` is 578..998 x 172..544, `Figure`'s
own rect to the pixel, so the column never moves; `Way0` is 578..778 and `Way1`
798..998, both 213..503; the fork chip is 116 x 48; the hint row stays 20 tall,
its `Level`, `Gauge` and `Text` centred as one group.

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

**Decided on 2026-09-29: the recommended option, all four rows** -- "Recommended
for all". That is what was built, so nothing changed but this line and the
constants' comments.

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | What are the two ways called? | **fill and sweep ✓ recommended** · extension and sweep · more rays and sweep | The two words on the choice cards. "fill" says what happens: each level adds a ray between the ones you have, so the fan fills in and never gets wider. "extension" is your word, but it can read as a longer beam, and neither way makes it longer |
| 2 | Where does a gene's level show on its slot? | **a small number inside the slot's twist of DNA ✓ recommended** · a number after the three dots · no number on the slot, only in the line below | You see `7` framed by the DNA beside its rungs, apart from the dots, which stay the copies. After the dots, `●•• 7` looks like a count of dots, and the longest gene name leaves no room for two digits |
| 3 | When a choice is waiting and no gene is, what does pause open on? | **your body, with the beam already picked ✓ recommended** · straight onto the two choice cards | Recommended: pause looks as it does now, with the beam lit, and one more tap brings up the two ways. Opening on the cards puts the choice in front of you on every pause, even one to change the light |
| 4 | Should the pause button glow once when your beam can grow? | **yes, once per choice ✓ recommended** · no, the eye alone | For about two heartbeats the pause button in the corner lights up. It is the only sign in the water that pause has something new. Without it the only sign is your eye doubling, which you may not connect with pause |

The build took the recommended option in every row, and each other answer is
one line in `game/normal/normal_mode.gd`: 1, `PATH_TITLES`, the one table the
cards' titles and every line about a way read; 2, `LEVEL_SEAT` (`LOBE`,
`AFTER_PIPS`, `NONE`); 3, `PAUSE_OPENS_ON_CARDS`; 4, `PAUSE_BREATHES_AT_FORK`.
Rows 2 and 3 were flipped and rendered to prove it (§8.7, `alt_*`), then put
back.

---

## 9. Measured

All under Godot 4.7.2, `--fixed-fps 60`, on this container. Section 8's
screens are measured in §8.7.

### 9.1 `STEP`: the run that sets it

`tools/drive.gd --sniff` is the harness's forager, and it steers by smell
alone. It was given a nose and a beam dead ahead:
`--genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1:1,ocellus:1:0 --sniff
--trace=5`, seeds 1–8, six to ten minutes each. Only the first life counts,
because a death is a clean restart and takes the level with it. Seconds to
reach each level:

| `STEP` | level 2 | the fork (3) | seeds that reached it |
| --- | --- | --- | --- |
| 60 | 155–275, median ~185 | 235–260, median ~255 | 6 and 3 of 8 |
| **40, shipped** | **100–185, median ~145** | **150–225, median ~195** | 7 and 6 of 8 |

The bot does not aim. A player who turns the beam onto things earns faster,
so ordinary play should reach level 2 in about a minute and the fork in about
three. Level 1 is the slow stretch: one ray earns the bot about 0.35 a second,
two rays about 1.5, and three sit near the cap of 3. Past the fork, banked
levels came every 45–90 seconds (seeds 4, 6, 7 and 8). At the cap that puts
level 10 about ten minutes past the fork and level 20 about 40, before either
path's upkeep makes holding one hard.

### 9.2 The beam's frame cost

`--field-cost=1200`, seed 5: the field's whole frame, p50 over 1200 frames,
twice each.

| beam | p50 | vs no beam |
| --- | --- | --- |
| none | 507 µs | — |
| level 3, 3 rays (**dev's tier 3: 576–592 µs**) | 569 µs | +62 |
| level 10, fill, 10 rays | 600 µs | +93 |
| level 10, sweep | 598–607 µs | +96 |
| level 20, fill, 20 rays | 643–656 µs | +143 |

The skip of §4.4 more than pays for itself: three rays cost less than they
did before it. Twenty rays add 0.14 ms to a 16.7 ms frame here. A low-end
phone should be measured before a player reaches level 20, which is hours
away.

### 9.3 What did not change

- **Reproducible first**: one frame rendered three times, in each view,
  differs by 0 pixels.
- **A cell without a beam**: `--genome=cytostome:1,cirrus:1,flagellum:2,
  stigma:1:3,chemocyte:1:4,ampulla:2:2 --seed=11` renders **0 pixels**
  different from dev (`5793ca9`), in both views.
- **A level-1 beam is the old tier-1 beam**: `ocellus:1:0` with two bodies
  parked in it, `--cell=2,200,4,20 --cell=3,420,-3,24`, lit and hitting, is
  **0 pixels** different from dev in both views.
- **The wire**: net_probe `ALL PASS`, including the `referee` section's
  fingerprint of `Wire.RULES`. net_fuzz `--seed=1` and net_drop pass in their
  own network namespaces, as CI runs them.
- `tools/levels_probe.gd`: 38 checks, `ALL PASS`, in CI.

### 9.4 Both paths at level 8

`--level=ocellus:8:extend` and `:sweep`. Upkeep reads 2.26 and 1.81, which is
§5's table. Frames in both views, at both shapes:

- **Full vision**, four bodies parked in the fan at 250–520 units: fill's
  eight rays pass either side of a radius-16 body at +16°, which is 3.7° wide
  against the rays' 14.3° spacing, and **never see it**. Sweep lights all four
  and leaves each one's held marks on its near edge. This is the trade in one
  frame pair.
- **Point of view**, four bodies at 95–130 units: fill leaves one clean mark
  per ray that lands, five on four bodies. Sweep draws **an arc of fading
  marks along each body's near edge**, brightest where the ray has just been:
  a radar scope, and honest that the marks are a pass old. The same arcs sit
  in the same places at 2400x1080.
- **The replay**, raised over a live sweep (`--panes=2.0`): both panes draw
  the held marks, each in its own register.
