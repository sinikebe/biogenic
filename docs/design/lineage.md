# Lineage: water cells divide, and pass on their genes

Pack 2 of the evolving water (`roadmap.md`, "Next"). The owner, 2026-09-29:
cells "pass both [genes and behaviour] on with small mutations, so the cell
dangerousness improve with time not only because of genes, but also from a
kind of learning". This pack is the genes. Behaviour blocks are pack 3, the
player's block screen pack 4, and the gene pass (one bite or chewing, venomous
and poisonous) is its own phase. None of them is designed here; §10 names the
room each needs.

**Status: designed, prototyped and measured; nothing here is built.** The
prototype is a scratch copy of `dev` at `b349d23` with every rule below behind a
switch, all off by default. Switched off, thirty minutes of the drop print the
same census lines as `dev` to the byte. One command run three times prints the
same lines three times. Every number was measured in this container (Godot
4.7.2, headless or under xvfb with `--rendering-driver opengl3`), and §12 has
the commands. Nothing ran on a phone.

The owner's three rules bind it: *"all cells follow the same rules. Me,
friends, NPC, doesn't matter."* -- *"A cell dies of hunger, nothing else.
Unless it gets eaten by another one."* -- *"Don't go too far with ensuring a
player lives as long as today. I'll playtest it and tell you how we can fix
that."* So the rule is the player's wherever it can be, a division is not a
death, and the player's survival is measured, not tuned.

---

## 0. What pack 1 left at r40

Measured on `dev`: the drop alone for thirty minutes at a newborn's composition
(`eco_probe`, seeds 1–3, §12). **32 to 43 of its 92 hunters sit at r40 at the
last census**, and 488 to 555 of the 1,016 to 1,066 hunters that starved died
there. A body at r40 cannot divide in pack 1, so it eats to live
(`ocean.md` §5.5). The spawner makes every hunter, at the player's size and
with the dice's organs, so nothing a hunter does reaches the next one.

Pack 1 left three hooks, and this pack uses all three (`ocean.md` §12):
`_spawn()` is the one door every new body comes in by, `Body.id` is unique for
the drop's life, and the save already has a `parent` column, 0 throughout.
`SPAWN_SHARE` (1.0) is the spawner's share of the target, and pack 1 meant
this pack to lower it (§6.5 there).

---

## 1. Decided, in one place

1. **Every body divides at `DIVIDE_RADIUS` 40, the player's rule.** A water
   cell divides on its decision tick, 7.5 times a second wherever it is, the
   first tick it is at 40 **and the drop has room for one more mouth** (§2).
   A drifter never divides, because it never grows.
2. **A division is the player's, with nobody to choose.** The mother leaves
   the water. Two daughters at 28.28 (half her area) take her place, side by
   side and touching. Each is born fed, with a new id, through `_spawn()`. One
   carries her DNA faithfully, the other carries it with a mutation when the
   drop's rate gives one, and each wears what her own expression roll gives
   her. Both stay. A division is not a death: no `food.Cause` is added (§3.1).
3. **What passes on is the DNA, as for you.** A water cell now wears what it
   was born with, and its meals write its DNA, as the player's do. In pack 1 a
   water cell grew an organ the moment it ate one (§3.2).
4. **The water mutates one division in four** (`MUTATION_CHANCE` 0.25). At
   the player's rate, one every division, the drop's families hold only half
   to two thirds of their places, and the ones that last are cannibals with
   the biggest mouths in the game. At one in four they fill the drop and their
   mouths stay as today's. The player's own division keeps one every time
   (§3.3, row 19).
5. **Every newborn gets your grace**, row 16's promise. For `FIRST_DELAY` 42 s
   after a daughter is born, no mouth begins a run at her. A mouth that touches
   her can still swallow her, as yours can (§3.4).
6. **The drop holds as many mouths as it does today**: 96 at a newborn's
   composition, 200 at a sighted player's. Births fill that room. A full-grown
   cell in a full drop waits at 40, eating to live, until a hunter dies. With
   no limit, fit families multiplied to 238 hunters in thirty minutes, and the
   frame cost rose 60 % (§2.2, row 20).
7. **The spawner keeps the food and a floor** (§5). It makes drifters to their
   count as before. It makes a hunter only while the drop's mouths are under
   half the room (`SPAWN_SHARE` 0.5), and when venom is short whatever the
   count.
8. **Lineage is a record, kept and not shown.** Every body, the player's cell
   included, has an `id`, a `parent`, a `generation` and a `lineage` (the id
   of the first ancestor the water made). The record is saved with the drop
   and the server's room, carried by no wire, and drawn on no player's screen
   in this pack (row 21). The dev app's readout counts it (§4).
9. **Full vision shows a division coming and happening.** Every cell's
   nucleus doubles from r32, as yours does, and two daughters appear where
   their mother was. Point of view feels only what changed: two smaller mouths
   where there was one (§6.4).
10. **The drop gets more dangerous, and holds there** (§6). From fifteen
    minutes to an hour its hunters cruise at 110 to 175 µm/s (a born cell swims
    at 56.5) and notice prey from 1,300 to 1,900 µm (pack 1's from about 950).
    Half again as many could swallow a born cell. A hunter grown there catches
    a born cell that turns away 14 times in 14, where pack 1's typical hunter
    catches it 3 times in 14. The grace after every birth is what a newborn
    lives on.
11. **No protocol change.** Births are the host's water. `Wire.PROTOCOL` stays
    5 and `Wire.RULES` stays `46913eab…`: net_probe's referee section passes on
    the prototype (§8).
12. **No binary change, in two phases** (§11). Everything is GDScript: a
    content pack. When it reaches players is the owner's: they run the release.

---

## 2. Who divides, and when

### 2.1 The rule

**A body at `DIVIDE_RADIUS` divides.** That is the player's rule and every
body's: forty is where `slots_for` reaches seven and the body has no arc left
to grow an organ on (`lifecycle.md` §2.1). Only a body with a mouth ever gets
there. A drifter absorbs exactly its upkeep and grows nothing, a floc grows
nothing (row 6), and a drifter's tier-0 mouth fits no living body.

**A water cell divides on its tick**, the same 7.5 times a second at which
every mouth decides, near the player or far from it (`ocean.md` §4.3). So a
lineage far away is judged by the clock the near water runs on. It divides on
the first tick it is at 40 with room (§2.2), whatever it was doing: a run, a
rest after its last meal, or a search.

**The player divides as today**: the quickening, the pinch, the choice and the
commit (`lifecycle.md` §4). A player is never kept waiting for room, because
the room is the drop's count of what *it* makes, and a player is not made by
the drop. The sister takes a place like any daughter, so a drop can run one
mouth over its room until something dies.

### 2.2 Room

**The drop holds the mouths pack 1's spawner kept**: `(1 − drifter share) ×
554`, at the share the players' senses call for (`ocean.md` §6.4). That is
96.4 at a newborn's composition and 200.5 at a sighted player's. Births fill
it, and a cell at 40 in a full drop waits, eating to live, until a hunter dies.
It is pack 1's pile-up at r40, turned into a queue. In thirty minutes at a
newborn's composition the queue held 47 to 59 cells (§6.1).

Real cultures do the same thing: a population of protists divides until its
food runs short, then sits in a stationary phase. The drop's food is held at
its count by the spawner (§5), so here the room stands in for the food.

**Without it, fit families multiply.** With every other rule as recommended
and no limit (seed 1, a newborn's composition), the hunters went 98 → 122 →
201 → 238 at 0, 5, 15 and 30 minutes. The drifters fell to 258, about half,
because the spawner pays back only what the whole drop is short of. The water
alone cost p50 1,124 µs a frame in the first window and 1,723 µs in the last.
With the room it holds 96, at 1,037 to 1,087 µs against pack 1's 1,002 to 1,100
in the same batch (§7).

At the player's mutation rate the limit is never reached, because births do
not fill the room (§3.3). With no limit at that rate and without the grace
(seed 1, ten minutes), the hunters fell to the spawner's floor: 49 to 54.

---

## 3. A division

### 3.1 The two daughters

`food.gd`'s `_divide(i, b)` is the one place a water body becomes two:

1. Retire the mother with no cause. She is not swallowed, chewed, starved or
   poisoned, so she leaves no remains and adds no `food.Cause`, which
   `Wire.RULES` fingerprints.
2. Make two DNAs. One is hers; the other is hers mutated, with probability
   `Drop.MUTATION_CHANCE`, by `Genome.mutated(dna, [])`, otherwise hers too
   (§3.3). Which daughter gets which is a coin, as on the choosing screen.
3. Give each a body: `Genome.expressed(dna)`, the player's roll at 0.55, 0.80
   and 1.00 by copies, with the mouth always expressed. A daughter who wears
   no sense is given one at tier 1, the anti-blindness grant every peer and
   every player daughter gets (`Drop.give_sense`). It is written to her body
   and her DNA.
4. Put them through `_spawn()` at `daughter_radius(40)` = 28.28, either side of
   the mother's centre across her heading, touching (centres 56.6 apart, held
   inside the rim), both facing her way. Each is fed (hunger 0, "the mother
   spent herself") and gets `FIRST_DELAY` of grace, a new id, `parent` = the
   mother's id, `generation` = hers + 1 and her `lineage`.

**Side by side, not nose to tail.** A real ciliate splits across its middle
into a front daughter and a back one, the proter and the opisthe. In the drop,
the back daughter's mouth would then sit on her sister's tail, and a mouth
swallows what fits on contact (row 15). Side by side, nobody's mouth touches
anybody, and the player's sister already goes to a side.

**The choice the player makes, a water cell does not.** The player's two
daughters are the same two; the player leans into one and the other is left in
the water. A water cell goes on as neither. Both daughters live and the water
does the choosing: whichever of them eats its way to 40 divides again. The
player's sister is now a daughter by this rule in full. She carries her own
DNA, not only the body she wears, gets the grace, and her daughters are the
player's lineage (§4).

### 3.2 What passes on: the DNA, as for you

**Every body has the player's two registers.** It has the body it wears, fixed
at birth, which it hunts with, pays upkeep on and is drawn as, and which is
what eating it gives (`Genome.dominant_of`). It also has the DNA it writes by
eating, which is what its daughters are made of (`lifecycle.md` §1). A body
the water makes is born with the two equal, "expressed whole", as a run's
first cell is.

**A water cell's meal writes its DNA**, by the rule the player's lapsed sample
follows when nobody places it. A gene the DNA carries gains a copy, up to
three. A new gene takes a free slot if the cell's radius has one
(`Genome.integrate_into(dna, gene, slots_for(radius))`), and is lost if not.
Its body does not change.

That reverses one line of `ocean.md` §5.7's audit, "a water cell's goes
straight in". It was listed as the one choice a water cell cannot make. It was
also the one place a water cell's body changed in life when the player's
cannot, and pack 2 is where that difference starts to matter: what grows on a
body stays with that body, and what is written to the DNA reaches its
daughters. The player places a gene and may write over one; a water cell
places it in the first free slot and never writes over anything. Where a
water cell puts a gene is behaviour, and pack 3's blocks may decide it.

Water cells earn no levels, so none pass on.

### 3.3 How often a daughter is changed

**A water division mutates one of its two daughters one time in four**
(`MUTATION_CHANCE` 0.25, in `drop.gd`). The mutation is the player's:
`Genome.mutated`. A water cell has no slot layout, because its organs sit in
the default order as they do in pack 1. So of the player's three kinds it can
take two: **trade**, a copy moved from one gene to another, and **drift**, one
gene replaced by one the lineage does not carry. **Shift** moves an organ to
another arc and needs a layout. `mutated(dna, [])` already falls through to
the other two when it is handed none.

**Why one in four.** Measured: the drop alone, thirty minutes, seeds 1–3,
every other rule as recommended or as named:

| a water division mutates | grace for daughters | hunters at 30 min (room 96 / 200) | could swallow r26 / r34 / r40 | hunters' cruise, µm/s | notice, µm | generation | families left |
|---|---|---|---|---|---|---|---|
| **a newborn's composition** | | | | | | | |
| pack 1: nothing divides | -- | 92–93 | 57–60 / 25–29 / 24–27 | 78 (seed 1) | 936 (seed 1) | 1 | 92–93 |
| every time, as yours | no | 49–55 | 38–39 / 15–21 / 8–10 | 90–106 | 1,071–1,339 | 8–19 | 19–27 |
| every time, a trade only | no | 48–50 | 33–36 / 13–18 / 8–12 | 75–93 | 1,145–1,330 | 4–10 | 28–39 |
| every time, as yours | yes | 56–70 | 52–70 / 46–63 / 25–40 | 102–120 | 1,509–1,629 | 44–50 | 4–8 |
| one in two | no | 51–96 | 43–80 / 16–47 / 6–25 | 94–113 | 1,423–1,488 | 22–35 | 4–20 |
| one in two | yes | 96 | 78–88 / 37–46 / 24–34 | 96–142 | 1,592–1,671 | 29–32 | 4–5 |
| one in four | no | 90–96 | 56–80 / 8–25 / 2–16 | 120–143 | 1,618–1,725 | 28–41 | 3–5 |
| **one in four ✓** | **yes ✓** | **96** | **80–84 / 20–31 / 18–26** | **106–125** | **1,293–1,814** | **23–31** | **3–4** |
| one in ten | no | 96 | 66–89 / 3–31 / 3–19 | 109–113 | 1,662–1,881 | 27–37 | 3–4 |
| **a sighted player's** | | | | | | | |
| pack 1: nothing divides | -- | 181–182 | 125–143 / 57–68 / 50–58 | 81–83 | 930–959 | 1 | 181–182 |
| every time, as yours | no | 102 | 60–75 / 21–33 / 14–19 | 83–88 | 984–1,138 | 4–6 | 64–68 |
| every time, as yours | yes | 106–115 | 75–102 / 28–93 / 15–50 | 92–114 | 1,274–1,620 | 10–39 | 7–37 |
| one in two | yes | 140–190 | 132–171 / 106–110 / 54–58 | 115–119 | 1,552–1,706 | 41–51 | 4–5 |
| one in four | no | 101–102 | 63–67 / 9–35 / 4–21 | 77–102 | 1,035–1,364 | 6–10 | 42–72 |
| **one in four ✓** | **yes ✓** | **200** | **146–168 / 48–84 / 33–49** | **124–156** | **1,582–1,744** | **37–44** | **5** |

**At the player's rate, without the grace, the water's families wear out.**
Half of all daughters carry a change, and for a family that already hunts well
a change is mostly for the worse. A trade takes its copy from the genes eating
has raised, which are the ones that work, and a drift replaces a random organ,
perhaps the tail. In that row about half of the daughters died, two thirds of
those without one meal, and the spawner held the hunters up at its floor (§5).
The same happens with trades alone, so it is the rate, not the kind. Biology
calls it mutational meltdown: in an asexual population, damaging mutations
pile up faster than selection removes them, the population shrinks, and a
smaller population sorts worse ([Lynch, Bürger, Butcher and Gabriel,
*J. Heredity* 1993](https://doi.org/10.1093/oxfordjournals.jhered.a111354)).

**With the grace, which every newborn gets anyway (§3.4), the rate trades how
many hunters there are against how big their mouths grow.** At every division
the families hold 56 to 70 of a newborn's water's 96 places and 106 to 115 of a
sighted player's 200. The families that last are the ones that eat each other.
Eating a hunter writes its dominant gene, and on a tie `dominant_of` puts the
mouth first. Their mouths climb to tier 2.7 to 3.0, and 46 to 63 of them can
swallow a player at r34, against pack 1's 25 to 29. At one in two the places
fill at a newborn's composition and mostly at a sighted one's, with mouths
between. At one in four every place fills at both compositions and the mouths
stay about where pack 1 has them. What evolves is speed and senses (§6).

**Real cells copy almost perfectly.** DNA microbes make about 0.0033
mutations per genome per replication
([Drake, *PNAS* 1991](https://www.pnas.org/doi/10.1073/pnas.88.16.7160)), and
*Paramecium* about 2 × 10⁻¹¹ per site per division, the lowest rate ever
measured
([Sung et al., *PNAS* 2012](https://www.pnas.org/doi/full/10.1073/pnas.1210663109)).
The game's genome is seven organs and its mutation is a whole organ or a copy,
so the real rate would change nothing within a play session. Gameplay decides,
and one in four is recommended for three reasons. It is the only rate measured
that fills the water with families at both compositions, so the spawner leaves
the hunters to them entirely. It leaves the danger to a grown player where
pack 1 has it, so the danger that grows is the hunting kind, which the player's
grace, darts and senses answer, rather than the contact swallow by a big mouth,
which ended almost every game pack 1's bot lost to a mouth (`ocean.md` §8.3).
And it is a small rate, as the owner's "small mutations" asked. One in ten,
measured without the grace, filled a newborn's water as well and evolved as
fast. It is there if play says the water should change more slowly.

**The player keeps one every time.** The choosing screen needs a variation to
choose between, and a player who always takes the faithful daughter has a
lineage that never mutates. The player's lineage mutates at the rate the
player chooses.

### 3.4 Grace for every newborn

**Row 16's promise, kept**: the owner kept the player's 42 s "until pack 2
gives every newborn the same". Every daughter, water or sister, gets
`FIRST_DELAY` 42 s in which no mouth begins a run at her (`_look_in_drop`
passes her over). As for the player, it is not armour: a mouth she drifts into
still swallows her if she fits (row 15). A body the spawner makes is not a
newborn. It is water that was already there, and gets none. The player keeps
its own grace after a birth, a division and a return, and the referee's
`FIRST_DELAY` does not move.

**What it does to the water.** It is what lets families fill the room at a
sighted player's composition: one in four with the grace holds 200, without it
101 to 102, the spawner's floor (the table above). Daughters that cannot be
hunted live long enough to eat.

**What it does to you**, §6.3. Hunters cannot hunt the newest cells, so their
appetite falls on everything else, a player out of their own grace included.

---

## 4. Lineage

**A record, on every body.** `Body` already has `id` and a reserved `parent`.
It gains `generation` and `lineage`, beside §3's `dna` and `grace`:

| field | a body the water makes | a daughter |
|---|---|---|
| `id` | the drop's next id (pack 1) | the drop's next id |
| `parent` | 0 | the mother's id |
| `generation` | 1 | the mother's + 1 |
| `lineage` | its own id | the mother's `lineage` |

**The player's cell is in it.** It takes an id from the drop's count at every
birth and return, so a run's first cell is generation 1 with its own lineage.
A daughter takes a new id, with `parent` her mother's id; `normal_mode.gd`'s
`_generation` is already her generation. The sister has the same parent,
generation and lineage, so the cell you left behind founds a family that is
yours. A guest's sister arrives in the host's drop as generation 1 with her own
lineage. The wire carries no lineage (§8), and so in that one case the record
starts again.

**Kept.** `drop.bodies` gains four optional columns, checked when present as
1b-2's `runs` are: `generation` and `lineage` (`PackedInt32Array`), `grace`
(`PackedFloat32Array`), and `dna` (an Array of Dictionaries by gene name,
empty wherever the DNA is the body). `cell` gains optional `id`, `parent` and
`lineage`. `FORMAT` stays 1. A 1b file loads with every body at generation 1,
its own lineage, DNA equal to its body and no grace. A pack-2 file read by a
pack-1 build drops the four columns and loads the rest. Measured on a drop aged
five minutes (about 590 bodies, 120 of them with a DNA that is not their body),
as `var_to_bytes` of its state and zstd: **30 KB more raw and 3.3 KB more
compressed**, 8 % of the whole.

**Shown nowhere a player looks, in this pack** (row 21). The dev app's frame
readout, which only the dev app draws, gains two rows in its own grammar:
`generation`, the hunters' mean, and `families`, how many of the water's
founders they descend from. The owner can see the water evolving while
playing it (§6.4 has the frame). Full vision and the pause screen show nothing.
A family view is a pack-4 or later screen, and the record is what it would
read (§10).

---

## 5. The spawner backs off

**The food is the spawner's, always.** Drifters do not divide, so the spawner
makes every one, to their count: their share of the target, 457 at a newborn's
composition. With births on, it asks the drifter question of the target, not of
the standing drop. Asked of the standing drop as pack 1 asks it, it refused the
peers it no longer makes and stopped making drifters too: the prototype's first
run fell from 555 to 466 bodies in one minute.

**Hunters are the families'.** Births take the room first. The spawner makes a
peer, tuned to the player as in pack 1, only while the drop's mouths are under
`SPAWN_SHARE` 0.5 of the room. A drop's first fill is the spawner's, and its
peers are the founders. A drop whose families all failed refills to half from
the spawner, and births do the rest. In thirty minutes at a newborn's
composition the spawner made 10,365 to 10,524 bodies, almost all drifters,
against pack 1's 11,171 to 11,241. It wanted a hunter and left the place to
births 0 to 51 times.

**So the hunters stop being made for you.** Pack 1 made every hunter at the
player's size ±34 %, with the mouths the player's senses call for
(`ocean.md` §8.4). From pack 2 only their number and the food still follow the
player: the room and the drifters' share. What the hunters are is what their
families became. A newborn who joins an old server room meets hunters shaped
by the room's whole history, not hunters made for a newborn.

**The floors.** The drifter floor is unchanged. The gene floor is unchanged for
every gene a drifter carries. **Venom** came back in pack 1 through the next
peer, and peers are now rare: in §6.1's hour-long runs the drop held no
venomous body at 3 or 4 of its 13 censuses on every seed, 11 of 39 in all. So
when venom is short the spawner makes its next peer with it, whatever the
count, as pack 1 gave it to the next peer. The floor beats the back-off.
Measured on the same three seeds for an hour: all 16 genes carried at all 39
censuses, from 3 to 42 venomous peers an hour by seed. The rest of the water
read as before within the seeds' spread: 96 hunters cruising at 110 to 118 and
noticing from 1,321 to 1,869, at generation 38 to 62.

**The drop's size.** From fifteen minutes to an hour it holds 519 to 530 living
at a newborn's composition, against pack 1's 522 to 530, and its food, 423 to
434 drifters, is pack 1's 430 to 437. At a sighted player's composition it holds
498 to 509, about as pack 1 does, but with 200 hunters eating where pack 1 had
182 its drifters run about 5 % lower: 298 to 309, against pack 1's 317 to 328
(`ocean.md` §5.9). The spawner's lag is the gap, and `SPAWN_TAU` is its dial.

---

## 6. What the player meets

### 6.1 The drop over an hour

The drop alone, as recommended (one in four, the grace, the room), seeds 1–3,
`eco_probe` (§12). These runs predate venom's floor (§5), which changes nothing
here beyond the seeds' spread:

| composition | at | hunters | at r40, waiting | could swallow r26 / r34 / r40 | dread r26 / r34 / r40 | cruise, µm/s | notice, µm | mouth tier | generation | families |
|---|---|---|---|---|---|---|---|---|---|---|
| a newborn's | 0 | 96–101 | 0 | 22–28 / 3–4 / 0 | 0.22–0.39 / 0.02–0.09 / 0 | 61–64 | 736–787 | 1.11–1.17 | 1 | 96–101 |
| | 5 min | 80–96 | 0–11 | 48–59 / 4–8 / 2–4 | 0.51–0.65 / 0.03–0.18 / 0.01–0.08 | 110–111 | 1,409–1,529 | 1.09–1.20 | 8 | 18–22 |
| | 15 min | 96 | 11–39 | 68–76 / 15–20 / 10–13 | 1.04–1.18 / 0.34–0.40 / 0.13–0.15 | 111–138 | 1,536–1,790 | 1.23–1.39 | 16–20 | 5–9 |
| | 30 min | 96 | 47–59 | 80–84 / 20–31 / 18–26 | 1.18–1.57 / 0.48–0.65 / 0.15–0.32 | 106–125 | 1,293–1,814 | 1.29–1.49 | 23–31 | 3–4 |
| | 60 min | 96 | 49–64 | 82–93 / 22–38 / 22–33 | 1.37–1.83 / 0.53–0.83 / 0.29–0.41 | 111–115 | 1,309–1,889 | 1.39–1.70 | 37–49 | 1–3 |
| pack 1 | 30 min | 92–93 | 32–43 | 57–60 / 25–29 / 24–27 | 1.04–1.06 / 0.45–0.73 / 0.27–0.51 | 78 (seed 1) | 936 (seed 1) | 1.51 (seed 1) | 1 | -- |
| a sighted player's | 0 | 195–205 | 0 | 63–79 / 14–17 / 0 | 0.81–1.13 / 0.12–0.18 / 0–0.02 | 66–69 | 675–780 | 1.29–1.40 | 1 | 195–205 |
| | 15 min | 104–200 | 0–6 | 67–127 / 16–24 / 8–13 | 1.08–1.49 / 0.27–0.50 / 0.14–0.26 | 110–136 | 1,579–1,709 | 1.25–1.55 | 16–22 | 10–32 |
| | 30 min | 200 | 9–46 | 146–168 / 48–84 / 33–49 | 2.24–2.85 / 1.04–1.60 / 0.55–0.92 | 124–156 | 1,582–1,744 | 1.53–1.97 | 37–44 | 5 |
| | 60 min | 200 | 32–92 | 166–169 / 72–93 / 44–57 | 2.67–3.06 / 1.37–1.70 / 0.59–1.00 | 120–175 | 1,636–1,673 | 1.59–2.04 | 62–71 | 2–3 |
| pack 1 | 30 min | 181–182 | 66–75 | 125–143 / 57–68 / 50–58 | 2.11–2.40 / 1.03–1.28 / 0.66–0.96 | 81–83 | 930–959 | 1.59–1.78 | 1 | -- |

**It gets more dangerous fast, and then holds.** The change is in what the
hunters are more than in how many there are. In five minutes they cruise at
110 µm/s, against pack 1's 78. By fifteen they notice prey from twice as far
as the drop's founders did. Threats to a born cell rise by half: 82 to 93 of
96 hunters can swallow one after an hour, against 57 to 60 in pack 1. To a cell
at r34 or r40 the counts stay about where pack 1 has them at a newborn's
composition. At a sighted player's composition the r34 count rises by about a
third and the r40 count stays. Every measure flattens between thirty and sixty
minutes. The server's empty room, run three hours as recommended
(seed 1), held 96 hunters throughout at generation 104, cruising at 109 to 122
and noticing from 1,273 to 1,845, the threats between 74/15/13 and 92/42/38.
Pack 1's room over the same three hours: 92 hunters cruising at 78 to 81.

**What the water evolves.** After an hour the commonest hunter wears every
organ at tier 3 but its mouth, which stays at tier 1. For example: `cirrus`,
`flagellum`, `chemocyte` or `ocellus`, `axoneme`, `pellicle`, `vacuole` and
`crista` at 3, `cytostome` at 1. That is a fast, far-sensing, armoured hunter
with a small mouth, which eats drifters and newborns and seldom anything big.
Its upkeep is 2.1 to 2.4 times a born cell's, paid for by `crista` and a
`vacuole` tank. Families narrow fast: in thirty minutes three or four
founders' descendants hold the drop, and in an hour one to three. In full
vision the water fills with a few kinds of cell, and siblings look alike.

**Hunters live better.** In the three-hour room the hunters starved 3,184 times
against pack 1's 6,258, ate 895 hunters against 7,372, and ate 65,024 drifters
against 51,098.

### 6.2 The chase

`chase_probe`, `ocean.md` §15.6's method: a born cell (r26) against a hunter its
own size, posed 900 µm off and running at it, 14 seeds, the hunter's mouth tier
3 in both rows so that only how it moves differs:

| hunter | does nothing: caught | turns away: caught | median catch |
|---|---|---|---|
| pack 1's typical: `cirrus` 2, `flagellum` 2, `chemocyte` 1 | 12 of 14 | 3 of 14 | 7.8 s / 14.1 s |
| grown in an hour of pack 2: `cirrus`, `flagellum`, `chemocyte`, `axoneme`, `pellicle`, `vacuole`, `crista` at 3 | **14 of 14** | **14 of 14** | **3.9 s** |

**The chase contract does not survive the water's evolution.** "A cell that
turns away and commits escapes" (`food-and-predators.md` §5.4.1) holds against
pack 1's hunters and fails against what pack 2's drop grows in fifteen to thirty
minutes. A newborn cannot outswim it. What keeps a newborn alive is not being
hunted: the grace after each birth, a dart, and staying out of its senses. This
is the owner's "dangerousness improve with time" measured, and it is the first
thing a playtest should feel.

**If playing says it is too much**, the mutation rate is not the lever: speed
evolved at every rate measured (§3.3). Two rules are. The grace's length
protects the player, and changing it is a protocol change, since the referee
grants it. `UPKEEP_PER_TIER` (0.18) prices what evolves, and it is the
roadmap's rule that a build strong on every axis should be one that starves.
The water's maxed hunters live on 2.1 to 2.4 times a born cell's upkeep. Both
are the player's numbers as much as the water's, and neither was turned here:
they are for the playtest to turn.

### 6.3 The forage bot

`forage_probe` is `ocean.md` §8.3's bot: it swims at food through anything,
passes over venom, and answers a division by leaning port. Here it ran in a
drop aged fifteen minutes, seeds 1–16 at 16:9 and at 20:9 (§12):

| the drop | games | starved | eaten | lost (16:9 / 20:9) | hunters ran at it | meals a game | food within 1,400 µm | mouths within 1,400 µm that could swallow it | dread, mean (time above 0.5) |
|---|---|---|---|---|---|---|---|---|---|
| pack 1 | 32 | 10 | 4 | **14** (7 / 7) | in 3 games, 7 runs | 14.0 | 28.0 | 1.02 | 0.230 (17 %) |
| **pack 2, as recommended** | 32 | 9 | 3 | **12** (6 / 6) | **never** | 15.1 | 27.7 | 0.82 | 0.189 (15 %) |
| pack 2 with nobody's grace, yours included | 32 | 4 | 2 | **6** (3 / 3) | in 3 games, 3 runs | 14.9 | 26.5 | 0.58 | 0.150 (9 %) |

**The bot cannot tell pack 2 from pack 1.** It lost 12 games against 14, with
20 of the 32 ending differently. That is the whole drop played out
differently, which is how `ocean.md` §8.3 says a change to every water cell
reads: chance alone moves a set like this by that much. Nothing ran at it,
because it divides every 37 to 42 s, inside its own 42 s of grace, and in a
drop aged fifteen minutes the hunters near its size have small mouths (§6.1).
**The bot is not the player pack 2 changes most.** A person who takes longer
over a generation meets what the chase measures (§6.2), and that is the
playtest's first question.

**With nobody's grace the bot lost fewer games, not more**: 6 against 12. The
water, evolved without the newborn grace, held fewer hunters (§3.3), so the bot
met fewer mouths that could swallow it (0.58 within 1,400 µm, against 0.82).
Its own grace hardly came into it: hunters ran at it in 3 games of 32. That is
the newborn grace's other side. It is what fills the water with families
(§3.4), and fuller water is harder on a player who is out of their own grace.
Both changes, the player's grace and the water's, are in that one row, so it
does not separate them.

### 6.4 What is drawn

**A division coming.** `vision.gd` passes `double = smoothstep(32, 40, r)` to
`draw_cell` for every water cell in the drop, the argument the player's own
nucleus has always used. A cell nearing division shows two cores, read off its
radius. The wire and the replay already carry the radius, so a guest's mirror
and both replay panes draw it with no new field. In pack 1 nothing divided, so
a doubled nucleus would have been a lie; from pack 2 it is true of every body.

**A division.** In one frame the mother is gone and two daughters touch where
she was, each wearing her own roll. They then drift apart as any two bodies do.
Rendered (`tools/shot.tscn` over `drive.tscn`, `--fixed-fps 60`, both shapes
and both views, §12): a posed r38 hunter, grown to r40 at 1.2 s, divides on its
next tick.

| frame | judged |
|---|---|
| `before`, 1.15 s, full vision | the hunter dark, red-lipped and big, with two nuclei stacked on its axis: readable as about to divide at 1280x720 and at 2400x1080 |
| `after`, 1.45 s, full vision | two smaller cells side by side where it was. One keeps a red lip, because her mutation raised her mouth; the other has none. Readable as one cell become two at both shapes, and abrupt: the frame between has no pinch |
| `later`, 2.4 s | the two still touching, drifting |
| point of view, 1.15 and 1.45 s | nothing new, which is right: no sense reports a division. Dread held at its 0.95 cap (other mouths are near); the strongest single threat fell from 0.78 to 0.63 as one mouth became two smaller ones |
| the dev app's readout (`--dev-readout`, a drop aged fifteen minutes, 11.5 s in) | `generation 17` and `families 7` under the readout's five rows, in its own words and figure column, at both shapes; at 2400x1080 the panel widens for "% of 60 Hz" as it always has. The frame times in the shot are this container's software renderer, not a phone |

The `after` frame rendered four times was 0 pixels apart. **The abrupt frame is
the UX designer's to soften**, as `ocean.md` §7.6 left the death by hunger: a
pinch of a beat, drawn from the body's age, would need nothing on the wire.
Nothing in the rules waits on it.

---

## 7. Cost

**The same bodies, so the same frame.** The room holds the hunters at pack 1's
count. Measured as the water alone (`eco_probe`, p50 µs a frame, three runs at a
time): at a newborn's composition in thirty minutes, 1,037 to 1,087 against pack
1's 1,002 to 1,100 in the same batch. In the empty room over three hours, 547 to
593 against 534 to 555. What a division adds is one compare a tick for a body at
40 and two spawns about every two seconds across the drop. The grace adds one
compare per candidate in a prey search.

**With the player in it**, `ocean.md` §4.4's method:
`drive.tscn --field-cost=3600` at `--radius=30` with a tier-1 nose and
`ampulla`, in a drop aged fifteen minutes, seeds 7, 12345 and 2026, twice each.
Pack 1 and pack 2 were interleaved, and each run waited until no other Godot
ran and the one-minute load was under 1.0. All twelve got that window, and
nothing else started during any of them (§12). The cell dies in every run, so
1,809 to 3,196 frames were timed.

| the drop, aged fifteen minutes | p50, µs a frame | p50 median | p90 |
|---|---|---|---|
| pack 1 | 1,385–1,633 | 1,487 | 1,706–2,721 |
| **pack 2, as recommended** | **1,293–1,429** | **1,342** | **1,721–2,276** |

**No more than pack 1, and if anything a little less.** At `ocean.md`'s
assumed phone factor of six it is 7.8 to 8.6 ms of the 16.7 ms frame. For pack
1's drop `ocean.md` §4.4 estimated 7.1 to 8.0 ms, and the owner's phone then
held that drop at 0 % dropped.

**A phone that hosts a guest is still unmeasured** (§13). Nothing here adds
bodies to it.

---

## 8. Saves, the shared pond, the server, the replay

- **Births are the host's water.** A host's drop divides, and so does the
  server's room. A guest's mirror sees the mother's id leave its send set and
  two new ids arrive, with a GENOME each, exactly as when bodies come into
  reach. A guest's own drop is set aside while it is away and does not divide.
- **The referee judges no water cell**, so nothing it copies moves. The
  player's division (radius, daughter size, sister ring, the grace, the gift)
  is untouched, and no `food.Cause` or `food.Contact` is added. **`Wire.PROTOCOL`
  stays 5 and `Wire.RULES` stays `46913eab…`.** Measured: `net_probe
  --referee-only` on the prototype, 0 failed, the fingerprint unchanged. A
  host and a guest on loopback (`drive.gd --pond=host`), with the host's water
  dividing, ran 4,140 simulated seconds with no script error and the room full
  at 96.
- **Mixed builds play together.** A pack-1 phone and a pack-2 phone share
  PROTOCOL 5 and the same RULES, so neither refuses the other. Whose water
  divides is the host's build's.
- **A guest's sister carries what she wears.** SISTER sends her body and never
  sent her DNA, so a guest's declined daughter comes into the host's drop with
  DNA equal to her body. A host's sister carries her whole DNA. That is the one
  place a newborn's genes are not all passed on, and the next protocol change
  can add her DNA to SISTER (§13).
- **The server's room** keeps lineage the way it keeps everything else (§4), and
  is where generations add up: 51 in its first hour and 104 in three, empty.
- **The replay** records births as it records any body taking a slot. The
  mother's slot writes radius 0 and two newcomers take slots. The doubled
  nucleus is drawn from the recorded radius. Nothing new is recorded.

---

## 9. Generic mechanics, names at the edges

| file | knows | does not know |
|---|---|---|
| `game/mechanics/descent.gd` **new** | a record of descent, `[id, parent, generation, lineage]`, as static functions on ints: a founder, a child of a record, and the two points a body of radius `r` splits into across an axis, touching | cells, genes, water |
| `game/mechanics/replenish.gd` | `room(count, target) -> int`: how many more a population may hold, which births and the spawner's floor both ask | what is made |
| `genome.gd` | unchanged: `expressed`, `mutated` and `integrate_into` are the gene edge, called as they are | -- |
| `drop.gd` | this water's numbers and decisions: `MUTATION_CHANCE` 0.25, `SPAWN_SHARE` 0.5 (now the share of the room the spawner keeps), `ROOM_SHARE` 1.0, `hunter_room(share)`, and `daughter_dna(dna)` → `[faithful, changed, kind]` | how a grid or a debt works |
| `food.gd` | `_divide`, the one place a water body becomes two; meals into the DNA; the grace in the prey search; the spawner's back-off; the sister's DNA | the arithmetic above |

A second water writes its own rate and room in its own environment file;
nothing in `game/mechanics/` changes.

---

## 10. Hooks for packs 3 and 4

| later | the hook pack 2 leaves |
|---|---|
| **behaviour passes on** (pack 3) | `_divide` is the one place a body becomes two. A brain is copied there, mutated by the blocks' own operator at a rate of its own. `Body.brain` stays null in pack 2 |
| **where a gene goes** (pack 3) | a water cell's meal takes the first free slot and never writes over one (§3.2). That is behaviour, a block's to decide, as the player decides on the pause screen |
| **the same blocks drive the player** (pack 4) | the player's division is untouched, and its choice is the player's selection. The record already holds the player's family |
| **a family you can see** (later, row 21) | `id`, `parent`, `generation` and `lineage` on every body and in the save. Full vision could tint a lineage, or the pause screen count your sister's descendants |
| **lineage on the wire** (the next protocol change) | SISTER can carry her DNA and the guest's lineage. A POND entry has a spare flag bit for a family mark |

---

## 11. Build plan

### 11.1 Files

| file | change |
|---|---|
| `game/mechanics/descent.gd` | new (§9) |
| `game/mechanics/replenish.gd` | `room(count, target)` |
| `game/normal/drop.gd` | `MUTATION_CHANCE`, `ROOM_SHARE`, `SPAWN_SHARE` 1.0 → 0.5 with its new meaning, `hunter_room`, `daughter_dna` |
| `game/normal/food.gd` | `Body.dna`, `generation`, `lineage`, `grace`. `_spawn` writes the record and the DNA. `_divide(i, b)`, called from `_step_one` on the body's tick at 40 with room. `_grow` writes the DNA. `_look_in_drop` and the pond's person loop pass over a body in its grace. `_make_one` keeps drifters to their count, makes a peer only under the floor or for venom. `put_sister` and `place_sister` take a DNA and a record. `drop_state` and `load_drop` gain the optional columns. `take_id()` for the player's cell. A census line for lineage, for the probes |
| `game/normal/normal_mode.gd` | the player's `id`, `parent` and `lineage` at every birth and return, in `player_state` and the cell's save. `_be_born` hands the sister her DNA (`other["tiers"]`) and record |
| `game/normal/drop_save.gd` | the optional columns and `cell` keys, checked when present (§4) |
| `game/vision/vision.gd` | `double` for every water cell in the drop (§6.4) |
| `game/dev/frame_readout.gd` | the `generation` and `families` rows, dev app only (§4) |
| `tools/eco_probe.gd`, `tools/drive.gd` | the lineage census line, and switches for every rule here: `--births=`, `--mutate=`, `--room=`, `--floor=`, `--newborn-grace=`, `--split=` |
| `tools/drop_probe.gd` | the checks in §11.3 |
| `tools/net_probe.gd` | `pond-field` with the host's water dividing |

**Nothing** in `addons/launcher/`, `ci/` or `project.godot`.

### 11.2 Phases and the release

Each phase is one pull request into `dev`, played on the dev app before the next.

| phase | contents | the owner can try |
|---|---|---|
| **2-1** | the record and the second register, with nothing dividing: `descent.gd`, `room()`, the Body fields, the player's id, the sister's DNA, the save's columns, the lineage census line, drop_probe's save and record checks. A water cell's DNA is still its body (a meal writes both), so the drop's census lines are `dev`'s to the byte | nothing new: it is groundwork, like 1a-1 |
| **2-2** | the water divides: `_divide`, the room, meals into the DNA, `MUTATION_CHANCE`, the grace, the spawner's back-off and venom's floor, the doubled nucleus, the dev readout line, drop_probe's division checks and net_probe's pond-field | an evolving drop. Play it new and come back to it after fifteen minutes, and after an hour |
| **the release** | | when the owner runs it |

**Releases are the owner's.** The owner, 2026-10-01: *"Don't bother for the
release. I'll run the release skill when everything is ready."* Nothing about
playing together changes, so a release with either phase in it locks nobody
out, and 2-1 alone gives a player nothing. **`binary_version`: no bump.**

### 11.3 Probes, and what CI checks

`drop_probe`'s "Check the drop" step gains, each check failing with its rule
taken out:

1. **A division is the player's**: over five minutes with births, every water
   body that divided was at 40. Each made two bodies at `daughter_radius(40)`,
   touching, with `parent` its id, `generation` + 1 and its `lineage`. One
   daughter's DNA equals the mother's, and the other's equals it or differs by
   one trade or one drift. Both keep a `cytostome`.
2. **Expression**: every daughter's body is a subset of her DNA at the same
   copies, the mouth always worn, and a daughter who wears no sense wears one
   at tier 1.
3. **The room**: the drop's mouths never exceed the room plus the players'
   sisters, and no water cell divides into a full drop.
4. **The spawner**: no peer while the mouths are at or over `SPAWN_SHARE` of
   the room, except for venom. Drifters at 90 % of their count or more after
   five minutes. Every gene, venom included, carried at every census.
5. **The grace**: no run begins at a body whose grace is running (every
   `_start_run` checked for five minutes).
6. **A water cell's meal writes its DNA, never its body.**
7. **Determinism**: one seed twice with births, the same census line.
8. **The save**: round trip with the new columns, to the bit. A 1b file
   without them loads as generation 1. A room saved and loaded goes on to the
   same census (`ocean.md` §14.3 check 12, now dividing).
9. **The sister**: she carries the declined daughter's DNA, the player's
   lineage and the player's id as her parent.
10. **The identity gate for 2-1**: with births off, the census lines equal
    `dev`'s.

`net_probe`: the referee section passes unchanged (it fails if a fingerprinted
constant moved), and `pond-field` runs the host's water dividing, so that a
guest's mirror sees a mother leave and two daughters arrive, with no foul.

### 11.4 What it replaces

| pack 1 | pack 2 |
|---|---|
| hunters pile up at r40, unable to divide (`ocean.md` §5.5, §16 item 5) | a queue for room: a cell at 40 divides when a hunter dies |
| the spawner makes every hunter, at the player's size (§6.4 there) | births make them, and the spawner keeps the food and a floor of half |
| `SPAWN_SHARE` 1.0 of the whole target | 0.5 of the room, with drifters always to their count |
| a water cell's meal grows its body ("goes straight in") | it writes the DNA, as the player's does |
| `FIRST_DELAY` the player's alone (row 16) | every newborn's |
| the sister is a body, her DNA dropped (`put_sister(…, body)`) | she carries her DNA and the player's lineage |
| venom back through the next peer | through the next peer, whatever the count |
| hunters live about a minute and leave nothing behind (§16 item 7) | families 37 to 71 generations deep after an hour |

---

## 12. To measure again

Every probe is in `tools/`, headless, `--fixed-fps 60`, on the prototype's
switches (in the build they are `drive.gd`'s and `eco_probe`'s, §11.1). **R** is
the recommended water: `--births=1 --mutate=0.25 --grace=42` for `eco_probe`,
`--births=1 --mutate=0.25 --newborn-grace=42` for `drive.gd`. With none of them,
it is pack 1, byte for byte.

```
# the drop alone (§3.3, §6.1): seeds 1-3, --sensed=0.2 and 0.6
godot --headless --path . --fixed-fps 60 -s res://tools/eco_probe.gd -- \
    --seed=S --until=1800 --every=300 --sensed=0.2 R
# §3.3's rows: --mutate=1|0.5|0.1, --kinds=trade, --grace=0; no limit: --room=0
# §6.1: --until=3600; the room: --empty-room --until=10800 --every=1800

# the chase (§6.2): S = 1..14, with and without --evade
godot --headless --path . --fixed-fps 60 -s res://tools/chase_probe.gd -- \
    --seed=S --mode=0 --scheme=0 --hunt=900 --chase-for=40 --desert=1500 [--evade] \
    --hunter-genome=cytostome:3,cirrus:2,flagellum:2,chemocyte:1
# grown: --hunter-genome=cytostome:3,cirrus:3,flagellum:3,chemocyte:3,axoneme:3,pellicle:3,vacuole:3,crista:3

# the forage bot (§6.3): S = 1..16, --screen=1280x720 and 1600x720
godot --headless --path . --fixed-fps 60 -s res://tools/forage_probe.gd -- \
    --size=1280x720 --seed=S --mode=0 --scheme=0 --genome=cytostome:1,cirrus:1,flagellum:1 \
    --probe-until=180 --avoid-venom --screen=1280x720 --age=900 [R]
# without anyone's grace: --births=1 --mutate=0.25 --newborn-grace=0 --first-delay=0

# the frames (§6.4): T = 1.15, 1.45, 2.4; --mode=1 and 0; 1280x720 and 2400x1080
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    --fixed-fps 60 res://tools/shot.tscn -- --scene=res://tools/drive.tscn --out=F.png \
    --wait=T+1.5 --size=1280x720 --seed=7 --scheme=0 --mode=1 R \
    --cell=3,200,35,38,cytostome:1+cirrus:1+flagellum:2+ampulla:1+chemocyte:1,150 \
    --release-at=1.0 --grow-posed-at=1.2 --freeze-at=T
# the readout (§6.4): the same, with --age=900 --dev-readout --freeze-at=11.5 and no --cell=
```

`--grow-posed-at=` is the prototype's: it grows the posed bodies to 40 at that
time, because a body posed at 40 divides while it is held and its daughter is
posed again. `--dev-readout`, also the prototype's, poses the run as a dev-app
build so that the readout draws. `--kinds=trade` keeps a water mutation to a
trade. The save's size is a 30-line script: a drop aged 300 s, `var_to_bytes`
of `drop_state()` with and without the columns, and zstd. The idle cost runs
waited, before each, until no other Godot ran and the one-minute load was
under 1.0, and logged whether anything started meanwhile (`ocean.md` §15.1).

---

## 13. Left open

1. **A phone that hosts a guest** is still unmeasured, as it was after pack 1.
   Pack 2 adds no bodies to it.
2. **The bot does not feel the hunting** (§6.3). It divides every 37 to 42 s,
   inside its own 42 s, so it is almost never hunted, and the water's speed
   shows in the chase probe instead. A person who takes longer over a
   generation meets it. That is a playtest's to judge, first.
3. **The water converges.** In an hour one to three families hold a drop, and
   the server's room is one family after two hours. Variety comes back only
   through the one change in four and the spawner's floor. If playing says the
   water is too uniform, a higher floor brings in more founders tuned to the
   player, and a higher rate changes the families faster.
4. **A family can lose its tail.** Expression rolls each organ, and a family
   that carries its `flagellum` at one copy has daughters without it (in one
   seed's drop a family wearing tails on 6 to 21 % of its hunters held the room
   for half an hour). Such a family moves on its `axoneme` and drifts, and it is
   the player's rule. Watch it.
5. **A guest's sister carries what she wears** (§8), until the protocol next
   moves.
6. **What one generation is.** A water cell divides about a minute after it
   was born when the room is full (48 to 68 s on average, born mothers, a
   newborn's composition), so a newborn's drop is 37 to 49 generations deep
   after an hour and a sighted player's 62 to 71.
   `GROWTH_PER_MEAL` and `MUTATION_CHANCE` are the two dials.
7. **The abrupt division frame** (§6.4) is the UX designer's.
8. **Built on paper, not in the prototype.** These are new code the build must
   test: the player's id and record; the sister's DNA (the prototype's sister
   still carried her body alone); the save's columns, which were sized but
   never written or loaded; and `net_probe`'s pond-field with births. A host
   and a guest ran 4,140 seconds of a dividing drop without an error (§8), but
   nothing compared the guest's mirror with the host's water.

---

## 14. Owner's calls

Numbered on from `ocean.md`'s rows 1 to 18, which the owner answered on
2026-09-30, so that a row number names one call across both documents: rows
6, 15 and 16 above are `ocean.md`'s.

| # | Question | Options | What it means |
|---|---|---|---|
| 19 | How often is a daughter in the water born changed? *(to be played)* | every division, as yours · one division in two · **one division in four ✓** | Each time a water cell divides, one of its two daughters may come out a little different: an organ swapped for another, or a copy moved to another organ. Every division: only half to two thirds of the hunters' places fill, the families that last eat each other, and about twice as many cells as today can swallow you once you are grown. One in two: in between. One in four: every place fills, and mouths stay the size they are today. |
| 20 | How many hunters can the water hold? | **as many as today: about 96 in a newborn's water, 200 in a sighted player's; a full-grown cell waits for room ✓** · no limit but food | As many as today: the number of hunters you meet stays what it is; what changes is how good they are. No limit: good families multiply, measured at two and a half times as many hunters after 30 minutes with half the food, and the phone working 60 % harder and climbing. |
| 21 | Do you see families? | **not in this pack: the dev app counts generations, players see nothing new ✓** · full vision marks your own family: the cell you left when you divided, and her descendants | Not yet: families are kept in the save and can be shown later without changing anything else. Marked: in full vision you would recognise your sister's descendants in the water. It is a screen of its own, for the UX designer. |

**At every rate, the hunters get faster and keener** (row 19, §6.2). In 15 to
30 minutes they swim twice as fast as a newborn and notice it from twice as
far, and a newborn they have noticed cannot outswim them. The rate decides how
many hunters there are and how big their mouths grow, not whether the water
gets more dangerous.

**Not asked, because the owner's rules decide them.** Row 16 promised every
newborn the player's grace, and §3.4 is that promise. It has a side the row
did not ask about: the grace is what lets families fill the water, and fuller
water is harder on a player outside their own grace. The bot, which almost
never is, lost 12 games of 32 with it and 6 with nobody's grace (§6.3). Taking
it away from everyone, the player included, would also be a protocol change,
since the referee grants a guest's body `FIRST_DELAY`.
"All cells follow the same rules" decides that a water cell's meal writes its
DNA, not its body (§3.2), and that a sister is a daughter in full. A division
is not a death, which keeps "a cell dies of hunger or of being eaten" whole.
