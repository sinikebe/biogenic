extends RefCounted
## The wire: every byte that crosses between two cells, and nothing else.
##
## **Designed for the WebSocket shape, shipped on ENet.** docs/design/
## multiplayer.md §4.10 is explicit about why: `websocket_multiplayer_peer.cpp`
## has no concept of a transfer mode or a channel, so a protocol written against
## ENet's 253 channels and three reliabilities is a rewrite the day anyone needs
## WSS on 443. So this format assumes the weakest transport of the two:
##
##   - **one ordered stream.** No channels, and nothing in a frame says how it
##     was delivered. Every frame here is still correct sent reliable-ordered.
##   - **state frames are idempotent and drained to newest.** Each carries a
##     sequence number; a receiver applies the newest it has and discarding the
##     ones behind it changes nothing. That is what makes a backgrounded phone's
##     burst of forty queued frames cost one apply instead of forty.
##   - **events are applied in order, each exactly once.** They are not
##     idempotent -- a shout heard twice is two shouts -- so they carry their own
##     sequence and a receiver never replays one.
##
## **Nothing in this file asks for a channel, a transfer mode or an unreliable
## send, and that is still true now that state frames go out unreliable.** The
## choice of delivery is made per frame *kind*, by the transport, in one
## function -- `net_session.gd`'s `_mode_for` -- and the bytes do not change with
## it. It is the second property above that makes the choice safe: a state frame
## lost on ENet is superseded by the next one fifty milliseconds later, and one
## that arrives late is dropped by its sequence. A WebSocket port has no modes
## at all -- `set_transfer_mode()` is silently ignored there -- so it sends every
## frame reliable-ordered, and these exact bytes are just as correct on it. The
## same bytes go through `WebSocketPeer.put_packet()` unchanged.
##
## **The three bytes that must never move.** Every handshake frame is
## `kind(u8) | protocol(u16 LE)`, and that prefix is frozen for the life of this
## game. Version skew is permanent and unbounded here (multiplayer.md §0.1:
## updates are opt-in, so a player can sit on a months-old pack for good), which
## means two builds that cannot agree on anything else must still be able to
## agree on *why* they are hanging up. Three bytes buys that forever.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.
##
## **It loads one file, the body plan** (`game/genes/body_plan.gd`, which loads
## nothing): how many genes and slots a genome crosses with are the plan's
## (docs/design/gene-catalogue.md §10.2), and follow it. Everything else it needs
## of the game is written out here, and the probe holds each copy to its source.

## **Bumped by hand, whenever the meaning of any byte below changes** -- and,
## since protocol 8, for nothing else: what a host judges a guest by and decides a
## contact by is the rules' fingerprint's to tell apart, on the handshake's tail
## ([constant RULES]).
##
## Never derived from `content_version`, which is `git rev-list --count HEAD`
## and moves on a docs-only merge -- two identical builds would refuse each
## other. multiplayer.md §8 names this specifically.
##
## **2: the state frame carries a body.** Protocol 1's state frame was six
## bytes of heartbeat; this one carries where the sender is, which way it
## points and how big it is, so the other screen can draw it. That is a change
## in the meaning of a byte, so the number moves -- a protocol-1 peer reads
## byte 6 of this frame as the start of nothing it knows and would have to
## guess. It never gets the chance: [method protocol_of] runs first and the
## handshake refuses it with a sentence.
##
## **3: the state frame carries how the body is moving, and it is sent twenty
## times a second.** Twelve bytes on the end -- a velocity and a turn rate --
## and a change of meaning in the rest: a protocol-2 receiver drew the newest
## place it had half a second late on purpose, and a protocol-3 receiver draws it
## now, carried forward along the motion that came with it. A build on 2 would
## read the new tail as nothing and draw a friend who never jumps on time, so
## the number moves and the handshake refuses it with the same sentence it
## refused 1 with. Both phones need the update; neither can be talked into
## playing half a game.
##
## **4: the two cells share one water.** shared-pond.md §2. The host's water
## crosses as a snapshot ([constant KIND_POND]) twenty times a second, every
## contact the host resolves crosses as an event, and the two cells tell each
## other who they are -- by gene *name*, never by index -- when they arrive,
## are born and die. The state frame's flag byte gains two meanings, `OUT` and
## `POND`, which is a change in the meaning of bits a protocol-3 build writes
## zero and ignores: a 3 would read a friend dividing as a friend swimming, and
## would never answer an ENTER at all. So the number moves, and 1, 2 and 3 are
## all refused by name, with the sentence that names the update.
##
## **5: the pond is the host's drop** (docs/design/ocean.md §10.4). A drop has
## more bodies than a byte counts and keeps each one for its life, so a POND
## entry is keyed on the body's id, a u32 that outlives any slot, where it was a
## slot and a serial; the send set is the sixty nearest and every hunter of the
## guest; flocs, which never move, are told once as they come into reach
## ([constant EVENT_SETTLE]) and once as they go ([constant EVENT_CLEAR]); an
## ARRIVE carries the drop's rim, and a CONTACT can say `GRAZED`. Every one of
## those is a change in the meaning of bytes a 4 writes and reads, and the drop's
## rules are the referee's too -- so the number moves with `RULES`, and a 4 is
## refused at HELLO by name, as 1, 2 and 3 are.
##
## **6: a guest's sister carries her DNA and her instincts**
## (docs/design/automation.md §10.3). A SISTER said where the declined daughter
## is left and what she wears, and nothing more, so a host's water made her of
## her body alone: a DNA equal to it and the founders' rules, where a host's own
## sister carries both. Now, after her body, it says the DNA she was made of --
## by name, as her worn tiers are -- and the list her cell ran, a line for each
## rule as `rulebook.gd` writes it, and the host reads those lines with its own
## vocabulary. A 5 refuses the longer SISTER as a frame no writer of its own
## produces, and the division it answers would go unanswered; a 5's shorter one
## is not a SISTER to a 6. So the number moves, and a 5 is refused at HELLO by
## name, as 1 to 4 are. **`RULES` does not move with it**: the referee judges
## her place and size as it always did, and nothing it judges by changed --
## any DNA and any list are ones evolution could reach and the page could build.
##
## **7: venom and poison, outside and inside** (docs/design/dna-slots.md §14.2).
## A body carries loads of a toxin that wear off, and the host decides every
## dose as it decides every contact: the POND header's spare byte becomes three,
## the loads the snapshot's recipient carries, and a body's flags gain three bits
## for the loads it carries, so a guest draws them and wears its own. A genome
## may now hold nine names -- seven outside, one inside and the gift's -- where
## a 6 refuses nine whole. And the bite tables changed: `VENOM_BITE_BACK_BY_TIER`,
## `VENOM_COST_BY_TIER` and `venom_back` are gone into the doses, which by the
## rule below moves this number on its own. A 6 would read a harmed body as one
## swimming and a guest's loads as a reserved byte, and refuse the genomes the
## inside makes; so a 6 is refused at HELLO by name, as 1 to 5 are. **`RULES`
## does not move with it**: the referee judges a guest's size, path, heading,
## arrivals, sister, body and death, and harm changes none of them -- the host
## owns the guest's wound and decides its death. `Cause.POISONED` and
## `Contact.STUNG`'s number are kept for the same reason.
##
## **8: the handshake carries the rules** (docs/design/gene-catalogue.md §11.3;
## the ladder hash shared-pond.md §7 planned). Every handshake frame gains a tail
## after its three frozen bytes: the fingerprint of the rules its sender judges and
## decides contacts by -- `game/net/rules.gd`'s, written from the catalogue: every
## judged and contact table, by every organ, the referee's limits, the contact
## rules and the body plan -- and its content version, which says which of two
## builds is older. Two builds on one protocol whose rules differ refuse each other
## at the handshake, with the sentence that names the update, by themselves. A 7
## reads a tail as nothing, as it reads anything up to [constant HANDSHAKE_MAX], and
## refuses an 8 by its prefix, as 1 to 6 are refused. **`RULES` moves with it**, for
## the lines the tail made room for: the contact tables and rules that a hand rule
## here bumped this number for until now, and the body plan.
##
## **So, from protocol 8, a change to what the referee judges, what the host decides
## a contact by, or the body plan bumps nothing here**: it moves the rules, and the
## handshake keeps builds on other rules apart. Move [constant RULES]' pin in the
## same commit, as `tools/net_probe.gd` says. This number moves only when a
## message's format does.
const PROTOCOL := 8
## **The rules a host's referee judges a guest by, and the host decides every
## contact by, fingerprinted -- pinned** (net-hardening.md B.2, B.6;
## docs/design/gene-catalogue.md §11.3): SHA-256 of `game/net/rules.gd`'s text,
## which the game writes out from the catalogue -- every table a stat row marks
## judged or contact, by every organ, the run's numbers the referee judges by, the
## contact rules no table holds, the referee's own limits and the body plan.
##
## **A host judges its guests by its own copy of these.** A guest on other rules
## would be fouled, then cut and barred: a later content that grows five units a
## meal instead of four was cut 1.05 s after its first meal by a host on the old
## one, measured. **Since protocol 8 that cannot happen**: the handshake carries the
## fingerprint the game works out ([method tail]), and a host refuses a guest on
## other rules before it is in the water, with the sentence that names the update.
##
## **This is the pin, not the value on the wire**: the game never reads it. It is
## here so that a change to the rules is made on purpose -- `tools/net_probe.gd`
## writes the text again from the real constants (`_rules_text`, run by
## `_referee_rules` in its `referee` section), holds the game's to it, and fails
## until this is moved, saying that no [constant PROTOCOL] bump goes with it. A build
## on new rules plays every build on its own rules, and none on the old ones until
## they update: that is what moving it means.
const RULES := "c382d53197f7a8c7ac885baf51caa5d6f674c9c3e7e966208c60159ca90d88fa"

# --- Frame kinds. Byte 0 of every frame. ------------------------------------
## Guest to host, first thing after the transport connects: *this is what I
## speak*. Three bytes, and the shape of them is frozen forever.
const KIND_HELLO := 0x01
## Host to guest: *so do I, and this is who I am.* The host's own peer id rides
## in it so the guest never has to guess one -- see the note on [constant
## WELCOME_SIZE].
const KIND_WELCOME := 0x02
## Host to guest: *no, and here is why.* Sent before the disconnect, so a
## refusal is a sentence rather than a dropped line.
const KIND_REFUSE := 0x03
## Idempotent, superseded by the next one. Sequence-numbered so a receiver can
## drop everything behind the newest.
const KIND_STATE := 0x04
## Applied in order, once each. Sequence-numbered so a receiver can drop a
## duplicate and notice a gap.
const KIND_EVENT := 0x05
## **The host's water, host to guest**: a snapshot of every body the guest can
## sense, idempotent and drained to the newest exactly as a state frame is, and
## sent unreliable for the same reason. Its own sequence, not the state frame's:
## the two streams are paced by different things. shared-pond.md §2.
const KIND_POND := 0x06
## **Host to guest, on the internet listener only: *prove it*** (net-hardening.md
## C). A fresh nonce, sent once a caller's HELLO has passed the protocol check,
## and never by a LAN host. `kind | nonce(16)`.
##
## **No protocol bump, and none of the three frozen bytes**, because no build
## that does not know this kind can ever receive it: the internet listener
## speaks DTLS, which no protocol-4 build has a client for, at an address no
## protocol-4 build has a way to enter. On the LAN nothing changes.
const KIND_CHALLENGE := 0x07
## **Guest to host, the answer to CHALLENGE**: which invite, a nonce of the
## guest's own, and HMAC-SHA256 over both nonces, the protocol and the key id,
## keyed with the invite's secret (`invite.gd`'s `proof_mac`). The secret
## itself never crosses. `kind | key id(8) | nonce(16) | mac(32)`.
const KIND_PROOF := 0x08

# --- Event types. Byte 5 of an event frame. ---------------------------------
## **The ping, crossing.** One pond, one coordinate frame, so what crosses is
## where the pulse came from and how big the cell that made it is: a place, a
## radius and a reach. The receiver turns those into the four scalars its own
## membrane takes.
##
## **The wire is not the bus, and the seam is where it always was.** A position
## crosses here because the receiver cannot compute a bearing in a shared frame
## without one -- it is the same thing `food.gd` holds about every body in the
## water. What reaches `signal_bus.ping()` is still a bearing, a level, an
## angular half-width and a hold, converted on the game's side of the seam by
## the same `_cell.bearing_to()` every other mark on the membrane goes through.
## perception.md's "never a place" is a rule about the membrane, and it is
## intact: the place stops at `_post_pings()`, exactly where `food.gd`'s own
## positions already stop, and nothing downstream of it ever sees one.
const EVENT_SHOUT := 0x01
# --- The shared pond's events (shared-pond.md §2). Reliable and in order, like
# the shout: none of them is superseded by anything, and a guest that missed an
# ARRIVE or a KILLED would be swimming in a water that disagrees with the host's.
## Guest to host: *put me in your water*. The radius of the body arriving.
const EVENT_ENTER := 0x02
## Host to guest, the reply to ENTER: where the host put that body.
const EVENT_ARRIVE := 0x03
## Either way: *this is what I wear* -- a new body, or a change to the worn
## tiers or their order.
const EVENT_PERSON := 0x04
## Host to guest: one water body's genome, once per body version.
const EVENT_GENOME := 0x05
## Host to guest: something happened to the guest's cell in the host's water.
const EVENT_CONTACT := 0x06
## Either way: the sender's own cell died, how, and where.
const EVENT_DIED := 0x07
## Guest to host: the daughter the guest declined, to be left in the water.
const EVENT_SISTER := 0x08
## **Host to guest: a floc in the guest's reach** (ocean.md §10.4): where it
## lies, how big it is, how far it has settled and how long it has left. A floc
## never moves, and how far it has settled is a function of time, so it is told
## once -- as it comes into reach, or lands in it -- and not twenty times a
## second in every snapshot. Protocol 5.
const EVENT_SETTLE := 0x09
## Host to guest: a floc told by [constant EVENT_SETTLE] is gone -- eaten,
## dissolved, or out of the guest's reach. Protocol 5.
const EVENT_CLEAR := 0x0A

# --- Why a host hangs up. Byte 3 of a refusal. ------------------------------
## The two builds do not speak the same protocol -- or, since protocol 8, speak it
## by other rules: the tail's fingerprints differ ([method rules_of]). The one case
## that matters, and the reason the handshake exists at all. Either way the two are
## different versions, and the one that is older takes the update: the prefix says
## which by protocol, and the tail by content ([method content_of]).
const REFUSE_PROTOCOL := 0x01
## Somebody is already here. This game is two cells.
const REFUSE_FULL := 0x02
## The guest connected and then said nothing we understood.
const REFUSE_SILENT := 0x03
## **The guest broke the protocol, again and again**: frames no writer in this
## file produces, or -- once a host enforces its budgets -- far more of them
## than any body sends (net-hardening.md A.4). The host also bars the address
## for a minute. New in the life of protocol 4, and it needed no bump: every
## protocol-4 build reads a reason it does not know as [method reason_says]'s
## "refused", over "the other end hung up".
const REFUSE_BROKEN := 0x04
## **No invite this host will take** (net-hardening.md C): a PROOF naming a key
## id the host does not have, or one whose mac does not check out -- the same
## reason for both, on purpose, so a caller learns nothing about which it got
## wrong -- and a guest whose invite the owner has since revoked or replaced.
## Only ever sent on the internet listener, which no protocol-4 build reaches.
const REFUSE_INVITE := 0x05

## **The three bytes that never move**, a HELLO's whole length before protocol 8.
## Since then a HELLO is these and the [constant TAIL_SIZE] of its tail, 39 bytes.
const HELLO_SIZE := 3
## **The tail of every handshake frame since protocol 8**, after its fixed part:
## the rules the sender judges a guest and decides a contact by, as
## `game/net/rules.gd` fingerprints them ([constant RULES_SIZE] bytes), then its
## content version, a u32 (BuildInfo's), which says which of two builds is older.
## A build before 8 sends none, and a reader of 8 finds none in its frames. **A
## refusal to a stranger** -- a caller on the internet listener that has proved no
## invite -- carries zeros for the rules and a content version that says only which
## game is older (net_session.gd's `_refuse_tail`).
const RULES_SIZE := 32
const TAIL_SIZE := RULES_SIZE + 4
## `kind | protocol | host id`, then the tail. The id is four bytes because peer ids
## are random 32-bit values -- measured in this container, a guest came up as
## 694971552 -- and the only id that is ever a small number is an accident of ENet
## that a WebSocket or relay transport is under no obligation to repeat.
const WELCOME_SIZE := 7
const REFUSE_SIZE := 4
## The internet handshake's pieces (net-hardening.md C): a nonce each way, the
## invite's key id, and an HMAC-SHA256.
const NONCE_SIZE := 16
const KEY_ID_SIZE := 8
const MAC_SIZE := 32
## CHALLENGE: `kind | nonce`. 17 bytes, exactly.
const CHALLENGE_SIZE := 1 + NONCE_SIZE
## PROOF: `kind | key id | nonce | mac`. 57 bytes, exactly.
const PROOF_SIZE := 1 + KEY_ID_SIZE + NONCE_SIZE + MAC_SIZE
## `kind | seq(u32) | flags | x(f32) | y(f32) | radius(f32) | heading(u8)
##  | vx(f32) | vy(f32) | turning(f32)`.
##
## **Thirty-one bytes at 20 Hz is 620 B/s**, about 1.3 kB/s with §5.3's 36
## bytes of IPv4, UDP and ENet on every packet -- a quarter of §5.3's 5.4 kB/s
## for a quantized full-vision world at the same rate, and nothing a home Wi-Fi
## can feel. Twenty a second only while there is a body moving; a session with
## no cell, or one whose run is paused, beats at 2 Hz, 62 B/s. The encodings
## were chosen on correctness rather than size:
##
##   - **the place and the radius are float32**, the same three floats the
##     shout already sends and for the reason written on [constant
##     SHOUT_SIZE]: a world position has no bounds to quantize against, and a
##     fixed-point scale chosen today is a wire break the day the water gets
##     bigger. The radius rides in the same register because one quantity with
##     two encodings on one wire is a bug waiting for a rounding difference.
##   - **the heading is one byte**, which is the caller the note at the bottom
##     of this file was holding [constant BEARING_STEPS] for. Measured through
##     `tools/net_lag.gd`, the largest heading correction a hard turn produced
##     was 0.024 rad on loopback and 0.036 under simulated Wi-Fi -- one to one
##     and a half of the byte's steps, under a unit at the rim of a born cell.
##   - **the velocity is two float32s, in world units a second**, the body's
##     own `velocity` and not a difference of two places: at 20 Hz a difference
##     is divided by fifty milliseconds of arrival jitter, and it cannot see a
##     jump until the frame after the one that carried it.
##   - **the turning is one float32, in radians a second**: `cell.gd`'s
##     `heading_rate()`, the steering and the drift. It is the rate and not the
##     steering *demand* on purpose -- the demand turns into a rate through the
##     sender's own `cirrus` tier, and carrying it would put a gene on the wire
##     to shave a correction the measurements put at about one heading step.
##
## The contract, which is what the bump to 3 is: a receiver may carry the body
## forward by the velocity and the turning for a fraction of a second past the
## frame. How long, and what happens after that, is the receiver's decision --
## `vision.gd` makes it -- and nothing about it is on the wire.
const STATE_SIZE := 31
## **Faster than any body in this water can go, by a wide margin.** Every
## speed-up the game has, at tier 3, stacked and aligned -- impulses and dashes
## as often as their clocks allow, riding a held push -- peaks a little under a
## thousand units a second against the drag. A velocity past this, or a turn
## faster than [constant TURNING_MAX], is not a body -- it is a corrupt frame or
## a hostile one -- and [method state_body] refuses the whole frame rather than
## carry a marker off the edge of the water on it.
const MOTION_MAX := 4096.0
## Radians a second. A tier-3 `cirrus` flat out is 1.02 and the drift adds at
## most 0.13, so sixty-four is fifty-odd times the fastest turn the game has.
const TURNING_MAX := 64.0
## `kind | seq(u32) | type`, before the type's own payload.
const EVENT_HEADER := 6
## Four little-endian float32s after the header: x, y, radius, reach.
##
## Floats rather than the study's quantized bytes, and the arithmetic is why.
## §5.2's one-byte-per-bearing is right for a *bearing*, which has a full turn
## to be quantized over; a world position has no bounds to quantize against --
## a cell that swims for a quarter of an hour is thousands of units from the
## origin -- and a fixed-point scale chosen today is a wire break the day the
## water gets bigger. The organ fires **once** per `ping_period` -- 8.8 s at
## tier 1, 15.2 s at tier 3 -- so 22 bytes is **2.5 B/s at its loudest**, which
## is lost in the state frame's 620 B/s while a body is swimming. There is
## nothing here worth saving. (§5.3's "5 per 15.2 s" counts *returns*, which
## are what one pulse hears back; it is not the rate pulses leave at.)
const SHOUT_SIZE := EVENT_HEADER + 16

## Bit 0 of a state frame: the sender still has a body. Everything else is
## reserved and must be written zero and ignored on read, which is what lets a
## later protocol add a bit without moving a byte.
##
## **It is now load-bearing rather than decorative.** Clear, every float and
## the bearing byte after it are meaningless and [method state_body] refuses to
## read them -- which is the state a session on the join screen is in, before
## there is a run and therefore before there is a body. The bit was already
## spelled "the sender still has a body"; this is that sentence being taken
## literally.
const STATE_ALIVE := 1 << 0
## Bit 1: **alive, but out of the water** -- dividing. Meaningful only beside
## [constant STATE_ALIVE]; the body is still reported, because it is still an
## anchor of the pond (shared-pond.md §1.4), and nothing in the water may touch
## it. Protocol 4.
const STATE_OUT := 1 << 1
## Bit 2: **the pond**. From the host: its run is up and its water will take a
## guest. From a guest: it is swimming in the host's water -- arrived, and not
## dead. The host ignores a guest's positions until this is set. Meaningful
## with or without a body, because the host's pond is still open while the host
## is dead. Protocol 4.
const STATE_POND := 1 << 2

# --- Quantization ------------------------------------------------------------
## **One byte per bearing**, and this is the caller the note that used to sit
## at the bottom of this file was holding it for.
##
## multiplayer.md §5.2 settles it: `signal_bus.gd`'s POST_ANGLE_EPSILON is
## 0.05 rad, one byte over a full turn is 0.0245 rad, so a byte per bearing
## discards nothing the bus does not already discard, and slither.io ships the
## identical `value * TAU / 256`. A heading is the first bearing to cross this
## wire -- the shout still carries none, because its receiver computes its own
## from a place -- and 0.0245 rad is about a degree and a half of nose on a
## body drawn 50 pixels across, which is under a pixel of the thing it turns.
const BEARING_STEPS := 256

# --- The POND snapshot (shared-pond.md §2, ocean.md §10.4) -------------------
## `kind | seq(u32) | your_wound(u8, /255) | count(u8) | your_harm(u8, /4) |
## your_paralysis(u8, /4) | your_sleep(u8, /4)`. **The spare byte became three in
## protocol 7** (docs/design/dna-slots.md §14.2): the stacks of each of
## doses.gd's kinds the recipient carries, as the host counts them, at a quarter
## stack to 63.75 -- against the largest dose there is, a swallow's 48.
const POND_HEADER := 10
## Stacks per step of a POND load byte.
const POND_LOAD_SCALE := 4.0
## How many loads the header carries: doses.gd's KINDS, written out because this
## file loads nothing but the body plan, and the probe holds the two equal.
const POND_LOADS := 3
## One body: `id(u32) | meals(u8) | flags(u8) | x(f32) | y(f32) | heading(u8)
## | radius(u16, /64) | wound(u8, /255) | speed(u8, x2 u/s)`.
##
## **Keyed on the body's id** (protocol 5): a drop has more bodies than a byte
## counts, and an id is the body's for its whole life where a slot is reused.
## The person -- the host's own cell, or a server's other guest -- is id
## [constant PERSON_ID] and flagged [constant POND_IS_PERSON].
##
## **Floats only where a quantity has no bounds**, which is the rule the state
## frame was written to: a place has none, so it is float32; a heading is a
## bearing and takes the byte every bearing here takes; a radius is under a
## thousand units and 1/64 of one is far under a pixel; a wound is 0..1 and a
## 255th is the precision the acceptance holds it to; a speed is under 510
## units a second (a tier-3 lunge is 322), and 2 units a second of error
## carried for the mirror's 0.2 s at most is 0.4 units.
const POND_BODY := 19
## A person adds `vx(f32) | vy(f32) | turning(f32)`: the motion the mirror
## carries them by, which is the state frame's own motion, for the same reason.
const POND_PERSON := POND_BODY + 12
## **The send set: the sixty water bodies nearest the guest, and every one
## hunting it wherever it is** (ocean.md §10.4) -- `food.gd`'s SEND_MAX, written
## out because this file loads nothing but the body plan. 58 lie within 1,940
## units on average at
## the drop's density, more in a thick patch.
const SEND_MAX := 60
## How many bodies one snapshot may carry: the send set and the person.
const POND_BODIES_MAX := SEND_MAX + 1
## **The worst case, and the reason it is one datagram.** Sixty water bodies and
## the person: 10 + 60 x 19 + 31 = 1,181 bytes, under ENet's 1,392-byte MTU, so a
## snapshot is never fragmented and a lost fragment can never cost a whole one.
const POND_MAX := POND_HEADER + (POND_BODIES_MAX - 1) * POND_BODY + POND_PERSON
## The person's id in a snapshot: no water body has it, since a drop numbers
## its bodies from 1 and today's water its serials from 1.
const PERSON_ID := 0
## The POND flag bits: stalking the recipient, the person, and the person in
## the water. `food.gd`'s FLAG_STALKING, FLAG_PERSON and FLAG_IN_WATER, which
## the probe holds to these.
const POND_STALKING := 1 << 0
const POND_IS_PERSON := 1 << 1
const POND_IN_WATER := 1 << 2
## **What a body carries, since protocol 7** (docs/design/dna-slots.md §14.2): a
## load of harm, of paralysis, or of sleep past the cutoff -- so a guest draws
## the doses of the water and of the other player. `food.gd`'s FLAG_HARMED,
## FLAG_PARALYSED and FLAG_ASLEEP. Phase 1 writes harm's.
const POND_HARMED := 1 << 3
const POND_PARALYSED := 1 << 4
const POND_ASLEEP := 1 << 5
## Radius and wound are fixed point on the wire; the speed is in steps.
const POND_RADIUS_SCALE := 64.0
const POND_WOUND_SCALE := 255.0
const POND_SPEED_STEP := 2.0

## **One body of a snapshot, as an Array indexed by these.** The same order as
## `food.gd`'s `Entry` enum, so a snapshot goes from `pond_entries()` to these
## bytes and from these bytes to `apply_pond()` with no copy in between. This
## file loads nothing but the body plan, so the order is written out and the probe
## checks the two agree. `VELOCITY` and `TURNING` read zero for a water cell. An entry may carry
## more after `TURNING` -- the host's own slot for the body -- and none of it is
## written.
enum Entry { ID, MEALS, FLAGS, AT, HEADING, RADIUS, WOUND, SPEED,
	VELOCITY, TURNING }

# --- Genomes, by name (shared-pond.md §2, multiplayer.md §4.7) ---------------
## **Never index-packed.** A gene crosses as its name, because indices closed
## over the retired `rhabdom`'s gap once already (signal_bus.gd) and a name is
## version-proof by construction: an unknown one draws in the fallback hue and
## is inert in every rule, which is the shipped retirement behaviour.
##
## The decoder refuses the whole message on more genes than [member GENES_MAX]
## -- every slot the body plan has, today seven outside and one inside, and one
## more: a held sample, or a gift worn over an organ still worn -- on a name
## outside 1 to [constant NAME_MAX] bytes of `a-z`, or on an order longer than
## [member ORDER_MAX], the slots outside: the order is the worn layout, outside
## only, because an inside form is inside by its name. Tiers clamp to
## 0..[constant TIER_TOP]. Nine since protocol 7, and every bound after it follows
## (docs/design/dna-slots.md §14.2).
##
## **The two counts are the body plan's** (docs/design/gene-catalogue.md §10.2),
## worked out from it and read again whenever it changes ([method _read_plan]): a
## plan with one more slot sends and takes one more gene, one more outside slot
## one more in an order, and every size below that holds a genome follows. **A
## build on another plan is on other rules**: the plan's fingerprint is in the
## rules the handshake carries (§11.3), so two such builds refuse each other there,
## before either sends a genome the other's sizes do not fit.
const BodyPlan := preload("res://game/genes/body_plan.gd")
static var GENES_MAX: int = BodyPlan.SLOTS + 1
static var ORDER_MAX: int = BodyPlan.SLOT_MAX
const NAME_MAX := 16
## **The highest tier that crosses**: genome.gd's TIER_MAX, written out because
## this file loads nothing but the body plan, and the probe holds the two equal.
const TIER_TOP := 3

# --- A list of rules, by line (protocol 6, docs/design/automation.md §10.3) ----
## **The most rules a list holds**: `drop.gd`'s MOST_RULES, eight, written out
## because this file loads nothing but the body plan, and the probe holds the two
## equal. A SISTER carrying more is refused whole.
const MOST_RULES := 8
## **The longest line one rule may be**, in bytes. The longest line today's
## vocabulary can write is under ninety -- `net_probe` measures it -- so a later
## gene with a longer name still fits, and a rule's line is never cut.
const RULE_BYTES_MAX := 128
## **What a rule's line is made of, and all it is made of**: `a-z`, `0-9`, `.`,
## `-`, `>` and the space -- every name a declaration gives, every test word,
## every number on a ladder and the arrow (`rulebook.gd`'s `line_of`). A line is
## a list's text, by declared name, so a name this build does not know crosses as
## it came and the host keeps it as a rule that never fires. A line that is
## empty, longer than [constant RULE_BYTES_MAX] or holds any other byte is not
## one, and the reader refuses the whole SISTER rather than guess.
const RULE_BYTES := "abcdefghijklmnopqrstuvwxyz0123456789.-> "
## `kind | seq | type | radius(f32)`.
const ENTER_SIZE := EVENT_HEADER + 4
## `kind | seq | type | x(f32) | y(f32) | heading(u8) | rim x(f32) | rim y(f32)
## | rim radius(f32)`: where the host put the body, and **the drop it is in**
## (ocean.md §10.4) -- its meniscus, which the guest draws, holds its own cell
## inside and hears and sees with its own organs. A rim of radius 0 is none: a
## host playing today's water.
const ARRIVE_SIZE := EVENT_HEADER + 21
## `kind | seq | type | cause(u8) | by(u8) | x(f32) | y(f32)`.
const DIED_SIZE := EVENT_HEADER + 10
## `kind | seq | type | what(u8) | x(f32) | y(f32) | level(f32) | by(u8)`, and
## then the gene's name for ATE or the cause for KILLED.
const CONTACT_SIZE := EVENT_HEADER + 14
## CONTACT's `what` values that carry a tail: food.gd's Contact.ATE and
## Contact.KILLED, written out for the same reason as [enum Entry] -- and the
## one that carries none but is new in protocol 5, Contact.GRAZED: the guest
## swallowed a floc, and `level` is the nutrition.
const CONTACT_ATE := 5
const CONTACT_KILLED := 6
const CONTACT_GRAZED := 7
## SETTLE: `kind | seq | type | id(u32) | x(f32) | y(f32) | radius(u8, x4)
## | settle(u8, /255) | life(u16, /100 s)`. A floc is 8 to 18 units across, so a
## quarter unit is under a pixel; its settle is 0..1 like a wound; its life is
## under three minutes, to the hundredth of a second.
const SETTLE_SIZE := EVENT_HEADER + 16
const SETTLE_RADIUS_SCALE := 4.0
const SETTLE_LIFE_SCALE := 100.0
## CLEAR: `kind | seq | type | id(u32)`.
const CLEAR_SIZE := EVENT_HEADER + 4

# --- What a frame may weigh (net-hardening.md A.3) ----------------------------
## **Every size here is derived from the writers above**, and `tools/
## net_probe.gd` holds each bound to a frame a writer really produces at it, so
## the table in the plan and this code are one thing. A frame is measured as the
## session sees it: ENet carries one byte more, the RAW command in front.
##
## **A handshake frame may carry a tail.** Its three-byte prefix is frozen, and
## a later protocol may add to it -- shared-pond.md §7 plans the ladder hash on
## the HELLO and WELCOME tails -- so a reader takes anything up to this and
## reads the prefix, which is what lets it refuse that protocol with the
## sentence instead of a shrug.
##
## **So a later protocol's HELLO must stay within these 64 bytes** to be told
## why a host of this build refuses it. Protocol 8's is 39: the prefix and the
## rules' tail ([constant TAIL_SIZE]). Longer, and the host hangs up before
## the handshake with no sentence at all; longer than [member GUEST_OTHER_MAX]
## (290), and it is the oversize cut, which bars the caller's address for a
## minute (net-hardening.md A.2).
const HANDSHAKE_MAX := 64
## **Every size that holds a genome or an order is a static var**, worked out in
## [method _read_plan] from the two counts above, which are the plan's: they are
## constants in all but name, and change only with the plan.
##
## A worn genome at its longest: the count, then [member GENES_MAX] genes of
## `len | a name of NAME_MAX letters | tier`. 163 bytes. An unknown name is
## legal and inert, so the bound follows the format and not today's longest
## gene, which has ten letters.
static var TIERS_MAX := 0
## A slot order at its longest: the count, then [member ORDER_MAX] slots of
## `len | name`. 120 bytes.
static var ORDER_BYTES_MAX := 0
## PERSON: the header, the new-body byte, a genome and an order -- 9 bytes with
## nothing worn, 290 at the most the format holds. A real one is at most 194.
const PERSON_MIN := EVENT_HEADER + 1 + 1 + 1
static var PERSON_MAX := 0
## GENOME: the body's id and meals, then a genome. 12 to 174.
const GENOME_MIN := EVENT_HEADER + 5 + 1
static var GENOME_MAX := 0
## CONTACT: an ATE carries its gene's name, a KILLED its cause. 20 to 37.
const CONTACT_MAX := CONTACT_SIZE + 1 + NAME_MAX
## SISTER: a place, a heading, a radius and a genome -- and since protocol 6 a
## second genome, her DNA, and her list: a count of rules to [constant
## MOST_RULES], then each line as `len | ASCII`. 22 bytes with nothing worn,
## carried or run; 1,378 at the most the format holds, two genomes of nine
## sixteen-letter genes and eight lines of [constant RULE_BYTES_MAX]. A real one
## is under a kilobyte: a DNA holds eight genes of ten letters at most, and
## today's longest line is under ninety bytes.
const SISTER_MIN := EVENT_HEADER + 13 + 1 + 1 + 1
static var SISTER_MAX := 0
## **The most either side ever writes in one frame**: a guest's longest SISTER
## -- since protocol 6, longer than its longest PERSON, [member PERSON_MAX] --
## and a host's POND. A receiver reads no byte past the first of anything
## longer.
static var GUEST_FRAME_MAX := 0
const HOST_FRAME_MAX := POND_MAX
## **The most a guest writes in any frame but a SISTER**: its longest PERSON,
## which was every guest frame's cap before protocol 6. Only a SISTER needs
## more -- her list rides in it -- so a guest frame of any other kind past this
## is still the oversize cut that bars an address (net-hardening.md A.2), and
## not a strike on the ledger. [method guest_cap] says which applies.
static var GUEST_OTHER_MAX := 0


static func _static_init() -> void:
	_read_plan()
	BodyPlan.listen(_read_plan)


## **Every size that follows the body plan, worked out from it**: at load, and
## again whenever a tool swaps a plan in (body_plan.gd's `use`).
static func _read_plan() -> void:
	GENES_MAX = BodyPlan.SLOTS + 1
	ORDER_MAX = BodyPlan.SLOT_MAX
	TIERS_MAX = 1 + GENES_MAX * (1 + NAME_MAX + 1)
	ORDER_BYTES_MAX = 1 + ORDER_MAX * (1 + NAME_MAX)
	PERSON_MAX = EVENT_HEADER + 1 + TIERS_MAX + ORDER_BYTES_MAX
	GENOME_MAX = EVENT_HEADER + 5 + TIERS_MAX
	SISTER_MAX = EVENT_HEADER + 13 + 2 * TIERS_MAX + 1 + MOST_RULES * (1 + RULE_BYTES_MAX)
	GUEST_FRAME_MAX = SISTER_MAX
	GUEST_OTHER_MAX = PERSON_MAX


# ---------------------------------------------------------------------------
# Writing.
# ---------------------------------------------------------------------------

## **A handshake frame's tail** ([constant TAIL_SIZE]): [param rules], the
## fingerprint (written as zeros unless it is [constant RULES_SIZE] bytes), then
## [param content], the sender's content version.
static func tail(rules: PackedByteArray, content: int) -> PackedByteArray:
	var out := _exactly(rules, RULES_SIZE).duplicate()
	out.resize(TAIL_SIZE)
	_put_u32(out, RULES_SIZE, maxi(content, 0))
	return out


## HELLO: the frozen prefix, then [param rest] -- a [method tail], or none, as a
## build before protocol 8 sends it and as a tool may.
static func hello(protocol: int, rest: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(HELLO_SIZE)
	out[0] = KIND_HELLO
	_put_u16(out, 1, protocol)
	out.append_array(rest)
	return out


## WELCOME: `kind | protocol | host id`, then [param rest], a [method tail].
static func welcome(protocol: int, host_id: int,
		rest: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(WELCOME_SIZE)
	out[0] = KIND_WELCOME
	_put_u16(out, 1, protocol)
	_put_u32(out, 3, host_id)
	out.append_array(rest)
	return out


## REFUSE: `kind | protocol | reason`, then [param rest], a [method tail].
static func refuse(protocol: int, reason: int,
		rest: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(REFUSE_SIZE)
	out[0] = KIND_REFUSE
	_put_u16(out, 1, protocol)
	out[3] = reason & 0xFF
	out.append_array(rest)
	return out


## CHALLENGE: the host's fresh [param nonce], [constant NONCE_SIZE] bytes. A
## nonce of another length is written as zeros rather than as a frame the
## reader refuses.
static func challenge(nonce: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([KIND_CHALLENGE])
	out.append_array(_exactly(nonce, NONCE_SIZE))
	return out


## PROOF: which invite ([param key_id]), the guest's own [param nonce], and the
## [param mac] over both nonces. Each piece is written at its exact size.
static func proof(key_id: PackedByteArray, nonce: PackedByteArray,
		mac: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([KIND_PROOF])
	out.append_array(_exactly(key_id, KEY_ID_SIZE))
	out.append_array(_exactly(nonce, NONCE_SIZE))
	out.append_array(_exactly(mac, MAC_SIZE))
	return out


static func _exactly(bytes: PackedByteArray, size: int) -> PackedByteArray:
	if bytes.size() == size:
		return bytes
	var zeros := PackedByteArray()
	zeros.resize(size)
	return zeros


## **The heartbeat, carrying a body and how it is moving.** Where the sender
## is, which way it is pointing, how big it is, how fast it is going and how
## fast it is turning -- and nothing else, because nothing else is needed to put
## a cell on a screen *on time*.
##
## **The velocity used to be left out on purpose**, with the reasoning that a
## receiver holding two frames and a clock has a better velocity than a
## sender's guess. At 2 Hz that was true and it cost half a second of drawing
## behind. The sender's velocity is not a guess -- it is the simulation's own
## state -- and it is the one thing that lets the far screen draw a jump in the
## frame it arrives rather than a beat later.
##
## [param alive] false is the join screen and the death screen: there is a
## session but no cell, so the bytes after the flag are written zero and
## [method state_body] returns nothing for them. A motion no body could have --
## not finite, or past [constant MOTION_MAX] or [constant TURNING_MAX] -- is
## written as no motion, so this end never sends a frame the other end refuses.
##
## [param pond_flags] is [constant STATE_OUT] and [constant STATE_POND], and
## nothing else is written: `OUT` only beside a body, because it says something
## about one, and `POND` either way.
static func state(seq: int, alive: bool, at: Vector2 = Vector2.ZERO,
		heading: float = 0.0, radius: float = 0.0,
		velocity: Vector2 = Vector2.ZERO, turning: float = 0.0,
		pond_flags: int = 0) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(STATE_SIZE)
	out[0] = KIND_STATE
	_put_u32(out, 1, seq)
	var bodied := alive and radius > 0.0 and is_finite(radius) \
		and is_finite(at.x) and is_finite(at.y) and is_finite(heading)
	out[5] = (STATE_ALIVE | (pond_flags & STATE_OUT)) if bodied else 0
	out[5] |= pond_flags & STATE_POND
	if not bodied:
		return out
	out.encode_float(6, at.x)
	out.encode_float(10, at.y)
	out.encode_float(14, radius)
	_put_bearing(out, 18, heading)
	if not _moving_like_a_body(velocity, turning):
		velocity = Vector2.ZERO
		turning = 0.0
	out.encode_float(19, velocity.x)
	out.encode_float(23, velocity.y)
	out.encode_float(27, turning)
	return out


## **The whole of what one cell tells another.** Where the pulse left from, how
## big the cell that made it is, and how far that cell's organ carries. Twenty-
## two bytes, and every one of them is a fact about the shouter's body -- there
## is no velocity, no heading, no genome and no name in here, because none of
## them is needed to hear somebody.
##
## [param reach] is the shouter's own `ping_range`, and it is what makes this
## a *local* signal: the call crosses the water once where her echoes cross it
## twice, so at twice this reach it has run out of water and the listener
## hears nothing (`food.gd`'s `ping_level`). That is the screen's name, made
## mechanical.
static func shout(seq: int, at: Vector2, radius: float,
		reach: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SHOUT_SIZE)
	out[0] = KIND_EVENT
	_put_u32(out, 1, seq)
	out[5] = EVENT_SHOUT
	out.encode_float(6, at.x)
	out.encode_float(10, at.y)
	out.encode_float(14, radius)
	out.encode_float(18, reach)
	return out


## **One snapshot of the host's water**, shared-pond.md §2's POND.
## [param bodies] are Arrays indexed by [enum Entry], exactly what `food.gd`'s
## `pond_entries()` builds. [param your_wound] is the recipient's own wound, as
## the host last bit it.
##
## **This end never writes what the other end refuses**: a body whose place,
## heading or radius is not finite, or whose id is not a u32, is left out
## rather than sent, and a motion no body could have goes as none -- the state
## frame's own rule. Past [constant POND_BODIES_MAX] bodies the rest are left
## out; the send set is built to fit, so that is a guard and not a policy.
##
## **And never past [constant POND_MAX] bytes, whatever it is handed.** The
## budget is one datagram: an unreliable packet over ENet's MTU does not fail,
## it goes out as fragments, and a lost fragment loses the whole snapshot. The
## send set holds one person at most, so it always fits; a body that would take
## the frame past the budget -- sixty-one bodies all flagged as people, say,
## which would be 1,899 bytes -- is left out instead, like any other body this
## end will not send, and the reader refuses a longer frame outright.
##
## [param your_loads] are the stacks of each kind the recipient carries, as the
## host counts them; none written as none.
static func pond(seq: int, your_wound: float, bodies: Array,
		your_loads: PackedFloat64Array = PackedFloat64Array()) -> PackedByteArray:
	var keep: Array = []
	var size := POND_HEADER
	for body: Variant in bodies:
		if keep.size() >= POND_BODIES_MAX:
			break
		if not (body is Array) or (body as Array).size() <= Entry.TURNING:
			continue
		var entry: Array = body
		var where: Variant = entry[Entry.AT]
		if not (where is Vector2) or not (where as Vector2).is_finite():
			continue
		if not is_finite(float(entry[Entry.HEADING])) \
				or not is_finite(float(entry[Entry.RADIUS])):
			continue
		var id := int(entry[Entry.ID])
		var person := (int(entry[Entry.FLAGS]) & POND_IS_PERSON) != 0
		if id < 0 or id > 0xFFFFFFFF or (id == PERSON_ID) != person:
			continue
		var takes := POND_PERSON if person else POND_BODY
		if size + takes > POND_MAX:
			continue
		keep.append(entry)
		size += takes
	var out := PackedByteArray()
	out.resize(size)
	out[0] = KIND_POND
	_put_u32(out, 1, seq)
	out[5] = _unit_byte(your_wound)
	out[6] = keep.size()
	for k in POND_LOADS:
		var stacks := your_loads[k] if k < your_loads.size() else 0.0
		out[7 + k] = clampi(roundi(stacks * POND_LOAD_SCALE), 0, 255) \
			if is_finite(stacks) else 0
	var at := POND_HEADER
	for entry: Array in keep:
		var flags := int(entry[Entry.FLAGS]) & 0xFF
		_put_u32(out, at, int(entry[Entry.ID]))
		out[at + 4] = clampi(int(entry[Entry.MEALS]), 0, 255)
		out[at + 5] = flags
		var place: Vector2 = entry[Entry.AT]
		out.encode_float(at + 6, place.x)
		out.encode_float(at + 10, place.y)
		_put_bearing(out, at + 14, float(entry[Entry.HEADING]))
		_put_u16(out, at + 15, clampi(roundi(maxf(float(entry[Entry.RADIUS]), 0.0)
			* POND_RADIUS_SCALE), 0, 0xFFFF))
		out[at + 17] = _unit_byte(float(entry[Entry.WOUND]))
		var speed := float(entry[Entry.SPEED])
		out[at + 18] = clampi(roundi(speed / POND_SPEED_STEP), 0, 255) \
			if is_finite(speed) else 0
		at += POND_BODY
		if (flags & POND_IS_PERSON) == 0:
			continue
		var velocity: Variant = entry[Entry.VELOCITY]
		var v: Vector2 = velocity if velocity is Vector2 else Vector2.ZERO
		var turning := float(entry[Entry.TURNING])
		if not _moving_like_a_body(v, turning):
			v = Vector2.ZERO
			turning = 0.0
		out.encode_float(at, v.x)
		out.encode_float(at + 4, v.y)
		out.encode_float(at + 8, turning)
		at += 12
	return out


## **An event frame**: the header every event shares, then [param payload],
## which is one of the `*_payload` functions below. The session owns the
## sequence, so it assembles the frame; what the bytes after the header mean
## is this file's.
static func event(seq: int, type: int, payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(EVENT_HEADER)
	out[0] = KIND_EVENT
	_put_u32(out, 1, seq)
	out[5] = type & 0xFF
	out.append_array(payload)
	return out


## ENTER: the radius of the body asking to be put in the water.
static func enter_payload(radius: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	out.encode_float(0, radius if is_finite(radius) else 0.0)
	return out


## ARRIVE: where the host put it, which way it points, and the drop's rim --
## [param rim_center] and [param rim_radius], 0 for a water with none.
static func arrive_payload(at: Vector2, heading: float,
		rim_center: Vector2 = Vector2.ZERO, rim_radius: float = 0.0) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(21)
	out.encode_float(0, at.x if is_finite(at.x) else 0.0)
	out.encode_float(4, at.y if is_finite(at.y) else 0.0)
	_put_bearing(out, 8, heading if is_finite(heading) else 0.0)
	var rimmed := rim_center.is_finite() and is_finite(rim_radius) and rim_radius > 0.0
	out.encode_float(9, rim_center.x if rimmed else 0.0)
	out.encode_float(13, rim_center.y if rimmed else 0.0)
	out.encode_float(17, rim_radius if rimmed else 0.0)
	return out


## PERSON: whether this is a new body, what it wears and in which slots.
## [param order] is the worn layout, slot by slot, `&""` for an empty slot.
static func person_payload(new_body: bool, tiers: Dictionary,
		order: Array) -> PackedByteArray:
	var out := PackedByteArray([1 if new_body else 0])
	out.append_array(_tiers_bytes(tiers))
	out.append_array(_order_bytes(order))
	return out


## GENOME: one water body's genome, keyed by the version the mirror's book
## files it under: the body's id, as POND carries it, and its meals.
static func genome_payload(id: int, meals: int, tiers: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(5)
	_put_u32(out, 0, id)
	out[4] = clampi(meals, 0, 255)
	out.append_array(_tiers_bytes(tiers))
	return out


## SETTLE: a floc [param id] at [param at], [param radius] across, [param settle]
## of the way into focus with [param life] seconds before it begins to dissolve.
## What the wire cannot carry is carried as its nearest: a place that is not
## finite as the origin, the rest clamped to their bytes.
static func settle_payload(id: int, at: Vector2, radius: float, settle: float,
		life: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(16)
	_put_u32(out, 0, id)
	out.encode_float(4, at.x if is_finite(at.x) else 0.0)
	out.encode_float(8, at.y if is_finite(at.y) else 0.0)
	out[12] = clampi(roundi(radius * SETTLE_RADIUS_SCALE), 0, 255) \
		if is_finite(radius) else 0
	out[13] = _unit_byte(settle)
	_put_u16(out, 14, clampi(roundi(life * SETTLE_LIFE_SCALE), 0, 0xFFFF)
		if is_finite(life) else 0)
	return out


## CLEAR: the floc [param id] is gone.
static func clear_payload(id: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	_put_u32(out, 0, id)
	return out


## CONTACT: what happened to the guest, where the other body was, how hard or
## how much, and whose mouth it was -- and, for ATE, the meal's gene by name;
## for KILLED, the cause.
static func contact_payload(what: int, at: Vector2, level: float, by: int,
		gene: StringName = &"", cause: int = 0) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(14)
	out[0] = what & 0xFF
	out.encode_float(1, at.x if is_finite(at.x) else 0.0)
	out.encode_float(5, at.y if is_finite(at.y) else 0.0)
	out.encode_float(9, level if is_finite(level) else 0.0)
	out[13] = by & 0xFF
	if what == CONTACT_ATE:
		var name := String(gene)
		if not _name_ok(name):
			name = ""
		out.append(name.length())
		out.append_array(name.to_ascii_buffer())
	elif what == CONTACT_KILLED:
		out.append(cause & 0xFF)
	return out


## DIED: the sender's own death -- how, by whose mouth, and where.
static func died_payload(cause: int, by: int, at: Vector2) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(10)
	out[0] = cause & 0xFF
	out[1] = by & 0xFF
	out.encode_float(2, at.x if is_finite(at.x) else 0.0)
	out.encode_float(6, at.y if is_finite(at.y) else 0.0)
	return out


## SISTER: where the declined daughter is left, which way she points, how big
## she is and what she wears -- and since protocol 6 the DNA she was made of,
## [param dna] (`{gene: copies}`), and the list her cell ran, [param lines]: a
## rule a line as `rulebook.gd`'s `lines_of` writes them, none for the founders'
## (docs/design/automation.md §10.3).
##
## **The writer never sends what the reader refuses**: a DNA gene the wire
## cannot name is left out as a worn one is, and so is one at no copies, which
## is not carried; a line the reader would refuse is left out, and past
## [constant MOST_RULES] the rest are. A list a library holds never needs it --
## every line this build writes reads -- but a line a later build wrote into
## the library's file is kept there as it came, whatever it holds.
static func sister_payload(at: Vector2, heading: float, radius: float,
		tiers: Dictionary, dna: Dictionary = {},
		lines: PackedStringArray = PackedStringArray()) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(13)
	out.encode_float(0, at.x if is_finite(at.x) else 0.0)
	out.encode_float(4, at.y if is_finite(at.y) else 0.0)
	_put_bearing(out, 8, heading if is_finite(heading) else 0.0)
	out.encode_float(9, radius if is_finite(radius) else 0.0)
	out.append_array(_tiers_bytes(tiers))
	var carried := {}
	for gene: Variant in dna:
		if int(dna[gene]) >= 1:
			carried[gene] = dna[gene]
	out.append_array(_tiers_bytes(carried))
	out.append_array(_lines_bytes(lines))
	return out


# ---------------------------------------------------------------------------
# Reading. Every function here takes arbitrary bytes off a network and must
# return something sane for all of them -- a short frame, a frame from a build
# that does not exist yet, a frame from a port scanner. Nothing below can fail
# on any input; `kind()` returning 0 is the answer to "I do not know what this
# is", and every caller treats that as *ignore it*.
# ---------------------------------------------------------------------------

static func kind(frame: PackedByteArray) -> int:
	return 0 if frame.is_empty() else frame[0]


## The protocol out of a handshake frame, or 0 if this is not one or is too
## short to be one. The three bytes this reads are frozen forever.
static func protocol_of(frame: PackedByteArray) -> int:
	if frame.size() < 3:
		return 0
	var k := frame[0]
	if k != KIND_HELLO and k != KIND_WELCOME and k != KIND_REFUSE:
		return 0
	return _take_u16(frame, 1)


static func welcome_host_id(frame: PackedByteArray) -> int:
	if frame.size() < WELCOME_SIZE or frame[0] != KIND_WELCOME:
		return 0
	return _take_u32(frame, 3)


static func refuse_reason(frame: PackedByteArray) -> int:
	if frame.size() < REFUSE_SIZE or frame[0] != KIND_REFUSE:
		return 0
	return frame[3]


## **The rules out of a handshake frame's tail** ([constant RULES_SIZE] bytes), or
## empty for a frame with no whole tail -- a build's before protocol 8, or one cut
## short. Two builds on one protocol play only when theirs are the same.
static func rules_of(frame: PackedByteArray) -> PackedByteArray:
	var at := _tail_at(frame)
	if at < 0 or frame.size() < at + TAIL_SIZE:
		return PackedByteArray()
	return frame.slice(at, at + RULES_SIZE)


## **The content version out of a handshake frame's tail**, or -1 for a frame with
## no whole tail. Only ever compared, to say which of two builds is older.
static func content_of(frame: PackedByteArray) -> int:
	var at := _tail_at(frame)
	if at < 0 or frame.size() < at + TAIL_SIZE:
		return -1
	return _take_u32(frame, at + RULES_SIZE)


## Where a handshake frame's tail starts -- after its fixed part -- or -1 for a frame
## that is not one.
static func _tail_at(frame: PackedByteArray) -> int:
	if frame.is_empty():
		return -1
	match frame[0]:
		KIND_HELLO:
			return HELLO_SIZE
		KIND_WELCOME:
			return WELCOME_SIZE
		KIND_REFUSE:
			return REFUSE_SIZE
	return -1


## The nonce out of a CHALLENGE, or empty for anything that is not exactly one.
static func challenge_nonce(frame: PackedByteArray) -> PackedByteArray:
	if frame.size() != CHALLENGE_SIZE or frame[0] != KIND_CHALLENGE:
		return PackedByteArray()
	return frame.slice(1)


## `[key id, nonce, mac]` out of a PROOF, or empty for anything that is not
## exactly one.
static func proof_parts(frame: PackedByteArray) -> Array:
	if frame.size() != PROOF_SIZE or frame[0] != KIND_PROOF:
		return []
	var at := 1
	var key_id := frame.slice(at, at + KEY_ID_SIZE)
	at += KEY_ID_SIZE
	var nonce := frame.slice(at, at + NONCE_SIZE)
	at += NONCE_SIZE
	return [key_id, nonce, frame.slice(at, at + MAC_SIZE)]


## Sequence number of a state or event frame, or -1 if there is not one in
## there. -1 rather than 0 because 0 is a legitimate first sequence.
static func seq_of(frame: PackedByteArray) -> int:
	if frame.size() < 5:
		return -1
	if frame[0] != KIND_STATE and frame[0] != KIND_EVENT and frame[0] != KIND_POND:
		return -1
	return _take_u32(frame, 1)


static func state_alive(frame: PackedByteArray) -> bool:
	if frame.size() < STATE_SIZE or frame[0] != KIND_STATE:
		return false
	return (frame[5] & STATE_ALIVE) != 0


## The flag byte of a state frame, or 0 for anything that is not one. `OUT` is
## only ever read beside `ALIVE`; a frame from a build that sets a bit this one
## does not know is read for the bits it does.
static func state_flags(frame: PackedByteArray) -> int:
	if frame.size() < STATE_SIZE or frame[0] != KIND_STATE:
		return 0
	var flags: int = frame[5]
	if (flags & STATE_ALIVE) == 0:
		flags &= ~STATE_OUT
	return flags & (STATE_ALIVE | STATE_OUT | STATE_POND)


## `[at, heading, radius, velocity, turning]` out of a state frame, or an empty
## array when there is no body in it -- a short frame, a frame from something
## that is not a state frame, a sender with [constant STATE_ALIVE] clear, or
## numbers no body could have. Callers check `is_empty()`.
##
## The same refusal the shout decoder makes, for the same reason: a non-finite
## float off the wire is refused here rather than turned into a `NaN` position
## that draws a cell at no coordinate at all, on a canvas, three files away. A
## radius at or below zero goes with it -- it is the one value that would put a
## body on screen with no size, and it is also what an all-zero frame from a
## sender with no cell looks like. **So does a motion past [constant
## MOTION_MAX]**, because a receiver carries the body forward by it: a
## non-finite or absurd velocity is a marker flung off the water on the next
## frame, and refusing the frame costs one frame of a stream that sends twenty.
static func state_body(frame: PackedByteArray) -> Array:
	if frame.size() < STATE_SIZE or frame[0] != KIND_STATE:
		return []
	if (frame[5] & STATE_ALIVE) == 0:
		return []
	var x := frame.decode_float(6)
	var y := frame.decode_float(10)
	var radius := frame.decode_float(14)
	if not (is_finite(x) and is_finite(y) and is_finite(radius)):
		return []
	if radius <= 0.0:
		return []
	var velocity := Vector2(frame.decode_float(19), frame.decode_float(23))
	var turning := frame.decode_float(27)
	if not _moving_like_a_body(velocity, turning):
		return []
	return [Vector2(x, y), _take_bearing(frame, 18), radius, velocity, turning]


## Finite, and inside what any body in this water could be doing. `is_finite`
## first, because a `NaN` compares false against every bound and would pass the
## second test.
static func _moving_like_a_body(velocity: Vector2, turning: float) -> bool:
	if not (is_finite(velocity.x) and is_finite(velocity.y) and is_finite(turning)):
		return false
	return velocity.length() <= MOTION_MAX and absf(turning) <= TURNING_MAX


static func event_type(frame: PackedByteArray) -> int:
	if frame.size() < EVENT_HEADER or frame[0] != KIND_EVENT:
		return 0
	return frame[5]


## **Whether a frame of [param kind] -- and for an event, of event [param type]
## -- may be [param size] bytes long, sent by a host ([param from_host]) or by a
## guest.** False for a size no writer here produces, and for a kind or type
## that side never sends: a guest's POND or GENOME, a host's ENTER or HELLO.
## Nothing past the size is read, so it is safe on any frame. A kind or type
## this protocol does not define is not judged here -- see [method known]: it
## is a later build's, and is ignored rather than refused.
static func size_ok(kind: int, type: int, size: int, from_host: bool) -> bool:
	var span := _span(kind, type, from_host)
	return span.x >= 0 and size >= span.x and size <= span.y


## **The cap a guest's [param frame] is held to**: [member SISTER_MAX] for a
## SISTER event, and [member GUEST_OTHER_MAX] for every other frame. Of a
## frame past [member GUEST_OTHER_MAX] it reads byte 0 and the event's type,
## byte 5 -- which a frame that long has -- only to find the one kind allowed
## past it; of any other frame it reads nothing.
static func guest_cap(frame: PackedByteArray) -> int:
	if frame.size() > GUEST_OTHER_MAX and frame[0] == KIND_EVENT \
			and frame[5] == EVENT_SISTER:
		return SISTER_MAX
	return GUEST_OTHER_MAX


## True for a frame kind this protocol defines -- and for an event, a type it
## defines. Anything else is a later build's extension, which the reader
## promises to ignore.
static func known(kind: int, type: int) -> bool:
	return _span(kind, type, true).x >= 0 or _span(kind, type, false).x >= 0


## `[least, most]` bytes a frame may be, from the side [param from_host] says,
## or `(-1, -1)` when that side never sends it. A.3's table, in code.
static func _span(kind: int, type: int, from_host: bool) -> Vector2i:
	var never := Vector2i(-1, -1)
	match kind:
		KIND_HELLO:
			return never if from_host else Vector2i(HELLO_SIZE, HANDSHAKE_MAX)
		KIND_WELCOME:
			return Vector2i(WELCOME_SIZE, HANDSHAKE_MAX) if from_host else never
		KIND_REFUSE:
			return Vector2i(REFUSE_SIZE, HANDSHAKE_MAX) if from_host else never
		KIND_STATE:
			return Vector2i(STATE_SIZE, STATE_SIZE)
		KIND_POND:
			return Vector2i(POND_HEADER, POND_MAX) if from_host else never
		KIND_CHALLENGE:
			return Vector2i(CHALLENGE_SIZE, CHALLENGE_SIZE) if from_host else never
		KIND_PROOF:
			return never if from_host else Vector2i(PROOF_SIZE, PROOF_SIZE)
		KIND_EVENT:
			match type:
				EVENT_SHOUT:
					return Vector2i(SHOUT_SIZE, SHOUT_SIZE)
				EVENT_ENTER:
					return never if from_host else Vector2i(ENTER_SIZE, ENTER_SIZE)
				EVENT_ARRIVE:
					return Vector2i(ARRIVE_SIZE, ARRIVE_SIZE) if from_host else never
				EVENT_PERSON:
					return Vector2i(PERSON_MIN, PERSON_MAX)
				EVENT_GENOME:
					return Vector2i(GENOME_MIN, GENOME_MAX) if from_host else never
				EVENT_CONTACT:
					return Vector2i(CONTACT_SIZE, CONTACT_MAX) if from_host else never
				EVENT_DIED:
					return Vector2i(DIED_SIZE, DIED_SIZE)
				EVENT_SISTER:
					return never if from_host else Vector2i(SISTER_MIN, SISTER_MAX)
				EVENT_SETTLE:
					return Vector2i(SETTLE_SIZE, SETTLE_SIZE) if from_host else never
				EVENT_CLEAR:
					return Vector2i(CLEAR_SIZE, CLEAR_SIZE) if from_host else never
	return never


## `[at, radius, reach]`, or an empty array if this is not a readable shout.
## Callers check `is_empty()`; an unknown event type is silently nothing, which
## is the rule that lets a later protocol add an event without breaking this
## one. A non-finite float off the wire is refused here rather than turned into
## a `NaN` bearing three files away.
static func take_shout(frame: PackedByteArray) -> Array:
	if frame.size() < SHOUT_SIZE or frame[0] != KIND_EVENT \
			or frame[5] != EVENT_SHOUT:
		return []
	var x := frame.decode_float(6)
	var y := frame.decode_float(10)
	var radius := frame.decode_float(14)
	var reach := frame.decode_float(18)
	if not (is_finite(x) and is_finite(y) and is_finite(radius)
			and is_finite(reach)):
		return []
	return [Vector2(x, y), radius, reach]


## `[seq, your_wound, bodies, your_loads]` out of a POND frame, each body an
## Array indexed by [enum Entry], the loads the stacks of each kind the
## recipient carries -- or an empty array, and the whole frame refused, for a
## short or overlong frame, one past [constant POND_MAX] bytes whatever it
## holds, a count past [constant POND_BODIES_MAX], a person that is not
## [constant PERSON_ID] or a water body that is, a non-finite float, or a motion
## no body could have. A snapshot is superseded fifty milliseconds later, so
## refusing one costs one frame of a stream that sends twenty.
static func take_pond(frame: PackedByteArray) -> Array:
	if frame.size() < POND_HEADER or frame.size() > POND_MAX \
			or frame[0] != KIND_POND:
		return []
	var count: int = frame[6]
	if count > POND_BODIES_MAX:
		return []
	var bodies: Array = []
	var at := POND_HEADER
	for _i in count:
		if at + POND_BODY > frame.size():
			return []
		var id := _take_u32(frame, at)
		var flags: int = frame[at + 5]
		if (id == PERSON_ID) != ((flags & POND_IS_PERSON) != 0):
			return []
		var x := frame.decode_float(at + 6)
		var y := frame.decode_float(at + 10)
		if not (is_finite(x) and is_finite(y)):
			return []
		var entry: Array = [id, int(frame[at + 4]),
			flags, Vector2(x, y), _take_bearing(frame, at + 14),
			float(_take_u16(frame, at + 15)) / POND_RADIUS_SCALE,
			float(frame[at + 17]) / POND_WOUND_SCALE,
			float(frame[at + 18]) * POND_SPEED_STEP, Vector2.ZERO, 0.0]
		at += POND_BODY
		if (flags & POND_IS_PERSON) != 0:
			if at + 12 > frame.size():
				return []
			var velocity := Vector2(frame.decode_float(at), frame.decode_float(at + 4))
			var turning := frame.decode_float(at + 8)
			if not _moving_like_a_body(velocity, turning):
				return []
			entry[Entry.VELOCITY] = velocity
			entry[Entry.TURNING] = turning
			at += 12
		bodies.append(entry)
	if at != frame.size():
		return []
	var loads := PackedFloat64Array()
	loads.resize(POND_LOADS)
	for k in POND_LOADS:
		loads[k] = float(frame[7 + k]) / POND_LOAD_SCALE
	return [_take_u32(frame, 1), float(frame[5]) / POND_WOUND_SCALE, bodies, loads]


## `[radius]` out of an ENTER, or empty. A radius no body could have is
## refused: it would put a body in the water with no size, or with every size.
static func take_enter(frame: PackedByteArray) -> Array:
	if not _is_event(frame, EVENT_ENTER, ENTER_SIZE):
		return []
	var radius := frame.decode_float(EVENT_HEADER)
	if not is_finite(radius) or radius <= 0.0:
		return []
	return [radius]


## `[at, heading, rim_center, rim_radius]` out of an ARRIVE, or empty. A rim
## that is not finite, or not above nothing, reads as none: radius 0.
static func take_arrive(frame: PackedByteArray) -> Array:
	if not _is_event(frame, EVENT_ARRIVE, ARRIVE_SIZE):
		return []
	var x := frame.decode_float(EVENT_HEADER)
	var y := frame.decode_float(EVENT_HEADER + 4)
	if not (is_finite(x) and is_finite(y)):
		return []
	var rim := Vector2(frame.decode_float(EVENT_HEADER + 9),
		frame.decode_float(EVENT_HEADER + 13))
	var reach := frame.decode_float(EVENT_HEADER + 17)
	if not rim.is_finite() or not is_finite(reach) or reach <= 0.0:
		rim = Vector2.ZERO
		reach = 0.0
	return [Vector2(x, y), _take_bearing(frame, EVENT_HEADER + 8), rim, reach]


## `[new_body, tiers, order]` out of a PERSON, or empty.
static func take_person(frame: PackedByteArray) -> Array:
	if frame.size() < EVENT_HEADER + 1 or frame[0] != KIND_EVENT \
			or frame[5] != EVENT_PERSON:
		return []
	var tiers := _take_tiers(frame, EVENT_HEADER + 1)
	if tiers.is_empty():
		return []
	var order := _take_order(frame, int(tiers[1]))
	if order.is_empty() or int(order[1]) != frame.size():
		return []
	return [frame[EVENT_HEADER] != 0, tiers[0], order[0]]


## `[id, meals, tiers]` out of a GENOME, or empty.
static func take_genome(frame: PackedByteArray) -> Array:
	if frame.size() < EVENT_HEADER + 5 or frame[0] != KIND_EVENT \
			or frame[5] != EVENT_GENOME:
		return []
	var tiers := _take_tiers(frame, EVENT_HEADER + 5)
	if tiers.is_empty() or int(tiers[1]) != frame.size():
		return []
	return [_take_u32(frame, EVENT_HEADER), int(frame[EVENT_HEADER + 4]), tiers[0]]


## `[id, at, radius, settle, life]` out of a SETTLE, or empty.
static func take_settle(frame: PackedByteArray) -> Array:
	if not _is_event(frame, EVENT_SETTLE, SETTLE_SIZE):
		return []
	var x := frame.decode_float(EVENT_HEADER + 4)
	var y := frame.decode_float(EVENT_HEADER + 8)
	if not (is_finite(x) and is_finite(y)):
		return []
	return [_take_u32(frame, EVENT_HEADER), Vector2(x, y),
		float(frame[EVENT_HEADER + 12]) / SETTLE_RADIUS_SCALE,
		float(frame[EVENT_HEADER + 13]) / POND_WOUND_SCALE,
		float(_take_u16(frame, EVENT_HEADER + 14)) / SETTLE_LIFE_SCALE]


## `[id]` out of a CLEAR, or empty.
static func take_clear(frame: PackedByteArray) -> Array:
	if not _is_event(frame, EVENT_CLEAR, CLEAR_SIZE):
		return []
	return [_take_u32(frame, EVENT_HEADER)]


## `[what, at, level, by, gene, cause]` out of a CONTACT, or empty. `gene` is
## `&""` unless it was an ATE and `cause` is 0 unless it was a KILLED.
static func take_contact(frame: PackedByteArray) -> Array:
	if frame.size() < CONTACT_SIZE or frame[0] != KIND_EVENT \
			or frame[5] != EVENT_CONTACT:
		return []
	var what: int = frame[EVENT_HEADER]
	var x := frame.decode_float(EVENT_HEADER + 1)
	var y := frame.decode_float(EVENT_HEADER + 5)
	var level := frame.decode_float(EVENT_HEADER + 9)
	if not (is_finite(x) and is_finite(y) and is_finite(level)):
		return []
	var by: int = frame[EVENT_HEADER + 13]
	var gene := &""
	var cause := 0
	var end := CONTACT_SIZE
	if what == CONTACT_ATE:
		if frame.size() < end + 1:
			return []
		var length: int = frame[end]
		if frame.size() != end + 1 + length:
			return []
		if length > 0:
			var name := frame.slice(end + 1, end + 1 + length).get_string_from_ascii()
			if not _name_ok(name) or name.length() != length:
				return []
			gene = StringName(name)
		end += 1 + length
	elif what == CONTACT_KILLED:
		if frame.size() < end + 1:
			return []
		cause = frame[end]
		end += 1
	if frame.size() != end:
		return []
	return [what, Vector2(x, y), level, by, gene, cause]


## `[cause, by, at]` out of a DIED, or empty.
static func take_died(frame: PackedByteArray) -> Array:
	if not _is_event(frame, EVENT_DIED, DIED_SIZE):
		return []
	var x := frame.decode_float(EVENT_HEADER + 2)
	var y := frame.decode_float(EVENT_HEADER + 6)
	if not (is_finite(x) and is_finite(y)):
		return []
	return [int(frame[EVENT_HEADER]), int(frame[EVENT_HEADER + 1]), Vector2(x, y)]


## `[at, heading, radius, tiers, dna, lines]` out of a SISTER, or empty
## (docs/design/automation.md §10.3). `dna` is `{gene: copies}`, a gene at no
## copies left out, since it is not carried -- empty for a SISTER that names
## none, whom a host makes of her body as before; `lines` is her list, a rule a
## line, empty for the founders'.
##
## **Refused whole**, as a genome is: a DNA past [member GENES_MAX] genes or
## naming one the wire cannot ([method _name_ok]); more than [constant
## MOST_RULES] lines; a line that is empty, longer than [constant
## RULE_BYTES_MAX] or holds a byte outside [constant RULE_BYTES]; or a byte past
## the last line.
static func take_sister(frame: PackedByteArray) -> Array:
	if frame.size() < EVENT_HEADER + 13 or frame[0] != KIND_EVENT \
			or frame[5] != EVENT_SISTER:
		return []
	var x := frame.decode_float(EVENT_HEADER)
	var y := frame.decode_float(EVENT_HEADER + 4)
	var radius := frame.decode_float(EVENT_HEADER + 9)
	if not (is_finite(x) and is_finite(y) and is_finite(radius)) or radius <= 0.0:
		return []
	var tiers := _take_tiers(frame, EVENT_HEADER + 13)
	if tiers.is_empty():
		return []
	var dna := _take_tiers(frame, int(tiers[1]))
	if dna.is_empty():
		return []
	var lines := _take_lines(frame, int(dna[1]))
	if lines.is_empty() or int(lines[1]) != frame.size():
		return []
	var carried := {}
	for gene: StringName in dna[0]:
		if int(dna[0][gene]) >= 1:
			carried[gene] = dna[0][gene]
	return [Vector2(x, y), _take_bearing(frame, EVENT_HEADER + 8), radius, tiers[0],
		carried, lines[0]]


## **The short heading a refusal is told as**, on the screen of the phone that was
## refused and in the server's log. Translated here, in the one place both read:
## a process with no screen -- the server -- has no catalog, so its log stays
## English (game/i18n/i18n.gd).
##
## TRANSLATORS: Each is a heading of a few words above a sentence, on the screen
## of the phone whose call the other end ended. At most about 30 characters.
static func reason_says(reason: int) -> String:
	match reason:
		REFUSE_PROTOCOL:
			return TranslationServer.translate("different versions")
		REFUSE_FULL:
			return TranslationServer.translate("already two")
		REFUSE_SILENT:
			return TranslationServer.translate("no greeting")
		REFUSE_BROKEN:
			return TranslationServer.translate("cut off")
		REFUSE_INVITE:
			return TranslationServer.translate("no invite it could prove")
	return TranslationServer.translate("refused")


# ---------------------------------------------------------------------------
# Little-endian, by hand. PackedByteArray's encode_u32 exists, but writing the
# four shifts out makes the format readable by anyone porting it -- which is the
# point of having a format at all.
# ---------------------------------------------------------------------------

static func _put_u16(into: PackedByteArray, at: int, value: int) -> void:
	into[at] = value & 0xFF
	into[at + 1] = (value >> 8) & 0xFF


static func _take_u16(from: PackedByteArray, at: int) -> int:
	return from[at] | (from[at + 1] << 8)


static func _put_u32(into: PackedByteArray, at: int, value: int) -> void:
	into[at] = value & 0xFF
	into[at + 1] = (value >> 8) & 0xFF
	into[at + 2] = (value >> 16) & 0xFF
	into[at + 3] = (value >> 24) & 0xFF


static func _take_u32(from: PackedByteArray, at: int) -> int:
	return from[at] | (from[at + 1] << 8) | (from[at + 2] << 16) \
		| (from[at + 3] << 24)


## A bearing into one byte. Wrapped into a single turn first, so a heading that
## has been accumulating for a quarter of an hour still lands on a mark --
## `fposmod` rather than `fmod` because a negative heading is an ordinary
## heading here and `fmod` keeps the sign.
##
## The round can reach [constant BEARING_STEPS] exactly, at a hair under a full
## turn; the modulo folds it back onto zero, which is the same angle.
static func _put_bearing(into: PackedByteArray, at: int, radians: float) -> void:
	var turns := fposmod(radians, TAU) / TAU
	into[at] = int(roundf(turns * float(BEARING_STEPS))) % BEARING_STEPS


static func _take_bearing(from: PackedByteArray, at: int) -> float:
	return float(from[at]) * TAU / float(BEARING_STEPS)


## A 0..1 quantity into one byte, rounded, and a non-finite one as 0.
static func _unit_byte(value: float) -> int:
	if not is_finite(value):
		return 0
	return clampi(roundi(clampf(value, 0.0, 1.0) * POND_WOUND_SCALE), 0, 255)


## An event of [param type] exactly [param size] bytes long.
static func _is_event(frame: PackedByteArray, type: int, size: int) -> bool:
	return frame.size() == size and frame[0] == KIND_EVENT and frame[5] == type


## **A gene's name is 1 to [constant NAME_MAX] bytes of `a-z`**, and nothing
## else crosses. Every gene this game has ever had fits; a name that does not
## is not one, and the reader refuses the whole message rather than guess.
static func _name_ok(name: String) -> bool:
	if name.length() < 1 or name.length() > NAME_MAX:
		return false
	for i in name.length():
		var c := name.unicode_at(i)
		if c < 97 or c > 122:
			return false
	return true


## `u8 count`, then per gene `u8 len | name | u8 tier`. A gene whose name would
## be refused is not written, and past [member GENES_MAX] the rest are not:
## the writer never sends what the reader refuses.
static func _tiers_bytes(tiers: Dictionary) -> PackedByteArray:
	var out := PackedByteArray([0])
	var count := 0
	for gene: Variant in tiers:
		if count >= GENES_MAX:
			break
		var name := String(gene)
		if not _name_ok(name):
			continue
		out.append(name.length())
		out.append_array(name.to_ascii_buffer())
		out.append(clampi(int(tiers[gene]), 0, TIER_TOP))
		count += 1
	out[0] = count
	return out


## `u8 count`, then per slot `u8 len | name`, length 0 for an empty slot. Past
## [member ORDER_MAX] slots the rest are not written; a name that would be
## refused is written as an empty slot.
static func _order_bytes(order: Array) -> PackedByteArray:
	var out := PackedByteArray([0])
	var count := 0
	for gene: Variant in order:
		if count >= ORDER_MAX:
			break
		var name := String(gene) if gene != null else ""
		if not name.is_empty() and not _name_ok(name):
			name = ""
		out.append(name.length())
		out.append_array(name.to_ascii_buffer())
		count += 1
	out[0] = count
	return out


## `[{gene: tier}, next offset]` read at [param at], or empty for a refusal.
static func _take_tiers(from: PackedByteArray, at: int) -> Array:
	if at >= from.size():
		return []
	var count: int = from[at]
	if count > GENES_MAX:
		return []
	var tiers := {}
	var i := at + 1
	for _n in count:
		if i >= from.size():
			return []
		var length: int = from[i]
		if length < 1 or length > NAME_MAX or i + 1 + length + 1 > from.size():
			return []
		var name := from.slice(i + 1, i + 1 + length).get_string_from_ascii()
		if name.length() != length or not _name_ok(name):
			return []
		tiers[StringName(name)] = clampi(int(from[i + 1 + length]), 0, TIER_TOP)
		i += 1 + length + 1
	return [tiers, i]


## **Whether [param line] can cross as a rule's line**: 1 to [constant
## RULE_BYTES_MAX] characters, each one of [constant RULE_BYTES].
static func _line_ok(line: String) -> bool:
	if line.length() < 1 or line.length() > RULE_BYTES_MAX:
		return false
	for i in line.length():
		if not _rule_byte_ok(line.unicode_at(i)):
			return false
	return true


## Whether [param code] is one of [constant RULE_BYTES]: `a-z`, `0-9`, `.`, `-`,
## `>` or the space.
static func _rule_byte_ok(code: int) -> bool:
	return (code >= 97 and code <= 122) or (code >= 48 and code <= 57) \
		or code == 46 or code == 45 or code == 62 or code == 32


## `u8 count`, then per line `u8 len | ASCII`. A line the reader would refuse is
## not written, and past [constant MOST_RULES] the rest are not.
static func _lines_bytes(lines: PackedStringArray) -> PackedByteArray:
	var out := PackedByteArray([0])
	var count := 0
	for line: String in lines:
		if count >= MOST_RULES:
			break
		if not _line_ok(line):
			continue
		out.append(line.length())
		out.append_array(line.to_ascii_buffer())
		count += 1
	out[0] = count
	return out


## `[lines, next offset]` read at [param at], or empty for a refusal: a count
## past [constant MOST_RULES], or a line that is empty, longer than [constant
## RULE_BYTES_MAX], past the frame's end or holding a byte outside [constant
## RULE_BYTES]. No byte is turned into a character before it is checked.
static func _take_lines(from: PackedByteArray, at: int) -> Array:
	if at >= from.size():
		return []
	var count: int = from[at]
	if count > MOST_RULES:
		return []
	var lines := PackedStringArray()
	var i := at + 1
	for _n in count:
		if i >= from.size():
			return []
		var length: int = from[i]
		if length < 1 or length > RULE_BYTES_MAX or i + 1 + length > from.size():
			return []
		for k in range(i + 1, i + 1 + length):
			if not _rule_byte_ok(from[k]):
				return []
		lines.append(from.slice(i + 1, i + 1 + length).get_string_from_ascii())
		i += 1 + length
	return [lines, i]


## `[order, next offset]` read at [param at], or empty for a refusal. An empty
## slot reads as `&""`, which is what every layout in this game holds there.
static func _take_order(from: PackedByteArray, at: int) -> Array:
	if at >= from.size():
		return []
	var count: int = from[at]
	if count > ORDER_MAX:
		return []
	var order: Array = []
	var i := at + 1
	for _n in count:
		if i >= from.size():
			return []
		var length: int = from[i]
		if length > NAME_MAX or i + 1 + length > from.size():
			return []
		if length == 0:
			order.append(&"")
			i += 1
			continue
		var name := from.slice(i + 1, i + 1 + length).get_string_from_ascii()
		if name.length() != length or not _name_ok(name):
			return []
		order.append(StringName(name))
		i += 1 + length
	return [order, i]
