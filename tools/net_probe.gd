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
## different protocol is refused with a sentence instead of hanging. Every
## protocol before this one -- 1 to 5 since protocol 6 -- is refused by name,
## because none is a hypothetical: each is a build that shipped.
##
## **And the pond, played** (shared-pond.md §5, Phase 2): two sessions and two
## real runs of the game, one hosting the water and one mirroring it, put
## through every lifecycle the pond has -- arriving, eating and being eaten,
## the black, dividing, a quiet host and a closed one. **And a held tail**
## (automation.md §18.3 check 7): a guest whose tail has two copies holds it
## still and lets it go, in the pond and on the server, slowly and as fast as a
## hand can, and the host's referee calls no foul -- on rules whose fingerprint,
## `Wire.RULES`, the tail did not move.
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
## **And the dedicated server** (`game/server/`, docs/server.md): the real
## server scene with two guests, each a real run of the game on this build's
## own guest code -- which is exactly the guest a phone that has never heard
## of a server runs -- arriving, mirroring each other as the friend,
## eating each other, being eaten by the water, leaving, and being told when
## the server stops. Then its update loop's decisions, against a fake release
## feed and a loopback HTTP server, with no network.
##
## **And the server's forward on the router** (`upnp`, docs/server.md §9.3):
## `game/net/port_forward.gd` against a router of this probe's own -- it maps at
## start, renews before the lease ends, falls back to a forward with no time
## limit, takes it off at a stop, leaves one it did not make, never maps the
## LAN's port, names a router that cannot help, and never holds a frame for a
## slow search -- and the server scene's `--no-upnp`, remembered and for one
## run. Not a packet leaves the machine.
##
## **And which pair of ports a build is on** (`channel`, `game/net/channel.gd`,
## docs/server.md "A dev server"): the release channel's 45771 and 45772, and a
## branch's 45781 and 45782, posed as each -- every socket the game binds and
## dials, with a dev server and a live one side by side on one address, the
## forward and its name, and every sentence that names a port, the release
## channel's word for word as before there were two.
##
## **And the door and the gate** (`limits`, docs/design/net-hardening.md A.8):
## hostile peers against a host of their own each -- every frame at and past
## its size bound, malformed and wrong-way frames, a command that is not a
## frame, callers that speak before their hello or never, a caller cut with
## packets already queued, a flood with the budgets enforced, as they ship, and
## with them only watched, and its control, a storm of calls and one
## address's storm beside another's first call, the queues by weight, a later
## build's frames, the LAN-only guard, and what a guest said outliving it. The
## pond and server sections then hold the other half: over every stage of two
## real runs, and a server with six guests, the gate never touched an honest
## peer: nothing dropped, struck or cut, and nothing even watched would have been.
##
## **Two of these run against a scene rather than a socket**, and both are here
## rather than in a render for the same reason: CI never sees a pixel. A `_draw`
## does fire under `--headless` -- 1,920 `draw` signals in 1,920 frames of a
## full-vision run, measured -- but into a renderer that keeps nothing, so
## anything computed inside one runs in CI and is checked by nothing.
## `game/vision/vision.gd` keeps every number the marker needs in a `_process`,
## and this reads it.
##
## Excluded from export (`tools/*` on every preset), so none of it ships.

const Wire := preload("res://game/net/wire.gd")
const Lan := preload("res://game/net/lan.gd")
const NetSession := preload("res://game/net/net_session.gd")
## The invite line and the server's book, for the `invites` section.
const Invite := preload("res://game/net/invite.gd")
const InviteBook := preload("res://game/server/invite_book.gd")
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
## The genes and their numbers by stat (docs/design/gene-catalogue.md): the tables
## the referee's rules fingerprint, the gift, the born body.
const Catalogue := preload("res://game/genes/catalogue.gd")
const Stats := preload("res://game/genes/stats.gd")
## The body plan (gene-catalogue.md §10): what the wire's genome limits come from.
const BodyPlan := preload("res://game/genes/body_plan.gd")
## For the run's own numbering -- Life, Split, the division's clocks and the
## pond's lines -- which the `pond` section reads off two real runs.
const NormalMode := preload("res://game/normal/normal_mode.gd")
## For the views, and the name each keeps its cells under (docs/design/cells.md
## §1.2), which `pond, kept` reads a player's own slots by.
const RunState := preload("res://game/run_state.gd")
## For the recording's own numbering, which the replay in a pond is checked by
## (shared-pond.md §5, Phase 3): what a PERSON row is, and where the friend sits
## in a frame.
const RecorderNode := preload("res://game/replay/recorder.gd")

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
	# The step runs this uncapped under `--quit-after 24000`, which counts
	# frames, and every wait in here is wall time -- so on a fast enough runner
	# twenty-four thousand frames arrive before the last check does, and the
	# probe is cut off one line short of `ALL PASS`. At 500 a second that is
	# forty-eight seconds, and most sections cap themselves lower still. The
	# `pond-field` section's seconds do not count against it: it runs to the end
	# inside this one call, so all of it is spent within a single frame. Nothing
	# here depends on a frame rate above that: every clock in `game/net/` is
	# wall time, and the dash is timed in microseconds either way.
	Engine.max_fps = 500
	# `--pond-only` is for working on the pond sections: the rest is skipped,
	# so an answer comes in seconds. CI never passes it, and it never prints
	# ALL PASS -- a partial run must not read as a whole one.
	# `--server-only` is the same for the dedicated host's section.
	if OS.get_cmdline_user_args().has("--server-only"):
		_check_code()
		await _check_server()
		await _check_server_updates()
		print("[net-probe] NOTE --server-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	# `--limits-only` is the same for the door and the gate (`limits`).
	if OS.get_cmdline_user_args().has("--limits-only"):
		await _check_limits()
		print("[net-probe] NOTE --limits-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	# `--invites-only` is the same for the internet listener and its invites
	# (net-hardening.md part C).
	if OS.get_cmdline_user_args().has("--invites-only"):
		await _check_invites()
		print("[net-probe] NOTE --invites-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	# `--upnp-only` is the same for the server's forward on the router.
	if OS.get_cmdline_user_args().has("--upnp-only"):
		await _check_upnp()
		print("[net-probe] NOTE --upnp-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	# `--channel-only` is the same for the channel: which pair of ports a build
	# is on, and everything that binds, dials or says one.
	if OS.get_cmdline_user_args().has("--channel-only"):
		await _check_channel()
		print("[net-probe] NOTE --channel-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	# `--referee-only` is the same for the referee (net-hardening.md part B):
	# its socket-free checks and the pond's own, which include the real game.
	if OS.get_cmdline_user_args().has("--referee-only"):
		_check_referee()
		Engine.max_fps = 250
		await _check_pond_referee()
		print("[net-probe] NOTE --referee-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	# `--kept-only` is the same for `pond, kept`: a player's own worlds and cells in
	# slots, through a real pond (docs/design/cells.md §2).
	if OS.get_cmdline_user_args().has("--kept-only"):
		Engine.max_fps = 250
		await _check_pond_kept()
		print("[net-probe] NOTE --kept-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	# `--sister-only` is the same for protocol 6's SISTER (automation.md §10.3):
	# its wire, the referee's fingerprint and the handshake's refusals -- checks
	# 24 to 26 but for the real divisions, which are the pond's and the server's.
	if OS.get_cmdline_user_args().has("--sister-only"):
		_check_pond_wire()
		_check_sister_wire()
		_check_referee()
		await _check_skew()
		print("[net-probe] NOTE --sister-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	var only_pond := OS.get_cmdline_user_args().has("--pond-only")
	if only_pond:
		_check_pond_wire()
		_check_sister_wire()
		_check_pond_field()
		_check_referee()
		await _check_pond()
		print("[net-probe] NOTE --pond-only: %d failed" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	_check_code()
	_check_wire()
	_check_pond_wire()
	_check_sister_wire()
	_check_carry()
	_check_pond_field()
	_check_referee()
	await _check_link()
	await _check_phone_door()
	await _check_skew()
	await _check_limits()
	await _check_run()
	await _check_pond()
	await _check_server()
	await _check_server_updates()
	await _check_invites()
	await _check_upnp()
	await _check_channel()
	# **The margin on CI's backstop, printed.** The step runs this with no
	# frame cap and `--quit-after 24000`, which is a count of frames, not of
	# seconds -- so a faster runner reaches it sooner, and a probe that grew
	# past it would be cut off before `ALL PASS` and read as a failure.
	print("[net-probe] NOTE finished in %d frames and %.1f s -- CI stops at"
		% [Engine.get_process_frames(), float(Time.get_ticks_msec()) / 1000.0]
		+ " 24000, and at most %d a second can arrive" % Engine.max_fps)
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
	# RFC 5737 documentation addresses: the derivation is prefix arithmetic, so
	# any IPv4 shows it.
	_says(Lan.host_address("192.0.2.9", 37) == "192.0.2.37"
			and Lan.host_address("", 37).is_empty()
			and Lan.host_address("192.0.2.9", 0).is_empty(),
		"the /24 derivation puts a tapped octet on this device's own prefix")
	_check_adapters()


## **Which adapter is the LAN** (`Lan.pick_address`), on adapter lists shaped as
## `IP.get_local_interfaces()` returns them. Every address here is a
## placeholder: RFC 5737's 192.0.2.x, and round values -- 192.168.0.10,
## 10.0.0.10, 172.16.0.10 -- standing in for the private ranges being ranked,
## and Android's stock tether addresses, which are the same on every phone.
func _check_adapters() -> void:
	var ranked := Lan.pick_address([
		{"name": "eth1", "friendly": "eth1", "addresses": ["172.16.0.10"]},
		{"name": "eth2", "friendly": "eth2", "addresses": ["10.0.0.10"]},
		{"name": "wlan0", "friendly": "wlan0", "addresses": ["192.168.0.10"]}])
	var ten := Lan.pick_address([
		{"name": "eth1", "friendly": "eth1", "addresses": ["172.16.0.10"]},
		{"name": "eth2", "friendly": "eth2", "addresses": ["10.0.0.10"]}])
	_says(ranked == "192.168.0.10" and ten == "10.0.0.10",
		"adapters: 192.168/16 beats 10/8 beats 172.16/12, whatever order they"
		+ " are listed in")
	# A Windows PC with WSL, Hyper-V and a VPN up, and its Wi-Fi last.
	var windows := Lan.pick_address([
		{"name": "{0}", "friendly": "vEthernet (WSL)", "addresses": ["192.168.0.10"]},
		{"name": "{1}", "friendly": "vEthernet (Default Switch)",
			"addresses": ["172.16.0.10"]},
		{"name": "{2}", "friendly": "OpenVPN Wintun", "addresses": ["10.0.0.10"]},
		{"name": "{3}", "friendly": "Wi-Fi", "addresses": ["fe80::1", "192.0.2.10"]}])
	# A Linux server with docker and a tailnet, and its real NIC on 10/8.
	var linux := Lan.pick_address([
		{"name": "docker0", "friendly": "docker0", "addresses": ["192.168.0.10"]},
		{"name": "br-0a1b2c", "friendly": "br-0a1b2c", "addresses": ["172.16.0.10"]},
		{"name": "veth1f2e", "friendly": "veth1f2e", "addresses": ["192.168.0.11"]},
		{"name": "tailscale0", "friendly": "tailscale0", "addresses": ["192.0.2.20"]},
		{"name": "eth0", "friendly": "eth0", "addresses": ["10.0.0.10"]}])
	# Proxmox's own LAN bridge is a real adapter, not a docker one.
	var bridge := Lan.pick_address([
		{"name": "veth100i0", "friendly": "veth100i0", "addresses": ["192.168.0.12"]},
		{"name": "vmbr0", "friendly": "vmbr0", "addresses": ["10.0.0.10"]}])
	_says(windows == "192.0.2.10" and linux == "10.0.0.10" and bridge == "10.0.0.10",
		"adapters: a real one beats every virtual and VPN one, even in a better"
		+ " range -- Windows %s, Linux %s, a Proxmox bridge %s"
		% [windows, linux, bridge])
	var only_virtual := Lan.pick_address([
		{"name": "lo", "friendly": "lo", "addresses": ["127.0.0.1"]},
		{"name": "wg0", "friendly": "wg0", "addresses": ["192.0.2.30"]}])
	var none := Lan.pick_address([
		{"name": "lo", "friendly": "lo", "addresses": ["127.0.0.1", "::1"]},
		{"name": "eth0", "friendly": "eth0", "addresses": ["169.254.3.4"]}])
	_says(only_virtual == "192.0.2.30" and none.is_empty(),
		"adapters: a machine on a VPN alone still answers with it, and loopback"
		+ " and link-local are never an answer")
	# **An address no code can carry.** A code is the last number, 1 to 254; a
	# machine on a network wider than a /24 can be x.x.x.0 or x.x.x.255 --
	# a release runner once was, and its server never said READY.
	_says(NetSession.hostable("192.0.2.0", 2) and NetSession.hostable("192.0.2.255", 2)
			and not NetSession.hostable("192.0.2.0", 1)
			and not NetSession.hostable("192.0.2.255", 1)
			and NetSession.hostable("192.0.2.9", 1) and NetSession.hostable("192.0.2.9", 2)
			and not NetSession.hostable("", 1) and not NetSession.hostable("", 2),
		"a dedicated host listens at an address no code can carry (x.x.x.0,"
		+ " x.x.x.255) and a phone host does not; nobody listens with no address")
	# **A phone's own tethers.** Android hands its hotspot, USB and Bluetooth
	# tethers the same stock addresses on every phone -- 192.168.43.1,
	# 192.168.42.129, 192.168.44.1, nobody's network in particular -- so all
	# three outrank a 10.x Wi-Fi on range alone. On the Wi-Fi, the Wi-Fi is the
	# LAN; a phone that IS the hotspot, with only its cellular data besides,
	# answers with the tether, which is the LAN its friend joins.
	var joined: PackedStringArray = []
	var hosting: PackedStringArray = []
	for tether: Array in [["swlan0", "192.168.43.1"], ["rndis0", "192.168.42.129"],
			["bt-pan", "192.168.44.1"]]:
		joined.append(Lan.pick_address([
			{"name": tether[0], "friendly": tether[0], "addresses": [tether[1]]},
			{"name": "wlan0", "friendly": "wlan0", "addresses": ["10.0.0.10"]}]))
		hosting.append(Lan.pick_address([
			{"name": "rmnet_data0", "friendly": "rmnet_data0",
				"addresses": ["10.0.0.10"]},
			{"name": tether[0], "friendly": tether[0], "addresses": [tether[1]]}]))
	_says(joined == PackedStringArray(["10.0.0.10", "10.0.0.10", "10.0.0.10"])
			and hosting == PackedStringArray(["192.168.43.1", "192.168.42.129",
				"192.168.44.1"]),
		"adapters: a phone on a 10.x Wi-Fi with a hotspot, USB or Bluetooth"
		+ " tether up answers with the Wi-Fi (%s); a phone that is the tether,"
		% ", ".join(joined) + " with only cellular besides, answers with the"
		+ " tether (%s)" % ", ".join(hosting))
	# **Where a phone hosts** (issue #104): never on its cellular data, whose
	# private addresses a carrier shares with every other subscriber, though a
	# guest's side still answers with it; beside Wi-Fi, on the Wi-Fi; and when
	# it is a hotspot, on the hotspot. 100.64.0.10 stands in for a carrier's
	# pool (RFC 6598); 192.0.0.4 is the address Android gives every phone's
	# IPv4 over an IPv6-only network.
	var cellular := [{"name": "rmnet_data0", "friendly": "rmnet_data0",
		"addresses": ["10.0.0.10"]}]
	var beside_wifi := cellular + [{"name": "wlan0", "friendly": "wlan0",
		"addresses": ["192.168.0.10"]}]
	var beside_hotspot := cellular + [{"name": "swlan0", "friendly": "swlan0",
		"addresses": ["192.168.43.1"]}]
	var nowhere: PackedStringArray = []
	for adapter: Array in [["ccmni1", "ccmni1", "100.64.0.10"],
			["seth_lte0", "seth_lte0", "10.0.0.11"], ["sipa_eth0", "sipa_eth0", "10.0.0.16"],
			["pdp_ip0", "pdp_ip0", "10.0.0.12"],
			["wwan0", "wwan0", "10.0.0.13"], ["wwp0s20f0u6", "wwp0s20f0u6", "10.0.0.14"],
			["{4}", "Cellular", "10.0.0.15"],
			["v4-rmnet_data0", "v4-rmnet_data0", "192.0.0.4"]]:
		if Lan.pick_hosting([{"name": adapter[0], "friendly": adapter[1],
				"addresses": [adapter[2]]}]).is_empty():
			nowhere.append(str(adapter[1]))
	# A tether outside 192.168/16, as Android may hand out, still beats the
	# cellular data it sits beside: cellular ranks below every other adapter.
	var tether_ten := cellular + [{"name": "swlan0", "friendly": "swlan0",
		"addresses": ["10.0.0.20"]}]
	var tether_172 := cellular + [{"name": "rndis0", "friendly": "rndis0",
		"addresses": ["172.16.0.20"]}]
	_says(Lan.pick_hosting(cellular).is_empty() and Lan.pick_address(cellular) == "10.0.0.10"
			and Lan.pick_hosting(beside_wifi) == "192.168.0.10"
			and Lan.pick_hosting(beside_hotspot) == "192.168.43.1"
			and Lan.pick_hosting(tether_ten) == "10.0.0.20"
			and Lan.pick_hosting(tether_172) == "172.16.0.20" and nowhere.size() == 8,
		"adapters: a phone on cellular data alone hosts nowhere -- nor on %s --" % ", ".join(
			nowhere) + " though its guest's side still answers with it; beside Wi-Fi it"
		+ " hosts on the Wi-Fi, and when it is a hotspot, on the hotspot, in 192.168/16,"
		+ " 10/8 or 172.16/12 alike")


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

	# **The tail, since protocol 8** (gene-catalogue.md §11.3): the rules a build
	# judges and decides contacts by, and its content version, after the frozen
	# prefix of every handshake frame -- and a HELLO with it still within
	# HANDSHAKE_MAX, so a host of any build reads its prefix and refuses it by name.
	var rules8 := Rules.fingerprint()
	var tail8 := Wire.tail(rules8, 4242)
	var hello8 := Wire.hello(Wire.PROTOCOL, tail8)
	var welcome8 := Wire.welcome(Wire.PROTOCOL, big, tail8)
	var refuse8 := Wire.refuse(Wire.PROTOCOL, Wire.REFUSE_PROTOCOL, tail8)
	var read8 := true
	for each8: PackedByteArray in [hello8, welcome8, refuse8]:
		read8 = read8 and Wire.rules_of(each8) == rules8 \
			and Wire.content_of(each8) == 4242 and Wire.protocol_of(each8) == Wire.PROTOCOL \
			and each8.size() <= Wire.HANDSHAKE_MAX
	var bare7 := Wire.hello(Wire.PROTOCOL - 1)
	var cut8 := hello8.slice(0, hello8.size() - 1)
	_says(read8 and hello8.size() == Wire.HELLO_SIZE + Wire.TAIL_SIZE
			and Wire.welcome_host_id(welcome8) == big
			and Wire.refuse_reason(refuse8) == Wire.REFUSE_PROTOCOL
			and Wire.rules_of(bare7).is_empty() and Wire.content_of(bare7) == -1
			and Wire.rules_of(cut8).is_empty() and Wire.content_of(cut8) == -1
			and rules8.size() == Wire.RULES_SIZE and Rules.SIZE == Wire.RULES_SIZE
			and Wire.tail(PackedByteArray([1, 2]), 7).size() == Wire.TAIL_SIZE,
		"the handshake's tail: a HELLO with the rules and the content version is %d"
		% hello8.size() + " bytes of the %d any host reads, a WELCOME %d and a REFUSE"
		% [Wire.HANDSHAKE_MAX, welcome8.size()] + " %d, each read back whole; a frame" % refuse8.size()
		+ " with no tail, as a 7 sends, or one cut short of it, has no rules and no content")

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
			and FoodField.ENTRY_SLOT == Wire.Entry.size()
			and Wire.POND_STALKING == FoodField.FLAG_STALKING
			and Wire.POND_IS_PERSON == FoodField.FLAG_PERSON
			and Wire.POND_IN_WATER == FoodField.FLAG_IN_WATER
			and Wire.SEND_MAX == FoodField.SEND_MAX
			and Wire.POND_BODIES_MAX == FoodField.SEND_MAX + 1
			and Wire.PERSON_ID == FoodField.PERSON_ID
			and Wire.CONTACT_ATE == FoodField.Contact.ATE
			and Wire.CONTACT_KILLED == FoodField.Contact.KILLED
			and Wire.CONTACT_GRAZED == FoodField.Contact.GRAZED,
		"pond wire: the snapshot's entry order, its flags, its send set, the"
		+ " person's id and the contact numbers are the field's own")

	# **The budget, at its worst** (ocean.md §10.4): the send set's sixty water
	# bodies and the other player, every one of them sent, ids past 16 bits.
	# One ENet datagram under the MTU.
	var bodies: Array = []
	for i in Wire.SEND_MAX:
		bodies.append([70001 + 977 * i, i % 7, Wire.POND_STALKING if i % 5 == 0 else 0,
			Vector2(-3000.5 + 91.25 * i, 1777.75 - 13.5 * i), -3.0 + 0.09 * i,
			4.0 + 0.61 * i, float(i % 11) / 10.0, 2.0 * float(i % 90), Vector2.ZERO,
			0.0])
	bodies.append([Wire.PERSON_ID, 255,
		Wire.POND_IS_PERSON | Wire.POND_IN_WATER, Vector2(512.25, -96.5), 1.5, 28.28,
		0.4, 44.0, Vector2(-37.5, 12.25), -0.75])
	var whole := Wire.pond(123456, 0.62, bodies)
	_says(whole.size() == Wire.POND_MAX and Wire.POND_MAX == 1181,
		"pond wire: sixty water bodies and a person make %d bytes, the budget's"
		% whole.size() + " 1,181 -- one datagram under ENet's 1,392")
	var said := Wire.take_pond(whole)
	var exact := said.size() == 4 and int(said[0]) == 123456 \
		and absf(float(said[1]) - 0.62) <= 0.5 / 255.0 \
		and (said[2] as Array).size() == bodies.size()
	var worst_heading := 0.0
	if exact:
		for k in bodies.size():
			var sent: Array = bodies[k]
			var got: Array = said[2][k]
			worst_heading = maxf(worst_heading, absf(angle_difference(
				float(got[Wire.Entry.HEADING]), float(sent[Wire.Entry.HEADING]))))
			if int(got[Wire.Entry.ID]) != int(sent[Wire.Entry.ID]) \
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
		"pond wire: every body round-trips -- id, meals, flags, place"
		+ " exactly, radius to 1/64, wound to 1/255, speed to 2 u/s, heading to"
		+ " half a step (worst %.4f rad) -- and the person's motion exactly"
		% worst_heading)
	# **The loads, since protocol 7** (docs/design/dna-slots.md §14.2): the three
	# the recipient carries, in the header, at none, at the most its bytes say,
	# between, and past it -- held there, and a load that is not a number sent as
	# none; and a body's three flags, each its own bit beside the three before.
	var loads_back: Array = []
	for loads: PackedFloat64Array in [PackedFloat64Array([0.0, 0.0, 0.0]),
			PackedFloat64Array([63.75, 63.75, 63.75]), PackedFloat64Array([12.3, 0.25, 7.6]),
			PackedFloat64Array([64.0, 400.0, INF])]:
		var got := Wire.take_pond(Wire.pond(9, 0.25, bodies.slice(0, 2), loads))
		loads_back.append(Array(got[3]) if got.size() == 4 else [])
	var flagged: Array = []
	for k in 3:
		flagged.append((bodies[k] as Array).duplicate())
	flagged[0][Wire.Entry.FLAGS] = Wire.POND_HARMED
	flagged[1][Wire.Entry.FLAGS] = Wire.POND_PARALYSED | Wire.POND_STALKING
	flagged[2][Wire.Entry.FLAGS] = Wire.POND_ASLEEP | Wire.POND_HARMED | Wire.POND_PARALYSED
	var flags_back := Wire.take_pond(Wire.pond(10, 0.0, flagged))
	var flags_kept := flags_back.size() == 4 and (flags_back[2] as Array).size() == 3
	if flags_kept:
		for k in 3:
			flags_kept = flags_kept and int(flags_back[2][k][Wire.Entry.FLAGS]) \
				== int(flagged[k][Wire.Entry.FLAGS])
	_says(loads_back == [[0.0, 0.0, 0.0], [63.75, 63.75, 63.75], [12.25, 0.25, 7.5],
			[63.75, 63.75, 0.0]] and flags_kept and Wire.POND_LOADS == 3
			and Wire.POND_LOAD_SCALE == 4.0
			and Wire.POND_HARMED == FoodField.FLAG_HARMED
			and Wire.POND_PARALYSED == FoodField.FLAG_PARALYSED
			and Wire.POND_ASLEEP == FoodField.FLAG_ASLEEP,
		"pond wire: the recipient's three loads round-trip at a quarter stack -- %s"
		% str(loads_back) + " for none, the most, between and past it -- and a body's"
		+ " harmed, paralysed and asleep flags are its own bits (%s), the field's own"
		% str(flags_kept))

	# Refused whole: every truncation, one byte too many, a slot that is not one,
	# a place that is not finite, a motion no body could have.
	var refuses := true
	for cut in whole.size():
		if not Wire.take_pond(whole.slice(0, cut)).is_empty():
			refuses = false
			break
	var longer := whole.duplicate()
	longer.append(0)
	var bad_id := whole.duplicate()
	bad_id.encode_u32(Wire.POND_HEADER, Wire.PERSON_ID)
	var bad_person := whole.duplicate()
	bad_person.encode_u32(whole.size() - Wire.POND_PERSON, 42)
	var bad_place := whole.duplicate()
	bad_place.encode_float(Wire.POND_HEADER + 6, NAN)
	var bad_motion := whole.duplicate()
	bad_motion.encode_float(whole.size() - 12, INF)
	var too_many := whole.duplicate()
	too_many[6] = Wire.POND_BODIES_MAX + 1
	_says(refuses and Wire.take_pond(longer).is_empty()
			and Wire.take_pond(bad_id).is_empty()
			and Wire.take_pond(bad_person).is_empty()
			and Wire.take_pond(bad_place).is_empty()
			and Wire.take_pond(bad_motion).is_empty()
			and Wire.take_pond(too_many).is_empty(),
		"pond wire: a snapshot is refused whole at every truncation, one byte"
		+ " long, with a water body under the person's id or the person under a"
		+ " body's, a place or a motion that is not finite, or a count past 61")
	# And never written: a body the reader would refuse is left out, and a
	# motion no body could have goes as none.
	var rotten: Array = bodies.slice(0, 3)
	rotten[1] = rotten[1].duplicate()
	rotten[1][Wire.Entry.AT] = Vector2(NAN, 0.0)
	var person: Array = bodies[bodies.size() - 1].duplicate()
	person[Wire.Entry.VELOCITY] = Vector2(Wire.MOTION_MAX * 2.0, 0.0)
	rotten.append(person)
	var cleaned := Wire.take_pond(Wire.pond(1, 0.0, rotten))
	_says(cleaned.size() == 4 and (cleaned[2] as Array).size() == 3
			and (cleaned[2][2][Wire.Entry.VELOCITY] as Vector2) == Vector2.ZERO,
		"pond wire: a body the reader would refuse is never written, and an"
		+ " impossible motion goes as none")
	# **Never past the budget, whatever the writer is handed** (review): sixty-
	# one bodies all flagged as people would be 1,899 bytes, which ENet sends as
	# fragments -- one lost, the whole snapshot lost. The writer leaves out what
	# would not fit, and the reader refuses a longer frame outright, however
	# well formed.
	var people: Array = []
	for i in Wire.POND_BODIES_MAX:
		var one: Array = (bodies[bodies.size() - 1] as Array).duplicate()
		people.append(one)
	var capped := Wire.pond(7, 0.0, people)
	var capped_said := Wire.take_pond(capped)
	var fits := floori(float(Wire.POND_MAX - Wire.POND_HEADER) / float(Wire.POND_PERSON))
	var over := capped.duplicate()
	over.append_array(capped.slice(capped.size() - Wire.POND_PERSON))
	over[6] = int(over[6]) + 1
	_says(capped.size() <= Wire.POND_MAX and capped_said.size() == 4
			and (capped_said[2] as Array).size() == fits
			and over.size() > Wire.POND_MAX and Wire.take_pond(over).is_empty(),
		"pond wire: sixty-one people are written as the %d that fit, %d bytes of"
		% [fits, capped.size()] + " %d; one more, well formed at %d bytes, is"
		% [Wire.POND_MAX, over.size()] + " refused")

	# The nine events, each against its decoder.
	# A phase-1 body: venom worn on an arc, poison inside -- in the genome by its
	# name and in no slot of the order, which is the worn layout outside.
	var worn := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 2, &"toxicyst": 1,
		&"veneneux": 1, &"ampulla": 2}
	var order: Array = [&"cytostome", &"", &"cirrus", &"flagellum", &"ampulla", &"",
		&"toxicyst"]
	var enter := Wire.event(9, Wire.EVENT_ENTER, Wire.enter_payload(28.28))
	var arrive := Wire.event(10, Wire.EVENT_ARRIVE,
		Wire.arrive_payload(Vector2(560.5, -12.25), 1.0, Vector2(-1234.5, 777.25), 6000.0))
	var person_frame := Wire.event(11, Wire.EVENT_PERSON,
		Wire.person_payload(true, worn, order))
	var genome := Wire.event(12, Wire.EVENT_GENOME,
		Wire.genome_payload(3000000001, 4, worn))
	var ate := Wire.event(13, Wire.EVENT_CONTACT, Wire.contact_payload(
		FoodField.Contact.ATE, Vector2(3.5, -4.5), 0.93, FoodField.By.FRIEND,
		&"veneneux"))
	var killed := Wire.event(14, Wire.EVENT_CONTACT, Wire.contact_payload(
		FoodField.Contact.KILLED, Vector2(-8.0, 2.0), 0.0, FoodField.By.WATER, &"",
		FoodField.Cause.POISONED))
	var bit := Wire.event(15, Wire.EVENT_CONTACT, Wire.contact_payload(
		FoodField.Contact.BITTEN, Vector2(1.0, 1.0), 0.37, FoodField.By.WATER))
	var died := Wire.event(16, Wire.EVENT_DIED, Wire.died_payload(
		FoodField.Cause.CHEWED, FoodField.By.FRIEND, Vector2(-44.5, 90.0)))
	var sister := Wire.event(17, Wire.EVENT_SISTER, Wire.sister_payload(
		Vector2(700.0, -3.0), -1.25, 28.28, worn))
	var settle := Wire.event(18, Wire.EVENT_SETTLE, Wire.settle_payload(4000000123,
		Vector2(-812.5, 4410.25), 12.75, 0.4, 97.25))
	var clear := Wire.event(19, Wire.EVENT_CLEAR, Wire.clear_payload(4000000123))
	var grazed := Wire.event(20, Wire.EVENT_CONTACT, Wire.contact_payload(
		FoodField.Contact.GRAZED, Vector2(10.5, -2.0), 0.62, FoodField.By.WATER))
	var e := Wire.take_enter(enter)
	var a := Wire.take_arrive(arrive)
	var p := Wire.take_person(person_frame)
	var g := Wire.take_genome(genome)
	var c := Wire.take_contact(ate)
	var k := Wire.take_contact(killed)
	var b := Wire.take_contact(bit)
	var d := Wire.take_died(died)
	var s := Wire.take_sister(sister)
	var st := Wire.take_settle(settle)
	var cl := Wire.take_clear(clear)
	var gr := Wire.take_contact(grazed)
	var step := TAU / float(Wire.BEARING_STEPS)
	_says(enter.size() == Wire.ENTER_SIZE and arrive.size() == Wire.ARRIVE_SIZE
			and died.size() == Wire.DIED_SIZE and bit.size() == Wire.CONTACT_SIZE
			and killed.size() == Wire.CONTACT_SIZE + 1
			and settle.size() == Wire.SETTLE_SIZE and clear.size() == Wire.CLEAR_SIZE
			and grazed.size() == Wire.CONTACT_SIZE
			and Wire.ARRIVE_SIZE == 27 and Wire.SETTLE_SIZE == 22 and Wire.CLEAR_SIZE == 10,
		"pond wire: ENTER %d, ARRIVE %d, DIED %d and CONTACT %d bytes, as §2 says"
		% [enter.size(), arrive.size(), died.size(), bit.size()]
		+ " (KILLED one more, for its cause); SETTLE %d and CLEAR %d, and ARRIVE with"
		% [settle.size(), clear.size()] + " its rim, as ocean.md §10.4 says")
	_says(e.size() == 1 and is_equal_approx(float(e[0]), 28.28)
			and a.size() == 4 and (a[0] as Vector2).is_equal_approx(Vector2(560.5, -12.25))
			and absf(angle_difference(float(a[1]), 1.0)) <= step * 0.5
			and (a[2] as Vector2).is_equal_approx(Vector2(-1234.5, 777.25))
			and is_equal_approx(float(a[3]), 6000.0)
			and p.size() == 3 and bool(p[0]) and p[1] == worn and p[2] == order
			and g.size() == 3 and int(g[0]) == 3000000001 and int(g[1]) == 4
			and g[2] == worn,
		"pond wire: ENTER, ARRIVE with the drop's rim, PERSON and GENOME round-trip --"
		+ " the worn genome by name, with its empty slots, and a body's id past 31"
		+ " bits whole")
	_says(st.size() == 5 and int(st[0]) == 4000000123
			and (st[1] as Vector2).is_equal_approx(Vector2(-812.5, 4410.25))
			and is_equal_approx(float(st[2]), 12.75)
			and absf(float(st[3]) - 0.4) <= 0.5 / Wire.POND_WOUND_SCALE
			and absf(float(st[4]) - 97.25) <= 0.5 / Wire.SETTLE_LIFE_SCALE
			and cl.size() == 1 and int(cl[0]) == 4000000123
			and gr.size() == 6 and int(gr[0]) == FoodField.Contact.GRAZED
			and is_equal_approx(float(gr[2]), 0.62) and gr[4] == &"",
		"pond wire: SETTLE carries a floc's id, place, size, settle and life, CLEAR"
		+ " its id, and a GRAZED CONTACT its nutrition and no gene")
	_says(c.size() == 6 and int(c[0]) == FoodField.Contact.ATE
			and (c[1] as Vector2).is_equal_approx(Vector2(3.5, -4.5))
			and is_equal_approx(float(c[2]), 0.93) and int(c[3]) == FoodField.By.FRIEND
			and c[4] == &"veneneux" and int(c[5]) == 0
			and k.size() == 6 and int(k[5]) == FoodField.Cause.POISONED
			and k[4] == &"" and b.size() == 6 and is_equal_approx(float(b[2]), 0.37)
			and d.size() == 3 and int(d[0]) == FoodField.Cause.CHEWED
			and int(d[1]) == FoodField.By.FRIEND
			and (d[2] as Vector2).is_equal_approx(Vector2(-44.5, 90.0))
			and s.size() == 6 and (s[0] as Vector2).is_equal_approx(Vector2(700.0, -3.0))
			and absf(angle_difference(float(s[1]), -1.25)) <= step * 0.5
			and is_equal_approx(float(s[2]), 28.28) and s[3] == worn
			and (s[4] as Dictionary).is_empty() and (s[5] as PackedStringArray).is_empty(),
		"pond wire: CONTACT carries an ATE's gene and a KILLED's cause, and DIED"
		+ " and SISTER round-trip -- a SISTER that names no DNA and no list reads as"
		+ " neither")
	var events := [enter, arrive, person_frame, genome, ate, killed, bit, died, sister,
		settle, clear, grazed]
	var cut_ok := true
	for frame: PackedByteArray in events:
		for cut in frame.size():
			var short := frame.slice(0, cut)
			if not (Wire.take_enter(short).is_empty() and Wire.take_arrive(short).is_empty()
					and Wire.take_person(short).is_empty()
					and Wire.take_genome(short).is_empty()
					and Wire.take_contact(short).is_empty()
					and Wire.take_died(short).is_empty()
					and Wire.take_sister(short).is_empty()
					and Wire.take_settle(short).is_empty()
					and Wire.take_clear(short).is_empty()):
				cut_ok = false
		var long := frame.duplicate()
		long.append(0)
		if not (Wire.take_enter(long).is_empty() and Wire.take_arrive(long).is_empty()
				and Wire.take_person(long).is_empty() and Wire.take_genome(long).is_empty()
				and Wire.take_contact(long).is_empty() and Wire.take_died(long).is_empty()
				and Wire.take_sister(long).is_empty() and Wire.take_settle(long).is_empty()
				and Wire.take_clear(long).is_empty()):
			cut_ok = false
	_says(cut_ok, "pond wire: every event is refused at every truncation and one"
		+ " byte long, by every decoder")

	# **Genomes by name**: the reader refuses the whole message on a name that
	# is not 1-16 bytes of a-z, on more genes than the body plan has slots and one
	# more -- seven outside, one inside and a held sample, since protocol 7 -- or
	# more slots than it has outside; tiers clamp to 0..3; the writer never sends
	# what the reader refuses. As many as that are taken. **The counts are held to
	# what they come from** -- the plan, and genome.gd's tiers (gene-catalogue.md
	# §13) -- never to a number.
	var loud := Wire.take_person(Wire.event(1, Wire.EVENT_PERSON,
		Wire.person_payload(false, {&"cytostome": 9, &"cirrus": -2}, [])))
	var ten := {}
	for i in Wire.GENES_MAX + 1:
		ten[StringName("gene" + String.chr(97 + i))] = 1
	var ten_frame := Wire.event(1, Wire.EVENT_PERSON, Wire.person_payload(false, {}, []))
	ten_frame.resize(Wire.EVENT_HEADER + 1)
	ten_frame.append(ten.size())
	for gene: StringName in ten:
		ten_frame.append(String(gene).length())
		ten_frame.append_array(String(gene).to_ascii_buffer())
		ten_frame.append(1)
	ten_frame.append(0)
	var nine := ten.duplicate()
	nine.erase(ten.keys().back())
	var nine_said := Wire.take_person(Wire.event(1, Wire.EVENT_PERSON,
		Wire.person_payload(false, nine, [])))
	var named := func(name: String, tier: int = 1) -> PackedByteArray:
		var f := Wire.event(1, Wire.EVENT_PERSON, PackedByteArray([0, 1]))
		f.append(name.to_utf8_buffer().size())
		f.append_array(name.to_utf8_buffer())
		f.append(tier)
		f.append(0)
		return f
	var clamped := Wire.take_person(named.call("cytostome", 9))
	var eight_slots := Wire.event(1, Wire.EVENT_PERSON,
		PackedByteArray([0, 0, Wire.ORDER_MAX + 1]))
	for i in Wire.ORDER_MAX + 1:
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
			and Wire.take_person(ten_frame).is_empty()
			and nine_said.size() == 3 and nine_said[1] == nine
			and Wire.GENES_MAX == BodyPlan.SLOTS + 1 and Wire.ORDER_MAX == BodyPlan.SLOT_MAX
			and Wire.TIER_TOP == Genome.TIER_MAX
			and Wire.take_person(eight_slots).is_empty(),
		("pond wire: a genome is refused whole on a name that is not 1-16 bytes of"
		+ " a-z, %d genes or %d slots, and %d are taken -- the body plan's %d slots and"
		+ " one more, and its %d outside; tiers clamp to 0..%d, genome.gd's") % [
			Wire.GENES_MAX + 1, Wire.ORDER_MAX + 1, Wire.GENES_MAX, BodyPlan.SLOTS,
			BodyPlan.SLOT_MAX, Wire.TIER_TOP])
	var past: Array[StringName] = [&"cytostome", &"Bad Name", &""]
	while past.size() < Wire.ORDER_MAX + 2:
		past.append(StringName(String.chr(97 + past.size() - 3)))
	var written := Wire.take_person(Wire.event(1, Wire.EVENT_PERSON,
		Wire.person_payload(false, {&"cytostome": 1, &"Bad Name": 2, &"": 1}, past)))
	_says(written.size() == 3 and (written[1] as Dictionary).size() == 1
			and (written[2] as Array).size() == Wire.ORDER_MAX
			and written[2][1] == &"",
		"pond wire: and the writer leaves out what the reader would refuse --"
		+ " a bad name is not sent, a bad slot goes empty, past %d slots stop"
		% Wire.ORDER_MAX)


# ---------------------------------------------------------------------------
# **Protocol 6's SISTER** (docs/design/automation.md §10.3; §18.3 checks 24 and
# 25): a guest's sister carries her DNA and the list her cell ran. Socket-free:
# the writer against the reader, every refusal against the gate's own parse,
# and the host's reading of her lines with its own vocabulary. The real
# divisions -- on a phone host, and in the server's room through a save and a
# load -- are the `pond` and `server` sections'.
# ---------------------------------------------------------------------------

## The host's reading of a guest's sister's lines (`Pond.sister_list`).
const Pond := preload("res://game/net/pond.gd")
## **A rule of a gene no build of this game declares**: what a later build's
## gene looks like to this one -- a rule that never fires, kept as it came.
const LATER_LINE := "xenogene.hum above 0.5 -> body.turn-away"
## **A guest's sister's list**, as a page builds one: three rules this build
## reads -- a gene's sense, the metabolism's and one that always acts -- and
## [constant LATER_LINE].
const SISTER_LINES: Array[String] = ["palp.touch closeness above 0.5 -> body.turn-away",
	"metabolism.hunger below 0.3 -> body.rest", LATER_LINE, "always -> body.swim"]


func _check_sister_wire() -> void:
	var vocab := FoodField.vocabulary()
	# **The tables written out twice** -- drop.gd's eight, held here -- and the
	# alphabet's two spellings, the reader's test and the documented string, the
	# same over every byte there is.
	var alphabet := true
	for code in 256:
		var listed := code > 0 and Wire.RULE_BYTES.contains(String.chr(code))
		if Wire._rule_byte_ok(code) != listed:
			alphabet = false
	# **Only a SISTER gets the room**: every other guest frame keeps the cap a
	# PERSON set before protocol 6, and the cap is read off the event's type. The
	# first four frames are a byte past that cap, whatever the body plan makes it: a
	# frame under it is never read for its type at all.
	var padded := func(kind: int, type: int, size: int) -> PackedByteArray:
		var frame := PackedByteArray([kind, 0, 0, 0, 0, type])
		frame.resize(size)
		return frame
	var past := Wire.GUEST_OTHER_MAX + 1
	var caps := [Wire.guest_cap(padded.call(Wire.KIND_EVENT, Wire.EVENT_SISTER, past)),
		Wire.guest_cap(padded.call(Wire.KIND_EVENT, Wire.EVENT_PERSON, past)),
		Wire.guest_cap(padded.call(Wire.KIND_STATE, Wire.EVENT_SISTER, past)),
		Wire.guest_cap(padded.call(0x20, Wire.EVENT_SISTER, past)),
		Wire.guest_cap(padded.call(Wire.KIND_EVENT, Wire.EVENT_SISTER, Wire.SISTER_MIN)),
		Wire.guest_cap(PackedByteArray())]
	# **1378 is the pin a plan change moves**: the body plan's slot count is in every
	# size that holds a genome. The plan's fingerprint rides in the handshake's rules
	# since protocol 8, so no protocol moves with it -- said where it fails.
	var pinned := Wire.SISTER_MAX == 1378
	_says(Wire.MOST_RULES == FoodField.Drop.MOST_RULES and alphabet
			and Wire.RULE_BYTES.length() == 40 and Wire.RULE_BYTES_MAX == 128
			and Wire.SISTER_MAX == Wire.EVENT_HEADER + 13 + 2 * Wire.TIERS_MAX + 1
				+ 8 * (1 + Wire.RULE_BYTES_MAX)
			and pinned and Wire.SISTER_MIN == Wire.EVENT_HEADER + 16
			and Wire.GUEST_FRAME_MAX == maxi(Wire.PERSON_MAX, Wire.SISTER_MAX)
			and Wire.GUEST_OTHER_MAX == Wire.PERSON_MAX
			and caps == [Wire.SISTER_MAX, Wire.GUEST_OTHER_MAX, Wire.GUEST_OTHER_MAX,
				Wire.GUEST_OTHER_MAX, Wire.GUEST_OTHER_MAX, Wire.GUEST_OTHER_MAX],
		"sister wire: a list holds drop.gd's %d rules, each line 1 to %d bytes of"
		% [FoodField.Drop.MOST_RULES, Wire.RULE_BYTES_MAX] + " the %d of a-z, 0-9,"
		% Wire.RULE_BYTES.length() + " '.', '-', '>' and the space; a SISTER is %d"
		% Wire.SISTER_MIN + " to %d bytes, automation.md §10.3's sum, and the one"
		% Wire.SISTER_MAX + " guest frame that may pass the %d every other keeps"
		% Wire.GUEST_OTHER_MAX + " (caps read %s)" % str(caps) + ("" if pinned
			else " -- the body plan's slots changed (%d genes cross now): move the 1378 here"
			% Wire.GENES_MAX + " and Wire.RULES in the same commit -- no Wire.PROTOCOL: the"
			+ " plan is in the rules the handshake carries, and builds on other plans refuse"
			+ " each other there (body_plan.gd)"))

	# **Every line this build can write crosses**: each word a rule's line is
	# made of -- every name the declarations give, the tests, the references,
	# every rung of every ladder, every option and the arrow -- is of the
	# alphabet, and so are the water's seven. A merged list holds nothing else,
	# unless a later build wrote a line into the library's file, which is kept
	# there as it came and which the writer leaves out if the reader would not
	# take it.
	var words := _line_words(vocab)
	var unfit: PackedStringArray = []
	for word: String in words:
		if not Wire._line_ok(word):
			unfit.append(word)
	for line: String in FoodField.Drop.FOUNDERS:
		if not Wire._line_ok(line):
			unfit.append(line)
	var longest := _longest_line(vocab)
	_says(unfit.is_empty() and not longest.is_empty() and Wire._line_ok(longest),
		"sister wire: the %d words a rule's line is made of are of the alphabet,"
		% words.size() + " and so are the water's seven; the longest rule the"
		+ " vocabulary reads is %d bytes of %d -- '%s'" % [longest.length(),
			Wire.RULE_BYTES_MAX, longest]
		+ ("" if unfit.is_empty() else " -- NOT: " + ", ".join(unfit)))

	# **Check 24, on the wire**: her body, her DNA and her list cross exactly --
	# a gene at no copies is not carried, and a list of nothing is the
	# founders' -- and the host reads the lines with its own vocabulary, a later
	# build's rule kept as it came.
	var body := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 2}
	var dna := {&"cytostome": 2, &"cirrus": 1, &"flagellum": 3, &"ampulla": 1,
		&"palp": 2, &"stigma": 0}
	var carried := dna.duplicate()
	carried.erase(&"stigma")
	var lines := PackedStringArray(SISTER_LINES)
	var at := Vector2(-812.5, 4410.25)
	var frame := Wire.event(21, Wire.EVENT_SISTER, Wire.sister_payload(at, 2.0,
		Referee.DAUGHTER_RADIUS, body, dna, lines))
	var said := Wire.take_sister(frame)
	var bare := Wire.take_sister(Wire.event(22, Wire.EVENT_SISTER, Wire.sister_payload(at,
		2.0, Referee.DAUGHTER_RADIUS, body, dna)))
	var read: Array = _list_said(Pond.sister_list(said[5]) if said.size() == 6 else null)
	_says(said.size() == 6 and (said[0] as Vector2) == at
			and is_equal_approx(float(said[2]), Referee.DAUGHTER_RADIUS)
			and said[3] == body and said[4] == carried and said[5] == lines
			and bare.size() == 6 and bare[4] == carried
			and (bare[5] as PackedStringArray).is_empty() and Pond.sister_list(bare[5]) == null
			and read[0] == lines and read[1] == [false, false, true, false],
		"sister wire (check 24): a guest's sister crosses with her body, her DNA --"
		+ " %d genes, the one at no copies not carried -- and her list of %d lines,"
		% [carried.size(), lines.size()] + " in %d bytes; the host reads them with"
		% frame.size() + " its own vocabulary, the rule of a gene it does not know"
		+ " kept as a rule that never fires and written back as it came; a SISTER"
		+ " with no lines gives her the founders' rules")

	# **SISTER_MAX is the most the writer writes** -- two genomes of nine
	# sixteen-letter genes at three copies, and eight lines of 128 bytes -- and
	# handed more, it writes no more: a gene the wire cannot name, a ninth line,
	# an empty one, one of 129 bytes and one in capitals are each left out. The
	# writer never sends what the reader refuses.
	var full := {}
	for i in Wire.GENES_MAX:
		full[StringName(String.chr(97 + i).repeat(Wire.NAME_MAX))] = Wire.TIER_TOP
	var overfull := {&"Cirrus": 1, StringName("z".repeat(Wire.NAME_MAX + 1)): 2}
	overfull.merge(full)
	var most := PackedStringArray()
	for i in Wire.MOST_RULES + 1:
		most.append(_rule_line_of(Wire.RULE_BYTES_MAX, i))
	var crowded := PackedStringArray([most[0], "", _rule_line_of(Wire.RULE_BYTES_MAX + 1, 99),
		"Chemocyte.smell above 0.5 -> body.swim"])
	crowded.append_array(most.slice(1))
	var biggest := Wire.sister_payload(at, 2.0, Referee.DAUGHTER_RADIUS, overfull, overfull,
		crowded)
	var biggest_said := Wire.take_sister(Wire.event(23, Wire.EVENT_SISTER, biggest))
	_says(biggest.size() + Wire.EVENT_HEADER == Wire.SISTER_MAX and biggest_said.size() == 6
			and biggest_said[3] == full and biggest_said[4] == full
			and biggest_said[5] == most.slice(0, Wire.MOST_RULES),
		"sister wire: SISTER_MAX, %d bytes, is the most the writer writes -- two"
		% Wire.SISTER_MAX + " genomes of nine sixteen-letter genes and eight lines"
		+ " of 128 -- and handed more it writes no more: a gene the wire cannot name,"
		+ " a ninth line, an empty one, one of 129 bytes and one in capitals are left"
		+ " out")

	# **Check 25: the refusals.** Each by hand, the way no writer of this build
	# writes it, against the reader and against the gate's own parse
	# (`NetSession._parses`, its step 8): refused whole, so the guest that sent it
	# is struck and nothing is placed. Then what lies just inside every bound,
	# taken.
	var ascii := func(text: String) -> PackedByteArray: return text.to_ascii_buffer()
	var worn := [[ascii.call("cytostome"), 1], [ascii.call("cirrus"), 1],
		[ascii.call("flagellum"), 2]]
	var dna_said := [[ascii.call("cytostome"), 2], [ascii.call("ampulla"), 1]]
	var two := [ascii.call(SISTER_LINES[0]), ascii.call(SISTER_LINES[1])]
	var nine: Array = []
	for i in Wire.MOST_RULES + 1:
		nine.append(ascii.call(_rule_line_of(48, i)))
	var ten_genes: Array = []
	for i in Wire.GENES_MAX + 1:
		ten_genes.append([ascii.call("gene" + String.chr(97 + i)), 1])
	var refused := {
		"nine instincts": _sister_by_hand(worn, dna_said, nine),
		"a count of nine": _sister_by_hand(worn, dna_said, nine.slice(0, 8), 9),
		"a line of 129 bytes": _sister_by_hand(worn, dna_said,
			[ascii.call(_rule_line_of(Wire.RULE_BYTES_MAX + 1, 1))]),
		"an empty line": _sister_by_hand(worn, dna_said, [two[0], PackedByteArray()]),
		"a DNA gene of 17 letters": _sister_by_hand(worn, [[ascii.call("q".repeat(17)), 1]],
			two),
		"a DNA gene in capitals": _sister_by_hand(worn, [[ascii.call("Ampulla"), 1]], two),
		"a DNA gene with no name": _sister_by_hand(worn, [[PackedByteArray(), 1]], two),
		"a DNA gene with a digit": _sister_by_hand(worn, [[ascii.call("cili5"), 1]], two),
		"ten DNA genes": _sister_by_hand(worn, ten_genes, two),
		"a byte after the last line": _sister_by_hand(worn, dna_said, two, -1,
			PackedByteArray([0])),
		"a line past its count": _sister_by_hand(worn, dna_said, two, 1),
		"a protocol 5 SISTER, her body alone": _sister_by_hand(worn, [], [], -2),
	}
	var wrong: PackedStringArray = []
	for name: String in refused:
		var f: PackedByteArray = refused[name]
		if not Wire.take_sister(f).is_empty() \
				or NetSession._parses(Wire.KIND_EVENT, Wire.EVENT_SISTER, f):
			wrong.append(name)
	var outside := 0
	for code in 256:
		if Wire._rule_byte_ok(code):
			continue
		var odd: PackedByteArray = ascii.call(SISTER_LINES[3])
		odd[6] = code
		var f := _sister_by_hand(worn, dna_said, [two[0], odd])
		outside += 1
		if not Wire.take_sister(f).is_empty() \
				or NetSession._parses(Wire.KIND_EVENT, Wire.EVENT_SISTER, f):
			wrong.append("byte %d" % code)
	var every := PackedByteArray()
	for code in 256:
		if Wire._rule_byte_ok(code):
			every.append(code)
	var taken := {
		"eight instincts": _sister_by_hand(worn, dna_said, nine.slice(0, 8)),
		"a line of 128 bytes": _sister_by_hand(worn, dna_said,
			[ascii.call(_rule_line_of(Wire.RULE_BYTES_MAX, 1))]),
		"a line of every byte of the alphabet": _sister_by_hand(worn, dna_said, [every]),
		"a line of one byte": _sister_by_hand(worn, dna_said, [PackedByteArray([62])]),
		"no DNA and no list": _sister_by_hand(worn, [], []),
		"a DNA gene at no copies": _sister_by_hand(worn, [[ascii.call("ampulla"), 0]], two),
	}
	for name: String in taken:
		var f: PackedByteArray = taken[name]
		if Wire.take_sister(f).is_empty() \
				or not NetSession._parses(Wire.KIND_EVENT, Wire.EVENT_SISTER, f) \
				or not Wire.size_ok(Wire.KIND_EVENT, Wire.EVENT_SISTER, f.size(), false):
			wrong.append("NOT TAKEN: " + name)
	var at_no_copies := Wire.take_sister(taken["a DNA gene at no copies"])
	if at_no_copies.size() != 6 or not (at_no_copies[4] as Dictionary).is_empty():
		wrong.append("a gene at no copies carried")
	var whole: PackedByteArray = taken["eight instincts"]
	var cuts := 0
	for cut in whole.size():
		if not Wire.take_sister(whole.slice(0, cut)).is_empty():
			wrong.append("cut at %d" % cut)
		cuts += 1
	_says(wrong.is_empty() and outside == 256 - Wire.RULE_BYTES.length() and cuts > 300,
		"sister wire (check 25): the whole SISTER is refused, by the reader and by the"
		+ " gate's own parse, on %s; on each of the %d bytes outside the alphabet in a"
		% [", ".join(PackedStringArray(refused.keys())), outside] + " line; and at every"
		+ " one of %d truncations -- and %s are taken" % [cuts,
			", ".join(PackedStringArray(taken.keys()))]
		+ ("" if wrong.is_empty() else " -- NOT: " + ", ".join(wrong)))


## **A SISTER written by hand**, so a test can say what no writer of this build
## would: [param worn] and [param dna] as `[name bytes, tier]` pairs, [param lines]
## as raw bytes, [param count] the count byte as said -- -1 for the true one, -2
## for none, a protocol-5 SISTER's shape -- and [param tail] any bytes after.
static func _sister_by_hand(worn: Array, dna: Array, lines: Array, count := -1,
		tail := PackedByteArray()) -> PackedByteArray:
	var out := Wire.event(30, Wire.EVENT_SISTER, Wire.sister_payload(Vector2(560.0, 0.0),
		0.0, Referee.DAUGHTER_RADIUS, {}))
	out.resize(Wire.EVENT_HEADER + 13)
	var genomes: Array = [worn] if count == -2 else [worn, dna]
	for genome: Array in genomes:
		out.append(genome.size())
		for gene: Array in genome:
			var name: PackedByteArray = gene[0]
			out.append(name.size())
			out.append_array(name)
			out.append(int(gene[1]))
	if count == -2:
		return out
	out.append(lines.size() if count < 0 else count)
	for line: PackedByteArray in lines:
		out.append(line.size())
		out.append_array(line)
	out.append_array(tail)
	return out


## **A line of exactly [param size] bytes** of the alphabet: [constant LATER_LINE]
## numbered [param n], padded out.
static func _rule_line_of(size: int, n: int) -> String:
	return ("%s %d " % [LATER_LINE, n] + "x".repeat(size)).left(size)


## **Every word a rule's line can hold**, as `rulebook.gd`'s `line_of` writes
## them, from [param vocab]: its inputs and their values, its outputs and their
## options, the tests, the references, every rung of every ladder, `always` and
## the arrow.
static func _line_words(vocab: Variant) -> PackedStringArray:
	var words := PackedStringArray([String(FoodField.Rulebook.ALWAYS),
		FoodField.Rulebook.ARROW])
	words.append_array(PackedStringArray(FoodField.Rulebook.TEST_WORDS))
	for ref: StringName in FoodField.Rulebook.REFERENCES:
		words.append(String(ref))
	for kind: StringName in FoodField.Rulebook.LADDERS:
		for rung: float in FoodField.Rulebook.LADDERS[kind]:
			words.append(FoodField.Rulebook.number(rung))
	var inputs: Dictionary = vocab.get("inputs")
	for name: StringName in inputs:
		words.append(String(name))
		for value: StringName in (inputs[name] as Object).get("values"):
			words.append(String(value))
	var outputs: Dictionary = vocab.get("outputs")
	for name: StringName in outputs:
		words.append(String(name))
		for option: float in (outputs[name] as Object).get("options"):
			words.append(FoodField.Rulebook.number(option))
	return words


## **The longest rule [param vocab] reads**: for each input, every value it
## carries tested at its longest -- a rule tests a value once -- driving each
## output at its longest option, kept when the rulebook reads it as a rule that
## fires.
static func _longest_line(vocab: Variant) -> String:
	var heads: Array = [String(FoodField.Rulebook.ALWAYS)]
	var inputs: Dictionary = vocab.get("inputs")
	for name: StringName in inputs:
		var input: Object = inputs[name]
		var values: Array = input.get("values")
		var kinds: Array = input.get("kinds")
		var head := String(name)
		for k in values.size():
			var against: PackedStringArray = []
			if StringName(kinds[k]) == FoodField.Rulebook.SIZE:
				for ref: StringName in FoodField.Rulebook.REFERENCES:
					against.append(String(ref))
			else:
				for rung: float in FoodField.Rulebook.LADDERS[StringName(kinds[k])]:
					against.append(FoodField.Rulebook.number(rung))
			var widest := "falling"
			for each: String in against:
				if ("below " + each).length() > widest.length():
					widest = "below " + each
			head += " %s %s" % [values[k], widest]
		heads.append(head)
	var longest := ""
	var outputs: Dictionary = vocab.get("outputs")
	for head: String in heads:
		for name: StringName in outputs:
			var tail := String(name)
			var option := ""
			for each: float in (outputs[name] as Object).get("options"):
				if FoodField.Rulebook.number(each).length() > option.length():
					option = FoodField.Rulebook.number(each)
			if not option.is_empty():
				tail += " " + option
			var whole := "%s %s %s" % [head, FoodField.Rulebook.ARROW, tail]
			if whole.length() > longest.length() \
					and not bool(FoodField.Rulebook.rule_from(whole, vocab).get("inert")):
				longest = whole
	return longest


## **What a list says, as lines**, and which of its rules never fire: `[lines,
## inert flags]` -- no lines for the founders', null.
static func _list_said(brain: Variant) -> Array:
	if brain == null:
		return [PackedStringArray(), []]
	var inert: Array = []
	for rule: Object in (brain as Object).get("rules"):
		inert.append(bool(rule.get("inert")))
	return [FoodField.Rulebook.lines_of(brain), inert]


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

## **A phone host answers its own /24 alone** (issue #104) -- and loopback, for
## the tools -- where a dedicated host answers every house address. A friend
## finds a phone by its code, which is the friend's own /24 with the phone's
## last number on it, so nothing outside it is a friend's call. Asked of each
## door itself, with a house address from another /24 -- 10.20.30.40, or
## 10.20.31.40 should the host be in the first -- so it is outside wherever
## this runs.
func _check_phone_door() -> void:
	var phone: Node = await _session("PhoneDoor")
	var hosted: bool = phone.host()
	var at := str(phone.address)
	var own := Lan._v4_any(at)
	var inside := "%d.%d.%d.%d" % [own[0], own[1], own[2], (own[3] % 250) + 2] \
		if own.size() == 4 else ""
	var next_door := "10.20.30.40" if not Lan.same_24("10.20.30.40", at) \
		else "10.20.31.40"
	var callers := [inside, "::ffff:" + inside, "127.0.0.9", "::1", next_door, "100.64.0.10",
		"fd00::7", "fe80::7"]
	var said: Array = []
	for from: String in callers:
		var no: Array = phone._admit(from, NetSession.VIA_LAN)
		said.append("ok" if no.is_empty() else str(no[0]))
	await _limits_close([phone])
	var server: Node = await _session("ServerDoor")
	server.host(NetSession.GUESTS_MAX)
	var at_server: Array = server._admit(next_door, NetSession.VIA_LAN)
	await _limits_close([server])
	_says(hosted and said == ["ok", "ok", "ok", "ok", "lan", "lan", "lan", "lan"]
			and at_server.is_empty(),
		"a phone host at %s answers its own /24, in IPv4 clothes or not, and loopback,"
		% at + " and refuses another /24 (%s), a carrier's pool and IPv6's"
		% next_door + " own networks -- %s -- where a dedicated host answers that /24"
		% ", ".join(said) + " as a house address")


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

	# **ENet's packet throttle, pinned where it starts** (issue #61). ENet
	# discards unreliable frames at the sender in proportion to it, and a jittery
	# round trip lowers it; every state frame and snapshot is unreliable. Each
	# end sets its own peer's deceleration to 0 the moment the transport
	# connects, before either goes TOGETHER -- so this is read, not waited for,
	# and it is exact on any runner.
	var host_throttle := _enet_peer(host, guest.my_id())
	var guest_throttle := _enet_peer(guest, host.my_id())
	_says(_pinned(host_throttle) and _pinned(guest_throttle),
		"both ends' ENet peers are pinned -- [interval, acceleration, deceleration,"
		+ " throttle] %s on the host and %s on the guest, deceleration 0 and"
		% [str(_throttle_knobs(host_throttle)), str(_throttle_knobs(guest_throttle))]
		+ " throttle %d of %d" % [ENetPacketPeer.PACKET_THROTTLE_SCALE,
			ENetPacketPeer.PACKET_THROTTLE_SCALE])

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

	# **One end is enough to pin both directions**, which is what lets the fix
	# ship as content: a phone still on an older pack runs the same ENet in its
	# binary, and ENet takes the three numbers the far end sends it in a
	# THROTTLE_CONFIGURE command. A bare ENet client stands in for that phone:
	# it pins nothing itself, so its deceleration can only reach 0 by the host's
	# command. Waited for, since the command crosses the socket -- reliably, on
	# loopback, so in a frame or two. Only the three numbers are asserted, not
	# the client's throttle: until the command lands its own round trips could
	# move that, and no verdict here hangs on a round trip.
	var older := ENetConnection.new()
	var older_peer: ENetPacketPeer = null
	if older.create_host(1) == OK:
		# The id a client offers ENet's server: 2 or more, and nobody else's.
		older_peer = older.connect_to_host("127.0.0.1", Lan.channel_port(), 0,
			3 if guest.my_id() == 2 else 2)
	var older_knobs: Array = []
	var older_until := _now() + SETTLE
	# Until the host hangs up, too: it does, on a peer that never says hello,
	# after HELLO_GRACE -- which this wait, against a pinned host, never nears.
	while older_peer != null and older_peer.is_active() and _now() < older_until:
		var event: Array = older.service()
		while int(event[0]) > ENetConnection.EVENT_NONE:
			event = older.service()
		if not older_peer.is_active():
			break
		older_knobs = _throttle_knobs(older_peer).slice(0, 3)
		if older_peer.get_state() == ENetPacketPeer.STATE_CONNECTED \
				and older_knobs == [NetSession.THROTTLE_INTERVAL,
					NetSession.THROTTLE_ACCELERATION, 0]:
			break
		await get_tree().process_frame
	_says(older_knobs == [NetSession.THROTTLE_INTERVAL,
			NetSession.THROTTLE_ACCELERATION, 0],
		"and one end pins both: a bare ENet client, an older pack that pins"
		+ " nothing, is told [interval, acceleration, deceleration] %s by the host"
		% str(older_knobs))
	if older_peer != null and older_peer.is_active():
		older_peer.peer_disconnect_now()
	older.destroy()

	host.close()
	guest.close()
	await _wait(0.6)


# ---------------------------------------------------------------------------
# Version skew. The highest-value assertion in this file.
# ---------------------------------------------------------------------------

func _check_skew() -> void:
	# **No older protocol is a hypothetical.** 1 is the LAN build that first
	# shipped, 2 is the one that drew the friend half a second late, 3 is the
	# one with a friend who cannot eat you and no pond, 4 is today's water
	# shared, whose snapshot is keyed on a slot, and 5 is the drop shared, whose
	# SISTER says a guest's sister's body and nothing more; all of them are on
	# somebody's phone right now, because updates are opt-in. A 4 reads a
	# protocol-5 snapshot's ids as slots (ocean.md §10.4), and a 5 refuses a
	# protocol-6 SISTER and leaves its division unanswered (automation.md
	# §10.3). So every one of them is refused by name, 5 included. The one from
	# the future is still worth its two seconds: the host cannot tell which side
	# is behind, and does not need to.
	var older: Array = range(1, Wire.PROTOCOL)
	var named: Array = []
	for theirs: int in older + [Wire.PROTOCOL + 1]:
		if await _one_skew(theirs):
			named.append(theirs)
	# **Check 26** (automation.md §18.3): every older protocol refused by name,
	# and the rules a host judges by pinned -- since protocol 8 they ride on the
	# handshake, and moving them is the pin's to say, not a protocol's.
	_says(named == older + [Wire.PROTOCOL + 1]
			and _rules_text().sha256_text() == Wire.RULES,
		"handshake (check 26): a guest on each of protocols %s is refused by a host"
		% ", ".join(PackedStringArray(older.map(func(p: int) -> String: return str(p))))
		+ " on %d by name, with the sentence that names the update, as is one on %d;"
		% [Wire.PROTOCOL, Wire.PROTOCOL + 1] + " and the rules it judges by are the"
		+ " ones pinned, Wire.RULES %s" % Wire.RULES.left(16))
	await _rules_skew()
	await _welcome_skew()


## **This build's HELLO, as a session sends it** (protocol 8): the frozen prefix
## and the rules' tail, content version 0. What a bare client says to be greeted.
static func _hello() -> PackedByteArray:
	return Wire.hello(Wire.PROTOCOL, Wire.tail(Rules.fingerprint(), 0))


## **A faster tail**, filed as the tail's own organ with one variant whose speed is
## its own -- one more gene the referee judges, as the gene probe files one.
## Registered by the caller, and forgotten by its organ's name.
static func _faster_tail() -> Object:
	var plain := Catalogue.first_provider(&"impulse_speed")
	var speed: Array = Catalogue.table(plain, &"impulse_speed")
	var swift: Array = []
	for value: Variant in speed:
		swift.append(float(value) * 1.6)
	swift[0] = speed[0]
	var tail: Object = (Catalogue.gene(plain).get_script() as GDScript).new()
	tail.set(&"variants", [{"variant": &"probeswift", "order": 920, "born": 0,
		"provides": {&"impulse_speed": swift}}])
	return tail


## **A palp that feels further**, the palp's own organ with one variant whose reach
## is its own: one more gene that changes nothing a host judges or decides a
## contact by.
static func _longer_palp() -> Object:
	var plain := Catalogue.first_provider(&"touch_range")
	var reach: Array = Catalogue.table(plain, &"touch_range")
	var longer: Array = []
	for value: Variant in reach:
		longer.append(float(value) * 1.5)
	var palp: Object = (Catalogue.gene(plain).get_script() as GDScript).new()
	palp.set(&"variants", [{"variant": &"probefeel", "order": 921, "born": 0,
		"provides": {&"touch_range": longer}}])
	return palp


## **Version skew under one protocol** (gene-catalogue.md §11.4), with two builds
## modelled in one process: a session takes its rules as it starts, so a guest
## that starts while one more organ is registered is a build whose catalogue has
## it, against a host that started without.
##
## - **One more judged gene** -- a faster tail -- and the two refuse each other at
##   the handshake, the guest refused by name and told which game is older by the
##   content version on the tail, both ways round;
## - **one more gene that judges nothing** -- a palp that feels further -- and the
##   rules are the same, so the two play, and the gene crosses by its name to a
##   host that has never heard of it, which keeps it as a name;
## - and **a name the wire would refuse cannot be in the catalogue**: the gene
##   probe holds every key to the wire's alphabet and length, and this holds the
##   two probes' bounds to one another.
func _rules_skew() -> void:
	var ours := Rules.fingerprint()
	Catalogue.register(_faster_tail())
	var judged := Rules.fingerprint()
	Catalogue.forget(Catalogue.organ_of(&"probeswift"))
	Catalogue.register(_longer_palp())
	var unjudged := Rules.fingerprint()
	Catalogue.forget(Catalogue.organ_of(&"probefeel"))
	_says(judged != ours and unjudged == ours and Rules.fingerprint() == ours,
		"skew: one more gene the referee judges, a faster tail, makes other rules"
		+ " (%s against %s); one more that judges nothing, a palp that feels further,"
		% [judged.hex_encode().left(8), ours.hex_encode().left(8)]
		+ " leaves them as they are, and so does taking each out again")
	var named := 0
	for pair: Array in [[5, 6], [7, 6]]:
		if await _one_rules_skew(int(pair[0]), int(pair[1])):
			named += 1
	_says(named == 2, "skew (§11.4): a guest on one more judged gene is refused at the"
		+ " handshake on one protocol, by name, both ways round -- the older game, by its"
		+ " content version, told to take the update")
	await _unjudged_plays()
	var alphabet := true
	for key: StringName in Catalogue.keys():
		var text := String(key)
		alphabet = alphabet and text.length() >= 1 and text.length() <= Wire.NAME_MAX
		for c: String in text:
			alphabet = alphabet and c >= "a" and c <= "z"
	_says(alphabet, "skew (§11.4): every name in the catalogue, the %d keys, is one the"
		% Catalogue.keys().size() + " wire carries -- 1 to %d letters of a-z" % Wire.NAME_MAX)


## **The guest's half of the rules check, on the LAN** (§11.3; net_session.gd's
## `_take_welcome`): a host that welcomes it on other rules -- another build's tail,
## one more judged gene on a later content -- or with no tail at all is a host whose
## own check let it through, and the guest refuses it from its end with the version
## sentence, told which game is older by the content on the WELCOME, and never plays.
func _welcome_skew() -> void:
	for case: Array in [["another build's tail, on a later content", _other_tail(6),
			"yours", "its own"], ["no tail at all", PackedByteArray(), "theirs", "the host's"]]:
		var ended: Array = await _welcomed_by_other("Welcome%d" % (case[1] as PackedByteArray).size(),
			case[1], {})
		_says(int(ended[0]) == NetSession.Link.REFUSED and str(ended[1]) == "different versions"
				and str(ended[3]).contains("launcher") and str(ended[3]).contains(str(case[2]))
				and not bool(ended[4]),
			"skew (§11.3): a guest on content 5 welcomed with %s gives up on the WELCOME as"
			% case[0] + " different versions, told it is %s game that is older ('%s'), and"
			% [case[3], ended[3]] + " is never together with that host -- it %s" % ("was, for"
				+ " a while" if bool(ended[4]) else "never was"))


## **A host whose every handshake frame carries a tail not its own** -- another
## build's, or none -- as a host whose own check let a guest through would welcome
## it: its refusal path broken, or a build that never had one. Its check of a guest's
## HELLO is the real one, against its real rules, so it welcomes this build's guest.
class OtherTail extends "res://game/net/net_session.gd":
	var other := PackedByteArray()

	func _tail() -> PackedByteArray:
		return other


## **Another build's handshake tail**: the rules of a catalogue with one more judged
## gene -- the faster tail -- and [param content], its content version.
static func _other_tail(content: int) -> PackedByteArray:
	Catalogue.register(_faster_tail())
	var rules := Rules.fingerprint()
	Catalogue.forget(Catalogue.organ_of(&"probeswift"))
	return Wire.tail(rules, content)


## **A guest on content 5 welcomed with [param tail]** by an [OtherTail] host -- a
## phone's on the LAN, or, given [param invite], a server's that it calls by it and
## proves it to: `[the link it ended on, its trouble, its trouble key, the sentence
## under it, whether it was ever together]`.
func _welcomed_by_other(named: String, tail: PackedByteArray, invite: Dictionary) -> Array:
	var host := OtherTail.new()
	host.name = named + "Host"
	host.other = tail
	_tally_on(host)
	get_tree().root.add_child.call_deferred(host)
	await host.ready
	var guest: Node = await _session(named + "Guest")
	guest.content_override = 5
	var links: Array = []
	guest.link_changed.connect(func(to: int) -> void: links.append(to))
	if invite.is_empty():
		host.host()
		guest.join("127.0.0.1")
		await _until_link(guest, NetSession.Link.REFUSED)
	else:
		host.host(NetSession.GUESTS_MAX)
		host.listen_internet(_inv_key, _inv_cert)
		host.set_invites(InviteBook.table(INVITES_ROOT))
		await _invites_call(guest, invite)
	var ended := [int(guest.link), str(guest.trouble), str(guest.trouble_key),
		str(guest.because), links.has(NetSession.Link.TOGETHER)]
	host.close()
	guest.close()
	await _wait(0.4)
	return ended


## One guest on [param guest_content] with one more judged gene, against a host on
## [param host_content] without it: true when it was refused by name, told which
## game is older, and every line below passed.
func _one_rules_skew(guest_content: int, host_content: int) -> bool:
	var failed := _failed
	var host: Node = await _session("HostRules%d" % guest_content)
	var guest: Node = await _session("GuestRules%d" % guest_content)
	host.content_override = host_content
	guest.content_override = guest_content
	host.host()
	Catalogue.register(_faster_tail())
	guest.join("127.0.0.1")
	Catalogue.forget(Catalogue.organ_of(&"probeswift"))
	await _until_link(guest, NetSession.Link.REFUSED)
	var guest_older := guest_content < host_content
	_says(int(guest.link) == NetSession.Link.REFUSED and guest.trouble == "different versions"
			and int(guest.refused_for) == Wire.REFUSE_PROTOCOL,
		"a guest on content %d with one more judged gene is refused by a host on %d,"
		% [guest_content, host_content] + " on one protocol, as different versions")
	_says(guest.because.contains("launcher") and guest.because.contains(
			"yours" if guest_older else "theirs"),
		"and told it is %s game that is older: '%s'" % ["its own" if guest_older
			else "the host's", guest.because])
	_says(host.trouble == "different versions" and host.because.contains(
			"theirs" if guest_older else "yours") and host.peer_count() == 0
			and int(host.link) != NetSession.Link.TOGETHER,
		"the host is told too, the other way round, and keeps nothing of it: '%s'"
		% host.because)
	_says(guest.heard.is_empty() and guest.peer_track().is_empty(),
		"nothing from the refused guest's host reached its game")
	host.close()
	guest.close()
	await _wait(0.4)
	return _failed == failed


## **One more gene that judges nothing, and they play**: a guest that started with a
## palp that feels further is welcomed by a host that started without it, and its
## PERSON names the palp to a host that does not know it -- the name whole, its
## copies and its slot.
func _unjudged_plays() -> void:
	var host: Node = await _session("HostUnjudged")
	var guest: Node = await _session("GuestUnjudged")
	host.host()
	Catalogue.register(_longer_palp())
	guest.join("127.0.0.1")
	Catalogue.forget(Catalogue.organ_of(&"probefeel"))
	await _until_link(guest, NetSession.Link.TOGETHER)
	var born := Catalogue.born_order()
	var tiers := Catalogue.born().duplicate()
	tiers[&"probefeel"] = 2
	var order: Array = Array(born) + [&"probefeel"]
	guest.send_event(Wire.EVENT_PERSON, Wire.person_payload(true, tiers, order))
	var until := _now() + SETTLE
	while _now() < until and (host.pond_events as Array).is_empty():
		await get_tree().process_frame
	var got: Array = []
	for frame: PackedByteArray in host.pond_events:
		got = Wire.take_person(frame)
		if not got.is_empty():
			break
	var kept := not got.is_empty() and int((got[1] as Dictionary).get(&"probefeel", 0)) == 2 \
		and (got[2] as Array).has(&"probefeel") and not Catalogue.known(&"probefeel")
	_says(int(guest.link) == NetSession.Link.TOGETHER and int(host.link) == NetSession.Link.TOGETHER
			and kept,
		"skew (§11.4): a guest with one more gene that judges nothing plays -- the two"
		+ " are together, the rules the same -- and its PERSON names it to a host that"
		+ " does not know it, whole: %s" % (str(got[1]) if not got.is_empty() else "nothing"))
	host.close()
	guest.close()
	await _wait(0.4)


## One guest on [param theirs] against a host on this build: true when it was
## refused by name, and every line below passed.
func _one_skew(theirs: int) -> bool:
	var failed := _failed
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
	return _failed == failed


# ---------------------------------------------------------------------------
# **The door and the gate** (docs/design/net-hardening.md A.8; issues #56 and
# #58). Every test opens a host of its own, and the door's memory belongs to
# the socket, so one test's bars and buckets never reach the next. A hostile
# peer is either a real guest's session made to send what no writer produces
# -- `_to` is the one way out of it, and tools may reach it -- or a [Rogue], a
# bare ENet client that writes any first byte, any size, any kind. Nothing is
# timed against a budget a slow runner could miss: every wait ends the moment
# its answer is in, and every number asserted is the ledger's own arithmetic.
# ---------------------------------------------------------------------------

## The frame rate for this section: nothing in it is finer than a tenth of a
## second, and at a hundred a second its sixteen-odd seconds cost CI's backstop
## about 1,600 frames.
const LIMITS_FPS := 100


## **A peer that is not a Biogenic build**: a bare ENet client that writes
## whatever it is told to and keeps every packet it is sent, whole -- the RAW
## byte and all. Polled once a frame; it never answers anything by itself.
class Rogue extends Node:
	var peer := ENetMultiplayerPeer.new()
	## The id it offered the host, which is the id the host knows it by.
	var id := 0
	var got: Array[PackedByteArray] = []
	## When a refusal reached it, and when its transport went down: -1 for
	## not yet.
	var refused_at := -1.0
	var down_at := -1.0

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func call_host() -> bool:
		if peer.create_client("127.0.0.1", Lan.channel_port()) != OK:
			return false
		id = peer.get_unique_id()
		return true

	## **The same caller at the internet listener** (net-hardening.md C): DTLS
	## pinned to [param certificate] under the invite's name, from
	## [param source] when it is given -- another loopback address, bound on
	## [param local_port], so a storm can come from several addresses.
	func call_internet(certificate: X509Certificate, source: String = "",
			local_port: int = 0) -> bool:
		if not source.is_empty():
			peer.set_bind_ip(source)
		if peer.create_client("127.0.0.1", Invite.channel_port(), 0, 0, 0, local_port) != OK:
			return false
		if peer.host.dtls_client_setup(Invite.NAME,
				TLSOptions.client(certificate, Invite.NAME)) != OK:
			return false
		id = peer.get_unique_id()
		return true

	## The nonce of the CHALLENGE it was sent, or empty for none yet.
	func challenge() -> PackedByteArray:
		for packet: PackedByteArray in got:
			if packet.size() == 1 + Wire.CHALLENGE_SIZE and packet[0] == NetSession.RAW \
					and packet[1] == Wire.KIND_CHALLENGE:
				return packet.slice(2)
		return PackedByteArray()

	func _process(_delta: float) -> void:
		var now := float(Time.get_ticks_msec()) / 1000.0
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			if down_at < 0.0:
				down_at = now
			return
		peer.poll()
		while peer.get_available_packet_count() > 0:
			got.append(peer.get_packet())
			if refused_at < 0.0 and refused_for() >= 0:
				refused_at = now

	func connected() -> bool:
		return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

	func down() -> bool:
		return down_at >= 0.0

	## [param bytes] exactly as given, whatever the first of them is.
	func send_raw(bytes: PackedByteArray, reliable: bool = true) -> void:
		if not connected():
			return
		peer.set_target_peer(1)
		peer.transfer_channel = 0
		peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable \
			else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		peer.put_packet(bytes)

	## A frame, as a guest's `send_bytes` writes one: the RAW byte in front.
	func send(frame: PackedByteArray, reliable: bool = true) -> void:
		var raw := PackedByteArray([NetSession.RAW])
		raw.append_array(frame)
		send_raw(raw, reliable)

	## The refusal it was sent, its frame without the RAW byte, or empty.
	func refusal() -> PackedByteArray:
		for packet: PackedByteArray in got:
			if packet.size() >= 1 + Wire.REFUSE_SIZE and packet[0] == NetSession.RAW \
					and packet[1] == Wire.KIND_REFUSE:
				return packet.slice(1)
		return PackedByteArray()

	## The reason in the refusal it was sent, or -1.
	func refused_for() -> int:
		for packet: PackedByteArray in got:
			if packet.size() >= 1 + Wire.REFUSE_SIZE and packet[0] == NetSession.RAW \
					and packet[1] == Wire.KIND_REFUSE:
				return packet[4]
		return -1

	func welcomed() -> bool:
		for packet: PackedByteArray in got:
			if packet.size() >= 1 + Wire.WELCOME_SIZE and packet[0] == NetSession.RAW \
					and packet[1] == Wire.KIND_WELCOME:
				return true
		return false

	func hang_up() -> void:
		peer.close()
		queue_free()


func _check_limits() -> void:
	var began := _now()
	var began_frames := Engine.get_process_frames()
	var ceiling := Engine.max_fps
	Engine.max_fps = LIMITS_FPS
	await _limits_edges()
	await _limits_oversize()
	await _limits_malformed()
	await _limits_direction()
	await _limits_commands()
	await _limits_before_hello()
	await _limits_greeted_gone()
	await _limits_flood()
	await _limits_storm()
	await _limits_queues()
	await _limits_unknown()
	_limits_lan()
	await _limits_leftovers()
	print("[net-probe] NOTE limits took %.1f s and %d frames, at most %d a second"
		% [_now() - began, Engine.get_process_frames() - began_frames, Engine.max_fps])
	Engine.max_fps = ceiling


## **T1: every frame at its edges.** Each bound in wire.gd's size table is a
## frame a writer really produces -- the largest PERSON is nine genes and
## seven slots of sixteen-letter names, and since protocol 6 the largest SISTER,
## a guest's longest frame, is two genomes of them and eight lines of 128 bytes
## -- and one byte either side of it, or the wrong side of the wire, is refused.
## Then the largest of each crosses a real socket both ways and every one is
## taken.
func _limits_edges() -> void:
	var genes := {}
	for i in Wire.GENES_MAX:
		genes[StringName(String.chr(97 + i).repeat(Wire.NAME_MAX))] = Wire.TIER_TOP
	var order: Array = []
	for i in Wire.ORDER_MAX:
		order.append(StringName(String.chr(97 + i).repeat(Wire.NAME_MAX)))
	var longest_list := PackedStringArray()
	for i in Wire.MOST_RULES:
		longest_list.append(_rule_line_of(Wire.RULE_BYTES_MAX, i))
	var long_gene := StringName("z".repeat(Wire.NAME_MAX))
	var bodies: Array = []
	for i in Wire.SEND_MAX:
		bodies.append([60000 + i, i % 7, 0, Vector2(91.25 * i, -13.5 * i), 0.09 * i,
			4.0 + 0.61 * i, 0.1, 2.0 * float(i % 90), Vector2.ZERO, 0.0])
	bodies.append([Wire.PERSON_ID, 255,
		Wire.POND_IS_PERSON | Wire.POND_IN_WATER, Vector2(512.25, -96.5), 1.5, 28.28,
		0.4, 44.0, Vector2(-37.5, 12.25), -0.75])
	var at := Vector2(700.0, -3.0)
	var person_max := Wire.person_payload(true, genes, order)
	var sister_max := Wire.sister_payload(at, -1.25, 28.28, genes, genes, longest_list)
	var genome_max := Wire.genome_payload(0xFFFFFFFF, 255, genes)
	var contact_max := Wire.contact_payload(FoodField.Contact.ATE, at, 0.9,
		FoodField.By.FRIEND, long_gene)
	# `[name, frame, least, most, the host sends it, a guest sends it]` -- the
	# writer's smallest and largest of every kind and event type there is.
	var cases := [
		["HELLO", Wire.hello(Wire.PROTOCOL), Wire.HELLO_SIZE, Wire.HANDSHAKE_MAX,
			false, true],
		["WELCOME", Wire.welcome(Wire.PROTOCOL, 0xC0DE1234), Wire.WELCOME_SIZE,
			Wire.HANDSHAKE_MAX, true, false],
		["REFUSE", Wire.refuse(Wire.PROTOCOL, Wire.REFUSE_BROKEN), Wire.REFUSE_SIZE,
			Wire.HANDSHAKE_MAX, true, false],
		["STATE", Wire.state(1, true, at, 0.5, 26.0, Vector2(30.0, -40.0), 0.2),
			Wire.STATE_SIZE, Wire.STATE_SIZE, true, true],
		["SHOUT", Wire.shout(1, at, 26.0, 1100.0), Wire.SHOUT_SIZE, Wire.SHOUT_SIZE,
			true, true],
		["ENTER", Wire.event(1, Wire.EVENT_ENTER, Wire.enter_payload(26.0)),
			Wire.ENTER_SIZE, Wire.ENTER_SIZE, false, true],
		["ARRIVE", Wire.event(1, Wire.EVENT_ARRIVE, Wire.arrive_payload(at, 1.0,
			Vector2.ZERO, 6000.0)), Wire.ARRIVE_SIZE, Wire.ARRIVE_SIZE, true, false],
		["PERSON, smallest", Wire.event(1, Wire.EVENT_PERSON,
			Wire.person_payload(false, {}, [])), Wire.PERSON_MIN, Wire.PERSON_MAX, true, true],
		["PERSON, largest", Wire.event(1, Wire.EVENT_PERSON, person_max),
			Wire.PERSON_MIN, Wire.PERSON_MAX, true, true],
		["GENOME, smallest", Wire.event(1, Wire.EVENT_GENOME,
			Wire.genome_payload(1, 0, {})), Wire.GENOME_MIN, Wire.GENOME_MAX, true, false],
		["GENOME, largest", Wire.event(1, Wire.EVENT_GENOME, genome_max),
			Wire.GENOME_MIN, Wire.GENOME_MAX, true, false],
		["CONTACT, smallest", Wire.event(1, Wire.EVENT_CONTACT, Wire.contact_payload(
			FoodField.Contact.BITTEN, at, 0.3, FoodField.By.WATER)),
			Wire.CONTACT_SIZE, Wire.CONTACT_MAX, true, false],
		["CONTACT, largest", Wire.event(1, Wire.EVENT_CONTACT, contact_max),
			Wire.CONTACT_SIZE, Wire.CONTACT_MAX, true, false],
		["DIED", Wire.event(1, Wire.EVENT_DIED, Wire.died_payload(
			FoodField.Cause.STARVED, FoodField.By.WATER, at)), Wire.DIED_SIZE, Wire.DIED_SIZE,
			true, true],
		["SISTER, smallest", Wire.event(1, Wire.EVENT_SISTER,
			Wire.sister_payload(at, 0.0, 28.28, {})), Wire.SISTER_MIN, Wire.SISTER_MAX,
			false, true],
		["SISTER, largest", Wire.event(1, Wire.EVENT_SISTER, sister_max),
			Wire.SISTER_MIN, Wire.SISTER_MAX, false, true],
		["SETTLE", Wire.event(1, Wire.EVENT_SETTLE, Wire.settle_payload(9, at, 12.0, 1.0,
			120.0)), Wire.SETTLE_SIZE, Wire.SETTLE_SIZE, true, false],
		["CLEAR", Wire.event(1, Wire.EVENT_CLEAR, Wire.clear_payload(9)),
			Wire.CLEAR_SIZE, Wire.CLEAR_SIZE, true, false],
		["POND, smallest", Wire.pond(1, 0.0, []), Wire.POND_HEADER, Wire.POND_MAX,
			true, false],
		["POND, largest", Wire.pond(1, 0.5, bodies), Wire.POND_HEADER, Wire.POND_MAX,
			true, false],
	]
	var wrong: Array[String] = []
	var at_bound: Array[String] = []
	for case: Array in cases:
		var frame: PackedByteArray = case[1]
		var kind: int = frame[0]
		var type: int = frame[5] if kind == Wire.KIND_EVENT else 0
		var least: int = case[2]
		var most: int = case[3]
		var by_host: bool = case[4]
		var by_guest: bool = case[5]
		if not Wire.known(kind, type) \
				or Wire.size_ok(kind, type, frame.size(), true) != by_host \
				or Wire.size_ok(kind, type, frame.size(), false) != by_guest:
			wrong.append(str(case[0]))
		for side: bool in [true, false]:
			if Wire.size_ok(kind, type, least - 1, side) \
					or Wire.size_ok(kind, type, most + 1, side):
				wrong.append("%s one byte out" % case[0])
		if frame.size() == least or frame.size() == most:
			at_bound.append("%s %d" % [case[0], frame.size()])
	# Every bound but the handshake tail is the size of a frame a writer makes.
	var writers := Wire.PERSON_MAX == person_max.size() + Wire.EVENT_HEADER \
		and Wire.SISTER_MAX == sister_max.size() + Wire.EVENT_HEADER \
		and Wire.GENOME_MAX == genome_max.size() + Wire.EVENT_HEADER \
		and Wire.CONTACT_MAX == contact_max.size() + Wire.EVENT_HEADER \
		and Wire.POND_MAX == (cases[cases.size() - 1][1] as PackedByteArray).size() \
		and Wire.GUEST_FRAME_MAX == Wire.SISTER_MAX and Wire.SISTER_MAX > Wire.PERSON_MAX \
		and Wire.GUEST_OTHER_MAX == Wire.PERSON_MAX and Wire.HOST_FRAME_MAX == Wire.POND_MAX \
		and at_bound.size() == cases.size()
	var later := not Wire.known(0x7E, 0) and not Wire.known(Wire.KIND_EVENT, 0x7F) \
		and not Wire.size_ok(0x7E, 0, 8, false) \
		and Wire.size_ok(Wire.KIND_HELLO, 0, Wire.HANDSHAKE_MAX, false) \
		and not Wire.size_ok(Wire.KIND_HELLO, 0, Wire.HANDSHAKE_MAX + 1, false)
	_says(wrong.is_empty() and writers and later,
		"limits T1: every kind at its smallest and largest is taken from the side"
		+ " that sends it and from no other, one byte either side of the bound is"
		+ " not, and every bound is a frame a writer makes (%s)%s" % [", ".join(at_bound),
			"" if wrong.is_empty() else " -- NOT: " + ", ".join(wrong)])

	# The largest of each, through a real socket both ways.
	var host: Node = await _limits_host("LimitsEdgesHost")
	var guest: Node = await _limits_guest("LimitsEdgesGuest")
	var gid: int = guest.my_id()
	guest.send_event(Wire.EVENT_PERSON, person_max)
	guest.send_event(Wire.EVENT_SISTER, sister_max)
	guest.send_event(Wire.EVENT_ENTER, Wire.enter_payload(26.0))
	guest.send_event(Wire.EVENT_DIED, Wire.died_payload(FoodField.Cause.STARVED,
		FoodField.By.WATER, at))
	guest.shout(at, 26.0, 1100.0)
	guest.report_body(at, 0.5, 26.0, Vector2(30.0, -40.0), 0.2)
	host.send_event(Wire.EVENT_GENOME, genome_max)
	host.send_event(Wire.EVENT_CONTACT, contact_max)
	host.send_event(Wire.EVENT_PERSON, person_max)
	host.send_pond(0.5, bodies)
	await _limits_until(func() -> bool:
		return (host.pond_events as Array).size() >= 4 and (host.heard as Array).size() >= 1 \
			and not (host.peer_track() as Array).is_empty() \
			and (guest.pond_events as Array).size() >= 3 \
			and (guest.peer_pond() as PackedByteArray).size() == Wire.POND_MAX)
	var into_host: Array = (host.pond_events as Array).map(func(f: PackedByteArray) -> int:
		return f.size())
	var into_guest: Array = (guest.pond_events as Array).map(func(f: PackedByteArray) -> int:
		return f.size())
	_says(into_host == [Wire.PERSON_MAX, Wire.SISTER_MAX, Wire.ENTER_SIZE, Wire.DIED_SIZE]
			and (host.heard as Array).size() == 1
			and into_guest == [Wire.GENOME_MAX, Wire.CONTACT_MAX, Wire.PERSON_MAX]
			and (guest.peer_pond() as PackedByteArray).size() == Wire.POND_MAX
			and _limits_clean(host.gate_counts) and _limits_clean(guest.gate_counts)
			and float(host.points_of(gid)) == 0.0,
		"limits T1: and the largest of each crosses a real socket and is taken --"
		+ " %s into the host, %s and a %d-byte POND into the guest, nothing"
		% [str(into_host), str(into_guest), (guest.peer_pond() as PackedByteArray).size()]
		+ " dropped and no strike on either side%s" % _limits_unclean(
			[host.gate_counts, guest.gate_counts]))
	await _limits_close([host, guest])


## **T2: over the cap.** An event one byte past the longest frame a guest
## writes of any kind but a SISTER -- 273 bytes, as before protocol 6 -- and
## then a 64 KiB reliable frame that ENet reassembles from fifty
## fragments: each is a cut on the spot, with nothing queued, and the address
## is barred -- a minute, then ten for a second offence -- so a call back is
## cut at the door. Then the one kind allowed past 272 since protocol 6, a
## SISTER, on a host of its own ([method _limits_sister_room]).
func _limits_oversize() -> void:
	var host: Node = await _limits_host("LimitsOversizeHost")
	var first: Node = await _limits_guest("LimitsOversizeGuest1")
	var over := Wire.event(1, Wire.EVENT_PERSON, PackedByteArray())
	over.resize(Wire.GUEST_OTHER_MAX + 1)
	first._to(int(first.get("_host_id")), over)
	await _limits_until(func() -> bool:
		return int(host.peer_count()) == 0 and int(first.link) != NetSession.Link.TOGETHER)
	var counts: Dictionary = host.gate_counts
	var book: Dictionary = host.get("_book")
	var barred: float = float(book.get("127.0.0.1", {}).get("barred_until", 0.0)) - _now()
	_says(int(counts["oversize"]) == 1 and int(counts["cuts"]) == 1
			and int(counts["strikes"]) == 0 and int(host.peer_count()) == 0
			and (host.pond_events as Array).is_empty()
			and int(first.link) != NetSession.Link.TOGETHER
			and barred > NetSession.BAR_FIRST * 0.5 and barred <= NetSession.BAR_FIRST,
		"limits T2: a %d-byte event is cut on the spot -- no strike, nothing queued,"
		% over.size() + " the host alone again -- and the address barred for %.0f s"
		% barred)
	var again: Node = await _session("LimitsOversizeGuest2")
	again.join("127.0.0.1")
	await _limits_until(func() -> bool:
		return int(host.gate_counts["refused_barred"]) >= 1 \
			and int(again.link) != NetSession.Link.REACHING)
	_says(int(host.gate_counts["refused_barred"]) == 1 and int(host.peer_count()) == 0
			and int(again.link) != NetSession.Link.TOGETHER,
		"limits T2: and a call back from it is cut at the door (link %d)" % int(again.link))
	# Its minute served, by hand: the same address, one more time.
	book["127.0.0.1"]["barred_until"] = 0.0
	var third: Node = await _limits_guest("LimitsOversizeGuest3")
	var joined := int(third.link) == NetSession.Link.TOGETHER
	var huge := PackedByteArray()
	huge.resize(65536)
	huge[0] = Wire.KIND_EVENT
	third._to(int(third.get("_host_id")), huge)
	await _limits_until(func() -> bool:
		return int(host.gate_counts["oversize"]) >= 2 and int(host.peer_count()) == 0)
	barred = float(book["127.0.0.1"]["barred_until"]) - _now()
	_says(joined and int(host.gate_counts["oversize"]) == 2
			and int(host.gate_counts["bars"]) == 2 and int(host.peer_count()) == 0
			and (host.pond_events as Array).is_empty()
			and barred > NetSession.BAR_AGAIN - NetSession.BAR_FIRST,
		"limits T2: a 64 KiB reliable frame, reassembled from its fragments, is cut"
		+ " the same way, and a second offence inside ten minutes bars for %.0f s"
		% barred)
	await _limits_close([host, first, again, third])
	await _limits_sister_room()


## **T2, the SISTER's room** (protocol 6, automation.md §10.3): the one kind a
## greeted guest may send past [member Wire.GUEST_OTHER_MAX], to [member
## Wire.SISTER_MAX], because her list rides in it. One of a thousand-odd bytes
## is taken; one as long that does not read is an ordinary malformed frame, a
## strike and no cut; one byte past SISTER_MAX is the oversize cut. And a
## caller that has not said HELLO is held to 272 whatever it sends: its SISTER
## past it is the oversize cut, as at protocol 5.
func _limits_sister_room() -> void:
	var host: Node = await _limits_host("LimitsSisterRoomHost")
	var guest: Node = await _limits_guest("LimitsSisterRoomGuest")
	var gid: int = guest.my_id()
	var lines := PackedStringArray()
	for i in Wire.MOST_RULES:
		lines.append(_rule_line_of(Wire.RULE_BYTES_MAX, i))
	var payload := Wire.sister_payload(Vector2(560.0, 0.0), 0.0, Referee.DAUGHTER_RADIUS,
		{&"cytostome": 1}, {&"cytostome": 2}, lines)
	guest.send_event(Wire.EVENT_SISTER, payload)
	await _limits_until(func() -> bool: return (host.pond_events as Array).size() >= 1)
	var taken: Array = (host.pond_events as Array).map(func(f: PackedByteArray) -> int:
		return f.size())
	# The same length, its count of rules made nine: a SISTER that does not read.
	var spoiled := payload.duplicate()
	spoiled[payload.size() - 1 - Wire.MOST_RULES * (1 + Wire.RULE_BYTES_MAX)] = \
		Wire.MOST_RULES + 1
	guest.send_event(Wire.EVENT_SISTER, spoiled)
	await _limits_until(func() -> bool: return int(host.gate_counts["malformed"]) >= 1)
	var points: float = host.points_of(gid)
	var struck := int(host.gate_counts["malformed"]) == 1 \
		and int(host.gate_counts["oversize"]) == 0 and int(host.gate_counts["cuts"]) == 0 \
		and points > 2.0 and points <= NetSession.STRIKE_MALFORMED \
		and int(guest.link) == NetSession.Link.TOGETHER \
		and (host.pond_events as Array).size() == 1
	var over := Wire.event(9, Wire.EVENT_SISTER, PackedByteArray())
	over.resize(Wire.SISTER_MAX + 1)
	guest._to(int(guest.get("_host_id")), over)
	await _limits_until(func() -> bool: return int(host.peer_count()) == 0)
	var book: Dictionary = host.get("_book")
	var barred: float = float(book.get("127.0.0.1", {}).get("barred_until", 0.0)) - _now()
	_says(taken == [Wire.EVENT_HEADER + payload.size()]
			and Wire.EVENT_HEADER + payload.size() > Wire.GUEST_OTHER_MAX and struck
			and int(host.gate_counts["oversize"]) == 1 and int(host.gate_counts["cuts"]) == 1
			and int(host.peer_count()) == 0 and barred > NetSession.BAR_FIRST * 0.5,
		"limits T2: since protocol 6 a greeted guest's SISTER may pass %d bytes --"
		% Wire.GUEST_OTHER_MAX + " one of %d is taken; one as long that does not read"
		% (Wire.EVENT_HEADER + payload.size()) + " is a malformed strike, %.2f"
		% points + " points and no cut; one of %d, a byte past SISTER_MAX, is the"
		% over.size() + " oversize cut, and the address barred for %.0f s" % barred)
	# Before its hello, a caller is held to the old cap whatever its frame says.
	book["127.0.0.1"]["barred_until"] = 0.0
	var early := _limits_rogue("LimitsSisterRoomEarly")
	await _limits_until(func() -> bool: return early.connected())
	var early_sister := Wire.event(1, Wire.EVENT_SISTER, payload)
	early.send(early_sister)
	await _limits_until(func() -> bool:
		return int(host.gate_counts["oversize"]) >= 2 and early.down())
	_says(int(host.gate_counts["oversize"]) == 2 and int(host.gate_counts["malformed"]) == 1
			and int(host.peer_count()) == 0 and early.down()
			and float(book.get("127.0.0.1", {}).get("barred_until", 0.0)) > _now(),
		"limits T2: and a caller's SISTER of %d bytes before its hello is the oversize"
		% early_sister.size() + " cut, barred, as any frame past %d was at protocol 5"
		% Wire.GUEST_OTHER_MAX)
	await _limits_close([host, guest, early])


## **T3: malformed, twice and then again.** A PERSON with ten genes is the
## right size and does not read -- nine is the most since protocol 7. Two are 8 points and the guest stays; two
## more inside a second cut it, told why: REFUSE_BROKEN.
func _limits_malformed() -> void:
	var host: Node = await _limits_host("LimitsMalformedHost")
	var guest: Node = await _limits_guest("LimitsMalformedGuest")
	var gid: int = guest.my_id()
	var nine := PackedByteArray([0, Wire.GENES_MAX + 1])
	for i in Wire.GENES_MAX + 1:
		nine.append(5)
		nine.append_array(("gene" + String.chr(97 + i)).to_ascii_buffer())
		nine.append(1)
	nine.append(0)
	guest.send_event(Wire.EVENT_PERSON, nine)
	guest.send_event(Wire.EVENT_PERSON, nine)
	await _limits_until(func() -> bool: return int(host.gate_counts["malformed"]) >= 2)
	var points: float = host.points_of(gid)
	var stayed := int(host.link) == NetSession.Link.TOGETHER \
		and int(guest.link) == NetSession.Link.TOGETHER \
		and (host.pond_events as Array).is_empty()
	_says(int(host.gate_counts["malformed"]) == 2 and points > 6.0 and points <= 8.0
			and stayed,
		"limits T3: two ten-gene PERSONs, %d bytes each, are %.2f points; the"
		% [Wire.EVENT_HEADER + nine.size(), points] + " guest stays, and nothing"
		+ " was queued")
	guest.send_event(Wire.EVENT_PERSON, nine)
	guest.send_event(Wire.EVENT_PERSON, nine)
	await _until_link(guest, NetSession.Link.REFUSED)
	_says(int(guest.link) == NetSession.Link.REFUSED
			and str(guest.trouble) == Wire.reason_says(Wire.REFUSE_BROKEN)
			and str(guest.because).contains("update")
			and int(host.peer_count()) == 0 and int(host.gate_counts["cuts"]) == 1
			and int(host.link) == NetSession.Link.LISTENING,
		"limits T3: and two more inside a second cut it with REFUSE_BROKEN -- the"
		+ " guest reads '%s: %s', and the host is listening again"
		% [guest.trouble, guest.because])
	await _limits_close([host, guest])


## **T4: the wrong side of the wire.** A POND and a GENOME are the host's to
## send; from a guest each is 4 points, and neither lands anywhere.
func _limits_direction() -> void:
	var host: Node = await _limits_host("LimitsDirectionHost")
	var guest: Node = await _limits_guest("LimitsDirectionGuest")
	var gid: int = guest.my_id()
	guest._to(int(guest.get("_host_id")), Wire.pond(1, 0.0, []))
	guest.send_event(Wire.EVENT_GENOME, Wire.genome_payload(3, 0, {}))
	await _limits_until(func() -> bool: return int(host.gate_counts["malformed"]) >= 2)
	var peer: Dictionary = (host.get("_peers") as Dictionary).get(gid, {})
	var points: float = host.points_of(gid)
	_says(int(host.gate_counts["malformed"]) == 2 and points > 6.0 and points <= 8.0
			and not peer.is_empty() and (peer["pond"] as PackedByteArray).is_empty()
			and (host.pond_events as Array).is_empty()
			and int(host.link) == NetSession.Link.TOGETHER,
		"limits T4: a POND and a GENOME from a guest are %.2f points, the host keeps"
		% points + " no snapshot of it, and nothing is queued")
	await _limits_close([host, guest])


## **T5: a command, not a frame.** Bytes that SceneMultiplayer would have run
## as a path to cache -- first byte 1, SIMPLIFY_PATH -- are one malformed
## strike on a host that reads its own socket, and nothing comes back: no
## CONFIRM_PATH, nothing but the host's own frames.
func _limits_commands() -> void:
	var host: Node = await _limits_host("LimitsCommandsHost")
	var rogue := _limits_rogue("LimitsCommandsRogue")
	await _limits_until(func() -> bool: return rogue.connected())
	rogue.send(_hello())
	await _limits_until(func() -> bool: return rogue.welcomed())
	var path := PackedByteArray([1, 7, 0, 0, 0])
	path.append_array("root/NetSession".to_utf8_buffer())
	path.append(0)
	rogue.send_raw(path)
	await _limits_until(func() -> bool: return int(host.gate_counts["malformed"]) >= 1)
	var ids: Array = host.peer_ids()
	var points: float = host.points_of(int(ids[0])) if ids.size() == 1 else -1.0
	# Long enough for a CONFIRM_PATH to have come back, if anything sent one.
	await _wait(0.3)
	var firsts := {}
	for packet: PackedByteArray in rogue.got:
		firsts[int(packet[0]) if not packet.is_empty() else -1] = true
	_says(rogue.welcomed() and int(host.gate_counts["malformed"]) == 1
			and points > 2.0 and points <= 4.0 and firsts.keys() == [NetSession.RAW]
			and int(host.link) == NetSession.Link.TOGETHER,
		"limits T5: a SIMPLIFY_PATH command is %.2f points and nothing else --"
		% points + " every packet back starts with RAW %s, none is a CONFIRM_PATH"
		% str(firsts.keys()))
	await _limits_close([host, rogue])


## **T6: before the handshake.** A caller whose first frame is not a HELLO is
## cut in the frame it spoke, and nothing it sent after is read. A silent one
## is told REFUSE_SILENT at HELLO_GRACE and cut when the linger is over. And a
## caller cut inside `peer_connected` with forty packets queued behind its
## handshake -- the one reading of ENet that would close the whole host if it
## were wrong (A.5), measured on 4.7-stable -- leaves the host up with none of
## the forty delivered, where the same caller at an open door has all forty
## delivered; and a real guest joins straight after.
func _limits_before_hello() -> void:
	var host: Node = await _limits_host("LimitsHelloHost")
	var early := _limits_rogue("LimitsHelloEarly")
	await _limits_until(func() -> bool: return early.connected())
	for i in 6:
		early.send(Wire.state(i, true, Vector2.ZERO, 0.0, 26.0))
	await _limits_until(func() -> bool:
		return int(host.gate_counts["cuts"]) >= 1 and early.down())
	var counts: Dictionary = host.gate_counts
	_says(int(counts["cuts"]) == 1 and int(counts["strikes"]) == 0
			and int(counts["malformed"]) == 0 and int(counts["bars"]) == 0
			and int(counts["strays"]) <= 5 and int(host.peer_count()) == 0 and early.down(),
		"limits T6: a caller whose first frame is a STATE is cut there, with no"
		+ " strike and no bar; ENet delivered %d of the five behind it, and none"
		% int(counts["strays"]) + " was read")
	# The control: at an open door, the packets that rode in with the handshake
	# are delivered with it -- the first gets the caller cut, and the rest are
	# counted as strays. ENet puts at most 32 commands in a datagram, so that is
	# the acknowledgement and 31 of the forty; the other nine come a poll later,
	# to a peer ENet has already reset.
	var strays_before := int(host.gate_counts["strays"])
	var control: Array = await _limits_squat(1000001)
	var delivered := int(host.gate_counts["strays"]) - strays_before
	_says(bool(control[0]) and bool(control[1]) and delivered >= 20
			and int(host.gate_counts["cuts"]) == 2,
		"limits T6: a caller that sends forty packets in the datagram that finishes"
		+ " its handshake has them delivered with it at an open door -- cut at the"
		+ " first, %d more delivered in the same poll, counted and never read"
		% delivered)
	# Two callers that say nothing fill the waiting room...
	var quiet: Array[Rogue] = [_limits_rogue("LimitsHelloQuiet1"),
		_limits_rogue("LimitsHelloQuiet2")]
	await _limits_until(func() -> bool:
		return quiet[0].connected() and quiet[1].connected() \
			and int(host.peer_count()) == NetSession.PENDING_MAX)
	# ...so the same caller again is cut inside `peer_connected`.
	strays_before = int(host.gate_counts["strays"])
	var squat: Array = await _limits_squat(1000002)
	var up := int(host.link) == NetSession.Link.LISTENING \
		and (host.get("_peer") as ENetMultiplayerPeer).get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED
	_says(bool(squat[0]) and bool(squat[1]) and up
			and int(host.gate_counts["refused_pending"]) == 1
			and int(host.gate_counts["strays"]) == strays_before
			and int(host.peer_count()) == NetSession.PENDING_MAX,
		"limits T6: and cut inside peer_connected with the forty queued, it leaves"
		+ " the host up -- none of them delivered, the two waiting still waiting")
	# The two quiet ones: told at HELLO_GRACE, and cut when the linger is over.
	await _limits_until(func() -> bool: return quiet[0].down() and quiet[1].down(),
		NetSession.HELLO_GRACE + NetSession.REFUSE_LINGER + 2.0)
	var told := true
	var lingered := 0.0
	for rogue: Rogue in quiet:
		if rogue.refused_for() != Wire.REFUSE_SILENT or not rogue.down():
			told = false
			continue
		lingered = maxf(lingered, rogue.down_at - rogue.refused_at)
	_says(told and lingered >= NetSession.REFUSE_LINGER * 0.5
			and lingered < NetSession.REFUSE_LINGER + 2.0,
		"limits T6: the two that said nothing are told REFUSE_SILENT at %.0f s and"
		% NetSession.HELLO_GRACE + " cut %.2f s later, at the end of the linger"
		% lingered)
	var guest: Node = await _limits_guest("LimitsHelloGuest")
	_says(int(guest.link) == NetSession.Link.TOGETHER
			and int(host.link) == NetSession.Link.TOGETHER,
		"limits T6: and the host is still up -- a real guest joins straight after")
	await _limits_close([host, early, quiet[0], quiet[1], guest])


## **A greeted guest that goes silent for good is let go** (#92). A host holds a
## transport open for each guest, so one that proved itself and then stops
## sending would keep a slot -- and, on the dedicated server, the empty pond its
## updater waits for -- open forever. [member NetSession.silence_cut] is dropped
## from the build's half-minute to a second and a half here.
func _limits_greeted_gone() -> void:
	var host: Node = await _limits_host("GoneHost")
	host.set("silence_cut", 1.5)
	var rogue := _limits_rogue("GoneRogue")
	await _limits_until(func() -> bool: return rogue.connected())
	rogue.send(_hello())
	await _limits_until(func() -> bool:
		return int(host.link) == NetSession.Link.TOGETHER and int(host.company()) == 1)
	var greeted := int(host.company()) == 1 and int(host.peer_count()) == 1
	# It says nothing more. A second and a half is still three heartbeats: a
	# guest that was still there would have spoken.
	var waited := await _limits_until(func() -> bool: return rogue.down(), 4.0)
	var lan_book: Dictionary = host.get("_book")
	var barred: bool = float((lan_book.get("127.0.0.1", {}) as Dictionary)
		.get("barred_until", 0.0)) > _now()
	_says(greeted and waited >= 1.0 and rogue.refused_for() == Wire.REFUSE_SILENT
			and int(host.company()) == 0 and int(host.peer_count()) == 0
			and int(host.gate_counts["gone"]) == 1 and not barred,
		"limits: a greeted guest silent past silence_cut (%.1f s here) is cut, told"
		% 1.5 + " REFUSE_SILENT and not barred, and company falls back to 0 -- so a staged"
		+ " update is no longer pinned open (#92)")
	# The control: a real guest keeps sending its heartbeat, so it is never cut
	# by this -- and its getting in also proves the silent one left no bar.
	var live: Node = await _limits_guest("GoneLiveGuest")
	await _limits_until(func() -> bool: return false, 2.0)
	_says(int(live.link) == NetSession.Link.TOGETHER and int(host.company()) == 1
			and int(host.gate_counts["gone"]) == 1,
		"limits: a guest still sending its heartbeat outlives silence_cut untouched, and"
		+ " the silent one that was cut left no bar behind it")
	await _limits_close([host, rogue, live])


## **A caller that sends forty packets in the datagram that finishes its
## handshake**: a bare `ENetConnection`, offering [param id], that sends them
## the moment its own side connects and flushes once -- ENet writes the
## handshake's last acknowledgement and all forty into one datagram, so they
## are queued on the host before `peer_connected` fires. Each is a three-byte
## STATE, which no caller may send first. `[it connected, it was cut]`.
func _limits_squat(id: int) -> Array:
	var squatter := ENetConnection.new()
	var peer: ENetPacketPeer = null
	if squatter.create_host(1) == OK:
		peer = squatter.connect_to_host("127.0.0.1", Lan.channel_port(), 0, id)
	var seen := [false, false]
	await _limits_until(func() -> bool:
		if peer == null:
			return true
		var event: Array = squatter.service()
		while int(event[0]) > ENetConnection.EVENT_NONE:
			if int(event[0]) == ENetConnection.EVENT_CONNECT and not bool(seen[0]):
				seen[0] = true
				for k in 40:
					peer.send(0, PackedByteArray([NetSession.RAW, Wire.KIND_STATE, k, 0]),
						ENetPacketPeer.FLAG_RELIABLE if k % 2 == 0
							else ENetPacketPeer.FLAG_UNSEQUENCED)
				squatter.flush()
			elif int(event[0]) == ENetConnection.EVENT_DISCONNECT:
				seen[1] = true
			event = squatter.service()
		return bool(seen[1]))
	await _wait(0.2)
	squatter.destroy()
	return seen


## **T7: a flood, and the control -- the budgets enforced, and watched.** Three
## thousand valid state frames in a second from a greeted guest. With
## [member NetSession.enforce_budgets] on, no more are taken than the frame
## budget's burst and refill, and flood strikes cut it inside two seconds.
## Watched -- the budgets switched off, as they can be to diagnose a false
## positive -- the same flood is counted and logged as the drops and the cut it
## would have been, and the guest loses neither a frame nor its link. Then a guest sending a hundred a second for three seconds --
## over any honest peak -- is never struck, and the budgets never even note it.
func _limits_flood() -> void:
	var host: Node = await _limits_host("LimitsFloodHost")
	host.enforce_budgets = true
	var guest: Node = await _limits_guest("LimitsFloodGuest")
	var gid: int = guest.my_id()
	var guard: RefCounted = (host.get("_peers") as Dictionary)[gid]["guard"]
	var to: int = guest.get("_host_id")
	var from := _now()
	var sent := 0
	var worst := 0.0
	var last := from
	var cut_at := -1.0
	while _now() - from < 1.0 or (cut_at < 0.0 and _now() - from < 2.5):
		var due := mini(3000, int(3000.0 * (_now() - from)))
		while sent < due:
			sent += 1
			guest._to(to, Wire.state(1000000 + sent, true, Vector2(float(sent), 0.0), 0.0,
				26.0))
		await get_tree().process_frame
		var now := _now()
		worst = maxf(worst, now - last)
		last = now
		if cut_at < 0.0 and int(guest.link) == NetSession.Link.REFUSED:
			cut_at = now - from
	var taken := int(guard.get("taken"))
	var allowed := NetSession.FRAMES_BURST + NetSession.FRAMES_RATE * maxf(cut_at, 0.0) + 4.0
	_says(cut_at >= 0.0 and cut_at < 2.0 and taken <= int(allowed)
			and int(host.gate_counts["cuts"]) == 1 and int(host.gate_counts["strikes"]) >= 2
			and int(host.gate_counts["would_drop"]) == 0
			and str(guest.trouble) == Wire.reason_says(Wire.REFUSE_BROKEN),
		"limits T7: enforced, a flood of %d state frames is cut after %.2f s with"
		% [sent, cut_at] + " REFUSE_BROKEN, %d frames taken of the %d the budget allows"
		% [taken, int(allowed)] + " by then, %d dropped; the host's worst frame %.1f ms"
		% [int(host.gate_counts["dropped"]), worst * 1000.0])
	await _limits_close([host, guest])
	# Watched -- the switch for diagnosing a false positive in the field: the
	# same flood, and nothing is taken away.
	host = await _limits_host("LimitsWatchHost")
	host.enforce_budgets = false
	guest = await _limits_guest("LimitsWatchGuest")
	gid = guest.my_id()
	guard = (host.get("_peers") as Dictionary)[gid]["guard"]
	to = guest.get("_host_id")
	from = _now()
	sent = 0
	while _now() - from < 1.0:
		var due := mini(3000, int(3000.0 * (_now() - from)))
		while sent < due:
			sent += 1
			guest._to(to, Wire.state(1000000 + sent, true, Vector2(float(sent), 0.0), 0.0,
				26.0))
		await get_tree().process_frame
	var took := await _limits_until(func() -> bool: return int(guard.get("taken")) >= sent)
	var counts: Dictionary = host.gate_counts
	var notes: Dictionary = host.get("_notes")
	_says(not bool(host.enforce_budgets) and took >= 0.0
			and int(guest.link) == NetSession.Link.TOGETHER and int(host.peer_count()) == 1
			and int(counts["would_drop"]) > 0
			and int(counts["would_drop"]) == int(counts["would_drop_frames"])
			and int(counts["would_cuts"]) >= 1 and int(counts["would_strikes"]) >= 2
			and int(counts["dropped"]) == 0 and int(counts["strikes"]) == 0
			and int(counts["cuts"]) == 0 and float(host.points_of(gid)) == 0.0
			and notes.has("would drop|127.0.0.1") and notes.has("would cut|127.0.0.1"),
		"limits T7: watched, the budgets switched off, the same flood is taken"
		+ " whole -- %d"
		% int(guard.get("taken")) + " frames of the %d sent, with its own beat -- and"
		% sent + " logged and counted as %d frames it would have dropped and %d cuts"
		% [int(counts["would_drop"]), int(counts["would_cuts"])] + " it would have"
		+ " made; the guest is never struck or cut")
	await _limits_close([host, guest])
	# The control: a hundred a second is more than any honest guest sends.
	host = await _limits_host("LimitsControlHost")
	host.enforce_budgets = true
	guest = await _limits_guest("LimitsControlGuest")
	gid = guest.my_id()
	guard = (host.get("_peers") as Dictionary)[gid]["guard"]
	to = guest.get("_host_id")
	from = _now()
	sent = 0
	while _now() - from < 3.0:
		var due := mini(300, int(100.0 * (_now() - from)))
		while sent < due:
			sent += 1
			guest._to(to, Wire.state(1000000 + sent, true, Vector2(float(sent), 0.0), 0.0,
				26.0))
		await get_tree().process_frame
	await _wait(0.2)
	_says(_limits_clean(host.gate_counts) and float(host.points_of(gid)) == 0.0
			and int(guard.get("taken")) >= sent
			and int(guest.link) == NetSession.Link.TOGETHER,
		"limits T7: the control, %d frames at a hundred a second, is all taken" % sent
		+ " (%d, with its own beat) with no strike and nothing dropped%s"
		% [int(guard.get("taken")), _limits_unclean([host.gate_counts])])
	await _limits_close([host, guest])


## **T8: a storm of calls.** Twelve callers from one address inside half a
## second, none of which ever says hello: never more than two wait at once,
## the address's bucket stops the rest after its burst, and every one of them
## is cut on arrival -- and a real guest from the same address gets in as soon
## as the bucket has a call in it again. One address's storm is its own: the
## review's lockout, twelve calls at once from one address and then a first
## call from another, has the second answered. Then the other per-address
## limit: the fourth transport from one address is refused while three are
## open.
func _limits_storm() -> void:
	var host: Node = await _limits_host("LimitsStormHost")
	var callers: Array[Rogue] = []
	var most_waiting := [0]
	var watch := func() -> void:
		var waiting := 0
		for id: int in host.peer_ids():
			if not bool((host.get("_peers") as Dictionary)[id]["greeted"]):
				waiting += 1
		most_waiting[0] = maxi(int(most_waiting[0]), waiting)
	var from := _now()
	for i in 12:
		callers.append(_limits_rogue("LimitsStorm%d" % i))
		if i % 3 == 2:
			await get_tree().process_frame
			watch.call()
	var calling := _now() - from
	# Every caller cut at the door, waiting, or already told it said nothing: a
	# caller ENet had no slot for tries again by itself, so this is ENet's pace,
	# not the host's -- and ENet's retries come 0.5, 1.5, 3.5 and 7.5 s after a
	# call, so the wait allows twice the last of them.
	var admitted := func() -> int:
		var n := 0
		for rogue: Rogue in callers:
			if rogue.refused_for() == Wire.REFUSE_SILENT \
					or (host.get("_peers") as Dictionary).has(rogue.id):
				n += 1
		return n
	await _limits_until(func() -> bool:
		watch.call()
		for rogue: Rogue in callers:
			if not rogue.down() and not (host.get("_peers") as Dictionary).has(rogue.id) \
					and rogue.refused_for() < 0:
				return false
		return true, 16.0)
	var storm := _now() - from
	var counts: Dictionary = host.gate_counts
	var through := callers.size() - int(counts["refused_calls"]) - int(counts["refused_busy"])
	var bucket: RefCounted = (host.get("_book") as Dictionary)["127.0.0.1"]["calls"]
	var let_in: int = admitted.call()
	_says(int(most_waiting[0]) <= NetSession.PENDING_MAX and let_in >= NetSession.PENDING_MAX
			and int(counts["refused"]) + let_in == callers.size()
			and int(counts["refused_calls"]) + int(counts["refused_busy"]) >= 1
			and int(counts["refused_pending"]) >= 1
			and through <= int(NetSession.CALLS_BURST + storm * NetSession.CALLS_RATE),
		"limits T8: twelve silent calls in %.2f s -- at most %d waiting at once, %d"
		% [calling, int(most_waiting[0]), through] + " through the address's bucket"
		+ " of %d; %d let in to wait, %d cut on arrival for the waiting room and %d"
		% [int(NetSession.CALLS_BURST), let_in, int(counts["refused_pending"]),
			int(counts["refused_calls"]) + int(counts["refused_busy"])]
		+ " for calling too often (%.1f s of ENet's retries)" % storm)
	# A real guest, from the same address, once the bucket holds a call again and
	# the two waiting have been hung up on.
	var empty := float(bucket.call("level", _now())) < 1.0
	var waited := await _limits_until(func() -> bool:
		watch.call()
		return float(bucket.call("level", _now())) >= 1.0 \
			and int(host.peer_count()) < NetSession.PENDING_MAX, 6.0)
	var guest: Node = await _limits_guest("LimitsStormGuest")
	_says(empty and waited >= 0.0 and int(guest.link) == NetSession.Link.TOGETHER,
		"limits T8: the bucket was empty after the storm, and a real guest from the"
		+ " same address joins once it holds a call again, %.1f s on" % waited)
	await _limits_close([host, guest] + callers)
	# **One address's storm is its own** -- the review's lockout, exactly, at the
	# door itself and in one instant: twelve calls from one address, then a
	# first call from another. The first address's own bucket answers eight and
	# turns four away, and only the eight spend the bucket every address
	# shares, so the other address is answered; spending the shared one first,
	# the twelve had emptied it, and the stranger was refused as busy. Ten more
	# first calls from ten more addresses then find what is left of the shared
	# bucket, and the rest are busy: it still does its job. Allowed whatever the
	# buckets could refill if the runner stalls in the middle.
	var door: Node = await _session("LimitsDoor")
	door._reset_socket()
	door.hosting = true
	door.address = "192.168.1.10"
	var began := _now()
	var first: Array = []
	for i in 12:
		var said: Array = door._admit("192.168.1.66")
		first.append("ok" if said.is_empty() else str(said[0]))
	var second: Array = door._admit("192.168.1.77")
	var rest: Array = []
	for i in 10:
		var said: Array = door._admit("192.168.1.%d" % (100 + i))
		rest.append("ok" if said.is_empty() else str(said[0]))
	var spent := _now() - began
	var own_more := int(spent * NetSession.CALLS_RATE)
	var all_more := int(spent * NetSession.CALLS_ALL_RATE)
	var left := int(NetSession.CALLS_ALL_BURST) - int(NetSession.CALLS_BURST) - 1
	_says(first.count("ok") >= int(NetSession.CALLS_BURST)
			and first.count("ok") <= int(NetSession.CALLS_BURST) + own_more
			and first.count("ok") + first.count("calls") == 12 and second.is_empty()
			and rest.count("ok") >= left and rest.count("ok") <= left + all_more
			and rest.count("ok") + rest.count("busy") == 10,
		"limits T8: and one address's storm is its own -- twelve calls at once from"
		+ " one address are %d answered and %d refused for calling too often, a first"
		% [first.count("ok"), first.count("calls")] + " call from another is %s, and"
		% ("answered" if second.is_empty() else "refused as " + str(second[0]))
		+ " ten more from ten more addresses find %d left in the bucket every address"
		% rest.count("ok") + " shares; %d are busy" % rest.count("busy"))
	door.close()
	# Three transports from one address are all it may hold.
	host = await _limits_host("LimitsLiveHost", NetSession.GUESTS_MAX)
	var a: Node = await _limits_guest("LimitsLiveA")
	var b: Node = await _limits_guest("LimitsLiveB")
	var third := _limits_rogue("LimitsLiveThird")
	await _limits_until(func() -> bool: return int(host.peer_count()) == 3)
	var fourth := _limits_rogue("LimitsLiveFourth")
	await _limits_until(func() -> bool: return fourth.down())
	_says(int(host.gate_counts["refused_live"]) == 1 and fourth.down()
			and int(host.peer_count()) == 3 and int(a.link) == NetSession.Link.TOGETHER
			and int(b.link) == NetSession.Link.TOGETHER,
		"limits T8: with two guests and a caller open from one address, a fourth"
		+ " transport from it is refused (%d open)" % int(host.peer_count()))
	await _limits_close([host, a, b, third, fourth])


## **T9: the queues, by weight.** Driven straight into `_take_event`, so no
## frame is spent: a phone host's queue of one guest's events stops at 16 KB of
## the longest PERSONs or 64 of the shortest frames, the oldest dropped; a
## dedicated host's is capped per guest, so one guest flooding it never pushes
## out the other's; and a guest's own queue of its host's events holds 512.
func _limits_queues() -> void:
	var node: Node = await _session("LimitsQueues")
	var genes := {}
	for i in Wire.GENES_MAX:
		genes[StringName(String.chr(97 + i).repeat(Wire.NAME_MAX))] = 1
	var order: Array = []
	for i in Wire.ORDER_MAX:
		order.append(StringName(String.chr(97 + i).repeat(Wire.NAME_MAX)))
	var longest := Wire.person_payload(false, genes, order)
	var peer := func(id: int) -> Dictionary:
		return {"id": id, "in_event": -1, "greeted": true}
	node.hosting = true
	node.guests_max = 1
	var one: Dictionary = peer.call(7)
	for seq in 100:
		node._take_event(one, Wire.event(seq, Wire.EVENT_PERSON, longest))
	var kept: Array = node.pond_events
	var weight := 0
	for f: PackedByteArray in kept:
		weight += f.size()
	var newest := not kept.is_empty() and Wire.seq_of(kept[kept.size() - 1]) == 99
	node.drain_pond_events()
	for seq in range(100, 200):
		node._take_event(one, Wire.event(seq, Wire.EVENT_ENTER, Wire.enter_payload(26.0)))
	var small := (node.pond_events as Array).size()
	node.drain_pond_events()
	_says(kept.size() == NetSession.QUEUE_BYTES / Wire.PERSON_MAX and weight <= NetSession.QUEUE_BYTES
			and newest and small == NetSession.QUEUE_FRAMES,
		"limits T9: a phone host keeps %d of 100 longest PERSONs (%d bytes of %d)," % [
			kept.size(), weight, NetSession.QUEUE_BYTES] + " the newest last, and %d of"
		% small + " 100 ENTERs; the oldest go")
	node.guests_max = NetSession.GUESTS_MAX
	var flooder: Dictionary = peer.call(11)
	var quiet: Dictionary = peer.call(12)
	node._take_event(quiet, Wire.event(0, Wire.EVENT_DIED, Wire.died_payload(3, 0,
		Vector2.ZERO)))
	for seq in 100:
		node._take_event(flooder, Wire.event(seq, Wire.EVENT_PERSON, longest))
	node._take_event(quiet, Wire.event(1, Wire.EVENT_ENTER, Wire.enter_payload(26.0)))
	var by := {11: 0, 12: 0}
	for said: Array in node.inbox:
		by[int(said[0])] = int(by[int(said[0])]) + 1
	var quiet_first := (node.inbox as Array).size() > 0 and int(node.inbox[0][0]) == 12
	node.drain_inbox()
	_says(int(by[11]) == NetSession.QUEUE_BYTES / Wire.PERSON_MAX and int(by[12]) == 2
			and quiet_first,
		"limits T9: a dedicated host holds one flooding guest to %d of its" % int(by[11])
		+ " events and keeps both of the other guest's, the first still first")
	node.hosting = false
	node.guests_max = 1
	var host_peer: Dictionary = peer.call(1)
	var genome := Wire.genome_payload(1, 0, genes)
	for seq in 600:
		node._take_event(host_peer, Wire.event(seq, Wire.EVENT_GENOME, genome))
	var guest_kept := (node.pond_events as Array).size()
	node.drain_pond_events()
	_says(guest_kept == NetSession.POND_EVENTS_MAX,
		"limits T9: and a guest keeps %d of 600 GENOMEs from its host -- room for" % guest_kept
		+ " the seventy an ENTER is answered with, seven times over")
	node.close()
	await _wait(0.1)


## **T10: a frame from a later build**: ten of an unknown kind and one event of
## an unknown type are dropped with no strike -- the wire promises to ignore
## them -- and the event keeps its place in the order, so the shout after it is
## heard, not taken for a gap.
func _limits_unknown() -> void:
	var host: Node = await _limits_host("LimitsUnknownHost")
	var guest: Node = await _limits_guest("LimitsUnknownGuest")
	var gid: int = guest.my_id()
	for i in 10:
		guest._to(int(guest.get("_host_id")), PackedByteArray([0x7E, i, 2, 3, 4, 5, 6, 7]))
	guest.send_event(0x7F, PackedByteArray([1, 2, 3]))
	guest.shout(Vector2(1.0, 2.0), 26.0, 1100.0)
	await _limits_until(func() -> bool:
		return int(host.gate_counts["unknown"]) >= 11 and (host.heard as Array).size() >= 1)
	_says(int(host.gate_counts["unknown"]) == 11 and int(host.gate_counts["strikes"]) == 0
			and float(host.points_of(gid)) == 0.0 and (host.heard as Array).size() == 1
			and int(host.link) == NetSession.Link.TOGETHER,
		"limits T10: ten frames of kind 0x7E and an event of type 0x7F are dropped"
		+ " with no strike, and the shout behind them is heard")
	await _limits_close([host, guest])


## **T11: the LAN-only guard**, on a table of addresses. Documentation ranges
## stand in for public ones -- RFC 5737's for IPv4, RFC 3849's for IPv6 -- and
## this host is a placeholder 10.0.0.5, so 192.0.2.x is somebody else's
## network here. Every address is made up: the few outside those ranges --
## 172.32.0.1 and 100.128.0.1, one past a private range's edge, and 192.0.3.77,
## one /24 past a host's own -- are there for the edge, and are nobody's.
func _limits_lan() -> void:
	var own := "10.0.0.5"
	var yes := ["127.0.0.1", "10.20.30.40", "172.16.0.9", "172.31.255.1", "192.168.1.20",
		"100.64.0.7", "100.127.3.3", "169.254.1.1", "::1", "fd12:3456::1",
		"fe80::1", "fe80::1%wlan0", "fe80:0:0:0:1:2:3:4", "::ffff:192.168.1.5"]
	var no := ["192.0.2.9", "198.51.100.7", "203.0.113.9", "172.32.0.1", "100.128.0.1",
		"2001:db8::1", "2001:db8:0:0:0:0:0:1", "::ffff:203.0.113.9", "::", "0.0.0.0",
		"", "not an address", "256.1.1.1", "1.2.3", "1::2::3"]
	var wrong: Array[String] = []
	for address: String in yes:
		if not Lan.is_local_source(address, own):
			wrong.append("refused " + address)
	for address: String in no:
		if Lan.is_local_source(address, own):
			wrong.append("took " + address)
	var own_24 := Lan.is_local_source("192.0.2.77", "192.0.2.12") \
		and not Lan.is_local_source("192.0.3.77", "192.0.2.12")
	var keys := Lan.source_key("2001:db8:1:2:aaaa::1") == Lan.source_key("2001:db8:1:2:bbbb::2") \
		and Lan.source_key("2001:db8:1:2::1") != Lan.source_key("2001:db8:1:3::1") \
		and Lan.source_key("::ffff:192.168.1.5") == "192.168.1.5"
	_says(wrong.is_empty() and own_24 and keys,
		"limits T11: loopback, RFC 1918, 100.64/10, 169.254/16, the host's own /24,"
		+ " and IPv6 loopback, ULA and link-local are answered; %d public stand-ins"
		% no.size() + " and junk are not; an IPv6 caller is its /64%s"
		% ("" if wrong.is_empty() else " -- NOT: " + ", ".join(wrong)))


## **T12: nothing a guest said outlives it.** A phone host's run stops draining
## its guest's events the moment the link drops, so whatever was still queued
## -- an ENTER, a PERSON, a shout -- used to wait for the next guest, and reach
## its run as an arrival that guest never made. Now it goes with the guest,
## whether it left or was cut, and the next guest finds nothing. A dedicated
## host forgets what one guest said and keeps the other's.
func _limits_leftovers() -> void:
	var host: Node = await _limits_host("LimitsLeftoversHost")
	var person := Wire.person_payload(true, {&"cytostome": 1, &"flagellum": 1},
		[&"cytostome", &"flagellum"])
	# One that leaves with an ENTER, a PERSON and a shout still waiting.
	var gone: Node = await _limits_guest("LimitsLeftoversLeaves")
	gone.send_event(Wire.EVENT_PERSON, person)
	gone.send_event(Wire.EVENT_ENTER, Wire.enter_payload(26.0))
	gone.shout(Vector2(1.0, 2.0), 26.0, 1100.0)
	await _limits_until(func() -> bool:
		return (host.pond_events as Array).size() >= 2 and (host.heard as Array).size() >= 1)
	var queued := (host.pond_events as Array).size() + (host.heard as Array).size()
	gone.close()
	await _limits_until(func() -> bool: return int(host.link) == NetSession.Link.LISTENING)
	var after_leave := (host.pond_events as Array).size() + (host.heard as Array).size()
	# One that is cut with an ENTER waiting: a frame over the cap.
	var cut: Node = await _limits_guest("LimitsLeftoversCut")
	cut.send_event(Wire.EVENT_ENTER, Wire.enter_payload(26.0))
	await _limits_until(func() -> bool: return (host.pond_events as Array).size() >= 1)
	var over := Wire.event(9, Wire.EVENT_PERSON, PackedByteArray())
	over.resize(Wire.GUEST_OTHER_MAX + 1)
	cut._to(int(cut.get("_host_id")), over)
	await _limits_until(func() -> bool: return int(host.gate_counts["cuts"]) >= 1)
	var after_cut := (host.pond_events as Array).size() + (host.heard as Array).size()
	# Its minute served, by hand, and the next guest finds nothing waiting.
	(host.get("_book") as Dictionary)["127.0.0.1"]["barred_until"] = 0.0
	var next: Node = await _limits_guest("LimitsLeftoversNext")
	var joined := int(next.link) == NetSession.Link.TOGETHER
	await _wait(0.2)
	var for_next := (host.pond_events as Array).size() + (host.heard as Array).size()
	_says(queued == 3 and after_leave == 0 and after_cut == 0 and joined and for_next == 0,
		"limits T12: a phone host's guest leaves with %d things it said still waiting,"
		% queued + " and another is cut with an ENTER waiting; both go with them, and"
		+ " the next guest finds %d" % for_next)
	await _limits_close([host, gone, cut, next])
	# A dedicated host: one guest leaves, and only what it said goes.
	host = await _limits_host("LimitsLeftoversServer", NetSession.GUESTS_MAX)
	var a: Node = await _limits_guest("LimitsLeftoversA")
	var b: Node = await _limits_guest("LimitsLeftoversB")
	var a_id: int = a.my_id()
	var b_id: int = b.my_id()
	a.send_event(Wire.EVENT_ENTER, Wire.enter_payload(26.0))
	a.shout(Vector2(3.0, 4.0), 26.0, 1100.0)
	b.send_event(Wire.EVENT_ENTER, Wire.enter_payload(28.0))
	await _limits_until(func() -> bool: return (host.inbox as Array).size() >= 3)
	var before := (host.inbox as Array).size()
	a.close()
	await _limits_until(func() -> bool: return int(host.peer_count()) == 1)
	var from_a := 0
	var from_b := 0
	for said: Array in host.inbox:
		from_a += 1 if int(said[0]) == a_id else 0
		from_b += 1 if int(said[0]) == b_id else 0
	var load: Dictionary = host.get("_inbox_load")
	_says(before == 3 and from_a == 0 and from_b == 1 and not load.has(a_id)
			and int(b.link) == NetSession.Link.TOGETHER,
		"limits T12: a dedicated host holding %d events from two guests forgets the" % before
		+ " two from the one that left (%d left) and keeps the other's (%d)" % [from_a, from_b])
	await _limits_close([host, a, b])


## A host of its own, for one test: its own socket, so its own door.
func _limits_host(named: String, guests: int = 1) -> Node:
	var host: Node = await _session(named)
	host.host(guests)
	return host


## A real guest on this build's own code, joined to whoever is hosting on
## loopback -- or left as it is if the host never welcomed it.
func _limits_guest(named: String) -> Node:
	var guest: Node = await _session(named)
	guest.join("127.0.0.1")
	await _until_link(guest, NetSession.Link.TOGETHER)
	return guest


func _limits_rogue(named: String) -> Rogue:
	var rogue := Rogue.new()
	rogue.name = named
	add_child(rogue)
	rogue.call_host()
	return rogue


## Frames until [param done] says so, or [param seconds] pass: the seconds it
## took, or -1.
func _limits_until(done: Callable, seconds: float = SETTLE) -> float:
	var from := _now()
	while not done.call():
		if _now() - from >= seconds:
			return -1.0
		await get_tree().process_frame
	return _now() - from


## Closes every session and hangs up every Rogue in [param nodes] that is still
## there -- a test may have closed some itself.
func _limits_close(nodes: Array) -> void:
	for node: Variant in nodes:
		if not is_instance_valid(node):
			continue
		if node is Rogue:
			(node as Rogue).hang_up()
		elif node is Node:
			(node as Node).close()
	await _wait(0.3)


## True when a session's counts show nothing refused, struck, cut or dropped --
## and, in watch mode, nothing the budgets would have dropped or cut either.
func _limits_clean(counts: Dictionary) -> bool:
	return _limits_unclean([counts]).is_empty()


## The offence counters that are not zero, as " -- NOT: name n, ...", or "".
func _limits_unclean(all: Array) -> String:
	var bad: Array[String] = []
	for counts: Dictionary in all:
		for key: String in ["refused", "cuts", "bars", "strikes", "oversize", "malformed",
				"unknown", "dropped", "queue_dropped", "strays", "would_drop",
				"would_strikes", "would_cuts", "fouls"]:
			if float(counts.get(key, 0)) != 0.0:
				bad.append("%s %s" % [key, str(counts[key])])
	return "" if bad.is_empty() else " -- NOT: " + ", ".join(bad)


# ---------------------------------------------------------------------------
# **The referee, with no socket** (docs/design/net-hardening.md B.5): what a
# host checks a guest's word against, driven by hand on a clock of its own --
# every rule at its edge, a born body's honest life through a modelled rough
# link, and a tier-3 body at the physical peak through the same. No frames,
# only arithmetic, like `pond-field`. R1-R4 are here; R5-R11, which need a real
# host's water, are `_check_pond_referee`'s.
# ---------------------------------------------------------------------------

const Referee := preload("res://game/net/referee.gd")
## **The rules two builds must agree on, as the game writes them** (§11.3).
const Rules := preload("res://game/net/rules.gd")
## R2's and R3's link: `tools/net_lag.gd`'s `rough`, modelled here with no
## socket -- 10-50 ms of flight, 5% of frames lost, a 5% chance of 100-250 ms
## more, and a reliable frame resent after 150 ms, doubling, with every
## reliable frame behind it waiting for it.
const REF_FLIGHT_MIN := 0.010
const REF_FLIGHT_MAX := 0.050
const REF_LOSS := 0.05
const REF_SPIKE := 0.05
const REF_SPIKE_MIN := 0.100
const REF_SPIKE_MAX := 0.250
const REF_RTO := 0.150
## The nodes the section builds by hand, freed at its end.
var _ref_nodes: Array[Node] = []


## **cell.gd's drawn controls, reduced to what R2 drives**: a push held, a
## steering demand the probe sets. Never floating, so the body reads it. A Node
## because that is what a body's `controls` holds.
class RefStick extends Node:
	const NONE := 0
	const DASH := 1
	var demand := 0.0

	func floating() -> bool:
		return false

	func steer() -> float:
		return demand

	func pushing() -> bool:
		return true

	## The hold pad (automation-ux.md §6.1), never held here: R2 swims flat out.
	func holding() -> bool:
		return false

	func press(_index: int, _at: Vector2) -> int:
		return NONE

	func move(_index: int, _at: Vector2) -> bool:
		return false

	func release(_index: int) -> int:
		return NONE


func _check_referee() -> void:
	var from := _clock()
	_referee_rules()
	_referee_agrees()
	_referee_teleport()
	_referee_tier_three()
	_referee_silence()
	_referee_radius()
	_referee_dividing()
	_referee_unseen()
	_referee_bodies()
	_referee_arrivals()
	_referee_deaths()
	_referee_shouts()
	_referee_reentry()
	_referee_once()
	_referee_gaps()
	_referee_rim()
	for node: Node in _ref_nodes:
		if is_instance_valid(node):
			node.free()
	_ref_nodes.clear()
	print("[net-probe] NOTE referee took %.1f s of wall time and no frames"
		% (_clock() - from))


## A referee whose guest has just arrived at [param at] and been seen there:
## PERSON with a new body, ENTER, the host's arrival, and a first state frame.
func _ref_arrived(now: float, at: Vector2, radius: float = CellBody.BASE_RADIUS,
		tiers: Dictionary = Catalogue.born()) -> Referee:
	var ref := Referee.new(now)
	ref.judge_person(now, true, tiers, tiers.keys(), false)
	ref.judge_enter(now, radius, false)
	ref.arrive(now, at, radius)
	ref.claim(now + 0.05, at, 0.0, radius, Vector2.ZERO, 0.0, false)
	return ref


## The rules of [param fouls] (from `take_fouls`), in order.
static func _ref_rules(fouls: Array) -> Array:
	return fouls.map(func(foul: Array) -> String: return str(foul[0]))


## **The rules two builds in one pond must agree on** (gene-catalogue.md §11.3):
## the game writes them out itself (game/net/rules.gd) and the handshake carries their
## fingerprint, so two builds on other rules refuse each other there. Here they are
## written again from the real constants, by name, and held three ways: every table a
## row marks judged or contact is in them, by every organ; the game's text is this
## one, line for line; and `Wire.RULES` pins their SHA-256, so they change on purpose.
func _referee_rules() -> void:
	var doubts: Array = []
	var text := _rules_text(doubts)
	var now := text.sha256_text()
	# Every stat a row marks as judged or contact is in the text, by every provider.
	var unwritten: Array[String] = []
	var shared := Stats.judged() + Stats.contact()
	for stat: StringName in shared:
		if not ("\n" + text).contains("\nstat.%s=" % stat):
			unwritten.append("stat." + String(stat))
		var providers := Catalogue.providers(stat)
		for k in providers.size():
			var label := Stats.label(stat) + ("" if k == 0 else "." + String(providers[k]))
			if not ("\n" + text).contains("\n%s=" % label):
				unwritten.append(label)
	_says(unwritten.is_empty(), "referee: every table of the %d stats the referee judges"
		% Stats.judged().size() + " and the %d the host decides a contact by" % Stats.contact().size()
		+ " is in the rules the handshake fingerprints, one line an organ that provides"
		+ " it, after the stat's row%s" % ("" if unwritten.is_empty()
			else "; not %s -- write it in _rules_text" % ", ".join(unwritten)))
	# **Every constant of referee.gd is a limit the rules write, or one named as no
	# limit with why** (rules.gd's REFEREE_LIMITS and REFEREE_NOT_LIMITS): a limit
	# added to the referee's judgement fails here until it is in the rules or said
	# not to be, and a name either list keeps after referee.gd lost it fails too.
	var constants := {}
	for key: Variant in (Referee as Script).get_script_constant_map():
		constants[String(key)] = true
	var neither: Array[String] = []
	var twice: Array[String] = []
	var gone: Array[String] = []
	for name: String in constants:
		var limit := Rules.REFEREE_LIMITS.has(name)
		var no_limit := Rules.REFEREE_NOT_LIMITS.has(name)
		if limit and no_limit:
			twice.append(name)
		elif not limit and not no_limit:
			neither.append(name)
		elif no_limit and str(Rules.REFEREE_NOT_LIMITS[name]).strip_edges().is_empty():
			neither.append(name + " (no reason given)")
	for name: Variant in Rules.REFEREE_LIMITS + Rules.REFEREE_NOT_LIMITS.keys():
		if not constants.has(String(name)):
			gone.append(String(name))
	var sorted := neither.is_empty() and twice.is_empty() and gone.is_empty()
	_says(sorted, ("referee: every one of referee.gd's %d constants is sorted -- the %d"
		% [constants.size(), Rules.REFEREE_LIMITS.size()] + " limits the rules write, and"
		+ " %d named as no limit, with why: the scripts it loads, its rules' names and"
		% Rules.REFEREE_NOT_LIMITS.size() + " its budgets' class") if sorted
		else ("referee: referee.gd's constants are not all sorted -- in neither list: %s;"
			% (", ".join(neither) if not neither.is_empty() else "none") + " in both: %s;"
			% (", ".join(twice) if not twice.is_empty() else "none") + " listed, and not"
			+ " referee.gd's: %s -- a limit goes in rules.gd's REFEREE_LIMITS, which moves"
			% (", ".join(gone) if not gone.is_empty() else "none") + " the pin, and"
			+ " anything else in REFEREE_NOT_LIMITS, with why"))
	# **A row's fields are each written or said not to decide a value**: a field
	# stats.gd's rows gain -- phase 5's `group` -- fails here until it is one or the
	# other, so how two providers combine cannot change with no line moving.
	var unsorted: Array[String] = []
	var fields := {}
	for stat: StringName in Stats.ROWS:
		for field: Variant in Stats.ROWS[stat]:
			fields[String(field)] = true
			var written := Rules.ROW_FIELDS.has(String(field))
			if written == Rules.ROW_FIELDS_UNREAD.has(String(field)):
				unsorted.append("%s.%s" % [stat, field])
	for field: String in Rules.ROW_FIELDS + Rules.ROW_FIELDS_UNREAD.keys():
		if not fields.has(field):
			unsorted.append("%s, which no row has" % field)
	_says(unsorted.is_empty(), ("referee: every field of stats.gd's %d rows is written on"
		% Stats.ROWS.size() + " the row's line -- %s -- or named as deciding no value, with"
		% ", ".join(Rules.ROW_FIELDS) + " why -- %s" % ", ".join(Rules.ROW_FIELDS_UNREAD.keys()))
		if unsorted.is_empty() else ("referee: a field of stats.gd's rows is not sorted: %s"
			% ", ".join(unsorted) + " -- a field that decides a body's value goes at the end"
			+ " of rules.gd's ROW_FIELDS, which moves the pin, and one that does not in"
			+ " ROW_FIELDS_UNREAD, with why"))
	# **The game's own text is this one**: what it carries on the handshake is what is
	# written here from the constants themselves.
	var game := Rules.text()
	var ours := text.split("\n")
	var theirs := game.split("\n")
	var first := -1
	for k in maxi(ours.size(), theirs.size()):
		if k >= ours.size() or k >= theirs.size() or ours[k] != theirs[k]:
			first = k
			break
	_says(first < 0, ("referee: the game writes the %d lines of its rules as this probe"
		% theirs.size() + " does from the real constants (%s)" % Rules.hex().left(16)) if first < 0
		else ("referee: the game's rules (game/net/rules.gd) and this probe's differ at line"
			+ " %d: the game's '%s', this probe's '%s' -- write the same value in both"
			% [first + 1, theirs[first] if first < theirs.size() else "",
			ours[first] if first < ours.size() else ""]))
	# **Written the same on every machine** (rules.gd's note): every float as whole
	# millionths by Godot alone, none within RULE_TIE of a rounding edge -- the body
	# plan's own numbers too, inside its fingerprint -- and nothing of a kind the rules
	# would hand to the C library to write.
	_says(doubts.is_empty(), ("referee: every value of the %d lines is one every machine"
		% ours.size() + " writes alike -- each float as whole millionths, by Godot alone,"
		+ " and none within %s of a half, the plan's own numbers in its line too" % RULE_TIE)
		if doubts.is_empty() else ("referee: the rules print values one machine could"
			+ " write otherwise: %s -- move a sample off its edge, or write the value as"
			% "; ".join(PackedStringArray(doubts)) + " rules.gd's note says"))
	# **The tripwire**: a build's rules move only on purpose. No PROTOCOL moves with
	# them any more -- the handshake keeps builds on other rules apart by itself.
	var ok := now == Wire.RULES
	_says(ok, ("referee: the %d rules two builds must agree on fingerprint to Wire.RULES"
		% ours.size() + " (%s)" % now.left(16)) if ok
		else ("referee: the rules two builds must agree on changed -- they fingerprint to %s"
			% now + " now, and Wire.RULES says %s. A build on these refuses every build"
			% Wire.RULES + " on the old ones at the handshake, with the version sentence,"
			+ " until both update: if that is meant, set Wire.RULES to the new value in the"
			+ " same commit. No Wire.PROTOCOL bump -- that moves only when a message's format"
			+ " does (wire.gd)"))


## **Every value two builds in one pond must agree on**, one per line, written from
## where each is defined, in the order game/net/rules.gd writes them: every table a
## row marks judged or contact, by every organ; the run's numbers the referee judges
## by; the contact rules no table holds; the referee's own limits; the body plan.
## `Wire.RULES` is its SHA-256. A value added to the referee's judgement, or to what
## the host decides a contact by, belongs here and there. **What one machine could
## write otherwise** -- a float on a rounding edge, a kind of value the rules do not
## write digit by digit -- is said in [param doubts], by its line ([method _rule_doubts]).
func _rules_text(doubts: Array = []) -> String:
	var lines: PackedStringArray = []
	var put := func(name: String, value: Variant) -> void:
		lines.append("%s=%s" % [name, _rule_value(value)])
		_rule_doubts(name, value, doubts)
	# **A stat two builds must agree on**: its row -- the fields of it that decide a
	# body's value, read here by name, each as `name:value` -- then its table by every
	# organ that provides it, the first under the name its table had as cell.gd's
	# (stats.gd's `label`), any other after it with its key, as drop_save.gd writes
	# them. A second organ that calls, or swims, or bites, is a new line -- and new
	# rules, which the handshake keeps apart.
	for stat: StringName in Stats.ROWS:
		if not Stats.judged().has(stat) and not Stats.contact().has(stat):
			continue
		var row: Dictionary = Stats.ROWS[stat]
		var items: PackedStringArray = []
		for field: String in Rules.ROW_FIELDS:
			if row.has(field):
				items.append("%s:%s" % [field, _rule_value(row[field])])
				_rule_doubts("stat.%s" % stat, row[field], doubts)
		lines.append("stat.%s=%s" % [stat, ",".join(items)])
		var providers := Catalogue.providers(stat)
		for k in providers.size():
			put.call(Stats.label(stat) + ("" if k == 0 else "." + String(providers[k])),
				Catalogue.table(providers[k], stat))
	# cell.gd: size, growth, division and mending; and the motion the caps sit over
	# (`_referee_agrees`).
	put.call("cell.BASE_RADIUS", CellBody.BASE_RADIUS)
	put.call("cell.GROWTH_PER_MEAL", CellBody.GROWTH_PER_MEAL)
	put.call("cell.DIVIDE_RADIUS", CellBody.DIVIDE_RADIUS)
	put.call("cell.DIVIDE_SPLIT", CellBody.DIVIDE_SPLIT)
	put.call("cell.daughter_radius", CellBody.daughter_radius(CellBody.DIVIDE_RADIUS))
	put.call("cell.MEND_SECONDS", CellBody.MEND_SECONDS)
	put.call("cell.mended(0.5,10)", CellBody.mended(0.5, 10.0))
	put.call("cell.IMPULSE_KICK", CellBody.IMPULSE_KICK)
	put.call("cell.DRAG", CellBody.DRAG)
	put.call("cell.DASH_COOLDOWN", CellBody.DASH_COOLDOWN)
	put.call("cell.WANDER_RATE", CellBody.WANDER_RATE)
	# food.gd: the grace, and what a contact and a death are called.
	put.call("food.FIRST_DELAY", FoodField.FIRST_DELAY)
	put.call("food.Contact", FoodField.Contact)
	put.call("food.Cause", FoodField.Cause)
	put.call("food.By", FoodField.By)
	# **The drop** (ocean.md §10.5): a floc feeds and grows nobody, so a graze is
	# never a meal to the referee; the rim holds a body in -- by a sample value,
	# as `cell.mended` is -- which is where a claim past it is held and a sister
	# near it is put; and the two eating rules a guest is held to, which the host
	# decides and the referee never judges, one sample each: a mouth swallows a
	# player that fits on contact, hunting or not (row 15), and armour makes a body
	# bigger to a mouth (row 5).
	put.call("drop.FLOC_GROWTH", FoodField.Drop.FLOC_GROWTH)
	var held: Vector2 = FoodField.Drop.new().meniscus.contain(Vector2(7000.0, 125.0),
		Referee.DAUGHTER_RADIUS)
	put.call("drop.contain(7000,125;r28.28).x", held.x)
	put.call("drop.contain(7000,125;r28.28).y", held.y)
	put.call("food.swallows_player(not hunting, on contact)",
		FoodField.swallows_player(false, FoodField.CONTACT_SWALLOW, 20.0, 30.0))
	put.call("food.armoured_size(r30, pellicle 2)",
		FoodField.armoured_size(30.0, Stats.at(&"armor", 2), FoodField.ARMOUR_SWALLOW))
	# normal_mode.gd: the sister's ring, the run's own; and the free senses, the
	# catalogue's `gift` tag since there was a catalogue, under the name they had.
	put.call("run.SISTER_DISTANCE", NormalMode.SISTER_DISTANCE)
	put.call("run.FIRST_SENSES", Catalogue.tagged(Catalogue.GIFT))
	# genome.gd: the tiers, a born body -- each organ's own `born` -- and the
	# gift's tier, measured on a real genome rather than read off its constant.
	put.call("genome.TIER_MAX", Genome.TIER_MAX)
	put.call("genome.BORN", Catalogue.born())
	var genome: Node = Genome.new()
	genome.express(Catalogue.born().duplicate(), Catalogue.born_order())
	genome.gift(&"stigma")
	genome.place(0)
	put.call("genome.gift_tier", int((genome.tiers() as Dictionary).get(&"stigma", 0)))
	genome.free()
	# **The contact rules no table holds** (shared-pond.md §7; wire.gd's rule under
	# PROTOCOL until protocol 8): the bite's gap and flank, `bite_damage` by two
	# samples, the doses' constants, with how a dose is felt by one, and the dart.
	put.call("cell.BITE_GAP", CellBody.BITE_GAP)
	put.call("cell.FLANK_AHEAD", CellBody.FLANK_AHEAD)
	put.call("cell.FLANK_ASTERN", CellBody.FLANK_ASTERN)
	put.call("cell.bite_damage(0.3,20,r30,1.3,ahead)",
		CellBody.bite_damage(0.3, 20.0, 30.0, 1.3, 0.0))
	put.call("cell.bite_damage(0.3,40,r30,1,astern)",
		CellBody.bite_damage(0.3, 40.0, 30.0, 1.0, PI))
	put.call("cell.VENOM_ARC_DEG", CellBody.VENOM_ARC_DEG)
	put.call("cell.VENOM_SIDES", CellBody.VENOM_SIDES)
	put.call("cell.HARM_PER_STACK", CellBody.HARM_PER_STACK)
	put.call("cell.DOSE_TAU_BY_KIND", CellBody.DOSE_TAU_BY_KIND)
	put.call("cell.DOSE_GONE", CellBody.DOSE_GONE)
	put.call("cell.DOSE_SIZE", CellBody.DOSE_SIZE)
	put.call("doses.felt(2,r30)", FoodField.Doses.felt(2.0, 30.0, CellBody.DOSE_SIZE))
	# **The dart** (behaviour.md §4.3), which the host fires for a guest as for its own
	# cell: the arc it answers on, and what each organ that darts stuns for -- its own
	# number, read off the organ here rather than through `dart_stun`.
	put.call("cell.DART_ARC_DEG", CellBody.DART_ARC_DEG)
	var darts := Catalogue.providers(&"dart_range")
	for k in darts.size():
		var stun: Variant = Catalogue.number(darts[k], &"stun")
		put.call("cell.dart_stun" + ("" if k == 0 else "." + String(darts[k])),
			float(stun) if stun != null else 0.0)
	# referee.gd: its own limits, and its copies of the run's numbers, by the one list
	# of them (rules.gd's REFEREE_LIMITS), each read here off referee.gd by name.
	# `_referee_rules` sorts every constant referee.gd has by that list and the list of
	# those that are not limits. **The gift's senses are no copy any more**: the
	# referee reads the catalogue's `gift` tag (§11.1), which `run.FIRST_SENSES` is.
	var referee: Dictionary = (Referee as Script).get_script_constant_map()
	for name: String in Rules.REFEREE_LIMITS:
		put.call("referee." + name, referee.get(name))
	# **The body plan** (gene-catalogue.md §10.4): builds on other plans -- other slot
	# counts, other arcs -- are other rules. Its text written again here from its rows,
	# so the game's fingerprint of it is held to them too.
	put.call("plan.fingerprint", _plan_text(doubts).sha256_text())
	return "\n".join(lines)


## **The body plan's text, written again from its rows** (body_plan.gd's
## `fingerprint`, whose SHA-256 is the rules' last line): the body's shape, then a line
## a slot, every number a whole number of millionths, as the rules write a float --
## and each held off a rounding edge as theirs are, in [param doubts].
static func _plan_text(doubts: Array) -> String:
	var lines := PackedStringArray()
	var shape := [BodyPlan.OVOID_ALONG, BodyPlan.OVOID_ACROSS, BodyPlan.OVOID_PINCH]
	_rule_doubts("plan.fingerprint, the shape", shape, doubts)
	lines.append("shape=%s,%s,%s" % [_rule_value(shape[0]), _rule_value(shape[1]),
		_rule_value(shape[2])])
	for row: Dictionary in BodyPlan.rows():
		var arc_of: Vector2 = row.get("arc", Vector2.ZERO)
		var numbers := [arc_of.x, arc_of.y, float(row["earned"])]
		_rule_doubts("plan.fingerprint, slot %s" % row["id"], numbers, doubts)
		lines.append("%s|%s|%s|%s,%s|%s|%s" % [row["id"], row["place"],
			row.get("anatomy", &""), _rule_value(numbers[0]), _rule_value(numbers[1]),
			_rule_value(numbers[2]), row.get("home", &"")])
	return "\n".join(lines)


## One value, written the same way on every machine, by Godot alone: a float as a
## whole number of millionths, a list comma-joined, a dictionary by its keys in order.
static func _rule_value(value: Variant) -> String:
	var kind := typeof(value)
	if kind == TYPE_FLOAT:
		return str(roundi(float(value) * 1e6))
	if Rules.LISTS.has(kind):
		var parts: PackedStringArray = []
		for each: Variant in value:
			parts.append(_rule_value(each))
		return "[" + ",".join(parts) + "]"
	if kind == TYPE_DICTIONARY:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var parts: PackedStringArray = []
		for key: Variant in keys:
			parts.append("%s:%s" % [str(key), _rule_value(value[key])])
		return "{" + ",".join(parts) + "}"
	return str(value)


## **How near a half a float's millionths may come** before the rules call it a tie
## (rules.gd's note): a thousandth of a millionth, some thousand times the last bit
## of the largest number they print, so no machine's last bit can tip one.
const RULE_TIE := 1e-3


## **What in [param value] one machine could write otherwise**, said in [param doubts]
## under [param name]: a float whose millionths lie within [constant RULE_TIE] of a
## half, or that is not finite; a dictionary keyed by anything but a whole number, a
## bool or a name; and a value of any kind but those, a float and the lists and
## dictionaries rules.gd's `value_text` writes item by item.
static func _rule_doubts(name: String, value: Variant, doubts: Array) -> void:
	var kind := typeof(value)
	if kind == TYPE_FLOAT:
		var x := float(value)
		var off := absf(fposmod(x * 1e6, 1.0) - 0.5) if is_finite(x) else 0.0
		if not is_finite(x) or off < RULE_TIE:
			doubts.append("%s: %.9f, %s" % [name, x, "not a number it can write"
				if not is_finite(x) else "its millionths %.6f from a half" % off])
	elif kind == TYPE_DICTIONARY:
		for key: Variant in value:
			if not [TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME].has(typeof(key)):
				doubts.append("%s: a key that is a %s" % [name, type_string(typeof(key))])
			_rule_doubts(name, value[key], doubts)
	elif Rules.LISTS.has(kind):
		for each: Variant in value:
			_rule_doubts(name, each, doubts)
	elif not [TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME].has(kind):
		doubts.append("%s: a %s, which the rules do not write digit by digit" % [name,
			type_string(kind)])


## **The numbers the referee writes out, held to where they come from**, and its
## caps held over the fastest and the hardest-turning bodies the tables make.
func _referee_agrees() -> void:
	# **The gift's senses are the run's own**: every live gene the referee takes
	# as a born body's one gift is one the run can give, and no other.
	var senses := Catalogue.tagged(Catalogue.GIFT)
	var gifts := not senses.is_empty()
	for gene: StringName in Catalogue.live():
		var after := Catalogue.born().duplicate()
		after[gene] = 1
		gifts = gifts and Referee._is_gift(Catalogue.born(), after) \
			== (senses.has(gene) and not Catalogue.born().has(gene))
	var peak := _stacked_peak()
	# **The hardest turn**: the best steering any organ gives, flat out, the drift
	# at its most, and an impulse's kick to the nose as often as the shortest gap
	# any tail beats at -- every provider of each, as the peak above.
	var steer := Stats.top(&"turn_rate") + CellBody.WANDER_RATE
	var turn := steer + CellBody.IMPULSE_KICK / Stats.top(&"impulse_gap_min")
	_says(is_equal_approx(Referee.SISTER_DISTANCE, NormalMode.SISTER_DISTANCE)
			and is_equal_approx(Referee.DAUGHTER_RADIUS,
				CellBody.daughter_radius(CellBody.DIVIDE_RADIUS))
			and gifts
			and Referee.SPEED_MAX > peak and Referee.MOVE_RATE > peak
			and Referee.TURN_RATE > turn and Referee.TURNING_MAX > steer,
		"referee: its ring (%.0f), a daughter's r%.3f and the gift's four senses are"
		% [Referee.SISTER_DISTANCE, Referee.DAUGHTER_RADIUS] + " the run's own; its"
		+ " %.0f u/s is over every speed-up at the top tier, stacked (%.0f u/s), and"
		% [Referee.MOVE_RATE, peak] + " its %.2f rad/s over the hardest turn the"
		% Referee.TURN_RATE + " tables make (%.2f rad/s, %.2f of it steering)"
		% [turn, steer])


## **The fastest the tables let any body go**, every speed-up at its peak at once:
## the best beat any tail gives, as often as the shortest gap any tail allows,
## the most push every organ that pushes adds, and the best dash -- each by
## every organ that provides it (stats.gd's `top`), so a second organ that
## swims is under the referee's cap as well, or this says it is not.
static func _stacked_peak() -> float:
	return Stats.top(&"impulse_speed") \
		/ (1.0 - exp(-CellBody.DRAG * Stats.top(&"impulse_gap_min"))) \
		+ Stats.top(&"push_accel") / CellBody.DRAG \
		+ Stats.top(&"dash_speed") / (1.0 - exp(-CellBody.DRAG * CellBody.DASH_COOLDOWN))


## **R1: a 5,000 unit teleport.** The host moves the body no further than the
## budget and fouls it once, 2 points; the honest frames after it foul nothing,
## and the host's place walks to them at the cap.
func _referee_teleport() -> void:
	var t := 0.0
	var at := Vector2.ZERO
	var ref := _ref_arrived(t, at)
	for i in 40:
		t += 0.05
		at += Vector2(0.0, -2.5)
		ref.claim(t, at, 0.0, 26.0, Vector2(0.0, -50.0), 0.0, false)
	ref.take_fouls()
	t += 0.05
	var jumped := t
	var there := at + Vector2(5000.0, 0.0)
	var put: Array = ref.claim(t, there, 0.0, 26.0, Vector2.ZERO, 0.0, false)
	var moved: float = (put[0] as Vector2).distance_to(at)
	var said := ref.take_fouls()
	var converged := -1.0
	for i in 200:
		t += 0.05
		there += Vector2(0.0, -2.5)
		put = ref.claim(t, there, 0.0, 26.0, Vector2(0.0, -50.0), 0.0, false)
		if converged < 0.0 and (put[0] as Vector2).distance_to(there) < 0.01:
			converged = t - jumped
	var after := ref.take_fouls()
	_says(said.size() == 1 and str(said[0][0]) == Referee.MOVE
			and float(said[0][1]) == Referee.WEIGHT_MOVE
			and moved <= Referee.MOVE_HOLD + Referee.MOVE_SLACK + 0.01 and moved > 1000.0
			and after.is_empty() and converged > 0.0,
		"referee R1: a 5,000-unit teleport fouls once (%s, %.0f points) and the"
		% [str(said[0][0]) if not said.is_empty() else "none",
			float(said[0][1]) if not said.is_empty() else 0.0]
		+ " host moves the body %.0f -- the budget and its slack; the honest" % moved
		+ " frames after it foul nothing, and the host's place walks to them at the"
		+ " cap, %.1f s later" % converged)


## **R2: a cell with every organ at tier 3, driven by cell.gd's own physics
## for 60 s through `rough`**: a held push, a dash every cooldown, a steering
## demand that changes every 0.4-2.0 s, its own impulses, a call every 15.2 s.
## Every state frame crosses the wire's own bytes; the host takes the newest
## that has landed, once a frame at 60 frames a second. No foul; the closest
## call printed.
func _referee_tier_three() -> void:
	var fouls := _ref_swim({&"cytostome": 3, &"cirrus": 3, &"flagellum": 3,
		&"axoneme": 3, &"myoneme": 3, &"ampulla": 3}, 60.0, true, 0.0, 26925)
	# **And at the bound itself.** cell.gd's own physics never lines every
	# speed-up up at its peak at once, so the body above tops out short of it; a
	# body held at the stacked peak the tables make, straight on, is the bound.
	var peak := _stacked_peak()
	var held := _ref_straight(peak, 60.0, 26926)
	_says(int(fouls[0]) == 0 and int(fouls[2]) > 1000 and int(fouls[3]) >= 3
			and int(held[0]) == 0 and int(held[1]) > 900,
		"referee R2: a tier-3 body swimming flat out for 60 s through a rough link"
		+ " fouls %d times over %d state frames and %d calls -- fastest %.0f u/s;"
		% [int(fouls[0]), int(fouls[2]), int(fouls[3]), float(fouls[4])]
		+ " closest calls: movement %.0f%%, heading %.0f%%, calls %.0f%%"
		% [100.0 * float(fouls[5]), 100.0 * float(fouls[6]), 100.0 * float(fouls[7])]
		+ " (%d frames lost, %d spiked); and one held at the stacked peak, %.0f u/s,"
		% [int(fouls[8]), int(fouls[9]), peak] + " through the same link, %d over %d"
		% [int(held[0]), int(held[1])] + " frames, closest call %.0f%%"
		% (100.0 * float(held[2])))


## **A body held at [param speed], straight on, through the modelled `rough`
## link** for [param seconds]: `[fouls, state frames judged, closest movement]`.
func _ref_straight(speed: float, seconds: float, dice: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = dice
	var ref := Referee.new(0.0)
	ref.judge_person(0.0, true, Catalogue.born(), Catalogue.born().keys(), false)
	ref.judge_enter(0.0, CellBody.BASE_RADIUS, false)
	ref.arrive(0.0, Vector2.ZERO, CellBody.BASE_RADIUS)
	var step := 1.0 / 60.0
	var t := 0.0
	var beat_at := 0.0
	var seq := 0
	var states: Array = []
	var newest := -1
	var judged := 0
	while t < seconds:
		t += step
		if t >= beat_at:
			beat_at = t + NetSession.STATE_PERIOD
			seq += 1
			var lands := _ref_lands(t, true, rng)
			if lands >= 0.0:
				states.append([lands, seq, Vector2(speed * t, 0.0)])
		var best: Array = []
		for each: Array in states:
			if float(each[0]) <= t and int(each[1]) > newest \
					and (best.is_empty() or int(each[1]) > int(best[1])):
				best = each
		states = states.filter(func(each: Array) -> bool: return float(each[0]) > t)
		if not best.is_empty():
			newest = int(best[1])
			ref.claim(t, best[2], 0.0, CellBody.BASE_RADIUS, Vector2(speed, 0.0), 0.0, false)
			judged += 1
	return [ref.fouled(), judged, ref.move.closest]


## **One body swimming through the modelled link**, for R2 and R3: `[fouls,
## rules, state frames judged, calls, fastest speed, closest movement, heading,
## calls, frames lost, frames spiked]`. [param rough] models `rough`, or no
## network; [param silence] holds every frame back for that many seconds from
## the fifth second, then lands them at once. Stepped on a clock of its own, 60
## frames a second a side, so no frame of the probe is spent.
func _ref_swim(tiers: Dictionary, seconds: float, rough: bool, silence: float,
		dice: int) -> Array:
	seed(dice)
	var rng := RandomNumberGenerator.new()
	rng.seed = dice
	var genome := StubGenome.new()
	genome.body = tiers.duplicate()
	var cell: Node = CellBody.new()
	cell.genome = genome
	cell.radius = CellBody.BASE_RADIUS
	var stick := RefStick.new()
	cell.controls = stick
	_ref_nodes.append_array([genome, cell, stick])
	# As every arrival starts a body: held, or reset, with its first impulse
	# 0.6-1.4 s off -- never a kick in the first frame after the ARRIVE.
	cell.reset(true)
	var ref := Referee.new(0.0)
	var order: Array = tiers.keys()
	ref.judge_person(0.0, true, tiers, order, false)
	ref.judge_enter(0.0, cell.radius, false)
	ref.arrive(0.0, cell.position, cell.radius)
	var reach: float = cell.ping_range()
	var period: float = cell.ping_period()
	var step := 1.0 / 60.0
	var t := 0.0
	var steer_at := 0.0
	var beat_at := 0.0
	var call_at := 0.0
	var seq := 0
	var lost := 0
	var spiked := 0
	var fastest := 0.0
	var states: Array = []
	var calls: Array = []
	var reliable_free := 0.0
	var newest := -1
	var host_t := 0.0
	var judged := 0
	var called := 0
	while t < seconds:
		# The guest's frame: steer, dash when it can, step the body.
		if t >= steer_at:
			stick.demand = [-1.0, -0.5, 0.0, 0.5, 1.0][rng.randi_range(0, 4)]
			steer_at = t + rng.randf_range(0.4, 2.0)
		cell.call(&"_dash")
		var before: Vector2 = cell.velocity
		cell._process(step)
		t += step
		fastest = maxf(fastest, (cell.velocity as Vector2).length())
		var jumped: bool = ((cell.velocity as Vector2) - before).length() > 20.0
		if t >= beat_at or jumped:
			beat_at = t + NetSession.STATE_PERIOD
			seq += 1
			var frame := Wire.state(seq, true, cell.position, cell.heading, cell.radius,
				cell.velocity, cell.heading_rate(), Wire.STATE_POND)
			var lands := _ref_lands(t, rough, rng)
			if lands < 0.0:
				lost += 1
			else:
				if lands - t > REF_FLIGHT_MAX + 0.001:
					spiked += 1
				if silence > 0.0 and t >= 5.0 and t < 5.0 + silence:
					lands = maxf(lands, 5.0 + silence)
				states.append([lands, seq, Wire.state_body(frame)])
		if period > 0.0 and t >= call_at:
			call_at = t + period
			var lands := t + (_ref_flight(rng) if rough else 0.0)
			var tries := 0
			while rough and rng.randf() < REF_LOSS:
				lands += REF_RTO * pow(2.0, float(tries))
				tries += 1
			lands = maxf(lands, reliable_free)
			reliable_free = lands
			calls.append([lands, cell.position, cell.radius, reach])
		# The host's frames, up to now: the newest state frame that has landed,
		# and every call, in order.
		while host_t + step <= t:
			host_t += step
			var best: Array = []
			for each: Array in states:
				if float(each[0]) <= host_t and int(each[1]) > newest \
						and (best.is_empty() or int(each[1]) > int(best[1])):
					best = each
			states = states.filter(func(s: Array) -> bool: return float(s[0]) > host_t)
			if not best.is_empty() and not (best[2] as Array).is_empty():
				newest = int(best[1])
				var body: Array = best[2]
				ref.claim(host_t, body[0], float(body[1]), float(body[2]), body[3],
					float(body[4]), false)
				judged += 1
			while not calls.is_empty() and float(calls[0][0]) <= host_t:
				var call: Array = calls.pop_front()
				ref.judge_shout(host_t, call[1], float(call[2]), float(call[3]), true)
				called += 1
	var rules := _ref_rules(ref.take_fouls())
	return [ref.fouled(), rules, judged, called, fastest, ref.move.closest,
		ref.turn.closest, ref.shouts.closest, lost, spiked]


## When a frame sent at [param t] lands, or -1 for lost: `rough`, or at once.
func _ref_lands(t: float, rough: bool, rng: RandomNumberGenerator) -> float:
	if not rough:
		return t
	if rng.randf() < REF_LOSS:
		return -1.0
	return t + _ref_flight(rng)


func _ref_flight(rng: RandomNumberGenerator) -> float:
	var d := rng.randf_range(REF_FLIGHT_MIN, REF_FLIGHT_MAX)
	if rng.randf() < REF_SPIKE:
		d += rng.randf_range(REF_SPIKE_MIN, REF_SPIKE_MAX)
	return d


## **R3: 3 s of silence, then sixty frames at once** -- a born body swimming
## while nothing it sends lands, and then everything does: no foul. And a host
## that stalls for 3 s, a tier-3 body held after 1.2 s of the quiet, as a
## guest's run holds it: no foul either.
func _referee_silence() -> void:
	var quiet := _ref_swim_now(Catalogue.born(), 12.0, 3.0)
	var t := 0.0
	var at := Vector2.ZERO
	var ref := _ref_arrived(t, at)
	var velocity := Vector2(0.0, -900.0)
	# Swimming at 900 u/s -- near every tier-3 organ's peak together -- until
	# the host stalls; then 1.2 s more before the guest holds; then held.
	for i in 40:
		t += 0.05
		at += velocity * 0.05
		ref.claim(t, at, 0.0, 26.0, velocity, 0.0, false)
	at += velocity * 1.2
	t += 3.0
	ref.stalled(3.0)
	ref.claim(t, at, 0.0, 26.0, Vector2.ZERO, 0.0, false)
	var stall := ref.fouled()
	_says(int(quiet[0]) == 0 and int(quiet[2]) > 100 and stall == 0,
		"referee R3: 3 s of silence and then %d frames at once fouls %d times %s;"
		% [int(quiet[3]), int(quiet[0]), str(quiet[1])] + " a host that stalls 3 s while a body"
		+ " swims 1,080 units at 900 u/s and then holds fouls %d" % stall)


## [method _ref_swim] with no network, for R3: every frame of [param silence]
## seconds from the fifth landing at once. `[fouls, rules, judged, frames
## landed at once]`.
func _ref_swim_now(tiers: Dictionary, seconds: float, silence: float) -> Array:
	seed(3)
	var genome := StubGenome.new()
	genome.body = tiers.duplicate()
	var cell: Node = CellBody.new()
	cell.genome = genome
	var stick := RefStick.new()
	stick.demand = 0.5
	cell.controls = stick
	_ref_nodes.append_array([genome, cell, stick])
	cell.reset(true)
	var ref := Referee.new(0.0)
	ref.judge_person(0.0, true, tiers, tiers.keys(), false)
	ref.judge_enter(0.0, cell.radius, false)
	ref.arrive(0.0, cell.position, cell.radius)
	var step := 1.0 / 60.0
	var t := 0.0
	var beat_at := 0.0
	var held: Array = []
	var judged := 0
	var burst := 0
	while t < seconds:
		cell._process(step)
		t += step
		if t < beat_at:
			continue
		beat_at = t + NetSession.STATE_PERIOD
		var body := [cell.position, cell.heading, cell.radius, cell.velocity,
			cell.heading_rate()]
		if t >= 5.0 and t < 5.0 + silence:
			held.append(body)
			continue
		if not held.is_empty():
			burst = held.size() + 1
			held.clear()
		ref.claim(t, body[0], float(body[1]), float(body[2]), body[3], float(body[4]),
			false)
		judged += 1
	return [ref.fouled(), _ref_rules(ref.take_fouls()), judged, burst]


## **R4: a radius the host never fed.** r36 with no meal is clamped to r26 and
## fouled, 4 points; after one ATE the host sent, r30 is taken.
func _referee_radius() -> void:
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	var over: Array = ref.claim(1.0, Vector2.ZERO, 0.0, 36.0, Vector2.ZERO, 0.0, false)
	var said := ref.take_fouls()
	ref.ate()
	var fed: Array = ref.claim(2.0, Vector2.ZERO, 0.0, 30.0, Vector2.ZERO, 0.0, false)
	var then := ref.take_fouls()
	_says(is_equal_approx(float(over[2]), 26.0) and _ref_rules(said) == [Referee.SIZE]
			and float(said[0][1]) == Referee.WEIGHT_SIZE
			and is_equal_approx(float(fed[2]), 30.0) and then.is_empty(),
		"referee R4: r36 with no meal is put at r%.0f and fouled (%.0f points);"
		% [float(over[2]), float(said[0][1]) if not said.is_empty() else 0.0]
		+ " after the one ATE the host sent, r30 is taken as it is")


## **Dividing and the sister** (the socket-free halves of R5 and R6): an OUT
## only at r40, frozen while it lasts, ending in a birth; a SISTER once for it,
## on the ring at a daughter's size.
func _referee_dividing() -> void:
	# OUT at r30: kept in the water, fouled.
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	ref.ate()
	var early: Array = ref.claim(1.0, Vector2.ZERO, 0.0, 30.0, Vector2.ZERO, 0.0, true)
	var early_said := _ref_rules(ref.take_fouls())
	# A SISTER with no division: nothing placed, fouled.
	var stray := ref.judge_sister(1.1, Vector2(560.0, 0.0), Referee.DAUGHTER_RADIUS, true)
	var stray_said := ref.take_fouls()
	# A real division: grown to r40, out and frozen, a sister on the ring, and a
	# daughter's new body -- with her mother's last OUT frame landing after it.
	ref.credit_meals(3)
	var home := Vector2(10.0, 0.0)
	ref.claim(2.0, home, 0.0, 40.0, Vector2.ZERO, 0.0, false)
	var out: Array = ref.claim(2.5, home, 0.0, 40.0, Vector2(30.0, 0.0), 0.0, true)
	var wandered: Array = ref.claim(3.0, home + Vector2(9.0, 0.0), 0.0, 40.0,
		Vector2.ZERO, 0.0, true)
	var wander_said := _ref_rules(ref.take_fouls())
	var sister := ref.judge_sister(4.0, home + Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS,
		true)
	var tail: Array = ref.claim(4.02, home, 0.0, 40.0, Vector2.ZERO, 0.0, true)
	var again := ref.judge_sister(4.05, home + Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS,
		true)
	var again_said := ref.take_fouls()
	var born := ref.judge_person(4.1, true, Catalogue.born(), Catalogue.born().keys(), true)
	var twice := ref.judge_person(4.2, true, Catalogue.born(), Catalogue.born().keys(), true)
	var twice_said := _ref_rules(ref.take_fouls())
	var daughter: Array = ref.claim(4.3, home, 0.0, Referee.DAUGHTER_RADIUS, Vector2.ZERO,
		0.0, false)
	var clean := ref.take_fouls().is_empty()
	_says(bool(early[5]) and early_said == [Referee.OUT] and stray.is_empty()
			and _ref_rules(stray_said) == [Referee.SISTER]
			and float(stray_said[0][1]) == Referee.WEIGHT_SISTER,
		"referee R5/R6: OUT at r30 is kept in the water and fouled; a SISTER with no"
		+ " division places nothing and fouls %.0f points"
		% (float(stray_said[0][1]) if not stray_said.is_empty() else 0.0))
	_says(not bool(out[5]) and (out[3] as Vector2) == Vector2.ZERO
			and (wandered[0] as Vector2).distance_to(home) < 0.01
			and wander_said == [Referee.OUT] and sister.size() == 2
			and not bool(tail[5]) and is_equal_approx(float(tail[2]), 40.0)
			and again.is_empty()
			and _ref_rules(again_said) == [Referee.SISTER] and born == [true]
			and twice == [false] and twice_said == [Referee.BODY] and bool(daughter[5])
			and is_equal_approx(float(ref.expected), Referee.DAUGHTER_RADIUS) and clean,
		"referee: an OUT at r40 is out of the water and still, a move while out stays"
		+ " put and fouls, a SISTER on the ring is taken, her mother's last OUT frame"
		+ " landing after her is no foul, a second SISTER and a second new body are,"
		+ " and the daughter is expected at r%.2f" % float(ref.expected))
	# Off the ring and the wrong size: put right, 2 points.
	var off := _ref_out_at_forty()
	var put := off.judge_sister(3.0, Vector2(700.0, 0.0), 35.0, true)
	var off_said := off.take_fouls()
	# Back in at r40 undivided, and a daughter with no sister ever.
	var undivided := _ref_out_at_forty()
	undivided.claim(3.0, Vector2.ZERO, 0.0, 40.0, Vector2.ZERO, 0.0, false)
	var undivided_said := _ref_rules(undivided.take_fouls())
	var orphan := _ref_out_at_forty()
	orphan.claim(3.0, Vector2.ZERO, 0.0, Referee.DAUGHTER_RADIUS, Vector2.ZERO, 0.0, false)
	var waited := orphan.take_fouls().is_empty()
	orphan.claim(3.0 + Referee.BIRTH_WAIT + 0.1, Vector2.ZERO, 0.0, Referee.DAUGHTER_RADIUS,
		Vector2.ZERO, 0.0, false)
	var orphan_said := _ref_rules(orphan.take_fouls())
	# A daughter fed before her SISTER lands: expected at what she was fed.
	var fed := _ref_out_at_forty()
	fed.claim(3.0, Vector2.ZERO, 0.0, Referee.DAUGHTER_RADIUS, Vector2.ZERO, 0.0, false)
	fed.ate()
	fed.claim(3.1, Vector2.ZERO, 0.0, Referee.DAUGHTER_RADIUS + 4.0, Vector2.ZERO, 0.0,
		false)
	fed.judge_sister(3.2, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS, true)
	fed.claim(3.3, Vector2.ZERO, 0.0, Referee.DAUGHTER_RADIUS + 4.0, Vector2.ZERO, 0.0,
		false)
	var fed_clean := fed.take_fouls().is_empty()
	_says(put.size() == 2 and is_equal_approx((put[0] as Vector2).length(),
				Referee.SISTER_DISTANCE)
			and is_equal_approx(float(put[1]), Referee.DAUGHTER_RADIUS)
			and _ref_rules(off_said) == [Referee.SISTER]
			and float(off_said[0][1]) == Referee.WEIGHT_SISTER_OFF
			and undivided_said == [Referee.OUT] and waited and orphan_said == [Referee.OUT]
			and fed_clean,
		"referee: a sister off the ring at r35 is put on it at r%.2f and fouls %.0f;"
		% [float(put[1]) if put.size() == 2 else 0.0,
			float(off_said[0][1]) if not off_said.is_empty() else 0.0]
		+ " back in undivided fouls; a daughter's frame waits %.0f s for her sister"
		% Referee.BIRTH_WAIT + " and fouls only then; one fed before her sister lands"
		+ " is expected at what she was fed")


## **The host's drop's rim, at its referee** (ocean.md §10.5): a claim past the
## rim is held at it -- a clamp, never a foul, since an honest guest's own run
## holds its cell there too -- and a sister the rim held back is taken where the
## guest's run put her, unfouled, when the same sister with no rim is fouled;
## one off the ring and off the rim is put on the ring, inside it, and fouled.
func _referee_rim() -> void:
	var centre := Vector2(1234.0, -567.0)
	var rim := FoodField.Drop.new(centre).meniscus
	# A claim 25 units past the edge, at walking pace.
	var edge := centre + Vector2(rim.radius - CellBody.BASE_RADIUS - 10.0, 0.0)
	var walker := _ref_arrived(0.0, edge)
	walker.set_rim(centre, rim.radius)
	var past := edge + Vector2(25.0, 0.0)
	var held: Array = walker.claim(0.3, past, 0.0, CellBody.BASE_RADIUS, Vector2(80.0, 0.0),
		0.0, false)
	var walker_said := walker.take_fouls()
	var at := held[0] as Vector2
	# A division 140 from the edge; her side of her mother is past the rim.
	var mother := centre + Vector2(rim.radius - 140.0, 0.0)
	var side := Vector2(0.6, 0.8)
	var kept := rim.contain(mother + side * Referee.SISTER_DISTANCE, Referee.DAUGHTER_RADIUS)
	var ref := _ref_near_rim(mother, centre, rim.radius)
	var taken := ref.judge_sister(3.0, kept, Referee.DAUGHTER_RADIUS, true)
	var taken_said := ref.take_fouls()
	var bare := _ref_near_rim(mother, centre, 0.0)
	bare.judge_sister(3.0, kept, Referee.DAUGHTER_RADIUS, true)
	var bare_said := _ref_rules(bare.take_fouls())
	# Off the ring and off the rim: 300 out, on her side.
	var stray := _ref_near_rim(mother, centre, rim.radius)
	var put := stray.judge_sister(3.0, mother + side * 300.0, Referee.DAUGHTER_RADIUS, true)
	var stray_said := stray.take_fouls()
	_says(walker_said.is_empty() and rim.inside(at, CellBody.BASE_RADIUS)
			and at.distance_to(rim.contain(past, CellBody.BASE_RADIUS)) < 0.01
			and taken.size() == 2 and (taken[0] as Vector2).distance_to(kept) < 0.01
			and taken_said.is_empty() and bare_said == [Referee.SISTER]
			and put.size() == 2 and (put[0] as Vector2).distance_to(kept) < 0.5
			and rim.inside(put[0], Referee.DAUGHTER_RADIUS)
			and _ref_rules(stray_said) == [Referee.SISTER]
			and float(stray_said[0][1]) == Referee.WEIGHT_SISTER_OFF,
		"referee, the drop: a claim %.0f past the rim is held %.1f inside it with %d"
		% [past.distance_to(centre) - rim.radius + CellBody.BASE_RADIUS,
			rim.radius - CellBody.BASE_RADIUS - at.distance_to(centre), walker_said.size()]
		+ " fouls; a sister the rim held back, %.0f from her mother, is taken there with"
		% kept.distance_to(mother) + " %d fouls (%s with no rim); one off the ring and"
		% [taken_said.size(), bare_said] + " the rim is put on the ring inside it and"
		+ " fouled %s" % [_ref_rules(stray_said)])


## A referee, its rim at [param centre] [param radius] across (0 for none),
## whose guest is at r40 and out of the water at [param at], from 2.5 s.
func _ref_near_rim(at: Vector2, centre: Vector2, radius: float) -> Referee:
	var ref := _ref_arrived(0.0, at)
	ref.set_rim(centre, radius)
	ref.credit_meals(4)
	ref.claim(2.0, at, 0.0, 40.0, Vector2.ZERO, 0.0, false)
	ref.claim(2.5, at, 0.0, 40.0, Vector2.ZERO, 0.0, true)
	return ref


## A referee whose guest is at r40 and out of the water at the origin, from 2.5 s.
func _ref_out_at_forty() -> Referee:
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	ref.credit_meals(4)
	ref.claim(2.0, Vector2.ZERO, 0.0, 40.0, Vector2.ZERO, 0.0, false)
	ref.claim(2.5, Vector2.ZERO, 0.0, 40.0, Vector2.ZERO, 0.0, true)
	return ref


## **A division the host never saw, and one whose daughter went before her
## sister landed** (found in review). A phone host frozen through the whole of
## a guest's out window -- an app switch, a call screen -- hears the division
## all at once when it wakes: the OUT frames, the SISTER and the new body in
## one frame, and a host takes events before state frames. And a SISTER lost on
## the way lands a resend later, by when the daughter it left can have been
## eaten. Neither is a foul, and each sister and daughter is taken.
func _referee_unseen() -> void:
	var born := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"stigma": 1}
	# Unseen: fed to r40 in the water, never seen out. On waking, the SISTER, her
	# mother's new body, then the newest state frames: the mother's last OUT
	# frames where she stopped -- 300 units on -- and the daughter's first.
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	ref.credit_meals(4)
	ref.claim(2.0, Vector2.ZERO, 0.0, 40.0, Vector2.ZERO, 0.0, false)
	ref.stalled(6.0)
	var stopped := Vector2(300.0, 0.0)
	var sister := ref.judge_sister(8.0, stopped + Vector2(0.0, 560.0),
		Referee.DAUGHTER_RADIUS, true)
	var renewed := ref.judge_person(8.0, true, born, born.keys(), true)
	var tail: Array = ref.claim(8.0, stopped, 0.0, 40.0, Vector2.ZERO, 0.0, true)
	var still: Array = ref.claim(8.05, stopped, 0.0, 40.0, Vector2.ZERO, 0.0, true)
	var daughter: Array = ref.claim(8.1, stopped, 0.0, Referee.DAUGHTER_RADIUS,
		Vector2.ZERO, 0.0, false)
	var unseen_clean := ref.take_fouls().is_empty()
	var unseen_expects := float(ref.expected)
	# And the same with no OUT frame left to land: the daughter's first frame next.
	var bare := _ref_arrived(0.0, Vector2.ZERO)
	bare.credit_meals(4)
	bare.claim(2.0, Vector2.ZERO, 0.0, 40.0, Vector2.ZERO, 0.0, false)
	bare.stalled(6.0)
	var bare_sister := bare.judge_sister(8.0, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS,
		true)
	var bare_renewed := bare.judge_person(8.0, true, born, born.keys(), true)
	var bare_daughter: Array = bare.claim(8.0, Vector2.ZERO, 0.0, Referee.DAUGHTER_RADIUS,
		Vector2.ZERO, 0.0, false)
	var bare_clean := bare.take_fouls().is_empty()
	# Still no SISTER below r40, or twice, or from a body not here.
	var second := bare.judge_sister(8.2, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS, true)
	var young := _ref_arrived(0.0, Vector2.ZERO)
	young.credit_meals(3)
	young.claim(2.0, Vector2.ZERO, 0.0, 38.0, Vector2.ZERO, 0.0, false)
	var at_38 := young.judge_sister(3.0, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS, true)
	var gone := _ref_arrived(0.0, Vector2.ZERO)
	gone.credit_meals(4)
	gone.claim(2.0, Vector2.ZERO, 0.0, 40.0, Vector2.ZERO, 0.0, false)
	var absent := gone.judge_sister(3.0, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS, false)
	var refused := _ref_rules(bare.take_fouls() + young.take_fouls() + gone.take_fouls())
	_says(sister.size() == 2 and renewed == [true] and not bool(tail[5])
			and (tail[0] as Vector2).distance_to(stopped) < 0.01
			and (still[0] as Vector2).distance_to(stopped) < 0.01 and bool(daughter[5])
			and is_equal_approx(unseen_expects, Referee.DAUGHTER_RADIUS) and unseen_clean
			and bare_sister.size() == 2 and bare_renewed == [true] and bool(bare_daughter[5])
			and bare_clean and second.is_empty() and at_38.is_empty() and absent.is_empty()
			and refused == [Referee.SISTER, Referee.SISTER, Referee.SISTER],
		"referee: a division the host never saw -- fed to r40, never seen out, its"
		+ " SISTER and new body heard before its OUT frames -- is taken with no foul:"
		+ " the sister placed, the daughter renewed and expected at r%.2f, and her"
		% unseen_expects + " mother's last OUT frames out of the water where she"
		+ " stopped; and with none left to land; but a second SISTER, one at r38, and"
		+ " one from a body not here are each fouled")
	# Owed: seen out, the daughter's first frame first -- her SISTER lost on the
	# way -- then the daughter eaten, then the resend and her new body.
	var owed := _ref_out_at_forty()
	owed.claim(3.0, Vector2.ZERO, 0.0, Referee.DAUGHTER_RADIUS, Vector2.ZERO, 0.0, false)
	owed.died(3.4)
	var late := owed.judge_sister(3.9, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS, false)
	var late_born := owed.judge_person(3.9, true, born, born.keys(), false)
	var owed_clean := owed.take_fouls().is_empty()
	var twice := owed.judge_sister(4.0, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS, false)
	var twice_said := _ref_rules(owed.take_fouls())
	var stale := _ref_out_at_forty()
	stale.claim(3.0, Vector2.ZERO, 0.0, Referee.DAUGHTER_RADIUS, Vector2.ZERO, 0.0, false)
	stale.died(3.4)
	var too_late := stale.judge_sister(3.4 + Referee.BIRTH_WAIT + 0.1, Vector2(0.0, 560.0),
		Referee.DAUGHTER_RADIUS, false)
	var too_late_said := _ref_rules(stale.take_fouls())
	_says(late.size() == 2 and (late[0] as Vector2).distance_to(Vector2(0.0, 560.0)) < 0.01
			and late_born == [true] and owed_clean and twice.is_empty()
			and twice_said == [Referee.SISTER] and too_late.is_empty()
			and too_late_said == [Referee.SISTER],
		"referee: a SISTER resent after her daughter was eaten is placed on the ring"
		+ " where her mother stopped, with no foul, within %.0f s of the death; a"
		% Referee.BIRTH_WAIT + " second one, or one later than that, is fouled")


## **Bodies** (the socket-free half of R7): a new body only in turn, the same
## tiers but for the gift, once, and every slot a gene it wears -- and the dead
## body every build describes after a death, never fouled.
func _referee_bodies() -> void:
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	var early := ref.judge_person(1.0, true, Catalogue.born(), Catalogue.born().keys(), true)
	var early_said := ref.take_fouls()
	var bigger := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1}
	var escalated := ref.judge_person(2.0, false, bigger, bigger.keys(), true)
	var escalated_said := _ref_rules(ref.take_fouls())
	var gifted := Catalogue.born().duplicate()
	gifted[&"ampulla"] = 1
	var gift := ref.judge_person(3.0, false, gifted, gifted.keys(), true)
	var gift_clean := ref.take_fouls().is_empty()
	var twice_gifted := gifted.duplicate()
	twice_gifted[&"stigma"] = 1
	var second := ref.judge_person(4.0, false, twice_gifted, twice_gifted.keys(), true)
	var second_said := _ref_rules(ref.take_fouls())
	var stray_slot := ref.judge_person(5.0, false, gifted, [&"cytostome", &"palp"], true)
	var twin_slot := ref.judge_person(6.0, false, gifted, [&"cytostome", &"cytostome"],
		true)
	var slots_said := _ref_rules(ref.take_fouls())
	# A gift placed over a slot an organ is still worn in: worn, with no slot.
	var over_slot := ref.judge_person(7.0, false, gifted,
		[&"ampulla", &"cirrus", &"flagellum"], true)
	var over_clean := ref.take_fouls().is_empty()
	_says(early == [false] and _ref_rules(early_said) == [Referee.BODY]
			and float(early_said[0][1]) == Referee.WEIGHT_BODY
			and escalated.is_empty() and escalated_said == [Referee.BODY]
			and gift == [false] and gift_clean and second.is_empty()
			and second_said == [Referee.BODY] and stray_slot.is_empty()
			and twin_slot.is_empty() and slots_said.size() >= 1 and over_slot == [false]
			and over_clean and ref.worn == gifted,
		"referee R7: a new body mid-life is taken as the old one and fouls %.0f points;"
		% (float(early_said[0][1]) if not early_said.is_empty() else 0.0)
		+ " a tier-3 mouth is refused; the gift is taken once and the second is"
		+ " refused; a slot naming what it does not wear, or one gene twice, is"
		+ " refused -- and a gift placed over a slot another organ is still worn in"
		+ " is taken")
	# **After a death, the dead body is described once more**: every protocol-4
	# build (+104 to +108) sends it between its ENTER and its ARRIVE. Never a foul.
	var dead_body := {&"cytostome": 3, &"cirrus": 2, &"flagellum": 1, &"palp": 1}
	var quirk := _ref_quirk(dead_body, true)
	# The same, when the dead body was a born one with its gift: it looks like a
	# gift, and the born body said after it is still the body, and the real gift
	# after that is still taken.
	var lookalike := Catalogue.born().duplicate()
	lookalike[&"stigma"] = 1
	var alike := _ref_quirk(lookalike, true)
	# And the stale body landing after the first frame, its resend late.
	var late := _ref_quirk(dead_body, false)
	_says(bool(quirk[0]) and bool(alike[0]) and bool(late[0]),
		"referee: the dead body every build describes after a death is never fouled"
		+ " -- %s; a dead body that looked like a gift: %s; landing late: %s"
		% [str(quirk[1]), str(alike[1]), str(late[1])])
	# More bodies than the budget, at once: the seventh is refused.
	var rate := Referee.new(0.0)
	var taken := 0
	for i in 8:
		if not rate.judge_person(0.0, true, Catalogue.born(), Catalogue.born().keys(),
				false).is_empty():
			taken += 1
	var rate_said := _ref_rules(rate.take_fouls())
	var refilled := rate.judge_person(1.0, true, Catalogue.born(), Catalogue.born().keys(), false)
	_says(taken == int(Referee.PERSON_BANK) and rate_said == [Referee.BODY]
			and refilled == [true],
		"referee: of eight bodies said at once, %d are taken and the rest foul" % taken
		+ " once; a second later the budget has room again")


## **The dead body, described after a death**, as every build does it: `[true
## if nothing fouled and the born body is what is worn, a note]`. [param early]
## puts the stale PERSON before the first state frame, as it lands.
func _ref_quirk(dead_body: Dictionary, early: bool) -> Array:
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	ref.judge_died(5.0, FoodField.Cause.STARVED, 0, true)
	ref.take_fouls()
	ref.judge_person(6.0, true, Catalogue.born(), Catalogue.born().keys(), false)
	ref.judge_enter(6.0, CellBody.BASE_RADIUS, false)
	ref.arrive(6.0, Vector2(480.0, 0.0), CellBody.BASE_RADIUS)
	if early:
		ref.judge_person(6.02, false, dead_body, dead_body.keys(), true)
	ref.claim(6.2, Vector2(480.0, 0.0), 0.0, CellBody.BASE_RADIUS, Vector2.ZERO, 0.0,
		false)
	if not early:
		ref.judge_person(6.25, false, dead_body, dead_body.keys(), true)
	ref.judge_person(6.3, false, Catalogue.born(), Catalogue.born().keys(), true)
	var clean := ref.take_fouls().is_empty() and ref.worn == Catalogue.born()
	# Its real gift, later, is still taken.
	var gifted := Catalogue.born().duplicate()
	gifted[&"ocellus"] = 1
	var gift := ref.judge_person(12.0, false, gifted, gifted.keys(), true)
	clean = clean and gift == [false] and ref.take_fouls().is_empty()
	return [clean, "no foul, worn %s" % str(ref.worn)]


## **Arrivals** (the socket-free half of R8): only with no body swimming here,
## at a body's size, as a born cell after a death, and not too often.
func _referee_arrivals() -> void:
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	var swimming := ref.judge_enter(1.0, 26.0, true)
	var swimming_said := ref.take_fouls()
	var ref2 := Referee.new(0.0)
	var big := ref2.judge_enter(1.0, 45.0, false)
	var small := ref2.judge_enter(1.6, 20.0, false)
	var sizes_said := _ref_rules(ref2.take_fouls())
	var waiting := ref2.judge_enter(2.0, 26.0, true)
	var ref3 := _ref_arrived(0.0, Vector2.ZERO)
	ref3.judge_died(1.0, FoodField.Cause.STARVED, 0, true)
	var not_born := ref3.judge_enter(2.0, 40.0, false)
	var not_born_said := _ref_rules(ref3.take_fouls())
	# It said DIED itself, so until a born cell arrives every ENTER must be one
	# (#102): a refusal does not spend the rule, where the first build let the
	# next one past.
	var next := ref3.judge_enter(2.1, 40.0, false)
	var born_next := ref3.judge_enter(2.2, 26.0, false)
	var ref4 := Referee.new(0.0)
	var taken := 0
	for i in 6:
		if ref4.judge_enter(1.0, 26.0, false):
			taken += 1
	var rate_said := _ref_rules(ref4.take_fouls())
	var later := ref4.judge_enter(1.0 + Referee.ENTER_EVERY, 26.0, false)
	# Six arrivals asked for and never made: the newest two are anchors, and a
	# first frame at the one before the newest is no foul.
	var chain := Referee.new(0.0)
	for i in 6:
		chain.judge_enter(4.0 * i, 26.0, i > 0)
		if i > 0:
			# What `_host_enter` does with a body that never arrived.
			chain.left(4.0 * i, 0.0, 0.0)
		chain.arrive(4.0 * i, Vector2(480.0, 0.0).rotated(0.5 * i), 26.0)
	var anchors: int = (chain.get("_anchors") as Array).size()
	chain.claim(20.05, Vector2(480.0, 0.0).rotated(2.0), 0.0, 26.0, Vector2.ZERO, 0.0, false)
	var chain_clean := chain.take_fouls().is_empty()
	_says(anchors == 2 and chain_clean,
		"referee: six arrivals asked for and never made keep %d anchors, the newest"
		% anchors + " two, and a first frame at the one before the newest is no foul")
	_says(not swimming and _ref_rules(swimming_said) == [Referee.ENTER]
			and float(swimming_said[0][1]) == Referee.WEIGHT_ENTER
			and not big and not small and sizes_said == [Referee.ENTER, Referee.ENTER]
			and waiting and not not_born and not_born_said == [Referee.ENTER] and not next
			and born_next and taken == int(Referee.ENTER_BANK) and rate_said == [Referee.ENTER]
			and later,
		"referee R8: an ENTER while swimming here is refused, %.0f point; r45 and"
		% (float(swimming_said[0][1]) if not swimming_said.is_empty() else 0.0)
		+ " r20 are refused; one while the last is still waiting is taken; after a"
		+ " death it said itself every one must be r26 until one arrives; %d at once are"
		% taken
		+ " taken and the rest refused until the budget refills")


## **Deaths** (the socket-free half of R9): only starving is the guest's own.
func _referee_deaths() -> void:
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	var starved := ref.judge_died(1.0, FoodField.Cause.STARVED, 0, true)
	var starved_clean := ref.take_fouls().is_empty()
	var ref2 := _ref_arrived(0.0, Vector2.ZERO)
	var eaten := ref2.judge_died(1.0, FoodField.Cause.SWALLOWED, FoodField.By.FRIEND, true)
	var eaten_said := ref2.take_fouls()
	var again := ref2.judge_died(1.1, FoodField.Cause.SWALLOWED, FoodField.By.WATER, false)
	_says(starved == [FoodField.Cause.STARVED, 0] and starved_clean
			and eaten == [FoodField.Cause.STARVED, 0]
			and _ref_rules(eaten_said) == [Referee.DIED]
			and float(eaten_said[0][1]) == Referee.WEIGHT_DIED and again.is_empty()
			and ref2.take_fouls().is_empty(),
		"referee R9: starving is taken as said; swallowed by the friend, said of a"
		+ " body still here, is reported as starving and fouls %.0f points; a death"
		% (float(eaten_said[0][1]) if not eaten_said.is_empty() else 0.0)
		+ " the host already made, said again, is nothing")


## **Shouts** (the socket-free half of R10): from where it swims, at its size,
## reaching what it wears, as often as that calls.
func _referee_shouts() -> void:
	var worn := Catalogue.born().duplicate()
	worn[&"ampulla"] = 1
	var ref := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, worn)
	var honest := ref.judge_shout(1.0, Vector2(0.0, -20.0), 26.0, 1100.0, true)
	var far := ref.judge_shout(1.1, Vector2(3000.0, 0.0), 26.0, 1100.0, true)
	var reach := ref.judge_shout(1.6, Vector2.ZERO, 26.0, 1500.0, true)
	var shouts_said := _ref_rules(ref.take_fouls())
	var ref2 := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, worn)
	var big := ref2.judge_shout(1.0, Vector2.ZERO, 36.0, 1100.0, true)
	var big_said := _ref_rules(ref2.take_fouls())
	# Where it swam in the last seconds counts, not only where it is now: a call
	# resent after a loss lands behind frames sent after it.
	var ref3 := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, worn)
	var at := Vector2.ZERO
	for i in 30:
		ref3.claim(0.1 + 0.05 * float(i), at, 0.0, 26.0, Vector2(900.0, 0.0), 0.0, false)
		at += Vector2(45.0, 0.0)
	var behind := ref3.judge_shout(1.6, Vector2(100.0, 0.0), 26.0, 1100.0, true)
	var behind_clean := ref3.take_fouls().is_empty()
	# As often as it calls: two banked and one for the arrival, then one each
	# period less a second.
	var ref4 := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, worn)
	var heard := 0
	for i in 5:
		if ref4.judge_shout(1.0, Vector2.ZERO, 26.0, 1100.0, true):
			heard += 1
	var rate_said := _ref_rules(ref4.take_fouls())
	var later := ref4.judge_shout(1.0 + Stats.at(&"ping_period", 1), Vector2.ZERO, 26.0,
		1100.0, true)
	# Alone, not in the water here: only the rate.
	var ref5 := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, worn)
	var alone := ref5.judge_shout(1.0, Vector2(9000.0, 0.0), 33.0, 1900.0, false)
	# **A call reaching nothing**, which every build sends on coming back from the
	# black having worn an organ (its water pulses on the dead cell's period with
	# the born body's reach): not heard, not charged, never a foul.
	var ref6 := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, Catalogue.born())
	var bank := float(ref6.shouts.tokens)
	var organless := ref6.judge_shout(1.0, Vector2.ZERO, 26.0, 0.0, true)
	var organless_clean: bool = ref6.take_fouls().is_empty() \
		and is_equal_approx(float(ref6.shouts.tokens), bank)
	_says(honest and not far and not reach
			and shouts_said == [Referee.SHOUT, Referee.SHOUT] and not big
			and big_said == [Referee.SHOUT] and behind and behind_clean and heard == 3
			and rate_said == [Referee.SHOUT] and later and alone and not organless
			and organless_clean,
		"referee R10: a call from where it swims is heard; one from 3,000 units off,"
		+ " one reaching 1,500 with a tier-1 organ and one at r36 are not; a call from"
		+ " 1,200 units back along the last second's path is; %d at once are heard" % heard
		+ " and the rest refused until the organ's period; alone, only the rate; and a"
		+ " call reaching nothing -- sent on every return from the black -- is dropped"
		+ " uncharged and unfouled")


## **The re-entry wound rule, both ways** (the owner's decision): on, a body
## back inside 30 s is the old one continued; off, every arrival is fresh.
func _referee_reentry() -> void:
	var results := {}
	for keeps: bool in [true, false]:
		var ref := Referee.new(0.0)
		ref.reentry_keeps_wound = keeps
		var first := _ref_enter(ref, 0.0)
		ref.claim(0.1, Vector2.ZERO, 0.0, 26.0, Vector2.ZERO, 0.0, false)
		ref.left(10.0, 0.5, 30.0)
		var soon := _ref_enter(ref, 20.0)
		ref.claim(20.1, Vector2.ZERO, 0.0, 26.0, Vector2.ZERO, 0.0, false)
		ref.left(30.0, 0.5, 30.0)
		var late := _ref_enter(ref, 61.0)
		ref.claim(61.1, Vector2.ZERO, 0.0, 26.0, Vector2.ZERO, 0.0, false)
		ref.died(70.0)
		var reborn := _ref_enter(ref, 75.0)
		# That one never arrives -- no frame put it in the water -- and is asked
		# for again: it keeps what it was granted.
		ref.left(76.0, 0.0, 41.0)
		var asked_again := _ref_enter(ref, 78.0)
		ref.claim(78.1, Vector2.ZERO, 0.0, 26.0, Vector2.ZERO, 0.0, false)
		ref.left(100.0, 0.4, 10.0)
		var kept := _ref_enter(ref, 105.0)
		ref.left(106.0, 0.4, 5.0)
		var kept_again := _ref_enter(ref, 108.0)
		results[keeps] = [first, soon, late, reborn, asked_again, kept, kept_again]
	var on: Array = results[true]
	var off: Array = results[false]
	var mended := CellBody.mended(0.5, 10.0)
	var ok_on: bool = (on[0] as Array).is_empty() and (on[1] as Array).size() == 2 \
		and is_equal_approx(float(on[1][0]), mended) and is_equal_approx(float(on[1][1]), 20.0) \
		and (on[2] as Array).is_empty() and (on[3] as Array).is_empty() \
		and (on[4] as Array).is_empty() and (on[5] as Array).size() == 2 \
		and is_equal_approx(float(on[5][1]), 5.0) and (on[6] as Array).size() == 2 \
		and is_equal_approx(float(on[6][1]), 2.0) \
		and is_equal_approx(float(on[6][0]), CellBody.mended(0.4, 8.0))
	var ok_off := true
	for each: Array in off:
		if not each.is_empty():
			ok_off = false
	_says(ok_on and ok_off,
		"referee: re-entry on -- back 10 s after leaving with wound 0.50 and 30 s of"
		+ " grace, the body keeps wound %.3f and %.0f s of grace; fresh after"
		% [float(on[1][0]) if (on[1] as Array).size() == 2 else -1.0,
			float(on[1][1]) if (on[1] as Array).size() == 2 else -1.0]
		+ " 31 s away, after a death, and for a connection's first; an arrival that"
		+ " never happened, asked again, keeps its grant. Off -- every arrival fresh")


## An ENTER at [param now], taken and put at the origin: what `arrive` said.
func _ref_enter(ref: Referee, now: float) -> Array:
	ref.judge_enter(now, CellBody.BASE_RADIUS, false)
	return ref.arrive(now, Vector2.ZERO, CellBody.BASE_RADIUS)


## **A rule fouls at most once each half second**, however many frames break
## it; and a host stall hands every budget the gap.
func _referee_once() -> void:
	var ref := _ref_arrived(0.0, Vector2.ZERO)
	for i in 10:
		ref.claim(1.0 + 0.03 * float(i), Vector2.ZERO, 0.0, 36.0, Vector2.ZERO, 0.0, false)
	var burst := ref.take_fouls().size()
	ref.claim(1.0 + Referee.FOUL_EVERY + 0.05, Vector2.ZERO, 0.0, 36.0, Vector2.ZERO, 0.0,
		false)
	var next := ref.take_fouls().size()
	var called := int(ref.called[Referee.SIZE])
	var stalled := _ref_arrived(0.0, Vector2.ZERO)
	stalled.claim(3.0, Vector2.ZERO, 0.0, 26.0, Vector2.ZERO, 0.0, false)
	stalled.stalled(3.0)
	stalled.claim(3.05, Vector2(2000.0, 0.0), 0.0, 26.0, Vector2.ZERO, 0.0, false)
	var stall_clean := stalled.take_fouls().is_empty()
	var steady := _ref_arrived(0.0, Vector2.ZERO)
	steady.claim(3.0, Vector2.ZERO, 0.0, 26.0, Vector2.ZERO, 0.0, false)
	steady.claim(3.05, Vector2(2000.0, 0.0), 0.0, 26.0, Vector2.ZERO, 0.0, false)
	var steady_said := _ref_rules(steady.take_fouls())
	_says(burst == 1 and next == 1 and called == 11 and stall_clean
			and steady_said == [Referee.MOVE],
		"referee: ten radius lies in 0.3 s are one foul and the next half second's"
		+ " another (%d called); 2,000 units after a 3 s host stall is no foul, and"
		% called + " without the stall it is")


## **The gaps the full read of game/net found, shut** (#102): each one a rule a
## modified guest could step round for a point or none. A new body said behind
## its ENTER does not renew the arrival; a birth is said at once or not at all;
## the born-cell rule outlives a refused ENTER; a call is held to what a body and
## an organ can be, in the water or out; a body earns one shout bonus however
## often it is said; the last body's reach counts only while its calls can
## still be landing; and a sister's place is bounded when her mother's stop was
## never seen, and found on the ring even from 1e20 units off.
func _referee_gaps() -> void:
	var born := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"stigma": 1}
	# A new body behind its ENTER: its tiers taken, no renew, no foul.
	var behind := Referee.new(0.0)
	behind.judge_enter(0.0, CellBody.BASE_RADIUS, false)
	behind.arrive(0.0, Vector2.ZERO, CellBody.BASE_RADIUS)
	var behind_said := behind.judge_person(0.1, true, born, born.keys(), true)
	var behind_clean := behind.take_fouls().is_empty()
	# A birth: said at once, renewed; held back past BIRTH_WAIT, out of turn.
	var birth := _ref_out_at_forty()
	birth.judge_sister(3.0, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS, true)
	var at_once := birth.judge_person(3.0, true, born, born.keys(), true)
	var at_once_clean := birth.take_fouls().is_empty()
	var held := _ref_out_at_forty()
	held.judge_sister(3.0, Vector2(0.0, 560.0), Referee.DAUGHTER_RADIUS, true)
	var held_back := held.judge_person(3.0 + Referee.BIRTH_WAIT + 1.0, true, born,
		born.keys(), true)
	var held_said := _ref_rules(held.take_fouls())
	# After its own death -- it said DIED -- an ENTER at r40 is refused, and so
	# is the next: the rule is not spent by a refusal. Then a born cell's.
	var reborn := _ref_arrived(0.0, Vector2.ZERO)
	reborn.judge_died(1.0, FoodField.Cause.STARVED, 0, true)
	var big_first := reborn.judge_enter(2.0, CellBody.DIVIDE_RADIUS, false)
	var big_again := reborn.judge_enter(3.0, CellBody.DIVIDE_RADIUS, false)
	var as_born := reborn.judge_enter(4.0, CellBody.BASE_RADIUS, false)
	var reborn_said := _ref_rules(reborn.take_fouls())
	# After a death the host made, only the first need be a born cell's: a guest
	# that left the water as it was killed never heard the kill, comes back as
	# the body it still is, and must not be locked out.
	var killed := _ref_arrived(0.0, Vector2.ZERO)
	killed.died(1.0)
	var killed_first := killed.judge_enter(2.0, 35.0, false)
	var killed_again := killed.judge_enter(3.0, 35.0, false)
	var killed_said := _ref_rules(killed.take_fouls())
	# A call no body could make, from a guest with no body here; then an honest
	# one from the biggest body with the farthest organ.
	var worn := Catalogue.born().duplicate()
	worn[&"ampulla"] = 1
	var caller := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, worn)
	var huge := caller.judge_shout(1.0, Vector2.ZERO, 3.0e38, 3.0e38, false)
	var huge_said := _ref_rules(caller.take_fouls())
	var reach_max: float = Stats.at(&"ping_range", Stats.table(&"ping_range").size() - 1)
	var biggest := caller.judge_shout(2.0, Vector2(9000.0, 0.0), CellBody.DIVIDE_RADIUS,
		reach_max, false)
	var biggest_clean := caller.take_fouls().is_empty()
	# A new body said twice a second for 30 s with no body here, and a call
	# after each: what the organ calls, and one bonus -- not one a body.
	var farm := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, worn)
	farm.left(0.5, 0.0, 0.0)
	var farmed := 0
	for i in 60:
		var t := 1.0 + 0.5 * float(i)
		farm.judge_person(t, true, worn, worn.keys(), false)
		if farm.judge_shout(t, Vector2.ZERO, 26.0, 1100.0, false):
			farmed += 1
	farm.take_fouls()
	var calls_itself := int(Referee.SHOUT_BANK) + 2 \
		+ int(30.0 / (Stats.at(&"ping_period", 1) - Referee.SHOUT_EARLY))
	# The last body's reach: while its calls may still be landing, and no longer.
	var three := Catalogue.born().duplicate()
	three[&"ampulla"] = 3
	var old := _ref_arrived(0.0, Vector2.ZERO, CellBody.BASE_RADIUS, three)
	old.died(1.0)
	old.judge_person(1.5, true, Catalogue.born(), Catalogue.born().keys(), false)
	old.judge_enter(1.5, CellBody.BASE_RADIUS, false)
	old.arrive(1.5, Vector2.ZERO, CellBody.BASE_RADIUS)
	old.claim(1.6, Vector2.ZERO, 0.0, CellBody.BASE_RADIUS, Vector2.ZERO, 0.0, false)
	var landing := old.judge_shout(2.0, Vector2.ZERO, CellBody.BASE_RADIUS, reach_max, true)
	var long_after := old.judge_shout(1.5 + Referee.SHOUT_PAST + 1.0, Vector2.ZERO,
		CellBody.BASE_RADIUS, reach_max, true)
	var old_said := _ref_rules(old.take_fouls())
	# A division never seen, her sister said 1e30 units off: put where her
	# mother could have swum to since her last frame, and fouled.
	var flung := _ref_arrived(0.0, Vector2.ZERO)
	flung.credit_meals(4)
	flung.claim(2.0, Vector2.ZERO, 0.0, CellBody.DIVIDE_RADIUS, Vector2.ZERO, 0.0, false)
	var thrown := flung.judge_sister(2.5, Vector2(-2.0e30, 3.0e30), Referee.DAUGHTER_RADIUS,
		true)
	var thrown_said := _ref_rules(flung.take_fouls())
	var could := Referee.SISTER_DISTANCE + Referee.SISTER_RING + Referee.MOVE_HOLD \
		+ Referee.MOVE_SLACK
	var thrown_ok := thrown.size() == 2 and (thrown[0] as Vector2).is_finite() \
		and (thrown[0] as Vector2).length() <= could + 1.0
	# A division seen, her sister said 1e20 units off: on the ring, not on her
	# mother -- float32 squares that distance to inf.
	var ring := _ref_out_at_forty()
	var off_ring := ring.judge_sister(3.0, Vector2(1.0e20, 0.0), Referee.DAUGHTER_RADIUS, true)
	var ring_ok := off_ring.size() == 2 \
		and (off_ring[0] as Vector2).distance_to(Vector2(Referee.SISTER_DISTANCE, 0.0)) < 0.01
	_says(behind_said == [false] and behind_clean and at_once == [true] and at_once_clean
			and held_back == [false] and held_said == [Referee.BODY],
		"referee R11: a new body said behind its ENTER takes its tiers but renews"
		+ " nothing -- the arrival's wound and grace stand -- and a daughter said at"
		+ " her SISTER is renewed, where one held back %.0f s is out of turn"
		% (Referee.BIRTH_WAIT + 1.0))
	_says(not big_first and not big_again and as_born
			and reborn_said == [Referee.ENTER, Referee.ENTER] and not killed_first
			and killed_again and killed_said == [Referee.ENTER],
		"referee R12: after a death it said itself, an ENTER at r40 is refused, and so"
		+ " is the next -- a refusal does not spend the born-cell rule -- and one at"
		+ " r26 is taken; after a death the host made, the second is taken, so a guest"
		+ " that left as it was killed is never locked out")
	_says(not huge and huge_said == [Referee.SHOUT] and biggest and biggest_clean
			and farmed <= calls_itself and landing and not long_after
			and old_said == [Referee.SHOUT],
		"referee R13: a call at r3e38 reaching 3e38 from a guest with no body here is"
		+ " refused and fouled, where r40 reaching %.0f is heard; a new body said" % reach_max
		+ " twice a second for 30 s buys %d calls, not one each (at most %d); and the"
		% [farmed, calls_itself] + " last body's reach is heard %.0f s after it and" % 0.5
		+ " refused %.0f s after" % (Referee.SHOUT_PAST + 1.0))
	_says(thrown_ok and thrown_said == [Referee.SISTER] and ring_ok,
		"referee R14: an unseen division's sister said 3e30 units off is put %.0f"
		% ((thrown[0] as Vector2).length() if thrown.size() == 2 else -1.0)
		+ " from her mother's last place, within the %.0f she could swim, and" % could
		+ " fouled; a seen one's said 1e20 off is put on the ring at %.0f, not on her"
		% Referee.SISTER_DISTANCE + " mother")


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
	# some machines and about nothing on others. And it keeps no drop: the
	# game's default is the player's own file (ocean.md §9).
	run.mode = 1
	run.keep = ""
	run.library_at = ""
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
		# **The law it is heard by**, which is the echo's own over the path the
		# call actually crossed: one way, 366 units of water surface to surface
		# (issue #45). An echo off a body there would have gone out and back.
		# The tolerance is a few units of the cell's drift inside one frame.
		var want := FoodField.ping_level(SHOUT_FROM.length() - 34.0, 1100.0)
		_says(absf(float(mark["strength"]) - want) < 0.005,
			"and its level is food.gd's ping_level over the one-way path"
			+ " (%.3f, law %.3f)" % [float(mark["strength"]), want])

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

	# **One way, so twice as far** (issue #45). A call crosses the water once
	# where her echoes cross it twice, so it carries to twice the reach her own
	# echoes come home from: 1,766 units is past a tier-1 echo's 1,100 and well
	# inside the call's 2,200, where it lands at about 0.35.
	marks.clear()
	other.shout(Vector2(0.0, -1800.0), 34.0, 1100.0)
	await _hold(cell, Vector2.ZERO, PI * 0.5, 0.5)
	# On the shout's own bearing, so none of this cell's echoes can pass it.
	var far := not marks.is_empty() \
		and absf(angle_difference(float(marks[0]["bearing"]), -PI * 0.5)) < 0.01
	_says(far, "a shout from past the shouter's echo reach but inside twice it"
		+ " is heard (%.3f)" % (float(marks[0]["strength"]) if far else 0.0))

	# Even inside that, a call the water has taken down to `PING_SILENT` is not
	# played, which is the rule `_cast_ping` keeps for an echo. One unit short
	# of 2,200 it would land at 0.009; it turns audible about six units nearer.
	marks.clear()
	other.shout(Vector2(0.0, -2233.0), 34.0, 1100.0)
	await _hold(cell, Vector2.ZERO, PI * 0.5, 0.5)
	_says(marks.is_empty(),
		"a shout the water has taken to PING_SILENT or below is not played")

	# Out of earshot: past twice the shouter's reach, nothing is heard at all.
	marks.clear()
	other.shout(Vector2(0.0, -4000.0), 34.0, 1100.0)
	await _hold(cell, Vector2.ZERO, PI * 0.5, 0.5)
	_says(marks.is_empty(),
		"a shout from beyond twice the shouter's reach is not heard")

	# **A call no body could make** (#102), from the host -- over whose calls a
	# guest has no referee: as big as a float and reaching as far, it is heard
	# as the biggest honest call, and its mark held no longer than one.
	marks.clear()
	other.shout(SHOUT_FROM, 3.0e38, 3.0e38)
	await _hold(cell, Vector2.ZERO, PI * 0.5, 0.5)
	var longest := FoodField.PING_RING * 2.0 * CellBody.DIVIDE_RADIUS / FoodField.PING_SPEED
	var capped := not marks.is_empty() and float(marks[0]["hold"]) <= longest + 1e-4 \
		and float(marks[0]["strength"]) <= 1.0
	_says(capped, "a call at r3e38 reaching 3e38 is held as the biggest honest one:"
		+ " %.2f s, where r%.0f's is %.2f s" % [float(marks[0]["hold"]) if not marks.is_empty()
			else -1.0, CellBody.DIVIDE_RADIUS, longest])

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
	var ladder := Stats.table(&"impulse_speed")
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
	blind.keep = ""
	blind.library_at = ""
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
# time, and no frame of CI's 24000 is spent on it. The global stream is seeded
# before every field, so a failure here is the same failure on every machine.
#
# Every field is a [WatchedFood], which counts any seed, retirement or meal
# that touches the person's slot -- the one thing §1.2 says can never happen to
# a person -- and the last check below is that nothing did, across everything
# the section put the water through. **Since pack 2 the host's water divides**
# (docs/design/lineage.md §8), and a guest's mirror is held to that too: a
# mother leaves it and her two daughters arrive, by id, with no new message.
# ---------------------------------------------------------------------------

const POND_STEP := 1.0 / 60.0
## **The organ the pond's checks armour a body with**: the first live one that provides
## armour. A check asks for a mechanic by its stat, never a gene by name, so retiring
## one organ that provides armour moves these checks to the next, as the referee's
## rules move. `&""` once none does, and a check that needs an armoured body says so
## first ([constant NO_ARMOUR]).
static var ARMOUR: StringName = Catalogue.first_provider(&"armor")
## What a check that poses an armoured body says first, when nothing provides armour.
const NO_ARMOUR := "no live organ provides armour, which this check poses its body with -- "
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

	# cell.gd reads the beam's level and path off its genome
	# (beam-levels.md); a hand-built cell has no levels, so its level is its
	# tier, exactly as the beam read it before levels existed.
	func level_of(gene: StringName) -> int:
		return tier(gene)

	func path_of(_gene: StringName) -> StringName:
		return &""

	# cell.gd finds the organ a mechanic with a place acts from in the body's
	# slots (gene-catalogue.md §5.2); a hand-built cell wears its organs in none
	# it knows, so the catalogue's order answers, as it did before there were
	# seats.
	func body_layout() -> Array[StringName]:
		return []


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

	# **The drop's doors** (ocean.md §10.2): a body made into a person's slot,
	# or one leaving it as water, is the same thing happening to a person.
	func _spawn(at: Vector2, drifter: bool, sensed: float, fill := false,
			body_radius := 0.0, tiers := {}, mine := -1.0) -> int:
		var index: int = super._spawn(at, drifter, sensed, fill, body_radius, tiers, mine)
		if _pond and _is_person_slot(index):
			touched_person += 1
		return index

	func _drop_lose(index: int, cause: int) -> void:
		if _pond and _is_person_slot(index):
			touched_person += 1
		super._drop_lose(index, cause)


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
	_pond_replay_field()
	_drop_pond_rules()
	_drop_pond_anchors()
	_drop_pond_mirror()
	_drop_pond_kept()
	_drop_pond_births()
	var touched := 0
	for field: Node in _pond_fields:
		touched += int(field.get("touched_person"))
	_says(touched == 0 and _pond_fields.size() >= 14,
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
	field.touch_range = Stats.at(&"touch_range", mini(cell.extra(&"palp"), 3))
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
	field.dosed.connect(func(b: float, kind: int, stacks: float, meal: bool) -> void:
		said.append(["dosed", b, kind, stacks, meal]))
	return said


func _pond_said(said: Array, kind: String, what: int = -1) -> Array:
	for entry: Array in said:
		if entry[0] == kind and (what < 0 or int(entry[1]) == what):
			return entry
	return []


## **[param stacks] are a dose of [param n], as a body in the water holds it a
## step later**: a body's loads are the water's to wear, so they may have worn
## for the one step since the dose went in -- and by no more than that.
func _pond_worn(stacks: float, n: float) -> bool:
	return stacks <= n \
		and stacks >= n * exp(-POND_STEP / CellBody.DOSE_TAU_BY_KIND[0]) - 1e-9


## The heading that points a body at [param from] toward [param to].
func _pond_face(from: Vector2, to: Vector2) -> float:
	var v := to - from
	return atan2(v.x, -v.y)


## `food.gd`'s own flank angle, worked out here from the outside.
func _pond_flank(heading: float, target: Vector2, mouth: Vector2) -> float:
	var v := mouth - target
	return absf(angle_difference(heading, atan2(v.x, -v.y)))


## Water slot [param i], made into a calm body of [param radius] wearing
## [param tiers] at [param at], facing [param heading]. **In the drop** a new
## body, with an id of its own, comes into that slot by the drop's own door
## (`pose_at`), and is filed where it is: a body written by hand over another
## would keep that one's id, and the guest's mirror its genome.
func _pond_pose(field: Node, i: int, radius: float, tiers: Dictionary,
		at: Vector2, heading: float) -> Object:
	if field.owns_drop():
		field.pose_at(i, at, radius, tiers)
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
	if field.owns_drop():
		# Fed, and resting on nothing: a posed body neither starves nor dashes.
		b.hunger = 0.0
		field.refresh(i)
	return b


## Water slot [param i] out of the water: retired in today's water, taken out
## of the drop by its own bookkeeping there.
func _pond_retire(field: Node, i: int) -> void:
	if field.owns_drop():
		field.take_out(i)
	else:
		field.call("_retire", i)


## **Every water body but [param keep_id] coming for the person in [param slot]**,
## taken out of [param field]: for a check about whose hunter one posed body is,
## in a room whose own hunters swim (automation.md §5.3).
func _pond_spare(field: Node, slot: int, keep_id: int) -> void:
	var bodies: Array = field.bodies()
	var p: Object = (bodies[slot] as Object).get("person")
	if p == null:
		return
	for i in bodies.size():
		var b: Object = bodies[i]
		if not bool(b.seeded) or bool(b.inert) or b.person != null or int(b.id) == keep_id:
			continue
		if bool(field.call(&"_coming_for_player", b, p)):
			_pond_retire(field, i)


## ...on a run at the person, committed -- the one in [param slot], on a
## dedicated host that has two -- and with nothing of the chase the slot last
## ran carried into this one.
func _pond_hunt(field: Node, b: Object, slot: int = FoodField.PERSON_SLOT) -> void:
	var pb: Object = field.bodies()[slot]
	b.state = FoodField.State.STALK
	b.target = slot
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
	var gape := CellBody.gape_of({&"cytostome": 3}, 30.0)
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
	# commit to them yet -- only bites. Astern, through two tiers of armour and
	# into two of veneneux, so every term of the bite is in the number, and the
	# person's poison goes into the biter as stacks (dna-slots.md §7).
	field = _pond_rig(12, 30.0, POND_SENSES)
	field.open_pond()
	var armoured := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		ARMOUR: 2, &"veneneux": 2}
	_pond_person(field, at, 28.0, armoured)
	said = _pond_listen(field)
	from = at + Vector2(0.0, 54.0)
	b = _pond_pose(field, 5, 30.0, hunter_genes, from, _pond_face(from, at))
	field._process(POND_STEP)
	var bit := _pond_said(said, "touched", FoodField.Contact.BITTEN)
	var person: Object = field.bodies()[FoodField.PERSON_SLOT]
	var expected := 0.0
	if not bit.is_empty():
		expected = CellBody.bite_damage(Stats.at(&"bite", 3), gape, 28.0, Stats.at(&"armor", 2),
			_pond_flank(0.0, at, bit[2] as Vector2))
	# The poison is the stacks the table gives, worn for at most the one step the
	# body may have taken since; nothing yet in its wound but what that step wore.
	var poison_n := Stats.at(&"poison_stacks", 2)
	var taken := float((b.loads as PackedFloat64Array)[0])
	_says(field.person() != null and _pond_said(said, "died").is_empty()
			and not bit.is_empty() and 28.0 * Stats.at(&"armor", 2) < gape,
		"pond-field: an uncommitted cell whose gape fits them only bites")
	_says(not bit.is_empty() and absf(float(person.wound) - expected) < 1e-9
			and expected > 0.0 and taken <= poison_n
			and taken >= poison_n * exp(-POND_STEP / CellBody.DOSE_TAU_BY_KIND[0]) - 1e-9
			and float(b.wound) < 0.001
			and is_equal_approx(float(bit[3]), clampf(expected
				/ Stats.at(&"bite", 3), FoodField.BITE_HIT_FLOOR, 1.0)),
		("" if ARMOUR != &"" else NO_ARMOUR)
		+ "pond-field: the chew is bite_damage for that gape, armour and flank"
		+ " (%.5f, astern), and the biter takes %.3f stacks of their poison, its"
		% [float(person.wound), taken] + " wound %.5f" % float(b.wound))

	# Committed, and they are poisonous: swallowed as anyone is -- nobody is spat
	# out any more -- and the cell that ate them takes the swallow's dose, and
	# lives on with it (dna-slots.md §7.1, owner's row 5).
	field = _pond_rig(13, 30.0, POND_SENSES)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"flagellum": 1,
		&"veneneux": 1})
	said = _pond_listen(field)
	from = at + Vector2(0.0, -54.0)
	b = _pond_pose(field, 5, 30.0, hunter_genes, from, _pond_face(from, at))
	_pond_hunt(field, b)
	var serial := int(b.serial)
	# What the cell that ate them carries **when the death is told**: the dose goes
	# in first. Read then, because later in the same step today's water culls it
	# with the rest of what the person anchored (`_step_pond`): out here, 3,000
	# from the host, nobody is left to keep it.
	var at_death: Array = []
	field.person_died.connect(func(_cause: int, _by: int, _at: Vector2) -> void:
		at_death.append([int(b.serial), bool(b.seeded),
			float((b.loads as PackedFloat64Array)[0])]))
	field._process(POND_STEP)
	died = _pond_said(said, "died")
	var swallow_n := Stats.at(&"swallow_stacks", 1)
	var dosed := float(at_death[0][2]) if at_death.size() == 1 else 0.0
	_says(field.person() == null and not died.is_empty()
			and int(died[1]) == FoodField.Cause.SWALLOWED
			and int(died[2]) == FoodField.By.WATER
			and _pond_said(said, "touched", FoodField.Contact.STUNG).is_empty()
			and at_death.size() == 1 and int(at_death[0][0]) == serial
			and bool(at_death[0][1]) and dosed == swallow_n,
		"pond-field: a committed cell that swallows a poisonous person eats them --"
		+ " SWALLOWED by the water -- and carries %.2f stacks of their poison when the"
		% dosed + " death is told, alive")


# --- §1.3, the last row: one player's mouth on the other ---------------------

func _pond_friends() -> void:
	# This cell, a tier-3 mouth (gape 42), nose to the person's tail.
	var gape := CellBody.gape_of({&"cytostome": 3}, 30.0)
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
		ARMOUR: 3})
	said = _pond_listen(field)
	field._process(POND_STEP)
	var person: Object = field.bodies()[FoodField.PERSON_SLOT]
	var expected := CellBody.bite_damage(Stats.at(&"bite", 3), gape, 28.0, Stats.at(&"armor", 3),
		_pond_flank(0.0, at, Vector2.ZERO))
	var felt := _pond_said(said, "bitten")
	var chewed := _pond_said(said, "touched", FoodField.Contact.BITTEN)
	_says(field.person() != null and 28.0 * Stats.at(&"armor", 3) > gape
			and absf(float(person.wound) - expected) < 1e-9 and not felt.is_empty()
			and not chewed.is_empty() and int(chewed[4]) == FoodField.By.FRIEND,
		("" if ARMOUR != &"" else NO_ARMOUR)
		+ "pond-field: armoured past this gape, the friend is chewed instead"
		+ " (%.5f from astern) and this cell feels its own bite" % float(person.wound))

	# And the other way: their mouth on this cell, which is too big for it.
	var field2 := _pond_rig(23, 30.0, mouth, Vector2.ZERO, PI)
	field2.open_pond()
	_pond_person(field2, at, 28.0, {&"cytostome": 1, &"cirrus": 1,
		&"flagellum": 1}, PI)
	said = _pond_listen(field2)
	field2._process(POND_STEP)
	var cell: Object = field2.get("_cell")
	var their_gape := CellBody.gape_of({&"cytostome": 1}, 28.0)
	var theirs := CellBody.bite_damage(Stats.at(&"bite", 1), their_gape, 30.0,
		Stats.at(&"armor", 0), absf(cell.bearing_to(at)))
	var hit := _pond_said(said, "bitten")
	var told := _pond_said(said, "touched", FoodField.Contact.BITTEN)
	_says(field2.person() != null and 30.0 > their_gape
			and absf(float(cell.wound) - theirs) < 1e-9 and not hit.is_empty()
			and not told.is_empty()
			and is_equal_approx(float(told[3]), clampf(theirs
				/ Stats.at(&"bite", 3), FoodField.BITE_HIT_FLOOR, 1.0)
				* FoodField.BITE_FELT_SHARE),
		"pond-field: and the friend's mouth chews this cell back (%.5f, astern),"
		% float(cell.wound) + " each side feeling its own share")

	# **Each bite carries its toxins, each way** (dna-slots.md §7.2). This cell's
	# front venom rides its bite into the friend -- whatever their armour -- and
	# their poison comes back into this cell: one bite, two doses. This cell's
	# loads are the run's, and exact; the friend's are the water's to wear
	# ([method _pond_worn]).
	var venom := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1, &"toxicyst": 2}
	var venom_n := Stats.at(&"venom_stacks", 2)
	var poison_n := Stats.at(&"poison_stacks", 2)
	var fired: Array = []
	field = _pond_rig(24, 30.0, venom)
	field.toxins = FoodField.toxins_of(venom,
		[&"cytostome", &"cirrus", &"flagellum", &"toxicyst"])
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		ARMOUR: 3, &"veneneux": 2})
	said = _pond_listen(field)
	field.toxin_fired.connect(func(how: int) -> void: fired.append(how))
	field._process(POND_STEP)
	var mine: Object = field.get("_cell")
	var friend: Object = field.bodies()[FoodField.PERSON_SLOT]
	var into_them := float((friend.loads as PackedFloat64Array)[0])
	var into_me := float((mine.loads as PackedFloat64Array)[0])
	var dose := _pond_said(said, "dosed")
	_says(field.person() != null
			and not _pond_said(said, "touched", FoodField.Contact.BITTEN).is_empty()
			and _pond_worn(into_them, venom_n) and into_me == poison_n
			and not dose.is_empty() and float(dose[3]) == poison_n and not bool(dose[4])
			and fired == [FoodField.FIRED_VENOM],
		("" if ARMOUR != &"" else NO_ARMOUR)
		+ "pond-field: this cell's front venom rides its bite into an armoured friend"
		+ " (%.3f stacks), and their poison comes back into this cell (%.0f, told"
		% [into_them, into_me] + " as a dose); its venom is told as fired, once")

	# And the other way: a friend's front venom rides their bite into this
	# poisonous cell, and its poison goes into them.
	var poisonous := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1, &"veneneux": 2}
	fired = []
	field = _pond_rig(25, 30.0, poisonous, Vector2.ZERO, PI)
	field.toxins = FoodField.toxins_of(poisonous, [&"cytostome", &"cirrus", &"flagellum"])
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		&"toxicyst": 2}, PI)
	said = _pond_listen(field)
	field.toxin_fired.connect(func(how: int) -> void: fired.append(how))
	field._process(POND_STEP)
	mine = field.get("_cell")
	friend = field.bodies()[FoodField.PERSON_SLOT]
	into_them = float((friend.loads as PackedFloat64Array)[0])
	into_me = float((mine.loads as PackedFloat64Array)[0])
	dose = _pond_said(said, "dosed")
	_says(field.person() != null and not _pond_said(said, "bitten").is_empty()
			and float(mine.wound) > 0.0 and into_me == venom_n
			and not dose.is_empty() and float(dose[3]) == venom_n and not bool(dose[4])
			and _pond_worn(into_them, poison_n) and fired == [FoodField.FIRED_POISON],
		"pond-field: and a friend's front venom rides their bite into this poisonous"
		+ " cell (%.0f stacks, told as a dose), and its poison goes into them (%.3f);"
		% [into_me, into_them] + " its poison is told as fired, once")

	# **A side sting** (§7.2): the friend wears their venom in slot 5, on the
	# starboard quarter. This cell's bite landing there takes its stacks, and the
	# same bite on their other quarter none -- and neither friend's mouth is on
	# this cell, so nothing else doses it. Then this cell's own sting, worn in
	# slot 5 too, into a friend whose mouth lands there.
	var guards := Cilia.slot_bearing(5)
	var stinger := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, ARMOUR: 3,
		&"toxicyst": 2}
	var quarter: Array = [&"cytostome", &"cirrus", &"flagellum", ARMOUR, &"",
		&"toxicyst"]
	var sting: Array = []
	for side: float in [guards, -guards]:
		field = _pond_rig(26, 30.0, mouth)
		field.open_pond()
		field.set_person_genome(stinger, quarter)
		# Turned so that this cell, straight below them, is at `side` from their
		# nose: the bearing its bite lands at.
		field.place_person(at, PI - side, 28.0)
		said = _pond_listen(field)
		field._process(POND_STEP)
		mine = field.get("_cell")
		dose = _pond_said(said, "dosed")
		sting.append([float((mine.loads as PackedFloat64Array)[0]),
			float(dose[3]) if not dose.is_empty() else 0.0,
			not _pond_said(said, "touched", FoodField.Contact.BITTEN).is_empty()
				and float(mine.wound) == 0.0])
	var my_sting := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"toxicyst": 2}
	fired = []
	field = _pond_rig(27, 30.0, my_sting, Vector2.ZERO, -guards)
	field.toxins = FoodField.toxins_of(my_sting,
		[&"cytostome", &"cirrus", &"flagellum", &"", &"", &"toxicyst"])
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, PI)
	said = _pond_listen(field)
	field.toxin_fired.connect(func(how: int) -> void: fired.append(how))
	field._process(POND_STEP)
	mine = field.get("_cell")
	friend = field.bodies()[FoodField.PERSON_SLOT]
	into_them = float((friend.loads as PackedFloat64Array)[0])
	_says(sting.size() == 2 and float(sting[0][0]) == venom_n
			and float(sting[0][1]) == venom_n and bool(sting[0][2])
			and float(sting[1][0]) == 0.0 and float(sting[1][1]) == 0.0
			and bool(sting[1][2])
			and not _pond_said(said, "bitten").is_empty()
			and float((mine.loads as PackedFloat64Array)[0]) == 0.0
			and _pond_worn(into_them, venom_n) and fired == [FoodField.FIRED_STING],
		("" if ARMOUR != &"" else NO_ARMOUR)
		+ "pond-field: a side sting -- this cell's bite on the quarter a friend wears"
		+ " their venom on takes %.0f stacks, and on their other quarter %.0f; and"
		% [float(sting[0][0]), float(sting[1][0])] + " this cell's own sting puts"
		+ " %.3f into a friend biting it there, told as fired, once" % into_them)


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

	# **This cell swallows a poisonous friend** (dna-slots.md §7.1, owner's row 5):
	# they are eaten -- SWALLOWED by the friend -- and this cell takes the swallow's
	# dose, felt as the meal, before the meal is told; nobody is stung any more.
	var swallow_n := Stats.at(&"swallow_stacks", 1)
	var field := _pond_rig(81, 30.0, big)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"flagellum": 1, &"veneneux": 1})
	var said := _pond_listen(field)
	field._process(POND_STEP)
	var cell: Object = field.get("_cell")
	var died := _pond_said(said, "died")
	var dosed := _pond_said(said, "dosed")
	_says(_pond_said(said, "killed").is_empty() and not died.is_empty()
			and int(died[1]) == FoodField.Cause.SWALLOWED
			and int(died[2]) == FoodField.By.FRIEND
			and not _pond_said(said, "eaten").is_empty() and not dosed.is_empty()
			and bool(dosed[4]) and said.find(dosed) < said.find(_pond_said(said, "eaten"))
			and float((cell.loads as PackedFloat64Array)[0]) == swallow_n
			and _pond_said(said, "touched", FoodField.Contact.STUNG).is_empty()
			and field.person() == null,
		"pond-field: swallowing a poisonous friend eats them -- SWALLOWED by the"
		+ " friend -- and this cell takes %.0f stacks, told as the meal's before it"
		% float((cell.loads as PackedFloat64Array)[0]))

	# **The friend swallows this poisonous cell**: this cell is eaten -- SWALLOWED
	# by the friend -- and they take the dose, and live on with it.
	var mine := {&"cytostome": 1, &"cirrus": 1, &"veneneux": 1}
	field = _pond_rig(82, 30.0, mine, Vector2.ZERO, PI)
	field.toxins = FoodField.toxins_of(mine, [&"cytostome", &"cirrus"])
	field.open_pond()
	_pond_person(field, at, 30.0, big, PI)
	said = _pond_listen(field)
	field._process(POND_STEP)
	var friend: Object = field.bodies()[FoodField.PERSON_SLOT]
	var theirs := float((friend.loads as PackedFloat64Array)[0])
	_says(not _pond_said(said, "killed").is_empty()
			and int(field.died_of) == FoodField.Cause.SWALLOWED
			and int(field.died_by) == FoodField.By.FRIEND
			and _pond_said(said, "died").is_empty() and field.person() != null
			and theirs <= swallow_n
			and theirs >= swallow_n * exp(-POND_STEP / CellBody.DOSE_TAU_BY_KIND[0]) - 1e-9
			and _pond_said(said, "touched", FoodField.Contact.STUNG).is_empty(),
		"pond-field: a friend who swallows this poisonous cell eats it -- SWALLOWED by"
		+ " the friend, on this side -- and takes %.2f stacks of its poison" % theirs)

	# This cell chews the friend apart: its meal, their CHEWED.
	field = _pond_rig(83, 30.0, big)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		ARMOUR: 3})
	field.bodies()[FoodField.PERSON_SLOT].wound = 0.99
	said = _pond_listen(field)
	field._process(POND_STEP)
	died = _pond_said(said, "died")
	var ate := _pond_said(said, "eaten")
	_says(not died.is_empty() and int(died[1]) == FoodField.Cause.CHEWED
			and int(died[2]) == FoodField.By.FRIEND and not ate.is_empty()
			and _pond_said(said, "killed").is_empty() and field.person() == null,
		("" if ARMOUR != &"" else NO_ARMOUR)
		+ "pond-field: chewing a friend to the end is a meal here and CHEWED by the"
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

	# **A bite on a poisonous friend that finishes them** (dna-slots.md §7): a meal
	# here, CHEWED by the friend there, and the bite carries their poison into this
	# cell all the same -- stacks that work over the next seconds, so this cell is
	# not killed at the bite, already wounded as it is. Then the harm wears into
	# its wound until it is whole: POISONED, by the friend whose poison it was.
	field = _pond_rig(85, 30.0, big)
	field.open_pond()
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1,
		ARMOUR: 3, &"veneneux": 3})
	field.bodies()[FoodField.PERSON_SLOT].wound = 0.99
	cell = field.get("_cell")
	cell.set("wound", 0.95)
	said = _pond_listen(field)
	field._process(POND_STEP)
	died = _pond_said(said, "died")
	var bite_n := float((cell.loads as PackedFloat64Array)[0])
	var alive_after := _pond_said(said, "killed").is_empty()
	var steps := 0
	while float(cell.get("wound")) < 1.0 and steps < 3600:
		cell.set("wound", CellBody.dosed(cell.loads, float(cell.get("wound")),
			float(cell.get("radius")), POND_STEP))
		steps += 1
	field._process(POND_STEP)
	_says(not died.is_empty() and int(died[1]) == FoodField.Cause.CHEWED
			and int(died[2]) == FoodField.By.FRIEND and not _pond_said(said, "eaten").is_empty()
			and alive_after and bite_n == Stats.at(&"poison_stacks", 3)
			and not _pond_said(said, "killed").is_empty()
			and int(field.died_of) == FoodField.Cause.POISONED
			and int(field.died_by) == FoodField.By.FRIEND,
		("" if ARMOUR != &"" else NO_ARMOUR)
		+ "pond-field: a bite that finishes a poisonous friend is a meal -- CHEWED by the"
		+ " friend -- and carries %.0f stacks into this cell, which lives; %.1f s on"
		% [bite_n, steps * POND_STEP] + " the harm makes its wound whole: POISONED by"
		+ " the friend")

	# **A friend made whole by harm** (dna-slots.md §6.2): this cell's poison in
	# them, worn into their wound, takes them out of the pond -- POISONED, by the
	# friend, told them as a KILLED with that cause, and nothing eats them.
	field = _pond_rig(89, 30.0, plain)
	field.open_pond()
	_pond_person(field, Vector2(600.0, 0.0), 28.0, plain)
	said = _pond_listen(field)
	field._dose(FoodField.PERSON_SLOT, 0, 60.0, FoodField.TARGET_PLAYER, 0.0, false)
	var frames := 0
	while field.person() != null and frames < 3600:
		field._process(POND_STEP)
		frames += 1
	died = _pond_said(said, "died")
	var told_killed := _pond_said(said, "touched", FoodField.Contact.KILLED)
	_says(field.person() == null and not died.is_empty()
			and int(died[1]) == FoodField.Cause.POISONED
			and int(died[2]) == FoodField.By.FRIEND and not told_killed.is_empty()
			and _pond_said(said, "eaten").is_empty() and frames < 3600,
		"pond-field: a friend carrying this cell's poison dies of it %.1f s on --"
		% (frames * POND_STEP) + " POISONED by the friend, told as a KILLED, eaten"
		+ " by nobody")

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
	cell = field.get("_cell")
	cell.set("wound", 0.95)
	var ahead := Vector2(0.0, -72.0)
	_pond_pose(field, 5, 44.0, {&"cytostome": 1, ARMOUR: 3, &"veneneux": 3},
		ahead, 0.0)
	field._process(POND_STEP)
	# What it bit dosed it; the harm, worn as this cell's own step wears it, makes
	# its wound whole, and the field tells the death at its next pass.
	steps = 0
	while float(cell.get("wound")) < 1.0 and steps < 3600:
		cell.set("wound", CellBody.dosed(cell.loads, float(cell.get("wound")),
			float(cell.get("radius")), POND_STEP))
		steps += 1
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
			var slot := int(entry[FoodField.ENTRY_SLOT])
			if slot < 0:
				continue
			var id := int(entry[FoodField.Entry.ID])
			var meals := int(entry[FoodField.Entry.MEALS])
			if versions.get(id, -1) != meals:
				versions[id] = meals
				mirror.apply_genome(id, meals,
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
		if _hunter_id(host) != _hunter_id(mirror) and mismatch.is_empty():
			mismatch = "-- frame %d hunter %d against %d" % [frame, _hunter_id(host),
				_hunter_id(mirror)]
	_says(mismatch.is_empty() and worst <= 1e-6 and hunted > 500 and returns > 0,
		("pond-field: the mirror returns the host's taste, dread, shadow, touch,"
		+ " beams, ping returns and hunter() within 1e-6 for %d frames (worst %s;"
		+ " %d frames hunted, %d returns, at most %d of %d bodies sent) %s")
		% [frames, str(worst), hunted, returns, sent_max, FoodField.POND_SLOTS,
			mismatch])

	# A hunter the host loses leaves the mirror's hunt in the same snapshot: a
	# retired body is not sent, and a mirror that kept its last STALK would go
	# on answering hunter() for nothing. The mirror holds it in a slot of its
	# own, found by the body's id (protocol 5).
	var gone_id := int(host.call("_wire_id", host.bodies()[7]))
	var gone_at := int((mirror.get("_mirror_slots") as Dictionary).get(gone_id, -1))
	var was_hunted: bool = host.hunter() == 7 and mirror.hunter() == gone_at \
		and gone_at >= 0
	host.call("_retire", 7)
	mirror.apply_pond(host_cell.wound, host.pond_entries(false))
	_says(was_hunted and _hunter_id(host) == _hunter_id(mirror)
			and mirror.hunter() != gone_at,
		"pond-field: a hunter the host retires leaves the mirror's hunter() with"
		+ " the next snapshot (%d on both)" % _hunter_id(mirror))
	# And it is drawn as nothing there, as on the host: the view reads points()
	# and radii() and never `seeded`, so a radius left behind is a ghost.
	_says(gone_at >= 0 and not bool(mirror.bodies()[gone_at].seeded)
			and float(mirror.radii()[gone_at]) == 0.0 and float(host.radii()[7]) == 0.0,
		"pond-field: a body the host stops sending has radius 0 on the mirror,"
		+ " as on the host (%s against %s)" % [str(mirror.radii()[maxi(gone_at, 0)]),
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

	# **A return into the pond forgets the last killer** (shared-pond.md §5,
	# Phase 3): a cell killed by a body comes back through `enter_water()`, not
	# through an arrival as a solo return does, and a killer it remembered would
	# be named by the recorder at its next death -- predator rings round an
	# innocent body in the replay of a death by hunger or by the friend.
	field = _pond_rig(74, 30.0, POND_SENSES)
	field.open_pond()
	field.set("died_to", 5)
	field.leave_water(true)
	var remembered := int(field.get("died_to"))
	field.enter_water()
	_says(remembered == 5 and int(field.get("died_to")) == -1,
		"pond-field: a cell back in the pond from its black has no killer (%d,"
		% int(field.get("died_to")) + " where its last death had %d)" % remembered)


# --- The friend, recorded and drawn back (shared-pond.md §5, Phase 3) -----------

## **A session for one number**: the friend's silence, as a check sets it --
## what the recorder and the world view both ask a session for, and nothing
## else a session is.
class QuietStub extends Node:
	var quiet := 0.0

	func quiet_for() -> float:
		return quiet

	func peer_track() -> Array:
		return []

	func clock() -> float:
		return 0.0


## **The friend, recorded and drawn back as the live view drew them** (shared-
## pond.md §5, Phase 3; UX §4, §9 item 7), with no socket and no frames. A
## host's drop opened as a pond; a person arriving in it, swimming, out of the
## water and back as a friend dividing is, changing what they wear, falling
## quiet, and swallowed by the water and said gone -- a world view drawing them
## live as it does in a run, and the recorder taking every frame. Then the
## replay over the sealed ring, on nodes of its own, played frame by frame: its
## world view draws the friend as the live one did, every number of it -- place,
## heading, size, the arrival fade, the ghost and its pinch, the commit, the
## tiers, the mouth, presence -- and their departure as a SELF_TINT meal ring
## where they were eaten, one recorded frame early, as every mark is. **This is
## the render CI cannot make**: the drawing itself is cilia.gd's, the same call
## either way; what decides it is this dictionary.
func _pond_replay_field() -> void:
	var dt := 1.0 / 60.0
	var rig := Node.new()
	rig.name = "PondReplayRig"
	var cell := CellBody.new()
	cell.radius = 30.0
	cell.process_mode = Node.PROCESS_MODE_DISABLED
	rig.add_child(cell)
	var field := FoodField.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	rig.add_child(field)
	var rec := RecorderNode.new()
	rec.process_mode = Node.PROCESS_MODE_DISABLED
	rig.add_child(rec)
	var quiet := QuietStub.new()
	rig.add_child(quiet)
	add_child(rig)
	seed(77)
	field.setup_drop(cell)
	field.open_pond()
	rec.set_session(quiet)
	var live: Node = (load("res://game/vision/vision.tscn") as PackedScene).instantiate()
	live.bind(cell, null, field, null, null)
	rig.add_child(live)
	live.set_session(quiet)
	live.set_active(true)
	var frames := 100
	var eat := 80
	var from: Vector2 = cell.position + Vector2(300.0, -40.0)
	var first := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1}
	var daughter := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 2, &"ampulla": 1}
	var gone_at := Vector2.ZERO
	var lived: Array = []
	for k in frames:
		if k == 3:
			field.set_person_genome(first, [&"cytostome", &"cirrus", &"flagellum"])
		if k == 20:
			field.set_person_in_water(false)
		if k == 45:
			field.set_person_in_water(true)
		if k == 50:
			field.set_person_genome(daughter,
				[&"cytostome", &"cirrus", &"flagellum", &"ampulla"])
		if k >= 3 and k < eat:
			field.place_person(from + Vector2(2.0, 0.5) * float(k), 0.05 * float(k),
				28.0 + 0.02 * float(k))
		quiet.quiet = maxf(0.1 * float(k - 55), 0.0)
		if k == eat:
			gone_at = field.bodies()[FoodField.PERSON_SLOT].pos
			field.call(&"_person_gone", FoodField.Cause.SWALLOWED, FoodField.By.WATER,
				field.person())
			rec.friend_gone(VisionLayer.Gone.EATEN, gone_at)
			live.friend_gone(VisionLayer.Gone.EATEN, gone_at)
		live._process(dt)
		lived.append((live.get("_peer") as Dictionary).duplicate())
		rec._process(dt)
	var lived_ring := _ring_at(live.get("_meals"), gone_at)
	rec.seal()
	var held := bool(rec.call(&"holds_person"))
	var screen: Node = (load("res://game/replay/replay.tscn") as PackedScene).instantiate()
	screen.set(&"recorder", rec)
	screen.set(&"private_nodes", true)
	rig.add_child(screen)
	screen.set_process(false)
	var water: Node = screen.get("_food")
	var shown: Node = (screen.get("_panes") as Node).get("_vision")
	screen.call(&"_rewind")
	screen.set("_forget", false)
	(screen.get("_panes") as Node).call(&"rewound")
	var drawn: Array = []
	var in_grid := false
	for k in int(rec.call(&"frames")):
		# A hair past the frame, so what was written in it is in (_replay_friend).
		screen.set("_at", float(rec.call(&"time_of", k)) + 1e-6)
		screen.call(&"_seek")
		shown._process(dt)
		drawn.append((shown.get("_peer") as Dictionary).duplicate())
		var pb: Object = _person_of(water)
		if pb != null and float(pb.radius) > 0.0 and (water.call(&"bodies_near", pb.pos,
				80.0) as PackedInt32Array).has(FoodField.PERSON_SLOT):
			in_grid = true
	var shown_ring := _ring_at(shown.get("_meals"), gone_at)
	# **A rim told while the friend is in the water** -- a guest that swapped
	# into a host's drop has its own rim and then the host's in one window --
	# files every body in the replay's grid again, and still not the friend.
	screen.call(&"_rewind")
	screen.set("_at", float(rec.call(&"time_of", 10)) + 1e-6)
	screen.call(&"_seek")
	var rim: RefCounted = water.call(&"basin")
	water.call(&"restore_rim", (rim.get(&"center") as Vector2) + Vector2(1.0, 0.0),
		float(rim.get(&"radius")))
	var friend: Object = _person_of(water)
	if friend == null or (water.call(&"bodies_near", friend.pos, 80.0)
			as PackedInt32Array).has(FoodField.PERSON_SLOT):
		in_grid = true
	# Every frame before the departure, number for number.
	var worst := 0.0
	var off: Array = []
	var ghosts := 0
	var commits := 0
	for k in eat - 1:
		var was: Dictionary = lived[k]
		var now: Dictionary = drawn[k]
		if was.is_empty() or now.is_empty():
			if was.is_empty() != now.is_empty():
				off.append("%d: %s live, %s replayed" % [k, "drawn" if not was.is_empty()
					else "none", "drawn" if not now.is_empty() else "none"])
			continue
		worst = maxf(worst, (was["at"] as Vector2).distance_to(now["at"]))
		worst = maxf(worst, absf(angle_difference(float(was["heading"]),
			float(now["heading"]))))
		for key: String in ["radius", "confidence", "alpha", "pinch", "double", "gape",
				"wound", "doubt"]:
			worst = maxf(worst, absf(float(was[key]) - float(now[key])))
		if was["tiers"] != now["tiers"] or was["order"] != now["order"] \
				or bool(was["ghost"]) != bool(now["ghost"]) or was["felt"] != now["felt"]:
			off.append("%d: tiers, order, ghost or felt" % k)
		ghosts += 1 if bool(now["ghost"]) else 0
		commits += 1 if float(now["pinch"]) > 0.0 and not bool(now["ghost"]) else 0
	# Presence below the body's own alpha: the silence, not the commit.
	var faded: bool = not (drawn[eat - 2] as Dictionary).is_empty() \
		and float((drawn[eat - 2] as Dictionary)["confidence"]) \
			< 0.95 * float((drawn[eat - 2] as Dictionary)["alpha"])
	var departed: bool = (drawn[eat - 1] as Dictionary).is_empty() \
		and (lived[eat] as Dictionary).is_empty() and (drawn[eat] as Dictionary).is_empty()
	var rings: bool = not lived_ring.is_empty() and not shown_ring.is_empty() \
		and (shown_ring[3] as Color) == VisionLayer.SELF_TINT \
		and absf(float(shown_ring[1]) - float(lived_ring[1])) < 0.1
	_says(held and off.is_empty() and worst < 1e-3 and ghosts > 10 and commits > 10
			and faded and departed and rings and not in_grid,
		"pond-field: the friend recorded and played back is drawn as the live view drew"
		+ " them, every frame of %d before they were eaten -- worst %.6f apart, the ghost"
		% [eat - 1, worst] + " on %d frames and the commit on %d, presence faded %s --"
		% [ghosts, commits, str(faded)] + " and eaten, a SELF_TINT meal ring where they"
		+ " were (%s), one recorded frame early (%s); never in the replay's grid (%s)%s"
		% [str(rings), str(departed), str(not in_grid),
			"" if off.is_empty() else " -- NOT: " + ", ".join(off.slice(0, 4))])
	rig.free()


## The body in [param field]'s person slot, or null for a field with none.
static func _person_of(field: Node) -> Object:
	var bodies: Array = field.call(&"bodies")
	return bodies[FoodField.PERSON_SLOT] if bodies.size() > FoodField.PERSON_SLOT else null


## The meal ring [param meals] holds at [param at], or empty.
static func _ring_at(meals: Variant, at: Vector2) -> Array:
	for meal: Array in (meals as Array):
		if (meal[0] as Vector2) == at:
			return meal.duplicate()
	return []


# --- The pond on the drop (ocean.md §10.2, protocol 5) --------------------------

## **A host's own drop, opened as a pond**: made round a cell of [param radius]
## wearing [param tiers] as a run makes one, with the organs set as a run sets
## them, and the pond opened on it. The cell is at the drop's quiet start.
func _pond_drop_rig(from_seed: int, radius: float, tiers: Dictionary) -> Node:
	seed(from_seed)
	var genome := StubGenome.new()
	genome.body = tiers.duplicate()
	var cell: Node = CellBody.new()
	cell.genome = genome
	cell.radius = radius
	var field: Node = WatchedFood.new()
	field.setup_drop(cell)
	field.smell_range = cell.smell_range()
	field.smell_bearing = 0.0
	field.ping_range = cell.ping_range()
	field.ping_period = cell.ping_period()
	field.ping_through = cell.ping_through()
	field.ping_tier = cell.ping_tier()
	field.open_pond()
	_pond_nodes.append_array([genome, cell, field])
	_pond_fields.append(field)
	return field


## A point inside [param field]'s rim [param away] units from its cell: along
## the line from the cell through the middle, or the middle itself.
func _drop_point(field: Node, away: float) -> Vector2:
	var rim: RefCounted = field.basin()
	var centre: Vector2 = rim.get(&"center")
	var from: Vector2 = field.get("_cell").position
	var dir := (centre - from).normalized() if from.distance_to(centre) > 1.0 \
		else Vector2.RIGHT
	return from + dir * away


## **The drop's rules for the other player** (ocean.md §10.2, rows 15 and 5): a
## water mouth that is not hunting them swallows them on contact when they fit,
## as it does the host, and is fed by them -- a meal and a unit of growth -- and
## the slot empties that frame; and their mouth on a settled floc grazes it,
## said to them as GRAZED with its worth, and they do not grow.
func _drop_pond_rules() -> void:
	var field := _pond_drop_rig(81, 30.0, POND_SENSES)
	var at := _drop_point(field, 700.0)
	_pond_person(field, at, CellBody.BASE_RADIUS, {&"cytostome": 1, &"cirrus": 1,
		&"flagellum": 1})
	var said := _pond_listen(field)
	var from := at + Vector2(0.0, -54.0)
	var b := _pond_pose(field, 5, 30.0, {&"cytostome": 3, &"flagellum": 1}, from,
		_pond_face(from, at))
	b.hunger = 0.8
	var gape := CellBody.gape_of({&"cytostome": 3}, 30.0)
	var reaches := Cilia.mouth_touches(b.pos, b.heading, 30.0, gape, at, CellBody.BASE_RADIUS)
	field._process(POND_STEP)
	var died := _pond_said(said, "died")
	_says(reaches and int(b.state) != FoodField.State.STALK and not died.is_empty()
			and int(died[1]) == FoodField.Cause.SWALLOWED and field.person() == null
			and not bool(field.bodies()[FoodField.PERSON_SLOT].seeded)
			and is_equal_approx(float(b.radius), 30.0 + CellBody.GROWTH_PER_MEAL)
			and int(b.meals) == 1 and float(b.hunger) < 0.8,
		"pond-field, the drop: a mouth not hunting the other player swallows them on"
		+ " contact (row 15), is fed by them -- r%.0f and a meal, hunger %.2f from 0.80 --"
		% [float(b.radius), float(b.hunger)] + " and their slot is empty that frame")

	field = _pond_drop_rig(82, 30.0, POND_SENSES)
	at = _drop_point(field, 700.0)
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	said = _pond_listen(field)
	var floc := int(field.call("_spawn_floc", at + Vector2(0.0, -(28.0 + 4.0)), 8.0, true))
	var floc_id := int(field.bodies()[floc].id)
	field._process(POND_STEP)
	var grazed := _pond_said(said, "touched", FoodField.Contact.GRAZED)
	var fb: Object = field.bodies()[floc]
	_says(not grazed.is_empty() and is_equal_approx(float(grazed[3]),
			clampf(8.0 / 28.0, FoodField.MEAL_MIN, FoodField.MEAL_MAX))
			and _pond_said(said, "touched", FoodField.Contact.ATE).is_empty()
			and not (bool(fb.seeded) and int(fb.id) == floc_id)
			and is_equal_approx(float(field.bodies()[FoodField.PERSON_SLOT].radius), 28.0),
		"pond-field, the drop: the other player's mouth on a settled floc grazes it --"
		+ " GRAZED at %.2f of a meal, no ATE, the floc gone and r28 still"
		% (float(grazed[3]) if not grazed.is_empty() else -1.0))


## **Every player is an anchor, and the send set is the nearest sixty** (ocean.md
## §10.2, §10.4): a body beside the other player and far from the host is stepped
## every frame, as one beside the host is; and their snapshot is every body
## within reach that is coming for them, flagged, and then the nearest of the
## rest, sixty in all -- never a floc, never a person. **The host's water is on
## rules** (behaviour.md §8): "stalking you" is "coming for you" (§4.3), a body
## swimming with them within 35° of its heading and a mouth that takes them.
func _drop_pond_anchors() -> void:
	var field := _pond_drop_rig(83, 30.0, POND_SENSES)
	var at := _drop_point(field, FoodField.Drop.LOD_NEAR * 1.5)
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var near := _pond_pose(field, 6, 15.0, {}, at + Vector2(150.0, 0.0), 0.0)
	var every := 0
	for frame in 16:
		field._process(POND_STEP)
		if int(near.stepped) == int(field.get("_frame")):
			every += 1
	# A mouth coming for them -- swimming, at them -- far inside the send reach,
	# and the snapshot they are sent.
	var pb: Object = field.bodies()[FoodField.PERSON_SLOT]
	var far_at: Vector2 = at + (at - (field.get("_cell").position as Vector2)).normalized() \
		* -1800.0
	var far := _pond_pose(field, 7, 30.0, {&"cytostome": 3, &"flagellum": 1}, far_at,
		_pond_face(far_at, pb.pos))
	far.swimming = true
	var entries: Array = field.pond_entries(true)
	var sent := {}
	var worst := 0.0
	var fair := true
	var hunter_in := false
	for entry: Array in entries:
		var slot := int(entry[FoodField.ENTRY_SLOT])
		if slot < 0:
			continue
		var b: Object = field.bodies()[slot]
		sent[slot] = true
		if bool(b.inert) or b.person != null:
			fair = false
		if slot == 7:
			hunter_in = (int(entry[FoodField.Entry.FLAGS]) & FoodField.FLAG_STALKING) != 0
		elif (int(entry[FoodField.Entry.FLAGS]) & FoodField.FLAG_STALKING) == 0:
			# The rest, nearest first. Another body coming for them goes first
			# wherever it is in reach, flagged, as the posed one does -- so it is
			# not one of the rest, however far it is.
			worst = maxf(worst, (b.pos as Vector2).distance_to(pb.pos) - float(b.radius))
	var nearer_left := 0
	for i in field.bodies().size():
		var b: Object = field.bodies()[i]
		if not bool(b.seeded) or bool(b.inert) or b.person != null or sent.has(i):
			continue
		if (b.pos as Vector2).distance_to(pb.pos) - float(b.radius) < worst - 1.0 / 16.0:
			nearer_left += 1
	_says(every == 16 and hunter_in and fair and sent.size() <= FoodField.SEND_MAX
			and nearer_left == 0 and entries.size() == sent.size() + 1,
		"pond-field, the drop: a body beside the other player, %.0f from the host, is"
		% at.distance_to(field.get("_cell").position) + " stepped %d of 16 frames;" % every
		+ " their snapshot is %d water bodies, a mouth coming for them 1,800 off in it"
		% sent.size() + " and flagged, none of the rest nearer than its farthest (%.0f), no"
		% worst + " floc and no person")


## **The guest's mirror, on the host's drop** (ocean.md §10.4): fed the host's
## own snapshots for the other player, their bodies' genomes by id, the flocs in
## their reach as SETTLE and CLEAR, and the rim -- it holds exactly the bodies
## sent, each under its id with its genome, and exactly the flocs in reach, each
## settling by the mirror's own clock; and its cell, put past the rim, is held
## inside it and knocked.
func _drop_pond_mirror() -> void:
	var host := _pond_drop_rig(84, 30.0, POND_SENSES)
	var at := _drop_point(host, 400.0)
	_pond_person(host, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	# A floc landing in their reach, still settling.
	var landing := int(host.call("_spawn_floc", at + Vector2(160.0, 90.0), 10.0, false))
	var landing_id := int(host.bodies()[landing].id)
	var mirror := _pond_rig(84, 28.0, POND_SENSES)
	mirror.become_mirror()
	var rim: Array = host.rim()
	mirror.mirror_rim(rim[0], float(rim[1]))
	var versions := {}
	var told := {}
	var problems: Array[String] = []
	var settling := [-1.0, -1.0]
	for frame in 90:
		host._process(POND_STEP)
		var pb: Object = host.bodies()[FoodField.PERSON_SLOT]
		var mirror_cell: Object = mirror.get("_cell")
		mirror_cell.position = pb.pos
		var entries: Array = host.pond_entries(true)
		for entry: Array in entries:
			var slot := int(entry[FoodField.ENTRY_SLOT])
			if slot < 0:
				continue
			var id := int(entry[FoodField.Entry.ID])
			var meals := int(entry[FoodField.Entry.MEALS])
			if versions.get(id, -1) != meals:
				versions[id] = meals
				mirror.apply_genome(id, meals, (host.bodies()[slot].genome as Dictionary)
					.duplicate())
		mirror.apply_pond(0.0, entries)
		var now := {}
		for f: Array in host.flocs_in_reach(pb.pos):
			now[int(f[0])] = true
			if not told.has(int(f[0])):
				told[int(f[0])] = true
				mirror.mirror_floc(int(f[0]), f[1], float(f[2]), float(f[3]), float(f[4]))
		for id: int in told.keys():
			if not now.has(id):
				told.erase(id)
				mirror.mirror_unfloc(id)
		mirror.call("_step_mirror", POND_STEP)
		# Exactly what was sent, by id, with its genome.
		var slots: Dictionary = mirror.get("_mirror_slots")
		var flocs: Dictionary = mirror.get("_mirror_flocs")
		var sent := 0
		for entry: Array in entries:
			var slot := int(entry[FoodField.ENTRY_SLOT])
			if slot < 0:
				continue
			sent += 1
			var m := int(slots.get(int(entry[FoodField.Entry.ID]), -1))
			if m < 0 or mirror.bodies()[m].genome != host.bodies()[slot].genome:
				problems.append("frame %d body %d" % [frame, int(entry[FoodField.Entry.ID])])
		if slots.size() != sent or flocs.size() != now.size():
			problems.append("frame %d holds %d bodies and %d flocs for %d and %d"
				% [frame, slots.size(), flocs.size(), sent, now.size()])
		if flocs.has(landing_id):
			var m := int((flocs[landing_id] as Array)[0])
			if frame == 10:
				settling[0] = float(mirror.bodies()[m].settle)
			elif frame == 70:
				settling[1] = float(mirror.bodies()[m].settle)
	# Its own cell, put past the rim.
	var knocks := [0]
	mirror.shored.connect(func(_b: float, _s: float, _at: Vector2) -> void: knocks[0] += 1)
	var cell: Object = mirror.get("_cell")
	var basin: RefCounted = mirror.basin()
	var centre: Vector2 = basin.get(&"center")
	cell.position = centre + Vector2(float(basin.get(&"radius")) + 50.0, 0.0)
	cell.velocity = Vector2(80.0, 0.0)
	mirror.call("_step_mirror", POND_STEP)
	var held: bool = basin.call(&"inside", cell.position, float(cell.radius))
	_says(problems.is_empty() and settling[0] >= 0.0 and settling[1] > settling[0]
			and held and knocks[0] == 1,
		"pond-field, the drop: the guest's mirror holds exactly the bodies sent, by id and"
		+ " with their genomes, and the flocs in reach (settling %.2f to %.2f by its own"
		% [settling[0], settling[1]] + " clock); its cell past the rim is held inside and"
		+ " knocked %d time%s%s" % [knocks[0], "" if knocks[0] == 1 else "s",
			"" if problems.is_empty() else " -- NOT: " + ", ".join(problems.slice(0, 4))])


## **A drop kept while it is a pond keeps nobody** (ocean.md §9.1): the other
## player is never in the file -- no body where they are, their slot empty
## loaded -- and a chase of them is kept as a chase of nobody.
func _drop_pond_kept() -> void:
	var field := _pond_drop_rig(85, 30.0, POND_SENSES)
	var at := _drop_point(field, 600.0)
	_pond_person(field, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var pb: Object = field.bodies()[FoodField.PERSON_SLOT]
	for frame in 30:
		field._process(POND_STEP)
	var hunter := _pond_pose(field, 8, 30.0, {&"cytostome": 3, &"flagellum": 1},
		pb.pos + Vector2(0.0, 400.0), 0.0)
	hunter.state = FoodField.State.STALK
	hunter.target = FoodField.PERSON_SLOT
	hunter.target_serial = pb.serial
	var state: Dictionary = field.drop_state()
	var rows: Dictionary = state["bodies"]
	var there := 0
	for p: Vector2 in rows["at"] as PackedVector2Array:
		if p.distance_to(pb.pos) < 0.5:
			there += 1
	var slots: PackedInt32Array = rows["slot"]
	# A phone's pond has one person, in slot 68; the slot after it is water.
	var kept_person := slots.has(FoodField.PERSON_SLOT)
	var chase := -99
	var at_row := slots.find(8)
	if at_row >= 0:
		chase = int((state["runs"]["target"] as PackedInt64Array)[at_row])
	var solo := _pond_drop_rig(86, 30.0, POND_SENSES)
	solo.load_drop(solo.get("_cell"), state)
	_says(there == 0 and not kept_person and chase == FoodField.TARGET_NONE
			and not bool(solo.bodies()[FoodField.PERSON_SLOT].seeded),
		"pond-field, the drop: kept mid-pond, %d bodies, %d where the other player is"
		% [slots.size(), there] + " (none, and not their slot: %s), their slot empty" % kept_person
		+ " loaded, and a chase of them kept as a chase of nobody (%d)" % chase)


## **The host's water divides, and the guest's mirror sees it** (lineage.md §8,
## §11.3): births are the host's water, and the wire carries them as it carries
## any body coming into reach -- no new field, no new message. A host's drop
## with the other player in it, a mouth beside them posed a meal short of
## DIVIDE_RADIUS, and a guest's mirror fed the host's own snapshots and GENOMEs
## by id, as in [method _drop_pond_mirror]. Ten frames on the mouth is grown to
## forty, and on the frame the host divides it the mirror loses the mother's id
## and holds her two daughters' -- each at half her area, where the host has her,
## under her own genome -- with **no foul**: every frame the mirror holds exactly
## the bodies sent, each with its genome, and nothing the host did reached the
## other player's slot.
func _drop_pond_births() -> void:
	var host := _pond_drop_rig(87, 30.0, POND_SENSES)
	var at := _drop_point(host, 500.0)
	_pond_person(host, at, 28.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var from := at + Vector2(250.0, 0.0)
	var mother := _pond_pose(host, 9, CellBody.DIVIDE_RADIUS - CellBody.GROWTH_PER_MEAL,
		{&"cytostome": 1, &"cirrus": 2, &"flagellum": 2, &"ampulla": 1}, from,
		_pond_face(from, at))
	var mother_id := int(mother.id)
	var mirror := _pond_rig(87, 28.0, POND_SENSES)
	mirror.become_mirror()
	var rim: Array = host.rim()
	mirror.mirror_rim(rim[0], float(rim[1]))
	var versions := {}
	var problems: Array[String] = []
	var held_mother := -1
	var left := -1
	var arrived := -1
	var daughters: Array[int] = []
	var as_sent := 0
	for frame in 40:
		# Grown to forty on the tenth frame, as a meal would, if the water has not
		# already fed it there: it divides on its next tick.
		if frame == 10 and bool(mother.seeded) and int(mother.id) == mother_id:
			mother.radius = CellBody.DIVIDE_RADIUS
			host.refresh(9)
		host._process(POND_STEP)
		var pb: Object = host.bodies()[FoodField.PERSON_SLOT]
		var mirror_cell: Object = mirror.get("_cell")
		mirror_cell.position = pb.pos
		var entries: Array = host.pond_entries(true)
		for entry: Array in entries:
			var slot := int(entry[FoodField.ENTRY_SLOT])
			if slot < 0:
				continue
			var id := int(entry[FoodField.Entry.ID])
			var meals := int(entry[FoodField.Entry.MEALS])
			if versions.get(id, -1) != meals:
				versions[id] = meals
				mirror.apply_genome(id, meals, (host.bodies()[slot].genome as Dictionary)
					.duplicate())
		mirror.apply_pond(0.0, entries)
		# As it lands: every body sent, by id, with its genome and where the host has
		# it -- before the mirror carries it on by its own clock.
		var slots: Dictionary = mirror.get("_mirror_slots")
		var sent := 0
		for entry: Array in entries:
			var slot := int(entry[FoodField.ENTRY_SLOT])
			if slot < 0:
				continue
			sent += 1
			var m := int(slots.get(int(entry[FoodField.Entry.ID]), -1))
			if m < 0 or mirror.bodies()[m].genome != host.bodies()[slot].genome \
					or (mirror.bodies()[m].pos as Vector2) != (host.bodies()[slot].pos as Vector2):
				problems.append("frame %d body %d" % [frame, int(entry[FoodField.Entry.ID])])
		if slots.size() != sent:
			problems.append("frame %d holds %d bodies for %d" % [frame, slots.size(), sent])
		mirror.call("_step_mirror", POND_STEP)
		if slots.has(mother_id):
			held_mother = frame
		elif held_mother >= 0 and left < 0:
			left = frame
			for b: Object in host.bodies():
				if bool(b.seeded) and int(b.parent) == mother_id:
					daughters.append(int(b.id))
			var both := daughters.size() == 2
			for id: int in daughters:
				both = both and slots.has(id)
			arrived = frame if both else -1
			for id: int in daughters:
				var m := int(slots.get(id, -1))
				if m >= 0 and is_equal_approx(float(mirror.bodies()[m].radius),
						CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)):
					as_sent += 1
	var touched := int(host.get("touched_person"))
	_says(problems.is_empty() and held_mother >= 0 and left == held_mother + 1
			and arrived == left and as_sent == 2 and touched == 0,
		"pond-field, the drop: the host's water divides and the guest's mirror sees it -- the"
		+ " mother (id %d) held until frame %d, gone at frame %d, and her daughters %s"
		% [mother_id, held_mother, left, str(daughters)]
		+ " there from frame %d, %d of them at r%.2f under their own genomes; every frame"
		% [arrived, as_sent, CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)]
		+ " exactly the bodies sent, %d fouls, and the other player's slot touched %d times"
		% [problems.size(), touched]
		+ ("" if problems.is_empty() else " -- NOT: " + ", ".join(problems.slice(0, 4))))


## **Which body is hunting this cell, by its id on the wire** -- a host's and a
## mirror's slots for one body differ (protocol 5), its id does not. -1 for
## none.
func _hunter_id(field: Node) -> int:
	var h: int = field.hunter()
	if h < 0:
		return -1
	if field.mirroring():
		return int(field.bodies()[h].id)
	return int(field.call("_wire_id", field.bodies()[h]))


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
	## last 64 kept: `[count, entries, water, the guest's place]`, where `water`
	## is every water body that could be in it as it stood at that instant --
	## within the send reach and a margin, or hunting the guest -- as `[slot,
	## id, place, radius, meals, genome, hunting the guest]`. **On rules,
	## "hunting" is what the send set puts first** (`_send_coming`): coming for
	## the guest, within the reach. Under row 37 (automation.md §5.3) a resting
	## hunter of one copy swims, so one is often coming for the guest from past
	## the sixty nearest -- and a run's state, which no body on rules is in, never
	## named it. The mirror check finds the one the guest applied by its
	## sequence, and so never compares a mirror with water a frame later than the
	## water it was sent.
	var built: Array = []
	var built_count := 0

	func pond_entries(for_person: bool, reach: float = SEND_REACH) -> Array:
		var out: Array = super.pond_entries(for_person, reach)
		if for_person:
			var pb := _cells[PERSON_SLOT]
			var water: Array = []
			for i in _cells.size():
				var b := _cells[i]
				if not b.seeded or b.inert or b.person != null:
					continue
				var hunting := b.state == State.STALK and b.target == PERSON_SLOT \
					and b.target_serial == pb.serial
				if _ruled():
					hunting = pb.person != null and b.pos.distance_to(pb.pos) - b.radius \
						<= reach and _coming_for_player(b, pb.person)
				if not hunting and b.pos.distance_to(pb.pos) - b.radius > reach + 100.0:
					continue
				water.append([i, _wire_id(b), b.pos, b.radius, b.meals,
					b.genome.duplicate(), hunting])
			built_count += 1
			built.append([built_count, out, water, pb.pos])
			if built.size() > 64:
				built.pop_front()
		return out

	func place_sister(at: Vector2, heading: float, body_radius: float,
			tiers: Dictionary, dna := {}, mother := PackedInt32Array(),
			brain: Variant = null) -> int:
		var before := PackedInt64Array()
		var seeded := PackedByteArray()
		for b in _cells:
			before.append(b.serial)
			seeded.append(1 if b.seeded else 0)
		var slot := super.place_sister(at, heading, body_radius, tiers, dna, mother, brain)
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
		var record := {"slot": slot,
			"was_free": slot >= 0 and (slot >= seeded.size() or seeded[slot] == 0),
			"appended": slot >= before.size(),
			"changed": changed, "at": at, "radius": body_radius,
			"host_at": _cell.position, "clear": clear, "moved": moved,
			# **What she was placed with, and what she is in the water**
			# (automation.md §10.3, check 24): a guest's comes with no record.
			"tiers": tiers.duplicate(), "dna": dna.duplicate(), "mother": mother.size(),
			"brain": brain}
		if slot >= 0:
			var sb := _cells[slot]
			record.merge({"id": sb.id, "parent": sb.parent, "generation": sb.generation,
				"lineage": sb.lineage, "body_dna": sb.dna.duplicate(),
				"body_brain": sb.brain, "genome": sb.genome.duplicate()})
		sisters.append(record)
		return slot


const POND_ARRIVAL_TOLERANCE := 1.0
const POND_BEARING_TOLERANCE := 0.05
## **How fast a guest is moved across the water here**: 900 units a second, a
## glide, where the referee allows 1,100 (B.5) -- so a tighter cap per genome,
## the obvious next step (B.2), would still let every move in this file by.
const POND_GLIDE := 900.0
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
	# be more than about 5,500 of CI's 24,000 frames, however fast the runner.
	# Nothing here is finer than a 4 ms frame -- the tightest bound is 0.1 s.
	var ceiling := Engine.max_fps
	Engine.max_fps = 250
	_pond_frame_worst = 0.0
	_tally_begin()
	var host_net: Node = await _session("PondHost")
	var guest_net: Node = await _session("PondGuest")
	host_net.host()
	guest_net.join("127.0.0.1")
	await _until_link(guest_net, NetSession.Link.TOGETHER)
	await _until_link(host_net, NetSession.Link.TOGETHER)
	_says(int(host_net.link) == NetSession.Link.TOGETHER
			and int(guest_net.link) == NetSession.Link.TOGETHER,
		"pond: two sessions on protocol %d completed the handshake" % Wire.PROTOCOL)
	_watch_throttle(true)

	# **The host's run first, and its water is the pond.**
	var host_run := _pond_run_scene(host_net, true)
	# **Started at the drop's centre**, not at a quiet start (ocean.md §8.1),
	# which can be anywhere 1,000 or more inside the rim. Everything below
	# happens within about 2,200 units of where the host began, nearly all of
	# it north-east -- the arrival, the deaths, and the division, which puts
	# the host 560 east of the guest and asks for its sister 560 further. From
	# a start near that side of the rim that is past it. Measured at DNA slots
	# phase 1, where it happened in two runs of eight: a start 1,441 units in
	# from the rim, eastward, had the host pinned 328 units outside the water
	# when it divided, and the pond came apart; in the other the host's
	# sister, held back onto the rim, landed beside it and shoved its daughter
	# 27 units. The rim is not what this section is about, and from the centre
	# it is 3,800 units or more from anything here. The start's clearing is the
	# same either way.
	host_run.get_node(^"Food").set("start_mode", &"centre")
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
	# **The mirror** (§2's send set; ocean.md §10.4): the host's send set for
	# the guest -- every body hunting it, or on rules every body within reach
	# coming for it, then the nearest within 1,900, surface to centre, sixty in
	# all -- is in the guest's water within a unit of where the host has it,
	# with the genome of its (id, meals); nothing else.
	#
	# **Held exactly, so a loaded runner cannot fail it and a broken mirror
	# cannot pass it**: against the snapshot the guest applied, found by its
	# sequence among the ones the host recorded building. The send set is the
	# host's own bodies at the instant it was built; each body sent is in the
	# mirror at the place sent, carried by the snapshot's age along its
	# heading, with the genome of its (id, meals); nothing else is there.
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
		"pond: the %d host bodies of the guest's send set are mirrored exactly as"
		% int(exact[0]) + " the snapshot it applied said, carried by its age,"
		+ " with (id, meals) genomes and nothing else%s; live, %.3f units"
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
	_pond_retire(host_food, 3)
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
	# **The free sense, through the host's referee** (net-hardening.md B.2):
	# the one change a worn body ever makes, handed to the guest's run the way
	# the run hands it (`_step_sense_grant`: a sample held, a slot made if there
	# is none) and placed as a player places it -- so what reaches the host is
	# the real run's own PERSON, and the host must take it as the gift.
	# ----------------------------------------------------------------------
	var guest_genome: Node = guest_run.get_node(^"Genome")
	guest_run.set("_sensed", true)
	if not (guest_genome.layout() as Array).has(&""):
		guest_genome.bonus_slots += 1
	var sense := &"stigma"
	var granted: int = guest_genome.gift(sense)
	guest_genome.place((guest_genome.layout() as Array).find(&""))
	var host_ref: Object = host_pond.call("referee_of", 0)
	var fouls_were: int = int(host_ref.call("fouled")) if host_ref != null else -1
	var gifted := await _pond_until(func() -> bool:
		return Genome.tier_of(host_food.bodies()[FoodField.PERSON_SLOT].genome, sense) == 1,
		1.0, pins)
	_says(granted == Genome.Result.HELD and gifted >= 0.0 and host_ref != null
			and int(host_ref.call("fouled")) == fouls_were
			and int((host_ref.get("worn") as Dictionary).get(sense, 0)) == 1,
		"pond: the guest's free sense, a %s, placed as a player places it, is on the"
		% sense + " host's person %.2f s later -- its referee took the run's own PERSON"
		% gifted + " as the gift, with no foul")

	# ----------------------------------------------------------------------
	# **A graze on the guest's side** (ocean.md §10.4, §10.5): a floc settling
	# on the guest's lip is told to it -- SETTLE -- and held in its mirror;
	# settled, the host's water says GRAZED, and the guest is fed by it and does
	# not grow, nor does the host's referee expect it to; and the floc gone is
	# told -- CLEAR.
	# ----------------------------------------------------------------------
	var guest_meta: Node = guest_run.get("_metabolism")
	var hunger_was := float(guest_meta.hunger)
	var grazes: Array = []
	guest_food.grazed.connect(func(worth: float, _at: Vector2) -> void:
		grazes.append([worth, float(guest_meta.hunger)]))
	guest_meta.set_hunger(0.8)
	var graze_r := float(guest_cell.radius)
	var lip := graze_r * Cilia.OVOID_ALONG * Cilia.GAPE_SEAT \
		+ float(guest_cell.gape()) * Cilia.GAPE_BULGE
	var told_were := int(host_pond.get("flocs_told"))
	var cleared_were := int(host_pond.get("flocs_cleared"))
	var expected_was := float(host_ref.get("expected")) if host_ref != null else NAN
	var fouls_before := int(host_ref.call("fouled")) if host_ref != null else -1
	var floc := int(host_food.call("_spawn_floc", landed + Vector2(0.0, -lip), 6.0, false))
	var floc_id := int(host_food.bodies()[floc].id)
	host_food.bodies()[floc].settle = 0.9
	var in_mirror := [false]
	var grazed_in := await _pond_until(func() -> bool:
		if (guest_food.get("_mirror_flocs") as Dictionary).has(floc_id):
			in_mirror[0] = true
		return not grazes.is_empty(), 2.0, pins)
	var cleared := await _pond_until(func() -> bool:
		return not (guest_food.get("_mirror_flocs") as Dictionary).has(floc_id), 1.0, pins)
	var worth := float(grazes[0][0]) if not grazes.is_empty() else -1.0
	var fed_to := float(grazes[0][1]) if not grazes.is_empty() else -1.0
	guest_meta.set_hunger(hunger_was)
	_says(in_mirror[0] and grazed_in >= 0.0 and cleared >= 0.0
			and int(host_pond.get("flocs_told")) > told_were
			and int(host_pond.get("flocs_cleared")) > cleared_were
			and absf(worth - clampf(6.0 / graze_r, FoodField.MEAL_MIN, FoodField.MEAL_MAX))
				<= 1.0 / 255.0
			and fed_to >= 0.0 and fed_to < 0.8
			and is_equal_approx(float(guest_cell.radius), graze_r)
			and is_equal_approx(float(host_food.bodies()[FoodField.PERSON_SLOT].radius),
				graze_r)
			and host_ref != null and float(host_ref.get("expected")) == expected_was
			and int(host_ref.call("fouled")) == fouls_before,
		"pond: a floc settling on the guest's lip is told (SETTLE) and held in its"
		+ " mirror (%s); settled, it is GRAZED at %.2f of a meal %.0f ms later, the"
		% [in_mirror[0], worth, grazed_in * 1000.0] + " guest fed to hunger %.2f from"
		% fed_to + " 0.80 and still r%.2f, the host's referee expecting r%.2f and no"
		% [float(guest_cell.radius), float(host_ref.get("expected")) if host_ref != null
			else NAN] + " foul, and the floc gone told (CLEAR) %.0f ms after"
		% (cleared * 1000.0))

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
	# A settled floc behind the guest, told to it and held in its mirror before
	# it dies -- for the return below.
	var behind := int(host_food.call("_spawn_floc", guest_cell.position
		+ Vector2(0.0, 160.0), 6.0, true))
	var behind_id := int(host_food.bodies()[behind].id)
	var behind_held := await _pond_until(func() -> bool:
		return (guest_food.get("_mirror_flocs") as Dictionary).has(behind_id), 1.0, pins)
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
	# The floc goes while the guest is in the black, where nothing is sent it.
	host_food.call("take_out", behind)

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
	# **Back, it holds only the flocs there are** (ocean.md §10.4): the one
	# that went in the black is not in its mirror, and every one it holds is
	# the host's, told again since the arrival.
	await _pond_until(func() -> bool: return false, 0.3, pins)
	var held_flocs: Dictionary = guest_food.get("_mirror_flocs")
	var ghosts := 0
	for id: int in held_flocs:
		var real := false
		for b: Object in host_food.bodies():
			if bool(b.seeded) and bool(b.inert) and int(b.id) == id:
				real = true
				break
		ghosts += 0 if real else 1
	_says(behind_held >= 0.0 and not held_flocs.has(behind_id) and ghosts == 0,
		"pond: a floc held in the guest's mirror and gone while it was in the black"
		+ " is not in it when it is back (%s), and %d of the %d flocs it holds"
		% [not held_flocs.has(behind_id), ghosts, held_flocs.size()]
		+ " are ones the host no longer has")

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
	# Each facing away from the other, so one mouth only is on a body -- and the
	# guest glided there, as a body swims, with nothing on the way to eat.
	_pond_clear_line(host_food, guest_home, in_mouth, 60.0)
	var eaten := await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) == NormalMode.Life.DYING, 2.0,
		[host_pin, [guest_cell, in_mouth, 0.0, POND_GLIDE]])
	host_food.eaten.disconnect(on_eaten)
	var said_ate: String = _line_of(host_run)
	_says(eaten >= 0.0 and bool(host_ate[0])
			and int(guest_food.died_of) == FoodField.Cause.SWALLOWED
			and int(guest_food.died_by) == FoodField.By.FRIEND
			and said_ate == NormalMode.LINE_ATE,
		"pond: the host swallows the guest -- a meal for the host, SWALLOWED by"
		+ " the friend for the guest, and the host is told '%s'" % said_ate)

	# **A death inside its first breath offers nothing, in a pond as alone**
	# (replay.md §4.5; shared-pond.md §5, Phase 3): the guest was eaten under a
	# second after it tapped back, and its black holds no `watch` -- what Phase 3
	# brings back to the pond is the offer, not a replay of a few frames. Then
	# its tap brings it back beside the host, as it always has.
	var g_short := await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) == NormalMode.Life.WAITING, 1.5, [host_pin])
	var g_span := float((guest_run.get("_recorder") as Node).call(&"span"))
	_says(g_short >= 0.0 and g_span < NormalMode.WATCH_MIN_SECONDS
			and not bool((guest_run.get("_watch_ui") as Control).visible),
		"pond: eaten %.2f s into its life, the guest's black offers no `watch` --"
		% g_span + " under the %.0f s a replay needs, in a pond as alone"
		% NormalMode.WATCH_MIN_SECONDS)
	guest_run.call(&"_wake_up")
	var g_back := await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) == NormalMode.Life.RETURNING, 3.5,
		[host_pin])
	guest_home = guest_cell.position
	guest_pin = [guest_cell, guest_home, 0.0]
	pins = [host_pin, guest_pin]
	_says(g_back >= 0.0 and absf(guest_home.distance_to(host_cell.position)
			- host_pond.ARRIVAL) <= POND_ARRIVAL_TOLERANCE and guest_food.mirroring(),
		"pond: and its tap brings it back %.1f units from the host, in the same water"
		% guest_home.distance_to(host_cell.position))

	# **A stronger mouth, brought in the way a player brings one** (B.5): out of
	# the pond, grown alone, and back in by an arrival. A worn body never
	# changes mid-life, so the host's referee keeps the old one if a guest says
	# otherwise -- which is what this used to do, and what R7 now holds it to.
	# **And a second copy of its tail** (automation.md §5.2), which it can hold
	# still: below, it does, in the host's water.
	var genome_guest: Node = guest_run.get_node(^"Genome")
	# **And a push and a dash** (automation.md §18.3 check 23), which its programs
	# use on the autopilot below.
	# **And the toxin, both forms** (dna-slots.md §20.3 check 11): venom on its
	# flank and poison inside -- eight names -- so every word of the guest's from
	# here to the section's end is a venomous, poisonous body's.
	var reentry := await _pond_reenter(guest_run, {&"cytostome": 3, &"cirrus": 1,
		&"flagellum": 2, &"axoneme": 1, &"myoneme": 1, &"toxicyst": 1, &"veneneux": 1},
		[&"cytostome", &"cirrus", &"flagellum", &"axoneme", &"myoneme", &"toxicyst"],
		[host_pin])
	guest_home = guest_cell.position
	guest_pin = [guest_cell, guest_home, 0.0]
	pins = [host_pin, guest_pin]
	# The body it arrived with is on the host before the mouth can be used.
	var worn_three := await _pond_until(func() -> bool:
		return (Genome.tier_of(host_food.bodies()[FoodField.PERSON_SLOT].genome,
			&"cytostome") == 3), 1.0, pins)
	var guest_worn: Dictionary = host_food.bodies()[FoodField.PERSON_SLOT].genome
	_says(reentry >= 0.0 and worn_three >= 0.0 and host_food.person() != null
			and guest_worn.has(&"toxicyst") and guest_worn.has(&"veneneux"),
		"pond: the guest leaves the pond, grows a tier-3 mouth, venom and poison alone"
		+ " and swims back in %.2f s, and the host takes the body it arrives with"
		% reentry)
	# **And a dose the host gives it**: the loads ride the next snapshot's header,
	# and the guest's cell carries what the host counts.
	host_food.call(&"_dose", FoodField.PERSON_SLOT, 0, 2.0, -1, 0.0, false)
	var carried := [0.0, 0.0]
	var dosed_guest := await _pond_until(func() -> bool:
		carried[0] = float((host_food.bodies()[FoodField.PERSON_SLOT].loads
			as PackedFloat64Array)[0])
		carried[1] = float((guest_cell.loads as PackedFloat64Array)[0])
		return (float(carried[1]) > 0.0 and absf(float(carried[0]) - float(carried[1]))
			<= 0.5 / Wire.POND_LOAD_SCALE + 0.05), 2.0, pins)
	_says(dosed_guest >= 0.0,
		"pond: a dose the host gives the guest reaches its cell -- %.2f stacks on the"
		% float(carried[1]) + " guest against the host's %.2f, %.0f ms on"
		% [float(carried[0]), dosed_guest * 1000.0])

	# **The guest holds its tail still, and lets it go** (automation.md §10.2,
	# §18.3 check 7): a motion no guest made before 4-1, swum free in the host's
	# water -- strokes that stop while its hand holds the tail and come back on
	# their own clock -- for the host's referee to judge. Its last word is the
	# section's end: no foul on either honest guest.
	var swum: Array = await _hold_tail_free(guest_cell, host_food, host_cell.position,
		[host_pin])
	_says(int(swum[0]) >= 1 and int(swum[1]) == 0 and int(swum[2]) > 90
			and float(swum[5]) >= float(swum[6]) - 0.1
			and int(guest_run.get("_life")) == NormalMode.Life.ALIVE
			and bool(guest_pond.in_pond) and host_food.person() != null,
		"pond: the guest, its tail at two copies, swims free in the host's water and holds"
		+ " it still %d frames, let go %d strokes and %d while held, %s, %.1f units in %.1f s"
		% [int(swum[2]), int(swum[0]), int(swum[1]), _gap_said(swum), float(swum[3]),
		float(swum[4])])

	# **Check 23: never cut for the autopilot** (automation.md §18.3): the same
	# guest hands its cell to its programs -- resting, holding its tail,
	# swimming, pushing at half and full, dashing, and flipping hold and swim
	# every tick -- in the host's water, for the host's referee to judge.
	var host_fouls_were := _fouls_of(host_pond.get("referees_made"))
	var flown: Dictionary = await _autopilot_free(guest_run, guest_cell, host_food,
		host_cell.position, [host_pin])
	_says(_autopilot_flew(flown) and int(guest_run.get("_life")) == NormalMode.Life.ALIVE
			and bool(guest_pond.in_pond) and host_food.person() != null
			and _fouls_of(host_pond.get("referees_made")) == host_fouls_were,
		"pond: the guest on the autopilot (check 23) %s, in the host's water, and its"
		% _autopilot_said(flown) + " referee called no foul")
	guest_home = guest_cell.position
	guest_pin = [guest_cell, guest_home, 0.0]
	pins = [host_pin, guest_pin]
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
			and _line_of(guest_run) == NormalMode.LINE_ATE,
		"pond: and the guest swallows the host -- the host told its own cause,"
		+ " SWALLOWED by the friend, and the guest told '%s'"
		% _line_of(guest_run))

	# ----------------------------------------------------------------------
	# **UX §9 item 7, from the host's seat** (shared-pond.md §5, Phase 3): the
	# host's black offers `watch`, and the replay draws the guest that ate it,
	# in the frame before the death, on a field, a cell, a genome and grit of
	# the replay's own.
	# ----------------------------------------------------------------------
	var h_offered := await _pond_offered(host_run, [guest_pin])
	var died_here: Vector2 = host_cell.position
	var host_genome: Node = host_run.get_node(^"Genome")
	var died_wearing: Dictionary = host_genome.to_state()
	var host_worn_was: Variant = guest_pond.get("_host_worn")
	var host_said_was := str(host_pond.get("_worn"))
	var h_screen: Node = await _pond_watch(host_run, [guest_pin])
	var h_bound: Array = _replay_bound(host_run, h_screen)
	var h_seen: Array = [{}, Vector2.ZERO, 0.0, null]
	if h_screen != null:
		h_seen = await _replay_friend(h_screen,
			float((host_run.get("_recorder") as Node).call(&"span")), [guest_pin])
	var h_worn := _recorded_worn(host_run)
	var h_peer: Dictionary = h_seen[0]
	var h_apart := (h_seen[1] as Vector2).distance_to(h_peer.get("at", Vector2.INF))
	_says(h_offered >= 0.0 and not h_bound.has(false) and _drawn_as_recorded(h_seen, h_worn)
			and Genome.tier_of(h_worn, &"cytostome") == 3
			and float(h_peer.get("gape", 0.0)) > float(h_seen[2]),
		"pond (UX §9.7, host's seat): eaten by the guest, the host's black offers"
		+ " `watch` %.2f s on; its replay, on a field, cell, genome and grit of its"
		% h_offered + " own %s, draws the guest in the frame before the death where the"
		% str(h_bound) + " recording has it, %.0f units off -- the probe put the host in"
		% h_apart + " its mouth in one frame -- wearing its recorded tiers, cytostome %d,"
		% Genome.tier_of(h_worn, &"cytostome") + " a gape of %.1f over the host's r%.1f"
		% [float(h_peer.get("gape", 0.0)), float(h_seen[2])])

	# ----------------------------------------------------------------------
	# **The host's black does not stop the pond** (owner's row A), **and nor
	# does its replay** (Phase 3): 3 s of the black with the replay up, the
	# host's own water stepping and sent -- snapshots advancing and the water
	# moving on the guest's screen -- while the replay's field is its own and
	# never steps. Nothing the replay writes reaches the wire: the host sends no
	# PERSON, and its cell is where it died and its genome what it died wearing,
	# which is what the pond reads on the black -- for PERSON, and for where a
	# returning guest lands. Closed, the offer is back; then its tap lands it
	# ARRIVAL, 480, from the guest.
	# ----------------------------------------------------------------------
	var seq_from := Wire.seq_of(guest_net.peer_pond())
	var water_from: Array = _pond_places(guest_food)
	var steps_from := int(host_food.get("_frame"))
	var replay_water: Node = h_screen.get("_food") if h_screen != null else null
	await _pond_until(func() -> bool: return false, 3.0, [guest_pin])
	var black_frames := _pond_frames
	var seq_to := Wire.seq_of(guest_net.peer_pond())
	var moved := _pond_moved(water_from, _pond_places(guest_food))
	var steps := int(host_food.get("_frame")) - steps_from
	var still_up: bool = h_screen != null and host_run.get("_replay") == h_screen \
		and h_screen.get("_food") == replay_water and not replay_water.is_processing()
	var sent_none: bool = is_same(guest_pond.get("_host_worn"), host_worn_was) \
		and str(host_pond.get("_worn")) == host_said_was
	var as_died: bool = host_cell.position == died_here \
		and host_genome.to_state() == died_wearing
	_says(int(host_run.get("_life")) == NormalMode.Life.WAITING and still_up
			and host_food.is_processing() and steps > 10
			and seq_to - seq_from >= _pond_snapshots(3.0, black_frames) and moved > 10
			and sent_none and as_died,
		"pond: through %.1f s of the host's black with its replay up, the host's own"
		% (_now() - host_died_at) + " water stepped %d frames and the guest took %d"
		% [steps, seq_to - seq_from] + " snapshots, %d bodies moving, while the"
		% moved + " replay's field stood apart (%s); the host sent no PERSON (%s), and"
		% [str(still_up), str(sent_none)] + " its cell and genome are as it died (%s)"
		% str(as_died))
	if h_screen != null:
		(h_screen.get("_leave_button") as Button).pressed.emit()
	await _pond_frames_on(2, [guest_pin])
	_says(host_run.get("_replay") == null
			and bool((host_run.get("_watch_ui") as Control).visible)
			and int(host_run.get("_life")) == NormalMode.Life.WAITING,
		"pond: closed with `leave`, the host's replay leaves it on its black with"
		+ " `watch` offered again")
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
	# **Check 24 on a phone host** (automation.md §10.3, §18.3): the guest
	# divides with a program on -- the autopilot off, so nothing it does moves
	# -- and its sister carries that list into the host's water, the rule of a
	# gene no build declares among it.
	var guest_library: RefCounted = guest_run.get("_library")
	var guest_program := int(guest_library.call(&"add_new"))
	guest_library.call(&"set_lines", guest_program, PackedStringArray(SISTER_LINES))
	guest_library.call(&"switch", guest_program, true)
	guest_run.call(&"_library_changed")
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
	# **The guest grows to r40 on real meals** (B.5): its size is what the host
	# fed it, so a radius set by hand would be clamped, and its OUT and its
	# sister refused. The host is its own authority, and is set.
	var fed := await _pond_feed(host_food, guest_cell, pins)
	_says(fed >= 0 and is_equal_approx(float(guest_cell.radius), CellBody.DIVIDE_RADIUS),
		"pond: the guest grows to r%.0f on %d meals the host's water fed it"
		% [float(guest_cell.radius), fed])
	host_cell.radius = CellBody.DIVIDE_RADIUS
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
		for i in bodies.size():
			var b: Object = bodies[i]
			if not b.seeded or b.person != null:
				continue
			for spot: Vector2 in spots:
				if (b.pos as Vector2).distance_to(spot) < float(b.radius) + 90.0:
					_pond_retire(host_food, i)
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
	# **The daughter the guest declines carries a gene her body does not wear**
	# -- expression is a roll, so a DNA often holds one -- and only her DNA can
	# say it: with it, a sister made of her body alone is told apart from one
	# made of her DNA (check 24). Both lean to the first daughter, below.
	var declined: Dictionary = (guest_run.get("_daughters") as Array)[1]
	var unworn := &""
	for gene: StringName in [&"ampulla", &"stigma", &"palp", &"ocellus", &"chemocyte"]:
		if not (declined["body"] as Dictionary).has(gene) \
				and not (declined["tiers"] as Dictionary).has(gene):
			unworn = gene
			break
	(declined["tiers"] as Dictionary)[unworn] = 2
	var declined_dna: Dictionary = (declined["tiers"] as Dictionary).duplicate()
	var declined_body: Dictionary = (declined["body"] as Dictionary).duplicate()
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
		# **A new slot in the drop is a slot too** (ocean.md §4): one past the
		# end, which had no serial to change.
		var renumbered: Array = [] if bool(sister["appended"]) else [int(sister["slot"])]
		if not bool(sister["was_free"]) or sister["changed"] != renumbered \
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
	# **Check 24 on a phone host**: the guest's sister is the one that came with
	# no record -- the host's own is its mother's child -- and she came with her
	# DNA and her list, read with the host's own vocabulary.
	var from_guest := {}
	for each: Dictionary in sisters:
		if int(each["mother"]) == 0:
			from_guest = each
	var placed_list: Array = _list_said(from_guest.get("brain"))
	var kept_list: Array = _list_said(from_guest.get("body_brain"))
	_says(not from_guest.is_empty() and unworn != &""
			and _by_name(from_guest["dna"]) == _by_name(declined_dna)
			and _by_name(from_guest["body_dna"]) == _by_name(declined_dna)
			and _by_name(from_guest["tiers"]) == _by_name(declined_body)
			and not (from_guest["genome"] as Dictionary).has(unworn)
			and placed_list[0] == PackedStringArray(SISTER_LINES)
			and placed_list[1] == [false, false, true, false]
			and kept_list[0] == PackedStringArray(SISTER_LINES)
			and int(from_guest["parent"]) == FoodField.Descent.NOBODY
			and int(from_guest["generation"]) == 1
			and int(from_guest["lineage"]) == int(from_guest["id"]),
		"pond (check 24): the guest's declined daughter arrives in the host's water"
		+ " with her DNA, %s -- %s at 2 copies, which her body does not wear -- and"
		% [str(from_guest.get("body_dna", {})), unworn] + " the list her cell ran,"
		+ " %d lines read with the host's own vocabulary, the rule of a gene it does"
		% SISTER_LINES.size() + " not know kept as it came and never firing; the"
		+ " founder of a line of her own (id %d)" % int(from_guest.get("id", -1)))
	guest_library.call(&"delete", guest_program)
	guest_run.call(&"_library_changed")
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
	# host stopped again, the guest held, and the host's own water taking the
	# guest -- its KILLED the first word the guest hears. **The host makes the
	# kill** (B.5): a KILLED put straight in the guest's queue would be a death
	# the host never decided, and its DIED one the referee reports as starving.
	# ----------------------------------------------------------------------
	await _pond_until(func() -> bool: return false, 0.2, pins)
	modes = _pond_stop(host_run)
	host_net.set_process(false)
	await _pond_until(func() -> bool: return bool(guest_run.get("_held")), 2.5,
		[guest_pin])
	var was_held := bool(guest_run.get("_held"))
	var victim: Object = host_food.person()
	if victim != null:
		host_food.call("_person_gone", FoodField.Cause.SWALLOWED, FoodField.By.WATER,
			victim)
	await _pond_until(func() -> bool:
		return int(guest_run.get("_life")) != NormalMode.Life.ALIVE, 0.5, [])
	var corpse_at: Vector2 = guest_cell.position
	var metabolism: Node = guest_run.get_node(^"Metabolism")
	var corpse_on := [guest_cell.is_processing() or metabolism.is_processing()]
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
	# **A dead guest watches while the host plays on** (shared-pond.md §5,
	# Phase 3), on the black of the death above -- whose sixty seconds hold a
	# body brought in and a division, so the replay opens on bodies this cell
	# no longer wears. The pond tells the host what this cell wears whenever it
	# changes, as PERSON, and the host's referee holds a guest to the body it
	# arrived with: a replay written onto the run's own genome would say the
	# first of those bodies within a frame, and every loop after, and be fouled
	# for it. So for a second of it, the host running again: no PERSON judged,
	# no foul, the guest's cell and genome as the death left them, and the host's
	# water stepping. Android Back closes it and the offer is back; watched again
	# it is a new screen of its own with the friend in it, and Esc closes that.
	# ----------------------------------------------------------------------
	_pond_start(host_run, modes)
	host_net.set_process(true)
	var w_offered := await _pond_offered(guest_run, [])
	var w_ref: Object = host_pond.call("referee_of", 0)
	var w_judged := int((w_ref.get("judged") as Dictionary)["person"]) if w_ref != null else -1
	var w_fouls := int(w_ref.call("fouled")) if w_ref != null else -1
	var w_said := str(guest_pond.get("_worn"))
	var w_wearing: Dictionary = guest_genome.to_state()
	var w_at: Vector2 = guest_cell.position
	var w_bodies := 0
	for row: Array in ((guest_run.get("_recorder") as Node).call(&"deltas") as Array):
		if int(row[1]) == RecorderNode.Delta.PLAYER:
			w_bodies += 1
	var w_steps := int(host_food.get("_frame"))
	var w_screen: Node = await _pond_watch(guest_run, [])
	var w_bound: Array = _replay_bound(guest_run, w_screen)
	await _pond_until(func() -> bool: return false, 1.0, [])
	var w_judged_now := int((w_ref.get("judged") as Dictionary)["person"]) \
		if w_ref != null else -2
	var w_fouls_now := int(w_ref.call("fouled")) if w_ref != null else -2
	w_steps = int(host_food.get("_frame")) - w_steps
	_says(w_offered >= 0.0 and not w_bound.has(false) and w_bodies >= 2
			and w_screen != null and guest_run.get("_replay") == w_screen
			and w_judged_now == w_judged and w_fouls_now == w_fouls
			and str(guest_pond.get("_worn")) == w_said
			and guest_genome.to_state() == w_wearing and guest_cell.position == w_at
			and host_food.is_processing() and w_steps > 10,
		"pond: a dead guest watches while the host plays on -- a replay of %d bodies'"
		% w_bodies + " genomes, on nodes of its own %s; through a second of it the"
		% str(w_bound) + " host's water stepped %d frames, its referee judged %d PERSON"
		% [w_steps, w_judged_now - w_judged] + " and called %d fouls, and the guest's"
		% (w_fouls_now - w_fouls) + " cell and genome are as the death left them")
	var w_first := w_screen.get_instance_id() if w_screen != null else 0
	guest_run.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	var w_closed: bool = guest_run.get("_replay") == null
	await _pond_frames_on(1, [])
	var w_offered_again := bool((guest_run.get("_watch_ui") as Control).visible)
	var w_again: Node = await _pond_watch(guest_run, [])
	var w_again_bound: Array = _replay_bound(guest_run, w_again)
	var w_again_seen: Array = [{}, Vector2.ZERO, 0.0, null]
	if w_again != null:
		w_again_seen = await _replay_friend(w_again,
			float((guest_run.get("_recorder") as Node).call(&"span")), [])
	# Read before Esc frees it.
	var w_twice: bool = w_again != null and w_again.get_instance_id() != w_first \
		and not w_again_bound.has(false) \
		and _drawn_as_recorded(w_again_seen, _recorded_worn(guest_run))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _pond_frames_on(2, [])
	esc = esc.duplicate()
	esc.pressed = false
	Input.parse_input_event(esc)
	var w_esc: bool = guest_run.get("_replay") == null \
		and bool((guest_run.get("_watch_ui") as Control).visible) \
		and int(guest_run.get("_life")) == NormalMode.Life.WAITING
	_says(w_closed and w_offered_again and w_twice and w_esc,
		"pond: Back closes the dead guest's replay with `watch` offered again (%s,"
		% str(w_closed) + " %s); watched twice it is a new screen on nodes of its own %s,"
		% [str(w_offered_again), str(w_again_bound)] + " the host drawn as recorded (%s),"
		% str(w_twice) + " and Esc closes that one -- the run never left its black (%s)"
		% str(w_esc))
	# The tap, for the next check, on the black as a player's is.
	guest_run.call(&"_wake_up")

	# ----------------------------------------------------------------------
	# **The link goes while the guest is coming back** (review, the first
	# finding): a takeover inside the 0.9 s of RETURNING. It used to stop the
	# fresh water outright, as for a cell on the black, and nothing started it
	# again -- the guest came back alive into water where nothing moved and
	# nothing could be smelt. The host answers the tap taken above, and the
	# guest's own link is cut the moment it is returning.
	# ----------------------------------------------------------------------
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
	# its own drop again -- the one it set aside as it joined, frozen, taken up
	# again (ocean.md §9.1) -- keeping its body, genome, generation and hunger.
	# ----------------------------------------------------------------------
	await _pond_until(func() -> bool: return false, 0.2, pins)
	# Half a bar, so a takeover that lost the hunger -- back to fed, or to
	# anything else -- shows. The body's own is put back after the check, so
	# what follows sees the run it saw.
	var guest_met: Node = guest_run.get_node(^"Metabolism")
	var own_hunger: float = guest_met.hunger
	guest_met.set_hunger(0.5)
	var kept := [guest_cell.radius, (guest_run.get_node(^"Genome")).tiers().duplicate(),
		int(guest_run.get("_generation")), float(guest_met.hunger)]
	var own: Dictionary = guest_run.get("_own_drop")
	var own_seed := int(own.get("seed", -1))
	var own_age := float(own.get("age", -1.0))
	var closed_at := _now()
	host_net.close()
	var took := await _pond_until(func() -> bool: return not guest_food.mirroring(),
		1.0, [guest_pin])
	var took_frames := _pond_frames
	var fresh: bool = not own.is_empty() and guest_food.owns_drop() \
		and int(guest_food.drop_seed) == own_seed and guest_food.drop_age() >= own_age \
		and guest_food.drop_age() < own_age + 1.0 \
		and (guest_run.get("_own_drop") as Dictionary).is_empty()
	var now_kept := [guest_cell.radius, (guest_run.get_node(^"Genome")).tiers(),
		int(guest_run.get("_generation")), float(guest_met.hunger)]
	# Kept, less what the body spent while the host went: the second the wait
	# allows at rest, and one stroke, which at the thirty-second pace is up to
	# 0.06 of the bar on its own (energy.md §7).
	var spent_max: float = (1.0 + CellBody.STROKE_COST * Stats.at(&"impulse_speed", 
		Stats.table(&"impulse_speed").size() - 1)) / float(guest_met.HUNGER_SECONDS)
	var gained := float(now_kept[3]) - float(kept[3])
	_says(took >= 0.0 and took_frames <= _pond_budget(0.1) and fresh
			and is_equal_approx(float(kept[0]), float(now_kept[0]))
			and kept[1] == now_kept[1] and int(kept[2]) == int(now_kept[2])
			and gained > -0.01 and gained < spent_max + 0.01,
		"pond: the host closes and the guest takes over %d frames later (0.1 s"
		% took_frames + " at 60 fps is %d; %.0f ms here) in its own drop again, as it"
		% [_pond_budget(0.1), (took if took >= 0.0 else _now() - closed_at) * 1000.0]
		+ " set it aside (drop %d, %.1f s old then, %d bodies now),"
		% [own_seed, own_age, guest_food.drop_bodies()]
		+ " keeping r%.2f, its genome, generation %d and hunger %.2f (set to %.2f)"
		% [float(now_kept[0]), int(now_kept[2]), float(now_kept[3]), float(kept[3])])
	guest_met.set_hunger(own_hunger)

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
	guest_run.call("_on_pond_arrived", guest_cell.position + Vector2(480.0, 0.0), 0.0,
		Vector2.ZERO, 0.0)
	var dropped: bool = float(guest_run.get("_water_beat")) < 0.0 \
		and not bool(guest_run.get("_swap_pending")) and not guest_food.mirroring() \
		and not bool(guest_pond.in_pond)
	guest_run.set("_split", NormalMode.Split.NONE)
	_says(dropped, "pond: an ARRIVE that lands mid-division drops the swap -- no"
		+ " beat, no mirror, not in the pond")
	guest_run.set("_swap_pending", true)
	guest_run.set("_menu_open", true)
	guest_run.call("_on_pond_arrived", guest_cell.position + Vector2(480.0, 0.0), 0.0,
		Vector2.ZERO, 0.0)
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
	_watch_throttle(false)
	_says(_throttle_reads > 0
			and _throttle_lowest == ENetPacketPeer.PACKET_THROTTLE_SCALE,
		"pond: no ENet peer's packet throttle fell under the section's load --"
		+ " lowest %d of %d over %d readings" % [_throttle_lowest,
			ENetPacketPeer.PACKET_THROTTLE_SCALE, _throttle_reads])
	# **And the gate never touched an honest peer** (net-hardening.md A.7): two
	# real runs through every stage of a pond's life, host and both guests.
	var tally: Array = _tally_end()
	_says(_limits_clean(tally[0]) and int(tally[1]) == 3,
		"pond: across %d sessions the gate struck nothing, dropped nothing, cut" % int(tally[1])
		+ " nothing and refused nobody, and the budgets it watches would have done"
		+ " none of it either -- the host's socket took %.1f KB and %d"
		% [float(tally[0]["peak_bytes"]) / 1024.0, roundi(float(tally[0]["peak_datagrams"]))]
		+ " datagrams in its busiest second%s" % _limits_unclean([tally[0]]))
	# **And the referee never called a foul on either honest guest** (B.5): two
	# real runs through every stage of a pond's life -- arriving, eating, being
	# eaten, the black, a stronger body brought in, dividing, a quiet host -- is
	# the strongest guard against a false one there is.
	var pond_referees: Array = host_pond.get("referees_made")
	var judged_states := 0
	for referee: Object in pond_referees:
		judged_states += int((referee.get("judged") as Dictionary)["state"])
	_says(float(tally[0].get("fouls", 0.0)) == 0.0 and pond_referees.size() == 2
			and judged_states > 100,
		"pond: and the host's referee called no foul on either honest guest -- %s"
		% _referee_said(pond_referees))
	print("[net-probe] NOTE pond took %.1f s and %d frames, at most %d a second"
		% [_now() - began, Engine.get_process_frames() - began_frames, Engine.max_fps])
	await _check_pond_referee()
	await _check_pond_kept()
	Engine.max_fps = ceiling


# ---------------------------------------------------------------------------
# **Your cells, in slots, in a pond too** (docs/design/cells.md §2, §6.3): a host and
# a guest, each with worlds and cells of its own -- a folder each -- made by runs of
# the game alone. The host's full vision has two cells, the third generation's
# selected in slot 2 beside the fifth's in slot 1, and its point of view one of the
# sixth; the guest's point of view has one of the seventh, selected, and its full
# vision one of the third. The host opens its selected world in full vision, as the
# pond, on its selected cell, **resumed in place** -- the drop moved under it since
# by point of view's quiet start, so in place is read in the frame of the rim it
# was kept with. The guest joins in point of view on its own. Left there, **each
# keeps its cell into its own selected slot** -- the guest's `elsewhere`, its place
# its own world as it was set aside -- every other slot as it was, no file new, and
# each world with no cell in it. Alone again, the guest's full vision resumes in
# place, and **point of view's cell comes home to its own world at a quiet place**:
# the drop moved under it, which its next keep records as its place. Nothing on the
# wire is new: a view, a slot or a name is never said there.
# ---------------------------------------------------------------------------

## Where `pond, kept` keeps the two players' worlds and cells: a folder each.
const KEPT_ROOT := "user://net_probe_kept"
## **Your cells** (cells.md): the slots, the index and a cell's file.
const Cells := preload("res://game/normal/cells.gd")
const CellSave := preload("res://game/normal/cell_save.gd")
## **Your worlds**: which one a run plays, and where its file is.
const Drops := preload("res://game/normal/drops.gd")


func _check_pond_kept() -> void:
	var began := _now()
	var began_frames := Engine.get_process_frames()
	var full_key := RunState.cell_key(RunState.Mode.FULL_VISION)
	var pov_key := RunState.cell_key(RunState.Mode.POV)
	var host_root := KEPT_ROOT.path_join("host")
	var guest_root := KEPT_ROOT.path_join("guest")
	_forget_kept_worlds()
	# **Cells in slots, by runs alone**: `[folder, view, slot, generation]`, each
	# selected as it is made -- the last of each view stays selected.
	var made := [[host_root, RunState.Mode.FULL_VISION, 1, 5],
		[host_root, RunState.Mode.FULL_VISION, 2, 3], [host_root, RunState.Mode.POV, 1, 6],
		[guest_root, RunState.Mode.FULL_VISION, 1, 3], [guest_root, RunState.Mode.POV, 1, 7]]
	for one: Array in made:
		var root := str(one[0])
		DirAccess.make_dir_recursive_absolute(root)
		Cells.select(RunState.cell_key(int(one[1])), int(one[2]), root)
		var alone := _kept_run_scene(null, root, int(one[1]))
		get_tree().root.add_child.call_deferred(alone)
		await alone.ready
		alone.set("_generation", int(one[3]))
		alone.notification(NOTIFICATION_APPLICATION_PAUSED)
		alone.queue_free()
		await get_tree().process_frame
	var generations: Array = []
	for one: Array in made:
		generations.append(int((_kept_slot(str(one[0]), RunState.cell_key(int(one[1])),
			int(one[2])).get("cell", {}) as Dictionary).get("generation", 0)))
	var host_files := _kept_files(host_root)
	var guest_files := _kept_files(guest_root)
	var host_slot := _kept_slot(host_root, full_key, 2)
	var host_world := DropSave.read(Drops.path_of(1, host_root))
	var guest_world := DropSave.read(Drops.path_of(1, guest_root))
	# **The pond**: the host's world in full vision, the guest's in point of view.
	var host_net: Node = await _session("KeptHost")
	var guest_net: Node = await _session("KeptGuest")
	host_net.host()
	guest_net.join("127.0.0.1")
	await _until_link(guest_net, NetSession.Link.TOGETHER)
	await _until_link(host_net, NetSession.Link.TOGETHER)
	var host_run := _kept_run_scene(host_net, host_root, RunState.Mode.FULL_VISION)
	get_tree().root.add_child.call_deferred(host_run)
	await host_run.ready
	var host_food: Node = host_run.get_node(^"Food")
	# **In place**: where the slot keeps it, from the rim it was kept with, against
	# where it is now, from the rim now -- the drop has moved since.
	var host_moved := 0.0
	var host_in_place := false
	if not host_slot.is_empty() and not host_world.is_empty():
		var rim_now: Vector2 = (host_food.call(&"basin") as RefCounted).get("center")
		host_moved = rim_now.distance_to(host_slot["where"]["rim"])
		var host_at: Vector2 = host_run.get_node(^"Cell").get("position")
		host_in_place = (host_at - rim_now).distance_to((host_slot["cell"]["body"]["at"] as Vector2)
			- (host_slot["where"]["rim"] as Vector2)) < 0.01
	await _pond_until(func() -> bool: return bool(guest_net.peer_pond_open()), 2.0, [])
	var guest_run := _kept_run_scene(guest_net, guest_root, RunState.Mode.POV)
	get_tree().root.add_child.call_deferred(guest_run)
	await guest_run.ready
	var guest_pond: Object = guest_run.get("_pond")
	var arrived := await _pond_until(func() -> bool: return bool(guest_pond.in_pond), 3.0, [])
	var host_plays := [bool(host_run.get("_resumed")), int(host_run.get("_generation")),
		int(host_run.get("_cell_slot")), host_in_place, bool(host_food.pond_open())]
	var guest_plays := [bool(guest_run.get("_resumed")), int(guest_run.get("_generation")),
		int(guest_run.get("_cell_slot")), arrived >= 0.0]
	# **Each left where it is**: the app paused, a keep.
	host_run.notification(NOTIFICATION_APPLICATION_PAUSED)
	guest_run.notification(NOTIFICATION_APPLICATION_PAUSED)
	var host_kept_slot := _kept_slot(host_root, full_key, 2)
	var guest_kept_slot := _kept_slot(guest_root, pov_key, 1)
	var host_world_after := DropSave.read(Drops.path_of(1, host_root))
	var guest_world_after := DropSave.read(Drops.path_of(1, guest_root))
	var host_kept := [int((host_kept_slot.get("cell", {}) as Dictionary).get("generation", 0)),
		bool((host_kept_slot.get("cell", {}) as Dictionary).get("elsewhere", false)),
		_kept_where(host_kept_slot, host_world_after),
		_kept_others(host_root, host_files, [Cells.path_of(full_key, 2, host_root)]),
		_kept_bare(host_world_after)]
	var guest_kept := [int((guest_kept_slot.get("cell", {}) as Dictionary).get("generation", 0)),
		bool((guest_kept_slot.get("cell", {}) as Dictionary).get("elsewhere", false)),
		_kept_where(guest_kept_slot, guest_world_after),
		_kept_others(guest_root, guest_files, [Cells.path_of(pov_key, 1, guest_root)]),
		_kept_bare(guest_world_after) and not guest_world.is_empty()
			and int(guest_world_after["drop"]["seed"]) == int(guest_world["drop"]["seed"])]
	guest_run.queue_free()
	host_run.queue_free()
	guest_net.close()
	host_net.close()
	await _wait(0.3)
	# **The guest alone again**, in each view: full vision's cell in place, the drop
	# where it was; point of view's home at a quiet place, which its keep records.
	var rim: Vector2 = guest_world_after["drop"]["rim_centre"] \
		if not guest_world_after.is_empty() else Vector2.INF
	var back: Array = []
	var home: Array = []
	for mode: int in [RunState.Mode.FULL_VISION, RunState.Mode.POV]:
		var alone := _kept_run_scene(null, guest_root, mode)
		get_tree().root.add_child.call_deferred(alone)
		await alone.ready
		var basin: RefCounted = (alone.get_node(^"Food")).call(&"basin")
		var centre: Vector2 = basin.get("center") if basin != null else Vector2.ZERO
		back.append([bool(alone.get("_resumed")), int(alone.get("_generation")),
			centre.is_equal_approx(rim)])
		if mode == RunState.Mode.POV:
			var place := (alone.get_node(^"Cell").get("position") as Vector2) - centre
			alone.notification(NOTIFICATION_APPLICATION_PAUSED)
			var slot := _kept_slot(guest_root, pov_key, 1)
			var world := DropSave.read(Drops.path_of(1, guest_root))
			var cell: Dictionary = slot.get("cell", {})
			home = [not slot.is_empty() and not bool(cell.get("elsewhere", false)),
				_kept_where(slot, world), not slot.is_empty() and ((cell["body"]["at"] as Vector2)
				- (slot["where"]["rim"] as Vector2)).distance_to(place) < 0.01]
		alone.queue_free()
		await get_tree().process_frame
	_forget_kept_worlds()
	_says(generations == [5, 3, 6, 3, 7] and host_moved > 1.0
			and host_plays == [true, 3, 2, true, true] and guest_plays == [true, 7, 1, true]
			and host_kept == [3, false, true, true, true]
			and guest_kept == [7, true, true, true, true]
			and back == [[true, 3, true], [true, 7, false]] and home == [true, true, true],
		("pond, kept: a host and a guest with cells in slots of their own (made, by generation:"
		+ " %s) -- the host opens its world in full vision on its selected cell [resumed,"
		+ " generation, slot, in place, the pond] %s, the drop moved %.0f under it since; the"
		+ " guest joins in point of view on its own %s; left there, the host keeps [generation,"
		+ " elsewhere, its own world, every other slot as it was and none new, the world with no"
		+ " cell] %s and the guest %s, its place its own world as it was set aside; alone again,"
		+ " the guest's world gives [resumed, generation, the drop where it was] %s -- full"
		+ " vision's own cell in place, and point of view's home from the friend's water at a"
		+ " quiet place, which its keep records [not elsewhere, its own world, its place] %s") % [
		str(generations), str(host_plays), host_moved, str(guest_plays), str(host_kept),
		str(guest_kept), str(back), str(home)])
	print("[net-probe] NOTE pond, kept took %.1f s and %d frames"
		% [_now() - began, Engine.get_process_frames() - began_frames])


## A run of the game on [param net] -- null for one alone -- playing the selected
## world and the selected cell of the folder [param root], in [param mode], on the
## shipped scheme.
func _kept_run_scene(net: Node, root: String, mode: int) -> Node:
	NetSession.current = net
	var run: Node = load(RUN_SCENE).instantiate()
	run.set("mode", mode)
	run.set("scheme", 0)
	run.set("keep", Drops.selected_in(root))
	run.set("cells_at", Cells.selected_in(root))
	run.set("library_at", "")
	return run


## [param view]'s slot [param slot] in the folder [param root], read and never
## moved: an empty Dictionary for none.
static func _kept_slot(root: String, view: String, slot: int) -> Dictionary:
	return CellSave.peek(Cells.path_of(view, slot, root))


## **Whether [param slot] keeps its cell in [param world]**: the folder's world 1,
## that drop's number, and the rim it was kept with.
static func _kept_where(slot: Dictionary, world: Dictionary) -> bool:
	if slot.is_empty() or world.is_empty() or (slot["where"] as Dictionary).is_empty():
		return false
	var where: Dictionary = slot["where"]
	return int(where["world"]) == 1 and int(where["drop"]) == int(world["drop"]["seed"]) \
		and (where["rim"] as Vector2).is_equal_approx(world["drop"]["rim_centre"])


## **Every file of [param root]'s cells, with its bytes**: the index and the
## folder's files, by name.
static func _kept_files(root: String) -> Dictionary:
	var out := {}
	for path: String in [root.path_join(Cells.INDEX), root.path_join(Cells.INDEX_TMP)]:
		if FileAccess.file_exists(path):
			out[path] = FileAccess.get_file_as_bytes(path)
	var folder := Cells.folder_of(root)
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			out[folder.path_join(file)] = FileAccess.get_file_as_bytes(folder.path_join(file))
	return out


## Whether [param root]'s cells are [param before] but for the files [param played]:
## the same files, and every other one the same bytes.
static func _kept_others(root: String, before: Dictionary, played: Array) -> bool:
	var now := _kept_files(root)
	if now.keys().size() != before.keys().size():
		return false
	for path: String in before:
		if not now.has(path):
			return false
		if not played.has(path) and now[path] != before[path]:
			return false
	return true


## **The player's own cells on this machine**, by path, with their bytes: what no
## server and no probe may write.
static func _own_cells() -> Dictionary:
	return _kept_files(Cells.ROOT)


## Whether a world's file keeps no cell: `cell` empty and no `cells`.
static func _kept_bare(world: Dictionary) -> bool:
	return not world.is_empty() and (world["cell"] as Dictionary).is_empty() \
		and not world.has(DropSave.CELLS)


## Nothing of `pond, kept` left in `user://`.
func _forget_kept_worlds() -> void:
	for root: String in [KEPT_ROOT.path_join("host"), KEPT_ROOT.path_join("guest")]:
		for dir: String in [Cells.folder_of(root), root]:
			if not DirAccess.dir_exists_absolute(dir):
				continue
			for file: String in DirAccess.get_files_at(dir):
				DirAccess.remove_absolute(dir.path_join(file))
			DirAccess.remove_absolute(dir)
	if DirAccess.dir_exists_absolute(KEPT_ROOT):
		for file: String in DirAccess.get_files_at(KEPT_ROOT):
			DirAccess.remove_absolute(KEPT_ROOT.path_join(file))
		DirAccess.remove_absolute(KEPT_ROOT)


# ---------------------------------------------------------------------------
# **The referee on a real host** (net-hardening.md B.5, R5-R11): a host run
# whose water is the pond, and a guest that is not a run -- a bare session
# driven by hand, which is exactly what a modified client is: it sends
# whatever it is told to. Watched for R5-R10, so one guest can break every rule
# in a few seconds without being cut at the third: the verdicts stand the same
# watched or enforced, and every foul is counted with its weight. Then enforced
# for R11, which is the cut.
# ---------------------------------------------------------------------------

func _check_pond_referee() -> void:
	var began := _now()
	var began_frames := Engine.get_process_frames()
	var host_net: Node = await _session("RefereeHost")
	host_net.host()
	host_net.enforce_referee = false
	var host_run := _pond_run_scene(host_net, true)
	get_tree().root.add_child.call_deferred(host_run)
	await host_run.ready
	var host_cell: Node = host_run.get_node(^"Cell")
	var host_food: Node = host_run.get_node(^"Food")
	var host_pond: Object = host_run.get("_pond")
	# An organ on the host's own cell, so its membrane can mark a friend's call.
	(host_run.get_node(^"Genome")).express({&"cytostome": 1, &"cirrus": 1,
		&"flagellum": 1, &"ampulla": 1}, [&"cytostome", &"cirrus", &"flagellum",
		&"ampulla"])
	var host_pin := [host_cell, host_cell.position, 0.0]
	var marks: Array = []
	var on_mark := func(kind: StringName, _info: Dictionary) -> void:
		if kind == &"ping":
			marks.append(kind)
	host_run.get_node(^"Membrane").bus.sensation.connect(on_mark)
	var guest: Node = await _session("RefereeGuest")
	guest.join("127.0.0.1")
	await _until_link(guest, NetSession.Link.TOGETHER)
	var worn := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"ampulla": 1}
	var order: Array = [&"cytostome", &"cirrus", &"flagellum", &"ampulla"]
	var body := [Vector2.ZERO, 0.0, CellBody.BASE_RADIUS, false]
	var arrived := await _ref_by_hand(guest, worn, order, body, host_food, host_pin)
	var ref: Referee = host_pond.call("referee_of", 0)
	var at: Vector2 = body[0]
	_says(arrived and ref != null and bool(ref.arrived),
		"pond referee: a guest driven by hand -- a bare session, as a modified client"
		+ " is -- arrives in a host's water and is judged, watched")

	# **R5: OUT at r30**, after the one meal the host fed it: kept in the water,
	# fouled, and bitten there all the same.
	var tip := CellBody.BASE_RADIUS * Cilia.OVOID_ALONG * Cilia.GAPE_SEAT \
		+ CellBody.gape_of(Catalogue.born(), CellBody.BASE_RADIUS) * Cilia.GAPE_BULGE
	var mouth_at: Vector2 = at + Vector2(0.0, -tip)
	var morsel := _pond_pose(host_food, 4, 7.0, {}, mouth_at, 0.0)
	var morsel_serial := int(morsel.serial)
	var fed := await _ref_until(func() -> bool:
		if int(morsel.serial) == morsel_serial:
			morsel.pos = mouth_at
		return is_equal_approx(float(ref.expected), 30.0), 1.0, guest, body, host_pin)
	body[2] = 30.0
	body[3] = true
	var points := _ref_points(host_net)
	var out_called := int(ref.called.get(Referee.OUT, 0))
	await _ref_until(func() -> bool:
		return int(ref.called.get(Referee.OUT, 0)) > out_called, 1.0, guest, body,
		host_pin)
	var out_points := _ref_points(host_net) - points
	var person: Object = host_food.person()
	var kept_in: bool = person != null and bool(person.in_water)
	var bites := [0]
	var on_touch := func(what: int, _a: Vector2, _l: float, _b: int, _g: StringName) -> void:
		if what == FoodField.Contact.BITTEN:
			bites[0] = int(bites[0]) + 1
	host_food.person_touched.connect(on_touch)
	var chewer_at: Vector2 = at + Vector2(47.0, 0.0)
	var chewer := _pond_pose(host_food, 3, 20.0, {&"cytostome": 1, &"flagellum": 1},
		chewer_at, _pond_face(chewer_at, at))
	var chewer_serial := int(chewer.serial)
	var bitten := await _ref_until(func() -> bool:
		if int(chewer.serial) == chewer_serial:
			chewer.pos = chewer_at
			chewer.heading = _pond_face(chewer_at, at)
		return int(bites[0]) > 0, 1.0, guest, body, host_pin)
	host_food.person_touched.disconnect(on_touch)
	_pond_retire(host_food, 3)
	body[3] = false
	var pb: Object = host_food.bodies()[FoodField.PERSON_SLOT]
	_says(fed >= 0.0 and kept_in and bitten >= 0.0 and float(pb.wound) > 0.0
			and is_equal_approx(out_points, Referee.WEIGHT_OUT),
		"pond referee R5: OUT at r30, after the one meal it was fed, keeps the guest in"
		+ " the host's water, fouls %.0f points, and a chewer bites it there" % out_points
		+ " (wound %.3f)" % float(pb.wound))

	# **R6: a SISTER with no division**: nothing placed.
	var sisters: Array = host_food.get("sisters")
	var sisters_were := sisters.size()
	points = _ref_points(host_net)
	guest.send_event(Wire.EVENT_SISTER, Wire.sister_payload(at + Vector2(560.0, 0.0),
		0.0, Referee.DAUGHTER_RADIUS, {&"cytostome": 1}))
	await _ref_until(func() -> bool: return int(ref.judged["sister"]) >= 1, 1.0, guest,
		body, host_pin)
	_says(sisters.size() == sisters_were
			and is_equal_approx(_ref_points(host_net) - points, Referee.WEIGHT_SISTER),
		"pond referee R6: a SISTER with no division places nothing and fouls %.0f"
		% (_ref_points(host_net) - points) + " points")

	# **R7: a new body mid-life after a bite, a tier-3 mouth, the gift twice.**
	var wound_was := float(pb.wound)
	var grace_was := float(person.first_hunt)
	var serial_was := int(pb.serial)
	var persons := int(ref.judged["person"])
	await _ref_until(func() -> bool: return false, 0.55, guest, body, host_pin)
	points = _ref_points(host_net)
	guest.send_event(Wire.EVENT_PERSON, Wire.person_payload(true, worn, order))
	await _ref_until(func() -> bool: return int(ref.judged["person"]) > persons, 1.0,
		guest, body, host_pin)
	var renew_points := _ref_points(host_net) - points
	var unrenewed: bool = int(pb.serial) == serial_was and float(pb.wound) <= wound_was \
		and float(pb.wound) > wound_was - 0.05 and float(person.first_hunt) < grace_was
	await _ref_until(func() -> bool: return false, 0.55, guest, body, host_pin)
	var bigger := worn.duplicate()
	bigger[&"cytostome"] = 3
	persons = int(ref.judged["person"])
	points = _ref_points(host_net)
	guest.send_event(Wire.EVENT_PERSON, Wire.person_payload(false, bigger, order))
	await _ref_until(func() -> bool: return int(ref.judged["person"]) > persons, 1.0,
		guest, body, host_pin)
	var mouth_points := _ref_points(host_net) - points
	var mouth := Genome.tier_of(pb.genome, &"cytostome")
	var gifted := worn.duplicate()
	gifted[&"stigma"] = 1
	var gifted_order := order.duplicate()
	gifted_order.append(&"stigma")
	persons = int(ref.judged["person"])
	guest.send_event(Wire.EVENT_PERSON, Wire.person_payload(false, gifted, gifted_order))
	await _ref_until(func() -> bool: return int(ref.judged["person"]) > persons, 1.0,
		guest, body, host_pin)
	var took_gift := Genome.tier_of(pb.genome, &"stigma") == 1
	await _ref_until(func() -> bool: return false, 0.55, guest, body, host_pin)
	var greedy := gifted.duplicate()
	greedy[&"ocellus"] = 1
	var greedy_order := gifted_order.duplicate()
	greedy_order.append(&"ocellus")
	persons = int(ref.judged["person"])
	points = _ref_points(host_net)
	guest.send_event(Wire.EVENT_PERSON, Wire.person_payload(false, greedy, greedy_order))
	await _ref_until(func() -> bool: return int(ref.judged["person"]) > persons, 1.0,
		guest, body, host_pin)
	var greedy_points := _ref_points(host_net) - points
	_says(unrenewed and is_equal_approx(renew_points, Referee.WEIGHT_BODY) and mouth == 1
			and is_equal_approx(mouth_points, Referee.WEIGHT_BODY) and took_gift
			and Genome.tier_of(pb.genome, &"ocellus") == 0
			and is_equal_approx(greedy_points, Referee.WEIGHT_BODY),
		"pond referee R7: a new body mid-life after a bite leaves the wound (%.3f) and"
		% float(pb.wound) + " the grace (%.1f s) as they were and fouls %.0f;"
		% [float(person.first_hunt), renew_points] + " a tier-3 mouth leaves it at"
		+ " %d and fouls %.0f; the gift is taken and a second one refused, %.0f"
		% [mouth, mouth_points, greedy_points])

	# **R8: five ENTERs in one second while swimming here**: no arrival, no
	# genome sent, the wound untouched.
	await _ref_until(func() -> bool: return false, 0.55, guest, body, host_pin)
	var genomes_were := int(host_pond.genomes_sent)
	wound_was = float(pb.wound)
	var enters := int(ref.judged["enter"])
	guest.pond_events.clear()
	points = _ref_points(host_net)
	for i in 5:
		guest.send_event(Wire.EVENT_ENTER, Wire.enter_payload(CellBody.BASE_RADIUS))
		await _ref_until(func() -> bool: return false, 0.2, guest, body, host_pin)
	await _ref_until(func() -> bool: return int(ref.judged["enter"]) >= enters + 5, 1.0,
		guest, body, host_pin)
	var arrivals := 0
	for frame: PackedByteArray in guest.pond_events:
		if Wire.event_type(frame) == Wire.EVENT_ARRIVE:
			arrivals += 1
	var enter_points := _ref_points(host_net) - points
	# **No genome resent**: an arrival resends every body in the send set --
	# `genomes_were` of them, all it has ever sent this guest -- where the water
	# going on sends one now and then, as a body eats and changes version.
	var resent := int(host_pond.genomes_sent) - genomes_were
	_says(arrivals == 0 and resent < 10 and resent < genomes_were / 2
			and float(pb.wound) <= wound_was and float(pb.wound) > wound_was - 0.05
			and enter_points >= Referee.WEIGHT_ENTER and enter_points <= 3.0
			and host_food.person() == person,
		"pond referee R8: five ENTERs in a second while swimming here bring no ARRIVE"
		+ " and no arrival's genomes (%d sent by the water going on, where an arrival" % resent
		+ " resends all %d), leave the wound as it was, and foul %.0f points -- once"
		% [genomes_were, enter_points] + " each half second")

	# **R9: DIED, swallowed by the friend, while alive**: taken out all the same,
	# and reported as starving.
	var died_as: Array = []
	var on_died := func(cause: int, _by: int, _at: Vector2, _mine: bool) -> void:
		died_as.append(cause)
	host_pond.friend_died.connect(on_died)
	points = _ref_points(host_net)
	guest.send_event(Wire.EVENT_DIED, Wire.died_payload(FoodField.Cause.SWALLOWED,
		FoodField.By.FRIEND, at))
	var gone := await _ref_until(func() -> bool: return host_food.person() == null, 1.0,
		guest, body, host_pin)
	host_pond.friend_died.disconnect(on_died)
	_says(gone >= 0.0 and died_as == [FoodField.Cause.STARVED]
			and is_equal_approx(_ref_points(host_net) - points, Referee.WEIGHT_DIED),
		"pond referee R9: DIED, swallowed by the friend, said of a body still alive"
		+ " takes it out, is reported as %s, and fouls %.0f points"
		% [str(died_as), _ref_points(host_net) - points])

	# **R10: a call from 3,000 units off, and one with the wrong reach**: nothing
	# on the host's membrane -- where an honest call, first, is marked. Back from
	# that death first, as a born cell must come back.
	body[2] = CellBody.BASE_RADIUS
	var back := await _ref_by_hand(guest, worn, order, body, host_food, host_pin)
	ref = host_pond.call("referee_of", 0)
	# **The host's own organ held quiet from here on**, so every mark is a
	# friend's call: its pulse, and the echoes of one already out, are marks too
	# -- and in the drop the rim answers every one (ocean.md §3.2). The returns
	# that have already landed go with them. The run processes before its `Food`
	# child, so it posts a frame's landed returns at the next frame, and one that
	# landed as the honest call was heard was marked inside the window. Held from
	# before the honest call as well, so the mark that call waits for is its own
	# and not an echo's, with the call then marked in the window.
	var quiet := func() -> void:
		host_food.set("_ping_clock", 1000.0)
		(host_food.get("_echoes") as Array).clear()
		(host_food.get("pings") as Array).clear()
	quiet.call()
	marks.clear()
	guest.shout(body[0], CellBody.BASE_RADIUS, 1100.0)
	var heard := await _ref_until(func() -> bool:
		quiet.call()
		return not marks.is_empty(), 1.0, guest, body, host_pin)
	var shouts := int(ref.judged["shout"])
	quiet.call()
	marks.clear()
	points = _ref_points(host_net)
	guest.shout((body[0] as Vector2) + Vector2(3000.0, 0.0), CellBody.BASE_RADIUS, 1100.0)
	await _ref_until(func() -> bool:
		quiet.call()
		return int(ref.judged["shout"]) > shouts, 1.0, guest, body, host_pin)
	await _ref_until(func() -> bool:
		quiet.call()
		return false, 0.55, guest, body, host_pin)
	guest.shout(body[0], CellBody.BASE_RADIUS, 1500.0)
	await _ref_until(func() -> bool:
		quiet.call()
		return int(ref.judged["shout"]) > shouts + 1, 1.0, guest, body, host_pin)
	await _ref_until(func() -> bool:
		quiet.call()
		return false, 0.2, guest, body, host_pin)
	_says(back and heard >= 0.0 and marks.is_empty()
			and is_equal_approx(_ref_points(host_net) - points, 2.0 * Referee.WEIGHT_SHOUT),
		"pond referee R10: an honest call is marked on the host's membrane; one from"
		+ " 3,000 units off and one reaching 1,500 with a tier-1 organ are not, and"
		+ " foul %.0f points" % (_ref_points(host_net) - points))
	var watched: Dictionary = host_net.gate_counts
	_says(int(watched["referee_strikes"]) == 0 and float(watched["points"]) == 0.0
			and int(watched["referee_would_strikes"]) > 0 and int(watched["cuts"]) == 0,
		"pond referee: watched, %d fouls were counted and logged and none cost a"
		% int(watched["referee_would_strikes"]) + " point -- while every verdict above"
		+ " stood")

	# **A guest made whole by harm** (docs/design/dna-slots.md §6.2, §20.3 check
	# 5): the host's poison in it, as a dose, wears into its wound until it is
	# whole -- the host decides that death as every other: POISONED, by the
	# friend, told the guest as a KILLED with that cause -- and the host draws its
	# friend gone as one that starved, stopped where it was, eaten by nobody.
	var poisoned_as: Array = []
	var on_poisoned := func(cause: int, by: int, _at: Vector2, mine: bool) -> void:
		poisoned_as.append([cause, by, mine])
	host_pond.friend_died.connect(on_poisoned)
	guest.pond_events.clear()
	host_food.call(&"_dose", FoodField.PERSON_SLOT, 0, 400.0, FoodField.TARGET_PLAYER, 0.0,
		false)
	var poisoned := await _ref_until(func() -> bool: return host_food.person() == null,
		2.0, guest, body, host_pin)
	host_pond.friend_died.disconnect(on_poisoned)
	var killed_by: Array = []
	for frame: PackedByteArray in guest.pond_events:
		if Wire.event_type(frame) == Wire.EVENT_CONTACT:
			var said := Wire.take_contact(frame)
			if said.size() == 6 and int(said[0]) == FoodField.Contact.KILLED:
				killed_by.append([int(said[5]), int(said[3])])
	var drawn := int((host_run.get("_vision") as Node).get("_fr_gone"))
	_says(poisoned >= 0.0 and poisoned_as == [[FoodField.Cause.POISONED,
			FoodField.By.FRIEND, false]]
			and killed_by == [[FoodField.Cause.POISONED, FoodField.By.FRIEND]]
			and drawn == VisionLayer.Gone.STARVED,
		"pond referee: a guest the host's poison makes whole dies %.0f ms on --"
		% (poisoned * 1000.0) + " %s, told it as %s -- and the host draws it gone as"
		% [str(poisoned_as), str(killed_by)] + " one that starved (%s)"
		% ("STARVED" if drawn == VisionLayer.Gone.STARVED else str(drawn)))

	# **R11: a radius lie on every frame, enforced**: cut within 3 s, the guest
	# told REFUSE_BROKEN.
	guest.close()
	await _pond_until(func() -> bool: return (host_net.guests() as Array).is_empty(), 2.0,
		[host_pin])
	host_net.enforce_referee = true
	var cheat: Node = await _session("RefereeCheat")
	cheat.join("127.0.0.1")
	await _until_link(cheat, NetSession.Link.TOGETHER)
	var lie := [Vector2.ZERO, 0.0, CellBody.BASE_RADIUS, false]
	var in_water := await _ref_by_hand(cheat, Catalogue.born(), Catalogue.born().keys(), lie,
		host_food, host_pin)
	lie[2] = 40.0
	var cut := await _ref_until(func() -> bool:
		return int(cheat.link) == NetSession.Link.REFUSED, 4.0, cheat, lie, host_pin)
	_says(in_water and cut >= 0.0 and cut <= 3.0
			and str(cheat.trouble) == Wire.reason_says(Wire.REFUSE_BROKEN)
			and int(host_net.gate_counts["cuts"]) == 1,
		"pond referee R11: a guest claiming r40 on every frame, fed nothing, is cut"
		+ " %.2f s after its first lie and told '%s'" % [cut, str(cheat.trouble)])
	host_run.get_node(^"Membrane").bus.sensation.disconnect(on_mark)
	host_run.queue_free()
	cheat.close()
	host_net.close()
	await _wait(0.3)
	print("[net-probe] NOTE pond referee took %.1f s and %d frames, at most %d a second"
		% [_now() - began, Engine.get_process_frames() - began_frames, Engine.max_fps])


## **A guest driven by hand arrives**: its body said, its ENTER, the host's
## ARRIVE, and its state frames from there until the host has it in the water.
## [param body] is `[place, heading, radius, out]`, reported every frame by
## [method _ref_until]; the arrival is written into it.
func _ref_by_hand(guest: Node, tiers: Dictionary, order: Array, body: Array,
		host_food: Node, host_pin: Array) -> bool:
	guest.pond_events.clear()
	guest.set_pond(false, false)
	guest.send_event(Wire.EVENT_PERSON, Wire.person_payload(true, tiers, order))
	guest.send_event(Wire.EVENT_ENTER, Wire.enter_payload(float(body[2])))
	var got: Array = []
	await _pond_until(func() -> bool:
		for frame: PackedByteArray in guest.pond_events:
			if Wire.event_type(frame) == Wire.EVENT_ARRIVE and got.is_empty():
				got.append_array(Wire.take_arrive(frame))
		return not got.is_empty(), 1.0, [host_pin])
	if got.is_empty():
		return false
	body[0] = got[0]
	body[1] = float(got[1])
	var placed := await _ref_until(func() -> bool:
		var p: Object = host_food.person()
		return p != null and bool(p.in_water), 1.0, guest, body, host_pin)
	return placed >= 0.0


## [method _pond_until] with a hand-driven guest reporting [param body] --
## `[place, heading, radius, out]` -- every frame, in the pond.
func _ref_until(done: Callable, seconds: float, guest: Node, body: Array,
		host_pin: Array) -> float:
	return await _pond_until(func() -> bool:
		guest.report_body(body[0], float(body[1]), float(body[2]))
		guest.set_pond(true, bool(body[3]))
		return done.call(), seconds, [host_pin])


## Every point the referee's fouls have put on a session's ledgers, enforced
## and watched.
func _ref_points(net: Node) -> float:
	var counts: Dictionary = net.gate_counts
	return float(counts["referee_points"]) + float(counts["referee_would_points"])


## A run of the game on [param net], in full vision so its view works the
## friend out, on the shipped scheme -- and the host's with a watched field.
func _pond_run_scene(net: Node, watched: bool) -> Node:
	NetSession.current = net
	var run: Node = load(RUN_SCENE).instantiate()
	run.set("mode", 1)
	run.set("scheme", 0)
	# **A probe's run keeps no drop** (ocean.md §9): the game's default is the
	# player's own file, which two runs in one process would share.
	run.set("keep", "")
	run.set("library_at", "")
	if watched:
		run.get_node(^"Food").set_script(PondWatchedFood)
	return run


## Frames until [param done] says so or [param seconds] of wall time pass,
## holding every `[cell, at, heading]` in [param pins] still where it is put.
## Returns the seconds it took, or -1 for never.
##
## **A pin with a fourth number glides there instead**, at that many units a
## second, and holds once it arrives. A guest is never teleported: the host's
## referee holds its place to the path a body could swim (net-hardening.md
## B.5), and a guest pinned 480 units away in one frame is a guest that did
## not swim there. [constant POND_GLIDE] is well inside that budget.
func _pond_until(done: Callable, seconds: float, pins: Array) -> float:
	var from := _now()
	var last := from
	var pinned_at := _clock()
	_pond_frames = 0
	_pond_frame_max = 0.0
	while true:
		var clock := _clock()
		for pin: Array in pins:
			var cell: Node = pin[0]
			if pin.size() > 3:
				cell.position = (cell.position as Vector2).move_toward(pin[1],
					float(pin[3]) * (clock - pinned_at))
			else:
				cell.position = pin[1]
			cell.heading = float(pin[2])
			cell.velocity = Vector2.ZERO
		pinned_at = clock
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


## **A guest brings a new genome into the pond the way a player does** (B.5):
## out of the pond -- the takeover's own two calls, without its beat -- the
## body grown alone, here by [method Genome.express], and back in by the swap
## the run asks for at its next ordinary frame: PERSON with a new body, ENTER,
## the host's ARRIVE and the beat. Waits for the run to be swimming first, and
## returns the seconds from leaving to being back in, or -1.
func _pond_reenter(run: Node, tiers: Dictionary, order: Array, pins: Array) -> float:
	var pond: Object = run.get("_pond")
	var food: Node = run.get_node(^"Food")
	await _pond_until(func() -> bool:
		return int(run.get("_life")) == NormalMode.Life.ALIVE \
			and float(run.get("_water_beat")) < 0.0, 2.0, pins)
	var from := _now()
	pond.mirror_ended()
	food.leave_mirror()
	(run.get_node(^"Genome")).express(tiers, order)
	var back := await _pond_until(func() -> bool:
		return bool(pond.in_pond) and food.mirroring() \
			and float(run.get("_water_beat")) < 0.0, 4.0, pins)
	return _now() - from if back >= 0.0 else -1.0


# --- The replay in a pond (shared-pond.md §5, Phase 3) -------------------------

## **The black of a run in a pond, with `watch` on it**: seconds until the run
## waits on its black and offers its replay, or -1.
func _pond_offered(run: Node, pins: Array) -> float:
	return await _pond_until(func() -> bool:
		return int(run.get("_life")) == NormalMode.Life.WAITING \
			and bool((run.get("_watch_ui") as Control).visible), 2.0, pins)


## **The replay raised as its button raises it**, a frame or two on: the
## screen, or null.
func _pond_watch(run: Node, pins: Array) -> Node:
	run.call(&"_watch")
	await _pond_frames_on(2, pins)
	return run.get("_replay")


## [param count] frames, holding [param pins] where they are put.
func _pond_frames_on(count: int, pins: Array) -> void:
	var left := [count]
	await _pond_until(func() -> bool:
		left[0] -= 1
		return int(left[0]) < 0, 2.0, pins)


## **What a replay in a pond is writing onto, against [param run]'s own**:
## `[its own field, not stepping, a person slot in it, cell genome and grit of
## its own, none of them in the tree]` -- every one of them true is what lets the
## water and the wire go on under it.
func _replay_bound(run: Node, screen: Node) -> Array:
	if screen == null:
		return [false, false, false, false, false]
	var water: Node = screen.get("_food")
	var own: Array = [screen.get("_cell"), screen.get("_genome"), screen.get("_motes")]
	var theirs: Array = [run.get_node(^"Cell"), run.get_node(^"Genome"),
		run.get_node(^"Motes")]
	var apart := true
	var loose := true
	for k in own.size():
		if own[k] == null or own[k] == theirs[k]:
			apart = false
		elif (own[k] as Node).is_inside_tree():
			loose = false
	return [water != null and water != run.get_node(^"Food"),
		water != null and not water.is_processing(),
		water != null and bool(water.call(&"pond_open")), apart, loose]


## **The friend as the replay's world view draws them at [param at] seconds into
## the window**, sought there and its history forgotten, so they are drawn as a
## view coming on draws them -- in it, no arrival fade: `[the view's friend, the
## watched cell's place and radius, the friend's body in the field]`.
##
## Sought a hair past [param at]: a row the recorder writes in a frame carries
## the run's own clock, a double, and the ring keeps that frame's time as a
## float, which can round below it -- so a seek to exactly the last frame's time
## can stop short of what the friend put on in that frame. A played replay never
## lands there at all; it loops at the end.
func _replay_friend(screen: Node, at: float, pins: Array) -> Array:
	screen.set_process(false)
	screen.call(&"_rewind")
	screen.set("_at", at + 1e-4)
	screen.call(&"_seek")
	screen.set("_forget", false)
	var panes: Node = screen.get("_panes")
	panes.call(&"rewound")
	await _pond_frames_on(2, pins)
	var peer: Dictionary = ((panes.get("_vision") as Node).get("_peer") as Dictionary) \
		.duplicate()
	var cell: Node = screen.get("_cell")
	var bodies: Array = (screen.get("_food") as Node).call(&"bodies")
	var pb: Object = bodies[FoodField.PERSON_SLOT] \
		if bodies.size() > FoodField.PERSON_SLOT else null
	screen.set_process(true)
	return [peer, cell.position, float(cell.radius), pb]


## **What the recording says the friend wore last**: its newest PERSON row's
## tiers, or empty.
func _recorded_worn(run: Node) -> Dictionary:
	var worn := {}
	for row: Array in ((run.get("_recorder") as Node).call(&"deltas") as Array):
		if int(row[1]) == RecorderNode.Delta.PERSON:
			worn = (row[3] as Array)[0]
	return worn


## A replay's world view drew the friend as the recording has them: their worn
## tiers, the field's body where it is, at [param seen] -- the view's `_peer`.
static func _drawn_as_recorded(seen: Array, worn: Dictionary) -> bool:
	var peer: Dictionary = seen[0]
	var pb: Object = seen[3]
	return peer.has("tiers") and pb != null and float(pb.radius) > 0.0 \
		and peer["tiers"] == worn and not worn.is_empty() \
		and (peer["at"] as Vector2) == (pb.pos as Vector2) \
		and float(peer["alpha"]) > 0.99


## **A guest's tail of two copies, held still and let go** (automation.md §5.2,
## §10.2; §18.3 check 7): the one motion 4-1 gives a guest that none made before.
## [param cell] is let swim free the way it was pinned facing -- turned by nothing
## but the water, as a hand that holds only its tail turns it -- through water
## cleared of every body round it, so nothing takes it meanwhile, while its hand
## holds the tail by `↓`'s action for a second, lets go until a stroke beats on
## the clock it kept, holds and lets go twice more, and then flips its hold every
## frame for 120 frames, the fastest a hand can: a tail that beat at once when let
## go would stroke on every other frame, far past the speed and the turn the
## host's referee allows. [param pins] hold the rest, and [param other], the one
## other cell, is an arrival's distance off, past any swim this takes -- or the
## strokes say -1. Every other cell in this process wears one copy, so the key
## holds nothing of theirs. `[strokes, strokes while held, frames held, units
## swum, seconds, the closest two strokes in seconds, the tier's shortest gap]`.
func _hold_tail_free(cell: Node, water: Node, other: Vector2, pins: Array) -> Array:
	var at: Vector2 = cell.position
	var ahead := Vector2(sin(float(cell.heading)), -cos(float(cell.heading)))
	_pond_clear_line(water, at - ahead * 300.0, at + ahead * 600.0, 600.0)
	var strokes := [0, 0]
	var beats := PackedFloat64Array()
	var on_stroke := func(_strength: float) -> void:
		strokes[0] += 1
		beats.append(_clock())
		if Input.is_action_pressed(&"ui_down"):
			strokes[1] += 1
	cell.impulsed.connect(on_stroke)
	var held := [0]
	var watch := func() -> bool:
		if bool(cell.call(&"tail_held")):
			held[0] += 1
		return false
	var from := _now()
	Input.action_press(&"ui_down")
	await _pond_until(watch, 1.0, pins)
	Input.action_release(&"ui_down")
	var beat: int = strokes[0]
	await _pond_until(func() -> bool:
		watch.call()
		return strokes[0] > beat, 3.2, pins)
	for k in 2:
		Input.action_press(&"ui_down")
		await _pond_until(watch, 0.4, pins)
		Input.action_release(&"ui_down")
		await _pond_until(watch, 0.2, pins)
	for k in 120:
		if k % 2 == 0:
			Input.action_press(&"ui_down")
		else:
			Input.action_release(&"ui_down")
		var ticks := [0]
		await _pond_until(func() -> bool:
			ticks[0] += 1
			if ticks[0] > 1:
				watch.call()
			return ticks[0] > 1, 1.0, pins)
	Input.action_release(&"ui_down")
	await _pond_until(watch, 0.2, pins)
	cell.impulsed.disconnect(on_stroke)
	var closest := INF
	for n in range(1, beats.size()):
		closest = minf(closest, beats[n] - beats[n - 1])
	# It never came near the other cell: what this asks is the referee's word on
	# a hold, not a meeting.
	if (cell.position as Vector2).distance_to(other) < 200.0:
		strokes[0] = -1
	return [strokes[0], strokes[1], held[0], at.distance_to(cell.position), _now() - from,
		closest, float(cell.call(&"impulse_gap_min"))]


## How close [method _hold_tail_free]'s strokes came, said against the tier's
## shortest gap.
func _gap_said(swum: Array) -> String:
	if is_inf(float(swum[5])):
		return "no two to compare (shortest gap %.2f s)" % float(swum[6])
	return "the closest two %.2f s apart (shortest gap %.2f s)" % [float(swum[5]),
		float(swum[6])]


## **Check 23** (automation.md §18.3): [param run]'s cell handed to its programs
## and swum free in [param water], away from [param other], while the programs
## rest, hold the tail, swim and push at half, turn at random pushing at full and
## dashing, and then flip hold and swim at every tick of the instincts -- each as
## a program of the run's own library, given as the page gives it, and the
## autopilot switched on and off by the run's own switch. Returns what was seen:
## the outputs that acted, frames the tail was held, strokes, dashes, the push
## strengths claimed, the flips of the tail and the ticks.
func _autopilot_free(run: Node, cell: Node, water: Node, other: Vector2,
		pins: Array) -> Dictionary:
	var at: Vector2 = cell.position
	var ahead := Vector2(sin(float(cell.heading)), -cos(float(cell.heading)))
	_pond_clear_line(water, at - ahead * 300.0, at + ahead * 900.0, 600.0)
	var library: RefCounted = run.get("_library")
	var instincts: RefCounted = run.get("_instincts")
	var program := int(library.call(&"add_new"))
	library.call(&"switch", program, true)
	var seen := {"acted": {}, "held": 0, "strokes": 0, "dashes": 0, "pushes": {},
		"flips": 0, "ticks": 0, "driving": false, "was_held": bool(cell.call(&"tail_held")),
		"from": int(instincts.get("tick"))}
	var on_stroke := func(_strength: float) -> void: seen["strokes"] = int(seen["strokes"]) + 1
	var on_dash := func(_cost: float) -> void: seen["dashes"] = int(seen["dashes"]) + 1
	cell.impulsed.connect(on_stroke)
	cell.dashed.connect(on_dash)
	var give := func(lines: Array) -> void:
		library.call(&"set_lines", program, PackedStringArray(lines))
		run.call(&"_library_changed")
	var watch := func() -> bool:
		var list: Object = instincts.get("list")
		if list != null and bool(cell.get("autopilot")):
			seen["driving"] = true
			for won: Array in instincts.get("fired"):
				(seen["acted"] as Dictionary)[str((list.get("rules") as Array)[int(won[0])]
					.get("output"))] = true
			var strength := float(instincts.call(&"push_strength"))
			if strength > 0.0:
				(seen["pushes"] as Dictionary)[strength] = true
		var held := bool(cell.call(&"tail_held"))
		if held:
			seen["held"] = int(seen["held"]) + 1
		if held != bool(seen["was_held"]):
			seen["flips"] = int(seen["flips"]) + 1
			seen["was_held"] = held
		return false
	# **The open menu in a pond** (§2.2, §2.4; check 11's last clause, which
	# needs a session): it engages nothing -- it silences the hand and the cell
	# drifts -- and once the autopilot is on, as the page's copy of the icon
	# switches it, the programs drive under it, since in a pond it stops nothing.
	give.call(["always -> body.swim", "always -> axoneme.push 0.5"])
	run.call(&"_toggle_pause")
	await _pond_until(func() -> bool: return false, 0.4, pins)
	seen["menu_open"] = bool(run.get("_menu_open")) and bool(cell.get("steering_off"))
	seen["menu_engaged"] = bool(cell.get("autopilot"))
	run.call(&"_set_autopilot", true)
	var under_menu := [0]
	await _pond_until(func() -> bool:
		if bool(cell.get("autopilot")) and not (instincts.get("fired") as Array).is_empty():
			under_menu[0] += 1
		return false, 0.6, pins)
	seen["menu_drove"] = int(under_menu[0]) > 0 and bool(cell.get("autopilot")) \
		and bool(run.get("_menu_open"))
	run.call(&"_toggle_pause")
	await get_tree().process_frame
	seen["menu_shut_kept"] = bool(cell.get("autopilot")) and not bool(run.get("_menu_open"))
	give.call(["always -> body.rest"])
	for phase: Array in [[["always -> body.rest"], 0.6],
			[["always -> flagellum.hold"], 0.6],
			[["always -> body.swim", "always -> axoneme.push 0.5"], 0.8],
			[["always -> body.turn-random", "always -> axoneme.push 1",
				"always -> myoneme.dash"], 1.8]]:
		give.call(phase[0])
		await _pond_until(watch, float(phase[1]), pins)
	# Hold and swim, flipped at every tick of the instincts.
	var flipping := [int(instincts.get("tick")), true]
	give.call(["always -> flagellum.hold"])
	seen["flips"] = 0
	await _pond_until(func() -> bool:
		var tick := int(instincts.get("tick"))
		if tick != int(flipping[0]):
			flipping[0] = tick
			flipping[1] = not bool(flipping[1])
			give.call(["always -> flagellum.hold"] if bool(flipping[1])
				else ["always -> body.swim"])
		watch.call()
		return false, 1.6, pins)
	run.call(&"_set_autopilot", false)
	await _pond_until(watch, 0.2, pins)
	seen["ticks"] = int(instincts.get("tick")) - int(seen["from"])
	seen["moved"] = at.distance_to(cell.position)
	seen["kept_off"] = not bool(cell.get("autopilot"))
	seen["far"] = (cell.position as Vector2).distance_to(other) >= 200.0
	cell.impulsed.disconnect(on_stroke)
	cell.dashed.disconnect(on_dash)
	library.call(&"delete", program)
	run.call(&"_library_changed")
	return seen


## Whether [method _autopilot_free] saw every motion it asked for.
func _autopilot_flew(seen: Dictionary) -> bool:
	var acted: Dictionary = seen["acted"]
	var pushes: Dictionary = seen["pushes"]
	for output: String in ["body.rest", "flagellum.hold", "body.swim", "axoneme.push",
			"myoneme.dash", "body.turn-random"]:
		if not acted.has(output):
			return false
	return bool(seen["driving"]) and pushes.has(0.5) and pushes.has(1.0) \
		and int(seen["dashes"]) >= 1 and int(seen["held"]) > 30 and int(seen["strokes"]) >= 1 \
		and int(seen["flips"]) >= 6 and bool(seen["kept_off"]) and bool(seen["far"]) \
		and bool(seen["menu_open"]) and not bool(seen["menu_engaged"]) \
		and bool(seen["menu_drove"]) and bool(seen["menu_shut_kept"])


func _autopilot_said(seen: Dictionary) -> String:
	var acted: Array = (seen["acted"] as Dictionary).keys()
	acted.sort()
	return ("is not engaged by its open menu (%s) and drives under it once on (%s, %s);"
		% [str(not bool(seen["menu_engaged"]) and bool(seen["menu_open"])),
		str(seen["menu_drove"]), "kept as it shuts" if bool(seen["menu_shut_kept"])
		else "NOT kept as it shuts"]
		+ " rests, holds, swims, pushes at %s, dashes %d times and flips its tail %d"
		% [", ".join((seen["pushes"] as Dictionary).keys().map(func(p: float) -> String:
			return "%.1f" % p)), int(seen["dashes"]), int(seen["flips"])]
		+ " times over %d ticks -- %s acted, the tail held %d frames, %d strokes, %.0f"
		% [int(seen["ticks"]), ", ".join(acted), int(seen["held"]), int(seen["strokes"]),
		float(seen.get("moved", 0.0))] + " units swum")


## Every foul [param referees] have called between them.
func _fouls_of(referees: Array) -> int:
	var fouls := 0
	for referee: Object in referees:
		fouls += int(referee.call(&"fouled"))
	return fouls


## **Feeds the guest [param cell] to r40 on real meals in the host's water**,
## one morsel at a time on the lip of its mouth -- facing north, as pinned --
## each one an ATE the host decides and the guest grows by. A wide mouth takes
## a morsel in its hollow for no meal, so the morsel is put on the lip itself.
## Returns the meals, or -1.
func _pond_feed(host_food: Node, cell: Node, pins: Array) -> int:
	var meals := 0
	while float(cell.radius) < CellBody.DIVIDE_RADIUS - 0.01 and meals < 6:
		var was := float(cell.radius)
		# The tip of the lip bow, dead ahead: cilia.gd's `_lip` at its middle.
		var tip := was * Cilia.OVOID_ALONG * Cilia.GAPE_SEAT \
			+ float(cell.gape()) * Cilia.GAPE_BULGE
		var at: Vector2 = (cell.position as Vector2) + Vector2(0.0, -tip)
		var morsel := _pond_pose(host_food, 4, 7.0, {}, at, 0.0)
		var serial := int(morsel.serial)
		var grew := await _pond_until(func() -> bool:
			if int(morsel.serial) == serial:
				morsel.pos = at
			return float(cell.radius) > was + 0.01, 1.0, pins)
		if grew < 0.0:
			return -1
		meals += 1
	return meals


## Retires every water body within [param reach] of the segment from
## [param from] to [param to], so a glide along it meets nothing.
func _pond_clear_line(food: Node, from: Vector2, to: Vector2, reach: float) -> void:
	var bodies: Array = food.bodies()
	for i in bodies.size():
		var b: Object = bodies[i]
		if not bool(b.seeded) or b.person != null:
			continue
		var p: Vector2 = b.pos
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, from, to)) \
				< reach + float(b.radius):
			_pond_retire(food, i)


## **What the referees in [param referees] judged, and how near they came to a
## foul**: every input by kind, and each budget's closest call -- the most any
## one input used of what was left, where 100% is a foul.
func _referee_said(referees: Array) -> String:
	var judged := {}
	var closest := {"movement": 0.0, "heading": 0.0, "shouts": 0.0, "arrivals": 0.0,
		"bodies": 0.0}
	var fouls := 0
	var speed := 0.0
	var over := -INF
	for referee: Object in referees:
		var said: Dictionary = referee.get("judged")
		for kind: String in said:
			judged[kind] = int(judged.get(kind, 0)) + int(said[kind])
		closest["movement"] = maxf(closest["movement"], float(referee.move.closest))
		closest["heading"] = maxf(closest["heading"], float(referee.turn.closest))
		closest["shouts"] = maxf(closest["shouts"], float(referee.shouts.closest))
		closest["arrivals"] = maxf(closest["arrivals"], float(referee.enters.closest))
		closest["bodies"] = maxf(closest["bodies"], float(referee.bodies.closest))
		fouls += int(referee.fouled())
		speed = maxf(speed, float(referee.get("worst_speed")))
		over = maxf(over, float(referee.get("worst_radius")))
	var parts: Array[String] = []
	for kind: String in ["state", "person", "enter", "sister", "died", "shout"]:
		parts.append("%d %s" % [int(judged.get(kind, 0)), kind])
	var calls: Array[String] = []
	for budget: String in closest:
		calls.append("%s %.0f%%" % [budget, 100.0 * float(closest[budget])])
	return "%d fouls over %d referee%s; judged %s; closest calls %s; fastest %.0f u/s,"\
		% [fouls, referees.size(), "" if referees.size() == 1 else "s", ", ".join(parts),
			", ".join(calls), speed] + " radius at most %+.2f of what it was fed" % over


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
	var slots: Dictionary = guest_food.get("_mirror_slots")
	var sent := 0
	var worst := 0.0
	var wrong := 0
	var missing := 0
	var ids := {}
	for entry: Array in host_food.pond_entries(true):
		var slot := int(entry[FoodField.ENTRY_SLOT])
		if slot < 0:
			continue
		var id := int(entry[FoodField.Entry.ID])
		ids[id] = true
		sent += 1
		var m := int(slots.get(id, -1))
		if m < 0 or not bool(mirror[m].seeded):
			missing += 1
			continue
		var hb: Object = host_bodies[slot]
		worst = maxf(worst, (mirror[m].pos as Vector2).distance_to(hb.pos))
		if int(mirror[m].meals) != int(hb.meals) or mirror[m].genome != hb.genome:
			wrong += 1
	# In the mirror and not in the host's send set now: one frame of lag can
	# leave a body at the set's edge either side of it, so this is reported.
	var too_far := 0
	for id: int in slots:
		if not ids.has(id):
			too_far += 1
	var self_off: float = (mirror[FoodField.PERSON_SLOT].pos as Vector2).distance_to(
		host_cell.position)
	worst = maxf(worst, self_off)
	return [sent, worst, too_far, wrong, missing, self_off]


## **The guest's water against the snapshot it applied**, exactly: `[bodies
## checked, problems]`, no problems meaning all of it held. The host's watched
## field recorded that snapshot and the water it was built from, found here by
## the sequence the guest applied. The send set is worked out again from that
## water (ocean.md §10.4) -- every body hunting the guest, then the rest whose
## surface lies within SEND_REACH of it, nearest first, SEND_MAX in all -- and
## each body sent must be in the mirror under its id and meals, at the place
## sent (float32 both ways, so exact), heading and speed to half a wire step,
## carried from there by the snapshot's age along that heading, with the genome
## that body wore. Nothing else may be in the mirror but its flocs and the host.
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
	var sent := {}
	for entry: Array in entries:
		if int(entry[FoodField.ENTRY_SLOT]) >= 0:
			sent[int(entry[FoodField.Entry.ID])] = entry
	# The set it should have been, from the water it was built from.
	var should := {}
	var near: Array = []
	var by_id := {}
	for w: Array in water:
		by_id[int(w[1])] = w
		if bool(w[6]):
			should[int(w[1])] = true
		else:
			var gap: float = (w[2] as Vector2).distance_to(you) - float(w[3])
			if gap <= FoodField.SEND_REACH:
				# The host's own order: the surface gap to a sixteenth of a unit,
				# then the slot.
				near.append([(int(clampf(gap, 0.0, 1.0e6) * 16.0) << 24) | int(w[0]),
					int(w[1])])
	near.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for each: Array in near:
		if should.size() >= FoodField.SEND_MAX:
			break
		should[int(each[1])] = true
	for id: int in should:
		if not sent.has(id):
			problems.append("body %d left out" % id)
	for id: int in sent:
		if not should.has(id):
			problems.append("body %d sent" % id)
	var mirror: Array = guest_food.bodies()
	var slots: Dictionary = guest_food.get("_mirror_slots")
	var snap_at: PackedVector2Array = guest_food.get("_snap_at")
	var ahead := minf(float(guest_food.get("_snap_age")), FoodField.CARRY_MAX)
	var step := TAU / float(Wire.BEARING_STEPS)
	var checked := 0
	for id: int in slots:
		if not sent.has(id):
			problems.append("body %d in the mirror, not sent" % id)
	for id: int in sent:
		var entry: Array = sent[id]
		var m := int(slots.get(id, -1))
		checked += 1
		if m < 0 or not bool(mirror[m].seeded) \
				or int(mirror[m].meals) != int(entry[FoodField.Entry.MEALS]):
			problems.append("body %d not in the mirror as sent" % id)
			continue
		var mb: Object = mirror[m]
		var heading := float(mb.heading)
		var speed := float(mb.speed)
		if not snap_at[m].is_equal_approx(entry[FoodField.Entry.AT]) \
				or absf(angle_difference(heading, float(entry[FoodField.Entry.HEADING]))) \
					> step * 0.5 + 1e-4 \
				or absf(speed - float(entry[FoodField.Entry.SPEED])) \
					> Wire.POND_SPEED_STEP * 0.5 + 1e-3:
			problems.append("body %d not where it was sent" % id)
		var carried: Vector2 = snap_at[m] + Vector2(sin(heading), -cos(heading)) \
			* (speed * ahead)
		if (mb.pos as Vector2).distance_to(carried) > 1e-3:
			problems.append("body %d not carried by its age" % id)
		if by_id.has(id) and mb.genome != (by_id[id] as Array)[5]:
			problems.append("body %d wears another genome" % id)
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
	_tally_on(node)
	get_tree().root.add_child.call_deferred(node)
	await node.ready
	return node


## **What the gate did over a whole section, on every side of it** (A.8):
## every session [method _session] makes while tallying, and any other handed
## to [method _tally_on], read as it leaves the tree -- `close()` keeps a
## session's counts for exactly this -- or where it stands, if it has not.
var _tallying := false
var _tallies: Array = []


func _tally_begin() -> void:
	_tallying = true
	_tallies = []


func _tally_on(node: Node) -> void:
	if not _tallying:
		return
	var entry := [node, {}]
	_tallies.append(entry)
	node.tree_exiting.connect(func() -> void:
		entry[1] = (node.get("gate_counts") as Dictionary).duplicate())


## `[counts summed, sessions]`: the peaks are the highest any session saw.
func _tally_end() -> Array:
	_tallying = false
	var sum := {}
	for entry: Array in _tallies:
		var counts: Dictionary = entry[1]
		if counts.is_empty() and is_instance_valid(entry[0]):
			counts = (entry[0] as Node).get("gate_counts")
		for key: String in counts:
			if key.begins_with("peak_"):
				sum[key] = maxf(float(sum.get(key, 0.0)), float(counts[key]))
			else:
				sum[key] = float(sum.get(key, 0.0)) + float(counts[key])
	return [sum, _tallies.size()]


func _says(passed: bool, what: String) -> void:
	if passed:
		print("[net-probe] PASS %s" % what)
		return
	_failed += 1
	print("[net-probe] FAIL %s" % what)


## **The pond line [param run] has queued**, in words. The run keeps a line by name
## and says it in the language of the moment (docs/design/settings.md §3.3); with
## no screen, that is the English the lines are written in.
func _line_of(run: Node) -> String:
	return str(run.call(&"_line_words", run.get(&"_line_next")))


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
	var burst := Vector2(0.0, -1.0) * Stats.at(&"dash_speed", 1)
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


## The ENet peer [param session] reaches [param id] through, or null. Reaching
## for a private member is a thing only tools/ may do.
func _enet_peer(session: Node, id: int) -> ENetPacketPeer:
	# Through the session, which knows which of a server's two listeners holds
	# the id: asking the other one is an engine error line.
	return session.call("enet_peer_of", id)


## `[interval, acceleration, deceleration, throttle]` as [param peer] holds
## them -- empty for no peer, or one the far end has already hung up on, whose
## statistics ENet answers with an error line apiece.
func _throttle_knobs(peer: ENetPacketPeer) -> Array:
	if peer == null or not peer.is_active():
		return []
	return [int(peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_INTERVAL)),
		int(peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_ACCELERATION)),
		int(peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION)),
		int(peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE))]


## **Pinned as net_session.gd pins every peer**: its interval and acceleration,
## a full throttle, and a deceleration of 0 -- written as the literal, so that
## a constant put back to ENet's 2 fails here rather than agreeing with itself.
func _pinned(peer: ENetPacketPeer) -> bool:
	return _throttle_knobs(peer) == [NetSession.THROTTLE_INTERVAL,
		NetSession.THROTTLE_ACCELERATION, 0, ENetPacketPeer.PACKET_THROTTLE_SCALE]


## **Every ENet peer's packet throttle, read every frame** while
## [method _watch_throttle] is on: the lowest any of them showed, and how many
## readings that is. A section that runs load asserts the lowest is still 32.
##
## Not a timing check. Pinned, a throttle cannot fall at all: the fall
## subtracts the deceleration, which is 0, and the one other thing that lowers
## it is ENet's bandwidth limiter, which no host here switches on -- so any
## runner, however loaded, reads 32 every frame, and a reading below it is the
## pin gone. Unpinned, it is issue #61: the server section sank one guest's
## throttle to 0 in one run of three on an idle machine, and the probe passed
## all three without a word.
var _throttle_lowest := 0
var _throttle_reads := 0


func _watch_throttle(on: bool) -> void:
	var frame := get_tree().process_frame
	if on:
		_throttle_lowest = ENetPacketPeer.PACKET_THROTTLE_SCALE
		_throttle_reads = 0
		if not frame.is_connected(_read_throttles):
			frame.connect(_read_throttles)
	elif frame.is_connected(_read_throttles):
		frame.disconnect(_read_throttles)


## Every session in the tree -- the probe's own, under the root, and a server's,
## one below -- and every peer in its bookkeeping, which it enters only after
## pinning it.
func _read_throttles() -> void:
	for top: Node in get_tree().root.get_children():
		for node: Node in [top] + top.get_children():
			if node.get_script() != NetSession:
				continue
			for id: int in node.peer_ids():
				var peer := _enet_peer(node, id)
				if peer == null or not peer.is_active():
					continue
				_throttle_lowest = mini(_throttle_lowest,
					int(peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)))
				_throttle_reads += 1


# ---------------------------------------------------------------------------
# **The dedicated host** (`game/server/`): the pond with no cell of its own and
# two guests, each of whom is told the other is the friend. The guests are two
# real runs of the game on this build's own guest code -- which is a phone's
# guest code, unchanged, exactly what a phone that has never heard of a server
# runs -- so everything here is a phone joining a server.
#
# Then the server's update loop, with no network: a fake update service for the
# decisions, and a loopback HTTP server for the one download it does itself.
# ---------------------------------------------------------------------------

const SERVER_SCENE := "res://game/server/server.tscn"
## **How long a wait here gives anything an unreliable frame carries** -- a
## snapshot, or a guest's state frame. It was made this long for ENet's packet
## throttle, which discards unreliable packets at the sender when a peer's
## round trip jitters -- and three hosts serviced once a frame in one process
## jitter: the server's peer for one guest was measured at 6 in 32, with four
## snapshots in a row that never arrived. net_session.gd now pins every peer's
## throttle at 32 (issue #61) and this section asserts that it never falls, so
## nothing on this loopback throws a frame away any more. The margin stays
## because it is free: every wait returns the moment its answer is in, and the
## NOTE prints the longest one.
const SERVER_UNRELIABLE := 5.0
## The longest any of those waits has taken, for the section's NOTE.
var _server_waited := 0.0
const Updater := preload("res://game/server/updater.gd")
## For its `State` values only, which the fake service below answers in.
const ServiceScript := preload("res://addons/launcher/update_service.gd")
const DropSave := preload("res://game/normal/drop_save.gd")
## **The section's own room** (ocean.md §10.3), where no real server keeps one:
## made at its start, kept at its stop, loaded by the next start, and gone after.
const SERVER_ROOM := "user://net_probe_room/1.save"


func _check_server() -> void:
	var began := _now()
	var began_frames := Engine.get_process_frames()
	var ceiling := Engine.max_fps
	Engine.max_fps = 250
	_tally_begin()
	var server: Node = load(SERVER_SCENE).instantiate()
	server.set("check_updates", false)
	server.set("own_frame_rate", false)
	server.set("quits", false)
	# A book of its own, which stays empty: this section is the LAN's, and a
	# real server's invites in this user:// must not open anything here.
	server.set("pond_root", "user://net_probe_no_invites/")
	# A router of the probe's own that finds nothing: this section asks none.
	server.set("upnp_router", UpnpRouter.new(&"none"))
	# A room of the probe's own, never there before it starts.
	_server_room_gone()
	server.set("room_path", SERVER_ROOM)
	# **And no cell of anyone's** (cells.md §2): the player's own cells on this
	# machine, which the server never reads or writes.
	var cells_before := _own_cells()
	get_tree().root.add_child.call_deferred(server)
	await server.ready
	var net: Node = server.session()
	_tally_on(net)
	var food: Node = server.food()
	var pond: Object = server.pond()
	_says(int(net.link) == NetSession.Link.LISTENING and food.pond_open()
			and food.in_drop() and int(food.drop_bodies()) > FoodField.COUNT
			and not bool(food.in_water) and not bool(food.anchored)
			and food.person(FoodField.PERSON_SLOT) == null
			and food.person(FoodField.PERSON_SLOT + 1) == null
			and int(server.get("rooms_kept")) == 1 and FileAccess.file_exists(SERVER_ROOM),
		"server: listening, its room open as the pond -- a drop of %d bodies, made"
		% int(food.drop_bodies()) + " and kept at once (%d), with no cell of its own"
		% int(server.get("rooms_kept")) + " in it and nobody in either guest's slot")
	_watch_throttle(true)

	var a_net: Node = await _session("ServerGuestA")
	var b_net: Node = await _session("ServerGuestB")
	a_net.join("127.0.0.1")
	await _until_link(a_net, NetSession.Link.TOGETHER)
	b_net.join("127.0.0.1")
	await _until_link(b_net, NetSession.Link.TOGETHER)
	await _pond_until(func() -> bool:
		return ((net.guests() as Array).size() == 2 and bool(a_net.peer_pond_open())
			and bool(b_net.peer_pond_open())), 2.0, [])
	_says(int(a_net.link) == NetSession.Link.TOGETHER
			and int(b_net.link) == NetSession.Link.TOGETHER
			and (net.guests() as Array).size() == 2
			and bool(a_net.peer_pond_open()) and bool(b_net.peer_pond_open()),
		"server: two guests are greeted on protocol %d, and both read its pond"
		% Wire.PROTOCOL + " as open")
	var c_net: Node = await _session("ServerGuestC")
	c_net.join("127.0.0.1")
	await _until_link(c_net, NetSession.Link.REFUSED)
	_says(int(c_net.link) == NetSession.Link.REFUSED
			and str(c_net.trouble) == "already two"
			and (net.guests() as Array).size() == 2,
		"server: a third is refused with '%s', and the two stay" % c_net.trouble)
	c_net.close()
	# **One protocol, other rules** (gene-catalogue.md §11.3): a guest whose
	# catalogue held one more judged gene as it called -- a faster tail -- is
	# refused by the dedicated server on the version check, ahead of the count of
	# its room, and the two stay.
	var rules_net: Node = await _session("ServerGuestRules")
	Catalogue.register(_faster_tail())
	rules_net.join("127.0.0.1")
	Catalogue.forget(Catalogue.organ_of(&"probeswift"))
	await _until_link(rules_net, NetSession.Link.REFUSED)
	_says(int(rules_net.link) == NetSession.Link.REFUSED
			and str(rules_net.trouble) == "different versions"
			and int(rules_net.refused_for) == Wire.REFUSE_PROTOCOL
			and (net.guests() as Array).size() == 2,
		"server: a guest on one more judged gene is refused with '%s' on the version"
		% rules_net.trouble + " check, ahead of the room's count, and the two stay")
	rules_net.close()

	# **A call crosses to the other guest**, as the numbers sent, and never
	# back to the one who made it. Before the runs exist, which drain it.
	var shout_at := Vector2(321.5, -77.25)
	a_net.shout(shout_at, 33.5, 1500.0)
	await _until_heard(b_net, 1)
	await _wait(0.1)
	var heard: Array = b_net.drain_heard()
	var echoed: Array = a_net.drain_heard()
	_says(heard.size() == 1 and (heard[0][0] as Vector2).is_equal_approx(shout_at)
			and is_equal_approx(float(heard[0][1]), 33.5)
			and is_equal_approx(float(heard[0][2]), 1500.0) and echoed.is_empty(),
		"server: a guest's shout reaches the other guest as the numbers sent,"
		+ " and not the guest who made it")

	# **Both runs open inside the pond.** The first has nobody to arrive
	# beside; the second arrives ARRIVAL from the first.
	var a_run := _pond_run_scene(a_net, false)
	get_tree().root.add_child.call_deferred(a_run)
	await a_run.ready
	var a_cell: Node = a_run.get_node(^"Cell")
	var a_food: Node = a_run.get_node(^"Food")
	var a_pond: Object = a_run.get("_pond")
	var a_in := await _pond_until(func() -> bool: return bool(a_pond.in_pond), 3.0, [])
	var a_home: Vector2 = a_cell.position
	var a_pin := [a_cell, a_home, 0.0]
	var b_run := _pond_run_scene(b_net, false)
	get_tree().root.add_child.call_deferred(b_run)
	await b_run.ready
	var b_cell: Node = b_run.get_node(^"Cell")
	var b_food: Node = b_run.get_node(^"Food")
	var b_pond: Object = b_run.get("_pond")
	var b_in := await _pond_until(func() -> bool: return bool(b_pond.in_pond), 3.0,
		[a_pin])
	var b_home: Vector2 = b_cell.position
	var b_pin := [b_cell, b_home, 0.0]
	var pins := [a_pin, b_pin]
	var slot_a := int((pond.call("_guest_by_id", int(a_net.my_id())) as Object).slot)
	var slot_b := int((pond.call("_guest_by_id", int(b_net.my_id())) as Object).slot)
	var apart := b_home.distance_to(a_home)
	_says(a_in >= 0.0 and b_in >= 0.0 and a_food.mirroring() and b_food.mirroring()
			and slot_a != slot_b and absf(apart - float(pond.ARRIVAL))
				<= POND_ARRIVAL_TOLERANCE,
		"server: both guests' runs open inside the pond, in slots %d and %d, and"
		% [slot_a, slot_b] + " the second lands %.2f units from the first (%.0f +-"
		% [apart, float(pond.ARRIVAL)] + " %.0f)" % POND_ARRIVAL_TOLERANCE)

	# **Each mirrors the other as the friend, in slot 68** -- where a guest of a
	# phone has always found the host -- wearing what the other wears. The
	# second guest brings a palp in first, so the genome checked is one it
	# chose: out of the pond, grown alone and back, as a player brings one
	# (B.5) -- a worn body never changes mid-life, and the server's referee would
	# keep the old one.
	var b_genome: Node = b_run.get_node(^"Genome")
	# And a second copy of its tail (automation.md §5.2), which it holds still below.
	# And a push and a dash, which its programs use on the autopilot (check 23).
	# **And the toxin, both forms** (dna-slots.md §20.3 check 11): venom at the
	# back of its free arcs and poison inside -- eight names, for the room's
	# referee and the other guest's mirror.
	var b_brought := await _pond_reenter(b_run, {&"cytostome": 2, &"cirrus": 1,
		&"flagellum": 2, &"palp": 1, &"axoneme": 1, &"myoneme": 1, &"toxicyst": 1,
		&"veneneux": 1}, [&"cytostome", &"cirrus", &"flagellum", &"palp", &"axoneme",
		&"myoneme", &"toxicyst"], [a_pin])
	b_home = b_cell.position
	b_pin = [b_cell, b_home, 0.0]
	pins = [a_pin, b_pin]
	_says(b_brought >= 0.0 and food.person(slot_b) != null,
		"server: the second guest leaves the pond and swims back in with a palp, venom"
		+ " and poison in %.2f s, in slot %d again" % [b_brought,
			int((pond.call("_guest_by_id", int(b_net.my_id())) as Object).slot)])
	# **And a dose the room gives it**, which reaches its cell in its own header.
	food.call(&"_dose", slot_b, 0, 2.0, -1, 0.0, false)
	var b_carried := [0.0]
	var b_dosed := await _server_until(func() -> bool:
		b_carried[0] = float((b_cell.loads as PackedFloat64Array)[0])
		return float(b_carried[0]) > 0.0, pins)
	_says(b_dosed >= 0.0 and float((a_cell.loads as PackedFloat64Array)[0]) == 0.0,
		"server: a dose the room gives the second guest reaches its cell (%.2f stacks)"
		% float(b_carried[0]) + " and the first guest's header carries none")
	var mirrored := await _server_until(func() -> bool:
		var fa: Object = a_food.person()
		var fb: Object = b_food.person()
		return fa != null and fb != null and bool(fa.in_water) and bool(fb.in_water) \
			and a_food.bodies()[FoodField.PERSON_SLOT].genome == b_genome.tiers(), pins)
	await _pond_until(func() -> bool: return false, 0.3, pins)
	# **Settled, not sampled.** Each guest carries the other on by the velocity
	# it last heard until the next report lands (`food.gd`'s `_carry_person`),
	# so one frame is a race: in about fifty full runs this check read 0.834
	# and 1.803 units off once each, at a single frame, and 0.000 in every
	# other. A mirror that is right comes back within a report or two; one
	# that is wrong never does, so the check waits up to a second for both.
	await _pond_until(func() -> bool:
		return (a_food.bodies()[FoodField.PERSON_SLOT].pos as Vector2).distance_to(b_home) \
				< 1.0 \
			and (b_food.bodies()[FoodField.PERSON_SLOT].pos as Vector2).distance_to(a_home) \
				< 1.0, 1.0, pins)
	var a_sees: Vector2 = a_food.bodies()[FoodField.PERSON_SLOT].pos
	var b_sees: Vector2 = b_food.bodies()[FoodField.PERSON_SLOT].pos
	var water_a := 0
	var water_b := 0
	for i in FoodField.PERSON_SLOT:
		water_a += 1 if bool(a_food.bodies()[i].seeded) else 0
		water_b += 1 if bool(b_food.bodies()[i].seeded) else 0
	_says(mirrored >= 0.0 and a_sees.distance_to(b_home) < 1.0
			and b_sees.distance_to(a_home) < 1.0
			and a_food.bodies()[FoodField.PERSON_SLOT].genome == b_genome.tiers()
			and water_a > 10 and water_b > 10
			and int(pond.pond_bytes_max) <= Wire.POND_MAX,
		"server: each guest mirrors the other as the friend in slot 68 -- %.3f and"
		% a_sees.distance_to(b_home) + " %.3f units off where they are, the"
		% b_sees.distance_to(a_home) + " first wearing the palp the second grew"
		+ " -- in water of %d and %d cells; largest snapshot %d B"
		% [water_a, water_b, int(pond.pond_bytes_max)])

	# **The second guest holds its tail still, and lets it go** (automation.md
	# §10.2, §18.3 check 7), swum free in the room: the server's referee judges it,
	# and the section ends on its word -- no foul on any of its guests.
	var b_swum: Array = await _hold_tail_free(b_cell, food, a_cell.position, [a_pin])
	_says(int(b_swum[0]) >= 1 and int(b_swum[1]) == 0 and int(b_swum[2]) > 90
			and float(b_swum[5]) >= float(b_swum[6]) - 0.1
			and int(b_run.get("_life")) == NormalMode.Life.ALIVE
			and food.person(slot_b) != null,
		"server: the second guest, its tail at two copies, swims free in the room and"
		+ " holds it still %d frames, let go %d strokes and %d while held, %s, %.1f units in"
		% [int(b_swum[2]), int(b_swum[0]), int(b_swum[1]), _gap_said(b_swum),
		float(b_swum[3])] + " %.1f s" % float(b_swum[4]))
	# **Check 23 in the room** (automation.md §18.3): the second guest on the
	# autopilot, its programs resting, holding, swimming, pushing, dashing and
	# flipping hold and swim every tick, judged by the server's referee.
	var server_fouls_were := _fouls_of(pond.get("referees_made"))
	var b_flown: Dictionary = await _autopilot_free(b_run, b_cell, food, a_cell.position,
		[a_pin])
	_says(_autopilot_flew(b_flown) and int(b_run.get("_life")) == NormalMode.Life.ALIVE
			and food.person(slot_b) != null
			and _fouls_of(pond.get("referees_made")) == server_fouls_were,
		"server: the second guest on the autopilot (check 23) %s, in the room, and its"
		% _autopilot_said(b_flown) + " referee called no foul")
	b_home = b_cell.position
	b_pin = [b_cell, b_home, 0.0]
	pins = [a_pin, b_pin]

	# **The server decides a meeting of the two, and both hear it.** The guest
	# in slot 68 is this cell's side of the players' rule on a dedicated host,
	# so it is tested eating and being eaten.
	# The first brings a tier-3 mouth in the same way.
	var a_brought := await _pond_reenter(a_run, {&"cytostome": 3, &"cirrus": 1,
		&"flagellum": 1}, [&"cytostome", &"cirrus", &"flagellum"], [b_pin])
	a_home = a_cell.position
	a_pin = [a_cell, a_home, 0.0]
	pins = [a_pin, b_pin]
	await _pond_until(func() -> bool:
		return Genome.tier_of(food.bodies()[slot_a].genome, &"cytostome") == 3,
		1.0, pins)
	var a_ate := [false]
	var on_a_eaten := func(_n: float, _g: StringName, _at: Vector2) -> void:
		a_ate[0] = true
	a_food.eaten.connect(on_a_eaten)
	# Both facing north, so only the first one's mouth is on a body -- the second
	# glided there, as a body swims, with nothing on the way.
	var in_a_mouth: Vector2 = a_home + Vector2(0.0, -(float(a_cell.radius) + 18.0))
	_pond_clear_line(food, b_home, in_a_mouth, 60.0)
	var b_down := await _server_until(func() -> bool:
		return int(b_run.get("_life")) == NormalMode.Life.DYING,
		[a_pin, [b_cell, in_a_mouth, 0.0, POND_GLIDE]])
	var b_slot_empty: bool = food.person(slot_b) == null
	await _pond_until(func() -> bool:
		return (bool(a_ate[0])
			and _line_of(a_run) == NormalMode.LINE_ATE), 1.0, [a_pin])
	a_food.eaten.disconnect(on_a_eaten)
	_says(b_down >= 0.0 and bool(a_ate[0]) and b_slot_empty
			and int(b_food.died_of) == FoodField.Cause.SWALLOWED
			and int(b_food.died_by) == FoodField.By.FRIEND
			and _line_of(a_run) == NormalMode.LINE_ATE,
		"server: the first guest swallows the second -- a meal for the first and"
		+ " '%s' said to it; SWALLOWED by the friend for the second, and its"
		% _line_of(a_run) + " slot empty on the server")

	# ----------------------------------------------------------------------
	# **UX §9 item 7, from a guest's seat** (shared-pond.md §5, Phase 3):
	# eaten by its friend -- here the room's other guest, who is its slot 68 as
	# a phone host would be -- the second guest's black offers `watch`, and the
	# replay draws the friend in the frame before the death, where the
	# recording has it, wearing the tier-3 mouth it swam in with and wide enough
	# for the second guest that its threat bow showed; on a field, a cell, a
	# genome and grit of the replay's own. Android Back closes it, the offer is
	# back, and the tap brings it back beside the first, as ever.
	# ----------------------------------------------------------------------
	var b_offered := await _pond_offered(b_run, [a_pin])
	var b_screen: Node = await _pond_watch(b_run, [a_pin])
	var b_bound: Array = _replay_bound(b_run, b_screen)
	var b_seen: Array = [{}, Vector2.ZERO, 0.0, null]
	if b_screen != null:
		b_seen = await _replay_friend(b_screen,
			float((b_run.get("_recorder") as Node).call(&"span")), [a_pin])
	var b_worn := _recorded_worn(b_run)
	var b_peer: Dictionary = b_seen[0]
	var b_apart := (b_seen[1] as Vector2).distance_to(b_peer.get("at", Vector2.INF))
	_says(b_offered >= 0.0 and not b_bound.has(false) and _drawn_as_recorded(b_seen, b_worn)
			and Genome.tier_of(b_worn, &"cytostome") == 3
			and float(b_peer.get("gape", 0.0)) > float(b_seen[2]),
		"server (UX §9.7, a guest's seat): eaten by the other guest, the second's black"
		+ " offers `watch` %.2f s on; its replay, on a field, cell, genome and grit of"
		% b_offered + " its own %s, draws its friend in the frame before the death where"
		% str(b_bound) + " the recording has it, %.1f units off, wearing its recorded tiers,"
		% b_apart + " cytostome %d, a gape of %.1f over the second's r%.1f"
		% [Genome.tier_of(b_worn, &"cytostome"), float(b_peer.get("gape", 0.0)),
			float(b_seen[2])])
	b_run.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	var b_closed: bool = b_run.get("_replay") == null
	await _pond_frames_on(1, [a_pin])
	_says(b_closed and bool((b_run.get("_watch_ui") as Control).visible)
			and int(b_run.get("_life")) == NormalMode.Life.WAITING,
		"server: Android Back closes its replay and leaves it on its black, `watch`"
		+ " offered again")
	b_run.call(&"_wake_up")
	var b_back := await _pond_until(func() -> bool:
		return int(b_run.get("_life")) == NormalMode.Life.RETURNING, 4.0, [a_pin])
	b_home = b_cell.position
	b_pin = [b_cell, b_home, 0.0]
	pins = [a_pin, b_pin]
	var back_apart := b_home.distance_to(a_cell.position)
	_says(b_back >= 0.0 and absf(back_apart - float(pond.ARRIVAL))
			<= POND_ARRIVAL_TOLERANCE and b_food.mirroring()
			and int(b_run.get("_generation")) == 1,
		"server: the second taps from the black and comes back %.1f units from"
		% back_apart + " the first, in the same water")

	# And brings a tier-3 mouth back in -- a re-entry inside 30 s of the one
	# before, so it is the same body continued (the referee's re-entry rule).
	await _pond_reenter(b_run, {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1},
		[&"cytostome", &"cirrus", &"flagellum"], [a_pin])
	b_home = b_cell.position
	b_pin = [b_cell, b_home, 0.0]
	pins = [a_pin, b_pin]
	await _pond_until(func() -> bool:
		return Genome.tier_of(food.bodies()[slot_b].genome, &"cytostome") == 3,
		1.0, pins)
	var b_ate := [false]
	var on_b_eaten := func(_n: float, _g: StringName, _at: Vector2) -> void:
		b_ate[0] = true
	b_food.eaten.connect(on_b_eaten)
	var in_b_mouth: Vector2 = b_home + Vector2(0.0, -(float(b_cell.radius) + 18.0))
	_pond_clear_line(food, a_home, in_b_mouth, 60.0)
	var a_down := await _server_until(func() -> bool:
		return int(a_run.get("_life")) == NormalMode.Life.DYING,
		[b_pin, [a_cell, in_b_mouth, 0.0, POND_GLIDE]])
	var a_slot_empty: bool = food.person(slot_a) == null
	await _pond_until(func() -> bool:
		return (bool(b_ate[0])
			and _line_of(b_run) == NormalMode.LINE_ATE), 1.0, [b_pin])
	b_food.eaten.disconnect(on_b_eaten)
	_says(a_down >= 0.0 and bool(b_ate[0]) and a_slot_empty
			and int(a_food.died_of) == FoodField.Cause.SWALLOWED
			and int(a_food.died_by) == FoodField.By.FRIEND
			and _line_of(b_run) == NormalMode.LINE_ATE,
		"server: and the second swallows the first, with the same outcome on"
		+ " both, the other way round")

	a_run.set("_tap_pending", true)
	await _pond_until(func() -> bool:
		return int(a_run.get("_life")) == NormalMode.Life.RETURNING, 4.0, [b_pin])
	a_home = a_cell.position
	a_pin = [a_cell, a_home, 0.0]
	pins = [a_pin, b_pin]
	await _server_until(func() -> bool: return a_food.person() != null, pins)

	# **The water, on the guest in the second slot.** A chewer's bite is felt
	# at its true bearing, and that guest's snapshots carry its own wound --
	# the other's stays whole: each header is written for the one it goes to.
	var b_bites: Array = []
	var on_b_bitten := func(bearing: float, _s: float) -> void: b_bites.append(bearing)
	b_food.bitten.connect(on_b_bitten)
	# On its starboard quarter: this guest wears the wide mouth it swallowed the
	# other with, and at 70 degrees off its nose that mouth reaches a chewer
	# and eats it first.
	var chew_bearing := deg_to_rad(120.0)
	var chewer_at: Vector2 = b_home + Vector2(sin(chew_bearing), -cos(chew_bearing)) \
		* (float(b_cell.radius) + 20.0 - 3.0)
	var chewer := _pond_pose(food, 3, 20.0, {&"cytostome": 1, &"flagellum": 1},
		chewer_at, _pond_face(chewer_at, b_home))
	var chewer_serial := int(chewer.serial)
	var chewed := await _pond_until(func() -> bool:
		if int(chewer.serial) == chewer_serial:
			chewer.pos = chewer_at
			chewer.heading = _pond_face(chewer_at, b_home)
		return not b_bites.is_empty(), 1.5, pins)
	_pond_retire(food, 3)
	b_food.bitten.disconnect(on_b_bitten)
	var wounds := [0.0, 0.0]
	var agreed := await _server_until(func() -> bool:
		wounds[0] = float(food.bodies()[slot_b].wound)
		wounds[1] = float(b_cell.wound)
		return (float(wounds[0]) > 0.02
			and absf(float(wounds[0]) - float(wounds[1])) <= 1.0 / 255.0), pins)
	var felt_at := float(b_bites[0]) if not b_bites.is_empty() else NAN
	_says(chewed >= 0.0 and agreed >= 0.0
			and absf(angle_difference(felt_at, chew_bearing)) <= POND_BEARING_TOLERANCE
			and float(food.bodies()[slot_a].wound) == 0.0 and float(a_cell.wound) == 0.0,
		"server: a chewer's bite on the guest in slot %d is felt at %.3f rad, the"
		% [slot_b, felt_at] + " true bearing %.3f; its wound is its own -- %.4f"
		% [chew_bearing, float(wounds[0])] + " on the server, %.4f on its cell --"
		% float(wounds[1]) + " and the other guest's is 0")

	# A committed hunter swallows that guest: told by the water, and the other
	# guest told that its friend died, not that it ate them.
	# Held off first, on its run: "stalking you" is written per snapshot, so the
	# guest it hunts has a hunter and the other guest, sent the same body, has
	# none. Held outside COMMIT_RANGE, and on a run with nothing in it of the
	# chase its slot last ran (`_pond_hunt`): a closest approach left over from
	# that one ends this run on its first step, and so can a lunge whose aim it
	# has passed -- measured: held at 300 with a `best` of 137.5 left in it.
	#
	# **Square to the line between the guests, on whichever side lies deeper in
	# the drop.** The guests land wherever the room puts them, and 400 to one
	# side of a guest near the rim is past it: the server holds the body inside,
	# and the other guest's mirror holds it there -- measured once in 320 runs,
	# some 200 units from where it was posed, the 197 the rim's arithmetic
	# gives. An arrival lands inside the rim by its radius and more, so the
	# deeper side is in the water, or past it by less than the 30 the other
	# guest is held to below.
	var hold_off := (b_home - a_home).orthogonal().normalized() \
		* (FoodField.COMMIT_RANGE + 90.0)
	var rim: RefCounted = food.basin()
	var held_at: Vector2 = b_home + hold_off
	if float(rim.call(&"depth", b_home - hold_off)) > float(rim.call(&"depth", held_at)):
		held_at = b_home - hold_off
	# **And in clear water.** The pond is a live drop, and a mouth this wide
	# posed beside whatever lies there closes on it within a step or two: a
	# meal, REST_MEAL, off the run for five seconds, so nobody is hunted and the
	# wait below runs out -- measured in 14 runs of the same 320, before pack 2
	# and after: 13 bodies swallowed (r30 to r34), and once off the run with no
	# growth. So nothing within its mouth's reach, and 60 more: seconds of drift
	# for anything outside, where the wait takes a snapshot or two.
	var hunter_gape := CellBody.gape_of({&"cytostome": 3}, 30.0)
	_pond_clear_line(food, held_at, held_at, Cilia.mouth_reach(30.0, hunter_gape)
		+ hunter_gape * Cilia.MOUTH_BITE + 60.0)
	# **And nothing else coming for the other guest** (automation.md §5.3). The
	# room is a live drop, and under row 37 a hunter of one copy swims even at
	# rest, so one aimed at the other guest by chance would be that guest's
	# hunter -- once in this probe's first runs on the tail. So the water round it
	# is cleared, and while this waits a body that comes for it all the same is
	# taken out: what is asked is whose hunter the posed one is, not the room's.
	_pond_clear_line(food, a_home, a_home, 1000.0)
	var hunter := _pond_pose(food, 5, 30.0, {&"cytostome": 3, &"flagellum": 1},
		held_at, _pond_face(held_at, b_home))
	_pond_hunt(food, hunter, slot_b)
	# **The room is on rules** (behaviour.md §4.3, §8), and there "stalking you"
	# is "coming for you": swimming -- hungry enough to, on the founders' rules --
	# with that guest dead ahead and a mouth that takes them.
	hunter.hunger = 0.5
	hunter.swimming = true
	# **Until both have it**: each guest's snapshots run on a 50 ms schedule of
	# its own (pond.gd `_flush_guest`), so the other guest can be a snapshot
	# behind the one hunted -- and its mirror can hold an older body in slot 5
	# somewhere else. So the wait is for the hunted guest's hunter and for the
	# posed body, where it was posed, in the other guest's water.
	# Each mirror holds it under its id (protocol 5), in a slot of its own.
	var hunter_id := int(hunter.id)
	var a_holds := func() -> bool:
		var m := int((a_food.get("_mirror_slots") as Dictionary).get(hunter_id, -1))
		return m >= 0 and (a_food.bodies()[m].pos as Vector2).distance_to(held_at) < 30.0
	var flagged := await _server_until(func() -> bool:
		hunter.pos = held_at
		hunter.heading = _pond_face(held_at, b_home)
		_pond_spare(food, slot_a, hunter_id)
		return _hunter_id(b_food) == hunter_id and a_holds.call() \
			and _hunter_id(a_food) == -1, pins)
	var a_sees_hunter := _hunter_id(a_food)
	var a_has_it: bool = a_holds.call()
	# Which of the three, when it fails, and what the server's body was doing.
	var hunt_off: Array = []
	if flagged < 0.0:
		hunt_off.append("the hunted guest's hunter is %d, not %d, after %.0f s; slot 5"
			% [_hunter_id(b_food), hunter_id, SERVER_UNRELIABLE] + " holds %d, %s, %d"
			% [int(hunter.id), "stalking" if int(hunter.state) == FoodField.State.STALK
				else "off the run", int(hunter.meals)] + " meals")
	if a_sees_hunter != -1:
		hunt_off.append("the other guest's hunter is %d" % a_sees_hunter)
	if not a_has_it:
		var a_slot := int((a_food.get("_mirror_slots") as Dictionary).get(hunter_id, -1))
		hunt_off.append("the other guest holds %d, %.0f units from where it was posed"
			% [hunter_id, (a_food.bodies()[a_slot].pos as Vector2).distance_to(held_at)]
			if a_slot >= 0 else "the other guest holds no %d" % hunter_id)
	_says(flagged >= 0.0 and a_sees_hunter == -1 and a_has_it,
		"server: a hunter on the guest in slot %d is that guest's hunter, and the"
		% slot_b + " other guest, who is sent the same body, sees no hunter"
		+ ("" if hunt_off.is_empty() else " -- NOT: " + ", ".join(hunt_off)))
	# Then let in: already on the lunge, and aimed at the guest.
	var hunter_at: Vector2 = b_home + Vector2(0.0, -56.0)
	hunter.pos = hunter_at
	hunter.heading = _pond_face(hunter_at, b_home)
	hunter.aim = b_home
	hunter.lunging = true
	var hunted := await _server_until(func() -> bool:
		return (int(b_run.get("_life")) != NormalMode.Life.ALIVE
			and _line_of(a_run) == NormalMode.LINE_DIED), [a_pin])
	_says(hunted >= 0.0 and food.person(slot_b) == null
			and int(b_food.died_of) == FoodField.Cause.SWALLOWED
			and int(b_food.died_by) == FoodField.By.WATER
			and _line_of(a_run) == NormalMode.LINE_DIED,
		"server: a committed hunter swallows the guest in slot %d -- SWALLOWED by"
		% slot_b + " the water -- and the other guest is told '%s'"
		% _line_of(a_run))
	b_run.set("_tap_pending", true)
	await _pond_until(func() -> bool:
		return int(b_run.get("_life")) == NormalMode.Life.RETURNING, 4.0, [a_pin])
	b_home = b_cell.position
	b_pin = [b_cell, b_home, 0.0]
	pins = [a_pin, b_pin]
	await _server_until(func() -> bool: return a_food.person() != null, pins)

	# **A guest leaving frees its slot**: the server forgets it and takes it
	# out of the water, the other guest's friend goes, and the slot takes the
	# next guest, who arrives beside the one still swimming.
	var b_id := int(b_net.my_id())
	b_net.close()
	var freed := await _pond_until(func() -> bool:
		return (net.guests() as Array).size() == 1 and food.person(slot_b) == null \
			and pond.call("_guest_by_id", b_id) == null, 2.0, [a_pin])
	var friend_gone := await _server_until(func() -> bool:
		return a_food.person() == null, [a_pin])
	_says(freed >= 0.0 and friend_gone >= 0.0,
		"server: a guest leaving frees its slot -- forgotten by the server, out of"
		+ " its water, and gone from the other guest's %.0f ms later"
		% (friend_gone * 1000.0))
	b_run.queue_free()
	var d_net: Node = await _session("ServerGuestD")
	d_net.join("127.0.0.1")
	await _until_link(d_net, NetSession.Link.TOGETHER)
	var d_run := _pond_run_scene(d_net, false)
	get_tree().root.add_child.call_deferred(d_run)
	await d_run.ready
	var d_cell: Node = d_run.get_node(^"Cell")
	var d_pond: Object = d_run.get("_pond")
	var d_in := await _pond_until(func() -> bool: return bool(d_pond.in_pond), 3.0,
		[a_pin])
	var d_guest: Object = pond.call("_guest_by_id", int(d_net.my_id()))
	var d_apart: float = (d_cell.position as Vector2).distance_to(a_home)
	var met := await _server_until(func() -> bool: return a_food.person() != null,
		[a_pin, [d_cell, d_cell.position, 0.0]])
	_says(d_in >= 0.0 and d_guest != null and int(d_guest.slot) == slot_b
			and absf(d_apart - float(pond.ARRIVAL)) <= POND_ARRIVAL_TOLERANCE
			and met >= 0.0,
		"server: the freed slot %d takes the next guest, who lands %.1f units"
		% [slot_b, d_apart] + " from the one still swimming, and is its friend")

	# **With nobody left, the room lives on** (ocean.md §10.3): its guests go
	# out of it, and its cells hunt, grow and starve on with nobody watching --
	# the drop's clock runs, and its bodies are still there.
	a_net.close()
	d_net.close()
	var emptied := await _pond_until(func() -> bool:
		return (net.guests() as Array).is_empty() and food.person(slot_a) == null \
			and food.person(slot_b) == null, 2.0, [])
	var age_empty := float(food.drop_age())
	var stepped_from := int(food.get("_frame"))
	await _pond_until(func() -> bool: return false, 0.5, [])
	var lived := float(food.drop_age()) - age_empty
	var stepped := int(food.get("_frame")) - stepped_from
	_says(emptied >= 0.0 and food.pond_open() and int(food.drop_bodies()) > FoodField.COUNT
			and lived > 0.3 and stepped > 10,
		"server: when the last guest leaves, the room lives on -- %.2f s of its life"
		% lived + " and %d steps in half a second with nobody in it, %d bodies"
		% [stepped, int(food.drop_bodies())])
	a_run.queue_free()
	d_run.queue_free()

	# **The server stops cleanly**: two new guests arrive in water made for
	# them, and when it stops each is told at once and swims on alone in fresh
	# water, rather than waiting out a timeout.
	var e_net: Node = await _session("ServerGuestE")
	var f_net: Node = await _session("ServerGuestF")
	e_net.join("127.0.0.1")
	f_net.join("127.0.0.1")
	await _until_link(e_net, NetSession.Link.TOGETHER)
	await _until_link(f_net, NetSession.Link.TOGETHER)
	var e_run := _pond_run_scene(e_net, false)
	get_tree().root.add_child.call_deferred(e_run)
	await e_run.ready
	var f_run := _pond_run_scene(f_net, false)
	get_tree().root.add_child.call_deferred(f_run)
	await f_run.ready
	var e_food: Node = e_run.get_node(^"Food")
	var f_food: Node = f_run.get_node(^"Food")
	await _pond_until(func() -> bool:
		return (bool((e_run.get("_pond") as Object).in_pond)
			and bool((f_run.get("_pond") as Object).in_pond)), 3.0, [])
	# **Checks 24 and 27 in the room** (automation.md §10.3, §18.3): both divide
	# on meals the room fed them -- the first with a program on, the second with
	# nothing on -- and the server places each one's sister: the first's with her
	# DNA and her list, the second's with her DNA and the founders' rules. The
	# stop below keeps them in the room, and the next start loads them so.
	var room_sisters: Array = await _server_sisters(pond, food, e_run, f_run)
	var e_sister: Dictionary = room_sisters[0]
	var f_sister: Dictionary = room_sisters[1]
	_says(_sister_came(e_sister, true) and _sister_came(f_sister, false),
		"server (check 24): in the room, the first guest's declined daughter arrives"
		+ " with her DNA -- %s at 2 copies, which her body does not wear -- and the"
		% e_sister.get("unworn", &"") + " %d lines her cell ran, the rule of a gene"
		% SISTER_LINES.size() + " the server does not know kept as it came; the"
		+ " second's, with nothing on, with her DNA and the founders' rules; each the"
		+ " founder of a line of her own (ids %d and %d)" % [int(e_sister.get("id", -1)),
			int(f_sister.get("id", -1))])

	# ----------------------------------------------------------------------
	# **The host leaves mid-replay** (shared-pond.md §5, Phase 3): the second
	# guest is swallowed by the room's water and watches its death back -- the
	# other guest drawn in it as its friend, the room's way: slot 68, as a phone
	# host would be -- and the server stops under the screen. The takeover onto
	# its own drop leaves the replay alone: it plays on, on the field it was
	# raised with; closed, `watch` is back on its black; and the tap brings a new
	# cell into its own drop, alone, the water running.
	# ----------------------------------------------------------------------
	var f_guest: Object = pond.call("_guest_by_id", int(f_net.my_id()))
	var f_person: Object = food.person(int(f_guest.slot)) if f_guest != null else null
	if f_person != null:
		food.call("_person_gone", FoodField.Cause.SWALLOWED, FoodField.By.WATER, f_person)
	var f_offered := await _pond_offered(f_run, [])
	var f_screen: Node = await _pond_watch(f_run, [])
	var f_bound: Array = _replay_bound(f_run, f_screen)
	var f_seen: Array = [{}, Vector2.ZERO, 0.0, null]
	if f_screen != null:
		f_seen = await _replay_friend(f_screen,
			float((f_run.get("_recorder") as Node).call(&"span")), [])
	var f_water: Node = f_screen.get("_food") if f_screen != null else null
	_says(f_offered >= 0.0 and not f_bound.has(false)
			and _drawn_as_recorded(f_seen, _recorded_worn(f_run)),
		"server: the second guest, swallowed by the room's water, is offered `watch`"
		+ " %.2f s on, and its replay draws the first guest as its friend, as" % f_offered
		+ " recorded, on nodes of its own %s" % str(f_bound))
	var fresh := int(food.drop_bodies())
	var kept_before := int(server.get("rooms_kept"))
	# **Each sister as the room keeps her** (check 27), read in the frame the stop
	# keeps the room in -- `shut_down` keeps it first thing -- so the next start is
	# held to what was kept. Not to what came at check 24: she has been a water body
	# since, and a meal there writes its gene to her DNA (food.gd's `_grow`), which
	# failed this check about one run in seven. **A sister the water has eaten since
	# is put back as she came**, through the door the pond put her in by, so the
	# room has her to keep: the harness reaching into the world, as `_hold` does,
	# for a check about the file rather than the water.
	var kept_sisters: Array = []
	for said: Dictionary in [e_sister, f_sister]:
		var b: Object = _body_of(food, int(said.get("id", -1)))
		var again := false
		if b == null and said.has("body_dna"):
			var slot := int(food.place_sister(said["at"], float(said["heading"]),
				float(said["radius"]), said["genome"], said["body_dna"], PackedInt32Array(),
				pond.sister_list(_list_said(said.get("brain"))[0])))
			b = food.bodies()[slot] if slot >= 0 else null
			again = b != null
		kept_sisters.append({} if b == null else {"id": int(b.get("id")),
			"dna": (b.get("dna") as Dictionary).duplicate(), "again": again})
	server.shut_down()
	var stopped_age := float(food.drop_age())
	var kept_at_stop := int(server.get("rooms_kept")) - kept_before
	var taken := await _pond_until(func() -> bool:
		return not e_food.mirroring() and not f_food.mirroring(), 1.5, [])
	var taken_frames := _pond_frames
	_says(fresh >= FoodField.COUNT and taken >= 0.0
			and taken_frames <= _pond_budget(0.2),
		"server: the next two arrive in the room, %d bodies; stopped, both take over"
		% fresh + " their own water %d frames later (%.0f ms here) -- told, not timed out"
		% [taken_frames, taken * 1000.0])
	var f_at := float(f_screen.get("_at")) if f_screen != null else -1.0
	await _pond_frames_on(10, [])
	var f_on: bool = f_screen != null and f_run.get("_replay") == f_screen \
		and f_screen.get("_food") == f_water and not f_water.is_processing() \
		and bool(f_water.call(&"pond_open")) and float(f_screen.get("_at")) != f_at
	var f_alone: bool = not f_food.mirroring() and f_food.owns_drop()
	if f_screen != null:
		(f_screen.get("_leave_button") as Button).pressed.emit()
	await _pond_frames_on(2, [])
	var f_reoffered: bool = f_run.get("_replay") == null \
		and bool((f_run.get("_watch_ui") as Control).visible) \
		and int(f_run.get("_life")) == NormalMode.Life.WAITING
	f_run.call(&"_wake_up")
	var f_back := await _pond_until(func() -> bool:
		return int(f_run.get("_life")) == NormalMode.Life.RETURNING, 1.0, [])
	var f_back_alone: bool = not f_food.mirroring() and f_food.owns_drop() \
		and f_food.is_processing() and (f_run.get("_pond") as Object) != null \
		and not bool((f_run.get("_pond") as Object).call(&"together"))
	_says(f_on and f_alone and f_reoffered and f_back >= 0.0 and f_back_alone,
		"server: stopped while the second guest watched, it took over its own drop"
		+ " under the screen (%s), which played on, on its own field (%s); closed,"
		% [str(f_alone), str(f_on)] + " `watch` is offered on its black again (%s), and"
		% str(f_reoffered) + " its tap brings a new cell into its own drop, alone, the"
		+ " water running (%s)" % str(f_back_alone))
	var stop_kept := DropSave.read(SERVER_ROOM)
	var stop_rows: Dictionary = (stop_kept.get("drop", {}) as Dictionary).get("bodies", {})
	var stop_bodies := (stop_rows.get("slot", PackedInt32Array()) as PackedInt32Array).size()

	e_run.queue_free()
	f_run.queue_free()
	e_net.close()
	f_net.close()
	server.queue_free()
	await _wait(0.3)
	# **The next start takes the room up where the stop kept it** (§10.3).
	var again: Node = load(SERVER_SCENE).instantiate()
	for seam: String in ["check_updates", "own_frame_rate", "quits"]:
		again.set(seam, false)
	again.set("pond_root", "user://net_probe_no_invites/")
	again.set("upnp_router", UpnpRouter.new(&"none"))
	again.set("room_path", SERVER_ROOM)
	get_tree().root.add_child.call_deferred(again)
	await again.ready
	var again_food: Node = again.food()
	var loaded_age := float(again_food.drop_age())
	var loaded_bodies := int(again_food.drop_bodies())
	_says(kept_at_stop == 1 and stop_bodies > FoodField.COUNT
			and absf(loaded_age - stopped_age) < 0.001 and loaded_bodies == stop_bodies
			and int(again.get("rooms_kept")) == 0 and again_food.pond_open(),
		"server: stopped, it kept its room first (%d bodies, %.1f s old); the next"
		% [stop_bodies, stopped_age] + " start loads it -- %d bodies, %.1f s old --"
		% [loaded_bodies, loaded_age] + " and keeps nothing new until it is due")
	# **Check 27: a guest's sister's list, through a save and a load**
	# (automation.md §10.3, §18.3): the file holds her lines as they came, the
	# rule this build cannot read among them, and the next start gives them back
	# to her, read again, with her DNA; the sister on the founders' stays on them.
	var stop_lists: Array = ((stop_kept.get("drop", {}) as Dictionary).get("behaviours",
		{}) as Dictionary).get("lists", [])
	var e_kept: Dictionary = kept_sisters[0]
	var f_kept: Dictionary = kept_sisters[1]
	var e_again: Object = _body_of(again_food, int(e_kept.get("id", -1)))
	var f_again: Object = _body_of(again_food, int(f_kept.get("id", -1)))
	var e_back: Array = _list_said(e_again.get("brain") if e_again != null else null)
	var put_back := PackedStringArray()
	for k in kept_sisters.size():
		if bool((kept_sisters[k] as Dictionary).get("again", false)):
			put_back.append(["the first guest's", "the second guest's"][k])
	_says(stop_lists.has(PackedStringArray(SISTER_LINES)) and e_again != null
			and f_again != null and e_back[0] == PackedStringArray(SISTER_LINES)
			and e_back[1] == [false, false, true, false]
			and _by_name(e_again.get("dna")) == _by_name(e_kept.get("dna"))
			and f_again.get("brain") == null
			and _by_name(f_again.get("dna")) == _by_name(f_kept.get("dna")),
		"server (check 27): stopped, the room kept the first guest's sister's list as"
		+ " it came -- the rule it cannot read among it -- and loaded, she has it back,"
		+ " %d lines, one never firing, with her DNA as the room kept it; the second's"
		% (e_back[0] as PackedStringArray).size() + " sister is on the founders' rules"
		+ " still%s" % ("" if put_back.is_empty() else (" (both sisters put back as they"
			+ " came: the water ate them before the stop)") if put_back.size() > 1
			else " (%s sister put back as she came: the water ate her before the stop)"
			% put_back[0]))
	again.set("room_path", "")
	again.shut_down()
	again.queue_free()
	await _wait(0.2)
	_server_room_gone()
	_watch_throttle(false)
	_says(_throttle_reads > 0
			and _throttle_lowest == ENetPacketPeer.PACKET_THROTTLE_SCALE,
		"server: no ENet peer's packet throttle fell under the section's load --"
		+ " lowest %d of %d over %d readings, the server's and every guest's"
		% [_throttle_lowest, ENetPacketPeer.PACKET_THROTTLE_SCALE, _throttle_reads])
	# The third guest is refused with "already two", and the fourth -- on other
	# rules -- with "different versions", which are the handshake's sentences and
	# not the door's: nothing here is an offence.
	var tally: Array = _tally_end()
	_says(_limits_clean(tally[0]) and int(tally[1]) == 8,
		"server: across the server and all seven guests the gate struck nothing,"
		+ " dropped nothing, cut nothing and refused nobody at the door, and the"
		+ " budgets it watches would have done none of it either -- its"
		+ " socket took %.1f KB and %d datagrams in its busiest second%s"
		% [float(tally[0]["peak_bytes"]) / 1024.0, roundi(float(tally[0]["peak_datagrams"])),
			_limits_unclean([tally[0]])])
	# **And its referees called no foul on any of the five guests it took**:
	# arriving, bringing new bodies in, eating each other, eaten by the water,
	# back from the black, leaving (B.5).
	var server_referees: Array = pond.get("referees_made")
	_says(float(tally[0].get("fouls", 0.0)) == 0.0 and server_referees.size() == 5,
		"server: and its referees called no foul on an honest guest -- %s"
		% _referee_said(server_referees))
	_says(_own_cells() == cells_before,
		("server: and no cell file was written for its room -- user://%s and user://%s/ as"
		+ " they were before it started, %d files") % [Cells.INDEX, Cells.FOLDER,
		cells_before.size()])
	print("[net-probe] NOTE server took %.1f s and %d frames, at most %d a second;"
		% [_now() - began, Engine.get_process_frames() - began_frames, Engine.max_fps]
		+ " its longest wait on an unreliable frame %.2f s, of %.0f"
		% [_server_waited, SERVER_UNRELIABLE])
	Engine.max_fps = ceiling


## The section's room, and what a save leaves beside it, gone -- and its folder.
func _server_room_gone() -> void:
	for path: String in [SERVER_ROOM, SERVER_ROOM.get_basename() + ".tmp",
			SERVER_ROOM + ".old"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(SERVER_ROOM.get_base_dir()):
		DirAccess.remove_absolute(SERVER_ROOM.get_base_dir())


## **Two guests of the room divide, and the room places their sisters**
## (automation.md §10.3; checks 24 and 27): [param first] with a program on --
## [constant SISTER_LINES], the autopilot off -- and [param second] with nothing
## on. Each is fed to r40 on morsels the room puts on its lip, divides as the
## pond section's guest does, its quickening and its parting skipped, and leans
## to its first daughter. The one it declines carries in her DNA a gene her body
## does not wear, a different one for each, and that tells the two sisters apart
## in the room. `[first's, second's]`, each `{unworn, dna, body}` as the guest
## sent them and, once the room placed her, `{id, parent, generation, lineage,
## body_dna, brain, genome}` as she is there -- `id` -1 for one it never placed.
func _server_sisters(pond: Object, food: Node, first: Node, second: Node) -> Array:
	var runs: Array = [first, second]
	var pins: Array = []
	for run: Node in runs:
		var cell: Node = run.get_node(^"Cell")
		pins.append([cell, cell.position, 0.0])
	var library: RefCounted = first.get("_library")
	var program := int(library.call(&"add_new"))
	library.call(&"set_lines", program, PackedStringArray(SISTER_LINES))
	first.call(&"_library_changed")
	# **Each sister as she is placed**, read in the signal, before the water's next
	# step: she is a water body from then on, and a meal writes its gene to a water
	# body's DNA (food.gd's `_grow`), so read a step later she can already be other
	# than what her mother sent -- one run in 25 here.
	var placed: Array = []
	var on_placed := func(slot: int) -> void:
		var b: Object = food.bodies()[slot]
		placed.append({"id": int(b.get("id")), "parent": int(b.get("parent")),
			"generation": int(b.get("generation")), "lineage": int(b.get("lineage")),
			"body_dna": (b.get("dna") as Dictionary).duplicate(), "brain": b.get("brain"),
			"genome": (b.get("genome") as Dictionary).duplicate(), "at": b.get("pos"),
			"heading": float(b.get("heading")), "radius": float(b.get("radius"))})
	pond.connect(&"sister_placed", on_placed)
	for pin: Array in pins:
		await _pond_feed(food, pin[0], pins)
	await _pond_until(func() -> bool:
		return runs.all(func(run: Node) -> bool:
			return int(run.get("_split")) != NormalMode.Split.NONE), 1.0, pins)
	await _pond_until(func() -> bool:
		for run: Node in runs:
			if int(run.get("_split")) == NormalMode.Split.QUICKEN:
				run.set("_split_clock", NormalMode.DIVIDE_QUICKEN)
			elif int(run.get("_split")) == NormalMode.Split.PART:
				run.set("_split_clock", NormalMode.DIVIDE_PART)
		return runs.all(func(run: Node) -> bool:
			return int(run.get("_split")) == NormalMode.Split.CHOOSING), 3.0, [])
	var out: Array = []
	var taken := {}
	for run: Node in runs:
		var said := {"unworn": &"", "id": -1}
		if int(run.get("_split")) == NormalMode.Split.CHOOSING:
			var declined: Dictionary = (run.get("_daughters") as Array)[1]
			for gene: StringName in [&"ampulla", &"stigma", &"palp", &"ocellus",
					&"chemocyte"]:
				if not taken.has(gene) and not (declined["body"] as Dictionary).has(gene) \
						and not (declined["tiers"] as Dictionary).has(gene):
					said["unworn"] = gene
					break
			taken[said["unworn"]] = true
			(declined["tiers"] as Dictionary)[said["unworn"]] = 2
			said["dna"] = (declined["tiers"] as Dictionary).duplicate()
			said["body"] = (declined["body"] as Dictionary).duplicate()
			# Leaning to the first, as `_step_choosing` would after CHOOSE_HOLD.
			run.set("_chosen", 0)
			run.set("_split", NormalMode.Split.COMMIT)
			run.set("_split_clock", 0.0)
		out.append(said)
	await _pond_until(func() -> bool:
		return placed.size() >= 2 and runs.all(func(run: Node) -> bool:
			return int(run.get("_split")) == NormalMode.Split.NONE), 3.0, [])
	pond.disconnect(&"sister_placed", on_placed)
	for one: Dictionary in placed:
		for said: Dictionary in out:
			if said["unworn"] != &"" and (one["body_dna"] as Dictionary).has(said["unworn"]):
				said.merge(one, true)
	return out


## **Whether a guest's sister came as §10.3 says**, from [method _server_sisters]'
## record of her: placed, with the DNA her mother sent -- the gene her body does
## not wear in it, and not on her body -- and, [param with_list], the list of
## [constant SISTER_LINES] read with the room's own vocabulary, the later
## build's rule never firing; without, the founders' rules. A founder of a line
## of her own either way: ids are per drop.
static func _sister_came(said: Dictionary, with_list: bool) -> bool:
	if int(said.get("id", -1)) < 0 or not said.has("dna"):
		return false
	var list: Array = _list_said(said.get("brain"))
	var listed: bool = (list[0] == PackedStringArray(SISTER_LINES)
		and list[1] == [false, false, true, false]) if with_list \
		else said.get("brain") == null
	return listed and _by_name(said["body_dna"]) == _by_name(said["dna"]) \
		and not (said["genome"] as Dictionary).has(said["unworn"]) \
		and _by_name(said["genome"]) == _by_name(said["body"]) \
		and int(said["parent"]) == FoodField.Descent.NOBODY \
		and int(said["generation"]) == 1 and int(said["lineage"]) == int(said["id"])


## [param tiers] by name, `{String: int}`, so two maps are compared whatever
## their keys were read as.
static func _by_name(tiers: Variant) -> Dictionary:
	var out := {}
	if tiers is Dictionary:
		for gene: Variant in tiers:
			out[String(gene)] = int(tiers[gene])
	return out


## The body numbered [param id] in [param food]'s water, or null.
static func _body_of(food: Node, id: int) -> Object:
	if id < 0:
		return null
	for b: Object in food.bodies():
		if bool(b.get("seeded")) and int(b.get("id")) == id:
			return b
	return null


## [method _pond_until] for anything an unreliable frame carries: given
## [constant SERVER_UNRELIABLE], and the longest it took kept for the NOTE, so
## the margin is read in the log before a slower runner uses it up.
func _server_until(done: Callable, pins: Array) -> float:
	var took: float = await _pond_until(done, SERVER_UNRELIABLE, pins)
	_server_waited = maxf(_server_waited, took if took >= 0.0 else SERVER_UNRELIABLE)
	return took


## **An update service that answers what it is told to**: the launcher's two
## coroutines' shape, with no network behind them. Made by [method _fake], whose
## manifest is built for the binary this process is.
class FakeService extends RefCounted:
	var state := 0
	var last_error := ""
	var manifest := {"version_name": "9.9.9", "binary_version": 0}
	var pending_kind := ""
	var pending_artifact := {}
	var pending_version := 0
	var answer := 0
	var applied_as := 0
	var applies := 0

	func check_for_updates() -> int:
		state = answer
		return state

	func apply_pending_update() -> int:
		applies += 1
		state = applied_as
		return state


## **Enough of an HTTP server to serve one file to `HTTPRequest`**, on
## loopback: whatever is asked for, [member body] comes back, whole, and the
## connection closes. Polled a frame at a time, so a download on
## `HTTPRequest`'s own thread is served while the probe awaits it.
class TinyHttp extends Node:
	var body := PackedByteArray()
	## When set, the response carries no Content-Length -- the body just streams
	## until the connection closes, the shape a lying or chunked length takes,
	## so the download's own byte count is the only ceiling.
	var no_length := false
	var port := 0
	var served := 0
	var _server := TCPServer.new()
	var _open: Array = []

	func start() -> bool:
		for candidate in range(47110, 47190):
			if _server.listen(candidate, "127.0.0.1") == OK:
				port = candidate
				return true
		return false

	func _process(_delta: float) -> void:
		while _server.is_connection_available():
			_open.append([_server.take_connection(), PackedByteArray()])
		for each: Array in _open.duplicate():
			var peer: StreamPeerTCP = each[0]
			peer.poll()
			var waiting := peer.get_available_bytes()
			var asked: PackedByteArray = each[1]
			if waiting > 0:
				asked.append_array(peer.get_data(waiting)[1])
				each[1] = asked
			if not asked.get_string_from_ascii().contains("\r\n\r\n"):
				continue
			var head := "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\n"
			if not no_length:
				head += "Content-Length: %d\r\n" % body.size()
			head += "Connection: close\r\n\r\n"
			peer.put_data(head.to_ascii_buffer())
			peer.put_data(body)
			peer.disconnect_from_host()
			_open.erase(each)
			served += 1

	func stop() -> void:
		_server.stop()


func _check_server_updates() -> void:
	var scratch := ProjectSettings.globalize_path("user://net_probe_server")
	DirAccess.make_dir_recursive_absolute(scratch)
	var exe := scratch.path_join("biogenic-server.x86_64")
	var note := scratch.path_join("note.json")
	var part := scratch.path_join(".biogenic-server.x86_64.download")
	var leftovers := [exe, exe + ".previous", exe + ".previous.part", note, part]
	for leftover: String in leftovers:
		DirAccess.remove_absolute(leftover)

	# **Content newer**: staged, held while a guest is in, done once it is not.
	var content := _fake(ServiceScript.State.CONTENT_READY, 1_000_000)
	var up := _updater(content, exe, note, 0.25)
	var restarts: Array = []
	up.restart_wanted.connect(func(why: String) -> void: restarts.append(why))
	await up.check()
	var staged_first := str(up.staged) == "content" \
		and int(up.staged_version) == 1_000_000 and content.applies == 1
	var until := _now() + 0.6
	while _now() < until:
		up.tick(1)
		await get_tree().process_frame
	await up.check()
	var held := restarts.is_empty()
	var applies_held := content.applies
	var empty_from := _now()
	until = _now() + 2.0
	while _now() < until and restarts.is_empty():
		up.tick(0)
		await get_tree().process_frame
	var waited := _now() - empty_from
	_says(staged_first and held and applies_held == 1 and restarts.size() == 1
			and waited >= 0.25 and FileAccess.file_exists(note),
		"server updates: content newer is staged once, held through 0.6 s with a"
		+ " guest in and a second check, and restarts %.2f s after the pond"
		% waited + " empties (asked for 0.25), leaving a note for the next start")
	up.queue_free()

	# **A pack that did not mount is not taken again**: the note says content
	# 1,000,000, this build runs less, so the next start refuses it.
	var after := _fake(ServiceScript.State.CONTENT_READY, 1_000_000)
	var next := _updater(after, exe, note, 0.25)
	await next.check()
	_says(after.applies == 0 and str(next.staged).is_empty()
			and not FileAccess.file_exists(note),
		"server updates: after a restart that did not take, the same content is"
		+ " not downloaded again")
	next.queue_free()

	# **Content built for another binary is not this one's**: the launcher
	# offers it whenever the binary number has not gone up, down included.
	var running := int(content.manifest["binary_version"])
	var passed_over := 0
	for other: int in [running - 1, running + 1]:
		var elsewhere := _fake(ServiceScript.State.CONTENT_READY, 1_000_004)
		elsewhere.manifest["binary_version"] = other
		var picky := _updater(elsewhere, exe, note, 60.0)
		var picky_lines := _lines_of(picky)
		await picky.check()
		if elsewhere.applies == 0 and str(picky.staged).is_empty() \
				and _said(picky_lines, "published for binary %d" % other):
			passed_over += 1
		picky.queue_free()
	_says(passed_over == 2,
		"server updates: content published for binary %d or %d is not taken by"
		% [running - 1, running + 1] + " binary %d" % running)

	# **Binary newer**: downloaded from a loopback HTTP server, hashed, asked
	# for its version, and swapped over the running build -- which is kept
	# beside it. The build is a shell script that answers `--version` as an
	# exported server does, padded past a megabyte so that its hashing takes
	# more than one of its megabyte-a-frame steps.
	var http := TinyHttp.new()
	add_child(http)
	var listening := http.start()
	var old_build := "the build that is running".to_utf8_buffer()
	var new_build := _fake_build("4.7.stable.probe", 0, 1_500_000)
	var new_sum := _sha(new_build)
	http.body = new_build
	_write(exe, old_build)
	var binary := _fake(ServiceScript.State.BINARY_READY, 1_000_001)
	binary.pending_artifact = {"url": _served(http), "sha256": new_sum,
		"size": new_build.size()}
	var swap := _updater(binary, exe, note, 60.0)
	var swap_lines := _lines_of(swap)
	await swap.check()
	var mode := FileAccess.get_unix_permissions(exe)
	_says(listening and http.served == 1 and _read(exe) == new_build
			and _read(exe + ".previous") == old_build
			and (mode & FileAccess.UNIX_EXECUTE_OWNER) != 0
			and not FileAccess.file_exists(part)
			and not FileAccess.file_exists(exe + ".previous.part")
			and str(swap.staged) == "binary" and int(swap.staged_version) == 1_000_001
			and _said(swap_lines, "starts here (4.7.stable.probe)"),
		"server updates: binary newer is fetched over HTTP, its SHA-256 checked"
		+ " (%s...), asked for its version, and swapped over the running build,"
		% new_sum.left(12) + " executable, the old one kept as .previous")

	# **A second build while the first still waits** replaces that one, which
	# never ran -- and `.previous` stays the build that did.
	var second_build := _fake_build("4.7.stable.probe2", 0)
	http.body = second_build
	binary.pending_version = 1_000_002
	binary.pending_artifact = {"url": _served(http), "sha256": _sha(second_build),
		"size": second_build.size()}
	await swap.check()
	_says(http.served == 2 and _read(exe) == second_build
			and _read(exe + ".previous") == old_build
			and str(swap.staged) == "binary" and int(swap.staged_version) == 1_000_002,
		"server updates: a second binary while the first is staged replaces it,"
		+ " and .previous stays the build that ran")
	swap.queue_free()

	# **A build that does not start here is refused**, and not fetched again
	# until the manifest's checksum for it changes.
	var previous := "the build before that".to_utf8_buffer()
	_write(exe, old_build)
	_write(exe + ".previous", previous)
	var broken_build := _fake_build("cannot start on this machine", 1)
	http.body = broken_build
	var broken := _fake(ServiceScript.State.BINARY_READY, 1_000_003)
	broken.pending_artifact = {"url": _served(http), "sha256": _sha(broken_build),
		"size": broken_build.size()}
	var refuse := _updater(broken, exe, note, 60.0)
	var refuse_lines := _lines_of(refuse)
	var served := http.served
	await refuse.check()
	_says(http.served == served + 1 and _read(exe) == old_build
			and _read(exe + ".previous") == previous and not FileAccess.file_exists(part)
			and str(refuse.staged).is_empty()
			and _said(refuse_lines, "does not start on this machine"),
		"server updates: a new binary that exits 1 on --version is refused -- the"
		+ " running build and .previous untouched, the download deleted")
	await refuse.check()
	await refuse.check()
	var skipped_downloads := http.served - served - 1
	var skips_said := _count(refuse_lines, "not downloading it again")
	var fixed_build := _fake_build("4.7.stable.fixed", 0)
	http.body = fixed_build
	broken.pending_artifact = {"url": _served(http), "sha256": _sha(fixed_build),
		"size": fixed_build.size()}
	await refuse.check()
	_says(skipped_downloads == 0 and skips_said == 1 and http.served == served + 2
			and _read(exe) == fixed_build and str(refuse.staged) == "binary",
		"server updates: a refused build is not downloaded again while the"
		+ " manifest gives it the same checksum -- %d downloads in 2 checks,"
		% skipped_downloads + " said %d time(s) -- and is, once it gives another"
		% skips_said)

	# **What the pre-flight takes for a version**: any `N.M...`, so the first
	# Godot 5 build is not refused for its number by every server already out
	# there -- and never an empty answer with exit 0, which is what a build
	# killed on its way out can give.
	var asked := scratch.path_join("preflight.sh")
	leftovers.append(asked)
	var verdicts: PackedStringArray = []
	for case: Array in [["", false], ["5.0.stable.official", true], ["hello", false]]:
		_write(asked, _fake_build(str(case[0]), 0))
		FileAccess.set_unix_permissions(asked, FileAccess.UNIX_READ_OWNER
			| FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
		if bool(refuse.preflight(asked)["ok"]) == bool(case[1]):
			verdicts.append(str(case[0]))
	_says(verdicts.size() == 3,
		"server updates: the pre-flight refuses an empty answer and a non-version"
		+ " with exit 0, and takes a Godot 5 version (%d of 3 right)" % verdicts.size())
	refuse.queue_free()

	# **A bad checksum is refused**: nothing moves, nothing is left, and it is
	# not fetched again at the next check.
	var before := _read(exe)
	var bad := _fake(ServiceScript.State.BINARY_READY, 1_000_005)
	bad.pending_artifact = {"url": _served(http), "sha256": "00".repeat(32),
		"size": fixed_build.size()}
	var mismatch := _updater(bad, exe, note, 60.0)
	served = http.served
	await mismatch.check()
	await mismatch.check()
	_says(http.served == served + 1 and _read(exe) == before
			and str(mismatch.staged).is_empty() and not FileAccess.file_exists(part),
		"server updates: a download whose SHA-256 does not match the manifest is"
		+ " refused -- the running build untouched, the download deleted -- and"
		+ " not fetched again at the next check")
	mismatch.queue_free()

	# **A download is abandoned before it can fill the disk** (#77): held to
	# twice the size the manifest declares, so a url that never stops sending is
	# given up on -- whether its length is honestly oversized or missing
	# altogether. Here the manifest declares a hundred bytes and the feed serves
	# far more.
	var oversized := PackedByteArray()
	oversized.resize(300_000)
	http.body = oversized
	var kept := _read(exe)
	var capped := 0
	for lying: bool in [false, true]:
		http.no_length = lying
		var big := _fake(ServiceScript.State.BINARY_READY, 1_000_007 + int(lying))
		big.pending_artifact = {"url": _served(http), "sha256": _sha(oversized),
			"size": 100}
		var bound := _updater(big, exe, note, 60.0)
		var bound_lines := _lines_of(bound)
		await bound.check()
		if _read(exe) == kept and str(bound.staged).is_empty() \
				and not FileAccess.file_exists(part) and _said(bound_lines, "ceiling"):
			capped += 1
		bound.queue_free()
	http.no_length = false
	http.body = fixed_build
	_says(capped == 2,
		"server updates: a build download past twice the manifest's declared size is"
		+ " abandoned -- an honestly oversized Content-Length and a missing one both"
		+ " -- the running build untouched and the partial deleted, so a runaway url"
		+ " cannot fill the disk (#77)")

	# **Nothing is applied from the editor**: the same news, and no download.
	var editor := _fake(ServiceScript.State.CONTENT_READY, 1_000_006)
	var dry := _updater(editor, exe, note, 60.0)
	dry.can_apply = false
	await dry.check()
	_says(editor.applies == 0 and str(dry.staged).is_empty(),
		"server updates: outside an exported server build it says what it would"
		+ " take, and takes nothing")
	dry.queue_free()

	# **What a stop in the middle of an update leaves is gone at the next
	# start** -- and the rollback copy is not.
	var way_back := "the way back".to_utf8_buffer()
	_write(part, "half a download".to_utf8_buffer())
	_write(exe + ".previous.part", "half a copy".to_utf8_buffer())
	_write(exe + ".previous", way_back)
	var fresh := _updater(_fake(ServiceScript.State.UP_TO_DATE, 0), exe, note, 60.0)
	_says(not FileAccess.file_exists(part)
			and not FileAccess.file_exists(exe + ".previous.part")
			and _read(exe + ".previous") == way_back,
		"server updates: a download and a half-made copy left by a stop"
		+ " mid-update are removed at the next start, and .previous is kept")
	fresh.queue_free()

	http.stop()
	http.queue_free()
	for leftover: String in leftovers:
		DirAccess.remove_absolute(leftover)
	DirAccess.remove_absolute(scratch)


## A fake update service answering [param answer] about [param version], its
## manifest built for the binary this process is.
func _fake(answer: int, version: int) -> FakeService:
	var service := FakeService.new()
	service.answer = answer
	service.pending_version = version
	service.pending_kind = "binary" if answer == ServiceScript.State.BINARY_READY \
		else "content"
	service.applied_as = ServiceScript.State.RESTART_REQUIRED
	var info := get_node_or_null(^"/root/BuildInfo")
	service.manifest["binary_version"] = int(info.binary_version) if info != null else 0
	return service


## **A server build, as far as the pre-flight can tell**: a shell script that
## answers `--version` with [param says] and exits [param code] -- padded to
## [param size] bytes past its `exit`, where the shell never reads.
static func _fake_build(says: String, code: int, size: int = 0) -> PackedByteArray:
	var bytes := ("#!/bin/sh\necho '%s'\nexit %d\n" % [says, code]).to_utf8_buffer()
	var line := ("#" + "=".repeat(62) + "\n").to_utf8_buffer()
	while bytes.size() + line.size() <= size:
		bytes.append_array(line)
	return bytes


static func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _served(http: Node) -> String:
	return "http://127.0.0.1:%d/biogenic-server.x86_64" % int(http.port)


## Every line [param up] says from now on, as it says it.
func _lines_of(up: Node) -> Array:
	var lines: Array = []
	up.said.connect(func(line: String) -> void: lines.append(line))
	return lines


func _said(lines: Array, part: String) -> bool:
	return _count(lines, part) > 0


func _count(lines: Array, part: String) -> int:
	var count := 0
	for line: String in lines:
		if line.contains(part):
			count += 1
	return count


## An updater on a fake service, in the tree, that checks only when told.
func _updater(service: Object, exe: String, note: String, grace: float) -> Node:
	var up: Node = Updater.new()
	up.service = service
	up.exe_path = exe
	up.note_path = note
	up.can_apply = true
	up.restart_after = grace
	up.check_every = 1e9
	add_child(up)
	up.set("_next_check", INF)
	return up


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _read(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) \
		else PackedByteArray()


# ---------------------------------------------------------------------------
# **Invites** (docs/design/net-hardening.md C, issue #59): the dedicated
# server's internet listener -- DTLS on its own port, the certificate the
# invite pins, and the secret a caller proves before a single frame of play
# is taken -- and the line a friend pastes to reach it. First the line itself,
# with no socket; then real calls over DTLS on loopback to a host of their own
# each: the good one, every wrong invite, every wrong server, and callers that
# break the handshake; then the doors, which a storm on the internet listener
# must never close to the LAN; then the real server scene, minting, revoking
# and holding a LAN guest and an internet guest in one pond. Every line
# printed while it runs is caught, and not one may hold a secret.
# ---------------------------------------------------------------------------

## Where this section keeps its books: never a real server's `user://pond`.
const INVITES_ROOT := "user://net_probe_invites/"
const INVITES_SERVER_ROOT := "user://net_probe_invites_server/"
## **The server scene's look at its invites, as this section runs it**: every
## half second, so a revocation's cut is asserted against it.
const INVITES_POLL := 0.5
## **Fifty frames a second.** Nothing here is finer than a few tenths of a
## second -- a call connects at ENet's first resend, 0.5 s in, and every wait
## ends the moment its answer is in -- and most of the section is waiting out
## timeouts a player would: the 8 s of a call nothing answers, the 3 s of a
## caller that never proves. At fifty a second its forty-odd seconds cost
## CI's backstop about 2,100 frames.
const INVITES_FPS := 50

## **Every line printed while the section runs** -- the probe's, the
## sessions', the server's and the engine's error lines alike -- for the one
## check that none of them holds a secret. The engine may log from any
## thread, so it takes a lock.
class LineCatcher extends Logger:
	var lines: PackedStringArray = []
	var _lock := Mutex.new()

	func _log_message(message: String, _error: bool) -> void:
		_lock.lock()
		lines.append(message)
		_lock.unlock()

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		lines.append("%s %s (%s:%d %s)" % [code, rationale, file, line, function])
		_lock.unlock()


## **The server's updater, as far as the server can tell**: it only ever
## calls `tick`, once a frame, with how many are there -- which this keeps.
class TickTaker extends Node:
	var told: Array[int] = []

	func tick(peers: int) -> void:
		told.append(peers)


var _inv_catcher: LineCatcher = null
## The server identity the socket tests share: made once, by a mint.
var _inv_key: CryptoKey = null
var _inv_cert: X509Certificate = null
## Everything the log must never hold: secrets, invite lines, key text.
var _inv_needles: PackedStringArray = []
## **Every line an invite job gave back in this section.** A job prints them,
## and this section calls the jobs' own code, which prints nothing -- so they
## are checked for secrets here, as the printed ones are. And which jobs ran,
## by flag, so the check can say it saw every kind.
var _inv_job_lines: PackedStringArray = []
var _inv_jobs_run: Dictionary = {}


func _check_invites() -> void:
	var began := _now()
	var began_frames := Engine.get_process_frames()
	var ceiling := Engine.max_fps
	Engine.max_fps = INVITES_FPS
	NetSession.forget_refusals()
	for root: String in [INVITES_ROOT, INVITES_SERVER_ROOT]:
		_invites_wipe(root)
	_inv_needles = PackedStringArray()
	_inv_job_lines = PackedStringArray()
	_inv_jobs_run = {}
	_inv_catcher = LineCatcher.new()
	OS.add_logger(_inv_catcher)
	_invites_format()
	await _invites_calls()
	await _invites_strangers()
	await _invites_welcome()
	await _invites_doors()
	await _invites_room()
	await _invites_house_closed()
	await _invites_server()
	OS.remove_logger(_inv_catcher)
	_invites_no_secret()
	_inv_catcher = null
	_inv_key = null
	_inv_cert = null
	NetSession.forget_refusals()
	for root: String in [INVITES_ROOT, INVITES_SERVER_ROOT]:
		_invites_wipe(root)
	print("[net-probe] NOTE invites took %.1f s and %d frames, at most %d a second"
		% [_now() - began, Engine.get_process_frames() - began_frames, Engine.max_fps])
	Engine.max_fps = ceiling


## **F1-F5: the line, with no socket.** It reads back as written; a messaging
## app's line breaks, spaces, invisible characters and the message around it
## are read through; anything cut short or changed is damage, caught here and
## never a refused proof; a newer version says so; `--reach` reads what an
## owner types; and a guest keeps its invite where only it can read it.
func _invites_format() -> void:
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(InviteBook.KEY_BITS)
	var cert := crypto.generate_self_signed_certificate(key, InviteBook.SUBJECT,
		InviteBook.VALID_FROM, InviteBook.VALID_TO)
	var scratch := INVITES_ROOT.path_join("format.pem")
	DirAccess.make_dir_recursive_absolute(INVITES_ROOT)
	cert.save(scratch)
	var der := Invite.der_of_pem(FileAccess.get_file_as_string(scratch))
	DirAccess.remove_absolute(scratch)
	var key_id := crypto.generate_random_bytes(Invite.KEY_ID_SIZE)
	var secret := crypto.generate_random_bytes(Invite.SECRET_SIZE)
	_invites_hide(secret)
	# F1: a round trip, to each kind of address.
	var round_trips := true
	var lengths: Array = []
	for address: String in ["203.0.113.7", "2001:db8::7", "pond.example.net"]:
		var line := Invite.format(address, 45999, key_id, secret, der)
		var back := Invite.parse(line)
		lengths.append(line.length())
		round_trips = round_trips and int(back["read"]) == Invite.Read.OK \
			and str(back["address"]) == address and int(back["port"]) == 45999 \
			and back["key_id"] == key_id and back["secret"] == secret \
			and back["der"] == der and str(back["line"]) == line \
			and back["certificate"] is X509Certificate
	_says(round_trips and der.size() > 600,
		"invites F1: an invite reads back as written -- to an IPv4 address, an IPv6 one"
		+ " and a name: %s characters, %d of them the certificate's %d bytes"
		% [str(lengths), Marshalls.raw_to_base64(der).length(), der.size()])
	# F2: what a messaging app does to a long line, and the message around it.
	var line := Invite.format("203.0.113.7", Invite.PORT, key_id, secret, der)
	var broken := ""
	for i in line.length():
		broken += line[i]
		if i == 7:
			broken += "\n"
		elif i % 61 == 60:
			broken += "\r\n"
		elif i % 97 == 50:
			broken += " "
		elif i == 300:
			broken += String.chr(0x200B)
		elif i == 400:
			broken += String.chr(0xA0)
		elif i == 500:
			broken += String.chr(0xAD) + "\t"
	var pastes := {
		"line breaks, spaces and invisible characters": broken,
		"a message around it": "hi! here's the way into my pond:\n\n" + broken
			+ "\n\nsee you in there :) -- 8:30?",
		"glued to the words around it": "invite:" + line + "thanks",
		"after a damaged one": line.substr(0, 400) + "\n...\n" + line,
		"a capitalised prefix": "Biogenic-Invite:" + line.substr(Invite.PREFIX.length()),
	}
	var read_through: Array[String] = []
	for what: String in pastes:
		var back := Invite.parse(pastes[what])
		if int(back["read"]) == Invite.Read.OK and str(back["line"]) == line \
				and back["secret"] == secret:
			read_through.append(what)
	_says(read_through.size() == pastes.size(),
		"invites F2: a paste is read through %d ways a chat app leaves it: %s"
		% [read_through.size(), ", ".join(read_through)])
	# F3: cut short, one character changed, a newer version, and none at all.
	var damaged := 0
	var tries := 0
	for cut: int in [line.length() - 1, line.length() - 5, line.length() - 9,
			line.length() / 2, Invite.PREFIX.length() + 3, Invite.PREFIX.length()]:
		tries += 1
		if int(Invite.parse(line.substr(0, cut))["read"]) == Invite.Read.DAMAGED:
			damaged += 1
	for at: int in [Invite.PREFIX.length(), Invite.PREFIX.length() + 2, 100, 500, 900,
			line.length() - 12, line.length() - 3]:
		tries += 1
		# Another letter, not the same one in the other case: the check is hex
		# and read case-blind, so an `a` made `A` there is not damage.
		var changed := line.substr(0, at) + ("B" if line[at].to_lower() == "a" else "A") \
			+ line.substr(at + 1)
		if int(Invite.parse(changed)["read"]) == Invite.Read.DAMAGED:
			damaged += 1
	var inner := "2" + line.substr(Invite.PREFIX.length() + 1,
		line.length() - Invite.PREFIX.length() - 1 - Invite.CHECK_CHARS - 1)
	var newer := Invite.PREFIX + inner + "." + inner.sha256_text().substr(0, Invite.CHECK_CHARS)
	var newer_read := int(Invite.parse("from a later build: " + newer)["read"])
	var nothing := int(Invite.parse("hello")["read"])
	var said := [Invite.says_read(Invite.Read.DAMAGED),
		Invite.says_read(Invite.Read.UNKNOWN_VERSION), Invite.says_read(Invite.Read.NOT_FOUND)]
	_says(damaged == tries and newer_read == Invite.Read.UNKNOWN_VERSION
			and nothing == Invite.Read.NOT_FOUND and int(Invite.parse("")["read"])
				== Invite.Read.NOT_FOUND
			and said[0] != said[1] and said[1] != said[2] and said[0] != said[2],
		"invites F3: %d of %d truncated or one-character-changed invites read as damaged,"
		% [damaged, tries] + " a whole one of version 2 as newer ('%s'), and no invite at"
		% str(said[1][0]) + " all as none -- three sentences, one for each")
	# F4: what an owner types after --reach.
	var reach_ok := true
	for typed: String in ["203.0.113.7", "203.0.113.7:50000", "[2001:db8::7]:50000",
			"2001:db8::7", "Pond.Example.NET.", "pond.example.net:45772"]:
		reach_ok = reach_ok and not Invite.parse_reach(typed).has("error")
	var reach_read := Invite.parse_reach("[2001:db8::7]:50000")
	var name_read := Invite.parse_reach("Pond.Example.NET.")
	var refused := 0
	for typed: String in ["", "203.0.113.7:0", "203.0.113.7:70000", "[2001:db8::7",
			"pond..example.net", "-pond.example.net", "fe80::1%eth0", "a b"]:
		refused += 1 if Invite.parse_reach(typed).has("error") else 0
	_says(reach_ok and str(reach_read["address"]) == "2001:db8::7"
			and int(reach_read["port"]) == 50000 and str(name_read["address"]) == "pond.example.net"
			and int(name_read["port"]) == Invite.channel_port() and refused == 8,
		"invites F4: --reach takes an address, a name or [IPv6] with or without a port,"
		+ " and refuses %d of 8 things that are none of them" % refused)
	# F5: kept once pasted, where only this user reads it.
	var kept_path := INVITES_ROOT.path_join("kept.txt")
	var kept_ok := Invite.keep(pastes["a message around it"], kept_path)
	var mode := FileAccess.get_unix_permissions(kept_path)
	var again := Invite.kept(kept_path)
	var refuses_junk := not Invite.keep("hello", kept_path) \
		and str(Invite.kept(kept_path).get("line", "")) == line
	Invite.forget(kept_path)
	_says(kept_ok and mode == Invite.PRIVATE and str(again.get("line", "")) == line
			and refuses_junk and Invite.kept(kept_path).is_empty(),
		"invites F5: a guest keeps the invite it pasted, clean, rw------- (%o); a paste"
		% mode + " that does not read leaves it as it was; forgotten, it is gone")
	# F6: the two new frames, held to A.3's table as T1 holds the rest -- each
	# exactly its size, from its own side alone, and read back as written.
	var nonce := crypto.generate_random_bytes(Wire.NONCE_SIZE)
	var mac := crypto.generate_random_bytes(Wire.MAC_SIZE)
	var asked := Wire.challenge(nonce)
	var answer := Wire.proof(key_id, nonce, mac)
	var framed := asked.size() == Wire.CHALLENGE_SIZE and answer.size() == Wire.PROOF_SIZE \
		and Wire.known(Wire.KIND_CHALLENGE, 0) and Wire.known(Wire.KIND_PROOF, 0) \
		and Wire.challenge_nonce(asked) == nonce and Wire.proof_parts(answer) == [key_id, nonce, mac]
	for edge: Array in [[Wire.KIND_CHALLENGE, Wire.CHALLENGE_SIZE, true],
			[Wire.KIND_PROOF, Wire.PROOF_SIZE, false]]:
		var kind: int = edge[0]
		var size: int = edge[1]
		var from_host: bool = edge[2]
		framed = framed and Wire.size_ok(kind, 0, size, from_host) \
			and not Wire.size_ok(kind, 0, size - 1, from_host) \
			and not Wire.size_ok(kind, 0, size + 1, from_host) \
			and not Wire.size_ok(kind, 0, size, not from_host)
	_says(framed and Wire.reason_says(Wire.REFUSE_INVITE) != Wire.reason_says(0x7F),
		"invites F6: CHALLENGE is %d bytes and PROOF %d, each exactly and from its own"
		% [Wire.CHALLENGE_SIZE, Wire.PROOF_SIZE] + " side alone -- a byte either side, or"
		+ " the other side, is refused -- and each reads back as written")
	# F7: an address says what it dials (#106) -- at --reach, at the mint, and
	# in a line some older mint wrote.
	# Taken as before: a literal is read by Godot's own parser, decimal, so a
	# zero-padded one and IPv4 in IPv6 clothes that shows its IPv4 address
	# both dial what they show.
	var plain := ["203.0.113.7", "127.0.0.1", "10.0.0.1", "::1", "2001:db8::7",
		"pond.example.net", "localhost", "a1.example", "203.000.113.007",
		"::ffff:203.0.113.7"]
	var disguised := ["2130706433", "127.1", "0x7f.0.0.1", "0x7f000001", "017700000001",
		"0.0.0.0", "0.1.2.3", "255.255.255.255", "224.0.0.1", "240.0.0.1", "::", "ff02::1",
		"::ffff:7f00:1", "::ffff:0.0.0.1", "::ffff:224.0.0.1", "pond.example.123",
		"0:ffff::0.0.0.0", "0000:FFFF::0.0.0.0", "0:ffff::203.0.113.7"]
	# Refused though they dial what they show: `Lan` reads them otherwise, or
	# not at all, and `Lan` is what places an address -- a home network, or a
	# phone's own loopback.
	var unread := ["203.0000.113.7", "0203.0.113.7", "::ffff:203.0000.113.7",
		"1:2:3:4:5:6:7::8", "0:0:0:0:0:0::ffff:203.0.113.7"]
	var wrong: Array = []
	for address: String in plain:
		if not Invite.address_ok(address) or Invite.parse_reach(address).has("error") \
				or int(Invite.parse(Invite.format(address, Invite.PORT, key_id, secret,
					der))["read"]) != Invite.Read.OK:
			wrong.append("refused " + address)
	for address: String in disguised + unread:
		if Invite.address_ok(address) or not Invite.parse_reach(address).has("error") \
				or not Invite.format(address, Invite.PORT, key_id, secret, der).is_empty() \
				or int(Invite.parse(_invite_line_to(address, key_id, secret, der))["read"]) \
					!= Invite.Read.DAMAGED:
			wrong.append("took " + address)
	for address: String in unread:
		if not str(Invite.parse_reach(address).get("error", "")).contains("not read the same"):
			wrong.append("did not say why of " + address)
	_says(wrong.is_empty(),
		"invites F7: %d addresses that show what they dial -- zero-padded, and IPv4 in"
		% plain.size() + " IPv6 clothes showing it, as before -- are taken at --reach, minted"
		+ " and read back; %d that do not -- a number a resolver reads as 127.0.0.1, no"
		% disguised.size() + " machine or every machine, IPv4 in IPv6 clothes written in hex"
		+ " or spelled to dial another address than it shows -- are refused at --reach,"
		+ " never minted, and damage in an old line, as '%s' says;" % str(Invite.parse_reach(
			"2130706433").get("error", "")) + " and so are %d that dial what they show but"
		% unread.size() + " that this build reads otherwise, saying so"
		+ ("" if wrong.is_empty() else " -- NOT: " + ", ".join(PackedStringArray(wrong))))
	# F8: junk behind checks that read costs the log nothing, or a certificate's
	# worth of lines a paste at most (#106).
	var junk := PackedStringArray()
	for n in 2000:
		var spoiled := "1.%s" % ["QUJDRA", "QUI=QUJD", "QQ===", "QUJDRA="][n % 4]
		junk.append(Invite.PREFIX + spoiled + "." + Invite._check_of(spoiled))
	var shaped := PackedByteArray([0x30, 0x82, 0x01, 0x00])
	shaped.resize(4 + 256)
	var fakes := PackedStringArray()
	var shapeless := PackedStringArray()
	for n in 50:
		fakes.append(_invite_line_to("203.0.113.7", key_id, secret, shaped))
		shapeless.append(_invite_line_to("203.0.113.7", key_id, secret,
			crypto.generate_random_bytes(260)))
	var logged := _inv_catcher.lines.size()
	var junk_read := int(Invite.parse(" ".join(junk))["read"])
	junk_read = maxi(junk_read, int(Invite.parse(" ".join(shapeless))["read"]))
	var junk_lines := _inv_catcher.lines.size() - logged
	logged = _inv_catcher.lines.size()
	var fakes_read := int(Invite.parse(" ".join(fakes))["read"])
	var fake_lines := _count(_inv_catcher.lines.slice(logged), "Error parsing X509 certificates")
	var fake_all := _inv_catcher.lines.size() - logged
	var three := " ".join(fakes.slice(0, 3)) + " " + line
	var after_three := int(Invite.parse(three)["read"])
	var more := " ".join(fakes.slice(0, Invite.CERTIFICATES_MAX)) + " " + line
	var after_more := int(Invite.parse(more)["read"])
	# Surrogates on their own, as a Windows clipboard hands over a broken
	# pair: 60,000 of them ahead of a real invite, made by decoding a hundred
	# -- which prints its hundred lines here, before the paste is read.
	var lone_bytes := PackedByteArray()
	for n in 100:
		lone_bytes.append(n)
		lone_bytes.append(0xDC)
	var lone := lone_bytes.get_string_from_utf16().repeat(600)
	logged = _inv_catcher.lines.size()
	var lone_read := int(Invite.parse(lone + " " + line)["read"])
	var lone_lines := _inv_catcher.lines.size() - logged
	_says(junk_read == Invite.Read.DAMAGED and junk_lines == 0 and fakes_read == Invite.Read.DAMAGED
			and fake_lines == Invite.CERTIFICATES_MAX and fake_all == fake_lines
			and after_three == Invite.Read.OK and after_more == Invite.Read.DAMAGED
			and lone.length() == 60000 and lone_read == Invite.Read.OK and lone_lines == 0,
		"invites F8: a paste of 2,000 invites whose base64 does not decode, and one of 50"
		+ " whose certificates are not even DER, print %d engine lines; one of 50" % junk_lines
		+ " whose certificates are DER and do not parse prints %d, the most a paste may: a"
		% fake_lines + " real invite after three of those still reads, and after %d it is"
		% Invite.CERTIFICATES_MAX + " damage; and one behind 60,000 surrogates on their own,"
		+ " as a broken Windows clipboard hands them over, reads and prints %d" % lone_lines)
	# F9: an owner whose --reach, set by an older build, is one this build will
	# not call is told so wherever that --reach is shown -- and changing it
	# still names the invites already sent with it (#106).
	var legacy := INVITES_ROOT.path_join("legacy")
	var set_first: Array = InviteBook.set_reach("203.0.113.7", legacy)
	var minted: Array = InviteBook.mint("dave", legacy)
	var old_reach := ConfigFile.new()
	old_reach.set_value("reach", "address", "2130706433")
	old_reach.set_value("reach", "port", 45772)
	Invite.write_private(str(InviteBook.paths(legacy)["reach"]),
		old_reach.encode_to_text().to_utf8_buffer())
	var stale := InviteBook.reach_refused(legacy)
	var none_taken := InviteBook.reach(legacy).is_empty()
	var listed: Array = InviteBook.listing(legacy)
	var mint_refused: Array = InviteBook.mint("erin", legacy)
	var set_again: Array = InviteBook.set_reach("203.0.113.9", legacy)
	var set_lines := "\n".join(PackedStringArray(set_again[1]))
	# And a port a hand made no port of, as a number and as no number at all:
	# said to be the port's fault, and no script error.
	var said_of_port: Array = []
	for bad_port: Variant in [70000, [1]]:
		old_reach.set_value("reach", "address", "203.0.113.7")
		old_reach.set_value("reach", "port", bad_port)
		Invite.write_private(str(InviteBook.paths(legacy)["reach"]),
			old_reach.encode_to_text().to_utf8_buffer())
		said_of_port.append(InviteBook.reach_refused(legacy))
	# Setting a new one then names the invites already sent by their address
	# alone: no invite ever called a port that is no port.
	var set_past_bad: Array = InviteBook.set_reach("203.0.113.9", legacy)
	var past_bad_lines := "\n".join(PackedStringArray(set_past_bad[1]))
	_invites_wipe(legacy)
	_says(int(set_first[0]) == 0 and int(minted[0]) == 0 and none_taken
			and stale.contains("2130706433:45772") and stale.contains("is a number")
			and str(listed[1][0]).contains(stale) and int(mint_refused[0]) == 1
			and str(mint_refused[1][0]).contains(stale) and int(set_again[0]) == 0
			and set_lines.contains("invites already sent still call 2130706433:45772")
			and str(said_of_port[0]).contains("its port is not one from 1 to 65535")
			and str(said_of_port[1]).contains("before, 203.0.113.7, is not one this build")
			and str(said_of_port[1]).contains("its port is not one from 1 to 65535")
			and past_bad_lines.contains("invites already sent still call 203.0.113.7: mint")
			and not (str(said_of_port[1]) + past_bad_lines).contains(":-1"),
		"invites F9: a --reach an older build stored as 2130706433 is named, not taken for"
		+ " none, at --invites and at the mint ('%s'), and setting a new one still says" % stale
		+ " the invites already sent call the old; a port a hand made no port of is said"
		+ " to be the port's fault, and never shown as one")


## **An invite line to [param address], as [method Invite.format] writes one but
## asking nothing of the address** -- what a mint from before #106 could have
## written, or anybody by hand.
static func _invite_line_to(address: String, key_id: PackedByteArray,
		secret: PackedByteArray, der: PackedByteArray) -> String:
	var payload := PackedByteArray()
	payload.append_array(key_id)
	payload.append_array(secret)
	payload.append(Invite.PORT & 0xFF)
	payload.append((Invite.PORT >> 8) & 0xFF)
	var host := address.to_ascii_buffer()
	payload.append(host.size())
	payload.append_array(host)
	payload.append(der.size() & 0xFF)
	payload.append((der.size() >> 8) & 0xFF)
	payload.append_array(der)
	var inner := "%d.%s" % [Invite.VERSION, Marshalls.raw_to_base64(payload)]
	return Invite.PREFIX + inner + "." + Invite._check_of(inner)


## **C1-C8: calls by invite, to a host of their own each, over DTLS on
## loopback.** The good invite in; a wrong secret and a key id nobody has out,
## the same way, and barred; a revoked invite out, and not dialled twice; a
## certificate that is not the pinned one, and the right one under another
## name, failing fast; a port nothing listens on; and an invite by host name.
func _invites_calls() -> void:
	var minted: Array = _invites_job(["--reach=127.0.0.1", "--invite=alice", "--invite=bob"],
		INVITES_ROOT)
	var identity := InviteBook.load_identity(INVITES_ROOT)
	_inv_key = identity[0]
	_inv_cert = identity[1]
	_invites_hide_book(INVITES_ROOT)
	var alice := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("alice", INVITES_ROOT)))
	var bob := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("bob", INVITES_ROOT)))
	_says(int(minted[0]) == 0 and int(alice["read"]) == Invite.Read.OK
			and int(bob["read"]) == Invite.Read.OK and alice["key_id"] != bob["key_id"],
		"invites C0: two invites minted from the command line's own code, each with its"
		+ " own key id and secret, both calling 127.0.0.1:%d" % Invite.channel_port())
	# J1: a job root would run into another user's files is refused, with the
	# command to run instead; root in its own, and anybody else, goes on. The
	# rule is asked with the owners given, since this probe runs as root in one
	# place and not in another -- and then of this machine, as it is.
	var theirs := {"/var/lib/biogenic/.local/share/godot/app_userdata/Biogenic": [998,
		"biogenic"]}
	var exe := "/opt/biogenic/biogenic-server.x86_64"
	var job := PackedStringArray(["--revoke=sam"])
	var refused := InviteBook.ownership_refusal(0, theirs, job, exe, "/var/lib/biogenic")
	var roots_own := InviteBook.ownership_refusal(0, {"/root": [0, "root"]}, job, exe, "/root")
	var not_root := InviteBook.ownership_refusal(998, theirs, job, exe, "/var/lib/biogenic")
	var asked_at := Time.get_ticks_usec()
	var found := InviteBook.owners(INVITES_ROOT)
	var asked_ms := float(Time.get_ticks_usec() - asked_at) / 1000.0
	var here := InviteBook.ownership_refusal(int(found["uid"]), found["owners"], job, exe,
		OS.get_environment("HOME"))
	_says(refused.begins_with("refused: this runs as root")
			and refused.contains("runuser -u biogenic -- env HOME=/var/lib/biogenic"
				+ " /opt/biogenic/biogenic-server.x86_64 --headless -- --revoke=sam")
			and roots_own.is_empty() and not_root.is_empty() and here.is_empty(),
		"invites J1: a job run as root into files another user owns is refused, naming the"
		+ " command to run as that user; root in its own files, and any other user, goes on"
		+ " -- as here, uid %d, where asking took %.1f ms" % [int(found["uid"]), asked_ms])
	# J2: run as root but unable to read who owns the files (owners() could not
	# stat them), the job fails closed rather than write what the service user
	# might not read back (#71).
	var unverified := InviteBook.ownership_refusal(0, {}, job, exe, "/var/lib/biogenic", false)
	var verified_clean := InviteBook.ownership_refusal(0, {}, job, exe, "/var/lib/biogenic", true)
	_says(unverified.begins_with("refused: this runs as root")
			and unverified.contains("could not read who owns")
			and verified_clean.is_empty(),
		"invites J2: run as root but unable to read who owns the files, the job fails closed"
		+ " -- it refuses rather than write what the service user might not read")
	# J3: the book keeps InviteBook.INVITES_MAX invites at most (#85). A name
	# past them is refused, named, told what to do, and writes nothing -- not a
	# byte of the book, the key or the certificate; a name already in the book
	# is minted again; a revoke makes room, and the book no longer says it is
	# full. A book an older build grew past the cap keeps every invite, and is
	# told how many to revoke. It is filled as mint writes it, after one real
	# mint has made the key.
	var full := INVITES_ROOT.path_join("full")
	_invites_wipe(full)
	var full_first: Array = _invites_job(["--reach=203.0.113.7", "--invite=f000"], full)
	var many := InviteBook.entries(full)
	var random := Crypto.new()
	for i in range(1, InviteBook.INVITES_MAX):
		many["f%03d" % i] = {"created": 1790000000,
			"key_id": random.generate_random_bytes(Invite.KEY_ID_SIZE).hex_encode(),
			"secret": random.generate_random_bytes(Invite.SECRET_SIZE)}
	var filled := InviteBook._write_book(many, full)
	var files := InviteBook.paths(full)
	var before: Array = []
	for what: String in ["book", "key", "cert"]:
		before.append(FileAccess.get_file_as_bytes(str(files[what])))
	var one_more: Array = InviteBook.mint("latecomer", full)
	var refusal := "\n".join(PackedStringArray(one_more[1]))
	var after: Array = []
	for what: String in ["book", "key", "cert"]:
		after.append(FileAccess.get_file_as_bytes(str(files[what])))
	var wrote_none := after == before and not (before[0] as PackedByteArray).is_empty() \
		and not FileAccess.file_exists(InviteBook.line_path("latecomer", full))
	var listed_full := "\n".join(PackedStringArray(InviteBook.listing(full)[1]))
	var again: Array = InviteBook.mint("f042", full)
	var made_room: Array = InviteBook.revoke("f007", full)
	var listed_room := "\n".join(PackedStringArray(InviteBook.listing(full)[1]))
	var room: Array = InviteBook.mint("latecomer", full)
	var kept := InviteBook.entries(full)
	# Grown past the cap, as a build before #85 could: 150 invites.
	var grown := kept.duplicate()
	for i in range(InviteBook.INVITES_MAX, 150):
		grown["f%03d" % i] = {"created": 1790000000,
			"key_id": random.generate_random_bytes(Invite.KEY_ID_SIZE).hex_encode(),
			"secret": random.generate_random_bytes(Invite.SECRET_SIZE)}
	var grew := InviteBook._write_book(grown, full)
	var grown_bytes := FileAccess.get_file_as_bytes(str(files["book"]))
	var past: Array = InviteBook.mint("another", full)
	var past_said := "\n".join(PackedStringArray(past[1]))
	var listed_past := "\n".join(PackedStringArray(InviteBook.listing(full)[1]))
	var past_kept := InviteBook.entries(full).size() == 150 \
		and FileAccess.get_file_as_bytes(str(files["book"])) == grown_bytes
	_invites_wipe(full)
	var most := InviteBook.INVITES_MAX
	_says(int(full_first[0]) == 0 and filled == OK and int(one_more[0]) == 1 and wrote_none
			and refusal.contains("no invite made for latecomer")
			and refusal.contains("holds %d invites, and keeps %d at most. Revoke one" % [most,
				most]) and listed_full.contains("the book is full")
			and listed_full.contains("revoke one") and int(again[0]) == 0
			and int(made_room[0]) == 0 and not listed_room.contains("the book is full")
			and int(room[0]) == 0 and kept.size() == most and kept.has("latecomer")
			and not kept.has("f007") and grew == OK and int(past[0]) == 1 and past_kept
			and past_said.contains("holds 150 invites") and past_said.contains("Revoke 51")
			and listed_past.contains("revoke 51"),
		"invites J3: the book keeps %d invites at most (#85): one more name is refused" % most
		+ " and writes nothing ('%s'), and --invites says the book is full; a name" % refusal
		+ " already in it is minted again, and a revoke makes room; a book of 150 an older"
		+ " build made keeps all 150, and is told to revoke 51")
	# C1: in.
	var host: Node = await _invites_host("InvCallsHost")
	var proved: Array = []
	host.invite_proved.connect(func(label: String, _key: String) -> void: proved.append(label))
	var guest: Node = await _session("InvCallsAlice")
	var took := await _invites_call(guest, alice)
	var gid: int = guest.my_id()
	_says(int(guest.link) == NetSession.Link.TOGETHER and int(host.link) == NetSession.Link.TOGETHER
			and int(host.via_of(gid)) == NetSession.VIA_NET and str(host.label_of(gid)) == "alice"
			and proved == ["alice"] and int(host.gate_counts["proofs"]) == 1,
		"invites C1: a good invite reaches TOGETHER over DTLS in %.2f s -- ENet's first" % took
		+ " resend, as C.1 measured -- and the host holds it as alice's, on the internet"
		+ " listener")
	guest.close()
	await _limits_until(func() -> bool: return int(host.peer_count()) == 0)
	# C2 and C3: a wrong secret and an unknown key id, answered alike.
	var wrong := alice.duplicate()
	wrong["secret"] = Crypto.new().generate_random_bytes(Invite.SECRET_SIZE)
	var unknown := alice.duplicate()
	unknown["key_id"] = Crypto.new().generate_random_bytes(Invite.KEY_ID_SIZE)
	var answers: Array = []
	var bars: Array = []
	for bad: Dictionary in [wrong, unknown]:
		var caller: Node = await _session("InvCallsBad%d" % answers.size())
		var spent := await _invites_call(caller, bad)
		answers.append([int(caller.link), str(caller.trouble_key), str(caller.trouble),
			str(caller.because)])
		var book: Dictionary = host.get("_net_book")
		bars.append(float(book.get("127.0.0.1", {}).get("barred_until", 0.0)) - _now())
		print("[net-probe] NOTE invites: a %s refused after %.2f s"
			% ["wrong secret" if bars.size() == 1 else "key id nobody has", spent])
		caller.close()
		# Its bar served, by hand, for the next call from the same address.
		book["127.0.0.1"]["barred_until"] = 0.0
	var lan_book: Dictionary = host.get("_book")
	_says(answers[0] == answers[1] and int(answers[0][0]) == NetSession.Link.REFUSED
			and str(answers[0][1]) == "invite_refused"
			and int(host.gate_counts["proofs_refused"]) == 2
			and float(bars[0]) > 0.0 and float(bars[1]) > 0.0
			and not lan_book.has("127.0.0.1") and int(host.peer_count()) == 0,
		"invites C2-C3: a wrong secret and a key id nobody has get the same answer --"
		+ " '%s' -- and each bars the address at the internet door (%.0f s, then %.0f s),"
		% [answers[0][2], bars[0], bars[1]] + " and not at the LAN's")
	# C4: revoked before the call -- bob's stays, so the listener stays open.
	_invites_job(["--revoke=alice"], INVITES_ROOT)
	host.set_invites(InviteBook.table(INVITES_ROOT))
	var revoked: Node = await _session("InvCallsRevoked")
	await _invites_call(revoked, alice)
	var first_key := str(revoked.trouble_key)
	var calls_before := int(host.gate_counts["proofs_refused"])
	var dialled_at := _now()
	revoked.call_invite(alice)
	var instant := _now() - dialled_at
	await _wait(0.3)
	_says(first_key == "invite_refused" and str(revoked.trouble_key) == "invite_refused"
			and int(revoked.link) == NetSession.Link.REFUSED and instant < 0.05
			and int(host.gate_counts["proofs_refused"]) == calls_before
			and bool(host.internet_listening()),
		"invites C4: an invite revoked before the call is refused the same way, and"
		+ " calling it again is refused in %.0f ms without dialling -- the server bars"
		% (instant * 1000.0) + " a second refused proof for ten minutes")
	revoked.close()
	(host.get("_net_book") as Dictionary).clear()
	# C5: a certificate that is not the one pinned.
	var crypto := Crypto.new()
	var other_key := crypto.generate_rsa(InviteBook.KEY_BITS)
	var other := bob.duplicate()
	other["certificate"] = crypto.generate_self_signed_certificate(other_key,
		InviteBook.SUBJECT, InviteBook.VALID_FROM, InviteBook.VALID_TO)
	var stranger: Node = await _session("InvCallsOtherCert")
	var other_took := await _invites_call(stranger, other)
	var other_said := [int(stranger.link), str(stranger.trouble_key)]
	stranger.close()
	var still_up: bool = host.internet_listening() and int(host.peer_count()) == 0
	await _limits_close([host])
	# C6: the right certificate, under another name.
	var renamed := crypto.generate_self_signed_certificate(_inv_key, "CN=someone-else",
		InviteBook.VALID_FROM, InviteBook.VALID_TO)
	var named_host: Node = await _session("InvCallsNamedHost")
	named_host.host(NetSession.GUESTS_MAX)
	named_host.listen_internet(_inv_key, renamed)
	named_host.set_invites(InviteBook.table(INVITES_ROOT))
	var named := bob.duplicate()
	named["certificate"] = renamed
	var misnamed: Node = await _session("InvCallsWrongName")
	var named_took := await _invites_call(misnamed, named)
	var named_said := [int(misnamed.link), str(misnamed.trouble_key)]
	misnamed.close()
	var named_up: bool = named_host.internet_listening()
	_says(other_said == [NetSession.Link.FAILED, "not_this_pond"]
			and named_said == [NetSession.Link.FAILED, "not_this_pond"]
			and other_took < 1.0 and named_took < 1.0 and still_up and named_up,
		"invites C5-C6: another server's certificate fails in %.0f ms, and the right one"
		% (other_took * 1000.0) + " under another name in %.0f ms, both '%s', and"
		% [named_took * 1000.0, Invite.says(&"not_this_pond")[0]] + " each server stays up")
	# C7: a port nothing listens on refuses the call at once, and says so.
	named_host.close_internet(true)
	var closed: Node = await _session("InvCallsClosed")
	var closed_took := await _invites_call(closed, bob)
	_says(int(closed.link) == NetSession.Link.FAILED and str(closed.trouble_key) == "not_running"
			and closed_took < 1.0,
		"invites C7: a call to a port nothing listens on fails in %.0f ms as '%s', not as"
		% [closed_took * 1000.0, closed.trouble] + " another server -- the second look,"
		+ " with no pin, is refused too")
	closed.close()
	await _limits_close([named_host])
	# C8: an invite by host name, resolved off the frame; and one that is not.
	host = await _invites_host("InvCallsNameHost")
	var by_name := bob.duplicate()
	by_name["address"] = "localhost"
	var named_guest: Node = await _session("InvCallsByName")
	var name_took := await _invites_call(named_guest, by_name)
	var nowhere := bob.duplicate()
	nowhere["address"] = "nothing-here.invalid"
	var lost: Node = await _session("InvCallsNowhere")
	await _invites_call(lost, nowhere)
	var asked_named := str(named_guest.looked_up)
	var asked_lost := str(lost.looked_up)
	_says(int(named_guest.link) == NetSession.Link.TOGETHER
			and int(lost.link) == NetSession.Link.FAILED
			and str(lost.trouble_key) == "no_such_place"
			and asked_named == str([IP.TYPE_IPV4])
			and asked_lost == str([IP.TYPE_IPV4, IP.TYPE_IPV6]),
		"invites C8: an invite that names its host by name is resolved on the engine's"
		+ " resolver thread, over IPv4 alone when it has an IPv4 address, and reaches"
		+ " TOGETHER in %.2f s; one under .invalid, asked for IPv4 and then IPv6," % name_took
		+ " ends as '%s'" % lost.trouble)
	await _limits_close([host, named_guest, lost])
	# C9: the pin is held to the phone's clock, and to the key (issue #89). A
	# certificate on the server's own key that ended in 2021 is refused
	# whichever side holds it -- which is why the server's runs from 2020 to
	# 2099 -- and one made again on the same key, with other dates, passes an
	# invite that pinned the first: only a new key voids an invite.
	var ended := crypto.generate_self_signed_certificate(_inv_key, InviteBook.SUBJECT,
		"20200101000000", "20211231235959")
	var renewed := crypto.generate_self_signed_certificate(_inv_key, InviteBook.SUBJECT,
		"20210101000000", "20981231235959")
	var dated := {}
	for case: Array in [["the server's ended", ended, _inv_cert],
			["the pinned one ended", _inv_cert, ended], ["made again", renewed, _inv_cert]]:
		var dated_host: Node = await _session("InvCallsDatedHost")
		dated_host.host(NetSession.GUESTS_MAX)
		dated_host.listen_internet(_inv_key, case[1])
		dated_host.set_invites(InviteBook.table(INVITES_ROOT))
		var pinned := bob.duplicate()
		pinned["certificate"] = case[2]
		var dated_guest: Node = await _session("InvCallsDated")
		await _invites_call(dated_guest, pinned)
		dated[case[0]] = [int(dated_guest.link), str(dated_guest.trouble_key)]
		await _limits_close([dated_guest, dated_host])
	var refused_both: bool = dated["the server's ended"] == [NetSession.Link.FAILED,
		"not_this_pond"] and dated["the pinned one ended"] == [NetSession.Link.FAILED,
		"not_this_pond"]
	_says(refused_both and int(dated["made again"][0]) == NetSession.Link.TOGETHER,
		"invites C9: a certificate on the server's own key that ended in 2021 fails the pin"
		+ " on either side, as '%s' -- why the server's runs 2020 to 2099" % Invite.says(
			&"not_this_pond")[0] + " -- and one made again on the same key with other dates"
		+ " passes an invite that pinned the first: only a new key voids an invite")


## **S1-S10: callers that are not guests, at the internet listener.** A plain
## ENet caller at the DTLS port, and a DTLS caller at the LAN's, both end as no
## answer. Then DTLS [Rogue]s: two that never prove -- one says HELLO and
## nothing more, one says nothing -- which are hung up on and barred, count for
## nothing in what the updater waits for, and cannot hold the waiting room by
## calling back; one that sends a STATE before its PROOF, a PROOF before its
## CHALLENGE, a second HELLO, a second PROOF after a good one, and an old
## protocol -- which is refused before it is ever challenged.
func _invites_strangers() -> void:
	var bob := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("bob", INVITES_ROOT)))
	var host: Node = await _invites_host("InvStrangersHost")
	# S1 and S2 together: each waits out its own timeout.
	var plain: Node = await _session("InvPlainAtInternet")
	_invites_join_port(plain, Invite.channel_port())
	var crossed: Node = await _session("InvDtlsAtLan")
	var at_lan := bob.duplicate()
	at_lan["port"] = Lan.channel_port()
	crossed.call_invite(at_lan)
	var waited := await _limits_until(func() -> bool:
		return int(plain.link) != NetSession.Link.REACHING \
			and int(crossed.link) != NetSession.Link.REACHING,
		NetSession.INVITE_REACH_TIMEOUT + 3.0)
	_says(waited >= 0.0 and int(plain.link) == NetSession.Link.FAILED
			and str(plain.trouble) == "no answer" and int(crossed.link) == NetSession.Link.FAILED
			and str(crossed.trouble_key) == "no_answer" and int(host.peer_count()) == 0
			and int(host.link) == NetSession.Link.LISTENING and bool(host.internet_listening())
			and int(host.gate_counts["refused"]) == 0,
		"invites S1-S2: a plain ENet caller at the internet port and a DTLS caller at the"
		+ " LAN's both end as no answer, and the host is up, with nobody let near either door")
	await _limits_close([plain, crossed])
	# S3: two strangers that never prove -- one says HELLO and nothing after
	# its CHALLENGE, one says nothing at all -- from 127.0.0.2 and .3, so the
	# friend of S10 can call from .1.
	var quiet := _invites_stranger("InvStrangerQuiet", "127.0.0.2", 47290)
	var mute := _invites_stranger("InvStrangerMute", "127.0.0.3", 47291)
	var connected_at := [-1.0]
	await _limits_until(func() -> bool:
		if quiet.connected() and float(connected_at[0]) < 0.0:
			connected_at[0] = _now()
		return quiet.connected() and mute.connected())
	quiet.send(_hello())
	await _limits_until(func() -> bool: return not quiet.challenge().is_empty())
	var challenged := quiet.challenge().size() == Wire.NONCE_SIZE
	# S9, meanwhile: what the server's updater would wait for, beside what
	# peer_count() says -- with a LAN caller saying nothing either, and then
	# without it.
	var hush := Rogue.new()
	hush.name = "InvStrangerLanHush"
	add_child(hush)
	hush.call_host()
	await _limits_until(func() -> bool: return hush.connected() and int(host.peer_count()) == 3)
	var with_lan := [int(host.company()), int(host.peer_count())]
	hush.hang_up()
	await _limits_until(func() -> bool: return int(host.peer_count()) == 2)
	var without_lan := [int(host.company()), int(host.peer_count())]
	await _limits_until(func() -> bool: return quiet.down() and mute.down(),
		NetSession.HELLO_GRACE + NetSession.REFUSE_LINGER + 2.0)
	var told_after := quiet.refused_at - float(connected_at[0])
	var net_book: Dictionary = host.get("_net_book")
	var lan_book: Dictionary = host.get("_book")
	var held: Array = []
	for from: String in ["127.0.0.2", "127.0.0.3"]:
		held.append(float(net_book.get(from, {}).get("barred_until", 0.0)) - _now())
	_says(challenged and quiet.refused_for() == Wire.REFUSE_SILENT
			and mute.refused_for() == Wire.REFUSE_SILENT and quiet.down() and mute.down()
			and told_after >= NetSession.HELLO_GRACE - 0.5
			and told_after < NetSession.HELLO_GRACE + 1.0
			and float(held[0]) > NetSession.BAR_FIRST - 10.0
			and float(held[1]) > NetSession.BAR_FIRST - 10.0
			and not lan_book.has("127.0.0.2") and not lan_book.has("127.0.0.3")
			and int(host.gate_counts["net_silent"]) == 2,
		"invites S3: a stranger that says HELLO and nothing after its CHALLENGE, and one"
		+ " that says nothing at all, are each told REFUSE_SILENT %.2f s after they"
		% told_after + " connected, cut, and barred at the internet door for %.0f s -- not"
		% float(held[0]) + " at the LAN's -- as a wrong proof is")
	# S10: straight back, each -- refused at the door as barred, so neither
	# takes a place in the waiting room -- and a friend with an invite is in.
	var refused_barred := int(host.gate_counts["net_refused_barred"])
	var again := [_invites_stranger("InvStrangerBack0", "127.0.0.2", 47292),
		_invites_stranger("InvStrangerBack1", "127.0.0.3", 47293)]
	await _limits_until(func() -> bool:
		return (again[0] as Rogue).down() and (again[1] as Rogue).down(), 4.0)
	var friend: Node = await _session("InvStrangerFriend")
	await _invites_call(friend, bob)
	var friend_counts := [int(host.company()), int(host.peer_count())]
	_says(int(host.gate_counts["net_refused_barred"]) == refused_barred + 2
			and int(friend.link) == NetSession.Link.TOGETHER,
		"invites S10: both call straight back and are refused at the door as barred, taking"
		+ " no place in the waiting room, and a friend calling by invite is in")
	_says(with_lan == [1, 3] and without_lan == [0, 2] and friend_counts == [1, 1],
		"invites S9: what the updater waits for is the pond's company, not every peer: two"
		+ " strangers on the internet listener that have proved nothing and a LAN caller"
		+ " saying hello are %d of %d peers, the strangers alone %d of %d, and a friend"
		% [with_lan[0], with_lan[1], without_lan[0], without_lan[1]]
		+ " who proved an invite %d of %d" % [friend_counts[0], friend_counts[1]])
	await _limits_close([friend] + again)
	# S4, S5 and S7: the wrong thing before the PROOF, each cut at once -- and
	# barred (#103), so each from an address of its own: 127.0.0.4, .5, .6.
	var proofs_before := int(host.gate_counts["proofs"])
	var early: Array = []
	var early_barred := 0
	for what: String in ["a STATE before its PROOF", "a PROOF before any CHALLENGE",
			"a second HELLO"]:
		var source := "127.0.0.%d" % (4 + early.size())
		var rogue := _invites_stranger("InvStranger%d" % early.size(), source,
			47296 + early.size())
		await _limits_until(func() -> bool: return rogue.connected())
		var cuts := int(host.gate_counts["cuts"])
		if what != "a PROOF before any CHALLENGE":
			rogue.send(_hello())
			await _limits_until(func() -> bool: return not rogue.challenge().is_empty())
		match what:
			"a STATE before its PROOF":
				rogue.send(Wire.state(1, true, Vector2.ZERO, 0.0, 26.0))
			"a PROOF before any CHALLENGE":
				rogue.send(Wire.proof(bob["key_id"], PackedByteArray(), PackedByteArray()))
			"a second HELLO":
				rogue.send(_hello())
		var gone := await _limits_until(func() -> bool: return rogue.down(), 2.0)
		if gone >= 0.0 and int(host.gate_counts["cuts"]) == cuts + 1 and not rogue.welcomed():
			early.append(what)
		if float(net_book.get(source, {}).get("barred_until", 0.0)) > _now():
			early_barred += 1
	_says(early.size() == 3 and early_barred == 3 and int(host.gate_counts["strikes"]) == 0
			and int(host.gate_counts["proofs"]) == proofs_before,
		"invites S4-S5, S7: %s -- each cut the moment it spoke, with no strike, and barred"
		% ", ".join(early) + " at the internet door (%d of 3): no Biogenic build speaks"
		% early_barred + " out of turn there")
	# S8: an old protocol is refused on the compatibility check, before any
	# CHALLENGE, and barred for a minute -- a minute again the next time, never
	# the ten of a second bar (#103); a real guest reads the far sentence for it.
	var old_from := "127.0.0.7"
	var old := _invites_stranger("InvStrangerOld", old_from, 47299)
	await _limits_until(func() -> bool: return old.connected())
	old.send(Wire.hello(Wire.PROTOCOL - 1))
	await _limits_until(func() -> bool: return old.refused_for() >= 0)
	var old_held := float(net_book.get(old_from, {}).get("barred_until", 0.0)) - _now()
	# The minute brought to its end here, rather than waited out.
	if net_book.has(old_from):
		(net_book[old_from] as Dictionary)["barred_until"] = _now()
	var old_again := _invites_stranger("InvStrangerOldAgain", old_from, 47287)
	await _limits_until(func() -> bool: return old_again.connected())
	old_again.send(Wire.hello(Wire.PROTOCOL - 1))
	await _limits_until(func() -> bool: return old_again.refused_for() >= 0)
	var again_held := float(net_book.get(old_from, {}).get("barred_until", 0.0)) - _now()
	var old_guest: Node = await _session("InvStrangerOldGuest")
	old_guest.protocol_override = Wire.PROTOCOL - 1
	await _invites_call(old_guest, bob)
	_says(old.refused_for() == Wire.REFUSE_PROTOCOL and old.challenge().is_empty()
			and old_again.refused_for() == Wire.REFUSE_PROTOCOL
			and old_held > NetSession.BAR_FIRST - 10.0 and old_held < NetSession.BAR_FIRST + 0.5
			and again_held > NetSession.BAR_FIRST - 10.0
			and again_held < NetSession.BAR_FIRST + 0.5
			and int(old_guest.link) == NetSession.Link.REFUSED
			and str(old_guest.trouble_key) == "game_older",
		"invites S8: a caller on protocol %d is refused on the compatibility"
		% (Wire.PROTOCOL - 1) + " check before it is ever challenged, and barred for"
		+ " %.0f s -- and %.0f s the next time, not ten minutes -- and a guest reads"
		% [old_held, again_held] + " '%s: %s'" % [old_guest.trouble, old_guest.because])
	# S8b (gene-catalogue.md §11.4): one protocol and other rules -- a guest whose
	# catalogue held one more judged gene as it called -- is refused on the same
	# check, before any CHALLENGE, and reads the far sentence for whichever end is
	# older by content version: this game, or the server.
	var keys: Array[String] = []
	var proved := 0
	for pair: Array in [[5, 6], [7, 6]]:
		if net_book.has("127.0.0.1"):
			(net_book["127.0.0.1"] as Dictionary)["barred_until"] = _now()
		host.content_override = int(pair[1])
		var skewed: Node = await _session("InvRulesGuest%d" % int(pair[0]))
		skewed.content_override = int(pair[0])
		Catalogue.register(_faster_tail())
		skewed.call_invite(bob)
		Catalogue.forget(Catalogue.organ_of(&"probeswift"))
		await _limits_until(func() -> bool: return int(skewed.link) != NetSession.Link.REACHING,
			NetSession.INVITE_REACH_TIMEOUT + NetSession.RESOLVE_TIMEOUT + 2.0)
		keys.append("%s %s %d" % [str(skewed.trouble_key), "refused"
			if int(skewed.link) == NetSession.Link.REFUSED else "not refused",
			int(skewed.refused_for)])
		# A guest by invite answers a CHALLENGE with its one PROOF: none here.
		proved += 1 if bool(skewed.get("_proved")) else 0
		await _limits_close([skewed])
	host.content_override = -1
	if net_book.has("127.0.0.1"):
		(net_book["127.0.0.1"] as Dictionary)["barred_until"] = _now()
	_says(keys == ["game_older refused %d" % Wire.REFUSE_PROTOCOL,
			"server_older refused %d" % Wire.REFUSE_PROTOCOL] and proved == 0,
		"invites S8b: a caller on protocol %d by other rules -- one more judged gene --"
		% Wire.PROTOCOL + " is refused on the compatibility check before it is challenged,"
		+ " and reads that its game is older, or the server, by content version (%s)"
		% ", ".join(keys))
	# S6: a good PROOF, then another -- cut, told and barred.
	var twice_from := "127.0.0.8"
	var twice := _invites_stranger("InvStrangerTwice", twice_from, 47288)
	await _limits_until(func() -> bool: return twice.connected())
	twice.send(_hello())
	await _limits_until(func() -> bool: return not twice.challenge().is_empty())
	var mine := Crypto.new().generate_random_bytes(Wire.NONCE_SIZE)
	var proof := Wire.proof(bob["key_id"], mine, Invite.proof_mac(bob["secret"], Wire.PROTOCOL,
		twice.challenge(), mine, bob["key_id"]))
	twice.send(proof)
	await _limits_until(func() -> bool: return twice.welcomed())
	var welcomed := twice.welcomed()
	twice.send(proof)
	await _limits_until(func() -> bool: return twice.down(), 3.0)
	var barred := float(net_book.get(twice_from, {}).get("barred_until", 0.0)) > _now()
	_says(welcomed and twice.refused_for() == Wire.REFUSE_BROKEN and twice.down() and barred
			and int(host.gate_counts["proofs"]) == proofs_before + 1,
		"invites S6: a caller that proves bob's invite and is welcomed, then sends a second"
		+ " PROOF, is cut with REFUSE_BROKEN and barred")
	# S8d (gene-catalogue.md §11.3): before a PROOF, a refusal on the internet listener
	# says which game is older and nothing else of the server's build -- its rules all
	# zeros, and for a content version 0 where the server is the older, CONTENT_NEWER
	# where it is the newer, and the caller's own on a tie -- while a caller on the LAN
	# listener is told the server's whole tail, as before. Three strangers on other
	# rules, at contents either side of the server's 6 and on it, each from an address
	# of its own so that no bar is another's; and a real guest on the tie, by invite,
	# reads the sentence it always did.
	host.content_override = 6
	var other_rules := _other_tail(0).slice(0, Wire.RULES_SIZE)
	var said: Array = []
	var says: Array = []
	for theirs: int in [7, 5, 6]:
		var stranger := _invites_stranger("InvStrangerSays%d" % theirs,
			"127.0.0.%d" % (9 + said.size()), 47280 + said.size())
		said.append(stranger)
		await _limits_until(func() -> bool: return stranger.connected())
		stranger.send(Wire.hello(Wire.PROTOCOL, Wire.tail(other_rules, theirs)))
		await _limits_until(func() -> bool: return not stranger.refusal().is_empty())
		var told := stranger.refusal()
		says.append([Wire.refuse_reason(told) if not told.is_empty() else -1,
			Wire.rules_of(told).hex_encode(), Wire.content_of(told)])
	var near := Rogue.new()
	near.name = "InvLanSays"
	add_child(near)
	near.call_host()
	await _limits_until(func() -> bool: return near.connected())
	near.send(Wire.hello(Wire.PROTOCOL, Wire.tail(other_rules, 7)))
	await _limits_until(func() -> bool: return not near.refusal().is_empty())
	var lan_told := near.refusal()
	if net_book.has("127.0.0.1"):
		(net_book["127.0.0.1"] as Dictionary)["barred_until"] = _now()
	var tied: Node = await _session("InvRulesGuestTie")
	tied.content_override = 6
	Catalogue.register(_faster_tail())
	tied.call_invite(bob)
	Catalogue.forget(Catalogue.organ_of(&"probeswift"))
	await _limits_until(func() -> bool: return int(tied.link) != NetSession.Link.REACHING,
		NetSession.INVITE_REACH_TIMEOUT + NetSession.RESOLVE_TIMEOUT + 2.0)
	host.content_override = -1
	if net_book.has("127.0.0.1"):
		(net_book["127.0.0.1"] as Dictionary)["barred_until"] = _now()
	var zeros := Wire.tail(PackedByteArray(), 0).slice(0, Wire.RULES_SIZE).hex_encode()
	var versions := Wire.REFUSE_PROTOCOL
	_says(says == [[versions, zeros, 0], [versions, zeros, NetSession.CONTENT_NEWER],
			[versions, zeros, 6]] and Wire.refuse_reason(lan_told) == versions
			and Wire.rules_of(lan_told) == (host.get("_rules") as PackedByteArray)
			and Wire.content_of(lan_told) == 6
			and int(tied.link) == NetSession.Link.REFUSED
			and str(tied.trouble_key) == "server_older",
		"invites S8d: before a PROOF, a refusal on the internet listener says which game is"
		+ " older and nothing else -- strangers on other rules at contents 7, 5 and 6, the"
		+ " server on 6, are refused with rules of zeros and content 0, %d and 6 (%s) --"
		% [NetSession.CONTENT_NEWER, str(says.map(func(one: Array) -> int: return one[2]))]
		+ " while a LAN caller is told the server's own rules and content (%d); and a guest"
		% Wire.content_of(lan_told) + " on the tie, by invite, reads '%s: %s'"
		% [tied.trouble, tied.because])
	await _limits_close([host, quiet, mute, old, old_again, old_guest, twice, near, tied]
		+ said)


## **S8c: the guest's half of the rules check, by invite** (gene-catalogue.md §11.3):
## a server whose WELCOME, after the guest proved bob's invite, carries another build's
## tail -- one more judged gene on a later content -- or none at all, is refused from
## the guest's end in the server's own words, this game older or the server, and the
## guest never plays there.
func _invites_welcome() -> void:
	var bob := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("bob", INVITES_ROOT)))
	for case: Array in [["another build's tail, on a later content", _other_tail(6),
			"game_older"], ["no tail at all", PackedByteArray(), "server_older"]]:
		var ended: Array = await _welcomed_by_other("InvWelcome%d"
			% (case[1] as PackedByteArray).size(), case[1], bob)
		_says(int(ended[0]) == NetSession.Link.REFUSED and str(ended[2]) == str(case[2])
				and not bool(ended[4]),
			"invites S8c: a guest on content 5 that proved bob's invite and was welcomed with"
			+ " %s gives up on the WELCOME, told %s -- '%s: %s' -- and is never together"
			% [case[0], case[2], ended[1], ended[3]] + " with that server -- it %s"
			% ("was, for a while" if bool(ended[4]) else "never was"))


## **D1-D3: the doors.** The LAN-only guard is the LAN listener's alone; a
## storm of internet callers fills the internet side's waiting room and its
## bucket for everybody, and a LAN caller is answered all the same; and one id
## on both listeners is refused, never merged.
func _invites_doors() -> void:
	var bob := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("bob", INVITES_ROOT)))
	# D1: loopback made a stranger to the LAN door (the seam).
	var host: Node = await _invites_host("InvGuardHost")
	host.loopback_is_local = false
	var lan_caller: Node = await _session("InvGuardLan")
	lan_caller.join("127.0.0.1")
	await _limits_until(func() -> bool:
		return int(host.gate_counts["refused_lan"]) >= 1 \
			and int(lan_caller.link) != NetSession.Link.REACHING)
	var far: Node = await _session("InvGuardFar")
	await _invites_call(far, bob)
	_says(int(host.gate_counts["refused_lan"]) == 1
			and int(lan_caller.link) != NetSession.Link.TOGETHER
			and int(far.link) == NetSession.Link.TOGETHER
			and int(host.via_of(far.my_id())) == NetSession.VIA_NET,
		"invites D1: with loopback a stranger to the LAN door, a LAN call from 127.0.0.1 is"
		+ " refused as not on this network, and an internet call from the same address"
		+ " proves bob's invite and is in: the guard is the LAN listener's alone")
	await _limits_close([host, lan_caller, far])
	# D2: a storm on the internet listener, from three addresses, saying nothing.
	host = await _invites_host("InvStormHost")
	var storm: Array[Rogue] = []
	var most := [0]
	var watch := func() -> void:
		var waiting := 0
		for id: int in host.peer_ids():
			var peer: Dictionary = (host.get("_peers") as Dictionary)[id]
			if not bool(peer["greeted"]) and int(peer["via"]) == NetSession.VIA_NET:
				waiting += 1
		most[0] = maxi(int(most[0]), waiting)
	for i in 15:
		var rogue := Rogue.new()
		rogue.name = "InvStorm%d" % i
		add_child(rogue)
		rogue.call_internet(_inv_cert, "127.0.0.%d" % (1 + i % 3), 47300 + i)
		storm.append(rogue)
	# A LAN guest in the middle of it.
	await _limits_until(func() -> bool:
		watch.call()
		return int(host.gate_counts["net_refused"]) >= 3, 6.0)
	var lan_guest: Node = await _session("InvStormLan")
	lan_guest.join("127.0.0.1")
	await _limits_until(func() -> bool:
		watch.call()
		return int(lan_guest.link) != NetSession.Link.REACHING)
	await _limits_until(func() -> bool:
		watch.call()
		for rogue: Rogue in storm:
			if not rogue.down() and not (host.get("_peers") as Dictionary).has(rogue.id):
				return false
		return true, 12.0)
	var counts: Dictionary = host.gate_counts
	_says(int(most[0]) <= NetSession.PENDING_MAX and int(counts["net_refused_pending"]) >= 1
			and int(counts["refused"]) == int(counts["net_refused"])
			and int(lan_guest.link) == NetSession.Link.TOGETHER,
		"invites D2: fifteen silent internet callers from three addresses -- at most %d"
		% int(most[0]) + " waiting at once, %d turned away at the internet door (%d for"
		% [int(counts["net_refused"]), int(counts["net_refused_pending"])] + " its waiting"
		+ " room, %d barred for their silence, %d for calling too often, %d as busy) --"
		% [int(counts["net_refused_barred"]), int(counts["net_refused_calls"]),
			int(counts["net_refused_busy"])]
		+ " and a LAN caller in the middle of it is answered: the LAN door refused nobody")
	await _limits_close([host, lan_guest] + storm)
	# The same, at the doors themselves: the internet's bucket for everybody
	# emptied by twelve first calls, and the LAN's untouched.
	host = await _invites_host("InvStormDoor")
	var net_said: Array = []
	for i in 12:
		var no: Array = host._admit("203.0.113.%d" % (10 + i), NetSession.VIA_NET)
		net_said.append("ok" if no.is_empty() else str(no[0]))
	var lan_said: Array = []
	for i in 10:
		var no: Array = host._admit("192.168.1.%d" % (10 + i), NetSession.VIA_LAN)
		lan_said.append("ok" if no.is_empty() else str(no[0]))
	_says(net_said.count("busy") >= 1
			and net_said.count("ok") <= int(NetSession.CALLS_ALL_BURST) + 1
			and lan_said.count("ok") == 10,
		"invites D2: and at the doors themselves, twelve first calls from twelve addresses"
		+ " on the internet are %d answered and %d busy, and ten LAN callers after them are"
		% [net_said.count("ok"), net_said.count("busy")] + " all answered")
	await _limits_close([host])
	# D3: one id, both listeners -- the newcomer refused, the first untouched.
	host = await _invites_host("InvTwinHost")
	var lan: Node = await _limits_guest("InvTwinLan")
	var lan_id: int = lan.my_id()
	var over_net := await _invites_raw_call(true, lan_id)
	var net_guest: Node = await _session("InvTwinFar")
	await _invites_call(net_guest, bob)
	var net_id: int = net_guest.my_id()
	var over_lan := await _invites_raw_call(false, net_id)
	await _wait(0.3)
	_says(bool(over_net[0]) and bool(over_net[1]) and bool(over_lan[0]) and bool(over_lan[1])
			and int(host.gate_counts["refused_twin"]) == 2
			and int(host.via_of(lan_id)) == NetSession.VIA_LAN
			and int(host.via_of(net_id)) == NetSession.VIA_NET
			and int(lan.link) == NetSession.Link.TOGETHER
			and int(net_guest.link) == NetSession.Link.TOGETHER
			and (host.guests() as Array).size() == 2,
		"invites D3: a caller on the internet listener with a LAN guest's id, and one on"
		+ " the LAN with an internet guest's, are each refused on their own listener, and"
		+ " both guests play on, each on the listener it came in by")
	# D4: an id below 2 -- which no Godot build picks, and which a host's
	# `set_target_peer` would read as more than one peer -- refused at the door
	# of either listener before anything is kept for it (issue #75).
	var low_lan := await _invites_raw_call(false, -5)
	var low_net := await _invites_raw_call(true, -6)
	await _wait(0.3)
	_says(bool(low_lan[1]) and bool(low_net[1])
			and int(host.gate_counts["refused_id"]) == 2
			and int(host.gate_counts["net_refused_id"]) == 1
			and not (host.peer_ids() as Array).has(-5) and not (host.peer_ids() as Array).has(-6)
			and int(lan.link) == NetSession.Link.TOGETHER
			and int(net_guest.link) == NetSession.Link.TOGETHER
			and (host.guests() as Array).size() == 2,
		"invites D4: a caller offering an id below 2 -- one a host would address as more"
		+ " than one peer -- is refused at the door of either listener, and both guests"
		+ " play on")
	await _limits_close([host, lan, net_guest])


## **R1-R4: the internet door's waiting room makes room** (issue #103). Two
## strangers that prove nothing fill it, and first calls from twenty addresses
## meanwhile are turned away for want of room without spending the bucket for
## everybody; a friend calling by invite once the elder has waited takes its
## place -- the elder's alone -- and that one is told why and barred; a third
## stranger that hangs up before it can be hung up on is barred all the same;
## and at the door itself the third barred /64 of a /56 bars the /56, where
## two do not, IPv4 never widens and the LAN door never does.
func _invites_room() -> void:
	var bob := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("bob", INVITES_ROOT)))
	var host: Node = await _invites_host("InvRoomHost")
	var peers: Dictionary = host.get("_peers")
	# R1: two strangers from 127.0.0.2 and .3, so the friend of R2 can call
	# from .1 -- one challenged and silent after it, one silent throughout, and
	# the second a good while after the first, so which is the elder is plain.
	var talker := _invites_stranger("InvRoomTalker", "127.0.0.2", 47310)
	await _limits_until(func() -> bool: return talker.connected() and peers.has(talker.id))
	talker.send(_hello())
	await _wait(0.3)
	var mute := _invites_stranger("InvRoomMute", "127.0.0.3", 47311)
	await _limits_until(func() -> bool: return mute.connected() and peers.has(mute.id))
	var from := {talker: "127.0.0.2", mute: "127.0.0.3"}
	var everybody: Variant = host.get("_net_calls_all")
	var level_before: float = everybody.level(host._now())
	var said: Array = []
	for i in 20:
		var no: Array = host._admit("203.0.113.%d" % (100 + i), NetSession.VIA_NET)
		said.append("ok" if no.is_empty() else str(no[0]))
	var level_after: float = everybody.level(host._now())
	_says(said.count("pending") == 20 and level_after > level_before - 0.5
			and peers.has(talker.id) and peers.has(mute.id),
		"invites R1: with two strangers waiting on the internet listener, first calls from"
		+ " twenty addresses are turned away for want of room, %d of 20, and the bucket"
		% said.count("pending") + " for everybody is as it was, %.1f then %.1f: a call the"
		% [level_before, level_after] + " door cannot take costs no friend a place")
	# R2: the friend calls once the elder has waited 1.2 s here. Its call comes
	# up at ENet's first resend, some 0.55 s on, or at the next if its DTLS
	# handshake misses that, a second later -- either way past the 1.5 s a
	# newcomer waits for, and inside the 3 s the elder has before it would be
	# cut for its silence.
	var since := {talker: float(peers[talker.id]["since"]), mute: float(peers[mute.id]["since"])}
	var eldest := minf(float(since[talker]), float(since[mute]))
	await _limits_until(func() -> bool: return host._now() - eldest >= 1.2, 3.0)
	var friend: Node = await _session("InvRoomFriend")
	await _invites_call(friend, bob)
	var arrived := -1.0
	if peers.has(friend.my_id()):
		arrived = float(peers[friend.my_id()]["since"]) - eldest
	var net_book: Dictionary = host.get("_net_book")
	var gone: Array = []
	for rogue: Rogue in [talker, mute]:
		if rogue.refused_for() >= 0:
			gone.append(rogue)
	var left: Rogue = null
	var held := 0.0
	var line := ""
	if gone.size() == 1:
		left = mute if gone[0] == talker else talker
		held = float(net_book.get(from[gone[0]], {}).get("barred_until", 0.0)) - _now()
		for each: String in _inv_catcher.lines:
			if each.contains("(%s)" % from[gone[0]]) and each.contains("a caller waiting"):
				line = each.strip_edges()
	_says(int(friend.link) == NetSession.Link.TOGETHER and gone.size() == 1
			and int(host.gate_counts["net_evicted"]) == 1
			and (gone[0] as Rogue).refused_for() == Wire.REFUSE_SILENT
			and float(since[gone[0]]) < float(since[left]) and peers.has(left.id)
			and held > NetSession.BAR_FIRST - 10.0 and not line.is_empty(),
		"invites R2: a friend calling by invite %.2f s after the elder came is in, in the"
		% arrived + " place of the elder alone, which is told REFUSE_SILENT and barred for"
		+ " %.0f s, the younger waiting on: '%s'" % [held, line])
	# R3: a fresh stranger from 127.0.0.4, which says HELLO and hangs up before
	# it can be hung up on -- barred all the same, so a call straight back from
	# there is refused at the door.
	var quitter := _invites_stranger("InvRoomQuitter", "127.0.0.4", 47312)
	await _limits_until(func() -> bool:
		return quitter.connected() and peers.has(quitter.id))
	quitter.send(_hello())
	await _limits_until(func() -> bool: return not quitter.challenge().is_empty())
	var refused_barred := int(host.gate_counts["net_refused_barred"])
	quitter.hang_up()
	await _limits_until(func() -> bool: return int(host.gate_counts["net_left"]) >= 1, 2.0)
	var quit_held := float(net_book.get("127.0.0.4", {}).get("barred_until", 0.0)) - _now()
	var quit_line := ""
	for each: String in _inv_catcher.lines:
		if each.contains("(127.0.0.4) hung up"):
			quit_line = each.strip_edges()
	var back := _invites_stranger("InvRoomBack", "127.0.0.4", 47313)
	await _limits_until(func() -> bool: return back.down(), 4.0)
	_says(back.down() and int(host.gate_counts["net_left"]) == 1
			and int(host.gate_counts["net_refused_barred"]) == refused_barred + 1
			and quit_held > NetSession.BAR_FIRST - 10.0 and not quit_line.is_empty(),
		"invites R3: a stranger that hangs up before its grace is out is barred all the"
		+ " same, for %.0f s -- '%s' -- and its call straight back is refused at the door"
		% [quit_held, quit_line] + " as barred")
	await _limits_close([host, talker, mute, friend, back])
	# R4: at the door itself -- two /64s of 2001:db8:0:100::/56 barred, and one
	# of the next /56, bar nothing more; a third bars the /56.
	host = await _invites_host("InvRoomDoor")
	for net: String in ["2001:db8:0:100::1", "2001:db8:0:101::1", "2001:db8:0:200::1"]:
		host._bar(net, NetSession.VIA_NET)
	var two: Array = host._admit("2001:db8:0:1ff::5", NetSession.VIA_NET)
	for net: String in ["2001:db8:0:102::1", "203.0.113.1", "203.0.113.2", "203.0.113.3"]:
		host._bar(net, NetSession.VIA_NET)
	for lan: String in ["fd00:0:0:100::1", "fd00:0:0:101::1", "fd00:0:0:102::1"]:
		host._bar(lan, NetSession.VIA_LAN)
	var wide: Array = host._admit("2001:db8:0:1ff::5", NetSession.VIA_NET)
	var beside: Array = host._admit("2001:db8:0:201::5", NetSession.VIA_NET)
	var fourth: Array = host._admit("203.0.113.4", NetSession.VIA_NET)
	var lan_wide: Array = host._admit("fd00:0:0:1ff::5", NetSession.VIA_LAN)
	# What is left of the /56's bar: a hair over a minute when no millisecond
	# has passed since it was made, as float arithmetic goes.
	var book: Dictionary = host.get("_net_book")
	var whole: float = float(book.get("2001:db8:0:100::/56", {}).get("barred_until", 0.0)) \
		- host._now()
	_says(two.is_empty() and wide.size() == 2 and str(wide[0]) == "barred"
			and str(wide[1]).contains("/56") and beside.is_empty() and fourth.is_empty()
			and lan_wide.is_empty() and int(host.gate_counts["net_barred_wide"]) == 1
			and whole > NetSession.BAR_FIRST - 1.0 and whole < NetSession.BAR_FIRST + 0.5,
		"invites R4: two /64s of a /56 barred at the internet door, and one of the next /56,"
		+ " bar nothing more (%s); the third bars the /56 for %.0f s -- a fourth /64 in it"
		% ["answered" if two.is_empty() else str(two[0]), whole] + " is told '%s', and"
		% (str(wide[1]) if wide.size() == 2 else "nothing") + " one in the next /56 is"
		+ " answered -- while three barred IPv4 addresses bar no neighbour, and three /64s"
		+ " barred at the LAN door none either")
	await _limits_close([host])


## **H1-H4: the house's listener closing by itself** (issue #105), as 4.7's
## `ENetMultiplayerPeer.poll()` closes one whose service failed -- a send the
## network refused, as when an interface goes down under it: `close()`, which
## takes every transport on it and tells the host nothing. Closed here by hand:
## between two frames, and once during `poll()` itself -- where 4.7 closes one,
## in the service call a poll begins with -- from inside the very signal that
## brings a caller in. `tools/net_drop.gd` is the real failure. The server lets
## its LAN guest go, keeps its internet guest, and answers the house again at
## once; a phone goes back to showing its code; and with the port taken
## meanwhile, the listener is tried again after one second, two, four, and
## opens again once it is free.
func _invites_house_closed() -> void:
	var bob := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("bob", INVITES_ROOT)))
	# H1: the server, with a guest from the house and one by invite.
	var host: Node = await _invites_host("InvHouseHost")
	var lan: Node = await _limits_guest("InvHouseLan")
	var lan_id: int = lan.my_id()
	var far: Node = await _session("InvHouseFar")
	await _invites_call(far, bob)
	var far_id: int = far.my_id()
	var from := _inv_catcher.lines.size()
	(host.get("_peer") as ENetMultiplayerPeer).close()
	await _limits_until(func() -> bool:
		return int(host.gate_counts["lan_closed"]) >= 1 \
			and int(lan.link) != NetSession.Link.TOGETHER)
	var let_go: bool = host.via_of(lan_id) == -1 \
		and not (host.get("_addresses") as Dictionary).has(lan_id) \
		and host.guests() == [far_id] and int(host.link) == NetSession.Link.TOGETHER
	lan.join("127.0.0.1")
	await _until_link(lan, NetSession.Link.TOGETHER)
	await _wait(0.3)
	var lines := _inv_catcher.lines.slice(from)
	_says(let_go and int(host.gate_counts["lan_closed"]) == 1
			and _count(lines, "[net] the LAN listener closed by itself") == 1
			and _count(lines, "[net] the LAN listener is open again, 0.0 s on") == 1
			and _said(lines, "[net] %d (127.0.0.1) done after" % lan_id)
			and int(lan.link) == NetSession.Link.TOGETHER
			and int(host.via_of(lan.my_id())) == NetSession.VIA_LAN
			and int(far.link) == NetSession.Link.TOGETHER
			and int(host.via_of(far_id)) == NetSession.VIA_NET
			and str(host.label_of(far_id)) == "bob" and (host.guests() as Array).size() == 2,
		"invites H1: the server's LAN listener closing under a LAN guest lets that guest go"
		+ " -- its line in the log, nothing of it kept -- and opens again the same frame,"
		+ " where it calls back and is in; bob's guest by invite plays on throughout, and"
		+ " the log says it once: 'the LAN listener closed by itself', 'open again, 0.0 s on'")
	await _limits_close([host, lan, far])
	# H2: a phone, with its friend in.
	var phone: Node = await _limits_host("InvHousePhone")
	var friend: Node = await _limits_guest("InvHouseFriend")
	(phone.get("_peer") as ENetMultiplayerPeer).close()
	await _limits_until(func() -> bool:
		return int(phone.gate_counts["lan_closed"]) >= 1 \
			and int(friend.link) != NetSession.Link.TOGETHER)
	var showing: bool = int(phone.link) == NetSession.Link.LISTENING \
		and str(phone.trouble) == "they left" and (phone.guests() as Array).is_empty()
	friend.join("127.0.0.1")
	await _until_link(friend, NetSession.Link.TOGETHER)
	_says(showing and int(friend.link) == NetSession.Link.TOGETHER
			and (phone.guests() as Array).size() == 1,
		"invites H2: a phone host's listener closing under its friend shows its code again"
		+ " -- 'they left' -- and the friend calling back is in")
	await _limits_close([phone, friend])
	# H3: inside the call that brings a caller in, the session's record of it
	# made first.
	var lone: Node = await _limits_host("InvHouseLone")
	var enet: ENetMultiplayerPeer = lone.get("_peer")
	# The records the session had made, and the frame it closed in.
	var held := [-1, -1]
	enet.peer_connected.connect(func(_id: int) -> void:
		held[0] = (lone.get("_via") as Dictionary).size()
		held[1] = Engine.get_process_frames()
		enet.close(), CONNECT_ONE_SHOT)
	var caller: Node = await _session("InvHouseCaller")
	caller.join("127.0.0.1")
	var seen := [-1]
	await _limits_until(func() -> bool:
		if int(lone.gate_counts["lan_closed"]) >= 1:
			seen[0] = Engine.get_process_frames()
		return int(seen[0]) >= 0)
	var none_kept: bool = (lone.peer_ids() as Array).is_empty() \
		and (lone.get("_via") as Dictionary).is_empty() \
		and (lone.get("_addresses") as Dictionary).is_empty() \
		and lone.get("_peer") != enet
	await _limits_until(func() -> bool: return int(caller.link) != NetSession.Link.REACHING)
	caller.join("127.0.0.1")
	await _until_link(caller, NetSession.Link.TOGETHER)
	_says(int(held[0]) == 1 and int(seen[0]) == int(held[1]) and none_kept
			and int(caller.link) == NetSession.Link.TOGETHER,
		"invites H3: a listener closing in the very service call a caller came in by is"
		+ " found straight after it, in that frame, the record just made for that caller"
		+ " let go with it, and the caller calling again is answered on the listener"
		+ " opened anew")
	await _limits_close([lone, caller])
	# H4: the port taken the moment it closed, for five seconds.
	host = await _invites_host("InvHouseTaken")
	far = await _session("InvHouseTakenFar")
	await _invites_call(far, bob)
	from = _inv_catcher.lines.size()
	(host.get("_peer") as ENetMultiplayerPeer).close()
	var squatter := PacketPeerUDP.new()
	var squatted := squatter.bind(Lan.channel_port()) == OK
	await _wait(5.0)
	var down: bool = float(host.get("_lan_down_since")) >= 0.0
	var counting: float = host._now() - float(host.get("_saturation_from"))
	var far_on := int(far.link) == NetSession.Link.TOGETHER
	squatter.close()
	var took := await _limits_until(func() -> bool:
		return float(host.get("_lan_down_since")) < 0.0, 4.0)
	lan = await _limits_guest("InvHouseTakenLan")
	lines = _inv_catcher.lines.slice(from)
	var on := -1.0
	for line: String in lines:
		if line.begins_with("[net] the LAN listener is open again, "):
			on = float(line.get_slice(", ", 1).get_slice(" ", 0))
	# Tries at once, one second on and three -- each an engine line -- and
	# the next, seven on, finds the port free. Trying every second makes six:
	# the one due as the port is let go comes first in that frame.
	var tries := _count(lines, "Couldn't create an ENet host")
	_says(squatted and down and counting < 2.0 and far_on and took >= 0.0
			and on >= 6.5 and on < 8.5 and tries == 3
			and _count(lines, "[net] the LAN listener could not open again: port %d is taken"
				% Lan.channel_port()) == 1
			and int(lan.link) == NetSession.Link.TOGETHER
			and int(far.link) == NetSession.Link.TOGETHER,
		"invites H4: with the port taken for 5 s the moment the listener closed, it is"
		+ " tried again after one second, two and four -- %d tries -- and said once," % tries
		+ " arrivals at the internet listener still counted (%.1f s since the last" % counting
		+ " count) and its guest playing on; free again, it opens at the next try, %.1f s"
		% on + " on, and a LAN guest is in")
	await _limits_close([host, far, lan])


## **L1-L12: the real server scene** (`game/server/`), with a book of its own
## looked at every [constant INVITES_POLL]: no invites and no listener at the
## start; a mint opens it without a restart, with every file rw-------; a LAN
## guest and an internet guest share its pond and see each other, and a
## stranger beside them is not what the updater waits for; another invite
## coming and going leaves a guest be, and revoking its own cuts it within a
## look and leaves the LAN guest swimming; with none left, the listener closes;
## a book it cannot read fails closed; a new key that cannot be written
## changes nothing, and one that can tells its guest and comes back with the
## new certificate, the LAN guest swimming on; and a job run through the scene
## prints as the command line's does.
func _invites_server() -> void:
	var root := INVITES_SERVER_ROOT
	var server: Node = load(SERVER_SCENE).instantiate()
	server.set("check_updates", false)
	server.set("own_frame_rate", false)
	server.set("quits", false)
	server.set("pond_root", root)
	server.set("invites_poll", INVITES_POLL)
	server.set("upnp_router", UpnpRouter.new(&"none"))
	# No room kept: this user dir's `rooms/1.save` is not the probe's to write.
	server.set("room_path", "")
	get_tree().root.add_child.call_deferred(server)
	await server.ready
	var net: Node = server.session()
	_says(int(net.link) == NetSession.Link.LISTENING and not bool(net.internet_listening())
			and str(server.get("_internet_said")).begins_with("nothing listens"),
		"invites L1: the server boots with no invites and nothing listening for the internet,"
		+ " and its READY says so")
	# L2: the address alone first -- `pond/` is made private by it, not left
	# for the first mint -- then a mint, from the command line's own code, and
	# no restart.
	var reached: Array = _invites_job(["--reach=127.0.0.1"], root)
	var pond_mode := FileAccess.get_unix_permissions(str(InviteBook.paths(root)["pond"]))
	var minted: Array = _invites_job(["--invite=carol"], root)
	_invites_hide_book(root)
	var opened := await _limits_until(func() -> bool: return bool(net.internet_listening()),
		INVITES_POLL * 4.0 + 1.0)
	_says(int(reached[0]) == 0 and pond_mode == Invite.PRIVATE_DIR and int(minted[0]) == 0
			and opened >= 0.0 and opened <= INVITES_POLL + 0.5,
		"invites L2: --reach alone makes pond/ rwx------ (%o), and a mint then opens the"
		% pond_mode + " internet listener %.2f s later, with no restart" % opened)
	# L3: rw------- for everything a secret is in.
	var where := InviteBook.paths(root)
	var modes := {}
	for what: String in ["key", "book", "reach"]:
		modes[what] = FileAccess.get_unix_permissions(str(where[what]))
	modes["invite line"] = FileAccess.get_unix_permissions(InviteBook.line_path("carol", root))
	modes["pond/"] = FileAccess.get_unix_permissions(str(where["pond"]))
	modes["invites/"] = FileAccess.get_unix_permissions(str(where["lines"]))
	var private := true
	for what: String in modes:
		private = private and int(modes[what]) == (Invite.PRIVATE_DIR if what.ends_with("/")
			else Invite.PRIVATE)
	var shown: Array[String] = []
	for what: String in modes:
		shown.append("%s %o" % [what, int(modes[what])])
	_says(private,
		"invites L3: the key, the book, the address and the invite line are rw-------, in"
		+ " directories that are rwx------: %s" % ", ".join(shown))
	# L4: a LAN guest and an internet guest, one pond.
	var carol := Invite.parse(FileAccess.get_file_as_string(InviteBook.line_path("carol", root)))
	var lan: Node = await _session("InvPondLan")
	lan.join("127.0.0.1")
	await _until_link(lan, NetSession.Link.TOGETHER)
	var far: Node = await _session("InvPondFar")
	await _invites_call(far, carol)
	var both := int(lan.link) == NetSession.Link.TOGETHER \
		and int(far.link) == NetSession.Link.TOGETHER \
		and (net.guests() as Array).size() == 2 and int(net.peer_count()) == 2 \
		and int(net.via_of(lan.my_id())) == NetSession.VIA_LAN \
		and int(net.via_of(far.my_id())) == NetSession.VIA_NET \
		and str(net.label_of(far.my_id())) == "carol"
	var lan_run := _pond_run_scene(lan, false)
	get_tree().root.add_child.call_deferred(lan_run)
	await lan_run.ready
	await _pond_until(func() -> bool:
		return bool((lan_run.get("_pond") as Object).in_pond), 3.0, [])
	var far_run := _pond_run_scene(far, false)
	get_tree().root.add_child.call_deferred(far_run)
	await far_run.ready
	var lan_food: Node = lan_run.get_node(^"Food")
	var far_food: Node = far_run.get_node(^"Food")
	var met := await _server_until(func() -> bool:
		return bool((far_run.get("_pond") as Object).in_pond) and lan_food.person() != null \
			and far_food.person() != null, [])
	_says(both and met >= 0.0,
		"invites L4: a LAN guest and an internet guest are the server's two -- one on each"
		+ " listener, the internet one carol's -- and each sees the other in the water,"
		+ " %.2f s after both were in; its updater would wait for %d" % [met,
			int(net.company())])
	# L5: what the server tells its updater, with a stranger on the internet
	# listener beside the two guests: the guests, and not the stranger.
	var ticks := TickTaker.new()
	server.set("_updater", ticks)
	var stranger := Rogue.new()
	stranger.name = "InvPondStranger"
	add_child(stranger)
	stranger.call_internet(InviteBook.load_identity(root)[1], "127.0.0.2", 47295)
	await _limits_until(func() -> bool: return int(net.peer_count()) == 3, 3.0)
	await _wait(0.1)
	var peers_then := int(net.peer_count())
	var told: int = ticks.told.back() if not ticks.told.is_empty() else -1
	server.set("_updater", null)
	ticks.free()
	stranger.hang_up()
	await _limits_until(func() -> bool: return int(net.peer_count()) == 2, 3.0)
	_says(peers_then == 3 and told == 2,
		"invites L5: with a stranger on the internet listener that has proved nothing beside"
		+ " the two guests, the server tells its updater %d are here -- not the %d that" % [told,
			peers_then] + " peer_count() counts -- so no stranger holds an update off")
	# L6: the book changing under a guest whose invite stays in it -- a friend
	# minted, then revoked -- leaves her be. Only her own invite going cuts.
	_invites_job(["--invite=dave"], root)
	_invites_hide_book(root)
	var labels_of := func() -> Dictionary: return server.get("_labels")
	var added := await _limits_until(func() -> bool: return labels_of.call().has("dave"),
		INVITES_POLL * 4.0 + 1.0)
	var stayed := added >= 0.0 and int(far.link) == NetSession.Link.TOGETHER
	_invites_job(["--revoke=dave"], root)
	var gone := await _limits_until(func() -> bool: return not labels_of.call().has("dave"),
		INVITES_POLL * 4.0 + 1.0)
	_says(stayed and gone >= 0.0 and int(far.link) == NetSession.Link.TOGETHER
			and str(net.label_of(far.my_id())) == "carol" and bool(net.internet_listening())
			and int(net.gate_counts["invite_cuts"]) == 0 and (net.guests() as Array).size() == 2,
		"invites L6: an invite minted for dave, then revoked, while carol swims -- each taken"
		+ " within a look (%.2f s, %.2f s) -- leaves her in the water and the listener open"
		% [added, gone])
	# L7: carol's invite revoked while she swims.
	var listing: Array = _invites_job(["--invites"], root)
	var joined := false
	for said: String in listing[1]:
		joined = joined or (said.contains("carol") and not said.contains("never"))
	_invites_job(["--revoke=carol"], root)
	var cut := await _limits_until(func() -> bool:
		return int(far.link) == NetSession.Link.REFUSED, INVITES_POLL * 4.0 + 1.0)
	await _pond_until(func() -> bool: return bool((far_run.get("_pond") as Object).cut_off()),
		1.0, [])
	_says(joined and cut >= 0.0 and cut <= INVITES_POLL + 0.5
			and str(far.trouble_key) == "invite_refused"
			and bool((far_run.get("_pond") as Object).cut_off())
			and int(lan.link) == NetSession.Link.TOGETHER and (net.guests() as Array).size() == 1,
		"invites L7: --invites shows when carol last came in; revoked while she swims, she"
		+ " is cut %.2f s later, within a look at the book, reading '%s', and her run" % [cut,
			far.trouble] + " says cut off -- the LAN guest swims on")
	# L8: none left, so nothing listens for the internet -- at once for new
	# calls, and the socket itself once the refusal has had its linger.
	var refusing := not bool(net.internet_listening())
	var closed := await _limits_until(func() -> bool: return net.get("_net_peer") == null,
		NetSession.REFUSE_LINGER + 1.0)
	_says(refusing and closed >= 0.0 and int(net.link) == NetSession.Link.TOGETHER
			and str(server.get("_internet_said")).begins_with("nothing listens"),
		"invites L8: with no invite left the internet listener takes no call from the cut"
		+ " on, and its socket is put down %.2f s later, when the refusal has had its" % closed
		+ " linger -- and the server says nothing listens for the internet")
	far_run.queue_free()
	far.close()
	# L9: a book the server cannot read fails closed. Root, which this probe
	# may run as, reads a file whatever its mode, so the book is put out of
	# reach as a directory where it was: `_bytes_of` finds the same thing
	# either way -- something there that will not read -- and it is the same
	# branch a book another user wrote goes down.
	_invites_job(["--invite=erin"], root)
	_invites_hide_book(root)
	var erin := Invite.parse(FileAccess.get_file_as_string(InviteBook.line_path("erin", root)))
	await _limits_until(func() -> bool: return bool(net.internet_listening()),
		INVITES_POLL * 4.0 + 1.0)
	var erin_at: Node = await _session("InvPondErin")
	await _invites_call(erin_at, erin)
	var erin_in := int(erin_at.link) == NetSession.Link.TOGETHER
	var book_path := str(InviteBook.paths(root)["book"])
	var book_kept := FileAccess.get_file_as_bytes(book_path)
	DirAccess.remove_absolute(book_path)
	DirAccess.make_dir_absolute(book_path)
	var shut := await _limits_until(func() -> bool:
		return int(erin_at.link) == NetSession.Link.REFUSED \
			and not bool(net.internet_listening()), INVITES_POLL * 4.0 + 1.0)
	var said_why := str(server.get("_internet_said"))
	var still_shut := not bool(net.internet_listening())
	await _wait(INVITES_POLL * 2.0 + 0.2)
	still_shut = still_shut and not bool(net.internet_listening())
	DirAccess.remove_absolute(book_path)
	Invite.write_private(book_path, book_kept)
	var reopened := await _limits_until(func() -> bool: return bool(net.internet_listening()),
		INVITES_POLL * 4.0 + 2.0)
	_says(erin_in and shut >= 0.0 and str(erin_at.trouble_key) == "invite_refused"
			and still_shut and said_why.contains("cannot be read")
			and reopened >= 0.0 and int(lan.link) == NetSession.Link.TOGETHER
			and str(server.get("_internet_said")).begins_with("listening"),
		"invites L9: a book the server cannot read fails closed -- erin, swimming on an"
		+ " invite in it, is cut %.2f s later reading '%s', nothing listens while it" % [shut,
			erin_at.trouble] + " stays unread and the log says why -- and %.2f s after it"
		% reopened + " reads again, the listener is back")
	# L10: a new key that cannot be written -- its certificate's way blocked
	# once the key is down, as a disk that fills there would leave it --
	# changes nothing: the old key, certificate and book as they were, nothing
	# half-made left beside them, and erin swims on (issue #89).
	NetSession.forget_refusals()
	await _invites_call(erin_at, erin)
	var back_in := int(erin_at.link) == NetSession.Link.TOGETHER
	var files := InviteBook.paths(root)
	var pair_of := func() -> Array:
		return [FileAccess.get_file_as_bytes(str(files["key"])),
			FileAccess.get_file_as_bytes(str(files["cert"])),
			FileAccess.get_file_as_bytes(str(files["book"]))]
	var pair_before: Array = pair_of.call()
	# Every name a certificate is written through, blocked by a directory that
	# is not empty: root, which this probe may run as, writes past any mode.
	var in_the_way := [str(files["cert"]) + ".next", str(files["cert"]) + ".new"]
	for dir: String in in_the_way:
		DirAccess.make_dir_recursive_absolute(dir.path_join("in-the-way"))
	var stuck: Array = _invites_job(["--new-key"], root)
	await _wait(INVITES_POLL * 2.0 + 0.2)
	var pair_after: Array = pair_of.call()
	for dir: String in in_the_way:
		DirAccess.remove_absolute(dir.path_join("in-the-way"))
		DirAccess.remove_absolute(dir)
	var litter: Array[String] = []
	for left: String in DirAccess.get_files_at(str(files["pond"])):
		if left.contains(".next"):
			litter.append(left)
	var stuck_said := "\n".join(PackedStringArray(stuck[1]))
	_says(back_in and int(stuck[0]) == 1 and stuck_said.contains("nothing was changed")
			and pair_after == pair_before and litter.is_empty()
			and int(erin_at.link) == NetSession.Link.TOGETHER
			and bool(net.internet_listening()),
		"invites L10: a --new-key whose certificate cannot be written after its key exits 1"
		+ " and changes nothing -- the key, certificate and book as they were, nothing"
		+ " half-made left beside them%s -- and erin swims on"
		% ("" if litter.is_empty() else " (NOT: %s)" % ", ".join(litter)))
	# L11: a new key while a friend swims, and an invite minted with it in the
	# same look: she is told, not hung up on, and the listener comes back with
	# the new certificate -- the one the job printed, which its listening line
	# names -- while the LAN guest swims on: that listener has no key.
	var answering_before := str(server.get("_answering_with"))
	var rekeyed: Array = _invites_job(["--new-key", "--invite=erin"], root)
	_invites_hide_book(root)
	var fresh := Invite.parse(FileAccess.get_file_as_string(InviteBook.line_path("erin", root)))
	var told_at := await _limits_until(func() -> bool:
		return int(erin_at.link) != NetSession.Link.TOGETHER, INVITES_POLL * 4.0 + 2.0)
	var back_up := await _limits_until(func() -> bool: return bool(net.internet_listening()),
		INVITES_POLL * 4.0 + 3.0)
	var made_print := InviteBook.fingerprint(Invite.der_of_pem(
		FileAccess.get_file_as_string(str(files["cert"]))))
	var job_named := "\n".join(PackedStringArray(rekeyed[1])).contains("certificate " + made_print)
	var line_named := str(server.get("_internet_said")).contains("certificate " + made_print)
	NetSession.forget_refusals()
	var with_old: Node = await _session("InvPondErinOld")
	await _invites_call(with_old, erin)
	var with_new: Node = await _session("InvPondErinNew")
	await _invites_call(with_new, fresh)
	_says(int(rekeyed[0]) == 0 and told_at >= 0.0
			and int(erin_at.link) == NetSession.Link.REFUSED
			and str(erin_at.trouble_key) == "invite_refused" and back_up >= 0.0
			and str(with_old.trouble_key) == "not_this_pond"
			and int(with_new.link) == NetSession.Link.TOGETHER
			and made_print != answering_before and job_named and line_named
			and int(lan.link) == NetSession.Link.TOGETHER,
		"invites L11: --new-key and a new invite for erin in one look while she swims: she"
		+ " is told, %.2f s later, reading '%s' -- not hung up on -- and the" % [told_at,
			erin_at.trouble] + " listener is back %.2f s after that with the new key," % back_up
		+ " certificate %s where it was %s, as the job printed and the" % [made_print,
			answering_before] + " listening line says: her old line meets '%s', her new one"
		% with_old.trouble + " is in, and the LAN guest swims on")
	await _limits_close([erin_at, with_old, with_new])
	# L12: a job through the server scene itself, as the command line runs
	# one: its lines printed as `[server]` lines, its exit code kept, and no
	# session opened.
	var printed_from := _inv_catcher.lines.size()
	var job: Node = load(SERVER_SCENE).instantiate()
	job.set("check_updates", false)
	job.set("quits", false)
	job.set("pond_root", root)
	job.set("job_args", PackedStringArray(["--invite=frank", "--invites"]))
	get_tree().root.add_child.call_deferred(job)
	await job.ready
	var job_code := int(job.get("_job_code"))
	var refused_job: Node = load(SERVER_SCENE).instantiate()
	refused_job.set("check_updates", false)
	refused_job.set("quits", false)
	refused_job.set("pond_root", root)
	refused_job.set("job_args", PackedStringArray(["--revoke=nobody"]))
	get_tree().root.add_child.call_deferred(refused_job)
	await refused_job.ready
	_invites_hide_book(root)
	var printed := _inv_catcher.lines.slice(printed_from)
	var wrote_frank := false
	var listed_frank := false
	var said_nobody := false
	for line: String in printed:
		wrote_frank = wrote_frank or line.begins_with("[server] invite for frank written to")
		listed_frank = listed_frank or line.begins_with("[server]   frank -- made")
		said_nobody = said_nobody or line.begins_with("[server] --revoke: there is no invite")
	_says(job_code == 0 and wrote_frank and listed_frank and job.session() == null
			and int(refused_job.get("_job_code")) == 1 and said_nobody,
		"invites L12: jobs run through the server scene itself print their lines as the"
		+ " command line does -- --invite=frank --invites exits 0, --revoke=nobody 1 -- and"
		+ " open no session")
	job.queue_free()
	refused_job.queue_free()
	lan_run.queue_free()
	lan.close()
	server.shut_down()
	server.queue_free()
	await _wait(0.4)


## **The last check: nothing a secret is made of was printed** -- not by the
## probe, the sessions, the server, its command line, or the engine -- while
## the section ran, and nothing is in the lines any job gave back, which a job
## run from the command line prints. Every kind of job ran.
func _invites_no_secret() -> void:
	var lines := _inv_catcher.lines
	var hits: Array[String] = []
	for line: String in lines + _inv_job_lines:
		for needle: String in _inv_needles:
			if not needle.is_empty() and line.contains(needle):
				hits.append(line.substr(0, 60))
	var kinds: Array[String] = []
	for kind: String in ["--reach", "--invite", "--revoke", "--invites", "--new-key"]:
		if _inv_jobs_run.has(kind):
			kinds.append(kind)
	_says(hits.is_empty() and lines.size() > 100 and _inv_needles.size() >= 8
			and kinds.size() == 5 and _inv_job_lines.size() >= 10,
		"invites: %d lines were printed while this section ran, and %d came back from its"
		% [lines.size(), _inv_job_lines.size()] + " jobs (%s), and none holds any of the"
		% " ".join(kinds) + " %d secrets, invite lines or key texts it made%s"
		% [_inv_needles.size(), "" if hits.is_empty() else " -- NOT: " + ", ".join(hits)])


## **An invite job, as the command line runs it**, its lines kept for the
## check that none of them holds a secret ([method _invites_no_secret]).
func _invites_job(args: Array, root: String) -> Array:
	var done: Array = InviteBook.run(PackedStringArray(args), root)
	for arg: String in args:
		_inv_jobs_run[arg.get_slice("=", 0)] = true
	_inv_job_lines.append_array(PackedStringArray(done[1]))
	return done


## A host of its own, with both listeners open and the probe's invites.
func _invites_host(named: String) -> Node:
	var host: Node = await _session(named)
	host.host(NetSession.GUESTS_MAX)
	host.listen_internet(_inv_key, _inv_cert)
	host.set_invites(InviteBook.table(INVITES_ROOT))
	return host


## [param guest] calls by [param invite] and it is waited out: the seconds it
## took to be anything but REACHING.
func _invites_call(guest: Node, invite: Dictionary) -> float:
	var from := _now()
	guest.call_invite(invite)
	await _limits_until(func() -> bool: return int(guest.link) != NetSession.Link.REACHING,
		NetSession.INVITE_REACH_TIMEOUT + NetSession.RESOLVE_TIMEOUT + 2.0)
	return _now() - from


## A DTLS [Rogue] at the internet listener from [param source], another
## loopback address, bound on [param port] -- so its bar is its own.
func _invites_stranger(named: String, source: String, port: int) -> Rogue:
	var rogue := Rogue.new()
	rogue.name = named
	add_child(rogue)
	rogue.call_internet(_inv_cert, source, port)
	return rogue


## A DTLS [Rogue] at the internet listener, pinned to the probe's server.
func _invites_rogue(named: String) -> Rogue:
	var rogue := Rogue.new()
	rogue.name = named
	add_child(rogue)
	rogue.call_internet(_inv_cert)
	return rogue


## `join()`, to a port that is not the LAN's: what a build with no DTLS would
## do if it were ever pointed at the internet listener.
func _invites_join_port(session: Node, port: int) -> void:
	session._reset_socket()
	session.hosting = false
	session.address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", port)
	session._peer = peer
	(session.get("_api") as SceneMultiplayer).multiplayer_peer = peer
	session.set_process(true)
	session._reach_at = session._now()
	session._set_link(NetSession.Link.REACHING)


## **A bare ENet connection that offers [param id]**: over DTLS to the internet
## listener, or plain to the LAN's. `[it connected, it was cut]`.
func _invites_raw_call(internet: bool, id: int) -> Array:
	var raw := ENetConnection.new()
	var peer: ENetPacketPeer = null
	if raw.create_host(1) == OK:
		if internet:
			raw.dtls_client_setup(Invite.NAME, TLSOptions.client(_inv_cert, Invite.NAME))
		peer = raw.connect_to_host("127.0.0.1", Invite.channel_port() if internet
			else Lan.channel_port(), 0, id)
	var seen := [false, false]
	await _limits_until(func() -> bool:
		if peer == null:
			return true
		var event: Array = raw.service()
		while int(event[0]) > ENetConnection.EVENT_NONE:
			if int(event[0]) == ENetConnection.EVENT_CONNECT:
				seen[0] = true
			elif int(event[0]) == ENetConnection.EVENT_DISCONNECT:
				seen[1] = true
			event = raw.service()
		return bool(seen[1]), 4.0)
	raw.destroy()
	return seen


## What the log must never hold, from one secret: its base64 and its hex.
func _invites_hide(secret: PackedByteArray) -> void:
	_invites_needle(Marshalls.raw_to_base64(secret))
	_invites_needle(secret.hex_encode())


## Every secret in [param root]'s book, every invite line written from it, and
## the key's own text.
func _invites_hide_book(root: String) -> void:
	var book := InviteBook.entries(root)
	for name: String in book:
		_invites_hide((book[name] as Dictionary)["secret"])
		var line := FileAccess.get_file_as_string(InviteBook.line_path(name, root)).strip_edges()
		if line.length() > 90:
			_invites_needle(line.substr(Invite.PREFIX.length() + 30, 60))
	var key := FileAccess.get_file_as_string(str(InviteBook.paths(root)["key"]))
	var body := key.get_slice("\n", 2).strip_edges()
	if body.length() > 40:
		_invites_needle(body)


## One thing the log must never hold, counted once however often it is seen.
func _invites_needle(text: String) -> void:
	if not _inv_needles.has(text):
		_inv_needles.append(text)


## Everything a book under [param root] left, gone.
func _invites_wipe(root: String) -> void:
	for dir: String in [root.path_join("pond"), root.path_join("invites"), root]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)


# ---------------------------------------------------------------------------
# **UPnP** (docs/server.md §9.3): the server's internet port, forwarded on the
# home router for as long as the server runs -- `game/net/port_forward.gd`,
# the generic forward, and the server's use of it -- against a router of this
# probe's own, [UpnpRouter], so not a packet leaves the machine. The real
# `UPNP` is only asked which numbers it uses. What this cannot see is a real
# router: that was run by hand against miniupnpd in a network namespace, and
# the notes are in the report that shipped this section.
# ---------------------------------------------------------------------------

const PortForward := preload("res://game/net/port_forward.gd")
## The server's script, for its `[upnp]` sentences, which are static.
const DedicatedServer := preload("res://game/server/server.gd")
## Where this section keeps its switches: never a real server's `user://pond`.
const UPNP_ROOT := "user://net_probe_upnp/"
const UPNP_RUN_ROOT := "user://net_probe_upnp_run/"
## A stand-in `/proc`, for reading a running server's own command line.
const UPNP_PROC_ROOT := "user://net_probe_upnp_proc/"
## **Fifty frames a second**, as `invites` runs: nothing here is finer than a
## tenth of a second, and a slow search is timed in wall clock.
const UPNP_FPS := 50
## The server scene's look at its switch, as this section runs it.
const UPNP_POLL := 0.5


## **A router, as far as the forward can tell**: the four calls the real one
## takes (`PortForward.Upnp`), answered from what the test set, each written
## down with the time it came and whether it came on the main thread -- which
## none may. The forward calls it from its worker threads, so it takes a lock.
class UpnpRouter extends RefCounted:
	## What a search finds: `ok`, `reserved`, `offline`, `not_igd` or `none`.
	var status := &"ok"
	var wan := ""
	var internal := "192.0.2.12"
	var external := "203.0.113.7"
	var search_ms := 0
	## How long an add takes to answer, as a router on a slow link would.
	var add_ms := 0
	## What adding answers for a lease, and with none; what removing answers.
	var timed := PortForward.SUCCESS
	var lasting := PortForward.SUCCESS
	var removal := PortForward.SUCCESS
	var on_main := 0
	var _calls: Array = []
	var _lock := Mutex.new()

	func _init(finds: StringName = &"ok") -> void:
		status = finds

	## Each search written down with the ports it was told never to listen on.
	func discover(timeout_ms: int, avoid: PackedInt32Array = PackedInt32Array()) -> Dictionary:
		_note(["discover", timeout_ms, avoid])
		if search_ms > 0:
			OS.delay_msec(search_ms)
		var out := {"status": status, "result": PortForward.NO_DEVICES if status == &"none"
			else PortForward.SUCCESS, "devices": 0 if status == &"none" else 1}
		if status == &"ok":
			out["internal"] = internal
		elif status == &"reserved":
			out["wan"] = wan
		return out

	func external_address() -> String:
		_note(["external"])
		return external

	func add_mapping(port: int, protocol: String, said: String, lease: int) -> int:
		_note(["add", port, protocol, said, lease])
		if add_ms > 0:
			OS.delay_msec(add_ms)
		return timed if lease > 0 else lasting

	func delete_mapping(port: int, protocol: String) -> int:
		_note(["delete", port, protocol])
		return removal

	## Every call of [param kind] so far -- each `[kind, args..., msec]` -- or
	## every call at all for "".
	func calls(kind: String = "") -> Array:
		_lock.lock()
		var out: Array = []
		for call: Array in _calls:
			if kind.is_empty() or call[0] == kind:
				out.append(call.duplicate())
		_lock.unlock()
		return out

	func _note(call: Array) -> void:
		_lock.lock()
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			on_main += 1
		call.append(Time.get_ticks_msec())
		_calls.append(call)
		_lock.unlock()


## Every `[event, facts]` a forward reported, in order.
class UpnpEvents extends RefCounted:
	var said: Array = []

	func take(event: StringName, facts: Dictionary) -> void:
		said.append([event, facts])

	func count(event: StringName) -> int:
		var n := 0
		for each: Array in said:
			if each[0] == event:
				n += 1
		return n

	func first(event: StringName) -> Dictionary:
		for each: Array in said:
			if each[0] == event:
				return each[1]
		return {}

	func names() -> String:
		var out: PackedStringArray = []
		for each: Array in said:
			out.append(str(each[0]))
		return ", ".join(out)


var _upnp_catcher: LineCatcher = null


func _check_upnp() -> void:
	var began := _now()
	var began_frames := Engine.get_process_frames()
	var ceiling := Engine.max_fps
	Engine.max_fps = UPNP_FPS
	for root: String in [UPNP_ROOT, UPNP_RUN_ROOT]:
		_invites_wipe(root)
	_upnp_catcher = LineCatcher.new()
	OS.add_logger(_upnp_catcher)
	_upnp_numbers()
	await _upnp_maps_and_removes()
	await _upnp_renews()
	await _upnp_lasting()
	await _upnp_conflict()
	await _upnp_never_the_lan()
	await _upnp_cannot_help()
	await _upnp_slow_search()
	await _upnp_server_switch()
	await _upnp_server_this_run()
	await _upnp_lasting_ceiling()
	await _upnp_search_port()
	_upnp_running_override()
	_upnp_words()
	OS.remove_logger(_upnp_catcher)
	_upnp_catcher = null
	for root: String in [UPNP_ROOT, UPNP_RUN_ROOT]:
		_invites_wipe(root)
	print("[net-probe] NOTE upnp took %.1f s and %d frames, at most %d a second"
		% [_now() - began, Engine.get_process_frames() - began_frames, Engine.max_fps])
	Engine.max_fps = ceiling


## **U0: the numbers the forward mirrors are the engine's**: every result code
## and gateway status it reads by value, so that it parses where there is no
## `UPNP` at all, held to `UPNP` and `UPNPDevice` here -- an engine upgrade that
## renumbered or renamed one fails this, not a router.
func _upnp_numbers() -> void:
	var wrong: Array[String] = []
	for each: Array in PortForward.MIRRORED:
		# `class_get_integer_constant` is 0 for a name the class does not have,
		# which two of these are anyway: asked whether it has it, first.
		if not ClassDB.class_has_integer_constant(str(each[0]), str(each[1])) \
				or ClassDB.class_get_integer_constant(str(each[0]), str(each[1])) != int(each[2]):
			wrong.append(str(each[1]))
	_says(ClassDB.class_exists("UPNP") and wrong.is_empty()
			and PortForward.result_name(PortForward.CONFLICT) == "conflict with other mapping"
			and PortForward.result_name(PortForward.PERMANENT_ONLY)
				== "only permanent lease supported",
		"upnp U0: the %d result codes and gateway statuses the forward mirrors are the engine's"
		% PortForward.MIRRORED.size() + ("" if wrong.is_empty() else " -- NOT: "
			+ ", ".join(wrong)))


## How many of [param calls] name [param port], or -1 when any names another.
func _upnp_only(calls: Array, port: int) -> int:
	for call: Array in calls:
		if int(call[1]) != port:
			return -1
	return calls.size()


## A forward of [method Invite.channel_port] that never maps [method Lan.channel_port], as
## the server makes it, through [param router], its events kept in
## [param events].
func _upnp_forward(router: UpnpRouter, events: UpnpEvents,
		port: int = Invite.channel_port()) -> Node:
	var forward: Node = PortForward.new(port, DedicatedServer.upnp_description(),
		PackedInt32Array([Lan.channel_port()]), router)
	forward.reported.connect(events.take)
	add_child(forward)
	return forward


func _upnp_gone(forward: Node) -> void:
	forward.stop()
	await _limits_until(func() -> bool: return bool(forward.is_stopped()), 3.0)
	forward.queue_free()


## **U1: it maps at start, and U2: takes it off at a stop.** One search, off the
## main thread, told never to listen on this port or the LAN's; the port, the
## same outside and in, UDP, for an hour, to this machine as the router sees
## it, the hour counted from when the router was asked -- this one takes a
## quarter of a second to answer -- not from when it did; the router's public
## address said once. Then the forward asked for once more and taken off, and
## nothing asked after it.
func _upnp_maps_and_removes() -> void:
	var router := UpnpRouter.new()
	router.add_ms = 250
	var events := UpnpEvents.new()
	var forward := _upnp_forward(router, events)
	forward.start()
	var mapped := await _limits_until(func() -> bool: return bool(forward.holds()), 3.0)
	var adds := router.calls("add")
	var searches := router.calls("discover")
	var said: Dictionary = events.first(&"mapped")
	var address: Dictionary = events.first(&"address")
	var counted_from := float(forward.get("_lease_end")) - float(PortForward.LEASE)
	var asked_at := float(adds[0][5]) / 1000.0 if not adds.is_empty() else -INF
	var avoided: PackedInt32Array = searches[0][2] if not searches.is_empty() \
		else PackedInt32Array()
	_says(mapped >= 0.0 and searches.size() == 1
			and int(searches[0][1]) == PortForward.DISCOVER_TIMEOUT
			and avoided.has(Invite.channel_port()) and avoided.has(Lan.channel_port())
			and absf(counted_from - asked_at) < 0.05 and adds.size() == 1
			and int(adds[0][1]) == Invite.channel_port() and str(adds[0][2]) == "UDP"
			and str(adds[0][3]) == DedicatedServer.upnp_description()
			and int(adds[0][4]) == PortForward.LEASE
			and not bool(forward.is_permanent()) and str(said.get("internal", "")) == "192.0.2.12"
			and str(address.get("address", "")) == "203.0.113.7"
			and StringName(address.get("kind", &"")) == &"public" and router.on_main == 0,
		"upnp U1: started, the forward searches once, off the main thread and never listening on"
		+ " %s, and maps UDP %d to this machine's %s:%d for %d s, %.2f s in -- the lease" % [
			str(avoided), Invite.channel_port(), said.get("internal", "?"),
			Invite.channel_port(), PortForward.LEASE, mapped] + " counted from %.0f ms before"
		% ((asked_at + 0.25 - counted_from) * 1000.0) + " the router answered -- and says the"
		+ " router's public address, %s (%s)" % [address.get("address", "?"), events.names()])
	forward.stop()
	var stopped := await _limits_until(func() -> bool: return bool(forward.is_stopped()), 3.0)
	await _wait(0.3)
	var removals := router.calls("delete")
	var all := router.calls()
	_says(stopped >= 0.0 and removals.size() == 1 and int(removals[0][1]) == Invite.channel_port()
			and str(removals[0][2]) == "UDP" and not bool(forward.holds())
			and events.count(&"removed") == 1 and all.size() == 5
			and str(all[3][0]) == "add" and int(all[3][1]) == Invite.channel_port()
			and str(all[4][0]) == "delete" and router.on_main == 0,
		"upnp U2: stopped, it asks for that forward once more and then takes it off the router,"
		+ " %.2f s later, says so once, and asks nothing more" % stopped)
	forward.queue_free()


## **U3: it renews before the lease ends -- and a renewal that does not take is
## one line, however often it is asked again.** A four-second lease is asked
## again at two; the router gives no answer to that or the two retries after
## it, which is one `renew_failed`, and each retry searches for the router
## afresh, as one that restarted elsewhere needs; a later one takes -- still
## inside the lease, with two retries to spare for a runner that stalls --
## which is one `renewed`, the forward held throughout.
func _upnp_renews() -> void:
	var router := UpnpRouter.new()
	var events := UpnpEvents.new()
	var forward := _upnp_forward(router, events)
	forward.lease = 4
	forward.renew_retry = 0.1
	forward.start()
	await _limits_until(func() -> bool: return bool(forward.holds()), 3.0)
	router.timed = PortForward.HTTP_ERROR
	await _limits_until(func() -> bool: return router.calls("add").size() >= 4, 3.0)
	var refused := router.calls("add").size()
	router.timed = PortForward.SUCCESS
	await _limits_until(func() -> bool: return events.count(&"renewed") >= 1, 3.0)
	var adds := router.calls("add")
	var taken := float(adds[0][5]) if not adds.is_empty() else 0.0
	var asked := (float(adds[1][5]) - taken) / 1000.0 if adds.size() > 1 else INF
	var took := (float(adds[adds.size() - 1][5]) - taken) / 1000.0 if adds.size() > 4 else INF
	var told: Dictionary = events.first(&"renew_failed")
	var searches := router.calls("discover").size()
	_says(refused >= 4 and adds.size() >= 5 and int(adds[1][4]) == 4
			and searches == adds.size() - 1
			and int(adds[1][1]) == Invite.channel_port() and asked >= 1.9 and asked < 2.5
			and took < 4.0
			and events.count(&"renew_failed") == 1 and events.count(&"renewed") == 1
			and str(told.get("name", "")) == "http error" and bool(forward.holds())
			and events.count(&"lapsed") == 0,
		"upnp U3: a 4 s lease is asked again %.2f s after it was taken, before it ends; the" % asked
		+ " %d unanswered running are one line, each retried by a fresh search (%d in all)," % [
			adds.size() - 2, searches] + " and the renewal that takes, %.2f s in, is one" % took
		+ " more -- the forward held throughout (%s)" % events.names())
	await _upnp_gone(forward)


## **U4: a router that takes no timed lease gets one with no time limit** --
## asked once for the hour, refused with 725, then with none -- which is put
## again with none from then on, and taken off at a stop like any other, asked
## for with none once more first. Started again at a router that now takes the
## hour, it asks for the hour first: no time limit is asked for only while one
## is held.
func _upnp_lasting() -> void:
	var router := UpnpRouter.new()
	router.timed = PortForward.PERMANENT_ONLY
	var events := UpnpEvents.new()
	var forward := _upnp_forward(router, events)
	forward.permanent_check = 0.3
	forward.start()
	await _limits_until(func() -> bool: return router.calls("add").size() >= 3, 3.0)
	var adds := router.calls("add")
	var leases: Array[int] = []
	for add: Array in adds:
		leases.append(int(add[4]))
	var lasting := bool(forward.is_permanent())
	var before_stop := router.calls("add").size()
	forward.stop()
	await _limits_until(func() -> bool: return bool(forward.is_stopped()), 3.0)
	var at_stop := router.calls("add").slice(before_stop)
	router.timed = PortForward.SUCCESS
	var before_start := router.calls("add").size()
	forward.start()
	await _limits_until(func() -> bool: return router.calls("add").size() > before_start, 3.0)
	var anew := router.calls("add").slice(before_start)
	_says(adds.size() >= 3 and leases[0] == PortForward.LEASE and leases[1] == 0 and leases[2] == 0
			and lasting and bool(events.first(&"mapped").get("permanent", false))
			and at_stop.size() == 1 and int(at_stop[0][4]) == 0
			and router.calls("delete").size() == 1 and events.count(&"removed") == 1
			and not anew.is_empty() and int(anew[0][4]) == PortForward.LEASE,
		"upnp U4: refused a timed lease (725), it maps with no time limit and puts it again"
		+ " with none -- leases asked %s -- a stop asks for it with none once more" % str(leases)
		+ " and takes it off, and started again it asks for the hour first")
	await _upnp_gone(forward)


## **U5: a port the router forwards to another machine is left alone** -- one
## line, however often it looks again, no removal at a stop, and the public
## address said without the hint for `--reach`: the forward was never this
## one's. And a forward this one held, which the router gave to another machine
## before the stop -- asked for once more at the stop, it answers 718 -- is left
## there too.
func _upnp_conflict() -> void:
	var router := UpnpRouter.new()
	router.timed = PortForward.CONFLICT
	var events := UpnpEvents.new()
	var forward := _upnp_forward(router, events)
	forward.look_again = 0.2
	forward.look_again_max = 0.2
	forward.start()
	await _limits_until(func() -> bool: return router.calls("discover").size() >= 3, 3.0)
	var looks := router.calls("discover").size()
	forward.stop()
	await _limits_until(func() -> bool: return bool(forward.is_stopped()), 3.0)
	await _wait(0.2)
	var line := DedicatedServer.upnp_said(&"conflict", events.first(&"conflict"))
	var elsewhere: Dictionary = events.first(&"address")
	var hint := DedicatedServer.upnp_said(&"address", elsewhere)
	var kept := bool(forward.holds())
	forward.queue_free()
	# Held, then given away before the stop.
	var given := UpnpRouter.new()
	var held := UpnpEvents.new()
	var holding := _upnp_forward(given, held)
	holding.start()
	await _limits_until(func() -> bool: return bool(holding.holds()), 3.0)
	given.timed = PortForward.CONFLICT
	given.lasting = PortForward.CONFLICT
	holding.stop()
	await _limits_until(func() -> bool: return bool(holding.is_stopped()), 3.0)
	var left := DedicatedServer.upnp_said(&"not_ours", held.first(&"not_ours"))
	holding.queue_free()
	_says(looks >= 3 and events.count(&"conflict") == 1 and not kept
			and router.calls("delete").is_empty() and line.contains("forwards UDP %d elsewhere"
				% Invite.channel_port()) and line.contains("left alone")
			and line.contains("192.0.2.12")
			and not bool(elsewhere.get("held", true)) and not hint.contains("set --reach")
			and hint.contains("which this server's own forward does not")
			and given.calls("add").size() == 2 and given.calls("delete").is_empty()
			and held.count(&"not_ours") == 1 and held.count(&"removed") == 0
			and left.contains("another machine holds it now"),
		"upnp U5: with the port forwarded elsewhere, %d looks say so once, a stop removes" % looks
		+ " nothing, and the public address comes without the hint for --reach; one it held"
		+ " and the router gave away before the stop is asked for again, answered 718, and"
		+ " left there: \"%s...\"" % line.substr(0, 60))


## **U6: never the LAN's port.** A forward made for [method Lan.channel_port] asks the
## router nothing at all, not even a search; one made for the internet port
## and pointed at the LAN's afterwards is refused where the call is made; and
## the guard itself: its own port, 1 to 65535, and none of its never-list.
func _upnp_never_the_lan() -> void:
	var router := UpnpRouter.new()
	var events := UpnpEvents.new()
	var lan_forward := _upnp_forward(router, events, Lan.channel_port())
	lan_forward.start()
	await _wait(0.3)
	var asked_for_lan := router.calls().size()
	lan_forward.queue_free()
	var turned := UpnpEvents.new()
	var retold := _upnp_forward(router, turned)
	retold.set("port", Lan.channel_port())
	retold.start()
	await _wait(0.3)
	var untouched := router.calls().is_empty()
	retold.queue_free()
	# One already forwarding when it is turned: its renewal is refused where the
	# call is made, and its stop still takes off its own port, and only that.
	var held := UpnpEvents.new()
	var holding := _upnp_forward(router, held)
	holding.lease = 2
	holding.start()
	await _limits_until(func() -> bool: return bool(holding.holds()), 3.0)
	holding.set("port", Lan.channel_port())
	await _limits_until(func() -> bool: return held.count(&"forbidden") > 0, 3.0)
	holding.stop()
	await _limits_until(func() -> bool: return bool(holding.is_stopped()), 3.0)
	holding.queue_free()
	var lan_calls := 0
	for call: Array in router.calls():
		if call.size() > 1 and int(call[1]) == Lan.channel_port():
			lan_calls += 1
	var removed := router.calls("delete")
	var lan := Lan.channel_port()
	var net := Invite.channel_port()
	var guard := not PortForward.may_map(lan, lan, PackedInt32Array([lan])) \
		and not PortForward.may_map(lan, net, PackedInt32Array()) \
		and not PortForward.may_map(0, 0, PackedInt32Array()) \
		and PortForward.may_map(net, net, PackedInt32Array([lan]))
	_says(asked_for_lan == 0 and events.count(&"forbidden") == 1 and untouched
			and turned.count(&"forbidden") == 1 and held.count(&"forbidden") == 1
			and lan_calls == 0 and removed.size() == 1 and int(removed[0][1]) == net
			and _upnp_only(router.calls("add"), net) == 2 and guard,
		"upnp U6: UDP %d is never forwarded -- a forward made for it asks the router" % lan
		+ " nothing; one turned to it before it starts, or while it holds %d, is" % net
		+ " refused where the call is made, and the one holding takes off its own port at a"
		+ " stop and no other; the guard takes only the port a forward was made for")


## **U7: a router that cannot help is said to be one, and asked for nothing**:
## its own internet address shared (carrier-grade NAT), private (a router
## behind a router), or one it would not say -- each with the sentence the
## server prints -- and a public one the hint for `--reach`, which is never set
## for the owner. 100.64.0.2, 10.0.0.2 and 172.16.0.1 are round stand-ins for
## their ranges, as the adapters' checks use; 203.0.113.7 is RFC 5737's.
func _upnp_cannot_help() -> void:
	var lines := {}
	var adds := 0
	for wan: String in ["100.64.0.2", "10.0.0.2", ""]:
		var router := UpnpRouter.new(&"reserved")
		router.wan = wan
		var events := UpnpEvents.new()
		var forward := _upnp_forward(router, events)
		forward.start()
		await _limits_until(func() -> bool: return events.count(&"cannot_help") > 0, 2.0)
		lines[wan] = DedicatedServer.upnp_said(&"cannot_help", events.first(&"cannot_help"))
		adds += router.calls("add").size()
		await _upnp_gone(forward)
	var shared := str(lines["100.64.0.2"])
	var private := str(lines["10.0.0.2"])
	var unsaid := str(lines[""])
	var facts := {"port": Invite.channel_port(), "protocol": "UDP", "address": "203.0.113.7",
		"kind": PortForward.kind_of("203.0.113.7")}
	var hint := DedicatedServer.upnp_said(&"address", facts)
	var named := DedicatedServer.upnp_said(&"address", facts, {"address": "203.0.113.7",
		"port": Invite.channel_port()})
	var v6 := DedicatedServer.upnp_said(&"address", facts, {"address": "2001:db8::7",
		"port": Invite.channel_port()})
	var gone_private := DedicatedServer.upnp_said(&"address", {"port": Invite.channel_port(),
		"protocol": "UDP", "address": "10.0.0.2", "kind": PortForward.kind_of("10.0.0.2")})
	_says(adds == 0 and shared.contains("100.64.0.2") and shared.contains("shares one address")
			and shared.contains("cannot reach you") and private.contains("10.0.0.2")
			and private.contains("two routers in a row")
			and unsaid.contains("private, shared, or none")
			and hint.contains("set --reach=203.0.113.7") and named.ends_with("which --reach names")
			and v6.contains("a firewall rule, not a forward") and gone_private == private
			and PortForward.kind_of("172.16.0.1") == &"private"
			and PortForward.kind_of("0.0.0.0") == &"unusable"
			and PortForward.kind_of("pond.example.net") == &"unknown",
		"upnp U7: a router whose own address is shared, private or unsaid is asked for nothing"
		+ " and named as what it is -- carrier-grade NAT, two routers in a row -- and a public"
		+ " one is the hint for --reach, which the server never sets; IPv6 needs a firewall rule")


## **U8: a search that takes seconds does not stop the frames.** The router
## takes 1.5 s to answer, on the worker thread, and the main thread goes on at
## its fifty a second meanwhile: its longest frame is timed.
func _upnp_slow_search() -> void:
	var router := UpnpRouter.new()
	router.search_ms = 1500
	var events := UpnpEvents.new()
	var forward := _upnp_forward(router, events)
	var frames := 0
	var longest := 0.0
	var last := _clock()
	var from := _clock()
	forward.start()
	while not bool(forward.holds()) and _clock() - from < 5.0:
		await get_tree().process_frame
		var now := _clock()
		longest = maxf(longest, now - last)
		last = now
		frames += 1
	var took := _clock() - from
	_says(bool(forward.holds()) and took >= 1.4 and frames >= int(1.5 * UPNP_FPS * 0.6)
			and longest < 0.25 and router.on_main == 0,
		"upnp U8: a search that takes %.2f s costs the main thread nothing: %d frames went" % [took,
			frames] + " by meanwhile, the longest %.0f ms" % (longest * 1000.0))
	await _upnp_gone(forward)


## A server scene with a router of the probe's own, [param router], its
## switches under [param root], looked at every [constant UPNP_POLL].
func _upnp_server(router: UpnpRouter, root: String, args: PackedStringArray) -> Node:
	var server: Node = load(SERVER_SCENE).instantiate()
	server.set("check_updates", false)
	server.set("own_frame_rate", false)
	server.set("quits", false)
	server.set("pond_root", root)
	server.set("invites_poll", UPNP_POLL)
	server.set("upnp_router", router)
	server.set("job_args", args)
	# No room kept: this user dir's `rooms/1.save` is not the probe's to write.
	server.set("room_path", "")
	get_tree().root.add_child.call_deferred(server)
	await server.ready
	return server


## The `[upnp]` lines printed since [param from].
func _upnp_lines(from: int) -> Array[String]:
	var out: Array[String] = []
	for line: String in _upnp_catcher.lines.slice(from):
		if line.begins_with("[upnp] "):
			out.append(line.strip_edges())
	return out


func _upnp_has(lines: Array[String], part: String) -> bool:
	for line: String in lines:
		if line.contains(part):
			return true
	return false


## **U9-U11: the server scene.** It forwards from its first READY, whatever the
## invites -- there are none here -- to [method Invite.channel_port] and never
## [method Lan.channel_port]; `--no-upnp`, run as the command line runs it, takes the
## forward off within a look, is remembered in `pond/upnp.cfg`, `rw-------`, and
## asks the router nothing while it holds; `--upnp` forwards again within a
## look; and the server's clean stop takes the forward off.
func _upnp_server_switch() -> void:
	var router := UpnpRouter.new()
	var from := _upnp_catcher.lines.size()
	var server: Node = await _upnp_server(router, UPNP_ROOT, PackedStringArray())
	var forward: Node = server.call("forward")
	var up := await _limits_until(func() -> bool: return forward != null and bool(forward.holds()),
		3.0)
	var at_start := _upnp_lines(from)
	_says(up >= 0.0 and int(forward.port) == Invite.channel_port()
			and (forward.call("never") as PackedInt32Array).has(Lan.channel_port())
			and not bool(server.session().internet_listening())
			and _upnp_has(at_start, "looking for the router")
			and _upnp_has(at_start, "forwarded UDP %d" % Invite.channel_port())
			and _upnp_has(at_start, "set --reach=203.0.113.7")
			and router.on_main == 0,
		"upnp U9: the server forwards UDP %d from its first READY, %.2f s in, with no" % [
			Invite.channel_port(), up] + " invite and nothing listening there -- never UDP %d --"
		% Lan.channel_port() + " and says so in %d [upnp] lines" % at_start.size())
	var job: Array = InviteBook.run(PackedStringArray(["--no-upnp"]), UPNP_ROOT)
	var mode := FileAccess.get_unix_permissions(str(InviteBook.paths(UPNP_ROOT)["upnp"]))
	var off := await _limits_until(func() -> bool:
		return router.calls("delete").size() == 1 and not bool(forward.holds()), UPNP_POLL * 4.0)
	var asked := router.calls().size()
	await _wait(UPNP_POLL * 3.0)
	var listing: Array = InviteBook.run(PackedStringArray(["--invites"]), UPNP_ROOT)
	var said_off := _upnp_lines(from)
	var job_said := "\n".join(PackedStringArray(job[1]))
	_says(int(job[0]) == 0 and job_said.contains("upnp: off, remembered")
			and mode == Invite.PRIVATE and InviteBook.upnp_setting(UPNP_ROOT) == 0
			and off >= 0.0 and off <= UPNP_POLL + 0.5 and router.calls().size() == asked
			and _upnp_has(said_off, "off (--no-upnp)") and _upnp_has(said_off, "took the forward")
			and "\n".join(PackedStringArray(listing[1])).contains("upnp: off"),
		"upnp U10: --no-upnp is remembered in pond/upnp.cfg (%o), and the running server" % mode
		+ " takes its forward off %.2f s later, within a look, and asks the router" % off
		+ " nothing while it holds")
	job = InviteBook.run(PackedStringArray(["--upnp"]), UPNP_ROOT)
	var again := await _limits_until(func() -> bool: return bool(forward.holds()), UPNP_POLL * 4.0
		+ 1.0)
	var before_stop := router.calls("delete").size()
	var line_from := _upnp_catcher.lines.size()
	server.call("shut_down")
	var taken := await _limits_until(func() -> bool:
		return router.calls("delete").size() == before_stop + 1 and bool(forward.is_stopped()),
		3.0)
	var at_stop := _upnp_lines(line_from)
	_says(int(job[0]) == 0 and again >= 0.0 and InviteBook.upnp_setting(UPNP_ROOT) == 1
			and _upnp_has(_upnp_lines(from), "on again (--upnp)") and taken >= 0.0
			and _upnp_has(at_stop, "took the forward of UDP %d off the router"
				% Invite.channel_port())
			and router.on_main == 0,
		"upnp U11: --upnp forwards again %.2f s later, and the server's clean stop takes the"
		% again + " forward off the router %.2f s after it is asked" % taken)
	server.queue_free()
	await _wait(0.3)


## **U12: `--no-upnp` on the service's own command line** -- beside
## `--no-update` or `--stop-file=` -- holds for that run: the server runs rather
## than doing a job and exiting, asks the router nothing, and writes nothing
## down. Alone, it is a job.
func _upnp_server_this_run() -> void:
	var router := UpnpRouter.new()
	var from := _upnp_catcher.lines.size()
	var server: Node = await _upnp_server(router, UPNP_RUN_ROOT,
		PackedStringArray(["--no-update", "--no-upnp"]))
	await _wait(UPNP_POLL * 3.0)
	var said := _upnp_lines(from)
	var ran := server.session() != null and int(server.get("_job_code")) == -1
	_says(ran and router.calls().is_empty() and _upnp_has(said, "off for this run")
			and not FileAccess.file_exists(str(InviteBook.paths(UPNP_RUN_ROOT)["upnp"]))
			and InviteBook.is_job(PackedStringArray(["--no-upnp"]))
			and not InviteBook.is_job(PackedStringArray(["--stop-file=/run/x", "--no-upnp"]))
			and not bool(server.forward().is_on()),
		"upnp U12: --no-upnp beside --no-update runs the server, asks the router nothing and"
		+ " writes nothing down; alone, it is a job")
	server.call("shut_down")
	server.queue_free()
	await _wait(0.3)


## **U13: a forward with no time limit is asked for again no further apart than
## [member PortForward.permanent_check], however long the router stays away.**
## Held with none, then refused (501) at every renewal: the waits double from
## [member PortForward.renew_retry] and stop at the ceiling, where they had
## doubled on without end -- after a two-hour outage, the next try was hours
## off while the status line said "forwarded".
func _upnp_lasting_ceiling() -> void:
	var router := UpnpRouter.new()
	router.timed = PortForward.PERMANENT_ONLY
	var events := UpnpEvents.new()
	var forward := _upnp_forward(router, events)
	forward.permanent_check = 0.5
	forward.renew_retry = 0.1
	forward.start()
	await _limits_until(func() -> bool: return bool(forward.is_permanent()), 3.0)
	router.lasting = ClassDB.class_get_integer_constant("UPNP", "UPNP_RESULT_ACTION_FAILED")
	var from := router.calls("add").size()
	await _limits_until(func() -> bool: return router.calls("add").size() >= from + 7, 5.0)
	var tries := router.calls("add").slice(from)
	var gaps: Array[float] = []
	for i in range(1, tries.size()):
		gaps.append((float(tries[i][5]) - float(tries[i - 1][5])) / 1000.0)
	var longest := 0.0
	for gap: float in gaps:
		longest = maxf(longest, gap)
	var shown: PackedStringArray = []
	for gap: float in gaps:
		shown.append("%.2f" % gap)
	_says(tries.size() >= 7 and longest <= 0.5 + 0.15 and gaps.size() >= 5
			and gaps[gaps.size() - 1] >= 0.45 and bool(forward.holds())
			and events.count(&"renew_failed") == 1,
		"upnp U13: refused at every renewal, a forward with no time limit is asked again %s s" % (
			", ".join(shown)) + " apart -- never further than its 0.5 s ceiling -- and says so"
		+ " once")
	await _upnp_gone(forward)


## **U14: the search never listens on the forwarded port, or the LAN's.** Its
## port is drawn from 49152 to 65535 for every search; twenty thousand draws
## land in that range and never on the forwarded port or the LAN's -- 45772 and
## 45771 on the release channel -- and a draw that lands on a port it must
## avoid moves on to the next, round the range. The forward hands the search
## its own port and its never-list. A search port the forward reached would
## take any datagram from the internet for a router's answer.
func _upnp_search_port() -> void:
	var draw := RandomNumberGenerator.new()
	draw.seed = 7
	var avoid := PackedInt32Array([Invite.channel_port(), Lan.channel_port()])
	var outside := 0
	var ours := 0
	var low := 65536
	var high := 0
	for _i in 20000:
		var port := PortForward.Upnp.search_port(avoid, draw)
		if port < PortForward.Upnp.SEARCH_PORT_LOW or port > PortForward.Upnp.SEARCH_PORT_HIGH:
			outside += 1
		if avoid.has(port):
			ours += 1
		low = mini(low, port)
		high = maxi(high, port)
	# Every port of the range but one avoided: the draw finds the one left.
	var all_but := PackedInt32Array()
	for port in range(PortForward.Upnp.SEARCH_PORT_LOW, PortForward.Upnp.SEARCH_PORT_HIGH + 1):
		if port != 60000:
			all_but.append(port)
	var cornered := PortForward.Upnp.search_port(all_but, draw)
	var router := UpnpRouter.new(&"none")
	var events := UpnpEvents.new()
	var forward := _upnp_forward(router, events)
	forward.start()
	await _limits_until(func() -> bool: return not router.calls("discover").is_empty(), 3.0)
	await _upnp_gone(forward)
	var told: PackedInt32Array = router.calls("discover")[0][2] \
		if not router.calls("discover").is_empty() else PackedInt32Array()
	_says(outside == 0 and ours == 0 and cornered == 60000 and told.has(Invite.channel_port())
			and told.has(Lan.channel_port())
			and PortForward.Upnp.SEARCH_PORT_LOW > Invite.channel_port()
			and PortForward.Upnp.SEARCH_PORT_LOW > Lan.channel_port(),
		"upnp U14: 20000 search ports drawn from %d-%d, none outside it and none %d or %d;" % [
			low, high, Invite.channel_port(), Lan.channel_port()] + " a draw on an avoided port"
		+ " moves on, and the forward tells its search to avoid %s" % str(told))


## **U15: a running server's own `--no-upnp` or `--upnp` is found and named.**
## Read from `cmdline` files as `ps` reads them -- here under a stand-in
## `/proc`: the service, run with its own flags, counts; the same binary doing
## a job, another program, and this process do not. The jobs and `--invites`
## then say what that server makes of the switch, rather than promising what
## its command line overrides.
func _upnp_running_override() -> void:
	var exe := "/opt/biogenic/biogenic-server.x86_64"
	var write := func(pid: String, argv: Array) -> void:
		DirAccess.make_dir_recursive_absolute(UPNP_PROC_ROOT.path_join(pid))
		var bytes := PackedByteArray()
		for arg: String in argv:
			bytes.append_array(arg.to_utf8_buffer())
			bytes.append(0)
		var file := FileAccess.open(UPNP_PROC_ROOT.path_join(pid).path_join("cmdline"),
			FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	_upnp_proc_wipe()
	write.call("102", [exe, "--headless", "--", "--invites"])
	write.call("103", ["/usr/bin/bash", "-c", "--", "--stop-file=/run/biogenic/stop", "--no-upnp"])
	DirAccess.make_dir_recursive_absolute(UPNP_PROC_ROOT.path_join("self"))
	var none := InviteBook.running_upnp_override(UPNP_PROC_ROOT, exe, 999)
	write.call("101", [exe, "--headless", "--", "--stop-file=/run/biogenic/stop"])
	var plain := InviteBook.running_upnp_override(UPNP_PROC_ROOT, exe, 999)
	write.call("101", [exe, "--headless", "--", "--stop-file=/run/biogenic/stop", "--upnp"])
	var forced := InviteBook.running_upnp_override(UPNP_PROC_ROOT, exe, 999)
	write.call("101", [exe, "--headless", "--", "--stop-file=/run/biogenic/stop", "--no-upnp"])
	var off := InviteBook.running_upnp_override(UPNP_PROC_ROOT, exe, 999)
	var mine := InviteBook.running_upnp_override(UPNP_PROC_ROOT, exe, 101)
	var missing := InviteBook.running_upnp_override(UPNP_PROC_ROOT.path_join("nowhere"), exe, 999)
	_upnp_proc_wipe()
	var off_job := InviteBook._running_takes(false, 1)
	var on_job := InviteBook._running_takes(true, -1)
	var unseen := InviteBook._running_takes(false, -2)
	var plain_job := InviteBook._running_takes(false, 0)
	var listed := InviteBook.upnp_said(1, -1)
	var listed_unseen := InviteBook.upnp_said(1, -2)
	var listed_agree := InviteBook.upnp_said(0, -1)
	_says(none == -2 and plain == 0 and forced == 1 and off == -1 and mine == -2 and missing == -2
			and off_job.contains("says --upnp, which holds for its run")
			and on_job.contains("says --no-upnp, which holds for its run")
			and unseen.contains("unless its own command line says --upnp")
			and plain_job == "the running server takes its forward off within seconds."
			and listed.contains("but the running server's own command line says --no-upnp")
			and listed_unseen.contains("would hold instead")
			and listed_agree.begins_with("upnp: off --") and not listed_agree.contains("but"),
		"upnp U15: a running server's own command line is read from /proc -- %d with" % plain
		+ " neither,"
		+ " %d with --upnp, %d with --no-upnp, and %d for a job, another program, this" % [forced,
			off, none] + " process or no /proc -- and the jobs and --invites say what it makes of"
		+ " the switch")


func _upnp_proc_wipe() -> void:
	if not DirAccess.dir_exists_absolute(UPNP_PROC_ROOT):
		return
	for pid: String in DirAccess.get_directories_at(UPNP_PROC_ROOT):
		var dir := UPNP_PROC_ROOT.path_join(pid)
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(UPNP_PROC_ROOT)


## **U16: the words say what is so.** No router answering is where UPnP being
## off lands, since Godot keeps only devices that say they are Internet Gateway
## Devices; a router whose description cannot be read is not called off. The
## advice for `--reach` tells a switch it cannot read from one set to off. And
## a stop still waiting on the router says so at once, with the wait it will
## take and that SIGTERM comes sooner under systemd.
func _upnp_words() -> void:
	var what := {"port": Invite.channel_port(), "protocol": "UDP"}
	var silent := DedicatedServer.upnp_said(&"no_router", what.merged({"network": true}))
	var unread := DedicatedServer.upnp_said(&"no_gateway", what.merged({"why": &"not_igd",
		"devices": 2}))
	var looking := DedicatedServer.upnp_said(&"stop_timeout", what.merged({"holds": false}))
	var lasting := DedicatedServer.upnp_said(&"stop_timeout", what.merged({"holds": true,
		"permanent": true}))
	var timed := DedicatedServer.upnp_said(&"stop_timeout", what.merged({"holds": true,
		"permanent": false, "lease": 3600}))
	var on := InviteBook.forward_advice(Invite.channel_port(), 1)
	var off := InviteBook.forward_advice(Invite.channel_port(), 0)
	var unreadable := InviteBook.forward_advice(Invite.channel_port(), -1)
	var other := InviteBook.forward_advice(50000, 1)
	_says(silent.contains("UPnP is off in the router, most likely")
			and unread.contains("UPnP is on") and unread.contains("could not be read")
			and not unread.contains("UPnP is off")
			and looking.contains("15 s at most for each call") and looking.contains("SIGTERM")
			and looking.contains("nothing is forwarded yet")
			and lasting.contains("stays until you take it off the router")
			and timed.contains("lapses within an hour")
			and on.contains("by UPnP") and off.contains("(--no-upnp)")
			and unreadable.contains("cannot be read") and not unreadable.contains("--no-upnp")
			and other.contains("is of %d, not of 50000" % Invite.channel_port()),
		"upnp U16: the lines say what is so -- no router answering is where UPnP off lands, a"
		+ " description that cannot be read is not called off, an unreadable switch is not"
		+ " called --no-upnp, and a stop still waiting says how long, and that SIGTERM comes"
		+ " sooner")


# ---------------------------------------------------------------------------
# **The channel** (`game/net/channel.gd`; docs/server.md, "A dev server"):
# which pair of ports a build is on. A build that follows a branch's rolling
# prerelease -- the dev app, and the dev server beside it -- is on its branch's
# channel, 45781 and 45782; every other build is on the release channel, 45771
# and 45772, as every build was before there were two. This section poses as
# each through `Channel.posing`, the seam no player reaches, and holds the game
# to the pair wherever it binds, dials, forwards, prints or defaults a port --
# the sockets themselves, not only the helpers -- and the release channel to
# what it said before, word for word.
# ---------------------------------------------------------------------------

const Channel := preload("res://game/net/channel.gd")
## For its receipt, `address · port`, which is the one port a screen shows.
const Earshot := preload("res://game/net/earshot.gd")
## Where this section keeps its books and its stand-in `/proc`: never a real
## server's `user://pond`.
const CHANNEL_ROOT := "user://net_probe_channel/"
const CHANNEL_SERVER_ROOT := "user://net_probe_channel_server/"
const CHANNEL_WORDS_ROOT := "user://net_probe_channel_words/"
const CHANNEL_PROC_ROOT := "user://net_probe_channel_proc/"
## **The two pairs, written out** -- the LAN's port, then the internet's --
## which the helpers are held to.
const RELEASE_PAIR := [45771, 45772]
const BRANCH_PAIR := [45781, 45782]

var _channel_catcher: LineCatcher = null


func _check_channel() -> void:
	var began := _now()
	var began_frames := Engine.get_process_frames()
	var ceiling := Engine.max_fps
	Engine.max_fps = INVITES_FPS
	NetSession.forget_refusals()
	for root: String in [CHANNEL_ROOT, CHANNEL_SERVER_ROOT, CHANNEL_WORDS_ROOT]:
		_invites_wipe(root)
	_channel_catcher = LineCatcher.new()
	OS.add_logger(_channel_catcher)
	_channel_pairs()
	await _channel_sockets()
	await _channel_server("dev")
	await _channel_server("")
	_channel_words()
	_channel_own_server()
	Channel.posing = null
	OS.remove_logger(_channel_catcher)
	_channel_catcher = null
	NetSession.forget_refusals()
	for root: String in [CHANNEL_ROOT, CHANNEL_SERVER_ROOT, CHANNEL_WORDS_ROOT]:
		_invites_wipe(root)
	print("[net-probe] NOTE channel took %.1f s and %d frames, at most %d a second"
		% [_now() - began, Engine.get_process_frames() - began_frames, Engine.max_fps])
	Engine.max_fps = ceiling


## **K1: the two pairs.** Posed as the release channel, the LAN's port is 45771
## and the internet's 45772 -- `Lan.PORT` and `Invite.PORT`, as they always
## were; posed as a branch's, 45781 and 45782. The four are apart, and all
## below the range a UPnP search listens in. Unposed, the channel is this
## build's own stamp, read from BuildInfo and fixed: the same at every ask.
func _channel_pairs() -> void:
	var info := get_node_or_null(^"/root/BuildInfo")
	var stamped: Variant = info.get("release_branch") if info != null else null
	var stamp: String = stamped if stamped is String else ""
	Channel.posing = null
	var own := [Channel.branch(), Lan.channel_port(), Invite.channel_port()]
	Channel.posing = ""
	var release := [Lan.channel_port(), Invite.channel_port(), Channel.is_branch(),
		Channel.port(1000)]
	Channel.posing = "dev"
	var branch := [Lan.channel_port(), Invite.channel_port(), Channel.is_branch(),
		Channel.port(1000)]
	Channel.posing = null
	var again := [Channel.branch(), Lan.channel_port(), Invite.channel_port()]
	var own_pair: Array = BRANCH_PAIR if not stamp.is_empty() else RELEASE_PAIR
	var below := true
	for port: int in RELEASE_PAIR + BRANCH_PAIR:
		below = below and port < PortForward.Upnp.SEARCH_PORT_LOW
	var apart := {}
	for port: int in RELEASE_PAIR + BRANCH_PAIR:
		apart[port] = true
	_says(release == [45771, 45772, false, 1000] and branch == [45781, 45782, true, 1010]
			and [Lan.PORT, Invite.PORT] == RELEASE_PAIR and Channel.BRANCH_SHIFT == 10
			and own == [stamp, own_pair[0], own_pair[1]] and again == own
			and apart.size() == 4 and below,
		"channel K1: the release channel is on %d and %d, a branch's on %d and %d -- four"
		% [release[0], release[1], branch[0], branch[1]] + " ports, all apart; this"
		+ " build's own stamp, read from BuildInfo, is '%s': %d and %d, the same at"
		% [stamp, own[1], own[2]] + " every ask")


## Whether [param port] is held on this machine: a UDP socket cannot bind it.
func _channel_held(port: int) -> bool:
	var probe := PacketPeerUDP.new()
	var held := probe.bind(port) != OK
	probe.close()
	return held


## Which of the four ports are held: the release channel's LAN and internet
## ports, then the branch channel's.
func _channel_holds() -> Array:
	var out: Array = []
	for port: int in RELEASE_PAIR + BRANCH_PAIR:
		out.append(_channel_held(port))
	return out


## The port [param guest]'s LAN call went to.
func _channel_dialled(guest: Node) -> int:
	var peer := guest.get("_peer") as ENetMultiplayerPeer
	if peer == null or peer.get_peer(1) == null:
		return -1
	return peer.get_peer(1).get_remote_port()


## **K2: every listener binds its channel's port. K3: every call dials its
## own channel's.** Posed as a branch, a server's LAN listener binds 45781 and
## its internet one 45782, and nothing of the release channel's; posed as the
## release channel, a second server beside it binds 45771 and 45772. With both
## up on one address, a guest on each channel dials its own channel's LAN port
## and is in with its own server and never the other; and a call by each
## channel's invite -- minted with `--reach` naming no port -- is in at its own
## internet listener. **K4:** the LAN listener, closed under its guest, opens
## again on its channel's port, and a phone hosts on it too.
func _channel_sockets() -> void:
	# One book for both servers: one key, and an invite minted on each channel
	# to a --reach with no port.
	Channel.posing = "dev"
	var dev_minted: Array = InviteBook.run(PackedStringArray(["--reach=127.0.0.1",
		"--invite=dev-friend"]), CHANNEL_ROOT)
	Channel.posing = ""
	var live_minted: Array = InviteBook.run(PackedStringArray(["--reach=127.0.0.1",
		"--invite=live-friend"]), CHANNEL_ROOT)
	var identity := InviteBook.load_identity(CHANNEL_ROOT)
	var table := InviteBook.table(CHANNEL_ROOT)
	var dev_invite := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("dev-friend", CHANNEL_ROOT)))
	var live_invite := Invite.parse(FileAccess.get_file_as_string(
		InviteBook.line_path("live-friend", CHANNEL_ROOT)))
	var held_before := _channel_holds()
	# The dev server alone first: its pair held, and none of the release's.
	Channel.posing = "dev"
	var dev_host: Node = await _session("ChannelDevHost")
	var dev_up: bool = dev_host.host(NetSession.GUESTS_MAX) \
		and dev_host.listen_internet(identity[0], identity[1])
	dev_host.set_invites(table)
	var dev_alone := _channel_holds()
	Channel.posing = ""
	var live_host: Node = await _session("ChannelLiveHost")
	var live_up: bool = live_host.host(NetSession.GUESTS_MAX) \
		and live_host.listen_internet(identity[0], identity[1])
	live_host.set_invites(table)
	var both := _channel_holds()
	_says(int(dev_minted[0]) == 0 and int(live_minted[0]) == 0 and identity.size() == 3
			and held_before == [false, false, false, false] and dev_up and live_up
			and dev_alone == [false, false, true, true] and both == [true, true, true, true],
		"channel K2: posed as a branch, a server's LAN listener binds %d and its internet"
		% BRANCH_PAIR[0] + " one %d, and nothing of the release channel's; posed as the"
		% BRANCH_PAIR[1] + " release channel, a server beside it binds %d and %d -- held"
		% RELEASE_PAIR + " %s, then %s" % [str(dev_alone), str(both)])
	# A guest on each channel, calling the one address.
	Channel.posing = "dev"
	var dev_guest: Node = await _limits_guest("ChannelDevGuest")
	var dev_dialled := _channel_dialled(dev_guest)
	var after_dev := [(dev_host.guests() as Array).size(), (live_host.guests() as Array).size()]
	Channel.posing = ""
	var live_guest: Node = await _limits_guest("ChannelLiveGuest")
	var live_dialled := _channel_dialled(live_guest)
	var after_live := [(dev_host.guests() as Array).size(),
		(live_host.guests() as Array).size()]
	# By invite, each at its own channel's internet listener.
	Channel.posing = "dev"
	var dev_far: Node = await _session("ChannelDevFar")
	await _invites_call(dev_far, dev_invite)
	Channel.posing = ""
	var live_far: Node = await _session("ChannelLiveFar")
	await _invites_call(live_far, live_invite)
	var far_in := [str(dev_host.label_of(dev_far.my_id())),
		str(live_host.label_of(live_far.my_id()))]
	var together := int(dev_guest.link) == NetSession.Link.TOGETHER \
		and int(live_guest.link) == NetSession.Link.TOGETHER \
		and int(dev_far.link) == NetSession.Link.TOGETHER \
		and int(live_far.link) == NetSession.Link.TOGETHER
	_says(together and dev_dialled == BRANCH_PAIR[0] and after_dev == [1, 0]
			and live_dialled == RELEASE_PAIR[0] and after_live == [1, 1]
			and int(dev_invite["port"]) == BRANCH_PAIR[1]
			and int(live_invite["port"]) == RELEASE_PAIR[1]
			and far_in == ["dev-friend", "live-friend"],
		"channel K3: on one address, a dev guest dials %d and is in with the dev server"
		% dev_dialled + " alone, and a release guest dials %d and is in with the live one" % (
			live_dialled) + " alone; each channel's invite, minted to a --reach with no port,"
		+ " calls %d and %d and is in at its own server's internet listener -- %s" % [
			int(dev_invite["port"]), int(live_invite["port"]), str(far_in)])
	# The LAN listener closed under its guest, as 4.7 closes one whose send
	# failed, with its port held by something else that moment -- as H4 holds
	# the release channel's: it says so, naming its own channel's port, and
	# once the port is free it opens on it again, and the guest is back.
	Channel.posing = "dev"
	var from := _channel_catcher.lines.size()
	(dev_host.get("_peer") as ENetMultiplayerPeer).close()
	var squatter := PacketPeerUDP.new()
	var squatted := squatter.bind(BRANCH_PAIR[0]) == OK
	await _limits_until(func() -> bool:
		return int(dev_host.gate_counts["lan_closed"]) >= 1 \
			and int(dev_guest.link) != NetSession.Link.TOGETHER \
			and _count(_channel_catcher.lines.slice(from), "could not open again") >= 1)
	squatter.close()
	await _limits_until(func() -> bool:
		return float(dev_host.get("_lan_down_since")) < 0.0, 4.0)
	var taken_said := _count(_channel_catcher.lines.slice(from),
		"[net] the LAN listener could not open again: port %d is taken" % BRANCH_PAIR[0])
	var reopened := float(dev_host.get("_lan_down_since")) < 0.0 \
		and _channel_held(BRANCH_PAIR[0])
	dev_guest.join("127.0.0.1")
	await _until_link(dev_guest, NetSession.Link.TOGETHER)
	var back := int(dev_guest.link) == NetSession.Link.TOGETHER \
		and _channel_dialled(dev_guest) == BRANCH_PAIR[0]
	await _limits_close([dev_host, dev_guest, dev_far])
	# A phone, which hosts on the LAN's port alone.
	var phone: Node = await _session("ChannelDevPhone")
	var phone_up: bool = phone.host(1)
	var phone_holds := _channel_holds()
	var friend: Node = await _limits_guest("ChannelDevFriend")
	var friend_in := int(friend.link) == NetSession.Link.TOGETHER \
		and _channel_dialled(friend) == BRANCH_PAIR[0] and (phone.guests() as Array).size() == 1
	# A session's close() frees it as well.
	await _limits_close([phone, friend, live_host, live_guest, live_far])
	Channel.posing = null
	var held_after := _channel_holds()
	_says(squatted and taken_said == 1 and reopened and back and phone_up
			and phone_holds == [true, true, true, false] and friend_in
			and held_after == [false, false, false, false],
		"channel K4: a dev server's LAN listener, closed under its guest with %d held" % (
			BRANCH_PAIR[0]) + " elsewhere, says that port is taken, opens again on it once it"
		+ " is free, and the guest is back; a dev phone hosts on %d alone, beside"
		% BRANCH_PAIR[0] + " the live server's %d, and its friend dials it there; and" % (
			RELEASE_PAIR[0]) + " closed, every port is let go")


## The `[server]` and `[upnp]` lines printed since [param from].
func _channel_lines(from: int) -> Array[String]:
	var out: Array[String] = []
	for line: String in _channel_catcher.lines.slice(from):
		if line.begins_with("[server] ") or line.begins_with("[upnp] "):
			out.append(line.strip_edges())
	return out


## **K5 and K6: the server scene, as [param branch]'s build** -- K5 a dev
## build, K6 the release channel's. Its LAN listener binds its channel's port
## and not the other channel's; its READY, join and listening lines name that
## port -- a dev build's saying whose build it is, the release channel's word
## for word as they always were. With an invite in its book, minted to a
## `--reach` with no port, and its internet port held by something else as it
## starts, its `internet:` line says that port is taken; free, the next says
## it listens there, for friends calling that port. Its forward asks the
## router for its channel's internet port, never the LAN's, under its
## channel's name; and its clean stop takes that forward off.
func _channel_server(branch: String) -> void:
	Channel.posing = branch
	var dev := not branch.is_empty()
	var lan: int = BRANCH_PAIR[0] if dev else RELEASE_PAIR[0]
	var net: int = BRANCH_PAIR[1] if dev else RELEASE_PAIR[1]
	var other_lan: int = RELEASE_PAIR[0] if dev else BRANCH_PAIR[0]
	_invites_wipe(CHANNEL_SERVER_ROOT)
	var minted: Array = InviteBook.run(PackedStringArray(["--reach=203.0.113.7",
		"--invite=channel"]), CHANNEL_SERVER_ROOT)
	var identity := InviteBook.load_identity(CHANNEL_SERVER_ROOT)
	var certificate := InviteBook.fingerprint(identity[2]) if identity.size() == 3 else "?"
	var squatter := PacketPeerUDP.new()
	var squatted := squatter.bind(net) == OK
	var router := UpnpRouter.new()
	var from := _channel_catcher.lines.size()
	var server: Node = await _upnp_server(router, CHANNEL_SERVER_ROOT, PackedStringArray())
	var forward: Node = server.call("forward")
	var up := await _limits_until(func() -> bool:
		return forward != null and bool(forward.holds()), 3.0)
	squatter.close()
	var listening := await _limits_until(func() -> bool:
		return bool(server.session().internet_listening()), 3.0)
	var held := [_channel_held(lan), _channel_held(other_lan)]
	server.call("_announce", false)
	var address := str(server.session().address)
	var code: String = DedicatedServer.clock_code(address)
	var lines := _channel_lines(from)
	var ready_line := "[server] READY -- listening on %s port %d/udp, code %s" % [address, lan,
		code] + (" -- a dev build: only the dev app finds it" if dev else "")
	var join_line := ("[server] to join: a phone on this wi-fi (%sx) opens within earshot,"
		% Lan.prefix_of(address) + (" in the dev app," if dev else "") + " taps answer, and"
		+ " taps the ring at %s, in that order. LAN only: do not forward this port." % code)
	var listening_line := ("[server] listening on %s port %d/udp, code %s -- 0 of %d guests, 0 in"
		% [address, lan, code, FoodField.GUESTS_MAX] + " the water -- internet: 1 invite -- upnp:"
		+ " forwarded" + (" -- a dev build" if dev else ""))
	var taken_line := ("[server] internet: not listening for the internet: there are invites, but"
		+ " port %d/udp is taken, or not free yet. Trying again in %d s." % [net,
			roundi(UPNP_POLL)])
	var internet_line := ("[server] internet: listening on port %d/udp for 1 invite (channel),"
		% net + " certificate %s. Friends call 203.0.113.7:%d, which must reach this" % [
			certificate, net] + " machine's %d/udp: the [upnp] lines say whether the router" % net
		+ " forwards it, and if not, forward it by hand -- the one port to forward"
		+ " (docs/server.md §9.3).")
	var adds := router.calls("add")
	var avoided: PackedInt32Array = router.calls("discover")[0][2] \
		if not router.calls("discover").is_empty() else PackedInt32Array()
	var description := "Biogenic server (dev)" if dev else "Biogenic server"
	var asked := adds.size() == 1 and int(adds[0][1]) == net and str(adds[0][2]) == "UDP" \
		and str(adds[0][3]) == description and int(adds[0][4]) == PortForward.LEASE
	var joins := Lan.octet_of(address) < 0 or lines.has(join_line)
	var never: PackedInt32Array = forward.call("never")
	var to := "[upnp] forwarded UDP %d on the router to this machine," % net
	var forwarded := false
	for line: String in lines:
		forwarded = forwarded or line.begins_with(to)
	var line_from := _channel_catcher.lines.size()
	server.call("shut_down")
	var down := await _limits_until(func() -> bool:
		return router.calls("delete").size() == 1 and bool(forward.is_stopped()), 3.0)
	var at_stop := _channel_lines(line_from)
	var removed := router.calls("delete")
	server.queue_free()
	await _wait(0.3)
	Channel.posing = null
	_says(up >= 0.0 and held == [true, false] and lines.has(ready_line) and joins
			and int(minted[0]) == 0 and squatted and lines.has(taken_line) and listening >= 0.0
			and lines.has(internet_line) and lines.has(listening_line) and asked and forwarded
			and never == PackedInt32Array([lan]) and avoided.has(net) and avoided.has(lan)
			and lines.has("[upnp] looking for the router, to forward UDP %d to this" % net
				+ " machine for as long as the server runs -- nothing answers there without"
				+ " an invite")
			and down >= 0.0 and removed.size() == 1 and int(removed[0][1]) == net
			and at_stop.has("[upnp] took the forward of UDP %d off the router" % net)
			and router.on_main == 0,
		"channel %s: %s server listens on %d and not %d, says so in its READY, join and" % [
			"K5" if dev else "K6", "a dev" if dev else "the release channel's", lan, other_lan]
		+ " listening lines%s; with an invite, its internet line says %d is taken while" % [
			" -- a dev build's own" if dev else " -- word for word as ever", net]
		+ " held and then that it listens there; it asks the router for UDP %d as '%s'," % [net,
			description] + " never %d, and takes that forward off at its stop" % lan)


## **K7: every sentence that names a port, or the service's account, names its
## channel's -- and on the release channel, word for word what it said before
## there were two.** `--reach` with no port, and a `reach.cfg` a hand made with
## none, mean the internet's port; `--reach` and `--invite` refused say it; the
## advice for the router, the UPnP switch and `--invites` name it; a call from
## outside the house at the LAN's door is sent to it; the earshot screen shows
## the LAN's; the forward's line and its name on the router are the channel's;
## and the note a job run as root gives, and the refusal when a job run as root
## cannot read who owns the book, name the channel's service account.
func _channel_words() -> void:
	var release := {
		"reach": "45772,45772,50000",
		"reach_job": "friends will call 203.0.113.7:45772. The server asks your router to"
			+ " forward UDP 45772 to it by itself, by UPnP, and its [upnp] lines say whether the"
			+ " router did; if not, forward UDP 45772 on your router to this machine's port"
			+ " 45772/udp, and nothing else.",
		"reach_refused": "--reach: a port is a number from 1 to 65535. For example"
			+ " --reach=203.0.113.7 or --reach=pond.example.net:45772 (both placeholders).",
		"mint_refused": "--invite: friends need an address to call first. Set it with"
			+ " --reach=<your public address or name>[:<port>] -- where your router answers,"
			+ " and the port it forwards to this machine's 45772/udp.",
		"handmade": "45772",
		"advice_off": "Forward UDP 45772 on your router to this machine's port 45772/udp, and"
			+ " nothing else -- UPnP is off here (--no-upnp).",
		"advice_other": "Forward UDP 50000 on your router to this machine's port 45772/udp,"
			+ " and nothing else: the server's own forward, by UPnP, is of 45772, not of"
			+ " 50000.",
		"switch_on": "upnp: on -- the server asks the router to forward 45772/udp to it"
			+ " (--no-upnp turns that off)",
		"switch_off": "upnp: off -- forward 45772/udp to this machine by hand (--upnp turns it"
			+ " back on)",
		"set_off": "upnp: off, remembered -- the server asks the router for nothing. For"
			+ " friends outside the house, forward UDP 45772 to this machine by hand"
			+ " (docs/server.md §9.3); --upnp turns it back on.",
		"set_on": "upnp: on, remembered -- the server asks the router to forward UDP 45772 to"
			+ " this machine for as long as it runs, and its [upnp] lines say whether the"
			+ " router did (docs/server.md §9.3).",
		"listing": "friends call 203.0.113.7:45772; the server listens on 45772/udp for them.",
		"door": "not on this network -- a call from outside needs an invite, on port 45772",
		"mapped": "forwarded UDP 45772 on the router to this machine, 192.0.2.12:45772, for an"
			+ " hour at a time -- renewed every 30 minutes while the server runs, and taken off"
			+ " when it stops",
		"receipt": "%s · 45771" % Lan.local_address() if not Lan.local_address().is_empty()
			else "no network here",
		"account": "biogenic",
		"description": "Biogenic server",
		"tag": "|",
		"root_note": "note: this runs as root, so it keeps root's own book, in %s, which the"
			% ProjectSettings.globalize_path(CHANNEL_WORDS_ROOT).trim_suffix("/") + " service"
			+ " never reads. For the service's, run the job as its user: runuser -u biogenic --"
			+ " env HOME=/var/lib/biogenic /opt/biogenic/biogenic-server.x86_64 --headless --"
			+ " <job> (docs/server.md §9.1)",
		"ownership": "refused: this runs as root but could not read who owns the invite files,"
			+ " so it will not write what the service user might not read back. Run the job as"
			+ " that user: runuser -u biogenic -- env HOME=/h /x --headless -- --invites (or"
			+ " sudo -u biogenic, the same way; docs/server.md §9.1)",
	}
	# A dev build's: the same sentences on the other pair, and its own names.
	var branch := {}
	for key: String in release:
		branch[key] = str(release[key]).replace("45772", "45782").replace("45771", "45781")
	branch["account"] = "biogenic-dev"
	branch["root_note"] = str(release["root_note"]).replace("biogenic -- env HOME=/var/lib/biogenic"
		+ " /opt/biogenic/", "biogenic-dev -- env HOME=/var/lib/biogenic-dev /opt/biogenic-dev/")
	branch["ownership"] = str(release["ownership"]).replace("runuser -u biogenic --",
		"runuser -u biogenic-dev --").replace("sudo -u biogenic,", "sudo -u biogenic-dev,")
	branch["description"] = "Biogenic server (dev)"
	branch["tag"] = " -- a dev build: only the dev app finds it| -- a dev build"
	var wrong: Array[String] = []
	for posed: String in ["", "dev"]:
		Channel.posing = posed
		var said := _channel_sentences()
		var want: Dictionary = branch if not posed.is_empty() else release
		for key: String in want:
			if str(said.get(key, "")) != str(want[key]):
				wrong.append("%s %s: '%s'" % ["dev" if not posed.is_empty() else "release", key,
					said.get(key, "")])
	Channel.posing = null
	_says(wrong.is_empty(),
		"channel K7: %d sentences that name a port or the service's account name their" % (
			release.size()) + " channel's, and the release channel's are word for word what"
		+ " they were before there were two" + ("" if wrong.is_empty() else " -- NOT: "
			+ "; ".join(wrong)))


## Every sentence K7 holds, as this channel says it, from the game's own code.
func _channel_sentences() -> Dictionary:
	_invites_wipe(CHANNEL_WORDS_ROOT)
	var said := {}
	said["reach"] = "%d,%d,%d" % [int(Invite.parse_reach("203.0.113.7")["port"]),
		int(Invite.parse_reach("2001:db8::7")["port"]),
		int(Invite.parse_reach("pond.example.net:50000")["port"])]
	said["mint_refused"] = str((InviteBook.mint("sam", CHANNEL_WORDS_ROOT)[1] as Array)[0])
	said["reach_refused"] = str((InviteBook.set_reach("203.0.113.7:0", CHANNEL_WORDS_ROOT)[1]
		as Array)[0])
	said["reach_job"] = str((InviteBook.set_reach("203.0.113.7", CHANNEL_WORDS_ROOT)[1]
		as Array)[0])
	said["listing"] = str((InviteBook.listing(CHANNEL_WORDS_ROOT)[1] as Array)[0])
	said["set_off"] = str((InviteBook.set_upnp(false, CHANNEL_WORDS_ROOT)[1] as Array)[0])
	said["set_on"] = str((InviteBook.set_upnp(true, CHANNEL_WORDS_ROOT)[1] as Array)[0])
	# A reach.cfg a hand made, with an address and no port.
	var handmade := ConfigFile.new()
	handmade.set_value("reach", "address", "203.0.113.7")
	Invite.write_private(str(InviteBook.paths(CHANNEL_WORDS_ROOT)["reach"]),
		handmade.encode_to_text().to_utf8_buffer())
	said["handmade"] = str(int(InviteBook.reach(CHANNEL_WORDS_ROOT).get("port", -1)))
	_invites_wipe(CHANNEL_WORDS_ROOT)
	said["advice_off"] = InviteBook.forward_advice(Invite.channel_port(), 0)
	said["advice_other"] = InviteBook.forward_advice(50000, 1)
	said["switch_on"] = InviteBook.upnp_said(1, 0)
	said["switch_off"] = InviteBook.upnp_said(0, 0)
	# The LAN's door, as a server's: a call from outside the house.
	var door: Node = NetSession.new()
	door.set("address", "192.0.2.12")
	door.set("guests_max", NetSession.GUESTS_MAX)
	said["door"] = str((door.call("_admit", "203.0.113.9", NetSession.VIA_LAN) as Array)[1])
	door.free()
	said["mapped"] = DedicatedServer.upnp_said(&"mapped", {"port": Invite.channel_port(),
		"protocol": "UDP", "internal": "192.0.2.12", "lease": PortForward.LEASE})
	var screen: Node = Earshot.new()
	said["receipt"] = str(screen.call("_here_says"))
	screen.free()
	said["account"] = InviteBook.service_account()
	said["root_note"] = InviteBook.root_note(CHANNEL_WORDS_ROOT)
	said["ownership"] = InviteBook.ownership_refusal(0, {}, PackedStringArray(["--invites"]),
		"/x", "/h", false)
	said["description"] = DedicatedServer.upnp_description()
	said["tag"] = DedicatedServer.channel_said(true) + "|" + DedicatedServer.channel_said(false)
	return said


## **K8: a job reads its own server's command line, and never the other
## channel's.** The live server and the dev server run the same file name from
## two directories, so the server a job asks about is the one started from its
## own path: under a stand-in `/proc`, a live service with neither switch and a
## dev service with `--no-upnp` -- the live job sees neither, and the dev job
## its own `--no-upnp`. One started by another path to the same file -- a
## symlinked directory -- is known by the `exe` link `/proc` keeps, the same
## after its build was replaced, when the link reads ` (deleted)`; and one
## started by a relative path is known by its name.
func _channel_own_server() -> void:
	var live := "/opt/biogenic/biogenic-server.x86_64"
	var dev := "/opt/biogenic-dev/biogenic-server.x86_64"
	var write := func(pid: String, argv: Array) -> void:
		DirAccess.make_dir_recursive_absolute(CHANNEL_PROC_ROOT.path_join(pid))
		var bytes := PackedByteArray()
		for arg: String in argv:
			bytes.append_array(arg.to_utf8_buffer())
			bytes.append(0)
		var file := FileAccess.open(CHANNEL_PROC_ROOT.path_join(pid).path_join("cmdline"),
			FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	_channel_proc_wipe()
	write.call("201", [live, "--headless", "--", "--stop-file=/run/biogenic/stop"])
	write.call("202", [dev, "--headless", "--", "--stop-file=/run/biogenic-dev/stop",
		"--no-upnp"])
	var live_sees := InviteBook.running_upnp_override(CHANNEL_PROC_ROOT, live, 999)
	var dev_sees := InviteBook.running_upnp_override(CHANNEL_PROC_ROOT, dev, 999)
	_channel_proc_wipe()
	write.call("203", ["./biogenic-server.x86_64", "--headless", "--", "--no-update",
		"--upnp"])
	var by_name := InviteBook.running_upnp_override(CHANNEL_PROC_ROOT, dev, 999)
	_channel_proc_wipe()
	# Started through a symlinked directory: the same file, by its link.
	var linked := "/srv/pond/biogenic-server.x86_64"
	write.call("204", [linked, "--headless", "--", "--stop-file=/run/biogenic/stop",
		"--no-upnp"])
	var linking := DirAccess.open(CHANNEL_PROC_ROOT.path_join("204"))
	var link_made := linking != null and linking.create_link(live, "exe") == OK
	var by_link := InviteBook.running_upnp_override(CHANNEL_PROC_ROOT, live, 999)
	var dev_by_link := InviteBook.running_upnp_override(CHANNEL_PROC_ROOT, dev, 999)
	_channel_proc_wipe()
	write.call("205", [linked, "--headless", "--", "--no-update", "--upnp"])
	linking = DirAccess.open(CHANNEL_PROC_ROOT.path_join("205"))
	link_made = link_made and linking != null \
		and linking.create_link(live + " (deleted)", "exe") == OK
	var by_deleted := InviteBook.running_upnp_override(CHANNEL_PROC_ROOT, live, 999)
	_channel_proc_wipe()
	_says(live_sees == 0 and dev_sees == -1 and by_name == 1 and link_made and by_link == -1
			and dev_by_link == -2 and by_deleted == 1,
		"channel K8: beside a dev server run with --no-upnp, a live server's job sees its own"
		+ " server with neither (%d), the dev server's job its --no-upnp (%d); one started" % [
			live_sees, dev_sees] + " through a symlinked directory is known by its /proc link"
		+ " (%d, and %d to the dev job), and after its build was replaced (%d); one" % [
			by_link, dev_by_link, by_deleted] + " started by a relative path is known by its"
		+ " name (%d)" % by_name)


func _channel_proc_wipe() -> void:
	if not DirAccess.dir_exists_absolute(CHANNEL_PROC_ROOT):
		return
	for pid: String in DirAccess.get_directories_at(CHANNEL_PROC_ROOT):
		var dir := CHANNEL_PROC_ROOT.path_join(pid)
		# The `exe` link first, by name: one that leads nowhere may not list.
		DirAccess.remove_absolute(dir.path_join("exe"))
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	DirAccess.remove_absolute(CHANNEL_PROC_ROOT)
