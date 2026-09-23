extends Node
## The network probe: two sessions, one headless process, over ENet on
## loopback.
##
## **It asserts positives and CI greps for them.** `.github/workflows/ci.yml`
## documents twice, from measurement, that Godot exits 0 straight through script
## errors -- a duplicate function in a booted scene's own script produces a
## SCRIPT ERROR and exit 0. A network test that only ran would go green while
## testing nothing, so every check below prints `[net-probe] PASS <name>` or
## `[net-probe] FAIL <name>`, and the last line is `[net-probe] ALL PASS`, which
## is the only thing CI trusts.
##
## **What it cannot see, and the list is longer than what it can.** Everything
## here happens inside one process on 127.0.0.1, so it says nothing at all
## about: latency, jitter, packet loss, reordering, MTU, NAT, Wi-Fi roaming,
## Android's `onActivityStopped` pausing the whole main loop, thermal
## throttling, battery, or the one bug that matters most --
## `godotengine/godot#105726`, ENet clients disconnecting at random over a real
## LAN, which is **documented not to reproduce on localhost**, which is exactly
## this recipe. It also cannot see whether a phone's Wi-Fi is on a /24. Two real
## devices on real Wi-Fi for thirty minutes is the test this is not.
##
## What it *can* see is the whole of the local contract: that the handshake
## completes, that a shout crosses and decodes to the numbers that went in, that
## state frames keep arriving **carrying the sender's body and its motion**, at
## twenty a second and at once when the body jumps, that the newest state frame
## wins and the ones behind it are dropped, that the marker the world view draws
## off all that lands where the other cell said it was -- **on time, which is
## locked here** -- and the highest-value assertion in the file, that a peer on a
## different protocol is refused with a sentence instead of hanging. Protocols
## 1, 2 and 3 are all refused by name, because none is a hypothetical: they are
## the three builds that shipped before this one.
##
## **And the pond, played** (shared-pond.md §5, Phase 2): two sessions and two
## real runs of the game, one hosting the water and one mirroring it, put
## through every lifecycle the pond has -- arriving, eating and being eaten,
## the black, dividing, a quiet host and a closed one.
##
## **How late the marker is, as a distribution, is `tools/net_lag.gd`'s job**,
## not this file's -- it takes minutes. What this file keeps is the one number
## that would move if anybody put a buffer back: how long a dash takes to show.
##
## **And one section has no socket at all**: `pond-field`, the water learning a
## second player before any wire carries one (shared-pond.md §5, Phase 1) --
## `food.gd` stepped by hand, a host field with a person in it and a mirror fed
## that field's own snapshots. It spends no frames, only a few seconds.
##
## **Two of these run against a scene rather than a socket**, and both are here
## rather than in a render for the same reason: CI never sees a pixel. A `_draw`
## does fire under `--headless` -- 1,920 `draw` signals in 1,920 frames of a
## full-vision run, measured -- but into a renderer that keeps nothing, so
## anything computed inside one runs in CI and is checked by nothing.
## `game/vision/vision.gd` keeps every number the marker needs in a `_process`,
## and this reads it.
##
## Excluded from export (`tools/*` on both presets), so none of it ships.

const Wire := preload("res://game/net/wire.gd")
const Lan := preload("res://game/net/lan.gd")
const NetSession := preload("res://game/net/net_session.gd")
## Only for [method VisionLayer.carry] and its two constants, which are the
## arithmetic in the peer marker that a render could not catch: CI renders no
## pixels -- its headless draws land in a renderer that keeps none -- so a carry
## checked only by looking at a screenshot is a carry CI has never checked.
const VisionLayer := preload("res://game/vision/vision.gd")
const CellBody := preload("res://game/normal/cell.gd")
## The water, for the `pond-field` section: driven by hand, with no socket and
## no tree, so a minute of it costs its arithmetic and not a minute of waiting.
const FoodField := preload("res://game/normal/food.gd")
const Cilia := preload("res://game/vision/cilia.gd")
const Genome := preload("res://game/normal/genome.gd")
## For the run's own numbering -- Life, Split, the division's clocks and the
## pond's lines -- which the `pond` section reads off two real runs.
const NormalMode := preload("res://game/normal/normal_mode.gd")

## Long enough for a loopback handshake by a wide margin; short enough that a
## hang is a failure rather than a job timeout.
const SETTLE := 6.0
## **The lag, locked.** How long a dash on one screen may take to be drawn on
## the other, on loopback, at both levels `tools/net_lag.gd` times: 2 units --
## the first thing an eye could catch -- and 20, most of a body radius, where
## nobody could miss it. Measured by `tools/net_lag.gd` on loopback at 60 fps
## over forty jumps: the new wire drew the first 2 units 15-34 ms after the far
## body moved them and 20 units 31-46 ms after; the old one took 199-554 ms and
## 465-573 ms. 200 ms leaves a CI runner room to stall and still fails the day
## anybody puts a buffer of a fifth of a second or more back in -- and it was
## tried: the old 2 Hz beat with no carry, put back by hand, failed both.
const DASH_ONSET_MAX := 0.2

var _failed := 0


func _ready() -> void:
	# **A ceiling on the frame rate, for CI's backstop and for nothing else.**
	# The step runs this uncapped under `--quit-after 20000`, which counts
	# frames, and every wait in here is wall time -- so on a fast enough runner
	# twenty thousand frames arrive before the last check does, and the probe
	# is cut off one line short of `ALL PASS`. At 500 a second twenty thousand
	# frames is forty seconds, twice what the socket sections take. The
	# `pond-field` section's seconds do not count against it: it runs to the end
	# inside this one call, so all of it is spent within a single frame. Nothing
	# here depends on a frame rate above that: every clock in `game/net/` is
	# wall time, and the dash is timed in microseconds either way.
	Engine.max_fps = 500
	# `--pond-only` is for working on the pond sections: the rest is skipped,
	# so an answer comes in seconds. CI never passes it, and it never prints
	# ALL PASS -- a partial run must not read as a whole one.
	var only_pond := OS.get_cmdline_user_args().has("--pond-only")
	if only_pond:
		_check_pond_wire()
		_check_pond_field()
		await _check_pond()
		print("[net-probe] NOTE --pond-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	_check_code()
	_check_wire()
	_check_pond_wire()
	_check_carry()
	_check_pond_field()
	await _check_link()
	await _check_skew()
	await _check_run()
	await _check_pond()
	# **The margin on CI's backstop, printed.** The step runs this with no
	# frame cap and `--quit-after 20000`, which is a count of frames, not of
	# seconds -- so a faster runner reaches it sooner, and a probe that grew
	# past it would be cut off before `ALL PASS` and read as a failure.
	print("[net-probe] NOTE finished in %d frames and %.1f s -- CI stops at"
		% [Engine.get_process_frames(), float(Time.get_ticks_msec()) / 1000.0]
		+ " 20000, and at most %d a second can arrive" % Engine.max_fps)
	if _failed == 0:
		print("[net-probe] ALL PASS")
	else:
		print("[net-probe] %d FAILED" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


# ---------------------------------------------------------------------------
# The tap code. Pure arithmetic, no socket.
# ---------------------------------------------------------------------------

func _check_code() -> void:
	var round_trips := true
	var seen: Array[Dictionary] = [{}, {}, {}]
	for octet in range(1, 255):
		var code := Lan.code_for(octet)
		if code.size() != Lan.DIGITS:
			round_trips = false
			break
		for i in Lan.ADDRESS_DIGITS:
			seen[i][code[i]] = true
		if Lan.octet_for(code) != octet:
			round_trips = false
			break
	_says(round_trips, "code round-trips all 254 addresses")

	# The scramble earning its constant: straight base-twelve would put every
	# real address on one of two first bearings.
	var spread := true
	for i in Lan.ADDRESS_DIGITS:
		if seen[i].size() != Lan.BEARINGS:
			spread = false
	_says(spread, "all 12 bearings are used at all 3 positions (%d/%d/%d)"
		% [seen[0].size(), seen[1].size(), seen[2].size()])

	# The check digit's whole job.
	var caught := true
	var tried := 0
	for octet in range(1, 255):
		var code := Lan.code_for(octet)
		for position in Lan.DIGITS:
			for wrong in Lan.BEARINGS:
				if wrong == code[position]:
					continue
				var bad := PackedInt32Array(code)
				bad[position] = wrong
				tried += 1
				if Lan.octet_for(bad) != -1:
					caught = false
	_says(caught, "every one of %d single-digit mis-taps is refused" % tried)

	# What it does not catch, measured rather than hand-waved.
	var swaps := 0
	var escaped := 0
	for octet in range(1, 255):
		var code := Lan.code_for(octet)
		for position in Lan.ADDRESS_DIGITS - 1:
			if code[position] == code[position + 1]:
				continue
			var bad := PackedInt32Array(code)
			bad[position] = code[position + 1]
			bad[position + 1] = code[position]
			swaps += 1
			if Lan.octet_for(bad) != -1:
				escaped += 1
	print("[net-probe] NOTE %d of %d adjacent transpositions decode to some"
		% [escaped, swaps]
		+ " other address (%.1f%%) -- a fifth tap is what would close that"
		% (100.0 * float(escaped) / maxf(float(swaps), 1.0)))

	# Out of range, both ends, and the digits the ring cannot produce.
	var refuses := Lan.code_for(0).is_empty() and Lan.code_for(255).is_empty() \
		and Lan.octet_for(PackedInt32Array([0, 0, 0])) == -1 \
		and Lan.octet_for(PackedInt32Array([12, 0, 0, 0])) == -1 \
		and Lan.octet_for(PackedInt32Array([-1, 0, 0, 0])) == -1
	_says(refuses, "network and broadcast addresses have no code")

	# Bearings and the ring's hit test are inverses, which is what makes a tap
	# land on the mark it is under.
	var bearings := true
	for digit in Lan.BEARINGS:
		if Lan.digit_at(Lan.bearing_of(digit)) != digit:
			bearings = false
		# A tap a third of a sector off still lands on the same mark.
		if Lan.digit_at(Lan.bearing_of(digit) + deg_to_rad(9.0)) != digit:
			bearings = false
		if Lan.digit_at(Lan.bearing_of(digit) - deg_to_rad(9.0)) != digit:
			bearings = false
	_says(bearings, "a tap 9 degrees off a mark still lands on it")

	var address := Lan.local_address()
	_says(not address.is_empty() and Lan.octet_of(address) > 0,
		"this machine has a LAN address to be found at (%s)" % address)
	_says(Lan.host_address("192.168.4.9", 37) == "192.168.4.37"
			and Lan.host_address("", 37).is_empty()
			and Lan.host_address("192.168.4.9", 0).is_empty(),
		"the /24 derivation puts a tapped octet on this device's own prefix")


# ---------------------------------------------------------------------------
# The wire. Every encoder against its decoder, then every decoder against
# rubbish.
# ---------------------------------------------------------------------------

func _check_wire() -> void:
	var sizes := Wire.hello(1).size() == Wire.HELLO_SIZE \
		and Wire.welcome(1, 7).size() == Wire.WELCOME_SIZE \
		and Wire.refuse(1, 1).size() == Wire.REFUSE_SIZE \
		and Wire.state(0, true, Vector2.ZERO, 0.0, 26.0).size() == Wire.STATE_SIZE \
		and Wire.state(0, false).size() == Wire.STATE_SIZE \
		and Wire.shout(0, Vector2.ZERO, 1.0, 1.0).size() == Wire.SHOUT_SIZE
	_says(sizes, "every frame is the length the constants say it is")

	# A peer id with the top bit set, because peer ids are random 32-bit values
	# and a sign-extended one would address the wrong peer forever.
	var big := 0xC0DE1234
	var welcome := Wire.welcome(4242, big)
	_says(Wire.protocol_of(welcome) == 4242
			and Wire.welcome_host_id(welcome) == big,
		"a welcome survives a 32-bit peer id with the high bit set")

	var refuse := Wire.refuse(9, Wire.REFUSE_PROTOCOL)
	_says(Wire.protocol_of(refuse) == 9
			and Wire.refuse_reason(refuse) == Wire.REFUSE_PROTOCOL,
		"a refusal carries the refuser's protocol and its reason")

	var alive := Wire.state(70000, true, Vector2(-1806.5, 942.25), 2.25, 33.5,
		Vector2(-121.5, 64.25), -0.625)
	var dead := Wire.state(70001, false)
	_says(Wire.seq_of(alive) == 70000 and Wire.state_alive(alive)
			and Wire.seq_of(dead) == 70001 and not Wire.state_alive(dead),
		"a state frame round-trips a sequence past 16 bits")

	# **Protocol 2's whole reason for existing.** The place and the radius are
	# float32 and must come back exactly; the heading is one byte over a full
	# turn, so it comes back within half a step of 0.0245 rad -- finer than
	# signal_bus.gd's own POST_ANGLE_EPSILON of 0.05, which is the argument
	# multiplayer.md §5.2 makes for spending the byte.
	var body := Wire.state_body(alive)
	var step := TAU / float(Wire.BEARING_STEPS)
	var carried := body.size() == 5 \
		and (body[0] as Vector2).is_equal_approx(Vector2(-1806.5, 942.25)) \
		and is_equal_approx(float(body[2]), 33.5) \
		and absf(angle_difference(float(body[1]), 2.25)) <= step * 0.5
	_says(carried, "a state frame round-trips a place, a radius and a heading"
		+ " (heading off by %.4f rad of a %.4f rad step)"
		% [absf(angle_difference(float(body[1]), 2.25)), step])
	# **And protocol 3's.** The motion the far screen carries the body forward
	# by: float32, so it comes back exactly -- a velocity that drifted in the
	# encoding would walk the marker off the body it belongs to.
	_says(body.size() == 5
			and (body[3] as Vector2).is_equal_approx(Vector2(-121.5, 64.25))
			and is_equal_approx(float(body[4]), -0.625),
		"and the velocity and turn rate it is moving with, exactly")
	var still := Wire.state_body(Wire.state(4, true, Vector2(1.0, 1.0), 0.0, 20.0))
	_says(still.size() == 5 and (still[3] as Vector2) == Vector2.ZERO
			and float(still[4]) == 0.0,
		"a body reported with no motion is a body held still, not a guess")

	# Every bearing a cell can hold, including the negative ones `heading` is
	# full of and the wound-up ones a quarter of an hour of turning produces.
	var bearings := true
	var worst := 0.0
	for i in 720:
		var angle := -TAU * 3.0 + TAU * 6.0 * float(i) / 720.0
		var back := Wire.state_body(Wire.state(1, true, Vector2.ZERO, angle, 20.0))
		if back.is_empty():
			bearings = false
			break
		var off := absf(angle_difference(float(back[1]), angle))
		worst = maxf(worst, off)
		if off > step * 0.5 + 0.0001:
			bearings = false
	_says(bearings, "every heading over six turns survives the byte"
		+ " (worst %.4f rad, half a step is %.4f)" % [worst, step * 0.5])

	# The flag is the gate, and it is the difference between "no cell here" and
	# "a cell at the origin with no size".
	_says(Wire.state_body(dead).is_empty(),
		"a state frame with no body in it decodes to no body")
	var bodiless := Wire.state(2, true, Vector2(4.0, 4.0), 1.0, 0.0)
	_says(not Wire.state_alive(bodiless) and Wire.state_body(bodiless).is_empty(),
		"a caller that claims a body and hands over no radius gets neither")

	var rotten := Wire.state(3, true, Vector2(1.0, 2.0), 0.5, 18.0)
	rotten.encode_float(10, INF)
	_says(Wire.state_body(rotten).is_empty(),
		"a non-finite place in a state frame is refused at the decoder")

	# A motion is carried forward by the far screen, so a poisoned one is worse
	# than a poisoned place: it moves the marker every frame. Refused whole.
	var flung := Wire.state(5, true, Vector2(1.0, 2.0), 0.5, 18.0,
		Vector2(10.0, 0.0), 0.1)
	flung.encode_float(23, NAN)
	var spun := Wire.state(6, true, Vector2(1.0, 2.0), 0.5, 18.0)
	spun.encode_float(27, Wire.TURNING_MAX * 2.0)
	var fast := Wire.state(7, true, Vector2(1.0, 2.0), 0.5, 18.0)
	fast.encode_float(19, Wire.MOTION_MAX * 2.0)
	_says(Wire.state_body(flung).is_empty() and Wire.state_body(spun).is_empty()
			and Wire.state_body(fast).is_empty(),
		"a non-finite or impossible motion is refused at the decoder")
	# And this end never writes one it would refuse: a bad motion goes out as
	# none, and the body with it still arrives.
	var sane := Wire.state_body(Wire.state(8, true, Vector2(3.0, 4.0), 0.0,
		18.0, Vector2(NAN, 1.0), INF))
	_says(sane.size() == 5 and (sane[0] as Vector2).is_equal_approx(Vector2(3.0, 4.0))
			and (sane[3] as Vector2) == Vector2.ZERO and float(sane[4]) == 0.0,
		"a motion no body could have is sent as none, and the body still crosses")

	var at := Vector2(-4213.75, 917.5)
	var frame := Wire.shout(5, at, 34.25, 1500.0)
	var said := Wire.take_shout(frame)
	var exact := said.size() == 3 and (said[0] as Vector2).is_equal_approx(at) \
		and is_equal_approx(float(said[1]), 34.25) \
		and is_equal_approx(float(said[2]), 1500.0) \
		and Wire.seq_of(frame) == 5 \
		and Wire.event_type(frame) == Wire.EVENT_SHOUT
	_says(exact, "a shout round-trips its place, its size and its reach")

	# Every frame, truncated at every length, through every decoder. Nothing
	# here may crash, and nothing may claim to have read something.
	var survives := true
	for whole: PackedByteArray in [Wire.hello(1), welcome, refuse, alive, frame,
			PackedByteArray([0xFE, 0xFF]), PackedByteArray()]:
		for cut in whole.size():
			var short := whole.slice(0, cut)
			Wire.kind(short)
			Wire.protocol_of(short)
			Wire.welcome_host_id(short)
			Wire.refuse_reason(short)
			Wire.seq_of(short)
			Wire.state_alive(short)
			Wire.event_type(short)
			if not Wire.take_shout(short).is_empty():
				survives = false
			if not Wire.state_body(short).is_empty():
				survives = false
	_says(survives, "every decoder refuses every truncation of every frame")

	# A kind from a protocol that does not exist yet.
	var future := PackedByteArray([0x7F, 1, 2, 3, 4, 5, 6, 7])
	_says(Wire.kind(future) == 0x7F and Wire.protocol_of(future) == 0
			and Wire.take_shout(future).is_empty()
			and Wire.state_body(future).is_empty(),
		"an unknown frame kind reads as unknown rather than as something")

	# A float the wire should never carry, because the alternative is a NaN
	# bearing three files away.
	var poisoned := Wire.shout(1, Vector2.ZERO, 1.0, 1.0)
	poisoned.encode_float(6, NAN)
	_says(Wire.take_shout(poisoned).is_empty(),
		"a non-finite float off the wire is refused at the decoder")


# ---------------------------------------------------------------------------
# **Protocol 4's frames** (shared-pond.md §2): the snapshot, the seven events
# and genomes by name. Every encoder against its decoder, every decoder against
# every truncation, and the two tables this file cannot load against the field
# that fills them.
# ---------------------------------------------------------------------------

func _check_pond_wire() -> void:
	# The two tables written out twice, and the checks that they agree.
	var same := true
	for key: String in FoodField.Entry.keys():
		if not Wire.Entry.has(key) or int(Wire.Entry[key]) != int(FoodField.Entry[key]):
			same = false
	_says(same and Wire.Entry.size() == FoodField.Entry.size()
			and Wire.POND_STALKING == FoodField.FLAG_STALKING
			and Wire.POND_IS_PERSON == FoodField.FLAG_PERSON
			and Wire.POND_IN_WATER == FoodField.FLAG_IN_WATER
			and Wire.POND_BODIES_MAX == FoodField.POND_SLOTS
			and Wire.CONTACT_ATE == FoodField.Contact.ATE
			and Wire.CONTACT_KILLED == FoodField.Contact.KILLED,
		"pond wire: the snapshot's entry order, its flags, its slot count and"
		+ " the contact numbers are the field's own")

	# **The budget, at its worst**: sixty-eight water cells and the other
	# player, every one of them sent. One ENet datagram under the MTU.
	var bodies: Array = []
	for i in FoodField.PERSON_SLOT:
		bodies.append([i, 60000 + i, i % 7, Wire.POND_STALKING if i % 5 == 0 else 0,
			Vector2(-3000.5 + 91.25 * i, 1777.75 - 13.5 * i), -3.0 + 0.09 * i,
			4.0 + 0.61 * i, float(i % 11) / 10.0, 2.0 * float(i % 90), Vector2.ZERO,
			0.0])
	bodies.append([FoodField.PERSON_SLOT, 65535, 255,
		Wire.POND_IS_PERSON | Wire.POND_IN_WATER, Vector2(512.25, -96.5), 1.5, 28.28,
		0.4, 44.0, Vector2(-37.5, 12.25), -0.75])
	var whole := Wire.pond(123456, 0.62, bodies)
	_says(whole.size() == Wire.POND_MAX and Wire.POND_MAX == 1262,
		"pond wire: sixty-eight cells and a person make %d bytes, the budget's"
		% whole.size() + " 1,262 -- one datagram under ENet's 1,392")
	var said := Wire.take_pond(whole)
	var exact := said.size() == 3 and int(said[0]) == 123456 \
		and absf(float(said[1]) - 0.62) <= 0.5 / 255.0 \
		and (said[2] as Array).size() == bodies.size()
	var worst_heading := 0.0
	if exact:
		for k in bodies.size():
			var sent: Array = bodies[k]
			var got: Array = said[2][k]
			worst_heading = maxf(worst_heading, absf(angle_difference(
				float(got[Wire.Entry.HEADING]), float(sent[Wire.Entry.HEADING]))))
			if int(got[Wire.Entry.SLOT]) != int(sent[Wire.Entry.SLOT]) \
					or int(got[Wire.Entry.SERIAL]) != int(sent[Wire.Entry.SERIAL]) & 0xFFFF \
					or int(got[Wire.Entry.MEALS]) != int(sent[Wire.Entry.MEALS]) \
					or int(got[Wire.Entry.FLAGS]) != int(sent[Wire.Entry.FLAGS]) \
					or not (got[Wire.Entry.AT] as Vector2).is_equal_approx(sent[Wire.Entry.AT]) \
					or absf(float(got[Wire.Entry.RADIUS]) - float(sent[Wire.Entry.RADIUS])) \
						> 0.5 / Wire.POND_RADIUS_SCALE \
					or absf(float(got[Wire.Entry.WOUND]) - float(sent[Wire.Entry.WOUND])) \
						> 0.5 / Wire.POND_WOUND_SCALE \
					or absf(float(got[Wire.Entry.SPEED]) - float(sent[Wire.Entry.SPEED])) \
						> Wire.POND_SPEED_STEP * 0.5 \
					or not (got[Wire.Entry.VELOCITY] as Vector2).is_equal_approx(
						sent[Wire.Entry.VELOCITY]) \
					or not is_equal_approx(float(got[Wire.Entry.TURNING]),
						float(sent[Wire.Entry.TURNING])):
				exact = false
	_says(exact and worst_heading <= TAU / float(Wire.BEARING_STEPS) * 0.5 + 1e-4,
		"pond wire: every body round-trips -- slot, serial, meals, flags, place"
		+ " exactly, radius to 1/64, wound to 1/255, speed to 2 u/s, heading to"
		+ " half a step (worst %.4f rad) -- and the person's motion exactly"
		% worst_heading)

	# Refused whole: every truncation, one byte too many, a slot that is not one,
	# a place that is not finite, a motion no body could have.
	var refuses := true
	for cut in whole.size():
		if not Wire.take_pond(whole.slice(0, cut)).is_empty():
			refuses = false
			break
	var longer := whole.duplicate()
	longer.append(0)
	var bad_slot := whole.duplicate()
	bad_slot[Wire.POND_HEADER] = Wire.POND_BODIES_MAX
	var bad_place := whole.duplicate()
	bad_place.encode_float(Wire.POND_HEADER + 5, NAN)
	var bad_motion := whole.duplicate()
	bad_motion.encode_float(whole.size() - 12, INF)
	var too_many := whole.duplicate()
	too_many[6] = Wire.POND_BODIES_MAX + 1
	_says(refuses and Wire.take_pond(longer).is_empty()
			and Wire.take_pond(bad_slot).is_empty()
			and Wire.take_pond(bad_place).is_empty()
			and Wire.take_pond(bad_motion).is_empty()
			and Wire.take_pond(too_many).is_empty(),
		"pond wire: a snapshot is refused whole at every truncation, one byte"
		+ " long, with a slot past 68, a place or a motion that is not finite,"
		+ " or a count past 69")
	# And never written: a body the reader would refuse is left out, and a
	# motion no body could have goes as none.
	var rotten: Array = bodies.slice(0, 3)
	rotten[1] = rotten[1].duplicate()
	rotten[1][Wire.Entry.AT] = Vector2(NAN, 0.0)
	var person: Array = bodies[bodies.size() - 1].duplicate()
	person[Wire.Entry.VELOCITY] = Vector2(Wire.MOTION_MAX * 2.0, 0.0)
	rotten.append(person)
	var cleaned := Wire.take_pond(Wire.pond(1, 0.0, rotten))
	_says(cleaned.size() == 3 and (cleaned[2] as Array).size() == 3
			and (cleaned[2][2][Wire.Entry.VELOCITY] as Vector2) == Vector2.ZERO,
		"pond wire: a body the reader would refuse is never written, and an"
		+ " impossible motion goes as none")
	# **Never past the budget, whatever the writer is handed** (review): sixty-
	# nine bodies all flagged as people were 2,078 bytes, which ENet sends as
	# fragments -- one lost, the whole snapshot lost. The writer leaves out what
	# would not fit, and the reader refuses a longer frame outright, however
	# well formed.
	var people: Array = []
	for i in Wire.POND_BODIES_MAX:
		var one: Array = (bodies[bodies.size() - 1] as Array).duplicate()
		one[Wire.Entry.SLOT] = i
		people.append(one)
	var capped := Wire.pond(7, 0.0, people)
	var capped_said := Wire.take_pond(capped)
	var fits := floori(float(Wire.POND_MAX - Wire.POND_HEADER) / float(Wire.POND_PERSON))
	var over := capped.duplicate()
	over.append_array(capped.slice(capped.size() - Wire.POND_PERSON))
	over[6] = int(over[6]) + 1
	_says(capped.size() <= Wire.POND_MAX and capped_said.size() == 3
			and (capped_said[2] as Array).size() == fits
			and over.size() > Wire.POND_MAX and Wire.take_pond(over).is_empty(),
		"pond wire: sixty-nine people are written as the %d that fit, %d bytes of"
		% [fits, capped.size()] + " %d; one more, well formed at %d bytes, is"
		% [Wire.POND_MAX, over.size()] + " refused")

	# The seven events, each against its decoder.
	var worn := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 2, &"toxicyst": 1,
		&"ampulla": 2}
	var order: Array = [&"cytostome", &"", &"cirrus", &"flagellum", &"ampulla", &"",
		&"toxicyst"]
	var enter := Wire.event(9, Wire.EVENT_ENTER, Wire.enter_payload(28.28))
	var arrive := Wire.event(10, Wire.EVENT_ARRIVE,
		Wire.arrive_payload(Vector2(560.5, -12.25), 1.0))
	var person_frame := Wire.event(11, Wire.EVENT_PERSON,
		Wire.person_payload(true, worn, order))
	var genome := Wire.event(12, Wire.EVENT_GENOME,
		Wire.genome_payload(67, 70001, 4, worn))
	var ate := Wire.event(13, Wire.EVENT_CONTACT, Wire.contact_payload(
		FoodField.Contact.ATE, Vector2(3.5, -4.5), 0.93, FoodField.By.FRIEND,
		&"toxicyst"))
	var killed := Wire.event(14, Wire.EVENT_CONTACT, Wire.contact_payload(
		FoodField.Contact.KILLED, Vector2(-8.0, 2.0), 0.0, FoodField.By.WATER, &"",
		FoodField.Cause.POISONED))
	var bit := Wire.event(15, Wire.EVENT_CONTACT, Wire.contact_payload(
		FoodField.Contact.BITTEN, Vector2(1.0, 1.0), 0.37, FoodField.By.WATER))
	var died := Wire.event(16, Wire.EVENT_DIED, Wire.died_payload(
		FoodField.Cause.CHEWED, FoodField.By.FRIEND, Vector2(-44.5, 90.0)))
	var sister := Wire.event(17, Wire.EVENT_SISTER, Wire.sister_payload(
		Vector2(700.0, -3.0), -1.25, 28.28, worn))
	var e := Wire.take_enter(enter)
	var a := Wire.take_arrive(arrive)
	var p := Wire.take_person(person_frame)
	var g := Wire.take_genome(genome)
	var c := Wire.take_contact(ate)
	var k := Wire.take_contact(killed)
	var b := Wire.take_contact(bit)
	var d := Wire.take_died(died)
	var s := Wire.take_sister(sister)
	var step := TAU / float(Wire.BEARING_STEPS)
	_says(enter.size() == Wire.ENTER_SIZE and arrive.size() == Wire.ARRIVE_SIZE
			and died.size() == Wire.DIED_SIZE and bit.size() == Wire.CONTACT_SIZE
			and killed.size() == Wire.CONTACT_SIZE + 1,
		"pond wire: ENTER %d, ARRIVE %d, DIED %d and CONTACT %d bytes, as §2 says"
		% [enter.size(), arrive.size(), died.size(), bit.size()]
		+ " (KILLED one more, for its cause)")
	_says(e.size() == 1 and is_equal_approx(float(e[0]), 28.28)
			and a.size() == 2 and (a[0] as Vector2).is_equal_approx(Vector2(560.5, -12.25))
			and absf(angle_difference(float(a[1]), 1.0)) <= step * 0.5
			and p.size() == 3 and bool(p[0]) and p[1] == worn and p[2] == order
			and g.size() == 4 and int(g[0]) == 67 and int(g[1]) == 70001 & 0xFFFF
			and int(g[2]) == 4 and g[3] == worn,
		"pond wire: ENTER, ARRIVE, PERSON and GENOME round-trip -- the worn"
		+ " genome by name, with its empty slots, and a serial past 16 bits as"
		+ " its low 16")
	_says(c.size() == 6 and int(c[0]) == FoodField.Contact.ATE
			and (c[1] as Vector2).is_equal_approx(Vector2(3.5, -4.5))
			and is_equal_approx(float(c[2]), 0.93) and int(c[3]) == FoodField.By.FRIEND
			and c[4] == &"toxicyst" and int(c[5]) == 0
			and k.size() == 6 and int(k[5]) == FoodField.Cause.POISONED
			and k[4] == &"" and b.size() == 6 and is_equal_approx(float(b[2]), 0.37)
			and d.size() == 3 and int(d[0]) == FoodField.Cause.CHEWED
			and int(d[1]) == FoodField.By.FRIEND
			and (d[2] as Vector2).is_equal_approx(Vector2(-44.5, 90.0))
			and s.size() == 4 and (s[0] as Vector2).is_equal_approx(Vector2(700.0, -3.0))
			and absf(angle_difference(float(s[1]), -1.25)) <= step * 0.5
			and is_equal_approx(float(s[2]), 28.28) and s[3] == worn,
		"pond wire: CONTACT carries an ATE's gene and a KILLED's cause, and DIED"
		+ " and SISTER round-trip")
	var events := [enter, arrive, person_frame, genome, ate, killed, bit, died, sister]
	var cut_ok := true
	for frame: PackedByteArray in events:
		for cut in frame.size():
			var short := frame.slice(0, cut)
			if not (Wire.take_enter(short).is_empty() and Wire.take_arrive(short).is_empty()
					and Wire.take_person(short).is_empty()
					and Wire.take_genome(short).is_empty()
					and Wire.take_contact(short).is_empty()
					and Wire.take_died(short).is_empty()
					and Wire.take_sister(short).is_empty()):
				cut_ok = false
		var long := frame.duplicate()
		long.append(0)
		if not (Wire.take_enter(long).is_empty() and Wire.take_arrive(long).is_empty()
				and Wire.take_person(long).is_empty() and Wire.take_genome(long).is_empty()
				and Wire.take_contact(long).is_empty() and Wire.take_died(long).is_empty()
				and Wire.take_sister(long).is_empty()):
			cut_ok = false
	_says(cut_ok, "pond wire: every event is refused at every truncation and one"
		+ " byte long, by every decoder")

	# **Genomes by name**: the reader refuses the whole message on a name that
	# is not 1-16 bytes of a-z, on more than eight genes or seven slots; tiers
	# clamp to 0..3; the writer never sends what the reader refuses.
	var loud := Wire.take_person(Wire.event(1, Wire.EVENT_PERSON,
		Wire.person_payload(false, {&"cytostome": 9, &"cirrus": -2}, [])))
	var nine := {}
	for i in 9:
		nine[StringName("gene" + "abcdefghi"[i])] = 1
	var nine_frame := Wire.event(1, Wire.EVENT_PERSON, Wire.person_payload(false, {}, []))
	nine_frame.resize(Wire.EVENT_HEADER + 1)
	nine_frame.append(9)
	for gene: StringName in nine:
		nine_frame.append(String(gene).length())
		nine_frame.append_array(String(gene).to_ascii_buffer())
		nine_frame.append(1)
	nine_frame.append(0)
	var named := func(name: String, tier: int = 1) -> PackedByteArray:
		var f := Wire.event(1, Wire.EVENT_PERSON, PackedByteArray([0, 1]))
		f.append(name.to_utf8_buffer().size())
		f.append_array(name.to_utf8_buffer())
		f.append(tier)
		f.append(0)
		return f
	var clamped := Wire.take_person(named.call("cytostome", 9))
	var eight_slots := Wire.event(1, Wire.EVENT_PERSON, PackedByteArray([0, 0, 8]))
	for i in 8:
		eight_slots.append(0)
	_says(loud.size() == 3 and int(loud[1][&"cytostome"]) == Wire.TIER_TOP
			and int(loud[1][&"cirrus"]) == 0
			and clamped.size() == 3 and int(clamped[1][&"cytostome"]) == Wire.TIER_TOP
			and not Wire.take_person(named.call("cirrus")).is_empty()
			and Wire.take_person(named.call("Cirrus")).is_empty()
			and Wire.take_person(named.call("")).is_empty()
			and Wire.take_person(named.call("abcdefghijklmnopq")).is_empty()
			and Wire.take_person(named.call("cir rus")).is_empty()
			and Wire.take_person(named.call("cili5")).is_empty()
			and Wire.take_person(nine_frame).is_empty()
			and Wire.take_person(eight_slots).is_empty(),
		"pond wire: a genome is refused whole on a name that is not 1-16 bytes of"
		+ " a-z, nine genes or eight slots; tiers clamp to 0..3")
	var written := Wire.take_person(Wire.event(1, Wire.EVENT_PERSON,
		Wire.person_payload(false, {&"cytostome": 1, &"Bad Name": 2, &"": 1},
			[&"cytostome", &"Bad Name", &"", &"a", &"b", &"c", &"d", &"e", &"f"])))
	_says(written.size() == 3 and (written[1] as Dictionary).size() == 1
			and (written[2] as Array).size() == Wire.ORDER_MAX
			and written[2][1] == &"",
		"pond wire: and the writer leaves out what the reader would refuse --"
		+ " a bad name is not sent, a bad slot goes empty, past seven slots stop")


# ---------------------------------------------------------------------------
# The carry. Pure arithmetic against frames made up on the spot, and the only
# part of the peer marker that a screenshot cannot judge. `--headless` still
# calls every `_draw`, but into a renderer that keeps no pixels, so anything
# that lived inside one would boot green in CI forever however wrong its
# numbers were -- only a script error there would show.
#
# **This reverses #50's "never extrapolates" for a live peer, and keeps it for
# a silent one.** #50 drew the friend half a second behind the newest frame so
# it never had to guess; the owner played it and the friend was late. So the
# newest frame is now carried forward along its own velocity -- for at most
# PEER_REACH, after which it freezes, and silence is handled exactly as #50
# handled it. The third and fourth checks below are that boundary.
# ---------------------------------------------------------------------------

func _check_carry() -> void:
	var frame := [10.0, Vector2(100.0, 40.0), 0.5, 30.0, Vector2(50.0, -20.0), 0.4]

	var landed := VisionLayer.carry(frame, 10.0)
	_says(landed.size() == 3
			and (landed[0] as Vector2).is_equal_approx(Vector2(100.0, 40.0))
			and is_equal_approx(float(landed[1]), 0.5)
			and is_equal_approx(float(landed[2]), 30.0),
		"a frame the moment it lands is drawn exactly where it says")

	var tenth := VisionLayer.carry(frame, 10.1)
	_says((tenth[0] as Vector2).is_equal_approx(Vector2(105.0, 38.0))
			and is_equal_approx(float(tenth[1]), 0.54),
		"a tenth of a second on it has moved a tenth of its velocity and turned"
		+ " a tenth of its rate")

	# **The one that matters when a phone goes in a pocket.** Five minutes after
	# the last frame the marker is where a fifth of a second of carry left it --
	# not somewhere an old velocity would have taken it since, which would be
	# confidently wrong in a brand new place every frame.
	var reach := VisionLayer.PEER_REACH
	var capped := VisionLayer.carry(frame, 10.0 + reach)
	var much_later := VisionLayer.carry(frame, 310.0)
	_says((much_later[0] as Vector2).is_equal_approx(capped[0])
			and is_equal_approx(float(much_later[1]), float(capped[1]))
			and (capped[0] as Vector2).is_equal_approx(
				Vector2(100.0, 40.0) + Vector2(50.0, -20.0) * reach),
		"five minutes on it has been carried %.2f s and not a unit further" % reach)

	# And the carry is over long before the fade starts, so the two policies
	# never overlap: a silent peer is never extrapolated, it is only faded.
	_says(VisionLayer.PEER_REACH < VisionLayer.PEER_FRESH,
		"the carry (%.2f s) ends long before the quiet fade begins (%.1f s)"
		% [VisionLayer.PEER_REACH, VisionLayer.PEER_FRESH])

	var held := VisionLayer.carry([4.0, Vector2(7.0, 8.0), 1.0, 22.0,
		Vector2.ZERO, 0.0], 4.15)
	var old_shape := VisionLayer.carry([4.0, Vector2(7.0, 8.0), 1.0, 22.0], 99.0)
	_says((held[0] as Vector2).is_equal_approx(Vector2(7.0, 8.0))
			and is_equal_approx(float(held[1]), 1.0)
			and (old_shape[0] as Vector2).is_equal_approx(Vector2(7.0, 8.0)),
		"a frame with no motion in it is drawn exactly where it says, at any age")

	# A clock read before the stamp -- which one clock cannot produce, and a
	# refactor that mixed two could -- carries nothing rather than backwards.
	var early := VisionLayer.carry(frame, 9.0)
	_says((early[0] as Vector2).is_equal_approx(Vector2(100.0, 40.0)),
		"a clock behind the frame's own stamp carries it nowhere, not backwards")

	_says(VisionLayer.carry([], 1.0).is_empty(),
		"no frame draws nothing at all")


# ---------------------------------------------------------------------------
# Two sessions, one process, over ENet on loopback.
# ---------------------------------------------------------------------------

func _check_link() -> void:
	var host: Node = await _session("HostSide")
	var guest: Node = await _session("GuestSide")

	_says(host.host(), "the host opened a socket on %s" % host.address)
	_says(guest.join("127.0.0.1"), "the guest reached for the host")
	await _until_link(host, NetSession.Link.TOGETHER)
	await _until_link(guest, NetSession.Link.TOGETHER)

	_says(int(host.link) == NetSession.Link.TOGETHER
			and int(guest.link) == NetSession.Link.TOGETHER,
		"both ends completed the handshake")
	print("[net-probe] NOTE host id %d, guest id %d -- the guest's is a random"
		% [host.my_id(), guest.my_id()]
		+ " 32-bit value and nothing in game/net/ compares an id to a literal")
	_says(host.peer_ids() == [guest.my_id()]
			and guest.peer_ids() == [host.my_id()],
		"each end's bookkeeping holds exactly the other end's id")

	# The ping, crossing. The numbers are arbitrary and that is the point: what
	# comes out the far side has to be them.
	var at := Vector2(612.5, -248.25)
	guest.shout(at, 41.5, 1500.0)
	await _until_heard(host, 1)
	var said: Array = host.drain_heard()
	var landed := said.size() == 1 and (said[0][0] as Vector2).is_equal_approx(at) \
		and is_equal_approx(float(said[0][1]), 41.5) \
		and is_equal_approx(float(said[0][2]), 1500.0)
	_says(landed, "a shout crossed the wire and arrived as the numbers sent")
	_says(host.drain_heard().is_empty(),
		"a drained shout is not heard a second time")

	# Both ways, because the host and the guest run the same code down different
	# branches and only one of them was just proved.
	host.shout(Vector2(-7.25, 3.5), 12.0, 1100.0)
	await _until_heard(guest, 1)
	_says(guest.drain_heard().size() == 1, "and it crosses the other way too")

	# In order, once each.
	for i in 3:
		guest.shout(Vector2(float(i), 0.0), 30.0, 1100.0)
	await _until_heard(host, 3)
	var three: Array = host.drain_heard()
	var ordered := three.size() == 3
	if ordered:
		for i in 3:
			if not is_equal_approx((three[i][0] as Vector2).x, float(i)):
				ordered = false
	_says(ordered, "three events arrived in the order they were sent")

	# The heartbeat, which is the only thing that notices a peer that has gone
	# quiet without hanging up. **2 Hz here, because there is no body yet**: a
	# session with nothing moving to draw beats slowly, and twenty a second is
	# for a body in motion.
	var before: int = host.heartbeats_heard()
	await _wait(1.6)
	var after: int = host.heartbeats_heard()
	_says(after >= before + 2 and after <= before + 6,
		"state frames keep arriving (%d then %d -- the 2 Hz beat of a session"
		% [before, after] + " with no body in it)")
	_says(host.quiet_for() >= 0.0 and host.quiet_for() < 1.0
			and host.peers_say() == "within earshot",
		"and the other cell reads as present, not quiet")

	# ----------------------------------------------------------------------
	# **The body, crossing on the state frames.** Protocol 2 put the place on
	# the beat; protocol 3 puts the motion beside it and sends it twenty times a
	# second, and at once when the body jumps.
	# ----------------------------------------------------------------------
	_says(host.peer_track().is_empty(),
		"a session with no run behind it reports no body at all")

	guest.report_body(Vector2(320.0, -180.0), 1.25, 31.0)
	await _until_tracked(host, 1)
	var track: Array = host.peer_track()
	var first := not track.is_empty()
	if first:
		var newest: Array = track[track.size() - 1]
		first = newest.size() == 6 \
			and (newest[1] as Vector2).is_equal_approx(Vector2(320.0, -180.0)) \
			and is_equal_approx(float(newest[3]), 31.0) \
			and absf(angle_difference(float(newest[2]), 1.25)) \
				<= TAU / float(Wire.BEARING_STEPS) \
			and (newest[4] as Vector2) == Vector2.ZERO and float(newest[5]) == 0.0
	_says(first, "the other cell's place, heading, radius and stillness crossed"
		+ " the wire")

	# **At the body rate, which is the claim.** A body moving exactly as it says
	# it is moving -- reported with the velocity it really has -- goes out twenty
	# times a second: not at this probe's frame rate, which is thousands, and
	# not at the old 2 Hz. And nothing goes early, because the far end's guess
	# is never wrong.
	var start := Vector2(320.0, -180.0)
	var speed := Vector2(40.0, 0.0)
	var from := _now()
	var rate := 0
	var seen: Array = []
	var sent_before: int = guest._out_state_seq
	while _now() < from + 2.2:
		guest.report_body(start + speed * (_now() - from), 0.0, 31.0, speed, 0.0)
		var now_track: Array = host.peer_track()
		if not now_track.is_empty():
			var x: float = (now_track[now_track.size() - 1][1] as Vector2).x
			if seen.is_empty() or not is_equal_approx(float(seen[seen.size() - 1]), x):
				seen.append(x)
				rate += 1
		await get_tree().process_frame
	var sent: int = guest._out_state_seq - sent_before
	_says(rate >= 30 and rate <= 60,
		"%d distinct places landed in 2.2 s -- 20 a second, not the frame rate"
		% rate + " and not the old 2 Hz")
	_says(sent <= 2 + int(ceilf(2.2 / NetSession.STATE_PERIOD)),
		"and a body moving just as it said sent nothing early (%d frames)" % sent)
	_says(host.peer_track().size() == NetSession.TRACK_MAX,
		"and the track holds exactly the %d a view needs" % NetSession.TRACK_MAX)
	var climbs := true
	var climbing: Array = host.peer_track()
	for i in range(1, climbing.size()):
		if float(climbing[i][0]) < float(climbing[i - 1][0]):
			climbs = false
		if (climbing[i][1] as Vector2).x <= (climbing[i - 1][1] as Vector2).x:
			climbs = false
	_says(climbs, "oldest first, and the newest place is the newest one sent")

	# **A jump leaves in the call that reports it.** Deterministic, so it is
	# asserted on the sender rather than timed across a socket: a frame has
	# just gone, the next is not due for most of a period, a report that says
	# nothing new sends nothing -- and a report with a new velocity in it sends
	# one there and then, carrying that velocity. That is the whole of "send
	# immediately on an impulse", and the difference between a jump drawn in
	# the frame it lands and one drawn up to a period later.
	#
	# **Reported every frame throughout, as a run reports.** A frame with no
	# report in it is a body the run has stopped simulating, and the session
	# says so at once with a frame of no motion -- so a probe that paused its
	# reports to wait would be testing a pause, not a jump.
	var quiet_ok := false
	var jumped := false
	var jump := Vector2(40.0 + 150.0, 0.0)
	var jumped_at := Vector2.ZERO
	var jumped_when := 0.0
	for attempt in 20:
		var went: int = guest._out_state_seq
		while guest._out_state_seq == went:
			guest.report_body(start + speed * (_now() - from), 0.0, 31.0, speed, 0.0)
			await get_tree().process_frame
		var left := _now()
		while _now() - left < 0.02:
			guest.report_body(start + speed * (_now() - from), 0.0, 31.0, speed, 0.0)
			await get_tree().process_frame
		if _now() - left > NetSession.STATE_PERIOD * 0.6 \
				or guest._out_state_seq != went + 1:
			continue
		var calm: int = guest._out_state_seq
		jumped_at = start + speed * (_now() - from)
		jumped_when = _now()
		guest.report_body(jumped_at, 0.0, 31.0, speed, 0.0)
		quiet_ok = guest._out_state_seq == calm
		guest.report_body(jumped_at, 0.0, 31.0, jump, 0.0)
		jumped = guest._out_state_seq == calm + 1 \
			and (guest._told[4] as Vector2).is_equal_approx(jump)
		break
	_says(quiet_ok, "a report with nothing new in it between two beats sends nothing")
	_says(jumped, "a report with a jump in it sends a frame at once, carrying"
		+ " the jump")
	var landed_jump := false
	var until_jump := _now() + SETTLE
	while _now() < until_jump:
		guest.report_body(jumped_at + jump * (_now() - jumped_when), 0.0, 31.0,
			jump, 0.0)
		var jump_track: Array = host.peer_track()
		if not jump_track.is_empty() \
				and (jump_track[jump_track.size() - 1][4] as Vector2).is_equal_approx(jump):
			landed_jump = true
			break
		await get_tree().process_frame
	_says(landed_jump, "and the far end has the jump's velocity to carry the"
		+ " body forward by")

	# **Drain to newest, and it is not hypothetical any more.** State frames go
	# out unreliable now, and ENet hands an unreliable frame over whenever it
	# lands -- a late one after its successor. Loopback will not reorder on
	# demand, so the frames go straight into the decoder. Reaching for a
	# private member is a thing only tools/ may do.
	var bench := {"greeted": true, "alive": true, "in_state": -1,
		"in_event": -1, "track": []}
	host._take_state(bench, Wire.state(9, true, Vector2(9.0, 0.0), 0.0, 20.0))
	host._take_state(bench, Wire.state(7, true, Vector2(-700.0, 0.0), 0.0, 20.0))
	host._take_state(bench, Wire.state(9, true, Vector2(-900.0, 0.0), 0.0, 20.0))
	host._take_state(bench, Wire.state(10, true, Vector2(10.0, 0.0), 0.0, 20.0))
	var bench_track: Array = bench["track"]
	var newest_wins := bench_track.size() == 2 \
		and is_equal_approx((bench_track[0][1] as Vector2).x, 9.0) \
		and is_equal_approx((bench_track[1][1] as Vector2).x, 10.0) \
		and int(bench["in_state"]) == 10
	_says(newest_wins,
		"a sequence behind the newest is dropped, and so is a repeat of it")
	host._take_state(bench, Wire.state(12, true, Vector2(12.0, 0.0), 0.0, 20.0,
		Vector2(30.0, -40.0), 0.5))
	var moving: Array = (bench["track"] as Array).back()
	_says(moving.size() == 6 and (moving[4] as Vector2).is_equal_approx(Vector2(30.0, -40.0))
			and is_equal_approx(float(moving[5]), 0.5),
		"and a frame's motion is kept with its place, for the view to carry")

	# The far cell died. Not a gap in the stream -- an answer -- so the marker
	# goes out rather than ageing.
	host._take_state(bench, Wire.state(13, false))
	_says((bench["track"] as Array).is_empty(),
		"a frame with no body in it clears the track rather than holding one")

	guest.forget_body()
	await _until_tracked(host, 0)
	_says(host.peer_track().is_empty(),
		"and a run that ends stops the marker across the wire")

	host.close()
	guest.close()
	await _wait(0.6)


# ---------------------------------------------------------------------------
# Version skew. The highest-value assertion in this file.
# ---------------------------------------------------------------------------

func _check_skew() -> void:
	# **No older protocol is a hypothetical.** 1 is the LAN build that first
	# shipped, 2 is the one that drew the friend half a second late, and 3 is
	# the one with a friend who cannot eat you and no pond; all of them are on
	# somebody's phone right now, because updates are opt-in, and a 3 reads a
	# POND frame as a kind it has never heard of. The one from the future is
	# still worth its two seconds: the host cannot tell which side is behind,
	# and does not need to.
	for theirs: int in [Wire.PROTOCOL - 3, Wire.PROTOCOL - 2, Wire.PROTOCOL - 1,
			Wire.PROTOCOL + 1]:
		await _one_skew(theirs)


func _one_skew(theirs: int) -> void:
	var host: Node = await _session("HostSide2_%d" % theirs)
	var guest: Node = await _session("GuestSide2_%d" % theirs)
	# Updates are opt-in (multiplayer.md §0.1), so the gap between two installs
	# is unbounded and permanent, and this is the only thing standing between
	# that and a hang.
	guest.protocol_override = theirs

	host.host()
	guest.join("127.0.0.1")
	await _until_link(guest, NetSession.Link.REFUSED)

	_says(int(guest.link) == NetSession.Link.REFUSED,
		"a guest on protocol %d is refused by a host on %d"
		% [theirs, Wire.PROTOCOL])
	_says(guest.trouble == "different versions",
		"the guest is told which of the two problems it has: '%s'" % guest.trouble)
	_says(guest.because.contains("launcher") and guest.because.contains("update"),
		"and is told what to do about it: '%s'" % guest.because)
	_says(guest.because.contains("yours" if theirs < Wire.PROTOCOL else "theirs"),
		"and told which of the two of them is the old one")
	_says(int(host.link) != NetSession.Link.TOGETHER,
		"the host never joined itself to a peer it refused")
	_says(host.peer_count() == 0, "and dropped it from its bookkeeping")
	_says(host.trouble == "different versions",
		"the host is told as well -- it may be the one holding the old build")
	_says(guest.heard.is_empty() and guest.peer_track().is_empty(),
		"nothing from a refused peer reached the game -- no shout, no marker")

	host.close()
	guest.close()
	await _wait(0.4)


# ---------------------------------------------------------------------------
# The whole way through: a real run, a real session, a real membrane.
#
# Everything above stops at net_session.gd's front door. This is the only check
# that crosses the seam -- a shout goes on the wire from one cell and comes out
# of `signal_bus.ping()` on the other as a mark on a membrane, through
# `_hear_others()`, which is the function the feature is.
# ---------------------------------------------------------------------------

const RUN_SCENE := "res://game/normal/normal_mode.tscn"
## Far enough that the bearing is unambiguous, near enough to be inside a
## tier-1 ampulla's 1100 units of reach.
const SHOUT_FROM := Vector2(0.0, -400.0)


func _check_run() -> void:
	# The other cell hosts; this one joins. `NetSession.current` ends up the
	# joiner because it was made second, which is what the run will pick up.
	var other: Node = await _session("OtherCell")
	other.host()
	var mine: Node = await _session("MyCell")
	mine.join("127.0.0.1")
	await _until_link(mine, NetSession.Link.TOGETHER)

	var run: Node = load(RUN_SCENE).instantiate()
	# **Before it enters the tree**, which is where `normal_mode.gd` reads it.
	# Forced rather than inherited: the view is remembered in `user://`, so a
	# probe that took whatever was last chosen would assert about the marker on
	# some machines and about nothing on others.
	run.mode = 1
	get_tree().root.add_child.call_deferred(run)
	await run.ready
	await get_tree().process_frame

	# An `ampulla`, because `signal_bus.ping()` refuses to draw a mark for a
	# cell that has no organ to hear one with -- the same guard that keeps a
	# solo eyeless cell from being told things, enforced in the bus and not
	# here. Reaching for a private member is a thing only tools/ may do.
	var genome: Node = run.get_node(^"Genome")
	genome.express({&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		&"ampulla": 1}, [&"cytostome", &"cirrus", &"flagellum", &"ampulla"])
	var cell: Node = run.get_node(^"Cell")
	cell.position = Vector2.ZERO
	cell.heading = 0.0
	await get_tree().process_frame

	var bus: Node = run.get_node(^"Membrane").bus
	var marks: Array[Dictionary] = []
	bus.sensation.connect(func(kind: StringName, info: Dictionary) -> void:
		if kind == &"ping":
			marks.append(info))

	# Dead ahead is heading 0, and the other cell is due north of this one, so
	# the mark has to land at bearing 0. A mark that arrives at some other
	# bearing is a frame-of-reference bug, which is the one bug this whole
	# conversion exists not to have.
	marks.clear()
	other.shout(SHOUT_FROM, 34.0, 1100.0)
	await _hold(cell, Vector2.ZERO, 0.0, 0.5)
	var heard := not marks.is_empty()
	_says(heard, "a shout crossed the wire and reached the membrane as a mark")
	if heard:
		var mark: Dictionary = marks[0]
		var bearing := float(mark["bearing"])
		_says(absf(angle_difference(bearing, 0.0)) < 0.01,
			"and it is at the bearing the other cell actually is: %.3f rad"
			% bearing)
		_says(float(mark["strength"]) > 0.0 and float(mark["halfwidth"]) > 0.0
				and float(mark["hold"]) > 0.0,
			"with a level, a width and a hold off food.gd's own tables"
			+ " (%.2f / %.1f deg / %.2f s)" % [float(mark["strength"]),
				float(mark["halfwidth"]), float(mark["hold"])])

	# Turn the cell a quarter turn to starboard and the same shout must move a
	# quarter turn to port on the membrane. This is the whole of "one water, one
	# frame of reference" in one assertion.
	marks.clear()
	cell.heading = PI * 0.5
	await get_tree().process_frame
	other.shout(SHOUT_FROM, 34.0, 1100.0)
	await _hold(cell, Vector2.ZERO, PI * 0.5, 0.5)
	var turned := not marks.is_empty()
	if turned:
		var bearing := float(marks[0]["bearing"])
		turned = absf(angle_difference(bearing, -PI * 0.5)) < 0.01
	_says(turned, "turning the cell 90 degrees moves the mark 90 the other way")

	# Out of earshot: past the shouter's own reach, nothing is heard at all.
	marks.clear()
	other.shout(Vector2(0.0, -4000.0), 34.0, 1100.0)
	await _hold(cell, Vector2.ZERO, PI * 0.5, 0.5)
	_says(marks.is_empty(),
		"a shout from beyond the shouter's own reach is not heard")

	# ----------------------------------------------------------------------
	# **The marker, all the way to the thing that draws it.** Everything above
	# stops at the session's front door or at the membrane. This crosses the
	# last seam: a body reported on one session has to come out of the world
	# view's own per-frame arithmetic as a place on this screen.
	#
	# It is asserted off `_peer` rather than off a render because **CI has no
	# pixels to look at**. Under `--headless` the draw routines do run -- 1,920
	# `draw` signals in 1,920 frames, measured -- but into a renderer that keeps
	# nothing, so a peer marker checked only by screenshot would be a feature CI
	# executes and never once checks. That is why every number the draw
	# routines use is computed in `_step_peer`, where this can read it.
	# ----------------------------------------------------------------------
	var view: Node = run.get_node(^"Vision")
	_says(view.is_active(), "the run this probe built is in full vision")
	other.report_body(Vector2(0.0, -260.0), 0.0, 29.0)
	await _hold(cell, Vector2.ZERO, 0.0, 1.4)
	var mark: Dictionary = view._peer
	var drawn := not mark.is_empty()
	_says(drawn, "full vision worked out where the other player is")
	if drawn:
		_says((mark["at"] as Vector2).distance_to(Vector2(0.0, -260.0)) < 1.0,
			"and it is the place they reported, in this cell's own frame"
			+ " (%.1f, %.1f)" % [(mark["at"] as Vector2).x, (mark["at"] as Vector2).y])
		_says(is_equal_approx(float(mark["radius"]), 29.0)
				and float(mark["confidence"]) > 0.99
				and float(mark["doubt"]) <= 0.0,
			"at their real radius, at full confidence, with no doubt circle yet")

	# ----------------------------------------------------------------------
	# **The lag, locked.** The owner's report as an assertion: a friend's dash
	# has to be drawn on this screen within DASH_ONSET_MAX of starting on
	# theirs. The far end is played the way the run plays it -- a body at
	# rest, then a tier-1 dash's 190 units a second along its nose, reported
	# every frame with the water's drag on it -- and the time is read off
	# `_peer`, which is what the draw routines use, against when the far body
	# itself had moved as far. Three dashes; the worst one counts.
	# ----------------------------------------------------------------------
	var worst_first := 0.0
	var worst_plain := 0.0
	for trial in 3:
		var onset: Array = await _dash_onset(other, view, cell, Vector2(0.0, -260.0))
		worst_first = maxf(worst_first, float(onset[0]))
		worst_plain = maxf(worst_plain, float(onset[1]))
	_says(worst_first < DASH_ONSET_MAX,
		"a friend's dash is drawn here within %.0f ms of starting"
		% (DASH_ONSET_MAX * 1000.0)
		+ " (first 2 units: worst of 3 %.1f ms)" % (worst_first * 1000.0))
	_says(worst_plain < DASH_ONSET_MAX,
		"and is unmistakable inside the same bound (20 units: worst of 3"
		+ " %.1f ms) -- half a second of buffer fails this" % (worst_plain * 1000.0))

	# ----------------------------------------------------------------------
	# **#50's reason, kept.** The far body is still coasting out of that last
	# dash when its phone goes in a pocket: the far session stops dead, which
	# is what `onActivityStopped` does to a main loop, and nothing more is
	# sent. The marker is carried PEER_REACH along the last velocity it had and
	# then held -- and past PEER_FRESH the fade and the doubt ring take over at
	# #50's own moments and rates, around a marker that does not move.
	# ----------------------------------------------------------------------
	#
	# Measured against the last frame this end *received*, not the last one
	# the far end sent: state frames are unreliable now, so the two need not be
	# the same frame, and a lost one is the design working -- not what this
	# check is about.
	other.set_process(false)
	await _hold(cell, Vector2.ZERO, 0.0, 0.5)
	var last: Array = mine.peer_track().back() if not mine.peer_track().is_empty() else []
	var last_at: Vector2 = last[1] if last.size() == 6 else Vector2(NAN, NAN)
	var last_speed: float = (last[4] as Vector2).length() if last.size() == 6 else 0.0
	var frozen: Vector2 = view._peer["at"]
	await _hold(cell, Vector2.ZERO, 0.0, 0.2)
	var carried_by := frozen.distance_to(last_at)
	var reach_by := last_speed * VisionLayer.PEER_REACH
	_says(last_speed > 50.0 and absf(carried_by - reach_by) < 1.5
			and (view._peer["at"] as Vector2).is_equal_approx(frozen),
		"a friend who goes silent mid-dash is carried %.1f units -- %.2f s of"
		% [carried_by, VisionLayer.PEER_REACH]
		+ " their last %.0f units a second -- and then held still" % last_speed)
	# Long enough past PEER_FRESH for the fade to be under way, and past
	# TRACK_GAP -- two seconds from the last frame -- for the step below.
	await _hold(cell, Vector2.ZERO, 0.0, 1.45)
	var ghost: Dictionary = view._peer
	var ladder := CellBody.IMPULSE_SPEED_BY_TIER
	var top: float = ladder[ladder.size() - 1]
	var silent: float = mine.quiet_for()
	var doubt: float = float(ghost["doubt"])
	var lost := clampf((doubt / top) / (VisionLayer.PEER_LOST - VisionLayer.PEER_FRESH),
		0.0, 1.0)
	var fade := VisionLayer.PEER_FLOOR + (1.0 - VisionLayer.PEER_FLOOR) \
		* (1.0 - lost) * (1.0 - lost)
	_says(silent > VisionLayer.PEER_FRESH + 0.5
			and absf(doubt - (silent - VisionLayer.PEER_FRESH) * top) < 5.0
			and is_equal_approx(float(ghost["confidence"]), fade)
			and float(ghost["confidence"]) < 1.0
			and (ghost["at"] as Vector2).is_equal_approx(frozen),
		("and the quiet state is #50's: %.1f s of silence, a doubt ring of %.0f"
			+ " units at %.0f a second, confidence %.2f on the squared curve,"
			+ " and the marker has not moved")
			% [silent, doubt, top, float(ghost["confidence"])])

	# **Past TRACK_GAP of silence, the next frame lands as a step**, as it did
	# in #50: blending across a pocket would animate a journey nobody made.
	# Re-enabled and reported in one breath, so the first frame after the gap
	# is this one and not a held frame from the far session's own beat -- and
	# a second frame goes straight after it, because a phone out of a pocket
	# can land two in one poll, and then the track holds two frames that
	# continue *each other* while the marker is still on one from before the
	# silence. A view that trusted the track's length would slide.
	other.set_process(true)
	var back_at := Vector2(180.0, -300.0)
	other.report_body(back_at, 0.0, 29.0)
	other._beat(other.clock())
	var stepped := false
	var until_step := _now() + SETTLE
	while _now() < until_step:
		_pin(cell)
		await get_tree().process_frame
		var now_drawn: Vector2 = view._peer["at"]
		if now_drawn.distance_to(back_at) < 0.01:
			stepped = true
			break
		if now_drawn.distance_to(frozen) > 0.01:
			break
	_says(stepped, "after %.0f s of silence the next frame lands as a step,"
		% NetSession.TRACK_GAP + " not a slide across the gap")

	# **A correction is blended, never snapped.** The far body turns up thirty
	# units from where the marker is -- a badly mispredicted jump -- and in the
	# frame that says so the marker stays exactly where it was, the whole
	# difference held as an offset to be bled out. Asserted on that one frame
	# rather than timed, so it holds at any frame rate a CI runner produces.
	await _hold(cell, Vector2.ZERO, 0.0, 0.3)
	var before_fix: Vector2 = view._peer["at"]
	var shifted := back_at + Vector2(30.0, 0.0)
	var old_basis: Array = view._peer_basis
	other.report_body(shifted, 0.0, 29.0)
	var arrived := Vector2(NAN, NAN)
	var in_flight := Vector2(NAN, NAN)
	var until_fix := _now() + SETTLE
	while _now() < until_fix:
		_pin(cell)
		await get_tree().process_frame
		if not is_same(view._peer_basis, old_basis):
			arrived = view._peer["at"]
			in_flight = view._peer_offset
			break
	_says(arrived.is_finite() and arrived.distance_to(before_fix) < 0.5
			and in_flight.distance_to(before_fix - shifted) < 0.5,
		"a 30-unit correction is not taken in the frame it lands: the marker"
		+ " stays put, holding (%.1f, %.1f) to bleed out" % [in_flight.x, in_flight.y])
	await _hold(cell, Vector2.ZERO, 0.0, 0.5)
	_says((view._peer["at"] as Vector2).distance_to(shifted) < 0.1,
		"and all of it is taken back out within half a second (%.3f units left)"
		% (view._peer["at"] as Vector2).distance_to(shifted))

	# **And the whole point of "full vision only".** A second run in point of
	# view, on the same wire, with the same body reported on it: the view never
	# comes on and the marker is never worked out, because there a friend is
	# only ever heard.
	var blind: Node = load(RUN_SCENE).instantiate()
	blind.mode = 0
	get_tree().root.add_child.call_deferred(blind)
	await blind.ready
	other.report_body(Vector2(0.0, -260.0), 0.0, 29.0)
	await _wait(1.4)
	var blind_view: Node = blind.get_node(^"Vision")
	_says(not blind_view.is_active() and (blind_view._peer as Dictionary).is_empty(),
		"point of view never draws one, and never even works one out")
	blind.queue_free()

	run.queue_free()
	other.close()
	mine.close()
	await _wait(0.4)


# ---------------------------------------------------------------------------
# **pond-field: the water learns a second player, with no wire**
# (shared-pond.md §5, Phase 1). One host field with a person this probe drives,
# and one mirror fed that field's own snapshots.
#
# No socket and no tree: every frame here is `_process(1/60)` called by hand, so
# a minute of water costs its arithmetic -- seconds -- and not a minute of wall
# time, and no frame of CI's 20000 is spent on it. The global stream is seeded
# before every field, so a failure here is the same failure on every machine.
#
# Every field is a [WatchedFood], which counts any seed, retirement or meal
# that touches the person's slot -- the one thing §1.2 says can never happen to
# a person -- and the last check below is that nothing did, across everything
# the section put the water through.
# ---------------------------------------------------------------------------

const POND_STEP := 1.0 / 60.0
## Tier 2 of the four senses and a palp, so that every organ the mirror is held
## to has something to report.
const POND_SENSES := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
	&"chemocyte": 2, &"ampulla": 2, &"ocellus": 2, &"stigma": 1, &"palp": 2}


## The tiers a genome node would answer, for a cell this probe builds by hand.
class StubGenome extends Node:
	var body := {}

	func tier(gene: StringName) -> int:
		return int(body.get(gene, 0))

	func tiers() -> Dictionary:
		return body


## **The field, watched.** A seed, a seed-for, a retirement on the person's
## slot, or a meal with a person on either side, is counted -- and must never
## be, however the water got there.
class WatchedFood extends "res://game/normal/food.gd":
	var touched_person := 0

	func _seed(index: int) -> void:
		if index == PERSON_SLOT:
			touched_person += 1
		super._seed(index)

	func _seed_for(index: int, anchor: int, drifter: bool = false) -> void:
		if index == PERSON_SLOT:
			touched_person += 1
		super._seed_for(index, anchor, drifter)

	func _retire(index: int) -> void:
		if index == PERSON_SLOT:
			touched_person += 1
		super._retire(index)

	func _devour(b: Body, prey: Body) -> void:
		var slot: Body = _cells[PERSON_SLOT] if _cells.size() > PERSON_SLOT else null
		if b.person != null or prey.person != null or b == slot or prey == slot:
			touched_person += 1
		super._devour(b, prey)


var _pond_nodes: Array[Node] = []
var _pond_fields: Array = []


func _check_pond_field() -> void:
	var from := _clock()
	_pond_swallow_rule()
	_pond_friends()
	_pond_to_the_death()
	_pond_rings()
	_pond_ties()
	_pond_out_of_water()
	_pond_mirror()
	_pond_housekeeping()
	var touched := 0
	for field: Node in _pond_fields:
		touched += int(field.get("touched_person"))
	_says(touched == 0 and _pond_fields.size() >= 10,
		"pond-field: slot 68 never reached _seed, _seed_for, _retire or _devour"
		+ " in %d fields (%d times)" % [_pond_fields.size(), touched])
	for node: Node in _pond_nodes:
		if is_instance_valid(node):
			node.free()
	_pond_nodes.clear()
	_pond_fields.clear()
	print("[net-probe] NOTE pond-field took %.1f s of wall time and no frames"
		% (_clock() - from))


## A field about a cell of [param radius] wearing [param tiers] at [param at],
## seeded from [param from_seed] -- the whole of what the run hands it, done by
## hand. The organs are set as the run sets them every frame.
func _pond_rig(from_seed: int, radius: float, tiers: Dictionary,
		at: Vector2 = Vector2.ZERO, heading: float = 0.0) -> Node:
	seed(from_seed)
	var genome := StubGenome.new()
	genome.body = tiers.duplicate()
	var cell: Node = CellBody.new()
	cell.genome = genome
	cell.radius = radius
	cell.position = at
	cell.heading = heading
	var field: Node = WatchedFood.new()
	field.setup(cell)
	field.smell_range = cell.smell_range()
	field.smell_bearing = 0.0
	field.beam_range = cell.beam_range()
	field.beam_bearings = PackedFloat32Array([-0.2, 0.2]) \
		if cell.beam_range() > 0.0 else PackedFloat32Array()
	field.ping_range = cell.ping_range()
	field.ping_period = cell.ping_period()
	field.ping_bearing = 0.0
	field.ping_through = cell.ping_through()
	field.ping_tier = cell.ping_tier()
	field.touch_range = CellBody.TOUCH_RANGE_BY_TIER[mini(cell.extra(&"palp"), 3)]
	_pond_nodes.append_array([genome, cell, field])
	_pond_fields.append(field)
	return field


## Everything the field says, in order.
func _pond_listen(field: Node) -> Array:
	var said: Array = []
	field.person_touched.connect(func(what: int, at: Vector2, level: float,
			by: int, gene: StringName) -> void:
		said.append(["touched", what, at, level, by, gene]))
	field.person_died.connect(func(cause: int, by: int, at: Vector2) -> void:
		said.append(["died", cause, by, at]))
	field.eaten.connect(func(n: float, gene: StringName, at: Vector2) -> void:
		said.append(["eaten", n, gene, at]))
	field.bitten.connect(func(b: float, strength: float) -> void:
		said.append(["bitten", b, strength]))
	field.killed.connect(func(b: float) -> void: said.append(["killed", b]))
	field.stung.connect(func(b: float) -> void: said.append(["stung", b]))
	return said


func _pond_said(said: Array, kind: String, what: int = -1) -> Array:
	for entry: Array in said:
		if entry[0] == kind and (what < 0 or int(entry[1]) == what):
			return entry
	return []


## The heading that points a body at [param from] toward [param to].
func _pond_face(from: Vector2, to: Vector2) -> float:
	var v := to - from
	return atan2(v.x, -v.y)


## `food.gd`'s own flank angle, worked out here from the outside.
func _pond_flank(heading: float, target: Vector2, mouth: Vector2) -> float:
	var v := mouth - target
	return absf(angle_difference(heading, atan2(v.x, -v.y)))


## Water slot [param i], made into a calm body of [param radius] wearing
## [param tiers] at [param at], facing [param heading].
func _pond_pose(field: Node, i: int, radius: float, tiers: Dictionary,
		at: Vector2, heading: float) -> Object:
	var b: Object = field.bodies()[i]
	b.radius = radius
	b.genome = tiers.duplicate()
	b.drifter = tiers.is_empty()
	b.seeded = true
	b.pos = at
	b.heading = heading
	b.state = FoodField.State.DRIFT
	b.target = FoodField.TARGET_NONE
	b.calm = 999.0
	b.wound = 0.0
	b.bite = 0.0
	b.aim = at
	b.flee_from = at
	return b


## ...on a run at the person, committed.
func _pond_hunt(field: Node, b: Object) -> void:
	var pb: Object = field.bodies()[FoodField.PERSON_SLOT]
	b.state = FoodField.State.STALK
	b.target = FoodField.PERSON_SLOT
	b.target_serial = pb.serial
	b.aim = pb.pos
	b.aim_clock = 0.0
	b.lunging = false
	b.best = INF
	b.lost = 0.0
	b.rush = 0.0
	b.stale = 0.0
	b.stroke = 5.0


func _pond_person(field: Node, at: Vector2, radius: float, tiers: Dictionary,
		heading: float = 0.0) -> void:
	var order: Array = []
	for gene: StringName in tiers:
		order.append(gene)
	field.set_person_genome(tiers, order)
	field.place_person(at, heading, radius)


# --- §1.3, rows one and two: a water cell's mouth on the person -------------

func _pond_swallow_rule() -> void:
	var at := Vector2(3000.0, 0.0)
	var hunter_genes := {&"cytostome": 3, &"flagellum": 1}
	var gape := CellBody.gape_of(3, 30.0)
	# Committed, and they fit: gone, in the frame it happens.
	var field := _pond_rig(11, 30.0, POND_SENSES)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var said := _pond_listen(field)
	var from := at + Vector2(0.0, -54.0)
	var b := _pond_pose(field, 5, 30.0, hunter_genes, from, _pond_face(from, at))
	_pond_hunt(field, b)
	var reaches := Cilia.mouth_touches(b.pos, b.heading, 30.0, gape, at, 28.0)
	field._process(POND_STEP)
	var died := _pond_said(said, "died")
	_says(reaches and not died.is_empty()
			and int(died[1]) == FoodField.Cause.SWALLOWED
			and int(died[2]) == FoodField.By.WATER
			and not _pond_said(said, "touched", FoodField.Contact.KILLED).is_empty()
			and field.person() == null
			and not field.bodies()[FoodField.PERSON_SLOT].seeded,
		"pond-field: a committed cell whose gape fits the person swallows them,"
		+ " and slot 68 is empty that frame")

	# The same mouth, not committed -- they have just arrived, so nothing may
	# commit to them yet -- only bites. Astern, through two tiers of pellicle
	# and into two of toxicyst, so every term of the bite is in the number.
	field = _pond_rig(12, 30.0, POND_SENSES)
	field.open_pond()
	var armoured := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		&"pellicle": 2, &"toxicyst": 2}
	_pond_person(field, at, 28.0, armoured)
	said = _pond_listen(field)
	from = at + Vector2(0.0, 54.0)
	b = _pond_pose(field, 5, 30.0, hunter_genes, from, _pond_face(from, at))
	field._process(POND_STEP)
	var bit := _pond_said(said, "touched", FoodField.Contact.BITTEN)
	var person: Object = field.bodies()[FoodField.PERSON_SLOT]
	var expected := 0.0
	var back := 0.0
	if not bit.is_empty():
		expected = CellBody.bite_damage(3, gape, 28.0, 2,
			_pond_flank(0.0, at, bit[2] as Vector2))
		back = CellBody.venom_back(2, expected)
	_says(field.person() != null and _pond_said(said, "died").is_empty()
			and not bit.is_empty() and 28.0 * CellBody.ARMOR_BY_TIER[2] < gape,
		"pond-field: an uncommitted cell whose gape fits them only bites")
	_says(not bit.is_empty() and absf(float(person.wound) - expected) < 1e-9
			and absf(float(b.wound) - back) < 1e-9 and expected > 0.0
			and is_equal_approx(float(bit[3]), clampf(expected
				/ CellBody.BITE_BY_TIER[3], FoodField.BITE_HIT_FLOOR, 1.0)),
		"pond-field: the chew is bite_damage for that gape, pellicle and flank"
		+ " (%.5f, astern), with %.5f of venom back on the biter"
		% [float(person.wound), float(b.wound)])

	# Committed, and they carry venom: spat out, and the cell is gone.
	field = _pond_rig(13, 30.0, POND_SENSES)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"flagellum": 1,
		&"toxicyst": 1})
	said = _pond_listen(field)
	from = at + Vector2(0.0, -54.0)
	b = _pond_pose(field, 5, 30.0, hunter_genes, from, _pond_face(from, at))
	_pond_hunt(field, b)
	var serial := int(b.serial)
	field._process(POND_STEP)
	_says(field.person() != null and _pond_said(said, "died").is_empty()
			and not _pond_said(said, "touched", FoodField.Contact.STUNG).is_empty()
			and int(b.serial) != serial,
		"pond-field: a committed cell that swallows a venomous person is retired,"
		+ " and they are stung, not killed")


# --- §1.3, the last row: one player's mouth on the other ---------------------

func _pond_friends() -> void:
	# This cell, a tier-3 mouth (gape 42), nose to the person's tail.
	var gape := CellBody.gape_of(3, 30.0)
	var mouth := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1}
	var field := _pond_rig(21, 30.0, mouth)
	field.open_pond()
	var at := Vector2(0.0, -54.0)
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var said := _pond_listen(field)
	var reaches := Cilia.mouth_touches(Vector2.ZERO, 0.0, 30.0, gape, at, 28.0)
	field._process(POND_STEP)
	var ate := _pond_said(said, "eaten")
	var died := _pond_said(said, "died")
	_says(reaches and not ate.is_empty() and not died.is_empty()
			and int(died[1]) == FoodField.Cause.SWALLOWED
			and int(died[2]) == FoodField.By.FRIEND
			and is_equal_approx(float(ate[1]), 28.0 / 30.0)
			and field.person() == null,
		"pond-field: a friend whose armoured radius fits this mouth is swallowed"
		+ " with no commitment, and fed %.3f of a meal" % (float(ate[1]) if ate else 0.0))

	# The same friend armoured past the gape: chewed instead, from astern.
	field = _pond_rig(22, 30.0, mouth)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		&"pellicle": 3})
	said = _pond_listen(field)
	field._process(POND_STEP)
	var person: Object = field.bodies()[FoodField.PERSON_SLOT]
	var expected := CellBody.bite_damage(3, gape, 28.0, 3,
		_pond_flank(0.0, at, Vector2.ZERO))
	var felt := _pond_said(said, "bitten")
	var chewed := _pond_said(said, "touched", FoodField.Contact.BITTEN)
	_says(field.person() != null and 28.0 * CellBody.ARMOR_BY_TIER[3] > gape
			and absf(float(person.wound) - expected) < 1e-9 and not felt.is_empty()
			and not chewed.is_empty() and int(chewed[4]) == FoodField.By.FRIEND,
		"pond-field: armoured past this gape, the friend is chewed instead"
		+ " (%.5f from astern) and this cell feels its own bite" % float(person.wound))

	# And the other way: their mouth on this cell, which is too big for it.
	var field2 := _pond_rig(23, 30.0, mouth, Vector2.ZERO, PI)
	field2.open_pond()
	_pond_person(field2, at, 28.0, {&"cytostome": 1, &"cirrus": 1,
		&"flagellum": 1}, PI)
	said = _pond_listen(field2)
	field2._process(POND_STEP)
	var cell: Object = field2.get("_cell")
	var their_gape := CellBody.gape_of(1, 28.0)
	var theirs := CellBody.bite_damage(1, their_gape, 30.0, 0,
		absf(cell.bearing_to(at)))
	var hit := _pond_said(said, "bitten")
	var told := _pond_said(said, "touched", FoodField.Contact.BITTEN)
	_says(field2.person() != null and 30.0 > their_gape
			and absf(float(cell.wound) - theirs) < 1e-9 and not hit.is_empty()
			and not told.is_empty()
			and is_equal_approx(float(told[3]), clampf(theirs
				/ CellBody.BITE_BY_TIER[3], FoodField.BITE_HIT_FLOOR, 1.0)
				* FoodField.BITE_FELT_SHARE),
		"pond-field: and the friend's mouth chews this cell back (%.5f, astern),"
		% float(cell.wound) + " each side feeling its own share")


## **Every way one player's contact with the other can end in a death**, and the
## cause each side is told (shared-pond.md §1.3's three unsaid things, and
## Phase 2's "the host learns its own cause of death"): the Phase 1 review ran
## these by hand, and DIED is wired to them now. The host is this field's own
## cell; its cause is `died_of`/`died_by`, written in the instant before
## `killed`.
func _pond_to_the_death() -> void:
	var at := Vector2(0.0, -54.0)
	var plain := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}
	var big := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1}

	# This cell swallows a venomous friend: it is poisoned, and they are stung.
	var field := _pond_rig(81, 30.0, big)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"flagellum": 1, &"toxicyst": 1})
	var said := _pond_listen(field)
	field._process(POND_STEP)
	_says(not _pond_said(said, "killed").is_empty()
			and int(field.died_of) == FoodField.Cause.POISONED
			and int(field.died_by) == FoodField.By.FRIEND
			and not _pond_said(said, "touched", FoodField.Contact.STUNG).is_empty()
			and _pond_said(said, "died").is_empty() and field.person() != null
			and not field.anchored,
		"pond-field: swallowing a venomous friend poisons this cell -- told"
		+ " POISONED by the friend -- and the friend is stung, not eaten")

	# The friend swallows this venomous cell: they are poisoned, it is stung.
	field = _pond_rig(82, 30.0, {&"cytostome": 1, &"cirrus": 1, &"toxicyst": 1},
		Vector2.ZERO, PI)
	field.venom_cost = CellBody.VENOM_COST_BY_TIER[1]
	field.open_pond()
	_pond_person(field, at, 30.0, big, PI)
	said = _pond_listen(field)
	field._process(POND_STEP)
	var died := _pond_said(said, "died")
	_says(not died.is_empty() and int(died[1]) == FoodField.Cause.POISONED
			and int(died[2]) == FoodField.By.FRIEND
			and not _pond_said(said, "stung").is_empty()
			and _pond_said(said, "killed").is_empty() and field.anchored
			and field.person() == null,
		"pond-field: a friend who swallows this venomous cell is poisoned --"
		+ " POISONED by the friend, on their side -- and this cell is stung")

	# This cell chews the friend apart: its meal, their CHEWED.
	field = _pond_rig(83, 30.0, big)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		&"pellicle": 3})
	field.bodies()[FoodField.PERSON_SLOT].wound = 0.99
	said = _pond_listen(field)
	field._process(POND_STEP)
	died = _pond_said(said, "died")
	var ate := _pond_said(said, "eaten")
	_says(not died.is_empty() and int(died[1]) == FoodField.Cause.CHEWED
			and int(died[2]) == FoodField.By.FRIEND and not ate.is_empty()
			and _pond_said(said, "killed").is_empty() and field.person() == null,
		"pond-field: chewing a friend to the end is a meal here and CHEWED by the"
		+ " friend there (%.3f of a meal)" % (float(ate[1]) if ate else 0.0))

	# The friend chews this cell apart: this cell's CHEWED, their meal.
	field = _pond_rig(84, 30.0, plain, Vector2.ZERO, PI)
	field.open_pond()
	_pond_person(field, at, 28.0, plain, PI)
	(field.get("_cell") as Object).set("wound", 0.99)
	said = _pond_listen(field)
	field._process(POND_STEP)
	var fed := _pond_said(said, "touched", FoodField.Contact.ATE)
	_says(not _pond_said(said, "killed").is_empty()
			and int(field.died_of) == FoodField.Cause.CHEWED
			and int(field.died_by) == FoodField.By.FRIEND and not fed.is_empty()
			and int(fed[4]) == FoodField.By.FRIEND and _pond_said(said, "died").is_empty()
			and field.person() != null,
		"pond-field: a friend chewing this cell to the end kills it CHEWED by the"
		+ " friend, and the friend is fed")

	# **The eater's death first.** One bite that would finish both: the venom
	# back finishes this cell, and the friend it was chewing lives.
	field = _pond_rig(85, 30.0, big)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		&"pellicle": 3, &"toxicyst": 3})
	field.bodies()[FoodField.PERSON_SLOT].wound = 0.99
	(field.get("_cell") as Object).set("wound", 0.999)
	said = _pond_listen(field)
	field._process(POND_STEP)
	_says(not _pond_said(said, "killed").is_empty()
			and int(field.died_of) == FoodField.Cause.POISONED
			and int(field.died_by) == FoodField.By.FRIEND
			and _pond_said(said, "died").is_empty()
			and not _pond_said(said, "touched", FoodField.Contact.BITTEN).is_empty()
			and _pond_said(said, "eaten").is_empty() and field.person() != null,
		"pond-field: a bite that would finish both kills the eater first --"
		+ " this cell POISONED, the friend only bitten and not a meal")

	# And the water's three ways, told to this cell as causes too.
	var water := {&"cytostome": 3, &"flagellum": 1}
	field = _pond_rig(86, 30.0, plain)
	field.open_pond()
	var from := Vector2(0.0, -54.0)
	var b := _pond_pose(field, 5, 30.0, water, from, _pond_face(from, Vector2.ZERO))
	b.state = FoodField.State.STALK
	b.target = FoodField.TARGET_PLAYER
	b.stroke = 5.0
	field._process(POND_STEP)
	var swallowed: Array = [int(field.died_of), int(field.died_by)]
	field = _pond_rig(87, 30.0, plain)
	field.open_pond()
	(field.get("_cell") as Object).set("wound", 0.99)
	# Astern: ahead, this cell's own mouth would swallow it first.
	var touching := Vector2(0.0, 48.0)
	_pond_pose(field, 5, 20.0, {&"cytostome": 1, &"flagellum": 1}, touching,
		_pond_face(touching, Vector2.ZERO))
	field._process(POND_STEP)
	var chewed: Array = [int(field.died_of), int(field.died_by)]
	field = _pond_rig(88, 30.0, plain)
	field.open_pond()
	(field.get("_cell") as Object).set("wound", 0.999)
	var ahead := Vector2(0.0, -72.0)
	_pond_pose(field, 5, 44.0, {&"cytostome": 1, &"pellicle": 3, &"toxicyst": 3},
		ahead, 0.0)
	field._process(POND_STEP)
	var poisoned: Array = [int(field.died_of), int(field.died_by)]
	_says(swallowed == [FoodField.Cause.SWALLOWED, FoodField.By.WATER]
			and chewed == [FoodField.Cause.CHEWED, FoodField.By.WATER]
			and poisoned == [FoodField.Cause.POISONED, FoodField.By.WATER],
		"pond-field: and the water's three -- swallowed, chewed apart, poisoned by"
		+ " what it bit -- each reach this cell as its cause, by the water"
		+ " (%s, %s, %s)" % [str(swallowed), str(chewed), str(poisoned)])


# --- §1.4: the water is tuned to each cell -----------------------------------

func _pond_rings() -> void:
	# Apart: each of you has your own 34.
	var field := _pond_rig(31, 30.0, POND_SENSES)
	field.open_pond()
	_pond_person(field, Vector2(4000.0, 0.0), 28.0, POND_SENSES)
	var apart := _pond_run(field, 600)
	var counts: Array = apart[0]
	_says(counts.size() == 2 and int(counts[0]) >= FoodField.COUNT
			and int(counts[1]) >= FoodField.COUNT,
		"pond-field: anchors 4,000 apart each hold >= 34 after 10 s (%s)" % str(counts))

	# Together: one disc, and about one water's worth in it.
	field = _pond_rig(32, 30.0, POND_SENSES)
	field.open_pond()
	_pond_person(field, Vector2(300.0, 0.0), 28.0, POND_SENSES)
	var together := _pond_run(field, 3600)
	_says(int(together[1]) <= 40,
		"pond-field: anchors 300 apart hold <= 40 active after 60 s together"
		+ " (%d; at most %d over the last 50 s)" % [int(together[1]), int(together[2])])
	# The other side of the same bound, so an empty water cannot pass it: the
	# quota still holds for each of you, only now it is met by shared cells.
	var shared: Array = together[0]
	_says(shared.size() == 2 and int(shared[0]) >= FoodField.COUNT
			and int(shared[1]) >= FoodField.COUNT,
		"pond-field: together, each anchor still has >= 34 within reach after"
		+ " 60 s (%s)" % str(shared))
	_says(int(apart[3]) == 0 and int(together[3]) == 0,
		"pond-field: every disc kept a drifter every frame, over 4,200 frames"
		+ " (%d misses)" % (int(apart[3]) + int(together[3])))
	_says(int(apart[4]) == 0 and int(together[4]) == 0
			and int(apart[5]) + int(together[5]) > 60,
		"pond-field: no seed landed within RING_MIN of an anchor"
		+ " (%d seeds, %d inside)" % [int(apart[5]) + int(together[5]),
			int(apart[4]) + int(together[4])])


## [param frames] of water, with the two players kept in it -- a death is a tap
## straight back in, where they were, as §6's row A has it -- and every frame
## checked. Returns `[disc counts, active, most active after the first 10 s,
## frames a disc had no drifter, seeds inside RING_MIN, seeds]`.
func _pond_run(field: Node, frames: int) -> Array:
	var person_at: Vector2 = field.bodies()[FoodField.PERSON_SLOT].pos
	var person_radius: float = field.bodies()[FoodField.PERSON_SLOT].radius
	var dead := [false]
	field.killed.connect(func(_b: float) -> void: dead[0] = true)
	# Taken before the first frame, so the ring the person's arrival seeds at
	# the end of it is checked with everything after.
	var serials := PackedInt64Array()
	for body: Object in field.bodies():
		serials.append(int(body.serial))
	var misses := 0
	var inside := 0
	var seeds := 0
	var most := 0
	var reach := FoodField.CULL * FoodField.CULL
	var ring := FoodField.RING_MIN * FoodField.RING_MIN
	for frame in frames:
		if dead[0]:
			dead[0] = false
			field.enter_water()
		if field.person() == null:
			field.place_person(person_at, 0.0, person_radius)
		field._process(POND_STEP)
		var bodies: Array = field.bodies()
		var anchors: Array[Vector2] = []
		var cell: Object = field.get("_cell")
		if field.anchored:
			anchors.append(cell.position)
		if field.person() != null:
			anchors.append(bodies[FoodField.PERSON_SLOT].pos)
		var drifting := PackedInt32Array()
		drifting.resize(anchors.size())
		var active := 0
		for i in FoodField.PERSON_SLOT:
			var b: Object = bodies[i]
			if not b.seeded:
				serials[i] = int(b.serial)
				continue
			active += 1
			if int(b.serial) != serials[i]:
				serials[i] = int(b.serial)
				seeds += 1
				for a: Vector2 in anchors:
					if (b.pos as Vector2).distance_squared_to(a) < ring:
						inside += 1
			if b.drifter:
				for k in anchors.size():
					if (b.pos as Vector2).distance_squared_to(anchors[k]) <= reach:
						drifting[k] += 1
		for k in anchors.size():
			if drifting[k] == 0:
				misses += 1
		if frame >= 600:
			most = maxi(most, active)
	var counts: Array = []
	var last: Array = field.bodies()
	for a: Vector2 in [field.get("_cell").position, last[FoodField.PERSON_SLOT].pos]:
		var n := 0
		for i in FoodField.PERSON_SLOT:
			if last[i].seeded and (last[i].pos as Vector2).distance_squared_to(a) <= reach:
				n += 1
		counts.append(n)
	var active_now := 0
	for i in FoodField.PERSON_SLOT:
		if last[i].seeded:
			active_now += 1
	return [counts, active_now, most, misses, inside, seeds]


## **Ties take turns** (§6 row 2). Two anchors at one point share every cell,
## so their deficits are equal every time; empty six slots and the six seeds
## that refill them must alternate between the two players' water, starting
## with the one seeded for least recently.
func _pond_ties() -> void:
	var field := _pond_rig(41, 30.0, POND_SENSES)
	field.open_pond()
	# Out of the water, so nothing pushes the two anchors apart: still an
	# anchor, which is all this needs.
	_pond_person(field, Vector2.ZERO, 26.0, {&"cytostome": 1, &"flagellum": 1})
	field.set_person_in_water(false)
	field._process(POND_STEP)
	var emptied := 0
	for i in FoodField.PERSON_SLOT:
		if field.bodies()[i].seeded and emptied < 6:
			emptied += 1
			field.call("_retire", i)
	# Whoever was seeded for least recently goes first; an exact tie is this
	# cell's, the anchor asked first.
	var stamps: PackedInt64Array = field.get("_seeded_for")
	var first := FoodField.Anchor.PERSON \
		if stamps[FoodField.Anchor.PERSON] < stamps[FoodField.Anchor.LOCAL] \
		else FoodField.Anchor.LOCAL
	var before: Array[int] = []
	for body: Object in field.bodies():
		before.append(int(body.serial))
	field._process(POND_STEP)
	# Every seed of that frame, in the order it was made -- serials only climb --
	# so a meal the water happened to make in the same frame is one more turn in
	# the sequence rather than a gap in it.
	var seeded: Array = []
	for i in FoodField.PERSON_SLOT:
		var body: Object = field.bodies()[i]
		if body.seeded and int(body.serial) != before[i]:
			seeded.append([int(body.serial), int(body.tuned)])
	seeded.sort()
	var turns: Array[int] = []
	for pair: Array in seeded:
		turns.append(int(pair[1]))
	var alternate := turns.size() >= 6
	for i in range(1, turns.size()):
		if turns[i] == turns[i - 1]:
			alternate = false
	_says(alternate and turns[0] == first,
		"pond-field: tied anchors take turns, one cell each, the one seeded for"
		+ " least recently first (%s)" % str(turns))


# --- §1.5: leaving the water does not stop it --------------------------------

func _pond_out_of_water() -> void:
	# This cell out of the water: a run at it ends a frame later, and the water
	# goes on moving.
	var field := _pond_rig(51, 30.0, POND_SENSES)
	field.open_pond()
	_pond_person(field, Vector2(3000.0, 0.0), 28.0, POND_SENSES)
	var from := Vector2(0.0, -400.0)
	var b := _pond_pose(field, 5, 30.0, {&"cytostome": 3, &"flagellum": 1}, from,
		_pond_face(from, Vector2.ZERO))
	b.state = FoodField.State.STALK
	b.target = FoodField.TARGET_PLAYER
	b.stroke = 5.0
	field._process(POND_STEP)
	var stalked_before: bool = field.hunter() == 5
	var moved_from: Array[Vector2] = []
	for body: Object in field.bodies():
		moved_from.append(body.pos)
	field.leave_water(false)
	field._process(POND_STEP)
	var chasing := 0
	var moved := 0
	for i in field.bodies().size():
		var body: Object = field.bodies()[i]
		if body.state == FoodField.State.STALK and body.target == FoodField.TARGET_PLAYER:
			chasing += 1
		if body.seeded and (body.pos as Vector2) != moved_from[i]:
			moved += 1
	_says(stalked_before and chasing == 0 and field.hunter() == -1 and moved > 30,
		"pond-field: out of the water, no stalker targets this cell a frame later"
		+ " (%d bodies moved meanwhile)" % moved)

	# The person out of the water: a committed mouth on them does nothing.
	field = _pond_rig(52, 30.0, POND_SENSES)
	field.open_pond()
	var at := Vector2(3000.0, 0.0)
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"flagellum": 1})
	var said := _pond_listen(field)
	from = at + Vector2(0.0, -54.0)
	b = _pond_pose(field, 5, 30.0, {&"cytostome": 3, &"flagellum": 1}, from,
		_pond_face(from, at))
	_pond_hunt(field, b)
	field.set_person_in_water(false)
	field._process(POND_STEP)
	_says(said.is_empty() and field.person() != null
			and float(field.bodies()[FoodField.PERSON_SLOT].wound) == 0.0
			and int(b.target) != FoodField.PERSON_SLOT,
		"pond-field: a person out of the water is not bitten, and the run at them ends")

	# ...and not perceived: 200 units off this cell's nose, every sense it has
	# reads exactly what it reads with nobody there at all. One water at one
	# instant, the organs worked out three times -- the person out of it, gone
	# from it, and back in it -- because only perception may differ between the
	# first two: stepping two waters instead would let a meal's refill, which
	# must stay clear of a dividing player as of anyone, part them. And the
	# person in the water has to be felt, or this proves nothing.
	field = _pond_rig(53, 30.0, POND_SENSES)
	field.open_pond()
	_pond_person(field, Vector2(0.0, -200.0), 30.0, {&"cytostome": 3,
		&"flagellum": 1})
	field._process(POND_STEP)
	var readings: Array = []
	for pose in ["out", "absent", "in"]:
		match pose:
			"out":
				field.set_person_in_water(false)
			"absent":
				field.remove_person()
			"in":
				field.place_person(Vector2(0.0, -200.0), 0.0, 30.0)
		field.call("_step_sense")
		field.call("_step_beams")
		field.call("_step_touch")
		(field.get("_echoes") as Array).clear()
		field.call("_cast_ping")
		readings.append([field.taste_level, field.dread_level, field.shadow,
			field.touch_level, field.beams.duplicate(true),
			(field.get("_echoes") as Array).duplicate(true)])
	_says(var_to_bytes(readings[0]) == var_to_bytes(readings[1]),
		"pond-field: a person out of the water is not perceived -- taste, dread,"
		+ " shadow, touch, beams and the ping read exactly as with nobody there")
	_says(float(readings[2][3]) > float(readings[1][3])
			and float(readings[2][2]) > float(readings[1][2]),
		"pond-field: and the same person in the water is felt (touch %.2f,"
		% float(readings[2][3]) + " shadow %.2f)" % float(readings[2][2]))


# --- The mirror: the same senses from the host's snapshots -------------------

func _pond_mirror() -> void:
	var host := _pond_rig(61, 30.0, POND_SENSES)
	host.open_pond()
	var person_genes := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1,
		&"pellicle": 1}
	_pond_person(host, Vector2(380.0, -260.0), 32.0, person_genes, 1.0)
	# Something hunting this cell, far enough off not to arrive in ten seconds
	# -- and wider than any mouth the water seeds (ARRIVAL_GAPE_MAX), so that
	# nothing out there swallows it before the ten seconds are up.
	var from := Vector2(-1250.0, 300.0)
	var b := _pond_pose(host, 7, 45.0, {&"cytostome": 3, &"flagellum": 1}, from,
		_pond_face(from, Vector2.ZERO))
	b.state = FoodField.State.STALK
	b.target = FoodField.TARGET_PLAYER
	b.calm = 0.0
	var mirror := _pond_rig(61, 30.0, POND_SENSES)
	mirror.become_mirror()
	var order: Array = []
	for gene: StringName in person_genes:
		order.append(gene)
	mirror.set_person_genome(person_genes, order)
	var host_cell: Object = host.get("_cell")
	var mirror_cell: Object = mirror.get("_cell")
	var versions := {}
	var worst := 0.0
	var frames := 0
	var hunted := 0
	var returns := 0
	var sent_max := 0
	var mismatch := ""
	var hunter_serial := int(b.serial)
	for frame in 600:
		# Held on its run, as `drive.gd --stalk` holds one: a hunter that
		# swallows a drifter on the way in ends its run, and then there is no
		# `hunter()` left to compare. One the water takes anyway is replaced in
		# its slot where it was, so the hunt is compared for the whole run.
		if int(b.serial) != hunter_serial:
			_pond_pose(host, 7, 45.0, {&"cytostome": 3, &"flagellum": 1}, b.pos,
				_pond_face(b.pos, Vector2.ZERO))
			hunter_serial = int(b.serial)
		b.state = FoodField.State.STALK
		b.target = FoodField.TARGET_PLAYER
		host._process(POND_STEP)
		mirror_cell.position = host_cell.position
		mirror_cell.heading = host_cell.heading
		mirror_cell.velocity = host_cell.velocity
		mirror_cell.radius = host_cell.radius
		var entries: Array = host.pond_entries(false)
		sent_max = maxi(sent_max, entries.size())
		for entry: Array in entries:
			var slot := int(entry[FoodField.Entry.SLOT])
			if slot == FoodField.PERSON_SLOT:
				continue
			var sig := int(entry[FoodField.Entry.SERIAL]) * 1000 \
				+ int(entry[FoodField.Entry.MEALS])
			if versions.get(slot, -1) != sig:
				versions[slot] = sig
				mirror.apply_genome(slot, int(entry[FoodField.Entry.SERIAL]),
					int(entry[FoodField.Entry.MEALS]),
					(host.bodies()[slot].genome as Dictionary).duplicate())
		mirror.apply_pond(host_cell.wound, entries)
		# The organs alone: this cell's own push-out was the host's to make,
		# and a mirror of the same cell would make it a second time.
		mirror.call("_step_organs", POND_STEP)
		frames += 1
		var off := _pond_differ(host, mirror)
		worst = maxf(worst, off)
		if off > 1e-6 and mismatch.is_empty():
			mismatch = "-- frame %d off by %s" % [frame, str(off)]
		if host.hunter() >= 0:
			hunted += 1
		returns += (host.pings as Array).size()
		if host.hunter() != mirror.hunter() and mismatch.is_empty():
			mismatch = "-- frame %d hunter %d against %d" % [frame, host.hunter(),
				mirror.hunter()]
	_says(mismatch.is_empty() and worst <= 1e-6 and hunted > 500 and returns > 0,
		("pond-field: the mirror returns the host's taste, dread, shadow, touch,"
		+ " beams, ping returns and hunter() within 1e-6 for %d frames (worst %s;"
		+ " %d frames hunted, %d returns, at most %d of %d bodies sent) %s")
		% [frames, str(worst), hunted, returns, sent_max, FoodField.POND_SLOTS,
			mismatch])

	# A hunter the host loses leaves the mirror's hunt in the same snapshot: a
	# retired body is not sent, and a mirror that kept its last STALK would go
	# on answering hunter() for nothing.
	var was_hunted: bool = host.hunter() == 7 and mirror.hunter() == 7
	host.call("_retire", 7)
	mirror.apply_pond(host_cell.wound, host.pond_entries(false))
	_says(was_hunted and host.hunter() == mirror.hunter()
			and mirror.hunter() != 7,
		"pond-field: a hunter the host retires leaves the mirror's hunter() with"
		+ " the next snapshot (%d on both)" % mirror.hunter())
	# And it is drawn as nothing there, as on the host: the view reads points()
	# and radii() and never `seeded`, so a radius left behind is a ghost.
	_says(not bool(mirror.bodies()[7].seeded) and float(mirror.radii()[7]) == 0.0
			and float(host.radii()[7]) == 0.0,
		"pond-field: a body the host stops sending has radius 0 on the mirror,"
		+ " as on the host (%s against %s)" % [str(mirror.radii()[7]),
			str(host.radii()[7])])

	# And between snapshots it carries: a water body on along its heading at
	# its own speed, the person on the closed form of the drag -- each for no
	# more than CARRY_MAX, and then it holds.
	var carried := true
	var held_at: Array = []
	var snap: Array = []
	for body: Object in mirror.bodies():
		snap.append([body.pos, body.heading, body.speed, body.seeded])
	var person_rec: Object = mirror.person()
	for step in 30:
		mirror._process(POND_STEP)
	var ahead := minf(29.0 * POND_STEP, FoodField.CARRY_MAX)
	for i in FoodField.PERSON_SLOT:
		var body: Object = mirror.bodies()[i]
		if not bool(snap[i][3]):
			continue
		var want: Vector2 = (snap[i][0] as Vector2) + Vector2(sin(float(snap[i][1])),
			-cos(float(snap[i][1]))) * (float(snap[i][2]) * ahead)
		if (body.pos as Vector2).distance_to(want) > 1e-3:
			carried = false
	var k := CellBody.DRAG
	var person_want: Vector2 = person_rec.at \
		+ person_rec.launch * ((1.0 - exp(-k * ahead)) / k)
	var person_now: Vector2 = mirror.bodies()[FoodField.PERSON_SLOT].pos
	_says(carried and person_now.distance_to(person_want) < 1e-3,
		"pond-field: between snapshots the mirror carries every body %.2f s and"
		% ahead + " no further, the person on the drag's closed form")


# --- The rest of the field's own contract -------------------------------------

func _pond_housekeeping() -> void:
	# §1.8: a quiet guest coasts on under the water's drag, and stops.
	var field := _pond_rig(71, 30.0, POND_SENSES)
	field.open_pond()
	var at := Vector2(2500.0, 0.0)
	var v := Vector2(60.0, -20.0)
	field.set_person_genome({&"cytostome": 1, &"flagellum": 1}, [])
	field.place_person(at, 0.0, 28.0, v, 0.3)
	for frame in 121:
		field._process(POND_STEP)
	var k := CellBody.DRAG
	var t := 120.0 * POND_STEP
	var want := at + v * ((1.0 - exp(-k * t)) / k)
	var coast: Vector2 = field.bodies()[FoodField.PERSON_SLOT].pos
	# The rest of the way on the person's own step alone: the carry is all
	# that moves them, and thirty seconds of two rings would only cost time.
	for frame in 1800:
		field.call("_step_person", POND_STEP)
	var rest: Vector2 = field.bodies()[FoodField.PERSON_SLOT].pos
	_says(coast.distance_to(want) < 1e-3 and rest.distance_to(at + v / k) < 0.5,
		"pond-field: a person nobody reports coasts on under the drag (%.1f"
		% at.distance_to(coast) + " units in 2 s) and stops %.1f units on"
		% at.distance_to(rest))

	# §1.5: in a pond a sister takes a free slot, not slot 1.
	field = _pond_rig(72, 30.0, POND_SENSES)
	field.open_pond()
	var one := int(field.bodies()[1].serial)
	field.put_sister(PI * 0.5, 560.0, 28.28, {&"cytostome": 1, &"flagellum": 1})
	var slot := -1
	for i in FoodField.PERSON_SLOT:
		if field.bodies()[i].seeded and is_equal_approx(float(field.bodies()[i].radius), 28.28):
			slot = i
	_says(slot >= FoodField.COUNT and int(field.bodies()[1].serial) == one,
		"pond-field: in a pond the sister takes a free slot (%d), and slot 1 is"
		% slot + " left alone")

	# A mirror is a water of nobody until it is sent one, and leaving it is a
	# fresh single-player water round this cell.
	field = _pond_rig(73, 30.0, POND_SENSES)
	field.become_mirror()
	var empty: bool = field.bodies().size() == FoodField.POND_SLOTS
	for body: Object in field.bodies():
		if body.seeded:
			empty = false
	field._process(POND_STEP)
	field.leave_mirror()
	var solo: bool = field.bodies().size() == FoodField.COUNT and not field.pond_open() \
		and not field.mirroring()
	for body: Object in field.bodies():
		if not body.seeded:
			solo = false
	_says(empty and solo,
		"pond-field: a mirror starts empty, and leaving it is 34 fresh cells alone")


## The largest difference between what the two fields report this frame, over
## every sense the mirror is held to; INF for a shape that differs at all.
func _pond_differ(a: Node, b: Node) -> float:
	var off := 0.0
	for key: String in ["taste_level", "dread_level", "shadow", "touch_level",
			"concentration"]:
		off = maxf(off, absf(float(a.get(key)) - float(b.get(key))))
	if float(a.shadow) > 0.0:
		off = maxf(off, absf(angle_difference(float(a.shadow_bearing),
			float(b.shadow_bearing))))
	if float(a.touch_level) > 0.0:
		off = maxf(off, absf(angle_difference(float(a.touch_bearing),
			float(b.touch_bearing))))
	var beams_a: Array = a.beams
	var beams_b: Array = b.beams
	if beams_a.size() != beams_b.size():
		return INF
	for i in beams_a.size():
		if bool(beams_a[i][2]) != bool(beams_b[i][2]):
			return INF
		off = maxf(off, absf(float(beams_a[i][0]) - float(beams_b[i][0])))
		off = maxf(off, absf(float(beams_a[i][1]) - float(beams_b[i][1])))
	var pings_a: Array = a.pings
	var pings_b: Array = b.pings
	if pings_a.size() != pings_b.size():
		return INF
	for i in pings_a.size():
		for j in 4:
			off = maxf(off, absf(float(pings_a[i][j]) - float(pings_b[i][j])))
	return off


# ---------------------------------------------------------------------------
# **The pond, played** (shared-pond.md §5, Phase 2). Two sessions on loopback
# and two real runs of `normal_mode.tscn` -- the host's, whose water is the
# pond, and the guest's, which mirrors it -- with every byte between them
# crossing a socket. What the probe does is what a player or a phone would do:
# it poses bodies in the host's water, holds the two cells still where a
# geometry has to be exact, opens the menu, stops a phone, closes a session.
# Everything it asserts it reads off the two runs.
#
# **The wall-clock bill is the section's cost to CI**, so it is ordered to
# spend no second twice: both players divide at once, the guest's deaths are
# tapped through at the shut, and the three waits the spec names -- 3 s of the
# host's black, 5 s of choosing, 3 s of a quiet host -- are the only long ones.
# ---------------------------------------------------------------------------

## **The host's field, with every sister it places written down**: which slot
## she took, whether it was free, and every serial the call changed -- so "the
## sister in a free slot and no other serial changed" is read off the call
## itself, not off a frame in which the water's own meals and seeds also land.
class PondWatchedFood extends "res://game/normal/food.gd":
	var sisters: Array = []
	## **Every snapshot this water built for the guest**, newest last and the
	## last 64 kept: `[count, entries, water, the guest's place, its serial]`,
	## where `water` is each body as it stood at that instant -- `[seeded, place,
	## radius, serial, meals, genome, state, target, target serial]`. The mirror
	## check finds the one the guest applied by its sequence, and so never
	## compares a mirror with water a frame later than the water it was sent.
	var built: Array = []
	var built_count := 0

	func pond_entries(for_person: bool, reach: float = SEND_REACH) -> Array:
		var out: Array = super.pond_entries(for_person, reach)
		if for_person:
			var water: Array = []
			for b in _cells:
				water.append([b.seeded, b.pos, b.radius, b.serial, b.meals,
					b.genome.duplicate(), b.state, b.target, b.target_serial])
			built_count += 1
			built.append([built_count, out, water, _cells[PERSON_SLOT].pos,
				_cells[PERSON_SLOT].serial])
			if built.size() > 64:
				built.pop_front()
		return out

	func place_sister(at: Vector2, heading: float, body_radius: float,
			tiers: Dictionary) -> int:
		var before := PackedInt64Array()
		var seeded := PackedByteArray()
		for b in _cells:
			before.append(b.serial)
			seeded.append(1 if b.seeded else 0)
		var slot := super.place_sister(at, heading, body_radius, tiers)
		var changed: Array[int] = []
		for i in mini(_cells.size(), before.size()):
			if _cells[i].serial != before[i]:
				changed.append(i)
		# How clear of the two players she ended up, and how far from where
		# she was asked for.
		var clear := INF
		var moved := 0.0
		if slot >= 0:
			var sb := _cells[slot]
			moved = sb.pos.distance_to(at)
			if anchored:
				clear = minf(clear, sb.pos.distance_to(_cell.position) - sb.radius
					- _cell.radius)
			var pb := _cells[PERSON_SLOT]
			if pb.person != null:
				clear = minf(clear, sb.pos.distance_to(pb.pos) - sb.radius - pb.radius)
		sisters.append({"slot": slot, "was_free": slot >= 0 and seeded[slot] == 0,
			"changed": changed, "at": at, "radius": body_radius,
			"host_at": _cell.position, "clear": clear, "moved": moved})
		return slot


const POND_ARRIVAL_TOLERANCE := 1.0
const POND_BEARING_TOLERANCE := 0.05
## **Latency in `pond` is counted in frames, and a claim made in seconds is held
## at the game's own 60 frames a second**: "within 0.2 s" is within 12 frames,
## "within 0.1 s" within 6. Every hop here is loopback, taken at a poll, so a
## chain of them costs frames; a loaded runner stretches the frames and not the
## chain. Wall-clock bounds are what failed in review -- 119 ms against 100
## with the CPU saturated -- and could only be widened into saying nothing. The one
## wall-clock wait inside a chain, the state frame's 12 ms EARLY_GAP, is three
## frames at this section's 250 and under one at 60, so counting here only
## ever overstates what a phone would take.
const POND_FPS := 60.0

## Frames the last [method _pond_until] waited, and the longest single frame in
## it -- the unit a latency is held to, and what a wall-clock window is widened
## by when a claim can only be made in seconds.
var _pond_frames := 0
var _pond_frame_max := 0.0
## The longest frame anywhere in the section so far.
var _pond_frame_worst := 0.0


func _check_pond() -> void:
	var began := _now()
	var began_frames := Engine.get_process_frames()
	# **Half the probe's ceiling, for this section only**, which is most of
	# the probe's wall time: at 250 a second its twenty-odd seconds can never
	# be more than about 5,500 of CI's 20,000 frames, however fast the runner.
	# Nothing here is finer than a 4 ms frame -- the tightest bound is 0.1 s.
	var ceiling := Engine.max_fps
	Engine.max_fps = 250
	_pond_frame_worst = 0.0
	var host_net: Node = await _session("PondHost")
	var guest_net: Node = await _session("PondGuest")
	host_net.host()
	guest_net.join("127.0.0.1")
	await _until_link(guest_net, NetSession.Link.TOGETHER)
	await _until_link(host_net, NetSession.Link.TOGETHER)
	_says(int(host_net.link) == NetSession.Link.TOGETHER
			and int(guest_net.link) == NetSession.Link.TOGETHER,
		"pond: two sessions on protocol %d completed the handshake" % Wire.PROTOCOL)

	# **The host's run first, and its water is the pond.**
	var host_run := _pond_run_scene(host_net, true)
	get_tree().root.add_child.call_deferred(host_run)
	await host_run.ready
	var host_cell: Node = host_run.get_node(^"Cell")
	var host_food: Node = host_run.get_node(^"Food")
	var host_pond: Object = host_run.get("_pond")
	var home: Vector2 = host_cell.position
	var host_pin := [host_cell, home, 0.0]
	await _pond_until(func() -> bool: return bool(guest_net.peer_pond_open()), 2.0,
		[host_pin])
	_says(host_food.pond_open() and bool(guest_net.peer_pond_open()),
		"pond: the host's water opened as the pond, and its state frames say so")

	# **The guest's run opens inside it**, held for the round trip (§1.6): no
	# swap and no beat, and placed where ARRIVE says.
	var guest_run := _pond_run_scene(guest_net, false)
	get_tree().root.add_child.call_deferred(guest_run)
	await guest_run.ready
	var guest_cell: Node = guest_run.get_node(^"Cell")
	var guest_food: Node = guest_run.get_node(^"Food")
	var guest_pond: Object = guest_run.get("_pond")
	var held_start := bool(guest_run.get("_entering_held"))
	var arrived := await _pond_until(func() -> bool: return bool(guest_pond.in_pond),
		2.0, [host_pin])
	var landed: Vector2 = guest_cell.position
	var arrival := landed.distance_to(host_cell.position)
	_says(held_start and arrived >= 0.0
			and absf(arrival - host_pond.ARRIVAL) <= POND_ARRIVAL_TOLERANCE
			and landed.distance_to(host_pond.arrival_at) <= POND_ARRIVAL_TOLERANCE
			and float(guest_run.get("_water_beat")) < 0.0,
		"pond: a guest opening inside the pond is held, then arrives %.2f units"
		% arrival + " from the host (%.0f +- %.0f), with no beat, %.0f ms after"
		% [host_pond.ARRIVAL, POND_ARRIVAL_TOLERANCE, arrived * 1000.0]
		+ " opening")
	var guest_pin := [guest_cell, landed, 0.0]
	var pins := [host_pin, guest_pin]

	# ----------------------------------------------------------------------
	# **The mirror** (§2's send set): every host body within 1,900 of the
	# guest, surface to centre, is in the guest's water within a unit of where
	# the host has it, with the genome of its (serial, meals); none farther.
	#
	# **Held exactly, so a loaded runner cannot fail it and a broken mirror
	# cannot pass it**: against the snapshot the guest applied, found by its
	# sequence among the ones the host recorded building. The send set is the
	# host's own bodies at the instant it was built; each body sent is in the
	# mirror at the place sent, carried by the snapshot's age along its
	# heading, with the genome of its (serial, meals); nothing else is there.
	# Put the carry back at the frame's start, or halve the send reach, and
	# this fails.
	#
	# **The live distance is reported, not held.** How far the mirror stands
	# from the host's water *now* is how far that water moved off a straight
	# line since the snapshot -- a lunge that starts inside the snapshot's
	# age is off by its speed times that age -- which is latency, and
	# `net_lag --pond` measures it as a distribution: p99 0.083 units on
	# loopback. Here it was a tenth of a unit on an idle runner and 9.4 on a
	# saturated one, with the exact half passing both times.
	# ----------------------------------------------------------------------
	# The first snapshot is two hops after the arrival -- this POND bit out,
	# the host's water back -- so it is waited for, and then a third of a
	# second of them: a fixed wait was not two frames on a saturated runner.
	await _pond_until(func() -> bool: return int(guest_pond.get("_applied")) >= 0,
		3.0, pins)
	await _pond_until(func() -> bool: return false, 0.35, pins)
	var exact: Array = _pond_mirror_exact(host_food, guest_food, guest_pond, host_net)
	var mirror: Array = _pond_mirror_error(host_food, guest_food, host_cell)
	_says(int(exact[0]) > 5 and (exact[1] as Array).is_empty(),
		"pond: %d host bodies within 1,900 of the guest are mirrored exactly as"
		% int(exact[0]) + " the snapshot it applied said, carried by its age,"
		+ " with (serial, meals) genomes and nothing else%s; live, %.3f units"
		% ["" if (exact[1] as Array).is_empty() else " -- NOT: " + ", ".join(
			exact[1] as Array), float(mirror[1])]
		+ " off the host's water now (latency: net_lag's), the host itself"
		+ " %.3f in slot 68" % float(mirror[5]))

	# ----------------------------------------------------------------------
	# **A chewer's bite, felt where it is** (§0.2): the host bites, the guest
	# hears a place and makes the bearing itself. And the wound the host owns
	# is the wound the guest's cell carries (§0.1).
	# ----------------------------------------------------------------------
	# **The bite, and nothing else**: a mote strikes the membrane with the same
	# `hit`, so the bite is read where only a bite is said -- the mirror's own
	# `bitten` -- and then found on the bus at that bearing.
	var guest_bus: Node = guest_run.get_node(^"Membrane").bus
	var hits: Array = []
	var bus_hits: Array = []
	guest_food.bitten.connect(func(b: float, _s: float) -> void:
		hits.append([_now(), b]))
	guest_bus.sensation.connect(func(kind: StringName, info: Dictionary) -> void:
		if kind == &"hit":
			bus_hits.append(float(info.get("bearing", NAN))))
	var bearing := deg_to_rad(-70.0)
	var chewer_at: Vector2 = landed + Vector2(sin(bearing), -cos(bearing)) \
		* (float(guest_cell.radius) + 20.0 - 3.0)
	var chewer := _pond_pose(host_food, 3, 20.0, {&"cytostome": 1, &"flagellum": 1},
		chewer_at, _pond_face(chewer_at, landed))
	var chewer_serial := int(chewer.serial)
	hits.clear()
	var person_now: Object = host_food.bodies()[FoodField.PERSON_SLOT]
	var chew_pin := func() -> void:
		if int(chewer.serial) == chewer_serial:
			chewer.pos = chewer_at
			chewer.heading = _pond_face(chewer_at, landed)
	var felt := await _pond_until(func() -> bool:
		chew_pin.call()
		return not hits.is_empty(), 1.0, pins)
	host_food.call("_retire", 3)
	# **The wound rides the next snapshot's header**, a frame or more behind
	# the bite on the reliable channel: waited for, not slept past -- 0.12 s
	# was not one snapshot on a saturated runner. Both ends mend by the same
	# 1/75 a second, so a guest that never heard it cannot catch up: its own
	# cell starts at 0, and the host's copy stays above 0.02 for the two
	# seconds this waits, and more.
	var wounds := [0.0, 0.0]
	var applied_from := int(guest_pond.get("_applied"))
	var agreed := await _pond_until(func() -> bool:
		wounds[0] = float(person_now.wound)
		wounds[1] = float(guest_cell.wound)
		return float(wounds[0]) > 0.02 \
			and absf(float(wounds[0]) - float(wounds[1])) <= 1.0 / 255.0, 2.0, pins)
	var felt_at := float(hits[0][1]) if not hits.is_empty() else NAN
	var on_bus := false
	for said: float in bus_hits:
		if absf(said - felt_at) < 1e-6:
			on_bus = true
	var host_wound := float(wounds[0])
	var guest_wound := float(wounds[1])
	_says(felt >= 0.0 and on_bus
			and absf(angle_difference(felt_at, bearing)) <= POND_BEARING_TOLERANCE,
		"pond: a chewer's bite on the guest is a `hit` at %.3f rad, the true"
		% felt_at + " bearing %.3f +- %.2f" % [bearing, POND_BEARING_TOLERANCE])
	var wound_frames := _pond_frames
	_says(agreed >= 0.0 and host_wound > 0.02
			and absf(host_wound - guest_wound) <= 1.0 / 255.0,
		"pond: and the wound the host owns (%.4f) is the guest's own (%.4f),"
		% [host_wound, guest_wound] + " within 1/255, %d frames after the bite"
		% wound_frames + " was felt (snapshots %d to %d applied meanwhile)"
		% [applied_from, int(guest_pond.get("_applied"))])

	# ----------------------------------------------------------------------
	# **A meal on the guest's side, on the host's screen**: the host swallows
	# it for them, the guest grows, and the host's person is +4 within 0.2 s.
	# ----------------------------------------------------------------------
	var before_r: float = person_now.radius
	var mouth_at := landed + Vector2(0.0, -(guest_cell.radius + 6.0))
	var morsel := _pond_pose(host_food, 4, 7.0, {}, mouth_at, 0.0)
	var morsel_serial := int(morsel.serial)
	var swallowed := await _pond_until(func() -> bool:
		if int(morsel.serial) == morsel_serial:
			morsel.pos = mouth_at
		return int(morsel.serial) != morsel_serial, 1.0, pins)
	var grew := await _pond_until(func() -> bool:
		return (float(host_food.bodies()[FoodField.PERSON_SLOT].radius)
			>= before_r + CellBody.GROWTH_PER_MEAL - 0.01), 1.0, pins)
	var grew_frames := _pond_frames
	_says(swallowed >= 0.0 and grew >= 0.0 and grew_frames <= _pond_budget(0.2),
		"pond: a guest's meal shows on the host +%.0f within 0.2 s at 60 fps --"
		% CellBody.GROWTH_PER_MEAL + " %d frames of %d (%.0f ms here)"
		% [grew_frames, _pond_budget(0.2), grew * 1000.0])

	# ----------------------------------------------------------------------
	# **Pause stops nothing (B)**, on both seats at once: the tree never
	# pauses, the warning is up, KEY_D moves no cell, and a hunter still eats
	# the cell whose menu is open.
	# ----------------------------------------------------------------------
	host_run.call("_toggle_pause")
	guest_run.call("_toggle_pause")
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await _pond_until(func() -> bool: return false, 0.15, [])
	var steer_host := float(host_cell.steer)
	var steer_guest := float(guest_cell.steer)
	var menus := bool(host_run.get("_menu_open")) and bool(guest_run.get("_menu_open"))
	var warned := bool((host_run.get("_warn") as Label).visible) \
		and bool((guest_run.get("_warn") as Label).visible)
	var paused := get_tree().paused
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	_says(menus and not paused and warned,
		"pond: both menus open over a live pond and the tree is not paused;"
		+ " the warning is up on both")
	_says(steer_host == 0.0 and steer_guest == 0.0,
		"pond: KEY_D held with the menu up leaves both cells' steer at 0")
	var died_at := [-1.0, false, 0]
	var on_died := func(_cause: int, _by: int, _at: Vector2) -> void:
		died_at[0] = _now()
		died_at[1] = host_food.person() == null
		died_at[2] = Engine.get_process_frames()
	host_food.person_died.connect(on_died)
	var hunter_at: Vector2 = guest_cell.position + Vector2(0.0, -56.0)
	var hunter := _pond_pose(host_food, 5, 30.0, {&"cytostome": 3, &"flagellum": 1},
		hunter_at, _pond_face(hunter_at, guest_cell.position))
	_pond_hunt(host_food, hunter)
	var dying := await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) != NormalMode.Life.ALIVE, 1.0, [host_pin])
	var dying_after := _now() - float(died_at[0])
	var dying_frames := Engine.get_process_frames() - int(died_at[2])
	host_food.person_died.disconnect(on_died)
	_says(dying >= 0.0 and float(died_at[0]) > 0.0 and bool(died_at[1])
			and dying_frames <= _pond_budget(0.2)
			and int(guest_food.died_of) == FoodField.Cause.SWALLOWED
			and int(guest_food.died_by) == FoodField.By.WATER,
		"pond: with its menu open, the guest is swallowed by a committed hunter"
		+ " -- DYING %d frames after the host's swallow (0.2 s at 60 fps is %d;"
		% [dying_frames, _pond_budget(0.2)] + " %.0f ms here), slot 68 empty on"
		% (dying_after * 1000.0) + " the host that frame, told SWALLOWED by the water")
	host_run.call("_toggle_pause")
	_says(not bool(guest_run.get("_menu_open")) and not get_tree().paused,
		"pond: the death closed the guest's menu, and nothing ever paused")

	# **Back from the black into the pond** (owner's row A): tapped during the
	# collapse, it asks the host where, and lands near its friend.
	guest_run.set("_tap_pending", true)
	var back := await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) == NormalMode.Life.RETURNING, 3.0, [host_pin])
	var guest_home: Vector2 = guest_cell.position
	_says(back >= 0.0 and absf(guest_home.distance_to(host_cell.position)
			- host_pond.ARRIVAL) <= POND_ARRIVAL_TOLERANCE
			and guest_food.pond_open() and guest_food.mirroring()
			and int(guest_run.get("_generation")) == 1,
		"pond: the guest taps from the black and comes back a generation-1 cell"
		+ " %.1f units from the host, in the same water" % guest_home.distance_to(
			host_cell.position))
	guest_pin = [guest_cell, guest_home, 0.0]
	pins = [host_pin, guest_pin]

	# ----------------------------------------------------------------------
	# **Either player can eat the other.** The host grows a mouth and the
	# guest is put in it; then the guest grows one and the host is put in
	# that -- and the host's own death is told to it as a cause. The guest is
	# still returning each time, which is in the water (owner's row A): what
	# the host's water does to it there, it obeys.
	# ----------------------------------------------------------------------
	var genome_host: Node = host_run.get_node(^"Genome")
	genome_host.express({&"cytostome": 3, &"cirrus": 1, &"flagellum": 1},
		[&"cytostome", &"cirrus", &"flagellum"])
	var in_mouth: Vector2 = home + Vector2(0.0, -(float(host_cell.radius) + 18.0))
	var host_ate := [false]
	var on_eaten := func(_n: float, _g: StringName, _a: Vector2) -> void:
		host_ate[0] = true
	host_food.eaten.connect(on_eaten)
	# Each facing away from the other, so one mouth only is on a body.
	var eaten := await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) == NormalMode.Life.DYING, 1.5,
		[host_pin, [guest_cell, in_mouth, 0.0]])
	host_food.eaten.disconnect(on_eaten)
	var said_ate: String = str(host_run.get("_line_text"))
	_says(eaten >= 0.0 and bool(host_ate[0])
			and int(guest_food.died_of) == FoodField.Cause.SWALLOWED
			and int(guest_food.died_by) == FoodField.By.FRIEND
			and said_ate == NormalMode.LINE_ATE,
		"pond: the host swallows the guest -- a meal for the host, SWALLOWED by"
		+ " the friend for the guest, and the host is told '%s'" % said_ate)
	guest_run.set("_tap_pending", true)
	await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) == NormalMode.Life.RETURNING, 3.5,
		[host_pin])
	guest_home = guest_cell.position
	guest_pin = [guest_cell, guest_home, 0.0]
	pins = [host_pin, guest_pin]

	var genome_guest: Node = guest_run.get_node(^"Genome")
	genome_guest.express({&"cytostome": 3, &"cirrus": 1, &"flagellum": 1},
		[&"cytostome", &"cirrus", &"flagellum"])
	# The worn change crosses as PERSON before the mouth can be used.
	await _pond_until(func() -> bool:
		return (Genome.tier_of(host_food.bodies()[FoodField.PERSON_SLOT].genome,
			&"cytostome") == 3), 1.0, pins)
	var guest_ate := [false]
	var on_guest_eaten := func(_n: float, _g: StringName, _a: Vector2) -> void:
		guest_ate[0] = true
	guest_food.eaten.connect(on_guest_eaten)
	var host_mouth_at := guest_home + Vector2(0.0, -(guest_cell.radius + 18.0))
	var host_down := await _pond_until(func() -> bool:
		return int(host_run.get("_life")) == NormalMode.Life.DYING, 1.5,
		[guest_pin, [host_cell, host_mouth_at, 0.0]])
	var host_died_at := _now()
	await _pond_until(func() -> bool: return bool(guest_ate[0]), 0.5, [guest_pin])
	guest_food.eaten.disconnect(on_guest_eaten)
	_says(host_down >= 0.0 and bool(guest_ate[0])
			and int(host_food.died_of) == FoodField.Cause.SWALLOWED
			and int(host_food.died_by) == FoodField.By.FRIEND
			and str(guest_run.get("_line_text")) == NormalMode.LINE_ATE,
		"pond: and the guest swallows the host -- the host told its own cause,"
		+ " SWALLOWED by the friend, and the guest told '%s'"
		% str(guest_run.get("_line_text")))

	# ----------------------------------------------------------------------
	# **The host's black does not stop the pond** (owner's row A): 3 s of it,
	# snapshots advancing and the water moving on the guest's screen -- and
	# the replay withheld. Then its tap lands it ARRIVAL, 480, from the guest.
	# ----------------------------------------------------------------------
	var seq_from := Wire.seq_of(guest_net.peer_pond())
	var water_from: Array = _pond_places(guest_food)
	await _pond_until(func() -> bool: return false, 3.0, [guest_pin])
	var black_frames := _pond_frames
	var seq_to := Wire.seq_of(guest_net.peer_pond())
	var moved := _pond_moved(water_from, _pond_places(guest_food))
	_says(int(host_run.get("_life")) == NormalMode.Life.WAITING
			and seq_to - seq_from >= _pond_snapshots(3.0, black_frames) and moved > 10
			and not bool((host_run.get("_watch_ui") as Control).visible),
		"pond: through %.1f s of the host's black the guest took %d snapshots"
		% [_now() - host_died_at, seq_to - seq_from] + " and %d bodies moved;"
		% moved + " the replay is withheld")
	host_run.call("_wake_up")
	await _pond_until(func() -> bool:
		return int(host_run.get("_life")) == NormalMode.Life.RETURNING, 0.5, [guest_pin])
	home = host_cell.position
	var host_back: float = home.distance_to(guest_home)
	_says(absf(host_back - host_pond.ARRIVAL) <= POND_ARRIVAL_TOLERANCE
			and host_food.pond_open() and int(host_run.get("_generation")) == 1,
		"pond: the host taps and comes back %.1f units from the guest, the pond"
		% host_back + " still open")
	host_pin = [host_cell, home, 0.0]
	pins = [host_pin, guest_pin]
	await _pond_until(func() -> bool:
		return int(host_run.get("_life")) == NormalMode.Life.ALIVE, 2.0, pins)

	# ----------------------------------------------------------------------
	# **Both players divide at once** (§1.5, UX §2): out of the water from the
	# pinch -- gone from every sense on the other seat -- the water going on
	# through 5 s of choosing, and each back where it left at r28.28, its
	# sister in a free slot with nothing else renumbered.
	# ----------------------------------------------------------------------
	var sisters: Array = host_food.get("sisters")
	sisters.clear()
	# **Aimed at the host, on purpose.** Facing north, a sister declined to
	# starboard goes SISTER_DISTANCE due east -- so with the host put exactly
	# there, the guest's sister is asked for the host's own place. That is
	# `food.gd`'s SISTER_CLEAR at work, and the check below it; the first run
	# here, when an arrival still landed at the same 560, measured the host
	# shoved 14 units in its own daughter's first frame.
	home = guest_home + Vector2(NormalMode.SISTER_DISTANCE, 0.0)
	host_pin = [host_cell, home, 0.0]
	pins = [host_pin, guest_pin]
	await _pond_until(func() -> bool: return false, 0.1, pins)
	for run: Node in [host_run, guest_run]:
		(run.get_node(^"Cell")).radius = CellBody.DIVIDE_RADIUS
	await _pond_until(func() -> bool:
		return (int(host_run.get("_split")) != NormalMode.Split.NONE
			and int(guest_run.get("_split")) != NormalMode.Split.NONE), 1.0, pins)
	# The quickening is the one phase still in the water, and nothing here is
	# about it: both go straight to the pinch.
	for run: Node in [host_run, guest_run]:
		run.set("_split_clock", NormalMode.DIVIDE_QUICKEN)
	await _pond_until(func() -> bool:
		return (int(host_run.get("_split")) >= NormalMode.Split.PINCH
			and int(guest_run.get("_split")) >= NormalMode.Split.PINCH), 1.0, [])
	var pinched := _now()
	var left_host: Vector2 = host_cell.position
	var left_guest: Vector2 = guest_cell.position
	var gone := await _pond_until(func() -> bool:
		return (not bool(host_food.bodies()[FoodField.PERSON_SLOT].seeded)
			and not bool(guest_food.bodies()[FoodField.PERSON_SLOT].seeded)
			and not bool(host_food.in_water) and not bool(guest_food.in_water)),
		1.0, [])
	var gone_frames := _pond_frames
	_says(gone >= 0.0 and gone_frames <= _pond_budget(0.1),
		"pond: from the pinch each divider is out of the water on both seats --"
		+ " unseeded, so no sense, mouth or push finds it -- within %d frames"
		% gone_frames + " (0.1 s at 60 fps is %d; %.0f ms here)"
		% [_pond_budget(0.1), gone * 1000.0])
	# The parting is a drawing, and nothing here is about it either.
	await _pond_until(func() -> bool:
		for run: Node in [host_run, guest_run]:
			if int(run.get("_split")) == NormalMode.Split.PART:
				run.set("_split_clock", NormalMode.DIVIDE_PART)
		return (int(host_run.get("_split")) == NormalMode.Split.CHOOSING
			and int(guest_run.get("_split")) == NormalMode.Split.CHOOSING), 3.0, [])
	var choose_from := _pond_places(host_food)
	var seq_choose := Wire.seq_of(guest_net.peer_pond())
	# **Each divider's own spot kept clear** while it is out of the water. The
	# water does not see a divider, so a body can drift onto the place she
	# will come back to -- and then her first frame is a meal and a shove,
	# which is the water being right and this check being about something
	# else. Measured the first time: born exactly at the pinch, then eaten
	# into r32.28 and pushed 16 units in the same frame.
	var spots: Array[Vector2] = [left_host, left_guest]
	var keep_clear := func() -> void:
		var bodies: Array = host_food.bodies()
		for i in FoodField.PERSON_SLOT:
			var b: Object = bodies[i]
			if not b.seeded:
				continue
			for spot: Vector2 in spots:
				if (b.pos as Vector2).distance_to(spot) < float(b.radius) + 90.0:
					host_food.call("_retire", i)
					break
	await _pond_until(func() -> bool:
		keep_clear.call()
		return false, 5.0, [])
	var chose_frames := _pond_frames
	var chose_moved := _pond_moved(choose_from, _pond_places(host_food))
	var seq_chose := Wire.seq_of(guest_net.peer_pond()) - seq_choose
	_says(int(host_run.get("_split")) == NormalMode.Split.CHOOSING
			and int(guest_run.get("_split")) == NormalMode.Split.CHOOSING
			and chose_moved > 10 and seq_chose >= _pond_snapshots(5.0, chose_frames),
		"pond: through 5 s of both choosing, %d bodies moved and the guest took"
		% chose_moved + " %d snapshots" % seq_chose)
	# Both lean the same way, as `_step_choosing` would after CHOOSE_HOLD.
	for run: Node in [host_run, guest_run]:
		run.set("_chosen", 0)
		run.set("_split", NormalMode.Split.COMMIT)
		run.set("_split_clock", 0.0)
	await _pond_until(func() -> bool:
		return (int(host_run.get("_split")) == NormalMode.Split.NONE
			and int(guest_run.get("_split")) == NormalMode.Split.NONE
			and sisters.size() >= 2), 3.0, [])
	var daughter := CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)
	# Each daughter as she is born -- the frame her `_split` comes back to NONE,
	# before she has swum or fed -- and each as the other seat first sees her.
	var born := {}
	var seen := {}
	await _pond_until(func() -> bool:
		if born.size() < 2:
			keep_clear.call()
		for run: Node in [host_run, guest_run]:
			var cell: Node = run.get_node(^"Cell")
			if not born.has(run) and int(run.get("_split")) == NormalMode.Split.NONE:
				born[run] = [cell.position, float(cell.radius)]
		if absf(float(host_food.bodies()[FoodField.PERSON_SLOT].radius) - daughter) < 0.01:
			seen[guest_run] = true
		if absf(float(guest_food.bodies()[FoodField.PERSON_SLOT].radius) - daughter) < 0.01:
			seen[host_run] = true
		return born.size() == 2 and seen.size() == 2 and sisters.size() >= 2, 3.0, [])
	var clean := sisters.size() == 2
	var clear_of := true
	var shifted: Array[String] = []
	for sister: Dictionary in sisters:
		if not bool(sister["was_free"]) or sister["changed"] != [int(sister["slot"])] \
				or not is_equal_approx(float(sister["radius"]), daughter):
			clean = false
		if float(sister["clear"]) < FoodField.SISTER_CLEAR - 0.01:
			clear_of = false
		shifted.append("%.1f" % float(sister["moved"]))
	var host_at_call: Array[String] = []
	for each: Dictionary in sisters:
		host_at_call.append("%.2f" % (each["host_at"] as Vector2).distance_to(left_host))
	var host_born: Array = born.get(host_run, [Vector2(INF, INF), 0.0])
	var guest_born: Array = born.get(guest_run, [Vector2(INF, INF), 0.0])
	_says((host_born[0] as Vector2).distance_to(left_host) < 0.5
			and (guest_born[0] as Vector2).distance_to(left_guest) < 0.5
			and is_equal_approx(float(host_born[1]), daughter)
			and is_equal_approx(float(guest_born[1]), daughter) and seen.size() == 2,
		"pond: both dividers come back where they left, at r%.2f, and each is"
		% daughter + " seen so on the other seat (born %.2f and %.2f units from"
		% [(host_born[0] as Vector2).distance_to(left_host),
			(guest_born[0] as Vector2).distance_to(left_guest)]
		+ " the pinch, r%.2f and r%.2f; at the sister call the host was %s from it)"
		% [float(host_born[1]), float(guest_born[1]), str(host_at_call)])
	_says(clean, "pond: each sister took a free slot and nothing else was"
		+ " renumbered (%s)" % str(sisters.map(func(s: Dictionary) -> String:
			return "slot %d, changed %s" % [int(s["slot"]), str(s["changed"])])))
	_says(clear_of and sisters.size() == 2,
		"pond: and neither landed on a player -- each at least %.0f units clear,"
		% FoodField.SISTER_CLEAR + " moved %s units from where she was asked for"
		% str(shifted))
	home = host_cell.position
	guest_home = guest_cell.position
	host_pin = [host_cell, home, 0.0]
	guest_pin = [guest_cell, guest_home, 0.0]
	pins = [host_pin, guest_pin]
	await _pond_until(func() -> bool: return false, 0.3, pins)

	# ----------------------------------------------------------------------
	# **A quiet host holds the guest** (UX §5): its whole main loop stopped,
	# as `onActivityStopped` stops a phone -- the guest's pond held from 1.2 s,
	# and back on the next snapshot.
	#
	# **Held to the guest's own clock, not to this one.** The guest holds on
	# the first frame its own silence reaches PEER_FRESH, and the probe looks
	# at the start of the frame after: so the silence it reads at the first
	# held frame is at least PEER_FRESH and less than two frames past it, on
	# any runner. And the silence began at the stop -- the host was heard
	# every STATE_PERIOD, or every frame where frames are slower than that.
	# ----------------------------------------------------------------------
	var modes := _pond_stop(host_run)
	host_net.set_process(false)
	var quiet_from := _now()
	var quiet_seen := [0.0]
	var held := await _pond_until(func() -> bool:
		quiet_seen[0] = float(guest_net.quiet_for())
		return bool(guest_run.get("_held")), 2.5, [guest_pin])
	var hold_frame := _pond_frame_max
	await _pond_until(func() -> bool: return false, 3.0 - (_now() - quiet_from),
		[guest_pin])
	var still_held := bool(guest_run.get("_held")) and not guest_food.is_processing() \
		and not bool((guest_run.get("_warn") as Label).visible)
	_pond_start(host_run, modes)
	host_net.set_process(true)
	var resumed := await _pond_until(func() -> bool:
		return not bool(guest_run.get("_held")), 1.0, pins)
	var resumed_frames := _pond_frames
	var silence := float(quiet_seen[0])
	# The host's last word before the stop left at most a STATE_PERIOD before
	# it, or one of its frames where those run longer -- and no frame in this
	# section has run longer than the worst one seen.
	var on_time: bool = silence >= VisionLayer.PEER_FRESH \
		and silence < VisionLayer.PEER_FRESH + 2.0 * hold_frame + 0.01 \
		and held >= VisionLayer.PEER_FRESH \
			- maxf(NetSession.STATE_PERIOD, _pond_frame_worst) - 0.02
	_says(held >= 0.0 and on_time and still_held and resumed >= 0.0
			and resumed_frames <= _pond_budget(0.2),
		"pond: a host stopped for 3 s holds the guest %.2f s after it stops, at"
		% held + " %.3f s of its own silence (PEER_FRESH %.1f, frames up to %.0f"
		% [silence, VisionLayer.PEER_FRESH, hold_frame * 1000.0] + " ms), and it"
		+ " resumes %d frames after the host does (0.2 s at 60 fps is %d; %.0f ms"
		% [resumed_frames, _pond_budget(0.2), resumed * 1000.0] + " here)")

	# ----------------------------------------------------------------------
	# **A kill is the first thing heard after a hold** (review, trigger B):
	# the host's water took the guest while its packets were stuck, and the
	# KILLED is the first of them to land. The run dies inside `_pond.step()`
	# and lets the hold go in the same frame -- which used to restart the
	# simulation under the corpse, and it swam on, dead. Posed as it lands: the
	# host stopped again, the guest held, the KILLED put in the guest's queue.
	# ----------------------------------------------------------------------
	await _pond_until(func() -> bool: return false, 0.2, pins)
	modes = _pond_stop(host_run)
	host_net.set_process(false)
	await _pond_until(func() -> bool: return bool(guest_run.get("_held")), 2.5,
		[guest_pin])
	var was_held := bool(guest_run.get("_held"))
	(guest_net.pond_events as Array).append(Wire.event(0, Wire.EVENT_CONTACT,
		Wire.contact_payload(FoodField.Contact.KILLED,
			guest_cell.position + Vector2(0.0, -40.0), 0.0, FoodField.By.WATER, &"",
			FoodField.Cause.SWALLOWED)))
	await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) != NormalMode.Life.ALIVE, 0.5, [])
	var corpse_at: Vector2 = guest_cell.position
	var metabolism: Node = guest_run.get_node(^"Metabolism")
	var corpse_on := [guest_cell.is_processing() or metabolism.is_processing()]
	# The tap is taken now and honoured at the black, for the next check.
	guest_run.set("_tap_pending", true)
	await _pond_until(func() -> bool:
		if guest_cell.is_processing() or metabolism.is_processing():
			corpse_on[0] = true
		return false, 0.3, [])
	var corpse_moved := (guest_cell.position as Vector2).distance_to(corpse_at)
	_says(was_held and int(guest_run.get("_life")) != NormalMode.Life.ALIVE
			and not bool(guest_run.get("_held")) and not bool(corpse_on[0])
			and corpse_moved < 0.01 and guest_food.is_processing(),
		"pond: a KILLED heard first after a hold kills the guest and lets the"
		+ " hold go in one frame, and the corpse is %s -- moved %.2f units in"
		% ["simulated" if bool(corpse_on[0]) else "never simulated", corpse_moved]
		+ " 0.3 s -- while the water it died in runs on")

	# ----------------------------------------------------------------------
	# **The link goes while the guest is coming back** (review, the first
	# finding): a takeover inside the 0.9 s of RETURNING. It used to stop the
	# fresh water outright, as for a cell on the black, and nothing started it
	# again -- the guest came back alive into water where nothing moved and
	# nothing could be smelt. The host is let go, answers the tap taken above,
	# and the guest's own link is cut the moment it is returning.
	# ----------------------------------------------------------------------
	_pond_start(host_run, modes)
	host_net.set_process(true)
	var returning := await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) == NormalMode.Life.RETURNING, 3.0, [])
	guest_net.close()
	var took_back := await _pond_until(func() -> bool: return not guest_food.mirroring(),
		1.0, [])
	var in_return := int(guest_run.get("_life")) == NormalMode.Life.RETURNING
	var water_on := guest_food.is_processing()
	var fresh_from: Array = _pond_places(guest_food)
	await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) == NormalMode.Life.ALIVE, 1.5, [])
	await _pond_until(func() -> bool: return false, 0.3, [])
	var fresh_moved := _pond_moved(fresh_from, _pond_places(guest_food))
	_says(returning >= 0.0 and took_back >= 0.0 and in_return and water_on
			and int(guest_run.get("_life")) == NormalMode.Life.ALIVE
			and guest_food.is_processing() and fresh_moved > 10,
		"pond: the link lost while the guest is returning is a takeover into"
		+ " water that runs -- %d of %d fresh cells moved by the time it was back"
		% [fresh_moved, guest_food.bodies().size()])

	# ----------------------------------------------------------------------
	# **A new run hears nothing said before it** (review): a session queues
	# events from the moment it is up, and nothing drained them between runs
	# -- so a guest run opened on `they died` for a death it never saw, and
	# never drew the host it had just been put beside, which the stale death
	# said had gone. A second guest calls; the host says a death to it before
	# its run exists; then the run opens inside the pond.
	# ----------------------------------------------------------------------
	guest_run.queue_free()
	guest_net = await _session("PondGuest2")
	guest_net.join("127.0.0.1")
	await _until_link(guest_net, NetSession.Link.TOGETHER)
	await _until_link(host_net, NetSession.Link.TOGETHER)
	host_net.send_event(Wire.EVENT_DIED, Wire.died_payload(FoodField.Cause.CHEWED,
		FoodField.By.WATER, host_cell.position))
	await _pond_until(func() -> bool:
		return not (guest_net.pond_events as Array).is_empty(), 1.0, [host_pin])
	var stale := (guest_net.pond_events as Array).size()
	guest_run = _pond_run_scene(guest_net, false)
	get_tree().root.add_child.call_deferred(guest_run)
	await guest_run.ready
	guest_cell = guest_run.get_node(^"Cell")
	guest_food = guest_run.get_node(^"Food")
	guest_pond = guest_run.get("_pond")
	# Watched every frame from its first: the stale death, heard, would set
	# `_friend_dead` in the first step and keep the host undrawn for good, so
	# waiting up to two seconds for the drawing cannot pass a run that heard it.
	var second_view: Node = guest_run.get_node(^"Vision")
	var ever_dead := [false]
	var second := await _pond_until(func() -> bool:
		if bool(guest_run.get("_friend_dead")) or str(guest_run.get("_line_key")) == "dead":
			ever_dead[0] = true
		return bool(guest_pond.in_pond) \
			and (second_view.get("_peer") as Dictionary).has("tiers"), 3.0, [host_pin])
	_says(stale >= 1 and second >= 0.0 and not bool(ever_dead[0]),
		"pond: a guest run opening after its session heard a death hears none of"
		+ " it -- %d stale event%s dropped, no `they died`, and the host it"
		% [stale, "" if stale == 1 else "s"] + " arrives beside is drawn")
	guest_pin = [guest_cell, guest_cell.position, 0.0]
	pins = [host_pin, guest_pin]

	# ----------------------------------------------------------------------
	# **A closed host is a takeover** (§1.8): within 0.1 s the guest swims in
	# 34 fresh cells of its own, keeping its body, genome, generation and
	# hunger.
	# ----------------------------------------------------------------------
	await _pond_until(func() -> bool: return false, 0.2, pins)
	var kept := [guest_cell.radius, (guest_run.get_node(^"Genome")).tiers().duplicate(),
		int(guest_run.get("_generation")),
		float((guest_run.get_node(^"Metabolism")).hunger)]
	var closed_at := _now()
	host_net.close()
	var took := await _pond_until(func() -> bool: return not guest_food.mirroring(),
		1.0, [guest_pin])
	var took_frames := _pond_frames
	var fresh: bool = guest_food.bodies().size() == FoodField.COUNT
	for body: Object in guest_food.bodies():
		if not body.seeded:
			fresh = false
	var now_kept := [guest_cell.radius, (guest_run.get_node(^"Genome")).tiers(),
		int(guest_run.get("_generation")),
		float((guest_run.get_node(^"Metabolism")).hunger)]
	_says(took >= 0.0 and took_frames <= _pond_budget(0.1) and fresh
			and is_equal_approx(float(kept[0]), float(now_kept[0]))
			and kept[1] == now_kept[1] and int(kept[2]) == int(now_kept[2])
			and absf(float(kept[3]) - float(now_kept[3])) < 0.01,
		"pond: the host closes and the guest takes over %d frames later (0.1 s"
		% took_frames + " at 60 fps is %d; %.0f ms here) in %d fresh cells,"
		% [_pond_budget(0.1), (took if took >= 0.0 else _now() - closed_at) * 1000.0,
			guest_food.bodies().size()]
		+ " keeping r%.2f, its genome, generation %d and hunger %.2f"
		% [float(now_kept[0]), int(now_kept[2]), float(now_kept[3])])

	# **Alone when the link goes, with the menu open** (§1.7): a guest that is
	# not in the pond has nothing to take over, so nothing closes its menu --
	# and the menu it opened over a live session becomes the shipped pause,
	# the tree stopped under it. Posed on the run that has just taken over,
	# which swims alone: its session is told it is together again, the menu
	# opens over live water, and the link goes back to what the close left.
	# After the takeover's beat, so this is an ordinary frame of a cell alone.
	await _pond_until(func() -> bool: return float(guest_run.get("_water_beat")) < 0.0,
		2.0, [guest_pin])
	var link_was := int(guest_net.link)
	guest_net.set("link", NetSession.Link.TOGETHER)
	guest_run.call("_toggle_pause")
	await _pond_until(func() -> bool: return false, 0.1, [guest_pin])
	var open_live := bool(guest_run.get("_menu_open")) and not get_tree().paused \
		and bool((guest_run.get("_warn") as Label).visible)
	guest_net.set("link", link_was)
	var stopped := await _pond_until(func() -> bool: return get_tree().paused, 0.5, [])
	var stopped_frames := _pond_frames
	var solo_menu := bool(guest_run.get("_menu_open")) \
		and not bool((guest_run.get("_warn") as Label).visible) \
		and not bool((guest_run.get_node(^"Cell")).steering_off)
	guest_run.call("_toggle_pause")
	var shut := not bool(guest_run.get("_menu_open")) and not get_tree().paused
	get_tree().paused = false
	_says(open_live and stopped >= 0.0 and stopped_frames <= 2 and solo_menu and shut,
		"pond: a guest alone whose link goes under its open menu keeps the menu,"
		+ " and the tree stops under it %d frame%s later -- the shipped pause;"
		% [stopped_frames, "" if stopped_frames == 1 else "s"]
		+ " shut, the water runs again")

	# **An ARRIVE that finds the cell no longer ordinary** -- it began to
	# divide, or opened the menu, in the swap's round trip (UX §1: never dead,
	# dividing or in the menu) -- drops the swap, rather than run a beat that
	# stops and restarts the simulation under the division, or changes the
	# water under the menu. Called straight, inside one frame, on the run
	# swimming alone.
	guest_run.set("_swap_pending", true)
	guest_run.set("_split", NormalMode.Split.QUICKEN)
	guest_run.call("_on_pond_arrived", guest_cell.position + Vector2(480.0, 0.0), 0.0)
	var dropped: bool = float(guest_run.get("_water_beat")) < 0.0 \
		and not bool(guest_run.get("_swap_pending")) and not guest_food.mirroring() \
		and not bool(guest_pond.in_pond)
	guest_run.set("_split", NormalMode.Split.NONE)
	_says(dropped, "pond: an ARRIVE that lands mid-division drops the swap -- no"
		+ " beat, no mirror, not in the pond")
	guest_run.set("_swap_pending", true)
	guest_run.set("_menu_open", true)
	guest_run.call("_on_pond_arrived", guest_cell.position + Vector2(480.0, 0.0), 0.0)
	var dropped_menu: bool = float(guest_run.get("_water_beat")) < 0.0 \
		and not bool(guest_run.get("_swap_pending")) and not guest_food.mirroring() \
		and not bool(guest_pond.in_pond)
	guest_run.set("_menu_open", false)
	_says(dropped_menu, "pond: and so does one that lands with the menu open --"
		+ " the water never changes under it")

	# **A death inside the water's beat ends the beat** (review, trigger G):
	# the host's water can take a guest in the second half of the beat that put
	# it there, and the beat's end used to restart the simulation under the
	# corpse, bring the world back and pulse. Posed on the run alone: a beat
	# whose swap is done, run on to a tenth of a second from its end, and a
	# death -- then watched past where that end was.
	guest_run.call("_begin_water_beat", Callable(), 0.0, "", "")
	guest_run.set("_water_beat", NormalMode.SignalBus.DEATH_RETURN - 0.1)
	guest_run.call("_die", true, 0.0)
	var beat_over := float(guest_run.get("_water_beat")) < 0.0
	var dead_at: Vector2 = guest_cell.position
	var dead_on := [guest_cell.is_processing()]
	await _pond_until(func() -> bool:
		if guest_cell.is_processing():
			dead_on[0] = true
		return false, 0.25, [])
	_says(beat_over and not bool(dead_on[0])
			and (guest_cell.position as Vector2).distance_to(dead_at) < 0.01
			and int(guest_run.get("_life")) != NormalMode.Life.ALIVE,
		"pond: a death inside the water's beat ends the beat, and the corpse is"
		+ " not simulated through where the beat's end was")

	guest_run.queue_free()
	host_run.queue_free()
	guest_net.close()
	await _wait(0.4)
	print("[net-probe] NOTE pond took %.1f s and %d frames, at most %d a second"
		% [_now() - began, Engine.get_process_frames() - began_frames, Engine.max_fps])
	Engine.max_fps = ceiling


## A run of the game on [param net], in full vision so its view works the
## friend out, on the shipped scheme -- and the host's with a watched field.
func _pond_run_scene(net: Node, watched: bool) -> Node:
	NetSession.current = net
	var run: Node = load(RUN_SCENE).instantiate()
	run.set("mode", 1)
	run.set("scheme", 0)
	if watched:
		run.get_node(^"Food").set_script(PondWatchedFood)
	return run


## Frames until [param done] says so or [param seconds] of wall time pass,
## holding every `[cell, at, heading]` in [param pins] still where it is put.
## Returns the seconds it took, or -1 for never.
func _pond_until(done: Callable, seconds: float, pins: Array) -> float:
	var from := _now()
	var last := from
	_pond_frames = 0
	_pond_frame_max = 0.0
	while true:
		for pin: Array in pins:
			var cell: Node = pin[0]
			cell.position = pin[1]
			cell.heading = float(pin[2])
			cell.velocity = Vector2.ZERO
		if done.call():
			return _now() - from
		if _now() - from >= seconds:
			return -1.0
		await get_tree().process_frame
		var now := _now()
		_pond_frames += 1
		_pond_frame_max = maxf(_pond_frame_max, now - last)
		_pond_frame_worst = maxf(_pond_frame_worst, now - last)
		last = now
	return -1.0


## Frames a claim of [param seconds] allows at the game's own frame rate.
func _pond_budget(seconds: float) -> int:
	return int(roundf(seconds * POND_FPS))


## **How many snapshots [param seconds] of waiting must bring**, at least: the
## host sends one with every state frame and otherwise every STATE_PERIOD, and
## never more than one a frame -- so on a runner that drew [param frames] in
## that time, two thirds of the fewer of the two.
func _pond_snapshots(seconds: float, frames: int) -> int:
	return int(floorf(minf(seconds / NetSession.STATE_PERIOD, float(frames)) * 0.66))


## `[sent, worst, sent too far, genomes wrong, missing, slot 68 off]`: the
## guest's water against the host's, body by body, this frame.
func _pond_mirror_error(host_food: Node, guest_food: Node, host_cell: Node) -> Array:
	var host_bodies: Array = host_food.bodies()
	var mirror: Array = guest_food.bodies()
	var guest_at: Vector2 = host_bodies[FoodField.PERSON_SLOT].pos
	var person_serial := int(host_bodies[FoodField.PERSON_SLOT].serial)
	var sent := 0
	var worst := 0.0
	var too_far := 0
	var wrong := 0
	var missing := 0
	for i in FoodField.PERSON_SLOT:
		var hb: Object = host_bodies[i]
		var mb: Object = mirror[i]
		var reach: float = (hb.pos as Vector2).distance_to(guest_at) - float(hb.radius)
		var hunting := int(hb.state) == FoodField.State.STALK \
			and int(hb.target) == FoodField.PERSON_SLOT \
			and int(hb.target_serial) == person_serial
		if not hb.seeded:
			if mb.seeded:
				too_far += 1
			continue
		# A body within a hair of the edge may be either side of it by the
		# frame the two are compared in.
		if absf(reach - FoodField.SEND_REACH) < 2.0 and not hunting:
			continue
		if reach <= FoodField.SEND_REACH or hunting:
			sent += 1
			if not mb.seeded or int(mb.serial) != int(hb.serial) & 0xFFFF:
				missing += 1
				continue
			worst = maxf(worst, (mb.pos as Vector2).distance_to(hb.pos))
			if int(mb.meals) != int(hb.meals) or mb.genome != hb.genome:
				wrong += 1
		elif mb.seeded:
			too_far += 1
	var self_off: float = (mirror[FoodField.PERSON_SLOT].pos as Vector2).distance_to(
		host_cell.position)
	worst = maxf(worst, self_off)
	return [sent, worst, too_far, wrong, missing, self_off]


## **The guest's water against the snapshot it applied**, exactly: `[bodies
## checked, problems]`, no problems meaning all of it held. The host's watched
## field recorded that snapshot and the water it was built from, found here by
## the sequence the guest applied. The send set is worked out again from that
## water -- every seeded body within SEND_REACH of the guest, surface to
## centre, or hunting it, and nothing else -- and each body sent must be in the
## mirror under its (serial, meals), at the place sent (float32 both ways, so
## exact), heading and speed to half a wire step, carried from there by the
## snapshot's age along that heading, with the genome that body wore. A slot
## not sent must be empty.
func _pond_mirror_exact(host_food: Node, guest_food: Node, guest_pond: Object,
		host_net: Node) -> Array:
	var problems: Array[String] = []
	var applied := int(guest_pond.get("_applied"))
	var records: Array = host_food.get("built")
	var offset := int(host_net.get("_out_pond_seq")) - int(host_food.get("built_count"))
	var record: Array = []
	for each: Array in records:
		if int(each[0]) + offset == applied:
			record = each
	if record.is_empty():
		return [0, ["snapshot %d is not among the host's last %d" % [applied,
			records.size()]]]
	var entries: Array = record[1]
	var water: Array = record[2]
	var you: Vector2 = record[3]
	var person_serial := int(record[4])
	var sent := {}
	for entry: Array in entries:
		sent[int(entry[FoodField.Entry.SLOT])] = entry
	for i in FoodField.PERSON_SLOT:
		var w: Array = water[i]
		var should := false
		if bool(w[0]):
			var hunting := int(w[6]) == FoodField.State.STALK \
				and int(w[7]) == FoodField.PERSON_SLOT and int(w[8]) == person_serial
			should = hunting \
				or (w[1] as Vector2).distance_to(you) - float(w[2]) <= FoodField.SEND_REACH
		if should != sent.has(i):
			problems.append("slot %d %s" % [i, "left out" if should else "sent"])
	var mirror: Array = guest_food.bodies()
	var snap_at: PackedVector2Array = guest_food.get("_snap_at")
	var ahead := minf(float(guest_food.get("_snap_age")), FoodField.CARRY_MAX)
	var step := TAU / float(Wire.BEARING_STEPS)
	var checked := 0
	for i in FoodField.PERSON_SLOT:
		var mb: Object = mirror[i]
		if not sent.has(i):
			if bool(mb.seeded):
				problems.append("slot %d in the mirror, not sent" % i)
			continue
		var entry: Array = sent[i]
		checked += 1
		if not bool(mb.seeded) \
				or int(mb.serial) != int(entry[FoodField.Entry.SERIAL]) & 0xFFFF \
				or int(mb.meals) != int(entry[FoodField.Entry.MEALS]):
			problems.append("slot %d not the body sent" % i)
			continue
		var heading := float(mb.heading)
		var speed := float(mb.speed)
		if not snap_at[i].is_equal_approx(entry[FoodField.Entry.AT]) \
				or absf(angle_difference(heading, float(entry[FoodField.Entry.HEADING]))) \
					> step * 0.5 + 1e-4 \
				or absf(speed - float(entry[FoodField.Entry.SPEED])) \
					> Wire.POND_SPEED_STEP * 0.5 + 1e-3:
			problems.append("slot %d not where it was sent" % i)
		var carried: Vector2 = snap_at[i] + Vector2(sin(heading), -cos(heading)) \
			* (speed * ahead)
		if (mb.pos as Vector2).distance_to(carried) > 1e-3:
			problems.append("slot %d not carried by its age" % i)
		if mb.genome != (water[i] as Array)[5]:
			problems.append("slot %d wears another genome" % i)
	return [checked, problems]


func _pond_places(food: Node) -> Array:
	var out: Array = []
	for body: Object in food.bodies():
		out.append([int(body.serial), body.pos, bool(body.seeded)])
	return out


## How many bodies that were in the water both times moved between the two.
func _pond_moved(was: Array, now: Array) -> int:
	var moved := 0
	for i in mini(was.size(), now.size()):
		if not bool(was[i][2]) or not bool(now[i][2]) or int(was[i][0]) != int(now[i][0]):
			continue
		if (was[i][1] as Vector2).distance_to(now[i][1]) > 0.5:
			moved += 1
	return moved


## **A phone in a pocket**: every node of the run stopped, whatever mode it had
## -- the run keeps several on ALWAYS so that a pause cannot stop them, and a
## main loop that stops stops those too. Returns the modes to put back.
func _pond_stop(node: Node, modes: Dictionary = {}) -> Dictionary:
	modes[node] = node.process_mode
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_pond_stop(child, modes)
	return modes


func _pond_start(node: Node, modes: Dictionary) -> void:
	for each: Node in modes:
		if is_instance_valid(each):
			each.process_mode = modes[each]


# ---------------------------------------------------------------------------
# Plumbing.
# ---------------------------------------------------------------------------

## Deferred, because `root` is still setting up its own children while this
## probe's `_ready` runs and a direct `add_child` there fails with an error and
## a node that is never in the tree.
func _session(named: String) -> Node:
	var node: Node = NetSession.new()
	node.name = named
	get_tree().root.add_child.call_deferred(node)
	await node.ready
	return node


func _says(passed: bool, what: String) -> void:
	if passed:
		print("[net-probe] PASS %s" % what)
		return
	_failed += 1
	print("[net-probe] FAIL %s" % what)


## Waits for a link to reach a state, or gives up, so a broken handshake is a
## failing assertion rather than a job that runs until the runner kills it.
func _until_link(session: Node, want: int) -> void:
	var until := _now() + SETTLE
	while _now() < until:
		if int(session.link) == want:
			return
		await get_tree().process_frame


func _until_heard(session: Node, count: int) -> void:
	var until := _now() + SETTLE
	while _now() < until:
		if session.heard.size() >= count:
			return
		await get_tree().process_frame


## Waits for the peer track to reach a size, so a beat that never carries a
## body is a failing assertion instead of a job that runs until it is killed.
## [param count] 0 waits for it to go *empty*, which is what a run ending looks
## like from the other end.
func _until_tracked(session: Node, count: int) -> void:
	var until := _now() + SETTLE
	while _now() < until:
		var size: int = session.peer_track().size()
		if size == count if count == 0 else size >= count:
			return
		await get_tree().process_frame


## **One dash, timed from the far body to this screen's drawing of it.** The
## body rests long enough for the marker to settle, then leaves at a tier-1
## dash's speed along its nose with the water's drag on it -- reported every
## frame, as the run reports its own cell. Returns how much later than the body
## itself the drawn marker reached 2 and 20 units from where it rested, in
## seconds; INF for a level the marker never reached.
func _dash_onset(other: Node, view: Node, cell: Node, rest: Vector2) -> Array:
	var settle_until := _now() + 0.5
	while _now() < settle_until:
		other.report_body(rest, 0.0, 29.0)
		_pin(cell)
		await get_tree().process_frame
	var drawn_rest: Vector2 = view._peer["at"]
	var burst := Vector2(0.0, -1.0) * CellBody.DASH_SPEED_BY_TIER[1]
	var levels: Array[float] = [2.0, 20.0]
	var body_at: Array[float] = [INF, INF]
	var drawn_at: Array[float] = [INF, INF]
	var from := _clock()
	while _clock() - from < 1.0 and drawn_at[1] == INF:
		var t := _clock() - from
		var fade := exp(-CellBody.DRAG * t)
		var at := rest + burst * (1.0 - fade) / CellBody.DRAG
		other.report_body(at, 0.0, 29.0, burst * fade, 0.0)
		var mark: Dictionary = view._peer
		var seen := 0.0 if mark.is_empty() \
			else (mark["at"] as Vector2).distance_to(drawn_rest)
		for k in levels.size():
			if body_at[k] == INF and at.distance_to(rest) >= levels[k]:
				body_at[k] = t
			if drawn_at[k] == INF and seen >= levels[k]:
				drawn_at[k] = t
		_pin(cell)
		await get_tree().process_frame
	var out: Array = []
	for k in levels.size():
		out.append(INF if body_at[k] == INF or drawn_at[k] == INF
			else drawn_at[k] - body_at[k])
	return out


func _pin(cell: Node) -> void:
	cell.position = Vector2.ZERO
	cell.heading = 0.0
	cell.velocity = Vector2.ZERO


## **The same wait, with the cell pinned where the pose put it.**
##
## The assertions around it are about a *geometry* -- the other cell is due
## north, so the mark has to land dead ahead -- and a cell left to itself does
## not stay where it was put: it wanders, and one flagellar impulse inside the
## half second is 59 units of sideways, which at 400 units of range is a tenth
## of a radian of bearing. Measured: one run in ten missed a 0.01 rad tolerance
## for that reason and that reason only, and a gate that fails one run in ten
## is worse than no gate because it teaches people to re-run it.
##
## The harness reaching into the world on purpose, exactly as `tools/drive.gd`
## does in `_hold_world`, and for the same reason: the game has no such hook
## and must not grow one.
func _hold(cell: Node, at: Vector2, heading: float, seconds: float) -> void:
	var until := _now() + seconds
	while _now() < until:
		cell.position = at
		cell.heading = heading
		cell.velocity = Vector2.ZERO
		await get_tree().process_frame


## **Wall time, not frames.** net_session.gd keeps every clock on
## `Time.get_ticks_msec()` so that a backgrounded phone is not reported as
## fresh, and a probe that counted frames instead would race a headless build
## running at several thousand of them a second: 96 frames would be a tenth of
## a second of real time, and the 2 Hz heartbeat it is waiting for would not
## have beaten once.
func _wait(seconds: float) -> void:
	var until := _now() + seconds
	while _now() < until:
		await get_tree().process_frame


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## Microseconds, for the one measurement here that is shorter than a frame.
func _clock() -> float:
	return float(Time.get_ticks_usec()) / 1e6
