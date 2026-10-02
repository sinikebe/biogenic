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

The owner's standing rules bind it as they bound pack 2: *"all cells follow the
same rules. Me, friends, NPC, doesn't matter."* -- *"A cell dies of hunger,
nothing else. Unless it gets eaten by another one."* -- *"Don't go too far with
ensuring a player lives as long as today. I'll playtest it and tell you how we
can fix that."* -- and row 19, *"every division. No specific treatment between
NPCs and players"*. So behaviour only decides when and how a body uses the
organs it has. A division changes one daughter's behaviour as it changes her
genes. The player's survival is the playtest's to judge.

---

## 0. What packs 1 and 2 left

**One hand-written behaviour for every mouth.** In the drop, a water cell with
a `cytostome` decides on its tick, 7.5 times a second near the player or far
from it (`ocean.md` §4.3), in `food.gd`'s `_decide(index, b)`, and only while it
is not on a run:

- it **rests** while it is digesting or fed. That means `calm > 0` (5 s after a
  meal, `REST_MEAL`, or after a miss, `REST_MISS`) or `hunger < HUNT_AT` 0.3.
  Resting, it drifts with the water at 9 µm/s, which is free, and still turns on
  anything it can eat that touches it (`_look_in_drop` with reach 0);
- otherwise it **hunts** the nearest thing it can eat that its own senses find
  (`_look_in_drop` at its senses' reach). The hunt is a committed run: it turns
  to face the prey at its `cirrus`'s rate (`ORIENT_SECONDS` 8 at most), stalks,
  intercepts, dashes on its `myoneme` inside `LUNGE_RANGE`, and is committed
  inside `COMMIT_RANGE`, until a meal or a miss;
- otherwise it **searches**: it swims along a wandering heading at its own
  tail's speed, and pays for it.

Drifters decide nothing. `ocean.md` §5.4 has what each piece is worth. §16 item
9 there left the defaults to this pack, "chosen so that the rules work, not
tuned". `CALM_*` and the flight after a miss belong to today's water
(`--drop=0`, a tool's reference) and to the tool switch `--flight=all`. The
drop's own rules never read them, and this pack leaves them as they are.

**The hooks** (`ocean.md` §12, `lineage.md` §10):

- `Body.brain`, reserved and null;
- `_decide`, "the entry pack 3's blocks take over";
- `_divide`, the one place a body becomes two, where "a brain is copied ...
  mutated by the blocks' own operator";
- `_spawn`, the one door every body comes in by;
- `cell.gd`'s `_read_steer()`, where pack 4's blocks would steer the player.

---

## 1. Decided, in one place

1. **A behaviour is an ordered list of rules**, at most eight. Each rule reads
   *when <reading> <above|below> <value> → <action>*. The list is read from the
   top on the body's tick, while it is not on a hunt. The first rule whose test
   passes and whose action has something to act on is what the body does until
   the next tick. Final Fantasy XII's gambits are the model (§2).
2. **A rule reads only what the body's own organs give it** (§3): its hunger,
   how long since it ate and since a chase failed, how near the nearest food its
   senses find is, and how near the nearest mouth it dreads is. No rule names an
   organ. An organ the body lacks gives nothing, so the same rule reaches as far
   as the body's organs do.
3. **A rule does only what the organs can** (§4): rest, search at a share of its
   own speed, hunt the nearest or the biggest food, or flee. A hunt is today's
   run, unchanged, and once begun it runs to a meal or a miss.
4. **Today's behaviour is five rules** (§5). Every body the water makes, every
   sister and every body in an old save carries it (row 22, recommended). Read
   as rules,
   today's water plays exactly as it does now, and the build checks that to the
   byte (§12.3).
5. **Every division changes one daughter's behaviour**: the daughter whose DNA
   it changes. She gets one small change: a value nudged, a part replaced, two
   rules swapped, or a rule copied or dropped (§6). Her sister carries her
   mother's behaviour and DNA unchanged. This is row 19's rule, and the water
   has no rate of its own.
6. **Cells can learn to flee** a mouth that could swallow them (row 23,
   recommended).
7. **Where a gene goes stays the body's.** A water cell's meal takes the first
   free slot, as in pack 2, so its mutation is still never a shift (§4.4).
8. **Drifters decide nothing**, as today. They never grow, so they never
   divide, and a behaviour could never pass on from one.
9. **Players see nothing new except how the water behaves** (row 24,
   recommended). The dev app's readout counts it in two new rows, `behaviours`
   and `as today` (§7.3).
10. **Saved by name and version** (§8). A pack-2 drop loads every hunter on
    today's behaviour.
11. **No protocol change.** The referee judges guests, never a water cell's
    behaviour, and nothing it copies moves. `Wire.PROTOCOL` stays 5 and
    `Wire.RULES` stays `46913eab…` (§8).
12. **The list and the change are generic mechanics**, in
    `game/mechanics/rulebook.gd`. The vocabulary's names are `drop.gd`'s, and
    what each reading and action means in the water is `food.gd`'s (§10).
13. **Two phases, no binary change**: today's behaviour as rules first, then
    behaviour that changes (§12).

---

## 2. What a behaviour is

### 2.1 Four candidates

A behaviour has to do three things:

- run for every hunter in a drop, on a phone, 7.5 times a second. In pack 2 a
  newborn's drop held up to 158 hunters and a sighted player's about 200
  (`lineage.md` §2.2);
- change in small steps that usually leave it working;
- be built by a player in pack 4, on a 1600×720 landscape canvas, with 48 px
  targets, in the game's plain words.

It also has to hold today's behaviour exactly, or the change cannot be checked
(§12.3).

| candidate | what a decision costs | a small change | can a player build it | today's behaviour, exactly |
|---|---|---|---|---|
| **an ordered list of when → do rules** (Final Fantasy XII's gambits) | at most eight tests. A costly reading, such as a prey search, is made only when a rule reaches it | a value nudged, two rules swapped, or one rule copied, replaced or dropped. The rest of the list stays as it was | yes: one row per rule, two chips to a row, eight rows to a screen. Console players learned it in 2006 | yes: five rules (§5) |
| a behaviour tree | a walk of the tree, about the same | replacing a subtree changes a whole branch, and trees grow without use (genetic programming's "bloat") | depth needs panning, and "selector" and "sequence" are not plain words | yes, but only as a tree whose root is the list above |
| weighted steering (context steering, Braitenberg's vehicles) | a sum over stimuli, cheap | smooth: a weight moves a little | a weight is not a plain word, and what a sum will do is hard to foresee | no. Today's hunt is a committed run in phases, and the player's dodge lives in those phases (`food-and-predators.md` §5.4.1) |
| a small neural net | about a hundred multiply-adds a decision, in GDScript | smooth | nobody can build or read one | only approximately |

**The list wins.** It is the only candidate a player can build that also holds
today's behaviour exactly, and it changes in steps that mostly keep it working.

- **The tree** loses on the screen. Nothing is lost by passing it over: a list
  is a tree one level deep, so pack 4 can later let a rule hold a list.
- **Steering** loses the regression check and the dodge. It lives on inside
  one action: a flee steers away from a bearing.
- **A net** loses everything a player would touch.

Robotics calls this shape subsumption: behaviours in priority order, a higher
one suppressing those below it ([Brooks, *IEEE J. Robotics and Automation*
1986](https://doi.org/10.1109/JRA.1986.1087032)).

### 2.2 The real mechanisms are the blocks

Real ciliates and bacteria behave through a handful of named mechanisms
(Fraenkel and Gunn, *The Orientation of Animals*, 1940; Jennings, *Behavior of
the Lower Organisms*, 1906). Each one is already an action or a reading here:

| mechanism | what a real cell does | here |
|---|---|---|
| positive taxis (chemo-, photo-, thigmo-) | steers up a stimulus toward its source | **hunt**: turns onto food that its nose, eye, radar or palp found, and closes |
| negative taxis | steers away from a noxious stimulus | **flee**, when a sense gives it a bearing |
| the avoiding reaction (*Paramecium*) | on a bad stimulus, backs off, turns to a new heading at random, and swims on | **flee** with no bearing. A body whose senses do not reach the danger feels it only as dread, and turns sharply to a random side |
| orthokinesis | swims faster or slower with the strength of a stimulus, or with how starved it is (starved ciliates swim faster: `ocean.md` §5.4) | **search** at a share of its own speed, chosen by hunger |
| run-and-tumble (*E. coli*) | runs straight, tumbles to a random heading, and tumbles less while things get better ([Berg and Brown, *Nature* 1972](https://www.nature.com/articles/239500a0)) | **search**: a run along a heading that the water turns at random |
| satiation | a fed cell slows down and stops feeding | **rest** while fed or digesting |

Nothing in the vocabulary is invented. What the game adds is the order. A real
cell's mechanisms run in parallel and their effects add up. Here the first rule
that fits wins, because a player can read an order and cannot read a sum.

---

## 3. What a rule reads

| reading | what it is | where it comes from | values (the ladder a change steps along) |
|---|---|---|---|
| `always` | nothing: the rule always passes | -- | -- |
| `hunger` | the tank: 0 is fed, 1 is empty | the body. The player feels it as the beat | 10 % to 90 %, in tenths |
| `since a meal` | seconds since its last meal: a cell, a floc, or you | the body | 1, 2, 3, 5, 8, 13, 21, 34 s |
| `since a miss` | seconds since one of its hunts ended without a meal | the body | the same |
| `food` | how near the nearest thing it can eat is, among what its senses find: 1 when touching, falling to 0 at the edge of its senses' reach, and 0 when nothing is found | its senses, as today: `chemocyte`, `ampulla`, `ocellus`, `palp`, and `stigma` for a body big enough to cast a shadow. Touch, without any of them | 10 % to 90 % |
| `danger` | how near the nearest mouth is that could swallow it, armour counted, you included: 1 when touching, 0 at 1,400 µm (`DREAD_RANGE`) | the membrane, as dread is the player's. Every body feels it. None knows its bearing without a sense that reaches it | 10 % to 90 % |

**A rule tests a number. Where a thing is goes to the action that needs it.** A
hunt turns onto its prey, and a flee turns away from its danger. The run inside
a hunt is today's, and leads its prey as today's does. No rule ever reads a
position.

**A sense the body lacks.** No reading names an organ, so no rule can name one
the body lacks. An organ it lacks simply gives nothing:

- a body with no sense finds food only by touch;
- it feels danger only as dread, with no bearing to flee by, so its flee is the
  avoiding reaction.

The same rule, in a daughter that gains a nose, reaches 1,100 µm. That is
where behaviour and genes meet. A family whose rules hunt from afar lives by
its senses, and a family whose rules wait for food to touch it does not need
them.

There are no organ-named readings because today the water's senses are one
reach (`Body.notice`). Five organ-named readings would put five times the
vocabulary on a phone screen, for a choice the water does not make. Pack 4 can
add one ("when my radar hears…") if its screen wants it (§11).

**Its own speed and turn are not readings.** They are what its actions set, so
no rule has a use for them that the actions do not already have.

**Each reading is read at most once a tick, and only when a rule reaches it.**
`food` is one prey search: the same search today's decision makes. `danger` is
one grid question out to 1,400 µm. The others are fields of the body.

---

## 4. What a rule does

| action | what the body does | what it needs | the organs it uses |
|---|---|---|---|
| `rest` | drifts with the water at 9 µm/s, for free, and turns off the shore as today. It turns on anything it can eat that touches it. This is today's look with reach 0: "calm suppresses seeking, not opportunity" | -- | the contact |
| `search` at ¼, ½, ¾ or full | swims at that share of its own speed along a heading that wanders at random, paying for every stroke | -- | `flagellum` and `axoneme`, as today's search |
| `hunt` the nearest or the biggest | today's run, at the nearest food its senses find or at the biggest one that fits its mouth (ties go to the nearest) | food found | `cirrus`, tail, `myoneme`, mouth: today's run |
| `flee` | swims away from the danger at its own speed, turning at its `cirrus`'s rate and paying for both. It dashes on its `myoneme` when the danger is within lunge range (220 µm). If no sense reaches the danger, it does the avoiding reaction instead: a new heading 90° to 180° to a random side, held for as long as the rule keeps firing | danger felt | tail, `cirrus`, `myoneme` |

**A rule whose action has nothing to act on is passed over**: a hunt with no
food found, or a flee with no danger felt. That is Final Fantasy XII's rule for
a gambit with no target. A body none of whose rules fires rests.

### 4.1 A hunt runs to its end

Rules are read when the body is free, as today's `_decide` is. Once a hunt
begins, it runs to a meal or a miss, and its run is today's: `ORIENT_SECONDS`,
`COMMIT_RANGE`, `LOCK_SECONDS`, `LUNGE_RANGE` and the break-off are untouched.

**The chase contract stays out of evolution's reach.** A cell can learn when to
hunt and whom, but never how a pass is made. So a newborn that turns away and
commits still escapes a hunter without an `axoneme` as often as it does in
pack 2 (`lineage.md` §6.2: 10 times in 14).

A hunter on a run cannot flee. A rule that breaks off a run would be a later
addition (§14).

### 4.2 What it costs a body

Every action is paid at the player's prices, as today (`ocean.md` §5.2). Rest
is free. A search or a flee pays for its strokes and its turns, and a dash pays
its price. Behaviour buys nothing the organs do not.

### 4.3 The darts, the ping, the push

These are not actions. A `trichocyst` fires on its own, as the player's does; a
ping keeps its organ's own period; a water cell's speed already counts its
`axoneme`. The player's tap to dash is a decision, and pack 4 adds `dash` to the
actions when the player's blocks need it.

### 4.4 Where a gene goes stays the body's, in this pack

`lineage.md` §10 offered this: a water cell's meal takes the first free slot,
and where a gene goes is behaviour. **It stays the body's in pack 3**, for
three reasons:

- **It is a meal's decision, not a tick's.** It would need a second kind of
  rule for one choice.
- **A layout would quietly cut pack 2's gene changes.** A water cell's arcs
  matter only to its dart and to its drawing, so a layout would make the
  player's shift a mutation that changes almost nothing in the water.
  `Genome.mutated` tries shift, trade and drift in a random order and takes the
  first that applies. So at least a third of the water's gene changes would
  become shifts, which would quietly reduce the change at every division that
  pack 2's water is being played with.
- **It is the player's choice on the pause screen.** If pack 4 makes it a
  block, the water takes the same block, a layout, and shift with it.

---

## 5. Today's behaviour as rules

### 5.1 The five rules

| # | when | do | today's code |
|---|---|---|---|
| 1 | since a meal below 5 s | rest | `calm > 0` after `REST_MEAL` |
| 2 | since a miss below 5 s | rest | `calm > 0` after `REST_MISS` |
| 3 | hunger below 30 % | rest | `hunger < HUNT_AT` |
| 4 | always | hunt the nearest | `_look_in_drop` at its senses' reach, then `_start_run` |
| 5 | always | search at full speed | `searching`, at `_cruise_speed` |

In plain words: *rest for five seconds after eating or after missing. Rest
while less than a third hungry. Otherwise hunt the nearest food you sense.
Otherwise search.* Three of the eight places are free.

The save and the logs write it by name (§8):

```
since-meal below 5 -> rest
since-miss below 5 -> rest
hunger below 0.3 -> rest
always -> hunt nearest
always -> search full
```

`HUNT_AT`, `REST_MEAL` and `REST_MISS` stop being constants of the water. They
become these values, carried and changed by each body. `ORIENT_SECONDS` and
`COMMIT_RANGE` stay with the hunt.

### 5.2 Why it plays exactly as today

Read as rules, the five rules make the same calls as `_decide` in the same
order, so they make the same random draws:

- rules 1 to 3 read fields of the body and draw nothing;
- a rest makes today's look with reach 0;
- rule 4 makes today's look at the senses' reach and starts today's run. That
  run's one draw is the stroke;
- rule 5 sets `searching`, as `_decide` does when its look found nothing.

Two details carry it to the bit:

- **The rests' two clocks.** Today a single `calm` counts down from 5 s after
  either a meal or a miss. Here a body keeps two countdowns, `meal_clock` and
  `miss_clock`:
  - each is set to 5 s where `_rest` sets `calm` today;
  - each is stepped down at the top of the body's step by the time the body is
    owed, and is never clamped;
  - "since a meal below *T*" is tested on the countdown, as
    `meal_clock > 5 − T`. At today's 5 s that is `meal_clock > 0`: the same
    subtractions from the same 5.0 as `calm > 0`;
  - the later event's clock is always the larger of the two, so "either one
    below 5 s" is exactly `calm > 0`;
  - every new body, founder or daughter, starts both clocks at −10⁶ s, meaning
    never, where `_renew` sets `calm` to 0 today.
- **The thresholds are the constants' own floats.** The ladders are literal
  tables, so `0.3` is the literal `0.3` and not `3 × 0.1`. A full-speed search
  multiplies by nothing.

Proving it is the build's job: §12.3's first check runs the drop with today's
hand-written decision and with the five rules, and compares the census lines to
the byte.

---

## 6. A change at every division

### 6.1 Which daughter

`_divide` already makes a faithful DNA and a changed one (`Drop.daughter_dna`),
and tosses a coin for which daughter gets which. **The daughter who gets the
changed DNA also gets a changed behaviour**: `Rulebook.mutated` applied to her
mother's, which makes one change. Her sister carries her mother's DNA and
behaviour, unchanged.

So every division leaves one faithful daughter, as row 19 has it for the
player, and a family always has a line that is exactly its mother's. The two
other ways to place the change are both worse:

- **the behaviour's change on the other daughter**: no line would stay
  faithful;
- **one change that is either genes or behaviour, by a coin**: the gene change
  pack 2's water is being played with would be halved.

**The cost is that the changed daughter now carries two changes**, so she is
more likely to be the worse for it. `lineage.md` §3.3 measured what changes cost
a family when they come at every division. Without the newborn grace, the
families wore out; with it, they held. The grace stays. This is the first thing
to watch (§13).

### 6.2 The change

One change, drawn from the global stream that `--seed=` seeds, as
`Genome.mutated`'s is. It is drawn by weight from the kinds that can apply to
the behaviour:

| kind | what it does | weight | why |
|---|---|---|---|
| nudge | moves one rule's value or option one step up or down its ladder | 5 | the small step: 30 % becomes 20 % or 40 %, 5 s becomes 3 or 8 |
| replace | replaces one rule's reading (drawing a new test and value) or its action (drawing a new option) with another | 2 | where new rules come from |
| swap | two neighbouring rules change places | 1 | order is half of what a list means |
| copy | copies a rule in directly under itself | 1 | gene duplication. A copy under its original never fires, and is free to change later |
| drop | removes a rule | 1 | lets the list shrink |

Every change changes something:

- a nudge at the end of its ladder goes the other way;
- a replace always draws a different part;
- a swap of two equal rules is drawn again.

A copy needs room, because a list holds at most **eight rules**, the most one
phone screen shows (§11). A drop and a swap need at least two rules.

Nothing is protected. A change can leave a body that never hunts, for example
by dropping rule 4 or swapping rule 5 above it. Such a body still eats whatever
its mouth touches, and lives or dies by that. Its sister is a copy of its
mother.

### 6.3 What the water makes, the sister, the player

- **The spawner's founders carry today's behaviour** (row 22, recommended). A
  drop starts as today's, and only its daughters change. The founders made to
  hold the floor keep bringing today's behaviour back. So a sighted player's
  water, where a third of the hunters are the spawner's (`lineage.md` §6.1),
  will change least.
- **The player's sister carries today's behaviour.** The player has no rules in
  pack 3; from pack 4 the sister carries the player's. A guest's sister carries
  today's too, because SISTER carries her body and nothing else (`lineage.md`
  §8).
- **A `Body.brain` of null means today's behaviour.** So a founder, a sister, a
  body a tool poses and a body from an old save all carry it without a copy. A
  change writes a new list, and a faithful daughter shares her mother's.
- **The player divides as today.** What pack 4 does to the player's rules is
  §11's question.

### 6.4 Starting values

None of these was measured. Each is where the playtest starts.

| | starting value | why | watch for |
|---|---|---|---|
| today's behaviour's values | 5 s, 5 s and 30 % | today's constants, so a new drop is today's | -- |
| how often | at every division, on the daughter whose DNA changed | row 19 | hunters that stop hunting; families thinning while the spawner makes more of the hunters |
| the kinds | nudge 5, replace 2, swap 1, copy 1, drop 1 | mostly small changes | a water that never changes (raise replace), or one that cannot keep a way of hunting (raise nudge) |
| the most rules | 8 | one phone screen (§11) | families stuck at eight, unable to copy |
| the ladders | seconds from 1 to 34 in Fibonacci steps; hunger, food and danger in tenths | a nudge is about the same proportion anywhere on the ladder, and the numbers stay plain for pack 4 | -- |
| how far danger is felt | 1,400 µm, the player's `DREAD_RANGE` | a water cell's membrane feels what yours does | -- |
| flee with no bearing | a new heading 90° to 180° to a random side | the avoiding reaction | cells spinning near danger |
| search speeds | ¼, ½, ¾ or full | kinesis in four steps | -- |

---

## 7. What to expect, and what the player sees

### 7.1 What the water can learn

None of this was measured. These are what the vocabulary lets a family find,
each a few changes away from today's behaviour:

- **Hunting sooner or later**: rule 3's 30 % nudged. Hunting sooner means more
  danger, and more strokes to pay for.
- **No rest after a miss**: rule 2 dropped, or nudged down to 1 s. Today a
  hunter that misses you rests 5 s, and comes again only if it is still hungry
  and you are still the nearest thing it can eat (`ocean.md` §5.4). Without
  the rest, it comes again at once. This is the change a player would feel
  first.
- **The biggest prey**: rule 4's option replaced. You are bigger than the
  drifters (r26 to r40, against r13 to r21). A hunter whose mouth fits you and
  that hunts the biggest food goes for you over the food around you. This is the
  learning the owner asked for, aimed at you.
- **Slower searching**: cheaper, so a hungry hunter lasts longer but finds less.
- **Waiting**: a rest in place of the search, and a hunt only of food that is
  near (*food above 80 % → hunt*). Cheap, and lives where food drifts to it.
- **Running**: a rule like *danger above 50 % → flee*, reached by a copy and two
  replaces. Hunters that run from bigger mouths, including yours once you are
  big enough to eat them (row 23).

**What to watch for that would be bad:**

- a family that never hunts and still holds the water. Waiting could do it at a
  newborn's composition, where there are 4.7 drifters for each hunter
  (`lineage.md` §6.1);
- a family that flees from everything and starves;
- the opposite of learning: changes piling up faster than they are sorted out
  (`lineage.md` §3.3's mutational meltdown), until hunters forget how to hunt.

**Nothing new runs away** (`lineage.md` §13.2). A behaviour is at most eight
rules, and there are at most as many behaviours as hunters. What behaviour can
change is how many hunters the food feeds. A family that rests more lives
longer, and each extra hunter costs about 45 µs a frame on a phone
(`lineage.md` §7). The dev readout's `stepped` row shows it.

**How many behaviours hold the water.** Behaviour rides with families. Where
the genes converge, a handful of behaviours and their near variants should
converge with them: 3 to 12 families held a newborn's water after thirty
minutes in pack 2 (`lineage.md` §13.5). At a sighted player's composition, the
spawner's third keeps today's behaviour common.

### 7.2 Would a person notice?

A generation is about 30 s (`lineage.md` §13.8). So a newborn's drop is 23 to
26 generations deep at fifteen minutes and 43 to 50 at thirty, and its deepest
lines reach 60 to 66 (`lineage.md` §6.1, §13.8). Every division changes one of
its two daughters. A line 25 generations deep has therefore come through up to
25 changes, and about half that if changed daughters live as well as faithful
ones.

A person would see cells, not rules: one that comes back the moment you dodge
it, one that leaves the drifters to come for you, one that sits still, one that
turns and runs (§13). At a sighted player's composition, 5 to 6 generations
deep at fifteen minutes, there is much less to see.

### 7.3 What is drawn

**Nothing new** (row 24, recommended). A behaviour shows as motion in both
views. Full vision shows a cell turn and run. Point of view feels a hunter's
wake as today, and only a hunt raises a wake.

The dev app's frame readout gains two rows in its own grammar, under
`generation` and `families`:

- `behaviours`: how many different behaviours the hunters carry;
- `as today`: the share of hunters still running today's five rules, in percent.

Only the dev app draws them, and they are not translated. Marking what a cell is
doing in full vision (resting, hunting or fleeing) would be a screen of its own,
for the UX designer, and the replay's recorder would have to keep each slot's
action (§8).

---

## 8. Saves, the shared pond, the server, the replay

**Saves.**

- **Saved by name and version** (`ocean.md` §12). `drop` gains an optional
  `behaviours` entry, `{"version": 1, "lists": [...]}`, each list its rules in
  the text of §5.1.
- `drop.bodies` gains two optional columns:
  - `behaviour`: one int a body. −1 means today's, which covers drifters,
    flocs and every body still running it. Any other value is an index into
    the lists, so a family that shares one list is saved once;
  - `since`: a body's two countdowns, in 64 bits, as every clock is kept.
- Each is checked when present, as pack 2's columns are, and `FORMAT` stays 1.
- **Old saves.** A pack-2 file has none of them. Every body loads on today's
  behaviour, with both countdowns set from its `calm`, so it goes on resting
  exactly as it was. A pack-2 build reading a pack-3 file loads everything else
  and runs its own hand-written behaviour.
- **A name this build does not know**, such as a reading or action that a later
  content pack added, loads as a rule that never fires. It is kept by its name
  and written back as it came, as a retired gene is (`genome.gd`,
  `GENE_ORDER`).
- **A room that runs for days** adds nothing that grows. A list has at most
  eight rules, and there is at most one list a hunter. The size was not
  measured: a list is at most eight short lines, and there are fewer lists than
  hunters. For scale, pack 2's four lineage columns, one entry a body each,
  added 3.3 KB to a compressed save (`lineage.md` §4).

**The shared pond and the server.**

- **Behaviour is the host's water.** A host's drop and the server's room run the
  rules and change them at each division. A guest's mirror draws bodies from
  snapshots and decides nothing. A guest's own drop is set aside while it is
  away. **Nothing goes on the wire.** A guest's sister arrives running today's
  behaviour.
- **The referee judges a guest, never a water cell**, and nothing it copies
  moves: growth, division, the daughter, the sister ring, the gift, the speed
  and turn tables, the ping, `FIRST_DELAY` and the causes of death are all
  unchanged. None of `HUNT_AT`, `REST_MEAL`, `REST_MISS`, `ORIENT_SECONDS` or
  `COMMIT_RANGE` is in `net_probe`'s `_rules_text()`. **`Wire.PROTOCOL` stays 5
  and `Wire.RULES` stays `46913eab…`.** The build runs `net_probe
  --referee-only` to show it (§12.3).
- **Mixed builds play together.** Whether the water learns depends on the
  host's build.
- **The dedicated server** is the last to update, at an empty room's restart.
  Its pack-2 room loads every hunter on today's behaviour with its genes as
  they were, and from then on its behaviour changes too.

**The replay** records what moved, and a behaviour shows as motion, so nothing
new is recorded. A hunt is today's run, so `AT_HUNTER` and `AT_KILLER` stay as
they are.

---

## 9. Cost

**Reasoned from the code, not measured.** The dev app's frame readout, in its
`water` and `stepped` rows, is where the owner will see it.

- **Today's behaviour costs what today's decision costs, plus a few hundred
  interpreted operations a frame.** A hunter decides when it is free, on its
  tick. With 100 to 200 hunters, that is at most 13 to 25 decisions a frame.
  - Today's `_decide` makes two comparisons and one prey search.
  - The five rules make at most five tests, each a field of the body, and the
    same prey search.
  - The prey search is the real cost: pass 2 timed hunters looking for prey at
    88 µs a frame here (`ocean.md` §4.4).
  - The tests are an estimate of the order of 50 µs a frame here, and 0.3 ms on
    a phone at `ocean.md` §4.4's assumed factor of six.
  - The rulebook takes the cheap readings in an array, and asks for each costly
    one at most once a decision, so today's behaviour makes exactly the
    searches today's decision makes.
- **Changed behaviours can cost more**, and only in families that use them.
  `danger` is one more grid question out to 1,400 µm, for each decision that
  reaches it. `hunt the biggest` is a prey search with no early stop. If every
  hunter read danger at every decision, the water would pay about one more
  prey search a decision: of the order of 0.1 ms a frame here and 0.5 ms on a
  phone. For scale, pack 2's water was put at 8 to 10 ms of a phone's 16.7
  (`lineage.md` §7).
- **A division** copies nothing for the faithful daughter, and makes one list of
  at most forty ints for the other.
- **`binary_version` is unchanged.** It is all GDScript, a content pack.

---

## 10. Generic mechanics, names at the edges

| file | knows | does not know |
|---|---|---|
| `game/mechanics/rulebook.gd` **new** | a list of rules, five ints each: reading, test, step on the reading's ladder, action and option. **Choosing**: from the top, the first rule whose reading passes its test and whose action's need is above zero. The readings come in an array, with the costly ones asked of a callable at most once each. **One change** (§6.2), under a vocabulary of ladder lengths, option counts and needs that it is handed. The cap. Text to and from a list, given the names | cells, food, danger, the water |
| `game/normal/drop.gd` | **this water's vocabulary**: the names of the readings and actions, their ladders and options, each action's need, the cap, the kinds' weights, `BEHAVIOUR_VERSION`, and today's behaviour as the five lines of §5.1. Also `daughter_behaviours(list)`, which returns `[faithful, changed, kind]`, beside `daughter_dna` | how a list is read or changed |
| `game/normal/food.gd` | what each reading means for a body (`food`, `danger`, the two clocks); what each action does (the rest, the search at its share, `_start_run` at the nearest or the biggest, the flee); `_decide` reading the body's list; `_divide` handing lists on; the save's columns; the census's behaviour line | the arithmetic of a list |

A second water writes its own vocabulary in its own environment file. A second
kind of body, the player in pack 4, reads the same lists through the same
`rulebook.gd`.

---

## 11. What pack 4 needs from these blocks

Named here, not designed.

- **The same rules drive the player through `_read_steer()`.** The player is not
  a water body: it moves by impulses, steering, push and dash (`cell.gd`). So
  each action needs a player's form:
  - rest is no steering, and, if the owner wants it, a flagellum that stops,
    which `ocean.md` §5.2 left to the player's own blocks;
  - search steers by a wander;
  - hunt steers onto the intercept today's run computes;
  - flee steers away.

  The readings are the same functions, asked for the player's body. The field
  already treats a person as a body.
- **A screen holds eight rules.** On 1600×720, a rule is one row of 48 px
  targets: a handle, a *when* chip and a *do* chip. Eight rows with 12 px
  between them fit in under 480 px of the 720.
- **The vocabulary is ten chips**: six readings and four actions, with their
  values. Every name is the owner's to choose, and goes through `tr()`.
- **Your division changes your rules** under row 19. One daughter keeps your
  rules and the other carries one change, so the choosing screen would show
  both. Row 19 decides it; pack 4 confirms it with the owner once the screen
  exists.
- **Your sister carries your rules.** A guest's sister would need SISTER to
  carry them, which is the next protocol change.
- **Additions pack 4 may want**: `dash` as an action, organ-named readings, the
  player's own speed, a rule that breaks off a hunt, and a rule for where a gene
  goes.

---

## 12. Build plan

### 12.1 Files

| file | change |
|---|---|
| `game/mechanics/rulebook.gd` | new (§10) |
| `game/normal/drop.gd` | the vocabulary, today's behaviour, and `daughter_behaviours` (§10) |
| `game/normal/food.gd` | `Body.brain` put to use (null is today's), and `meal_clock` and `miss_clock` beside it. `_rest` split into a meal and a miss, each setting its own clock (and `calm`, for the reference). `_decide` reads the list. The hand-written decision is kept as `_decide_by_hand` behind a tool switch. `_look_in_drop` split into a find and a start, plus a search for the biggest. The flee and the search's share go in `_drift_in_drop`. `_divide` hands the changed daughter `Drop.daughter_behaviours`. `drop_state` and `load_drop` gain the columns. A behaviour line beside the lineage line, and `behaviour_counts()` for the readout |
| `game/normal/drop_save.gd` | the optional entries, each checked when present |
| `game/dev/frame_readout.gd` | `behaviours` and `as today`, in the dev app only |
| `tools/eco_probe.gd`, `tools/drive.gd` | `--blocks=0` (today's hand-written decision, the reference), `--behaviour-change=0` (no change at division), `--founders=today\|varied\|random` and `--flee=0` (the other answers to rows 22 and 23), and the behaviour line |
| `tools/drop_probe.gd` | the checks in §12.3 |

**Nothing** changes in `addons/launcher/`, `ci/` or `project.godot`.

**No player-facing text.** Nothing new goes through `tr()` or into
`game/i18n/biogenic.pot`. The readout's rows are the dev app's, and are not
translated.

### 12.2 Phases

Each phase is one pull request into `dev`, played on the dev app before the next
one starts.

| phase | contents | what the owner can try |
|---|---|---|
| **3-1** | today's behaviour as rules: the rulebook, the whole vocabulary, every body on today's five rules, the two clocks, the save's entries, the identity check, and the checks on the actions | nothing new: the water plays as it does now |
| **3-2** | behaviour that changes: one change at every division, the readout's two rows, and the checks on the change and on determinism | a water that learns. Play it new, then come back after fifteen minutes and after an hour |
| the release | | whenever the owner runs it |

No `Wire.PROTOCOL` change, and no `binary_version` bump.

### 12.3 What the build checks

`drop_probe`'s "Check the drop" step gains these checks. Each must fail with its
rule taken out.

1. **Today's behaviour plays as today, to the byte.** Run the drop with
   `--blocks=0`, and again with the rules and no change
   (`--behaviour-change=0`). The census and lineage lines must be equal. In CI:
   seed 1, five minutes, at a newborn's composition and at a sighted player's.
   By the builder, once before 3-1 merges: seeds 1 to 3, thirty minutes. This is
   the regression guarantee, and the gate for 3-1.
2. **The five rules choose what `_decide` chooses**, over a table of body
   states: each clock either side of 0, hunger either side of 0.3, and food
   touching, found, or not found.
3. **Every change is valid.** Make ten thousand changes, starting from today's
   behaviour and from random lists. Each result must have one to eight rules,
   every value on its ladder and every option its action's. Each must differ
   from its parent, and each must survive the text round trip.
4. **A division.** The daughter whose DNA changed carries a behaviour one change
   away from her mother's. Her sister carries her mother's. Founders, sisters
   and posed bodies carry today's.
5. **The actions keep to the organs.** A search and a flee move at the body's
   own speed. A dash happens only with a `myoneme`. Food is found only within
   the senses' reach, or by touch without them. A flee whose senses do not
   reach its danger turns at random.
6. **Determinism.** One seed run twice with changes on gives the same lines.
7. **The save.**
   - A round trip with the new entries is exact to the bit.
   - A pack-2 file loads on today's behaviour and goes on to the same census as
     one that never stopped (`ocean.md` §14.3 check 12).
   - An unknown name loads as a rule that never fires, and is written back as it
     came.

`net_probe`: the referee section passes unchanged, and so does `pond-field` with
the host's water running on rules.

### 12.4 What it replaces

| pack 2 | pack 3 |
|---|---|
| one hand-written decision for every mouth (`_decide`) | each hunter's own rules, read by `rulebook.gd`; today's decision kept as a tool's reference |
| `HUNT_AT`, `REST_MEAL`, `REST_MISS` | values in each body's rules, inherited and changed |
| one `calm` after a meal or a miss | two countdowns: since a meal, and since a miss |
| every water cell decides alike | a division changes one daughter's behaviour, together with her genes |
| always the nearest prey | the nearest or the biggest |
| a hunter never flees | it can learn to (row 23) |
| `Body.brain` reserved and null | a behaviour; null means today's |

---

## 13. What to watch in the playtest

**At fifteen minutes**, in a new drop, as a newborn:

- `as today` on the readout shows how much of the water no longer behaves as it
  did. Expect it to fall. If it stays near 100 %, nothing is learning.
- A hunter that comes straight back after you dodge it. Today's hunters rest
  five seconds after a miss.
- A hunter that leaves the drifters to come for you.
- Hunters sitting still, which swallow you when you bump into them.
- Hunters that run from you once you are big (row 23).

**At an hour**:

- `behaviours` on the readout. A handful means a water that settled on what
  works. Dozens means one that is still trying, or that cannot keep anything.
- Hunters that drift and never chase, and still fill the water.
- Whether you are caught more or less often than in pack 2, and at what size.
- The `water` row against pack 2's: the cost of families that read danger.

**In the server's room, over days**: whether it keeps changing or settles, and
whether one behaviour takes over the whole room.

---

## 14. Left open

1. **Nothing here was measured**, by the owner's choice. Whether behaviour
   evolves within fifteen minutes or an hour, what it evolves toward, the
   danger to the player and the cost on a phone are all for the playtest.
2. **A hunter on a run cannot flee** (§4.1). A rule that breaks off a run would
   be a later addition, and would be the first thing to change the chase.
3. **The changed daughter carries two changes** (§6.1). If families thin, the
   levers are how often behaviour changes, or which daughter carries the
   change.
4. **Where a gene goes stays the body's** (§4.4), so the water's gene change is
   still never a shift.
5. **Drifters decide nothing** (§1 item 8).
6. **A guest's sister arrives running today's behaviour**, until SISTER carries
   one.
7. **Organ-named blocks, `dash` and the player's own speed** are pack 4's to
   add, if its screen wants them.

---

## 15. Owner's calls

The rows are numbered on from `lineage.md`'s rows 19 to 21, so that one row
number names one call across the three documents. Rows 22 and 23 set starting
points that the playtest judges. Row 24 is about what a player sees.

| # | Question | Options | What it means |
|---|---|---|---|
| 22 | What do the cells the water makes know how to do? | **today's hunting ✓ recommended** · today's, with a few random changes each · random rules, as you first described | Today's: a new drop behaves exactly as it does now, and only the cells born in it change, one small change at every division. A few random changes: a new drop is varied from the first minute, and some of its cells hunt worse than today's. Random: a new drop starts harmless, since most of its cells hunt badly or not at all and starve, and it gets dangerous as the families that work fill it. The cells the water adds to keep the drop alive stay random too, so a drop made for a player with good senses, where a third of the hunters are those, never gets as good. Untested: a starting point the playtest judges. |
| 23 | Can cells learn to run from danger? | **yes: a cell's rules can make it swim away from a mouth that could swallow it, yours included ✓ recommended** · no: in this pack cells only rest, search and hunt | Yes: families can learn to turn and swim away from bigger mouths, at their own speed, and that includes yours once you are big enough to eat them. A cell with no sense that reaches you can only turn sharply at random. The hunters you chase may get harder to catch, and hunters that would have been eaten live longer. The drifters you mostly eat never run, because they decide nothing. No: no cell ever runs, as today. Untested: a starting point the playtest judges. |
| 24 | Do you see what the water's cells are doing? | **not in this pack: you see them move, and the dev app counts how many ways of behaving the water has ✓ recommended** · full vision marks each cell that is resting, hunting or running | Not yet: behaviour shows only in how cells move, and it can be marked later without changing anything else. Marked: in full vision you would read each cell's intent at a glance. That is a screen of its own for the UX designer, and the replay would have to record it. |

**Under row 22.** The owner's first words for the evolving water were "random
logic at the start". Today's hunting is recommended for two reasons:

- it starts the playtest from a water the owner has already played, so whatever
  changes is the learning;
- the spawner keeps making founders to hold the floor (`lineage.md` §5), so
  whatever founders carry never leaves the water.

Each of the other two answers is one switch in the tools
(`--founders=varied|random`).

**Under row 23.** Fleeing is the one action the water does not do today.
Without it, a cell can learn when to hunt and whom, but can only stay alive by
eating. In pack 2, other hunters ate the water's daughters twice as often as
they starved (`lineage.md` §2.2). Fleeing is real (§2.2) and it shows.
`--flee=0` plays the other answer.

**Not asked, because answered rows already decide them:**

- every division changes a daughter's behaviour together with her genes
  (row 19);
- behaviour gives a body nothing its organs cannot do (row 5's "all cells
  follow the same rules").

**Settled here, not asked:** a hunt runs to its end and its run is today's
(§4.1), so the chase you escape is the one pack 2 measured; and where a gene
goes stays the body's (§4.4), so the water's gene changes stay what pack 2's
playtest is judging.
