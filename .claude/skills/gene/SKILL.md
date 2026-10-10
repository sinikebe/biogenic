---
name: gene
description: Add, edit or retire a gene, a variant of one, or a strain of the toxin -- an organ, its numbers, its words, its look, its place in the water -- or change the body plan's slots. The gene pass's playbook as steps with their commands; game/genes/README.md is the long version. Use it whenever a session is asked to add a new gene, organ, variant or strain, change what an existing one does, says or looks like, retire one, or change the slots.
---

# A gene

Everything about a gene is in `game/genes/`, and `game/genes/README.md` is the
playbook: read it first, and follow it where this is short. Nothing outside
`game/genes/` names a gene -- a mechanic asks the catalogue by stat, tag or channel --
so the work is edits to that folder, its probe's pins, the translation template and
the French.

The commands below are run from the project root, after the one-time import in
`CLAUDE.md` ("Run it"). **Every import rewrites `project.godot`: put it back at once**
(`git checkout -- project.godot`), since a change there is a new binary and a gene is
content. Each probe passes only on its marker: grep for it.

## 1. Settle the name

A new key or a new word is **the owner's call** (`CLAUDE.md`, "Putting a decision to
the owner": a table, one option recommended). **Look up the real organelle first**
(`CLAUDE.md`, "Realism is a tool") and map the ability onto it. A key is 1 to 16
letters `a-z` and permanent once shipped.

## 2. Make the change

- **A variant**: one entry in its organ's `variants` -- a `variant` name, its `key`, the
  next `order`, what it changes, and an accent, `"look": {"accent": &"ring"}`, never a
  colour. `born` is 0 unless set; its tags add to its organ's; its parts are its
  organ's; **it sets no class to share its organ's place in the water evenly, or
  `"water": {"rarity": &"rare"}` to be a rare kind of it** -- either way it changes
  nothing outside its organ. One the water never makes (`"drifter": false`) takes
  nothing of its organ's place there; drift may still bring it, at its share in drift,
  unless it is tagged `never_drifts`. **A variant of a sense is a sense and a gift**,
  by its organ's tags: the water may give it to a peer or a daughter with no sense and
  your newborn may be given it, whatever its water and drift say. A strain of the
  toxin sets its `dose`, and its `water` as the first strain does, `{"drifter": true}`:
  the toxin's drifter flag is each strain's, not the organ's. A form never sets a
  class. README, "A variant" and "Rarity".
- **An organ on mechanics the game has**: a copy of the nearest organ's file as
  `organs/<key>.gd`, every field set -- **its class, `water.rarity`**: `common` only if
  every run needs it, `uncommon` if runs are built from it, and **when unsure, `rare`**
  -- and one line in `catalogue.gd`'s `ORGANS`; then
  import again (`xvfb-run -a ~/godot/godot --path . --import`), which writes the file's
  `.uid` -- commit it, never write one by hand. README, "An organ on mechanics the game
  has" and "Rarity".
- **A new mechanic**: the mechanic, reading stats by name; its rows in `stats.gd`
  (`none`, `better`, `combine`, `unit`, `judged`, `contact`, `group`); `SEATED` for one
  that acts from a place, which then takes every number it uses -- its stats through
  `Stats.seated` -- from the one organ it acts from, the first in slot order, never
  the best of two. README, "An organ with a new mechanic".
- **An edit**: the organ's file. Never a key, never a shipped `order`. README, "Editing
  a gene".
- **A retirement**: the `retired` tag. Never delete the file or reuse the key. An
  organ's tag retires every variant it lists, so to retire only its own key lay it out
  as the toxin is: `order = -1`, and its first variant listed first with the key, the
  order and the born the organ had, `"tags": [RETIRED]`. README, "Retiring a gene".
- **The slots**: `body_plan.gd`, after settling what spec §15.3 lists for the first
  plan change. README, "Changing the slots".

Numbers are **starting values** with their reasons; balance waits for players
(`CLAUDE.md`). A player-facing word for `one_variant` -- writing over a variant -- is
written with the first organ that turns it on.

## 3. Words

Its key in the organ's word tables -- a variant's own word in `VARIANT_WORDS`, which
the explaining line puts after its organ's name -- with the TRANSLATORS note, ROOM and
CONTEXT the table has. Then write the template again, and add the French in
`game/i18n/fr.po`:

```
~/godot/godot --headless --path . res://tools/i18n_pot.tscn -- --write
```

## 4. Pins

- Append a new key to `tools/gene_probe.gd`'s `SHIPPED`, and to each list of its
  `SHIPPED_LISTS` it joins (`drifter`, `sense`, `gift`, `declares`).
- **The rules**: when net_probe's referee section says the rules two builds agree on
  changed, set `Wire.RULES` (`game/net/wire.gd`) to the value it names, in the same
  commit. **Never `Wire.PROTOCOL`.** They move with a judged or contact table, that
  row's `none`, `better`, `combine` or `group`, the body plan, the gift's list -- which
  a variant of a sense joins, whatever it provides -- and a second organ of a mechanic
  with a place, which adds the line naming its seat.
- **The referee's caps** hold over every provider of a judged stat: a tail faster than
  the speed cap fails net_probe's check of them. Moving a cap changes the referee's own
  limits, which needs the false-positive runs of `docs/design/net-hardening.md` again
  (`CLAUDE.md`).
- **The seeded runs**: a gene the water, drift or a sense's draws can make -- a
  variant of a sense always can -- moves the drop probe's pins and `ci.yml`'s
  empty-library hash, and a key added or retired adds or takes away its column in the
  lineage lines four of those pins hold. Record them again from the checks' own
  output, and say why. A new key that never drifts, is no drifter and no sense moves
  only that column, and fails the drop probe's lineage 4 (every live variety carried):
  anything more is a bug (README, "The seeded runs"). The workflow's pin is the lead's
  to move: ask.

## 5. Run every check

```
timeout 120 ~/godot/godot --headless --path . res://tools/gene_probe.tscn            # [gene-probe] ALL PASS
timeout 120 ~/godot/godot --headless --path . res://tools/gene_probe.tscn -- --names # [gene-names] ALL PASS
timeout 120 ~/godot/godot --headless --path . res://tools/i18n_pot.tscn -- --check   # [i18n] ALL PASS
timeout 120 ~/godot/godot --headless --path . res://tools/i18n_pot.tscn -- --lint-all # [i18n] ALL PASS
timeout 600 ~/godot/godot --headless --path . res://tools/drop_probe.tscn            # [drop-probe] ALL PASS
~/godot/godot --headless --path . --quit-after 24000 res://tools/net_probe.tscn -- --referee-only
                                                     # [net-probe] NOTE --referee-only: 0 failed
```

Run the network probe alone, or in a namespace of its own with an address besides
loopback, which its pond referee needs -- any private one; CI's is made up:
`unshare --net -- bash -c 'ip link set lo up && ip addr add 10.77.0.5/24 dev lo && <command>'`.
Two at once call each other's servers.

## 6. Look at it

Render the gene beside its nearest neighbours -- the organs of its family on
`tools/looks_sheet.tscn`, then full vision, point of view and the pause screen -- at
1280x720 **and** 2400x1080, with `tools/shot.tscn` posing `tools/drive.tscn` (README,
"The checks" and "Looks"), and judge it. Pass `--fixed-fps 60` to Godot, so one pose is
one frame. A screen is done when it has been looked at.

## 7. Land it

`CLAUDE.md`'s git workflow: a pull request into `dev`, its title a line of the next
patch note -- what changed for a player. Say in its body which pins moved and why,
and, when `Wire.RULES` moved, that a player on the old content cannot play with one on
the new until the older updates. **Paste the gene probe's `NOTE the water by class`
line into it**: what the water holds of each class, and what the floor costs.
