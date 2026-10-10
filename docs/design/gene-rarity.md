# Common and rare genes: how the water carries a hundred of them

Phase 7 of "Genes as data" (`gene-catalogue.md` §9 and §15). The owner, 2026-10-04,
answering that document's row 3 as recommended:

> **Common and rare genes, rare ones scarce, and later tied to places.** With every
> gene equally likely you'd rarely meet the same one twice, and building the cell you
> want becomes luck. Common and rare keeps a hunt worth making.

And its row 1: *"There will be new organs. but also variants. At any moment of the
life of the game, we could add a new gene and/or variant."* With *"The gene pass is
just adding/editing genes, so it should be straightforward"*, that is the brief: **a
gene's rarity is a field on the gene, and adding a gene never needs anything else
retuned by hand**, whether it is the 18th or the 118th.

**Status: phases 7-1 and 7-2 built.** 7-1 (`gene-catalogue.md` §15.7, 2026-10-10): the
classes on the genes, the ladder, the floor by class with its queue and its budget, the
gift's two tags and the senses by channel, with today's water kept to the byte. 7-2
(`gene-catalogue.md` §15.8, 2026-10-10): every draw of the water by class, in floats,
drift weighted, `water.weight` gone -- and §2.2's share settled for a variety the water
never makes: an organ's place is shared among the varieties of each draw, so one out of
the water's pool takes nothing of it there and only its share in drift (§15.8 says how
and why). §15.8 has what §11.3's probes measured of this design. The word for a class on
screen is its own pull request (`rarity-word-ux.md`). Written from the code on `dev` at
`77f90c3` and from the numbers earlier specs measured. Nothing was prototyped or
measured for it (the owner, 2026-10-02: *"Don't measure in prototypes. I'll
playtest."*). §5 is arithmetic: expected values worked from the code's own draws and the
drop's measured populations. It says so wherever it appears, and none of it is a
measurement. It is built on what `gene-catalogue.md` phases 1 to 3 leave: one file per
organ, its variants and forms, and its `water` entry.

**What it replaces.** Where these say otherwise, this document wins:

- `gene-catalogue.md` §4.2 and §9, `water.weight`, a number on each organ: it
  becomes `water.rarity`, a class (§2);
- `genome.gd`'s `_mutate_drift`, an even draw, and `gene-catalogue.md` §9's *"the
  draw is a weight, defaulting to 1"*: drift draws by rarity (§3.2);
- `ocean.md` §6.4 and `drop.gd`'s `GENE_FLOOR` 2, one count for every gene: the floor
  counts by class, takes turns and has a budget (§3.3);
- `dna-slots.md` §9, *"keeps it at `GENE_FLOOR` carriers, and from phase 3 each
  strain"*: each strain at its class's count (§3.3);
- `food.gd`'s `_sensed`, the sum of four genes' tiers: the sum, over the senses'
  channels, of the best tier worn on each (§3.5).

---

## 0. What the water does today, and what a hundred genes would do to it

**Five things make a gene** (`dev` at `77f90c3`):

1. **The spawner's drifters**: one gene at tier 1, drawn by `GENE_WEIGHTS` from
   `DRIFTER_GENES` without the toxin (`food.gd` `_seed_drifter` :6116, `_draw_gene`
   :6194). In the five minutes of `drop_probe`'s two seeded drops it made 1,303 at a
   newborn's composition and 2,218 at a sighted player's (`DEV_LINES`): 4.3 and 7.4 a
   second.
2. **The spawner's peers**: the born three, then draws without replacement from the
   same table until the radius's outside slots are full, the toxin's place by a coin,
   and a sense given to a peer that drew none (`_draw_living` :9593).
3. **Drift**: a division's mutation replaces a gene by one the lineage lacks, drawn
   **evenly** from `GENE_ORDER`'s varieties, never the mouth (`genome.gd`
   `_mutate_drift` :1805). Every water division mutates (`lineage.md` §3.3), and
   about half of the mutations are drifts: 174 and 341 in the same five minutes.
4. **The gift**: one of four senses, drawn flat, to a newborn that wears none at five
   seconds, and to every peer and water daughter that wears none (`FIRST_SENSES`,
   `Drop.give_sense`).
5. **The floor**: every two seconds the drop counts each variety's living carriers.
   One under `GENE_FLOOR` 2 goes on the next drifter, and the toxin, which no drifter
   carries, on the next peer (`_count_genes` :9636; `drop.gd` :121, :340–357). It is
   a net, not a source: in those five minutes it put a gene on no drifter at all, and
   the toxin on one peer (`floors: gene 0+1` and `0+0`).

**Three steps of weight.** `cirrus`, `flagellum` and `chemocyte` weigh 4, `stigma`
and `ampulla` 3, the other nine and the toxin 2. The mouth's 3 is never drawn: every
peer is born with one and no drifter has one. Over the drifters' pool, 36 in all, a 4
is 11.1 % of the draw, a 3 8.3 % and a 2 5.6 %, and the four senses together 33 %.
About 457 drifters stand in a newborn's drop and 354 in a sighted player's
(`lineage.md` §5), so in a newborn's drop about 51 carry each 4, 38 each 3 and 25
each 2.

**At a hundred genes, today's rules lose what row 3 asks for.** `gene-catalogue.md`
§0 item 5 and the audit behind it estimated it:

- a gene the tables do not list enters at weight 1 (`_draw_gene`'s default). With 85
  added the pool weighs 121: the senses fall to 10 % of the draw, and a tail to
  3.3 %, about 15 in a newborn's drop where there are 51;
- drift picks among about 90 genes instead of 8 to 10, so a given organ comes about
  nine times less often by drift, and each of the 85 as often as the tail;
- **nothing bounds the floor.** Every short gene takes the next drifter, however many
  are short. The audit estimated 11 genes short at a count against 9 drifters made
  between counts, so that the floor would take every drifter and flatten the draw.
  Counting the floor's drifters as living as long as any drifter does, §5.3's
  arithmetic puts the same catalogue at 2.5 % of the drifters in a newborn's drop,
  6.4 % in a sighted one's and 18 % in a fully sighted one's: a smaller share, but
  one that grows with every gene, with nothing to stop it. And drop_probe's check 6
  and lineage 4, which ask every gene for two carriers at every count, would be
  asking it of 85 genes with two to four drifters each.

---

## 1. Decided, in one place

1. **Rarity is a class on the gene**: `water.rarity` in the organ's file, `common`,
   `uncommon` or `rare`. A variant inherits its organ's unless it sets its own. A form
   never sets one (§2.1, §2.4).
2. **A class is a step on a ladder** (`game/genes/rarity.gd`): common weighs 4,
   uncommon 2, rare ½, so a rare gene is drawn an eighth as often as a common one. A
   class also says how many carriers the floor keeps (§2.1, §3.3).
3. **One number per variety, read by everything that makes a gene**: its organ's
   class weight, shared among the organ's variants by their own classes. Variants are
   alleles: they share their organ's place in the water and change nothing outside it
   (§2.2).
4. **The commons always hold at least a third of the drifters' draw**
   (`COMMON_SHARE`), what the born organs and the nose hold today. When the ladder
   would give them less, everything else shares the other two thirds by its weights.
   So the commons stay as common as they are today however many genes arrive (§2.3).
5. **The spawner, its peers and drift all draw by that number** (§3.1, §3.2). Drift
   stops being even: it is the water's own draw, over what the lineage lacks.
6. **The floor keeps every gene in the drop at its class's count**: two living
   carriers for common and uncommon, as today, and one for rare. It counts every two
   seconds, as today (§3.3).
7. **The floor takes turns, within a budget**: at most one drifter in four carries
   its gene, and the gene short longest goes first. Today it never needs two at once,
   so nothing changes. At a hundred genes the arithmetic puts it at 2 to 11 % of the
   drifters, by how sighted the player is, and keeps its budget out of reach to about
   160 genes in the hardest case, a fully sighted player's drop (§3.3, §5.3).
8. **The gift stays the four senses, drawn flat** (§3.4).
9. **The water's danger counts senses by channel**: over `SENSE_FULL` 5, the sum of
   the best sense tier worn on each of light, beam, ping and smell. That is today's
   sum. Two variants of the nose count as one nose (§3.5).
10. **Today's seventeen keys**: the born three and the nose are common, the other
    thirteen uncommon, and none is rare. `stigma` and `ampulla` go from 3 to 2. The
    rare class waits for the gene pass (§4).
11. **Places later.** `water.habitats` is reserved and empty, and every draw goes
    through one function, which is where a habitat will act (§6).
12. **No protocol change and no binary.** The referee judges no draw. Content, in
    two pull requests: the structure with today's water kept to the byte, then the
    draws switched to the ladder (§8, §11).
13. **One call was the owner's**: whether the game tells a player how rare a gene is.
    Answered 2026-10-05: yes, in one word wherever the gene is named (§13).

---

## 2. The structure

### 2.1 Three classes on a ladder

**A drop of pond water holds a few kinds of cell in great numbers and a long tail of
kinds in small ones.** Sequencing found that a relatively small number of populations
dominate every sample, while thousands of low-abundance ones make up most of the
diversity: the "rare biosphere", which its authors called *"a nearly inexhaustible
source of genomic innovation"* ([Sogin et al., *PNAS*
2006](https://www.pnas.org/doi/10.1073/pnas.0605127103)). Row 3 has that shape: a
few genes the water is full of, and a long tail the gene pass keeps adding to.

| class | weight | the floor keeps | what it is for |
|---|---|---|---|
| `common` | 4 | 2 carriers | **what every run needs**: the organs a cell is born with, and the nose that turns a wander into a run |
| `uncommon` | 2 | 2 carriers | **what a run is built from**: every organ a player chooses among |
| `rare` | ½ | 1 carrier | **what a run is lucky, or determined, to find** |

**Why these weights.** Common and uncommon are the two weights today's water uses
most, 4 and 2, so today's genes keep them (§4). Rare is an eighth of a common and a
quarter of an uncommon: the first rare gene, added to today's water, has about six or
seven drifters in a newborn's drop of 554 bodies and about five in a sighted
player's (§5.1). That is a body a player sees now and then in full vision and may
chase, never a crowd. These are starting values (`CLAUDE.md`, "Balance waits for
players"), and §14 says what to watch.

**A fourth class later is one row** in the ladder: a name, a weight and a floor.
Nothing else names a class. Code asks the ladder in its order, so "the commons" is
the ladder's first row wherever this document says it.

### 2.2 One number per variety: a variant shares its organ

A variety's weight in the water is its organ's class weight, shared among the
organ's variants by their own classes:

```
weight(v) = W[class of v's organ] × W[class of v] / Σ W[class of v']
            (the sum over every variant v' of the same organ)
```

A variant's class is its organ's unless it sets its own.

**Alleles at one locus share one frequency**, and that is the model: the organ is the
locus and its variants are its alleles. Adding an allele does not make the locus any
commoner; it takes its share from its siblings. `dna-slots.md` §8.3 settled it for
the toxin already: *"The toxin is drawn as often as `veneneux` is today; then a die
picks its strain and a coin its place. So the strains share today's toxin, and do not
triple it."*

So **a variant never changes anything outside its organ**:

- three strains of the toxin that set no class are uncommon like their organ and
  split its 2 evenly, which is the die `dna-slots.md` asks for;
- a rare variant of `cirrus` takes 4 × ½ ÷ 4½, about 0.44, of `cirrus`'s 4. The plain
  `cirrus` keeps 3.56, and every other gene keeps what it had. In a newborn's drop
  that is about six of its 54 `cirrus` drifters (§5.1);
- a second variant that sets nothing, beside a plain one, splits the organ evenly.

**Forms are not variants.** A form is a variant in one place (`gene-catalogue.md`
§3), and the place is the slot's or a coin's. A form row never sets a class, and the
gene probe says so.

### 2.3 The commons keep a third

The ladder alone would dilute everything as organs are added: each new organ of
weight w takes a share from every other. Variants cannot do that (§2.2), but new
organs can, and the commons are the genes no run can do without.

**So the commonest class always holds at least `COMMON_SHARE` of the drifters'
draw:**

```
C = Σ weight over the common organs in the drifters' pool
N = Σ weight over the rest of the drifters' pool
if C > 0 and N > 0 and C / (C + N) < COMMON_SHARE:
    every non-common variety's weight is multiplied by
        C × (1 − COMMON_SHARE) / (COMMON_SHARE × N)
```

In words: whenever the ladder would give the commons less than a third of what
drifters carry, they keep a third, and everything else shares the other two thirds by
its own weights. A pool with no common organ in it, or nothing else, is left as the
ladder makes it.

**Why a third.** It is what the commons hold today: `cirrus`, `flagellum` and
`chemocyte` weigh 12 of the pool's 36. After §4's change they hold 12 of 34, 35 %, so
the rule does nothing to today's water. It starts to act once new organs add more
than 2 to the pool, two uncommon organs or five rare ones, and from then on **each of
the three is 11.1 % of the drifters' draw, exactly as it is now**, however many
uncommon and rare genes arrive. A common gene added later shares the third with them.

It is the pond's shape again, a few populations dominating every sample (§2.1). And
it is the one place where row 3's *"building the cell you want"* is held by
construction rather than by the gene pass's restraint.

**One set of weights, everywhere.** The factor is worked out once, over the
drifters' pool, when the catalogue loads, and again when a tool registers a gene.
Peers and drift use the same weights; their pools differ only in what they leave out
(§3.1, §3.2).

### 2.4 The fields

An organ's `water` entry (`gene-catalogue.md` §4.2), with `pellicle`:

```gdscript
	water = {
		"rarity": &"uncommon",  # how often the water makes it: rarity.gd's ladder
		                        # (gene-rarity.md §2). Required on a live organ. A
		                        # variant may set its own; a form may not.
		"drifter": true,        # phase 1a's: in the water's pool at all
		"habitats": [],         # reserved (gene-rarity.md §6): the places of a
		                        # water where it is found more. Empty: everywhere
		                        # alike. A variant may set its own; a form may not.
	}
```

**`water.weight` goes.** A number on each gene is what made every gene something to
retune by hand.

`game/genes/rarity.gd`, the ladder, which names no gene:

```gdscript
extends RefCounted
## The classes a gene's `water.rarity` names, commonest first: what each weighs in
## the water's draw and how many living carriers the floor keeps of each
## (docs/design/gene-rarity.md §2, §3.3). A class is a row. Nothing else names one.

const LADDER: Array[Dictionary] = [
	{"class": &"common", "weight": 4.0, "floor": 2},
	{"class": &"uncommon", "weight": 2.0, "floor": 2},
	{"class": &"rare", "weight": 0.5, "floor": 1},
]
## The share of the drifters' draw the first class always holds (§2.3).
const COMMON_SHARE := 1.0 / 3.0
```

The catalogue resolves each key's numbers once, into its flat record
(`gene-catalogue.md` §4.2), and answers:

- `rarity_of(key)`: how rare it is in the water, the rarer of its organ's class and
  its variant's own. A rare kind of a common organ is rare, and so is any variant of
  a rare organ. It is the class the floor counts by and the word a player would read
  (§7);
- `water_weight(key)`: §2.2's number after §2.3's factor; a form's is its variety's,
  and a retired key's is 0;
- `floor_of(key)`: the floor of `rarity_of(key)`'s class.

**Everything that makes a gene reads `water_weight`**, and nothing reads the
ladder's weights directly. That one function is also where a habitat will act (§6).

---

## 3. What rarity drives

### 3.1 The spawner: drifters and peers

**A drifter** (`_seed_drifter`): the floor's gene if one is due (§3.3); otherwise one
variety drawn by `water_weight` from the drifters' pool, every live variety in the
water's pool but those tagged `not_on_drifters` (the toxin). A variety with two
places takes one by a coin, as today.

**A peer** (`_draw_living`, and `_draw_genome` for today's water): the body plan at
drawn tiers, then varieties drawn by `water_weight` without replacement until its
outside slots are full, as today. Two rules for variants:

- **one of each organ**: once a variety is drawn, its organ's other varieties leave
  the pool, so a peer never wears two tails. Today's draw does that by construction,
  with one variety to an organ;
- **a strain comes with its variety**, by its weight, which is an even die while the
  strains share a class; its place by the coin, as `dna-slots.md` §9 has it.

Then the gift if the peer drew no sense (§3.4), and a peer-borne gene if the floor
wants one (§3.3).

**Where a rare gene is found: on a drifter, alone.** A hunter rarely gives one. A
meal is the prey's dominant gene (`genes-and-cilia.md` §3.4), and a gene added later
sorts after every gene before it in `dominant_of`'s tie-break (`order` is
append-only), so a hunter gives its rare gene only when that is its highest tier. The
hunt is for the small body that carries it.

### 3.2 Drift

**What comes is drawn by `water_weight`** from every live variety the lineage does
not carry in any form, leaving out the organs tagged `never_drifts_out` (the mouth)
and the retired. Its form follows the slot, or a coin for a water cell, as today
(`dna-slots.md` §5.5). For an organ with `one_variant` on (`gene-catalogue.md` §6.3),
a lineage that carries any of its variants does not drift into another.

**Why not even.** The water's divisions drift 35 times a minute at a newborn's
composition and 68 at a sighted player's (§0). Drawn evenly, every rare organ would
come into the hunters' lineages as often as any uncommon one, and into the player's
daughters on the choosing screen as often: the rare class would leak through the one
door that does not go through the spawner. Weighted, a rare gene comes by drift as
seldom as the water makes it.

Real mutation is not even either: some changes arise far more often than others. A
whole new organ arriving by mutation, which is what a drift is, is the rare event,
and a common organ coming back to a line that lost it the frequent one.

**What it changes today** (§4). A line that carries its commons drifts evenly among
the uncommons, as now. A line that has lost a common organ by drift, its tail or its
nose, drifts back into it twice as often as into any one uncommon, 4 against 2: for a
line carrying `cirrus`, `chemocyte`, `ocellus` and `pellicle` and missing its tail,
the tail comes back in 16.7 % of drifts, against one in eleven (9.1 %) today.

**At a hundred genes** (§5.2), a given uncommon organ comes in about 4 % of drifts,
against 10 % today and the 1 % an even draw over a hundred would give.

### 3.3 The floor

**"Everything is everywhere, but the environment selects"**, Baas Becking's law of
microbial biogeography (1934; [de Wit and Bouvier, *Environmental Microbiology*
2006](https://doi.org/10.1111/j.1462-2920.2006.01017.x)): a microbe turns up, in
small numbers, wherever it could live, and the place decides which ones bloom. The
rare ones are the community's seed bank, a reserve that blooms when conditions change
([Lennon and Jones, *Nature Reviews Microbiology*
2011](https://www.nature.com/articles/nrmicro2504)). The floor is the first half of
that law. Places will be the second (§6).

**Whom it keeps**: every live variety in the water's pool, at its class's count
(`floor_of`, §2.4): two living carriers for common and uncommon, as `GENE_FLOOR`
keeps today, and one for rare. Carriers are counted as today: every living body's worn genes, a form as its
variety, every `GENE_FLOOR_EVERY` 2 s (`_count_genes`).

**Why one for rare.** Keeping a gene alive costs bodies, and the long tail is where
the genes are. At one each, the mixed hundred of §5.1 keeps 12 to 27 bodies standing
for the floor, by how sighted the player is; at two each it would keep three to four
times as many (43 to 79), for a promise a player cannot tell apart: the gene is in
the drop either way. §5.3 has the arithmetic.

**How it gives them back**, as today: on the next drifter; and a variety no drifter
may carry (tagged `not_on_drifters` and `floor_by_peers`, `gene-catalogue.md` §6.4:
the toxin's strains) on the next peer, made whatever the hunters' count (`lineage.md`
§5). A peer that already carries a variety of that organ is passed over for the
next, as a peer carrying either form of the toxin is today (`_give_toxin_back`).

**Its budget**:

- **at most one drifter in four is the floor's** (`GENE_FLOOR_GAP` 4, `drop.gd`): a
  drifter carries a short gene only if three drifters or more have been made since
  the floor's last one. The count starts full, so a drop's first short gene goes on
  the very next drifter, as today. Whatever the catalogue, three drifters in four are
  the draw's, and the draw keeps its shape;
- **at most one peer a count is the floor's**, as it is for the toxin today. The
  spawner's *"one more while the toxin is short"* (`_shortfall`, `_make_one`) becomes
  one more while any peer-borne variety is short, and that peer takes the one short
  longest.

**Its order: the gene short longest goes first.** Genes found short at the same count
go in the catalogue's order. The floor notes the count at which it first found each
gene short, and forgets it once the gene is back at its count. Today's floor takes
the last short gene in `DRIFTER_GENES`' order instead. The two differ only when two
genes are short at once, which the pinned runs never had (§0). At a hundred genes,
first come first served is what keeps one gene from waiting behind the same others
at every count.

**What it promises**:

- **every common and uncommon gene is in the drop at every count**, and back at two
  by the next, as check 6 holds today;
- **every rare gene is back on a body within a count or two of running short**,
  while the floor is under its budget. The arithmetic (§5.3) keeps it under to about
  160 genes in a fully sighted player's drop, the hardest case, and further in every
  other. Past that, rare genes would take turns in the drop, each gone for a while
  and back, and the gene probe fails before it comes to that (§11.3).

### 3.4 The gift stays the four senses

The gift is drawn flat from four senses: for a newborn at five seconds
(`normal_mode.gd` `FIRST_SENSES`), and for a peer or a water daughter with none
(`Drop.give_sense`). Rarity does not touch it, and the four stay four:

- **the referee judges it** (`referee.gd` `FIRST_SENSES` :162, `_is_gift`): a new
  gift sense is a rule change, the owner's to make, and a protocol change with it;
- **it is the first lesson in placing** (`normal_mode.gd`'s comment): four senses a
  new player learns;
- **a rare sense handed out at five seconds** would be the commonest gene a player
  holds.

Two tags keep it straight as senses multiply (`gene-catalogue.md` §9). **Whether a
body needs the gift** reads the `sense` tag: any sense at all. **What the gift is**
reads the `gift` tag: the four. Today both name the same four, so nothing changes.

### 3.5 The water's danger as sense genes multiply

`_sensed` (`food.gd` :6228) sets how much of the water can hurt you: the four
senses' tiers summed over `SENSE_FULL` 5, clamped to 1, and the drifters' share and
the peers' mouths follow it ("What a cell that cannot see meets", `food.gd` :396).
Summed over every sense gene, a second nose would read as a second sense, and a cell
wearing three variants of one sense would meet the full water with one sense's sight.

**So it sums channels, not genes**: for each channel a sense drives (`light`, `beam`,
`ping`, `smell`; `gene-catalogue.md` §7.3), the best tier worn among the senses that
drive it, and those summed over `SENSE_FULL`.

- **Today it is today's number**: each channel has one sense.
- **Variants never move it**: a second nose is still the smell channel, as a second
  provider of a stat combines by its row rather than adding up (`gene-catalogue.md`
  §5.1).
- **A new channel is code**, a lobe in `signal_bus.gd` (`gene-catalogue.md` §7.3), so
  it is rare and deliberate. It raises the most a body can sum, and `SENSE_FULL`
  stays 5, *"two organs, one grown"*: the full water costs as many tiers as now.
- `_anchor_sensed`, a person's, is the same function over the person's tiers.

**Finding senses.** The nose is common, so it keeps its 11 % of the drifters whatever
arrives (§2.3). The other three senses are uncommon, and thin as uncommon organs
arrive (§5.1). A player then sees more slowly, and the water darkens more slowly with
them, since it reads the senses worn. The two move together. That is how `_sensed`
was designed, and it needs no new lever here.

### 3.6 What rarity does not touch

- **Meals**: a meal is the prey's dominant form, as always.
- **Selection.** Rarity is how often the water *makes* a gene, not how long it
  lasts. A gene that serves its line spreads through its families whatever its
  class: the `axoneme`, weighted like every earned organ, is worn by 39 to 65 % of a
  newborn's water's hunters after thirty minutes (`lineage.md` §6.1). The floor only
  ever adds. An old server room fills with whatever wins there, rare or not, and that
  is the water learning.
- **Expression, copies, levels, upkeep, the body plan.**
- **The referee and the wire** (§8).

---

## 4. Today's seventeen keys

| key | today's weight | class | weight | share of the drifters' draw, today → after | drifters carrying it in a newborn's / a sighted player's drop, today → after |
|---|---|---|---|---|---|
| `cytostome` | 3, never drawn | common | — | — | — |
| `cirrus`, `flagellum`, `chemocyte` | 4 | common | 4 | 11.1 → 11.8 % each | 51 / 39 → 54 / 42 |
| `stigma`, `ampulla` | 3 | uncommon | 2 | 8.3 → 5.9 % each | 38 / 30 → 27 / 21 |
| `ocellus`, `axoneme`, `palp`, `myoneme`, `trichocyst`, `pellicle`, `plastid`, `vacuole`, `crista` | 2 | uncommon | 2 | 5.6 → 5.9 % each | 25 / 20 → 27 / 21 |
| `veneneux` and `toxicyst`: the toxin, one variant in two forms | 2 | uncommon | 2 | on no drifter | — |

`rhabdom` and `statocyst` are retired (`gene-catalogue.md` §4.4). They keep a class
in their files for the record, and no pool reads it.

**The rule that sorts them: common is what every run needs.** A cell is born with
the mouth, the `cirrus` and the `flagellum`, and the code already weights the nose
with them, because *"a nose is the difference between a run and a wander -- it has
to be the commonest thing the water can hand you, on a par with the three organs you
are born with"* (`food.gd`, above `GENE_WEIGHTS`). Everything else a run is built
from is uncommon.

**Nothing today is rare.** The same comment wants the beam and the voluntary push
*"the rarest of all"*, and the weights it shipped do not make them so. Making them
rare now would change how runs go, which is balance, and balance waits for players
(§12). The rare class is the gene pass's.

**What changes in today's water, and why** (phase 7-2, §11.2):

1. **`stigma` and `ampulla` go from 3 to 2**, the only weights that move. In a
   newborn's drop about 27 drifters carry each instead of 38, every other gene gains
   about two, and the four senses go from 33 % of the drifters' draw to 29 %. Peers
   draw them a little less often too. *Why*: keeping a 3 would be a fourth class for
   two genes, and the gene pass needs a rule it can sort a hundred genes by. The light
   and ping senses become as common as the eye-spot, the fourth gift sense, which is
   2 already.
2. **Drift is weighted.** It is today's for a line that carries its commons. A line
   that lost its tail or its nose gets it back about twice as often as any one
   uncommon organ (§3.2), so hunters may keep their tails and noses a little more
   often.
3. **Nothing else.** The floor's counts are today's for every gene today, two each.
   Its budget and its order act only when two genes are short at once, which the
   pinned runs never had. The senses' channel sum is today's sum, and the gift is
   today's.

Phase 7-1 proves the third item to the byte before 7-2 moves the first two (§11.2).

---

## 5. Adding a gene: the arithmetic

What follows is worked from the code's draws and the drop's measured populations. A
drop holds as many drifters as `Drop.food_count` asks for the players' sight: about
457 at a newborn's composition, 354 at a sighted player's (`lineage.md` §5) and 249
at a fully sighted one's, where `_sensed` reads 1 and drifters are 45 % of the drop.
The spawner made them at 4.3 and 7.4 a second at the first two (§0) and at 5.5 at the
third (`drop_probe`'s `TAIL_LINES`), so a drifter lives about 105 s, 48 s and 45 s. A
variety's drifters are counted as a Poisson number around its expected count, which
drawing every drifter independently gives. Hunters carry genes too and are left out,
so every count of carriers below is the least the drop holds. None of it was
measured. §11.3's probes are what will measure it.

### 5.1 The spawner

A variety is drawn with probability `water_weight(v) / Σ water_weight` over the pool.
So:

- **adding a variant changes nothing outside its organ** (§2.2): the pool's sum is
  unchanged;
- **adding an uncommon or rare organ** of weight w, once the commons' third binds,
  multiplies every other non-common variety's share by N ÷ (N + w), N being the
  non-commons' weight, and leaves the commons where they are. Before the third binds
  (today), it multiplies every share by Σ ÷ (Σ + w);
- **adding a common organ** shares the commons' third with the others when the third
  binds, and otherwise dilutes everything by its 4.

**Table 5.1, at about a hundred genes.** Four ways the gene pass might get there,
each to 99 drifter varieties, and two rows for contrast. Carriers are drifters in a
newborn's drop / a sighted player's; a fully sighted player's drop holds 0.54 of a
newborn's. The floor's share is for all three:

| catalogue | each common organ, any variant | each uncommon organ | each rare variety | the senses' share of the draw | the floor's share of drifters made (§5.3), newborn / sighted / fully sighted |
|---|---|---|---|---|---|
| today, after 7-2 (14 varieties) | 54 / 42 | 27 / 21 | — | 29 % | 0 / 0 / 0 % |
| **mixed**: 20 new organs (2 common, 6 uncommon, 12 rare) and 65 rare variants | 30 / 24 | 15 / 12 | 1.3–3.0 / 1.0–2.4 | 17 % | 2.5 / 4.9 / 10.6 % |
| **mostly variants**: 5 new organs (1 uncommon, 4 rare) and 80 rare variants | 51 / 39 | 23 / 18 | 1.2–3.9 / 0.9–3.0 | 26 % | 2.0 / 4.0 / 9.1 % |
| **every new organ rare**: 85 | 51 / 39 | 9 / 7 | 2.4 / 1.8 | 17 % | 1.8 / 3.9 / 9.6 % |
| **every new organ uncommon**: 85 | 51 / 39 | 3 / 2 | — | 13 % | 4.5 / 10.3 / **25.4 %** |
| the same, without the commons' third | 9 / 7 | 4 / 3 | — | 5 % | 1.5 / 4.6 / 14.9 % |
| today's rules: 85 new genes at weight 1 (§0) | 15 / 12 | 8 / 6 | 3.8 / 2.9 | 10 % | 2.5 / 6.4 / 18.0 % |

In the rows with variants, they are spread evenly over every organ the drifters
carry, the commons' too, and a common organ's count includes its rare variants.

**What it says:**

- **The commons hold** in every row but the one without the third: about 51 of each
  common organ in a newborn's drop at a hundred genes, as now. Commons the gene pass
  adds share the third: in the mixed row the two new ones take the five down to 30
  each.
- **The uncommon class thins as uncommon organs arrive**, and the rare class with it.
  What the gene pass marks uncommon is what it pays for. With 85 new uncommon organs,
  an uncommon is down to three drifters in a drop, and keeping each at two carriers
  costs the floor more than its budget in a fully sighted player's drop. The classes
  keep their order (an uncommon is always drawn four times as often as a rare one),
  but the long tail is then the uncommons, kept at two carriers each where a rare
  gene needs one. The playbook's rule is there for it: when unsure, rare (§11.4).
- **The senses** thin with the uncommons. The nose does not (§3.5).
- **The first rare gene**, added alone to today's water, is 1.45 % of the drifters'
  draw: about 6.6 drifters in a newborn's drop and 5.1 in a sighted one's. The chance
  that the draw has left none standing is under 1 %, and the floor covers that.

### 5.2 Drift

Drift draws the same weights over what the lineage lacks, so its arithmetic is the
spawner's with the line's own genes taken out. For a line carrying `cirrus`,
`flagellum`, `chemocyte`, `ocellus` and `pellicle`, and the same line without its
tail:

| | today | after 7-2 | the mixed hundred |
|---|---|---|---|
| a given uncommon organ comes | 1 in 10, even | 1 in 10 | 4.3 %, about 1 in 23 |
| without its tail, the tail comes back | 1 in 11 | 1 in 6 (16.7 %) | 8.0 %, about 1 in 12 |
| a given rare variety comes | — | — | 0.36 %, about 1 in 280 |
| some rare variety comes | — | — | 38 %, about 2 in 5 |

**The long tail is common together and rare one by one.** At a hundred genes a drift
brings some rare gene about two times in five, since a line lacks most of them, and a
given one about once in 280. That is the rare biosphere's shape (§2.1). On the
choosing screen it reads as it should: a daughter's new organ is often something
seldom seen, and seldom the same seldom-seen thing twice.

### 5.3 The floor

**What it costs.** A gene short of its count gets a drifter, which then lives as long
as any drifter. So the floor keeps about as many bodies standing as the draw leaves
its genes short of their counts:

```
the floor's drifters standing ≈ Σ over varieties v of E[(floor(v) − X_v)⁺]
                                with X_v ~ Poisson(D × p_v)
its share of the drifters made ≈ that ÷ D
```

D is the drifters standing and p_v the variety's share of the draw. That share is the
last column of table 5.1: **nothing today**, where every gene has 14 drifters or more
even in a fully sighted player's drop; **2 to 11 %** at a hundred genes, rising as
the player's sight thins the drifters; and over a quarter in one row only, 85 new
uncommon organs in a fully sighted player's drop.

**Its budget is a quarter, by construction.** The counter holds it, not the
arithmetic (§3.3). The arithmetic says where it would start to bind, in the hardest
case, a fully sighted player's drop: **at about 160 drifter varieties** if the new
genes are rare organs or rare variants (146 rare organs added to today's, or the
mixed row's organs and 130 rare variants), and **at about 100** if every new organ is
uncommon. In a sighted player's drop it binds at about 220 rare organs added, and in
a newborn's at about 290. The mixed path at 118 genes costs 3.4 / 6.5 / 14.0 %.
Short of the budget, a short gene is back on the next drifters made after a count.
Past it, short genes queue, first come first served, each waiting as long as the
queue ahead of it takes at one drifter in four.

**Why a quarter.** It is at least twice the floor's share in every one of table
5.1's four ways but the all-uncommon one, so it binds only past anything the gene
pass plans, and three drifters in four are always the draw's. A starting value, not a
measurement (§14).

### 5.4 Where it stops: the size of the drop

The floor's need grows with every gene, and the drop does not: in its thinnest
composition, 249 drifters can keep about 160 genes at their counts within the floor's
budget, not a thousand. That is the real ceiling of one water, and **row 3's places
are the answer to it**, not a retuning: a gene tied to another water is not this one's
to keep (§6). The gene probe prints the floor's expected share at every build and
fails only when it would pass the budget in the hardest case (§11.3): past about 160
genes, a third more than the 118 this phase is asked to carry, and sooner only if the
gene pass marks most new organs uncommon.

---

## 6. Later: tied to places

Row 3's last clause waits for a water that has places. This section reserves the seam
and says what it will mean. It builds nothing.

**What the real thing is.** Rarity has more than one axis. Rabinowitz's *seven forms
of rarity* (1981) separate how many a species has where it lives from how many kinds
of place it lives in and how far its range runs: a species may be scarce everywhere,
or abundant in one kind of place and absent from the rest ([Deborah
Rabinowitz](https://en.wikipedia.org/wiki/Deborah_Rabinowitz)). Row 3's class is the
first axis. Places are the other two. A founder effect shows how far apart they can
be: on Pingelap atoll, after a typhoon around 1775 left about twenty survivors, total
colour blindness, about 1 in 33,000 people in the United States, affects nearly one
islander in ten ([Pingelap](https://en.wikipedia.org/wiki/Pingelap)). And for
microbes, *"the environment selects"* is the second half of the law the floor keeps
(§3.3).

**The field**: `water.habitats`, a list of names, empty on every gene and inherited
by variants. A habitat is a name a water declares for a kind of place in it. The drop
already has one place both views can feel: the shallows, the band inside the meniscus
(`drop.gd` `SHALLOWS`), which full vision lights and the membrane meets as the rim's
echo and shadow (`ocean.md` §3.2). A second water (`roadmap.md` phase 8) could be a
habitat as a whole.

**What it will mean**, for the places design to settle:

- **the spawner**: a gene's weight is raised inside its habitats, so that a rare gene
  of the shallows is common there. Whether it is still drawn elsewhere at its class's
  weight (Baas Becking's "everything is everywhere") or not at all (Rabinowitz's
  narrow range) is that design's question, and the owner's (§12);
- **the floor**: keeps a habitat's genes in that habitat, and a water keeps only the
  genes whose habitats it has. That is what lifts §5.4's ceiling;
- **the hunt in point of view**: in full vision a rare body is something a player can
  see and chase; in point of view it is a meal that surprises. A place is something
  the membrane can find (the rim's echo, a light, a richness), so places are what make
  the hunt work in point of view.

**The seam, kept today:**

1. the field, empty, checked by the gene probe: every habitat named must be one a
   water declares, and no water declares any yet (§11.3);
2. **one function**: every draw reads `water_weight` (§2.4). A habitat will act there,
   given where the body is being made, which the spawner already knows before it makes
   it (`_make_one` picks the point, then `_spawn` seeds the body);
3. the floor's choice of what to give back lives in one place, `drop.gd`, beside the
   spawner's choice of where.

---

## 7. What a player must see

Rarity is felt in how often things come. Some of it must also be seen:

1. **How rare a gene is, wherever the gene is named.** The pause screen names every
   gene a player holds (`gene-catalogue.md` row 2), and the choosing screen every gene
   a daughter carries. A player who reads that a gene is rare learns its look, and can
   hunt the next one. Whether the game says so, and in which words, is the owner's
   (§13; recommended: yes, *common*, *uncommon*, *rare*). How it looks is the UX
   designer's, with the families (`gene-catalogue.md` phase 6) or after them.
2. **In the water a rare body looks like its organ**: its shape and its family's
   colour (row 2), as every body does. Full vision draws every body's organs, so a
   player who has learned a rare gene's look can spot it. A mark on the body itself is
   the UX designer's to propose; this design works without one.
3. **In point of view** a rare gene arrives as any meal does, its colour flooding the
   membrane (`genes-and-cilia.md` §2.2). Whether a rare one floods differently is the
   UX designer's. Until there are places, point of view finds rare genes by luck (§6).
4. **Nothing else is seen.** The floor, its budget and the weights act out of every
   player's sight, where the spawner works (`ocean.md` §6.3).

---

## 8. The shared pond, the server, saves and the replay

- **The host's water draws.** The spawner, the floor and every water division run on
  the host, or on the dedicated server, by its own catalogue. A guest mirrors bodies
  as names and draws nothing.
- **A guest's own division drifts by the guest's catalogue, and the referee judges no
  drift**: a new body is legal after a birth (`judge_person`), whatever genes it
  carries, and the one gene the referee checks by name is the gift's, one of the four
  senses (`_is_gift`), which do not change (§3.4).
  So **no `Wire.PROTOCOL` bump and no `Wire.RULES` change**, and net_probe's
  `referee` section passes as it is. From `gene-catalogue.md` phase 4, rarity is not
  a judged stat, so it is outside the handshake's fingerprint: two builds with
  different ladders play together, and each host's water draws by its own.
- **Version skew**: a guest's drift into a gene the host does not know arrives as a
  name, kept, drawn and inert, as `gene-catalogue.md` §11.3 has it.
- **The dedicated server** takes a new ladder when it next restarts empty, like any
  content. Its room's hunters keep whatever their families became (§3.6).
- **Saves**: `DropSave.rules()` fingerprints what bodies are read by, not what the
  water draws (`drop_save.gd` :334). A world saved before this loads as it was, its
  bodies unchanged, and new bodies follow the new draws. The floor's note of who is
  short (§3.3) is rebuilt at the first count, and not saved.
- **The replay** records bodies and their genes, as now. Rarity adds nothing to the
  water that needs recording. Habitats will: a place a player can see is a place the
  replay must draw (§6).

---

## 9. Cost

Nothing for every body every frame, and nothing per pair of cells. Everything rarity
adds runs where today's draws run, when a body is made, a cell divides or the floor
counts:

- **the weights**: resolved once when the catalogue loads, one pass over the genes;
- **a drifter's draw**: the drifters' pool is fixed between catalogue loads, so its
  running sums are kept as one table and a draw is one random number and a binary
  search, where today's `_draw_gene` walks the pool twice;
- **a peer's draws and a drift**: a pass over a table of about a hundred weights for
  each draw, leaving out what is drawn or carried, where today's walk fourteen;
- **the floor's count**: every two seconds, as today. Its one new walk is over the
  varieties, and its note of who is short is a small dictionary.

The busiest seeded run the probes pin is a fully sighted player's drop (`drop_probe`'s
`TAIL_LINES`, five minutes): 1,635 drifters, 2,269 peers and 334 drifts, so about 5.5
drifter draws, 7.6 peers of up to four draws each and 1.1 drifts a second. With a
pass of about two hundred steps for each peer draw and each drift, that is about six
thousand steps of simple GDScript a second: about a hundred a frame on average,
beside the water's own work on 554 bodies every frame.

Unmeasured. At `ocean.md` §4.4's assumed phone factor of six it should stay a small
part of the water's frame. The dev app's frame readout shows the water's own
`_process` share (`game/dev/frame_readout.gd`), where the spawner's tick and the
count run, and that is where a cost would show. If it ever does, a peer's draws can
keep one running sum and subtract what each draw takes, instead of walking the pool
again.

---

## 10. Generic mechanics, names at the edges

| file | what it knows | what it does not |
|---|---|---|
| `game/genes/rarity.gd` **new** | classes in order, each a weight and a floor; the first class's share | genes, waters, how the floor works |
| `game/mechanics/kinds_floor.gd` **new** | kinds, as any ids, each with a count and a least count; which are short, first come first served; at most one in N of what is made | genes, cells, the water |
| `game/genes/catalogue.gd` | each key's class, and its weight and floor from the ladder (§2.2, §2.3) | what a water makes, or when |
| `game/normal/drop.gd` | this water's floor: what it counts and when (`GENE_FLOOR_EVERY`), its budget (`GENE_FLOOR_GAP`), drifter or peer | how the queue works |
| `game/normal/food.gd`, `game/normal/genome.gd` | the spawner's draws, drift's pool, `_sensed` by channel | the ladder's numbers |

---

## 11. Build plan

### 11.1 Files

| file | change |
|---|---|
| `game/genes/rarity.gd` **new** | the ladder and `COMMON_SHARE` (§2.4) |
| `game/genes/gene.gd` | `water.rarity`, required on a live organ, settable by a variant, never by a form; `water.habitats`, reserved and empty; `water.weight` goes in 7-2 |
| `game/genes/organs/*.gd` | each organ's class (§4) |
| `game/genes/catalogue.gd` | `rarity_of`, `water_weight` and `floor_of`, resolved once; `register()` resolves again |
| `game/mechanics/kinds_floor.gd` **new** | the floor's queue and budget |
| `game/normal/drop.gd` | `GENE_FLOOR` gives way to the ladder's floors; `GENE_FLOOR_GAP` 4; `short_genes`, `take_drifter_gene` and `give_toxin` through the queue, for every peer-borne variety; `give_sense` tests the `sense` tag's genes and gives from the `gift` tag's |
| `game/normal/food.gd` | `_draw_gene` by `water_weight`, in floats; `_draw_living` and `_draw_genome` one variety to an organ; `_count_genes` by class; `_toxin_short`, `_shortfall` and `_give_toxin_back` for any peer-borne variety; `_sensed` and `_anchor_sensed` by channel; a `rarity_line()` beside `census_line()` |
| `game/normal/genome.gd` | `_mutate_drift` by `water_weight` |
| `game/normal/normal_mode.gd` | the gift's test by the `sense` tag, its pick from the `gift` tag (today's four either way) |
| `tools/gene_probe.gd` | §11.3 |
| `tools/drop_probe.gd` | §11.3 |
| `tools/eco_probe.gd` | prints `rarity_line()`; `--genes=crowded` registers §11.3's crowded catalogue, for looking at a crowded drop by hand |
| `.github/workflows/ci.yml` | 7-2 only: check 8's pinned hash, re-pinned with its reason |
| `game/genes/README.md`, `.claude/skills/gene/SKILL.md` | the playbook's rarity rules (§11.4) |

`rarity_line()` is a line of its own, as `lineage_line()` is, so that `census_line()`
and `DEV_LINES` keep their format: for each class, its live varieties, how many are in
the drop, their mean carriers and how many are short now; the floor's drifters and
peers so far, by class, and their share of what was made.

### 11.2 Phases

Two pull requests into `dev`, after `gene-catalogue.md` phase 3. Both are content, and
they can go out in one release.

| phase | what it does | what proves it |
|---|---|---|
| **7-1. Rarity as data, today's water kept** (`chore:`) | `rarity.gd`; every organ's class; the floor by class, with its queue and budget (`kinds_floor.gd`); the peer-borne floor for any variety; the gift's two tags; `_sensed` by channel; `rarity_line()`; the gene probe's rarity checks. **The draws still read phase 1a's `water.weight`, and drift stays even** | **identity**: every seeded-water pin unchanged (§11.3); every probe `ALL PASS`, no check loosened; the floor's new unit checks |
| **7-2. Common and rare genes in the water** (for players) | every draw by `water_weight`, in floats; drift weighted; one variety to an organ on a peer; `water.weight` removed; every seeded-water pin re-recorded, with the reason in the commit and above each | the draw, drift, crowded-drop and channel checks (§11.3), and the pins' new values, each explained |

**Why two.** 7-1 rewrites the floor and `_sensed`, which today never act differently;
if every seeded run comes out as `dev`'s, the rewrite is proven. 7-2 then changes only
what the draws read and how, and its re-recorded pins can be read as that and nothing
else, as DNA slots phase 1's were (`ci.yml`, the note above check 8). Its explanation,
above each pin: every draw of the water is now a float draw by `water_weight`, so a
seeded run differs from `dev`'s from the first body the water seeds; `stigma` and
`ampulla` weigh 2; and drift is weighted, so `DEV_MUTATIONS` differs from its first
drift.

**7-2's title**, a line of the patch note: *"Genes in the water are common or
uncommon now, with room for rare ones: the organs you are born with and the nose stay
the commonest, the light and ping senses are a little less common, and a daughter is
likelier to win back a tail or a nose her line has lost."*

**After 7-2**: if the owner answers §13 yes, the words are the UX designer's to
design, and land no later than the first rare gene.

### 11.3 Checks

**The gene probe** (`tools/gene_probe.gd`, `gene-catalogue.md` §12.1; static, in CI)
gains:

1. **the ladder**: classes unique, weights above 0 and falling, floors 1 or more,
   `COMMON_SHARE` between 0 and 1;
2. **a class on every live gene**: the organ's `water.rarity` names a row; a
   variant's, if set, too; no form row sets one. This replaces *"water: a weight"*;
3. **habitats**: every name in `water.habitats` is one some water declares. None does
   yet, so every list is empty; no form row sets one;
4. **a weight**: every live variety in the water's pool has `water_weight` above 0,
   every retired key 0, and the commons hold at least `COMMON_SHARE` of the drifters'
   draw;
5. **the water's arithmetic, printed**: for each class, how many varieties and each
   one's expected drifters at a newborn's, a sighted and a fully sighted player's
   composition (§5, with D from `Drop.food_count` at 0.2, 0.6 and 1), the senses'
   share of the draw and the floor's expected share of the drifters. A pull request
   that adds genes shows what they cost the water, in its CI log;
6. **the floor's load stays bounded**: the floor's expected share is under its budget
   at all three compositions. It fails, past about 160 genes on today's drop (sooner
   if most new organs are uncommon, §5.3), with the sentence *"the drop cannot keep
   this many genes at their counts: see gene-rarity.md §5.4"*, because past it the
   floor cannot keep its promise, and the answer is a design (places), not a
   retuning. Short of it, nothing the gene pass adds can fail it.

**`drop_probe`, changed:**

- **The floor's unit check** (`_drop`, :1180): with every gene counted at 5, `palp` at
  1, the toxin at 0 and `crista` at 2, the floor finds `palp` short, gives it to a
  drifter and leaves the toxin for a peer. It keeps that, through the queue, and adds:
  a rare variety at 1 carrier is not short and at 0 is; two found short at one count
  go in the catalogue's order, and one found at the next count after both; the
  first goes on the next drifter and the second waits for three more; a peer-borne
  variety never goes on a drifter.
- **Check 6, the floors** (`_five_minutes`, :1820). *"Every drifter gene carried at
  every count, and a gene found short back at `GENE_FLOOR` by the next"* becomes:
  **every common and uncommon variety carried at every count and back at two by the
  next; no rare variety short three counts running; the floor's drifters at most a
  quarter of those made; no drifter made with a `not_on_drifters` variety.** With no
  rare gene in today's catalogue, that is today's check with the budget's clause
  added, which today's floor meets by making no drifter at all.
- **Lineage 4, the spawner** (:2059). *"Every gene carried at every census"* becomes
  **every common and uncommon variety at every census, and every rare one at every
  census but for a gap of one**; *"no peer … but for venom"* becomes *but for the
  floor's peer-borne genes*. Today's catalogue: today's check.
- **The seeded-water pins**: every fingerprint of a seeded run of the water.
  `drop_probe` holds ten: `DEV_LINES` (check 1, lineage), `IDENTITY_LINES` (lineage
  10), `THREE_ONE_LINES`, `PACK3_LINES`, `TAIL_LINES`, `DEV_MEMBRANE`, `PACK3_TRACE`,
  `TAIL_TRACE`, `DEV_DRAWS` with `DEV_DRAWS_TOXIC` (dna 8) and `DEV_MUTATIONS` with
  `DEV_MUTATIONS_CAME` (dna 1); `ci.yml` holds check 8's hash. **Unchanged by 7-1**,
  which is its identity. **Re-recorded in 7-2** from the checks' own output, all
  together and with one explanation (§11.2), as DNA slots phase 1 re-recorded the
  same set. dna 1 and dna 8 keep what they assert beyond the digests: a genome with
  no toxin draws and mutates as the pin says, and a draw differs only where it
  should.

**`drop_probe`, new**, a section `rarity`:

1. **The draw** (static, no drop). A synthetic catalogue is registered
   (`Catalogue.register()`, `gene-catalogue.md` §12.3) with commons, uncommons, rares
   and variants of each. 100,000 drifter draws from a fixed seed land within 2 % of
   each class's share of `water_weight`, and within 10 % for each variety expected
   2,000 times or more; a variant's draws are its organ's times its share; the commons
   hold `COMMON_SHARE` where the ladder would give them less; no peer wears two
   varieties of one organ.
2. **Drift** (static): 50,000 drifts of a fixed DNA bring no carried variety, never
   the mouth and never a retired gene, and the classes' shares land within 5 % of
   their weights over what the DNA lacks.
3. **The crowded drop.** The mixed hundred of table 5.1, registered; five minutes of a
   drop made for a fully sighted player, as check 6's is, which is the floor's hardest
   case (§5.3), on the rules. Check 6's floors as above; the floor's drifters at most
   a quarter of those made; and of all the drifters made, the commons at least nine
   tenths of their share of the draw, so the floor has not flattened it. It prints the
   floor's measured share beside §5.3's arithmetic, 10.6 %.
4. **Senses by channel**: a body wearing `chemocyte` at 2 and a synthetic second nose
   at 3 reads 3, not 5; today's four at any tiers read their sum.

**CI**: the gene probe (from `gene-catalogue.md` phase 1a) and `drop_probe` already
run in CI. Nothing new to wire, beyond `ci.yml` check 8's pin in 7-2.

**By hand**: `eco_probe --genes=crowded --sensed=1 --until=1800` prints the
crowded drop's `[rarity]` line every census for thirty minutes, for anyone who wants
to see the floor work over a long run. It is not in CI.

### 11.4 The playbook

`game/genes/README.md` (`gene-catalogue.md` §16) gains the rules the gene pass
follows:

- **every new organ sets `water.rarity`**: `common` only if every run needs it, since
  the commons share one third and a new common makes the others less common;
  `uncommon` if runs are built from it; and **when unsure, `rare`**, since moving a
  gene up a class later is one line and the probe prints what each class costs;
- **a variant sets nothing to share its organ evenly** with its siblings, or `rare`
  to be a rare kind of a commoner organ. It changes nothing outside its organ;
- **a form never sets a class**;
- **the probe's printout goes in the pull request** (§11.3 item 5): what the water
  holds of each class, and what the floor costs.

### 11.5 What it replaces

- `food.gd`'s `GENE_WEIGHTS`, by then phase 1a's `water.weight`, and `_draw_gene`'s
  integer draw with its default of 1: `water.rarity`, the ladder and `water_weight`;
- `genome.gd`'s even drift;
- `drop.gd`'s `GENE_FLOOR`, and `take_drifter_gene`'s last-first order;
- `food.gd`'s `_toxin_short` and `_give_toxin_back` as the toxin's alone: any
  peer-borne variety, one a count;
- `_sensed`'s sum over `SENSE_GENES`;
- `ocean.md` §6.4, `lineage.md` §5 and `dna-slots.md` §9, where every gene is kept at
  two carriers;
- `gene-catalogue.md` §4.2's `water = {"weight": 2, …}` and §12.1's *"water: a
  weight"*.

### 11.6 Content or binary

GDScript and data under `game/` and `tools/`, and a hash in `ci.yml`. No
`project.godot`, no autoload, no permission. **Both phases ship as content**, with
`binary_version` unchanged, and `Wire.PROTOCOL` and `Wire.RULES` unchanged (§8).

---

## 12. Left open

- **Today's genes in the rare class.** None is rare (§4). If the owner wants a rare
  gene to hunt before the gene pass, the code names its own candidates, the beam and
  the voluntary push (`food.gd`, above `GENE_WEIGHTS`), each a line. `lineage.md`
  §6.2 shows what the push decides in a chase, so that is a balance change, made from
  play.
- **What a gene of a place is elsewhere**: rare there (Baas Becking) or absent
  (Rabinowitz's narrow range). The places design puts it to the owner when there are
  places (§6).
- **A second water's own ladder** (`ocean.md` §13): `rarity.gd`'s rows are this
  drop's. A second water could bring its own, and the catalogue would then resolve
  the weights per water. Not built until there is one.

---

## 13. The owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | Does the game tell a player how rare a gene is? | **✓ Yes, in one word wherever the gene is named** (the pause screen, the choosing screen): *common*, *uncommon* or *rare* / No: the player learns it from how seldom they meet a gene | Yes: the first time you hold a rare gene you read that it is rare, learn what it looks like, and can go looking for the next one. No: you notice rarity only over many runs, and nothing tells you which genes are worth a hunt. |

**Answered 2026-10-05: yes, as recommended.** The owner: *"Recommended"*. So the
word is shown wherever the gene is named (the pause screen, the choosing screen),
designed with the UX designer and translated as every gene word is
(`gene-catalogue.md` §8); it is part of phase 7's build (§7, §11).

**Why yes.** Row 3 asks for *"a hunt worth making"*, and a hunt needs a quarry a
player can name. Among a hundred genes nobody can keep count of what they meet
seldom. The words are plain, and the owner's own (*"common and rare genes"*). Under
either answer a body in the water is drawn as it always is; a mark on the body is the
UX designer's to propose (§7). If yes, the words are designed with the UX designer
and translated as every gene word is (`gene-catalogue.md` §8).

---

## 14. What to watch in the playtest

**After 7-2, in today's water** (no rare gene yet):

- **The light and ping senses** come a little less often from drifters: about 27 in a
  newborn's drop where there were 38. If a run that starts without them never seems
  to find one, that is this.
- **The water's danger** rises as you find senses. With two senses less common, it
  may rise a little later in a run.
- **Hunters' tails and noses.** A water line that loses its tail or nose to a
  mutation now gets it back twice as often as before. If hunters feel faster, or
  better at finding you, than before 7-2, this is a likely cause.
- **The choosing screen**: a daughter whose line lost a common organ is likelier to be
  offered it back.

**Once the gene pass adds rare genes:**

- **Does a rare gene turn up at all?** The first one is about one drifter in seventy.
  In full vision you should see one every few minutes if you look. Never seeing one
  means rare is too scarce; seeing them everywhere means it is too common.
- **Is it a hunt or a lottery?** A hunt is: you see one, you go for it, and sometimes
  you get it. A lottery is: it only ever happens to you. If it is a lottery, the
  levers are the rare weight and, later, places, not more rare genes.
- **Do the born organs and the nose still feel as common** as genes are added? They
  should feel exactly as now. If not, the commons' third is the lever.
- **Does the opening still work**: a nose, a tail and a meal in the first minute?

**The levers**, recorded and not turned (`CLAUDE.md`, "Balance waits for players"):
the ladder's weights (`rarity.gd`: 4, 2, ½), `COMMON_SHARE` (⅓), the rare floor (1),
the floor's budget (`GENE_FLOOR_GAP` 4), and any gene's class. Each is one line.
