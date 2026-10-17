# The senses' tiles

The owner, 2026-10-15, after the energy gauge and the eyespot's glow:

> Now, we need UI elements for other sensing genes. Beam does not need one, but
> smell could have something. See should work like smell, reflecting the stimulus
> on the organ itself. Add UI elements (modular, so they are not shown when the
> gene is not equiped, and greyed out when the gene is not active)

## 1. What they are

**A tile for every sense but the beam**, in the HUD's row after the energy gauge
(energy-gauge.md §2.1). Each is the organ that senses, drawn as its tile -- the
same drawing a control pad carries -- **lit by what it senses**, as the organ on
the body is (three-senses.md §2.6, §2.7). Under it a thin bar says how much.

| sense | organ | lit by | the bar |
| --- | --- | --- | --- |
| smell | `chemocyte` | the nose's glow: food along its arc | the level it smells |
| see | `stigma` | the eyespot's glow: the shadow it is under, brightest facing it | the shadow's strength |
| ping | `ampulla` | **a flash for each echo** as it comes home, as the organ on the body lights (ping-as-outline.md §14) | none: its tile is widened into a scope (§7), whose sweep is the round trip still to come |
| touch | `palp` | what the palps feel | the same |

**The beam has none.** Its rays already say what they strike, on the screen
where they strike it (the owner: *"Beam does not need one"*).

**2026-10-16, the light** (daylight.md §3.3): a fifth tile, for the organ that lives
on light. `plastid` drives no membrane channel, so its tile is keyed by the stat it
provides, `sun` -- a `readout` organ with no channel is keyed by its stat, worn being
the body's provider of it and carried the DNA's. Its glow and its bar are both the
light where the cell is, 0 to 1, the same for one copy or three. It sits first,
beside the energy gauge, whose rate it explains.

**"See works like smell, on the organ itself"**: the eyespot's tile and the nose's
are lit the same way, by the same glow the body's organ shows, so a player reads
one sense the way they read the other.

## 2. When they show, and when they are grey

**Modular: a tile exists only while its gene does.**

- **Shown** while the lineage carries a gene on that sense, in its DNA or on the
  body. A cell with no nose has no smell tile, and the row closes up.
- **At work** only while this body wears the organ and its senses are running.
- **Grey otherwise**, the organ faint and colourless, with no bar:
  - **carried, not worn**: the DNA has the gene and this body did not grow it.
    Copies are odds (lifecycle), so a daughter can carry a sense she does not wear.
    Her own daughters may.
  - **senses held**: a division's pinch, and a pond's still moments, as the drawn
    controls go quiet then.

A body that wears a sense its DNA no longer carries (written over this life, "your
body keeps it") shows it at work: the body is what senses.

## 3. How it looks

- **The tile is the pause target's size**, 56 × 56, on the gauge's slab, so the
  row is one height. With all four the row ends at 604 px of the 1280, under half
  the top edge, which nothing else uses; at 2400 × 1080 it ends at 604 of 1600.
- **The organ is a control pad's tile, a third larger** (`ORGAN_SCALE` 1.35), in its
  family's violet. Its shape is what tells the four apart, as on the pause screen's
  chips, where each carries its word.
- **Lit**: a haze of its hue over the dome and its strokes whitened
  (`cilia.gd`'s `draw_tile_organ`, its new `glow`), kept inside the tile.
- **The bar**: 32 × 4 at the tile's foot, its hue on a faint track.

## 4. Kept generic

- **`gene.gd`'s `readout`** says whether an organ's sense has a tile.
  `chemocyte`, `stigma`, `ampulla` and `palp` set it; the beam does not. A new sense
  sets one line.
- **`game/normal/sense_tile.gd`** knows a gene to draw, a glow, a level, whether it
  is at work, and `flash()` for a sense whose stimulus comes as events. It never
  names a sense.
- **`normal_mode.gd`** is the edge:
  - `_readout_channels()` makes one tile for every channel a `readout` gene drives,
    in the catalogue's order, at the start;
  - `_update_sense_tiles()` shows, greys and feeds them each frame;
  - `_sense_reading()` says, by channel, what each one's glow and level are;
  - `_post_pings()` flashes the ping's tile on each echo.
- **No words**, so nothing to translate. The organ is the label, as on a control
  pad.

## 5. Rendered

At 1280 × 720 and 2400 × 1080, in both views:

- all four worn, beside a big body: the eyespot, the nose and the palps lit with
  their bars, the ping unlit between echoes, its bar the listening left;
- the nose worn and the eyespot carried only: the eyespot's tile grey, the nose's
  lit;
- a born body with no sense: no tiles, the row ending at the gauge.

## 6. What to watch

- **Are the four told apart** by their shapes alone? If not, the lever is a word
  under each, which the row has the height for, at the cost of translating four.
- **Is a grey tile understood** as *your line carries this, you do not*? It is the
  pause screen's own distinction, carried into play.
- **Does the ping's flash read as its echoes**, beside the marks the membrane
  already draws for them?
- **Is the row too much** beside the water? The levers are the slab's fill and the
  tile's size.

## 7. The ping's scope (2026-10-16)

The owner: *"Add also an oscilloscope small UI showing pikes and a distance scale"*.
The ping's tile is widened into an **A-scope**, the radar's own oscilloscope. Range
runs left to right, and each echo is a spike where it came from.

```
┌────────┬───────────────────────────────────────┐  56 px
│        │ ▌        ╱╲       ╱╲         ╱╲   │      │
│ organ  │ ▌_______╱  ╲_____╱  ╲_______╱  ╲__│  ·· │  baseline y 35
│ 56 px  │ 0            500           1000      µm  │  scale, 10 px type
└────────┴───────────────────────────────────────┘
          call        echoes          sweep  last sweep, faint
```

- **The tile is still there, at the left**, lit by each echo as before (§1). The
  trace takes 168 px beside it, so the readout is 228 × 56 on the same slab. With
  all four senses, the row now ends at 776 px of the canvas's width, at either
  shape.
- **Range left to right**, from nothing to the organ's reach (1100, 1500 or 1900
  µm by copies). Ticks fall every 500 µm with their numbers under them, and the
  unit, a symbol and so untranslated, sits at the axis's end on the baseline. A
  number that would run into the next is left out.
- **The call is a spike at nothing**, the "main bang", full height.
- **Each echo is a spike at the distance it came from**:
  - as high as the square root of its strength, so a faint one still stands clear
    of the grass;
  - as wide as the body it came off is deep (its hold), and never thinner than
    1.4 px.
- **The sweep moves right** as the call's round trip runs:
  `(1 − ping_listen) × reach`. It reaches an echo's distance at the moment the echo
  lands, so a spike appears exactly where the sweep is. The cell knows an echo only
  when it lands (ping-as-outline.md §13), and so does the scope.
- **The last sweep stays ahead of the cursor, faint**, until the sweep reaches it:
  a phosphor's persistence. The scope is never empty through the 8.8 to 15.2 s of a
  call, and a body that moved between two calls shows as a spike that walked.
- **Grass**: a faint fixed ripple on the baseline, new each call and still within
  one, so the trace never flickers. It is computed from a hash, never from a random
  draw (signal_bus.gd says why).
- **Grey** when the ping is carried and not worn: the organ grey and an empty axis.
- **Kept generic**: `game/normal/scope.gd` extends the tile and knows a reach, a
  sweep, a call and its echoes by distance, strength and depth. A gene asks for one
  with gene.gd's `scope` (only the `ampulla` today). `normal_mode.gd` feeds it:
  - `_update_sense_tiles` sets the sweep;
  - `_post_pings` adds each echo;
  - `_on_pulsed` starts a new sweep.

**Rendered**, at 1280x720 and 2400x1080, in both views:
- a body 300 units ahead and one about 700 units out, frozen at 5.8 s: spikes at
  about 270, 430 (a passing water cell) and 660, the cursor at 725 (5.8 s × 125);
- the second call, at 11.6 s: the new spikes before the cursor and the last
  sweep's faint after it;
- the ping carried and not worn: grey;
- all four senses with a three-copy ping: a scale of 0 to 1500 µm.

**What to watch**:
- Are the numbers legible at 10 px on a phone? The lever is `LABEL_SIZE`, which
  the slab has the height for.
- Does the faint last sweep read as the past and not as now? The lever is
  `GHOST_ALPHA`.
