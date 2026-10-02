# Your rules: the player's own blocks

Pack 4 of the evolving water (`roadmap.md`, "Next"). The owner, 2026-09-29,
introducing the whole feature:

> I want to make the AIs logic evolving. By that I mean random logic at the
> start, then each cell that divides carries genes but also behavior logic (AI)
> with small mutations. [...] And while we're at it, we could propose to players
> a screen where they can use the same logic blocks to automate their cell !
> Offering a new gameplay type. Both should use the same logic system.

Pack 1 made the drop (`ocean.md`), pack 2 made its cells divide (`lineage.md`),
and pack 3 gave every water cell ordered rules that it carries, passes on and
changes at division (`behaviour.md`). This pack lets the player build the same
rules for their own cell. `behaviour.md` §11 is its contract, and every point of
it is answered here (§1).

This document owns the rules of the game: what your rules can read and do, when
they act, their limits and states, the save, the wire, the replay, and what must
be visible. **The screen itself is `automation-ux.md`'s**: where it lives, the
rows of chips, picking and setting, reordering, live feedback, both shapes, touch
and mouse. Where the two touch, this one says what must be shown and that one says
how.

**Status: designed from the code and the existing specs; nothing prototyped or
measured, by the owner's choice; the owner playtests it on the dev app.** The
owner, 2026-10-02: *"Don't measure in prototypes. I'll playtest."* Every number
below is a starting value given with its reason, arithmetic on the code's own
constants (said so where it is), or a measurement an earlier spec holds, cited
where it is used. Code references are to `dev` at `df45f82`.

**Put to the owner on 2026-10-02**, together with the screen's calls: rows 27 to
35 (§17).

The owner's standing rules bind it: *"all cells follow the same rules. Me,
friends, NPC, doesn't matter."* -- row 19, *"every division. No specific
treatment between NPCs and players"* -- *"A cell dies of hunger, nothing else.
Unless it gets eaten by another one."* -- and, on pack 3's blocks, *"blocks can
only contain things coming from enabled senses [...] No magic info. The cell has
inputs and produces output that acts on available triggers (turn, dash)"* and
*"The design of the blocks must be modular."* Balance waits for players
(`CLAUDE.md`): no balance number is put to the owner here.

---

## 0. What pack 3 left

**The rules exist, for the water only.** `game/mechanics/rulebook.gd` reads an
ordered list from the top with one winner for each trigger (`choose`), changes
one a small step (`changed`), and reads and writes a list as text by declared
name. `genome.gd`, `cell.gd` and `metabolism.gd` declare every input and output
(`DECLARES`). `food.gd` wires each declared name to a function that reads it for
a water body (`_read_smell`, `_read_beam`, ...) or performs it (`_turn_toward`,
`_rest_on`, ...), and `_decide_by_rules` runs a body's list on its tick, every
eighth frame (`Drop.LOD_EVERY`), 7.5 times a second at 60 fps.

**Every sense is already one function of an observer** (behaviour.md §12.1): the
player's membrane and a water cell read the water by the same arithmetic
(`_feel`, `_beams_of`, `_touch_of`, `_call_of`), and behaviour.md's check 2, in
`drop_probe`, holds them equal to the float. So the player's organs already
compute, every frame, exactly the reports a rule reads.

**The player's body has no rules.** `cell.gd` steers from the hand alone:
`_read_steer()` reads the keys, then a drawn control, then the floating stick,
and returns a rate from -1 to +1 that the cirrus turns at, with a lag
(`TURN_RESPONSE_BY_TIER`). `_pushing()` is a yes or no, `_dash()` fires on a
tap, Space or the dash pad, and **the flagellum beats on its own**: an impulse
every 1.70 to 3.60 s at tier 1, whatever the hand does (`_fire_impulse`,
`energy.md` §2). A water body on rules moves differently: it holds a heading and
turns toward it at its cirrus's rate, swims at its tail's speed only while a
swim rule fires, and otherwise is carried at 9 µm/s (`_move_ruled`).

**The hooks pack 3 named** (§11 there): the player's blocks are the same inputs
and triggers; the triggers map onto `_read_steer()` and the controls; swim and
rest drive a flagellum that today beats on its own, and whether blocks may stop
it is the owner's call; a screen holds eight rules; names are the owner's;
your division changes your rules under row 19; your sister carries your rules,
and a guest's needs SISTER to carry them; no block reads dread or the wake. In
code: `Body.brain` (a water body's list, null for the founders'), `put_sister`
(no list yet), `Drop.daughter_behaviours`, and SISTER, which carries her body and
nothing else (`wire.gd`'s `sister_payload`).

---

## 1. Decided, in one place

1. **Your rules are the water's kind** (behaviour.md §2 to §4): an ordered list
   of at most eight, each *when <input> [tests] -> <output>*, read from the top
   with one winner for each trigger, by the same `rulebook.gd`. A test's value is
   a rung of its ladder, the space the water's changes step along (§3.4).
2. **They read only your own organs**, exactly what each one posts to your
   membrane, from the reading your membrane already took that frame: no new
   sensing (§3.1). A mote and the feel of your own bite are not a `hit`. Dread and
   the wake are not inputs.
3. **They drive your cell whenever your hand is off the controls, and touching
   takes over at once** (row 27). They take it back on their first tick at least
   `HAND_LETS_GO` (0.5 s) after you let go. A switch puts them to sleep without
   losing them (§2).
4. **The triggers are your body's own** (§3.2): a turn holds a heading that your
   cirrus steers you onto through `HOLD_BAND`; a push at the rule's strength; the
   dash as yours; and **while your rules have your cell, your tail beats only when
   a swim rule fires**, as a water cell's does (row 29).
5. **A new cell has no rules, and no rules is today's game, to the byte** (row 28,
   §5). **A list you start begins as one rule, *always swim***, which is today's
   cell too, so adding a rule changes only what that rule does.
6. **Your division changes one daughter's rules**, the one whose genes changed, by
   the water's own change, and the choosing screen shows it (row 19, §6). **Your
   sister carries her list into the water**; with no rules, the founders' as today.
7. **A death keeps your rules** (row 30), and **you can change them whenever the
   screen is open** (row 31). Each world keeps its own (§9).
8. **What you must see** (§8): whether your rules or your hand has your cell, and
   which rule is acting, in both views; on the screen, each rule's state and what
   your senses report; the change on the choosing screen; all of it in the replay.
9. **Saved by declared name in the world's file**, optional keys: `FORMAT` stays 1
   (§9).
10. **The shared pond** (§10): your rules run on your device, and the host's
    referee judges the motion they make, which never leaves your hand's envelope.
    **`Wire.RULES` stays `46913eab…`.** From phase 4-3 a friend's sister carries
    her DNA and her rules: **`Wire.PROTOCOL` 6** (row 33).
11. **Generic** (§13): `rulebook.gd` learns nothing about a player. The player's
    wiring is a file of its own, and the words sit beside the declarations.
12. **Content only, in three phases** (§18.2): no `binary_version` bump.

---

## 2. Your hand and your rules share the cell

### 2.1 Four candidates

| candidate | how it plays | what it costs |
|---|---|---|
| **(a) your rules drive whenever your hand is off the controls; touching takes over at once** | you steer as today. The moment you let go, your cell follows your rules; touch, and it is yours again. A player with no rules plays exactly as today, and one who never touches watches their cell live by its rules | one state, who has the cell, which must be visible (§8); a half second before the rules take back (§2.3) |
| (d), added here: your rules do whatever your hand is not doing | your hand claims the triggers it is working, as a rule above every rule would (behaviour.md §4.1's own order), and your rules keep every other one: a dash rule can lunge while your thumb steers | the indicator has to say, trigger by trigger, which are yours and which a rule's; and a rule can push or dash under your thumb when you did not expect it |
| (b) a way to play, chosen before a run: you steer, or your rules do | a run is all yours or all your rules'. In a rules run the controls do nothing but choose a daughter | a second choice before every run, beside the view; the controls hidden or dead for a whole run; a rules run whose list cannot swim is a cell that drifts until it dies |
| (c) a switch on the pause screen | (b), changed in the middle of a run | in a pond the pause stops nothing, so a trip to the menu is a trip with your cell on whatever it was on |

**(a) is recommended** (row 27). It is the only candidate that adds a way to play
without splitting the game in two: steering everything, steering nothing and
everything between are one game, and the player slides along it by touching or
not. It needs no new control on any scheme. It leaves today's game untouched for
anyone without rules. And it is the robotics reading pack 3 already used: the
hand is a higher layer that suppresses the layers below it while it acts
(Brooks's subsumption, behaviour.md §2.1). (d) is the same reading done trigger
by trigger, and it is the natural next step once (a) has been played (§14).

`automation-ux.md` is designed for (a), and its §8 says what (b) and (c) would
change on the page.

### 2.2 What "the controls" are, scheme by scheme

The hand is **whatever the player's scheme reads as steering, pushing or
dashing**, and nothing else. A touch the scheme ignores is ignored here too.

| | your cell is yours while | your rules take it back |
|---|---|---|
| `anywhere`, phone | a finger is down on the water (`cell.gd`'s `_pointer`): it steers, and pushes with an `axoneme`. A tap is yours for its press, and dashes as it lifts | 0.5 s after the finger lifts. Your thumb is down while you steer, so your rules act in the moments it is up |
| `stick`, phone | your thumb is on the stick, which also pushes with an `axoneme`, or on the dash pad (`controls.gd`'s held controls) | 0.5 s after it leaves. A press on open water is inert under this scheme (controls.md §1) and takes nothing over |
| `pads`, phone | any pad is held | 0.5 s after the last pad is let go. The scheme where rules and hand alternate most finely: your rules act between presses |
| Windows, any scheme | a steering or push key is held (A, D, the arrows, W), Space is pressed, or the mouse button is held where the scheme reads it | 0.5 s after the last key or button |

**Keys work under every scheme**, as they always have (controls.md §1). The lean
at a division, the pause target, the strand and every button consume their own
presses before `cell.gd` sees them, so none of them is the hand. **Nor is a raw
key or finger that the cell is not reading**: a finger holding your body open to
place a gene, or `E` held with `A` and `D` walking a slot round it
(`dna-body.md` §8), is placing, not steering, and your rules drive under it.
**In a pond the open menu silences the hand** (`steering_off`, shared-pond.md
§1.7): your rules drive while the menu is up, where today your cell drifts with
its tail beating.

**What the other three would mean on the same schemes.** Under (d), a held
control claims only what it works: a finger under `anywhere` and the stick under
`stick` claim steering and, with an `axoneme`, the push; each pad and each key
claims its own; your rules keep the dash and whatever else is free. Under (b)
and (c), a rules run reads no finger on the water under `anywhere`; under
`stick` and `pads` the controls are not drawn in a rules run (or are drawn and
dead, which controls.md §1.1 forbids); on Windows the keys do nothing but lean at
a division. Every scheme still needs the hand for the division (§6), so no
candidate is a run with no hand at all.

### 2.3 Taking over, and handing back

- **Touching takes over on the frame it lands.** What the rules held goes with
  it: the heading, the random turn, and what they remember of the last tick
  (`memory`, which rising, falling and leading are measured against). The tail
  beats on its own clock again, as yours always has. The rules' tick goes on
  counting, unread, so the first tick after a handback has nothing to compare
  with, and leads nothing.
- **The rules take the cell back on their first tick at least `HAND_LETS_GO`
  after the hand let go**, so there is never a moment where nobody drives. A
  re-grip under `anywhere`, lifting to re-centre the floating stick and
  pressing again, takes about a quarter of a second; the rules should not twitch
  the cell in between. Starting value 0.5 s, unmeasured (§15).
- **A switch puts your rules to sleep** without losing them, as Final Fantasy
  XII's gambits had one. Asleep, your cell is yours alone, as with no rules.
  Your list still passes on at division and into your sister (§6): the switch is
  about who drives your cell, not about what your cell is. Switched on, your rules
  take the cell at their next tick if your hand is off. The switch sits in the
  page's head (`automation-ux.md` §3.4).

### 2.4 The states

| state | when | your cell |
|---|---|---|
| **no rules** | an empty list | yours alone: today's game |
| **asleep** | a list, switched off | yours alone |
| **yours** | a list, switched on, and your hand on the controls or let go less than `HAND_LETS_GO` ago | yours: your rules are not read |
| **your rules'** | a list, switched on, hand off | what your rules say, read every eighth frame |

Not simulated at all, as today: paused in single player, from the pinch of a
division to the birth, dead, or held in a pond.

---

## 3. What your rules can read and do

### 3.1 Inputs: your own organs, as your membrane gets them

The vocabulary is the water's: the parts the body and the metabolism declare,
and those of every gene in your DNA, worn or only carried (behaviour.md §6.3). A
rule for a gene you carry and do not wear is **asleep**: its input never reports
and its output never fires (`Rulebook.choose`'s `worn` mask) until a daughter of
yours wears it. Nothing is offered for a gene your DNA has never had: no magic.
A rule for a gene you have since lost stays in your list, asleep, until you
remove it.

Each input is what that organ already posts to your membrane, taken from the
reading the membrane got that frame. Your rules read it once a tick; nothing is
sensed again.

| input | your organ's reading | taken from |
|---|---|---|
| `metabolism.hunger` | your tank, a level | metabolism.gd's `hunger` |
| `metabolism.fed` | seconds since you last ate: a cell, a floc, or one you chewed apart. Never, at a new cell | the run's clock at `_on_eaten` and `_on_grazed` |
| `body.hit` | a mouth's bite landing on you, at its bearing now and how hard (`_felt`) | `food.gd`'s `hear_contact` at `BITTEN`, the one door a mouth's bite reaches you by, from the water or a friend. **Not a mote** (`motes.gd`'s grit is your screen's, and no water cell feels it) **and not the feel of your own bite** (`_bite_from`'s `bitten`), which a water cell chewing feels nothing of |
| `chemocyte.smell` | your nose's level | `taste_level`, from `_step_sense` |
| `stigma.shadow` | the shade on your eyespot and its bearing, while there is any | `shadow`, `shadow_bearing` |
| `palp.touch` | the nearest thing within reach of your skin, the rim included | `touch_level`, `touch_bearing`, from `_step_touch` |
| `ocellus.beam` | each of your rays that stops on something, nearest first, at your beam's own level and path | `beams`, from `_step_beams` |
| `ampulla.echo` | each return of your own call while it rings: its bearing, its distance from its time home, its size from its ring | your call's returns, kept from landing until they ring out, as a water cell's are (`_call_now`'s `[lands, at, distance, size, rings until]`) |

**One report function per input, shared.** Each `_read_X(i, b)` in `food.gd`
splits into the sensing it does for a water body and a report that formats what
the sense found. The water's reader senses, then reports; yours reports what your
membrane's frame already sensed. So the report a rule gets is the same function
for both, and check 2 (§18.3) holds them equal.

**What no rule of yours can read**, beyond behaviour.md §3.4's list: your dread
and your wake (they read other cells' mouths), your grace, what your full vision
shows (a view, not a sense), motes, and anything about a friend that your organs
do not report.

### 3.2 Outputs: the triggers, on your body

| output | your body | how |
|---|---|---|
| `body.turn-toward`, `turn-away`, `turn-random` | holds a heading, set exactly as a water cell's is (`_turn_toward`, led by three times the bearing's drift a tick; `_turn_away`; `_turn_random`'s tumble), and steers onto it | `steer = clamp(angle_difference(heading, held) / HOLD_BAND, -1, 1)`, into `_read_steer()`'s place. Paid at `TURN_COST` a radian, as your hand's turn is |
| `body.swim` | your tail beats, on its own clock and at its own price, as today | the stroke clock runs |
| `body.rest` | everything stops: no stroke, no turn, no push, no dash. You coast to a stop under `DRAG` while the water's wander turns you, for free | the stroke clock is held; `steer` 0 |
| `myoneme.dash` | your dash, on its cooldown, at its price | `cell.gd`'s `_dash()` |
| `axoneme.push 0.5` / `1` | your push, at half or full strength, at that share of its price | `_pushing()` becomes a strength, 0, 0.5 or 1 |
| a trigger nothing claims | what a water cell does on its own (behaviour.md §4.1): no new heading, no stroke, no push | |

**Your body is your body.** A water cell is kinematic: it turns at its cirrus's
rate exactly and swims at a constant pace. Yours keeps its own physics: its
turn has the cirrus's lag, its tail fires impulses with a random kick, and it
coasts under drag. So a rule means the same thing in both bodies and each body
does it its own way. That is why a resting player is not carried at the water's
9 µm/s: nothing ever carried it, and a coast to a stop is its own drift.

**`HOLD_BAND`, the one new piece of steering.** Your cirrus answers a steer with
a lag, and the lag times the rate (`TURN_RESPONSE_BY_TIER` ×
`TURN_RATE_BY_TIER`) is 0.69, 0.68, 0.68 and 0.66 rad at tiers 0 to 3: the same
at every tier. Steering at full rate until the heading is reached would carry
the turn about that far past it, near 39°. Steering in proportion inside a band
of about twice that settles instead. By the arithmetic of the lag, with no wander
and no kick, a band of 1.3 rad (75°) damps the turn at about 0.7, and a 90° turn
at tier 1 overshoots by about 4°, a 180° one by about 6°. Arithmetic, not
measured; check 6 holds that it settles.

**The tail at rest keeps its clock.** While it rests, its stroke clock is held,
never reset, so when it beats again two strokes are never closer than its own
shortest gap (`IMPULSE_GAP_MIN_BY_TIER`). That is what the referee's movement
budget assumes, "impulses as often as their clock allows" (`referee.gd`), and a
list that flips between rest and swim every tick cannot beat faster than a tail.

**What stays automatic, as for every body** (behaviour.md §3.3): the dart, the
call, the beam and the mouth. The drawn controls show your hand only: the knob
stays home and the pads stay dark while your rules steer.

### 3.3 The tail is the one trigger your hand lacks

Today your tail beats whatever you do, and a newborn burns ×1.50 of rest
drifting, where the tail is a third of that (`energy.md` §2, §7.2). With row 29
answered as recommended, **your rules drive your tail as a water cell's drive
its own**: while they have your cell, it beats only when a swim rule fires, and
a rest, or no rule claiming swimming, keeps it still.

Three reasons decide it:

- **Your sister carries your list into the water** (§6), where a body with no
  swim rule drifts. A list has to do the same thing in your cell as in hers.
  Under the other answer, a list built on a cell whose tail beats by itself
  would leave her drifting, and she would starve.
- **The water's cells already rest**, for free: the founders rest while fed and
  while under 30 % hungry (behaviour.md §5.1). "All cells follow the same rules."
- **It is real.** A cilium or a flagellum beats because dynein spends ATP on
  every stroke (`energy.md` §1), and a cell can stop it. *Rhodobacter
  sphaeroides* swims on one flagellum that stops several times a minute, for up
  to a few seconds, and drifts to a new heading while it is still ([Armitage and
  Macnab, *J. Bacteriology* 1987](https://journals.asm.org/doi/10.1128/jb.169.2.514-518.1987)):
  rest, then swim, as a rule would say it.

**What it gives your rules that your hand has not got**: a cell that lies still
and saves what its tail burns. From birth, resting throughout, a born cell's tank
would empty at 36 s and it would die at 46 s, against 24 s and 34 s drifting
with its tail beating. That is arithmetic from `HUNGER_SECONDS` 36,
`STARVE_GRACE` 10 and the upkeep alone (×1.00), against `energy.md` §7.2's
measured drifting row. It is a balance consequence and nothing is tuned for it
(§15, §16).

**What it asks of a player**: a list that never says swim leaves your cell
drifting whenever you let go. A list you start begins with *always swim* (§5), so
that happens only when a player takes it away or puts a rest above it, and the
screen says so when it does (§8.2).

### 3.4 Limits

- **At most eight rules**, `Drop.MOST_RULES`, the water's: one phone screen.
- **One test for each value an input carries**, as `rulebook.gd` enforces: up to
  three on an echo (its bearing, distance and size), one on the hunger.
- **A test's value is a rung of its kind's ladder** (`Rulebook.LADDERS`: tenths
  of a level; 1, 2, 3, 5, 8, 13, 21, 34 s; 50 to 1,450 µm; 15° to 150°), or a size
  against your mouth or your body (`REFERENCES`). The player builds in the space
  evolution steps along, so a list of yours and a list of the water's are the
  same kind of thing, and a division's nudge moves your value one rung.
- **A turn needs an input with a bearing**; a push takes 0.5 or 1. A rule that is
  not whole is not in the list your cell runs. Any rule the screen makes must come
  back the same through its line (`Rulebook.rule_from`, `line_of`).
- **No cost.** A rule costs nothing to keep or to fire, as the water's do; what
  it makes your body do is paid at your body's prices.

---

## 4. How your rules run

- **Every eighth frame of your cell's simulation** (`Drop.LOD_EVERY`), the
  water's spacing, so a tick means the same in both bodies. That matters: the
  lead is three times a bearing's drift *a tick*, and rising and falling compare
  one tick with the last. The tick counts in single player and in a pond, on a
  guest's mirror as well, from a counter of the run's own.
- **Read from what the membrane shows.** The run posts your senses to the
  membrane from what `food.gd` sensed on the frame before (`normal_mode.gd`'s
  live branch, which runs ahead of the cell and the water). Your rules are read
  there, from the same values, and the cell acts on what they claimed in that
  same frame's step.
- **`Rulebook.choose` with your vocabulary, your worn mask and your sizes**
  (your gape and radius for `mouth` and `body`), then each winner performed. A
  hit is felt on the tick it is read, and cleared. A dash fires once, on the tick
  its rule wins. The swim, rest and push claims hold until the next tick.
- **An edit takes effect at the next tick**, and clears what the rules held, as
  a takeover does (§2.3). A rule half-built on the screen is not in the list your
  cell runs. **An edit makes a new list**: the one your sister carries is never
  written through (`rulebook.gd`'s `Behaviour`, "shared, never written through").
- **Your rules never choose a daughter.** No input reports a daughter, and the
  division is the hand's (`_read_lean`). A player who never touches is asked
  there, and nowhere else.
- **The opening's first drifter waits for you to move**: `food.gd` puts it along
  your drift path the first time your velocity passes 1 µm/s (`_first_pending`).
  A cell whose rules keep it still from birth meets it when it first moves. Today
  every cell moves within a second or two, because the tail always beats.

---

## 5. What a new cell starts with

**No rules** (row 28). A new player's game is exactly today's: their cell does
what it does now, the screen opens empty, and nothing draws a random number that
pack 3 did not. Today's seeded runs stay byte-identical (check 1).

**No rules and asleep are the same to your cell**: yours alone, the tail beating
on its own. A list whose every rule is asleep is not the same: your rules have
your cell, nothing fires, and it drifts, its tail still. The screen says so
(§8.2).

**A list you start begins as one rule, `always -> body.swim`.** With your hand
off, that one rule is exactly today's cell: the tail beats on its own clock,
nothing steers and nothing pushes (§3.2). So the first rule you add above it
changes only what that rule does, and your tail stops only if you take the swim
away or put a rest above it. It is removed like any rule. This is what the list
holds; how the screen starts one is `automation-ux.md`'s (§4.5). Under the other
answer to row 29 it is still harmless.

The alternative was the founders' seven (`drop.gd`'s `FOUNDERS`). It would turn
every new player's cell into a water cell the moment they lift a finger, and its
second rule, *hunger below 30 % -> rest*, fires at birth, when a cell is fed: a
newborn who lets go would stop dead. The first thirty seconds teach that the
cell drifts and the membrane speaks (`perception.md` §2); a cell that stops
whenever you let go would teach something else. The screen may still offer the
water's seven as a list to start from, and `automation-ux.md` §5 does (row 28).

---

## 6. Division

### 6.1 Which daughter

`_make_daughters` already rolls a faithful DNA and a changed one, and puts them
on sides by a coin (`normal_mode.gd`). **The daughter with the changed DNA also
carries your list with one change** (row 19): `Drop.daughter_behaviours(list,
vocabulary, Rulebook.worn(vocabulary, her DNA, every body's parts))`, the water's
call exactly (behaviour.md §6.1 to §6.3), drawn from what the body, the metabolism
and every gene in her DNA declare. Her sister carries your list unchanged. One
faithful daughter, as row 19 has it for every division.

- **With no rules, nothing is drawn.** Your list is null, the call is not made,
  and the division draws exactly what pack 3's did: the same daughters from the
  same seed (check 16).
- **The rules are rolled at the pinch with the DNA**, from your list as it stands
  then. A division left while choosing keeps both lists and offers the same two on
  return (§9).
- **The chosen daughter's list becomes yours. The other's goes with her into the
  water** as her `brain` (§6.2).
- **Your list changes even asleep.** The switch decides who drives; the list is
  what your cell is (§2.3).

**You may undo a change.** With row 31 answered as recommended, the change is a
proposal: keep it, take her sister, or edit it away. The water cannot edit, so
the water keeps every change it is dealt; you are the one cell that can.

### 6.2 Your sister

In single player and as a host, `put_sister` places her with her list:

| your list | your sister carries |
|---|---|
| none (null) | the founders' rules, as every sister did in pack 3 (`Body.brain` null) |
| a list, on or asleep | the list she was given at the pinch |

So your rules enter the water's families. A sister whose list hunts well
divides, and her line passes it on, changed at every division. Nothing of this
is shown (row 21 stands); `behaviours` and `unchanged` on the dev readout count
her list with the rest.

**A guest's sister** carries the founders' rules until phase 4-3 (§10.3).

### 6.3 What the choosing screen must show

Named here. The screen's mark is designed with phase 4-2 (`automation-ux.md`
§11, item 1):

- **The daughter whose rules changed, and the change, in the rules' own words**:
  a value moved one rung, a test, an input or an output replaced, two rules
  swapped, one copied below itself, or one removed.
- **Computed by comparing the two lists**, never by asking which kind of change
  was drawn: the same principle as the DNA's caret (`choosing.md` §6), so the
  mark stays right whatever kinds of change a later pack adds.
- **That her sister carries yours as it is.** Nothing more is needed to read the
  difference, since the two lists differ by one change.
- **Nothing new when you have no rules**: the screen is today's.
- The choice stays a lean (`choosing.md` §4); nothing here is a new gesture.

---

## 7. A death, and the worlds

**A death keeps your rules** (row 30). The next cell is a new cell at generation
1, with a born body and a born DNA (`_return`), and it runs your list from its
first tick if your hand is off. Rules for organs it was not born with are asleep
until it grows them. The rules are what a player builds over many thirty-second
lives, and a death that wiped them would make building them pointless. The
alternative is the run's own philosophy, "a run keeps nothing" (`normal_mode.gd`'s
`_return`): every new cell would start with no rules.

**Each world keeps its own rules** (`settings.md` §4.1: "each world keeps its
own water, and your cell in it"). A new world starts with none. Copying a list
from another world is a hook (§14), not designed.

---

## 8. What a player must see

Named here; `automation-ux.md` designs how each one looks. A mechanic nobody can
see is not designed.

### 8.1 In play, in both views

1. **Whether your rules have your cell, or you do.** Nothing at all while you
   have no rules or they are asleep. It changes at the tick the rules take back
   and on the frame a touch takes over.
2. **Which of your rules is acting**: each rule that won a trigger on the last
   tick, by its place in your list, 1 to 8. Up to four at once, one for each of
   steering, the tail, the push and the dash; a rest is one rule acting on all
   of them. `automation-ux.md` §6.2 shows it in the water by the organ that
   decides, and by place on the page and in the replay (row 32).
3. **Your tail at rest.** In point of view your strokes' blooms (`impulsed`, the
   `thrust` sensation) stop, which is already true, and in full vision your cell
   coasts to a stop. But both views draw your flagellum on a clock (`cilia.gd`),
   the soma figure in point of view and the cell in full vision, so a resting
   tail is drawn beating. It should be drawn still while your rules rest it.

**What your rules do already shows as your hand's does**, and needs nothing new:
a turn shears the membrane (`shear_rate()` reads the steer, whoever set it), a
dash blooms, and a stroke blooms. What is new is *who* did it, items 1 and 2.

**Constraints the two views put on all three.** In point of view the screen's
edge is the senses' channel (`perception.md` §3), interface subtracts light and
never emits it, and nothing may look like a sensation: no rings, no glow at a
bearing (`controls.md` §3, §4). In full vision nothing may hide the water. Both
shapes, 1280x720 and 2400x1080, and 48 px for anything touched. **Nothing shown may tell
the player more than their organs do**: a rule acting says only what its input
reported, which your membrane is already showing.

### 8.2 On the screen

1. **Your list**, at most eight rules, in your organs' words (§13.1).
2. **What the screen offers**: only the parts your DNA's genes declare, and the
   body's and the metabolism's. Carried genes are offered, marked as not worn.
3. **Each rule's state on the last tick**: acted; passed over, because a rule
   above took its trigger; asleep, because its organ is not worn (and which
   organ); quiet, its sense reported nothing; or reported, and no report passed
   its tests. `Rulebook.choose` learns to say this for any caller (§13).
4. **What each of your senses reports now**, for setting a test against: your
   hunger in percent, seconds since you ate, each echo's bearing, distance and
   size. In single player the water waits while the screen is open, so these are
   the last tick's.
5. **What your cell does when nothing fires: it drifts, its tail still.** Said
   most clearly when no rule of yours can ever swim (no `swim` rule whose organ
   is worn), because then your cell stops the moment you let go.
6. **The switch**, and whether your rules are asleep.

### 8.3 On the choosing screen

§6.3.

### 8.4 In the replay

**Who had your cell and which rules acted, through the whole run**, in the
`what you felt` pane at least, so a death can be read back as "my rule 3 turned
me into it" (§11).

### 8.5 What no player sees

The water's cells' rules (row 24 stands) and your sister's line (row 21 stands).

---

## 9. Saves

**Kept per world, in the world's file** (`drop_save.gd`), by declared name, at
the save points the drop already has (`ocean.md` §9.3: a death, pause, leaving,
the app backgrounded), and also **when the screen closes with a changed list in
single player**, where the water is paused under it and the save's two or three
frames are never seen. In a pond the water runs under the screen, so the next
save point keeps the list. Optional keys: **`FORMAT` stays 1**.

| key | what | when absent |
|---|---|---|
| `own_rules` (top level) | `{"version": 1, "lines": PackedStringArray, "on": bool}`: your list in the text of behaviour.md §5.1, and the switch | no rules |
| `cell.fed` | seconds since the cell last ate | never ate |
| `cell.daughters[k].rules` | each daughter's list, when a division was left while choosing (phase 4-2) | both carry your list |

- **Top level, not in `cell`**, because `cell` is empty after a death and your
  rules are not (§7).
- **A name this build does not know**, a gene from a later content pack, loads
  as a rule that never fires and is written back as it came (`rulebook.gd`'s
  inert rule, as the water's lists are kept).
- **An `own_rules` this build cannot read**, under a version it does not know or
  with more than eight lines, is **kept as it came and written back unchanged**,
  and you have no rules in this build. The log says so. A player's work should
  not be lost to a content pack going back a version.
- **A pack-3 build** ignores all three keys and writes the file back without
  them, so going back to pack 3 loses your list. That cannot be fixed from here.
- **Not kept**: the heading your rules held, their random turn, their memory and
  an unfelt hit. A resumed cell comes back behind the beat (`ocean.md` §9.3) and
  its rules start fresh, as its call's returns in flight are not kept today
  (`food.gd`'s `player_state`).
- **The server's room** has no `own_rules`: it is nobody's drop. A guest keeps
  its own in its own world while it swims in a friend's (`ocean.md` §9.1).
- **Size**: at most eight lines of about ninety bytes, under 1 KB before
  compression, against a drop's 27 KB on disk (`ocean.md` §9.3).

---

## 10. The shared pond and the server

### 10.1 Who runs what

| | host | guest | dedicated server |
|---|---|---|---|
| your rules | run on your device, read your senses in your water | run on your device, read your senses on the mirror (`_step_organs` runs there) | has no cell and no rules of its own |
| your sister | in your water, with her list (`put_sister`) | by SISTER: the founders' until 4-3, then her DNA and her list | places each guest's sister; from 4-3 with her list |
| the open menu | nothing pauses; your rules drive while it is up | the same | -- |

### 10.2 The referee: nothing it copies moves

The host judges a guest's motion, never how it was asked for. Your rules ask for
nothing your hand could not:

- **a steer between -1 and +1**, so the turn never passes the cirrus's rate,
  under the referee's 1.35 rad/s;
- **a push of at most full strength**;
- **a dash on the hand's own cooldown**, 1.4 s;
- **strokes never closer than the tail's own shortest gap**, because a rest holds
  the clock and never resets it (§3.2). A still tail is only slower, and the
  referee bounds speed from above.

`HAND_LETS_GO` and `HOLD_BAND` are not values the referee judges by. **So
`Wire.RULES` stays `46913eab…` and phases 4-1 and 4-2 need no protocol change**:
`net_probe --referee-only` passes unchanged. Mixed builds play together until
4-3, and whose sister carries what depends on each phone's build.

**Repeat the false-positive runs anyway** (`net-hardening.md`): a guest on rules
makes motion no guest made before, such as a still tail and a half push. Check 15.

### 10.3 SISTER carries her DNA and her rules: phase 4-3, PROTOCOL 6

Today a guest's sister arrives in the host's water with only her worn body, so
she carries the founders' rules and a DNA equal to her body (`lineage.md` §8).
A host's sister carries both. Row 33 recommends closing that, which pack 2
already named for the next protocol change (`lineage.md` §10).

- **SISTER gains her DNA and her list**: after today's fields, her DNA in the
  same by-name format as her worn tiers (copies 1 to 3), then `u8` count of rules
  (0 to `Drop.MOST_RULES`), then each rule as `u8` length (1 to `RULE_BYTES_MAX`,
  128) and its line in ASCII.
- **The decoder refuses the whole SISTER** on more than eight rules, a line
  longer than 128 bytes or empty, a byte outside `a-z`, `0-9`, `.`, `-`, `>` and
  the space, a gene name outside the wire's rule (`NAME_MAX`), or trailing bytes:
  the shipped refusal style (`take_sister`).
- **`SISTER_MAX`** grows to `EVENT_HEADER + 13 + 2 × TIERS_MAX + 1 + 8 × (1 +
  RULE_BYTES_MAX)`, 1,336 bytes plus the header. In practice about 0.4 to 1 KB,
  once per guest division, on a reliable channel.
- **The host reads the lines with its own vocabulary**: a name it does not know
  is a rule that never fires, kept and written back in the room's save. Count 0
  gives her the founders' rules.
- **The referee judges her place and size as it does today, and nothing more**
  (`judge_sister`). It never judged her worn body, and her DNA and her list are
  the same kind of thing: any list is one evolution could reach, and the screen
  could build. So **`Wire.RULES` stays `46913eab…`; only `Wire.PROTOCOL` moves,
  5 to 6**, because the message's shape changes and a protocol-5 host would
  refuse the longer SISTER and leave the division unanswered. A 5 is refused at
  HELLO by name, as 1 to 4 are.
- **Her lineage record stays the host's**: ids are per drop, so she is the
  founder of a line of her own in the host's water, as today.
- **The dedicated server updates last** (`CLAUDE.md`): from the moment the phones
  have 6 until the server restarts empty, phones and server refuse each other with
  the version sentence. That is the price of every protocol change.

---

## 11. The replay

The replay records what moved, and your rules move nothing that is not already
recorded. What is new is *why*, and that has to be recorded to be drawn
(`replay.md` §4.1). Two state deltas, both dictionaries, so the ring's 322 floats
a frame do not change:

| delta | payload | recorded |
|---|---|---|
| `Delta.RULES` | your list's lines and the switch | at the start of the window, and at every edit and every birth |
| `Delta.ACTS` | who has your cell (no rules or asleep, yours, your rules'), and a mask of the rules that acted on the last tick | whenever either changes: at most 7.5 a second, usually far fewer |

`DAUGHTERS` is unchanged: the replay does not show the strands (`choosing.md`
row 3), and so does not show the rules' change either. The replay draws the
in-play indicator from these in its `what you felt` pane (§8.4); how is the UX
designer's. A run with no rules records neither.

---

## 12. Cost

Reasoned from the code. **Unmeasured.**

- **The tick.** One `Rulebook.choose` every eighth frame. Pack 3 measured about
  13 µs for each water decision on this container, mostly GDScript call overhead
  (behaviour.md §9). One more decision is about 1.6 µs a frame on average here;
  at `ocean.md` §4.4's assumed factor of six, about 10 µs a frame on a phone, 80
  µs on the frame that ticks. Against pack 3's +3.5 to +6.5 ms a frame on a phone,
  it is lost in the noise.
- **No new sensing.** Your rules read the reports your membrane's frame already
  took (§3.1). The one addition is keeping your call's returns until they ring
  out: at most five, once a call.
- **Every frame**: one angle difference for the held heading, and the hand's
  keys, which `_read_steer()` already polls.
- **The water**: your sister is one more list among as many as there are hunters
  (behaviour.md §7.1); nothing grows.
- **The replay**: a small dictionary when who drives or what fired changes.
- **The wire, from 4-3**: up to 1.3 KB once per guest division.
- **The screen**: `automation-ux.md`'s to cost. Open in single player, it is over a
  paused water; in a pond, the water runs under it.

Where it shows: the dev app's frame readout, `dropped` and `water`. Nothing
here is paid per body or per pair of cells: it is one body's worth, once.

---

## 13. Generic mechanics, names at the edges

| file | knows | does not know |
|---|---|---|
| `game/mechanics/rulebook.gd` | as pack 3, plus **one optional output of `choose`**: each rule's state on the tick (acted, passed over for a claim above, asleep, quiet, reported but failed, unreadable), for any caller that asks | a player, a hand, a screen |
| `game/normal/own_rules.gd` **new** | **the player's wiring**: each declared input to the report of your organ's frame, each output to your body, the list, the switch, the tick, the handover. Its rules' fields are a `food.gd` `Body`'s (held heading, claims, tumble, memory, hit), run by the water's own triggers, with the dash wired to your cell's | how a list is chosen or changed |
| `game/normal/cell.gd` | the hand (`hand_on()`), `HAND_LETS_GO`, `HOLD_BAND`; reads the claims for the steer, the tail's clock, the push's strength and the dash; `steering_off` silences the hand only | how a rule wins |
| `game/normal/food.gd` | one report function per input, shared by the water's reader and yours; the pending hit at `hear_contact`'s `BITTEN`; your call's returns kept as a water cell's are; `put_sister` and `place_sister` take a list | the screen, the hand |
| `game/normal/drop.gd` | unchanged: `MOST_RULES`, `CHANGES`, `daughter_behaviours`, which your division calls as the water's does | the player |
| `genome.gd`, `cell.gd`, `metabolism.gd` | **the words** for each part they declare, beside `DECLARES` (§13.1) | the screen's layout |
| `game/normal/normal_mode.gd` | the run: builds and ticks your rules, hands lists on at a division and into your sister, keeps them in the save, wires the indicator | rule arithmetic |
| the screen | `automation-ux.md` | rule arithmetic |

### 13.1 Words for the chips

The chips come from the declarations, so **a new gene needs words, not a new
screen** (behaviour.md §3.5, §11). Each declaring file keeps a words table beside
its `DECLARES`, keyed by qualified name (`ocellus.beam`, `body.turn-toward`,
`metabolism.fed`) and by value name, as a `const` of plain strings whose comment
carries `TRANSLATORS:`, which is how `tools/i18n_pot.gd` takes a table of words
into the template. `DECLARES` itself holds plain strings that are not words
(`"in"`, `"name"`), so it must not carry the comment. The rulebook's own words,
`always`, the four tests, `mouth` and `body`, and the units, live with the
screen. **Which words is the owner's**: `automation-ux.md` §7 proposes them (row
35), and row 34 names the whole.

Adding a gene with a sense and a trigger is now behaviour.md §3.5's three steps
plus two: its words beside its declaration, and its report registered for the
player in `own_rules.gd`.

---

## 14. What pack 4 leaves for later

Hooks, not designs.

- **The hand as the first rule** (§2.1's (d)): the hand claims only the triggers
  it is working. `own_rules.gd` already holds the claims per trigger; the
  takeover would claim fewer.
- **A rest for the hand**: the one trigger your hand lacks (§3.3). A fourth verb
  is `controls.md`'s to add on every scheme.
- **A rule that holds a list** (behaviour.md §2.1): a tree one level deep, when
  eight rows stop being enough.
- **Your family, shown** (row 21): your sister's line carries your rules, and the
  record (`id`, `parent`, `lineage`) is there to mark it.
- **The water's rules, shown** (row 24): the rulebook's new per-rule state
  serves a water cell as well.
- **Sharing a list**: with a friend by invite, or from one world to another.
  Lines by declared name are already the wire's and the save's form.
- **Where a gene goes, as a rule**: placement is behaviour (`lineage.md` §3.2),
  and a water cell's layout waits for the wire (behaviour.md §4.4).
- **Every resting tail drawn still**: a POND entry's speed already says when a
  water cell is carried at 9 µm/s.
- **The screen arriving later in a player's life**, rather than from the first
  cell: not designed.
- **More words, more organs**: every later gene that declares an input or an
  output reaches your screen with its words.

---

## 15. Starting values

None of these was measured. Each is where the playtest starts.

| | starting value | why | watch for |
|---|---|---|---|
| `HAND_LETS_GO` | 0.5 s | a re-grip under `anywhere` takes about a quarter of a second, and the rules should not twitch the cell between two touches | the cell ignoring its rules for a noticeable moment after you let go (shorten), or twitching between your touches (lengthen) |
| `HOLD_BAND` | 1.3 rad, 75° | the cirrus's lag times its rate is 0.66 to 0.69 rad at every tier, and a band of about twice that settles with a few degrees of overshoot (§3.2) | rule turns that overshoot and swing back (widen), or creep onto the heading (narrow) |
| the tick | every eighth frame, `Drop.LOD_EVERY` | the water's, so the lead and rising and falling mean the same in both bodies | -- |
| the most rules | 8, `Drop.MOST_RULES` | the water's: one phone screen | wanting a ninth |
| a test's value | a rung of its ladder | the space the water's changes step along | wanting a value between two rungs |
| the change at your division | `drop.gd`'s `CHANGES`, one change | the water's (row 19) | changes you always undo |
| `RULE_BYTES_MAX` (4-3) | 128 bytes | the longest rule today, an echo with three tests driving a push, is about 90 | -- |

**A balance note, recorded and not acted on.** With row 29 as recommended, your
rules can keep your tail still, and a cell resting from birth outlasts a drifting
one by about twelve seconds of thirty-four (§3.3, arithmetic). Your hand cannot
do that. If players feel automation outlives them too easily, the levers are a
rest for the hand (§14), or a price on standing still. None is pulled: balance
waits for players.

---

## 16. Left open

1. **Nothing here was measured**, by the owner's choice: the cost on a phone,
   how the handover and the held heading feel, and how dangerous a player's rules
   make the water once their sisters' lines spread.
2. **Whether players understand *always swim*.** A list starts with it (§5).
   Under row 29, a player who removes it, or puts a rest above it, stops their
   cell whenever they let go. The screen has to say so (§8.2 item 5), and only a
   player can say whether that is enough.
3. **A still tail drawn beating**, in both views, for the water's cells today and
   for yours until §8.1 item 3 is built.
4. **Rules outlive the hand** (§15's note). A balance question for players.
5. **What the water does with players' lists**: a server's room, from 4-3, takes
   every guest's sister's list into its families. Whether one player's list
   takes over a room is the playtest's.
6. **A keyboard-only Windows player** and the screen, and the room the choosing
   screen has for one more line: `automation-ux.md`'s (§4.7, §11).
7. **A pack-3 build reading a pack-4 world** loses the list on its next write
   (§9). Only going back a content version does this.

---

## 17. Owner's calls

Rows 27 to 35, numbered on from `behaviour.md`'s row 26, so that one number names
one call across the documents. The screen's calls are in this one table too:
rows 28, 31, 32 and 35 (`automation-ux.md` §12). It says *instincts*, row 34's
recommended name. No balance rows (`CLAUDE.md`, "Balance waits for players").
Put to the owner on 2026-10-02.

| # | Question | Options | What it means |
|---|---|---|---|
| 27 | When do your instincts drive your cell, and when do you? | **whenever your hand is off the controls; touching them takes over at once ✓ recommended** · your instincts do whatever your hand is not doing at that moment · a way to play chosen before a run: you steer, or your instincts do · a switch on the pause screen | Hand off: you steer as today, and the moment you let go your cell follows your instincts; touch again and it is yours. Nothing changes for a player with none, and a player who never touches watches their cell live by its instincts. Whatever your hand is not doing: your instincts keep acting under your thumb, so one can lunge while you steer, but one can also push or dash when you did not expect it. Before a run: each run is all yours or all your instincts', and in an instincts run your controls only choose a daughter. A switch: the same, changed from the pause screen during a run. |
| 28 | What does a new player's cell start with? | **none, and the empty page offers to write one or to copy the water's seven ✓ recommended** · none, and the page offers only to write one · the water's seven, from the first second | None, with a copy: a new player sees nothing new until they open the page, and there they can build a first instinct or start from what the water's own cells do. Theirs rest while they are fed, so a cell with them stops when you let go after eating. None, without: every list is built by hand from the first block. The water's seven from the start: letting go makes your cell behave like the water's cells, and two of their instincts make it rest while it is fed, so a newborn who lifts a finger stops dead. |
| 29 | May your instincts stop your tail? | **yes, as a water cell's do: it beats only while an instinct says swim ✓ recommended** · no: your tail always beats on its own | Yes: while your instincts have your cell, it can lie still and save the food its tail burns, about a third of what a newborn spends, which only your instincts can do. A list starts with an instinct that says swim; take it away and your cell drifts when you let go. The water's cells already work like this, and your sister takes your instincts into the water. No: your tail beats as it does today, and resting only stops turning, pushing and dashing. A list that works for you could then leave your sister drifting in the water, where nothing beats a tail by itself. |
| 30 | After a death, does your next cell keep your instincts? | **yes, your instincts are yours ✓ recommended** · no, a new cell starts with none | Keep: you build your instincts over many short lives, and a death costs you your cell, not them. None: every life starts from an empty list, as every life starts from a born body. |
| 31 | When and where do you change your instincts? | **whenever you like, on a page of the pause screen beside the genome ✓ recommended** · whenever you like, over the water without pausing · only between lives, on a screen before each new cell | Pause page: tap pause, then `instincts`. Alone, the water waits while you think; with a friend it keeps moving, and your instincts steer you while you edit. Over the water: you watch them work while you edit, but on a phone the rows cover the water, the water needs a second button, and alone you can be eaten mid-edit. Between lives: each life tests one set, and you cannot fix an instinct when you see it fail. |
| 32 | While you play, how do you see which instinct is acting? | **the organ it listens to draws a thread to your nucleus ✓ recommended** · that, and a row of eight small beads in a corner, lit by place · nothing in the water: only on the page and in the replay | Thread: when your ping steers you, a violet line runs from your ping to your nucleus, the same colour as the echo on the screen's edge. Nothing is written in the water. Beads: you also see "the third one" while playing, but it is the first readout this game would put in the water. Nothing: the water stays as it is, and you read your instincts after the fact. |
| 33 | When a friend divides in your water, does the daughter left there carry their instincts and all their genes? | **yes, in an update of its own; every phone and the home server must have it to play together ✓ recommended** · not yet: she carries the water's own instincts and only the genes she shows | Yes: a friend's daughter behaves as they do and passes on everything she carries, as your own daughters already do in your water. Phones with the update and phones without refuse each other, and the home server refuses updated phones until it restarts with the update, which it does once its water is empty. Not yet: hers are the only daughters that don't carry their mother's instincts, and different versions keep playing together. |
| 34 | What are they called in the game? | **instincts ✓ recommended** · reflexes · rules | Instincts: behaviour a cell is born with, passes to its daughters and runs without being told, which is what these are; the same word in French. Reflexes: right for "when hit, turn away", but not for "always swim". Rules: plain, and what the code calls them, but it reads like a menu of settings. |
| 35 | Which words do the blocks use? | **the set in `automation-ux.md` §7, such as echo, meal, smaller than my mouth, tumble ✓ recommended** · plainer: `fed` and `turn at random` · symbols: `< my mouth`, `> 30%` | The set: a sense's word, then what it is tested against, then what your cell does, all in plain words, the same in French, and every one fits a phone. Plainer: closer to the code's own names, and `tourne au hasard` is longer. Symbols: shorter, but this game says things in words. |

**Under the table.**

- **27.** Option two is §2.1's (d). On paper it is the better game for a player
  whose thumb is always down, because their instincts still lunge for them. It is
  recommended against for now: what is acting gets mixed with what you are doing,
  and a player learning their instincts cannot tell which did what. It is the
  next step once the first has been played (§14). The other two split the game in
  two, and both still need the hand at every division.
- **28.** The copy offers only the founders, never what a family evolved, so row
  24 stands. It is the one way the water's own behaviour reaches a player at all.
- **29** is the call behaviour.md §11 left to the owner. The deciding argument is
  the sister: a list has to mean the same thing in your cell and in hers.
- **31** joins two halves of one call: when you may edit, this document's, and
  where, `automation-ux.md` §1's. Placing a gene without pausing is one gesture;
  writing an instinct takes several taps, which is what pause is for.
- **32.** The second option answers §8.1's "by its place, 1 to 8" literally. The
  recommendation answers it by organ, because a place in a list is a number and
  this game's water carries none (`diegetic-hud.md` §1).
- **33** is phase 4-3, so the owner can play 4-1 and 4-2 with mixed builds and
  decide when the protocol moves. It carries her DNA as well as her instincts,
  because both are what a daughter passes on and both wait on the same protocol
  change (`lineage.md` §10).
- **34** names the whole, for the button and the page. **35** is every word on
  the chips; `automation-ux.md` §7's table is the whole set, so one word can
  change without the others.

**Not asked, because row 19 decides it: your division changes one daughter's
instincts**, the one whose genes changed, as the water's do. Row 19: *"every
division. No specific treatment between NPCs and players"*. behaviour.md §11
meant to confirm it once the screen exists, and phase 4-2's playtest is that
confirmation (§19).

**Settled here, not asked**, because the owner's rules or an answered row decide
them: your instincts read only your organs ("No magic info"); a test's value is
a ladder's rung (the water's space, row 19's same rules); your sister carries
your list, and the founders' when you have none (behaviour.md §11, row 22); your
instincts never choose a daughter (no sense reports one); each world keeps its
own list (`settings.md` §4.1); a list starts as *always swim*, which is today's
cell (§5); a resting player coasts under its own drag rather than being carried
at 9 µm/s (its own body's physics); and `Wire.RULES` does not move (the referee
judges motion, and your instincts make none your hand could not).

---

## 18. Build plan

### 18.1 Files

| file | change | phase |
|---|---|---|
| `game/mechanics/rulebook.gd` | `choose` fills an optional per-rule state array (§13) | 4-1 |
| `game/normal/own_rules.gd` | **new** (§13) | 4-1 |
| `game/normal/cell.gd` | `hand_on()`, `HAND_LETS_GO`, `HOLD_BAND`; `_read_steer()` takes the rules' held heading when they drive; `_pushing()` becomes a strength; the stroke clock held while the tail rests; a dash the rules fire bypasses `steering_off`, which silences the hand only; the onboarding reads the hand's steer, not the rules' | 4-1 |
| `game/normal/food.gd` | each `_read_X` split into sensing and a shared report; your call's returns kept until they ring out; the pending hit at `hear_contact`'s `BITTEN`; `put_sister` and `place_sister` take a list | 4-1 |
| `game/normal/genome.gd`, `cell.gd`, `metabolism.gd` | the words tables beside `DECLARES` (§13.1) | 4-1 |
| `game/normal/normal_mode.gd` | builds and ticks `own_rules`; the meal clock for `fed`; a death keeps the list; your sister gets her list; the save's keys; the indicator's wiring; a save when the screen closes with a changed list in single player | 4-1 |
| the screen and the indicator | `automation-ux.md`'s files | 4-1 |
| `game/normal/drop_save.gd` | `own_rules` and `cell.fed`, each checked when present; an unreadable `own_rules` kept and written back | 4-1 |
| `game/replay/recorder.gd`, `replay.gd`, `panes.gd` | `Delta.RULES` and `Delta.ACTS`, and the indicator drawn from them | 4-1 |
| `game/normal/normal_mode.gd`, `drop_save.gd` | `_make_daughters` rolls the changed daughter's list; `_kept_pair` checks the lists too; `cell.daughters[k].rules` | 4-2 |
| `game/net/wire.gd`, `pond.gd` | SISTER with her DNA and her list; `RULE_BYTES_MAX`; `PROTOCOL := 6` with a paragraph in the style of 4 and 5; the host places her with both | 4-3 |
| `game/i18n/biogenic.pot`, the French catalog | every new word, through `tr()` | each |
| `tools/drive.gd` | `--own-rules=<lines, ;-separated>` or `=founders`, `--own-rules-off`; with `--own-rules`, who drives and what acted on lines of their own, so a run without it traces as `dev` does. `forage_probe` wraps `drive.tscn`, so it takes them unchanged | 4-1 |
| `.github/workflows/ci.yml` | one step beside "Check the input path": check 1's three seeded runs against the pinned hash. Repository furniture, in neither the pack nor the binary | 4-1 |
| `tools/drop_probe.gd` | the checks of §18.3 | each |
| `tools/net_probe.gd`, `tools/net_fuzz.gd` | checks 15 and 19 to 22; the fuzz corpus gains SISTER frames | 4-1, 4-3 |

**Nothing** changes in `addons/launcher/`, `ci/` or `project.godot`. **No new
input action is needed**: a key the screen needs is polled as `cell.gd` polls
Space. If one ever needs an action in `project.godot`, that is a `binary_version`
bump, and no reason to avoid it (`CLAUDE.md`). **`binary_version` does not
move.** Every phase is GDScript, scenes and translations: a content pack.
`Wire.RULES` stays `46913eab…`.

### 18.2 Phases

Each phase is one pull request into `dev`, played on the dev app before the next
starts.

| phase | contents | what the owner can try |
|---|---|---|
| **4-1** | your rules drive your cell when you let go: the wiring, the hand, the tail, the held heading, the switch, the screen, the indicator, the save, the replay, a death that keeps them, your sister carrying your list (single player and host), checks 1 to 15 | build a list, let go, and watch; take over; die and come back with it; relaunch |
| **4-2** | your division changes your rules: the change on the changed daughter, the choosing screen's mark, the kept pair; checks 16 to 18 | divide with rules, read the change, keep it or undo it |
| **4-3** | a friend's sister carries their DNA and rules: SISTER, `PROTOCOL` 6; checks 19 to 22 | divide in a friend's water, and in the server's room |
| the release | | whenever the owner runs it |

### 18.3 What the build checks

In `drop_probe`'s "Check the drop" step unless a check names another place,
each of which must fail with its rule taken out:

1. **No rules, no change.** With no rules, a seeded `drive.gd` run (seed 1, 60 s,
   `--trace=0.5`, under each scheme) prints `dev`'s trace to the byte, and a
   division posed with `--radius=40` rolls `dev`'s daughters. The build takes the
   trace's hash on `dev` before its first commit and pins it, as `DEV_LINES` pins
   pack 2's lines; a step in `.github/workflows/ci.yml`, beside "Check the input
   path", runs the three and compares. "Check the input path" itself passes
   unchanged. **And the same three runs on `--own-rules=always -> body.swim` print
   the same trace**, but for the lines that say who drives: the list a player
   starts from is today's cell, to the byte.
2. **You read what a water cell reads.** Pose the player and a water cell alike
   (place, heading, size, genome, arcs): every input's report for your rules
   equals the water cell's reader's, to the float.
3. **No magic.** An input of a gene you do not wear never reports; a mote and your
   own bite are never a `hit`; nothing in the vocabulary reads dread or the wake.
4. **The handover.** Under `always -> body.turn-random` and `always -> body.swim`:
   a held key, a held pad, a held stick and a finger under `anywhere` each make the
   steer the hand's on the frame it lands and clear the held heading; the rules
   act again on their first tick at least `HAND_LETS_GO` after the last control is
   let go; a press on open water under `stick` and `pads` takes nothing over; the
   pond menu's `steering_off` hands the cell to the rules.
5. **The tail.** Under `always -> body.rest`, and under a list that claims no
   swimming, no stroke fires while the rules drive, and a born cell burns its
   upkeep alone; under `always -> body.swim`, strokes fire on the tail's own clock;
   under a list that flips rest and swim every tick, no two strokes are closer than
   the tier's shortest gap.
6. **The held heading settles.** At cirrus tiers 0 to 3, a held heading 90° and
   180° away is reached and held, overshooting by less than 15°, and the turn is
   paid at `TURN_COST` a radian as the hand's is.
7. **Push and dash.** `axoneme.push 0.5` gives half the hand's thrust at half its
   price; `myoneme.dash` dashes on the hand's cooldown and price; neither acts
   without its organ.
8. **Edits.** An edit acts at the next tick and clears what the rules held; a
   list the screen builds survives its lines; no value off a ladder is offered.
9. **The save.** `own_rules` and `cell.fed` round-trip exactly; a pack-3 world
   loads with no rules; an unknown name loads as a rule that never fires and is
   written back as it came; an `own_rules` of an unknown version is kept, written
   back and not run; each world keeps its own; a death keeps the list.
10. **Your sister** carries the list she was given (host and single player), and
    the founders' when you have none.
11. **Determinism.** One seed with rules on, run twice, prints the same trace.
12. **Modular.** The probe's test gene (behaviour.md check 8), with its player
    report registered by the probe, is offered to a player who carries it, read
    and acted on by your rules, and kept by name, with no change to the screen,
    `rulebook.gd`, `own_rules.gd`'s handover or the save code.
13. **Alive**, run by the build and not in CI (twelve simulated minutes).
    `forage_probe` with `--own-rules=founders` and a genome that wears every
    organ the founders read, seeds 1 to 4, three minutes: every founder rule acts
    on the player's cell at least once, and the cell eats at least once across
    the four. This checks that the wiring is alive, not how well it forages.
14. **The replay.** A run with rules records the list and every change of who
    drives and what acted; a run without records neither.
15. **`net_probe`: never cut for rules.** The referee section passes with
    `Wire.RULES` `46913eab…`. The `pond` and `server` sections, which end by
    checking that no referee fouled an honest guest (`net-hardening.md` B.3), run
    again with that guest on rules that rest, swim, push at half and full, dash,
    and flip between rest and swim every tick, and still end with no foul.

Phase 4-2:

16. **A division.** The daughter whose DNA changed carries a list one change from
    yours, and her sister yours; with no rules nothing is drawn, so a seeded
    division rolls `dev`'s daughters.
17. **Left while choosing.** A save made while choosing keeps both lists, and the
    division offers the same two on return.
18. **The mark** is computed by comparing the two lists: a nudge, a replace, a
    swap, a copy and a drop each mark what changed (the choosing screen renders it,
    designed with 4-2).

Phase 4-3, in `net_probe`:

19. **SISTER carries her DNA and her list**: a guest's declined daughter arrives in
    the host's water with both; with count 0, the founders'.
20. **Refusals**: nine rules, a line of 129 bytes, an empty line, a byte outside
    the alphabet, or trailing bytes, and the SISTER is refused whole.
21. **The handshake**: protocols 1 to 5 refused by name; the referee section
    unchanged.
22. **The server's room** keeps a guest's sister's list through a save and a load.

### 18.4 What it replaces

| pack 3 | pack 4 |
|---|---|
| `_read_steer()` reads the hand alone | the hand, or your rules' held heading when they drive |
| `_pushing()`, yes or no | a strength: the hand's full, or a rule's half or full |
| the tail always beats | it beats unless your rules drive and say rest, or nothing says swim |
| your sister carries the founders' rules | she carries the list she was given; the founders' when you have none |
| the choosing screen shows the DNA | the DNA and the change to your rules |
| the world's file keeps your cell | your cell and your list, which outlives a death |
| a guest's sister carries her worn body (`PROTOCOL` 5) | her body, her DNA and her list (`PROTOCOL` 6, phase 4-3) |
| the replay records what moved | what moved, who drove, and which rule acted |

---

## 19. What to watch in the playtest

**In phase 4-1, building a list**: whether you can tell at a glance, in both
views, when your rules have your cell and which one is acting; whether the half
second before they take back feels right, or the cell either ignores you or
twitches between touches; whether a cell that stops its tail reads as resting
rather than broken; whether the *always swim* a list starts with makes sense,
or you take it away and your cell stops when you let go and you don't know why;
how your rules' turns
feel, overshooting or creeping; whether keeping a cell alive without touching is
possible, and fun; and whether you find yourself wanting your rules to act under
your thumb as well, which is row 27's second option.

**On a phone**: the frame readout's `dropped` row with your rules on, against
with them off.

**Across lives and launches**: your list still there after a death, after a
relaunch, and separately in each world.

**In phase 4-2**: whether the change at a division reads on the choosing screen;
whether you keep the changes, take the sister, or undo them on the screen; and
whether the change ever teaches you something you would not have tried.

**In a pond**: your rules driving while the menu is open; a friend on rules
moving smoothly on your screen; and, after 4-3, whether a friend's daughters
behave like them.

**Over days, in the server's room (after 4-3)**: whether players' lists spread
through the water, and whether one takes it over.

**And a balance note to judge, not a call**: whether a cell on a rest rule
outlasts hunger too easily (§15).
