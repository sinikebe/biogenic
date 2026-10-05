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
`CLAUDE.md` ("Run it"). Each probe passes only on its marker: grep for it.

## 1. Settle the name

A new key or a new word is **the owner's call** (`CLAUDE.md`, "Putting a decision to
the owner": a table, one option recommended). **Look up the real organelle first**
(`CLAUDE.md`, "Realism is a tool") and map the ability onto it. A key is 1 to 16
letters `a-z` and permanent once shipped.

## 2. Make the change

- **A variant**: one entry in its organ's `variants` -- a `variant` name, its `key`, the
  next `order`, what it changes, a `hue` of its own for now. `born` is 0 unless set; its
  tags add to its organ's; its parts are its organ's. A strain of the toxin sets its
  `dose`. README, "A variant".
- **An organ on mechanics the game has**: a copy of the nearest organ's file as
  `organs/<key>.gd`, every field set, and one line in `catalogue.gd`'s `ORGANS`. README,
  "An organ on mechanics the game has".
- **A new mechanic**: the mechanic, reading stats by name; its rows in `stats.gd`
  (`none`, `better`, `combine`, `unit`, `judged`, `contact`, `group`); `SEATED` for one
  that acts from a place. README, "An organ with a new mechanic".
- **An edit**: the organ's file. Never a key, never a shipped `order`. README, "Editing
  a gene".
- **A retirement**: the `retired` tag. Never delete the file or reuse the key. README,
  "Retiring a gene".
- **The slots**: `body_plan.gd`, after settling what spec §15.3 lists for the first
  plan change. README, "Changing the slots".

Numbers are **starting values** with their reasons; balance waits for players
(`CLAUDE.md`). A player-facing word for `one_variant` -- writing over a variant -- is
written with the first organ that turns it on.

## 3. Words

Its key in the organ's word tables, with the TRANSLATORS note, ROOM and CONTEXT the
table has. Then write the template again, and add the French in `game/i18n/fr.po`:

```
~/godot/godot --headless --path . res://tools/i18n_pot.tscn -- --write
```

## 4. Pins

- A new key appends to `tools/gene_probe.gd`'s `SHIPPED`, and to each list of its
  `SHIPPED_LISTS` it joins (`drifter`, `sense`, `gift`, `declares`).
- **The rules**: when net_probe's referee section says the rules two builds agree on
  changed, set `Wire.RULES` (`game/net/wire.gd`) to the value it names, in the same
  commit. **Never `Wire.PROTOCOL`.**
- **The seeded runs**: a gene the water or drift can make moves the drop probe's pins
  and `ci.yml`'s empty-library hash. Record them again from the checks' own output, and
  say why. The workflow's pin is the lead's to move: ask.

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

Run the network probe alone, or in a namespace of its own
(`unshare --net -- bash -c 'ip link set lo up && <command>'`): two at once call each
other's servers.

## 6. Look at it

Render the gene beside its nearest neighbours -- full vision, point of view and the
pause screen -- at 1280x720 **and** 2400x1080, with `tools/shot.tscn` posing
`tools/drive.tscn` (README, "The checks"), and judge it. A screen is done when it has
been looked at.

## 7. Land it

`CLAUDE.md`'s git workflow: a pull request into `dev`, its title a line of the next
patch note -- what changed for a player. Say in its body which pins moved and why,
and, when `Wire.RULES` moved, that a player on the old content cannot play with one on
the new until the older updates.
