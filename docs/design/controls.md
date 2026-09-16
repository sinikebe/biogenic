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
reverted. §8 lists the frames.

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

Glance peak is the σ = 6 px Gaussian peak on the 8-bit output — the measurement
`diegetic-hud.md` §4 and `gene-lines-and-the-pause-target.md` §4.3 both use.
Each frame is the same seed and the same clock with only the scheme changed, so
the difference *is* the control.

| point of view | port corner | starboard corner | **the controls add** | the soma figure |
| --- | --- | --- | --- | --- |
| `anywhere`, 1280x720 | 39.1 | 39.1 | — | 61.4 |
| `stick`, 1280x720 | 39.8 | 46.7 | **+0.7 / +7.6** | 61.4 |
| `pads`, 1280x720 | 48.6 | 46.7 | **+9.5 / +7.6** | 61.4 |
| `anywhere`, 2400x1080 | 46.3 | 46.3 | — | 65.2 |
| `stick`, 2400x1080 | 46.3 | 58.9 | **+0.0 / +12.6** | 65.2 |
| `pads`, 2400x1080 | 62.7 | 58.9 | **+16.4 / +12.6** | 65.2 |

**+0.7 to +16.4**, against the pause target's own measured +8 to +18. Inside the
envelope the precedent set, on a control the player uses constantly instead of
twice, and the loudest block (62.7) is still under the figure it shares a screen
with (65.2).

**The worst case, posed on purpose.** A hunter at 150 units on bearing 220° with
a tier-3 `stigma` and `gain` at maximum, so a saturated lobe blazes across
exactly the pixels the pads occupy:

| | glance peak at the port corner |
| --- | --- |
| the lobe, `anywhere` | **213.6** |
| the same lobe with four pads over it | **212.3** |

**The controls do not add light there, they subtract it.** The well is a
13%-alpha dark teal, so over a bright lobe it is a slightly darker patch and the
marks vanish into the glare. The silhouette survives, the bearing is still
readable, the signal wins outright — the same result and the same mechanism the
pause target measured at 219 against 218. This is the ranking `diegetic-hud.md`
§4 asks for, reached without an alpha ramp.

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
  scheme is chosen.
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
- **Pressed, the mark goes to `0.92` and the well lights.** On a phone that is
  under the thumb; it is for the desktop cursor and for the light that spills
  past a fingertip. It is also, at a division, the only confirmation a lean has
  ever had — see §6.

Alphas were set by measurement, not by eye: the first pass at `0.42` put the
`pads` block at 66.4 glance against a 65.2 figure, which is a dead heat, and a
dead heat is not losing. `0.36` is what §3.2 measures.

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

---

## 7. What the game developer builds

| file | change |
| --- | --- |
| `game/normal/controls.gd` | **new.** A `Control` under `Hud`, before `PauseTap` so the pause scrim covers it. Holds the geometry, the drawing and `hit(point) -> int`. |
| `game/normal/normal_mode.tscn` | `Hud/Controls`; `Settings/Feel` with its caption and toggle |
| `game/normal/normal_mode.gd` | three `@onready`s, the cycle handler, `_update_controls()` in `_process`, the lean routing in `_read_lean`, `_read_control()` for a division |
| `game/normal/cell.gd` | a `controls` reference; `_claim()` replacing `_grab()` on a press; `_read_steer` and `_pushing` consult the scheme; **multi-pointer, §7.1** |
| `game/run_state.gd` | `load_scheme` / `save_scheme` |
| `game/vision/cilia.gd` | one optional `tone` parameter on `draw_tile_organ`, so a glyph can be drawn in something other than its own hue. Nothing else |
| `tools/drive.gd` | `--scheme=0\|1\|2`. The choice lives in `user://`, so without it a scheme cannot be photographed without writing one the next run inherits |

No `project.godot`, no `version.json`, no `export_presets.cfg`, no `addons/`, no
`ci/`. **This ships as a content pack.**

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
| the stick held, knob at +40 px, 1280x720 | passes. Well lit, knob moved, and the membrane's turn shear answers on the starboard band in the same frame |
| the `dash` pad held | passes. The well lights, the burst goes to full rose, and the contour blooms with the dash |
| saturated `stigma` lobe over the pads, gain 2.4 | **the frame that settles §3.2.** 213.6 bare against 212.3 with the pads over it: the control subtracts light and the signal wins |
| pause, 3 loci and 7, both shapes, with the `controls` panel | passes. y 45..674 and 629 of 720 at every combination — identical to the shipped column |
| pause over point of view, controls previewing behind the scrim | passes. Plainly readable at scrim 0.50 |
| pause over full vision, same | passes but faint at scrim 0.86. Recorded rather than fixed; the word on the button is still the answer |
| a division with `pads`, port pad held, 1280x720 | passes. The turn pads stay, `push` and `dash` are gone, and **the held pad is lit** — feedback the lean has never had. 21 px of clear space between the starboard pad and the port strand block, which is the tightest gap in the design |
| the same at 2400x1080 | passes with room to spare; the strand blocks move outboard with the canvas |
| everything hidden during `QUICKEN` and `PINCH` | **failed.** The cell is still simulating during `QUICKEN`, so this took steering away from a moving cell. Now only the two action pads go, and only at the pinch |
| a press in open water under `stick` and `pads` | correct: nothing. No steer, no thrust, no dash. The water is inert under those schemes, which is the scheme the player chose |
| a genome with no `myoneme`, `stick` | passes — one control, no dash pad. The interface is the genome |

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
