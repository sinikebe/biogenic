extends Node
## **The house's network, taken from under a host** (issue #105,
## docs/design/net-hardening.md part G): a send that really fails, where the
## probe's `invites` H1-H4 close the LAN listener by hand, as 4.7's
## `ENetMultiplayerPeer.poll()` does after one. A dedicated host at
## [constant AT] with a guest in; the address goes; the host's next send to the
## guest -- ENet's own ping, within half a second -- fails, and ENet closes the
## listener. The host must say so, let the guest go and listen again at once;
## the address comes back, and a new guest is in.
##
## **Run it** in a network namespace of its own, beside something with root
## there that takes the address away when this prints `ready` and gives it
## back when it prints `dropped` -- as CI's "Take the network from under a
## host" step does, and by hand:
##
##   sudo unshare --net -- bash -c 'ip link set lo up &&
##       ip addr add 10.77.0.5/24 dev lo &&
##       (godot --headless --path . res://tools/net_drop.tscn > drop.log 2>&1 &
##        until grep -q "net-drop\] ready" drop.log; do sleep 0.1; done
##        ip addr del 10.77.0.5/24 dev lo
##        until grep -q "net-drop\] dropped" drop.log; do sleep 0.1; done
##        ip addr add 10.77.0.5/24 dev lo; wait); cat drop.log'
##
## It will not run where any interface but loopback is up: it binds the real
## LAN port. Prints `[net-drop] PASS <what>` per check and `ALL PASS` only if
## none failed. Excluded from export (`tools/*`), so it never ships.

const NetSession := preload("res://game/net/net_session.gd")
## The address the host takes and loses: a private one on loopback, in a
## namespace nothing else is in -- the one CI gives the fuzzer too.
const AT := "10.77.0.5"
## How long any one wait may take before it is a failure.
const WAIT := 10.0

var _failed := 0


func _ready() -> void:
	var names: PackedStringArray = []
	for each: Dictionary in IP.get_local_interfaces():
		names.append(str(each.get("name", "?")))
	if names != PackedStringArray(["lo"]):
		_says(false, "alone on loopback: this binds the real LAN port, and runs only in a"
			+ " network namespace of its own -- here are %s" % ", ".join(names))
		_end()
		return
	var host: Node = await _session("DropHost")
	var hosted: bool = host.host(NetSession.GUESTS_MAX)
	var guest: Node = await _session("DropGuest")
	guest.join(AT)
	await _until(func() -> bool: return int(guest.link) == NetSession.Link.TOGETHER)
	var guest_id: int = guest.my_id()
	var in_water: bool = hosted and str(host.address) == AT \
		and host.guests() == [guest_id]
	_says(in_water, "a dedicated host at %s, and a guest in the water" % str(host.address))
	if not in_water:
		_end()
		return
	print("[net-drop] ready")
	await _until(func() -> bool: return not IP.get_local_addresses().has(AT))
	var gone_at := _now()
	var closed := await _until(func() -> bool:
		return int(host.gate_counts["lan_closed"]) >= 1)
	var enet: ENetMultiplayerPeer = host.get("_peer")
	_says(closed >= 0.0 and int(host.gate_counts["lan_closed"]) == 1
			and (host.guests() as Array).is_empty() and int(host.via_of(guest_id)) == -1
			and int(host.link) == NetSession.Link.LISTENING and enet != null
			and enet.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
		"the address gone, the LAN listener closed by itself %.2f s later -- a send that"
		% (_now() - gone_at) + " failed -- and the host let its guest go, listens again,"
		+ " and is open")
	print("[net-drop] dropped")
	await _until(func() -> bool: return IP.get_local_addresses().has(AT))
	var again: Node = await _session("DropAgain")
	again.join(AT)
	await _until(func() -> bool: return int(again.link) == NetSession.Link.TOGETHER)
	_says(int(again.link) == NetSession.Link.TOGETHER and (host.guests() as Array).size() == 1
			and int(host.gate_counts["lan_closed"]) == 1,
		"the address back, a new guest calls the same host and is in")
	host.close()
	guest.close()
	again.close()
	_end()


func _session(named: String) -> Node:
	var node: Node = NetSession.new()
	node.name = named
	get_tree().root.add_child.call_deferred(node)
	await node.ready
	return node


## Frames until [param done] says so, or [constant WAIT] passes: the seconds it
## took, or -1.
func _until(done: Callable) -> float:
	var from := _now()
	while not done.call():
		if _now() - from >= WAIT:
			return -1.0
		await get_tree().process_frame
	return _now() - from


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _says(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("[net-drop] %s %s" % ["PASS" if ok else "FAIL", what])


func _end() -> void:
	print("[net-drop] ALL PASS" if _failed == 0 else "[net-drop] %d failed" % _failed)
	get_tree().quit()
