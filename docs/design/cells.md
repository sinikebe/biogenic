# Your cells: saved apart from the worlds

The owner, 2026-10-04, in two steps:

> "Split the saved cells between full vision and point of view. Cells grown in full
> vision should not be usable in point of view, since it's not the same difficulty
> and gameplay."

> "Move the cells out of the world save. Add cell saving slots, with a way to open a
> detailed view of the cell."

The first step is built: each world keeps one cell per view (`ocean.md` §9.5). This
document is the second. Cells leave the worlds and get slots of their own, and the
per-view rule stays: **a cell belongs to the view it was born in and is only ever
played in that view.**

**Status: designed and mocked on the real screens, at 1280x720 and 2400x1080, in
English and French (`cells-ux.md` §7). Phase 1 of §6.2 is built (§6.5): the figure,
drawn from plain values. Phase 2, everything a player sees, is not.** This file holds
the rules, the files, the migration, ponds and the build plan. `cells-ux.md` holds the
screens, their words and the mocks. Three calls were the owner's (§8), answered
2026-10-04: all three as recommended.

**What it replaces.** Where these say otherwise, this document wins:

- `ocean.md` §9.1, "your cell is in it when you come back", and all of §9.5;
- `settings.md` §4.1 (a world keeps your cells), §4.3 (a world's cell lines), §4.4
  (the delete line) and §6.2 (the index's `generation` keys);
- `automation.md` §9.2 (the cell's part, in its world's file).

---

## 0. Decided, in one place

1. **A cell is its own save**, one small file in `user://cells/`. A world's file
   keeps only its water (§3).
2. **Three slots for each view**, six with today's two views, and each view keeps its
   own selection. A view's button plays that view's selected cell, so a cell can never
   be started in the wrong view (§1.2).
3. **A run is the selected world plus the view's selected cell.** The world is
   chosen in the corner, as today. The cell is chosen beside its view (§1.3).
4. **A cell remembers its place in the water of the world it was left in.** Back in
   that world, it resumes where it was, even after the drop moved under another cell.
   If that water ran on without it, dread's reach is cleared round it. Anywhere else
   it comes in at a quiet place, as `elsewhere` does today (§1.4).
5. **A death leaves the dead cell's record in its slot until a new cell starts
   there** (row 1). The tap on the black starts that new cell in the same slot (§1.5).
6. **Division:** the chosen daughter is the slot's cell from then on. She keeps its
   name and its line's age, one generation on. Her sister stays in the water, as
   today (§1.6).
7. **Names:** every cell has one. A new cell gets a default name, the old name of an
   animalcule (rows 2 and 3), and the player can type over it, as for a world (§1.7).
8. **The program library stays the player's**, one for every cell. A cell keeps only
   its own clock, `fed` (§1.8).
9. **Ponds:** a guest brings its selected cell and takes it home to its slot. A host
   plays its own selected cell. The server's room keeps none. **No wire change**
   (§2).
10. **Migration runs once and loses nothing.** Each world's cells move into slots,
    and the first press of each view plays exactly the cell it played before the
    update (§4).
11. **Content only.** No `binary_version` bump, no `project.godot` change, and
    `Wire.PROTOCOL` stays 7 (§6.4).

---

## 1. The model

### 1.1 A cell is its own save

A slot keeps everything a world kept for its cell, untouched:

- the body;
- its genome: DNA, layout, worn body, levels and the waiting queue;
- its tank and starve clock;
- its generation and its record (`id`, `parent`, `lineage`);
- the two daughters rolled, if it was left while choosing;
- the water's part of it: its grace, the clocks of its dart and bite, and the first
  drifter it had not met yet;
- its loads;
- `fed`.

It also keeps what is new:

- **its view**, set at its birth and never changed;
- **its name**;
- **when its line was born**, in wall-clock time (`born`), for the record;
- **how long its line has been played** (`lived`): every second a cell of the line
  was alive in the water, across its divisions;
- **where it is** (§1.4).

`cell_save.gd` (§5) knows a cell only as the Dictionary a world used to keep. So it
holds no gene name, and the per-view rule is a name compared with a name.

### 1.2 Slots: three for each view

**Three slots a view, kept by the view's name** (`run_state.gd`'s `CELL_KEYS`: full
vision's is `""`, point of view's `pov`). Six today, nine if the third view of
`roadmap.md` ever comes. Why three:

- **It is exactly enough for the migration.** A world keeps at most one cell for each
  view, and there are three worlds. So each view has at most three cells to move, and
  none is ever left over (§4).
- **The sheet is the worlds sheet.** Three rows fit 720 px with their lines and no
  scrolling, at both shapes (`cells-ux.md` §2). More rows would scroll on a phone.
- **Slots per view, not one shared pool of six.** Each view's button opens its own
  cells. With a shared pool, every list would hold cells that the button just pressed
  could never play.

Each view has **a selected slot**: the one its button plays. It may be empty. Then
the button says `a new cell`, and pressing it starts one there. Choosing another slot
leaves the cell in the old one exactly as it was. So setting a cell aside takes one
tap. `Cells.SLOTS` is the number, and a later build can raise it.

### 1.3 A run is a world plus a cell

Pressing a view opens a run with:

- **the selected world**: `Drops.SELECTED`, chosen from the corner's chip as today;
- **the view**: the button pressed;
- **the cell**: that view's selected slot (§3.2).

**Each cell lives under its own view's button** (`cells-ux.md` §1), so the question
"what if the selected cell's view does not match the button" cannot arise. A run also
checks: it refuses a slot file whose `view` is not its own, and starts a new cell
instead, saying so in the log. That check protects against a damaged index and
against tools.

`V` still flips the view in the editor only, and a flipped run still keeps nothing
(`ocean.md` §9.5).

### 1.4 Where a cell is

**Its place is kept in the frame of the drop it was kept with.** A quiet start moves
the whole drop, and its rim, under the cell that comes in (`food.gd`'s
`_shift_drop`). So a place in the water only means something next to the rim it was
measured against. A slot keeps the cell's body as the world kept it, plus a `where`:

| key | what |
|---|---|
| `world` | the world's slot, 1 to 3 |
| `drop` | that drop's number, `drop.seed`. It is drawn once when a drop is made and kept for its life, so a world deleted and made again in the same slot has another |
| `rim` | the rim's centre, `drop.rim_centre`, in the frame of that keep |
| `age` | the drop's age, `drop.age`, at that keep |

**Opening a run in world `s`, whose drop is number `n`, with its rim centred at `c`
and aged `a`:**

```
if where.world == s and where.drop == n and not cell.elsewhere:
    the cell resumes in place:
        at = cell.body.at + (c - where.rim)    # the drop moved under it since
        at = rim.contain(at, radius)           # a content pack may shrink the rim
        food.restore_player(cell.water)        # its grace and clocks, as today
        if a != where.age:                     # the water ran on without it
            clear dread's reach round it       # food.gd's _clear_round, at its place
else:
    it comes in at a quiet place               # food.return_to_drop(), as `elsewhere`
```

`at + (c − where.rim)` is the arithmetic `_cells_kept_aside` does today for a cell
set aside. Here it is applied once, as the cell is read. The world's file no longer
carries the cell, so no keep of anyone else's ever has to move it.

**Why clear dread's reach when the water ran on.** If the drop's age is the one kept
with the cell, nothing has moved since this cell left: that is the water it left, with
its dangers. If another cell has played the world since, a hunter may be sitting on
the place, and the player has never seen it. The quiet start's own clearing removes
what could swallow *this* cell within dread's reach of it, and nothing else. This
adds no number. Like any resume, it still comes in behind the beat of
`shared-pond-ux.md` §0.5.

**When it gives up its place** and comes in at a quiet place:

- **another world is selected.** The cell goes where the player chose, and its
  button says where it is coming from (`cells-ux.md` §1.2);
- **its world is gone:** the slot is empty, or it holds a different drop. That
  happens when the world was deleted and made again, or when its file could not be
  read and was set aside;
- **it was kept in a friend's water** (`elsewhere`, §2).

In every case its old place is forgotten at its next keep.

### 1.5 A death (owner's row 1)

**The cell is gone.** Under the recommended answer, its file becomes **its record**:

- `cell` stays as it was at the death, so the detailed view can still draw it;
- `where` says where it died;
- `died` is added: `{"cause": Cause, "at": unix seconds}`.

A record is not a cell, and nothing plays it. A run that opens on a slot holding a
record starts a new cell there, and the record goes at that cell's first keep. The tap
on the black does exactly that in the same run, so in play the record lasts only until
the tap. **It is seen only if the player leaves from the black**, or closes the app
there: the case where a player would otherwise come back to find the cell simply
gone. The slot then says what happened, and its last body can still be looked at.

With the other answer, a death deletes the slot's file, and the slot reads `new cell`.

The world is kept at a death, as today, with the cell's remains in the water if it
starved or was poisoned (`ocean.md` §7.4).

### 1.6 Division

**The chosen daughter is the slot's cell from then on**, one generation on. She keeps
the slot, the name, `born` and `lived`, and takes a new `id` with her mother as
`parent`, as today (`lineage.md` §4). **The sister is the water's**, as she always
was: she carries the DNA and the instincts this cell ran (`automation.md` §6.3),
founds a family there, and is in no slot. A division left while choosing is kept as
today (`daughters`, `_kept_pair`).

### 1.7 New cells, and their names (owner's rows 2 and 3)

**A new cell is born at a quiet place in the selected world.** It is generation 1, a
new line with `born` now and `lived` 0, and it is the view's cell.

**Its name** is a default: the first in the list that no cell in any slot, living or
recorded, wears or is called. Like a world's default name:

- the slot keeps *which* default, not its words, so the name follows the language;
- the player can type over it in the detailed view (`cells-ux.md` §3.4). The rules
  are the world's: 20 characters, trimmed, and a default's own words keep the default
  (`settings.md` §5.2);
- a name is the player's words. It is never translated and never crosses the wire.

**The defaults, recommended (row 3): the names the first microscopists gave the
animalcules they found in a drop.** They are the cells' answer to the worlds' names,
which are the water a microscopist takes a drop from.

| default | the animalcule | French |
|---|---|---|
| `slipper` | *Paramecium*, the slipper animalcule | `pantoufle` |
| `bell` | *Vorticella*, the bell animalcule | `cloche` |
| `trumpet` | *Stentor*, the trumpet animalcule | `trompette` |
| `proteus` | *Amoeba*, Rösel's "little Proteus", 1755 | `protée` |
| `swan` | *Lacrymaria olor*, the swan's tear, O. F. Müller 1786 | `cygne` |
| `wheel` | rotifers, the wheel animalcules | `roue` |
| `sparkle` | *Noctiluca*, the sea sparkle | `étincelle` |

**The sun animalcule (*Actinophrys*) is left out on purpose.** `sun` is already a
gene's word on the pause screen.

### 1.8 Instincts and the library

**The library is the player's, as the owner set it:** "Players have a library of
programs" (`automation.md` §3.5). There is one `user://library.save`, with one set of
switches and one order, and every cell in every slot runs whatever is on. A slot
keeps only the cell's own part: `fed`, the seconds since it last ate. As today, the
autopilot's state is not kept.

**Switches per cell were considered and set aside.** Changing cells would change
which programs run, under a player who changed nothing. Instincts for organs a body
lacks already sleep (`automation.md` §4.1), so one library already fits every body.

---

## 2. Ponds and the server

- **A guest brings its view's selected cell.** Its run opens in its own selected
  world, on that cell, resumed or at a quiet place (§1.4). Then it swaps into the
  host's water, as today. While it swims there, a keep writes the cell with
  `elsewhere` and the guest's own world as it was set aside (`ocean.md` §9.1).
  Leaving the pond, or losing the link, puts the cell back in its own world at a
  quiet place, and its next keep gives it that place. **The cell goes home to its
  slot**, whichever way the guest leaves.
- **A death in a friend's water** writes the record (§1.5). The tap brings the new
  cell into the pond, as today, and it is the slot's new cell.
- **A host plays its own view's selected cell** in its selected world, which is the
  pond. It keeps both as it does alone.
- **The dedicated server's room keeps no cell.** It never did: `server.gd` composes
  its room with no cell, and it never reads `user://cells/`.
- **Nothing on the wire changes.** A guest's cell crosses as it does today: its body,
  its genome, its sister's DNA and list. Its name, `born`, `lived`, view and slot
  never cross, so a host never sees a guest's name. **`Wire.PROTOCOL` stays 7 and
  `Wire.RULES` stays as it is**: the referee judges the body a guest brings, never
  where it was kept (`CLAUDE.md`, "The host's referee copies the game's rules").

---

## 3. The files

### 3.1 A cell's file

`user://cells/cell_<n>.save` for full vision's slot `n`, and
`user://cells/cell_<view>_<n>.save` for every other view's: `cell_pov_1.save`. The
name is built from the view's key, so a view a later build adds is kept by this one.

It is one `store_var` of plain types through `open_compressed`, written to a `.tmp`,
read back, compared and renamed over: **`DropSave.write`, called as it is**. A phone
killed mid-write keeps the last good cell.

| key | type | what |
|---|---|---|
| `format` | int | `CellSave.FORMAT`, 1: the layout of this file, not of a drop |
| `rules` | String | `DropSave.rules()`. A cell kept under other rules is re-derived from its genome by name, as a world's cell is, and logged as converted |
| `content`, `commit` | int, String | the build that wrote it, for the log |
| `view` | String | the view's key: `""` or `pov` |
| `name` | String | as typed, or `""` while it wears its default |
| `default` | int | which default it wears (§1.7) |
| `born` | int | unix seconds, UTC, when its line's first cell was born; 0 when unknown (§4) |
| `lived` | float | seconds its line has been played; absent when unknown (§4) |
| `where` | Dictionary | `{world, drop, rim, age}` (§1.4), or `{}` for none |
| `cell` | Dictionary | **`DropSave.CELL`, exactly as a world kept it**, `elsewhere`, `loads`, `fed` and the record keys included, checked by the same code. Its `body.at` is in the frame of `where.rim` |
| `died` | Dictionary | `{}` for a living cell; `{cause, at}` for a record (§1.5) |

- **A file this build cannot read** (an unknown format, or one that does not hold what
  it says) is set aside as `.old` by the run that would play its slot. That run starts
  a new cell there. A menu never sets a file aside: it shows the slot as empty.
- **A gene this build does not know** loads as a name kept and inert, as in a world
  (`ocean.md` §9.2).
- **Size, estimated and not measured:** a world's file holds about 520 bodies in
  27 KB on disk (`ocean.md` §9.3), and a cell's is one body with its genome, so a few
  KB at most. A daughter pair left while choosing adds the most. The probe of §6.3
  prints the real size and the time a write takes.

### 3.2 The index: `user://cells.cfg`

```
[cells]
selected=1          ; full vision's selected slot, from 1
selected_pov=2      ; every other view's, as selected_<view>
```

**It holds the selection and nothing else.** A slot's name, line and place are in its
file, and a menu reads them from there. A cell file is a few KB, so the drops' cached
line is not worth having here. It is written as `drops.cfg` is: to `cells.tmp`, read
back and renamed. A missing or unreadable index selects slot 1 of each view. A
selection that names a slot past the slots that exist falls back to slot 1.

**Reading never writes.** The chooser, the sheet, the detailed view, every tool and
every probe leave `cells.cfg` and `user://cells/` as they found them. Only a choice
writes, and a keep, a rename, a delete or the migration.

### 3.3 A world's file now

**`cell` is written `{}`, and `cells` is never written.** `FORMAT` stays 1, and every
build reads the file. A build from before this change sees a drop with no cell in it
and starts a new one there (§4 has what happens to that cell).

`drops.cfg` keeps each world's `lived`, and its `generation` keys go:
`Drops.note_kept(slot, lived)` writes none, and a world's line in "your worlds" is its
age alone (`cells-ux.md` §5).

### 3.4 When each is written, and in what order

The save points are today's (`ocean.md` §9.3):

- a death, on the black;
- the pause screen opening;
- the app backgrounded or closed;
- leaving the run;
- joining a friend;
- hosting stopping.

**At each one the cell is written first, then the water.** A phone killed between the
two keeps the cell's newer state and water one keep older. The age rule of §1.4 then
treats that water as moved on and clears round the cell, which is the safe side.

A death writes the record, or deletes the file under the other answer to row 1. A
tool's run writes neither file unless it is given one (§6.2).

---

## 4. Migration

**When.** It runs at two moments, and is never run by a tool given no cells folder, or
by the server:

- **On the chooser's first frame:** for every world whose index line names a cell (a
  `generation` key), or whose file `Drops.read` had to peek. This is cheap: it reads
  `drops.cfg`, which the chooser reads anyway.
- **When a run opens a world's file:** for any cell still in it. This is free, because
  the run decodes that file anyway.

**Order:**

- the selected world first, then the others in slot order;
- within each world, full vision's cell, then point of view's, then any other view's
  by name.

**For each cell:**

1. **If a slot of its view already holds this very cell, skip to step 3.** That is a
   slot whose `where.world` and `where.drop` are this world's and whose `cell` is
   byte for byte the same: a migration that was killed before step 3.
2. **Write it into its view's first empty slot**, with these values:
   - `where`: from the world's file (its slot, `drop.seed`, `drop.rim_centre` and
     `drop.age`). Giving it the world's own age means its first resume is the one it
     would have had before the update: in place and not cleared, as `ocean.md` §9.5
     resumes a cell set aside. A cell set aside there is already in that rim's frame,
     because every keep moved it with the drop;
   - `name`: none typed, so it takes the next free default;
   - `born`: 0, since it is unknown;
   - `lived`: not written. The age of a line from before the move is unknown, so no
     age is shown for it rather than a wrong one.

   Read the file back.
3. **Once every cell of the world is in a slot, write the world's file again without
   them:** `cell` `{}` and no `cells`. Read it back, rename it, and drop the world's
   `generation` keys from `drops.cfg`.

**Nothing leaves a world's file until its slot has been read back.** If a slot cannot
be written (a full disk), the run carries that world's unmoved cells aside and writes
them back at every keep, as `_cells_kept_aside` does today. So a failed migration
loses nothing and is simply tried again next time.

**The selection.** Where `cells.cfg` has no selection for a view yet, each view
selects:

- the slot that took **the selected world's** cell of that view;
- or, when that world kept none, the view's first empty slot.

So the first press of each view after the update plays exactly what it played before:
the same cell, or a new one. A later migration (below) never moves a selection.

**More cells than slots.** It cannot happen the first time: three worlds with one cell
of a view each fill that view's three slots at most. It can happen only if an older
build kept new cells in the worlds after the migration. That is a content pack that
failed to mount, so that the APK ran its own content. **A cell is still never left
behind.** It takes a slot past the three, which the sheet lists, and that slot closes
when it empties. Nothing is ever deleted to make room.

**A view this build does not know** (a later build's) migrates into its own slots by
its key. Those slots are kept, and are never shown or selected.

**Cost.** Once, on the first chooser after the update. These are the costs already
measured for a world's file on a desktop, plus an estimate for a cell's:

- decode up to three worlds: about 2 ms each (`DropSave.peek`, `settings.md` §6.3);
- write up to six cell files: about 1 ms each, an estimate;
- write up to three worlds again: about 3 to 4 ms each to write, read back and
  rename (`ocean.md` §9.3).

That is under 30 ms, in one frame of a menu. It has not been measured on a phone
(§9).

**The log** says each move:
`[cells] full vision's cell from world 1 (drop 2207, 7800 s) into slot 1`.

---

## 5. Generic mechanics, names at the edges

| file | knows | does not know |
|---|---|---|
| `game/normal/cell_save.gd` **new** | a cell's file: its shape, `compose`, `read` (sets aside), `peek` (never does), `write` through `DropSave.write`, its own `FORMAT`, and a cell's checks, taken from `drop_save.gd` (`_bad_cell` becomes the public `bad_cell`) | genes, views by meaning, menus |
| `game/normal/cells.gd` **new** | the slots per view, by key; the selection; paths; the default names and the free one; `migrate(drops_root, cells_root)`; a slot's summary for a menu (`line_of`) | what a view draws, a run, a menu |
| `game/normal/drop_save.gd` | a world's file. It now composes it with no cell, and still reads one with cells, for the migration | slots |
| `game/normal/drops.gd` | the worlds. `note_kept(slot, lived)` loses its view and generation; `lines_of` is the age | cells |
| `game/normal/normal_mode.gd` | when to read and keep the two files; the place rule of §1.4; `lived` and `born` | the files' layout |

**The place rule is generic:** "a body kept with the frame it was measured in, moved
by the frame's change, cleared round if the water moved on". `food.gd` gets one public
door for it, `resume_player(state, moved_on)`: `restore_player` plus the clearing.

---

## 6. Build plan

### 6.1 Files

New:
- `game/normal/cells.gd`;
- `game/normal/cell_save.gd`;
- `game/normal/figure.gd` (phase 1);
- `game/menu/cell_figure.gd` (phase 2).

Changed:
- `drop_save.gd`, `drops.gd`, `normal_mode.gd` and `food.gd` (one public door);
- `mode_select.gd` and `.tscn`;
- `earshot.gd` and `.tscn`;
- `corner.gd` and `.tscn`;
- `game/i18n/fr.po`;
- the tools below.

Untouched:
- `server.gd`, `wire.gd`, `referee.gd`;
- `addons/`, `ci/`, `project.godot`.

### 6.2 Phases, and what each must pass before `dev`

Two pull requests. If the owner answers a row against its recommendation after the
second has merged, the change is a small third.

| phase | the player gets | what is built | checks |
|---|---|---|---|
| **1. `chore:` the figure, drawn from values** | nothing they can notice | **Pure drawing and wording move out of `normal_mode.gd`** into `figure.gd`, as static functions of plain values (`dna`, `body`, `layout`, `body_layout`, `levels`, `waiting`, `radius`, `loads`, `slack`). What moves: the body and tethers, a chip and its label, pips and level, a waiting chip, a fork chip, the caption, and the explain, odds and numbers lines. **The pause screen keeps its state and its input**, and calls them | **Pixel-identical pause.** First three seeded renders must be 0 px apart (`perception.md` §4.1). Then before and after must be 0 px apart, at both shapes, for: `G` of `gene-stats.md` §8; a waiting gene; a fork waiting to be chosen (`beam-levels.md` §8.3's pose); a toxin inside; `--hunger=0.72`; a dose; numbers on and off; the choosing screen. Plus `--lint-all` and the CI boot |
| **2. Cells apart, and a cell's own view** | "Your cells have slots of their own, three for each view, apart from the worlds: pick one beside its view, or start a new one, and open any of them to see its body, its genes and where it is" | §§1-4; the chooser's split buttons, the sheet, the detailed view (`cell_figure.gd`: read-only, on `figure.gd`), rename and delete, the TOGETHER lines, "your worlds" without cells, the words (`cells-ux.md`) | §6.3's probe; `net_probe`'s `pond, kept` on slots; the frames of `cells-ux.md` §7, at both shapes and in both languages; `--lint-all` with the new rooms; the CI boot of every scene |

**Tools, in phase 2:**

- `normal_mode.gd` gains `cells_at := Cells.SELECTED`, a marker resolved as the run
  opens, as `keep` is;
- `drive.gd` empties it unless given `--cells=<folder>`, so no render opens on a cell
  another run left, or leaves one (`--cell=` already means a posed water cell);
- `corner_shot.gd` gains `--cells=` states for the sheet;
- `i18n_pot.gd` builds the cell lines against their rooms.

### 6.3 The save and the migration, tested

`drop_probe` gains a `cells` section. Its checks replace `views 1` to `views 7`, which
were about cells in worlds, and run through real runs of the game in a folder of the
probe's own:

1. **A world with both cells migrates.** It writes two slot files whose `cell` holds
   the world's bytes. The world comes back with `cell {}` and no `cells`, and its
   index loses its generations. Each view selects the selected world's cell.
2. **A migration killed between steps 2 and 3 loses nothing and duplicates nothing.**
   A slot is written while the world still keeps the cell; the next migration skips
   it and cleans the world.
3. **A cell an older build kept after the migration** takes a free slot, and when its
   view is full, a slot past three. No selection moves.
4. **A full-vision cell is never opened in point of view, nor the other way.** Each
   view plays its own selection, and a slot file of the other view is refused.
5. **The place survives the drop moving.** A cell kept in world 1 resumes at its
   place, rim-relative, after another cell's quiet start moved the drop by thousands
   of units. It is cleared round when the drop aged, and it is exact, with its first
   drifter still waiting, when the drop did not.
6. **Another world, a gone world, `elsewhere`:** each brings the cell in at a quiet
   place, and its next keep records the new place.
7. **A death:** writes the record (or deletes, by row 1). The tap's new cell takes the
   same slot with generation 1, a new line and the next default name. The record goes
   at its first keep.
8. **A division** keeps the slot, the name, `born` and `lived`, with generation + 1.
9. **The keep order:** the cell is written before the world. A run killed between the
   two resumes the cell, cleared round.
10. **Reading never writes:** the chooser, the sheet and the detailed view leave
    `cells.cfg` and `user://cells/` byte for byte, and a tool's run with `cells_at`
    empty writes neither.
11. **The library is untouched:** two cells in two slots run the same programs, and
    `library.save` is not rewritten by a switch of cells.

**`net_probe`'s `pond, kept`** becomes: a host and a guest, each with cells in slots,
play their selected cells in a real pond. The guest's cell is kept `elsewhere` in its
own slot and comes home to its own world at a quiet place. The host's resumes in
place. No cell file is written for the server's room.

### 6.4 Wire and binary

- **No wire change.** Nothing the referee copies moves, `Wire.PROTOCOL` stays 7 and
  `Wire.RULES` stays as it is: net_probe's `referee` section passes unchanged.
- **No binary change.** It is GDScript, scenes and words, so it ships as content. No
  autoload is added: `cells.gd` is preloaded by path, as `drops.gd` is. And
  `project.godot` is untouched.

**Six things the build must not get wrong:**

1. A world's file loses a cell only after that cell's slot has been read back.
2. The cell is written before the water.
3. A place is read in the frame of the rim it was kept with.
4. A run plays only its own view's slot.
5. No menu or tool writes a file by reading.
6. Names are never translated and never sent.

### 6.5 As built: phase 1, 2026-10-04

**`game/normal/figure.gd`, and nothing a player can notice.** The figure's constants
moved there as they were, their translators' notes and rooms with them: its geometry,
its inks, and the words of the chips, the tray and the lines under the figure. Its
drawing became static functions. Each takes the values its own piece draws, so a
screen resolves a cell into them, from a live genome or from a file:

| piece | `Figure.` | takes |
|---|---|---|
| the body, its tethers, its own words | `draw_body` | `body`, `body_layout`, the eight slots' genes (`layout` and the inside), how many are live, `slack`, and the loads' marks (`FoodField.felt_of(loads, radius)`) |
| the part being read, lit | `draw_mark` | the slot, and the gene whose hue it takes |
| a chip | `draw_chip`, `chip_at` | its gene, copies, worn copies, hue and level; a screen with input adds `forking`, `selected`, `trace`, `refused` and a ghost |
| the tray | `make_tray_caption`, `draw_waiting`, `draw_fork_chip`, `waiting_width`, `fork_chip_width` | a waiting gene's copies and seconds left, in hand or not; a fork's level, open or not, stepped back or not |
| the caption | `caption` | the generation, the switch, `radius`, `body` and the upkeep |
| the lines | `explains`, `explain_empty`, `hint_empty`, `odds`, `level_text`, `draw_explain_organ`, `numbers_lines`, `draw_numbers` | a gene, the slot it is read at and the way its fork took; a copy count; a level |
| the switch, the gauge | `toggle_boxes`, `draw_toggle`, `draw_gauge` | on and hovered; a level's progress |

**Where it differs from §6.2, and why:**

- **More moved than §6.2 lists:** the `numbers` switch, the level's gauge, the
  explanation's organ, the tray's caption and the travelling gene. The detailed view
  draws the first four (`cells-ux.md` §3.3), and moving them here put them under this
  phase's pixel check instead of the next one's.
- **Values for each piece, not one set for the whole figure.** §6.2 names a cell's
  values. Each function takes the ones its piece draws, already resolved: a level as a
  number, a gauge as a fraction, a waiting gene as its copies and its seconds left.
- **The upkeep is a value.** `caption()` takes it, because the genome prices a levelled
  gene by its level and figure.gd prices nothing. Phase 2 reads a body from a file, so
  it needs that price without a `Genome`: one static on genome.gd, which `upkeep()`
  then calls.
- **What stays in normal_mode.gd:** the state and the input, as §6.2 says, and with them
  the ring's keyboard (`SLOT_NEIGHBOUR`, `SLOT_RING`), the verb lines and the lines
  that price an eviction (`ACT_*`, `HINT_LOSES*`), the fork's cards, and the choosing
  screen's own strands. `_word`, `_carried_word`, `_odds` and `_explains` stay there as
  one-line doors to figure.gd, so the lines that call them did not change.
- **The template**, `biogenic.pot`, is written again: the same 502 messages, 52 of them
  now referenced from figure.gd, and the notes of `dash` and `push` in the other order.
  `fr.po` is untouched, and `--lint-all` says what it said before, to the pixel.

**Checked: pixel-identical.** Every frame is `tools/shot.tscn` driving
`tools/drive.tscn` under `--fixed-fps 60 --rendering-driver opengl3`, with `--seed=`, at
1280x720 and 2400x1080: three times on the commit before this one, and twice after it.
47 poses, 94 frames:

- `G` of `gene-stats.md` §8 with the numbers off and on, a chip read, the three-copy
  tail in both views, a chip and the switch hovered, and Tab walked to a chip, to the
  inside, to the switch, and to a waiting gene's chip and a fork's;
- a gene waiting, and five; a fork waiting to be chosen (`beam-levels.md` §8.7's
  `G F5`) with the numbers off and on, with a gene in hand, with its cards up and with a
  way armed; a beam at level 7 read, armed over with a gene in hand, and at level 120;
- `dna-slots.md` §20's `T` and `S`, and `dna-slots-ux.md` §9.3's `B3`: a toxin inside
  and read, a side venom read, a toxin in hand with its ghosts, armed inside and
  outside, adding a copy elsewhere and to a form at three copies, dragged from the tray
  onto an empty slot; a gene that faces out, armed inside; the poison dragged where it
  would be a form already carried;
- `--hunger=0.72`; `--dose=harm:4`; the beam in the air over the tail; a body wearing an
  organ its DNA no longer carries;
- the choosing screen: `gene-stats.md` §8's `CH` with a worn and a carried gene read,
  with the numbers off, at a level, and `dna-slots.md` §20's `D12` with the inside;
- in French: a chip read, a gene waiting, a toxin in hand, a fork, the choosing screen.

**The three renders before were 0 px apart in all 94 frames, and both renders after
are 0 px from them.** A pose that arms a slot or a way shoots six frames after the tap:
the arm lapses on the wall clock (`ARM_TIMEOUT_MS`), and under load at 2400x1080 the
24 frames of `M07` outran it once. `--lint-all`, the CI boot of every scene and every
`ci.yml` step that runs here pass; the Android export stops only for want of an SDK.

---

## 7. What is not built here

- **Families.** The detailed view shows the cell's own line, its generation and its
  age, and nothing of the families in the water. That is row 21 of `lineage.md`, "not
  yet".
- **A cell's name on the pause screen.** Its caption still says `genome · <generation>`
  (§9).
- **Moving a cell between views.** It never happens; that is the owner's rule.

---

## 8. Owner's calls

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | When a cell dies, what does its slot show until you start a new one there? | **The dead cell, marked as dead: its name, where it died, and its last body if you look ✓ recommended** · nothing: the slot is empty at once | If you leave the game right after dying, or close it on the black screen, your cell's slot still says what happened to it, and you can take a last look at it. With the other option the slot just says "new cell", and the cell has simply vanished. Either way, your next cell starts in the same slot. |
| 2 | Do cells have names? | **Yes: each new cell arrives with a name, and you can type your own, like a world ✓ recommended** · only if you type one · no names | With names, you can tell your cells apart at a glance and call one "the fast one". Without names, a cell is shown as its view, its generation and its age, such as "full vision · fourth generation". |
| 3 | What is a new cell called before you name it? | **What the first microscopists called the little animals in a drop: slipper, bell, trumpet, proteus, swan, wheel, sparkle ✓ recommended** · cell 1, cell 2, cell 3 · the microscopists' own names: leeuwenhoek, hooke, müller | Your cells get the real old nicknames for what swims in pond water, which go well with the worlds' names (pond water, rain barrel). Numbers are plain and easy to forget. Scientists' names honour people, but read oddly on a creature. |

**Answered 2026-10-04:** "All recommended". A dead cell's slot keeps its record until a
new cell starts there (row 1); every new cell arrives with a name and can be renamed
(row 2); the defaults are the first microscopists' names for the little animals in a
drop (row 3).

**Under the table.**

- Row 3 matters only if row 2 is yes.
- Each row costs a constant or a few strings either way. The build can start on the
  recommendations.
- Under the second answer to row 1, a death deletes the slot's file (§1.5), and
  `cells-ux.md`'s record rows and lines go.

---

## 9. Left open

1. **Where a cell's water ran on, the clearing is this design's**, with no prototype
   behind it (§1.4). What to watch on the dev app: a resumed cell eaten in its first
   seconds, or one whose surroundings were cleared in a way the player notices.
2. **The migration's one hitch** has not been measured on a phone (§4).
3. **A cell from before the update shows no age** (§4), because none was kept. An age
   counted from the update would be wrong, so it is left blank.
4. **The pause screen does not name the cell**, and the TOGETHER page cannot change
   it: Back leaves the call (`cells-ux.md` §4). Both are small, and the dev app will
   show whether either is missed.
5. **Three slots a view** is enough for the migration. Players may want more, and
   `Cells.SLOTS` is the one number.
