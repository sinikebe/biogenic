# The margin: a nursery at the drop's edge, and lineages that stay big

The owner, 2026-10-17:

> Now, we'll add a kind of spawn zone. It's a zone where conditions to develop are
> optimal. But we need to find an organic way to make strong enough cells forced to
> go outside. [...] No invisible walls.

and, on the first answer:

> My only objection is about size. Since the size is a cycle and not linear, there
> might still be OP creatures at the edges. Maybe the minimal size of a cell should
> be dictated by the number of slot it has, or equipped genes? This way, an apex
> predator dividing will stay bigger than newborns

The decisions, all as recommended ("Agree on both"):

| # | Question | Answer |
|---|---|---|
| 1 | What keeps strong cells out and pushes growing cells out? | **The margin**: a thin water film at the drop's edge |
| 2 | Why is the margin the best place to grow? | **Food drifts to the edge, and the light is full there** |
| 3 | Where do runs begin? | **In the margin**, for you and for new cells arriving in the water |
| 4 | Should the margin's own cells carry only common genes? | **No**: size is the filter |
| 5 | What sets a newborn's size? | **The genes its DNA carries** |
| 6 | Can bodies grow past r40? | **Yes, up to about r57** |

Two phases, each its own pull request into `dev`:

1. **The size floor** (§1). Status: **built**.
2. **The margin** (§2). Status: to build, after phase 1.

---

## 0. In one place

1. **A cell is never born smaller than the room its genes need.** The slot ladder
   read backwards. Four genes outside need r26, as a newborn carries them: the three
   of its body plan, and the gift's sense in the slot the gift brings. Five need
   r29.5, six r33, seven r36.5. Two inside need r33, three r40.
2. **A mother divides when each half has that room.** At r40, as today, for a light
   lineage; at up to r56.6 for one that fills its inside. A daughter is still exactly
   half her mother's area.
3. **So a strong lineage stays big.** Its daughters are born at r36.5 to r40 and never
   fit in the margin. A simple lineage's daughters are born at r28.3, as today.
4. **The margin** is the thin film of water at the drop's edge, where a cell can only
   go as far as the water is deep enough for its size. It is where food drifts and
   the light is full, and where runs begin.

---

## 1. Size follows what a lineage carries

### 1.1 The rule

Real cells keep this rule: across protists, the more DNA a cell carries, the bigger
it is, because genome size and cell size go together (the nucleotypic effect). Here a
gene is DNA a cell holds and an organ it may grow, so **a cell is never smaller than
what it carries**.

- **The floor** (`cell.gd`'s `floor_radius(dna)`): the least radius whose slots hold
  every gene the DNA carries. That is the slot ladder read backwards
  (`body_plan.gd`'s `radius_for`), outside and inside alike, and never under
  `BASE_RADIUS`. A DNA carrying more than the plan has slots needs the last rung,
  r40.
- **The gift's slot is room every body has** (`cell.gd`'s `GIFT_ROOM`). Every
  newborn, yours and the water's, is given a sense at birth, and the sense comes with
  a slot of its own (`genome.gd`'s `bonus_slots`, `drop.gd`'s `give_sense`). So a
  newborn carries four genes outside on three arcs. Counted strictly, every lineage
  would carry more than a newborn's room, and every one would divide past forty. So
  the floor counts one slot more than the arcs.
- **Where a body divides** (`divide_radius_of(dna)`): r40, or its floor times √2
  when that is more, so that each half is born at its floor.
- **A daughter** is her mother's radius over √2, half her area, as she always was.
- **The most any body grows**: `RADIUS_MAX`, r40 × √2 = r56.57.

| Genes outside | Genes inside | Floor | Divides at | Meals a generation |
|---|---|---|---|---|
| up to 4 | up to 1 | r26 | r40 | 3, from r28.3 (as today) |
| 5 | | r29.5 | r41.7 | 4 |
| 6 | 2 | r33 | r46.7 | 4 |
| 7 | | r36.5 | r51.6 | 4 |
| more | 3 | r40 | r56.6 | 5 |

The floor is the larger of the two columns. Meals a generation is `GROWTH_PER_MEAL`
(4) a meal from the daughter's radius to the mother's, rounded up.

**Counted from the DNA, not the body.** What a daughter wears is a roll; what her
lineage carries is not. Counting the DNA makes her size her lineage's, every
generation, whatever the roll gave her.

**When a cell divides is judged as it eats**, as before: on the meal that takes it to
its division radius. Its DNA can change in its life -- a placed gene, one written
over -- and its division radius moves with it: a gene that needs more room lets it
grow on, one fewer may make it divide at once. A meal never makes a body smaller.

### 1.2 What it changes

- **The water's apex lineages are giants.** A lineage that fills every arc is born at
  r36.5 and grows to r51.6. One that fills its inside too is born at r40 and grows to
  r57. Its mouth grows with it, so it swallows bigger prey.
- **Reproduction is the price.** Four or five meals a generation for a heavy lineage,
  three for a simple one.
- **The player** grows past r40 only while their DNA needs it, and divides there.
- **Saves**: a body kept smaller than its floor keeps its size; it divides at its
  division radius as any body does, and its daughters follow the rule. A body kept
  bigger than its division radius divides at once.
- **The shared pond**: the host's referee judges a guest's size up to `RADIUS_MAX`,
  lets a division begin at r40 or over, and takes a daughter at half her mother's
  area -- the size her mother went out of the water at. It never needs the guest's
  DNA. A guest that grows past its division radius on purpose earns that with meals
  the host fed it, as any growth. A division the host only heard of from its SISTER
  may have any daughter of a mother the host fed that far. `Wire.RULES` moves
  (`RADIUS_MAX` is in the rules; the floor's ladder is the body plan's, whose
  fingerprint they already hold), so builds on the old content and the new refuse
  each other at the handshake. `Wire.PROTOCOL` does not move: no message changes.

### 1.3 Drawn

- **The nucleus starts to double two meals before the division radius** -- each
  body's own, where it was always 8 units under r40.
- A body over r40 is drawn as any body, bigger.

---

## 2. The margin (phase 2)

### 2.1 The film

**A cell can only go where the water is at least as deep as it is thick.** At the
drop's edge the water thins to nothing. Starting value: its depth rises 1 µm for
every 15 µm in from the rim (water on clean glass spreads into a very flat film). So
a body of radius r reaches no closer to the rim than **30 µm per unit of radius**:

| Body | Closest to the rim |
|---|---|
| a drifter, r13 | 390 µm |
| a newborn, r26 to r28.3 | 780 to 850 µm |
| r33 | 990 µm |
| r40 | 1,200 µm |
| a giant, r56.6 | 1,700 µm |

It is the meniscus as it always was, read at each body's own size. Today's 240 µm
shallows, where a drifting body turns back, moves with it.

**Real.** In soil and thin water films, the thickness of the film decides which
microbes can move and feed: big protists are shut out of thin films.

### 2.2 Why it is the best place to grow

- **The light is full there** (daylight.md: all of it at the rim).
- **Food drifts to the edge**: a drying drop carries what floats in it toward its
  edge (the coffee-ring effect). Flocs and drifters drift slowly rimward, to where
  each one's own size stops it.

### 2.3 Where runs begin

A run's first cell, a cell back from a death, and the water's new arrivals start in
the margin.

### 2.4 Drawn

The film thinning toward the edge, and a faint line where the water gets too thin
for you.

---

## 3. Pins that moved, and why

Phase 1:

- **gene_probe**: none; the ladder's couplings to r40 still hold.
- **drop_probe**: the seeded lines, since heavier lineages divide later and bigger.
  Its checks of a division at forty now judge each body at its own division radius.
  The growth check holds every body under `RADIUS_MAX` and its own division radius.
  The save check trims to `RADIUS_MAX`. Lineage 1 counts the divisions past forty and
  wants some. Check 5 wants fifty divisions on rules where it wanted a hundred: the
  seeded drop makes 96 now, every kind of change among them. The kept room (checks 12,
  lineage 8 and 7) is kept once a family carries a list of its own, 40 s in or the
  first second after, where it was kept at 40 s with none. The floors (check 6, rarity
  3) count apart a variety short twice running that the floor gave all it owed in
  between: the water took a carrier back, and the floor had answered.
- **Drift draws again when it leaves no room** (`genome.gd`'s `_drift_room`). A drift
  drew the gene that goes first. When that was an inside gene, and what came faced
  out onto a full ring, the drift gave up. With every gene at one copy, a trade had
  nothing to give either, so the division changed nothing, though lineage.md §3.1
  says every one changes a daughter. Lineages born big fill their DNA sooner, and
  the drop probe's lineage 1 caught one. Now the gene that goes is drawn again among
  those that leave room. Only with none of those does the drift not apply.
- **net_probe**:
  - the referee's size bounds: an arrival at r45 is a body's size now, so its refusal
    test asks r60;
  - the biggest honest call is r56.57's;
  - the water mother in "the host's water divides" carries five genes outside and
    divides at r41.7;
  - in the pond's honest run, the guest writes a gene more into its DNA and divides
    past forty, through the host's referee, with no foul;
  - a check of its own, "a giant divides": seen, early, late, unseen, too small,
    whole.
- **net_fuzz**: radii and sisters up to `RADIUS_MAX`'s.
- **`Wire.RULES`**: `cell.RADIUS_MAX`. The floor's ladder is the body plan's, already
  in the rules by its fingerprint.
- **ci.yml's trace**: the water's heavier lineages grow past forty. The first line
  that moves is a water cell at r42 where dev's stopped at r40.
- **The drop save's rules** gain `cell.RADIUS_MAX`, so a drop kept before this loads
  as converted. Every body is re-derived from its genome, and a body past
  `RADIUS_MAX` is trimmed to it.

---

## 4. What to watch when playing

All balance, which waits for players (`CLAUDE.md`).

- **Most lineages grow past forty.** A water cell writes nearly every meal into its
  DNA, so within a generation or two most lineages carry more than a newborn's room.
  In the drop probe's two seeded five-minute drops, 426 of 440
  divisions were past forty. So the floor sorts lineages by age as much as by
  strength: a young lineage is small, an old one big. For the margin (§2) that is the
  point: a newcomer grows up and out. If the water feels like a sea of giants, the
  levers are `GIFT_ROOM` (how many genes ride free), the ladder the floor reads, and
  `RADIUS_MAX`.
- **Giants.** If r57 apex cells own the water, the levers are the floor's ladder and
  `RADIUS_MAX`.
- **Slow lineages.** If carrying many genes stops being worth it, the lever is how
  much room a gene needs.
- **You.** Your DNA fills as the water's does, by eating. A lineage of yours that
  fills its arcs is born at r36.5 and divides at r51.6. Born bigger means more slots
  at birth and a mouth that swallows more.
