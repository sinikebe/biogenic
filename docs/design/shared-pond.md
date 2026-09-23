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

### 1.5 Leaving the water does not stop it

In a pond, `_set_simulating(false)` stops Cell, Metabolism, Motes and Genome,
but not Food. Food instead gets `in_water = false`, which skips the local cell's
contacts, separation and targeting, and its four organ steps, so a dead or
dividing cell never pings or shouts. A player out of the water is still an
anchor, so what a daughter comes back to is still there (`shared-pond-ux.md` §2);
a dead player is not. `_be_born` resets only the local organ state that `setup()`
resets today: clocks, pulses, echoes and `first_hunt`. `put_sister` takes a free
slot rather than slot 1 (`:2358`), and a guest's sister comes by SISTER.

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

### 1.8 Quiet and gone

| | host's screen | guest's screen |
|---|---|---|
| guest quiet (STATE stops) | its body coasts under `DRAG` along `p₀ + v₀(1−e^(−0.74t))/0.74` (`multiplayer.md` §5.4) and stops; still edible, still biting | — |
| host quiet for `PEER_FRESH` (1.2 s) | — | held: `_set_simulating(false)`, `_hush()`, dim 0.22, steering dead; resumes on the next snapshot |
| link gone | the person is removed | takeover: `leave_mirror()` is `setup()` behind the §0.5 beat, keeping body, genome, generation and hunger |

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
| `DIED 0x07` | both | cause u8 (swallowed, chewed, starved), by u8, x, y f32 | 16 | the sender's own death, for the friend's lines and drawing |
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
- [ ] `PERSON_SLOT`, `POND_SLOTS := 2 * COUNT + 1`, inner `Person`; `Body` gains
  `person`, `speed` (written where bodies move) and `order`.
- [ ] `open_pond()` (grows `_cells` unseeded; never called solo),
  `place_person()`, `remove_person()`, `set_person_genome()`, `in_water`.
- [ ] §1.2-§1.3, one function per rule. Outcomes leave as signals:
  `person_touched(what, at, level, by, gene)`, `person_died(cause, by, at)`.
- [ ] §1.4's recycle: `_retire`, `_seed_for(i, anchor)`, and `put_sister` into a
  free slot.
- [ ] Mirror mode: `become_mirror()`/`leave_mirror()`; `apply_pond()` carries
  each body by `speed` along its heading (≤ 0.2 s) and the person by the closed
  form; `apply_genome()`; `hear_contact()` emits the shipped signals with
  `_cell.bearing_to(at)`; the stalking bit sets STALK and `TARGET_PLAYER`;
  `_process` skips `_step_body`, the recycle and contacts, and runs the local
  half of `_step_separate` and the four organ steps.
- [ ] Phase 0 pre-checks, each skipping only pairs the full test rejects:
  `_look_for_prey` tests distance before `_worth_committing_to`; the contact pass
  tests the squared `(mouth_reach + gape·MOUTH_BITE + widest radius)·1.001 + 0.01`
  before `_mouth_reaches`; `_step_separate` skips
  `length_squared() > ((r₁+r₂)·1.001+0.01)²`.

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
- [ ] Phase 0: `_draw_cells` skips bodies farther than `½·diagonal + 4r + 32`
  from the camera. The haze reaches 3 r and the lip bow 3.06 r.
- [ ] In a pond, `_draw_cells` skips slot 68. `_draw_peer` draws it with real
  tiers, order, gape, wound and `double`, `is_self` false and `untinted` true.
- [ ] Presence fades with `quiet_for()`; no doubt ring; the ghost at 0.34
  (UX §0.1-0.3). `peer_track()` is not drawn in a pond.

**Elsewhere**
- [ ] `cell.gd`: `swim_speed_of` and `steering_off`.
- [ ] `cilia.gd`: a trailing `untinted := false` (UX §8).
- [ ] Phase 3, `recorder.gd`: `BODIES := FoodField.POND_SLOTS` (+3.0 MB on a
  4.6 MB ring) and `AT_PERSON`.
- [ ] Phase 3, `replay.gd`: private nodes in a pond.

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

1. **Fingerprint.** `drive.gd --seed=S --fingerprint=60`, headless at
   `--fixed-fps 60`, for S = 7, 12345 and 2026: the same hash on `main` and the
   branch. Phase 0 adds the flag, so for that PR only, run the branch's `tools/`
   over `main`'s `game/` in a worktree. `tools/` never ships.
2. **Renders.** `shot.tscn` → `drive.tscn --seed=7 --freeze-at=9.0 --wait=10.5`,
   in modes 1 and 0, at 1280x720 and 2400x1080. Three runs of `main` must first
   diff to 0 pixels; then the branch against `main` must diff to 0 pixels.
3. **Sensations.** The same drive run, headless, prints every bus sensation, and
   the `diff` of the branch against `main` is empty.
4. **The probe.** `net_probe` reports `ALL PASS`. Its 95 existing checks are
   superseded only by name, and only in the same PR.

**Phase 0 — cheaper frames.** No wire and no behaviour change.

- *Contents:* the pre-checks, the cull, `swim_speed_of`, `steering_off`,
  `untinted`, and `drive.gd --fingerprint=` and `--field-cost=`.
- *Accepted when:* the gate passes; the cull pair diffs to 0 pixels at both
  shapes, with bodies straddling the edge (§4); and one ring measures
  `--field-cost` ≤ 750 µs.

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

Rows 4 and 5 are `shared-pond-ux.md` §10's; this side's technical notes follow the
table.

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | When you swim together, is the water twice as busy? | **no, the same number of cells one of you would meet alone ✓ recommended** / yes, each of you brings your own | No: together you share the food and the danger. Yes: twice the food and twice the hunters, and every sense reads busier than it was tuned for. |
| 2 | Swimming together, whose difficulty is the water? | **each new cell is made for one of you, taking turns ✓ recommended** / always the newer cell's / always the stronger cell's | Turns: a veteran and a newcomer meet a mix. Newer: a veteran can shepherd a friend through easy water, and farm it. Stronger: a newcomer who sticks close meets water sized for the veteran. |
| 3 | A water cell can swallow you only while it is hunting you, but can swallow another water cell by accident. That is the one exception to "the same rule". What happens to it? | **keep it for both of you until the gene phase, which makes one rule for every cell ✓ recommended** / fix it now for every cell: nothing swallows by accident / drop it now: you can be swallowed by accident too | Keep: something always came for you first, and you felt it; the exception is settled with the other gene-phase rules. Fix now: water cells stop swallowing each other by accident, which changes solo play a little. Drop: a big cell drifting into you can swallow you with no warning. Between the two of you there is no hunting either way: a friend's mouth on you is enough, and your only warning is dread. |
| 4 | How long does the pond wait for a quiet phone? (UX row 1) | **about 8 seconds, the same every time ✓ recommended** / 30 seconds / 2 minutes | While the host's phone is quiet, the guest's water is held. While the guest's is quiet, their cell drifts and can be eaten. When the wait ends, the guest swims on alone. |
| 5 | When a dropped friend's water comes back, swim together again? (UX row 2) | **yes, automatically ✓ recommended** / no, call again | Yes: the guest arrives in the host's water again, keeping their cell. No: a dropped pond is over. |

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
  same PR, and that is the lead's call.
