# DNA slots: where a gene sits decides what it does

The owner, 2026-10-03:

> "dna slots for genes rework
> One player can put it's genes how he wants to. For instance, we could imagine
> a poison gene. When put in a dna slot that expresses inside the cell, it
> becomes poisonous. But when attached to the mouth, it becomes venom. This
> requires to be able to have this gene (we can call it toxin or something else)
> multiple times, let's say if you want to be venomous and poisonous."

later the same day:

> "The toxic gene or whatever we call it could have even more variations.
> Paralyze, sleep, damage over time, etc"

and, answering this document's first draft and the screen's (§22):

> "All recommended"
>
> "Just a precision for 3 : We need add body internal slots. Those express
> inside the body. The direction slots express outside the body."
>
> "Also, does cell have mouths?"

**Revised to those answers.** The first draft put two places on the seven
slots round the body: the three at the front were the mouth's, the other four
the body's. The owner's precision replaces that. **There are two places, in the
owner's words: outside and inside.** Outside is the seven direction slots round
the body, as today. Inside is new: a slot inside the body. A toxin inside is
poison; outside it is venom, and it acts in the direction its slot faces. Every
section below is written to that.

**Revised again the same day**, after the lead told the owner how real cells eat:
most absorb, amoebae engulf with any part of the body, ciliates have a mouth, and
toxins sit in three places. The owner:

> "That's interesting. This needs to be integrated. We must think of what the
> starting cell has, and what it could evolve to get"

That is answered in a companion, **`feeding.md`**: the starting cell, the paths a
cell can grow along, the water on the same paths, and one new path, a skin that
eats (phase 5). Here it adds the phases (§20.2), the hooks (§19), a line on the
wire (§14.4) and the owner's rows 11 to 14 (§22.4). **The real biology confirms
the toxin's places** as they stand: round the mouth to hunt (the front), on the
skin to defend (a side or the stern, beside the `trichocyst`'s darts), and
inside, which makes a cell poisonous to eat (`feeding.md` §2).

**This is the gene pass's venom, which the owner had already shaped.** On
2026-09-30, answering `ocean.md` row 12, the owner said: *"venom add a stack of
venom while it's biting. The stacks deplete over time, doing damage. We could
later imagine specialized venoms later. But for now keep it simple"*, and, asked
who takes the stacks: *"There'll be 2 variants. This is about the difference
between venomous and poisonous. We'll add both on the gene pass later."*
`roadmap.md` records it: a **venomous** cell's bite adds stacks to what it bites,
whatever bites or eats a **poisonous** cell takes stacks, and the two variants
replace both of `veneneux`'s effects today.

**Status: designed from the code and the existing specs. Nothing was prototyped
or measured, by the owner's choice; the owner playtests it on the dev app.** The
owner, 2026-10-02: *"Don't measure in prototypes. I'll playtest."* Every number
below is one of three things, and says which: a starting value with its reason,
arithmetic on the code's own constants, or a measurement an earlier spec holds,
cited where it is used. Balance waits for players (`CLAUDE.md`): no balance
number is put to the owner. Code references are to `dev` at `d08b0c3`.

**The screen and the look are `dna-slots-ux.md`'s.** It was written to the
first draft, and §10.2 lists what it has to redo now that the body has an
inside. Its corrections to the first draft are taken here: the refusal line
(§3.2), the French in `vous` (§3.2), `{} stacks` (§3.3), the full-copies guard
(§5.2), the quiet death and a friend's (§6.2).

---

## 0. What exists today

Read on `d08b0c3`, not taken from a summary.

- **The genome is two registers of `{gene: copies}`** (`genome.gd`):
  - `_dna` is what the cell writes and its daughters are made of;
  - `_order` says which slot each gene sits in, `&""` for an empty one;
  - `_body` and `_body_slots` are what the body wears, fixed at birth.

  **A gene can be in a DNA only once.** `_dna` is a dictionary, and `_sync_order`
  seats a gene only if `_order` does not already hold it.
- **Every slot is an arc of the skin** (`cilia.gd`'s `arc_for_slot`): slot 0 the
  nose, 1 the flank pair, 2 the tail, and 3 to 6 the four diagonals, two forward
  and two rear. Seven arcs, `SLOT_MAX` 7, earned by growing: 3 at birth, 7 at
  r40 (`slots_for`). The body has no inside slot.
- **The born three are drawn at home whatever slot holds them**
  (`dna-body.md` §12, item 1, still open). The mouth always bites at the nose.
- **A gene's copies are its strength and its odds.** They run 1 to 3 and are
  drawn as pips (`dna-body.md` §3.1). A daughter wears a gene with
  `EXPRESS_CHANCE` 0.55, 0.80 or 1.00 by copies, at full copies. Only the beam
  earns levels; every other gene's level is its worn copies (`level_of`).
- **A meal**: of a gene the DNA carries, it adds a copy at once (`integrate`); of
  a new gene, it waits in the tray to be placed (#118), and after 45 s lapses
  into the first free slot.
- **`veneneux` has two effects** (`cell.gd`, `food.gd`):
  - whatever **bites** a body wearing it takes 35, 55 or 80 % of that bite back
    into its own wound (`VENOM_BITE_BACK_BY_TIER`, `venom_back`), for every body;
  - whatever **swallows a player** wearing it dies. The player is spat out and
    pays `VENOM_COST_BY_TIER` in hunger (46, 34 or 22 % of a born tank, as
    seconds of rest; `_on_stung`).

  A venomous **water** cell is swallowed safely. That is "the one exception
  left" in the water's rules (`roadmap.md`, `ocean.md` §5.7).
- **`veneneux` is French for *poisonous*.** French keeps the two words apart:
  *vénéneux* is what harms whoever eats it (a mushroom), *venimeux* what
  injects (a snake). Today's gene is the poisonous variant, by name and by
  effect.
- **The drop keeps venom off its food** (`ocean.md` row 13). No drifter carries
  `veneneux` (`Drop.VENOM`, `drifter_genes`). A drop down to its last venomous
  bodies gives it back through the next peer (`give_venom`).
- **The wire carries genomes by name**: PERSON, GENOME, SISTER, and the gene of a
  CONTACT ATE (`wire.gd`).
  - `PROTOCOL` is 6, and `Wire.RULES` is `46913eab…`.
  - A genome is refused whole past `GENES_MAX` 8 names, *"seven slots and a held
    sample"*.
  - The referee's `_order_fits` holds that *every slot names a gene the body
    wears, once*.
  - `wire.gd` says that any change to the bite tables bumps `PROTOCOL`.
- **`veneneux` declares no sense and no action** (`genome.gd`'s `DECLARES`). It
  acts on its own, as the dart and the mouth do (`behaviour.md` §3.3).
- **A water cell has no layout.** Its organs sit in `Cilia.default_order`, it
  places nothing, and its meals take the first free slot (`lineage.md` §3.2).
- **Deaths.** A death the field makes is loud: a hit at a bearing, then the
  slam (`_on_killed` → `_die(true, …)`). Starving is quiet (`_die(false, …)`), and
  in a pond it is reported as `STARVED`. A friend who dies is drawn by cause
  (`_on_friend_died`: eaten, eaten by you, or `Gone.STARVED`). The replay records
  472 floats a frame since the hunger change (`recorder.gd`).

---

## 1. Decided, in one place

1. **Two places, in the owner's words.**
   - **Outside** is the seven direction slots round the body, as today, earned by
     growing.
   - **Inside** is new: **one slot inside the body**, every cell's from birth.

   §2.
2. **A gene may be a different *form* in each place.** A form has its own name,
   so every `{name: copies}` map in the game holds each one once, as it does
   today. §3.
3. **The toxin is the only gene with forms, and the only gene that may sit
   inside, now.**
   - Inside it is `veneneux`, **poison**: today's gene, kept by its name.
   - Outside it is `toxicyst`, **venom**.

   Every other gene faces out, and the inside slot refuses it. On screen the gene
   is called `toxicyst` (row 1), and a toxin not yet placed `toxin` (row 10). §3.
4. **Outside, the direction decides how venom works.**
   - At the **front** (the nose and the slot either side of it, row 3's three) it
     rides in on your bite.
   - On a **side** or at the **stern**, it stings the mouth that bites you there.

   §2.3, §7.
5. **More than once means once per form**: one venom outside in total and one
   poison inside, of each kind (row 4). A meal placed on a form you carry adds a
   copy to it. §3.4.
6. **Each slot is its own**: its own copies, which are its pips, its own roll for
   a daughter, and its own place. Copies never split; a move carries them. §4.
7. **A meal of the toxin waits to be placed**, even when you carry it: placed on
   your own form it adds a copy, placed in the other place it makes the other
   form. Left to lapse, it adds a copy. Every other gene is raised at once, as
   today. §5.
8. **Where it sits converts it.**
   - Placing or moving the toxin between outside and inside turns it into that
     place's form.
   - Between two outside slots it stays venom, and only where it works changes.
   - A move that would make a form you already carry is refused, and so is any
     other gene moved inside, and the screen says why.
   - A division's shift never crosses between inside and outside.

   §5.
9. **Venom and poison are doses**: stacks that wear off over seconds and act while
   they last, the owner's rule of 2026-09-30, in one generic file. The first kind
   is **harm**, damage over time, and a body carrying harm does not mend. A death
   by it is **quiet**. §6.
10. **Venom and poison replace both of `veneneux`'s effects.**
    - Venom leaves stacks through the bites its front delivers and the bites
      its side receives.
    - Poison leaves stacks in whatever bites it, anywhere, and a large dose in
      whatever swallows it, which still eats it (row 5).
    - Nobody is spat out any more. Every cell alike, so the water's last
      exception closes.

    §7.
11. **Strains: what a toxin does is the gene's own** (row 6), after the release
    (row 8).
    - **Paralysis** (phase 3) slows a body's own strokes and turns, down to a
      stop.
    - **Sleep** (phase 4) silences the hand, the instincts and the senses until a
      bite wakes the body (row 7).

    §6, §8.
12. **The water** has an inside too, and carries both forms. A peer that draws
    the toxin tosses a coin for its place. Drifters carry neither. The floor
    keeps the toxin in the drop. §9.
13. **What must be seen**:
    - the inside and the outside, and what a toxin becomes in each slot;
    - for venom, whether it works through your bite or guards a side;
    - every dose on every body, in both views, your own in point of view.

    §10.
14. **Instincts gain no sense and no action.** §11.
15. **Saves keep `FORMAT` 1, and no genome format changes**: the inside has no
    layout to keep. A world kept before this loads converted, and your old
    `veneneux` moves inside. §12.
16. **The wire.** Phase 1 moves `PROTOCOL` 6 to 7: the bite rules change, the
    pond says each body's doses, and a genome may now hold nine names.
    **`Wire.RULES` stays `46913eab…`.** Phases 3 and 4 move both, because the
    referee judges a paralysed or sleeping guest's motion. §14.
17. **Content only, in four phases**: venom and poison, inside and outside, then
    the screen, then paralysis, then sleep. The last two come after the release
    (row 8). `binary_version` does not move. §17, §20.
18. **A new cell keeps its mouth**, and the feeding paths are `feeding.md`'s.
    Its one new path, **a skin that eats** for a body with no mouth, is phase 5,
    after the release (rows 11 to 14, §22.4).

---

## 2. Places: outside and inside

### 2.1 The rule

> "We need add body internal slots. Those express inside the body. The
> direction slots express outside the body."

| slot | what it is | place |
|---|---|---|
| 0 .. 6 | the seven arcs of the skin: nose, flank pair, tail, four diagonals | **outside** |
| 7 | the inside of the body | **inside** |

```gdscript
# genome.gd, beside GENE_ORDER
## **The inside of a body** (dna-slots.md §2): every slot from this index on is
## inside the body, and every slot before it is an arc of the skin, outside.
## Arcs are earned by growing; the inside is every cell's from birth.
const INSIDE := CellBody.SLOT_MAX           # 7: the first inside slot
const INSIDE_SLOTS := 1
static func place_of(slot: int) -> StringName   # &"inside" from INSIDE on, else &"outside"
## **The front** (§2.3): the arcs that touch the mouth's own, the nose and the
## two either side of it. Anatomy, not a place: an outside gene in one of them
## acts through the bite.
const FRONT: Array[int] = [0, 3, 4]
```

**Real, and the reason the split is clean.** A ciliate's skin carries what faces
the water: its cilia, its mouth, and the extrusomes it fires outward.
Toxicysts *"tend to be localized around the mouth"*
([Britannica: toxicyst](https://www.britannica.com/science/toxicyst)), and
defended ciliates keep their toxins in cortical granules that discharge at an
attacker ([Predator-Prey Interactions in Ciliated
Protists](https://www.intechopen.com/chapters/62301)). Its inside keeps what
works where nothing faces anywhere: nuclei, vacuoles, mitochondria, plastids,
and the toxins that make it poisonous to eat. So an organ either faces out or it
does not, and the owner's two places are the cell's own.

### 2.2 The inside slot

- **How many: one.** It holds the only gene with an inside form, the toxin's
  poison. `INSIDE_SLOTS` is the one constant, and more inside genes or more
  strains are where it would grow (§19).
- **Earned from birth, by every cell**, not by growing. Three reasons:
  - the arcs are skin, and grow with it; the inside is not an arc;
  - it holds only the toxin, so a cell without one loses nothing to it;
  - off the ladder, it leaves alone `slots_for`'s two fixed points
    (`dna-strand.md` §4.1) and the three things forty is coupled to
    (`cell.gd`).
- **The born cell is still full outside**: three slots, three organs. Its inside
  is empty until it eats a toxin. The five-second gift is a sense, which faces
  out, so it still comes with its bonus slot: `_say_sense`'s test is on the
  outside layout, unchanged.
- **A daughter** has her inside from birth, and the poison her DNA carries sits
  there.
- **Which genes may sit inside: the toxin, as poison. Every other gene faces
  out**: the mouth, the cilia, the tail, the senses, the dart, the skin.
  `vacuole`, `crista` and `plastid` are organelles a real cell keeps inside, but
  here they have always sat on arcs, and letting them in would give every cell
  room for more genes. That is the next step and not this one (§19).
- **Capacity, by place**: outside as today (`slots()`); inside `INSIDE_SLOTS`,
  apart. A full cell carries seven genes outside and one inside, and wears nine
  in the one case today's body already allows, a gift placed over an organ still
  worn.
- **The inside has no order.** Nothing inside faces anywhere, so which inside
  slot holds what means nothing, and the genome keeps no inside layout. **The
  inside is the inside forms the DNA carries, and the inside forms the body
  wears**, read off the maps that already exist. `inside_layout()` and
  `body_inside()` hand the screen them in `GENE_ORDER`, padded with `&""` to
  `INSIDE_SLOTS`. That is why no save, no message and the referee's slot rule
  change for it (§12, §14).

### 2.3 Outside: the direction decides how venom works

The owner: *"The direction slots express outside the body."* A gene outside acts
the way its slot faces, as the beam, the dart, the ping and the nose already do
(`cilia.gd`'s `slot_bearing`). For venom:

| outside slot | bearing of its arc | venom there |
|---|---|---|
| **front**: 0, 3, 4 | 0°, ±42° | **rides in on your bite**: every bite your mouth lands leaves its stacks in what it bit |
| **a side**: 1 (the starboard flank), 5, 6 | 92.5°, ±133° | **stings the mouth that bites you there**: a bite landing within `VENOM_ARC_DEG / 2` of the slot's bearing leaves its stacks in the biter |
| **the stern**: 2 | 180° | the same, astern |

(The bearings are the arcs' own, `dna-body.md` §2.)

**The front is row 3's answer, kept.** The three slots the owner answered *"as
recommended"* are the arcs that touch the mouth's: the forward diagonals begin at
±42°, exactly where the mouth's own arc (`ARC_CYTOSTOME`) ends. They are where
an oral toxicyst is. **"Does cell have mouths?"** One cytostome per cell, at the
front, and drifters have none: the lead's answer to the owner, taken here. So
the front venom needs a mouth that bites. A drifter, or a cell whose mouth was
written over (a tier-0 mouth bites nothing, `BITE_BY_TIER[0]`), gets nothing from
it. A venom on a side needs no mouth. Phase 5's skin, which eats for a body with
no mouth, bites nothing either, so the same holds then (`feeding.md` §5.2).

**A sting on a side, checked against the biology and the geometry.**

- **Real.** Extrusomes fire where they are touched. When a predator's proboscis
  touched *Climacostomum*, *"dense material is visible ... emerging from the
  site where the proboscis touched"* ([Predator-Prey Interactions in Ciliated
  Protists](https://www.intechopen.com/chapters/62301)), and the toxicyst's
  filament is used to capture food *"and, presumably, in defense"*
  ([Britannica](https://www.britannica.com/science/toxicyst)).
- **The geometry is already there.** Every bite knows where on its target it
  landed: `food.gd`'s `_flank_theta` measures it at the target, for
  `CellBody.flank()`. It needs the side as well, a signed bearing, which is the
  same angle before its `absf`.
- **The stern is where a body is softest** (`FLANK_ASTERN` 2.10 against 1.00 at
  the nose). So a venom at the stern answers being chewed from behind, as a dart
  in a rear slot answers being flanked (`edibility.md` §2).
- **On a bite, not on any touch.** Bodies are solid and touch all the time when
  they jostle (`food.gd`'s `_step_separate`). Stinging every touch would make
  bumping lethal and make a drifter you brush past pay, and it would cost a new
  test over touching pairs every frame. A bite is the attack, already resolved
  and already located.
- **Why not "venom only through the mouth"**, with a toxin on a side doing
  nothing until it is moved. That is the simplest reading, and it is a trap. A
  slot that takes the gene and does nothing with it is freedom of placement to
  no purpose, and the screen would have to say so on four of the seven slots.
  It stays one switch away: `VENOM_SIDES := false` makes a side venom inert, and
  the screen then says `venom works at your front`.

**Not an owner row.** It is the owner's own sentence applied: a direction slot
expresses outside, in its direction.

### 2.4 What it does to growth

The inside is there from birth, so **poison can go in from the first toxin you
eat**. Venom takes an outside slot. The first two a first generation grows are
the front's (slots 3 and 4, at r29.5 and r33), and the last two are sides (5 and
6, at r36.5 and r40). A daughter carries her mother's seven-long layout, so from
the second generation every outside slot is there to write over.

### 2.5 Generic

A slot's place is a function of its index. A gene's forms by place are rows in
one table (§3.1), and the front is anatomy in another. The open ends are:

- **another inside gene**: one row in `FORMS`;
- **more room inside**: `INSIDE_SLOTS`;
- **another direction-dependent effect**: it reads the slot's bearing, as the
  dart does.

---

## 3. Forms

### 3.1 One gene, a name per place

**A form is one gene in one place**, and from phase 3 of one strain (§8). It is
what every map in the game is keyed by: `_dna`, `_body`, `_order`, a water
cell's `genome` and `dna`, every message on the wire, every saved world and the
replay. So **each form appears in a genome at most once, exactly as each gene
does today**, and none of those formats changes shape.

```gdscript
# genome.gd
## **A gene that is a different form in another place** (dna-slots.md §3):
## form -> [gene, strain, place]. A name not here is an outside gene of one form:
## itself outside, and nothing inside. The first listed form of a gene and strain
## is its *variety*, the name the gene goes by where no place is known yet: the
## water's draws, the floor's count, and two meals in the tray found to be one.
const FORMS := {
	&"veneneux": [&"toxin", &"harm", &"inside"],
	&"toxicyst": [&"toxin", &"harm", &"outside"],
}
static func form_in(form: StringName, place: StringName) -> StringName
	# its gene and strain's form in that place: itself outside for a gene not in
	# FORMS, and &"" -- it cannot sit there -- inside
static func fits(form: StringName, slot: int) -> bool    # form_in(form, place_of(slot)) == form
static func variety(form: StringName) -> StringName      # veneneux for both, today
static func has_forms(form: StringName) -> bool
static func forms_of(form: StringName) -> Array[StringName]
```

**Why a name per form, and not a gene that may sit twice.** A gene in two slots
needs two entries under one name. Nothing in the game can hold that:

- the water's `{gene: tier}` bodies and `Genome.tier_of`;
- the wire's by-name genomes;
- the saves;
- the referee's *a gene once* rule.

A name per form needs none of them to change, and a name the receiver does not
know is already legal and inert everywhere (`wire.gd`, the retirement of
`rhabdom`).

**Why `veneneux` stays the poison.** It is what the gene already does: harm to
whatever bites it or swallows it. Keeping the name keeps every world, kept drop
and server room that holds one. Nothing is renamed in any file, and the drop's
floor goes on finding it.

**The new form is `toxicyst`.** It is the real organ. In *Dileptus* and other
carnivorous protists, toxicysts *"tend to be localized around the mouth"*, and
fire a filament that *"paralyzes or kills other microorganisms; this filament is
used to capture food and, presumably, in defense"*
([Britannica: toxicyst](https://www.britannica.com/science/toxicyst)). That one
organ, used both to feed and to defend, is the owner's outside toxin: at the
front it feeds, on a side it defends. `CLAUDE.md` names the pattern: map the
ability onto a real organ.

### 3.2 What the player reads

| | slot word | its line | French |
|---|---|---|---|
| `veneneux`, inside | `poison` (was `venom`) | `whatever bites or swallows you takes your poison` | `poison` · `ce qui vous mord ou vous avale prend votre poison` |
| `toxicyst`, at the front | `venom` | `your bite leaves venom, which goes on hurting` | `venin` · `votre morsure laisse du venin, qui continue de faire mal` |
| `toxicyst`, on a side | `venom` | `whatever bites you on that side takes venom` **new**, `EXPLAINS_SIDE` | `ce qui vous mord de ce côté prend du venin` |
| `toxicyst`, at the stern | `venom` | `whatever bites you from behind takes venom` **new**, `EXPLAINS_STERN` (the screen's, `dna-slots-ux.md` §1: *that side* read wrong for the tail) | `ce qui vous mord par-derrière prend du venin` |

- **The slot says the place's word**, so a player reads the rule off the slot
  where they put the gene: `venom` outside, `poison` inside.
- **The line says where venom works**, as `that side` already does for the beam
  and the dart. Three lines, all inside the gene line's 440 px at 15 px. The
  ux-designer measured the first two in both languages (`dna-slots-ux.md` §1);
  the third is shorter than either.
- **One name for both forms** on the gene's line, `toxicyst` (row 1), through
  `Genome.NAMES := {&"veneneux": "toxicyst", &"toxicyst": "toxicyst"}`:
  `_update_explain` sets `_explain_name.text = String(gene)` today, and it becomes
  `Genome.name_of(gene)`. The keys never change; they are in saves and on the
  wire for good.
- **The places' words**: `outside` and `inside`, the owner's own. In French
  `dehors` and `dedans`. They appear in the line that teaches the rule (§10). The
  French is the game's register, `vous`, as every line here is
  (`dna-slots-ux.md` §1).
- **A toxin not yet placed is `toxin`** (`toxine`) on the tray, in hand and on a
  drag (row 10).
- **A move the toxin refuses** says why in `ACT_REFUSE`, the ux-designer's line:
  `here it would become %s, which you already carry` (`ici il deviendrait %s,
  que vous portez déjà`). It replaces the first draft's `you already carry %s`,
  which named the form you were not holding.
- **A gene that faces out**, armed or dropped on the inside slot, is refused in a
  line of its own: `%s works only outside` (`%s ne fonctionne que dehors`, as the
  shipped `fonctionne comme niveau %d` says it), `ACT_FACES_OUT`.
- **The screen's spec holds the final words.** Every wording here was measured
  in `dna-slots-ux.md` §1, and where the two differ it wins: the numbers rows'
  `qui vous mord…`, `EXPLAINS_STERN`, and `HINT_SISTER`, which goes because a
  shift no longer crosses between inside and outside.

### 3.3 The numbers

With numbers on (`gene-stats.md`), each form has two lines, read off §15's
constants by `gene_stats.gd`. There is a row for each form and, for venom, for
where it works, at this body's own copies and size:

| form | line 1: what it does | line 2: what it costs |
|---|---|---|
| venom at the front | `each bite leaves {} stacks of venom` · `a stack takes {} of a body your size over {} s` | `free to wear`, or `wearing it burns {} s a second` |
| venom on a side | `whatever bites you on that side takes {} stacks` · the same stack item | the same |
| poison | `whatever bites you takes {} stacks a bite` · `a swallower takes {} stacks` | `a stack takes {} of a body your size over {} s` · the wear item |

- **`{} stacks`, and `{} stack` at one**, never a bare number: `a swallower takes
  {}` read as a number on its own (`dna-slots-ux.md` §1). The French says
  `dose(s)`, the ux-designer's word for the owner's *stack*.
- **The values**:
  - `VENOM_STACKS_BY_TIER`, `POISON_STACKS_BY_TIER` and `SWALLOW_STACKS_BY_TIER`
    at the copies, as counts;
  - `HARM_PER_STACK × (26 / r)²`, as a share;
  - a stack's life down to `DOSE_GONE`, `τ × ln(1 / DOSE_GONE)` (9.7 s for
    harm), as a time.
- From phase 3 each strain adds one item: paralysis `{} stacks stop a body your
  size`, sleep `{} stacks put a body your size to sleep, until it is bitten`.
- The `TRANSLATORS` notes that say *the poison gene (`veneneux`, shown as
  `venom`)* change to name both forms and the inside.

### 3.4 What freedom of placement keeps, and the limits left

Any outside gene may go into any live outside slot, as today. The toxin goes
inside or into any outside slot. The limits that remain, and why:

| limit | why |
|---|---|
| **outside capacity**: 3 slots at birth, 7 at r40; a newborn may replace but not add | the body's arcs and the slot ladder (`lifecycle.md` §3.1), unchanged |
| **inside capacity**: one slot, from birth | §2.2 |
| **only the toxin goes inside** | every other gene faces out (§2.2) |
| **each form once**: one venom outside in total, one poison inside | a second copy of a form is what the pips already count, and every format holds a name once. "Once in total" and not "once per bearing" keeps one venom form; where it faces is the choice (row 4) |
| **a move may not make a form you carry** | it would merge two slots into one and lose copies, and a move never destroys (`moving-a-gene.md` §4) |
| **a copy to a form at three copies is refused** | it would spend the sample for nothing; the screen refuses it (§5.2) |
| **writing over a gene evicts it, with two taps** | `genes-and-cilia.md` §9.7's one irreversible action, unchanged |
| **the quick placement takes free slots only** | `dna-body.md` §8, unchanged. A free slot whose form you already carry is not offered, because placing there would add a copy somewhere else |

---

## 4. Copies, pips and inheritance

The brief's four questions, answered:

| question | answer |
|---|---|
| **Does each placed instance have its own level?** | Yes. Each form is a slot of its own with its own copies, 1 to 3, drawn as that slot's pips, the inside slot's as any other's. Its strength is its copies, as for every gene but the beam |
| **Do the copies split between places?** | No. Venom ●●○ outside and poison ●○○ inside are two slots. A copy goes where you place the meal, and a move carries all of a slot's copies |
| **What does the DNA carry, and what does a daughter inherit?** | Every form with its copies: outside ones in their slots, inside ones inside (and from phase 3 their strain, which is part of the form). A daughter inherits all of them, as she inherits every gene today |
| **What does expression chance do?** | Each form rolls on its own copies: 0.55, 0.80, 1.00. A daughter may wear the venom and not the poison. A form that missed stays in her DNA and rolls again in her daughters |

**Upkeep is each form's own**: `UPKEEP_PER_TIER` × (copies − 1). Venom and poison
at one copy each cost nothing to wear.

**A levelled gene with forms** would carry its level through a form change. No
such gene exists (only the beam levels, and it faces out), so the rule is
written in §5.4 for a later one.

---

## 5. The genome's rules

All in `genome.gd`. Every rule keeps two invariants, and check 1 holds them
(§20.3):

- **every form sits in its place**: an outside form in `_order`, an inside form
  not in `_order`;
- **no place holds more than its room.**

### 5.1 A meal

```
integrate(gene):
  a gene with forms (has_forms):
    every form of its variety carried at TIER_MAX       -> SATURATED (food only)
    otherwise                                           -> HELD: it waits
  any other gene: as today -- carried: a copy more (RAISED); new: it waits (HELD)
```

**It waits even when you carry it.** Carrying the poison does not say whether
this copy should go to the poison or become a venom. That decision is the
placement, and it is the owner's *"put its genes how he wants to"*. It waits in
the tray as every new gene does, for 45 s, called `toxin` (row 10).

**Two meals of one variety are one waiting sample**, as two meals of one gene
are (#118): the copies add up to 3, its clock starts again, and it goes to the
back. The sample keeps the name of the form it was first eaten as, which only
the lapse reads (§5.3).

**`_process` never settles a sample with forms on its own.** Today a waiting
gene that reaches the DNA by another route is written in as more copies. For the
toxin that would take the choice away.

### 5.2 Placing

```
_settle(waiting, slot):
  f = form_in(waiting.gene, place_of(slot))
  f is &""       -> nothing: this gene cannot sit there (the screen never asks)
  _dna has f     -> f gains waiting.copies, up to 3, wherever f is (RAISED);
                    the tapped slot is left alone
  slot inside    -> f goes inside, over the inside form there if the inside is full
  otherwise      -> _write(slot, f, waiting.copies), over whatever is there
```

- For a gene of one form outside, `f` is the gene, and this is today's code line
  for line.
- **A placement never writes a second slot of a form you carry.** Today's
  `_settle` already guarantees it for a gene: "certainly writes no second copy in
  a second slot".
- **The full-copies case is a screen guard** (`dna-slots-ux.md` §3.4). A tap
  whose copy would go to a form already at three would spend the sample and add
  nothing. `_commit_slot` refuses it, and so does the tray drop, both saying
  `ACT_RAISE_FULL`; the gene stays in hand. The quick placement never offers it,
  and the lapse never does it (§5.3).
- **For the screen**, `Genome.placing(gene, slot) -> [what, where]` answers what
  a second tap would do: write here, add a copy at slot *k*, refuse as full, or
  refuse because the gene faces out. The armed preview, the `Act` line and the
  guard all ask it, so the three never disagree.

### 5.3 A lapse

A toxin that lapses goes to the first of these that applies:

1. it adds its copies to the form it was eaten as, if you carry it with room
   (below 3);
2. otherwise to the other form, if you carry that with room;
3. otherwise it goes, as the form it was eaten as, into a free slot of that
   form's place (the inside, or the first free outside slot);
4. otherwise as the other form, into a free slot of the other place;
5. otherwise it is gone.

Forty-five seconds of not choosing still means *anywhere*, as it does today.
For a gene you carry, *anywhere* is *more of it*, and for one you do not, it is
*where you ate it from*.

### 5.4 A move

`move(from, to)` swaps as today, then **turns each of the two into the form of
its new place**:

- the lifted form becomes `form_in(lifted, place_of(to))`, and the displaced one
  `form_in(displaced, place_of(from))`;
- each takes its own slot's copies with it, and its level if it has one;
- **refused, changing nothing**, in two cases:
  - either end would become `&""`: a gene that faces out moved or swapped inside;
  - either end would become a form already carried in a third slot.
- A new `can_move(from, to) -> bool` answers the same question for the screen
  without moving anything.

**Between two outside slots the toxin stays venom.** What changes is where it
works: front or side, read off the slot. **Between outside and inside it
converts.** Swapping your venom (slot 3, ●●●) with your poison (inside, ●○○)
gives poison ●●● and venom ●○○ at slot 3: the strong one changed places, which
is a real choice and destroys nothing. The body is not touched, as today: a move
reaches your daughters.

### 5.5 A division's mutation

`mutated(dna, order)` keeps its three kinds and its draws.

- **Shift** stays among the outside slots, exactly as today, because `order` is
  the outside layout. **It never crosses between inside and outside.** Where a
  toxin lives, inside or out, is the player's to decide, and keeping the shift
  out of it keeps every genome's draw as it is. A shift can still move a venom
  from the front to a side, or back, which changes how it works, sideways.
- **Trade** moves a copy between two forms, as between two genes. Unchanged.
- **Drift** draws as today, with three rules for the toxin:
  - **What comes is a gene, not a form.** The pool leaves out every form but
    each variety's first, and any variety the lineage carries in any form. In
    phase 1 that list is today's, name for name, except for a lineage that
    carries venom and not poison, which the toxin no longer drifts into twice.
  - **A toxin that comes takes the form of the slot it lands in**: venom, since
    the gene it replaces sat outside. A water cell has no slots, so its place is
    one more coin, `randi() % 2`, drawn only when the toxin is what comes.
  - **The poison that goes, inside, is replaced by a gene that faces out.**
    - For your daughters, that gene takes a free outside slot (a hole in the
      layout), and with none the drift does not apply.
    - For a water cell, it applies while the cell has fewer than seven outside
      genes, and otherwise not.

    A drift that does not apply falls through to the next kind, as any kind does.

**A genome with no toxin draws exactly what it draws today.**

### 5.6 A birth, a load, a pose

`express(dna, order, …)` **puts every DNA form in its place** before anything
reads it:

- an inside form found in `order` (a save written before this, or a pose) leaves
  its slot and goes inside if the inside has room. Otherwise it becomes its
  outside form in place if that is not carried, and otherwise it stays and the
  log says so (no save can hold this; check 1);
- an outside form posed at an inside index (`--genome=…,toxicyst:2:7`) becomes
  its inside form.

**The body passed to `express` keeps every organ it wears.** An inside form it
wears only loses its outside slot in `_body_slots`, because inside nothing has an
arc. A birth is already in place, because §5.4 and §5.5 keep it so, and this does
nothing there. It is what migrates an old save (§12), and what makes a pose
honest: `--genome=…,veneneux:1:5` now poses poison inside, and slot 5 empty.

`_sync_order`, which runs every frame, seats only outside forms. An inside form
is never put into `_order`.

### 5.7 The water

- **A water cell's meal writes the form it ate**: the eaten cell's dominant form
  is what a hunter absorbs, as `genes-and-cilia.md` §3.4 always said. It never
  converts, because it never places.
- **Its room is by place**: `integrate_into(tiers, gene, capacity)` asks for room
  in the form's own place, inside (`INSIDE_SLOTS`) or outside (`capacity`), so a
  water cell's poison no longer takes an arc.
- **`Cilia.default_order(tiers)`** keeps the born three at home, seats a venom at
  slot 3 (the first front arc), and puts the other outside genes after it in
  genome order, as today. It leaves inside forms out: they are inside. A water
  hunter's venom therefore rides on its bite. Because a poison no longer takes
  an arc, the genes after it move up one: a water cell's beam or dart can face
  another way than it did.

---

## 6. Doses: what a toxin does

### 6.1 A load

The owner's *stack*, made generic: **a load is a number of stacks of one kind
on one body. It wears off over time, and acts while it lasts.** One new file
knows the arithmetic and nothing about genes:

```gdscript
# game/mechanics/doses.gd -- NEW. A body's loads of each kind: how they wear off
# and what each does. Knows no gene and no cell; every number is an argument.
enum Kind { HARM, PARALYSIS, SLEEP }
## stacks x (size / radius)^2: a load is diluted by the body it is in.
static func felt(stacks: float, radius: float, size: float) -> float
## Wears [param loads] by [param delta], each kind at its own tau, in closed form
## (exact for any step, which the drop's slow far bodies need), a kind below
## [param gone] stacks cleared whole. Returns `(harm stacks that wore off, the
## seconds of the step left after the harm ran out)`: harm is delivered as it
## wears, and mending has the rest of the step.
static func wear(loads: PackedFloat64Array, delta: float, taus: Array,
		gone: float) -> Vector2
static func still(loads, radius, size, full: float) -> float    # 1 free .. 0 stopped
static func asleep(loads, radius, size, at: float) -> bool
static func wake(loads) -> void                                  # SLEEP to 0
static func mends(loads) -> bool                                 # no HARM load
```

- **Every body carries one.** `cell.gd`'s cell and every `food.gd` `Body`, a
  person's included, gain `loads := PackedFloat64Array([0, 0, 0])`: 64 bits,
  because a load wears down like a clock and the drop keeps every clock in 64.
  Being born, a death and a reset clear them. A division clears them too, since a
  daughter is a new body.
- **It wears exponentially**: `stacks × e^(−t/τ)`, one tau per kind. That is
  linear in stacks, so a stack does the same however many share its body, and no
  stack needs a clock of its own. Below `DOSE_GONE` stacks a load is gone.
- **It is diluted by size**: a load acts on a body as `stacks × (26 / r)²`.
  - A dose is an amount, and a body twice as wide has four times the area to
    spread it over. The game is flat, so area stands for mass.
  - Real toxicity is measured per unit of body the same way.
  - It keeps a legendary cell legendary: one born mouth's venom barely touches an
    r80 runaway.
- **The numbers are the game's, not the mechanic's**: `cell.gd` holds them beside
  the other tables (§15).

### 6.2 Harm: damage over time

Phase 1, and what venom and poison do from their first day.

- **A stack of harm takes `HARM_PER_STACK` of a body of size 26 as it wears
  off**, 0.05 to start, diluted for any other size. It goes into the same
  `wound`, 0 to 1, that bites tear, so full vision's tears show it. Each step, the
  stacks that wore off × `HARM_PER_STACK` × the dilution go into the wound.
- **A body carrying harm does not mend.** `CellBody.mended()` is skipped while
  any harm is left, and resumes for the part of a step after it ran out.
  - That makes the arithmetic exact: one stack is worth exactly what it says,
    whatever else is happening.
  - Today's mending (1/75 of a body a second) would otherwise cancel a light dose
    completely.
  - It is also what a poison is: the body cannot repair while it is being harmed.
- **The same for every cell**, steered by hand, on the autopilot or in the
  water. Harm touches the wound and nothing else, so a dosed cell moves, senses
  and decides as it did.
- **A wound made whole by harm is a death by poison**: `Cause.POISONED`, as
  today. Remains are left as for any poisoned body (`ocean.md` §5.6).
- **Who killed it** is the body whose stacks it took last. That is `Body.dosed_by`
  and, for the cell on this device, `food.gd`'s `_dosed_by`, which becomes
  `died_to` for the replay's killer and `By.WATER` or `By.FRIEND` in a pond.
- **The death is quiet** (`dna-slots-ux.md` §6): nothing hit you, so there is no
  bearing and no slam.
  - `_die` takes the cause: `_die(loud, bearing, cause := Cause.STARVED)`.
    `_on_killed` dies quietly when the field's `died_of` is `POISONED`:
    `_die(false, bearing, POISONED)`.
  - The pond is told `POISONED` where a quiet death says `STARVED` today, and
    the drop gets its remains, as it already does for poison.
  - **A friend who dies of a dose is drawn as `Gone.STARVED`**:
    `_on_friend_died` takes `POISONED` as it takes `STARVED`. Nothing ate them;
    they stop where they were.

Each body is stepped in one place, beside today's `mended`. Each
`wound = CellBody.mended(...)` becomes a dose step that mends only when it may:

| body | worn in | a death by it is found |
|---|---|---|
| the cell on this device | `cell.gd`'s `_process`, beside the wound's mending | **at the top of `food.gd`'s `_contacts_with(null)`**, which both waters call for this cell: told as `KILLED`, `POISONED`, and returned as a contact death is, so nothing touches the field after it |
| the other player, on a host | `_step_person` | at the top of `_contacts_with(p)`, the same rule from its other caller: `_tell(p, KILLED, …, POISONED)` and `_person_gone` |
| a water body, in the drop | a new `_dose_step(i, b, dt)` in `_step_one`, right after `_tank`, with the body's own `dt` | there: `_consume(i, Cause.POISONED)` and return, as `_tank` returns on a starvation, so `_step_one` never files a body it has just retired |
| a water body, in today's water | the same `_dose_step`, at the top of `_step_body` when there is no drop | there, the same |
| this cell on a guest | its mirror sets its loads from each POND (§14), and `cell.gd` wears them between snapshots. The host's `your_wound` stays the truth | never on the guest, because a mirror runs no contacts. The host sends CONTACT KILLED `POISONED`, and the guest dies quietly |

`_step_body`'s own `mended` line then mends only a body carrying no harm.

### 6.3 Paralysis (phase 3)

**A paralysing load slows a body's own movement, down to a stop**:
`still = clamp(1 − felt / PARALYSIS_FULL, 0, 1)`, 1 free and 0 stopped. The water
still moves it. Real: Didinium's toxicysts immobilise a Paramecium before it is
swallowed ([Wessenberg and Antipa,
1970](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1550-7408.1970.tb02366.x)).

| cell | what paralysis does |
|---|---|
| **yours, by hand** | the tail's strokes add `still` × their speed and kick; the push and the dash are `still` × their thrust and speed; the cirrus turns at `still` × its rate. You coast under `DRAG`, and the water's wander still turns you. The senses work: you feel what is coming |
| **yours, on the autopilot** | the instincts read and decide as ever; what they ask is done at `still` × its strength, through the same four places in `cell.gd` |
| **a water cell** | its pace (`_move_ruled`: tail and push), its dash and its turn rate × `still`. It reads its rules and still wants to turn. The hand-written hunter's `_swim` is scaled the same way |

What moving costs is what the body actually does (`energy.md` §1.2), so a
paralysed body pays less for moving. Its mouth still closes on whatever drifts
into it.

### 6.4 Sleep (phase 4)

**A body sleeps while its sleeping load, diluted, is at least `SLEEP_AT`.** A
**hit wakes it**: a bite landing on it, or a dart. Its sleeping load then goes to
zero, before the stacks of that same bite are added. So a strong sleeping venom
keeps its prey asleep while it eats, and a weak one wakes it. Real enough: an
anaesthetic quiets a paramecium for minutes, and it recovers in fresh water
([Cole and Richmond,
1925](https://journals.sagepub.com/doi/abs/10.3181/00379727-22-110)). Gameplay
decides the rest.

| cell | what sleep does |
|---|---|
| **yours, by hand** | **the hand is ignored**: no steer, no push, no dash, no hold (row 7). **The tail beats on its own**, as every swimming body's does (`automation.md` row 37), so you swim on blind along your heading. **Your senses go quiet**: the organs' readings and dread stop reaching the membrane, while the beat and a bite's hit still do, and the hit wakes you. A new press takes nothing back |
| **yours, on the autopilot** | its tick is skipped (`own_rules.gd`'s `step`), and the heading it held is let go, as a dart's stun lets it go. On waking it reads again |
| **a water cell** | its rules are unread (`_decide_by_rules` returns, as for a stun), it holds no heading, and its tail beats under `tails_beat`. A hit wakes it (`_feel_hit`) |

The two differ on purpose. Paralysed, you stop and feel the hunter coming.
Asleep, you swim on, blind, until its first bite wakes you.

### 6.5 More kinds later

A new kind is one more entry in `Doses.Kind`, one more float in every body's
loads, its own tau, and its effect wired where the body acts. The owner's
*"specialized venoms"* and *"etc."* land there: a blinding one (senses only), a
weakening one (bite strength), one that stops mending without harming. None is
designed here.

---

## 7. Venom and poison: how a dose arrives

### 7.1 The deliveries

| form | where it sits | when | who takes stacks | how many |
|---|---|---|---|---|
| **venom** | the front | a bite its body lands (damage > 0, a body too big to swallow) | **the body it bit** | `VENOM_STACKS_BY_TIER[copies]` |
| **venom** | a side or the stern | a bite landing on its body within `VENOM_ARC_DEG / 2` of its slot's bearing | **the biter** | `VENOM_STACKS_BY_TIER[copies]` |
| **poison** | inside | a bite landing anywhere on its body | **the biter** | `POISON_STACKS_BY_TIER[copies]` |
| **poison** | inside | its body is swallowed | **the swallower** | `SWALLOW_STACKS_BY_TIER[copies]` |

The stacks are of the form's strain's kind. Phase 1 has one: harm.

- **A swallowed body is eaten** (row 5): it dies, as anyone swallowed dies, and
  feeds what ate it. The swallower takes the dose **before** the death is told.
  That is the order every contact keeps: nothing touches the field after a
  death's signal (`food.gd`'s `_step_contacts` note).
- **Venom does nothing on a swallow**: what it would poison is already dead, and
  what swallows a venom carrier meets its poison or nothing.
- **Armour does not stop venom.** `pellicle` divides a bite's damage, and the
  stacks ride in whole, so venom is the answer to a thick skin. Real: toxicysts
  penetrate what they hit ([Litostomatea](https://en.wikipedia.org/wiki/Litostomatea)).
- **A body with several forms delivers each.** A cell with venom on its stern
  and poison inside gives a mouth chewing its stern both.
- **Every cell alike**: a player and a water cell, in either role, take the same
  stacks from the same contact (check 6).

### 7.2 What goes

| today | becomes |
|---|---|
| `VENOM_BITE_BACK_BY_TIER`, `venom_back()` | stacks of harm in the biter: poison's from anywhere, venom's from its side |
| a swallower of a venomous **player** dies; a venomous **water** cell is swallowed safely | **every** poisonous body, swallowed, poisons its swallower; the swallowed body is eaten |
| the player spat out alive: `VENOM_COST_BY_TIER`, `venom_cost`, `_on_stung`, the `STUNG` contact | gone. `Contact.STUNG` keeps its number and is never sent, so `Wire.RULES`, which fingerprints `food.Contact`, does not move |

Every place in `food.gd` where a bite or a swallow is resolved changes, in the
same shape. Each bite already measures where it lands on its target
(`_flank_theta`); a signed `_bite_bearing(target_heading, target_pos,
mouth_pos)` gives the side, and `_flank_theta` becomes its `absf`. For the cell
on this device the signed bearing is `_cell.bearing_to(at)`, already there.

| function | today's venom | becomes |
|---|---|---|
| `_chew` (a water mouth on a water body) | `venom_back` into the biter | the biter's front venom into the bitten; the bitten's poison, and its side venom if the bite is on that side, into the biter |
| `_bitten_by` (a water mouth on a player) | `venom_back` into the mouth | the same, with the player as the bitten |
| `_bite_from` (a player's mouth on a water body) | `venom_back` into the player | the same, with the player as the biter |
| `_chewed_by_friend`, `_chew_friend` | `venom_back` | the same, between players |
| `_contacts_with`, its mouth on a player that fits | `venom_cost >= 0`: STUNG, and the mouth dies | the player is swallowed as anyone is; the mouth takes the player's poison |
| `_contacts_with`, a player's mouth on a body that fits | eaten safely | eaten, and the player takes its poison |
| `_mouth_on`, `_mouth_on_drop` (water swallows water) | eaten safely | eaten, and the eater takes its poison |
| `_players_meet` | the swallowed friend survives, the swallower dies | eaten, and the swallower takes the poison |

**What a body delivers is read once, when its body changes, not at every bite.**

- `_refresh_body` gives a water body four values: `venom_bite` (the stacks its
  bites leave, from a front venom), `venom_side` (a side venom's bearing and
  stacks, or none), `poison_bite` and `poison_swallow`.
- `_derive_person` gives a person the same, with the venom's slot read from
  their worn order, as their dart's is.
- `normal_mode.gd` hands the field this cell's, where it sets `venom_cost` today.

### 7.3 Why the swallow kills the poisonous body (row 5, answered)

- **It is real.** Chemically defended ciliates discharge their toxins at an
  attacker, and predators that do eat them *"are not able to reproduce,
  suggesting the presence of the post-ingestion toxicity"*
  ([Predator-Prey Interactions in Ciliated Protists](https://www.intechopen.com/chapters/62301)).
  The prey is eaten, and the eater pays later.
- **It is one rule for every cell.** It closes the water's last exception
  without opening another.
- **It keeps the drop from filling with one gene.** If a poisonous cell survived
  every swallow, poison would protect its carrier from every mouth big enough to
  swallow it, and nothing in the water would be selected against it.
- **What the player loses**, said plainly: carrying poison no longer survives a
  swallow. In exchange, what eats you probably dies of it, every chewer pays for
  every bite, and the same gene outside can guard your stern.

---

## 8. Strains: where a variant comes from (phase 3 on)

### 8.1 What a toxin does is the gene's own (row 6, answered)

A toxin is of one strain, corrosive, paralysing or sleeping (row 2), and the
strain is part of the form. It travels as the form does:

- **you get a strain by eating a cell that carries it**: the meal's gene is its
  dominant form, strain and all, as every meal's gene is;
- **your daughters inherit it**, with the slot and the copies;
- **a division's mutation can change it**: a drift that brings the toxin in
  draws its strain by a die, as it draws its place for a water cell;
- **the place still decides the delivery**: a paralysing toxin inside is
  paralysing poison; outside it is paralysing venom, at the front or on a side.

So a strain is to the toxin what an allele is to a gene, and that is the realism
behind it. Several haptorid species carry *"two types of toxicysts with varying
sizes and structures"*, and the genes that likely make their toxins (PKS, LAAO)
have been duplicated many times over in that group ([Li et al., BMC Biology
2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11077807/)). Toxicysts paralyse,
kill and begin digesting what they hit
([Litostomatea](https://en.wikipedia.org/wiki/Litostomatea)). Real toxins are
named by what they do to whatever takes them: shellfish poisoning comes as
*paralytic*, *amnesic* and other kinds.

**It stays readable**, because the strain is a property of a slot the player
already reads: its colour and bead on the slot and the body, and its name on
the gene's line (`dna-slots-ux.md` §2.5, §3.6).

### 8.2 The inside holds one poison

`INSIDE_SLOTS` stays one through phases 3 and 4: **one poison inside, of the kind
you choose to keep there.** Row 4's *"one poison, of each kind"* is a cap, not a
promise of room. Placing a second kind of poison writes over the first, with the
screen's two taps. Venoms of different kinds can each take an outside slot. If
one inside slot feels too tight once strains exist, the lever is
`INSIDE_SLOTS` (§21).

### 8.3 How strains are named in code

Each strain is two more forms, one per place. Their names are permanent once
shipped, since saves and the wire keep them. Proposed, all `a-z` and within the
wire's 16 bytes:

| strain (`Doses.Kind`) | outside form (venom) | inside form (poison) |
|---|---|---|
| harm, corrosive (phase 1) | `toxicyst` | `veneneux` |
| paralysis, paralysing (phase 3) | `paracyst` | `paraneux` |
| sleep, sleeping (phase 4) | `hypnocyst` | `hypnoneux` |

The names are code only. On screen every one shows the gene's name (`toxicyst`),
the place's word (`venom`, `poison`) and, from phase 3, the strain's (row 2).

**The toxin counts as one gene wherever the water counts genes.** Drift, a
peer's draw and the floor all draw *genes*. The toxin is drawn as often as
`veneneux` is today; then a die picks its strain and a coin its place. So the
strains share today's toxin, and do not triple it.

---

## 9. The water

- **Every water cell has an inside**, as every cell does (*"all cells follow the
  same rules"*). Its poison sits there, by `default_order`, and no longer takes an
  arc (§5.7).
- **Peers draw the toxin as they draw `veneneux` today**: weight 2 in
  `GENE_WEIGHTS`, under `veneneux`'s name. Once drawn, a coin decides its place,
  and from phase 3 a die its strain. So half the drop's toxins are venom, and a
  peer's venom rides on its bite (`default_order`). The coin is a starting
  value: the gene is one gene, and its two places are equal.
  - **A peer's poison does not use outside room**, so `_draw_living`'s loop fills
    the outside to its capacity as it does today.
  - The draw changes from today's only for a peer that draws the toxin.
- **How common that is**: at the last census of `DEV_LINES` the hunters' mean
  worn `veneneux` is 0.03 to 0.11 a body, so a few hunters in a hundred carry it.
  That share is now split between venom and poison.
- **Drifters carry neither form** (row 13, extended). `Drop.VENOM` becomes
  `Drop.TOXIN`, the variety, and `drifter_genes` and `take_drifter_gene` pass over
  every form of it. The drop's defenceless food stays harmless to eat, and a
  mouthless drifter's venom would bite nothing anyway.
- **The floor counts the toxin as one gene** (`_count_genes` counts a form under
  its variety) and keeps it at `GENE_FLOOR` carriers, and from phase 3 each
  strain. A drop short of it gives it to the next peer, its place by a coin
  (`give_venom` becomes `give_toxin`). Outside, it takes a spare gene's slot as
  `give_venom` does today. One form is enough for the player, who converts it by
  placing; each strain must stay in the drop, because a player can change a
  place but never a strain.
- **Doses work on every body.**
  - A hunter whose venom paralyses will stop its prey, then take it.
  - A poisonous cell's chewer weakens.
  - A mouth that swallows a poisonous cell may die of it some seconds later.
- **What evolves is unmeasured.** Venom helps its carrier eat, which births
  reward, so it may spread. Poison and side venom help their line only by hurting
  what attacks it.
  - The nearest measurement is `ocean.md` §5.6's: with a swallow death for every
    mouth, pack 1's prototype lost 0.8 to 1.1 water cells a minute to it at a
    newborn's composition, and 3.6 to 5.2 at a sighted player's.
  - The census's `genes` count and `worn` columns gain the new form, which is
    where the dev app shows it.

---

## 10. What a player must see

In broad strokes; how it looks is the ux-designer's. Every item works in both
views, on both shapes, and in the replay.

### 10.1 The list

**On the pause screen:**

1. **The inside and the outside.** The inside slot, as a slot of the body like
   any other, and the seven outside slots round it. The words `outside` and
   `inside` (`dehors`, `dedans`) appear in the one line that teaches the rule,
   for instance `tap a slot · venom outside, poison inside`.
2. **What a toxin becomes before it lands.** Armed over a slot, or dragged over
   one, the slot shows the form it would make: `venom` outside, `poison` inside.
   **For venom, also where it works**: through your bite at the front, or
   guarding that side. When the second tap would **add a copy to a form you carry
   elsewhere**, the screen says so and shows where (§5.2).
3. **Refusals say why, while the finger is down**: a move that would make a form
   you carry (`ACT_REFUSE`); a gene that faces out, on the inside slot; a copy to
   a form at three (`ACT_RAISE_FULL`). Nothing on this screen refuses silently
   (`moving-a-gene.md` §3.7).
4. **The tray**: a waiting toxin is `toxin`, and says that where it goes decides
   venom or poison (and, from phase 3, its strain).
5. **The quick placement**: each free slot blooms as the form it would make, the
   inside included, and a free slot whose form you carry does not bloom
   (`dna-body.md` §8).
6. **The strain** (phase 3), on the slot itself: colour, and a shape that
   survives greyscale.
7. **The gene's line and its numbers**, per form, and for venom per front or
   side.
8. **The choosing screen**: each daughter's forms, her inside included, and a
   shift that moved a venom between front and side.

**In the water:**

9. **The forms on a body**, so a full-vision player can learn which cells are
   which:
   - venom at the front, on the lips;
   - venom on a side, standing out of that side;
   - poison inside the body.
10. **Every load on every body**: a body carrying harm, a paralysed one and a
    sleeping one, each told apart from the others and from a body that is only
    wounded. Your own as well.
11. **Your own loads in point of view**, where there is no map:
    - **harm** as a hurt that goes on, not a bite at a bearing, and not hunger;
    - **paralysis** as a body that will not answer, so a dead control is not
      taken for a broken one;
    - **sleep** as the senses fading out, and that a bite will wake you.
12. **A venom firing**: your front venom when your bite lands, your side venom
    when a mouth bites that side, your poison when a biter or a swallower takes
    it.
13. **The drawn controls** (`stick`, `pads`) look dead while you are paralysed or
    asleep.
14. **The death**: quiet, *poisoned*; the replay shows whose dose it was; a
    friend's is drawn as one that starved.

### 10.2 What the screen spec has to redo

`dna-slots-ux.md` was written to the first draft's two places, both on the
skin. Its look for doses in the water and in point of view (§4, §5), its death
(§6), its words (§1) and its strain marks (§2.5) all stand. What has to change:

| | what to redo |
|---|---|
| **the inside slot on the figure** | where it sits (the body is drawn in the middle cell of the ring, at `FIGURE_R` 60); its size and its touch target; its empty, ghost, armed, occupied and refused states; its place in focus, `Tab` and the arrows (`SLOT_NEIGHBOUR`); a drag to and from it; a tray drop on it. `SLOT_SEAT` gains an eighth seat |
| **the places** | the mouth's arc and threads (`dna-slots-ux.md` §3.1) gave way to outside and inside. The ghosts: every empty outside slot `venom`, the inside slot `poison`. `ACT_ARM_FORMS` reworded with the owner's words |
| **venom on a side** | the fangs on the lips stand for venom at the front (§2.2 there). A venom on a side is drawn standing out of that side's arc, and flares there when a biter takes it. The armed or read slot lights the arc it guards. `EXPLAINS_SIDE`, and its numbers line |
| **poison** | granules inside the body, with no pigment and haze at an arc, since it has none |
| **a gene that faces out** | refused on the inside slot, in words |
| **the quick placement** | the inside needs a target in a gesture that today cancels when the finger is let go inside the body |
| **the choosing screen** | an inside locus on each daughter's strand |
| **row 9** | answered *mouth / body*, now `outside / inside` in the owner's words, `dehors / dedans` in French |

**For phase 5, not phase 1** (`feeding.md` §5.5): a cell whose skin eats, in
both views; an engulf from the side, felt in point of view; what fits a skin;
the line before you write over your mouth; the figure and the strand without a
mouth. And, only if row 11 asks for it, the mouthless newborn's first minute.

---

## 11. The instincts

**No form declares a sense or an action.** So the vocabulary does not change,
the water's rule changes draw from what they drew (`behaviour.md` §6.3), and no
library needs touching. Venom and poison act on their own, as the dart and the
mouth do.

- **Paralysis** leaves the instincts reading and deciding; their turns, pushes
  and dashes are done at `still` × strength.
- **Sleep** stops them: no tick and no held heading, until a hit.
- **Hooks, not built.** `DECLARES` is keyed by name, so a form can bring a part
  of its own with no new mechanism. A sense of one's own loads (*"I am
  poisoned"*) would be a `body` input. Either would change the water's vocabulary
  and so its evolution, which is a design of its own.

---

## 12. Saves and migration

**`FORMAT` stays 1, and the genome's shape in a save does not change.** The
inside has no layout to keep (§2.2): an inside form is a name in `dna` and in
`body`, absent from `order` and `worn`, exactly as a save already keeps any gene.

- **Every kept world, every kept drop and the server's room** loads *converted*.
  `DropSave.rules()` fingerprints `GENE_ORDER` and every `_BY_TIER` table of
  `cell.gd`, and both change. That path exists (`ocean.md` §9.4): it re-derives
  every body from its genome and logs it. A water cell's `veneneux` is now
  poison inside, which is what it always meant, and its arc is free.
- **Your cell**: `set_state` reaches `express`, which puts every form in its
  place (§5.6).
  - **Your `veneneux`, whichever slot you had put it in, moves inside**, in your
    DNA and on your body. Its old slot is left empty. You keep the poison you
    had, and gain an arc.
  - Logged: `[genome] veneneux moved inside from slot 3`.
  - A waiting `veneneux` keeps waiting, as `toxin`.
- **New optional keys, checked when present**, in `drop_save.gd`'s style for
  pack 2's and pack 3's:
  - `cell.loads`, this cell's three loads, so a dose survives closing the app
    mid-fight (`ocean.md` row 17);
  - three columns in `drop.bodies`, `harm`, `paralysis` and `sleep`, one entry a
    body, as `PackedFloat64Array`, because they wear down like the clocks kept
    there.

  Absent means none. An older build ignores them and loads the rest, as it does
  pack 2's columns.
- **A save older than the rename** (`8587c1b`, 2026-10-01) may hold
  `toxicyst`, which that rename left an unknown, inert gene. It now loads as the
  venom form, in its slot. Only the dev app and the dev server can have one:
  keeping a cell came after the last release, so players have no saves yet.
- **The library** (`user://library.save`) is unchanged: no rule names a toxin.
- **The replay** is in memory only (`recorder.gd`), so there is nothing to
  migrate.

---

## 13. The replay

What is new in the water is recorded, so it can be drawn:

- **this cell's three loads**: three floats in the player's block;
- **each kept body's three loads** in one float, packed as `h + 256·p + 65536·s`,
  each `round(stacks × 4)` clamped to 0..255. A float32 holds 24 bits exactly.

That is 51 floats a frame over today's 472, about 12 KB a second and 0.7 MB over
the minute, in RAM.

- **Forms and the inside** are names in the genomes the replay already records
  per body version, and in this cell's recorded genome, so nothing new is kept
  for them.
- **A side venom firing** is the biter taking a dose, recorded with its loads,
  and the hit the bite already records.

The `what you felt` pane draws your own loads as point of view felt them, and
the water's are drawn on the bodies (`dna-slots-ux.md` §6).

---

## 14. The shared pond, the referee and the wire

### 14.1 Who decides

**The host decides every dose**, as it decides every contact (`shared-pond.md`
§1.1). It applies stacks to its own cell, to its water and to each guest's
person, and it wears the person's in `_step_person`.

**A guest's device obeys its own loads** as the host sends them, so its cell
slows, sleeps and hurts on its own screen. It never applies a stack itself and
never dies of its own count.

| | host (a phone) | guest | dedicated server |
|---|---|---|---|
| doses from contacts | decides all of them, its own cell's included | hears its loads in POND | decides all of them, for both guests |
| the effects on its own cell | `cell.gd`, from its loads | `cell.gd`, from the loads POND says, worn between snapshots | no cell |
| a death by poison | its field finds it; quiet | the host's KILLED `POISONED`; quiet | its field, for each guest |
| its friend's death by poison | drawn as `Gone.STARVED` | the same | -- |

The guest's own DIED `POISONED` then reaches a host that has already taken that
body out, and `judge_died` drops it unread, as it drops every death the host
made itself (`referee.gd`: *"a death the host made itself, said again"*).

### 14.2 Phase 1: `PROTOCOL` 7, `Wire.RULES` unchanged

- **The POND header's spare byte becomes three**: `kind | seq(u32) |
  your_wound(u8) | count(u8) | your_harm(u8) | your_paralysis(u8) |
  your_sleep(u8)`.
  - Each is `round(stacks × 4)`, clamped to 255: 63.75 stacks, against a largest
    swallow dose of 48.
  - `POND_HEADER` goes 8 → 10, and `POND_MAX` 1,179 → 1,181, still one datagram
    under ENet's 1,392.
  - Phase 1 writes harm; the other two are written as zero and ignored until
    their phases.
- **A POND body's flags gain three bits**: 3 `HARMED`, 4 `PARALYSED`, 5 `ASLEEP`,
  set for a load past `DOSE_GONE`, or a body asleep. A guest draws the doses of
  the water and of the other player from them. Phase 1 writes bit 3.
- **A genome may hold nine names**: seven outside, one inside, and the gift's
  case, where a gift is worn over an organ still worn. `GENES_MAX` goes 8 → 9, and
  every bound derived from it follows (net-hardening A.3):

  | bound | before | after |
  |---|---|---|
  | `TIERS_MAX` | 145 | 163 |
  | `PERSON_MAX`, and with it `GUEST_OTHER_MAX` (the oversize cut) | 272 | 290 |
  | `GENOME_MAX` | 156 | 174 |
  | `SISTER_MAX`, and with it `GUEST_FRAME_MAX` | 1,342 | 1,378 |

  `ORDER_MAX` stays 7, because the order PERSON carries is the worn layout,
  outside only. `net_probe` holds `GENES_MAX` to `SLOT_MAX + INSIDE_SLOTS + 1`.
- **`toxicyst` crosses by name** in PERSON, GENOME, SISTER and an ATE. The inside
  needs no field: an inside form is inside by its name.
- **`PROTOCOL` moves 6 → 7**, for three reasons, each enough alone:
  - `wire.gd`'s own rule bumps it for a change to the bite tables, and this one
    replaces `VENOM_BITE_BACK_BY_TIER`, `VENOM_COST_BY_TIER` and `venom_back`;
  - the POND header and flags change meaning;
  - a 6 refuses a genome of nine names whole.

  A 6 is refused at HELLO by name, as 1 to 5 are, with the version sentence.
- **`Wire.RULES` stays `46913eab…`.** The referee judges a guest's size, path,
  heading, arrivals, sister, body and death, and harm changes none of them: the
  host owns the guest's wound and decides its death.
  - Its slot rule, *every slot names a gene the body wears, once*, holds as it
    is. A form is a name, it appears once, and an inside form is in no slot.
  - `food.Cause` keeps `POISONED`, and `food.Contact` keeps `STUNG`'s number.
    Both enums are what `_rules_text` fingerprints.
  - `net_probe --referee-only` passes unchanged.
- **The dedicated server updates last**, as always (`CLAUDE.md`). Until it
  restarts on 7, phones on 7 and the server on 6 refuse each other with the
  version sentence.

### 14.3 Phases 3 and 4: the referee judges a held guest

**A guest paralysed or put to sleep by the host's water must stop on its own
client**, and it does: POND tells it its loads every 50 ms, and its `cell.gd`
applies them (§6.3, §6.4). **The referee must judge its motion knowing that**,
so that a guest that ignores it (an old build, a modified one, a desync) cannot
outrun the host's water.

- **`pond.gd` tells the referee each frame**, before `claim()`:
  `referee.status(now, still, asleep)`, from the host's own loads for that
  person.
- **What changes**: while the status holds, the four budgets that follow the
  claim refill more slowly.
  - `move` and `_follow` refill at `max(MOVE_RATE × still, STILL_MOVE)` while
    paralysed, and at `SLEEP_MOVE` while asleep: the lower of the two if both.
  - `turn` and `_swing` refill at `max(TURN_RATE × still, STILL_TURN)` while
    paralysed, and at `SLEEP_TURN` while asleep.
  - **The banks are not touched.** They are what an honest guest coasts on, and
    what covers the moment before it hears (below).
  - A claim past the slower refill fouls at the weights it has today: 2 points,
    at most once every 0.5 s. The host's place for the guest follows the claim
    only as fast as these allow.
- **`STATUS_GRACE`, 1.0 s.** A status is judged from this long after the host
  applied it.
  - An honest guest learns of it in the next POND, within 50 ms.
  - Its link may spike: net-hardening's harnesses model spikes of 150 to 250 ms
    (`net-hardening.md` B.3), and its frames come back over the same link.
  - One second covers both trips and a lost snapshot. A status that ends is let
    go at once.
- **The new limits** (§15), each with its reason:
  - `STILL_MOVE` 110 u/s and `STILL_TURN` 0.2 rad/s are for what still moves a
    stopped body: a shove, and the wander;
  - `SLEEP_MOVE` 400 u/s is over the fastest tail alone. A tier-3 tail's impulses
    peak at 323 u/s against the drag, by `cell.gd`'s own tables, with no push and
    no dash;
  - `SLEEP_TURN` 0.35 rad/s is over the wander (0.13) plus the kicks a tier-3
    tail gives its heading (0.16 at most every 1.2 s, so 0.13 a second).
- **`Wire.RULES` moves in phase 3, and again in phase 4.** `_rules_text` gains
  the referee's new limits and the values it derives them from:
  `cell.PARALYSIS_FULL`, `cell.SLEEP_AT`, `cell.DOSE_TAU_BY_KIND` and
  `cell.DOSE_SIZE`. A host and a guest that disagree on how still a load makes a
  body would foul an honest guest. **`PROTOCOL` moves with it each time**, 7 → 8
  and 8 → 9, by `CLAUDE.md`'s rule. Those numbers assume the two land in that
  order; phase 5 takes a number of its own (§14.4), so each phase takes the next
  one when it merges.
- **The false-positive runs are repeated** with an honest guest being paralysed
  and put to sleep (`net-hardening.md` B.3: the `pond` and `server` sections,
  `net_lag --link=rough`, the relay). The bar stays what it is: **0 fouls**.

### 14.4 Phase 5 and the starting cell (`feeding.md`)

- **Phase 5, a skin that eats: `PROTOCOL` moves, `Wire.RULES` does not.** The
  host decides every contact, so mixed builds would feed a mouthless guest by two
  rules. And POND body flags gain bit 6, `CARRIED`, so a guest's mirror stops
  guessing a drifter from its missing mouth. The referee judges no contact rule,
  and no cause or contact is added (`feeding.md` §7).
- **A new cell keeps today's kit** (row 11), so `genome.BORN` and
  `FIRST_SENSES`, both in `_rules_text`, do not move. If the owner chooses the
  mouthless start, `Wire.RULES` moves with `BORN_BODY`, and `PROTOCOL` with it,
  sharing phase 5's bump if they land together (`feeding.md` §3.3).

---

## 15. Starting values

Balance waits for players. Each value has a reason and what to watch for; none
is put to the owner. All are in `cell.gd` unless named.

| value | start | reason | watch for |
|---|---|---|---|
| `DOSE_SIZE` | 26 (`BASE_RADIUS`) | a stack is quoted for a born cell | -- |
| `HARM_PER_STACK` | 0.05 | about 70 % of a born mouth's head-on bite (0.07). A born mouth's bite on an r40 stern is 0.077 (`edibility.md` §1.2); one copy of venom adds 0.021 to it, about 27 % | venom that does nothing you can see, or that wins every fight |
| `DOSE_TAU_BY_KIND` | harm 6 s, paralysis 4 s, sleep 8 s | harm lasts about a fight (a stern kill takes 13 s, `edibility.md` §1.2). Paralysis is short, so it opens a window and does not lock you out. Sleep is longer, because a bite ends it | a fight where everyone has gone before the dose shows; a paralysis that feels like a stun |
| `DOSE_GONE` | 0.2 stacks | one stack clears in 6 × ln 5 = 9.7 s, so a light dose stops your mending for about ten seconds | a body that never heals after one scratch |
| `VENOM_STACKS_BY_TIER` | 0, 1, 2, 3 a bite | one stack a copy, which the line can say as such. Three copies add 82 % to that same born bite on an r40 stern, over the next seconds | a three-copy front venom deciding every fight |
| `VENOM_ARC_DEG` | 110 | the dart's own arc (`DART_ARC_DEG`), so the two weapons that guard a side reach as far round it | a side venom that never fires, or one that guards everything |
| `VENOM_SIDES` | true | a venom on a side stings (§2.3); false makes it inert, the fallback | nobody ever puts venom on a side |
| `POISON_STACKS_BY_TIER` | 0, 1, 2, 3 a bite | the same price for biting a poisonous body, in place of today's 35, 55 and 80 % bite-back. An r34 biter with a two-copy mouth, chewing an r40 body with two copies of poison, takes 0.058 a bite: a third to two thirds of its own bite, by where it bites | chewing a poisonous cell is suicide, or free |
| `SWALLOW_STACKS_BY_TIER` | 0, 16, 32, 48 | one copy takes 0.8 of a born swallower, 0.47 of an r34 and 0.34 of an r40. Three copies kill anything up to r40 (1.01), an r34 in about 7.5 s | a poison nobody swallows twice, or one nobody notices |
| dilution | `(26 / r)²` | a dose per unit of body (§6.1) | big cells shrugging off everything |
| `PARALYSIS_FULL` (phase 3) | 4 stacks, diluted | a tier-3 bite slows a born cell by 75 %, and two stop it; an r40 body is slowed by 32 % a bite | a hunter that stops you and eats you every time; paralysis too weak to notice |
| `SLEEP_AT` (phase 4) | 2 stacks, diluted | a two-copy bite puts a born cell to sleep; no single bite sleeps an r40 body (3 × 0.42 = 1.3) | sleep that never happens to anything big, or happens to everything |
| peers' toxin | weight 2 (`veneneux`'s), place by a coin, strain by a die | one gene, as common as today's | a drop full of venom, or with none left |
| `STATUS_GRACE`, `STILL_MOVE`, `STILL_TURN`, `SLEEP_MOVE`, `SLEEP_TURN` (`referee.gd`) | 1.0 s, 110 u/s, 0.2 rad/s, 400 u/s, 0.35 rad/s | §14.3 | a fouled honest guest: `enforce_referee` is the switch (`CLAUDE.md`) |

**The worked numbers are arithmetic on these constants**, not measurements.

`INSIDE_SLOTS` (1, `genome.gd`) is structure, not balance: §2.2 gives its
reasons and §21 what would move it.

---

## 16. Cost

Reasoned from the code. **Unmeasured.**

- **Every frame, every body with a load**: one `exp` per kind and a few
  multiplies. A body with no load costs one test. In the drop most bodies carry
  nothing, and at `ocean.md` §4.4's assumed phone factor of six it is under a
  microsecond a body.
- **Every bite and swallow**: a few reads of values made once when the body
  changed (`_refresh_body`, `_derive_person`), and for a side venom one angle
  difference. **Nothing is added per pair of cells**: contacts are already found,
  and this only acts on them.
- **The inside** is a name in a map: no pass, no layout, nothing per frame.
- **Drawing**: a mark per body that carries a load, which few do at once.
- **The wire**: 2 bytes a snapshot, and a genome up to 18 bytes longer.
  **The replay**: 51 floats a frame (§13).
- **Where it shows**: the dev app's frame readout, the `water` and `dropped`
  rows, in a drop where venom has spread.

---

## 17. Content or binary

**Content only, every phase**: GDScript, scenes and the two catalogs.

- No `project.godot` change, and no new input action: the effects act through
  code that already reads the hand.
- No plugin. **`binary_version` does not move.**
- The one shader uniform the screen spec adds (phase 4's sleep veil) is a
  `.gdshader`, which rides in the pack.

---

## 18. Generic mechanics, names at the edges

| file | knows | does not know |
|---|---|---|
| `game/mechanics/doses.gd` **new** | loads of kinds; their wear in closed form, dilution, still, asleep, wake, mends | a gene, a cell, a toxin, a number of its own |
| `game/normal/genome.gd` | `INSIDE`, `INSIDE_SLOTS`, `FRONT`, `FORMS`, `NAMES`, and the rules a place, a form and a variety obey: placing, lapsing, moving, mutating, expressing | what a form does |
| `game/normal/cell.gd` | the toxin's tables and the dose constants (§15); this cell's loads and what they do to its strokes, turns, push, dash and hold | how a load wears |
| `game/normal/food.gd` | where a dose is delivered, every body's loads and their effects on water bodies and persons, deaths by poison | the toxin's names, beyond reading its tables |
| `game/normal/drop.gd` | `TOXIN`: the variety drifters never carry and the floor gives back | the forms' places |
| `game/net/referee.gd` | a held guest's slower refill (phases 3, 4) | doses, genes |
| `game/vision/cilia.gd`, `soma.gd`, `vision.gd` | how a form and a load look | the rules |

A second water, a second toxin or a second kind adds rows to the tables and
touches none of the arithmetic.

---

## 19. Hooks for later

- **More genes inside.**
  - `vacuole`, `crista` and `plastid` are organelles a real cell keeps inside;
    letting them in is one row each in `FORMS` (an inside form that does what it
    does on an arc) and more `INSIDE_SLOTS`.
  - It gives every cell room for more genes, which is why it is not this
    polish's.
- **More room inside**: `INSIDE_SLOTS`, for strains or for organelles.
- **A gene placed twice in one place** would need a slot index in the form's key.
  Not wanted now (row 4).
- **More kinds of dose**: §6.5.
- **More genes with direction-dependent forms**: a trichocyst at the front as a
  pexicyst, which holds prey, or a palp at the front as taste. One row each in
  `FORMS`, with the effect wired.
- **A sense of one's own loads**, for instincts (§11).
- **The dart's stun is already a status** (`DART_STUN`: rules unread, tail
  still, for 5 s). It could become a load of paralysis and sleep, delivered by
  the same mechanism.
- **`dna-body.md` §12, item 1**: pinning the born three to their slots would make
  the front cleaner. Not decided here.
- **Feeding** (`feeding.md` §4.2): a mouth on another arc, as *Paramecium*'s
  oral groove is on its side; tentacles, which feed and dose through an arc; a
  feeding current. Each is a later pack's. The side sting's geometry (§2.3) is
  the contact a tentacle would need.

---

## 20. Build plan

### 20.1 Files

**Phase 1:**

| file | change |
|---|---|
| `game/mechanics/doses.gd` | **new** (§6.1) |
| `game/normal/genome.gd` | `INSIDE`, `INSIDE_SLOTS`, `place_of`, `FRONT`, `FORMS`, `NAMES` and their statics; `inside_layout()`, `body_inside()`, `placing()`, `can_move()`; `toxicyst` appended to `GENE_ORDER`; `integrate`, `_process`, `_lapse`, `_settle`, `place` and `move` across the inside; `express`'s putting in place; `_sync_order` seating only outside forms; `integrate_into`'s room by place; `mutated`'s drift (§5) |
| `game/normal/cell.gd` | the §15 tables; `VENOM_BITE_BACK_BY_TIER`, `VENOM_COST_BY_TIER` and `venom_back` removed; `loads`, worn in `_process` with the wound; `body_state` and `restore_body` keep them |
| `game/normal/food.gd` | `Body.loads`, `Body.dosed_by`, and the four delivery values from `_refresh_body` and `_derive_person`; `_bite_bearing`; §7.2's table of functions; `_dose_step` and the death checks where §6.2 puts them; `_dosed_by`; `venom_cost` removed; `loads()` for the views; the drop's draws, floor and census by variety (§9); the optional columns in `drop_state` and `load_drop` |
| `game/normal/drop.gd` | `VENOM` → `TOXIN`; `drifter_genes` and `take_drifter_gene` over every form; `give_venom` → `give_toxin`, with its coin |
| `game/normal/drop_save.gd` | `cell.loads`, and the `drop.bodies` columns `harm`, `paralysis` and `sleep`, checked when present (§12) |
| `game/normal/normal_mode.gd` | `_on_stung` and `venom_cost` removed; this cell's delivery values handed to the field; `_die(loud, bearing, cause)` and the quiet poisoned death; `_on_friend_died` taking `POISONED` as `Gone.STARVED`; the words (`WORDS`, `EXPLAINS`, `EXPLAINS_SIDE`, `TOXIN_WORD`, the `ACT_` lines); `name_of` on the gene's line; the minimum honest screen (§20.2) |
| `game/normal/gene_stats.gd` | the rows of §3.3 |
| `game/vision/cilia.gd` | `default_order` by place (§5.7); `arc_for_slot` never asked for an inside slot; and the ux-designer's look |
| `game/vision/vision.gd`, `game/perception/soma.gd` | the ux-designer's look |
| `game/net/wire.gd` | `PROTOCOL := 7`, with a paragraph in the style of 4 to 6; the POND header's three loads and three flags; `GENES_MAX := 9` and the bounds after it |
| `game/net/pond.gd`, `net_session.gd` | `apply_pond` takes the loads |
| `game/replay/recorder.gd`, `replay.gd`, `panes.gd` | §13 |
| `tools/drive.gd` | `--dose=<kind>:<stacks>[:hunter\|<slot>]` poses a load: on this cell, unless the posed hunter or a body's slot is named. It is held at that value until `--dose-at=` lets it wear, so frames hold still. `--drifter-venom=` is read as `--drifter-toxin=` as well |
| `tools/forage_probe.gd` | `--avoid-venom` passes over a body wearing any toxin form; the old name is kept |
| `.github/workflows/ci.yml` | the pinned hash in "Check an empty library changes nothing", re-pinned with its reason (§20.3, check 13) |

**Every phase:**

| file | change |
|---|---|
| `game/i18n/biogenic.pot`, `fr.po` | every new word through `tr()` |
| `tools/drop_probe.gd`, `levels_probe.gd`, `net_probe.gd`, `net_fuzz.gd` (with its corpus), `eco_probe.gd` | §20.3 |

**Phase 2:**

| file | change |
|---|---|
| `normal_mode.gd`, `normal_mode.tscn`, `cilia.gd`, `controls.gd` | the ux-designer's screen |

**Phase 3**, the paralysis strain:

| file | change |
|---|---|
| `genome.gd`, `cell.gd`, `food.gd`, `gene_stats.gd`, `normal_mode.gd`, `cilia.gd` | `paracyst` and `paraneux`; `PARALYSIS_FULL`; `still` applied in `cell.gd` (`_fire_impulse`, the push, `_dash_now`, `turn_rate`) and in `food.gd` (`_move_ruled`, `_swim`, the dash); strains in the draws, the floor and the census. The census's `worn` columns name a gene by four letters, so they need longer names once two forms share a prefix (`para`) |
| `game/net/referee.gd`, `pond.gd`, `wire.gd`, `tools/net_probe.gd` | `status()`, the slower refills, `STATUS_GRACE`, `STILL_*`; `PROTOCOL := 8`; `Wire.RULES` updated |

**Phase 4**, the sleep strain:

| file | change |
|---|---|
| the same files, and `own_rules.gd` | `hypnocyst` and `hypnoneux`; `SLEEP_AT`; the hand ignored, the tick skipped, the senses not posted, the wake on a hit; `SLEEP_*`; `PROTOCOL := 9`; `Wire.RULES` updated |

**Phase 5**, a skin that eats, and **5b**, the mouthless start: `feeding.md` §9,
its files, checks and frames.

**Nothing** in `addons/launcher/` or `ci/`. **No `project.godot` change, and no
`binary_version` bump.**

### 20.2 Phases

Each phase is one pull request into `dev`, played on the dev app before the next
begins. **Phases 1 and 2 are the polish before the release. Phases 3 and 4 come
after it** (row 8), **and so does `feeding.md`'s phase 5** (row 14). Phases 3, 4
and 5 do not depend on one another.

| phase | contents | what the owner can try |
|---|---|---|
| **1. Venom and poison, outside and inside** | everything mechanical, §2 to §9 and §12 to §14.2; **the minimum honest screen** and **the look in the water** below | eat a poisonous cell. Put it inside, and let a hunter chew you and weaken. Move it to your front and bite something big, then let go and watch it go on tearing. Put it on your stern and turn your back on a chewer. Carry both. Swallow a poisonous cell and pay for it |
| **2. The screen** | the ux-designer's pause screen, tray, quick placement and choosing screen for the inside and the outside (§10.1, items 1 to 8) | read where a toxin goes before placing it; drag it in and out of your body |
| **3. Paralysing toxins** | strains (§8), the paralysis kind (§6.3), the water's paralysing hunters, the referee (§14.3), `PROTOCOL` 8 and `Wire.RULES` | get stopped by a hunter's venom; stop your prey with yours; be poisonous and watch what bit you slow down; in a pond, be paralysed by your friend's water |
| **4. Sleeping toxins** | the sleep kind (§6.4), the referee, `PROTOCOL` 9 and `Wire.RULES` | fall asleep in point of view and be woken by a bite; put prey to sleep and eat it |
| **5. A skin that eats** (`feeding.md` §5), if row 12 says yes | a body with no mouth engulfs what fits 0.58 of its radius from any side; drifters graze the same way; POND's `CARRIED` flag; `PROTOCOL` +1, `Wire.RULES` unchanged | write a gene over your mouth and divide: your daughter eats what touches her and lives on the water. Give her poison and stings, and watch what bites her pay for it |
| **5b. The mouthless start** (`feeding.md` §3.3), only if row 11 asks for it | a new cell born without a mouth, its daughters with one; `Wire.RULES` and `PROTOCOL` | a first generation that engulfs and soaks up food, and hunts from its first division |

**Phase 1 in full:**

- **The mechanics**:
  - places, the inside slot, and the toxin's two forms;
  - the meal that waits, and placing, moving and drifting that convert;
  - front venom, side venom and poison as harm on every body, the quiet death;
  - the water's forms and the floor;
  - saves and migration, the replay, and `PROTOCOL` 7.
- **The minimum honest screen**:
  - **an inside slot on the figure**, in the ux-designer's seat for it;
  - a slot armed or dragged over shows the form it would make;
  - `ACT_RAISE` when the tap adds a copy elsewhere, and a tray drop onto such a
    slot arms it rather than landing at once (`dna-body.md`'s owner's call 6
    places a drop on an empty slot at once because nothing is destroyed; this
    one would land elsewhere);
  - `ACT_RAISE_FULL`, `ACT_REFUSE` and the faces-out refusal;
  - a free slot of a carried form is not offered to the quick placement;
  - the gene's line shows `name_of` and, for venom, the front's or the side's
    sentence.
- **The look in the water**, the ux-designer's for phase 1 (`dna-slots-ux.md`
  §8), with the side venom's barbs added.

**Why the strains wait.** Row 8 answered it. Paralysis touches every body's
movement and the referee, and sleep touches perception and the instincts.
Phase 1 lays out what they need, so 3 and 4 add kinds and reshape nothing:

- three loads on every body;
- three bytes and three flags on the wire;
- the packed float in the replay;
- the strain in `FORMS`.

### 20.3 What the build checks

Each check must fail with its rule taken out. They run in `drop_probe`'s "Check
the drop" step unless named.

**Phase 1:**

1. **Forms follow their places** (headless, `genome.gd` alone).
   - Placing a waiting toxin into each outside slot writes venom, and into the
     inside writes poison.
   - A placement into a place whose form is carried adds copies there, and leaves
     the tapped slot as it was. A gene that faces out is refused inside. A lapse
     follows §5.3.
   - A move converts across inside and outside, swaps copies, and is refused on a
     collision or a gene that faces out, with `can_move` agreeing every time.
   - `express` moves an old DNA's `veneneux` from slot 3 inside, and its body's
     too.
   - **Ten thousand seeded random meals, placements, moves, lapses and mutations
     end with every form in its place, no place over its room, and no form
     twice.**
   - A genome with no toxin draws exactly what `dev` draws, mutation for mutation.
2. **The referee's slot rule holds**: every genome check 1 makes passes
   `Referee._order_fits` with its worn layout, in the same headless run
   (`referee.gd` holds no scene and preloads anywhere).
3. **The meal that waits**:
   - a meal of a carried toxin is `HELD`, not `RAISED`;
   - two meals of one variety are one sample of two copies;
   - a gene of one form is raised as today;
   - `_process` never settles a toxin on its own.
4. **A stack is worth what it says** (`levels_probe`).
   - One stack of harm takes `HARM_PER_STACK × (26 / r)²` of a body at r26, r34
     and r40, to within the cutoff.
   - A body carrying harm does not mend, and mends from the moment the harm is
     gone, within the step.
   - A drop body stepped every eighth frame and one stepped every frame end the
     same.
5. **Deaths by poison**: a wound made whole by harm is `POISONED`, with remains,
   for this cell, a water body and a person, and `died_to` is the last doser.
   This cell's is quiet (`_die(false, …, POISONED)`). In a pond it reports
   `POISONED`, and the friend is drawn as `Gone.STARVED`.
6. **Every cell alike**: the same contact, posed with the player and with a water
   cell in each role, gives the same stacks to the float. The roles are a front
   venom biting, a side venom bitten on its side and off it, a poisonous body
   bitten, and a poisonous body swallowed.
7. **Venom and poison**. This replaces check 11's *venom as today*.
   - A front venom's bite leaves `VENOM_STACKS_BY_TIER` on its target, whatever
     its `pellicle`, and nothing on a swallow.
   - A side venom leaves it on a biter within 55° of its bearing and on no other.
   - A bite on a poisonous body leaves `POISON_STACKS_BY_TIER` on the biter.
   - A swallow leaves `SWALLOW_STACKS_BY_TIER` on the swallower before the death
     is told, and the swallowed body is eaten.
   - `stung` is never emitted.
   - With `VENOM_SIDES` off, a side venom leaves nothing.
8. **The water**:
   - no drifter is ever made with either form;
   - the floor gives the toxin back through a peer, at either place;
   - `default_order` seats venom at slot 3 and leaves poison out;
   - a water cell's poison takes no outside room;
   - a peer's draw differs from `dev`'s only on a body that drew the toxin.
9. **Saves**:
   - a world kept by `dev` loads converted and plays;
   - the player's `veneneux` in slot 3 is inside, in the DNA and on the body, and
     slot 3 is empty;
   - a dosed cell and a dosed water body keep their loads through a keep and a
     load;
   - a file without the new keys loads with none.
10. **The replay** records and plays back this cell's loads and a body's packed
    loads, and a body that was dosed is drawn so.
11. **`net_probe`**:
    - `pond-field`'s venomous friend is rewritten for doses: a bite each way,
      a side sting, and a swallow each way.
    - The POND round-trips the three loads and the three flags: at 0, at the
      most the bytes say, and past it.
    - A PERSON and a SISTER of nine names round-trip, and ten are refused whole.
      The bounds of §14.2 are held to frames a writer really makes.
    - Protocols 1 to 6 are refused at HELLO by name, and so is 8.
    - **The referee section passes with `Wire.RULES` `46913eab…`.**
    - The `pond` and `server` sections end with no foul, with a guest that is
      venomous, poisonous and dosed.
    - `net_fuzz`'s corpus gains POND frames with loads, and nine-name genomes.
12. **`gene_stats`**: the numbers lines read §15's constants (`levels_probe`,
    beside the rows it pins). The dash's check stays; the venom-paid half goes
    with `_on_stung`.
13. **What moves, re-pinned with its reason**: `DEV_LINES` (the census's `genes`
    count gains one, `worn` gains a `toxi` column) and CI's empty-library hash
    (`ff34f4c6…`), because the water's draws, bites and default order changed. A
    change that moves them for any other reason is a bug.
14. **The translation catalogs**: the template is current, `fr.po` has the new
    words, and the lint passes, every new line inside its `ROOM`.
15. **Alive**, run by the build and not in CI:
    - `forage_probe` with
      `--genome=cytostome:2,cirrus:1,flagellum:1,toxicyst:2:2,veneneux:1:7`,
      seeds 1 to 4, three minutes.
    - Bites on the cell's stern leave venom in the biter, every bite on it leaves
      poison, and the stacks counted are printed.
    - The same at `toxicyst:2:3`: its own bites leave venom.
    - This checks the wiring is alive, not how well the cell does.

**Phase 2**: the ux-designer's checks and frames.

**Phase 3:**

16. **Paralysis scales every body's own movement**, to the float, at `still` 1,
    0.5 and 0:
    - this cell's strokes, push, dash and turn, by hand and by instinct;
    - a water body's pace, dash and turn.

    The wander still turns a stopped body, and a stopped body pays nothing to
    move.
17. **Strains travel with forms**: eaten, inherited, converted by place and never
    by strain; drift's die; the floor keeps each strain; the inside holds one
    poison.
18. **`net_probe`, the referee**:
    - a guest posed paralysed that keeps claiming full speed is held to the
      slower refill and fouled after `STATUS_GRACE`;
    - an honest guest paralysed mid-swim, coasting on its bank, is never fouled;
    - `_rules_text` gains §14.3's values, `PROTOCOL` is 8, and protocols 1 to 7
      are refused by name;
    - the false-positive runs are repeated (§14.3), with 0 fouls.

**Phase 4:**

19. **Sleep**:
    - at `SLEEP_AT`, this cell's hand moves nothing, its autopilot does not tick,
      and its senses post nothing to the membrane;
    - a water body reads no rules and swims on its tail;
    - a bite or a dart wakes either, and a bite strong enough puts it back to
      sleep;
    - it wears off at its tau.
20. **`net_probe`, the referee**: as check 18, for sleep. `PROTOCOL` 9.

### 20.4 Frames

Every frame runs through `tools/shot.tscn` driving `tools/drive.tscn` at
`--fixed-fps 60 --rendering-driver opengl3`, at 1280x720 **and** 2400x1080, in
both views where the view matters. **Render one three times first and diff it:
0 pixels** (`CLAUDE.md`), or nothing below measures the design.

```
T = --genome=cytostome:2,cirrus:1,flagellum:2,toxicyst:2:3,veneneux:1:7 --radius=39.5 --seed=7
S = --genome=cytostome:2,cirrus:1,flagellum:2,toxicyst:2:5,veneneux:1:7 --radius=39.5 --seed=7
```

`--radius=39.5`, as `dna-body.md`'s own frames use: a first-generation body with
outside slots 0 to 5 live and slot 4 empty, which does not divide on the first
frame as r40 would. Slot 7 is the inside.

| frame | flags | shows |
|---|---|---|
| `D01_pause_forms` | `T --esc-at=1.0 --mode=0` | venom ●●○ at the front (slot 3), poison ●○○ inside, their words, the gene's line |
| `D02_armed_out` / `D03_armed_in` | `--genome=cytostome:1,cirrus:1,flagellum:1 --radius=39.5 --sample=veneneux --esc-at=1.0`, a tap on slot 3, then on the inside | the gene in hand previewed as `venom`, then as `poison` |
| `D04_raise_elsewhere` | `T --sample=veneneux --esc-at=1.0`, a tap on empty slot 4 at 2.5 s | venom is carried at slot 3: `tap again to add a copy to venom` |
| `D05_move_refused` | `T --esc-at=1.0`, the poison dragged onto empty slot 4 | it would be venom there: `here it would become venom, which you already carry`, and the drop refused |
| `D06_faces_out` | `T --esc-at=1.0`, the tail dragged onto the inside | refused, in words |
| `D07_side_venom` | `S --esc-at=1.0 --mode=0`, slot 5 read | the side's sentence and its arc lit |
| `D08_body_fv` | `T --mode=1 --freeze-at=2.0`, and `S` the same | venom on the lips against venom on a side; poison inside |
| `D09_dosed_water` | `--mode=1 --hunter-genome=cytostome:1 --hunt=900 --dose=harm:12:hunter`, and the same without `--dose` | a water body carrying harm, against one that is not |
| `D10_dosed_pov` | `--mode=0 --dose=harm:12 --freeze-at=2.0` | your own harm in point of view, against the same frame with none |
| `D11_numbers` | `D01 --numbers=1`, then `D07 --numbers=1`, each slot read | the numbers lines of front venom, side venom and poison |
| `D12_choosing` | `--seed=12345 --radius=40 --mode=0 --dna=cytostome:3:0,cirrus:2:1,flagellum:3:2,toxicyst:1:3,ampulla:2:4,pellicle:1:6,veneneux:2:7` | two daughters, each with her outside and her inside |

`D02`, `D04` and `D05` tap at 2.5 s, because the arm's timeout runs on the wall
clock and a slow 2400x1080 render can lapse an earlier tap (`dna-slots-ux.md`
§9.3). `D08` to `D10` are drawn to the ux-designer's spec; until it exists they
show the tears alone. `--hunt=` poses its hunter in body slot 0, as
`chase_probe` does (`ocean.md` §5.7). The ux-designer's own frames
(`dna-slots-ux.md` §9.3) are shot beside these, re-posed where they placed poison
in slot 5.

### 20.5 What it replaces

| today | now |
|---|---|
| seven slots, all arcs of the skin | seven outside, and one inside every cell has from birth |
| a gene once in a DNA | a form once: the toxin twice, once outside and once inside |
| `veneneux`, `venom`: whatever bites you pays, whatever swallows you dies | `veneneux`, `poison`, inside; `toxicyst`, `venom`, outside, on your bite at the front or guarding a side |
| a meal of a gene you carry is a copy more | the same, except the toxin, whose meal waits to be placed |
| `VENOM_BITE_BACK_BY_TIER`, `venom_back` | stacks of harm in the biter |
| a swallower of a venomous player dies, the player is spat out (`VENOM_COST_BY_TIER`, `_on_stung`, `STUNG`) | every swallowed poisonous body is eaten, and its swallower takes a dose |
| a venomous water cell is swallowed safely | every cell alike |
| a wound always mends | a body carrying harm does not |
| a poisoned player's death is loud | quiet, as a dose is (`_die(false, …, POISONED)`); a friend's is drawn as one that starved |
| `Drop.VENOM` | `Drop.TOXIN`, every form |
| a water cell's `veneneux` takes an arc | it sits inside, and the genes after it move up one |
| gene-stats' `S04` (`veneneux:3:3`) is poison on an arc | `veneneux:3:7` poses it inside; at slot 3 it is put inside |
| `GENES_MAX` 8; `PROTOCOL` 6 | 9; 7, then 8 and 9 with the strains |

---

### 20.6 As built: phase 1, 2026-10-03

Built to §20.2's phase 1. Every check in §20.3 passes, and so does every CI step
run locally. It ships as content:

- `PROTOCOL` is 7, and protocols 1 to 6, and an 8, are refused by name.
- `Wire.RULES` stays `46913eab…`.
- `binary_version` stays 6.

Two builders made it. The first one's actions were blocked partway by the
session's safety check, which said it was reacting to earlier content in its own
conversation. The owner said to continue, and a second builder finished the
work. Where the build differs from the text above, or found something:

- **Toxins are worked out lazily**, in `food._toxins_at`, and cached by genome,
  order and the side-venom switch (`venom_sides`, a runtime switch for check 7).
- **The `stung` signal is gone.** `Contact.STUNG` keeps its number, because
  `Wire.RULES` fingerprints `Contact`.
- **The killing bite carries its toxins on every path.** That includes a bite
  that finishes the player or a person (`_bitten_by`, `_chewed_by_friend`), as a
  water body's last bite on another always did. This is what makes check 6's
  "every cell alike" true.
- **Drifters never carry a form**, in the drop or in today's water. A toxin they
  draw is drawn again from the pool without it.
- **`cilia.gd`'s `default_order`** could seat a fifth gene at index 7, which is
  now the inside. It now takes the first empty home arc and never goes past 6.
- **`Doses.wear` returns 64-bit values.** A 32-bit `Vector2` let stepping every
  eighth frame drift from stepping every frame by 2.6e-9, which check 4 caught.
- **The replay's block grows by 54 floats**, not 51: the bruise's tint adds 3.
- **A guest's bruise is not tinted**, because a CONTACT carries no dose. The
  mirror reads doses from the body's flags.
- **The French numbers row for the stern** says `qui vous mord de dos prend {}
  dose(s)`. The screen's `par-derrière` measured 658 px against a room of 650;
  the gene's line keeps `par-derrière`.
- **Check 4 (the doses) and half of check 11 were not written** in the first
  pass. The second builder wrote them, including a friend's toxins each way in
  the pond's field and a side sting on its quarter and off it.
- **Check 13's re-pins went past §20.3's list.** `DEV_LINES` and CI's
  empty-library hash moved, and so did IDENTITY, PACK3, TAIL and THREE_ONE and
  their traces, each with its reason in `drop_probe.gd`. The water's draws now
  take a coin for the toxin's place, every bite and swallow doses, and the
  default order changed.
  - The check-8 trace is dev's line for line until the drop's first toxin
    carrier.
  - `DEV_MUTATIONS` and `DEV_DRAWS` reproduce dev's digests exactly.
- **Check 15's runs, as written, never meet a mouth.** It was run again with a
  hunter posed in: stern stings and poison land on what bites, and front venom
  rides the cell's own bites. `forage_probe` prints a `[forage-toxin]` line.
- **`net_probe`'s pond section starts its host at the drop's centre.** A random
  start near the rim could pin the host outside the water when it divided,
  which failed 2 of 8 runs on this branch. Dev has the same weakness. The game
  is unchanged.
  - The run exposed an older game bug: a sister held back by the rim can land
    on a player. That is issue #182.
- **CI's two margins:**
  - `drop_probe` takes 378 to 387 s locally (at 4-3, 251 s locally was 191 s
    on CI), against its 600 s timeout;
  - `net_probe` runs 16,794 to 17,811 frames, 426 checks, against 24,000.
- **Not built, as phase 2's:** the empty slots' ghosts, the form's ghost under a
  drag, the inside in the quick placement's bloom, and the choosing screen's
  inside locus.

## 21. Left open

1. **One inside slot.** Whether it feels like the "body internal slots" the
   owner asked for, or like a slot kept for one gene, is for play to show. It
   grows by one constant: for organelles, or for a second poison once strains
   exist (§8.2, §19).
2. **Whether a venom on a side earns its slot.** Poison already answers every
   bite. A side venom adds its own stacks to the bites on its side, and costs the
   front venom it could have been. If nobody puts one there, the levers are its
   stacks, `VENOM_ARC_DEG`, and last `VENOM_SIDES`.
3. **The look of a dose in point of view**, of paralysis and of sleep is the
   ux-designer's, and phase 1 waits on its harm part.
4. **What evolves** (§9): whether venom spreads through the drop, and whether a
   paralysing hunter makes the water unfair. The census's `worn` columns show it.
5. **The paralysed guest's bank.** A cheat that ignores paralysis keeps moving on
   the host until its bank runs dry, up to about eight seconds at a slow swim,
   because the bank is what an honest guest coasts on. Tightening it means
   measuring honest coasts first.
6. **`STUNG` is never sent**, and keeps its number. A later protocol may reuse it
   or retire it.
7. **The born three's slots** (`dna-body.md` §12, item 1) stay storage. The front
   leans on that and does not settle it.
8. **A form a body wears where its DNA no longer has it.** A body keeps what it
   was born with while its DNA's toxin moves (§5.4). It acts by its worn form and
   its worn slot, wherever its DNA now puts the gene. That is correct, and may
   surprise a player for one generation.
9. **What a new cell is born with** is the owner's (row 11). This document
   assumes today's kit throughout. The other start changes nothing here but
   what the first generation can bite with, and a front venom on a cell with no
   mouth does nothing, as it already does today (§2.3).

---

## 22. Owner's calls

### 22.1 Rows 1 to 10: as they were put, and as they were answered

Put to the owner on 2026-10-03 as one table: rows 1 to 7 from the first draft
of this document, row 8 added by the lead from the phases (§20.2), and rows 9
and 10 from the screen (`dna-slots-ux.md` §12, its rows 1 and 2).

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | What is the gene called? | **`toxicyst` ✓ recommended** · keep `veneneux` · two names: `veneneux` in your body, `venimeux` at your mouth | The name on the gene's line. Whichever you pick, its slot says `poison` in your body and `venom` at your mouth. A toxicyst is the tiny harpoon real hunting ciliates fire from round their mouths. `veneneux` means poisonous, an odd name for venom at your mouth. `veneneux` and `venimeux` are French's own words for poisonous and venomous, so the name changes as you move it |
| 2 | What are a toxin's three kinds called? | **`corrosive`, `paralysing` and `sleeping` ✓ recommended** · `lytic`, `paralytic` and `narcotic` · `burning`, `numbing` and `drowsy` | The word for what a toxin does once it is in a cell: it eats at the body, it stops it swimming, or it puts it to sleep. You read it on the gene's line and see it as a colour. The second set is what a biologist says. In the third, `burning` sits close to `burn`, the gene that makes everything cheaper |
| 3 | Which slots are your mouth's? | **the three at your front: the nose and the slot either side of it ✓ recommended** · the nose's slot only | Whatever sits at your mouth's slots works through your bite; anything else is in your body. With the three, the first two slots you grow are at your mouth, so venom comes early and poison later. With the nose only, you would first have to move your mouth gene out of its own slot to make venom |
| 4 | How many times can you carry a gene? | **once in each form: one venom and one poison, of each kind ✓ recommended** · in as many slots as you like | Eating a toxin you carry either adds a copy (the dots) or makes the other form. With as many slots as you like, a second poison in a second slot would do exactly what a second copy does, and cost you a slot |
| 5 | What happens to a poisonous cell that is swallowed? | **it dies, and whatever swallowed it takes a big dose of its poison ✓ recommended** · it is spat out alive and hungry, and the swallower takes the dose | Today whatever swallows you dies on the spot and you are spat out alive. Recommended: you die when swallowed, as anyone does, and what ate you is left full of your poison. Three copies kill even a full-grown cell; one leaves it hurt. The same for every cell, and real: predators that eat a toxic ciliate sicken afterwards. Spat out: you survive being swallowed, but so does every poisonous cell, and the water may fill with them |
| 6 | Where does a toxin's kind come from? | **from what you eat: it passes to you with its kind, your daughters inherit it, a mutation can change it ✓ recommended** · you choose it once the gene has been used enough, as the beam forks · from where it sits | Recommended: eat a paralysing cell and you can carry its paralysing toxin, and the water's hunters evolve theirs. Choosing at a fork makes it yours to pick, but the water's cells never fork, so no hunter could ever paralyse you. Where it sits already decides venom or poison, so it cannot decide the kind too |
| 7 | When your cell is asleep, can you steer it? | **no: it swims on by itself until a bite wakes it, or the sleep wears off ✓ recommended** · yes: only your senses and your instincts sleep | Recommended: sleep means losing your cell for a few seconds, in both views, and the hunter's first bite wakes you. If you can still steer, sleep only darkens your senses, and in full vision, which shows everything anyway, it would do almost nothing |
| 8 | When do paralysis and sleep come? | **after the release ✓ recommended** · in it | Put by the lead, from this document's phases: venom and poison by place go into the release, and the paralysing and sleeping kinds follow it, each played on the dev app first |
| 9 | What does the gene screen call the two places? | **mouth / body ✓ recommended** (French *à la bouche* / *dans le corps*) · *front / inside* (*devant* / *dedans*) · no words, the drawing only | One sentence on the gene screen says the rule: *venom at your mouth, poison in your body*. *Front / inside* says the same thing less exactly. With no words, players learn the rule only from the lit front of the body and the slot names |
| 10 | What is a toxin called before you place it? | **toxin ✓ recommended** (*toxine*) · the form you ate it as (*venom* or *poison*) · the gene's name, *toxicyst* | While it waits it is neither: the slot you pick decides. *Toxin* says so. The eaten form would show *venom* on the tray and then *poison* once placed in the body. *Toxicyst* is the real organelle, but a hard word to meet on every pickup |

Row 8's wording here is a summary; the lead put the row.

**Answered on 2026-10-03.** The owner, verbatim:

> All recommended

then:

> Just a precision for 3 : We need add body internal slots. Those express inside
> the body. The direction slots express outside the body.
>
> Also, does cell have mouths?

**The lead answered the question:** one cytostome per cell, at the front, and
drifters have none.

So, row by row:

| # | answered | what it changed |
|---|---|---|
| 1 | as recommended: **`toxicyst`** | `Genome.NAMES` shows `toxicyst` for both forms (§3.2); the code keeps `veneneux` and `toxicyst` as the forms' keys |
| 2 | as recommended: **corrosive, paralysing, sleeping** | the strains' names on the gene's line from phase 3 (§8.3); French *corrosif*, *paralysant*, *endormant* |
| 3 | as recommended, **then made precise: an inside, and the direction slots outside** | §2 rewritten. The places are outside (the seven arcs) and inside (a new slot, every cell's from birth). The answered three survive as **the front**, where venom rides on the bite; on a side or the stern venom stings what bites there (§2.3) |
| 4 | as recommended: **once in each form** | one venom outside in total, and one poison inside (§3.4). With one inside slot, row 4's *"of each kind"* is a cap for poison (§8.2) |
| 5 | as recommended: **eaten, and the swallower takes a big dose** | §7: no spit-out for any cell |
| 6 | as recommended: **from what you eat** | §8.1 |
| 7 | as recommended: **asleep, you cannot steer** | §6.4 |
| 8 | as recommended: **after the release** | phases 3 and 4 follow the release (§20.2) |
| 9 | as recommended, **then overtaken by the owner's own words for row 3** | the screen says `outside` and `inside` (`dehors`, `dedans`), not *mouth* and *body* (§3.2, §10.2) |
| 10 | as recommended: **`toxin`** | the tray, the hand and a drag say `toxin` (§5.1) |

### 22.2 How the precision is read

- **"Body internal slots"** is read as slots of the body's inside, apart from the
  arcs: **one, every cell's from birth, holding only the toxin now** (§2.2). The
  owner's plural is the kind of slot. More inside room and more inside genes are
  one constant and one row each away (§19).
- **"Those express inside the body"**: a gene inside acts as the cell's
  contents. The toxin inside is poison, as the owner's first message said: *"in
  a dna slot that expresses inside the cell, it becomes poisonous"*.
- **"The direction slots express outside the body"**: a gene in a direction slot
  acts outward, facing its slot. The toxin there is venom. **At the front it
  rides on the bite**, the owner's *"attached to the mouth, it becomes venom"*.
  On a side or the stern it stings what bites there (§2.3). That last part is
  this document's reading, checked against the biology and the bite's geometry.
  It is not put as a row, because it applies the owner's sentence and does not
  change it. `VENOM_SIDES := false` is the switch if the owner reads it as venom
  through the mouth alone.

### 22.3 Settled here, not asked

These are decided by the owner's words or by an answered row:

- **The inside**: one slot, from birth, every cell's, the water's included
  (*"all cells follow the same rules"*).
- **Only the toxin goes inside, now**, and the inside keeps no layout.
- **One venom outside in total**, not one per bearing (row 4).
- **A shift never crosses between inside and outside.** Where a toxin lives is
  the player's choice; a drift that takes the poison out finds the incoming gene
  an outside seat or does not apply.
- **Your old `veneneux` moves inside**, keeping its copies and its meaning.
- **A death by a dose is quiet**, and a friend's is drawn as one that starved.
- **`Wire.RULES` does not move in phase 1** (the referee never judged venom), and
  **`PROTOCOL` does**, by `wire.gd`'s own rule for the bite tables.

**The precision needed no new row.** Rows 11 to 14 come from the owner's next
message (§22.4).

### 22.4 Rows 11 to 15: the starting cell, a skin that eats, its word, the release, and the inside

From `feeding.md`, after the owner's *"We must think of what the starting cell
has, and what it could evolve to get"*. Rows 1 to 10 are answered (§22.1).

| # | Question | Options | What it means |
|---|---|---|---|
| 11 | What is a new cell born with? | **a mouth at its front, as today ✓ recommended** · no mouth: its skin eats small things and the water feeds it, and its daughters are born with a mouth | As today: your first cell hunts from its first second, every drifter and every clump fits in its mouth, and it starves in 30 seconds without food. With no mouth, your first cell eats any small thing that touches it, from any side and without aiming, and it lasts about 55 seconds without food. But at first only about one drifter in four is small enough, and it cannot bite or fight back. Its daughters, and every cell after them, hunt with a mouth. Every death starts you again without one. It cannot win a mouth by eating, because nothing it can eat at first has one |
| 12 | Can a cell with no mouth eat with its whole skin? | **yes, after the release ✓ recommended** · no: as today, it eats only through a small mouth at its nose | Today, if you write a gene over your mouth, your daughters are left a tiny mouth at their nose and live mostly on food soaked up from the water. With the skin they eat any small thing that touches them, from any side, as an amoeba does. They cannot bite or hunt, but with poison inside and stings on their sides, whatever bites them pays for it. Giving up your mouth is nearly for good: your line gets one back only by swallowing a small hunter once it has grown, or when you die and start again. The drifters graze the same way |
| 13 | What is eating with the skin called? | **engulf ✓ recommended** (*englober*) · swallow (*avaler*), as the mouth does · phagocytose (*phagocyter*) | The word on the line before you write over your mouth, and on your cell once it has none. *Engulf* is the whole body closing round its food. *Swallow* is the mouth's word, so the two ways of eating would read alike. *Phagocytose* is what a biologist says, and a hard word to meet. It only matters if row 12 is yes |
| 14 | What goes into the next release? | **venom and poison inside and outside, with their screen; the skin, paralysis and sleep after it ✓ recommended** · the same, and the skin too · what dev has now, and the toxins in the release after | Recommended: the release waits for the toxin work and its screen, which you will have played on the dev app first. Everything after that is played there and released later. With the skin too, the release waits one piece longer and brings two new ways to play at once, so each is harder to judge. Releasing now gives players what dev already has, among it the drop, cells that divide and learn, your instincts and autopilot, and the hunger alarm. Players would then meet today's venom and learn the new one a release later, and the venom gene would change its name twice |
| 15 | How many inside slots, and what goes in them? | **one now, for the toxin's poison; vacuole, crista and plastid move inside in a later pack ✓ recommended** · those three move inside now, with an inside slot each | You said *inside slots*. Today only the toxin has an inside form, so one slot holds it. Vacuole, crista and plastid are organelles a real cell keeps inside, but in the game they sit on the outside slots. Moving them inside frees outside room, so every cell carries more genes. That changes the game's balance and everyone's saved cells, so it is bigger than polish |

- **Row 11's second option needs row 12's first**: a cell born without a mouth
  eats with its skin.
- **Row 13 matters only if row 12 is yes.**
- **The numbers in row 11 are not up for tuning.** The 55 seconds, the one
  drifter in four and the four meals to divide are what the code does with each
  start. They are given so the owner can choose what the game is, not how hard.
- **Row 14's first option carries row 8's answer on**: venom and poison go into
  the release, and paralysis and sleep follow it.
- **The venom gene's names.** Players have it as `toxicyst` (the last release),
  `dev` calls it `veneneux` (`8587c1b`), and row 1 makes it `toxicyst` again.
  Releasing now would show players the middle name for one release.
- **Not put**: tentacles, and a mouth on another arc. They are hooks
  (`feeding.md` §4.2), each a later pack's design.
- **Row 15 was put by the lead**, from the owner's plural *slots* and §2.2's
  one inside slot and §19's hook for the organelles.
- **The screen's redo** (§10.2) may raise rows of its own. They number on from
  16.

**Answered 2026-10-03: the recommended option, all five rows.** The owner:
*"All recommended."* So:

- **Row 11:** a new cell is born with its mouth, as today. `feeding.md`'s
  phase 5b is not built.
- **Row 12:** a mouthless cell eats with its skin, after the release (phase 5).
- **Row 13:** that eating is called *engulf* (*englober*).
- **Row 14:** the release waits for venom and poison, inside and outside, and
  their screen (phases 1 and 2). The skin, paralysis and sleep come after it.
- **Row 15:** one inside slot, for the toxin's poison (§2.2). The organelles'
  move inside is a later pack's (§19).

---

## 23. What to watch in the playtest

**Phase 1, venom and poison:**

- Whether putting the toxin inside or outside feels like your choice, and
  whether you knew which it would be before the second tap.
- Whether the inside reads as *inside your body*, on the pause screen and in the
  water.
- Whether venom at your front does something you can see: a bitten cell that
  goes on coming apart after you let go.
- Whether a venom on your stern feels like armour you chose, or a front venom
  wasted. Watch a chewer behind you weaken.
- Whether being poisonous feels worth carrying, now that it no longer saves you
  from a swallow. Watch a hunter chew you and weaken. In the replay, watch the
  one that swallowed you die.
- Whether a dose in you is clear in point of view: you should know you are
  poisoned, and not mistake it for hunger or for a bite.
- Whether swallowing a poisonous cell surprises you, and whether full vision
  taught you which cells to leave alone.
- The water: on the dev readout's census, whether venom or poison spreads or
  vanishes over an hour, and whether the drop feels more dangerous.

**Phase 2, the screen:** whether the inside slot is easy to hit and to read on a
phone, with your thumb over the body.

**Phase 3, paralysis:**

- whether being stopped by a hunter is frightening or unfair;
- whether stopping your own prey is satisfying;
- how it feels to be paralysed by your friend's water in a pond, and whether you
  stop on your own screen at once.

**Phase 4, sleep:** whether falling asleep reads as sleep and not as a frozen
game, in both views, and whether the bite that wakes you leaves you a chance.

**Phase 5, a skin that eats**, and the start: `feeding.md` §11.

**On a phone:** the frame readout's `water` and `dropped` rows once the drop's
cells carry doses.
