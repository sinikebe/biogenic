# Biogenic — First Playable

UX/UI spec. Build target: one engineer, no Godot binary, no artist, content-pack only.

Everything here is drawn with `_draw()` primitives and one hand-written canvas_item
shader. There is not a single texture, font file or audio asset in this design.

---

## 1. Concept directions

**A. Confluence** — A petri dish. Cells grow on their own and must be split at the
right moment: too early does nothing, too late and the cell ruptures and scars the
dish. Every clean split makes two cells, so playing well is what makes the game
hard. Three lesions and the culture is contaminated. One verb, one finger.

**B. Chemotaxis** — You steer a slow organism down a nutrient gradient in the dark,
feeding on motes and avoiding a rival bloom. Tilt on phone, WASD on desktop.
*Rejected:* it is a collect-em-up wearing a biology costume, the tilt channel is the
least reliable input we have, and "gradient you can feel but not see" is exactly the
kind of thing you cannot tune without an engine to play it in.

**C. Membrane** — A cell wall under siege; you drag to seal breaches before
pathogens push through. *Rejected:* drag-to-seal needs stroke/segment intersection
maths, and the difficulty curve has to be authored by hand — two things that go
wrong silently when nobody can run the game.

### Picked: **A — Confluence**

Four reasons, in order of weight:

1. **It is arithmetic, not simulation.** A cell is a position, a radius and a
   maturity float. Division is "remove one, add two." Rupture is "remove one,
   increment a counter." There is no physics body, no polygon cutting, no pathing,
   no emergent behaviour to tune. An engineer can verify this design is correct by
   reading it, which is the only verification available to us.
2. **The difficulty curve authors itself.** Success creates the pressure: each clean
   split doubles the thing you have to watch. We never have to hand-tune a ramp, and
   failure gently relieves pressure, so a struggling player is pushed back toward
   playable instead of into a spiral.
3. **The art requirement is circles.** Cells, rings, a dish rim, scars. Every visual
   in the game is a primitive we can draw with total confidence and zero assets. The
   aesthetic brief — organic, cellular, wet, slow — is not something we are
   simulating here, it is literally the subject.
4. **One verb on both targets.** Tap a cell / press Space. No drag, no gesture, no
   aiming. Touch and keyboard are equally good, not one grudgingly ported to the
   other.

---

## 2. The game

### Core loop

The dish holds a colony. Every cell grows continuously and a ring around it fills
like a clock hand as it matures. Two tick marks on that ring mark the **ripe band**.
Tap a cell inside its band and it divides cleanly into two small daughters and banks
a division; tap it before the band and nothing happens but a ripple — misfires are
free, this is a game about timing, not aim. Miss the band entirely and the cell
elongates, goes amber, and ruptures on its own, leaving a permanent scar on the dish
and costing you a lesion. Because a clean split leaves you with *two* cells to watch
instead of one, the dish fills up as you succeed, until you are spinning ten plates
at once.

### Win / lose

| | Condition | Screen title |
|---|---|---|
| **Win** | 24 divisions banked | `CONFLUENT` |
| **Lose** | 3 lesions | `CONTAMINATED` |
| **Lose** | population reaches 0 | `CONTAMINATED` |

That last row is a real edge case — rupturing your last cell ends the run even at
one lesion. Handle it explicitly or the game soft-locks on an empty dish.

A run should land at **90–150 seconds**. The two dials are `GROW_SECONDS` and
`TARGET_DIVISIONS`; everything else is feel.

### Controls

**Both targets share one verb.** Neither is a port of the other.

| Action | Touch (Android) | Mouse + keyboard (Windows) |
|---|---|---|
| Divide a cell | Tap it | Left-click it, **or** `ui_accept` (Space/Enter) to divide the ripest tappable cell |
| Pause | `PAUSE` button, or the hardware **Back** button | `PAUSE` button, or `ui_cancel` (Esc) |
| Resume / restart / leave | Overlay buttons | Overlay buttons, or click |

Notes the engineer must not skip:

- **Use only `ui_accept` and `ui_cancel`.** The project has no input map, and the
  input map is baked into the binary — a new action shipped in a `.pck` does nothing.
  These two are built in, so the whole control scheme stays content-side.
- **Space auto-targets.** It divides the cell with the highest maturity among those
  currently tappable. The game is about *when*, not *which*, so auto-aim costs the
  player nothing and makes desktop genuinely one-button. There is no Tab-cycling and
  no focus ring on cells — deliberately cut, see §6.
- **Handle `InputEventMouseButton` only, in `Main._unhandled_input()`.** Godot's
  `emulate_mouse_from_touch` is on by default, so a finger arrives as a mouse press.
  One code path covers both targets. Do *not* also handle `InputEventScreenTouch` in
  the first playable — with emulation on you will get both and every tap fires twice.
- **Do not use `_gui_input` on the dish.** Put gameplay input in `_unhandled_input`
  on the root and give every non-Button Control `mouse_filter = 2` (IGNORE). GUI
  input is processed first, so the `PAUSE` button still swallows its own taps, and
  you avoid the whole `mouse_filter` ordering puzzle.
- **Android Back must open the pause overlay, not quit.** Handle
  `NOTIFICATION_WM_GO_BACK_REQUEST` in `_notification()`. Left alone this quits the
  entire app mid-run — see the launcher issue in §7.

### Getting back to the launcher

The launcher replaces itself (`get_tree().change_scene_to_file(play_scene)`), so
there is no return path unless we build one. **Leave** does:

```gdscript
get_tree().change_scene_to_file("res://addons/launcher/launcher.tscn")
```

That path is hardcoded into a directory we are forbidden to edit. Accepted for now;
flagged in §7.

---

## 3. Visual language

Everything below is lifted from `launcher_theme.tres` and `launcher_config.tres` so
that pressing Play does not feel like changing products.

### Inherited (do not invent new values for these)

| Token | Value | From |
|---|---|---|
| `VOID` | `Color(0.023, 0.055, 0.05, 1)` | boot splash, clear colour, launcher bg |
| `DISH_RIM` | `Color(0.141, 0.302, 0.267, 1)` | launcher panel border |
| `VITAL` | `Color(0.239, 0.863, 0.592, 1)` | launcher progress fill |
| `VITAL_BRIGHT` | `Color(0.490, 1.0, 0.831, 1)` | launcher pressed border |
| `TEXT` | `Color(0.855, 0.953, 0.933, 1)` | launcher label colour |
| `TEXT_TITLE` | `Color(0.827, 1.0, 0.937, 1)` | launcher title |
| `TEXT_BODY` | `Color(0.663, 0.812, 0.78, 1)` | launcher overlay body |
| `TEXT_MUTED` | `Color(0.404, 0.639, 0.588, 1)` | launcher tagline |
| `TEXT_FAINT` | `Color(0.318, 0.463, 0.435, 1)` | launcher version stamp |
| `OVERLAY_DIM` | `Color(0.004, 0.016, 0.014, 0.784)` | launcher update overlay |

### New, game-only

| Token | Value | Used for |
|---|---|---|
| `DISH_FILL` | `Color(0.031, 0.075, 0.068, 1)` | inside of the dish, one step above `VOID` |
| `MEMBRANE_GROW` | `Color(0.078, 0.204, 0.180, 0.92)` | cell fill, growing |
| `MEMBRANE_RIPE` | `Color(0.118, 0.353, 0.294, 0.95)` | cell fill, ripe |
| `MEMBRANE_OVER` | `Color(0.267, 0.220, 0.110, 0.95)` | cell fill, overripe |
| `RIM_GROW` | `Color(0.141, 0.361, 0.310, 1)` | membrane outline, growing |
| `RIM_RIPE` | `Color(0.490, 1.0, 0.831, 1)` | membrane outline, ripe |
| `RIM_OVER` | `Color(0.945, 0.643, 0.259, 1)` | membrane outline, overripe |
| `NUCLEUS_GROW` | `Color(0.161, 0.478, 0.400, 0.85)` | nucleus, growing |
| `NUCLEUS_RIPE` | `Color(0.588, 1.0, 0.859, 0.90)` | nucleus, ripe |
| `NUCLEUS_OVER` | `Color(0.976, 0.780, 0.447, 0.90)` | nucleus, overripe |
| `RING_TRACK` | `Color(0.141, 0.302, 0.267, 0.55)` | unfilled part of the tension ring |
| `SCAR` | `Color(0.204, 0.145, 0.075, 1)` | lesion scar core |
| `SCAR_HALO` | `Color(0.145, 0.110, 0.063, 0.60)` | lesion scar bleed |

Amber is the only hue the launcher does not already contain. It earns its place: we
need a danger signal, and a biological warm rot reads as *spoiling* rather than as a
UI error state. It is never the only cue — see §5.

### Background

Copy `addons/launcher/shaders/organic_background.gdshader` byte-for-byte to
`res://game/shaders/dish_background.gdshader`. **Copy, do not reference.** The sync
job replaces `addons/launcher/` wholesale without our review; a `ShaderMaterial`
pointing at a uniform that a future template rename deletes is a silent visual break
in a shipped build. Sixty duplicated lines is the cheap side of that trade.

Set on the `ShaderMaterial` (leave the shader source itself untouched):

```
shader_parameter/deep_color   = Color(0.023, 0.055, 0.05, 1)
shader_parameter/glow_color   = Color(0.06, 0.42, 0.34, 1)
shader_parameter/rim_color    = Color(0.12, 0.70, 0.58, 1)
shader_parameter/drift_speed  = 0.018
shader_parameter/intensity    = 0.55
```

Slower and dimmer than the launcher's `0.035` / `1.0`. The menu's background is the
main event; in-game it is wallpaper, and the cells must own the motion. The shader
already ships and runs under GL Compatibility, so compilation is proven.

---

## 4. Layout

### Viewport arithmetic

`canvas_items` stretch + `expand` aspect at 1280x720 means **one axis is always
exactly at base and the other only grows.** You never get less than 1280x720, so a
centred 1280x720 safe rect is always fully visible.

| Device | Window | Viewport | Notes |
|---|---|---|---|
| Desktop 16:9 | 1280x720 | **1280x720** | reference |
| Phone landscape 20:9 | 2400x1080 | **1600x720** | 160px gutter each side |
| Desktop 16:10 | 1920x1200 | **1280x800** | 40px gutter top/bottom |
| Desktop 4:3 | 1024x768 | **1280x960** | 120px gutter top/bottom |
| Portrait (see §7) | 1080x2400 | **1280x2844** | degrades, does not break |

**Android is landscape-locked.** `window/handheld/orientation=4` is
`SCREEN_SENSOR_LANDSCAPE`, not full sensor — the phone flips between the two
landscape orientations and never goes portrait. So the phone case is *wider* than
base, not taller. The portrait row above is insurance, not a target.

### Dish geometry — computed, never hardcoded

```
HUD_TOP    = 96
HUD_BOTTOM = 84
band       = viewport.y - HUD_TOP - HUD_BOTTOM
DISH_R     = min(viewport.x * 0.5 - 40, band * 0.5)
DISH_C     = Vector2(viewport.x * 0.5, HUD_TOP + band * 0.5)
```

Recompute on `get_viewport().size_changed`. Results: **R=270** at 1280x720 and at
1600x720; **R=310** at 1280x800; **R=390** at 1280x960.

The dish is sized by the *short* axis, so on a phone it stays a 540px circle in the
middle of a 1600px-wide screen. That is the point: **the bottom corners, where
thumbs rest in landscape, are never part of the play area.** No occlusion rule
needed — the geometry gives it to us.

### Node tree

```
Main (Control)                          res://game/main.tscn  ·  main.gd
│  anchors_preset 15 · grow both · mouse_filter 2
│  theme = res://addons/launcher/theme/launcher_theme.tres
│
├── Backdrop (ColorRect)                anchors_preset 15 · mouse_filter 2
│     color = Color(0.023, 0.055, 0.05, 1)
│     material = ShaderMaterial → game/shaders/dish_background.gdshader
│
├── Dish (Control)                      anchors_preset 15 · mouse_filter 2
│     dish.gd — draws EVERYTHING in one _draw()
│
├── Hud (Control)                       anchors_preset 15 · mouse_filter 2
│   ├── TopBar (HBoxContainer)          anchors 0,0,1,0 · offsets 28, 20, -28, 84
│   │   │                               separation 24 · mouse_filter 2
│   │   ├── Score (VBoxContainer)       separation 0 · size_flags_h 0
│   │   │   ├── ScoreCaption (Label)    "DIVISIONS" · 14px · TEXT_FAINT
│   │   │   └── ScoreValue (Label)      "7 / 24"    · 30px · TEXT_TITLE
│   │   ├── Spacer (Control)            size_flags_h 3 · mouse_filter 2
│   │   ├── Lesions (VBoxContainer)     separation 4 · size_flags_v 4
│   │   │   ├── LesionCaption (Label)   "LESIONS" · 14px · TEXT_FAINT · h_align 2
│   │   │   └── PipRow (HBoxContainer)  separation 10 · alignment 2
│   │   │       └── Pip1..Pip3 (Panel)  custom_minimum_size (18, 18)
│   │   └── PauseButton (Button)        custom_minimum_size (0, 64) · text "PAUSE"
│   │                                   size_flags_v 4 · mouse_filter 0
│   └── Coach (Label)                   anchors 0,1,1,1 · offsets 28, -76, -28, -28
│                                       18px · TEXT_MUTED · align 1/1 · autowrap 3
│                                       mouse_filter 2
│
└── Overlay (Control)                   anchors_preset 15 · starts hidden
    ├── Dim (ColorRect)                 anchors_preset 15 · mouse_filter 2
    │                                   color = Color(0.004, 0.016, 0.014, 0.784)
    └── Center (CenterContainer)        anchors_preset 15 · mouse_filter 2
        └── Dialog (PanelContainer)     custom_minimum_size (440, 0)
            └── Box (VBoxContainer)     separation 14
                ├── OverlayTitle (Label) 26px · TEXT_TITLE
                ├── OverlayBody (Label)  17px · TEXT_BODY · autowrap 3
                └── Actions (HBoxContainer) separation 10
                    ├── SecondaryBtn (Button) size_flags_h 3 · min_size (0, 56)
                    └── PrimaryBtn (Button)   size_flags_h 3 · min_size (0, 56)
```

`Hud` and `Overlay` come **after** `Dish` in the tree so their Buttons take input
first. `Overlay` reuses the launcher's `UpdateOverlay` structure exactly, so the
game's dialogs and the updater's dialogs are the same object. One deliberate
departure: the buttons are `size_flags_h 3` (expand-fill) and 56px tall rather than
the launcher's shrink-to-fit, because these get pressed with a thumb mid-run.

**No text below 14px. No information conveyed on hover only** — touch has no hover.

---

## 5. The cells

### Data, not nodes

Cells are entries in an array on `dish.gd`, drawn in that one `_draw()`. No
`Cell.tscn`, no instancing, no node lifecycle. Ten cells is ten array entries.

```gdscript
pos: Vector2      # relative to DISH_C
vel: Vector2      # 4..10 px/s, random direction at birth
t: float          # maturity, 0 → 1
phase: float      # wobble seed, randf() * TAU
wobble_rate: float # 0.6 .. 1.0
flash: float      # 0..1, decays at 2.5/s; set to 1.0 on any tap
```

### Tuning

| Constant | Value | |
|---|---|---|
| `GROW_SECONDS` | 11.0 | birth → rupture; `t += delta / GROW_SECONDS` |
| `RIPE_START` | 0.62 | t at which the band opens (≈6.8s) |
| `RIPE_END` | 0.86 | t at which it closes (≈9.5s) — a **2.6s** window |
| `R_BIRTH` / `R_BURST` | 20 / 54 | `radius = 20 + 34 * pow(t, 0.72)` |
| `HIT_R` | `max(radius, 34)` | **68px minimum** tap diameter, vs the 48px floor |
| `POP_CAP` | 10 | at cap a division yields one daughter, not two |
| `TARGET_DIVISIONS` | 24 | win |
| `MAX_LESIONS` | 3 | lose |
| start | 1 cell at `t = 0.35` | first ripe event ~3s in, not 7s |

### States

| State | Range | Membrane | Rim | Nucleus | Ring |
|---|---|---|---|---|---|
| **GROWING** | `t < 0.62` | `MEMBRANE_GROW` | `RIM_GROW` | `NUCLEUS_GROW` | fills, `VITAL` @ 0.45 alpha |
| **RIPE** | `0.62 ≤ t < 0.86` | `MEMBRANE_RIPE` | `RIM_RIPE` | `NUCLEUS_RIPE` | `VITAL_BRIGHT`, pulse 1.2 Hz |
| **OVERRIPE** | `0.86 ≤ t < 1.0` | `MEMBRANE_OVER` | `RIM_OVER` | `NUCLEUS_OVER` | `RIM_OVER`, pulse 2.2 Hz |
| **HOVER** (desktop only) | any | — | +12% brightness | — | — |
| **FLASH** (transient) | `flash > 0` | — | — | — | expanding ripple, see below |

Outcomes of a tap:

| Tapped state | Result |
|---|---|
| GROWING | Ripple only. **No penalty.** Mis-taps must be free. |
| RIPE | +1 division. Parent removed, two daughters at `t = 0.0`, offset `±radius*0.55` on a random axis with a small outward `vel`. At `POP_CAP`, one daughter. |
| OVERRIPE | +1 division, but **one** daughter at `t = 0.18`. Late costs you the population gain and hands back a cell that is already part-grown. |
| — | `t` reaching 1.0: cell removed, +1 lesion, permanent scar at `pos`. |

### Draw order, per frame

1. `draw_circle(DISH_C, DISH_R, DISH_FILL)` then
   `draw_arc(DISH_C, DISH_R, 0, TAU, 96, DISH_RIM, 2.0, true)`
2. Scars — `draw_circle(p, 18, SCAR_HALO)` then `draw_circle(p, 11, SCAR)`
3. Cells, **sorted by `t` ascending** so the urgent ones land on top:
   1. membrane fill — `draw_colored_polygon(pts, membrane_colour)`
   2. nucleus — `draw_circle(pos, radius * 0.30, nucleus_colour)`
   3. membrane rim — `draw_polyline(pts_closed, rim_colour, 2.0, true)`
   4. ring track — `draw_arc(pos, radius + 9, -PI/2, 3*PI/2, 48, RING_TRACK, 3.0, true)`
   5. ring fill — `draw_arc(pos, radius + 9, -PI/2, -PI/2 + TAU * t, 48, ring_colour, 3.0, true)`
   6. **band ticks** — `draw_line` from `radius + 5` to `radius + 15` at
      `-PI/2 + TAU * RIPE_START` and `-PI/2 + TAU * RIPE_END`, in `VITAL_BRIGHT`, 2px
   7. flash — `draw_arc(pos, radius + 9 + (1.0 - flash) * 22.0, 0, TAU, 48,
      Color(VITAL_BRIGHT, flash * 0.5), 2.0, true)`

Membrane points, 24 of them:

```gdscript
var a := TAU * i / 24.0
var w := 1.0 + 0.05 * sin(a * 3.0 + phase + clock * wobble_rate) \
             + 0.03 * sin(a * 5.0 - phase * 1.7 + clock * wobble_rate * 0.7)
if state == OVERRIPE:
    w += 0.06 * sin(a * 2.0 + phase)   # elongates — a cell about to divide
pts[i] = pos + Vector2(cos(a), sin(a)) * radius * w
```

Keep total deviation at or under 8% in the non-overripe case so the polygon stays
convex — `draw_colored_polygon` is not reliable on concave input.

Do **not** rely on `draw_circle`'s optional `filled` / `width` arguments. Use
`draw_arc` for every ring and `draw_circle` only for filled discs.

### Those band ticks are the entire tutorial

The two ticks make the rule visible in the first three seconds without a word: the
hand sweeps, there is a marked zone, you act inside it. Everything else is the
`Coach` label, which shows exactly two strings, once each, fading over 0.4s:

- run start, 5s: *"Split a cell when its ring reaches the bright band."*
- first time any cell goes OVERRIPE: *"That one is about to burst."*

No tutorial screen, no modal, no first-run flow.

### Motion

- Drift: `pos += vel * delta`, plus a tiny random walk on `vel`.
- Containment: if `pos.length() > DISH_R - radius`, clamp back and reflect `vel`.
- Separation: pairwise, if `dist < r1 + r2` push each out by half the overlap,
  capped at 60 px/s. Ten cells is 45 pairs — free.
- When an overlay is open, keep `clock` advancing (so membranes still breathe) but
  freeze `t`. The dish should look alive while paused. It costs one `if`.

### Accessibility

No state is signalled by hue alone. Each one also changes **ring fill fraction**
(geometry), **pulse rate**, and in the danger case **membrane silhouette**
(round → elongated). Green/amber is the classic deuteranopia trap, and this is what
keeps it out of it. Slowest pulse 1.2 Hz, fastest 2.2 Hz — well under the 3 Hz
photosensitivity threshold.

---

## 6. HUD and overlay states

| Element | States |
|---|---|
| `ScoreValue` | `"N / 24"`. On increment: scale 1.0 → 1.12 → 1.0 over 0.18s. |
| `Pip1..3` | **empty** — `StyleBoxFlat`, `draw_center = false`, 2px border `DISH_RIM`, `corner_radius 9`. **filled** — `bg_color = RIM_OVER`, no border, same radius. Display only, never a touch target. |
| `PauseButton` | normal / hover / pressed / focus / disabled (while the overlay is up). All five come from the launcher theme for free. |
| `Coach` | hidden → fade in 0.4s → shown → fade out 0.4s → hidden. `modulate.a` only. |
| `Overlay` | hidden / paused / won / lost. |

| Overlay | Title | Body | Secondary | Primary |
|---|---|---|---|---|
| paused | `PAUSED` | "The culture is held." | `Leave` | `Resume` |
| won | `CONFLUENT` | "24 clean divisions. The culture holds the dish." | `Leave` | `Again` |
| lost | `CONTAMINATED` | "Three lesions. The dish is lost at N divisions." | `Leave` | `Again` |

`Again` calls `_start_run()`, which resets state in place. Not
`reload_current_scene()` — in-place reset is one function an engineer can read and
confirm, and it has no re-entrancy surprises with the overlay.

`PrimaryBtn` should `grab_focus()` whenever the overlay opens, so Enter works
immediately on desktop.

---

## 7. Scope — what is deliberately not in this

An unbuildable spec is worse than a small one. All of these are cut with a reason,
not forgotten.

| Cut | Why |
|---|---|
| **Multi-touch** | Mouse emulation gives us one reliable pointer on both targets from one code path. At a 10-cell cap with ~1.1s between ripe events, one finger is enough. To add later: handle `InputEventScreenTouch`, set `Input.emulate_mouse_from_touch = false` in `_ready()` and restore it in `_exit_tree()`. |
| **Drag-to-pinch division** | Better feel, but it needs a gesture state machine and a drag/tap disambiguation threshold that nobody here can tune by feel. Tap first, earn the right to complicate it. |
| **Tab-cycling / a focus ring on cells** | Space auto-targeting the ripest cell is strictly better for a timing game and is a third of the code. |
| **Saved best score** | Adds a `user://` IO path that can fail on a headless CI boot and inside the Android sandbox, for zero gameplay consequence against a fixed win target. |
| **Audio** | No sound designer either. Procedural `AudioStreamGenerator` under GL Compatibility on low-end Android is a real risk and not one worth taking on a first playable. |
| **Levels, difficulty select, strains** | Population *is* the difficulty curve. Authoring a second one would fight it. |
| **Settings screen** | Nothing to set yet. When there is, it goes on the launcher's `extra_buttons` → `custom_button_pressed`, which already exists. |
| **Portrait layout** | Android is locked to sensor **landscape**. §4's formulas degrade gracefully if that ever changes, but no portrait-specific layout is being built for a mode the app cannot enter. |
| **Particles, trails, screen shake** | `_draw()` only. The flash ripple is the entire juice budget. Revisit once it plays well. |

### Definition of done

- Runs at 1280x720, 1600x720 and 1280x960 with nothing clipped or overlapping.
- Every tap target ≥ 68px; every glyph ≥ 14px.
- Playable start-to-win with only a mouse; start-to-win with only the Space bar;
  start-to-win with one finger.
- Android Back opens the pause overlay and does not quit.
- Headless boot does not crash: no window assumptions, no network, no file IO.
- `play_scene = "res://game/main.tscn"` in `launcher_config.tres`.

---

## 8. Launcher issues found (for the template, not this repo)

1. **No supported return path from a game to the launcher.** `_on_play_pressed()`
   calls `change_scene_to_file()`, which destroys the launcher, and nothing exposes
   the way back. Every game must hardcode `res://addons/launcher/launcher.tscn` — a
   path inside the one directory games are forbidden to edit and which the sync job
   can move without review. A `BuildInfo.LAUNCHER_SCENE` constant, or a documented
   stability promise on the path, would fix it.

2. **Android Back quits the app from inside the game.** `quit_on_go_back` is unset
   (defaults true) and nothing handles `NOTIFICATION_WM_GO_BACK_REQUEST`. Fine while
   Play does nothing; the moment `play_scene` is set, one stray Back tap mid-run
   kills the process instead of pausing. It is a project setting, so it is
   **binary-side** and cannot be repaired in a content pack after ship.

3. **`window/handheld/orientation=4` is `SCREEN_SENSOR_LANDSCAPE`, not full sensor.**
   The template's docs and both agent briefs describe it as "sensor" and ask for
   portrait support. Full sensor is `6`. Also binary-side, so shipping the wrong one
   is expensive to undo — and in the meantime it costs design work aimed at a
   screen shape the app never reaches.
