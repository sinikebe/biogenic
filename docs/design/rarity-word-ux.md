# How rare a gene is, in one word

The owner, 2026-10-05, answering `gene-rarity.md` §13 as recommended:

> "Recommended"

So **the game tells a player how rare a gene is, in one word, wherever the gene is
named: *common*, *uncommon* or *rare***. This is the design of that word: where it
sits, how it looks, its French, and what the build changes. It is built in phase 7-2
(`gene-rarity.md` §11.2), on phase 7-1's `Catalogue.rarity_of(key)` (§2.4 there).
Today no gene is rare, and the first one arrives with the gene pass. The word is there
for that gene: a player who reads *rare* learns its look and can hunt the next one
(§7 there).

**Status: designed, prototyped and photographed; not built.** It was prototyped in a
throwaway copy of the code at `cec8ff9`, with a stand-in for `rarity_of`: the born
three and the nose common, every other gene uncommon, and any gene forced rare by an
environment variable. Every frame in §6 was rendered at 1280x720 and 2400x1080, in
English and French, under `--rendering-driver opengl3 --fixed-fps 60 --seed=12345`,
and looked at. The prototype is not in the repository. `$N` below is the design
session's notes folder (`scratchpad/genes/notes/ux7/`), which is not in the repository
either: `$N/shots/` holds the frames, `$N/bin/` the commands that made them and
`$N/mock.patch` the prototype.

---

## 0. Decided, in one place

1. **The word starts the row under the gene's line** (the hint row), on every screen
   whose line names a gene: the pause screen, the choosing screen and a cell's
   detailed view. For example: `uncommon · two copies · a daughter probably wears it`.
   §1.
2. **It is not put beside the name, because that row is full.** In French its widest
   line is 562 px, in a 560 px column. §1.2.
3. **It uses the row's own type:** 14 px, lowercase, the game's font. It has no
   capitals, no badge, no colour, no glyph and no motion. §2.
4. ***Common* and *uncommon* use the caption's tint, and *rare* uses the level's:**
   `Color(0.855, 0.953, 0.933, 0.45)` and `Color(0.855, 0.953, 0.933, 0.66)`. *Rare*
   is about as bright as the gene's own sentence, and dimmer than any number's value.
   The other two are one step brighter than the odds that follow them. §2.
5. **It belongs to the gene the line names**, in every state of the row: a waiting
   gene in hand, a toxin not yet placed, the gene that a tap would write over, and the
   beam with its fork open. When no gene is named, there is no word. §4.
6. **The words are `common`, `uncommon` and `rare`, under the context `rarity`.** In
   French they are **`commun`, `peu commun`, `rare`**, masculine singular to agree
   with *le gène*, as `porté` already does. §3.
7. **One French string gets shorter**, the fork's hint, so that the beam's row still
   fits with the word in front of it. §1.4.
8. **The word appears nowhere else.** That covers the chips, the tray, the loci, the
   verb line, the instincts page, a body in the water, the membrane's flood and the
   bloom. §5.
9. **It ships as content.** It touches GDScript, one scene and the catalogs. It
   needs no binary and no wire change, and no rule the referee copies.

**There is no owner's call.** The three words are the owner's own. Placement, type,
tint and the French are the designer's to decide.

---

## 1. Where it goes

### 1.1 At the head of the row under the line

```
1280x720, pause, a waiting ping in hand                       column x 508 .. 1068
y 552   [organ] ampulla · a pulse that answers off everything, not just food      [ numbers ]
y 586                rare · one copy · a daughter may not wear it
y 614                      tap a slot · your daughters may wear it
```

- **It belongs to the gene's own block.** The line above names the gene and says
  what it does. This row says what kind of find the gene is, and then what it is
  worth to a daughter. The reading order is the screen's own: *name → what it does
  → how rare, how many copies, what a daughter gets → what to do*.
- **It is the first word under the name.** It sits in the row the eye drops to
  next, with no extra line and no new place to learn.
- **It is the one row with room to spare** (§1.4).

### 1.2 Why not beside the name

Measured in the game's own font (`ThemeDB.fallback_font`, as the lint measures):

- **The name's row is full.** It holds the organ (34 px), the name and the line. It
  is up to 490 px wide in English (`chemocyte`) and **562 px in French**
  (`cytostome`), in a 560 px column, with the `numbers` switch 16 px to its right.
  The word would need 60 to 96 px more.
- **A line of its own has no height to use.** The tightest pause screen, with two
  tray rows and numbers on, already ends 12 px above the screen's edge
  (`gene-stats.md` §3.2).
- **A chip has 47 px for its word**, and it already carries the pips, a variant's
  accent and a level.

### 1.3 The three screens

| screen | row | today | with the word |
|---|---|---|---|
| pause | `Hud/Pause/Center/Columns/Genome/Lines/Stack/Hint`, an `HBoxContainer` | `[Level][Gauge][Text]` | **`[Rarity][Level][Gauge][Text]`** |
| choosing | `Hud/Choosing/Says/Hint`, a `Label` | one label | **an `HBoxContainer` `Hint`: `[Rarity][Text]`** |
| a cell's detailed view | `cell_figure.gd`'s `Hint` row, built in code | `[Level][Gauge][Text]` | **`[Rarity][Level][Gauge][Text]`** |

```
Hud/Pause/Center/Columns/Genome/Lines/Stack/Hint   HBoxContainer   unchanged: min (0, 20), separation 6, ALIGNMENT_CENTER
  Rarity   Label    NEW, first child: 14 px, MOUSE_FILTER_IGNORE, min (0, 19), hidden
  Level, Gauge, Text                               unchanged
Hud/Choosing/Says/Hint                    HBoxContainer   WAS a Label: min (0, 19), separation 6, ALIGNMENT_CENTER, IGNORE
  Rarity   Label    NEW: as above
  Text     Label    the old Hint, moved: 14 px, Color(0.855, 0.953, 0.933, 0.38), min (0, 19), SIZE_FILL
```

- **The row puts `· ` at the start of every label that follows another.** That way
  each separator keeps the row's own tint, and only the word wears its own. Today
  `Text` gains `· ` after a level. It now gains it after the word too, and `Level`
  gains it after the word.
- **`Text` is `SIZE_FILL` whenever something shares the row**, whether the word or a
  level, so that the row centres as one group, as it does beside a level today.
  When `Text` is alone it stays `SIZE_EXPAND_FILL`, as today.
- **The choosing row keeps its height** of 20 px, so `Says` lays out as it does
  today. `_choose_hint` now points at `Hint/Text`. drive.gd's `--rects=` name
  `SaysHint` still finds the row.
- **The word takes no input.** It has no focus and no hover, so it needs no 48 px
  target. It follows whatever the row is reading, whether by tap, hover or focus.

### 1.4 Room, and the one place it is tight

Each row below is built whole and measured at 14 px, in its widest case:

| row | English, today → with the word | French, today → with the word |
|---|---|---|
| pause, no level: `uncommon · two copies · …` | 279 → 370 | 350 → 453 |
| pause, the beam: `uncommon · level 20 ▬ · two copies · …` | 386 → 477 | 470 → **574** |
| pause, the fork open: `uncommon · level 20 ▬ · works as level 3 until you choose` | 329 → 420 | 519 → 623, **545 with the shorter French** |
| choosing: `uncommon · carried · level 20 · two copies · …` | 400 → 491 | 509 → 613 |

- **The pause row's room becomes 576 px, measured whole.** That is the 560 px
  column plus 8 px on each side. It stops 8 px short of the `numbers` switch's left
  edge, and the switch's slab ends at y 580, above the row's ink at y 590. The
  widest French row, the beam at level 10 or more with two copies, measures 574 px.
  As built in the prototype (`m1_beam`), `Stack` grows to x 501..1075, centred.
  `Lines`, the column and the switch do not move, and nothing else moves either.
- **The fork's French hint gets shorter.** It is the only row that would not fit.
  `fonctionne comme niveau %d jusqu'à ce que vous choisissiez` (399 px, 80 % longer
  than its English) becomes **`fonctionne comme niveau %d jusqu'à votre choix`**
  (320 px). With the word, its row measures 545 px (`m1_fork`).
- **The choosing row has the whole screen, below the strands.** Its widest case,
  613 px, uses about half the width it has.
- **On a phone nothing reflows.** At 2400x1080 the canvas is 1600 x 720. The column
  centres 160 px further right, and the word is drawn at 21 device px.
- **A body with many genes changes nothing**, because the screen reads one gene at a
  time.

---

## 2. The look

| class | `font_color` | which is | peak glyph luma, 1280x720 |
|---|---|---|---|
| common, uncommon | `Color(0.855, 0.953, 0.933, 0.45)` | `Figure.CAPTION_TINT`, the caption's tint, also used by `waiting` | 114 |
| rare | `Color(0.855, 0.953, 0.933, 0.66)` | `Figure.LABEL_TINT`, a chip word's tint and the level's | 161 |

Here is the same measure (Rec. 709 luma on the 8-bit frame, as `gene-stats.md` §3.3
measures it) for the text around the word:

| text | peak |
|---|---|
| the odds, which the word leads | 98 |
| the gene's name, in sensing violet | 136 |
| the gene's sentence | 153 |
| a value among the numbers (`gene-stats.md` §3.3) | 170 |

- ***Common* and *uncommon* are one step brighter than the odds.** That is enough
  for the word to read as the head of the row, and not as part of `a daughter may
  not wear it`.
- ***Rare* is about as bright as the gene's own sentence (161 against 153), and
  dimmer than any value.** `gene-stats.md` §3.3 held the numbers' values to 170 so
  that a detail would not sit above its headline, and this word is a detail too.
  Brighter versions were tried (`study_tints`). At 0.85 (peak 204) and at 0.92 (peak
  220), *rare* was the brightest text in the gene's block, brighter than its own
  sentence, and it read like a prize. At 0.62 for *rare* with 0.38 for the other two
  (152 and 98), *uncommon* sank into the odds.
- **It has no colour, because every hue on this column already means something.**
  The five family bands are used, and the name is drawn in one of them. Teal means
  *this responds* (the switch, the verb line, the focus mark), amber means light,
  red means threat, and food is green. A gold *rare* would be metabolism's colour.
  A pale word competes with no family.
- **It is a step in brightness, so it survives greyscale and colour blindness**
  (`study_grey`).
- **It is honest.** *Rare* says how seldom the water makes a gene, not how good the
  gene is. So the word is not dressed as a prize: no capitals, no glow, no star, no
  animation and no sound. It is the same word in the same place, a little brighter.

---

## 3. The words

| `msgctxt` | `msgid` | French | width at 14 px, English / French |
|---|---|---|---|
| `rarity` | `common` | `commun` | 60 / 60 |
| `rarity` | `uncommon` | `peu commun` | 78 / 90 |
| `rarity` | `rare` | `rare` | 29 / 29 |

**Where they live.** They go in `game/genes/rarity.gd`, the one file that names a
class (`gene-rarity.md` §2.4). They sit in a table of their own, keyed by class
(StringName keys, as an organ's `WORDS` are). They do not go in `LADDER`'s rows:
a `TRANSLATORS:` note there would make the translation tool extract every plain
string in the rows, `"class"` and `"weight"` included.

```gdscript
## TRANSLATORS: How often the water makes a gene, in one lowercase word at the start
## of the line under the gene's name on the pause and choosing screens: "uncommon ·
## two copies · a daughter probably wears it". Commonest first. It says how seldom
## the gene is found, not how good it is: a field guide's words. An adjective about
## the gene (in French "le gène": "commun", "peu commun", "rare").
## ROOM: 100 px at 14 px
## CONTEXT: rarity
const WORDS := {&"common": "common", &"uncommon": "uncommon", &"rare": "rare"}
## The classes a screen marks as the hunt: their word is drawn brighter
## (docs/design/rarity-word-ux.md §2). Today the rarest.
const MARKED := [&"rare"]
```

- **The context `rarity`.** These are bare adjectives, and French agrees them with
  the noun. A gene is masculine (`commun`), a cell feminine (`commune`). This is
  exactly the i18n README's case for a context: the same English spelling, said
  differently.
- **Why `commun`, `peu commun`, `rare`.** It is the field guides' scale (French flora
  and bird atlases count species as *commun*, *peu commun*, *rare*), and it is the
  ladder French players know from games. The words are masculine singular because
  the hint row speaks of *le gène*, as `porté`, `transporté` and `le porter` already
  do, the toxin included. Four other options were rejected:
  - `courant`, because in a water game it is also *a current*;
  - `répandu`, because it also means *spilled*, beside a poison;
  - `fréquent`, because it reads as how often something happens;
  - `inhabituel`, because it is not a word for how often a thing is found.
- **A fourth class later** needs one row in `LADDER`, its word here, and its French.
  The gene probe asks for all three (§7).

---

## 4. Which gene, in every state of the row

**The word always belongs to the gene whose name the line shows.** On the pause
screen that is the gene `_update_explain()` passes to `Figure.explain_name()`. It is
not `_explain_gene`, which is empty for a toxin not yet placed.

| state | the line names | the word |
|---|---|---|
| a slot read by tap, hover or focus | its gene | that gene's |
| pause opens with a gene waiting, in hand | the waiting gene | its own (`m1_wait`) |
| a toxin in hand, no slot chosen (`toxicyst · …`) | the toxin | its variety's (`m1_toxin`) |
| armed over an occupied slot | the gene under it | **the gene under it**: `rare · sting leaves your dna · your body keeps it` (`m1_loses`) |
| a tap that adds a copy elsewhere | the target form | its own |
| the beam's fork open, a way read | `ocellus`, or the way's title | the beam's, throughout (`m1_fork`) |
| a variant | `organ · variant` | `rarity_of`: the rarer of organ and variant |
| a locus on the choosing screen | her gene | its own (`m1_choose`) |
| an empty slot or locus, or nothing read | nothing | no word |
| a key this build does not know, or a retired one | its name | **no word**: the water does not make it |
| a record in the detailed view | its gene | its own, dimmed with the figure (`RECORD_ALPHA`) |

**When the language changes**, the pause screen says its rows again through
`_build_genome_strip()`, and the word goes with them. The choosing screen cannot
change language in the middle of a division, because pause is refused then.

---

## 5. Other places a gene is named

| place | how it names the gene | the word? | why |
|---|---|---|---|
| **a cell's detailed view** (`cells-ux.md` §3.3) | the same line, `Figure.explain_name` | **yes** (`m1_detail`) | It is the pause screen's genome group, read-only. If it were left out, the same line would say less on one of its two screens. |
| slot chips, tray chips, the choosing loci | the short word (`ping`) | no | These are glanced at, and have 47 px. The line under the figure names the gene the chip stands for, and pause opens with the waiting gene in hand. |
| the verb line and the hint's warnings (`tap again to write ping over sting`) | the short word, in a sentence | no | The word already starts the row above. |
| in point of view, the flood as a gene is eaten | the family's colour | **no difference for rare** | The membrane carries what the cell feels, and a cell cannot feel how rare something is. A special flood would be the lottery chime the owner ruled out. Pause opens on the waiting gene, which is where the word is. |
| in full vision, a body | its organs | **no mark** (`gene-rarity.md` §7.2) | The word exists so that the gene's look can be learned. A mark a few pixels wide would compete with the variants' accents. |
| placing from the water, the bloom (`dna-body.md` §8) | the organ's tile | no | It is in the playfield, where there are no letters (`diegetic-hud.md` §3). |
| the instincts page | a sense's word (`echo`, `smell`) | no | It names what a sense reports, not a gene. |
| the replay, the shared pond, the death | none | — | |

---

## 6. Rendered and judged

The frames are in `$N/shots/` as `<frame>_<en|fr>_<1280x720|2400x1080>.png`. `now_`
is today's code, and `m1_` is the prototype with §2's tints. The studies are crops at
twice the size. **Three renders of `m1_waitrare` differ by 0 pixels** (`det1` to
`det3`). **Against today's frames, only the hint row changes.** For the same pose,
2,368 px differ at 1280x720, all inside y 590..603. At 2400x1080 it is 6,209 px, all
inside y 885..906. On the choosing screen it is 2,651 px, all inside y 634..647.

| frame | what it shows | judged |
|---|---|---|
| `now_wait`, `now_beam`, `now_sting`, `now_choose` | today: a waiting gene in hand, the beam's fork, the sting read, the choosing screen | the starting point |
| `m1_wait` | a waiting ping in hand, uncommon | **passes**: the word starts the row, and nothing else moves |
| `m1_waitrare` | the same gene, forced rare | **passes**: *rare* is found at a glance, and the name, in its family's colour, still leads the block |
| `m1_common` | the smell chip read, common | **passes** |
| `m1_waitnum` | numbers on, rare | **passes**: the row sits two lines lower and still starts with the word |
| `m1_tight` | two tray rows and numbers on, the tightest pause screen | **passes**: `Act` still ends at y 708 |
| `m1_beam` | the beam at level 20 with two copies, the widest row | **passes**: 574 px in French, 7 px past the column on each side and 9 px short of the switch |
| `m1_beamrare` | the beam forced rare, at level 7 | **passes**: `rare` and `level 7` share the level's tint |
| `m1_fork` | the fork open at level 20 | **passes** with the shorter French, at 545 px |
| `m1_loses` | a ping in hand, armed over a rare sting | **passes**: the warning says what is about to be lost |
| `m1_toxin` | a toxin in hand, no slot chosen | **passes** |
| `m1_chooseopen`, `m1_choose`, `m1_chooserare` | the choosing screen as it opens (the mouth, common), and the port daughter's poison, uncommon and rare | **passes**: `rare · worn · one copy · …` |
| `m1_detail`, `m1_detailrare` | a cell's detailed view with its beam read | **passes**: the pause screen's row, read-only |
| `study_tints`, `study_tints2` | five tint pairs side by side | the reasons for §2's choice |
| `study_grey`, `study_grey_choose` | the rows in luminance only | *rare* still stands out |

---

## 7. Build checklist (phase 7-2)

1. **`game/genes/rarity.gd`**: add `WORDS` and `MARKED` as in §3.
2. **`tools/gene_probe.gd`**: check that every class in `LADDER` has a word, every
   word names a class, and every class in `MARKED` is one.
3. **`game/normal/figure.gd`**: add `rarity_word(key)`, the word in the player's
   language (`TranslationServer.translate(WORDS[class], &"rarity")`), or `""` for a
   key with no class or not live. Add `rarity_tint(key)`, which is `LABEL_TINT` for
   a class in `MARKED` and `CAPTION_TINT` otherwise. Add one function that builds the
   row by §1.3's rule, for all three screens.
4. **`game/normal/normal_mode.tscn` and `.gd`**: build §1.3's tree. Set the word in
   `_update_explain()`, for the gene it names, and in `_choose_say()`. `_set_hint()`
   builds the row.
5. **`game/menu/cell_figure.gd`**: add the same word to its `Hint` row.
6. **The words.** Regenerate `game/i18n/biogenic.pot` (`--write`). In `fr.po`, add
   the three `rarity` entries, and the shorter fork hint (§1.4).
7. **`tools/i18n_pot.gd`**: measure the pause hint row whole, as SCREENS does, at
   **576 px**. Build it from the widest word, then `· level 20`, the gauge and its
   gaps, then each text that shares the row with a level. Those texts are
   `HINT_CHANCE`, `HINT_WORKS_AS`, `HINT_BOTH_NEXT` and the cost lines, with the
   widest way. Build it without a level for `HINT_CERTAIN` and the `HINT_LOSES`
   lines. Lower those texts' `ROOM:` from 430 to 350 px, which is what the built row
   leaves them beside the widest word and level. In `game/i18n/README.md`, add the
   word and the built row to the room table, and correct the sentence about the rows
   under the figure.
8. **A rare gene to photograph.** In `tools/looks_specimens.gd`, the ringed eye
   `ocellusb` sets its own `water.rarity` to `rare` (`gene-rarity.md` §2.4). That
   gives the rare case on today's content as `--specimens=1 --sample=ocellusb`, and
   it exercises the variant rule too. `drive.gd`'s `--rects=` names the two `Rarity`
   labels.
9. **Run** `--lint-all` and `gene_probe`. Nothing in the water changes because
   of the word, so the seeded pins do not move for it.
10. **Photograph §6's frames from the build** at both sizes and in both languages,
    with the rare case through the specimen. Check them against `$N/shots/` and
    the numbers in §1.4 and §2. The detailed view shares the word's code, so it is
    shot uncommon only.

**7-2's title** is a line of the patch note, so it could gain *"…, and the pause and
choosing screens say how rare each gene is"*.

---

## 8. Left open, and what to watch

1. **Does the word get noticed?** Watch whether a player who catches a gene reads
   *uncommon* at all, and whether *rare* is seen the first time it appears. If
   *rare* is missed, the lever is its tint. It should not go above 0.70 (peak 170,
   the numbers' values).
2. **Is *rare* read as *better*?** If players place rare genes for that reason, the
   words are doing harm, and the honest fix is in the gene's own sentence, not a
   louder word.
3. **`commun` beside two daughters.** On the choosing screen a French player could
   read `commun · porté` as *shared by both*. If playtests show that, the fallback
   is `fréquent` / `peu fréquent` / `rare`.
4. **Telling a player they caught something rare** before they pause. The pause
   target's breath (`beam-levels.md` §8.4) is an existing, quiet channel for it.
   It is not proposed now: the owner's answer names the screens, and the hunt
   works without it.
