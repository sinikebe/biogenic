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

## 1. The decision

**The tank stays and the spending grows.** `metabolism.gd`'s `HUNGER_SECONDS`
is still 420: seven minutes from fed to starved, but now only for a body at
rest, which no living cell is. On top of being alive (`upkeep`, genes-and-cilia.md
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

### 1.3 What did not move

- **The dash** keeps `DASH_COST_BY_TIER`, its price since Phase 5: 6, 4.5 and
  3.2 % of the bar, about 25, 19 and 13 s of rest. It is not also charged as a
  stroke. It stays a share of the bar that store and burn do not soften, which
  is older than this and is for the gene-stats work to make consistent.
- **The grace** is time. Spending stops at full hunger and never shortens the
  forty seconds, because swimming for food at the end is exactly what the grace
  is for.
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
| `myoneme` | per dash (unchanged) | 25 s | 19 s | 13 s |

Per use: a tier-1 beat costs **1.3 s** of rest (1.8 s at tier 3); a half turn
costs **4.1 s** and a full circle **8.2 s** at every tier.

A body that has lost its flagellum (tier 0, which genes-and-cilia.md §9.7
allows) beats on the tier-0 ladder and pays 0.36.

## 3. Measured

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

Seeds 1 and 2 give ×1.48 and ×1.53 drifting and ×2.29–2.30 turning: the spread is
the stroke's random strength. Every row matches the arithmetic of §2 to within
it — the `crista` row is `(1.18 + 0.5) × 0.77`, the `vacuole` row
`(1.18 + 0.5) / 1.6`, since tier 2 of either adds its own 0.18 of upkeep.

**What a meal buys** (half a bar, genes-and-cilia.md §3.2's unit), for a born
cell: 210 s before at any pace; now 140 s drifting, 118 s steering a third of the
time and 91 s turning all the time.

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
3.1 s and 0.81. A player learning by playing finds out that swimming around
wears them out, and that sitting still in a good spot is a strategy. A player
who wants to master it gets the numbers in §2 when the gene descriptions carry
them.

## 5. For the gene descriptions (the next piece of work)

The owner wants the numbers there for players who want them, and nowhere they
would be imposed on players who do not. This change keeps that door open rather
than walking through it:

- every cost is one constant per organ, in a unit that reads as time;
- §2's table is what each organ costs, by tier, in that unit;
- the pause screen's `EXPLAINS` lines are untouched, and still true.

## 6. For the owner

| # | Question | Options | What it means |
| --- | --- | --- | --- |
| 1 | How much sooner should a cell starve? | gentle · **as built ✓ recommended** · harsh | A newborn that never eats and steers now and then dies at **5:42 · 4:36 · 3:24** (it was 7:40). Just drifting: 6:16 · 5:19 · 4:10. Turning all the time: 4:54 · 3:41 · 2:36. |
| 2 | Should `crista` and `vacuole` also make moving cheaper? | **yes ✓ recommended** · no | They already make being alive cheaper. With yes, swimming and turning get cheaper the same way, so both genes are worth more than before. With no, they only soften the resting cost. |

Row 1's gentle and harsh are `STROKE_COST` and `TURN_COST` halved and doubled;
nothing else moves.
