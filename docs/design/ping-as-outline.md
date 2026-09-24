# The ping is an outline, not a mark

Phase 8. The `ampulla` returns an **extent**, not a point.

> "The ping wave does not bounce back. It should visually represent what a radar
> would allow to perceive to a being, = outline obstacles (like bats). And the
> wave should be way slower."
>
> "There's no 'no shape' rule. The cell must one day become able to see its
> environment. It's just that where we're at in the cell development, it does not
> achieve this yet."
>
> **"The ping should bounce back."**
> — the owner

**The last line replaces the first.** An earlier draft of §2 read *"the owner is
right that nothing bounces"* out of the first quote and built §3.1 on it. The
owner has since said plainly that it bounces, so §2 is rewritten rather than
extended and every section that rested on the one-way reading has been brought
into line. What that cost is not cosmetic: a return now arrives at `2d /
PING_SPEED`, so every flight time in this document doubled and §7's overlap
doubled with it. **§10 row 1 has since closed that overlap**, by setting the
period to the round trip — §7 and §10 carry the before and after.

The speed is shipped (`PING_SPEED` 1250 → 250, commit `962cea0`) and this build
did **not** re-open it, on instruction, so that §7 could be stated honestly
against the numbers players have. §10 puts the ladder to the owner with the
measurements.

Status: **built, and photographed**, at 1280x720 and 2400x1080, in point of view
and in full vision, under `--rendering-driver opengl3`. Every number marked
*measured* came off a render or a trace in §8; the rest is arithmetic off the
shipped constants and says so. Three byte-identical runs of the measured command
differed by **0 pixels** on this build (§8.0), so the comparisons below are
comparisons.

---

## 0. The rule this spec does not break, and the one it corrects

`normal_mode.gd` is still the only node that talks to the signal bus, and **no
position reaches it.** An outline arrives as a bearing, an angular half-width, a
hold time and a level — four scalars, none of which is a place. You cannot
recover a position from them: the half-width conflates size with distance, on
purpose, exactly as an ear does.

The correction is to `perception.md` §4:

> Phase 1 encodes only *bearing* (coarse, lagged, jittering) and *intensity*
> (scalar). It never encodes position, distance, shape, count or identity.

That was read here for seven phases as a **prohibition**. The owner has said
plainly it is not one — it is a statement about how far the cell has developed.
§9 has the replacement wording and it has been made in that file. **Shape is
allowed.** The only question is what a tier-1 organ has earned.

**One thing the bounce did not change, and it is the one worth checking twice.**
The two views draw the pulse going out and coming home, at radii and bearings.
That is the same licence `returns.gd` has had since it was written — the cell
emitted the pulse and knows where its own wave has got to — and it does not leak
through the bus: `_post_pings` still hands over four scalars and an organ arc.
Nothing in `food.gd`'s `ping_echoes` reaches `signal_bus.gd`, by any route.

---

## 1. What was wrong with the return this replaced

Rendered at tier 1, with an r80 body 300 units off the port bow: one soft violet
blob on the contour, **30° of bearing at half power, 36° lit, alive for 0.19 s**,
and then nothing for three seconds. *(measured, `base_pov_return_720.png`)*

Three specific failures, all three now fixed:

1. **Angular width is a constant.** `PING_HALFWIDTH_DEG` is 17/13/10 by tier, so
   every body reports the organ's beamwidth and nothing of its own. A whale
   against your flank and a speck at the edge of reach draw the *same shape*;
   only brightness separates them, and brightness is already spent on range and
   occlusion.
2. **A return was an instant.** `PING_ATTACK` 0.035 + `PING_DECAY` 0.15. The
   wave takes up to 8.8 s to go out and come back and the thing it found was
   reported in a fifth of a second. The slow wave bought seconds of readable
   time and the readout threw them away. Marks now live 0.21–0.70 s
   *(measured)*, scaled by the body's own depth.
3. **Five returns shared one envelope**, and shared it with the `ocellus`.
   Loudest wins. A pulse that found four bodies could only ever say one thing at
   a time, so "a wall of things to port" and "one thing to port" were the same
   picture. There are two ping arcs now, out of a pool of four, and the
   `ocellus` has its own slot back.

The first 3.5 s of a tier-1 run on the old build, traced: **one** ping event, at
0.88 s, bearing −35°, strength 0.87. That was the whole of what the sense said
in one pulse period. *(measured)*

---

## 2. The fiction: an echo that bounces

**It bounces.** The pulse leaves the organ, travels out, reflects off the near
edge of the first thing it meets, and the echo travels home. The organ hears it
when it gets back.

> A return arrives at **`2d / PING_SPEED`**, not `d / PING_SPEED`. A body 220
> units out is answered 1.76 s later at tier 1, not 0.88; the far edge of a
> tier-1 reach answers after **8.8 s**, not 4.4.

An earlier draft of this section argued the opposite, off a reading of the
owner's first quote, and it was wrong. It is worth saying why the wrong version
was attractive, because the argument it made is still half true: an ampulla of
Lorenzini really does read a field rather than listen for an echo, and a
field-sweep model makes the drawn wavefront and the felt return the *same event*
in one frame. That is a nice picture. It is not the one the owner asked for, and
it is not the better one.

**A bat is not a thing that shouts. It is a thing that listens.** The moment the
mechanic becomes legible is the echo arriving, and a model where the sensation
fires as the front passes over something has no arriving to draw. So the picture
is now four things, in order:

1. an outgoing front, expanding out of the organ's own arc on the membrane;
2. a reflection, where it meets a body;
3. a **return travelling home**, contracting onto that same arc;
4. the membrane reporting, at the instant it lands.

Point of view gets all four: `returns.gd` already drew (1) on the argument that
the cell emitted the pulse and knows where its own front has got to, and (3) is
the same class of thing — the cell's own pulse, coming back. It is **not** the
outline drawn at its place, which is §10 row 3 and the next gene's to sell: an
echo is only ever at the body's own distance for the instant it leaves, it
carries no shape, and it is gone the moment it lands. What stays on the skin is
still a bearing.

### 2.1 What the round trip doubles, and the one thing it does not

Everything made of *distance* doubles: flight time, the number of pulses in the
water at once, and — the expensive one — the reach a given period can answer
from without ambiguity, which **halves**. §7 is that bill, and §10 row 1 is the
owner paying it: the period is now the round trip itself, so one pulse is in the
water at a time and the unambiguous reach is the whole reach again.

**The held time does not double**, and that is not a convenience. Only the near
hemisphere of a body answers; the far side is in its own shadow. The reflecting
surface runs from the near pole, at range `D − R`, to the limb, at range
`sqrt(D² − R²) ≈ D`, so the echo is spread over a depth of `R` and arrives over
`2R / PING_SPEED`. That is exactly the number the one-way front took to cross
the *whole* body, so §3.2's table survives the bounce untouched — and so does
§10 row 2, which was deferred on the assumption that every number in it would
double. It does not: the arrival time doubled and the duration did not.

### 2.2 The fade is counted on the path, and the water takes its share (#45)

One law for every ping, `food.gd`'s static `ping_level(path, reach)`, times the
hull and the occluders as before:

```
level = (1 − path / (2 × reach)) ^ PING_FALLOFF × exp(−PING_ATTENUATION × path)
```

**An echo's path is `2d`**, so its fade is the `(1 − d / reach)^0.6` it always
was — proved with `PING_ATTENUATION` at 0: all six identity-gate fingerprints
(`shared-pond.md` §5) are `main`'s, and `field_diff` is ALL EQUAL over 284,450
checks. **The water takes 3.75e-5 per unit of path** (Beer–Lambert), set to
the owner's bound: an echo off a body 900–1,400 units out comes home at most 10%
fainter, 0.900 at 1,400 and 0.867 at the edge of tier-3 reach. Measured over
300 s of the sighted forager at six seeds per tier, 293 pulses and 1,089 echoes
heard, before → after:

| tier | heard | median | p10 | p90 | lit bodies in reach at or under `PING_SILENT` |
|---|---|---|---|---|---|
| 1 | 480 | 0.636 → 0.609 | 0.222 → 0.210 | 0.853 → 0.837 | 7.05% → 7.23% |
| 2 | 284 | 0.474 → 0.453 | 0.257 → 0.246 | 0.879 → 0.861 | 1.00% → 1.14% |
| 3 | 325 | 0.572 → 0.566 | 0.433 → 0.411 | 0.902 → 0.882 | 0% → 0% |

Every heard echo kept 0.922–0.998 of its level, and not one left or joined the
heard set: the six bodies the water newly silenced were already past the cap.
The echo that lands in foraging is nearer than the seeding band (median 426–493
units, never past 1,081), so the loss is under the bound, not at it. Rendered in
point of view at both shapes, `main`'s frame three times to 0 px first, a mark
loses 7–9% of its violet and no pixel moves by more than 9/255: the faintest
tier-1 mark reads as it did.

**A friend's call crosses once, path `d`.** So it is louder than the echo off
the same body, carries to twice the reach of the organ that made it, still
arrives at once (the owner's call), and is not played at or under
`PING_SILENT`, which it used to be. Level by distance, before → after:

| units of water | 500 | 1,000 | 1,500 | 2,000 | 3,000 | heard to |
|---|---|---|---|---|---|---|
| tier 1 | 0.695 → 0.841 | 0.237 → 0.670 | — → 0.476 | — → 0.220 | — | 1,100 → 2,193 |
| tier 2 | 0.784 → 0.880 | 0.517 → 0.755 | — → 0.624 | — → 0.480 | — | 1,500 → 2,990 |
| tier 3 | 0.833 → 0.902 | 0.639 → 0.802 | 0.393 → 0.699 | — → 0.593 | — → 0.351 | 1,900 → 3,786 |

## 3. The four readings one return now carries

A body of radius `R` whose centre is `D` from the organ reflects between
`2(D − R) / c` and `2D / c` — near pole to limb, out and back. Four independent
facts fall out; none is a position. §7 used to tax exactly one of them, and
§10 row 1 has now bought that one back.

### 3.1 *When it comes back* — distance, and the reading that was taxed

`flight = 2d / PING_SPEED`, `d` the surface distance. The slowdown and the
bounce together made this the longest channel the sense has: **0 to 8.8 s** of
dynamic range at tier 1, against 4.4 one-way and 0.88 before the slowdown.

**The overlap this used to be taxed by is gone.** Unambiguous reach is
`period × speed / 2`, and the owner has set the period to the round trip
(§10 row 1, option (c)), so `period × speed / 2` is exactly the reach at every
tier: **1100 / 1500 / 1900 of 1100 / 1500 / 1900 — 100%**. Counted rather than
argued: `--pings=` puts the peak number of outgoing fronts at **1 at all three
tiers**, against 2 / 3 / 6 under the ladder this replaces. There is one pulse in
the water and a mark can only have come from it, so arrival time is distance
again over the whole of the organ's reach.

The three things that used to be the consolation for the overlap are all still
true, and they are now redundancy rather than defence:

- **The other two readings do not care.** Width (§3.3) and held time (§3.2) are
  properties of the body and of the organ, not of which pulse answered. So is
  the bearing.
- **Distance is already carried twice.** `PING_FALLOFF` puts it in the mark's
  *level*: measured over a 60 s tier-3 run the levels that land run 0.24 to
  0.97, and a near body is always louder than a far one.
- **The echo is watched rather than timed.** It is drawn walking home for the
  last ~430 world units of its journey — 1.7 s at 250 — and it is the brightest
  violet on the screen while it does. A mark arrives attached to something the
  player has been looking at, which is a different act from counting seconds
  since a wavefront left.

**What it cost is in §7**, and it is refresh: 21 / 20 / 19 marks a minute
instead of 55 / 104 / 168.

### 3.2 *How long it lasts* — size, and the number the bounce left alone

The echo is spread over `2R / PING_SPEED`, and that is **independent of
distance**. Under the one-way model it was the time the front spent inside the
body; under the round trip it is the depth of the illuminated hemisphere, there
and back — §2.1. Same number. At `PING_SPEED` 250:

| body | radius | echo spread | held mark, with `PING_RING` 2.0 |
| --- | --- | --- | --- |
| drifter, smallest | 13 | 0.104 s | 0.36 s |
| drifter, largest | 21 | 0.168 s | 0.49 s |
| a cell your own size | 26 | 0.208 s | 0.57 s |
| a cell about to divide | 40 | 0.320 s | 0.80 s |

**Measured on the shipped build**, over 60 s of foraging at each tier: holds
land between **0.21 and 0.70 s**, mean 0.28 / 0.36 / 0.34 by tier, which is the
r13–r44 band the table predicts with attack and release on top.

A channel the membrane did not use at all before this. **Held, not struck**, a
return becomes something you wait out, and a big one takes visibly longer to say
itself. This is the bat reading: echo duration is target depth.

```gdscript
## How much longer the organ rings than the echo takes to pass. 1.0 is the bare
## geometry; 2.0 is what shipped, because 0.104 s against 0.320 s is a real
## ratio hiding inside two numbers that are both "a blink".
const PING_RING := 2.0
```

### 3.3 *How wide it opens* — angular extent, and why it must be magnified

At any instant the echo is coming off exactly **two points** of the body's rim,
at bearings `θ ± φ(t)`. Those are the outline's edges. `φ` opens from 0 at the
near pole, reaches the true angular half-width `α = asin(R/D)` as the reflecting
ring crosses the limb, and closes again. To first order the profile is a
half-ellipse:

```
φ(t) = α · sqrt(1 − u²),   u = 2t/T − 1,   T = 2R / PING_SPEED
```

**And α is tiny.** This number decides the whole design. Bodies seed between 920
and 1350 units out (`RING_MIN`/`RING_MAX`) at radii 13–40:

| body | distance | true α |
| --- | --- | --- |
| r13 drifter | 1000 | 0.74° |
| r21 drifter | 1000 | 1.20° |
| r40 peer | 920 | 2.49° |
| r26 peer | 300 | 4.97° |
| r26 peer | 60 (touching) | 25.7° |

Against a beamwidth of 17°/13°/10°. A literal angular width would report **every
body in the water at under 3°** — a hairline, indistinguishable from every other
hairline — and would only open up for something already on top of you. Literal is
unusable.

That is fine, and it is not a compromise: **an organ is a transducer, not a
camera.** Every sense on this membrane already magnifies — the taste lobe is 78°
wide for a source that subtends nothing. What honesty requires is that the
mapping be *monotone* and that the organ's own beamwidth be a **floor**: a sensor
cannot report an extent finer than its beam, and that floor is exactly what the
ladder lowers.

```
halfwidth = min(WIDTH_FLOOR[tier] + WIDTH_GAIN[tier] · α, PING_WIDTH_MAX)
```

| tier | `WIDTH_FLOOR` | `WIDTH_GAIN` | `HOLLOW` | returns/pulse |
| --- | --- | --- | --- | --- |
| 1 | 17° | 1.5 | 0.00 | 3 |
| 2 | 13° | 3.5 | 0.35 | 4 |
| 3 | 10° | 6.0 | 0.62 | 5 |

`PING_WIDTH_MAX = 52°`. Past that a lobe stops being a bearing and becomes a mood.

What the table produces, arithmetically:

| body | tier 1 | tier 2 | tier 3 |
| --- | --- | --- | --- |
| r13 @ 1000 | 18.1° | 15.6° | 14.4° |
| r40 @ 1000 | 20.4° | 21.0° | 23.8° |
| r26 @ 300 | 24.5° | 30.4° | 39.8° |
| r26 @ 60 | 52° (cap) | 52° (cap) | 52° (cap) |

**Measured on the shipped build**, over 60 s of foraging: reported widths land
between 15.0° and the 52° cap, and the floor is never breached at any tier.
The organ's own beamwidth is what a far speck reports and nothing narrower ever
reaches the skin.

Read down a column: at tier 1 a speck and a whale a kilometre out differ by 2.3°
and you will not feel it — *the cell does not achieve this yet*. Read across a
row: the top tier tells them apart by 9.4°, and reports the speck **sharper**
than tier 1 does, because its beam is narrower. That is the resolution ladder and
it is the developmental story the owner described.

### 3.4 The shape of the mark: hollow, and why that is the outline

The shader's lobe is `smoothstep(cos w, 1, dot)` — a soft bump, brightest at the
centre. A bump is a *detection*. An outline is **two edges with a lit gap**,
because that is what the front actually touches.

One extra scalar per lobe turns one into the other:

```glsl
float a = smoothstep(lobe.z, 1.0, dot(bd, lobe.xy));
float s = mix(a, 4.0 * a * (1.0 - a), hollow);   // hollow in 0..1
```

`4a(1−a)` is zero at the lobe centre and peaks where `a ≈ 0.5`, so the mark
becomes two bright bearings with a dimmer middle, and the wider the reported
extent the further apart they are.

**Rendered on the built version**, one r80 body 300 units off the port bow, the
mark caught at its widest, the whole ladder in one pose (§8.1). True bearing
−41.8°, from the trace:

| tier | `HOLLOW` | footprint | limbs | separation | centre of the pair | bridge |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 0.00 | 72° | −54° / −30° | 24° | **−42.0°** | **78%** |
| 2 | 0.35 | 94° | −70° / −13° | 57° | **−41.5°** | **65%** |
| 3 | 0.62 | 95° | −76° / −8° | 68° | **−42.0°** | **39%** |
| 3, at 2400x1080 | 0.62 | 95° | −75° / −7° | 68° | **−41.0°** | **36%** |

Every centre lands on the true bearing within a degree, at both shapes. Tier 1's
"limbs" at 24° with a 78% bridge are the contour wobble on a single hump, not
two edges — which is the point: *the cell does not achieve this yet.*

The bridge is the number that had to be tuned. At `HOLLOW` 0.85 the middle
measured **21%** of the peak and the render read as *two separate bodies*, which
is the one thing a single body's outline must not say. At 0.62 it is 39% and the
two edges stay visibly joined. `HOLLOW` is capped well below 1 on purpose: the
top of the ladder is 0.62, not 1.0.

**One warning about measuring this, which cost an hour.** The shader takes
bearing on an aspect-corrected ellipse and the contour is a rounded rectangle,
so on the diagonals the band sits at about 1.14 of the ellipse radius. A sweep
that stops at 1.0 samples only the inner lip there — exactly the bearings
*between* two limbs — and reports a dead gap where there is a lit bridge. It
did: the tier-1 frame, which has no hollowness in it at all, read as two humps
with a zero middle. Sweep past 1.4 or the instrument invents the result.

### 3.5 Putting it together: what one body feels like

Tier 2, an r26 peer 300 units off the port bow, at `PING_SPEED` 250. Every time
below is doubled from the draft that had it travelling one way:

```
t = 0.00   the pulse leaves the organ's arc; the membrane hums faintly there
t = 1.10   the front reaches its near edge. Nothing is felt yet
t = 2.19   the echo lands. A narrow bright flick at −35°
t = 2.30   the mark swells, 13° toward 30°, dimming as it spreads; edges parting
t = 2.41   widest — the reflecting ring is across the limb
t = 2.52   the edges close; a second narrow bright flick
t = 2.62   gone
```

The echo is drawn walking home from about t = 1.5, when it comes inside the
frame, and it collapses onto the organ at 2.19 — which is the instant the flick
appears. Near edge first, opening over a fifth of a second, closing again. A far
speck at the same bearing arrives at t = 7.8, flicks once at 15°, and is gone in
0.25 s.

**A near wide body and a far narrow one are different facts in four channels at
once** — when, how long, how wide, how loud — and §7 taxes exactly one of them.

---

## 4. Tier is the resolution ladder

No fourth mechanic: the ladder is the three constants in §3.3 plus the existing
`PING_RANGE_BY_TIER`, `PING_PERIOD_BY_TIER` and `PING_THROUGH_BY_TIER`. As a
promise to the player:

- **Tier 1 — *there is something, that way, and it is this big.*** Extent arrives
  as **time** (§3.2) and barely as angle. Stone blind behind your own body. Two
  bodies within 17° merge into one wider, longer mark — the honest failure, and
  the reason to upgrade.
- **Tier 2 — *and it has edges.*** `HOLLOW` 0.35 begins to split a wide return
  into two limbs. The blind arc softens to 0.34 through your own hull.
- **Tier 3 — *and there are two of them.*** A 10° beam separates what tier 1
  merged; five returns per pulse instead of three; `HOLLOW` 0.62, so a near body
  reads as a rim rather than a blob.

Measured on the built ladder, one pose, in §3.4: the two edges of one body part
by 24°, then 57°, then 68°, and the bridge between them falls 78% → 65% → 39%.
The skin is silent about seven seconds in eight at **every** tier now (§7.1.1),
which is the one rung the ladder lost when the period became the round trip:
tier buys resolution, reach and penetration, and no longer buys refresh.

**The interior is still not spent.** The wave is drawn there, out and back — the
cell emitted the pulse and knows where its own front and its own echo have got
to — and so is the `ocellus` pointer, but the ping's *returns* stay on the
membrane. A returning echo is not an outline at its place: it collapses onto the
organ, it carries no shape, and it is gone the instant it lands. Drawing an
outline at its true *place* is vision, and that is what the gene after this one
sells. **Settled**: §10 row 3 is (a) — the interior stays black until the next
gene, which confirms what the code does.

---

## 5. What was built: the simulation side

Section titles below name the file the constant actually lives in, because this
is now a description of the build rather than a plan for one.

### 5.1 `food.gd`

```gdscript
const PING_RING := 2.0
const PING_WIDTH_FLOOR: Array[float] = [0.0, 17.0, 13.0, 10.0]
const PING_WIDTH_GAIN: Array[float]  = [0.0,  1.5,  3.5,  6.0]
const PING_WIDTH_MAX := 52.0
const PING_RETURNS_BY_TIER: Array[int] = [0, 3, 4, 5]   # was a flat 5
const PING_MIN_GAP := 0.30                              # was 0.17
var ping_tier := 0
```

`_cast_ping` keeps every line it had — the origin on the skin, the hull's
`PING_GRAZE` shadow, the per-occluder `ping_through` loop, the cap applied after
occlusion. It gains two scalars per heard body, both out of values it already
held:

```gdscript
var radius_i: float = found[i][2]
var span := maxf(reach, radius_i)                  # organ to body centre
var alpha := rad_to_deg(asin(clampf(radius_i / span, 0.0, 1.0)))
var width := minf(PING_WIDTH_FLOOR[tier] + PING_WIDTH_GAIN[tier] * alpha,
	PING_WIDTH_MAX)
var hold := PING_RING * 2.0 * radius_i / PING_SPEED
```

and one line is the whole of the bounce:

```gdscript
var flight := 2.0 * d / PING_SPEED                 # was d / PING_SPEED
```

`_echoes` entries grow from `[due, pos, level]` to `[due, pos, level, width,
hold]`; `pings` entries from `[bearing, level]` to `[bearing, level, width,
hold]`. **The position still dies on the line it died on.**

### 5.1.1 One pulse is not enough state

`_ping_age` was a single scalar and `ping_front` a single radius, which is what
§7.0 photographed: the newest front drawn over the oldest pulse's returns. **The
period §10 row 1 chose means there is only ever one front to draw**, so
`_pulses` and `ping_fronts` now hold one entry where they used to hold six, and
`ping_echoes` at most five where it used to hold thirty-one. They are kept as
arrays anyway: the ambiguity they fixed was real, a scalar is exactly the shape
that hid it, and nothing about the period is load-bearing here. The field
keeps

```gdscript
var _pulses: Array = []      # ages of every outgoing front still inside reach
var ping_fronts: Array = []  # their radii, oldest first, for the two views
var ping_echoes: Array = []  # [radius, bearing, halfwidth_deg, level], nearest home first
var ping_listen := 0.0       # how much of the newest round trip is still to come
```

`ping_echoes` is recomputed every frame off the stored world position, so an
echo eight seconds out still arrives on the bearing the body is on **now** — the
same conversion `_step_pings` already did once, at the moment of landing, done
twice and handed on neither time as a place the bus can see.

### 5.2 `normal_mode.gd`

```gdscript
func _post_pings() -> void:
	for echo: Array in _food.pings:
		_bus.ping(float(echo[0]), float(echo[1]), float(echo[2]), float(echo[3]))
	_bus.ping_out(_food.ping_bearing, _food.ping_listen)
```

plus `_food.ping_tier = _cell.ping_tier()` beside `ping_through`, and
`_bus.ping_out(0.0, 0.0)` in `_hush()`. Still no position, still the only node
that talks to the bus.

### 5.3 `signal_bus.gd`

The bus owns the envelope; the field only measures. An `Arc` holder beside
`Env`, because a crossing is not a strike and a decay:

```gdscript
func step(delta: float) -> void:
	if _hold <= 0.0:
		return
	_t += delta
	var u := clampf(2.0 * _t / _hold - 1.0, -1.0, 1.0)
	var profile := sqrt(maxf(1.0 - u * u, 0.0))          # §3.3's half-ellipse
	width = _floor_deg + (_wide_deg - _floor_deg) * profile
	var gate := 1.0
	if _t < PING_ATTACK:
		gate = _t / PING_ATTACK
	elif _t > _hold:
		gate = maxf(1.0 - (_t - _hold) / PING_RELEASE, 0.0)
	level = _peak * lerpf(1.0, PING_LIMB_ACCENT, absf(u)) * gate
	if _t >= _hold + PING_RELEASE:
		_hold = 0.0
		level = 0.0
```

Four `Arc`s in a pool (`PING_ARCS`), the quietest giving way to a new return;
`_compose_lobes` fills slots 4 and 5 with the two loudest live arcs, and the hum
takes whichever of the two is idle — so a return never competes with the cell's
own organ. New constants: `LOBE_PING_A` 4, `LOBE_PING_B` 5, `PING_LIMB_ACCENT`
1.35, `PING_RELEASE` 0.12, `PING_HOLLOW_BY_TIER` `[0, 0, 0.35, 0.62]`,
`PING_HUM_LEVEL` 0.08, `PING_HUM_HALFWIDTH` 54°, `PING_COLOR` — the ping has its
own violet now, `Cilia.hue(&"ampulla")`, because it no longer shares a slot.
`PING_DECAY` is gone with the envelope it belonged to; `PING_HALFWIDTH_DEG` has
become `PING_WIDTH_FLOOR` and is now the bottom of a measurement rather than the
measurement.

Hollowness rides in `glow_colors[i].a`, pushed with the palette rather than
every frame; `sense_organs()` re-pushes when the `ampulla` tier moves.

**The `ocellus` gets lobe 3 back to itself**, and the wrong comment that kept
two senses in one slot for three phases is deleted with it — §11.

### 5.4 The shader

`game/perception/membrane.gdshader`, three edits, all content:

```glsl
uniform vec4 glow_lobes[6];         // xy = bearing, z = cos(halfwidth), w = intensity
uniform vec4 glow_colors[6];        // rgb = colour, a = hollowness (0 bump, 1 rim)
...
	vec3 glow = vec3(0.0);
	if (band > 0.002) {
		for (int i = 0; i < 6; i++) {
			float a = smoothstep(glow_lobes[i].z, 1.0, dot(bd, glow_lobes[i].xy));
			float s = mix(a, 4.0 * a * (1.0 - a), glow_colors[i].a);
			glow += glow_colors[i].rgb * (s * glow_lobes[i].w);
		}
	}
```

Idle slots stay `Vector4(0, -1, 2, 0)`: `cos(halfwidth) = 2` never fires, and
`4a(1−a)` is 0 when `a` is 0, so hollow is safe on an idle lobe.

**Cost, and the branch that pays for it.** Six lobes is +50% on the only loop in
this shader, at 2.6M fragments on a 2400x1080 phone. The glow term is multiplied
by `band`, which is zero across most of the frame, so the loop is skipped there —
a spatially coherent branch on a value every neighbouring fragment agrees about.
`perception.md` §3 notes this shader has no branches; that was a description, not
a rule. **This is the one thing in this spec a desktop render cannot judge:
measure it on a phone.** Nothing here was measured on a GPU that is not this
container's software rasteriser.

### 5.5 The replay stride

`BLOCK_FLOATS` went 37 → **46**: two more glow lobes are eight floats, and the
ninth is the hollowness. Hollowness *has* to be in the block, which is not
obvious — it rides in the palette, and a pane rebuilds a membrane out of uniforms
with no organ to read a tier off, so a recorded tier-3 outline would play back as
a tier-1 bump on the one screen built to check what the player actually felt.

`recorder.gd` replaces the single `ping_front` float with eighteen: two front
radii and four echoes of four scalars each. Both counts were measured rather than
chosen — a front leaves the frame in under a second, so at most two are ever
inside it, and four echoes covers every instant of the tier-3 pose. Both are now
slack rather than tight: under the period §10 row 1 chose there is one front in
the water at a time and five echoes at the very most, so the two front slots and
four echo slots are a ceiling the field can no longer reach. `STRIDE` 296 → **322**, 69 → **75 KB/s**, a 60 s window 4.1 → **4.4 MB**.
Measured on the new stride, one `capture()` costs **186 µs** at its worst and
**104 µs** on average.

The ping tail is **stepped, not lerped**, for the reason `AT_HUNTER` is: an echo
slot is not an identity. The field re-sorts nearest-home every frame and a
landing vacates one, so slot 2 in two consecutive frames is routinely two
different bodies, and lerping would slide one arc across the water to where
another one was. A bearing cannot be lerped through the wrap at ±π either.

## 6. What was built: what is drawn

### 6.1 Point of view — the membrane

Two arcs where there was one blip. They are `glow_lobes[4]` and `[5]` in
`Cilia.hue(&"ampulla")` — the violet the wave and the organ's tuft already use —
and they live in the 104px band like every other lobe. Reflow is free: the band
follows the viewport, the bearing is aspect-corrected, nothing is centred.
Verified at both shapes in §3.4 — the limb bearings move by at most 1° between
1280x720 and 2400x1080 and the centre of the pair lands on the true bearing at
both.

### 6.2 Point of view — the wave, out and back, and the silence between

**The wave leaves the screen in under a second and the round trip lasts up to
15.2 s.** At `SomaLayer.SCALE` 1.7 the front reaches the top edge of a 1280x720
canvas at `212 / 1.7 / 250 = 0.50 s` and is past the corner by 1.7 s.

Do **not** rescale the wave to fit. The soma figure and the `ocellus` pointer are
drawn at true body scale in the same picture; a wavefront on a compressed scale
would make the one honest distance reading on screen a lie.

Two things fill the silence instead, and the first is what the bounce bought.

**The echo comes home.** One short arc per return still in flight, at the bearing
it will land on, over the span the membrane is about to open to, contracting onto
the organ at the instant the mark appears on the skin. It is brighter and thicker
than the outgoing front on purpose — the front is the question going out and this
is the answer coming back. The last ~430 world units of an echo's journey are on
screen, which is **1.7 s of watching it arrive** at 250 u/s, and it is the
brightest violet in the picture while it does.

It is capped at six drawn at once (`ECHO_DRAWN`), off screen ones excluded first.
There is no cap in the field, and that cap mattered when the water held up to
**31** returning echoes at tier 3 (§7.0, measured); under the period §10 row 1
chose it holds at most **5**, so the cap is now slack it will never take up.

**And every live front is drawn, not just the newest**, which is the half of
§7's fix that lives in a view. There is now only ever one.

**The organ hums while it listens.** 54° half-width, peak 0.08, at
`ping_bearing`, fading as the newest pulse's **round trip** runs out — the
one-way version of this faded over half as long. It costs no slot, because it
only takes a ping slot that is idle. It makes a wait of 8.8 to 15.2 s read as
*listening*, and it draws the blind arc for free: the hum is where the pulse
went, so the half of the water you are not asking is the half that is dark.

**It got better when the period did.** `ping_listen` is `1 - age / trip`, and
the period is now exactly `trip`, so the hum breathes from full to empty once
per call at **every** tier. Under the old ladder a tier-3 period was a tenth of
its own round trip and the hum sat nearly flat — a readout that was honest
(*a tier-3 organ really is always listening*) and said nothing. It is now the
thing that fills the seven seconds in eight that §7.1.1 measures as silence.

**Measured on this build**: with nothing arriving, the hum reads `B − G` = **5**
at the nose and **0** dead astern, against 46–69 for a mark at its peak and about
15 for the quietest return the falloff produced in a 60 s run. That keeps §6.2's
actual constraint — *the hum must sit under the quietest return* — with a factor
of three in hand. One wrinkle: at tiers 2 and 3 the hum inherits the tier's
hollowness, because it borrows a ping slot, so it is a faint double veil rather
than a single one. At 0.08 the difference is below anything a player will read.

### 6.3 Full vision — the fronts, and the echoes coming back

`vision.gd` draws every live front as a half-ring at `ping_through` on the far
side, exactly as before but N times, and then every returning echo as a short
bright arc at its own bearing and reported span.

This is not decoration. Full vision exists to check that point of view is telling
the truth, and this is the check: **the skin lights at the same instant, at the
same bearing, over the same span, that an echo lands on the organ.** Both are
drawn off the same four numbers, so a disagreement is visible in one frame rather
than inferred. Checked again on this tree the way §8.2 asks: 60 s at seed 7 with
the view forced each way produced **0 divergent sensation lines** out of 152 and
the same 20 ping marks.

Full vision draws no outline of its own — it already draws the bodies.

### 6.4 Both targets

- No widgets, no touch targets, nothing new to reach. The 48px rule does not bite
  on the sensory screen and this adds nothing to it.
- At 2400x1080 the canvas is 1600x720 and the band widens with it. A lobe is
  aspect-corrected, so a mark lands at the same relative place on both: measured
  in §3.4, the tier-3 limbs sit at −76°/−8° at 1280x720 and −75°/−7° at
  2400x1080, both centred within a degree of the true bearing, bridge 39% against
  36%. The echo arcs are drawn in canvas space at the figure's scale, so they are
  the same size in world units on both and simply have more room.
- The hum is the dimmest thing this spec adds and the one at risk on a phone in
  daylight. It is under the `gain` uniform like everything else, and it carries
  nothing the arcs do not repeat, so losing it outdoors costs only atmosphere.

---

## 7. What the bounce cost, what the owner paid, and what one pulse costs

**This section used to be a bill. §10 row 1 has now settled it, and the price is
printed at the bottom.**

### 7.0 What the bounce cost, before the period moved

A pulse answers for `2 x PING_RANGE / PING_SPEED`; the organ fired again after
`PING_PERIOD`, and under the old 3.2 / 2.2 / 1.4 ladder those two did not fit
inside one another:

| tier | reach | round trip | old period | pulses answering at once | unambiguous reach |
| --- | --- | --- | --- | --- | --- |
| 1 | 1100 | **8.80 s** | 3.20 s | 2.8 | 400 — **36%** |
| 2 | 1500 | **12.0 s** | 2.20 s | 5.5 | 275 — **18%** |
| 3 | 1900 | **15.2 s** | 1.40 s | **10.9** | 175 — **9%** |

Counted on the build rather than left as arithmetic, `--pings=` over 60 s at
seed 7, `--radius=30`, as maxima — the worst instant is what decides whether a
mark is ambiguous:

| tier | outgoing fronts, peak | returning echoes, peak | marks in 60 s |
| --- | --- | --- | --- |
| 1 | 2 | 9 | 55 |
| 2 | 3 | 16 | 104 |
| 3 | **6** | **31** | 168 |

Thirty-one echoes in the water at one instant at tier 3. A mark that landed could
not be timed back to the pulse that started it, so **§3.1 was the one reading
this taxed**.

### 7.1 What one pulse at a time costs instead

`PING_PERIOD_BY_TIER` is now `2 × PING_RANGE_BY_TIER / PING_SPEED` exactly —
8.8 / 12.0 / 15.2 s. Same command, same seed, same radius:

| tier | outgoing fronts, peak | returning echoes, peak | marks in 60 s | unambiguous reach |
| --- | --- | --- | --- | --- |
| 1 | **1** | 3 | 21 | 1100 — **100%** |
| 2 | **1** | 4 | 20 | 1500 — **100%** |
| 3 | **1** | 5 | 19 | 1900 — **100%** |

**One front, at every tier, always.** That is the whole of what was bought, and
it is the thing the arithmetic promised — the peak was not assumed, it was
counted.

**Two things were paid for it, and both are measured.**

**Refresh stops climbing with tier.** 21 / 20 / 19 marks a minute against
55 / 104 / 168. Upgrading the `ampulla` now buys reach and resolution — how far
it hears and how many bodies one sweep answers for — and not frequency. A player
who eats their way from tier 1 to tier 3 gets a sense that reaches nearly twice
as far and resolves five bodies instead of three, at the same rate of about one
mark every three seconds.

**The water is no longer always ringing.** A front or an echo is somewhere in
the water 70% / 54% / 64% of the time, against 100% at every tier before. The
gap is *not* the period: the last possible echo lands exactly as the next call
goes out. It is that the front is culled at its own reach — half a round trip in
— and the bodies it actually found are far nearer than the reach, so their
echoes are all home early. Between the last echo landing and the next call the
water is empty.

### 7.1.1 What it does to the skin

The membrane has two ping arcs. Over 60 s at seed 7, `--radius=30`, marks
occupying an arc for their own hold plus `PING_RELEASE`:

| tier | marks | per second | mean hold | skin silent | one mark | two marks | a third competing |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **old** 1 | 55 | 0.92 | 0.34 s | 62.7% | 33.2% | 4.1% | **0.0%** |
| **old** 2 | 104 | 1.73 | 0.34 s | 40.1% | 42.6% | 14.6% | **2.6%** |
| **old** 3 | 168 | 2.80 | 0.31 s | 36.3% | 23.1% | 27.8% | **12.8%** |
| **now** 1 | 21 | 0.35 | 0.34 s | **85.5%** | 12.9% | 1.6% | **0.0%** |
| **now** 2 | 20 | 0.33 | 0.34 s | **86.4%** | 12.0% | 1.4% | **0.1%** |
| **now** 3 | 19 | 0.32 | 0.30 s | **88.3%** | 10.2% | 1.6% | **0.0%** |

Read it both ways and neither reading is dishonest. The two arcs are never
fought over now — a third mark competes for a slot 0.1% of the time at worst,
against 12.8% at tier 3 before — so the "loudest wins" eviction that used to
lose a quarter of tier 3's marks effectively never fires. And the skin is quiet
about seven seconds in eight at every tier, where a tier-3 skin used to be quiet
only a third of the time.

**What fills that silence is the hum**, and it got better rather than worse.
`ping_listen` is `1 - age / trip`; under the old ladder a tier-3 period was a
tenth of its own round trip, so the hum sat nearly flat and said nothing. Now
the period *is* the trip at every tier, so the hum breathes from full to empty
exactly once per call — a reading that says *the answer is still coming* over
the whole of the wait, at all three tiers, for the first time.

### 7.2 The frame

`vis_t3_echo_1280.png` was full vision, tier 3, t = 8.05: five fronts and
twenty-seven echoes on one screen, a water full of concentric rings with no way
to tell by eye which ring an arriving arc left from. **It cannot be taken any
more, and that is the change.** At any instant there is one front and a handful
of echoes belonging to it.

`ping_t1_1.20_1280x720.png` / `ping_t3_1.20_1280x720.png` and their 2400x1080
pairs replace it: point of view, 1.2 s after the call, one front going out and
one echo walking home. Tier 1 draws the forward hemisphere only —
`PING_THROUGH_BY_TIER[1]` is a hard zero, so the cell's own body is in the way —
and tier 3 carries the front all the way round at 0.58 of its level. Nothing is
concentric with anything, because there is nothing else in the water.

`ping_t1_2.00_1280x720.png` / `ping_t3_2.00_1280x720.png` are the same run
0.8 s later, once the 80-unit body at 300 units has answered: the tier-1 mark is
a solid band 42° wide, the tier-3 mark is 52° wide and hollow — two limbs with a
dim bridge, which is §3.4's outline. Same pair at 2400x1080.

---

## 8. Measurements

### 8.0 The frames are frames

Three byte-identical runs of

```
--mode=0 --seed=7 --genome=cytostome:1,cirrus:1,flagellum:1,ampulla:3:0 \
--cell=0,300,-35,80 --cell=1,1000,35,14 --freeze-at=8.05 --fixed-fps 60
```

differed by **0 pixels, 0 pixels, 0 pixels** on this build, and the same was true
of the old command on the build before it. `--seed=` reaches the bus, so
everything below is a measurement and not weather (`perception.md` §4.1).

Re-proved on the tree that moved the period, before any A/B was measured on it,
and re-proved again afterwards: three renders of `--freeze-at=1.20` at tier 3
and three of the smell frame that shipped alongside it — **0 differing pixels**
in all four comparisons.

### 8.1 The mark, per degree of bearing

Violet only (`B − G`; the contour is teal and cancels), sampled around the band
at 1° of bearing, the six brightest samples on each ray discarded so a 2px
wavefront crossing the band is not read as a mark. **Sweep the ray past 1.4 of
the ellipse radius** — §3.4's warning.

One pose, one r80 body 300 units off the port bow, mark caught at its widest, the
whole ladder in §3.4's table. Peaks: 68 at tier 1, 56 at tier 2, 58 at tier 3 —
the mark does not get *brighter* with tier, it gets wider and hollower, which is
the ladder saying *resolution* rather than *volume*.

### 8.2 One simulation, two views

`--mode=0` against `--mode=1`, 30 s at seed 7, tier 3: **216 sensation lines
each, 0 divergent.** The only differing line in the whole log is the harness's
own `mode forced to N` banner. 98 of those lines are pings.

Re-run on the tree that moved the period, 60 s at seed 7 with a tier-3
`ampulla` and a tier-2 `chemocyte`: **152 sensation lines each, 0 divergent**,
and 0 divergent `[sniff]` samples. 20 of those lines are pings, which is the
new rate rather than a quieter log — §7.1.

### 8.3 What is in the water

`--pings=`, the trace this build added, because §7 was arithmetic off three
constants until something counted it. Peaks over 60 s at seed 7 are in §7.0
(the old period) and §7.1 (this one); the mark rate, the hold distribution and
the two-arc occupancy are in §7.1.1.

### 8.4 The recorder

`--capture-cost=10.0` on the new 322-float stride: **peak 186 µs, mean 104 µs**
per `capture()`, over 600 frames. `replay.md` §4.6 asks for a measurement rather
than an estimate; that is the measurement.

### 8.5 The renders

All at `--seed=7`, `--fixed-fps 60`, `--rendering-driver opengl3`, at 1280x720
and 2400x1080.

| file | what it shows |
| --- | --- |
| `pov_t1_mark_*.png` | tier 1, r80 @ 300: a broad soft wash over the port bow, no edges in it |
| `pov_t3_limbs_*.png` | tier 3, same body: **two limbs with a lit bridge** — the outline |
| `pov_t3_echo_*.png` | tier 3 in seeded water: two fronts going out, four echoes walking home |
| `vis_t3_echo_*.png` | the same instant in full vision: five fronts, twenty-seven echoes |
| `pov_hum_*.png` | the hum alone, nothing arriving, mid-flight |
| `cand_A_m1.png` | §10's option (b): the wave is **not in the picture at all** |
| `cand_B_m1.png` | §10's option (c): one front, one echo, a sweep every 15 s |
| `cand_C_m1.png` | §10's option (d): nothing at all |
| `panes_t3.png`, `replay_wave.png` | the two-pane screen, live and off a real recording |

They live in this session's scratchpad, listed with absolute paths in the handoff.

## 9. The `perception.md` wording — made

§4 of that file read as a prohibition. It now reads:

> Phase 1 encodes *bearing* and *intensity*, and the first sensory gene adds
> *extent* — how wide a thing is, and how long its echo takes to pass. **This is
> a stage, not a rule.** A cell this early cannot resolve a form; it can feel
> that something is wide and near, or narrow and far, and that is the whole of
> what a tier-1 organ has earned. What is still unspent is *place*: no signal is
> yet drawn at the position of the thing that caused it, and the interior is
> still black. That is what the gene after this one sells, and it should feel
> enormous.

with a note beside it recording what it replaced and one thing the bounce forced
into the open: **distance is encoded twice now**, in a mark's level and in its
round-trip arrival, and neither is a place. §0 is the four-scalar rule that keeps
it so.

§3's signal-table row for the ping is replaced by the three constants in §3.3
and the profile in §3.5. The `three-senses.md` §1.4 note that the returns "stay
marks on the contour" stays true and is now the point rather than a restriction.

---

## 10. To the owner: the ladder — row 1 answered

Rows 1 and 2 were deferred *specifically until the wave bounced*, because every
number in them was expected to double. **Row 1's did. Row 2's did not** — §2.1 —
so row 2 came back answered rather than asked.

**Row 1 is now answered too: option (c), a rarer ping, one sweep every
8.8 / 12.0 / 15.2 s.** That is the round trip at each tier exactly, so the organ
does not call again until its own echo is home. `PING_SPEED` and
`PING_RANGE_BY_TIER` did not move; `PING_PERIOD_BY_TIER` is the only constant
that changed.

| # | Question | Options | What it means |
| --- | --- | --- | --- |
| 1 | The pulse answers for twice as long, so up to eleven of them were in the water at once at tier 3 and a mark could not be timed back to the pulse that made it. Pay to close that, or keep it? | (a) keep it · (b) a faster wave, 690 / 1360 / 2710 by tier · **(c) a rarer ping, one sweep every 8.8 / 12.0 / 15.2 s — CHOSEN** · (d) a shorter reach, 400 / 275 / 175 units | **(c)** the organ waits for its own echo before it calls again, so there is one pulse in the water and *when it came back* means *how far away it is* over the whole reach. It costs frequency: about one mark every three seconds at every tier, instead of one a second at tier 1 rising to three a second at tier 3. |
| 2 | How much does the organ exaggerate a body's size? `PING_RING` and the `WIDTH_GAIN` column. | **(a) leave them where they are ✓ recommended** · (b) re-tune | Nothing changes. These were deferred because the bounce was expected to double them and it does not — only the *wait* doubled, not how long a mark is held or how wide it is drawn. Built and photographed at 2.0 and 1.5 / 3.5 / 6.0, and the ladder reads correctly at all three tiers. |
| 3 | Does a tier-3 ping draw its outline **inside** the membrane, at the place it actually is? | **(a) no — the interior stays black until the next gene.** Confirms current behaviour. | You said the cell must one day see. This keeps that moment for the gene that is *about* seeing, so it lands as an event. The echo now drawn walking home is not that: it collapses onto your own skin and carries no shape. |
| 4 | Two bodies inside one beamwidth merge into one wider, longer mark. Bug or ladder? | **(a) merge — it is the ladder.** Confirms current behaviour. | A crowd feels like one big thing until your radar gets better, which is how a real one behaves and what makes the next tier worth eating for. |

### 10.1 Why (c), and why the other three were not it

The reasoning the owner gave is physical, and it is the same reasoning a bat
uses. **You do not call again until the echo is home.** The animals that do —
the high-duty-cycle horseshoe bats — get away with it only because they carry
Doppler-shift compensation to separate the call from the returns. This cell has
no such machinery, so a second pulse in the water is not a harder problem for
it; it is an unanswerable one. Period equal to round trip means there is exactly
one pulse out there, always, and every mark belongs to it.

That is also why **(a), keep the overlap, was not it**: (a) is the option that
requires the Doppler compensation the cell does not have. Its defence was that
distance is carried twice — in the mark's level as well as its timing — which is
true, and is still true, and is now redundancy rather than a substitute.

**(b), a faster wave, needs the medium's wave speed to change with the genome.**
The number it needs at tier 3 is 2710 units per second. Nothing in the water is
different when a different cell pings it: sound speed is a property of the
medium, and making it a function of which organ fired would be the one place in
this design where the physics reads the player's inventory. It also undoes the
thing the owner asked for by name — at 2710 the front crosses the visible 430
units in 0.16 s and there is no wave on screen at all (`cand_A_m1.png`).

**(d), a shorter reach, only closes below 175 units at tier 3, against a seeding
floor of 920.** Nothing is ever seeded closer than 920 units, so a 175-unit
reach is an organ that answers about one call in seven and mostly reports
nothing (`cand_C_m1.png` is an empty screen). Buying the top tier of a gene to
see *less far* than the tier below is a ladder that goes down.

### 10.2 What each option costs, measured

Marks heard in 60 s at seed 7, `--radius=30`, and what the picture looks like.
Rows (a), (b) and (d) were each patched in, measured, rendered and reverted;
(c) is what shipped and its numbers are re-measured on the built tree:

| ladder | tier 1 | tier 2 | tier 3 | unambiguous | the frame |
| --- | --- | --- | --- | --- | --- |
| (a) keep it — 250 / 1100-1900 / 3.2-1.4 | 55 | 104 | 168 | 36 / 18 / 9% | rings going out, arcs coming home — it reads as sonar, and no arc can be traced to a ring |
| (b) speed 690 / 1360 / 2710 | 56 | 108 | 214 | 100% | `cand_A_m1.png`: **no wave on screen at all.** At 2710 the front crosses the visible 430 units in 0.16 s |
| **(c) period 8.8 / 12.0 / 15.2 s — CHOSEN** | **21** | **20** | **19** | **100%** | one front, one echo, at every tier. §7.2's frames |
| (d) reach 400 / 275 / 175 | 20 | 20 | **6** | 100% | `cand_C_m1.png`: nothing. At tier 3 one pulse in seven finds anything |

**The refresh cost is the honest headline and it is not small: ten times fewer
marks at tier 3, and the ladder's refresh flattens — tier 3 is no more
responsive than tier 1.** What tier still buys is reach (1100 → 1900), how many
bodies one sweep answers for (3 → 5), penetration (0 → 0.58 through a body) and
resolution (a 17° beamwidth floor → 10°). §7.1 is the full bill, including the
silence: a front or an echo is in the water 70 / 54 / 64% of the time instead of
100%, and the skin is quiet about seven seconds in eight.

**Two old corrections, now closed.** An earlier draft of row 1 recommended
*250 / 400 / 600 u/s* and claimed it closed the overlap; under a round trip it
covers 36 / 29 / 22% and closes nothing. And option (a) as first described —
*"eight seconds of silence between sweeps"* — was wrong about silence, then
over-corrected: a later draft of this section said a 15.2 s period *"holds a
pulse in the water 100% of the time"*, and **that was wrong too**. Measured, it
is 64% at tier 3. The last possible echo does land exactly as the next call goes
out, but the front is culled at its own reach half a trip in, and the bodies it
found are nearer than the reach, so their echoes are home early and the water
empties. The arithmetic bound is not the measurement, which is why §7.1 counts
it.

## 11. A wrong comment, now deleted

`game/perception/signal_bus.gd`, at `PING_PEAK`, said:

> **It shares [constant LOBE_BEAM] with the ocellus** -- there are four glow
> lobes in the shader and a fifth is a new uniform and a new binary

`export_presets.cfg` is `export_filter="all_resources"` with
`exclude_filter="tools/*"`, so `membrane.gdshader` is inside the `.pck`. **A
shader uniform is a content change**: no new APK, no `binary_version` bump. The
sentence had been standing since phase 5 and it was the reason two senses shared
one lobe for three of them. It is gone, the shader has six lobes, and
`binary_version` did not move.

Nothing in this spec needs a launcher change, and no launcher problem was found
while building it.

---

## 12. Rejected

- **One-way timing (`d / speed`).** This is the one that was rejected, and it
  was the recommendation of an earlier draft of this document. It makes the
  drawn front and the felt return one event, which is a genuinely good picture,
  and it halves §7's overlap. It is still wrong: the owner asked for a bounce,
  and a sense whose payoff is *an answer arriving* has nothing to draw arriving.
- **Drawing the echo as a full contracting ring.** It would say the whole
  hemisphere answered. An echo comes off one body over one span of bearings and
  is drawn over exactly that span.
- **A reflection flash on the outgoing front** — brightening the vertices of the
  front where it crosses a body, which an earlier §6.3 asked for. Built
  differently and deliberately: the reflection is drawn as the echo that *leaves*
  it, so the same event is on screen without a bright point sitting at a bearing
  **and** a radius. In point of view that pair is a position, and position is
  §10 row 3's to sell. The check §6.3 exists for is unaffected — skin and arc
  still come off the same four numbers.
- **A literal angular width.** §3.3: under 3° for every body at seeding distance.
  It is the honest number and it is invisible.
- **`HOLLOW` at 0.85.** Measured: the middle falls to 21% of the peak and one
  body reads as two. §3.4.
- **A bearing histogram uniform** — N bins around the contour, the outline drawn
  as a profile. It is the general answer and the expensive one: a texture or a
  large array, a write every frame, and what it buys — resolving more than two
  things at once — is exactly what tier 1 must *not* have.
- **Rescaling the point-of-view wavefront** so a whole 15.2 s round trip fits on
  screen. §6.2: two distance scales in one picture.
- **Drawing the returns in the interior.** §4 and §10 row 3, which the owner has
  now answered (a). That is vision, and it is the next gene's to sell.
