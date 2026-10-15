# One control per gene

The owner, in the gene pass (2026-10-15), on the moving genes:

> No more controls without buttons. Add a proper control element for each gene
> (small button if binary entry, a slider if analogic entry, etc.) the control
> type must reflect the gene's behavior

Status: **built**. This page is the rule, the layout, and what to watch when
playing. It replaces the three schemes of `controls.md` (`anywhere`, `stick`,
`pads`) and their chooser; that page's geometry, its look, its multi-pointer rule,
the lean at a division and the pinch handover all still hold, and are not repeated
here.

---

## 0. In one place

1. **Open water is never a control.** No drag on the water, no finger anywhere
   for thrust, no tap on the water for a dash. Everything the hand does, it does
   on a drawn control or a key.
2. **Each thing the hand can do has a control of its own, and the control's kind
   is the gene's behaviour**: a slider for something with a strength, a pad for
   something on or off.
3. **One layout.** The chooser on the pause screen is gone, and so is the
   `run/scheme` setting a player may have saved.
4. **A control arrives with its gene and goes with it** (`controls.md` §1.1, kept):
   a newborn has the turn alone.
5. **Content only.** No new binary, no rule the referee judges, no message: `Wire`
   does not move.

---

## 1. The controls today

| Gene | What the hand does | Its behaviour | Its control | Where | Key |
|---|---|---|---|---|---|
| the body, faster with `cirrus` | turn | a strength, left or right, nothing once let go | **a slider**: a knob in a channel, home when let go | bottom left | `A` `D`, `←` `→` |
| `axoneme` | push | a strength, while held | **a lever**: a knob pushed up a channel, down again when let go | bottom row, inboard of the pads | `W`, `↑` (full) |
| `myoneme` | dash | one burst, then a wait | **a tap pad**, which dims and refills while it waits | the corner | Space |
| `flagellum`, from 2 copies | hold the tail still | on while held | **a held pad** | up the right edge | `S`, `↓` |
| `haptonema` | cling | on while held | **a held pad** | up the right edge | `Q` |

Every control carries its organ's own tile, as the pause screen draws it beside the
gene's name: the cirrus rides the turn's knob, the axoneme the lever's, and each pad
shows its organ. The hold keeps its own mark, the tail's wave running into a stop
bar (`automation-ux.md` §6.2), because the tail's tile would say *swim*.

**The push is a real strength now.** It was full or nothing in the hand and a half
or full in an instinct. The lever gives any strength between, and the push costs in
proportion, as an instinct's half always did.

**The dash's pad shows its wait.** While the dash recharges, its mark dims to a third
and a line along the foot of its well fills back up over the 1.4 s.

---

## 2. How a gene says what its control is

An output a gene declares (`gene.gd`'s `declares`) carries a `"button"`, naming the
kind of control the hand gets for it:

| `"button"` | Drawn as | Acts |
|---|---|---|
| `&"held"` | a pad | while it is held, as while an instinct claims it |
| `&"tap"` | a pad | once, on the press |
| `&"lever"` | a slider pushed up from rest | at that strength while it is held, and drops back when let go |

`true` still means `&"held"`, the one kind there was (`haptonema.md` §4). A part with
no `"button"` is the instincts' alone. `Catalogue.buttons()` lists every part with
one as `[part, name, organ, level, kind]`, and a body has a control for each it
wears at the part's level (`Catalogue.worn_buttons`).

So **a new gene that declares a part with a `"button"` gets its control with no
change to the controls**. The one thing the cell has to be told is what a `tap`
does, by the part's name (`cell.gd`'s `_tap`); a `held` part is asked
`hand_holds(name)`, and a `lever` part `controls.lever(name)`.

The turn is the body's own, not a gene's part, so it is the one control
`controls.gd` names: it is always drawn, because a body with no cirrus still turns,
slowly.

---

## 3. Layout

Canvas pixels, at 720 tall. `W` is the canvas width: 1280 at 16:9, 1600 at 20:9.
The margins, the 96 px pad and the 24 px gap are `controls.md` §2's.

```
turn slider   x 48 .. 240        y 576 .. 672    knob ±48, home at x 144
pads          x W-144 .. W-48    row k: y 576 - 120k .. 672 - 120k
levers        x W-264 .. W-168   y 480 .. 672    knob rests at y 624, travels 96 up
```

- **The pads stack up the right edge from the corner**, taps first: the dash keeps
  the corner, where the right thumb rests. Then the held pads, in the catalogue's
  order: the hold, then the cling. With all three, the column reaches y 336.
- **The levers stand in the bottom row inboard of the pads**, each one column
  further in. The push's knob rests on the bottom row's centre line, beside the
  dash, so a thumb on it slides up rather than reaching.
- **A gene that arrives ahead of another in the list moves it up a row.** The pads
  stay a column with no holes, and a held finger stays on its own part, by name, when
  that happens. `controls.md` §1.1's "positions never move" held for three fixed
  pads; it does not hold for a list that grows.

Rendered at 1280x720 and 2400x1080 (§6): the two blocks slide outward with the
corners and nothing reflows vertically.

---

## 4. What went

- **The three schemes and their chooser.** `anywhere` was the default: a drag on
  the water steered, any finger down pushed, and a short still press dashed. `pads`
  turned with two on-or-off pads, which the rule now rules out: turning has a
  strength. `stick` was nearest to this, and its slider is the turn, but touching it
  also pushed. The `Feel` panel on the pause screen, `RunState`'s scheme and
  `tools/drive.gd`'s `--scheme=` went with them.
- **The steering line on phones.** "drag to turn" taught a gesture that no longer
  exists. On a phone the drawn turn is the onboarding, as it was under `stick`; a
  keyboard still gets "A · D to turn".
- **Waiting to place a gene.** Holding your body to place a gene opened after
  0.35 s under `anywhere`, so that a tap on the body could still dash. Open water is
  inert now, so a press on your body opens it at once, as it did under `stick` and
  `pads`.
- **The controls behind the pause screen.** They were drawn under the scrim so
  cycling the chooser showed what it chose. With nothing to choose, they hide while
  the pause screen is open.

## 5. What stayed

- **The lean at a division** (`controls.md` §6): the turn, while held, decides it;
  a finger anywhere else falls back to the screen half; keys first. The genes'
  controls go at the pinch and the turn stays.
- **One pointer per control**, so the turn, the lever and a pad can all be held at
  once: four fingers at once were driven and traced (§6).
- **A press on any drawn control takes the cell back from the autopilot**, and a
  press on open water takes nothing back.

---

## 6. Checks

- **`ci.yml`, "Check the input path"**: one run, the turn held and slid, the lever
  pushed, the dash tapped, then the turn held hard over through a division, which
  must commit a daughter. Committed: r40 to r28.28.
- **`ci.yml`, "Check an empty library changes nothing"**: one run, where it was one
  per scheme. The hash is unchanged, c5d5a002…, 70,197 lines: with no hand on it
  the layout moves nothing.
- **The drop probe**: tail 2 and 3 draw the hold pad in a run of the game, the only
  pad and so in the corner, clear of the turn, holding the tail while held; the
  autopilot's check 11 takes the cell back from the turn, the lever, the dash and
  the hold, and not from open water.
- **Traced** with `tools/drive.gd --controls=0.5`: the turn at +1.00, the lever at
  0.98 and then slid down to 0.20, the dash tapped, and the hold held, four fingers
  at once; each let go back to nothing.

Rendered and judged at 1280x720 in point of view and 2400x1080 in full vision, with
all five controls, the turn and the lever held, and the dash recharging.

---

## 7. What to watch when playing

- **The lever comes back down when you let go.** That is the push's behaviour,
  thrust while held, and it keeps an unattended push from draining the tank. If
  holding it feels like work on a long swim, the other answer is a lever that stays
  where it is left, a throttle.
- **The dash and the cling are both coils** (`haptonema.md` §7): told apart by the
  cling's denser turns. If they misread side by side, the lever is the haptonema's
  `look`.
- **How high the right thumb reaches.** With the hold and the cling, the column is
  three pads tall. A fourth part would go to y 216.
- **The turn's throw is 48 px each way**, `stick`'s, much shorter than the old
  190 px drag. If steering feels twitchy, `THROW` is the number.
