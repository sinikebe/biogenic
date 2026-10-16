# Sound and touch: the heartbeat

The owner, 2026-10-16:

> "Time to make sound and vibrations. First, the heartbeat. Very Light vibration
> and sound so it doesn't drive players crazy and mask other sounds"

**Status: built, as binary 8.** This is the game's first sound and its first
vibration, so it also lays down what every later sound will go through:
- a synthesizer (`game/feel/tone.gd`);
- a listener on the signal bus (`game/feel/feel.gd`);
- a mix rule (§2.2);
- two switches on the settings sheet.

The heartbeat is its one cue (`game/feel/heart.gd`).

perception.md §5 kept this door open ("audio becomes a second subscriber to the same
events, with no change to the visual layer"), and hunger.md §8 planned steps 2 and
3: a felt heartbeat and an audible one. This is both, on every beat rather than only
in the last chance, at the owner's word.

---

## 1. What a player gets

- **A soft lub-dub on every heartbeat**, the beat the membrane already shows. It is
  low and quiet, a thump more felt than heard, and it races when the beat races
  (hunger.md).
- **Two tiny ticks in the hand on every heartbeat**, on a phone, while the cell is
  in the water. Nothing while a menu is up.
- **Two switches on the settings sheet**, under the languages: `sound` and, on a
  phone only, `vibration`. Both are on until the player turns one off, and both are
  kept.

## 2. The sound

### 2.1 Made in code

The game has no audio files, and this keeps it that way. `tone.gd` makes a **thump**
from a dozen numbers:
- a sine that falls in pitch as it dies away;
- a raised-cosine attack, so it never clicks;
- a soft `tanh` drive for a few odd overtones;
- an optional quieter "knock" partial;
- two one-pole low-passes;
- a 20 ms fade at the end.

Every sound peaks at exactly 1, so how loud it plays is its volume alone. The two
heart sounds take a few milliseconds to make, once a process.

Why code rather than a recorded sample:
- a change to a number ships as content;
- the probe can read the very waves the game plays (§7);
- nothing has to be licensed or attributed.

### 2.2 The mix rule: low, quiet, brief

"So it doesn't mask other sounds" sets three things, and the heartbeat is built to
all three:

| | the heartbeat | what it leaves the next sounds |
|---|---|---|
| **band** | 98.6 % of its energy under 150 Hz, 0.015 % from 400 Hz to 1 kHz, none above (measured on the listening sample, §7) | everything above about 400 Hz, which is where the ear is most sensitive and where an eat, a ping or a hit will sit |
| **level** | the lub peaks at −20 dBFS and the dub at −24, at a beat of full strength; −37 dBFS RMS at rest | 20 dB of headroom over it. Low sound is also heard as much quieter than its level says (the equal-loudness contours), so this is quieter than −20 suggests |
| **time** | about half a second of a 2.4 s beat at rest | silence for most of every beat |

A later sound should keep to the other side of each line: above 400 Hz, louder than
the heart where it matters, and short. If one ever has to share the low band, that
is the moment for a bus of its own and a duck, not before.

**Phone speakers.** A phone's own speaker plays very little under 300 Hz, so the pure
thump would be silent on it. The knock partial puts a trace at 3.5 times the pitch,
about 180 to 330 Hz, where a speaker starts to answer. On a phone speaker the heart is
a faint knock. On earbuds it is a thump. Both are what "very light" asks for.

## 3. The heartbeat

### 3.1 Its numbers (`heart.gd`)

| | lub | dub |
|---|---|---|
| pitch | 80 → 52 Hz, falling over 35 ms | 96 → 62 Hz, over 30 ms |
| attack, decay | 6 ms, 50 ms | 5 ms, 38 ms |
| length | 0.30 s | 0.24 s |
| drive, knock | 2.4, 0.25 | 2.2, 0.25 |
| low-pass | 420 Hz | 480 Hz |
| volume at full strength | −20 dBFS | −24 dBFS |
| when | on the beat | 0.24 s later, and never later than 0.32 of the period |
| buzz at full strength | 20 ms at 0.20 | 14 ms at 0.12 |

**The dub stays inside its beat.** The beat races to 0.4 s at its fastest
(`BEAT_PERIOD_MIN`), and 0.32 × 0.4 is 0.128 s. That is the same rule a real heart
keeps, where diastole shortens as the rate climbs.

**Strength scales it.** `feel.gd` scales every part by the sensation's `strength`:
sound by amplitude, buzz by amplitude. So dread, which dims the drawn beat to 0.15,
dims the heard and felt one with it, to −36.5 dBFS and a buzz of 0.03. There is no
rule of its own for that.

### 3.2 Heard on every beat, felt only in the water

The bus beats on under the pause scrim, because the light slider is judged against
it (settings.md §2.1). Its sound does too: it is the heart the player can still
see. The hand is not buzzed while a menu is up, nor once the cell is no longer alive.
`normal_mode.gd`'s `_on_bus_sensation` hands every sensation to `Feel.hear` with
`felt = not _menu_open and _life == ALIVE`.

A new life drops whatever of the last beat was still to come (`quiet()`, from
`_settle_gauges`). There is no beat in a death and none in the replay: the replay
has no listener.

## 4. The switches

**On the settings sheet, not the pause screen.** settings.md §2.1 keeps a setting
on the pause screen when its effect shows as it is set. Sound and vibration show
nothing. They belong to the whole app, like the language, and they had no home, so
the sheet is where its own rule sends them ("grows only when something has no better
home").

```
Box
├─ … Caption "language", Languages
├─ Gap3       Control, height 6           -- the two groups apart
├─ Feel       VBoxContainer, separation 8
│  ├─ Sound      Button 472 x 56, 20 px   "sound"
│  └─ Vibration  Button 472 x 56, 20 px   "vibration", on a phone only
├─ Warn …
└─ Close …
```

- **A row** is a language row's size and box, so the sheet stays one list. Where a
  language row has its mark, at x 26, it has an icon: a speaker, or a phone shaking.
  At its right end it has a drawn switch, a 40 × 22 track 22 px in. While on, the
  track is teal with the knob right; while off, it is an outline with a dim knob
  left. The switch has no words, so only `sound` and `vibration` need translating
  (`son` and `vibration` in French), and each has 340 px of room.
- **A tap throws it**, and it is kept at once in `user://normal_mode.cfg`, `[app]`,
  beside the locale, as a language is. There is no apply button.
- **Sound off mutes the Master bus**, so every sound the game will ever make obeys
  it with no switch of its own. **Vibration off** stops every buzz.
- **Applied at boot**, by `GameBoot` (game/boot.gd), before the launcher's first
  frame. A player who turned the sound off never hears the game start.
- **The vibration row exists only where there is a hand to buzz**: Android or iOS.
  The Windows build has no row for it.
- The rows sit in the sheet's focus column, between the last language and `close`.

At 1280x720 the sheet is 520 × 488. It fits a 720 canvas at either shape.

## 5. The new APK

Vibrating needs Android's `VIBRATE` permission, which is a line in the export preset
(`permissions/vibrate=true`). That makes a new APK: **`binary_version` 8**.
`VIBRATE` is a normal permission, granted at install with no prompt.

What Godot 4.7.2 does with `Input.vibrate_handheld(ms, amplitude)`, read in its
source (`java_godot_wrapper.cpp`, `GodotNativeBridge.kt`):
- the amplitude is scaled to 1–255;
- from Android 8 it plays `VibrationEffect.createOneShot(ms, amplitude)`;
- before Android 8 it plays the length at full strength;
- without the permission it does nothing and logs a warning.

**On a phone with no amplitude control, Android plays any amplitude at full
strength.** That is why the buzzes are kept to 20 and 14 ms: short enough to be a
tick, not a buzz, on either kind of phone.

The sound needs nothing: it would have shipped as content. It rides in the same
binary because the two are one change.

## 6. What to watch

All of these are starting values. The owner will play them, as always.

- **Is it light enough, and still there?** The levers are `LUB_DB` and `DUB_DB`,
  and the knock, which is how much a phone speaker carries. If players never notice
  it on a speaker, the knock is the lever, not the volume.
- **Does the vibration annoy over a long session?** It ticks every 2.4 s at rest and
  faster when hungry. The levers are `LUB_BUZZ` and `DUB_BUZZ`, the lengths, or
  dropping the dub's buzz (a single tick a beat). The switch is the player's own
  answer.
- **Does the racing heart become too much** in the last chance, when it is felt and
  heard at its fastest? It is meant to be urgent. Watch whether it reads as urgent
  or as noise.
- **On a phone with no amplitude control**, is 20 ms a tick? If it is a buzz, make
  the lengths shorter.

## 7. Checks

- **`tools/feel_probe.tscn`**, in CI as "Check the heartbeat's sound and touch",
  with `--fixed-fps 60`:
  1. The two sounds:
     - at least 90 % under 150 Hz;
     - at most 1 % above 400 Hz and 0.05 % above 1 kHz;
     - played at −18 dBFS or quieter;
     - no step larger than 0.05 between samples;
     - rising from silence and ending in it.
  2. The cue:
     - the lub at once, and the dub 0.24 s later at rest;
     - at a 0.4 s beat, the dub at 0.128 s;
     - a beat at 0.15 plays 16.5 dB quieter and buzzes at 0.03;
     - each buzz at most 25 ms and 0.25;
     - not felt, vibration off, or no hand stops the buzz; sound off stops the
       sound; an unknown sensation plays nothing;
     - `quiet()` drops what was still to come.
  3. The switches are on with nothing kept, are kept, and sound off mutes the mix.
  4. The sheet shows the vibration row with a hand and not without, and a tap
     throws each switch.
  5. A real run:
     - in the water, three beats made six sounds and six buzzes;
     - on the pause screen, two beats made four sounds and no buzz.
- **`--wav=<path>`** writes a listening sample: five beats at rest, then eight
  racing at 0.6 s, at the game's volumes. It was sent to the owner with this build.
- **Check 8** prints `0c666c11…`, unchanged: the heartbeat changes nothing in the
  simulation.
- **Rendered and judged** with `tools/corner_shot.tscn --open=settings
  --handheld=1`:
  - at 1280x720 and 2400x1080;
  - with sound off and with vibration off;
  - in French.

## 8. Kept generic

- **`tone.gd`** knows a spec, never what the sound is for.
- **`feel.gd`** knows kinds of sensation and the parts of a cue: a sound, a volume,
  a buzz, a delay and a share of the period. It knows nothing of hearts or menus.
- **`heart.gd`** is the edge that names a heartbeat, and **`normal_mode.gd`** says
  when a buzz may be felt.
- **A new sound** is a cue on another sensation kind the bus already posts (`taste`,
  `hit`, `ping`, `shove`…): one `cue()` call and its numbers.
