extends RefCounted
## The join, with no text input anywhere: an address carried by four taps on a
## ring of bearings.
##
## **Why not a field to type an address into.** There is no `LineEdit` and no
## `TextEdit` in this project, and `addons/launcher/theme/launcher_theme.tres`
## -- which every screen here is themed with, and which is template-owned and
## may not be edited -- styles exactly `Button`, `Label`, `PanelContainer` and
## `ProgressBar`. A text field would fall back to Godot's default theme inside a
## scene that has none of it, and on Android it would raise a soft keyboard over
## a landscape-locked canvas that has never had one over it. multiplayer.md §4.2
## prices that out and reaches the same answer: **a tap-only pictorial code**.
##
## **Why bearings.** They are the membrane's entire vocabulary. The player has
## spent the whole game reading marks around a ring; the code is the same ring,
## and it is drawn in the same violet the `ampulla` wears, because that is what
## it is -- one cell saying *here* in the only language the fiction has.
##
## **Why four taps.** Twelve bearings, three taps, base twelve: 12^3 = 1728,
## which covers a final octet's 0-255 with room to spare. The fourth tap is a
## check digit. It is not politeness -- a mis-tap that reaches the transport
## costs a two-second connection timeout and a screen that says nothing useful,
## and the check digit turns that into instant, local, obvious feedback.
##
## **What the check digit is deliberately not.** It does not mix in the protocol
## version. It would be nearly free, and it would be a trap: two builds that
## cannot talk would report *every* code as a mis-tap, forever, and the player
## would retype a correct code until they gave up. Version skew gets its own
## refusal and its own sentence. See wire.gd.
##
## **The /24 is an assumption, and Godot cannot check it.**
## `IP.get_local_interfaces()` returns addresses with no netmask -- verified in
## this container, which reports `{name: eth0, addresses: [192.0.2.2]}` and
## nothing else. So the guest assumes its own first three octets are the host's
## too. On a home Wi-Fi that is nearly always true, and where it is false this
## cannot reach and must say so rather than hang. Everything here fails to an
## empty string or -1; nothing throws.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## Twelve, because twelve bearings is a clock face and a clock face is the one
## ring layout every player can already read. Thirty degrees of arc apiece.
const BEARINGS := 12
## Three carry the address, the fourth checks them.
const DIGITS := 4
const ADDRESS_DIGITS := 3
## 12^3.
const SPAN := 1728

## The port, fixed, so that nothing else has to be tapped. Unregistered, high,
## and the same on both ends. Needs no manifest permission: the Android preset
## already has `permissions/internet`, which is what a socket costs.
const PORT := 45771

## **A scramble, not an encoding.** Straight base-twelve would put nearly every
## real address in the same corner of the ring: a /24 host is 1-254, so the
## first tap would be one of two bearings out of twelve and the code would be
## visibly, uselessly lopsided. Multiplying by a constant coprime to 1728 is a
## bijection that spreads the 254 live addresses over all twelve bearings at
## every position.
##
## 595 = 5 x 7 x 17, and 1728 = 2^6 x 3^3, so they share no factor and the map
## is one-to-one. Verified exhaustively by tools/net_probe.gd over all 254.
const SCRAMBLE := 595

## Check-digit weights, one per address digit. All three are coprime to twelve,
## which is the property that matters: a single mis-tapped digit changes the
## check by `weight * error mod 12`, and a weight coprime to 12 is invertible
## mod 12, so that is never zero. **Every single-digit mis-tap is caught.**
## Adjacent transposition is not fully covered and is not worth a fifth tap;
## net_probe.gd measures what fraction escapes.
const CHECK_WEIGHTS: Array[int] = [1, 5, 7]

## Loopback, and the link-local block a device falls back to when DHCP never
## answered. Neither is a LAN anybody is on together.
const LOOPBACK := "127."
const LINK_LOCAL := "169.254."


## This device's own address on whatever it is attached to, or "" if it is not
## attached to anything.
##
## **Permissive on purpose.** The obvious filter is "RFC 1918 only", and it is
## wrong twice: a carrier-grade-NAT Wi-Fi (100.64/10) is a real home network,
## and this very container answers 192.0.2.2, which is documentation space. The
## two addresses that are never a shared LAN are loopback and link-local, so
## those are the two that are excluded. Private ranges are still *preferred*,
## because a phone with a VPN up has two and the Wi-Fi one is the right answer.
static func local_address() -> String:
	var best := ""
	for iface: Dictionary in IP.get_local_interfaces():
		for address: String in PackedStringArray(iface.get("addresses",
				PackedStringArray())):
			if not _is_ipv4(address):
				continue
			if address.begins_with(LOOPBACK) or address.begins_with(LINK_LOCAL):
				continue
			if _is_private(address):
				return address
			if best.is_empty():
				best = address
	return best


## Everything before the final octet, with the dot: "192.168.1." from
## "192.168.1.37". "" if that is not an address.
static func prefix_of(address: String) -> String:
	if not _is_ipv4(address):
		return ""
	var cut := address.rfind(".")
	return address.substr(0, cut + 1)


## The final octet, or -1. 0 and 255 are refused here rather than downstream:
## on a /24 they are the network and the broadcast address, so neither is a
## device and neither has a code.
static func octet_of(address: String) -> int:
	if not _is_ipv4(address):
		return -1
	var last := address.substr(address.rfind(".") + 1)
	if not last.is_valid_int():
		return -1
	var value := int(last)
	return value if value >= 1 and value <= 254 else -1


## The address the taps pointed at: this device's own /24, with the tapped
## octet on the end. "" if this device has no address to work from.
static func host_address(local: String, octet: int) -> String:
	var prefix := prefix_of(local)
	if prefix.is_empty() or octet < 1 or octet > 254:
		return ""
	return prefix + str(octet)


## The four taps for a final octet, most significant first, check digit last.
## Empty if the octet is not one a device can have.
static func code_for(octet: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if octet < 1 or octet > 254:
		return out
	var scrambled := (octet * SCRAMBLE) % SPAN
	out.append(scrambled / (BEARINGS * BEARINGS))
	out.append((scrambled / BEARINGS) % BEARINGS)
	out.append(scrambled % BEARINGS)
	out.append(check_digit(out))
	return out


## The check digit for however many address digits have been tapped so far --
## which is what lets the answering screen show the whole code forming rather
## than only validating at the end.
static func check_digit(digits: PackedInt32Array) -> int:
	var sum := 0
	for i in mini(digits.size(), ADDRESS_DIGITS):
		sum += CHECK_WEIGHTS[i] * digits[i]
	return sum % BEARINGS


## The octet four taps mean, or -1 if they do not mean one. Three ways to be
## -1, and all three are the same message to the player: that is not a code.
##
## Brute force over 254 candidates rather than a modular inverse. It runs once,
## on a tap, and a loop anyone can read beats a constant nobody can check.
static func octet_for(digits: PackedInt32Array) -> int:
	if digits.size() != DIGITS:
		return -1
	for digit: int in digits:
		if digit < 0 or digit >= BEARINGS:
			return -1
	if digits[ADDRESS_DIGITS] != check_digit(digits):
		return -1
	var scrambled := digits[0] * BEARINGS * BEARINGS + digits[1] * BEARINGS \
		+ digits[2]
	for octet in range(1, 255):
		if (octet * SCRAMBLE) % SPAN == scrambled:
			return octet
	return -1


## The bearing, in radians clockwise from straight up, that a digit is drawn
## at. Straight up is digit 0, the way a clock reads.
static func bearing_of(digit: int) -> float:
	return TAU * float(digit) / float(BEARINGS)


## Which digit a bearing lands on. Wraps, so a tap at 359 degrees is digit 0.
static func digit_at(bearing: float) -> int:
	var turns := wrapf(bearing, 0.0, TAU) / TAU
	return int(floorf(turns * float(BEARINGS) + 0.5)) % BEARINGS


static func _is_ipv4(address: String) -> bool:
	return address.count(".") == 3 and not address.contains(":")


static func _is_private(address: String) -> bool:
	if address.begins_with("192.168.") or address.begins_with("10."):
		return true
	if not address.begins_with("172."):
		return false
	var parts := address.split(".")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return false
	var second := int(parts[1])
	return second >= 16 and second <= 31
