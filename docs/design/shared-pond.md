# Shared pond: two cells, one water, on a LAN

Build spec; every line number cites the code at `d11eb29`. Anything *measured* was
run in this container on Godot 4.7-stable, headless or under xvfb; nothing ran on
a phone. `shared-pond-ux.md` owns what is drawn and what is said. This file owns
the simulation, the wire and the order of work, and defers to that one wherever
the two touch.

**The owner's decisions, binding here.** (1) The second player is a friend you
text. (4) One water, and both swim in it. (5) A dividing player leaves the water
and comes back as the chosen daughter where they left. (6) Every cell obeys the
same eating rule, with no player special case; *which genes decide one bite or
chewing* is a later phase, so nothing here may special-case players in a way that
rule would have to undo. (7) Pings are heard (shipped). (A) A death is a tap on
the black and a return at generation 1 near your friend, and no death resets the
pond, the host's included. (B) Pause stops nothing.

## 0. What the code says, against the brief

**0.1 The wound is contact state, so the host owns the remote cell's wound.**
`_bite_from_me` checks the eater's death before the prey's (`food.gd:1586-1593`),
and `_bitten_by` breaks the biter off in the frame of the kill (`:1550-1556`).
Both need the wound the bite was computed against, in that same frame. A wound
the guest owned would reach the host 50-100 ms stale, and could feed a corpse. So
the host bites, envenoms and mends the guest's wound with `CellBody.mended`
(`cell.gd:443`), decides every contact death, and sends the value in every
snapshot. The guest mends with the same function between snapshots, so the
correction is zero unless something bit. Healing stays local; ownership does not.

**0.2 Positions cross the wire; bearings never do.** A contact event carries the
other body's world position at that instant. The guest turns it into a bearing
with its own `_cell.bearing_to()`, as `_hear_others` does for a shout
(`normal_mode.gd:770-800`). A bearing made on the host is wrong by however far
the guest has turned since its last frame.

**0.3 A lost host means fresh water, not an adopted mirror.** The mirror never
receives the AI's targets, aims, clocks, calm or break state (`food.gd:731-752`),
so an adopted field would be a new AI starting mid-hunt. `shared-pond-ux.md` §5
already ends a lost pond with the §0.5 beat onto fresh water, which is `setup()`:
the same reseed every birth and every return already runs.

**0.4 Three things stop or overwrite the water, not one.**
`_set_simulating(false)` (`normal_mode.gd:1488-1491`) runs at a death (`:1315`)
and at the pinch (`:952`); `_food.setup()` runs at every birth (`:1155`) and
return (`:1471`); and the replay writes recorded bodies onto the live field
(`replay.gd:151-190`) and calls `_food.set_process(false)` (`:477`). A host
watching a replay on the black would freeze the guest's water and overwrite it.

**0.5 Today's eating rule has one player special case, and a quieter
asymmetry.** A water cell swallows another on contact, but swallows a player
only from a committed run (`food.gd:1409-1436`). And `pellicle` armours a player
against a swallow (`cell.gd:508-509`) but not a water cell: `food.gd:1467` tests
the bare radius. Removing either would change single player, so this spec
extends both, unchanged, to *both* players. The first goes to the owner (§6 row
3); the second belongs to the later phase (`roadmap.md`).

**0.6 Motes feed a sensation and still stay local.** They are the opening `hit`,
and they bump the cell (`motes.gd:83-89`), but no field body ever touches one.
The price: in full vision, a friend swims through grit that is not in their water.

**0.7 Full vision draws every body in the field, on screen or not**
(`vision.gd:965-998`). Draw callbacks run under `--headless` too; measured, 1,921
`draw` signals in 1,920 frames. That drawing, not the simulation, is the pond's
largest cost (§4).

## 1. Architecture

### 1.1 Who owns what

| state | owner | how the other side learns it |
|---|---|---|
| position, heading, velocity, radius, worn tiers and order, hunger, generation, division | the cell's own device | STATE at 20 Hz (shipped); PERSON on change |
| wound, bite and dart clocks, first-hunt grace, every contact and its outcome | the host | the snapshot header (wound); CONTACT events |
| every water cell: AI, seeding, culling | the host | POND at 20 Hz; GENOME once per body version |
| motes | each device, its own | never |

### 1.2 The friend is a body, in slot 68, on both devices

`PERSON_SLOT := 2 * COUNT` (68) holds the other player on both devices: the guest
in the host's field, the host in the guest's mirror. The local cell stays `_cell`
and keeps `TARGET_PLAYER` (`food.gd:703`), so every single-player path is
untouched.

To smell, taste, dread, shadow, beams, ping returns and occlusion, touch,
separation, vision and the recorder, the remote player is simply a `Body`. A
`Person` record beside it carries what a body lacks: velocity and turning; swim
speed, from a new `cell.gd` static `swim_speed_of(flagellum, axoneme)` that
`swim_speed()` (`:580-582`) also calls; dart range and cooldown from
`trichocyst` and its bearing from the worn order via `Cilia.slot_bearing`; venom
cost from `toxicyst`; and `first_hunt`, `dart_clock`, `in_water` and `quiet`.

Wherever the AI asks something of *the* player, it asks the same of a person, with
the same arithmetic. Each rule becomes one function with two callers, and the
identity gate (§5) proves that refactor changed nothing.

| rule | today | in a pond |
|---|---|---|
| `_look_for_prey` (`:1022`) | the local cell after `FIRST_DELAY`, by armoured radius and wound (`:1039-1044`) | a person too, after its own `first_hunt`. Nearest wins, so the AI hunts whichever player is closest and fits; an exact tie goes to the local cell, tested first. |
| `_predict` (`:1287`), `_reference_speed` (`:2513`) | the player's closed form | the same, fed the person's pose and speed |
| `_target_present` (`:2548`) | always true for the player | false for anyone out of the water, the local cell included |
| wake and dart (`:1137-1164`) | signals | for a person, CONTACT events, with its own anatomy and dart clock |
| `_step_body` (`:988`) | behaviour | a person is only mended and its bite clock run down |
| `_step_separate` (`:1630`) | moves both bodies | each device moves only what it owns, by the same area share |
| `_seed`, `_devour` | on eaten bodies | never on a person: an event and a removal instead |

### 1.3 One eating rule

| contact | the host resolves | who hears what |
|---|---|---|
| a water cell's mouth on a person that fits its armoured radius, the cell committed to that person | killed, or `stung` if the person carries venom (the cell is retired) | the person: CONTACT `KILLED` or `STUNG` |
| a water cell's mouth on a person that does not fit | `_chew` onto the person's wound, venom back to the cell; a wound of 1 kills | the person: `BITTEN` (felt level) or `KILLED` |
| a person's mouth on a water cell | swallowed if `radius < gape` (today's bare-radius rule for water cells), otherwise chewed | the person: `ATE` (nutrition, dominant gene) or `BITTEN` (felt share) |
| one player's mouth on the other | today's rule without the commitment, because a human's mouth on you *is* the commitment: swallowed if it fits the armoured radius, otherwise chewed, both ways, with flank and venom | the eaten: `KILLED` or `BITTEN` by the friend; the eater: its own `eaten` or `bitten` |

The order inside a contact is `_bite_from_me`'s: the eater's death is checked
before the meal. Nutrition is `_meal_value` against the eater's reported radius.
The mirror emits the shipped signals (`waked`, `bitten`, `stung`, `darted`,
`eaten`, `killed`) from these events, so `normal_mode.gd`'s handlers, `vision.gd`
and the recorder all run unchanged.

**Built in Phase 1, and three things the table left unsaid.** (1) The two
players' contact is resolved on the host from its own cell's side, exactly as a
water cell's contact with that cell is, with the person in the water cell's
place: so a pair that could each swallow the other goes to the one whose mouth
is asked first, which is the guest's -- the shipped pass asks a water cell's
mouth before the host's. (2) A swallow is today's rule entire, venom included:
a player who swallows a venomous friend is poisoned, as a water cell is. The
friend is `STUNG` and the swallower dies, and that death is a fourth cause,
`POISONED`, which DIED (§2) has to carry. (3) Each chewing direction keeps its
own shipped order: a mouth on the host is `_bitten_by`'s (the victim's death
first), the host's mouth on the friend is `_bite_from`'s (the eater's first;
it was `_bite_from_me` until it had to bite for either player). The host's own
contacts reach its run through the same `hear_contact()` the mirror uses, so
its handlers cannot tell a pond from single player.

### 1.4 The water is tuned to each cell

An **anchor** is a player with a body: in the water, out of it dividing, or
quiet. Single player keeps `food.gd:1696-1699`; in a pond only, each frame runs
four steps.

1. **Cull.** Retire (`seeded = false`, radius 0) any water cell farther than
   `CULL` (1,700) from every anchor. With no anchor, cull nothing.
2. **Quota.** While some anchor has fewer than `COUNT` (34) cells within `CULL`
   and a slot is free, seed one *for* the anchor with the largest deficit. Ties
   go to the anchor seeded for least recently.
3. **Excess.** While every anchor has more than `COUNT`, retire one cell per frame
   that lies beyond `RING_MAX` from every anchor.
4. **Floor.** An anchor whose disc holds no drifter gets one in the next free
   slot, quota or not. This is `_other_drifter`, per anchor.

**Seeding for P** is today's `_seed` with P substituted: origin at P, P's radius
in `_seed_peer` (`:2394-2401`), P's senses in `_drifter_share` and `_tier_weight`
(`:2459-2478`). It adds one constraint: the point must be at least `RING_MIN` from
*every* anchor, the visibility bound of `:384-398`. That takes up to 8 angle
draws, then falls back to the ring point directly away from the nearest other
anchor. Eaten cells are retired rather than reseeded in place, and the quota
refills them at the end of the frame.

**How overlapping rings behave.** Together, the two players share one disc, each
quota is met by the other's cells, and the water holds about 34, not 68 (§6 row
1). New cells alternate between the two tunings, so a veteran and a newcomer side
by side meet a mix of both waters (§6 row 2). Apart, each player has its own 34.
While they converge the density briefly doubles, and step 3 relaxes it.

**Built in Phase 1.** The four steps run once a frame after the contacts and the
pushing and before the organs, so a slot a meal emptied is refilled in the frame
it emptied and no sense ever reads the hole. A retired slot takes a new serial,
so a chase of the body that was there ends rather than carrying on against the
next one. Step 3 never retires a cell on a run at a player -- a hunt must not
vanish from under the dread it raised -- nor the last drifter of any disc. Step
4 with every slot taken replaces the farthest of that anchor's own cells that no
other disc counts and that is not on a run at a player; the quota itself never
needs to, because two separate discs hold exactly 68 and overlapping ones share.
Each body records which player's water it was made for (`Body.tuned`).

### 1.5 Leaving the water does not stop it

In a pond, `_set_simulating(false)` stops Cell, Metabolism, Motes and Genome,
but not Food. Food instead gets `in_water = false`, which skips the local cell's
contacts, separation and targeting, and its four organ steps, so a dead or
dividing cell never pings or shouts. A player out of the water is still an
anchor, so what a daughter comes back to is still there (`shared-pond-ux.md` §2);
a dead player is not. `_be_born` resets only the local organ state that `setup()`
resets today: clocks, pulses, echoes and `first_hunt`. `put_sister` takes a free
slot rather than slot 1 (`:2358`), and a guest's sister comes by SISTER.

**Built in Phase 1.** Dead and dividing need telling apart, so the field has
two flags: `in_water`, and `anchored` for "has a body". The run's calls are
`leave_water(dead)` and `enter_water()`, the second being exactly the organ
reset above; `place_sister()` is the free-slot sister for either player. A kill
the field makes itself in a pond -- the host's cell swallowed, chewed or
poisoned -- clears both flags in the frame it happens, and that frame goes on
for everybody else: nothing below the kill touches a cell that is out of the
water, because everything that would asks `in_water` first. The person out of
the water is simply unseeded, which is how every sense, mouth and push skips
them without a second test.

### 1.6 Arriving

The host decides where. The arrival is `SISTER_DISTANCE` (560) along the world
horizontal from the friend, or from where the friend last was if they are dead. It
takes the first side clear by `r + r_body + 20`, then 30° steps round the circle,
and drops to 480 if `shared-pond-ux.md` §9.3 fails at 1280x720. That is inside
every tier's ping range (1,100 at tier 1). The arrival gets
`first_hunt := FIRST_DELAY`, as every `setup()` grants in single player, and
nothing is reseeded.

The exchange: the guest sends PERSON and then ENTER(radius); the host adds the
person and replies ARRIVE(position, heading). If the pond is already open when
the guest's run starts, the run begins held (no simulation, no seeding) for that
round trip, and opens solo if no ARRIVE comes within `REACH_TIMEOUT` (4 s). A
guest already swimming solo when the pond opens swaps in at the next ordinary
frame (not dead, dividing or in the menu) with the §0.5 beat: `become_mirror()`,
place the cell, `motes.setup()`, keeping body, genome, generation and hunger.

### 1.7 Pause (B)

While a session is up, pause never sets `get_tree().paused`, on either seat. That
is wider than the UX's "while a friend is in the pond", on purpose: the host's
water must keep running to take a dead friend back, and a guest's paused tree
would stop its own reports. `_menu_open` replaces the four `paused` reads
(`normal_mode.gd:551, 1799, 2013, 2143`). `cell.steering_off` silences
`_read_steer`, `_pushing` and the dash (`cell.gd:837-884`), because the arrows
also move menu focus. `_step_arming` runs from the live branch, the strip
rebuilds on `eaten`, and a division or a death closes the menu. Hunger keeps
burning, and a held sample's 45 s clock keeps running.

**`steering_off` does not stop `_unhandled_input` claiming a pointer** (found in
the Phase 0 review; the docstring now says so). A finger that goes down on the
water while the menu is up is still claimed, by the floating stick or through
`controls.press()`, and steers the moment the flag clears. So Phase 2 calls
`cell.release()` and `controls.let_go()` every time it flips the flag, both
ways -- the pair the pause screen and a lost focus already call.

### 1.8 Quiet and gone

| | host's screen | guest's screen |
|---|---|---|
| guest quiet (STATE stops) | its body coasts under `DRAG` along `p₀ + v₀(1−e^(−0.74t))/0.74` (`multiplayer.md` §5.4) and stops; still edible, still biting | — |
| host quiet for `PEER_FRESH` (1.2 s) | — | held: `_set_simulating(false)`, `_hush()`, dim 0.22, steering dead; resumes on the next snapshot |
| link gone | the person is removed | takeover: `leave_mirror()` is `setup()` behind the §0.5 beat, keeping body, genome, generation and hunger |

The host's coast is the field's own, built in Phase 1: `place_person()` takes
the reported velocity and turn rate, and between reports the field carries the
body on the closed form -- the place to rest, the heading for at most 0.2 s. A
mirror carries every body, the person included, for at most 0.2 s past its
snapshot and then holds it.

Measured on loopback: a clean close reaches the far end in 6-7 ms, so a host
pressing Leave releases the guest at once. A host whose main loop stops is dropped
by ENet after 5.68 s (warm RTT, defaults). Longer waits and rejoining are Phase 4.

## 2. The wire: PROTOCOL 4

**STATE** runs both ways and stays 31 B at 20 Hz. It gains two flag bits: bit 1
`OUT` (alive, but out of the water) and bit 2 `POND` (the host's pond is open, or
the guest is swimming in it). The host ignores a guest's positions until that
guest's `POND` bit is set.

**POND** (`KIND_POND 0x06`, host → guest) is unreliable and drained to the newest
by sequence, as `_take_state` does. Header, 8 B: `kind | seq u32 | your_wound u8
(/255) | count u8 | reserved u8`. Each body, 18 B: `slot u8 | serial u16 | meals
u8 | flags u8 | x f32 | y f32 | heading u8 | radius u16 (/64) | wound u8 (/255) |
speed u8 (×2 u/s)`. Flags: bit 0 stalking you, bit 1 person, bit 2 person in
water. A person adds `vx f32 | vy f32 | turning f32`.

These are exactly the fields the guest reads:

| field | used by |
|---|---|
| position, radius | every perception loop |
| the cytostome tier, from GENOME | `_gape`, for dread and the chew term |
| heading, tiers, wound, gape | `vision.gd` and the recorder |
| serial, meals | the recorder's change signature (`recorder.gd:422`) and the genome key |
| the stalking bit | `hunter()`, and through it vision's rings and `AT_HUNTER` |
| speed | the carry |

`drifter` and all AI state stay on the host.

**The send set** is every body whose surface lies within 1,900 of the guest, the
reach of a tier-3 ampulla measured to the target's surface (`food.gd:2013`).
Scent (1,600), dread (1,400), beams (1,240) and the frame all lie inside it.
**Plus every body hunting the guest, wherever it is** (Phase 1): a hunt
acquired from 1,900 can fall behind a fast guest, and without it the mirror's
`hunter()` would read -1 where the host's reads a body. `food.gd`'s
`pond_entries()` builds the set and `apply_pond()` reads it. The one field the
mirror does not reproduce is `threat`, a maximum taken over every body at any
distance; only the dev harness reads it.

**The budget.** At most 68 cells plus the host is ≤ 1,262 B: one ENet datagram
under the 1,392-byte MTU, never fragmented. With the players together, about 45
bodies make ≈ 850 B. At 20 Hz that is ≤ 25 KB/s (≈ 207 kbit/s) worst case and
≈ 17 KB/s typical, on the 20 Hz reasoning of `net_session.gd:71-96`, unchanged.

**Events** are reliable and in order, like `SHOUT`:

| type | direction | payload | bytes | when |
|---|---|---|---|---|
| `ENTER 0x02` | guest → host | radius f32 | 10 | run start with the pond open, a tap on the black, a swap |
| `ARRIVE 0x03` | host → guest | x, y f32, heading u8 | 15 | the reply to ENTER |
| `PERSON 0x04` | both | new-body u8, worn tiers, worn order | ~100 | arrival, birth, any change of the worn signature |
| `GENOME 0x05` | host → guest | slot u8, serial u16, meals u8, tiers | ~60 | once per body version entering the send set |
| `CONTACT 0x06` | host → guest | what u8, x, y f32, level f32, by u8 (water or friend), gene if `ATE` | 20-37 | `WAKED`, `BITTEN`, `STUNG`, `DARTED`, `ATE`, `KILLED` |
| `DIED 0x07` | both | cause u8 (swallowed, chewed, starved, poisoned), by u8, x, y f32 | 16 | the sender's own death, for the friend's lines and drawing |
| `SISTER 0x08` | guest → host | x, y f32, heading u8, radius f32, tiers | ~70 | the guest's commit |

**Genomes go by name, never index-packed** (`multiplayer.md` §4.7). Tiers are
`u8 count`, then per gene `u8 len | ASCII name | u8 tier`; the order is `u8 count
≤ 7`, then per slot `u8 len | name`, length 0 for an empty slot. The decoder
refuses the whole message on more than 8 genes, a name outside 1-16 bytes of
`a-z`, or a non-finite float; tiers clamp to 0..3. An unknown name draws in the
fallback hue and is inert in every rule, the shipped retirement behaviour
(`food.gd:160-169`). The host tracks the version sent per slot with the
recorder's signature, `serial*1000+meals`; an arrival bursts ≤ 68 × 60 B once.

**An old peer** on protocol 3 is refused at HELLO or WELCOME, by both sides, with
"different versions" and `_skew_says` (`net_session.gd:641-719`), exactly as 1 and
2 are. The three-byte prefix is untouched.

## 3. The changes, by file

**`food.gd`**
- [x] `PERSON_SLOT`, `POND_SLOTS := 2 * COUNT + 1`, inner `Person`; `Body` gains
  `person`, `speed` (written where bodies move) and `order` -- and `tuned`,
  which player's water a cell was made for.
- [x] `open_pond()` (grows `_cells` unseeded; never called solo),
  `place_person()`, `remove_person()`, `set_person_genome()`, `in_water` -- and
  `anchored`, `leave_water()`, `enter_water()`, `set_person_in_water()`,
  `set_person_quiet()` and `place_sister()` (§1.5). Every loop over the water
  runs `range(_water)`, which is every slot solo and all but slot 68 in a pond.
- [x] §1.2-§1.3, one function per rule: `_look_for_prey`, `_predict` (through
  `_lead`), `_reference_speed`, `_target_present` and `_target_edible` ask a
  person what they ask this cell; `_felt_hunting` is the wake and the dart for
  either; `_contacts_with(p)`, `_bitten_by` and `_bite_from` are one pass and two
  chews for either player; `_players_meet` is the last row. Outcomes leave as
  signals: `person_touched(what, at, level, by, gene)`, `person_died(cause, by,
  at)`, with `Contact`, `Cause` and `By` numbered for the wire.
- [x] §1.4's recycle: `_retire`, `_seed_for(i, anchor)`, and `put_sister` into a
  free slot.
- [x] Mirror mode: `become_mirror()`/`leave_mirror()`; `apply_pond()` carries
  each body by `speed` along its heading (≤ 0.2 s) and the person by the closed
  form; `apply_genome()`; `hear_contact()` emits the shipped signals with
  `_cell.bearing_to(at)`; the stalking bit sets STALK and `TARGET_PLAYER`;
  `_process` skips `_step_body`, the recycle and contacts, and runs the local
  half of `_step_separate` and the four organ steps. The host's side of it is
  `pond_entries(for_person)`, which builds the snapshot. A slot a snapshot
  leaves out leaves the mirror's water and its hunt with it, so the mirror's
  `hunter()` never names a body the host has retired.
- [x] Phase 0 pre-checks, each skipping only pairs the full test rejects:
  `_look_for_prey` tests distance, and `d < best`, before `_worth_committing_to`,
  written as the negation of the acceptance it replaces; the contact pass tests
  the squared `(mouth_reach + gape·MOUTH_BITE + widest radius)·1.001 + 0.01`
  before `_mouth_reaches`; `_step_separate` skips
  `distance_squared_to() > ((r + widest)·1.001+0.01)²`, one bound per body rather
  than `(r₁+r₂)` per pair. A NaN radius makes every bound NaN, which skips nothing.
- [x] Phase 1: **the contact bound is structural.** Every seed, retirement and
  meal bumps `_changes`, and after any contact that moved it the pass finds the
  widest body again by a whole scan and rebuilds its bound, so no rule added
  later can leave a stale one behind. The players' contact pass got the same
  kind of pre-check -- the larger of the player's own bound and the widest
  body's at the widest gape any tier opens -- re-made whenever the player's
  radius or `_changes` moves.

**`normal_mode.gd`**
- [ ] Build `_pond` in `_ready` when there is a session, and call `_pond.step()`
  before the early returns: intake runs while dead, dividing or held.
- [ ] `_set_simulating` per §1.5; `_die` sends DIED; `_on_pulsed` is gated on
  `in_water`.
- [ ] `_wake_up` and `_be_born` skip `setup()`. A return goes through §1.6; a
  birth sends the sister (locally, or by SISTER) and PERSON.
- [ ] Pause per §1.7, with UX §6's `SCRIM_POND` and `Warn`.
- [ ] The held pond, takeover, swap and lines (UX §0.4, §0.5, §1, §5).
- [ ] The division dims from the pinch (UX §2).
- [ ] `_offer_replay` is off while a pond is up, until Phase 3.

**`game/net/pond.gd`** (new; RefCounted, preloaded, no `class_name`, no node)
- [ ] Host: carry the guest's newest STATE into the person; every
  `STATE_PERIOD`, pick the send set, build POND and send GENOME by version;
  forward `person_touched` as CONTACT and `person_died` as DIED; handle ENTER,
  PERSON, SISTER and DIED.
- [ ] Guest: apply the newest POND; drain GENOME and CONTACT into the mirror;
  send PERSON on a signature change; hold at `quiet_for() ≥ PEER_FRESH`; take
  over when the link goes.

**`net_session.gd`**
- [ ] `KIND_POND` intake, newest by sequence, via `peer_pond()`.
- [ ] `drain_pond_events()`, `send_pond()` and a generic `send_event()`.
- [ ] `OUT`/`POND` in `report_body()`, plus `peer_pond_open()` and
  `peer_in_water()`.
- [ ] POND unreliable in `_mode_for`.

**`wire.gd`**
- [ ] `PROTOCOL := 4`, with a paragraph in the style of 2 and 3.
- [ ] Encoders and refusing decoders for POND, the seven events and both codecs.

**`vision.gd`**
- [x] Phase 0: `_draw_cells` skips bodies farther than `½·diagonal + 4r + 32`
  from the middle of `$Frame`, found through `$World`'s own transform, which is
  the camera whenever the two agree. The haze reaches 3.05 r counting the
  filter's last texel, and `mouth_reach` bounds the lip bow at 3.06 r; searched
  over every tier-3 organ, the lip tips reach 1.87 r and the flagellum 2.18 r.
- [ ] In a pond, `_draw_cells` skips slot 68. `_draw_peer` draws it with real
  tiers, order, gape, wound and `double`, `is_self` false and `untinted` true.
- [ ] Presence fades with `quiet_for()`; no doubt ring; the ghost at 0.34
  (UX §0.1-0.3). `peer_track()` is not drawn in a pond.

**What Phase 1 found that Phase 2 has to do**
- `vision.gd`'s `_draw_thresholds` rings the nearest body in `points()`, and a
  retired slot keeps its last place: skip unseeded bodies there. (`_draw_cells`
  draws nothing at radius 0, and a mirror's unsent slot now has radius 0 too:
  the Phase 1 review found `apply_pond` left a dropped body's radius behind, a
  ghost in the guest's full vision, and `pond-field` now checks it.)
- `returns.gd` hides its marks while `_food.is_processing()` is false; in a pond
  the field keeps processing through a death and a division.
- `_die` calls `_food.leave_water(true)` instead of stopping Food. For the kills
  the field makes itself it has already done so, in the same frame.
- DIED carries a fourth cause, `POISONED`.
- Flipping `cell.steering_off` calls `release()` and `controls.let_go()` (§1.7).
- **The host cannot learn its own cause of death.** `signal killed` carries
  only a bearing, and `hear_contact(KILLED, ...)` is how the field kills the
  host; DIED needs swallowed, chewed or poisoned, and only the person gets a
  cause today, through `person_died`. Give the local cell one.
- **Probe the deviations before DIED is wired to them.** `_pond_friends` does
  not exercise §1.3's venomous friend or chewing to death between players; the
  Phase 1 review ran six such cases by hand, all correct (a host swallowing a
  venomous friend dies and stings it; the reverse poisons the friend; either
  chews the other to death with the meal and cause right; the eater's death is
  checked first). Make them checks.
- **Decide the `bitten` bearing's order.** `_bite_from` now works out BITTEN's
  bearing after the run's `eaten` handler, where main worked it out before. It
  is identical today because no `eaten` listener moves or turns the cell, and
  the gate is blind to it (`field_diff`'s `growing` handler never moves the
  cell; a variant that turns it 0.05 rad fails 269 checks, all this bearing).
  Capture the bearing before the ATE event when there is no person, or say on
  `signal eaten` that listeners must not move or turn the cell.
- **From Phase 1 on, each tree runs its own `tools/` in the gate.** The branch's
  `drive.gd` references `FoodField.PERSON_SLOT` and no longer parses over main's
  `food.gd`; Phase 0's "branch tools over main's game" recipe hangs there.

**Elsewhere**
- [x] `cell.gd`: `swim_speed_of` and `steering_off`; Phase 1 corrected the
  latter's docstring, which claimed it silenced every input.
- [x] `cilia.gd`: a trailing `untinted := false` (UX §8).
- [x] Phase 1, tools: `net_probe.gd`'s socket-free `pond-field` section;
  `drive.gd --pond=` (a held person and two rings, for `--field-cost`); and
  `tools/field_diff.gd`, the differential half of the identity gate, against
  `main`'s `food.gd` on adversarial water.
- [ ] Phase 3, `recorder.gd`: `BODIES := FoodField.POND_SLOTS` (+3.0 MB on a
  4.6 MB ring) and `AT_PERSON`.
- [ ] Phase 3, `replay.gd`: private nodes in a pond. `restore_body` writes a
  radius without bumping `_changes`, which is safe only because the replay
  calls it with the field stopped; the sandbox must keep that true, or bump.

## 4. Host cost, measured

**Method.** A scratch harness, not committed, drove `food.gd` directly. The cell
was tier 1 with a nose and an ampulla, radius 30. Each run was 3,600 frames at
1/60 s after 240 frames of warm-up, over several seeds. For two rings, a subclass
seeded 35 more cells round a second anchor and culled against the nearer of the
two. The whole-run rows instanced `normal_mode.tscn` with that `Food` and read
`Performance.TIME_PROCESS` headless over 1,800 frames. The pre-checks and the cull
are as §3 specifies them.

| per frame, this container | one ring (34) | two rings (69) |
|---|---|---|
| `food.gd` `_process`, shipped | 848-1,055 µs | 2,850-3,620 µs (≈ 3.3×) |
| prey search / contacts / separation / senses | 214-260 / 351-431 / 187-200 / ~105 µs | 704-908 / 1,203-1,682 / 748-778 / ~200 µs |
| with the Phase 0 pre-checks | 655-715 µs | 1,844-2,176 µs |
| whole run, point of view, p50 | 1.46 ms | 3.57 ms |
| whole run, full vision, p50 | 8.1-9.7 ms | 14.3-20.3 ms |
| whole run, full vision, p50, with the cull | 7.9 ms | 7.8 ms |

**Both fixes are exact.** With the pre-checks on and off, the whole field and the
cell ended bit-identical after 3,600 frames on every seed tried: three at one
ring, two at each two-ring shape. For the cull, three baseline renders under
`--seed=7 --mode=1` diffed to 0 pixels at each shape, and the culled frames then
showed **0 differing pixels** against them at 1280x720 and 2400x1080, with edible
bodies parked so their haze straddled the frame's edge and corner.

**What this means for a phone host.** Without Phase 0, the pond roughly doubles
the host's full-vision frame, and almost all of that is drawing bodies nobody
sees. With it, the host pays 1.2-1.5 ms a frame more than solo on this Xeon. The
guest pays less than solo: no AI, no contacts, and perception over at most 69
bodies. No phone was measured, so only the ratio transfers. Windows stays the
recommended host (`multiplayer.md` §4.2), and Phase 2 is not accepted until a pond
has been played with a phone as host.

## 5. Phases

Each phase is one PR that ships playable. Each must also pass the **single-player
identity gate**, which is the method #50 and #51 used, with no session:

1. **Fingerprint.** `drive.gd --seed=S --mode=1 --scheme=0 --fingerprint=10800`,
   and the same with `--radius=30
   --genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:2,ampulla:2,stigma:1
   --sniff --fingerprint=7200`, headless at `--fixed-fps 60`, for S = 7, 12345
   and 2026: the same line on `main` and the branch. The flag counts frames, and
   the line counts what was exercised. 10,800 is the first whole minute by which
   every seed's plain run has eaten; nothing hunts the player before
   `FIRST_DELAY` (42 s) and a born cell's water seldom seeds a mouth that fits it,
   so the sighted forager is the run in which the player is hunted, bitten and
   killed. `--mode` and `--scheme` are pinned because both are otherwise read
   from `user://`, which every run on the machine shares. Phase 0 adds the flag,
   so for that PR only, run the branch's `tools/` over `main`'s `game/` in a
   worktree. `tools/` never ships.
2. **Renders.** `shot.tscn` → `drive.tscn --seed=7 --freeze-at=9.0 --wait=10.5
   --mode=M --scheme=0`, with `--fixed-fps 60` before the `--`, in modes 1 and 0,
   at 1280x720 and 2400x1080. Three runs of `main` must first diff to 0 pixels;
   then the branch against `main` must diff to 0 pixels.
3. **Sensations.** The same drive run, headless, prints every bus sensation, and
   the `diff` of the branch against `main` is empty. `drive.gd`'s own log leaves
   out `taste` and `shear` and rounds to two places, so Phase 0 also diffed every
   `sensation` the bus emitted, at full precision, through a listener that is not
   committed.
4. **The probe.** `net_probe` reports `ALL PASS`. Its 95 existing checks are
   superseded only by name, and only in the same PR.
5. **The differential test** (from Phase 1). `git show
   main:game/normal/food.gd > /tmp/food_main.gd`, then `godot --headless --path
   . -s res://tools/field_diff.gd -- --old=/tmp/food_main.gd`: `main`'s field and
   the branch's, side by side on adversarial water -- NaN and infinite radii, a
   NaN place, a whale, a wounded pack, a cell its own `eaten` handler grows
   mid-pass -- compared after every call on every member both have, and it
   prints `ALL EQUAL`. The fingerprint holds whole runs to the bit; this holds
   every function to it on water no run would make, which is where a bound that
   skips one real contact in ten thousand pairs shows up.

**Phase 0 — cheaper frames.** No wire and no behaviour change.

- *Contents:* the pre-checks, the cull, `swim_speed_of`, `steering_off`,
  `untinted`, and `drive.gd --fingerprint=` and `--field-cost=`.
- *Accepted when:* the gate passes; the cull pair diffs to 0 pixels at both
  shapes, with bodies straddling the edge (§4); and one ring measures
  `--field-cost` ≤ 750 µs.
- *Built, and measured here:* `--field-cost=3600` at `--radius=30`, tier 1
  with a nose and an ampulla, three seeds twice over, went from p50 779-812 µs
  and p90 914-1,049 µs on `main` to p50 569-593 µs and p90 663-714 µs. Full
  vision draws 9 of the 34 bodies a frame at 1280x720 and 13 at 2400x1080, and
  the whole run's `TIME_PROCESS` p50 in full vision fell from 8.5-10.0 ms to
  4.9-6.4 ms, a noisy figure on this container. The cull pair parked twelve
  edible bodies so that, at each shape, their hazes straddle all four edges and
  two corners, a different two at each; culling by centre instead loses 6,885
  and 29,265 pixels at the two shapes, and the built cull loses none.

**Phase 1 — the field learns a second player.** No wire.

- *Contents:* §1.2-1.5 and the mirror API, called only by tools.
- *Accepted when* the gate passes and a socket-free `pond-field` section in
  `net_probe` (one host field with a probe-driven person, and one mirror fed that
  field's own entries) shows: a committed cell swallows the person and an
  uncommitted one only bites; chew damage equals `bite_damage` for that gape,
  pellicle and flank, with venom back on the biter; between players an armoured
  fit swallows with no commitment and chewing works both ways; slot 68 never
  reaches `_seed` or `_devour`; anchors 4,000 apart each hold ≥ 34 after 10 s, and
  anchors 300 apart ≤ 40 active after 60 s together; every disc keeps a drifter
  every frame, no seed lands within `RING_MIN`, and ties alternate; with
  `in_water` false no stalker targets the local cell a frame later while the
  water keeps stepping, and a person out of the water is neither perceived nor
  bitten; the mirror returns the same `taste_level`, `dread_level`, `shadow`,
  `touch_level`, beams, ping returns and `hunter()` as the field, within 1e-6;
  and `--field-cost` with a person and two rings is ≤ 2.3 ms.
- *Built, and measured here:* all six gate fingerprints are identical to
  `main`'s; `tools/field_diff.gd` made 1,677,704 checks over 32,002 adversarial
  trials and 270 runs of 600 frames with 0 mismatches (the last 320,580 on the
  final file), and it fails the two mutants that break the new bounds (the
  water pass without its rebuild, 5 of 45,858 checks; the players' bound
  without the water's mouth, 818 of 5,497). Main's three renders diff to 0
  pixels at each shape and view, and the branch to 0 against them in all four;
  every bus sensation is identical at full precision, in the 9 s run above and
  in 120 s of the sighted forager at seeds 12345 and 2026 (1,008 and 1,383
  sensations, a death in each). `net_probe` passes 118 checks, 23 of them
  `pond-field`: 2,234-2,239 frames and 24.0-24.7 s against `main`'s 2,237 and
  16.2 s, the section spending 7.8-8.4 s and no frames. The section also passes
  whole with every seed in it shifted, forty shifts over, which is the nearest
  this container comes to another machine's arithmetic. The mirror agreed with
  the field to 0.0, not merely 1e-6, over 600 frames with a hunter on it
  throughout, in all forty-one. `--field-cost=3600 --pond=4000` at
  `--radius=30`, tier 1 with a nose and an ampulla, three seeds twice: p50
  1,674-1,884 µs and p90 1,846-2,136 µs. One ring got cheaper, p50 571-589 on
  `main` to 533-558 µs, from the new pre-check on the player's own contacts.

**Phase 2 — one water on the wire.** PROTOCOL 4, and the playable pond.

- *Contents:* §2, `pond.gd`, the lifecycle, and UX §0-§8. `drive.gd` gains
  `--pond=host|guest`, `--friend=dist,bearing` and
  `--friend-state=out|dead|quiet|held`; the far seat is a second real run with
  hidden canvas layers. `net_lag` gains `--pond`. The replay stays withheld.
- *Accepted when* the gate passes and `net_probe`, with two sessions and two real
  runs, shows: PROTOCOL 4 completes and 1, 2 and 3 are refused by name; the guest
  arrives 560 ± 1 from the host; every host body within 1,900 (surface) is
  mirrored within 1 unit, none farther, each with its (serial, meals) genome; a
  posed committed hunter swallows the guest (DYING within 0.2 s, slot 68 empty on
  the host that frame); a posed chewer's `hit` lands at the true bearing
  ± 0.05 rad and the wounds agree within 1/255; a guest meal shows +4 on the host
  within 0.2 s, and either player can eat the other; snapshots advance through
  3 s of the host's black (A) and its return lands 560 from the guest; from both
  seats a divider is gone from every sense from the pinch, the water advances
  through 5 s of choosing, and the divider returns where it left at r28.28, the
  sister in a free slot and no other serial changed; `paused` stays false on both
  seats (B), KEY_D with the menu up leaves `steer` at 0, and a posed hunter still
  eats that cell; host polling stopped 3 s holds the guest from 1.2 s, then it
  resumes; and a closed host means takeover within 0.1 s, keeping radius, genome,
  generation and hunger, in 34 fresh cells.
- *Renders:* UX §9 items 1-6, both seats, both views, both shapes, judged rather
  than diffed (loopback timing is not reproducible).
- *Timing,* `net_lag --pond` on loopback and simulated Wi-Fi (10-50 ms jitter,
  2 % loss): water cells within 2 units of the truth at p99 and the host's cell
  within #51's figures; bite to `hit` ≤ 60 ms loopback, ≤ 150 ms p99 Wi-Fi; POND
  ≤ 1,262 B; the host's `--field-cost` with a guest in.
- *Then* two phones for thirty minutes, the host on a phone, watching for dropped
  frames and for `godotengine/godot#105726`.

**Phase 3 — the replay in a pond.** No wire.

- *Contents:* the recorder takes 69 slots and `AT_PERSON`, `replay.gd` binds
  private Cell, Motes, Food and Genome nodes in a pond, and the offer returns.
- *Accepted when* the gate passes, plus a single-player replay render
  (`--kill-at=`, then watch) at 0 pixels; `net_probe` shows the water advancing
  while a dead host watches, with the replay's Food not the run's; UX §9.7
  renders; and `--capture-cost` is printed (expect about 2×).

**Phase 4 — waiting and rejoining.** PROTOCOL 5; §6 rows 4 and 5.

- *Contents:* `ENetPacketPeer.set_timeout` pinned at greeting; a 4-byte rejoin
  token on the HELLO and WELCOME tails, so a returning guest replaces its own
  stale peer instead of meeting `REFUSE_FULL` (`net_session.gd:657-659`); `BYE`
  on leaving; a re-dial every 5 s after a takeover, and at once on waking, seen as
  a wall-clock gap of more than 2 s between frames (UX §5).
- *Accepted when* `net_probe` shows: a host stopped 3 s leaves the guest held,
  then back; stopped past the pin, takeover within it ± 0.3 s; restored, the
  guest back within 5 s keeping its cell; Leave, takeover in < 0.2 s and no
  re-dial; a tokenless HELLO while the guest is quiet gets "already two"; and
  protocols 1-4 are refused by name.

**Later, the owner's phase:** genes decide one bite or chewing, for every cell
(`roadmap.md`).

## 6. Owner decisions

**All five answered on 2026-09-23, each as recommended.** Together the water holds
what one of you would meet alone; new cells take turns between the two tunings;
the hunting-only swallow stays for both players until the gene phase; a quiet
phone is waited for about 8 s, the same every time; and a dropped pond rejoins
by itself. Rows 4 and 5 are `shared-pond-ux.md` §10's; this side's technical
notes follow the table.

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | When you swim together, is the water twice as busy? | **no, the same number of cells one of you would meet alone ✓ answered** / yes, each of you brings your own | No: together you share the food and the danger. Yes: twice the food and twice the hunters, and every sense reads busier than it was tuned for. |
| 2 | Swimming together, whose difficulty is the water? | **each new cell is made for one of you, taking turns ✓ answered** / always the newer cell's / always the stronger cell's | Turns: a veteran and a newcomer meet a mix. Newer: a veteran can shepherd a friend through easy water, and farm it. Stronger: a newcomer who sticks close meets water sized for the veteran. |
| 3 | A water cell can swallow you only while it is hunting you, but can swallow another water cell by accident. That is the one exception to "the same rule". What happens to it? | **keep it for both of you until the gene phase, which makes one rule for every cell ✓ answered** / fix it now for every cell: nothing swallows by accident / drop it now: you can be swallowed by accident too | Keep: something always came for you first, and you felt it; the exception is settled with the other gene-phase rules. Fix now: water cells stop swallowing each other by accident, which changes solo play a little. Drop: a big cell drifting into you can swallow you with no warning. Between the two of you there is no hunting either way: a friend's mouth on you is enough, and your only warning is dread. |
| 4 | How long does the pond wait for a quiet phone? (UX row 1) | **about 8 seconds, the same every time ✓ answered** / 30 seconds / 2 minutes | While the host's phone is quiet, the guest's water is held. While the guest's is quiet, their cell drifts and can be eaten. When the wait ends, the guest swims on alone. |
| 5 | When a dropped friend's water comes back, swim together again? (UX row 2) | **yes, automatically ✓ answered** / no, call again | Yes: the guest arrives in the host's water again, keeping their cell. No: a dropped pond is over. |

**Row 3** is the one player special case in today's rule (§0.5). "No player
special case" cannot remove it without changing single player, so it is asked
rather than assumed.

**Row 4 is one line either way.** "Until the connection gives up by itself" is
5.7 s on a warm LAN (measured) but 5.4-31.5 s in general (`multiplayer.md` §3),
so it is never the same wait twice. `ENetPacketPeer.set_timeout` sets it from
content, per connection. Measured: asking for 2 s gave 1.74 s, 10 s gave 10.93 s,
and 30 s gave 42.4 s, because ENet checks only on its doubling resend schedule.
So pin it, or cut at an exact second from `quiet_for()`.

**Row 5** costs about 120 lines and a protocol bump for the token. It is worth
more because of `godot#105726`, which drops LAN links at random: only a rejoin
heals that.

## 7. Risks

- **Content skew under one protocol.** The host's tables govern contacts, while
  the guest perceives with its own. A pack that changes `GAPE_BY_TIER` or
  `ARMOR_BY_TIER` without a bump makes the guest's membrane misjudge danger.
  Phase 2 should refuse on a hash of the ladders the contact rules read, sent on
  the HELLO and WELCOME tails, so that skew becomes a sentence and not a lie.
- **Android backgrounding stops the pond** for both players. Nothing in content
  fixes it (`multiplayer.md` §3; a foreground service is a binary change), so
  the held pond and the takeover are the whole mitigation.
- **Phase 2 is large.** Its silent failure is a mirror that disagrees with the
  host, which is exactly what Phase 1's mirror-equality check and Phase 2's
  mirror-error check exist to catch.
- **CI's frame budget.** `net_probe` runs under `--quit-after 20000` at 500 fps.
  If the pond sections push it past about 35 s, `ci.yml` has to change in the
  same PR, and that is the lead's call. Phase 1's `pond-field` spends none of
  it: the section never awaits, so its 7.8-8.4 s pass inside a single frame, and
  the probe still ends near 2,237 frames, now in 24.0-24.7 s. A Phase 2 section
  that waits on frames is the one that will spend the budget.
