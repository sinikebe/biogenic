# Sight: the eyespot sees

The owner, 2026-10-16:

> Move it back to the runner now, with a gameplay change to see. It will act like
> real vision. It will be impacted by light, have a field of view, start blurred
> and improve with levels, and won't allow, like beam, to see behind objects

`see` is the eyespot, `stigma`. Status: **built**.

This page replaces three-senses.md §2.7's shadow, which was a sum over every big
body within 620 µm, in every direction, through every other body, day or night,
and which never levelled. The glow on the organ (§2.7) and the membrane's lobe stay,
fed by what the eye now sees.

---

## 0. In one place

1. **A field.** The eye sees 60° either side of the slot it is worn on, so where
   it is worn decides what it sees, as it does for the beam.
2. **Light.** In full light it sees 620 µm. As the light falls -- at night, and
   toward the drop's deep middle (daylight.md) -- its reach and its picture fall
   with it, down to 30% with no light at all.
3. **Blur, sharper with levels.** A level-1 eye blurs over 36°, a level-2 eye over
   19°, a level-3 eye over 13°, and it keeps getting sharper toward 2°, each level
   taking off less than the last. A body narrower than the blur comes through
   faint. Levels come from seeing: every different body seen in a second, up to 3,
   on the beam's curve (level 2 at 40, level 3 at 120).
4. **Nothing behind a body.** A nearer body hides what is behind it, as it stops
   the beam's rays.
5. **What the player sees.**
   - **Point of view**: the water in the eye's field lit faintly in the eyespot's
     violet, out to where the eye stops seeing; dark where a body is in the way
     and behind it; as soft as the eye is blurred. The interior perception.md kept
     for vision.
   - **Full vision**: the same field, fainter and exact, so the player can see
     where the eye looks and what hides what.
   - The membrane's lobe is as wide as the eye's blur. The organ glows as before.
6. **The water's eyes are the same eyes.** A water cell sees by the same rules, at
   its copies as its level (a water cell has no levels). Its instincts read what it
   sees, and its hunt finds a body by eye only when it sees it.

---

## 1. The rule

Each frame, for an eye at the cell's centre looking along its slot's bearing:

- **The things**: every body whose near side is inside the reach, and inside the
  field once its own width is counted.
- **The view** (`game/mechanics/sight.gd`'s `view`): nearest first by near side,
  each body's angular span, minus what nearer bodies already cover. What is left is
  what is seen of it: its width, and the middle of its widest piece.
- **How clearly** a body comes through: `clarity × haze`.
  - `clarity` is the width seen over the blur, at most 1.
  - `haze` is 1 inside the core, 0 at the reach, a ramp between.
  - Light scales both the reach and the core: `seeing = lerp(0.3, 1, light)`.
- **The sense** (`shadow`, as before): every body seen, summed at how clearly, with
  the bearing of that sum. The rim counts as before (`Drop.EDGE_SHADOW`) while its
  nearest stretch is in the field.
- **A floc** hides what is behind it but is not reported, and earns nothing.
- **An eye that is not worn sees nothing.** The old shadow was the water's, computed
  whatever the cell wore. An eye is not.

Every number is the organ's (`stigma.gd`), asked through the catalogue by the
light channel: `sight_range` 620, `sight_core` 180, `sight_half_deg` 60,
`sight_dark` 0.3, `sight_blur_deg` 36, `sight_finest_deg` 2, `xp_cap` 3,
`sharp_cost` 0.18. `food.gd`'s `sight_of(key, level)` reads them for the player and
for every water cell alike.

### 1.1 The price

The eye levels, so it is priced by its level, as the beam is:
`0.18 × (how much of the sharpening it has reached)`, at the sense's half share.
Nothing at level 1, 0.045 at level 2, and never more than 0.09. Copies past the
first no longer cost anything on a cell that levels; a water cell, which does not,
pays for its copies as before.

---

## 2. Words

| Where | English | French |
|---|---|---|
| What it does | `sees what is in front of it, sharper with use` | `voit ce qui est devant lui, plus net à l'usage` |
| The instinct's line | `shadow · what your eyespot sees in front of it: where, and how clearly.` | `ombre · ce que votre œil voit devant lui : où, et avec quelle netteté.` |
| Numbers | `sees {} either side` · `out to {} µm in full light, {} µm in none` · `sharp to within {}` | `voit à {} de chaque côté` · `à {} µm en pleine lumière, {} µm dans le noir` · `net à {} près` |
| Next level | `level {} after {} bodies seen` | `niveau {} après {} corps vus` |

The sense keeps its word, `shadow`. Real vision in water sees a body as a dark shape
against the light, so the word still fits. Renaming it is a word, and words are the
owner's.

---

## 3. Drawing

- **Point of view**: `game/perception/sight.gdshader`, a rect under the returns'
  marks (`returns.gd`).
  - It is handed the field's 92 rays (`food.gd`'s `sight_fan`: how far each ran
    before a body or the rim stopped it).
  - A pixel is as bright as the share of rays within the blur either side that run
    past it, times the haze, the light and the edge fade.
  - Twelve looks a pixel, each nudged by per-pixel noise so they do not show as
    steps. Pixels outside the field or the reach leave at once.
- **Full vision** (`vision.gd`'s `_draw_sight`): two triangle strips, exact, at a
  third of point of view's brightness.
- **The replay** does not draw the field: it plays the senses back rather than
  stepping them, and the field's rays are not recorded. The lobe and the glow are.

Rendered at 1280 × 720 and 2400 × 1080:
- point of view at levels 1, 3 and 12;
- by day and by night in the drop;
- full vision;
- the pause screen in English and French.

At level 1 a body 160 µm ahead is a soft dark smudge. At level 3 it is a notch. At
level 12 it is a crisp silhouette, with the dark wedge behind it. At night the field
is a third as bright and that body is at the edge of what the eye sees.

---

## 4. What changed for the water, and the pond

- **The water's instincts** (`_read_shadow`) see by the same eye.
- **The hunt** finds a body by eye only when its eye saw it, at the search's moment
  (`_look_in_drop`). It used to find any body at least 0.8 of its own size within
  620 µm.
- **Nothing the referee judges moved.** The handshake rules carry only judged and
  contact tables, and the eye's numbers are neither, so `Wire.RULES` is unchanged:
  players on the old content and the new can play together. A guest's eye sees by
  the host's light, as its sun does.
- daylight.md §4 said nothing the water decides reads the light. Its eyes do now.

---

## 5. Pins that moved, and why

- **drop_probe**:
  - check 1's lines and the membrane digest;
  - daylight 5's lines;
  - lineage 10's identity lines;
  - the tail traces.
  The water's eyes see differently, and the membrane's shadow is now 0 for a cell
  with no eyespot.
- **ci.yml's seeded trace** (`686c55a2...`): against dev it agrees to 50.12 s, where
  the run's cell first wears an eyespot.
- **The probes' posed eyes**: drop_probe's posed player and net_probe's pond rig aim
  an eyespot as the run does, since an eye nobody aims sees nothing. Check 2 poses one
  body in front of it.

---

## 6. What to watch when playing

All balance, which waits for players (`CLAUDE.md`). The levers are the organ's
numbers.

- **Night.** At 30% the eye sees 186 µm. If night makes the eye useless, the lever is
  `sight_dark`. If the night is not felt, lower it.
- **The field.** If 120° feels like tunnel vision or like seeing everything, the
  lever is `sight_half_deg`.
- **Level 1.** If a first eye seems broken rather than blurred, the lever is
  `sight_blur_deg`. 36° makes a body your size 200 µm off come through at under half.
- **How fast it sharpens.** Level 2 at 40 bodies seen, level 3 at 120. The levers are
  `SIGHT_XP_STEP` and `xp_cap`.
- **The picture's brightness**: `SIGHT_ALPHA` in returns.gd (0.16) and vision.gd
  (0.07).
- **Water hunters with eyes** now find only what is in front of them, and less at
  night. If eyed hunters thin out over a long run, it is the field and the light.
