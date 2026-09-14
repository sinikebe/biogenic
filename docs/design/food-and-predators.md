# Food and predators

Phase 4. One food, one predator, both "other cells". The predator is inedible
*for now* — not by species, by size.

Extends `perception.md`; does not revisit it. Every number below was rendered
under GL Compatibility at 1280x720 **and** 2400x1080 and looked at. Where this
document contradicts `perception.md` it says so and gives the measurement.

Phase 5 (the gene roll on eating) is out of scope. `ingest` lands here and the
hook is named in §3.4.

## 1. The decision

The cell already has two chemical senses it cannot tell apart by looking:
food is chemistry and the predator is chemistry. They are separated by making
them **opposite on every channel**, starting with a channel that costs no light
at all.

| | **food** | **predator** |
| --- | --- | --- |
| long range | beat **quickens**, evenly | beat **stumbles** — the rhythm breaks |
| mid range | green band wash appears | base **drains**, taste muffles and wanders |
| close | wash narrows, beat races | white **dents**, hard, from one bearing |
| contact | interior floods green | membrane closes and you are gone |

Read down either column and it is unambiguous within two or three beats. The
rule in one line: **food quickens you; the hunter makes you stumble.**

This is the mechanism §2 of `perception.md` promised ("the field does not
brighten — it drains") with one correction: **draining is dread's second tell,
not its first.** A darker base takes twenty seconds to become visible and is
worth 5 sRGB units when it does. Arrhythmia is legible in three beats, at any
brightness, on any screen, in daylight. So dread arrives as a *timing* failure
and only later as a *light* failure. That reordering is what makes §6.2's
"reads as a broken screen rather than as dying" avoidable — see §5.1.

**Taste stays a short-range sense.** The beat is the long-range one. Nothing
below gives the player a position, a distance, a shape, a count or an identity.

## 2. Foraging, and why it works inside that rule

Food emits a scalar field. The cell reads two things from it and nothing else:
its **total** (→ beat rate) and its **gradient bearing** (→ band wash).

| distance | c | beat, fed | taste lobe |
| --- | --- | --- | --- |
| 1600 | 0 | 2.40s | — |
| 1400 | 0.016 | 2.17s | — |
| 900 | 0.037 | 2.04s | — |
| **680** | **0.060** | 1.95s | **appears, 75°** |
| 420 | 0.136 | 1.72s | 71° |
| 250 | 0.329 | 1.34s | 61° |
| 170 | 0.634 | 0.93s | 45° |
| 130 | 1.0 | 0.55s | 26° |

The whole outer kilometre is hot-and-cold with no direction in it. Direction
resolves at 680 units — about twelve seconds of swimming — and is still 71° wide
at 420. It only becomes a real bearing on the approach.

**That makes foraging run-and-tumble, which is what a cell actually does.** The
player's only verb is turning; the cell fires its own impulses. So the loop is:
turn, wait for an impulse, *did the beat quicken?* Keep the heading or change it.
Nothing teaches this — it is the only thing that can be done, and it works.

**Concentrations sum; bearings average.** Two sources either side give a bearing
that points between them, at a strength neither one has. Swimming into the middle
and finding nothing is a correct outcome of a crude sense and should not be
designed out.

### 2.1 Hunger and food must not collapse into the same reading

`metabolism.beat_period()` currently nests the two lerps, so a starving cell in
rich food beats at 0.55s — exactly as fast as a healthy one. Make the food term
a **multiplier**:

```gdscript
func beat_period() -> float:
    var starved := lerpf(REST_PERIOD, STARVED_PERIOD, hunger)
    return starved * lerpf(1.0, RICH_PERIOD / REST_PERIOD, sqrt(clampf(concentration, 0.0, 1.0)))
```

A starving cell's fastest possible beat becomes 1.10s against a fed cell's 0.55s.
The player learns "my best beat is getting worse" — starvation stays readable
*through* a meal, which is when they most need to know. One line, same file, and
§6.2's rule that the mapping lives in exactly one place is preserved.

## 3. Food

### 3.1 The cell

Smaller than you, passive, does not flee. `radius` 14–20. Drifts at ~9 units/s
on a slow random walk, so it is never a fixed target but never a chase either.
Phase 4 has one flavour; fleeing prey and a second flavour are later glow slots.

### 3.2 The field — `game/normal/food.gd`

```gdscript
const COUNT := 4
const RADIUS_MIN := 14.0
const RADIUS_MAX := 20.0
const DRIFT_SPEED := 9.0

## Inverse-power falloff, the shape a diffusing metabolite actually has.
const CORE_RANGE := 130.0      # c = 1 at or inside this
const SCENT_RANGE := 1600.0    # c = 0 at or outside this
const SCENT_FALLOFF := 1.7
const SCENT_WINDOW := 250.0    # smooth the outer cutoff so it cannot pop

## Ring placement, exactly like motes.gd: recycled to the far edge when culled.
const RING_MIN := 800.0
const RING_MAX := 2200.0
const CULL := 3000.0
## Authored, like mote 0: placed along the cell's real velocity once it moves,
## just outside scent range, so the beat quickens at about 0:12 as §2 wants.
const FIRST_DISTANCE := 2200.0

func scent(d: float) -> float:
    if d >= SCENT_RANGE:
        return 0.0
    var v := pow(CORE_RANGE / maxf(d, CORE_RANGE), SCENT_FALLOFF)
    return minf(1.0, v * smoothstep(SCENT_RANGE, SCENT_RANGE - SCENT_WINDOW, d))
```

Per frame, the field posts one taste and sets the metabolism's concentration:

```gdscript
var total := 0.0
var pull := Vector2.ZERO
for f in _food:
    var c := scent(_cell.position.distance_to(f.position))
    if c <= 0.0:
        continue
    total += c
    pull += (f.position - _cell.position).normalized() * c
total = minf(total, 1.0)
metabolism.concentration = total
if total > 0.0 and pull.length_squared() > 0.0:
    bus.taste(_cell.bearing_to(_cell.position + pull), total)
else:
    bus.taste(0.0, 0.0)
```

### 3.3 The economy

```gdscript
const HUNGER_SECONDS := 420.0   # was 1800; nothing could feed the cell before
const MEAL := 0.50              # one food cell
```

Seven minutes fed-to-starved, two meals to fill. Competent foraging is a meal
every 60–90 seconds, so the bar is usually somewhere in the middle and the beat
is usually saying something. **Move `HUNGER_SECONDS` first if the pace is wrong;
`MEAL` sets how much one success is worth and should stay near half a bar so a
single meal is felt and two are needed.**

Eating at full does not waste the food: it still fires `ingest` and still rolls
the gene. There is always a reason to eat.

### 3.4 The moment of eating, and the Phase 5 hook

On `d < cell.radius + food.radius`:

```gdscript
## Nutrition, the rolled gene, and where it happened. `at` is for the full-vision
## view only and MUST be dropped before the bus -- the same contract as
## motes.struck. In phase 4 `gene` is always &"".
signal eaten(nutrition: float, gene: StringName, at: Vector2)
```

`normal_mode.gd` then, in this order: `bus.ingest()`, `metabolism.feed(MEAL)`,
`cell.radius += GROWTH_PER_MEAL`, recycle the food cell. Phase 5 subscribes to
`eaten` and needs no refactor. `ingest_color` is already a uniform, so a gene can
tint the flood.

**Eating while hunted is safe to read, and that is measured, not assumed.** The
interior flood is `ingest * interior * 0.38`; `interior` has decayed to 0.08 by
the contour, so the rim is untouched (measured: the ingest frame's brightest
pixel is the *contour* at `(27,123,99)`, not the flood). A pressure wake lands at
`(185,238,229)` straight through it. No extra term needed.

## 4. The predator

### 4.1 What makes it inedible — and what makes "yet" real

**You can eat anything smaller than you. Anything bigger can eat you.** One
comparison, no species tag. The predator never changes; the player does.

```gdscript
# cell.gd: RADIUS stops being a const.
var radius := 26.0
const GROWTH_PER_MEAL := 0.5
# predator.gd
const RADIUS := 40.0
```

Two consequences worth having now:

- **Dread scales with the ratio**, `smoothstep(0.85, 1.35, predator.radius / cell.radius)`.
  At 26 that is 1.0. The player *feels themselves stop being afraid of it* long
  before they can eat it. That is the best available readout of a growth curve on
  a screen with no numbers on it.

  > **Arithmetic correction, found when built.** This section said "at 34 it is
  > 0.44". `smoothstep(0.85, 1.35, 40/34)` is **0.72**; 0.44 is reached at cell
  > radius ≈ 37. The formula is what ships and it is the right shape — the
  > annotation was simply mis-evaluated. Dread is still meaningfully down by 34,
  > just not as far as the number claimed.
- When the ratio crosses 1.0 the predator's chemistry stops blocking and starts
  tasting, in **glow slot 3** (slot 2 stays reserved for the eyespot, per §4 of
  `perception.md`), in a colour not yet used. **Specced, not built.** 28 meals is
  well over an hour at Phase 4 rates; Phase 5's genes are what make the arc real,
  and they will rebalance `GROWTH_PER_MEAL`. Ship the comparison anyway — it
  costs one variable and it is what stops the predator being scenery.

### 4.2 How it makes itself known

Two channels, neither of which is a position.

**Dread** — its metabolites saturate the chemoreceptor. Scalar, no bearing, *by
mechanism*: a blocked receptor has no differential to read a direction from.

```gdscript
const DREAD_RANGE := 1400.0
const DREAD_CORE := 240.0
const DREAD_CAP := 0.95
var near := clampf((DREAD_RANGE - d) / (DREAD_RANGE - DREAD_CORE), 0.0, 1.0)
bus.dread(near * threat_ratio * DREAD_CAP)
```

Dread also **costs** something, which is what stops it being mood: it suppresses
taste to 40% and doubles the taste bearing's jitter (§5.3). A hunted cell cannot
smell its way out of the problem. That is the point.

**The pressure wake** — one dent per stroke of its flagellum, at its true
bearing. This is the only directional information the predator ever gives, and
it is intermittent by construction: each wake says where it *was*, 1.45s ago.

```gdscript
const WAKE_RANGE := 760.0
const WAKE_CORE := 170.0
const STROKE_GAP := 1.45         # +/- 0.35, resampled each stroke
const LUNGE_RANGE := 220.0       # inside this, gap halves and strength pins
bus.shove(cell.bearing_to(position), smoothstep(WAKE_RANGE, WAKE_CORE, d) * SignalBus.WAKE_CAP)
```

No bearing jitter — §3 of `perception.md` specced none and it is right. The
imprecision is in the *interval*, not the angle.

> `perception.md` §3 gives the wake as `smoothstep(3.5r, 0.8r, dist)`. Written
> before there was a predator, that is 140 → 32 units: kissing distance.
> Superseded by the absolute ranges above.

The gap between the two ranges is deliberate: 1400 → 760 is about nine seconds of
closing, which is §2's "ten seconds of the water simply being wrong. Then the
first pressure wake." Dread is at ~0.55 when the first wake lands and keeps
climbing through the chase.

### 4.3 Speed, and what dread actually means

Simulated over 40 seeds of the shipped drive model: the cell nets **56.5 world
units/s** with no steering, and takes **median 5.6s / p90 6.6s** to get its
*velocity* 90° off its previous bearing at full steer — 6.0s / 6.9s for 120°.

```gdscript
const CRUISE := 68.0    # 1.20x the cell
const LUNGE := 96.0     # 1.70x the cell
```

**You cannot outswim it. Therefore dread does not mean "flee".** It means
*commit away from that bearing now, before it lunges.* The predator holds a
bearing and must re-acquire; a cell that turns hard and keeps turning is not
where the lunge goes.

## 5. The four parked problems

### 5.1 The compound floor — solved by one rule, in one place

Dread drains the beat; starvation drains the beat; they multiply. At full both,
`0.35 x 0.2 = 0.07`.

**The rule: dread is the dimmest the game is ever allowed to be, and nothing may
compound past it.** One clamp, in the one place the composite is computed:

```gdscript
func beat_strength() -> float:
    return maxf(_beat_amplitude * lerpf(1.0, DREAD_BEAT_FLOOR, _dread), DREAD_BEAT_FLOOR)
```

The floor **is** `DREAD_BEAT_FLOOR` — not a second constant that can drift away
from it, and unbreakable by the third and fourth stressor Phase 5 will add.

Rendered, at both sizes:

| starving **and** hunted | brightest | base |
| --- | --- | --- |
| unfixed (`0.35 x 0.1925 = 0.067`) | **(5, 15, 17)** | (3, 7, 10) |
| fixed (floored to 0.15) | **(6, 23, 23)** | (3, 7, 10) |

The unfixed frame is a ghost of a contour on black — the failure §6.2 exists to
prevent. The fixed one is a continuous, readable membrane. Starvation still costs
about 22% of the beat under dread (0.15 against 0.1925), so the two states are
not bit-identical, but it can never cost more.

**And the rest of the answer is that this moment does not compete on brightness
at all.** Three things carry it, none of them luminance:

- **rate** — hunger owns the beat period and dread does not touch it, so
  starvation stays fully legible while hunted (4.8s against 2.4s)
- **rhythm** — dread owns the stumble, which reads at any brightness
- **the wake is never dimmed.** `press_color * pushv * line` is independent of
  `pulse`. Measured on the exact compound frame: contour `(5,22,22)`, wake
  **`(185,238,229)`**.

At the moment the player can see least, the one thing they can see is where the
predator is. That is the design, not a rescue.

### 5.2 `DREAD_BEAT_FLOOR` → 0.15

Confirmed by render, not by inference. At 0.2 the dread frame measures
`(8,31,30)`; `perception.md`'s own dread row is `(7,26,26)`. At **0.15** it
measures **`(7,27,27)`** — the spec's number, within a unit. Ship 0.15.

### 5.3 Dread in full vision — do nothing, and here is why

The premise of the question is measurably half wrong. Full vision composites
additively, so dread's base drain does not reach the *drawn* world — but it
reaches the empty water exactly as hard as it does in point of view, and it
takes the membrane contour down with it:

| full vision, 1280x720 | water ground | membrane contour |
| --- | --- | --- |
| calm | (5, 15, 14) | (20, 95, 80) |
| dread 0.95 | (3, 7, 10) | (6, 22, 23) |

Side by side the two frames are obviously different states, and the world stays
completely legible in the dread frame. **Dread is already carried into full
vision by the contour and the ground, for free, and nothing should be added.**

The principle underneath: **point of view loses information when afraid; full
vision never does, because losing information is the one thing it exists to
detect.** Darkening the world view would hide the predator on the only screen
built to check that the membrane is pointing at it.

If the owner wants fear in full vision anyway, the cheap version is one uniform —
lerp `water_tint` from `(0.10,0.62,0.52)` toward a cold `(0.10,0.30,0.42)` with
dread. It drains the water's colour without taking any brightness off the
predator. Not recommended; recorded.

### 5.4 The escape window — `ESCAPE_SECONDS = 7.0`

Stated as a **contract on the game, not a parameter of the AI**, so it is
testable however the pursuit is implemented:

> From the moment the cell's steering is committed more than 90° away from the
> last wake bearing and stays committed, dread must begin falling within
> `ESCAPE_SECONDS`, and the predator must break off. A cell that does nothing
> must be caught.

7.0 is not a guess: it is the p90 time for the shipped drive model to swing its
velocity 120° (6.9s). **The window cannot be made shorter than about six seconds
— the cell physically cannot turn faster than that** — so anything below 7 makes
dread cruelty by arithmetic.

It is not free. Seven seconds of full-rate turning is seven seconds not foraging,
travelling away from the food, with taste suppressed and dread still rising. The
difficulty is not the turn, it is reading the wake correctly under pressure and
not wavering — the wakes are 1.45s apart and 34° wide, and a player who changes
their mind at the fourth wake has spent the window. Once the lunge starts at 220
units the encounter is over in 2.3s, so the skill being tested is **committing
early**.

Suggested implementation, not binding: hold a bearing for `LOCK_SECONDS = 7.0`,
re-acquire only if the cell is within `LOCK_CONE = 70°` of the predator's own
heading at re-acquire.

### 5.4.1 What was built, and what it measures

Implemented as `game/normal/predator.gd`, and measured headless over 14 seeds
per case with `tools/drive.gd --hunt=900`, against two scripted players: one that
never steers, and one that plays the contract above (`--evade`: full steer away
from the last wake bearing until it is 130° astern, then hold, with hysteresis so
it cannot waver).

| | caught | escaped |
| --- | --- | --- |
| never steers | **11 / 14** | 3 |
| commits away and holds | 1 | **13 / 14** |

The asymmetry is the mechanic and it is large. Doing nothing kills you; reading
the wake and committing away from it saves you.

Four things carry it, and only the first is in the original text:

- the pursuit solution is up to `LOCK_SECONDS = 7.0` stale inside wake range
- the attack run **commits at `COMMIT_RANGE = 420`**, not at `LUNGE_RANGE`. This
  is the number the whole dodge lives in and it had to be found by measuring:
  committed at 220 the run is only 2.3s long, a full-steer cell curves about 87
  units off the straight prediction, and the two bodies are 66 wide — so a
  committed turn missed by too little and was eaten about a third of the time.
  Committed at 420 the run is 4–5s, the curve is ~240 units, and it is a clean
  miss. Shipped at **310**, which is where a cell swimming straight still gets
  caught 11 times in 14 and a turning one escapes 13 times in 14; at 420 the
  passive catch rate collapses to 5 in 14, which breaks the other half of the
  contract.
- one missed pass ends the encounter. The run is over the moment the frozen aim
  point is behind the predator, and it sheers off then.
- `LOST_GROUND = 90.0`: a run that stops gaining is over too.

**Where the contract as written is not met.** "Dread must begin falling within
`ESCAPE_SECONDS`" is not achievable by an honest pursuit, and this is arithmetic
rather than tuning: the predator is 1.2× the cell's speed, so committing away
creates no distance, and relief can only arrive when a pass has *failed*. Across
the 13 escapes the measured delay from the first evasive input to dread falling
is **7–24s, median about 15s**. The commitment is what causes the escape — it is
just paid off one failed pass later, not within seven seconds.

Two levers if that is too long: drop `RUSH_SECONDS` (24.0) toward 12, which caps
it directly at the cost of letting some passive cells go; or narrow
`LOCK_CONE_DEG` below 70, which makes the hunter give up on geometry sooner.
Both trade against "a cell that does nothing must be caught". Recorded, not
taken — this is the one number in the encounter that should be settled by
playing it rather than by measuring it.

**If playtesting says it is wrong:**

- *Too hard* — drop `ESCAPE_SECONDS` to 5.0 and widen the course correction the
  predator cannot make. **Do not slow the predator below 56.5 u/s.** That turns
  the whole mechanic into "swim away" and deletes the dodge.
- *Too easy* — **do not raise `ESCAPE_SECONDS`.** Longer dread is longer taste
  blackout, which starves the player for being good at the game. Let the predator
  re-acquire **once**, after a 6s break. The encounter gets longer in events, not
  in dread.

## 6. Death

There are two, and they feel opposite.

### 6.1 Starvation — quiet

`hunger` reaching 1.0 starts `STARVE_GRACE = 40.0` seconds. The beat *strength*
stays on its floor throughout — the floor rule has no exceptions — and only the
**period** stretches past it, toward `DYING_PERIOD = 7.5s`. Rate is free; it
costs no light and nothing else is using it at that moment.

That gives the last forty seconds a signature nothing else has: intervals long
enough that you sit waiting, wondering whether it is coming back. It has been
telegraphed for minutes; the grace exists so that food ten seconds away is still
worth swimming for.

**And then the last one does not come.** The end of the grace closes the same
aperture §6.2 closes, `FAINT_COLLAPSE = 2.60s` against predation's 0.75, with no
white in it at all: the light on the shutting membrane is one final beat at
exactly the strength `beat_strength()` was already returning, fading out across
the close and the `FAINT_BLACK = 1.20s` after it. Rendered at both sizes, the
two deaths are the same geometry at opposite temperature and tempo — a teal
aperture sinking shut against a white one slamming. Measured mid-close:
`(10,36,31)` quiet against `(231,255,255)` loud.

The first build let the quiet collapse be lit by whatever the last beat had left
behind, and when the death landed between beats the membrane shut in the dark
and the screen simply went out. Floor it with `beat_strength()`; that constant is
already floored, so a quiet death cannot be invisible however starved and however
hunted the cell was.

### 6.2 Predation — loud

The predator reaches `cell.radius + predator.radius`. Then, and this is the one
other time the interior is spent:

| t | what |
| --- | --- |
| 0.00 | `hit` at the strike bearing. Flash 0.80 + bruise — the sensation they already know |
| 0.15 | **the collapse.** `inset_px` ramps 28 → **300** over `DEATH_COLLAPSE = 0.75s` on `t²`, `flash` held at 0.80, every glow lobe idled |
| 0.90 | `DEATH_BLACK = 0.35s`: `flash` → 0, `base_color` and `dread_color` → `(0,0,0)` |
| 1.25 | `DEATH_HOLD = 1.80s`. Nothing. Measurably nothing — rendered `(0,0,0)` |
| 3.05 | **the invitation** (§6.3). The black holds here until the player touches it |
| tap + 0.90 | `DEATH_RETURN = 0.90s`: colours and `inset_px` back, new cell, new water, hunger 0, first beat on arrival |

No text, no button, no new screen.

**Why `inset_px` and not `push_px`.** Pushing the SDF offsets a rounded box by a
constant, so once the push passes `corner_px = 150` the radius goes negative and
the contour becomes **a hard-cornered rectangle** — rendered, and it is exactly
the thing §1 of `perception.md` forbids. Raising `inset_px` shrinks `half_ext`,
and `r = min(corner_px, min(half_ext.x, half_ext.y))` shrinks with it, so the
shape passes through stadium to slit and is never a rectangle. Rendered at both
sizes: a white, wobbling aperture closing on the middle of the screen.

Two details found by looking at it:

- Drive the white from **`flash`, not a pressure lobe.** A pressure lobe adds its
  own constant offset and reintroduces the rectangle.
- **Keep `wobble_px` at 22 all the way down.** Fading it to 0 was tried; the
  closing shape becomes a perfectly regular stadium and reads as a progress bar.
  At full wobble it reads as an organism.

Measured at `inset_px = 300`: brightest `(229,255,254)`, both sizes.

### 6.3 What happens next — it waits for a tap

**Owner's decision, replacing the auto-restart in §9.1.** The black holds until
the player touches the screen, presses a key or clicks. There has to be a place
to put the phone down, and the end of a run is it.

That creates the one problem auto-restart did not have: on a near-black screen
with no widgets, how does anyone know a tap is wanted? §6.1 of `perception.md`
allows exactly one line of text in normal mode and this does not get to spend it,
so the invitation has to be made of membrane.

**The invitation is the beat, still trying, and failing to open the shut
membrane.** After `DEATH_HOLD` the closed aperture breathes on the cell's old
rest period of 2.4s: `pulse` rises to 0.62 on a heartbeat envelope — fast in,
slow out, then a silence longer than the sound — and `inset_px` lifts 34px off
`DEATH_INSET`, parting the slit and losing it again. It ramps in from half
strength over `INVITE_RISE = 6.0s` and then repeats forever without ever
resolving, which is what separates a screen that is waiting from a screen that is
still playing.

Rendered at both sizes: black between breaths (`(0,2,1)` at the trough) and
`(11,60,50)` at the peak of a late one, on a field that is `(0,0,0)` everywhere
else. The slit's height swings 120 → 188 canvas px, identical at 1280x720 and
2400x1080 because it is driven by `half_ext.y`. It is the only thing on the
screen and it moves; nothing else in the game looks remotely like it.

Input is accepted from the moment the aperture shuts — through the fade and the
hold, before the first breath — so a player who taps early is never ignored.

The exit is unchanged and still costs no pixels: **Back or Esc during the death
sequence goes straight to the mode select**, skipping the pause screen, because
pausing a dead cell is nonsense.

The restart has to be unmistakable or players will not know they died. It is: the
collapse is the loudest frame in the game, and the returning beat is at 2.4s and
full strength after minutes of a slow faint one.

## 7. Godot-ready

### 7.1 `game/perception/signal_bus.gd`

| constant | from | to | why |
| --- | --- | --- | --- |
| `DREAD_BEAT_FLOOR` | 0.2 | **0.15** | §5.2, measured |
| `DREAD_JITTER` | 0.3 | **0.40** | arrhythmia is dread's first tell |
| `DREAD_JITTER_GATE` | 0.4 | **deleted** | replaced by a ramp |
| `BEAT_PERIOD_MAX` | — | **6.5** | new: jitter on a dying beat must not leave the screen empty |
| `DREAD_FALL_RATE` | — | **0.22** | new: relief must arrive in ~4.5s or escape cannot be learnt. Rise stays `DREAD_RATE = 0.095` |
| `TASTE_DREAD_SUPPRESS` | — | **0.6** | new |

```gdscript
func beat_strength() -> float:
    return maxf(_beat_amplitude * lerpf(1.0, DREAD_BEAT_FLOOR, _dread), DREAD_BEAT_FLOOR)

# _step_beat: scaled, not gated. Arrhythmia arrives ~20s before the drain shows.
var shake := smoothstep(0.05, 0.45, _dread) * DREAD_JITTER
var jitter := 1.0 if shake <= 0.0 else randf_range(1.0 - shake, 1.0 + shake)
_beat_this_period = clampf(_beat_period * jitter, 0.05, BEAT_PERIOD_MAX)

# _process: asymmetric.
_dread = move_toward(_dread, _dread_target,
    delta * (DREAD_RATE if _dread_target > _dread else DREAD_FALL_RATE))

# _compose_lobes: taste is suppressed and confused, not deleted.
var intensity := smoothstep(TASTE_FLOOR, 1.0, _taste_c) * TASTE_PEAK \
    * (1.0 - TASTE_DREAD_SUPPRESS * _dread)
# _step_taste:
var spread := deg_to_rad(lerpf(TASTE_JITTER_WIDE_DEG, TASTE_JITTER_TIGHT_DEG, _taste_c)) \
    * (1.0 + _dread)
```

> **`BEAT_PERIOD_MAX` is a ceiling on the jitter, not on the period.**
> `clampf(_beat_period * jitter, 0.05, BEAT_PERIOD_MAX)` as written cuts
> §6.1's `DYING_PERIOD = 7.5` down to 6.5 and quietly deletes the last of the
> starvation signature. Shipped as
> `clampf(_beat_period * jitter, 0.05, maxf(BEAT_PERIOD_MAX, _beat_period))`, so
> an authored period is never shortened and only the random half is capped. A
> dying, hunted cell therefore jitters 5.25–7.5s rather than 4.5–10.5s.

Plus one new method, `collapse(t: float)`, owning the death frames: it writes
`inset_px`, holds `flash`, idles all four glow lobes, and fades `base_color` /
`dread_color`. **Nothing outside the bus writes a uniform** — that rule holds. Shipped as
`collapse(t: float, loud: bool = true)`, because the two deaths share every
frame of geometry and differ only in tempo and temperature (§6.1), plus
`revive(t: float)` for the tap and the 0.90s back. `t` keeps counting through the
hold, so the caller owns a clock and nothing else.

### 7.2 `game/normal/metabolism.gd`

`HUNGER_SECONDS` 1800 → **420**; `beat_period()` multiplicative (§2.1); new
`MEAL := 0.50`, `DYING_PERIOD := 7.5`, `STARVE_GRACE := 40.0`. `feed()` and
`concentration` stop being stubs.

### 7.3 New files

`game/normal/food.gd`, `game/normal/predator.gd`. Same shape as `motes.gd`: a
plain `Node`, no `class_name`, a ring of positions, a `points()` accessor for
full vision, world positions emitted on the signal and **dropped before the bus**.

One convention added while building, because it is what keeps that last rule
cheap to hold: **these nodes compute and do not post.** Continuous state
(`food.concentration`, `food.taste_bearing`, `predator.dread_level`) is read once
a frame by `normal_mode.gd`, which is the only node that talks to the bus;
discrete events (`eaten`, `waked`, `killed`) are signals it forwards. The §3.2
sketch has the field calling `bus.taste()` itself; posting a continuous signal
from four places is how a world position eventually reaches the bus by accident,
and a per-frame `taste` signal would allocate a dictionary sixty times a second
besides. `dread()` is gated on the bus for the same reason `taste()` already was.

`game/normal/cell.gd`: `RADIUS` const → `radius` var.

`game/normal/motes.gd` is **unchanged**. The first full-vision mock looked
crowded and I was about to cut `COUNT` from 14; measured over three 120-second
runs the cell actually bumps a mote 5 / 1 / 2 times, so about once a minute. The
crowding was the threshold rings, not the motes. The one real interaction — a
contact flash wiping the contour for 90ms plus a 600ms bruise, in the middle of a
chase — lands in roughly one chase in three, and it should stay: blundering into
something while fleeing is a cost of panicking, not a bug.

### 7.4 Shader

**No change.** Every effect above uses uniforms that already exist:
`inset_px`, `flash`, `wobble_px`, `base_color`, `dread_color`, `press_lobes`,
`glow_lobes`, `dread`, `pulse`. Slots 2 and 3 stay reserved.

### 7.5 `game/vision/vision.gd`

Food in `Color(0.35, 0.88, 0.42)` — the same green the taste lobe uses, so "the
green on my rim" and "the green thing out there" are visibly one substance.
Predator in `Color(0.78, 0.24, 0.30)`: full-vision only, never on the membrane,
which is the whole point of it. Rendered against the teal water it is
unmistakable, and the size difference does the work even without the hue.

Two verification draws, following `_draw_hits`:

- the reported **wake bearing**, as a ray from the cell. If it does not point at
  the predator, the membrane is lying.
- **threshold rings** at 680 / 130 (food) and 1400 / 760 / 220 (predator) —
  drawn **only while the cell is within 130 units of crossing one**, fading out
  either side. Drawn always, they are larger than the screen and the world reads
  as a radar plot; that was rendered and it was bad. A ring is a measuring
  instrument, so show it at the moment of measurement.

### 7.6 Both targets

- No new widgets. Steering is unchanged, death takes no input, and the pause
  screen is untouched — the 48px rule still only bites there.
- **Reflow:** everything new lives in the world (full vision) or on the rim
  (point of view). The death collapse is driven by `half_ext.y = 360 - inset`,
  which is 720 canvas px tall at *both* shapes, so the collapse has identical
  timing and geometry at 1280x720 and 2400x1080. Verified.
- One asymmetry, accepted: at 2400x1080 full vision shows more world, so a
  predator is visible sooner. Point of view is aspect-corrected and unaffected,
  and point of view is the game.
- **`gain` is now a real setting, and it lives on the pause screen.** Phase 4
  introduces the first state where dimness is a failure rather than a mood, and a
  `(6,23,23)` contour on an LCD phone in sunlight is the one risk this design
  carries.

  It is on pause rather than on a settings screen because that is where the
  problem is felt: the membrane keeps beating behind the scrim, so the effect is
  visible live as the player drags, and it costs no new surface. One lowercase
  caption, `light`, on the one screen in normal mode that already carries words.
  Range 0.70–2.40 in steps of 0.05, shipping at 1.0, persisted next to the mode
  choice in `run_state.gd`.

  Measured on the starving-and-hunted frame, which is the case it exists for:
  contour `(6,23,23)` at gain 1.0 becomes `(22,58,55)` at 2.40, and the ordinary
  rest beat at 2.40 is `(45,243,202)` — lifted hard and still not clipped, which
  is what sets the top of the range.

  The slider sits **above** `resume` in the same box, so it inherits the same 48
  canvas px of separation and nothing destructive is ever under a dragging thumb.
  Its control rect is 48px tall for the touch-target rule even though the drawn
  track is thinner.

## 8. Measured output

Sampled from renders at 1280x720; 2400x1080 agrees within a unit unless noted.

| state | centre | brightest |
| --- | --- | --- |
| rest, beat peak | (5, 13, 12) | (23, 113, 94) contour |
| food far, c = 0.30 | (5, 13, 12) | (32, 135, 105) band |
| food near, c = 1.0 | (5, 13, 12) | (78, 248, 158) band |
| stalked — dread 0.55 + wake | (4, 10, 11) | (193, 255, 255) dent; contour (13, 63, 55) |
| hunted, fed — dread 0.95 | (3, 7, 10) | (7, 27, 27) |
| hunted, over food | (3, 7, 10) | (31, 87, 55) band — muffled, still a bearing |
| starving, not hunted | (5, 13, 12) | (12, 48, 41) |
| **starving + hunted, unfixed** | (3, 7, 10) | **(5, 15, 17)** — the bug |
| **starving + hunted, fixed** | (3, 7, 10) | **(6, 23, 23)** |
| **starving + hunted + wake** | (3, 7, 10) | **(185, 238, 229)** dent |
| death, `inset_px` 300 | — | (229, 255, 254) |
| death, hold | (0, 0, 0) | (0, 0, 0) |
| ingest | (39, 98, 52) | (27, 123, 99) contour — the rim survives the flood |

Every state above was rendered and looked at, at both sizes, except the two that
are made of time rather than light: **arrhythmia and the escape window cannot be
photographed.** They must be judged by playing, and they are the two things in
this document most likely to be wrong.

## 9. Left open — owner's call

1. ~~Auto-restart on death, or wait for a tap?~~ **DECIDED: wait for a tap.**
   Holding the black gives the player somewhere to put the phone down, which
   auto-restart did not. It costs no new screen and no second string of text; the
   affordance is the breathing aperture in §6.3, which is made of the same
   membrane as everything else.
2. **Does a run remember anything?** Phase 4 says no: death is a clean restart.
   Phase 5 will want lineage, and that is the natural moment to decide whether
   `run_state.gd` grows or a run is always the first of its line.
3. **`GROWTH_PER_MEAL = 0.5` is a placeholder.** 28 meals to edibility is over an
   hour. Genes are what should make the curve real, so Phase 5 owns it; what
   matters now is that the comparison exists and dread already falls off with it.
4. Still open from `perception.md` §6.4: **where the gene screen lives.** It is
   the next thing that has to be decided, and Phase 5 cannot start without it.
