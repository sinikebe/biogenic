# Three senses, and the slot that aims them

Phase 7. The owner asked for three changes in one breath, and they are one
change.

> the radar gene : the wave should bounce back on anything it touches instead of
> going through. Including me. It goes out from me at the point where the organ
> is. Upgrades of the gene may allow a little of go through effect, allowing to
> sense a little bit behind objects but not at the first level of the gene.
>
> smell : it is not a directional sensor. It should only say whether the smell is
> strong or not. Orientation should count. If the smell sensor is facing towards
> nothing, the smell is less than when faced towards food.
>
> beam. Beam should evolve even more, adding beams again and again. We could
> start with a limit of 20 beams per beam organ. Fill the space in between
> current 3 beams with the 20.

All three make **where the organ sits decide what it can do.** The `ampulla`'s
slot decides which half of the water your own body hides. The `chemocyte`'s slot
decides which way you must point to smell. The `ocellus`'s slot aims a fan about
to get twenty times denser. `moving-a-gene.md` shipped the gesture that moves a
gene between slots this morning; this is what gives that gesture something to
be *for*.

Status: **§1 the `ampulla` and §2 the `chemocyte` are built. §3, the beam fan,
is not.** The owner has answered all three rows of §8: smell ships as a level
(row 1, option A), `rhabdom` is retired (row 2, option C), and the twenty-beam
outline is allowed but ships on its own (row 3, option A — **not this build**).
§4 says which line of which file is which; read it before treating any of this
as a description of the game.

Prototyped and photographed at 1280x720 and 2400x1080 under
`--rendering-driver opengl3`. Every number below is measured off a render or off
an instrumented run, and §7 says which. **The smell change is a nerf to the
sense a blind player leans on**; it was put to the owner in §8 and it shipped.

**§7.5's meal table has been re-measured on the built code over 24 seeds and it
does not reproduce.** The direction of every finding holds — the new nose is far
more navigable by level alone than the field it replaces — and the absolute
numbers are worse than the prototype's. §7.5.1 is the re-measurement, and it
raises one number the owner may want back: `SMELL_TAIL`.

---

## 0. The one rule this spec does not break

`normal_mode.gd` is still the only node that talks to the signal bus, and no
position reaches it. Occlusion is computed in `food.gd`, against positions that
die in that file, and what leaves is a bearing and a strength — exactly as
today. The pulse's origin is a `Vector2` that `_cast_ping` makes and spends in
the same function; **as built it is a local and not a field**, which is what the
spec's own code below always did with it. A world position on the field's public
surface is an invitation the invariant does not need, and nothing outside that
function has a use for it.

One simulation, two views: everything here is either a simulation change that
both views read, or a drawing change made twice. The A/B in §7.2 is two runs of
one command differing only in `--mode=`, diffed line for line.

---

## 1. `ampulla` — the baffles

### 1.1 What changes

Today the pulse is cast from the **centre of the cell**, answers for the nearest
five bodies inside reach in every direction, and is drawn as a full ring.

After: the pulse leaves the membrane **at the organ's own arc**, and every body
— including the cell's own — stops it.

```gdscript
# cell.gd, beside PING_RANGE_BY_TIER
## How much of the pulse survives one body, including your own. Tier 1 is a
## hard zero: nothing behind anything. See §1.3 for why the curve is this one.
const PING_THROUGH_BY_TIER: Array[float] = [0.0, 0.0, 0.34, 0.58]
```

```gdscript
# food.gd, written once a frame by the run, like beam_bearings
var ping_bearing := 0.0      ## Cilia.slot_bearing(genome.slot_of(&"ampulla"))
var ping_through := 0.0      ## CellBody.PING_THROUGH_BY_TIER[tier]

## The soft edge on the hull shadow, as a cosine. A hemisphere is a boolean and
## every gate in this file has been taken off that argument (§7.0 of
## genes-and-cilia.md); a ray leaving 6 degrees under the tangent really does
## graze the body and come back weak, so the shadow has a 27-degree soft edge.
const PING_GRAZE := 0.24
## A return below this is not worth one of the five slots: it draws nothing.
const PING_SILENT := 0.03
```

`_cast_ping` gains two terms and one loop:

```gdscript
var dir := _cell.forward() * cos(ping_bearing) + _cell.starboard() * sin(ping_bearing)
var origin := _cell.position + dir * _cell.radius

# The hull: an emitter on the skin sees the hemisphere it faces and no more.
var open := smoothstep(-PING_GRAZE, PING_GRAZE, (b.pos - origin).normalized().dot(dir))
level *= ping_through + (1.0 - ping_through) * open

# Everything nearer is in the way, by how centrally the path crosses it.
for j in i:                       # found is sorted nearest-first
    ...perp = distance from body j's centre to the segment origin -> body i...
    var clear := clampf(perp / body_j.radius, 0.0, 1.0)
    level *= ping_through + (1.0 - ping_through) * clear
```

The `PING_RETURNS` cap of five is now applied **after** occlusion — returns
silenced by a shadow do not consume a slot. That is the whole of the
compensation, and §7.3 shows it is enough.

### 1.2 Why a hemisphere, and why that is a *mechanic* and not a tax

A point source sitting on the surface of a body radiates into exactly half the
plane; the rest of the directions go into the body. That is not a chosen number,
it is the geometry of mounting a transducer on a hull — and it is why a
submarine has **baffles**, a permanent blind arc astern of a bow sonar, and why
clearing them is done by *turning the boat*.

Biogenic's only verb is turning. So the realism hands over a mechanic the game
can already express, with a counter the player already owns and no new control:

> **Your radar is blind behind your own body, and the way to see behind you is
> to turn.**

A blind arc that can be cleared is not a nerf; it is the first thing in this
game that makes *heading* matter while standing still. Before this, turning was
only ever about where you were going.

### 1.3 Penetration, and why this curve

`PING_THROUGH_BY_TIER = [0.0, 0.0, 0.34, 0.58]`, applied **once per body in the
way, multiplying**, so a return two bodies deep at tier 3 comes back at
0.58 x 0.58 = 0.34 and three deep at 0.20.

Three candidate shapes were considered and two rejected (§9):

- **A fraction of range past the first hit.** Rejected: it needs per-bearing
  marching, it is expensive, and "how far past" is not a thing the membrane can
  say. The membrane has intensity, and intensity is what a dimmer echo is.
- **A limit on how many bodies deep.** Rejected: a count is a step, the player
  cannot count bodies, and it reintroduces exactly the boolean this file spent
  §7.0 removing.
- **A dimmer return, compounding per body.** Chosen. It is the shape the physics
  has — each interface takes a bite — it is continuous, and it needs no rule for
  "how deep": four bodies deep at tier 3 is `0.58^4 = 0.11` of an echo the range
  has already faded, which is a mark nobody reads.

  **It does not silence itself, and the spec used to say it did.** 0.11 is not
  under `PING_SILENT`'s 0.03 — it only crosses it once the range term has fallen
  below 0.265, which at `PING_FALLOFF` 0.6 means a body past 89% of the reach.
  What keeps the fourth rank off the membrane is the cap: `PING_RETURNS` is five
  and the loop stops at five *audible* returns, so a fifth body four deep is
  competing for a slot with four nearer ones that are louder. `cell.gd`'s note
  beside the constant states this arithmetic correctly and claims nothing more
  than "a mark nobody reads"; this bullet now agrees with it.

**It resolves the ambiguity it creates, and in a channel that already exists.**
A shadowed near body and a clear far body both read as *faint*. But returns are
staggered by their own flight time (`d / PING_SPEED`), so the shadowed near body
still answers **early**: an early faint mark is something close and hidden, a
late faint mark is something far. That cue is free, it is the sweep the ping was
already built to read as, and it is the reason this curve rather than one that
throws distance away.

Self-occlusion penetrates at the same rate, so a tier-1 `ampulla` is stone blind
astern of its organ and a tier-3 one hears through its own body at 0.58 — never
quite as well as around it. That is the right direction for a build that has
spent three tiers on one gene.

**It does not *soften* with investment, though: it goes.** This spec claimed a
blind arc that narrowed tier by tier, and the build does not do that and never
did. Measured on the shipped code, at tier 2 and at tier 3 the pings arrive at
the *same times* and the *same bearings* as with no occlusion at all,
bin-for-bin and bearing-for-bearing; only the strength moves (§7.3.1). At 0.34
and at 0.58 per occluder nothing in the nearest five ever falls under
`PING_SILENT`, so the first upgrade buys the whole circle back at once and pays
for it in loudness. The blind arc is a **tier-1 mechanic**: stone blind behind
your own body until the first upgrade, and after it a quieter answer from the
half you are not pointed at. Whether that is the right ladder is an owner
question and `PING_THROUGH_BY_TIER` is not moved here.

### 1.4 What is drawn

A drawing change in both views, and it is the thing that teaches the mechanic
with no text at all.

**Point of view** (`returns.gd`) and **full vision** (`vision.gd`): the
wavefront is no longer a circle centred on the cell. It is a **half-ring centred
on the organ's point on the membrane**, spanning `ping_bearing +- 90 degrees`.
Where `ping_through > 0` the other half is drawn too, at `alpha x ping_through`.

- Centre: `cell.position + dir * cell.radius` (world) /
  `centre + _ray(ping_bearing) * cell.radius * SCALE` (point of view).
- `draw_arc(origin, front, mid - PI/2, mid + PI/2, 64, ...)`, 64 segments rather
  than 96 — it is half the arc.
- Point of view keeps its per-vertex alpha and `_edge_fade`, so the arc still
  dissolves into the band instead of clipping at a rectangle.
- **The far half is inset half an angle step at both ends.** Drawn flush the two
  arcs share a vertex at each seam, a shared vertex is composited twice, and the
  join came out brighter than either half of the ring it joins: measured at
  tier 3, plateaus of 257 and 150 summed sRGB above base meeting in a bead of
  **407** in point of view, and a ring maximum of 342 against a 254 plateau in
  full vision. With the inset the brightest pixel on the ring is on the lit
  plateau where it belongs — 263 and 254. The cost is a notch of half a step at
  each seam: 5 canvas px on the r212 ring that was measured, growing with the
  ring because it is an angle, and about 10 px by the radius at which the arc is
  fading into the band anyway. Rendered at both shapes and at three radii, it
  reads as the boundary between the loud half and the quiet one, not as a break.

In point of view the arc's centre lands **on the violet tuft the soma figure
already draws for the `ampulla`** — the organ and the wave leaving it are the
same place on screen, for free, because both are read off the same arc. *On*,
not exactly on: the wave leaves a circle of `cell.radius` and the figure is an
ovoid (`OVOID_ALONG` 1.18 against `OVOID_ACROSS` 0.94), so the two agree to
1.3 canvas px on the forward diagonals and part by 8 px at the nose and astern,
where the origin sits that far inside the drawn rim.

Measured on the tier-3 render (§7.3): the lit half of the ring reads 232 above
base in summed sRGB and the penetrated half reads 135, a ratio of **0.58** — the
constant, drawn.

**The ratio is the number seen twice; the edge is not.** `PING_GRAZE` gives the
hull shadow a 27.8-degree fade — `acos(-0.24)` is 103.9 degrees — and
`PING_SILENT` cuts what is left of it at about 101, so at tier 1 the simulation
still answers for a body ten degrees behind the tangent while the drawn arc has
stopped dead at 90. The arc is where the pulse is *loud*, not where it is *zero*. Softening
it to match would mean a per-vertex fade in both views, and `vision.gd` draws
the world arc with `draw_arc`, which takes one colour — so it is a change to two
files and to this section, not a constant. Left as it is, and said here rather
than claimed away.

**The replay pays one dictionary key for this**, and it is not the one this spec
predicted. Both panes draw the arc off `ping_bearing` and `ping_through`, and
`recorder.gd` carries neither — `replay.gd` derives them from the restored
genome, `Cilia.slot_bearing(genome.slot_of(&"ampulla"))` and the cell's own
tier, the same two calls a live run makes. But `slot_of` reads the **body's**
layout, and that layout was being rebuilt at playback from the **DNA's** order,
which `move()` deliberately parts from it. Measured on a run with the `ampulla`
worn at slot 3 and moved in the DNA to slot 5: live, the wave leaves at +42.09
degrees; replayed, at +133.27 — and `soma.gd` drew the tuft on the same wrong
arc, because it reads `body_layout()` too. The PLAYER delta now carries the
body's layout beside the DNA's. It is a dictionary, so `STRIDE` still does not
move for the `ampulla`, and both bearings now read +42.09 (§7.3.2).

---

## 2. `chemocyte` — a level, and a nose that points

### 2.1 What changes

Taste stops being a bearing. `taste_level` becomes a scalar weighted by how
nearly each source lies along the organ's own facing:

```gdscript
# food.gd _step_sense, inside the smell_range branch
var lobe := 0.5 + 0.5 * cos(angle_difference(smell_bearing, _cell.bearing_to(b.pos)))
var w := c * (smell_floor + (1.0 - smell_floor) * lobe)   # accumulated below
```

```gdscript
# food.gd -- moved here from signal_bus.gd when `rhabdom` was retired. §8.2.
## What a receptor pointed dead away still picks up. The whole of "orientation
## counts", and §2.3 is why it is not zero.
const SMELL_BEHIND := 0.22
```

As built there is no tier table under it: `smell_floor` **is** `SMELL_BEHIND`,
0.22 at every tier, because the gene that was going to scale it is retired
(§8.1). What a `chemocyte` tier buys is reach and only reach.

`taste_bearing` still exists and is still posted, but it is now
`Cilia.slot_bearing(genome.slot_of(&"chemocyte"))` — **where the nose is on this
body**. It is the same number every frame of a run and it carries nothing about
the water. The bus signature does not change, no uniform is added, and
`normal_mode.gd` stays the only node that talks to the bus.

A cosine rather than a cone with a tier-scaled width: a cone needs a second tier
table, and `genes-and-cilia.md` §11.1 already decided that `chemocyte` buys
reach and `rhabdom` buys sharpness. Measured, the cone's extra parameter buys
almost nothing anyway — §7.4.

**And the sum has to stop being a plain sum.** This is not part of the owner's
request; it is what §7.5 measured as the difference between a sense that works
and one that does not. The nose reports **the loudest thing it can smell, plus a
tail of everything else**:

```gdscript
## How much of everything-but-the-loudest reaches the readout. Not a taste
## number -- 0.0 and 0.22 were both measured and 0.22 is nearly three times
## better at finding food. §7.5.
const SMELL_TAIL := 0.22
...
taste_level = minf(smelt_top + SMELL_TAIL * smelt_rest, 1.0)
```

Thirteen to nineteen sources inside a tier-1 reach sum to something that barely
moves with position or facing and clamps at 1.0 for much of a run. A gradient
the player is asked to follow has to exist, and with a plain sum it does not.

### 2.2 The readout: a ring, not a lobe

The membrane's vocabulary is bearing and intensity, so an intensity with no
bearing needs a shape the shader can draw and a player cannot mistake for a
direction. It is one lobe, in the slot it already has, with its `z` pushed past
-1 so the smoothstep never closes:

```gdscript
_glow_lobes[LOBE_NUTRIENT] = Vector4(
    sin(_taste_bearing), -cos(_taste_bearing), _ring_z, intensity)

## Solved once, at construction, and not once a frame: with `rhabdom` retired
## the floor does not vary by tier, so this is a single number. A member rather
## than a `const` because a `const` cannot call a function, and solved rather
## than written down so the ring and the floor cannot drift apart.
var _ring_z := _ring_edge(SMELL_RING_FLOOR)

## The lobe `z` for which the shader's `smoothstep(z, 1.0, dot)` equals [param
## ratio] at `dot = -1`. Newton on 3t^2 - 2t^3, then z = (t + 1) / (t - 1).
static func _ring_edge(ratio: float) -> float:
    var t := clampf(ratio, 0.001, 0.999)
    var x := 0.5
    for _i in 12:
        var f := 3.0 * x * x - 2.0 * x * x * x - t
        var d := 6.0 * x - 6.0 * x * x
        if absf(d) < 1e-5:
            break
        x = clampf(x - f / d, 0.001, 0.999)
    return (x + 1.0) / (x - 1.0)
```

`_ring_edge(ratio)` returns the `z` for which the shader's
`smoothstep(z, 1.0, dot)` equals `ratio` at `dot = -1` — i.e. the `z` that makes
the ring's dimmest point sit at the same fraction of its brightest that the
*simulation's* floor sits at. `0.22 -> z = -1.87`. (The tier table that would
have given `0.088 -> z = -1.45` went with `rhabdom`; §8.1.) Verified on the
built code: `tools/drive.gd`'s trace prints the shader's own
`smoothstep(z, 1, -1)` and it comes back at **0.22**.

> **The shape on the skin is the organ's own directivity pattern.** The player
> is looking at the sensitivity curve the maths is using. It is a full ring,
> brightest where the nose is, dimmest dead astern of it, and it never goes out.

Three properties it buys, in order of importance:

1. **It cannot be read as a bearing to food**, because it does not move when the
   water does. It is welded to the body.
2. **It still has an edge**, so the eye has something to catch a change against.
   A perfectly uniform ring is a brightness with no contrast, and a
   dark-adapted eye is bad at absolute brightness and good at contrast — that
   was the objection that killed the uniform ring (§9).
3. **Its bright side teaches where the organ is**, which is the theme of the
   whole spec, on a surface that has no room for a diagram.

And the one misreading it permits is not wrong: a player with the nose in slot 0
sees the top brighten when food is ahead, and *"turn until the top is bright"*
is still the correct play.

**No jitter and no lag.** `TASTE_JITTER_*` and `TASTE_BEARING_TAU` were vagueness
on a bearing, and there is no bearing left to be vague about. Vagueness now
lives in the level's own flatness (§7.4), which is a truer place for it. Delete
`_taste_jitter`, `_taste_jitter_clock` and `_taste_bearing_lp`'s low-pass — and
note that this removes one of the **two** draws from the signal bus's private
RNG. `perception.md` §4.1's warning is unchanged: the beat jitter remains, so
`--seed=` is still mandatory for any comparison.

### 2.3 The brightness curve has to change, and that is measured

The old curve was `smoothstep(TASTE_FLOOR, 1.0, c) * TASTE_PEAK`. It is savage at
the bottom — a reading of 0.124 becomes an intensity of 0.013 — because it was
designed for a channel whose job was *is there anything at all*, with the
bearing carrying the rest. There is no bearing now, so the level must spend the
whole of `TASTE_PEAK` over the levels a forager actually sees.

Instrumented over 3 seeds x 3 times (§7.4), the shipped nose's level lives in
**0.046 .. 0.784** — a whole band lower than the summed field it replaces, and
straddling today's floor. Both ends of the curve move:

```gdscript
const TASTE_FLOOR := 0.02   # was 0.06 -- scent(680), a number from the old sum
const TASTE_FULL  := 0.45   # where it saturates: a cell already on the food
const TASTE_CURVE := 0.8
const TASTE_FADE  := 0.02

var intensity := pow(clampf((c - TASTE_FLOOR) / (TASTE_FULL - TASTE_FLOOR), 0.0, 1.0), TASTE_CURVE)
    * TASTE_PEAK
    * smoothstep(TASTE_FLOOR, TASTE_FLOOR + TASTE_FADE, c)   # still fades on, never pops
    * (1.0 - TASTE_DREAD_SUPPRESS * dread)
```

`TASTE_PEAK` stays at 0.62. Measured on the render, the opening band's peak green
channel goes from **66 today to 77** — brighter than today, on a sense that has
just lost its bearing.

**Re-measured on the build**, one frame each from the tree at `40df405` and from
this one, same seed, same posed body, same freeze: peak green on the band goes
**74 -> 86**, and the mean green over the whole band **15.1 -> 18.6**. Different
absolute numbers from the prototype's pair and the same direction and roughly
the same size of step. The claim that holds is the one that matters: the sense
that lost its bearing did not get dimmer.

`TASTE_FULL` pins the top deliberately: above 0.45 the cell is inside
`CORE_RANGE` of something edible and about to eat it, and a readout that keeps
climbing while the mouth is closing is spending range on a decision that has
already been made.

**`SMELL_BEHIND` is 0.22 and not lower for one reason: the band must never go
out.** At 0.22 the dimmest facing in every instrumented sample stays above
`TASTE_FLOOR`. At 0.10 a cell facing away from everything drops through the
floor and the band disappears, which reads as *the gene has stopped working*
rather than as *you are facing the wrong way*. Dimming is information; darkness
is a bug report.

### 2.4 `rhabdom` is retired, and this is what was rejected to get there

`FOCUS_BY_TIER` multiplied the taste lobe's **width** and its **bearing jitter**.
Both are gone. Left alone, `rhabdom` becomes a gene that does nothing — in the
drop table, on the strand, in the gene lines, with a shipped sentence promising
an effect it no longer has.

This section used to propose moving it to the floor, and the arithmetic still
holds: `smell_floor = SMELL_BEHIND * FOCUS_BY_TIER[tier]` generates
`0.220 / 0.163 / 0.123 / 0.088`, and §7.4 measured that as the only re-aiming
that buys anything — sharpening the cosine moved the swing by under 2%, while
lowering the floor moved the contrast ratio from 1.63x to 1.92x at the opening
and 2.00x to 2.52x at t=25s. `rhabdom` would have **traded coverage for
contrast**: a focused nose reads less of the water but tells you more clearly
which way it is.

**The owner took option C instead: retire it** (§8 row 2). The measurement above
is why that is defensible rather than lazy. What the re-aimed gene bought was a
*ratio* — the ring's bright side against its dim side — on a readout the player
is already reading as a single brightness that rises and falls. It is the one
kind of improvement this membrane is worst at showing: `perception.md` §3's own
argument is that a dark-adapted eye is poor at absolute brightness and good at
edges, and `rhabdom` would have moved an edge that is already there by half a
stop. A gene whose whole effect is a number nobody can see move is worse than
one fewer gene in the water.

§8.1 is what retiring it actually touched, and what a genome that still names it
does.

### 2.5 What blind play is after this

Today: a band appears at a bearing, you turn until it is at the top, you swim.
One decision, then commit.

After: a band is lit at some level, you turn, you watch it brighten or dim, you
commit to the direction that brightened. That is a **gradient sweep** — run and
tumble, which is what chemotaxis is — and it is slower.

Measured, it costs a median 26 s to a median 73 s on the first meal (§7.5).
Four things keep it survivable, and the last two are new:

1. **The beat is unchanged and still innate.** It reads `concentration`, which is
   what the *water* is like, with no facing and no gene. So a player has two
   instruments: rhythm says *am I in a rich patch*, band says *am I pointed at
   it*. A coarse always-on altimeter and a fine directional one. That pairing
   already exists and this change is what finally gives the second one a job.
2. **The sweep is not extra work.** Turning is the only verb; the player is
   already doing it. The band answering a turn they were making anyway is
   feedback, not a new chore. A 180-degree sweep costs 6.1s at tier-1 `cirrus`
   (0.62 rad/s, 1.10s to build) and 3.1s at tier 3 — and the cell keeps moving
   through it, so the sweep is a spiral, which is what a real chemotactic track
   looks like.
3. **The loudest-source nose** (§2.1). Without it the level has no gradient at
   all and the sweep is a coin toss — measured, and it is the reason that
   constant is in this spec at all.
4. **The opening band is brighter than today's** (§2.3): peak green 77 against
   66, measured on the render. That is the compensating
   change, and it is not a fudge: it falls straight out of giving the level
   channel the whole range, now that it is the only channel.

**Where it is genuinely worse, and it should be said plainly.** The first meal
takes about three times as long and one run in eight does not get one inside
ninety seconds. `HUNGER_SECONDS` is 420 with a 40-second grace, so nobody dies
of it — but the opening minute stops being safe, and a player who is unlucky
twice in a row will feel it. On top of that, when the food around you is evenly
spread the swing narrows: worst measured 1.41x on the shipped nose, and in that
case the sense is saying *there is food and no direction is much better*, which
is true and is also indistinguishable from *my sense is broken*. The honest
summary is that smell becomes **reliable about how much and slower about
where**. That was the owner's call in §8 and the answer was ship it.

---

## 3. `ocellus` — twenty rays

### 3.1 The ladder

The fan does **not** widen. The owner's words are *fill the space in between*,
so `BEAM_FAN_DEG_BY_TIER` stays `[0.0, 0.0, 22.0, 50.0]` and only the count
moves:

```gdscript
const BEAM_COUNT_BY_TIER: Array[int] = [0, 1, 5, 20]
```

Twenty is a **tier-3 number inside one organ**, not a second axis, because the
owner said *per beam organ* and because a genome is a `{gene: tier}` map — the
same gene cannot occupy two slots, and making it able to is the slot-keyed
refactor `cell.gd` already declined. Three rungs is all the ladder has, so
"again and again" is bought by the size of the steps: x5, then x4.

What each tier is, stated as the range at which the fan stops missing things.
A body of radius R at distance d subtends about `2R/d`; a fan of spacing `s`
catches it reliably while `2R/d > s`:

| tier | rays | span | spacing | reliable on an r26 body to | at full reach |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | — | — | only what it is pointed at | a pointer |
| 2 | 5 | 44 deg | 11.0 deg | **271 units** | p = 0.30 at 900 |
| 3 | 20 | 100 deg | 5.26 deg | **566 units** | p = 0.46 at 1240 |

Tier 2's 271 units is not an arbitrary landing: it is *contact range*. A body you
are about to eat or be eaten by is inside it, so tier 2 is the tier at which the
beam stops being a lottery about the thing that is about to matter. Tier 3 buys
**near-field shape** and explicitly does not buy far-field coverage — at 1240
units a body is still a coin flip, which is honest and keeps the gene from
becoming vision at range.

### 3.2 Twenty rays are a shape, and that is the line this crosses

`perception.md` §4 forbids the interior encoding *position, distance, shape,
count or identity*. `genes-and-cilia.md` §2.3 already carries an owner override
for **position**, for exactly these two senses, on the argument that a stopped
beam has genuinely measured where a surface is.

Twenty beams have measured twenty places, and twenty places along a body's near
edge is a **silhouette**. That is a shape, and the override has to be widened to
cover it. It should be, and the argument is already written down — `perception.md`
§4 said:

> The gene after that is what buys the interior: a signal drawn *inside* the
> contour, at a place. That is the first true image, and it should feel enormous
> because the interior has been black for hours.

**A tier-3 `ocellus` is that gene.** It costs three tiers in one slot, it is
aimed by where that slot is, and what it draws is still only points a ray
actually touched. The boundary in §2.3 is unchanged in every other respect: no
bodies, no silhouettes *drawn as outlines*, no scent bloom, no identity. An arc
of dots is not a drawn body; it is twenty returns that happen to be adjacent.

### 3.3 The recorder's frame gets bigger — named, not solved

`recorder.gd` stores beams as exactly `BEAMS = 3` x `BEAM_FLOATS = 3`
(bearing, distance, hit) inside a fixed `STRIDE`, and `_lerp_frame` steps the
hit flag over the same `BEAMS`. Twenty rays move it:

| | today | at 20 rays |
| --- | --- | --- |
| beam floats per frame | 9 | 60 |
| `STRIDE` | 296 | **347** (+17%) |
| bytes per frame | 1184 | 1388 |
| rate | 69 KB/s | **81 KB/s** |
| 60-second window | 4.1 MB | **4.8 MB** |

Nothing here is a compatibility problem: the ring is allocated once, lives in
RAM and is never serialised, so there is no old recording to read. It is 0.7 MB
of extra resident memory on a phone, and the knob is `SECONDS`. Whoever builds
this owns the decision; it is not made here.

### 3.4 Cost, also named

`_step_beams` is `rays x bodies` ray-circle tests every frame: 3 x 34 = 102
today, **20 x 34 = 680** at tier 3, in GDScript, at 60 fps. (The header comment
saying "sixteen at the very worst, which is four bodies by four beams" has been
wrong since `COUNT` became 34 and should be corrected in the same change.) The
obvious mitigation is one dot product per body against the fan's angular bounds
before entering the ray loop, which rejects most of the water for a 100-degree
fan. Measure it on a low-end Android before shipping; it is not measured here
because this container is not that phone.

---

## 4. What the game developer changes

> ## TWO THIRDS OF THIS TABLE IS IN `main`. ONE THIRD IS NOT.
>
> **Built and shipped: the `ampulla` (§1) and the `chemocyte` (§2).** **Not
> built: the `ocellus` (§3)** — the owner allowed it (§8 row 3) and it ships on
> its own, because twenty rays rewrite `food.gd`'s beam loop, `cell.gd`'s tier
> table, `cilia.gd` and the recorder's stride, and three of those four are files
> the smell change has just moved. `recorder.gd` is unchanged by §2: the replay
> captures a whole `Vector4` per glow lobe, so a ring costs it nothing and
> `BLOCK_FLOATS` stays at 37.

| file | change | state |
| --- | --- | --- |
| `game/normal/cell.gd` | new `PING_THROUGH_BY_TIER` | **shipped** |
| `game/normal/cell.gd` | the `rhabdom` note beside `VENOM_COST_BY_TIER` records the retirement | **shipped** |
| `game/normal/cell.gd` | `BEAM_COUNT_BY_TIER = [0,1,5,20]` | **not built** — §8 row 3 |
| `game/normal/food.gd` | `ping_bearing` / `ping_through`; `PING_GRAZE`, `PING_SILENT`; occlusion in `_cast_ping`, cap applied after it | **shipped** |
| `game/normal/food.gd` | `SMELL_BEHIND` and `SMELL_TAIL`; the cosine weight and the loudest-plus-tail level in `_step_sense`; `smell_bearing` in, `taste_bearing` and `smelt_pull` gone | **shipped** |
| `game/normal/food.gd` | `rhabdom` out of `GENE_WEIGHTS` and `DRIFTER_GENES` | **shipped** |
| `game/normal/genome.gd` | `rhabdom` out of `GENE_ORDER`, which is also what `_mutate_drift` draws from | **shipped** |
| `game/normal/normal_mode.gd` | write `ping_bearing` and `ping_through` from `slot_of` + tier | **shipped** |
| `game/normal/normal_mode.gd` | write `smell_bearing`; post the organ's arc to `taste()`; `rhabdom` out of `sense_organs`, `WORDS` and `EXPLAINS`; the `chemocyte` line rewritten | **shipped** |
| `game/perception/signal_bus.gd` | `SMELL_RING_FLOOR`, `TASTE_FULL`, `TASTE_CURVE`, `TASTE_FADE`, `TASTE_FLOOR` 0.06 -> 0.02, `_ring_edge()`; taste lobe becomes a ring; taste jitter and bearing low-pass deleted; `FOCUS_BY_TIER`, `SENSE_RHABDOM` and the fifth `_senses` slot gone | **shipped** |
| `game/vision/cilia.gd` | `rhabdom` out of `HUES` and `EARNED_COUNT` | **shipped** |
| `game/perception/returns.gd` | wave becomes an arc from the organ, `_wave_arc()` helper | **shipped** |
| `game/vision/vision.gd` | the same arc in world space | **shipped** |
| `game/replay/recorder.gd` | the PLAYER delta carries the body's layout (§1.4) | **shipped** |
| `game/replay/recorder.gd` | `BEAMS` 3 -> 20, and the `STRIDE` arithmetic in §3.3 | **not built** — §8 row 3 |
| `tools/drive.gd` | `--forage` replaced by `--sniff` (§7.7); the trace line carries the taste ring and the raw level | **shipped** |

No shader change. No new uniform. No `class_name`. Nothing outside `game/`.
It ships as a content pack.

---

## 5. Both targets

Nothing here adds a widget, so the 48px rule does not bite. The three changes
land entirely on the sensory screen, which has no controls on it.

- **Reflow.** The ring and the wave arc are both drawn in the aspect-corrected
  bearing space the shader already uses and at `soma.gd`'s SCALE respectively,
  so at 2400x1080 the canvas widens to 1600x720 and both simply get wider. The
  arc's `_edge_fade` reads off the live rect. Verified at both sizes in §7.
- **Touch.** The sweep is a drag, which is the control that already ships; the
  ring is read, not touched.
- **The one real risk** is the same one `perception.md` §3 named: dim greens on a
  phone in daylight. The taste ring is *dimmer per pixel than today's lobe was
  at its centre* in the mid-run cases, because the same light is spread round
  the whole contour. `gain` is the escape hatch and it is already exposed.

---

## 6. What this breaks in the shipped documents

- `perception.md` §3's signal table: the `nutrient taste` row's half-width,
  jitter and bearing low-pass all go. Replace with *ring, `z` from
  `smell_floor`, no jitter, no lag*.
- `perception.md` §4: the *shape* prohibition needs the same owner override the
  *position* one already has, scoped to a tier-3 `ocellus` (§3.2).
- `perception.md` §4.1: still true and still binding; one of the two RNG draws
  goes away, the beat's does not.
- `genes-and-cilia.md` §11.1: *"Sharpness is deliberately left alone: `rhabdom`
  already owns the taste lobe's width and jitter"* — there is no width and no
  jitter, and `rhabdom` is retired (§8 row 2). Corrected in that file.
- `gene-lines-and-the-pause-target.md` §1: eighteen lines become seventeen, and
  the `chemocyte` line changes from *smells food, and which way it is* to
  *smells food, strongest where your nose is pointed*. Corrected there.
- `choosing.md` §12's fifth open risk — *`rhabdom` and `cytostome` are the
  tightest pair on the hue wheel* — is closed by the retirement rather than
  answered. Corrected there.
- `genes-and-cilia.md` §11.2: *"a bearing for every body it comes back off"* is
  now *every body it comes back off that is not in a shadow*.
- `edibility.md`: untouched. Nothing here changes what can eat what.
- `moving-a-gene.md` §5.1 said the move surface deliberately does not teach why
  a slot matters, because *"a player who has not yet met a directional gene has
  nothing to aim"*. After this, three of the five sensing genes are directional
  and the fourth, `rhabdom`, modifies one. That argument is weaker than it was
  and is worth revisiting — but not here.

---

## 7. What was measured, and on what

Every number here comes from a render or an instrumented run with `--seed=`
passed, on the prototype described in §4. `tools/drive.gd` grew two temporary
instruments for it — `--scan-at=` (sweep a hypothetical organ facing through 360
degrees against the live water and report what each sense would read) and
`--sniff` (a run-and-tumble forager, §7.5). Neither is part of the deliverable.

### 7.1 Reproducibility, first, because CLAUDE.md says so

Three renders of

```
--seed=4242 --mode=0 --genome=cytostome:1,cirrus:1,flagellum:1,ampulla:1,chemocyte:1 \
--cell=1,900,-35,26 --freeze-at=3.34 --fixed-fps 60
```

produced three byte-identical PNGs (`md5 69944c27...`, 0 differing pixels of
921,600) on the prototype build. Every A/B below is therefore a measurement and
not weather. `perception.md` §4.1 is the reason this paragraph exists.

### 7.2 One simulation, two views

The same command run at `--mode=0` and `--mode=1` over 20 seconds with a
six-gene genome: **0 divergent lines of 180 sensations.** The occlusion, the
orientation weight and the twenty rays are all simulation, and both views read
the same numbers.

### 7.3 The `ampulla`

Instrumented over 3 seeds x 40 seconds of foraging, counting the returns that
actually reached the bus:

| | returns in 40s | share arriving from behind the organ | mean strength |
| --- | --- | --- | --- |
| today, tier 1 | 65 | **40%** | 0.647 |
| occluded, tier 1 | 65 | **8%** | 0.516 |
| today, tier 3 | 150 | 48% | 0.817 |
| occluded, tier 3 | 150 | **45%** | 0.660 |

Three things fall out and only the first was expected.

1. **The count does not change.** `PING_RETURNS` is 5 and a tier-1 reach holds
   13-19 bodies, so there are still five survivors in the lit half almost
   always. The cap was already discarding more than the shadow does; occlusion
   changes *which* five you hear, not how many — and five marks spread over 180
   degrees are more resolvable than five over 360.
2. **Tier 1 becomes a forward-looking instrument and tier 3 buys the circle
   back**: 40% -> 8% behind at tier 1, 48% -> 45% at tier 3. That is exactly the
   owner's *"not at the first level of the gene"*, measured.
3. **Marks are about 20% dimmer on average** at both tiers, which is the price.

The residual 8% at tier 1 is not a leak: an echo's bearing is taken when it
lands, not when it left, so a cell that turned during the flight really does
hear its own pulse from a bearing it is no longer pointed at. That is correct
and should not be fixed.

**Drawn, at tier 3:** the lit half of the ring measures 232 above base in summed
sRGB and the penetrated half 135 — a ratio of **0.58**, which is
`PING_THROUGH_BY_TIER[3]` exactly. The picture and the simulation are one
number.

#### 7.3.1 Measured three times. The invariants hold; the absolutes do not.

The table above is the prototype's. It has since been measured twice more — once
on the shipped build, once independently by review — and **the three runs agree
on every structural claim and disagree on every absolute.** The structure is
what this section now leads with, because that is what reproduced.

| invariant | prototype | build | third run |
| --- | --- | --- | --- |
| tier-1 returns in 40 s, per seed | 65 | 65 | **65** |
| tier-3 returns in 40 s, per seed | 150 | 144 (143 on one seed) | **145 (144 on one seed)** |
| tier-1 bins collapse into the first four | — | `[65,50,63,17,0,0]` | **`[66,69,47,13,0,0]`** |
| drawn ratio, penetrated half to lit | 0.58 | 0.581 | **0.584** |

**The count is arithmetic, not water.** Forty seconds at a 3.2-second period is
13 pulses, `PING_RETURNS` is 5, and 13 x 5 = 65; at tier 3 it is 29 x 5 = 145.
The cap is full every time. That is the whole finding about cost: occlusion
changes *which* five bodies answer and never *how many*, because the cap was
already discarding more than the shadow does.

**The absolutes, all three, rather than the best one:**

| | build | review | third run |
| --- | --- | --- | --- |
| tier 1, behind the organ, before -> after | 41.0% -> 8.7% | 32.3% -> 10.3% | — -> **6.7%** |
| tier 1, mean strength | 0.645 -> 0.500 (−22.5%) | −20.5% | -> **0.544** |
| tier 3, mean strength | 0.817 -> 0.651 (−20.3%) | −13.6% | -> **0.714** |
| tier 3, behind the organ, after | 46.4% | — | **30.0%** |

Those are three different numbers for one quantity and the spread is not noise
between seeds — each column is already 3 seeds x 40 s. **The share arriving from
behind the organ is a fact about where the bodies are**, the water is seeded
around the player's own radius, and neither of the first two runs wrote down the
`--radius=` it used. So the command is written down here instead:

```
xvfb-run -a -s "-screen 0 1280x720x24" ~/godot/godot --path . \
  --rendering-driver opengl3 --fixed-fps 60 --quit-after 2500 \
  res://tools/drive.tscn -- --size=1280x720 --seed=<4242|77|1009> --radius=30 \
  --genome=cytostome:1,cirrus:1,flagellum:1,ampulla:<1|3>:3
```

Count the `[drive] ... ping` lines with a timestamp under 40, bin them by
`angle_difference(bearing, +42.09)` — slot 3's arc — and the third column comes
back. The `today` half of each row needs the tree at `1231dd3`, before occlusion
existed; the third run measured only the occluded side and the two earlier runs
are the source for the baselines.

**Tier 3's blind arc does not narrow. It is gone — and so is tier 2's.** On the
build, occlusion at tier 3 changes *nothing* about which five bodies answer —
the same returns arrive at the same times and the same bearings, about 20%
quieter. The review's run found the same at **tier 2**, bin-for-bin and
bearing-for-bearing, with only the strength moved. The third run agrees from the
other side: its tier-3 bins are `[130, 121, 53, 67, 33, 30]`, with 30 returns in
the 150-180 bin, which is directly astern of the organ. At 0.34 and at 0.58 per occluder nothing in the
nearest five ever falls under `PING_SILENT`, so the first upgrade buys the whole
circle back at once. §1.3 used to call this a blind arc that softens with
investment; it is a tier-1 mechanic that the first upgrade removes, and the
ladder is an owner question rather than a number to quietly move.

**Tier 1's residual is the flight-time effect §7.3 names**, and the bin shape is
the proof: binned by offset from the organ in 30-degree steps, the 195 tier-1
returns go from `[43, 32, 40, 36, 18, 26]` unoccluded to `[65, 50, 63, 17, 0, 0]`
on the build and `[66, 69, 47, 13, 0, 0]` on the third run. Every survivor past
90 degrees is in the 90-120 bin — a return that left inside the lit half and
landed after the cell had turned under it.

**Past 120 degrees is not quite nothing.** Two of the three runs saw zero
returns there in 195; the review saw **one**, at 127.8 degrees, at strength 0.06
— a mark at the bottom of the scale, about a fifth of a typical return. So: from
120 degrees or further, roughly one return in two hundred, and faint. Not *none*,
which is what this section said before and could not support.

**Drawn, re-measured:** on a tier-3 frame whose ring is clear of the edge fade,
the lit half's peak above base is 258 in summed sRGB and the penetrated half's
150 — **0.581**; on the third run's frame, 257 and 150 — **0.584**. The absolute
pair moves with the frame, because the wave fades with how much of its reach it
has spent; the ratio is the constant and does not. Three renders of each command
were byte-identical, 0 differing pixels of 921,600, so both are measurements.

**What it costs.** `_cast_ping` fires once a pulse, not once a frame.
Instrumented over 60 s: occlusion adds a mean **23 µs** per pulse at tier 1 (max
32) and **20 µs** at tier 3 (max 46), against 41 µs and 78 µs for the gather and
sort that were there before. Amortised at 60 fps that is **+0.12 µs a frame** at
tier 1 and **+0.24 µs** at tier 3, and the worst single frame measured spends
46 µs, which is 0.3% of one. The cap is what keeps it there: the loop stops at
five audible returns, so the inner test runs about ten times and not 34 x 33.

#### 7.3.2 The replay was drawing the wave from the wrong slot

Both panes derive `ping_bearing` from the restored genome rather than from the
ring (§1.4), and for one commit that derivation went through the **DNA's**
layout instead of the body's. `move()` parts the two deliberately, so the bug
was one gesture away from any player who used the feature that shipped the same
morning.

Posed with the shipped gesture, not with a harness poke: `ampulla` worn at
slot 3, `Esc`, five `Tab`s onto DNA locus 3, two `Shift`+`->`, resume, starve,
`watch`.

| | live | replayed, before | replayed, after |
| --- | --- | --- | --- |
| `ampulla`, body slot | 3 | 5 | 3 |
| `ping_bearing` | +42.09 deg | **+133.27 deg** | **+42.09 deg** |

Ninety-one degrees, on the screen whose whole job is to be trustworthy — and
`soma.gd` draws the fringe off the same `body_layout()`, so the tuft moved with
it. Rendered at 1280x720 and 2400x1080, point of view and full vision: before,
the replay puts the tuft and the wave's origin on the rear-starboard quarter
while the live frame has them forward-starboard; after, the two frames put them
on the same arc.

**The overwrite case is worse and is fixed by the same key.** Drop a held gene
over the `ampulla`'s own DNA locus and the gene leaves the DNA while the organ
stays on the body — `genes-and-cilia.md` §9.7's irreversible action, made gentle
exactly by that. Rebuilt from the DNA, `slot_of` returned −1: the replay drew
**no organ at all** on the figure and sent the wave **dead ahead** at 0.00
degrees. Measured on a run that places a `stigma` over locus 3 and is then
watched: bearing 0.00 and body slot −1 before the fix, +42.09 and slot 3 after.

**The live run never had the bug**, which is why nothing but the replay changes:
the live point-of-view and full-vision frames come out **byte-identical** before
and after the fix — 0 differing pixels of 921,600 at 1280x720 and of 2,592,000
at 2400x1080. `STRIDE` does not move either: the PLAYER delta is a dictionary
and this is one more key in it.

### 7.4 The `chemocyte`'s swing, and where it is flat

`--scan-at=` sweeps a facing through 360 degrees in 5-degree steps and reports
the weighted level at each. Twelve samples, 3 seeds x 4 times, `smell_floor`
0.22:

| sample | level range | best/worst |
| --- | --- | --- |
| s4242 t4 | 0.124 .. 0.203 | 1.63x |
| s4242 t12 | 0.141 .. 0.324 | 2.30x |
| s4242 t25 | 0.775 .. 0.830 | **1.07x** |
| s4242 t45 | 0.281 .. 0.419 | 1.49x |
| s77 t4 | 0.150 .. 0.414 | 2.76x |
| s77 t12 | 0.384 .. 1.280 | 3.33x (clamped to 2.60x) |
| s77 t25 | 0.482 .. 0.855 | 1.77x |
| s77 t45 | 0.249 .. 0.430 | 1.73x |
| s1009 t4 | 0.180 .. 0.357 | 1.98x |
| s1009 t12 | 0.282 .. 0.573 | 2.03x |
| s1009 t25 | 0.472 .. 0.639 | 1.35x |
| s1009 t45 | 0.602 .. 0.810 | 1.35x |

Median 1.75x, range 1.07x to 3.33x. **One sample in twelve is flat**, and that is
the risk in §8 — and it is the finding that sent §7.5 looking for a better nose.

Re-run with the shipped loudest-source nose (§7.5), 3 seeds x 3 times:

| | s4242 | s77 | s1009 |
| --- | --- | --- | --- |
| t = 4 s | 0.046..0.076 (1.65x) | 0.049..0.134 (2.72x) | 0.056..0.114 (2.03x) |
| t = 15 s | 0.063..0.177 (2.83x) | 0.149..0.474 (3.19x) | 0.105..0.257 (2.45x) |
| t = 30 s | 0.111..0.269 (2.43x) | 0.241..0.784 (3.26x) | 0.196..0.276 (1.41x) |

Median **2.45x**, worst **1.41x**, and **nothing is flat**. The loudest-source
nose is better at carrying direction as well as better at being followed, and
that is why it is in the spec rather than in §9.

Two things this table settled:

- **Do not add a gain.** Normalising the weight to mean 1 — the antenna-theory
  answer, directivity redistributes rather than shrinks — pushed 5 of 12 samples
  into the hard clamp at 1.000, where the swing is exactly zero. The weighting
  on its own de-saturates the field, which is what the readout needed. Only one
  of twelve clamps without it.
- **Sharpening the cosine buys nothing; lowering the floor buys contrast.**
  Exponents 1.00 / 1.79 / 2.50 gave swings of 0.358 / 0.365 / 0.340 on one
  sample — under 2% apart. Floors 0.35 / 0.22 / 0.10 / 0.00 gave ratios of
  1.67x / 2.00x / 2.48x / 3.17x on the same sample. That is why `rhabdom` moves
  to the floor (§2.4) and not to a width.

**Drawn.** Two renders differing only in which slot the `chemocyte` is worn in
(slot 3, bearing +54; slot 4, bearing -54), same seed, same water: the ring's
peak green channel moves from 147 on the starboard side to 155 on the port side,
with the dimmest point at 40-44 in both. Measured ring contrast **4.96:1**
against the 4.5:1 the `z` was solved for.

Two more renders differing only in whether the posed body is in front of the
nose (+54) or behind it (-126), on the shipped nose and the fitted curve: peak
green **106 -> 163**, a **54% rise** of the whole ring with its shape unchanged.
That is *"turn and watch it brighten"*, photographed, and the two frames are not
subtly different — one is a lit green ring and the other is a hint of one. On
the plain summed nose the same pair moved only 20%.

**Re-taken on the built code, and it holds.** Same pair, `chemocyte` in slot 3
(bearing +42), an r12 body posed at 300 units at +42 and then at -138, seed 7,
`--freeze-at=3.0`. Sampled as `green - blue` — the contour is teal and cancels —
along 72 rays from the centre, taking the maximum on each:

| | peak | at | dimmest | at | ring contrast |
| --- | --- | --- | --- | --- | --- |
| body in front of the nose | **64** | +35 deg | 25 | 230 deg | 2.56x |
| body behind the nose | **37** | +5 deg | 19 | 225 deg | 1.95x |

**73% brighter with the nose on the food, and the ring does not move**: the
peak sits on the organ's own arc in both frames and the dimmest point sits
opposite it, 180 degrees away, in both. That is the whole of §2.2 in two
numbers — the shape is welded to the body and only the brightness answers the
water. Three renders of each command were byte-identical (0 differing pixels of
921,600), so both are measurements.

The drawn contrast, 2.56x, is not `1 / 0.22`. The lobe itself is exact —
`tools/drive.gd`'s trace prints the shader's own `smoothstep(z, 1, -1)` and it
comes back at **0.22** — and what the render adds on top is the contour's base
glow, which is lit by everything else on the membrane and floors the dim side.
The constant is in the uniform; the picture is the constant plus the skin it is
drawn on.

### 7.5 Blind play — and the measurement that changed the design

This is the one that mattered and the one that nearly failed.

`--sniff` is a run-and-tumble forager: sample `taste_level` every 0.4s, hold a
turn while it rises, reverse when it falls. It is deliberately stupid — if it
can find food, a player can. It reads the level straight off the field rather
than off the bus, because `POST_EPSILON` gates re-posts at 0.02 and a player
reads the membrane every frame.

Time to the first meal, tier-1 `chemocyte`, 90-second cap:

| build and strategy | seeds | ate | median |
| --- | --- | --- | --- |
| **today**, steering onto the taste bearing | 8 | **8 of 8** | **26.1 s** |
| **today**, level only (run-and-tumble) | 5 | 1 of 5 | 68.8 s |
| **summed nose**, level only | 5 | 1 of 5 | 49.1 s |
| **loudest-source nose, tail 0.00**, level only | 5 | 1 of 5 | 40.5 s |
| **loudest-source nose, tail 0.22**, level only | 8 | **7 of 8** | **73.4 s** |

(today: 13.9 / 18.4 / 25.0 / 25.7 / 26.4 / 28.7 / 28.8 / 37.9 s.
 tail 0.22: 30.4 / 34.8 / 59.6 / 73.4 / 78.9 / 88.9 / 89.9 / no meal.)

The second row is the finding. **Even on today's unmodified field, a level-only
strategy finds food one time in five.** That is a property of the scent field,
not of the orientation weight: 13-19 sources inside a tier-1 reach sum to
something that barely moves with position or facing, and clamps at 1.0 for much
of a run. Taking the bearing away does not make the level harder to read — it
reveals that the level was never navigable.

So the change **needs** one more thing, and the fourth row is it:

```gdscript
# food.gd, replacing the plain sum inside smell_range
## How much of everything-but-the-loudest reaches the readout. The nose reports
## the strongest thing it can smell, plus a tail of the rest -- so the reading
## still rises in richer water, but one source can dominate it and a gradient
## therefore exists.
const SMELL_TAIL := 0.22
...
taste_level = minf(smelt_top + SMELL_TAIL * smelt_rest, 1.0)
```

**A tail of 0.22 is measured, not chosen.** Pure loudest-source (tail 0.00) is
*worse* than the sum: when the nose turns away from its loudest source the
maximum jumps to a different body, so the level steps discontinuously and a
gradient follower tumbles at random. The tail smooths those handovers, and it
also keeps the owner's *"whether the smell is strong or not"* literally true —
more food still reads as more smell.

**The honest cost: median time to first meal goes from 26 s to 73 s, and one run
in eight does not eat inside ninety seconds.** That is a 2.8x slowdown in the
thing a run opens with. Two facts put it in proportion and neither excuses it:

- `HUNGER_SECONDS` is 420 with a 40-second grace, so a 73-second first meal is
  nowhere near starving. The change makes the opening *anxious*, not lethal.
- The bot is worse than a player at this. It reads one number and ignores the
  beat entirely, and the beat is an independent, always-on reading of the same
  water (§2.5). A player has two instruments and the bot has one.

It was the row in §8 that needed the owner, and the owner shipped it. §7.5.1
re-measures the whole table on the built code.

`concentration`, and therefore the beat, is unchanged: it is still the plain
unweighted sum over the whole field, so a noseless cell still beats faster in
rich water and hunger reads exactly as it did.

#### 7.5.1 Re-measured on the built code, over 24 seeds — and it does not reproduce

Everything above is the prototype's, on one build and one bot. The built code
was measured again with the shipped `--sniff` (§7.7) over **24 seeds**, 90-second
cap, `--radius=30 --genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1`,
`--fixed-fps 60`, headless. Three controls, one command each, differing only in
which tree they were pointed at:

| what the nose is | seeds | ate inside 90 s | median of those that ate |
| --- | --- | --- | --- |
| **today**, plain sum, steering onto the taste bearing (`--forage`, at `40df405`) | 8 | **8 of 8** | **20.8 s** |
| **today**, plain sum, level only (`--sniff`, at `40df405`) | 24 | **6 of 24** | 60.8 s |
| **shipped nose**, `SMELL_TAIL` 0.22, level only | 24 | **16 of 24** | 64.5 s |
| **loudest-source nose**, `SMELL_TAIL` 0.00, level only | 24 | **19 of 24** | 36.8 s |

(today/forage: 16.0 / 17.9 / 18.2 / 19.7 / 21.8 / 23.2 / 24.0 / 25.7 s.
 shipped nose: 24.8 / 29.9 / 33.8 / 36.8 / 46.1 / 47.0 / 53.4 / 63.5 / 65.4 /
 68.5 / 69.0 / 73.2 / 75.3 / 79.7 / 81.2 / 83.5, and eight that did not eat.)

**Two of the three findings reproduce and one inverts.**

1. **The level-only strategy really is a coin toss on today's field**: 6 of 24,
   which is the prototype's "1 in 5" again. That is a property of the scent
   field and not of the orientation weight, exactly as §7.5 said.
2. **The weighted nose is far more navigable by level alone**: 6 of 24 becomes
   16 of 24. The change is doing the thing it was made to do.
3. **`SMELL_TAIL` 0.22 is *worse* than 0.00, which is the opposite of §7.5.**
   19 of 24 against 16, and a median first meal of 36.8 s against 64.5 s.

**Why, and it is arithmetic.** On identical trajectories — same seed, same
water, no steering, so the two builds fly the same path — the tail is a mean
**40%** of the whole reading and reaches **67%** (3 seeds x 11 samples). With
13-19 sources inside a tier-1 reach, `0.22 x 15` is 3.3, so "a tail of
everything else" outweighs the loudest source by more than three to one. It is
not a tail. It is most of the reading, and most of the reading is a slow
position term that says nothing about facing — which is the plain sum this
change exists to get away from, let back in at 22%.

**The mechanism §7.5 claims for the tail is real, and it is small.** Over 5,208
consecutive sample pairs from the same 24 runs:

| | median \|ΔL\| | p99 \|ΔL\| | \|ΔL\| > 0.25 |
| --- | --- | --- | --- |
| tail 0.22 | 0.0117 | 0.193 | 0.65% |
| tail 0.00 | 0.0080 | 0.256 | **1.09%** |

The tail does damp the handovers — the worst 1% of steps are a third smaller and
big jumps are 40% rarer — but it buys that by raising the *typical* step 46%,
because it is adding a moving crowd to every sample. The prototype measured the
damping and did not measure what it cost.

**It ships at 0.22 anyway, because that is what the owner approved and because
the meal count is not the only thing it buys.** A pure maximum is not
*"whether the smell is strong or not"*, which is the owner's own sentence: it
is how strong the single nearest thing is, and it does not rise in richer water.
That is a design property the bot cannot see and a player can. The number is
flagged for the owner in this file's own table rather than moved here.

| # | Question | Options | What it means |
| --- | --- | --- | --- |
| 1 | `SMELL_TAIL` is 0.22. Measured on the built code over 24 seeds it is the thing making the first meal slow: 16 of 24 fed against 19, and a median 64.5 s against 36.8 s. Lower it? | A — leave it at 0.22 · **B — take it to about 0.06, so the tail is a tenth of the reading rather than 40% of it ✓ recommended** · C — take it to 0.00, pure loudest-source | **A**: the opening stays as it is now — slow, and about one run in three does not find a first meal in ninety seconds. **B**: the glow still rises when there is more food around you, but the thing your nose is actually pointed at dominates it, so turning tells you more. **C**: the glow stops saying how much food is near at all and only ever reports the single loudest thing; fastest to hunt with, and it drops half of what the owner asked smell to say. |

0.06 rather than 0.00 because 0.06 x 15 is 0.9 — the crowd and the loudest
source weigh about the same — which keeps *more food reads as more smell* true
while leaving the facing term in charge. It is an estimate from the arithmetic
above and **has not been measured**; it is a row for the owner, not a change.

**One property of the field that neither table shows and a player will meet.**
`scent()` saturates inside `CORE_RANGE`, 130 units, so the last 130 units to a
meal have almost no gradient in them: the bot reached a clamped level of 1.000
three times on seed 12345 and ate nothing, because the mouth needs contact and
the nose stopped saying which way. That is not new — it is the shape of the
scent field, unchanged since Phase 4 — but taking the bearing away is what makes
it visible. A player has the same problem and two more instruments.

### 7.6 The `ocellus`

Rendered at tier 3 with twenty rays, both views, both shapes.

- **Full vision**: twenty lines read as *rays*, not as a wall. The misses stay at
  their shipped 0.10-0.16 alpha and the two that landed on a body are at
  0.34-0.62 with a white tip — the eye goes to the hits. Nothing needed
  changing.
- **Point of view, a body at 150 units**: five pointers in an **arc** tracing the
  body's near edge, at 116-140 world units, which is the surface where it
  actually is. This is the picture the interior has been black for, and it took
  no new drawing code at all — `returns.gd` already drew one mark per landed
  beam.
- **Point of view, a body at 310 units**: nothing. The pointer's full-strength
  reach is 134 units dead ahead and 299 abeam, which `genes-and-cilia.md` §2.3
  already measured and named. Twenty rays do not change it: the membrane's lobe
  is still the approach instrument.
- **2400x1080**: the same arc, the same place, nothing clipped and nothing
  collided. The marks scale with the figure because both read `soma.gd`'s SCALE
  through the same stretch.

### 7.7 The harness consequence, and what replaced the flag

`tools/drive.gd --forage` steered to put the **taste bearing** on the nose.
After this change that bearing is the organ's own arc, so `--forage` would turn
one way forever — it would be measuring itself. It is gone, and **`--sniff`**
is in its place: sample `taste_level` off the field every 0.4 s, hold a turn
while it rises, reverse when it falls.

Three things about it that are not obvious and are all measured.

**It reads the field, not the bus.** `signal_bus.gd` gates its re-posts at
`POST_EPSILON` 0.02, so a subscriber sees a staircase where a player watching
the membrane sees a continuous glow. Measuring a gradient through a 0.02
quantiser would measure the quantiser.

**The reversal is edge-triggered.** Reversing on *every* falling sample makes a
cell that has just swum past its food alternate port/starboard every 0.4 s,
which is a straight line — at the one moment a straight line is the worst
answer. Reversing once, at the turn from rising to falling, leaves the new
direction held while the level keeps falling, so the heading sweeps until
something gets better. It matters because the actuator is slow: a tier-1
`cirrus` takes 1.10 s to build its turn against a 0.4 s sample, so a bot allowed
to reverse on consecutive samples never actually turns. Measured over the same
eight seeds: 4 of 8 ate inside 90 s level-triggered, 5 of 8 edge-triggered.

**Every measurement in this repository taken with `--forage` and a `chemocyte`
is void across this change.** `replay.md` §3 and §9 quote two `--forage --evade`
commands; those runs were about the recorder's determinism and its cost per
frame, not about the nose, so their *findings* stand — but the commands as
written no longer run, and re-taking them needs `--sniff`.

---

## 8. Decided — the owner's answers

All three rows are settled. The questions and the evidence that supported them
are kept; what changed is that each now has an answer and a state.

| # | Question | Decision | What it means |
| --- | --- | --- | --- |
| 1 | Smell becomes a level with no direction. Ship it? | **A — ship it, with the loudest-source nose (§7.5). BUILT.** | Finding food is hunting rather than walking: you swing your nose about and watch the glow rise and fall. It takes longer and it can go wrong — you will not starve, but the opening minute stops being safe — and it is the first sense that rewards knowing which way your body is pointed. |
| 2 | `rhabdom` sharpened the smell lobe's *width*, and there is no width any more. | **C — retire it from the drop table. BUILT.** | One fewer gene in the water. Nothing in a player's build changes, because nothing could have a `rhabdom` from a version that still had one: no genome in this game is ever written to disk. |
| 3 | Twenty beams draw an outline in the middle of the screen. Allow it? | **A — allow it, at tier 3 only, for the `ocellus` alone. NOT BUILT — ships separately.** | Pour three whole tiers into one eye and you finally *see* the shape of the thing in front of you. |

Rows 1 and 2 are in this build. **Row 3 is not**, and deliberately: it collides
with rows 1 and 2 in `food.gd`, `cell.gd` and `cilia.gd`, and a change that
rewrites the beam fan, the recorder's stride and the drawn pointers at the same
time as the nose is a release nobody can review. §3 still describes it and §4's
table still marks it *not built*.

### 8.1 What the retirement of `rhabdom` actually does, and the compatibility call

The owner's row 2 is option C. **`rhabdom` is retired by taking it out of the
two tables that can *produce* a gene** — `food.gd`'s `GENE_WEIGHTS` and
`DRIFTER_GENES`, which are what the water is seeded from — **and out of
`genome.gd`'s `GENE_ORDER`, which is what `_mutate_drift` draws a replacement
from.** Nothing in the shipped game can hand a player one after this.

It is also taken out of the four tables that *describe* it — `cilia.gd`'s `HUES`
and `EARNED_COUNT`, `normal_mode.gd`'s `WORDS` and `EXPLAINS` — and that is the
deliberate half. Leaving `focus` and *sharpens where a smell is coming from*
behind would be the pause screen promising an effect that no longer exists,
which is the only way this change could actually corrupt something a player
reads.

**The compatibility question, answered by looking rather than by guessing.**
A genome could in principle survive a version change through a save file, a
serialised replay or `user://`. In this project **none of those exist**:

- `grep -rn "FileAccess" game/` is empty. Nothing under `game/` writes a file.
- `run_state.gd` is the only thing that touches `user://`, and it stores four
  scalars: view, gain, camera lock, scheme, plus the onboarding flag. No genome.
- `recorder.gd`'s own header states it and the code agrees: *"In memory and
  nowhere else. No file, no `user://`, no serialisation, no version field."*
  A replay cannot outlive the process that made it.
- The only surface that names a gene as text is `tools/drive.gd`'s `--genome=`
  and `--dna=`, and `tools/` is excluded from both export presets.

So the retirement cannot meet an old genome, because there are no old genomes.
**What was implemented instead is that it would survive one if there were.**
Every table that consumes a gene name already answers for one it has never
heard of, and that was checked rather than assumed:

| lookup | what an unknown gene gets |
| --- | --- |
| `Genome.tier_of` | `.get(gene, 0)` — the tier is kept, not dropped |
| `Genome.dominant_of` | an explicit second pass over keys outside `GENE_ORDER` |
| `Genome.upkeep_of` | iterates `values()` — a retired gene still costs upkeep |
| `Cilia.hue_of` | `RESERVED_HUES[0]`, indigo |
| `Cilia`'s `EARNED_COUNT` | `COUNT_EARNED`, the default tuft |
| `normal_mode.WORDS` | the raw gene name |
| `normal_mode.EXPLAINS` | the empty string, so no line is drawn |

**Photographed, not argued.** `--genome=cytostome:2,cirrus:1,flagellum:1,`
`chemocyte:2,rhabdom:2,ocellus:1` boots, plays, pauses and divides. The pause
strand draws the locus in indigo and labels it `rhabdom`; the line under it
reads `rhabdom` with **no sentence**, because the gene no longer does anything
and the screen declines to invent one. Nothing crashes, nothing is silently
dropped from the genome, and the upkeep is paid.

**One defect found by that photograph, and it is left alone on purpose.** The
locus word falls back to the raw gene name, and `rhabdom` measures about 60 px
against `normal_mode.gd`'s documented 47 px budget for a word on the *choosing*
screen — so on a division it runs about 15 px past its block's nominal right
edge. Rendered at 1280x720 and 2400x1080 nothing collides, because the next
block is 232 px away; the overrun is invisible and real. It is not fixed here
because it is unreachable without the harness, and because `normal_mode.gd`
already writes down the fix if it ever matters: add the difference to
`CHOOSE_BLOCK_W` on the **outboard** side.

**72 degrees of the hue wheel is free again**, where `rhabdom`'s yellow-green
sat. `cilia.gd` records it beside `RESERVED_HUES` rather than adding it to that
list, because those two are in wheel order and a third entry would change which
colour an unknown gene gets.

### 8.2 `SMELL_BEHIND` lives in `food.gd`, and the ring is a second copy

§2.1 put `SMELL_BEHIND` in `signal_bus.gd`, next to `FOCUS_BY_TIER`, because the
floor was going to be `SMELL_BEHIND * FOCUS_BY_TIER[tier]`. With `rhabdom`
retired there is no tier table and the floor is one number, so it moved to
`food.gd`, which is the file that computes the level. The membrane keeps a
second copy, `SMELL_RING_FLOOR`, and that is deliberate rather than an oversight:

- the drawn ring **is** the organ's directivity pattern (§2.2), so the two
  numbers are one number wearing two hats;
- the membrane is a view and may not preload the field — a `signal_bus.gd` that
  imported `food.gd` would put the water inside the skin;
- the file already has exactly this pairing between `PING_RELEASE` and
  `food.gd`'s `PING_MIN_GAP` — and, since `ping-as-outline.md`, a second one
  between the two copies of `PING_WIDTH_FLOOR` — documented the same way.

Both comments name the other constant and say what breaks if they drift: the
picture stops being the maths and becomes a decoration. Measured on the shipped
build, the lobe's `smoothstep(z, 1, -1)` comes back at **0.22** exactly.

### 8.3 §1.3's blind arc: confirmed, not changed

`three-senses.md` §1.3 raised one question in prose that was never tabled — the
blind arc does not narrow with investment, it *goes* at the first upgrade, and
whether that is the right ladder is an owner call. **It is: the blind arc stays
a tier-1 mechanic and `PING_THROUGH_BY_TIER` is unchanged at
`[0.0, 0.0, 0.34, 0.58]`.** Stone blind behind your own body until the first
upgrade; after it, a quieter answer from the half you are not pointed at. No
code changed for this row and none should.

## 9. What was considered and rejected

**A uniform ring for the smell readout.** The obvious answer for "an intensity
with no bearing": push the lobe's `z` to -200 and the smoothstep is flat to
within 0.03%. Rejected on contrast. A dark-adapted eye is poor at absolute
brightness and good at edges, and a perfectly even ring has no edge to catch a
change against — it reads as the base field getting slightly greener, which is
not a signal. The directivity ring (§2.2) keeps a 4.5:1 gradient, which is what
the eye actually notices, and it costs the same single uniform.

**A ring centred on the *food* rather than on the organ.** Keeps the contrast
and throws away the whole point: it would be a bearing again, wearing a ring.

**Renormalising the orientation weight to mean 1.** Antenna theory says
directivity redistributes a conserved total rather than shrinking it, and it is
a lovely argument. Measured, it pushed 5 of 12 samples into the clamp at 1.000
where the swing is exactly zero (§7.4). The realism was right about physics and
wrong about this field, which has no headroom. Dropped.

**A soft compressor (`S / (S + H)`) in place of the hard clamp.** Fixes
saturation at the cost of squashing contrast everywhere else: at H = 0.7 the
best sample's 3.33x became 1.83x. The weighting de-saturates on its own, so the
compressor was solving a problem that had already gone.

**`rhabdom` sharpening the cosine's exponent.** Measured at under 2% of swing
across three exponents (§7.4). The water is too evenly spread for a narrower
lobe to find more of it. The floor is where the contrast lives.

**Penetration as "a fraction of range past the first hit".** Needs per-bearing
marching, and "how far past" is not something the membrane can say. Intensity
is what a dimmer echo is, and intensity is what the membrane has.

**Penetration as a depth limit ("two bodies deep at tier 2").** A count is a
step, the player cannot count bodies, and `food.gd` spent `genes-and-cilia.md`
§7.0 removing exactly this kind of gate.

**A hard 180-degree hull shadow.** Same objection: a body drifting across the
tangent would pop a mark on and off. `PING_GRAZE` gives it a 27-degree soft
edge, justified by the fact that a ray leaving just under the tangent really
does graze the body.

**Coupling the `ampulla`'s blind arc to the *width* of the arc it is worn on.**
`arc_for_slot` already returns a span — 84 degrees for the anterior arc, 24 for
the diagonals — so a wider organ could honestly see more than a hemisphere. It
would make slot 0 strictly the best slot for a radar, and slot 0 is the mouth.
Rejected: a placement decision with one right answer is not a decision.

**Widening the beam fan with the ray count.** The owner's words are *fill the
space in between*, and they are also the better design: a wider fan makes the
slot matter less, and the slot mattering is the whole theme.

**Twenty beams as twenty copies of the gene across twenty slots.** What the
original design asked for, and what `cell.gd` already declined: a genome is a
`{gene: tier}` map, a second copy raises the tier, and making the same gene
occupy two slots is a refactor of `genome.gd`, `recorder.gd`, the strand and the
choosing screen. The owner said *per beam organ*, which this satisfies.

**Keeping the taste jitter, applied to the level instead of the bearing.** A
jittering level destroys the gradient the player is now reading, which is the
one thing the change cannot afford. Vagueness moved to where it belongs: the
level is genuinely flat in an evenly-fed water, and that is the honest version
of "you cannot be sure".

---

## 10. What was rendered, and where it is

All under `--rendering-driver opengl3 --fixed-fps 60`, through
`res://tools/shot.tscn -- --scene=res://tools/drive.tscn`, with `--seed=` on
every frame that is compared against another.

**The `ampulla` and `chemocyte` frames have been taken on the build; the
`ocellus` frames are the prototype's and nothing else** — §3 is not in `main`
(§4), so nothing in the beam row can be re-photographed without building it
first.

Taken on the build, at both shapes, under `--rendering-driver opengl3`:

- the taste ring with the food in front of the nose and behind it, 1280x720 and
  2400x1080 — the A/B in §7.4, and the pair a reviewer should look at first
- the pause screen's gene strip with `rhabdom` gone: `eat turn swim smell ping
  beam`, and the `chemocyte` line reading *smells food, strongest where your
  nose is pointed*
- the division screen with the same line under a pair of daughters
- the compatibility frame: a forced `rhabdom:2` drawn in the reserved indigo,
  labelled with its raw name, with no sentence under it (§8.1)

**Before**

- the ping's full ring and a return on the contour, point of view and full
  vision, 1280x720 and 2400x1080
- the taste band at a bearing, both shapes
- three beams in full vision, aimed from slot 0

**After**

- the wave as a half-ring out of the organ, point of view and full vision, both
  shapes — the blind arc is the most legible thing in the spec
- the tier-3 wave with the penetrated half closing the circle at 0.58
- the taste ring, both shapes, and the two-frame A/B with the food in front of
  the nose and behind it
- twenty rays in full vision, and the arc of five pointers tracing a body's near
  edge in point of view, both shapes

**Judged.** The wave arc reads instantly and needs no text. The twenty rays read
as rays and the pointer arc reads as an edge. The taste ring needed its curve
re-fitted twice before it was bright enough to be a readout rather than a tint,
and the numbers above are the second fit; at the first it measured peak green 52
against today's 66 and it was, plainly, too dim to be a sense.

**Judged again on the build, at both shapes.** The ring reads as a ring: at
2400x1080 the bright side sits over the top and upper-starboard of the contour
and the dim side over the lower-port corner, with no clipping and nothing
colliding — the band simply gets wider, as §5 predicted. The A/B is not subtle;
one frame is a lit green rim and the other is a suggestion of one, and neither
goes out, which is the whole of why `SMELL_BEHIND` is 0.22 and not 0.10. The
pause strip is one word shorter and reads better for it.

---

## 11. The verdict, in one paragraph

Two of these three changes are straightforwardly good and cost almost nothing:
the `ampulla`'s baffles add a mechanic with a counter the player already owns,
and measured, they cost no returns at all — only which returns. Twenty rays are
the payoff the interior has been black for since Phase 1. **The smell change is
different**, and it was the row the owner had the least reason to want on the
evidence. It shipped, and on the built code the honest summary is narrower than
either the hope or the fear: a level-only forager finds food on **6 of 24**
seeds against today's field and **16 of 24** against the new one, so the sense
is more than twice as navigable as the thing it replaces — and still much slower
than the autopilot it takes away, which fed on **8 of 8** in a median 20.8 s.
The sense that comes out the far side is more interesting to use than the one
that goes in, it never goes dark, and turning is now the thing that answers it.
The one number worth revisiting is `SMELL_TAIL`, which at 0.22 is 40% of the
whole reading and is measurably what makes the opening slow (§7.5.1).

## 11.1 The paragraph this replaced, kept because it was the warning

Two of these three changes are straightforwardly good and cost almost nothing:
the `ampulla`'s baffles add a mechanic with a counter the player already owns,
and measured, they cost no returns at all — only which returns. Twenty rays are
the payoff the interior has been black for since Phase 1. **The smell change is
different.** It is the one the owner has the least reason to want on the
evidence: a player finds their first meal in a median 26 seconds today and 73
seconds after, one run in eight does not eat inside ninety, and one facing sweep
in twelve is too flat to steer by. It is not fatal — starvation is 420 seconds
away and the beat is untouched — and the sense that comes out the far side is
more interesting to use than the one that goes in. But it is the only change
here that makes the game *harder in a way that is not also more interesting on
the first try*, and it is the row in §8 that should be answered before anything
is built.
