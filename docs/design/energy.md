# Energy: what moving costs

The owner, 2026-09-29:

> We should reduce the amount of time needed to starve. But not necessarily by
> reducing the storage. It can be by adding consumption. For exemple, each swim
> should consume energy. turning should also consume energy. We should see
> details of the stats in the gene description. Energy consumption, range when
> applicable, etc. Everything must be explained to players for those who wants
> to master the game, but not impose and overwhelm players willing to learn by
> playing, without numbers.
>
> That being said, focus on the energy consumption. We will deal with gene
> stats later

This document is the energy half. The gene descriptions are the next piece of
work; §5 is what it can start from.

The owner, later the same day, answering §6:

> Recommended for all.
> Adapt so we starve after 30 seconds with spawn gear

§6 records the first line and §7 is the second. **Since §7 the pace is thirty
seconds, not seven minutes.** Every cost here is still what it was in seconds
of rest, which is a bigger share of a smaller tank; where a time below runs to
minutes, it is the pace before §7.

## 1. The decision

**The tank stays and the spending grows.** `metabolism.gd`'s `HUNGER_SECONDS`
stayed 420 here: seven minutes from fed to starved, but now only for a body at
rest, which no living cell is. (§7 then made it 36.) On top of being alive (`upkeep`, genes-and-cilia.md
§3.2), a body now pays for what it does:

- **every stroke** — the flagellum's own beat, on its own schedule, and a held
  push, frame by frame — in proportion to the speed it adds;
- **every turn** the cirrus makes, in proportion to the angle.

It is realism doing the work, as CLAUDE.md asks. A cilium or a flagellum beats
because dynein motors spend ATP on every stroke, so swimming is paid by the
stroke; the mitochondrion is where that ATP is made, which is `crista`; and a
vacuole is a store. Nothing had to be invented, only priced.

### 1.1 One unit: seconds of rest

Every cost is in **seconds of rest**: how long a resting born cell (upkeep 1)
takes to burn as much. It is the unit the rest of the economy already thinks
in — genes-and-cilia.md §3.2 prices a meal as *seconds of life it buys* — and it
is the one a gene description can say in words later: "each beat costs about a
second of life".

`metabolism.gd`'s `spend(rest_seconds)` turns it into hunger, exactly as the
resting rate does:

```gdscript
set_hunger(hunger + rest_seconds * burn / (HUNGER_SECONDS * reserve))
```

So `crista` (burn) makes moving cheaper as it makes being alive cheaper, and
`vacuole` (store) makes every cost a smaller share of a bigger tank. Neither
gene's line on the pause screen became untrue: *"burns cleaner, so everything
you carry costs less"* and *"a bigger tank, so hunger takes longer to reach
you"*.

### 1.2 Priced on what the body does

The costs are on the speed a stroke adds and the angle the body turns, not on
the button. So:

- **A better flagellum costs more to run and the same per unit of speed.** It
  beats harder and more often; it also carries you twice as far.
- **A better cirrus turns faster for the same price per degree.** A half turn
  costs the same at every tier; a better cirrus just finishes it sooner.
- **The water's own drift is free.** The heading's wander and an impulse's kick
  are not the cirrus working, and cost nothing.
- **A push is a push, however it was asked for.** With `axoneme`, a finger down
  under `anywhere` and a thumb on the stick under `stick` push — they always
  did (controls.md §1) — so they pay for it too. Steering by touch with an
  `axoneme` costs more than on the keyboard or under `pads`, which is the scheme
  that turns without swimming. §3 measures it and §6 row 3 asks whether it
  should.

### 1.3 What did not move

- **The dash** keeps `DASH_COST_BY_TIER`, its price since Phase 5: 6, 4.5 and
  3.2 % of the bar, about 25, 19 and 13 s of rest at the seven-minute pace
  (2.2, 1.6 and 1.2 s at §7's). It is not also charged as a stroke. It stays a
  share of the bar that store and burn do not soften, which is older than this
  and is for the gene-stats work to make consistent.

  > **Made consistent, 2026-09-29** (`gene-stats.md` §11, call 2: the
  > recommended option, which the owner chose the same day). A dash, and
  > being spat out by venom, are paid as the seconds of rest their share of a
  > born cell's tank comes to, through `spend`, like every other cost: `crista`
  > makes them cheaper and a bigger `vacuole` tank makes them a smaller share of
  > it. A born cell pays exactly what it did. Neither table moved, and nothing
  > crosses the wire.
- **The grace** is time. Spending stops at full hunger and never shortens it
  (forty seconds here, ten since §7), because swimming for food at the end is
  exactly what the grace is for.
- **The water.** The other cells do not starve and pay nothing.
- **The wire.** Hunger is each player's own; the host's referee never judges
  when a guest starves (`referee.gd`'s `judge_died`: starving is the guest's own
  to say). No `Wire.PROTOCOL` or `Wire.RULES` change, and net_probe's fingerprint
  check passes.
- **The binary.** GDScript only: a content pack.

## 2. The numbers

Two constants in `cell.gd`, beside the drive they price:

```gdscript
const STROKE_COST := 0.0113  # seconds of rest per unit of speed a stroke adds
const TURN_COST := 1.3       # seconds of rest per radian the cirrus turns
```

`STROKE_COST` is set so a tier-1 flagellum, beating on its own, burns half
again what a resting body does: a stroke adds `138 × 0.85 = 117` u/s on average
every `(1.70 + 3.60) / 2 = 2.65` s, and `0.5 / (117 / 2.65) = 0.0113`. `TURN_COST`
is set so turning flat out at tier 1 (0.62 rad/s) burns 0.8 of a resting body
on top: `0.8 / 0.62 = 1.3`.

**What each organ costs, as a multiple of a resting body** — the table the gene
descriptions can start from:

| organ | when | tier 1 | tier 2 | tier 3 |
| --- | --- | --- | --- | --- |
| `flagellum` | always: it beats on its own | 0.50 | 0.70 | 0.99 |
| `cirrus` | while turning flat out | 0.81 | 1.04 | 1.33 |
| `axoneme` | while pushing | 0.68 | 0.96 | 1.30 |
| `myoneme` | per dash: a share of the bar, not of rest | 6 % (2.2 s) | 4.5 % (1.6 s) | 3.2 % (1.2 s) |

Per use: a tier-1 beat costs **1.3 s** of rest (1.8 s at tier 3); a half turn
costs **4.1 s** and a full circle **8.2 s** at every tier. The dash's seconds are
at §7's pace; at the seven-minute pace they were 25, 19 and 13.

> **Of rest, since 2026-09-29**: the dash's row is paid in those seconds through
> `spend`, so `crista` and `vacuole` soften it like the rows above (§1.3's note).

A body that has lost its flagellum (tier 0, which genes-and-cilia.md §9.7
allows) beats on the tier-0 ladder and pays 0.36.

## 3. Measured

> **At the seven-minute pace.** The burns (×) hold at any pace, since every
> cost is in seconds of rest; the times to die at thirty seconds are §7.2's.

`--fixed-fps 60`, seed 3, a born cell (`cytostome 1, cirrus 1, flagellum 1`,
plus `stigma 1` so the free sense at five seconds does not change the genome
mid-run), 120 s of the water, `dev` against this change. The burn is every rise
in hunger added up, so a meal on the way does not hide what was spent, over the
seconds the body was actually simulated. **Dies at** is fed to the end of the
grace, never eating.

| play | burn before | dies at, before | burn after | dies at, after |
| --- | --- | --- | --- | --- |
| drifting, no input | ×1.00 | 7:40 | ×1.50 | **5:19** |
| steering a third of the time (2 s in every 6) | ×1.00 | 7:40 | ×1.78 | **4:36** |
| turning all the time | ×1.00 | 7:40 | ×2.31 | **3:41** |
| pushing all the time (`axoneme 1`) | ×1.00 | 7:40 | ×2.18 | **3:52** |
| pushing and turning, flat out | ×1.00 | 7:40 | ×2.97 | **3:01** |
| `flagellum 3`, drifting | ×1.36 | 5:49 | ×2.32 | **3:41** |
| `crista 2`, drifting | ×0.91 | 8:22 | ×1.30 | **6:04** |
| `vacuole 2`, drifting | ×0.74 | 10:09 | ×1.05 | **7:19** |
| `axoneme 1`, steering flat out by touch (`anywhere`) | ×1.00 | 7:40 | ×3.00 | **3:00** |
| `axoneme 1`, a thumb resting on the glass (`anywhere`) | ×1.00 | 7:40 | ×2.17 | **3:53** |
| `axoneme 1`, steering flat out on the keyboard | ×1.00 | 7:40 | ×2.28 | **3:43** |

The last three rows are 40 s, before any meal: under `anywhere` a finger down is
also a push (§1.2).

Seeds 1 and 2 give ×1.48 and ×1.53 drifting and ×2.29–2.30 turning: the spread is
the stroke's random strength. Every row matches the arithmetic of §2 to within
it — the `crista` row is `(1.18 + 0.5) × 0.77`, the `vacuole` row
`(1.18 + 0.5) / 1.6`, since tier 2 of either adds its own 0.18 of upkeep.

**To measure again** when a cost moves, with the committed harness: `tools/
drive.tscn` under `--fixed-fps 60`, with `-- --seed=3 --mode=0 --genome=cytostome:1,
cirrus:1,flagellum:1,stigma:1 --trace=10`, and `--hold=d` to turn, reading the
trace's `hunger` before the first `[meal]` line.

**What a meal buys** (half a bar, genes-and-cilia.md §3.2's unit), for a born
cell: 210 s before at any pace; now 140 s drifting, 118 s steering a third of the
time and 91 s turning all the time. (Since §7 a meal your size is the whole bar:
24, 20 and 16 s.)

The fast swimmer ate four drifters in its first 82 s without being steered: it
burns more and finds more. Twice the speed for about 1.5 times the burn, so it
still covers more water per meal than a born cell.

**A forager that follows its nose still feeds itself.** The harness's `--sniff`
bot (`cytostome 1, cirrus 1, flagellum 1, chemocyte 1`), which turns all the
time, ran five minutes on seeds 1 to 4. Its path is the same as before —
hunger does not steer anything — so it ate the same 2 to 5 meals and was eaten
by the same hunters at the same moments on three seeds. It never starved. It
ran hungrier: burn ×2.0 to ×2.2, and on the seed it survived, hunger 0.58 at
five minutes against 0.26.

## 4. How it reads, without a number

Nothing new is drawn and nothing new is said. The beat is the hunger readout
(perception.md §6.2), and moving now makes it slow sooner. A born cell steering
a third of the time is at hunger 0.51 after two minutes: its beat has gone from
2.4 s to 3.6 s and to two thirds of its strength, where before it had reached
3.1 s and 0.81. (At §7's pace that is ten seconds in; §7.5.) A player learning by playing finds out that swimming around
wears them out, and that turning less and pushing less saves it — never all of
it, because the tail beats on its own, and for a newborn that is two thirds of
what moving costs. A player who wants to master it gets the numbers in §2 when
the gene descriptions carry them.

## 5. For the gene descriptions (the next piece of work)

The owner wants the numbers there for players who want them, and nowhere they
would be imposed on players who do not. This change keeps that door open rather
than walking through it:

- every cost is one constant per organ, in a unit that reads as time;
- §2's table is what each organ costs, by tier, in that unit;
- the pause screen's `EXPLAINS` lines are untouched, and still true;
- `plastid`'s sun is unchanged: a fixed income taken off the resting bill. That
  bill is always the larger of the two, so the sun saves as much as it would if
  it came off the whole.

## 6. For the owner

| # | Question | Options | What it means |
| --- | --- | --- | --- |
| 1 | How much sooner should a cell starve? | gentle · **as built ✓ recommended** · harsh | A newborn that never eats and steers now and then dies at **5:42 · 4:36 · 3:24** (it was 7:40). Just drifting: 6:16 · 5:19 · 4:10. Turning all the time: 4:54 · 3:41 · 2:36. |
| 2 | Should `crista` and `vacuole` also make moving cheaper? | **yes ✓ recommended** · no | They already make being alive cheaper. With yes, swimming and turning get cheaper the same way, so both genes are worth more than before. With no, they only soften the resting cost. |
| 3 | With the push organ, should steering by touch pay for the push it gives? | **as built ✓ recommended** · make that push free | Once you grow the push organ, a finger on the screen pushes you (it always did), and now that costs food: turning by touch costs about a third more than on a keyboard, and a thumb just resting on the screen costs as much as holding the push key. The `pads` layout turns without pushing. Free would give phone players speed that keyboard players pay for. |
| 4 | Should the tail's automatic beat cost energy, or only what the player does? | **as built ✓ recommended** · only turning and pushing | As built, every cell starves sooner even if you touch nothing: about two thirds of the new cost is the tail beating by itself, and a faster tail costs clearly more. With the other, a drifting cell keeps the old 7:40, and only steering and pushing make you starve sooner. |

Row 1's gentle and harsh are `STROKE_COST` and `TURN_COST` halved and doubled;
nothing else moves.

**Answered 2026-09-29: the recommended option, all four rows.** "Recommended for
all." Row 1 holds for what moving costs against being alive; the pace itself
moved in the same message, to thirty seconds (§7), and the ratios came with it.

## 7. Thirty seconds

The owner, answering §6:

> Adapt so we starve after 30 seconds with spawn gear

**Read as: a born cell that never eats dies thirty seconds after it is born.**
"Starve" is dying of hunger, in the owner's own question that morning ("how
much time do you have before dying of hunger when spawning?"), which was
answered as fed-to-empty plus the grace. "Spawn gear" is the genome a run
starts with, `cytostome 1, cirrus 1, flagellum 1`. The play is §6 row 1's,
steering now and then, because that is the row the owner was answering.

### 7.1 What moved

| `metabolism.gd` | before | now | why |
| --- | --- | --- | --- |
| `HUNGER_SECONDS`, the tank at rest | 420 | **36** | steering a third of the time burns ×1.78, so the tank is empty at 20 s |
| `STARVE_GRACE` | 40 | **10** | the last ten of the thirty; "food ten seconds away is still worth swimming for" was always its reason |
| `MEAL`, a meal your own size | 0.5 | **1.0** | the whole bar; §7.3 is why |

**Nothing else moved.** Every cost of moving is in seconds of rest (§1.1), so it
came down with the tank and kept its share: a born cell still burns ×1.50
drifting and ×1.78 steering a third of the time. Two prices are shares of the
bar, not seconds of rest, and kept their share: the dash (6, 4.5 and 3.2 %,
which is now 2.2, 1.6 and 1.2 s of rest; at tier 1 that is almost exactly what
a stroke of the same speed costs, 2.16 s against 2.15 s) and
`veneneux`'s venom (46, 34 and 22 %). Hunger is each player's own, so there is no
`Wire.PROTOCOL` or `Wire.RULES` change (§1.3), and it ships as a content pack.

> **Seconds of rest since, 2026-09-29** (`gene-stats.md` §11, call 2). The dash
> and the venom are paid as the seconds their share of a born cell's tank comes
> to -- 2.2, 1.6 and 1.2 s, and 17, 12 and 7.9 s -- through `spend`, so `crista`
> and `vacuole` soften them as they soften every other cost. A born cell's price
> is unchanged. §1.3 has the note.

### 7.2 Dies at

`--fixed-fps 60`, seed 3, §3's plays over 120 s. The burn is measured with
hunger held low every frame, so the tank never empties under the measurement and
a meal changes nothing; the times are those of a cell that never eats
(`tools/forage_probe.gd --burn`, §7.7):

| play | burn | empty at | dies at |
| --- | --- | --- | --- |
| drifting, no input | ×1.50 | 24.0 s | **34.0 s** |
| steering a third of the time (2 s in every 6) | ×1.78 | 20.3 s | **30.3 s** |
| pushing all the time (`axoneme 1`) | ×2.18 | 16.5 s | **26.5 s** |
| turning all the time | ×2.31 | 15.6 s | **25.6 s** |
| pushing and turning, flat out | ×2.97 | 12.1 s | **22.1 s** |
| `flagellum 3`, drifting (82 s, until it divides) | ×2.32 | 15.5 s | **25.5 s** |
| `crista 2`, drifting | ×1.30 | 27.8 s | **37.8 s** |
| `vacuole 2`, drifting | ×1.05 | 34.2 s | **44.2 s** |

Seeds 1 and 2 give 30.2 s steering a third of the time. `levels_probe.gd`
holds the owner's number in CI from the constants alone, `36 / (1 + 0.500 +
0.806 / 3) + 10 = 30.35` s, and fails if it moves a second from thirty.

### 7.3 What a meal is worth

At thirty seconds the old `MEAL`, half a bar, is ten seconds of life, and a
drifter a newborn can swallow is worth half to four-fifths of that. Measured
with a bot that does what a player in full vision does: it steers at the
nearest body its mouth can take **on the screen** (the camera is north-up and
unzoomed, so a 16:9 screen is 1280 × 720 units around the cell and a 20:9 phone
1600 × 720). Sixteen seeds on each shape, three minutes each, a division
answered by leaning port.

| a meal your size is worth | starved within three minutes, 16:9 | on a 20:9 phone | the bar on average | time in the grace |
| --- | --- | --- | --- | --- |
| half the bar, as before | 9 of 16 | 7 of 16 | 0.61 · 0.64 | 1–28 % |
| three quarters | 8 of 16 | 4 of 16 | 0.52 · 0.56 | 1–21 % |
| **the whole bar** | **6 of 16** | **4 of 16** | **0.46 · 0.49** | **0–16 %** |
| one and a half | 6 of 16 | 1 of 16 | 0.41 · 0.41 | 0–15 % |

**The whole bar** loses a third fewer games than half a bar, and keeps the bar
in the middle, so the beat is usually saying something. The bot eats every
12.5 s at the median (8 to 19 s), has its first meal at 15 to 23 s and divides up
to six times in the three minutes; each division is a fed daughter.

**What it still loses to is not the meal.** The games it loses are lost to a
stretch with no food on the screen that outlasts a full tank, 32 s and more,
and no meal bridges that: on a 16:9 screen one and a half bars loses the same
six. The wider phone screen sees more water and has fewer such stretches. What
bridges them is time, §7.6 row 1: empty at 30 s and dead at 40 s, the same
bot starved in 2 of 16 on 16:9 and none of 16 on a phone.

### 7.4 Who can find food in thirty seconds

The same sixteen seeds and three minutes, with the whole-bar meal:

| forager | starved within three minutes | before any meal | first meal, where there was one |
| --- | --- | --- | --- |
| steering at food on the screen (full vision) | 6 of 16 on 16:9, 4 on a phone | none | 15–23 s |
| drifting, no input | 16 of 16 | 11, at 32–35 s | 23–28 s; then starved at 48–68 s |
| following its nose (`--sniff`, `chemocyte 1` from birth) | 16 of 16 | 9, at 27–29 s | 23–27 s; then starved at 44–96 s |
| steering at radar echoes (`ampulla 1` from birth, a crude bot) | 16 of 16 | 10, at 29–32 s | 18–28 s; then starved at 43–117 s |

**Point of view is where thirty seconds bites hardest.** Both sense bots are
worse than a person. The nose bot reads the level alone and spirals; the radar
bot acts on each echo once and only then, and ignores the ampulla's baffles and
its own body's shadow, which flatters it. A player will do better than either,
and how much better is what the dev app has to say. What the bots and the
arithmetic do settle:

- **The opening is tight whatever the sense.** The first body the water places
  for a newborn is 1000 units straight ahead (`FIRST_DISTANCE`), about 18 s of
  swimming at a born cell's 56 units a second; everything else arrives 920 to
  1350 units away; and the free sense comes at five seconds. A newborn steering
  now and then dies at thirty, so even a perfect opening has about ten seconds
  to spare.
- **More food did not fix it for the nose.** Doubling the water's cells
  (`COUNT` 68, eight seeds) left the nose bot starving before its first meal on
  7 of 8. The nose reads a sum, and more sources flatten it.
- **A bigger meal does not fix it.** Most of these bots starve before they have
  eaten anything.
- **The senses' tempo does.** A tier-1 nose answers one arc at a time; a tier-1
  `ampulla` pings every 8.8 s, and an echo from 1100 units takes 8.8 s to come
  back. Food has to be found inside the twenty seconds a tank lasts.
  three-senses.md measured the nose that still pointed, before the owner took
  its direction away: a bot steering onto its bearing fed on 8 of 8 seeds in a
  median 20.8 s, inside the clock. The nose that shipped fed its bot on 19 of
  24 seeds in a median 39.8 s, outside it. §2.5, §7.5 and §11.1 there called
  the slower opening "anxious, not lethal" because starving was 420 s away. At
  thirty seconds it is lethal.

The free sense also arrives at five seconds and waits to be placed. Left alone
it lapses in by itself 45 s later, after a newborn that has not eaten is dead.
And a `stigma` newborn can barely see a drifter at all: a shadow is mass, and a
drifter has almost none (normal_mode.gd's `FIRST_SENSES`). perception.md §2's
first sixty seconds, with the first meal at 0:45, are thirty now.

### 7.5 How it reads

Nothing new is drawn and nothing new is said; the beat still carries hunger. A
newborn that never eats (seed 1, drifting) beats ten times in its life: every
2.4 s at first, 3.6 s after ten seconds, 4.7 s when the tank is empty, then one
last gap of about 6 s into the grace, and the one after it does not come. A meal
your size puts it straight back to 2.4 s.

Two things about the opening:

- **Nothing may hunt the player before `FIRST_DELAY`, 42 s** (food.gd), so a
  newborn that never eats now dies before anything is allowed to hunt it. The
  opening's danger is hunger's.
- **A first-time player who does not yet know that eating keeps them alive
  will starve at about thirty seconds**, on their first life, with nothing to
  say why but the slowing beat and the quiet death.

And one about the shared pond: there the pause menu stops nothing, and hunger
keeps burning under it (normal_mode.gd, shared-pond.md §1.7). Ten seconds in the
menu is two fifths of a drifting newborn's tank.

### 7.6 For the owner

| # | Question | Options | What it means |
| --- | --- | --- | --- |
| 1 | What should the thirty seconds be? | **dead at 30 s: 20 s to empty, then 10 s of last chance ✓ recommended** · dead at 30 s: 25 s, then 5 s · empty at 30 s, dead at 40 s | The last chance is the end, where the heart slows right down and one meal still saves you. In ten seconds a newborn swims about 560 units, most of the way from the middle of the screen to its side. Five seconds is about one heartbeat. Dead at 30 s, a player who goes for every food on the screen still starves in about one game in three within three minutes on a 16:9 screen, one in four on a phone. Dead at 40 s, one in eight on 16:9 and none on a phone. |
| 2 | How much should a meal fill you? | **a meal your size fills you completely ✓ recommended** · three quarters · half, as before | A small drifter then fills you half to four-fifths of the way. With half, that same player starves in about half of three-minute games; with the whole bar, in about one in three on a 16:9 screen and one in four on a phone. More than a whole bar helps on a phone's wider screen and not at all on a 16:9 one, where what kills is a long stretch with no food in sight. |
| 3 | In point of view, a newborn usually starves before its first meal. Should its senses find food faster? | **not yet: play point of view on the dev app first ✓ recommended** · give the nose back its direction | Test bots that find food by smell or by radar starve before eating in about three games in five, and all of them within three minutes. A person is better than those bots, but only playing says by how much. The nose that pointed fed a bot in 21 seconds, but it undoes your smell change, and changing a sense is its own piece of work. |
| 4 | A first-time player starves at about 30 s, and only the heartbeat says why. Keep it? | **keep it, and judge it on the dev app ✓ recommended** · say it once, the first time a cell starves | The game has no tutorial on purpose: the heartbeat slowing is the lesson. Saying it once would put words on the screen where there are none now. |

Row 1's options are `HUNGER_SECONDS` and `STARVE_GRACE`: 36 and 10, 45 and 5,
or 53 and 10. Row 2's are `MEAL`: 1.0, 0.75 or 0.5.

Rows 1 and 3 pull the same way: dying at 40 s also gives point of view ten
more seconds to find its first meal. And the free first sense, if nobody places
it, lapses into its slot by itself 45 s after it arrives, at 50 s, which is
after a newborn that has not eaten has died (lifecycle.md §6's grant).

**Rows 1 and 3 want an answer before the next release.** Everything on `dev`
ships together, so a release cut before them sends thirty seconds to players
as built.

**Answered 2026-09-29: the recommended option, all four rows.** "All
recommended." Nothing moves, because the recommended option is what was built:

- **Row 1:** dead at thirty seconds, twenty to empty and ten of grace
  (`HUNGER_SECONDS` 36, `STARVE_GRACE` 10).
- **Row 2:** a meal your size fills the bar (`MEAL` 1.0).
- **Row 3:** no sense changes until the owner has played point of view on the
  dev app.
- **Row 4:** no words on the screen for a first death. The slowing heartbeat,
  and the replay behind `watch`, are what explain it.

Rows 1 and 3 have their answers, so nothing here holds a release. Rows 3 and 4
were answered "play it first", so what the dev app shows can still reopen them.

**Row 4 reopened, 2026-10-03.** The owner, after playing the dev app: *"hunger.
It must be more than what it is. I often die of hunger without noticing
anything."* A slowing, fading beat read as nothing at all, or as dread.
`hunger.md` answers it, still with no words: from half a tank the beat races at
full strength, the body crumples, and when the tank empties the membrane falls
in. The thirty seconds, the meal and the grace are unchanged.

### 7.7 To measure again

`tools/forage_probe.gd` wraps `tools/drive.tscn`, so every drive flag plays the
run as it always does. It never ships (`tools/*` is excluded from every export).

```
godot --headless --path . --fixed-fps 60 -s res://tools/forage_probe.gd -- \
    --size=1280x720 --seed=3 --mode=0 --scheme=0 \
    --genome=cytostome:1,cirrus:1,flagellum:1,stigma:1 --burn --probe-until=120
```

That is §7.2's drifting row. Add `--hold=a` to turn all the time, and
`--key-down=T:a --key-up=T+2:a` for T = 0, 6, 12, and so on up to 114, to steer
a third of the time. For §7.3 and §7.4, drop `--burn` and `stigma`, run
`--probe-until=180` on seeds 1 to 16, and add `--screen=1280x720` (a 16:9
screen) or `--screen=1600x720` (a 20:9 phone), or `--ping` with `ampulla:1`, or
drive's own `--sniff` with `chemocyte:1`. With none of them it is the drifting
row. `--seek=800`, the first draft's bot, sees 800 units in every direction,
past a real screen's top and bottom, and it starved in none of eight games: it
is there to compare with, not to quote.
