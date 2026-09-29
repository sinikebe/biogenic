# The drop: a finite ocean, and everything in it all the time

Pack 1 of the owner's evolving-water feature. The owner, verbatim:

> I want to make the AIs logic evolving. By that I mean random logic at the
> start, then each cell that divides carries genes but also behavior logic (AI)
> with small mutations. This should make the cell dangerousness improve with
> time not only because of genes, but also from a kind of learning.
> And while we're at it, we could propose to players a screen where they can use
> the same logic blocks to automate their cell ! Offering a new gameplay type.
> Both should use the same logic system.
> Maybe one start point is to make the ocean finite. I don't know the current
> state but I never reached the end […]
> Then, we need rules to spawn cells when they are not enough in the water, so
> there's always enough population to not starve and/or loose genes.
> That also may require food objects that are not alive, that we can dispose
> where there's few cells. It's logical since no eater means more edibles
> available at this place, and it allows the player to have a chance to survive
> empty environments.
> We won't make all at once. And we will release things as packs to prevent an
> all in one release.

The owner approved the pack order ("All recommended. design pack 1"), each pack
shipped on its own and played on the dev app before the next starts:

1. **Pack 1, this document: the real ocean.** A finite size, cells that persist,
   spawn rules, and food that isn't alive.
2. Water cells divide, passing on their genes.
3. Behaviour blocks with mutation replace the hand-written AI.
4. The player's own block screen, built from the same blocks.

**Status: designed, prototyped and measured; nothing here is built.** The
prototype is a scratch copy of the game outside the repository, on `eb4dbf1`
(`dev`), switched on by `--ocean` after the `--` so that every run without it is
the shipped water. Every number below was measured on it in this container
(Intel Xeon at 2.1 GHz, 4 vCPU, Godot 4.7.2, headless or under xvfb with
`--rendering-driver opengl3`); nothing ran on a phone. §15 has every command.
The builder builds it for real and shoots §3.4 and §7.6 again.

"Ocean" is the owner's word. This document calls the place **the drop**, because
that is what it is under a microscope and because "pond" already names the
shared pond; row 3 of §17 asks the owner to choose.

---

## 0. What the water is today, against the brief

Verified in the code at `eb4dbf1`. The brief was right on every point; three
findings sharpen it.

- **There is no ocean.** `food.gd` keeps `COUNT` = 34 bodies (`:107`) within
  `CULL` = 1,700 µm of the player (`:490`). A body past it is reseeded at once
  (`_step_recycle`, `:2559`) at a random angle `RING_MIN`–`RING_MAX` = 920–1,350 µm
  out (`:488`), and so is every body eaten (`_consume`, `:1998`). A division runs
  `_food.setup(_cell)` (`normal_mode.gd:1637`), which throws the field away and
  seeds a new one, then puts the sister 560 µm off (`:1642`, `SISTER_DISTANCE`
  `:206`). One world unit is one µm; full vision is unzoomed (`vision.gd:65`).
- **The water reseeds about a hundred bodies a minute round a foraging player**,
  measured: 265 culls and meals in 158 s on seed 3 of the forage bot below, plus
  34 more at every division. Every one of them appears 920–1,350 µm away -- off the
  screen, but inside a tier-1 nose or `ampulla` (1,100) and inside dread
  (`DREAD_RANGE` 1,400, `:508`). **The bubble pops things into the senses all the
  time**; the only rule it keeps is the screen.
- **Its real density is not the nominal one.** 34 bodies over a disc of 1,700 is
  3.74 per million µm², but they are seeded in a ring round you, so what a player
  actually swims through is denser: **26.8 to 27.8 living bodies within 1,400 µm,
  4.35–4.51 per million µm²**, measured along the forage bot's path on seeds 1–4
  (§15.4). That is the number a drop has to match (§6.1).
- **Water cells grow without bound.** `_devour` (`:2541`) adds `GROWTH_PER_MEAL`
  (4) per meal with no ceiling, and says so: "The bound on it is that nothing
  outside CULL is simulated at all" (`:2540`). §5 measures what a drop does with
  that: a body of **r332 after eighteen minutes**.
- **The water is tuned to you**: 45% of arrivals are mouthless drifters (92% when
  you sense nothing, `:183`, `:310`), peers are your radius ±34% (`:192`), no
  arrival opens its mouth past 40 (`ARRIVAL_GAPE_MAX`, `:214`), at least one
  drifter always exists, the first cell is a drifter 1,000 µm ahead
  (`FIRST_DISTANCE`, `:505`), nothing that could eat you starts inside
  `DREAD_RANGE`, and nothing hunts you for `FIRST_DELAY` = 42 s (`:813`).
- **Water cells never starve.** They drift at 9 µm/s (`:316`), notice anything
  they can swallow within `NOTICE_RANGE` = 1,900 µm whatever their senses
  (`:804`), and rest `CALM_MIN`–`CALM_MAX` = 30–55 s after a meal (`:799`).
- **Every per-pair pass is all-pairs**: prey search (`_look_for_prey`, `:1336`),
  contacts (`_contacts_water`, `:1929`) and separation (`_step_separate`,
  `:2382`), with shared-pond Phase 0's pre-checks; the player's senses scan every
  body (`_step_sense`, `:2772`, and the beam, ping and touch). §4 measures what
  that costs at a drop's count.

---

## 1. Decided, in one place

1. **The drop is a round drop of water 12 mm across**: radius 6,000 µm, 554
   living bodies at a density of 4.9 per million µm² (§2, row 1).
2. **Its edge is the meniscus** (row 2). A body cannot cross it: a drifting cell
   turns off it, a hunter slides along it, and the player is held and **feels it
   as a knock** at its bearing. The `ampulla` hears it as the widest, longest
   echo in the game, a `stigma` sees it as a shadow, a beam stops on it and a
   `palp` touches it. Full vision draws a bright meniscus line, a lit film of
   thinning water inside it and dry glass beyond, with the counting grid still
   etched on it (§3).
3. **Everything in the drop exists all the time.** A uniform grid answers "what
   is near here" for every pass, and a body far from every player runs **the
   same rules at a lower rate**: every mouth decides 7.5 times a second wherever
   it is, a far mouth moves 7.5 times a second, a far mouthless body 1.9 times.
   Nothing within 1,100 µm of a player -- the view and a margin -- is ever
   slowed, and nothing within 2,000, past the farthest any sense reaches, below
   every second frame (§4). **It costs 1.9 times today's field here**, over the
   1.5 this document set itself; a phone measurement decides whether that is too
   much (§4.4).
4. **Water cells stop growing at the player's ceiling and die of age.** A water
   cell grows as today until its radius reaches 40 or its mouth would open past
   40, and dies about three minutes after it was made, leaving remains (§5,
   rows 4 and 5). Pack 2's division replaces the radius cap. Water-cell hunger
   was measured and deferred: it doubles the player's starvation. The mouth's
   ceiling reverses what the owner settled for today's water, where a cell that
   eats past it is kept as a legendary organism; row 5 asks again, with what a
   drop does to that rule measured (§5.2).
5. **The spawner keeps the drop at its population**, paying the shortfall back
   over 5 s, one body at a time, each at the thinnest of twelve candidate
   points -- half of them in the ring just past a player's horizon -- and **never
   inside what any player can see or sense** (§6). It makes what is short: the
   drifter share your senses call for, peers your size, and any gene the drop is
   down to its last two carriers of. From pack 2 it only tops up what births do
   not.
6. **Food that isn't alive is detritus: flocs** (§7). Flakes fall everywhere at
   one rate and **stay where there are few cells** -- the owner's rule as a
   chance -- settle into focus over five seconds rather than appearing, and
   dissolve after two minutes. A floc is food and nothing else: **no growth and
   no gene** (row 6). The nose smells it, a beam and a `palp` find it, the
   `ampulla` and the `stigma` do not; full vision draws a small brown clump with
   the edible bloom round it. A water cell that dies of age or of venom leaves one
   (row 7). Measured, flocs made no difference a bot could show to how often it
   starved (§7.7): they are here because the owner asked for them, and cheap.
7. **A run starts somewhere quiet** (row 9): the spot, of 64 drawn, where a born
   cell would feel the least dread, with nothing edible within 400 µm and the
   most food within 1,100; anything still inside `DREAD_RANGE` that could
   swallow it is moved out, as today. The first drifter, the free sense and the
   42 s before anything may hunt you are kept; a division no longer regenerates
   anything.
8. **Fair against today, measured**: the full-vision forage bot starves no more
   often in a new drop than in the bubble (38 games of 128 against 44, and one
   eaten), eats every 10 s instead of every 12.5, finds its first meal at 11 s
   instead of 20, and meets the same dread. A drop aged fifteen minutes starves
   it as often as a new one on average, 38 games of 128, though aged drops differ
   more from one to the next (§8.5, §15).
9. **The drop outlives the run** (row 8): a death returns you to the same drop
   at a quiet place, and from pack 1's second release the drop is saved on the
   device and the dedicated server keeps one (§9).
10. **Pack 1 ships as two releases** (row 10): single player first, with no wire
    change -- a run with a session keeps today's water -- then the shared pond and
    the server on the drop, which is `Wire.PROTOCOL` 5 and a new `Wire.RULES`,
    plus saving (§10, §14).
11. **The mechanics are generic** (§13): a spatial grid, a basin with an edge, a
    replenisher and a snowfall in `game/mechanics/`, knowing points and counts;
    this water's numbers and names -- drop, meniscus, floc -- in one environment
    file.
12. **No binary change**: GDScript, one shader and scenes, all content.

---

## 2. Size and shape

### 2.1 A drop on a slide

Under a microscope the world is literally a drop of pond water on a glass slide.
A wet mount's drop is a few millimetres to a couple of centimetres across; its
edge is a meniscus, where the water thins against the glass and the air holds it
in. The game already draws the rest of that picture: `water.gdshader`'s
graticule is "a counting-chamber reticule, not a debug grid", anchored to the
water. So the drop is **round**, and what lies past its edge is the slide --
dry glass with the grid still on it.

Round rather than the square of a counting chamber: a circle has no corners to
trap a cell in, every point of the edge is the same edge, and "how far to the
edge" is one subtraction.

### 2.2 How big

| | Ø 8 mm | **Ø 12 mm ✓** | Ø 16 mm |
|---|---|---|---|
| radius | 4,000 µm | **6,000 µm** | 8,000 µm |
| living bodies at 4.9 per million µm² | 246 | **554** | 985 |
| across, in 16:9 screens (1,280 µm) | 6.3 | **9.4** | 12.5 |
| across, in 20:9 phone screens (1,600 µm) | 5.0 | **7.5** | 10.0 |
| area, in 16:9 screens | 55 | **123** | 218 |
| crossing, newborn (`flagellum` 1, 56.5 µm/s) | 2 min 22 s | **3 min 32 s** | 4 min 43 s |
| crossing, fast cell (`flagellum` 3, 111.5 µm/s) | 1 min 12 s | **1 min 48 s** | 2 min 23 s |
| the water's cost a frame here, p50, against today's 453 µs (§4.4) | 735 µs, 1.6 times | **882 µs, 1.9 times** | 1,213 µs, 2.7 times |

Speeds are `CellBody.speed_for()`: 56.5 and 111.5 µm/s.

**Why twelve.** A player who swims straight reaches the edge in under two
minutes from the middle -- which is what "I never reached the end" asked for --
and meets the same places again within a run. A newborn's whole tank, thirty
seconds, carries it 1,700 µm, a seventh of the way across. Five hundred bodies is
a population evolution can work with in packs 2 and 3 (§12). What it costs is
mostly the water near you, which is the same at any size; the far water adds
about a quarter at twelve millimetres and nearly half at sixteen (§4.4). Eight
millimetres puts the edge on the screen too often to be a place; sixteen is 218
screens of water, most of which a run never visits.

---

## 3. The edge: the meniscus

### 3.1 What it does

`game/mechanics/basin.gd` (§13) is a closed region: `contain`, `depth`, the exit
point along a ray and the nearest point of the rim. The drop is a disc of
`RADIUS` 6,000 with a band `SHALLOWS` 240 inside the rim.

- **A water body is contained**: after it moves, a centre past `RADIUS - r` is
  put back on that circle. Nothing is lost and nothing bounces.
- **A drifting body turns off the shore** -- a drifter, or a peer at rest.
  Inside the band, a body heading outward turns toward the middle at up to `SHORE_TURN` 1.4 rad/s, scaled by how
  deep into the band it is, so drifters do not grind along the rim. Hunters are
  only contained: a chase can run along the edge, and a break-off that aims past
  it slides round it until its timeout.
- **The player is held and knocked**: a centre past the rim is put back, the
  velocity into it is reflected at `SHORE_RESTITUTION` 0.2 through `cell.bump()`,
  and an impact faster than `SHORE_FELT_SPEED` 6 µm/s is **felt as a `hit`** at
  the edge's bearing, strength `clamp(sqrt(v / impulse speed), 0.35, 1)` -- the
  same knock grit gives -- at most once every `SHORE_GAP` 0.6 s. Pressing on
  into it keeps knocking at one bearing, which grit never does: grit is gone
  after one knock.
- **Grit stays in the water**: `motes.gd` places no mote past the rim, the
  authored first mote included. At the edge the meniscus is the first knock.

A wall at your back is a real position: nothing comes at you from behind it.
That falls out of containment and nothing was added for it.

### 3.2 How each sense perceives it

Every sense that answers *where is something* has an answer at the edge, taken
from what a meniscus physically is. Nothing new reaches the membrane: each
answer rides a channel the sense already has.

| sense | what the meniscus is to it | on the membrane |
|---|---|---|
| none (touch) | a surface | a `hit` at its bearing on contact, repeating while you push |
| `ampulla` | the largest reflector a pulse can meet | an echo from its nearest point, as a body `EDGE_ECHO_RADIUS` 80 µm wide: measured, **half-width 45.6° and a 1.28 s hold** at 520 µm, 52° (the cap) closer, against 17–21° and 0.2–0.4 s for cells |
| `stigma` | a curved surface is a lens that bends the light away | a shadow at its bearing, `EDGE_SHADOW` 0.6 of a body's at the closest, fading to nothing at `SHADOW_RANGE` 620 |
| `ocellus` | something a ray stops on | the ray's distance; no beam experience, which counts bodies |
| `palp` | the nearest thing there is | its bearing and closeness, like a body |
| `chemocyte` | nothing: the edge does not smell | nothing |

Occlusion, the hull's baffles and the ping's slot limits apply to the edge's echo
exactly as to a body's. Dread is untouched: the edge has no mouth.

### 3.3 Full vision

`water.gdshader` gains four uniforms -- `drop_on`, `drop_center`, `drop_radius`,
`drop_band` -- written by `vision.gd`'s `_push_shader()`:

- inside, the water as today;
- in the band, the thinning film: `water_tint · film² · rim_level` added, with
  `film = smoothstep(R - band, R, d)` and `rim_level` 0.22;
- at the rim, the meniscus line: `exp(-((d - R) / 2.2 px)²) · 0.55` of a pale
  teal, a few pixels wide at any zoom;
- past it, dry glass: no grain and no cloud, the grid at 0.45 of its level.

### 3.4 Rendered

Every frame is `tools/shot.tscn` driving `tools/drive.tscn` under
`--rendering-driver opengl3 --fixed-fps 60`, on the prototype, at 1280x720 and
2400x1080, both views. The frames reproduce first: one frame rendered three times
differs by **0 pixels**.

```
E = --seed=7 --scheme=0 --ocean --start=edge --density=4.9e-6
```

| frame | flags | shows | judgement |
|---|---|---|---|
| `edge` | `E --edge-gap=380 --flocs-near=4 --freeze-at=5.0`, `--mode=1` | the meniscus, the film, dry glass and grid, four flocs | reads as the edge of the water at both shapes; the film is a lit shore, not a wall painted on. In point of view (`--mode=0`) the same moment shows the cell alone: the rim is nothing until a sense meets it, which the next three frames show |
| `knock` | `E --edge-gap=110 --freeze-on=hit --freeze-delay=4`, both modes | the cell against the rim | point of view: the contour lit, brightest dead ahead, where the rim is (`hit` at +0.4°, 0.52) |
| `wallecho` | `E --edge-gap=520 --genome=cytostome:1,cirrus:1,flagellum:1,ampulla:2:0 --freeze-at=4.45`, both modes | the pulse's echo off the rim landing | point of view: a violet band across the top wider than any cell's mark, held; full vision: the same band and the wavefront in the water |
| `shade` | `E --edge-gap=330 --genome=cytostome:1,cirrus:1,flagellum:1,stigma:1 --hold=d --freeze-at=2.2`, both modes | a `stigma` closing on the rim | point of view: the amber lobe dead ahead (`light` +0.7°, 0.86) |

Two faults the first renders showed, both fixed in the prototype and both for the
build: motes were seeded before the drop existed and sat on dry glass, and the
authored first mote was placed 340 µm ahead with no regard for the rim. Every
frame above was shot again on the final prototype, with the edge frame the one
rendered three times: no grit on the glass, and the first mote inside the film.

---

## 4. Cells that persist, and what that costs

### 4.1 Today's passes at a drop's count

**Today, per cell**: the shipped field costs p50 407–521 µs a frame here with the
player in it (§4.4), **12–15 µs a body** at 34 bodies. `shared-pond.md` §4 split an
earlier hour's figure by pass, before its pre-checks: prey search 214–260 µs,
contacts 351–431, separation 187–200, the player's senses about 105. The first
three are all-pairs, so their cost per body grows with the count; the senses grow
with it linearly.

`tools/eco_probe.gd` (§15.2) steps the drop alone, with a ghost player out of the
water, and times `food.gd`'s frame. At radius 6,000 and 423 bodies (the nominal
density, a blind player's composition, the prototype's defaults), 90 simulated
seconds, one run at a time on an idle machine, mean microseconds a frame:

| | step | contacts | separation | total |
|---|---|---|---|---|
| today's all-pairs passes (the grid as one bucket), every body every frame | 2,301 | 3,440 | 48,658 | **≈ 54,500** |
| a 400 µm grid, every body every frame | 1,679 | 177 | 622 | **≈ 2,500** |
| the grid, every frame within 2,000 µm of the player and the tick past it | 320 | 39 | 92 | **≈ 470** |
| the same, with the half-rate band from 1,100 µm and the near-first prey search (§4.3) | 235 | 22 | 63 | **≈ 340** |

A micro-benchmark here puts one skipped pair at 0.17–0.24 µs, a grid insert at
0.20 µs, a grid query of 1,900 µm at about 20 µs and one of 200 µm at 1.3 µs; a
bare drift step is 0.35–0.56 µs, and a real body's step -- today's AI, hunger-free
-- measures about 7 µs. All-pairs at 423 bodies is 89,000 pairs a pass: it cannot
be done at any frame rate, and a grid alone still steps every body every frame.

### 4.2 The grid

`game/mechanics/space_grid.gd`: buckets of `GRID_CELL` 400 µm over the square
round the drop, each a linked list threaded through two packed arrays, `head`
and `next`, with `where` per id. **Incremental**: a body is re-bucketed only when
the step that moved it crossed a bucket line, which is a subtraction and a compare
in the caller; spawns insert and retirements unlink. Measured, the grid's whole
cost a frame fell from 280–320 µs rebuilt to 9–12 µs incremental.

A query returns every id in the buckets a circle touches and the caller keeps its
exact distance test, so a query can only answer more than the truth, never less.
Every pass that was all-pairs asks the grid instead:

| pass | reach it asks |
|---|---|
| `_look_for_prey` | `NOTICE_RANGE` (0 when resting) + the widest body + 40 µm slack |
| water contacts | the mouth's own bound, `mouth_reach + gape·MOUTH_BITE + widest` |
| separation | `r + widest` |
| the player's senses and contacts | one list a frame: `max(SCENT_RANGE, DREAD_RANGE, ping, beam)` + widest + slack |
| spawner, snow, floors | 800 µm counts |

The 40 µm slack covers what moved since a body was last re-bucketed; the widest
body is kept as a running maximum, which only has to be too big.

**A prey search looks near first.** Nearest wins, so a search that finds its
winner within `PREY_NEAR` 400 µm, over the buckets that close, has found the
answer: anything nearer lay in those buckets. Only a search that finds nothing
that close asks the whole `NOTICE_RANGE`. The same body wins either way: five
minutes of the drop with and without it print the same census lines, every
meal and death alike. In drifter-rich water most searches stop at the first
pass (§4.4 has what it saves).

**One trap the prototype fell into, for the builder.** A pass that loops over
the grid's answer and calls something that asks the grid again must not share
the answer's array: packed arrays are passed by reference, and the prototype's
LOD loop carried on over a prey search's candidates instead of its own list, so
some near bodies skipped frames. The fix changes only how regularly the bodies
near a player are stepped. §4's costs and statistics and §8.5's forage runs were
measured again after it; the rest -- the drop as a whole, the rim, the renders,
and pairs that ran on one prototype on both sides -- stands from before it.

### 4.3 The same rules at a lower rate

Three rates, by distance from the nearest player:

- **within `LOD_FULL` 1,100 µm, every frame**: everything the view can show
  (949 µm on a 20:9 phone, with the camera's lead) and a margin;
- **from 1,100 to `LOD_NEAR` 2,000, every second frame**, with the time it is
  owed: inside the senses' reach, outside the view;
- **past 2,000, on a tick**: a slot's tick is its index modulo `LOD_EVERY` 8, so
  a tick is a stride through the array and never a scan of it. A far body with a
  mouth steps once every 8 frames (7.5 times a second at 60); a far body with no
  mouth -- a drifter or a floc, which decide nothing -- once every
  `LOD_EVERY · LOD_SLOW` = 32 frames;
- **every mouth, near or far, looks for prey on its tick and only then**, so a
  decision is made 7.5 times a second everywhere (`LOD_EVERY` is even, so a body
  in the half-rate band is always stepped on its tick). That is the property
  packs 2 and 3 need: a behaviour evolved in the far water is judged by the same
  clock as the one that meets you. It costs a hunter up to 133 ms before it
  notices you.

**Why nothing can be seen.** Past 2,000 µm nothing senses anything: a tier-3
`ampulla` answers off a body whose surface is within 1,900, so a centre up to
1,940 for the widest body there is; scent ends at 1,600, dread at 1,400, a beam
at 1,240 plus a radius. A body crossing 2,000 has been stepped at least every
second frame for as long as anything could sense it, and every frame for as
long as it could be seen. In the half-rate band a body's position is at most one
frame's travel stale -- about 2 µm for a cell at full stroke -- against echoes
17° wide and a dread and a scent that fall off over a millimetre. **A body
stepped at a lower rate is not the same run**, so no pixel comparison can prove
this; §14.3 holds it with a CI check that `LOD_NEAR` stays past every reach in
the tables and `LOD_FULL` past the view, and the water's statistics hold it
here. Ten minutes of the drop alone on seeds 1–3, with the LOD and with every
body stepped every frame (`eco_probe.gd`, `--sensed=0.6`, §15.2 with
`--until=600` and `--lod=0|1`), means of the three:

| | drifters eaten | peers eaten | died of age | spawned | peers at r40 | threats to r34 | mean peer r | dread, r34 |
|---|---|---|---|---|---|---|---|---|
| every body every frame | 1,880 | 423 | 431 | 3,280 | 25.3 | 46.3 | 32.2 | 0.80 |
| **the LOD, as recommended** | **1,900** | **445** | **425** | **3,310** | **22.0** | **44.3** | **31.8** | **0.67** |
| seed-to-seed range, either | 1,813–1,942 | 399–470 | 414–438 | 3,246–3,338 | 21–30 | 40–51 | 31.7–32.4 | 0.63–0.85 |

Every difference is inside the spread between seeds. Dread at r34 reads lower
with the LOD on all three seeds (0.63–0.75 against 0.71–0.85), the direction
that costs a player nothing; it is the number to watch when the builder runs
these statistics again. The water alone cost p50 8.1 ms a frame without the LOD
and 0.72 ms with it, in those runs.

### 4.4 Frame budget

**The budget this document set itself: the water may cost at most 1.5 times
today's field**, measured the same way with the player in it --
`drive.tscn --field-cost=3600` at `--radius=30` with a tier-1 nose and `ampulla`
(shared-pond.md §4's method), seeds 7, 12345 and 2026, one run at a time on an
idle machine, today's field and the drop interleaved. **The drop does not meet
it: it costs 1.9 times today's field here.**

**The phone factor is six**, assumed and stated, not measured. GDScript is an
interpreter and its cost is one core's; this Xeon core is roughly four times a
2020 budget phone's big core (a Cortex-A73/A75 class, Geekbench-6 single core
around 400 against about 1,600 here), and an interpreter's branchy,
memory-bound work loses more on small cores than a benchmark does, so four
becomes six. At six, today's field is about 2.7 ms of a 16.7 ms frame on such a
phone and the drop about 5.3 ms. **Only the ratio transfers**; the builder
measures a real phone before 1a ships (§16).

| water, p50 µs a frame here | bodies | seeds 7, 12345, 2026 | median | times today's |
|---|---|---|---|---|
| today's field | 34 | 407–521 (three runs each) | 453 | 1.0 |
| the drop, Ø 12 mm, everything within 2,000 µm every frame | 554 | 1,035–1,095 (two each) | 1,047 | 2.3 |
| and the half-rate band from 1,100 µm | 554 | 827–997 (two each) | 938 | 2.1 |
| and the near-first prey search (§4.2) | 554 | 977–1,090 (two each) | 1,049 | 2.3 |
| **both: the drop as recommended** | 554 | **839–1,013 (two each)** | **882** | **1.9** |
| both, in a drop aged fifteen minutes | 550 | 805–858 | 849 | 1.9 |
| both, Ø 8 mm | 246 | 576–828 | 735 | 1.6 |
| both, Ø 16 mm | 985 | 1,128–1,293 | 1,213 | 2.7 |
| the search, and every frame only within 1,100 µm, the tick past it | 554 | 749–804 | 760 | 1.7 |

The search alone replays the first row's runs to the frame, so the whole of its
difference is its cost: nothing at the p50, 48 µs off the steps' mean; with the
band, 938 becomes 882. Where a frame goes, in the recommended drop (the phase
means, seed 7): the steps 402 µs, for 58 bodies a frame -- the 19 within 1,100,
half of the band's 43 and 17 far ticks; the player's senses over one scan list
191; separation 148; contacts 62; the player's own contacts 45; the spawner,
floors and snow 15; the grid 10.

**Why it is over: density, not size.** The drop keeps 61 bodies within 2,000 µm
of you where the bubble keeps 34 in all, and a body near you costs what it costs
in the bubble. The far water is about a quarter of the cost at 12 mm and nearly
half at 16. The density is what fairness asked for (§6.1), so fewer bodies is not
the lever. In order:

1. **Measure a phone.** Whether the rest of a frame leaves a budget phone
   5.3 ms for the water is not knowable here (§16).
2. **The tick from 1,100 µm out** (the last row, 1.7): its case rests on how
   finely the senses resolve rather than on how far they reach -- a hunter at
   1,500 µm moving in 13 µm steps 7.5 times a second, against a dread and a scent
   that fall off over a millimetre -- and it needs the statistics above again
   before it replaces the band.
3. **The senses' scan list per sense** rather than one list at the widest reach,
   and separation in the band at the tick: the builder's, not measured here.

**Drawing** is the other cost: full vision today reads `points()`, `radii()`,
`headings()`, `genomes()` and `wounds()` over every body every frame and culls
per body. At 554 bodies that is 2,770 rebuilt entries a frame for the dozen on
screen. `vision.gd` asks the field for the bodies within the frame's circle
instead, through the grid (§14.1).

---

## 5. Bounded growth

### 5.1 What a drop does with today's rule

`tools/eco_probe.gd`, the drop alone at radius 6,000 and 4.9 per million µm²,
spawns tuned to a sighted player (`--sensed=0.6`: 37% peers), for 25 minutes of
simulated time. A **threat** to a player of radius r is a peer whose gape exceeds
r; **dread** is the membrane's own sum (`THREAT_LOW`/`THREAT_HIGH` window times
`DREAD_RANGE` falloff) for a player of that radius, averaged over 64 random
points. Today's bubble, worked out from its own tables (peer band, tier weights
at 0.6, the arrival ceiling), threatens a r34 player with about **9%** of its
peers.

| after 25 min | peers r40 | threats to r26 / r34 / r40 | share threatening r34 | mean peer r | dread r26 / r34 / r40 |
|---|---|---|---|---|---|
| a fresh drop (t = 0) | 0 | 62 / 15 / 0 | 8% | 25.4 | 1.07 / 0.16 / 0.01 |
| today's rule, nothing added (18 min, nominal density) | 65 | 114 / 79 / 60 | 54% | 60.3, **largest r332** | -- |
| a radius cap at 40 | 107 | 155 / 95 / 85 | 49% | 35.7 | 2.92 / 1.80 / 1.31 |
| the cap and the gape ceiling | 158 | 192 / 27 / 0 | 14% | 39.2 | 3.57 / 0.85 / 0.13 |
| the cap, and death at 120 s ± 30% | 26 | 112 / 43 / 27 | 23% | 31.1 | -- |
| the cap, and death at 180 s ± 30% | 48 | 130 / 51 / 37 | 27% | 32.7 | 2.19 / 0.85 / 0.48 |
| the cap, and death at 300 s ± 30% | 70 | 136 / 69 / 53 | 36% | 34.0 | -- |
| **the cap, the ceiling after every meal, and death at 180 s ± 30%** | **30** | **132 / 51 / 0** | **26%** | **32.2** | **2.32 / 0.87 / 0.20** |
| the cap and hunger like yours (18 min, nominal density) | 55 | 94 / 51 / 42 | 37% | 32.9 | -- |

The first row after "fresh" is why something must bound growth: with nothing but
a persistent drop, a feeding cell becomes a whale. A cap alone is not enough
either: after a few minutes half the peers sit at r40 and never leave. The cap
and the ceiling without age are worse for a newborn, not better: four peers in
five end at r40 with a small mouth, harmless to a r34 player and able to swallow
every r26 one. Age keeps the drop young, and the ceiling takes away only what
age leaves at the top: the 37 bodies that could swallow a cell reaching full
size. Threats to r26 and r34 are the same with it and without it.

Every row is one seed and one moment, and every row ran before §4.2's fix, so
the rows compare with each other and not with anything after. The chosen rule,
run again after the fix on the same seed, read 118 / 35 / 0 at 25 minutes and
118–131 threats to r26 at every census from five minutes on: the same shape, a
snapshot's worth apart.

### 5.2 The rule for pack 1

- **The radius stops at `CellBody.DIVIDE_RADIUS`**, 40: the player's own ceiling,
  where a body runs out of arcs. Pack 2's division replaces this cap -- a water
  cell that reaches 40 divides, as you do.
- **The mouth stops at the water's ceiling**, `ARRIVAL_GAPE_MAX` 40, which
  becomes a ceiling on what the drop *grows* as well as on what it makes (row 5).
  A meal that would take the gape to 40 or past it grows the radius only as far
  as the gape allows, and a meal that would raise the mouth's tier past what fits
  does not raise it: the tier is taken back in the same step, which is
  `_draw_genome`'s rule for an arrival applied after every meal, with 0.01 µm of
  margin. Without that last step 16 bodies could still swallow a r40 player after
  25 minutes; with it, none can. It stays a property of this water
  (`genes-and-cilia.md` §9.8), set in `drop.gd`.

  **This reverses what the owner settled for today's water**, so row 5 asks
  again. `genes-and-cilia.md` §1.3 keeps a cell that eats its way past the
  ceiling on purpose, as the first legendary organism: rare, earned in view, and
  the one thing that can still threaten a cell reaching full size. It is rare
  today because nothing lives long: the water round you is thrown away at every
  division and past `CULL`. A drop keeps its cells, and the rare stops being
  rare: with the cap and age but no ceiling, **37 bodies could swallow a r40
  player after 25 minutes**, one every three screens, and a cell reaching full
  size feels dread 0.48 instead of 0.20 (§5.1). §1.3 rejected an absolute
  ceiling because enforcing one takes a tier off a living cell, which would read
  as a rendering glitch. This one never does: the radius stops, and a tier that
  would not fit is never granted, so no mouth anyone has seen ever shrinks. (The
  drop makes its arrivals under the same 0.01 µm margin, so that no arrival
  starts in the hair between the two tests and loses a tier at its first meal.)
- **A water cell with a mouth dies of age** at `LIFESPAN` 180 s ± 30% after it
  was made (drawn once, at its making), and leaves remains (§7.4). A mouthless
  drifter does not age: it is food and does not stay long, which §6.4 measures.
  Age is honest for a protozoan only as a stand-in: a real one does not die of
  age, it divides, and after its division it is not itself any more. In pack 1
  there is no division, so age is what ends a body; pack 2 turns a cell's age
  into "it divided or it died", and a lineage that keeps eating outlives any of
  its bodies.

**Why not hunger, which is the realistic answer.** It was built and measured:
water cells with your metabolism -- the same 36 s tank, the same upkeep, strokes
priced at `STROKE_COST` -- and a rest that ends when they are hungry. At the
chosen density, in the drop as it was before the spawner's ring (§6.3), the
forage bot then **starves 20 of 32 games instead of 10**,
because hungry hunters strip the drifters round you; the drop turns over at
eight spawns a second, a thousand cells starve every eighteen minutes, and the
average peer is half-empty. It is the right rule for pack 3 -- a behaviour that
never eats should die of it -- and it wants its own balance pass with the water's
density and composition; `Body.hunger` is reserved for it (§12).

---

## 6. Spawn rules

### 6.1 How many

`DENSITY` is **4.9 living bodies per million µm²**: 554 in the drop. It is set
by what a player actually swims through today, not by the nominal 3.74: the bubble
keeps 26.8–27.8 bodies within 1,400 µm of a foraging player (4.35–4.51 per
million), and in a drop the player's own grazing thins its neighbourhood. At 4.9
the drop keeps **26.1 edible bodies within 1,400 µm of the bot against the
bubble's 25.5** (§8.5). At the nominal 3.74, before the spawner had its ring
(§6.3), the bot starved 16 games of 32 against the bubble's 10. At 5.5 it
starves no less (15 of 64 against 14 for 4.9 in the same batch) and meets 35%
more dread along its path (0.27 against 0.20; above 0.5 for 21% of the time
against 15%): more water is more hunters, not more meals.

### 6.2 How often

A shortfall is paid back over `SPAWN_TAU` 5 s: each half second the spawner adds
`(target − living) · 0.5 / 5` to a debt and makes a body for every whole one, at
most `SPAWN_BURST` 8 a tick. A body that dies is replaced within seconds,
somewhere else. At 20 s, with hungry hunters, the drop ran a third short (272
of 423); at 5 s it holds within 4% (534 of 554 after 25 minutes).

What that is in practice, measured over 25 minutes with a sighted player's
composition: **about 270 bodies a minute**, of which 182 replace drifters the
water ate and 47 replace cells that died of age; the drop's 341 drifters turn over
every two minutes. Today's bubble, for comparison, reseeds
about a hundred a minute *round you* (§0).

### 6.3 Where

**Never inside what any player can see or sense.** Each player has a hide reach:

```
hide(player, kind) = max(VIEW_REACH, its smell_range, ping_range, beam_range,
                         DREAD_RANGE if kind has a mouth) + HIDE_MARGIN
```

`VIEW_REACH` is 949 µm (a 20:9 phone's half-diagonal, 877, plus the camera's lead,
72) and `HIDE_MARGIN` 100. A mouthless body raises no dread, so for a born cell
with its free sense a drifter may be made 1,050–1,200 µm away (by which sense it
was given) and a peer 1,500. A peer
cannot pop into the dread readout; a drifter cannot pop into a nose that is
not there.

Of `SPAWN_TRIES` 12 candidate points, half are drawn anywhere in the drop and half
in the ring `[hide, hide + 800]` round a player; any inside a hide reach is
thrown away, and the spawner takes **the thinnest**: the fewest living bodies
within `SPAWN_SCAN` 800 µm. So the water a player has grazed out is refilled from
its horizon inward, and a region nobody is in refills too.

Without the ring, and with one hide reach for every kind, the drop starved the
bot 29 games of 64; with both, on the same prototype, 14, and the edible bodies
within 1,400 µm of it went from 21 to 26: the player's own grazing had not been
paid back where it could reach it. The final drop starves it 38 games of 128
against the bubble's 44 (§8.5).

**How a region that emptied recovers**, measured by clearing everything within
2,500 µm of a point (96 bodies expected there): with nobody in it, 72% back in
20 s, 81% in a minute, 95% in five; with a player sitting still in the middle,
77% in 20 s and 99% in a minute -- from its rim inward, since nothing may land
within 1,500 of that player.

### 6.4 What

The spawner makes **what is short**:

- **Drifter or peer** by the drifter share your senses call for today
  (`_drifter_share`, 0.92 blind to 0.45 at `SENSE_FULL`), asked of the *standing*
  drop rather than of each arrival: a drifter when the living share is under it,
  a peer when it is over. Hunters eat drifters faster than anything else dies, so
  asked per arrival the standing water drifted toward peers.
- **A peer your size**: `_seed_peer` with your radius and senses, as today --
  the band, the tier weights, the arrival ceiling. In the shared pond, the
  players take turns (§10).
- **The gene floor**: every two seconds the drop counts who carries what; the next
  drifter carries a gene in `DRIFTER_GENES` that fewer than `GENE_FLOOR` 2 living
  bodies carry. Genes are never lost, and "there is always a way to eat your way
  to any gene" stops being statistical. Measured: all 16 genes present at every
  one of 390 censuses (134 in the ecosystem runs, and at the end of each of
  §8.5's 256 games in the drop, new and aged).
- **The drifter floor** stays: if no living drifter is within `hide + 600` of a
  player, one is made just past its horizon, ahead of it, at most every
  `DRIFTER_FLOOR_GAP` 10 s. With the ring it has nothing to do: it fired 0 times
  in §8.5's 256 games in the drop. It stays as the invariant it always was.

The first drifter a run meets is still placed `FIRST_DISTANCE` 1,000 µm along the
cell's first motion. It is 51 µm past the view and a born cell has no sense for
five seconds, so nothing sees it arrive; a division no longer re-places one
(§8.3).

### 6.5 From pack 2, births take over

Division adds bodies. The spawner fills only the gap between what is living and
`target · SPAWN_SHARE`, with `SPAWN_SHARE` 1.0 in pack 1; pack 2 lowers it (say to
0.5), and the spawner backs off by construction: births that keep the drop full
leave no debt. The one door every new body comes through is `_spawn()` (§12), so
a birth is a spawn with a parent.

---

## 7. Food that isn't alive

### 7.1 What real microbes eat that isn't a cell

Ciliates and amoebae live largely on **detritus**: dead organic matter, the
remains of cells, faecal pellets and mucus, colonised by bacteria and clumped
into **flocs**. In open water it falls as **marine snow**, and it accumulates
wherever nothing eats it. In a drop on a slide it settles out of the water column
onto the glass, and under the microscope a particle settling into the focal plane
goes from a blurred halo to a sharp speck. That is the whole mechanic, and the
owner's reasoning is the ecology's: "no eater means more edibles available at
this place".

### 7.2 How flocs appear, and go

- **Snow falls everywhere at one rate**: `SNOW` 0.072 flakes per million µm² a
  second, over the whole drop (8 a second).
- **Each flake stays with a chance of `1 − n / (SNOW_SHARE · expected)`**, where n
  counts the living bodies within `SNOW_SCAN` 800 µm, a player included, and
  `expected` is the drop's density over that disc (9.9). A place holding half its
  share of cells keeps nothing; an empty one keeps every flake. That is "dispose
  where there's few cells" as a chance rather than as a placement, so nothing is
  ever put where the game decided food should go.
- **A floc settles** into view over `FLOC_SETTLE` 5 s: its scent, its drawing and
  its edibility ramp from nothing, and it cannot be eaten until it has settled.
  So a floc may appear inside what a player sees and smells -- gradually, like
  something sinking into focus, never in a step. It is the only thing in the drop
  allowed to.
- **It dissolves** after `FLOC_LIFE` 120 s ± 25%, the same five seconds in
  reverse. Flocs never move.
- Radius `FLOC_MIN`–`FLOC_MAX` 8–14 µm: always in a born cell's mouth (gape 21.3).

A fresh drop holds a median of 19 flocs after three minutes (7 to 34, 128 runs).
One that has run for five minutes or more holds 45 to 80 with a sighted player's
composition, the remains of cells that died of age among them (the §5.1 runs),
and 13 to 41 with a newborn's, which has fewer mouths to die of age (median 28,
64 runs aged fifteen minutes). Almost all lie where cells are thin: a normal
neighbourhood holds none, and a grazed-out one fills over a minute or two.

### 7.3 What a floc is worth

- **Food**, by the meal rule every body obeys: its radius over the eater's,
  clamped to `MEAL_MIN`–`MEAL_MAX`. For a born cell a floc is 0.35–0.54 of the bar,
  7–11 s of life for a born cell steering a third of the time, against 0.5–0.8
  of the bar for a drifter.
- **No growth** (row 6). The radius does not move, so a floc never brings a
  division nearer. Living prey is what builds a body; detritus keeps one going.
- **No gene** (row 6). Genes come only from the living. A lineage that lives on
  flocs survives and does not change -- a real trade-off, and it keeps the gene
  in a meal's flood meaning *this was alive*.
- **Water cells eat flocs by the same rule**, as the nearest thing they can
  swallow, and get the same: food, nothing else. In pack 1 a water cell does not
  starve, so what a floc does to it is what any meal does: it ends the run and
  the cell rests 30–55 s. A floc near you can take a hunter's attention and then
  its appetite -- the same rule, not a new one. From the day water cells can
  starve, it feeds them too.

### 7.4 Remains

A water cell that **dies of age or of venom** leaves one floc where it died,
radius half its own, 8 to 18 µm, already settled: it is not falling, it is what
is left. A cell that is swallowed or chewed apart has fed whoever finished it and
leaves nothing. A player that starves leaves one too (§9 makes that matter: the
drop outlives you). Row 7 asks the owner.

### 7.5 How each sense perceives a floc

| sense | a floc | why |
|---|---|---|
| `chemocyte` | smells like food, weighted as any edible body, times how far it has settled | decaying matter smells; the nose is how point of view finds it |
| dread | nothing | no mouth |
| `ampulla` | nothing | 8–14 µm is far smaller than the pulse; a speck does not echo, and the ping's three to five returns stay for bodies |
| `stigma` | nothing | a shadow is mass, and a floc is below `SHADOW_MIN_RATIO` of any cell |
| `ocellus` | stops a ray | it is matter; it earns the beam no experience |
| `palp` | touched | it is there |
| touch | nothing | it is not solid: a cell swims over it |

So in point of view a floc is the green band rising with no echo and no shadow to
go with it -- a smell with nothing alive behind it, which is exactly what it is.
Swallowed, it floods the membrane like any meal, in the plain nutrient colour the
flood takes when no gene arrives (`signal_bus.gd`'s `NUTRIENT_COLOR`): a meal with
nothing alive in it, told on the one channel that already names what you ate.

### 7.6 Drawn, and rendered

`vision.gd` draws a floc as **a clump of five rounded fragments** in
`DETRITUS_TINT` (0.74, 0.60, 0.36), a darker body with a lighter core, inside a
thin ragged outline -- never a cell's rim and never grit's single shell. Settling,
it is a wider, fainter blot that tightens into the clump. **The edible bloom goes
round it, never over it** -- the friend's ring (`_draw_scent_ring`), weighted by
the same curve the nose uses times how far it has settled -- because the first
render drew the ordinary bloom, and a clump that does not hide its middle glowed
like a lamp.

`flocs2`: `--seed=11 --mode=1 --scheme=0 --ocean --density=4.9e-6
--flocs-near=5 --freeze-at=1.0`, 1280x720 and 2400x1080, one caught settling.
Judged: small brown clumps with a green ring, legible as *edible and not alive*
at both shapes, told apart from a drifter (rim, nucleus, cilia) at a glance and
from grit (grey, one shell, no bloom). A floc is 16–28 px across at 1280x720 and
24–42 device px on the phone.

### 7.7 Measured

The forage bot (§8.5) goes for the living first and for a floc only when nothing
alive is on its screen -- what a player does once they know a floc does not grow
them. Each pair below is one prototype and one set of seeds, with flocs and
without; "died" counts every game that ended inside three minutes. The first two
pairs ran before the start's clearing (§8.1), which moves one body at two starts
in 32 and changes nothing here; all of them ran before §4.2's fix, on both sides.

| water | flocs | games | died | before any meal | flocs eaten | meals | first meal, median |
|---|---|---|---|---|---|---|---|
| a fresh drop | on | 64 | 14 | 0 | 16 | 993 | 11.1 s |
| a fresh drop | off | 64 | 15 | 1 | 0 | 978 | 11.3 s |
| an emptied start: everything within 2,500 µm cleared | on | 64 | 21, one of them eaten | 3 | 10 | 836 | 22.1 s |
| an emptied start | off | 64 | 18 | 1 | 0 | 928 | 22.7 s |
| a drop aged fifteen minutes | on | 64 | 25 | 0 | 10 | 925 | 10.4 s |
| a drop aged fifteen minutes | off | 64 | 27 | 0 | 0 | 889 | 10.6 s |
| the nose bot (`--sniff`, `chemocyte` 1), a fresh drop | on | 32 | 32 | 19 | 1 | 28 | 18.9 s |
| the nose bot, a fresh drop | off | 32 | 32 | 24 | 0 | 18 | 21.8 s |

**Flocs made no difference these runs can see.** Whether one game starves is
nearly a coin toss that any change throws again -- the same seed starved both
with flocs and without only 3 to 8 times in 64 -- so two sets of 64 games of one
water differ by up to six in a new drop and fourteen in an aged one (§8.5), and
every pair above is inside that. The full-vision bot ate a floc
once in four to six games: the spawner refills an emptied place from its horizon
inward within a minute (§6.3), so its screen was almost never without something
alive. The nose bot ate one in 32 games: it starves before its first meal in most
of them, as it does in the bubble (energy.md §7.4), and flocs do not change that.

A first version of the bot that went for the nearest edible thing, floc or not,
ate three flocs a game in a fresh drop whose snow was twice as permissive
(`SNOW_SHARE` 1.0) and starved 18 games of 32 where the living-first bot starved
10: flocs may be a trap for a player who does not yet know what they are. From an
emptied start the same bot and snow ate six a game and died in 16 games of 32
against 20 without flocs. Neither is outside the noise either.

So flocs are in pack 1 because the owner asked for them, because they cost
little -- a few dozen bodies that never move and never decide -- and because they
are where the drop's dead go: remains feed the water cells that find them, which
is what those cells will need from the day they can starve (§12). What flocs do
for a person is the dev app's to judge; `SNOW`, `SNOW_SHARE` and a floc's worth
are the three numbers to move.

---

## 8. Keeping it fair for the player

Today the water is built round you: the peer band, the drifter floor, the gape
ceiling, the opening. In a drop the water is its own, and each of those becomes
something else.

### 8.1 Where a run starts

**Somewhere quiet** (row 9). Of `START_TRIES` 64 points drawn uniformly more than
1,000 µm inside the rim, those with anything edible within 400 µm are thrown away
-- the first meal is found, not handed over -- and the run starts at the one where
**a born cell would feel the least dread**, ties going to the most food within
1,100 µm. The drop is placed so that point is where the cell already is, so the
camera does not move. A return after a death is the same choice, made behind the
black.

Measured on the fresh drop over 32 seeds, the choice alone put the start's dread
at **0 on 19 seeds**, median 0, worst 0.48 (the raw sum, before the membrane's
cap), with 10–24 edible bodies within 1,100 µm, median 17. Today's rule is
stronger -- nothing that could swallow you starts inside `DREAD_RANGE` at all --
and it is kept on top of the choice: **whatever could swallow a born cell and is
still within `DREAD_RANGE` of the chosen point is moved straight out to
`DREAD_RANGE` + 100 µm**, as today's `_seed` puts it there. It moves a resident
about a millimetre at the start of a run, which nobody can see and which costs
persistence nothing that matters. Measured with it, on 64 seeds each: in a fresh
drop it moved one body at 5 starts of 64, and in a drop aged fifteen minutes 36
bodies at 25 starts, never more than four at one; the start's dread was then 0 at
46 starts of 64 in a fresh drop and 51 in an aged one, and at most 0.12. What is
left is cells a little too small to swallow a born cell, which the membrane
already dreads (`THREAT_LOW` 0.85).

### 8.2 What guarantees a first meal

- The first drifter, 1,000 µm along the cell's first motion, as today (§6.4).
- The start itself: nothing edible within 400, the most within 1,100.
- The drifter floor, and the ring that refills the player's surroundings (§6.3).
- The snow, which keeps what falls wherever the player has eaten its
  neighbourhood out (§7.2).

Measured: **first meal at 10.6 s median (6.3–30.2) against today's 19.6 s
(7.3–32.4)**, 128 games each; one game in each ended before its first meal. Along
the bot's path, nothing edible was within 700 µm 1% of the time in the drop and
17% in the bubble.

### 8.3 What replaces the opening rules, and a division

- **`FIRST_DELAY`** is kept whole: nothing may hunt a cell for 42 s after it is
  born, after a division, or after a return. It is the rule that makes the forage
  bot unhuntable -- it divides every 30–45 s -- in the bubble as in the drop.
- **"Nothing that could eat you starts inside `DREAD_RANGE`"** becomes §8.1.
- **A division regenerates nothing.** The daughter is where her mother was, in
  her mother's water, with a new cell's organs and grace: `food.gd`'s
  `enter_water()`, which is what the shared pond has done since Phase 1. The
  sister is left `SISTER_DISTANCE` 560 µm off, contained if that is past the rim.
  The authored first drifter is not placed for a daughter: her mother's water is
  round her, and the floors hold. (The prototype re-placed one only when no drifter
  was within her horizon + 300 µm; that happened 0 times in 29 divisions.)
- **A return after death** is a born cell at a quiet start in the same drop, not
  a fresh water (§9).

### 8.4 How difficulty scales

- **What is made is tuned to you**, exactly as today's arrivals are: the drifter
  share your senses call for, peers your size ±34%, no mouth made past 40. The
  difference is that it now shapes what the drop *becomes* over the next minutes,
  not what is in front of you this second.
- **What lives grows.** Residents eat and grow to the ceiling, so the drop is at
  its gentlest when it is new and gets harder over its first five minutes, then
  holds: with a sighted player's composition, threats to a r26 cell go from 62
  to 131 by five minutes and stay between 118 and 131 to 25 (§5.1's chosen rule,
  run again after §4.2's fix, a census every five minutes). That is the first of
  the owner's "dangerousness improve with time", arriving through growth before
  genes and learning do. §5 bounds it and §8.5 measures what an aged drop does
  to the forage bot.
- **Place.** The drop has thick and thin water and an edge. A player who has
  grazed a place out finds flocs and must move on; a wall at your back is a real
  refuge; the thinnest water is where spawns land, just past your horizon.

### 8.5 Measured against today

`tools/forage_probe.gd`, energy.md §7.3's method: a born cell steering at the
nearest body its mouth can take **on the screen** (1280x720 for 16:9, 1600x720
for a 20:9 phone), going for the living first; seeds 1 to 64 on each shape, three
minutes, a division answered by leaning port. The drop is the recommended one,
with §4.3's rates. Along the bot's path, every second: "food" counts the edible
bodies within 1,400 µm, settled flocs included, and "dread" is the membrane's own
`dread_level`. "The bar" is hunger, 0 full and 1 empty, averaged over the run.

| water | games | starved | meals | a meal every, median (range) | flocs eaten | first meal, median | the bar on average | divisions, median | food within 1,400 µm | dread, mean | dread above 0.5 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| today's water | 128 | **44** (34%), and 1 eaten | 1,514 | 12.5 s (7.7–27.6) | 0 | 19.6 s | 0.48 | 3 | 25.5 | 0.220 | 16% |
| the drop, new | 128 | **38** (30%) | 1,965 | 9.9 s (5.7–36.4) | 24 | 10.6 s | 0.36 | 4 | 26.1 | 0.223 | 17% |
| the drop, aged fifteen minutes | 128 | **37** (29%), and 1 eaten | 1,975 | 9.8 s (7.0–19.0) | 26 | 9.6 s | 0.36 | 5 | 26.2 | 0.216 | 17% |

**The drop is at least as fair as today's water, new or aged.** The bot starves
no more often, eats 30% more meals, finds its first in half the time, runs
fuller, and meets the same dread. How much the counts can say: whether one game
starves is nearly a coin toss, so 32 games of one water starve 8 to 11 times in a
new drop, 9 to 15 in the bubble, and **5 to 16 in an aged one**. That last spread is the aged drop's own: every seed ages a different
drop, and some come out harder than others. Its residents have grown, and they
take the bot's target from under it three times as often -- 2.9% of its chases
against 0.9% in a new drop (seeds 1 to 16, both shapes, counted by a read-only
tally that replays the same games to the frame).

On the prototype before §4.2's fix, seeds 1 to 32 on both shapes, the aged drop
against two changes to it:

| water | games | starved | meals | a meal every, median (range) | flocs eaten | first meal, median | the bar on average | divisions, median | food within 1,400 µm | dread, mean | dread above 0.5 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| the drop, aged fifteen minutes | 64 | **25** (39%) | 925 | 9.9 s (7.0–19.0) | 10 | 10.4 s | 0.39 | 4 | 26.0 | 0.193 | 14% |
| the same, without flocs | 64 | **27** (42%) | 889 | 10.4 s (7.3–25.1) | 0 | 10.6 s | 0.40 | 4 | 24.6 | 0.229 | 18% |
| aged under the radius cap alone: no age, no mouth ceiling | 64 | **18** (28%), and 1 eaten | 961 | 10.0 s (6.2–25.9) | 3 | 11.4 s | 0.38 | 4 | 25.0 | **0.379** | **34%** |

Flocs change nothing here either (§7.7). **What §5's rule buys is the dread**:
under the cap alone the bot swims through twice the dread, above 0.5 a third of
the time against a seventh, and was eaten once -- the bot divides too often to be
hunted much (§16), so a player who does not is the one who pays for a drop left
to grow.

---

## 9. Across runs

### 9.1 The recommendation

**The drop outlives the run, and is saved on the device** (row 8):

- **Pack 1a**: the drop lives for the session. A death returns you to the same
  drop, at a quiet place; the drop is simulated only while you are in it.
- **Pack 1b**: it is saved to `user://drop.save` and loaded on the next launch,
  and the dedicated server keeps one of its own. A drop thrown away at every death
  is today's water with extra steps: packs 2 and 3's evolution needs many
  generations, and a lineage can only accumulate in a water that is kept.

The dev app has its own package id and its own saves (CLAUDE.md), so the owner's
drop on the dev app never touches a player's.

### 9.2 What pack 1 lays down now, even before it saves

Every piece of state a save needs has a home in 1a, so 1b adds a file and not a
format:

- **`Body.id`**: a 32-bit id, unique for the life of the drop and never reused.
  Pack 2's lineage is ids (§12).
- **The drop's header**: format, seed, simulated age, next id, the rules hash
  (§9.4), the content version that wrote it.
- **Everything else a body is**: place, heading, radius, wound, meals, age and
  lifespan, whether it is mouthless or a floc, its settle and life, and its genome
  **by gene name**, never by index -- the wire's rule (`shared-pond.md` §2) and for
  the same reason: a retired gene loads as a name the build does not know, kept and
  inert, exactly as `rhabdom` is today.

### 9.3 The file

One `store_var` of plain types -- Dictionaries, Arrays and Packed arrays, never
objects -- through `FileAccess.open_compressed`, written to `drop.tmp` and renamed
over `drop.save`, so a phone killed mid-write keeps the last good drop.

- **Size, measured** on a drop that had run five minutes (`tools/save_size.gd`,
  537 bodies and 55 flocs): **99,984 bytes raw, 169 a body, and 29,458 bytes
  with zstd**. Building and compressing it took 0.67 ms here and reading it back
  0.97 ms: four to six on the assumed phone, a hitch worth hiding. Pack 3's
  behaviour genomes would add a few hundred bytes a body.
- **When**: at a death (on the black), when the pause screen opens, when the app
  is backgrounded or closed (`NOTIFICATION_APPLICATION_PAUSED`,
  `NOTIFICATION_WM_CLOSE_REQUEST`), and every five minutes of play, at a frame
  boundary. Never in the middle of play without a pause: a phone's write is a
  hitch, and the pause points are where nobody sees one.
- **The server** saves on the same schedule without the pause, and before every
  update restart, which already only happens with nobody connected.

### 9.4 Versioning against content packs

A content pack can change any number the drop is made of. So the save carries:

- **`format`**, an integer bumped only when the layout of the file changes. A
  format this build does not know is not read: the drop starts fresh and the old
  file is kept beside it as `drop.save.old`, once.
- **`rules`**, a hash of what the drop's bodies mean -- the gene list, the tier
  tables, `GROWTH_PER_MEAL`, `DIVIDE_RADIUS`, the ceilings -- written the way
  `Wire.RULES` is. A different hash does **not** discard the drop: every body is
  re-derived from its genome by name (upkeep, gape, speed), the ceilings are
  applied again (a body over one is trimmed by the ceiling's own rule, §5.2),
  bodies past a smaller rim are contained, and the spawner converges on a changed
  density by itself. It is logged, so a tester can tell a converted drop from a
  fresh one.
- **The content version** that wrote it, for the log only.

---

## 10. The shared pond and the dedicated server

### 10.1 In pack 1a: today's water

**A run that begins with a session up plays today's bubble, unchanged**: the
drop is built only when `NetSession.current` is null in `_ready`. That is
`normal_mode.gd`'s existing test for building `_pond`, so a phone that can meet a
friend keeps the pond, the mirror, the dedicated server and PROTOCOL 4 exactly as
they are, and 1a has **no `Wire.PROTOCOL` or `Wire.RULES` change**. Single player
gets the drop; the pond gets it in 1b.

### 10.2 In pack 1b: one drop, shared

**The host's drop is the pond.** A guest who arrives is placed in it; its own drop
is saved, set aside and taken up again when it leaves (a takeover is a return
into its own drop at a quiet place, behind today's §0.5 beat).

What replaces `_step_pond`'s four steps (`food.gd:2577`):

| today, per anchor | in the drop |
|---|---|
| cull past `CULL` | nothing is culled |
| quota: 34 per disc | the drop's population, one target for the whole drop |
| excess: retire one a frame while both are over | nothing: the drop is one population |
| floor: a drifter in every disc | the drifter floor per player, and the snow counts every player |

Every player is an anchor for the LOD (near means near any of them), for the hide
reach (a spawn is outside all of them) and for the ring (candidates round each).
New bodies are **made for the players in turn**, as the owner answered in
`shared-pond.md` §6 row 2. A player out of the water, dividing or dead, stays an
anchor while it has a body, as today.

**The dedicated server keeps a drop.** `open_dedicated()` loads its save or makes
one; `empty_water()` no longer retires everything: it saves the drop and stops
simulating it until the next guest, so an empty server still costs nothing.
Packs 2 and 3 may let an empty server's drop run at the far rate, so that it goes
on evolving overnight; that is their call, not this one's.

### 10.3 The wire: PROTOCOL 5

| change | why |
|---|---|
| **POND entries key on `id u32`, not `slot u8` + `serial u16`**: `id u32 · meals u8 · flags u8 · x f32 · y f32 · heading u8 · radius u16 · wound u8 · speed u8`, 19 B | a drop has more bodies than a byte counts, and an id outlives a slot. The mirror keys bodies, GENOME and the genome book on id |
| **the send set is capped at `SEND_MAX` 60**, nearest first, every hunter of the guest always in | 58 bodies lie within 1,940 µm on average at 4.9 per million, more in a thick patch. Header 8 + 60 water bodies · 19 + the person's 19 and its motion 12 = **1,179 B**, under the 1,392-byte MTU |
| **SETTLE `0x09`** (host → guest, reliable): `id u32 · x f32 · y f32 · radius u8 · settle u8 · life u16`, 19 B | flocs never move, so they are told once, as they enter the guest's reach or settle in it, not twenty times a second |
| **CLEAR `0x0A`** (host → guest, reliable): `id u32`, 9 B | a floc eaten, dissolved or out of reach |
| **ARRIVE carries the drop**: `centre x f32 · y f32 · radius f32`, +12 B | the guest draws the meniscus, contains its own cell, and hears and sees the rim with its own organs |
| **CONTACT gains `GRAZED` = 7**: the level is the nutrition, no gene | the guest's run feeds without growing |

A guest on PROTOCOL 4 is refused at HELLO by name, as 1, 2 and 3 are. A guest's
mirror holds only what it is sent -- at most 60 bodies and the flocs in reach -- so
a guest costs what it costs today; the host carries the drop.

### 10.4 What the referee must learn, and `Wire.RULES`

- **`Contact` gains `GRAZED`**, and `food.Contact` is already in the fingerprint
  (`net_probe.gd`'s `_rules_text`), so the hash moves on its own.
- **A graze is not a meal to the referee**: `pond.gd` calls `referee.ate()` only
  for ATE, never for GRAZED, so a guest that ate flocs is still expected at the
  radius its live meals give it. `drop.FLOC_GROWTH` = 0 goes in the fingerprint,
  so a pack that let flocs grow a body changes the protocol.
- **The rim**: the host contains the guest's body in its drop as it contains
  everything in its water, and a claim past the rim is held at it -- a clamp, not
  a foul, because an honest guest's own run contains it the same way.
  `drop.contain` goes in the fingerprint by a sample value, as `cell.mended` does.
- **The sister** near the rim is placed where `drop.contain(mother + side · 560)`
  puts her, so `judge_sister` accepts that point ± `SISTER_RING`.

So 1b is **`Wire.PROTOCOL` 5 and a new `Wire.RULES` in the same commit**, and
`net_probe`'s `referee` section fails until both are done, as CLAUDE.md requires.
Nothing about water cells' age, the ceilings or the spawner is judged -- they are
the host's water, not a guest's word -- so none of it is in the fingerprint.

---

## 11. The replay

The recorder keeps sixty seconds of the run as slots, 34 bodies a frame, and the
replay writes them back onto the run's own `Food` (`replay.md` §3). A drop has
554 bodies and outlives the run, so both halves change in 1a:

- **48 recorder slots**, holding the 48 living bodies nearest the player each
  frame. A body keeps its slot while it stays in the set; a newcomer takes a free
  one; a freed slot writes radius 0, which both views draw as nothing -- the
  mirror's convention. 48 covers about 1,770 µm at the drop's density: the frame,
  dread, scent and the beam. `STRIDE` grows by 84 floats, 322 to 406, and the
  ring from 4.4 MB to **5.6 MB** (replay.md §3.1's units). Genome deltas key on
  the body's id.
- **Flocs as timestamped deltas**, SETTLE and CLEAR with place and radius, like
  the wire's: they never move, and their fade is a function of time.
- **The drop's centre and radius** as one delta at the start of the window.
- **`AT_HUNTER` records a recorder slot**, not a field index.
- **The replay binds a private `Food`** -- 48 slots, the flocs, the rim -- and
  never writes to the run's. Scribbling on the real field was free when a run
  kept nothing; it would now overwrite the drop the player returns to. This is
  the private-node binding `shared-pond.md`'s Phase 3 planned for the pond, done
  in 1a for single player.

---

## 12. Hooks for packs 2 to 4

Not designed here; named so that pack 1 leaves room for them.

| later | the hook pack 1 leaves |
|---|---|
| **a body carries a lineage** (pack 2) | `Body.id`, and room in the save for `parent` and `generation`; 0 in pack 1 |
| **cells are born from division** (pack 2) | `_spawn()` is the one door every new body comes through -- spawner, sister, first drifter -- so a birth is a spawn with a parent; the spawner fills only up to `SPAWN_SHARE` of the target and backs off by construction (§6.5); the radius cap at `DIVIDE_RADIUS` is where division goes |
| **a body carries a behaviour genome** (pack 3) | `Body.brain`, null in pack 1 (the hand-written state machine); saved by the same rule as genes, by name and version |
| **the same blocks drive every body** (pack 3) | decisions are made on the LOD tick, 7.5 a second, near and far alike (§4.3), from the per-body senses the grid answers; `_decide(b)` wraps today's `_look_for_prey` entry so a brain can take its place |
| **a hungry cell dies of it** (pack 3) | `Body.hunger`, reserved; §5 measured it, and it wants its own balance pass |
| **the same blocks drive the player** (pack 4) | `cell.gd`'s steering is written from one place a frame, `_read_steer()`; a brain writes `steer` there instead, on the same tick |
| **an evolving server drop** | §10.2: the server's drop saves and sleeps when empty in pack 1; running it at the far rate is one flag |

---

## 13. Generic mechanics, names at the edges

CLAUDE.md: keep the mechanic free of the cell and the gene. `food.gd`'s own §9.8
note already says a second environment writes its own seeder; this makes the drop
the first environment that is a file.

| file | what it knows | what it does not |
|---|---|---|
| `game/mechanics/space_grid.gd` **new** | integer ids, points, a bucket size | what an id is |
| `game/mechanics/basin.gd` **new** | a closed region: `contain(p, r)`, `depth(p)`, `exit_along(origin, dir)`, `nearest_rim(p)`, `inside(p, r)`; a disc today, other shapes by other scripts with the same five calls | water, glass, cells |
| `game/mechanics/replenish.gd` **new** | a population, a target and a time constant: the debt; the thinnest of a set of candidate points under a counting callback; whether a point is hidden from a set of observers with reaches | what is being made, or for whom |
| `game/mechanics/snowfall.gd` **new** | a rate per area and a keep-chance against a local count: how many fall this tick and which stay | what falls |
| `game/normal/drop.gd` **new** | **this water, and its seeder**: every number in §2–§7 by name -- `RADIUS`, `SHALLOWS`, `DENSITY`, `SPAWN_*`, `HIDE_MARGIN`, `LIFESPAN`, `GROW_GAPE_MAX`, `GENE_FLOOR`, `SNOW*`, `FLOC_*`, `LOD_*`, `EDGE_*`, `SHORE_*`, `START_TRIES` -- the words drop, meniscus, floc, and the decisions only this water makes: what is short, whose turn it is, where a run starts. It calls the four mechanics for the arithmetic and `food.gd`'s `_seed_drifter`, `_seed_peer` and `_draw_genome` for the cells | how the grid, the basin or the arithmetic work |
| `game/normal/food.gd` | cells, genes, mouths and senses, as today, reading the drop's numbers | the grid's or the basin's insides |

A second water (`roadmap.md` phase 8) is a second environment file and perhaps a
second basin shape; nothing in `game/mechanics/` changes for it. The seeding
tables `food.gd` holds today (`DRIFTER_SHARE`, `PEER_SPREAD`, `GENE_WEIGHTS`,
`TIER_WEIGHTS`, `ARRIVAL_GAPE_MAX`) are this water's too and belong in
`drop.gd`; moving them is left to whichever pack first needs a second water,
because it touches every tool that reads them.

---

## 14. Build plan

### 14.1 Files

| file | change |
|---|---|
| `game/mechanics/space_grid.gd`, `basin.gd`, `replenish.gd`, `snowfall.gd` | new (§13) |
| `game/normal/drop.gd` | new: the environment (§13) |
| `game/normal/food.gd` | `Body` gains `id`, `age`, `life_span`, `lag`/`last_t`, `near_frame`, `inert`, `settle`, `life`, and reserved `hunger`, `brain`, `parent`; the drop's path beside the bubble's, chosen once per run: `setup_drop()`, `_process` at three rates by distance (§4.3), every all-pairs pass through the grid and the near-first prey search (§4.2), containment and the shore turn, the spawner, floors and gene floor, age and remains, the ceilings in `_devour`, the snow and flocs, flocs in contacts and in each sense (§7.5), the rim in the ping, the shadow, the beam and touch (§3.2), the quiet start and its clearing, `enter_water()` on division and return, `put_sister` contained; signals `shored(bearing, strength, at)` and `grazed(nutrition, at)`; `bodies_near(point, reach)` for the view |
| `game/normal/normal_mode.gd` | the drop when `_net` is null in `_ready`; `shored` → `_bus.hit`; `grazed` → feed without growth, the flood with no gene, `mark_meal`; `_be_born` and `_return` enter the drop instead of `setup()`; a starved cell leaves remains |
| `game/normal/motes.gd` | grit inside the rim, the first mote included; seeded after the drop |
| `game/vision/water.gdshader` | `drop_on`, `drop_center`, `drop_radius`, `drop_band`: film, meniscus line, dry glass (§3.3) |
| `game/vision/vision.gd` | the four uniforms; `_draw_floc` and the ring bloom; `_draw_cells` asks `bodies_near()` instead of rebuilding five arrays over every body |
| `game/replay/recorder.gd`, `replay.gd`, `panes.gd` | 48 nearest in stable slots, floc and rim deltas, `AT_HUNTER` as a slot, a private `Food` (§11) |
| `tools/drive.gd` | `--drop=0\|1`, `--start=quiet\|centre\|edge`, `--edge-gap=`, `--flocs-near=`, `--desert=`, `--age=`, and §4.4's switches (`--lod-full=`, `--lod-near=`, `--prey-rings=`), set on the run before it enters the tree, as `--mode` is |
| `tools/forage_probe.gd` | grazes, the living-first bot, `[forage-near]` (food, dread, living along the path), `[forage-compete]` (targets another eater took first), meal times (§15) |
| `tools/eco_probe.gd` | new: the drop alone, census and cost (§15) |
| `tools/drop_probe.gd`, `.tscn` | new, in CI (§14.3) |
| **1b** `game/normal/drop_save.gd` | new: §9.3–§9.4 |
| **1b** `game/net/wire.gd`, `pond.gd`, `referee.gd`, `net_session.gd` | PROTOCOL 5 and `RULES` (§10.3–§10.4) |
| **1b** `game/server/server.gd`, `food.gd`'s `open_dedicated`/`empty_water` | the server's drop, saved and asleep when empty |
| **1b** `tools/net_probe.gd` | `pond-field` and `pond` on the drop; the new events; `referee` on grazes, the rim and the contained sister |

**Nothing** in `addons/launcher/`, `ci/` or `project.godot`.

### 14.2 Phases and releases

Each phase is one pull request into `dev`, played on the dev app before the next.

| phase | contents | the owner can try |
|---|---|---|
| **1a-1** | the four mechanics files and `drop.gd`, with `drop_probe`'s grid, basin, replenish and snowfall checks; nothing uses them yet | nothing: the game is today's, which the gate proves (§14.4) |
| **1a-2** | the drop in single player: world, grid, LOD, containment, the rim in every sense and in full vision, the spawner and floors, age and ceilings, the quiet start, divisions and returns in the drop, motes; flocs off | the drop, its edge, persistence |
| **1a-3** | flocs: the snow, remains, grazing, the senses, the drawing | food that isn't alive |
| **1a-4** | the replay on the drop | watching a death in the drop |
| **release 1a** | | players get the drop alone; multiplayer is today's |
| **1b-1** | the saved drop | the drop continuing next launch |
| **1b-2** | PROTOCOL 5: the pond and the server on the drop | two phones in one drop, and the server's |
| **release 1b** | | everyone gets the drop |

**Two releases, not one** (row 10): 1a changes nothing multiplayer, so a phone on
1a still meets a phone or a server on 1a in today's pond, and a player on 1a is
not refused by anyone else on 1a. 1b is the protocol change, and it goes out when
the pond on the drop has been played by two phones on the dev app.

**`binary_version`: no bump in either.** Everything is GDScript, one shader, and
scenes: content, delivered as a pack.

### 14.3 Probes, and what CI checks

A new CI step, **"Check the drop"**, runs `tools/drop_probe.tscn` headless and
greps `[drop-probe] ALL PASS`, then greps for `SCRIPT ERROR|Parse Error`, in the
levels probe's shape and for its reasons. Its checks, each failing with its fix
taken out:

1. **The grid never misses**: 10,000 random queries against brute force, every id
   within reach returned.
2. **The basin**: `contain`, `depth`, `exit_along`, `nearest_rim` against brute
   force; a contained point is inside.
3. **Nothing is made where it can be seen**: 2,000 spawns with one player and
   with two, and none within any player's hide reach for its kind (§6.3); the
   first drifter outside the view.
4. **Containment**: after 1,800 frames no body's centre past `RADIUS − r`, the
   player's included; no mote past the rim.
5. **The ceilings**: after five minutes at `--sensed=1`, no water body over
   `DIVIDE_RADIUS` and none with a gape of `GROW_GAPE_MAX` or more.
6. **The floors**: every gene in `DRIFTER_GENES` carried by at least
   `GENE_FLOOR` living bodies at every count; a living drifter within the floor
   reach of a still player at every check.
7. **The LOD reaches past the senses**: `LOD_NEAR ≥ max(PING_RANGE_BY_TIER) +`
   the widest body the ceilings allow `+` slack, and `≥` every other reach in the
   tables (scent, dread, the beam at its longest level, touch); `LOD_FULL ≥` the
   view's reach on the widest screen plus the camera's lead and the widest body;
   `LOD_EVERY` even. A future sense that reaches further fails CI instead of being
   slowed where it can be sensed.
8. **Determinism**: one seed twice, the same census line; and the same seed with
   the near-first prey search on and off, the same census line.
9. **Flocs**: none edible before it has settled; a graze changes hunger and not
   the radius or the genome; remains where a cell died of age.
10. **1b, the save**: save, load, the same bodies to the bit; an unknown gene
    survives; an unknown `format` starts fresh and keeps the old file; a smaller
    `RADIUS` contains; a changed `rules` re-derives and logs.

The existing steps keep passing: the scene boots, the input path (`drive.gd`,
now in the drop), the Back gesture, the levels probe, the LAN session. In 1b
`net_probe` gains the pond-on-the-drop checks and its `referee` section proves
`PROTOCOL` and `RULES` moved together.

### 14.4 The identity gate, where it still applies

The drop changes single player by design, so `shared-pond.md` §5's fingerprints
are not the drop's gate. They still hold everything else:

- **1a-1** must be byte-identical to `dev` everywhere: the four files are unused.
- **The bubble**, which every run with a session still plays in 1a: the six
  fingerprints with `--drop=0`, `field_diff` against `dev`'s `food.gd`, and the
  render and sensation diffs, all identical.
- **The drop's own gate** is statistical and in §15: the census and the forage
  numbers against this document's, and `--field-cost` against §4.4's table and,
  before 1a ships, on a phone.

### 14.5 What it replaces

| today (`food.gd` unless named) | in the drop |
|---|---|
| `COUNT` 34 kept within `CULL` 1,700 of you, `_step_recycle` reseeding past it (`:2559`) | the drop's whole population, always, the far part stepped at a lower rate (§4) |
| `_consume` reseeding an eaten body in place (`:1998`) | the body is retired; the spawner pays the shortfall back somewhere thin (§6) |
| `_seed`'s arrival ring, 920–1,350 µm round you (`:4146`) | the thinnest of twelve points, past every player's hide reach (§6.3) |
| `setup()` at every division, which throws the water away (`normal_mode.gd:1637`) | `enter_water()`: the daughter stays in her mother's water (§8.3) |
| the opening: the first drifter, and nothing that could eat you within `DREAD_RANGE` | the quiet start, then the same clearing; the first drifter kept (§8.1) |
| growth without a bound in `_devour` (`:2541`) | the radius cap, the gape ceiling after every meal, and age (§5) |
| all-pairs prey search, contacts and separation | the grid (§4.2) |
| **1b**: `_step_pond`'s cull, quota, excess and floor (`:2577`) | one population; every player an anchor for the LOD, the hide reach and the ring (§10.2) |
| the recorder's 34 field slots, replayed onto the run's own `Food` | the 48 nearest in stable slots, replayed onto a private `Food` (§11) |

The bubble stays in the code through 1a, because a run with a session still
plays it, and through 1b as `--drop=0`, the reference the probes compare the
drop against. Deleting it is a chore for the release after, once nothing
compares against it.

---

## 15. To measure again

Every probe is in `tools/`, excluded from every export. Headless, `--fixed-fps 60`,
with the prototype's flags after the `--`; in the build they are `drive.gd`'s
(§14.1).

### 15.1 Cost

```
godot --headless --path . --fixed-fps 60 res://tools/drive.tscn -- --seed=S \
    --mode=0 --scheme=0 --radius=30 \
    --genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1,ampulla:1 \
    --field-cost=3600 --ocean --density=4.9e-6 --ocean-r=R --spawn-tau=5 \
    --water-hunger=0 --lifespan=180 --grow-gape-max=40 --clear=1 \
    --lod-full=1100 --prey-rings=1 --ocean-log=10
```

for S = 7, 12345, 2026, one run at a time on an idle machine, today's field (the
same line without the drop's flags) between them. Leave out `--lod-full` and
`--prey-rings` for §4.4's other rows, or use `--lod-near=1100` for its last; add
`--age=900` for the aged one. `--ocean-log=10` prints the phases. The cell dies
in every run, so fewer than 3,600 frames are timed; the line says how many.

### 15.2 The drop alone

```
godot --headless --path . --fixed-fps 60 -s res://tools/eco_probe.gd -- --ocean \
    --seed=1 --until=1500 --every=150 --sensed=0.6 --spawn-tau=5 \
    --density=4.9e-6 --water-hunger=0 --lifespan=180 --grow-gape-max=40 \
    --lod-full=1100 --prey-rings=1
```

prints a census every 150 s (living, drifters, peers, flocs, threats to r26, r34
and r40, peers at r40, mean peer radius, genes carried, spawns and every cause of
death, mean dread at 64 random points) and the frame's cost by phase. `--desert=D
--watch=D` clears a disc at the start and counts it back; `--anchored` puts a
still player in it; `--lod=0` and `--grid-cell=20000` are §4.1's other rows, run
as `--seed=1 --until=90 --every=30 --ocean-r=6000` with the prototype's defaults.
The same five minutes with `--prey-rings=0` and `=1` print the same census.

### 15.3 The forage bot

```
godot --headless --path . --fixed-fps 60 -s res://tools/forage_probe.gd -- \
    --size=1280x720 --seed=S --mode=0 --scheme=0 \
    --genome=cytostome:1,cirrus:1,flagellum:1 --probe-until=180 \
    --screen=1280x720|1600x720  [drop flags]
```

S = 1 to 64 on each shape for §8.5's first table, 1 to 32 for the rest. Without
drop flags it is energy.md §7.3's run, and reproduces its numbers exactly on
seeds 1–16 (6 and 4 starved). With them: `--ocean --density=4.9e-6 --spawn-tau=5
--water-hunger=0 --lifespan=180 --grow-gape-max=40 --clear=1 --lod-full=1100
--prey-rings=1`, plus `--age=900` for the aged row. §7.7's pairs and §8.5's
second table ran on the prototype before §4.2's fix, without the last two flags
(and the first two pairs without `--clear=1`), with `--detritus=0`,
`--desert=2500` or `--age=900`; the cap-only row drops `--lifespan`,
`--grow-gape-max` and `--clear`. The same command three times prints the same
lines to the byte. The prototype's `forage_probe.gd` also prints
`[forage-compete]`: the chases the bot began and the targets another eater took
first, a read-only tally that leaves every game as it was.

The nose bot is the same line with `--genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1
--sniff` in place of `--screen=`, on seeds 1 to 32 (energy.md §7.4's bot).

### 15.4 The bubble's real density

The forage line above with no drop flags prints `[forage-living]`: living bodies
within 1,400 µm along the path, 26.8–27.8 on seeds 1–4.

### 15.5 Renders

§3.4 and §7.6's commands, through `tools/shot.tscn` under xvfb with
`--rendering-driver opengl3` and `--fixed-fps 60`, at 1280x720 and 2400x1080.
One frame rendered three times first: 0 differing pixels.

---

## 16. Left open

1. **The drop is over the frame budget here, and no phone was measured.** It
   costs 1.9 times today's field against the 1.5 this document set (§4.4), and
   the factor of six is an assumption. The builder measures `--field-cost` on a
   real budget Android phone before 1a ships; the tick from 1,100 µm out (1.7,
   measured) and per-sense scan lists are the levers if it does not fit.
2. **The forage bot is almost never hunted.** It divides every 30–45 s and every
   birth grants `FIRST_DELAY`, so it was eaten 4 times in the 928 games of §7.7,
   §8.5 and the nose bot's; predation is measured only as the dread along its
   path. A player who does not divide that fast will meet the aged drop's
   hunters (§5.1); the dev app is where that is judged.
3. **Point of view was measured with the nose bot only.** It starves every game
   in the bubble, the drop and the drop without flocs, 32 seeds each, as
   energy.md §7.4 found in the bubble; numbers pinned at 100% say little, and the
   radar bot was not run. The rim adds to what point of view can know (§3.2) and
   takes nothing away.
4. **Aged drops vary** (§8.5). On average one starved the bot as often as a new
   drop, but 32 games of one aged water starved 5 to 16 times against 8 to 11
   for new ones, and its grown residents take the bot's target three times as
   often. How an aged drop feels to a person is the dev app's to judge;
   `LIFESPAN` is the dial for how grown its residents get (§5.1).
5. **Flocs showed no measurable benefit** to any bot (§7.7). They ship because
   they were asked for and cost little; the dev app judges them.
6. **Water-cell hunger is deferred** (§5.2), measured and not wanted yet.
7. **Row 5 reverses a settled call** (§5.2). If the owner keeps the legendary
   organism, the ceiling code goes and nothing else in this document changes.
8. **The recorder keeps 48 bodies.** Enough for everything but the farthest
   echoes, which the ring keeps on their own.
9. **Moving the seeding tables into `drop.gd`** waits for a second water (§13).

---

## 17. Owner's calls

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | How big is the ocean? | 8 mm across · **12 mm across ✓ recommended** · 16 mm across | A newborn swims straight across it in 2 min 22 s · 3 min 32 s · 4 min 43 s, and a fast cell in about half that. At 12 mm you reach the edge from the middle in under two minutes and come back to places you know within a run. At 8 mm the edge is on the screen often; at 16 mm most of it is somewhere you never go. |
| 2 | What is at its edge? | **the rim of a drop of water: you bump into it, and the water ends ✓ recommended** · the square wall of a counting chamber · no edge: swim off one side and come back on the other | The ocean is a drop of water on a microscope slide. At its round rim you feel a knock, your radar hears a wall, your eyespot sees a shadow, and full vision shows the bright edge of the water and dry glass beyond. A square chamber has corners things get stuck in. Wrapping round has no end at all, which is what you said you never reached. |
| 3 | What is the ocean called? | ocean · **the drop ✓ recommended** · the slide | It is what the game shows: a drop of pond water under a microscope. "Pond" already means playing together. Only these documents and the code use the name today; a player would meet it only if a later screen names the place. |
| 4 | What ends a cell in the water? | **it dies of age, about three minutes after it was made, and never grows bigger than you can ✓ recommended** · it has to eat like you, or starve · nothing: it only stops growing at your full size | With nothing at all, a cell that kept eating grew to 664 µm across, nearly the height of your screen, in eighteen minutes. Dying of age keeps the water young: it gets harder over its first five minutes and then holds, and an old cell leaves food where it dies. Hunger is the most realistic, but in testing it doubled how often you starve, because hungry cells eat the food around you; it is kept for when the water learns to hunt. Only stopping growth fills the water with full-grown cells for good. |
| 5 | Can a cell in the water grow a mouth big enough to swallow you as you reach full size? | **no: its mouth stops growing at the widest the water makes ✓ recommended** · yes, as you decided for today's water: a cell that earns it by eating is a legendary organism | You decided that today's water keeps a cell that eats its way past the widest mouth, as a legendary organism, and today it is rare, because the water round you is thrown away every time you divide. An ocean keeps its cells, so it stops being rare: after 25 minutes, 37 cells could swallow you as you reach full size, about one every three screens. With the limit, the fear fades as you grow to full size, as it does today, and a later pack can bring a legendary cell back on purpose. A cell that is still growing meets the same danger either way. |
| 6 | What does food that isn't alive give you? | **food only: it fills you, and you don't grow or get a gene ✓ recommended** · food and growth, no gene · food, growth and the dead cell's gene | It is detritus: small brown clumps that settle where few cells are and melt away after two minutes, a meal where nothing alive is left. Only eating living cells makes you bigger and changes your genes. If it grew you, a player could reach every division without ever hunting. In testing it seldom decided whether a newborn starved, because the ocean refills an empty place within a minute; it is there for when it has not yet. |
| 7 | Do cells that die leave food? | **yes: a cell that dies of age or poison leaves a small clump where it died ✓ recommended** · no | Death feeds the water, so a place where cells died is a place with food. A cell that is eaten leaves nothing: whoever ate it got it. |
| 8 | Is the ocean kept between runs? | only while the app is open · **saved on the phone, and the same ocean continues next time ✓ recommended** · a new one every time you die, as today | Evolution in the next packs needs many generations. If the ocean is thrown away, its cells can't improve. Saved, the ocean you come back to is the one you left, and the home server can keep one of its own. It is saved when you die, pause or leave the app. In testing an old ocean was as kind to a newborn as a new one on average, but some old oceans were harder than others. |
| 9 | Where does a run start? | **somewhere quiet, chosen for a newborn ✓ recommended** · always the middle · anywhere | Quiet: out of 64 places, the one where the fewest cells could eat a newborn, the nearest counting most, with food nearby but not right on top of you; and if a hunter is still in range, it is moved away before you arrive. The middle is always the same place and just as dangerous as it happens to be. Anywhere can start you next to a hunter. |
| 10 | Ship it all at once, or in two? | one release · **two: the ocean alone first, then playing together and saving ✓ recommended** | Two: the first release changes nothing about playing with a friend, so nobody is locked out of anyone's game; the second changes the network version and needs both phones updated. One: everything at once, and a bigger thing to test before any player gets it. |

**Row 4** decides how the water feels over time, and §5.1 has every option's
numbers. **Row 5 is a call you have already made** for today's water
(`genes-and-cilia.md` §1.3); an ocean that keeps its cells changes what it
costs, so it is asked again, with the reasoning in §5.2. If the answer is yes,
the ceiling code goes and §5.1's "the cap, and death at 180 s" row is the drop;
nothing else here changes. **Row 8** needs no answer before 1a: the
session-long drop is built either way, and only 1b saves.

**Row 1 also sets part of what the water costs a phone** (§4.4): 8 mm is about
a sixth lighter than 12, which is a reason to choose it only if a phone
measurement says 12 does not fit. **Rows 1, 3 and 9 are one constant or one word
each to change later.** **Row 6 is a rule the shared pond's referee copies from
1b on** (a floc grows nothing, and the host holds a guest to it), so after 1b
ships, changing it is a protocol change; rows 4, 5 and 7 are the host's own water
and never cross the wire.
