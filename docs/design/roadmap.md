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

## Proposed

**6 — The predator becomes prey.** Finish the arc Phase 4 opened: the hunter's
chemistry stops blocking and starts tasting once you are the bigger cell (glow
slot 3, reserved since Phase 1), and then you can eat it and take its genome.
Depends on 5 because the growth curve is only fast enough to reach `radius 40`
once genes make it real, and because "eat the predator" only means something
when it means *take its thrust*.

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
own hazard. Depends on 6: author a second place only once the first has a
complete arc — born, specialise, outgrow the hunter — because "what is different
here" is not a question you can answer without a baseline.

**9 — Multicellular bodies.** Where the original concept's "synthesise the
corresponding cell" finally lands: spend genome capacity and mass to bud a
daughter of a type you carry the gene for, and keep it attached. Depends on 5
for the genes to synthesise from and on 8 for a reason — a colony needs a
pressure that a single cell cannot meet, and a second environment is the natural
place to put one.

## Standing rules the order obeys

- **Nothing is built before the thing it is evidence about.** Full vision exists
  to catch the membrane lying, so it came after the membrane; a third view
  exists to show what perception has bought, so it comes after genes.
- **Content is cheaper than structure.** A phase that needs a new `.pck` beats a
  phase that needs a new binary, every time; see `CLAUDE.md`.
- **Each phase leaves its own headroom.** Phase 1 specced four glow lobes and
  two pressure lobes for senses that did not exist; Phase 4 reserved slot 3 for
  the edible predator; Phase 5 leaves four free arcs on the body and two
  reserved hues. Keep doing that and the next phase costs a diff rather than a
  rewrite.
