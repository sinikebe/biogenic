# Your instincts: programs, the library and the autopilot

Pack 4 of the evolving water (`roadmap.md`, "Next"). The owner, 2026-09-29,
introducing the whole feature:

> I want to make the AIs logic evolving. By that I mean random logic at the
> start, then each cell that divides carries genes but also behavior logic (AI)
> with small mutations. [...] And while we're at it, we could propose to players
> a screen where they can use the same logic blocks to automate their cell !
> Offering a new gameplay type. Both should use the same logic system.

Pack 1 made the drop (`ocean.md`), pack 2 made its cells divide (`lineage.md`),
and pack 3 gave every water cell ordered rules that it carries, passes on and
changes at division (`behaviour.md`). This pack lets the player write the same
rules for their own cell. `behaviour.md` §11 is its contract, and every point of
it is answered here (§1).

This document owns the rules of the game: what your instincts read and do, when
they drive, the programs and the library, their limits and states, the tail, the
save, the wire, the replay, and what must be visible. **The screen itself is
`automation-ux.md`'s**: the page, the library on it, the rows of chips, the
autopilot's icon, the tail's control, both shapes, touch, mouse and keys. Where
the two touch, this one says what must be shown and that one says how.

**Status: designed from the code and the existing specs; nothing prototyped or
measured, by the owner's choice; the owner playtests it on the dev app.** The
owner, 2026-10-02: *"Don't measure in prototypes. I'll playtest."* Every number
below is a starting value given with its reason, arithmetic on the code's own
constants (said so where it is), or a measurement an earlier spec holds, cited
where it is used. Code references are to `dev` at `47d2308`.

**Revised the same day to the owner's answers** (§17). Four of rows 27 to 35
reshaped the design:

- **row 27**: an **autopilot**, switched on and off by an icon on the play
  screen, outside the menu, "since taking the control back can be a matter of
  life". Letting go no longer hands your cell to anything;
- **row 29**: holding the tail still is **a level-2 bonus of the tail**, for the
  hand as much as for the instincts;
- **row 30**: instincts are kept in **programs**, programs in a **library**, and
  several programs can be on at once, with a priority order between them;
- **row 32**: **nothing in the water yet** shows which instinct is acting.

Rows 28, 31, 33, 34 and 35 stand as recommended. Two calls the answers raised
were put next, and the owner answered both as recommended the same day:
**row 36**, touching the steering controls while the autopilot drives takes the
cell back and switches the autopilot off; and **row 37**, holding the tail still
is a level-2 ability of every cell, the water's included. Five more were put
after them, rows 38 to 42 (§17.2).

**Revised again the same day to those answers** (§17.2). Rows 38, 39, 41 and 42
stand as recommended, and the owner confirmed how this document reads rows 36
and 37 (§17.3). Row 40 asked where a division's change to your programs goes,
and the owner chose neither option: *"no mutation to programs made by players.
100% manual."* So **no division changes your programs; only your hand does**
(§6). The phase that changed them is gone, and the wire is now phase 4-3
(§18.2). Phase 4-1 is unchanged.

The owner's standing rules bind it: *"all cells follow the same rules. Me,
friends, NPC, doesn't matter."* -- row 19, *"every division. No specific
treatment between NPCs and players"*, which row 40 sets aside for your programs
and for nothing else (§6) -- *"A cell dies of hunger, nothing else.
Unless it gets eaten by another one."* -- and, on pack 3's blocks, *"blocks can
only contain things coming from enabled senses [...] No magic info. The cell has
inputs and produces output that acts on available triggers (turn, dash)"* and
*"The design of the blocks must be modular."* Balance waits for players
(`CLAUDE.md`): no balance number is put to the owner here.

**The words.** An **instinct** is one line: *when <a sense reports something>
-> <do this>*. A **program** is an ordered set of up to eight instincts. The
**library** is the player's programs. The **autopilot** runs the programs that
are on. "Program", "library" and "autopilot" are the owner's own words (row 30,
row 27); "instinct" is row 34's. The code keeps pack 3's: a *rule*, a *list*
(`Rulebook.Behaviour`).

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
`energy.md` §2).

**A water body on rules moves differently** (`_move_ruled`): it holds a heading
and turns toward it at its cirrus's rate, swims at its tail's speed only while a
swim rule fires, and otherwise is carried at 9 µm/s for free. A drifter, a body
with no mouth, decides nothing and is always carried (`_step_ruled`), which is
how pack 1's row 11 keeps the drop's food alive: an osmotroph at rest takes in
exactly its upkeep and never starves (`ocean.md` §5.3).

**Levels.** Only the beam earns levels by use (`cell.gd`'s `LEVELLED`). Every
other gene's level is its worn copies: `genome.gd`'s `level_of` answers the worn
tier, "which is what its strength has always been". A water cell earns no levels
(`lineage.md` §3.2), so its levels are its copies, as its beam's already are
(`food.gd`'s `_eye_of`). And a body wears what it was born with: the player's
worn tiers are fixed for a life but for the five-second gift (`referee.gd`), and
a meal writes the DNA its daughters are made of.

**The hooks pack 3 named** (§11 there): the player's blocks are the same inputs
and triggers; the triggers map onto `_read_steer()` and the controls; swim and
rest drive a flagellum that today beats on its own; a screen holds eight rules;
names are the owner's; your division changes your rules under row 19; your
sister carries your rules, and a guest's needs SISTER to carry them; no block
reads dread or the wake. In code: `Body.brain` (a water body's list, null for the
founders'), `put_sister` (no list yet), `Drop.daughter_behaviours`, and SISTER,
which carries her body and nothing else (`wire.gd`'s `sister_payload`). Row 40
has since answered one of them the other way: no division changes your
programs (§6).

---

## 1. Decided, in one place

1. **Instincts are the water's rules** (behaviour.md §2 to §4): each *when
   <input> [tests] -> <output>*, read from the top with one winner for each
   trigger, by the same `rulebook.gd`. A test's value is a rung of its ladder,
   the space the water's changes step along (§4.4).
2. **They read only your own organs**, exactly what each one posts to your
   membrane, from the reading your membrane already took that frame: no new
   sensing (§4.1). A mote and the feel of your own bite are not a `hit`. Dread and
   the wake are not inputs.
3. **The autopilot** (row 27): an icon on the play screen, and a key on Windows,
   hands your cell to your programs and takes it back. **A new press of any
   control your hand drives with takes the cell back at once and switches the
   autopilot off** (row 36). Nothing else engages it. A death switches it off; a
   division keeps it (§2).
4. **Programs and the library** (row 30): a program holds up to eight instincts;
   the library holds up to eight programs, in an order the player sets, each on
   or off. **The autopilot runs the programs that are on, read program by
   program from the top, then instinct by instinct**: one winner for each
   trigger, so a program above wins a contradiction (§3). **One library, the
   player's**, for all three worlds, outliving every death.
5. **Your cell runs eight instincts in all**, as every cell does: the programs
   you switch on share them (row 39) (§3.4).
6. **A tail at level 2 can be held still**, by the hand and by an instinct alike
   (row 29). A new output, `flagellum.hold`, declared by the flagellum at level 2;
   `body.rest` holds the tail too at level 2; a new control for the hand at level
   2. **A level-1 tail beats on its own, for every body that swims** (row 37):
   the water's one-copy hunters can no longer stop swimming. A drifter is still
   carried (§5). Level 2 means two copies (row 38).
7. **A new library is empty, and an empty library changes nothing, to the
   byte** (row 28). The page offers a new program or a copy of the water's seven
   (§3.6).
8. **No division changes your programs** (row 40: *"100% manual"*). Both
   daughters run them as they are, and only your hand edits them. **Your sister
   carries the instincts your cell ran into the water**, the founders' when none
   was on. There she is a water cell, and her line's instincts change at its own
   divisions, as every water cell's do (§6).
9. **What you must see** (§8): the autopilot's icon and whether it drives, in both
   views; a held tail drawn still; the hold's control when the tail reaches level
   2; on the page, the library, every instinct's state and what wins a
   contradiction; all of it in the replay.
   **Nothing in the water says which instinct acts** (row 32).
10. **Saved**: the library in a file of its own, `user://library.save`; the cell's
    part in its world's file, one optional key: `FORMAT` stays 1 (§9).
11. **The shared pond** (§10): your instincts run on your device, and the host's
    referee judges the motion they make, which never leaves your hand's envelope.
    **`Wire.RULES` stays `46913eab…`.** From phase 4-3 a friend's sister carries
    her DNA and her instincts: **`Wire.PROTOCOL` 6** (row 33).
12. **Generic** (§13): `rulebook.gd` learns three things any caller can use and
    nothing about a player; the player's wiring and the library are files of
    their own, and the words sit beside the declarations.
13. **Content only, in three phases** (§18.2): the tail, then programs and the
    autopilot, then the wire. No `binary_version` bump.

---

## 2. The autopilot

### 2.1 The owner's answer

Row 27 was put as *when do your instincts drive your cell, and when do you?* The
owner, 2026-10-02: *"auto pilot trigger on screen with an icon. Available even
outside the menu since taking the control back can be a matter of life."* So
**the autopilot is a switch, and the icon is how you throw it**: in play, on the
water, not only on the pause screen. Letting go of the controls no longer hands
your cell to anything, and pack 4's first design, `HAND_LETS_GO` and the half
second before the instincts took back, is gone.

It is still Brooks's subsumption (behaviour.md §2.1), one level up: the hand is
the layer above, and while it acts nothing below it does. What changed is that
the player decides when the layer below may act at all.

### 2.2 Engaging

- **The icon**, and on Windows **a key**, switch the autopilot on and off. Both
  are `automation-ux.md`'s to place and draw. On the page they say the same thing
  as on the water: one state, two ways to throw it.
- **The icon is there only while there is something to run**: while the programs
  that are on hold at least one instinct between them. A new player, with an
  empty library, never sees it; the play screen is today's. That is
  `controls.md` §1.1's rule, *a control exists only when what it works does*.
- **Switched on, your programs take the cell at their next tick**, at most eight
  frames later. Switching on lets go of whatever the hand was holding, by the
  pair the pause screen already calls (`cell.release()`, `controls.let_go()`), so
  a thumb still on the stick, or a key still down, steers nothing until it is
  pressed again.
- **Nothing else engages it.** Not letting go, not the open menu in a pond (which
  silences the hand, shared-pond.md §1.7, and leaves your cell drifting on its
  tail, as today), not a birth, not a return.

### 2.3 Taking the cell back

**Row 36, answered as recommended**: *touching the steering controls while the
autopilot drives takes the cell back at once and switches the autopilot off.*
Designed here as:

- **A new press of any control your hand drives the cell with** takes it back on
  that frame: a steer, a push, a dash, or the tail's hold (§5.2). Under
  `anywhere`, the scheme that ships, the steering control *is* the push and the
  dash: one finger on the water does all three. Reading the row the same way on
  every scheme means a dash pad or a push key takes the cell back too, rather than
  firing under an autopilot that stays on, or doing nothing (§17.3).
- **What the instincts held goes with it**: the heading, the random turn, and
  what they remember of the last tick (`memory`). The tail beats on its own clock
  again unless your hand holds it.
- **The autopilot is off**, and the icon shows it. Tap it again to hand the cell
  back.
- **Only a new press counts.** A key held through the moment of switching on, or
  a finger left down, is let go (§2.2) and takes nothing back until pressed
  again. So the hand's keys are read as presses for this, not as held states.

| | the autopilot is switched on by | your cell is taken back by a new press of |
|---|---|---|
| `anywhere`, phone | the icon | a finger on the water: it steers, pushes with an `axoneme`, and as a tap dashes. A press on the icon or the pause target is theirs, not the water's |
| `stick`, phone | the icon | the stick, the dash pad or the hold. Open water is inert under this scheme (controls.md §1) and takes nothing back |
| `pads`, phone | the icon | any pad |
| Windows, any scheme | the icon, or the key | a steer, push, dash or hold key, or the mouse button where the scheme reads it |

**Placing a gene** (`dna-body.md` §8) starts as a press on the water under
`anywhere`, so it takes the cell back; under `stick` and `pads` a press on your
body opens it at once and takes nothing back. **The icon consumes its own
press**, as the pause target does (`accept_event()`), so tapping it never also
counts as a press on the water.

**The hand alongside the autopilot**, where a touch would act and the autopilot
go on, was the first design's other candidate, "your instincts do whatever your
hand is not doing". Row 36 sets it aside; it stays a hook (§14).

### 2.4 Divisions, deaths and the menu

- **A division keeps the autopilot as it was.** From the pinch the cell is not
  simulated and nothing drives it; the lean is the hand's, as always (no input
  reports a daughter). The daughter you take is your cell going on, with the
  same programs (row 40), so if the autopilot was on, she is on it from her
  first tick. A finger still down from the lean is let go at the birth
  (`_cell.reset(true)` calls `release()`), so it does not switch the autopilot
  off; the next press does.
- **A death switches it off.** A new cell starts with your hand, and you switch
  the autopilot on when you choose to.
- **Alone, the pause stops everything**, the autopilot with it. **In a pond the
  menu stops nothing**: if the autopilot is on, your programs drive while you
  edit them, and the page says so (`automation-ux.md`).
- **It is not saved.** A cell resumed after a relaunch comes back behind the
  beat (`ocean.md` §9.3) with your hand on it.

### 2.5 The states

| state | when | your cell |
|---|---|---|
| **nothing to run** | the library is empty, or the programs that are on hold no instinct | yours: today's game. No icon |
| **yours** | something to run, the autopilot off | yours |
| **the autopilot's** | the autopilot on | what your programs say, read every eighth frame |

Not simulated at all, as today: paused in single player, from the pinch of a
division to the birth, dead, or held in a pond.

---

## 3. Programs and the library

### 3.1 The owner's answer

Row 30 was put as *after a death, does your next cell keep your instincts?* The
owner, 2026-10-02: *"instincts are 'programs'. Players have a library of
programs. They can, if they want, enable many at the same time, as long as they
deal with contradiction between orders in their programs (there could be a kind
of priority order when this happens)"*. So the answer to the row is yes, and
more: what a player keeps is a library.

### 3.2 What they are

| | what it is | limits |
|---|---|---|
| an **instinct** | one rule: one sense, up to one test on each value it carries, one action (behaviour.md §3) | as pack 3's rules (§4.4) |
| a **program** | an ordered set of instincts, with a name and a switch | at most eight instincts, `Drop.MOST_RULES`: one phone screen of rows |
| the **library** | the player's programs, in the player's order | at most eight programs, `LIBRARY_MOST`: one page of rows, as a program is |

**A program's name** is typed by the player, as a world's is, or the default
`automation-ux.md` gives it. It is never translated and never crosses the wire.
**Two programs may hold the same instinct**; nothing forbids it.

### 3.3 Several programs on: the order decides

**The autopilot runs every program that is on, in the library's order, as one
list**: the first program's instincts from the top, then the second's, and so
on. `Rulebook.choose` reads that list exactly as it reads a water cell's: one
winner for each trigger, the first instinct that fits. So:

- **A contradiction is settled by the order.** If the program above says *turn
  toward the echo* and the one below says *turn away from the shadow*, and both
  fire, the cell turns toward the echo; the one below is held back for this tick.
  Different triggers do not contradict: a program that steers and one that
  dashes both act. This is the owner's *"priority order when this happens"*,
  and it is the order a player already reads in one program, carried across
  programs.
- **The player deals with it on the page** (`automation-ux.md`): an instinct
  held back by an instinct above shows which one, and in which program, so a
  contradiction between programs is as visible as one inside a program.
  Reordering the library, or switching a program off, changes the winner at the
  next tick.
- **The merged list is made again** whenever the library's order, a switch, or a
  program that is on changes, as a new list: `rulebook.gd`'s lists are shared and
  never written through, so the list your sister carries is never touched by an
  edit made after she left.

### 3.4 How many run at once

**Eight instincts in all, as every cell** (row 39, answered as recommended). The
programs you switch on share the eight a water cell holds (`Drop.MOST_RULES`):

- **A program that would not fit cannot be switched on**, and an instinct cannot
  be added to a program that is on when the eight are full. The page says why and
  how many places are free. Nothing is ever silently cut off.
- **Small programs side by side is the point.** A program that dodges in two
  instincts, one that hunts in three and one that rests in one fit together; the
  water's seven fit alone.
- **It keeps three things the same for every cell**: what your cell runs is what
  a water cell can run, your sister takes into the water exactly what your cell
  ran (§6.3), and the cost on a phone stays pack 3's (§12).

### 3.5 One library, the player's

The owner's words decide it: *"Players have a library of programs."* **One
library for the whole device**, in a file of its own beside the worlds' index
(§9), shared by all three worlds:

- **It outlives every death.** The next cell runs what is on, from its first tick
  under the autopilot. Instincts for organs it was not born with are asleep until
  a daughter grows them.
- **A new world starts with your library**, and only its water is new.
- **Only your hand writes into it** (row 40). No division changes a program, so
  a program is what you last wrote, the same in every world.
- **The dev app has its own** (`CLAUDE.md`: its own `user://`), and a tool's run
  touches none (§9).

### 3.6 What a new player starts with

**An empty library** (row 28, answered as recommended): no programs, no icon,
and nothing changed: the game is what phase 4-1 left it, to the byte, with
nothing drawing a random number it did not (check 8). The page offers two ways
in (`automation-ux.md`):

- **a new program**, empty, switched on;
- **a copy of the water's seven** (`drop.gd`'s `FOUNDERS`), as a program of
  seven, switched on if it fits (§3.4). It is a copy of the founders only, never
  of what a family evolved, so row 24 stands.

**Pack 4's first design began every list with `always -> body.swim`**, so that a
list never stopped a tail by accident. It is not needed now: a tail beats on its
own unless something holds it, and holding needs level 2 (§5). A new program is
empty, and an empty program does nothing.

### 3.7 Switches, order and edits

- **Each program has its own switch.** The library's order is the priority.
  Reordering programs changes which wins a contradiction; reordering instincts
  inside one changes which wins inside it.
- **Any edit takes effect at the next tick**, and clears what the instincts held,
  as a takeover does (§2.3). An instinct half-built on the page is not in any
  program (`automation-ux.md`).
- **Switching off every program, or emptying the last one on, switches the
  autopilot off**: it has nothing to run, and its icon goes.
- **A program that is off is only kept.** It is not run and not carried by your
  sister.

---

## 4. What an instinct can read and do

### 4.1 Inputs: your own organs, as your membrane gets them

The vocabulary is the water's: the parts the body and the metabolism declare,
and those of every gene in your DNA, worn or only carried (behaviour.md §6.3). An
instinct for a gene you carry and do not wear, or do not wear at the level its
part needs (§4.3), is **asleep**: its input never reports and its output never
fires (`Rulebook.choose`'s `worn` mask) until a daughter of yours has it. Nothing
is offered for a gene your DNA has never had: no magic. An instinct for a gene
you have since lost stays in its program, asleep, until you remove it.

Each input is what that organ already posts to your membrane, taken from the
reading the membrane got that frame. Your instincts read it once a tick; nothing
is sensed again.

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
membrane's frame already sensed. So the report an instinct gets is the same
function for both, and check 9 (§18.3) holds them equal.

**What no instinct of yours can read**, beyond behaviour.md §3.4's list: your
dread and your wake (they read other cells' mouths), your grace, what your full
vision shows (a view, not a sense), motes, and anything about a friend that your
organs do not report.

### 4.2 Outputs: the triggers, on your body

| output | needs | your body | how |
|---|---|---|---|
| `body.turn-toward`, `turn-away`, `turn-random` | -- | holds a heading, set exactly as a water cell's is (`_turn_toward`, led by three times the bearing's drift a tick; `_turn_away`; `_turn_random`'s tumble), and steers onto it | `steer = clamp(angle_difference(heading, held) / HOLD_BAND, -1, 1)`, into `_read_steer()`'s place. Paid at `TURN_COST` a radian, as your hand's turn is |
| `body.swim` | -- | your tail beats, as it does on its own. It claims the tail, so nothing below it may hold it | the stroke clock runs |
| `body.rest` | -- | stops steering, the push and the dash; **and, at tail level 2, holds the tail still**, so you coast to a stop under `DRAG` while the water's wander turns you. At level 1 your tail swims on | `steer` 0; at level 2, the stroke clock held |
| `flagellum.hold` **new** | the flagellum at level 2 | holds the tail still, and only the tail: instincts below may still steer, push and dash | the stroke clock held |
| `myoneme.dash` | `myoneme` | your dash, on its cooldown, at its price | `cell.gd`'s `_dash()` |
| `axoneme.push 0.5` / `1` | `axoneme` | your push, at half or full strength, at that share of its price | `_pushing()` becomes a strength, 0, 0.5 or 1 |
| a trigger nothing claims | | what a body does on its own: no new heading, no push, and the tail beats | |

**`hold` and `rest` differ on purpose.** `rest` is behaviour.md's: stop
everything you can. `hold` stops the tail and leaves the cirrus free, so *always
hold* above *turn toward what the beam touches* is a cell that lies still and
keeps facing what comes, an ambush pack 3's outputs could not say.

**Your body is your body.** A water cell is kinematic: it turns at its cirrus's
rate exactly and swims at a constant pace. Yours keeps its own physics: its turn
has the cirrus's lag, its tail fires impulses with a random kick, and it coasts
under drag. So an instinct means the same in both bodies and each body does it
its own way. A resting player is not carried at the water's 9 µm/s: nothing ever
carried it, and a coast to a stop is its own drift.

**`HOLD_BAND`, the one new piece of steering.** Your cirrus answers a steer with
a lag, and the lag times the rate (`TURN_RESPONSE_BY_TIER` ×
`TURN_RATE_BY_TIER`) is 0.69, 0.68, 0.68 and 0.66 rad at tiers 0 to 3: the same
at every tier. Steering at full rate until the heading is reached would carry
the turn about that far past it, near 39°. Steering in proportion inside a band
of about twice that settles instead. By the arithmetic of the lag, with no wander
and no kick, a band of 1.3 rad (75°) damps the turn at about 0.7, and a 90° turn
at tier 1 overshoots by about 4°, a 180° one by about 6°. Arithmetic, not
measured; check 14 holds that it settles.

**What stays automatic, as for every body** (behaviour.md §3.3): the dart, the
call, the beam and the mouth. The drawn controls show your hand only: the knob
stays home and the pads stay dark while the autopilot steers.

### 4.3 A part that needs a level

`flagellum.hold` is the first part a gene brings at a level rather than at its
first copy. **That is generic, not a special case**: a declaration may say
`"level": n`, and the part is there only while its owner works at level `n` or
more. The rulebook gives each owner-and-level a bit of its own, and `worn`
takes levels where it took copies:

- **for the player**, `genome.gd`'s `level_of(gene)`: the beam's earned level,
  and every other gene's worn copies;
- **for a water cell**, its worn copies, as its beam already uses (`_eye_of`);
- **for a change at division**, the daughter's DNA copies, so `hold` is drawn
  only for a daughter whose DNA carries two copies of the tail (behaviour.md
  §6.3's rule, "rules and genes travel together").

Below its level, a part is offered on the page as asleep and named so (*your
tail holds still at level 2*), and an instinct that uses it waits, as one for an
organ not worn does. A later gene can bring a sense or a trigger at its own
level with no code but its declaration (§13).

### 4.4 Limits

- **At most eight instincts in a program**, and eight in all running (row 39).
- **One test for each value an input carries**, as `rulebook.gd` enforces: up to
  three on an echo (its bearing, distance and size), one on the hunger.
- **A test's value is a rung of its kind's ladder** (`Rulebook.LADDERS`: tenths
  of a level; 1, 2, 3, 5, 8, 13, 21, 34 s; 50 to 1,450 µm; 15° to 150°), or a size
  against your mouth or your body (`REFERENCES`). The player builds in the space
  evolution steps along, so a program of yours and a water cell's list are the
  same kind of thing: once your sister takes yours into the water, her line's
  nudges move its values one rung at a time.
- **A turn needs an input with a bearing**; a push takes 0.5 or 1. An instinct
  that is not whole is in no program. Any instinct the page makes must come back
  the same through its line (`Rulebook.rule_from`, `line_of`).
- **No cost.** An instinct costs nothing to keep or to fire, as the water's rules
  do; what it makes your body do is paid at your body's prices.

---

## 5. The tail

### 5.1 The owner's answer

Row 29 was put as *may your instincts stop your tail?* The owner, 2026-10-02:
*"yes, but then this must be doable by players too. This could be a lvl 2 bonus
of the tail"*. So **holding the tail still is an ability of the tail at level 2**,
and the hand and the instincts have it alike.

It is real. A cilium or a flagellum beats because dynein spends ATP on every
stroke (`energy.md` §1), and a cell can stop it: *Rhodobacter sphaeroides* swims
on one flagellum that stops several times a minute, for up to a few seconds, and
drifts to a new heading while it is still ([Armitage and Macnab, *J.
Bacteriology* 1987](https://journals.asm.org/doi/10.1128/jb.169.2.514-518.1987)).
Making it something a tail earns is the game's: a beat that can be stopped is a
better motor than one that cannot.

### 5.2 What a level-2 tail can do

**`HOLD_LEVEL` 2**, in `cell.gd` beside the flagellum's tables: the one number
both the hand and the instincts ask (`level_of(&"flagellum") >= HOLD_LEVEL`).

- **The hand gets a fourth verb, *hold***: while the hand holds it, the tail does
  not beat. Steering, the push and the dash go on as they are. `controls.md`'s
  rule is that every scheme carries every verb its organs give, so all three
  schemes and the keys carry it; `automation-ux.md` designs the control and its
  key, and whether it is held or toggled. **It is drawn only while the tail is at
  level 2** (`controls.md` §1.1), so a born cell's screen is today's.
- **The instincts get `flagellum.hold`, and `body.rest` holds too** (§4.2).
- **A held tail keeps its clock.** The stroke clock is held, never reset, so when
  the tail beats again two strokes are never closer than its own shortest gap
  (`IMPULSE_GAP_MIN_BY_TIER`). That is what the referee's movement budget
  assumes, "impulses as often as their clock allows" (`referee.gd`), and a list
  that flips between hold and swim every tick cannot beat faster than a tail.
- **A held tail is free**: no stroke, no `STROKE_COST`. A born cell's body with a
  second copy of the tail burns ×1.18 holding it, its upkeep alone, against ×1.88
  with it beating (`energy.md` §2: the flagellum costs 0.70 of rest at tier 2, and
  a tier-2 gene adds 0.18 of upkeep). Arithmetic, not measured.

**What level 2 is** is row 38, answered as recommended: **two copies of the
tail**, which is what `level_of` already answers for every gene but the beam,
and what a water cell's level is. A cell is born wearing them: you eat a cell
whose dominant gene is the tail (`Genome.dominant_of`), the copy is written to
your DNA, and a daughter of yours wears both copies when her expression roll
passes, 0.80 at two copies (`genome.gd`'s `EXPRESS_CHANCE`). The other option,
a tail that earns its levels by swimming as the beam earns them by use
(`cell.gd`'s `LEVELLED`), was set aside; it stays a hook (§14).

### 5.3 Every body that swims (row 37)

**Row 37, answered as recommended**: holding the tail still is a level-2
ability of every cell, the water's included. So **a level-1 tail beats on its
own for every body that swims**. What that does to pack 3:

| pack 3 | under row 37 |
|---|---|
| `_move_ruled`: a body swims at its tail's speed, paying `stroke_cost`, only while a swim rule fires; otherwise it is carried at `DRIFT_SPEED` 9 µm/s for free | **a body's tail beats unless it is held**: it swims at its tail's speed and pays for it, unless a `hold`, or a `rest` at level 2, holds it, or a dart stuns it |
| `body.swim` makes the tail beat | it claims the tail, which beats anyway: it keeps a lower `hold` from holding it |
| `body.rest` stops everything, the tail included | it stops steering, the push and the dash, and the tail only at level 2 |
| -- | `flagellum.hold`, declared by the flagellum at level 2, which mutation draws for daughters whose DNA has two copies |
| the founders' rules | **unchanged, word for word**. Their meaning changes for a cell with a one-copy tail: *fed below 5 s -> rest* and *hunger below 30 % -> rest* now stop its steering and its push, and its tail swims on |
| `_under_power`: swimming by a swim rule, a push or a dash | **its tail beating**, a push or a dash: a resting one-copy hunter swimming at you can be *coming for you*, and your wake and your dart answer it |
| a dart's stun: everything stops for 5 s | unchanged, for every body: a stun is something done to a cell, not an ability it has |
| `drop.bodies.acts`: a held heading, a rest, a swim | and bit 3, a held tail. An optional bit: a pack-3 build ignores it |

**In plain words**: water cells whose tail has one copy can no longer stop
swimming. After a meal they swim straight on instead of drifting, paying for
every stroke, so they get hungry sooner and cover more water. Cells whose tail
has two or three copies rest as they did. By the spawner's own weights
(`TIER_WEIGHTS` lerped toward `BLIND_TIER_WEIGHTS` by how much the player
senses), about four in five of the cells it makes for a newborn (sensing 0.2: 7.0
of 8.4) and about two in three at the 0.6 composition the probes use (5.0 of 7.2)
wear a one-copy tail. Families trade copies at division, so that is where a drop
starts, not where it stays. Arithmetic, not measured.

**What it costs them**: a founder rests from its meal until it is 30 % hungry.
For a born cell's body that rest burned ×1.00 and now burns ×1.50, so it lasts
about two thirds as long: about 7 s of tank where it was about 11. Arithmetic
from `HUNGER_SECONDS` 36; balance waits for players (§15).

**A drifter is still carried.** A body with no mouth decides nothing (behaviour.md
§4, `_step_ruled`) and the water carries it, its tail or not: it is not holding
a tail, it never swims at all. That is pack 1's answer to row 11, which made an
osmotroph at rest take in exactly its upkeep, and it is not undone here. If
drifters swam, each would pay for strokes its income never covers, and by that
arithmetic be empty in 72 to 100 s and dead ten seconds later: the answer row 11
weighed and set aside, whose two-minute trial measured 6.5 drifters a second
dying and ten times the flocs (`ocean.md` §5.3, `--drifters-starve=1`). So row
37's "every cell" is read as **every cell that swims**: the player, and every
water cell with a mouth. The owner confirmed that reading (§17.3).

### 5.4 Pack 3's water, kept as a tool's reference

**One switch**, `food.gd`'s `tails_beat`: true is row 37, and false is pack 3's
water, kept the way `--rules=0` keeps pack 2's hunter (behaviour.md §12). False,
`_move_ruled` is pack 3's, the founders mean what they meant, and the drop is
pack 3's to the byte, which is how check 1 proves the change touched nothing
else. Tools reach it as `--water-tail=pack3`; the game never sets it.

**Why row 37 matters to your programs**: with every swimming body's tail beating
on its own, an instinct means the same thing in your cell and in your sister's.
A program that never mentions the tail swims in both, so nothing has to be added
to a list when it enters the water.

---


### 5.5 As built: phase 4-1, 2026-10-02

Built to §5 and checks 1 to 7, which pass and each fail with their rule taken
out. Content only; `Wire.RULES` stays `46913eab…`. Where the build differs from
the text above, or found something:

- **Check 1** runs a pack-3 five-minute drop of its own, seeded 1
  (`_five_minutes` is now seeded), so `TAIL_LINES` equal what `eco_probe
  --seed=1 --until=300 --sensed=1.0` prints; pack 2's `DEV_LINES` are untouched.
- **Words**: only `rest`, `hold still` and the two hints, in the two-copies
  wording (row 38). Nothing shows them before 4-2's page.
- **The readout's behaviour line** counts a beating tail as swimming; it reads the
  same as before in pack 3's water.
- **A stun** marks a two-copy tail held, as the rest it leaves the body in; it
  stops every tail regardless.
- **Existing checks the new water reached**: check 6's "off" drop runs in pack 3's
  water; the posing helper sets a posed body resting and held; `_one_body`'s and
  `_replay_killer`'s hunters wear two-copy tails; `_flaws` reads a part's level
  bit.
- **`net_probe`**: the pond's mirror check now records the coming-for-you test
  itself, within reach, because a resting one-copy hunter swims on and so comes
  for the guest; the server's hunter stage clears and spares the other guest's
  water. On CI at 4-1: 17,071 frames against 20,000, and `drop_probe` 235 s
  against its 600 s timeout; locally, alone, 16,226 to 16,532 frames and 319 s.
  The frame margin is the one to watch as 4-2 adds sections.
- **The replay's held tail** is 4-2's (§18.1).
- **Seen, and left for 4-2's pause work**: on the pause screen at 1280x720 under
  `pads`, the genome caption's second line runs about 20 px over the dimmed hold
  pad, and at 2400x1080 the French `nombres` button touches its top. `numbers`
  already overlapped push and dash there before 4-1. The pads are inert under
  the scrim; 4-2 rebuilds this screen's bottom edge for the programs page.

## 6. Division

### 6.1 The owner's answer

Row 40 was put as *when a division changes one of your programs and you choose
that daughter, where does the change go?* The owner, 2026-10-02, chose neither
option: *"no mutation to programs made by players. 100% manual."* So **no
division changes your programs. They change by your hand and by nothing else.**

That sets aside, for your programs only, what §17.1 had settled without asking
(*"Not asked, because row 19 decides it"*). Row 19 still holds for everything
else at your division: your DNA changes as it always has, and so do the
instincts of every water cell, your sister's line included (§6.3). It also fits
what the library already was: the player's, not the cell's (§7). Heredity
changes the cell, and it does not reach into what the player wrote.

### 6.2 Your daughters

- **Neither daughter's instincts change.** `_make_daughters` rolls a faithful DNA
  and a changed one, and puts them on sides by a coin, as today
  (`normal_mode.gd`). Nothing about your instincts is drawn, so a division with
  programs on draws exactly what `dev` draws: the same two daughters from the
  same seed (check 18).
- **The daughter you take is your cell going on**, with your library, its
  switches and the autopilot as they were (§2.4). Her body may wear an organ
  yours did not, and an instinct asleep for want of it then wakes (§4.1): a
  change in the body, not in the program.
- **A division left while choosing** comes back as today (`_kept_pair`). It holds
  nothing of your programs, so there is nothing more to keep.

### 6.3 Your sister

In single player and as a host, `put_sister` places her with the instincts her
cell ran:

| what was on | your sister carries |
|---|---|
| nothing | the founders' rules, as every sister did in pack 3 (`Body.brain` null) |
| programs | **one list**: the programs that were on, merged in the library's order, **as they were**. Eight at most (row 39) |

**From then on she is a water cell, and her list is hers.** At her own
divisions her line's instincts change as every water cell's do (row 19,
`Drop.daughter_behaviours` on the changed daughter), and nothing of that comes
back to your library. So the water is the one place your instincts evolve: a
sister whose list hunts well divides, and her line passes it on, changed a
little at every division. In the water a list is a list: the programs'
boundaries and names stay with you. Nothing of this is shown (row 21 stands);
`behaviours` and `unchanged` on the dev readout count her list with the rest.

**A guest's sister** carries the founders' rules until phase 4-3 (§10.3).

### 6.4 The choosing screen

**Nothing new.** Both daughters run the same programs, so there is nothing about
instincts to choose between. The screen shows their DNA and their bodies, as
today, and the choice stays a lean (`choosing.md` §4). The mark that showed a
changed program, in the design before row 40, is gone (§18.4).

---

## 7. A death, and the worlds

**A death keeps the library** (row 30): it is the player's, not the cell's. The
next cell is a new cell at generation 1, with a born body and a born DNA
(`_return`), its tail at one copy, and the autopilot off (§2.4).

**Each world keeps its water and its cell; the library is the same in all
three** (§3.5). A world's file keeps only the cell's new part: the time since
it ate (§9).

---

## 8. What a player must see

Named here; `automation-ux.md` designs how each one looks. A mechanic nobody can
see is not designed.

### 8.1 In play, in both views

1. **The autopilot's icon, and whether it drives** (row 27). The one thing the
   feature adds to the play screen. Its two states differ by shape as well as
   light (`genes-and-cilia.md` §4.4). It is there only while there is something
   to run (§2.2).
2. **Not which instinct acts.** Row 32 answered *"nothing yet. We'll see that
   later."* Nothing in the water names or marks the acting instinct; the page
   and the replay do (§8.2, §8.4).
3. **The hold's control**, from the moment the tail reaches level 2, on every
   scheme (§5.2).
4. **A held tail drawn still.** In point of view your strokes' blooms (`impulsed`,
   the `thrust` sensation) stop, which is already true, and in full vision your
   cell coasts to a stop. But both views draw your flagellum on a clock
   (`cilia.gd`), the soma figure in point of view and the cell in full vision, so
   a held tail is drawn beating. It is drawn still while it is held, by your hand
   or an instinct. **This is not row 32's mark**: it says what your body is doing,
   not which instinct did it, and full vision exists to draw what is there.

**What your instincts do already shows as your hand's does**, and needs nothing
new: a turn shears the membrane (`shear_rate()` reads the steer, whoever set it),
a dash blooms, and a stroke blooms.

**Constraints the two views put on the icon and the hold.** In point of view the
screen's edge is the senses' channel (`perception.md` §3), interface subtracts
light and never emits it, and nothing may look like a sensation: no rings, no
glow at a bearing (`controls.md` §3, §4). In full vision nothing may hide the
water. Both shapes, 1280x720 and 2400x1080, and 48 px for anything touched. The
icon is a control in the water, which the game pays for in the band it covers
(`gene-lines-and-the-pause-target.md` §4); the owner chose to pay it, "since
taking the control back can be a matter of life".

### 8.2 On the page

1. **The library**: every program, its name, its switch, and the order, which is
   the priority. How many of your cell's eight are taken, and by what.
2. **Each program's instincts**, in your organs' words (§13.1).
3. **What the page offers**: only the parts your DNA's genes declare, and the
   body's and the metabolism's. Carried genes are offered, marked as not worn; a
   part that needs a level your organ has not reached is offered marked so.
4. **Each instinct's state on the last tick**: acted; held back, because an
   instinct above took its trigger, **naming the program when it is another
   one**, which is how a contradiction is seen and dealt with; asleep, because its
   organ is not worn or not at its level; quiet, its sense reported nothing; or
   reported, and no report passed its tests. `Rulebook.choose` learns to say this
   for any caller (§13).
5. **What each of your senses reports now**, for setting a test against. Alone
   the water waits while the page is open, so these are the last frame's.
6. **Why a switch or an addition was refused**: the eight are full (§3.4).
7. **The autopilot**, the same switch as the icon.

### 8.3 On the choosing screen

Nothing new: both daughters run the same programs (§6.4).

### 8.4 In the replay

**When the autopilot drove, which instincts acted, and when the tail was held,
through the whole run** (§11), so a death can be read back as "my third instinct
turned me into it". Row 32 keeps it out of the water while you play, not out of
the replay.

### 8.5 What no player sees

The water's cells' rules (row 24 stands) and your sister's line (row 21 stands).

---

## 9. Saves

### 9.1 The library: `user://library.save`

**A file of its own**, because the library is the player's and not a world's
(§3.5). Written as a drop is (`DropSave.write`: to a `.tmp`, read back,
compared, renamed over), so a phone killed mid-write keeps the last good
library.

```
{"version": 1,
 "programs": [                     # in the library's order: the priority
   {"name": "…",                   # as typed; "" while it wears its default
    "lines": PackedStringArray,    # its instincts, in behaviour.md §5.1's text
    "on": bool},
 ...]}
```

- **Written** when the page closes with a change, and only then: no division,
  birth or death writes it (row 40). A few hundred bytes compressed: no hitch in
  a pond.
- **A name this build does not know**, a gene from a later content pack, loads
  as an instinct that never fires and is written back as it came (`rulebook.gd`'s
  inert rule).
- **A file this build cannot read**, under a version it does not know or not
  holding what it says, is moved aside as `library.save.old`, once, as a drop is,
  and the library starts empty. The log says so.
- **A pack-3 build never opens it**, so going back a content version loses no
  program: the first design's list in the world's file did not have that.
- **A tool's run keeps no library**: `normal_mode.gd` takes its path as it takes
  `keep`, and `drive.gd` empties it unless given `--library=`. No render opens on
  a library another run wrote.

### 9.2 The cell's part: in its world's file

One optional key, checked when present: **`FORMAT` stays 1**.

| key | what | when absent |
|---|---|---|
| `cell.fed` | seconds since the cell last ate | never ate |

A division left while choosing is kept as it is today (`daughters`, `_kept_pair`):
nothing of your programs is in it (§6.2).

- **Not kept**: the autopilot's state (§2.4), the heading the instincts held,
  their random turn, their memory and an unfelt hit. A resumed cell comes back
  behind the beat (`ocean.md` §9.3) with your hand on it.
- **The server's room** has none of this: it is nobody's drop. A guest keeps its
  own world's file while it swims in a friend's (`ocean.md` §9.1).
- **The water's own lists** are pack 3's (`drop.behaviours`), your sister's
  among them; and the `acts` column gains bit 3, a held tail (§5.3).

---

## 10. The shared pond and the server

### 10.1 Who runs what

| | host | guest | dedicated server |
|---|---|---|---|
| your programs | run on your device under your autopilot, read your senses in your water | run on your device, read your senses on the mirror (`_step_organs` runs there) | has no cell and no programs |
| your sister | in your water, with your merged list (`put_sister`) | by SISTER: the founders' until 4-3, then her DNA and her list | places each guest's sister; from 4-3 with her list |
| the open menu | nothing pauses; if the autopilot is on, it drives | the same | -- |
| the water's tails | under row 37, the host's water: one-copy hunters swim through their rests | mirrored from the host | its room's water, the same rule |

### 10.2 The referee: nothing it copies moves

The host judges a guest's motion, never how it was asked for. Your instincts and
your hand's new hold ask for nothing a hand could not before:

- **a steer between -1 and +1**, so the turn never passes the cirrus's rate,
  under the referee's 1.35 rad/s;
- **a push of at most full strength**;
- **a dash on the hand's own cooldown**, 1.4 s;
- **strokes never closer than the tail's own shortest gap**, because a hold keeps
  the clock and never resets it (§5.2). A held tail is only slower, and the
  referee bounds speed from above.

`HOLD_LEVEL`, `HOLD_BAND` and the autopilot are not values the referee judges
by, and the water it never judges. **So `Wire.RULES` stays `46913eab…`, and
phases 4-1 and 4-2 need no protocol change**: `net_probe --referee-only` passes
unchanged. Mixed builds play together until 4-3; whose water's tails swim through
their rests is the host's build's, and whose sister carries what is each phone's.

**Repeat the false-positive runs anyway** (`net-hardening.md`): a guest whose hand
holds its tail, or whose autopilot drives, makes motion no guest made before.
Checks 7 and 23.

### 10.3 SISTER carries her DNA and her instincts: phase 4-3, PROTOCOL 6

Row 33, answered as recommended. Today a guest's sister arrives in the host's
water with only her worn body, so she carries the founders' rules and a DNA equal
to her body (`lineage.md` §8). A host's sister carries both, and pack 2 named
this for the next protocol change (`lineage.md` §10).

- **SISTER gains her DNA and her list**: after today's fields, her DNA in the
  same by-name format as her worn tiers (copies 1 to 3), then `u8` count of
  instincts (0 to `Drop.MOST_RULES`), then each as `u8` length (1 to
  `RULE_BYTES_MAX`, 128) and its line in ASCII. Her list is the merged list
  her cell ran (§6.3).
- **The decoder refuses the whole SISTER** on more than eight instincts, a line
  longer than 128 bytes or empty, a byte outside `a-z`, `0-9`, `.`, `-`, `>` and
  the space, a gene name outside the wire's rule (`NAME_MAX`), or trailing bytes:
  the shipped refusal style (`take_sister`).
- **`SISTER_MAX`** grows to `EVENT_HEADER + 13 + 2 × TIERS_MAX + 1 + 8 × (1 +
  RULE_BYTES_MAX)`, 1,336 bytes plus the header. In practice about 0.4 to 1 KB,
  once per guest division, on a reliable channel.
- **The host reads the lines with its own vocabulary**: a name it does not know
  is an instinct that never fires, kept and written back in the room's save.
  Count 0 gives her the founders' rules.
- **The referee judges her place and size as it does today, and nothing more**
  (`judge_sister`). It never judged her worn body, and her DNA and her list are
  the same kind of thing: any list is one evolution could reach, and the page
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

The replay records what moved, and your instincts move nothing that is not
already recorded. What is new is *why*, and that has to be recorded to be drawn
(`replay.md` §4.1). Two state deltas, both dictionaries, so the ring's 322 floats
a frame do not change:

| delta | payload | recorded |
|---|---|---|
| `Delta.PROGRAMS` | the programs that are on, in order: their names and lines | at the start of the window, and at every edit, switch and reorder |
| `Delta.ACTS` | whether the autopilot drives, whether the tail is held, and a mask of the instincts that acted on the last tick, by their place in the merged list | whenever any of them changes: at most 7.5 a second, usually far fewer |

The mask is an `int` of eight bits (row 39). `DAUGHTERS` is unchanged, and a
division changes no program (row 40), so nothing new is recorded at one. The
replay's `what you felt` pane draws the held tail still, and
`automation-ux.md` says how it shows the rest (§8.4). A run with nothing on
records `ACTS` only for the hand's holds.

---

## 12. Cost

Reasoned from the code. **Unmeasured.**

- **The tick.** One `Rulebook.choose` every eighth frame, while the autopilot
  drives. Pack 3 measured about 13 µs for each water decision on this container,
  mostly GDScript call overhead (behaviour.md §9). One more decision is about 1.6
  µs a frame on average here; at `ocean.md` §4.4's assumed factor of six, about 10
  µs a frame on a phone, 80 µs on the frame that ticks. Against pack 3's +3.5 to
  +6.5 ms a frame on a phone, it is lost in the noise.
- **No new sensing.** Your instincts read the reports your membrane's frame
  already took (§4.1). The one addition is keeping your call's returns until they
  ring out: at most five, once a call.
- **Every frame**: one angle difference for the held heading, and the hand's
  presses, which `cell.gd` already reads.
- **The water under row 37**: a one-copy hunter swims where it drifted, which is
  the same step with a different pace and one more `stroke_cost` added. Nothing is
  read or decided more often.
- **Your sister**: one more list among as many as there are hunters (behaviour.md
  §7.1), and eight at most (row 39).
- **The library**: a file of a few hundred bytes, written off the play frame.
- **The replay**: a small dictionary when who drives, the hold or what fired
  changes.
- **The wire, from 4-3**: up to 1.3 KB once per guest division.
- **The page**: `automation-ux.md`'s to cost.

Where it shows: the dev app's frame readout, `dropped` and `water`. Nothing here
is paid per body or per pair of cells but the water's swimming, which is the step
it already pays.

---

## 13. Generic mechanics, names at the edges

| file | knows | does not know |
|---|---|---|
| `game/mechanics/rulebook.gd` | as pack 3, plus three things for any caller: **an optional output of `choose`**, each rule's state on the tick (acted, held back by a claim above, asleep, quiet, reported but failed, unreadable); **a part's level**, `"level": n` in a declaration, an owner-and-level bit, and `worn` taking levels; and **`merged(lists)`**, lists read one after another as one, sharing their rules | a player, a hand, a program, a library, a screen |
| `game/normal/library.gd` **new** | the library: programs with names, lines and switches, in order; `LIBRARY_MOST`; the eight in all; the merged list; the file | how a list is read or changed; a division |
| `game/normal/own_rules.gd` **new** | **the player's wiring**: each declared input to the report of your organ's frame, each output to your body; the tick; the autopilot's handover. The instincts' fields are a `food.gd` `Body`'s (held heading, claims, tumble, memory, hit), run by the water's own triggers, with the dash wired to your cell's | how a list is chosen or changed |
| `game/normal/cell.gd` | `HOLD_LEVEL`, `HOLD_BAND`; the hand's hold; the hand's presses, for taking back; reads the claims for the steer, the tail's clock, the push's strength and the dash; `steering_off` silences the hand only | how a rule wins |
| `game/normal/food.gd` | one report function per input, shared; the pending hit at `hear_contact`'s `BITTEN`; your call's returns kept as a water cell's are; `put_sister` and `place_sister` take a list; `tails_beat` and the held tail in `_move_ruled` and `_under_power` | the page, the hand, the library |
| `game/normal/drop.gd` | `MOST_RULES`, `CHANGES` and `daughter_behaviours`, as pack 3 left them: the water's alone (row 40) | the player |
| `genome.gd`, `cell.gd`, `metabolism.gd` | **the words** for each part they declare, beside `DECLARES` (§13.1); `flagellum.hold` at `HOLD_LEVEL` | the page's layout |
| `game/normal/normal_mode.gd` | the run: the autopilot's state, builds and ticks the merged list, hands it to your sister, keeps the cell's part in the save | rule arithmetic |
| the page, the icon, the hold's control | `automation-ux.md` | rule arithmetic |

### 13.1 Words for the chips

The chips come from the declarations, so **a new gene needs words, not a new
screen** (behaviour.md §3.5, §11). Each declaring file keeps a words table beside
its `DECLARES`, keyed by qualified name (`ocellus.beam`, `body.turn-toward`,
`flagellum.hold`) and by value name, as a `const` of plain strings whose comment
carries `TRANSLATORS:`, which is how `tools/i18n_pot.gd` takes a table of words
into the template. `DECLARES` itself holds plain strings that are not words
(`"in"`, `"name"`), so it must not carry the comment. The rulebook's own words,
`always`, the four tests, `mouth` and `body`, and the units, live with the page.
**Which words is the owner's**: `automation-ux.md` §8 lists them (rows 35 and
42, answered as recommended), the hold's word among them.

Adding a gene with a sense and a trigger is behaviour.md §3.5's three steps plus
two: its words beside its declaration, and its report registered for the player
in `own_rules.gd`. A part it brings at a level is one key in its declaration.

---

## 14. What pack 4 leaves for later

Hooks, not designs.

- **Which instinct acts, in the water** (row 32: *"We'll see that later."*).
  `automation-ux.md`'s first design, a thread from the deciding organ to the
  nucleus, is drawn and waiting; `Delta.ACTS` already carries what it needs.
- **The hand alongside the autopilot**, if a later playtest asks for it: the
  hand claims only the triggers it works, and the instincts keep the rest. Row 36
  set it aside for now; `own_rules.gd` already holds the claims per trigger.
- **A tail that levels by use** (the option row 38 set aside): an entry in
  `LEVELLED` and a rule for what a stroke earns.
- **More at a level**: any gene can bring a sense or a trigger at level 2 or 3,
  as the tail's hold does, with no code but its declaration (§4.3).
- **A rule that holds a list** (behaviour.md §2.1): a tree one level deep. A
  program is already a named list; a program that calls one is the next step.
- **Sharing a program**: with a friend by invite. Lines by declared name are
  already the wire's and the save's form.
- **Your family, shown** (row 21): your sister's line carries your instincts and,
  since row 40, is the one place they evolve. The record (`id`, `parent`,
  `lineage`) is there to mark it, and a list her line evolved could be copied
  into your library by your own hand, which keeps row 40's *"100% manual"*.
- **The water's rules, shown** (row 24): the rulebook's per-rule state serves a
  water cell as well.
- **Every held tail drawn still**, the water's too: a POND entry's speed already
  says when a body is carried at 9 µm/s.
- **Where a gene goes, as a rule**: placement is behaviour (`lineage.md` §3.2),
  and a water cell's layout waits for the wire (behaviour.md §4.4).

---

## 15. Starting values

None of these was measured. Each is where the playtest starts.

| | starting value | why | watch for |
|---|---|---|---|
| `HOLD_LEVEL` | 2 | the owner's *"a lvl 2 bonus of the tail"* | -- |
| `HOLD_BAND` | 1.3 rad, 75° | the cirrus's lag times its rate is 0.66 to 0.69 rad at every tier, and a band of about twice that settles with a few degrees of overshoot (§4.2) | instinct turns that overshoot and swing back (widen), or creep onto the heading (narrow) |
| the tick | every eighth frame, `Drop.LOD_EVERY` | the water's, so a turn's lead, `rising` and `falling` mean the same in both bodies | -- |
| a program | 8 instincts, `Drop.MOST_RULES` | one phone screen, and a water cell's list | wanting a ninth |
| the library | 8 programs, `LIBRARY_MOST` | one page of rows, as a program is | wanting a ninth program |
| running at once | 8 instincts in all (row 39) | a water cell's, so a sister carries exactly what ran | programs you cannot switch on together |
| a test's value | a rung of its ladder | the space the water's changes step along | wanting a value between two rungs |
| `RULE_BYTES_MAX` (4-3) | 128 bytes | the longest instinct today, an echo with three tests driving a push, is about 90 | -- |

**Balance notes, recorded and not acted on.** The hand and the instincts both
hold a level-2 tail, so neither outlives the other by standing still; the first
design's note that automation outlasted the hand is gone. A cell that holds a
two-copy tail burns ×1.18 against ×1.88 beating (§5.2): a daughter born with two
copies who held hers from birth would empty her tank in about 31 s, against about
19 with it beating (arithmetic, from `HUNGER_SECONDS` 36). Under row 37 the
water's one-copy hunters burn more and rest less (§5.3). If players feel the
water thins or the hold is too strong, the levers are `HOLD_LEVEL` and a price
on a held tail. None is pulled: balance waits for players.

---

## 16. Left open

1. **Nothing here was measured**, by the owner's choice: the cost on a phone, how
   the autopilot's handover and the held heading feel, and how dangerous players'
   programs make the water once their sisters' lines spread.
2. **The water under row 37**: one-copy hunters swimming through their rests may
   find more food or starve sooner. The `water` row, `behaviours` and `unchanged`
   on the dev readout, and the census, are where it shows.
3. **A held tail drawn beating**, for the water's resting cells, until a later
   pass draws it still (§14).
4. **What the water does with players' lists**: a server's room, from 4-3, takes
   every guest's sister's list into its families. Whether one player's list takes
   over a room is the playtest's.
5. **A keyboard-only Windows player**: `automation-ux.md`'s. The hold's control
   on `anywhere` is row 41's pad.

---

## 17. Owner's calls

### 17.1 Rows 27 to 37: as they were put, and as they were answered

Numbered on from `behaviour.md`'s row 26, so that one number names one call
across the documents. The screen's calls were in the same table: rows 28, 31,
32 and 35 (`automation-ux.md`). Put to the owner on 2026-10-02, as follows.

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

**Not asked, because row 19 decides it: your division changes one daughter's
instincts**, the one whose genes changed, as the water's do. Row 19: *"every
division. No specific treatment between NPCs and players"*.

**Decided otherwise on 2026-10-02, by the owner's answer to row 40**: no
division changes a player's programs (§6.1). The paragraph above stays as what
was written then. For the player's programs, the owner has now made the call it
said was not needed. Row 19 still holds for the player's DNA and for every water
cell.

**Answered on 2026-10-02.** The owner, verbatim:

> 27 : auto pilot trigger on screen with an icon. Available even outside the menu since taking the control back can be a matter of life.
> 29 : yes, but then this must be doable by players too. This could be a lvl 2 bonus of the tail
> 30: instincts are 'programs'. Players have a library of programs. They can, if they want, enable many at the same time, as long as they deal with contradiction between orders in their programs (there could be a kind of priority order when this happens)
> 32 : nothing yet. We'll see that later.
> Recommended for the rest unless you need precision

So, row by row:

| # | answered | what it changed |
|---|---|---|
| 27 | **an autopilot, switched by an icon on the play screen**, none of the four as put; the nearest was the fourth, moved out of the menu | §2: the autopilot replaces letting go; `HAND_LETS_GO` is gone. What touching does while it drives is row 36 |
| 28 | as recommended | §3.6, in the library's terms: an empty library, a new program or a copy of the water's seven |
| 29 | **yes, and the hand too, as a level-2 bonus of the tail** | §5: the tail beats on its own unless held, and holding needs level 2, for the hand, for the instincts and, by row 37, for every body that swims |
| 30 | **yes, as a library of programs, several on at once, with a priority order** | §3, §6, §9: programs, the library, the merged list, and what a division and your sister do with them |
| 31 | as recommended | the page of the pause screen, beside the genome |
| 32 | **nothing in the water**, the third option | §8: no thread; the page and the replay show what acted |
| 33 | as recommended | §10.3, now phase 4-3 |
| 34 | as recommended | an *instinct* is one line; *program*, *library* and *autopilot* are the owner's words |
| 35 | as recommended | `automation-ux.md`'s set (§8 there now), with a word for the hold |

**Rows 36 and 37**, which these answers raised, were put the same day.
**Answered on 2026-10-02**, verbatim: *"36 and 37 as recommended"*.

| # | answered | what it changed |
|---|---|---|
| 36 | **touching the steering controls while the autopilot drives takes the cell back at once and switches the autopilot off** | §2.3: a new press of any control the hand drives the cell with, on every scheme; the autopilot stays off until the icon or the key |
| 37 | **holding the tail still is a level-2 tail ability for every cell, the water's included** | §5.3: every swimming body's level-1 tail beats on its own, and the water's one-copy hunters swim through their rests; pack 3's water stays a tool's reference behind `tails_beat` (§5.4) |

### 17.2 Rows 38 to 42: as they were put, and as they were answered

Opened by the answers to rows 27 to 37, and put to the owner on 2026-10-02, as
follows. Rows 41 and 42 are the screen's.

| # | Question | Options | What it means |
|---|---|---|---|
| 38 | What makes a tail "level 2", so it can be held still? | **its second copy: a cell born wearing two copies of the tail can hold it ✓ recommended** · a level the tail earns by swimming, as the beam earns its levels by use | Second copy: you eat a cell made mostly of tail, and a daughter born with two copies can hold hers still; the water's cells follow the same rule, since their copies are their levels. Earned: your tail learns to stop after enough swimming, within one life, as your beam grows its rays; it needs a new way for the tail to gain experience, and the water's cells, which earn nothing, would still go by their copies. |
| 39 | How many instincts can your cell run at once? | **eight in all, like every cell: the programs you switch on share them ✓ recommended** · eight in each program, for as many programs as you switch on | Eight in all: you choose which programs fit together, small ones side by side, and a program that would not fit waits until you make room; your sister takes exactly what your cell ran into the water. Eight each: switch on as many as you like, so your cell can run far more than a water cell, and your sister takes only the first eight, the ones your order puts on top. |
| 40 | When a division changes one of your programs and you choose that daughter, where does the change go? | **into the program itself, which keeps its old version for one undo ✓ recommended** · into a copy of the program, added to your library beside it | Into the program: the program you run is the one your daughter carries, as for every cell, in all your worlds; you see the change before you choose, and one tap puts the old version back. Into a copy: your programs stay exactly as you wrote them and each change you keep becomes a new program beside the old one, so your library fills with variants. |
| 41 | How does a player on the default controls hold the tail still? | **a pad, drawn only once the tail reaches level 2, where the pads scheme puts it ✓ recommended** · a second finger held anywhere on the water · no way by hand: keys and the autopilot only | A pad: the default controls stay empty until your tail reaches level 2, then gain one button. A second finger keeps the screen empty, but it is a gesture nobody can see. No way by hand breaks *"this must be doable by players too"* for phone players on the default controls. |
| 42 | Which new words does the game use? | **as listed in `automation-ux.md` §7: programs, autopilot, a water cell's program, program 2, steering · tail · dash · push, hold still, and the French ✓ recommended** · other words, one by one | These are what the page, the autopilot's explanation, the automatic names and the new action say. Any one can change without touching the others. |

**Under the table.**

- **38.** "Level" is the beam's word for what use earns, and every other gene's
  level is its copies (`genome.gd`'s `level_of`). The recommendation needs no new
  system and gives the water and the player one rule. Either way the hold is
  asked through `level_of`, so the other answer is an entry in `LEVELLED` and a
  rule for what a stroke earns.
- **39.** The owner's *"many at the same time"* is kept either way; the call is
  whether *many* shares a cell's eight. The recommendation keeps "all cells
  follow the same rules" and makes a sister's inheritance exact.
- **40** is where row 19 meets the library. Into the program is what a cell
  carrying its instincts means; a copy protects what the player wrote, at the
  price of a library of variants.
- **41 and 42** are the screen's (`automation-ux.md` §12, where the pad's place
  is argued).

**Answered on 2026-10-02.** The owner, verbatim:

> 40 : no mutation to programs made by players. 100% manual.
> Rest as recommended

So, row by row:

| # | answered | what it changed |
|---|---|---|
| 38 | as recommended: **the tail's second copy** | nothing: §5.2 was written to it, and phase 4-1 builds it |
| 39 | as recommended: **eight in all** | §3.4 and §11: what the other option would have needed goes; the replay's mask is eight bits |
| 40 | **neither option: no division changes a player's programs, which change only by the player's hand** | §6: both daughters run your programs as they are, and your sister carries the merged list unchanged, a water cell from then on. The undo, the choosing screen's mark, `before` and `cell.daughters[k].change` go, and so does the phase that built them: the wire is phase 4-3 (§18.2). It overrides, for the player's programs, §17.1's *"not asked, because row 19 decides it"* |
| 41 | as recommended: **a pad, drawn once the tail reaches level 2** | nothing here: `automation-ux.md` §12, and phase 4-1 already builds it |
| 42 | as recommended: **the words `automation-ux.md` lists** (§8 there; the row as put says §7) | the set stands. The two that named a division's change, *changed at your last division* and *undo the change*, have nothing left to name (`automation-ux.md`'s to drop) |

The two readings of §17.3 were confirmed with these answers.

### 17.3 How the answers are read

Two answered rows were read here in one particular way, and **the owner
confirmed both on 2026-10-02**, with the answers to rows 38 to 42:

- **Row 36, "the steering controls"**: every control the hand drives the cell
  with, steering, the push, the dash and the hold (§2.3), because under
  `anywhere` one finger is all of them.
- **Row 37, "every cell"**: every cell that swims. Drifters, which have no mouth
  and decide nothing, stay carried: if they swam they would starve, which is the
  answer row 11 set aside (§5.3).

Row 29's *"lvl 2"* is row 38's second copy.

**Row 40, "programs made by players"**, is read as the programs in the player's
library, and this document takes that reading as its position. Your sister's
list leaves them when she does: from her birth it is a water cell's, and her
line's divisions change it under row 19 (§6.3), while nothing changes the
programs you keep. Read the other way, as every list a player ever wrote, her
line would be the one family in the water whose instincts never change.

**Settled here, not asked**, because the owner's words or an answered row decide
them: one library for all worlds (*"Players have a library"*); the order between
programs is the player's, and your sister carries them merged in that order; the
autopilot is off at every new cell, kept through a division and not saved; its
icon is there only while there is something to run (`controls.md` §1.1); your
instincts read only your organs ("No magic info"); a test's value is a ladder's
rung; your instincts never choose a daughter (no sense reports one); a stun stops
every tail; a resting player coasts under its own drag; and `Wire.RULES` does not
move (the referee judges motion, and nothing here makes any a hand could not).

---

## 18. Build plan

### 18.1 Files

| file | change | phase |
|---|---|---|
| `game/mechanics/rulebook.gd` | a part's `"level"`: owner-and-level bits, `worn` taking levels, `_inputs_for` and `_outputs_for` held to them (§4.3) | 4-1 |
| `game/normal/cell.gd` | `HOLD_LEVEL`; the hand's hold, read under every scheme and its key; the stroke clock held while the tail is held; the words for the body's parts | 4-1 |
| `game/normal/genome.gd` | `flagellum.hold` in `DECLARES`, at `HOLD_LEVEL`; the words tables (§13.1) | 4-1 |
| `game/normal/food.gd` | `tails_beat`; `_move_ruled` and `_under_power` with the held tail, a drifter still carried; `_rest_on` and a `_hold_on` trigger; `Body.tail_level` made with the body; the `acts` column's bit 3 | 4-1 |
| `game/normal/controls.gd`, the hold's control | `automation-ux.md`'s; drawn at level 2 only | 4-1 |
| `game/vision/cilia.gd`, `soma.gd`, `vision.gd` | the player's held tail drawn still, in both views | 4-1 |
| `tools/drive.gd`, `tools/eco_probe.gd` | `--hold=` posing the hand's hold; `--water-tail=pack3` (`tails_beat` false) | 4-1 |
| `game/mechanics/rulebook.gd` | `choose` fills an optional per-rule state array; `merged(lists)` (§13) | 4-2 |
| `game/normal/library.gd` | **new** (§13) | 4-2 |
| `game/normal/own_rules.gd` | **new** (§13) | 4-2 |
| `game/normal/cell.gd` | `HOLD_BAND`; `_read_steer()` takes the held heading while the autopilot drives; `_pushing()` becomes a strength; a dash the instincts fire bypasses `steering_off`, which silences the hand only; a new press of the hand's controls, read for taking back; the onboarding reads the hand's steer, not the instincts' | 4-2 |
| `game/normal/food.gd` | each `_read_X` split into sensing and a shared report; your call's returns kept until they ring out; the pending hit at `hear_contact`'s `BITTEN`; `put_sister` and `place_sister` take a list | 4-2 |
| `game/normal/genome.gd`, `cell.gd`, `metabolism.gd` | the rest of the words tables (§13.1) | 4-2 |
| `game/normal/normal_mode.gd` | the autopilot's state, its icon and key; builds and ticks the merged list; the meal clock for `fed`; your sister's list; `cell.fed`; the library's path, emptied by tools | 4-2 |
| the page, the library on it, the icon | `automation-ux.md`'s files | 4-2 |
| `game/normal/drop_save.gd` | `cell.fed`, checked when present | 4-2 |
| `game/replay/recorder.gd`, `replay.gd`, `panes.gd` | `Delta.PROGRAMS` and `Delta.ACTS`, and the held tail drawn from them | 4-2 |
| `game/net/wire.gd`, `pond.gd` | SISTER with her DNA and her list; `RULE_BYTES_MAX`; `PROTOCOL := 6` with a paragraph in the style of 4 and 5; the host places her with both | 4-3 |
| `game/i18n/biogenic.pot`, the French catalog | every new word, through `tr()` | each |
| `tools/drive.gd` | `--program=<lines, ;-separated>` (repeatable, in order), `--program=founders`, `--program-off=<n>`, `--autopilot` or `--autopilot-at=<s>`, `--library=`; with any of them, who drives, the hold and what acted on lines of their own, so a run without them traces as `dev` does. `forage_probe` wraps `drive.tscn` and takes them unchanged | 4-2 |
| `.github/workflows/ci.yml` | one step beside "Check the input path": check 8's three seeded runs against the pinned hash. Repository furniture, in neither the pack nor the binary | 4-2 |
| `tools/drop_probe.gd` | the checks of §18.3 | each |
| `tools/net_probe.gd`, `tools/net_fuzz.gd` | checks 7, 23 and 24 to 27; the fuzz corpus gains SISTER frames | 4-1, 4-2, 4-3 |

**Nothing** changes in `addons/launcher/` or `ci/`. **No new input action is
needed**: the autopilot's key and the hold's key are polled as `cell.gd` polls
Space. If one ever needs an action in `project.godot`, that is a `binary_version`
bump, and no reason to avoid it (`CLAUDE.md`). **`binary_version` does not
move.** Every phase is GDScript, scenes and translations: a content pack.
`Wire.RULES` stays `46913eab…`.

**What row 40 took out of the build**: `drop.gd`, `_make_daughters` and
`_kept_pair` do not change. `daughter_behaviours` needs no `most`: no change is
ever drawn for a player's program, and your sister's list is at most eight (row
39), which is what the water's call already assumes when her line divides. The
library's `before`, the undo, the choosing screen's mark and
`cell.daughters[k].change` are not built.

### 18.2 Phases

Each phase is one pull request into `dev`, played on the dev app before the next
starts. The tail comes first. **Revised 2026-10-02, after row 40**: the phase in
which your division changed your programs is gone, and the wire, which was 4-4,
is 4-3. Phase 4-1 is as it was.

| phase | contents | what the owner can try |
|---|---|---|
| **4-1** | the tail: `HOLD_LEVEL`, the hand's hold, `flagellum.hold`, `rest` at level 2, the water's tails under row 37 with pack 3's kept behind `tails_beat`, the held tail drawn still; checks 1 to 7 | grow a two-copy tail and hold it; watch the water's one-copy hunters swim on after their meals |
| **4-2** | programs and the autopilot: the library, the page, the icon and its key, the merged list and its order, the save, the replay, a division that leaves your programs as they are, your sister carrying your list (single player and host); checks 8 to 23 | write programs, switch them on, tap the icon and watch; take back; divide on the autopilot and go on; die and come back with your library; relaunch; switch worlds |
| **4-3** | a friend's sister carries their DNA and instincts: SISTER, `PROTOCOL` 6; checks 24 to 27 | divide in a friend's water, and in the server's room |
| the release | | whenever the owner runs it |

**Why the tail comes first.** It is the one change to the water, it needs no
page, and it makes a program mean the same in your cell and in your sister's
before any sister carries one.

### 18.3 What the build checks

In `drop_probe`'s "Check the drop" step unless a check names another place,
each of which must fail with its rule taken out.

**Phase 4-1, the tail:**

1. **Pack 3, to the byte, with the switch off.** With `tails_beat` false and no
   hand holding, the five-minute drops print `dev`'s census, lineage and
   behaviour lines (`DEV_LINES`, and behaviour.md's check 1), and the player's
   seeded trace is `dev`'s. With it on, the build pins the new lines.
2. **A level-1 tail cannot be held**: no hold control is drawn and its key does
   nothing; `flagellum.hold` is asleep; `body.rest` stops steering, the push and
   the dash while strokes keep firing.
3. **A level-2 tail holds**, by the hand, by `flagellum.hold` and by `body.rest`:
   no stroke fires and a born-like cell burns its upkeep alone; under `hold`
   alone the cirrus still turns; through any sequence of holds and beats, no two
   strokes are closer than the tier's shortest gap.
4. **The water's tails** (`tails_beat` on): a posed hunter with a one-copy tail
   under the founders swims and pays through its rests; one with two copies
   drifts free, as in pack 3; a drifter is carried and pays nothing; a stunned
   body of any tail stops.
5. **Coming for you**: a resting one-copy hunter swimming at you is coming for
   you, and your wake and your dart answer it; a two-copy hunter holding still is
   not.
6. **A level is generic**: a probe gene declaring a part at level 3 is offered
   and fires only at three copies, is asleep below, and is drawn by a change
   only for a daughter whose DNA carries three, with no change to `rulebook.gd`.
7. **`net_probe`: never cut for a hold.** The referee section passes with
   `Wire.RULES` `46913eab…`; the `pond` and `server` sections, which end by
   checking that no referee fouled an honest guest (`net-hardening.md` B.3), run
   again with that guest holding and releasing a two-copy tail, and still end
   with no foul.

**Phase 4-2, programs and the autopilot:**

8. **An empty library, no change.** With no programs, a seeded `drive.gd` run
   (seed 1, 60 s, `--trace=0.5`, under each scheme) prints the trace 4-1 left,
   to the byte; no icon is drawn and the autopilot's key does nothing. The build
   pins the trace's hash, as `DEV_LINES` pins pack 2's lines; a step in
   `.github/workflows/ci.yml`, beside "Check the input path", runs the three and
   compares. "Check the input path" itself passes unchanged.
9. **You read what a water cell reads.** Pose the player and a water cell alike
   (place, heading, size, genome, arcs): every input's report for your instincts
   equals the water cell's reader's, to the float.
10. **No magic.** An input of a gene you do not wear never reports; a mote and
    your own bite are never a `hit`; nothing in the vocabulary reads dread or the
    wake.
11. **The autopilot.** It engages only by the icon or its key, and lets go of
    what the hand held; a new press of a steer, a push, a dash or a hold, under
    each scheme and on the keys, switches it off on that frame (row 36); a key
    held through the switch, or a finger left down, takes nothing back until
    pressed again; a press on open water under `stick` and `pads` takes nothing
    back; a death switches it off and a division keeps it; the pond's open menu
    does not engage it; switching off the last program on switches it off.
12. **The order decides.** Two programs on whose instincts claim the same trigger
    in the same tick: the upper program's acts and the lower one's is held back,
    naming it; reordering them changes the winner at the next tick; a program off
    is never read.
13. **Eight in all** (row 39): switching on a program that would take your cell
    past eight is refused; adding an instinct to a program on, at eight, is
    refused; nothing past eight ever runs.
14. **The held heading settles.** At cirrus tiers 0 to 3, a held heading 90° and
    180° away is reached and held, overshooting by less than 15°, and the turn is
    paid at `TURN_COST` a radian as the hand's is.
15. **Push and dash.** `axoneme.push 0.5` gives half the hand's thrust at half its
    price; `myoneme.dash` dashes on the hand's cooldown and price; neither acts
    without its organ.
16. **Edits.** An edit, a switch or a reorder acts at the next tick and clears
    what the instincts held; a program the page builds survives its lines; no
    value off a ladder is offered.
17. **The library's file.** It round-trips exactly; an unknown name loads as an
    instinct that never fires and is written back as it came; a file this build
    cannot read is moved aside once and the library starts empty; the same
    library opens in every world and after every death; a tool's run writes none.
18. **A division, and your sister** (row 40). Posed at one seed, a division with
    programs on and one with none roll the same two daughters, and leave the
    global stream at the same place: nothing is drawn for your instincts. The
    daughter you take runs the same merged list, and the library and its file
    are untouched. Your sister carries the merged list as it was (host and single
    player), and the founders' when nothing was on.
19. **Determinism.** One seed with the autopilot on, run twice, prints the same
    trace.
20. **Modular.** The probe's test gene (behaviour.md check 8), with its player
    report registered by the probe, is offered to a player who carries it, read
    and acted on by an instinct, and kept by name, with no change to the page,
    `rulebook.gd`, `library.gd` or the save code.
21. **Alive**, run by the build and not in CI (twelve simulated minutes).
    `forage_probe` with `--program=founders --autopilot` and a genome that wears
    every organ the founders read, seeds 1 to 4, three minutes: every founder
    instinct acts at least once, and the cell eats at least once across the four.
    This checks that the wiring is alive, not how well it forages.
22. **The replay.** A run with programs records them and every change of who
    drives, the hold and what acted; a run without records only the hand's holds.
23. **`net_probe`: never cut for the autopilot**: the `pond` and `server`
    sections again with the honest guest on the autopilot, its programs resting,
    holding, swimming, pushing at half and full, dashing, and flipping hold and
    swim every tick, and still no foul.

**Phase 4-3, in `net_probe`:**

24. **SISTER carries her DNA and her list**: a guest's declined daughter arrives
    in the host's water with both; with count 0, the founders'.
25. **Refusals**: nine instincts, a line of 129 bytes, an empty line, a byte
    outside the alphabet, or trailing bytes, and the SISTER is refused whole.
26. **The handshake**: protocols 1 to 5 refused by name; the referee section
    unchanged.
27. **The server's room** keeps a guest's sister's list through a save and a
    load.

### 18.4 What it replaces

| pack 3, and pack 4's earlier designs | now |
|---|---|
| `_read_steer()` reads the hand alone | the hand, or the held heading while the autopilot drives |
| the first design: letting go hands the cell to your rules, `HAND_LETS_GO` 0.5 s | the autopilot, switched by an icon or a key; a new press of the hand takes back |
| `_pushing()`, yes or no | a strength: the hand's full, or an instinct's half or full |
| the player's tail always beats; a water cell's beats only while a swim rule fires | every swimming body's tail beats unless held, and a tail at level 2 can be held, by the hand or an instinct |
| `body.swim`, `body.rest` | `swim` keeps the tail beating; `rest` holds it only at level 2; `flagellum.hold`, new, at level 2 |
| the first design: one list, in the world's file | a library of programs, `user://library.save`, for every world and every life |
| your sister carries the founders' rules | she carries what her cell ran; the founders' when nothing was on |
| the design before row 40: your division changes one of your programs, with one undo | no division changes your programs; only your hand does, and the choosing screen is today's |
| a guest's sister carries her worn body (`PROTOCOL` 5) | her body, her DNA and her list (`PROTOCOL` 6, phase 4-3) |
| the replay records what moved | what moved, when the autopilot drove, the held tail, and which instinct acted |

---

## 19. What to watch in the playtest

**In phase 4-1, the tail**: whether holding a two-copy tail feels like a power
worth eating for, on each scheme and on the keys; whether a held tail reads as
resting and not as broken, in both views; and the water: whether one-copy
hunters swimming on after their meals make the drop feel busier, hungrier or
emptier, on the census and the `water` row.

**In phase 4-2, programs and the autopilot**: whether the icon is where your
thumb can find it when it matters, and whether you can tell at a glance that the
autopilot drives; whether taking the cell back by touching feels like rescue or
like an accident, which is row 36's playtest; whether you build small programs
and switch them on together, or one big one, and whether the eight in all feel
tight; whether a contradiction between programs is easy to see and settle on the
page; how your instincts' turns feel, overshooting or creeping; and whether
keeping a cell alive on the autopilot is possible, and fun.

**On a phone**: the frame readout's `dropped` row with the autopilot on, against
it off.

**Across lives, launches and worlds**: your library there after a death, after a
relaunch, and the same in each world.

**At your divisions**: whether going on under the autopilot through a division
feels seamless, and whether choosing a daughter by her body alone still reads as
a real choice when both run the same programs (row 40).

**In a pond**: the autopilot driving while the menu is open; a friend on the
autopilot moving smoothly on your screen; and, after 4-3, whether a friend's
daughters behave like them.

**Over days, in the server's room (after 4-3)**: whether players' lists spread
through the water and change in their sisters' lines, and whether one takes it
over.
