# Feeding: what a new cell has, and what it can grow into

The owner, 2026-10-03, after the lead's account of how real cells eat:

> "That's interesting. This needs to be integrated. We must think of what the
> starting cell has, and what it could evolve to get"

The account, in short:

- most cells have no mouth, and absorb what is dissolved in the water;
- amoebae engulf with any part of the body;
- ciliates have a mouth, the cytostome: *Paramecium*'s oral groove, often with
  a cell anus, the cytoproct; *Didinium*'s snout, ringed with toxicysts;
- some flagellates have a small cytostome;
- suctorians lose the mouth, and suck their prey through tentacles;
- toxins sit in three places: round the mouth, to hunt; as darts over the
  surface, to defend; as granules under it, which make a cell poisonous to eat.

**A companion to `dna-slots.md`**, which puts the toxin inside and outside the
body. This document answers the owner's sentence: what a new cell is born with,
and what it can grow into. The two share their phases (§8) and one owner's table
(`dna-slots.md` §22.4, rows 11 to 14).

**Status: designed from the code and the existing specs.** Nothing was
prototyped or measured, by the owner's choice: *"Don't measure in prototypes.
I'll playtest."* (2026-10-02). Every number is a starting value with its reason,
arithmetic on the code's own constants, or a measurement an earlier spec holds,
cited where it is used. Balance waits for players. Code references are to `dev`
at `d08b0c3`.

**In one paragraph.**

- **A new cell keeps its mouth.** Everything a newborn meets fits in it. Under
  the game's rules a mouth cannot be earned from none. And every death starts
  the game again from this cell.
- **What it can grow into**: the mouth's own path, first a wider gape and a
  harder bite, then fangs (venom at the front); the skin's path, darts and
  stings on its sides; and the inside's path, poison.
- **One new path: give the mouth up, and the whole skin eats**, as an amoeba's
  does.
- **The water already holds the mouthless majority**: the drifters, which
  absorb. Its hunters walk the same paths as you do.
- **The mouthless start is laid out in full for the owner** (row 11), with what
  it would do to a first life.

---

## 0. What exists today

- **The born cell** (`genome.gd`'s `BORN`) is `cytostome` 1, `cirrus` 1 and
  `flagellum` 1 at r26 (`BASE_RADIUS`): three slots, all full.
  - Five seconds in, a sense from `FIRST_SENSES` comes free, with a bonus slot
    to put it in (`normal_mode.gd`'s `_step_sense_grant`).
  - **Every death is a clean restart as this cell** (`lifecycle.md` §1, item 5).
    Only a division carries the DNA on.
- **The mouth is a bow at the nose** (`Cilia.mouth_touches`), as wide as
  `GAPE_BY_TIER[tier] × r`. The tiers are 0.58, 0.82, 1.05 and 1.40.
  - It swallows a body whose radius is below its gape, and bites one that is
    not, by `BITE_BY_TIER` 0, 0.07, 0.10 and 0.14. Tier 0 is a hard zero
    (`edibility.md` §4).
  - The bow is at the nose whatever slot the gene sits in (`dna-body.md` §12,
    item 1).
- **A newborn's mouth takes everything a newborn meets.** Its gape is 21.3.
  Drifters are r13 to 21 (`DRIFTER_MIN`, `DRIFTER_MAX`), and a floc is r8 to 14:
  *"always in a born cell's mouth"* (`drop.gd`).
- **A body with no `cytostome` lives on the water** (`ocean.md` §5.3, row 11).
  - In the drop it absorbs `ABSORB` 1.0 seconds of rest a second. That is
    exactly the upkeep of a body whose genes are all at tier 1 (`upkeep_of`).
  - Its nose keeps a tier-0 bow of 0.58 r, and it bites nothing.
  - **Measured there**: a born cell without a mouth lasts about 55 s without
    food instead of 30, and is empty at 46.
- **A player loses the mouth only by writing a gene over it.**
  - `_write` changes the DNA only, so the body keeps its mouth for this life.
    Its daughters are born without one.
  - **The mouth does not come back.** A mutation's drift never takes it and
    never brings it (`_mutate_drift`). And a 0.58 r bow takes no peer: round a
    newborn the smallest is r17.2 (`PEER_SPREAD` 0.34).
- **No new organ this life.** A meal writes the DNA, and the body is what was
  rolled at its birth (`lifecycle.md` §1, item 1). The referee holds a guest's
  worn body fixed for a whole life, except for the free sense (`referee.gd`'s
  `judge_person`, `_is_gift`).
- **The water** (`ocean.md`):
  - **Drifters** are 45 % of arrivals. They have no mouth, are carried by the
    water, absorb, never starve, and graze flocs with their tier-0 bow
    (`_grazed_by_drifter`). Each carries one gene, never a venom.
  - **Peers** are the born plan plus whatever the dice give (`Drop.peer_plan()`,
    which reads `BORN`). They eat and take genes as you do (`_grow`), divide, and
    mutate by trade or by drift, neither of which touches the mouth.
- **The skin already has darts.** A `trichocyst` on an arc fires at a hunter
  that comes within `DART_RANGE_BY_TIER` on that arc, and stuns it for
  `DART_STUN` 5 s.
- **The toxin is `dna-slots.md`'s**: venom outside, by direction, and poison
  inside.

---

## 1. Decided, in one place

1. **A new cell is born as today**: a mouth at its nose, a steering tuft, a
   tail, a sense at five seconds, and an empty inside. Row 11 puts the other
   start to the owner, and recommends this one (§3).
2. **The paths are the genes the game already has**, in the places
   `dna-slots.md` gives them. There is one new path: **a body with no mouth eats
   with its whole skin** (§5, row 12, phase 5).
3. **Oral cilia are the cytostome's tiers**, not a gene of their own.
   Tentacles, a mouth on another arc and a feeding current are hooks. The
   cytoproct is dropped (§4.2).
4. **The water walks the same paths** (§6):
   - drifters are the osmotrophs, and from phase 5 they graze with their skin;
   - peers are hunters with a mouth at the nose, and grow everything the player
     can grow except the mouthless path.
5. **Phase 5 is content**: `PROTOCOL` moves, `Wire.RULES` does not, and
   `binary_version` does not (§7).
6. **The release takes phases 1 and 2.** Phases 3, 4 and 5 come after it
   (row 14, §8).

---

## 2. How real cells eat, checked

The lead's account holds. What the sources say, and where each way of eating
goes in the game:

| how | what the source says | in the game |
|---|---|---|
| **absorbing** | The astomes are ciliates that gave the mouth up: *"In one group, the astomes, the mouth and associated structures have been lost altogether"* ([Oligohymenophorea](https://en.wikipedia.org/wiki/Oligohymenophorea)). Amoebae too *"feed by pinocytosis, imbibing dissolved nutrients"* ([Amoeba](https://en.wikipedia.org/wiki/Amoeba)) | `ABSORB`, for every body with no mouth. **Exists** |
| **engulfing** | *"Amoeboid cells do not have a mouth or cytostome, and there is no fixed place on the cell at which phagocytosis normally occurs"* ([Amoeba](https://en.wikipedia.org/wiki/Amoeba)) | the skin of a body with no mouth. **Phase 5** |
| **a mouth** | *"a ventral groove containing the mouth and distinct oral cilia, separate from those of the body"* ([Oligohymenophorea](https://en.wikipedia.org/wiki/Oligohymenophorea)). Each daughter gets a working one at division: *"not only is a new oral apparatus made for the posterior daughter, but the already existing oral apparatus of the parent cell is reorganized ... to provide a functional feeding apparatus for the anterior daughter cell"* ([Introduction to the Phylum Ciliophora](https://www2.gwu.edu/~darwin/Ciliates/Introduction%20to%20ciliates/Intro.html)) | `cytostome`, which a new cell is born with. **Exists** |
| **tentacles** | Suctorians *"become sessile in their developed stage and then lose their redundant cilia"*. They feed through tentacles with *"toxic extrusomes called haptocysts at the tip"*, and *"suck the prey's cytoplasm directly into a food vacuole"*. Their swarmers *"lack both tentacles and stalks"* ([Suctoria](https://en.wikipedia.org/wiki/Suctoria)) | a hook (§4.2) |
| **a cell anus** | *"The anal pore is located on the ventral surface, usually in the posterior half of the cell"* ([Anal pore](https://en.wikipedia.org/wiki/Anal_pore)) | dropped (§4.2) |
| **a young cell with no mouth** | In folliculinids *"the anterior cell part (proter) becomes a non-feeding motile swarmer"* (Mulisch and Patterson, [Eur. J. Protistol. 1988](https://pubmed.ncbi.nlm.nih.gov/23195095/)) | why a mouthless newborn is not the real picture either (§3.1) |

And the toxin's three places:

| where | what the source says | in the game |
|---|---|---|
| **round the mouth** | toxicysts *"tend to be localized around the mouth"* ([Britannica](https://www.britannica.com/science/toxicyst)) | venom at the front (`dna-slots.md` §2.3). **Phase 1** |
| **darts over the surface** | *Paramecium* that cannot fire its trichocysts: *"Cells of tnd mutants were eaten 9–45 times faster than wild-type cells by the predator"*, *Dileptus* (Harumoto and Miyake, [J. Exp. Zool. 1991](https://onlinelibrary.wiley.com/doi/abs/10.1002/jez.1402600111)) | `trichocyst`, on its arc. **Exists** |
| **granules under the surface** | cortical granules discharge where a predator touches (*Climacostomum*, [Predator-Prey Interactions in Ciliated Protists](https://www.intechopen.com/chapters/62301)), and toxic cells harm what eats them | venom on a side or the stern stings what bites there; poison inside doses whatever bites or eats you (`dna-slots.md` §2.3, §7). **Phase 1** |

---

## 3. The starting cell

### 3.1 Born with its mouth (row 11, recommended)

**A new cell keeps today's kit**: `cytostome` 1, `cirrus` 1, `flagellum` 1, a
sense at five seconds, and the empty inside `dna-slots.md` gives every cell.
Six reasons, the first two of which settle it:

1. **Everything a newborn meets fits its mouth.** A gape of 21.3 takes every
   drifter (r13 to 21) and every floc (r8 to 14). So a newborn's first lesson
   has no exception: anything with no green at its nose (`genes-and-cilia.md`'s
   read for *cannot eat anything*) is food it can swallow. A skin of 0.58 r, the
   mouthless gape, takes 15.1 at r26: every
   floc, and about **a quarter of the drifters** (26 % of radii drawn evenly
   from 13 to 21, fewer counting those a `pellicle` makes bigger to a mouth).
   Three bodies in four that a mouthless newborn touched would be food it could
   not eat.
2. **A mouth cannot be earned from none.** A gene comes from what you eat
   (`dominant_of`).
   - Nothing a mouthless newborn can take carries a mouth: drifters never do,
     and a peer round a newborn is r17.2 at the smallest.
   - Drift never brings the mouth.

   So a mouthless start's mouth would have to be handed over. It would not
   evolve, and evolving it was the point.
3. **No new organ this life.** A mouth cannot grow on the body mid-life without
   a second exception in the referee, beside the free sense. So the earliest a
   mouthless start could give one is its first division.
4. **Every death replays the start** (`lifecycle.md` §1). A weaker first
   generation is paid on every life, not once.
5. **Most of what a mouthless start buys is a softer first meal**: about 55 s
   without food instead of 30 (`ocean.md` §5.3). That is balance by another
   name.
   - The 30 s was the owner's answer to `energy.md` §7.6, row 1.
   - `hunger.md`'s alarm, which makes starving impossible to miss, was built on
     2026-10-03 and wants playing first.
6. **The biology agrees.** A ciliate daughter is born with a working mouth: it
   is rebuilt during the division (§2). The real mouthless young are swarmers
   that do not feed at all.

**What this work does for the first minutes** is to leave them alone, where
that matters:

- drifters carry no toxin, so a newborn's food is never poisonous
  (`dna-slots.md` §9);
- `FIRST_DELAY`'s 42 s and the quiet start (`ocean.md` §8.1) are untouched.

The first meal stays where the earlier specs measured it: a median of 9.6 s in
a new drop and 11.0 s in an aged one, for the full-vision bot (`ocean.md` §8.3).

### 3.2 What the other start would do to a first life

**The other start**: a new cell is born without a mouth. Its skin eats (§5), the
water feeds it, and **its daughters are born with a mouth**, because its DNA
carries one and a mouth always expresses (`ALWAYS_EXPRESSED`).

Said plainly, for a first life:

- **It lasts about 55 s without food instead of 30**, empty at 46 (`ocean.md`
  §5.3, measured for a born cell without a mouth). The arithmetic is the same
  here: every gene at tier 1, so its upkeep is 1.0, which `ABSORB` pays.
- **It eats anything small enough that touches it, from any side**: no aiming.
- **Small enough is 0.58 of its radius.** As it grows, more of the drifters fit:

  | meal | its radius | its skin takes | drifters that fit |
  |---|---|---|---|
  | the first | 26 | 15.1 | about 26 % |
  | the second | 30 | 17.4 | about 55 % |
  | the third | 34 | 19.7 | about 84 % |
  | the fourth | 38 | 22.0 | all |

  Every floc fits from the start. A peer does not, at first.
- **It cannot bite.** It cannot take a bigger body apart, or answer a hunter
  once the 42 s grace is over. It can only leave.
- **It divides after four living meals, as today.** A floc feeds it and does
  not grow it (row 6), so the four come from the drifters it can take.
- **The first drifter must be drawn small.** The run's promised first meal is
  placed 1,000 µm along the cell's first motion (`food.gd`'s `_arrive`), and a
  drifter over 15.1 would be one it cannot eat. That is a correctness fix, not
  balance.
- **The mouthless generation is every life's first.** Every death goes back to
  it, and every daughter after it hunts with a mouth.
- **Unmeasured**: how long that first generation lasts, and how often it starves
  or is eaten before it divides.

### 3.3 What the other start would take to build

Only if row 11 goes that way. It needs phase 5 first, and lands as phase 5b.

- **`genome.gd`**: `BORN` stays the born DNA. A new `BORN_BODY := {&"cirrus": 1,
  &"flagellum": 1}` is the born body, and `_ready()` and `reset()` express `BORN`
  wearing `BORN_BODY`. The strand shows the mouth carried and not worn, with
  `HINT_CERTAIN`, *"a daughter always wears it"*.
- **`drop.gd`**: `peer_plan()` stops reading `BORN`. `PEER_PLAN := [&"cytostome",
  &"cirrus", &"flagellum"]`, so the water's peers keep their mouths.
- **`food.gd`**:
  - the first drifter is drawn below the born body's skin:
    `randf_range(DRIFTER_MIN, born_gape - 0.05)`, with `born_gape` from
    `BORN_BODY`;
  - `_food_for_born` reads the born body's gape instead of `gape_of(1, …)`.
- **`normal_mode.gd`**: `_pond.enter(BASE_RADIUS, …)` says the born body and its
  worn order, with the mouth's slot empty. `_order_fits` would foul an order
  naming a gene the body does not wear.
- **The gift is unchanged.** The DNA's layout still has no empty slot, so the
  free sense still comes with its bonus slot, and never lands on the mouth's
  seat.
- **`soma.gd` and `vision.gd`** draw `BORN_BODY` where they fall back to `BORN`
  for a cell with no genome yet.
- **The wire and the referee**: `net_probe`'s `_rules_text` fingerprints
  `genome.BORN`, and adds `BORN_BODY`, so `Wire.RULES` moves, and with it
  `PROTOCOL`. It shares phase 5's bump if the two land together. The referee
  takes any body at a birth, so `judge_person` needs nothing. *(2026-10-10:
  since protocol 8 the handshake carries the rules' fingerprint, so this moves
  `Wire.RULES`' pin alone and no `PROTOCOL` -- see the note at the head of §7.)*
- **Saves.** A life saved under the old start keeps its mouth, and the next
  life starts without one. `DropSave.rules()` does not hash `BORN`, so kept
  drops and the server's room load as they are. The library is untouched.
- **Content**: no `binary_version` bump.

### 3.4 Starts weighed and dropped

- **An osmotroph that eats nothing.** The water would pay its upkeep, but growth
  comes only from living meals, four units each. It could never divide.
- **A mouth that grows at the first meal.** This one is tempting, because the
  mouthless stage would cover exactly the hardest moment and end in a felt
  beat. Two things stop it:
  - it is a new organ mid-life, which needs the referee to allow a second
    change beside the free sense;
  - the first meal already brings the flood, the growth, a gene and a new slot
    at once.
- **A mouth earned by eating.** Nothing a mouthless newborn can take carries one.
  Making something carry one is a retune: a wider skin, or small hunters in the
  water.
- **A naked skin for every cell**: every cell engulfs small things anywhere until
  it grows a `pellicle`, a ciliate's rigid cortex. It would make point of view's
  first minutes kinder. But it takes the aim out of eating small things for
  every cell, peers included, so it is a balance lever more than a path.

---

## 4. What a cell can grow into

### 4.1 The paths

```
born: a mouth at the nose · a steering tuft · a tail · a sense at 5 s · an empty inside
│
├─ the mouth grows          cytostome 2, 3: a wider gape, a harder bite        exists
├─ the mouth is armed       the toxin at the front: venom on every bite        phase 1
├─ the skin is armed        a trichocyst on an arc: darts at a hunter there    exists
│                           the toxin on a side or the stern: stings a biter   phase 1
├─ the inside is poisoned   the toxin inside: what bites or eats you is dosed  phase 1
├─ the toxin's kind         corrosive · paralysing · sleeping, from your food  phases 1, 3, 4
└─ the mouth given up       a gene written over it: the skin eats              phase 5
```

| path | the real thing | gene | place | what it does | status |
|---|---|---|---|---|---|
| a wider mouth | the oral apparatus and its cilia | `cytostome` 2, 3 | the nose | gape 1.05 r and 1.40 r; bite 0.10 and 0.14 | exists |
| fangs | toxicysts round *Didinium*'s and *Dileptus*'s mouths | the toxin (`toxicyst`) | outside, the front (slots 0, 3, 4) | your bite leaves stacks in what it bit | phase 1 |
| darts | *Paramecium*'s trichocysts | `trichocyst` | outside, any arc | a dart at a hunter on that arc stuns it | exists |
| stings | toxic granules fired where a predator touches | the toxin (`toxicyst`) | outside, a side or the stern | a mouth biting you on that side takes stacks | phase 1 |
| poison | toxic contents | the toxin (`veneneux`) | inside | a mouth biting you anywhere, or swallowing you, takes stacks | phase 1 |
| the kind | the toxin families | the strain | inherited with the gene | harm; paralysis; sleep | phases 1, 3, 4 |
| a skin that eats | an amoeba's phagocytosis | none: no `cytostome` | the whole skin | what fits 0.58 r and touches you is eaten; the water feeds you | phase 5 |

**What makes them a tree and not a list** is the slots. A cell has seven arcs
and one inside, so every path costs another:

- fangs take a front arc a sense would want;
- stings take a rear arc a dart would want;
- giving the mouth up frees the nose for a sense or a fang that no longer has a
  bite to ride on.

### 4.2 What is not in this pack, and why

- **Oral cilia are the cytostome's tiers.** A real mouth's cilia sweep food in,
  and the game's wider gape is that. `cilia.gd` already draws the cytostome as a
  mat of cilia round the mouth (`_gather_cytostome`). A gene of its own would be
  a second way to buy a gape.
- **A mouth on another arc** (a hook). *Paramecium*'s oral groove is on its side.
  It would make the cytostome directional, like the beam: contacts, the bow,
  every hunter's aim and the instincts' *toward* would all have to follow the
  mouth's bearing. It starts at `dna-body.md` §12, item 1, and at
  `Cilia.mouth_touches` taking a bearing.
- **Tentacles** (a hook). A suctorian feeds through toxic tentacles, and gives up
  swimming to do it. In the game that is a gene that feeds on whatever touches
  its arc: a bite from an arc, with a dose, by a cell that waits instead of
  hunting. The side sting's geometry (`dna-slots.md` §2.3) is the contact it
  would need.
- **A feeding current** (a hook). Oral cilia that draw small food in from a
  distance would be a pull on flocs and drifters towards the mouth.
- **The cytoproct is dropped.** Where a cell puts its waste is nothing a player
  would feel.

---

## 5. A skin that eats (phase 5)

### 5.1 The rule

**A body with no mouth eats with its whole skin.** Whatever fits its tier-0
gape (0.58 r) and touches its skin anywhere is engulfed, and it is a meal as a
mouth's would be. The skin still bites nothing. A body with a mouth eats only
through the mouth.

```gdscript
# cell.gd
## **A body with no mouth eats with its whole skin** (feeding.md §5): what fits
## its tier-0 gape and touches it anywhere is engulfed, as an amoeba's
## pseudopods do. A cytostome ends it: a body with a mouth eats only through it.
static func engulfs(cytostome_tier: int) -> bool:
	return cytostome_tier <= 0
```

```gdscript
# cilia.gd, beside mouth_touches
## **Is that body against this skin**: measured on the circle the water already
## keeps bodies apart by, with the bow's own slack, so a touch at the skin is
## what a touch at the mouth is.
static func skin_touches(at: Vector2, r: float, gape: float, body: Vector2,
		body_radius: float) -> bool:
	var reach := r + body_radius + gape * MOUTH_BITE
	return at.distance_squared_to(body) <= reach * reach

## **Is that body where this one takes food in**: its mouth's bow or, for a
## body that engulfs, its whole skin. Every eating test in the water asks this.
static func takes_in(at: Vector2, heading: float, r: float, gape: float,
		skin: bool, body: Vector2, body_radius: float) -> bool:
	if skin:
		return skin_touches(at, r, gape, body, body_radius)
	return mouth_touches(at, heading, r, gape, body, body_radius)
```

**Why the circle.** Bodies are solid. `_separate_drop` pushes two bodies out to
the sum of their radii, so two bodies that meet sit at exactly that distance. The
bow's slack (`MOUTH_BITE` 0.22 of the gape) makes that contact count.

**Why the tier-0 gape.** It is the size today's mouthless body already takes, at
its nose. The skin takes the same bodies, from every side. So the rule needs no
new number.

### 5.2 What it changes, body by body

- **You, and a friend in a pond.** `_contacts_with`'s `my_mouth` is asked twice,
  once of a floc and once of a body, and both become `takes_in`. The host decides
  a guest's contacts, as it does today.
- **A drifter.** `_grazed_by_drifter` asks `_mouth_reaches`, which becomes
  `takes_in`. A drifter grazes a floc that touches any side of it, not only its
  nose. It is fed and does not grow (`FLOC_GROWTH` 0). How many more flocs go
  is unmeasured; the census's floc count shows it.
- **A drifter touching you.** `its_mouth` becomes true, and nothing follows.
  - No drifter can swallow you: its skin takes 0.58 × 21 = 12.2 at most, and you
    are r26 at the least.
  - Tier 0 bites nothing, so no venom of yours stings it either. A sting answers
    a bite that lands (`dna-slots.md` §7.1).
- **Peers** always have a mouth, since drift never takes it. Unchanged.
- **Nobody engulfs a player.** The widest skin is 0.58 × 40 = 23.2, and a player
  is r26 at birth and r28.3 as a daughter.
- **A swallow is a swallow.** An engulfed body's poison doses what engulfed it
  (`dna-slots.md` §7.1).
- **A mouthless swimmer**, your daughter's line left as a sister in a pond or
  the server's room, swims, decides and absorbs as she does today, and her skin
  eats. The host already knows she is no drifter (`_spawn`'s
  `b.drifter = tiers.is_empty()`). A guest's mirror decides that from the mouth
  instead (`_mirror_refresh`). So **POND body flags gain bit 6, `CARRIED`**, and
  the mirror takes it.
- **The broad phase needs no change.** At tier 0 the bow reaches 1.99 r
  (`mouth_reach`: 1.18 × 1.05 r for the seat, plus 0.58 r × 1.30), and the skin
  reaches r. Every pre-check stays an upper bound, and a check pins it.

### 5.3 For good, nearly

**Write a gene over your mouth, and your daughters are born without one.** Your
own body keeps its mouth until you divide: `_write` changes the DNA only. Drift
never brings the mouth back.

**The way back is to engulf a hunter whose strongest gene is its mouth**, which
breaks ties in its favour (`dominant_of`, in `GENE_ORDER`'s order). A skin takes
r17.2, the smallest peer the water makes round a newborn, only past r29.6. And
it takes only the small hunters still about from earlier. It is rare.

**A death gives the mouth back**: a new cell is born with one.

### 5.4 Why now, and why it is a way to play

- **The toxin pass makes it a build.** A mouthless cell with poison inside,
  venom on its flanks and stern, darts and a pellicle costs anything that bites
  it. It lives on what touches it and on the water.
- **Without the skin, losing the mouth is the trap `ocean.md` §5.3 called *"a
  real and interesting mistake"***: a body that eats only what its nose's 0.58 r
  bow meets.
- **It is what the drop's commonest cell really does.** The drifters are
  osmotrophs, and a skin is how one eats.
- **It is the owner's call** (row 12): it adds a way to live, which changes what
  the game is.

### 5.5 What a player must see

In broad strokes. How it looks is the ux-designer's.

1. **Your skin eats.** In full vision, a cell without a mouth must not look like
   a drifter that cannot eat. *"No green at the nose"* means *this cannot eat
   anything* (`genes-and-cilia.md`, the drifters). The faint tier-0 bow at the
   nose goes, because the nose is no longer where you eat.
2. **An engulf**, in both views. In full vision, a small body is taken at a
   bearing. In point of view, the meal's flood (`ingest`) comes from that side,
   and a touch that eats must differ from a bump that does not, because the body
   was too big.
3. **What fits.** A mouth's bow shows its width. A skin needs its own way to
   show which bodies are small enough.
4. **Writing over your mouth.** Before the second tap, the line says what goes
   and what comes. It is today's `ACT_COMMIT_OVER` (*"tap again to write %s over
   %s"*), given its own words for the mouth: the mouth's daughters lose it, and
   their skin will eat.
5. **The gene screen without a mouth**: the figure's nose and the strand say
   that the skin engulfs (row 13's word), where `eat` and the mouth's line
   were.
6. **The replay** draws a mouthless body as the views do. An engulf is a meal, and
   is recorded as one: nothing new to keep.

### 5.6 Starting values

**None new.** The skin takes `GAPE_BY_TIER[0]` 0.58 and the bow's slack. If it
plays wrong:

- the levers are `GAPE_BY_TIER[0]` and `ABSORB`;
- `wire.gd` names `GAPE_BY_TIER` with the bite tables, so moving it is a
  `PROTOCOL` bump. *(2026-10-10: no longer, since protocol 8: the gape is a
  contact table in the rules the handshake carries, so moving it moves
  `Wire.RULES`' pin alone -- see the note at the head of §7.)*

### 5.7 Cost

The skin's test is one distance against the bow's eight segments, so every
tier-0 test gets cheaper. The only bodies that run it are drifters grazing flocs
and a mouthless player. This is reasoned from the code, not measured: the dev
app's frame readout, row `water`, shows it on a phone.

---

## 6. The water on the same paths

| body | the real picture | how it eats | its paths |
|---|---|---|---|
| **drifter** | an osmotroph; from phase 5, an amoeba | absorbs, and its skin takes flocs | none. One gene, no mouth and no toxin (`dna-slots.md` §9). It never divides |
| **peer** | a ciliate that hunts | its mouth at the nose | **The mouth grows**: it eats a peer whose strongest gene is the mouth. **The toxin**: weight 2, its place by a coin, its strain by a die from phase 3 (`dna-slots.md` §9). **Darts**: from the drifters that carry them. It never gives up its mouth, because drift never takes it |
| **a mouthless sister** | your lineage, in the water | absorbs; from phase 5 her skin eats | her daughters keep her DNA, so the line stays mouthless |
| **you** | — | — | all of them |

**What the water does not have.** An amoeba that hunts, or a suctorian. Each
would be a new kind of arrival, which is `ocean.md`'s spawner's to make and the
water's own design, not this pack's.

---

## 7. Saves, the pond, the referee and the wire

> **Since gene-catalogue.md phase 4 (protocol 8, 2026-10-05)** the handshake carries
> the rules a host judges and decides contacts by (`game/net/rules.gd`), so a change to
> them moves `Wire.RULES`' pin and keeps older builds apart by itself. `PROTOCOL` moves
> only when a message's format does: a new byte, bit or message. Read the bumps planned
> here that way: one planned only for a judged or contact rule is the pin alone; a new
> contact rule is a sample line in `rules.gd` and in `net_probe`'s `_rules_text`; and a
> format change takes the next free number, 9 at the time of writing.

**Phase 5:**

| what | change |
|---|---|
| saves | **none.** A body with no mouth is a state saves already hold |
| kept drops and the server's room | **none to convert.** `DropSave.rules()` hashes the tables, not the contact rule. A drop's drifters graze by skin from their next frame |
| the library | none |
| the replay | nothing new to record |
| `PROTOCOL` | **+1.** The host decides every contact, its guests' included, so mixed builds would play a mouthless guest by two rules. That is `wire.gd`'s own reasoning for the bite tables. The POND body flag `CARRIED` (bit 6) is a second reason |
| `Wire.RULES` | **unchanged.** The referee judges no contact rule: a meal is the host's to tell, growth per meal and its cap do not move, and no cause or contact is added. `net_probe --referee-only` passes as it is |
| the dedicated server | updates last. Until it restarts, phones on the new protocol and the server on the old one refuse each other at the handshake, with the version sentence |
| `binary_version` | **no bump.** GDScript and words only |

**The other start** (only if row 11 says so): `Wire.RULES` and `PROTOCOL` move
(§3.3). Both share phase 5's bump if they land together.

---

## 8. Phases and the release

The table's `PROTOCOL` column predates protocol 8: see the note at the head of §7.

Shared with `dna-slots.md` §20.2. Each phase is one pull request into `dev`, and
is played on the dev app before the next one begins.

| phase | what | when | `PROTOCOL` | `Wire.RULES` |
|---|---|---|---|---|
| **1** | venom and poison, outside and inside | **before the release** | 6 → 7 | unchanged |
| **2** | their screen | **before the release** | unchanged | unchanged |
| **3** | paralysing toxins | after it (row 8) | +1 | moves |
| **4** | sleeping toxins | after it (row 8) | +1 | moves |
| **5** | a skin that eats | after it (row 14), if row 12 says yes | +1 | unchanged |
| **5b** | the mouthless start | after phase 5, only if row 11 says so | with 5's, or +1 | moves |

**Honestly split.** Phases 1 and 2 are the polish the release waits for, because
row 8 put venom and poison in it. **Nothing in this document is polish.** The
skin is a new way to play, and the other start would change every first minute.
Both belong to a later pack. Phases 3, 4 and 5 do not depend on each other, and
can land in any order.

**What phase 1 lets the owner feel, soon** (`dna-slots.md` §20.2):

- eat a poisonous cell;
- put the toxin inside, and let a hunter chew you and weaken;
- move it to your front, bite something big, and watch it go on tearing after
  you let go;
- put it on your stern and turn your back on a chewer;
- swallow a poisonous cell and pay for it.

**What phase 5 lets the owner feel**:

- write a gene over your mouth, and divide;
- your daughter eats what touches her, from any side, and the water feeds her;
- give her poison inside and stings on her flanks, and watch what bites her pay for it.

---

## 9. Build plan

### 9.1 Phase 5: files

| file | change |
|---|---|
| `game/normal/cell.gd` | `engulfs()`; the note on `GAPE_BY_TIER`'s index 0 says the skin |
| `game/vision/cilia.gd` | `skin_touches()` and `takes_in()`; the ux-designer's look for a skin that eats, and no tier-0 bow at the nose |
| `game/normal/food.gd` | `_mouth_reaches`, and `_contacts_with`'s two `my_mouth` tests, through `takes_in`; `var engulf := true`, the switch, in the style of `absorb`; `FLAG_CARRIED` written, and taken by `apply_pond` in place of `_mirror_refresh`'s guess; a `player_engulfed` stat for a meal taken off the nose's arc |
| `game/normal/normal_mode.gd` | the line for writing over the mouth; the flood's bearing for a meal taken by the skin; the figure's and the strand's words without a mouth |
| `game/vision/vision.gd`, `game/perception/soma.gd`, `game/replay/*` | the ux-designer's look |
| `game/net/wire.gd` | `PROTOCOL` +1, with a paragraph in the style of the others; `POND_CARRIED := 1 << 6` |
| `tools/drive.gd` | `--engulf=0\|1`; `--food-at=<units>[,<bearing>]`, so a frame can pose food at the stern; `--food-radius=<r>`, field cell 1's radius as a drifter (`--prey-radius=` makes it a peer) |
| `game/i18n/biogenic.pot`, `fr.po` | the words (row 13) |
| `tools/drop_probe.gd`, `levels_probe.gd`, `net_probe.gd` | §9.2 |

**Nothing** in `addons/launcher/` or `ci/`. **No `project.godot` change.**

### 9.2 Phase 5: what the build checks

Each check must fail with its rule taken out.

1. **A skin takes from every side** (headless, `Cilia` alone). A floc posed
   against the skin at 0°, 90°, 180° and 270° is taken each time. One unit
   farther, nothing is taken. A body at 0.58 r or wider is never taken.
2. **A mouth takes only at the nose.** The same poses, with `skin` false, take
   only the one at 0°.
3. **The broad phase stays an upper bound.** For every r from 13 to 40, the
   skin's reach is within `mouth_reach(r, gape_of(0, r))`.
4. **Nobody engulfs a player.** `gape_of(0, DIVIDE_RADIUS) < BASE_RADIUS`, from
   the constants. And a drifter posed against a player's flank (`drop_probe`):
   no contact told, no wound, no dose.
5. **A mouthless player eats from its sides** (`drop_probe`):
   `--genome=palp:1:0,cirrus:1:1,flagellum:1:2 --seed=7`, three minutes.
   `player_engulfed` is above zero and the cell grows. The same run with
   `--engulf=0` has `player_engulfed` at zero.
6. **A drifter grazes by its skin.** A floc posed at a drifter's stern is grazed
   with the rule, and not without it.
7. **The mirror's drifters are the host's** (`net_probe`). A mouthless sister
   posed by the host (`--sister-genome=palp:1,cirrus:1,flagellum:1`) is
   `drifter` false on the guest's mirror, and a drifter is `drifter` true.
8. **The wire** (`net_probe`): `PROTOCOL` moved, `POND_CARRIED` agrees with
   `FLAG_CARRIED`, and `Wire.RULES` recomputes unchanged.
9. **Before any frame**, a `--seed=` frame rendered three times gives 0
   differing pixels (`CLAUDE.md`).

### 9.3 Phase 5: frames

`E = --genome=palp:1:0,cirrus:1:1,flagellum:1:2 --radius=30 --seed=7`, at 1280x720
and at 2400x1080, both views:

| frame | pose | what it shows |
|---|---|---|
| `E01` | `E --food-at=50,180 --food-radius=14` | a small drifter just off your stern, about to be taken |
| `E02` | `E --flocs-near=6` | flocs round a mouthless cell: what fits, and where it eats |
| `E03` | `E --food-at=50,180 --food-radius=14 --mode=0` | point of view: the meal from behind |
| `E04` | `B`, its waiting `ocellus` armed over slot 0 | the line before you write over your mouth |
| `E05` | a replay after a death with `E` | the mouthless body in the replay |

`B` is `dna-body.md`'s born-cell base.

### 9.4 Phase 5: what it replaces

- the tier-0 bow at the nose, as a mouth and as a drawing;
- `_grazed_by_drifter`'s bow test;
- `_mirror_refresh`'s `drifter = cytostome == 0`;
- `ocean.md` §5.3's *"can still swallow what fits a gape of 0.58 r"*: it now
  engulfs what fits, from any side;
- `genome.gd`'s `place()` note that a gene written over the mouth makes you *"fall
  to gape 0.58r"*. The body keeps its mouth until it divides, as `_write`
  already does.

### 9.5 Phase 5b, if row 11 asks for it

Files are those of §3.3. Its checks:

1. A born cell wears no mouth, carries one, and absorbs.
2. The first drifter always fits its skin, over 64 seeds.
3. Every peer the water makes has a mouth (`drop_probe`'s census, `worn`).
4. Both daughters of the first division wear a mouth.
5. A guest born mouthless is judged clean by the referee, and so is its gift
   (`net_probe`).
6. `Wire.RULES` moved, and `PROTOCOL` with it.

---

## 10. Owner's calls

The rows are in `dna-slots.md` §22.4, numbered on from row 10:

- **11**, the starting cell;
- **12**, the skin that eats;
- **13**, its word;
- **14**, the release.

The nuance:

- **Row 11's second option needs row 12's first.** A mouthless start eats with
  its skin.
- **Row 13 matters only if row 12 is yes.**
- **The balance under row 11 is not asked.** The 55 s, the quarter of the
  drifters and the four meals are what the other start would do as the code
  stands, said so the owner can choose what the game is. They are not numbers to
  tune.
- **Tentacles and a mouth on another arc are not put.** They are hooks (§4.2),
  each one a later pack's design.

**Answered 2026-10-03: the recommended option in every row** (`dna-slots.md`
§22.4). A new cell is born with its mouth, as today (row 11), so §3.3's phase
5b is not built. A mouthless cell will eat with its skin (row 12), after the
release. That eating is called *engulf* (*englober*, row 13). The release waits
for venom and poison and their screen, and this file's phase 5 follows it
(row 14).

---

## 11. What to watch in the playtest

**The start, as it is:**

- whether a new life's first minute feels like the beginning of something you
  will grow, now that the pause screen shows paths you can take;
- whether dying of hunger in the first 30 s still happens without warning
  (`hunger.md`), since the other start would mostly answer that.

**Phase 5, the skin:**

- whether giving up your mouth ever feels worth doing, and whether the line
  before the second tap told you what you were giving up;
- whether a meal taken by your skin reads in point of view, where you cannot
  see it coming;
- whether a mouthless, poisonous cell feels safe, or only slow;
- on the census, whether drifters grazing by skin empty the drop of flocs.

**If the other start is chosen:**

- whether the first generation feels like a gentle opening or a slow one;
- how often it dies before its first division;
- whether bumping into drifters too big to eat reads as the water's rule or as a
  bug.

**On a phone:** the frame readout's `water` row, with drifters grazing by skin.
