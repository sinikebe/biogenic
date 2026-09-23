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
## different protocol is refused with a sentence instead of hanging. Protocols 1
## and 2 are both refused by name, because neither is a hypothetical: they are
## the two builds that shipped before this one.
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
	_check_code()
	_check_wire()
	_check_carry()
	_check_pond_field()
	await _check_link()
	await _check_skew()
	await _check_run()
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
	# **Neither older protocol is a hypothetical.** 1 is the LAN build that
	# first shipped and 2 is the one that drew the friend half a second late;
	# both are on somebody's phone right now, because updates are opt-in, and a
	# 2 reads a protocol-3 state frame's motion as nothing it knows. The one
	# from the future is still worth its two seconds: the host cannot tell which
	# side is behind, and does not need to.
	for theirs: int in [Wire.PROTOCOL - 2, Wire.PROTOCOL - 1, Wire.PROTOCOL + 1]:
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
