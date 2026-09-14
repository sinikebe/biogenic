# Genes and cilia

Phase 5. The cell stops being one thing and starts being a **choice**: a genome
with a fixed number of slots, filled by what you eat, worn on the outside as
cilia.

Extends `perception.md` and `food-and-predators.md`; it contradicts both in
places and says so where it does. Every number below was rendered under GL
Compatibility at 1280x720 **and** 2400x1080 and looked at. The prototype was
built in a throwaway copy of the project outside the repository.

## 1. The decisions, in one place

1. **Cilia are the visible expression of ability, and every cell wears them** —
   you, the food, the predator. One drawing routine, three subjects.
2. **The starting cell is already full.** Three slots, three organs: feed,
   orient, thrust, all at tier 1. You are not an empty vessel; you are mediocre
   at three things, and becoming something means stopping being something.
3. **Genome size is capacity, not currency.** There are no genetic points.
   Slots come from body radius — the one number the game already has, which now
   means three things: what can eat me, what I can eat, and how much I can be.
4. **Gene identity is one hue used in four places** — the cilia on your body,
   the cilia on the prey that carries it, the ingest flood at the instant you
   eat it, and the slot on the genome strip. No legend, no lookup.
5. **Point of view forages blind and that is the point** (§2).
6. **The genome surface is a launcher-themed panel, and it lives on the pause
   screen.** This settles `perception.md` §6.4 (§5).
7. **"Synthesis" is not a Phase 5 word.** Phase 5 integrates genes into one
   cell. Making *other* cells belongs with multicellular bodies, which the owner
   deferred; see `roadmap.md`.

## 2. The tension: point of view cannot see its own cilia

The viewport is the inside of the body. Cilia are a full-vision readout. So in
point of view the player can neither look at what they can do nor look at a prey
cell and read its gene.

**This is resolved by not solving it in the same place three times.**

### 2.1 What you can do — you already feel it, and always have

The three starting cilia are not new capabilities. They are `metabolism.gd` and
`cell.gd`, which have shipped since Phase 2. And the membrane has been drawing
all three since Phase 1, in its self-register:

| organ | what it is in code | what point of view already feels |
| --- | --- | --- |
| **feed** | `metabolism.beat_period/amplitude` | the metabolic beat |
| **orient** | `TURN_RATE_MAX`, `TURN_RESPONSE` | the turn shear on the outside of the turn |
| **thrust** | `IMPULSE_SPEED`, `IMPULSE_GAP_*` | the thrust bloom at bearing 0° |

So the retrofit is the discovery that **the membrane's three self-signals and
the cell's three cilia are the same three organs seen from inside and from
outside.** Nothing new is needed in point of view to express ability — a tier
change is a change in the sensation the player already knows:

| gene | tier 1 | tier 2 | tier 3 | uniform |
| --- | --- | --- | --- | --- |
| thrust | bloom 0.14 / 60° | 0.19 / 52° | 0.25 / 44° | `glow_lobes[0]` (`THRUST_PEAK`, `THRUST_HALFWIDTH_DEG`) |
| orient | shear 0.10 | 0.14 | 0.19 | `glow_lobes[0]` (`SHEAR_PEAK`) |
| feed | flood decay 1.2s | 1.5s | 1.9s | `INGEST_DECAY` |

No new shader term, no new lobe, no HUD. A thrust-specialised cell feels its own
push harder and more sharply; a feeder savours the meal longer.

### 2.2 What you just ate — the flood is the gene's colour

`food-and-predators.md` §3.4 already reserved this: *"`ingest_color` is already a
uniform, so a gene can tint the flood."* Phase 5 spends it.

The interior flood is `perception.md`'s one licensed exception, it lasts 1.2s,
and it is a *contact* event — chemistry you have absorbed, which is the one
moment a cell could plausibly tell what something was. It is also the only place
a gene is ever identified on the sensory screen.

> This is a deliberate, narrow breach of "never an identity". It is bounded to
> the one signal `perception.md` already exempted and to the one frame where
> the thing is inside you. Do not let it spread to the band.

Rendered, amber (`eyespot`): interior centre **`(99, 88, 41)`**, against the
nutrient green flood's `(39, 98, 52)`. The rim survives the flood at
`(33, 121, 98)`, as in Phase 4.

### 2.3 What is out there — point of view does not get to know, deliberately

**Full vision plays selective foraging; point of view plays opportunistic
foraging.** You swim at the bearing your skin gives you and you take what is
there. That is the honest consequence of the premise, and it is the first time a
view's information advantage has become a strategic one.

Two things keep it from being a punishment:

- **The advantage is smaller than it sounds.** Measured: at ZOOM 1.0 the visible
  world is ±640 x ±360 world units at 1280x720 and ±800 x ±360 at 2400x1080.
  `food.BEARING_RANGE` is 680, so when the taste bearing first resolves the food
  is usually still off-screen. Full vision's real advantage is *"the wash points
  that way — is it worth going?"* over the last few hundred units, not a menu.
- **It is a gene's job to close the gap, and that is now a designed slot rather
  than a hole.** A later *chemoreceptor discrimination* gene lets the band
  distinguish flavours, giving point of view gene identity at range. Reserve it;
  do not build it now. It is exactly the kind of thing `perception.md` §4 said
  later genes should sell.

### 2.4 What am I — the mirror, on pause

Both modes read their genome on the pause screen (§5). That is also where a
point-of-view player learns the cilia vocabulary, because the slot tiles draw
the organ. If they ever switch views, the language is already theirs.

**You can look at yourself in the mirror; you cannot look at yourself while you
are swimming.**

## 3. The genome

### 3.1 Slots come from size

```gdscript
# cell.gd
const BASE_RADIUS := 26.0
const GROWTH_PER_MEAL := 1.0    # was 0.5 -- food-and-predators.md §9.3 gave
                                # this to Phase 5 as a placeholder
const SLOT_RADIUS := 3.5        # one more slot per this much growth
const SLOT_MIN := 3
const SLOT_MAX := 7

func slots() -> int:
    return clampi(SLOT_MIN + int((radius - BASE_RADIUS) / SLOT_RADIUS),
        SLOT_MIN, SLOT_MAX)
```

| radius | slots | meals |
| --- | --- | --- |
| 26.0 | 3 | 0 |
| 29.5 | 4 | 4 |
| 33.0 | 5 | 7 |
| 36.5 | 6 | 11 |
| **40.0** | **7** | **14** |

`SLOT_MAX = 7` is not arbitrary: the body has exactly seven arcs (§4.1), and 40
is `predator.RADIUS`. **The genome fills up at the moment you outgrow the thing
that has been hunting you.** At Phase 4 foraging rates (a meal every 60–90s)
that is a 15–21 minute arc — a session, not a campaign, which is right for a
game with no save.

### 3.2 A gene has a tier, and tiers cost upkeep

Eating a food cell that carries gene X:

- **X not held, a slot free** → integrates at tier 1, immediately, no screen, no
  pause. The flood is X's colour and the cilia grow in over `GROW_SECONDS = 2.5`.
  This is the whole early game and it teaches the vocabulary by accident.
- **X already held below tier 3** → tier +1. Free, automatic.
- **X already at tier 3** → nutrition only. No sample, no echo.
- **X not held, no slot free** → the sample is **held** (§3.3). Nothing blocks.

**Every tier above 1 raises the metabolic rate.** This is the price of power and
it is paid in the channel the game already reads:

```gdscript
# genome.gd -- a new plain Node. It computes and does not post, exactly like
# food.gd and predator.gd; normal_mode.gd is still the only node that talks to
# the bus, and it is what carries this number across.
const UPKEEP_PER_TIER := 0.18

func upkeep() -> float:
    var extra := 0
    for tier: int in _slots.values():
        extra += maxi(tier - 1, 0)
    return 1.0 + UPKEEP_PER_TIER * float(extra)

# metabolism.gd -- one new public var, written once a frame by the run, exactly
# like `concentration` already is. The hunger mapping stays in this one file.
var upkeep := 1.0
# _process: set_hunger(hunger + delta * upkeep / HUNGER_SECONDS)

# normal_mode.gd _process, beside the existing read-once-post-once block:
_metabolism.upkeep = _genome.upkeep()
```

A cell with one tier-3 gene starves in 420 / 1.36 = **309s**; a late cell with
`feed 2, orient 3, thrust 3, eyespot 2` in 420 / 2.08 = **202s**. That is the
whole economy: **the specialist eats constantly and moves; the generalist is
slow and lives.** And `feed` is how you pay for it — its tiers raise `MEAL`
(0.50 / 0.62 / 0.78), so a broad eater can afford a narrow body.

Nothing about this needs a number on screen. Upkeep is read off the beat, which
has been the hunger readout since `perception.md` §6.2.

### 3.3 A held sample is a second heartbeat

The one new point-of-view signal Phase 5 adds, and the answer to "how does a
player with no HUD know a decision is waiting".

A sample is held for `SAMPLE_SECONDS = 45.0`. While it is held, **each metabolic
beat is followed by a smaller second one**:

```gdscript
const HELD_ECHO := 0.44          # of beat_strength()
const HELD_ECHO_DELAY := 0.58    # seconds after the beat
const HELD_FADE := 15.0          # the echo weakens over the last 15s

# in _step_beat, after pulse_now():
if held_sample != &"":
    _echo_at = HELD_ECHO * minf(remaining / HELD_FADE, 1.0)
    _echo_in = minf(HELD_ECHO_DELAY, 0.34 * _beat_this_period)
```

- **It is teal, not the gene's colour.** `perception.md`'s rule stands: the
  contour carries bearing and intensity, never identity. The echo says *there is
  something in you that is not resolved*, and nothing else.
- It costs **no interior** — `perception.md` §4's "the interior is currency" is
  not spent here; that is still reserved for the gene that buys a true image.
- It costs no new uniform: it is `pulse_now(HELD_ECHO)` on a delay.
- It survives dread and starvation, because it is **rhythm**, which
  `food-and-predators.md` §5.1 established as the channel that survives
  everything.
- 0.58s clears `PULSE_ATTACK + PULSE_DECAY = 0.51s`, so the two pulses are
  separate. Below a 1.7s beat period the delay compresses and at rich-food
  periods (0.55s) the two merge into a flutter. That is acceptable: it is still
  not the normal rhythm. Do not add a second uniform to fix it.

In full vision the same state is drawn literally: a disc of radius `0.16r` in
the gene's hue inside the body, offset `0.30r` to port of the nucleus, pulsing
on the beat and shrinking with `remaining`.

If the sample lapses it is simply gone. There is no discard control and there
does not need to be one.

### 3.4 Where the gene comes from — the food, not a roll

> **Contradicts `food-and-predators.md`**, which called this "the gene roll on
> eating". A roll cannot be seen in advance, and informed foraging requires that
> it can. **Each food cell's gene is fixed when it is seeded**, and full vision
> draws it.

```gdscript
# food.gd -- weights, drawn in _seed()
const GENE_WEIGHTS := {&"feed": 3, &"orient": 3, &"thrust": 3, &"eyespot": 2}
```

`eaten(nutrition, gene, at)` already exists with exactly this signature and
`normal_mode.gd` already forwards it. Phase 5 fills `gene` and removes the
`push_warning` guard. No refactor.

## 4. Cilia

### 4.1 Seven arcs, three of them spoken for

Cilia are placed by the **ovoid's own parameter `t`**, not by bearing, because
the body is already drawn that way (`vision.gd`, `OVOID_STEPS`: along `cos(t)`,
across `sin(t) * (1 - 0.30 * cos t)`, scaled `1.18r` x `0.94r`).

| arc | `t` (deg) | bearing (deg) | occupant |
| --- | --- | --- | --- |
| anterior | −42 … 42 | ±29 | **feed** |
| lateral, starboard | 66 … 118 | 58 … 120 | **orient** |
| lateral, port | −118 … −66 | −120 … −58 | **orient** |
| posterior | 146 … 214 | 146 … 214 | **thrust** |
| free 1 | 42 … 66 | 29 … 58 | earned |
| free 2 | −66 … −42 | −58 … −29 | earned |
| free 3 | 118 … 146 | 120 … 146 | earned |
| free 4 | −146 … −118 | −146 … −120 | earned |

Earned genes fill the free arcs in genome order. Three home arcs plus four free
arcs is `SLOT_MAX = 7`.

**The free arcs are also the bearing rose.** While empty they are visible gaps at
roughly the four diagonals, which is a 45° reference read off the organism
rather than painted over it.

> **The 32-cilium rose in `vision.gd` is retired.** It was a protractor of 32
> even cilia with four bright cardinals. Measured: under a tier-2 fringe the
> pale cardinal ticks are invisible at both sizes, and the fringe now carries
> meaning that a protractor laid over it only muddles. The bearing checks full
> vision exists for are drawn as *rays from the cell* (`_draw_hits`,
> `_draw_wakes`) and are their own instrument.

### 4.2 Geometry, at tier 1

All lengths are fractions of the body radius `r`, so a grown cell is not a small
cell with stubble. `clock` is `vision.gd`'s `_clock`; `u` runs 0→1 across the
arc; strokes are `draw_polyline` in world space.

| | **feed** | **orient** | **thrust** | **earned** |
| --- | --- | --- | --- | --- |
| count | 15 across the arc | 5 per side | 6 | 4 |
| root | surface + `0.06r` | surface | surface | surface |
| length | `0.27r x (0.80 + 0.30w)` | `0.34r x (0.86 + 0.22c)` | `0.62r x (0.82 + 0.26s)` | `0.30r x (0.88 + 0.14s)` |
| width | 1.3 | 2.0 | 1.8 | 1.6 |
| alpha | 0.62 | 0.66 | 0.62 | 0.72 |
| points | 3 (curved inward) | 3 (bent oar) | 6 (travelling lash) | 2 (stiff) |
| motion | metachronal wave `w = sin(u·7.4 − clock·5.6)`, swing ±26°·w toward the nose | `phase = clock·2.4 + (0 or π) + u·0.9`, swing ±30°·sin(phase); the two sides are in **antiphase** | `lash = sin(v·3.0 − clock·5.2 + u·0.45) · length · 0.26 · v` along the stroke | none — a sensory cilium does not row |

The **earned** gene also carries a pigment organelle: filled discs of `0.20r` at
alpha 0.55 and `0.10r` at alpha 0.85, seated at `surface(r * 0.80, mid_t)`, over
three haze rings at `0.30r x (1 + 1.6q)`, alpha `0.030(1 − q)`.

**Orient leans with the steer.** The outboard side of the turn works harder:
`bias = 1.0 + 0.55 * clamp(-steer * side, -1, 1)` on the swing. This is a motion
cue, not a still-frame cue — it does not show in a screenshot and is not claimed
to.

### 4.3 Tier is magnitude, not a badge

```gdscript
const TIER_LEN:   Array[float] = [0.0, 1.00, 1.22, 1.46]
const TIER_COUNT: Array[float] = [0.0, 1.00, 1.35, 1.70]
const TIER_ALPHA: Array[float] = [0.0, 1.00, 1.12, 1.24]
```

Longer, denser, brighter. Countable without counting. Rendered at r26 and r40:
tier 1 against tier 3 is unmistakable in every arc.

### 4.4 Hues

| gene | `Color(r, g, b, a)` | wheel |
| --- | --- | --- |
| **feed** | `Color(0.62, 1.00, 0.38, 1)` | 95° |
| **orient** | `Color(0.36, 0.62, 0.98, 1)` | 216° |
| **thrust** | `Color(0.80, 0.42, 0.95, 1)` | 291° |
| **eyespot** | `Color(0.98, 0.78, 0.30, 1)` | 45° |
| *reserved* | `Color(0.48, 0.42, 0.95, 1)` indigo | 250° |
| *reserved* | `Color(0.94, 0.42, 0.68, 1)` rose | 333° |

Rules for the next designer: a new gene hue must sit **≥30° from every other
gene hue** and **≥40° from self teal `(0.12, 0.70, 0.58)` and predator red
`(0.78, 0.24, 0.30)`**.

**Feed breaks the first rule on purpose.** It is deliberately in the nutrient
green family, because feed *is* nutrition and the taste lobe is already that
green. It is brighter and yellower than `FOOD_TINT (0.35, 0.88, 0.42)` so it
separates from the food body it sits on — rendered at 1x, it does. It is the
least legible of the four at range and its positive tell is texture: feed is the
only dense fine mat.

> **Measured colour-blindness check.** A Viénot deuteranope simulation of the
> render collapses feed-green and eyespot-amber onto the same yellow, and brings
> orient-blue and thrust-orchid close. **On a body this does not matter** — a
> luminance-only render separates all four by arc, length and density with no
> ambiguity. It matters in exactly two places, and both are handled: food cells
> wear the organ as well as the hue (§4.5), and genome slots are labelled (§5.2).

### 4.5 Food and the predator wear cilia too

**One routine, three subjects.** A food cell is drawn with its single gene at
tier 2 geometry (it is small; the organ needs to survive at `r` 14–20), facing
its drift heading.

Everything else about food is **unchanged and must stay unchanged**: the core
disc, the wobbled shell outline and the three haze rings all stay
`FOOD_TINT (0.35, 0.88, 0.42)`. The haze is the drawn form of the scent field
that the membrane's green band is reading — if it were gene-coloured, full
vision would be showing a distinction point of view cannot make, in the one
channel where the two views must agree.

**The predator is drawn with `{thrust: 3}` and nothing else**, in the thrust
orchid, over the red body and its existing flagellum. It costs one line. It is
the whole visual language in one glance: **the thing that is all tail is the
thing that catches you**, and you are the thing with three small organs. When
you specialise into thrust you start to look like it — which is the arc.

Rendered at 1280x720: the orchid brush on the red body does not muddy; the
silhouette comparison with the player's cell is instant.

### 4.6 Two changes to shipped `vision.gd`

- `HEADING_LEN`'s needle base moves from `r * 1.55` to **`r * 1.80`**. A tier-3
  feed crest reaches `r * 1.61` and collided with the chevron. Rendered.
- The `CILIA = 32` block is replaced by the genome routine (§4.1–4.3).

## 5. The genome surface — `perception.md` §6.4, settled

### 5.1 It is a launcher-themed panel, and the rule is general

**Decision: launcher theme, not the membrane aesthetic.**

`mode_select.tscn` and the pause screen already made this choice; this only
names it. Rendered side by side, both are the launcher's theme resource, the
launcher's organic wash at `intensity 0.5`, lowercase text, teal slabs. The
genome surface joins them.

> **The membrane is what the cell feels. A panel is what the player consults.
> The launcher theme marks every surface where the player, not the cell, is
> being addressed.**

The genome surface is not sensory — it is a representation, it needs touch
targets and it needs words, all three of which the sensory screen forbids and a
panel allows.

### 5.2 It lives on the pause screen

Not a new screen. Pause already has widgets, already has the house style, and is
already reachable by a gesture the player knows (Back on Android, `Esc` on
desktop). It costs no new input, no new pixels in play and no new binary.

Always visible as a readout; interactive only when a sample is held.

```
Hud/Pause/Center/Buttons  VBoxContainer  separation = 48
  ├── Genome              VBoxContainer  separation = 10          <-- NEW
  │     ├── Caption       Label   "genome"  15px  Color(0.855, 0.953, 0.933, 0.45)
  │     ├── Row           HBoxContainer  separation = 20  alignment = CENTER
  │     │     ├── Sample  PanelContainer  76x76   (only while held)
  │     │     ├── Arrow   Control  30x76          (only while held)
  │     │     └── Slot0.. PanelContainer  76x76 x slots()
  │     └── Hint          Label   14px  Color(0.855, 0.953, 0.933, 0.38)
  ├── Light               (unchanged)
  ├── Resume              (unchanged)
  └── Leave               (unchanged)
```

**`Light`, `Resume` and `Leave` must be given `size_flags_horizontal =
SIZE_SHRINK_CENTER`.** They currently inherit the VBox's width; with a seven-slot
strip above them they stretch to 652px. Rendered, and it looked wrong.

**Tile states** — `PanelContainer` + `StyleBoxFlat`, `corner_radius_all = 8`:

| state | bg | border |
| --- | --- | --- |
| occupied | `Color(0.063, 0.141, 0.125, 0.62)` | 1px, gene hue at `a = 0.45` |
| empty | `Color(0.047, 0.082, 0.075, 0.50)` | 1px, `Color(0.141, 0.278, 0.247, 0.85)` |
| held sample | `Color(0.063, 0.141, 0.125, 0.80)` | 2px, gene hue at `a = 0.90` |
| armed | `Color(0.086, 0.204, 0.176, 0.80)` | 2px, gene hue at `a = 0.85` |

**Tile face**, drawn in `_draw` on a `MOUSE_FILTER_IGNORE` child:

- the gene's name, 13px, `Color(0.855, 0.953, 0.933, 0.66)` (`0.92` when armed or
  held), centred at `y = 15`
- the organ: an arc of radius 13 at `centre = (w/2, 0.66h)`, spanning
  `1.04π … 1.96π`, gene hue at `a = 0.30`, with the gene's own stroke count and
  length (feed 9 x 8px, orient 5 x 13px, thrust 6 x 17px, earned 5 x 11px plus a
  4.2px pigment disc), gene hue at `a = 0.88`, width 1.7
- tier pips: three dots radius 2.6 at `y = h − 9`, spaced 9px; filled at
  `a = 0.92`, outline at `a = 0.22`
- an empty slot draws a `+`: two 16px lines, `Color(0.141, 0.278, 0.247, 0.75)`

**Interaction** — two taps on the same target, which is the only pattern that is
safe on touch and navigable by keyboard:

1. A tap (or `Enter` on a focused tile) **arms** a slot. The hint changes from
   `tap a slot to replace it` to `tap again to integrate`.
2. A second tap on the **same** tile commits the swap, no sooner than
   `ARM_GUARD = 0.30s` after the first, so a double-tap cannot commit.
3. Arming lapses after `ARM_TIMEOUT = 4.0s`, or on arming a different slot.

A mis-tap costs nothing because arming is reversible. That is why the 20px gap
between tiles is acceptable even though it is ~1.5mm on a 2400x1080 phone — it
is the same argument the 48px `resume`/`leave` separation makes in reverse, and
the destructive control here is not adjacent to `resume`.

### 5.3 Measured layout

| | value |
| --- | --- |
| tile | 76 x 76 canvas px (touch rule: ≥48 ✓) |
| tile gap | 20 |
| widest state (7 slots + sample + arrow) | **798** canvas px |
| margin at 1280x720 | 241 px each side |
| margin at 2400x1080 (canvas 1600x720) | 401 px each side |
| tallest state (genome + hint + light + two buttons) | **465** canvas px of 720 |

Rendered at both sizes at 3 slots, 7 slots, held, and armed. Nothing overflows,
nothing collides, and the buttons stay 232px wide once shrink-centred.

**Reflow:** the canvas is 720 tall at both shapes, so the vertical stack is
identical. Only the horizontal margins change, and the strip is centred.

## 6. The one earned gene Phase 5 ships: `eyespot`

`perception.md` §4 promised it: *"a new glow lobe in slot 2, in a colour not yet
used… sharper (half-width ~20°) and does not jitter… the moment the player
learns that direction can be certain."* Slot 2 has been reserved since Phase 1.

**What it sees: the shadow of anything bigger than you.** A body passing between
you and the light above occludes it. This costs no new world content — no sun,
no lamp — and it gives point of view a *sharp, certain, continuous* bearing on
the predator where before it had only intermittent wakes and directionless
dread.

```gdscript
# signal_bus.gd
const LOBE_LIGHT := 2
const LIGHT_COLOR := Vector3(0.98, 0.78, 0.30)   # glow_colors[2], was ZERO
const LIGHT_PEAK := 0.28
const LIGHT_HALFWIDTH_DEG := [0.0, 26.0, 19.0, 13.0]   # by tier

# predator / anything with radius >= SHADOW_MIN_RATIO * cell.radius
const SHADOW_RANGE := 620.0      # inside WAKE_RANGE 760: it sharpens, never extends
const SHADOW_CORE := 180.0
const SHADOW_MIN_RATIO := 0.8
```

Three properties, all load-bearing:

- **It does not jitter and it does not lag.** Taste is 78° wide at range and only
  26° on top of the food; the eyespot is its tier's width at *every* range.
- **Dread cannot muffle it.** Dread is a blocked chemoreceptor; light is a
  different organ. `TASTE_DREAD_SUPPRESS` must not be applied to `LOBE_LIGHT`.
  This is the fiction and it is also the purchase: at the moment the player can
  see least, the thing they bought still works.
- **It goes quiet when you outgrow the predator**, because `SHADOW_MIN_RATIO`
  stops being met. The silence is itself the readout that you have won.

Rendered on a `dread = 0.95` frame at 1280x720: the amber lobe is the brightest
thing on screen at **`(77, 83, 48)`** against dread's own `(7, 27, 27)` — a
precise bearing on a drained membrane. Rendered beside a full-strength taste
lobe: amber and green read as two different substances with no ambiguity.

## 7. What this breaks, and who owns it

Two Phase 4 contracts are stated against a tier-1 cell and Phase 5 invalidates
both. Neither is a reason not to ship; both must be re-measured.

- **`orient` tier 3 sets `TURN_RATE_MAX = 1.02`** (58°/s, half-turn in 3.1s)
  against the 0.62 that `ESCAPE_SECONDS = 7.0` was derived from — and against
  `predator.TURN_RATE`, which is also 0.62, so a tier-3 cell out-turns its hunter
  by 1.65x. The dodge gets much easier. That is the reward; re-measure
  `predator.COMMIT_RANGE` (310) against a tier-3 cell with
  `tools/drive.gd --hunt --evade`, and check that *"a cell that does nothing must
  be caught"* still holds at tier 1.
- **`thrust` tier 3 sets `IMPULSE_SPEED = 190`**, taking the cell's net speed
  from 56.5 to roughly 78 u/s — past `predator.CRUISE = 68`. *"You cannot outswim
  it"* stops being true, and `predator.PREY_SPEED` is a hard-coded `56.5` that
  the pursuit solution uses to aim, so it starts leading the wrong point.
  **Recommended: `PREY_SPEED` becomes the cell's realised speed and
  `CRUISE = PREY_SPEED * 1.20`**, so the chase stays a chase at every tier and
  only `orient` improves the dodge. Owner's call; recorded.

### 7.1 New and changed files

| file | change |
| --- | --- |
| `game/normal/genome.gd` | **new.** A plain `Node`, no `class_name`, same shape as `food.gd`: holds `{gene: tier}`, the held sample and its clock, `slots()`, `upkeep()`, `integrate()`. Computes; does not post. |
| `game/normal/normal_mode.tscn` | **new** `Genome` node, `process_mode = 1`; pause gains the `Genome` block (§5.2); `Light`/`Resume`/`Leave` get `size_flags_horizontal = 4` |
| `game/normal/normal_mode.gd` | fills `gene` from `_on_eaten`, writes `_metabolism.upkeep`, owns the strip and the two-tap arming |
| `game/normal/food.gd` | `GENE_WEIGHTS`; a gene per slot, chosen in `_seed()`; a `genes()` accessor for full vision, index-matched to `points()` |
| `game/normal/cell.gd` | `GROWTH_PER_MEAL` 0.5 → 1.0; `SLOT_*`; drive constants read from the genome |
| `game/normal/metabolism.gd` | `upkeep`; `MEAL` read from the genome |
| `game/normal/predator.gd` | §7, if the owner takes the recommendation |
| `game/perception/signal_bus.gd` | `LOBE_LIGHT`/`LIGHT_COLOR` in `attach()`, `light()`, the `LOBE_LIGHT` branch in `_compose_lobes()`, `ingest()` writing `ingest_color`, the held echo in `_step_beat()` |
| `game/vision/cilia.gd` | **new.** The drawing routine. Used by the player's cell, food, the predator and the genome tiles. |
| `game/vision/vision.gd` | §4.6 |
| `game/perception/membrane.gdshader` | **no change.** Every uniform this phase needs already exists. |

Tier targets, for the engineer:

| gene | constant | t1 | t2 | t3 |
| --- | --- | --- | --- | --- |
| feed | `metabolism.MEAL` | 0.50 | 0.62 | 0.78 |
| orient | `cell.TURN_RATE_MAX` | 0.62 | 0.80 | 1.02 |
| orient | `cell.TURN_RESPONSE` | 1.10 | 0.85 | 0.65 |
| thrust | `cell.IMPULSE_SPEED` | 138 | 162 | 190 |
| thrust | `cell.IMPULSE_GAP_MIN/MAX` | 1.7 / 3.6 | 1.45 / 3.0 | 1.2 / 2.5 |
| eyespot | `LIGHT_HALFWIDTH_DEG` | 26° | 19° | 13° |

These must be *read from the genome*, not stored as `const`. Put the mapping in
one place per file, next to the constant it replaces, for the same reason
`perception.md` §6.2 put the hunger→beat mapping in one place.

## 8. Text budget

`perception.md` §6.1 allows exactly one string in normal mode. **It is not
touched.** Phase 5 adds no text to the sensory screen in either mode, in any
state.

Every word Phase 5 adds is on the pause screen, which has carried words since
Phase 1 and carries `light` already: the caption `genome`, the hint
(`tap a slot to replace it` / `tap again to integrate`), and one lowercase word
per slot.

**Genes are named on the genome strip and nowhere else.** The names are the
owner's to set; what is decided is that a *word* is there. A permanent,
irreversible swap needs an unambiguous label, and the deuteranope render in §4.4
shows that hue alone is not one.

## 9. Left open — owner's call

1. **Gene names.** `feed`, `orient`, `thrust`, `eyespot` are placeholders and
   read like engineering. They are content and they are yours.
2. **Does the predator's cruise track the cell's speed?** (§7.) Recommended, but
   it changes the character of a chase and should be felt, not argued.
3. **`UPKEEP_PER_TIER = 0.18` is the only number here that cannot be checked by
   looking.** It sets whether specialising feels like a bargain or a trap. Move
   it first if the late game feels either free or airless; `HUNGER_SECONDS`
   second.
4. **Does a run remember its genome?** Still open from
   `food-and-predators.md` §9.2. Phase 5 assumes **no** — death is a clean
   restart and the arc is one session. Lineage is a real design and it is not
   this one.
5. **A dedicated gesture for the genome** (two-finger tap / `G`) instead of
   going through pause. Not recommended: pause already works on both targets and
   costs nothing. Recorded because it will be asked.

## 10. What was rendered

Prototyped in a throwaway copy outside the repository, at 1280x720 and
2400x1080, under `--rendering-driver opengl3`:

- the born cell (1/1/1, r26) and the maximum cell (3/3/3 + eyespot 3, r40) in
  full vision, against the live halo, beat, trail, velocity plume and heading
- all three organs at all three tiers, side by side, at r26 / r30 / r34 / r40
- the same frame in luminance only and under a Viénot deuteranope simulation
- four gene-bearing food cells at 250–300 units, and one at 430 canvas px
- the predator with its `{thrust: 3}` brush, stalking at 210 units
- the genome strip on the pause screen at 3 slots, at 7 slots, with a held
  sample, and armed — at both sizes
- point of view: the eyespot lobe at 13° / 19° / 26° on a `dread = 0.95` frame,
  the eyespot beside a full-strength taste lobe, and the amber ingest flood

Two things in this document are made of time and cannot be photographed: **the
second heartbeat and the orient lean.** They must be judged by playing, and they
are the two things here most likely to be wrong.
