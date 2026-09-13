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

**~0:10 — the bump.** An inert mote is placed on the initial drift path. Contact
is a hard near-white flash of the whole contour plus a lingering bruise at the
contact bearing. The player learns: things exist out there, and hitting them has
a direction.

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
| nutrient taste | glow lobe 1, `Color(0.35,0.88,0.42,1)` | `smoothstep(0.06,1,c) * 0.62` | `lerp(78°, 26°, c)` | bearing low-passed 0.6s; jitter `lerp(22°,4°,c)` resampled 1.5Hz; off below c = 0.06 |
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

### Both targets

- No widgets in normal mode, so the 48px rule does not bite. Steering is drag
  (Android) or `A`/`D` and arrows (desktop) — both occupy zero pixels.
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

The rule to hold: **Phase 1 owns the outer 104px. The interior is currency.**

Phase 1 encodes only *bearing* (coarse, lagged, jittering) and *intensity*
(scalar). It never encodes position, distance, shape, count or identity. Those
are exactly what later genes sell, so the ladder has somewhere to go:

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

1. **One line of onboarding text.** A player on a phone facing a black screen
   with no widgets may never discover that dragging steers. I recommend exactly
   one line, first run only — `drag to turn` / `A · D to turn`, 18px,
   `Color(0.855, 0.953, 0.933, 0.55)`, lower third, fading over 0.8s the instant
   they first turn. It would be the only text in normal mode. It is a real dent
   in the fiction and the owner should decide, not me.
2. **Is the beat also the health readout?** Making beat rate double as starvation
   would be elegant and free, but it couples perception to survival tuning and
   that is a gameplay decision.
3. **The predator's escape window.** I have specced the *warning* — roughly 10s
   of dread, then a directional wake. Whether a slow cell can actually escape in
   that window is balance, and if it cannot, the warning is only cruelty.
4. **Where the synthesis / gene screen lives.** Same black membrane aesthetic, or
   a launcher-themed panel? That is the biggest remaining fork in the game's
   visual identity and it should be decided before that screen is specced.
