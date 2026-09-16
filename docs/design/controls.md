# Control schemes

The owner, in one sentence:

> "Add more control options. For example, a left right joystick and buttons. We
> can choose from the pause menu"

Three schemes, chosen from the pause screen, remembered in `user://`. The one
that ships today stays the default and is not touched. Extends
`perception.md` §3 (nothing at the screen edge), `gene-lines-and-the-pause-target.md`
§4 (a control in the playfield is allowed, and what it costs) and
`moving-a-gene.md` §6 (the pause column's measurements).

Everything below was built in the working tree, rendered at 1280x720 **and**
2400x1080 under `--rendering-driver opengl3 --fixed-fps 60`, measured, and
reverted. §8 lists the frames; §8.1 lists what review then found and changed.

**Every measurement on this page states its own command** and was verified
reproducible by rendering it three times and diffing — 0 differing pixels.
That is not politeness: the membrane's jitter came off an unseedable generator
until this change, so the first version of §3.2 quoted numbers nobody could
repeat. `perception.md` §4.1 is the rule that came out of it.

---

## 0. The shipped scheme is already a stick, and that changes the brief

`cell.gd` is usually described as *position on screen sets steer*. It is not.
`_grab` records `_pointer_anchor = x` at the press and `_read_steer` returns

```gdscript
clampf((_pointer_x - _pointer_anchor) / DRAG_SPAN, -1.0, 1.0)   # DRAG_SPAN 190
```

— **relative to wherever the finger landed.** So the scheme that ships is
already a floating, invisible, horizontal-only stick with a 190 canvas px
full-scale throw and no return spring, plus *a finger down is thrust* and *a
short still press is the dash*.

Two consequences run through the whole of this document:

- **The owner's "left right joystick" is mostly a request to draw the thing that
  is already there.** What a fixed stick adds over today is a *known centre*
  (today's recentres on every press), a *visible* target, and a shorter throw.
  Those are worth having; they are not a new mechanic.
- **A floating stick that appears where the thumb lands is therefore not a
  fourth scheme.** It is today's scheme with a picture drawn *underneath the
  thumb that is drawing it*, which is the one place on a phone a picture cannot
  be seen. Rejected in §7.

---

## 1. The three schemes

Chosen on the pause screen. The pause button cycles the word; the controls
themselves appear in the playfield corners behind the scrim as you cycle, which
is the whole explanation and costs no string (§5).

| | `anywhere` (default, shipped) | `stick` | `pads` |
| --- | --- | --- | --- |
| **steer** | drag anywhere, 190 px full scale, relative to the press | a knob in a channel, bottom left, ±48 px full scale | two pads, bottom left, full rate while held |
| **thrust** | any finger down | touching the stick | a `push` pad, bottom right |
| **dash** | short still press (≤ 0.28 s, ≤ 26 px) | a `dash` pad, bottom right | a `dash` pad, bottom right |
| **lean, at a division** | which half of the screen | the stick's own deflection | whichever turn pad is held |
| **pixels at rest** | **none** | 27,648 canvas px², 3.00% / 2.40% | 36,864 canvas px², 4.00% / 3.20% |
| **what it is for** | the game as designed: the dash costs no pixel and no second finger | one thumb does everything, the other only dashes | three verbs fully independent — the only scheme that can turn without swimming |

**Keys are unchanged under every scheme.** `ui_left`/`A`, `ui_right`/`D`,
`ui_up`/`W`, `Space`, `V`, `Esc`. The scheme is a *touch* choice; a desktop
player who picks `pads` gets the pads **and** the keys, and there is no platform
branch anywhere in this design — branching on `OS.has_feature("mobile")` would
make the phone layout the one thing nobody can photograph.

**Every scheme carries all three verbs, and that is the rule this document
exists to hold.** `myoneme` is a gene a player can have spent three meals on; a
scheme that cannot dash is not a scheme. The moment a stick owns the finger the
tap gesture is gone, so the dash becomes a drawn control — that is the new pixel
cost and it is 9,216 canvas px².

### 1.1 The controls are a readout of the genome

**A pad exists only when the organ that works it does.** `push` is drawn when
`_cell.extra(&"axoneme") > 0`, `dash` when `_cell.extra(&"myoneme") > 0`. A
newborn on `pads` has two controls and grows into four; a newborn on `stick` has
one. This is `gene-lines-and-the-pause-target.md` §4.1's own rule — *a control
that is drawn and does nothing teaches the player that tapping it does nothing*
— and it is also the most diegetic thing in the design: **the interface is the
organism, and it arrives when the organ does.**

Positions never move, so growing a gene adds a control and never relocates one.

---

## 2. Geometry

One baseline. Every control is 96 canvas px tall, bottom-aligned, `EDGE = 48`
from the bottom and from its own side — the launcher's `edge_margin` and
`PauseTap`'s own offsets, so the game has one margin and not three.

```
EDGE   48      PAD     96 x 96      PAD_GAP  24
STICK  192 x 96          KNOB 56      THROW  ±48      DEAD 6
```

At canvas height 720 every control occupies **y 576 .. 672**. `W` is the canvas
width: 1280 at 16:9, 1600 at 20:9.

| control | scheme | x | notes |
| --- | --- | --- | --- |
| stick | `stick` | 48 .. 240 | knob home at x 144 |
| port | `pads` | 48 .. 144 | corner-most: port is the port side of the screen |
| starboard | `pads` | 168 .. 264 | 24 px of dead space between them, because a mis-hit here is the *opposite* of what was asked |
| dash | both | W−144 .. W−48 | corner-most on the right, in both schemes, so it never moves |
| push | `pads` | W−264 .. W−168 | inboard, because it is the one that is *held* and the thumb tip rests inboard of its own knuckle |

**Sizes, in millimetres.** The project's own conversion (`perception.md` §3: 56
canvas px ≈ 5.3 mm at 2400x1080) gives 0.0946 mm per canvas px. So a 96 px pad
is **9.1 mm** — the ~9 mm that document says a thumb actually needs, and twice
CLAUDE.md's 48 px floor, which is a floor for a *finger on a precise target* and
not for a thumb bracing a phone. The stick's ±48 px throw is **4.5 mm** of thumb
roll, which is a stick you pivot rather than a drag you reach for: 4.0x more
sensitive per millimetre than `anywhere`'s 190 px span, and that difference in
feel is most of why these are separate schemes rather than a skin.

**Reflow at 2400x1080: none vertically.** The canvas is 720 tall at both shapes,
so the baseline is identical. Horizontally both blocks are anchored to their own
corner, so they slide outward with it and the gap between them grows by 320 px.
Verified at both shapes; §8.

**Against the membrane.** The band is 104 px deep from the inset rect, whose
inner edge sits at y 588. The controls run 576..672, so **12 px of the 512 px
interior is touched** and the rest of each control is in the band, where it is
measured in §3.

---

## 3. What it costs the one channel a blind player has

`perception.md` says nothing may be placed at the screen edge, because the edge
*is* the sensory channel. `gene-lines-and-the-pause-target.md` §4 already broke
that for a control and paid for it with a measurement. This is the same
measurement, on a much larger control, and it is the honest answer to the
owner's request.

### 3.1 Water covered

Computed from the shader's own rounded-rect SDF and its aspect-corrected
bearing, not estimated:

| | canvas | of the band | port arc | starboard arc |
| --- | --- | --- | --- | --- |
| `stick` @ 1280x720 | 3.00% | 7.3% | 216.0–237.0° (**21.1°**) | 123.0–138.1° (15.1°) |
| `pads` @ 1280x720 | 4.00% | 9.7% | 214.3–237.0° (**22.7°**) | 123.0–145.8° (22.8°) |
| `stick` @ 2400x1080 | 2.40% | 6.1% | 219.1–237.4° (18.4°) | 122.6–136.5° (13.9°) |
| `pads` @ 2400x1080 | 3.20% | 8.1% | 217.8–237.4° (19.6°) | 122.6–142.2° (19.6°) |
| the pause target, for scale | 0.34% | 0.6% | 307.7–315.8° (8.1°) | — |

`pads` sits on about **45° of the 360° compass**, in two arcs, both on the
quarters astern. For scale: a `nutrient near` lobe is 52° wide and a `ping`
return is 20–34°, so each block is roughly one radar return wide, on a bearing
that never moves. That is the cost, stated plainly. It is 5.6x the pause
target's, and the pause target is a control you touch twice a run.

### 3.2 It subtracts light rather than adding it

**The ranking first, because the ranking is the finding and the only part of it
that survived being measured three different ways.** At both shapes, at a beat
trough and at a beat peak: *the loudest thing the controls put on the screen
stays under the quietest thing they share it with.* The starboard block peaks at
**46.85 / 47.80** (trough / peak) at 1280x720 against a soma figure of
**59.22 / 59.12**, and at **57.78 / 58.60** at 2400x1080 against
**75.25 / 75.14**. That is the ranking `diegetic-hud.md` §4 asks for and it is
reached without an alpha ramp.

The absolute numbers below are reproducible rather than impressive, and that is
deliberate: the first version of this section quoted figures nobody else could
reproduce, because it stated neither the rectangle it measured nor the clock it
froze. Both of those move every number on the page. So:

**The method, stated.** Glance peak is the σ = 6 px Gaussian peak of Rec.709
luminance on the 8-bit output — the measurement `diegetic-hud.md` §4 and
`gene-lines-and-the-pause-target.md` §4.3 both use. The canvas is 720 tall at
every shape; `W` is the canvas width, 1280 at 16:9 and 1600 at 20:9. Three
rectangles, in **canvas** units, converted to device pixels by `H / 720`:

| rectangle | canvas x | canvas y | why that box |
| --- | --- | --- | --- |
| **port block** | 48 .. 264 | 576 .. 672 | the stick (48..240) and both turn pads (48..264), so one box holds either scheme |
| **starboard block** | W−264 .. W−48 | 576 .. 672 | `push` and `dash` |
| **the figure** | W/2−200 .. W/2+200 | 180 .. 500 | the soma figure, stopping clear of the onboarding label's band at y 518..548 — so no number here depends on whether `user://` has the seen-flag |

**The genome carries a sense on purpose.** `stigma:1` is in it so the free grant
at five seconds finds one already there and does not fire: an unforced genome
gets handed a random sense at t=5, which starts a held sample, a second
heartbeat and a second line of text, and none of that is the same picture twice.

**The exact command**, one scheme per run, `0` `1` `2`:

```
xvfb-run -a -s "-screen 0 1280x720x24" ~/godot/godot --path . \
  --rendering-driver opengl3 --fixed-fps 60 res://tools/shot.tscn -- \
  --scene=res://tools/drive.tscn --size=1280x720 --out=/tmp/g.png --wait=8 \
  --seed=12345 --mode=0 --scheme=0 --freeze-at=6.0 \
  --genome=cytostome:1,cirrus:1,flagellum:1,stigma:1,axoneme:1,myoneme:1
```

For 2400x1080, change the screen and `--size=`. For the beat-peak row, replace
`--freeze-at=6.0` with `--arm-at=5.5 --freeze-on=beat --freeze-delay=2 --wait=9`,
which freezes at 6.30 s.

**`--seed=` is load-bearing and until this review it did not cover the
membrane.** `signal_bus.gd`'s jitter came off an unseedable private generator,
so the same command rendered a different frame every time — up to a third of the
screen. `perception.md` §4.1 is the whole story. Every command on this page was
verified by rendering it three times and diffing: **0 differing pixels.**

#### At a beat trough — `--freeze-at=6.0`

| point of view | port block | starboard block | **the controls add** | the figure |
| --- | --- | --- | --- | --- |
| `anywhere`, 1280x720 | 11.65 | 11.63 | — | 59.22 |
| `stick`, 1280x720 | 22.50 | 46.85 | **+10.85 / +35.22** | 59.22 |
| `pads`, 1280x720 | 25.24 | 46.85 | **+13.59 / +35.22** | 59.22 |
| `anywhere`, 2400x1080 | 11.64 | 11.63 | — | 75.25 |
| `stick`, 2400x1080 | 25.69 | 57.78 | **+14.05 / +46.15** | 75.25 |
| `pads`, 2400x1080 | 30.86 | 57.78 | **+19.22 / +46.15** | 75.25 |

#### At a beat peak — `--freeze-on=beat`, frozen at 6.30 s

| point of view | port block | starboard block | **the controls add** | the figure |
| --- | --- | --- | --- | --- |
| `anywhere`, 1280x720 | 26.77 | 26.81 | — | 59.12 |
| `stick`, 1280x720 | 29.12 | 47.80 | **+2.35 / +20.99** | 59.12 |
| `pads`, 1280x720 | 27.86 | 47.80 | **+1.09 / +20.99** | 59.12 |
| `anywhere`, 2400x1080 | 30.93 | 30.92 | — | 75.14 |
| `stick`, 2400x1080 | 32.43 | 58.60 | **+1.50 / +27.68** | 75.14 |
| `pads`, 2400x1080 | 32.05 | 58.60 | **+1.12 / +27.68** | 75.14 |

Four things worth reading off those two tables:

- **What a control adds depends almost entirely on what the contour is doing
  underneath it.** The same `pads` block adds +13.59 to a dark port corner and
  +1.09 to a lit one. Any single number for "what the controls cost" is a number
  about a beat phase, which is why this section now states its clock and gives
  two of them.
- **`stick` and `pads` read identically to starboard**, at every row, because
  the peak there is the `dash` burst and both schemes draw it in the same place.
  The `push` wave never wins its own block: *swim is a wave, dash is a burst*,
  and a wave is the quieter mark, which is the right way round for the one that
  is held.
- **At a beat peak `pads` is quieter in the port corner than `stick` is**
  (27.86 against 29.12). The knob's border is the brightest object either scheme
  draws; four flat wells are not.
- **The starboard block is the loudest control object in the design**, and its
  worst reading anywhere on this page is 58.60 against a 75.14 figure. If a
  later change makes any control block beat the figure, it has crossed the line
  this section exists to hold.

**The worst case, posed on purpose.** A hunter at 150 units on bearing 220° with
a tier-3 `stigma` and `gain` at maximum, so a saturated lobe blazes across
exactly the pixels the pads occupy. Same rectangles, `--freeze-at=8.0`:

```
  --seed=12345 --mode=0 --scheme=0 --stalk=150 --stalk-at=220 --gain=2.4 \
  --freeze-at=8.0 --wait=10 \
  --genome=cytostome:1,cirrus:1,flagellum:1,stigma:3,axoneme:1,myoneme:1
```

| | port block, `anywhere` | port block, four pads over it | the pads add |
| --- | --- | --- | --- |
| 1280x720 | **157.76** | **149.67** | **−8.09** |
| 2400x1080 | **168.28** | **160.95** | **−7.33** |

**The controls do not add light there, they subtract it**, and the sign is now
outside the noise rather than inside it — the previous version of this row read
213.6 against 212.3, a difference of 1.3 on a frame that moved by up to 125 of
luminance between identical runs, and it was not evidence of anything. The well
is a 13%-alpha dark teal, so over a bright lobe it is a slightly darker patch and
the marks vanish into the glare. The silhouette survives, the bearing is still
readable, the signal wins outright — the same result and the same mechanism the
pause target measured at 219 against 218.

**And the honest other half of that frame.** The starboard block in the same
picture has no lobe on it at all: it reads **8.03** bare and **44.41** with the
pads drawn at 1280x720, **8.04** against **55.55** at 2400x1080. Where there is
nothing to hear, the control *is* the brightest thing in its own corner. It is
still under the figure in the same frame (59.49 and 74.35), which is the rule;
and the moment there is something to hear, the measurement above is what
happens.

---

## 4. What they look like, and why they are not a joystick ring

**Interface subtracts light; the body emits it.** That is the rule this design
adds, and it is what makes a control at the rim safe: the membrane's grammar is
*light, at a bearing, means a sensation*, so anything that is not a sensation
must be a dark, hard-edged object that occludes.

- **The wells are `PauseTap`'s own slab**, unchanged: `StyleBoxFlat`, corner
  radius 12, 1 px border, rest `bg Color(0.063, 0.141, 0.125, 0.13)` /
  `border Color(0.12, 0.70, 0.58, 0.09)`, held or hovered `0.58` / `0.48`. What
  you press looks like a piece of the surface the pause target opens.
- **Rounded rectangles, never circles.** A circular ring is the one shape that
  *would* read as a sensation: the water is full of cells, ring-shaped vesicles
  and round ping returns. `gene-lines-and-the-pause-target.md` §4.1 bought the
  right angle as the game's word for *interface*; a generic translucent joystick
  ring would spend it back.
- **The stick is a channel, not a bowl.** A 6 px track running ±48 px across the
  well's waist, `Color(0.855, 0.953, 0.933, 0.07)`, with a 56 px rounded-square
  knob riding it — rest `bg 0.045 / border 0.28`, held `0.16 / 0.80`. A bowl
  promises a second axis the simulation does not have; a slot says *left and
  right, and only left and right*, which is the truth.
- **The marks are the organism's, in the organ's own hue, at `0.36` alpha**, via
  `Cilia.draw_tile_organ` at scale 2.0 — the same glyph the pause screen draws
  beside that gene's name, so the player meets the mark on the surface where the
  scheme is chosen. The hues are **asked of `Cilia.hue()`, not copied out of
  `Cilia.HUES`**: a second copy of a colour table is the drift `cilia.gd` warns
  about in three separate comments, and these pads are the surface where a drift
  would show worst — the mark on the pad and the glyph beside that gene's name
  are meant to be one object seen twice.
  - `dash` — the `myoneme` burst, `Color(0.94, 0.42, 0.68)`.
  - `push` — **not** the `axoneme` tile glyph. Rendered side by side, `axoneme`
    and `myoneme` are near-twins in shape *and* hue (306° against 333°, and both
    a radial burst with a pigment at the heart), and at 96 px the two pads were
    indistinguishable. `push` is drawn instead as three strokes of the body's own
    metachronal wave, lying along the way you go: *swim* is a wave, *dash* is a
    burst, and the two read apart at a glance. §8 has both frames.
  - `turn` — the `cirrus` oars, `Color(0.36, 0.62, 0.98)`, swept the way the turn
    goes with the sweep growing across the row, **plus `cilia.gd`'s own filled
    dart**. The sweep alone was built first and rendered as two similar tufts;
    `draw_slot_dart`'s comment had already reached the same conclusion for the
    strand's compass — *a filled dart is unmistakable* — so it is that mark doing
    that job again. On the stick the same dart sits at each end of the channel.
  - **The dart comes without its compass bezel**, and that is a parameter rather
    than an exception. `draw_slot_dart` draws a ring around its dart, and on a
    locus that ring is the compass the dart is a needle on: it says *this is a
    bearing around the body*. On a turn pad there is no compass and no bearing,
    so the circle carried no sentence at all — and it sat in the one shape the
    bullet above forbids by name. The first build kept it and it read as an
    arrow in a button icon. `draw_slot_dart` now takes `ring: bool = true`; the
    pad passes `false` and **every other caller renders exactly as it did**,
    which was verified by rendering the pause strand and the choosing screen at
    both shapes and diffing them against `main`: 0 differing pixels. A
    byte-unchanged `cilia.gd` was a verification convenience, and a render is a
    better one than a git hash.
- **Pressed, the mark goes to `0.92` and the well lights.** On a phone that is
  under the thumb; it is for the desktop cursor and for the light that spills
  past a fingertip. It is also, at a division, the only confirmation a lean has
  ever had — see §6.

Alphas were set by measurement, not by eye: the first pass at `0.42` put the
`pads` block at 66.4 glance against a 65.2 figure, which is a dead heat, and a
dead heat is not losing. `0.36` is what §3.2 measures.

> **Those two numbers predate §3.2's stated method and are not reproducible
> from it.** They were taken on an unstated rectangle, at an unstated clock,
> with the membrane's jitter unseeded — so do not try to reproduce 66.4 against
> 65.2. What survives is the comparison they were used for, which is the same
> comparison §3.2 now makes under a method anyone can repeat: at `0.36` the
> loudest control block is clear of the figure at both shapes and at both ends
> of the beat, and at `0.42` it was not. If the alpha is ever revisited, take
> the reading again under §3.2's command rather than against these.

---

## 5. The chooser, and it fits with zero vertical cost

A third panel in the `Settings` row `moving-a-gene.md` §6 built, identical to
the other two: `PanelContainer` at `_slab(-0.2)`, caption `controls` at 16 px
`Color(0.855, 0.953, 0.933, 0.52)`, and a 192 x 48 `Button` that cycles the
scheme word. Same styling loop as the camera toggle — the two are the same kind
of thing and should be one `for` loop over both.

```
Settings   HBoxContainer  separation = 48  SIZE_SHRINK_CENTER
  ├── Light   PanelContainer  232 x 101   (unchanged)
  ├── View    PanelContainer  232 x 101   (unchanged)
  └── Feel    PanelContainer  232 x 101   <-- NEW
        ├── Caption  Label   "controls"
        └── Toggle   Button  192 x 48   "anywhere" / "stick" / "pads"
```

Measured with `get_global_rect()` on a paused run, at 1280x720 **and**
2400x1080, at 3 loci **and** at 7:

| | y | height |
| --- | --- | --- |
| `Buttons` | **45 .. 674** | **629 of 720**, 45 clear above, 46 below |
| `Settings` | 365 .. 466 | 101 |
| `Light` / `View` / `Feel` | 365 .. 466 | 232 x 101 each |

**Every one of those numbers is what `moving-a-gene.md` §6 measured on the
shipped build. The chooser costs zero vertical pixels** — the row it joins is
already 101 tall and has horizontal room, which is exactly the slack that
document said was there.

What it does cost is width: `Settings` goes from 512 to **792**. The strand
block is `256 + 96n`, so 544 at three loci and 928 at seven — the settings row is
the column's widest element from 3 to 5 loci and inboard of the strand from 6.
At 1280x720 it runs x 244..1036, at 2400x1080 x 404..1196; the membrane band's
inner edge is at x 132, so nothing collides at either shape. Rendered at 3 and 7
loci and judged: the column reads as one object, and a side effect is that its
outer edge now stops breathing as the genome grows.

**No confirmation, no apply.** Cycling takes effect immediately, `RunState`
writes it, and `_cell.release()` + `controls.let_go()` drop any pointer so a
finger still down when the scheme changed is not steering the new one.

### 5.1 The chooser explains itself, for free

The controls stay drawn while paused — dead to input, but drawn — so cycling the
word makes the corners change under the scrim. **That is the entire
explanation, and it costs no string.** Rendered at both scrims: at point of
view's 0.50 the preview is plainly readable; at full vision's 0.86 it is faint
but present. The pause column is centred and its lowest element (`leave`, y
618..674, x 524..756) never reaches a corner, so nothing overlaps at either
shape.

### 5.2 Persistence

`RunState.load_scheme()` / `save_scheme()`, in `user://normal_mode.cfg` under
`run/scheme`, exactly the shape `load_camera_locked` already has. Out-of-range
values fall back to `anywhere`, so a file written by a later build with a fourth
scheme downgrades cleanly instead of crashing.

---

## 6. Leaning, and it must be the control that steers

`normal_mode.gd`'s `_read_lean` reads a screen half, on the argument that *a
96 px daughter is not a 48 px target with a thumb over it*. **That argument is
untouched and the screen half stays live under every scheme** — it is the floor,
and a player who cannot choose a daughter loses the run.

But the half cannot be the *only* read once anything is drawn down there, and
this was checked rather than assumed. A thumb parked on the stick sits at canvas
x ≈ 144, which is the port half **whichever way it is pushing**. Under `pads`
both turn pads are in the port half. So:

> **A drawn control that is being held decides the lean. A finger anywhere else
> falls back to the screen half. Keys come first, as they always did.**

Two consequences worth writing down, both rendered:

- **The steering control never disappears during a division.** `push` and `dash`
  go the moment `_set_simulating(false)` runs at the pinch — there is nothing
  left for them to do — but the stick and the turn pads stay for the whole
  sequence. A target that vanishes from under a thumb and returns 1.5 s later is
  a target the player has to find twice at the one beat in a run that cannot be
  replayed. The first build hid everything from `QUICKEN` to `PART` and took
  steering away from a cell that was still swimming; rendered, and fixed.
- **The lean finally has feedback.** The held pad lights. Until now leaning gave
  the player nothing but the daughter slowly brightening, and *is it hearing me*
  had no answer for the first second. §8 has the frame.

**A thumb already down is adopted**, the same way `_read_touch_lean` adopts one
for the screen half and for the same reason: the press happened before there was
anything to lean at, so the only event that finger will ever produce is a drag.
Adoption is refused for `push` and `dash`, which are not leans.

**And a thumb that lands *during* the division is honoured on the frame it
lands, which needed a fix.** "The steering control stays drawn through the
division" and "the held pad lights" are the two promises above, and for the
1.5 s of the pinch neither was true: the pad was drawn, it did not light, and
pressing it did nothing at all, because the pinch is where the cell's input
stops and nothing had picked it up yet. §7.2 is the measurement and the fix. It
matters most for the player who cannot rescue it by accident — a phone thumb
jitters by a pixel and recovers, a mouse held still does not.

---

## 7. What the game developer builds

| file | change |
| --- | --- |
| `game/normal/controls.gd` | **new.** A `Control` under `Hud`, before `PauseTap` so the pause scrim covers it. Holds the geometry, the drawing and `hit(point) -> int`. |
| `game/normal/normal_mode.tscn` | `Hud/Controls`; `Settings/Feel` with its caption and toggle |
| `game/normal/normal_mode.gd` | three `@onready`s, the cycle handler, `_update_controls()` in `_process`, the lean routing in `_read_lean`, and the input gate opening at the pinch instead of at `PART` (§7.2) |
| `game/normal/cell.gd` | a `controls` reference; `_claim()` replacing `_grab()` on a press; `_read_steer` and `_pushing` consult the scheme; **multi-pointer, §7.1** |
| `game/run_state.gd` | `load_scheme` / `save_scheme` |
| `game/vision/cilia.gd` | one optional `ring` parameter on `draw_slot_dart`, defaulting `true`, so a turn pad can borrow the dart without the compass bezel that belongs to it (§4). `draw_tile_organ` needed nothing: it already takes an alpha and derives its tone from `hue()`, which is where the pads now read their hues from too |
| `game/perception/signal_bus.gd` | `seed_rng()`, so the view's private generator can be reproduced without being shared. Not called from the game (§7.3) |
| `tools/drive.gd` | `--scheme=0\|1\|2`, `--press=`/`--slide=`/`--lift=`, `--controls=`, `--size=`, and `--seed=` reaching the membrane bus. The scheme lives in `user://`, so without the flag a scheme cannot be photographed without writing one the next run inherits |
| `.github/workflows/ci.yml` | one step that drives presses under each scheme (§7.4). Not a content-pack file, and not synced from the template — copying workflow changes across is manual either way |

No `project.godot`, no `version.json`, no `export_presets.cfg`, no `addons/`, no
`ci/`. **This ships as a content pack.** The workflow file is not in the pack
and is not in the binary; it is repository furniture.

### 7.1 Two rules the build must not get wrong

**`MOUSE_FILTER_IGNORE`, end to end, on the node and on every child.** The
controls are drawn and hit-tested by hand; they never enter the GUI pass. This
is not tidiness. `normal_mode.gd`'s own comment records what a `MOUSE_FILTER_STOP`
control in the playfield costs: Godot hit-tests a drag afresh whenever the press
did not land on a `Control`, and a STOP control handed a pointer event consumes
it whether it wanted it or not — which cost a whole blocker on the genome strand,
where a thumb resting on a strand block could not lean at all. A stick in the
bottom-left corner is that same defect in the corner a thumb actually rests in.
Avoided here by construction rather than by guarding.

**`cell.gd` must track one pointer per control, not one pointer.** Today
`_pointer` is a single slot and a second finger is ignored — which is correct
for `anywhere`, where a resting palm must not fight the steering thumb, and a
**blocker** for the other two: under `pads` a player cannot hold `port` and
`push` at once, and under `stick` cannot dash while steering. Route by touch
index, keep `anywhere` exactly as it is, and derive:

```
steer  = stick deflection, or (port held ? -1 : 0) + (starboard held ? +1 : 0)
thrust = stick held (stick) / push held (pads)
dash   = fired on the press, never on the release
```

The dash fires on the press because a dash that waits for a lift is a dash that
arrives after the thing that was chasing you.

### 7.2 The pinch had no owner, and the corner was drawn anyway

**Found in review, fixed here, and it is a defect of this feature because this
feature is what draws something pressable in that corner.**

Pointer input during a division has two owners in sequence. `cell.gd` owns it
while the cell is swimming; `normal_mode.gd` owns it once the cell has stopped.
The handover was written a phase apart and the two halves did not meet:

- `_set_simulating(false)` runs at the **pinch** and stops `cell.gd`'s
  `_unhandled_input`.
- `normal_mode.gd`'s `_input` returned early while `_split < Split.PART`, and
  its lean branch was gated on `_split >= Split.PART`.

Between those two facts is `DIVIDE_PINCH` — **a second and a half in which no
node in the tree consumed a pointer press at all.** Measured at `--fixed-fps 60`
before the change: `--scheme=2 --radius=40 --press=3.0:216,624,0` logged
`held []  steer +0.00` for the whole run and never committed; the same press at
2.0 s, one phase earlier and on the cell's watch, logged
`held [starboard#0]  steer +1.00` and committed at 6 s. The turn pad stayed
drawn through all of it — which is what §6 promises and is exactly what makes
the hole a defect: a control that is drawn, unlit and inert is the one thing
`gene-lines-and-the-pause-target.md` §4.1 forbids. It recovered on the first
pixel of movement, so a jittering thumb escaped it and a Windows mouse held
still did not.

**The fix is to move the boundary to where the other half already is:
`Split.PINCH`.** From the pinch, `normal_mode.gd` owns pointer input; before it,
`cell.gd` does. There is no frame where both listen and none where neither does.
Nothing else in the corner changes: `_read_touch_lean` does at the pinch exactly
what it did at PART — a drawn control claims the press, or the screen half
remembers it — and neither is *read* until `CHOOSING` asks. Claiming drags a
phase earlier costs nothing, because `_choosing` is not visible until PART and
there is no locus in the tree to hit-test a drag against yet.

Two things worth recording:

- **It was never scheme-specific.** With the gate at PART the drive check in
  §7.4 fails under `anywhere` too, and for the same reason: a press in the port
  half during the pinch produced no event any node handled, and a finger that
  then never moves produces no later event either — so the lean never began at
  all and the division never committed. `anywhere` merely had nothing drawn
  there to look pressable, which is why nobody had found it. The scheme that
  ships gets this fix as well.
- **The release had the same hole, and it was the worse one.** Measured, same
  harness: a turn pad pressed at 2.0 s and **let go at 3.0 s**, inside the
  pinch. Before the fix the lift reached nobody, the pad stayed lit, `steer`
  stayed at +1.00 with nothing on the glass, and **the division committed the
  starboard daughter on a lean the player had already abandoned.** After it, the
  pad goes dark on the frame the finger leaves and the division correctly does
  not commit — which is this screen's own rule: releasing early undoes it, there
  is no timeout and no default. One boundary, both symptoms, and one of them was
  choosing a daughter by itself.

### 7.3 `--seed=` never reached the membrane, and every A/B on this page was affected

`signal_bus.gd` draws its beat and taste jitter from a **private**
`RandomNumberGenerator`, which is correct and must stay: the bus is a view, it
keeps stepping while the tree is paused, and a view drawing off the simulation's
stream once made how long you left the pause screen open change where every cell
in the water was.

What did not follow is that private meant seeded. It was not seeded anywhere,
`RandomNumberGenerator.new()` takes a system seed, and the global `seed()` the
harness called cannot reach an instance. So three byte-identical runs of one
`--freeze-at` command differed by up to **34.9% of the frame**, and the spread
between two runs of the *same* scheme was larger than the difference §3.2 was
quoting between schemes.

`seed_rng()` on the bus, called by `tools/drive.gd` from `--seed=`, is the whole
fix; it does not draw from the global stream to seed itself, so measuring a run
cannot change it. Not called from the game — a player's membrane keeps its
system seed, because a fixed jitter pattern is a worse picture and nobody
replays a run frame for frame. The durable version of this lives in
`perception.md` §4.1, which is where the next person measuring will look.

### 7.4 CI boots four scenes and presses nothing

The boot check proves every scene **loads**. It cannot prove any of them
**responds**, and the whole touch path is reachable only from a press.

The nodes that own it are held in untyped `Node` references on purpose — the
preload cycle is real, `cilia.gd` → `genome.gd` → `cell.gd` and
`controls.gd` → `cilia.gd` — and GDScript treats an unknown member on an untyped
base as `UNSAFE_PROPERTY_ACCESS` rather than an error. Measured: rename a
constant inside `controls.gd`, leave `cell.gd`'s use of it stale, and
`--check-only` on `cell.gd` exits 0 printing nothing while all four scenes boot
with **zero** error lines. The first player's dash tap finds it, with
`Invalid access to property or key 'DASH'`.

So the boot set gains a scene that *acts*. One step, three runs of
`tools/drive.tscn` — one per scheme — each pressing every control, sliding,
lifting, pressing through the pinch and then repeating the gesture on the mouse
path. Same grep as the boot check, **plus one positive assertion**: that the
division actually commits. A step that only greps for errors goes green if the
harness quietly stops driving anything, which is the same class of fault it was
added to catch.

Measured against both faults it exists for: the stale constant fails it under
all three schemes, and so does §7.2's input gate. About fifteen seconds, against
an export measured in minutes. `tools/` is excluded from export on both presets,
so it ships nothing.

**`--size=` is load-bearing and is the reason this needed more than one line.**
Canvas coordinates go in through `get_screen_transform()`, and a headless run
with no window of its own scales canvas 96,624 down to window **5,31** — a 96 px
pad becomes five pixels, every press lands on nothing, and the check passes
while testing nothing at all. `tools/shot.gd` already set the window for the
same reason; `drive.gd` now takes the same flag so it can be booted directly.

---

## 8. What was rendered, and judged

At 1280x720 **and** 2400x1080, GL Compatibility, `--fixed-fps 60`, through
`tools/drive.tscn`.

| frame | judgement |
| --- | --- |
| the playfield as it ships, both views, both shapes | the before, on record. The corners are empty and the interior is black |
| `stick`, point of view, both shapes | passes. A knob in a channel with a dart at each end; the membrane contour passes behind it and reads as a pane over the water |
| `stick`, full vision, both shapes | passes, quieter against a lit world than a dark one — the right way round |
| `pads`, point of view, both shapes | passes. Four quiet marks in two corners; the centre is untouched |
| `pads`, full vision, both shapes | passes |
| the knob at `0.20 / 0.30` | **failed.** A solid grey block, the loudest interface object on the screen and brighter than the cell. `0.045 / 0.28` is a watermark with an edge, which is what a control at the rim may be |
| `push` and `dash` as their own tile glyphs | **failed.** `axoneme` and `myoneme` are near-twins in shape and in hue; at 96 px the two pads were the same picture. Fixed by drawing `push` as a wave |
| the turn pads as rotated fans | **failed.** Two similar sunbursts; rotation does not make a radial mark directional |
| the turn pads as swept oars, no dart | **failed**, more subtly: distinguishable when enlarged, ambiguous at true size |
| the turn pads as swept oars **plus the dart** | passes, and it is unmistakable at 1:1 at both shapes |
| the same dart with its compass ring still on it | **failed, and shipped in the first build.** A ring is a bezel and a bezel needs a bearing; on a pad it read as an arrow in a button icon. See §4 and §8.1 |
| the stick held, knob at +40 px, 1280x720 | passes. Well lit, knob moved, and the membrane's turn shear answers on the starboard band in the same frame |
| the `dash` pad held | passes. The well lights, the burst goes to full rose, and the contour blooms with the dash |
| saturated `stigma` lobe over the pads, gain 2.4 | **the frame that settles §3.2**, re-posed with a seeded bus. 157.76 bare against 149.67 with the pads over it at 1280x720, 168.28 against 160.95 at 2400x1080: the control subtracts light and the signal wins. The previous reading of this row — 213.6 against 212.3 — was inside the noise of a frame that moved by up to a third of itself between identical runs, and is withdrawn |
| pause, 3 loci and 7, both shapes, with the `controls` panel | passes. y 45..674 and 629 of 720 at every combination — identical to the shipped column |
| pause over point of view, controls previewing behind the scrim | passes. Plainly readable at scrim 0.50 |
| pause over full vision, same | passes but faint at scrim 0.86. Recorded rather than fixed; the word on the button is still the answer |
| a division with `pads`, starboard pad held, 1280x720 | passes. The turn pads stay, `push` and `dash` are gone, and **the held pad is lit** — feedback the lean has never had. 21 px of clear space between the starboard pad and the port strand block, which is the tightest gap in the design |
| the same at 2400x1080 | passes with room to spare; the strand blocks move outboard with the canvas |
| the same division under `stick` | passes. Well lit, knob hard over to starboard, a dart at each end and no ring on either |
| everything hidden during `QUICKEN` and `PINCH` | **failed.** The cell is still simulating during `QUICKEN`, so this took steering away from a moving cell. Now only the two action pads go, and only at the pinch |
| a press in open water under `stick` and `pads` | correct: nothing. No steer, no thrust, no dash. The water is inert under those schemes, which is the scheme the player chose |
| a genome with no `myoneme`, `stick` | passes — one control, no dash pad. The interface is the genome |

### 8.1 What review added, and what it found

| frame or run | judgement |
| --- | --- |
| the turn pad's dart **with** `draw_slot_dart`'s compass ring | **failed**, and was shipped in the first build. The ring is a bezel and a bezel needs a bearing; on a pad it says nothing and it is a circle in the one corner that may not have one. Now `ring: bool = true`, `false` from the pad |
| the pause strand and the choosing screen, both shapes, against `main` | **0 differing pixels.** That is the regression check for the ring parameter, and it is a render rather than a git hash |
| the `pads` corner before and after the ring came out | 188 pixels differ, in a 140 x 20 box around the two darts, and nothing else on the frame moves. That is also the proof that reading the hues off `Cilia.hue()` instead of copying them changed no colour |
| a press during the pinch, `stick` and `pads`, both shapes | **failed before §7.2, passes after.** The pad lights on the frame the finger lands, the lean is held from there, and the division commits |
| the same press under `anywhere` | also failed before, also fixed. The hole was never scheme-specific — see §7.2 |
| a turn pad pressed at 2.0 s and **released at 3.0 s**, inside the pinch | **failed before §7.2, and worse than the press did.** The lift reached nobody, the pad stayed lit at `steer +1.00` with nothing on the glass, and the division committed a daughter on an abandoned lean. Now the pad goes dark on the frame the finger leaves and nothing commits |
| three identical runs of the §3.2 command | **0 differing pixels.** Before `seed_rng()`, three runs of the same command differed by up to 34.9% of the frame |
| the simulation, 30 s at `--seed=12345 --fixed-fps 60` | byte-identical between `--mode=0`, `--mode=1` and `main`. Nothing in this change reaches the water |
| CI driving presses under all three schemes | passes in about 15 s, and fails on both of the two faults it was written for (§7.4) |
| the `anywhere` playfield against `main`, both views, both shapes | **0 differing pixels.** The scheme that ships is still the scheme that ships |
| a newborn on `pads` — no `axoneme`, no `myoneme` | passes. Two turn pads and an empty starboard corner. The interface is the genome |
| two fingers at once, both schemes | `held [port#0, push#1]` with steer −1.00 and thrust on, and `held [stick#0, dash#1]` with the dash firing while the stick is over |
| the screen-half floor under `pads` | a press in open water on the starboard half commits the starboard daughter with no control held. The floor is intact |
| adoption granted, refused, and refused for `dash` | a thumb down before the pinch and dragged onto a turn pad is adopted and the pad lights; a thumb that pressed after the pinch and slid into the corner is refused and keeps its screen half; a thumb dragged onto `dash` is refused and keeps its screen half. All three commit the daughter the rule says they should |
| the chooser cycling | one tap, one step, `anywhere` → `stick` → `pads` → `anywhere`, and `user://` follows. The first reading of this looked like a double-fire and was the harness inheriting the previous run's persisted scheme |

---

## 9. What was rejected

- **A circular joystick ring.** It is the shape the water is made of, and it
  is precisely what "not a classic HUD, integrated to the actual designs" exists
  to prevent. The right angle is the game's word for *interface* and it was
  already paid for.
- **A two-axis stick.** The simulation has one axis of steering. A knob in a
  bowl promises a freedom that does not exist, and its vertical would either do
  nothing or duplicate *a finger is down*.
- **A relative/floating stick that appears where the thumb lands.** This is
  `anywhere`, already, mechanically (§0) — and drawing it puts the picture
  underneath the thumb that summoned it, which on a phone is the one place a
  picture cannot be seen. It would help a desktop mouse and nobody else.
- **A fixed thumb-zone with an absolute mapping** (position within a corner box
  sets steer). Needs the thumb to know where centre is with no feedback, which
  is the problem a visible knob exists to solve; and a thumb that drifts steers.
- **Tilt.** Genuinely tempting: zero pixels, and a lagged single-axis steer is
  what an accelerometer is actually good at. Not specced, for three reasons and
  the third is not obvious. It cannot be rendered or tested in this container,
  so it would ship unlooked-at. It does not exist on desktop, so the chooser
  would grow an option that is absent on half the targets. And
  `window/handheld/orientation=4` is `SCREEN_SENSOR_LANDSCAPE`: the wheel-roll
  axis a landscape tilt scheme would use is the same rotation Android flips the
  display on, so a hard sustained turn can invert the player's own control.
  Owner's call, §10 row 3.
- **Drawing `anywhere`'s stick while it is in use.** Same objection as the
  floating stick, plus it changes what the shipped game looks like for every
  player who never opens pause.
- **Words on the pads** (`turn`, `push`, `dash`). Permitted by precedent —
  §4 of `gene-lines-and-the-pause-target.md` resolved *a control is not a
  readout* in the control's favour — but four strings in the playfield against
  one authored line today, and it would make the answer to "integrated to the
  actual designs" be *labels*.
- **Hue-coding the pads instead of shape-coding them.** Does not work here:
  `axoneme` 306° and `myoneme` 333° are adjacent on purpose, and at 0.36 alpha on
  black they are one colour.
- **A fourth scheme.** Three is what the cycling button can carry without
  becoming a menu, and each of the three is a different answer to *where does my
  thumb live*. A fourth would have to earn a segmented control, and a segmented
  control does not fit in 232 px.
- **Hiding the controls while paused.** They are dead there, which the project's
  own rule dislikes — but a preview is understood as a preview, and it is the
  only wordless explanation of the chooser (§5.1).
- **A new onboarding line.** §10 row 2 puts the question to the owner; the
  recommendation is none. The existing line (`drag to turn` / `A · D to turn`) is
  simply **not shown under `stick` or `pads`**, because the drawn control is the
  onboarding. `RunState`'s seen-flag is unchanged, so a player who later switches
  to `anywhere` still gets it if they never had it.
- **Putting the chooser anywhere but the `Settings` row.** A second row costs
  109 px against 91 px of slack. It does not fit and it must not be squeezed.

---

## 10. Owner's call

| # | Question | Options | What it means |
| --- | --- | --- | --- |
| 1 | Which scheme does a brand-new player get? | **`anywhere` ✓ recommended** · `stick` · `pads` | Keep the game opening the way it was designed — one finger, nothing on screen, the dash free. The other two are there for anyone who goes looking. Changing this changes what Biogenic *is* on first launch, and it would put controls over the water for every player who never opens pause |
| 2 | Should the game point at the chooser, or let it be found? | **Let it be found ✓ recommended** · one extra line of text on the first run | Today there is exactly one authored sentence in the game. Leaving it alone means players who want a joystick find it where `light` and `camera` already are; adding one means everybody reads a second sentence to serve a minority who could have tapped pause |
| 3 | Offer tilt-to-steer as a fourth scheme later? | **Not now ✓ recommended** · yes, spec it | Steering by leaning the phone, no controls on screen at all. It suits this game's slow turn better than anything else here — but it cannot be tested or photographed in our container, it does not exist on Windows, and Android's landscape lock can flip the screen upside down under exactly the wrist rotation it would use |
| 4 | Are `anywhere` / `stick` / `pads` the right words? | **Yes ✓ recommended** · something else | The three words a player sees on the pause button. Each says what is on screen; `anywhere` also states the rule it names |

---

## 11. Left open

1. **Left-handed layout.** Steering is on the left and the actions on the right
   in both schemes, which is the convention and is what a right-handed majority
   expects. A mirror toggle is cheap — every rect is derived from `EDGE` and `W`
   — and is not built, because it is a fifth thing on a pause row that just
   filled up. Re-judge it if anyone asks.
2. **The stick's throw.** ±48 canvas px was picked as 4.5 mm of thumb roll and
   rendered, not played. It is the first number to move if `stick` feels twitchy
   or numb, and it is one constant.
3. **Whether `pads` should thrust while turning.** It does not: that is its
   distinguishing virtue and the reason the `push` pad exists. It is also the one
   thing in this document that can only be judged by playing, because turning
   without swimming has never been possible before.
4. **Hover on desktop.** Specced as the same lit state a held control already
   draws, driven by tracking the cursor rather than by `mouse_entered` — the node
   never enters the GUI pass, so it gets no enter/exit signals. The *look* is on
   record (§8, the held frames); only the trigger is unrendered.
