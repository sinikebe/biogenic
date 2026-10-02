# Behaviour: rules a cell carries, passes on and changes

Pack 3 of the evolving water (`roadmap.md`, "Next"). The owner, 2026-09-29:
cells "pass both [genes and behaviour] on with small mutations, so the cell
dangerousness improve with time not only because of genes, but also from a
kind of learning", and players then build their own cell's behaviour from the
same blocks. Pack 1 made the drop (`ocean.md`). Pack 2 made its cells divide
and pass on their genes (`lineage.md`). This pack replaces the hand-written
hunter with rules that every water cell carries, passes on and changes when it
divides. Pack 4, the player's block screen, is not designed here; §11 names
what it needs.

**Status: designed from the code and the existing specs; nothing prototyped or
measured, by the owner's choice; the owner playtests it on the dev app.** The
owner, 2026-10-02: *"Don't measure in prototypes. I'll playtest."* Every number
below is either a starting value, given with its reason, or a measurement that
`ocean.md` or `lineage.md` already holds, cited where it is used. Code
references are to `dev` at `f62ef20`.

**Revised the same day to the owner's answers** (§15). Rows 22 to 24 stand as
recommended, and three rules reshaped the design:

- a rule reads only what the body's own senses report: no magic information;
- it acts only through the triggers a body has, such as turning and dashing;
- the blocks are modular: every gene declares what it senses and what it
  triggers, so a new gene brings its own blocks.

The owner's standing rules bind it as they bound pack 2: *"all cells follow the
same rules. Me, friends, NPC, doesn't matter."* -- *"A cell dies of hunger,
nothing else. Unless it gets eaten by another one."* -- *"Don't go too far with
ensuring a player lives as long as today. I'll playtest it and tell you how we
can fix that."* -- and row 19, *"every division. No specific treatment between
NPCs and players"*.

---

## 0. What packs 1 and 2 left

**One hand-written hunter for every mouth.** In the drop, a water cell with a
`cytostome` decides on its tick, 7.5 times a second near the player or far from
it (`ocean.md` §4.3), in `food.gd`'s `_decide(index, b)`, while it is not on a
run. It **rests** while digesting or fed: `calm > 0` (5 s after a meal,
`REST_MEAL`, or after a miss, `REST_MISS`) or `hunger < HUNT_AT` 0.3. Otherwise
it **hunts** the nearest thing it can eat within its senses' reach
(`_look_in_drop`) in a committed run: it turns to face the prey, stalks and
intercepts it, dashes on its `myoneme` inside `LUNGE_RANGE` 220 µm, and is
committed inside `COMMIT_RANGE`, until a meal or a miss. Otherwise it
**searches**, swimming along a wandering heading at its own speed.

**What today's hunter knows that its organs do not tell it.** Its senses only
gate the moment it finds its prey: `_senses_find` is a reach check (`d ≤
notice`, `notice_floc` or `see_big`). After that it knows the prey fits its
mouth (`_worth_committing_to`), and for the whole run it steers on the prey's
true position and velocity (`_intercept`, `_lead`). So a hunter that only
smells knows your exact place and speed once it has found you. The owner's
answer rules out all of that (§15).

Drifters decide nothing. `ocean.md` §5.4 has what each piece of today's hunter
is worth. `CALM_*` and the flight after a miss belong to today's water
(`--drop=0`, a tool's reference) and to the tool switch `--flight=all`, and this
pack leaves them alone.

**The hooks** (`ocean.md` §12, `lineage.md` §10) are `Body.brain` (reserved and
null), `_decide` ("the entry pack 3's blocks take over"), `_divide` (where "a
brain is copied ... mutated by the blocks' own operator"), `_spawn` (the one
door every body comes in by) and `cell.gd`'s `_read_steer()` (where pack 4's
blocks would steer the player).

---

## 1. Decided, in one place

1. **A behaviour is an ordered list of at most eight rules.** A rule reads
   *when <input> [is …] → <output>*: one of the body's declared inputs, up to
   one test on each value that input carries, and one of its declared outputs
   (§3, §4).
2. **Inputs are only what the body's own senses report, in the form they report
   it** (§3.2): a bearing, a level, a distance, a size, exactly what the same
   organ gives the player. The body's own state counts too: its hunger, and how
   long since it ate. Nothing about another body's mouth, genome, intent,
   position or speed is ever an input.
3. **Outputs are the triggers a body has** (§3.3): turn toward a sensed bearing,
   turn away from one, turn at random, swim, rest, dash on a `myoneme`, push on
   an `axoneme`. A cell runs away with an ordinary rule, such as *when my laser
   touches something ahead → turn away* (row 23). There is no flee action.
4. **The blocks are modular** (§3.5). Every gene declares its inputs and
   outputs in one table in `genome.gd`, and the body and the metabolism declare
   theirs the same way. A body's vocabulary is whatever it carries. A new gene
   that declares a sense and a trigger is usable in rules, by mutation, in the
   save and on pack 4's screen, with no block written by hand.
5. **Read from the top, with one winner for each trigger** (§4.1). A cell can
   steer, swim and dash in one tick, as a real cell's organs work at once.
6. **Hunting is rules over senses** (§4.2, §5). Today's run goes. A hunter
   turns toward what a sense reports and holds that heading. It leads its prey
   only by how a sensed bearing drifts from tick to tick: constant-bearing
   pursuit.
7. **The water's first cells carry today's hunting, re-derived under these
   rules** (row 22): seven rules (§5). It cannot be exactly today's hunting,
   and §5.3 says what that changes for the player.
8. **Every division changes one daughter's rules**, the daughter whose DNA it
   changes, by one small change (§6). A change draws on what the body, its
   metabolism and the genes in its DNA declare.
9. **"Hunting you" becomes "coming for you"** (§4.3) for your wake, every dart,
   full vision's rings, the replay and the pond's flag. A dart stuns what it
   hits for 5 s.
10. **Players see nothing new except how the water behaves** (row 24). The dev
    app's readout gains `behaviours` and `unchanged` (§7.3).
11. **Saved by declared name; no protocol change; no binary change** (§8, §12).
    `Wire.PROTOCOL` stays 5 and `Wire.RULES` stays `46913eab…`. It ships in two
    phases: first cells sense and hunt by rules, then their rules change.

---

## 2. What a behaviour is

### 2.1 Four candidates

A behaviour has to run for every hunter in the drop on a phone, 7.5 times a
second (in pack 2 a newborn's drop held up to 158 hunters and a sighted
player's about 200: `lineage.md` §2.2). It has to change in small steps that
usually leave it working, and be built by a player in pack 4 on a 1600×720
landscape canvas, with 48 px targets, in the game's plain words. It also has to
grow with the genes: a new gene's sense or trigger must become a block without
anyone writing one.

| candidate | what a decision costs | a small change | can a player build it | a new gene's sense or trigger |
|---|---|---|---|---|
| **an ordered list of when → do rules** (Final Fantasy XII's gambits) | at most eight rules, and a sense is read only when a rule reaches it | a value nudged, a test or a part replaced, two rules swapped, a rule copied or dropped | yes: one row per rule, a few chips to a row, eight rows to a screen. Console players learned it in 2006 | becomes a chip: something a rule can read, or do |
| a behaviour tree | a walk of the tree, about the same | replacing a subtree changes a whole branch, and trees grow without use (genetic programming's "bloat") | depth needs panning, and "selector" and "sequence" are not plain words | becomes a leaf |
| weighted steering (context steering, Braitenberg's vehicles) | a sum over stimuli, cheap | smooth: a weight moves a little | a weight is not a plain word, and what a sum will do is hard to foresee | a sense becomes a weight, but a trigger that is not a direction, such as a dash, has no place in a sum |
| a small neural net | about a hundred multiply-adds a decision, in GDScript | smooth | nobody can build or read one | an input or output neuron that nobody can read |

**The list wins.** It is the only candidate a player can build and read, it
changes in steps that mostly keep it working, and a declared sense or trigger
drops straight into it. The tree loses on the screen, and passing it over costs
nothing: a list is a tree one level deep, so pack 4 can later let a rule hold a
list. Steering loses the screen and the dash, and lives on inside one output:
turning toward a bearing holds that bearing steady (§4.2). A net loses
everything a player would touch.

Robotics calls this shape subsumption: layers in priority order, each driving
an actuator and suppressing the layers below it
([Brooks, *IEEE J. Robotics and Automation* 1986](https://doi.org/10.1109/JRA.1986.1087032)).
§4.1's "one winner for each trigger" is that reading.

### 2.2 The real mechanisms are the blocks

Real ciliates and bacteria behave through a handful of named mechanisms
(Fraenkel and Gunn, *The Orientation of Animals*, 1940; Jennings, *Behavior of
the Lower Organisms*, 1906). Each one is a rule over a declared input and
trigger:

| mechanism | what a real cell does | as a rule |
|---|---|---|
| positive taxis (chemo-, photo-, thigmo-) | steers toward a stimulus's source | *when an echo or a beam reports something → turn toward it*, and swim |
| negative taxis | steers away from a noxious stimulus | *when a shadow, a beam hit or a touch is reported → turn away from it* |
| the avoiding reaction (*Paramecium*) | when struck, backs off and swims on at a new heading chosen at random | *when hit → turn at random* |
| run-and-tumble (*E. coli*) | runs straight, tumbles to a random heading, and tumbles less while things get better ([Berg and Brown, *Nature* 1972](https://www.nature.com/articles/239500a0)) | *when the smell is falling → turn at random*, and swim |
| orthokinesis | swims faster or slower with a stimulus's strength, or with how starved it is (`ocean.md` §5.4) | *when hunger is above x → push* |
| satiation | a fed cell stops feeding and slows down | *when fed → rest* |
| constant-bearing pursuit | keeps the prey's bearing steady, which puts it on a collision course: the interception rule pursuers use | *turn toward* leads a bearing that drifts (§4.2) |

Nothing in the vocabulary is invented. What the game adds is the order. A real
cell's mechanisms run in parallel and their effects add up. Here the first rule
for each trigger wins, because a player can read an order and cannot read a
sum.

---

## 3. What the blocks are: what each part declares

### 3.1 A declaration

Every gene that senses or triggers anything declares it once, in a table beside
`GENE_ORDER`:

```gdscript
# genome.gd: what each gene gives a body's rules (behaviour.md §3).
# The body's own parts (cell.gd) and the metabolism's (metabolism.gd)
# are declared in the same shape.
const DECLARES := {
	&"ocellus": {"in": [{"name": &"beam", "bearing": true,
		"values": {&"distance": &"distance"}}]},
	&"ampulla": {"in": [{"name": &"echo", "bearing": true,
		"values": {&"distance": &"distance", &"size": &"size"}}]},
	&"chemocyte": {"in": [{"name": &"smell", "bearing": false,
		"values": {&"level": &"level"}}]},
	&"stigma": {"in": [{"name": &"shadow", "bearing": true,
		"values": {&"level": &"level"}}]},
	&"palp": {"in": [{"name": &"touch", "bearing": true,
		"values": {&"closeness": &"level"}}]},
	&"myoneme": {"out": [{"name": &"dash", "claims": [&"dash"]}]},
	&"axoneme": {"out": [{"name": &"push", "claims": [&"push"],
		"options": [0.5, 1.0]}]},
}
```

**An input** has a name, says whether it carries a bearing, and lists the
values it carries, each of a kind. **An output** has a name, says which
triggers it claims, and may need a bearing (a turn does) or take an option (a
push's strength).

**The kinds belong to `rulebook.gd`** and are the same for every input. Each has
the ladder a change steps along:

| kind | ladder | why |
|---|---|---|
| level, 0 to 1 | 10 % to 90 %, in tenths | plain, and the same everywhere |
| seconds | 1, 2, 3, 5, 8, 13, 21, 34 | about the same proportion at each step |
| distance, in µm | 50, 80, 130, 220, 350, 560, 900, 1,450 | the same proportion, with today's lunge range (220) on it |
| bearing, in degrees off the nose to either side | 15, 30, 45, 60, 90, 120, 150 | "within 30°" or "in my front half" (within 90°) |
| size | the body's own size, or its mouth's gape, which the caller hands over | a comparison against what the body knows of itself |

**A test** is one value against a step or a reference: below, above, rising or
falling since the last tick. An input's bearing, where it has one, counts as
one of its values. A rule without tests fires whenever its input reports
anything. An input that reports several things at once, such as a call's
returns or a fan's rays, is filtered by the tests, and the output acts on the
nearest report that passes.

### 3.2 Inputs, from the senses as they are

Each of these is what the organ already reports to the player's membrane, read
from the same code. A water cell reads it the same way, from where it is and
with its own organs.

| input | declared by | carries | what it reports, in the code |
|---|---|---|---|
| `smell` | `chemocyte` | a level, no bearing | the scent of everything its mouth could take, within its smell reach (1,100 to 1,600 µm by tier), weighted by how nearly each source lies along the organ's own arc (`_step_sense`). A nose steers by its rise and fall |
| `echo` | `ampulla` | a bearing, a distance and a size | its own call, once per round trip (every 8.8, 12 or 15.2 s by tier), with up to 3, 4 or 5 returns, blind behind its own arc at tier 1 (`_cast_ping`). A return's bearing is to where the body was. Its distance comes from when it came back, and its size from how long it rings (`ping-as-outline.md` §3). Each return is reported for as long as it rings |
| `beam` | `ocellus` | a bearing and a distance | the nearest thing its rays stop on (one, two or three rays by tier, 620 to 1,240 µm) along the organ's arc: a cell, a floc or the rim (`_step_beams`). What it hit is not reported |
| `shadow` | `stigma` | a bearing and a level | light blocked by bodies at least about its own size (from 0.8 of its radius) within 620 µm, and by the rim, summed with a bearing (`_step_sense`) |
| `touch` | `palp` | a bearing and a closeness | the nearest thing within 150 to 330 µm of its skin, the rim included (`_step_touch`) |
| `hit` | the body | a bearing and a strength | a bite or a dart landing on its membrane. The player feels a bite as a `hit` |
| `hunger` | the metabolism | a level | its tank. The player feels it as the beat |
| `fed` | the metabolism | seconds | how long since its last meal: a cell, a floc or you |

### 3.3 Outputs, the triggers a body has

The player's own controls are steer, push and dash (`cell.gd`), and its
flagellum beats on its own (`energy.md`). A water cell can turn, swim or drift,
and dash (`food.gd`). These are the triggers, declared by what owns them:

| output | declared by | does | claims | needs |
|---|---|---|---|---|
| `turn toward` | the body | sets the heading it steers for on the input's bearing (§4.2) | steering | an input with a bearing |
| `turn away` | the body | sets the opposite heading | steering | an input with a bearing |
| `turn at random` | the body | sets a heading 90° to 180° to a random side | steering | -- |
| `swim` | the body | beats its flagellum at its tail's speed, paying for it | swimming | -- |
| `rest` | the body | stops everything: the water carries it at 9 µm/s, for free | every trigger | -- |
| `dash` | `myoneme` | a burst forward, on its cooldown, paying for it | dash | the organ worn |
| `push` at half or full | `axoneme` | the axoneme's thrust while the rule holds, paying for it | push | the organ worn |

**What stays automatic, and why.** The `trichocyst` dart fires on its own, as
the player's always has ("the design has no second control to spend":
`food.gd`). The ping calls on its own clock, the round trip, and the beam is
always on. The mouth swallows or bites whatever it touches (row 15). These act
the same for the player and the water, so they declare no output. The `cirrus`
and the `flagellum` declare nothing either: every body turns and swims (their
tier 0 has a rate), and these genes only make the body's own triggers faster.
`pellicle`, `veneneux`, `plastid`, `vacuole` and `crista` are passive.

### 3.4 What no rule can read

- **Dread.** It is the player's membrane summing every mouth within
  `DREAD_RANGE` that could swallow or chew you (`THREAT_LOW`, `THREAT_HIGH`,
  `CHEW_*`). No organ reports another cell's mouth.
- **The wake.** You feel it only from a cell coming for you, and that test
  reads the other cell's mouth too (§4.3).
- **Anything else about another body that no sense reports**: its mouth,
  genome, hunger, intent, or exact position and speed.
- **Comparisons against the body's own traits are allowed.** "An echo smaller
  than my mouth" compares a size the echo carries with the body's own gape.
  The smell already counts only what the body's mouth could take, and the
  shadow only bodies about its own size or bigger. Both are those organs
  exactly as the player has them.
- **The clocks.** `fed` is kept: a body knows it has eaten, because it is
  digesting. "Since a miss" is dropped: a miss was a run that ended without a
  meal, there are no runs any more, and nothing tells a body that a chase
  failed.

### 3.5 How a gene brings its own blocks

To add a gene with a new sense and a new trigger:

1. Name it in `genome.gd`'s `GENE_ORDER` and give it its tier tables in
   `cell.gd`, as for every gene today.
2. Write its entry in `DECLARES`: each input with its name, bearing and value
   kinds, and each output with its name, claims, needs and options.
3. Write the organ. That is one function that computes each input for any body,
   serving both the player's membrane and a water cell, and one that performs
   each output. Register both under the declared names in `food.gd`, and from
   pack 4 in the player's run.

Nothing else changes. Rules can read and drive the gene, mutation draws it for
bodies whose DNA carries it, the save keeps it by name, and pack 4's screen
lists it. The organ always had to be written; the block never has to be.

**Where the declarations live, and why.** They live in `genome.gd`, one entry
per gene beside `GENE_ORDER`, because that is where a gene exists: adding one
already means editing the list a drift mutation draws from. A declaration is
data that ships in a content pack like any GDScript. One resource file per gene
was rejected: nothing else in the game is defined per gene, and it would need a
loader. The body's own parts are `cell.gd`'s, the body every cell runs, and the
metabolism's are `metabolism.gd`'s, which owns the tank.

**The owner's example, worked through.** *"Turn away when laser touches
something in front of it."*

1. `genome.gd` declares `ocellus` → `beam`, with a bearing and a distance
   (§3.1).
2. `food.gd` wires `ocellus.beam` to the player's own ray cast, run from any
   body: from where the body is, along its `ocellus` arc, reporting the nearest
   thing its rays stop on as a bearing and a distance.
3. The rule, as the save writes it: `ocellus.beam bearing below 90 ->
   body.turn-away`. In plain words: *when my laser touches something in my
   front half, turn away from it.*
4. On a tick the rulebook reaches the rule and asks for `ocellus.beam`. Say the
   rays stop on a body 300 µm off at about 54° to starboard, the front diagonal
   where a water cell's first extra organ sits. 54 is below 90, so the rule
   fires: it claims steering, and the body sets its heading 180° from that
   bearing and turns there at its `cirrus`'s rate, paying for the turn.
5. A body without an `ocellus` gets no reports on `ocellus.beam`, so the rule
   is passed over. It waits, inherited, for a daughter who grows one.
6. In pack 4 the same line is a row on the player's screen, wired by the
   player's run to the player's own beam.

The founders' fourth rule (§5.1) reads the same input and turns the other way.
Which one a family keeps is up to evolution.

---

## 4. How a body runs its rules

### 4.1 Each tick, from the top

A water cell reads its rules on its tick, 7.5 times a second near you or far
away, as today (`ocean.md` §4.3). Going down the list, a rule fires when its
input reports something now, every test passes, its output is one the body has
(the declaring gene is worn), and none of the triggers its output claims was
claimed by a rule above it this tick. The output then acts on the nearest
report that passed, and claims its triggers.

**One winner for each trigger.** A turn claims steering, a swim claims
swimming, a dash and a push claim themselves, and a rest claims all of them. So
a list can make a cell steer toward an echo, swim and dash in the same tick, as
its organs do, and a rest above everything else stops everything. For each
trigger it is still an order, where the first rule wins, so the list reads the
same way.

**A trigger no rule claims** does what the body does on its own: no new
heading (§4.2), no swimming (the water carries it at 9 µm/s, for free), no dash
and no push. A body none of whose rules fire drifts.

### 4.2 Steering

**A turn sets a heading, and the body holds it.** A turn output sets the heading
the body steers for: the sensed bearing, its opposite, or a random one. On every
step the body turns toward that heading at its own `cirrus`'s rate, paying
`TURN_COST` per radian, until a later tick's turn sets another heading or a rest
clears it. So an echo that rings for half a second still turns the body all the
way round, toward where the echo came from.

**Leading by the bearing's drift.** When a turn toward an input finds that the
input also reported last tick, it aims ahead of the bearing by three times how
far the bearing drifted since. Three is the textbook navigation constant, and a
starting value. A target whose bearing holds steady is on a collision course,
which is how a pursuer intercepts without knowing where its prey is. A bearing
that jumps by more than 30° (`LEAD_JUMP`) belongs to a new target and is aimed at
straight. Leading works only for senses that report a bearing every tick: the
shadow, the touch, and a beam while its rays stay on the target. A smell has no
bearing, and an echo comes back only once a call. As built, a beam reports its
ray's bearing rather than the target's centre, so a laser hunter turning while
its ray stays on the target can over-lead.

**A random turn** draws its heading when the rule starts firing and keeps it
while the rule keeps firing, so a run of falling smell is one tumble, not a
spin. The draw comes from the global stream that `--seed=` seeds.

**With no turn claimed, the heading is the water's**: the free wander every body
has, and the turn a drifting body makes away from the shore (`ocean.md` §3.1).
A swimming body slides along the rim.

### 4.3 What "hunting you" becomes

Five things read today's run: your wake, every `trichocyst` (which fires at a
run coming at its body), full vision's predator rings, the replay's hunter slot
and the pond's "stalking you" flag. With no run, each now reads **a cell coming
for you**: one that is swimming, has you within 35° of its heading (half today's
`LOCK_CONE_DEG`), and has a mouth that could swallow or chew you
(`_worth_committing_to`, today's test for starting a run). That last condition
is the same knowledge your dread has. Like dread, it is your membrane and your
organs reading the water, never an input to a rule (§14). The player is never
darted, as today.

**A dart stuns.** Today a dart breaks off a run at its body, and the hunter
rests for 5 s (`REST_MISS`). With no run to break, a dart now stuns what it
hits: the body rests for 5 s with its rules unread, and feels the dart as a
`hit` at its bearing. That is the effect today's darts have.

**The grace protects nothing on rules** (row 25, answered). Today no run begins
at a body in its grace: the player for `FIRST_DELAY` after a birth or a return,
and every daughter for `newborn_grace`. No sense reports a grace, so a hunter
whose senses find a newborn, you included, can come for it at once. Both
constants stay for pack 2's reference (`--rules=0`).

### 4.4 Where a gene goes

**A water cell's senses stay where the default order puts them.** Under these
rules, where an organ sits matters: the beam's rays and the nose's lobe follow
its arc, and the ping leaves from it (`three-senses.md`). A water cell has no
layout of its own. Its organs sit in default order (`Cilia.default_order`): the
mouth ahead, the `cirrus` and the tail on their home arcs, and everything else
on the four diagonals, about 54° and 132° to either side, in the order it came.
A meal still takes the first free slot.

Giving the water a layout, and with it the player's shift (row 19), is the
natural next step, but not this pack's. The guest's mirror and the replay draw a
water cell in default order, because neither the wire nor the recorder carries a
layout, so a moved organ would be drawn where it is not. It waits for the next
protocol change (§14).

### 4.5 What it costs a body

Every trigger is paid at the player's prices (`ocean.md` §5.2). Swimming pays
for its strokes at its tail's speed, a push pays the `axoneme`'s thrust as
yours does, a turn pays per radian and a dash its price. Drifting is free.

Today a water cell swims with half of its `axoneme`'s push folded into its
speed (`swim_speed_of`, `PUSH_CHASE_SHARE`). That push is now the `axoneme`'s
own trigger, and the founders push at half strength while they swim (§5.1),
which is the same speed.

---

## 5. The founders: today's hunting, re-derived

### 5.1 The seven rules

What every body the water makes carries (row 22):

| # | when | do | what it stands in for today |
|---|---|---|---|
| 1 | `fed` below 5 s | rest | `calm > 0` after `REST_MEAL` |
| 2 | `hunger` below 30 % | rest | `hunger < HUNT_AT` |
| 3 | an `echo` smaller than my mouth | turn toward it | the run, for a cell with an `ampulla` |
| 4 | a `beam` hit | turn toward it | the run, for a cell with an `ocellus` |
| 5 | the `smell`, falling | turn at random | the run, for a cell with a `chemocyte` |
| 6 | always | swim | the search, at `_cruise_speed` |
| 7 | always | push at half | the half push folded into `_cruise_speed` |

In plain words: *rest for five seconds after eating, and while less than a
third hungry. Otherwise turn toward an echo of something smaller than my
mouth; otherwise toward whatever my laser touches; otherwise, when the smell of
food fades, turn at random. Swim, and push at half strength.*

As the save writes it:

```
metabolism.fed below 5 -> body.rest
metabolism.hunger below 0.3 -> body.rest
ampulla.echo size below mouth -> body.turn-toward
ocellus.beam -> body.turn-toward
chemocyte.smell level falling -> body.turn-random
always -> body.swim
always -> axoneme.push 0.5
```

Rules 3 to 5 compete for steering, in that order. Rules for organs a founder
lacks are passed over, and wait, inherited, for a daughter who grows the organ.
One of the eight places is free.

`HUNT_AT` and `REST_MEAL` stop being constants of the water and become values
in each body's rules. `REST_MISS`, `ORIENT_SECONDS`, `COMMIT_RANGE` and the rest
of the run leave the drop. They stay for today's water (`--drop=0`) and for the
tool's reference (`--rules=0`, §12).

### 5.2 What each founder does with the senses it has

- **A nose** (`chemocyte`) swims, and turns at random whenever the smell of food
  it could swallow fades. That is run-and-tumble, which climbs toward food
  without ever knowing where the food is.
- **A radar** (`ampulla`) turns, at each echo from something smaller than its
  mouth, toward where the echo came from, and swims there. Between calls (8.8 to
  15.2 s by tier) it holds that heading.
- **A laser** (`ocellus`) turns toward whatever its rays stop on (a cell, a
  floc, you or the rim) and swims there. The rays sit on a diagonal arc, so the
  target leaves the beam as the body turns: it aims once, then swims at where
  the target was.
- **An eyespot** (`stigma`) **or a palp** alone: no founder rule reads them. The
  cell swims, and eats whatever it bumps into.
- **No founder dashes.** Today's lunge fires only at prey that is close, ahead
  and small enough for its mouth. A beam or a touch reports close and ahead, but
  never what it touched, so a dash on them could as well be a dash into the rim
  or into a bigger mouth. Only an echo also carries a size, and an echo comes
  back once a call. So the founders do not dash, and a family can learn it, for
  example with *an echo smaller than my mouth, within 30°, nearer than 220 µm →
  dash*.

### 5.3 What changes for the player

"Today's hunting" can no longer be exactly today's. In plain words:

- **No hunter knows where you are until a sense tells it, and none leads you by
  your true speed.** Nose hunters never chase you as such: they climb the scent
  of everything they could eat, and you are part of it. Radar hunters aim at
  you once per call, at where you were. Laser hunters turn onto you whenever a
  ray touches you, whether or not they can eat you.
- **The dodge changes.** Today a hunter commits inside 310 µm and runs straight,
  so turning away at that point escapes it. Now a hunter steers every tick by
  what it senses. You lose a radar hunter by turning between its calls, and a
  laser hunter by leaving its beam. One that follows your shadow or your touch
  stays on you. Pack 2's measured chase (a newborn that turned away escaped a
  hunter without an `axoneme` 10 times in 14, `lineage.md` §6.2) no longer
  holds.
- **At first, some hunters never chase anything.** A hunter that senses only by
  eyespot or palp has no hunting rule, although its mouth still swallows
  whatever it bumps into. No founder lunges.
- **A cell cannot tell that you are dangerous.** It turns away only from what
  its senses report: a shadow, an echo bigger than itself, a beam hit, a touch,
  a bite. It may run from a big harmless cell and swim straight into a small
  one with a big mouth, you included.
- **A hunter that turns onto you but cannot eat you is food**, if your mouth can
  take it.

---

## 6. A change at every division

### 6.1 Which daughter

`_divide` already makes a faithful DNA and a changed one (`Drop.daughter_dna`),
and tosses a coin for which daughter gets which. **The daughter who gets the
changed DNA also gets changed rules**: one change to her mother's. Her sister
carries her mother's DNA and rules unchanged. So every division leaves one
faithful daughter, as row 19 has it for the player, and a family always has a
line that is exactly its mother's.

The other two placements are worse. Putting the rules' change on the other
daughter would leave no line faithful. A single change that is either genes or
rules, by a coin, would halve the gene change pack 2's water is being played
with.

**The cost is that the changed daughter carries two changes.** `lineage.md`
§3.3 measured what changes cost a family at every division: without the newborn
grace the families wore out, and with it they held. On rules the grace protects
nothing (row 25, §4.3), so this is the first thing to watch (§13).

### 6.2 The change

One change, drawn from the global stream that `--seed=` seeds, as
`Genome.mutated`'s is, weighted by kind:

| kind | what it does | weight | why |
|---|---|---|---|
| nudge | one test's step, or one output's option, moves one place up or down its ladder | 5 | the small step: 30 % becomes 20 % or 40 %, and 220 µm becomes 130 or 350 |
| replace | one rule's input (with fresh tests), one of its tests (another test, or one added or removed), or its output becomes another | 2 | where new rules come from |
| swap | two neighbouring rules change places | 1 | order is half of what a list means |
| copy | a rule is copied in directly under itself | 1 | gene duplication. A copy under its original never fires, and is free to change later |
| drop | a rule is removed | 1 | lets the list shrink |

Every change must be valid and must change something. A rule has at most one
test on each value its input carries, a turn needs an input with a bearing, and
a list holds one to **eight rules**, the most one phone screen shows (§11). A
nudge at the end of a ladder goes the other way, a replace draws a different
part, and a swap of two equal rules is drawn again. Nothing is protected: a
change can leave a body that never hunts. It still eats whatever its mouth
touches, and its sister is a copy of its mother.

### 6.3 What a change draws from

**The parts declared by the body, by its metabolism, and by every gene in its
DNA**, whether the body wears that gene or only carries it. A rule for an organ
the DNA carries but the body does not wear can come alive in a daughter who
expresses it (copies are a chance: 55 %, 80 % or 100 %), so rules and genes
travel together. Drawing from every gene in the game would spend places on
organs a family has never had. And what a family can learn still grows with
what it eats, because a meal writes new genes into the DNA (`lineage.md`
§3.2).

### 6.4 What the water makes, the sister, the player

- **The spawner's founders carry the founders' rules** (row 22). The founders
  made to hold the floor keep bringing them back. So a sighted player's water,
  where a third of the hunters are the spawner's (`lineage.md` §6.1), will
  change least.
- **The player's sister carries the founders' rules.** The player has no rules
  in pack 3; from pack 4 the sister carries the player's. A guest's sister also
  carries the founders' rules, because SISTER carries her body and nothing else
  (`lineage.md` §8).
- **A `Body.brain` of null means the founders' rules.** A founder, a sister, a
  posed body and a body from an old save all carry them without a copy. A
  change writes a new list, and a faithful daughter shares her mother's.

### 6.5 Starting values

None of these was measured. Each one is where the playtest starts.

| | starting value | why | watch for |
|---|---|---|---|
| the founders' values | 5 s, 30 %, push at half | today's `REST_MEAL`, `HUNT_AT` and cruise speed | -- |
| how often | at every division, on the daughter whose DNA changed | row 19 | hunters that stop hunting; families thinning while the spawner makes more of the hunters |
| the kinds | nudge 5, replace 2, swap 1, copy 1, drop 1 | mostly small changes | a water that never changes (raise replace), or one that cannot keep a way of hunting (raise nudge) |
| the most rules | 8 | one phone screen (§11) | families stuck at eight, unable to copy |
| the ladders | §3.1 | about the same proportion at each step, and plain for pack 4 | -- |
| leading | three times the bearing's drift | the textbook navigation constant | hunters that overshoot, or still trail behind you |
| a new target | a bearing that jumps more than 30° (`LEAD_JUMP`) | the spec named no number; the build chose it | laser hunters that over-lead while their ray stays on you |
| a random turn | 90° to 180° to a random side | a tumble, or the avoiding reaction | cells spinning in place |
| coming for you | within 35° of its heading | half today's `LOCK_CONE_DEG` | darts spent on cells passing by |
| a dart's stun | 5 s | today's rest after a dart | -- |

---

## 7. What to expect, and what the player sees

### 7.1 What the water can learn

None of this was measured. These are what the vocabulary lets a family find, a
few changes away from the founders' rules:

- **Hunting sooner or later**: rule 2's 30 % nudged.
- **A lunge**: a dash rule on an echo or a beam hit that is near and ahead, the
  change a player would feel first.
- **The other way round**: *a beam hit → turn away* in place of rule 4, the
  owner's example: cells that steer clear of anything their laser touches, you
  included.
- **Running from what they sense**: turning away from a shadow, an echo bigger
  than themselves, a touch or a hit (row 23).
- **Pushing harder or not at all**: rule 7 nudged to full, or dropped.
- **Waiting**: a rest in place of rule 6, with a turn toward whatever comes
  near.

**What would be bad**: a family that never hunts and still holds the water; one
that runs from everything and starves; cells spinning on random turns; or the
opposite of learning, where changes pile up faster than they are sorted out
(`lineage.md` §3.3's mutational meltdown).

**Nothing new runs away** (`lineage.md` §13.2). A list is at most eight rules,
and there are at most as many lists as hunters. What behaviour can change is how
many hunters the food feeds, and each hunter costs about 45 µs a frame on a
phone (`lineage.md` §7). The dev readout's `stepped` row shows it.

**How many behaviours hold the water.** Behaviour rides with families. In pack
2, 3 to 12 families held a newborn's water after thirty minutes (`lineage.md`
§13.5), so a handful of lists and their near variants should hold it. At a
sighted player's composition, the spawner's third keeps the founders' rules
common.

### 7.2 Would a person notice?

A generation is about 30 s (`lineage.md` §13.8). So a newborn's drop is 23 to
26 generations deep at fifteen minutes and 43 to 50 at thirty, with its deepest
lines at 60 to 66 (`lineage.md` §6.1, §13.8). A line 25 generations deep has
come through up to 25 changes, and about half that if changed daughters live as
well as faithful ones. A person would see cells, not rules: one that lunges as
you pass, one that steers clear of you, one that sits still. At a sighted
player's composition there is much less to see. The founders themselves already
differ from pack 2's hunters (§5.3), and the owner will notice that first, in
phase 3-1.

### 7.3 What is drawn

**Nothing new** (row 24). A behaviour shows as motion in both views. The dev
app's frame readout gains two rows in its own grammar, under `generation` and
`families`: `behaviours`, how many different lists the hunters carry, and
`unchanged`, the share of hunters still on the founders' seven rules, in
percent. Only the dev app draws them, and they are not translated.

---

## 8. Saves, the shared pond, the server, the replay

**Saves.**

- **Saved by declared name** (`ocean.md` §12). `drop` gains an optional
  `behaviours` entry, `{"version": 1, "lists": [...]}`, each list its rules in
  the text of §5.1.
- **`drop.bodies` gains optional columns**: `behaviour`, one int per body (−1
  is the founders' rules, for drifters, flocs and every body still on them, and
  any other value indexes the lists, so a family's shared list is saved once);
  and what a body was doing (its steering heading, its stun, the time since it
  ate, and its echoes in flight), with clocks kept in 64 bits as every clock is.
  Each is checked when present, as pack 2's columns are, and `FORMAT` stays 1.
  As built, the columns also carry its last actions, its push, its tumble, the
  hit it felt, its call's clock and its rules' memory, because a drop saved and
  loaded has to go on as one that never stopped. The time it ate is kept as the
  drop clock's time of its last meal, so the round trip is exact to the bit. A
  list of an unknown version loads as the founders' rules rather than making
  the file unreadable.
- **Old saves.** A pack-2 file loads every hunter on the founders' rules, with
  `fed` set from its `calm`, so a body resting after a meal or a miss rests on.
  A pack-2 build reading a pack-3 file loads the rest and runs its own
  hand-written hunter.
- **A name this build does not know**, such as a gene from a later content pack,
  loads as a rule that never fires, and is written back as it came, as a
  retired gene is kept (`genome.gd`, `GENE_ORDER`).
- **A room that runs for days** adds nothing that grows: at most eight rules a
  list and one list per hunter. The size was not measured; pack 2's four
  lineage columns added 3.3 KB to a compressed save (`lineage.md` §4).

**The shared pond and the server.**

- **Behaviour is the host's water.** A host's drop and the server's room read
  the rules and change them at division. A guest's mirror draws bodies from
  snapshots and decides nothing, and a guest's own drop is set aside while it
  is away. A dedicated server, the last to update, loads its pack-2 room with
  every hunter on the founders' rules and its genes as they were.
- **Nothing new goes on the wire.** The "stalking you" bit in each POND entry
  now means "coming for you" (§4.3), computed by the host for each guest, for
  the bodies within the send reach (1,900 µm). Pack 2 flagged every hunter on a
  run at the guest, wherever it was. A water cell's call is heard by nobody, and only a player's call
  crosses the wire, as today (§14).
- **The referee judges a guest, never a water cell**, and nothing it copies
  moves. None of `HUNT_AT`, `REST_MEAL`, `REST_MISS`, `COMMIT_RANGE` or
  `LOCK_CONE_DEG` is in `net_probe`'s `_rules_text()`. **`Wire.PROTOCOL` stays
  5 and `Wire.RULES` stays `46913eab…`**, which the build shows with `net_probe
  --referee-only` (§12.3). Mixed builds play together, and whether the water
  learns depends on the host's build.

**The replay** records what moved, and a behaviour shows as motion, so nothing
new is recorded. The hunter slot reads "coming for you".

---

## 9. Cost

**Measured as built, in phase 3-1, on this container.** After one optimisation
pass, the drop's frame went from 1.80 ms to 2.39 ms at a 0.6 composition, and
from 2.31 ms to 3.39 ms at 1.0. That is +0.6 to +1.1 ms, several times the
estimate below. It is mostly GDScript call overhead, about 13 µs for each of 24
to 37 decisions a frame, plus the scent sums. At `ocean.md` §4.4's assumed
factor of six, a phone pays +3.5 to +6.5 ms. Pack 1's phone gate read 0 %
dropped frames, and the dev app's `dropped` and `water` rows decide whether that
still holds. A further optimisation pass is the lever. `drop_probe` now takes
about 200 s, and CI's timeout for it is 600 s.

What follows is the design's estimate, reasoned from the code before the build.

- **Today**, each hungry hunter makes one prey search on its tick, out to its
  senses' reach, and each hunter on a run is stepped through stalk, aim and
  intercept on every frame it is stepped. Pass 2 timed these at 88 µs a frame
  for hunters looking for prey and 67 µs for hunters on a run (`ocean.md`
  §4.4).
- **Now**, each hunter reads on its tick only the senses its rules reach, each
  at most once, and only for organs it wears. `smell` is a scent sum out to its
  smell reach, about one of today's prey searches. `beam` is one to three rays
  against the bodies within 620 to 1,240 µm. `shadow` and `touch` are
  short-range questions to the grid. `echo` costs nothing on the tick: one cast
  every 8.8 to 15.2 s, with at most five returns. `hit`, `hunger` and `fed` are
  fields of the body. Nothing is stepped through a run any more: between ticks
  a body only turns toward the heading it holds.
- **Estimate**: about what today's search and run cost together. Where a hunter
  reads two senses, the extra is up to one more prey search per decision: of
  the order of 0.1 ms a frame here, and 0.5 ms on a phone at `ocean.md` §4.4's
  assumed factor of six. The rule tests add of the order of 50 µs a frame here.
  For scale, pack 2's water was put at 8 to 10 ms of a phone's 16.7 ms frame
  (`lineage.md` §7).
- **A division** copies nothing for the faithful daughter, and makes one list of
  at most eight short rules for the other.
- **`binary_version` is unchanged.** It is all GDScript, a content pack.

---

## 10. Generic mechanics, names at the edges

| file | knows | does not know |
|---|---|---|
| `game/mechanics/rulebook.gd` **new** | declared inputs (bearing or not, values of a kind), outputs (the triggers they claim, their needs, their options), the kinds and their ladders, and tests. **Choosing**: from the top, one winner per trigger, with each input read at most once a tick through a callable the caller hands it. **One change** (§6.2) from a vocabulary it is handed. A list to and from text by declared names, with unknown names kept inert | genes, cells, senses, the water |
| `game/normal/genome.gd` | `DECLARES`: each gene's inputs and outputs (§3.1) | how a sense is computed |
| `game/normal/cell.gd`, `game/normal/metabolism.gd` | the body's own parts (`hit`, the turns, swim, rest) and the metabolism's (`hunger`, `fed`); the dart's stun beside the dart's tables | how a list is read |
| `game/normal/drop.gd` | this water's choices: the founders' rules (§5.1), the kinds' weights, the cap of eight, and `daughter_behaviours(list)` → `[faithful, changed, kind]` beside `daughter_dna` | how a list is read or changed |
| `game/normal/food.gd` | the wiring: each declared name to the function that reads it for a body, or performs it. Every sense is one function of an observer, serving your membrane and a water cell alike. Also the body's heading, swim, push, dash and rest; "coming for you"; `_decide` reading the body's list; `_divide` handing lists on; the save's columns | the arithmetic of a list |

A second water writes its own founders' rules in its own environment file. A
second kind of body, the player in pack 4, reads the same lists through the
same `rulebook.gd`, with its own wiring.

---

## 11. What pack 4 needs from these blocks

Named here, not designed.

- **The player's blocks are the same inputs and triggers**: what the player's
  own genes declare, plus the body's and the metabolism's parts. The player's
  run wires them to the player's organs, which already post exactly these
  sensations to the membrane. Pack 4's screen lists what the player's genes
  declare, and nothing else.
- **The triggers map onto `_read_steer()` and the controls.** The turns become
  steering, push the push and dash the dash. Swim and rest drive the flagellum,
  which today beats on its own (`energy.md`). That is the one trigger the
  player's hand lacks, and whether blocks may stop it is the owner's call then.
- **A screen holds eight rules.** On 1600×720 a rule is one row of 48 px chips
  (an input, up to three tests and an output), and eight rows with 12 px
  between them fit in under 480 px of the 720.
- **The names are the owner's**, through `tr()`. The chips come from the
  declarations, so a new gene needs words, not a new screen.
- **Your division changes your rules** under row 19: one daughter keeps them and
  the other carries one change, so the choosing screen would show both. Row 19
  decides it, and pack 4 confirms it with the owner once the screen exists.
- **Your sister carries your rules.** A guest's sister would need SISTER to
  carry them, which is the next protocol change.
- **No block reads dread or the wake** (§3.4).

---

## 12. Build plan

### 12.1 Files

| file | change |
|---|---|
| `game/mechanics/rulebook.gd` | new (§10) |
| `game/normal/genome.gd` | `DECLARES` (§3.1) |
| `game/normal/cell.gd`, `game/normal/metabolism.gd` | the body's and the metabolism's declarations, and `DART_STUN` 5 s |
| `game/normal/drop.gd` | the founders' rules, the kinds' weights, the cap, `daughter_behaviours` |
| `game/normal/food.gd` | **Every sense as one function of an observer**: the player's smell, beam, shadow, touch and ping run from any body's place, heading, size, mouth and organ arcs, and the player's membrane gets exactly what it gets today. **The water**: a ping clock and echoes in flight for each water cell with an `ampulla`; the readers and triggers registered by declared name; `Body.brain` put to use (null is the founders'); the held heading, swim, push, dash, rest and stun; `fed`; `_decide` reading the list. The run is kept only for `--drop=0` and `--rules=0`. "Coming for you" for the wake, the darts, `hunter()` and the pond flag. `_divide` hands the changed daughter `Drop.daughter_behaviours`. `drop_state` and `load_drop` gain the columns. A behaviour line beside the lineage line, and `behaviour_counts()` for the readout |
| `game/normal/normal_mode.gd` | the player's senses through the shared functions, posting what they post today |
| `game/normal/drop_save.gd` | the optional entries, each checked when present |
| `game/dev/frame_readout.gd` | `behaviours` and `unchanged`, in the dev app only |
| `tools/eco_probe.gd`, `tools/drive.gd` | `--rules=0` (pack 2's hunter and everything §12.4 replaces: the reference), `--rule-change=0` (no change at division), and the behaviour line |
| `tools/drop_probe.gd` | the checks in §12.3 |

**Nothing** changes in `addons/launcher/`, `ci/` or `project.godot`. **No
player-facing text**: nothing new goes through `tr()` or into
`game/i18n/biogenic.pot`. The readout's rows belong to the dev app and are not
translated.

### 12.2 Phases

Each phase is one pull request into `dev`, played on the dev app before the next
one starts.

| phase | contents | what the owner can try |
|---|---|---|
| **3-1** | cells sense and hunt by rules: the declarations, the rulebook, every sense shared with the player, the triggers, the founders' rules on every hunter, "coming for you", the dart's stun, the save's entries, and checks 1 to 3, 7, 9 and 10 | a water whose hunters know only what their senses tell them. Nothing learns yet |
| **3-2** | the rules change at division: the change, the readout's two rows, and checks 4 to 6 and 8 | a water that learns. Play it new, then come back after fifteen minutes and after an hour |
| the release | | whenever the owner runs it |

No `Wire.PROTOCOL` change, and no `binary_version` bump.

### 12.3 What the build checks

`drop_probe`'s "Check the drop" step gains these checks, each of which must fail
with its rule taken out:

1. **With rules off, it is pack 2, to the byte.** With `--rules=0`, the drop's
   census and lineage lines, and the membrane's trace from a seeded `drive.gd`
   run, equal `dev`'s. In CI: seed 1, five minutes, at both compositions. This
   pins the senses shared between the player and the water.
2. **A water cell reads what your organs would.** Pose a water cell and the
   player alike (place, heading, size, genome, arcs): their smell, beam,
   shadow, touch and echoes are equal to the float.
3. **No magic.** An input of a gene the body does not wear never reports, and
   no reader is handed anything but its observer and the bodies its organ
   reaches, which check 2 holds it to.
4. **Every change is valid.** Ten thousand changes, from the founders' rules
   and from random lists: each holds to §6.2's limits, differs from its parent,
   and survives the text round trip.
5. **A division.** The daughter whose DNA changed carries rules one change from
   her mother's, and her sister carries her mother's. Founders, sisters and
   posed bodies carry the founders' rules.
6. **Determinism.** One seed run twice with changes on gives the same lines.
7. **The save.** A round trip with the new entries is exact to the bit, and a
   drop saved and loaded goes on to the same census as one that never stopped
   (`ocean.md` §14.3 check 12). A pack-2 file loads with every hunter on the
   founders' rules. An unknown name loads as a rule that never fires, and is
   written back as it came.
8. **Modular.** A test gene, declared only in the probe with one new input and
   one new output, and with its reader and trigger registered by the probe, is
   in the vocabulary of a body that carries it, is drawn by mutation, is read
   and acted on by a rule, and is saved and loaded by name. None of this needs
   a change to `rulebook.gd`, `drop.gd`, `drop_save.gd` or any list.
9. **The founders hunt.** In five minutes of the drop each founder rule fires,
   and hunters that have each of the nose, the radar and the laser eat at least
   once. This checks that the rules are alive, not how well they hunt.
10. **Coming for you.** With posed bodies, the wake and the dart fire for a cell
    swimming at you within 35° whose mouth could take you, and not for one
    swimming past or one too small to eat you. A dart stuns for 5 s.

`net_probe`: the referee section passes unchanged, and so does `pond-field` with
the host's water running on rules.

### 12.4 What it replaces

| pack 2 | pack 3 |
|---|---|
| `_decide` and the run, for every mouth | each hunter's rules over its senses, with pack 2's hunter kept as a tool's reference (`--rules=0`) |
| finds the nearest thing it can eat within reach, then leads it on its true place and speed | turns toward what a sense reports, and leads only by a sensed bearing's drift |
| `HUNT_AT`, `REST_MEAL` | values in each body's rules |
| `REST_MISS` | gone, because there is no miss; its 5 s is now a dart's stun |
| one `calm` after a meal or a miss | `fed`, the time since its last meal |
| cruise with half the push folded in | swim, plus push as a trigger (the founders push at half) |
| a lunge on every run | a dash when a rule says so |
| a hunter never runs | it can turn away from what a sense reports (row 23) |
| "hunting you" means on a run at you | "coming for you" (§4.3) |
| a dart breaks off a run: 5 s of rest | a dart stuns: 5 s with its rules unread |
| `Body.brain` reserved and null | a behaviour; null means the founders' |

---

## 13. What to watch in the playtest

**In phase 3-1, before anything learns**: whether hunters still find food or
starve while they wander; laser hunters turning onto you, or onto the rim;
radar hunters coming in at where you were; nose hunters zig-zagging their way up
to food; and whether you are caught more or less often than in pack 2, and how
you get away.

**In phase 3-2, at fifteen minutes**, in a new drop as a newborn: `unchanged` on
the readout should fall, and if it stays near 100 %, nothing is learning. Look
for a hunter that lunges as you pass, cells that steer clear of you or of each
other, and hunters sitting still that swallow you when you bump into them.

**At an hour**: `behaviours` on the readout, where a handful means a water that
settled on what works and dozens means one still trying, or unable to keep
anything; families that never chase and still fill the water; and the `water`
row against pack 2's.

**In the server's room, over days**: whether it keeps changing or settles, and
whether one behaviour takes over the whole room.

---

## 14. Left open

1. **Nothing here was measured**, by the owner's choice. Whether behaviour
   evolves within fifteen minutes or an hour, what it evolves toward, the danger
   to the player and the cost on a phone are all for the playtest.
2. **Your dread and your wake read other cells' mouths.** Your membrane still
   feels both, and "coming for you" (§4.3), which decides when your dart fires,
   reads the same thing. No rule can read them, so pack 4's blocks will not
   either. Whether the player keeps them is the owner's call, later.
3. **No organ tells a cell that a mouth is bigger than it.** Real ciliates do
   smell their predators: *Euplotes* takes a shape that is harder to swallow
   when it smells *Lembadion*
   ([Induction of defensive morphological changes in ciliates](https://link.springer.com/article/10.1007/BF00566974)).
   A later sense gene could declare that input. Nothing is added in this pack.
4. **Nobody hears a water cell's call.** You hear a friend's ping. Water cells
   now call for their own echoes, but nobody hears them, and hearing them would
   be new on the membrane and on the wire.
5. **Where a water cell's senses point is fixed** by the default order (§4.4). A
   layout, and the player's shift with it, needs the order on the wire and in
   the replay: the next protocol change.
6. **The chase is no longer a contract** (§5.3). How you escape is the
   playtest's to judge.
7. **The changed daughter carries two changes** (§6.1). If families thin out,
   the levers are how often rules change, and which daughter carries the change.
8. **Drifters decide nothing**, and a guest's sister arrives on the founders'
   rules until SISTER carries hers.
9. **The cost on a phone** (§9) is several times the estimate here, and is the
   dev app readout's to judge.

---

## 15. Owner's calls

The rows are numbered on from `lineage.md`'s rows 19 to 21, so that one row
number names one call across the three documents. They are shown as they were
put, and as they were answered on 2026-10-02.

| # | Question | Options | What it means |
|---|---|---|---|
| 22 | What do the cells the water makes know how to do? | **today's hunting ✓ answered** · today's, with a few random changes each · random rules, as you first described | Today's: a new drop behaves exactly as it does now, and only the cells born in it change, one small change at every division. A few random changes: a new drop is varied from the first minute, and some of its cells hunt worse than today's. Random: a new drop starts harmless, since most of its cells hunt badly or not at all and starve, and it gets dangerous as the families that work fill it. The cells the water adds to keep the drop alive stay random too, so a drop made for a player with good senses, where a third of the hunters are those, never gets as good. Untested: a starting point the playtest judges. |
| 23 | Can cells learn to run from danger? | **yes: a cell's rules can make it swim away from a mouth that could swallow it, yours included ✓ answered** · no: in this pack cells only rest, search and hunt | Yes: families can learn to turn and swim away from bigger mouths, at their own speed, and that includes yours once you are big enough to eat them. A cell with no sense that reaches you can only turn sharply at random. The hunters you chase may get harder to catch, and hunters that would have been eaten live longer. The drifters you mostly eat never run, because they decide nothing. No: no cell ever runs, as today. Untested: a starting point the playtest judges. |
| 24 | Do you see what the water's cells are doing? | **not in this pack: you see them move, and the dev app counts how many ways of behaving the water has ✓ answered** · full vision marks each cell that is resting, hunting or running | Not yet: behaviour shows only in how cells move, and it can be marked later without changing anything else. Marked: in full vision you would read each cell's intent at a glance. That is a screen of its own for the UX designer, and the replay would have to record it. |

**Answered on 2026-10-02.** The owner, verbatim:

> All recommended. But blocks can only contain things coming from enabled senses. If it cannot say whether my mouth is bigger, it cannot run. And currently, it cannot know that using available senses. No magic info. The cell has inputs and produces output that acts on available triggers (turn, dash)

and later the same day:

> By it cannot run, I mean it can, but not because my mouth is bigger. Its behavior could still be turn away when laser touches something in front of it
>
> The design of the blocks must be modular. Any new added gene could declare inputs and outputs so we don't have to create manually new blocs

So rows 22 to 24 stand as recommended, and the three rules reshaped the design:

- **Inputs are only what senses report**, in the form they report it (§3.2).
  Dread and the wake are not inputs (§3.4); the design as put had given every
  cell its dread, with no organ needed.
- **Outputs are the triggers** (§3.3). Fleeing is an ordinary rule, *turn away*
  from what a sense reports. So row 23's "yes" now means that turning away is
  in the vocabulary, not that a cell knows your mouth is bigger.
- **Today's run goes, and hunting is rules over senses** (§4.2, §5). Row 22's
  "today's hunting" is the closest the senses allow: seven rules, not exactly
  today's (§5.3).
- **Genes declare the blocks** (§3). There is no hand-written vocabulary.
- **The check that the founders replay today's hunter to the byte cannot hold,
  and is gone.** The build checks instead that the drop is pack 2's to the byte
  with rules off, that a water cell reads what your organs would, and the rest
  of §12.3.

**No new rows in the revision.** Everything it raised is decided by the owner's
answer or by an answered row. The player's own dread and wake, and whether
pack 4's blocks may stop your flagellum, are the owner's calls later (§11, §14),
not this pack's.

**Not asked, because the owner's answers or answered rows decide them:** a
division changes a daughter's rules together with her genes (row 19); a rule
reads nothing the organs do not report ("No magic info"); the founders' rules
are today's hunting under that rule (row 22); a cell turns away from what it
senses, never from what it cannot know (row 23); nothing new is drawn (row 24).

**Settled here, not asked:** a water cell's senses stay where the default order
puts them (§4.4), because a layout needs the wire and the replay first; and
"coming for you" replaces "on a run at you" (§4.3), so your wake and your dart
keep working, from cells that come at you.

### 15.1 Raised by the build, answered

Phase 3-1 found that the grace no longer protects anything (§4.3): it stopped a
run from starting, and there are no runs. Put and answered on 2026-10-02:

| # | Question | Options | What it means |
|---|---|---|---|
| 25 | Now that hunters follow only their senses, what protects a newborn, you included, in its first 42 seconds? | **nothing: newborns are sensed like any other cell ✓ answered** · hunters' senses can't find a newborn for 42 s · a newborn can't be swallowed for 42 s | Nothing: a hunter that senses you can come for you the moment you're born, but it is a weaker hunter than pack 2's, with no lead and no lunge. Can't be found: closest to today's 42 s of safety, but a hunter you bump into can still swallow you. Can't be swallowed: newborns are completely safe for 42 s, which is stronger than today. |

The owner, verbatim: *"25 as recommended"*. `lineage.md` §3.3 found that
families wore out without the grace when every division changes a daughter, so
it is the first thing to watch when 3-2 turns the rules' changes on (§13).
