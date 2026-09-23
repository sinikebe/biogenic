extends RefCounted
## **One water on the wire**: what each run tells the other about the shared
## pond, and what it does with what it hears. shared-pond.md §1-§2, Phase 2.
##
## One of these belongs to every run that began inside a session, host or
## guest, and to nothing else: a run with no session never builds one, which is
## the whole of what single player pays for this file. The run calls
## [method step] once a frame, before any of its own early returns, so intake
## goes on while its cell is dead, dividing or held.
##
## **The host's water is the water** (§1.1). On the host this file carries the
## guest's newest state frame into the person in slot 68, sends the water as a
## POND snapshot with every state frame the host sends -- twenty a second, and
## at once on a jump -- sends each body's genome once per body version, and
## forwards every contact the field resolves on the guest as CONTACT. On the
## guest it applies the newest snapshot to the mirror, drains the genomes and
## the contacts into it, and speaks for the guest's own cell: ENTER, PERSON,
## SISTER and DIED.
##
## **Nothing here decides what anything looks like or says.** Every moment the
## run has to act on -- an arrival, a death, a friend leaving -- leaves as a
## signal, and the run owns the beat, the fades and the lines
## (shared-pond-ux.md). The field owns every rule. This is the seam between
## them and the socket, and it carries places and names, never a bearing and
## never a gene index (§0.2, §2).
##
## RefCounted and preloaded, no node and no class_name, like every other file in
## game/net/ -- see the note at the top of signal_bus.gd.

const Wire := preload("res://game/net/wire.gd")
const NetSession := preload("res://game/net/net_session.gd")
const FoodField := preload("res://game/normal/food.gd")
const CellBody := preload("res://game/normal/cell.gd")
## For [constant VisionLayer.PEER_FRESH] only: the silence after which a friend
## counts as quiet is the view's number, and the field is told it here.
const VisionLayer := preload("res://game/vision/vision.gd")

## **How far from the friend an arrival lands, along the world horizontal:
## 480**, where the spec started at the division's own SISTER_DISTANCE, 560 --
## near enough to be met, far enough not to be a fight, and inside every tier's
## ping range either way. shared-pond-ux.md §9.3 decided it, as it was written
## to: rendered at 1280x720, where the frame is 640 units either side of the
## camera, a friend landing at 560 sat 45-52 px from the frame's edge, under
## the membrane's outer band, and the camera's lead -- up to 72 units, away from
## them -- puts the body on the edge. At 480 it lands 160 px in, and 88 at the
## full lead. Written out rather than read, because normal_mode.gd preloads
## this file.
const ARRIVAL := 480.0
## An arrival is clear of every body by both radii and this much more.
const ARRIVAL_CLEAR := 20.0
## Past the two sides of the horizontal, the circle is searched in these steps.
const ARRIVAL_STEP_DEG := 30.0

## Guest: the host put this cell at [param at], facing [param heading].
signal arrived(at: Vector2, heading: float)
## Host: a guest's cell has just been put in this water.
signal friend_entered
## Either seat: the other player's cell died. [param cause] and [param by] are
## food.gd's Cause and By; [param at] is where their body was;
## [param eaten_by_me] is this cell's own mouth having done it.
signal friend_died(cause: int, by: int, at: Vector2, eaten_by_me: bool)
## Host: the guest is gone from this water -- the link, or they left the pond.
signal friend_left
## Host: the guest's declined daughter was left in slot [param slot].
signal sister_placed(slot: int)
## Either seat: the other player has a new body -- back from the black, or born.
signal friend_renewed

var hosting := false

var _net: Node = null
var _food: FoodField = null
var _cell: CellBody = null
## The genome node, untyped for the reason cell.gd's is: genome.gd preloads
## cell.gd, and this file preloads both.
var _genome: Node = null

# --- Host ---------------------------------------------------------------------
## Body version last sent as GENOME, by slot: `serial * 1000 + meals`, the
## mirror's own book key.
var _sent := {}
## When the next snapshot is due if no state frame goes first, and how many
## state frames had gone when the last one went.
var _pond_due := 0.0
var _states_seen := -1
var _flush_queued := false
## The guest's track entry last carried into the person, by identity.
var _basis: Array = []
## True from ENTER until the guest's state frames say it is swimming here: the
## person waits at the arrival, out of the water, and nothing is sent to a
## mirror that is not there yet.
var _awaiting := false
var _awaiting_since := 0.0
## The KILLED the field just said, waiting for the person_died that follows it
## in the same call with the cause.
var _killed_at := Vector2.ZERO
var _killed_pending := false
## **For tools**: where the last arrival was measured from and where it landed,
## the largest snapshot sent and how many went.
var arrival_from := Vector2.ZERO
var arrival_at := Vector2.ZERO
var pond_bytes_max := 0
var ponds_sent := 0
var genomes_sent := 0
## Where the other player's body last was, and whether there has been one.
var _friend_at := Vector2.ZERO
var _friend_known := false

# --- Guest --------------------------------------------------------------------
## The newest snapshot applied, by its sequence.
var _applied := -1
## ENTER sent and ARRIVE not yet heard.
var entering := false
var _enter_since := 0.0
## **In the pond**: this mirror has been put in the host's water at least once
## and has not been taken over since. It is the guest's `POND` bit, dead or
## alive, so a death reads to the host as a death and not as a leave. The run
## sets it, the moment its cell is placed where ARRIVE said.
var in_pond := false
## The host's last PERSON, kept for a mirror that begins after it arrived.
var _host_worn: Array = []

# --- Both ---------------------------------------------------------------------
## The worn signature last told to the other player.
var _worn := ""


func _init(net: Node, food: FoodField, cell: CellBody, genome: Node) -> void:
	_net = net
	_food = food
	_cell = cell
	_genome = genome
	hosting = bool(net.hosting)
	if hosting:
		_food.person_touched.connect(_on_person_touched)
		_food.person_died.connect(_on_person_died)


## **Once a frame, before the run's early returns.** Everything this file hears
## is taken in here, whatever the run's own cell is doing.
func step() -> void:
	if _net == null or not is_instance_valid(_net):
		return
	if hosting:
		_step_host()
	else:
		_step_guest()


## True while the link is up.
func together() -> bool:
	return _net != null and is_instance_valid(_net) \
		and int(_net.link) == NetSession.Link.TOGETHER


## Seconds since anything arrived from the other player, or -1.
func quiet_for() -> float:
	if _net == null or not is_instance_valid(_net):
		return -1.0
	return float(_net.quiet_for())


# ---------------------------------------------------------------------------
# The host.
# ---------------------------------------------------------------------------

func _step_host() -> void:
	if not together():
		if _food.person() != null:
			_drop_person()
		_awaiting = false
		return
	for frame: PackedByteArray in _net.drain_pond_events():
		_host_hears(frame)
	_carry_guest()
	var pb: Object = _person_body()
	if _food.person() != null and pb != null:
		_friend_at = pb.pos
		_friend_known = true
		_watch_worn()
	if _food.person() != null and not _flush_queued:
		# **At the end of this frame**, after the field has stepped: the
		# snapshot is then the water as this frame leaves it, and the guest's
		# mirror, which carries it on by one frame of its own, stands where the
		# water really is. Built at the start of the frame instead, it was a
		# frame old before it left.
		_flush_queued = true
		_flush.call_deferred()


func _host_hears(frame: PackedByteArray) -> void:
	match Wire.event_type(frame):
		Wire.EVENT_PERSON:
			var said := Wire.take_person(frame)
			if said.is_empty():
				return
			_food.set_person_genome(said[1], said[2])
			if bool(said[0]):
				_food.renew_person()
				friend_renewed.emit()
		Wire.EVENT_ENTER:
			var said := Wire.take_enter(frame)
			if not said.is_empty():
				_host_enter(float(said[0]))
		Wire.EVENT_SISTER:
			var said := Wire.take_sister(frame)
			if said.is_empty():
				return
			var slot := _food.place_sister(said[0], float(said[1]), float(said[2]),
				said[3])
			if slot >= 0:
				sister_placed.emit(slot)
		Wire.EVENT_DIED:
			# The guest's own death, and only the one the guest decides:
			# starving. A death this field made has already taken the person
			# out, and its DIED is the same death said twice.
			var said := Wire.take_died(frame)
			if said.is_empty() or _food.person() == null:
				return
			var at: Vector2 = _person_body().pos
			_food.remove_person()
			_awaiting = false
			friend_died.emit(int(said[0]), int(said[1]), at, false)
		_:
			pass


## **A guest's cell asks to come into this water** (§1.6): put it
## [constant ARRIVAL] along the world horizontal from this cell -- alive, or
## where it last was -- and say where. A guest already in here is taken out
## first: an ENTER is always a new arrival.
##
## It waits out of the water until the guest's state frames say it is swimming
## here, which is the length of the guest's own beat: nothing can bite a body
## the other screen has not put in the water yet.
func _host_enter(radius: float) -> void:
	if _food.person() != null:
		_food.remove_person()
	var from := _cell.position
	var at := arrival_point(from, radius)
	arrival_from = from
	arrival_at = at
	_food.place_person(at, 0.0, radius)
	_food.set_person_in_water(false)
	var track: Array = _net.peer_track()
	_basis = track[track.size() - 1] if not track.is_empty() else []
	_awaiting = true
	_awaiting_since = _now()
	# A new mirror knows none of this water yet: every genome goes again.
	_sent.clear()
	_friend_at = at
	_friend_known = true
	_net.send_event(Wire.EVENT_ARRIVE, Wire.arrive_payload(at, 0.0))
	_send_person(false)
	friend_entered.emit()


## **Where a cell arriving near [param near] goes** (§1.6): [constant ARRIVAL]
## along the world horizontal -- east, then west -- and then round the circle
## in [constant ARRIVAL_STEP_DEG] steps, the first spot clear of every body in
## the water by both radii and [constant ARRIVAL_CLEAR]. Nothing clear, the
## first side anyway: a crowded arrival is still an arrival.
func arrival_point(near: Vector2, radius: float) -> Vector2:
	var angles: Array[float] = [0.0, PI]
	var step := deg_to_rad(ARRIVAL_STEP_DEG)
	var steps := int(roundf(TAU / step))
	for k in range(1, steps):
		if 2 * k == steps:
			continue
		angles.append(step * float(k))
	for angle: float in angles:
		var at := near + Vector2(cos(angle), sin(angle)) * ARRIVAL
		if _clear(at, radius):
			return at
	return near + Vector2(ARRIVAL, 0.0)


func _clear(at: Vector2, radius: float) -> bool:
	for b: Object in _food.bodies():
		if not b.seeded:
			continue
		if at.distance_to(b.pos) < radius + float(b.radius) + ARRIVAL_CLEAR:
			return false
	if _food.anchored and at.distance_to(_cell.position) \
			< radius + _cell.radius + ARRIVAL_CLEAR:
		return false
	return true


## Where the other player is, or last was: `[place, known]`. For the host's own
## return from the black, which lands near them (§1.6, owner's row A).
func friend_place() -> Array:
	var pb: Object = _person_body()
	if _food.person() != null and pb != null:
		return [pb.pos, true]
	return [_friend_at, _friend_known]


## **The guest's newest state frame, carried into the person** -- once they
## are swimming here. Before their `POND` bit is set the person waits where it
## was put; after it clears the guest has left this water without leaving the
## wire, and goes.
func _carry_guest() -> void:
	if _food.person() == null:
		return
	var flags: int = _net.peer_flags()
	if (flags & Wire.STATE_POND) == 0:
		if _awaiting and _now() - _awaiting_since < NetSession.REACH_TIMEOUT:
			return
		_drop_person()
		return
	_awaiting = false
	var track: Array = _net.peer_track()
	if not track.is_empty():
		var newest: Array = track[track.size() - 1]
		if not is_same(newest, _basis):
			_basis = newest
			_food.set_person_in_water((flags & Wire.STATE_OUT) == 0)
			_food.place_person(newest[1], float(newest[2]), float(newest[3]),
				newest[4], float(newest[5]))
	_food.set_person_quiet(quiet_for() >= VisionLayer.PEER_FRESH)


func _drop_person() -> void:
	_food.remove_person()
	_awaiting = false
	friend_left.emit()


## **The snapshot, at the end of the frame.** With every state frame this end
## has sent since the last one -- so a jump the state frame carries at once is
## in the guest's water at once too -- and otherwise every STATE_PERIOD, which
## keeps the water moving on the guest's screen while this cell is dead and its
## own state frames beat at two a second.
func _flush() -> void:
	_flush_queued = false
	if not together() or _food.person() == null or _awaiting:
		return
	var now := _now()
	var states: int = _net.states_sent()
	if states == _states_seen and now < _pond_due:
		return
	_states_seen = states
	_pond_due = now + NetSession.STATE_PERIOD
	var bodies := _food.pond_entries(true)
	_send_genomes(bodies)
	var pb: Object = _person_body()
	var size: int = _net.send_pond(float(pb.wound) if pb != null else 0.0, bodies)
	pond_bytes_max = maxi(pond_bytes_max, size)
	ponds_sent += 1


## Every body in the send set whose version the guest has not been sent.
func _send_genomes(bodies: Array) -> void:
	var cells := _food.bodies()
	for entry: Array in bodies:
		var slot := int(entry[FoodField.Entry.SLOT])
		if slot >= FoodField.PERSON_SLOT or slot >= cells.size():
			continue
		var serial := int(entry[FoodField.Entry.SERIAL])
		var meals := int(entry[FoodField.Entry.MEALS])
		var version := (serial & 0xFFFF) * 1000 + meals
		if int(_sent.get(slot, -1)) == version:
			continue
		_sent[slot] = version
		genomes_sent += 1
		_net.send_event(Wire.EVENT_GENOME, Wire.genome_payload(slot, serial, meals,
			cells[slot].genome))


## **What the field did to the guest, told to the guest.** Every contact but a
## death goes as it is said; a death waits the moment it takes the field to say
## why, which is the next signal in the same call.
func _on_person_touched(what: int, at: Vector2, level: float, by: int,
		gene: StringName) -> void:
	if what == FoodField.Contact.KILLED:
		_killed_at = at
		_killed_pending = true
		return
	_net.send_event(Wire.EVENT_CONTACT,
		Wire.contact_payload(what, at, level, by, gene))


func _on_person_died(cause: int, by: int, at: Vector2) -> void:
	var hit := _killed_at if _killed_pending else at
	_killed_pending = false
	_awaiting = false
	_net.send_event(Wire.EVENT_CONTACT,
		Wire.contact_payload(FoodField.Contact.KILLED, hit, 0.0, by, &"", cause))
	friend_died.emit(cause, by, at, _eaten_by_friend(cause, by))


# ---------------------------------------------------------------------------
# The guest.
# ---------------------------------------------------------------------------

func _step_guest() -> void:
	if not together():
		return
	for frame: PackedByteArray in _net.drain_pond_events():
		_guest_hears(frame)
	if _food.mirroring() and _food.anchored and in_pond:
		apply_newest()
	if _food.mirroring() and in_pond:
		_watch_worn()


## **The newest snapshot, into the mirror** -- if it is newer than the last one
## applied. Returns true when one went in. A refused frame is not retried.
func apply_newest() -> bool:
	var frame: PackedByteArray = _net.peer_pond()
	var seq := Wire.seq_of(frame)
	if seq <= _applied:
		return false
	_applied = seq
	var said := Wire.take_pond(frame)
	if said.is_empty():
		return false
	_food.apply_pond(float(said[1]), said[2])
	return true


func _guest_hears(frame: PackedByteArray) -> void:
	match Wire.event_type(frame):
		Wire.EVENT_ARRIVE:
			var said := Wire.take_arrive(frame)
			if said.is_empty() or not entering:
				return
			entering = false
			arrived.emit(said[0], float(said[1]))
		Wire.EVENT_GENOME:
			var said := Wire.take_genome(frame)
			if not said.is_empty():
				_food.apply_genome(int(said[0]), int(said[1]), int(said[2]), said[3])
		Wire.EVENT_CONTACT:
			# **The host is the authority on every contact** (§0.1), so a
			# contact that reaches a living cell is obeyed -- a KILLED during
			# this cell's own quickening or pinch included: the host decided it
			# before it knew, and the host's water no longer has this cell in
			# it. Only a cell that has not arrived, or is already dead, has
			# nothing to be told.
			var said := Wire.take_contact(frame)
			if said.is_empty() or not _food.mirroring() or not _food.anchored \
					or not in_pond:
				return
			_food.hear_contact(int(said[0]), said[1], float(said[2]), int(said[3]),
				said[4], int(said[5]))
		Wire.EVENT_DIED:
			var said := Wire.take_died(frame)
			if said.is_empty() or not _food.mirroring():
				return
			friend_died.emit(int(said[0]), int(said[1]), said[2],
				_eaten_by_friend(int(said[0]), int(said[1])))
		Wire.EVENT_PERSON:
			var said := Wire.take_person(frame)
			if said.is_empty():
				return
			_host_worn = [said[1], said[2]]
			if _food.mirroring():
				_food.set_person_genome(said[1], said[2])
			if bool(said[0]):
				friend_renewed.emit()
		_:
			pass


## **Ask to come into the host's water** (§1.6): who is arriving, then how big
## it is. [param tiers] and [param order] are the body about to arrive, which on
## a return from the black is not yet the body this run wears.
func enter(radius: float, tiers: Dictionary, order: Array) -> void:
	_send_person_as(true, tiers, order)
	_net.send_event(Wire.EVENT_ENTER, Wire.enter_payload(radius))
	entering = true
	_enter_since = _now()


## Seconds since ENTER went, while it waits.
func entering_for() -> float:
	return _now() - _enter_since if entering else 0.0


## **The mirror just began** (a swap, or a run that opened inside the pond):
## whatever the host already said about itself goes into it now.
func mirror_began() -> void:
	if not _host_worn.is_empty():
		_food.set_person_genome(_host_worn[0], _host_worn[1])


## **The pond is over for this cell** -- taken over, or never arrived.
func mirror_ended() -> void:
	in_pond = false
	entering = false


## The guest's declined daughter, for the host to leave in the water.
func sister(at: Vector2, heading: float, radius: float, tiers: Dictionary) -> void:
	_net.send_event(Wire.EVENT_SISTER, Wire.sister_payload(at, heading, radius, tiers))


# ---------------------------------------------------------------------------
# Both.
# ---------------------------------------------------------------------------

## **This cell died** (§2's DIED): how, by whose mouth, and where, for the other
## player's lines and drawing.
func died(cause: int, by: int, at: Vector2) -> void:
	if not together():
		return
	_net.send_event(Wire.EVENT_DIED, Wire.died_payload(cause, by, at))


## **This cell wears something new** -- a birth, a return, or the worn tiers or
## their order changing -- and the other player is in the pond to be told.
func person_changed(new_body: bool) -> void:
	if not together():
		return
	if hosting and _food.person() == null:
		return
	if not hosting and not in_pond:
		return
	_send_person(new_body)


func _send_person(new_body: bool) -> void:
	_send_person_as(new_body, _genome.tiers(), _genome.body_layout())


func _send_person_as(new_body: bool, tiers: Dictionary, order: Array) -> void:
	_worn = _signature(tiers, order)
	_net.send_event(Wire.EVENT_PERSON, Wire.person_payload(new_body, tiers, order))


## A PERSON whenever what this cell wears stops being what it last said.
func _watch_worn() -> void:
	var now := _signature(_genome.tiers(), _genome.body_layout())
	if now != _worn:
		_send_person_as(false, _genome.tiers(), _genome.body_layout())


static func _signature(tiers: Dictionary, order: Array) -> String:
	return "%s|%s" % [str(tiers), str(order)]


## The death was the other player's mouth on them, swallowed or chewed apart --
## "you ate them" -- rather than their own mouth on a venomous one.
static func _eaten_by_friend(cause: int, by: int) -> bool:
	return by == FoodField.By.FRIEND and (cause == FoodField.Cause.SWALLOWED
		or cause == FoodField.Cause.CHEWED)


func _person_body() -> Object:
	var bodies := _food.bodies()
	return bodies[FoodField.PERSON_SLOT] if bodies.size() > FoodField.PERSON_SLOT \
		else null


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
