# How a hundred genes stay readable

The owner, 2026-10-04, row 2 of `gene-catalogue.md` §1, answered as recommended:

> Colour shows the family (moving, sensing, eating, defending, inside), shape shows
> the organ, the pause screen names the exact gene.

and row 1:

> "There will be new organs. but also variants. At any moment of the life of the game,
> we could add a new gene and/or variant."

This is phase 6 of `gene-catalogue.md` (§7.2, §7.3): the families and their colours,
the shapes an organ is built from, how a variant shows, what the membrane does with
all of it, and today's seventeen keys redrawn. It is the one part of that plan a player
sees on a body. The catalogue's fields, the probe's checks and the build follow from it
(§7 to §9).

**Status: built in phase 6, 2026-10-10.** §13 is what the build did and measured,
and where it differs from the sections above. Designed and mocked first, in the design
worktree on dev `77f90c3`, by changing `cilia.gd`, `signal_bus.gd` and `figure.gd`
locally and adding a specimen sheet (`tools/looks_sheet.tscn`). The mock is kept as a
patch beside the frames, not in the repository. Every frame in §10 was rendered at
1280x720 and 2400x1080 under `--rendering-driver opengl3 --fixed-fps 60 --seed=12345`
and looked at, in colour, in luminance only, and through a deuteranope simulation. One
frame rendered three times differs by **0 pixels**.

`$N` below is the design session's notes folder (`scratchpad/genes/notes/ux/`), not in
the repository: `$N/shots/` holds the frames, `$N/mock.patch` the mock, and
`$N/frames.sh` and `$N/sheet.sh` the commands that make them.

**What this replaces.** `genes-and-cilia.md` §4.4's hue rule (each gene its own hue,
30° apart) and its stroke counts (`EARNED_COUNT`): a gene's colour is its family's,
and its organ is told by shape. `dna-slots-ux.md` §2.1's strain hues (lime, ice, pale
moon): every strain wears the toxin's colour, and its accent tells it (§3.3).

---

## 0. Decided, in one place

1. **A family is a colour and a build.** Each family owns a band of the wheel *and* a
   way of being built: the movers beat, the senses stand still over a pigment, the
   defences are armed or plated, metabolism sits inside the skin, the mouth is a mat.
   A player who cannot see the colour still sees the family. §1.
2. **Five families: eating, moving, sensing, defending, metabolism.** `inside` is
   already the name of a place, the slot the poison goes in, so the fifth family takes
   its real name. Family names are never shown on screen. The owner chose `metabolism`
   on 2026-10-05 (§12).
3. **Colours are measured perceptually** (OKLCH): every family band at least 20° from
   every other, at least 30° from self teal and threat red, and the two pairs that
   colour blindness merges (moving and sensing, eating and metabolism) a lightness
   step apart. §1.3.
4. **Nine shape kinds, each a generator with a few parameters**, drawn on a body's arc
   or a tile's dome by the same code. A new organ picks a kind and its numbers; it
   needs drawing code only when it wants a parameter value that does not exist yet.
   §2.
5. **Tier stays magnitude**: longer, denser, brighter, wider, and for an organelle one
   more of it. Identity never rests on count or length. §2.3.
6. **A variant keeps its organ's colour and shape and changes one mark, its accent**:
   a disc, a ring, a diamond or a bar at the organ's accent seat. The toxin's strains
   are this rule's first case. §3.
7. **The pause screen names the exact gene**: the chip's word, the accent in the chip's
   first lobe, and `organ · variant` at the head of the explaining line. No family mark
   is added: the colour is the mark. §4.
8. **The membrane colours channels, never organs.** Five channels on the six glow lobes
   there are; a new sense on an existing channel changes nothing on the membrane. One
   pressure lobe is still free. §5.
9. **Content only.** GDScript and data under `game/`; `binary_version` does not move.
   §9.

---

## 1. Families

### 1.1 Five, and why the fifth is not called `inside`

| family | what it is for | today's organs |
|---|---|---|
| **eating** | taking food in | `cytostome` |
| **moving** | going somewhere | `cirrus`, `flagellum`, `axoneme`, `myoneme` |
| **sensing** | knowing what is there | `stigma`, `ocellus`, `chemocyte`, `ampulla`, `palp` |
| **defending** | being costly to touch: armed or plated | `trichocyst`, `pellicle`, the toxin (`toxicyst`, `veneneux`) |
| **metabolism** | living on less: making, storing and burning food | `plastid`, `vacuole`, `crista` |

The owner's five words cover all seventeen keys. Only the fifth needs another name.
`inside` is the place the owner named on 2026-10-03, the slot where a toxin becomes
poison, and it is on screen: `inside your body · only a toxin goes here`. `sun`, `store`
and `burn` cannot go there. So a family called `inside` would teach a rule the game
refuses (`sun works only outside`). The three are what biology calls metabolism, and
they are drawn inside the skin (§2.1), so the owner's picture survives the rename.

**The toxin is one organ in one family.** At the front its venom makes your bite costly;
on a side it stings what bites you; inside it poisons what swallows you. All three make
the cell costly to touch, which is what *defending* means here.

**Family names never reach the screen.** A gene's own word already says its family
(`see`, `smell`, `ping`, `touch` and `beam` are senses), the chip has no room, and five
new words would each need a translation. The family is a key in code and a colour on
screen.

### 1.2 A family is a colour and a build

A deuteranope simulation of today's palette (Machado 2009, severity 1) shows the
problem. Today's six blues and violets, up to ΔE 0.18 apart in OKLab to normal vision,
come within 0.055 of each other (median 0.024): one blue. The five greens, golds and
lime come within 0.071: one yellow. About one man in twelve has some form of this. So
colour alone can carry two families at best, and the house rule already says what to
do: *any signal whose opposite is drawn on the same shape must differ in shape, not
only in colour* (`genes-and-cilia.md` §4.4).

**So each family is also a build**, and the builds are the real ones:

| family | build | the biology it borrows |
|---|---|---|
| eating | a dense mat with a beat travelling along it, at the mouth | oral membranelles |
| moving | things that **beat**: oars with a knee, lashes with a travelling wave, a spring that draws up | cirri, flagella, a myoneme's spasmoneme |
| sensing | things that **stand still** over a pigment: stiff bristles, or a lens | sensory cilia are non-motile; eyespots are pigment |
| defending | things that are **armed or plated**: hard shafts with heads, beads, scales along the skin | extrusomes, the pellicle's alveolar plates |
| metabolism | bodies **inside the skin** at the arc, nothing outside | plastids, vacuoles, mitochondria |

Two tells survive any colour vision. In play, movers move and senses do not. On a still
frame, **only a sense carries a pigment disc**, so a disc under the skin means a sense.
That one fell out of the design rather than being put in, and the deuteranope frames
show it working (`$N/shots/after_sheet_deut_*`, `one_compare_*`).

### 1.3 The bands

Each family has three explicit shades. They share a lightness and a chroma, so a shade
never reads as a tier, and they step in OKLCH hue. Measured on the colours below:

| family | shade 0 | shade 1 (default) | shade 2 | OKLCH hue | lightness | HSV hue, for the code's comments |
|---|---|---|---|---|---|---|
| eating | `Color(0.75, 0.97, 0.22)` | `Color(0.69, 0.99, 0.31)` | `Color(0.63, 1.00, 0.40)` | 125–135 | 0.91 | 78–97 |
| metabolism | `Color(0.97, 0.80, 0.18)` | `Color(0.93, 0.82, 0.20)` | `Color(0.89, 0.84, 0.23)` | 92–105 | 0.86 | 47–56 |
| defending | `Color(1.00, 0.52, 0.16)` | `Color(0.98, 0.54, 0.04)` | `Color(0.94, 0.57, 0.05)` | 52–65 | 0.74 | 26–35 |
| moving | `Color(0.33, 0.79, 0.98)` | `Color(0.41, 0.78, 0.99)` | `Color(0.48, 0.76, 0.99)` | 229–245 | 0.79 | 198–207 |
| sensing | `Color(0.60, 0.53, 0.99)` | `Color(0.65, 0.50, 0.98)` | `Color(0.70, 0.48, 0.95)` | 288–304 | 0.69 | 249–268 |

- **Eating keeps today's mouth green**: `cytostome` is its shade 2, `Color(0.63, 1.00,
  0.40)`, a hundredth or two off today's. The band reaches toward yellow and never toward food
  green (146): the mouth sits 10.5° from food on purpose, as it does today ("the mouth
  *is* nutrition").
- **Defending is orange, because orange is the colour of warning** (aposematism: wasps,
  poison frogs). It is 33° from threat red and lighter: ΔE 0.21 normally and 0.20 to a
  deuteranope. The threat bow keeps its teeth, which is what carries it anyway.
- **Moving is sky blue and sensing is violet**: the two families every player has on
  every cell, and the pair colour blindness merges. **Moving is 0.10 lighter**, which
  puts their middle shades 0.121 apart to a deuteranope, against 0.024 at one
  lightness.
- **Metabolism is gold, eating is green**: the other merged pair, 0.05 apart in
  lightness. Its real separation is the build: a mat at the nose against bodies inside
  the skin.

Measured gaps, OKLCH hue degrees:

| check | value | limit |
|---|---|---|
| closest pair of shades in different families | 20.8 (eating 0, metabolism 2) | ≥ 20 |
| closest to self teal (174) | 38.6 (eating 2, the mouth) | ≥ 30 |
| closest to threat red (18.5) | 33.1 (defending 0) | ≥ 30 |
| closest to food green (146), any family but eating | 41.3 (metabolism 2) | ≥ 30 |
| lightness between any two families | ≥ 0.05 | ≥ 0.04 |

**Free for a sixth family: rose, OKLCH 324–348** (HSV about 315–340). It is the only
band left that keeps 20° from sensing and 30° from red. Cyan between teal and moving is
5° wide and too narrow for a band.

### 1.4 Shades: a whisper, on purpose

Two shades of one family are about ΔE 0.025 apart. That is one or two just-noticeable
differences: visible side by side, invisible on a 9-pixel tuft. Shade is not identity.
It exists for the places where two organs of one family meet side by side: the beam and
the ping lobes on the membrane (§5), and the ingest flood. An organ that sets none takes
shade 1. The probe never accepts a shade as the only difference between two organs.

---

## 2. The shape vocabulary

### 2.1 Nine kinds

Lengths are fractions of the body radius at one copy. "Seat" is where a variant's
accent goes (§3).

| kind | family | what it draws | parameters, with defaults | moves | seat, and its mark as shipped |
|---|---|---|---|---|---|
| `mat` | eating | dense fine cilia just off the skin, a beat travelling along them | count 15, length 0.27 | the metachronal wave | basal body, none |
| `oars` | moving | rowing strokes with a knee, in antiphase on both flanks | count 5, length 0.34, knee 0.62, bend 34° | rows | basal body, none |
| `lash` | moving | long strands with a wave travelling to the tip | count 6, length 0.62, wave 0.26, waves 1 | lashes | basal body, none |
| `coil` | moving | a zigzag spring standing off the skin | count 1, length 0.40, turns 2 | draws up and lets go | basal body, none |
| `tuft` | sensing | stiff bristles fanned over a pigment disc | count 3, length 0.30, tip `plain`/`fork`/`ring`/`hook`/`tri`, bend 0°, fan 16° | never | pigment, disc |
| `lens` | sensing | a clear lens standing on the skin over a pigment disc | bulge 0.20 | never | pigment, disc |
| `spines` | defending | hard straight shafts, fanned, each with a head | count 3, length 0.30, tip `spear`/`bead`/`barb`, fan 14°, `per_copy`, `lips` | never | beads, disc (a spear has a basal body) |
| `plates` | defending | overlapping scales lying along the skin over a thickened rim | count 3 | never | basal body, none |
| `organelle` | metabolism | bodies under the skin at the arc, nothing outside it | form `lens`/`bubble`/`capsule`/`stack`/`star`, size 0.17, depth 0.30 | never | the centre of each, none |

- **The toxin's three place forms are one kind in three places.** `spines` with bead
  tips, two a copy (`per_copy 2`), are barbs on the arc at a side or the stern, as today.
  With `lips` they are fangs on the lip bow in a front slot. Inside they are their beads
  with no shafts, under the whole skin: the granules. `dna-slots-ux.md` §2.2 to §2.4's
  numbers stand. A future bite-riding organ sets `lips` and gets fangs; an inside form of
  any bead-tipped organ gets granules.
- **`bend` splays the outer bristles away from the middle**, as feelers do.
  **`waves`** is how many waves a strand carries: 1 is the tail's own, 2 is a whip.
  **`per_copy`** replaces `count` with *n a copy* for an organ that grows in pairs.
- **Home organs are kinds too.** `cytostome`, `cirrus` and `flagellum` are `mat`,
  `oars` and `lash` with today's constants as the kinds' defaults, drawn on the arcs
  they are drawn on today, so a body draws exactly what it draws today.

### 2.2 One generator, two skins

Each kind is one generator that draws on a **skin**: a stretch of a body's arc, or the
tile's dome. The body passes `r` as the length unit and the arc in ovoid degrees. The
tile passes its dome (`TILE_ARC_RADIUS`) and **36.7 px per body radius**
(`TILE_LEN_EARNED / LEN_EARNED`). So the tile is the same organ at the tile's scale,
which is the promise `cilia.gd` makes at its top. The explaining line's glyph and the
quick placement's buds are that tile; they change with it, at no extra cost.

On a tile, a reach is capped at 0.46 r, which is 17 px, today's tallest (the tail). A
lash shows at most three strands. That keeps the explaining line's row exactly as it was
measured: the glyph's top sits at `EXPLAIN_ORGAN_SEAT`.

The mock had to learn one thing about drawing. A continuous outline built from separate
segments, in one `draw_multiline`, shows a bright dot at every joint, and dots are what
*armed* looks like. **Closed outlines are polylines**: rings, lenses and organelles.
Strokes stay in the organ's one `draw_multiline`, as today (§9.2).

### 2.3 Tier is magnitude

| kind | one copy → three |
|---|---|
| every kind with strokes | length × `TIER_LEN` (1, 1.22, 1.46), alpha × `TIER_ALPHA` (1, 1.12, 1.24) |
| `mat`, `oars`, `lash`, `coil`, `tuft`, `spines`, `plates` | count × `TIER_COUNT` (1, 1.35, 1.70), or `per_copy` × copies |
| `tuft`, `spines` | the fan opens 6° a copy, so tips stay apart as the count grows |
| `lens` | bulge × `TIER_LEN` |
| `organelle` | **one per copy: 1, 2, 3**. Three things are counted without counting |

**What tier never changes**: the kind, a tip, a bend, a form or `waves`. The probe never
counts count or length as identity. That is what ends today's collision, where tier
multiplies the very stroke count that told organs apart: an `ocellus` at three showed
five strokes, the same as a `myoneme` at one.

### 2.4 How much room

An organ is *different at a glance* when it differs from every other organ of its family
in a structural parameter: kind, tip, bend, form or waves. Rendered at true size
(`$N/shots/after_sheet_*`, `room_*`):

| family | different on a body | also different on a tile | used today |
|---|---|---|---|
| eating | 1: `mat` | 1 | 1 |
| moving | 4: `oars`, a 1-wave `lash`, a 2-wave `lash`, `coil` | 5: a 4-turn `coil` | 4 |
| sensing | 9: five tips × straight or bent, less the three-way tip, plus `lens` | 11: the three-way tip | 5 |
| defending | 3: spear, bead, `plates` | 4: `barb` | 3 |
| metabolism | 5: `lens`, `bubble`, `capsule`, `stack`, `star` | 5 | 3 |
| **all** | **22** | **26** | **16** |

With three or four accents per organ (§3), that is about a hundred keys a player can
tell apart on a body, the faintest by a basal-body dot, and every one of them named
exactly on the pause screen. That meets row 1, where most new genes are variants.
**Moving and defending have the least room.** Their next new organ will want a new
parameter value: a new tip, form or head, which is a few lines in that kind's generator
plus a render. The probe says so when a new organ collides (§8).

### 2.5 An unknown gene

A key this build does not know, arriving over an older binary, draws as a plain `tuft`
in **`UNKNOWN_TINT`, `Color(0.78, 0.84, 0.82)`**. That is pale, low in chroma and in no
family. It replaces today's fallback, indigo, which now sits inside the sensing band and
would pass an unknown gene off as a sense.

---

## 3. Variants: the accent

### 3.1 One mark at one seat

A variant keeps everything its organ's look says: family, shade, kind and parameters.
It changes one thing, **its accent**: a mark from four, drawn at the kind's seat.

| mark | drawn |
|---|---|
| `disc` | filled |
| `ring` | hollow, the stroke 0.42 of its radius |
| `diamond` | a square on its point, square to the skin |
| `bar` | a short slab lying along the skin |

| seat | kinds | its mark as shipped | variants may use |
|---|---|---|---|
| the pigment (a variant's mark at 0.85 of `PIGMENT_OUTER`) | `tuft`, `lens` | disc | ring, diamond, bar |
| every bead; a ring, diamond or bar bead is never under 2.6 canvas px | `spines` with bead tips | disc | ring, diamond, bar |
| the centre of each organelle | `organelle` | none | disc, ring, diamond, bar |
| a basal body, 0.11 r inside the skin at the arc's middle (0.085 r) | `mat`, `oars`, `lash`, `coil`, `plates`, spear `spines` | none | disc, ring, diamond, bar |

The basal body is real: every cilium and flagellum is rooted in one, just inside the
cell. So an organ that beats shows its variant at its root, where nothing else is drawn.

**An organ holds three or four variants this way**, plus the organ as shipped. One
variant more than its seat has marks fails the probe, with the sentence that names the
fix: a new organ.

### 3.2 Not tier, and not a place

- **Tier is magnitude** and an accent is a shape. An accent never changes length, count,
  alpha or fan, and tier never changes a mark.
- **The toxin's place forms are where the beads are**: on the lips, on an arc, under the
  skin. A strain is what the beads are. A paralysing venom at the front is fangs with
  diamond beads.
- **Never colour.** A variant and its organ are the same shape in the same place, which
  is the case the house rule exists for. So they differ in shape, and a variant cannot
  set a hue.

### 3.3 The toxin's strains are the first case

`dna-slots-ux.md` §2.6 planned *"the shape is the bead: discs for corrosive, diamonds
for paralysing and rings for sleeping"*, with the same bead in the slot chip. That
becomes the general rule here, unchanged for the toxin. What changes is the colour:

- **every strain wears the toxin's orange**. Lime, ice and pale moon go, because a
  strain's hue would be a second family colour on one organ;
- **a load is drawn in the hue of the organ that delivered it**, which is already what
  `Cilia.dose_hue()` does. The three kinds stay apart by what `dna-slots-ux.md` §4.4
  already gives them: a roiling lump, a still shard, a swelling haze; pits, droop, dark
  senses. That table was built to survive greyscale, so it does not need the hue.

`STRAIN_COLORS` in `signal_bus.gd` becomes the delivering organ's hue, read from the
catalogue.

---

## 4. The pause screen and a cell's detailed view

The figure is `Cilia.draw_cell`, and the detailed view's figure is the same code
(`cell_figure.gd` delegates to `figure.gd`). Both change with the kinds and nothing else
does. What names the exact gene:

| where | today | with families |
|---|---|---|
| the body on the figure | hues and tufts | kinds, in family colours, with accents |
| a chip's rungs and pips | the gene's hue | the organ's shade; one family reads as one colour across the ring |
| **a chip's first lobe** | the plain weave | **a variant's accent**: 3.6 px, in its hue at full ink like a pip, centred in the lobe (x 20, y 19). The rungs keep the middle lobe and a level keeps the third |
| the chip's word | the gene's word | the variant's own word, which a variant brings (`gene-catalogue.md` §8.1) |
| the explaining line's name | `ampulla` | **`organ · variant`** for any variant but the organ as shipped (`toxicyst · paralysing`), in the hue. `dna-slots-ux.md` §3.6 planned it for the strains, and it is generalised here |
| the glyph beside the line | the tile | the tile's kind, with the accent |
| the tray's chip (waiting genes) | word and ring pips | the accent before the word, as on the slot's chip. Not mocked; the build shoots it |
| in the water, the hole a waiting gene is trying (`dna-body.md` §8) | a generic tuft of four, floating off the skin, in the gene's hue | **the waiting organ's own kind**, faint, on the skin lifted as today's ghost is, **strokes and outlines only**: an organelle cannot float clear of the skin, so its ghost is its outline, unfilled. The bud beside it is already the organ's tile |
| the body's word where it disagrees with the DNA (`dna-body.md` §4) | needed | **still needed**: two organs of one family can share a kind |

**No family mark.** The colour is the family, and the screen already prints it in the
rungs, the pips, the name and the organ. Eight chips read as five colour groups (eat;
turn and swim; smell and beam; sting and poison; sun) without a legend
(`$N/shots/after_pause_*`). The choosing screen's strand groups the same way
(`after_choose_*`). Its loci keep the dart and the word, and a variant is told there by
its word.

---

## 5. The membrane

### 5.1 Channels, not organs

The membrane is what the cell feels, and a channel is a kind of feeling. **Each lobe
takes its channel's colour, whichever organ drives it**, so a new organ on an existing
channel changes nothing on the membrane:

| channel | lobe | colour | why that colour | today's organ |
|---|---|---|---|---|
| `light` | glow 2 | amber, `LIGHT_COLOR`, light's own | what it reports has a colour | `stigma` |
| `beam` | glow 3 | the hue of the organ providing `beam_range`: sensing shade 0 | a struck body has no colour, so it is the sense's own | `ocellus` |
| `ping` | glow 4 and 5 | the hue of the organ providing `ping_range`: sensing shade 2 | the same, a shade apart from the beam as today | `ampulla` |
| `smell` | glow 1, the ring | food green, `NUTRIENT_COLOR` | it reports food, and full vision's bloom is that green | `chemocyte` |
| `touch` | glow 0, the bruise envelope held at a level | self teal | it reports your own skin | `palp` |
| (the cell's own) | glow 0 | teal, or a dose's hue on a dosed bite | thrust, shear, a bite | home organs, doses |
| (a wake) | pressure 0 | — | dread | — |
| **free** | **pressure 1** | — | idle since `statocyst` | — |

- **A new sense on an existing channel** names its channel (the catalogue's `channel`
  field, `gene-catalogue.md` §7.3) and needs nothing else. A second eye-spot is `light`;
  a better nose is `smell`. Two on one channel act as one, from the first in slot order
  (`gene-catalogue.md` §5.2).
- **A new channel is code.** The first new channel that is a pressure, a dent at a
  bearing, takes pressure lobe 1 with no shader change. A new glow channel needs a
  seventh glow lobe in `signal_bus.gd`, the shader's arrays and the replay's block, and
  it brings a lobe design with it.
- `BEAM_COLOR` and `PING_COLOR` move by at most 0.02 and 0.05 in any channel.
  Rendered, the beam's lobe is unchanged to the eye (`$N/shots/lobes_compare_*`).

### 5.2 The flood

**The ingest flood takes the organ's hue, which is now its family's.** Point of view
learns *you ate a sense*, and the pause screen says which, which is row 2 exactly. A
poisonous meal floods in the toxin's orange instead of lime (`flood_compare_*`). A meal
with no gene floods food green, unchanged.

Checked against the membrane's own colours: the orange of a venom's bruise is **ΔE 0.139
from the amber light lobe; lime was 0.140**. It is no closer than today. A bruise also
always comes with its bite's hit.

---

## 6. Today's seventeen keys

| key | word | family | shade | kind | its parameters | was |
|---|---|---|---|---|---|---|
| `cytostome` | eat | eating | 2 | `mat` | as the kind | green 95°, the mat |
| `cirrus` | turn | moving | 1 | `oars` | as the kind (both flanks) | blue 216°, oars |
| `flagellum` | swim | moving | 0 | `lash` | as the kind | orchid 291°, the lash |
| `axoneme` | push | moving | 2 | `lash` | count 1, length 0.50, wave 0.22, waves 2.1: a whip | magenta 306°, tuft of 8 |
| `myoneme` | dash | moving | 1 | `coil` | as the kind | rose 333°, tuft of 5 |
| `stigma` | see | sensing | 1 | `tuft` | count 3, length 0.26, tip `plain` | amber 45°, tuft of 4 |
| `ocellus` | beam | sensing | 0 | `lens` | as the kind | periwinkle 251°, tuft of 3 |
| `chemocyte` | smell | sensing | 1 | `tuft` | tip `fork` | green 111°, tuft of 8 |
| `ampulla` | ping | sensing | 2 | `tuft` | length 0.24, tip `ring`: pores | violet 263°, tuft of 6 |
| `palp` | touch | sensing | 2 | `tuft` | count 2, length 0.54, bend 34°: feelers | peach 23°, tuft of 8 |
| `trichocyst` | sting | defending | 2 | `spines` | length 0.32, tip `spear`: darts | violet 276°, tuft of 3 |
| `pellicle` | armor | defending | 1 | `plates` | as the kind | cyan 186°, tuft of 7 |
| `toxicyst`, `veneneux` | venom, poison | defending | 1 | `spines` | tip `bead`, per_copy 2, length 0.26, fan 16°, `lips` | lime 71°: fangs, barbs, granules |
| `plastid` | sun | metabolism | 1 | `organelle` | form `lens`: solid | gold 52°, tuft of 8 |
| `vacuole` | store | metabolism | 0 | `organelle` | form `bubble`: hollow | blue 232°, tuft of 2 |
| `crista` | burn | metabolism | 2 | `organelle` | form `capsule`: a rod with a fold | brown 26°, tuft of 6 |

Hue degrees are HSV, as `cilia.gd` writes them. The pairs that were too close today
(`palp` and `crista` at 3.2°, `stigma` and `plastid` at 6.3°, `flagellum` and
`trichocyst` at 7.8°, `cirrus` and `vacuole` at 10.2°) are all now in different
families and different builds. `ocellus` and `trichocyst`, the two violet three-stroke
organs `dna-body.md` §4 needed a word for, are a violet lens and orange darts.

---

## 7. What the catalogue holds

The fewest fields that work. `gene-catalogue.md` §4.2 already has `family` on the organ;
its `look` loses `hue`, which is derived.

**`game/genes/families.gd`**, one row per family:

```gdscript
const FAMILIES := {
	&"eating": {"shades": [Color(0.75, 0.97, 0.22), Color(0.69, 0.99, 0.31),
		Color(0.63, 1.00, 0.40)], "kinds": [&"mat"]},
	&"moving": {"shades": [Color(0.33, 0.79, 0.98), Color(0.41, 0.78, 0.99),
		Color(0.48, 0.76, 0.99)], "kinds": [&"oars", &"lash", &"coil"]},
	&"sensing": {"shades": [Color(0.60, 0.53, 0.99), Color(0.65, 0.50, 0.98),
		Color(0.70, 0.48, 0.95)], "kinds": [&"tuft", &"lens"]},
	&"defending": {"shades": [Color(1.00, 0.52, 0.16), Color(0.98, 0.54, 0.04),
		Color(0.94, 0.57, 0.05)], "kinds": [&"spines", &"plates"]},
	&"metabolism": {"shades": [Color(0.97, 0.80, 0.18), Color(0.93, 0.82, 0.20),
		Color(0.89, 0.84, 0.23)], "kinds": [&"organelle"]},
}
```

**`game/genes/kinds.gd`**, data only, so the catalogue validates looks without
preloading a view (`gene-catalogue.md` §4.1). For each kind, its parameters: default,
range or allowed values, and whether it is **structural** (tip, bend, form, waves, lips:
identity) or **magnitude** (count, length, fan, wave, bulge, size: never identity). Also
its seat and the seat's mark as shipped, and the four accent marks. `cilia.gd`
implements one generator per kind by these names.

**An organ's file**:

```gdscript
	family = &"defending"
	look = {"shape": &"plates", "count": 3}      # shade 1 unless it says otherwise
```

```gdscript
	family = &"defending"
	look = {"shape": &"spines", "tip": &"bead", "per_copy": 2, "length": 0.26,
		"fan": 16.0, "lips": true}
	variants = [
		{"variant": &"corrosive", ...},                      # as shipped: the seat's disc
		{"variant": &"paralysing", ..., "look": {"accent": &"diamond"}},
		{"variant": &"sleeping", ..., "look": {"accent": &"ring"}},
	]
```

| field | where | required | meaning |
|---|---|---|---|
| `family` | organ | yes | a key of `FAMILIES` |
| `look.shape` | organ | yes | a kind the family allows |
| `look.shade` | organ | no, 1 | 0, 1 or 2 |
| the kind's parameters | organ | no, the kind's defaults | as `kinds.gd` lists them |
| `look.accent` | variant | yes, on every variant but the first | `disc`, `ring`, `diamond` or `bar` |
| `channel` | sense organ | yes | `light`, `beam`, `ping`, `smell` or `touch` (`gene-catalogue.md` §7.3) |

A variant may set `look.accent` and nothing else in `look`. A form row inherits its
variant's look; the place decides where the kind draws (§2.1).

---

## 8. What the gene probe checks

Static, in `tools/gene_probe.gd`, replacing `gene-catalogue.md` §12.1's colour lines
from phase 6:

**Every live organ**

1. `family` is a family; `look.shape` is a kind that family allows; no `hue` key.
2. Every parameter is one its kind knows, inside its range; `shade` is 0, 1 or 2.
3. **No two organs in one family with the same kind and the same structural
   parameters.** Count and length alone are not a difference. The message names both
   organs and says the fix is a new tip, form or head.
4. Its tile drawing fits: the generator run on the tile skin, with no canvas, stays
   inside the 76 px tile and under the explaining row's glyph box (34 x 26 at 0.6).

**Every variant**

5. Every variant but the first sets an `accent` from the four, different from its seat's
   mark as shipped and from every sibling's; it sets nothing else in `look`. More
   variants than marks fails with: *make a new organ*.

**Colours**, in OKLCH, computed from the `Color`s, about twenty lines:

6. A family's three shades share a lightness within 0.02 and step in hue by 5–10°.
7. Every shade is at least 20° from every shade of every other family.
8. Every shade is at least 30° from self teal (`SELF_TINT`) and threat red
   (`PREDATOR_TINT`); no family but eating within 30° of food green (`FOOD_TINT`).
9. Any two families are at least 0.04 apart in OKLab lightness.
10. Every copy of a colour matches its source: `BEAM_COLOR`, `PING_COLOR` and
    `STRAIN_COLORS` against the organs that provide those channels and doses
    (`gene-catalogue.md` §12.1 already lists this).

**Senses**

11. Every sense names a channel that has a lobe (§5.1).

---

## 9. Building it

### 9.1 Files

| file | change |
|---|---|
| `game/genes/families.gd`, `game/genes/kinds.gd` | new, data (§7) |
| the organ files | `family`, `look`, accents |
| `game/vision/cilia.gd` | one generator per kind on a skin (§2.2); `_draw_fringe` and `draw_tile_organ` dispatch by kind; the home organs' functions become the `mat`, `oars` and `lash` generators. **Go**: `HUES`, `RESERVED_HUES`, `EARNED_COUNT`, `COUNT_EARNED`, `TILE_COUNT`, `TILE_LEN`, `TILE_COUNT_EARNED`, the per-gene tile branches. **New**: `UNKNOWN_TINT`, `ACCENT_BEAD_MIN` 2.6 |
| `game/perception/signal_bus.gd` | `BEAM_COLOR`, `PING_COLOR` and `STRAIN_COLORS` read from the catalogue by channel and dose (or kept as copies the probe checks) |
| `game/normal/figure.gd` | the accent in the chip's first lobe and on the tray's chip; `organ · variant` as the line's name |
| `game/vision/cilia.gd`, `_draw_socket` | the ghost of the hole being tried draws the waiting organ's kind, outline only (§4) |
| `docs/design/genes-and-cilia.md` §4.4, `dna-slots-ux.md` §2.1 | a line each pointing here |

### 9.2 What a body costs to draw

Today an earned organ costs one `draw_multiline` and five circles (haze, rim, core). A
kind costs **one `draw_multiline` for its strokes**, plus one polyline per closed outline
(a ring tip, a lens, an organelle: at most three), one polygon per fill (at most three),
and its marks. The tail stays one multiline. On the worst body the game makes, that is
within a few calls of today. Measure a full-vision frame with fifty cells on the owner's
phone in the dev app before merging, as the fringe's own comment asks of anything drawn
per cell.

### 9.3 Content or binary

GDScript and data. No autoload, no project setting, no shader uniform: the lobes
are the six there are. **Content**; `binary_version` stays. It changes nothing the
referee judges, so `Wire.RULES` and the protocol do not move.

### 9.4 Frames the build shoots

The mock's, under the mock's names (`$N/frames.sh`, `$N/sheet.sh`), at both shapes,
three times first to show 0 px:

| frame | pose |
|---|---|
| `fv` | `--mode=1 --radius=34`, the player with eight genes and six posed water cells (`frames.sh`) |
| `one` | `--mode=1 --radius=30 --desert=700`, one water cell at r39 with seven outside genes and poison, `--cell=0,150,60,39,…,90`, frozen at 0.5 s |
| `pause`, `pausevar` | `--radius=39.5`, seven genes and poison; the same with a variant eye and a paralysing strain, the eye's chip tapped |
| `choose` | `--mode=0 --radius=40 --dna=…`, at 6.0 s |
| `flood`, `lobes` | point of view: `--poison-meal=1.5`; `ocellus` and `ampulla` with two posed cells, frozen at 3.4 s |
| the sheet | every organ at one and three copies with its tile; `--variants=1`; `--room=1` |
| the tray | a waiting variant: the accent before its word. Not in the mock |

---

## 10. Rendered and judged

Before is dev `77f90c3`; after is the mock. All in `$N/shots/`, as
`<frame>_<1280x720|2400x1080>.png`. `_grey` is luminance only (Rec. 709 relative
luminance), `_deut` the Machado deuteranope simulation, and `_zoom` a 4x crop of real
pixels. Three renders of `one` differ by **0 pixels** (`det1`–`det3`).

| frame | 1280x720 | 2400x1080 |
|---|---|---|
| `before_fv` / `after_fv`: full vision, seven cells | **after reads by family**: violet discs are senses, orange is armed or poisonous, gold inside is metabolism. Free-arc organs at one copy are still a few pixels, as they always were. **Cost**: every born fringe is now one blue, where the tail used to be orchid | the same, and the kinds are legible: the ping's ring tips, the plates' arc, the organelles inside. Before, every organ was a coloured flag and a disc that needed a legend |
| `one_compare` (`before`/`after_one_zoom`, `_zoomgrey`, `_zoomdeut`): a cell at r39 with seven genes and poison | **pass.** In luminance, before is four identical discs with tufts; after is a lens, forks, darts, a solid body inside, and granules | **pass**, and the deuteranope column decides it. Before, smell and sun are the same yellow disc and tuft, and beam and sting the same blue one. After, every organ is its own shape |
| `before_sheet` / `after_sheet` (+ `_grey`, `_deut`): seventeen organs at one and three copies, and their tiles | **pass.** One copy on a free arc is small but each kind keeps its silhouette; three copies fan instead of closing into a flag | **pass.** All seventeen tile glyphs are distinct in greyscale; under deuteranopia every family is still told by its build |
| `variants`: accents on an eye, a see-tuft, a tail, three toxin strains, a plastid, a vacuole | **pass.** Ring, diamond and bar read on the pigment at true size; strain beads read at the 2.6 px floor; the tail's basal body is a small dot, the weakest seat | **pass.** Every accent is clear, on bodies and tiles |
| `room`: hooked and three-way tips, ring tips bent, barbed spines, stacked and star organelles, a two-wave lash, a four-turn coil | the hook, the bent rings, the stack and the star are new organs at a glance. **The three-way tip, the barb and the four-turn coil only read on a tile** (§2.4 counts them so) | the same |
| `before_pause` / `after_pause`: the figure, seven chips and poison | **pass.** The ring reads as five colour groups; the figure carries the kinds; nothing moved in the layout | **pass** |
| `after_pausevar`: a variant eye selected, a paralysing strain | **pass.** The ring and the diamond sit in the chips' first lobes, clear of the rungs; the figure shows the ring pigment and diamond beads. The words are raw keys, standing in for the words variants bring | **pass**, crisp |
| `before_choose` / `after_choose` | **pass.** The strand's rungs group by family down both columns; the daughters wear the kinds | **pass** |
| `flood_compare`: a poisonous meal in point of view | **pass.** The flood is orange instead of lime; the stain and pits on the figure match it | **pass** |
| `lobes_compare`: beam and ping in point of view | **unchanged**, as intended: the beam's lobe and its mark are the same violet | **unchanged** |
| `offer_pair` (`after_offer_plastid`, `after_offer_ampulla`): the body held open with a gene waiting, full vision | **pass.** The bud is the organ's tile (a gold body in its dome; ring-tipped pores); the ghost on the skin is the same organ, faint: a hollow outline for the plastid, pores and a dim pigment for the ampulla | **pass** |

**What judging changed:**

| first version | what it looked like | now |
|---|---|---|
| the lens as an outline | a hook, not an eye | a filled lens over the pigment |
| a myoneme of small loops | at body size the loops read as **beads**, which mean *armed* | a bold zigzag spring |
| an axoneme of two high-frequency strands | a zigzag, the spring's twin | one smooth whip with two waves |
| a capsule `crista` beside a lens `plastid`, both striped | two striped blobs | a solid oval against a long hollow rod with a fold |
| outlines from separate segments | a bright dot at every joint, beading the plastid and the lens | closed outlines as polylines |
| tufts that only grew denser with tier | five forks or rings at three copies merged into a patch | the fan opens 6° a copy |
| the home organs' tiles as before | turn and swim were straight strokes, the same as `see` | every tile is its kind: kneed oars, lashes, the mat |
| six lash strands on a tile | a tangle | three strands, reach capped at 17 px |
| variants drawn by a look of their own | a variant tail that was not its organ's tail | a variant is its organ's look plus the accent |
| strain beads at 1.6 times | heavy diamonds on the 60 px figure | a 2.6 px floor |
| the hole's ghost as today's tuft | gold bristles for a sun, a build no metabolism organ has | the waiting organ's kind |
| that ghost with its fills and pigment | a solid organelle and a bright pigment: an organ, not a hole | outlines only, the pigment at the ghost's ink |

---

## 11. Left open

1. **Every born cell's fringe is one blue.** Oars and tail are both moving, so the
   commonest cells lost the orchid tail's second colour. This is what *colour shows the
   family* means, and the earned organs now stand out against it. Play will tell if the
   water feels flatter.
2. **Drifters come closer to your own teal.** A moving-dominant body is tinted ΔE 0.089
   from the player's teal, against 0.102 for today's cirrus-dominant drifter, and
   drifters are the commonest cell. The lever is the moving band's hue: 5–8° further from
   teal costs the same off the 43° to sensing.
3. **One copy on a free arc is still a few pixels at 1280x720.** The free arcs are 24–28°
   of the ovoid; no kind changes that. At true size a family reads reliably, and an organ
   reads from two copies or on a phone. The pause screen is where exact identity was
   always going to live (row 2).
4. **Moving and defending have the least room** (§2.4). Their next organs will want a
   new parameter value.
5. **The weakest pairs**: the whip and the spring, told apart in a still frame by
   smooth against sharp, and in play by lashing against drawing up. A beater's basal-body
   accent is a small dot.
6. **`sun works only outside`** (`ACT_FACES_OUT`) is still what a metabolism gene dragged
   to the inside says, while it is now drawn inside the skin. It was already slightly
   untrue (a sun faces nothing). If players stumble on it, the sentence wants a per-organ
   word, which the catalogue's words allow.
7. **The tray chip's accent is specified, not mocked.** Built and shot in phase 6 (§13).
8. **Whether metabolism genes should one day go in inside slots** is a game question, not
   a look. If they do, an inside organelle draws round the nucleus instead of at an arc,
   as the toxin's inside form drops its arc: a few lines in that kind, not mocked.

---

## 12. The owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | What is the fifth family called? | `inside`, as in row 2 · **`metabolism` ✓ recommended** · another word | Sun, store and burn are the cell's machinery for food. `inside` is already the name of the slot only a toxin goes in, so the same word for these would say they go there, and they cannot. The name lives in each gene's file for the gene pass; no player reads it on screen. |

**Answered 2026-10-05: `metabolism`, as recommended.** The owner: *"Recommended"*.

Nothing else here is a name or changes what the game is. The colours, the shapes and
the toxin leaving lime for orange are looks, decided above and photographed.

---

## 13. As built: phase 6, 2026-10-10

Built on phase 4's tree (`b63e365`), in the files §9.1 lists. The frames are kept in
the build session's notes (`scratchpad/genes/notes/p6/shots/`), not in the repository,
as the mock's were.

| file | what it holds |
|---|---|
| `game/genes/families.gd` | the five families, each three shades and the kinds it is built as |
| `game/genes/kinds.gd` | the nine kinds as data (§7): each parameter's default, range or values, and whether it is structural; each kind's seat and its mark as shipped; the four accents. `resolved()` fills a look's defaults in, `signature()` is what makes it its own organ, `faults()` is what the probe reports |
| the organ files | `family`, and a `look` of a kind and its parameters (§6). No colour |
| `game/genes/catalogue.gd` | every look resolved once (`look()`), `family_of()`, `hue_of()` (its family's shade), `as_shipped()`, and `VARIANT_WORDS` among a key's words |
| `game/vision/cilia.gd` | a generator per kind, `_kind_mat` to `_kind_organelle`, on a `Stretch`: a body's arc or a tile's dome. The fringe, the tile and the hole's ghost dispatch by kind. `UNKNOWN_TINT`, `ACCENT_BEAD_MIN`, `draw_accent()`, `accent_of()`, `tile_bounds()` |
| `game/perception/signal_bus.gd` | `LIGHT_COLOR`, light's own amber; `BEAM_COLOR` and `PING_COLOR`, the hue of the organ on the channel; `STRAIN_COLORS`, the delivering organ's; `CHANNEL_LOBES`, the lobe each channel lights |
| `game/normal/figure.gd` | the accent in a chip's first lobe and before a waiting gene's word; `explain_name()`, `organ · variant`, for the pause screen and a cell's detailed view alike |
| `tools/gene_probe.gd` | §8's checks |
| `tools/looks_sheet.tscn`, `tools/looks_specimens.gd`, `tools/drive.gd --specimens=1` | the specimen sheet, and the variants and spare organs it files to be photographed |

**A body's own organs are drawn as they were**, in their family's colours. The home
organs' kinds were run against today's three functions, `_gather_cytostome`,
`_gather_cirrus` and `_gather_flagellum`, kept verbatim in a scratch harness: 12,000
organ poses at random headings, radii, clocks, steering and copies from 0 to 4, one
pose in seven on a mirrored canvas. Of 756,194 points, **0 differ, bit for bit**. Only
the earned organs change shape.

**What did not move**, measured on the build: the seeded run's hash with an empty
library under all three control schemes (`7397a410`); every `drop_probe` pin, the
membrane's among them (its digest is still `67a6afe687b3b316`: the membrane's pin
hashes what the cell feels, not its colours); `Wire.RULES`, which no look is part of;
`DropSave.rules()`; saves; and the words. No string was added, so the template and `fr.po` are unchanged.
`net_probe`, `net_fuzz` and `net_drop` pass, each in a network namespace of its own.

**What the probe reads today:**

| check | today |
|---|---|
| 1, 2 | 17 keys: `mat` 1, `oars` 1, `lash` 2, `tuft` 4, `lens` 1, `coil` 1, `spines` 3, `plates` 1, `organelle` 3 |
| 3 | builds in use: eating 1, moving 4, sensing 5, defending 3, metabolism 3 |
| 4 | every tile inside the 76 px tile and the line's 34 x 26 glyph box at 0.6; the tallest, the tail, 28.7 px above the tile's centre |
| 5 | no variants yet |
| 6 to 9 | the nearest two families 20.8°; self teal 38.6°, threat red 33.1°, food green 41.3°; the least lightness between two families 0.049 |
| 10 | 7 copies of a hue, each its source's |
| 11 | touch, smell, light, beam and ping, each on its lobe |

**Each check was seen failing.** Nineteen faults were planted one at a time in a
scratch copy, and the probe failed every one on the check it was planted for: a family
its kind is not built for, a look with a hue, a length out of range, a parameter its
kind has not, shade 3, two senses alike at a glance, a tile reach past its box, a
variant with no accent, a variant wearing its organ's mark, two variants with one
accent, a variant setting a length, four variants on a seat with three marks to spare
(*make a new organ*), a shade off its family's lightness, a band within 20° of
another, moving pulled toward teal, two families at one lightness, a pad copying a
colour literal, a turn provided by two families, and a channel with no lobe.

**Rendered and judged**: every frame of §9.4, from the build, at 1280x720 and
2400x1080 -- the waiting tray among them, which the mock did not shoot (`tray`, and
`trayplain` with genes as shipped) -- and the movement pads (`pads`), which neither
listed. Before is `b63e365`, whose frames are the mock's before to the pixel. Three
renders of `one` at each size differ by **0 pixels**.

| frame | 1280x720 | 2400x1080 |
|---|---|---|
| `fv`: full vision, the player and six posed cells | **pass**, and the mock's frame within 0.5 % of its pixels (the pigment's seat, below). Read by family | **pass** |
| `one_compare` (`_zoom`, `_zoomgrey`, `_zoomdeut`) | **pass**: in luminance and to a deuteranope, every organ is its own shape | **pass** |
| `sheet`, `sheet_grey`, `sheet_deut`, against `before_sheet_*` | **pass**: the seventeen tiles all differ in greyscale; to a deuteranope, moving and sensing meet in one blue and are told by the pigment, and eating, defending and metabolism meet in one yellow and are told by their builds. Before, seventeen hues on as many tufts | **pass** |
| `sheet_vari` (+ `_grey`, `_deut`): an eye ringed and keeled, a see-tuft barred, a tail with a disc, three strains, a plastid ringed, a vacuole cored | **pass**, every accent a shape in greyscale. The faintest pair is a strain's disc against its diamond beads, at true size | **pass** |
| `sheet_room` | the hook, the bent rings, the stack and the star read; the three-way tip, the barb and the four-turn coil on a tile, as §2.4 counts them. **A two-wave lash at three copies on a forward arc is a brush** (below) | the same |
| `pause` | **pass**: five colour groups, nothing moved in the layout | **pass** |
| `pausevar`: the ringed eye's chip tapped, a paralysing strain | **pass**: the ring and the diamond in their chips' first lobes; the line reads `ocellus · ringed` | **pass** |
| `tray`: a keeled eye and a paralysing strain waiting | **pass**: the accent before the word, small at this size and clear | **pass** |
| `trayplain`: genes as shipped waiting | **pass**: no accent, and every word where it was | **pass** |
| `choose` | **pass**: the strand's rungs group by family; the poison's marker is orange | **pass** |
| `flood` | **pass**, orange; the mock's frame within 0.16 % | **pass** |
| `lobes` | **unchanged to the eye**: the beam's lobe moves ΔE 0.015 and the ping's 0.039 in OKLab, the light's not at all | **unchanged** |
| `offer_plastid`, `offer_ampulla` | **pass**: the bud is the organ's tile; the ghost is a hollow lens for the plastid, and pores over a dim pigment for the ampulla | **pass** |
| `pads`, the third control scheme | **pass**: the four movement pads are one blue now, and dash's glyph is the coil's tile, a spring, smaller in its pad than the tuft it was | **pass** |

**Where it differs from the sections above, and why:**

- **A sense's pigment stays where it was**, 0.80 of the way out (`PIGMENT_SEAT`). The
  mock had moved it; nothing above asks for it, and the build keeps today's body
  exactly. It is nearly all of the 0.13 to 0.52 % of pixels by which the build's frames
  differ from the mock's.
- **The bead of the hole being tried keeps its brightening.** The mock reused the flag
  that brightens it to skip the old tuft, and its bead went dim with it.
- **The probe's shade step is 4.5° to 10°, not §8's 5° to 10°.** The eating shades of
  §1.3, written to two decimals, step 5.1° and 4.9°. The colours are the design's, and
  the check allows for their rounding.
- **Ink and width go by kind**: a `mat`, `oars` or `lash` keeps its home organ's, a
  bead-tipped spine the guard's, and every other kind an earned organ's. So a variant
  of a home organ is drawn exactly as its organ is.
- **What a tile holds**: no reach past 0.46 r, the tail's 17 px; at most three strands
  of a lash and eleven strokes of a mat; and its oars held where the knee shows.
- **On the tray**, the accent is 3.6 px before the word, as on the chip, and moves the
  word along by its width. A gene as shipped moves nothing.
- **A variant with no word of its own is named by its variant's name**, so the line
  never reads `organ · ` and nothing. The probe asks every variant for its word.
- **`LIGHT_COLOR` is a constant.** `stigma` is violet now, and the light lobe stays
  light's amber whichever organ drives it. `CHANNEL_LOBES` is the map check 11 reads.

**Cost** (§9.2), measured here and not on a phone. The same command on both trees,
interleaved, four rounds, with other work on the machine: 52 bodies a frame through
`draw_cell` at full vision's radii -- born cells wearing an earned organ, drifters,
peers wearing four to seven genes at one to three copies, the toxin in both forms, and
five bodies with every slot full at three copies -- timed over 240 frames after 60.

| `_draw` for 52 bodies, ms a frame | before | phase 6 |
|---|---|---|
| p10 | 21.3 to 21.5 | 24.4 to 25.2, **+15 %** |
| p50 | 23.4 to 24.6 | 27.3 to 28.8, **+15 %** |
| p90 | 34.8 to 36.9 | 39.6 to 42.9 |

The whole frame, which llvmpipe rasterises on this machine's CPU, did not move beyond
its noise (p50 152 to 167 ms before, 153 to 168 after).

**As first built it was +26 %.** The home organs' kinds asked the skin for each
stroke's point, normal and lean in three calls, seventeen lookups of the skin's fields
by name among them, where today's functions had them as arguments; they took up to
twice as long to build. Now one call a stroke reads them from locals (`_frame_on`), with
the same arithmetic -- the frames shot before and after the change are identical to the
pixel -- and a home organ builds within a few microseconds of today's. What is left is
a few microseconds an organ of dispatch, and the organs that draw more than a tuft did.
By body, the least of 50 samples of 30 bodies each, µs:

| body, or what an earned organ adds to a born one | before | phase 6 |
|---|---|---|
| a drifter: oars and a tail | 195 | 235 |
| a born cell: mouth, oars, tail | 227 | 249 |
| the same at three copies | 308 | 331 |
| a sense, one copy or three: a plain tuft, a lens, forks, ring tips, feelers | 62 to 80 | 111 to 184 |
| plates | 48 to 74 | 120 to 133 |
| an organelle, one copy / three | 72 to 83 / 65 to 75 | 42 to 74 / 117 to 173 |
| darts, the whip, the spring | 67 to 77 | 47 to 57 |
| the toxin's barbs; its poison inside | 36 to 64; 144 to 217 | 53 to 78; 157 to 191 |
| every slot full at three copies | 776 | 944 |

**What to watch on the phone**: the dev app's frame readout, its `dropped` row, in
full vision with a crowded water in view, against the build before this one. A phone's
GPU also pays for each antialiased polyline and polygon, which llvmpipe cannot show:
ring tips, lenses, plates and organelles are outlines and fills where a tuft was
strokes. If it drops frames, the levers are fewer steps in those outlines
(`ORGANELLE_STEPS` 18, a ring tip's 13 points, `LENS_STEPS` 10), the dispatch, and
leaving a body a few pixels across its family colours without its kinds' details.

**Left open, besides §11:**

1. **A tail's variant worn on a forward arc is a brush**: a lash on 24 to 28° of skin
   is six strands close together. The sheet seats a home organ's variant on its organ's
   home arc, as the mock did; where the game seats one is phase 5's variants and the
   body plan's.
2. **The movement pads are one colour.** Each was its organ's hue; they are told apart
   by place and glyph, which they always were.
