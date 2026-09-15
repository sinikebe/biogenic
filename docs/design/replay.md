# Watching the run back, from both sides

> "The game should record a run. Then, when you die, allow you to watch a
> 2 sided replay, one normal view and the other with full vision, so you can see
> what you've done exactly given your set of sensors. This allows to get better
> by seeing our mistakes."

The value is precisely **the gap between the two panes**: what you perceived
against what was actually there. That is the principle the project has held
since Phase 3 — full vision exists to catch the membrane lying — turned around
and aimed at the player's own mistakes instead of at the engine.

Status: nothing here is built. §1 and §2 are measurements taken against the
shipped build with the harness that already exists. §2 was a bug in that build
and **has been fixed separately from this feature**. §4 is a design that has
been measured but not rendered; the two things it still owes a photograph are
named where they occur.

## 1. The determinism measurement

There are two ways to record a run and the choice is not a matter of taste.

**A — record the seed and the input stream, replay by re-simulating.** Tiny and
exact, *if the simulation is deterministic*. It is not obviously deterministic:
`randf()` seeds the water, fires the impulses and rolls the mutations,
`_process(delta)` deltas vary with frame rate, and randomness drawn
conditionally on unrecorded state desynchronises a replay silently and
progressively.

**B — record a state trace** and play it back as data. Robust, needs no
determinism, larger.

Settled by testing rather than from first principles. `tools/drive.gd` already
takes `--seed=` and `--trace=<secs>`, which dumps the player's radius, gape,
wound, hunger and both genome registers plus all 34 field bodies' ranges, radii,
wounds, states, targets and genomes, and logs every sensation with a timestamp.
`--fixed-fps N` forces `delta = 1/N`. That is a state diff with no new code.

| test | result |
| --- | --- |
| seed 12345, `--fixed-fps 60`, 40 s, `--hold=d`, two processes | **byte-identical**, 455 lines each; only the `--out=` filename differs |
| seed 4242, `--fixed-fps 60`, **200 s**, `--forage --evade` — 12 meals, r26 → r38, water reseeded repeatedly | **byte-identical**, 1814 lines, 12,000 frames |
| same seed, **no** `--fixed-fps` | diverges at the first logged event, 0.15 s against 0.14 s; 833 of ~910 lines differ |
| seed 12345 at 30 fps against the same seed at 60 | 840 lines differ — a different run |
| seed 999 against seed 12345 at 60 | 852 lines differ, so `seed()` is honoured and the test is not vacuous |
| **`--mode=0` against `--mode=1`, same seed, 30 s** | **0 divergent simulation lines** |

So the simulation **is** bit-exactly reproducible across processes given a
seeded global stream and a fixed timestep. Option A is reachable.

The last row is worth keeping for its own sake: it is the first measurement of
the invariant `perception.md` §4 and `normal_mode.gd`'s header both assert —
*both modes run the same simulation* — and `game/vision/` passes it exactly.

## 2. The finding that decides it

> **This was a bug in the shipped build and has been fixed separately.** It is
> recorded here because this is where it was found and because it is the reason
> §3 goes the way it does.

Two runs, seed 7, `--fixed-fps 60`: one clean, one paused at t=10 and resumed at
t=15. `tools/drive.gd` is `PROCESS_MODE_ALWAYS`, so its clock counts paused
time, and comparing the paused run at t=30 against the clean run at t=25
compares **equal simulation time**.

- before the pause: **identical**, so the comparison is sound
- during the pause: **identical**, so the pause really froze the simulation
- at equal simulation time afterwards: **all 34 bodies in different places.**
  Same radii, same genomes — seeding was identical — different positions.
  Cell 0 at **800.7** units against **912.4**

The cause was in `game/perception/signal_bus.gd`. **There was no
`RandomNumberGenerator` anywhere in this project.** Every draw in `cell.gd`,
`food.gd`, `genome.gd`, `motes.gd`, `normal_mode.gd` *and* `signal_bus.gd` came
off the one global stream, and the bus drew from it — a beat jitter under dread,
and a taste-bearing jitter **ungated at 1.5 Hz, always**, even for a cell with
no `chemocyte` and a taste level of zero.

`Membrane` is `process_mode = 3` (ALWAYS), so the bus keeps stepping through a
pause while the simulation nodes (`process_mode = 1`) do not. Five wall-clock
seconds on the pause screen pulled roughly seven draws out of the shared stream.

Stated plainly: **the perception layer wrote into the simulation through the
random stream, and how long you left the pause screen open changed the world.**
`normal_mode.gd`'s header — *"the simulation is identical in both views and only
the drawing differs"* — and `perception.md` §4 — *"If a view ever changes how the
cell behaves, full vision stops being evidence about point of view"* — were
contradicted by the one view file nobody thought of as a view. `vision.gd` is
innocent, measured. The bus was not.

**The fix**: the bus owns a `RandomNumberGenerator` and every draw in that file
goes through it, so no draw in a view ever touches the simulation's stream
again. That is structural rather than a discipline — a future sensation cannot
reintroduce the bug by forgetting a gate. Measured after: the same pause test
moves cell 0 by **under one unit over 25 seconds** against 112 before, and the
sub-unit remainder tracks the harness's own trace-sampling phase, which shifts
because `drive.gd`'s clock counts paused time.

## 3. The recommendation: B, a state trace

Not because A failed. A passed, at 200 seconds, exactly. It fails on three
things the test cannot show.

1. **The stream is shared with the perception layer, and that layer draws
   conditionally on state a recording does not capture.** §2 was one instance.
   `normal_mode.gd`'s `randi()` for the free opening sense is another: one guard
   runs *before* the draw and another *after* it, so whether a draw happens at
   t=5 s depends on genome state. Each is fixable, and each fix is a change to a
   shipped gameplay file for the benefit of something that is not gameplay.
2. **The two-pane screen would itself be a stream consumer under A.** Both panes
   carry a membrane; two buses stepping envelopes would double the jitter draws
   and desynchronise the very replay they are drawing.
3. **A scrub needs keyframes, and a keyframe cannot restore the global stream.**
   GDScript exposes `seed()` and no getter. Seeking backwards would mean
   re-simulating from t=0 — 24,000 frames for a 400-second run, seconds of
   grinding on a phone. The fix is a single seeded RNG threaded through every
   draw: a `RandomNumberGenerator` does have a settable `.state`. That means
   threading one object through roughly forty call sites in six files.

Against that, B costs storage and nothing else. B cannot desync by
construction, seeks in O(1), needs no change to how the game simulates anything
— and, the part that decides it, **needs no change to the four view files
either**, because the replay can write recorded state back into the real `Cell`
/ `Food` / `Genome` / `Motes` nodes and let `soma.gd`, `returns.gd` and
`vision.gd` read them exactly as they do now. *A run keeps nothing*, so
scribbling on those nodes is free: `_wake_up()` rebuilds all of them.

A is the elegant answer and it measures clean. B is the one that does not put a
tripwire under every future gene.

### 3.1 Size, at a realistic run length

Per frame, as `float32`:

| | floats |
| --- | --- |
| player: pos, heading, velocity, radius, wound, steer | 8 |
| 34 field bodies x (pos, heading, radius, wound, gape) | 204 |
| 14 motes x pos | 28 |
| membrane uniforms | 37 |
| `beams` — 3 x (bearing, distance, hit) | 9 |
| `ping_front`, `ping_range`, `held_remaining`, `division`, delta, beat | 9 |
| **total** | **295 floats = 1,180 B** |

At 60 fps that is **69 KB/s**: a 400-second run is **27.7 MB**, 90 seconds is
**6.2 MB**, 60 seconds is **4.1 MB**. Option A for comparison is under 150 KB —
200x smaller, and still the wrong choice.

**The window is the design, not an optimisation.** Keep the **last 60 seconds**
in a preallocated ring: 4.1 MB, allocated once in `_ready()`, never grown, never
written to disk. Nobody rewatches seven minutes; the mistake that killed you is
in the last twenty seconds. The constant is the knob and the arithmetic is
69 KB per second bought.

## 4. The spec

### 4.1 What is recorded

One `PackedFloat32Array` ring of `60 x 60 x 295` floats, written by a `Recorder`
node appended as the **last** child of `NormalMode`, so its `_process` runs
after every other node's and it sees the finished frame. **Nothing is added to
`normal_mode.gd`'s `_process`.**

Alongside it, two small arrays of timestamped events: **state deltas** — the
player's genome, DNA, layout and held sample, a field cell's genome after it
eats, a division committing — and **sensations** — `thrust`, `hit` and `shove`
off `bus.sensation`, plus `motes.struck` and `food.eaten` with their world
positions, which is what the truth pane needs for its bearing rays.

**The membrane is recorded as uniforms, not as bus inputs.** Regenerating the
envelopes at playback would re-roll the taste jitter and the beat jitter, and a
replay that shows a *different* jitter from the one the player actually steered
on is a replay that lies about the one thing the screen exists to check. So
`signal_bus.gd` gains exactly two functions and stays the only file that knows a
uniform name: `capture_block()` and `write_block()`.

`vision.gd`'s camera lag, trail and mark ages are **not** recorded. They are
deterministic filters over positions and events that are, driven by the recorded
per-frame delta, so they reconstruct themselves. That is why the trace is 295
floats and not 500.

### 4.2 Where it lives

**In memory, and nowhere else.** No file, no `user://` path, no serialisation
format, no version field, no Android storage question. The buffer is a member of
the `Recorder`; it survives the death because the death does not free the scene
— only `_leave()` and starting the next run do, and `_wake_up()` clears it
deliberately.

*A run keeps nothing* is honoured to the letter: the replay is the last thing
the run has, and it dies with the run.

### 4.3 The two-pane screen

**No SubViewports. Two `ColorRect`s in the main canvas, side by side, sharing
one `ShaderMaterial`.**

A `SubViewport` is the obvious answer and it is wrong here. A
`SubViewportContainer` sizes its viewport in *canvas* pixels, so at 2400x1080
each pane would render at 800x720 and be upscaled 1.5x — the 9 px contour
becoming a soft 13.5 px, against a shipped game that draws it crisply because
`canvas_items` stretch scales the *transform*, not a render target. Sizing the
SubViewport in device pixels instead fixes the sharpness and breaks the
membrane: `band_px = 104`, `line_px = 9` and `inset_px = 28` are canvas
constants that assume a 720-tall canvas. Neither branch is acceptable.

The direct route has no such problem, because **the membrane is already
resolution-independent and already takes its rect from GDScript.** `membrane.gd`
sets `rect_px` from `field.size`; the shader computes `px = UV * rect_px`, so a
640-wide `ColorRect` draws a complete 640-wide membrane. Both panes are the same
size, so the uniform block is the same for both and they share one material.

**Measured, at both shapes.** The shipped fragment shader was reimplemented
numerically and validated against `perception.md` §3's own measured table before
being trusted: contour peak (22,112,94) against the document's (23,113,94), base
(5.9,14.0,12.75) against (5,13,12) and (6,14,13) — exactly the 8-bit dither's
two rounding outcomes.

| shape | pane | black middle |
| --- | --- | --- |
| 1280x720 today | 1280x720 | 1065 x 505 |
| 2400x1080 today | 1600x720 | 1385 x 505 |
| 1280x720, 88 px transport | **640x632** | **425 x 418** |
| 2400x1080, 88 px transport | **800x632** | **585 x 417** |

A fully grown cell's soma figure is **204 px** across, fitting a 640 pane with
110 px to spare. The bearing map survives untouched because the shader's `bd` is
aspect-corrected: a lobe at -42 degrees lands at the same *relative* spot on
640x632 as on 1280x720, so the panes agree with each other and with the shipped
game by construction.

**The one collision, and it is measured.** `soma.gd`'s `DIVIDE_SEAT = 132` is
the only length on that figure that is not a fraction of anything. Two daughters
at +/-132 with r28.28 span **408 px** against a 425 px black middle — it fits by
8 px a side, and at a stricter threshold the outer flagellum tips land in the
faint tail of the band. Multiply it by `figure.size.x / 1280.0`, or accept it
knowingly. Every generation contains one division, so this is not a rare frame.

**Clipping the world pane** is the only part needing a change to a shipped view
file. `vision.gd`'s `$World` is a `Node2D`; anchors do not clip it and it draws
out to 1900 units, so it would spill across the other pane. Wrap it in a
`Control` with `clip_contents = true` — **this is the one claim in this document
that a render must confirm rather than a measurement.** The guaranteed fallback
is to make `$World` a `Control` drawing into itself with
`draw_set_transform()`. Also `_world.position` assumes the `Water` rect starts
at the viewport origin; it needs a `Water.position` term. Latent today, exactly
zero behaviour change in normal mode.

**`ZOOM` stays 1.0 in the pane, and this finding went the other way from
expected.** A 640x632 pane shows +/-320 x +/-316 world units. Measured off the
traces: while foraging, at least one body is inside that box in **75-80%** of
frames; while drifting it is 0% — but at +/-640 on the shipped canvas, drifting
is *also* 0%, with a median nearest body of 728 units. And the moment the replay
exists for is in frame: **`LUNGE_RANGE` is 220 units**, inside +/-316, so the
approach, the contact and the kill all happen on screen. Halving the zoom to buy
water would halve the fringe, and the fringe is what the pane is for.

**Fill cost is unchanged.** Two half-screen membranes are one screen of fragment
work, and the world layer is drawn over half the pixels — cheaper than today.

### 4.4 Transport

The panes are **632 px tall, not 720**, and the 88 px the transport takes is
taken off them rather than laid over them. The band is 104 px deep from every
edge; a bar floating over the bottom would sit exactly on the astern channel,
which is where *it ate me from behind* is written.

Register: the pause screen's exactly. This is a panel the player consults, not a
sensory screen, and `genes-and-cilia.md` §5's argument for the genome strip
carries here word for word.

Controls, all at least 48 px: `leave`; back 0.25 s / play-pause / forward
0.25 s; a speed toggle cycling 1x, 1/2x, 1/4x; and a scrub track 48 px tall at
about 15 px per second, so a thumb-width is roughly 3 seconds.

**No frame step.** A button tapped sixty times to cross a second is not a
control; 1/4x with a pause does the same job in one tap.

Playback lerps the membrane block and the body positions between recorded
frames, so 1/4x is smooth rather than stepped — which is the whole reason for
recording every frame rather than sampling. The recorded per-frame delta paces
playback, so a stretch the phone rendered at 30 fps replays at the speed it
happened.

Two captions, one under each pane: **`what you felt`** and **`what was there`**.
That is the legend and it is also the thesis; the feature does not work if the
player has to be told which pane is which.

### 4.5 Where it hooks in

Today: `_die()` sets `DYING` and stops the simulation; `_step_death()` drives the
collapse and moves to `WAITING`; `_unhandled_input` sees any tap in `WAITING` and
calls `_wake_up()`, which rebuilds everything.

Four edits, none inside `_process`: `_die()` seals the ring; the `WAITING`
transition calls `_offer_replay(true)`, which shows one centred `watch` button
and calls `_bus.attach(null)` so the run's collapse writes stop fighting the
replay for the same uniforms; the button instances the replay scene as a child
of the run, so the buffer is never freed and no scene change happens; and
`_wake_up()` calls `_offer_replay(false)`, re-attaches the bus and clears the
buffer.

**Tapping anywhere else still restarts, exactly as today** — a `Button` consumes
its own press, so `_unhandled_input` never sees it, and a player who does not
want a replay experiences no change at all.

The replay screen is self-contained: it instances its own membrane rects, soma,
returns and vision, binds them to the run's frozen nodes through the existing
`setup()` calls, writes recorded state into those nodes each frame, and re-emits
the recorded sensations on the existing signals so `vision.gd` draws its kick
rings, bruise rays, ghosts, meals and wake rays unchanged. Closing it is
`queue_free()`.

### 4.6 What it costs in the hot loop

About 295 indexed float writes into one preallocated array and about forty
property reads. No allocation, no dictionary, no signal. Estimated at tens of
microseconds against a 16.6 ms budget.

**That estimate is not a measurement and must not be cited as one.** The number
to take is `Time.get_ticks_usec()` around `capture()`, as a rolling maximum, on
the device — it belongs in this section once it exists.

The one thing that would cause a stutter is allocation, and the ring removes it.
The second would be `food.gd`'s accessors: `genomes()` allocates a fresh array on
every call. The recorder must read `_cells` directly rather than adding an
eighth rebuild.

### 4.7 Constraints

Nothing here touches `project.godot`, `version.json`, `export_presets.cfg`,
`addons/` or `ci/`. No new shader uniform. No `class_name`. No new input action,
no new permission, no `user://` write. GL Compatibility throughout: no
SubViewport, no render target, no canvas group. **This ships as a content pack.**

## 5. What is a bad idea, including parts of the ask

- **Persisting replays to disk.** It contradicts *a run keeps nothing* for a
  thing nobody rewatches, and buys an Android path surface, a growing file, a
  quota question and a format-version field to honour forever.
- **Recording the whole run.** 27.7 MB and rising, to hold five minutes of open
  water nobody will scrub to. The mistake is always local.
- **Option A, despite it measuring clean.** *It works as long as nobody adds a
  `randf()` anywhere, including in a view* is a constraint the next gene will
  break silently and progressively — the worst failure mode a debugging tool
  can have.
- **A frame step button.** See §4.4.
- **The part of the ask that is disproportionate: the transport.** The two panes
  are the feature; a scrub bar, three speeds and jump buttons are a video editor
  grafted onto it. If this has to be cut, ship **play-once-then-loop plus one
  speed toggle** — two controls instead of six, the same recorder, and the whole
  of the owner's sentence delivered.
- **What to build first, and separately: the split-screen renderer as a live
  view mode.** It is the only part that can fail for reasons a document cannot
  predict — the clipping, the pane geometry, the membrane at a shape nothing has
  rendered — and it is independently useful on the owner's phone. Ship the two
  panes, look at them, then hang the recorder off them.

## 6. Other errors found while measuring

1. **`perception.md` §3: *"Nothing is centred, so nothing can collide."*** False
   since Phase 6. `soma.gd` centres a figure on every point-of-view frame,
   `diegetic-hud.md` centres a vesicle on that figure, and `normal_mode.gd`'s own
   scrim comment documents the collision that followed. Strike the sentence.
2. **`soma.gd`'s `DIVIDE_SEAT = 132` is a bare canvas constant in a canvas whose
   width changes.** §4.3.
3. **`vision.gd`'s `_world.position` assumes `Water` starts at the viewport
   origin.** Latent today. §4.3.
4. **`normal_mode.gd`'s `randi()` for the opening sense is consumed on some
   branches and not others.** Harmless today, and a textbook instance of the
   hazard in §3.
5. Two things that are **not** errors, confirmed: `perception.md` §3's measured
   output table is exactly reproducible from the shader text printed in that
   document, and the *one simulation, two views* invariant holds to the bit.

## 7. Left open — owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | How much of the run does the replay keep? | **60 seconds ✓ recommended** · 90 seconds · the whole run | 60 s costs 4 MB and covers the run-up to any death. 90 s is 6 MB. The whole run is 28 MB and mostly empty water. Each extra second costs 69 KB. |
| 2 | Does the truth pane keep the membrane under the world? | **yes ✓ recommended** · no, the right pane is only the water | Keeping it lets the player see the lie and the truth in one glance — the green band pointing one way and the food sitting the other. Dropping it stops the replay being the two shipped modes side by side. |
| 3 | How is the replay offered? | **one `watch` button, tap anywhere else still restarts ✓ recommended** · a gesture · automatically | The button changes nothing for a player who does not want it. A gesture is a thing nobody finds. Automatic makes every death longer. |
| 4 | Every death, or only past generation 1? | **every death ✓ recommended** · from the second generation | Dying in the first thirty seconds is the death a new player most needs explained. |
| 5 | Transport: full or minimal? | **minimal — play/loop and one speed toggle ✓ recommended** · full — scrub, speed, jumps, play/pause | The panes are the feature; the transport is the part to grow after watching somebody use it. §5. |
