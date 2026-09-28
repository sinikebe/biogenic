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

**To be written by the UX designer.** The mechanics need these things from
the screens:

1. **A gene's level is visible** wherever the gene is read: its slot on the
   pause screen, and the lines under the figure. The three pips stay the copies
   (`dna-body.md` §3.1). Copies and level are now two different numbers, and
   they must not be confused.
2. **Progress toward the next level** is readable on the pause screen.
3. **The fork is offered** when the beam reaches level 3 with no path: which
   two, what each one does, and a confirm, because the choice is permanent.
4. **The player learns in play that a choice is waiting**, with no new text
   on the sensory screen: `perception.md` §6.1 allows exactly one string there,
   and `genes-and-cilia.md` §8 kept it that way. Words belong on the pause
   screen.
5. **A level-up is felt in play**, however quietly.
6. **The choosing screen** shows, or deliberately does not show, the level each
   daughter would inherit. Both daughters inherit the same level.

Everything is rendered at 1280x720 and 2400x1080 and judged before it is called
done.

---

## 9. Measured

*Filled in by the build.* It will cover:

- the run that sets `STEP`;
- the frame cost of `_step_beams` at 3, 10 and 20 rays;
- 0-pixel reproducibility before any A/B;
- both paths at level 8 in both views at both shapes;
- the pause screen with the fork offered;
- net_probe's `referee` section passing untouched.
