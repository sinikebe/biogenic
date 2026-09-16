# Watching the run back, from both sides

> "The game should record a run. Then, when you die, allow you to watch a
> 2 sided replay, one normal view and the other with full vision, so you can see
> what you've done exactly given your set of sensors. This allows to get better
> by seeing our mistakes."

The value is precisely **the gap between the two panes**: what you perceived
against what was actually there. That is the principle the project has held
since Phase 3 — full vision exists to catch the membrane lying — turned around
and aimed at the player's own mistakes instead of at the engine.

Status: built, and **rendered at 1280x720 and 2400x1080**. §1 and §2 are
measurements taken against the shipped build with the harness that already
exists. §2 was a bug in that build and **has been fixed separately from this
feature**. §4 was measured before it was photographed; §4.8 is what the
photographs changed, and it is the only part of this document written after
looking rather than before.

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
| `hunter` — who was chasing you, as an index | 1 |
| **total** | **296 floats = 1,184 B** |

`recorder.gd`'s `STRIDE` is built out of the offsets above and has to equal this
number exactly; an off-by-one there writes one frame's tail into the next
frame's head and corrupts silently, with nothing to see but a replay that
drifts. The last row is the one §4.8 added after the renders, and what it buys
is in §4.8.8: a body's `state` is the one thing the replay deliberately does not
write back, and `hunter()` is a question about exactly that.

At 60 fps that is **69 KB/s**: a 400-second run is **27.1 MB**, 90 seconds is
**6.1 MB**, 60 seconds is **4.1 MB**. Option A for comparison is under 150 KB —
190x smaller, and still the wrong choice.

**The window is the design, not an optimisation.** Keep the **last 60 seconds**
in a preallocated ring: 4.1 MB, allocated once in `_ready()`, never grown, never
written to disk. Nobody rewatches seven minutes; the mistake that killed you is
in the last twenty seconds. The constant is the knob and the arithmetic is
69 KB per second bought.

## 4. The spec

### 4.1 What is recorded

One `PackedFloat32Array` ring of `60 x 60 x 296` floats, written by a `Recorder`
node appended as the **last** child of `NormalMode`, so its `_process` runs
after every other node's and it sees the finished frame. **Nothing is added to
`normal_mode.gd`'s `_process`.**

Alongside it, two small arrays of timestamped events: **state deltas** — the
player's genome, DNA, **both layouts** and held sample, a field cell's genome
after it eats, a division committing — and **sensations** — `thrust`, `hit` and
`shove` off `bus.sensation`, plus `motes.struck` and `food.eaten` with their
world positions, which is what the truth pane needs for its bearing rays.

**Both layouts, and the second is not a duplicate of the first.** The DNA's
layout is where the genes sit; the body's is where the organs are actually worn.
`move()` swaps two loci in the DNA and deliberately leaves the body alone, so
the two part company from the first move of a run — and the soma figure's
fringe and the `ampulla`'s wavefront are both drawn off the body's. Rebuilding
the body's layout from the DNA's at playback drew every organ on the arc its
gene had been moved to rather than the arc it was grown on, which is a lie on
the one screen built to catch lies. Deltas are dictionaries, so the second
layout costs nothing in the ring.

**The membrane is recorded as uniforms, not as bus inputs.** Regenerating the
envelopes at playback would re-roll the taste jitter and the beat jitter, and a
replay that shows a *different* jitter from the one the player actually steered
on is a replay that lies about the one thing the screen exists to check. So
`signal_bus.gd` gains exactly two functions and stays the only file that knows a
uniform name: `capture_block()` and `write_block()`.

`vision.gd`'s camera lag, trail and mark ages are **not** recorded. They are
deterministic filters over positions and events that are, driven by the recorded
per-frame delta, so they reconstruct themselves. That is why the trace is 296
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
| 1280x720, 96 px transport | **640x624** | **425 x 410** |
| 2400x1080, 96 px transport | **800x624** | **585 x 409** |

The transport band was designed at 88 px and shipped at 96; §4.8.9 is the eight
pixels and why. Everything else in this table is unchanged by it — the panes
lost eight rows of water and nothing else moved.

A fully grown cell's soma figure is **204 px** across, fitting a 640 pane with
110 px to spare. The bearing map survives untouched because the shader's `bd` is
aspect-corrected: a lobe at -42 degrees lands at the same *relative* spot on
640x624 as on 1280x720, so the panes agree with each other and with the shipped
game by construction.

**The collision this section predicted does not exist, and that was settled by
measuring rather than by arithmetic.** `soma.gd`'s `DIVIDE_SEAT = 132` is the
only length on that figure that is not a fraction of anything, and two daughters
at +/-132 with r28.28 span **408 px** against a 425 px black middle — which
reads as eight pixels a side and was the reason this document asked for the seat
to be scaled by `figure.size.x / 1280.0`. It is spec arithmetic against a
nominal lip. Rendered, the daughters' outer body edge sits **140 px** from the
pane edge, where the shader's `inner = smoothstep(-104, 0, -112)` is **0** and
the band contributes exactly nothing; at the full 22 px wobble, with the outer
flagellum tips at ~116 px, `band = 0.092` — and `_hush()` idles every glow lobe
through a division, so what reaches the screen is about **0.8 of 255 green**.
The scaling was written, rendered, and reverted. §4.8.3.

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
expected.** A 640x624 pane shows +/-320 x +/-312 world units. Measured off the
traces: while foraging, at least one body is inside that box in **75-80%** of
frames; while drifting it is 0% — but at +/-640 on the shipped canvas, drifting
is *also* 0%, with a median nearest body of 728 units. And the moment the replay
exists for is in frame: **`LUNGE_RANGE` is 220 units**, inside +/-312, so the
approach, the contact and the kill all happen on screen. Halving the zoom to buy
water would halve the fringe, and the fringe is what the pane is for.

**Fill cost is unchanged.** Two half-screen membranes are one screen of fragment
work, and the world layer is drawn over half the pixels — cheaper than today.

### 4.4 Transport

The panes are **624 px tall, not 720**, and the 96 px the transport takes is
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

About 296 indexed float writes into one preallocated array, about forty property
reads and one call — `food.hunter()`, which §4.8.8 bought. No allocation, no
dictionary, no signal.

**Measured**, with `Time.get_ticks_usec()` around `capture()`, over a
**400-second** `--forage --evade` run at `--fixed-fps 60` — **24,000 captures**,
the ring wrapping six times, two processes run one at a time so neither is
measuring the other's CPU:

```
--mode=1 --seed=4242 --genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1 \
    --forage --evade --capture-cost=50
```

| over 400 s, 24,000 captures | without the hunter column | shipped |
| --- | --- | --- |
| mean at 50 s | 62.4 µs | 68.7 µs |
| **mean at 400 s** | **86.0 µs** | **93.7 µs** |
| **rolling maximum at 400 s** | **624 µs** | **710 µs** |

**The duration is part of the number and it was not stated before.** This
section used to print a 150-second rolling maximum of 148 µs as though it were a
bound; a rolling maximum with no window is not a measurement, it is however long
you happened to watch. Over four hundred seconds the same statistic reaches
**710 µs**, 4.8x the printed figure — and the mean climbs by about a third
across the run as the water fills with bodies that have eaten, which is the
`_deltas` prune doing its job rather than a leak. Against a 16,600 µs frame
budget that is **0.6% mean and 4.3% at its worst**, and the worst is one frame
in twenty-four thousand.

The hunter column costs about **7.7 µs of the 93.7**, measured as the paired
difference above rather than estimated. It is one loop over 34 bodies that
early-exits on a state compare for all but the one or two that are stalking, and
it is the price of the truth pane having any predator ring at all.

The figures are from the headless container (llvmpipe, no Vulkan), not from the
phone; they are an upper bound on the GDScript interpreter's share, which is all
of it — nothing here touches the GPU.

**Two things had to change to get there, and the first is the interesting one.**

- **`food.gape_at()` is not a property read.** It resolves to
  `gape_of(tier_of(genome))`: a dictionary lookup and two static calls, 102 of
  them a frame, and measured at **34 of the 80 µs** the first working version
  cost — 43% of the whole capture for one of the six columns. A gape is
  `GAPE_BY_TIER[tier] * radius` and the tier only moves when the genome does,
  which the recorder already watches, so the multiplier is cached on that event
  and the hot loop does a multiply. The float written is bit-identical.
- The genome-change detection is an integer compare per body, never a dictionary
  walk: a body's `serial` and `meals` catch a reseed and a meal between them,
  and one summed hash catches everything about the player's genome.

The one thing that would cause a stutter is allocation, and the ring removes it.
The second would be `food.gd`'s accessors: `genomes()` allocates a fresh array on
every call. The recorder reads the bodies directly rather than adding an eighth
rebuild — through a `bodies()` accessor that returns the live array, so no file
is reaching into another's privates to do it.

### 4.7 Constraints

Nothing here touches `project.godot`, `version.json`, `export_presets.cfg`,
`addons/` or `ci/`. No new shader uniform. No `class_name`. No new input action,
no new permission, no `user://` write. GL Compatibility throughout: no
SubViewport, no render target, no canvas group. **This ships as a content pack.**

### 4.8 What the renders changed

Four things this document asserted survive a photograph unaltered: the clipping
works, the membrane draws complete at 640x624 and at 800x624, `ZOOM` 1.0 keeps
the kill in frame, and the two views do read as two views. Eight did not —
four found by photographing the screen, and four more found by reading it back
against the shipped files afterwards.

**1. The panes had no edge, and the membrane is not one.** On a quiet frame the
contour peaks at **G=14 against a G=13 background** — one level out of 255.
§4.3 assumed the membrane would frame each pane; it frames it only when there is
something to feel. On the shipped one-pane screen that costs nothing, because
the edge of the pane is the edge of the screen. Here the world layer is clipped
at the seam, so a body sliced vertically in half at x=640 with no line beside it
reads as a fault in the picture rather than as the edge of a window, and the two
panes read as one wide field with two cells adrift in it. **The gap between the
two panes cannot be read off a picture whose halves have no boundary.**

The fix is two `ColorRect`s on the legend layer: a **2 px seam** at the pane
join, `Color(0.12, 0.70, 0.58, 0.20)`, measuring G=47 — well under the contour's
own peak of 112, so the membrane still wins every frame it has anything to say —
and a **1 px sill** under both panes at 0.13, G=35, which also does §4.4's
register job by drawing the band as a surface rather than asserting it.

**2. The pointer fidelity gap is bigger than dead ahead.** `returns.gd`'s
`EDGE_HIDE`/`EDGE_SHOW` are absolute canvas px and are *correct* absolute px —
they are the contour's furthest inward reach and the band's inner lip, both of
which are the same absolute depth in a pane as on a full screen. The loss comes
from the pane being smaller, and it is not uniform, because a 640x624 pane is
nearly square and a 1280x720 screen is not:

| | full screen | left pane | loss |
| --- | --- | --- | --- |
| dead ahead, full strength | 134 units | 108 | −19% |
| dead ahead, last trace | 179 | 153 | −15% |
| **abeam, full strength** | **299** | **111** | **−63%** |
| abeam, last trace | 344 | 155 | −55% |
| any mark at all, by area | 245,800 sq units | 95,000 | **−61%** |

So **the left pane shows the player about a third of the ocellus returns they
actually had.** Inside ~108 units in every direction it is exact, which covers
contact and the kill; what is lost is the approach between 110 and 300 units.

It is left alone, and the two reasons are worth writing down carefully, because
the reason this section gave first was **wrong**. It said a pane-only
`EDGE_SHOW` of 88 "would draw pointers at distances where the player had none".
It cannot. The pane's edge distance is `min(320 − |dx|, 316 − |dy|)` and the
screen's is `min(640 − |dx|, 360 − |dy|)`, so the pane's is *strictly smaller*
at every offset at both shapes, and `smoothstep(56, 88, edge_pane)` is therefore
`<= smoothstep(56, 132, edge_screen)` everywhere. A pane-only 88 is a strict
subset of what the player saw and can invent nothing. The conclusion was right
and the argument for it was not, which is the worse of the two errors to leave
in a document that is the project's memory.

The two reasons that hold:

- **88 px in is on the band, at full strength.** `EDGE_SHOW = 132` is not a
  round number because it is not an aesthetic choice: it is exactly where the
  shader's `inner = smoothstep(-104, 0, sdf)` reaches zero, the band's inner
  lip. At 88 px in, `inner = smoothstep(-104, 0, -(88 - 28)) = 0.385` and
  `band = inner² = 0.148` — 15% of peak, so the pointer would sit on a lit
  surface rather than on black. `returns.gd`'s own docstring says what 132
  buys: "the pointer handing the bearing back to the lobe that carries it the
  rest of the way". At 88 that handoff is gone and the two instruments overlap
  instead of meeting.
- **It would put replay-only calibration inside a shipped view file.** §3's
  whole claim is that the replay needs no change to the four view files. One
  constant that means one thing in a run and another in a pane is the crack
  that claim leaks out of.

What is lost is worth stating plainly, because it is smaller than the table
above makes it look: **the distance of a return, never its existence and never
its bearing.** The bearing lives in the membrane lobe, which is recorded as
uniforms and reproduced bit-exactly. Rendered, with an `ocellus` on the
starboard flank: the felt pane keeps the violet lobe in the corner at the right
bearing and loses only the dot.

**3. The division fits in both panes, and §4.3's collision was arithmetic rather
than visible.** Measured at 1280x720, ink extents against the nominal 425 px
black middle:

| | ink spans | clear of the band lip |
| --- | --- | --- |
| point of view, `DIVIDE_SEAT` scaled | 214..442 | 106 / 90 px |
| point of view, unscaled | 148..510 | 40 / 22 px |
| **truth pane** (`DIVIDE_SPREAD` 160, world scale) | 774..1154 | **26 / 19 px** |

The truth pane is four times tighter than the point-of-view pane, and nobody
measured it, because §4.3's collision was about `DIVIDE_SEAT` and the truth pane
does not use it. It does not collide either: across the daughters' row the band
contributes **+1 to +3 green levels** between its nominal lip and the contour
(G=15 at the lip, 22 at sixty px in, 111 at the contour). None of the three rows
above is a collision anybody can see. At 2400x1080 the truth pane has 101 px
clear and the question does not arise.

Two costs of the scaling are real, and neither is a collision. In the pane it
halves the seat while leaving the daughter radius alone, so the two bodies sit
36 px apart where the player watched them 168 px apart — **the replay shows a
division that does not look like the one it is replaying.** And because
`_figure.size.x` is the whole viewport in normal mode, it moves the *shipped*
2400x1080 division as well: the pair's half-span goes from 181 to 213 canvas px,
and a render of normal mode at that shape differs from `main` by **59,374
pixels**.

**The revert was taken, and this is the decision going the other way from §4.3
and §6.2.** Three reasons, in the order they weigh. It is a live visual change
to a shipped screen riding in on a replay feature, which is not what content
packs are for. It scales the seat and not `SomaLayer.SCALE`, so the separation
moves with the screen width while the bodies do not — a replay misrepresenting
the exact frame it is replaying, which is the one failure this screen may not
have. And the collision it was fixing does not exist: §4.3 now carries the
measurement. `DIVIDE_SEAT_WIDTH` went with it, because it becomes dead.

Proved by render rather than by reading: normal mode at 1280x720 **and** at
2400x1080, in full vision and on a point-of-view division, is byte-identical
against `main` with the revert in and differs at 2400x1080 without it.

**4. The transport broke the pause screen's own spacing rule.** `normal_mode.gd`
writes it down: 56 px buttons with **48 canvas px of dead water** between the
safe control and the destructive one, "do not tighten it back up for looks". The
transport shipped 48 px buttons 12 canvas px apart — 18 device px, about 1.1 mm
on a 2400x1080 phone — so a thumb going for the speed toggle lands on `leave`.
Widened to **32**, about 2.9 mm; not the pause screen's 48, because `leave` here
is reversible — closing the screen puts the `watch` offer back, so a mis-tap
costs one tap and not the replay.

The captions were also quieter than the chrome beside them: 15 px at 0.45
measures 5.05:1 against `pause` at 17 px and 0.82 measuring 7.71:1. Both clear
AA; readability was never the problem, the hierarchy was. At 16 px and 0.60 the
legend measures 6.39:1 — above the chrome, under everything in a pane.

**Left alone, deliberately.** The control row is centred at the bottom, which on
a landscape phone is the least reachable point on the screen, and it is exactly
where the pause screen puts its own `leave`, so moving it would break the one
register §4.4 named. At 2400x1080 the band is 1600 canvas px wide with 368 px of
buttons in the middle and 80% of it empty; if the owner wants `leave` under a
thumb, the right pane's margin is where it goes. `1x` as a state label rather
than a verb matches the pause screen's `north up` toggle, and it is the only
number on the screen, so it reads.

**The sister is off screen in the truth pane.** `SISTER_DISTANCE` is 560 world
units, and its own comment says she is left "inside the frame in full vision, so
the answer to *what happened to the other one* is visible". A 640-wide pane at
`ZOOM` 1.0 reaches 320. She is visible in the shipped game and never in the
replay. Halving the zoom is ruled out by §4.3 and is the wrong trade; this is
the price of the pane, recorded rather than fixed.

**5. The replay ignored the player's light setting, which is an accessibility
bug on a phone.** `panes.gd` instances a `SignalBus` of its own and never told
it what `gain` was, so it sat at `GAIN_DEFAULT` — which is also `GAIN_MIN` —
and `write_block()` ends in an apply, so every replay frame stamped 1.0 onto the
pane material.

The rationale in `signal_bus.gd` for keeping `gain` out of the recorded block is
right and stays: it is a setting the player owns *now*, not a fact about the run
that ended. Out of the block simply means it has to arrive by another route, and
none existed. The route is the run's own bus when there is one — the live value,
including a drag the pause screen has not written to `user://` yet — and
`RunState.load_gain()` otherwise, applied once after the panes are built.

Measured, at `--gain=2.4` against the default, on the same seeded run:

| | gain 1.0 | gain 2.4 |
| --- | --- | --- |
| live death screen, invite contour peak | G=33 | **G=78** |
| replay pane, before the fix (peak of 3 samples) | G=209 | G=203 |
| replay pane, after the fix (peak of 3 samples) | G=209 | **G=255, all three** |

Before, the pane was indistinguishable from itself at the two settings — the
spread is frame-phase noise on a beating membrane, not response. After, it
clips at full green where before it never passed 209. `normal_mode.gd` writes
down the case the control exists for: *a starving, hunted cell renders at
(6,23,23), and on an LCD phone in daylight that is close to invisible.* Losing
that on the one screen built to explain the death is the worst place to lose it.

**6. Android Back could close the replay and leave the run in the same press.**
`normal_mode._notification(NOTIFICATION_WM_GO_BACK_REQUEST)` clears the replay
*synchronously*. That file has recorded since Phase 2 that Android has delivered
Back as a notification, as a key event, or as both, depending on the version —
which is why `_toggle_pause()` carries a same-frame latch. With the replay up
that hazard gets a worse ending: the notification closes the screen, and the
duplicate `ui_cancel` behind it finds `_replay` already null and `_life` not
ALIVE, and calls `_leave()`. The player asked to close a screen and lost the
death screen under it.

Fixed with one counter on both doors (`_back_once()`), not by deleting the
notification branch: on a build that delivers *only* the notification, deleting
it stops Back working inside the replay unless the screen grows an Android quirk
of its own. Both doors are read inside one engine iteration and see the same
`get_process_frames()`, which is the assumption the existing latch has shipped
on.

**7. The bus detach and re-attach were a hand-maintained pair.** The detach
itself is right and stays: `replay.gd` runs at `process_priority = -10`, so it
processes *before* the run's `Membrane/Signals`, and if the two materials were
ever shared the run's `collapse()` would win the race and the replay would show
the shut aperture instead of the recording. What was wrong was the pairing —
`_watch()` detached and `_close_replay()` re-attached, and any route that freed
the screen without going through `_close_replay()` left the run's membrane
unplugged forever. `replay.gd`'s own `else: queue_free()` branch is exactly such
a route, and it would have left `normal_mode._replay` pointing at a freed object
with a permanently frozen death screen behind it — silent until a player
reported that the game had stopped.

The re-attach now hangs on `_replay.tree_exited`, so it happens however the
screen goes away. `_close_replay()` clears its handle *before* freeing, which is
what makes it idempotent and stops `queue_free` → `tree_exited` → `_close_replay`
going round twice. `_watch()` also gained the `_life == WAITING` guard it had
been relying on its only caller to provide: the screen stops the food field
processing on the way in, which is free after `_die()` and not a frame earlier.

**8. `hunter()` frozen removed the predator rings from the replay entirely.**
Worse than "a stale ring": `food.gd`'s own comment says the body that swallowed
you is reseeded — "it is gone, not fleeing" — and a reseeded body is `DRIFT`, so
`hunter()` returns −1, and `vision.gd` draws **no** dread, wake or lunge ring
for the whole sixty seconds. Measured on a seeded predation death, printing
`hunter()` every half-second through a full replay loop: **−1 on every frame**
before, **0 — the body that killed you — on every frame** after. The truth pane
lost the one instrument that explains the death, in exactly the case it exists
for.

Recorded rather than suppressed. `hunter()` only ever needs the single nearest
stalker, so it is one float at the tail of the stride, stepped rather than
lerped the way `commit` is — an index halfway between body 3 and body 9 is body
6, which is a different cell in a different place. `food.restore_hunter()` puts
it back on the two fields `hunter()` reads and clears every other claim on the
player, because a field frozen at the moment of death still holds whatever was
chasing you then. 4 bytes a frame against 1,180 is 0.24 KB/s against 69 — a 0.3%
window cost for the instrument the pane is for.

**9. The transport row sat where the Android gesture bar lives.** At `BAND = 88`
the row's bottom edge was `_view.y − 88 + 32 + 48` = 712 of 720: **8 canvas px**,
12 device px on a 2400x1080 phone. In sensor landscape that is the system
gesture handle, and this is the first control in the game to sit on that edge —
`membrane.gd._inset_px()`'s safe-area logic is about the contour and does not
reach a `Control`. The band went to **96** rather than `ROW_TOP` to 20, and a
render decided which: raising `ROW_TOP` alone drives the row up into the
captions, while eight more pixels of band lifts the whole assembly by eight and
keeps the caption-to-row gap at the 4 px the designer set. The clearance
doubles to 16 canvas px, 24 device px. `BUTTON_GAP` stays at 32. §4.8.4's
"left alone, deliberately" is about the row's *horizontal* place and is
untouched by this.

**10. Beats piled up while the game was paused.** `Membrane` is
`PROCESS_MODE_ALWAYS` and `Recorder` is `PROCESS_MODE_PAUSABLE`, so the bus goes
on emitting `beat` through a pause while the recorder's clock is frozen. A
thirty-second pause files about forty-two `beat` rows at one identical
timestamp, and `replay._fire_events()` fires all of them in a single frame — a
burst of wake rays that never happened. One `if get_tree().paused: return` in
`_on_sensation` ends it. It is the same asymmetry §2 found in the random stream,
in the last place it still reached.

## 5. What is a bad idea, including parts of the ask

- **Persisting replays to disk.** It contradicts *a run keeps nothing* for a
  thing nobody rewatches, and buys an Android path surface, a growing file, a
  quota question and a format-version field to honour forever.
- **Recording the whole run.** 27.1 MB and rising, to hold five minutes of open
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
2. ~~**`soma.gd`'s `DIVIDE_SEAT = 132` is a bare canvas constant in a canvas
   whose width changes.**~~ **Struck.** The premise proves too much:
   `SomaLayer.SCALE`, the shader's `band_px`, `line_px`, `inset_px`, and
   `returns.gd`'s `EDGE_HIDE`, `EDGE_SHOW` and `POINT_HALO` are all equally bare
   canvas constants in a canvas whose width changes, and every one of them is
   deliberately absolute — that is the house style, and §4.8.2 above leans on it.
   The one thing on this screen that *is* proportional, the bearing map, is
   aspect-corrected inside the shader and says so in the shader text. Scaling
   one length out of that set made the replay disagree with the frame it was
   replaying and moved a shipped screen; §4.3 has the measurement and §4.8.3 has
   the decision.
3. **`vision.gd`'s `_world.position` assumes `Water` starts at the viewport
   origin.** Latent today. §4.3.
4. **`normal_mode.gd`'s `randi()` for the opening sense is consumed on some
   branches and not others.** Harmless today, and a textbook instance of the
   hazard in §3.
5. **`normal_mode.gd`'s three `DIVIDE_FADE*` constants are coupled to the
   replay and nothing says so at the constants.** The recorder writes a whole
   division choice as one float — the difference between the two daughters'
   brightnesses — and the replay recovers the lean from it by dividing by
   `DIVIDE_FADE - DIVIDE_FADE_DIM`. That round-trip is exact only because both
   daughters leave the same `DIVIDE_FADE_IDLE` on the same clock, so the leaned
   one's rise plus the declined one's fall is exactly that span. Move any of the
   three, or give either daughter a different base or curve, and the replay
   reconstructs the wrong pair with **no error anywhere**. The float itself is
   verified exact and the two regimes are 1.34 apart in float32, so they cannot
   collide; the coupling is now written at the constants as well as at the
   decoder, which is where somebody about to change one would look.
6. Two things that are **not** errors, confirmed: `perception.md` §3's measured
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
