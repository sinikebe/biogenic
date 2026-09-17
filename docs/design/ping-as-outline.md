# The ping is an outline, not a mark

Phase 8. The `ampulla` returns an **extent**, not a point.

> "The ping wave does not bounce back. It should visually represent what a radar
> would allow to perceive to a being, = outline obstacles (like bats). And the
> wave should be way slower."
>
> "There's no 'no shape' rule. The cell must one day become able to see its
> environment. It's just that where we're at in the cell development, it does not
> achieve this yet."
> — the owner

The speed is already shipped (`PING_SPEED` 1250 → 250, commit `962cea0`). This
spec is designed **against** the slow wave and does not re-open it. It does
report one thing the slowdown broke on the way past — §7, with a render.

Status: **prototyped and photographed**, at 1280x720 and 2400x1080, in point of
view and in full vision, under `--rendering-driver opengl3`. Every number marked
*measured* came off one of the renders in §8; the rest is arithmetic off the
shipped constants and says so. Three byte-identical runs of the measured command
differed by **0 pixels** (§8.0), so the comparisons below are comparisons.

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

That has been read here for seven phases as a **prohibition**. The owner has said
plainly it is not one — it is a statement about how far the cell has developed.
§9 proposes the replacement wording. **Shape is allowed.** The only question is
what a tier-1 organ has earned.

---

## 1. What is wrong with today's return

Rendered at tier 1, with an r80 body 300 units off the port bow: one soft violet
blob on the contour, **30° of bearing at half power, 36° lit, alive for 0.19 s**,
and then nothing for three seconds. *(measured, `base_pov_return_720.png`)*

Three specific failures:

1. **Angular width is a constant.** `PING_HALFWIDTH_DEG` is 17/13/10 by tier, so
   every body reports the organ's beamwidth and nothing of its own. A whale
   against your flank and a speck at the edge of reach draw the *same shape*;
   only brightness separates them, and brightness is already spent on range and
   occlusion.
2. **A return is an instant.** `PING_ATTACK` 0.035 + `PING_DECAY` 0.15. The wave
   now takes up to 4.4 s to cross its own reach and the thing it finds is
   reported in a fifth of a second. The slow wave bought seconds of readable
   time and the readout throws them away.
3. **Five returns share one envelope**, and share it with the `ocellus`. Loudest
   wins. A pulse that found four bodies can only ever say one thing at a time,
   so "a wall of things to port" and "one thing to port" are the same picture.

The first 3.5 s of a tier-1 run, traced: **one** ping event, at 0.88 s, bearing
−35°, strength 0.87. That is the whole of what the sense said in one pulse
period. *(measured)*

---

## 2. The fiction: a field that sweeps, not an echo that bounces

The owner is right that nothing bounces, and the build already agrees without
having said so: returns are staggered by `d / PING_SPEED`, **one way**, not `2d`.
Make it explicit, because it is the physical story and it is the real one — an
ampulla of Lorenzini does not listen for an echo, it reads a field.

> The pulse is a disturbance the cell pushes out into the water. It does not come
> back. A body is **felt as the front passes over it** — the instant the front
> touches its near edge, and for as long as the front is inside it.

That sentence buys every reading in §3 and costs no new machinery. It also means
the drawn wavefront and the felt return are the *same event*, which is visible in
one frame in full vision: `outline_vision_crossing_720.png` catches the violet
arc mid-way through the body at the same instant the membrane is lit in that
body's direction.

---

## 3. The three readings one return now carries

A body of radius `R` whose centre is `D` from the organ is crossed by the front
between `D − R` and `D + R`. Three independent facts fall out; none is a
position.

### 3.1 *When it starts* — distance

Unchanged: `flight = d / PING_SPEED`, `d` the surface distance. The slowdown made
this real for the first time — **0 to 4.4 s** of dynamic range at tier 1 against
0.88 s before. Read §7 before trusting it.

### 3.2 *How long it lasts* — size

The front is inside the body for `2R / PING_SPEED`, and that is **independent of
distance**. At `PING_SPEED` 250:

| body | radius | crossing | held mark, with `PING_RING` 2.0 |
| --- | --- | --- | --- |
| drifter, smallest | 13 | 0.104 s | 0.36 s |
| drifter, largest | 21 | 0.168 s | 0.49 s |
| a cell your own size | 26 | 0.208 s | 0.57 s |
| a cell about to divide | 40 | 0.320 s | 0.80 s |

A channel the membrane does not use at all today. **Held, not struck**, a return
becomes something you wait out, and a big one takes visibly longer to say itself.
This is the bat reading: echo duration is target depth.

```gdscript
## How much longer the organ rings than the front takes to cross. 1.0 is the
## bare geometry; 2.0 is what these renders used, because 0.104 s against
## 0.320 s is a real ratio hiding inside two numbers that are both "a blink".
const PING_RING := 2.0
```

### 3.3 *How wide it opens* — angular extent, and why it must be magnified

At any instant the front meets the body in exactly **two points**, at bearings
`θ ± φ(t)`. Those are the outline's edges. `φ` opens from 0 at the near limb,
reaches the true angular half-width `α = asin(R/D)` as the front crosses the
centre, and closes at the far limb. To first order the profile is a half-ellipse:

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
extent the further apart they are. **Rendered** at tier 3 on an r80 body 300
units out, `outline_t3_limbs_720.png`:

| | predicted | measured, 1280x720 | measured, 2400x1080 |
| --- | --- | --- | --- |
| limb bearings | −69.1° and −0.9° | **−70° and 0°** | **−69° and −1°** |
| centre of the pair | −35.0° | **−35.0°** — the true bearing | **−35.0°** |
| separation | 68.2° | **69°** | **68°** |
| middle, as a fraction of the peak | 47% | **56%** | **56%** |

The bridge is the number that had to be tuned. At `HOLLOW` 0.85 the middle
measured **21%** of the peak and the render read as *two separate bodies*, which
is the one thing a single body's outline must not say. At 0.62 it is 56% and the
two edges stay visibly joined; at tier 1's 0.0 it is **93%**, a solid bump with no
edges in it at all. `HOLLOW` is capped well below 1 on purpose: the top of the
ladder is 0.62, not 1.0.

### 3.5 Putting it together: what one body feels like

Tier 2, an r26 peer 300 units off the port bow, at `PING_SPEED` 250:

```
t = 0.00   the pulse leaves the organ's arc; the membrane hums faintly there
t = 1.10   the front touches its near edge. A narrow bright flick at −35°
t = 1.20   the mark swells, 13° toward 30°, dimming as it spreads; edges parting
t = 1.31   widest — the front is across the body's centre
t = 1.42   the edges close; a second narrow bright flick
t = 1.52   gone
```

Near edge first, opening over a fifth of a second, closing again. A far speck at
the same bearing arrives at t = 3.9, flicks once at 15°, and is gone in 0.25 s.
**A near wide body and a far narrow one are now different facts in three channels
at once** — and the two renders in §8 are those two facts.

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

**The interior is still not spent.** The wave is drawn there (the cell knows
where its own front has got to) and so is the `ocellus` pointer, but the ping's
returns stay on the membrane. Drawing an outline at its true *place* is vision,
and that is what the gene after this one sells. §10 row 3.

---

## 5. Godot-ready: the simulation side

### 5.1 `food.gd`

```gdscript
## How much longer the organ rings than the front takes to cross the body. §3.2.
const PING_RING := 2.0
## **The organ's own beamwidth**, in degrees: the finest extent it can report,
## and the floor every reported extent sits on.
const PING_WIDTH_FLOOR: Array[float] = [0.0, 17.0, 13.0, 10.0]
## **How much of a body's true angular half-width reaches the readout**, on top
## of that floor. A magnification, and §3.3 is why one is needed: at seeding
## distance every body in this water subtends under three degrees.
const PING_WIDTH_GAIN: Array[float] = [0.0, 1.5, 3.5, 6.0]
## Past this a lobe has stopped being a bearing and become a mood.
const PING_WIDTH_MAX := 52.0
## How many bodies one pulse may answer for, by tier. Was a flat five.
const PING_RETURNS_BY_TIER: Array[int] = [0, 3, 4, 5]
## The smallest gap between two returns of one pulse. Raised from 0.17: a mark
## now lives 0.36-0.80 s instead of 0.19, and there are two lobes to hold them.
const PING_MIN_GAP := 0.30
## The `ampulla` tier, written by the run beside ping_range and ping_through.
var ping_tier := 0
```

`_cast_ping` keeps every line it has — the origin on the skin, the hull's
`PING_GRAZE` shadow, the per-occluder `ping_through` loop, the cap applied after
occlusion. It gains two scalars per heard body, both from values it already holds
and both spent in the same function:

```gdscript
var radius_i: float = found[i][2]                  # already there, for occlusion
var span := maxf(path.length(), radius_i)          # organ to body centre
var alpha := rad_to_deg(asin(clampf(radius_i / span, 0.0, 1.0)))
var width := minf(PING_WIDTH_FLOOR[ping_tier]
	+ PING_WIDTH_GAIN[ping_tier] * alpha, PING_WIDTH_MAX)
var hold := PING_RING * 2.0 * radius_i / PING_SPEED
heard.append([float(found[i][0]), at, level, width, hold])
```

`_echoes` entries grow from `[due, pos, level]` to `[due, pos, level, width,
hold]`; `pings` entries from `[bearing, level]` to `[bearing, level, width,
hold]`. **The position still dies on the line it dies on today.**

### 5.2 `normal_mode.gd`

```gdscript
func _post_pings() -> void:
	for echo: Array in _food.pings:
		_bus.ping(float(echo[0]), float(echo[1]), float(echo[2]), float(echo[3]))
	# The organ's own arc, humming while the pulse is still out: a bearing and
	# a scalar, like everything else that reaches the bus.
	var out := 0.0
	if _food.ping_front > 0.0 and _food.ping_range > 0.0:
		out = 1.0 - clampf(_food.ping_front / _food.ping_range, 0.0, 1.0)
	_bus.ping_out(_food.ping_bearing, out)
```

Plus `_food.ping_tier = _cell.tier(&"ampulla")` beside `ping_through`. Still no
position, still the only node that talks to the bus.

### 5.3 `signal_bus.gd`

The bus keeps owning the envelope; the field only measures.

```gdscript
func ping(bearing: float, strength: float, halfwidth_deg: float,
		hold: float) -> void:
```

An `Arc` holder beside `Env`, because a crossing is not a strike and a decay:

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

Four `Arc`s in a pool, the quietest giving way to a new return. New constants:

```gdscript
const LOBE_PING_A := 4
const LOBE_PING_B := 5
## How much brighter a mark's two limb flicks are than its broad middle.
const PING_LIMB_ACCENT := 1.35
## How long a mark takes to let go once the front is out the far side.
const PING_RELEASE := 0.12
## 0 at tier 1: a tier-1 mark is a smear with no edges in it at all. The top of
## the ladder is 0.62 and not 1.0 -- at 0.85 the middle between one body's two
## limbs measured 21% of the peak and the pair read as two bodies. §3.4.
const PING_HOLLOW_BY_TIER: Array[float] = [0.0, 0.0, 0.35, 0.62]
## While a pulse is still out, the organ's own arc hums. §6.2.
const PING_HUM_LEVEL := 0.08
const PING_HUM_HALFWIDTH := 54.0
```

`_compose_lobes` fills slots 4 and 5 with **the two loudest live arcs**, and the
hum takes whichever of the two is still idle — so a return never has to compete
with the cell's own organ. A third simultaneous arc loses, which is why
`PING_MIN_GAP` went to 0.30.

Hollowness rides in `glow_colors[i].a`, so it is pushed with the palette rather
than every frame; `sense_organs()` re-pushes when the `ampulla` tier moves.

**The `ocellus` gets lobe 3 back to itself.** Sharing was reasonable when a return
was 0.19 s long; a return that lives most of a second would sit on the beam
permanently. Delete the sharing note at `PING_PEAK` with it — and see §11.

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

- `glow_colors` goes `vec3[4]` → `vec4[6]` carrying hollowness in `a`, so
  `attach()` stays one call and no second uniform appears.
- Idle slots stay `Vector4(0, -1, 2, 0)`: `cos(halfwidth) = 2` never fires, and
  `4a(1−a)` is 0 when `a` is 0, so hollow is safe on an idle lobe.

**Cost, and the branch that pays for it.** Six lobes is +50% on the only loop in
this shader, at 2.6M fragments on a 2400x1080 phone. The glow term is multiplied
by `band`, which is zero across ~60% of the frame, so the loop is skipped there —
a spatially coherent branch on a value every neighbouring fragment agrees about.
`perception.md` §3 notes this shader has no branches; that was a description, not
a rule, and the saving is larger than the added lobes cost. **This is the one
thing in this spec a desktop render cannot judge: measure it on a phone.**

### 5.5 The replay stride

`capture_block` / `write_block` / `BLOCK_FLOATS` carry four floats per glow lobe
with the pressure lobes and the tail hard-coded after them. Two more lobes moves
`BLOCK_FLOATS` 37 → 45 and every offset from 31 up by 8. Mechanical, and the
recording never outlives the run that made it, so there is no format to migrate.
Done in the prototype and the two-pane replay screen rendered clean.

---

## 6. Godot-ready: what is drawn

### 6.1 Point of view — the membrane

Nothing new on screen. The arcs are `glow_lobes[4]` and `[5]` in
`Cilia.hue(&"ampulla")` — the violet the wave and the organ's tuft already use —
and they live in the 104px band like every other lobe. Reflow is free: the band
follows the viewport, the bearing is aspect-corrected, nothing is centred.
Verified at both shapes: the measured limb bearings in §8 move by at most 1°
between 1280x720 and 2400x1080, and the footprint grows 2–7° because the band is
deeper on the taller canvas, not because anything has shifted.

### 6.2 Point of view — the wave, and the silence after it

**The wave leaves the screen in under a second and the pulse lasts 4.4.** At
`SomaLayer.SCALE` 1.7 the front reaches the top edge of a 1280x720 canvas at
`212 / 1.7 / 250 = 0.50 s` and is past the corner by 1.6 s. *(measured: by t =
0.95 the wave is two thin arc fragments at the left and right edges —
`base_pov_return_720.png`.)* After that the picture says nothing at all until a
mark lands, and at tier 1 the next mark can be three seconds away.

Do **not** rescale the wave to fit. The soma figure and the `ocellus` pointer are
drawn at true body scale in the same picture; a wavefront on a compressed scale
would make the one honest distance reading on screen a lie.

Fill the silence on the membrane instead: **while a pulse is in flight, the
organ's own arc hums** — 54° half-width, peak 0.08, at `ping_bearing`, fading as
`ping_front` approaches `ping_range`. It costs no slot, because it only takes a
ping slot that is idle. It makes a four-second wait read as *listening*, and it
draws the blind arc for free: the hum is where the pulse went, so the half of the
water you are not asking is the half that is dark.

**The level was measured into place, twice.** At 0.06 it rendered at `B − G` = 3
on an 8-bit frame — invisible. At 0.20 it **swamped a genuine far return**: on the
r14-at-900 pose (`strength` 0.37, `B − G` 26) the frame read as one broad glow at
the nose with the real answer lost inside it, and the hum was the brightest violet
in the band. At 0.08 it peaks at `B − G` 9 (`proto_hum20_720.png`, sampled at the
same effective level), against 26–57 for a return, so a return is always at least
three times the hum — and `outline_t1_far_720.png` reads as a compact mark at
+45° with a faint veil at the nose, which is the right way round. That ratio is
the constraint, not the constant: **whatever the hum is, it must sit under the
quietest return the range falloff can produce.**

### 6.3 Full vision — the wave lights where it is crossing something

`vision.gd` draws the wavefront with `draw_arc`, which takes one colour. Swap it
for the per-vertex `draw_polyline_colors` that `returns.gd` already uses, and
brighten the vertices that fall inside a body — over `bearing ± φ(t)`, the same φ
the membrane is reporting, undisguised.

This is not decoration. Full vision exists to check that point of view is telling
the truth, and this is the check: **the arc lights at the same instant, at the
same bearing, over the same span, that the membrane's arc opens.** If they
disagree, the bearing or the profile is wrong and it is visible in one frame.

**Not built in the prototype** — and the geometric coincidence is already legible
without it: `outline_vision_crossing_720.png` catches the plain arc passing
through the r80 body at the instant the membrane's wash covers that quarter of
the band. Brightening it makes the claim explicit rather than inferred.

Full vision draws no outline of its own — it already draws the bodies.

### 6.4 Both targets

- No widgets, no touch targets, nothing new to reach. The 48px rule does not bite
  on the sensory screen and this adds nothing to it.
- At 2400x1080 the canvas is 1600x720 and the band widens with it. A lobe is
  aspect-corrected, so a mark lands at the same relative place on both: measured,
  the tier-3 limbs sit at −70°/0° at 1280x720 and −69°/−1° at 2400x1080, both
  centred on −35.0°, both with a 56% bridge. The footprint grows about 6° on the
  taller canvas because the band is deeper there — it does not move.
- The hum is the dimmest thing this spec adds and the one at risk on a phone in
  daylight. It is under the `gain` uniform like everything else, and it carries
  nothing the arcs do not repeat, so losing it outdoors costs only atmosphere.

---

## 7. What the slowdown broke: the organ is listening to two pulses

**Not a design choice — arithmetic off the shipped constants, and photographed.**
A pulse is in flight for `PING_RANGE / PING_SPEED`; the organ fires again after
`PING_PERIOD`:

| tier | reach | flight | period | pulses in the air at once |
| --- | --- | --- | --- | --- |
| 1 | 1100 | **4.40 s** | 3.20 s | 1.4 |
| 2 | 1500 | **6.00 s** | 2.20 s | 2.7 |
| 3 | 1900 | **7.60 s** | 1.40 s | **5.4** |

Before the change tier 1 flew for 0.88 s against a 3.2 s period and nothing
overlapped. Now a far return from pulse *n* lands after pulse *n+1* has left, and
`_ping_age` is a single scalar — so the **drawn** wavefront restarts while the
previous one's marks are still arriving.

`outline_t3_ambiguity_720.png` is that frame: full vision at tier 3, t = 1.52.
The drawn wavefront is the small ring hugging the cell — 30 units out, from the
pulse at 1.40 — while the membrane is reporting a body at 220 units from the
pulse at 0.00. The picture says *the wave has just left*; the skin says *something
is out there*. One frame, two registers, contradicting each other.

It also takes §3.1 away: if the player cannot tell which pulse a mark belongs to,
arrival time stops meaning distance, and a third of this spec is selling a
reading that is not there. Three ways out, in §10 row 1.

---

## 8. Measurements

### 8.0 The frames are frames

Three byte-identical runs of

```
--mode=0 --seed=7 --genome=cytostome:1,cirrus:1,flagellum:1,ampulla:3:0 \
--cell=0,300,-35,80 --cell=1,1000,35,14 --freeze-at=1.52 --fixed-fps 60
```

differed by **0 pixels, 0 pixels, 0 pixels**. `--seed=` reaches the bus, so
everything below is a measurement and not weather (`perception.md` §4.1).

### 8.1 What a return looks like on the band

Violet only (`B − G`; the contour is teal and cancels), sampled around the
contour at 1° of bearing, excluding the wavefront arc and the soma figure.

| frame | peak | at | lit ≥50% | lit ≥25% |
| --- | --- | --- | --- | --- |
| **today**, r80 @ 300, tier 1 | 58 / 46 | −43° / −38° | 30° / 25° | 36° / 31° |
| **new**, r80 @ 300, tier 1 | 57 / 57 | −28° / −28° | **51° / 58°** | 64° / 71° |
| **new**, r14 @ 900, tier 1 | 26 / 27 | +38° / +41°³ | **28° / 26°** | 81° / 82°¹ |
| **new**, r80 @ 300, tier 3, hollow | 48 / 48 | −2° / −2° | **77° / 82°**² | 87° / 94° |

Each cell is 1280x720 / 2400x1080. ¹ includes the hum at the nose. ² across both
limbs; the pair's own geometry is in §3.4. ³ the field reported +45.5°; the hum at
the nose pulls the measured peak of the *sum* a few degrees toward 0, which is a
property of the measurement and of the picture alike.

The near body now lights **1.7× the angular footprint** at the same peak
brightness. The far body lights **half the width at half the brightness**. Today
those two frames differ only in where the blob sits, and by less than 5°.

### 8.2 The renders

All at `--seed=7`, `--fixed-fps 60`, `--rendering-driver opengl3`.

| file | what it shows |
| --- | --- |
| `base_pov_return_720.png`, `base_pov_return_1080.png` | **today**: one blob, and the wave already off screen at t = 0.95 |
| `base_vis_720.png`, `base_vis_1080.png` | **today**, full vision: the half-ring at 80 units |
| `outline_t1_near_720.png`, `outline_t1_near_1080.png` | tier 1, r80 @ 300: a broad 64° wash over the port bow |
| `outline_t1_far_720.png`, `outline_t1_far_1080.png` | tier 1, r14 @ 900: a compact dim mark at +45°, and the hum |
| `outline_t3_limbs_720.png`, `outline_t3_limbs_1080.png` | tier 3, r80 @ 300: **two limbs with a lit bridge** — the outline |
| `outline_vision_crossing_720.png`, `_1080.png` | full vision: the front inside the body at the instant the skin is lit |
| `outline_t3_ambiguity_720.png` | §7: the drawn wave at 30 units, the skin reporting 220 |
| `proto_hum20_720.png` | the hum alone, nothing arriving, mid-flight |
| `proto_replay.png` | the two-pane replay at `BLOCK_FLOATS` 45 |

They live in this session's scratchpad, listed with absolute paths in the handoff.

---

## 9. The `perception.md` wording

§4 currently reads as a prohibition. Proposed replacement, to be made in that file
when this ships:

> Phase 1 encodes *bearing* and *intensity*, and the first sensory gene adds
> *extent* — how wide a thing is, and how long the front takes to cross it.
> **This is a stage, not a rule.** A cell this early cannot resolve a form; it can
> feel that something is wide and near, or narrow and far, and that is the whole
> of what a tier-1 organ has earned. What is still unspent is *place*: no signal
> is yet drawn at the position of the thing that caused it, and the interior is
> still black. That is what the gene after this one sells, and it should feel
> enormous.

§3's signal-table row for the ping is replaced by the three constants in §3.3 and
the profile in §3.5. The `three-senses.md` §1.4 note that the returns "stay marks
on the contour" stays true and is now the point rather than a restriction.

---

## 10. Left open — owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | The slow wave means one pulse is still in the water when the next leaves (§7). Which way out? | (a) fire less often — 5.0 / 6.6 / 8.2 s between pulses; (b) **the better organ sweeps faster — 250 / 400 / 600 units per second ✓ recommended**; (c) leave it, and draw every wave at once | Right now a far answer can arrive after the next pulse has gone out, so you cannot tell how far away it was. (a) makes the best radar the slowest — eight seconds of silence between sweeps. (b) keeps the top tier feeling quick and keeps the slow wave where you asked for it, at the start. (c) is honest but the proof is only visible in the full-vision view. |
| 2 | How much does the organ exaggerate? `PING_RING` and the `WIDTH_GAIN` column are the two dials. | (a) bare geometry — 1.0 and 1.0; (b) **2.0 and 1.5 / 3.5 / 6.0 ✓ recommended**; (c) louder — 3.0 and 3 / 7 / 12 | Real sizes at real distances are under three degrees and a tenth of a second: honest, and you would feel none of it. (b) is the smallest exaggeration that makes a big near thing and a small far thing feel different. (c) makes the sense dramatic and starts telling a first radar more than a first radar should know. |
| 3 | Does a tier-3 ping draw its outline **inside** the membrane, at the place it actually is? | (a) **no — the interior stays black until the next gene ✓ recommended**; (b) yes, at tier 3 only | You said the cell must one day see. (a) keeps that moment for the gene that is *about* seeing, so it lands as an event. (b) spends it now, and the eye you grow later has nothing left to show you. |
| 4 | Two bodies inside one beamwidth merge into one wider, longer mark. Bug or ladder? | (a) **merge — it is the ladder ✓ recommended**; (b) always separate them | (a) means a crowd feels like one big thing until your radar gets better, which is how a real one behaves and what makes the next tier worth eating for. (b) is clearer and removes the reason to upgrade. |

---

## 11. A wrong comment worth deleting

`game/perception/signal_bus.gd`, at `PING_PEAK`:

> **It shares [constant LOBE_BEAM] with the ocellus** -- there are four glow
> lobes in the shader and a fifth is a new uniform and a new binary

`export_presets.cfg` is `export_filter="all_resources"` with
`exclude_filter="tools/*"`, so `membrane.gdshader` is inside the `.pck`. **A
shader uniform is a content change**: no new APK, no `binary_version` bump. The
sentence has been standing since phase 5 and it is the reason two senses share
one lobe today.

Nothing in this spec needs a launcher change, and no launcher problem was found
while writing it.

---

## 12. Rejected

- **Round-trip timing (`2d / speed`).** The owner is explicit that nothing
  bounces, and one-way is what the build already does. Doubling it would also
  double §7's problem.
- **A literal angular width.** §3.3: under 3° for every body at seeding distance.
  It is the honest number and it is invisible.
- **`HOLLOW` at 0.85.** Measured: the middle falls to 21% of the peak and one
  body reads as two. §3.4.
- **A bearing histogram uniform** — N bins around the contour, the outline drawn
  as a profile. It is the general answer and the expensive one: a texture or a
  large array, a write every frame, and what it buys — resolving more than two
  things at once — is exactly what tier 1 must *not* have.
- **Rescaling the point-of-view wavefront** so a whole 4.4 s flight fits on
  screen. §6.2: two distance scales in one picture.
- **Drawing the returns in the interior.** §4 and §10 row 3. That is vision, and
  it is the next gene's to sell.
