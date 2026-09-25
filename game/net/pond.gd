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
## **A dedicated host is the same host with two guests and no cell**
## (`game/server/`). Each guest gets the host side above to itself -- its own
## person slot, its own snapshots and genomes, its own contacts -- and where a
## phone host would speak for its own cell, it speaks for the *other guest*: a
## guest's snapshot carries the other one as the person in slot 68, and its
## PERSON, its DIED and its shouts are passed on as the host's own would be.
## So a PROTOCOL 4 guest joins either kind of host with the same code, and
## meets its friend in the place it always has.
##
## **Nothing here decides what anything looks like or says.** Every moment the
## run has to act on -- an arrival, a death, a friend leaving -- leaves as a
## signal, and the run owns the beat, the fades and the lines
## (shared-pond-ux.md). The field owns every rule. This is the seam between
## them and the socket, and it carries places and names, never a bearing and
## never a gene index (§0.2, §2).
##
## **A host checks what its guests say** (net-hardening.md part B, #57). Every
## word a guest sends -- where its cell is, how big, what it wears, an arrival,
## a sister, a death, a shout -- goes through that guest's referee
## (`referee.gd`) before it reaches the field, and the field is handed the
## referee's answer: taken, clamped, or left. A broken rule is a foul on the
## session's ledger. The field itself is unchanged and trusts what it is handed.
##
## RefCounted and preloaded, no node and no class_name, like every other file in
## game/net/ -- see the note at the top of signal_bus.gd.

const Wire := preload("res://game/net/wire.gd")
const NetSession := preload("res://game/net/net_session.gd")
const Referee := preload("res://game/net/referee.gd")
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
## **A host frame this long after the last is a stall**, and what arrives in it
## is the stall's backlog: every referee is handed the gap (net_session.gd's
## STALL_GAP, A.4, for the same reason).
const STALL_GAP := 0.25
## How many referees tools can still read after their guests have gone.
const REFEREES_KEPT := 8

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

## Dedicated host: one plain line about a guest -- joined, arrived, died, left
## -- for the server's log. A phone's pond never says anything here.
signal noted(line: String)

var hosting := false
## **A dedicated host** (`game/server/`): a host with no cell of its own and a
## guest for every one the session greets, up to two, each of whom is told the
## other is the friend. Built by passing no cell; a phone's run always passes
## one.
var dedicated := false

var _net: Node = null
var _food: FoodField = null
var _cell: CellBody = null
## The genome node, untyped for the reason cell.gd's is: genome.gd preloads
## cell.gd, and this file preloads both.
var _genome: Node = null

# --- Host ---------------------------------------------------------------------
## **Everything the host keeps about one guest.** A phone's pond has exactly one,
## made with the run and never replaced: id 0, which means "the session's only
## peer" and speaks through the session's one-peer calls, in the person slot.
## A dedicated host has one per greeted guest, by peer id, each in a person slot
## of its own, spoken to through the session's `*_to` calls.
class Guest:
	## The guest's peer id, or 0 for a phone's one guest.
	var id := 0
	## Its body's slot in the host's field.
	var slot := FoodField.PERSON_SLOT
	## Body version last sent as GENOME, by slot: `serial * 1000 + meals`, the
	## mirror's own book key.
	var sent := {}
	## When the next snapshot is due if no state frame goes first, and how many
	## state frames had gone when the last one went.
	var pond_due := 0.0
	var states_seen := -1
	## The guest's track entry last carried into the person, by identity.
	var basis: Array = []
	## True from ENTER until the guest's state frames say it is swimming here:
	## the person waits at the arrival, out of the water, and nothing is sent to
	## a mirror that is not there yet.
	var awaiting := false
	var awaiting_since := 0.0
	## The KILLED the field just said, waiting for the person_died that follows
	## it in the same call with the cause.
	var killed_at := Vector2.ZERO
	var killed_pending := false
	## Dedicated only: what this guest last said it wears, `[tiers, order]`,
	## for the other guest; and where its body last was.
	var worn: Array = []
	var last_at := Vector2.ZERO
	var known := false
	## **What the host checks this guest's word against** (`referee.gd`): made
	## with the record, and on a phone again with every connection -- so the
	## connection's first arrival is its first.
	var referee: Referee = null

var _guests: Array = []
var _flush_queued := false
## When [method step] last ran, for a stall: see [constant STALL_GAP].
var _stepped_at := 0.0
## **A phone host's shouts, already judged**: the session keeps them for the
## run, which drains them later in the frame, so each is judged once, the frame
## it lands, and those left standing are known here by identity.
var _shouts_judged: Array = []
## **For tools**: the newest referees made, the last [constant REFEREES_KEPT],
## so a probe can read one after its guest has gone.
var referees_made: Array = []
## **For tools**: where the last arrival was measured from and where it landed,
## the largest snapshot sent and how many went.
var arrival_from := Vector2.ZERO
var arrival_at := Vector2.ZERO
var pond_bytes_max := 0
var ponds_sent := 0
var genomes_sent := 0
## Where the other player's body last was, and whether there has been one: a
## phone host's guest, for its own return from the black.
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


## A phone's run passes its own [param cell] and [param genome]; a dedicated
## host passes neither, and is one (`game/server/`).
func _init(net: Node, food: FoodField, cell: CellBody, genome: Node) -> void:
	_net = net
	_food = food
	_cell = cell
	_genome = genome
	hosting = bool(net.hosting)
	dedicated = hosting and cell == null
	# **Nothing said before this run is about this run.** The session queues
	# events from the moment it is up and nothing drains them between runs, so
	# a new run would open on an old one's news -- `they died` for a death on
	# the chooser, or an ARRIVE answering an ENTER a run long gone had sent.
	# Everything this run needs is said again once it is here: the host
	# answers a new ENTER with ARRIVE, PERSON and every genome.
	net.drain_pond_events()
	_stepped_at = _now()
	if dedicated:
		net.drain_inbox()
	elif hosting:
		# Its referee comes with the first frame the link is up: see _step_host.
		_guests.append(Guest.new())
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


## **The host cut this guest** -- its gate or its referee, `REFUSE_BROKEN`, or
## the owner revoking the invite it came in by, `REFUSE_INVITE` -- rather than
## going: what a guest's run says when its pond ends.
func cut_off() -> bool:
	return _net != null and is_instance_valid(_net) \
		and int(_net.link) == NetSession.Link.REFUSED \
		and (int(_net.refused_for) == Wire.REFUSE_BROKEN
			or int(_net.refused_for) == Wire.REFUSE_INVITE)


## Seconds since anything arrived from the other player, or -1.
func quiet_for() -> float:
	if _net == null or not is_instance_valid(_net):
		return -1.0
	return float(_net.quiet_for())


## How many guests have a body in this water right now: on the water's slots,
## not the wire -- a guest who is connected but has not arrived has none.
func guests_in_water() -> int:
	var count := 0
	for g: Guest in _guests:
		if _food.person(g.slot) != null:
			count += 1
	return count


# ---------------------------------------------------------------------------
# The host.
# ---------------------------------------------------------------------------

func _step_host() -> void:
	_mind_stall()
	if dedicated:
		_step_dedicated()
		return
	var g: Guest = _guests[0]
	if not together():
		if _food.person(g.slot) != null:
			_drop_person(g)
		g.awaiting = false
		# **The next connection is a new guest to the referee**: its first
		# arrival is a first arrival, as A's ledger starts clean for it too.
		g.referee = null
		_shouts_judged.clear()
		return
	if g.referee == null:
		g.referee = _new_referee()
	for frame: PackedByteArray in _net.drain_pond_events():
		_host_hears(g, frame)
		if _gone(g):
			return
	_carry_guest(g)
	if _gone(g):
		return
	_judge_heard(g)
	var pb: Object = _person_body(g.slot)
	if _food.person(g.slot) != null and pb != null:
		_friend_at = pb.pos
		_friend_known = true
		_watch_worn()
	if _food.person(g.slot) != null and not _flush_queued:
		# **At the end of this frame**, after the field has stepped: the
		# snapshot is then the water as this frame leaves it, and the guest's
		# mirror, which carries it on by one frame of its own, stands where the
		# water really is. Built at the start of the frame instead, it was a
		# frame old before it left.
		_flush_queued = true
		_flush.call_deferred()


## **A dedicated host's frame**: the same intake, carry and snapshot as a
## phone's, once for each guest -- and what a phone host says about its own
## cell said about each guest's friend instead: what the other one wears, how
## it died, and every call it makes are passed on.
func _step_dedicated() -> void:
	# Its pond is open for good and it has no body: what a phone host's state
	# frames say while it is on the black.
	_net.set_pond(_food.pond_open(), _food.pond_open() and not _food.in_water)
	_meet_guests()
	for said: Array in _net.drain_inbox():
		var from := _guest_by_id(int(said[0]))
		# A guest a foul just cut is heard no further, however much it said.
		if from != null and not _gone(from):
			_host_hears(from, said[1])
	var any := false
	for g: Guest in _guests:
		if _gone(g):
			continue
		_carry_guest(g)
		var pb: Object = _person_body(g.slot)
		if _food.person(g.slot) != null and pb != null:
			g.last_at = pb.pos
			g.known = true
			any = true
	if any and not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


## A record for every guest the session has greeted, in a person slot of its
## own; a guest the session no longer has is taken out of the water and
## forgotten, which frees its slot.
func _meet_guests() -> void:
	var ids: Array = _net.guests() if together() else []
	for g: Guest in _guests.duplicate():
		if ids.has(g.id):
			continue
		if _food.person(g.slot) != null:
			_drop_person(g)
		_guests.erase(g)
		noted.emit("guest %d left -- %d of %d here" % [g.id, _guests.size(),
			FoodField.GUESTS_MAX])
		if _guests.is_empty():
			_food.empty_water()
			noted.emit("nobody is left, so the water goes with them")
	for id: int in ids:
		if _guest_by_id(id) != null:
			continue
		var slot := _free_person_slot()
		if slot < 0:
			continue
		var g := _new_guest()
		g.id = id
		g.slot = slot
		_guests.append(g)
		noted.emit("guest %d joined -- %d of %d here" % [id, _guests.size(),
			FoodField.GUESTS_MAX])


## **One guest's event, through its referee, then into the water.** Each branch
## asks first and acts on the answer; a foul goes to the ledger at once, and a
## guest it cuts is heard no further.
func _host_hears(g: Guest, frame: PackedByteArray) -> void:
	var now := _now()
	_settle(g)
	match Wire.event_type(frame):
		Wire.EVENT_PERSON:
			var said := Wire.take_person(frame)
			if said.is_empty():
				return
			# **A new body only when it can be one**, and the same tiers
			# otherwise but for the gift (B.2): what is applied is the answer.
			var take: Array = g.referee.judge_person(now, bool(said[0]), said[1], said[2],
				_food.person(g.slot) != null)
			_charge(g)
			if take.is_empty() or _gone(g):
				return
			var new_body := bool(take[0])
			_food.set_person_genome(said[1], said[2], g.slot)
			if new_body:
				_food.renew_person(g.slot)
				friend_renewed.emit()
			if dedicated:
				# What this guest wears is what its friend is told it wears --
				# now, if the friend is in the water, and on arriving if not.
				g.worn = [said[1], said[2]]
				var other := _other(g)
				if other != null and _food.person(other.slot) != null:
					_send(other, Wire.EVENT_PERSON,
						Wire.person_payload(new_body, said[1], said[2]))
		Wire.EVENT_ENTER:
			var said := Wire.take_enter(frame)
			if said.is_empty():
				return
			# **Only with no body here, or one that has not arrived**, not too
			# often, and as a born cell after a death. Refused, it is simply not
			# answered: the guest asks again after REACH_TIMEOUT, as it does for
			# an ENTER that was lost.
			var take: bool = g.referee.judge_enter(now, float(said[0]),
				_food.person(g.slot) != null)
			_charge(g)
			if take and not _gone(g):
				_host_enter(g, float(said[0]))
		Wire.EVENT_SISTER:
			var said := Wire.take_sister(frame)
			if said.is_empty():
				return
			# **Once for each division**, on the ring round her mother, a
			# daughter's size: otherwise nothing, or put there. A division this
			# host never saw begin -- its OUT frames landed in this same frame,
			# behind its SISTER -- is proved by the body it knows: here, and fed
			# to r40.
			var take: Array = g.referee.judge_sister(now, said[0], float(said[2]),
				_food.person(g.slot) != null)
			_charge(g)
			if take.is_empty() or _gone(g):
				return
			var slot := _food.place_sister(take[0], float(said[1]), float(take[1]),
				said[3])
			if slot >= 0:
				sister_placed.emit(slot)
		Wire.EVENT_DIED:
			# The guest's own death, and only the one the guest decides:
			# starving. A death this field made has already taken the person
			# out, and its DIED is the same death said twice. Any other cause
			# said of a body still here takes it out all the same -- dying is
			# the guest's right -- and is reported as starving.
			var said := Wire.take_died(frame)
			if said.is_empty():
				return
			var take: Array = g.referee.judge_died(now, int(said[0]), int(said[1]),
				_food.person(g.slot) != null)
			_charge(g)
			if take.is_empty():
				return
			var at: Vector2 = _person_body(g.slot).pos
			_food.remove_person(g.slot)
			g.awaiting = false
			friend_died.emit(int(take[0]), int(take[1]), at, false)
			if dedicated:
				_tell_friend_died(g, int(take[0]), int(take[1]), at)
		Wire.EVENT_SHOUT:
			# Only a dedicated host hears a shout here -- a phone's session
			# keeps them for the run, and [method _judge_heard] asks there --
			# and it has no ear: it passes the call on to the other guest, as
			# the numbers that came in, if the referee lets it be heard.
			var said := Wire.take_shout(frame)
			var other := _other(g)
			if not dedicated or said.is_empty() or not _shout_heard(g, said) or _gone(g):
				return
			if other != null:
				_send(other, Wire.EVENT_SHOUT, Wire.shout(0, said[0], float(said[1]),
					float(said[2])).slice(Wire.EVENT_HEADER))
		_:
			pass


## **A guest's cell asks to come into this water** (§1.6): put it
## [constant ARRIVAL] along the world horizontal from the friend -- a phone
## host's own cell, alive or where it last was -- and say where. A guest already
## in here is taken out first: an ENTER is always a new arrival.
##
## It waits out of the water until the guest's state frames say it is swimming
## here, which is the length of the guest's own beat: nothing can bite a body
## the other screen has not put in the water yet.
##
## **A re-entry is the old body, continued** (the referee's re-entry rule, the
## owner's decision): the new body takes the wound and what was left of the
## grace of the one that left, when the referee says so. The field grants every
## new person a fresh wound and grace, so they are written over it here -- the
## two numbers `_step_person` runs down, and nothing that sizes a body.
func _host_enter(g: Guest, radius: float) -> void:
	if _food.person(g.slot) != null:
		# Legal only for a body that never arrived: the referee is told it left.
		_leave(g)
		_food.remove_person(g.slot)
	var from := _arrival_origin(g)
	var at := arrival_point(from, radius)
	arrival_from = from
	arrival_at = at
	_food.place_person(at, 0.0, radius, Vector2.ZERO, 0.0, g.slot)
	_food.set_person_in_water(false, g.slot)
	var kept: Array = g.referee.arrive(_now(), at, radius)
	var p: Object = _food.person(g.slot)
	var pb: Object = _person_body(g.slot)
	if not kept.is_empty() and p != null and pb != null:
		pb.wound = float(kept[0])
		p.first_hunt = float(kept[1])
	var track: Array = _track_of(g)
	g.basis = track[track.size() - 1] if not track.is_empty() else []
	g.awaiting = true
	g.awaiting_since = _now()
	# A new mirror knows none of this water yet: every genome goes again.
	g.sent.clear()
	g.last_at = at
	g.known = true
	if not dedicated:
		_friend_at = at
		_friend_known = true
	_send(g, Wire.EVENT_ARRIVE, Wire.arrive_payload(at, 0.0))
	if dedicated:
		# The friend's PERSON, as a phone host sends its own: what the other
		# guest wears, if it has ever said.
		var other := _other(g)
		if other != null and not other.worn.is_empty():
			_send(g, Wire.EVENT_PERSON,
				Wire.person_payload(false, other.worn[0], other.worn[1]))
		noted.emit("guest %d arrived at (%.0f, %.0f)" % [g.id, at.x, at.y])
	else:
		_send_person(false)
	friend_entered.emit()


## **Where an arrival is measured from.** A phone host: its own cell, alive or
## where it last was. A dedicated host has none, so the other guest takes its
## place -- alive, or where they last were -- and with no other guest, where
## this one last was; and the middle of the water for a first arrival alone.
func _arrival_origin(g: Guest) -> Vector2:
	if not dedicated:
		return _cell.position
	var other := _other(g)
	if other != null:
		var ob: Object = _person_body(other.slot)
		if _food.person(other.slot) != null and ob != null:
			return ob.pos
		if other.known:
			return other.last_at
	return g.last_at if g.known else Vector2.ZERO


## **Where a cell arriving near [param near] goes** (§1.6): [constant ARRIVAL]
## along the world horizontal -- east, then west -- and then round the circle
## in [constant ARRIVAL_STEP_DEG] steps, the first spot clear of every body in
## the water by both radii and [constant ARRIVAL_CLEAR]. Nothing clear, the
## first side anyway: a crowded arrival is still an arrival.
func arrival_point(near: Vector2, radius: float) -> Vector2:
	var angles: Array[float] = [0.0, PI]
	var step := deg_to_rad(ARRIVAL_STEP_DEG)
	# **Shallowest first** (shared-pond-ux.md §1): at 1280x720 an arrival more
	# than 37 degrees off the horizontal lands off the frame, so every 30-degree
	# spot either side of it is tried before anything steeper.
	for k: int in [1, 5, 7, 11, 2, 4, 8, 10, 3, 9]:
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
	if _food.anchored and _cell != null and at.distance_to(_cell.position) \
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
##
## **What is carried is the referee's answer to the frame, not the frame**
## (`referee.gd`'s `claim`): its place no further than the movement budget
## allows, its heading likewise, its size no bigger than the host has fed it,
## its motion under the cap, and out of the water only to divide.
func _carry_guest(g: Guest) -> void:
	if _food.person(g.slot) == null:
		return
	var flags: int = _flags_of(g)
	if (flags & Wire.STATE_POND) == 0:
		if g.awaiting and _now() - g.awaiting_since < NetSession.REACH_TIMEOUT:
			return
		_drop_person(g)
		return
	g.awaiting = false
	var track: Array = _track_of(g)
	if not track.is_empty():
		var newest: Array = track[track.size() - 1]
		if not is_same(newest, g.basis):
			g.basis = newest
			var put: Array = g.referee.claim(_now(), newest[1], float(newest[2]),
				float(newest[3]), newest[4], float(newest[5]),
				(flags & Wire.STATE_OUT) != 0)
			_charge(g)
			if _gone(g):
				return
			_food.set_person_in_water(bool(put[5]), g.slot)
			_food.place_person(put[0], float(put[1]), float(put[2]), put[3],
				float(put[4]), g.slot)
	_food.set_person_quiet(_quiet_of(g) >= VisionLayer.PEER_FRESH, g.slot)


## **What the guest's newest state frame already says, before its events are
## judged.** A guest that leaves the pond and asks straight back in sends the
## state frame that says it has gone first, and its PERSON and ENTER after it,
## in the same frame -- but a host takes events before it carries state frames
## ([method _step_host]), and would judge an arrival from a guest it still has
## swimming here. So a body whose guest's POND bit has gone, and which is not
## waiting to arrive, is let go now, as [method _carry_guest] would at the end
## of this frame. Only a state frame that is lost on the way still makes one
## honest arrival look early -- the one point the arrival rule allows for.
func _settle(g: Guest) -> void:
	if _food.person(g.slot) == null or (_flags_of(g) & Wire.STATE_POND) != 0:
		return
	if g.awaiting and _now() - g.awaiting_since < NetSession.REACH_TIMEOUT:
		return
	_drop_person(g)


func _drop_person(g: Guest) -> void:
	_leave(g)
	_food.remove_person(g.slot)
	g.awaiting = false
	friend_left.emit()


## **The body leaves without dying**, told to the referee with its wound and
## grace as they stand: what a re-entry inside 30 s carries on with.
func _leave(g: Guest) -> void:
	var p: Object = _food.person(g.slot)
	var pb: Object = _person_body(g.slot)
	if g.referee == null or p == null or pb == null:
		return
	g.referee.left(_now(), float(pb.wound), maxf(float(p.first_hunt), 0.0))


## **The snapshots, at the end of the frame**: one for each guest in the water.
func _flush() -> void:
	_flush_queued = false
	for g: Guest in _guests:
		_flush_guest(g)


## **One guest's snapshot.** With every state frame this end has sent since the
## last one -- so a jump the state frame carries at once is in the guest's
## water at once too -- and otherwise every STATE_PERIOD, which keeps the water
## moving on the guest's screen while this cell is dead and its own state
## frames beat at two a second.
func _flush_guest(g: Guest) -> void:
	if not together() or _food.person(g.slot) == null or g.awaiting:
		return
	var now := _now()
	var states: int = _net.states_sent()
	if states == g.states_seen and now < g.pond_due:
		return
	g.states_seen = states
	g.pond_due = now + NetSession.STATE_PERIOD
	var bodies := _food.pond_entries(true) if g.id == 0 \
		else _food.pond_entries_for(g.slot)
	_send_genomes(g, bodies)
	var pb: Object = _person_body(g.slot)
	var wound := float(pb.wound) if pb != null else 0.0
	var size: int = _net.send_pond(wound, bodies) if g.id == 0 \
		else _net.send_pond_to(g.id, wound, bodies)
	pond_bytes_max = maxi(pond_bytes_max, size)
	ponds_sent += 1


## Every body in the send set whose version the guest has not been sent.
func _send_genomes(g: Guest, bodies: Array) -> void:
	var cells := _food.bodies()
	for entry: Array in bodies:
		var slot := int(entry[FoodField.Entry.SLOT])
		if slot >= FoodField.PERSON_SLOT or slot >= cells.size():
			continue
		var serial := int(entry[FoodField.Entry.SERIAL])
		var meals := int(entry[FoodField.Entry.MEALS])
		var version := (serial & 0xFFFF) * 1000 + meals
		if int(g.sent.get(slot, -1)) == version:
			continue
		g.sent[slot] = version
		genomes_sent += 1
		_send(g, Wire.EVENT_GENOME, Wire.genome_payload(slot, serial, meals,
			cells[slot].genome))


## **What the field did to a guest, told to that guest.** Every contact but a
## death goes as it is said; a death waits the moment it takes the field to say
## why, which is the next signal in the same call.
func _on_person_touched(what: int, at: Vector2, level: float, by: int,
		gene: StringName) -> void:
	var g := _guest_in(_food.touched_slot)
	if g == null:
		return
	if what == FoodField.Contact.KILLED:
		g.killed_at = at
		g.killed_pending = true
		return
	if what == FoodField.Contact.ATE and g.referee != null:
		# **The meal the guest will grow by**, counted as it is sent: the
		# guest's radius can only lag behind what the host expects of it.
		g.referee.ate()
	_send(g, Wire.EVENT_CONTACT, Wire.contact_payload(what, at, level, by, gene))


func _on_person_died(cause: int, by: int, at: Vector2) -> void:
	var g := _guest_in(_food.touched_slot)
	if g == null:
		return
	if g.referee != null:
		g.referee.died(_now())
	var hit := g.killed_at if g.killed_pending else at
	g.killed_pending = false
	g.awaiting = false
	_send(g, Wire.EVENT_CONTACT,
		Wire.contact_payload(FoodField.Contact.KILLED, hit, 0.0, by, &"", cause))
	friend_died.emit(cause, by, at, _eaten_by_friend(cause, by))
	if dedicated:
		g.last_at = at
		_tell_friend_died(g, cause, by, at)


## **A guest died, told to the other one** -- as a phone host tells its guest
## its own death, with DIED. [param by] needs no turning round: the only other
## mouth in a pond of two is the one being told, so "by the friend" says "by
## you" to it, and its "you ate them" is right.
func _tell_friend_died(g: Guest, cause: int, by: int, at: Vector2) -> void:
	var how := _cause_name(cause)
	if cause != FoodField.Cause.STARVED:
		how += ", by " + ("the other guest" if by == FoodField.By.FRIEND else "the water")
	noted.emit("guest %d died (%s)" % [g.id, how])
	var other := _other(g)
	if other != null:
		_send(other, Wire.EVENT_DIED, Wire.died_payload(cause, by, at))


# --- The guest records, and speaking to one ------------------------------------

func _new_guest() -> Guest:
	var g := Guest.new()
	g.referee = _new_referee()
	return g


func _new_referee() -> Referee:
	var referee := Referee.new(_now())
	referees_made.append(referee)
	while referees_made.size() > REFEREES_KEPT:
		referees_made.remove_at(0)
	return referee


## **The referee of guest [param id]** -- 0 for a phone's one guest -- or null.
## For tools.
func referee_of(id: int = 0) -> Referee:
	var g := _guest_by_id(id)
	return g.referee if g != null else null


## **A host frame long after the last is a stall**: every referee is handed the
## gap, as the session's budgets are (A.4), because what lands now is the
## backlog of a host that could not listen, not a guest that swam too far.
func _mind_stall() -> void:
	var now := _now()
	var gap := now - _stepped_at
	_stepped_at = now
	if gap <= STALL_GAP:
		return
	for g: Guest in _guests:
		if g.referee != null:
			g.referee.stalled(gap)


## **Every foul the referee just called, on the guest's ledger** -- which may
## cut it here and now. The session decides whether a foul is enforced or only
## watched (`enforce_referee`).
func _charge(g: Guest) -> void:
	if g.referee == null:
		return
	var id := _peer_of(g)
	for foul: Array in g.referee.take_fouls():
		if id != 0:
			_net.strike(id, float(foul[1]), str(foul[2]))


## The session's peer id for [param g]: a dedicated host's guests carry theirs;
## a phone's one guest is whoever the session has greeted.
func _peer_of(g: Guest) -> int:
	if g.id != 0:
		return g.id
	var ids: Array = _net.guests()
	return int(ids[0]) if not ids.is_empty() else 0


## True once [param g]'s link is gone -- a foul can cut it mid-frame, and
## nothing it said after that is anybody's to act on.
func _gone(g: Guest) -> bool:
	if g.id == 0:
		return not together()
	return not (_net.guests() as Array).has(g.id)


## **A phone host's shouts, judged the frame they land**, before the run hears
## them: the session keeps a host's shouts for the run -- `normal_mode.gd`'s
## `_hear_others` drains them later in this same frame, and not at all in one
## where its cell is dead or held -- so each is judged once, here, and the ones
## the referee refuses are taken out of the queue. Those it lets stand are
## remembered by identity, so a shout the run has not drained yet is not
## judged, or charged, twice.
func _judge_heard(g: Guest) -> void:
	var heard: Array = _net.heard
	if heard.is_empty():
		_shouts_judged.clear()
		return
	var kept: Array = []
	for said: Array in heard.duplicate():
		var known := false
		for judged: Array in _shouts_judged:
			if is_same(judged, said):
				known = true
				break
		if known or _shout_heard(g, said):
			kept.append(said)
		if _gone(g):
			# Cut by the shout just judged: the session has let go of everything
			# it said, and none of it goes back.
			_shouts_judged.clear()
			return
	_shouts_judged = kept.duplicate()
	if kept.size() != heard.size():
		heard.clear()
		heard.append_array(kept)


## **One shout, asked of the referee**: where it was made against where the
## guest has been swimming, how big and how far it carries against what the
## host knows of the body -- when that body is in the water here.
func _shout_heard(g: Guest, said: Array) -> bool:
	if g.referee == null:
		return true
	var p: Object = _food.person(g.slot)
	var wet: bool = p != null and bool(p.in_water)
	var heard: bool = g.referee.judge_shout(_now(), said[0], float(said[1]),
		float(said[2]), wet)
	_charge(g)
	return heard


func _guest_by_id(id: int) -> Guest:
	for g: Guest in _guests:
		if g.id == id:
			return g
	return null


func _guest_in(slot: int) -> Guest:
	for g: Guest in _guests:
		if g.slot == slot:
			return g
	return null


## The other guest of a dedicated host's two, or null.
func _other(g: Guest) -> Guest:
	for o: Guest in _guests:
		if o != g:
			return o
	return null


## The first person slot no guest has, or -1.
func _free_person_slot() -> int:
	for k in FoodField.GUESTS_MAX:
		if _guest_in(FoodField.PERSON_SLOT + k) == null:
			return FoodField.PERSON_SLOT + k
	return -1


## The session's one-peer calls for a phone's guest, and the per-guest ones for
## a dedicated host's -- so a phone's pond sends and reads exactly what it did.
func _send(g: Guest, type: int, payload: PackedByteArray) -> void:
	if g.id == 0:
		_net.send_event(type, payload)
	else:
		_net.send_event_to(g.id, type, payload)


func _flags_of(g: Guest) -> int:
	return int(_net.peer_flags()) if g.id == 0 else int(_net.flags_of(g.id))


func _track_of(g: Guest) -> Array:
	return _net.peer_track() if g.id == 0 else _net.track_of(g.id)


func _quiet_of(g: Guest) -> float:
	return quiet_for() if g.id == 0 else float(_net.quiet_for_of(g.id))


static func _cause_name(cause: int) -> String:
	match cause:
		FoodField.Cause.SWALLOWED:
			return "swallowed"
		FoodField.Cause.CHEWED:
			return "chewed"
		FoodField.Cause.STARVED:
			return "starved"
		FoodField.Cause.POISONED:
			return "poisoned"
	return "cause %d" % cause


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


func _person_body(slot: int = FoodField.PERSON_SLOT) -> Object:
	var bodies := _food.bodies()
	return bodies[slot] if bodies.size() > slot else null


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
