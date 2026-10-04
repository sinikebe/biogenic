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
prototype is a scratch copy of the game outside the repository, on `eb4dbf1`,
switched on by `--ocean` after the `--` so that every run without it is the
shipped water. Nothing it measures has changed on `dev` since: up to `8d61338`
the commits touch the server, its router forward, the dev server's ports and the
docs, and every file this document cites a line of is identical, so §0's line
numbers are `8d61338`'s. Every number below was measured in this container (Intel Xeon at
2.1 GHz, 4 vCPU, Godot 4.7.2, headless or under xvfb with `--rendering-driver
opengl3`); nothing ran on a phone. §15 has every command. The builder builds it
for real and shoots §3.4 and §7.6 again.

**Revised on 2026-09-30 to the owner's answers** (§17). Seven of the ten calls
stood as recommended; rows 4, 5 and 8 changed the design. Every cell in the drop
now has one body under one set of rules, the player's: it starves as you do,
grows as you do, sees and swims with its own organs, and dies of hunger or of
being eaten (§5). The drop is kept, in the owner's shape: your own drop on the
device, served to friends when you host, and a room on the home server that
lives on while it is empty (§9, §10). The prototype was extended to those rules
and everything they move was measured again; the first pass's numbers that
still stand say so. §17.1 has the eight new calls those answers raised.

**Reviewed the same day.** An independent review recomputed the numbers from the
raw logs and found the owner-facing parts wanting: venom, the courtesies a
player still gets, and four claims about today's code. Its corrections are in
place, the forage runs a changed rule touches were run again, and pass 2's own
noise was measured (§8.3).

**The second round was answered the same day** (§17.1): every call as
recommended, except venom. The owner kept venom out of pack 1 -- the gene pass
brings it in two variants, venomous and poisonous, each as stacks that wear off
over time, hurting while they last (row 12) -- so `veneneux` works in the drop
exactly as it does today (§5.6), and the pass-2 prototype's swallow death for
every mouth is reverted.

"Ocean" is the owner's word. This document calls the place **the drop**, because
that is what it is under a microscope and because "pond" already names the
shared pond; the owner chose it (row 3).

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
  outside CULL is simulated at all" (`:2540`). The first pass measured what a
  drop does with that: a body of **r332 after eighteen minutes** (§5.10).
- **The water is tuned to you**: 45% of arrivals are mouthless drifters (92% when
  you sense nothing, `:183`, `:310`), peers are your radius ±34% (`:192`), no
  arrival opens its mouth past 40 (`ARRIVAL_GAPE_MAX`, `:214`), at least one
  drifter always exists, the first cell is a drifter 1,000 µm ahead
  (`FIRST_DISTANCE`, `:505`), nothing that could eat you starts inside
  `DREAD_RANGE`, and nothing hunts you for `FIRST_DELAY` = 42 s (`:813`).
- **Water cells never starve, and they are not the body you are.** They drift
  at 9 µm/s (`:316`), notice anything they can swallow within `NOTICE_RANGE` =
  1,900 µm whatever their senses (`:804`), snap their nose onto a far target
  (`:1411`), and rest `CALM_MIN`–`CALM_MAX` = 30–55 s after a meal (`:799`). A
  hunter chasing you cruises at 1.2 and lunges at 1.7 times *your* speed,
  whatever its own tail; chasing another cell, at 1.2 and 1.7 times the faster
  of its own tail and its prey (`:764`, `_reference_speed` `:4514`). A peer is a
  mouth and whatever else its slots draw from the drifter list, 3 to 7 organs in
  all (`_draw_genome`, `:4403`), so nothing guarantees it a tail, a `cirrus` or a
  sense. Only a cell hunting you may swallow you (`:1856`); your `pellicle` and
  your venom protect you against a swallow and theirs do not (`:1872`, `:1966`);
  a cell that swallows or chews through you is not fed by it, and breaks off
  (`:1868`, `:2078`); and their `trichocyst` never fires. §5.7 lists every
  difference and what pack 1 does with it.
- **Every per-pair pass is all-pairs**: prey search (`_look_for_prey`, `:1336`),
  contacts (`_contacts_water`, `:1929`) and separation (`_step_separate`,
  `:2382`), with shared-pond Phase 0's pre-checks; the player's senses scan every
  body (`_step_sense`, `:2772`, and the beam, ping and touch). §4 measures what
  that costs at a drop's count.

---

## 1. Decided, in one place

1. **The drop is a round drop of water 12 mm across** (row 1, answered): radius
   6,000 µm, 554 living bodies at a density of 4.9 per million µm² (§2).
2. **Its edge is the meniscus** (row 2, answered). A body cannot cross it: a
   drifting cell turns off it, a hunter slides along it, and the player is held
   and **feels it as a knock** at its bearing. The `ampulla` hears it as the
   widest, longest echo in the game, a `stigma` sees it as a shadow, a beam stops
   on it and a `palp` touches it. Full vision draws a bright meniscus line, a lit
   film of thinning water inside it and dry glass beyond, with the counting grid
   still etched on it (§3).
3. **Everything in the drop exists all the time.** A uniform grid answers "what
   is near here" for every pass, and a body far from every player runs **the
   same rules at a lower rate**: every mouth decides 7.5 times a second wherever
   it is, a far mouth moves 7.5 times a second, a far mouthless body 1.9 times.
   Nothing within 1,100 µm of a player -- the view and a margin -- is ever
   slowed, and nothing within 2,000, past the farthest any sense reaches, below
   every second frame (§4). **In its steady state it costs 2.6 times today's
   field here** -- 2.5 in a new drop's first minute, and the first pass's drop,
   measured in the same hour, 2.1 -- over the 1.5 this document set itself. A
   frame-time readout on the dev app, on the owner's phone, decided whether that
   is too much before 1a ships (§4.4, §14.2): it is not, for the phone drops at
   most 0.1 % of its frames.
4. **One body for every cell** (rows 4 and 5, answered). The player, a friend
   and a water cell run the player's metabolism -- the same tank, upkeep, stroke,
   turn and meal -- grow to 40 and no further, keep whatever mouth they eat
   their way to, notice only what their own senses reach and are armoured by
   their own `pellicle`, which row 5 decides; and, as rows 14 and 15 decided,
   swim only as fast as their own tail and swallow whatever fits on contact.
   **A cell dies of hunger or of being eaten -- swallowed or chewed -- and age is
   gone.** Venom stays exactly as it is today (row 12, answered): whatever bites
   a venomous body takes a share of the bite back and can die of it, and
   whatever swallows a venomous *player* dies, while a player swallows a
   venomous water cell safely. It is the one body rule not yet the same for
   every cell, until the gene pass brings venomous and poisonous cells, each
   with stacks that wear off (§5.6, §5.7). What else stays different is named:
   how a water cell decides (hand-written until pack 3), how it was made (the
   spawner, until pack 2's births), and the 42 s of grace a player gets after a
   birth (row 16, kept) (§5).
5. **A cell with no `cytostome` absorbs its food from the water** (row 11,
   answered): the drifters are osmotrophs, never starve, and die only when
   something eats them; a player who drops their own becomes one too (§5.3).
6. **The water makes cells that can live**: every peer has a born cell's mouth,
   `cirrus` and `flagellum` and at least one sense, and no drifter carries venom
   (row 13, answered). Growth fills the drop with full-size hunters that
   cannot divide until pack 2: at a newborn's composition about half of them sit
   at r40 and half of the hunters that starve starve there; at a sighted
   player's, about a third, and 38 % (§5.5, §5.8, §5.9).
7. **The spawner keeps the drop at its population**, paying the shortfall back
   over 5 s, one body at a time, each at the thinnest of twelve candidate
   points -- half of them in the ring just past a player's horizon -- and **never
   inside what any player can see or sense** (§6). It makes what is short: the
   drifter share your senses call for, peers your size, and any gene the drop is
   down to its last two carriers of. Under one metabolism the drop turns over
   fast: about 355 new bodies a minute at a newborn's composition and 635 at a
   sighted player's. From pack 2 it only tops up what births do not.
8. **Food that isn't alive is detritus: flocs** (rows 6 and 7, answered). Flakes
   fall everywhere at one rate and **stay where there are few cells** -- the
   owner's rule as a chance -- settle into focus over five seconds rather than
   appearing, and dissolve after two minutes. A floc is food and nothing else:
   no growth and no gene. **A cell that dies of hunger or of poison leaves
   one**, and those remains are now most of the drop's flocs (§7). The nose
   smells a floc, a beam and a `palp` find it, the `ampulla` and the `stigma` do
   not; full vision draws a small brown clump with the edible bloom round it.
9. **A run starts somewhere quiet** (row 9, answered): the spot, of 64 drawn,
   where a born cell would feel the least dread, with nothing edible within
   400 µm and the most food within 1,100; anything still inside `DREAD_RANGE`
   that could swallow it is moved out, as today. The first drifter, the free
   sense and the 42 s before anything may hunt you are kept (row 16, answered);
   a division no longer regenerates anything (§8.1).
10. **What the player meets is measured, not tuned** (the owner, §17): with the
    same bot, a new drop loses about as many of the full-vision forage bot's
    games as today's water -- 40 % of 192 against 36 %, inside what the seeds
    move -- but fewer to hunger and far more to a swallow by a big cell it swims
    into; a drop aged fifteen minutes loses about as many as a new one. In pass
    2 chance alone moves a set of 64 games by ten or more, so only the two rules
    that touch the player directly, rows 15 and 16, move it measurably (§8.3).
    The dials a playtest turns are in §8.5.
11. **The drop is kept** (row 8, in the owner's words): your drop is saved on the
    device when you die, pause or leave the app, and frozen while you are away;
    your cell is in it when you come back (row 17, answered); a phone that
    hosts serves its own drop and saves it when hosting stops; a guest's drop
    waits for it; and the home server keeps **one room that always lives** (row
    18, answered), for about 3 % of a core of this container while it is
    empty (§9, §10).
12. **Pack 1 ships as two releases** (row 10, answered): single player first,
    with no wire change -- a run with a session keeps today's water and today's
    rules -- then the shared pond and the server on the drop, which is
    `Wire.PROTOCOL` 5 and a new `Wire.RULES`, plus saving (§10, §14).
    **Overtaken on 2026-10-01**: both were on `dev` before the first went out,
    so pack 1 ships as one release, when the owner runs it (§14.2).
13. **The mechanics are generic** (§13): a spatial grid, a basin with an edge, a
    replenisher and a snowfall in `game/mechanics/`, knowing points and counts;
    the metabolism's arithmetic in one place that the player and the water both
    call; this water's numbers and names -- drop, meniscus, floc -- in one
    environment file.
14. **No binary change**: GDScript, one shader and scenes, all content.

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
| the first pass's water, cost a frame here, p50, against today's 453 µs (§4.4) | 735 µs, 1.6 times | **882 µs, 1.9 times** | 1,213 µs, 2.7 times |

Speeds are `CellBody.speed_for()`: 56.5 and 111.5 µm/s. Under one metabolism
the 12 mm drop costs 2.5 times today's field, measured in another hour in which
the first pass's read 2.1 (§4.4); 8 and 16 mm were not measured again.

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
- **A drifting body turns off the shore** -- a drifter, or a hunter at rest or
  swimming to look for food. Inside the band, a body heading outward turns
  toward the middle at up to `SHORE_TURN` 1.4 rad/s, scaled by how deep into the
  band it is, so drifters do not grind along the rim. A hunter in a run is only
  contained: a chase can run along the edge.
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
  teal, a few pixels wide at any zoom. **The square is `k * k`**, with
  `k = (d - R) / 2.2 px`, never `pow(k, 2.0)`: `k` is negative inside the rim,
  and `pow` of a negative base is undefined in GLSL ES 3.00. The prototype's
  first shader used `pow`, and this container's driver happened to draw it
  right: the edge frame with `k * k` is 0 pixels from it here. A phone's driver
  need not be so kind;
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
player in it (the first pass's hour; 433–839 in pass 2's, §4.4), **12–15 µs a
body** at 34 bodies. `shared-pond.md` §4 split an
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
| `_look_for_prey` | the body's own reach, the farther of its senses' and its `stigma`'s (§5.7; 0 when resting), + the widest body + 40 µm slack |
| water contacts | the mouth's own bound, `mouth_reach + gape·MOUTH_BITE + widest` |
| separation | `r + widest` |
| the player's senses and contacts | one list a frame: `max(SCENT_RANGE, DREAD_RANGE, ping, beam)` + widest + slack |
| spawner, snow, floors | 800 µm counts |

The 40 µm slack covers what moved since a body was last re-bucketed; the widest
body is kept as a running maximum, which only has to be too big.

**A prey search looks near first.** Nearest wins, so a search that finds its
winner within `PREY_NEAR` 400 µm, over the buckets that close, has found the
answer: anything nearer lay in those buckets. Only a search that finds nothing
that close asks its whole reach. The same body wins either way: five
minutes of the drop with and without it print the same census lines, every
meal and death alike. In drifter-rich water most searches stop at the first
pass (§4.4 has what it saves).

**One trap the prototype fell into, for the builder.** A pass that loops over
the grid's answer and calls something that asks the grid again must not share
the answer's array: packed arrays are passed by reference, and the prototype's
LOD loop carried on over a prey search's candidates instead of its own list, so
some near bodies skipped frames. The fix changes only how regularly the bodies
near a player are stepped. The first pass measured §4's costs and statistics
and its forage runs again after it; the rest -- the drop as a whole, the rim,
the renders, and pairs that ran on one prototype on both sides -- stands from
before it. Everything pass 2 measured ran on the fixed prototype.

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
here. In the first pass, with age and without hunger: ten minutes of the drop
alone on seeds 1–3, with the LOD and with every body stepped every frame
(`eco_probe.gd`, `--sensed=0.6`, §15.2 with `--until=600` and `--lod=0|1`),
means of the three:

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

**Again under one metabolism** (pass 2's rules, §5), where a far body's hunger,
search and orienting turn are integrated over the time it is owed: the same
three seeds, ten minutes, a sighted player's composition (`--sensed=0.6`,
`--same-rules=1`), means of the three:

| | cells starved | drifters eaten | cells eaten | spawned | hunters at r40 | could swallow r26 / r34 / r40 | mean hunter r | dread, r26 | runs begun |
|---|---|---|---|---|---|---|---|---|---|
| every body every frame | 703 | 4,140 | 1,317 | 6,764 | 58.7 | 124 / 61 / 50 | 32.7 | 2.15 | 14,369 |
| **the LOD, as recommended** | **699** | **4,125** | **1,405** | **6,822** | **60.3** | **113 / 61 / 54** | **32.2** | **1.98** | **11,602** |
| seed-to-seed range, either | 653–726 | 3,974–4,308 | 1,274–1,438 | 6,660–6,978 | 51–67 | 105–125 / 54–66 / 49–58 | 31.2–33.0 | 1.90–2.30 | -- |

What every body eats, starves of and grows to is the same within the seeds'
spread. Two numbers move: **a far body begins a fifth fewer runs** for the same
meals, so fewer of its runs fail and are begun again -- and **dread and the
threats to a born cell read lower again**, on the side that costs a player
nothing, as in the first pass. Those two are the ones to watch, and so are two
small counts the table folds into "cells eaten", which move outside the seeds'
spread: **hunters chewed apart**, 49–62 at the full rate against 23–47 with the
LOD, and **mouths that died swallowing a venomous cell**, 38–47 against 51–57
-- a death pack 1 does not keep (§5.6), so only chewing is left to watch. Each
is about 1 % of the drop's deaths in those ten minutes, and why the rate moves
them was not measured. The water alone cost p50 5.8 ms a frame without the LOD
and 1.0 ms with it, in runs that shared the machine with other work: the ratio
is the point, not the numbers.

### 4.4 Frame budget

**The budget this document set itself: the water may cost at most 1.5 times
today's field**, measured the same way with the player in it --
`drive.tscn --field-cost=3600` at `--radius=30` with a tier-1 nose and `ampulla`
(shared-pond.md §4's method), seeds 7, 12345 and 2026, one run at a time on an
idle machine, today's field and the drop interleaved. **The drop does not meet
it. Under one metabolism, in its steady state, it costs 2.6 times today's field
here**: a drop aged fifteen minutes, which is what a player swims in after the
first five (§5.9). A new drop's first minute costs 2.5, and the first pass's
drop, measured again in the same hour, 2.1.

Measured on 2026-09-30: two runs on each seed, the three waters interleaved,
each run started only when no other Godot process was running and the
one-minute load was under one (§15.1). All 21 runs got that window; none was
taken under load.

| water, µs a frame here | bodies | p50, seeds 7, 12345, 2026 | p50 median | p90 | times today's, p50 / p90 |
|---|---|---|---|---|---|
| today's field | 34 | 433–839 (two runs each) | 515 | 515–1,006 | 1.0 / 1.0 |
| the first pass's drop, as it recommended | 554 | 966–1,215 (two each) | 1,064 | 1,508–1,837 | 2.1 / 2.2 |
| pass 2's drop, new: its first minute | 554 | 1,102–1,494 (two each) | 1,279 | 1,669–2,219 | 2.5 / 2.4 |
| **pass 2's drop aged fifteen minutes: the steady state** | 554 | **1,205–1,523 (one each)** | **1,318** | **1,821–1,948** | **2.6 / 2.5** |

The drops held 516 to 550 living bodies through these runs. A new drop's runs
time only its first minute or so, because the cell dies in most of them; the
aged runs are the drop a player actually swims in. This hour was noisier than
the first pass's: one seed's two runs of today's field read 545 and 839, where
the first pass's hour read 407–521 for all of them, and the first pass's drop
moved from 1.9 times to 2.1. **Only ratios from one hour compare.**

**The longest frames are the probe's, not the drop's.** The drops' runs show
frames of 12.6 to 34.3 ms, against today's 2.3 to 4.8: `--ocean-log` prints a
census every ten seconds from inside the timed step, and the census counts
threats over every body and samples dread at 64 points. The aged drop without
it, three seeds, idle: longest frames 5.9–6.8 ms, p50 1,249–1,456 µs. The build
has no census; a playtest readout must not have one inside the frame either.

**Not measured: a phone that hosts with a guest.** Two players are two anchors:
twice the water stepped every frame when they are apart, two scan lists, and
the wire on top (§10). That is the worst case the drop has, and it runs on a
phone; it is 1b's gate (§14.2).

**Where pass 2's extra goes.** The same runs on copies of both prototypes that
time the step by part, one run a seed, mean µs a frame over eleven ten-second
windows (§15.1). Timing adds its own cost -- two clock reads a body for the tank
alone -- so only the differences count:

| part of the frame | the first pass | pass 2 | difference |
|---|---|---|---|
| **the steps, all told** | 586 | 806 | **+220** |
| -- every body's tank | -- | 65 | +65 |
| -- hunters looking for prey | 44 | 88 | +44 |
| -- hunters drifting or searching, besides looking | 28 | 43 | +15 |
| -- hunters in a run | 76 | 67 | −9 |
| -- drifters | 101 | 115 | +14 |
| -- flocs, each asking whether a drifter's mouth closed on it | 3 | 29 | +26 |
| -- the LOD's loops and each body's bookkeeping | 334 | 399 | +65 |
| the player's senses | 242 | 239 | 0 |
| separation | 185 | 187 | 0 |
| contacts, the player's and the water's | 136 | 138 | 0 |
| the spawner, floors and snow, and the grid | 32 | 33 | 0 |

**The extra is the body, not the water**: every body stepped keeps a tank, more
hunters are hungry and looking at once -- none sits out 30–55 s of calm now --
and every floc near the player asks the grid for a drifter's mouth every frame.
Contacts, separation and the player's senses cost what they did.

**The phone factor is six**, assumed and stated, not measured. GDScript is an
interpreter and its cost is one core's; this Xeon core is roughly four times a
2020 budget phone's big core (a Cortex-A73/A75 class, Geekbench-6 single core
around 400 against about 1,600 here), and an interpreter's branchy,
memory-bound work loses more on small cores than a benchmark does, so four
becomes six. At six, today's field is 2.7 to 3.1 ms of the 16.7 ms a frame has
at 60 Hz, the most §14.2's gate holds a phone to, on such a phone -- by which
hour's 453 or 515 µs one takes -- and pass 2's drop in its steady state 7.1 to
8.0 ms. **Only the ratio transfers**; a phone is measured before 1a ships, by
§14.2's gate.

**The first pass's variants**, measured in its own hour against today's
407–521 µs: what the half-rate band, the near-first search and the drop's size
each cost. Pass 2 changed none of them.

| water, p50 µs a frame here, the first pass's hour | bodies | seeds 7, 12345, 2026 | median | times today's |
|---|---|---|---|---|
| today's field | 34 | 407–521 (three runs each) | 453 | 1.0 |
| the drop, Ø 12 mm, everything within 2,000 µm every frame | 554 | 1,035–1,095 (two each) | 1,047 | 2.3 |
| and the half-rate band from 1,100 µm | 554 | 827–997 (two each) | 938 | 2.1 |
| and the near-first prey search (§4.2) | 554 | 977–1,090 (two each) | 1,049 | 2.3 |
| **both: the first pass's drop as recommended** | 554 | **839–1,013 (two each)** | **882** | **1.9** |
| both, in a drop aged fifteen minutes | 550 | 805–858 | 849 | 1.9 |
| both, Ø 8 mm | 246 | 576–828 | 735 | 1.6 |
| both, Ø 16 mm | 985 | 1,128–1,293 | 1,213 | 2.7 |
| the search, and every frame only within 1,100 µm, the tick past it | 554 | 749–804 | 760 | 1.7 |

The search alone replays the first row's runs to the frame, so the whole of its
difference is its cost: nothing at the p50, 48 µs off the steps' mean; with the
band, 938 becomes 882.

**Why it is over: density, and now the body.** The drop keeps 61 bodies within
2,000 µm of you where the bubble keeps 34 in all, and a body near you costs what
it costs in the bubble -- more, now that it keeps a tank. The far water is about
a quarter of the cost at 12 mm and nearly half at 16. The density is what
fairness asked for (§6.1), so fewer bodies is not the lever. In order:

1. **Measure a phone** (§14.2's gate). Whether the rest of a frame leaves a
   budget phone 8 ms for the water is not knowable here (§16). **Measured on
   2026-10-01: the owner's phone holds its 60 Hz in the drop** (§14.2), with
   nothing but what the build does from the start.
2. **A tank that cannot move is not stepped**, which the build does from the
   start (§14.1): a drifting drifter absorbs what its upkeep costs and does
   nothing that is paid for, so its hunger cannot change until it eats, and
   skipping it changes no number. Measured on the prototype (`--skip-still=1`):
   five minutes of the drop on two seeds print the same census to the byte,
   and the steps' mean fell from 703 to 670 µs a frame over six runs each --
   about 30 µs, most of what the tank costs once the timers are gone, because
   most bodies stepped are drifters. The last of those twelve runs overlapped
   another Godot process that started as it ended; without that pair, 691
   against 661. **A floc could ask for a drifter's mouth
   on its tick**, as a mouth looks for prey, instead of every frame near the
   player: most of its 26 µs. It changes when a floc is found, as the LOD
   changes when a body is stepped, so it is a lever, not a default.
3. **The tick from 1,100 µm out** (the first pass's last row, 1.7 against 1.9):
   its case rests on how finely the senses resolve rather than on how far they
   reach -- a hunter at 1,500 µm moving in 13 µm steps 7.5 times a second,
   against a dread and a scent that fall off over a millimetre -- and it needs
   §4.3's statistics again before it replaces the band.
4. **The senses' scan list per sense** rather than one list at the widest reach,
   and separation in the band at the tick: the builder's, not measured here.

**Drawing** is the other cost: full vision today reads `points()`, `radii()`,
`headings()`, `genomes()` and `wounds()` over every body every frame and culls
per body. At 554 bodies that is 2,770 rebuilt entries a frame for the dozen on
screen. `vision.gd` asks the field for the bodies within the frame's circle
instead, through the grid (§14.1).

---

## 5. One body for every cell

### 5.1 The owner's rule, and what it asks

The owner, on rows 4 and 5 (§17): *"A cell dies of hunger, nothing else. Unless
it gets eaten by another one"*, and *"all cells follow the same rules. Me,
friends, NPC, doesn't matter."*

So every cell in the drop -- the player, a friend, a water cell -- is **one body
under one set of body rules**: the same tank and the same prices, the same
growth and the same mouth, the same senses and the same tail, and the same ways
to end. A water cell differs from you in four things, all named: **how it
decides** (the hand-written behaviour, which pack 3's blocks replace), **how it
was made** (the spawner, which pack 2's births take over), **the 42 s of
grace** after a birth, a division or a return, in which nothing may hunt a
player or a friend and which no water cell gets (`FIRST_DELAY`, row 16: kept
until pack 2 gives every newborn the same), and **venom**, whose swallow death
still protects only a player (row 12: until the gene pass).

**Venom stays as it is, for now** (row 12). Today it works both ways for a
player only: whatever bites a venomous body pays for it and can die of it, for
every body; whatever *swallows* a venomous player dies; but a player swallows a
venomous water cell safely. Killing the eater is the opposite of being eaten,
so the owner's "nothing else" did not settle it, and it was asked. The owner
kept venom out of pack 1: the gene pass brings it in two variants, venomous and
poisonous, each as stacks that wear off over time (§5.6).

The first pass bounded the water with age and a ceiling on the mouth (§5.10).
Both are gone. What bounds the water now is the owner's own rule: a cell that
cannot feed itself dies.

### 5.2 The metabolism, for every body

**Every body runs the player's tank, line for line** -- one with no `cytostome`
has an income as well (§5.3) -- and pays for what it does at the player's
prices.
None of the numbers is new:

| | value | where |
|---|---|---|
| the tank, at rest | `HUNGER_SECONDS` 36 s | `metabolism.gd` |
| the grace, at empty | `STARVE_GRACE` 10 s, then death by hunger | `metabolism.gd` |
| upkeep | `(1 + 0.18 × tiers above the first) × burn` | `genome.gd`'s `upkeep_of` |
| a bigger tank, cheaper effort, light | `vacuole` 1.28–2× the tank, `crista` 0.88–0.66× every cost, `plastid` 0.12–0.34 taken off the upkeep (a born cell's is 1): `max(upkeep − photosynthesis, 0) / reserve` | `cell.gd` tier tables, `metabolism.gd` |
| a stroke | `STROKE_COST` 0.0113 s per unit of speed added: a body holding `v` against the drag pays `v × DRAG / SPREAD_LOSS × STROKE_COST` a second, **0.50 at 56.5 µm/s**, what the player's flagellum costs it | `cell.gd` |
| a steering turn | `TURN_COST` 1.3 s a radian; the wander is the water's and free | `cell.gd` |
| a dash | `DASH_COST_BY_TIER` × 36 s | `cell.gd` |
| spat out by venom | `VENOM_COST_BY_TIER` × 36 s | `cell.gd` |
| a meal | `MEAL` × `clamp(prey r / eater r, 0.35, 1.40)` of the bar; a floc the same, with no growth and no gene | `food.gd`, `metabolism.gd` |

The player's flagellum pays per beat, on the speed each beat adds; a water body
swims at a steady speed and pays for holding it against the drag -- the same
`STROKE_COST` on the same speed, 0.50 a second for a born cell either way. A
water body integrates all of it over whatever time it was stepped (§4.3), which
is exact for rates that do not change within a step. **One definition**:
`metabolism.gd` gains static functions -- the rate at rest, the cost of an
effort, a meal -- that the player's node and the water both call, so a change
to the player's pace is a change to the whole drop's, and cannot be made to one
without the other (§13, §14.3 check 10).

**Drifting is free; swimming is not.** A water cell at rest drifts at 9 µm/s,
which is the water carrying it -- the player's wander is free for the same
reason. A cell that swims, to chase or to search, pays for its own speed and
for every radian it steers. The player cannot drift: its flagellum is its drive
and beats whether it is steered or not, so a born cell pays 0.50 a second more
than a resting water cell. That is how the player is controlled, not
a rule of the body, and it is pack 4's to revisit when the player's own blocks
can rest.

### 5.3 How cells without a cytostome live (row 11)

**A body with no `cytostome` absorbs its food from the water.** Real mouthless
protists are osmotrophs: they take up dissolved organic matter through the
membrane, and most of what drifts in pond water that is not eating something is
doing that, or photosynthesising. So a body whose `cytostome` tier is 0 takes
`ABSORB` 1.0 seconds of rest a second from the water: exactly a one-gene
drifter's upkeep. A drifter at rest therefore holds its tank where it is, never
starves, and **dies only when something eats it**.

It is the same rule for every body, keyed on the organ and not on the actor. A
player who puts a gene over their own `cytostome` -- the irreversible move
`genome.gd` allows, genes-and-cilia.md §9 item 7 -- becomes an osmotroph too: its
upkeep is paid, and it still pays for its strokes and turns, so a born cell
without one lasts about 55 s instead of 30 (empty at 46, steering a third of the
time) and can still swallow what fits a gape of 0.58 r. That changes the
decided call it came from: §9 item 7 weighed the move as "a real and
interesting mistake or a soft lock", survivable only because the drifter floor
holds; absorbing, it is neither -- a slow, cheap body that lives on what fits a
small mouth. Row 11 answered it so.

The other two answers were weighed, and row 11 set them aside:

- **Drifters eat the flocs**, which makes the snow the drop's only income and
  the owner's non-living food the base of the food chain. It is the most
  realistic of the three, and the hardest to balance: drifters would have to
  seek food, the snow would have to feed about twelve bars a second across the
  drop, and every drifter far from a floc would starve.
- **Drifters starve like anyone**, in about 45 s, and the spawner replaces
  them. Tried for two minutes (`--drifters-starve=1`, seed 1): 6.5 drifters a
  second died of hunger across the drop, and after one minute it held 329
  flocs, ten times its usual.

**A mouth with no cytostome is still a mouth**: tier 0 opens 0.58 r, as it does
on a player who has dropped theirs. So a drifter whose mouth closes on a floc
small enough swallows it, by the rule every mouth obeys -- 12 to 16 times in
thirty minutes of a drop at a newborn's composition. Drifters hunt nothing;
that is behaviour.

### 5.4 How a hunter eats: hunger, rest and search

This is behaviour, the hand-written state machine, and pack 3's blocks replace
it. Its defaults were chosen so that a cell under the player's metabolism can
actually live on what the drop holds:

- **It rests while it is fed** and hunts when its hunger reaches `HUNT_AT` 0.3.
  After a meal it digests for `REST_MEAL` 5 s whatever its hunger says.
- **It turns to face what it found**, at its own cirrus's rate and price, before
  the run begins (`ORIENT_SECONDS` 8 at most). Today's hunter snapped its nose
  onto a target spotted from afar -- a free, instant half turn no body can make.
- **A hungry cell that finds nothing swims to look**, at its own speed, paying
  for it, instead of drifting until it starves. Real ciliates swim faster and
  turn more when starved.
- **A miss costs a moment, whoever was missed**: `REST_MISS` 5 s where it is,
  then its hunger decides again -- after a run at a cell, at a friend or at you,
  and after a run a dart broke. Today every failed run ends in a flight of up to
  20 s at a lunge and 30–55 s of calm. Paid for at a hunter's own speed, that
  flight costs it most of a tank (the table below); kept for runs at a player
  only, it would be a courtesy the owner's row 5 does not allow. So the relief
  `food-and-predators.md` §5.4 gave the player is what any cell gets: a hunter
  that misses you rests five seconds, and comes again only if it is still
  hungry and you are still the nearest thing it can eat. Measured: of the
  1,024 forage games run before this rule, a hunter ran at the bot in 28 -- 3
  of the new drop's 64, none of the aged drop's, 7 of the 64 with the contact
  swallow off -- and run again under it, 4 of those 28 ended differently,
  three of them for the better; every other game is the same to the byte
  (§15). §8's numbers are the uniform rule's.

What each piece is worth, measured by taking it out: the drop alone for four
minutes at a newborn's composition, seeds 1–3 (`tools/eco_probe.gd --death-log`,
§15.2), counting the hunters that starved:

| the rules | hunters starved in 4 min | of them, never fed once | drifters eaten | cells eaten |
|---|---|---|---|---|
| **pass 2, as recommended** | **137–158** | **35–50** | 1,047–1,098 | 114–133 |
| peers made as today: a mouth and two to six others at random | 196–203 | 91–105 | 748–801 | 65–92 |
| a miss ends in today's flight, up to 20 s at a lunge, and 30–55 s of calm | 234–249 | 91–112 | 888–924 | 86–103 |
| no search: a hungry cell that finds nothing drifts | 134–153 | 45–59 | 1,024–1,135 | 109–128 |
| hunting from hunger 0.5, and 10 s of digesting | 150–165 | 48–60 | 727–783 | 86–101 |
| noticing 1,900 µm off whatever its senses, as today | 104–109 | 14–22 | 1,236–1,248 | 102–123 |
| chasing at today's speeds (row 14) | 100–115 | 20–35 | 1,212–1,276 | 150–156 |
| no hunger at all, the first pass's water | 0 | 0 | 1,435–1,480 | 110–130 |

**What kills a hunter is what it is made of and what a miss costs it**, not
how long it rests: made as today, half the hunters that starve never eat once,
and today's flight after a miss, now paid for at a lunge, costs a hunter most
of a tank. Searching changes nothing measurable and is kept because a cell
that drifts until it starves is not hunting. Today's senses and speed would feed
the hunters better, at the drifters' expense: a quarter fewer starve, eating a
sixth more of the drifters. What that does to the player is inside what chance
moves the forage bot (§8.3).

### 5.5 Growth and the mouth

- **Growth stops at `DIVIDE_RADIUS` 40**, where the player's does, four units a
  meal to get there. A floc grows nothing (row 6).
- **The mouth has no ceiling of its own.** A cell that eats its way to a bigger
  mouth keeps it, as the player does (row 5): `cytostome` rises when a meal's
  gene is a mouth, to tier 3, a gape of 1.40 r, 56 µm at r40. The seeding
  ceiling stays on what the water *makes* (`ARRIVAL_GAPE_MAX` 40, §5.8) and on
  nothing it grows. So the legendary organism of genes-and-cilia.md §1.3 is
  back, on the owner's word: after thirty minutes 16 to 23 bodies in a
  newborn's drop, and 49 to 55 in a sighted player's, could swallow a player at
  full size (§5.9).
- **A water cell at 40 has nowhere to go in pack 1.** It cannot divide, so it
  stays at 40 and eats to live: every meal still counts as food and as a gene
  into its seven slots. But a drifter is worth 0.43 of a r40 bar against 0.65 of
  a born cell's, so it needs a meal every nine seconds or cells its own size, and
  most do not manage. Measured over thirty minutes (§5.9): **34 to 50 of a
  newborn's drop's 92 hunters sit at r40 at every census after the first** --
  about half -- and 56 to 69 of a sighted player's 182, about a third; half of
  the hunters that starve at a newborn's composition starve there, and 38 % at
  a sighted player's. It is the stand-in for age that the rules produce by
  themselves, and pack 2's division is what empties it.

### 5.6 What kills

Four causes, for every body, and nothing else -- `food.Cause` as it is. The
owner's rule is the first three; the fourth is venom, as it is today (row 12):

| cause | how |
|---|---|
| **hunger** | empty for `STARVE_GRACE` 10 s |
| **swallowed** | a mouth closed on it and it fit: its radius × its `pellicle` armour under the gape |
| **chewed** | bitten to nothing by a mouth it did not fit |
| **poisoned** | it bit a venomous body and took the venom back until it was bitten through, for every body; or it swallowed a venomous *player*. Today's rule, kept through pack 1 (row 12) |

**Venom, as today, until the gene pass** (row 12, answered on 2026-09-30; the
owner's words are in §17.1). Row 12 asked whether a mouth that swallows a
venomous cell dies, the player's included. The owner chose neither: venom is
not reworked in pack 1, and the gene pass brings it in two variants -- a
**venomous** cell's bite adds stacks of venom to what it bites, and whatever
bites or eats a **poisonous** cell takes stacks; the stacks wear off over time,
doing damage while they last. Until then `veneneux` does exactly what it does
today:

- **whatever bites a venomous body** takes `VENOM_BITE_BACK_BY_TIER` of each
  bite back into its own wound, and dies of it when that wound is whole -- every
  body, as today;
- **whatever swallows a venomous player dies**, and the player is spat out
  alive, paying `VENOM_COST_BY_TIER` from its hunger -- a water cell or a friend
  alike, as the shared pond already does (`shared-pond.md` §1.3;
  `food.gd:2211`). A venomous water cell is swallowed like any other.

So venom is the one body rule not yet the same for every cell (§5.7), and the
gene pass replaces both of its effects. The drop's drifters carry no venom
(row 13, §5.8), so the venomous bodies are cells with mouths, and full vision
draws the organ.

**What keeping today's venom does to the numbers.** Every run in §4, §5 and §8
was made with the pass-2 prototype's swallow death for every mouth, which pack
1 does not have. Under today's rule the drop's water cells stop dying of a
swallowed venomous cell -- 0.8 to 1.1 a minute at a newborn's composition and
3.6 to 5.2 at a sighted player's, of the 355 to 635 bodies made a minute (§5.9)
-- and the forage bot's poisoned games go: three of the 448 in §8.3's first
table, one in each of the plain bot's first two sets of 64 and one with the bot
that passes over venom. Run again under today's rule (`--venom-swallow=0`), the
plain bot's seeds 1–64 lost 64 of 128 against 59, with no game lost to poison:
the game poisoned at 131 s lived, the one poisoned at 113 s starved at 125 s
instead, and 21 games ended differently in all, as the whole drop plays out
differently -- inside what chance moves pass 2's games (§8.3).

**Remains** (row 7): a body that dies of hunger or of poison leaves one floc
where it died, half its radius, settled (§7.4), the player's included. A body
swallowed or chewed apart feeds whoever finished it and leaves nothing -- and
from pack 1 that holds when the body is a player: **the cell that eats you is
fed by it**, with your radius over its own, growth and your dominant gene, and
then digests `REST_MEAL` as after any meal -- unless you carry venom, which
kills it, as today. Today it is not: it breaks off
unfed (`food.gd:1868`, `:2078`). The prototype kept today's, and nothing it
measured depends on it, because a solo run ends at that moment.

### 5.7 The same rules: the audit

Every place a water cell and a player differ today, and what pack 1 does about
it. **Body** rules are the same for everyone from pack 1 but one, venom, which
waits for the gene pass (row 12); **behaviour** stays hand-written until pack
3, but never by breaking a body rule; **what the water makes** is how a new
body is born and stays the spawner's (§5.8).

| today | kind | pack 1 | measured |
|---|---|---|---|
| water cells never starve | body | the player's metabolism, every body (§5.2); mouthless ones absorb (§5.3) | §5.9 |
| water cells grow without bound | body | growth stops at 40, as yours does (§5.5) | §5.9 |
| a water cell's mouth has a ceiling only on what the water makes | body | no ceiling on what it grows, as for yours (row 5) | §5.9 |
| a water cell notices prey 1,900 µm off whatever its senses (`NOTICE_RANGE`) | body: perception | **its own senses** (row 5, not asked again): the reach of its `chemocyte`, `ampulla`, `ocellus` or `palp` by tier, 150 to 1,900 µm; a `stigma`'s 620 µm for bodies at least 0.8 of its size, which is what a shadow shows; touch only without one | §8.3 |
| a hunter chasing a player cruises at 1.2× and lunges at 1.7× the player's speed, whatever its own tail; chasing a cell, 1.2× and 1.7× the faster of its own tail and its prey (`_reference_speed`) | body: speed | **its own tail** (row 14, answered): `swim_speed_of(flagellum, axoneme)`, the arithmetic the water already uses to lead a player; a lunge is a `myoneme` dash, at its price and cooldown, or nothing | §8.3, and the chase contract below |
| a hunter snaps its nose onto a far target | body: turning | it turns at its cirrus's rate, paying for it, before the run begins (§5.4) | §5.4 |
| a water cell swallows a player only from a committed run | body: the mouth | **a mouth swallows what fits on contact, whoever it is** (row 15, answered) | §8.3 |
| `pellicle` armours a player against a swallow, not a water cell | body: the mouth | **every body**: a mouth measures its prey's radius × armour. Row 5 decides it; it was never put to the owner on its own (`shared-pond.md` §0.5 left it to a later phase), and it was not measured the other way | on in every §8.3 row |
| venom kills whatever swallows a player, not a water cell | body: what kills | **kept as today** (row 12): the one body rule not yet the same for every cell. The gene pass replaces it, and the bite-back, with two variants -- venomous and poisonous -- as stacks that wear off (§5.6) | -- |
| a water cell that swallows or chews through a player is not fed by it: no meal, no growth, no gene, and it breaks off (`:1868`, `:2078`) | body: the mouth | **fed as by any meal**, then `REST_MEAL` (§5.6, §14.1) | not in the prototype |
| a water cell's `trichocyst` never fires | body: defence | it breaks a run at it exactly as the player's does: in range, on its arc, then its cooldown | 5 to 12 darts a minute (§5.9) |
| a drifter's tier-0 mouth never closes | body: the mouth | it swallows a floc that fits (§5.3) | 12 to 21 in thirty minutes |
| a drifter drifts at 9 µm/s whatever its organs | behaviour | kept: drifting is being carried, and free (§5.2) | -- |
| rest is a 30–55 s clock after any run | behaviour | rest while fed, hunt when hungry, search when nothing is found (§5.4) | §5.4 |
| the flight of up to 20 s and the 30–55 s calm after any failed run | behaviour | **gone for every target**: 5 s where it is after any miss, whoever was missed, a run broken by a dart included (§5.4) | §5.4, §8.3 |
| `FIRST_DELAY`: nothing hunts a player or a friend for 42 s after a birth, a division or a return, and no water cell gets it | behaviour | **kept** (row 16) until pack 2 gives every newborn the same; the quiet start (row 9) with it | §8.3 |
| the free sense at 5 s is the player's | what the water makes | every peer the spawner makes carries a sense; a blind one is given one, as you are (§5.8) | §5.4 |
| peers are a mouth and two to six other organs drawn at random, as many as their radius has slots (3 to 7), with nothing that guarantees a tail, a `cirrus` or a sense; drifters carry any gene | what the water makes | peers carry a born cell's body plan and a sense; drifters carry no venom (§5.8) | §5.4, row 13 |
| the peer band, the drifter share and the tier weights follow your senses; no arrival's mouth past 40 | what the water makes | kept (§6.4) | -- |
| the water's gene hands you a sample to place; a water cell's goes straight in | behaviour: the choice | kept: a water cell cannot open a pause screen | -- |

**The chase contract, at a hunter's own speed.** Hunters were tuned so that a
cell that does nothing is caught and a cell that turns away and commits escapes
(`food-and-predators.md` §5.4.1: 11 of 14 and 13 of 14). Measured again with
`tools/chase_probe.gd` (§15.6): `drive.gd --hunt=900` and `--evade`, a born
player against a hunter with a tier-3 mouth, 14 seeds each:

| hunter | does nothing: caught | turns away: escaped |
|---|---|---|
| today's rule: tier-2 tail, but 1.2× and 1.7× your speed | 8 of 14 | 14 of 14 |
| its own tail, tier 1 (56.5 µm/s, yours) | **11 of 14** | **13 of 14** |
| its own tail, tier 2 (79 µm/s) | 8 of 14 | 12 of 14 |
| its own tail, tier 3 (111.5 µm/s) | 7 of 14 | 8 of 14 |
| tier 1 and a `myoneme` dash | 10 of 14 | 11 of 14 |

A hunter with your own tail still catches a cell that does nothing and still
misses one that commits away: the contract holds, because the chase was never
won on speed but on the intercept and the committed pass. What changes is that
the tail now matters on both sides: a faster hunter catches more of the cells
that turn away.

**The contract is one pass; what follows a miss is §5.4's rule.** Today's
hunter flees for up to 20 s and calms for 30–55; the drop's rests 5 s where it
is and comes again if it is still hungry and you are the nearest thing it can
eat. So an escape now buys seconds, not a minute, and dread comes back sooner.
This probe cannot show it: its cell is born, so `FIRST_DELAY` forbids a second
run inside its 40 s.

**Why today's rule reads 8 of 14 here, not the documented 11.** The documented
contract was measured on `predator.gd`, the single scripted hunter the water
cells have since replaced (genes-and-cilia.md §9 item 2). Here the hunter is a
water cell that `drive.gd --hunt` poses in body slot 0, and today's opening
moves body 0 to 1,000 µm along the cell's first motion as its first drifter
(`food.gd`'s `_first_pending`): every run starts where the opening put it, not
where it was posed. In 4 of the 14 seeds of a cell that does nothing (2, 4,
10 and 11, traced), the hunter was moved at 1.5 s and dropped its run by 2 s,
without a pass. Every row above starts the same way, so the rows compare with
each other and not with the documented 11.

### 5.8 What the water makes

The spawner makes new bodies; how it makes them is not a rule of the body, and
every choice below is the water's (`genes-and-cilia.md` §9.8), in `drop.gd`:

- **Peers carry a born cell's body plan**: a mouth, a `cirrus` and a
  `flagellum`, at tiers drawn as today, then the other genes drawn as today up
  to the slots their radius has. **A peer with no sense is given one**, a tier-1
  `chemocyte`, `ampulla`, `ocellus` or `stigma` in a bonus slot, as the player's
  newborn is at five seconds. Today's peers are a mouth and two to six other
  genes drawn from the drifter list, as many as their radius has slots, so
  nothing guarantees them a tail, a `cirrus` or a sense -- which cost nothing
  while a water cell saw 1,900 µm and swam faster than its prey. Under the
  body's own senses and tail, made that way, 196 to 203 hunters starved in four
  minutes instead of 137 to 158, about half of them without one meal (§5.4).
- **Drifters carry no venom** (row 13, answered): one gene at tier 1, drawn
  from the list without `veneneux`. They are the water's defenceless food, the
  owner's words for them, under today's venom and the gene pass's alike. A
  drop down to its last venomous bodies gets venom back through the next peer
  instead (`GENE_FLOOR`, §6.4).
- **A new body is fed**: hunger 0. A drop being made for the first time draws
  its tanks at 0–0.4, as a water that was already there.
- Kept: the peer band round your radius, the drifter share and the tier weights
  your senses call for, no arrival's mouth past `ARRIVAL_GAPE_MAX` 40, the gene
  floor, the drifter floor (§6.4).

### 5.9 The drop over thirty minutes

`tools/eco_probe.gd` (§15.2), the drop alone with a ghost player out of the
water, 30 minutes, a census every five, seeds 1–3; a newborn's composition
(`--sensed=0.2`, 83 % drifters) and a sighted player's (`--sensed=0.6`, 64 %):

| composition | at | living (target 554) | drifters | hunters | flocs | hunters at r40 | could swallow r26 / r34 / r40 | mean hunter r | mean hunter hunger | dread at random points, r26 / r34 / r40 |
|---|---|---|---|---|---|---|---|---|---|---|
| a newborn's | 0 min | 555 | 453–476 | 79–102 | 30 | 0 | 22–24 / 1–3 / 0 | 25.8–26.8 | 0.20–0.22 | 0.24–0.29 / 0.01–0.02 / 0 |
| | 5 min | 522–526 | 430–434 | 91–92 | 37–42 | 41–50 | 61–67 / 22–34 / 20–31 | 33.7–35.1 | 0.48–0.54 | 1.08–1.18 / 0.43–0.66 / 0.26–0.37 |
| | 15 min | 521–526 | 430–434 | 91–92 | 38–46 | 40–43 | 60–69 / 23–28 / 22–25 | 33.8–34.6 | 0.46–0.51 | 0.93–1.03 / 0.36–0.52 / 0.23–0.34 |
| | 30 min | 525–531 | 433–438 | 91–93 | 36–45 | 34–45 | 57–67 / 18–29 / 16–23 | 32.7–34.8 | 0.48–0.52 | 1.04–1.22 / 0.41–0.50 / 0.25–0.28 |
| a sighted player's | 0 min | 555 | 342–370 | 185–213 | 30 | 0 | 51–73 / 6–13 / 0 | 25.2–26.7 | 0.19–0.20 | 0.63–1.09 / 0.06–0.16 / 0 |
| | 5 min | 499–507 | 318–323 | 181–185 | 56–77 | 56–69 | 109–130 / 54–67 / 50–55 | 31.3–33.1 | 0.44–0.46 | 1.73–2.17 / 0.91–1.23 / 0.64–0.91 |
| | 15 min | 497–504 | 316–320 | 181–184 | 57–60 | 57–69 | 123–130 / 63–71 / 49–56 | 32.5–33.4 | 0.44–0.48 | 2.10–2.35 / 1.13–1.36 / 0.82–0.92 |
| | 30 min | 500–511 | 317–328 | 182–183 | 53–66 | 57–64 | 114–115 / 60–64 / 49–55 | 32.1–32.7 | 0.47–0.48 | 2.01–2.15 / 1.10–1.23 / 0.80–0.89 |

And what flowed through it in the thirty minutes, per minute, the three seeds'
range:

| composition | bodies made, after the first 555 | drifters eaten | hunters eaten or chewed | hunters starved (at r40) | flocs eaten by the water | swallowed a venomous body and died (a rule pack 1 does not have: §5.6) | darts fired | remains left / snow kept |
|---|---|---|---|---|---|---|---|---|
| a newborn's | 350–359 | 276–288 | 35–39 | 35–37 (half) | 26–28 | 0.8–1.1 | 5–7 | 36–37 / 1.5–2.1 |
| a sighted player's | 634–635 | 412–417 | 144–147 | 71 (38 %) | 67–68 | 3.6–5.2 | 11–12 | 75–76 / 1.5–2.2 |

**The drop holds its numbers.** The population, its composition and every
threat count are flat from five minutes to thirty on every seed: the drop has a
steady state, and reaches it in its first five minutes. That first five minutes
is growth -- hunters made at your size eat their way to 40 -- and after it
about half of them sit there at a newborn's composition, and a third at a
sighted player's.

**It turns over fast.** A hunter that starves has lived about a hundred seconds
and eaten six meals, on average, at a newborn's composition, and eighty seconds
and four meals at a sighted player's; a drifter lasts about a minute and a half
before something eats it at a newborn's composition, and under a minute at a
sighted player's. Nothing about that is visible as a clock: cells are eaten,
starve and are made somewhere out of sight, one at a time.

**It is more dangerous than the first pass's drop, and than today's water**, for
the reason §5.5 gives: nothing takes a hunter down from 40 but hunger. At a
newborn's composition two hunters in three could swallow a born cell after five
minutes, against a quarter in a new drop. The first pass's rule held a sighted
drop at 118–131 threats to a born cell, where this one holds 109–130 -- but it
held none that could swallow a full-size cell, and this one holds 49–55 (row 5).
Today's bubble, worked out from its own tables, threatens a r34 player with
about 9 % of its peers; this drop with a fifth to two fifths of its hunters.
What that costs a player who swims through it is §8.3: along the bot's own path
the dread it met was a little lower than today's on average, because it starts
where it is quiet and grows fast -- and it was swallowed far more often, almost
always by a big cell it swam into.

The water alone cost p50 733–829 µs a frame at a newborn's composition and
1,029–1,235 at a sighted player's, with the ghost player's surroundings stepped
every frame, three runs at a time; §4.4 has the cost with a player in it, and
§10.3 the drop with nobody at all, both taken one run at a time on an idle
machine.

### 5.10 What the first pass measured, and why it changed

The first pass bounded growth with a radius cap, a ceiling on the mouth after
every meal and death at 180 s ± 30 %, and deferred hunger because, built then,
it doubled the forage bot's starvation. Its numbers (the table below, §5.1 of
that version, one seed each, before §4.2's fix) still show what a drop does to
growth with nothing to stop it:

| after 25 min | peers r40 | threats to r26 / r34 / r40 | mean peer r |
|---|---|---|---|
| today's rule, nothing added (18 min) | 65 | 114 / 79 / 60 | 60.3, **largest r332** |
| a radius cap at 40 | 107 | 155 / 95 / 85 | 35.7 |
| the cap, the ceiling after every meal, and death at 180 s | 30 | 132 / 51 / 0 | 32.2 |

The owner answered that a cell dies of hunger or of being eaten, and that its
mouth grows as yours does (rows 4 and 5), so age and the ceiling are gone. What
the first pass's hunger lacked was everything in §5.4, §5.7 and §5.8: its
hunters saw 1,900 µm, swam faster than their prey, fled up to 20 s at a lunge
after every miss, and were made with whatever organs the dice gave.

---

## 6. Spawn rules

### 6.1 How many

`DENSITY` is **4.9 living bodies per million µm²**: 554 in the drop. It is set
by what a player actually swims through today, not by the nominal 3.74: the
bubble keeps 26.8–27.8 bodies within 1,400 µm of a foraging player (4.35–4.51
per million), and in a drop the player's own grazing thins its neighbourhood. At
4.9 the drop keeps **26.1 edible bodies within 1,400 µm of the bot against the
bubble's 25.5** (the first pass), and under one metabolism 28.2 against 25.4
over 192 games each, the dead's remains among them (§8.3). In the first pass, at
the nominal 3.74 and before the spawner had its ring (§6.3), the bot starved 16
games of 32 against the bubble's 10; at 5.5 it starved no less (15 of 64 against
14 for 4.9 in the same batch) and met 35% more dread along its path (0.27
against 0.20; above 0.5 for 21% of the time against 15%): more water is more
hunters, not more meals.

### 6.2 How often

A shortfall is paid back over `SPAWN_TAU` 5 s: each half second the spawner adds
`(target − living) · 0.5 / 5` to a debt and makes a body for every whole one, at
most `SPAWN_BURST` 8 a tick. A body that dies is replaced within seconds,
somewhere else. Paid back that way, the drop runs short by the turnover times
`SPAWN_TAU`: under one metabolism it holds **95 % of its target at a newborn's
composition and 91 % at a sighted player's** (521–531 and 497–511 of 554, thirty
minutes, §5.9). `SPAWN_TAU` is the dial if that matters; at 20 s the first pass's
hungry drop ran a third short.

What that is in practice, measured over thirty minutes (§5.9) and not counting
the first 555: **about 355 bodies a minute at a newborn's composition** -- 280
replace drifters the water ate, 37 hunters eaten, 36 hunters that starved --
**and 635 at a sighted player's**, where there are twice the hunters to feed. At a newborn's
composition the drifters turn over every minute and a half. The first pass,
without hunger, made 270 a minute; today's bubble reseeds about a hundred a
minute *round you* (§0).

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

Nothing is made within `SPAWN_INSET` 80 µm of the rim, and a drop's first fill
(§5.8) puts nothing within `FILL_INSET` 60 µm of it. Both numbers are the
prototype's and were never measured on their own: its `food.gd` draws the
spawner's points with `_uniform_in_drop(ocean_radius - 80.0)` (`:6176`) and the
first fill's with `ocean_radius - 60.0` (`:5439`).

Without the ring, and with one hide reach for every kind, the drop starved the
bot 29 games of 64; with both, on the same prototype, 14, and the edible bodies
within 1,400 µm of it went from 21 to 26: the player's own grazing had not been
paid back where it could reach it. The first pass's final drop starved it 38
games of 128 against the bubble's 44; pass 2's drop is in §8.3.

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
  the band, the tier weights, the arrival ceiling -- **made to live**: a born
  cell's mouth, `cirrus` and `flagellum`, and a sense if the draw gave it none
  (§5.8). In the shared pond, the players take turns (§10).
- **A drifter carries no venom** (row 13, §5.8).
- **The gene floor**: every two seconds the drop counts who carries what; the next
  drifter carries a gene in `DRIFTER_GENES` that fewer than `GENE_FLOOR` 2 living
  bodies carry -- and venom, which no drifter carries, comes back through the
  next peer instead (9 to 17 times in thirty minutes at a newborn's composition,
  once at most at a sighted one's). Genes are never lost, and "there is always a way to
  eat your way to any gene" stops being statistical, venom's way being to chew a
  venomous cell apart. Measured: all 16 genes present at every census of pass 2's
  thirty-minute runs, as at every one of the first pass's 390. **Two readings the
  build made, both kept**: the floor passes venom over when it picks the next
  drifter's gene, rather than stalling on it; and venom given back through a peer
  never takes the peer's body plan (`cytostome`, `cirrus`, `flagellum`) or its
  only sense -- it takes a spare slot, or one slot more when none is spare.
- **The drifter floor** stays: if no living drifter is within `hide + 600` of a
  player, one is made just past its horizon, ahead of it, at most every
  `DRIFTER_FLOOR_GAP` 10 s. With the ring it has nothing to do: it fired 0 times
  in the first pass's 256 games in the drop, and 0 in pass 2's. It stays as the
  invariant it always was. **Its `hide` is the reach for a body with a mouth**,
  about 1,500 for a born cell, although what it makes is a drifter: the
  prototype's floor asked `_hide_reach()` with its default. "Just past" is
  `DRIFTER_FLOOR_NEAR`–`DRIFTER_FLOOR_FAR` 50–350 µm past that reach, the
  prototype's `randf_range(50.0, 350.0)` (`food.gd:6117`), never measured on its
  own.

The first drifter a run meets is still placed `FIRST_DISTANCE` 1,000 µm along the
cell's first motion. It is 51 µm past the view and a born cell has no sense for
five seconds, so nothing sees it arrive; a division no longer re-places one
(§8.2).

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
  second, over the whole drop (8 a second), none within `SNOW_INSET` 40 µm of the
  rim -- the prototype's number (`_uniform_in_drop(ocean_radius - 40.0)`,
  `food.gd:5442`), never measured on its own.
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

**Under one metabolism most flocs are remains.** Over thirty minutes of a drop at
a newborn's composition the snow kept 45 to 63 flakes and the dead left 1,085 to
1,122; at a sighted player's, 46 to 67 against about 2,270 (§5.9). A drop holds
36 to 46 flocs at a newborn's composition and 53 to 77 at a sighted player's,
and a new drop a median of 34 at the end of the forage bot's games -- three
minutes, or its death if that came first -- (23 to 62, 64 games; the first
pass's drop held 19). The snow still does what the owner
asked -- it lands where cells are few, so a grazed-out place fills over a minute
or two -- but the drop's detritus is now mostly the dead, where they died.

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
  swallow, and get the same: food, nothing else. Now that they can starve, it
  keeps them alive: they grazed about 26 flocs a minute at a newborn's
  composition and 67 at a sighted player's (§5.9). A floc near you can take a
  hungry hunter's attention and then its appetite -- the same rule, not a new
  one. A drifter's tier-0 mouth swallows one now and then too (§5.3).

### 7.4 Remains

A body that **dies of hunger or of poison** leaves one floc where it died,
radius half its own, 8 to 18 µm, already settled: it is not falling, it is what
is left. A cell that is swallowed or chewed apart has fed whoever finished it and
leaves nothing. A player that starves or is poisoned leaves one too (§9 makes
that matter: the drop outlives you). Row 7, answered: yes.

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

**A death by hunger, rendered** (pass 2). `starve`: `--seed=2 --scheme=0 P2
--starve-near=3.0` (§15), which empties the hunter nearest the player at 3.0 s
-- a r26 peer 434 µm off at 71° -- with `--mode=1 --freeze-at=2.95` and `3.4`,
and `--mode=0 --freeze-at=3.4`, at 1280x720 and 2400x1080; the 3.4 s frame
three times, 0 pixels apart. Judged: in full vision the peer, mouth bow, eyespot
and cilia, is gone in one frame and a floc sits where it was, half its radius,
brown with the green ring: legible as *something died here and left food*
at both shapes, and abrupt. Point of view shows nothing, which is right: no
sense reports a death, and a nose smells the remains once they are there. The
first frame of a death is the UX designer's to soften -- a body that fades into
its remains over a beat -- and nothing in the rules waits on it.

### 7.7 Measured

**In pass 2**, the full-vision bot ate 56 flocs in 192 games of a new drop and
31 in 128 of an aged one (§8.3), against some 900 meals of the living in every
64; the water's
cells ate them far more often (§7.3). Whether a floc bridges a bad stretch for a
person is the dev app's to judge. The first pass's measurements follow; they ran
before hunger, and their "died" is every game that ended inside three minutes.

The forage bot (§8.3) goes for the living first and for a floc only when nothing
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
with flocs and without only 3 to 8 times in 64 -- so in the first pass two sets
of 64 games of one water differed by up to six in a new drop and fourteen in an
aged one, and every pair above is inside that (pass 2's own noise is larger,
§8.3). The full-vision bot ate a floc once in four to six games: the spawner
refills an emptied place from its horizon inward within a minute (§6.3), so its
screen was almost never without something alive. The nose bot ate one in 32
games: it starves before its first meal in most of them, as it does in the
bubble (energy.md §7.4), and flocs do not change that.

A first version of the bot that went for the nearest edible thing, floc or not,
ate three flocs a game in a fresh drop whose snow was twice as permissive
(`SNOW_SHARE` 1.0) and starved 18 games of 32 where the living-first bot starved
10: flocs may be a trap for a player who does not yet know what they are. From an
emptied start the same bot and snow ate six a game and died in 16 games of 32
against 20 without flocs. Neither is outside the noise either.

So flocs are in pack 1 because the owner asked for them, because they cost
little -- a few dozen bodies that never move and never decide -- and because they
are where the drop's dead go: remains feed the water cells that find them, and
under one metabolism that is most of what flocs do (§7.3). What flocs do for a
person is the dev app's to judge; `SNOW`, `SNOW_SHARE` and a floc's worth are
the three numbers to move (§8.5).

---

## 8. What the player meets

Today the water is built round you: the peer band, the drifter floor, the gape
ceiling, the opening. In a drop the water is its own, and each of those becomes
something else. The owner asked for the rules first and the balance after:
*"Don't go too far with ensuring a player lives as long as today. I'll playtest
it and tell you how we can fix that"* (2026-09-30). So this section measures the
player's survival, says what each of the owner's new calls does to it, and
names the dials (§8.5); it does not tune for a target.

### 8.1 Where a run starts

**Somewhere quiet** (row 9). Of `START_TRIES` 64 points drawn uniformly more than
1,000 µm inside the rim, those with anything edible within 400 µm are thrown away
-- the first meal is found, not handed over -- and the run starts at the one where
**a born cell would feel the least dread**, ties going to the most food within
1,100 µm. The drop is placed so that point is where the cell already is, so the
camera does not move. A return after a death is the same choice, made behind the
black. Today's stronger rule is kept on top: **whatever could swallow a born cell
and is still within `DREAD_RANGE` of the chosen point is moved straight out to
`DREAD_RANGE` + 100 µm**, as today's `_seed` puts it there.

Measured on the pass-2 drop over 64 starts each: in a new drop the start's dread
was 0 at 60 and at most 0.18, with 10–26 edible bodies within 1,100 µm (median
18), and the clearing moved 2 bodies in all; in a drop aged fifteen minutes it
was 0 at 56 and at most 0.11, with 12–28 edible bodies (median 20), and the
clearing moved 46 bodies at 34 starts, never more than three at one. What is
left is cells a little too small to swallow a born cell, which the membrane
already dreads (`THREAT_LOW` 0.85).

### 8.2 What guarantees a first meal, and what replaces the opening

- The first drifter, 1,000 µm along the cell's first motion, as today (§6.4).
- The start itself: nothing edible within 400, the most within 1,100.
- The drifter floor, and the ring that refills the player's surroundings (§6.3).
- The snow, which keeps what falls wherever the player has eaten its
  neighbourhood out, and now the remains of every cell that starves (§7).
- **`FIRST_DELAY`** is kept whole, as row 16 decided: nothing may hunt a
  player for 42 s after it is born, after a division or after a return. It is
  the rule that makes the forage bot all but unhuntable -- it divides every
  30–45 s -- in the bubble as in the drop: without it, hunters ran at the bot
  32 times in 64 games of a new drop, against 3 (§8.3). Nothing may *hunt* it;
  since a mouth now swallows on contact (row 15), something drifting into it
  still can.
- **"Nothing that could eat you starts inside `DREAD_RANGE`"** becomes §8.1.
- **A division regenerates nothing.** The daughter is where her mother was, in
  her mother's water, with a new cell's organs and grace: `food.gd`'s
  `enter_water()`, which is what the shared pond has done since Phase 1. The
  sister is left `SISTER_DISTANCE` 560 µm off, contained if that is past the rim,
  and she is a water cell from then on, under every rule of §5. The authored
  first drifter is not placed for a daughter: her mother's water is round her,
  and the floors hold. (The first pass's prototype re-placed one only when no
  drifter was within her horizon + 300 µm; that happened 0 times in 29
  divisions.)
- **A return after death** is a born cell at a quiet start in the same drop, not
  a fresh water (§9).

### 8.3 Measured, against today and against the first pass

`tools/forage_probe.gd`, energy.md §7.3's method: a born cell steering at the
nearest body its mouth can take **on the screen** (1280x720 for 16:9, 1600x720
for a 20:9 phone), the living first and a floc only when nothing alive is on
the screen; three minutes, a division answered by leaning port. **The bot does
not look at danger**: it swims at food through anything, which is what a
player who reads dread and the red lip does not do. Today's water and the first
pass were measured with that bot, the plain one; pass 2's rows also use one that
passes over a body carrying venom, as a full-vision player who has learnt the
organ's colour does (`--avoid-venom`). Along its path, every second: "food"
counts the edible bodies within 1,400 µm, settled flocs included, and "dread" is
the membrane's own `dread_level`.

**How much the counts can say.** A set of 64 games is 32 seeds on two shapes --
the same drop and the same start, seen through a narrower or a wider screen --
so it is 32 pairs that often end alike, not 64 independent games. And the seeds
themselves matter: three sets of seeds lost 19, 26 and 25 of their 64 games in
today's water, **and 19, 40 and 17 in pass 2's new drop**; two sets lost 26 and
12 in the first pass's aged drop. That is pass 2's own spread, measured for this
revision. The ±6 and ±14 this document quoted before were the first pass's,
which lost games only to hunger; they do not hold here, where a game can also
end in one swallow. So the waters are compared over every seed there is, with
the same bot, and a row that changes one rule is read on the same seeds, game
by game (the next table).

| water | the bot | games | starved | eaten | lost, all told | lost of each 64: seeds 1–32 / 33–64 / 65–96 | food within 1,400 µm | dread, mean |
|---|---|---|---|---|---|---|---|---|
| today's water | plain | 192 | 69 | 1 | **70** (36 %) | 19 / 26 / 25 | 25.4 | 0.214 |
| the first pass's drop, new | plain | 128 | 38 | 0 | **38** (30 %) | 18 / 20 / -- | 26.1 | 0.223 |
| the first pass's drop, aged fifteen minutes | plain | 128 | 37 | 1 | **38** (30 %) | 26 / 12 / -- | 26.2 | 0.216 |
| **pass 2, new** | plain | 192 | 40 | 36 | **76** (40 %) | 19 / 40 / 17 | 28.2 | 0.203 |
| pass 2, new | passes over venom | 128 | 32 | 26 | **58** (45 %) | 18 / 40 / -- | 28.1 | 0.205 |
| **pass 2, aged fifteen minutes** | passes over venom | 128 | 31 | 25 | **56** (44 %) | 31 / 25 / -- | 28.1 | 0.195 |

**Pass 2 loses about as many of the bot's games as today's water, and loses
them differently.** Over 192 games with the bot today's water was measured
with, a new drop lost 76 (40 %) against today's 70 (36 %) -- inside what the
seeds move: pass 2's three sets of seeds lost 19, 40 and 17, today's 19, 26 and
25. The bot starves in 21 % of its games against today's 36 %, because the
drop keeps more food round it (28.2 edible bodies within 1,400 µm against
25.4, the dead's remains among them). It is eaten in 19 % against almost none,
and almost every one of those is a swallow by a big cell it swam into, not one
hunting it: of the 51 deaths by a mouth in the venom-aware games, new and aged,
3 came in a game where anything had run at it at all. That is row 15's contact
rule, met by a bot that swims into mouths. The dread it met on its way was a
little lower than today's (0.203 against 0.214). These runs had the swallow
death for every mouth, which pack 1 does not keep; under today's venom the
plain bot's first 128 games lost 64 against 59, inside chance, and none to
poison (§5.6).

**The aged drop is no harder on average**: the venom-aware bot lost 44 % of an
aged drop's 128 games against 45 % of a new one's -- 31 against 18 on seeds
1–32, and 25 against 40 on seeds 33–64. It holds more threats (§5.9), but what ends
the bot's games is a mouth it swims into, and it divides every 35 s or so under
the grace. The first pass's drop, with age and without hunger, lost 30 %, new or
aged.

**What each new call does to it.** The same 64 games, seeds 1–32, each with one
call answered the other way or with the bot changed. "Games that end
differently" counts the games whose fate -- lost or not -- is not the
recommended drop's. A change that touches only what the bot meets -- a swallow
on contact, the grace after a birth, a careful bot -- changes a handful of games
and leaves the rest as they were, so its difference is the change's own. A
change to what every water cell is -- its speed, its senses, venomous drifters
-- reshapes the whole drop, and a third to a half of the games end differently
for that alone: the same seeds replayed with another random stream, which
changes no rule at all, show how far such a row can move by chance. Every row
ran with the pass-2 prototype's swallow death for every mouth, which pack 1
does not keep (§5.6); the three venom rows are the ones that depend on it.

| the drop, with | games | starved | eaten (of them poisoned) | lost, all told | games that end differently | meals | food within 1,400 µm | dread, mean |
|---|---|---|---|---|---|---|---|---|
| **new, as recommended** | 64 | 11 | 7 | **18** (28 %) | -- | 930 | 29.0 | 0.184 |
| new, a bot that swallows the venomous cells it could see | 64 | 11 | 8 (1) | **19** (30 %) | 1 | 928 | 29.0 | 0.183 |
| new, **row 13 the other way**: drifters as venomous as today, and a bot that cannot tell them | 64 | 7 | 47 (42) | **54** (84 %) | 45 | 570 | 28.5 | 0.151 |
| new, row 13 the other way, and a bot that passes over them | 64 | 11 | 17 (7) | **28** (44 %) | 34 | 936 | 27.5 | 0.200 |
| new, **row 14 the other way**: hunters at today's speeds | 64 | 18 | 9 | **27** (42 %) | 33 | 917 | 27.7 | 0.212 |
| new, **row 15 the other way**: a cell swallows you only from a run at you | 64 | 12 | 2 | **14** (22 %) | 4 | 962 | 29.0 | 0.191 |
| new, **row 16 the other way**: no grace after a birth | 64 | 12 | 16 | **28** (44 %) | 10 | 854 | 29.3 | 0.177 |
| new, hunters noticing you 1,900 µm off whatever they carry (not asked: row 5) | 64 | 18 | 15 | **33** (52 %) | 33 | 834 | 28.2 | 0.228 |
| new, played again with a census every 10 s: the same seeds, another random stream | 64 | 19 | 10 | **29** (45 %) | 27 | 917 | 28.4 | 0.201 |
| new, and every 7 s | 64 | 17 | 12 | **29** (45 %) | 29 | 866 | 28.8 | 0.171 |
| **aged fifteen minutes, as recommended** | 64 | 19 | 12 | **31** (48 %) | -- | 900 | 28.0 | 0.196 |
| aged, row 15 the other way | 64 | 25 | 0 | **25** (39 %) | 6 | 939 | 27.9 | 0.214 |
| aged, row 16 the other way | 64 | 20 | 14 | **34** (53 %) | 5 | 887 | 28.0 | 0.198 |
| aged, a bot that reads the red lip: it leaves food within 200 µm of a mouth that could swallow it, and turns away from one that close | 64 | 22 | 12 | **34** (53 %) | 9 | 889 | 28.0 | 0.202 |

**Two calls move the bot beyond doubt, by the games they touch.** Row 16:
without the grace after a birth, hunters ran at the bot 32 times in the new
drop's 64 games instead of 3, and ten games it had survived were lost -- none
the other way. In the aged drop the grace is worth three games (five end
differently), because what kills there is mostly a mouth the bot swims into.
Row 15: with the owner's earlier rule, 4 games of the new drop and 6 of the
aged are not lost to a swallow; in the aged drop the bot starves instead in six
of the twelve games a swallow would have ended. Both rows are with a thick skin
protecting every cell either way (§5.7): the contact swallow alone.

**Row 13 was not close**, under the rule it was asked for. With drifters as
venomous as today, a swallow killing its eater, and a bot that cannot tell
which, 42 games in 64 ended in poison: about one drifter in nineteen, against
some fourteen meals a game. That bot is point of view, where nothing on the
membrane says a drifter carries venom. A bot that sees the venom and never
steers at it still died of it in 7 games, swallowing the venomous drifters its
mouth closed on while it chased another, because a mouth swallows what it
touches. The swallow death itself cost a full-vision player almost nothing once
drifters carry none -- the bot that swallows every venomous cell it can reach
died of it once in 64 games -- and pack 1 does not have it (row 12). These
numbers are the ceiling on what poisonous drifters could cost once the gene
pass brings them, since a swallow can do no worse than kill; row 13 keeps the
drifters without venom either way.

**Row 14, and how far a hunter notices you, cannot be told from chance by this
bot.** Each reshapes every hunter, so a third to a half of the games end
differently for that alone, and the recommended drop replayed with nothing
changed but the random stream lost 29 and 29 where it had lost 18, with 27 and
29 games ending differently. Today's speeds lost 27, today's reach 33: inside
that. What the two do to the hunters is measured without the bot, in §5.4: at
today's speed or reach about a quarter fewer starve, because they eat a sixth
more of the drifters -- the food a player lives on too. What that does to a
person is the dev app's to show.

**A bot that reads the red lip was swallowed as often**, twelve times in the
aged drop, and lost 34 against 31 (nine games end differently): a born cell
turns half round in five seconds, and a mouth 200 µm away is too close to leave
by turning. Whether a person who sees the danger from the edge of the screen
does better is the first thing the dev app can tell that no bot here could. It
is the owner's own rule for every cell, and the one a playtest should watch
first.

**Point of view**, measured with energy.md §7.4's nose bot (`--sniff`, a tier-1
`chemocyte` from birth, seeds 1–32): it starves in every game, in today's water,
in the first pass's drop and in this one, before any meal in 22 of 32 here
against 22 in today's water. A nose on a thirty-second tank was already too slow
(energy.md §7.4), and nothing in the drop changes that.

**The detail, seeds 1–32.** What the bot's games looked like, the same seeds in
every water:

| water | games | starved | eaten | lost, all told | lost on 16:9 / on 20:9 | meals | a meal every, median (range) | flocs eaten | first meal, median | the bar on average | divisions, median | food within 1,400 µm | dread, mean | dread above 0.5 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| today's water | 64 | 19 | 0 | **19** (30 %) | 10 / 9 | 768 | 12.5 s (7.7–24.4) | 0 | 19.8 s | 0.47 | 3.5 | 25.4 | 0.223 | 17 % |
| the first pass's drop, new | 64 | 18 | 0 | **18** (28 %) | 8 / 10 | 1,003 | 9.9 s (5.8–15.2) | 14 | 10.4 s | 0.36 | 5 | 25.8 | 0.231 | 18 % |
| the first pass's drop, aged fifteen minutes | 64 | 25 | 1 | **26** (41 %) | 14 / 12 | 922 | 9.9 s (7.0–19.0) | 10 | 8.8 s | 0.37 | 4.5 | 25.8 | 0.215 | 17 % |
| **pass 2, new**, the plain bot | 64 | 11 | 8 | **19** (30 %) | 9 / 10 | 928 | 10.1 s (5.2–26.2) | 16 | 9.6 s | 0.38 | 4 | 29.0 | 0.183 | 13 % |
| pass 2, new, the bot that passes over venom | 64 | 11 | 7 | **18** (28 %) | 9 / 9 | 930 | 10.1 s (5.2–26.2) | 16 | 9.6 s | 0.38 | 4 | 29.0 | 0.184 | 13 % |
| **pass 2, aged fifteen minutes**, the bot that passes over venom | 64 | 19 | 12 | **31** (48 %) | 15 / 16 | 900 | 9.3 s (5.5–27.6) | 16 | 11.0 s | 0.37 | 4 | 28.0 | 0.196 | 14 % |

The first pass's rows are its final drop's seeds 1–32. On these seeds pass 2
looked kinder than it is: replayed, the same seeds lost 29 of 64, and over 192
games it loses 40 % against today's 36 % (the first table).

### 8.4 How difficulty moves

- **What is made is tuned to you**, exactly as today's arrivals are: the drifter
  share your senses call for, peers your size ±34 %, no mouth made past 40. It
  shapes what the drop *becomes* over the next minutes, not what is in front of
  you this second -- and as you eat genes that sharpen your senses, the drop
  fills with more hunters: a bot that sharpened its senses through one game in
  an aged drop ended it among 270 hunters, where the drop had made about 45 for
  a cell with none.
- **What lives grows, and now stays big.** Residents eat and grow to 40, and in
  pack 1 nothing takes them down again but hunger (§5.5): about half the
  drop's hunters sit at r40 at a newborn's composition and a third at a sighted
  player's, and at a newborn's composition 61–67 of its 92 hunters could
  swallow a born cell after five minutes, against 22–24 in a new drop.
  That is the owner's "dangerousness improve with time" arriving through growth,
  before genes and learning do; pack 2's division is what thins it.
- **Hunger moves the hunters.** A hungry cell that finds nothing swims to look,
  in a straight line at its own speed, where today's drifted at 9 µm/s: the
  water round a player that stays in one place changes faster than it did.
- **Place.** The drop has thick and thin water and an edge. A player who has
  grazed a place out finds flocs and must move on; a wall at your back is a real
  refuge; the thinnest water is where spawns land, just past your horizon.

### 8.5 The dials

Every number below is a constant in one file, and a content pack moves it. The
direction is what it does to how long a player lives; "measured" is the forage
bot's 64 games in a new drop, seeds 1–32, with that one dial moved (§15.3),
against the recommended drop's 11 starved and 7 eaten, 18 lost. **Read them
against chance**: every dial but the two rules that touch the bot directly
reshapes the whole drop, and the same 64 games replayed with nothing changed
but the random stream lost 29 both times (§8.3). A dial inside that says which way
a playtest should expect it to push, from what it does to the water, and not
how far.

| dial | where, and now | turned which way, and what it does | measured: starved + eaten = lost |
|---|---|---|---|
| a swallow on contact (row 15) | `food.gd`: on | off: nothing swallows you that is not hunting you | off: 12 + 2 = **14**: the 4 games it touches, all saved |
| the grace after a birth (row 16) | `food.gd`: `FIRST_DELAY` 42 s | shorter, or none: hunters may come for a newborn sooner; longer: more time after every birth | none: 12 + 16 = **28**: the 10 games it touches, all lost |
| `DENSITY` | `drop.gd`: 4.9 per million µm² | lower is less food near you and hardly fewer hunters near you, so you starve | 3.9: 25 + 11 = 36, at the edge of chance |
| hunters' senses | `food.gd`: each hunter's own organs | wider -- today's 1,900 µm for every hunter -- lets them find more of the food round you, and you | 1,900 µm: 18 + 15 = 33, inside chance |
| hunters' speed (row 14) | `food.gd`: each hunter's own tail | faster -- today's -- and they take more of the food, and you | today's: 18 + 9 = 27, inside chance |
| what the water makes for your senses (`DRIFTER_SHARE`, `BLIND_DRIFTER_SHARE`, `TIER_WEIGHTS`) | `food.gd`, to move to `drop.gd`: 0.45–0.92 drifters, the tier weights | the gentler end -- as for a cell that senses nothing -- is fewer hunters with poorer mouths: less dread (0.165 against 0.184) | as for a blind cell: 12 + 6 = 18, inside chance |
| `HUNT_AT` | `food.gd`: 0.3 | later (0.6): hunters look for food later, eat fewer drifters and starve more | 0.6: 16 + 8 = 24, inside chance |
| `SNOW` | `drop.gd`: 0.072 | more (×4): more flocs where cells are few, which the hungry hunters eat too | ×4: 14 + 11 = 25, inside chance |
| `DRIFTER_MIN`–`MAX` | `food.gd`: 13–21 µm | bigger (16–24): every drifter a bigger meal, for you and for every hunter | 16–24: 11 + 13 = 24, inside chance |
| `HUNGER_SECONDS` | `metabolism.gd`: 36 s | longer (45): you last longer between meals, and so does every hunter | 45: 12 + 11 = 23, inside chance |
| `SPAWN_TAU` | `drop.gd`: 5 s | shorter: the drop is refilled faster, nearer its 554 | not measured |

**Feeding the drop feeds its hunters.** The four dials that give everyone more
to eat -- a later hunt, more snow, bigger drifters, a longer tank -- each left
the bot fuller (its bar 0.29–0.37 against 0.38) and none of them lost it fewer
games: 23 to 25 against 18, inside chance, with as many starved or more and
more swallowed. Every cell runs the same tank now, so food helps you only
against the hunters it also helps. What moved the bot beyond chance were the two
rules that touch it directly -- a swallow on contact, and the grace after a
birth -- and a playtest's "too hard" can be answered there first, one game at
a time; then the density; then what the hunters are, which only a person
playing can judge.

`HUNGER_SECONDS` and `MEAL` were the owner's own calls for the player
(energy.md §7.6), and they are now the whole drop's: a longer tank keeps hunters
alive as well as you, and fills the drop with bigger, hungrier ones sooner.

---

## 9. Across runs: the drop is kept

### 9.1 The owner's shape (row 8)

The owner, on row 8: *"why not. We could imagine server rooms that always grow
and you can join whenever you want. Solo mode could also save the state and
reuse it. And when hosting on a phone, it serves the personal world of the
host, saving it again when the server is stopped."* So there are two kinds of
drop, and a device keeps one of each kind at most:

- **Your drop: one per device, `user://drop.save`.** The personal world. You
  play solo in it; a death returns you to it at a quiet place (§8.1); the next
  launch loads it. **It lives only while you are in it.** Closed, it is frozen,
  and it wakes as you left it: a phone cannot run a drop in the background, and
  running the missed hours on load would cost the player a wait for nothing
  they could tell -- a drop is at its steady state within about five minutes of
  play (§5.9), so a frozen one is as alive as a caught-up one the moment it
  wakes.
- **Your cell is in it when you come back** (row 17, answered). Leaving the
  app in the middle of a run saves your cell with the drop -- where it is, its
  size, its genes in their order, its generation and its hunger -- and the next
  launch carries on from there, behind the same beat a return from a pond has.
  **One cell for each view** (§9.5): the next launch in the same view.
  Today a run is one session (genes-and-cilia.md §9 item 4: "the arc is one
  session"); with yes, a run can span several, and a death is still the only
  clean restart. The replay is not saved (§11): after a resume it holds only
  what happened since.
- **Hosting on a phone: your drop is the pond.** The friends who arrive swim in
  your personal drop, with everything in it, and it goes on living while you
  host. When hosting stops -- you leave, or the last guest does and you stop
  the session -- it is saved again as your drop, and what your friends ate,
  grew or left behind is in it the next time you play alone.
- **As a guest, your own drop waits.** Joining saves it (a pause point) and puts
  it away, frozen; you swim in your friend's. When you leave, or the link
  drops, you are back in your own drop at a quiet place, behind today's beat
  (`shared-pond-ux.md` §0.5), and it is exactly as you left it. Your cell goes
  both ways -- body, genome, generation and hunger -- as a guest's does today.
- **The home server keeps a room that always lives** (§10.3): the owner's
  "server rooms that always grow". It is nobody's personal drop.

The dev app has its own package id and its own saves (CLAUDE.md), so the
owner's drop on the dev app never touches a player's.

**As built in 1b-2.** A host's drop is kept at every save point while it hosts,
as when it is alone, and **a guest is never in the file**: no body where they
are, their slot empty, and a chase of them kept as a chase of nobody. A guest's
own drop is set aside as the pond swaps in, kept to its file then, and taken up
again at a quiet place behind the beat when it leaves the pond, whichever way
it leaves. A save point reached while a guest -- the app paused or closed --
keeps the drop set aside and the cell marked as elsewhere, so the next launch
opens the player's own drop and puts the cell at a quiet place in it.

### 9.2 What pack 1 lays down now, even before it saves

Every piece of state a save needs has a home in 1a, so 1b adds a file and not a
format:

- **`Body.id`**: a 32-bit id, unique for the life of the drop and never reused.
  Pack 2's lineage is ids (§12).
- **The drop's header**: format, seed, simulated age, next id, the rules hash
  (§9.4), the content version that wrote it, and **whom the water is made
  for** (§10.3): the radius and senses the spawner tunes to when nobody is in
  it.
- **Your cell, when you left mid-run** (row 17): its body, its genome by gene
  name and its order, generation, hunger and grace, and the organs' clocks --
  what a guest's cell already carries across the wire. None after a death.
- **Everything else a body is**: place, heading, radius, wound, meals, **its
  hunger, its grace and the clocks of its mouth, dart and dash**, age, whether
  it is mouthless or a floc, a floc's settle and life, and its genome **by gene
  name**, never by index -- the wire's rule (`shared-pond.md` §2) and for the
  same reason: a retired gene loads as a name the build does not know, kept
  and inert, exactly as `rhabdom` is today. A run in progress (a chase, a
  rest) is not saved: a loaded body starts drifting, as a spawned one does.

**As built in 1b-2: a run in progress is saved after all.** A room saved and
loaded has to go on to the same census as one that never stopped (§14.3 check
12), and a drop whose bodies all start drifting on load does not: with the runs
left out, the census lines 30 s after a load differed. So the file keeps each
body's run -- its state, its target by id (a player's as nobody), its lunge,
orient and search, ten clocks and two points -- and the grid's order, each
gene's shortfall, the drop's counters and whose turn the spawner is on. They
are optional keys, not a new `format`: a 1b-1 file still loads, its bodies
drifting as before. A player's own drop is kept the same way, so it too wakes
mid-chase.

### 9.3 The file

One `store_var` of plain types -- Dictionaries, Arrays and Packed arrays, never
objects -- through `FileAccess.open_compressed`, written to `drop.tmp`, read
back, and renamed over `drop.save`, so a phone killed mid-write keeps the last
good drop and a full disk never passes for a save (`invites-ux.md` §2 found
Godot's `close()` does not report a lost write).

- **Size, measured** (`tools/save_size.gd`, §15.7) on a pass-2 drop aged five
  minutes, 530 bodies and 41 flocs: **107,480 bytes raw, 188 a body; 24,621
  bytes with zstd in memory, and 31,342 on disk** through `open_compressed`,
  whose blocks cost the difference. The tank and the clocks add about twenty
  bytes a body to the first pass's 169; pack 3's behaviour genomes would add a
  few hundred.
- **What it costs, whole**: gathering the bodies 1.6–2.6 ms, writing the file
  1.5–2.3 ms, reading it back and comparing it 2.0–3.1 ms, and the rename
  0.5–0.7 ms -- **5.6 to 8.5 ms here** (three runs, idle), about 35 to 50 ms at
  the assumed factor of six (§4.4): two or three frames. What a phone's flash
  takes to write 31 KB was not measured; the container's disk is not a phone's,
  and its write returns before the data reaches it.
- **When**: the moments the owner accepted in row 8 -- "when you die, pause or
  leave the app": at a death (on the black), when the pause screen opens, when
  the app is backgrounded or closed (`NOTIFICATION_APPLICATION_PAUSED`,
  `NOTIFICATION_WM_CLOSE_REQUEST`), and besides those before joining a friend
  and when hosting stops. **Never in the middle of play**: every one of those
  moments is off the play frame, so the save's two or three frames are never
  seen. Leaving the app covers Android's backgrounding, which comes before the
  system kills an app; a crash costs what was played since the last death or
  pause.
- **The server** saves each room every five minutes and before every stop or
  update restart (§10.3): it has no player's frame to hitch and nobody leaving
  to save on, so a crash costs it at most five minutes of a room's life.

**As built in 1b-1** (`game/normal/drop_save.gd`, 2026-09-30). The file is one
Dictionary: the header -- `format`, `rules`, and the content version and commit
that wrote it -- then `drop`, and `cell`, empty after a death. `drop` holds its
number (the header's seed: drawn once from a generator of its own and kept, for
the log; the drop is still made from the global stream), age and frame, next
id, rim, the spawner's debt, the four clocks of the spawner, the floors and the
shore, whom its water is made for, the free slots, and **every body by its
slot, one Packed column a field**, which is what makes a column of clocks that
are mostly zero cost almost nothing. `cell` is the body, both registers of the
genome by gene name with the queue and the levels, the tank, the generation,
what the run had told it, the water's part of it -- grace, the dart's and the
mouth's clocks, a first drifter not yet met -- and **the two daughters a
division had rolled**, if the app was left while choosing: the division plays
again from its quickening on return and offers the same two, unless the cell ate
and wrote its DNA again in that quickening. The save points are the four above
**and leaving the run** by its own button, which keeps whatever the pause screen
changed; both halves of Android's backgrounding (`FOCUS_OUT`, `PAUSED`) and a
desktop window's close; a point reached twice in one frame keeps once. Every
tool's run keeps nothing (`normal_mode.gd`'s `keep`, emptied by `drive.gd`
unless it is given `--keep=`), so no render opens on a drop another run left.
Measured on a drop aged five minutes as §15.7 ages one (522 living, 47 flocs):
**107,364 bytes raw, 189 a body; 27,320 on disk**; gathering 1.6–3.3 ms and
writing, reading back and renaming 2.8–3.6 ms, three runs -- the prototype's
size, a little faster. Loading takes about 10 ms, once, as the run opens. A
resumed cell comes back **behind the beat of `shared-pond-ux.md` §0.5**, as the
pond's takeover does: the world fades in, the aperture opens over 0.9 s, and
the water runs under it while the cell is held.

### 9.4 Versioning against content packs

A content pack can change any number the drop is made of. So the save carries:

- **`format`**, an integer bumped only when the layout of the file changes. A
  format this build does not know is not read: the drop starts fresh and the old
  file is kept beside it as `drop.save.old`, once.
- **`rules`**, a hash of what the drop's bodies mean -- the gene list, the tier
  tables, `GROWTH_PER_MEAL`, `DIVIDE_RADIUS`, **and the metabolism every body
  runs** (`HUNGER_SECONDS`, `STARVE_GRACE`, `MEAL`, `STROKE_COST`, `TURN_COST`,
  `ABSORB`), written the way `Wire.RULES` is. A different hash does **not**
  discard the drop: every body is re-derived from its genome by name (upkeep,
  gape, speed, reach), a radius over the cap is trimmed to it, bodies past a
  smaller rim are contained, a tank is kept as the share it was, and the
  spawner converges on a changed density by itself. It is logged, so a tester
  can tell a converted drop from a fresh one.
- **The content version** that wrote it, for the log only.

**As built in 1b-1.** `rules` is worked out as the run opens, from the
constants themselves, not pinned beside them: the gene list and `TIER_MAX`,
`UPKEEP_PER_TIER`, **every `*_BY_TIER` table `cell.gd` has, found by name**, the
slot ladder, `GROWTH_PER_MEAL` and `DIVIDE_RADIUS`, the metabolism above, and
`RADIUS` -- so a content pack that moves any of them converts the drop without
anyone remembering to. The names are sorted as Strings: sorted as the
StringNames Godot hands them over as, they came out in memory's order, and the
same build fingerprinted differently from one launch to the next. The
re-derivation runs on every load, since under the same rules it changes
nothing; only the log differs -- `your drop, … as you left it`, or `CONVERTED`,
with what it trimmed and contained. A file that is not a drop this build can
read -- one it cannot decode, or one that does not hold what its format says --
is treated as an unknown format: kept as `.old`, never half-loaded.

### 9.5 A cell per view

The owner, 2026-10-04: *"Split the saved cells between full vision and point of
view. Cells grown in full vision should not be usable in point of view, since it's
not the same difficulty and gameplay."*

**One cell per view, per world.** A world keeps a full-vision cell and a
point-of-view cell, each the one left mid-run in that view, or none. **The water
is shared**: a world is still one drop, and only your cell is split. Opening a
world in a view resumes that view's cell, or brings a new cell into the water at a
quiet place (§8.1), as a death does. The other view's cell is kept aside, out of
the water and untouched, and a death clears only the dying view's cell.

**A cell kept aside keeps its place in the water.** A quiet start moves the whole
drop under the cell that comes in -- in the probe's world, 7,112 units -- so a cell
out of the water has to move with it, or it would come back that far from where it
was left, past the rim as often as not. Every keep moves each cell set aside by
as much as the drop's rim has moved since the run read it (`normal_mode.gd`'s
`_cells_kept_aside`), so every place in a file is in the frame of the drop kept
with it.

**An old cell is full vision's.** Where a cell kept before the split was grown
cannot be told, and the rule is there to protect point of view: an old file's
`cell` loads as full vision's, and point of view starts a new cell in every world.

**In the file** (`drop_save.gd`'s `CELLS`): `cell` stays full vision's, and point
of view's sits beside it in `cells`, a dictionary from a view's name to its cell,
written only while some other view keeps one -- so a world with only a full-vision
cell is laid out exactly as before. **`FORMAT` stays 1**: like `cell.loads`, it is
an optional key, checked as `cell` is when it is there, which a build before it
loads past and never asks for (and drops the next time it writes). The views are
named once, in `run_state.gd`'s `CELL_KEYS`: full vision's is `""`, which is
`cell`, and point of view's `pov`. The file and the worlds' index know a view only
by that name.

**The worlds' index** (`drops.cfg`, settings.md §6.2) keeps a generation for each
view: `generation`, full vision's, as it always was, and `generation_pov` beside
it while a point-of-view cell waits. A keep writes its own view's and leaves the
other's, and a world's line in the menu names each view's cell (settings.md §4.3).

**`V` flips the view in the editor only** (`normal_mode.gd`'s `view_flip`, which is
`OS.has_feature("editor")`): the developer's comparison tool it was written as. In
an exported build -- the dev app's included -- the mode select is the only way to
choose a view, so no cell crosses views. **A run whose view was flipped keeps
nothing from then on**: its cell has been played in both, so it goes into
neither, and what was kept before the flip stands. Every tool that forces a view
-- `tools/drive.gd --mode=`, the probes -- sets `mode` before the run opens, so it
opens on that view's cell.

**Ponds follow the same rule.** A guest's cell comes from its own world's place
for the view it plays in and goes back to it -- `elsewhere` included (§9.1) -- and
a host's own cell likewise. Nothing on the wire changes: `Wire.PROTOCOL` stays 7
and `Wire.RULES` with it, because a host judges the body a guest brings, never
where it was kept.

**What carries over is the water, doing what it was doing.** A hunter mid-chase
of the cell one view left goes on chasing whichever cell is in the water next, as
one chasing a cell that dies goes on after the tap brings a new one: single player
freezes the water on the black and never ends that run. A new cell's quiet start
clears dread's reach round it either way; a resumed cell gets no clearing, as
ever.

---

## 10. The shared pond and the dedicated server

### 10.1 In pack 1a: today's water

**A run that begins with a session up plays today's bubble, unchanged**: the
drop is built only when `NetSession.current` is null in `_ready`. That is
`normal_mode.gd`'s existing test for building `_pond`, so a phone that can meet a
friend keeps the pond, the mirror, the dedicated server and PROTOCOL 4 exactly as
they are -- today's rules included, the committed run and the player-only
armour and venom among them -- and 1a has **no `Wire.PROTOCOL` or `Wire.RULES`
change**. Single player gets the drop and its one body for every cell; the pond
gets both in 1b.

### 10.2 In pack 1b: a phone hosts its own drop

**The host's personal drop is the pond** (§9.1). A guest who arrives is placed in
it as today (`pond.gd`'s `ARRIVAL`, 480 µm from the friend); its own drop is
saved and set aside, and taken up again when it leaves.

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
anchor while it has a body, as today. The rules are the drop's, for both
players: a guest can be swallowed by a cell that is not hunting it (row 15),
exactly as the host can. Venom is today's (row 12): a water cell or a friend
that swallows a venomous player dies of it, and a player swallows a venomous
water cell safely, as in today's pond.

**What a host with a guest costs was not measured**, and it is the drop's worst
case: two anchors, so twice the water stepped every frame when the two are
apart, two scan lists, and the wire, on a phone. It is 1b's gate (§14.2).

**As built in 1b-2.** The other player -- a phone host's one guest, or each of a
server's two -- is a body in the person slots, 68 and 69, whatever lived there
moved to a slot of its own as they arrive. A person is not in the grid, so every
pass that needs them asks for them by name: the LOD's anchors, the prey search,
the contacts (each person keeps a list of the bodies near enough for a mouth
either way), separation and the senses. The rules are the drop's for everyone:
a water mouth swallows a person that fits on contact, hunting or not, and is fed
by them; a person's mouth on a settled floc grazes it -- `GRAZED`, food and no
growth; a person that starves or is poisoned leaves remains. The spawner makes
for each player in turn and keeps whom it made the water for; the drifter floor
is kept round each player, and the snow counts every player in the water.

### 10.3 The home server: a room that always lives

**One room in 1b** (row 18): the server's own drop, `user://rooms/1.save`,
made on the first start and loaded on every start after. It is nobody's
personal drop, and it is joined exactly as the server is today -- the four taps
on the home Wi-Fi, or an invite from outside -- so `invites-ux.md` changes
nothing.

**What "always grow" is in pack 1.** The room lives: its cells hunt, grow to
40, starve and are replaced whether anyone is watching or not, and a friend who
joins at three in the morning finds the water as the night left it. It does not
yet *evolve*: nothing is inherited until pack 2's division, and nothing learns
until pack 3's blocks. The room is built so that both land on it unchanged --
the same room, saved the same way, simply running rules that pass things on.

- **It always lives.** `empty_water()` no longer retires the water when the last
  guest leaves: the room goes on, with no anchor, so every body is on its tick
  (§4.3). **With nobody in it, it costs p50 454–483 µs a frame here, about 3 %
  of one core** at the server's 60 frames a second: five simulated minutes took
  10.3–10.7 s of this container's time, one run at a time on an idle machine
  (§15.1). The server that waits costs 1 % of a core today (`docs/server.md`
  §1). **At half the far rate** (`EMPTY_LOD_EVERY` 16) the room costs half,
  237–264 µs and 5.6–6.4 s, and thirty minutes of it moved the room's ecology
  by about 6 %: 6 % more hunters starved, 4 % fewer drifters eaten, 4 % more
  hunters eaten, and the threats and the hunters at r40 inside the seeds'
  spread (seeds 1–3). At a quarter (32) it moved by a third: 34 % more starved,
  21 % fewer drifters eaten. **Pack 1 keeps the far rate**, `EMPTY_LOD_EVERY` 8,
  so the room is the same drop whether anyone is in it or not; half is the
  lever if the server's core turns out short, and the server's core was not
  measured.
- **Its water is made for whoever was last in it.** The spawner tunes new bodies
  to the players in turn (§10.2); with nobody in, to the last players it was
  made for, kept in the room's header, so an empty room keeps the water its
  visitors had. A room nobody has visited is made for a newborn.
- **A guest arrives** 480 µm from a friend already in the room, as today, or at
  a quiet place (§8.1) if the room is empty.
- **It is saved** every five minutes and before every stop and every update
  restart, which already waits for an empty pond (`docs/server.md` §4). A
  restart costs the room the seconds it takes.
- **What a room costs with people in it** is what a phone host's drop costs: the
  drop and one scan list per player (§4.4).

**As built in 1b-2** (`game/server/server.gd`): `user://rooms/1.save`, written
by `drop_save.gd` as a player's drop is; made and kept at once on a first start
and loaded on every start after -- `[server] room: loaded from … as it was kept`,
or `CONVERTED` -- then kept every 300 s and before every stop, an update's
restart included. Its guests are never in the file. A guest who arrives in an
empty room is put at a quiet place. The rate is the far rate, `LOD_EVERY` 8:
the room is the same drop whether anyone is in it or not. **Measured on the
exported server** in this container, waiting with nobody in it: 4.6–4.9 % of
one core and 129 MB, against 2.2–2.3 % and 124 MB for the build before the
room -- the room's own 2.6 %, about the 3 % above.

**More rooms are later**, and pack 1 leaves them room without designing them: a
room is a `Food` field with an id; the server would hold several and route each
guest to one; HELLO would carry the room wanted, an invite a default room, and
a page after `answered` would let a guest choose. That page is the UX designer's;
it and each room's 3 % of a core are what the owner's "rooms" would add.

### 10.4 The wire: PROTOCOL 5

| change | why |
|---|---|
| **POND entries key on `id u32`, not `slot u8` + `serial u16`**: `id u32 · meals u8 · flags u8 · x f32 · y f32 · heading u8 · radius u16 · wound u8 · speed u8`, 19 B | a drop has more bodies than a byte counts, and an id outlives a slot. The mirror keys bodies, GENOME and the genome book on id |
| **the send set is capped at `SEND_MAX` 60**, nearest first, every hunter of the guest always in | 58 bodies lie within 1,940 µm on average at 4.9 per million, more in a thick patch. Header 8 + 60 water bodies · 19 + the person's 19 and its motion 12 = **1,179 B**, under the 1,392-byte MTU |
| **SETTLE `0x09`** (host → guest, reliable): `id u32 · x f32 · y f32 · radius u8 · settle u8 · life u16`, 16 B after the 6-byte `EVENT_HEADER`, 22 in all | flocs never move, so they are told once, as they enter the guest's reach or settle in it, not twenty times a second |
| **CLEAR `0x0A`** (host → guest, reliable): `id u32`, 4 B after the header, 10 in all | a floc eaten, dissolved or out of reach |
| **ARRIVE carries the drop**: `centre x f32 · y f32 · radius f32`, +12 B: `ARRIVE_SIZE` 15 → 27 | the guest draws the meniscus, contains its own cell, and hears and sees the rim with its own organs |
| **CONTACT gains `GRAZED` = 7**: the level is the nutrition, no gene | the guest's run feeds without growing |

A guest on PROTOCOL 4 is refused at HELLO by name, as 1, 2 and 3 are. A guest's
mirror holds only what it is sent -- at most 60 bodies and the flocs in reach -- so
a guest costs what it costs today; the host carries the drop. Water cells'
hunger never crosses the wire: it is the host's water.

**As built in 1b-2** (`game/net/wire.gd`, `pond.gd`), as the table says. The
send set is every body hunting the guest, then the nearest by the host's own
key, sixty in all; the genome book is keyed on (id, meals); SETTLE goes as a
floc comes into the guest's reach and CLEAR as it leaves it or goes. Today's
water, which only a tool opens now (`normal_mode.gd`'s `drop = 0`), keys its
entries on its serials under the same cap.

### 10.5 What the referee must learn, and `Wire.RULES`

- **`Contact` gains `GRAZED`**, and `food.Contact` is already in the fingerprint
  (`net_probe.gd`'s `_rules_text`), so the hash moves on its own.
- **A graze is not a meal to the referee**: `pond.gd` calls `referee.ate()` only
  for ATE, never for GRAZED, so a guest that ate flocs is still expected at the
  radius its live meals give it. `drop.FLOC_GROWTH` = 0 goes in the fingerprint,
  so a pack that let flocs grow a body changes the protocol.
- **The eating rule a guest is held to changes**: swallowed without a run (row
  15) and armoured prey (row 5); venom stays today's (row 12). The host decides
  both and tells the guest; the referee judges neither, since a guest never
  claims a contact. They go in the fingerprint all the same, as one sample each
  -- a swallow on contact, `_swallow_r` of an armoured water body -- so that two
  builds that disagree on them refuse each other at HELLO rather than one dying
  of a rule the other does not have.
- **`FIRST_DELAY` is already in the fingerprint** (`food.FIRST_DELAY`, the
  grace the referee grants a guest's new body), and row 16 kept it: it does not
  move.
- **The rim**: the host contains the guest's body in its drop as it contains
  everything in its water, and a claim past the rim is held at it -- a clamp, not
  a foul, because an honest guest's own run contains it the same way.
  `drop.contain` goes in the fingerprint by a sample value, as `cell.mended` does.
- **The sister** near the rim is placed where `drop.contain(mother + side · 560)`
  puts her, so `judge_sister` accepts that point ± `SISTER_RING`.

**As built in 1b-2.** `Wire.RULES` moved from `25e18f09…` to `46913eab…`. The
fingerprint gained `drop.FLOC_GROWTH`, a sample of the rim's `contain`, and one
sample each of `food.swallows_player` and `food.armoured_size` -- static
functions the field itself calls, so each sample is the rule and not a copy of
it. The referee holds a claim past the rim at it with no foul, and takes a
sister where the rim held her -- on the circle a daughter's centre keeps to, no
further than the ring from her mother -- with none.

So 1b is **`Wire.PROTOCOL` 5 and a new `Wire.RULES` in the same commit**, and
`net_probe`'s `referee` section fails until both are done, as CLAUDE.md requires.
Nothing about the water cells' metabolism, behaviour or making is judged -- they
are the host's water, not a guest's word -- so none of it is in the fingerprint.

---

## 11. The replay

The recorder kept sixty seconds of the run as slots, 34 bodies a frame, and the
replay wrote them back onto the run's own `Food` (`replay.md` §3). A drop has
554 bodies and outlives the run, so both halves changed in 1a:

- **48 recorder slots**, holding the 48 living bodies nearest the player each
  frame, within `LOD_NEAR`, past which no sense reaches (`drop_probe`'s check 7).
  A body keeps its slot while it stays in the set; a newcomer takes the lowest
  free one, newcomers in the field's own order; a freed slot writes radius 0,
  which both views draw as nothing -- the mirror's convention. 48 covers about
  1,770 µm at the drop's density: the frame, dread, scent and the beam. `STRIDE`
  grows by 84 floats, 385 to 469 -- the beam's twenty-four rays had already taken
  it past `replay.md` §3.1's 322 -- and the ring from 5.5 MB to 6.8 MB. Genome
  deltas key on the body: one is written when a body takes a slot and when it
  eats, by its serial, which is new for every body the water makes as its id is,
  and which today's water has too; the row carries the id.
- **Flocs as timestamped deltas**, SETTLE and CLEAR with place and radius, like
  the wire's: they never move, and their fade is a function of time --
  `food.gd`'s `floc_settle_after()`, the fade `_age_floc` steps, in closed form.
  A floc is told as it lands or comes within the same reach, and cleared as it
  is eaten, dissolves or is left behind. A cell that starves or is poisoned in
  view is its slot writing radius 0 and a SETTLE where it was, already settled:
  the replay shows the death as it happened with nothing new recorded. A water
  cell's hunger is not drawn in either view, so it is not recorded. The fade runs
  on the recording's clock, which goes on through a division while the water
  stops, so a floc settling at that moment settles a little early in the replay.
- **The drop's centre and radius** as one delta at the start of the window.
- **`AT_HUNTER` records a recorder slot**, not a field index.
- **And the killer's slot**, `AT_KILLER`: the slot of the body that swallowed or
  chewed you, or of the venomous one you bit, and −1 on every frame it does not
  name. `hunter()` answers only for a stalker, and from pack 1 most deaths by
  mouth are by a cell that was not hunting you (§8.3), so without it the truth
  pane would draw no predator for them -- the defect `replay.md` §4.8.8 fixed for
  stalkers. Stepped at playback like `AT_HUNTER`; `vision.gd` draws the predator
  rings for it when `hunter()` has none. `STRIDE` 469 → 470, 14 KB more ring.
  **Built otherwise than this section first said**, which was the frame of the
  death alone: that frame is never on screen and draws nothing if it is. The ring
  is sealed before the death is captured, and the replay loops as its cursor
  reaches the last frame, so a stepped float on the last frame is never shown;
  and a predator ring is drawn only while the cell is within `RING_WINDOW` (130)
  of crossing it, while at contact the killer's centre is some 60 away, so the
  nearest of its rings, at 220, is 160 off. So the seal writes the killer's slot
  over every frame that body held its slot, and its rings are drawn as the cell
  crossed them.
  The field says which body it was in `died_to`, beside `died_of`, in the drop
  only.
- **The ring is not saved.** It is the last minute of this session: after a
  resume (row 17) it holds only what happened since.
- **The replay binds a private `Food`** -- 48 slots, the flocs, the rim -- and
  never writes to the run's. Scribbling on the real field was free when a run
  kept nothing; it would now overwrite the drop the player returns to. This is
  the private-node binding `shared-pond.md`'s Phase 3 planned for the pond, done
  in 1a for single player; 1a-2's stash of what a replay wrote over went with it.
  **Phase 3 did the rest in a session** (`shared-pond.md` §5): the cell, the
  genome and the grit are the replay's own there too, since the wire reads the
  run's on the black, and the friend is a body in the replay's field, in its
  person slot and out of its grid.
- **Today's water is recorded the same way**, and comes out as it did: a run with
  a session plays it in 1a, its 34 bodies are always the nearest, and taking
  slots in the field's own order puts each in the slot of its own index, with the
  floats the old recorder wrote; slots 34 to 47 stay empty. Its field never names
  a killer, so its replay is today's. `drop_probe` holds both to the float.
- **What it costs**: one `capture()` averaged 167 to 186 µs over 25 s of a drop
  here, a cell swimming in circles, seeds 7 and 12345, against 92 to 103 µs for
  1a-2's recorder in the same half hour on an idle machine -- about 75 µs more a
  frame, some 5 % of the drop's own. Its longest capture moved from run to run,
  1.3 to 2.9 ms against 1.1 to 1.4, at no frame in particular. Most of it is
  finding the nearest: one grid question out to `LOD_NEAR` and one sort a frame.
  If the phone gate (§14.2) needs it back, the lever is to choose the nearest
  every few frames and write the slots every frame; a newcomer is on the edge of
  the set, far off any pane, so a few frames late is nothing either pane shows.

---

## 12. Hooks for packs 2 to 4

Not designed here; named so that pack 1 leaves room for them.

| later | the hook pack 1 leaves |
|---|---|
| **a body carries a lineage** (pack 2) | `Body.id`, and room in the save for `parent` and `generation`; 0 in pack 1 |
| **cells are born from division** (pack 2) | `_spawn()` is the one door every new body comes through -- spawner, sister, first drifter -- so a birth is a spawn with a parent; the spawner fills only up to `SPAWN_SHARE` of the target and backs off by construction (§6.5). **Division is waiting for it at r40**: at a newborn's composition about half the drop's hunters sit there, eating to live and unable to grow, and half of those that starve starve there (§5.5); a daughter is born fed, as a spawned body is (§5.8) |
| **a body carries a behaviour genome** (pack 3) | `Body.brain`, null in pack 1 (the hand-written state machine); saved by the same rule as genes, by name and version. Its inputs are what pack 1 already gives the hand-written one: its own hunger, what its own senses reach, its own speed and turn (§5.4, §5.7) |
| **the same blocks drive every body** (pack 3) | decisions are made on the LOD tick, 7.5 a second, near and far alike (§4.3), from the per-body senses the grid answers; `_decide(b)` wraps today's `_look_for_prey` entry so a brain can take its place. What pack 1 keeps as behaviour -- `FIRST_DELAY`, which row 16 kept, the rests after a meal and a miss, resting while fed -- is the blocks' to keep or drop (§5.7) |
| **a hungry cell dies of it** | **built in pack 1** (row 4): `Body.hunger`, the first pass's reserved field, is live |
| **the same blocks drive the player** (pack 4) | `cell.gd`'s steering is written from one place a frame, `_read_steer()`; a brain writes `steer` there instead, on the same tick. A player's blocks could let its cell rest, which its flagellum does not today (§5.2) |
| **an evolving server room** | **built in 1b**: the room lives on while it is empty (§10.3) |
| **several rooms on one server** | §10.3: a room is a `Food` field with an id; HELLO carries the room wanted; a page after `answered` chooses |
| **venomous and poisonous** (the gene pass, row 12) | `veneneux`'s two effects each stay in one place -- the bite-back where a bite lands (`_chew`, `_bitten_by`, `_bite_from`), the swallow death in the mouth rule -- so the gene pass can replace them with stacks without touching the rest. A stack that wears off is an amount a body carries, stepped with it like its hunger, so a far body on the tick takes it the same way (§4.3) |
| **a water cell's hunger, seen** | nothing draws it in pack 1; `Body.hunger` is there for full vision to read, and whether it shows a hungry hunter, or a death by hunger more gently than in one frame (§7.6), is the UX designer's |

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
| `game/normal/drop.gd` **new** | **this water, and its seeder**: every number in §2–§7 by name -- `RADIUS`, `SHALLOWS`, `DENSITY`, `SPAWN_*`, `HIDE_MARGIN`, `GENE_FLOOR`, `SNOW*`, `FLOC_*`, `LOD_*`, `EDGE_*`, `SHORE_*`, `START_TRIES`, `EMPTY_LOD_EVERY` -- the words drop, meniscus, floc, and the decisions only this water makes: what is short, whose turn it is, where a run starts, **what a new body is made of** (§5.8: the body plan, the given sense, no venom on a drifter). It calls the four mechanics for the arithmetic and `food.gd`'s `_seed_drifter`, `_seed_peer` and `_draw_genome` for the cells | how the grid, the basin or the arithmetic work |
| `game/normal/metabolism.gd` | **the arithmetic of a tank**, as static functions both the player's node and the water call: the rate at rest (upkeep less an income, over the reserve), what an effort costs, what a meal is worth; `ABSORB` beside `HUNGER_SECONDS` | cells, genes, the water: light and absorption are the callers' names for the income |
| `game/normal/food.gd` | cells, genes, mouths and senses, as today, reading the drop's numbers; **one body for every cell** (§5.2–§5.7) and the hand-written behaviour (§5.4), whose constants -- `HUNT_AT`, `REST_MEAL`, `REST_MISS`, `ORIENT_SECONDS` -- sit with today's `CALM_*` and `COMMIT_RANGE` until pack 3 replaces them | the grid's or the basin's insides |

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
| `game/normal/drop.gd` | new: the environment, and what the water makes (§5.8, §13) |
| `game/normal/metabolism.gd` | the tank's arithmetic as static functions the node and the water share: `rest_rate(upkeep, income, reserve)`, with light and absorption summed into `income` by the caller; `effort_cost(seconds, burn, reserve)`; `meal(nutrition)`; and `ABSORB` 1.0. The node's `_process`, `spend` and `feed` call them, so the player's numbers do not move (§14.4) |
| `game/normal/cell.gd` | `swallow_radius_of(radius, pellicle_tier)` beside `swallow_radius()`, and `stroke_cost(speed)` -- `speed × DRAG / SPREAD_LOSS × STROKE_COST` -- beside `STROKE_COST`, so the water prices a steady swim from the player's own table |
| `game/normal/food.gd` | `Body` gains `id`, `hunger`, `starve`, `effort`, `age`, `lag`/`last_t`, `near_frame`, `inert`, `settle`, `life`, `dart_clock`, `dash_v`, `dash_clock`, `orienting`, `searching`, and read-once `notice`, `see_big`, `armour`, `tox`, `dart_bearing`, `reserve`, `sun`, `burn`, `upkeep`; reserved `brain`, `parent`. The drop's path beside the bubble's, chosen once per run: `setup_drop()`, `_process` at three rates by distance (§4.3), every all-pairs pass through the grid and the near-first prey search (§4.2), containment and the shore turn, the spawner, floors and gene floor, the snow and flocs, flocs in contacts and in each sense (§7.5), the rim in the ping, the shadow, the beam and touch (§3.2), the quiet start and its clearing, `enter_water()` on division and return, `put_sister` contained. **One body** (§5): the metabolism per step -- skipped for a tank that cannot move, which changes no number (§4.4) -- and its four deaths with remains; `_swim` paying for speed and turns; a hunter's senses, tail, dash, dart and orienting turn; the one mouth rule in `_mouth_on` and `_contacts_with` -- on contact (row 15) and armoured (row 5), with `veneneux`'s two effects left exactly as they are (row 12); **a water cell that swallows or chews through a player is fed by it** and rests `REST_MEAL` (§5.6), where today it breaks off unfed (`:1868`, `:2078`); the behaviour of §5.4, with no flight after any miss. **The edible cue follows the mouth**: the taste weight in `_step_sense` (`:2799`) reads the prey's swallow radius, `swallow_radius_of(radius, pellicle)`, not its bare radius, now that armour protects every body -- or the scent would call a cell edible that the mouth cannot take. Signals `shored(bearing, strength, at)` and `grazed(nutrition, at)`; `bodies_near(point, reach)` for the view. **All of it keyed on the drop**: the bubble a session plays in 1a keeps today's rules to the byte (§14.4) |
| `game/normal/normal_mode.gd` | the drop when `_net` is null in `_ready`; `shored` → `_bus.hit`; `grazed` → feed without growth, the flood with no gene, `mark_meal`; `_be_born` and `_return` enter the drop instead of `setup()`; a starved or poisoned player leaves remains; a player without a `cytostome` absorbs (`ABSORB` into the metabolism's income, as `plastid` is) |
| `game/normal/motes.gd` | grit inside the rim, the first mote included; seeded after the drop |
| `game/vision/water.gdshader` | `drop_on`, `drop_center`, `drop_radius`, `drop_band`: film, meniscus line, dry glass (§3.3); the line's square as `k * k`, never `pow` |
| `game/vision/vision.gd` | the four uniforms; `_draw_floc` and the ring bloom; `_draw_cells` asks `bodies_near()` instead of rebuilding five arrays over every body; the scent bloom's weight (`:1362`) on the same swallow radius as the taste |
| `game/replay/recorder.gd`, `replay.gd`, `panes.gd` | 48 nearest in stable slots, floc and rim deltas, `AT_HUNTER` as a slot, `AT_KILLER`, a private `Food` (§11) |
| `game/dev/frame_readout.gd` **new**, and a line in `normal_mode.gd` | **1a-1**: the dev app's frame-time readout (§14.2), shown only when the launcher's `BuildInfo.release_branch` is not empty -- the dev app, never a player's: the frame's p50, p95 and share dropped (an interval over 1.5 periods of the display's refresh rate or of 60 Hz, whichever is lower: what the phone gate reads) and the water's own `_process` p50 over the last ten seconds, and the bodies stepped a frame |
| `tools/drive.gd` | `--drop=0\|1`, `--start=quiet\|centre\|edge`, `--edge-gap=`, `--flocs-near=`, `--desert=`, `--age=`, `--hunter-genome=`, §4.4's switches, and one switch per body rule so the owner's other answers can be played (`--absorb=`, `--drifter-venom=`, `--own-speed=`, `--notice=`, `--contact-swallow=`, `--armour-swallow=`, `--first-delay=`, `--flight=`), set on the run before it enters the tree, as `--mode` is |
| `tools/forage_probe.gd` | grazes, the living-first bot, `--avoid-venom`, `--cautious`, `[forage-near]`, `[forage-compete]`, the cause of death, meal times (§15) |
| `tools/eco_probe.gd` | new: the drop alone, census and cost, `--empty-room`, `--death-log` (§15) |
| `tools/chase_probe.gd` | new: the chase contract at a hunter's own speed (§5.7, §15.6) |
| `tools/drop_probe.gd`, `.tscn` | new, in CI (§14.3) |
| **1b** `game/normal/drop_save.gd` | new: §9.2–§9.4, for a personal drop and a room alike |
| **1b** `game/net/wire.gd`, `pond.gd`, `referee.gd`, `net_session.gd` | PROTOCOL 5 and `RULES` (§10.4–§10.5); the host's drop is the pond; a guest's own drop set aside and taken up again (§9.1) |
| **1b** `game/server/server.gd`, `food.gd`'s `open_dedicated`/`empty_water` | the room: loaded or made, living on with nobody in it, saved every five minutes and before every stop (§10.3) |
| **1b** `tools/net_probe.gd` | `pond-field` and `pond` on the drop; the new events; `referee` on grazes, the rim, the contained sister and the new eating samples |
| `.github/workflows/ci.yml` | the "Check the drop" step (§14.3), beside the levels probe's |
| **1b** `docs/server.md` | §1's "1% of one core while it waits" becomes about 3 %: the room lives while the server waits (§10.3) |

**Nothing** in `addons/launcher/`, `ci/` or `project.godot`.

### 14.2 Phases and releases

Each phase is one pull request into `dev`, played on the dev app before the next.

| phase | contents | the owner can try |
|---|---|---|
| **1a-1** | the four mechanics files, `drop.gd`, and the metabolism's static functions, with `drop_probe`'s grid, basin, replenish, snowfall and metabolism checks; **the dev app's frame readout**; nothing else uses them yet, and the player's own node gives the same numbers | nothing new but the readout: today's water, whose numbers on the owner's phone are the baseline the gate reads against (§14.4) |
| **1a-2** | the drop in single player as it was measured: world, grid, LOD, containment, the rim in every sense and in full vision, the spawner and floors, the quiet start, divisions and returns in the drop, motes; **one body for every cell** with its behaviour (§5); and the flocs, the snow and the remains with it, because every ecology number in this document was measured with them | the drop, its edge, water that starves and the dead feeding it; **the phone gate** |
| **1a-3** | the replay on the drop | watching a death in the drop |
| **release 1a** | | players get the drop alone; multiplayer is today's |
| **1b-1** | your drop kept across launches, and your cell in it (row 17); a death already keeps the drop from 1a-2 | closing the app and coming back to the same cell |
| **1b-2** | PROTOCOL 5: the pond on the host's own drop, a guest's drop waiting, the server's room living on | two phones in one drop, and the server's room; **the host's gate** |
| **release 1b** | | everyone gets the drop |

**The phone gate, before release 1a.** On 1a-2 the owner plays ten minutes on
the dev app with the readout on: the first five in a new drop, the rest in the
same drop, which is at its steady state by then (§5.9). **It passes if the
frame holds the display's own rate: at most 5 % of frames dropped over the ten
minutes, a dropped frame being one whose interval is more than 1.5 times the
period of the display's refresh rate or of 60 Hz, whichever is lower (the
readout's `dropped`; its p95 is shown beside it, for information).**
The readout shows the water's own cost beside the frame, against the baseline
1a-1 read of today's water, so a failure says whether the water is the cause.
If it fails, the §4.4 levers in this order, each a content update to the dev app
and the same ten minutes again:

1. a floc asks for a drifter's mouth on its tick (about 2 % of the drop's frame
   here);
2. the tick from 1,100 µm out (1.7 times today's field against 1.9 in the first
   pass), after §4.3's statistics again;
3. per-sense scan lists, and separation in the band at the tick.

If all three leave it failing, the drop comes back to this document before 1a
ships: the density (§6.1) and the reach of the near water are the next levers,
and both change what the player meets. The owner's phone is one phone; a slower
one is the first thing a player's report would show.

**Measured on 2026-10-01: it passes.** In play on the dev app, the owner's phone
read `dropped` 0 % of 60 Hz, now and then 0.1 %, against the 5 % the gate
allows. None of the three levers was needed.

**The host's gate, before release 1b**: the same ten minutes on a phone that
hosts, with a guest in the drop, apart and together -- the drop's worst case,
which was not measured here (§4.4).

**Two releases, not one** (row 10): 1a changes nothing multiplayer, so a phone on
1a still meets a phone or a server on 1a in today's pond, and a player on 1a is
not refused by anyone else on 1a. 1b is the protocol change, and it goes out when
the pond on the drop has been played by two phones on the dev app.

**Overtaken on 2026-10-01: one release.** 1b-1 and 1b-2 landed on `dev` before
release 1a went out, and the release skill ships everything on `dev` at once.
The owner: *"Don't bother for the release. I'll run the release skill when
everything is ready."* So pack 1 reaches players in one release, when the owner
runs it, and the network change goes out with it.

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
5. **Growth**: after five minutes at `--sensed=1`, no water body over
   `DIVIDE_RADIUS`, and no body *made* with a gape of `ARRIVAL_GAPE_MAX` or more
   (a grown one may have it: row 5).
6. **The floors**: every gene in `DRIFTER_GENES` carried by at least
   `GENE_FLOOR` living bodies at every count; a living drifter within the floor
   reach of a still player at every check; no drifter carries `veneneux`.
7. **The LOD reaches past the senses**: `LOD_NEAR ≥ max(PING_RANGE_BY_TIER) +`
   the widest body the cap allows `+` slack, and `≥` every other reach in the
   tables (scent, dread, the beam at its longest level, touch); `LOD_FULL ≥` the
   view's reach on the widest screen plus the camera's lead and the widest body;
   `LOD_EVERY` even. A future sense that reaches further fails CI instead of being
   slowed where it can be sensed.
8. **Determinism**: one seed twice, the same census line; and the same seed with
   the near-first prey search on and off, the same census line.
9. **Flocs**: none edible before it has settled; a graze changes hunger and not
   the radius or the genome; remains where a cell died of hunger or of poison,
   none where one was swallowed or chewed.
10. **One tank**: a water body and the player's metabolism node with the same
    genome, fed the same efforts over the same 60 s, end at the same hunger to
    1e-6; a mouthless body at rest does not starve; a body empty for
    `STARVE_GRACE` dies of hunger.
11. **One body**: over five minutes, every retired living body has one of the
    four causes and nothing else; a mouth swallows a body that fits on contact
    whether it is hunting or not (row 15); `pellicle` makes a body too big for a
    mouth it would otherwise fit; venom as today -- a mouth that swallows a
    venomous player dies of it, a player that swallows a venomous water cell
    does not (row 12); a water cell that swallows a player without venom is fed
    by it; a hunter never cruises faster than `swim_speed_of` its own organs nor
    lunges without a `myoneme`; no hunter starts a run at a body beyond its own
    senses' reach, and none flees after a miss; a water cell's dart breaks a run
    at it; the taste field and the bloom weigh a body by its swallow radius.
12. **1b, the save**: save, load, the same bodies to the bit, hunger and clocks
    included; an unknown gene survives; an unknown `format` starts fresh and
    keeps the old file; a smaller `RADIUS` contains; a changed `rules`
    re-derives and logs; a room saved and loaded goes on to the same census as
    one that never stopped. **1b-1 built all but the room's**, which is 1b-2's
    with the room: the bodies to the bit through the file's whole path, an
    unknown gene among them; a real run left by the app pausing and opened again
    on the same drop to the bit and the same cell -- and the same two daughters;
    an unknown format; and a changed `rules`, with a body past the rim contained
    and one past the cap trimmed, and the fingerprint's tables in name order.
    **1b-2 built the room's**: a room made alone and 40 s on, kept through the
    file's whole path and loaded, and both 30 s more on one stream -- the same
    census line.
13. **The replay** (§11, 1a-3): after every frame of a cell crossing the drop,
    the slots hold exactly the living bodies nearest it, none changing slot while
    it stays among them; today's water in the slots of its own indices with the
    old recorder's floats; a flake told once as it lands and once as it is eaten,
    settling by time as the field steps it, and a cell starving in view emptying
    its slot and leaving one SETTLE; a mouth that was not hunting named as the
    killer on every frame since it took its slot and on none before, and drawn
    round when nothing hunts; and a replay watched and closed through the run's
    own button leaving every body in the drop as it was, to the bit.

The existing steps keep passing: the scene boots, the input path (`drive.gd`,
now in the drop), the Back gesture, the levels probe (whose metabolism checks now
run through the shared static functions), the LAN session. In 1b `net_probe`
gains the pond-on-the-drop checks and its `referee` section proves `PROTOCOL`
and `RULES` moved together.

### 14.4 The identity gate, where it still applies

The drop changes single player by design, so `shared-pond.md` §5's fingerprints
are not the drop's gate. They still hold everything else:

- **1a-1** must be byte-identical to `dev` everywhere a player can see: the four
  files are unused, the readout draws nothing where the release branch is
  empty -- which is how CI and the fingerprints run -- and the player's
  metabolism, now computed through the shared static functions, gives the same
  numbers. That was checked bit for bit against `dev` once, by the build and
  again by its review, over 1.2 million calls; the fingerprints cannot show it,
  because no fingerprint run eats and a hunger pinned at full hides a reordered
  sum. What CI holds from there is the node against the static functions to
  1e-6 (`drop_probe`) and the thirty-second death within two frames (the levels
  probe).
- **The bubble**, which every run with a session still plays in 1a: the six
  fingerprints with `--drop=0`, `field_diff` against `dev`'s `food.gd`, and the
  render and sensation diffs, all identical. None of §5's rules may reach it.
- **The drop's own gate** is statistical and in §15: the census and the forage
  numbers against this document's, and `--field-cost` against §4.4's table and,
  before 1a ships, the phone gate (§14.2).

### 14.5 What it replaces

| today (`food.gd` unless named) | in the drop |
|---|---|
| `COUNT` 34 kept within `CULL` 1,700 of you, `_step_recycle` reseeding past it (`:2559`) | the drop's whole population, always, the far part stepped at a lower rate (§4) |
| `_consume` reseeding an eaten body in place (`:1998`) | the body is retired; the spawner pays the shortfall back somewhere thin (§6) |
| `_seed`'s arrival ring, 920–1,350 µm round you (`:4146`) | the thinnest of twelve points, past every player's hide reach (§6.3) |
| `setup()` at every division, which throws the water away (`normal_mode.gd:1637`) | `enter_water()`: the daughter stays in her mother's water (§8) |
| the opening: the first drifter, and nothing that could eat you within `DREAD_RANGE` | the quiet start, then the same clearing; the first drifter kept (§8.1) |
| water cells that never starve; growth without a bound in `_devour` (`:2541`) | one metabolism for every body, growth stopping at 40, four ways to die (§5) |
| `NOTICE_RANGE`, `CRUISE_OVER_PREY`, `LUNGE_OVER_PREY`, the nose snapped round | a body's own senses, tail, dash and turn (§5.7) |
| the flight of up to 20 s and the 30–55 s calm after any failed run | 5 s where it is after any miss (§5.4) |
| the committed run, and armour against a swallow for players only | one mouth rule for every body (rows 15 and 5); venom as today until the gene pass (row 12; §5.6, §5.7) |
| a player's killer breaking off unfed (`:1868`, `:2078`) | fed as by any meal (§5.6) |
| the edible cue on the bare radius (`:2799`, `vision.gd:1362`) | on the swallow radius (§14.1) |
| peers of a mouth and random others, drifters of any gene | peers made to live, drifters without venom (§5.8) |
| all-pairs prey search, contacts and separation | the grid (§4.2) |
| **1b**: `_step_pond`'s cull, quota, excess and floor (`:2577`) | one population; every player an anchor for the LOD, the hide reach and the ring (§10.2) |
| **1b**: `empty_water()` retiring the server's water | a room that lives on (§10.3) |
| the recorder's 34 field slots, replayed onto the run's own `Food` | the 48 nearest in stable slots, replayed onto a private `Food` (§11) |

The bubble stays in the code through 1a, because a run with a session still
plays it, and through 1b as `--drop=0`, the reference the probes compare the
drop against. Deleting it is a chore for the release after, once nothing
compares against it.

---

## 15. To measure again

Every probe is in `tools/`, excluded from every export. Headless, `--fixed-fps
60`, with the prototype's flags after the `--`; in the build they are
`drive.gd`'s (§14.1). **Pass 2's rules are one switch in the prototype**,
`--same-rules=1`, which sets everything in §5 -- the metabolism for every body
(`--water-hunger=1 --pay-effort=1 --absorb=1.0`), the behaviour
(`--hunt-hunger=0.3 --rest-meal=5 --rest-miss=5 --search=1 --flight=none`), the
body rules (`--notice=senses --own-speed=1 --contact-swallow=1
--armour-swallow=1 --water-darts=1 --drifter-mouths=1`), what the water makes
(`--viable=1 --drifter-venom=0 --spawn-hunger=0`), no age and no ceiling. It
goes first; a flag after it overrides one piece, which is how every "the other
way" row in §5.4 and §8 was run. **Every run in §4, §5 and §8 also had
`--venom-swallow=1`**, the swallow death for every mouth, which pack 1 does not
keep (row 12, §5.6): the prototype no longer sets it, and a run made to match
those numbers adds it, as `P2` below does. `--first-delay=` moves `FIRST_DELAY`
(row 16). **The same command three times prints the same lines to the byte**,
and so does a later build of the prototype on the same command: five runs of
seed 5 on three builds, 0 bytes apart, and after the review two forage games
made on earlier builds, again byte for byte.

**The miss rule changed after most runs.** Until the review, `--same-rules=1`
set `--flight=player`: a run at a player ended in the flight and 5 s of calm.
It now sets `--flight=none`, §5.4's rule. A game is touched only if a hunter
ran at the bot; the 28 such games across every batch of §8 were run again
under the new rule, and the rest are the same games to the byte.

```
P2 = --ocean --same-rules=1 --venom-swallow=1 --density=4.9e-6 --spawn-tau=5 --clear=1 --lod-full=1100 --prey-rings=1
```

### 15.1 Cost

```
godot --headless --path . --fixed-fps 60 res://tools/drive.tscn -- --seed=S \
    --mode=0 --scheme=0 --radius=30 \
    --genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1,ampulla:1 \
    --field-cost=3600 P2 --ocean-r=6000 --ocean-log=10
```

for S = 7, 12345, 2026, twice, today's field (the same line without the drop's
flags) and the first pass's drop (`--ocean --density=4.9e-6 --spawn-tau=5
--water-hunger=0 --lifespan=180 --grow-gape-max=40 --clear=1 --lod-full=1100
--prey-rings=1`) between them; add `--age=900` for the aged one. `--ocean-log=10`
prints the phases. The cell dies in most runs, so fewer than 3,600 frames are
timed; the line says how many.

**One run at a time, on an idle machine, and checked.** Before each run the
script waited until no Godot process was running whose working directory was
not its own and the one-minute load average was under 1.0, for up to twenty
minutes, and logged which it got; after each, it logged whether anything else
had started. Other builds and tests shared this container that day, so a
number without that check is not a number. Every cost in §4.4 and §10.3 was
taken in an idle window; the thirty-minute ecology runs, which count and do not
time, ran three at a time.

**Where a frame goes** (§4.4's second table): the same line on copies of both
prototypes with `Time.get_ticks_usec()` round the prey search, a floc's step,
the tank and each behaviour state, summed like the phases and printed after
them -- an instrument for the prototype, not a flag for the build. One run a
seed. `--skip-still=1` is §4.4's tank skip: the eco probe's census with and
without it (seeds 1 and 2, `--until=300 --every=60`), and the cost line twice on
each seed with and without it, interleaved.

**The server's empty room** (§10.3):

```
godot --headless --path . --fixed-fps 60 -s res://tools/eco_probe.gd -- \
    --ocean --same-rules=1 --venom-swallow=1 --until=300 --every=300 --sensed=0.2 --spawn-tau=5 \
    --density=4.9e-6 --lod-full=1100 --prey-rings=1 --empty-room --lod-every=8|16
```

seeds 1–3, one at a time under the same check, the wall time taken round each
run; the same with `--until=1800 --every=300` and `--lod-every=8|16|32` is the
room's ecology at each tick.

### 15.2 The drop alone

```
godot --headless --path . --fixed-fps 60 -s res://tools/eco_probe.gd -- \
    --ocean --same-rules=1 --venom-swallow=1 --seed=1 --until=1800 --every=300 --sensed=0.2 \
    --spawn-tau=5 --density=4.9e-6 --lod-full=1100 --prey-rings=1
```

prints a census every 300 s (living, drifters, hunters, flocs, threats to r26,
r34 and r40, hunters at r40, mean hunter radius and hunger, genes carried,
spawns and every cause of death, runs begun and at the player, darts, dashes,
mean dread at 64 random points) and the frame's cost by phase; `[eco] stats`
at the end holds every counter. §5.9 is seeds 1–3 at `--sensed=0.2` and `0.6`.
`--death-log` prints one line per hunter that starves (its age, meals, radius,
upkeep, reach and speed); §5.4's table is `--until=240` with it, seeds 1–3,
and one override each: `--viable=0`, `--flight=all --rest-miss=-1`,
`--search=0`, `--hunt-hunger=0.5 --rest-meal=10`, `--notice=fixed`,
`--own-speed=0`, `--water-hunger=0`. `--lod=0` is §4.3's every-frame row
(`--sensed=0.6 --until=600`); `--empty-room --lod-every=8|16|32` is §10.3's
room; `--absorb=0 --drifters-starve=1` is row 11's third answer. `--desert=D
--watch=D` clears a disc and counts it back, `--anchored` puts a still player
in it.

### 15.3 The forage bot

```
godot --headless --path . --fixed-fps 60 -s res://tools/forage_probe.gd -- \
    --size=1280x720 --seed=S --mode=0 --scheme=0 \
    --genome=cytostome:1,cirrus:1,flagellum:1 --probe-until=180 \
    --screen=1280x720|1600x720 P2 --avoid-venom
```

S = 1 to 32 on each shape, and 33 to 64 and 65 to 96 for §8.3's spread and
headline. Without the drop's flags it is energy.md §7.3's run, and reproduces
its numbers exactly on seeds 1–16 (6 and 4 starved) and the first pass's game
by game. `--age=900` is the aged drop; §8.3's other rows add one override each
(`--avoid-venom` left out, which is the plain bot; `--contact-swallow=0`;
`--notice=fixed`; `--own-speed=0`; `--drifter-venom=1`; `--cautious`;
`--first-delay=0`), and §8.5's dials one each
(`--hunt-hunger=0.6`, `--snow=0.29`, `--drifter-size=16-24`,
`--density=3.9e-6`, `--tank=45`). It prints the cause of a death, `[forage-near]`
(food, dread and threats along the path), `[forage-compete]` (targets another
eater took first) and the census at the end. The nose bot is the same line with
`--genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1 --sniff` in place of
`--screen=`, seeds 1 to 32 (energy.md §7.4's bot).

### 15.4 The bubble's real density

The forage line above with no drop flags prints `[forage-living]`: living bodies
within 1,400 µm along the path, 26.8–27.8 on seeds 1–4.

### 15.5 Renders

§3.4 and §7.6's commands, through `tools/shot.tscn` under xvfb with
`--rendering-driver opengl3` and `--fixed-fps 60`, at 1280x720 and 2400x1080.
One frame rendered three times first: 0 differing pixels. Pass 2 changed no
drawing, so the first pass's frames stand; its one new frame, a death by hunger,
is §7.6's `starve`.

### 15.6 The chase contract

```
godot --headless --path . --fixed-fps 60 -s res://tools/chase_probe.gd -- \
    --seed=S --mode=0 --scheme=0 --hunt=900 --chase-for=40 [--evade] \
    [--own-speed=1 --pay-effort=1 --hunter-genome=cytostome:3,flagellum:T[,myoneme:1]]
```

S = 1 to 14; without the bracketed flags it is today's rule. Prints `[chase]
caught|escaped at t s, breaks n`. It runs in today's bubble, where the posed
hunter is body 0 and the opening moves body 0 when the cell first moves (§5.7);
`tools/chase_trace.gd` with the same flags prints the hunter's state, target
and distance every half second, which is how that was found. In the build the
probe should pose its hunter in a slot the opening does not use.

### 15.7 The save

`godot --headless --path . -s res://tools/save_size.gd -- P2 --sensed=0.2`:
a drop aged five minutes, stored in §9.3's shape, its size raw, compressed and
on disk, and the whole save ten times into the prototype's own `user://` --
gathered, written through `open_compressed`, read back and compared, renamed
-- three runs, one at a time on an idle machine.

---

## 16. Left open

1. **The drop is over the frame budget here, and one phone was measured.** In
   its steady state it costs 2.6 times today's field against the 1.5 this
   document set (§4.4) -- pass 2's one body added about a fifth to the first
   pass's 2.1 -- and the factor of six is an assumption: 7.1 to 8.0 ms of the
   16.7 ms frame the gate holds a phone to, 60 Hz at most. §14.2's phone gate
   passed on the owner's phone on 2026-10-01 -- 0 % dropped, now and then
   0.1 % -- with no lever pulled. What is left open is a slower phone, and a
   player's report is where it would show first. Skipping a tank that cannot
   move is built in, and worth about 30 µs here.
2. **A phone that hosts with a guest was not measured** (§10.2): two anchors,
   twice the near water, two scan lists and the wire. It is the drop's worst
   case and 1b's gate.
3. **The survival numbers are one bot's, and noisier than the first pass
   said.** Three sets of seeds of the new drop lost 19, 40 and 17 of 64, and
   the first set replayed with nothing changed but the random stream lost 29
   and 29: in pass 2 one swallow ends a game, and chance moves 64 games by ten
   or more. Only the changes that touch a few games -- rows 15 and 16 -- are
   measured beyond it; row 14, the hunters' reach and the dials are not, the
   density at the edge of it at best. The bot swims at food through anything,
   so every contact swallow it met is one a careful player might not; and it
   divides every 35 s or so, so `FIRST_DELAY` keeps it almost unhunted. How the
   drop feels to a person is the dev app's to say, which is what the owner
   asked for.
4. **Point of view was measured with the nose bot only** (§8.3), and before
   the edible cue followed the swallow radius (§14.1). The radar bot was not
   run.
5. **The hunters at r40 until pack 2** (§5.5): about half of them at a
   newborn's composition and a third at a sighted player's, eating to live.
   That is the rules' own stand-in for age, and the reason an aged drop holds
   more threats than a new one -- though the bot lost as many games in either
   (§8.3). If playing says it is too much, the dials are in §8.5; the fix that
   is not a dial is pack 2's division.
6. **Legendary organisms are back, and common** (row 5, answered): after thirty
   minutes 16 to 23 bodies at a newborn's composition, and 49 to 55 at a sighted
   player's, could swallow a player at full size (§5.5, §17's note on rows 4 and
   5). The owner's own call, and nothing here limits it.
7. **The drop turns over fast**: about 355 to 635 new bodies a minute, and a
   hunter lives about a minute on average before it starves or is eaten (§5.9:
   92 hunters and 72 deaths a minute at a newborn's composition). It costs
   nothing a player sees and a little CPU (§4.4); it is also a drop whose
   hunters seldom live long enough to matter for evolution, which is pack 2's
   to change.
8. **The empty room's tick** (§10.3): about 3 % of a core here at the far
   rate; half the rate halves that and moves the room's ecology about 6 %; a
   quarter moves it a third. Pack 1 keeps the far rate. Whether a slower tick
   is worth it depends on the server's core, which was not measured.
9. **Behaviour defaults are pack 3's** (§5.4): the hunt threshold, the rests --
   5 s after a meal and after any miss -- and the search. They were chosen so
   that the rules work, not tuned, and each is one constant. `FIRST_DELAY`
   stays, as row 16 decided.
10. **Venom waits for the gene pass** (row 12): the one body rule not yet the
    same for every cell, and the owner's two variants, venomous and poisonous,
    replace it then (§5.6, `roadmap.md`). The prototype's `tools/dose_probe.gd`
    duels today's venom against stacks on the game's own bite arithmetic, for
    when it comes.
11. **Built on paper, not in the prototype**: the cell that eats a player is fed
    by it (§5.6); the edible cue on the swallow radius (§14.1); the dev app's
    frame readout (§14.2). None of them moves a number measured here -- a solo
    run ends when it is eaten, and the full-vision bot aims by its own rule --
    but each is new code the build must test.
12. **What a phone's flash takes to write a save** was not measured (§9.3): 5.6
    to 8.5 ms here for the whole save, read-back included, and only ever off
    the play frame.
13. **The chase probe poses its hunter in body slot 0**, which today's opening
    moves (§5.7); its rows compare with each other, not with the documented
    contract. The build's probe should use a slot the opening does not.
14. **The recorder keeps 48 bodies.** Enough for everything but the farthest
    echoes, which the ring keeps on their own.
15. **Moving the seeding tables into `drop.gd`** waits for a second water (§13).

---

## 17. Owner's calls

The first round, as it was put and as it was answered on 2026-09-30.

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | How big is the ocean? | 8 mm across · **12 mm across ✓ answered** · 16 mm across | A newborn swims straight across it in 2 min 22 s · 3 min 32 s · 4 min 43 s, and a fast cell in about half that. At 12 mm you reach the edge from the middle in under two minutes and come back to places you know within a run. At 8 mm the edge is on the screen often; at 16 mm most of it is somewhere you never go. |
| 2 | What is at its edge? | **the rim of a drop of water: you bump into it, and the water ends ✓ answered** · the square wall of a counting chamber · no edge: swim off one side and come back on the other | The ocean is a drop of water on a microscope slide. At its round rim you feel a knock, your radar hears a wall, your eyespot sees a shadow, and full vision shows the bright edge of the water and dry glass beyond. A square chamber has corners things get stuck in. Wrapping round has no end at all, which is what you said you never reached. |
| 3 | What is the ocean called? | ocean · **the drop ✓ answered** · the slide | It is what the game shows: a drop of pond water under a microscope. "Pond" already means playing together. Only these documents and the code use the name today; a player would meet it only if a later screen names the place. |
| 4 | What ends a cell in the water? | it dies of age, about three minutes after it was made, and never grows bigger than you can (was recommended) · **it has to eat like you, or starve ✓ answered** · nothing: it only stops growing at your full size | With nothing at all, a cell that kept eating grew to 664 µm across, nearly the height of your screen, in eighteen minutes. Dying of age keeps the water young: it gets harder over its first five minutes and then holds, and an old cell leaves food where it dies. Hunger is the most realistic, but in testing it doubled how often you starve, because hungry cells eat the food around you; it is kept for when the water learns to hunt. Only stopping growth fills the water with full-grown cells for good. |
| 5 | Can a cell in the water grow a mouth big enough to swallow you as you reach full size? | no: its mouth stops growing at the widest the water makes (was recommended) · **yes, as you decided for today's water: a cell that earns it by eating is a legendary organism ✓ answered** | You decided that today's water keeps a cell that eats its way past the widest mouth, as a legendary organism, and today it is rare, because the water round you is thrown away every time you divide. An ocean keeps its cells, so it stops being rare: after 25 minutes, 37 cells could swallow you as you reach full size, about one every three screens. With the limit, the fear fades as you grow to full size, as it does today, and a later pack can bring a legendary cell back on purpose. A cell that is still growing meets the same danger either way. |
| 6 | What does food that isn't alive give you? | **food only: it fills you, and you don't grow or get a gene ✓ answered** · food and growth, no gene · food, growth and the dead cell's gene | It is detritus: small brown clumps that settle where few cells are and melt away after two minutes, a meal where nothing alive is left. Only eating living cells makes you bigger and changes your genes. If it grew you, a player could reach every division without ever hunting. In testing it seldom decided whether a newborn starved, because the ocean refills an empty place within a minute; it is there for when it has not yet. |
| 7 | Do cells that die leave food? | **yes: a cell that dies of age or poison leaves a small clump where it died ✓ answered** · no | Death feeds the water, so a place where cells died is a place with food. A cell that is eaten leaves nothing: whoever ate it got it. |
| 8 | Is the ocean kept between runs? | only while the app is open · **saved on the phone, and the same ocean continues next time ✓ answered** · a new one every time you die, as today | Evolution in the next packs needs many generations. If the ocean is thrown away, its cells can't improve. Saved, the ocean you come back to is the one you left, and the home server can keep one of its own. It is saved when you die, pause or leave the app. In testing an old ocean was as kind to a newborn as a new one on average, but some old oceans were harder than others. |
| 9 | Where does a run start? | **somewhere quiet, chosen for a newborn ✓ answered** · always the middle · anywhere | Quiet: out of 64 places, the one where the fewest cells could eat a newborn, the nearest counting most, with food nearby but not right on top of you; and if a hunter is still in range, it is moved away before you arrive. The middle is always the same place and just as dangerous as it happens to be. Anywhere can start you next to a hunter. |
| 10 | Ship it all at once, or in two? | one release · **two: the ocean alone first, then playing together and saving ✓ answered**, overtaken on 2026-10-01 by one release (§14.2) | Two: the first release changes nothing about playing with a friend, so nobody is locked out of anyone's game; the second changes the network version and needs both phones updated. One: everything at once, and a bigger thing to test before any player gets it. |

**Answered on 2026-09-30.** The owner, verbatim:

> All recommended except :
> 4 : I don't get this one. A cell dies of hunger, nothing else. Unless it gets eaten by another one
> 5 : all cells follow the same rules. Me, friends, NPC, doesn't matter.
> 8: why not. We could imagine server rooms that always grow and you can join whenever you want
> Solo mode could also save the state and reuse it. And when hosting on a phone, it serves the personal world of the host, saving it again when the server is stopped

So rows 1, 2, 3, 6, 7, 9 and 10 stand as recommended: 12 mm, the meniscus, the
name "the drop", a floc is food only, dead cells leave remains, a quiet start,
and two releases. Three rows changed the design:

- **Row 4**: no age, and no cause of death but hunger and being eaten --
  swallowed or chewed (§5.6). Every cell runs the player's metabolism (§5.2).
  Venom was asked separately (row 12), because killing the eater is the opposite
  of being eaten: it stays as it is today through pack 1, and the gene pass
  brings it in two variants. The first pass deferred hunger because it doubled
  the bot's starvation; built with the rest of §5 it does not: the bot starves
  less often than in today's water -- hunters held to their own senses and tail
  eat a sixth fewer of the drifters (§5.4), and the ones that starve leave food
  where they die -- and is eaten more often instead (§8.3).
- **Row 5**: one set of body rules for every cell (§5.7). The mouth keeps what
  it grows, so the legendary organism of genes-and-cilia.md §1.3 is back.
  Growth stops at 40, where the player's does.
- **Row 8**: kept, in the owner's shape: your drop saved and reused, a phone
  host serving its own drop and saving it when hosting stops, and the home
  server's room living on while it is empty (§9, §10).

**What rows 4 and 5 did together, in plain words.** Row 5 was answered on "after
25 minutes, 37 cells could swallow you as you reach full size", measured when
cells still died of age. With hunger in place of age, nothing takes a grown
cell down but hunger: after thirty minutes **49 to 55 cells can swallow a
full-size player** in a drop made for a player with good senses, and 16 to 23
in one made for a newborn. And a newborn's drop is dangerous early: **61 to 67
of its 92 hunters can swallow a born cell after five minutes**, against 22 to
24 when it is new (§5.9).

Later the same day, verbatim: *"Don't go too far with ensuring a player lives
as long as today. I'll playtest it and tell you how we can fix that"*. So §8
measures the player's survival, against today's water and the first pass, and
names the dials a playtest turns (§8.5); no balance number is put to the owner
as a call.

### 17.1 Owner's calls, second round

The first round's answers raised eight new calls, and an independent review of
this revision asked for three of them (rows 12, 16 and 17). Each is a real
choice about what the game is; the balance that only play can settle is in
§8.5's dials instead. All eight were answered on 2026-09-30, the owner's words
under the table. "A test player" below is the forage bot of §8.3: it swims
at food without looking out for danger, so it shows what a rule does, not how
long a person lasts.

| # | Question | Options | What it means |
|---|---|---|---|
| 11 | How do the drifters -- the small cells with no mouth organ -- live, now that every cell can starve? | **they soak up food dissolved in the water, enough to live on, and die only when something eats them ✓ answered** · they eat the clumps of dead matter that fall, and starve where none fall · they starve like any cell, in about 45 seconds, and the water keeps replacing them | Real cells without a mouth live on what is dissolved in the water, or on light. Soaking it up: the drifters you eat are always there, as today. It holds for you too: if you put a gene over your own mouth organ, you soak up food as well, and a newborn's full tank lasts about 55 seconds instead of 30, so that move stops being a trap. Eating the clumps: the falling food becomes the start of the food chain, and drifters crowd where it falls and vanish where it does not. Starving: about six drifters a second die across the drop, and the water fills with hundreds of clumps. |
| 12 | When a mouth swallows a venomous cell, does the eater die? | yes, every eater, you included (was recommended) · no, venom only makes a biter pay, as it does for you today · **neither in this pack: venom stays as it is today, and the gene pass brings it in two variants -- a venomous cell's bite adds stacks of venom to what it bites, and whatever bites or eats a poisonous cell takes stacks; the stacks wear off over time, doing damage while they last ✓ answered** | Venom stays as it is in this pack: biting a venomous cell hurts you back, a cell that swallows you dies of your venom, and you can swallow a venomous cell safely. Later the gene pass brings two kinds of cell: a venomous one hurts what it bites, a poisonous one hurts what bites or eats it, and the hurt comes as stacks that wear off over time. |
| 13 | If row 12 is yes: can the drifters carry venom? | **no: drifters are never venomous; only cells with a mouth organ carry it ✓ answered** · yes, as today, about one drifter in nineteen | No: every drifter is safe to eat. A venomous cell with a mouth organ that is small enough for you to swallow still kills you: that is the one game in 64 above. Yes: one drifter in nineteen kills you when you swallow it; in full vision you can learn its colour, in point of view you cannot tell. The test player died of venom in 42 games of 64 with venomous drifters, and in 1 without; one that steers round the venomous ones it sees still died of it in 7, swallowing what it bumped into. If row 12 is no, this row changes nothing. |
| 14 | How fast does a hunter swim after you? | **as fast as its own tail lets it, as you do, from this pack ✓ answered** · as today until the behaviour pack: always a fifth faster than you, and 70 % faster in its last dash | Today a hunter chasing you is always faster than you, whatever it is made of. With its own tail, a hunter with a better tail than yours is faster, and a worse one cannot catch you if you swim away. A hunter with a tail like yours still catches a cell that does nothing 11 times in 14, and one that turns away escapes 13 times in 14. The test player could not tell the two apart: its 64 games, replayed with nothing changed but chance, move by as much. |
| 15 | Can a cell swallow you when it is not hunting you? For playing together you answered "keep it for both of you until the gene phase". | **yes, from this pack: any mouth swallows what fits on contact, yours and theirs alike ✓ answered** · no, keep your answer: only a cell that is hunting you can swallow you, until the gene phase | Today something must be hunting you to swallow you, so a death always comes after a warning you can feel: dread rising, and its strokes. Yes: a big cell that drifts into you can swallow you; dread still warns you it is near, its strokes do not. On the same 64 games, with a thick skin protecting every cell either way, the test player lost 18 in a new drop against 14 with your rule, and 31 against 25 in a drop fifteen minutes old. |
| 16 | Do hunters leave you alone for 42 seconds after you are born or divide? | **yes, as today, until pack 2 gives every newborn the same ✓ answered** · no, you are fair game from the first second, like any cell | Today nothing may hunt you for 42 seconds after you are born, divide or come back from a death; the water's cells get no such grace. Yes keeps it for you and your friends. No makes you like any cell: hunters may come for a newborn from its first second, and a cell that divides often is hunted all the time. On the same 64 games the test player lost 28 in a new drop against 18 -- ten more games, each one where a hunter came for it -- and 34 against 31 in a drop fifteen minutes old, where what kills is mostly a big mouth it swims into. |
| 17 | When you close the app in the middle of a run and come back, is your cell still there? | **yes, you carry on where you left off ✓ answered** · no, the drop is kept but you start a new run | Yes: closing the app is a pause, and you come back to the same cell, with its size and its genes, where you left it in your drop. Today a run is one sitting: closing the app ends it, and you always start as the basic cell. The replay then only holds what happened since you came back. No: your drop is kept, but opening the app starts a new basic cell in it, as a death does. |
| 18 | How many rooms does the home server keep, always alive? | **one: the server's own drop, living on while nobody is in it, joined as today ✓ answered** · several, each living on, and you choose one when you join | One: nothing changes about joining, and the room keeps living for about 3 % of one core of this container while it is empty (measured here, not on the server). Several: each costs as much again, and you need a new page to choose one, which is a design of its own. More rooms can come later without changing the first. |

**Answered on 2026-09-30.** The owner, verbatim:

> 12 : venom add a stack of venom while it's biting. The stacks deplete over time, doing damage. We could later imagine specialized venoms later. But for now keep it simple
> All recommended for the rest

and, asked who takes the stacks -- whatever bites or swallows a venomous cell,
whatever a venomous cell bites, or both -- and whether a swallowed venomous
cell is spat out alive:

> 12a and b : There'll be 2 variants. This is about the difference between venomous and poisonous. We'll add both on the gene pass later.

So rows 11 and 13 to 18 stand as recommended, and venom is not reworked in pack
1: `veneneux` keeps both of its effects today, and the gene pass brings the
two variants (`roadmap.md`).

**Row 11** is a rule of the body, keyed on the organ (§5.3). It also changes
a decided call: genes-and-cilia.md §9 item 7 allowed a player to put a gene
over their own mouth as "a real and interesting mistake or a soft lock"; with
absorption it is a slow, cheap body, and neither.

**Row 12** leaves venom where it is: the one body rule not yet the same for
every cell (§5.6, §5.7). Whatever bites a venomous body still takes a share of
the bite back, and whatever swallows a venomous player still dies of it, while
a player swallows a venomous water cell safely. The pass-2 prototype had made
the swallow death every mouth's, as the row recommended; that is reverted, and
§5.6 says what it did to the numbers. The gene pass replaces both effects with
the owner's two variants: **venomous** -- its bite adds stacks of venom to what
it bites -- and **poisonous** -- whatever bites or eats it takes stacks; the
stacks wear off over time, doing damage while they last, and specialised
venoms may follow.

**Row 13** is what the water makes, not a rule of the body. It was asked for
row 12's yes, and it stands: drifters carry no venom, which matters again when
the gene pass brings poisonous cells; its numbers were measured with the swallow
death for every mouth (§8.3). **Row 14** reverses a call made for Phase 5 ("the
chase stays a chase at every tier", genes-and-cilia.md §7.1). **Row 15** is the
contact swallow alone: it reverses `shared-pond.md` §6 row 3, where "both of
you" meant the two players; the one-bite-or-chewing phase in roadmap.md then
starts from one rule instead of an exception, with venom the one left.

**Not asked, because row 5 decides them.** A thick skin (`pellicle`) protects
every cell from being swallowed, not only a player: it was never put to the
owner as its own call (`shared-pond.md` §0.5 left it to a later phase), and it
was not measured the other way -- every row of §8.3 has it on. **How far a
hunter notices you** is its own senses' reach (§5.7); the alternative, today's
1.9 mm for every hunter, is a dial (§8.5); on the same 64 games it lost the
test player 33 against 18, which chance alone can do (§8.3).

**Row 16** keeps a player's grace until pack 2's newborns can share it, and
leaves the referee's `FIRST_DELAY` where it is (§10.5). **Row 17** changes
genes-and-cilia.md §9 item 4 ("the arc is one session"): a run can span
several sittings, and a death is still the only clean restart. **Row 18**: one
room, from 1b.
