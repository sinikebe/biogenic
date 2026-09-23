# Roadmap

The phase order has only ever existed in conversation, which is why it keeps
being rediscovered. This is the record. One or two sentences each, in build
order, with the dependency that forces that order.

A phase is **done** when it has shipped to `main` and players have it. Phases
past 5 are **proposals** — they follow from what the owner has said they want
(more modes, more environments, multicellular bodies, a predator that becomes
edible) and nothing here invents scope beyond that.

## Done

**1 — Perception.** How a blind cell tells the player anything without lighting
up a screen whose blackness is the premise: the edge of the screen is the
membrane, signals are a bearing plus an intensity, and nothing ever carries a
position. `docs/design/perception.md`, built as `game/perception/`. Everything
after this is a subscriber to the signal bus it established.

**2 — The first playable.** A cell with a drive that is not obedient, inert
motes to bump into, one line of onboarding and a pause screen. Depends on 1
because there was nothing to feel until the membrane could show it.

**3 — The two view modes.** Full vision draws the water underneath the membrane
so the blind signals can be checked against the truth; point of view draws
nothing but the membrane. `game/vision/` and `game/mode_select.tscn`. Depends on
2 because a view that verifies needs something to verify.

**4 — Food and predators.** One food, one predator, separated on every channel
without spending light: food quickens the beat, the hunter makes it stumble.
Two deaths, a growth curve, and the `radius` comparison that decides what eats
what. `docs/design/food-and-predators.md`. Depends on 3 because the escape
window and the wake bearings could not have been measured blind.

## In hand

**5 — Genes and cilia.** A genome with a fixed number of slots, filled by what
you eat and worn on the outside as cilia; a starting cell that is already full,
so specialising means giving something up. `docs/design/genes-and-cilia.md`.
Depends on 4 because the gene rides on `food.eaten` and the slot count rides on
the `radius` that meals grow.

## What the ending is for

Phase 5 lands the arc on radius 40: the genome fills on the same meal that
nothing in the water can swallow you. The owner settled that shape and attached
the reason it is not the end of the game:

> *"We will later add so much possibilities, bosses, legendary organisms that it
> will still be fun even with a maxed out organism. The player can still discover
> new combinations of genes that makes it very fun, or even become cheated (that
> must stay hard to do tho)."*

So **the ending is a floor for later content, not a ceiling on the design.** It
changes what the phases below are for:

- **A maxed genome is a starting position.** Seven slots full is where the
  interesting question starts — *which* seven — so the genome stays swappable at
  maximum and every later gene is a new combination rather than a new number.
  `genes-and-cilia.md` §9.8 carries the constraints this puts on Phase 5 itself.
- **Bosses and legendary organisms are the natural Phase 8 content**, not a
  separate phase. A second water needed a reason to exist; "this is where the
  things a finished cell cannot yet beat live" is that reason, and it is better
  than "somewhere else to swim".
- **Overpowered builds are allowed, and must be expensive.** Not forbidden by a
  rule — gated by upkeep, by how many meals the combination costs to assemble,
  and by having to survive the assembly. A build that is strong on every axis
  should be one that starves.

## Proposed

**6 — ~~The predator becomes prey.~~ Absorbed into 5.** This phase existed
because there was a predator species to graduate past. There is not: `genes-and-
cilia.md` §1 makes edibility a gape comparison evaluated per cell and in both
directions, so *the* predator becoming prey is just *a* cell you have grown a
mouth big enough for. It happens on the first run, without a phase.

What was worth keeping from it has moved: the *taste* of a cell you can eat is
now the ordinary taste field, summed over whatever your gape fits rather than
over a species, so it needs no reserved slot at all — **glow slot 3 goes back to
being free headroom.** The growth curve that made `radius 40` reachable is Phase
5's slot ladder, and `radius 40` is now where the water stops being able to eat
you (`genes-and-cilia.md` §1.3).

**6 — The chase, re-measured.** The successor, and it is smaller. Phase 4's two
stated contracts — *a cell that does nothing must be caught*, and *you cannot
outswim it* — were derived against a tier-1 cell and Phase 5 breaks both
(`genes-and-cilia.md` §7.1). This is the pass that re-derives them across the
tier range, against a real genome rather than a scripted evader, and it is the
one thing in the whole plan that a human has to play rather than measure.
Depends on 5 because there is nothing to measure until tiers exist.

**The review widened it by one item.** Phase 5's seeding numbers —
`DRIFTER_SHARE`, `PEER_SPREAD`, `ARRIVAL_GAPE_MAX` and the peer cytostome
weights (`genes-and-cilia.md` §1.3, §9.6) — are the same kind of thing as the
chase contracts: settled in shape, unsettled in value, and answerable only by
swimming. They belong in this pass rather than in a later one, because the chase
cannot be measured against a water whose difficulty is still a free variable.

**7 — A third view.** The two existing views are *what the cell feels* and
*what is actually there*. The missing one is **what the cell knows** — the world
as its senses have built it, only what it has tasted or felt, drawn where it
believed those things were, with the error left in. It adds no simulation and no
art, and every sensory gene visibly buys a better map. Depends on 5 and 6
because before genes there is one sense and the map is trivial; the mode enum in
`run_state.gd` was written to append, so the seam already exists.
*The subject of the third view is the part of this the owner should replace if
they had something else in mind — the slot in the order is what matters.*

**8 — A second water.** Somewhere else to swim, with its own chemistry and its
own hazard, and the natural home for the first organisms a finished cell cannot
beat. Depends on 6: author a second place only once the first has a complete arc
— born, specialise, outgrow the water — because "what is different here" is not a
question you can answer without a baseline. The baseline is exactly what the
radius-40 ending provides.

**9 — Multicellular bodies.** Where the original concept's "synthesise the
corresponding cell" finally lands: spend genome capacity and mass to bud a
daughter of a type you carry the gene for, and keep it attached. Depends on 5
for the genes to synthesise from and on 8 for a reason — a colony needs a
pressure that a single cell cannot meet, and a second environment is the natural
place to put one.

**Later — genes decide one bite or chewing, for every cell.** The owner's rule
for the shared pond (`shared-pond.md`, `multiplayer.md` §10 row 6) is that every
cell obeys one eating rule, players included. *Which* genes decide whether a
mouth swallows a body whole or has to chew it apart is left to this phase:

- the membrane genes (`pellicle`);
- the eating gene (`cytostome`);
- perhaps acid, or a gene not yet named.

It is decided once, for every cell equally.

Its first work is the two places where today's rule is not yet the same for
every cell:

- a water cell swallows a player only from a committed run
  (`food.gd:1409-1436`);
- `pellicle` armours a player against a swallow but not a water cell
  (`food.gd:1467` against `cell.gd:508-509`).

It depends on the pond only in that the pond must not special-case players, so
that this rule lands on every cell at once. It is also Phase 6's kind of number:
a human has to play it.

## Standing rules the order obeys

- **Nothing is built before the thing it is evidence about.** Full vision exists
  to catch the membrane lying, so it came after the membrane; a third view
  exists to show what perception has bought, so it comes after genes.
- **Content is cheaper than structure.** A phase that needs a new `.pck` beats a
  phase that needs a new binary, every time; see `CLAUDE.md`.
- **Each phase leaves its own headroom.** Phase 1 specced four glow lobes and
  two pressure lobes for senses that did not exist; Phase 4 reserved slot 3 for
  the edible predator, and Phase 5 handed it straight back unspent; Phase 5
  leaves four free arcs on the body and two reserved hues. Keep doing that and the next phase costs a diff rather than a
  rewrite.
