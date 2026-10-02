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
   first tick it is at 40. Nothing makes it wait (§2). A drifter never
   divides, because it never grows.
2. **A division is the player's, with nobody to choose.** The mother leaves
   the water. Two daughters at 28.28 (half her area) take her place, side by
   side and touching. Each is born fed, with a new id, through `_spawn()`. One
   carries her DNA faithfully, the other with one mutation, and each wears
   what her own expression roll gives her. Both stay. A division is not a
   death: no `food.Cause` is added (§3.1).
3. **What passes on is the DNA, as for you.** A water cell now wears what it
   was born with, and its meals write its DNA, as the player's do. In pack 1 a
   water cell grew an organ the moment it ate one (§3.2).
4. **Every division changes one daughter, as yours does** (row 19, answered:
   "every division. No specific treatment between NPCs and players"). It is the
   player's own `Genome.mutated`, called as the choosing screen calls it, and
   there is no water-side rate. One difference is left, and it is the
   mutation's kind, not its rate: a water cell has no slot layout, so of the
   player's three kinds it takes two, trade and drift, never shift (§3.3).
5. **Every newborn gets your grace**, row 16's promise. For `FIRST_DELAY` 42 s
   after a daughter is born, no mouth begins a run at her. A mouth that touches
   her can still swallow her, as yours can (§3.4).
6. **No ceiling on hunters: evolution and survival decide** (row 20,
   answered). The drop guarantees today's count and nothing more. Above it,
   how many hunters there are is how many the families feed (§2.2), and the
   frame follows them (§7).
7. **The spawner keeps the food and the floor** (§5). It makes drifters to
   their own count, whatever the hunters number. It makes a hunter whenever
   the hunters are under today's count, 96 at a newborn's composition and 200
   at a sighted player's (`SPAWN_SHARE` 1.0, a floor now), and pays that back
   within a second (`FLOOR_TAU`), so the drop is never short of today's for
   long. It makes a venomous one whenever venom is short.
8. **Lineage is a record, kept and not shown.** Every body, the player's cell
   included, has an `id`, a `parent`, a `generation` and a `lineage` (the id
   of the first ancestor the water made). The record is saved with the drop
   and the server's room, carried by no wire, and drawn on no player's screen
   in this pack (row 21, answered: "not yet"). The dev app's readout counts it
   (§4).
9. **Full vision shows a division coming and happening.** Every cell's
   nucleus doubles from r32, as yours does, and two daughters appear where
   their mother was. Point of view feels only what changed: two smaller mouths
   where there was one (§6.4).
10. **Where a newborn swims, the drop gets more dangerous, and rises and falls
    with its families** (§6). By thirty minutes its hunters cruise at 112 to 133
    µm/s (a born cell swims at 56.5, pack 1's hunters at about 78) and notice
    prey from about 1,550 µm (pack 1's from about 950). Their mouths are a tier
    bigger: 87 to 125 could swallow a born cell and 71 to 106 a cell at r34,
    against pack 1's 57 to 60 and 25 to 29. Where a sighted player swims, the
    spawner still makes a third of the hunters, and the water stays close to
    today's. A newborn that turns away escapes a grown hunter without an
    `axoneme` 10 times in 14, and one with an `axoneme` never. The grace after
    every birth is what a newborn lives on.
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
the first tick it is at 40, whatever it was doing: a run, a rest after its last
meal, or a search. Nothing makes it wait (§2.2).

**The player divides as today**: the quickening, the pinch, the choice and the
commit (`lifecycle.md` §4). The sister is a daughter like any other.

### 2.2 No ceiling, and today's count as a floor

**The owner's answer** (row 20, 2026-10-01): *"evolution and survival rate
decides. We only ensure there's at least as many as today to make the drop
alive using the spawn threshold."* So nothing limits how many hunters the drop
holds. A cell at 40 divides on its tick, always, and whether its daughters live
is food and survival. **The floor** is today's count: the spawner makes a
hunter whenever the drop's hunters are under what pack 1's spawner kept,
`(1 − drifter share) × 554` at the share the players' senses call for. That is
96.4 at a newborn's composition and 200.5 at a sighted player's, paid back
within a second (§5). **The food is kept apart**: drifters to their own count,
whatever the hunters number (§5).

**Measured** (§6.1; seeds 1–3, thirty minutes, a census every five). From five
minutes on, a newborn's drop held 94 to 158 hunters, and the families fed
nearly all of them: from ten minutes on, one census in fifteen held a hunter of
the spawner's, and it held one. A sighted player's drop held 188 to 196,
between a quarter and nearly half of them the spawner's at every census. Pack
1's spawner held 89 to 93 and 180 to 185 over the same censuses. An hour on
seed 1 held 91 to 158 and 190 to 194, and the server's empty room 94 to 125 at
its half-hourly censuses over three hours (§6.1). Nothing climbed without
bound, and survival is what bounds it. About half of all daughters died within
the thirty minutes, two thirds of those without one meal, and other hunters ate
them twice as often as they starved at a newborn's composition and nearly three
times as often at a sighted player's. A cell divided about 30 s after its own
birth.

**What no ceiling costs** is §7: a tenth to a quarter more a frame than pack 1,
following the hunters.

**Two earlier measurements no longer describe the drop.** The first is the
no-limit run under one division in four: 238 hunters after thirty minutes, the
drifters halved, the water 60 % dearer. Its spawner paid back only what the
whole drop was short of, so hunters above their count stopped the food being
made. The food has its own count now (§5). The second is today's count kept
over the spawner's five seconds rather than one. Measured with every other
rule as answered, that floor held a newborn's drop at 72 to 136 hunters, and
seed 1 at 72 to 82 for nine of its twelve censuses over an hour; a sighted
player's at 155 to 170. Against pack 1's 89 to 93 and 180 to 185, that is not
"at least as many as today".

---

## 3. A division

### 3.1 The two daughters

`food.gd`'s `_divide(i, b)` is the one place a water body becomes two:

1. Retire the mother with no cause. She is not swallowed, chewed, starved or
   poisoned, so she leaves no remains and adds no `food.Cause`, which
   `Wire.RULES` fingerprints.
2. Make two DNAs. One is hers; the other is hers with one mutation,
   `Genome.mutated(dna, [])`, every division, as the player's two are (§3.3,
   row 19). Which daughter gets which is a coin, as on the choosing screen.
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

### 3.3 Every division changes one daughter

**The owner's rule** (row 19, answered on 2026-10-01): *"every division. No
specific treatment between NPCs and players."* A water division mutates one of
its two daughters every time, through the player's own `Genome.mutated`, as the
choosing screen's `_make_daughters` calls it. The water has no rate of its own:
the build adds no `MUTATION_CHANCE`, and only a tool's `--mutate=` still plays
the other rates.

**The one difference left is the kind, and why.** The player's mutation is one
of three: **shift**, an organ moved to another arc of the body; **trade**, a
copy moved from one gene to another; and **drift**, a gene replaced by one the
lineage does not carry. A water cell has no slot layout. Its organs sit in the
default order, as they do in pack 1, because nothing ever places one: the
player places each gene, and a water cell's meal takes the first free slot. So
a shift has nothing to move, and `mutated(dna, [])` falls through to a trade or
a drift. Every water division is a change, as every one of yours is, but never
a shift. The day something places a water cell's organs (pack 3's blocks, §10),
the cell has a layout and shift is its too.

**What every division does to the water** is §6.1. At a newborn's composition
the families that last are the ones that eat each other, their mouths grow, and
two to four times as many hunters as today can swallow a player at r34. At a
sighted player's the spawner still makes a third of the hunters, and the water
stays close to today's.

**The record of why one in four was recommended.** Measured before the owner's
answer: the drop alone, thirty minutes, seeds 1–3, under the earlier
recommendation's room (today's count as a ceiling) and a floor of half of it,
every other rule as recommended or as named:

| a water division mutates | grace for daughters | hunters at 30 min (room 96 / 200) | could swallow r26 / r34 / r40 | hunters' cruise, µm/s | notice, µm | generation | families left |
|---|---|---|---|---|---|---|---|
| **a newborn's composition** | | | | | | | |
| pack 1: nothing divides | -- | 92–93 | 57–60 / 25–29 / 24–27 | 78 (seed 1) | 936 (seed 1) | 1 | 92–93 |
| every time, as yours | no | 49–55 | 38–39 / 15–21 / 8–10 | 90–106 | 1,071–1,339 | 8–19 | 19–27 |
| every time, a trade only | no | 48–50 | 33–36 / 13–18 / 8–12 | 75–93 | 1,145–1,330 | 4–10 | 28–39 |
| every time, as yours (answered, under the room) | yes | 56–70 | 52–70 / 46–63 / 25–40 | 102–120 | 1,509–1,629 | 44–50 | 4–8 |
| one in two | no | 51–96 | 43–80 / 16–47 / 6–25 | 94–113 | 1,423–1,488 | 22–35 | 4–20 |
| one in two | yes | 96 | 78–88 / 37–46 / 24–34 | 96–142 | 1,592–1,671 | 29–32 | 4–5 |
| one in four | no | 90–96 | 56–80 / 8–25 / 2–16 | 120–143 | 1,618–1,725 | 28–41 | 3–5 |
| one in four (was recommended) | yes | 96 | 80–84 / 20–31 / 18–26 | 106–125 | 1,293–1,814 | 23–31 | 3–4 |
| one in ten | no | 96 | 66–89 / 3–31 / 3–19 | 109–113 | 1,662–1,881 | 27–37 | 3–4 |
| **a sighted player's** | | | | | | | |
| pack 1: nothing divides | -- | 181–182 | 125–143 / 57–68 / 50–58 | 81–83 | 930–959 | 1 | 181–182 |
| every time, as yours | no | 102 | 60–75 / 21–33 / 14–19 | 83–88 | 984–1,138 | 4–6 | 64–68 |
| every time, as yours (answered, under the room) | yes | 106–115 | 75–102 / 28–93 / 15–50 | 92–114 | 1,274–1,620 | 10–39 | 7–37 |
| one in two | yes | 140–190 | 132–171 / 106–110 / 54–58 | 115–119 | 1,552–1,706 | 41–51 | 4–5 |
| one in four | no | 101–102 | 63–67 / 9–35 / 4–21 | 77–102 | 1,035–1,364 | 6–10 | 42–72 |
| one in four (was recommended) | yes | 200 | 146–168 / 48–84 / 33–49 | 124–156 | 1,582–1,744 | 37–44 | 5 |

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
so the real rate would change nothing within a play session. Gameplay decided,
and one in four was recommended for three reasons. It was the only rate
measured that filled the water with families at both compositions. It left the
danger to a grown player where pack 1 has it, so the danger that grew was the
hunting kind, which the player's grace, darts and senses answer, rather than
the contact swallow by a big mouth, which ended almost every game pack 1's bot
lost to a mouth (`ocean.md` §8.3). And it was a small rate, as the owner's
"small mutations" asked. **The owner chose every division**, the rule that is
the same for every cell. One in four and one in ten stay what `--mutate=`
plays.

**The player's division is unchanged**: two daughters, one faithful and one
with a mutation, read on the choosing screen.

### 3.4 Grace for every newborn

**Row 16's promise, kept**: the owner kept the player's 42 s "until pack 2
gives every newborn the same". Every daughter, water or sister, gets
`FIRST_DELAY` 42 s in which no mouth begins a run at her (`_look_in_drop`
passes her over). As for the player, it is not armour: a mouth she drifts into
still swallows her if she fits (row 15). A body the spawner makes is not a
newborn. It is water that was already there, and gets none. The player keeps
its own grace after a birth, a division and a return, and the referee's
`FIRST_DELAY` does not move.

**What it does to the water.** Under the earlier recommendation's room
(§3.3's table) it was what let families fill a sighted player's water: one in
four with the grace held 200, without it 101 to 102. Daughters that cannot be
hunted live long enough to eat. Under the owner's floor the spawner makes up
whatever births do not (§2.2), so the grace should now decide how many of the
hunters are born rather than made. That was not run.

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

**Shown nowhere a player looks, in this pack** (row 21, answered: "not yet").
The dev app's frame readout, which only the dev app draws, gains two rows in
its own grammar: `generation`, the hunters' mean, and `families`, how many of
the water's founders they descend from. The owner can see the water evolving
while playing it (§6.4 has the frame). Full vision and the pause screen show
nothing. A family view is a pack-4 or later screen, and the record is what it
would read (§10).

---

## 5. The spawner keeps the food and the floor

**The food is the spawner's, to its own count.** Drifters do not divide, so the
spawner makes every one: their share of the target, 457 at a newborn's
composition and 354 at a sighted player's, **whatever the hunters number**.
Its debt is each kind's own shortfall (`Replenish.due_for`, §9), not the whole
drop's. The whole drop's was pack 1's and the prototype's first pass, and once
births took the hunters past their count it stopped the food being made: the
drifters fell to 258 (§2.2). Kept to their own count under the owner's rules,
they held at 417 to 448 at a newborn's composition and 337 to 353 at a sighted
player's, over every census from five minutes on, against pack 1's 425 to 437
and 315 to 325. They are about pack 1's in a newborn's drop, where more hunters
eat them, and higher in a sighted player's, where pack 1's one debt ran its
food short.

**The hunters' floor is today's count** (row 20). The spawner makes a peer,
tuned to the player as in pack 1, whenever the drop's hunters are under what
pack 1's spawner kept: `(1 − drifter share) × 554` at the players' senses, 96
and 200 (`SPAWN_SHARE` 1.0, a floor now). Above it nothing is made and nothing
is stopped, and births decide. A drop's first fill is the spawner's, and its
peers are the founders.

**The floor is paid back within a second** (`FLOOR_TAU` 1 s; the food keeps
`SPAWN_TAU` 5 s). Under every division the water's daughters die fast, and a
floor paid back over five seconds runs short by about five seconds of deaths:
the drop then stood well under today's count (§2.2). Within a second it does
not: no census fell under what pack 1's spawner held, the least being 91 at a
newborn's composition (pack 1: 89 to 93) and 188 at a sighted player's (pack 1:
180 to 185, §6.1). Spawns are still made out of every player's sight
(`ocean.md` §6.3), so a quicker floor shows nothing.

**So the hunters stop being made for you.** Pack 1 made every hunter at the
player's size ±34 %, with the mouths the player's senses call for (`ocean.md`
§8.4). From pack 2 only the food and the floor still follow the player. At a
newborn's composition nearly every hunter after five minutes was born, and the
spawner's came back only when a family crashed to the floor. At a sighted
player's about a third were the spawner's, made for the player and topping the
floor up. What the rest are is what their families became. A newborn who joins
an old server room meets hunters shaped by the room's whole history, not
hunters made for a newborn.

**The floors.** The drifter floor is unchanged. The gene floor is unchanged for
every gene a drifter carries. **Venom** came back in pack 1 through the next
peer. Under the earlier recommendation peers were rare, and the drop held no
venomous body at 3 or 4 of its 13 hourly censuses on every seed. So when venom
is short the spawner makes its next peer with it, whatever the count: the
floor beats everything. Under the owner's rules all 16 genes were carried at
every census of every run, 75 censuses in all.

**The drop's size.** It held 529 to 575 living at a newborn's composition and
528 to 546 at a sighted player's, against pack 1's 514 to 530 and 496 to 509,
over the same censuses.

---

## 6. What the player meets

### 6.1 The drop over an hour

The drop alone under the owner's rules (every division, the grace, no room,
today's count as a floor paid back within a second), `eco_probe` (§12): seeds
1–3 for thirty minutes, and seed 1 for an hour, with pack 1 run beside it.
Hunters are counted as born of a division / made by the spawner:

| composition | at | hunters (born / the spawner's) | drifters | could swallow r26 / r34 / r40 | cruise, µm/s | notice, µm | mouth tier | generation | families |
|---|---|---|---|---|---|---|---|---|---|
| a newborn's | 0 | 96–101 (all the spawner's) | 454–459 | 22–28 / 3–4 / 0 | 61–64 | 736–787 | 1.11–1.17 | 1 | 96–101 |
| | 5 min | 99–112 (89–112 / 0–10) | 427–438 | 57–78 / 21–24 / 10–14 | 93–103 | 1,314–1,467 | 1.48–1.51 | 7–8 | 29–38 |
| | 15 min | 97–127 (all born) | 419–435 | 88–119 / 45–99 / 29–61 | 104–119 | 1,501–1,581 | 2.11–2.61 | 23–26 | 6–12 |
| | 30 min | 97–133 (all born) | 421–433 | 87–125 / 71–106 / 42–64 | 112–133 | 1,544–1,584 | 2.49–2.94 | 43–50 | 3–12 |
| | 30–60 min, seed 1 | 91–136 (79–136 / 0–15) | 417–453 | 77–126 / 57–101 / 32–53 | 95–128 | 1,409–1,588 | 2.26–2.80 | 44–61 | 3–28 |
| pack 1 | 30 min | 92–93 (all the spawner's) | 430–437 | 57–60 / 25–29 / 24–27 | 78 (seed 1) | 936 (seed 1) | 1.51 (seed 1) | 1 | -- |
| | 30–60 min, seed 1 | 91–93 (all the spawner's) | 431–441 | 63–75 / 25–32 / 22–31 | 76–82 | 890–1,080 | 1.44–1.61 | 1 | -- |
| a sighted player's | 0 | 195–205 (all the spawner's) | 350–360 | 63–79 / 14–17 / 0 | 66–69 | 675–780 | 1.29–1.40 | 1 | 195–205 |
| | 5 min | 190–194 (105–146 / 48–87) | 346–353 | 115–137 / 52–54 / 29–36 | 75–80 | 944–1,088 | 1.61–1.67 | 3–4 | 119–151 |
| | 15 min | 191–193 (112–120 / 72–80) | 349–351 | 126–135 / 58–71 / 35–48 | 78–86 | 970–1,052 | 1.73–1.84 | 5–6 | 139–142 |
| | 30 min | 188–192 (112–136 / 56–76) | 350–351 | 127–136 / 69–80 / 50–53 | 76–92 | 1,017–1,112 | 1.84–1.92 | 8–10 | 116–133 |
| | 30–60 min, seed 1 | 191–194 (126–151 / 43–66) | 339–354 | 130–142 / 63–90 / 40–57 | 78–99 | 1,062–1,177 | 1.73–2.01 | 7–13 | 99–135 |
| pack 1 | 30 min | 181–182 (all the spawner's) | 315–319 | 125–143 / 57–68 / 50–58 | 81–83 | 930–959 | 1.59–1.78 | 1 | -- |
| | 30–60 min, seed 1 | 180–184 (all the spawner's) | 317–326 | 116–127 / 63–72 / 52–61 | 78–81 | 857–959 | 1.70–1.76 | 1 | -- |

**At a newborn's composition the water gets more dangerous fast, then rises
and falls with its families.** In five minutes the hunters cruise at 93 to 103
µm/s, against pack 1's 79 (a born cell swims at 56.5), and notice prey from
1,314 to 1,467 µm, against about 1,000. By fifteen their mouths have grown a
tier. By thirty, 87 to 125 of them could swallow a born cell, 71 to 106 one at
r34 and 42 to 64 one at r40, against pack 1's 57 to 60, 25 to 29 and 24 to 27.
On seed 1 the hunters boomed to 158 at twenty minutes and crashed to 91 at
forty-five. The spawner's founders came back in at the floor: the families
went from 3 to 28, and the hunters' mean generation fell from 61 to 44. The
danger moved with them, 57 to 101 hunters able to swallow a cell at r34, and
stayed above pack 1's throughout.

**At a sighted player's composition it hardly changes.** The families feed
about two thirds of the 200 places, and the spawner makes the rest, for the
player, at every census. Those founders keep the families many, 99 to 151, and
the hunters' mean generation at 13 or under in the hour. So the hunters cruise
at 75 to 99 µm/s against pack 1's 78 to 83, and the counts that could swallow
a cell stay about pack 1's, a fifth more at r34.

**The difference is how well a hunter eats.** A newborn's water keeps 4.7
drifters for each hunter and a sighted player's 1.8. There 58 % of the
daughters died, against 50 %, and the families never outbred the floor.

**What the water evolves** where it evolves. No one body: after thirty minutes
a newborn's drop's commonest hunter is 2 of its 97 to 133. On average its
hunters wear the mouth at tier 2.5 to 2.9, `pellicle` at 2.5 to 3.0, `cirrus`
at about 2, a `vacuole` and `crista`, and a sense or two. Half to two thirds
wear a tail, and 39 to 65 % an `axoneme`, nearly all of those at tier 3. That
is a big-mouthed, armoured hunter that eats drifters, newborns and other
hunters, and pays 2.8 to 3.2 times a born cell's upkeep. Pack 1's hunters, at
the same age, wear the mouth at 1.5 and little beside the tail. In full vision
the water fills with a few families, and siblings look alike.

**The server's empty room**, run three hours (seed 1), held 94 to 125
hunters at its half-hourly censuses, against pack 1's 91 to 93. One family held
it for the first hour, 125 strong at its height, cruising at 130 µm/s with
mouths at tier 2.9 and 116 of its hunters able to swallow a cell at r34. It
had crashed by ninety minutes, 19 founders came in, and the water evolved again
from 33 families. Over the three hours its hunters cruised at 91 to 130 µm/s,
against pack 1's 78 to 81, and noticed from 1,340 to 1,574 µm, against 930 to
1,004. The deepest family reached generation 163.

**Hunters do not live better; they live faster.** In those three hours the
room's hunters divided 22,344 times, starved 6,972 times against pack 1's
6,258, were eaten by other hunters 9,078 times against 7,372, and ate 62,915
drifters against 51,098.

### 6.2 The chase

`chase_probe`, `ocean.md` §15.6's method: a born cell (r26) against a hunter its
own size, posed 900 µm off and running at it, 14 seeds. The hunter's mouth is
at tier 3 in every row, so that only how it moves differs:

| hunter | does nothing: caught | turns away: caught | median catch, still / turning |
|---|---|---|---|
| pack 1's typical: `cirrus` 2, `flagellum` 2, `chemocyte` 1 | 12 of 14 | 3 of 14 | 7.8 s / 14.1 s |
| **grown under every division, without an `axoneme`**: `cirrus`, `flagellum`, `ocellus`, `chemocyte`, `pellicle`, `vacuole`, `crista` at 3, `myoneme` 2 | **12 of 14** | **4 of 14** | **5.3 s / 6.9 s** |
| grown under one in four, with an `axoneme`: `cirrus`, `flagellum`, `chemocyte`, `axoneme`, `pellicle`, `vacuole`, `crista` at 3 | 14 of 14 | 14 of 14 | 3.9 s / 3.9 s |

**What decides a chase is the `axoneme`.** Each grown hunter was the commonest
body after an hour of its water: the first under every division with the floor
paid over 5 s, 3 of 119 hunters; the second under one in four, 23 to 73 of a
drop's. The first has a tier-3 tail and a dash but no `axoneme`. A cell that
turns away and commits still escapes it 10 times in 14, so the contract
(`food-and-predators.md` §5.4.1) holds, though the hunter catches sooner. The
second carried an `axoneme` at 3, 189 µm/s, and nothing escaped it. Every
division keeps the water varied, so no one body stands for it. After thirty
minutes 39 to 65 % of a newborn's water's hunters wore an `axoneme`, nearly all
at tier 3, and in the server's room 23 to 58 % over three hours. A newborn will
meet both kinds. Against the fast ones, what keeps it alive is not being
hunted: the grace after each birth, a dart, and staying out of their senses.

**If playing says it is too much**, the mutation rate is not the lever: speed
evolved at every rate measured (§3.3). Two rules are. The grace's length
protects the player, and changing it is a protocol change, since the referee
grants it. `UPKEEP_PER_TIER` (0.18) prices what evolves, and it is the
roadmap's rule that a build strong on every axis should be one that starves.
A newborn's water's hunters live on 2.8 to 3.2 times a born cell's upkeep
after thirty minutes. Both
are the player's numbers as much as the water's, and neither was turned here:
they are for the playtest to turn.

### 6.3 The forage bot

**Measured on the earlier recommendation** (one in four, the room), before the
owner's answers, and not run again for them. The bot is almost never hunted
(below), so what the answers change, the hunters, is what it cannot show.
`forage_probe` is `ocean.md` §8.3's bot: it swims at food through anything,
passes over venom, and answers a division by leaning port. Here it ran in a
drop aged fifteen minutes, seeds 1–16 at 16:9 and at 20:9 (§12):

| the drop | games | starved | eaten | lost (16:9 / 20:9) | hunters ran at it | meals a game | food within 1,400 µm | mouths within 1,400 µm that could swallow it | dread, mean (time above 0.5) |
|---|---|---|---|---|---|---|---|---|---|
| pack 1 | 32 | 10 | 4 | **14** (7 / 7) | in 3 games, 7 runs | 14.0 | 28.0 | 1.02 | 0.230 (17 %) |
| **pack 2, the earlier recommendation** | 32 | 9 | 3 | **12** (6 / 6) | **never** | 15.1 | 27.7 | 0.82 | 0.189 (15 %) |
| pack 2 with nobody's grace, yours included | 32 | 4 | 2 | **6** (3 / 3) | in 3 games, 3 runs | 14.9 | 26.5 | 0.58 | 0.150 (9 %) |

**The bot could not tell that pack 2 from pack 1.** It lost 12 games against
14, with 20 of the 32 ending differently. That is the whole drop played out
differently, which is how `ocean.md` §8.3 says a change to every water cell
reads: chance alone moves a set like this by that much. Nothing ran at it,
because it divides every 37 to 42 s, inside its own 42 s of grace, and in a
drop aged fifteen minutes under one in four the hunters near its size had small
mouths (§3.3). Under every division their mouths are a tier bigger by then
(§6.1). **The bot is not the player pack 2 changes most.** A person who takes
longer over a generation meets what the chase measures (§6.2), and that is the
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
next tick. The frames were shot under the earlier recommendation; a division
is drawn the same at every rate, and only whether a daughter carries a
change differs.

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

**The frame follows the hunters.** Measured as the water alone (`eco_probe`,
p50 µs a frame over each five minutes, seed 1), pack 1 and the owner's rules
were started together and ran side by side, so that both paid the same load.
The machine was shared while they ran, so the ratio is the measure, not the
microseconds (§12):

| the drop, seed 1 | pack 1: median (range) | the owner's rules | the owner's / pack 1 |
|---|---|---|---|
| a newborn's composition, an hour | 1,337 (1,270–1,692) | 1,547 (1,302–1,881) | **1.16** |
| a sighted player's, an hour | 1,739 (1,499–1,974) | 1,920 (1,711–2,181) | **1.10** |
| the server's empty room, three hours | 660 (640–691) | 743 (702–793) | **1.13** |

The five-minute windows follow the hunters. Where the owner's drop stood at
pack 1's count after a crash, its frame was pack 1's, 0.91 to 0.97 of it.
Where a family had boomed 40 to 54 hunters over, it was 1.29 to 1.41 of it. A
sighted player's drop holds its hunters near pack 1's, and pays for its fuller
food (§5).

**What no ceiling costs.** Fitted over the hour at a newborn's composition,
each hunter over pack 1's count cost about 7.5 µs a frame here: about 45 µs on
a phone at `ocean.md`'s assumed factor of six. The most any census held, 158
against 92, is then about 3 ms of a phone's 16.7 ms frame. What one division
adds is one compare a tick for a body at 40 and two spawns; the grace adds one
compare per candidate in a prey search. The rest is the bodies.

**With the player in it**, `ocean.md` §4.4's method: `drive.tscn
--field-cost=3600` at `--radius=30` with a tier-1 nose and `ampulla`, in a drop
aged fifteen minutes, seeds 7, 12345 and 2026, pack 1 and the owner's rules
side by side: p50 1,852 to 2,036 µs a frame, against pack 1's 1,504 to 1,757,
**1.12 to 1.26 times** pack 1's. The cell dies in every run, so 1,349 to 3,196
frames were timed.

**On a phone.** At `ocean.md`'s assumed factor of six, pack 1's drop was
estimated at 7.1 to 8.0 ms of the 16.7 ms frame (§4.4 there), and the owner's
phone held it at 0 % dropped. Scaled by the same ratio, the owner's water is
about 8 to 10 ms: inside the frame, with less to spare. The dev app's frame
readout is where to watch it.

**The record.** Under the earlier recommendation the room held the bodies at
pack 1's count, and its frame was pack 1's: measured one run at a time on an
idle machine, 1,293 to 1,429 µs with the player in it against pack 1's 1,385
to 1,633.

**A phone that hosts a guest is still unmeasured** (§13). Pack 2 adds bodies
to it.

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
  dividing under the earlier recommendation, ran 4,140 simulated seconds with
  no script error. It was not run again under the owner's answers, which change
  the water's numbers and nothing on the wire.
- **Mixed builds play together.** A pack-1 phone and a pack-2 phone share
  PROTOCOL 5 and the same RULES, so neither refuses the other. Whose water
  divides is the host's build's.
- **A guest's sister carries what she wears.** SISTER sends her body and never
  sent her DNA, so a guest's declined daughter comes into the host's drop with
  DNA equal to her body. A host's sister carries her whole DNA. That is the one
  place a newborn's genes are not all passed on, and the next protocol change
  can add her DNA to SISTER (§13).
- **The server's room** keeps lineage the way it keeps everything else (§4),
  and is where generations add up. Empty, its hunters' mean generation was 59
  after an hour, and its deepest line reached generation 163 at ninety
  minutes, as a crash let new founders in (§6.1).
- **The replay** records births as it records any body taking a slot. The
  mother's slot writes radius 0 and two newcomers take slots. The doubled
  nucleus is drawn from the recorded radius. Nothing new is recorded.

---

## 9. Generic mechanics, names at the edges

| file | knows | does not know |
|---|---|---|
| `game/mechanics/descent.gd` **new** | a record of descent, `[id, parent, generation, lineage]`, as static functions on ints: a founder, a child of a record, and the two points a body of radius `r` splits into across an axis, touching | cells, genes, water |
| `game/mechanics/replenish.gd` | `due_for(short, dt) -> int`: the debt on a shortfall the caller has worked out, which `due(living, dt)` becomes the case of. The drop sums each kind's own: the food against its count, the hunters against the floor | what is made |
| `genome.gd` | unchanged: `expressed`, `mutated` and `integrate_into` are the gene edge, called as they are | -- |
| `drop.gd` | this water's numbers and decisions: `SPAWN_SHARE` 1.0 (now the floor: the share of today's hunters the spawner keeps at least), `FLOOR_TAU` 1 s, `hunter_floor(share)` and `food_count(share)`, and `daughter_dna(dna)` → `[faithful, changed, kind]`, which calls the player's `Genome.mutated` every time | how a grid or a debt works |
| `food.gd` | `_divide`, the one place a water body becomes two; meals into the DNA; the grace in the prey search; the spawner's two shortfalls; the sister's DNA | the arithmetic above |

A second water writes its own floor and food in its own environment file;
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
| `game/mechanics/replenish.gd` | `due_for(short, dt)` (2-2) |
| `game/normal/drop.gd` | `SPAWN_SHARE` keeps 1.0 with its new meaning (a floor), `FLOOR_TAU`, `hunter_floor`, `food_count`, `daughter_dna` |
| `game/normal/food.gd` | `Body.dna`, `generation`, `lineage`, `grace`. `_spawn` writes the record and the DNA. `_divide(i, b)`, called from `_step_one` on the body's tick at 40, always, with one daughter mutated every time. `_grow` writes the DNA. `_look_in_drop` and the pond's person loop pass over a body in its grace. `_ecology` pays back each kind's own shortfall, the food over `SPAWN_TAU` and the hunters' floor over `FLOOR_TAU`, and `_make_one` makes a drifter under the food's count, a peer under the floor or for venom, and nothing else. `put_sister` and `place_sister` take a DNA and a record. `drop_state` and `load_drop` gain the optional columns. `take_id()` for the player's cell. A census line for lineage, for the probes |
| `game/normal/normal_mode.gd` | the player's `id`, `parent` and `lineage` at every birth and return, in `player_state` and the cell's save. `_be_born` hands the sister her DNA (`other["tiers"]`) and record |
| `game/normal/drop_save.gd` | the optional columns and `cell` keys, checked when present (§4) |
| `game/vision/vision.gd` | `double` for every water cell in the drop (§6.4) |
| `game/dev/frame_readout.gd` | the `generation` and `families` rows, dev app only (§4) |
| `tools/eco_probe.gd`, `tools/drive.gd` | the lineage census line, and switches for every rule here: `--births=` (off is pack 1), `--mutate=` (a tool's rate; the game has none), `--floor=`, `--floor-tau=`, `--newborn-grace=` |
| `tools/drop_probe.gd` | the checks in §11.3 |
| `tools/net_probe.gd` | `pond-field` with the host's water dividing |

**Nothing** in `addons/launcher/`, `ci/` or `project.godot`.

**No player-facing text.** Pack 2 adds none, so nothing new goes through `tr()`
or into `game/i18n/biogenic.pot`. The readout's two rows are the dev app's,
which is not translated.

### 11.2 Phases and the release

Each phase is one pull request into `dev`, played on the dev app before the next.

| phase | contents | the owner can try |
|---|---|---|
| **2-1** | the record and the second register, with nothing dividing: `descent.gd`, the Body fields, the player's id, the sister's DNA, the save's columns, the lineage census line, drop_probe's save and record checks. A water cell's DNA is still its body (a meal writes both), so the drop's census lines are `dev`'s to the byte | nothing new: it is groundwork, like 1a-1 |
| **2-2** | the water divides: `_divide` at 40 with nothing to wait for, a mutation every division, meals into the DNA, the grace, the spawner's two shortfalls (the food to its count, the hunters to the floor within `FLOOR_TAU`) with `due_for` and venom's floor, the doubled nucleus, the dev readout rows, drop_probe's division checks and net_probe's pond-field | an evolving drop. Play it new and come back to it after fifteen minutes, and after an hour |
| **the release** | | when the owner runs it |

**Releases are the owner's.** The owner, 2026-10-01: *"Don't bother for the
release. I'll run the release skill when everything is ready."* Nothing about
playing together changes, so a release with either phase in it locks nobody
out, and 2-1 alone gives a player nothing. **`binary_version`: no bump.**

### 11.3 Probes, and what CI checks

`drop_probe`'s "Check the drop" step gains, each check failing with its rule
taken out:

1. **A division is the player's**: over five minutes with births, every water
   body that divided was at 40, and every one at 40 divided on its next tick.
   Each made two bodies at `daughter_radius(40)`, touching, with `parent` its
   id, `generation` + 1 and its `lineage`. One daughter's DNA equals the
   mother's, and the other's differs from it by exactly one trade or one
   drift, never a shift. Both keep a `cytostome`.
2. **Expression**: every daughter's body is a subset of her DNA at the same
   copies, the mouth always worn, and a daughter who wears no sense wears one
   at tier 1.
3. **The floor**: after the first minute, the drop's hunters at or above
   90 % of today's count at every census (measured: 94 % at the least), at
   both compositions.
4. **The spawner**: no peer while the hunters are at or over the floor, except
   for venom. Drifters at 85 % of their count or more after five minutes
   (measured: 91 % at the least), **whatever the hunters number**: with a
   hundred hunters posed over the floor, the food is still made. Every gene,
   venom included, carried at every census.
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
| hunters pile up at r40, unable to divide (`ocean.md` §5.5, §16 item 5) | a cell at 40 divides on its next tick; nothing waits |
| the spawner makes every hunter, at the player's size (§6.4 there) | births make them; the spawner keeps the food, and today's count as a floor |
| `SPAWN_SHARE` 1.0 of the whole target, one debt over 5 s | 1.0 of today's hunters as a floor, paid back within a second; the food to its own count over 5 s |
| a water cell's meal grows its body ("goes straight in") | it writes the DNA, as the player's does |
| `FIRST_DELAY` the player's alone (row 16) | every newborn's |
| the sister is a body, her DNA dropped (`put_sister(…, body)`) | she carries her DNA and the player's lineage |
| venom back through the next peer | through the next peer, whatever the count |
| hunters live about a minute and leave nothing behind (§16 item 7) | families up to 66 generations deep after thirty minutes |

---

## 12. To measure again

Every probe is in `tools/`, headless, `--fixed-fps 60`, on the prototype's
switches (in the build they are `drive.gd`'s and `eco_probe`'s, §11.1). **A**
is the answered water: `--births=1 --grace=42 --room=0 --floor=1
--split-targets=1 --hunter-tau=1` for `eco_probe`, with `--newborn-grace=42` in
place of `--grace=42` for `drive.gd`; `--mutate=` is 1 unless given. Without
`--hunter-tau=1` the floor is paid back over the spawner's five seconds (§2.2).
`--room=0` and `--split-targets=1` are the prototype's way of saying no room
and a shortfall for each kind, which the build has always; `--hunter-tau=` is
the build's `--floor-tau=`. The earlier recommendation, §3.3's and §6.3's, is
`--births=1 --mutate=0.25 --grace=42` with the room and a floor of half, the
prototype's defaults. With none of them, it is pack 1, byte for byte.

```
# the drop alone (§6.1): seeds 1-3, --sensed=0.2 and 0.6
godot --headless --path . --fixed-fps 60 -s res://tools/eco_probe.gd -- \
    --seed=S --until=1800 --every=300 --sensed=0.2 A
# an hour: --until=3600; the room: --empty-room --until=10800 --every=1800
# §3.3's record: --births=1 --mutate=0.25|0.5|0.1|1 [--grace=42] [--kinds=trade]

# the cost (§7): each run with a --births=0 twin started beside it
#   the drop alone: seed 1, --until=3600 at both compositions, and the room
#   with the player in it: S = 7, 12345, 2026
godot --headless --path . --fixed-fps 60 res://tools/drive.tscn -- --seed=S --mode=0 --scheme=0 \
    --radius=30 --genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1,ampulla:1 \
    --field-cost=3600 --age=900 A

# the chase (§6.2): S = 1..14, with and without --evade
godot --headless --path . --fixed-fps 60 -s res://tools/chase_probe.gd -- \
    --seed=S --mode=0 --scheme=0 --hunt=900 --chase-for=40 --desert=1500 [--evade] \
    --hunter-genome=cytostome:3,cirrus:2,flagellum:2,chemocyte:1
# every division, no axoneme: --hunter-genome=cytostome:3,cirrus:3,flagellum:3,ocellus:3,chemocyte:3,myoneme:2,pellicle:3,vacuole:3,crista:3
# one in four, an axoneme: --hunter-genome=cytostome:3,cirrus:3,flagellum:3,chemocyte:3,axoneme:3,pellicle:3,vacuole:3,crista:3

# the forage bot (§6.3): S = 1..16, --screen=1280x720 and 1600x720
godot --headless --path . --fixed-fps 60 -s res://tools/forage_probe.gd -- \
    --size=1280x720 --seed=S --mode=0 --scheme=0 --genome=cytostome:1,cirrus:1,flagellum:1 \
    --probe-until=180 --avoid-venom --screen=1280x720 --age=900 [--births=1 --mutate=0.25 --newborn-grace=42]
# without anyone's grace: --births=1 --mutate=0.25 --newborn-grace=0 --first-delay=0

# the frames (§6.4): T = 1.15, 1.45, 2.4; --mode=1 and 0; 1280x720 and 2400x1080
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    --fixed-fps 60 res://tools/shot.tscn -- --scene=res://tools/drive.tscn --out=F.png \
    --wait=T+1.5 --size=1280x720 --seed=7 --scheme=0 --mode=1 --births=1 --mutate=0.25 --newborn-grace=42 \
    --cell=3,200,35,38,cytostome:1+cirrus:1+flagellum:2+ampulla:1+chemocyte:1,150 \
    --release-at=1.0 --grow-posed-at=1.2 --freeze-at=T
# the readout (§6.4): the same, with --age=900 --dev-readout --freeze-at=11.5 and no --cell=
```

`--grow-posed-at=` is the prototype's: it grows the posed bodies to 40 at that
time, because a body posed at 40 divides while it is held and its daughter is
posed again. `--dev-readout`, also the prototype's, poses the run as a dev-app
build so that the readout draws. `--kinds=trade` keeps a water mutation to a
trade. The save's size is a 30-line script: a drop aged 300 s, `var_to_bytes`
of `drop_state()` with and without the columns, and zstd. The cost runs (§7)
ran pack 1 and the owner's rules side by side, started together, because other
work shared the machine and no idle window came (`ocean.md` §15.1's check): the
ratio of a pair is the measure. The earlier recommendation's were one at a time
on an idle machine.

---

## 13. Left open

1. **A phone that hosts a guest** is still unmeasured, as it was after pack 1.
   Pack 2 adds bodies to it now: a newborn's drop held up to 575 living, against
   pack 1's 530 (§5), and the water's frame follows its hunters (§7).
2. **Nothing but survival bounds the hunters** (row 20). In every run here it
   did: three seeds for thirty minutes, an hour on one, and the server's empty
   room for three hours (§2.2, §6.1). A family that booms outeats its food and
   its own daughters and crashes back to the floor. Nothing ran longer than
   three hours, and a server's room runs for days. No ceiling was added, as the
   owner chose. What a runaway would cost is the frame: about 7.5 µs for each
   hunter over pack 1's count here, and 45 µs on a phone (§7). The dev app's
   frame readout is where one would show first.
3. **`FLOOR_TAU` is this spec's reading of "at least as many as today".**
   Paid back over the spawner's five seconds, the floor left a newborn's drop at
   72 to 82 hunters for most of an hour on one seed, against pack 1's 89 to 93
   (§2.2). Within a second it never fell under what pack 1's own spawner held.
   If the owner meant the spawner's own pace, `FLOOR_TAU` 5 s is that.
4. **The bot does not feel the hunting** (§6.3), measured under the earlier
   recommendation and not run again. It divides every 37 to 42 s, inside its
   own 42 s, so it is almost never hunted. A person who takes longer over a
   generation meets the water's speed. That is a playtest's to judge, first.
5. **Where the water evolves, it converges.** At a newborn's composition 3 to
   12 families held the drop after thirty minutes, and a crash lets new
   founders in: on seed 1 a crash at 45 minutes took the families from 3 to 28,
   and 19 held the drop at the hour. At a sighted player's the spawner's third
   keeps founding: 116 to 133 families held it, and it hardly evolved (§6.1).
   If playing says the water is too uniform, a higher floor brings in more
   founders tuned to the player.
6. **A family can lose its tail, and many do.** Expression rolls each organ,
   and a family that carries its `flagellum` at one copy has daughters without
   it. A quarter to over a third of all daughters were born tailless, and after
   thirty minutes 38 to 50 % of a newborn's drop's hunters wore no tail, 12 to
   27 % of a sighted player's. Such a hunter still swims, on the strokes
   every cell has: about 41 µm/s, against a one-copy tail's 56.5, and faster
   with an `axoneme`. It is the player's rule. Watch it. *(Corrected
   2026-10-02: this said such a hunter moved on its `axoneme` or drifted.
   `CellBody.speed_for(0)` is 40.7 µm/s.)*
7. **A guest's sister carries what she wears** (§8), until the protocol next
   moves.
8. **What one generation is.** A water cell divides about 30 s after it was
   born (30 to 32 s on average, born mothers), so a newborn's drop is 43 to 50
   generations deep after thirty minutes, its deepest family 60 to 66. A
   sighted player's is 8 to 10 deep, because its founders keep coming.
   `GROWTH_PER_MEAL` is the dial, and the referee copies it.
9. **One chase body says less than it did** (§6.2). Under every division a
   drop's commonest body is 2 or 3 of its hunters, so the chase was run against
   one with an `axoneme` and one without, and the water holds both.
10. **The abrupt division frame** (§6.4) is the UX designer's.
11. **Built on paper, not in the prototype.** These are new code the build must
    test: the player's id and record; the sister's DNA (the prototype's sister
    still carried her body alone); the save's columns, which were sized but
    never written or loaded; and `net_probe`'s pond-field with births. A host
    and a guest ran 4,140 seconds of a dividing drop without an error (§8), but
    nothing compared the guest's mirror with the host's water.

---

## 14. Owner's calls

Numbered on from `ocean.md`'s rows 1 to 18, which the owner answered on
2026-09-30, so that a row number names one call across both documents: rows
6, 15 and 16 above are `ocean.md`'s. As they were put, and as they were
answered on 2026-10-01.

| # | Question | Options | What it means |
|---|---|---|---|
| 19 | How often is a daughter in the water born changed? | **every division, as yours ✓ answered** · one division in two · one division in four (was recommended) | Each time a water cell divides, one of its two daughters may come out a little different: an organ swapped for another, or a copy moved to another organ. Every division: only half to two thirds of the hunters' places fill, the families that last eat each other, and about twice as many cells as today can swallow you once you are grown. One in two: in between. One in four: every place fills, and mouths stay the size they are today. |
| 20 | How many hunters can the water hold? | as many as today: about 96 in a newborn's water, 200 in a sighted player's; a full-grown cell waits for room (was recommended) · **no limit but food ✓ answered**, with today's count kept as the spawner's floor (§2.2) | As many as today: the number of hunters you meet stays what it is; what changes is how good they are. No limit: good families multiply, measured at two and a half times as many hunters after 30 minutes with half the food, and the phone working 60 % harder and climbing. |
| 21 | Do you see families? | **not in this pack: the dev app counts generations, players see nothing new ✓ answered** · full vision marks your own family: the cell you left when you divided, and her descendants | Not yet: families are kept in the save and can be shown later without changing anything else. Marked: in full vision you would recognise your sister's descendants in the water. It is a screen of its own, for the UX designer. |

**Answered on 2026-10-01.** The owner, verbatim:

> 19: every division. No specific treatment between NPCs and players
>
> 20: evolution and survival rate decides. We only ensure there's at least as many as today to make the drop alive using the spawn threshold
>
> 21: not yet

So row 21 stands as recommended: the record is kept and the dev app counts it,
and players see nothing new. Two rows changed the design:

- **Row 19**: every water division changes one daughter, through the player's
  own `Genome.mutated`, and the water has no rate of its own (§3.3). The one
  difference left is the mutation's kind. A water cell has no slot layout, so
  it takes a trade or a drift, never a shift, until something places its
  organs.
- **Row 20**: no room and no ceiling. A cell at 40 divides on its tick, always
  (§2). The spawner keeps the drifters to their own count whatever the hunters
  number, makes a hunter whenever the hunters are under pack 1's count, and
  makes a venomous one whenever venom is short (§5). "At least as many as
  today" is read as never under today's count for more than a moment, so the
  floor is paid back within a second (§13).

**What rows 19 and 20 did together, in plain words** (§6.1). In a newborn's
water, every hunter is soon born of a family, and the families that last are
the ones that eat each other. After thirty minutes 97 to 133 hunters swim
there, against today's 92 or 93. They cruise at twice a newborn's speed and
notice it from about 1,550 µm, against today's 950. Their mouths have grown: 87
to 125 of them could swallow a born cell, against 57 to 60 today, and 71 to 106
a grown cell at r34, against 25 to 29. A family that booms outeats its food and
its own daughters, and crashes back to the floor, where new founders start
again. In a sighted player's water the spawner still makes a third of the
hunters, for the player, and the water stays close to today's: 188 to 196
hunters, and the counts that could swallow you about today's, a fifth more at
r34. Nothing ran away. The water costs a tenth to a quarter more a frame, and
the cost follows its hunters (§7).

**Every division makes the hunters faster and keener where a newborn swims**
(§6.2). Within fifteen minutes they swim twice as fast as a newborn and notice
it from twice as far as the drop's first hunters did. Whether a newborn they
have noticed gets away depends on the hunter. One without an `axoneme` is
escaped 10 times in 14 by a newborn that turns away; one with an `axoneme` at 3
catches it every time. After thirty minutes, between a third and two thirds of
the hunters in a newborn's water carry one.

**Not asked, because the owner's rules decide them.** Row 16 promised every
newborn the player's grace, and §3.4 is that promise. It has a side the row did
not ask about: the grace is what lets families fill the water, and fuller water
is harder on a player outside their own grace. The bot, which almost never is,
lost 12 games of 32 with it and 6 with nobody's grace (§6.3, under the earlier
recommendation). Taking it away from everyone, the player included, would also
be a protocol change, since the referee grants a guest's body `FIRST_DELAY`.
"All cells follow the same rules" decides that a water cell's meal writes its
DNA, not its body (§3.2), and that a sister is a daughter in full. A division
is not a death, which keeps "a cell dies of hunger or of being eaten" whole.