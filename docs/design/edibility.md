# Edibility: position, not size

The owner, overturning `genes-and-cilia.md` §1.1:

> "Radius shouldn't decide who you can eat. You could try to eat anyone if you
> have the technic. For example, a huge cell could be eaten from behind if it
> has nothing to defend itself."

§1.1 said *"You can eat a cell whose body fits in your mouth. That is the whole
rule."* That sentence is withdrawn. What replaces it is smaller than it sounds,
because **the build already went most of the way and the document did not follow
it.**

> **What is already shipped, and was not written down.** `food.gd`'s
> `_bite_from_me` carries this docstring: *"Your own mouth on a body too big to
> swallow. The option the player never had: whittle it down and it comes apart,
> and then it is a meal on exactly the terms a swallowed one is."* Biting, wounds
> that accumulate, `pellicle` dividing the damage, `toxicyst` charging the biter,
> and a body that is devoured at `wound >= 1.0` all exist, in both directions,
> off one table. The mouth is directional geometry (`Cilia.mouth_touches`) and
> bodies are solid. **You can already eat anything. Nobody told the player, the
> numbers do not reward doing it the clever way, and §1.1 still says you cannot.**

This spec is the smaller half of two. `lifecycle.md` is the other and depends on
this one through §1 — what an encounter is now — and §4 — that there is no
radius at which you are safe. They are separate documents because they change
separate files — this one is `cell.gd` and `food.gd`, that one is
`normal_mode.gd` and `genome.gd` — and because a spec nobody finishes reading
is not a spec.

## 1. The rule

> **You can attack anything. The gape decides whether you swallow it whole or
> have to take it apart, and where you bite decides how long that takes.**

Three sentences of code, two of which already run:

| | condition | what happens |
| --- | --- | --- |
| **swallow** | `target.swallow_radius < my.gape` | one contact, one meal. Shipped, unchanged. |
| **take apart** | otherwise | a bite every `BITE_GAP`; at `wound >= 1.0` the body comes apart and is a meal on the same terms. Shipped. |
| **nothing** | `cytostome` tier 0 | `BITE_BY_TIER[0]` is a hard zero. A mouthless cell touches you and nothing happens. Shipped, and §4 is why it must stay a hard zero. |

The gape keeps its job and loses its veto. A mouth still physically cannot
engulf a body several times its width, and `bite_damage`'s `min(gape / radius,
1.0)` term already makes taking apart something enormous slow rather than
impossible — which is the right shape and needs no change.

**What it costs, off the shipped tables.** A born cell (`r26`, `cytostome 1`,
gape 21) chewing an `r40` body with no `pellicle`: `0.07 x (21/40) = 0.0368` a
bite, one bite per `BITE_GAP 0.85 s`, against `MEND_SECONDS 75` healing `0.0113`
in the same interval. Net `0.0254` — **40 bites, 34 seconds of unbroken mouth
contact.** A `cytostome 3` mouth (gape 36.4) does it in 7. Against an `r80`
runaway the same two builds need 120 s and 16 s. Those are already the numbers;
nothing here changes them.

Thirty-four seconds of holding your nose against a body that is doing the same
to you is not a fight anyone wins. That is the gap §1.2 closes.

### 1.2 Where you bite it

One new pair of constants and one new argument. `theta` is measured **at the
target**, between its own heading and the direction the mouth arrived from: 0 is
dead ahead, `PI` is dead astern.

```gdscript
# cell.gd, beside BITE_BY_TIER
## Where on a body a bite lands, and therefore how much of it lands. The nose is
## 1.0 because that is where the target's own mouth is and where it is thickest;
## astern nothing it has can answer. A cosine, so there is no angle at which the
## damage steps.
const FLANK_AHEAD := 1.00
const FLANK_ASTERN := 2.10

static func flank(theta: float) -> float:
    return lerpf(FLANK_AHEAD, FLANK_ASTERN, 0.5 - 0.5 * cos(theta))
```

`bite_damage()` gains `theta` and multiplies by `flank(theta)`. **One definition,
asked in both directions**, exactly as the docstring already promises: the water
chewing on the player and the player chewing on the water read the same table.

The same born cell on that `r40` body's stern: `0.0368 x 2.1 - 0.0113 = 0.0659`
— **15 bites, 13 seconds.** On its nose it is 34 seconds *and* the target's own
mouth is on you for all of them. The owner's sentence is now literally true and
it cost two floats.

**2.10 is the number to move, and it is the whole difficulty of flanking.** It
is not measurable from a still frame; it is the first thing to change if taking
a big cell apart feels either hopeless or free.

## 2. What "defends itself" means

**No new genes.** Five that exist already answer it, and one of them gets a job
it has never had.

| gene | what it defends against | change |
| --- | --- | --- |
| **`cirrus`** *turn* | being flanked — you turn your nose onto the attacker and the 2.10 becomes 1.00 | **none.** A 180° turn is 5.1 s at tier 1 and 3.1 s at tier 3, against a 13 s stern kill. `cirrus` stops being a foraging gene and becomes the defensive one. |
| **`pellicle`** *armor* | every bite, everywhere | none. Divides the damage; tier 3 turns a 13 s stern kill into 22 s. |
| **`trichocyst`** *sting* | being held on one bearing | **becomes directional.** See below. |
| **`toxicyst`** *venom* | the attacker, afterwards | none. Already charges a biter a share of what it just did. |
| **`vacuole`** *store*, **`crista`** *burn* | the length of the fight | none. A fight is now measured in seconds of contact, so endurance is defence. |

**`trichocyst` reads the arc it is worn on.** It is the one gene whose fix is
required rather than optional: today the dart is a scalar range and fires at
whatever is near, which under a positional rule is a defence with no position.
It should fire only within `DART_ARC_DEG := 110.0` of `Cilia.slot_bearing(slot)`
— the same wiring `_beam_bearings()` already does for the `ocellus`, in the same
file, for the same reason. **A dart in a rear slot is the answer to being
flanked**, and placement becomes a defensive decision instead of only an
offensive one. Nothing else about the gene changes.

That is the whole of it: turn, armour, a dart on a bearing, venom, and stamina.
A cell with none of those, drifting, presenting its stern — *"nothing to defend
itself"* — is thirteen seconds of work, and it is thirteen seconds because of
what it lacks rather than because of how big it is.

**Point of view is worse at this, deliberately and not silently.** Reading a
body's facing is a full-vision fact. Blind, the player has a bearing
(`ampulla`), a hit point (`ocellus`) and contact (`palp`) — enough to find a
body, not enough to know which way it is pointing. A gene that reports facing is
the obvious next earned sense and it is **headroom, not scope**: do not build it
here, and do not pretend the asymmetry is not there.

## 3. Dread, and the hole in it that was measured

Dread is a pure continuous relation summed over every body — `smoothstep(0.85,
1.35, other.gape / my.swallow_radius)` times a distance falloff — and
`food.gd` spends thirty lines explaining why no boolean may ever enter it. That
stands. **Nothing below is a gate; the new term is added to the old one, not
branched against it.**

**The hole, measured against the shipped build.** Two `r40` cells with
`cytostome 1` parked with their mouths 43 units off an `r40` player's skin:

| the parked pair | dread | what they can actually do |
| --- | --- | --- |
| `cytostome 1` — gape 32.8, ratio **0.82** | **0.084** | chew you to death in 18 s of contact |
| `cytostome 2` — gape 42.0, ratio **1.05** | **0.753** | swallow you instantly |

0.82 is below `THREAT_LOW`, so the first pair contributes **exactly zero** and
0.084 is the rest of the field a kilometre away. The membrane is silent about a
body that can kill you in eighteen seconds. It was silent about it before this
change too — the bite has been shipped for one release — so this is a defect
being fixed, not a cost being paid.

```gdscript
# food.gd -- added to the threat weight, never substituted for it
const CHEW_SHARE := 0.55          ## a chewer never reads as loud as a swallower
const CHEW_FULL_SECONDS := 12.0   ## the rate at which this term saturates
const CHEW_HURT_FLOOR := 0.35     ## what a whole body feels of it
const CHEW_RANGE := 520.0         ## and its own, much shorter, distance falloff

# rate = CellBody.bite_damage(its cytostome, its gape, my radius,
#                             my pellicle, PI) / CellBody.BITE_GAP
# urgency = clampf(rate * CHEW_FULL_SECONDS, 0.0, 1.0)
# chew = CHEW_SHARE * urgency * (CHEW_HURT_FLOOR + (1.0 - CHEW_HURT_FLOOR) * my.wound)
# weight = swallow_weight + chew          <- summed. Then today's cap.
```

Four properties, each of which is the reason for one line:

- **It is continuous everywhere.** `bite_damage` is continuous in every
  argument, `clampf` is continuous, the sum is continuous. A body's contribution
  moves smoothly as its mouth grows, as you grow and as you are hurt.
- **`theta = PI` is used, not the live angle.** Dread is what a body *could* do.
  Feeding the real bearing in would make dread swing as the player turns, which
  is `statocyst`'s job and not fear's.
- **It keys on your own wound, continuously.** `0.35 + 0.65 * wound`: a whole
  body feels a third of it, a body that has been chewed feels all of it. Being
  hurt genuinely does make the water more dangerous, and the membrane should say
  so. It is a fact about your own body, so it adds no state and no gate.
- **520, not 1400.** Something that needs twelve seconds of unbroken contact is
  not a threat at a kilometre. The short range is what stops seventeen mouthed
  peers raising the floor of the readout — the new term is quiet almost always
  and loud exactly when something is on you.

## 4. The floor and the ceiling still hold, for different reasons

§1.3's guarantee — *the world cannot degenerate* — was carried by two constants.
Both survive; one changes what it means.

- **The drifter floor is unchanged and is now load-bearing in a second place.**
  A drifter has `cytostome` tier 0, and `BITE_BY_TIER[0] = 0.0` is a **hard
  zero, not an extrapolated step** — the comment in `cell.gd` already says *"a
  floor that could chew on you would not be a floor"*. Under this rule that
  sentence stops being a nicety: the hard zero is the only thing in the game
  guaranteeing anything at all is harmless, and it is what keeps a wounded
  player's water survivable. **Never give tier 0 a nonzero bite.**
- **`ARRIVAL_GAPE_MAX = 40` stops meaning "at r40 nothing can eat you" and
  starts meaning "the water never seeds a mouth that can end you in one
  contact".** That claim is still true, still a real bound on the worst arrival,
  and still the top of the difficulty curve. What is gone is the *safe harbour*:
  there is no radius at which the water cannot kill you, because anything with a
  mouth can take you apart given time and position.

  **This withdraws `genes-and-cilia.md` §3.1's "the genome fills on the same
  meal that nothing left in the water can eat you" and §1.3's "dread stops
  arriving, and that is the readout that the run is won".** There is no won
  state. `lifecycle.md` §2 rebuilds the division trigger without appealing to
  either, and the arc is better for it.

## 5. What the water does about it

The rules are symmetric; the *behaviour* need not be, and should not be, or the
water becomes a brawl in which every cell gnaws every other one.

- **A cell still hunts only what it can swallow.** Unchanged. That is what it
  commits a chase to.
- **A cell bites what it bumps into.** Unchanged, and already shipped.
- **One addition: `CHEW_INVITE := 0.35`.** A cell will *commit* to a body it
  cannot swallow once that body's `wound` is past this. Blood in the water.
  It is the owner's sentence from the other side — a body that has been opened
  up is a body that could not defend itself — and it produces the best emergent
  moment available: **you get hurt, and the water changes its mind about you.**
  The wound is drawn on every body already, so the player watches it happen to
  somebody else before it happens to them.
- **`AIM_STERN_SHARE := 0.6`.** A committed hunter leads the point `0.6` of a
  radius behind its target's nucleus rather than the nucleus itself, so it
  arrives on the quarter. This is the change with the largest felt effect in the
  whole spec and it is the one most likely to be too strong; it is the second
  dial after `FLANK_ASTERN`.

## 6. What is drawn: nothing new

No new mark, no new colour, no new uniform, no new art. The playfield already
carries every fact this rule needs, and three marks only change what sentence
they are the answer to.

| mark | was | is now |
| --- | --- | --- |
| **scent bloom** on a body | "I can eat it" | **"I can swallow this whole"** — one contact, no fight. Exactly the same drawing and exactly the same edibility curve; the bloom simply stops being the whole menu and becomes the shortcut. |
| **red toothed lip bow** | "it can eat me" | unchanged, and more important: it is now the only *instant* death in the game. |
| **the gape bow's size** | how wide its menu is | how fast it could take you apart. §4.5's *"the gape is what decides the encounter"* survives the change in full. |
| **the rim's tears** | damage | damage, **and an invitation** (§5). It was already drawn on every body; it now means something to everyone looking at it. |

A cell's facing is already legible from its own shape — the ovoid has a pinched
nose and the mouth is drawn on it — so *"which end is soft"* needs no mark
either. **A rule that costs nothing in the playfield is the best outcome
available here**, and it is only available because the four marks were drawn on
the thing that causes them rather than on a status line.

## 7. What this breaks in the shipped documents

- `genes-and-cilia.md` **§1.1** — *"You can eat a cell whose body fits in your
  mouth. That is the whole rule."* Withdrawn. The four-relationship table in
  §1.1.1 is now **four ways an encounter opens**, not four verdicts.
- **§1.1's "standoff"** no longer exists. There is no pair of cells with nothing
  between them; there are pairs for whom the fight is long. That deletes the
  claim that *"cytostome 2 is where the water stops having standoffs in it"* —
  the water never had them, it had long fights nobody was allowed to start.
- **§3.1 and §1.3's ending.** See §4 above.
- **§1.2 / §9.8's "legendary organism"** — a cell that grew past the arrival
  ceiling — is no longer unkillable. It is a thirteen-second job from astern
  with a good mouth. That is a strict improvement: the runaway I measured
  (`r82`, gape 114, four minutes into a run, nothing in the water able to touch
  it) stops being a dead end.

## 8. Left open — owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | How much softer is a body's stern than its nose? | `FLANK_ASTERN` **2.10 ✓ recommended** / 1.6 / 3.0 | 2.10 makes taking a big cell apart from behind about thirteen seconds of staying there, against thirty-one from the front. Lower and flanking is not worth the trouble; higher and one good approach kills anything. |
| 2 | Will other cells gang up on a wounded body? | `CHEW_INVITE` **0.35 ✓ recommended** / never / always | At 0.35 the water turns on anything that has been opened up, including you. "Never" keeps chewing a player-only trick; "always" makes the water a permanent brawl. |
| 3 | Do hunters aim for your stern? | **yes, `AIM_STERN_SHARE 0.6` ✓ recommended** / no | Yes means the water plays by the rule it teaches, and being flanked is how you learn to flank. It also makes hunters markedly deadlier; this is the first thing to turn off if the water feels unfair. |
