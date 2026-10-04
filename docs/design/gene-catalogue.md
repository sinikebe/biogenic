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

**Status: designed, not built.** This document is the preparation. It turns the
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
	order = 12                               # its place in GENE_ORDER: append-only
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
- **tags**: `tagged(tag)` and `is(key, tag)`;
- **look**, **words** and **water** (§7, §8, §9).

Lookups are dictionaries built once when the catalogue loads. Nothing per frame walks
the whole catalogue. `dominant_of` keeps today's tie-break (the order) through `rank`,
an O(genes worn) loop instead of today's O(every gene) scan. That scan costs 18 µs per
drawn body at 117 genes, against 4 µs at 17, measured on desktop.

The answer must be exactly today's, unknown keys included:

- a known key beats an unknown one at the same tier;
- unknown keys tie-break among themselves in the genome's dictionary order.

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
   that comments explain.
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
first one in slot order, and the stat combines as its row says. A mechanic that should
act from every provider (a beam per eye) is the gene pass's code to write, in that
mechanic, when an organ needs it.

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
- its tags;
- its dose (for the toxin).

The organ owns its mechanic, its shape and its family, so a variant reads as its organ
at a glance and names itself on the pause screen (row 2).

### 6.3 One variant per body: a switch, off

An organ may say `one_variant = true`: placing a second variant of it writes over the
first, as the inside's one poison does today. It is off for every organ today,
because nothing today can carry two. It is a switch the gene pass sets per organ when
it adds variants. The default and the reasoning are the gene pass's call, not this
document's.

### 6.4 What the toxin's special cases become

`Drop.TOXIN`, `take_drifter_gene`, `drifter_genes`, `give_toxin`, `_toxin_short`,
`_give_toxin_back` and `toxins_of` assume one toxin. They become tags on the organ,
which every variant inherits:

- `not_on_drifters`: drifters never carry it, so they stay defenceless food
  (`ocean.md` §5.8);
- `floor_by_peers`: the floor gives it back through peers.

A second strain is then a variant entry, and every one of these rules covers it.

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
then data.

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
| `tags: never_drifts_out` | the literal `cytostome` in `_mutate_drift` | `genome.gd` |
| `born` | `BORN`, `BORN_ORDER` | `genome.gd`, `normal_mode.gd` |

Two more rules:

- **Drift draws through the catalogue**: today an even draw over every live,
  drift-eligible organ that the lineage lacks. The draw is a weight, defaulting to
  1, so it stays even until phase 7 says otherwise.
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

### 10.4 What a plan change costs later

It is an edit to `body_plan.gd`. Saves migrate by §10.3. The wire's limits follow it.
The handshake fingerprint (§11.3) includes the plan, so two builds on different plans
refuse each other with the version sentence instead of misreading each other's slot
orders.

The pause figure and the placing gesture follow the arcs. A plan with more slots than
the figure has room for fails the probe's layout check rather than overlapping in
silence.

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
with the sentence: raise the cap, which changes the rules.

### 11.3 The rules fingerprint goes on the handshake (phase 4)

`Wire.RULES` is the fingerprint of what the referee judges by. From phase 4:

- **It is generated from the catalogue**: every judged stat of every key, plus the
  referee's own limits and today's other lines. A new judged table is in it without
  anyone listing it.
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

### 12.2 No gene names outside `game/genes/`

A grep gate in CI fails on any `&"<key>"` or `"<key>"` literal for a catalogue key in
`game/` outside `game/genes/`. Comments and `tools/` are exempt. It lands in phase 5,
once nothing is left to move. Until then, the probe prints the count.

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
2. **`drop_probe` check 8's hash unchanged** (`7397a410…`, pinned in `ci.yml`): the
   water's seeded run, lineage by lineage, is the same.
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

---

## 16. The playbook (what the gene pass will do)

`game/genes/README.md` is written in phase 5 from what phases 1 to 4 built. In short:

- **A variant**: add an entry to the organ's `variants`, with its key, words, numbers
  it changes, accent and weight. Run the gene probe. Add the French. Render the organ
  beside its nearest neighbours at both sizes.
- **An organ on existing mechanics**: copy the template to `organs/<key>.gd`, set the
  next `order`, fill every field the probe asks for, and add one line to the index.
  Then the same three steps.
- **An organ with a new mechanic**: write the mechanic in `game/mechanics/`, reading
  stats by name. Add its stats to `stats.gd`. Then as above. If it is a sense on no
  existing channel, it brings a membrane lobe (§7.3).
- **Editing a gene**: edit its file. If CI says the rules changed, nothing else needs
  doing: the handshake handles it from phase 4.
- **Retiring a gene**: tag it `retired`. Never delete the file, and never reuse its
  key.
- **Changing the slots**: edit `body_plan.gd`; saves migrate (§10.3).
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
  any genome. Only the order of its own lists is its own.
- **Work on `dev` in the meantime.** Each phase rebases on `dev` before its pull
  request. Anything that lands on `dev` naming a gene, between phases, is moved by the
  next phase.
