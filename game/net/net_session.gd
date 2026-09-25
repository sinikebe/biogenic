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
## **A host reads its own socket, and a stranger is judged at the door**
## (docs/design/net-hardening.md, part A). A guest keeps SceneMultiplayer: it
## only ever calls out, to one host. A host no longer hands it the socket,
## because it ran every command a datagram named -- a path, an RPC, a spawn, a
## relay -- in C++, for anybody, before a line of this file saw the bytes. So
## the host polls its ENet peer itself ([method _pump]) and nothing but a RAW
## frame goes further; every frame from either end then passes one gate
## ([method _admit_frame]) that checks its size, its kind and what it parses
## to, and charges the sender's budgets, which [member enforce_budgets] can
## turn to watching only. Who may
## connect at all is decided in [method _on_peer_connected], before any
## bookkeeping exists for them. None of it changes a byte on the wire: a
## protocol-4 build on either end cannot tell.
##
## **And what a guest says is checked, not only how it is said** (part B): the
## host's pond asks a referee (`referee.gd`) about every word a guest sends, and
## a rule broken lands on the same ledger through [method strike] -- enforced,
## or only watched while [member enforce_referee] is off.
##
## **A friend outside the house comes in by invite** (part C, issue #59), and
## only to the dedicated server. Beside its LAN listener on `Lan.PORT` it can
## hold a second, on `Invite.PORT`, that speaks DTLS with the server's own
## certificate ([method listen_internet]), which the invite pins. That door
## skips the LAN-only guard and nothing else, and before a caller is welcomed
## it must prove an invite's secret: HELLO -- the frozen compatibility check,
## refused with its sentence as ever -- then CHALLENGE, a fresh nonce, then
## PROOF, an HMAC over both nonces keyed with the secret. Both listeners feed one
## set of peers, one pond and one limit of two guests; each keeps its own
## waiting room and call buckets, so nothing that arrives over the internet can
## ever turn a LAN caller away. A phone host never opens it. A guest calls one
## with [method call_invite].
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Wire := preload("res://game/net/wire.gd")
const Lan := preload("res://game/net/lan.gd")
const Invite := preload("res://game/net/invite.gd")

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
## **A caller on the internet listener proved an invite** -- by its owner's
## [param label], and the invite's [param key_id] in hex. The server keeps when
## each invite last came in (`--invites`); nothing a secret is made of rides
## on it.
signal invite_proved(label: String, key_id: String)

## The live session, or null. Set in [method _ready] and cleared in
## [method _exit_tree], so it is never a reference to a freed node.
static var current: Node = null
## **Invites a server has refused, this run of the game**: a digest of each
## one's key id and secret, never the secret. [method call_invite] does not dial
## one again -- the server bars an address for a minute after a refused proof,
## and ten for a second, so a retry could only earn the longer bar and then a
## silent door (docs/design/invites-ux.md §3). A new paste is a new invite.
static var _turned_away: Dictionary = {}

## **Which listener a peer came in on** -- a dedicated host has two -- and so
## which transport every send, cut, address and throttle for it goes through.
## A guest's one socket, and a phone host's, are the LAN's.
const VIA_LAN := 0
const VIA_NET := 1
## **Where a caller on the internet listener is in its handshake**: its HELLO
## is still owed, or its PROOF is, after the CHALLENGE went out. A LAN caller
## is only ever owed a HELLO.
const STAGE_HELLO := 0
const STAGE_PROOF := 1

## How long the host waits for a guest's greeting before hanging up on it. A
## transport connection that never says hello is a port scanner, a crash, or a
## build so old it does not know it has to.
const HELLO_GRACE := 3.0
## How long a guest waits for anything at all. Deliberately shorter than ENet's
## own give-up: an unanswered address must become a sentence on screen, not a
## spinner. multiplayer.md §4.2 budgets the reply wait at ~2 s; this is double.
const REACH_TIMEOUT := 4.0
## **How long a call by invite waits, for the transport and again for the
## handshake: 8 s, where the LAN waits 4.** DTLS comes up first, and mbedTLS
## resends a lost flight after 1 s and then 2 s; ENet's CONNECT goes out before
## DTLS is up and is resent 0.5, 1.5, 3.5 and 7.5 s after the call -- so on
## loopback a call connects at the first resend, 0.5 s in. **Measured through
## the relay** (net-hardening.md C.8), twice twenty calls each: with jitter
## alone the worst was 1.2 s, with 2% loss 2.1 s, and with 5% loss 3.85 s both
## times, which is the 3.5 s resend -- four seconds would barely have held it,
## and the next resend is at 7.5. The same as `docs/design/invites-ux.md` §8
## asks for.
const INVITE_REACH_TIMEOUT := 8.0
## **How long an invite's host name may take to resolve** before the call says
## so. The lookup runs on the engine's resolver thread
## (`IP.resolve_hostname_queue_item`): `create_client` given a name resolves it
## on the calling thread, blocking the frame for as long as DNS takes --
## measured, and read in `enet_connection.cpp`.
const RESOLVE_TIMEOUT := 6.0
## **How long the second look after a fast failure may take.** A call whose
## DTLS handshake fails at once met either a certificate that is not the one
## the invite pins, or a port where nothing listens -- a connected UDP socket
## hears the ICMP refusal, and ENet fails the same way for both, measured. So
## the guest asks again without the pin ([method _diagnose]): a pond answers
## that one -- somebody else's -- and a closed port refuses it at once.
const DIAGNOSE_TIMEOUT := 3.0
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
## `v * 0.74 * dt^2 / 2`. So faster buys nothing a player can see. It does
## cost: every packet is air time on a Wi-Fi channel two phones share, and more
## packets on a shared channel is more contention, which is jitter bought for no
## picture. Slower is the other way wrong: at 10 Hz, two frames lost in a row
## leave a 300 ms hole, and `vision.gd` carries a body at most 200 ms before it
## freezes -- 20 Hz rides over two lost frames and still lands the third inside
## that reach.
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
## **Callers still to say hello, at once: two.** A third is cut on arrival. A
## real guest says hello the moment its transport connects, so a caller left
## waiting is one in the middle of saying it -- or one that never will, which
## [constant HELLO_GRACE] hangs up on. More than one guest is still refused
## with a sentence rather than by the transport, so the extra device learns
## why; see [method _slots] for how many transports a host holds at all.
const PENDING_MAX := 2
## **The most guests any host takes: two**, a dedicated host's (`game/server/`),
## each of whom sees the other as the friend. A phone takes one.
const GUESTS_MAX := 2
## Shouts waiting for the run to drain them. Capped because nothing drains while
## the player is still on the session screen.
const HEARD_MAX := 8
## **The shared pond's events waiting for the run** (shared-pond.md §2), capped
## for the same reason as [constant HEARD_MAX] and far higher, because these
## are not sensations: an arrival bursts one GENOME per body in the send set,
## sixty-eight at most, and the run drains every frame it exists. A cap reached
## is a run that is not there, and dropping the oldest is then harmless. **A
## guest's cap**, on what its host sends: a host holds each of its guests to
## [constant QUEUE_FRAMES] and [constant QUEUE_BYTES].
const POND_EVENTS_MAX := 512
## The same queue by weight: 128 KB, twelve times the largest arrival burst --
## sixty-eight GENOMEs of 155 bytes and an ARRIVE and a PERSON.
const POND_EVENTS_BYTES := 131072
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
## **ENet may not throttle a single state frame or snapshot away: deceleration
## 0**, on every peer, from the moment the transport connects (issue #61).
##
## Both kinds go out unreliable ([method _mode_for]), and ENet discards
## unreliable packets **at the sender**, before any socket, by a per-peer
## throttle of 0-32: each one adds 7 to a counter mod 32 and is freed unsent if
## the counter is above the throttle (`thirdparty/enet/protocol.c:1520-1545` in
## 4.7-stable), so at 6 only 7 frames in 32 leave. Every acknowledgement after
## the first is judged (`peer.c:62-92`): a round trip longer than the previous
## five seconds' lowest by more than twice their variance lowers the throttle
## by the deceleration, and one no longer than that lowest raises it by the
## acceleration.
##
## **Measured through a relay** holding every datagram 5-40 ms, one in twenty
## 150-250 ms longer, in order, and losing none: at the join, the arrival's burst
## of reliable GENOME events brings a burst of acknowledgements, all judged
## against a window taken from the connection's *first* round trip alone
## (`protocol.c:903-911`). In five runs of six the host's throttle went from 32
## to 0 inside a second and stayed at 0-4 for 4.4 to 5.3 s, and in one run of
## three a dedicated host's did it to both its guests at once. In one of those
## seconds the guest got 2 of 23 state frames and 1 of 66 snapshots, while the
## relay delivered every datagram it was given. With no relay at all, the
## loopback server section of `tools/net_probe.gd` sank one guest's to 0 in one
## run of three.
##
## **Deceleration 0 makes the fall subtract nothing** (`peer.c:81-84`), so the
## throttle stays at the 32 every ENet peer starts at (`peer.c:406`). The brake
## it gives up protects nothing here: the unreliable traffic is set by the game,
## about twenty state frames and twenty snapshots a second to a peer, and a
## frame ENet discards is a frame the far screen needed, not load the link was
## spared.
##
## **Interval and acceleration stay ENet's defaults** (`enet.h:230, 232`),
## because with no fall they have nothing to act on. The interval only says how
## often that window is taken again, and the acceleration only climbs back from
## a fall. There is none to climb from. Each end pins its own peer at
## `peer_connected`, and neither has judged an acknowledgement by then: ENet
## judges none until one has been received (`protocol.c:872`), the host's
## connect event is raised by the first it receives, and a guest's by
## VERIFY_CONNECT, which is not one. The only other thing that lowers a throttle
## is the bandwidth limiter (`host.c:400-407, 436-439`), and it never engages:
## no host here is created with a bandwidth. **Keep it that way**, and mind that
## 4.7's `create_server` passes a channel count on as its *incoming bandwidth*
## (`modules/enet/enet_multiplayer_peer.cpp:67`): given one, the host would
## advertise a few bytes a second and every guest's limiter would cap its
## throttle toward the host, pinned or not. Left as they were, the one number
## the far end is told that it did not already have is this one.
const THROTTLE_INTERVAL := 5000
const THROTTLE_ACCELERATION := 2
const THROTTLE_DECELERATION := 0

# --- The door and the budgets (net-hardening.md A.2-A.6; #56, #58) -----------
## SceneMultiplayer's `NETWORK_COMMAND_RAW`, with no flag bits: the byte a
## guest's `send_bytes` puts in front of every frame (`scene_multiplayer.cpp`
## in 4.7-stable). A host reads its own socket and takes it off. Anything else
## in that byte is a command this game never sends.
const RAW := 3
## **New connections from one address: eight at once, then one every three
## seconds.** A dropped guest rejoining, a friend retrying after "already two",
## a phone that backed out of the join screen and came back. The plan said four
## at once; `tools/net_probe.gd`'s server section calls six times from one
## loopback address in about six seconds, and four would have made it pass or
## fail on the runner's speed.
const CALLS_BURST := 8.0
const CALLS_RATE := 1.0 / 3.0
## New connections from every address together: ten a second. What a storm
## from many addresses can cost.
const CALLS_ALL_BURST := 10.0
const CALLS_ALL_RATE := 10.0
## Transports one address may hold at once: two friends behind one NAT, and a
## retry.
const LIVE_PER_ADDRESS := 3
## **Barred after an abuse cut**: a minute, and ten for a second one inside ten
## minutes. Silence, an old protocol and "already two" are not abuse.
const BAR_FIRST := 60.0
const BAR_AGAIN := 600.0
## **The addresses a host remembers: at most this many**, so the limiter's own
## memory is bounded too. A full book forgets a caller it has not heard from
## for [constant BOOK_IDLE] first, then the one heard from longest ago -- and
## only when it is full: until then an idle caller's entry stays.
const BOOK_MAX := 1024
const BOOK_IDLE := 600.0
## **What a host takes from each guest, a second and at once** (A.4). The
## worst an honest guest sends is 83 state frames a second -- a body knocked
## every frame, at about 80 frames a second, never closer than
## [constant EARLY_GAP] -- about one event a second in bursts of two to four,
## and about 3.5 KB a second. Each limit is at least 40% over that, and the
## bursts cover what a spike on the link delivers at once: the relay runs in
## net-hardening.md A.7 measured both. **Enforced while
## [member enforce_budgets] is on, which it ships as** -- and so are the flood
## rule and the guest's own limits on its host below.
const FRAMES_RATE := 120.0
const FRAMES_BURST := 240.0
const EVENTS_RATE := 5.0
const EVENTS_BURST := 20.0
const BYTES_RATE := 16384.0
const BYTES_BURST := 32768.0
## **What a guest takes from its host: sanity, not policy.** A guest never
## cuts its host; these only bound what a broken one can make it do. Over a
## POND with every one of 83 state frames a second, and over the seventy
## events that answer an ENTER.
const HOST_FRAMES_RATE := 600.0
const HOST_FRAMES_BURST := 1200.0
const HOST_EVENTS_RATE := 200.0
const HOST_EVENTS_BURST := 400.0
const HOST_BYTES_RATE := 262144.0
const HOST_BYTES_BURST := 524288.0
## **One guest's events waiting for the host's run: 64 frames and 16 KB**, the
## oldest dropped past either, as the old cap did. The run drains them every
## frame, so a full queue is a run that is not there. Kept per guest, so one
## guest of a dedicated host's two cannot push out the other's.
const QUEUE_FRAMES := 64
const QUEUE_BYTES := 16384
## **The ledger** (A.4): points for each offence, decaying at one a second;
## ten is a cut. Two malformed frames leave a guest connected and three inside
## two seconds do not -- and a guest on this protocol never sends one, because
## the writers never write what the readers refuse (wire.gd).
const STRIKE_CUT := 10.0
const STRIKE_DECAY := 1.0
const STRIKE_MALFORMED := 4.0
const STRIKE_FLOOD := 6.0
const STRIKE_BYTES := 6.0
const STRIKE_EVENTS := 2.0
## **A flood**: every 120 frames dropped over the frame budget inside one
## second is a flood strike -- so a burst of them cuts at once, and a steady
## overrun of 130 a second in about two.
const FLOOD_DROPS := 120
const FLOOD_WINDOW := 1.0
## **A host stall is not a flood.** A phone host that stalls gets the whole
## stall's frames at once -- software GL at 2400x1080 has taken over 100 ms a
## frame -- so a frame that comes more than this after the one before hands
## every budget the gap's whole refill, uncapped by the burst...
const STALL_GAP := 0.25
## ...counted up to this long: a peer silent for longer is past ENet's own
## timeout, and gone.
const STALL_CREDIT := 10.0
## **Telemetry, rate-limited**: one line per kind and address this often, and
## the next says how many like it were held back -- with at most this many
## kinds-and-addresses remembered: past it, the one whose hold ends soonest is
## forgotten first.
const NOTE_EVERY := 10.0
const NOTES_MAX := 256
## **Saturation**: a line when a second brings more than this to the socket.
## Two real guests send about 7 KB and 170 datagrams a second.
const SATURATED_BYTES := 65536.0
const SATURATED_DATAGRAMS := 2000.0

var link := Link.OFF
## The heading a screen puts on the current state of the link, when that state
## is one a player has to be told about. Empty when there is nothing to say.
var trouble := ""
## The sentence under it. Says what to *do*, wherever there is anything to do.
var because := ""
## **Which of `Invite.SAYS` [member trouble] and [member because] are**, on a
## call by invite -- `&"invite_refused"`, `&"no_answer"` and the rest -- so a
## screen can pick what to offer next by it (docs/design/invites-ux.md §6.3).
## `&""` on the LAN, and whenever there is nothing to say.
var trouble_key: StringName = &""
## **Why the host last refused this guest**, a `Wire.REFUSE_*`, or -1: so a run
## can tell a cut (`REFUSE_BROKEN`) from a host that simply went.
var refused_for := -1
## Set once, at host()/join(), and never derived from a peer id.
var hosting := false
## **How many guests this host greets** before it says "already two": one for
## a phone's pond, [constant GUESTS_MAX] for a dedicated host. Set by
## [method host]. A host of more than one keeps every guest's events apart --
## see [member inbox] -- and speaks to each through the `*_to` sends.
var guests_max := 1
## The address this session is on (hosting) or reaching for (guesting). Shown on
## screen as a receipt, never typed into.
var address := ""

## What the last shout heard on the wire was, as `[at, radius, reach]` each.
## Drained by the run, exactly the way `food.gd`'s own `pings` are.
var heard: Array = []
## **Every other event the far end sent**, as raw frames in the order they
## arrived: the shared pond's ENTER, ARRIVE, PERSON, GENOME, CONTACT, DIED and
## SISTER. Decoded by `pond.gd`, which is the only thing that knows what they
## mean; this file only guarantees the order and that each arrives once.
var pond_events: Array = []
## **A host of more than one guest hears each of them apart**: every event --
## shouts and the pond's alike -- as `[peer id, raw frame]`, in the order they
## arrived, instead of in [member heard] and [member pond_events], which cannot
## say who spoke. Filled by the same one intake as those two ([method
## _take_event]), after the same duplicate and order checks. Drained by
## [method drain_inbox]; never touched by a phone's session.
var inbox: Array = []

## **A test seam.** 0 means "speak [constant Wire.PROTOCOL]".
## tools/net_probe.gd sets it to something else to prove the refusal path, which
## is the single highest-value assertion CI can make about this file.
var protocol_override := 0
## **The other test seam: loopback counts as local on the LAN listener.** Every
## caller in `tools/net_probe.gd` comes from loopback, so its check that the
## internet listener skips the LAN-only guard -- and the LAN listener does not
## -- turns this off, and a loopback caller is then a stranger to the LAN door.
var loopback_is_local := true

var _api: SceneMultiplayer = null
## A guest's socket, or a host's LAN listener.
var _peer: ENetMultiplayerPeer = null
## **A dedicated host's internet listener**, or null: DTLS on
## [constant Invite.PORT], opened by [method listen_internet] while there are
## invites and closed when none remain.
var _net_peer: ENetMultiplayerPeer = null
## When a closing internet listener is put down: its refusals get
## [constant REFUSE_LINGER] to leave first. 0 while none is closing.
var _net_closing_at := 0.0
## Peer id -> bookkeeping. Every send addresses a key of this dictionary. **One
## set for both listeners**: the pond, the two-guest limit and the updater's
## "nobody here" all count them together.
var _peers: Dictionary = {}
## **Peer id -> the listener it came in on** ([constant VIA_LAN] or
## [constant VIA_NET]), for every transport a host admitted, until that
## transport says it has gone. ENet peer ids are random per listener, so two
## listeners can hand out one id: the second is refused, never merged
## ([method _on_peer_connected]), and a listener's news about an id it does not
## hold here is not news about this peer.
var _via: Dictionary = {}
## **The invites this host takes on its internet listener**: key id in hex ->
## `[label, secret]`, from the server's book ([method set_invites]).
var _invites: Dictionary = {}
## What a PROOF naming no key id this host has is checked against: an HMAC is
## computed and compared either way, so an unknown key id and a wrong secret
## cost the same and answer the same.
var _decoy_secret := PackedByteArray()
var _crypto := Crypto.new()
## **A guest's call by invite**: what [method Invite.parse] made of it, or
## empty for a LAN call. Its secret is only ever handed to [method
## Invite.proof_mac].
var _invite: Dictionary = {}
## The guest has answered its host's CHALLENGE; a second is dropped.
var _proved := false
## The invite's host name, being resolved on the engine's resolver thread: its
## query id, and when it was asked. -1 for none.
var _resolving := -1
var _resolve_at := 0.0
## The address the call went to, once resolved: what [method _diagnose] asks.
var _dialed := ""
## **The second look after a fast failure** ([method _diagnose]): a DTLS
## handshake with no pin, and when it began.
var _diag: PacketPeerDTLS = null
var _diag_udp: PacketPeerUDP = null
var _diag_at := 0.0
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
## **The shared pond's two bits on every state frame** (shared-pond.md §2):
## this run is in the pond -- the host's is open, or the guest is swimming in
## it -- and this cell is alive but out of the water, dividing. Written by the
## run through [method set_pond]; a change goes at once, like any other thing
## the far end could not have guessed.
var _in_pond := false
var _out_of_water := false
## The POND snapshots this end has sent. Their own sequence: a snapshot is
## drained to the newest by it, independently of the state frames.
var _out_pond_seq := 0

## **The budgets are enforced** (A.4) -- the owner's call, taken before the
## two-phone playtest: their numbers were measured through a relay, with every
## limit at least 40% over the worst honest traffic seen there. The frame, byte
## and event budgets and the flood rule are the only limits timing alone can
## trip: everything else the gate refuses is a frame no honest build writes, or
## a caller the door turns away, and all of that is enforced whatever this says.
## **Off is watch mode**, for diagnosing a false positive in the field: an
## overrun is then counted (`would_*` in [member gate_counts]) and logged as
## what it would have done -- "would drop", "would cut" -- and the frame is
## taken, with no points for it. The probe's budget tests set it per session.
var enforce_budgets := true
## **The referee's fouls are enforced** (part B), the same shape as
## [member enforce_budgets] and on by default for the same reason: the owner
## chose to enforce A. A foul is what the host's pond calls when a guest's word
## breaks a rule of the water -- a body bigger than it was fed, a place further
## than it could swim -- and each goes on this ledger through [method strike].
## **Off is watch mode**: a foul is counted (`referee_would_*` in
## [member gate_counts]) and logged as what it would have done, and costs no
## points. Either way the referee's verdicts stand -- a clamp or a refusal is
## the host deciding about its own water, and never cuts anybody.
var enforce_referee := true
## **What the door and the gate have done** since this end last hosted or
## joined -- callers refused, frames dropped, points struck, peers cut, and in
## watch mode what the budgets would have done -- for tools and for the log.
## Kept after [method close], so a tool can read a session's last word. Reset
## by [method host] and [method join].
var gate_counts: Dictionary = {}
## **The host's address book** (A.5): one entry per caller, by
## [method Lan.source_key] -- its connection bucket and whether it is barred.
## Bounded by [constant BOOK_MAX]; cleared with the socket. **The LAN
## listener's**: the internet listener keeps one of its own, [member
## _net_book], and its own [member _net_calls_all], so no storm of calls from
## outside can spend what a caller in the house needs.
var _book: Dictionary = {}
## Peer id -> caller key, for every transport the host admitted, until ENet
## says it has gone: what [constant LIVE_PER_ADDRESS] counts, per listener.
var _addresses: Dictionary = {}
## New connections from every address together, on the LAN listener.
var _calls_all: Bucket = null
## The internet listener's own address book and all-callers bucket.
var _net_book: Dictionary = {}
var _net_calls_all: Bucket = null
## `kind|key` -> `[next line allowed, lines held back]`. See [method _note].
var _notes: Dictionary = {}
## When this node's last frame began: the gap a stall is measured by.
var _frame_at := 0.0
## When the socket's arrivals were last counted, for the saturation line.
var _saturation_from := 0.0
## [member pond_events] by weight, and a dedicated host's [member inbox] by
## guest: peer id -> `[frames, bytes]`.
var _pond_bytes := 0
var _inbox_load: Dictionary = {}


## **A token bucket, on wall time** (A.4). [member tokens] refill at
## [member rate] a second up to [member burst]; a take that finds too few takes
## nothing and says no.
class Bucket extends RefCounted:
	var rate := 0.0
	var burst := 0.0
	var tokens := 0.0
	var at := 0.0
	## The fewest tokens a take has ever left: how deep traffic drew it.
	var low := 0.0

	func _init(per_second: float, most: float, now: float) -> void:
		rate = per_second
		burst = most
		tokens = most
		low = most
		at = now

	func take(cost: float, now: float) -> bool:
		# An overfull bucket -- a stall's refill, see [method top_up] -- is
		# spent down, not trimmed back.
		if tokens < burst:
			tokens = minf(burst, tokens + rate * maxf(now - at, 0.0))
		at = now
		if tokens < cost:
			return false
		tokens -= cost
		low = minf(low, tokens)
		return true

	## A stall of [param seconds]: the whole gap's refill at once, however
	## far past the burst that is.
	func top_up(seconds: float) -> void:
		tokens = maxf(tokens, rate * seconds)

	## What a take could spend now, without taking.
	func level(now: float) -> float:
		if tokens >= burst:
			return tokens
		return minf(burst, tokens + rate * maxf(now - at, 0.0))


## **One peer's budgets and its ledger** (A.4). A host holds each guest to
## the strict numbers and strikes it; a guest holds its host to the lenient
## ones, and never strikes anything.
class Guard extends RefCounted:
	var frames: Bucket = null
	var events: Bucket = null
	var bytes: Bucket = null
	var points := 0.0
	var points_at := 0.0
	## The flood window: when it began, frames dropped in it, strikes given.
	var flood_at := -INF
	var flood_drops := 0
	var flood_struck := 0
	## The frame a stall's refill was last handed out in.
	var topped := -1
	## What was taken and what was dropped, for tools and the log.
	var taken := 0
	var taken_bytes := 0
	var taken_events := 0
	var dropped := 0
	## **Watch mode's ledger** ([member NetSession.enforce_budgets] off): the
	## points the budgets would have struck, decaying like the real ones, and
	## what they would have done. Never read by anything that decides.
	var would_points := 0.0
	var would_points_at := 0.0
	var would_dropped := 0
	var would_cuts := 0
	## **The referee's fouls on this peer** (part B), enforced or watched: what
	## its farewell line says, beside the budgets' overruns.
	var fouls := 0

	func _init(strict: bool, now: float) -> void:
		frames = Bucket.new(FRAMES_RATE if strict else HOST_FRAMES_RATE,
			FRAMES_BURST if strict else HOST_FRAMES_BURST, now)
		events = Bucket.new(EVENTS_RATE if strict else HOST_EVENTS_RATE,
			EVENTS_BURST if strict else HOST_EVENTS_BURST, now)
		bytes = Bucket.new(BYTES_RATE if strict else HOST_BYTES_RATE,
			BYTES_BURST if strict else HOST_BYTES_BURST, now)
		points_at = now
		would_points_at = now

	## The points on the ledger now, after their decay.
	func points_now(now: float) -> float:
		return maxf(0.0, points - STRIKE_DECAY * maxf(now - points_at, 0.0))

	## Adds [param weight] and returns the total.
	func strike(weight: float, now: float) -> float:
		points = points_now(now) + weight
		points_at = now
		return points

	## Watch mode's [method strike]: returns what the whole ledger would hold,
	## the real points and the budgets' together.
	func would_strike(weight: float, now: float) -> float:
		would_points = maxf(0.0, would_points
			- STRIKE_DECAY * maxf(now - would_points_at, 0.0)) + weight
		would_points_at = now
		return points_now(now) + would_points


func _ready() -> void:
	# Beats and timeouts have to keep running while the game is paused, and they
	# can: SceneTree polls every registered MultiplayerAPI regardless of
	# `paused`, measured in this container by sending a packet across a paused
	# tree and watching it land. A host reads its own socket at that same
	# moment ([method _on_tree_frame]).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	current = self
	_zero_counts()
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


## **Back in a tree -- moved, not closed.** It is the session the game reaches
## again, if nothing took its place while it was out, and a host reads its
## socket again: one whose pump was left behind would hear nothing and say
## nothing.
func _enter_tree() -> void:
	if current == null:
		current = self
	if hosting and _peer != null \
			and not get_tree().process_frame.is_connected(_on_tree_frame):
		get_tree().process_frame.connect(_on_tree_frame)


func _exit_tree() -> void:
	if current == self:
		current = null
	if get_tree().process_frame.is_connected(_on_tree_frame):
		get_tree().process_frame.disconnect(_on_tree_frame)


func _process(_delta: float) -> void:
	var now := _now()
	if not hosting:
		# A guest's frames came in with SceneMultiplayer's poll, before this, so
		# the next frame's stall gap is measured from here: see [method _top_up].
		_frame_at = now
	if link == Link.REACHING:
		# A call by invite may still be resolving its address, or taking its
		# second look after a fast failure; either has the frame to itself.
		if not _invite.is_empty() and _reaching_by_invite(now):
			return
		if _invite.is_empty() and now - _reach_at >= REACH_TIMEOUT:
			_give_up(Link.FAILED, "no answer",
				"both of you have to be on the same wi-fi -- and on some"
				+ " networks that is still not enough to reach across.")
			return
		if not _invite.is_empty() and now - _reach_at >= INVITE_REACH_TIMEOUT:
			_invite_gives_up(Link.FAILED, &"no_answer")
			return
	if hosting:
		# A transport connection that never greets is hung up on, with a reason
		# -- and on the internet listener that greeting is the whole handshake,
		# its proof included.
		for id: int in _peers.keys():
			var peer: Dictionary = _peers[id]
			if bool(peer["greeted"]):
				continue
			if now - float(peer["since"]) >= HELLO_GRACE:
				_refuse(id, Wire.REFUSE_SILENT)
		if _net_closing_at > 0.0 and now >= _net_closing_at:
			_finish_closing_internet()
	for id: int in _hanging_up.keys():
		if now >= float(_hanging_up[id]):
			_hanging_up.erase(id)
			_drop_now(id)
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

## **Whether a host can take calls at [param address]**, for [param guests]
## guests. It needs an address. A phone host also needs one a code can carry --
## a last number from 1 to 254 -- because the code is the only way a phone is
## found. A dedicated host listens at any address, for its log to say what
## the matter is ([code]game/server/server.gd[/code]): an address that ends in
## .0 or .255 is a real device on a network wider than a /24, and a server that
## would not listen there only says "no wi-fi here" forever.
static func hostable(at: String, guests: int) -> bool:
	if at.is_empty():
		return false
	return guests > 1 or Lan.octet_of(at) >= 0


## Take the calls. Returns false, with [member trouble] set, if this device has
## no address to be found at or the port is already taken. [param guests] is
## how many to greet: one, as every phone does, or a dedicated host's two.
func host(guests: int = 1) -> bool:
	if _api == null:
		return false
	_reset_socket()
	_zero_counts()
	hosting = true
	guests_max = clampi(guests, 1, GUESTS_MAX)
	address = Lan.local_address()
	if not hostable(address, guests_max):
		_give_up(Link.FAILED, "no wi-fi here",
			"this device is not on a network two cells could share.")
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(Lan.PORT, _slots())
	if err != OK:
		_give_up(Link.FAILED, "could not listen",
			"something else on this device is already using the water.")
		return false
	# **Read here, and not by SceneMultiplayer**: `_api` is never handed this
	# peer, or SceneTree would poll it at the top of every frame and run every
	# command it carries before the gate saw a byte. See [method _pump].
	_peer = peer
	peer.peer_connected.connect(_on_peer_connected.bind(VIA_LAN))
	peer.peer_disconnected.connect(_on_peer_disconnected.bind(VIA_LAN))
	if is_inside_tree() and not get_tree().process_frame.is_connected(_on_tree_frame):
		get_tree().process_frame.connect(_on_tree_frame)
	set_process(true)
	_set_link(Link.LISTENING)
	return true


## **Open the internet listener** (net-hardening.md C): DTLS on
## [constant Invite.PORT], answering with [param certificate] and its
## [param key], beside the LAN listener [method host] opened. A dedicated
## host's alone -- one that greets more than one guest; a phone host never
## opens it. Callers there must prove an invite of [method set_invites]'s.
## True if it is listening; false, with nothing opened, if the port is taken or
## this is not a dedicated host.
##
## `dtls_server_setup` goes on the fresh `ENetConnection` straight after
## `create_server` and before anything polls it: it swaps ENet's socket for a
## DTLS one, which only a socket nothing has read from allows
## (`enet_godot.cpp`). mbedTLS answers a first ClientHello with a stateless
## cookie, so a spoofed address never holds a slot.
func listen_internet(key: CryptoKey, certificate: X509Certificate) -> bool:
	if not hosting or guests_max < 2 or _peer == null or key == null \
			or certificate == null:
		return false
	if _net_peer != null:
		if _net_closing_at <= 0.0:
			return true
		_finish_closing_internet()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(Invite.PORT, _slots()) != OK:
		return false
	if peer.host.dtls_server_setup(TLSOptions.server(key, certificate)) != OK:
		peer.close()
		return false
	_net_peer = peer
	_net_closing_at = 0.0
	_net_book.clear()
	_net_calls_all = Bucket.new(CALLS_ALL_RATE, CALLS_ALL_BURST, _now())
	peer.peer_connected.connect(_on_peer_connected.bind(VIA_NET))
	peer.peer_disconnected.connect(_on_peer_disconnected.bind(VIA_NET))
	return true


## **The invites this host takes**: key id in hex -> `[label, secret]`, the
## server's book as it stands. A guest on the internet listener whose invite is
## no longer in it -- revoked, or replaced, which gives the label a new key id
## -- is cut at once, told `REFUSE_INVITE`, and not barred: the owner decided,
## not the guest. **None left closes the internet listener**: nothing listens
## for the internet without an invite to answer.
func set_invites(table: Dictionary) -> void:
	_invites = table.duplicate()
	for id: int in _peers.keys():
		var peer: Dictionary = _peers.get(id, {})
		if peer.is_empty() or int(peer.get("via", VIA_LAN)) != VIA_NET \
				or not bool(peer["greeted"]):
			continue
		var entry: Array = _invites.get(str(peer.get("key_id", "")), [])
		if entry.is_empty() or entry[1] != peer.get("secret"):
			gate_counts["invite_cuts"] += 1
			_cut(id, "its invite (%s) was revoked or replaced" % str(peer.get("label", "")),
				true, false, Wire.REFUSE_INVITE)
	if _invites.is_empty():
		close_internet()


## **Put the internet listener down.** Every caller on it goes: a guest is
## told `REFUSE_INVITE`, since its invite no longer opens anything, and a
## caller still in its handshake is cut. New calls are refused from now on,
## and the socket itself closes once the refusals have had
## [constant REFUSE_LINGER] to leave -- or at once, with [param now].
func close_internet(now: bool = false) -> void:
	if _net_peer == null:
		return
	for id: int in _peers.keys():
		var peer: Dictionary = _peers.get(id, {})
		if peer.is_empty() or int(peer.get("via", VIA_LAN)) != VIA_NET:
			continue
		if bool(peer["greeted"]):
			gate_counts["invite_cuts"] += 1
			_cut(id, "the internet listener closed", true, false, Wire.REFUSE_INVITE)
		else:
			_cut(id, "the internet listener closed", false, false)
	_net_peer.refuse_new_connections = true
	if now:
		_finish_closing_internet()
	elif _net_closing_at <= 0.0:
		_net_closing_at = _now() + REFUSE_LINGER + 0.1


## True while the internet listener takes calls.
func internet_listening() -> bool:
	return _net_peer != null and _net_closing_at <= 0.0


## **Which listener peer [param id] came in on**, [constant VIA_LAN] or
## [constant VIA_NET]; -1 for an id this host does not hold.
func via_of(id: int) -> int:
	return int(_via.get(id, -1))


## **The label of the invite guest [param id] proved**, or "" for a LAN guest
## and anybody not greeted.
func label_of(id: int) -> String:
	return str((_peers.get(id, {}) as Dictionary).get("label", ""))


## **The ENet peer for [param id] on whichever transport holds it**, or null.
## For tools: asking the wrong listener for an id is an engine error line.
func enet_peer_of(id: int) -> ENetPacketPeer:
	var enet := _transport_of(id) if hosting else _peer
	if enet == null or enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return null
	if not hosting:
		return enet.get_peer(id) if id == _host_id and id != 0 else null
	return enet.get_peer(id)


func _finish_closing_internet() -> void:
	_net_closing_at = 0.0
	if _net_peer == null:
		return
	var enet := _net_peer
	_net_peer = null
	for id: int in _via.keys():
		if int(_via[id]) != VIA_NET:
			continue
		_via.erase(id)
		_addresses.erase(id)
		_hanging_up.erase(id)
		if _peers.has(id):
			_peers.erase(id)
	enet.close()
	_net_book.clear()


## **How many transports a host holds at once: a guest's, a caller's still
## saying hello, and a half-dead predecessor for each guest** -- ENet keeps a
## vanished peer's slot until it times out, and a retry has to get in past it.
## Four for a phone, six for the dedicated server's two guests. No more,
## because ENet will buffer up to 32 MiB in each for a peer that sends it
## fragments (multiplayer.md §3, point 6), and the count is the one lever
## GDScript has on that.
func _slots() -> int:
	return 2 * guests_max + PENDING_MAX


## Reach for a host. [param at] is a dotted IPv4 the tap code produced; this
## function never sees a code and never sees a digit.
func join(at: String) -> bool:
	if _api == null:
		return false
	_reset_socket()
	_zero_counts()
	hosting = false
	guests_max = 1
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


## **Call a dedicated server outside the house, by invite** (net-hardening.md
## C). [param invite] is what [method Invite.parse] -- or [method Invite.kept]
## -- returned. It ends in the same [enum Link] states a LAN call does, with
## [member trouble] and [member because] saying why when it is not TOGETHER;
## every one of those sentences is in [constant Invite.SAYS].
##
## - **REACHING** while the invite's address resolves (on the engine's resolver
##   thread, never this one), while DTLS and ENet come up -- pinned to the
##   invite's certificate and its name -- and while the handshake runs: HELLO,
##   then the server's CHALLENGE, answered with a PROOF.
## - **TOGETHER** once welcomed, exactly as on the LAN from there on.
## - **FAILED**: `no_invite` (nothing that reads), `no_such_place` (the name
##   did not resolve), `could_not_call` (no socket), `no_answer` (nothing within
##   [constant INVITE_REACH_TIMEOUT]), `not_this_pond` (another pond's
##   certificate answered, or the right one under another name), `not_running`
##   (the address refused the call: nothing listens on that port).
## - **REFUSED**: `invite_refused` (REFUSE_INVITE: the invite was revoked or
##   replaced, or never proved -- and from then on this invite is not dialled
##   again this run: see [member _turned_away]), `game_older` or
##   `server_older` (the compatibility check comes before the invite, so an
##   old build is told to update rather than to ask again), `already_two`,
##   `cut_off`, and `hung_up` for any other refusal or a hang-up.
##
## [member trouble_key] names the one it ended in. False when it failed at
## once, with [member trouble] set; true while it is on its way.
func call_invite(invite: Dictionary) -> bool:
	if _api == null:
		return false
	_reset_socket()
	_zero_counts()
	hosting = false
	guests_max = 1
	if int(invite.get("read", -1)) != Invite.Read.OK or invite.get("certificate") == null:
		address = ""
		_invite_gives_up(Link.FAILED, &"no_invite")
		return false
	_invite = invite
	address = str(invite["address"])
	if _turned_away.has(_mark_of(invite)):
		refused_for = Wire.REFUSE_INVITE
		_invite_gives_up(Link.REFUSED, &"invite_refused")
		return false
	if not _online() and not Lan.is_loopback(address):
		# No address of its own but loopback: an instant sentence, not 8 s.
		_invite_gives_up(Link.FAILED, &"could_not_call")
		return false
	set_process(true)
	_reach_at = _now()
	_set_link(Link.REACHING)
	if address.is_valid_ip_address():
		return _dial(address)
	# **Looked up fresh on every call**: the resolver keeps what it found for
	# the life of the process, and an owner's home address that changed while
	# the game was open would stay wrong until a restart.
	IP.clear_cache(address)
	_resolving = IP.resolve_hostname_queue_item(address, IP.TYPE_ANY)
	if _resolving == IP.RESOLVER_INVALID_ID:
		_resolving = -1
		_invite_gives_up(Link.FAILED, &"no_such_place")
		return false
	_resolve_at = _now()
	return true


## **The call itself, to [param ip]**: ENet's client with DTLS set up on its
## fresh socket before the first poll, pinned to the invite's certificate and
## checked against [constant Invite.NAME].
func _dial(ip: String) -> bool:
	_dialed = ip
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, int(_invite["port"])) != OK:
		_invite_gives_up(Link.FAILED, &"could_not_call")
		return false
	var pinned: X509Certificate = _invite["certificate"]
	if peer.host.dtls_client_setup(Invite.NAME, TLSOptions.client(pinned, Invite.NAME)) != OK:
		peer.close()
		_invite_gives_up(Link.FAILED, &"could_not_call")
		return false
	_peer = peer
	_api.multiplayer_peer = peer
	_reach_at = _now()
	return true


## **A call by invite that is not yet a transport**: its name resolving, or its
## second look after a fast failure. True when it had this frame.
func _reaching_by_invite(now: float) -> bool:
	if _resolving >= 0:
		var status := IP.get_resolve_item_status(_resolving)
		if status == IP.RESOLVER_STATUS_WAITING:
			if now - _resolve_at >= RESOLVE_TIMEOUT:
				IP.erase_resolve_item(_resolving)
				_resolving = -1
				_invite_gives_up(Link.FAILED, &"no_such_place")
			return true
		var ip := IP.get_resolve_item_address(_resolving) \
			if status == IP.RESOLVER_STATUS_DONE else ""
		IP.erase_resolve_item(_resolving)
		_resolving = -1
		if ip.is_empty():
			_invite_gives_up(Link.FAILED, &"no_such_place")
		else:
			_dial(ip)
		return true
	if _diag == null:
		return false
	_diag.poll()
	match _diag.get_status():
		PacketPeerDTLS.STATUS_HANDSHAKING:
			if now - _diag_at >= DIAGNOSE_TIMEOUT:
				_end_diagnosis()
				_invite_gives_up(Link.FAILED, &"no_answer")
		PacketPeerDTLS.STATUS_CONNECTED:
			# A pond answered without the pin: not the one this invite is for.
			_end_diagnosis()
			_invite_gives_up(Link.FAILED, &"not_this_pond")
		_:
			_end_diagnosis()
			_invite_gives_up(Link.FAILED, &"not_running")
	return true


## **The second look** (see [constant DIAGNOSE_TIMEOUT]): a DTLS handshake to
## the same address with no pin and no name, which any pond completes. It
## costs a server one handshake, on a call that has already failed, and says
## goodbye at once when it connects.
func _diagnose() -> void:
	_diag_udp = PacketPeerUDP.new()
	_diag = PacketPeerDTLS.new()
	_diag_at = _now()
	if _dialed.is_empty() or _diag_udp.connect_to_host(_dialed, int(_invite["port"])) != OK:
		# **This device could not even aim a socket there** -- an IPv6 invite on
		# a network with no IPv6, measured: the call failed for the same reason,
		# at once, and nothing was asked of any server.
		_end_diagnosis()
		_invite_gives_up(Link.FAILED, &"could_not_call")
		return
	if _diag.connect_to_peer(_diag_udp, Invite.NAME, TLSOptions.client_unsafe()) != OK:
		# Refused before a packet came back: nothing is listening there.
		_end_diagnosis()
		_invite_gives_up(Link.FAILED, &"not_running")


func _end_diagnosis() -> void:
	if _diag != null:
		_diag.disconnect_from_peer()
	if _diag_udp != null:
		_diag_udp.close()
	_diag = null
	_diag_udp = null


## [method _give_up] with the invite call's own sentence for [param key], and
## the key itself in [member trouble_key] before anybody is told.
func _invite_gives_up(to: int, key: StringName) -> void:
	var said := Invite.says(key)
	trouble_key = key
	trouble = str(said[0])
	because = str(said[1])
	_set_link(to)


## **Whether this session's call is by invite** -- for a screen deciding which
## page a REACHING link is. False on the LAN, and on a host.
func by_invite() -> bool:
	return not _invite.is_empty()


## **Whether [param invite] was turned away by its server this run**, so
## [method call_invite] will not dial it again. Read-only: for a screen that
## says so before anybody presses call (docs/design/invites-ux.md §3).
static func turned_away(invite: Dictionary) -> bool:
	return not invite.is_empty() and _turned_away.has(_mark_of(invite))


## **Forget which invites were refused this run.** For tools; a player's way
## out of a refused invite is a new one.
static func forget_refusals() -> void:
	_turned_away.clear()


## A digest of an invite's key id and secret: what [member _turned_away] keeps.
static func _mark_of(invite: Dictionary) -> String:
	var bytes := PackedByteArray()
	bytes.append_array(invite.get("key_id", PackedByteArray()))
	bytes.append_array(invite.get("secret", PackedByteArray()))
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


## **Whether this device has an address to call from** -- any but loopback
## and link-local, IPv4 or IPv6. A phone in flight mode has none.
static func _online() -> bool:
	for each: String in IP.get_local_addresses():
		var lower := each.to_lower()
		if Lan.is_loopback(each) or lower.begins_with("169.254.") \
				or lower.begins_with("fe80:"):
			continue
		return true
	return false


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


## **Where this run stands in the shared pond**, for the far end: [param
## in_pond] is the host's pond open, or the guest swimming in it; [param out]
## is this cell alive but out of the water. Kept, and written into every state
## frame from here on; a change is told at once, because a friend who has just
## left the water must be gone from the far end's senses now and not at the
## next beat. shared-pond.md §2.
func set_pond(in_pond: bool, out: bool) -> void:
	if in_pond == _in_pond and out == _out_of_water:
		return
	_in_pond = in_pond
	_out_of_water = out
	if link == Link.TOGETHER:
		_beat(_now())


## **A shared-pond event, sent now**: reliable and in order, on the same
## sequence as the shout, because the far end applies every event once and in
## the order it was said. [param type] is one of wire.gd's `EVENT_*` and
## [param payload] the matching `*_payload`. Silently nothing with nobody on the
## wire, like [method shout].
func send_event(type: int, payload: PackedByteArray) -> void:
	if link != Link.TOGETHER:
		return
	_out_event_seq += 1
	_to_everyone(Wire.event(_out_event_seq, type, payload))


## **One snapshot of the host's water, sent now**, unreliable (see
## [method _mode_for]) and on its own sequence. Returns the size it went out
## at, 0 when nothing went, so the size budget can be measured rather than
## argued. shared-pond.md §2.
func send_pond(your_wound: float, bodies: Array) -> int:
	if link != Link.TOGETHER:
		return 0
	_out_pond_seq += 1
	var frame := Wire.pond(_out_pond_seq, your_wound, bodies)
	_to_everyone(frame)
	return frame.size()


## Every shared-pond event heard since the last drain, as raw frames, oldest
## first. Empties the queue.
func drain_pond_events() -> Array:
	_pond_bytes = 0
	if pond_events.is_empty():
		return []
	var out := pond_events
	pond_events = []
	return out


## A host of more than one guest: every event heard since the last drain, as
## `[peer id, raw frame]`, oldest first. Empties [member inbox].
func drain_inbox() -> Array:
	_inbox_load.clear()
	if inbox.is_empty():
		return []
	var out := inbox
	inbox = []
	return out


# ---------------------------------------------------------------------------
# **One guest of several** (a dedicated host). Everything above that says "the
# far end" means the one greeted peer a phone has; these say which.
# ---------------------------------------------------------------------------

## Every greeted guest's id, in the order they arrived.
func guests() -> Array:
	var out: Array = []
	for id: int in _peers.keys():
		if bool(_peers[id]["greeted"]):
			out.append(id)
	return out


## [method peer_flags], for guest [param id]: 0 for nobody greeted by that id.
func flags_of(id: int) -> int:
	var peer: Dictionary = _peers.get(id, {})
	return int(peer["flags"]) if bool(peer.get("greeted", false)) else 0


## [method peer_track], for guest [param id]. Read-only, as that one is.
func track_of(id: int) -> Array:
	var peer: Dictionary = _peers.get(id, {})
	return peer["track"] if bool(peer.get("greeted", false)) else []


## [method quiet_for], for guest [param id]: -1 for nobody greeted by that id.
func quiet_for_of(id: int) -> float:
	var peer: Dictionary = _peers.get(id, {})
	if not bool(peer.get("greeted", false)):
		return -1.0
	return _now() - float(peer["heard"])


## **The points on peer [param id]'s ledger now**, after their decay: 0 for a
## peer in good standing or one this end does not have. A host cuts at
## [constant STRIKE_CUT]; a guest never strikes its host, so it always reads 0
## there. For tools and the log.
func points_of(id: int) -> float:
	var peer: Dictionary = _peers.get(id, {})
	if peer.is_empty():
		return 0.0
	return (peer["guard"] as Guard).points_now(_now())


## **A foul the referee called on guest [param id]** (net-hardening.md B):
## [param weight] points on the ledger A keeps, for [param why] -- which is the
## rule and what broke it. Enforced, it is a strike like any other, and ten
## points cut the guest with `REFUSE_BROKEN` and bar its address. Watched
## ([member enforce_referee] off), it goes on the watch ledger instead, counted
## and logged as what it would have done. One line per foul in the log, held to
## one every ten seconds for each address like every other (A.6). A host's
## alone: a guest never fouls its host.
func strike(id: int, weight: float, why: String) -> void:
	var peer: Dictionary = _peers.get(id, {})
	if not hosting or peer.is_empty() or not bool(peer.get("greeted", false)):
		return
	var guard: Guard = peer["guard"]
	var from := str(peer["address"])
	guard.fouls += 1
	gate_counts["fouls"] += 1
	if enforce_referee:
		gate_counts["referee_strikes"] += 1
		gate_counts["referee_points"] += weight
		_note("foul", Lan.source_key(from), "[net] %d (%s) fouled: %s -- %.0f point%s"
			% [id, from, why, weight, "" if weight == 1.0 else "s"])
		_strike(id, weight, "fouled: " + why)
		return
	var total := guard.would_strike(weight, _now())
	gate_counts["referee_would_strikes"] += 1
	gate_counts["referee_would_points"] += weight
	_note("would foul", Lan.source_key(from), "[net] would foul %d (%s): %s -- %.0f"
		% [id, from, why, weight] + " point%s -- watching the referee, not enforcing it"
		% ("" if weight == 1.0 else "s"))
	if total < STRIKE_CUT:
		return
	guard.would_cuts += 1
	guard.would_points = 0.0
	gate_counts["referee_would_cuts"] += 1
	_note("would cut foul", Lan.source_key(from), "[net] would cut %d (%s): fouled: %s"
		% [id, from, why] + " -- %.0f points -- watching the referee, not enforcing it"
		% total)


## [method send_event], to guest [param id] alone, **on that guest's own
## sequence** -- so each guest reads an unbroken run of events however many
## the others are sent, and its gap check stays a check.
func send_event_to(id: int, type: int, payload: PackedByteArray) -> void:
	var peer: Dictionary = _peers.get(id, {})
	if link != Link.TOGETHER or not bool(peer.get("greeted", false)):
		return
	peer["out_event"] = int(peer["out_event"]) + 1
	_to(id, Wire.event(int(peer["out_event"]), type, payload))


## [method send_pond], to guest [param id] alone: its own water, on its own
## sequence. Returns the size it went out at, 0 when nothing went.
func send_pond_to(id: int, your_wound: float, bodies: Array) -> int:
	var peer: Dictionary = _peers.get(id, {})
	if link != Link.TOGETHER or not bool(peer.get("greeted", false)):
		return 0
	peer["out_pond"] = int(peer["out_pond"]) + 1
	var frame := Wire.pond(int(peer["out_pond"]), your_wound, bodies)
	_to(id, frame)
	return frame.size()


## **The newest POND snapshot the far end sent**, as the raw frame, or an empty
## one. Drained to the newest by sequence on arrival, exactly as the state
## frames are; the reader applies it if its sequence is newer than the last it
## applied, and a frame read twice changes nothing.
func peer_pond() -> PackedByteArray:
	for id: int in _peers.keys():
		var peer: Dictionary = _peers[id]
		if bool(peer["greeted"]):
			return peer["pond"]
	return PackedByteArray()


## The flag byte of the far end's newest state frame -- wire.gd's `STATE_*` --
## or 0 with nobody there.
func peer_flags() -> int:
	for id: int in _peers.keys():
		var peer: Dictionary = _peers[id]
		if bool(peer["greeted"]):
			return int(peer["flags"])
	return 0


## True when the far end's run is in the pond: the host's is open, or the guest
## is swimming in it.
func peer_pond_open() -> bool:
	return (peer_flags() & Wire.STATE_POND) != 0


## True when the far end has a body and it is in the water -- not dead, and
## not dividing.
func peer_in_water() -> bool:
	var flags := peer_flags()
	return (flags & Wire.STATE_ALIVE) != 0 and (flags & Wire.STATE_OUT) == 0


## How many state frames this end has sent. The host's snapshot goes with
## every one of them, so a jump the state frame carries at once is in the water
## the guest sees at once as well.
func states_sent() -> int:
	return _out_state_seq


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
	if hosting:
		# A host's SceneMultiplayer never holds the socket (A.1), so it is asked
		# of the transport.
		if _peer == null \
				or _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			return 0
		return _peer.get_unique_id()
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

## [param via] is the listener a host heard this on; a guest's one transport
## is SceneMultiplayer's, and passes none.
func _on_peer_connected(id: int, via: int = VIA_LAN) -> void:
	# **Every peer, before anything else** -- one this host is about to refuse
	# included: it is ENet's setting and costs nothing (issue #61).
	_steady_throttle(id, via)
	var from := ""
	if hosting:
		# **One id, one peer.** ENet makes each listener's ids unique and no
		# more, so the other listener may already hold this one -- or be
		# hanging up on it. The newcomer is refused on its own transport, and
		# the peer already here never hears of it.
		if _peers.has(id) or _via.has(id) or _hanging_up.has(id):
			gate_counts["refused"] += 1
			gate_counts["refused_twin"] += 1
			if via == VIA_NET:
				gate_counts["net_refused"] += 1
				gate_counts["net_refused_twin"] += 1
			from = _address_of(id, via)
			_note("refused twin", "", "[net] refused %s: its id %d is taken on the other"
				% [from, id] + " listener, and one id is one peer")
			_drop_on(via, id)
			return
		# **The door** (A.5), before any bookkeeping exists for the caller. ENet
		# offers no earlier place to say no to an address, and a cut inside this
		# signal is safe with the caller's packets already queued -- measured
		# on 4.7-stable, and held by the probe's `limits` section (T6).
		from = _address_of(id, via)
		var no := _admit(from, via)
		if not no.is_empty():
			gate_counts["refused"] += 1
			gate_counts["refused_" + str(no[0])] += 1
			if via == VIA_NET:
				gate_counts["net_refused"] += 1
				gate_counts["net_refused_" + str(no[0])] += 1
			# A line per caller -- but a refusal that is about everybody, a
			# caller from outside or a door taking no calls at all, is one line
			# for all of them. A storm from a thousand addresses is then a line
			# every ten seconds, and the limiter only ever remembers callers
			# the door let near it.
			var about_all: bool = no[0] == "lan" or no[0] == "busy" or no[0] == "closed"
			var key := str(no[0]) if about_all else Lan.source_key(from)
			_note("refused", key if via == VIA_LAN else "internet " + key,
				"[net] refused %s%s: %s" % [from, " on the internet listener"
					if via == VIA_NET else "", no[1]])
			_drop_on(via, id)
			return
		_addresses[id] = Lan.source_key(from)
		_via[id] = via
	_peers[id] = {
		"id": id,
		"protocol": 0,
		"greeted": false,
		"since": _now(),
		"heard": _now(),
		"in_state": -1,
		"in_event": -1,
		"alive": true,
		"track": [],
		"flags": 0,
		"in_pond": -1,
		"pond": PackedByteArray(),
		# What this end has sent this peer alone: a host of several guests
		# numbers each one's events and snapshots apart.
		"out_event": 0,
		"out_pond": 0,
		# Where it calls from -- only a host asks -- and what it may still
		# send (A.4). Never read by `_take_state` or `_take_event`, which tools
		# drive with a dictionary of their own.
		"address": from,
		"guard": Guard.new(hosting, _now()),
		# Which listener, and on the internet one how far through the
		# handshake it is and which invite it proved (part C).
		"via": via,
		"stage": STAGE_HELLO,
		"nonce": PackedByteArray(),
		"label": "",
		"key_id": "",
		"secret": PackedByteArray(),
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


func _on_peer_disconnected(id: int, via: int = VIA_LAN) -> void:
	# A listener's goodbye to an id it does not hold here -- the other
	# listener's twin of it, refused -- is not news about this peer.
	if hosting and int(_via.get(id, via)) != via:
		return
	var peer: Dictionary = _peers.get(id, {})
	_peers.erase(id)
	_addresses.erase(id)
	_via.erase(id)
	# Gone already, so there is nothing left to hang up on: a refused guest
	# usually drops the line itself inside REFUSE_LINGER, and cutting it again
	# afterwards is an ENet error in the log and nothing else.
	_hanging_up.erase(id)
	if _greeted_count() == 0:
		_told = []
	if hosting:
		_farewell(id, peer)
		_forget_said_by(id)
		_lost_guest()
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
	if not _invite.is_empty():
		# **A call by invite failing before it connected**, which DTLS does at
		# once for a certificate that is not the pinned one and for a port that
		# refuses: which of the two is the second look's to say. A failure after
		# the call already gave up has been explained.
		if link == Link.REACHING and _diag == null:
			_diagnose()
		return
	_give_up(Link.FAILED, "no answer",
		"nothing is listening at that code. check your friend is still"
		+ " showing it.")


func _on_server_disconnected() -> void:
	if link == Link.REFUSED:
		# Already explained. The hang-up is the second half of the refusal, not
		# a separate event.
		return
	if not _invite.is_empty():
		_invite_gives_up(Link.FAILED, &"hung_up")
		return
	_give_up(Link.FAILED, "they hung up", "the other cell left the water.")


func _on_peer_packet(id: int, frame: PackedByteArray) -> void:
	# **The gate, first** (A.2). Everything the far end sends comes through
	# here -- off a host's own socket, off a guest's SceneMultiplayer, and out
	# of `tools/net_lag.gd`'s link model, which calls this directly -- so all of
	# it is gated, and nothing below ever reads a frame the gate has not sized.
	if not _admit_frame(id, frame):
		return
	var peer: Dictionary = _peers[id]
	# Stamped only on a frame the gate took, so junk cannot keep a peer looking
	# fresh.
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
		Wire.KIND_POND:
			if bool(peer.get("greeted", false)):
				_take_pond(peer, frame)
		Wire.KIND_CHALLENGE:
			_take_challenge(id, frame)
		Wire.KIND_PROOF:
			_take_proof(id, frame)
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
		# because the host is the one who can go and fetch the update. On the
		# internet listener too, and **before any invite is asked for**: the
		# compatibility check and the proof are two questions, and an old
		# build's answer to the first is "update", never "ask again".
		_refuse(id, Wire.REFUSE_PROTOCOL)
		_say("different versions", _skew_says(theirs))
		return
	if int(peer.get("via", VIA_LAN)) == VIA_NET:
		# **Then who are you** (part C): a fresh nonce, and the one thing this
		# caller may say next is the PROOF that answers it.
		var nonce := _crypto.generate_random_bytes(Wire.NONCE_SIZE)
		peer["nonce"] = nonce
		peer["stage"] = STAGE_PROOF
		_to(id, Wire.challenge(nonce))
		return
	_greet(id)


## **Welcome [param id]** -- or say "already two". A LAN caller gets here on its
## HELLO; one on the internet listener on its PROOF. The limit counts guests
## from both.
func _greet(id: int) -> void:
	var peer: Dictionary = _peers.get(id, {})
	if peer.is_empty():
		return
	if _greeted_count() >= guests_max:
		_refuse(id, Wire.REFUSE_FULL)
		return
	peer["greeted"] = true
	_to(id, Wire.welcome(_speaks(), my_id()))
	# A new listener has been told nothing, so the next report goes at once.
	_told = []
	_say("", "")
	_set_link(Link.TOGETHER)


## **A guest's answer to its host's CHALLENGE** (part C): the invite's key id,
## a nonce of its own, and the mac over both keyed with the invite's secret.
## Only on a call made by invite, and once: a CHALLENGE anywhere else is
## dropped -- a LAN host never sends one.
func _take_challenge(id: int, frame: PackedByteArray) -> void:
	if hosting:
		return
	if _invite.is_empty() or _proved or id != _host_id:
		gate_counts["challenges_dropped"] += 1
		return
	var nonce := Wire.challenge_nonce(frame)
	if nonce.is_empty():
		return
	var mine := _crypto.generate_random_bytes(Wire.NONCE_SIZE)
	var key_id: PackedByteArray = _invite["key_id"]
	_proved = true
	_to(id, Wire.proof(key_id, mine, Invite.proof_mac(_invite["secret"], _speaks(),
		nonce, mine, key_id)))


## **A caller's PROOF, checked** (part C). The gate lets one through only from
## a caller on the internet listener whose CHALLENGE has gone out, and only
## once. The mac is computed and compared in constant time whether or not the
## key id is one this host has -- against [member _decoy_secret] when it is
## not -- and **an unknown key id and a wrong secret get the same answer**:
## REFUSE_INVITE, the linger, and a bar. The log says which, and names the
## label; nothing a secret is made of is ever written anywhere.
func _take_proof(id: int, frame: PackedByteArray) -> void:
	if not hosting:
		return
	var peer: Dictionary = _peers.get(id, {})
	var parts := Wire.proof_parts(frame)
	if peer.is_empty() or parts.is_empty() \
			or int(peer.get("stage", STAGE_HELLO)) != STAGE_PROOF:
		return
	var key_id: PackedByteArray = parts[0]
	var key_hex := key_id.hex_encode()
	var entry: Array = _invites.get(key_hex, [])
	var secret: PackedByteArray = entry[1] if not entry.is_empty() else _decoy_secret
	var want := Invite.proof_mac(secret, _speaks(), peer["nonce"], parts[1], key_id)
	var matches := _crypto.constant_time_compare(want, parts[2])
	var from := str(peer["address"])
	if entry.is_empty() or not matches:
		gate_counts["proofs_refused"] += 1
		var barred := _bar(from, VIA_NET)
		_refuse(id, Wire.REFUSE_INVITE, " -- %s -- barred %d s" % ["a key id no invite has"
			if entry.is_empty() else "the wrong secret for the invite for %s" % str(entry[0]),
			roundi(barred)])
		return
	peer["label"] = str(entry[0])
	peer["key_id"] = key_hex
	peer["secret"] = secret
	gate_counts["proofs"] += 1
	# Printed whatever the limiter says, like the farewell: who came in from
	# outside is the one line an owner reads the log for.
	print("[net] %d (%s) proved the invite for %s" % [id, from, str(entry[0])])
	invite_proved.emit(str(entry[0]), key_hex)
	_greet(id)


func _take_welcome(id: int, frame: PackedByteArray) -> void:
	if hosting:
		return
	var theirs := Wire.protocol_of(frame)
	if theirs != _speaks():
		# Belt and braces. A host that welcomes us on a protocol we do not
		# speak is a host whose refusal path is broken; refuse it from this end
		# rather than play a game neither of us understands.
		if not _invite.is_empty():
			_invite_gives_up(Link.REFUSED, _skew_key(theirs))
		else:
			_give_up(Link.REFUSED, "different versions", _skew_says(theirs))
		_drop_link()
		return
	# **The id, learned twice and never assumed.** `peer_connected` reported it
	# and the host wrote its own into the welcome; if the two disagree the
	# transport is the authority, because it is what `send_bytes` addresses.
	var claimed := Wire.welcome_host_id(frame)
	if claimed != id:
		_note("host id", str(id), "[net] host calls itself %d, transport says %d"
			% [claimed, id], true)
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
	refused_for = reason
	if not _invite.is_empty():
		# **A server's refusal, in its own words** (docs/design/invites-ux.md
		# §6.3): it updates itself and holds water, and a refused invite is
		# remembered, so it is not dialled into a longer bar.
		match reason:
			Wire.REFUSE_INVITE:
				_turned_away[_mark_of(_invite)] = true
				_invite_gives_up(Link.REFUSED, &"invite_refused")
			Wire.REFUSE_PROTOCOL:
				_invite_gives_up(Link.REFUSED, _skew_key(theirs))
			Wire.REFUSE_FULL:
				_invite_gives_up(Link.REFUSED, &"already_two")
			Wire.REFUSE_BROKEN:
				_invite_gives_up(Link.REFUSED, &"cut_off")
			_:
				_invite_gives_up(Link.REFUSED, &"hung_up")
		_drop_link()
		return
	if reason == Wire.REFUSE_PROTOCOL:
		_give_up(Link.REFUSED, "different versions", _skew_says(theirs))
	elif reason == Wire.REFUSE_FULL:
		_give_up(Link.REFUSED, "already two",
			"that cell is already swimming with somebody.")
	elif reason == Wire.REFUSE_BROKEN:
		# **Cut for sending what the host would not take** (net-hardening.md
		# A.4): frames it could not read, or far more of them than any body
		# sends. Two honest builds on one protocol never get here, so for a
		# player it means one of the two is broken, and an update is the only
		# fix there is. The host also bars this address for a minute (A.5), so
		# a call straight back would only be hung up on at the door: the
		# sentence says when. A build that predates this reason reads the line
		# below instead.
		_give_up(Link.REFUSED, Wire.reason_says(reason),
			"the other end would not take what this game sent. update both from"
			+ " the launcher, then call again in a minute.")
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


## The same question for a call by invite, as an `Invite.SAYS` key: this game
## is older, or the server is -- which updates itself once its water is empty.
func _skew_key(theirs: int) -> StringName:
	return &"game_older" if _speaks() < theirs else &"server_older"


## Say no, then wait before hanging up. The waiting is not politeness -- see
## [constant REFUSE_LINGER] for what happens without it. Erased from the
## bookkeeping at once so a refused peer can never be counted as company, and
## kept in [member _hanging_up] so the line still gets cut if the other end
## decides to stay.
func _refuse(id: int, reason: int, detail: String = "") -> void:
	var from := str((_peers.get(id, {}) as Dictionary).get("address", ""))
	_to(id, Wire.refuse(_speaks(), reason))
	_peers.erase(id)
	_hanging_up[id] = _now() + REFUSE_LINGER
	_note("hung up", Lan.source_key(from), "[net] hung up on %d (%s): %s%s"
		% [id, from, Wire.reason_says(reason), detail])


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
	peer["flags"] = Wire.state_flags(frame)
	_track(peer, Wire.state_body(frame))


## **The host's water, drained to the newest** (shared-pond.md §2): a snapshot
## behind the newest one is dropped by its sequence, exactly as a state frame
## is, and it goes out unreliable for the same reason. Kept raw: decoding it is
## `pond.gd`'s, once a frame, and only the newest is ever worth decoding.
func _take_pond(peer: Dictionary, frame: PackedByteArray) -> void:
	if peer.is_empty():
		return
	var seq := Wire.seq_of(frame)
	if seq < 0 or seq <= int(peer["in_pond"]):
		return
	peer["in_pond"] = seq
	peer["pond"] = frame


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
		_note("event gap", str(peer.get("id", 0)), "[net] event gap: %d after %d"
			% [seq, peer["in_event"]], true)
	peer["in_event"] = seq
	if guests_max > 1:
		# **A host of several**: who said it matters -- a shout is passed on to
		# the other guest, an ENTER is answered to the one who sent it -- so
		# every event goes into one queue with its sender, in arrival order.
		inbox.append([int(peer["id"]), frame])
		_queue_inbox(int(peer["id"]), frame.size())
		return
	if Wire.event_type(frame) != Wire.EVENT_SHOUT:
		# A shared-pond event, kept whole for the run, in order. The gate only
		# lets through a type this protocol knows, and on a host only one that
		# parses -- so what waits here is what the run can read.
		pond_events.append(frame)
		_pond_bytes += frame.size()
		_queue_pond_events()
		return
	var said := Wire.take_shout(frame)
	if said.is_empty():
		return
	heard.append(said)
	while heard.size() > HEARD_MAX:
		heard.remove_at(0)


# ---------------------------------------------------------------------------
# **The boundary** (docs/design/net-hardening.md, part A): the host's socket,
# the gate every frame passes, the ledger, the door, and what the log is told.
# ---------------------------------------------------------------------------

## **When a host reads its socket: where SceneTree used to poll it for us.**
## SceneTree emits `process_frame` straight after polling every MultiplayerAPI
## and before any node processes, paused or not -- so a guest's frames land
## when they did before A, wherever this node is parented and whatever its
## priority: before the run reads them, and before the dedicated server's
## node, this one's parent, steps the pond. Connected by [method host], so it
## runs ahead of any `await` on the same signal made after it.
func _on_tree_frame() -> void:
	if not hosting:
		return
	var now := _now()
	_pump()
	_count_arrivals(now)
	# After the pump, so a stall's gap is measured from the last frame, not
	# this one: see [method _top_up].
	_frame_at = now


## **The host's socket, read by the host and by nothing else** (A.1). Every
## datagram that arrived since the last frame, oldest first, into
## [method _take_datagram], once a frame from [method _on_tree_frame].
##
## A handler below may close the session mid-way (a screen answering
## `link_changed`); the loop stops the moment [member _peer] is not the peer it
## began with. **The LAN listener first, then the internet one**, each drained
## the same way.
func _pump() -> void:
	_pump_one(_peer, VIA_LAN)
	if _net_peer != null and _peer != null:
		_pump_one(_net_peer, VIA_NET)


func _pump_one(enet: ENetMultiplayerPeer, via: int) -> void:
	if enet == null \
			or enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	enet.poll()
	if via == VIA_NET and _net_peer == enet \
			and enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		# ENet closes a listener whose service fails. Nothing a caller sends
		# does that to a DTLS one (enet_godot.cpp swallows its send errors), but
		# if it happens, its peers are gone with it, and the server's next look
		# at its invites opens a new one.
		_note("internet closed", "", "[net] the internet listener closed by itself")
		for id: int in _via.keys():
			if int(_via[id]) == VIA_NET and _peers.has(id):
				var peer: Dictionary = _peers[id]
				_peers.erase(id)
				if bool(peer["greeted"]):
					_farewell(id, peer)
					_forget_said_by(id)
		_finish_closing_internet()
		_lost_guest()
		return
	while _transport(via) == enet and enet.get_available_packet_count() > 0:
		var from := enet.get_packet_peer()
		_take_datagram(from, enet.get_packet(), via)


## **One datagram, as ENet delivered it.** Oversize is judged before anything
## is copied out of it. Then the RAW byte a protocol-4 guest's `send_bytes`
## puts in front of every frame is checked and taken off; any other command
## byte -- a path to cache, an RPC, a spawn -- is one this game never sends,
## and it is never run. [param via] is the listener it came in on: a datagram
## from an id that listener does not hold here is a stray.
func _take_datagram(id: int, bytes: PackedByteArray, via: int = VIA_LAN) -> void:
	var peer: Dictionary = _peers.get(id, {})
	if peer.is_empty() or int(peer.get("via", VIA_LAN)) != via:
		# Somebody refused, or cut, whose datagrams were already in: counted,
		# and never read.
		gate_counts["strays"] += 1
		return
	if bytes.size() - 1 > Wire.GUEST_FRAME_MAX:
		_oversize(id, bytes.size() - 1)
		return
	if bytes.size() < 2 or bytes[0] != RAW:
		if not bool(peer["greeted"]):
			_cut(id, _too_soon(peer), false, false)
		else:
			_malformed(id, "a command byte %d, where a frame starts with %d"
				% [bytes[0] if not bytes.is_empty() else -1, RAW])
		return
	_on_peer_packet(id, bytes.slice(1))


## **The gate** (A.2): true to take [param frame] from peer [param id], false
## to drop it. The first step that fails ends it, and no byte past a size
## already checked is ever read.
##
## A host is strict with its guests -- a frame no writer produces is a strike,
## and a cut ends the worst -- and a guest is lenient with its host: it drops
## what it cannot use and never punishes, because a host is not somebody a
## guest can refuse.
func _admit_frame(id: int, frame: PackedByteArray) -> bool:
	# 1. Somebody this end is talking to: not refused, not cut, not unknown.
	var peer: Dictionary = _peers.get(id, {})
	if peer.is_empty():
		return false
	# 2. The direction's cap, before any byte past the first is read. Over it
	# is the one offence that bypasses the ledger: it is how memory gets taken.
	var size := frame.size()
	if size > (Wire.GUEST_FRAME_MAX if hosting else Wire.HOST_FRAME_MAX):
		_oversize(id, size)
		return false
	if size == 0:
		return _malformed(id, "an empty frame")
	var kind := Wire.kind(frame)
	# 3. **Before the handshake, a host hears one thing: a HELLO.** A guest
	# says it the moment its transport connects, so anything else first is not
	# a guest. A guest is lenient here on purpose: the host's first STATE can
	# overtake its WELCOME on another channel, and is simply not read yet.
	# **On the internet listener, then one PROOF** (part C), once its CHALLENGE
	# has gone out: exactly one HELLO, then exactly one PROOF, and anything
	# else -- a second HELLO, a PROOF before the CHALLENGE, a STATE before the
	# PROOF -- is a caller that is not a guest.
	if hosting and not bool(peer["greeted"]):
		var wants := Wire.KIND_PROOF if int(peer.get("stage", STAGE_HELLO)) == STAGE_PROOF \
			else Wire.KIND_HELLO
		if kind == wants and Wire.size_ok(kind, 0, size, false):
			return true
		_cut(id, _too_soon(peer), false, false)
		return false
	# 4-5. A kind this protocol knows must come from the side that sends it, at
	# a size its writer produces.
	var type := 0
	if kind == Wire.KIND_EVENT:
		if size < Wire.EVENT_HEADER:
			return _malformed(id, "an event too short to say what it is")
		type = frame[5]
	var known := Wire.known(kind, type)
	if known and not Wire.size_ok(kind, type, size, not hosting):
		return _malformed(id, "%s of %d bytes from the %s" % [_kind_says(kind, type),
			size, "guest" if hosting else "host"])
	if hosting and kind == Wire.KIND_HELLO:
		return _malformed(id, "a second hello")
	if hosting and kind == Wire.KIND_PROOF:
		# **A proof nobody asked for.** On the internet listener that is a
		# second one, from a guest already welcomed: cut and barred, as the
		# handshake's rules are. On the LAN, where no CHALLENGE is ever sent, it
		# is a frame this protocol's LAN never carries.
		if int(peer.get("via", VIA_LAN)) == VIA_NET:
			_cut(id, "a second proof", true, true)
			return false
		return _malformed(id, "a proof it was never asked for")
	# 6. The budgets: every frame, known or not, and every event -- enforced
	# only when [member enforce_budgets] says so. Watched, an overrun is counted
	# and logged as what it would have done, and the frame goes on.
	var guard: Guard = peer["guard"]
	if not _within_budgets(id, guard, kind, size) and enforce_budgets:
		return false
	# 7. **A kind or type from a later build**, which the wire promises to
	# ignore: dropped, with no strike, once the budgets have paid for it. An
	# event keeps its place in the order, so the next one is not a gap.
	if not known:
		gate_counts["unknown"] += 1
		if kind == Wire.KIND_EVENT:
			peer["in_event"] = maxi(int(peer["in_event"]), Wire.seq_of(frame))
		return false
	# 8. **Parse or reject**, on a host, with the readers pond.gd uses: nothing
	# reaches a queue that the run would refuse a frame later.
	if hosting and not _parses(kind, type, frame):
		return _malformed(id, "%s that does not read" % _kind_says(kind, type))
	# 9. Taken.
	guard.taken += 1
	guard.taken_bytes += size
	if kind == Wire.KIND_EVENT:
		guard.taken_events += 1
	return true


## **What a guest's frame reads to, on a host**: every event through the
## `Wire.take_*` that pond.gd uses for it, and a state frame that says it has
## a body through [method Wire.state_body] -- one carrying a NaN used to clear
## the friend's track as if they had died. Reserved flag bits are not judged:
## the wire promises to ignore them.
static func _parses(kind: int, type: int, frame: PackedByteArray) -> bool:
	if kind == Wire.KIND_STATE:
		return (frame[5] & Wire.STATE_ALIVE) == 0 or not Wire.state_body(frame).is_empty()
	if kind != Wire.KIND_EVENT:
		return true
	match type:
		Wire.EVENT_SHOUT:
			return not Wire.take_shout(frame).is_empty()
		Wire.EVENT_ENTER:
			return not Wire.take_enter(frame).is_empty()
		Wire.EVENT_PERSON:
			return not Wire.take_person(frame).is_empty()
		Wire.EVENT_DIED:
			return not Wire.take_died(frame).is_empty()
		Wire.EVENT_SISTER:
			return not Wire.take_sister(frame).is_empty()
	return true


## What a caller that said the wrong thing before it was welcomed is cut for.
static func _too_soon(peer: Dictionary) -> String:
	if int(peer.get("stage", STAGE_HELLO)) == STAGE_PROOF:
		return "spoke before its proof"
	return "spoke before its hello"


static func _kind_says(kind: int, type: int) -> String:
	if kind == Wire.KIND_EVENT:
		return "an event of type %d" % type
	return "a frame of kind %d" % kind


## **A host stall hands every budget the whole gap at once** (A.4), once a
## frame per peer: a frame that began more than [constant STALL_GAP] after the
## last is the host catching up, and what arrives in it is the stall's backlog,
## not a flood. [member _frame_at] is still the last frame's start here: a
## host reads its socket before moving it on, and a guest's SceneMultiplayer
## reads before this node processes at all.
func _top_up(guard: Guard, now: float) -> void:
	var gap := now - _frame_at
	var frame := Engine.get_process_frames()
	if gap <= STALL_GAP or guard.topped == frame:
		return
	guard.topped = frame
	var credit := minf(gap, STALL_CREDIT)
	guard.frames.top_up(credit)
	guard.bytes.top_up(credit)
	guard.events.top_up(credit)


## **Charge a frame to its sender's budgets** (A.4): frames, then bytes, then,
## for an event, events. The first that cannot pay is the overrun, and the
## rest are not charged for that frame, as they would not be for a frame the
## gate drops -- so watch mode counts exactly what enforcing would have done.
## False on an overrun, in either mode: [member enforce_budgets] is the
## caller's to read.
func _within_budgets(id: int, guard: Guard, kind: int, size: int) -> bool:
	var now := _now()
	_top_up(guard, now)
	if not guard.frames.take(1.0, now):
		_over_frames(id, guard, now)
		return false
	if not guard.bytes.take(float(size), now):
		_over_budget(id, guard, STRIKE_BYTES, "bytes", "over its byte budget"
			+ " (%d a second, %d at once)" % [roundi(guard.bytes.rate),
				roundi(guard.bytes.burst)])
		return false
	if kind == Wire.KIND_EVENT and not guard.events.take(1.0, now):
		_over_budget(id, guard, STRIKE_EVENTS, "events", "over its event budget"
			+ " (%d a second, %d at once)" % [roundi(guard.events.rate),
				roundi(guard.events.burst)])
		return false
	return true


## A frame over the frame budget: dropped -- a state frame is superseded fifty
## milliseconds later anyway -- or, watched, counted as one that would have
## been. On a host, every [constant FLOOD_DROPS] of them inside a
## [constant FLOOD_WINDOW] is a flood strike, real or watched.
func _over_frames(id: int, guard: Guard, now: float) -> void:
	_overrun(id, guard, "frames", "over its frame budget (%d a second, %d at once)"
		% [roundi(guard.frames.rate), roundi(guard.frames.burst)])
	if not hosting:
		return
	if now - guard.flood_at >= FLOOD_WINDOW:
		guard.flood_at = now
		guard.flood_drops = 0
		guard.flood_struck = 0
	guard.flood_drops += 1
	if guard.flood_drops > FLOOD_DROPS * (guard.flood_struck + 1):
		guard.flood_struck += 1
		_budget_strike(id, guard, STRIKE_FLOOD, "flooding: %d frames over its budget"
			% guard.flood_drops + " in a second (%d a second, %d at once)"
			% [roundi(guard.frames.rate), roundi(guard.frames.burst)])


## A frame over the byte or event budget: dropped and struck on a host, or,
## watched, counted and struck on watch mode's ledger alone.
func _over_budget(id: int, guard: Guard, weight: float, what: String,
		why: String) -> void:
	_overrun(id, guard, what, why)
	if hosting:
		_budget_strike(id, guard, weight, why)


## **The count and the line for one frame over a budget.** Enforced, it is a
## drop: a line on a guest, and on a host the strike that follows says it.
## Watched, it is a frame that would have been dropped, taken all the same, and
## the line says so on either side.
func _overrun(id: int, guard: Guard, what: String, why: String) -> void:
	if enforce_budgets:
		guard.dropped += 1
		gate_counts["dropped"] += 1
		gate_counts["dropped_" + what] += 1
		if not hosting:
			_note("over", what, "[net] dropped a frame from the host: " + why)
		return
	guard.would_dropped += 1
	gate_counts["would_drop"] += 1
	gate_counts["would_drop_" + what] += 1
	if not hosting:
		_note("would drop", "host", "[net] would drop a frame from the host: %s"
			% why + " -- watching the budgets, not enforcing them")
		return
	var from := _from(id)
	_note("would drop", Lan.source_key(from), "[net] would drop a frame from %d"
		% id + " (%s): %s -- watching the budgets, not enforcing them" % [from, why])


## **A budget's strike** (A.4). Enforced, it goes on the ledger like any other.
## Watched, it goes on watch mode's own, and reaching [constant STRIKE_CUT]
## there -- with the real points counted in -- is a cut that would have
## happened: counted, logged, and the watch ledger emptied, as the cut would
## have ended that peer's.
func _budget_strike(id: int, guard: Guard, weight: float, why: String) -> void:
	if enforce_budgets:
		_strike(id, weight, why)
		return
	var total := guard.would_strike(weight, _now())
	gate_counts["would_strikes"] += 1
	gate_counts["would_points"] += weight
	if total < STRIKE_CUT:
		return
	guard.would_cuts += 1
	guard.would_points = 0.0
	gate_counts["would_cuts"] += 1
	var from := _from(id)
	_note("would cut", Lan.source_key(from), "[net] would cut %d (%s): %s -- %.0f"
		% [id, from, why, total] + " points -- watching the budgets, not enforcing them")


## Where peer [param id] calls from, as the door saw it: "" for a guest's
## host, and for anybody this end no longer has.
func _from(id: int) -> String:
	return str((_peers.get(id, {}) as Dictionary).get("address", ""))


## A frame no writer produces: 4 points on a host, and dropped either way.
## Returns false, for the gate to return.
func _malformed(id: int, why: String) -> bool:
	gate_counts["malformed"] += 1
	if hosting:
		_strike(id, STRIKE_MALFORMED, "malformed: " + why)
	else:
		_note("malformed", "host", "[net] dropped a frame from the host: " + why)
	return false


## A frame over the direction's cap. A host cuts the guest on the spot and
## bars its address; a guest drops it.
func _oversize(id: int, size: int) -> void:
	gate_counts["oversize"] += 1
	if hosting:
		_cut(id, "a %d-byte frame, where a guest writes %d at most"
			% [size, Wire.GUEST_FRAME_MAX], false, true)
	else:
		_note("oversize", "host", "[net] dropped a %d-byte frame from the host,"
			% size + " where a host writes %d at most" % Wire.HOST_FRAME_MAX)


## **A strike on peer [param id]'s ledger** (A.4). At [constant STRIKE_CUT]
## the peer is cut, told why and barred; crossing half of it is one line in the
## log, so a peer that is close is visible before it is gone.
func _strike(id: int, weight: float, why: String) -> void:
	var peer: Dictionary = _peers.get(id, {})
	if peer.is_empty():
		return
	var guard: Guard = peer["guard"]
	var now := _now()
	var before := guard.points_now(now)
	var after := guard.strike(weight, now)
	gate_counts["strikes"] += 1
	gate_counts["points"] += weight
	if after >= STRIKE_CUT:
		_cut(id, "%s -- %.0f points" % [why, after], true, true)
		return
	if before < STRIKE_CUT * 0.5 and after >= STRIKE_CUT * 0.5:
		var from := str(peer["address"])
		_note("strike", Lan.source_key(from), "[net] %d (%s) is at %.0f of %.0f"
			% [id, from, after, STRIKE_CUT] + " points: %s" % why)


## **Hang up on a peer that broke the rules** (A.4). Out of the bookkeeping at
## once, so none of its frames already waiting is read. A greeted guest cut by
## its ledger ([param tell]) is told why first -- REFUSE_BROKEN, and
## [constant REFUSE_LINGER] for it to arrive -- and anything else is cut on the
## spot: an oversize frame, or anything but a HELLO before the handshake, is
## not worth a sentence. [param abuse] bars the address. [param reason] is what
## a guest told is told: a guest whose invite was revoked hears
## `REFUSE_INVITE`, and every other cut `REFUSE_BROKEN`.
func _cut(id: int, why: String, tell: bool, abuse: bool,
		reason: int = Wire.REFUSE_BROKEN) -> void:
	var peer: Dictionary = _peers.get(id, {})
	if peer.is_empty():
		return
	var greeted := bool(peer["greeted"])
	var from := str(peer["address"])
	_peers.erase(id)
	if tell and greeted:
		_to(id, Wire.refuse(_speaks(), reason))
		_hanging_up[id] = _now() + REFUSE_LINGER
	else:
		_drop_now(id)
	gate_counts["cuts"] += 1
	var barred := _bar(from, int(peer.get("via", VIA_LAN))) if abuse else 0.0
	_note("cut", Lan.source_key(from), "[net] cut %d (%s): %s%s" % [id, _who(peer), why,
		" -- barred %d s" % roundi(barred) if barred > 0.0 else ""])
	if greeted:
		_farewell(id, peer)
		_forget_said_by(id)
		_lost_guest()


## **Cut [param id]'s transport now.** ENet frees the slot at once and says
## `peer_disconnected` on the next poll. `disconnect_peer()` would wait for an
## acknowledgement a hostile peer never sends, and hold the slot until ENet
## timed it out. A host's alone: a guest never cuts its host.
func _drop_now(id: int) -> void:
	if not hosting:
		return
	_drop_on(int(_via.get(id, VIA_LAN)), id)


## [method _drop_now], on the listener [param via] -- for a caller refused
## before this host kept any record of which listener it came in on.
func _drop_on(via: int, id: int) -> void:
	var enet := _transport(via)
	if not hosting or enet == null \
			or enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	# In ENet's own bookkeeping until it says `peer_disconnected`, which is
	# also what takes the id out of [member _hanging_up]; so asking is safe.
	var enet_peer := enet.get_peer(id)
	if enet_peer != null and enet_peer.is_active():
		enet_peer.peer_disconnect_now()


## Bars [param from] for [constant BAR_FIRST], or [constant BAR_AGAIN] when it
## was barred inside the last [constant BAR_AGAIN] already, at the door of the
## listener [param via]. Returns how long.
func _bar(from: String, via: int = VIA_LAN) -> float:
	if from.is_empty():
		return 0.0
	var now := _now()
	var entry := _book_entry(Lan.source_key(from), now, _book_of(via))
	var again := int(entry["bars"]) > 0 and now - float(entry["barred_at"]) < BAR_AGAIN
	var hold := BAR_AGAIN if again else BAR_FIRST
	entry["bars"] = int(entry["bars"]) + 1 if again else 1
	entry["barred_at"] = now
	entry["barred_until"] = now + hold
	gate_counts["bars"] += 1
	return hold


## A host whose last greeted guest has gone -- it left, or it was cut -- is
## listening again, and **nothing that guest said is left waiting**: a phone
## host's run stops draining [member pond_events] the moment the link drops, so
## an ENTER still queued would reach the next guest as an arrival it never
## made, and a shout as a call from nobody. A caller still saying hello is not
## company.
func _lost_guest() -> void:
	if not hosting or _greeted_count() > 0:
		return
	pond_events.clear()
	_pond_bytes = 0
	heard.clear()
	if link == Link.TOGETHER:
		_say("they left", "the other cell went. show the code again.")
		_set_link(Link.LISTENING)


## **A dedicated host forgets what one guest said** when it leaves or is cut:
## its events still in [member inbox] are about a body that is gone, and are
## nobody else's to hear.
func _forget_said_by(id: int) -> void:
	_inbox_load.erase(id)
	if inbox.is_empty():
		return
	var kept: Array = []
	for said: Array in inbox:
		if int(said[0]) != id:
			kept.append(said)
	inbox = kept


## **One line for every guest a host had, as it goes** (A.6): how long, what
## it sent, how often it went over its budgets -- enforced or only watched --
## and the points it left with. So a playtest's log says the budgets never bit
## in so many words, rather than by saying nothing. The address goes to the log
## and nowhere else.
func _farewell(id: int, peer: Dictionary) -> void:
	if not hosting or not bool(peer.get("greeted", false)):
		return
	var guard: Guard = peer["guard"]
	var now := _now()
	print("[net] %d (%s) done after %d s -- frames %d, events %d, over budget %d,"
		% [id, _who(peer), roundi(now - float(peer["since"])), guard.taken,
			guard.taken_events, guard.dropped + guard.would_dropped]
		+ " points %.0f, fouls %d" % [guard.points_now(now), guard.fouls])


## **Who a peer is, for the log**: its address, and for a guest that came in by
## invite, whose invite -- the label, never anything a secret is made of.
static func _who(peer: Dictionary) -> String:
	var label := str(peer.get("label", ""))
	var from := str(peer.get("address", ""))
	return from if label.is_empty() else "%s, invite %s" % [from, label]


## **Whether to answer a caller at all** (A.5), in `peer_connected` -- the
## earliest place 4.7 lets GDScript say no to an address -- and before any
## bookkeeping exists for it. `[]` answers it; otherwise `[reason, sentence]`
## for the counts and the log. The order is the cost: an address that is
## barred or not on this network spends no one else's budget, and **a call its
## own address's bucket turns away never touches the bucket every address
## shares** -- or one device calling fast would lock every other one out (the
## review measured it: twelve calls from one address, and a first call from
## another was refused as busy). Nor does a call the shared bucket turns away
## cost its address anything.
##
## **[param via] is the listener, and each keeps its own door** (part C): its
## own address book -- the call buckets and the bars -- its own bucket for every
## address together, its own count of transports per address and its own
## waiting room. So a storm on the internet listener fills the internet
## listener's room and empties its buckets, and a LAN caller finds its own as
## they were. The LAN-only guard is the LAN listener's alone; a caller on the
## internet one proves an invite instead.
func _admit(from: String, via: int = VIA_LAN) -> Array:
	var now := _now()
	if via == VIA_LAN and (not Lan.is_local_source(from, address)
			or (not loopback_is_local and Lan.is_loopback(from))):
		return ["lan", "not on this network -- a call from outside needs an invite, on"
			+ " port %d" % Invite.PORT]
	if via == VIA_NET and not internet_listening():
		return ["closed", "the internet listener is closing"]
	var key := Lan.source_key(from)
	var entry := _book_entry(key, now, _book_of(via))
	if now < float(entry["barred_until"]):
		return ["barred", "barred for %d s more" % ceili(float(entry["barred_until"]) - now)]
	var own: Bucket = entry["calls"]
	if own.level(now) < 1.0:
		return ["calls", "calling too often -- %d at once, then one every %d s"
			% [roundi(CALLS_BURST), roundi(1.0 / CALLS_RATE)]]
	var everybody: Bucket = _calls_all if via == VIA_LAN else _net_calls_all
	if not everybody.take(1.0, now):
		return ["busy", "more than %d calls a second, from everywhere"
			% roundi(CALLS_ALL_RATE)]
	own.take(1.0, now)
	var live := 0
	for other: int in _addresses:
		if str(_addresses[other]) == key and int(_via.get(other, VIA_LAN)) == via:
			live += 1
	if live >= LIVE_PER_ADDRESS:
		return ["live", "%d connections from there already" % live]
	var pending := 0
	for other: int in _peers:
		if not bool(_peers[other]["greeted"]) \
				and int(_peers[other].get("via", VIA_LAN)) == via:
			pending += 1
	if pending >= PENDING_MAX:
		return ["pending", "%d callers are already saying hello" % pending]
	return []


## The address book's entry for [param key] in [param book], made if there is
## none. A full book forgets an idle caller first, then the one heard from
## longest ago, and a barred one only when every caller in it is barred.
func _book_entry(key: String, now: float, book: Dictionary) -> Dictionary:
	var entry: Dictionary = book.get(key, {})
	if entry.is_empty():
		if book.size() >= BOOK_MAX:
			_forget_a_caller(now, book)
		entry = {"calls": Bucket.new(CALLS_RATE, CALLS_BURST, now),
			"barred_until": 0.0, "barred_at": -BAR_AGAIN, "bars": 0, "seen": now}
		book[key] = entry
	entry["seen"] = now
	return entry


func _forget_a_caller(now: float, book: Dictionary) -> void:
	var oldest := ""
	var oldest_seen := INF
	for key: String in book.keys():
		var entry: Dictionary = book[key]
		if now < float(entry["barred_until"]):
			continue
		if now - float(entry["seen"]) > BOOK_IDLE:
			book.erase(key)
			continue
		if float(entry["seen"]) < oldest_seen:
			oldest_seen = float(entry["seen"])
			oldest = key
	if book.size() < BOOK_MAX:
		return
	if oldest.is_empty():
		oldest = str(book.keys()[0])
	book.erase(oldest)


## The address book of the listener [param via].
func _book_of(via: int) -> Dictionary:
	return _net_book if via == VIA_NET else _book


## **The transport of the listener [param via]**: a guest's socket or a host's
## LAN listener, or a host's internet listener. Null if it is not open.
func _transport(via: int) -> ENetMultiplayerPeer:
	return _net_peer if via == VIA_NET else _peer


## The transport peer [param id] came in on.
func _transport_of(id: int) -> ENetMultiplayerPeer:
	return _transport(int(_via.get(id, VIA_LAN)))


## The caller's address, as ENet has it: dotted for IPv4, eight groups for
## IPv6. "" if the listener [param via] has no peer by that id.
func _address_of(id: int, via: int = VIA_LAN) -> String:
	var enet := _transport(via)
	if enet == null:
		return ""
	var enet_peer := enet.get_peer(id)
	if enet_peer == null or not enet_peer.is_active():
		return ""
	return str(enet_peer.get_remote_address())


## **A guest's events waiting for a phone host's run, or a host's for a
## guest's**: capped by count and by weight, the oldest dropped first. A host
## holds its guest to [constant QUEUE_FRAMES] and [constant QUEUE_BYTES]; a
## guest holds its host to [constant POND_EVENTS_MAX] and
## [constant POND_EVENTS_BYTES], because one ENTER is answered with seventy.
func _queue_pond_events() -> void:
	var frames_max := QUEUE_FRAMES if hosting else POND_EVENTS_MAX
	var bytes_max := QUEUE_BYTES if hosting else POND_EVENTS_BYTES
	while not pond_events.is_empty() \
			and (pond_events.size() > frames_max or _pond_bytes > bytes_max):
		_pond_bytes -= (pond_events[0] as PackedByteArray).size()
		pond_events.remove_at(0)
		gate_counts["queue_dropped"] += 1
	_pond_bytes = maxi(_pond_bytes, 0)


## **A dedicated host's queue, capped per guest**: a guest over its share
## loses its own oldest event, never the other guest's.
func _queue_inbox(from: int, size: int) -> void:
	var load: Array = _inbox_load.get(from, [0, 0])
	load[0] = int(load[0]) + 1
	load[1] = int(load[1]) + size
	_inbox_load[from] = load
	var at := 0
	while (int(load[0]) > QUEUE_FRAMES or int(load[1]) > QUEUE_BYTES) \
			and at < inbox.size():
		if int(inbox[at][0]) != from:
			at += 1
			continue
		load[0] = int(load[0]) - 1
		load[1] = int(load[1]) - (inbox[at][1] as PackedByteArray).size()
		inbox.remove_at(at)
		gate_counts["queue_dropped"] += 1


## **What arrived at the host's socket, once a second** (A.6) -- everything
## ENet read, the datagrams no gate ever saw included -- and a line when it is
## more than any two real guests send: about 7 KB and 170 datagrams a second.
## The peaks are kept in [member gate_counts] for tools.
func _count_arrivals(now: float) -> void:
	var span := now - _saturation_from
	if span < 1.0 or _peer == null \
			or _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	_saturation_from = now
	# Both listeners, the internet one's counted after DTLS has had its say:
	# what ENet read, which is what the gate is asked to read.
	var data := 0.0
	var datagrams := 0.0
	for enet: ENetMultiplayerPeer in [_peer, _net_peer]:
		if enet == null \
				or enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED \
				or enet.host == null:
			continue
		data += enet.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / span
		datagrams += enet.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS) \
			/ span
	gate_counts["peak_bytes"] = maxf(float(gate_counts["peak_bytes"]), data)
	gate_counts["peak_datagrams"] = maxf(float(gate_counts["peak_datagrams"]), datagrams)
	if data > SATURATED_BYTES or datagrams > SATURATED_DATAGRAMS:
		gate_counts["saturated"] += 1
		_note("saturated", "", "[net] saturated: %.1f KB a second in %d datagrams"
			% [data / 1024.0, roundi(datagrams)] + " arriving at the socket")


## **One line for the log, at most once per [param what] and [param key] every
## [constant NOTE_EVERY]** (A.6), and the next says how many like it were held
## back -- so a peer that sends a thousand bad frames a second costs the log a
## line every ten seconds, not a thousand. [param key] is an address, a peer, or
## the reason for a refusal that is about everybody; an address goes to the log
## and nowhere else. [param warn] makes it a warning rather than a plain line:
## the three the session always warned about.
func _note(what: String, key: String, line: String, warn: bool = false) -> void:
	var now := _now()
	var slot := what + "|" + key
	var seen: Array = _notes.get(slot, [0.0, 0])
	if now < float(seen[0]):
		seen[1] = int(seen[1]) + 1
		_notes[slot] = seen
		return
	if int(seen[1]) > 0:
		line += " (+%d like it held back)" % int(seen[1])
	if _notes.size() >= NOTES_MAX and not _notes.has(slot):
		# Full: every hold that has ended goes, and if none has, the one that
		# ends soonest -- so [constant NOTES_MAX] is a bound, not a hope.
		var soonest := ""
		for old: String in _notes.keys():
			if now >= float(_notes[old][0]):
				_notes.erase(old)
			elif soonest.is_empty() or float(_notes[old][0]) < float(_notes[soonest][0]):
				soonest = old
		if _notes.size() >= NOTES_MAX and not soonest.is_empty():
			_notes.erase(soonest)
	_notes[slot] = [now + NOTE_EVERY, 0]
	if warn:
		push_warning(line)
	else:
		print(line)


func _zero_counts() -> void:
	gate_counts = {
		"refused": 0, "refused_lan": 0, "refused_barred": 0, "refused_busy": 0,
		"refused_calls": 0, "refused_live": 0, "refused_pending": 0,
		"cuts": 0, "bars": 0, "strikes": 0, "points": 0.0,
		"oversize": 0, "malformed": 0, "unknown": 0,
		"dropped": 0, "dropped_frames": 0, "dropped_bytes": 0, "dropped_events": 0,
		"queue_dropped": 0, "strays": 0, "saturated": 0, "peak_bytes": 0.0,
		"peak_datagrams": 0.0,
		# Watch mode's (see [member enforce_budgets]): what the budgets would
		# have done. A playtest that is to turn them on must show every one 0.
		"would_drop": 0, "would_drop_frames": 0, "would_drop_bytes": 0,
		"would_drop_events": 0, "would_strikes": 0, "would_points": 0.0,
		"would_cuts": 0,
		# **The referee's** (part B, [method strike]): every foul, enforced or
		# watched, and then the two apart. An honest guest makes none.
		"fouls": 0, "referee_strikes": 0, "referee_points": 0.0,
		"referee_would_strikes": 0, "referee_would_points": 0.0,
		"referee_would_cuts": 0,
		# **The internet listener's** (part C): its door's refusals apart --
		# they are in `refused` and `refused_*` as well -- a second peer under
		# one id, invites proved and refused, guests cut when theirs was
		# revoked, and a guest's CHALLENGEs it had no invite to answer.
		"refused_twin": 0, "refused_closed": 0,
		"net_refused": 0, "net_refused_barred": 0, "net_refused_busy": 0,
		"net_refused_calls": 0, "net_refused_live": 0, "net_refused_pending": 0,
		"net_refused_closed": 0, "net_refused_twin": 0,
		"proofs": 0, "proofs_refused": 0, "invite_cuts": 0, "challenges_dropped": 0,
	}


# ---------------------------------------------------------------------------
# Plumbing.
# ---------------------------------------------------------------------------

func _speaks() -> int:
	return Wire.PROTOCOL if protocol_override == 0 else protocol_override


func _to(id: int, frame: PackedByteArray) -> void:
	var err := OK
	if hosting:
		# **The bytes `send_bytes` wrote**, written by hand, because a host's
		# SceneMultiplayer no longer holds the socket (A.1): the RAW byte, the
		# frame, channel 0, the frame's own mode -- so a guest on any protocol-4
		# build cannot tell the difference. Through the listener the guest came
		# in on.
		var enet := _transport_of(id)
		if enet == null \
				or enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			return
		enet.set_target_peer(id)
		enet.transfer_channel = 0
		enet.transfer_mode = _mode_for(frame)
		var raw := PackedByteArray([RAW])
		raw.append_array(frame)
		err = enet.put_packet(raw)
	else:
		if _api == null or _api.multiplayer_peer == null:
			return
		err = _api.send_bytes(frame, id, _mode_for(frame), 0)
	if err != OK:
		_note("send", str(id), "[net] could not send %d bytes to %d (error %d)"
			% [frame.size(), id, err], true)


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
## - **So does a POND snapshot** (shared-pond.md §2), for the same two reasons:
##   drained to the newest by its own sequence, and never able to hold up an
##   event behind it.
## - **Everything else stays reliable**: the handshake, the refusal, the shout
##   and the shared pond's events. A shout heard twice is two shouts and a shout
##   lost is a pulse the other cell never felt; a bite, a death or an arrival
##   told twice or not at all is a water the two screens disagree about.
##   None of them is superseded by anything.
##
## A WebSocket transport has no modes -- `set_transfer_mode()` is silently
## ignored there -- so it sends everything reliable-ordered, and the frames are
## exactly as correct on it: that is what designing the format for the
## WebSocket shape bought. Porting means deleting this function, not rewriting
## the wire.
static func _mode_for(frame: PackedByteArray) -> int:
	var kind := Wire.kind(frame)
	# **A POND snapshot too** (shared-pond.md §2), for the state frame's own two
	# reasons: it is idempotent and drained to the newest, so a lost one is
	# superseded fifty milliseconds later -- and a reliable one lost on a lossy
	# link would hold every event behind it, a bite and a death included, for a
	# resend timeout.
	if kind == Wire.KIND_STATE or kind == Wire.KIND_POND:
		return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


## **The peer the transport just connected, pinned at a throttle of 32** -- see
## [constant THROTTLE_DECELERATION]. The host's peer for every guest, both of a
## dedicated host's included, and a guest's for its host. Before the handshake,
## because this is ENet's setting and not the game's: a peer refused a moment
## later has cost nothing.
##
## **One end is enough, and that is what lets it ship as content.** ENet tells
## the far end the same three numbers in a THROTTLE_CONFIGURE command
## (`peer.c:43-58`), and the far end's ENet -- compiled into its binary,
## whatever content pack it runs -- writes them into its own peer for this one
## (`protocol.c:809-819`). So a device on this content steadies both directions
## with one still on an older pack, whichever of the two is hosting. The command
## reaches the far end with the first acknowledgement it receives, before it
## has judged any; if a lost datagram delays it past a judgement and the
## throttle dips a step first, ENet's own acceleration brings it back.
func _steady_throttle(id: int, via: int = VIA_LAN) -> void:
	var enet := _transport(via)
	if enet == null:
		return
	var enet_peer := enet.get_peer(id)
	if enet_peer == null:
		return
	enet_peer.throttle_configure(THROTTLE_INTERVAL, THROTTLE_ACCELERATION,
		THROTTLE_DECELERATION)


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
	var flags := (Wire.STATE_POND if _in_pond else 0) \
		| (Wire.STATE_OUT if _out_of_water else 0)
	var frame := Wire.state(_out_state_seq, _body, _body_at, _body_heading,
		_body_radius, _body_velocity if moving else Vector2.ZERO,
		_body_turning if moving else 0.0, flags)
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
	trouble_key = &""
	link_changed.emit(link)


func _give_up(to: int, headline: String, detail: String) -> void:
	trouble = headline
	because = detail
	trouble_key = &""
	_set_link(to)


## Put the socket down but keep the node and the bound API, so a refusal can be
## read on screen and the player can try again without a new session.
func _drop_link() -> void:
	if is_inside_tree() and get_tree().process_frame.is_connected(_on_tree_frame):
		get_tree().process_frame.disconnect(_on_tree_frame)
	# A guest still here when its host closes gets its line too.
	for id: int in _peers.keys():
		_farewell(id, _peers[id])
	if _peer != null:
		_peer.close()
		_peer = null
	if _net_peer != null:
		_net_peer.close()
		_net_peer = null
	_net_closing_at = 0.0
	if _api != null:
		_api.multiplayer_peer = null
	_peers.clear()
	_addresses.clear()
	_via.clear()
	_hanging_up.clear()
	_host_id = 0
	# A call by invite still resolving, or taking its second look, stops here.
	if _resolving >= 0:
		IP.erase_resolve_item(_resolving)
		_resolving = -1
	_end_diagnosis()
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
	_out_pond_seq = 0
	_in_pond = false
	_out_of_water = false
	_heartbeat_at = _now()
	_reach_at = _now()
	heard.clear()
	pond_events.clear()
	inbox.clear()
	_pond_bytes = 0
	_inbox_load.clear()
	# **The door's memory belongs to one socket** (A.5): every address, bucket,
	# bar and held-back line, gone with it -- which is also what keeps the many
	# hosts `tools/net_probe.gd` opens on one loopback address independent.
	_book.clear()
	_net_book.clear()
	_addresses.clear()
	_notes.clear()
	_calls_all = Bucket.new(CALLS_ALL_RATE, CALLS_ALL_BURST, _now())
	_net_calls_all = Bucket.new(CALLS_ALL_RATE, CALLS_ALL_BURST, _now())
	_frame_at = _now()
	_saturation_from = _now()
	trouble = ""
	because = ""
	trouble_key = &""
	refused_for = -1
	# **Nothing of the last call's invite outlives it**, nor the last host's.
	_invite = {}
	_proved = false
	_dialed = ""
	_invites = {}
	_decoy_secret = _crypto.generate_random_bytes(Invite.SECRET_SIZE)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
