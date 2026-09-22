extends Node
## The session: one socket, one other cell, and the bytes between them.
##
## **What this is not.** There is no lobby, no browser, no matchmaking, no
## account and no name. The second player is somebody you already texted, and
## the code on the host's ring is the entire invitation mechanism -- so every
## question that presupposes strangers (moderation, blocking, reporting,
## reputation, identity) is not deferred here, it is absent. multiplayer.md §0.2
## and §10 row 1.
##
## **It lives under `/root`, not in a scene, and it is not an autoload.** The
## autoload list is snapshotted before `build_info.gd` mounts the content pack,
## so an autoload cannot arrive as content -- measured. A plain Node parented to
## the window root survives `change_scene_to_file` the same way an autoload
## would, costs no project setting, and therefore costs no `binary_version`.
## [member current] is how the two scenes that need it find it.
##
## **Never assume the host is peer 1.** ENet hands out random 32-bit peer ids --
## this container produced 694971552 and 1587052382 on two consecutive runs --
## and the only reason the *server* is reliably 1 is an ENet convention that a
## WebSocket or relay transport is under no obligation to repeat. So the literal
## 1 does not appear in this file. The guest learns the host's id from
## `peer_connected`, checks it against the id the host puts in its own welcome,
## and addresses every later frame to that. `send_bytes`'s broadcast id 0 is
## never used either: every send names a peer out of the bookkeeping below.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Wire := preload("res://game/net/wire.gd")
const Lan := preload("res://game/net/lan.gd")

## Where the link is. The screen reads this and nothing else to decide what to
## draw; the run reads [constant Link.TOGETHER] to decide whether to shout.
enum Link {
	## No socket. The single-player state, and the state of a torn-down session.
	OFF,
	## Hosting, with nobody here yet.
	LISTENING,
	## Guesting: the transport is up or coming up, and the handshake has not
	## finished. A guest is never TOGETHER until it has been welcomed.
	REACHING,
	## Handshake complete, one other cell on the wire.
	TOGETHER,
	## Somebody said no, and [member trouble] says why in a sentence.
	REFUSED,
	## Nothing answered, or there was nothing to answer from.
	FAILED,
}

signal link_changed(link: int)

## The live session, or null. Set in [method _ready] and cleared in
## [method _exit_tree], so it is never a reference to a freed node.
static var current: Node = null

## How long the host waits for a guest's greeting before hanging up on it. A
## transport connection that never says hello is a port scanner, a crash, or a
## build so old it does not know it has to.
const HELLO_GRACE := 3.0
## How long a guest waits for anything at all. Deliberately shorter than ENet's
## own give-up: an unanswered address must become a sentence on screen, not a
## spinner. multiplayer.md §4.2 budgets the reply wait at ~2 s; this is double.
const REACH_TIMEOUT := 4.0
## **The beat when there is nothing moving to draw**: 2 Hz, thirty-one bytes.
## The join screen, a cell that has died, a run that is paused or dividing. It
## is still the only defence against `godotengine/godot#37186`, where a
## force-closed client is never noticed, and still what keeps [method
## quiet_for] small -- it just no longer paces a swimming body. See [constant
## STATE_PERIOD] for that, and for why this used to be the whole story.
const HEARTBEAT := 0.5
## **Twenty state frames a second while a body is being reported.**
##
## This was 2 Hz, and the owner felt it on two phones: a friend's cell that
## jumped or turned showed it late enough to be called a second. Measured on
## loopback with `tools/net_lag.gd` -- no network in it at all -- the old
## pairing of this beat with `vision.gd`'s half-second draw delay put the drawn
## friend about 0.55 s behind the real one. The radio budget it was protecting
## is not one a home LAN has: thirty-one bytes twenty times a second is 620 B/s.
##
## **Why twenty and not more or fewer.** The far screen now carries the body
## forward between frames along the velocity each frame brings, and at 50 ms
## apart that carry is off by a few hundredths of a unit on a cell coasting at
## cruising speed, a fifth of one at the top impulse speed -- the error is drag,
## `v * 0.74 * dt^2 / 2`. So faster buys nothing a player can see. It does cost: every packet is air time on a Wi-Fi channel two phones
## share, and more packets on a shared channel is more contention, which is
## jitter bought for no picture. Slower is the other way wrong: at 10 Hz, two
## frames lost in a row leave a 300 ms hole, and `vision.gd` carries a body at
## most 200 ms before it freezes -- 20 Hz rides over two lost frames and still
## lands the third inside that reach.
##
## **And the jumps do not wait for it.** [method report_body] sends at once
## whenever waiting for this beat would let the far end's picture stray -- see
## [constant STRAY_PLACE] -- so this constant paces the smooth part of the
## motion and nothing else.
const STATE_PERIOD := 0.05
## **Send now rather than on the beat, if waiting would let the far end's guess
## drift this far**, in world units. The far end carries the last frame along
## its velocity; this end runs the same arithmetic against the truth, one beat
## ahead. 1.5 units is a pixel and a half at the base shape.
##
## A coasting body never comes near it -- the carry is exact but for drag. A
## flagellar impulse is 97-190 units a second of new velocity, five to ten units
## of drift over one beat, so it goes the moment it fires: that is the whole of
## "send immediately on a jump", and it also catches the jumps nothing
## announces -- a bump off a mote, a shove -- because it tests the picture and
## not a list of events.
const STRAY_PLACE := 1.5
## The same for the heading, in radians: two degrees, a little over one step of
## the wire's heading byte (0.0245 rad), so rounding alone can never trip it.
## An impulse's kick is up to 0.16 rad and goes at once.
##
## **A steering change never trips it, and that is the physics, not the
## threshold.** Steering sets a demand and `cell.gd` turns the heading toward
## it over 0.65-1.43 s by `cirrus` tier, so fifty milliseconds after a hard-over
## the heading has moved about a thousandth of a radian and the turn rate a few
## hundredths. There is nothing in a turn's first frame worth sending early:
## the beat carries the turn as it builds, with the rate that is building it.
const STRAY_TURN := 0.035
## The least two state frames are ever apart. A game reports once a frame
## anyway; a headless run does thousands of frames a second, and a caller that
## reports a moving body with no velocity would otherwise be sent at that rate.
## **A little under one 60 Hz frame, and the "under" matters**: the clock here
## counts whole milliseconds, so two frames of a 60 fps game are 16 or 17 ms
## apart, and a gap of exactly 1/60 s would hold a jump back a frame whenever it
## landed in the frame just after a scheduled send and that frame came 16 ms on.
const EARLY_GAP := 0.012
## After this long with nothing heard, a peer is reported quiet. **Not
## disconnected**: a phone that went into a pocket for eight seconds is still
## the person you are playing with, and dropping them is a worse answer than
## saying so.
const SILENCE := 6.0
## More than one guest is refused with a sentence rather than by the transport,
## so the extra device learns why. Four slots because a half-dead peer holds one
## until ENet times it out, and a retry has to be able to get in past it.
const MAX_PEERS := 4
## Shouts waiting for the run to drain them. Capped because nothing drains while
## the player is still on the session screen.
const HEARD_MAX := 8
## **How many of the other cell's frames are kept: two.** The newest is the one
## a view draws from -- it carries a place and the motion to carry it forward
## by. The one before it is there to be read: it is the interval the stream is
## actually arriving at, and a track of one is a first frame, or the first
## after a gap. **No buffer is kept to draw between frames**, and that was
## measured rather than assumed: under `tools/net_lag.gd`'s simulated Wi-Fi --
## 10-50 ms of jitter, 2% loss -- the largest single-frame leap the drawn
## friend took beyond the real one's own step was 1.2 units over a minute of
## free swimming, where the half-second buffer this replaces leapt 9.2 under
## the same jitter. A buffer would buy latency back for smoothness the marker
## already has.
const TRACK_MAX := 2
## **When the frame before a silence stops being worth blending from.** Two
## seconds, and it is not a place the other cell was on its way from -- it is
## where it was before it went in a pocket. Sliding a marker across that gap
## would animate a journey nobody made, so the track is dropped here and
## `vision.gd` lands the next frame as a step, measuring the gap from the frame
## it was drawing. The *marker* is still theirs and still drawn; see [method
## quiet_for] for what says how old it is.
##
## Two seconds is what this was when it was written as four 2 Hz beats. It is
## a length of silence, not a count of frames, so it did not move with the rate.
const TRACK_GAP := 2.0
## **How long a refusal is given to get out before the line is cut.**
##
## Measured, and it is the difference between a sentence and a shrug: sending a
## refusal and disconnecting in the same call loses the refusal every time. Once
## the transport's status flips to disconnected, `SceneMultiplayer.poll()` stops
## draining packets that have already arrived, so the guest reads "they hung up"
## and never learns that its build is the problem. Lingering a second costs a
## second on a screen nobody is playing on, and buys the one message a player
## cannot work out for themselves.
const REFUSE_LINGER := 1.0

var link := Link.OFF
## The heading a screen puts on the current state of the link, when that state
## is one a player has to be told about. Empty when there is nothing to say.
var trouble := ""
## The sentence under it. Says what to *do*, wherever there is anything to do.
var because := ""
## Set once, at host()/join(), and never derived from a peer id.
var hosting := false
## The address this session is on (hosting) or reaching for (guesting). Shown on
## screen as a receipt, never typed into.
var address := ""

## What the last shout heard on the wire was, as `[at, radius, reach]` each.
## Drained by the run, exactly the way `food.gd`'s own `pings` are.
var heard: Array = []

## **A test seam, and the only one.** 0 means "speak [constant Wire.PROTOCOL]".
## tools/net_probe.gd sets it to something else to prove the refusal path, which
## is the single highest-value assertion CI can make about this file.
var protocol_override := 0

var _api: SceneMultiplayer = null
var _peer: ENetMultiplayerPeer = null
## Peer id -> bookkeeping. Every send addresses a key of this dictionary.
var _peers: Dictionary = {}
## The host's id, as learned from the transport. Only a guest has one.
var _host_id := 0
var _out_state_seq := 0
var _out_event_seq := 0
## **Every clock in this file is wall time, not accumulated frame time.**
## The two are the same thing right up until they are not: Android stops the
## whole main loop at `onActivityStopped`, so a delta accumulator freezes while
## a phone is in a pocket and would report a peer that has been gone for two
## minutes as perfectly fresh. `Time.get_ticks_msec()` keeps counting through
## it, which is the answer the player would give.
var _heartbeat_at := 0.0
## When the next state frame is due while a body is being reported. See
## [method _beat] for why it is not simply [member _heartbeat_at] plus a period.
var _beat_due := 0.0
var _reach_at := 0.0
## Peer id -> when to actually cut the line. See [constant REFUSE_LINGER].
var _hanging_up: Dictionary = {}
## **This cell, as the run last described it**, and the only thing in this file
## that is not a fact about a network. Written by [method report_body] and read
## once per beat; `_body` false is a session with no run behind it, which is
## every session on the join screen and every session whose cell has died.
var _body := false
var _body_at := Vector2.ZERO
var _body_heading := 0.0
var _body_radius := 0.0
var _body_velocity := Vector2.ZERO
var _body_turning := 0.0
## **Whether the run has stopped reporting the body.** It reports once a frame
## while its cell is simulated and stops while it is paused, dividing or dying:
## the body is *held*, and a held body has no velocity whatever its last report
## said. So a held body's frames carry no motion -- one goes at once to say so
## -- and the beat drops back to [constant HEARTBEAT].
##
## **Counted in frames, not seconds, and that was found by rendering.** The
## first version called a body held after 0.1 s without a report. At 2400x1080
## under software GL a frame took longer than that, so every frame this node --
## which processes before the run -- sent a stopped body, and the real report
## that followed was held back by [constant EARLY_GAP]: the friend on the other
## screen stalled, lunged and slid backwards. A phone that hitches past a tenth
## of a second would have done the same. Now it is one question: did a whole
## frame go by with no report in it? [member _reported] is the answer.
var _held := true
var _reported := false
## **What the far end was last told**, as `[when, at, heading, radius,
## velocity, turning]`, or empty for *no body*. Decoded back out of the frame
## that told it rather than remembered from the arguments, so the stray test
## runs against the one-byte heading and the float32 place the far end really
## has, and not against something a little truer that it never received.
var _told: Array = []


func _ready() -> void:
	# Beats and timeouts have to keep running while the game is paused, and they
	# can: SceneTree polls every registered MultiplayerAPI regardless of
	# `paused`, measured in this container by sending a packet across a paused
	# tree and watching it land.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	current = self
	_api = SceneMultiplayer.new()
	# No peer ever talks to another peer, so there is nothing to relay. Off, it
	# also guarantees a guest is told about exactly one other id -- the host's --
	# which is what makes learning the host id from the transport unambiguous.
	_api.server_relay = false
	_api.peer_connected.connect(_on_peer_connected)
	_api.peer_disconnected.connect(_on_peer_disconnected)
	_api.connected_to_server.connect(_on_connected_to_server)
	_api.connection_failed.connect(_on_connection_failed)
	_api.server_disconnected.connect(_on_server_disconnected)
	_api.peer_packet.connect(_on_peer_packet)
	# Bound to this node's own subtree rather than to the whole tree, so the
	# default MultiplayerAPI every other scene runs under is left exactly as it
	# was -- and so two of these can exist in one process, which is the headless
	# recipe CI uses.
	get_tree().set_multiplayer(_api, get_path())


func _exit_tree() -> void:
	if current == self:
		current = null


func _process(_delta: float) -> void:
	var now := _now()
	if link == Link.REACHING:
		if now - _reach_at >= REACH_TIMEOUT:
			_give_up(Link.FAILED, "no answer",
				"both of you have to be on the same wi-fi -- and on some"
				+ " networks that is still not enough to reach across.")
			return
	if hosting:
		# A transport connection that never greets is hung up on, with a reason.
		for id: int in _peers.keys():
			var peer: Dictionary = _peers[id]
			if bool(peer["greeted"]):
				continue
			if now - float(peer["since"]) >= HELLO_GRACE:
				_refuse(id, Wire.REFUSE_SILENT)
	for id: int in _hanging_up.keys():
		if now >= float(_hanging_up[id]):
			_hanging_up.erase(id)
			if _peer != null:
				_peer.disconnect_peer(id, false)
	# **A frame with no report in it is a held body.** Before anything that
	# sends, so the frame that says so is this one.
	_held = not _reported
	_reported = false
	if link == Link.TOGETHER and not _moving():
		# **A swimming body is sent from [method report_body]**, the moment it
		# is reported, so the frame carries this frame's truth and not the last
		# one's -- this node processes before the run does. What is left for
		# here is the beat with nothing moving in it, and the one frame that
		# says a body has just stopped: the far end is still carrying it along
		# its last velocity, and should not be left to.
		if _told_moving() or now - _heartbeat_at >= HEARTBEAT:
			_beat(now)


# ---------------------------------------------------------------------------
# Opening and closing.
# ---------------------------------------------------------------------------

## Take the calls. Returns false, with [member trouble] set, if this device has
## no address to be found at or the port is already taken.
func host() -> bool:
	if _api == null:
		return false
	_reset_socket()
	hosting = true
	address = Lan.local_address()
	if address.is_empty() or Lan.octet_of(address) < 0:
		_give_up(Link.FAILED, "no wi-fi here",
			"this device is not on a network two cells could share.")
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(Lan.PORT, MAX_PEERS)
	if err != OK:
		_give_up(Link.FAILED, "could not listen",
			"something else on this device is already using the water.")
		return false
	_peer = peer
	_api.multiplayer_peer = peer
	set_process(true)
	_set_link(Link.LISTENING)
	return true


## Reach for a host. [param at] is a dotted IPv4 the tap code produced; this
## function never sees a code and never sees a digit.
func join(at: String) -> bool:
	if _api == null:
		return false
	_reset_socket()
	hosting = false
	address = at
	if at.is_empty():
		_give_up(Link.FAILED, "no wi-fi here",
			"this device is not on a network two cells could share.")
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(at, Lan.PORT)
	if err != OK:
		_give_up(Link.FAILED, "could not reach",
			"the address that code points at is not one this device can call.")
		return false
	_peer = peer
	_api.multiplayer_peer = peer
	set_process(true)
	_reach_at = _now()
	_set_link(Link.REACHING)
	return true


## Put the socket down and take this node out of the tree. Safe to call on a
## session that never opened one, and safe to call twice.
func close() -> void:
	_reset_socket()
	if _api != null and is_inside_tree():
		get_tree().set_multiplayer(null, get_path())
	_api = null
	if current == self:
		current = null
	_set_link(Link.OFF)
	queue_free()


## Close whatever session is open, if any. The one line every screen that is
## *not* part of a session calls, so a run that ends leaves nothing listening.
static func close_current() -> void:
	if current != null and is_instance_valid(current):
		current.close()


# ---------------------------------------------------------------------------
# Talking.
# ---------------------------------------------------------------------------

## **The ampulla fired.** Where the pulse left from, how big this cell is, and
## how far its organ carries -- nothing else. Silently does nothing when there
## is nobody to hear it, which is the whole of what single player costs.
func shout(at: Vector2, radius: float, reach: float) -> void:
	if link != Link.TOGETHER:
		return
	_out_event_seq += 1
	_to_everyone(Wire.shout(_out_event_seq, at, radius, reach))


## **Where this cell is and how it is moving, sent now if it is time or if
## waiting would leave the far end wrong.** Called by the run once a frame, and
## once more the instant an impulse fires; the session still never reaches into
## a scene for a position at a moment of its own choosing, and has no business
## knowing there is a scene.
##
## Two reasons to send, and nothing else is one:
##
## - **the beat is due**, every [constant STATE_PERIOD];
## - **the far end's picture would stray** before the next one -- see
##   [method _strays]. That is an impulse, a dash, a bump or a meal, in the frame
##   it happens, and it is what the owner meant by a cell that jumps.
##
## [param velocity] is in world units a second and [param turning] in radians a
## second, both straight off `cell.gd`. Left at their defaults they say *not
## moving*, which is true of a body held in place and makes the far end draw it
## where it was put.
##
## Free with nobody on the wire, the same way [method shout] is: six
## assignments and a comparison, and nothing leaves.
func report_body(at: Vector2, heading: float, radius: float,
		velocity: Vector2 = Vector2.ZERO, turning: float = 0.0) -> void:
	_body_at = at
	_body_heading = heading
	_body_radius = radius
	_body_velocity = velocity
	_body_turning = turning
	_body = radius > 0.0
	_reported = true
	_held = false
	if link != Link.TOGETHER:
		return
	var now := _now()
	if now >= _beat_due:
		_beat(now, true)
	elif now - _heartbeat_at >= EARLY_GAP and _strays(now):
		_beat(now)


## **There is no longer a cell here.** The death of a run, and the state every
## session starts in. The beat keeps going -- the link is fine, the person is
## fine, there is just nothing to draw -- and [method Wire.state_body] on the
## far side returns nothing, so the marker goes out rather than freezing on a
## corpse. Said at once rather than on the next beat: a death is the most
## discrete event there is.
func forget_body() -> void:
	_body = false
	if link == Link.TOGETHER and not _told.is_empty():
		_beat(_now())


## Everything heard since the last drain, oldest first. Empties the queue, so
## the run can call it once a frame and never hear a shout twice.
func drain_heard() -> Array:
	if heard.is_empty():
		return []
	var out := heard
	heard = []
	return out


func peer_count() -> int:
	return _peers.size()


## This session's own peer id, as the transport assigned it. Never compared
## against a constant anywhere; it exists to be printed.
func my_id() -> int:
	return 0 if _api == null else _api.get_unique_id()


## Everyone on the wire, by id. The bookkeeping, readable.
func peer_ids() -> Array:
	return _peers.keys()


## Seconds since anything at all arrived from the other cell, or -1 when there
## is no other cell. The heartbeat is what keeps this small; when it stops
## climbing past [constant SILENCE] the link is technically up and practically
## gone, which is `godotengine/godot#37186` seen from this end.
func quiet_for() -> float:
	var now := _now()
	for id: int in _peers.keys():
		var peer: Dictionary = _peers[id]
		if bool(peer["greeted"]):
			return now - float(peer["heard"])
	return -1.0


## The newest sequence of the other cell's state frames applied here, 0 before
## the first one lands. The sender only ever increments, so it counts frames
## *sent*: state frames go out unreliable, and one lost on the way still moves
## it.
func heartbeats_heard() -> int:
	for id: int in _peers.keys():
		var peer: Dictionary = _peers[id]
		if bool(peer["greeted"]):
			return maxi(int(peer["in_state"]), 0)
	return 0


## **Where the other cell is and how it is moving, as its last two state frames
## said so.** Oldest first, each entry `[when, at, heading, radius, velocity,
## turning]`, and `when` is on this device's own [method clock] -- so a reader
## ages a frame against exactly the clock it was stamped with. A track of one
## is a first frame, or the first after [constant TRACK_GAP] of silence.
##
## Empty when there is nobody on the wire, when the other cell has no body yet,
## and when it has just lost one. **Read-only**: the array is the session's own,
## handed over rather than copied, the same way `food.gd` hands over its points
## -- and each entry is a new array, so a reader may hold on to one and ask
## later whether it is still the newest.
##
## Nothing in this file carries it forward. A place, a motion and a time is the
## whole of what arrived; what to draw from them is a question for whoever is
## drawing, and the answer is different for a marker and for a simulation.
func peer_track() -> Array:
	for id: int in _peers.keys():
		var peer: Dictionary = _peers[id]
		if bool(peer["greeted"]):
			return peer["track"]
	return []


## The clock every stamp in this file is on: wall seconds, monotonic, and
## deliberately not frame time. Public so that a reader of [method peer_track]
## cannot accidentally age a sample against a different one.
func clock() -> float:
	return _now()


## What the screen says about the other cell: whether anything has come from
## them lately.
func peers_say() -> String:
	var quiet := quiet_for()
	if quiet < 0.0:
		return ""
	if quiet >= SILENCE:
		return "quiet for %d seconds" % int(quiet)
	return "within earshot"


# ---------------------------------------------------------------------------
# The transport's own lifecycle.
# ---------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	_peers[id] = {
		"protocol": 0,
		"greeted": false,
		"since": _now(),
		"heard": _now(),
		"in_state": -1,
		"in_event": -1,
		"alive": true,
		"track": [],
	}
	if hosting:
		# The host says nothing first. It waits to be greeted, so the first
		# frame on the wire is always the guest's protocol -- which is the one
		# frame both ends are guaranteed to be able to read.
		return
	# Guesting, and this is the host announcing itself. `server_relay` is off,
	# so it is the only id that will ever arrive here.
	_host_id = id
	_to(_host_id, Wire.hello(_speaks()))


func _on_peer_disconnected(id: int) -> void:
	_peers.erase(id)
	if _greeted_count() == 0:
		_told = []
	if hosting:
		if _peers.is_empty() and link == Link.TOGETHER:
			_say("they left", "the other cell went. show the code again.")
			_set_link(Link.LISTENING)
		return
	if id == _host_id:
		_host_id = 0


func _on_connected_to_server() -> void:
	# The transport is up; the handshake is not. Stay REACHING until welcomed,
	# so a host that cannot speak to us never reads as a session -- but restart
	# the clock, because the wait that remains is the handshake's and not the
	# socket's.
	_reach_at = _now()


func _on_connection_failed() -> void:
	_give_up(Link.FAILED, "no answer",
		"nothing is listening at that code. check your friend is still"
		+ " showing it.")


func _on_server_disconnected() -> void:
	if link == Link.REFUSED:
		# Already explained. The hang-up is the second half of the refusal, not
		# a separate event.
		return
	_give_up(Link.FAILED, "they hung up", "the other cell left the water.")


func _on_peer_packet(id: int, frame: PackedByteArray) -> void:
	var peer: Dictionary = _peers.get(id, {})
	if not peer.is_empty():
		peer["heard"] = _now()
	match Wire.kind(frame):
		Wire.KIND_HELLO:
			_take_hello(id, frame)
		Wire.KIND_WELCOME:
			_take_welcome(id, frame)
		Wire.KIND_REFUSE:
			_take_refuse(frame)
		Wire.KIND_STATE:
			# **Nothing before the handshake.** A peer that has not been
			# greeted cannot put a mark on anybody's membrane; the grace timer
			# above is hanging up on it already.
			if bool(peer.get("greeted", false)):
				_take_state(peer, frame)
		Wire.KIND_EVENT:
			if bool(peer.get("greeted", false)):
				_take_event(peer, frame)
		_:
			# A kind from a build that does not exist yet. Ignored rather than
			# refused: the protocol gate has already run, so this cannot be
			# skew, and a decoder that falls over on an unknown byte is a
			# decoder that cannot be extended.
			pass


# ---------------------------------------------------------------------------
# The handshake. Everything about version skew is in these three functions.
# ---------------------------------------------------------------------------

func _take_hello(id: int, frame: PackedByteArray) -> void:
	if not hosting:
		return
	var theirs := Wire.protocol_of(frame)
	var peer: Dictionary = _peers.get(id, {})
	if peer.is_empty():
		return
	peer["protocol"] = theirs
	if theirs != _speaks():
		# **The refusal that matters.** Updates are opt-in (multiplayer.md
		# §0.1), so the other device may be months behind and may stay there
		# for good. Say so, in a sentence, before hanging up -- on both screens,
		# because the host is the one who can go and fetch the update.
		_refuse(id, Wire.REFUSE_PROTOCOL)
		_say("different versions", _skew_says(theirs))
		return
	if _greeted_count() >= 1:
		_refuse(id, Wire.REFUSE_FULL)
		return
	peer["greeted"] = true
	_to(id, Wire.welcome(_speaks(), _api.get_unique_id()))
	# A new listener has been told nothing, so the next report goes at once.
	_told = []
	_say("", "")
	_set_link(Link.TOGETHER)


func _take_welcome(id: int, frame: PackedByteArray) -> void:
	if hosting:
		return
	var theirs := Wire.protocol_of(frame)
	if theirs != _speaks():
		# Belt and braces. A host that welcomes us on a protocol we do not
		# speak is a host whose refusal path is broken; refuse it from this end
		# rather than play a game neither of us understands.
		_give_up(Link.REFUSED, "different versions", _skew_says(theirs))
		_drop_link()
		return
	# **The id, learned twice and never assumed.** `peer_connected` reported it
	# and the host wrote its own into the welcome; if the two disagree the
	# transport is the authority, because it is what `send_bytes` addresses.
	var claimed := Wire.welcome_host_id(frame)
	if claimed != id:
		push_warning("[net] host calls itself %d, transport says %d" % [claimed, id])
	_host_id = id
	var peer: Dictionary = _peers.get(id, {})
	if not peer.is_empty():
		peer["greeted"] = true
		peer["protocol"] = theirs
	_told = []
	_say("", "")
	_set_link(Link.TOGETHER)


func _take_refuse(frame: PackedByteArray) -> void:
	if hosting:
		# A guest refusing a host is not a thing. Ignored rather than obeyed:
		# the host is the one deciding who is here.
		return
	var reason := Wire.refuse_reason(frame)
	var theirs := Wire.protocol_of(frame)
	if reason == Wire.REFUSE_PROTOCOL:
		_give_up(Link.REFUSED, "different versions", _skew_says(theirs))
	elif reason == Wire.REFUSE_FULL:
		_give_up(Link.REFUSED, "already two",
			"that cell is already swimming with somebody.")
	else:
		_give_up(Link.REFUSED, Wire.reason_says(reason),
			"the other end hung up.")
	_drop_link()


## The sentence a player gets for the one failure that cannot be retried into
## working. It has to name the fix, because nothing on this screen is the fix.
func _skew_says(theirs: int) -> String:
	var mine := _speaks()
	var who := "yours" if mine < theirs else "theirs"
	return ("one of these games is older than the other -- %s. take the update"
		+ " from the launcher, restart, and call again.") % who


## Say no, then wait before hanging up. The waiting is not politeness -- see
## [constant REFUSE_LINGER] for what happens without it. Erased from the
## bookkeeping at once so a refused peer can never be counted as company, and
## kept in [member _hanging_up] so the line still gets cut if the other end
## decides to stay.
func _refuse(id: int, reason: int) -> void:
	_to(id, Wire.refuse(_speaks(), reason))
	_peers.erase(id)
	_hanging_up[id] = _now() + REFUSE_LINGER


# ---------------------------------------------------------------------------
# State and events. The two halves of the WebSocket shape.
# ---------------------------------------------------------------------------

## **Idempotent, drained to newest.** Applying the newest state frame and
## dropping everything behind it is the same as applying them all, which is
## what makes a burst of forty queued frames cost one apply. **The sequence test
## is no longer a formality**: state frames now go out unreliable, and ENet
## delivers an unreliable frame whenever it lands, so a late one can arrive
## after its successor. It is dropped here, which is the whole reason the
## sequence was put in the frame when every frame was still reliable.
func _take_state(peer: Dictionary, frame: PackedByteArray) -> void:
	if peer.is_empty():
		return
	var seq := Wire.seq_of(frame)
	if seq < 0 or seq <= int(peer["in_state"]):
		return
	peer["in_state"] = seq
	peer["alive"] = Wire.state_alive(frame)
	_track(peer, Wire.state_body(frame))


## **Two frames and the times they landed.** Stamped on arrival rather than by
## the sender, because the two devices have no common clock and this one needs
## no more than how long ago a frame arrived -- which is a thing it can measure
## for itself, and the only thing a view carrying it forward wants. The price is
## that a frame is treated as new when it lands: the far body is drawn one
## flight time behind, which on a home LAN is a few tens of milliseconds and on
## loopback is a frame.
##
## Wall time, like every other clock in this file, for the reason on
## [member _heartbeat_at]: a phone in a pocket stops the main loop, and a frame
## accumulator would call a sample from two minutes ago fresh.
func _track(peer: Dictionary, body: Array) -> void:
	var track: Array = peer["track"]
	if body.is_empty():
		# The far cell died, or was never born. Not a gap in the stream -- an
		# answer -- so the track goes rather than ages.
		track.clear()
		return
	var now := _now()
	if not track.is_empty() and now - float(track[track.size() - 1][0]) > TRACK_GAP:
		track.clear()
	track.append([now, body[0], float(body[1]), float(body[2]), body[3],
		float(body[4])])
	while track.size() > TRACK_MAX:
		track.remove_at(0)


## **In order, once each.** An event is not idempotent -- a shout heard twice is
## two shouts -- so a sequence at or behind the last one applied is a duplicate
## and is dropped. A sequence ahead by more than one is a gap, which cannot
## happen on a reliable ordered stream; it is applied anyway and noted, because
## losing a shout is worse than hearing one late.
func _take_event(peer: Dictionary, frame: PackedByteArray) -> void:
	if peer.is_empty():
		return
	var seq := Wire.seq_of(frame)
	if seq < 0 or seq <= int(peer["in_event"]):
		return
	if seq > int(peer["in_event"]) + 1 and int(peer["in_event"]) >= 0:
		push_warning("[net] event gap: %d after %d" % [seq, peer["in_event"]])
	peer["in_event"] = seq
	if Wire.event_type(frame) != Wire.EVENT_SHOUT:
		return
	var said := Wire.take_shout(frame)
	if said.is_empty():
		return
	heard.append(said)
	while heard.size() > HEARD_MAX:
		heard.remove_at(0)


# ---------------------------------------------------------------------------
# Plumbing.
# ---------------------------------------------------------------------------

func _speaks() -> int:
	return Wire.PROTOCOL if protocol_override == 0 else protocol_override


func _to(id: int, frame: PackedByteArray) -> void:
	if _api == null or _api.multiplayer_peer == null:
		return
	var err := _api.send_bytes(frame, id, _mode_for(frame), 0)
	if err != OK:
		push_warning("[net] could not send %d bytes to %d (error %d)"
			% [frame.size(), id, err])


## **How a frame is delivered, chosen by what kind of frame it is and by
## nothing in its bytes.** The one place in this project that knows ENet has
## more than one way to send.
##
## - **A state frame goes unreliable.** It is idempotent and drained to newest
##   (wire.gd), so a lost one is superseded fifty milliseconds later -- and on
##   ENet a *reliable* one that is lost holds every reliable frame behind it
##   until it has been resent. Measured with `tools/net_lag.gd --reliable` on
##   a simulated Wi-Fi losing one frame in fifty: the worst of forty jumps
##   reached the far screen in 173 ms instead of 84, and the worst correction
##   the view had to bleed out was 17.5 units instead of 4.8. The medians
##   barely moved; the tail is what a lost reliable frame costs, and the tail
##   is what a player notices. (The resend timeout in that model, 150 ms, is
##   an estimate of ENet's own on such a link, not a reading of it.) Channel
##   zero, unreliable, is a different ENet channel from channel zero reliable
##   -- `enet_multiplayer_peer.cpp` puts them on separate system channels,
##   read in the 4.7 source -- so a stalled handshake or shout can never hold
##   a state frame up either.
## - **Everything else stays reliable**: the handshake, the refusal and the
##   shout. A shout heard twice is two shouts and a shout lost is a pulse the
##   other cell never felt; neither is superseded by anything.
##
## A WebSocket transport has no modes -- `set_transfer_mode()` is silently
## ignored there -- so it sends everything reliable-ordered, and the frames are
## exactly as correct on it: that is what designing the format for the
## WebSocket shape bought. Porting means deleting this function, not rewriting
## the wire.
static func _mode_for(frame: PackedByteArray) -> int:
	if Wire.kind(frame) == Wire.KIND_STATE:
		return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


## **One state frame, now.** What the far end is told is decoded back out of the
## very bytes that tell it, and kept -- that is the far end's picture, and
## [method _strays] measures the truth against it.
##
## [param on_time] is a frame sent because one was due. The next is then due a
## period after this one *was due*, not after it went: a report only comes once
## a display frame, so measuring from the send would stretch every period to the
## next frame boundary -- 15 to 20 a second at 60 fps instead of 20. Any other
## frame restarts the schedule, because it is as fresh as a scheduled one.
func _beat(now: float, on_time: bool = false) -> void:
	_heartbeat_at = now
	var next := _beat_due + STATE_PERIOD
	_beat_due = next if on_time and next > now else now + STATE_PERIOD
	_out_state_seq += 1
	var moving := _moving()
	var frame := Wire.state(_out_state_seq, _body, _body_at, _body_heading,
		_body_radius, _body_velocity if moving else Vector2.ZERO,
		_body_turning if moving else 0.0)
	var told := Wire.state_body(frame)
	_told = [] if told.is_empty() \
		else [now, told[0], told[1], told[2], told[3], told[4]]
	_to_everyone(frame)


## **Would the far end be wrong by the next beat?** It carries the last frame
## it was told along that frame's velocity and turning; this runs the same
## straight-line arithmetic against the body as it really is, and looks one
## [constant STATE_PERIOD] ahead -- so a new velocity counts at the instant it
## appears, before it has moved the body a single unit, which is what makes an
## impulse leave in the frame it fires.
##
## The body appearing or going, or changing size -- a meal is four units of
## radius at once -- counts as well; none of those is anything the far end
## could have guessed.
func _strays(now: float) -> bool:
	if _told.is_empty():
		return _body
	if not _body:
		return true
	if absf(_body_radius - float(_told[3])) > 0.5:
		return true
	var ahead := now - float(_told[0])
	var told_velocity: Vector2 = _told[4]
	var told_turning := float(_told[5])
	var guess: Vector2 = (_told[1] as Vector2) + told_velocity * ahead
	var drift := (_body_at - guess) \
		+ (_body_velocity - told_velocity) * STATE_PERIOD
	if drift.length() > STRAY_PLACE:
		return true
	var twist := angle_difference(float(_told[2]) + told_turning * ahead,
		_body_heading) + (_body_turning - told_turning) * STATE_PERIOD
	return absf(twist) > STRAY_TURN


## True while the run is reporting a body: it is being simulated, so it has a
## motion worth sending. See [member _held].
func _moving() -> bool:
	return _body and not _held


## True when the far end was last told a body that is moving -- and is still
## carrying it along that motion.
func _told_moving() -> bool:
	if _told.is_empty():
		return false
	return (_told[4] as Vector2) != Vector2.ZERO or float(_told[5]) != 0.0


func _to_everyone(frame: PackedByteArray) -> void:
	for id: int in _peers.keys():
		if bool(_peers[id]["greeted"]):
			_to(id, frame)


func _greeted_count() -> int:
	var count := 0
	for id: int in _peers.keys():
		if bool(_peers[id]["greeted"]):
			count += 1
	return count


func _set_link(to: int) -> void:
	link = to
	link_changed.emit(link)


## Say something without moving the link: the host stays LISTENING after it
## turns a stale build away, because the next caller may well be fine.
func _say(headline: String, detail: String) -> void:
	trouble = headline
	because = detail
	link_changed.emit(link)


func _give_up(to: int, headline: String, detail: String) -> void:
	trouble = headline
	because = detail
	_set_link(to)


## Put the socket down but keep the node and the bound API, so a refusal can be
## read on screen and the player can try again without a new session.
func _drop_link() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	if _api != null:
		_api.multiplayer_peer = null
	_peers.clear()
	_hanging_up.clear()
	_host_id = 0
	set_process(false)


func _reset_socket() -> void:
	_drop_link()
	_body = false
	_body_velocity = Vector2.ZERO
	_body_turning = 0.0
	_held = true
	_reported = false
	_told = []
	_beat_due = 0.0
	_out_state_seq = 0
	_out_event_seq = 0
	_heartbeat_at = _now()
	_reach_at = _now()
	heard.clear()
	trouble = ""
	because = ""


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
