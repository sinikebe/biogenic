# Hunger you cannot miss

The owner, 2026-10-03:

> Also : hunger. It must be more than what it is. I often die of hunger without
> noticing anything.
>
> Do whatever is faster first so I can feel it

This reopens `energy.md` §7.6 row 4, which was "keep it, and judge it on the
dev app". It has now been judged on the dev app, and it failed. This is the
first and fastest step. It needs only a content pack: no binary, nothing on the
wire, and no balance change.

**Status.** Designed and prototyped on 2026-10-03, in a scratch copy of `dev` at
b77de21. The prototype was rendered under GL Compatibility at 1280x720 and
2400x1080 in both views, and looked at. A `--seed=` frame rendered three times
gave 0 differing pixels. Then built (§10).

## 0. The problem

The only cue is a beat that gets slower and dimmer as death approaches. In
today's renders the contour's glance at a beat peak falls from 62 (fed) to 39
(the last chance). In the last ten seconds it lands twice, at a third of its
strength, and then nothing comes for 4.6 s before death. Nothing at the middle
of the screen changes, and the middle is where the eyes are. A warning that
gets quieter as the danger rises reads as nothing at all, or as dread.

## 1. The decision: starving is an alarm, said three ways

All three cues come from the two numbers `metabolism.gd` already has: `hunger`
and `dying()`. No words. No new colour: everything stays `SELF_TINT`
`Color(0.12, 0.70, 0.58)` on the base `Color(0.023, 0.055, 0.05)`. The gene
wheel has no free hue left, and red belongs to the mouth that can eat you.

| cue | where the eye is | what the player sees | starts |
| --- | --- | --- | --- |
| **The beat races** | the screen's edge, in both views | The heartbeat *quickens* and stays at full strength: every 2.4 s when fed, 1.2 s at empty, 0.75 s at the very end. Hunger never dims it any more. | half a tank |
| **The body goes slack** | the middle, in both views (one routine draws the soma figure and the real cell) | The body's rim crumples into nine creases as it loses turgor, and the creases deepen as the tank empties | half a tank |
| **The membrane falls in** | the frame, in both views | When the tank empties, the contour drops 22 px inward all the way round, then keeps closing to 64 px through the last ten seconds. The starving death closes the rest of the way from there | empty |

**A meal undoes all three at once.** The beat calms on the next beat, the body
fills out in half a second and the membrane springs open in a quarter of a
second, right behind the ingest flood. That relief is what teaches *eating
fixes this*, with no words.

**Realism, used and dropped.**
- *Used.* A starving cell loses turgor, and here that becomes the creases. A
  body running out of fuel races its heart, and a faint narrows vision before it
  takes it: that is the beat and the closing membrane.
- *Dropped.* A starving cell also shrinks. The drawn body is never allowed to
  look smaller than its radius (`cilia.gd`, the wound rule), because size
  decides every encounter. So the creases only go inward, and the body's extent
  stays its radius.

**What does not move.** `HUNGER_SECONDS` 36, `STARVE_GRACE` 10, `MEAL` 1.0 and
every cost of moving stay as they are. The cell still dies at 30.3 s. These are
thresholds for *noticing*, not for starving.

## 2. Values

### 2.1 `metabolism.gd`, the one mapping

perception.md §6.2 says the mapping from hunger to the beat lives here and
nowhere else. That stays true.

```gdscript
const REST_PERIOD := 2.4    # fed: unchanged
const HUNGRY_FROM := 0.5    # the warning starts at half a tank
const EMPTY_PERIOD := 1.2   # tank empty: twice the rest rate
const LAST_PERIOD := 0.75   # end of the last chance: 80 a minute, 3.2x rest
const FAINT_ONSET := 0.35   # share of the fall that lands the moment the tank empties
# Retired: STARVED_PERIOD, DYING_PERIOD, STARVED_AMPLITUDE.

func hungry() -> float:     # 0 above half a tank, 1 at empty and through the grace
	return clampf((hunger - HUNGRY_FROM) / (1.0 - HUNGRY_FROM), 0.0, 1.0)

func beat_period() -> float:
	return lerpf(lerpf(REST_PERIOD, EMPTY_PERIOD, hungry()), LAST_PERIOD, dying())

func beat_amplitude() -> float:
	return FULL_AMPLITUDE   # hunger never dims the beat; only dread does

func faint() -> float:      # how far the membrane has fallen in, 0..1
	return lerpf(FAINT_ONSET, 1.0, dying()) if hunger >= 1.0 else 0.0
```

Here is how that plays out for a born cell steered a third of the time (burn
x1.78). It is empty at 20.2 s and dead at 30.2 s:

| t | hunger | beat every | body | membrane |
| --- | --- | --- | --- | --- |
| 0 – 10 s | 0 – 0.5 | 2.4 s | smooth | where it always is |
| 14 s | 0.7 | 1.9 s | creases begin (slack 0.4) | — |
| 18 s | 0.9 | 1.4 s | crumpled (0.8) | — |
| 20.2 s | empty | 1.2 s | fully crumpled | drops 22 px in 0.28 s |
| 30.2 s | end of grace | 0.75 s, then none | — | 64 px in; the quiet death closes from here |

Compared with today (arithmetic off the shipped envelope):
- **beats in the last ten seconds:** 2 today, 10 here;
- **beats in the second half of the tank:** 2 today, 6 here;
- **silence before death:** 4.6 s today, 0.5 s here.

### 2.2 `signal_bus.gd`

```gdscript
const FAINT_PX := 64.0         # canvas px the contour has fallen in by the end
const FAINT_IN := 80.0         # px/s falling (the 22 px onset lands in 0.28 s)
const FAINT_OUT := 240.0       # px/s springing back on a meal (all of it in 0.27 s)
const BEAT_PERIOD_MIN := 0.4   # no beat faster than 2.5 Hz, dread's jitter included
var _faint := 0.0              # px, stepped in _process like dread
var _faint_target := 0.0

## The last chance. Posted every frame by the run, like dread(); gated emit of
## &"faint" {"strength": level} on `sensation`, which is step 2's haptics hook.
func faint(level: float) -> void:
	_faint_target = clampf(level, 0.0, 1.0) * FAINT_PX
```

- **`_process`:** `_faint = move_toward(_faint, _faint_target, delta * (FAINT_IN if _faint_target > _faint else FAINT_OUT))`.
- **`_apply()`:** `inset_px` is `_inset_override` when that is set, otherwise
  `_inset + _faint`.
- **`collapse()`:** the close starts from where the membrane fell,
  `lerpf(_inset + _faint, DEATH_INSET, u * u)`. `_end_collapse()` zeroes both
  values.
- **`_step_beat()`:** `clampf(_beat_period * jitter, BEAT_PERIOD_MIN, ceiling)`.
  The worst case is the end of the grace under full dread, 0.75 x 0.6 = 0.45 s,
  which is 2.2 Hz. That is under the three-flashes-a-second line.
- **The replay block:** add one float, so `BLOCK_FLOATS` goes from 46 to 47.
  - `capture_block`: `out[at + 46] = _faint`.
  - `write_block`: `_faint = block[at + 46]` and `_faint_target = _faint`.
  - `inset_px` still stays out of the block. The fall is a delta on whatever
    rect is drawn into.

### 2.3 `cilia.gd`, `soma.gd`, `vision.gd`: the slack body

`draw_cell()` gains a last argument, `slack: float = 0.0`, and passes it to
`_draw_ovoid()`. Every other body passes nothing.

```gdscript
const SLACK_FOLDS := 9.0    # odd, so it never reads as a symmetric badge
const SLACK_DEPTH := 0.12   # of r, inward only: 5.3 canvas px on the born figure, 3.1 in full vision
const SLACK_SHARP := 2.0    # narrow creases, broad lobes
const SLACK_DRIFT := 0.15   # rad/s: the folds wander, wet and slow
const SLACK_STEPS := 96     # rim points while slack; 40 cannot draw nine folds

# in _draw_ovoid:
var steps := OVOID_STEPS if slack <= 0.0 else SLACK_STEPS
var crease := 1.0 - SLACK_DEPTH * slack * pow(0.5 + 0.5 * cos(t * SLACK_FOLDS
	+ phase * 3.0 + clock * SLACK_DRIFT), SLACK_SHARP)
body[i] = _surface(at, fwd, stb, r * breathe * crease, t, squeeze)
```

- **The tear loop** walks `steps`, not `OVOID_STEPS`.
- **The fill, the rim alpha and the nucleus do not change.** A thinner fill was
  tried, and it cost the figure 1.25 of glance against the control blocks
  (§7, check 6).
- **Organs stay rooted where they were**, and the skin pulls in beneath them.
  On screen this reads as shrivelling, and it saves threading the crease through
  every one of the fringe's gatherers.

**`soma.gd` and `vision.gd`.** Each gets a `var slack := 0.0`, written by the
run and passed in the main `draw_cell` call (daughters pass 0, because they are
born fed).

### 2.4 `normal_mode.gd`

```gdscript
const SLACK_EASE := 2.0   # per second: a meal fills the body out in half a second
# once a frame, beside set_beat():
_slack = move_toward(_slack, _metabolism.hungry(), delta * SLACK_EASE)
_soma.slack = _slack
_vision.slack = _slack
_bus.faint(_metabolism.faint())
```

**Reset.** `_slack = 0.0` wherever a new body arrives: birth, waking up, and
arriving in a pond.

**The pause figure.** `_draw_figure_body()` passes `_slack` as `draw_cell`'s
last argument. In a pond with the menu open, call `_redraw_figure()` whenever
`_slack` has moved 0.05 since the last draw.

### 2.5 The replay

- **`recorder.gd`:** add `AT_SLACK := AT_PING_RANGE + 10`, captured from
  `_soma.slack`, which moves `STRIDE` to `+ 11`.
- **`replay.gd`:** add `_panes.set_slack(_frame[RecorderNode.AT_SLACK])`.
- **`panes.gd`:** `set_slack()` writes `_soma.slack` and `_vision.slack`. It
  also mirrors the live run's soma, beside `set_division` and `set_eye`.

The racing beat is already recorded, because the block holds the pulse every
frame.

## 3. The thresholds, and why

- **Half a tank (`HUNGRY_FROM` 0.5).** At the usual pace that is 20 s from
  death. That is a good forager's gap between meals (median 12.5 s, energy.md
  §7.3), with margin to spare.
  - It is late enough that a forager who eats on time is not warned all the
    time. Their bar averages 0.46 to 0.49, so they meet the warning only on the
    way to the next meal.
  - The ramp is linear. At 0.6 the change is below what anyone notices; by 0.7
    it is plain (1.9 s against 2.4 s), with 16 s left to live.
- **Empty.** This is where the game's own rule changes: spending stops and the
  grace starts. So the membrane moves as an *event* (22 px in 0.28 s), not as a
  slope nobody notices they are on.
- **0.75 s at the very end.** That is three times the rest rate, and still
  longer than the 0.51 s one beat's envelope lasts, so the beats stay separate
  instead of blurring into a glow.

## 4. What each place shows

| where | what it shows |
| --- | --- |
| point of view | all three cues |
| full vision | All three cues. Full vision has always shown the membrane's contour around the water, so it falls in over the water too; nothing in the water is hidden. The body is the real cell, now the one crumpled egg among smooth ones. |
| pause, single player | Hunger is frozen. The beat keeps racing behind the scrim at the frozen rate, and the membrane holds where it fell. It works as a reminder, not as a clock. The pause figure is crumpled too. |
| shared pond (nothing pauses) | Hunger burns under the menu. The racing membrane shows through `SCRIM_POV` and `SCRIM_POND`, and the pause figure crumples live. **A friend is never drawn crumpled**: hunger is each player's own and is not sent over the network. |
| the quiet death | The racing beat stops, and the gap is felt within a second. The aperture closes from where it fell; `FAINT_COLLAPSE` is unchanged. The last beat lights it at full strength, in teal, still with no white. |
| replay | "what you felt" crumples and closes exactly as it did (§2.5) |
| first life | No line of text: row 4's "no words" stands. The three cues, and the relief when you eat, are the lesson. |
| controls | Nothing depends on the input scheme. In the last ten seconds the fallen contour runs behind the `stick`/`pads` blocks and the pause target. Every touch target stays where it is. |

## 5. Hunger is not dread

| | hunger | dread |
| --- | --- | --- |
| rhythm | faster, and even | stumbles (±40 %) |
| beat strength | full | drains to 0.15 |
| the screen | unchanged | base darker and colder |
| the body | crumples | never changes |
| the membrane | falls in all the way round, in the last 10 s | dents at one bearing (the wake) |

**Both at once is common.** Seed 12345 had dread from 11 s in a plain starving
run. Then the beat is fast, uneven and dim, the body is crumpled, and the
membrane has fallen in, and each of those still says its own thing.
The design's close-up of that frame shows it: "starving + hunted" is crumpled
where "fed + hunted" is smooth, because dread never touches the figure.

## 6. What to watch when the owner plays it

1. **When do they first notice?** The candidates are the quickening (about
   14 s), the creases, or only the drop at empty (20 s). If it is only the drop,
   lower `HUNGRY_FROM` or `EMPTY_PERIOD`.
2. **What does the racing beat read as?** It could read as hunger, as
   *something near*, or as *food near*, which a quickening meant until
   2026-09-29. The crumple and the drop belong to hunger alone, so check whether
   they read the body.
3. **Does a good forager feel warned all the time?** If so, move `HUNGRY_FROM`
   to 0.6.
4. **Outdoors.** The membrane carries it. The body, drawn at `FADE` 0.34,
   washes out in glare (the design's daylight sheet was an illustration only). If the body
   has to read outdoors, the lever is the slack rim at `FADE_PENDING` 0.68 in
   the last chance. That is the figure's one other licence to ask for
   something.
5. **Full vision.** Does the contour closing over the water read as closing in,
   or as a frame in the way? The lever is `FAINT_PX`.
6. **Single-player pause.** Is the racing beat behind the menu a reminder, or a
   nag?
7. **Eating in the last chance.** Does the relief land: the beat calming, the
   body filling out, the membrane opening?
8. **If a racing heart is wrong for the game's tone.** The fallback is today's
   slowing beat plus the crumple and the drop. But the drop would then be lit by
   only two beats in ten seconds, so it would need light of its own, which is
   new work.

## 7. Build plan

**Files.** These are the nine files in §2. The design's prototype held the
first six under the names used here. A headless run through a death and the
replay with the 47-float block raised no script errors. Still left for the
build:
- the resets of `_slack`;
- the pause figure;
- `recorder.gd`, `replay.gd` and `panes.gd`;
- the probe lines.

Then add short notes in the docs:
- `energy.md` §7.6 row 4: reopened by the owner on 2026-10-03, answered by this
  file, and still no words.
- `perception.md` §3: the beat's row.
- `food-and-predators.md`: §5.1 (1.2 s against 2.4 s) and §6.1 (the racing
  beat stops, and the aperture closes from where it fell).
- `diegetic-hud.md` §2.1: rank 4 becomes the beat and the creases.
- `metabolism.gd`: its header.

**Ships as.** A content pack. `project.godot`, `version.json` and `Wire` are
untouched, and there are no new strings.

**Checks.** The build runs all of these.
1. **`levels_probe` passes unchanged.** It holds the 30.3 s death from the
   constants, which proves balance did not move.
2. **New `levels_probe` lines for the mapping.**
   - The period at hunger 0, 0.5 and 1 is 2.4, 2.4 and 1.2.
   - The period at the end of the grace is 0.75.
   - The amplitude is 1.0 everywhere.
   - `faint()` is 0 at hunger 0.99, 0.35 when the grace starts, and 1 when it
     ends.
   - `hungry()` is 0 at 0.5 and 1 at 1.
   - `LAST_PERIOD * (1 - DREAD_JITTER)` is at least `BEAT_PERIOD_MIN`, and
     `BEAT_PERIOD_MIN` is at least 1/3 s.
3. **`drop_probe`'s metabolism check passes.** The node and the static
   functions are untouched.
4. **CI's empty-library trace hash.** It can only move through a beat-cued eye
   flare, because the beat is now faster when hungry. If it moves:
   - diff the trace;
   - confirm that only `eye … flare` lines differ;
   - re-pin it, and say why.
5. **Three renders of one `--seed=` frame give 0 differing pixels.** The
   prototype's did.
6. **The glance rule (controls.md §3.2).** Use §3.2's three boxes at the
   last-chance pose: `--scheme=2`, the genome with `axoneme:1,myoneme:1`,
   `--hunger=1 --starve=9`, frozen at a beat peak. The figure must stay above
   both blocks. In the prototype, the contour that fell in runs through the
   blocks:
   - bare membrane: 56.9 and 56.8;
   - with pads: 59.3 and 59.5 at 1280x720, 59.7 and 59.5 at 2400x1080;
   - the figure: 60.0 and 60.1.

   The figure wins by under one unit, so report the numbers. The controls add
   +2.4 to +2.7 over a lit line, which is less than they add today.

**Frames.** Shoot every frame at 1280x720 and 2400x1080, and look at it. One
command, seeded as `perception.md` §4.1 requires, with an absolute
`XDG_DATA_HOME`:

```
XDG_DATA_HOME=/abs/tmp/xdg xvfb-run -a -s "-screen 0 2400x1080x24" ~/godot/godot \
  --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/shot.tscn -- \
  --scene=res://tools/drive.tscn --size=2400x1080 --out=/tmp/h.png --seed=12345 \
  --scheme=0 --genome=cytostome:1,cirrus:1,flagellum:1,stigma:1 --mode=0 \
  --hunger=1.0 --starve=5 --freeze-on=beat --freeze-after=0.09 --wait=2.5
```

Change the pose for each frame:

- **The ramp**, in both views (`--mode=0` and `--mode=1`): `--hunger=0`, `0.7`
  and `0.9`, then the last chance at `--hunger=1 --starve=1`, `5` and `9`. Each
  freezes on the first beat, at 0.76 s.
- **Starving and hunted:** `--hunger=0.6 --stalk=150 --stalk-at=220 --arm-at=12
  --wait=20`. Then the same with `--hunger=0` (fed and hunted).
- **The pause:** `--hunger=1 --starve=5 --esc-at=1.5 --wait=5.34`, with no
  freeze, because a freeze cannot act on a paused tree. This timing lands on a
  beat.
- **The quiet death, mid-close from the fallen membrane:** `--hunger=1
  --starve=8 --freeze-at=3.3 --wait=4.5`.
- **The replay panes:** `--hunger=1 --starve=5 --panes=0.2 --wait=0.76`.
- **On the phone:** a never-eating run, outdoors.

## 8. Later steps

- **Step 2, haptics.** This would be the real fix for a player whose eyes are on
  the food: a heartbeat felt in the hand during the last chance.
  - **How it works:** a subscriber to `sensation`, which is the seam
    perception.md §5 kept open. On each `beat` while `faint` > 0 it calls
    `Input.vibrate_handheld(40, 0.5)`, and optionally `(20, 0.25)` from
    `hungry()` 0.6.
  - **What it needs:** `VIBRATE` (`permissions/vibrate=true` in the Android
    preset), which means a new APK and a `binary_version` bump. Ship it without
    hesitating.
  - **It also needs a pause-screen switch, on by default.** Some players turn
    vibration off everywhere, and this must not be the one place they cannot.
- **Step 3, sound.** An audible heartbeat. It needs no permission and can ship
  as content, but it would be the game's first audio (a mute switch, a mix, and
  CI's dummy driver). That is its own spec.
- **Words stay out.** If the dev app shows that a first-timer *notices* but
  still does not connect it with eating, row 4's other option comes back as an
  owner's call: one line, the first time a cell starves.

## 9. The design's frames

Today's starving cell (hunger 0, 0.5, 0.9 and the last chance, both views, both
shapes, at a beat peak), the mocks over a real run, the beat over a life that
never eats, and a daylight illustration were made in a scratch copy and are not
kept in the repo. The build shoots §7's frames again from the real game.

## 10. As built, 2026-10-03

Built to §2 and §7, as a content pack. `project.godot`, `version.json`, the input
actions, `Wire.RULES` and `PROTOCOL` are untouched, no words were added, and no
balance number moved: `levels_probe` still holds the death at 30.4 s. Where the
build differs from the text above, or found something:

- **Arrivals snap the slack to `hungry()` rather than to 0.** A pond swap keeps
  the cell's hunger, so a zero there would flash a hungry body smooth for half a
  second. Where hunger resets (a birth, a division, a return) `hungry()` is 0
  anyway. A resumed cell opens as crumpled as it was left, and a pond swap does
  nothing, because it is the same body.
- **Under a pond's open menu only the figure's body is redrawn** as the slack
  moves, every 0.05 and at either end, not the whole figure with its chips and
  tray.
- **A starving body that is also bitten** roots its wound flaps on the creased
  rim. Rooted at the uncreased radius, they hung up to 12% of r outside it.
  Bodies that are not slack draw exactly as before.
- **`levels_probe`** has §7's check 2, and one more line: from fed to the end of
  the grace the beat never once slows. Putting the old mapping back fails four
  of them.
- **Check 8's trace hash did not move.** The run does get hungry, beating 35
  times where it beat 16, but no line of the trace reads the beat.
- **The glance rule** at the last chance, 9 s, at a beat peak: the figure stays
  above both blocks under every scheme and at both shapes. Under `pads` it wins by
  under half a unit (59.96 against 59.29 and 59.50 at 1280x720; 60.09 against
  59.71 and 59.50 at 2400x1080).
  - Through the whole last chance, the contour's glance at a peak now holds
    about 58, where it used to fall to 38.9.
- **The replay** gains one float in the bus's block (`BLOCK_FLOATS` 47) and one
  in the frame (`AT_SLACK`, 472 floats). Both panes crumple and close as the run
  did.
  - In a 640-wide pane the same fall takes a larger share of the view, and the
    contour turns blobbier there. Watch it; it still reads as the same membrane.
- **The translators' note** on hunger now says the beat quickens. `biogenic.pot`
  was regenerated, and `fr.po` is untouched.
- **Not checked here:** a phone outdoors, a real two-phone pond, and how a
  1.3 Hz beat at full strength sits for ten seconds. It stays under the
  three-flashes line.
