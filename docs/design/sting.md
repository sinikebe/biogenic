# The sting, and the chase's aim

The owner, in the gene pass (2026-10-15):

> the cells behavior must be dictated by its inherited and evolved instincts, not
> hard coded elements

and, asked whether the sting should become an instinct with a button:

> Sting is a contact weapon. It hurts, whether you want it or not

then, on the table that followed: **1, touch and wounds. 2, yes.**

Status: **built**. This page is what the two answers changed, the numbers they
start at, and what to watch when playing.

---

## 0. In one place

1. **The sting (`trichocyst`) is a contact weapon.** Whatever touches the body on
   the arc it is worn on is wounded: a water cell, a drifter, you, a friend. It
   fires on its own, then waits out its cooldown. No instinct and no button fires
   it: a sting is the body's, not a behaviour.
2. **It wounds and never stuns.** It used to fire from a distance at a body coming
   for its own and stun it for 5 s. Nothing stuns now.
3. **A sting never finishes a body.** It wounds to at most 95 %, and a bite or a
   dose does the rest.
4. **How far ahead a chaser aims is its instinct's.** "Turn toward" takes an aim,
   from "at it" to "far", which a division may nudge one step. The founders aim
   where every chaser used to.
5. **The rules moved, not the protocol.** `Wire.RULES` is new, so players on this
   content and the content before cannot share a pond until both update.

---

## 1. The sting

### 1.1 What it does

On every frame of the water, after the bodies are pushed apart, each body whose
sting is ready looks for the nearest body touching it inside `DART_ARC_DEG`
(110°) of the bearing it is worn on. "Touching" is two skins within `STING_TOUCH`,
2 µm, of each other. If one is there, it is stung, and the sting's cooldown starts.

| | 1 copy | 2 copies | 3 copies |
|---|---|---|---|
| wound, as a share of a born cell | 8 % | 12 % | 16 % |
| again after | 26 s | 18 s | 11 s |

- **The wound scales with size**, as a dose's stack does: `wound × (26 / r)²`. So
  a sting tears a small body and grazes a big one.
- **It is felt as a hit** at the sting's bearing, as a bite is. A water cell's rules
  read it as `body.hit`; you feel it on the membrane.
- **You feel your own sting go off**, as a shove at its bearing (it used to say a
  dart went off).
- **It never takes a wound past `STING_MOST`, 95 %.** A sting is a defence, and a
  body killed by one would need a cause of death nothing else has.
- **Only the host stings**, in its own frame, for itself and its guests. A mirror
  never does.

The starting wound is about one born mouth's head-on bite (0.07) at one copy, and a
little over two at three: a sting is a bite you did not have to aim. The cooldown is
the dart's. Both are starting values: balance waits for players.

### 1.2 What went

- **The range**, 130 / 190 / 260 µm, and the "coming for it" test that chose what to
  fire at. That test was the code judging another cell's intent. A touch judges
  nothing.
- **The stun**, 5 s with a body's rules unread. `cell.gd`'s `dart_stun` and the
  organ's `stun` number are gone. The stunned state stays in `food.gd` for a dose
  that paralyses, which nothing delivers yet.
- **The dart in today's water**, which broke off a run at range. Today's water is the
  probes' reference and has no sting at all now.

The stat `dart_range` became `dart_wound`; the organ, its look, its arc and its
cooldown are as they were. The code still calls the discharge the dart.

### 1.3 What it means in play

- **A sting no longer stops a hunter before it reaches you.** It answers the touch:
  the hunter that bites your flank is stung as it bites, and a sting on your nose
  wounds what you bite into.
- **It hurts friends and food too.** Brushing a friend with your sting's side stings
  them, and bumping a drifter spends your sting on it.
- **Placement still matters most**: the sting guards one arc, and a rear sting is
  still the answer to being flanked.

---

## 2. The chase's aim

`body.turn-toward` used to lead a moving target by a fixed `LEAD := 3.0` in
`food.gd`, the textbook navigation constant, for every chaser. It is the rule's own
option now:

| option | said | aims |
|---|---|---|
| 0 | at it | straight at where the sense says it is |
| 1.5 | near | a little ahead of where it is going |
| 3 | ahead | as every chaser did before |
| 4.5 | far | further ahead |

- **The founders aim "ahead"** (`drop.gd`'s FOUNDERS say `body.turn-toward 3`). A
  line written before the option existed, in a kept library or a kept drop, reads as
  3 (`cell.gd`'s `LEAD_DEFAULT`; `rulebook.gd`'s output `default`).
- **A division may nudge it one step**, as it nudges a push's strength (behaviour.md
  §6.2), so a family can get better or worse at cutting off its prey.
- **On your instincts page** the action reads `turn toward · ahead`, and the row of
  options under it picks the aim. A new "turn toward" starts at "ahead".

The French chip for "turn toward" is now `va vers`, shorter than `tourne vers`, so
the aim fits on the chip: the catalog lint keeps 40 px of arc between an instinct's
two chips, and `tourne vers · avant` left 31.

---

## 3. Checks

- **The gene probe**: two stings in either order give the first one's wound and rest
  (it used to check the stun); a person's order is written before its genome, by the
  wound. Every part the hand works names a control kind.
- **The drop probe**:
  - check 11: a water cell's sting wounds a body touching its side by the felt share,
    the body feels a hit, nothing on its other side is touched, and it waits;
  - check 10: your sting, in the water's own frame, stings a body touching its side
    and neither one 200 µm off nor one on your other side, the stung body turns away
    on its next tick, a trichocyst in the water stings you when you touch its side,
    and a sting stops at `STING_MOST`;
  - tail 5 keeps its wakes and drops the dart, which no longer answers a hunter at
    range.
- **`ci.yml` check 8** is re-pinned. Diffed against `dev`, the traces part at 1.03 s,
  where `dev`'s dart stunned a body from a distance. With that dart taken out of
  `dev` and the stings left out here, the two agree to 37.2 s, the first daughter
  whose division nudged an aim.
- **`Wire.RULES`** moved: the sting's rows, its touch and its limit are rules a host
  decides contacts by.

---

## 4. What to watch when playing

- **Whether the sting still feels like a defence.** It wounds instead of stopping a
  hunter. If a sting now feels useless, the levers are the wound and the cooldown,
  not a return to range.
- **Whether stinging friends and food feels fair.** That is the rule ("whether you
  want it or not"); a sting on the nose spends itself on every meal it bites into.
- **Whether families visibly differ at the chase.** Over a long drop, some hunters
  should cut you off and others trail you. The ladder (`LEADS`) is the lever.
