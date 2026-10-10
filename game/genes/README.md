# Genes

Every gene the game knows lives here: each organ in a file of its own, the index
of those files, the stats a mechanic reads off a body, and the body plan's slots.
Everything else -- the genome, the water, the referee, the screens, saves, the wire
-- asks the catalogue by key, by stat, by tag or by channel, and never names a gene.
So **the gene pass is edits to this folder**: a variant is one entry, an organ on
mechanics the game has is one file and one line, and CI says what is missing.

The design and its history are `docs/design/gene-catalogue.md`; this is the
playbook (its §16). The words: an **organ** is what a gene builds; a **variant** is
the organ built differently, with its own numbers, name and place in the water; a
**form** is a variant in one place (outside or inside); a **key** is one form's
permanent name, what the DNA, saves and the wire hold; a **variety** is a variant's
first form; a **stat** is a number a mechanic reads off a body; a **tag** is a fact
other systems ask.

| File | What it is |
|---|---|
| `gene.gd` | The shape of one organ: every field, its default, who reads it. Read it before writing an organ. |
| `catalogue.gd` | The index (`ORGANS`, one `preload` per organ file) and every question asked of a gene by key. `SHIPPED_ORDERS` pins the order four lists shipped in; the gene pass never edits it. |
| `stats.gd` | One row per stat: its value with no provider, which way is better, how providers combine, its unit, whether the referee judges it, whether the host decides a contact by it, the group a mechanic reads it in. |
| `body_plan.gd` | The slots: how many, where, what kind, when earned. |
| `organs/<organ>.gd` | One organ, its variants and their forms, its words, its look and its numbers on the pause screen. `rhabdom` and `statocyst` are retired. |

## The checks

From the project root, with Godot installed as `CLAUDE.md` says ("Run it"). Each
probe prints one line per check and passes only on its marker -- grep for it, as CI
does, because Godot exits 0 after a script error too -- and with no `SCRIPT ERROR`
line anywhere in its output: CI fails most of these steps on one even under the
marker.

```
# Once, and again after adding a file: import the project. The import rewrites
# project.godot -- reorders it, drops a default -- so put it back every time: a change
# there is a new binary (CLAUDE.md), and a gene is content.
xvfb-run -a ~/godot/godot --path . --import
git checkout -- project.godot

# The genes (CI's "Check the genes"): ends "[gene-probe] ALL PASS". Seconds.
timeout 120 ~/godot/godot --headless --path . res://tools/gene_probe.tscn

# No gene named outside game/genes/ (CI's "Check the gene names"): "[gene-names] ALL PASS".
timeout 120 ~/godot/godot --headless --path . res://tools/gene_probe.tscn -- --names

# The translation template: write it again after any change to words, then check it
# and every catalog (CI's two translation steps): "[i18n] ALL PASS" for each.
~/godot/godot --headless --path . res://tools/i18n_pot.tscn -- --write
timeout 120 ~/godot/godot --headless --path . res://tools/i18n_pot.tscn -- --check
timeout 120 ~/godot/godot --headless --path . res://tools/i18n_pot.tscn -- --lint-all

# The drop -- the seeded water, its pins and its rules (CI's "Check the drop"):
# "[drop-probe] ALL PASS". About six minutes.
timeout 600 ~/godot/godot --headless --path . res://tools/drop_probe.tscn

# The referee and the rules two builds must agree on: net_probe's referee section,
# "[net-probe] NOTE --referee-only: 0 failed". CI runs the whole probe, the same line
# without "-- --referee-only", and greps "[net-probe] ALL PASS".
~/godot/godot --headless --path . --quit-after 24000 res://tools/net_probe.tscn -- --referee-only
```

Two network probes on one machine call each other's servers. Run them one at a
time, or each in a network namespace of its own, with an address on it besides
loopback -- net_probe's pond referee fails without one. Any private address does;
CI's, `10.77.0.5`, is made up:
`unshare --net -- bash -c 'ip link set lo up && ip addr add 10.77.0.5/24 dev lo && <command>'`.

**And look at it** (`CLAUDE.md`, "Nothing is done until someone has looked at
it"). `tools/shot.tscn` photographs any scene, `tools/drive.tscn` poses a run --
`--genome=key:copies:slot,...`, `--mode=1` full vision, `--mode=0` point of view,
`--esc-at=1.0` the pause screen, `--numbers=1` its numbers -- at 1280x720 and at
2400x1080. `--fixed-fps 60` steps the game at sixty frames a second however fast the
machine runs, so the same pose is the same frame twice; without it, two renders of one
pose differ, and a comparison between two builds measures the machine:

```
xvfb-run -a -s "-screen 0 2400x1080x24" ~/godot/godot --path . --rendering-driver opengl3 \
    --fixed-fps 60 res://tools/shot.tscn -- --scene=res://tools/drive.tscn --size=1280x720 \
    --out=/tmp/gene-1280.png --wait=4.0 --seed=7 --mode=1 --radius=39.5 \
    --genome=cytostome:2:0,cirrus:2:1,flagellum:3:2,<key>:2:3 --freeze-at=3.0
```

Render the gene beside its nearest neighbours -- the organs of its family, on
`tools/looks_sheet.tscn` (**Looks**) -- in full vision, in point of view and on the
pause screen, at both sizes. The pause screen arms a slot or a way by the wall clock
(`normal_mode.gd`'s `ARM_TIMEOUT_MS`), so a pose that arms one and waits can lapse on a
busy machine: render such poses on a quiet one, or both builds under the same load.

## A variant

A faster tail, a second strain of the toxin. **One entry** in the organ's file: the
organ's own key is its first variant, implicitly, and never leaves the catalogue.

1. **Name it** (below): its key, 1 to 16 letters `a-z`, permanent once shipped.
2. **Add the entry** to the organ's `variants`, in `_init()` -- the list starts there
   when the organ has none:

   ```gdscript
   variants = [
   	{"variant": &"swift", "key": &"swiftail", "order": 17,
   		"look": {"accent": &"disc"},
   		"provides": {&"impulse_speed": [118.0, 160.0, 190.0, 220.0], ...}},
   ]
   ```

   - **`variant`**, a name of its own: the organ's own key is the variant with none.
   - **`order`**, the next one, which the gene probe names. Without one it would take
     its organ's and tie it in `dominant_of`, and the probe fails it, saying so.
   - **What it changes**, and nothing else: it takes every field it does not set from
     its organ. A dictionary field -- `provides`, `water`, `numbers`, `look` -- is
     written over key by key, so a stat it names in `provides` takes its table whole
     and the rest keep the organ's. **Tags add up**: a variant's tags join its
     organ's, never replace them.
   - **`born`** is 0 unless it says otherwise: a newborn wears the organ, not both.
   - **Its place in the water**: the water draws an organ first, then one of its
     varieties by `water`'s `weight` -- the variant's share of its organ's draws.
     `drifter` says whether a drifter may be made of it. **Drift may bring it** to a
     lineage whatever its water says, unless it is tagged `never_drifts`. **A variant
     of a sense is a sense, and a gift**: it inherits both tags, so the water may give
     it to a peer or a daughter born with no sense, and your newborn may be given it
     at five seconds, whatever its water and drift say.
   - **Two places** take `forms`: place to `{"key": ..., "order": ..., ...}`, each
     form keyed and ordered, the first its variety. A variant of one place needs none.
   - **A strain of a toxin** sets its `dose`. The probe asks for a stack line where its
     kind of dose has none, and for a venom's side and stern words.
   - **Its parts are its organ's**: it declares none of its own, and every reader of
     the organ's parts reads it.
3. **Its words**: its key in the organ's word tables -- `WORDS`, `EXPLAINS`,
   `VARIANT_WORDS` (its own word after its organ's name on the explaining line,
   `toxicyst · paralysing`), and whatever else the organ's keys have
   (`EXPLAINS_SIDE`, `CARRIED_WORDS`...), each with the TRANSLATORS note, ROOM and
   CONTEXT the table has.
4. **Its look**: an accent, `"look": {"accent": &"ring"}`, and nothing else of a look
   (**Looks**, below).
5. **The pins**: append its key to `tools/gene_probe.gd`'s `SHIPPED`, and to each list
   of its `SHIPPED_LISTS` it joins by the tags and water it has: `drifter` (a variety
   whose water says `drifter`), `sense`, `gift`. The probe fails until it is there.
6. **The template**: `i18n_pot -- --write`, then its French in `game/i18n/fr.po`. The
   gene probe lists every gene word with no French.
7. **The rules**: a variant that provides a stat a row marks `judged` or `contact` is a
   new line of the rules two builds must agree on (**Editing a gene**) -- and, for a
   mechanic with a place (`SEATED`), the second organ of it adds the line naming its
   seat. **A variant of a sense moves them whatever it provides**: it inherits `gift`,
   and the gift's list is in the rules (`run.FIRST_SENSES`), since the referee lets a
   guest's body gain one of them. And the referee's caps are held over every provider
   of a judged stat: one past them -- a tail faster than the speed cap -- fails
   net_probe's check of the caps until they move, which is a change to the referee's
   own limits and needs the false-positive runs of `docs/design/net-hardening.md`
   again (`CLAUDE.md`).
8. **The seeded runs**: every new key adds its column to the drop probe's lineage
   pins, and a gene the water, drift or a sense's draws can make moves what the water
   draws (**Editing a gene**).
9. **Run the checks, render it, and look.**

**Two variants of one organ are two loci**, each with its own copies. If a body may
carry only one, set `one_variant = true` on the organ: placing, a meal, a lapse and
the water then write over the variant it carried, and drift and the gene floor never
give it a second. **No screen says so yet.** `genome.gd`'s `placing()` reports the key
a write would take out, as its third element; the words a player is told -- on the
armed slot's line, say -- wait for the first organ that turns the switch on, and are
written with it, with their TRANSLATORS notes and their French.

## An organ on mechanics the game has

A new nose, a new armour: everything it does, some mechanic already does.

1. **Copy the shipped organ nearest it** to `organs/<key>.gd` -- `crista.gd` for an
   organ of one stat, `palp.gd` for a sense with a part. Set every field the probe
   asks for: `organ`, the next `order`, `provides` (a table per stat, `TIER_MAX + 1`
   entries, the first the stat's value with no provider), `water` (its `weight`, and
   `drifter` when a drifter may be made of it), `tags`, `channel` for a sense, `family`
   and `look` (**Looks**), the words and `lines` (its numbers on the pause screen).
   Write the comment the other files have beside each table and number.
2. **Add one line to `catalogue.gd`'s `ORGANS`**, after the last live organ. The probe
   fails on a file the index lacks, or a line with no file. Import again: Godot writes
   the file's `.uid`, which is committed beside it, as every organ's is -- never
   written by hand.
3. **Parts it declares** (`declares`) need a reader or a trigger in a water cell
   (`food.gd`'s `wire_parts`) and in yours (`own_rules.gd`), wired by the part's
   name, and their words (`GENE_SAYS`, `GENE_SENSES`, `GENE_EXPLAINS`, and
   `GENE_ASLEEP` and `GENE_NEEDS` for a part that waits for a level). The probe fails
   a part nothing wires. A declaring organ joins `SHIPPED_LISTS`' `declares`.
4. **Then steps 5 to 9 of a variant.**

## An organ with a new mechanic

1. **Write the mechanic** where its system lives -- `game/mechanics/` for one that
   knows no body -- reading **stats by name** (`Stats.of`, or `Stats.seated` for one
   that acts from a place) and finding its organ by stat, tag or channel
   (`Catalogue.worn_provider`, `Stats.organ`, `Catalogue.worn_on`, `Catalogue.tagged`).
   Never by a gene's name: the gate fails it.
2. **Add its stats to `stats.gd`'s `ROWS`**, each with every field:
   - `none`, its value with no provider -- every table's index 0;
   - `better`, `higher` or `lower`;
   - `combine`, how a body wearing several providers has it: `best`, `sum` (from 0) or
     `product` (from 1);
   - `unit`, for the pause screen;
   - `judged`: the host's referee judges a guest by it -- its speed, its turn, its
     call. The referee's caps are held over every provider;
   - `contact`: the host decides a contact by it -- a mouth, a skin, a bite, a dose;
   - `group`: the first stat of the stats a mechanic reads together, `&""` for one
     read alone. A body wearing two providers takes a whole group from the one best on
     its first stat -- or, where its mechanic acts from a place, from the one it acts
     from (step 3) -- never stat by stat, so every organ that provides one stat of a
     group provides all of it, and a group's stats combine by `best`. The gene probe's
     `TOGETHER` pins the groups as the rows give them: a new group goes there too.

   A row marked `judged` or `contact` is in the rules the handshake carries
   (**Editing a gene**).
3. **A mechanic that acts from a place** -- an arc it looks along, a slot it leaves
   from -- adds its stat to `stats.gd`'s `SEATED`. **Every number it uses is then the
   one organ's it acts from**, the first in slot order, never the best of two: its
   arc, its tier, its own numbers and its stats, the seated one and every other of its
   group, all read through `Stats.seated` with the body's slots -- and the referee's
   copy too, where it judges one. A bound -- the most a body's senses could reach -- is
   no mechanic, and reads `Stats.of`. The gene probe holds the dart and the radar to
   it, two of each worn both ways round.
4. **A sense on a new channel** is code: a lobe in `signal_bus.gd`, the membrane's
   shader and the replay's block (spec §7.3). Every lobe is taken today.
5. **Then the steps of an organ on mechanics the game has.**

## Editing a gene

**Edit its file.** A key never changes, and neither does a shipped gene's `order`:
it is the tie-break of what a body is drawn as and what eating it gives.

- **The rules.** When a number a row marks `judged` or `contact` changes -- or that
  row's `none`, `better`, `combine` or `group`; or a provider of one is added or
  retired; or the gift's list changes, which a variant of a sense does; or, once two
  organs provide a stat of `SEATED`, which stats act from a place; or the body plan
  changes -- the rules two builds must agree on change, and net_probe's referee
  section fails:

  > the rules two builds must agree on changed -- they fingerprint to `<new>` now, and
  > Wire.RULES says `<old>`...

  If that is meant, set `game/net/wire.gd`'s `RULES` to the new value in the same
  commit, and nothing else. **Never `Wire.PROTOCOL`**: it moves only when a message's
  format does. The handshake carries the rules' fingerprint, so builds on other rules
  refuse each other there, with the version sentence. A player on the old content
  cannot play with one on the new until the older updates: say so in the patch note's
  line when a player can tell.
- **The seeded runs.** A gene the water or drift can make -- a drifter, any live
  variety not tagged `never_drifts`, or a sense, which the water gives a peer or a
  daughter with none, and your newborn as its gift, whatever its water and drift say
  -- changes what a seeded water draws: the drop probe's pins of it (`DEV_LINES`,
  `DEV_DRAWS`, `DEV_MUTATIONS` and the rest) and `ci.yml`'s empty-library hash. And
  every new live key, made or not, adds its column to the lineage lines four of those
  pins hold (`DEV_LINES`, `THREE_ONE_LINES`, `PACK3_LINES`, `TAIL_LINES`): `<key> 0.00`
  where nothing wears it. Each pin prints what this build gives where it fails, and
  each is recorded again from that output in the same pull request, with a line saying
  why.

  **A key that never drifts, is no drifter and no sense** is one nothing in a seeded
  run can make: it leaves the water's every draw as it was. It moves only that column
  -- and fails the drop probe's lineage 4, which holds that the water carries every
  live variety at every census: a gene the water can never make is a new kind of
  gene, and that check is the gene pass's to change, saying why. Anything else that
  moves is a draw that counts the catalogue's keys: a bug to find, not a pin to record.
  A pin in a workflow is the lead's to move: a session edits `.github/workflows/`
  only when asked, so the pull request says it needs it.
- **Words** are re-extracted (`i18n_pot -- --write`); a changed English message needs
  its French again.

## Retiring a gene

**Tag it `retired`.** Never delete its file, and never give its key to anything else:
saves and the wire keep it. A retired key stays known, drawn and inert, and leaves
every list the water, drift and the gift draw from. It keeps the place in the order it
shipped with.

**An organ's tags are every variant's**, so an organ tagged `retired` retires every
variant it lists. To retire the organ's own key and keep its variants, lay it out as
the toxin is: the organ's `order = -1` and no `retired` of its own, and its first
variant listed first with the key, the order and the born the organ had, retired --

```gdscript
order = -1
variants = [
	{"variant": &"plain", "key": &"vacuole", "order": 14, "born": 0,
		"tags": [RETIRED]},
	# ...then the others, live, as they were.
]
```

Its key keeps its place in the order and stays the first of its organ's keys, so it
is still the organ as shipped on the pause screen -- no accent, named by its organ
alone -- and every other variant keeps its accent and its `organ · variant` name. To
retire them all, tag each variant too. The gene probe fails an organ tagged `retired`
over a variant that does not say so, with this recipe.

What else moves fails until it is moved, each saying so:

- `SHIPPED_LISTS`, where it was on a list a draw or a bit reads -- a drifter, a sense,
  the gift, a declarer;
- the drop probe's pins and `ci.yml`'s hash (**The seeded runs**, above), when the
  water or drift could make it -- and the four pins that hold lineage lines whatever
  it was, which lose its column;
- `Wire.RULES`, when it provided a table the rules list or was a gift;
- the template, whose room notes are measured with the widest gene word.

A stat only it provided is read at its value with no provider, and the gene probe
names it. The probes pose a mechanic by its stat -- the first live organ that provides
armour -- so retiring one organ moves them to the next. **Retiring the last organ of a
stat** fails the checks that pose it, saying the mechanic has no organ left: that is a
design call, not a fix.

## Changing the slots

Edit `body_plan.gd` (spec §10). Saves migrate by slot id, and no gene is lost. In the
same commit, move what holds the plan that shipped -- the gene probe's
`SHIPPED_PLAN` and the pins beside it, which fail saying what to move; net_probe's
wire sizes, when the count changes; the drop probe's pins, which a change of the
ladder or the count moves; and `Wire.RULES`, since the plan's fingerprint is in the
rules. No `Wire.PROTOCOL`.

**First settle what spec §15.3 lists for the first plan change**: whether a migration
may leave a body more live slots than it earned; the choosing screen's column, which
runs off the canvas at ten loci; the drop probe's floors check, which can fail by
chance; and a plan with fewer outside slots than a saved DNA has genes outside. And
ship the first plan change in an APK built since phase 2, with a `binary_version` bump
of its own if none has gone out since: a build from before it reads a newer file by
index.

## Looks

**Colour shows the family, shape shows the organ, and the pause screen names the exact
gene** (`docs/design/gene-looks.md`).

- **An organ's look is a family and a kind.** `family` is one of the five in
  `families.gd` -- eating, moving, sensing, defending, metabolism -- and the colour
  comes from it: three shades measured in OKLCH, the middle one unless the look sets
  `shade` 0 or 2. **A look holds no colour.** The catalogue works a key's hue out
  (`Catalogue.hue_of`), and the probe fails a `hue`. `look.shape` is a kind the family
  is built as -- eating `mat`; moving `oars`, `lash`, `coil`; sensing `tuft`, `lens`;
  defending `spines`, `plates`; metabolism `organelle` -- and the rest of the look is
  that kind's parameters, each with its default and its range or values in `kinds.gd`:
  `look = {"shape": &"tuft", "tip": &"fork"}`.
- **Two organs of one family differ at a glance or the probe fails them**: in their
  kind, or in a structural parameter -- a tip, a bend, a form, waves, turns, lips. A
  count, a length or a shade is never a difference, because copies multiply counts and
  lengths. The message names both organs. The fix is a new value of a parameter -- a
  tip, a form, a head -- which is a few lines in that kind's generator in
  `game/vision/cilia.gd`, and a render.
- **A variant is its organ's look and one accent**: `"look": {"accent": &"ring"}`, one
  of `disc`, `ring`, `diamond` and `bar`. Not the mark its organ's seat shows as
  shipped (a sense's pigment and a toxin's beads are discs), and not a sibling's. It
  sets nothing else of a look, and never a colour. An organ has room for three or four
  variants, and one more fails the probe, saying *make a new organ*. On the pause screen
  the accent sits in its chip's first lobe and before its word on the waiting tray, and
  the explaining line names it `organ · variant`, the variant's word from the organ's
  `VARIANT_WORDS`.
- **A sense names its `channel`, and the membrane colours the channel**, not the
  organ: a new sense on a channel the game has changes nothing there. A new channel is
  code, a lobe of its own (`docs/design/gene-looks.md` §5).
- **Render it beside its neighbours.** `tools/looks_sheet.tscn` draws every live organ
  by family, at one copy and at three, with its tile. Its `--variants=1` lays out each
  variant beside its organ, and `--room=1` organs no file holds. The variants and organs
  it shows are filed by `tools/looks_specimens.gd` the way the gene probe files its own,
  so a new one can be shot before it ships; `tools/drive.tscn -- --specimens=1` puts the
  same variants on the pause screen. At both sizes:

  ```
  xvfb-run -a -s "-screen 0 2400x1080x24" ~/godot/godot --path . --rendering-driver opengl3 \
      --fixed-fps 60 res://tools/shot.tscn -- --scene=res://tools/looks_sheet.tscn \
      --size=2400x1080 --out=/tmp/sheet-2400.png --wait=0.5
  ```

A key this build does not know -- a gene from a newer build -- draws as a plain tuft in
`UNKNOWN_TINT`, a pale grey-green in no family.

## Names

**A new name is the owner's call** (`CLAUDE.md`, "Putting a decision to the owner"):
the key, and the words a player reads. **Look up the real organelle first**
(`CLAUDE.md`, "Realism is a tool"): the radar is `ampulla`, after the ampullae of
Lorenzini, and the laser `ocellus`, a real eyespot carrying an ability no eyespot has
-- map an invented ability onto a real organ rather than invent a name to go with it.
A real name longer than sixteen letters is shortened in the key; the name on screen is
the gene's word and its `NAMES` entry, not the key.

**Never name a gene outside `game/genes/`.** Ask the catalogue for the organ by its
stat, its tag or its channel. The gate fails a key, an organ's or a variant's name
written in any script, scene, resource or shader under `game/` -- in either quote,
alone or with a part, `&"flagellum.hold"`, or in a script as a dictionary's bare key,
`{flagellum = 2}`, which GDScript reads as the string. **What it cannot catch**, never
write: a name built by concatenation or a format (`"%s.hold" % organ`), a name inside
a longer string (`"flagellum hold"`), and a string with an escaped quote in it.
Comments and `tools/` are exempt: a probe names genes on purpose.

## Balance

**Every number a gene ships with is a starting value**, with the reason for it
written beside it, and **balance waits for players** (`CLAUDE.md`, "Balance waits for
players"). When a playtest finds a number that seems off, the spec records what was
seen and the levers that would move it; it is not retuned, and not put to the owner.
A number that stops a mechanic from working at all is a bug, and is fixed.

## Content or binary

All of this is GDScript and data: it ships in a content pack, with no
`binary_version` bump -- but for the first plan change (above), and for anything that
touches `project.godot`, an autoload, a permission or a plugin (`CLAUDE.md`).
