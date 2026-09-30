extends Node
## **One port, forwarded on the home router for as long as it is wanted** --
## UPnP IGD through Godot's own `UPNP` (miniupnpc 2.3.3 in 4.7: IGD only, no
## NAT-PMP and no PCP), with every call to the router on a worker thread.
##
## **Why a thread.** Every router call blocks the thread that makes it. A search
## waits out its whole timeout when nothing answers -- measured on 4.7 here,
## 8.1 s at Godot's default of 2,000 ms, which miniupnpc spends four times, and
## 6.0 s on a phone (docs/design/multiplayer.md §3) -- and a router that has
## gone quiet holds a call for miniupnpc's 3 s socket timeouts. On the main
## thread that is a frozen pond. So each batch of calls -- a look, a renewal, a
## removal -- runs on a thread of its own, handed everything it needs and
## nothing of this node's, and the main thread only asks, once a frame, whether
## it is done. All the state is the main thread's.
##
## **Generic on purpose** (CLAUDE.md: keep mechanics generic). It knows a port,
## a protocol, a description for the router's list of forwards and a lease --
## nothing of what listens behind the port, or why. What happens is said as
## events ([signal reported]); the sentences are its owner's.
##
## Once [method start] is called, until [method stop]:
##   - **it looks for the router**: miniupnpc's SSDP search, four search types
##     of [member discover_timeout] each, and the first answer Godot takes as a
##     valid gateway -- or, when none is, why not;
##   - **it maps the port**, the same number outside and in, to this machine's
##     address as the router sees it, for [member lease] seconds -- or with no
##     time limit, when the router takes no other kind
##     (`OnlyPermanentLeasesSupported`, 725);
##   - **it renews it** at half the lease, and one with no time limit every
##     [member permanent_check], which puts it back after the router restarts;
##     a renewal the router does not answer is asked again by a fresh search,
##     since a router that restarted may answer somewhere else, and a renewal
##     that did not take is asked again sooner and sooner apart -- never further
##     apart than [member permanent_check];
##   - **it never takes a port the router forwards elsewhere**
##     (`ConflictInMappingEntry`, 718): it says so, leaves it, and looks again
##     later;
##   - **it takes the forward off** once stopped -- and only one it still holds,
##     asked for again first: Godot's delete asks nobody whose a forward is, so a
##     router that answers that another machine holds the port now (after a
##     restart, say) keeps that one, and one whose lease ran out is never asked
##     about at all;
##   - **it maps no port but the one it was made for, and none in its
##     never-list**, whatever is asked of it later: checked where each call is
##     made. Its search, too, listens on a port of its own drawn from 49152 to
##     65535 and never one of those -- a forward to that port would hand
##     miniupnpc, which takes any datagram there for a router's answer, to the
##     internet.
## A process killed in between leaves a timed forward to its lease.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## **Something happened**: [param event] names it, and [param facts] carries
## what a sentence about it needs -- always `port` and `protocol`. The events:
##   `no_upnp`        this build has no UPnP at all; nothing is ever asked;
##   `forbidden`      the port is not one this may map; nothing was asked;
##   `no_router`      nothing answered the search: `code`, and `network` false
##                    when this machine has no network to search;
##   `no_gateway`     `devices` answered and none forwards ports -- `why` is
##                    `not_igd`, or `offline` for a router that says it is not
##                    connected;
##   `cannot_help`    the router's own internet address is one the internet
##                    cannot call -- `wan` ("" when it would not say) and `kind`
##                    ([method kind_of]) -- so nothing was asked of it;
##   `mapped`         forwarded to `internal`, for `lease` seconds or
##                    `permanent`;
##   `address`        the router's public address, `address` of `kind`, and
##                    `held`, whether this forward is on the router: the first
##                    time it is heard, and whenever either changes;
##   `conflict`       the router forwards the port elsewhere already -- another
##                    machine, or a forward made by hand -- and `internal` is
##                    this machine;
##   `not_ours`       at a stop, the router answered that the port is another
##                    machine's now, so nothing was taken off;
##   `refused`        the router would not forward it: `code`, `name`;
##   `renew_failed`   a renewal did not take: `code`, `name`; the forward holds
##                    until `until` (Unix time) and is asked again in `retry` s;
##   `renewed`        a renewal took again, after one that did not;
##   `lapsed`         the lease ran out before a renewal took;
##   `removed`        taken off the router;
##   `remove_failed`  not taken off: `code`, `name`, `permanent` and `lease`.
## **A look that finds what the last one found says nothing**, so a router that
## stays away costs one line, not one a look.
signal reported(event: StringName, facts: Dictionary)
## The forward is down after [method stop]: taken off, or never held.
signal stopped

## **Godot's own numbers, mirrored** -- `UPNP.UPNPResult` and
## `UPNPDevice.IGDStatus` -- so that this file parses in a build without the
## UPnP module, where naming `UPNP` would stop every script that preloads it.
## tools/net_probe.gd holds each to the engine's on every run ([constant
## MIRRORED]).
const SUCCESS := 0
const CONFLICT := 13
const PERMANENT_ONLY := 15
const INVALID_RESPONSE := 21
const HTTP_ERROR := 23
const SOCKET_ERROR := 24
const NO_GATEWAY := 26
const NO_DEVICES := 27
const IGD_OK := 0
const IGD_DISCONNECTED := 5
const IGD_UNKNOWN_DEVICE := 6
## `[class, constant, the value above]`, for the check.
const MIRRORED := [
	["UPNP", "UPNP_RESULT_SUCCESS", SUCCESS],
	["UPNP", "UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING", CONFLICT],
	["UPNP", "UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED", PERMANENT_ONLY],
	["UPNP", "UPNP_RESULT_INVALID_RESPONSE", INVALID_RESPONSE],
	["UPNP", "UPNP_RESULT_HTTP_ERROR", HTTP_ERROR],
	["UPNP", "UPNP_RESULT_SOCKET_ERROR", SOCKET_ERROR],
	["UPNP", "UPNP_RESULT_NO_GATEWAY", NO_GATEWAY],
	["UPNP", "UPNP_RESULT_NO_DEVICES", NO_DEVICES],
	["UPNPDevice", "IGD_STATUS_OK", IGD_OK],
	["UPNPDevice", "IGD_STATUS_DISCONNECTED", IGD_DISCONNECTED],
	["UPNPDevice", "IGD_STATUS_UNKNOWN_DEVICE", IGD_UNKNOWN_DEVICE],
]

## **How long each search waits for an answer, in ms.** miniupnpc makes four --
## the gateway, its two connection services, and any root device -- one after
## the other, so a network with no router costs four of these: 8.1 s at
## Godot's default of 2,000, measured. 1,000 is SSDP's shortest MX, which a
## router must answer inside, and an answer to one search still counts while
## the next waits: miniupnpd was found and forwarded through in 1.2 s here. A
## router missed is found at the next look -- and a clean stop, which waits out
## a search under way, waits 4 s for one at most.
const DISCOVER_TIMEOUT := 1000
## **An hour a lease**, renewed at half of it: a forward outlives a crash by an
## hour at most, and a router that forgot it has it back within half of one.
const LEASE := 3600
const RENEW_AT := 0.5
## A forward with no time limit is put again this often, which a router that
## restarted and forgot it needs.
const PERMANENT_CHECK := 1800.0
## **A look that forwarded nothing is tried again** after this, then twice as
## long each time up to [constant LOOK_AGAIN_MAX]: a router plugged in, UPnP
## turned on, another machine's forward taken off.
const LOOK_AGAIN := 60.0
const LOOK_AGAIN_MAX := 600.0
## A renewal that did not take is asked again after this, then twice as long,
## and never past the end of the lease.
const RENEW_RETRY := 60.0
## **The longest the node waits, as it goes, for a call to the router.**
## miniupnpc's own timeouts bound a call that is working -- a search with no
## router takes 4 s, a router gone quiet holds one for 3 s to connect and 5 s a
## read -- but a device that answers as the router and then trickles bytes is
## bounded by nothing. A process that cannot exit is a server whose update never
## restarts it, so past this it ends itself at once, as a crash would: `systemd`
## starts it again, and a timed forward lapses with its lease.
const EXIT_WAIT_MS := 15000

## The port -- the same number outside and in -- and its protocol, fixed when
## this is made.
var port := 0
var protocol := "UDP"
## What the router's own list of forwards calls it.
var description := ""
## **What makes the calls**, on the worker thread: [Upnp], the router through
## Godot's `UPNP`, unless a test hands in one of its own with the same four
## methods.
var router: Object = null
## **Seams**, for a test that cannot wait an hour for a renewal.
var lease := LEASE
var discover_timeout := DISCOVER_TIMEOUT
var permanent_check := PERMANENT_CHECK
var look_again := LOOK_AGAIN
var look_again_max := LOOK_AGAIN_MAX
var renew_retry := RENEW_RETRY
var exit_wait_ms := EXIT_WAIT_MS

## The port it was made for, and those it may never map: what every call is
## checked against, where it is made.
var _given := 0
var _never := PackedInt32Array()
## On since [method start], off since [method stop].
var _want := false
var _thread: Thread = null
var _job: Job = null
## **A forward the router took from this, and has not lost**: the only kind
## ever taken off.
var _held := false
var _permanent := false
var _lease_end := 0.0
var _next_look := 0.0
var _next_renew := 0.0
var _look_wait := 0.0
var _renew_wait := 0.0
var _renew_failing := false
## **The router did not answer where it said it would**, so the next renewal
## searches for it again: one that restarted may answer at another address or
## port -- miniupnpd picks a new port at every start unless told one.
var _search_again := false
## What the last look found, so the same again says nothing.
var _last_look := ""
## This machine as the router sees it, and the router's own public address --
## and whether this forward was on the router when that was last said.
var _internal := ""
var _public := ""
var _public_held := false
var _stopped := true
## A port it may not map, or a build with no UPnP: it never asks again.
var _done := false


## A forward of [param for_port] over [param with_protocol], named
## [param what] on the router's list, never of a port in [param never], and
## asked through [param through] -- the real router when null.
func _init(for_port: int, what: String, never: PackedInt32Array = PackedInt32Array(),
		through: Object = null, with_protocol: String = "UDP") -> void:
	port = for_port
	_given = for_port
	_never = never.duplicate()
	description = what
	protocol = with_protocol
	router = through if through != null else Upnp.new()


## **Forward the port from now on**: look for the router at once, unless a look
## or a forward is already under way.
func start() -> void:
	_want = true
	_stopped = false
	if not _held:
		_next_look = minf(_next_look, _now())


## **Take the forward off, and look for nothing more.** A call under way is let
## finish; a forward it made is then taken off. [signal stopped] says when it
## is done.
func stop() -> void:
	_want = false


## True while [method start] holds: it is looking, or forwarding.
func is_on() -> bool:
	return _want


## True once a stop is done: nothing held, and nothing being asked.
func is_stopped() -> bool:
	return _stopped


## True while a forward is held: the router took it and it has not lapsed.
func holds() -> bool:
	return _held


## True while the forward held has no time limit.
func is_permanent() -> bool:
	return _held and _permanent


## This machine's address as the router sees it, once it has said.
func internal_address() -> String:
	return _internal


## The router's public address, once it has said.
func public_address() -> String:
	return _public


## True while a call to the router is under way.
func is_asking() -> bool:
	return _thread != null


## The ports it may never map.
func never() -> PackedInt32Array:
	return _never.duplicate()


## **May [param which] be mapped, by one made for [param given] and never
## [param never]?** Only its own port, 1 to 65535, and none of the never-list.
static func may_map(which: int, given: int, never: PackedInt32Array) -> bool:
	return Job.may_map(which, given, never)


## **What kind of internet address [param address] is**, for a router's word
## on its own: `public`; `private` -- RFC 1918, a router behind another router,
## most likely; `shared` -- 100.64.0.0/10, carrier-grade NAT; `unusable` --
## unspecified, loopback, link-local, multicast or reserved, which no internet
## calls; or `unknown` for "" and anything that is not IPv4.
static func kind_of(address: String) -> StringName:
	return Address.kind_of(address)


## The engine's name for a result [param code], in words: 13 is "conflict with
## other mapping". "code N" in a build with no UPnP.
static func result_name(code: int) -> String:
	if ClassDB.class_exists("UPNP"):
		for name: String in ClassDB.class_get_enum_constants("UPNP", "UPNPResult", true):
			if ClassDB.class_get_integer_constant("UPNP", name) == code:
				return name.trim_prefix("UPNP_RESULT_").to_lower().replace("_", " ")
	return "code %d" % code


func _process(_delta: float) -> void:
	_poll()


## **The node goes -- with its process, most often -- so whatever the router is
## being asked is waited out, and a forward still held is taken off.** Blocks,
## for [member exit_wait_ms] at most each time: a stop that waited for
## [signal stopped] has nothing left here, and one that did not has nothing
## better to do. Never detached: a thread still running when the engine shuts
## down could wake inside it -- so a call that outlasts the wait ends the
## process instead ([constant EXIT_WAIT_MS]).
func _exit_tree() -> void:
	_want = false
	_finish_call_within(exit_wait_ms)
	if _held and (_permanent or _now() < _lease_end):
		_ask(&"unmap")
		_finish_call_within(exit_wait_ms)
	_stopped = true


## [method _finish_call], but for [param ms] at most; past that the process
## ends at once, as a crash would, rather than wait on the router for ever.
func _finish_call_within(ms: int) -> void:
	if _thread == null:
		return
	var until := Time.get_ticks_msec() + ms
	while _thread.is_alive() and Time.get_ticks_msec() < until:
		OS.delay_msec(10)
	if _thread.is_alive():
		printerr("[upnp] a call to the router did not end in %d s; the process ends"
			% (ms / 1000) + " itself, and a timed forward lapses with its lease")
		OS.kill(OS.get_process_id())
		return
	_finish_call()


func _poll() -> void:
	if _thread != null:
		if _thread.is_alive():
			return
		_finish_call()
	var now := _now()
	if _held and not _permanent and now >= _lease_end:
		_held = false
		_renew_failing = false
		_search_again = false
		_last_look = ""
		_next_look = now
		if _want:
			_say(&"lapsed", {})
	if not _want:
		if _held:
			_ask(&"unmap")
			return
		if not _stopped:
			_stopped = true
			stopped.emit()
		return
	if _done:
		return
	if not _held:
		if now >= _next_look:
			_ask(&"look")
	elif now >= _next_renew:
		_ask(&"look" if _search_again else &"renew")


## One batch of calls, on a thread of its own. A removal names the port this
## was made for -- the only one it can have mapped -- whatever [member port]
## says since. It asks for no time limit only while it holds a forward that has
## none: a new look asks for the lease first, whatever the last router took.
## A search is handed the ports it must never listen on: this one's, and its
## never-list.
func _ask(kind: StringName) -> void:
	var avoid := PackedInt32Array([_given])
	avoid.append_array(_never)
	_job = Job.new(router, {"kind": kind, "port": _given if kind == &"unmap" else port,
		"given": _given, "never": _never, "protocol": protocol, "description": description,
		"lease": lease, "permanent": _permanent and _held, "timeout": discover_timeout,
		"avoid": avoid})
	_thread = Thread.new()
	_thread.start(_job.run)


## The call under way, waited for and taken in. Returns at once when there is
## none, and blocks when it is still running.
func _finish_call() -> void:
	if _thread == null:
		return
	var got: Variant = _thread.wait_to_finish()
	var kind := StringName(_job.ask["kind"])
	_thread = null
	_job = null
	_took(kind, got if got is Dictionary else {})


func _took(kind: StringName, got: Dictionary) -> void:
	if bool(got.get("forbidden", false)):
		# Nothing more is asked -- but a forward already held stays held, for a
		# stop to take off.
		_done = true
		_say(&"forbidden", {})
		return
	match kind:
		&"look":
			_looked(got)
		&"renew":
			_renewed(got)
		&"unmap":
			_unmapped(got)


func _looked(got: Dictionary) -> void:
	var now := _now()
	var status := StringName(got.get("status", &"none"))
	if status == &"no_upnp":
		_done = true
		_say(&"no_upnp", {})
		return
	if _held:
		# **A search standing in for a renewal** the router did not answer: the
		# forward taken again, wherever the router answers now, is a renewal
		# that took; anything else is one more that did not.
		if status == &"ok":
			_internal = str(got.get("internal", _internal))
		_renewed(got if status == &"ok" else {"code": NO_GATEWAY})
		return
	if status != &"ok":
		_look_later(now)
		if not _want:
			return
		match status:
			&"reserved":
				var wan := str(got.get("wan", ""))
				_say_once(&"cannot_help", {"wan": wan, "kind": kind_of(wan),
					"devices": int(got.get("devices", 0))}, "cannot_help %s" % wan)
			&"offline", &"not_igd":
				_say_once(&"no_gateway", {"why": status, "devices": int(got.get("devices", 0))},
					"no_gateway %s" % status)
			_:
				var networked := bool(got.get("network", true))
				_say_once(&"no_router", {"code": int(got.get("result", NO_DEVICES)),
					"network": networked}, "no_router %s" % networked)
		return
	_internal = str(got.get("internal", ""))
	var code := int(got.get("code", NO_GATEWAY))
	if code == SUCCESS:
		_hold(_asked_at(got, now), bool(got.get("permanent", false)))
		_look_wait = 0.0
		_last_look = ""
		_say(&"mapped", {"internal": _internal, "lease": lease, "permanent": _permanent})
	elif code == CONFLICT:
		_look_later(now)
		if _want:
			_say_once(&"conflict", {"internal": _internal}, "conflict %s" % _internal)
	else:
		_look_later(now)
		if _want:
			_say_once(&"refused", {"code": code, "name": result_name(code)}, "refused %d" % code)
	_heard_address(str(got.get("external", "")))


func _renewed(got: Dictionary) -> void:
	var now := _now()
	var code := int(got.get("code", NO_GATEWAY))
	if code == SUCCESS:
		_hold(_asked_at(got, now), bool(got.get("permanent", _permanent)))
		_search_again = false
		if _renew_failing:
			_renew_failing = false
			_say(&"renewed", {})
		_heard_address(str(got.get("external", "")))
		return
	if code == CONFLICT:
		# **Somebody else's now**: the router lost this one -- restarted, or let
		# it lapse -- and another machine took the port. Not ours to take off.
		_held = false
		_renew_failing = false
		_search_again = false
		_look_later(now)
		_say_once(&"conflict", {"internal": _internal}, "conflict %s" % _internal)
		return
	# No answer where the router was, or none that reads: the next asks by a
	# fresh search. A refusal it did answer is asked of it again, where it is.
	_search_again = code == HTTP_ERROR or code == INVALID_RESPONSE or code == SOCKET_ERROR \
		or code == NO_GATEWAY
	_renew_wait = renew_retry if _renew_wait <= 0.0 else _renew_wait * 2.0
	if _permanent:
		# **Never further apart than one with no time limit is put again**: a
		# router out for hours is asked again within [member permanent_check]
		# of coming back, not after a wait that doubled past it.
		_renew_wait = minf(_renew_wait, permanent_check)
	_next_renew = now + _renew_wait
	if not _permanent:
		_next_renew = minf(_next_renew, _lease_end)
	if not _renew_failing:
		_renew_failing = true
		_say(&"renew_failed", {"code": code, "name": result_name(code), "retry": _renew_wait,
			"until": 0 if _permanent else int(Time.get_unix_time_from_system()
				+ (_lease_end - now)), "permanent": _permanent})


## **The removal's answer.** The forward is asked for again first, and taken off
## only when the router gives it: one it says another machine holds now is
## left there -- `not_ours` -- and one it will not answer about is left to its
## lease.
func _unmapped(got: Dictionary) -> void:
	var code := int(got.get("code", NO_GATEWAY))
	var was_permanent := _permanent
	_held = false
	_renew_failing = false
	_search_again = false
	_last_look = ""
	if code == SUCCESS:
		_say(&"removed", {})
	elif code == CONFLICT and not bool(got.get("reasserted", true)):
		_say(&"not_ours", {"internal": _internal})
	else:
		_say(&"remove_failed", {"code": code, "name": result_name(code),
			"permanent": was_permanent, "lease": lease})


## **A forward the router just took, or took again** -- its lease counted from
## [param since], when the router was asked, not from when the answer was
## taken in: the router's clock started no later, so the forward is never
## thought held past the router's own end of it.
func _hold(since: float, permanent: bool) -> void:
	_held = true
	_permanent = permanent
	_lease_end = since + float(lease)
	_renew_wait = 0.0
	_next_renew = since + (permanent_check if permanent else float(lease) * RENEW_AT)


## When the call that got [param got] asked the router for the forward it took,
## on this node's clock -- or [param otherwise], for a router that did not say.
static func _asked_at(got: Dictionary, otherwise: float) -> float:
	return float(got["asked_at"]) / 1000.0 if got.has("asked_at") else otherwise


func _look_later(now: float) -> void:
	_look_wait = look_again if _look_wait <= 0.0 else minf(_look_wait * 2.0, look_again_max)
	_next_look = now + _look_wait


## **The router's public address**, said the first time, whenever it changes,
## and whenever this forward came to be on the router or went since it was
## last said: an address is a hint for `--reach` only while the port leads
## here.
func _heard_address(address: String) -> void:
	if address.is_empty() or (address == _public and _held == _public_held):
		return
	_public = address
	_public_held = _held
	_say(&"address", {"address": address, "kind": kind_of(address), "held": _held})


func _say(event: StringName, facts: Dictionary) -> void:
	var told := facts.duplicate()
	told["port"] = port
	told["protocol"] = protocol
	reported.emit(event, told)


## Said only when [param key] is not what the last look found.
func _say_once(event: StringName, facts: Dictionary, key: String) -> void:
	if key == _last_look:
		return
	_last_look = key
	_say(event, facts)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## **One batch of router calls, on a worker thread**: the router and what to ask
## are handed over whole, and nothing of the node is touched. Returns what the
## main thread takes in -- and `forbidden` for a port it may not map, before a
## single call.
class Job extends RefCounted:
	var router: Object = null
	var ask: Dictionary = {}

	func _init(through: Object, what: Dictionary) -> void:
		router = through
		ask = what

	## **The guard, where the call is made**: the port it was made for, 1 to
	## 65535, and none of its never-list -- whatever the node was told since.
	static func may_map(which: int, given: int, never: PackedInt32Array) -> bool:
		return which == given and which >= 1 and which <= 65535 and not never.has(which)

	func run() -> Dictionary:
		var which := int(ask["port"])
		if not may_map(which, int(ask["given"]), ask["never"]):
			return {"forbidden": true}
		var proto := str(ask["protocol"])
		match StringName(ask["kind"]):
			&"look":
				var found: Dictionary = router.discover(int(ask["timeout"]), ask["avoid"])
				if StringName(found.get("status", &"none")) != &"ok":
					return found
				var out := found.duplicate()
				out.merge(_map(which, proto, bool(ask["permanent"])), true)
				out["external"] = str(router.external_address())
				return out
			&"renew":
				var out := _map(which, proto, bool(ask["permanent"]))
				if int(out["code"]) == SUCCESS:
					out["external"] = str(router.external_address())
				return out
			&"unmap":
				# **Asked for again, then taken off**: Godot's delete names a port
				# and asks nobody whose it is, so a router that answers that the
				# port is another machine's now (718) -- after it restarted and
				# gave it away -- keeps that one. Taken off only when the router
				# gives it back to this machine.
				var again := _map(which, proto, bool(ask["permanent"]))
				if int(again["code"]) != SUCCESS:
					return {"code": int(again["code"]), "reasserted": false}
				return {"code": int(router.delete_mapping(which, proto)), "reasserted": true}
		return {}

	## **Add the forward** -- for the lease, or with no time limit -- and once
	## more with none when the router takes no other kind. `asked_at` is when
	## the add that answered was sent, on the main thread's clock: the lease is
	## counted from there.
	func _map(which: int, proto: String, permanent: bool) -> Dictionary:
		var said := str(ask["description"])
		var seconds := 0 if permanent else int(ask["lease"])
		var asked_at := Time.get_ticks_msec()
		var code := int(router.add_mapping(which, proto, said, seconds))
		if code == PERMANENT_ONLY and not permanent:
			permanent = true
			asked_at = Time.get_ticks_msec()
			code = int(router.add_mapping(which, proto, said, 0))
		return {"code": code, "permanent": permanent, "asked_at": asked_at}


## **The router, through Godot's `UPNP`.** Every method blocks -- a search for
## seconds, a call for up to miniupnpc's socket timeouts -- so only a [Job], on
## its worker thread, calls one. The four a stand-in for it needs:
##   `discover(timeout_ms, avoid)` -> `{status, result, devices}`, and
##     `internal` for `status` `ok`, `wan` for `reserved`, `network` false with
##     no network; `status` is `ok`, `reserved`, `offline`, `not_igd`, `none` or
##     `no_upnp`. `avoid` holds the ports the search must never listen on;
##   `external_address()` -> the router's public address, or "";
##   `add_mapping(port, protocol, description, lease)` -> a result code;
##   `delete_mapping(port, protocol)` -> a result code.
class Upnp extends RefCounted:
	## A router's root description, read at most this far, for this long.
	const DESCRIPTION_MAX := 65536
	const DESCRIPTION_TIMEOUT_MS := 3000
	## **Where a search listens for the routers' answers**: a port drawn from
	## IANA's dynamic range for every search, never one in its avoid-list. Left
	## to the system, it is any ephemeral port -- 32768 to 60999 on Linux, 45772
	## among them -- and miniupnpc takes whatever datagram reaches it for a
	## router's answer, fetching the description it names: through a forward of
	## that port, a stranger's.
	const SEARCH_PORT_LOW := 49152
	const SEARCH_PORT_HIGH := 65535
	## A port already taken fails the search at once with a socket error, and
	## another is drawn, this many times in all.
	const SEARCH_TRIES := 3

	var _gateway: Object = null
	var _draw := RandomNumberGenerator.new()

	func _init() -> void:
		_draw.randomize()

	func discover(timeout_ms: int, avoid: PackedInt32Array = PackedInt32Array()) -> Dictionary:
		_gateway = null
		if not ClassDB.class_exists("UPNP") or not ClassDB.class_exists("UPNPDevice"):
			return {"status": &"no_upnp", "result": NO_DEVICES, "devices": 0}
		if not networked():
			return {"status": &"none", "result": SOCKET_ERROR, "devices": 0, "network": false}
		var upnp: Object = null
		var result := SOCKET_ERROR
		for _try in SEARCH_TRIES:
			upnp = ClassDB.instantiate("UPNP")
			upnp.discover_local_port = search_port(avoid, _draw)
			result = int(upnp.discover(timeout_ms, 2, "InternetGatewayDevice"))
			if result != SOCKET_ERROR:
				break
		var count := int(upnp.get_device_count()) if result == SUCCESS else 0
		if count == 0:
			return {"status": &"none", "result": result, "devices": 0}
		var offline := false
		var reserved: Object = null
		for i in count:
			var device: Object = upnp.get_device(i)
			if device == null:
				continue
			if bool(device.is_valid_gateway()):
				_gateway = device
				return {"status": &"ok", "result": result, "devices": count,
					"internal": str(device.igd_our_addr)}
			# **Godot 4.7 reads miniupnpc's "a connected router with a reserved
			# internet address" (UPNP_GetValidIGD's 2) as DISCONNECTED**, and its
			# "not connected" (3) as UNKNOWN_DEVICE: `upnp_miniupnp.cpp`'s
			# parse_igd was not moved on with miniupnpc's API 18.
			var status := int(device.igd_status)
			if status == IGD_DISCONNECTED and reserved == null:
				reserved = device
			offline = offline or status == IGD_UNKNOWN_DEVICE
		if reserved != null:
			return {"status": &"reserved", "result": result, "devices": count,
				"wan": wan_of(str(reserved.description_url))}
		return {"status": &"offline" if offline else &"not_igd", "result": result,
			"devices": count}

	func external_address() -> String:
		if _gateway == null:
			return ""
		return str(_gateway.query_external_address())

	func add_mapping(which: int, proto: String, said: String, seconds: int) -> int:
		if _gateway == null:
			return NO_GATEWAY
		return int(_gateway.add_port_mapping(which, which, said, proto, seconds))

	func delete_mapping(which: int, proto: String) -> int:
		if _gateway == null:
			return NO_GATEWAY
		return int(_gateway.delete_port_mapping(which, proto))

	## **The port a search listens on**: drawn from [constant SEARCH_PORT_LOW] to
	## [constant SEARCH_PORT_HIGH] by [param draw], and the next one up -- round
	## the range -- that is not in [param avoid]. Never 0, which would leave it
	## to the system.
	static func search_port(avoid: PackedInt32Array, draw: RandomNumberGenerator) -> int:
		var span := SEARCH_PORT_HIGH - SEARCH_PORT_LOW + 1
		var at := draw.randi_range(0, span - 1)
		for step in span:
			var candidate := SEARCH_PORT_LOW + (at + step) % span
			if not avoid.has(candidate):
				return candidate
		return SEARCH_PORT_LOW

	## **Whether this machine has a network a router could be on**: an adapter
	## other than loopback with an IPv4 address that is not loopback,
	## unspecified or link-local. Without one, miniupnpc's search fails anyway --
	## after a second, and four `sendto: Network is unreachable` lines of its own
	## on stderr, measured in a network namespace with loopback alone.
	static func networked() -> bool:
		for iface: Dictionary in IP.get_local_interfaces():
			if str(iface.get("name", "")) == "lo":
				continue
			for address: String in PackedStringArray(iface.get("addresses",
					PackedStringArray())):
				var kind := Address.kind_of(address)
				if kind != &"unknown" and kind != &"unusable":
					return true
		return false

	## **The internet address a router reports for itself, asked of it
	## directly** -- for one Godot will not take as a gateway because that
	## address is reserved, so that its owner can be told which kind: its root
	## description read here, its WAN connection service found in it, and
	## GetExternalIPAddress asked through a `UPNPDevice` built by hand. Only
	## from a router on this machine's own network, and "" for anything that
	## does not read. Never used to forward anything.
	static func wan_of(description_url: String) -> String:
		var at := parts_of(description_url)
		if at.is_empty() or not Address.near(str(at["host"])):
			return ""
		var service := wan_service(fetch(at))
		if service.is_empty():
			return ""
		var control := control_url(at, str(service["base"]), str(service["control"]))
		var there := parts_of(control)
		if there.is_empty() or not Address.near(str(there["host"])):
			return ""
		var device: Object = ClassDB.instantiate("UPNPDevice")
		device.igd_control_url = control
		device.igd_service_type = str(service["type"])
		device.igd_status = IGD_OK
		return str(device.query_external_address())

	## `{host, port, path}` of an `http://` URL whose host is an IPv4 address,
	## or empty.
	static func parts_of(url: String) -> Dictionary:
		if not url.begins_with("http://"):
			return {}
		var rest := url.substr(7)
		var slash := rest.find("/")
		var authority := rest if slash < 0 else rest.substr(0, slash)
		var path := "/" if slash < 0 else rest.substr(slash)
		var host := authority
		var number := 80
		var colon := authority.rfind(":")
		if colon >= 0:
			host = authority.substr(0, colon)
			var digits := authority.substr(colon + 1)
			if not digits.is_valid_int():
				return {}
			number = int(digits)
		if Address.octets(host).size() != 4 or number < 1 or number > 65535:
			return {}
		return {"host": host, "port": number, "path": path}

	## The control URL as miniupnpc builds one: as it is when it is whole, and
	## otherwise after the scheme and host of the description's `URLBase`, or of
	## the description's own address.
	static func control_url(at: Dictionary, base: String, control: String) -> String:
		if control.begins_with("http://"):
			return control
		var origin := base if base.begins_with("http://") \
			else "http://%s:%d" % [str(at["host"]), int(at["port"])]
		var slash := origin.find("/", 7)
		if slash >= 0:
			origin = origin.substr(0, slash)
		return origin + ("" if control.begins_with("/") else "/") + control

	## **A GET over plain HTTP**, bounded in bytes and time, on this thread.
	static func fetch(at: Dictionary) -> PackedByteArray:
		var body := PackedByteArray()
		var http := HTTPClient.new()
		var until := Time.get_ticks_msec() + DESCRIPTION_TIMEOUT_MS
		if http.connect_to_host(str(at["host"]), int(at["port"])) != OK:
			return body
		while http.get_status() == HTTPClient.STATUS_RESOLVING \
				or http.get_status() == HTTPClient.STATUS_CONNECTING:
			if Time.get_ticks_msec() > until:
				http.close()
				return body
			http.poll()
			OS.delay_msec(5)
		if http.get_status() != HTTPClient.STATUS_CONNECTED \
				or http.request(HTTPClient.METHOD_GET, str(at["path"]), PackedStringArray()) != OK:
			http.close()
			return body
		while http.get_status() == HTTPClient.STATUS_REQUESTING:
			if Time.get_ticks_msec() > until:
				http.close()
				return body
			http.poll()
			OS.delay_msec(5)
		if not http.has_response() or http.get_response_code() != 200:
			http.close()
			return body
		while http.get_status() == HTTPClient.STATUS_BODY and body.size() <= DESCRIPTION_MAX \
				and Time.get_ticks_msec() <= until:
			http.poll()
			var chunk := http.read_response_body_chunk()
			if chunk.is_empty():
				OS.delay_msec(5)
			else:
				body.append_array(chunk)
		http.close()
		return body

	## **The WAN connection service in a root description** -- `{type,
	## control, base}`, the IP one before the PPP one -- or empty.
	static func wan_service(xml: PackedByteArray) -> Dictionary:
		var parser := XMLParser.new()
		if xml.is_empty() or xml.size() > DESCRIPTION_MAX or parser.open_buffer(xml) != OK:
			return {}
		var open: PackedStringArray = []
		var base := ""
		var service := {}
		var by_ip := {}
		var by_ppp := {}
		while parser.read() == OK:
			var type := parser.get_node_type()
			if type == XMLParser.NODE_ELEMENT:
				var name := _local(parser.get_node_name())
				if name == "service":
					service = {}
				if not parser.is_empty():
					open.append(name)
			elif type == XMLParser.NODE_ELEMENT_END:
				if _local(parser.get_node_name()) == "service" \
						and not str(service.get("control", "")).is_empty():
					var kind := str(service.get("type", ""))
					if kind.contains(":WANIPConnection:") and by_ip.is_empty():
						by_ip = service.duplicate()
					elif kind.contains(":WANPPPConnection:") and by_ppp.is_empty():
						by_ppp = service.duplicate()
				if not open.is_empty():
					open.remove_at(open.size() - 1)
			elif type == XMLParser.NODE_TEXT and not open.is_empty():
				var text := parser.get_node_data().strip_edges()
				match open[open.size() - 1]:
					"serviceType":
						service["type"] = text
					"controlURL":
						service["control"] = text
					"URLBase":
						base = text
		var found := by_ip if not by_ip.is_empty() else by_ppp
		if found.is_empty():
			return {}
		found["base"] = base
		return found

	static func _local(name: String) -> String:
		var colon := name.find(":")
		return name if colon < 0 else name.substr(colon + 1)


## **Addresses, read without a lookup.**
class Address extends RefCounted:
	## Four octets out of a dotted IPv4 address, or empty.
	static func octets(address: String) -> PackedInt32Array:
		var parts := address.strip_edges().split(".")
		if parts.size() != 4:
			return PackedInt32Array()
		var out := PackedInt32Array()
		for part: String in parts:
			if part.is_empty() or part.length() > 3 or not part.is_valid_int() \
					or part.begins_with("+") or part.begins_with("-"):
				return PackedInt32Array()
			var value := int(part)
			if value > 255:
				return PackedInt32Array()
			out.append(value)
		return out

	## See [method PortForward.kind_of]. The documentation ranges count as
	## public here: no router has one, and a test stands in for a public
	## address with them.
	static func kind_of(address: String) -> StringName:
		var o := octets(address)
		if o.size() != 4:
			return &"unknown"
		if o[0] == 10 or (o[0] == 172 and o[1] >= 16 and o[1] <= 31) \
				or (o[0] == 192 and o[1] == 168):
			return &"private"
		if o[0] == 100 and o[1] >= 64 and o[1] <= 127:
			return &"shared"
		if o[0] == 0 or o[0] == 127 or (o[0] == 169 and o[1] == 254) or o[0] >= 224:
			return &"unusable"
		return &"public"

	## **Whether a router at [param host] is on this machine's own network**:
	## a private, shared or link-local address, or one in the /24 of an address
	## of this machine's.
	static func near(host: String) -> bool:
		var o := octets(host)
		if o.size() != 4:
			return false
		var kind := kind_of(host)
		if kind == &"private" or kind == &"shared" or (o[0] == 169 and o[1] == 254):
			return true
		for mine: String in IP.get_local_addresses():
			var m := octets(mine)
			if m.size() == 4 and m[0] == o[0] and m[1] == o[1] and m[2] == o[2]:
				return true
		return false
