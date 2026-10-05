# Genes as data: one home for every gene, one plan for the slots

The owner, 2026-10-04, after the readiness review (§0):

> "for 1, There will be new organs. but also variants. At any moment of the life of
> the game, we could add a new gene and/or variant
> ok for the other 2
>
> Keep in mind we may change slot number, slot positions, slot types, etc. later. So
> we'd better make it easy to work on today than later"

> "You will prepare the code for the gene pass. THe gene pass is just adding/editing
> genes, so it should be straightforward"

**Status: phases 1a, 1b, 2 and 3 built** (§15.1 to §15.4, 2026-10-05); phases 4 to 7
designed, not built.
This document is the preparation. It turns the
genes, their variants and the slots into data that every system reads, adds the checks
that catch a half-wired gene, and writes the playbook the gene pass follows. Phases 1
to 5 (§15) change nothing a player can see or feel, and each proves it (§14). Phases 6
and 7 build the owner's rows 2 and 3, which players do see.

**What it replaces.** Where these say otherwise, this document wins:

- `genes-and-cilia.md` §4.4, the hue rule (*"≥30° from every other gene hue"*): genes
  are coloured by family (row 2; phase 6);
- `genes-and-cilia.md` §3.4 and `ocean.md` §13, where a gene's weight in the water is
  a constant in `food.gd`: it is the gene's own (§9);
- `dna-slots.md` §2.5, §3.1 and §8.3, where `FORMS` is the toxin's table: every gene
  has forms and variants the same way (§6);
- `wire.gd`'s rule under `PROTOCOL` (*"any content change to `cell.gd`'s
  `GAPE_BY_TIER`, … must bump this number"*): a fingerprint carried on the handshake
  does it (§11.3, phase 4).

---

## 0. Why: the readiness review, 2026-10-04

The owner asked whether the way genes work could take a gene pass that grows the game
from 17 genes towards 100 or more. Four audits read the code: the gene model, the
water, the wire with the referee and the saves, and the screens with the senses.

**What already holds.** A genome is `{name: copies}` everywhere: in saves, on the
wire, in the replay and in every water cell. A name a build does not know is kept and
drawn, never dropped. Message sizes depend on the nine genes a cell can carry, never on
how many genes exist. Copies, expression, mutation, placing, moving, levels and the
inside/outside forms are written once, for any gene. No screen lists more than one
cell's genes.

**What does not.**

1. **A gene has no home.** One gene is spread over 10 to 30 places: `GENE_ORDER`,
   `FORMS`, `NAMES`, `DECLARES` and five word tables in `genome.gd`; its tier tables,
   an accessor with its name in it and `LEVELLED` in `cell.gd`; `HUES`,
   `EARNED_COUNT` and the tile tables in `cilia.gd`; `GENE_WEIGHTS`, `DRIFTER_GENES`,
   `SENSE_GENES`, `_refresh_body`, `_eye_of` and `_derive_person` in `food.gd`;
   `FIRST_SENSES` in `normal_mode.gd` and again in `referee.gd`; `TOXIN` in `drop.gd`;
   colour copies in `signal_bus.gd`; `WORDS` and `EXPLAINS` in `figure.gd`; a `match`
   branch in `gene_stats.gd`; and lists in five probes. Phase 5's twelve genes touched
   17 files before there was any wire, referee, save, stats screen, translation or
   instinct. The toxin touched 34. Renaming one gene touched 23.
2. **A half-wired gene ships with CI green.** Every table falls back without a word:
   an indigo hue, four strokes on the body and five on the tile, the raw key as its
   name, no stats line (`levels_probe.gd` asserts that as correct), no effect while it
   still costs upkeep, English only. A name longer than 16 letters, or with anything
   but `a-z`, works alone and vanishes in a shared pond.
3. **Genes look alike already.** Hue gaps of 3.2° (palp, crista), 6.3° (stigma,
   plastid) and 7.8° (flagellum, trichocyst); ocellus and trichocyst are both violet
   with three strokes, and `figure.gd` writes the word to tell them apart. About 15 to
   20 genes can be told apart at a glance.
4. **The referee is tuned by hand to today's genes**: its speed and turn caps (about
   17% and 5% headroom), the one organ that may call (`ampulla`), the gift's four
   senses. `Wire.RULES` lists its tables by hand. A new faster organ gets an honest
   guest cut and barred for a minute, and nothing forces the protocol bump.
5. **The water dilutes**: new genes enter at a default weight of 1, and drift draws
   evenly from every gene.
6. **Ceilings**: one bit per declaring gene in a 63-bit `int` (`rulebook.gd`, eleven
   used); `drop_probe` starts its census at a literal 99; the membrane has six lobes,
   all taken.

---

## 1. The owner's answers

| # | Question | Answer, 2026-10-04 |
|---|---|---|
| 1 | Where do most new genes come from? | **Both**: "There will be new organs. but also variants. At any moment of the life of the game, we could add a new gene and/or variant." |
| 2 | How does a player tell 100 genes apart? | **As recommended**: colour shows the family (moving, sensing, eating, defending, inside), shape shows the organ, the pause screen names the exact gene. |
| 3 | How does the water carry them? | **As recommended**: common and rare genes, rare ones scarce, and later tied to places. |
| — | Slots | "we may change slot number, slot positions, slot types, etc. later. So we'd better make it easy to work on today than later" |
| — | The gene pass | "The gene pass is just adding/editing genes, so it should be straightforward" |

**What row 1 means for this design.** A gene can arrive in any content update, for the
life of the game, as a new organ or as a variant of one. So adding one must not need a
binary, a hand-edited list elsewhere, a remembered protocol bump or a migration. And a
build that does not know it yet must behave as it does today: keep it, draw it, and
let it do nothing.

---

## 2. Done means

When phases 1 to 5 have landed:

1. **A variant is one entry** in its organ's file, plus its words in `fr.po`.
2. **An organ that works through mechanics the game already has is one file**, plus
   one line in the catalogue's index, plus its words in `fr.po`.
3. **An organ with a new kind of mechanic** adds that mechanic's code (game/mechanics,
   names at the edges) and its file. Nothing else names it.
4. **Editing a gene's numbers, look or words is an edit to its file.** If the referee
   judges a number it changed, the handshake refuses mismatched builds by itself (§11).
5. **Changing the slots** (how many, where, what kind) is an edit to one file. Saves
   written under the old plan load under the new one and lose no gene (§10).
6. **CI fails, and says what is missing,** when a gene lacks anything a player or
   another system needs (§12).
7. **No file outside `game/genes/` names a gene**, except tests (§12.2).
8. **A playbook** (`game/genes/README.md`) and a project skill (`.claude/skills/gene/`)
   walk the gene pass through adding, editing and retiring (§16).

---

## 3. Words used here

- **Organ**: what a gene builds. One look, one mechanic, one set of numbers, one place
  in the water. `flagellum`, the toxin.
- **Variant**: an organ built differently: the same look and mechanic, its own numbers,
  its own name and its own place in the water. The toxin's strains are variants; so
  would be a faster tail. A variant inherits everything from its organ that it does
  not set itself.
- **Form**: a variant in one place. The toxin's corrosive strain is `toxicyst` outside
  and `veneneux` inside. A variant with one place has one form.
- **Key**: the permanent name of one form: what the DNA, the body, the wire, saves and
  the replay hold. `{key: copies}` is a genome. A gene with one variant and one place
  has one key, its organ's name.
- **Variety**: a variant's first form, the name it goes by where no place is known yet
  (drift, the floor, two meals found to be one). Today's `variety()`.
- **Place**: a slot type. Today `outside` and `inside`.
- **Anatomy**: where on the body an outside slot is: `front`, `side`, `stern`. Today's
  `FRONT` and `STERN`.
- **Stat**: a number a mechanic reads off a body, by name, with no gene in it:
  `turn_rate`, `armor`, `ping_range`. A gene **provides** stats.
- **Mechanic**: code that does something with stats: steering, the beam, the ping, a
  dose. It knows stats and never genes.
- **Tag**: a fact about a gene other systems ask: `sense`, `gift`, `drifter`,
  `always_expressed`.
- **Family**: the group a gene's colour comes from (row 2): moving, sensing, eating,
  defending, inside.
- **Body plan**: the slots: how many, where each sits on the body, what kind each is,
  when each is earned.

---

## 4. The catalogue

### 4.1 Files

```
game/genes/
  README.md          the playbook (§16)
  gene.gd            the shape of one organ: every field, its default, what it means
  catalogue.gd       the index: one preload per organ file, and every question asked
                     of a gene by key
  stats.gd           the stats: name, value with no provider, which way is better,
                     how several providers combine, unit, whether the referee judges it
  body_plan.gd       the slots (§10)
  families.gd        the families and their colours (row 2; phase 6)
  organs/<organ>.gd  one file per organ, holding its variants and forms
```

**One file per organ, and an explicit index.** The index preloads each organ file by
path, one line each. An exported pack cannot be listed reliably, and an index makes the
order of arrival visible in review. The gene probe lists the folder in CI and fails on a
file the index lacks, or an index line with no file.

**No `class_name`**, for the reason `signal_bus.gd` gives. Everything is preloaded by
path.

**The organ files preload nothing from `game/normal`, `game/net`, `game/vision` or
`game/perception`.** `genome.gd`, `cell.gd`, `cilia.gd`, `food.gd`, the referee and the
screens all preload the catalogue, so anything the catalogue preloaded back would be
the cycle `cell.gd` already warns about. An organ's hooks (§8.4) take what they need as
arguments.

### 4.2 One organ's file

Fields, with today's `pellicle` as the example. The builder settles exact names and
types in `gene.gd`. The rules are: one entry per fact, a default for every field that
has a sensible one, and a comment on every field saying who reads it.

```gdscript
extends "res://game/genes/gene.gd"

func _init() -> void:
	organ = &"pellicle"                      # also its key while it has one form
	order = 11                               # its place in GENE_ORDER: append-only
	family = &"defending"                    # row 2 (phase 6); colour comes from here
	look = {"shape": &"tuft", "strokes": 7, "hue": Color(0.36, 0.88, 0.96)}
	provides = {&"armor": [1.0, 1.14, 1.30, 1.52]}     # stat -> by tier, [0] = absent
	water = {"weight": 2, "drifter": true}   # §9
	tags = []
	# TRANSLATORS notes live with the words, as they do today.
	word = "armor"                           # the chip on the body and tile
	explains = "..."                         # the line on the pause screen
```

A gene with variants or places lists them:

```gdscript
	variants = [
		# The first variant is the organ as it shipped. Its first form is its variety.
		{"variant": &"corrosive", "dose": &"harm",
			"forms": {&"inside": &"veneneux", &"outside": &"toxicyst"}},
		# phase 3 of dna-slots.md would add, as data:
		# {"variant": &"paralysing", "dose": &"paralysis",
		#  "forms": {&"inside": &"paraneux", &"outside": &"paracyst"},
		#  "look": {"hue": ...}, "water": {"weight": 1}, "word": ...},
	]
```

A form row can set anything its variant sets. A variant can set anything its organ
sets. The catalogue resolves the inheritance once, when it loads, into one flat record
per key. Every reader asks about a key and never walks the inheritance itself.

### 4.3 What the catalogue answers

Every question any file asks of a gene by name today, by key:

- **identity**: `known(key)`, `organ_of(key)`, `variant_of(key)`, `place_of(key)`,
  `variety(key)`, `forms_of(key)`, `form_in(key, place)`, `has_forms(key)`, `rank(key)`
  (from `order`), `keys()` in order (today's `GENE_ORDER`, with retired keys kept
  known), and `live()` without them;
- **numbers**: `table(key, stat)`, `providers(stat)`, and the stats layer (§5);
- **tags**: `tagged(tag)` and `has_tag(key, tag)` -- not `is`, which is a GDScript
  keyword;
- **look**, **words** and **water** (§7, §8, §9).

Lookups are dictionaries built once when the catalogue loads. Nothing per frame walks
the whole catalogue. `dominant_of` keeps today's tie-break (the order) through `rank`,
an O(genes worn) loop instead of today's O(every gene) scan. That scan costs 18 µs per
drawn body at 117 genes, against 4 µs at 17, measured on desktop.

The answer must be exactly today's, unknown keys included:

- a key with a place in the order beats one without at the same tier: a key this
  build does not know, or a retired one, which has none (§4.4) -- `rhabdom` and
  `statocyst` were outside `GENE_ORDER` before the catalogue, and lost ties then;
- keys without a place tie-break among themselves in the genome's dictionary order.

**Tools can register a gene** (`register()` and `forget()`), as `food.gd`'s
`declare()` already lets `drop_probe` check 8 declare a part. That is how the probes
put a synthetic gene through every system (§12.3). The game never calls it.

### 4.4 Invariants

1. **A key is permanent once shipped**: saves and the wire keep it. It is 1 to 16
   letters `a-z` (`Wire.NAME_MAX`, `_name_ok`). Real organelle names longer than that
   are shortened in the key. The name on screen is the gene's word and the organ's
   name (§8), not the key.
2. **`order` is append-only**: it is the tie-break of `dominant_of`, so changing an
   existing pair's order changes what a body is drawn as and what eating it gives. A
   new gene takes the next number.
3. **A retired gene stays in the catalogue**, tagged `retired`: known, drawn and
   inert. It drops out of every pool that produces genes: the water, drift, the gift.
   `rhabdom` and `statocyst` become entries so tagged. Today they are only absences
   that comments explain. **A retired gene has no place in the order** (`order` -1, no
   `rank`), so `dominant_of` ranks it as it ranks a key it does not know, as it always
   has. A gene retired after this keeps the place it shipped with.
4. **Nothing is silently defaulted that a player sees.** A field with no sensible
   default (look, word, explains, stats lines) is required, and the probe fails
   without it (§12).

---

## 5. Stats and mechanics

### 5.1 The stat table

`stats.gd` holds one row per stat:

- its **name**;
- its **value with no provider**: `turn_rate` 0.48, `armor` 1.0, `smell_range` 0.0.
  That is today's index 0 of every tier table, which means *"does not have this
  organ"*;
- **which way is better** (higher or lower);
- **how several providers combine**: best, sum or product;
- its **unit**, for the stats screen;
- **whether the referee judges it** (§11).

Today's tier tables become stats of their organs, **named after the constants they
were**: `TURN_RATE_BY_TIER` is `turn_rate`, `ARMOR_BY_TIER` is `armor`. The
fingerprints that list them (§14) can then write exactly the lines they write today.
The tables are:

- `gape`, `bite`;
- `impulse_speed`, `impulse_gap_min`, `impulse_gap_max`;
- `turn_rate`, `turn_response`;
- `beam_range`, `beam_count`, `beam_fan_deg`;
- `smell_range`;
- `ping_range`, `ping_period`, `ping_through`;
- `push_accel`, `dash_speed`, `dash_cost`;
- `armor`, `store`, `burn`, `sun`, `touch_range`;
- `dart_range`, `dart_cooldown`;
- `venom_stacks`, `poison_stacks`, `swallow_stacks`.

`HOLD_LEVEL`, the beam's fork, paths and experience, and `DART_STUN` stay with their
organs as the organ's own numbers.

**Tables a mechanic indexes by an organ's tier stay with the mechanic**:

- in `food.gd`, `PING_RETURNS_BY_TIER`, `PING_WIDTH_FLOOR` and `PING_WIDTH_GAIN`;
- in `signal_bus.gd`, `THRUST_PEAK_BY_TIER`, `THRUST_HALFWIDTH_BY_TIER`,
  `SHEAR_PEAK_BY_TIER`, `INGEST_DECAY_BY_TIER`, `PING_HOLLOW_BY_TIER`,
  `LIGHT_HALFWIDTH_DEG` and `BEAM_HALFWIDTH_DEG`.

Each is read at the tier of whichever organ provides the stat it belongs to, found by
the stat, not by name. A variant changes what an organ does, not how a channel feels
or how finely a ping resolves. If the gene pass ever wants that, the table moves into
the organ then.

**A stat a body has** is its providers' values at the tiers it wears, combined. With
none, it is the stat's value with no provider. Today every stat has exactly one
provider, so every combine rule gives today's number. The rule only starts to matter
when the gene pass adds a second provider of a stat, and it is set in that stat's row.

### 5.2 Mechanics read stats, never genes

`cell.gd`'s `turn_rate()` becomes the body's `turn_rate`, through the stats layer.
`food.gd`'s `_refresh_body`, `_eye_of` and `_derive_person` fill a body's fields from
stats in a loop, instead of fifteen hand-written lines with gene names in them.
`upkeep_of` reads `burn` as a stat, so `crista`'s name leaves the arithmetic.
`levelled_upkeep` asks the organ for its price instead of `match`ing on `ocellus`.

**Where a mechanic needs the organ itself**, not a number, it asks by tag or stat,
never by name:

- which slot the beam leaves from is where the provider of `beam_range` is worn;
- the mouth is the provider of `gape`;
- the ping is the provider of `ping_range`.

**One instance per mechanic, for now.** If a body wears two providers of a stat that
belongs to an organ with a position (two eyes, two pings), the mechanic acts from the
first one in the catalogue's order (`worn_provider`), and the stat combines as its row
says. Slot order would need the layout at every read; the catalogue's is fixed. A mechanic that should
act from every provider (a beam per eye) is the gene pass's code to write, in that
mechanic, when an organ needs it.

**As built in phase 3** (§15.4), it is the first **in slot order**: a body with two
eyes casts from the one in the lower slot. Slot order no longer needs the layout at
every read, because each of these is read once a body -- the cell's by
`body_version`, a water body's when its genome is written. `stats.gd`'s `SEATED` names the stats whose
mechanic has a place: `beam_range`, `ping_range`, `dart_range` and `smell_range`.
Everything such a mechanic reads off its organ is that organ's: its arc, its tier, its
level and path, its fork, its experience cap, its dart's stun. The mouth, the tail's
level and hold and the dash have no place to act from, and act from the first in the
catalogue's order, as before. `Stats.organ` answers which, for any stat.

### 5.3 Levels

`LEVELLED` becomes the organ's `levels` field: step, fork level and paths. The beam's
price per level stays the beam's (its `upkeep_at` hook). `Progression` already knows no
gene. `level_of` keeps answering the worn tier for a gene that does not level.

---

## 6. Variants and forms

### 6.1 Generalising what the toxin already does

Today `FORMS` maps form to `[gene, strain, place]`, and only the toxin has rows. Every
rule in `genome.gd` that reads it is already generic:

- the variety;
- two meals of one variety being one sample;
- a sample that waits even when carried;
- a placement taking the form of its slot's place;
- a move converting across places;
- the lapse trying each form;
- drift drawing the variety and taking its form from the slot.

**Every key gets that row now**: `[organ, variant, place]`, resolved by the catalogue
from the organ's file. A gene with one variant and one place answers exactly what
`FORMS` answers for a gene absent from it today: its own organ, no variant, outside,
and itself as its variety.

`has_forms(key)` stays true exactly when its variant has more than one place. That is
the toxin's two forms today, so placing, lapsing and moving behave as before.

**Different variants of one organ are different varieties**, as the toxin's strains
were designed (`dna-slots.md` §8.1):

- they are separate samples, separate loci, each with its own copies;
- a meal gives the prey's dominant form, variant and all;
- a daughter inherits it with its slot and its copies.

**Drift draws an organ first, then its variant by weight**, then its form by the slot,
as `dna-slots.md` §8.3 already settled for the toxin: *"The toxin counts as one gene
wherever the water counts genes."* With one variant per organ, that is today's draw.

### 6.2 What a variant may change

A variant may set anything its organ sets except the mechanic:

- its numbers (`provides`, each table whole);
- its look (an accent; phase 6 settles which part of the look a variant changes);
- its words;
- its weight in the water;
- its tags, **added to its organ's**, never in place of them -- so a strain of the
  toxin that sets one still has `not_on_drifters` and `floor_by_peers` (§6.4);
- its dose (for the toxin).

**A variant of one place needs no `forms`**: it is one form, outside, keyed by its own
`key` or, without one, by its name. A faster tail is one entry, `{"variant": &"swift",
"key": &"swiftail", "provides": {...}}`.

The organ owns its mechanic, its shape and its family, so a variant reads as its organ
at a glance and names itself on the pause screen (row 2).

### 6.3 One variant per body: a switch, off

An organ may say `one_variant = true`: placing a second variant of it writes over the
first, as the inside's one poison does today. It is off for every organ today,
because nothing today can carry two. It is a switch the gene pass sets per organ when
it adds variants. The default and the reasoning are the gene pass's call, not this
document's.

**As built** (§15.4): placing or integrating a variant of such an organ writes over
every other variant of it in the DNA, in both its places, and empties their slots; the
body keeps what it wears until a birth, as with any gene written over. Drift brings no
variant of such an organ to a lineage that carries one. The gene probe switches it on
for an organ of its own and shows both.

### 6.4 What the toxin's special cases become

`Drop.TOXIN`, `take_drifter_gene`, `drifter_genes`, `give_toxin`, `_toxin_short`,
`_give_toxin_back` and `toxins_of` assume one toxin. They become tags on the organ,
which every variant inherits:

- `not_on_drifters`: drifters never carry it, so they stay defenceless food
  (`ocean.md` §5.8);
- `floor_by_peers`: the floor gives it back through peers.

A second strain is then a variant entry, and every one of these rules covers it.

**As built** (§15.4): `toxin.gd` carries both tags, and `drop.gd` and `food.gd` ask for
them. `give_toxin` is `give_back(tiers, gene, ...)`: the coin picks the gene's inside
or outside form, and a strain of one place takes the one it has. `toxins_of` reads any
key with a dose, whatever its places. A strain's lines say what a stack of its own
dose does (`gene.gd`'s `dose_line`), and the gene probe fails a live strain whose
kind has no line, and a venom without its side and stern words -- the 1b review's
finding 4. The probe files a second strain of one place and shows every rule above
covering it.

---

## 7. Looks

### 7.1 Today's looks, as data (phase 1)

Each organ's `look` holds what `cilia.gd` keys by name today:

- its **hue**;
- its **shape**:
  - `mat` (the mouth);
  - `oars` (the cirrus: mirrored on both lateral arcs from one slot);
  - `lash` (the tail);
  - `tuft` with a stroke count (every earned organ);
  - `fangs`, `guard` and `granules` (the toxin's forms, by place and anatomy);
- its **tile** counts and lengths, and whether it wears a **pigment**;
- the ocellus's **bud**.

`cilia.gd` draws by shape and never by name. `default_order` seats each organ in its
`home` slot (§10) instead of naming the three home organs.

**As built in 1b** (§15.2): the toxin's three are one shape, `spines`, drawn by place,
as `gene-looks.md` §2.1 has it; the pigment is the shape's and the bud the levelled
organ's state, so neither is a field; and `default_order` names the home organs until
phase 2 gives each its `home`.

`vision.gd`'s beams and ping, and `returns.gd`'s pointers and wave, read their hue from
the catalogue by mechanic. `signal_bus.gd`'s colour copies (`LIGHT_COLOR`,
`BEAM_COLOR`, `PING_COLOR`, `STRAIN_COLORS`) become reads of the catalogue. If the bus
must keep a copy, the probe checks every copy against its source.

### 7.2 Families and the shape vocabulary (phase 6; row 2)

`families.gd` gives each family a band of the wheel. A gene's hue becomes its family's
colour, shaded within the band, so several genes of one family may share a hue and
are told apart by shape. The **shape vocabulary** grows past one tuft, so that a new
organ picks a shape and its parameters as data rather than needing a new drawing.

Phase 6 is a design by the UX designer before any code: the family bands, the shades,
the new shapes, the membrane's colours, and today's 17 genes recoloured. It is
rendered at 1280x720 and 2400x1080 and judged before it is built. It is the one part
of this work a player sees on the body.

### 7.3 The membrane

Each sense organ names the **channel** it drives: `light`, `beam`, `ping`, `smell`,
`touch`. A sense on an existing channel (a variant of the nose, a second eye-spot) is
then data. **The field arrived in phase 1a**, not with the looks: the eye-spot provides
no stat, so the water's shade and the membrane's eye-spot lobe find it by its channel
(`worn_on(tiers, &"light")`), and nothing else could have found it but its name.

**A new channel is code**: a lobe in `signal_bus.gd`, the shader's arrays and the
replay's block. All six lobes are taken today. So the first organ that needs a new
channel brings a lobe design with it. This document does not pretend otherwise.

---

## 8. Words

### 8.1 What an organ says

The words move from where they are today into the organ's file, each with its
TRANSLATORS note:

| Word | Today in |
|---|---|
| its **name on screen** | `NAMES` |
| its **chip word** | `figure.gd`'s `WORDS` |
| its **explains** line, with side, stern and path forms | `EXPLAINS` and the side, stern and path tables |
| the words of every part it declares to the instincts | `DECLARES`, `GENE_SAYS`, `GENE_SENSES`, `GENE_EXPLAINS`, `GENE_ASLEEP`, `GENE_NEEDS` |

A variant has its own name and may override any word.

### 8.2 The translation tool

`tools/i18n_pot.gd` already extracts any constant with a `TRANSLATORS:` note under
`game/`, so the organ files are found. What changes:

- its fill tables (`WORDS`), its walk over `GENE_ORDER` and its body sweep read the
  catalogue;
- the `.pot` is regenerated;
- `fr.po` keeps every msgid that does not change, which is all of them in phases 1
  to 5.

**As built in 1b** (§15.2): four fills read the catalogue -- the chip word, a way's
name, a sense's word and an action's -- and an organ's word tables count as named by
it, which reads them by name.

### 8.3 Missing translations

The probe lists, per gene, the words with no French. A gene fails the probe only for
words missing in English. CI keeps running the linter without `--strict`, as today:
an untranslated word still ships in English, and the gene pass sees it listed.

### 8.4 The stats lines

The stats screen's lines are per-gene code: each phrase computes its own value ("a
half turn in {} s" is π over `turn_rate`). They move into the organ's file as its
`lines(t, level, path, ctx, slot)` hook. It is called with the context `gene_stats.gd`
builds today: the scripts and stats it needs, passed in, not preloaded (§4.1).
`gene_stats.gd` keeps the readout, the upkeep line and the context, and calls the hook.

**A live gene with no lines fails the probe**, and `levels_probe.gd`'s assertion that
a gene with no row draws nothing becomes a check on a retired key.

---

## 9. The water

Each organ, or variant, carries its own entry in the water:

| Field | Was | Where |
|---|---|---|
| `water.weight` | `GENE_WEIGHTS` | `food.gd` |
| `water.drifter` | `DRIFTER_GENES` | `food.gd` |
| `tags: sense` | `SENSE_GENES` | `food.gd` |
| `tags: gift` | `FIRST_SENSES` | `normal_mode.gd` and `referee.gd` |
| `tags: always_expressed` | `ALWAYS_EXPRESSED` | `genome.gd` |
| `tags: never_drifts` | the literal `cytostome` in `_mutate_drift`, which kept the mouth out of both sides of a drift: never written over, never brought | `genome.gd` |
| `born` | `BORN`, `BORN_ORDER` | `genome.gd`, `normal_mode.gd` |

Two more rules:

- **Drift draws through the catalogue**: an even draw over every live variety that
  does not `never_drifts` and that the lineage lacks, as today. **It stays an even
  draw until phase 7**, not a weight defaulting to 1: a weighted draw takes the
  random numbers another way, so even at 1 it would move every seeded run.
- **The lists keep the order they shipped in.** The drifters are drawn by weight in
  order, the gift `randi() % 4` in order, and the rulebook gives the declaring genes
  their bits in order -- so a seeded water, a rule's bits and `Wire.RULES` all hang on
  those orders, and the catalogue's own order is not theirs. `catalogue.gd`'s
  `SHIPPED_ORDERS` pins the drifters, the senses, the gift and the declaring genes as
  they shipped; a new gene appends to the lists it joins, and the gene probe keeps its
  own copy, so a change to them fails there first.
- **`drop.gd`'s `FOUNDERS`** stay rule text in the water. They name instinct parts,
  which genes declare, and the probe checks that every part they name is declared.

**Phase 7 (row 3) builds the common and rare genes**:

- **Design first**: a systems design of how rarity drives the spawner, the floor and
  drift, with starting values and what to watch for, as `CLAUDE.md` asks.
- **Rarity is the gene's own field**, so the gene pass only sets it.
- **Places come later**: tying a rare gene to a place in the water waits for a water
  that has places. The field that will say where is reserved, empty.

---

## 10. The body plan: slots as data

### 10.1 Today's plan

`body_plan.gd` holds one row per slot. Today's are:

| index | id | place | anatomy | arc (ovoid `t`, degrees) | earned at radius | home organ |
|---|---|---|---|---|---|---|
| 0 | `nose` | outside | front | −42 … 42 | always | `cytostome` |
| 1 | `starboard` | outside | side | 66 … 118 | always | `cirrus` (its oars also draw at −118 … −66) |
| 2 | `tail` | outside | stern | 146 … 214 | always | `flagellum` |
| 3 | `fore_starboard` | outside | front | 42 … 66 | 29.5 | — |
| 4 | `fore_port` | outside | front | −66 … −42 | 33.0 | — |
| 5 | `aft_starboard` | outside | side | 118 … 146 | 36.5 | — |
| 6 | `aft_port` | outside | side | −146 … −118 | 40.0 | — |
| 7 | `inside` | inside | — | — | always | — |

**"Always" means at any radius**: a drifter of r13 has the first three, as
`slots_for`'s clamp to `SLOT_MIN` gives it today. The radii are today's ladder
(`26 + 3.5k`), written out. A count from them must equal `slots_for` at every radius,
and the probe checks it on a sweep.

**It also holds the body's shape**, because a slot's bearing is read off it:
`OVOID_ALONG`, `OVOID_ACROSS` and `OVOID_PINCH` move here from `cilia.gd`, which reads
them back.

**Ids are code only and permanent**, like keys. The player sees arcs, never ids.

### 10.2 Derived from it, never written again

- `SLOT_MIN`, `SLOT_MAX` and `slots_for(radius)`: the count of outside slots earned by
  a radius, the gift's bonus slot on top as today;
- `INSIDE`, `INSIDE_SLOTS`, `FRONT` and `STERN`;
- the arcs, `arc_for_slot` and `slot_bearing`;
- the home seats `default_order` uses;
- the pause figure's, choosing screen's and cell view's slot positions and placing
  targets;
- `Wire.ORDER_MAX` (outside slots) and `Wire.GENES_MAX` (every slot, plus one for the
  gift worn over an organ still worn).

**`DIVIDE_RADIUS` stays 40**, and the probe keeps the coupling `cell.gd` documents: the
last outside slot is earned at the divide radius.

### 10.3 Saves stamp the plan, and a new plan migrates by id

Every save that keeps a slot order writes the plan's ids beside it: a cell's file, a
world's water bodies and the daughters on offer. A save with no stamp was written under
today's plan.

On load under a different plan, each gene goes back to its slot's id. A gene whose id
is gone goes to the free slot of the same place nearest by bearing. With none free, it
stays in the DNA unseated, as a newborn's inherited layout can be today. **No gene is
ever dropped.** The body's worn layout follows the same rule. The replay is RAM only
and needs nothing.

Phase 2 builds the stamp and the migration. It proves them on a synthetic plan with a
slot added, one moved and one removed (§12.3). It changes no plan.

**As built** (§15.3): the stamp is `plan`, beside a genome's `order` and `worn` -- so a
cell's file and a cell a world kept before slots carry it alike -- and beside each
daughter's `order`. A world's water bodies keep no slot order, so they have nothing to
stamp: each is laid out by `default_order`, which reads the plan in use. A gene whose
slot is gone takes the nearest free outside slot whatever its index; an id this build
never knew, a later plan's, takes the first free one; a gene kept at an inside slot is
left to the DNA, which says what is inside.

### 10.4 What a plan change costs later

It is an edit to `body_plan.gd`. Saves migrate by §10.3. The wire's limits follow it.
The handshake fingerprint (§11.3) includes the plan, so two builds on different plans
refuse each other with the version sentence instead of misreading each other's slot
orders.

The pause figure and the placing gesture follow the arcs. A plan with more slots than
the figure has room for fails the probe's layout check rather than overlapping in
silence.

**As built** (§15.3), a plan change also moves the gene probe's pins of the plan that
shipped, in the same commit, as a new gene appends to `SHIPPED`; and it moves
`Wire.PROTOCOL` by hand until phase 4 puts the fingerprint on the handshake. A plan that
seats the port flank takes the ring's one empty cell, which the pause screen's columns
are shaped round. And a plan with fewer outside slots than a saved DNA has genes outside
needs one more change first (§15.3).

---

## 11. The referee and the wire

### 11.1 What the referee reads

- **The gift's senses**: the catalogue's `gift` tag. Today they are a copy that has to
  match `normal_mode.gd`'s.
- **Who may call**: the providers of `ping_range`. Today only `ampulla`.
- **What a person is in the host's water**: `_derive_person`, from stats (§5.2).

### 11.2 The caps stay explicit, and CI checks them against every gene

`MOVE_RATE` and `TURN_RATE` stay written constants with their reasoning. The probe's
`_referee_agrees` today sums the impulse, push and dash of three named tables. It will
instead compute the peak speed and turn from **every provider** of the judged motion
stats in the catalogue. A gene that would push the peak past a cap's headroom fails CI
with the sentence: raise the cap, which changes the rules. **Done in phase 1a**
(§15.1): `_stacked_peak`, over `stats.gd`'s `top`.

### 11.3 The rules fingerprint goes on the handshake (phase 4)

`Wire.RULES` is the fingerprint of what the referee judges by. From phase 4:

- **It is generated from the catalogue**: every judged stat of every key, plus the
  referee's own limits and today's other lines. A new judged table is in it without
  anyone listing it. (Phase 1a already writes every provider of each judged stat,
  the first under the line it always had and any other as `label.key`, and fails a
  row marked judged whose lines are missing; what is left is the generating.)
- **It is carried on HELLO and WELCOME**, in the 64-byte tail `wire.gd` reserved for
  it (the ladder hash `shared-pond.md` §7 planned). It is joined with the body plan's
  fingerprint and the contact tables: gape, armour, bite and doses.
- **Two builds whose fingerprints differ refuse each other at the handshake**, with
  the sentence that names the update. A gene added "at any moment" that changes what
  the referee judges then never cuts an honest friend, and nobody has to remember to
  bump anything.

**`PROTOCOL` becomes 8 once, for the new tail**, and from then on moves only when a
message's format changes. `wire.gd`'s hand rule about contact tables is replaced by
the fingerprint.

**What does not split builds**: a gene that changes nothing judged, such as a sense,
the stats screen or a look, is not in the fingerprint. An older host keeps it as a
name, draws it and lets it do nothing, as today.

### 11.4 Version skew, checked

net_probe gains a check for each of these:

- a guest on a catalogue with one more judged gene is refused at the handshake;
- a guest with one more unjudged gene plays, and that gene arrives intact by name;
- a name the wire would refuse cannot be in the catalogue (§12).

---

## 12. Checks

### 12.1 The gene probe (`tools/gene_probe.gd`, in CI, static, seconds)

For every key:

- its name passes the wire's `_name_ok`;
- it is unique;
- every shipped key and its order are still there: the probe keeps the list of shipped
  keys, and a new gene appends to it.

For every live gene:

- **look**: a valid shape, a hue, strokes where its shape counts them;
- **words**: a chip word, an explains line, words for every part it declares;
- **stats screen**: lines;
- **water**: a weight;
- **sense genes**: a channel;
- **declared parts**: a reader in the water and on the player's side, and a trigger
  for every output.

For every stat table:

- `TIER_MAX + 1` entries;
- index 0 equal to the stat's value with no provider;
- finite.

Colours: no new gene within today's floor of a colour already taken (pairs that
already break it are listed and kept until phase 6), nor within 25° of self teal or
threat red. From phase 6, the family rules replace both.

The body plan:

- unique ids;
- outside arcs that do not overlap;
- radii that only rise;
- the last outside slot earned at `DIVIDE_RADIUS`;
- the wire's limits at least the plan's;
- room on the pause figure for every slot.

Cross-checks:

- every `FOUNDERS` part is declared;
- every gift gene is a sense;
- every copy of a colour matches its source.

**v1, as built in phase 1a** (§15.1), checks what the numbers and rules need: the keys
(the wire's `_name_ok`, each once, the shipped keys in their places and the two retired
before the catalogue, live ones the shipped less any retired; organ names their own,
and variant names within an organ); the index against the folder; every tag and
channel of every key as filed, and every place and field a variant or form sets; the
water (a weight for every live variety, the drifters, a channel for every sense, the
gift a sense, the born cell) and each list a draw or a bit reads, whole and in the order
it shipped; every table and every row, and a provider for every stat -- live, or only
retired ones, which a NOTE names; the founders' parts declared, and every part a gene
declares read or performed by a water cell and by the player's; what each mechanic
asks of the organ it finds by stat -- every stat of the groups a mechanic reads
together (a call's reach, period and through; a stroke's speed and two gaps; a turn's
rate and response; a dash's burst and price; a dart's reach and rest; a beam's reach,
rays and fan), the tail's hold level, the dart's stun, the beam's shape, experience
and price, the levels; and organs registered and forgotten end to end -- forms and
their stats read at once, tags that add up, variants of no forms, an organ that calls
with no period (caught, and the referee still holding it to a rate), a part nothing
wires. It prints how many gene names are left in `game/`, `&"<key>"` and `"<key>"`.
**The look, word, stats-line and colour checks are phase 1b's; the body plan's are
phase 2's.**

**v2, as built in phase 1b** (§15.2), adds them: every live gene's look (a shape there
is, a hue, its strokes where its shape counts them, a home shape's tile, nothing a look
does not hold) and none on a retired one; its chip word and line, its words in hand
where it has forms and every way's where it forks, and every declared part's word, line
and, waiting for a level, what it says, with no word table keyed by what is not its
organ's; its numbers on the pause screen at every copy count, level, way and slot, and
none from a retired key or an unknown one; no two hues nearer than today's floor, 10° of
HSV hue, and none within 25° of self teal or threat red, but five pairs kept until phase
6 (`palp` and `crista`, `stigma` and `plastid`, `flagellum` and `trichocyst`, `pellicle`
and teal, `myoneme` and red); every copy of a gene's hue its organ's; and a registered
organ's hue drawn at once, by the dictionaries `cilia.gd` holds. It lists the gene words
with no French (§8.3).

**v3, as built in phase 2** (§15.3), adds the body plan's: ids unique, and every id a
save before stamps kept still known; outside arcs that do not overlap; radii that only
rise, the last at `DIVIDE_RADIUS`; a home for each born organ and nothing else, always
earned; every copy of a count the plan's own; the wire's limits at least the plan's, and
`TIER_TOP` genome.gd's `TIER_MAX`; and room on the pause figure -- a cell of the ring and
a chip inside the box for every slot. Each is seen failing a plan, swapped in, that
breaks it. Today's plan is held to the one that shipped, its ladder on a sweep of
12,071 radii. And it runs the synthetic plan of §12.3. With the 1b review it also fails
a word the catalogue hands out that the template lacks, and a live chip word wider than
the choosing screen's block or a chip, in English or in French. A retired key may now
keep its look and its lines (§16).

### 12.2 No gene names outside `game/genes/`

A grep gate in CI fails on any `&"<key>"` or `"<key>"` literal for a catalogue key in
`game/` outside `game/genes/`. Comments and `tools/` are exempt. It lands in phase 5,
once nothing is left to move. Until then, the probe prints the count.

**As built in phase 3** (§15.4), as its brief asked: CI's "Check the gene names" runs
the gene probe with `-- --names`, which prints one failure for every such literal
-- its file, line and text -- and `ALL PASS` only for none. Comment lines and `tools/`
are exempt, and retired keys count. There are none.

### 12.3 Synthetic genes and plans, end to end

A probe registers a test organ with a variant and two places. It wears it, and then:

- **the genome**: integrate, place, move, express, mutate;
- **the water**: the spawner draws it, the floor counts it, drift brings it;
- **the body**: its stats reach the body, and `cilia.gd` draws it in its hue;
- **the wire**: a genome holding it goes through `_tiers_bytes` and comes back intact;
- **the save**: a cell's file holding it goes through `compose` and `read` intact;
- **the referee**: it accepts the body that wears it;
- **the words**: the stats screen has its lines.

A second run does the same with a synthetic body plan (§10.3).

**As built** (§15.3), the second run is the gene probe's, from phase 2. It swaps in a
plan with a slot moved, one retired and two added, and loads a cell kept under today's
plan from its own file, from a world's and from before stamps, and the daughters on
offer. Each gene lands in its slot by id, and nothing is lost. It then checks the
genome's rules, the venom's side, the wire's limits, the referee and the pause figure
on that plan. It loads a cell and a daughter kept under it on today's plan, and
restores today's plan whole.

**As built** (§15.4), the first run is the gene probe's too, from phase 3. Its organ, a
gland, has two variants -- a plain one inside and out, and a keen one outside alone --
with words, a look and lines, as an organ's file has them. The probe puts it through
everything above, and through its instinct part, a water cell's and yours. It switches
it to one variant a body, then forgets it, and the catalogue and the vocabulary are as
they were. Then a faster tail, one more entry in the tail's own file, and a second
strain of the toxin, one entry of one place.

---

## 13. Ceilings, lifted

- **`rulebook.gd`'s owner bits**: past 63 declaring genes and levels, the `int` mask
  becomes something without that ceiling. It must be as fast for `worn` checks and
  cover every owner today and to come. The builder chooses what.
- **`drop_probe`**: the census starts at `INF`, not 99.
- **`lineage_line`**: labels genes by key, not `left(4)`.
- **Tier clamps** read `TIER_MAX`, not a literal `3`.
- **`net_fuzz`**: draws its random genomes from the catalogue, plus invented names.
- **Wire limits**: `GENES_MAX`, `ORDER_MAX` and `TIER_TOP` are derived (§10.2), and
  the probe holds them to the constants they come from, not to literals.

---

## 14. Proving nothing changed (phases 1 to 5)

Every phase that claims no change shows, in its pull request:

1. **CI all green**, every probe `ALL PASS`, with no check removed or loosened except
   the ones §13 names.
2. **The seeded runs unchanged.** `ci.yml`'s *Check an empty library changes
   nothing* -- a seeded minute driven under each of the three control schemes --
   hashes to `7397a410…` under all three. And `drop_probe`'s pins of the seeded water,
   every one: `DEV_LINES`, `IDENTITY_LINES`, `THREE_ONE_LINES`, `PACK3_LINES`,
   `TAIL_LINES`, `DEV_MEMBRANE`, `PACK3_TRACE`, `TAIL_TRACE`, `DEV_DRAWS` and
   `DEV_MUTATIONS`. None is ever pinned again to let a phase through: one that moves
   means something changed.
3. **`Wire.RULES` unchanged** through phase 3. The generator writes the same lines from
   the catalogue, under today's labels. Phase 4 changes it on purpose (§11.3).
4. **`DropSave.rules()` unchanged**, for the same reason: the stats are named so the
   lines come out the same (§5.1). If a phase cannot keep it, the pull request shows
   the two texts differ only in labels, never in a value, and notes that every world
   logs `CONVERTED` once and is re-derived by name, which loses nothing.
5. **The same frames, pixel for pixel.** Each scene is first rendered three times with
   `--seed=` to show 0 px differ (`CLAUDE.md`), then before and after at 1280x720 and
   2400x1080:
   - full vision with a cell wearing every gene;
   - point of view;
   - the pause figure with a full genome and a waiting toxin;
   - the choosing screen;
   - a cell's detail view;
   - the instincts page;
   - the stats lines.
6. **`.pot` regenerated**, and `fr.po` unchanged except for reference comments.

---

## 15. Phases

Each phase is its own pull request into `dev`, titled `chore:` unless it says
otherwise, and lands only when §14 holds.

| Phase | What it does | Files |
|---|---|---|
| **1a. The catalogue: numbers and rules** | `game/genes/` with `gene.gd`, `catalogue.gd`, `stats.gd` and one file per organ (with `rhabdom` and `statocyst` retired). Every per-gene table, list and tag moves into it, and every read in the simulation, the water, the referee's copies and the probes goes through it (§5, §9) | `genome.gd`, `cell.gd`, `food.gd`, `drop.gd`, `metabolism.gd`, `normal_mode.gd`, `controls.gd`, `referee.gd`, `drop_save.gd`, `recorder.gd`, `replay.gd`, the probes. **The gene probe v1** lands here and runs in CI |
| **1b. The catalogue: looks and words** | Every look, colour copy, word and stats line moves into the organ files, and the translation tool reads the catalogue (§7.1, §8) | `cilia.gd`, `vision.gd`, `returns.gd`, `signal_bus.gd`, `figure.gd`, `gene_stats.gd`, `program_words.gd`, `programs_page.gd`, `tools/i18n_pot.gd`, `.pot`. The probe gains the look and word checks |
| **2. The body plan** | Slots as data, saves stamped, migration by id, wire limits derived (§10) | `body_plan.gd`, `genome.gd`, `cell.gd`, `cilia.gd`, `figure.gd`, `cell_figure.gd`, `normal_mode.gd`, `food.gd`, `wire.gd`, `referee.gd`, `cell_save.gd`, `drop_save.gd`. A synthetic plan probe |
| **3. Variants and stats for every organ** | Every key's `[organ, variant, place]` row; combine rules; mechanics bound by stat, not name; the toxin's special cases as tags; `one_variant` (§5.2, §6) | `genome.gd`, `food.gd`, `drop.gd`, `cell.gd`, the probes. The synthetic gene probe (§12.3) |
| **4. The referee and the handshake** | `RULES` generated from the catalogue; the fingerprint on HELLO and WELCOME; `PROTOCOL` 8; caps checked against every provider (§11) | `wire.gd`, `referee.gd`, `net_session.gd`, `tools/net_probe.gd`. Not a player-visible change, but it ends play between builds before and after it, as every protocol bump does |
| **5. Ceilings, the gate and the playbook** | §13, the grep gate (§12.2), `game/genes/README.md`, `.claude/skills/gene/SKILL.md` | as listed |
| **6. Families and shapes** (row 2) | UX design first (§7.2), then the build. **Visible**: titled for players | `families.gd`, `cilia.gd`, the organ files, `signal_bus.gd` |
| **7. Common and rare genes** (row 3) | Systems design first (§9), then the build. **Visible in the water**: titled for players | the organ files, `food.gd`, `drop.gd`, `genome.gd` |

**The gene pass starts after phase 5.** It can start after phase 3 for genes that need
no new look, if the owner wants it sooner. Phases 6 and 7 can be designed while 1 to 5
are built, and are built after phase 3.

### 15.1 As built: phase 1a, 2026-10-05

**`game/genes/`, and nothing a player can notice.** By file:

| file | now |
|---|---|
| `game/genes/gene.gd` **new** | one organ's shape: `organ`, `order`, `provides` (stat to its table by tier), `numbers`, `levels`, `water`, `tags`, `channel`, `born`, `declares`, `variants`; what the catalogue writes per key, `key`, `variant`, `place`, `dose`; the tags and the channels; the hook `upkeep_at` |
| `game/genes/catalogue.gd` **new** | `ORGANS`, the index, eighteen files with the two retired last; every lookup built once at load, and again by `register` and `forget`; `SHIPPED_ORDERS` (§9) |
| `game/genes/stats.gd` **new** | `ROWS`: 27 stats, each with its value with no provider, which way is better, how providers combine, its unit, and whether the referee judges it (the seven tables `Wire.RULES` lists) |
| `game/genes/organs/*.gd` **new** | sixteen organs, `toxin.gd` holding `veneneux` inside and `toxicyst` outside; `rhabdom` and `statocyst`, retired. Every table keeps the name and the comment its constant had in `cell.gd` |
| `game/normal/cell.gd` | no table: a body's numbers by stat, each read once a body (below); `gape_of`, `speed_of`, `swim_speed_of`, `swallow_radius_of`, `bite_damage`, `hold_level`, `dart_stun` and `beam_shape` take what a body wears or what its organs give |
| `game/normal/genome.gd` | no list: the born cell, drift, levels, forms, the always-expressed mouth and `dominant_of` through the catalogue; `body_version` |
| `game/normal/food.gd` | no gene name: the water's draws, every sense and every bite by stat, tag and channel; every body's `stat_` fields |
| `normal_mode.gd`, `referee.gd`, `drop.gd`, `drop_save.gd`, `recorder.gd`, `replay.gd` | the same, by stat, tag and channel |
| `cell_figure.gd`, `figure.gd`, `gene_stats.gd`, `soma.gd`, `vision.gd`, `cilia.gd` | only where they read a constant that moved; their own names wait for 1b |
| `tools/gene_probe.gd`, `.tscn` **new**; `ci.yml`'s *Check the genes* | v1 (§12.1), before *Check the levels* |
| `tools/drop_probe.gd`, `net_probe.gd`, `levels_probe.gd`, `net_fuzz.gd`, `drive.gd`, `i18n_pot.gd` | read the catalogue and the stats |

**What the catalogue answers** (§4.3): `known`, `gene`, `keys`, `live`, `rank`,
`organ_of`, `variant_of`, `place_of`, `forms_of`, `has_forms`, `variety`, `form_in`,
`dose_of`; `tagged`, `has_tag`, `drifters`, `weight`, `born`, `born_order`; `declares`,
`levelled`, `has_levels`, `levels`, `number`, `number_for` (with what to answer once
nothing provides the stat), `upkeep_at`; `providers`,
`provided`, `first_provider`, `provides`, `table`, `worn_provider`, `channel_of`,
`worn_on`; `register`, `forget`. **The stats** (§5): `of`, `tier`, `value`, `at`,
`table`, `top`, `none`, `judged`, `label`. **A body** (`cell.gd`): `worn`, `stat`,
`provider`, `tier_for`, `on_channel`.

**Where it differs from the design, and why** (the sections above say so too):

- **`has_tag`, not `is`** (§4.3): `is` is a GDScript keyword.
- **`never_drifts`, not `never_drifts_out`** (§9): the literal it replaces kept the
  mouth out of both sides of a drift.
- **The lists keep the order they shipped in** (§9): the catalogue's own order would
  have moved every seeded draw, the rulebook's bits and `Wire.RULES`.
- **A retired key has no place in the order** (§4.3, §4.4), so it loses ties as it
  always did; pellicle's place is 11, not 12 (§4.2).
- **Drift stays an even draw** (§9) until phase 7.
- **`channel` arrived here** (§7.3), for the eye-spot, which provides no stat.
- **A mechanic acts from the first provider in the catalogue's order** (§5.2), not
  in slot order: the layout would be needed at every read. (Phase 3 made it slot
  order for a mechanic with a place, once each was read once a body: §15.4.)
- **Stats are read by name, not in a loop** (§5.2): each line of `_refresh_body`,
  `_eye_of` and `_derive_person` is one stat now, and the gene left it.
- **A body's stats are read once, when its genome is written, and never on a tick.**
  Every water body carries `stat_` fields -- its gape as a share of its radius, its
  bite, armour and turn, its tail's realised speed and hold level, its dart and its
  dash -- read by `Body.derive()`. The genome's setter calls it on every write, so a
  person's, a floc's, a replay's, a mirror's and today's water's bodies have them too
  (none of those reaches `_refresh_body`); the three edits in place -- a meal in
  today's water, a meal in the drop, the toxin given back -- call it after. The
  player's cell reads each stat, organ and tier once a body: `genome.gd` bumps
  `body_version` whenever the body changes (`express`, and through it `set_state`;
  `_express_gift`; a form's conversion). Before this, the switch cost the water's step
  10 to 18 % (below).
- **The gift's copy check went with the copies.** `net_probe` compared the referee's
  `FIRST_SENSES` with the run's; both read the `gift` tag now, so it checks instead that
  the referee lets in exactly the gift genes, one at tier 1, for every live gene.
- **`DropSave.rules()` lists every provider's table by stat** (`Stats.label`, the
  constant's old name), and still finds any `*_BY_TIER` left in `cell.gd` by name, as
  it always did. None is, and the text is the same to the byte.
- **`toxicyst` weighs 2 in the water**, its variant's, where it fell back to 1. Nothing
  reads it: the water draws the variety, `veneneux`, and places it by a coin.

**Found in review, and fixed here.** A review of the first build found no change in
behaviour, and seven things that would break as soon as the gene pass added a second
provider of a stat, a variant or a retirement. Each is a commit of its own and the
same for every body today; each check it adds was seen to fail on an organ planted in
a scratch copy, or registered by the probe itself:

1. **The rules fingerprint held only the first provider** of each stat the referee
   judges, though the referee judges every one, and the speed and turn caps were held
   over the first provider's numbers. A second organ that called past 1900 or swam
   faster left `Wire.RULES` where it was, so a host and a guest either side of it would
   cut an honest guest with no protocol bump and no failure. `net_probe` now writes
   every provider -- the first under the line it always had, any other as
   `label.key`, as `drop_save.gd` does -- and fails a row marked judged whose lines are
   missing; the caps are held over every provider (`_stacked_peak`, over `stats.gd`'s
   `top`, which now combines providers by the row's rule). The text and its hash are
   today's. A planted second caller (2,500 to 2,700) fails the fingerprint; a planted
   faster tail fails it, the speed cap (1,640 u/s against 1,100) and R2's bound.
2. **The referee's shout rate indexed the caller's own period table**, so an organ
   that called with no `ping_period` crashed it (`clampi(tier, 1, -1)`) and its guest
   got a rate of 0, then was cut. It reads the period as the guest's own run does,
   the stats' `ping_period` of what it wears, keeps the first caller's tier 1 for a
   body that calls with nothing, and never indexes an empty table. The probe holds
   the six groups of stats a mechanic reads together (§12.1) to come from the same
   organs, and registers a caller with no period to see it caught and held to a rate.
3. **A variant's or a form's `tags` replaced its organ's.** They add up now, as
   `gene.gd` always said (§6.2); the probe holds the union.
4. **A variant with no `forms` was filed under no key**, without a word, and the
   probe's count agreed. It is one form, outside, under its `key` or its name (§6.2);
   with neither the catalogue says so and the probe's count fails.
5. **The water read a dart's reach and rest, and an eye's ping period, off the first
   provider's table at the worn organ's copies.** A body reads the organ it wears
   now, as the player's cell does; no mechanic calls `Stats.at`.
6. **Two organ files of one name, or two variants of one name**, would answer for
   each other's forms. The probe fails on either.
7. **A stat whose only provider retired failed the probe**, and live keys were held to
   every shipped one, so retiring could not pass; and the game read an organ's own
   numbers -- the hold level, the stun, the beam's experience cap -- as `int()` of
   nothing, 3,549 script errors at the first frames with the tail, the beam and the
   dart retired in a scratch copy. The probe allows it and names the stat in a NOTE;
   `number_for` takes what to answer when nothing provides the stat (`HOLD_NEVER`, a
   stun of 0, a cap of 0). With the same three retired, no error.

And the smaller ones. The contact tables -- the gape, the bite, the armour, the
doses -- say beside them that a change is a `Wire.PROTOCOL` bump by hand. Every
container a record holds is read-only all the way down (`FROZEN`), so a reader writing
into one is a script error where it used to change the gene for every body. The probe
says what it checks and checks what it says: the lists whole, a gene that joins one
failing until it is appended to `SHIPPED_LISTS`; every key's tags and channel as
filed; and gene names written as `"key"` counted as well as `&"key"`.

**Checked: nothing changed** (§14), on the last commit before the documentation and
again after the review's fixes (`c482bd3`; the probe once more on `346c7f4`, which only
renames one of its variables):

1. Every check `ci.yml` runs passes here but two that need a network namespace this
   container refuses, `net_drop` and the door of `net_fuzz` (left to CI). None was
   removed or loosened; the gift-copy check above was replaced. The gene probe makes
   26 checks.
2. The empty library hashes to `7397a410…` under all three schemes, 69,349 trace
   lines. `drop_probe` passes all 144 checks, and the seven that hold its ten pins
   print what they printed before, to the byte: `DEV_LINES`, `THREE_ONE_LINES`,
   `IDENTITY_LINES`, `DEV_MEMBRANE` (`67a6afe687b3b316`), `PACK3_LINES`, `TAIL_LINES`,
   `PACK3_TRACE` (`78b3447e4eb64a80`), `TAIL_TRACE` (`d6fed1db6bd5befd`),
   `DEV_MUTATIONS` (`756d76d53e65d8a1`, 236) and `DEV_DRAWS` (`f2be9c30903816fc`, 793).
   Its other lines that differ are of the kinds that differ between two runs before:
   a new drop's random number, and the real-time frame readout.
3. `Wire.RULES` is `46913eab9d0b76a0`; `net_probe` passes all 441 (440, and the
   review's check that every judged table is in the rules), and what differs is what
   differs between two runs before -- timing, certificates, ids, the slots a pond's
   sisters land in.
4. `DropSave.rules()` is `e4213164b90d…`, the 43 lines the same.
5. Seven poses at 1280x720 and 2400x1080 -- full vision and point of view with a cell
   wearing every gene, the pause figure with a toxin waiting, the choosing screen, the
   stats lines, the instincts page, a cell's detail view -- rendered three times before,
   0 px apart, and after every commit that moved code: 0 px from them, all 14.
6. The template regenerates byte for byte (531 messages, read from 89 files, 68
   before); `fr.po` is untouched and `--lint-all` says what it said.

And: `drive --fingerprint=3000` at seeds 7 and 12345, plain, sniffing and with seven
genes on, the same six hashes and counts; the input path's three traces; every scene's
boot; the levels and Back probes' logs; 3,865 answers of the stats and the catalogue
(every stat at every key and copies -1 to 5), the same before and after the reads were
made fast; every script in `game/`, `tools/` and `server/` compiling.

**The cost, and what took it back.** The water's step is `drive --field-cost=600
--age=900`, seed 7, a sighted player of radius 30, p50 in µs, the mean of three rounds
interleaved with the commit before 1a on this machine; `drop_probe` is its whole run
here, alone on a quiet machine.

| | full vision | point of view | `drop_probe` |
|---|---|---|---|
| before 1a (`de11f8e`), over four sessions | 2266 to 2405 | 2123 to 2289 | 341 and 345 s |
| switched, every read through the catalogue (`fb5770f`) | +10 % | +18 % | 421 s |
| a stat read in one lookup (`f14934f`) | +4 % | +7 % | 373 s |
| a body's stats read once, when its genome is written (`e07c89a`) | **−7 %** | **−4 %** | 365 s |
| and with the review's fixes (`c482bd3`) | **−4 %** (2393 to 2303) | **−0.3 %** (2289 to 2282) | 363 s (+5 %) |

A stat read through `stats.gd` is 0.7 µs against the old table's 0.2: cheap, but the
water reads a body's gape about ninety times a frame and the tail's speed for every
chase, and those reads are now fields. **What is left of `drop_probe`'s 5 % is the
probe's own**: its watched drop checks every move of every ruled body against a speed
bound and a hold level it works out afresh from the genome, which is the independence
it is there for -- `CellBody.speed_of` 1.3 million times and `hold_level` 0.4 million
in its tail section alone, at 2.5 and 1.4 µs where the old tables took 0.5 and 0.01.
The game itself works them out only when a genome is written: 32 thousand times in
that section.

**Deferred, and to which phase:**

- **1b**: every look and word -- 135 gene names left in nine files of `game/`, which the
  probe prints: `cilia.gd` 58, `figure.gd` 37, `gene_stats.gd` 17, `programs_page.gd`
  9, `controls.gd` 4, `genome.gd` 4 (`NAMES`, whose word for the toxin is
  `"toxicyst"`), `returns.gd` 3, `vision.gd` 2, and `drop.gd`'s `TOXIN`, which is 3's;
  and the probe's look, word, stats-line and colour checks.
- **2**: `cilia.default_order`'s three home organs, the body plan, and its checks.
- **3**: the toxin's special cases (`Drop.TOXIN`), and the readers and triggers keyed
  `"<gene>.<part>"` in `food.gd` and `own_rules.gd` -- the probe checks every declared
  part is wired, but by those names.
- **4**: `Wire.RULES` generated from the catalogue; until then `net_probe` writes every
  provider of the judged stats by hand-listed stat, under `Stats.label`.
- **5**: the grep gate (§12.2), the README and the skill.
- **7**: drift's weight.

### 15.2 As built: phase 1b, 2026-10-05

**Every look, colour copy, word and numbers line is its organ's, and nothing a player
can notice.** By file:

| file | now |
|---|---|
| `game/genes/gene.gd` | the shapes -- `mat`, `oars`, `lash`, `tuft`, `spines` -- and which are drawn on arcs of their own and which counted; the field `look`; the word tables an organ's file may hold; the hooks `stat_at` and `lines` |
| `game/genes/catalogue.gd` | `look`, `looks`, `hues`, `shape_by_key`, `shaped`, `shapes`, `first_on`, `words`, `part_words`; the word tables read by their names (`KEY_WORDS`, `WAY_WORDS`, `PART_WORDS`); `look` a field a variant may set, frozen with the rest. The looks, the hues and shapes by key and the keys by shape are filled in place, as the stats are, because `cilia.gd` holds them |
| `game/genes/organs/*.gd` | each live organ's look -- shape, hue, stroke count, a home organ's tile -- with the comment its hue had; its words, each table with the TRANSLATORS note, ROOM and CONTEXT it had; its `lines`. `ocellus.gd` has the ways' words, `toxin.gd` its word and line in hand and `NAMES` |
| `game/vision/cilia.gd` | no `HUES`, `EARNED_COUNT`, `TILE_COUNT`, `TILE_LEN` or home counts: the home organs found by shape, tufts and tiles by their look's counts, spines by place, the lips in the hue of the organ the body has its gape from; `hue_for(stat)`, `hue_on(channel)` |
| `game/perception/signal_bus.gd` | its light, beam and ping lobes the hue of the organ on each channel, its strain colours those of the forms that deliver each kind; read once, as static vars |
| `vision.gd`, `returns.gd` | the beam's rays and the ping's wave in their channel's organ's hue |
| `controls.gd`, `programs_page.gd`, `earshot.gd` | each pad's hue, and the dash pad's organ, by what the pad works through; the library's column marks the pads'; a body part's organ by what it acts through; the call code the ping organ's violet |
| `figure.gd`, `genome.gd`, `normal_mode.gd`, `program_words.gd` | the words through the catalogue; the words of the values the senses report, which are no organ's, in `program_words.gd` |
| `gene_stats.gd` | the context, the costs line's last item, the odds and the caption; a gene's lines are its organ's |
| `tools/i18n_pot.gd`, `biogenic.pot` | the gene words a room is measured with from the catalogue, an organ's word tables named by it, the bodies by the stats that change a number |
| `tools/gene_probe.gd`, `levels_probe.gd` | v2 (§12.1); every retired key draws no numbers |

**Where it differs from the design, and why** (§7.1, §8.2 and §12.1 say so too):

- **The toxin's shape is one, `spines`, drawn by place** (§7.1 lists `fangs`, `guard`
  and `granules`): `gene-looks.md` §2.1 makes them one kind, so phase 6 adds that
  kind's parameters rather than merging three. Fangs on the lips at the front, barbs
  on a side or the stern, granules inside, as before.
- **No `pigment` or `bud` field** (§7.1). The shape says whether an organ wears a
  pigment: a tuft does, a home organ does not, spines by place. The bud is a levelled
  organ's state, which the player's body passes as `eye` each frame. A home organ's
  look gives its tile's count and length; a tuft's tile wears its body's count, as it
  did.
- **`default_order` still names the three home organs**: their seats are phase 2's.
- **An organ's words are constants of its file, keyed by the key or the part they are
  said of**, not fields set in `_init()`: the translation tool lists a constant that
  carries a TRANSLATORS note, and the notes had to stay as they were. The catalogue
  reads the tables by name.
- **The values' words went to `program_words.gd`** (§8.1 lists them with the parts'):
  `distance`, `size`, `level` and `closeness` are reported by several senses and are
  no organ's. They are asked after the declaring files, so the metabolism's own
  `level` keeps its chip.
- **The beam's ways have words of their own** (§8.1 does not list them): their
  titles, card lines and growing lines moved from `normal_mode.gd` to `ocellus.gd`,
  keyed by way, and the fork's screens read them through the forking gene.
- **The hook is `lines(t, level, path, ctx, slot, wear)`** (§8.4): `t` the copies
  already clamped, and `wear` the costs line's last item, priced by the screen. The
  context carries the body's terms and its tank, the five scripts a line reads numbers
  from (`cell`, `metabolism`, `food`, `bus`, `genome`) and the screen's own `beat` and
  `wear_item`, so an organ preloads nothing outside `game/mechanics/`. A context a
  caller built for itself is completed.
- **The bus keeps no copy** (§7.1 allowed one, held by the probe): its four colours
  are read from the catalogue once. A sense's lobe is the hue of the first live organ on
  its channel -- the organ `cilia.gd`'s `hue_on` draws that sense's marks in, so the
  lobe and the marks cannot part -- and a kind of load is drawn in the hue of the first
  live form that delivers it, by `dose_hue` and the bus alike. Paralysis and sleep,
  which nothing delivers yet, keep their starting values.
- **`earshot.gd`'s call code was a copy too**, which §7.1 does not list; it reads the
  ping organ's hue.
- **A sense's marks go by channel, a pad by what it works through**: the beam's rays
  and the ping's wave by their channel; the turn pad by `turn_rate`, the push pad by
  `push_accel`, the hold by the tail's `impulse_speed`, the dash pad's organ by
  `dash_speed`.
- **The translation tool reads four fills from the catalogue** (§8.2 names one): the
  chip word, a way's name, a sense's word and an action's. **Two words as wide now
  rank by their letters**: the sort was unstable, and the catalogue lists the words in
  another order than `figure.gd` did, which moved one room note by a pixel. The
  template keeps every msgid and context; its references and the order its notes
  merge in change, and the toxin's word and line in hand gain `entry:` lines, keyed
  by form now.
- **Today's floor is 10°** (§12.1), of HSV hue (`Color.h`): `cirrus` and `vacuole`,
  10.2° apart, are the nearest pair but the five kept. The degrees written beside the
  hues in the organ files are another measure, and are left as they were.
- **`levels_probe`'s row check was already on a retired key**, `statocyst`. It asks
  the catalogue for every retired one now.

**Checked: nothing changed** (§14), against `a37545e` (1a, and the two designs):

1. Every check `ci.yml` runs passes here but `net_drop` and the door of `net_fuzz`,
   which need a network namespace this container refuses (left to CI, as in 1a). None
   was removed or loosened. The gene probe makes 32 checks; each of its six new ones
   was seen to fail on a fault planted in a scratch copy -- a missing count, a stray
   look field, a word under a wrong key, a part's line under a wrong part, a gene with
   no lines, a hue moved next to another, a lobe and the call code copied as
   literals, the catalogue's hues replaced where they are refilled -- and the French
   note to list a word with none. Of the 66 gene words, it lists none.
2. The empty library hashes to `7397a410…` under all three schemes, 69,349 lines.
   `drop_probe` passes, its ten pins holding; the lines that differ from 1a's are of
   the kinds that differ between two runs of one tree -- a new drop's seed and what it
   holds, the real-time frame readout, a replay's slot.
3. `Wire.RULES` is `46913eab9d0b76a0`; `net_probe` passes all 441, and what differs
   is what differed between two runs in 1a.
4. `DropSave.rules()` is `e4213164b90d…`, its 43 lines the same.
5. **Seventeen poses at both sizes, 34 frames**, each rendered twice on `a37545e` 0 px
   apart, and on 1b after each commit that moved drawing code, 0 px from them every
   time: 1a's seven; the tray of waiting genes with a retired one among them; the
   quick placement offer; the beam's numbers past its fork; a waiting toxin's numbers;
   the store's and the burn's numbers; every pad; the programs library; and the beam's
   fork, its cards and an armed way (three times on `a37545e`, after a first shot
   raced the arming).
6. The template keeps its 531 messages, every msgid and context the same; `fr.po` is
   untouched, and `--lint-all` prints what it printed, line for line, the lines it
   composes measured the same.

And: every word, line and look a screen can ask for -- every key and one this build
does not know, in English and in French; every part's words; every numbers line at
every copy count, level, way and slot in eight bodies; every hue, tint and dose hue;
the bus's, the pads' and the call code's colours; `default_order` -- 30,519 answers,
the same to the byte; the stats' and the catalogue's 3,865 answers; `drive
--fingerprint=3000` at seeds 7 and 12345, plain, sniffing and with seven genes on, the
same six hashes and counts; the input path's three traces; every scene's boot; the
levels, Back and fuzz probes; and every script compiling, at the first commit of 1b
alone and at the last.

**The cost.** The water's step is `drive --field-cost=600 --age=900`, seed 7, a sighted
player of radius 30, p50 in µs: the median of seven rounds interleaved with `a37545e`,
in both orders, and the spread of the seven. `drop_probe` is its whole run, alone on a
quiet machine.

| | full vision | point of view | `drop_probe` |
|---|---|---|---|
| `a37545e` | 2125 (2039 to 2390) | 2366 (1999 to 2641) | 354 and 353 s |
| 1b | 2209 (2080 to 2298, and one round of 4971 the machine took) | 2199 (2049 to 3184) | 354 s |

The water's step calls nothing 1b changed -- `food.gd`, `cell.gd`, `genome.gd` and
`metabolism.gd` read no colour and no word, and the two `cilia.gd` functions the water
calls, `default_order` and `slot_bearing`, are as they were -- so what moves between
those columns is the machine. **Drawing is what 1b touched**, and the step does not time
it: 300 cells a frame through `draw_cell`, timed inside `_draw` on this container's
software GL, cost 4 % more while each organ's look was read through a function and two
lookups. With the catalogue keeping each key's hue and shape by key, as the old tables
did, it is within its noise: p10 136.1 ms against 135.0, four rounds each.

**Gene names left in `game/`** (§12.2): 10, from 135 -- `cilia.gd`'s `default_order`
9 (phase 2) and `drop.gd`'s `TOXIN` (phase 3) -- and 17 keys of the form
`"<gene>.<part>"`, which the probe does not count: `food.gd`'s readers and triggers 8,
`own_rules.gd`'s 6, and `programs_page.gd`'s `HOLDS_TAIL` and `_verb_of` 3, all phase
3's.

**Deferred, and to which phase:**

- **2**: `default_order`'s home seats.
- **3**: `Drop.TOXIN`, and every `"<gene>.<part>"` key.
- **6**: a look's `hue` becomes its family's, and the colour checks the family rules
  (`gene-looks.md` §8).

### 15.3 As built: phase 2, 2026-10-05

**The slots are one file of rows, every save that keeps a slot order carries the plan
it was kept under, and nothing a player can notice changes.** By file:

| file | now |
|---|---|
| `game/genes/body_plan.gd` | today's eight rows (§10.1) and the ovoid. Everything §10.2 derives, worked out once a plan. `use` and `restore` swap a plan in and out, as `register` and `forget` do an organ; `listen` is called by a file that keeps a copy of a count. Then the stamp, `written` and `migrate` (§10.3), and `fingerprint`, which nothing reads until phase 4 |
| `cell.gd`, `genome.gd` | `SLOT_MIN`, `SLOT_MAX`, `INSIDE`, `INSIDE_SLOTS`, `FRONT` and `STERN` under their names, static vars the plan refreshes; `slots_for` is the plan's count; a born body is seated by `home_layout`; `to_state` writes `plan`, and `set_state` lays both layouts out by `layout_from` |
| `cilia.gd` | the arcs, `arc_for_slot`, `slot_bearing` and the ovoid read off the plan; `default_order`'s home seats are the plan's, and its nine gene literals are gone; a home organ is drawn on its home slot's arc, and the cirrus's port oars mirror its flank |
| `figure.gd` | the ring's seats, arrows and Tab order, laid out from the bearings on the same 3 x 3 grid; `CROWDED` names a slot with no cell of its own |
| `cell_figure.gd`, `normal_mode.gd` | a cell's layouts read by `layout_from`; the daughters on offer stamped and read the same way; the choosing screen's loci, the plan's slots |
| `wire.gd` | `GENES_MAX` and `ORDER_MAX` are the plan's, and every size built on them is a static var worked out from them. It loads `body_plan.gd` and nothing else |
| `referee.gd` | `_order_fits` unchanged, its doc saying why |
| `drop_save.gd` | `rules_text`'s slot lines from the plan, under their old labels; `genome.plan` and a daughter's `plan` checked when there |
| `catalogue.gd` | `born_order` is the born organs; where they sit is the plan's |
| `tools/gene_probe.gd`, `net_probe.gd`, `i18n_pot.gd` | the plan's checks and the synthetic plan (§12.1, §12.3); `GENES_MAX == 9` gone, both counts held to the plan and `TIER_TOP` to `TIER_MAX`; `SLOT_MAX` read as the static var it is |

**Where it differs from the design, and why** (§10 says so too):

- **No water body is stamped** (§10.3 lists a world's water bodies): a water body keeps
  no slot order. Its layout is `default_order`'s, worked out from the plan in use each
  time, so it follows a new plan by construction.
- **The stamp is one key, `genome.plan`**, beside `order` and `worn`, so a cell's file
  and a cell a world kept before slots carry it the same way. A daughter on offer
  carries her own. Every shape check takes it as optional. **A build before it reads
  it**: `DropSave.misfit` asks only for the keys a shape names, so an older content
  pack takes a stamped file as today's plan -- which it is -- and writes it back
  without the stamp. Seen, not argued: phase 2's files, opened by `4f98110`, play as
  they do on phase 2. **That holds while the plan is today's.** After a plan change,
  a build from before phase 2 would lay a newer file out by index, and the APK's own
  content is such a build until the next binary: it is what runs when a pack fails to
  mount. So the first plan change should ship in an APK built since phase 2 -- with a
  `binary_version` bump of its own, if none has gone out by then.
- **A gene whose slot is gone takes the nearest free outside slot, whatever its index**,
  not only one within the layout's old length: the layout grows only as far as that
  slot. An id the build never knew -- a later plan's -- has no bearing, and takes the
  first free slot. A gene kept at an inside slot is left to the DNA, because the
  inside keeps no order and is read off the DNA.
- **A plan with fewer outside slots than a saved DNA has genes outside is not covered
  yet.** Such a gene stays in the DNA, as §10.3 says, but `genome.gd`'s `_sync_order`
  then seats it past the outside, as it seats a pose of more genes than slots today.
  The next birth's `_put_in_place` would read it as posed inside, and a toxin there
  would become its inside form. No plan that only adds slots reaches this. Before a
  plan ever drops below a body's genes, `_sync_order` should leave such a gene
  unseated. That changes what a pose of more than seven genes does today, so phase 2
  leaves it alone.
- **`TIER_TOP` stays written out in `wire.gd`** (§13 lists it with the derived
  limits): the wire loads nothing of the game but the plan. The gene probe and
  `net_probe` hold it to `genome.gd`'s `TIER_MAX`, which nothing did before.
- **`_order_fits` is unchanged** (§15 lists `referee.gd`): it counts no slot, and the
  wire bounds an order, by the plan, before the referee reads one.
- **The probe holds today's plan to the one that shipped**: `slots_for`'s formula, the
  arcs and bearings, the counts and the ring are pinned in `gene_probe.gd`, as
  `SHIPPED` pins the keys. A plan change moves them in the same commit.
- **The synthetic plan runs in the gene probe**, which CI already runs. A probe of its
  own would need a workflow step, and a workflow is edited only when asked. Its plan
  moves the rear starboard diagonal, retires the forward port one, and adds the port
  flank and a bow slot on the retired one's arc. That is eight outside, so every count
  the plan sizes grows by one.
- **The port flank is the ring's one empty cell, and the pause screen uses it**: its
  columns are shaped so full vision's ghost of your cell lands there (`normal_mode.gd`'s
  note on `_light_panel`). A plan that seats the port flank takes that cell -- a layout
  decision for that change, not a fault the layout check sees.
- **`body_plan.gd.uid` is committed**, as Godot's import made it, as every other script
  in `game/genes` was in 1a.

**Checked: nothing changed** (§14), against `4f98110`:

1. Every check `ci.yml` runs passes here but `net_drop` and the door of `net_fuzz`,
   which need a network namespace this container refuses (left to CI, as before).
   None was removed or loosened but `net_probe`'s literal nine, which §13 names. The
   gene probe makes 42 checks: phase 2's eight, and the review's two below. Each of
   phase 2's eight was seen to fail on a fault planted in a scratch copy: the wire not
   following the plan, no stamp written, a daughter unstamped, a gene whose slot is
   gone put in the first free slot rather than the nearest, a migration by index
   rather than by id, the ring laid out by index, `cell.gd` not listening, `slots_for`
   strict at a rung, crowding unseen, and the last rung at 39. Each plan check also
   fails on a plan, swapped in, that breaks it.
2. The empty library hashes to `7397a410…` under all three schemes, 69,349 lines.
   `drop_probe` passes all 143, its ten pins holding. The lines that differ from 1b's
   are the kinds that differ between two runs of one tree: a new drop's seed, the
   real-time frame readout, a replay's slot.
3. `Wire.RULES` is `46913eab9d0b76a0`: none of its lines is a slot's. `net_probe`
   passes all 441. What differs is the genome check's wording and what differs
   between two runs.
4. `DropSave.rules()` is `e4213164b90d…`: the slot lines come from the plan under the
   labels they had, `cell.SLOT_RADIUS` its even step.
5. **The 34 frames**: 17 poses at both sizes, rendered twice on `4f98110` 0 px apart,
   and 0 px from them at the last commit of phase 2 and again at the last of this pull
   request.
6. The template is current, 531 messages; `fr.po` is untouched, and `--lint-all`
   prints what it printed, line for line.

Also the same: the 30,519 answers of every word, line and look, to the byte; the
stats' and the catalogue's 3,865; `drive --fingerprint=3000` at seeds 7 and 12345,
plain, sniffing and with seven genes on, the same six hashes and counts at the last
commit of phase 2 and at the last of this pull request; the input path's three
traces; every scene's boot; the levels, Back and fuzz probes.

**And a cell left mid-choice by `4f98110`**, in its slot and its world: r40, its DNA
moved on from what it wears, two daughters on offer. Opened by `4f98110` and by phase
2, the 8,674 lines of four seconds are the same. Kept again, the files are the same
but for three stamps: the genome's and each daughter's. The stamped files, opened by
`4f98110` and by phase 2, play the same, 8,796 lines.

**The cost.** The water's step, as 1b measured it: `drive --field-cost=600 --age=900`,
seed 7, a sighted player of radius 30, p50 in µs. Each cell is the median of six
rounds -- three with `4f98110` first and three with phase 2 first -- and the spread of
the six. The container came back from a restart on a slower host midway, so these do
not compare with 1b's table.

| | full vision | point of view |
|---|---|---|
| `4f98110` | 2418 (2343 to 2877) | 2252 (2092 to 2433) |
| phase 2 | 2488 (2347 to 2619) | 2357 (2302 to 2487) |

**The water's step calls nothing phase 2 changed on its way through a frame.**
`food.gd` is untouched. `slots_for`, `default_order` and `slot_bearing` run when a
body eats, is spawned or is refreshed, not every frame. Point of view's six rounds
all came out slower, so it was run once more: four rounds rotating `4f98110`, a copy
of it, and phase 2. The two identical trees came out at 2372 and 2367, spread over
2152 to 2795, and phase 2 at 2274 (2134 to 2310). The machine moves this measure by
more than anything phase 2 did.

**Drawing** is 300 cells a frame through `draw_cell`, on this container's software GL.
Before the restart, eight rounds interleaved gave p50 126.7 ms for `4f98110` against
129.2 for phase 2, and p10 121.4 against 123.4. What phase 2 put on that path costs
about 2 µs a cell: `default_order` takes 0.8 µs more, and the three home arcs are
looked up rather than written in. That is 0.6 ms of a 127 ms frame. A slot's bearing
is cheaper (0.32 µs against 0.55), because it is worked out once a plan. After the
restart, three rounds were run of `4f98110`, phase 2 and four variants: the home arcs
written in again, the old `default_order`, `4f98110`'s whole `cilia.gd`, and a version
that reads the plan's counts from copies of its own. All six came out within one
another's spread, p10 149.2 to 151.6 ms, so none was kept.

**And the 1b review's findings 1 to 3**, each its own commit after phase 2's:

- **No gene word ships unseen, or too wide.** The translation tool lists a word table
  only where it carries a TRANSLATORS note, and measures a word only against a ROOM
  line. So the gene probe now looks every word the catalogue hands out up in the
  template, under its context. It also measures every live chip word, in English and
  in French, against the choosing screen's 47 px block and a chip's 62.2 px beside
  its pips. Both checks fail on the review's repros: a table with no note, and
  "carapace", 57 px, with no ROOM. French `armure` is the widest word today, at
  47.0 px of the block's 47.
- **Retiring a gene is its tag** (§16). A retired key may keep its look, which is held
  as a live one's is, and its lines. A key draws nothing when its organ's file has no
  lines, or when this build does not know it. A kept colour pair with a retired key in
  it leaves the count. With only the tag, `pellicle` fails one of the gene probe's
  checks, the drifter list, which §16 says it must until `SHIPPED_LISTS` records it.
  **That is not all it fails** (phase 2's review, corrected in phase 3): `i18n_pot
  --check` goes stale, because the template's room notes are measured with the widest
  gene word; nine of `drop_probe`'s checks fail, its seeded water's pins -- a drifter
  leaving moves the water -- and row 5's, which posed `pellicle` by name; and seven of
  `net_probe`'s, five pond-field checks that posed it by name and the referee's
  `RULES` with the handshake check that holds them, rightly: armour is in the rules.
  Phase 3 has the probes pose the first live organ that provides armour, so retiring
  one moves them to the next, and the last one's retirement fails them saying so
  (§15.4, §16).
- **The nits**: `crista`'s unused `burn`; `ocellus`'s dead fallback price; `stat_at`'s
  doc, which now says it answers 0 for a stat its organ does not provide, and why;
  and `HOME_SHAPES`, one list, gene.gd's.

**Gene names left in `game/`** (§12.2): 1, `drop.gd`'s `TOXIN` (phase 3), from 10 --
`default_order`'s nine went with the home seats -- and the 17 keys of the form
`"<gene>.<part>"`, phase 3's.

**Deferred, and to which phase:**

- **3**: `Drop.TOXIN`, and every `"<gene>.<part>"` key.
- **4**: the plan's fingerprint on the handshake (`BodyPlan.fingerprint()`), and with
  it the end of moving `PROTOCOL` by hand for a plan change.
- **Before a plan drops below a body's genes**: `_sync_order` leaves a gene with no
  outside slot unseated (above).
- **Before the first plan change** (phase 2's review, recorded in phase 3):
  - **Migration can give a body more live slots than it earned.** `migrate` sends a
    gene whose slot left the plan, or another gene took, to the free outside slot
    nearest it by bearing, whatever its index (`body_plan.gd`, its code against its
    doc's "as far as a gene's new slot is"). A swap of the fore diagonals does it; so
    does a born r26 cell with the gift on its bonus slot, or a gene whose slot was
    retired. A meal that lapses later then lands past the earned count. Nothing is
    lost or duplicated. Whether such a body keeps the slot, or the gene waits in its
    DNA until it earns one, is a design call to make and record with that change.
  - **The choosing screen's column** is `112 + (loci + 2) x 48` px, and its words
    under it: 658 px at today's eight loci, 706 at nine, past the 720 px canvas at
    ten. Phase 3's gene probe fails a plan it runs off (§15.4).
  - **`drop_probe`'s floors check can fail by chance.** It holds that no drifter gene
    is ever carried by nobody, over five minutes of one water at seed 1. On the
    eight-slot plan it failed there, twice. Phase 3 ran the same water at seeds 1 to
    6: today's plan loses a gene once (seed 3), the eight-slot plan five times (seeds
    1, 3 and 5), and in all twelve the floor brings each back by the next count. So
    the floor works on both, a plan change can fail the check at seed 1 without
    breaking anything, and whether a bigger outside makes a lost gene likelier is
    more than six seeds can say.

### 15.4 As built: phase 3, 2026-10-05

**A variant is one entry in its organ's file, for any organ, and the water, the genome,
the body, the instincts, the stats screen, the wire and saves follow it. Nothing a
player can notice changes.** By file:

| file | now |
|---|---|
| `gene.gd` | `one_variant`, an organ's, off (§6.3); the tags `not_on_drifters` and `floor_by_peers` (§6.4); `dose_line`, what one stack of a key's own dose does |
| `catalogue.gd` | an organ's weight in the water (`organ_weight`: its own, else its first variety's) and its varieties (`organs_in`, `of_organ`, `pick_variety`, which draws no number for an organ of one); a key's organ and an organ's keys, one lookup each (`organ_of`, `keys_of_organ`); `one_variant`; `seated_provider`, and `number_for` given a layout; `declares` by organ, `by_organ` and `first_key`; `declares` is no longer a field a variant sets, and every variant carries its organ's parts |
| `stats.gd` | `SEATED`, the stats whose mechanic has a place; `organ`, the organ a mechanic acts from; `tier_of` |
| `food.gd` | the water's draws and fills by organ, then strain; the floor's peer path by tag (`_peer_short`, `_give_back_by_peer`); `_seat_of`, the eye's ping tier and its beam by the organ acted from, and a water body's dart stun its seated dart's (`Body.seats`); the readers and triggers wired by part name (`wire_parts`); `_worn_of` by organ; `toxins_of` reads any key with a dose |
| `genome.gd` | drift draws an organ, then a strain; `one_variant` writes over the other strains and keeps drift off a carried organ |
| `drop.gd` | `TOXIN` gone: `take_drifter_gene` and `drifter_genes` by `not_on_drifters`; `give_toxin` is `give_back(tiers, gene, ...)`; the senses given by organ |
| `cell.gd` | `provider` is `Stats.organ` over the body's layout (`seats`), `tier_for` that organ's copies, and `dart_stun` takes a layout |
| `normal_mode.gd`, `replay.gd` | the gift by organ; the beam's fork and experience cap its own organ's; the replay's ping bearing its seated caller's |
| `own_rules.gd`, `programs_page.gd`, `rulebook.gd` | your instincts' readers wired by part name, your parts counted by organ; the hold's mark and a part's verb found by its name; `part_of` |
| `toxin.gd` | its two tags; `dose_line` read off its own dose |
| `body_plan.gd` | a stamp of no ids is no stamp; the plan's note says a plan change moves `Wire.PROTOCOL` by hand until phase 4 |
| `tools/gene_probe.gd` | 53 checks, 42 before: the synthetic gene and its variants, the faster tail and the second strain (§12.3), the dose and venom-word checks in two of the old ones, and `-- --names`, the gate (§12.2); the plan's checks start from `SHIPPED_PLAN`, and the choosing screen is held to the canvas (phase 2's review, below) |
| `tools/drop_probe.gd`, `net_probe.gd`, `field_diff.gd` | the toxin by its key; the stub genomes answer `body_layout`; armour posed by its stat, the outside filled from the plan, a genome past the plan's count named by letter (phase 2's review) |
| `.github/workflows/ci.yml` | "Check the gene names" (§12.2), asked for in phase 3's brief |

**Where it differs from the design, and why** (the sections above say so too):

- **A mechanic with a place acts from the first provider in slot order** (§5.2 said the
  catalogue's), as phase 3's brief asked. The design's reason for the catalogue's --
  the layout at every read -- is gone: each of these is read once a body. The beam,
  the ping, the dart and the nose have a place; the mouth, the tail's level and hold
  and the dash do not, and keep the catalogue's order.
- **An organ's weight in the water** is its file's own `water.weight`, read before a
  variant writes over it, or else its first variety's. Its strains share its draws: the
  spawner draws the organ by that weight, then a strain by theirs, and fills a body
  with one strain of an organ. **Drift draws the organ evenly** (§9), then a strain by
  weight. With one strain to every organ today, both take the numbers they always took.
- **`one_variant`'s rule** (§6.3 leaves its default to the gene pass): placing or
  integrating a strain of such an organ writes over every other strain of it in the
  DNA, both its places, and empties their slots; the body keeps what it wears until a
  birth. Drift brings no strain of such an organ to a lineage that carries one.
- **An organ's instinct parts are the organ's** (§6.2: a variant changes anything but
  the mechanic): the rulebook's owners are organs, and a variant declares none of its
  own. Every shipped organ goes by its own key, so every name, bit and saved list is
  the one it was, and `by_organ` hands back the dictionary it was given.
- **`toxins_of` reads the dose, not a tag** (§6.4 lists it with the cases that become
  tags): it took a toxin for a key with forms, so a strain of one place would have been
  worn and delivered nothing. It reads any key with a dose, which is what a toxin is.
- **A second strain's lines are required, not derived** (the 1b review's finding 4
  offered both): a stack's line is the organ's to write for each kind of dose, and the
  probe fails a live strain whose kind has none, and a venom without its side and stern
  words, rather than let `figure.gd` fall back to the front line.
- **The gate landed in phase 3** (§12.2 said phase 5), as phase 3's brief asked, as a
  mode of the gene probe rather than a tool of its own. It is the spec's literal match:
  `drop.gd`'s `FOUNDERS`, rule text naming organs' parts (`ampulla.echo`) as a saved
  list does, is no key literal and stays.
- **A water body's dart stun reads its layout** when its genome is written, if it wears
  a dart: its default order, 6 to 11 µs here. It is read only when several organs
  dart, so the layout is made for nothing today, once a write for a body with a dart.

**Checked: nothing changed** (§14), against `71938d6`, at `c56ceb5` -- the last commit
that touched what the game does before the reviews' -- and again at `9144209`, the
last that touches code:

1. Every check `ci.yml` runs passes here but `net_drop` and the door of `net_fuzz`,
   which need a network namespace this container refuses (left to CI, as before).
   None was removed or loosened. The gene probe makes 53 checks, 42 before, and each
   new one was seen to fail on a fault planted in a scratch copy: the water drawing
   only an organ's first strain, a variant built in code losing its organ's parts,
   the smell acting from the catalogue's first nose rather than the first in slot
   order, a body's parts counted by key where a variant has its own, `one_variant`
   writing over nothing, a strain of one place delivering no venom (`toxins_of`'s old
   filter), a strain whose kind of dose has no stack line, a venom with no side words,
   and a stamp of no ids taken; and the gate, on a gene named in `game/`.
2. The empty library hashes to `7397a410…` under all three schemes, 69,349 lines.
   `drop_probe` passes all 143, its ten pins holding -- `DEV_DRAWS` and
   `DEV_MUTATIONS` among them, so the water, drift and the gift draw what they drew,
   number for number.
3. `Wire.RULES` is `46913eab9d0b76a0`, and `net_probe` passes all 441.
4. `DropSave.rules()` is `e4213164b90d…`.
5. **The 34 frames**, rendered at `71938d6`, at `c56ceb5` and at `9144209`: 0 px apart,
   all three.
6. The template is current, 531 messages, its translators' note on a slot rewritten
   with no message changed; `fr.po` is untouched, and `--lint-all` passes.

Also the same, to the byte: the 30,519 answers of every word, line and look; the
stats' and the catalogue's 3,865; the rulebook's vocabulary as the game builds it --
every owner and its bits, every input, output and claim, and what the water and your
instincts wire -- 47 lines; `drive --fingerprint=3000` at seeds 7 and 12345, plain,
sniffing and with seven genes on, the same six hashes and counts; the input path's
three traces; every scene's boot; the levels, Back and fuzz probes; and every script
compiling.

**And a world, a cell mid-choice and a library of four instinct lists kept by
`71938d6`**, the lists naming parts as a saved list does -- `ampulla.echo`,
`myoneme.dash`, `flagellum.hold`, `chemocyte.smell`, `palp.touch`. Opened by `71938d6`
and by phase 3, the 10,261 lines of four seconds are the same. Kept again by each, the
files dump the same and the library is the same bytes; opened again by both, 10,260
lines the same.

**The cost.** The water's step is `drive --field-cost=600 --age=900`, seed 7, a sighted
player of radius 30, p50 in µs: the median of six rounds, three with `71938d6` first and
three with phase 3 first, and the spread of the six, on a machine running nothing else.
`drop_probe` is its whole run, twice each, interleaved.

| | full vision | point of view | `drop_probe` |
|---|---|---|---|
| `71938d6` | 2352 (2262 to 2459) | 2410 (2176 to 2537) | 363 and 371 s |
| phase 3 | 2414 (2256 to 2611) | 2254 (2136 to 2317) | 375 and 369 s |

A first pass at `c56ceb5`, with other probes on the machine, came out the same way:
2505 against 2425 in full vision, 2339 against 2351 in point of view, and 403 and 379 s
against 389 and 379.

**The water's draws are the path phase 3 made dearer, and it was put back.** Drawing
an organ and then its variety asked the catalogue for each key's organ through the key's
record, and worked out a key's weight for every organ's, needed or not. The step's
median does not show it -- a body is drawn when it is made, not every frame -- but
`drop_probe`'s water check in the DNA section, which makes 40,000 drifters and 9,000
peers, took 7.8 and 7.5 s against 4.3 and 3.9. A draw over the drifters cost 58 to 69 µs
against 20 to 25 on this container, and a living peer's genome 180 to 220 against 50 to
60: the water's whole fill at a drop's start, and every peer after. A key's organ and an
organ's keys are one lookup each now (`organ_of`, `keys_of_organ`), and the draws cost
about what they did, 22 to 24 µs and about 66; the check takes 4.4 and 4.6 s against 3.8
and 4.1 in the table's rounds, what is left being the grouping by organ itself.

**And the 1b review's finding 4**, in phase 3 as asked: a second strain of the toxin
said harm's numbers for one stack and its front line on a flank. `toxin.gd`'s stack
line is its own dose's now (`dose_line`), and the probe requires the rest (above).

**And phase 2's review**, which made the owner's two example plan changes in scratch
copies -- an eighth outside slot, and the fore diagonals swapped -- and found the
tooling failing them for the wrong reasons. Each its own commit:

- **F1**: `net_probe` named a genome past the plan's count by `"abcdefghij"[i]`, which
  an eighth slot indexes past; aborting with its host bound, it failed about fifty
  sessions after it. By letter now: on the eighth-slot plan it passes 440, and the one
  that fails is its wire-size pin, which says to move it and the protocol (F6).
- **F2**: the gene probe's broken plans and its synthetic plan started from today's
  plan and its indexes. `SHIPPED_PLAN` pins the rows; the broken plans are made from
  it by place, the synthetic cell is kept under it, and every expectation is written by
  slot id. On both scratch plans only the check that holds today's plan to the pins
  fails, saying what to move; with the pins moved, all 53 pass on both.
- **F3**: `drop_probe` filled "the outside" with seven genes; it fills every slot the
  plan has outside now. On the eighth-slot plan its DNA section fails only the digest
  pin a new ladder moves.
- **F5**: the gene probe fails a plan whose loci run the choosing screen off the canvas
  (§15.3).
- **F6**: until phase 4, a plan change moves `Wire.PROTOCOL` by hand; `body_plan.gd`,
  the gene probe's pin and `net_probe`'s wire-size pin say so where the change is made
  and where it fails -- and that an arcs-only change trips nothing on the wire side.
- **F7**: retiring `pellicle` failed probe checks that posed it by name; they pose the
  first live organ that provides armour now, and §15.3 and §16 say what a retirement
  moves (the drop's pins, `RULES` and the protocol, the template). In scratch copies:
  with `pellicle` retired, the six checks that need an armoured body -- one of
  `drop_probe`'s, five of `net_probe`'s -- fail saying no live organ provides armour,
  and what else fails is the seeded water's pins and the referee's rules; with its
  strain retired beside a second strain that carries armour, they pass, posed with
  the second, and `net_probe` passes all 441.
- **F4** (migration giving a body more live slots than it earned) is recorded in §15.3
  as a call to make before the first plan change. The comments that stated "seven" as
  a slot fact say what the plan says, the translators' note among them, and a stamp of
  no ids is refused.

**Gene names left in `game/`** (§12.2): none. The 17 qualified part names
(`"<gene>.<part>"`) and `drop.gd`'s `TOXIN` are gone, and CI fails on a name.

**Deferred, and to which phase:**

- **4**: the referee and the handshake, untouched here. `Wire.RULES` hangs on the
  tables of every judged stat, every provider's, so a variant that changes one -- the
  faster tail -- moves `PROTOCOL` with it until then, as `CLAUDE.md` says.
- **The gene pass**: a mechanic that acts from every provider of a stat with a place
  (a beam for each eye) is its code to write, in that mechanic, when an organ needs it.
  And the first variant of an organ that declares parts moves every body's parts onto
  `by_organ`'s other path, a dictionary made for each body's rules: the gene probe's
  gland takes that path, but its cost in a full water is unmeasured.
- **Not phase 3's, found while checking F7**: a water cell's division can change
  neither daughter. The changed one tries a trade and a drift, in a shuffled order;
  with every gene at one copy there is no trade, and a drift that picks the inside
  poison to go needs a free outside slot, which a full body at forty has not got
  (`genome.gd`'s `_mutate_drift`). `drop_probe`'s lineage 1 holds that every division
  changes one daughter, and fails on it: once in 1,827 divisions of a scratch water
  with a second armour strain, never in today's seeded waters. A gene change moves
  those waters and can meet it. Whether the drift then picks another gene to go is the
  lifecycle's call (dna-slots.md §5.5).

---

## 16. The playbook (what the gene pass will do)

`game/genes/README.md` is written in phase 5 from what phases 1 to 4 built. In short:

- **A variant**: add an entry to the organ's `variants`, with its key, words, numbers
  it changes, accent and weight. Run the gene probe. Add the French. Render the organ
  beside its nearest neighbours at both sizes. A variant in one place needs no `forms`
  (§6.2), and its tags add to its organ's. It has its organ's instinct parts, read by
  the same readers, and declares none of its own. Two variants of one organ are two
  loci; `one_variant` on the organ holds a body to one (§6.3). A strain of a toxin
  sets its `dose`, and the probe asks for a stack line where its kind has none, and
  for its side and stern words (§6.4).
- **An organ on existing mechanics**: copy the template to `organs/<key>.gd`, set the
  next `order`, fill every field the probe asks for, and add one line to the index.
  Then the same three steps.
- **An organ with a new mechanic**: write the mechanic in `game/mechanics/`, reading
  stats by name. Add its stats to `stats.gd`. Then as above. If it is a sense on no
  existing channel, it brings a membrane lobe (§7.3).
- **Editing a gene**: edit its file. If CI says the rules changed, nothing else needs
  doing: the handshake handles it from phase 4. Until then it is `Wire.PROTOCOL` and
  `Wire.RULES` in the same commit (`CLAUDE.md`) -- a second provider of a judged stat
  is a new line of the rules too -- and a contact table (the gape, the bite, the
  armour, the doses) is `Wire.PROTOCOL` by hand; each such table says so.
- **Retiring a gene**: tag it `retired`. Never delete the file, and never reuse its
  key. A stat only it provided reads its value with no provider, and the probe names
  it. If it was on a list a draw or a bit reads -- a drifter, a sense, the gift, a
  declarer -- every seeded draw moves, and the probe fails until its `SHIPPED_LISTS`
  says so. **And what else it moves fails until it is moved**: `drop_probe`'s pins of
  the seeded water, when it was a drifter; `Wire.RULES`, and `Wire.PROTOCOL` with it,
  when it provided a table the rules list (`net_probe`'s referee check names the
  line); and the translation template, whose room notes are measured with the widest
  gene word, which `i18n_pot -- --write` writes again when `--check` says stale. The
  probes pose a mechanic by its stat -- the first live organ that provides armour --
  so retiring one organ moves them to the next. Retiring the last one that provides
  a stat fails the checks that pose it, saying so: the mechanic has no organ left,
  which is a design call, not a fix.
- **Changing the slots**: edit `body_plan.gd`; saves migrate (§10.3). In the same
  commit, move what holds the plan that shipped: the gene probe's `SHIPPED_PLAN` and
  the pins beside it, and `net_probe`'s wire sizes when the count changes -- both fail
  saying what to move -- and `drop_probe`'s pins of the seeded water, which a change
  of the ladder or the count moves. Until phase 4, bump `Wire.PROTOCOL` too: on a
  change of arcs alone nothing on the wire side fails for it (§15.3, §15.4). First
  settle what §15.3 lists for the first plan change.
- **Balance**: the numbers a gene ships with are starting values with their reasons
  (`CLAUDE.md`, "Balance waits for players").
- **Names**: a gene's key and its words are the owner's call when they are new names
  (`CLAUDE.md`). Look up the real organelle first.

The skill (`.claude/skills/gene/SKILL.md`) is the same list with the commands. It
points at the README and loads when a session is asked to add or change a gene.

---

## 17. Content or binary

All of this is GDScript and data under `game/` and `tools/`. Nothing touches
`project.godot`, adds an autoload, a permission or a plugin. **Every phase ships as
content**, and `binary_version` stays where it is.

Phase 4 changes the wire, not the binary. Like every protocol bump, the dedicated
server takes it when it next restarts empty, and until then builds on either side of
it refuse each other with the version sentence.

---

## 18. Risks, and what to watch

- **A move that changes a number.** §14 is there for it: two fingerprints and a seeded
  run would all have to agree on a mistake.
- **Preload cycles.** The organ files depend on nothing in the game (§4.1). The first
  cycle the builder meets is a design fault to fix in the catalogue, not a `load()`
  inside a function to hide.
- **The size of phase 1.** It is split in two so each half can be reviewed. Within a
  half, one commit per file family keeps the diff readable.
- **A behaviour that depended on dictionary order.** Several loops walk a genome's
  dictionary: the wire's writer stops at nine in dictionary order, and
  `default_order` appends earned genes in that order. The catalogue must not reorder
  any genome. Only the order of its own lists is its own, and the lists a draw or a
  rule's bits read keep the order they shipped in (§9).
- **Work on `dev` in the meantime.** Each phase rebases on `dev` before its pull
  request. Anything that lands on `dev` naming a gene, between phases, is moved by the
  next phase.
