extends Node
## **The network's fuzzer** (issue #91, docs/design/net-hardening.md part D):
## everything that reads what a stranger sends, fed what a stranger could send,
## seeded, bounded, and replayable -- with no socket a caller could reach.
##
##   - **wire**: every decoder a host or a guest reads frames with, fed valid
##     frames of every kind and those frames cut, stretched, flipped and
##     spliced; read only where the gate would read them, as the gate does.
##   - **door**: a real host session -- the dedicated server's, both listeners,
##     and one run in four a phone's, the LAN one alone -- driven by hand: callers
##     that connect, say anything, prove or fail to, go and come back under
##     the same id or the other listener's, and more of them than a book holds
##     -- with every place it would touch ENet or the clock put under the
##     fuzzer's control, so nothing but this process ever reaches it.
##   - **guest**: the other end of the handshake -- a guest session, on a LAN
##     call or one by invite, fed whatever a host could send it: it greets
##     once, and proves an invite only on a call by invite, only once, and
##     only to a CHALLENGE from its host; and a WELCOME on other rules or with
##     no tail leaves it refused as different versions, never together.
##   - **invite**: pastes, from whole invites to junk behind a check that
##     reads.
##   - **address**: the LAN door's `is_local_source` and the limiter's
##     `source_key` and `wider_key`, for addresses written every way ENet and
##     people write them, against what each address is.
##   - **referee**: every judgement a guest can ask for, in any order, with any
##     finite values a frame can carry.
##
## **What must hold**, all of it checked after every step: no script error,
## and no engine error in a reader; nothing played before a valid proof on the
## internet listener, of an invite the owner holds; no peer the door did not
## admit, none under an id below 2, none greeted on another protocol; no guest
## together after a WELCOME on other rules or with no tail; one
## listener's peer never taken for the other's; nothing a real ENet would
## refuse -- a frame to an id not held or cut, a peer asked for that is not
## there; no bar forgotten early, no call taken from a barred address or /56,
## none turned away at a cost to the bucket every address shares, and room
## made only by the caller that has waited longest, long enough, from another
## address and /56 (#103);
## no peer taken past its budgets; every queue and book inside its cap, a
## phone host's inside a host's own share; the referee's answers finite and
## inside its caps; and no secret in any line
## printed; and no invite paste costs the engine's log more than
## `Invite.CERTIFICATES_MAX` lines, each one a certificate that does not parse
## (#106). **And every path the door can take is taken** -- by a run or a
## saved case -- but the few no run here can reach.
##
## **Run it** in a network namespace of its own, as CI does -- the door binds
## the real LAN and internet ports, and will not run where any interface but
## loopback could reach them:
##
##   sudo unshare --net -- bash -c 'ip link set lo up &&
##       ip addr add 10.77.0.5/24 dev lo && godot --headless --path .
##       res://tools/net_fuzz.tscn -- --seed=1'
##
## The address is one the LAN host can take, in a namespace nothing else is
## in. Options: `--seed=N`, `--scale=K` (1 is CI's five seconds, 20 a longer
## look), `--only=wire,door,...` -- which also narrows the corpus to those
## sections, and is how to run the rest anywhere -- and `--replay=` one case.
## A failure prints what broke and a `--replay=` that runs that case alone,
## minimised. **Every case in `net_fuzz_corpus.txt` runs first**: a failure
## that is fixed goes in there, and stays fixed. Excluded from export
## (`tools/*`), so it never ships.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Wire := preload("res://game/net/wire.gd")
const Lan := preload("res://game/net/lan.gd")
const Invite := preload("res://game/net/invite.gd")
const NetSession := preload("res://game/net/net_session.gd")
const Rules := preload("res://game/net/rules.gd")
const Referee := preload("res://game/net/referee.gd")
const CellBody := preload("res://game/normal/cell.gd")
## Every gene's numbers, by stat: the reach an honest call has.
const Stats := preload("res://game/genes/stats.gd")
## **Every gene this build knows**, by key: what a genome here is drawn from.
const Catalogue := preload("res://game/genes/catalogue.gd")
const CORPUS := "res://tools/net_fuzz_corpus.txt"
## **The certificate every invite here carries**: made once, its key thrown
## away, so it proves nothing and opens nothing -- it is here so a seed's
## invites are the same bytes on every run.
const INVITE_CERT := "res://tools/net_fuzz_cert.pem"
## [method _home_prefix]'s answer, once asked.
var _home := ""

## **Each section's size at `--scale=1`** -- what CI runs.
const WIRE_CASES := 20000
const DOOR_RUNS := 120
const DOOR_STEPS := 50
const INVITE_CASES := 1200
const ADDRESS_CASES := 6000
const REFEREE_RUNS := 150
const REFEREE_STEPS := 60
const GUEST_RUNS := 150
const GUEST_STEPS := 40
const SECTIONS := ["wire", "door", "guest", "invite", "address", "referee"]
## **The door's counts no run here can move**, by design: the real socket's
## statistics; a closing listener's door, which ENet's `refuse_new_connections`
## keeps every caller from; the referee's fouls, which are the pond's; and a
## guest's dropped CHALLENGEs. Every other count must be moved by some run.
const DOOR_OUT_OF_REACH := ["saturated", "refused_closed", "net_refused_closed", "fouls",
	"referee_strikes", "referee_would_strikes", "referee_would_cuts", "challenges_dropped"]
## The label and secret of the one invite the door knows: found in no log.
const LABEL := "fuzzfriend"
## **Lines a sister's list holds** (protocol 6, docs/design/automation.md
## §10.3): the water's seven, a page's, and the rule of a gene no build declares.
const LINES: Array[String] = ["metabolism.fed below 5 -> body.rest",
	"metabolism.hunger below 0.3 -> body.rest",
	"ampulla.echo size below mouth -> body.turn-toward", "ocellus.beam -> body.turn-toward",
	"chemocyte.smell level falling -> body.turn-random", "always -> body.swim",
	"always -> axoneme.push 0.5", "palp.touch closeness above 0.5 -> body.turn-away",
	"always -> flagellum.hold", "xenogene.hum above 0.5 -> body.turn-away"]


## **Every line printed and every error raised**, counted by kind.
class Catcher extends Logger:
	var lines: PackedStringArray = []
	var script_errors := 0
	var engine_errors := 0
	## **4.7's DTLS listener, closing**: three lines from
	## `godot_mbedtls_mutex_free` every time, an engine bug and harmless
	## (net-hardening.md C.1). Counted here and nowhere else, so any other line
	## still fails a run.
	var dtls_close_lines := 0
	## **Lines the engine prints as errors without an error's call** -- a
	## string that does not decode says so this way (#106). Counted apart, so
	## what a section makes on purpose to feed a reader is not that reader's.
	var message_errors := 0
	## The latest error, said in full.
	var last := ""
	var _lock := Mutex.new()

	func _log_message(message: String, error: bool) -> void:
		_lock.lock()
		lines.append(message)
		if error:
			message_errors += 1
			last = message
		_lock.unlock()

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		_lock.lock()
		if function == "godot_mbedtls_mutex_free":
			dtls_close_lines += 1
			_lock.unlock()
			return
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			script_errors += 1
		else:
			engine_errors += 1
		last = "%s %s (%s:%d %s)" % [code, rationale, file.get_file(), line, function]
		lines.append("%s %s" % [code, rationale])
		_lock.unlock()

	func errors() -> int:
		return script_errors + engine_errors


## **A host session with nothing a caller could reach**: its clock, the
## addresses of its callers, what it sends and whom it drops are all the
## fuzzer's. The rest -- the door, the gate, the handshake, the budgets, the
## timers -- is net_session.gd's own.
##
## [member connected] is ENet's side of it, one Dictionary per listener: an id
## is `true` while its transport is up and `false` once the host has cut it and
## ENet has not yet said so. **What a real host would make an engine error of
## is a failure here**: a frame to an id its listener does not hold or has cut
## -- `put_packet` to a peer `peer_disconnect_now` already reset -- and asking
## ENet for a peer it does not hold at all, to cut it, throttle it or learn its
## address (`get_peer`). So is a frame to an id below 2, which ENet reads as
## many peers.
class FuzzHost extends "res://game/net/net_session.gd":
	var now_at := 1000.0
	## Each transport's address, by its line: `id:via`.
	var where := {}
	var connected := [{}, {}]
	var sent: Array = []
	var drops: Array = []
	var misaddressed := ""
	## The internet listener [member connected]'s second half belongs to: when
	## the host closes it, its transports go with it, and ENet says nothing.
	var net_seen: Object = null

	func _now() -> float:
		return now_at

	func _address_of(id: int, via: int = VIA_LAN) -> String:
		_holds(id, via, "asked the address of")
		return str(where.get("%d:%d" % [id, via], ""))

	func _steady_throttle(id: int, via: int = VIA_LAN) -> void:
		_holds(id, via, "throttled")

	func _to(id: int, frame: PackedByteArray) -> void:
		# The listener the id came in on, as the real one sends on.
		var via := int(_via.get(id, VIA_LAN))
		if not hosting or _transport(via) == null:
			return
		var held: Dictionary = connected[via]
		if misaddressed.is_empty() and id < PEER_ID_MIN:
			misaddressed = "sent %d bytes to id %d, which ENet reads as many peers" % [
				frame.size(), id]
		elif misaddressed.is_empty() and not bool(held.get(id, false)):
			misaddressed = "sent %d bytes to id %d on the %s listener, which %s" % [
				frame.size(), id, "internet" if via == VIA_NET else "LAN",
				"has already cut it" if held.has(id) else "does not hold it"]
		sent.append([id, frame, via])

	func _drop_on(via: int, id: int) -> void:
		if not hosting or not _holds(id, via, "cut"):
			return
		var held: Dictionary = connected[via]
		if bool(held[id]):
			held[id] = false
			drops.append([via, id])

	## True if the listener [param via] holds [param id], cut or not; a failure
	## noted if it does not, since the real call asks ENet's `get_peer`.
	func _holds(id: int, via: int, doing: String) -> bool:
		if _transport(via) == null:
			return false
		if (connected[via] as Dictionary).has(id):
			return true
		if misaddressed.is_empty():
			misaddressed = "%s id %d on the %s listener, which does not hold it" % [doing, id,
				"internet" if via == VIA_NET else "LAN"]
		return false


## **A guest session with no transport**: its clock and what it sends are the
## fuzzer's, and the host is id 1, as a real guest's always is. It counts the
## WELCOMEs the gate let through to the handshake, so a run knows which it read.
class FuzzGuest extends "res://game/net/net_session.gd":
	var now_at := 1000.0
	var sent: Array = []
	var welcomes := 0

	func _now() -> float:
		return now_at

	func _take_welcome(id: int, frame: PackedByteArray) -> void:
		welcomes += 1
		super(id, frame)

	func _steady_throttle(_id: int, _via: int = VIA_LAN) -> void:
		pass

	func _to(id: int, frame: PackedByteArray) -> void:
		sent.append([id, frame])


var _seed := 1
var _scale := 1.0
var _only: Array = []
var _rng := RandomNumberGenerator.new()
## [method _lone_surrogates], made once a run by the invite section.
var _lone := ""
var _catcher: Catcher = null
var _failed := 0
var _key: CryptoKey = null
var _cert: X509Certificate = null
var _der := PackedByteArray()
var _key_id := PackedByteArray()
var _secret := PackedByteArray()
## The invite the owner replaces it with, in a run that does.
var _key_id_2 := PackedByteArray()
var _secret_2 := PackedByteArray()
var _host: FuzzHost = null
var _started := 0
## How many times a run closed an internet listener -- by closing its host,
## or the owner revoking an invite -- against the lines 4.7 prints for it.
var _closes := 0
## Every run's gate counts, summed -- the saved cases' included: which of the
## door's paths were taken.
var _door_counts := {}
## Why the last host could not be opened, said.
var _no_host := ""
## **This build's handshake tail** (protocol 8): its rules and content version 0,
## which every HELLO and WELCOME it means to be taken carries.
var _tail := PackedByteArray()


func _ready() -> void:
	_started = Time.get_ticks_msec()
	var replay := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--scale="):
			_scale = maxf(float(arg.trim_prefix("--scale=")), 0.01)
		elif arg.begins_with("--only="):
			_only = Array(arg.trim_prefix("--only=").split(",", false))
		elif arg.begins_with("--replay="):
			replay = arg.trim_prefix("--replay=")
	_catcher = Catcher.new()
	OS.add_logger(_catcher)
	_tail = Wire.tail(Rules.fingerprint(), 0)
	_identity()
	await _run(replay)
	OS.remove_logger(_catcher)
	get_tree().quit(1 if _failed > 0 else 0)


func _run(replay: String) -> void:
	var sections: Array = SECTIONS.filter(func(each: String) -> bool:
		return _only.is_empty() or _only.has(each))
	var door_ok := _isolated()
	if not door_ok and (sections.has("door") or replay.begins_with("door")):
		_says(false, "door: not run -- this machine has interfaces besides loopback (%s),"
			% ", ".join(_interfaces()) + " so a port the door opens could be reached from"
			+ " them. Run it in a network namespace of its own, as the header says, or"
			+ " leave the door out: --only=wire,guest,invite,address,referee")
		sections.erase("door")
		if replay.begins_with("door"):
			return
	if not replay.is_empty():
		var ok := await _replay(replay, true)
		print("[net-fuzz] %s --replay=%s" % ["PASS" if ok else "FAIL", replay])
		if not ok:
			_failed += 1
		return
	var corpus := Array(_corpus()).filter(func(entry: String) -> bool:
		return sections.has(entry.get_slice(" ", 0)))
	var corpus_failed := 0
	for entry: String in corpus:
		if not await _replay(entry, false):
			corpus_failed += 1
			print("[net-fuzz] FAIL corpus: --replay=%s" % entry)
	_failed += corpus_failed
	_says(corpus_failed == 0, "corpus: %d saved cases for %s, every one as it should be"
		% [corpus.size(), ", ".join(PackedStringArray(sections))])
	for section: String in sections:
		var began := Time.get_ticks_msec()
		match section:
			"wire":
				_fuzz_wire()
			"door":
				await _fuzz_door()
			"guest":
				await _fuzz_guest()
			"invite":
				_fuzz_invite()
			"address":
				_fuzz_address()
			"referee":
				_fuzz_referee()
		print("[net-fuzz] NOTE %s took %.1f s" % [section,
			float(Time.get_ticks_msec() - began) / 1000.0])
	if _host != null and is_instance_valid(_host):
		_host.close()
		_host = null
	_says(_secrets_unsaid(), "secrets: neither invite's secret -- in hex, in base64, or as"
		+ " GDScript prints bytes -- in any of the %d lines this run printed"
		% _catcher.lines.size())
	print("[net-fuzz] NOTE seed %d, scale %.2f, %.1f s in all" % [_seed, _scale,
		float(Time.get_ticks_msec() - _started) / 1000.0])
	if _failed == 0:
		print("[net-fuzz] ALL PASS")
	else:
		print("[net-fuzz] %d FAILED" % _failed)


## **No secret in any line printed** -- the host's log, a guest's, the
## fuzzer's own -- in hex, in base64, or as GDScript prints the bytes, in a
## `print` of a Dictionary or `var_to_str`.
func _secrets_unsaid() -> bool:
	for secret: PackedByteArray in [_secret, _secret_2]:
		for form: String in [secret.hex_encode(), Marshalls.raw_to_base64(secret),
				str(secret).trim_prefix("[").trim_suffix("]")]:
			for line: String in _catcher.lines:
				if line.containsn(form):
					return false
	return true


## **Whether nothing but this process can reach a port it opens**: true in a
## network namespace of its own, where loopback is the only interface -- how
## CI runs this, and how to run it locally (the header). The door binds the
## real LAN and internet ports; this is what makes sure no caller could ever
## reach them.
static func _isolated() -> bool:
	return _interfaces() == PackedStringArray(["lo"])


static func _interfaces() -> PackedStringArray:
	var names: PackedStringArray = []
	for each: Dictionary in IP.get_local_interfaces():
		names.append(str(each.get("name", "?")))
	names.sort()
	return names


func _says(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("[net-fuzz] %s %s" % ["PASS" if ok else "FAIL", what])


## **A seed's invites, the same bytes on every run**: key ids and secrets
## drawn from the seed, and [constant INVITE_CERT]'s certificate. The door's
## own key and certificate are made fresh: a DTLS listener needs a pair, and
## nothing any run decides depends on their bytes -- no caller here speaks
## DTLS.
func _identity() -> void:
	var made := RandomNumberGenerator.new()
	made.seed = hash("invites %d" % _seed)
	_key_id = _bytes_of(made, Wire.KEY_ID_SIZE)
	_secret = _bytes_of(made, Invite.SECRET_SIZE)
	_key_id_2 = _bytes_of(made, Wire.KEY_ID_SIZE)
	_secret_2 = _bytes_of(made, Invite.SECRET_SIZE)
	_der = Invite.der_of_pem(FileAccess.get_file_as_string(INVITE_CERT))
	var crypto := Crypto.new()
	_key = crypto.generate_rsa(2048)
	_cert = crypto.generate_self_signed_certificate(_key, "CN=" + Invite.NAME,
		"20200101000000", "20991231235959")


func _cases(base: int) -> int:
	return maxi(1, int(round(float(base) * _scale)))


# ---------------------------------------------------------------------------
# wire: the decoders, read where the gate reads them.
# ---------------------------------------------------------------------------

func _fuzz_wire() -> void:
	_rng.seed = hash(_seed * 31 + 1)
	var cases := _cases(WIRE_CASES)
	var bad := ""
	var read := 0
	var by_kind := {}
	for i in cases:
		var from_host := _rng.randf() < 0.5
		var frame := _mutate(_valid_frame(from_host))
		var why := _wire_case(frame, from_host)
		if why == "read":
			read += 1
			var kind := Wire.kind(frame)
			by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		elif not why.is_empty():
			var small := _shrink_frame(frame, from_host)
			bad = "case %d: %s -- --replay=\"wire %s %s\"" % [i, why, "h" if from_host else "g",
				small.hex_encode()]
			break
	_says(bad.is_empty(), "wire: %d frames, %d of them read by the gate's own rules (%d"
		% [cases, read, by_kind.size()] + " kinds), every reader clean and every value"
		+ " finite and inside its caps%s" % ("" if bad.is_empty() else " -- NOT: " + bad))


## **One frame, read as the side that receives it would**: "" when the gate
## would not read it, "read" when every reader was clean, or what went wrong.
func _wire_case(frame: PackedByteArray, from_host: bool) -> String:
	var errors := _catcher.errors()
	var outcome := ""
	var size := frame.size()
	# The gate's steps 2-5 (`_admit_frame`): the cap, a kind, the event
	# header, and a size its writer produces. Nothing past them is read unless
	# they pass. A greeted guest's cap is its frame's kind's: a SISTER's, or the
	# one every other frame keeps (`Wire.guest_cap`, protocol 6).
	var ceiling := Wire.HOST_FRAME_MAX if from_host else Wire.guest_cap(frame)
	if size == 0 or size > ceiling:
		return _errors_since(errors, "")
	var kind := Wire.kind(frame)
	var type := 0
	if kind == Wire.KIND_EVENT:
		if size < Wire.EVENT_HEADER:
			return _errors_since(errors, "")
		type = frame[5]
	if not Wire.known(kind, type) or not Wire.size_ok(kind, type, size, from_host):
		return _errors_since(errors, "")
	outcome = "read"
	var parses := NetSession._parses(kind, type, frame) if not from_host else true
	Wire.seq_of(frame)
	match kind:
		Wire.KIND_HELLO:
			Wire.protocol_of(frame)
		Wire.KIND_WELCOME:
			Wire.protocol_of(frame)
			Wire.welcome_host_id(frame)
		Wire.KIND_REFUSE:
			Wire.protocol_of(frame)
			Wire.refuse_reason(frame)
		Wire.KIND_CHALLENGE:
			if Wire.challenge_nonce(frame).size() != Wire.NONCE_SIZE:
				outcome = "a CHALLENGE of the right size gave no nonce"
		Wire.KIND_PROOF:
			var parts := Wire.proof_parts(frame)
			if parts.size() != 3:
				outcome = "a PROOF of the right size gave no parts"
		Wire.KIND_STATE:
			Wire.state_alive(frame)
			Wire.state_flags(frame)
			var body := Wire.state_body(frame)
			if parses and not body.is_empty():
				var why := _body_why(body)
				if not why.is_empty():
					outcome = "a state frame the host takes carried " + why
		Wire.KIND_POND:
			var pond := Wire.take_pond(frame)
			if not pond.is_empty():
				var why := _pond_why(pond)
				if not why.is_empty():
					outcome = "a snapshot a guest takes carried " + why
		Wire.KIND_EVENT:
			var got: Array = _take_event(type, frame)
			if parses and not got.is_empty():
				var why := _finite_why(got)
				if why.is_empty() and type == Wire.EVENT_SISTER:
					why = _sister_why(got)
				if not why.is_empty():
					outcome = "an event the host takes carried " + why
	return _errors_since(errors, outcome)


func _errors_since(before: int, outcome: String) -> String:
	if _catcher.errors() > before:
		return "an error while reading it: " + _catcher.last
	return outcome


func _take_event(type: int, frame: PackedByteArray) -> Array:
	match type:
		Wire.EVENT_SHOUT:
			return Wire.take_shout(frame)
		Wire.EVENT_ENTER:
			return Wire.take_enter(frame)
		Wire.EVENT_ARRIVE:
			return Wire.take_arrive(frame)
		Wire.EVENT_PERSON:
			return Wire.take_person(frame)
		Wire.EVENT_GENOME:
			return Wire.take_genome(frame)
		Wire.EVENT_CONTACT:
			return Wire.take_contact(frame)
		Wire.EVENT_DIED:
			return Wire.take_died(frame)
		Wire.EVENT_SISTER:
			return Wire.take_sister(frame)
		Wire.EVENT_SETTLE:
			return Wire.take_settle(frame)
		Wire.EVENT_CLEAR:
			return Wire.take_clear(frame)
	return []


## **A state body, held to what [method Wire.state_body] promises**: every
## value finite, a radius above zero, and a motion some body could have.
static func _body_why(body: Array) -> String:
	var why := _finite_why(body)
	if not why.is_empty():
		return why
	if float(body[2]) <= 0.0:
		return "a radius of %s" % str(body[2])
	return _motion_why(body[3], float(body[4]))


## **A snapshot, held to what [method Wire.take_pond] promises**: every value
## finite, no more bodies than a snapshot holds, the person and only the person
## by the person's id, and a person's motion one a body could have -- and since
## protocol 7 the recipient's three loads, each a count of stacks its byte can
## say.
static func _pond_why(pond: Array) -> String:
	var why := _finite_why(pond)
	if not why.is_empty():
		return why
	var loads: PackedFloat64Array = pond[3]
	if loads.size() != Wire.POND_LOADS:
		return "%d loads" % loads.size()
	for stacks: float in loads:
		if not is_finite(stacks) or stacks < 0.0 or stacks > 255.0 / Wire.POND_LOAD_SCALE:
			return "a load of %s" % str(stacks)
	var bodies: Array = pond[2]
	if bodies.size() > Wire.POND_BODIES_MAX:
		return "%d bodies, past %d" % [bodies.size(), Wire.POND_BODIES_MAX]
	for body: Array in bodies:
		var id := int(body[Wire.Entry.ID])
		var person := (int(body[Wire.Entry.FLAGS]) & Wire.POND_IS_PERSON) != 0
		if id < 0 or id > 0xFFFFFFFF or (id == Wire.PERSON_ID) != person:
			return "a body of id %d%s" % [id, " flagged as the person" if person else ""]
		why = _motion_why(body[Wire.Entry.VELOCITY], float(body[Wire.Entry.TURNING]))
		if not why.is_empty():
			return why
	return ""


## **A sister, held to what [method Wire.take_sister] promises** (protocol 6):
## her body's genes and her DNA's named as the wire names them, at most
## [member Wire.GENES_MAX], at tiers inside 0..3 and her DNA's copies inside
## 1..3; and at most [constant Wire.MOST_RULES] lines, each 1 to
## [constant Wire.RULE_BYTES_MAX] bytes of [constant Wire.RULE_BYTES].
static func _sister_why(sister: Array) -> String:
	for which: int in [3, 4]:
		var genome: Dictionary = sister[which]
		if genome.size() > Wire.GENES_MAX:
			return "%d genes" % genome.size()
		for gene: Variant in genome:
			var tier := int(genome[gene])
			if not Wire._name_ok(String(gene)) or tier > Wire.TIER_TOP \
					or tier < (1 if which == 4 else 0):
				return "a gene %s at %d" % [String(gene).c_escape(), tier]
	var lines: PackedStringArray = sister[5]
	if lines.size() > Wire.MOST_RULES:
		return "%d lines" % lines.size()
	for line: String in lines:
		if not Wire._line_ok(line):
			return "a line '%s'" % line.c_escape()
	return ""


static func _motion_why(velocity: Vector2, turning: float) -> String:
	if velocity.length() > Wire.MOTION_MAX or absf(turning) > Wire.TURNING_MAX:
		return "a motion of %s turning %s" % [str(velocity), str(turning)]
	return ""


## The first value in [param values] -- nested Arrays and Dictionaries
## included -- that is not finite, said; "" when every one is.
static func _finite_why(values: Variant) -> String:
	if values is float:
		return "" if is_finite(values) else "a %s" % str(values)
	if values is Vector2:
		return "" if (values as Vector2).is_finite() else "a vector %s" % str(values)
	if values is Array:
		for each: Variant in values:
			var why := _finite_why(each)
			if not why.is_empty():
				return why
	if values is Dictionary:
		for key: Variant in values:
			var why := _finite_why(values[key])
			if not why.is_empty():
				return why
	return ""


## **A handshake frame's tail, mostly this build's** -- its rules, so the frame is
## taken -- and now and then none, as a build before protocol 8 sends, or other
## rules, as a build on another catalogue does.
func _some_tail() -> PackedByteArray:
	var roll := _rng.randf()
	if roll < 0.8:
		return _tail
	if roll < 0.9:
		return PackedByteArray()
	return Wire.tail(_bytes(Wire.RULES_SIZE), _rng.randi_range(0, 9999))


## **A valid frame of any kind** its side could send, with random values
## inside what a real body could say.
func _valid_frame(from_host: bool, next := -1) -> PackedByteArray:
	var seq := next if next >= 0 else _rng.randi_range(0, 0x7FFFFFFF)
	var at := Vector2(_rng.randf_range(-5000.0, 5000.0), _rng.randf_range(-5000.0, 5000.0))
	var radius := _rng.randf_range(CellBody.BASE_RADIUS, CellBody.DIVIDE_RADIUS)
	var tiers := _tiers()
	var choice := _rng.randi_range(0, 15)
	match choice:
		0:
			return Wire.hello(_rng.randi_range(0, 9), _some_tail())
		1:
			return Wire.welcome(Wire.PROTOCOL, _rng.randi_range(2, 0x7FFFFFFF), _some_tail())
		2:
			return Wire.refuse(Wire.PROTOCOL, _rng.randi_range(0, 8), _some_tail())
		3:
			return Wire.challenge(_bytes(Wire.NONCE_SIZE))
		4:
			return Wire.proof(_bytes(Wire.KEY_ID_SIZE), _bytes(Wire.NONCE_SIZE),
				_bytes(Wire.MAC_SIZE))
		5:
			return Wire.state(seq, _rng.randf() < 0.8, at, _rng.randf_range(-PI, PI), radius,
				Vector2(_rng.randf_range(-900.0, 900.0), _rng.randf_range(-900.0, 900.0)),
				_rng.randf_range(-1.4, 1.4), _rng.randi_range(0, 7))
		6:
			return Wire.shout(seq, at, radius, Stats.table(&"ping_range")[
				_rng.randi_range(1, Stats.table(&"ping_range").size() - 1)])
		7:
			if from_host:
				return Wire.pond(seq, _rng.randf(), _pond_bodies(), _pond_loads())
			return Wire.event(seq, Wire.EVENT_ENTER, Wire.enter_payload(radius))
		8:
			return Wire.event(seq, Wire.EVENT_ARRIVE, Wire.arrive_payload(at,
				_rng.randf_range(-PI, PI), at * 0.5, _rng.randf_range(0.0, 8000.0)))
		9:
			return Wire.event(seq, Wire.EVENT_PERSON, Wire.person_payload(_rng.randf() < 0.5,
				tiers, tiers.keys()))
		10:
			return Wire.event(seq, Wire.EVENT_GENOME, Wire.genome_payload(
				_rng.randi_range(1, 0x7FFFFFFF), _rng.randi_range(0, 40), tiers))
		13:
			return Wire.event(seq, Wire.EVENT_SETTLE, Wire.settle_payload(
				_rng.randi_range(1, 0x7FFFFFFF), at, _rng.randf_range(8.0, 18.0), _rng.randf(),
				_rng.randf_range(0.0, 150.0)))
		14:
			return Wire.event(seq, Wire.EVENT_CLEAR, Wire.clear_payload(
				_rng.randi_range(1, 0x7FFFFFFF)))
		11:
			return Wire.event(seq, Wire.EVENT_CONTACT, Wire.contact_payload(
				_rng.randi_range(1, 6), at, _rng.randf(), _rng.randi_range(1, 2),
				StringName(tiers.keys()[0]) if not tiers.is_empty() else &"",
				_rng.randi_range(0, 4)))
		12:
			return Wire.event(seq, Wire.EVENT_DIED, Wire.died_payload(_rng.randi_range(1, 4),
				_rng.randi_range(0, 2), at))
	return Wire.event(seq, Wire.EVENT_SISTER, Wire.sister_payload(at,
		_rng.randf_range(-PI, PI), Referee.DAUGHTER_RADIUS, tiers, _tiers(), _lines()))


func _tiers() -> Dictionary:
	return _tiers_from(_rng)


## **A list a sister could carry**: none to [constant Wire.MOST_RULES] of
## [constant LINES], and now and then one as long as a line may be.
func _lines() -> PackedStringArray:
	var out := PackedStringArray()
	for i in _rng.randi_range(0, Wire.MOST_RULES):
		if _rng.randf() < 0.1:
			out.append((LINES[0] + " " + "x".repeat(Wire.RULE_BYTES_MAX)).left(
				Wire.RULE_BYTES_MAX))
		else:
			out.append(LINES[_rng.randi_range(0, LINES.size() - 1)])
	return out


## **A genome a body could wear, or a newer build's** (gene-catalogue.md §13): every
## key the catalogue knows -- the retired among them, and since protocol 7 the toxin's
## two forms -- and, about one gene in seven, a name this build does not know, as a
## later content update could add one ([method _invented]). Up to two more than the
## names a genome may hold, each at a tier from none to the wire's top.
static func _tiers_from(rng: RandomNumberGenerator) -> Dictionary:
	var genes := Catalogue.keys()
	var out := {}
	for i in rng.randi_range(1, Wire.GENES_MAX + 2):
		var gene: StringName = genes[rng.randi_range(0, genes.size() - 1)] \
			if rng.randf() < 0.85 else _invented(rng)
		out[gene] = rng.randi_range(0, Wire.TIER_TOP)
	return out


## **A gene's name this build does not know**: 1 to [constant Wire.NAME_MAX] letters
## `a-z`, a name the wire carries and every reader keeps.
static func _invented(rng: RandomNumberGenerator) -> StringName:
	var name := ""
	for k in rng.randi_range(1, Wire.NAME_MAX):
		name += String.chr(97 + rng.randi_range(0, 25))
	return StringName(name)


## **The loads a snapshot tells its recipient** (protocol 7): none mostly, then
## stacks of each kind, to past what a byte says, and now and then not a number
## at all -- which the writer sends as none.
func _pond_loads() -> PackedFloat64Array:
	var out := PackedFloat64Array([0.0, 0.0, 0.0])
	if _rng.randf() < 0.5:
		return out
	for k in out.size():
		out[k] = [0.0, _rng.randf_range(0.0, 80.0), 63.75, INF, NAN][_rng.randi_range(0, 4)]
	return out


func _pond_bodies() -> Array:
	var bodies: Array = []
	for i in _rng.randi_range(0, 12):
		var person := _rng.randf() < 0.2
		# A body's loads are three flags of its own since protocol 7.
		var loads: int = [0, Wire.POND_HARMED, Wire.POND_PARALYSED | Wire.POND_ASLEEP,
			Wire.POND_HARMED | Wire.POND_PARALYSED | Wire.POND_ASLEEP][_rng.randi_range(0, 3)]
		bodies.append([Wire.PERSON_ID if person else _rng.randi_range(1, 0x7FFFFFFF),
			_rng.randi_range(0, 40), (Wire.POND_IS_PERSON if person else 0) | loads,
			Vector2(_rng.randf_range(-3000.0, 3000.0), _rng.randf_range(-3000.0, 3000.0)),
			_rng.randf_range(-PI, PI), _rng.randf_range(4.0, 40.0), _rng.randf(),
			_rng.randf_range(0.0, 400.0), Vector2(_rng.randf_range(-300.0, 300.0),
				_rng.randf_range(-300.0, 300.0)), _rng.randf_range(-1.0, 1.0)])
	return bodies


func _bytes(count: int) -> PackedByteArray:
	return _bytes_of(_rng, count)


static func _bytes_of(rng: RandomNumberGenerator, count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(count)
	for i in count:
		out[i] = rng.randi_range(0, 255)
	return out


## **One way a frame goes wrong**, or none: cut, stretched, flipped, a byte at
## an edge, a float made strange, the kind or type swapped, two spliced.
func _mutate(frame: PackedByteArray) -> PackedByteArray:
	var out := frame.duplicate()
	var how := _rng.randi_range(0, 9)
	match how:
		0:
			pass
		1:
			out.resize(_rng.randi_range(0, out.size()))
		2:
			out.append_array(_bytes(_rng.randi_range(1, 40)))
		3:
			for n in _rng.randi_range(1, 8):
				if not out.is_empty():
					var at := _rng.randi_range(0, out.size() - 1)
					out[at] = out[at] ^ (1 << _rng.randi_range(0, 7))
		4:
			if not out.is_empty():
				out[_rng.randi_range(0, out.size() - 1)] = [0x00, 0x7F, 0x80, 0xFF][
					_rng.randi_range(0, 3)]
		5:
			if out.size() >= 4:
				var at := _rng.randi_range(0, out.size() - 4)
				out.encode_u32(at, [0x7FC00000, 0x7F800000, 0xFF800000, 0x7F7FFFFF,
					0x00000001, 0x80000000, 0xFFFFFFFF][_rng.randi_range(0, 6)])
		6:
			if not out.is_empty():
				out[0] = _rng.randi_range(0, 10)
		7:
			if out.size() > 5:
				out[5] = _rng.randi_range(0, 10)
		8:
			var other := _valid_frame(_rng.randf() < 0.5)
			var cut := _rng.randi_range(0, mini(out.size(), other.size()))
			out = out.slice(0, cut) + other.slice(cut)
		9:
			out = _bytes(_rng.randi_range(0, 64))
	return out


## The smallest frame, found by cutting and zeroing, that still fails.
func _shrink_frame(frame: PackedByteArray, from_host: bool) -> PackedByteArray:
	var best := frame
	var tries := 0
	var changed := true
	while changed and tries < 400:
		changed = false
		for cut in [best.size() / 2, 1]:
			if best.size() - cut < 1:
				continue
			var shorter := best.slice(0, best.size() - cut)
			tries += 1
			if _fails_wire(shorter, from_host):
				best = shorter
				changed = true
				break
		if changed:
			continue
		for i in best.size():
			if best[i] == 0:
				continue
			var zeroed := best.duplicate()
			zeroed[i] = 0
			tries += 1
			if _fails_wire(zeroed, from_host):
				best = zeroed
				changed = true
				break
	return best


## **Whether an event is taken**: the gate would read it, its reader hands
## something on, and on a host the gate's own parse lets it through -- what a
## saved case says it must or must not be. Anything but an event is not.
func _taken(frame: PackedByteArray, from_host: bool) -> bool:
	if _wire_case(frame, from_host) != "read" or Wire.kind(frame) != Wire.KIND_EVENT:
		return false
	var type: int = frame[5]
	return not _take_event(type, frame).is_empty() \
		and (from_host or NetSession._parses(Wire.KIND_EVENT, type, frame))


func _fails_wire(frame: PackedByteArray, from_host: bool) -> bool:
	var why := _wire_case(frame, from_host)
	return not why.is_empty() and why != "read"


# ---------------------------------------------------------------------------
# door: a host, both listeners, callers driven by hand.
# ---------------------------------------------------------------------------

func _fuzz_door() -> void:
	_rng.seed = hash(_seed * 131 + 2)
	var runs := _cases(DOOR_RUNS)
	var bad := ""
	var steps_all := 0
	var greeted_all := 0
	var proofs_all := 0
	for run in runs:
		# One run in ten is eight times as long, for what builds up, and one in
		# four is a phone's host.
		var actions := _door_actions(DOOR_STEPS * (8 if run % 10 == 9 else 1), run % 4 == 1)
		var result: Array = await _door_run(actions)
		steps_all += actions.size()
		greeted_all += int(result[1])
		proofs_all += int(result[2])
		if not str(result[0]).is_empty():
			var small: Array = await _shrink_door(actions)
			bad = "run %d: %s -- --replay=\"door %s\"" % [run, str(result[0]),
				_door_code(small)]
			break
	var reached: PackedStringArray = []
	var never: PackedStringArray = []
	for key: String in _door_counts:
		if int(_door_counts[key]) > 0:
			reached.append("%s %d" % [key, int(_door_counts[key])])
		else:
			never.append(key)
	print("[net-fuzz] NOTE the door's counts, every run and saved case summed: %s; never:"
		% ", ".join(reached) + " %s" % (", ".join(never) if not never.is_empty() else "none"))
	# **Coverage that cannot slip**: every path the door can take, taken --
	# by the runs or by a saved case -- or the section fails, and says which.
	# Below scale 1 there are too few runs to ask it of.
	var missed := Array(never).filter(func(key: String) -> bool:
		return not DOOR_OUT_OF_REACH.has(key))
	if _scale >= 1.0:
		_says(missed.is_empty(), "door coverage: every one of the door's %d counted paths"
			% _door_counts.size() + " taken, but the %d no run here can reach"
			% DOOR_OUT_OF_REACH.size() + ("" if missed.is_empty()
				else " -- NOT: never %s" % ", ".join(PackedStringArray(missed))))
	print("[net-fuzz] NOTE %d internet listeners closed with their host, and more by the"
		% _closes + " owner's hand: %d lines from godot_mbedtls_mutex_free, which 4.7"
		% _catcher.dtls_close_lines + " prints three at a time on every close (net-hardening.md"
		+ " C.1) -- set aside, and every other engine line fails the run")
	_says(bad.is_empty(), "door: %d runs, %d steps -- callers on both"
		% [runs, steps_all] + " listeners saying anything, proving and failing to, going"
		+ " and coming back as twins -- %d greetings and %d valid proofs, nothing"
		% [greeted_all, proofs_all] + " played before a proof, no id below 2 held, no"
		+ " frame to an id not held, no bar forgotten, every book and queue in its cap%s"
		% ("" if bad.is_empty() else " -- NOT: " + bad))


## **A run's steps, drawn from the seed.** Each is an Array: `["C", id, via,
## address]` connect, `["D", id, via, what]` a datagram, `["X", id, via]` the
## transport gone, `["T", seconds]` time, `["I", how]` the owner's invites
## revoked, replaced by another or restored, and `["L"]` the LAN listener
## closing by itself (#105).
##
## **Most callers follow the script** -- greet, prove when asked, then play,
## numbering their frames as a guest does -- so the run reaches every stage of
## the door and the gate past it; one step in five says anything at all.
## **Storms** -- a dozen calls at once, from one address or several -- reach
## the door's buckets, and **bursts** -- one caller saying fifty things at
## once -- its budgets. What a caller has said is the generator's own record:
## it never knows what the host made of it, which is the point.
func _door_actions(count: int, phone := false) -> Array:
	var actions: Array = [["P"]] if phone else []
	var lines: Array = []
	var stage := {}
	var seq := {}
	# **A long run fills a book once**: more callers from distinct places than
	# it holds, so it has to forget some -- and must not forget a bar (#75).
	var fill_at := _rng.randi_range(0, count - 1) if count > DOOR_STEPS else -1
	while actions.size() < count:
		if fill_at >= 0 and actions.size() >= fill_at:
			fill_at = -1
			actions.append(["S", _pick_via(phone), NetSession.BOOK_MAX + _rng.randi_range(1,
				120)])
		var roll := _rng.randf()
		if lines.is_empty() or roll < 0.12:
			var id := _pick_id(lines)
			var via := _pick_via(phone)
			_door_line(lines, stage, seq, id, via)
			actions.append(["C", id, via, _pick_address(via, phone)])
		elif roll < 0.15:
			# A storm: callers at once, from one address or from several, each
			# greeting as it lands.
			var via := _pick_via(phone)
			var one := _pick_address(via, phone)
			var alone := _rng.randf() < 0.5
			for n in _rng.randi_range(3, 14):
				var id := _rng.randi_range(2, 0x7FFFFFFF)
				_door_line(lines, stage, seq, id, via)
				actions.append(["C", id, via, one if alone else _pick_address(via, phone)])
				actions.append(["D", id, via, _door_next(_door_line(lines, stage, seq, id,
					via, false), stage, seq)])
		elif roll < 0.18:
			# A burst: one caller, many frames, no time between them -- mostly
			# one whose script has got it as far as playing.
			var line := _playing(lines, stage)
			# Mostly clean -- an honest build's own flood, which only the
			# budgets stop -- and now and then spoiled like any other step.
			var clean := _rng.randf() < 0.7
			for n in _rng.randi_range(10, 70):
				actions.append(["D", int(line.get_slice(":", 0)), int(line.get_slice(":", 1)),
					_door_next(line, stage, seq, clean)])
		elif roll < 0.185:
			# A flood, past the frame budget -- of state frames -- or past the
			# byte budget -- of frames of a kind from a later build, at the size
			# cap -- or of ENTERs, past the event budget.
			var line := _playing(lines, stage)
			var what: String = ["state", "later", "enter"][_rng.randi_range(0, 2)]
			var many := _rng.randi_range(260, 400)
			actions.append(["F", int(line.get_slice(":", 0)), int(line.get_slice(":", 1)), what,
				many, int(seq[line]) + 1])
			seq[line] = int(seq[line]) + many
		elif roll < 0.19:
			# A trickle: a guest's events, under its budgets for half a minute,
			# while nothing here reads its queue.
			var line := _playing(lines, stage)
			for n in _rng.randi_range(18, 28):
				for m in 4:
					actions.append(["D", int(line.get_slice(":", 0)),
						int(line.get_slice(":", 1)), _door_next(line, stage, seq, true,
							"event")])
				actions.append(["T", 1.0])
		elif roll < 0.84:
			var line: String = lines[_rng.randi_range(0, lines.size() - 1)]
			actions.append(["D", int(line.get_slice(":", 0)), int(line.get_slice(":", 1)),
				_door_next(line, stage, seq)])
		elif roll < 0.91:
			var line: String = lines[_rng.randi_range(0, lines.size() - 1)]
			actions.append(["X", int(line.get_slice(":", 0)), int(line.get_slice(":", 1))])
		elif roll < 0.93:
			actions.append(["I", ["revoke", "replace", "restore", "restore"][
				_rng.randi_range(0, 3)]])
		elif roll < 0.934:
			actions.append(["L"])
		else:
			actions.append(["T", [0.05, 0.4, 1.2, 3.5, 7.0, 31.0, 61.0][
				_rng.randi_range(0, 6)]])
	return actions


## A line whose script has got it as far as playing, mostly; any line if
## none has, and now and then anyway.
func _playing(lines: Array, stage: Dictionary) -> String:
	var playing := lines.filter(func(each: String) -> bool:
		return int(stage[each]) == 2)
	if not playing.is_empty() and _rng.randf() < 0.85:
		return playing[_rng.randi_range(0, playing.size() - 1)]
	return lines[_rng.randi_range(0, lines.size() - 1)]


## A caller's line, `id:via`, made fresh when [param fresh]: it says nothing
## yet. Returns the line.
func _door_line(lines: Array, stage: Dictionary, seq: Dictionary, id: int, via: int,
		fresh := true) -> String:
	var line := _line(id, via)
	if not lines.has(line):
		lines.append(line)
	if fresh:
		stage[line] = 0
		seq[line] = 0
	return line


## **What [param line] says next**, by the script or, one time in five, not
## -- always by it when [param clean]; once playing, only [param only] when it
## names a state frame or an event.
func _door_next(line: String, stage: Dictionary, seq: Dictionary,
		clean := false, only := "") -> Array:
	var via := int(line.get_slice(":", 1))
	if not clean and _rng.randf() < 0.2:
		return _door_bytes()
	if int(stage[line]) == 0:
		stage[line] = 1 if via == NetSession.VIA_NET else 2
		return ["hello", Wire.PROTOCOL if _rng.randf() < 0.92 else _rng.randi_range(0, 9)]
	if int(stage[line]) == 1:
		stage[line] = 2
		return ["proof", ["good", "good", "good", "new key", "wrong mac", "other key"][
			_rng.randi_range(0, 5)]]
	seq[line] = int(seq[line]) + 1
	var frame := _guest_frame(int(seq[line]), only)
	return ["raw", frame if clean or _rng.randf() < 0.85 else _mutate(frame)]


## **A frame an honest guest sends**: a state frame, or one of its events --
## or only one of those, when [param only] says which.
func _guest_frame(next: int, only := "") -> PackedByteArray:
	var at := Vector2(_rng.randf_range(-3000.0, 3000.0), _rng.randf_range(-3000.0, 3000.0))
	var radius := _rng.randf_range(CellBody.BASE_RADIUS, CellBody.DIVIDE_RADIUS)
	var tiers := _tiers()
	var pick := _rng.randi_range(0, 9)
	if only == "state":
		pick = 0
	elif only == "event":
		pick = _rng.randi_range(4, 9)
	match pick:
		0, 1, 2, 3:
			return Wire.state(next, _rng.randf() < 0.9, at, _rng.randf_range(-PI, PI), radius,
				Vector2.from_angle(_rng.randf_range(-PI, PI)) * _rng.randf_range(0.0, 900.0),
				_rng.randf_range(-1.4, 1.4), [Wire.STATE_POND, 0, Wire.STATE_OUT
					| Wire.STATE_POND][_rng.randi_range(0, 2)])
		4:
			return Wire.shout(next, at, radius, Stats.table(&"ping_range")[
				_rng.randi_range(1, Stats.table(&"ping_range").size() - 1)])
		5:
			return Wire.event(next, Wire.EVENT_ENTER, Wire.enter_payload(radius))
		6:
			return Wire.event(next, Wire.EVENT_PERSON, Wire.person_payload(_rng.randf() < 0.5,
				tiers, tiers.keys()))
		7:
			return Wire.event(next, Wire.EVENT_DIED, Wire.died_payload(_rng.randi_range(1, 4),
				_rng.randi_range(0, 2), at))
	return Wire.event(next, Wire.EVENT_SISTER, Wire.sister_payload(at,
		_rng.randf_range(-PI, PI), Referee.DAUGHTER_RADIUS, tiers))


## A listener to call: mostly the internet one on the dedicated host, and on a
## phone's -- which has no other -- the LAN one.
func _pick_via(phone: bool) -> int:
	if phone:
		return NetSession.VIA_LAN
	return NetSession.VIA_NET if _rng.randf() < 0.6 else NetSession.VIA_LAN


## A new id, one of the lines' again -- a twin on the other listener, or the
## same caller back -- or one no Godot build picks.
func _pick_id(lines: Array) -> int:
	var roll := _rng.randf()
	if not lines.is_empty() and roll < 0.25:
		return int(str(lines[_rng.randi_range(0, lines.size() - 1)]).get_slice(":", 0))
	if roll < 0.32:
		return [-5, -1, -0x7FFFFFFF, 0, 1][_rng.randi_range(0, 4)]
	return _rng.randi_range(2, 0x7FFFFFFF)


## Mostly an address the listener takes -- a house address on the LAN one --
## and now and then one it must not.
func _pick_address(via: int, phone := false) -> String:
	# **A phone's callers are mostly its own**: its /24 and loopback, all its
	# door answers (#104), so its runs reach past the door as a host's do.
	if phone and via == NetSession.VIA_LAN and _rng.randf() < 0.6:
		if _rng.randf() < 0.3:
			return "127.0.0.%d" % _rng.randi_range(1, 254)
		return _home_prefix() + str(_rng.randi_range(1, 254))
	# No address at all, which `_address_of` says of a peer ENet no longer
	# holds: a key like any other to the door's book (#75).
	if _rng.randf() < 0.02:
		return ""
	var choice := _rng.randi_range(0, 6)
	if via == NetSession.VIA_LAN and _rng.randf() < 0.75:
		choice = _rng.randi_range(0, 2)
	match choice:
		0:
			return "127.0.0.1"
		1:
			return "192.168.%d.%d" % [_rng.randi_range(0, 255), _rng.randi_range(1, 254)]
		2:
			return "10.%d.%d.%d" % [_rng.randi_range(0, 255), _rng.randi_range(0, 255),
				_rng.randi_range(1, 254)]
		3:
			return "203.0.113.%d" % _rng.randi_range(1, 254)
		4:
			return "198.51.100.%d" % _rng.randi_range(1, 254)
		5:
			# Now and then a neighbour: one of four /64s under one /56, which the
			# internet door bars as a whole once three of them are (#103).
			if _rng.randf() < 0.5:
				return "2001:db8:0:%x::%x" % [0x100 + _rng.randi_range(0, 3),
					_rng.randi_range(1, 0xFFFF)]
			return "2001:db8::%x" % _rng.randi_range(1, 0xFFFF)
	return "fd00::%x" % _rng.randi_range(1, 0xFFFF)


## **The /24 a phone host here answers** (#104), as "a.b.c.": the one it will
## host at -- in CI's namespace, 10.77.0.0/24 -- asked once.
func _home_prefix() -> String:
	if _home.is_empty():
		_home = Lan.prefix_of(Lan.hosting_address())
		if _home.is_empty():
			_home = "10.77.0."
	return _home


## **What a caller says next**: a greeting, a proof (right, wrong, or before
## it was asked for), a body, an event, junk -- or any of them spoiled. A
## proof is written when the run reaches it, against the nonce it was sent;
## here it is only named.
func _door_bytes() -> Array:
	var roll := _rng.randi_range(0, 11)
	match roll:
		0, 1:
			return ["hello", Wire.PROTOCOL if _rng.randf() < 0.85 else _rng.randi_range(0, 9)]
		2, 3:
			return ["proof", ["good", "good", "new key", "wrong mac", "other key"][
				_rng.randi_range(0, 4)]]
		4:
			return ["raw", Wire.state(_rng.randi_range(0, 99), true, Vector2(
				_rng.randf_range(-500.0, 500.0), _rng.randf_range(-500.0, 500.0)), 0.0, 26.0)]
		5:
			return ["raw", _valid_frame(false)]
		6, 7:
			return ["raw", _mutate(_valid_frame(false))]
		8:
			return ["raw", _bytes(_rng.randi_range(0, 30))]
		9:
			return ["bare", _bytes(_rng.randi_range(0, 12))]
		10:
			# **Past a cap**: past the one every frame but a SISTER keeps, up to
			# past the most any guest frame may be -- one in four a SISTER, the
			# one kind allowed between the two (protocol 6).
			var big := PackedByteArray()
			big.resize(_rng.randi_range(Wire.GUEST_OTHER_MAX + 1, Wire.GUEST_FRAME_MAX + 200))
			big[0] = Wire.KIND_EVENT
			big[5] = Wire.EVENT_SISTER if _rng.randf() < 0.25 else _rng.randi_range(0, 10)
			return ["raw", big]
	return ["raw", Wire.challenge(_bytes(Wire.NONCE_SIZE))]


## **One run on a fresh host**: `[why it failed or "", greetings, proofs]`. A
## run that opens with `["P"]` is a phone's: one guest, no internet listener,
## and its events queued in the host's own share.
func _door_run(actions: Array) -> Array:
	var phone := not actions.is_empty() and str(actions[0][0]) == "P"
	var host := await _fresh_host(phone)
	if host == null:
		return ["could not host: " + _no_host, 0, 0]
	# What the fuzzer knows of each transport, by its line -- where in
	# `host.sent` it began, how many datagrams it has sent, the invite it
	# proved -- and which invite the owner holds now: "first", "second" or
	# none.
	var run := {"began": {}, "said": {}, "proved": {}, "invite": "first", "door": ""}
	var proofs := 0
	# Each listener's barred callers after the last step, key -> until, and
	# how many bars the host had made by then.
	var bars := [{}, {}, 0]
	host.net_seen = host._net_peer
	for action: Array in _expanded(actions):
		var errors := _catcher.errors()
		var sent_before := host.sent.size()
		var net_before := host.net_seen
		# Every caller on the internet listener yet to prove, and where from.
		var unproved := {}
		for id: int in host._peers:
			var peer: Dictionary = host._peers[id]
			if not bool(peer["greeted"]) \
					and int(peer.get("via", NetSession.VIA_LAN)) == NetSession.VIA_NET:
				unproved[id] = str(peer["address"])
		proofs += int(_door_step(host, action, run))
		_settle_drops(host)
		if host.net_seen != net_before:
			# A listener closed takes its book with it, bars and all.
			bars[NetSession.VIA_NET] = {}
		var why := str(run["door"])
		if why.is_empty():
			why = _door_why(host, run["proved"])
		if why.is_empty():
			why = _told_why(host, sent_before, run["proved"])
		if why.is_empty():
			why = _bars_why(host, bars)
		if why.is_empty() and host.net_seen == net_before:
			why = _left_why(host, unproved, run["proved"])
		if why.is_empty() and _catcher.errors() > errors:
			why = "an error: " + _catcher.last
		if why.is_empty() and not host.misaddressed.is_empty():
			why = host.misaddressed
		if not why.is_empty():
			return ["after %s: %s" % [_door_code([action]), why], _welcomes(host), proofs]
	for key: String in host.gate_counts:
		if not key.begins_with("peak") and not key.begins_with("would") \
				and not key.contains("points"):
			_door_counts[key] = int(_door_counts.get(key, 0)) + int(host.gate_counts[key])
	return ["", _welcomes(host), proofs]


## [param actions] with each compact step written out, so every check runs
## after each datagram and each caller -- a replay keeps them one step each:
##
##   - **a book filled**, `["S", via, count]`: count callers, each from a place
##     of its own, a /64 of the documentation prefix on the internet listener
##     and of a unique-local one on the LAN;
##   - **a flood**, `["F", id, via, what, count, first]`: count frames from
##     one transport at once -- state frames, ENTERs or shouts numbered from
##     first, or frames of a kind from a later build at the size cap.
static func _expanded(actions: Array) -> Array:
	var out: Array = []
	for action: Array in actions:
		match str(action[0]):
			"S":
				var via := int(action[1])
				for i in int(action[2]):
					out.append(["C", 0x40000000 + i, via, ("2001:db8:%x::1"
						if via == NetSession.VIA_NET else "fd00:%x::1") % i])
			"F":
				for i in int(action[4]):
					out.append(["D", int(action[1]), int(action[2]), ["raw",
						_flood_frame(str(action[3]), int(action[5]) + i)]])
			_:
				out.append(action)
	return out


static func _flood_frame(what: String, seq: int) -> PackedByteArray:
	match what:
		"state":
			return Wire.state(seq, true, Vector2(10.0, 20.0), 0.5, 26.0, Vector2(100.0, 0.0),
				0.2, Wire.STATE_POND)
		"enter":
			return Wire.event(seq, Wire.EVENT_ENTER, Wire.enter_payload(26.0))
		"shout":
			return Wire.shout(seq, Vector2(10.0, 20.0), 26.0, 400.0)
	# At the cap a frame of a later build's kind is held to: every frame but a
	# SISTER's.
	var later := PackedByteArray()
	later.resize(Wire.GUEST_OTHER_MAX)
	later[0] = 0x20
	return later


static func _welcomes(host: FuzzHost) -> int:
	var count := 0
	for each: Array in host.sent:
		if Wire.kind(each[1]) == Wire.KIND_WELCOME:
			count += 1
	return count


## **A host, fresh**: the dedicated server's two-guest host with both
## listeners, or a phone's with the LAN one alone. Null, and [member _no_host]
## says why, when it cannot open.
func _fresh_host(phone: bool) -> FuzzHost:
	if _host != null and is_instance_valid(_host):
		if _host._net_peer != null:
			_closes += 1
		_host.close()
		_host = null
		await get_tree().process_frame
	var host := FuzzHost.new()
	host.name = "FuzzHost"
	add_child(host)
	_host = host
	host.loopback_is_local = true
	if not host.host(1 if phone else NetSession.GUESTS_MAX):
		_no_host = "this machine has no address a LAN host can use, or %d is taken" \
			% Lan.channel_port()
		return null
	# Driven by hand from here: its frames are the fuzzer's steps, not the
	# engine's.
	host.set_process(false)
	if get_tree().process_frame.is_connected(host._on_tree_frame):
		get_tree().process_frame.disconnect(host._on_tree_frame)
	# **The outside must be outside**: the callers meant as strangers call
	# from documentation ranges, which the namespace's own address must not
	# share -- or the LAN door would be right to let them in.
	for stranger: String in ["203.0.113.9", "198.51.100.9", "2001:db8::9"]:
		if Lan.is_local_source(stranger, host.address):
			_no_host = "this namespace's address, %s, makes %s a house address" % [
				host.address, stranger]
			return null
	if not phone:
		if not host.listen_internet(_key, _cert):
			_no_host = "%d is taken" % Invite.channel_port()
			return null
		host.set_invites({_key_id.hex_encode(): [LABEL, _secret]})
	# One frame taken, as a real host has before anybody calls: otherwise the
	# first frame here would read as coming after a stall, and be credited.
	host._on_tree_frame()
	return host


## Runs one step; true when it was a valid proof.
func _door_step(host: FuzzHost, action: Array, run: Dictionary) -> bool:
	var began: Dictionary = run["began"]
	var said: Dictionary = run["said"]
	var proved: Dictionary = run["proved"]
	match str(action[0]):
		"C":
			var id := int(action[1])
			var via := int(action[2])
			var line := _line(id, via)
			var held: Dictionary = host.connected[via]
			# ENet holds one peer an id on each listener, drops a caller
			# offering 0 or 1 itself (measured on 4.7), and turns away one past
			# its peer count -- all before any signal.
			if held.has(id) or id == 0 or id == 1 or held.size() >= host._slots():
				return false
			if via == NetSession.VIA_NET and not host.internet_listening():
				return false
			# Nor on a LAN listener closed, and not open again yet (#105).
			var lan: Variant = host.get("_peer")
			if via == NetSession.VIA_LAN and (lan == null
					or lan.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED):
				return false
			held[id] = true
			host.where[line] = str(action[3])
			began[line] = host.sent.size()
			said[line] = 0
			proved.erase(line)
			# **What the door does with a call** (#103): one from a barred
			# address -- or on the internet door, from a barred /56 -- is never
			# taken, before the call or after the room it made; one it turns
			# away spends nothing of the bucket every address shares; and room
			# is made only by the caller on the internet listener that has
			# waited longest, [constant NetSession.EVICT_AFTER] or more, and
			# never from the newcomer's own address or /56. Time stands still
			# inside a step, so the bucket's level can only fall by what a take
			# spends.
			var from := str(action[3])
			var book: Dictionary = host._book if via == NetSession.VIA_LAN else host._net_book
			var barred := _barred_now(book, from, via, host.now_at)
			var everybody: Variant = host._calls_all if via == NetSession.VIA_LAN \
				else host._net_calls_all
			var level: float = everybody.level(host.now_at) if everybody != null else 0.0
			var waiting := {}
			for other: int in host._peers:
				var peer: Dictionary = host._peers[other]
				if not bool(peer["greeted"]) \
						and int(peer.get("via", NetSession.VIA_LAN)) == NetSession.VIA_NET:
					waiting[other] = peer
			var evicted := int(host.gate_counts["net_evicted"])
			host._on_peer_connected(id, via)
			var taken := host._peers.has(id) and int(host._via.get(id, -1)) == via
			if taken and (barred or _barred_now(book, from, via, host.now_at)):
				run["door"] = "a call from %s was taken at the door while it is barred" % from
			elif not taken and everybody != null and everybody.level(host.now_at) < level:
				run["door"] = "a call from %s turned away at the door spent the bucket" % from \
					+ " every address shares"
			elif int(host.gate_counts["net_evicted"]) > evicted:
				run["door"] = _evicted_why(host, waiting, from)
		"D":
			var id := int(action[1])
			var via := int(action[2])
			var line := _line(id, via)
			if not bool((host.connected[via] as Dictionary).get(id, false)):
				return false
			# What this transport sent before this datagram: a proof is valid
			# only as its second, after its one HELLO -- the gate's own rule.
			var before := int(said.get(line, 0))
			said[line] = before + 1
			var what: Array = action[3]
			var frame := PackedByteArray()
			var good := false
			match str(what[0]):
				"hello":
					frame = Wire.hello(int(what[1]), _tail)
				"proof":
					var nonce := _nonce_for(host, id, int(began.get(line, 0)))
					var mine := PackedByteArray()
					mine.resize(Wire.NONCE_SIZE)
					mine.fill(7)
					var key_id := _key_id
					var secret := _secret
					var holds := "first"
					if str(what[1]) == "new key":
						key_id = _key_id_2
						secret = _secret_2
						holds = "second"
					elif str(what[1]) == "wrong mac":
						secret = PackedByteArray([1, 2, 3])
						holds = ""
					elif str(what[1]) == "other key":
						key_id = PackedByteArray([9, 9, 9, 9, 9, 9, 9, 9])
						holds = ""
					frame = Wire.proof(key_id, mine, Invite.proof_mac(secret, Wire.PROTOCOL,
						nonce, mine, key_id))
					# Valid: an invite the owner holds now, over the nonce this
					# transport was sent, as its second datagram, on the listener
					# that asks for one.
					good = not holds.is_empty() and str(run["invite"]) == holds \
						and before == 1 and nonce.size() == Wire.NONCE_SIZE \
						and via == NetSession.VIA_NET
					if good:
						proved[line] = holds
				"raw":
					frame = what[1]
				"bare":
					host._take_datagram(id, what[1], via)
					return false
			var bytes := PackedByteArray([NetSession.RAW])
			bytes.append_array(frame)
			host._take_datagram(id, bytes, via)
			return good
		"X":
			var id := int(action[1])
			var via := int(action[2])
			if not bool((host.connected[via] as Dictionary).get(id, false)):
				return false
			(host.connected[via] as Dictionary).erase(id)
			host._on_peer_disconnected(id, via)
		"T":
			host.now_at += float(action[1])
			host._on_tree_frame()
			host._process(0.016)
		"L":
			# **The LAN listener closes by itself** (#105), as ENet closes one
			# whose service fails: its transports go with it, saying nothing,
			# and the host's next frame finds it closed.
			var enet: Variant = host.get("_peer")
			if enet == null:
				return false
			(host.connected[NetSession.VIA_LAN] as Dictionary).clear()
			enet.close()
			host._on_tree_frame()
		"I":
			# The owner, at the server's console: every guest who proved the
			# invite taken away is cut, and none left closes the listener.
			match str(action[1]):
				"revoke":
					run["invite"] = ""
					host.set_invites({})
				"replace":
					run["invite"] = "second"
					host.set_invites({_key_id_2.hex_encode(): [LABEL, _secret_2]})
				"restore":
					if host.listen_internet(_key, _cert):
						run["invite"] = "first"
						host.set_invites({_key_id.hex_encode(): [LABEL, _secret]})
			# A proof of an invite the owner no longer holds proves nothing
			# from here: its guest must be gone.
			for line: String in proved.keys():
				if str(proved[line]) != str(run["invite"]):
					proved.erase(line)
	return false


## One transport: an id on one listener. A twin on the other is another.
static func _line(id: int, via: int) -> String:
	return "%d:%d" % [id, via]


## The nonce of the last CHALLENGE [param host] sent [param id] since
## [param since] in its sent list -- this transport's -- or empty.
func _nonce_for(host: FuzzHost, id: int, since: int) -> PackedByteArray:
	for i in range(host.sent.size() - 1, since - 1, -1):
		var sent: Array = host.sent[i]
		var frame: PackedByteArray = sent[1]
		if int(sent[0]) == id and Wire.kind(frame) == Wire.KIND_CHALLENGE:
			return Wire.challenge_nonce(frame)
	return PackedByteArray()


## **ENet, as the fuzzer plays it**: a transport the host cut is gone at the
## next service, and says so -- and a listener the host closed takes every
## transport on it, and says nothing: the host has already let them go.
func _settle_drops(host: FuzzHost) -> void:
	if host._net_peer != host.net_seen:
		(host.connected[NetSession.VIA_NET] as Dictionary).clear()
		host.drops = host.drops.filter(func(drop: Array) -> bool:
			return int(drop[0]) != NetSession.VIA_NET)
		host.net_seen = host._net_peer
	var guard := 0
	while not host.drops.is_empty() and guard < 1024:
		guard += 1
		var drop: Array = host.drops.pop_front()
		var via := int(drop[0])
		var id := int(drop[1])
		var held: Dictionary = host.connected[via]
		if held.has(id):
			held.erase(id)
			host._on_peer_disconnected(id, via)


## **Everything that must hold after a step**, or what does not.
func _door_why(host: FuzzHost, proved: Dictionary) -> String:
	if host._greeted_count() > host.guests_max:
		return "%d greeted, past %d" % [host._greeted_count(), host.guests_max]
	for id: int in host._peers.keys():
		var peer: Dictionary = host._peers[id]
		var via := int(peer.get("via", NetSession.VIA_LAN))
		if id < NetSession.PEER_ID_MIN:
			return "a peer held under id %d" % id
		if not host._via.has(id) or int(host._via[id]) != via:
			return "peer %d's listener is %s in _via and %d in its record" % [id,
				str(host._via.get(id, "none")), via]
		if not bool((host.connected[via] as Dictionary).get(id, false)):
			return "peer %d held on a listener it is not connected to" % id
		if not bool(peer["greeted"]) and (int(peer["in_state"]) >= 0
				or int(peer["in_event"]) >= 0 or int(peer["in_pond"]) >= 0
				or not (peer["track"] as Array).is_empty()):
			return "peer %d is not greeted, and something it said was taken" % id
		if bool(peer["greeted"]) and int(peer["protocol"]) != Wire.PROTOCOL:
			return "peer %d greeted, speaking protocol %d" % [id, int(peer["protocol"])]
		if bool(peer["greeted"]) and via == NetSession.VIA_NET \
				and not proved.has(_line(id, via)):
			return "peer %d greeted on the internet listener with no valid proof" % id
		# **The budgets hold**: what a peer's frames were taken to, against
		# what its buckets could have paid since it connected. No stall is ever
		# credited here -- every step that moves time takes a frame first.
		var guard: Object = peer["guard"]
		var age := host.now_at - float(peer["since"])
		for paid: Array in [[guard.taken, guard.frames, "frames"], [guard.taken_bytes,
				guard.bytes, "bytes"], [guard.taken_events, guard.events, "events"]]:
			var bucket: Object = paid[1]
			if float(paid[0]) > bucket.burst + bucket.rate * age + 0.5:
				return "peer %d was taken %d %s in %.2f s, past %d at once and %d a second" % [
					id, int(paid[0]), str(paid[2]), age, roundi(bucket.burst),
					roundi(bucket.rate)]
		if via == NetSession.VIA_LAN and not Lan.is_local_source(str(peer["address"]),
				host.address):
			return "peer %d from %s let in on the LAN listener" % [id, str(peer["address"])]
		# A phone's LAN door is its own /24 and loopback (#104).
		if via == NetSession.VIA_LAN and host.guests_max == 1 \
				and not Lan.is_loopback(str(peer["address"])) \
				and not Lan.same_24(str(peer["address"]), host.address):
			return "peer %d from %s let in by a phone host at %s, outside its /24" % [id,
				str(peer["address"]), host.address]
	for id: int in host._via.keys():
		if not host._peers.has(id) and not host._hanging_up.has(id):
			return "id %d kept in _via with no peer and nothing to hang up" % id
	# **The dedicated host's queue**: only greeted guests' events, and each
	# guest's inside its own share.
	var load := {}
	for said: Array in host.inbox:
		var from := int(said[0])
		var peer: Dictionary = host._peers.get(from, {})
		if peer.is_empty() or not bool(peer["greeted"]):
			return "an event from %d queued, which is no guest here" % from
		var had: Array = load.get(from, [0, 0])
		load[from] = [int(had[0]) + 1, int(had[1]) + (said[1] as PackedByteArray).size()]
	for from: int in load:
		if int(load[from][0]) > NetSession.QUEUE_FRAMES \
				or int(load[from][1]) > NetSession.QUEUE_BYTES:
			return "guest %d has %d events of %d bytes queued, past its share" % [from,
				int(load[from][0]), int(load[from][1])]
	# **A phone host's queue** is its one guest's, inside a host's own share.
	if host.pond_events.size() > NetSession.QUEUE_FRAMES \
			or host._pond_bytes > NetSession.QUEUE_BYTES \
			or host.heard.size() > NetSession.HEARD_MAX:
		return "a queue past its cap: %d events of %d bytes, %d shouts heard" % [
			host.pond_events.size(), host._pond_bytes, host.heard.size()]
	if host._book.size() > NetSession.BOOK_MAX or host._net_book.size() > NetSession.BOOK_MAX \
			or host._notes.size() > NetSession.NOTES_MAX:
		return "a book past its cap"
	for id: int in host._addresses.keys():
		if not host._via.has(id):
			return "id %d's address kept, and no listener holds it" % id
	# **A LAN listener that closed by itself is open again inside a second**
	# (#105): at once, or -- closing again inside a second of opening -- a
	# second after it opened, since this port is never anybody else's. Every
	# step that moves time runs a frame.
	var lan: Variant = host.get("_peer")
	var closed: bool = lan != null \
		and lan.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
	if closed and host.now_at >= host._lan_down_since + NetSession.LAN_REOPEN_EVERY:
		return "the LAN listener closed at %.2f, and is still closed at %.2f" % [
			host._lan_down_since, host.now_at]
	if closed != (host._lan_down_since >= 0.0):
		return "the LAN listener is %s, and the host thinks it %s" % [
			"closed" if closed else "open", "closed" if host._lan_down_since >= 0.0
				else "open"]
	return ""


## **A bar outlives a full book** (#75): a caller the door barred stays
## barred until its time is up. A full book may forget a barred caller only
## once every caller in it is barred -- so one gone early, while the book kept
## a caller it already held unbarred, is a failure. [param bars] is each
## listener's barred callers after the last step and the host's count of bars
## then, and is brought up to date: in full only when that count has moved,
## since only `_bar` makes one, and a filling book is checked after every
## caller.
## Whether [param key] is barred in [param book] at [param now]: never for
## "", which is no key at all.
static func _barred_in(book: Dictionary, key: String, now: float) -> bool:
	return not key.is_empty() and book.has(key) and now < float(book[key]["barred_until"])


## **Every way out of the internet waiting room without a proof bars** (#103):
## "" if each caller of [param unproved] -- id -> address, every caller on the
## internet listener yet to prove before the step -- that has gone left its
## address barred, or had proved an invite on its way out ("already two"). A
## book full of bars may forget one, and a listener closing bars nobody.
static func _left_why(host: FuzzHost, unproved: Dictionary, proved: Dictionary) -> String:
	if not host.internet_listening():
		return ""
	var book: Dictionary = host._net_book
	for id: int in unproved:
		if host._peers.has(id) or proved.has(_line(id, NetSession.VIA_NET)):
			continue
		var key := Lan.source_key(str(unproved[id]))
		if key.is_empty() or _barred_in(book, key, host.now_at) \
				or (not book.has(key) and book.size() >= NetSession.BOOK_MAX):
			continue
		return "%d (%s) left the internet listener's waiting room with nothing proved," % [
			id, str(unproved[id])] + " and its address is not barred"
	return ""


## Whether a call from [param from] on [param via] finds its address barred at
## [param now] -- or on the internet door, its /56.
static func _barred_now(book: Dictionary, from: String, via: int, now: float) -> bool:
	return _barred_in(book, Lan.source_key(from), now) or (via == NetSession.VIA_NET
		and _barred_in(book, Lan.wider_key(from), now))


## **Room made for a call from [param from]** (#103): "" if the caller it took
## the place of, out of [param waiting] -- every unproved caller on the
## internet listener just before, by id -- had waited longest, at least
## [constant NetSession.EVICT_AFTER], and called from neither the newcomer's
## address nor its /56.
static func _evicted_why(host: FuzzHost, waiting: Dictionary, from: String) -> String:
	var gone: Array = []
	var eldest := INF
	for other: int in waiting:
		eldest = minf(eldest, float(waiting[other]["since"]))
		if not host._peers.has(other):
			gone.append(other)
	if gone.size() != 1:
		return "room made for %s, and %d callers gone from the waiting room" % [from,
			gone.size()]
	var elder: Dictionary = waiting[gone[0]]
	var there := str(elder["address"])
	var waited := host.now_at - float(elder["since"])
	if float(elder["since"]) > eldest:
		return "room made for %s by pushing out %d, which had not waited longest" % [from,
			int(gone[0])]
	if waited < NetSession.EVICT_AFTER:
		return "room made for %s by pushing out %d after %.2f s" % [from, int(gone[0]),
			waited]
	if Lan.source_key(there) == Lan.source_key(from) or (not Lan.wider_key(from).is_empty()
			and Lan.wider_key(there) == Lan.wider_key(from)):
		return "room made for %s by pushing out %d, from its own address or /56 (%s)" % [
			from, int(gone[0]), there]
	return ""


static func _bars_why(host: FuzzHost, bars: Array) -> String:
	var now := host.now_at
	var made := int(host.gate_counts["bars"])
	for via: int in [NetSession.VIA_LAN, NetSession.VIA_NET]:
		var book: Dictionary = host._book if via == NetSession.VIA_LAN else host._net_book
		var had: Dictionary = bars[via]
		var still := {}
		for key: String in had:
			var until := float(had[key])
			if until <= now:
				continue
			var entry: Dictionary = book.get(key, {})
			if not entry.is_empty() and float(entry["barred_until"]) >= until:
				still[key] = float(entry["barred_until"])
				continue
			# Within a step the clock stands still, so a caller seen before it
			# and unbarred now was unbarred the whole step: the one to forget.
			for other: String in book:
				var kept: Dictionary = book[other]
				if float(kept["barred_until"]) <= now and float(kept["seen"]) < now:
					return "the bar on %s, until %.1f s, was forgotten at %.1f s while" % [
						"\"%s\"" % key, until, now] + " %s, not barred, was kept" % (
						"\"%s\"" % other)
		if made != int(bars[2]):
			still = {}
			for key: String in book:
				if float(book[key]["barred_until"]) > now:
					still[key] = float(book[key]["barred_until"])
		bars[via] = still
	bars[2] = made
	return ""


## **Nothing but the handshake reaches a caller on the internet listener
## before its proof**: a CHALLENGE, or a REFUSE on its way out.
func _told_why(host: FuzzHost, since: int, proved: Dictionary) -> String:
	for i in range(since, host.sent.size()):
		var id := int(host.sent[i][0])
		var kind := Wire.kind(host.sent[i][1])
		if int(host.sent[i][2]) != NetSession.VIA_NET or proved.has(_line(id,
				NetSession.VIA_NET)):
			continue
		if kind != Wire.KIND_CHALLENGE and kind != Wire.KIND_REFUSE:
			return "a frame of kind %d went to %d on the internet listener before any" % [kind,
				id] + " valid proof"
	return ""


## Actions written so a `--replay=` can read them back.
static func _door_code(actions: Array) -> String:
	var parts: PackedStringArray = []
	for action: Array in actions:
		match str(action[0]):
			"C":
				parts.append("C:%d:%d:%s" % [int(action[1]), int(action[2]), str(action[3])])
			"D":
				var what: Array = action[3]
				var payload := str(what[1]) if what[0] in ["hello", "proof"] \
					else (what[1] as PackedByteArray).hex_encode()
				parts.append("D:%d:%d:%s:%s" % [int(action[1]), int(action[2]), str(what[0]),
					payload.replace(" ", "_")])
			"X":
				parts.append("X:%d:%d" % [int(action[1]), int(action[2])])
			"L":
				parts.append("L")
			"T":
				parts.append("T:%s" % str(action[1]))
			"I":
				parts.append("I:%s" % str(action[1]))
			"S":
				parts.append("S:%d:%d" % [int(action[1]), int(action[2])])
			"F":
				parts.append("F:%d:%d:%s:%d:%d" % [int(action[1]), int(action[2]),
					str(action[3]), int(action[4]), int(action[5])])
			"P":
				parts.append("P")
	return "|".join(parts)


static func _door_read(code: String) -> Array:
	var actions: Array = []
	for part: String in code.split("|", false):
		var f := part.split(":")
		match f[0]:
			"C":
				# An IPv6 address keeps its colons: everything after the via.
				actions.append(["C", int(f[1]), int(f[2]), ":".join(f.slice(3))])
			"D":
				var kind := f[3]
				var payload := ":".join(f.slice(4)).replace("_", " ")
				var what: Array
				if kind == "hello":
					what = ["hello", int(payload)]
				elif kind == "proof":
					what = ["proof", payload]
				else:
					what = [kind, payload.hex_decode()]
				actions.append(["D", int(f[1]), int(f[2]), what])
			"X":
				actions.append(["X", int(f[1]), int(f[2])])
			"L":
				actions.append(["L"])
			"T":
				actions.append(["T", float(f[1])])
			"I":
				actions.append(["I", f[1]])
			"S":
				actions.append(["S", int(f[1]), int(f[2])])
			"F":
				actions.append(["F", int(f[1]), int(f[2]), f[3], int(f[4]), int(f[5])])
			"P":
				actions.append(["P"])
	return actions


## **The fewest of [param actions] that still fail**: halves, then quarters,
## and so on down to single steps, each taken out while the run still fails.
func _shrink_door(actions: Array) -> Array:
	var best := actions.duplicate()
	var chunk := maxi(best.size() / 2, 1)
	var tries := 0
	while tries < 400:
		var at := 0
		var cut := false
		while at < best.size() and tries < 400:
			var without := best.slice(0, at) + best.slice(at + chunk)
			tries += 1
			if not without.is_empty() and not str((await _door_run(without))[0]).is_empty():
				best = without
				cut = true
			else:
				at += chunk
		if chunk == 1 and not cut:
			break
		chunk = maxi(chunk / 2, 1)
	return best


# ---------------------------------------------------------------------------
# guest: the other end of the handshake.
# ---------------------------------------------------------------------------

func _fuzz_guest() -> void:
	_rng.seed = hash(_seed * 2027 + 6)
	var runs := _cases(GUEST_RUNS)
	var bad := ""
	var frames := 0
	var proofs := 0
	var foreign := 0
	for run in runs:
		var by_invite := run % 2 == 1
		var steps := _guest_steps(by_invite)
		var result: Array = await _guest_run(by_invite, steps)
		frames += steps.size()
		proofs += int(result[1])
		foreign += int(result[2])
		if not str(result[0]).is_empty():
			var small: Array = await _shrink_guest(by_invite, steps)
			bad = "run %d: %s -- --replay=\"guest %s\"" % [run, str(result[0]),
				_guest_code(by_invite, small)]
			break
	_says(bad.is_empty(), "guest: %d runs, %d frames from a host, LAN calls and calls by"
		% [runs, frames] + " invite alike -- one greeting each, %d proofs, every one on a"
		% proofs + " call by invite, once, and to its host's CHALLENGE; %d WELCOMEs on other"
		% foreign + " rules or with no tail taken, each refused as different versions%s"
		% ("" if bad.is_empty() else " -- NOT: " + bad))


## **What a host says to a guest**, mostly the handshake -- a WELCOME, right
## or wrong, a REFUSE, a CHALLENGE -- and the rest of its frames, spoiled now
## and then; now and then from an id that is not the host's. `[from, frame]`.
func _guest_steps(by_invite: bool) -> Array:
	var steps: Array = []
	for step in GUEST_STEPS:
		var frame: PackedByteArray
		match _rng.randi_range(0, 7):
			0:
				frame = Wire.welcome(Wire.PROTOCOL if _rng.randf() < 0.8
					else _rng.randi_range(0, 9), _rng.randi_range(0, 9), _some_tail())
			1:
				frame = Wire.challenge(_bytes(Wire.NONCE_SIZE))
			2:
				frame = Wire.refuse(Wire.PROTOCOL, _rng.randi_range(0, 6)) \
					if _rng.randf() < 0.3 else _valid_frame(true)
			3, 4:
				frame = _valid_frame(true)
			_:
				frame = _mutate(_valid_frame(true))
		if by_invite and _rng.randf() < 0.1:
			frame = Wire.challenge(_bytes(Wire.NONCE_SIZE))
		steps.append([1 if _rng.randf() < 0.9 else _rng.randi_range(2, 9), frame])
	return steps


## **One guest, [param steps] from its host**: `[what went wrong or "",
## proofs, WELCOMEs on other rules or with no tail it took]`. On a call by invite
## it holds this run's own invite, as a player's guest does once it has pasted one.
func _guest_run(by_invite: bool, steps: Array) -> Array:
	var guest := FuzzGuest.new()
	guest.name = "FuzzGuest"
	add_child(guest)
	if by_invite:
		guest._invite = Invite.parse(Invite.format("203.0.113.7", Invite.PORT, _key_id,
			_secret, _der))
	# Its first frame is not after a stall: the clock stood where it stands. And its
	# rules taken, as a session's are when it calls.
	guest._frame_at = guest.now_at
	guest._take_rules()
	guest._set_link(NetSession.Link.REACHING)
	guest._on_peer_connected(1)
	var why := ""
	var proofs := 0
	var foreign := 0
	for step: Array in steps:
		var errors := _catcher.errors()
		var from := int(step[0])
		var frame: PackedByteArray = step[1]
		var before := guest.sent.size()
		# A proof answers a whole CHALLENGE from its host, in the step that
		# brings it, on a call that is still up.
		var nonce := Wire.challenge_nonce(frame) if from == 1 and guest._peers.has(1) \
			else PackedByteArray()
		var welcomes := guest.welcomes
		guest._on_peer_packet(from, frame)
		for i in range(before, guest.sent.size()):
			var sent: PackedByteArray = guest.sent[i][1]
			var kind := Wire.kind(sent)
			if kind != Wire.KIND_PROOF:
				why = "it sent a frame of kind %d to a host's frame" % kind
			elif not by_invite:
				why = "it proved an invite on a LAN call"
			elif int(guest.sent[i][0]) != 1 or nonce.size() != Wire.NONCE_SIZE:
				why = "it proved to something that was not its host's CHALLENGE"
			else:
				# Over that nonce and its own, with its invite's key and secret.
				var parts := Wire.proof_parts(sent)
				if parts.size() != 3 or parts[0] != _key_id or parts[2] != Invite.proof_mac(
						_secret, Wire.PROTOCOL, nonce, parts[1], _key_id):
					why = "its proof is not its invite's, over its host's nonce"
				else:
					proofs += 1
		if why.is_empty() and proofs > 1:
			why = "it proved %d times on one call" % proofs
		# **A WELCOME on other rules, or with none, is refused and never played**
		# (gene-catalogue.md §11.3): one the gate let through that is not this
		# build's protocol and rules leaves the guest refused as different versions
		# -- by invite, in the server's words -- and so never together after it.
		if why.is_empty() and guest.welcomes > welcomes \
				and (Wire.protocol_of(frame) != Wire.PROTOCOL
					or Wire.rules_of(frame) != guest._rules):
			foreign += 1
			var told := ["game_older", "server_older"].has(str(guest.trouble_key)) \
				if by_invite else guest.trouble == "different versions"
			if int(guest.link) != NetSession.Link.REFUSED or not told:
				why = "a WELCOME on protocol %d with %s left it %s, '%s'" % [
					Wire.protocol_of(frame), "no tail" if Wire.rules_of(frame).is_empty()
					else "other rules", NetSession.Link.keys()[int(guest.link)],
					guest.trouble_key if by_invite else guest.trouble]
		if why.is_empty() and _catcher.errors() > errors:
			why = "an error: " + _catcher.last
		if why.is_empty() and (guest.pond_events.size() > NetSession.POND_EVENTS_MAX
				or guest.heard.size() > NetSession.HEARD_MAX):
			why = "a queue past its cap"
		if not why.is_empty():
			why = "after %s: %s" % [_guest_code(by_invite, [step]).get_slice(" ", 1), why]
			break
	if guest.sent.is_empty() or Wire.kind(guest.sent[0][1]) != Wire.KIND_HELLO:
		why = "it did not greet its host first" if why.is_empty() else why
	guest.close()
	return [why, proofs, foreign]


static func _guest_code(by_invite: bool, steps: Array) -> String:
	var parts: PackedStringArray = []
	for step: Array in steps:
		parts.append("%d:%s" % [int(step[0]), (step[1] as PackedByteArray).hex_encode()])
	return "%s %s" % ["invite" if by_invite else "lan", "|".join(parts)]


static func _guest_read(code: String) -> Array:
	var steps: Array = []
	for part: String in code.split("|", false):
		steps.append([int(part.get_slice(":", 0)), part.get_slice(":", 1).hex_decode()])
	return steps


func _shrink_guest(by_invite: bool, steps: Array) -> Array:
	var best := steps.duplicate()
	var i := best.size() - 1
	while i >= 0:
		var without := best.duplicate()
		without.remove_at(i)
		if not without.is_empty() \
				and not str((await _guest_run(by_invite, without))[0]).is_empty():
			best = without
		i -= 1
	return best


# ---------------------------------------------------------------------------
# invite: pastes.
# ---------------------------------------------------------------------------

func _fuzz_invite() -> void:
	_rng.seed = hash(_seed * 977 + 3)
	_lone = _lone_surrogates()
	var line := Invite.format("203.0.113.7", Invite.PORT, _key_id, _secret, _der)
	var cases := _cases(INVITE_CASES)
	var bad := ""
	var ok := 0
	var engine := 0
	for i in cases:
		var paste := _mutate_paste(line)
		var engine_before := _catcher.engine_errors
		var began := Time.get_ticks_usec()
		var judged := _paste_why(paste)
		var took := float(Time.get_ticks_usec() - began) / 1000.0
		engine += _catcher.engine_errors - engine_before
		var why := str(judged[0])
		if why.is_empty() and took > 500.0:
			why = "%.0f ms to read %d characters" % [took, paste.length()]
		ok += 1 if int(judged[1]) == Invite.Read.OK else 0
		if not why.is_empty():
			bad = "case %d: %s -- --replay=\"invite %s\"" % [i, why,
				Marshalls.utf8_to_base64(paste)]
			break
	_says(bad.is_empty(), "invite: %d pastes, %d of them read as an invite and every one"
		% [cases, ok] + " of those whole -- a key id, a secret, an address a call can"
		+ " use, a port, a certificate -- with no script error, and no paste costing the"
		+ " engine's log more than %d lines, each a certificate that does not parse:"
		% Invite.CERTIFICATES_MAX + " %d in all (#106)%s"
		% [engine, "" if bad.is_empty() else " -- NOT: " + bad])


## **One paste, judged**: `[what is wrong, or "", what it read as]`. Wrong is a
## script error, an invite that reads but is not whole, or an engine line past
## what [constant Invite.CERTIFICATES_MAX] allows -- or any engine line but a
## certificate's that does not parse (#106).
func _paste_why(paste: String) -> Array:
	var script_before := _catcher.script_errors
	var engine_before := _catcher.engine_errors
	var messages_before := _catcher.message_errors
	var lines_before := _catcher.lines.size()
	var read := Invite.parse(paste)
	var got := int(read.get("read", -1))
	if _catcher.script_errors > script_before:
		return ["a script error: " + _catcher.last, got]
	if _catcher.message_errors > messages_before:
		return ["%d error lines from one paste, the first: %s" % [
			_catcher.message_errors - messages_before, _catcher.last], got]
	var engine := _catcher.engine_errors - engine_before
	if engine > Invite.CERTIFICATES_MAX:
		return ["%d engine lines from one paste, past %d" % [engine,
			Invite.CERTIFICATES_MAX], got]
	if engine > 0:
		for said: String in _catcher.lines.slice(lines_before):
			if not said.contains("Error parsing X509 certificates"):
				return ["an engine line from a paste that is not a certificate's: " + said, got]
	return [_invite_why(read) if got == Invite.Read.OK else "", got]


static func _invite_why(read: Dictionary) -> String:
	if (read.get("key_id", PackedByteArray()) as PackedByteArray).size() != Wire.KEY_ID_SIZE:
		return "an invite with a key id of the wrong size"
	if (read.get("secret", PackedByteArray()) as PackedByteArray).size() != Invite.SECRET_SIZE:
		return "an invite with a secret of the wrong size"
	if not Invite.address_ok(str(read.get("address", ""))):
		return "an invite to %s, which no call can use" % str(read.get("address", ""))
	var port := int(read.get("port", 0))
	if port < 1 or port > 65535:
		return "an invite to port %d" % port
	if read.get("certificate") == null:
		return "an invite with no certificate"
	return ""


func _mutate_paste(line: String) -> String:
	var roll := _rng.randi_range(0, 9)
	match roll:
		0:
			return line
		1:
			return line.substr(0, _rng.randi_range(0, line.length()))
		2:
			# What a messaging app puts in a line: a break, a space, a zero-width
			# space, a no-break space, a tab, a soft hyphen -- and what Windows'
			# clipboard hands over from a broken one, surrogates on their own
			# (#106), a run of them.
			var at := _rng.randi_range(0, line.length())
			var lone := _lone.substr(_rng.randi_range(0, _lone.length() - 1),
				_rng.randi_range(1, 64))
			return line.substr(0, at) + ["\n", "\r\n", " ", char(0x200B), char(0xA0), "\t",
				char(0xAD), lone][_rng.randi_range(0, 7)] + line.substr(at)
		3:
			var out := line
			for n in _rng.randi_range(1, 6):
				var at := _rng.randi_range(0, out.length() - 1)
				out = out.substr(0, at) + char(_rng.randi_range(32, 126)) + out.substr(at + 1)
			return out
		4:
			return "hi, here: " + line + " -- see you in the pond"
		5:
			return line + line
		6:
			return _mutate_paste_spoiled(line)
		7:
			var payload := PackedByteArray()
			payload.resize(_rng.randi_range(0, 400))
			for i in payload.size():
				payload[i] = _rng.randi_range(0, 255)
			var inner := "%d.%s" % [Invite.VERSION, Marshalls.raw_to_base64(payload)]
			return Invite.PREFIX + inner + "." + Invite._check_of(inner)
		8:
			if _rng.randf() < 0.5:
				return Invite.PREFIX.repeat(_rng.randi_range(1, 400))
			# **Many candidates behind checks that read** (#106): each a
			# payload spoiled somewhere, the whole invite after them or not.
			var many := PackedStringArray()
			for n in _rng.randi_range(2, 60):
				many.append(_mutate_paste_spoiled(line))
			if _rng.randf() < 0.5:
				many.append(line)
			return " ".join(many)
		9:
			if _rng.randf() < 0.3:
				# A whole conversation pasted: the line two hundred times over,
				# some 200 KB, of which the reader looks at the first 64 KB.
				return ("hi -- " + line + "\n").repeat(_rng.randi_range(20, 200))
	var noise := ""
	for i in _rng.randi_range(0, 300):
		noise += char(_rng.randi_range(1, 0x2FF))
	return noise


## **Surrogates on their own**, 32 trails and then 32 leads -- no lead ever
## just before a trail, which would pair them -- as a Windows clipboard hands
## over text that was cut in the middle of a pair. Made by decoding UTF-16,
## which keeps them and says so once for each: those lines are the decoder's,
## before any paste, and [member Catcher.message_errors] counts them apart.
static func _lone_surrogates() -> String:
	var bytes := PackedByteArray()
	for i in 64:
		var k := (i & 31) * 0x1F
		var c := 0xDC00 + k if i < 32 else 0xD800 + k
		bytes.append(c & 0xFF)
		bytes.append(c >> 8)
	return bytes.get_string_from_utf16()


## **Junk behind a check that reads**: [param line]'s payload spoiled at one
## character, the check made over it again, so the parse gets as far as it
## can -- the payload's base64, its sizes or its certificate.
func _mutate_paste_spoiled(line: String) -> String:
	var inner := line.trim_prefix(Invite.PREFIX).get_slice(".", 0) + "." \
		+ line.trim_prefix(Invite.PREFIX).get_slice(".", 1)
	var at := _rng.randi_range(2, inner.length() - 1)
	inner = inner.substr(0, at) + char(_rng.randi_range(48, 122)) + inner.substr(at + 1)
	return Invite.PREFIX + inner + "." + Invite._check_of(inner)


# ---------------------------------------------------------------------------
# address: the LAN door's question, against what each address is.
# ---------------------------------------------------------------------------

func _fuzz_address() -> void:
	_rng.seed = hash(_seed * 4099 + 4)
	var cases := _cases(ADDRESS_CASES)
	var bad := ""
	var own := "192.0.2.10"
	for i in cases:
		var made := _address()
		var written: String = made[0]
		var want: bool = made[1]
		var errors := _catcher.errors()
		var got := Lan.is_local_source(written, own)
		Lan.source_key(written)
		var wider := Lan.wider_key(written)
		if _catcher.errors() > errors:
			bad = "case %d: %s raised an error" % [i, written]
			break
		if got != want or wider != str(made[2]):
			bad = "case %d: %s judged %s in '%s', where it is %s in '%s'" % [i, written,
				"local" if got else "not local", wider, "local" if want else "not local",
				made[2]] + " -- --replay=\"address %s/%s %s\"" % ["local" if want else "remote",
				made[2], written]
			break
	_says(bad.is_empty(), "address: %d addresses -- IPv4 and IPv6, compressed and not," % cases
		+ " with zones, in IPv4 clothes, and spoiled -- each judged local by the LAN door"
		+ " exactly when it is, and put in the /56 it is in, and IPv4 in none (#103)%s"
		% ("" if bad.is_empty() else " -- NOT: " + bad))


## **An address, whether it is local, and the /56 it is in** -- "" for IPv4,
## in any clothes, and for anything spoiled -- made from its numbers and then
## written out, so what it is is known without parsing it back. Own /24:
## 192.0.2.0/24.
func _address() -> Array:
	var roll := _rng.randi_range(0, 9)
	if roll <= 4:
		var o := [_rng.randi_range(0, 255), _rng.randi_range(0, 255), _rng.randi_range(0, 255),
			_rng.randi_range(0, 255)]
		match _rng.randi_range(0, 6):
			0:
				o[0] = 10
			1:
				o[0] = 192
				o[1] = 168
			2:
				o[0] = 172
				o[1] = _rng.randi_range(10, 40)
			3:
				o[0] = 100
				o[1] = _rng.randi_range(50, 140)
			4:
				o[0] = 192
				o[1] = 0
				o[2] = _rng.randi_range(1, 3)
		var local := _v4_local(o)
		var text := "%d.%d.%d.%d" % o
		if roll == 4:
			# In IPv6 clothes, as a dual-stack socket reports it.
			return ["::ffff:" + text, local, ""]
		return [text, local, ""]
	if roll <= 7:
		var g: Array = []
		for i in 8:
			g.append(_rng.randi_range(0, 0xFFFF))
		match _rng.randi_range(0, 4):
			0:
				g[0] = 0xFD00 | _rng.randi_range(0, 0xFF)
			1:
				g[0] = 0xFE80 | _rng.randi_range(0, 0x3F)
			2:
				g = [0, 0, 0, 0, 0, 0, 0, 1]
			3:
				g[0] = 0x2001
				g[1] = 0x0DB8
		var local := g == [0, 0, 0, 0, 0, 0, 0, 1] or (int(g[0]) & 0xFE00) == 0xFC00 \
			or (int(g[0]) & 0xFFC0) == 0xFE80
		return [_v6_text(g), local, "%x:%x:%x:%x::/56" % [g[0], g[1], g[2], int(g[3]) & 0xFF00]]
	# Spoiled: never local, however close it looks.
	var spoiled := ["192.168.1", "192.168.1.1.1", "256.1.1.1", "10.0.0.-1", "", "::1::",
		"fe80::1::2", "fd00::g", "localhost", "192.168.1.1.", "1e2.0.0.1", "10.0.0.1/8",
		"0x0a.0.0.1", ":::", "fd00:::1", "1:2:3:4:5:6:7:8:9"]
	return [spoiled[_rng.randi_range(0, spoiled.size() - 1)], false, ""]


static func _v4_local(o: Array) -> bool:
	var a := int(o[0])
	var b := int(o[1])
	if a == 127 or a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) \
			or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254):
		return true
	return a == 192 and b == 0 and int(o[2]) == 2


## Eight groups written as people and sockets write them: compressed or not,
## upper or lower case, with a zone now and then.
func _v6_text(g: Array) -> String:
	var parts: PackedStringArray = []
	for each: int in g:
		parts.append(("%x" if _rng.randf() < 0.7 else "%X") % each)
	var text := ":".join(parts)
	if _rng.randf() < 0.6:
		# The longest run of zero groups, if two or more long, as "::".
		var best_at := -1
		var best_len := 0
		var i := 0
		while i < 8:
			if int(g[i]) == 0:
				var j := i
				while j < 8 and int(g[j]) == 0:
					j += 1
				if j - i > best_len and j - i >= 2:
					best_at = i
					best_len = j - i
				i = j
			else:
				i += 1
		if best_at >= 0:
			var head := ":".join(parts.slice(0, best_at))
			var tail := ":".join(parts.slice(best_at + best_len))
			text = head + "::" + tail
	if _rng.randf() < 0.15:
		text += "%" + ["eth0", "wlan0", "3"][_rng.randi_range(0, 2)]
	return text


# ---------------------------------------------------------------------------
# referee: every judgement, in any order, with any value the wire lets through.
# ---------------------------------------------------------------------------

func _fuzz_referee() -> void:
	var runs := _cases(REFEREE_RUNS)
	var bad := ""
	var judged := 0
	for run in runs:
		var plan := _referee_plan(_seed, run)
		var result := _referee_run(plan, [])
		judged += int(result[1])
		if not str(result[0]).is_empty():
			var keep := _shrink_referee(plan)
			bad = "run %d: %s -- --replay=\"referee %s\"" % [run, str(result[0]),
				_referee_code(plan, keep)]
			break
	_says(bad.is_empty(), "referee: %d judgements over %d runs, in any order and with"
		% [judged, runs] + " anything the wire lets through, from nothing to float's edge"
		+ " -- every answer finite, the body placed inside its caps, and no error%s"
		% ("" if bad.is_empty() else " -- NOT: " + bad))


## **One run's judgements, drawn from its own seed** so any of them can be
## replayed alone: `[seconds since the last, what, values...]`.
##
## **What the host decides is the host's**: where a body arrives, and at the
## size its ENTER was allowed, a wound, a stall. **What the guest says is
## anything its reader lets through** -- any finite place, any size above zero
## -- except where the wire itself bounds it: a heading is a bearing byte, and a
## state frame's motion is inside [constant Wire.MOTION_MAX] and
## [constant Wire.TURNING_MAX].
func _referee_plan(seed: int, run: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("referee %d %d" % [seed, run])
	var plan: Array = []
	for step in REFEREE_STEPS:
		var dt := _f32([0.0, 0.016, 0.05, 0.5, 3.0, 12.0][rng.randi_range(0, 5)])
		var what := rng.randi_range(0, 10)
		var at := Vector2(_wild(rng, 5000.0), _wild(rng, 5000.0))
		match what:
			0:
				var heading := _f32(rng.randf_range(-PI, PI))
				var motion := Vector2.from_angle(rng.randf_range(-PI, PI)) \
					* rng.randf_range(0.0, Wire.MOTION_MAX)
				plan.append([dt, "claim", at, heading, _wild_size(rng), motion,
					_f32(rng.randf_range(-Wire.TURNING_MAX, Wire.TURNING_MAX)),
					rng.randf() < 0.2])
			1:
				plan.append([dt, "enter", _wild_size(rng)])
			2:
				plan.append([dt, "arrive", Vector2(rng.randf_range(-4000.0, 4000.0),
					rng.randf_range(-4000.0, 4000.0)), _f32(rng.randf_range(CellBody.BASE_RADIUS,
						CellBody.DIVIDE_RADIUS))])
			3:
				var tiers := _tiers_from(rng)
				plan.append([dt, "person", rng.randf() < 0.5, tiers, tiers.keys()])
			4:
				plan.append([dt, "sister", at, _wild_size(rng)])
			5:
				plan.append([dt, "shout", at, _wild(rng, 60.0), _wild(rng, 2000.0),
					rng.randf() < 0.7])
			6:
				plan.append([dt, "said died", rng.randi_range(0, 255), rng.randi_range(0, 255)])
			7:
				plan.append([dt, "killed"])
			8:
				plan.append([dt, "left", _f32(rng.randf()), _f32(rng.randf_range(0.0, 42.0))])
			9:
				plan.append([dt, "stalled", _f32(rng.randf_range(0.0, 20.0))])
			10:
				# **The host's drop** (ocean.md §10.5): a rim, somewhere, of any
				# size a host could have -- or none.
				plan.append([dt, "rim", Vector2(_wild(rng, 2000.0), _wild(rng, 2000.0)),
					_f32([0.0, 6000.0, 50.0, rng.randf_range(0.0, 9000.0)][rng.randi_range(0, 3)])])
	return plan


## **Steps written out so a `--replay=` reads them back exactly**: `what:dt:
## values`, a step each, `|` between. Every float in a plan is a float32 --
## which is what the wire carries -- and `var_to_str` writes one so that, read
## and made a float32 again, it is the same number (measured on 4.7 over 40,000
## of them).
static func _referee_code(plan: Array, only: Array) -> String:
	var parts: PackedStringArray = []
	for i in plan.size():
		if not only.is_empty() and not only.has(i):
			continue
		var step: Array = plan[i]
		var out: PackedStringArray = [str(step[1]).replace(" ", "_"), var_to_str(step[0])]
		for value: Variant in step.slice(2):
			if value is Vector2:
				out.append(var_to_str((value as Vector2).x))
				out.append(var_to_str((value as Vector2).y))
			elif value is bool:
				out.append("1" if value else "0")
			elif value is Dictionary:
				var pairs: PackedStringArray = []
				for gene: Variant in value:
					pairs.append("%s=%d" % [gene, int(value[gene])])
				out.append(",".join(pairs))
			elif value is int:
				out.append(str(value))
			elif value is float:
				out.append(var_to_str(value))
		parts.append(":".join(out))
	return "|".join(parts)


static func _referee_read(code: String) -> Array:
	var plan: Array = []
	for part: String in code.split("|", false):
		var f := part.split(":")
		var what := f[0].replace("_", " ")
		var dt := _f32(float(f[1]))
		match what:
			"claim":
				plan.append([dt, what, Vector2(float(f[2]), float(f[3])), _f32(float(f[4])),
					_f32(float(f[5])), Vector2(float(f[6]), float(f[7])), _f32(float(f[8])),
					f[9] == "1"])
			"enter":
				plan.append([dt, what, _f32(float(f[2]))])
			"arrive", "sister", "rim":
				plan.append([dt, what, Vector2(float(f[2]), float(f[3])), _f32(float(f[4]))])
			"person":
				var tiers := {}
				for pair: String in f[3].split(",", false):
					tiers[StringName(pair.get_slice("=", 0))] = int(pair.get_slice("=", 1))
				plan.append([dt, what, f[2] == "1", tiers, tiers.keys()])
			"shout":
				plan.append([dt, what, Vector2(float(f[2]), float(f[3])), _f32(float(f[4])),
					_f32(float(f[5])), f[6] == "1"])
			"said died":
				plan.append([dt, what, int(f[2]), int(f[3])])
			"killed":
				plan.append([dt, what])
			"left":
				plan.append([dt, what, _f32(float(f[2])), _f32(float(f[3]))])
			"stalled":
				plan.append([dt, what, _f32(float(f[2]))])
	return plan


## [param x] as the float32 a frame would carry.
static func _f32(x: float) -> float:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, x)
	return bytes.decode_float(0)


## **A run of [param plan]**, or of only its steps at [param only]:
## `[what went wrong or "", judgements]`. A body is here from an arrival to
## its death or its leaving, as `pond.gd` keeps one: a state frame is judged
## only then, and an arrival over a body here has it leave first, as
## `_host_enter` does.
func _referee_run(plan: Array, only: Array) -> Array:
	var ref := Referee.new(0.0)
	var now := 0.0
	var here := false
	var judged := 0
	for i in plan.size():
		if not only.is_empty() and not only.has(i):
			continue
		var step: Array = plan[i]
		now += float(step[0])
		var errors := _catcher.errors()
		var why := ""
		match str(step[1]):
			"claim":
				if not here:
					continue
				var claimed: Array = ref.claim(now, step[2], float(step[3]), float(step[4]),
					step[5], float(step[6]), bool(step[7]))
				why = _finite_why(claimed)
				if not why.is_empty():
					why = "a state frame placed the body at " + why
				elif float(claimed[2]) < CellBody.BASE_RADIUS - 0.001 \
						or float(claimed[2]) > CellBody.DIVIDE_RADIUS + 0.06:
					why = "a state frame made the body r%.3f" % float(claimed[2])
				elif (claimed[3] as Vector2).length() > Referee.SPEED_MAX + 0.01 \
						or absf(float(claimed[4])) > Referee.TURNING_MAX + 0.001:
					why = "a state frame let it move at %s turning %s" % [str(claimed[3]),
						str(claimed[4])]
			"enter":
				ref.judge_enter(now, float(step[2]), here)
			"arrive":
				if here:
					ref.left(now, 0.0, 0.0)
				var granted := ref.arrive(now, step[2], float(step[3]))
				here = true
				why = _finite_why(granted)
				if not why.is_empty():
					why = "an arrival granted " + why
			"person":
				ref.judge_person(now, bool(step[2]), step[3], step[4], here)
			"sister":
				var placed := ref.judge_sister(now, step[2], float(step[3]), here)
				why = _finite_why(placed)
				if not why.is_empty():
					why = "a sister placed at " + why
				elif not placed.is_empty() and absf(float(placed[1])
						- Referee.DAUGHTER_RADIUS) > Referee.RADIUS_SLACK + 0.001:
					why = "a sister made r%.3f" % float(placed[1])
			"shout":
				ref.judge_shout(now, step[2], float(step[3]), float(step[4]),
					here and bool(step[5]))
			"said died":
				if not ref.judge_died(now, int(step[2]), int(step[3]), here).is_empty():
					here = false
			"killed":
				if here:
					ref.died(now)
					here = false
			"left":
				if here:
					ref.left(now, float(step[2]), float(step[3]))
					here = false
			"stalled":
				ref.stalled(float(step[2]))
			"rim":
				ref.set_rim(step[2], float(step[3]))
		ref.take_fouls()
		judged += 1
		if why.is_empty() and _catcher.errors() > errors:
			why = "an error: " + _catcher.last
		if not why.is_empty():
			return ["step %d (%s): %s" % [i, str(step[1]), why], judged]
	return ["", judged]


## The fewest of [param plan]'s steps that still fail, each taken out in turn.
func _shrink_referee(plan: Array) -> Array:
	var keep: Array = range(plan.size())
	var i := keep.size() - 1
	while i >= 0:
		var without := keep.duplicate()
		without.remove_at(i)
		if not without.is_empty() and not str(_referee_run(plan, without)[0]).is_empty():
			keep = without
		i -= 1
	return keep


## A finite value a frame could carry: mostly in range, sometimes huge.
static func _wild(rng: RandomNumberGenerator, scale: float) -> float:
	match rng.randi_range(0, 7):
		0:
			return 0.0
		1:
			return _f32([3.0e38, -3.0e38, 3.4028e38, 1.0e20, -1.0e20, 1.0e-30][
				rng.randi_range(0, 5)])
		2, 3:
			return _f32(-scale * rng.randf())
	return _f32(scale * rng.randf())


## A size a reader lets through: finite and above zero.
static func _wild_size(rng: RandomNumberGenerator) -> float:
	match rng.randi_range(0, 5):
		0:
			return _f32([1.0e-30, 3.0e38, 1.0e20, 0.001][rng.randi_range(0, 3)])
		1:
			return _f32(rng.randf_range(0.001, 500.0))
	return _f32(rng.randf_range(CellBody.BASE_RADIUS - 1.0, CellBody.DIVIDE_RADIUS + 1.0))


# ---------------------------------------------------------------------------
# The corpus, and replaying one case.
# ---------------------------------------------------------------------------

## Every saved case: `<section> <payload>`, one a line, `#` to the end of a
## line a note.
func _corpus() -> PackedStringArray:
	var out: PackedStringArray = []
	var text := FileAccess.get_file_as_string(CORPUS)
	for raw_line: String in text.split("\n"):
		var line := raw_line.get_slice("#", 0).strip_edges()
		if not line.is_empty():
			out.append(line)
	return out


## One case, as a failure printed it or the corpus keeps it: true when it
## holds. [param say] prints what the door counted, for a case replayed by
## hand.
func _replay(entry: String, say: bool) -> bool:
	var section := entry.get_slice(" ", 0)
	var payload := entry.substr(section.length()).strip_edges()
	match section:
		"wire":
			# `<g|h> [takes|refuses] <frame in hex>`: an event can say what it
			# must read as, since protocol 6's SISTER -- a judge of its own, as an
			# invite's is, so a saved refusal fails the day the reader takes it.
			var parts := payload.split(" ", false)
			if parts.size() < 2 or parts.size() > 3:
				return false
			var from_host := parts[0] == "h"
			var frame := parts[parts.size() - 1].hex_decode()
			if _fails_wire(frame, from_host):
				return false
			if parts.size() == 2:
				return true
			if parts[1] != "takes" and parts[1] != "refuses":
				return false
			return _taken(frame, from_host) == (parts[1] == "takes")
		"door":
			var result: Array = await _door_run(_door_read(payload))
			if not str(result[0]).is_empty():
				print("[net-fuzz] %s" % str(result[0]))
			if say and _host != null and not _host.gate_counts.is_empty():
				var said: PackedStringArray = []
				for key: String in _host.gate_counts:
					if float(_host.gate_counts[key]) != 0.0:
						said.append("%s %s" % [key, str(_host.gate_counts[key])])
				print("[net-fuzz] NOTE the door counted: %s" % ", ".join(said))
			return str(result[0]).is_empty()
		"invite":
			# `[ok|none|damaged|newer] <paste in base64>`: what it must read as,
			# when said -- a judge of its own, which the fuzzer's does not
			# have: an invite that reads is only held to be whole by the very
			# `address_ok` it is read with.
			var want := -1
			var paste := payload
			if payload.contains(" "):
				want = ["ok", "none", "damaged", "newer"].find(payload.get_slice(" ", 0))
				paste = payload.get_slice(" ", 1)
				if want < 0:
					return false
			var judged := _paste_why(Marshalls.base64_to_utf8(paste))
			return str(judged[0]).is_empty() and (want < 0 or int(judged[1]) == want)
		"address":
			# `local <address>` or `remote <address>`: what it is, then as
			# written -- `local/<its /56>`, or `remote/` for none, to ask the
			# /56 too.
			var kind := payload.get_slice(" ", 0)
			var want := kind.get_slice("/", 0) == "local"
			var written := payload.substr(payload.find(" ") + 1)
			var before := _catcher.errors()
			var got := Lan.is_local_source(written, "192.0.2.10")
			Lan.source_key(written)
			var wider := Lan.wider_key(written)
			return _catcher.errors() == before and got == want \
				and (not kind.contains("/") or wider == kind.substr(kind.find("/") + 1))
		"guest":
			var result: Array = await _guest_run(payload.get_slice(" ", 0) == "invite",
				_guest_read(payload.get_slice(" ", 1)))
			if not str(result[0]).is_empty():
				print("[net-fuzz] %s" % str(result[0]))
			return str(result[0]).is_empty()
		"referee":
			var result := _referee_run(_referee_read(payload), [])
			if not str(result[0]).is_empty():
				print("[net-fuzz] %s" % str(result[0]))
			return str(result[0]).is_empty()
	print("[net-fuzz] a case this fuzzer does not know: %s" % entry)
	return false
