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
const PROTOCOL := 3

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

# --- Why a host hangs up. Byte 3 of a refusal. ------------------------------
## The two builds do not speak the same protocol. The one case that matters,
## and the reason the handshake exists at all.
const REFUSE_PROTOCOL := 0x01
## Somebody is already here. This game is two cells.
const REFUSE_FULL := 0x02
## The guest connected and then said nothing we understood.
const REFUSE_SILENT := 0x03

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
static func state(seq: int, alive: bool, at: Vector2 = Vector2.ZERO,
		heading: float = 0.0, radius: float = 0.0,
		velocity: Vector2 = Vector2.ZERO, turning: float = 0.0) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(STATE_SIZE)
	out[0] = KIND_STATE
	_put_u32(out, 1, seq)
	var bodied := alive and radius > 0.0 and is_finite(radius) \
		and is_finite(at.x) and is_finite(at.y) and is_finite(heading)
	out[5] = STATE_ALIVE if bodied else 0
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
## a *local* signal: past it the pulse has run out of water and the listener
## hears nothing. That is the screen's name, made mechanical.
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
	if frame[0] != KIND_STATE and frame[0] != KIND_EVENT:
		return -1
	return _take_u32(frame, 1)


static func state_alive(frame: PackedByteArray) -> bool:
	if frame.size() < STATE_SIZE or frame[0] != KIND_STATE:
		return false
	return (frame[5] & STATE_ALIVE) != 0


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


static func reason_says(reason: int) -> String:
	match reason:
		REFUSE_PROTOCOL:
			return "different versions"
		REFUSE_FULL:
			return "already two"
		REFUSE_SILENT:
			return "no greeting"
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
