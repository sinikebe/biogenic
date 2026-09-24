# Net hardening: limits, a referee, and what an open port needs

This plan covers issues #56, #57, #58 and #59. It has three parts:

- **A** is one PR for #58 and #56 (frames, budgets, admission). **Built.** This part now describes what was built on `main` at `956d586`, the measurements it rests on, and each place the build differs from the plan and why.
- **B** is one PR for #57 (the host checks what a guest says). Still a plan.
- **C** sets out the options for #59 and builds none of them. Still a plan.

Parts B and C were written against `main` at `d84bfb6`, and their line numbers (`pond.gd:198`, `net_session.gd:725` and so on) are that commit's. Part A names functions instead, because they outlive a line number.

The order is A, then B, then C. A carries a guard that makes "LAN-only for now" true in the code.

## 0. Rules this plan follows

- **Content only.** Every change is GDScript, so no `binary_version` bump. The two ideas that would force one (scanning a code with the camera, a native crypto library) are rejected in C.2.
- **No PROTOCOL bump in A or B.** The only new wire value is one refusal reason, `REFUSE_BROKEN`, and every protocol-4 build shows a reason it does not know generically, as "refused" over "the other end hung up" (`Wire.reason_says`, and `_take_refuse`'s last branch). That was checked in the code of all four protocol-4 releases, +104 to +107, and run against a hardened host (A.7).
- **Nothing personal.** Addresses here are documentation ranges (RFC 5737: 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24; RFC 3849 for IPv6: 2001:db8::/32). Keys, invites and server addresses live in `user://` on the device that needs them. A caller's real address appears only in a server's log, which is not the repository.
- **The launcher is not ours.** Nothing here touches `addons/launcher/` or `ci/`.
- **Run it, do not guess.** Every number is derived from a constant in main or a line in 4.7-stable. Where reading the source is not enough, the item is marked **measure first** (A.9, C.3).
- **Two guests.** Everything per guest is keyed by peer id, so the dedicated server's two guests are independent: each has its own budgets, its own ledger and its own share of the event queue.

## 1. How an inbound datagram reached our code before A

This was the path on a host, and what ran before any of our code saw the bytes. Line numbers are `d84bfb6`'s.

| # | Layer | What it does with an untrusted datagram | 4.7-stable / main source |
|---|---|---|---|
| 1 | ENet (`enet_host_service`) | Takes a slot on the first CONNECT from any source, spoofed or not, before any check. Holds a half-open slot until its resend timeout (5-30 s by default). Reads at most 256 datagrams per call. Reassembles fragments up to 32 MiB per packet, allocating the declared total on the first fragment, and holds up to 32 MiB waiting per peer. None of these limits can be set from GDScript, nor can ENet's per-address `duplicatePeers` limit or its `intercept` hook. | thirdparty/enet/protocol.c:310-340, :1374-1376, :1235, :622; peer.c:956, :992; host.c:103-105; enet/enet.h:219-238, :352, :403-408 |
| 2 | `ENetMultiplayerPeer.poll()` | Resets a CONNECT whose connect data (the id the client chose) is below 2 or already taken. Otherwise emits `peer_connected(id)`. Every received packet goes into an unbounded `incoming_packets` list. | modules/enet/enet_multiplayer_peer.cpp:198-231, :132-146 |
| 3 | `SceneMultiplayer.poll()`, run by `SceneTree.process` for every custom API at the start of each frame | Admits every peer at once, because no `auth_callback` is set. Drains every packet. Runs the non-RAW commands itself, in C++: RPC, path cache, spawn, sync, relay. `SIMPLIFY_PATH` inserts one cache entry per new id and answers each with a reliable CONFIRM_PATH, for any connected peer, whether or not it has said hello. Only `NETWORK_COMMAND_RAW` (byte 3) reaches GDScript, as `peer_packet`, with that byte removed. | modules/multiplayer/scene_multiplayer.cpp:67-167, :215-251, :357-395; scene_multiplayer.h:69-76; scene_cache_interface.cpp:98-140; scene/main/scene_tree.cpp:706-711 |
| 4 | net_session.gd `_on_peer_packet` (:725) | Our first line. It stamps `heard` (:727-728) before looking at the frame, then dispatches on byte 0. STATE, EVENT and POND are ignored before the handshake but never punished. Nothing checks a size. | net_session.gd:725-753 |
| 5 | `_take_event` (:921), `_take_pond` (:879) | `_take_event` appends the raw frame (any size, any type) to `pond_events`: 512 frames, no byte cap (:145, :934-936). `_take_pond` stores a raw frame of any size in `peer["pond"]`, **on the host as well**, where nothing ever reads it (:886). | net_session.gd:879-943 |
| 6 | pond.gd `_step_host` (:180) → `_host_hears` (:198) | The first place a malformed event is recognised: `Wire.take_*` refuses it one frame later, and nothing is logged. | pond.gd:174-232 |

So the real boundary was layer 4, and three layers ran before it. Layer 1's cost has been measured (multiplayer.md §3, point 6): 24 MiB from one peer that never said hello, 32 MiB per peer at most, and "the only lever is keeping max_clients small".

**After A, on a host**, layer 3 is gone, and layers 4-6 are one gate that every datagram passes before anything else reads it. A guest keeps SceneMultiplayer and gets the same gate, lenient.

## A. #58 and #56 in one PR: frames, budgets, admission

There is no client change a player can see. A hardened host and an unhardened protocol-4 guest play exactly as before, and so does the reverse pairing (A.7, measured). There is no PROTOCOL bump.

The files: `game/net/net_session.gd` (the boundary, the gate, the budgets, the door, the log), `game/net/wire.gd` (sizes and `REFUSE_BROKEN`), `game/net/lan.gd` (the LAN-only guard), and `tools/net_probe.gd` (the `limits` section, and one assertion each at the end of the pond and server sections). `game/normal/` is untouched.

### A.1 The host takes over the boundary

**Built as recommended: the host no longer uses SceneMultiplayer, and reads its `ENetMultiplayerPeer` directly.**

**Measured first**, as A.9 asked: the route change alone, with no gate, against the whole of `tools/net_probe.gd`, three runs against a baseline on unchanged main. All 214 checks passed in all three. `_check_link`'s timing checks did not move: 45 distinct places landed in 2.2 s (45 on main), a body moving as it said sent 44 frames (44), the 2 Hz beat went 0 to 3 (0 to 3), and a dash was drawn 13.8-13.9 ms after it started (13.9). The pond section's quiet host held the guest at 1.207-1.214 s of silence (1.208) and resumed 2 frames after the host did (2). So there was no measured reason for the fallback, and the fallback would have kept one engine error print per bogus command, which GDScript cannot rate-limit.

What changed, in `net_session.gd`:

- **`host()`** creates the server with the slot count from A.5 (`_slots()`) and connects the peer's own `peer_connected` and `peer_disconnected`. It never sets `_api.multiplayer_peer`, so SceneTree polls an API with no peer, which costs nothing and prints nothing.
- **`_pump()`** reads the socket once a frame: `poll()`, then every waiting packet through `get_packet_peer()` and `get_packet()` into **`_take_datagram(id, bytes)`**. The loop stops if a handler closes the session mid-way.
- **`_take_datagram`** drops a datagram from an id it does not have and counts it (`strays`). Then, before copying anything out, a datagram over the cap is the oversize cut (A.4). Then byte 0 must be `RAW` (3, SceneMultiplayer's `NETWORK_COMMAND_RAW` with no flag bits, which is what a protocol-4 guest's `send_bytes` writes) with at least one byte after it. Anything else is a command SceneMultiplayer would have run: before the handshake that is the pre-handshake cut, after it a malformed strike. Otherwise the byte is taken off and the frame goes to `_on_peer_packet`.
- **`_to()`** on a host writes `[RAW] + frame` itself, with `set_target_peer(id)`, `transfer_channel = 0`, `transfer_mode = _mode_for(frame)` and `put_packet()`, which flushes. These are the bytes, channel and mode `send_bytes` produced, so no guest can tell the difference.
- **`my_id()`** and the welcome read the host's id from the transport.
- **The socket is read when SceneTree used to read it.** `_pump()` runs from SceneTree's `process_frame` signal (`_on_tree_frame`, connected by `host()`, and again by `_enter_tree()` if a hosting session is ever moved to another parent -- measured: without that, a moved host heard nothing and said nothing), which SceneTree emits straight after polling every MultiplayerAPI and before any node's `_process`, paused or not. So a guest's frames land at the same point in the frame as before A, wherever the session is parented and whatever its priority, and a host whose session has its processing stopped still reads its socket, as it did.
- **That placement was measured, not assumed.** An earlier version of this change pumped at the top of the session's own `_process`. On the dedicated server the session is a child of the server's node, and a parent processes before its child (measured), so it needed a `process_priority` to keep the pond from reading every guest a frame late -- and it still read after `process_frame`, where it never had. The probe showed the difference: the moment its server section poses a hunter fell about 50 ms before a server heartbeat in 44 of 62 runs of that section, against 6 of 63 on `956d586`. Pumping on `process_frame` put it back: 3 of 24 runs in a scratch copy, and 1 of 24 on the build as it stands. That moment matters to one existing check (A.7).

**The two rules held.** The gate is the first statement of `_on_peer_packet`, so `tools/net_lag.gd`'s delayed frames, which it hands straight to `_on_peer_packet`, are gated too. And no budget or strike bookkeeping is in `_take_state` or `_take_event`: net_probe still drives `_take_state` with a hand-made dictionary. `_take_event` keeps only the queue caps (A.4), where the old frame cap already was.

`_steady_throttle` (issue #61) is still the first statement of `_on_peer_connected`, for every peer on both sides, a caller about to be refused included. The probe's throttle checks still pass.

### A.2 The gate, step by step

`_admit_frame(id, frame) -> bool` is the first statement of `_on_peer_packet`. The first failed step ends it, and no byte past a size already checked is read.

1. **Known peer.** An id not in `_peers` (refused, cut, or never admitted) is dropped without a log line.
2. **Size cap by direction**, before any byte after byte 0: a guest's frame may be 272 bytes (`Wire.GUEST_FRAME_MAX`, the longest PERSON), a host's 1,262 (`Wire.HOST_FRAME_MAX`, `POND_MAX`). Above it, a host cuts the guest at once and bars its address, with no strike count; a guest drops the frame. An empty frame is malformed.
3. **Before the handshake (host only):** a peer not yet greeted may send one thing, a HELLO of 3 to 64 bytes. Anything else is cut at once. A guest stays lenient: the host's first STATE can overtake its WELCOME, and is simply not read yet, as before.
4. **Kind and direction.** An event shorter than its six-byte header is malformed. A kind or event type this protocol knows, arriving from the side that never sends it, is malformed: a guest's POND, GENOME, CONTACT, ARRIVE, WELCOME or REFUSE; a host's HELLO, ENTER or SISTER.
5. **Size** for the kind and type (A.3). Outside it, malformed.
   - **Added: a second HELLO** from a guest already greeted is malformed. Before, `_take_hello` would have answered it with "already two" and refused a guest that was already playing.
6. **Budgets**, per peer (A.4): frames, then bytes, then, for an event, events. Every frame that got this far is charged, a later build's unknown one included; a malformed frame was struck at step 4 or 5 and is not.
7. **Unknown kind or event type** (the plan's step 8, moved ahead of parsing because an unknown frame cannot be parsed): a later build's extension, which the wire promises to ignore. Dropped after the budgets have paid for it, with no strike. **Added:** an unknown *event* still moves the peer's event sequence on, so the next known event is not reported as a gap.
8. **Parse or reject (host only),** with the readers pond.gd uses: `take_shout`, `take_enter`, `take_person`, `take_died`, `take_sister`. A STATE with `STATE_ALIVE` set must decode through `state_body`; before, one carrying a NaN cleared the friend's track as if they had died. Reserved flag bits stay ignored. A guest does not parse here: pond.gd already does, and a guest punishes nothing.
9. **Accept.** `heard` is stamped now, and only now, so junk cannot keep a peer looking fresh. The existing `_take_*` then run unchanged, and `_take_event` only ever queues a frame that is known, sized and, on a host, parsed.

### A.3 Frame sizes, derived from wire.gd

Sizes are the frame as `_on_peer_packet` sees it; ENet carries one more byte, the RAW command. They are constants in `wire.gd` (`HANDSHAKE_MAX`, `TIERS_MAX`, `ORDER_BYTES_MAX`, `PERSON_MIN`/`MAX`, `GENOME_MIN`/`MAX`, `CONTACT_MAX`, `SISTER_MIN`/`MAX`, `GUEST_FRAME_MAX`, `HOST_FRAME_MAX`), read by `Wire.size_ok(kind, type, size, from_host)` and `Wire.known(kind, type)` beside the readers. The table and the code are one thing: the probe (T1) builds every kind at its smallest and largest with the writers, checks each is exactly a bound, and checks one byte either side and the wrong direction are refused.

| Frame | Direction | Bytes | Where the number comes from |
|---|---|---|---|
| HELLO 0x01 | guest→host | 3 (accepted: 3-64) | `HELLO_SIZE`. The 3-byte prefix is frozen, and a later protocol may add a tail (shared-pond.md §7 plans the ladder hash "on the HELLO and WELCOME tails"). So the host reads the prefix of anything up to 64 bytes and, as before, refuses a different protocol with the sentence. |
| WELCOME 0x02 | host→guest | 7 (accepted: 7-64) | `WELCOME_SIZE` |
| REFUSE 0x03 | host→guest | 4 (accepted: 4-64) | `REFUSE_SIZE` |
| STATE 0x04 | both | exactly 31 | `STATE_SIZE` |
| EVENT SHOUT 0x01 | both | exactly 22 | `SHOUT_SIZE` |
| EVENT ENTER 0x02 | guest→host | exactly 10 | `ENTER_SIZE` |
| EVENT ARRIVE 0x03 | host→guest | exactly 15 | `ARRIVE_SIZE` |
| EVENT PERSON 0x04 | both | 9-272 | 6 header + 1 new-body byte + tiers (at most 1 + 8 × (1+16+1) = 145, `TIERS_MAX`) + order (at most 1 + 7 × (1+16) = 120, `ORDER_BYTES_MAX`). Today's longest gene name has 10 letters, so a real PERSON is at most 182 bytes; the cap follows the format, because an unknown name is legal and inert. |
| EVENT GENOME 0x05 | host→guest | 11-155 | 6 + 4 + tiers |
| EVENT CONTACT 0x06 | host→guest | 20-37 | `CONTACT_SIZE` 20; ATE adds 1 + 0-16 bytes, KILLED adds 1 |
| EVENT DIED 0x07 | both | exactly 16 | `DIED_SIZE` |
| EVENT SISTER 0x08 | guest→host | 20-164 | 6 + 13 + tiers |
| POND 0x06 | host→guest | 8-1,262 | `POND_MAX` = 8 + 68 × 18 + 30 |
| unknown kind or type | either | within the direction cap | dropped (A.2, step 7) |

### A.4 Budgets, strikes and cuts

**The legitimate rates, from the code:**

- **STATE.** 20 a second while a body moves (`STATE_PERIOD`) and 2 a second while nothing does (`HEARTBEAT`). Extra frames go out early whenever the far picture would stray, but never closer together than `EARLY_GAP` of 12 ms, and at most one per reported display frame.
  - That caps STATE at 83 a second, and it is reached only by a body knocked every frame (`bump`, cell.gd) at about 80 frames a second: at 90-120 Hz the 12 ms gap lets only every other frame send, and a 60 Hz phone tops out at 60. Measured (A.7): at most 55 sent in a second at 120 fps, and 80 at 80.
- **Guest events.**
  - SHOUT: once per `ping_period` (8.8, 12.0 or 15.2 s), plus one per new body.
  - ENTER: at most one per `REACH_TIMEOUT` of 4 s, on a retry.
  - PERSON: on a new body, on the gift, and when growth widens the layout.
  - SISTER: once per division. DIED: once per life.
  - Bursts are two or three frames (PERSON+ENTER, or SISTER+PERSON). net_probe's `_check_link` sends one shout and then three in a row.
- **Host to guest.** The same STATE rates, and a POND with every host state frame (at most 25 KB/s, shared-pond.md §2). On every ENTER the host sends an ARRIVE, a PERSON and up to 68 GENOMEs at once.

**What the host accepts from each guest** (`FRAMES_*`, `EVENTS_*`, `BYTES_*`, `QUEUE_*` in `net_session.gd`):

| Budget | Refill | Burst | Legitimate worst case | When exceeded |
|---|---|---|---|---|
| frames | 120/s | 240 | 83/s | Frame dropped; a STATE is superseded 50 ms later anyway. Every 120 dropped inside one second is a flood strike (6 points). |
| events | 5/s | 20 | about 1/s, bursts of 4 | Dropped, 2 points. Dropping a reliable event causes a desync, which is acceptable only for a peer about to be cut. |
| bytes | 16 KB/s | 32 KB | about 3.5 KB/s (83 × 32 B + events) | Dropped, 6 points |
| queued events | n/a | 64 frames and 16 KB | a few frames per host frame | Oldest dropped, as the old cap did: a full queue means no run is draining it. Per guest: a phone host's `pond_events`, and a dedicated host's `inbox` counted by sender, so one guest over its share loses its own oldest event and never the other guest's. |

**What a guest accepts from its host.** Sanity limits only; a guest never cuts its host. Frames 600/s with a burst of 1,200; events 200/s with a burst of 400; bytes 256 KB/s with a burst of 512 KB. All sit above POND's worst case (1,262 B × 83/s) and the 70-frame burst that follows an ENTER.

- **Changed: a guest's own event queue keeps 512 frames, and gains a 128 KB weight cap** (`POND_EVENTS_MAX`, `POND_EVENTS_BYTES`). The plan's 64 frames and 16 KB are what a host accepts from a guest; applied to what a guest queues from its host, they would drop the ARRIVE out of the front of the seventy events that answer every ENTER, and the guest would never arrive.

**A host stall is not a flood.** A phone host that stalls gets the whole stall's frames at once. Software GL at 2400x1080 has taken over 100 ms a frame.

- Every bucket refills on wall time.
- When the session's own frame gap exceeds 0.25 s (`STALL_GAP`), every bucket of every peer is topped up once in that frame: `tokens = max(tokens, rate × gap)`, uncapped by the burst.
- **Added:** the gap counted is at most 10 s (`STALL_CREDIT`). A peer silent for longer than that is past ENet's own timeout, and an unbounded credit would be one a flood could spend for as long as it lasted.
- An overfull bucket is spent down, not trimmed back, so the backlog the stall delivered is what the credit pays for.
- The reverse direction does not pile up. Once the host has been quiet for `PEER_FRESH` (1.2 s), the guest's run is held (shared-pond.md §1.8), and a held body beats at 2 Hz.

**The strike ledger, per peer** (`Guard`). Points decay at 1 a second, and a peer is cut at 10.

| Offence | Consequence |
|---|---|
| frame over the direction cap (A.2, step 2) | cut at once and barred, bypassing the ledger: this is how memory gets allocated |
| anything other than a well-formed HELLO before the handshake | cut at once, **not** barred (A.5) |
| non-RAW first byte (A.1), known kind in the wrong direction, size out of range, a second HELLO, parse refused | 4 points, counted on every frame |
| flood (every 120 frames over the frame budget inside one second), byte budget | 6 points |
| event budget | 2 points |
| unknown kind or type | 0 points (counts against the budgets only) |
| referee violations from part B | 1-4 points, each rule counted at most once per 0.5 s (B.2) |

In practice, two malformed frames leave a peer connected, and three within two seconds cut it. A peer on the same protocol never sends one, because the writers never write what the readers refuse (wire.gd). **The flood rule was sharpened in the build**: "more than 120 dropped in any 1 s window" read as one strike per window would never cut a one-second burst, so it is one strike for every 120 dropped inside a window. A burst of thousands cuts at once; a steady overrun of 130 frames a second cuts in about two.

**How a cut happens** (`_cut`):

1. A greeted peer cut by its ledger is sent `REFUSE` with a new reason, `REFUSE_BROKEN := 0x04`.
2. It is removed from `_peers` at once, so none of its later frames are read (they are counted as `strays`).
3. After `REFUSE_LINGER` it is cut with `get_peer(id).peer_disconnect_now()` (`_drop_now`).

`peer_disconnect_now` replaces the old `disconnect_peer(id, false)`. That call is graceful: it waits for an acknowledgement a hostile peer never sends, and holds the ENet slot until ENet times it out. `peer_disconnect_now` frees the slot at once, and the next poll emits `peer_disconnected`.

Oversize and pre-handshake cuts skip the refusal. The handshake's own refusals (`REFUSE_PROTOCOL`, `REFUSE_FULL`, and `REFUSE_SILENT` at `HELLO_GRACE`) keep their sentences and linger, and end with the same hard cut. A protocol-4 guest from before this shows reason 0x04 as "refused / the other end hung up"; a new one reads "cut off: the other end could not read what this game sent. take the update from the launcher on both, and call again."

A host whose last greeted guest is cut, or leaves, goes back to listening. **Changed:** that now counts greeted guests, not transports, so a caller still saying hello cannot keep a host reading TOGETHER after its guest has gone.

### A.5 Admission

**What 4.7 exposes to GDScript, and what it does not:**

- **The address.** `ENetPacketPeer.get_remote_address()` and `get_remote_port()`, reached through `ENetMultiplayerPeer.get_peer(id)` from inside `peer_connected`. Measured: it is a `String`, dotted for an IPv4 caller even on the host's dual-stack socket; an IPv6 one prints as eight hex groups (`IPAddress`'s own `String` form).
- **No way to refuse early, per address.**
  - ENet's `intercept` hook and its `duplicatePeers` limit exist in the C struct, but Godot never sets or exposes them (enet.h:352, :403-406; host.c:103; no reference in modules/enet).
  - `ENetConnection.refuse_new_connections()` does nothing on a plain UDP host: it only reaches the DTLS server socket.
  - `MultiplayerPeer.refuse_new_connections` resets every new peer after ENet's handshake, all or nothing.
- **So the earliest per-address decision is inside `peer_connected`**, and the refusal is `peer_disconnect_now()` within that same poll. It was **measured** safe with packets already queued (A.9), and T6 keeps it as a regression check.

**The limits** (`_admit`), checked in `_on_peer_connected` before any bookkeeping is created, in an order chosen so that a caller who is barred or not on this network spends nobody else's budget:

| Limit | Phone host | Server | Why |
|---|---|---|---|
| **LAN-only guard:** the source must be loopback, RFC 1918, 100.64/10, 169.254/16, the host's own /24, or IPv6 loopback, ULA or link-local | on | on, until #59's listener exists | Makes "LAN-only for now" true in code. A forwarded port, or a public IPv6 address the router lets through, hits the guard and is refused with one log line. The host binds the wildcard address, so IPv6 is otherwise open wherever a router allows inbound IPv6. 100.64/10 is allowed because lan.gd counts carrier-grade-NAT Wi-Fi as a home network, and it is also Tailscale's range (C1). The own-/24 rule is there because this container's own address is 192.0.2.2. `Lan.is_local_source(address, own)`. |
| ENet slots (`create_server`) | 4 | 6 | `_slots()` = one per guest, the two pending callers, and one half-dead predecessor per guest. Each slot can hold up to 32 MiB of ENet buffering, so no more than this. (The server had 5 before.) |
| greeted guests | 1 | 2 | Beyond this, REFUSE_FULL with its sentence, as before |
| pending (not greeted) | 2 | 2 | A third is cut on arrival (`PENDING_MAX`) |
| handshake grace | 3 s | 3 s | `HELLO_GRACE`, unchanged; a real guest's first frame is its HELLO |
| new connections per address | 1 per 3 s, **burst 8** | same | `CALLS_*`. See below. |
| transports per address | 3 | 3 | Two friends on one NAT, plus a retry (`LIVE_PER_ADDRESS`) |
| new connections, all addresses | 10/s | 10/s | Bounds the cost of a storm from many addresses |
| bars | 60 s after an abuse cut; 10 min for a second one within 10 min | same | Silence, protocol refusals and "already two" are not abuse. Nor, **changed**, is speaking before the handshake (below). |
| address book | 1,024 entries; idle entries dropped after 10 min | same | The limiter's own memory is bounded. A full book forgets an idle caller, then the one heard from longest ago, and a barred one only if every entry is barred. |

IPv6 callers are keyed by their /64 (`Lan.source_key`). The address book, the buckets, the bars and the log limiter belong to each `host()` call and are cleared by `_reset_socket`. That is also what keeps net_probe's many loopback hosts independent of each other.

**Where the build differs, and why:**

- **The per-address burst is 8, not 4.** The probe's existing server section calls six times from one loopback address in about six seconds (two guests, a third refused "already two", a fourth after one leaves, and two more at the end). With a burst of 4 and one call every 3 s it passed or failed on the runner's speed: it needed about 1.7 tokens for the last pair, and got them only if the section took long enough. A burst of 8 covers the section with no refill at all. What it costs is four more calls in a burst from one LAN address, each of which still meets the pending cap, the transport cap and the grace timer.
- **Speaking before the handshake is a cut, not a bar.** A port scanner or a confused non-Biogenic client does exactly that, the pending cap and the per-address bucket already bound its cost, and T6 needs a real guest from the same address to join straight after. An oversize frame and a ledger cut do bar.
- **`Lan.is_local_source()` sits beside `_range_rank`, not `_is_private`.** #62 replaced `_is_private` with `_range_rank`, which ranks addresses and refuses none; the guard refuses and ranks none, and its comment says so. It parses IPv6 itself: compressed or in Godot's eight-group form, with a zone or a dotted IPv4 tail, and an IPv4-mapped address is judged as the IPv4 it is.

### A.6 Telemetry

All of it goes through one helper, `_note(what, key, line)`. It prints at most one line per (what, address) every 10 s (`NOTE_EVERY`), and the next line says how many like it were held back. **Added:** a refusal that is about everybody -- a caller from outside the network, or the door taking no calls from anywhere -- is keyed by its reason instead of its address, so a storm from a thousand addresses is one line every 10 s, and the helper only ever remembers callers the door let near it. Its own memory is bounded.

- **The existing warnings go through it too:** the event gap, a failed send and a mismatched host id. Each was otherwise one line per frame, at a rate an attacker chooses. They stay warnings.
- **Lines, all starting `[net]`:**
  - a refused connection, with its reason: not on this network, barred, too many calls from everywhere, calling too often, too many transports from there, too many callers saying hello;
  - a cut: oversize, before its hello, malformed, flood, bytes, events, with the points and how long the address is barred;
  - a strike that crosses half the threshold;
  - **added:** the handshake's own refusals (different versions, already two, no greeting), because a server's operator wants to see those as much as the rest;
  - **saturation.** Once a second the host reads `HOST_TOTAL_RECEIVED_DATA` and `HOST_TOTAL_RECEIVED_PACKETS` from its `ENetConnection` (`pop_statistic`). These count everything ENet read, including what never reached the gate. A line is printed above 64 KB/s or 2,000 datagrams/s; two real guests send about 7 KB/s and 170 datagrams/s.
- **Counts for tools**: `gate_counts` on the session holds every refusal by reason, every cut, bar, strike and drop, the strays, and the busiest second's arrivals. It is reset by `host()` and `join()` and kept after `close()`, so a tool can read a session's last word; `points_of(id)` reads a peer's ledger.

Examples, using documentation addresses:

```
[net] refused 203.0.113.9: not on this network (LAN-only until #59)
[net] hung up on 1587052382 (192.0.2.40): different versions
[net] cut 694971552 (192.0.2.10): flooding: 241 frames over its budget in a second (120 a second, 240 at once) -- 12 points -- barred 60 s
[net] saturated: 1843.2 KB a second in 21400 datagrams arriving at the socket (+37 like it held back)
```

A peer's address may appear in the server's log: the log is not the repo.

### A.7 What this could break, measured

**A phone-hosted pond and the dedicated server: nothing, measured.**

The relay harness from #61 (`relay2.py`) sits between each guest and its host and holds every datagram for 5-40 ms, one in twenty for 150-250 ms more, in order, so a spike holds everything behind it the way Wi-Fi does; with `--loss 0.02` it drops one in fifty. Each run is real ENet on real sockets, two or three processes, real runs of the game with bodies swimming on their own impulses, 100 s requested (about 110 s measured). A scratch harness samples every peer's buckets, counters and ledger every frame. In **every run, every process's gate stayed at zero**: no strike, no dropped frame, no cut, no refusal, no queue overflow, not one stray.

| Run | Link | Frames from each guest: peak in 1 s (share of 120/s), in 0.1 s, deepest draw on the burst of 240 | Bytes: peak in 1 s (share of 16 KB/s), deepest draw | Events: peak in 1 s, deepest draw on the burst of 20 |
|---|---|---|---|---|
| phone host and guest | jitter | 27 (23%), 8, 6 (2.5%) | 890 B (5.4%), 0.6% | 2, 2 (10%) |
| phone host and guest | jitter, 2% loss (63 up, 99 down lost) | 26 (22%), 7, 6 (2.5%) | 812 B (5.0%), 0.6% | 2, 2 (10%) |
| server and two guests | jitter | 27 and 26 (23%), 8, 7 (2.9%) | 888 B (5.4%), 0.7% | 2, 2 (10%) |
| server and two guests | jitter, 2% loss (113 up, 110 down lost) | 26 and 26 (22%), 8, 6 (2.5%) | 859 B (5.2%), 0.6% | 2, 2 (10%) |
| phone host and guest, the guest at 120 fps and knocked every frame | jitter, 2% loss | 64 (53%), 20, 16 (6.6%) | 1,984 B (12.1%), 1.5% | 2, 2 (10%) |
| server and two guests, both at 120 fps and knocked every frame; one died and came back | jitter, 2% loss | 68 and 68 (57%), 21, 15 (6.2%) | 2,108 B (12.9%), 1.4% | **4** and 2, 3 (15%) |
| phone host and guest, the guest at 80 fps with its velocity thrown every frame: the ceiling, 57-80 state frames sent a second | jitter, 2% loss | **96** (80%), 26, 22 (9.2%) | 2,976 B (18.2%), 2.1% | 2, 2 (10%) |

What a guest takes from its host peaked at 87 frames a second (15% of 600), 42 events in the second after an arrival (21% of 200) and 28,210 bytes a second (11% of 256 KB), and no guest dropped anything either.

**The margins.** The most any guest sent was 80 state frames in a second, at the ceiling; the frame budget's refill of 120 is 50% above that, and 45% above the arithmetic ceiling of 83. Arriving through the relay's spikes, the busiest second held 96 -- 80% of the refill -- because a spike releases everything it held at once, in order; that is what the burst is for, and the deepest any run drew it was 22 of 240 (9.2%). The byte budget is five and a half times the most measured, and its burst was never drawn past 2.1%. The event budget is the one that comes closest: the guest that died and came back sent four events inside one second (80% of the refill), around its death and its return from the black -- the harness taps to come back at once, which packs them closer than a player would -- and drew the burst to 3 of 20. A run of the earlier version of this change, whose guest side is the same, caught a death and return sending five in one second, the refill rate exactly, again drawing the burst to 3. The bucket allows 25 in any one second, five times the most seen; five a second over any longer window never happened.

**Old and new builds together.** "Old" is main at `956d586` (+107), the newest protocol-4 release, run from a scratch copy.

Each through the same relay (default jitter), real runs in the pond:

| Pairing | Joined, in the pond | Frames delivered | The new build's gate |
|---|---|---|---|
| old guest, new phone host (90 s) | 0.15 s, 0.40 s | the guest got every state frame and snapshot the host sent (1,993 and 2,007) | host: clean for 102 s |
| new guest, old phone host (90 s) | 0.17 s, 0.43 s | every one, both ways | guest: clean for 98 s |
| two old guests, new dedicated server (90 s) | 0.17 and 0.32 s, 0.47 and 0.86 s | every one | server: clean for 104 s, both guests |
| a +104 guest, the oldest protocol-4 release, new phone host (60 s) | 0.15 s, 0.41 s | every one (1,380 and 1,389) | host: clean for 72 s |

And **an old guest cut with `REFUSE_BROKEN`**: +107 and +104 guests joined a hardened host on loopback and sent three nine-gene PERSONs. Each was cut at the third (12 points), went to `REFUSED` reading "refused" over "the other end hung up.", kept running, and closed cleanly. A reason it does not know is a sentence it already has, as every protocol-4 build's `_take_refuse` promised.

And **the exported server**: this tree's Linux Server export, the binary CI builds, took two new guests through the relay for 60 s -- every frame delivered, both guests' gates clean, not one `[net]` line -- and then cut a +107 guest the same way, saying so in two `[net]` lines: one as it crossed 8 of 10 points, one for the cut.

**Existing net_probe checks: none changed, and all pass.** The pond section and the server section each gained one assertion at their end: across every session in them, the gate struck nothing, dropped nothing, cut nothing and refused nobody at the door.

- `_check_link` sends four shouts in bursts; they fit the event budget, and the gate checks sizes and finiteness, not radii.
- `_check_skew`: every HELLO is 3 bytes; protocols 1, 2, 3 and 5 are still refused with the sentence; `peer_count() == 0` still holds, because `_refuse` removes the peer at once.
- The hand-made `bench` dictionaries still work, because the accounting is outside `_take_state`.
- `_check_run` sends shouts from host to guest, into a run on the guest, which exercises the guest-side budget.
- `_check_pond`: the genome burst after ENTER reaches the guest. Both "host stopped" stages pass unchanged.
- **`_check_server`'s hunter check has a race of its own, on `956d586` as well.** "A hunter on the guest in slot 69 is that guest's hunter, and the other guest, who is sent the same body, sees no hunter" reads the first guest's water in the frame the second guest sees the hunter. But each guest gets its snapshot on its own 50 ms schedule (`_flush_guest`), so after a guest returns from the black the first can be a snapshot behind the second, and the check then fails with the body not yet sent. Only the server's heartbeat, every 0.5 s, puts the two schedules back in step, and the check passes when the hunter is posed just before one. Instrumented, 956d586 posed it with the first guest's snapshot due later than the second's in 4 of 63 runs, every time just before a heartbeat. The earlier version's pump moved the pose off the heartbeat in most runs (A.1), and one full probe run failed on it; the build as it stands poses it where 956d586 does. The check is left as it is, because this change touches no existing check; waiting until both guests have the body before comparing them would close the race.

**CI's frame budget.** The whole probe now finishes in 8,275-8,600 frames and 69-72 s (six runs of the build as it stands), against 6,643 frames and 53.6 s on `956d586`. The `limits` section is 1,592-1,897 frames and 16-19 s of that, at 100 frames a second; what varies is how long ENet keeps retrying the callers T8 turns away. The backstop is 20,000 frames, so the margin is still better than two to one. The comment on ci.yml's LAN step still says "about fifty-five seconds", "about 6,700" frames and "two SceneMultiplayer instances"; `.github/workflows/` is not this change's to edit, so those three are left for whoever next touches the workflow.

### A.8 net_probe: the `limits` section

`_check_limits()` runs right after `_check_skew`, at 100 frames a second (`LIMITS_FPS`; nothing in it is finer than a tenth of a second). Each test gets a host of its own, so one test's bars and buckets never leak into the next. The hostile peers are either a real guest's session made to send what no writer produces (through its `_to`), or a `Rogue`: a bare `ENetMultiplayerPeer` client that writes any first byte, any size, any kind, and keeps everything it is sent. No test is timed against a budget a slow runner could miss: every wait ends the moment its answer is in, and what is asserted is the ledger's own arithmetic. `--limits-only` runs the section alone.

| # | Test | Result |
|---|---|---|
| T1 | **Sizes at the edge:** every kind and event type at its smallest and largest, built by the writers (a PERSON of 272 bytes: eight genes and seven slots of 16-letter names; SISTER 164, GENOME 155, CONTACT 37, POND 1,262) | Each is exactly a bound; one byte either side, or the wrong direction, is refused. Then the largest of each crosses a real socket both ways and is taken, with nothing dropped on either side. |
| T2 | **Oversized:** a 273-byte EVENT, then a 64 KiB reliable frame ENet reassembles from its fragments, from a greeted guest | Cut at once each time, no strike, nothing queued, `peer_count() == 0`. The address is barred 60 s, so a call back is cut at the door; with the bar lifted by hand, the second offence bars it for 600 s. |
| T3 | **Malformed burst:** two PERSONs with nine genes, then two more | After two: 8 points less their decay (7.99 recorded), still TOGETHER, nothing queued. After four: cut with `REFUSE_BROKEN`; the guest is `REFUSED` and reads the new sentence; the host is listening again. |
| T4 | **Wrong direction:** a POND and a GENOME from a guest | Both dropped, 4 points each. The host's `peer["pond"]` stays empty. |
| T5 | **Non-RAW command:** SIMPLIFY_PATH bytes (first byte 1) from a greeted Rogue | One malformed strike, and nothing else: every packet back starts with RAW, none is a CONFIRM_PATH. |
| T6 | **Before the handshake:** a Rogue whose first frame is a STATE; a caller that sends forty packets in the datagram that finishes its handshake, first at an open door and then at a full one; two silent Rogues | The STATE-first caller is cut in the frame it spoke, with no strike and no bar. At an open door the forty are delivered with the connection (30 besides the one that got it cut; ENet puts at most 32 commands in a datagram, so the acknowledgement and 31 packets ride together). At a full door the same caller is cut inside `peer_connected`, the host stays up, and none of the forty is delivered. The silent two get `REFUSE_SILENT` at 3 s and are cut 1.0 s later, at the end of the linger. A real guest joins straight after. |
| T7 | **Flood:** 3,000 valid STATEs in one second from a greeted guest; then a control run at 100/s for 3 s | Cut with `REFUSE_BROKEN` after about 0.2 s, with no more frames taken than 240 + 120 × t. The host's worst frame time is printed. The control run is all taken, with no strike and nothing dropped. |
| T8 | **Connect storm:** 12 silent Rogues from 127.0.0.1 in four consecutive frames; then the transport cap, on a two-guest host | Never more than 2 waiting at once. Every call is either let in to wait or cut on arrival, and the two counts add up to twelve; no more pass the address's bucket than its burst and its refill allow; both the bucket and the waiting room turn calls away (a recorded run: 2 let in, 6 cut for the waiting room, 4 for calling too often, over 1.6 s of ENet's own retries). The bucket is empty after the storm, and a real guest from the same address joins once it holds a call again. With two guests and a caller open from one address, a fourth transport from it is refused. |
| T9 | **Queue weight**, driven straight into `_take_event` so no frame is spent | A phone host keeps 60 of 100 longest PERSONs (16,320 bytes of 16,384), the newest last, and 64 of 100 ENTERs. A dedicated host holds one flooding guest to 60 and keeps both of the other guest's events, the first still first. A guest keeps 512 of 600 GENOMEs from its host. |
| T10 | **Unknown kind:** ten frames of kind 0x7E and one event of type 0x7F | Dropped, no strike, still TOGETHER, and the shout sent after them is heard. |
| T11 | **LAN-only guard:** a table of addresses, with documentation ranges standing in for public ones and a placeholder 10.0.0.5 as the host | Loopback, RFC 1918, 100.64/10, 169.254/16, the host's own /24, and IPv6 loopback, ULA and link-local are answered; public stand-ins and junk are not; an IPv6 caller is its /64. |

**Where the section differs from the plan, and why:**

- **T6 gained a control.** "None of the forty delivered" only means something next to the same caller at an open door, where they are.
- **T8 gained the per-address transport cap**, which the storm never reaches: the pending cap refuses first.
- **T9 is socket-free.** The plan's 40 largest PERSONs over 10 s cannot reach either cap within the event budget (40 × 272 = 10,880 bytes, under 16,384; 40 frames, under 64), and a run that pushes past both would take 10 s of frames. Driven straight into `_take_event`, it pushes each queue past its caps in no frames at all.

Every test prints `PASS` or `FAIL` in the house form and none causes a `SCRIPT ERROR`: the gate never reads past a size it has already checked, and ci.yml fails the step on any `SCRIPT ERROR`.

### A.9 What A cannot fix, and what was measured

- **ENet's 32 MiB per peer** (layer 1). A limits how many peers can hold it (slots), how long (grace and hard cuts) and how often (per-address rate). Only an engine change lowers the cap, and that would be a binary bump. And the gate sees an oversize frame only after ENet has reassembled it and `get_packet()` has copied it once; the copy is freed with the cut.
- **Spoofed CONNECTs hold slots** for 5-30 s without GDScript ever seeing them. Nobody spoofs on a LAN. On the internet, DTLS cookies are the fix (C).
- **ENet reads at most 256 datagrams per poll.** Anything beyond that waits in the kernel's 256 KiB buffer and is dropped there. This puts an implicit ceiling on CPU, but it also adds latency for honest frames during a flood.
- **Engine error prints** cannot be rate-limited from GDScript. This covers a failed DTLS handshake, and on guests, the SceneMultiplayer commands a hostile host could send.
- **The server's updater waits for an empty pond**, and a caller still saying hello counts (docs/server.md: "nobody connected, and nobody connecting"). A hostile device on the LAN that keeps calling can therefore hold an update back, one call every 3 s after its burst. That is the updater's definition of empty, and it is left as it is.
- **IPv6 could not be run here.** This container has no IPv6 at all, so the guard's IPv6 rules are checked on a table (T11) and against Godot's `IPAddress` string form, but no IPv6 caller has reached a host.
- **Measured on 4.7-stable in this container, 2026-09-24:**
  1. **Cutting a peer inside `peer_connected` with packets already queued is safe.** Four hostile raw `ENetConnection` clients sent 40 packets each in the same datagram as the ACK that completes the handshake. In a control run with no cut, they arrived in the same frame as the connection. With `get_peer(id).peer_disconnect_now()` inside the handler, none were delivered, `peer_disconnected` fired on the next frame, and each hostile client saw its disconnect. The server stayed up, and an ordinary client joined afterwards and exchanged 209 packets, with no error lines, through SceneMultiplayer and through the `ENetMultiplayerPeer` read directly alike. T6 keeps this as a regression check, with its own control.
  2. **`_check_link`'s timing checks with the host reading its own socket:** unchanged, three runs of three, for the route alone (A.1) and again for the build as it stands: 45 places in 2.2 s, 44 frames, a beat of 0 then 3, a dash drawn 13.8-13.9 ms after it started; the pond's quiet host held the guest at 1.207-1.216 s of silence and let it go 2 frames after it resumed.
  3. **Budgets on a real link.** Two phones on real Wi-Fi for 30 minutes remain to be run before the merge. Until then, the relay runs in A.7 stand in for them: real ENet over real sockets, through 5-40 ms of flight with 5% spikes of 150-250 ms, with and without 2% loss.

## B. #57 in one PR: the host checks what the guest says

**Still the plan, as written against `d84bfb6`.** What A left for it: the ledger B feeds is `_strike(id, weight, why)` in `net_session.gd`, which B's public `strike` wraps; the per-guest bookkeeping is keyed by peer id on both kinds of host; and T1 of the probe already holds every size bound B's checks start from.

### B.1 Where the checks live

A new file, `game/net/referee.gd`, holds them. It is RefCounted, preloaded, with no class_name, like wire.gd. There is one referee per guest, owned by pond.gd on the host.

- It holds what the host already knows about that guest.
- It answers each input with **accept**, **clamp** or **reject**, plus a strike weight. The weight goes to A's ledger through a new public `strike(id, weight, why)`.
- It holds no scene references, so net_probe can drive it without a socket, the way it already drives food.gd in `pond-field`.

Contacts are already decided by the host (shared-pond.md §1.1). B adds four more things the host can decide for itself:

- **The guest's radius.** Every meal a guest eats in the pond is one the host decided: a CONTACT ATE (pond.gd:381-388; food.gd:1799-1800, :2115, :2153). A guest's radius only grows in `_on_eaten`, by 4 units a meal up to 40 (normal_mode.gd:1379-1399; cell.gd:41, :146). So the host can compute the radius instead of trusting it.
- **The guest's genome.** The body a cell wears is fixed at birth, with one exception: the free sense, which adds one of four genes at tier 1, once (genome.gd:165-178, :496-506; food.gd:281-282). `move()` changes only the DNA (genome.gd:417-447).
- **Divisions.** A division is announced in advance: 2.4 s of quickening at radius 40, then OUT on every state frame through the pinch, the parting and the choice. The choice has no time limit (normal_mode.gd:1059-1099). The birth sends SISTER, then PERSON(new) (:1279-1281).
- **Arrivals.** The host picks the arrival point itself (`arrival_at`, pond.gd:248-250), and the guest's cell is placed there at rest (normal_mode.gd:4951-4958).

### B.2 Every guest input, checked

| Input (where the host applies it) | Trusted today | The host's check | On violation |
|---|---|---|---|
| **STATE: place and heading** (`_carry_guest`, pond.gd:310-328 → `place_person`, food.gd:3260) | Everything except finiteness and `MOTION_MAX`, 4,096 u/s (wire.gd:191-201, :712-715) | A **movement budget** on the path the guest *claims*. It refills at 1,100 u/s, holds 1.5 s of it (1,650 u), and allows 100 u of slack. Refill is uncapped across a host stall. It is anchored at ARRIVE: the first frame with the POND bit must lie within slack + 1,100 × (time since ARRIVE) of `arrival_at`. A separate heading budget refills at 1.35 rad/s and holds 1.5 rad. | The place the host *applies* moves toward the claim, no faster than the budget. 2 points, at most once per 0.5 s. The next frame is measured from the claim, not from the clamped place, so one false positive cannot snowball. |
| **STATE: velocity and turning** | as above | Speed clamped to 1,100 u/s, turning to 1.5 rad/s. This matters because the host's coast can carry the person up to v/0.74 units between reports (food.gd:3801-3807). | clamp, no strike |
| **STATE: radius** | anything above 0 | Never above the host's own expectation + 0.05. The expectation starts at the ENTER radius, gains 4 per ATE the host sent (capped at 40), and becomes 28.284 after a birth. Decreases are always allowed: a daughter's STATE can overtake her SISTER, since they travel on different channels. | Clamp to the expectation; 4 points |
| **STATE: OUT flag** (dividing, which makes the person untouchable: `set_person_in_water(false)`, pond.gd:325) | anything, any time | Allowed only when the expected radius is 40. While OUT, the place is frozen (±2 u) and the velocity is zero. OUT must end in a birth, a death or a leave. | OUT is ignored (the person stays in the water), or the place is frozen; 4 points |
| **SHOUT** (the host's own membrane, `_hear_others`, normal_mode.gd:872-903) | place, radius, reach and rate | When the guest's cell is in the water: `at` within 650 u of its place (100 + 1,100 × 0.5, since the shout is reliable and the state is not); radius within the expectation; reach exactly `PING_RANGE_BY_TIER` of the worn `ampulla` (cell.gd:269). Rate: one per `ping_period` − 1 s, with two banked, **plus one after every new body or arrival**, because `_fresh_senses` zeroes the ping clock and the next pulse fires at once (food.gd:1162, :2809-2815). With no person in the water: finiteness and the rate budget only, as today. | Dropped, so nothing is heard; 1 point |
| **ENTER** (`_host_enter`, pond.gd:243-262) | Any time, any radius above 0. Every ENTER creates a fresh person (wound 0, 42 s of grace from `FIRST_DELAY`, food.gd:3272-3283), places it 480 u from the host, and makes the host send ARRIVE, PERSON and up to 68 GENOMEs. | Legal only when the host has no person for this guest, or is still waiting for the last one to arrive (pond.gd:92-93, :313-318). One per 3 s, two banked. Radius in [26, 40]; exactly 26 after a death (`_enter_from_black`, normal_mode.gd:4975). A fresh wound and grace come only with the connection's first arrival, a return after a death, or a re-entry more than 30 s after leaving. Otherwise the new body keeps the old one's wound and gets no grace. | Ignored, so no ARRIVE is sent and the guest retries after `REACH_TIMEOUT`, as it already does. 1 point, because a lost POND-bit frame can make one honest ENTER look early. |
| **PERSON** (pond.gd:200-207 → `set_person_genome` and `renew_person`, food.gd:3303, :3457) | Only the decoder's bounds: at most 8 genes, a-z names, clamped tiers, at most 7 slots. `new_body` renews at any time: wound 0, reloaded mouth and dart, 42 s of grace. | `new_body` is allowed only when the host has no person (the PERSON sent just before an ENTER, pond.gd:477-481), or at the birth that closes a division. **Otherwise the worn tiers must equal the previous ones**, except for the gift, once. Each worn gene appears once in the order, and nothing else does. The newest PERSON in a frame wins. Two a second, six banked. | A `new_body` sent out of turn is applied as `false`; an escalation keeps the old genome; 4 points |
| **SISTER** (pond.gd:212-219 → `place_sister`, food.gd:3393) | Place, radius, heading, tiers and rate are all taken as sent. A guest could fill the water with any body, anywhere. A huge radius wrecks every contact pre-check (food.gd:2320-2329). | Once per division, after OUT. Radius exactly `daughter_radius(40)` = 28.284 ± 0.05 (cell.gd:163-164; normal_mode.gd:1264, :4999). Placed on the 560-unit ring around the frozen person, ±20 (`SISTER_DISTANCE`, normal_mode.gd:182). The 560 is written out in referee.gd, because pond.gd cannot preload normal_mode (pond.gd:46-47); the probe checks the two values agree. | Out of turn: rejected, 4 points. Off the ring or the wrong size: clamped, 2 points. |
| **DIED** (pond.gd:220-230) | Cause and killer, used for the host's on-screen lines (the place is already the host's own) | Only starvation is the guest's own death: cause 3, killer 0 (normal_mode.gd:1493-1494). Any other death was decided by the host, which has already removed the person. | The person is still removed, since dying is the guest's right, but the line says "starved"; 2 points |

**The speed cap, from cell.gd's own tables**, with each organ at its fastest:

| Organ | Tier 0 / 1 / 2 / 3 (units per second) | Derived from |
|---|---|---|
| flagellum, impulses as often as allowed | 153 / 193 / 246 / 323 | `IMPULSE_SPEED_BY_TIER` / (1 − e^(−0.74 × gap_min)), cell.gd:176-178, :194 |
| axoneme, held push | 0 / 81 / 115 / 155 | `PUSH_ACCEL_BY_TIER` / 0.74 (cell.gd:302; its own comment gives 81/115/155) |
| myoneme, a dash every cooldown | 0 / 295 / 372 / 465 | `DASH_SPEED_BY_TIER` / (1 − e^(−0.74 × 1.4)), cell.gd:313-315 |
| all three at tier 3, stacked | **943** | wire.gd:191-194 says "a little under a thousand" |

The global cap is 1,100. A tighter cap per genome (the guest's own organs, plus 350 for being shoved, since a lunge is 322 per wire.gd:265) would give 543 for a newborn cell. That is the obvious next step, but it is left out of this PR: every genome change would then have to widen the cap before the body uses its new speed, which is one more thing to get wrong.

### B.3 Latency and jitter: the checks that could hurt an honest player

| Check | The risk | Why it holds |
|---|---|---|
| movement | STATE frames are unreliable and arrive in bunches after a delay, so one bunch can cover more distance than the host's clock has refilled | The bucket holds 1.5 s at 1,100 u/s, so a guest at the physical peak can have its frames delayed about 1.8 s before a clamp. A host stall refills without a cap. A guest is held after 1.2 s of a quiet host, so it cannot have moved far. |
| radius | The grown radius could seem to arrive before the ATE that caused it | The host raises its expectation when it *sends* ATE, so the guest's radius can only lag behind it. Only a radius above the expectation counts. |
| division | SISTER and PERSON(new) are reliable, but OUT rides on unreliable STATE | By the birth, OUT has been on every state frame for at least 4.4 s (pinch 1.5, part 1.0, lean 1.0, commit 0.9), about nine frames at the held body's 2 Hz. Losing all nine at 5% loss has a probability of 2 × 10^-12. |
| ENTER | If the frame clearing the POND bit is lost, a following ENTER looks like one over a live person | Only 1 point, and the guest's retry 4 s later succeeds |
| SHOUT | shouts arrive in bunches, and a new body pulses at once | two banked, plus one per new body |
| the gift | The player can hold the free sample, and the menu can be open | Not time-limited: once per body, whenever it happens |
| re-entry wound | An honest player who quits and starts a new run within 30 s, with the pond still up, arrives with the old cell's wound and no grace | Rare, stated, and the price of closing the heal-by-re-entry cheat. The owner can drop the rule if it feels wrong in play. |

**These are measured, not argued.** net_lag gains a `--swimmer=guest` option that applies its link model to the *host's* intake; today it models only the guest's (net_lag.gd:470-472). Running `--pond --swim=120 --link=rough` must end with zero referee strikes, and prints the peak share of each budget used. `rough` means 10-50 ms of flight, 5% loss, and a 5% chance of a 100-250 ms spike (net_lag.gd:37-44).

### B.4 What B changes, by function

- **`game/net/referee.gd`** (new): the state and checks above.
- **`game/net/pond.gd`:**
  - `_host_hears` (:198-232): each branch goes through the referee before touching the field. PERSON before :204 and :206; ENTER before :211; SISTER before :216; DIED before :228, with the cause clamped for :230.
  - `_host_enter` (:243-262) records the arrival after `place_person` (:250).
  - `_carry_guest` (:310-328) runs the newest track entry through `check_state` before `set_person_in_water` (:325) and `place_person` (:326-327).
  - `_drop_person` (:331-334) records a leave.
  - `_on_person_touched` (:381-388) records an ATE.
  - `_on_person_died` (:391-397) records a death.
- **`game/normal/normal_mode.gd`:** `_hear_others` (:875) asks the host's pond to check each shout before `ping_level` (:891). On the dedicated server there is no local player, so the relay to the other guest must ask the same question.
- **`game/net/net_session.gd`:** `strike(id, weight, why)` feeding A's ledger, and the guest's peer id for pond.gd.
- **`game/normal/food.gd`:** no change. The field keeps trusting what pond.gd hands it; the referee sits in front of it. The two-guest server needs one referee per person slot.

There is no wire change, so no PROTOCOL bump, and the PR is content only. B depends on A's ledger.

### B.5 net_probe

**Two parts of the existing pond section must be restaged**, because they do things no player can do:

- **A mid-life tier-3 mouth.** The probe gives the guest a tier-3 mouth mid-life and waits for the host to adopt it (net_probe.gd:2622-2628). Under B that is an escalation: the host keeps the old mouth, and "the guest swallows the host" fails. Restage it as an arrival: take the guest out of the pond, change its genome, and let it swap back in. That is how a player really brings a strong genome into the pond.
- **Radius set to 40 by hand.** The probe sets both radii to 40 to trigger a division (:2697-2698). The host never fed the guest those meals, so B clamps the radius, ignores the OUT and rejects the sister, and "each back where it left at r28.28, its sister in a free slot" fails. Either feed the guest four drifters in the host's water, or record the meals through a tools-only `referee.credit_meals(n)`. That call records what the probe skipped; it switches no check off.
- **Teleports.** The probe pins the guest 480 u into the host's mouth (:2597-2605). That fits the 1,650 u budget, because the guest was pinned still beforehand. Turn these into glides at 900 u/s anyway, so a later per-genome cap does not break them.

The pond section then asserts **zero referee strikes** at its end. That is the strongest guard against false positives available, because it is two real runs through every stage of a pond's life.

**New tests.** The pure ones go in a socket-free `_check_referee()`, like `pond-field`; the rest go inside `_check_pond`.

| # | Test | Expected result |
|---|---|---|
| R1 | a 5,000 u teleport | The applied place moves no further than the budget; 2 points. The honest frames that follow converge within about 1 s with no more strikes. |
| R2 | a cell with every organ at tier 3, driven by cell.gd's own physics for 60 s through `rough` | Zero strikes; peak budget share printed |
| R3 | 3 s of silence, then 60 frames at once | Zero strikes |
| R4 | radius 36 with no meals; then 30 after one real ATE | 36 is clamped to 26 with a strike; 30 is accepted |
| R5 | OUT at radius 30 | The person stays in the water and can still be bitten; a strike |
| R6 | a SISTER with no division; then a real division | Nothing placed and a strike; then exactly one sister on the ring at 28.284 (the existing check, now with zero strikes) |
| R7 | PERSON(new) mid-life after a bite; PERSON raising cytostome from 1 to 3; the gift sent twice | Wound and grace unchanged; the mouth stays at 1; the first gift accepted, the second refused |
| R8 | five ENTERs in one second while swimming in the pond | No ARRIVE, `genomes_sent` unchanged, wound unchanged |
| R9 | DIED (swallowed, by the friend) while still alive | Person removed; `friend_died` reports starvation |
| R10 | a shout from 3,000 u away; a shout with the wrong reach | Nothing appears on the host's membrane |
| R11 | a radius cheat on every frame | Cut within 3 s; the guest is `REFUSED` with `REFUSE_BROKEN` |

### B.6 What B does not do

- **An arriving guest's genome cannot be checked.** A guest that swaps in from solo play brings a body the host never saw grow, so a maxed genome is legal; only structural bounds apply. Having the host own each guest's lineage would be a design change, not hardening.
- **Movement stays the guest's to decide** (shared-pond.md §1.1). The host caps it at what physics allows; it does not simulate it, because that is the latency the work in #53-#55 removed.
- **The guest never learns where the host placed it.** A clamped cheater therefore plays in a water the host disagrees with. For a cheater that is the right outcome; an honest guest never gets there.

## C. #59: what opening a port needs (options only)

**Still the plan, as written against `d84bfb6`.** A's LAN-only guard (`Lan.is_local_source`, checked in `_admit`) is what C2 switches off for its DTLS listener, and nowhere else.

### C.1 What Godot 4.7 actually offers

All of this was read in 4.7-stable and the 4.7 class reference.

- **ENet over DTLS: yes.**
  - `ENetConnection.dtls_server_setup(TLSOptions)` and `dtls_client_setup(hostname, TLSOptions)` (enet_connection.cpp:277-304) exist.
  - They are called on `ENetMultiplayerPeer.host` right after `create_server` or `create_client`, before the first poll. They swap ENet's socket for a DTLS one, which only a fresh UDP socket allows (enet_godot.cpp:536-556).
  - It is DTLS 1.2 through mbedTLS, **with cookies**: a spoofed ClientHello gets one stateless reply and never gets a slot (dtls_server_mbedtls.cpp:37-57; tls_context_mbedtls.cpp:146-151; packet_peer_mbed_dtls.cpp:95-113).
  - DTLS is in the official Android 4.7 template (measured in multiplayer.md §2).
- **Its limits, in the engine's own comments:** "TODO limits? Maybe we can better enforce allowed connections!" and "TODO this needs to be fair!" (enet_godot.cpp:359, :377).
  - A peer that is mid-handshake holds one of the host's slots for up to 8 s (`ENET_DTLS_TIMEOUT_MS`, :285, :366).
  - At most 16 new sources can be pending (:317).
  - `refuse_new_connections` does work here (:316-318).
  - Every failed handshake prints an `ERR_PRINT` (packet_peer_mbed_dtls.cpp:100).
- **Measured on 4.7-stable in this container, 2026-09-24** (loopback; RSA-2048 key and self-signed certificate made with `Crypto` at startup; `dtls_server_setup` on the server's `host` right after `create_server`, and `dtls_client_setup("biogenic-pond", TLSOptions.client(cert, "biogenic-pond"))` on the client):

  | Case | Client | Server |
  |---|---|---|
  | pinned certificate, right name | connected after 513 ms. ENet's first CONNECT goes out before DTLS is up and waits for its resend, which is one `bio_send` error line | `peer_connected` at 520 ms; packets flow |
  | a different self-signed certificate | refused in 16 ms (`X509 verify failed`, -0x2700), status DISCONNECTED | stays up; one handshake error line |
  | right certificate, wrong name | refused in 18 ms, the same way | stays up; one handshake error line |
  | a plain ENet client, no DTLS | stays CONNECTING until ENet gives up | stays up; one handshake error line per attempt (5 in 8 s) |

  So pinning works, a wrong server fails fast and cleanly, and a plain client costs the server only log lines. The 0.5 s connect delay is ENet's resend. The engine's error prints are what journald's rate limit is for (C.3).
- **No client certificates.** The server side is `MBEDTLS_SSL_VERIFY_NONE // TODO client auth.` (tls_context_mbedtls.cpp:127). DTLS proves who the server is and encrypts the traffic; the client has to prove itself inside the encrypted channel.
- **Pinning a self-signed certificate: yes.**
  - `TLSOptions.client(trusted_chain, common_name_override)` verifies against exactly the chain given, and checks the certificate's name against the override (or the hostname if no override is given) (tls_context_mbedtls.cpp:173-228; core/crypto/crypto.cpp:70-99).
  - `Crypto.generate_self_signed_certificate` marks the certificate CA:TRUE (crypto_mbedtls.cpp:419-420), so it can be its own trust anchor.
  - `client_unsafe(chain)` checks the chain but skips the name, and the reference calls it testing-only.
- **Pre-shared keys (PSK): no.** TLSOptions has only `client`, `client_unsafe` and `server`, and the mbedTLS context never sets a PSK.
- **Crypto on the server at install time: yes, RSA only.**
  - Available: `generate_rsa`, `generate_self_signed_certificate(key, "CN=…,O=…,C=…", not_before, not_after)`, `generate_random_bytes`, `hmac_digest` (SHA-256 or SHA-1) and `HMACContext`, `constant_time_compare`, and RSA `sign`, `verify`, `encrypt`, `decrypt`.
  - `CryptoKey` and `X509Certificate` save and load PEM. `FileAccess.set_unix_permissions` sets 0600 on Linux. `AESContext` offers ECB and CBC only.
  - **There is no ECDH, no X25519 and no big-number API, so no password-authenticated key exchange (SRP, SPAKE2, OPAQUE).** A human password proven over a channel that is not already authenticated can be guessed offline by anyone who relays a single handshake.
- **SceneMultiplayer's own auth** (`auth_callback`, `send_auth`, `complete_auth`, `auth_timeout`). It holds a peer back until a callback approves it, and drops everything else that peer sends (scene_multiplayer.cpp:96-120, :144-158). That includes a protocol-4 build's RAW HELLO, which would lose that build its refusal sentence (`_check_skew`). So it is usable only on a listener no protocol-4 build can reach. If A moves the host off SceneMultiplayer, the same job is two frames in net_session's own handshake.
- **WebSocket with TLS.** `WebSocketMultiplayerPeer.create_server(port, bind_address, tls_server_options)` and `create_client(url, tls_client_options)`, with the same TLSOptions. Per-peer buffers are bounded by `inbound_buffer_size` (65,535 by default) and `max_queued_packets`, with a 3 s `handshake_timeout`. ENet cannot bound its buffers like this.
- **No text field is needed for any of this.** `DisplayServer.clipboard_get()` works on Android and Windows (FEATURE_CLIPBOARD). An invite can be **pasted** with one 48 px button, so lan.gd's reasons for having no text field still hold (lan.gd:5-12: the launcher theme styles no text field, and a soft keyboard would cover a landscape-locked screen).

### C.2 Four designs

- **C1: a private network (WireGuard or Tailscale), with the game unchanged.** The server listens only inside the VPN (`ENetMultiplayerPeer.set_bind_ip`, enet_multiplayer_peer.cpp:477), and the only open port is WireGuard's.
- **C2: ENet over DTLS, with the server's certificate pinned from a pasted invite, and a per-friend secret proven inside the encrypted channel.**
  - On first boot the server generates an RSA-2048 key and a self-signed certificate with a fixed name (for example `biogenic-pond`), and keeps them in `user://` at 0600.
  - Each invite gets its own 128-bit secret, minted when the owner asks (`-- --invite=<label>`) and written to a 0600 file. Only the path is logged, so the log never holds a secret.
  - An invite is one line of about 1.3 KB of text: address, port, key id, secret and the certificate. The owner messages it to a friend, who pastes it once; it lives in `user://` from then on.
  - A call goes: `create_client` + `dtls_client_setup` with `TLSOptions.client(pinned_cert, "biogenic-pond")`; then HELLO (the frozen compatibility check, refused with the usual sentence on a mismatch); then CHALLENGE (a server nonce); then PROOF (key id, a client nonce, and HMAC-SHA256 of both nonces and the protocol, keyed with the secret); then WELCOME.
  - Before PROOF, the host accepts only HELLO and PROOF, and A's grace period covers both.
- **C3: no DTLS.** The same proof, then a truncated HMAC on every frame, using a key derived from the secret and both nonces.
- **C4: WSS.** C2's pinning and proof over `WebSocketMultiplayerPeer` with TLS. Alternatively, behind a reverse proxy with a CA-signed certificate for a domain name the owner enters at runtime.

| | C1 VPN | C2 DTLS + pinned cert + invite | C3 HMAC only | C4 WSS |
|---|---|---|---|---|
| **Passive eavesdropper** | sees only WireGuard ciphertext | sees only DTLS ciphertext (ECDHE by mbedTLS's default preference; confirm the negotiated suite when measuring) | **reads everything**, which fails #59's encryption requirement | sees only TLS ciphertext |
| **Active man-in-the-middle** | defeated: both ends hold keys set up in advance | defeated from the first packet: the pin comes in the invite, not from first contact | cannot forge or alter frames or impersonate either end if the secret is random; can still drop and delay | defeated (by the pin, or by a CA certificate) |
| **Stranger who can reach the port** | WireGuard does not answer; the game port is not on the internet at all | passes the DTLS cookie, costs one RSA signature, then must prove a secret within the grace period or be cut. Can still make ENet buffer up to 32 MiB per slot for a few seconds (A.9). Handshake floods from real addresses need a firewall rate limit. | reaches ENet in plaintext; spoofed CONNECTs can hold every slot (A.9) | kernel SYN cookies, then TLS, then the proof; per-peer buffers bounded by configuration |
| **What a player does** | installs WireGuard or Tailscale once, imports the owner's config (that app scans the QR code, not ours), and turns it on to play; adds the server in Biogenic once by pasting | pastes the invite once, then taps once to call | pastes the invite once | pastes the invite once |
| **PROTOCOL bump** | no | not needed if CHALLENGE and PROOF exist only on the DTLS listener, which no protocol-4 build can reach (it has no DTLS client and no way to enter an address); needed if the LAN listener also requires the proof | yes if the LAN path carries MACs; otherwise as C2 | no: the frames are the ones wire.gd was designed for (:4-29); auth as C2 |
| **binary_version bump** | no | no: ENet DTLS, mbedTLS, Crypto and the clipboard are all in the stock templates | no | no, but check that the WebSocket module is in the APK, the way multiplayer.md §2 checked DTLS |
| **Costs** | a third-party app on every device; Android allows one VPN at a time | a few hundred lines; the engine's DTLS server has TODO-level limits; RSA-only keys; handshake errors print | its own crypto design, and no confidentiality | TCP head-of-line blocking brings back the delay net_session measured: worst jump 173 ms instead of 84 ms at 2% loss (net_session.gd:970-975) |

**Rejected outright:**

- **Scanning a code inside Biogenic.** It needs the CAMERA permission (a binary bump) and a QR decoder.
- **A native crypto library for password-based key exchange.** That is a GDExtension, built per architecture.
- **A typed password.** It needs a text field, and without such a key exchange it only protects against people who never saw a handshake.

### C.3 Recommendation

**Use C2 for the dedicated server's internet listener, after A and B have landed.**

- It keeps the UDP responsiveness measured in #53-#55.
- It asks the player for one paste and nothing else.
- It pins the server without trusting first contact.
- It needs neither a PROTOCOL nor a binary bump, and keeps secrets and addresses in `user://`.
- The LAN listener and phone hosts stay exactly as they are. A's LAN-only guard is switched off only for the DTLS listener.
- On the server box, outside the repo: an nftables rate limit per source address on the UDP port, and journald's rate limit for the engine's own error prints.

If the owner wants internet play before #59 lands, **C1 is the interim.** It needs no game code beyond a way to paste an address, and it can stay in front of C2 afterwards.

**Order of work:**

1. A (the LAN-only guard ships with it).
2. B.
3. **Measure C2's DTLS on loopback** in this container: a pinned client, a wrong certificate and a wrong name, where each failure must end in a sentence, not a hang.
4. C2.
5. Only then open the port.

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | How do friends outside the house reach the server? | **a pasted invite, pinned and secret (C2) ✓** / a VPN app on every device (C1) / not yet: LAN only | Invite: each friend pastes one message once, then taps to play. VPN: everyone installs another app and switches it on to play. Not yet: only people in the house can play. |
| 2 | One invite per friend, or one shared? | **one per friend ✓** / one shared | Per friend: you can shut one person out without re-inviting everyone, and the server log says who joined. Shared: simpler, but one leak means new invites for everybody. |
| 3 | Does playing on the home Wi-Fi need the invite too? | **no, being in the house is enough ✓** / yes | No: LAN play works exactly as today, and older installs can still join at home. Yes: every device needs an invite, even at home. |
| 4 | What does a guest the host catches cheating, or sending garbage, see? | **cut, with one line saying why ✓** / cut silently | The line helps an honest player whose install is broken; a cheater learns nothing they did not already know. |

On row 3: the LAN path's security is the room itself; the tap code is the invitation (net_session.gd:4-9). multiplayer.md §0.2 is still right that, with two players who know each other, most of this defends against nobody. #56-#59 are the gate for opening the port, not a verdict on the LAN.

**Before each merge** (merging publishes a release): net_probe prints `ALL PASS`; two phones on real Wi-Fi for 30 minutes show zero strikes and zero drops in the host's log; and there is no pending launcher sync. The A PR carries `Closes #58` and `Closes #56`, the B PR carries `Closes #57`, and #59 stays open until C2 lands.

### Files

- **Part A (built):** `game/net/net_session.gd`, `game/net/wire.gd`, `game/net/lan.gd`, `tools/net_probe.gd`, `docs/server.md`, and this document.
- **Part B:** `game/net/referee.gd` (new), `game/net/pond.gd`, `game/net/net_session.gd`, `game/normal/normal_mode.gd`, `tools/net_probe.gd`, `tools/net_lag.gd`.
- **Part C:** to be decided by the table in C.3.
