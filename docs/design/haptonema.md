# The haptonema: holding on, and a gene's own button

The `haptonema` (chip word `cling`) holds on to what the cell touches. It came in on
`feat/gene-grab`, made with the gene skill. The owner checked it and answered,
2026-10-13:

> "Make it common for now. Add a way for genes to expose a button, so we can control
> it too. Fix all other problems and merge into dev."

## 1. The organ

**Named for a real one.** In the haptophyte algae, the haptonema is the thread between
the cell's two flagella. It coils, it sticks, and it holds on to what it touches. That
is all this gene does, so the name explains the mechanic on sight (`CLAUDE.md`,
"Realism is a tool").

**What it does, while the cell clings** (`game/mechanics/grip.gd`, `food.gd`):

- **At the drop's edge, the cell stops.** A body within its tether of the rim moves
  no further while it clings. A water cell's swimming pace is zeroed, and your
  velocity is.
- **Another cell is held.** A body that lies past touching, but within the tether,
  is drawn back towards the clinging cell. Each step closes `grip` of the gap, a share
  of the push the solid bodies already use. Past the tether, the hold breaks and the
  body is let go.

| Copies | `grip` (share of the gap closed each step) | `tether` (µm past touching) |
|---|---|---|
| 1 | 50 % | 6 |
| 2 | 75 % | 9 |
| 3 | 100 % | 12 |

These are starting values. Balance waits for players.

**Its look** is a coil of four turns, in the movers' sky blue at shade 1 (`myoneme`'s
coil has two).

## 2. In the water: common, for now

`water.rarity` is `common` and the haptonema is a drifter that drift may bring. The
water makes it as it makes the other commons, so a player meets it within the first
minutes of a run and can eat it.

The branch shipped it with `"drifter": false` and tagged `never_drifts`. Nothing in
the game could make it, and a player could never get it. The drop probe's lineage 4
check caught that ("every live variety carried"). The branch then exempted genes
nothing makes from that check, which hid the very problem the check exists to find.
The exemption is gone. A gene nothing makes fails lineage 4 again, as
`game/genes/README.md` says it should.

Four commons instead of three changes the water's draws:

- **The seeded pins move.** These are `ci.yml` check 8 and the drop probe's recorded
  lines and digests.
- **The gene probe's "commons keep their share" check is reworked.** It used to add
  three uncommon organs of its own and expect the commons to be crowded below
  `COMMON_SHARE`. With four commons, three no longer reach that line. The check now
  adds them one at a time until the others are scaled: six today.

## 3. The cling, from the instincts

`haptonema.cling` is an output, so an instinct can claim it (automation.md §4.3). A
water cell's rules can come to hold it by mutation. Your autopilot clings while an
instinct of yours claims it.

## 4. A gene's button

**Any output a gene declares can be the hand's as well.** Mark it `"button": true`
in the organ's `declares` (gene.gd). From then on, a body that wears the organ at
the part's level gets two things:

- **A pad** (`controls.gd`). It is drawn under every control scheme, as the tail's
  hold pad is. Pads stack up the right edge, above the bottom row: the first just
  above the dash's corner, the next above that. Each one shows its organ's tile, as
  the dash pad shows `myoneme`'s. A press on it takes the cell back from the
  autopilot, as any of the hand's presses does.
- **A key** (`cell.gd`'s `BUTTON_KEYS`). The first button a body has is `Q`, the next
  `F`, then `C`. These are letters nothing else in the run reads, and they are read
  raw, as `W` and `S` are, since a content pack adds no input action. A fourth
  button has its pad alone.

**While a button is held, the part acts** as it does while an instinct claims it.
Holding works the way the tail's hold does: let go, and the part stops. A mechanic
asks `cell.hand_holds(&"<part>")`, by the part's own name, never a gene's. While the
autopilot has the cell, the instincts decide, as they do for the hold.

`Catalogue.buttons()` lists every button part, in the order the parts are declared.
`Catalogue.worn_buttons(levels)` lists those a body has. `cell.buttons()` is the
second, made once a frame, and it is what the pads and the keys are numbered by.

**One kind today: held.** A button that fires once per press, as the dash does, is
the next kind to add. It would take a `"button": &"tap"` and a call into the part's
trigger on the press.

## 5. Fixed on the way in

- **The numbers line said what the mechanic does not do.** "Absorbs 100 % of a held
  push-off" is now "grips at 100 % strength · lets go 12 µm past touching", with its
  French.
- **A hold could be missed between two water cells.** The bodies' pairs are looked
  for once, from the side met first, out to that side's own reach. A big cell that
  clung was not found by a smaller neighbour further than the widest body's reach,
  so the hold never pulled. The reach now covers the longest tether anything has
  held by (`_tether_held`), which only grows, as the widest body's bound does.
- **Your cling cost two catalogue reads per nearby body per frame.** It is now asked
  once a frame (`cell.gd`'s `_cling`), and a pair where neither body clings returns
  at once.

## 6. Multiplayer

`grip` and `tether` are judged and contact stats, so `Wire.RULES` moved on the
branch. A player on content before this cannot play with one on content after it,
until the older one updates. The cling itself is local: you hold what is near you on
your own device, and a friend's cling is not on the wire.

## 7. What to watch

- **Is the cling pad told apart from the dash pad** at a glance? The cling's coil is
  denser, but both are coils over the same dome, in neighbouring blues. If it misreads,
  the lever is the haptonema's `look`, which the pad, the chip and the body all draw.
- **Is `Q` a good key** on desktop? It is a stand-in, chosen because nothing else
  uses it.
- **Does holding the rim, or a cell, feel like anything?** Nothing yet shows that the
  cell clings, beyond the cell stopping or a held cell staying.
