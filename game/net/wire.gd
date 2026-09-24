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

## **Bumped by hand, whenever the meaning of any byte below changes.**
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
## **Rule, until the ladder hash lands (shared-pond.md §7): any content change to
## `cell.gd`'s `GAPE_BY_TIER`, `ARMOR_BY_TIER` or the bite tables (`BITE_BY_TIER`,
## `BITE_GAP`, `VENOM_BITE_BACK_BY_TIER`, `VENOM_COST_BY_TIER`, `bite_damage`,
## `venom_back`) must bump this number**, or a host on one pack and a guest on
## another share a pond whose contacts one of them misjudges.
const PROTOCOL := 4

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

# --- Why a host hangs up. Byte 3 of a refusal. ------------------------------
## The two builds do not speak the same protocol. The one case that matters,
## and the reason the handshake exists at all.
const REFUSE_PROTOCOL := 0x01
## Somebody is already here. This game is two cells.
const REFUSE_FULL := 0x02
## The guest connected and then said nothing we understood.
const REFUSE_SILENT := 0x03
## **The guest broke the protocol, again and again**: frames no writer in this
## file produces, or far more of them than any body sends (net-hardening.md
## A.4). New in the life of protocol 4, and it needed no bump: every protocol-4
## build reads a reason it does not know as [method reason_says]'s "refused",
## over "the other end hung up".
const REFUSE_BROKEN := 0x04

const HELLO_SIZE := 3
## `kind | protocol | host id`. The id is four bytes because peer ids are random
## 32-bit values -- measured in this container, a guest came up as 694971552 --
## and the only id that is ever a small number is an accident of ENet that a
## WebSocket or relay transport is under no obligation to repeat.
const WELCOME_SIZE := 7
const REFUSE_SIZE := 4
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

# --- The POND snapshot (shared-pond.md §2) -----------------------------------
## `kind | seq(u32) | your_wound(u8, /255) | count(u8) | reserved(u8)`.
const POND_HEADER := 8
## One body: `slot(u8) | serial(u16) | meals(u8) | flags(u8) | x(f32) | y(f32)
## | heading(u8) | radius(u16, /64) | wound(u8, /255) | speed(u8, x2 u/s)`.
##
## **Floats only where a quantity has no bounds**, which is the rule the state
## frame was written to: a place has none, so it is float32; a heading is a
## bearing and takes the byte every bearing here takes; a radius is under a
## thousand units and 1/64 of one is far under a pixel; a wound is 0..1 and a
## 255th is the precision the acceptance holds it to; a speed is under 510
## units a second (a tier-3 lunge is 322), and 2 units a second of error
## carried for the mirror's 0.2 s at most is 0.4 units.
const POND_BODY := 18
## A person adds `vx(f32) | vy(f32) | turning(f32)`: the motion the mirror
## carries them by, which is the state frame's own motion, for the same reason.
const POND_PERSON := POND_BODY + 12
## How many bodies one snapshot may carry: two waters' worth and the person --
## `food.gd`'s POND_SLOTS, written out because this file loads nothing.
const POND_BODIES_MAX := 69
## **The worst case, and the reason it is one datagram.** Sixty-eight cells and
## the host: 8 + 68 x 18 + 30 = 1,262 bytes, under ENet's 1,392-byte MTU, so a
## snapshot is never fragmented and a lost fragment can never cost a whole one.
const POND_MAX := POND_HEADER + (POND_BODIES_MAX - 1) * POND_BODY + POND_PERSON
## The POND flag bits: stalking the recipient, the person, and the person in
## the water. `food.gd`'s FLAG_STALKING, FLAG_PERSON and FLAG_IN_WATER, which
## the probe holds to these.
const POND_STALKING := 1 << 0
const POND_IS_PERSON := 1 << 1
const POND_IN_WATER := 1 << 2
## Radius and wound are fixed point on the wire; the speed is in steps.
const POND_RADIUS_SCALE := 64.0
const POND_WOUND_SCALE := 255.0
const POND_SPEED_STEP := 2.0

## **One body of a snapshot, as an Array indexed by these.** The same order as
## `food.gd`'s `Entry` enum, so a snapshot goes from `pond_entries()` to these
## bytes and from these bytes to `apply_pond()` with no copy in between. This
## file loads nothing, so the order is written out and the probe checks the two
## agree. `VELOCITY` and `TURNING` read zero for a water cell.
enum Entry { SLOT, SERIAL, MEALS, FLAGS, AT, HEADING, RADIUS, WOUND, SPEED,
	VELOCITY, TURNING }

# --- Genomes, by name (shared-pond.md §2, multiplayer.md §4.7) ---------------
## **Never index-packed.** A gene crosses as its name, because indices closed
## over the retired `rhabdom`'s gap once already (signal_bus.gd) and a name is
## version-proof by construction: an unknown one draws in the fallback hue and
## is inert in every rule, which is the shipped retirement behaviour.
##
## The decoder refuses the whole message on more genes than [constant
## GENES_MAX] -- seven slots and a held sample -- on a name outside 1 to
## [constant NAME_MAX] bytes of `a-z`, or on an order longer than [constant
## ORDER_MAX]. Tiers clamp to 0..[constant TIER_TOP].
const GENES_MAX := 8
const ORDER_MAX := 7
const NAME_MAX := 16
const TIER_TOP := 3
## `kind | seq | type | radius(f32)`.
const ENTER_SIZE := EVENT_HEADER + 4
## `kind | seq | type | x(f32) | y(f32) | heading(u8)`.
const ARRIVE_SIZE := EVENT_HEADER + 9
## `kind | seq | type | cause(u8) | by(u8) | x(f32) | y(f32)`.
const DIED_SIZE := EVENT_HEADER + 10
## `kind | seq | type | what(u8) | x(f32) | y(f32) | level(f32) | by(u8)`, and
## then the gene's name for ATE or the cause for KILLED.
const CONTACT_SIZE := EVENT_HEADER + 14
## CONTACT's `what` values that carry a tail: food.gd's Contact.ATE and
## Contact.KILLED, written out for the same reason as [enum Entry].
const CONTACT_ATE := 5
const CONTACT_KILLED := 6

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
const HANDSHAKE_MAX := 64
## A worn genome at its longest: the count, then [constant GENES_MAX] genes of
## `len | a name of NAME_MAX letters | tier`. 145 bytes. An unknown name is
## legal and inert, so the bound follows the format and not today's longest
## gene, which has ten letters.
const TIERS_MAX := 1 + GENES_MAX * (1 + NAME_MAX + 1)
## A slot order at its longest: the count, then [constant ORDER_MAX] slots of
## `len | name`. 120 bytes.
const ORDER_BYTES_MAX := 1 + ORDER_MAX * (1 + NAME_MAX)
## PERSON: the header, the new-body byte, a genome and an order -- 9 bytes with
## nothing worn, 272 at the most the format holds. A real one is at most 182.
const PERSON_MIN := EVENT_HEADER + 1 + 1 + 1
const PERSON_MAX := EVENT_HEADER + 1 + TIERS_MAX + ORDER_BYTES_MAX
## GENOME: slot, serial and meals, then a genome. 11 to 155.
const GENOME_MIN := EVENT_HEADER + 4 + 1
const GENOME_MAX := EVENT_HEADER + 4 + TIERS_MAX
## CONTACT: an ATE carries its gene's name, a KILLED its cause. 20 to 37.
const CONTACT_MAX := CONTACT_SIZE + 1 + NAME_MAX
## SISTER: a place, a heading, a radius and a genome. 20 to 164.
const SISTER_MIN := EVENT_HEADER + 13 + 1
const SISTER_MAX := EVENT_HEADER + 13 + TIERS_MAX
## **The most either side ever writes in one frame**: a guest's longest PERSON
## and a host's POND. A receiver reads no byte past the first of anything
## longer.
const GUEST_FRAME_MAX := PERSON_MAX
const HOST_FRAME_MAX := POND_MAX

# ---------------------------------------------------------------------------
# Writing.
# ---------------------------------------------------------------------------

static func hello(protocol: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(HELLO_SIZE)
	out[0] = KIND_HELLO
	_put_u16(out, 1, protocol)
	return out


static func welcome(protocol: int, host_id: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(WELCOME_SIZE)
	out[0] = KIND_WELCOME
	_put_u16(out, 1, protocol)
	_put_u32(out, 3, host_id)
	return out


static func refuse(protocol: int, reason: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(REFUSE_SIZE)
	out[0] = KIND_REFUSE
	_put_u16(out, 1, protocol)
	out[3] = reason & 0xFF
	return out


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
## heading or radius is not finite, or whose slot is not a slot, is left out
## rather than sent, and a motion no body could have goes as none -- the state
## frame's own rule. Past [constant POND_BODIES_MAX] bodies the rest are left
## out; the send set is built to fit, so that is a guard and not a policy.
##
## **And never past [constant POND_MAX] bytes, whatever it is handed.** The
## budget is one datagram: an unreliable packet over ENet's MTU does not fail,
## it goes out as fragments, and a lost fragment loses the whole snapshot. The
## send set holds one person at most, so it always fits; a body that would take
## the frame past the budget -- sixty-nine bodies all flagged as people, say,
## which would be 2,078 bytes -- is left out instead, like any other body this
## end will not send, and the reader refuses a longer frame outright.
static func pond(seq: int, your_wound: float, bodies: Array) -> PackedByteArray:
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
		var slot := int(entry[Entry.SLOT])
		if slot < 0 or slot >= POND_BODIES_MAX:
			continue
		var takes := POND_PERSON if (int(entry[Entry.FLAGS]) & POND_IS_PERSON) != 0 \
			else POND_BODY
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
	out[7] = 0
	var at := POND_HEADER
	for entry: Array in keep:
		var flags := int(entry[Entry.FLAGS]) & 0xFF
		out[at] = int(entry[Entry.SLOT])
		_put_u16(out, at + 1, int(entry[Entry.SERIAL]) & 0xFFFF)
		out[at + 3] = clampi(int(entry[Entry.MEALS]), 0, 255)
		out[at + 4] = flags
		var place: Vector2 = entry[Entry.AT]
		out.encode_float(at + 5, place.x)
		out.encode_float(at + 9, place.y)
		_put_bearing(out, at + 13, float(entry[Entry.HEADING]))
		_put_u16(out, at + 14, clampi(roundi(maxf(float(entry[Entry.RADIUS]), 0.0)
			* POND_RADIUS_SCALE), 0, 0xFFFF))
		out[at + 16] = _unit_byte(float(entry[Entry.WOUND]))
		var speed := float(entry[Entry.SPEED])
		out[at + 17] = clampi(roundi(speed / POND_SPEED_STEP), 0, 255) \
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


## ARRIVE: where the host put it, and which way it points.
static func arrive_payload(at: Vector2, heading: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(9)
	out.encode_float(0, at.x if is_finite(at.x) else 0.0)
	out.encode_float(4, at.y if is_finite(at.y) else 0.0)
	_put_bearing(out, 8, heading if is_finite(heading) else 0.0)
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
## files it under. The serial crosses as sixteen bits, like POND's.
static func genome_payload(slot: int, serial: int, meals: int,
		tiers: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	out[0] = clampi(slot, 0, 255)
	_put_u16(out, 1, serial & 0xFFFF)
	out[3] = clampi(meals, 0, 255)
	out.append_array(_tiers_bytes(tiers))
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
## she is and what she wears.
static func sister_payload(at: Vector2, heading: float, radius: float,
		tiers: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(13)
	out.encode_float(0, at.x if is_finite(at.x) else 0.0)
	out.encode_float(4, at.y if is_finite(at.y) else 0.0)
	_put_bearing(out, 8, heading if is_finite(heading) else 0.0)
	out.encode_float(9, radius if is_finite(radius) else 0.0)
	out.append_array(_tiers_bytes(tiers))
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


## `[seq, your_wound, bodies]` out of a POND frame, each body an Array indexed
## by [enum Entry] -- or an empty array, and the whole frame refused, for a
## short or overlong frame, one past [constant POND_MAX] bytes whatever it
## holds, a count past [constant POND_BODIES_MAX], a slot
## that is not one, a non-finite float, or a motion no body could have. A
## snapshot is superseded fifty milliseconds later, so refusing one costs one
## frame of a stream that sends twenty.
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
		var slot: int = frame[at]
		if slot >= POND_BODIES_MAX:
			return []
		var flags: int = frame[at + 4]
		var x := frame.decode_float(at + 5)
		var y := frame.decode_float(at + 9)
		if not (is_finite(x) and is_finite(y)):
			return []
		var entry: Array = [slot, _take_u16(frame, at + 1), int(frame[at + 3]),
			flags, Vector2(x, y), _take_bearing(frame, at + 13),
			float(_take_u16(frame, at + 14)) / POND_RADIUS_SCALE,
			float(frame[at + 16]) / POND_WOUND_SCALE,
			float(frame[at + 17]) * POND_SPEED_STEP, Vector2.ZERO, 0.0]
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
	return [_take_u32(frame, 1), float(frame[5]) / POND_WOUND_SCALE, bodies]


## `[radius]` out of an ENTER, or empty. A radius no body could have is
## refused: it would put a body in the water with no size, or with every size.
static func take_enter(frame: PackedByteArray) -> Array:
	if not _is_event(frame, EVENT_ENTER, ENTER_SIZE):
		return []
	var radius := frame.decode_float(EVENT_HEADER)
	if not is_finite(radius) or radius <= 0.0:
		return []
	return [radius]


## `[at, heading]` out of an ARRIVE, or empty.
static func take_arrive(frame: PackedByteArray) -> Array:
	if not _is_event(frame, EVENT_ARRIVE, ARRIVE_SIZE):
		return []
	var x := frame.decode_float(EVENT_HEADER)
	var y := frame.decode_float(EVENT_HEADER + 4)
	if not (is_finite(x) and is_finite(y)):
		return []
	return [Vector2(x, y), _take_bearing(frame, EVENT_HEADER + 8)]


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


## `[slot, serial, meals, tiers]` out of a GENOME, or empty.
static func take_genome(frame: PackedByteArray) -> Array:
	if frame.size() < EVENT_HEADER + 4 or frame[0] != KIND_EVENT \
			or frame[5] != EVENT_GENOME:
		return []
	var tiers := _take_tiers(frame, EVENT_HEADER + 4)
	if tiers.is_empty() or int(tiers[1]) != frame.size():
		return []
	return [int(frame[EVENT_HEADER]), _take_u16(frame, EVENT_HEADER + 1),
		int(frame[EVENT_HEADER + 3]), tiers[0]]


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


## `[at, heading, radius, tiers]` out of a SISTER, or empty.
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
	if tiers.is_empty() or int(tiers[1]) != frame.size():
		return []
	return [Vector2(x, y), _take_bearing(frame, EVENT_HEADER + 8), radius, tiers[0]]


static func reason_says(reason: int) -> String:
	match reason:
		REFUSE_PROTOCOL:
			return "different versions"
		REFUSE_FULL:
			return "already two"
		REFUSE_SILENT:
			return "no greeting"
		REFUSE_BROKEN:
			return "cut off"
	return "refused"


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
## be refused is not written, and past [constant GENES_MAX] the rest are not:
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
## [constant ORDER_MAX] slots the rest are not written; a name that would be
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
