# The water evolves: danger comes only from families

The owner, in the gene pass (2026-10-14), after reading how the water used to
read the player's senses:

> Let's change the rule about danger based on senses. The only thing that should
> say if the water contains danger is evolution. The water evolves. Cells does not
> appear from nothing already strong. They must be the result of evolution
> process. We'll address the difficulty of starting a new cell in a dangerous water
> later

Status: **built**. This page is the rule, what it replaced, and what to watch for
when playing. The mechanics it leans on were built earlier: division, mutation and
a meal writing DNA are `lineage.md` §2–§3, the drop's spawner `ocean.md` §6.

---

## 0. In one place

1. **The water reads nobody's senses.** How much food it holds and how many
   mouths it keeps are the same for every drop and every player
   (`food.gd`'s `DRIFTER_SHARE`).
2. **Everything with a mouth that the water makes from nothing is a newborn**:
   the body a run's first cell is born with, at the same size, with the same
   free sense. That covers the first fill of a new drop, the spawner's floor, an
   empty server room and the venom floor. Nothing is sized to you or drawn from
   dice (§1).
3. **Every mouth bigger than a newborn's was grown.** A family eats, grows to 40,
   divides, and one daughter changes (`lineage.md` §3). The families that eat
   each other grow their mouths. That is the only way danger gets into the
   water (§3).
4. **A new drop opens harmless.** A newborn's mouth cannot swallow a newborn, so
   nothing in a fresh drop can end you in one contact until a family has grown
   (§3).
5. **Unchanged**: the drifters and their gene floor, the drifter floor near you,
   where the spawner places things (out of sight, by how far your senses reach),
   the grace after every birth, and the instincts.
6. **Left for later, by the owner**: a new cell arriving in an old drop whose
   families are already dangerous (§6).
7. **No rules change.** The water is the host's, and nothing the referee judges
   moved: `Wire.RULES` and `Wire.PROTOCOL` stay. Content only, no new binary.

---

## 1. What arrives from nothing

`food.gd`'s `_seed_peer` makes **a newborn**:

| | a newborn the water makes | your first cell |
|---|---|---|
| radius | `CellBody.BASE_RADIUS`, 26 | 26 |
| body | `Catalogue.born()`: `cytostome`, `cirrus`, `flagellum`, one copy each | the same |
| a sense | one of the gift's four at one copy, at birth (`Drop.give_sense`) | one of the same four, at five seconds |
| mouth | gape 21.3 | 21.3 |

Its DNA is its body, as every founder's is (`lineage.md` §4). From then on it is a
water cell like any other: it eats, a meal writes the eaten gene into its DNA, it
grows, and at 40 it divides.

**What went**:

- **The peer band.** Arrivals were your radius ±34 %.
- **The dice.** Each arrival filled every slot its radius had with organs drawn
  from the water's pool, at one to three copies by `TIER_WEIGHTS`.
- **The arrival ceiling.** `ARRIVAL_GAPE_MAX` capped the mouth an arrival could
  carry at 40, and `ARRIVAL_RADIUS_MAX` capped its radius.

**The venom floor keeps its place, and works harder.** No drifter may carry the
toxin, and now no arrival is born with it, so the gene floor is the only way it
comes back that no family earned (`ocean.md` §6.4). When the drop is down to its
last carriers, the spawner's next newborn carries one copy, in a bonus slot. That
keeps a gene from being lost, and it is not strength: a newborn with venom still
has a newborn's mouth.

The first build lost the toxin twice in a five-minute drop, and the drop probe's
check 6 caught it. Under the old water the dice had armed about 29 of 293
hunters; now 1 to 4 of about 95 carry it, and two things changed to match:

- **A new drop's founders carry it.** Right after the first fill, before the
  floor's first count, each variety the floor keeps through a peer is given to as
  many newborns as its class keeps (`_arm_the_founders`). Before that, every new
  drop opened with none.
- **The floor gives it back up to its count.** It still queues one such variety a
  count (`Drop.count_floor`), but that variety stays due until the peers it is
  owed are made (`_peer_owed`). When both carriers die within one count, two
  newborns carry it back before the next. Before, one did, and it was still short.

**Drifters are as they were**: mouthless, 13–21 µm, each carrying one gene, with
the gene floor bringing back any gene the drop is short of.

---

## 2. One composition

**`DRIFTER_SHARE` 0.826 for every drop.** That gives 457 drifters standing and a
floor of 96 other bodies (`Drop.food_count`, `Drop.hunter_floor`).

It is the share a run's first water was made at under the old rule: a newborn
with its free sense, 0.92 lerped a fifth of the way to 0.45. So a new drop still
opens with the food and the number of mouths it always opened with. Only what
those mouths are has changed.

Above the floor, how many hunters there are is still how many the families feed
(`lineage.md` §2.2). **A starting value**: the food and the floor are what it
moves.

**What went**: `_sensed()`, `SENSE_FULL`, `BLIND_DRIFTER_SHARE`,
`BLIND_TIER_WEIGHTS`, `TIER_WEIGHTS` and `sense_tiers()`. Growing a sense used
to fill the drop with more and stronger hunters: 200 at a sighted player's
composition against 96. The water no longer looks.

**What stays keyed to you is placement, not danger.** The spawner never makes a
body inside what any player can see or sense, so the reach of your senses still
sets how far away things appear (`ocean.md` §6.3).

---

## 3. Where danger comes from now

**A newborn's mouth cannot end a newborn.** A born cell's gape is 21.3 against a
born cell's radius of 26. A fresh drop holds nothing that can swallow you on
contact.

**Two things grow it**, both earned by a family:

- **Growth.** A body that eats grows, and its gape grows with its radius: a born
  mouth at r34 is 27.9, wide enough for a newborn. A newborn that survives and
  feeds becomes dangerous to the next newborn, with no gene changed at all.
- **Evolution.** A meal writes the eaten body's dominant gene into the eater's
  DNA. A division passes the DNA on, and one daughter of every division
  changes (`lineage.md` §3.3). Families that eat hunters gain mouth copies,
  because on a tie `dominant_of` puts the mouth first. A mouth at three copies
  has a gape of 39.6 at r28.28, and that is what ends a grown player.

So the water's danger is its history. A kept drop and a server room carry their
families across runs and visits, and a new drop starts over.

### 3.1 Measured once, to see that it works

This is a check that the mechanic works, not a number to tune. The drop alone, seed
1, thirty minutes (`tools/eco_probe.gd --seed=1 --until=1800 --every=300`), was run
on the built code and on `dev`'s water at a newborn's composition, which was the
gentlest the old rule made.

The census below counts the hunters that could swallow a body of three sizes:
r26 is a newborn, r34 a grown cell, r40 one about to divide. The last column is
the hunters' mean mouth copies.

| | now: r26 / r34 / r40 | `dev`: r26 / r34 / r40 | mouth copies, now / `dev` |
|---|---|---|---|
| 0 min | **0 / 0 / 0** | 19 / 2 / 0 | 1.00 / 1.14 |
| 5 min | 38 / 6 / 4 | 35 / 9 / 4 | 1.15 / 1.20 |
| 15 min | 32 / 5 / 4 | 43 / 12 / 7 | 1.10 / 1.35 |
| 30 min | 43 / 6 / 4 | 48 / 13 / 11 | 1.19 / 1.39 |

What it says:

- **A new drop opens with nothing that can end you.** Danger to a newborn arrives
  within minutes, about as fast as it did, and it arrives by **growth**: newborns
  that eat reach r30 and more, and a born mouth there swallows a newborn.
- **Danger to a grown cell builds slowly.** Mouths that end a cell at r34 or r40
  need copies a family has to grow. In thirty minutes the families grew a few,
  and lost them again.
- **Hunters turn over fast.** The water made 2,266 newborns in thirty minutes to
  keep its floor of 96, 32 of them carrying the toxin back. The families divided
  1,043 times, but at thirty minutes the mean generation was 2.0: most hunters are young, and the floor keeps
  topping the drop up with fresh newborns. That turnover is what keeps the
  water's evolution slow. `dev`'s numbers show the same turnover (1,312
  divisions, generation 1.9); the difference is that its arrivals came already
  armed.

---

## 4. What it replaces

| before (`food.gd`) | now |
|---|---|
| `_drifter_share(sensed)`: 0.92 blind to 0.45 at `SENSE_FULL`, read off your worn senses | `DRIFTER_SHARE` 0.826, for every drop |
| `_seed_peer(b, mine, sensed)`: your radius ±34 %, a born body at drawn tiers, every other slot filled by the dice | `_seed_peer(b)`: a newborn, `_newborn()` |
| `_draw_genome`, `_draw_living`, `_draw_tier`, `_tier_weight` | gone |
| `ARRIVAL_GAPE_MAX`, `ARRIVAL_RADIUS_MAX`, `PEER_SPREAD`, `TIER_WEIGHTS`, `BLIND_*`, `SENSE_FULL` | gone |
| `_made_for`: each player's `[radius, sight]` | the same shape, so saves still load, but only how many players there are is read: whose turn the next body is placed round. The second column is 0 |
| `_spawn(at, drifter, sensed, fill, body_radius, tiers, mine)` | `_spawn(at, drifter, fill, body_radius, tiers)` |
| `--sensed=` on `tools/drive.gd` and `tools/eco_probe.gd`, `sensed_override` | gone |

`ocean.md` §6.4 and §8.4, `lineage.md` §5 and `gene-rarity.md` §3.5 carry a note
saying they were superseded here.

---

## 5. Checks

- **The gene probe**:
  - It checks the new rule. Of 400 bodies the water made while a faster tail
    variant was in the catalogue, none wears it: a variant reaches the water
    through a family.
  - The floor's budget is checked in the one composition. The crowd it must
    catch grew from 170 rare organs to 300. 170 tripped it only in a fully
    sighted player's drop of 250 drifters; in 457 they cost 9.0 %, and 300 cost
    27.4 % against the budget of 25 %.
  - The senses-by-channel half of `_senses_and_gift` went with the rule; the
    gift half stays.
- **The drop probe**:
  - Its paired runs of "a newborn's" and "a sighted player's" drop were the same
    drop twice, and are one run now.
  - Its arrival checks say what arrives now.
  - Its pinned lines were re-recorded from its own output, each with a note.
- **`ci.yml` check 8** is re-pinned: the water's arrivals changed on purpose.

---

## 6. What to watch when playing

- **How long a new drop stays harmless**, and when the first mouth that can
  swallow you shows up. In full vision it shows as a body whose lip bow turns to
  threat.
- **Whether a grown cell ever meets a real threat.** §3.1 says that within half an
  hour it mostly does not: few hunters grow mouths that end a cell at r34 or r40,
  where `dev` had 13 and 11. If the late game feels toothless, the levers are how
  fast families turn over -- the floor that refills the drop with newborns
  (`SPAWN_SHARE`), the food (`DRIFTER_SHARE`), the mutation and the grace
  (`lineage.md`) -- not a return to arrivals made strong.
- **Whether growing a sense now feels like a pure gain.** It used to make the
  water worse, and now it does not.
- **A kept drop or a server room** whose families have grown: a newborn arriving
  there meets their history. The owner has put that off for now ("We'll address
  the difficulty of starting a new cell in a dangerous water later"), and it is
  the next design question here.
