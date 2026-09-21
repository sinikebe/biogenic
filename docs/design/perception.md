# Perception before the first sensory gene

Phase 1. One decision: how a blind cell tells the player anything, without
lighting up a screen whose blackness is the whole point.

Status: shader and every signal state below were rendered under GL Compatibility
at 1280x720 and 2400x1080 and looked at. Numbers in this document are measured
off those renders, not intended.

## 1. The decision

**The edge of the screen is the cell's membrane.** The viewport is not a window
onto the water; it is the inside of the player's own body. Every signal is a
*sensation on the player's own skin* — a bearing relative to the cell's front,
never a position in the world. The interior of the screen stays at the base
colour and is reserved: it is the space vision will one day occupy, and it is
not spent now.

Two registers, physically distinct so they can never be confused:

| register | what it is | what it carries |
| --- | --- | --- |
| **contour** — a crisp ~9px line | the membrane itself | self (metabolism), impact, pressure |
| **band** — a ~104px diffuse wash bleeding inward | chemistry soaking through | taste: food, and later other flavours |

Chemistry *glows*. Mechanics *deform* — a pressure wave dents the contour
physically inward. A player does not have to be taught that a glow and a dent
are different kinds of event.

**Why this over the alternatives.** Audio is the natural answer for a blind game
and it is not available (see §5); it would also be mono on cheap Androids,
muted in public, and absent on a desktop with no headphones — it can carry
proximity but not direction, which is half of what is needed. Haptics is
Android-only, needs the `VIBRATE` permission and therefore a new binary, and is
switched off by a large fraction of players. Pure touch-on-collision cannot pass
either gameplay test: you would find food by random collision, and a predator
would announce itself by eating you. A chemical gradient is the right *fiction*
— chemotaxis predates vision by a billion years and is literally how a cell
finds food — but "smell" still needs an output channel, and on a screen that
channel is light whether we admit it or not.

So the channel is light, and the discipline is what keeps it honest: light is
only ever allowed on the player's own membrane, and only ever as bearing plus
intensity. Never a position, never a distance, never a shape, never a count,
never an identity. That single rule is what stops this becoming vision, and it
is what the first sensory gene will be selling.

**The split that protects the premise:** *bearing is a short-range sense; the
beat is the long-range sense.* At distance the player has nothing but hot-and-
cold. Direction only resolves as they close.

## 2. How it reads — the first 60 seconds

No tutorial. The opening is authored so the rules teach themselves in order.

**0:00 — the beat.** Black, with one crisp teal contour that brightens every
2.4s and fades. Nothing else. The player learns: the screen is not broken, the
edge is alive, that is me.

**0:04 — the first push.** The basic cell's random forward impulse fires. The
contour blooms at the top and the drift starts. The player learns: **top is my
front.**

**0:05–0:12 — they fiddle.** Any input turns the cell. Turning shears water
past the membrane, so a faint wash appears on the *outside* of the turn,
immediately, with no lag. This is the single most important moment in the
design: it is the proof that the player is connected to anything at all. The
player learns: I steer, and the skin answers.

**~0:06 — the bump.** An inert mote is placed 340px along the cell's *actual*
velocity once it is moving. Contact is a hard near-white flash of the whole
contour plus a lingering bruise at the contact bearing. The player learns:
things exist out there, and hitting them has a direction.

This was originally specced as a mote dead ahead at boot, on "the initial drift
path". That phrase means nothing before there *is* a drift: the heading wanders
between boot and arrival, and measured over 60 seeds the mote was missed roughly
two thirds of the time. Placing it along the real velocity vector lands it on 53
of 60 seeds, median 6.3s. It is still **likely, not authored** — one player in
eight gets no bump in the first 30 seconds, and it can land before the player
has turned, which inverts the intended order of the two lessons.

**0:12–0:30 — the beat quickens.** The staged food cell's chemical field is
entered. The beat period falls from 2.4s toward 1.6s. Turn away and it slows and
dims. This is hot-and-cold, and it is self-teaching because turning is the only
verb the player has.

**~0:30 — direction resolves.** Past a concentration threshold, a wide green
wash appears on one side of the band — 78° half-width, jittering, lagged. It
narrows toward 26° as they close. The player turns until it sits at the top and
rides it in.

**~0:45 — the reward.** Contact flash, then the one licensed exception: the
interior floods warm green and decays over 1.2s. It is the only time the middle
of the screen is ever lit, it has no spatial structure, and it is over quickly.
The player learns what the goal was.

**0:45–1:00 — the dread.** The predator enters. The field does not brighten —
**it drains.** The base shifts colder and darker, the contour desaturates toward
invisibility, and the beat becomes irregular. No bearing, no way to act, ten
seconds of the water simply being wrong. Then the first pressure wake: the
contour dents hard inward at one bearing with a hot white line. Now it has a
direction, and now the player can turn.

> **The shader has no term for "the contour desaturates".** That sentence
> described an effect nothing implemented: `dread` only mixes the base colour,
> so a first build rendered a full-strength contour on a drained field, which
> read as a bug. Dread therefore drains the *beat* instead, via a floor on beat
> strength — inverting this spec's own measured dread row, brightest
> `(7,26,26)`, implies a pulse of about **0.15**. The shipped constant is 0.2,
> which renders `(8,32,31)` against the measured `(7,26,26)`; it is ~30% high
> and should be trimmed to 0.15 when predators actually arrive. Nothing in
> normal mode fires `dread` yet, so this is inert today.
>
> **Compound floor warning.** Dread's floor multiplies with the starvation floor
> in §6.2, and at full dread *and* full starvation the beat lands at
> `0.35 × 0.2 = 0.07` — a contour of roughly `(4,13,16)` on a `(3,8,10)` base.
> That is precisely the "reads as a broken screen rather than as dying" failure
> §6.2 exists to prevent, arriving by a route §6.2 does not cover. Whoever
> builds the predator owns resolving it; do not let the two floors multiply
> unbounded.

The predator is the only thing in the game that makes the screen *darker*. That
is the whole horror of it.

## 3. Godot-ready detail

### Scene

```
game/perception/membrane.tscn
  CanvasLayer            "Membrane"      layer = 0
  └── ColorRect          "Field"         anchors_preset = 15 (full rect)
                                         mouse_filter = MOUSE_FILTER_IGNORE
                                         material = ShaderMaterial -> membrane.gdshader
```

`ColorRect` + one shader, not `Line2D`/`Polygon2D`: one draw call, resolution
independent, and the contour has to follow the real viewport shape, which the
shader gets for free. Set `rect_px` from GDScript on `resized` (and once in
`_ready`); nothing else in this layer touches the tree.

### Shader

`game/perception/membrane.gdshader`. This exact text compiled and rendered
clean under `--rendering-driver opengl3`; no `acos`, no derivatives, no
branches, no textures.

```glsl
shader_type canvas_item;

uniform vec2  rect_px = vec2(1280.0, 720.0);
uniform float inset_px = 28.0;      // keep the contour off notches/rounded corners
uniform float corner_px = 150.0;
uniform float band_px = 104.0;
uniform float line_px = 9.0;
uniform float wobble_px = 22.0;

uniform vec3  base_color  = vec3(0.023, 0.055, 0.05);
uniform vec3  dread_color = vec3(0.013, 0.030, 0.043);
uniform float dread = 0.0;

uniform float pulse = 0.0;
uniform vec3  pulse_color = vec3(0.12, 0.70, 0.58);

uniform vec4 glow_lobes[4];         // xy = bearing, z = cos(halfwidth), w = intensity
uniform vec3 glow_colors[4];
uniform vec4 press_lobes[2];        // xy = bearing, z = cos(halfwidth), w = push
uniform vec3 press_color = vec3(0.78, 0.94, 0.90);
uniform float push_px = 86.0;

uniform float flash = 0.0;
uniform vec3  flash_color = vec3(0.90, 1.0, 0.97);
uniform float ingest = 0.0;
uniform vec3  ingest_color = vec3(0.35, 0.88, 0.42);
uniform float gain = 1.0;

void fragment() {
	vec2 px = UV * rect_px;
	vec2 c  = rect_px * 0.5;
	vec2 d  = px - c;

	// Aspect-corrected bearing: a signal at 45 degrees lands at the same
	// relative screen spot on 16:9 and on 20:9. Screen y is down; front is (0,-1).
	vec2 bd = normalize(vec2(d.x / max(c.x, 1.0), d.y / max(c.y, 1.0)) + vec2(1e-5, 1e-5));

	float pushv = 0.0;
	for (int i = 0; i < 2; i++) {
		float w = smoothstep(press_lobes[i].z, 1.0, dot(bd, press_lobes[i].xy));
		pushv = max(pushv, w * press_lobes[i].w);
	}

	vec2 half_ext = c - vec2(inset_px);
	float r = min(corner_px, min(half_ext.x, half_ext.y));
	vec2 q = abs(d) - (half_ext - vec2(r));
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	sdf += pushv * push_px;

	// The contour must never read as a rectangle. bd.x and bd.y each sweep
	// -1..1 around the loop, so sines of them are seamless -- no atan, no seam.
	sdf -= wobble_px * (
		  0.55 * sin(bd.x * 3.1 + TIME * 0.23)
		+ 0.30 * sin(bd.y * 4.7 - TIME * 0.19)
		+ 0.15 * sin((bd.x + bd.y) * 7.3 + TIME * 0.31));

	float inner = smoothstep(-band_px, 0.0, sdf);
	float band  = inner * inner * (1.0 - smoothstep(0.0, 20.0, sdf));
	float line  = 1.0 - smoothstep(0.0, line_px, abs(sdf));

	vec3 glow = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float w = smoothstep(glow_lobes[i].z, 1.0, dot(bd, glow_lobes[i].xy));
		glow += glow_colors[i] * (w * glow_lobes[i].w);
	}

	float interior = 1.0 - smoothstep(0.0, 1.15, length(vec2(d.x / c.x, d.y / c.y)));

	vec3 col = mix(base_color, dread_color, clamp(dread, 0.0, 1.0));
	col += pulse_color * (pulse * (line * 0.50 + band * 0.05) * gain);
	col += glow * (band * gain);
	col += press_color * (pushv * line * 0.95 * gain);
	col += flash_color * (flash * (line * 1.0 + band * 0.22) * gain);
	col += ingest_color * (ingest * interior * 0.38 * gain);

	// 8-bit dither. Dim wide gradients on a near-black field band visibly
	// without it -- the tail of a faint lobe shows as a hard straight line.
	col += vec3(fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;

	COLOR = vec4(col, 1.0);
}
```

Unused lobe slots must be set to `Vector4(0, -1, 2, 0)` — `cos(halfwidth) = 2`
never fires. Phase 1 uses at most 2 glow lobes and 1 pressure lobe; the rest are
deliberate headroom.

### Bearings

A bearing is body-relative, measured clockwise from the cell's front, and
converted to a lobe vector as `Vector2(sin(a), -cos(a))`. Front `(0,-1)` is the
top of the screen; starboard `(1,0)` is the right. The display never rotates —
turning slides signals around the contour, which is exactly how the player
localises them.

### Signals

Colours are the launcher's own palette: `pulse_color` is its `rim_color`,
`base_color` is the boot splash and launcher background unchanged, so pressing
Play is a continuous cut with no flash.

| signal | uniform | value | half-width | envelope |
| --- | --- | --- | --- | --- |
| metabolic beat | `pulse` | 1.0 peak | — (symmetric) | attack 90ms, decay 420ms, period 2.4s → 0.55s as concentration rises |
| thrust bloom | glow lobe 0, `Color(0.12,0.70,0.58,1)` | 0.14 | 60° at bearing 0° | attack 60ms, decay 500ms, on each impulse |
| turn shear | glow lobe 0, `Color(0.12,0.70,0.58,1)` | 0.10 × `|ω|/ω_max` | 84° at ±90°, outside of the turn | no lag; decay 180ms |
| nutrient taste | glow lobe 1, `Color(0.35,0.88,0.42,1)` | `pow(clamp((c-0.02)/(0.70-0.02)),0.8) * 0.62`, faded in over 0.02 and suppressed 60% by dread | **a full ring, not a lobe**: `z` solved so its dimmest point is 0.22 of its brightest | no lag and no jitter at all; off below c = 0.02. **The bearing is the organ's own arc on this body, not a direction to food** — it decides which side of the ring is bright and nothing else. Silent without `chemocyte`, and `c` is `s / (s + SMELL_HALF)` where `s` is the facing-weighted sum over **every** source inside that organ's reach — superposition, then a receptor that saturates rather than clips. three-senses.md §2 and §7.5.2 |
| ping return | glow lobe 3, `Color(0.62,0.55,1.00,1)` | 0.55 × nearness **× what survived the shadows** | 17°/13°/10° by `ampulla` tier | attack 35ms, decay 260ms; one per body **that is not in a shadow** per pulse (three-senses.md §1), staggered by `distance / PING_SPEED` (250 -- a tier-1 edge return lands 4.4 s out) so a pulse reads as a sweep. The survival term is `ping_through + (1 - ping_through) × clear` once per body in the way, the cell's own hull included, so at tier 1 it is 1 or 0 and nothing else. **Shares lobe 3 with the `ocellus` beam, loudest wins** |
| pressure wake | press lobe 0 | `smoothstep(3.5r, 0.8r, dist)`, cap 0.95 | 34°, no jitter | attack 70ms, decay 260ms — it is a shock, it must be sudden |
| contact | `flash` | **0.80** | whole contour | attack 1 frame, decay 90ms; plus a 0.35 glow bruise at the contact bearing, decay 600ms |
| dread | `dread` | → 0.95 over ~10s | — | beat period jitters ±30% once `dread > 0.4` |
| ingest | `ingest` | 1.0 | — (radial, no structure) | attack 120ms, decay 1.2s; beat returns to 2.4s over 3s |

Cap `flash` at 0.80, not 1.0: at 1.0 it clips to pure `(255,255,255)`, which on a
dark-adapted eye reads as a UI error rather than a hard knock.

### Measured output

Sampled from the renders. The interior is the load-bearing number:

| state | screen centre (sRGB8) | brightest pixel |
| --- | --- | --- |
| rest, beat trough | (5, 13, 12) | (6, 14, 13) |
| rest, beat peak | (5, 13, 12) | (23, 113, 94) contour |
| nutrient far | (5, 13, 12) | (33, 113, 79) band |
| nutrient near | (5, 13, 12) | (78, 247, 157) band |
| pressure wake | (5, 13, 12) | (186, 255, 246) dented contour |
| dread | **(3, 8, 10)** | (7, 26, 26) |
| ingest | (39, 99, 53) | — the one exception |

The interior holds at `(5,13,12)` in every state but ingest. The screen is
black, measurably, and the predator makes it blacker.

**Before you sample a frame of your own, read §4.1.** The bus jitters off its
own generator, that generator was unseedable until recently, and two runs of one
command were never the same picture. **One of the two draws that made it so is
gone** — three-senses.md §2 deleted the taste jitter along with the bearing it
was vague about — and §4.1 is unchanged by that: the beat still jitters on every
frame of dread, so `--seed=` is still mandatory and three byte-identical renders
are still the thing to check before measuring anything.

The `nutrient near` and `nutrient far` rows in the table above were measured on
a lobe that no longer exists. Re-measured on the ring, as `green - blue` along
72 rays from the centre so the teal contour cancels: an r12 body at 300 units in
front of the nose peaks at **64** on the organ's arc and falls to 25 opposite
it; the same body behind the nose peaks at **37** and falls to 19. The ring does
not move between the two frames — only its brightness does, by 73%.

### Both targets

- No widgets on the *sensory* screen, so the 48px rule does not bite there.
  Steering is drag (Android) or `A`/`D` and arrows (desktop) — both occupy zero
  pixels.
- **The pause screen is the one exception**, and it is deliberate: it carries
  two buttons and the words `resume` and `leave`. A game whose only exit is the
  hardware Back button, on a screen with no widgets, strands anyone who taps it
  by accident. Pause is a separate surface from the sensory screen and the
  §6.1 "only text in normal mode" rule is scoped to the latter.
- **Phase 6 spends a second string on the sensory screen**, on the same label
  and for a bounded reason: `a sense grew · esc to place it`, once per life, at
  five seconds, held seven seconds. Taste is now a gene, so a run opens with no
  sense at all and one is granted free — and the alternative to naming it is a
  second heartbeat the player has never been taught to read. It is a notice
  rather than onboarding, so it shows on every run and not only the first.
  `genes-and-cilia.md` §11.3.
  The gap between those two buttons matters more than their size: 56 canvas px
  is about 5.3mm on a 2400x1080 phone, under the ~9mm a thumb needs, and the
  control directly below `resume` ends the run. They are separated by 48 canvas
  px so a low tap misses into dead space rather than leaving.
- **Nothing may ever be placed at the screen edge.** The edge is the sensory
  channel; a button there is a signal the player cannot read. Future HUD goes in
  the interior or nowhere.
- Pause is the Android back button (`NOTIFICATION_WM_GO_BACK_REQUEST`) and `Esc`
  on desktop. Both are free and neither costs a pixel.
- `inset_px = 28` keeps the contour clear of rounded corners and cutouts. Raise
  it from `DisplayServer.get_display_safe_area()` where that reports an inset.
- **Reflow:** at 2400x1080 the canvas is 1600x720 (`expand` scales by 1.5 on
  height). Everything is anchored to the viewport edge and the middle is empty,
  so the contour simply widens and the black interior grows. Nothing is centred,
  so nothing can collide. Verified at both sizes.
- One `gain` uniform, exposed later as a "membrane sensitivity" setting. Dim
  greens on a phone in daylight are the one real risk this design carries, and
  gain is the escape hatch. Ship at `1.0`.

### What the engineer builds to prove it

`game/perception/membrane_probe.tscn` — no gameplay, just the layer plus a
driver that cycles the states: `rest`, `turn`, `nutrient far`, `nutrient near`,
`wake`, `contact`, `dread`, `dread+wake`, `ingest`. Photograph each with
`tools/shot.tscn` at 1280x720 and 2400x1080 before any gameplay is wired to it.

Drive the shader through **one signal bus** — a single node that takes events
(`taste`, `shove`, `hit`, `dread`, `ingest`) and owns all the envelopes. Nothing
else writes shader uniforms. This is what makes §5 cheap.

## 4. What this forces later

> **There are now two modes, and this document describes one of them.**
> *Point of view* is everything below: the membrane, and only what the cell can
> feel. *Full vision* draws the water underneath it — the cell, the motes, where
> things actually are — and leaves the membrane running on top.
>
> Full vision exists to check that point of view is telling the truth: that a
> bruise lands on the bearing the mote really was on, and later that a taste
> wash really points at the food. Measured on the first build, reported and
> rendered bruise bearings agreed within 4.2°, and the bearing the field
> computed reached the bus exactly.
>
> **Both modes run the same simulation.** If a view ever changes how the cell
> behaves, full vision stops being evidence about point of view and there is no
> reason to have two. Nothing in `game/vision/` writes to the simulation, and
> nothing that reaches the signal bus carries a world position — the mote's
> position travels on `motes.struck` and is dropped before the bus sees it.
>
> Everything below is the point-of-view rule. Full vision spends the interior on
> purpose; that is not a licence to spend it here.

The rule to hold: **Phase 1 owns the outer 104px. The interior is currency.**

Phase 1 encodes *bearing* and *intensity*, and the first sensory gene adds
*extent* — how wide a thing is, and how long its echo takes to pass. **This is a
stage, not a rule.** A cell this early cannot resolve a form; it can feel that
something is wide and near, or narrow and far, and that is the whole of what a
tier-1 organ has earned. What is still unspent is *place*: no signal is yet
drawn at the position of the thing that caused it, and the interior is still
black. That is what the gene after this one sells, and it should feel enormous.

> **This paragraph used to be a prohibition** — *"it never encodes position,
> distance, shape, count or identity"* — and was read as one for seven phases.
> The owner said plainly it is a statement about how far the cell has developed,
> and `ping-as-outline.md` §0 records that; the replacement above is that file's
> §9, made here now that the outline has shipped. Two decisions were taken
> against the old wording and both went the conservative way: the interior stays
> black until the gene that is *about* seeing (§10 row 3 there), and the
> twenty-beam outline is allowed at tier 3 for the `ocellus` alone
> (`three-senses.md` §8 row 3) — allowed, and not yet built.
>
> **Distance is encoded now, twice, and both are honest.** A ping mark's level
> falls with range, and its arrival time is the round trip — `2d / PING_SPEED`,
> because the wave bounces. Neither is a *place*: a bearing with a distance on it
> would be one, and the pair never reaches the bus together in a form that can be
> recombined. `ping-as-outline.md` §0 is the four-scalar rule that keeps it so.
>
> One thing this paragraph said has gone the other way and is now simply true of
> smell: **taste no longer encodes a bearing at all.** three-senses.md §2 made
> it a level, and the direction it used to carry was the last thing on the
> membrane that told a blind cell where something was without the player having
> to turn to find out.


- **First sensory gene (eyespot / photoreceptor):** a new glow lobe in slot 2,
  in a colour not yet used — light is not chemistry and must not look like it.
  It is sharper (half-width ~20°) and does not jitter. It still lives on the
  rim. This is the moment the player learns that direction can be *certain*.
- **The gene after that** is what buys the interior: a signal drawn *inside* the
  contour, at a place. That is the first true image, and it should feel enormous
  because the interior has been black for hours.
- Later flavours (a second food type, a second predator) take glow slots 2 and 3
  and the second pressure slot. That is why four and two are specced, not two
  and one.
- Nothing about §3 has to change to add any of this. New signals are new lobes
  on the same bus.

### 4.1 The bus has its own generator, and a measurement has to seed it

**Read this before measuring anything on a membrane frame.** It voided
measurements in this repository for five phases and nobody noticed, because the
failure is quiet: the numbers come out, they are just not the numbers of the
thing being measured.

`signal_bus.gd` draws its beat jitter from a **private**
`RandomNumberGenerator` — it drew the taste jitter from the same stream until
three-senses.md §2 deleted that jitter, and one draw is as unseedable as two —
and that is deliberate and must stay — the bus is a
view, `Membrane` is `process_mode = 3` so it keeps stepping through a pause, and
a view drawing off the simulation's stream is what once made how long you left
the pause screen open change where every cell in the water was.

What did not follow, and was assumed to: **private did not mean seeded.**

- `RandomNumberGenerator.new()` seeds itself from the system at construction.
- The global `seed()` — which is what `tools/drive.gd --seed=` called — sets the
  *global* stream and cannot reach an instance generator.
- So `--seed=` covered the simulation and never covered the picture of it.

It is not an edge case. The taste jitter is drawn every 1/1.5 s **from t = 0 in
every run**, unconditionally; the beat jitter joins it as soon as dread crosses
0.05, and the beat jitter moves the *whole contour*, not a detail of it.
Measured on three byte-identical runs of one `--stalk=150 --gain=2.4
--freeze-at=6.0 --fixed-fps 60` command: **288,380 to 321,940 differing pixels
of 921,600 — up to 34.9% of the frame — with a maximum luminance delta of 125.**
Any A/B whose own effect is smaller than that was measuring weather.

**And you cannot tell which frames are affected by reading the command.**
The same `--stalk=150 --gain=2.4` with a forced `stigma:3` genome and
`--freeze-at=8.0` measured stable to the pixel over three unseeded runs, because
a saturated dread lobe had swallowed the contour the jitter moves — same
harness, same kind of frame, opposite answer. That is the argument for checking
rather than for judging.

**The rule.** A measurement on a rendered membrane frame is only a measurement
if the same command renders the same frame. `tools/drive.gd` now calls
`signal_bus.gd`'s `seed_rng()` from `--seed=`, so:

> **Pass `--seed=` to every render you intend to compare against another
> render.** Without it the bus keeps its system seed — which is the right
> default for a player and the wrong one for a number. Prove reproducibility
> before quoting a difference: run the frame three times and diff. It is one
> command and it is the difference between evidence and a coincidence.

`seed_rng()` does not draw from the global stream to seed itself — that would
advance the simulation's own sequence and make the act of measuring change the
run. The seed is passed in, so a harness that wants both locked together passes
one number to both, which is what `--seed=` does.

Everything in `diegetic-hud.md` §4, `gene-lines-and-the-pause-target.md` §4.3
and `controls.md` §3.2 was measured before this existed. The rankings in them
survived re-measurement; the absolute figures did not, and `controls.md` §3.2
is the one that was rewritten to state its own method.

## 5. Audio and haptics — not needed, but keep the door open

**This design does not need audio, and I am not asking for it to be reopened.**
The membrane works identically on both targets, needs no permission, no new
binary, no sound designer, and no headphones.

But it is worth saying plainly what is being given up. A blind game wants sound,
and the cost of adding it later is small *provided* the signal bus in §3 exists:
audio becomes a second subscriber to the same `taste`/`shove`/`hit` events, with
no change to the visual layer. Same for haptics — Android vibration costs one
`VIBRATE` permission and therefore one `binary_version` bump, so it should ride
along the next time something else forces a new binary rather than triggering
one on its own.

Do not let either become load-bearing. They are reinforcement for a channel that
already works, which is the only way a channel that is mono, muted, disabled or
absent on some fraction of devices can be used at all.

## 6. Left open — owner's call

1. ~~One line of onboarding text.~~ **DECIDED: yes, one line, first run only.**
   `drag to turn` / `A · D to turn`, 18px, `Color(0.855, 0.953, 0.933, 0.55)`,
   lower third, fading over 0.8s the instant they first turn, never shown again.
   It is the only text in normal mode — do not let a second string join it.
2. ~~Is the beat also the health readout?~~ **DECIDED: yes, beat rate is hunger.**
   The metabolic beat slows and weakens as the cell starves; one signal carries
   both "I exist" and "I am running out".

   This is a deliberate coupling, so treat it as one: **hunger is now a
   perception parameter, not just a survival number.** Any change to starvation
   balance changes how the game reads, and any change to the beat envelope
   changes how legible starvation is. Keep the mapping from hunger to beat rate
   in exactly one place so the two can be reasoned about together, and expect
   the floor to matter most — a beat that decays to nothing leaves the player
   with no membrane at all, which reads as a broken screen rather than as dying.
3. **The predator's escape window.** I have specced the *warning* — roughly 10s
   of dread, then a directional wake. Whether a slow cell can actually escape in
   that window is balance, and if it cannot, the warning is only cruelty.
4. **Where the synthesis / gene screen lives.** Same black membrane aesthetic, or
   a launcher-themed panel? That is the biggest remaining fork in the game's
   visual identity and it should be decided before that screen is specced.
