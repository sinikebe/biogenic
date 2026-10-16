# Daylight: a day, a night, and light that fades with depth

The owner, 2026-10-16:

> Add a day/night cycle. Sun should depend on sun exposition. The deeper we go,
> the less sun produces. We'll see later how we will also make see affected by
> light

So: the drop gets a day and a night; `plastid`'s food from the sun (the `sun` stat)
follows how much light reaches the cell; less light reaches it the deeper it is.
**Light on the senses is the owner's later step.** This page designs nothing for it
beyond the one call it will need (§9).

**Status: built, both phases (2026-10-16)**: phase 1, the light, and phase 2, the
pond (§10.2). Written from the code on `dev` at 838c997, with the venom-rides
change (807f553) on top of it. Nothing was prototyped or measured (the owner,
2026-10-02: *"Don't measure in prototypes. I'll playtest."*). Every number below is
a starting value with its reason. Balance waits for players.

**As built**, where it differs from the words below:

- `food.gd`'s switch is `daylight`, as `--daylight=` names it, and GDScript will not
  give a method the same name, so the surface light it answers is `daylight_now()`.
  `light_at(p)`, `light_over(p, t0, t1)` and `restore_daylight(v)` are as written;
  `light_at_deepest()` hands the shader what reaches the middle, and `day_time()` the
  hour a kept drop keeps.
- **Phase 2, the pond**: a mirror keeps the host's surface light from each POND
  snapshot (`apply_pond(..., daylight)`), full until the first, and answers it times
  what gets through at its place under the host's rim -- for its tank, its tile and
  the water's tint; it keeps no day of its own (`day_time()` is -1). A server's room
  sends its own room's light, the same way. `Wire.PROTOCOL` is 10, `POND_HEADER` 12
  and `POND_MAX` 1,183; `Wire.RULES` did not move. A guest's replay records the host's
  light, so the truth pane is tinted as the guest saw it.
- net_fuzz's saved corpus greets on `hello:10`, and its seven hand-written snapshots
  carry full light after the loads, so each still says what it said.
- A tank that cannot move is judged at the least light anywhere, `NIGHT_LIGHT` under
  the whole depth (0 today), rather than `NIGHT_LIGHT` alone.
- The sun tile sits first in the row, beside the energy gauge (§3.3).
- §10.3 check 5: `DEV_LINES` and `DAYLIGHT_LINES` pin the drop of drop_probe's
  `_lineage` (pack 2's hunter, seed 1) with the light off and on. `TAIL_LINES`,
  `_five_minutes`' drop with the light on, are the build's own and moved with it.

---

## 0. In one place

1. **The drop has a day of ten minutes**: a minute of dawn, five of day, a minute
   of dusk, three of night (§2.1).
2. **Night is dark for the sun**: a plastid makes nothing at night. The picture
   keeps a floor, so the water never goes black (§3.1).
3. **"Deeper" is toward the drop's middle.** A drop on a slide is a lens: thin at
   its rim, thickest at its middle. Light falls off with the water above the cell,
   as Beer–Lambert has it: all of it at the rim, a quarter at the middle (§2.2).
   This is the owner's main call (§12, row 1).
4. **Sun income is the plastid's `sun` times the light where the cell is.** The
   player and every water cell read it through one function, averaged exactly over
   the step each one is paid for (§2.3).
5. **What the player sees** (§3):
   - in full vision, the water's own glow dims where light is low, and turns bluer
     at night. Cells are drawn as bright as ever;
   - a sun tile in the HUD row, in both views, while the line carries a plastid;
   - the energy gauge's rate already moves with the light;
   - the plastid's pause-screen line says its number is in full sun.
6. **The water's plastid cells follow the same light.** Nothing else in the water
   changes at night (§4).
7. **The shared pond shares the host's sky** (§5):
   - the host's surface light rides in every POND snapshot;
   - that is a message format change, so `Wire.PROTOCOL` moves to 10;
   - `Wire.RULES` does not move: the referee judges nothing light changes.
8. **The time of day is kept with the drop**, and a drop kept before this opens at
   morning (§6). **The replay records the light** and draws it (§7).
9. **Content only**: GDScript and one shader. No `binary_version` bump.

---

## 1. What the code does today

- **The plastid** (`game/genes/organs/plastid.gd`) provides `sun`, `SUN_BY_TIER`
  0.12 / 0.22 / 0.34: seconds of rest a second, taken off the resting bill.
- **The player**: `normal_mode.gd:1619` sets `_metabolism.photosynthesis =
  _cell.stat(&"sun")`, and `:1625` adds `_food.absorb` for a mouthless cell in the
  drop. `metabolism.gd`'s `rest_rate(upkeep, income, reserve)` pays the rest.
- **The water**: `food.gd`'s `_refresh_body` (`:8066`) sets `b.sun` and `b.income
  = b.sun + absorb` once, when the genome changes. `_tank` (`:7941`) pays
  `rest_rate(b.upkeep, b.income, b.reserve)`, and skips a body whose income covers
  its upkeep (`skip_still`).
- **Nothing else reads `sun`** but the pause screen (`gene_stats.gd`'s `context`,
  the caption's "drifting" time) and the probes.
- **The drop's clock** is `food.gd`'s `_t` (`:6650`): the seconds the drop has run.
  It stops while the cell is dead or dividing, under a single-player pause and in a
  pond's still moments. It is saved as the drop's `age` (`:7321`).
- **Today's water**, the field with no drop, is reached only by a tool's
  `--drop=0`. Players always play the drop. Today's water keeps full light.
- **Depth today** is `basin.gd`'s `depth(p)`: how far inside the rim a point is.
  The rim's 240 µm band is already called `SHALLOWS` (`drop.gd`), and the shader
  draws it as "the thinning film" (ocean.md §3.3).
- **There is no up-and-down.** `statocyst` ("level") was retired on 2026-09-28
  because "knowing which way is up says nothing about the water".
- **`sun` is neither judged nor contact** (`stats.gd`), so it is not in the rules
  the handshake fingerprints (`rules.gd`).
- **A POND snapshot** has a 10-byte header (`wire.gd:411`) and goes out at 20 Hz.

---

## 2. The rule

### 2.1 The day

The day is a cycle of `DAY_SECONDS` = **600**, in four spans, starting at dawn:

| span | seconds | from | light at the surface |
|---|---|---|---|
| dawn | 60 | 0 | rises, `smoothstep(u)` |
| day | 300 | 60 | 1 |
| dusk | 60 | 360 | falls, `1 − smoothstep(u)` |
| night | 180 | 420 | `NIGHT_LIGHT` = 0 |

- `u` is how far through the span, 0 to 1. `smoothstep(u) = u²(3 − 2u)`, so the
  light never jumps and never stalls at a join.
- **Ten minutes, so a sitting meets a night.** A born cell that never eats lives
  50 s (`metabolism.gd`); a lineage plays for many minutes in a drop that is kept.
  At ten minutes, twenty minutes of play holds two nights.
- **Day longer than night**, so a plastid's day at the surface averages 0.6 of what
  it makes today, and night is a phase to get through, not most of the game.
- **Three minutes of night** is longer than a full tank at rest (72 s), so a cell
  that leans on its plastid has to eat through it. It is short enough to wait out.
- **Night is dark for the sun.** Real moonlight is under a millionth of sunlight
  and drives no photosynthesis. A floor would blur the one thing night says: the
  plastid stops. The floor is a constant, `NIGHT_LIGHT`, if play wants one.
- **A new drop starts at the end of dawn** (`DAY_BEGINS` = 60 s): five minutes of
  full day first, so a new player meets the plastid doing what its line says.

### 2.2 Depth

**A drop on a slide is a lens.** Surface tension pulls a sessile drop into a cap:
the water is a film at the rim and thickest in the middle. Ocean.md §2.1 already
draws the drop that way. Light comes from above and passes through the water over
the cell, so **deeper is toward the middle**.

- **The water over a point**, as a share of the deepest:
  `column(p) = s (2 − s)`, with `s = clamp(depth(p) / radius, 0, 1)`. That is the
  shape of a shallow cap, 0 on the rim and 1 at the centre.
- **What gets through**: `LIGHT_AT_MIDDLE ^ column(p)`, with `LIGHT_AT_MIDDLE` =
  **0.25**. That is Beer–Lambert, `e^(−k·z)`, with its strength stated as what
  reaches the deepest point.
- **The light at a point** = the surface light (§2.1) × what gets through.

| from the rim | 0 | 240 | 600 | 1,200 | 1,800 | 3,000 | 6,000 (middle) |
|---|---|---|---|---|---|---|---|
| what gets through | 1.00 | 0.90 | 0.77 | 0.61 | 0.49 | 0.35 | 0.25 |

- **Why a quarter.** Half the light is lost 1,757 µm in from the rim, about one
  and a half screens. Half the drop's area gets more than half the light. The
  middle still makes a quarter by day, so the plastid works everywhere by day and
  best near the rim. A middle at nothing would make it a gene for the 240 µm band
  alone.
- **The realism is the shape, not the strength.** Pure water 1 mm deep loses
  under one percent of the light. The game's drop loses three quarters, as a pond
  about a metre and a half deep would. Gameplay wins.
- **What the player does differently**: a cell living on its plastid goes toward
  the edge by day. Real plankton do the same in a pond: they rise to the light by
  day and sink at night (diel vertical migration). Here, rising is going to the
  shallows.
- Averaged over the whole drop's area the light that gets through is 0.54 of the
  surface's. A cell anywhere at random, all day long, makes about a third of what
  its plastid makes today (0.6 × 0.54).

### 2.3 Sun income

- **Sun income = `sun` × the light where the body is.** Absorption is unchanged and
  is added after it, as today: `income = absorbs + sun × light`.
- **Averaged over the step it pays for, exactly.** A far water body is stepped once
  every 8 or 32 frames (`LOD_EVERY`, `LOD_SLOW`) with all the time it is owed. It
  takes the surface light's exact mean over that time, from the curve's integral,
  times what gets through at its place. The player takes the same mean over its
  frame. So a near body, a far one and the player are paid one light, and the
  arithmetic of a tank (`metabolism.gd`) does not change at all.
- **The integral** of `smoothstep` over a span is `u³ − u⁴/2`. A day's whole
  integral is `DAY + (DAWN + DUSK) / 2` = 360 s of full light.
- **The player's frame.** `NormalMode` processes before its `Food` child, so when
  the run sets the income, the field's clock is at the frame's start. The player is
  paid the mean over `[drop_age(), drop_age() + delta]`.
- **A tank that cannot move is still not stepped**, judged in the dark:
  `skip_still` skips a body only when `absorbs + sun × NIGHT_LIGHT` covers its
  upkeep. A body that needs the light to hold its tank is stepped. With the switch
  off (§10.3) the test is today's, `upkeep <= sun + absorbs`.
- **Off is today, to the byte.** With no drop, or with `daylight` off, the light is
  the literal `1.0`, so `absorbs + sun × 1.0` is today's `sun + absorbs` bit for
  bit (IEEE addition commutes; a product by 1 is exact).

### 2.4 What it does to a plastid, worked out from the code

A born cell at rest pays 1.0 s a second. Each plastid copy after the first adds
`UPKEEP_PER_TIER` 0.18 (`genome.gd`). The rest rate is `upkeep − sun × light`:

| copies | upkeep | noon, at the rim (today's) | noon, at the middle | night |
|---|---|---|---|---|
| 1 | 1.00 | 0.88 | 0.97 | 1.00 |
| 2 | 1.18 | 0.96 | 1.13 | 1.18 |
| 3 | 1.36 | 1.02 | 1.28 | 1.36 |

- These are arithmetic, not measurements. The gauge shows them as its rate, plus
  whatever moving costs.
- **One copy is never a loss**: the first copy is free, so at night it costs a slot
  and nothing else.
- **Two and three copies already barely pay today**, and now pay only by day near
  the rim. That is a balance finding to watch (§11), not a change made here.

### 2.5 Kept generic

- **`game/mechanics/daylight.gd`** (new) knows a cycle of four spans and a floor:
  - `surface(t)`, the light at the surface `t` seconds into the cycle;
  - `mean(t0, t1)`, its exact mean over any stretch, whole cycles included;
  - `through(column, at_deepest)`, what gets through a share of the deepest water.

  It never says sun, plastid, drop or water.
- **`basin.gd`** gains a sixth call, `column(p)`: the share of the region's deepest
  that lies over `p`, for a dome over it. Another basin shape is another script
  with the same six calls.
- **`drop.gd`**, the environment file, holds this water's numbers: the four spans,
  `NIGHT_LIGHT`, `LIGHT_AT_MIDDLE`, `DAY_BEGINS`, and a `daylight()` that builds the
  cycle from them.
- **`food.gd`** keeps the clock and answers `daylight()` (the surface now),
  `light_at(p)` and `light_over(p, t0, t1)`. Any stat that should follow the light
  asks these. The plastid's `sun` is the one that does, and it is multiplied where
  it is read, at the edge.

---

## 3. What the player sees

### 3.1 Full vision: the water's own light

`water.gdshader` is additive over the membrane's near-black, so it cannot darken
anything but its own glow. That is what changes, in the drop only:

- **Where light is low, the water's glow dims**: grain, cloud, grid and the rim's
  film, inside the water, times `mix(NIGHT_GLOW, 1, here)`. `here` is the light at
  that fragment, surface × what gets through: the same two numbers as §2.
- **At night the water's tint turns bluer**: `mix(NIGHT_TINT, water_tint,
  day_light)`, by the surface light alone. Depth only dims; night dims and cools.
  So the middle at noon and the rim at night do not look alike.
- **Starting values** for the UX/UI designer, who owns the look and shoots it:
  `NIGHT_GLOW` 0.5, `NIGHT_TINT` `vec3(0.10, 0.40, 0.66)` against today's
  `water_tint` `vec3(0.10, 0.62, 0.52)`.
- **Untouched**: the meniscus line, the cells, every ring and mark `vision.gd`
  draws. Nothing that says where something is gets dimmer. The edge stays as
  readable at night as by day.
- **Dry glass** past the rim dims with the surface light, at the same floor.
- **Cost**: one `exp2` and a few multiplies a fragment, inside the drop's branch,
  which already takes the distance to the centre.
- **Shoot it** at 1280x720 and 2400x1080: noon at the rim, noon at the middle,
  dusk, night. The middle at noon is about 0.63 of today's glow, and night about
  0.5. Judge that the water still reads as water in all four.

### 3.2 Point of view: nothing new on the membrane

The membrane is the body and has no map. A cell feels light only through an organ
that uses it. So in point of view, **night is the sun tile and the gauge's rate**,
and only for a cell whose line carries a plastid. A cell without one does not know
it is night, by design: how the senses meet light is the owner's later step.

### 3.3 The sun tile

The HUD row's tile pattern (sense-tiles.md), for the organ that lives on light:

- **Shown** while the line carries a plastid, in its DNA or on its body. Grey when
  it is carried and not worn, and while senses are held (a division's pinch, a
  pond's still moments), exactly as sense-tiles.md §2 says.
- **Lit by the light where the cell is**: the glow and the bar are both
  `light_at(cell)`, 0 to 1. The same for one copy or three: the tile says the
  light, and the gauge says what it earns.
- **No words**: the organ is the label, as on every tile.
- **Room**: one 56 × 56 tile and its 12 px gap. With every sense worn the row ended
  at 776 px; it ends at 844 px, far from the autopilot's switch at 1,176. At
  2400x1080 the canvas is 1,600 wide.
- **Where in the row** is the UX/UI designer's call. Beside the energy gauge reads
  best, since it explains the gauge's rate.
- **Generic**: today a tile is keyed by its membrane channel. A `readout` organ with
  no channel is keyed by the stat it provides, here `sun`. Worn is the cell's
  provider of that stat; carried is the DNA's.

### 3.4 The gauge's rate

Nothing to build. `metabolism.gd`'s `paying()` already subtracts the income, so a
plastid cell's `−x/s` falls as it swims into the shallows by day and climbs at dusk
(§2.4). It is the same in both views.

### 3.5 Words

Two of the plastid's lines change, so neither says more than is true at night.

| where | English | French | room |
|---|---|---|---|
| its numbers on the pause screen | `makes {} s of food a second in full sun` | `produit {} s de nourriture par seconde en plein soleil` | a phrase in a ~650 px line of 14 px type. With three copies and its wear, the French line is about 92 characters: shoot it at both shapes |
| what it does, after its name | `feeds a little on light, so you starve slower` | `se nourrit un peu de lumière, la faim vient moins vite` | 440 px at 15 px. The old English (52 characters) took 365 px. The new English is 45 and the French 54 |

- The number stays the table's: what it makes in full light.
- **The caption's "drifting" time** (`gene_stats.gd`'s `cell_items`, drawn by
  `figure.gd`) uses the light where the cell is now, so `a full tank: 72 s, 64 s
  drifting` is true where you are. One parameter, `light := 1.0`.
- The old two strings leave `fr.po` and the `.pot`.

### 3.6 The dev app's readout

Two rows on the dev app's frame readout, untranslated as its others are: `day`, the
time into the cycle as a share (`0.42`), and `light`, the light at the cell. The
owner can then say what time it was when something felt wrong. A release build
draws nothing (`frame_readout.gd`).

---

## 4. The water

- **Every water body with a plastid follows the same light** (§2.3), on the host,
  in a room, and in a solo drop.
- **The drifters are untouched.** The water makes them with one copy of one gene
  (`food.gd`'s `_seed_drifter`), so their upkeep is 1.0 and absorption
  (`ABSORB` 1.0) covers it in any light. drop_probe's "a mouthless body at rest
  neither starves nor fills" now holds in the dark.
- **Hunters that carry a plastid** run hungrier at night and in the middle. More of
  them starve there and leave remains. That is the mechanic, not a side effect.
- **Nothing the water decides reads the light.** No rule, no search, no spawn. A
  water that swims to the shallows by day is a later pack's (§9).

---

## 5. The shared pond and the server

- **The host owns the sky.** Its surface light rides in every POND snapshot:
  - two header bytes after the loads, `daylight(u16, /65535)`. `POND_HEADER` goes
    from 10 to 12;
  - `POND_MAX` goes from 1,181 to 1,183 bytes, still one datagram under ENet's
    1,392-byte MTU;
  - a server's room sends its own room's light, the same way.
- **A guest's light** is the last snapshot's surface light × what gets through at
  its place in the host's drop. The rim comes from ARRIVE, as it does today. Until
  the first snapshot it is full light (one 20 Hz tick). Between snapshots it is held:
  at the steepest point of dawn the light moves 0.025 a second, so 0.00125 between
  two snapshots.
- **The guest's own metabolism needs it**: a guest pays its own tank. It is the
  only thing the guest reads the sky for, with its tile and its tint.
- **`Wire.PROTOCOL` moves to 10.** The header's format changed. A 9 reads byte 10
  as the first body, so the build refuses a 9 at HELLO by name, as 1 to 8 are.
- **`Wire.RULES` does not move.** The referee judges a guest's size, path, heading,
  arrivals, sister, body and death, and starving is the guest's own to say
  (`referee.gd`, `judge_died`). Light changes none of them. `sun` is neither judged
  nor contact, and no light constant enters `rules.gd`. net_probe `--referee-only`
  proves it, with the pin untouched.
- **What players notice**: a player on the old content and one on the new refuse
  each other with the version sentence until the older one updates. A dedicated
  server updates last, when its pond is empty, so for a while new players cannot
  join it. Say so in the patch note's line.
- **Not chosen: the device's clock.** A day read off UTC would agree across devices
  with no wire change. But the light would jump through every pause, every death
  and every stretch away while the drop stands frozen (ocean.md §9.1, row 8). And no
  seeded run could repeat it. The protocol bump costs almost nothing.
- **Not chosen: the clock in ARRIVE.** It would need a guest to run the host's clock
  and know every moment the host's water stood still. The snapshot carries the
  answer twenty times a second instead.

---

## 6. Saves

- **The time of day is kept with the drop**: a new key in `drop_save.gd`'s `EXTRA`,
  `"day": TYPE_FLOAT`, the seconds into the cycle when it was kept.
- **The field keeps where the cycle stood at age 0** (`_day_origin`). Loading sets it
  to `fposmod(day − age, DAY_SECONDS)`, so the day is a pure function of the drop's
  age. It stops when the drop stops, as everything else does.
- **A file from before has no `day`**: it opens at `DAY_BEGINS`, the end of dawn,
  whatever its age. A file from this build read by an older one is read as it was;
  `EXTRA` keys are optional.
- **The drop's own rules** (`drop_save.gd`'s `rules_text`) gain the light's lines:
  the four spans, `NIGHT_LIGHT`, `LIGHT_AT_MIDDLE`. They are the metabolism every
  body runs, beside `HUNGER_SECONDS` and `ABSORB`. So every kept drop and room reads
  as converted once and says so in the log. A conversion re-derives each body from
  its genome, which changes nothing a body is.
- **A guest's own drop**, set aside while it swims in a friend's, keeps its own day
  in its own state, frozen like the rest of it.
- **A room** is the same file, and keeps its day the same way.

---

## 7. The replay

- **One float more a frame**: the surface light, `AT_DAYLIGHT`, after the person's
  block. `STRIDE` grows by one, which is 14.4 KB more ring over the minute.
- **It lerps**: it is a quantity.
- **The replay's own field answers it** (`restore_daylight`), so `vision.gd` tints
  the truth pane as the run was tinted. What gets through is worked out again from
  the recorded place and the recorded rim.
- **The membrane pane changes nothing**: point of view drew nothing new (§3.2).

---

## 8. Cost, reasoned and unmeasured

- **The player**: one `light_over` a frame. Nothing.
- **The water**: only bodies with `sun > 0` pay, at each step: a square root, an
  `exp`, and the cycle's mean (two calls of the integral). Call it a few µs a body
  here. How many hunters carry a plastid is not known. If one in ten of about 170
  does, and each is stepped on a third of frames, that is about six a frame: under
  0.05 ms here, under 0.3 ms at `ocean.md` §4.4's assumed phone factor of six.
- **If it shows**, every far body stepped on one tick shares one stretch of time:
  cache the mean by `(t0, t1)`.
- **The shader**: one `exp2` a fragment in the drop. At 2400x1080 that is 2.6
  million a frame, which a phone's GPU does in its special-function unit.
- **Where to look**: the dev app's frame readout. `water` is the field's own ms and
  `dropped` is what the phone gate reads (ocean.md §14.2).

---

## 9. Hooks for later, not designed

- **Seeing affected by light** (the owner's later step). `light_at(p)` is the one
  call it needs: the eyespot's shadow, the beam's reach or the full-vision drawing
  of a cell could each be multiplied by it. Realism points the way: in a real
  euglenid, the stigma is the organ that steers toward light.
- **An instinct that reads the light**: a `light` value beside `hunger` and `fed`
  in `metabolism.gd`'s `DECLARES`, for the player's programs and the water's rules.
- **A water that migrates**: hunters on rules that swim to the shallows by day.
  That is evolution's to find once the light is an input.
- **A second stat that follows the light**: if one ever does, a `lit` field on its
  `stats.gd` row is the place. A row field that decides a value is one of `rules.gd`'s
  `ROW_FIELDS`, and moves `Wire.RULES`.
- **Weather**: a cloud is a change to `daylight()` alone. The host already owns the
  sky on the wire.
- **The plastid moving inside** (dna-slots.md row 15): light has no bearing, so
  nothing here cares which slot it is in.

---

## 10. Build plan

### 10.1 Files, in order

1. `game/mechanics/daylight.gd` (new): the cycle, `surface`, `mean`, `through`.
2. `game/mechanics/basin.gd`: `column(p)`.
3. `game/normal/drop.gd`: `DAY_DAWN` 60, `DAY_LIGHT` 300, `DAY_DUSK` 60, `DAY_NIGHT`
   180, `NIGHT_LIGHT` 0.0, `LIGHT_AT_MIDDLE` 0.25, `DAY_BEGINS` 60, and `daylight()`.
4. `game/normal/food.gd`:
   - the switch `var daylight := true`, with the other body rules' switches;
   - `_day_origin`, set by `_reset_drop` to `DAY_BEGINS` (a new drop and a new
     room both pass through it), and by `load_drop` from `"day"`; `drop_state`
     writes `"day"`;
   - `daylight()`, `light_at(p)`, `light_over(p, t0, t1)`. Each is a literal 1.0
     with no drop or with the switch off; a mirror's comes from the host and a
     replay's from the recording;
   - `Body.income` becomes `Body.absorbs`, set in `_refresh_body`;
   - `_tank` pays `absorbs + sun × light_over(b.pos, _t − dt, _t)`, and
     `skip_still` tests the dark income (§2.3);
   - `apply_pond(..., daylight)` keeps the host's light; `restore_daylight(v)`.
5. `game/normal/normal_mode.gd`:
   - `photosynthesis = stat(sun) × light_over(position, age, age + delta)`, then
     absorption as before;
   - the sun tile: a `readout` organ with no channel is keyed by its stat
     (`_readout_channels`, `_update_sense_tiles`, `_sense_reading`);
   - the light handed to the pause figure for its caption.
6. `game/genes/organs/plastid.gd`: `readout = true`, the two lines of §3.5, and its
   doc comment.
7. `game/normal/gene_stats.gd` and `game/normal/figure.gd`: `cell_items(...,
   light := 1.0)`.
8. `game/vision/water.gdshader`: `day_light`, `light_at_middle`, `night_glow`,
   `night_tint`. `game/vision/vision.gd`'s `_push_shader()` writes them from the
   field and `drop.gd`.
9. `game/dev/frame_readout.gd`: the `day` and `light` rows.
10. `game/normal/drop_save.gd`: `"day"` in `EXTRA`, the light's lines in
    `rules_text`.
11. `game/replay/recorder.gd` and `game/replay/replay.gd`: `AT_DAYLIGHT`.
12. `game/net/wire.gd`: `PROTOCOL` 10 and its paragraph, `POND_HEADER` 12, the
    `daylight` argument to `pond()`, and `take_pond()` returning it.
13. `game/net/net_session.gd` (`send_pond`, `send_pond_to`) and `game/net/pond.gd`
    (the send at `:720`, `apply_newest`): pass it through.
14. `game/i18n/biogenic.pot` (regenerated by `tools/i18n_pot.tscn`) and
    `game/i18n/fr.po`: the two lines of §3.5.
15. `tools/drive.gd`: `--daylight=0|1`, and `--day-at=<seconds into the cycle>` for
    the renders (`--day-at=480` is night).
16. The probes, §10.3. `.github/workflows/ci.yml`: the re-pinned hash, §10.4.
17. Dated notes where an older spec now says too much: ocean.md §5.2 and §10.4,
    sense-tiles.md §1, energy-gauge.md §1, gene-stats.md's plastid row.

### 10.2 Phases and releases

**One release, built in two steps that each land on `dev`**:

1. **The light**: files 1 to 11 and 14 to 17. Single player, the water, saves, the
   replay. In a pond, a guest is in full light until step 2. That is acceptable on
   the dev app.
2. **The pond**: files 12 and 13, `Wire.PROTOCOL` 10, and net_probe's checks.

Both are content. Neither moves `binary_version`.

### 10.3 Checks

**drop_probe**, a new `daylight` section:

1. **The curve**:
   - 0 through the night, 1 through the day;
   - continuous at the four joins;
   - a whole cycle's mean is 0.6 within 1e-12;
   - `mean(t0, t1)` agrees with a 10,000-step sum within 1e-6, across a join and
     across midnight;
   - at a room's age, about 1e6 s, within 1e-9.
2. **The column**: 0 on the rim and past it, 1 at the centre, rising inward. The
   light at the rim at noon is exactly 1.0, and at the centre 0.25.
3. **One tank under a moving day**: check 10's three genomes again, with the field's
   day set so dawn runs through the 60 s. The node takes `light_over` from the field
   frame by frame; the water body is paid at its rates. They end within 1e-6.
4. **The drifters in the dark**: every drifter gene at one copy holds its tank at
   light 0.
5. **Off is `dev`, to the byte**: with `daylight` off, the five-minute drop prints
   `DEV_LINES`. With it on, it prints the new `DAYLIGHT_LINES`.
6. **The save**: a drop kept at dusk opens at dusk, to the bit. A file with no
   `"day"` opens at `DAY_BEGINS`. The light's lines make an older file read as
   converted.
7. **The replay**: the recorded light is the field's frame by frame. The replay's
   field answers it. The run's field is untouched.

Check 10 itself hands the node the field's light, which is today's 1.0 with the
switch off.

**net_probe**:

- the wire: the POND header carries the light to 1/65535 and back; `POND_MAX` is
  1,183 and under the MTU; a 9 is refused at HELLO by name;
- `--referee-only`: the rules' text and `Wire.RULES` unchanged;
- the mirror: a guest given a snapshot at light `d` answers `d` × what gets through
  at its place under the host's rim;
- a guest's set-aside drop comes back with its own day, beside the age check it
  already makes.

**gene_probe**: the plastid is a `readout` organ with no channel, and both its new
lines have their French.

**levels_probe**: unchanged. The born cell's fifty-second death holds within two
frames. If it moves, light has leaked into a body with no plastid.

**forage_probe**: run once. Its bot wears no plastid, so only the water's plastid
hunters move. Report what it prints; nothing in it is a pin.

**Renders**: §3.1's four frames and the sun tile, by day and by night, in both views,
at 1280x720 and 2400x1080. A `--seed=` frame rendered three times must differ by 0
pixels first (CLAUDE.md).

**`tools/net_fuzz.gd`**: run its saved corpus. A case written at the 10-byte header
that no longer holds is rewritten at 12, under a note.

### 10.4 Pins that move, and why

- **drop_probe's identity gates keep their lines.** `IDENTITY_LINES`,
  `THREE_ONE_LINES`, `PACK3_LINES` (tails off) and `DEV_MEMBRANE` reproduce an older
  pack. Their runs set `daylight = false` beside the switches they already set.
- **`DEV_LINES` becomes the daylight-off gate.** The new `DAYLIGHT_LINES` pin the
  five-minute drop with it on.
- **The build's own lines move**: `TAIL_LINES` (tails on) and anything else run with the
  light on. Hunters with a plastid starve otherwise, and the random stream follows.
  Each is re-pinned with a dated comment naming this page.
- **CI's "an empty library changes nothing" hash** (`ci.yml`) moves for the same
  reason. Its paragraph says so. With `--daylight=0` the build prints today's
  pinned hash, which is the proof.
- **net_probe's sizes**: `POND_HEADER` 12, `POND_MAX` 1,183, `PROTOCOL` 10.
- **The replay's `STRIDE`**, one more.

### 10.5 What it replaces

- `food.gd`'s `Body.income`, the full-light income: now `absorbs`, plus `sun`
  times the light at each step;
- `normal_mode.gd:1619`'s unlit `photosynthesis`;
- the plastid's two lines, in English and French;
- the POND header of protocol 9.

`metabolism.gd`'s arithmetic is untouched: it already took an income.

---

## 11. What to watch in the playtest

- **Is night noticed** in full vision, without being explained? Is it too dark, or
  too faint? Levers: `NIGHT_GLOW` and `NIGHT_TINT`, the UX/UI designer's.
- **Does the middle read as deep water**, and the edge as the bright shallows?
- **With a plastid, is the light found?** Watch whether the tile's bar and the
  gauge's rate are read, and whether you head for the edge by day.
- **Is the plastid still worth a slot?** Expect it to be clearly weaker: over a
  whole day, anywhere in the drop, about a third of what it makes today. Two and
  three copies pay only by day near the rim (§2.4). Levers: `SUN_BY_TIER`,
  `LIGHT_AT_MIDDLE`, the spans, `NIGHT_LIGHT`.
- **Is the day the right length?** Does a sitting meet a night? Does night drag?
  Levers: the four spans.
- **The edge by day**: more cells there, and the hunters that chase along it
  (ocean.md §3.1). Is the rim a place now?
- **The water at night**: more remains where plastid hunters starve. Is it seen?
- **The shared pond**: both players see one night at the same moment, and both
  tiles agree.
- **A kept drop** opens at morning once after the update, then keeps its own time.
- **The phone**: the readout's `water` and `dropped` rows, against the last build.

Seen and not changed: none yet. When something is, it is recorded here with its
levers, and the numbers keep their starting values (CLAUDE.md, "Balance waits for
players").

---

## 12. Owner's calls

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | What does "deeper" mean in a drop seen from above? | **Toward the drop's middle, where the water is thickest ✓ recommended** · a new up-and-down direction the cell swims in · no depth, only the time of day | With the first, the sun is strongest near the drop's edge and weakest in its middle, so a cell living on sun heads for the edge by day, with nothing new to steer. The second adds a third direction to swim and a control for it. The third lights the whole drop the same, and only day and night change it. |
| 2 | What does night look like in full vision? | **The water's own glow dims where light is low, and turns bluer at night ✓ recommended** · the water dims with the time of day only, the same everywhere · nothing on screen, only the sun tile | With the first, the map shows both the night and where the bright shallows are, and every cell stays as bright as ever. With the second, night shows but the middle looks like the edge. With the third, a player without the sun gene never sees night. |

- **Row 1.** The game has no up and down. The "level" gene that knew which way was
  up was retired because it said nothing about the water. A sinking control would
  be a new pad on a phone. The lens reading uses what the drop already is: a drop
  on a slide whose rim band is already called the shallows and drawn as a thin film.
- **Row 2.** Point of view is the same in all three: the membrane has no map, and
  light on the senses is the owner's later step (§3.2).
- **Not asked, because balance waits for players**: the length of a day, how dark
  night is for the sun, how much the middle loses. Their starting values and
  reasons are in §2, and their levers in §11.
- **Not asked, because it follows**: friends share the host's sky. That moves
  `Wire.PROTOCOL`, so players on the old content and the new cannot share a pond
  until both update (§5). The patch note's line says it, for example: *"The drop
  has days and nights: the sun gene makes food only in daylight, and less toward
  the drop's deep middle. Friends need this update to share a pond."*
