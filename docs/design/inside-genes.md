# Inside genes: the store moves in, the inside grows, and the cell mends

The owner, 2026-10-17, asked for a list of genes that could work in the inside slot,
"or we could even remove some genes from outside slots if not realistic". The list
and its decisions:

| # | Question | Answer |
|---|---|---|
| 1 | Which genes move inside? | **Only `store`** (`vacuole`), inside only |
| 2 | How much room inside? | **Grows with the cell**: 1 at birth, 2 at r33, 3 at r40 |
| 3 | Does the eyespot get an inside form? | **No** |
| 4 | Add a new inside gene, `mend` (`lysosome`)? | **Yes** |

Status: **built**. This page replaces dna-slots.md §2.2's "how many: one" and its
rule that only the toxin sits inside, and §19's first hook, which this is. The rest of
dna-slots.md stands.

---

## 0. In one place

1. **The inside grows with the cell**:
   - one slot from birth, as before;
   - a second at r33, when the body earns its fore-port arc;
   - a third at r40, when it earns its last one and divides.

   A daughter keeps the inside her DNA carries, as she keeps her mother's layout
   outside, so from the second generation the inside her mother filled is hers to
   write over.
2. **Three genes go inside, and only inside**:
   - the toxin, as poison (as before);
   - `store`, which moved in;
   - `mend`, which is new.

   Every other gene faces out, and the inside refuses it, as before.
3. **`store` works as it did.** It is a bigger tank, and now it sits inside. A save
   that wore it on an arc puts it inside.
4. **`mend` makes wounds knit faster.** A whole wound mends in 75 s. With mend, it
   takes 50, 37.5 or 30 s by copies. It is rare in the water.
5. **The water lives by the same rules.** A water cell's inside room is its radius's,
   and a meal of `store` or `mend` takes no arc.
6. **Builds on the old content and the new cannot share a pond** (`Wire.RULES`
   moved: the body plan, the new organ, the `mend` table).

---

## 1. The inside's room

`body_plan.gd`'s rows (`TODAY`), with `earned` read for the inside as it always was
for the outside:

| id | place | earned |
|---|---|---|
| `inside` | inside | from birth |
| `inside_2` | inside | r33 |
| `inside_3` | inside | r40 |

- `BodyPlan.inside_for(radius)`: the inside slots a radius has earned, 1 to 3.
- `genome.gd`'s `inside_room()`: that number, or what the DNA carries inside already,
  whichever is more, never more than 3. It plays the part `slots()` plus the
  inherited layout plays outside.
- **Placing**: a gene placed on an empty inside slot is added. One placed on a full
  inside slot writes over the gene there, as on an arc. A gene left to lapse goes into
  the first empty inside slot, or is lost when there is none, as one with no free arc
  is.
- **Drift** brings an inside gene only when the inside has room, unless the gene it
  replaces was inside too. It used to check that for the toxin alone.
- **The water**: `integrate_into` takes the room inside as it takes the room outside,
  from the body's radius (`CellBody.inside_for`). The floor's gift of a toxin to a peer
  whose inside is full gives up one of its inside genes for it, as one with no room
  outside gives up an arc (`drop.gd`'s `give_back`).

The numbers are the outside's ladder on purpose: r33 and r40 are rungs it already
has, so a body earns inside room on a step it already earns room on. Structure, not
balance.

## 2. `store` moves inside

`vacuole.gd` sets `place = INSIDE`. Its tables, its words and its numbers line are
unchanged.
- A save, a drop, or a pose with it on an arc moves it inside
  (`genome.gd`'s `_put_in_place`, which moved a save's poison the same way).
- With no room inside, it is kept anyway, over its room: nothing a player carried is
  lost.
- `Cilia.default_order` no longer seats a single-form inside gene on the skin.

## 3. `mend`, the lysosome

### 3.1 The organ

A real lysosome is the cell's stomach and its repair kit. A torn membrane is patched by
lysosomes fusing into the tear within seconds. So the name is the real organelle's, and
the ability is the one it has: no invented ability this time.

- Key `lysosome`, word `mend` (French `soin`). It is order 18, metabolism, inside only.
- It is **rare** in the water: the playbook's rule when unsure, for a gene a run may
  lean on but is not built from. It drifts, so a drifter can carry it.

### 3.2 The mechanic

A new stat, `mend`: a multiplier on the mending rate, 1 with no provider, combined by
product.
- `cell.gd`'s `mended(hurt, delta, mend)` and `dosed(..., mend)` divide
  `MEND_SECONDS` by it.
- The cell, every water body and every person read it.
- So does the referee's grace on a re-entry, from the tiers the guest wore.
- It is a `contact` stat (the host mends a person's wound), so it is in the rules the
  handshake carries.

| copies | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| `mend` | 1.0 | 1.5 | 2.0 | 2.5 |
| a whole wound mends in | 75 s | 50 s | 37.5 s | 30 s |

These are starting values. The first copy is worth having. Three copies still leave a
fight as something to get away from to recover. A body carrying harm does not mend,
whatever this says (dna-slots.md §6.2).

### 3.3 Words

| Where | English | French |
|---|---|---|
| chip | `mend` | `soin` |
| what it does | `patches your wounds, so a bite heals sooner` | `panse vos plaies, une morsure guérit plus tôt` |
| numbers | `a wound mends in {} s, not {}` | `une plaie guérit en {} s, pas {}` |

## 4. Drawing

- **An organelle inside is drawn as itself, inside the body.** `store` and `mend` are
  organelles, so they are not drawn as granules or on an arc. Each sits at one of three
  stretches (`cilia.gd`'s `INSIDE_ARCS`, in the inside's order): behind the
  nucleus, then beside it to starboard, then to port. Not in front of it: the two
  front diagonals are the first arcs a body earns, and an organelle worn on one sits
  there. It sits `INSIDE_DEEP` (0.14 of a
  radius) deeper than its look's own depth, so it lies between the skin and the
  nucleus.
- **The poison** keeps its granules under the whole skin.
- **On a tile**, an inside organelle is drawn by its kind, as every organelle is; only
  the poison is drawn as granules.
- **`mend`'s look**: a new organelle form, `dense`. It is a small body, half filled,
  with a darker core, the way lysosomes look under a microscope. Metabolism's shade 2.

## 5. The screens

- **The pause figure** stacks the inside's chips on the body, a chip's height apart
  (`figure.gd`'s `INSIDE_PITCH`, 56 px). That way no two chips share a pixel a finger
  could press, and each keeps its 48 px:
  - the first sits where the one inside chip always sat;
  - the second sits below it;
  - the third sits above it.
- **A slot not earned yet is not drawn at all**: a newborn's figure is the one it always
  was. The inside sits on the body, which is the mirror, and three faint helices on it
  read as clutter. Outside, an unearned slot is still drawn faint on the ring.
- **The arrows** go up and down the inside's column. An arrow steps past an inside slot
  not earned yet (`Figure.neighbour`), so a newborn moves between the nose, the inside
  and the tail as before.
- The figure has room for three rows (`INSIDE_ROWS`). A plan with more crowds it, and
  the gene probe says so.
- **The division screen** draws ten loci: seven outside and three inside. At the old
  48 px a locus, their words ran 34 px past the foot of a 720 px canvas. The pitch is
  44 px now.
- **Words**:

  | Where | Was | Is |
  |---|---|---|
  | empty inside slot, its line | `nothing inside yet · a toxin here becomes poison` | `nothing inside yet · store, mend or a toxin can go here` |
  | and under it | `inside your body · only a toxin goes here` | `inside your body · a toxin here becomes poison` |

  Placing `store` on an arc says `store works only inside`; a waiting toxin still says
  where it may ride.
- **Holding the body to place a gene** (dna-slots-ux.md §3.7) aims at the first empty
  inside slot, while the gene in hand works inside and there is one.

## 6. Pins that moved, and why

- **`gene_probe`**:
  - `lysosome` appended to `SHIPPED`;
  - `lysosome` appended to the drifter list;
  - the plan's rows, counts, seats, neighbours and ring.
- **`Wire.RULES`** moved: the plan's fingerprint, the new organ's tables and the `mend`
  contact table. Players on the old content and the new cannot share a pond until the
  older updates. `Wire.PROTOCOL` is unchanged.
- **The seeded runs** (`drop_probe`, `ci.yml`'s empty-library hash) moved, for two
  reasons:
  - `store` takes no arc in the water now;
  - `lysosome` joins the drifters, so the draws are not the ones they were.

## 7. What to watch when playing

All balance, which waits for players (`CLAUDE.md`).

- **A full cell carries one gene more than it did**: three inside where there was one,
  and `store` no longer takes an arc. If grown builds feel too strong, the levers are
  where the inside's slots are earned (`body_plan.gd`) and how many there are.
- **`mend`**: if fights stop mattering, the lever is `MEND_BY_TIER`. If it is never
  worth a slot, raise it.
- **Rare**: if `mend` is never seen, its class is the lever (`water.rarity`).
