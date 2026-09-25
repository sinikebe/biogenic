# Net hardening: limits, a referee, and what an open port needs

This plan covers issues #56, #57, #58 and #59. It has three parts:

- **A** is one PR for #58 and #56 (frames, budgets, admission). **Built, and reviewed.** This part now describes what was built on `main` at `956d586`, what its review found and how each was fixed (marked "after review"), the measurements it rests on, and each place the build differs from the plan and why. The budgets ship enforced, the owner's call; watch mode stays as a switch (A.4).
- **B** is one PR for #57 (the host checks what a guest says). **Built.** This part now describes what was built on `main` at `17e5f09`, the measurements it rests on, and each place the build differs from the plan and why. The fouls ship enforced, and `enforce_referee` is the watch switch (B.1). The re-entry wound rule is on, the owner's decision of 2026-09-25 (B.2).
- **C** sets out the options for #59 and builds none of them. Still a plan.

Part C was written against `main` at `d84bfb6`, and its line numbers are that commit's. Parts A and B name functions instead, because they outlive a line number.

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

The files: `game/net/net_session.gd` (the boundary, the gate, the budgets, the door, the log), `game/net/wire.gd` (sizes and `REFUSE_BROKEN`), `game/net/lan.gd` (the LAN-only guard), and `tools/net_probe.gd` (the `limits` section, one assertion each at the end of the pond and server sections, and, after review, the wait in the server section's hunter check). `game/normal/` is untouched.

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
6. **Budgets**, per peer (A.4): frames, then bytes, then, for an event, events. Every frame that got this far is charged, a later build's unknown one included; a malformed frame was struck at step 4 or 5 and is not. **Watched, not enforced, as this ships** (A.4, "Watch mode"): an overrun is counted and logged as what it would have done, and the frame goes on to step 7.
7. **Unknown kind or event type** (the plan's step 8, moved ahead of parsing because an unknown frame cannot be parsed): a later build's extension, which the wire promises to ignore. Dropped after the budgets have paid for it, with no strike. **Added:** an unknown *event* still moves the peer's event sequence on, so the next known event is not reported as a gap.
8. **Parse or reject (host only),** with the readers pond.gd uses: `take_shout`, `take_enter`, `take_person`, `take_died`, `take_sister`. A STATE with `STATE_ALIVE` set must decode through `state_body`; before, one carrying a NaN cleared the friend's track as if they had died. Reserved flag bits stay ignored. A guest does not parse here: pond.gd already does, and a guest punishes nothing.
9. **Accept.** `heard` is stamped now, and only now, so junk cannot keep a peer looking fresh. The existing `_take_*` then run unchanged, and `_take_event` only ever queues a frame that is known, sized and, on a host, parsed.

The step comments in `_admit_frame` carry these numbers.

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

| Budget | Refill | Burst | Legitimate worst case | When exceeded (enforced as shipped; watch mode below) |
|---|---|---|---|---|
| frames | 120/s | 240 | 83/s | Frame dropped; a STATE is superseded 50 ms later anyway. Every 120 dropped inside one second is a flood strike (6 points). |
| events | 5/s | 20 | about 1/s, bursts of 4 | Dropped, 2 points. Dropping a reliable event causes a desync, which is acceptable only for a peer about to be cut. |
| bytes | 16 KB/s | 32 KB | about 3.5 KB/s (83 × 32 B + events) | Dropped, 6 points |
| queued events | n/a | 64 frames and 16 KB | a few frames per host frame | Oldest dropped, as the old cap did: a full queue means no run is draining it. Per guest: a phone host's `pond_events`, and a dedicated host's `inbox` counted by sender, so one guest over its share loses its own oldest event and never the other guest's. Enforced always. |

**The budgets ship enforced, and watch mode is a switch.** The frame, byte and event budgets and the flood rule are the only limits in A that timing alone can trip, and the relay runs in A.7 stand in for two phones on real Wi-Fi without being them. The owner chose to enforce them anyway, before that playtest: `enforce_budgets` in `net_session.gd` is `true`. Set to `false`, on either end, it is **watch mode**, for diagnosing a false positive in the field, and an overrun is then:

- **counted**, beside the enforced counts in `gate_counts`: `would_drop` (split into `would_drop_frames`, `_bytes` and `_events`), `would_strikes`, `would_points` and `would_cuts`;
- **struck on a watch ledger of its own**, which decays like the real one. Reaching 10 there, with the peer's real points counted in, is a cut that would have happened: counted, logged, and the watch ledger emptied, as the cut would have ended it;
- **logged** through `_note` as what it would have done, and rate-limited like every other line (A.6):
  ```
  [net] would drop a frame from 694971552 (192.0.2.41): over its frame budget (120 a second, 240 at once) -- watching the budgets, not enforcing them
  [net] would cut 694971552 (192.0.2.41): flooding: 241 frames over its budget in a second (120 a second, 240 at once) -- 12 points -- watching the budgets, not enforcing them
  ```
- **and taken.** Nothing is dropped, and no real point comes from a budget.

The first budget a frame cannot pay is its overrun, and the rest are not charged for that frame, as they would not be for a frame the gate drops. So watch mode counts exactly what enforcing would have done, and a run that shows none of it is a run enforcing would not have touched.

Everything else in A stays enforced, because no honest build can trip it: the size caps, the wrong direction, malformed and unparseable frames, the rules before the handshake, the door (the LAN guard, the slots, the pending cap, both call rates, the bars), and the queue caps.

The owner's playtest still says whether the numbers are right: **two phones on real Wi-Fi for 30 minutes, and the dedicated server with two, must show no `[net] dropped` or `[net] cut` line for an honest guest, and every `done after` line (A.6) must end `over budget 0`.** An honest guest cut there is a bug in these numbers: switch to watch mode and raise the budget the log names. The probe's T7 runs its flood with the budgets enforced, as they ship, then again watched, and checks the watched flood is counted and logged while the guest keeps every frame and its link.

**What a guest accepts from its host.** Sanity limits only; a guest never cuts its host, and in watch mode it drops nothing for them either, logging `would drop a frame from the host` instead. Frames 600/s with a burst of 1,200; events 200/s with a burst of 400; bytes 256 KB/s with a burst of 512 KB. All sit above POND's worst case (1,262 B × 83/s) and the 70-frame burst that follows an ENTER.

- **Changed: a guest's own event queue keeps 512 frames, and gains a 128 KB weight cap** (`POND_EVENTS_MAX`, `POND_EVENTS_BYTES`). The plan's 64 frames and 16 KB are what a host accepts from a guest; applied to what a guest queues from its host, they would drop the ARRIVE out of the front of the seventy events that answer every ENTER, and the guest would never arrive.

**A host stall is not a flood.** A phone host that stalls gets the whole stall's frames at once. Software GL at 2400x1080 has taken over 100 ms a frame.

- Every bucket refills on wall time.
- When the session's own frame gap exceeds 0.25 s (`STALL_GAP`), every bucket of every peer is topped up once in that frame: `tokens = max(tokens, rate × gap)`, uncapped by the burst.
- **Added:** the gap counted is at most 10 s (`STALL_CREDIT`). A peer silent for longer than that is past ENet's own timeout, and an unbounded credit would be one a flood could spend for as long as it lasted.
- An overfull bucket is spent down, not trimmed back, so the backlog the stall delivered is what the credit pays for.
- **Only a guest swimming in the host's pond is held.** Once the host has been quiet for `PEER_FRESH` (1.2 s), that guest's run is held (shared-pond.md §1.8) and its held body beats at 2 Hz, so its side of a stall does not pile up. A guest that is connected but not in the pond keeps playing, and sending at its usual rate; what it sent during the stall arrives at once when the host resumes, which is exactly the backlog the top-up pays for. The review froze a phone host (SIGSTOP) for 1, 2, 3, 4 and 4.8 s with a guest in its pond: nothing was dropped or struck, and the deepest draw on the frame burst was 71 of 240.

**The strike ledger, per peer** (`Guard`). Points decay at 1 a second, and a peer is cut at 10.

| Offence | Consequence |
|---|---|
| frame over the direction cap (A.2, step 2) | cut at once and barred, bypassing the ledger: this is how memory gets allocated |
| anything other than a well-formed HELLO before the handshake | cut at once, **not** barred (A.5) |
| non-RAW first byte (A.1), known kind in the wrong direction, size out of range, a second HELLO, parse refused | 4 points, counted on every frame |
| flood (every 120 frames over the frame budget inside one second), byte budget | 6 points once the budgets are enforced; on the watch ledger until then |
| event budget | 2 points, the same way |
| unknown kind or type | 0 points (counts against the budgets only) |
| referee violations from part B | 1-4 points, each rule counted at most once per 0.5 s (B.2) |

In practice, two malformed frames leave a peer connected, and three within two seconds cut it. A peer on the same protocol never sends one, because the writers never write what the readers refuse (wire.gd). **The flood rule was sharpened in the build**: "more than 120 dropped in any 1 s window" read as one strike per window would never cut a one-second burst, so it is one strike for every 120 dropped inside a window. A burst of thousands cuts at once; a steady overrun of 130 frames a second cuts in about two.

**How a cut happens** (`_cut`):

1. A greeted peer cut by its ledger is sent `REFUSE` with a new reason, `REFUSE_BROKEN := 0x04`.
2. It is removed from `_peers` at once, so none of its later frames are read (they are counted as `strays`).
3. After `REFUSE_LINGER` it is cut with `get_peer(id).peer_disconnect_now()` (`_drop_now`).

`peer_disconnect_now` replaces the old `disconnect_peer(id, false)`. That call is graceful: it waits for an acknowledgement a hostile peer never sends, and holds the ENet slot until ENet times it out. `peer_disconnect_now` frees the slot at once, and the next poll emits `peer_disconnected`.

Oversize and pre-handshake cuts skip the refusal. The handshake's own refusals (`REFUSE_PROTOCOL`, `REFUSE_FULL`, and `REFUSE_SILENT` at `HELLO_GRACE`) keep their sentences and linger, and end with the same hard cut. A protocol-4 guest from before this shows reason 0x04 as "refused / the other end hung up"; a new one reads "cut off: the other end would not take what this game sent. update both from the launcher, then call again in a minute." **Changed after review:** the first build's "could not read" was wrong for a cut made for flooding or for bytes or events, and its "call again" was wrong for a minute: a ledger cut also bars the address for 60 s (A.5), so a call straight back is hung up on at the door as "they hung up". The sentence is one line at 1280x720 and at 2400x1080, rendered from a real join and cut.

A host whose last greeted guest is cut, or leaves, goes back to listening. **Changed:** that now counts greeted guests, not transports, so a caller still saying hello cannot keep a host reading TOGETHER after its guest has gone.

**Added after review: nothing a guest said outlives it.** A phone host's run stops draining `pond_events` the moment the link drops (pond.gd `_step_host` returns first), so whatever was still queued -- an ENTER, a PERSON -- used to wait there and reach the next guest's run as an arrival that guest never made, and a cut guest's events with it. The queue and `heard` are now cleared when the last greeted guest goes, however it goes, and a dedicated host drops a departing or cut guest's entries from `inbox` and keeps the other guest's (`_lost_guest`, `_forget_said_by`; T12).

### A.5 Admission

**What 4.7 exposes to GDScript, and what it does not:**

- **The address.** `ENetPacketPeer.get_remote_address()` and `get_remote_port()`, reached through `ENetMultiplayerPeer.get_peer(id)` from inside `peer_connected`. Measured: it is a `String`, dotted for an IPv4 caller even on the host's dual-stack socket; an IPv6 one prints as eight hex groups (`IPAddress`'s own `String` form).
- **No way to refuse early, per address.**
  - ENet's `intercept` hook and its `duplicatePeers` limit exist in the C struct, but Godot never sets or exposes them (enet.h:352, :403-406; host.c:103; no reference in modules/enet).
  - `ENetConnection.refuse_new_connections()` does nothing on a plain UDP host: it only reaches the DTLS server socket.
  - `MultiplayerPeer.refuse_new_connections` resets every new peer after ENet's handshake, all or nothing.
- **So the earliest per-address decision is inside `peer_connected`**, and the refusal is `peer_disconnect_now()` within that same poll. It was **measured** safe with packets already queued (A.9), and T6 keeps it as a regression check.

**The limits** (`_admit`), checked in `_on_peer_connected` before any bookkeeping is created, in an order chosen so that a caller who is barred or not on this network spends nobody else's budget, and **a call its own address's bucket turns away never spends the bucket every address shares** -- nor does a call the shared bucket turns away cost its address anything. **Fixed after review:** the first build spent the shared bucket first, so one device calling more than ten times a second locked every other device out. The review reproduced it -- twelve calls from one address, then a first-ever call from another, refused as busy -- and T8 now checks exactly that.

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
| address book | 1,024 entries | same | The limiter's own memory is bounded. Nothing is forgotten until the book is full; then a caller idle for 10 min (`BOOK_IDLE`) goes first, then the one heard from longest ago, and a barred one only if every entry is barred. |

IPv6 callers are keyed by their /64 (`Lan.source_key`). The address book, the buckets, the bars and the log limiter belong to each `host()` call and are cleared by `_reset_socket`. That is also what keeps net_probe's many loopback hosts independent of each other.

**Where the build differs, and why:**

- **The per-address burst is 8, not 4.** The probe's existing server section calls six times from one loopback address in about six seconds (two guests, a third refused "already two", a fourth after one leaves, and two more at the end). With a burst of 4 and one call every 3 s it passed or failed on the runner's speed: it needed about 1.7 tokens for the last pair, and got them only if the section took long enough. A burst of 8 covers the section with no refill at all. What it costs is four more calls in a burst from one LAN address, each of which still meets the pending cap, the transport cap and the grace timer.
- **Speaking before the handshake is a cut, not a bar.** A port scanner or a confused non-Biogenic client does exactly that, the pending cap and the per-address bucket already bound its cost, and T6 needs a real guest from the same address to join straight after. An oversize frame and a ledger cut do bar.
- **`Lan.is_local_source()` sits beside `_range_rank`, not `_is_private`.** #62 replaced `_is_private` with `_range_rank`, which ranks addresses and refuses none; the guard refuses and ranks none, and its comment says so. It parses IPv6 itself: compressed or in Godot's eight-group form, with a zone or a dotted IPv4 tail, and an IPv4-mapped address is judged as the IPv4 it is.

### A.6 Telemetry

All of it goes through one helper, `_note(what, key, line)`. It prints at most one line per (what, address) every 10 s (`NOTE_EVERY`), and the next line says how many like it were held back. **Added:** a refusal that is about everybody -- a caller from outside the network, or the door taking no calls from anywhere -- is keyed by its reason instead of its address, so a storm from a thousand addresses is one line every 10 s, and the helper only ever remembers callers the door let near it. Its own memory is bounded by `NOTES_MAX`, 256 kinds-and-keys: when it is full, every hold that has ended goes, and if none has, the one that ends soonest. With the door letting at most ten callers a second near it, that last never happens in practice, but the bound no longer depends on it.

- **The existing warnings go through it too:** the event gap, a failed send and a mismatched host id. Each was otherwise one line per frame, at a rate an attacker chooses. They stay warnings.
- **Lines, all starting `[net]`:**
  - a refused connection, with its reason: not on this network, barred, too many calls from everywhere, calling too often, too many transports from there, too many callers saying hello;
  - a cut: oversize, before its hello, malformed, and -- once the budgets are enforced -- flood, bytes, events, with the points and how long the address is barred;
  - a strike that crosses half the threshold;
  - **added:** the handshake's own refusals (different versions, already two, no greeting), because a server's operator wants to see those as much as the rest;
  - **added:** watch mode's "would drop" and "would cut" (A.4);
  - **added: one line for every greeted guest as it goes** -- it left, was cut, or the host closed -- with how long it stayed, the frames and events taken from it, how many times it went over its budgets (dropped, or would have been), and its points: `[net] 694971552 (192.0.2.41) done after 1800 s -- frames 51234, events 312, over budget 0, points 0`. It is printed unconditionally, because a playtest has to say "over budget 0" in so many words rather than by staying silent;
  - **saturation.** Once a second the host reads `HOST_TOTAL_RECEIVED_DATA` and `HOST_TOTAL_RECEIVED_PACKETS` from its `ENetConnection` (`pop_statistic`). These count everything ENet read, including what never reached the gate. A line is printed above 64 KB/s or 2,000 datagrams/s; two real guests send about 7 KB/s and 170 datagrams/s.
- **Counts for tools**: `gate_counts` on the session holds every refusal by reason, every cut, bar, strike and drop, the strays, the busiest second's arrivals, and watch mode's `would_*` counts. It is reset by `host()` and `join()` and kept after `close()`, so a tool can read a session's last word; `points_of(id)` reads a peer's ledger.

Examples, using documentation addresses:

```
[net] refused 203.0.113.9: not on this network (LAN-only until #59)
[net] hung up on 1587052382 (192.0.2.40): different versions
[net] cut 694971552 (192.0.2.10): malformed: an event of type 4 that does not read -- 12 points -- barred 60 s
[net] 694971552 (192.0.2.10) done after 3 s -- frames 12, events 2, over budget 0, points 12
[net] would drop a frame from 1945108233 (192.0.2.11): over its frame budget (120 a second, 240 at once) -- watching the budgets, not enforcing them (+2614 like it held back)
[net] saturated: 1843.2 KB a second in 21400 datagrams arriving at the socket (+37 like it held back)
```

A peer's address may appear in the server's log: the log is not the repo.

### A.7 What this could break, measured

**A phone-hosted pond and the dedicated server: nothing, measured.**

The relay harness from #61 (`relay2.py`) sits between each guest and its host and holds every datagram for 5-40 ms, one in twenty for 150-250 ms more, in order, so a spike holds everything behind it the way Wi-Fi does; with `--loss 0.02` it drops one in fifty. Each run is real ENet on real sockets, two or three processes, real runs of the game with bodies swimming on their own impulses, 100 s requested (about 110 s measured). A scratch harness samples every peer's buckets, counters and ledger every frame. These were run with the budgets watched (A.4), which is why they show both. In **every run, every process's gate stayed at zero**: no strike, no dropped frame, no cut, no refusal, no queue overflow, not one stray -- and not one `would drop` or `would cut`, so enforcing the budgets would not have touched any of it either. Every guest's `done after` line said `over budget 0, points 0`.

| Run | Link | Frames from each guest: peak in 1 s (share of 120/s), in 0.1 s, deepest draw on the burst of 240 | Bytes: peak in 1 s (share of 16 KB/s), deepest draw | Events: peak in 1 s, deepest draw on the burst of 20 |
|---|---|---|---|---|
| phone host and guest | jitter | 26 (22%), 8, 6 (2.5%) | 842 B (5.1%), 0.7% | 2, 2 (10%) |
| phone host and guest | jitter, 2% loss (70 up, 92 down lost) | 26 (22%), 8, 7 (2.9%) | 862 B (5.3%), 0.7% | 2, 2 (10%) |
| server and two guests | jitter | 27 and 26 (23%), 8, 7 (2.9%) | 880 B (5.4%), 0.7% | 2, 2 (10%) |
| server and two guests | jitter, 2% loss (111 up, 116 down lost) | 26 and 26 (22%), 8, 6 (2.5%) | 842 B (5.1%), 0.7% | 2, 2 (10%) |
| phone host and guest, the guest at 120 fps and knocked every frame (at most 55 sent a second) | jitter, 2% loss | 65 (54%), 19, 16 (6.7%) | 2,006 B (12.2%), 1.5% | 2, 2 (10%) |
| server and two guests, both at 120 fps and knocked every frame | jitter, 2% loss | 65 and 64 (54%), 19, 17 (7.1%) | 2,015 B (12.3%), 1.6% | 2, 2 (10%) |
| phone host and guest, the guest at 80 fps with its velocity thrown every frame: the ceiling, 56-80 state frames sent a second | jitter, 2% loss | **95** (79%), 27, 21 (8.8%) | 2,945 B (18.0%), 2.0% | 2, 2 (10%) |

What a guest takes from its host peaked at 87 frames a second (15% of 600), 41 events in the second after an arrival (21% of 200) and 25,354 bytes a second (10% of 256 KB), and no guest dropped anything, or would have, either.

**The margins.** The most any guest sent was 80 state frames in a second, at the ceiling; the frame budget's refill of 120 is 50% above that, and 45% above the arithmetic ceiling of 83. Arriving through the relay's spikes, the busiest second held 95 -- 79% of the refill -- because a spike releases everything it held at once, in order; that is what the burst is for, and the deepest any run drew it was 21 of 240 (8.8%). The byte budget is five and a half times the most measured, and its burst was never drawn past 2.0%. Events never came near: every run above peaked at two in a second. Earlier rounds, with this same guest code, caught a guest that died and came back from the black sending four, and once five, inside one second -- the harness taps to come back at once, which packs them closer than a player would. Those are clusters, and what they draw on is the burst, not the refill: 3 of its 20. The refill of five a second is what puts them back, and no window longer than a second ever came near it.

**Old and new builds together.** "Old" is main at `956d586` (+107), the newest protocol-4 release, run from a scratch copy.

Each through the same relay (default jitter), real runs in the pond:

| Pairing | Joined, in the pond | Frames delivered | The new build's gate |
|---|---|---|---|
| old guest, new phone host (90 s) | 0.15 s, 0.39 s | the guest got every state frame and snapshot the host sent (1,987 and 2,015) | host: clean for 101 s, `over budget 0` |
| a +104 guest, the oldest protocol-4 release, new phone host (60 s) | 0.17 s, 0.41 s | every one (1,374 and 1,375) | host: clean for 71 s, `over budget 0` |
| new guest, old phone host (90 s) | 0.15 s, 0.40 s | every one, both ways (the host got 1,999 of 1,999) | guest: clean for 99 s |
| two old guests, new dedicated server (90 s) | 0.17 and 0.15 s, 0.50 and 0.48 s | every one | server: clean for 104 s, both guests `over budget 0` |

And **an old guest cut with `REFUSE_BROKEN`**: +107 and +104 guests joined a hardened host on loopback and sent three nine-gene PERSONs. Each was cut at the third (12 points), went to `REFUSED` reading "refused" over "the other end hung up.", kept running, and closed cleanly. A reason it does not know is a sentence it already has, as every protocol-4 build's `_take_refuse` promised.

And **the exported server**: this tree's Linux Server export, the binary CI builds, took two new guests through the relay for 60 s -- every frame delivered, both guests' gates clean, and no `[net]` line but each guest's `done after ... over budget 0, points 0` -- and then cut a +107 guest the same way, saying so in two `[net]` lines: one as it crossed 8 of 10 points, one for the cut.

**Existing net_probe checks: one changed, after review, and all pass.** The pond section and the server section each gained one assertion at their end: across every session in them, the gate struck nothing, dropped nothing, cut nothing and refused nobody at the door, and the budgets it watches would have done none of it either.

- `_check_link` sends four shouts in bursts; they fit the event budget, and the gate checks sizes and finiteness, not radii.
- `_check_skew`: every HELLO is 3 bytes; protocols 1, 2, 3 and 5 are still refused with the sentence; `peer_count() == 0` still holds, because `_refuse` removes the peer at once.
- The hand-made `bench` dictionaries still work, because the accounting is outside `_take_state`.
- `_check_run` sends shouts from host to guest, into a run on the guest, which exercises the guest-side budget.
- `_check_pond`: the genome burst after ENTER reaches the guest. Both "host stopped" stages pass unchanged.
- **`_check_server`'s hunter check had a race of its own, on `956d586` as well -- fixed after review, and the one existing check this changes.** "A hunter on the guest in slot 69 is that guest's hunter, and the other guest, who is sent the same body, sees no hunter" read the first guest's water in the frame the second guest saw the hunter. But each guest gets its snapshot on its own 50 ms schedule (`_flush_guest`), so after a guest returns from the black the first can be a snapshot behind the second, and the check then failed with the body not yet sent -- or passed on an older body in slot 5, somewhere else. Only the server's heartbeat, every 0.5 s, puts the two schedules back in step. Instrumented, 956d586 posed the hunter with the first guest's snapshot due later than the second's in 4 of 63 runs, every time saved by an imminent heartbeat; an earlier version of this change moved the pose off the heartbeat in most runs (A.1), and one full probe run failed on it. **The wait now waits for both**: the hunted guest's hunter, and the posed body, within 30 units of where it was posed, in the other guest's water. The review's deterministic repro (hold the first guest's next snapshot 0.25 s and clear its old body 5 at the pose) failed 2 of 2 before the fix and passes after it, the wait returning about 0.27 s later, when the held snapshot lands.

**CI's frame budget.** The whole probe now finishes in 8,480-8,837 frames and 71-75 s (four runs of the build as it stands, one of them CI's own step), against 6,643 frames and 53.6 s on `956d586`. The `limits` section is 1,825-2,143 frames and 18-21 s of that, at 100 frames a second; what varies is how long ENet keeps retrying the callers T8 turns away. The backstop is 20,000 frames, so the margin is still better than two to one. The comment on ci.yml's LAN step says so, and says the host reads its own socket.

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
| T7 | **Flood, enforced and watched:** 3,000 valid STATEs in one second from a greeted guest, to a host with `enforce_budgets` on; the same flood to a host switched to watching; then a control run at 100/s for 3 s, enforced | Enforced: cut with `REFUSE_BROKEN` after about 0.2 s, with no more frames taken than 240 + 120 × t; the host's worst frame time is printed. Watched: every frame taken (a recorded run: 2,972, the 2,970 sent and the guest's own beat), about 2,600 counted as would-drops and about ten as would-cuts, both logged, and the guest never struck or cut. The control run is all taken, with nothing dropped, struck or even watched. |
| T8 | **Connect storm:** 12 silent Rogues from 127.0.0.1 in four consecutive frames; the review's lockout, at the door itself; then the transport cap, on a two-guest host | Never more than 2 waiting at once. Every call is either let in to wait or cut on arrival, and the two counts add up to twelve; no more pass the address's bucket than its burst and its refill allow; both the bucket and the waiting room turn calls away (a recorded run: 2 let in, 6 cut for the waiting room, 4 for calling too often, over 1.6 s of ENet's own retries, which the wait allows 16 s for). The bucket is empty after the storm, and a real guest from the same address joins once it holds a call again. **The lockout:** twelve calls at once from one address are 8 answered and 4 refused for calling too often, and a first call from a second address is answered, not refused as busy; ten first calls from ten more addresses then find the 1 call left in the shared bucket, and 9 are busy. With two guests and a caller open from one address, a fourth transport from it is refused. |
| T9 | **Queue weight**, driven straight into `_take_event` so no frame is spent | A phone host keeps 60 of 100 longest PERSONs (16,320 bytes of 16,384), the newest last, and 64 of 100 ENTERs. A dedicated host holds one flooding guest to 60 and keeps both of the other guest's events, the first still first. A guest keeps 512 of 600 GENOMEs from its host. |
| T10 | **Unknown kind:** ten frames of kind 0x7E and one event of type 0x7F | Dropped, no strike, still TOGETHER, and the shout sent after them is heard. |
| T11 | **LAN-only guard:** a table of addresses, with documentation ranges standing in for public ones and a placeholder 10.0.0.5 as the host | Loopback, RFC 1918, 100.64/10, 169.254/16, the host's own /24, and IPv6 loopback, ULA and link-local are answered; public stand-ins and junk are not; an IPv6 caller is its /64. |
| T12 | **Leftovers:** a phone host's guest leaves with an ENTER, a PERSON and a shout still waiting; a second is cut with an ENTER waiting; a third joins. Then a dedicated host holding three events from two guests, one of whom leaves | Both departures take what they said with them, and the third guest finds nothing waiting. The dedicated host forgets the two events from the guest that left and keeps the other guest's. |

**Where the section differs from the plan, and why:**

- **T6 gained a control.** "None of the forty delivered" only means something next to the same caller at an open door, where they are.
- **T8 gained the per-address transport cap**, which the storm never reaches: the pending cap refuses first. **After review** it gained the lockout check, and its wait grew from 8 s to 16 s, twice the last of ENet's retries (0.5, 1.5, 3.5 and 7.5 s after a call).
- **T7 runs its flood twice after review**: enforced, as the plan tested it and as the budgets ship, and watched, the switch for diagnosing a false positive (A.4).
- **T12 is new after review**, for the leftovers the review found (A.4).
- **T9 is socket-free.** The plan's 40 largest PERSONs over 10 s cannot reach either cap within the event budget (40 × 272 = 10,880 bytes, under 16,384; 40 frames, under 64), and a run that pushes past both would take 10 s of frames. Driven straight into `_take_event`, it pushes each queue past its caps in no frames at all.

Every test prints `PASS` or `FAIL` in the house form and none causes a `SCRIPT ERROR`: the gate never reads past a size it has already checked, and ci.yml fails the step on any `SCRIPT ERROR`.

### A.9 What A cannot fix, and what was measured

- **ENet's 32 MiB per peer** (layer 1). A limits how many peers can hold it (slots), how long (grace and hard cuts) and how often (per-address rate). Only an engine change lowers the cap, and that would be a binary bump. And the gate sees an oversize frame only after ENet has reassembled it and `get_packet()` has copied it once; the copy is freed with the cut.
- **Spoofed CONNECTs hold slots** for 5-30 s without GDScript ever seeing them. Nobody spoofs on a LAN. On the internet, DTLS cookies are the fix (C).
- **ENet reads at most 256 datagrams per poll.** Anything beyond that waits in the kernel's 256 KiB buffer and is dropped there. This puts an implicit ceiling on CPU, but it also adds latency for honest frames during a flood.
- **Engine error prints** cannot be rate-limited from GDScript. This covers a failed DTLS handshake, and on guests, the SceneMultiplayer commands a hostile host could send.
- **The lockout, fixed.** The first build's door spent the bucket every address shares before the caller's own, so one device making more than ten handshakes a second locked every new caller out. The review reproduced it, the order is swapped (A.5), and T8 checks the review's own scenario.
- **A barred address can still knock.** The door judges a caller only once ENet has finished its handshake, and the bar is checked before the call buckets, so a barred address can complete handshake after handshake -- each refused at once, the line printed once every 10 s -- and, by never finishing one, can hold every one of the 4 or 6 ENet slots until ENet gives up on it (5-30 s), which keeps every new caller out for as long as it keeps at it. A guest already playing keeps its slot. Only something below GDScript refuses before the handshake: on the server box, a firewall rate limit per source (C.3); on a phone, nothing.
- **An ENTER is answered with about seventy reliable events.** A.4 lets a guest send five events a second, and every ENTER makes the host queue an ARRIVE, a PERSON and up to 68 GENOMEs (about 10 KB) back to it, all reliable, so a guest that acknowledges slowly grows ENet's send queue for as long as it keeps asking. While the budgets are watched, not even the five a second bounds it: only the host's own frame rate does. B's ENTER limit (four at once, then one every 2 s, B.2) bounds it either way.
- **Watched budgets take a flood whole** (A.4). Memory stays bounded -- the queue caps are enforced, and ENet reads at most 256 datagrams a poll -- and the lines are rate-limited, but every frame of a flood is read, parsed and taken until the budgets are turned on.
- **The server's updater waits for an empty pond**, and a caller still saying hello counts (docs/server.md: "nobody connected, and nobody connecting"). A hostile device on the LAN that keeps calling can therefore hold an update back, one call every 3 s after its burst. That is the updater's definition of empty, and it is left as it is.
- **IPv6 could not be run here.** This container has no IPv6 at all, so the guard's IPv6 rules are checked on a table (T11) and against Godot's `IPAddress` string form, but no IPv6 caller has reached a host.
- **Measured on 4.7-stable in this container, 2026-09-24:**
  1. **Cutting a peer inside `peer_connected` with packets already queued is safe.** Four hostile raw `ENetConnection` clients sent 40 packets each in the same datagram as the ACK that completes the handshake. In a control run with no cut, they arrived in the same frame as the connection. With `get_peer(id).peer_disconnect_now()` inside the handler, none were delivered, `peer_disconnected` fired on the next frame, and each hostile client saw its disconnect. The server stayed up, and an ordinary client joined afterwards and exchanged 209 packets, with no error lines, through SceneMultiplayer and through the `ENetMultiplayerPeer` read directly alike. T6 keeps this as a regression check, with its own control.
  2. **`_check_link`'s timing checks with the host reading its own socket:** unchanged, three runs of three, for the route alone (A.1) and again for the build as it stands: 45 places in 2.2 s, 44 frames, a beat of 0 then 3, a dash drawn 13.8-13.9 ms after it started; the pond's quiet host held the guest at 1.207-1.216 s of silence and let it go 2 frames after it resumed.
  3. **Budgets on a real link.** Two phones on real Wi-Fi for 30 minutes remain to be run. The owner chose to ship the budgets enforced before that (A.4), on the strength of the relay runs in A.7: real ENet over real sockets, through 5-40 ms of flight with 5% spikes of 150-250 ms, with and without 2% loss.

## B. #57 in one PR: the host checks what the guest says

**Built.** This part now describes what was built on `main` at `17e5f09` (v0.2.0+108), which already had A, the dedicated server with two guests (#62) and the pinned ENet throttles (#63). It gives the measurements the build rests on, and each place the build differs from the plan and why, marked **changed from the plan**. The plan was written against `d84bfb6`, and its line numbers are gone from this part, which names functions instead. The fouls ship **enforced**, like A's budgets, and `enforce_referee` is the watch switch (B.1). The re-entry wound rule is **on: the owner's decision of 2026-09-25** (B.2).

There is no wire change and no PROTOCOL bump, and the PR is content only. `game/normal/` is untouched (B.1 says why that was possible), so the single-player identity gate (shared-pond.md §5) had nothing to guard.

### B.1 Where the checks live

A new file, **`game/net/referee.gd`**, holds them. It is RefCounted and preloaded, with no class_name, like wire.gd.

- **One referee per guest.** On a phone host there is one per connection: made on the first frame the link is up, and dropped with the link, so a reconnected guest is new to the referee as it is to A's ledger. On the dedicated server there is one per guest record, which is one per person slot (68 or 69) for as long as that guest holds it.
- **It answers, and the host acts.** Every guest input goes in through a `judge_*` call or through `claim`, and comes back as what the host should do: take it, take a clamped copy, or leave it. Each broken rule is queued as a foul with its weight.
- **pond.gd hands every foul to the ledger at once** (`_charge`), through the new public `strike(id, weight, why)` on `net_session.gd`, which feeds A's `_strike`. So a foul can cut a guest in the middle of a frame. After every charge, pond.gd asks `_gone(g)` and hears nothing more from a guest that has been cut: not the rest of its events, not its state frame, not its shouts.
- **It holds no scene.** Every call takes the time and the facts it needs, so net_probe drives it with no socket and no tree (B.5).
- **A host stall is not a teleport.** When a host frame comes more than 0.25 s after the last, pond.gd hands every referee the gap, up to 10 s of it, past each budget's hold (`_mind_stall`). These are A.4's `STALL_GAP` and credit, for A.4's reason: what lands after a stall is the backlog of a host that could not listen.
- **`enforce_referee := true`** on `net_session.gd` is the switch, shaped like `enforce_budgets`. Off is **watch mode**: a foul costs no points. It is counted (`referee_would_strikes`, `referee_would_points` and `referee_would_cuts` in `gate_counts`) and logged as `[net] would foul ...`, and at ten points as `[net] would cut ...`.
  - **Changed from the plan:** the verdicts stand in both modes, refusals as well as clamps. A clamp or a refusal is the host deciding about its own water, and it cuts nobody. An honest guest was never fouled (B.3), so letting refusals through while watching would show nothing the log does not already say.
- **Changed from the plan: a phone host's shouts are checked in pond.gd, not in `normal_mode.gd`.** A phone host's session keeps a guest's shouts in `heard`, and the run drains them later in the same frame (`_hear_others`). pond.gd judges each shout the frame it lands (`_judge_heard`) and takes the refused ones out of `heard` before the run reads it. It remembers the ones it lets stand, by identity, so a shout the run has not drained yet -- because its cell is dead, or held -- is not judged or charged twice. The dedicated server asks the same question before it relays a shout to the other guest (`_shout_heard`). That is why `game/normal/` needed no change.

The ledger is A's (A.4): points decay at one a second, and ten cut the guest with `REFUSE_BROKEN` and bar its address for 60 s. **Each rule fouls at most once every 0.5 s**, however many frames break it, so a cheat that lies on all twenty state frames a second is struck twice a second, not twenty times.

### B.2 Every guest input, checked

| Input | The host's check, as built | On violation |
|---|---|---|
| **STATE: place** | A movement budget on the path the guest *claims*. It refills at 1,100 u/s, holds 1,650 u, and allows 100 u of slack. **Anchored at the arrival:** the budget is emptied when the host places the body, and the first claimed place is measured from where the host put it -- or from the arrival before, if that one never happened, since its ARRIVE may be the one that lands. The next frame is measured from the claim, not from the clamped place, so one late frame cannot foul twice. The place the host *applies* follows the claim through a second budget with the same numbers. | The host's place walks toward the claim at 1,100 u/s at most. 2 points |
| **STATE: heading** | The same, at 1.35 rad/s with 1.5 rad held. **Added:** 0.05 rad of slack, two steps of the wire's one-byte heading, so rounding never fouls. | Turned toward the claim at the cap. 2 points |
| **STATE: velocity and turning** | Speed clamped to 1,100 u/s, turning to 1.5 rad/s, both zero while out of the water | Clamped, no foul |
| **STATE: radius** | Never over the host's expectation + 0.05. The expectation starts at the ENTER's radius and gains 4 for every ATE the host *sends*, up to 40. After a SISTER it is 28.284, plus 4 for every meal sent since the mother was last seen out. Decreases are always allowed. **Changed from the plan:** after an arrival that is not a return from a death, the first state frame's radius is taken, up to 40: a guest swimming alone eats during the round trip of its own swap, and an arriving body is one the host never saw grow (B.6). **Added:** a claim under r26 is raised to 26, with no foul. | Clamped to the expectation. 4 points |
| **STATE: OUT** | **Judged as a division begins:** an OUT phase may start only when the expectation is 40. While out, the body is out of the water, its place frozen (±2 u) and its motion zero. **Changed from the plan:** every later OUT frame of a phase that began legally is that division's own tail, bounded at r40 even after the SISTER has set the daughter's expectation. The SISTER is reliable and the mother's last OUT frames are not, and they travel on different channels, so the SISTER can land first -- and in the probe it did (B.3). A phase ends in a SISTER, a death, a leave, or a daughter's frame (under r39) whose SISTER lands within 5 s. | OUT under r40: kept in the water, 4 points. A move while out: held still, 4 points. Back in the water undivided, or a daughter whose SISTER never came: 4 points |
| **SHOUT** | With the guest's body in the host's water: `at` within 650 u of any place it claimed in the last 4 s -- **changed from the plan**, which measured the newest place only; a shout is reliable and a state frame is not, so a resent shout lands behind frames sent after it. The radius within the expectation. The reach exactly `PING_RANGE_BY_TIER` of the worn `ampulla`, or of the body before, for a shout sent before a new body that lands after it. The rate: one per ping period less 1 s, two banked, plus one after every new body, arrival or organ gained. With no body in the water, only the rate. **Added:** a shout reaching 0, or at r0, is dropped uncharged and never fouled (B.3, the second quirk). | Dropped, so nothing is heard or relayed. 1 point |
| **ENTER** | Legal with no body here for this guest, or with one that has not arrived (no state frame with a body since its ENTER). Radius in [26, 40], ±0.01. **Changed from the plan:** only the *first* ENTER after a death must be r26, so no guest can be locked out; and four are banked, then one every 2 s, where the plan had two and then one every 3 s (B.3). What an accepted ENTER's body carries is the re-entry rule's, below. | Not answered: no ARRIVE, and the guest asks again after `REACH_TIMEOUT`, as for a lost ENTER. 1 point |
| **PERSON** | Two a second, six banked. Every slot names a worn gene, once -- **changed from the plan:** a worn gene may have no slot, since the gift can be dropped over a slot another worn organ still sits in (genome.gd's `place`). `new_body` is legal with no body in the water, with one that has not arrived, or once after a SISTER, which is a birth. Otherwise the worn tiers must be the host's, but for the gift -- **made exact:** one of the four first senses (`ocellus`, `ampulla`, `chemocyte`, `stigma`) at tier 1, once a body. **Added:** the stale body every build describes after a death (B.3, the first quirk). | A `new_body` out of turn: applied as `false`, 4 points. An escalation or a bad order: ignored, the old body kept, 4 points. Over the rate: ignored, 1 point |
| **SISTER** | Once for each division the host saw begin. Radius exactly 28.284, ±0.05, and 560 u from where the host froze her mother, ±20. Heading and genome as sent (B.6). | Out of turn: nothing placed, 4 points. Off the ring or the wrong size: put on the ring at r28.284, 2 points |
| **DIED** | With a body here, the body goes: dying is the guest's right. Only starving (cause 3, by nobody) is the guest's own death to report. With none here, it is a death the host made itself, said again, and nothing. | Reported as starving. 2 points |

**The speed cap, from cell.gd's own tables**, with each organ at its fastest. The probe holds the stacked peak under the cap (`_referee_agrees`).

| Organ | Tier 0 / 1 / 2 / 3 (units per second) | Derived from |
|---|---|---|
| flagellum, impulses as often as allowed | 153 / 193 / 246 / 323 | `IMPULSE_SPEED_BY_TIER` / (1 − e^(−0.74 × gap_min)) |
| axoneme, held push | 0 / 81 / 115 / 155 | `PUSH_ACCEL_BY_TIER` / 0.74 |
| myoneme, a dash every cooldown | 0 / 295 / 372 / 465 | `DASH_SPEED_BY_TIER` / (1 − e^(−0.74 × 1.4)) |
| all three at tier 3, stacked | **943** | wire.gd says "a little under a thousand" |

The cap is 1,100 for every body. A tighter one for each genome is still left out (B.6).

**The re-entry wound rule: on, the owner's decision of 2026-09-25.** A player who leaves the pond and comes back within 30 s keeps the old wound and gets no fresh grace. As built, the new body is the one that left, carried on as if it had stayed in the water:

- **Its wound** is the one it left with, mended for the time it was away (`CellBody.mended`).
- **Its grace** is whatever was left of the old one, less the time away, and never below zero.

So leaving and coming back never leaves a body less wounded, or with more grace, than staying would have. A body that leaves after its 42 s have run out -- most of them -- comes back with none.

A body is fresh, as before B, in three cases: the connection's first arrival, a return after a death, and a re-entry after more than 30 s away. An arrival that never happened (no state frame ever put it in the water) and is asked for again gets the grant the first would have had.

The rule is `REENTRY_KEEPS_WOUND` in referee.gd, a one-line change back if play shows it feels wrong. The probe holds both settings to their rule (B.5). It is per connection (B.6).

### B.3 Latency, jitter, and what honest builds do

**No honest guest was fouled, measured.** Every row is real ENet over real sockets unless it says otherwise.

| Run | What ran | Fouls, and the closest calls |
|---|---|---|
| net_probe, `pond` | Two real runs through every stage of a pond's life: arrivals, a swallow each way, a tier-3 mouth brought in by a re-entry, a division on real meals, a kill, and deaths with returns | **0** over 2 referees in each of three runs: 184-187 state frames, 16 PERSONs, 6 ENTERs, 1 SISTER, 3 DIEDs and 0-2 calls. Movement 9-12%, heading 8-10%, arrivals 34%, bodies 25% |
| net_probe, `server` | The dedicated server and two guests, restaged the same way | **0** over 5 referees in each of three runs: 271-284 state frames, 19 PERSONs, 11 ENTERs, 3 DIEDs and 1 call. Movement 1%, heading 8-14%, calls 50%, arrivals 33%, bodies 25% |
| net_lag `--pond --swim=120 --link=rough --swimmer=guest` | The guest swims for 120 s, and its frames reach the host through `rough`: 10-50 ms of flight, 5% loss, and a 5% chance of a 100-250 ms spike | **0** over 2,158 state frames, 14 calls, 2 bodies, 1 arrival. Movement 1.0%, heading 11.1%, calls 50.0%, arrivals 25.0%, bodies 19.0%. Fastest 166 of 1,100 u/s, sharpest turn 0.59 of 1.50 rad/s, radius +0.00. 2,304 frames reached the host and 133 were lost |
| R2, socket-free | A tier-3 body at the physical peak for 60 s, moved by cell.gd's own physics, encoded through `Wire.state`, through a model of `rough` | **0** over 1,017 state frames and 4 calls. Fastest 788 u/s. Movement 7%, heading 18%, calls 50% |
| relay harness, phone pair | About 100 s through `relay2.py`, with jitter alone and again with 2% loss | **0** over 1,310 and 1,312 state frames, and 17 calls, 13 ENTERs, 50 PERSONs and 12 DIEDs each. Movement 1.8-1.9%, heading 9.7-11.1%, calls 50%, arrivals 25%, bodies 24.2-24.4% |
| relay harness, server | The same, with two guests at once | **0** on all four referees: 1,320-1,349 state frames, and 17 calls, 12-13 ENTERs, 46-51 PERSONs and 12 DIEDs each. Movement 1.6-2.2%, heading 11.1-13.9%, bodies 24.2-24.4% |
| older guests | Through the relay with 2% loss: a +108 guest (`17e5f09`, main before B) and a +104 guest against the new phone host, and the new server with one of each | **0** on all four: 1,264-1,315 state frames, and 17 calls, 12-13 ENTERs, 47-52 PERSONs and 12 DIEDs each. Movement 1.9-2.4%, heading 10.3-14.8% |
| a host stall | The phone host frozen (SIGSTOP) for 1, 2, 3 and 4 s, 7 s apart, with the guest swimming in its pond | **0** over 869 state frames and 6 calls. Movement 4.3%, heading 7.9%, and the gate clean |
| the exported server | This tree's Linux Server export, the binary CI builds, with two guests through the relay with 2% loss for 68 s, each dying five times and coming back | No `[net]` line but each guest's `done after ... over budget 0, points 0, fouls 0` |

The relay runs use the harness from #61 (`relay2.py`): every datagram is held for 5-40 ms, and one in twenty for 150-250 ms more, in order. Each run is about 100 s, and each guest wears an `ampulla`, so it shouts. Its bodies swim on their own impulses, starve every 13 s, are taken by the host's water every 17 s, and come back from the black. **Every host's gate and every guest's stayed at zero** -- no strike, no drop, no cut, no refusal -- and every `done after` line said `over budget 0, points 0, fouls 0`. In the referee's own count, not one rule was even broken (`called` stayed empty), so none was held back by the once-per-0.5-s limit either.

**Two quirks of every protocol-4 build**, found by these runs and never fouled:

1. **The dead body, described once more.** After a death, the guest's `pond.gd` (`_watch_worn`) compares the dead cell's genome with the born one it has just announced, and sends the difference as a PERSON, between its ENTER and its ARRIVE. That is a stale body, not a change. The referee ignores a PERSON that is not the arrival's until the guest says its born body again, which every build does once its new cell is alive, or until 10 s after the returning body's first frame (`STALE_FOR`). A stale body that looks like a gift is taken, then undone when the born body is said again. Builds +104 to +108 do this, and so does this one. The fix belongs in the guest's `_watch_worn`, and would change nothing a host can rely on while older builds are still in the water.
2. **A call that reaches nothing.** On the way back from the black, a guest whose dead cell wore an `ampulla` pulses once with the new body's reach, which is none: `normal_mode.gd` refreshes the water's ping range and period only once its cell is alive again. No receiver plays such a call (`_hear_others` skips a reach of 0), so the referee drops it without a word.

**The checks that could hurt an honest player, and why they hold:**

| Check | The risk | Why it holds |
|---|---|---|
| movement | State frames are unreliable and arrive in bunches after a delay | 1.5 s held at 1,100 u/s: a guest at the physical peak (943 u/s) can have its frames held about 1.8 s before a clamp. A host stall is credited up to 10 s. A guest is held after 1.2 s of a quiet host. The deepest draw measured anywhere is 12% |
| radius | The grown radius could arrive before the ATE that grew it | The host raises its expectation when it *sends* the ATE. Measured: never a hundredth over |
| division | The SISTER is reliable and the mother's last OUT frames are not | **Measured, and why OUT is judged as a division begins:** in the probe's own division, a SISTER landed before the mother's last OUT frame, which the plan's rule would have fouled as OUT at r28.28 |
| ENTER, the rate | A guest eaten as it comes back asks again every two or three seconds | A loud death shuts in 0.9 s (a 0.15 s strike and a 0.75 s collapse), a tap during the collapse is honoured then, and a returning cell is in the water, and edible, from that tap. **Measured:** the probe's pond section sends four ENTERs in five seconds, which the plan's two-then-one-every-3-s refused. The built budget's closest call there is 34% |
| ENTER, after a leave | A host takes events before state frames, so the state frame saying the guest left is read after the PERSON and ENTER that follow it, in the same frame | **Added:** `_settle`. Before an event is judged, a body whose guest's POND bit has gone, and which is not waiting to arrive, is let go, as `_carry_guest` would at the end of the frame. Only a lost state frame can still make one honest arrival look early, which is the 1 point the rule allows for |
| SHOUT | Shouts bunch; a new body calls at once; a resent shout lands behind newer frames | Two banked plus one per new body; the place is checked against 4 s of the path |
| the gift | The player can hold the free sample, and the menu can be open | Once a body, with no time limit |
| re-entry | A player who steps out of the host's water and back within 30 s | Comes back as the body that left (B.2): the owner's decision |

### B.4 What B changes, by function

- **`game/net/referee.gd`** (new): the checks above. `Budget`; `judge_enter`, `arrive`, `judge_person`, `judge_sister`, `judge_died`, `judge_shout` and `claim` for what the guest says; `ate`, `died`, `left` and `stalled` for what the host did; `take_fouls`. `credit_meals` is for tools: it records meals a tool skipped and switches no check off. `SISTER_DISTANCE` (560), `DAUGHTER_RADIUS` and `FIRST_SENSES` are written out, because pond.gd cannot preload the run; the probe holds each to the run's own.
- **`game/net/pond.gd`:**
  - `Guest.referee`, made by `_new_guest` and `_new_referee`. `referee_of(id)` and `referees_made` (the newest eight) are for tools.
  - `_step_host` makes the phone's referee on the first frame the link is up and drops it with the link. It stops at a cut, and after carrying the state frame it judges the frame's shouts (`_judge_heard`). `_step_dedicated` skips a guest a foul has cut.
  - `_host_hears`: `_settle` first; then each branch asks the referee, charges its fouls, and acts on the answer.
  - `_host_enter` tells the referee that a body which never arrived has left, then calls `arrive` after `place_person`, and writes a re-entry's wound and grace over the fresh person's.
  - `_carry_guest` runs the newest track entry through `claim`, and `set_person_in_water` and `place_person` get its answer.
  - `_drop_person` records a leave with its wound and grace (`_leave`); `_on_person_touched` records every ATE it sends; `_on_person_died` records the death.
  - Added: `_mind_stall`, `_charge`, `_peer_of`, `_gone`, `_judge_heard`, `_shout_heard`, `_settle`, `_leave`.
- **`game/net/net_session.gd`:** `strike(id, weight, why)`, `enforce_referee`, `Guard.fouls`, the `fouls` and `referee_*` counters in `gate_counts`, and `, fouls N` at the end of the `done after` line (docs/server.md).
- **`game/normal/`:** no change. `food.gd` still trusts what pond.gd hands it; the referee sits in front of it.
- **`tools/net_probe.gd`** and **`tools/net_lag.gd`**: B.5.

### B.5 net_probe and net_lag

**The restages.** The pond section did things no player can do, and the plan named three of them. The build found a fourth.

- **The mid-life tier-3 mouth is an arrival.** The guest leaves the pond, takes the mouth while alone, and swims back in (`_pond_reenter`): "the guest leaves the pond, grows a tier-3 mouth alone and swims back in 0.92 s, and the host takes the body it arrives with". The server section brings in the second guest's palp and both tier-3 mouths the same way.
- **r40 is reached on real meals.** `_pond_feed` poses a drifter at the tip of the guest's lip bow, in the host's water, until the host has fed it to r40: "the guest grows to r40 on 3 meals the host's water fed it". The tip, because a tier-3 mouth is hollow where `Cilia.mouth_reach` points, and a morsel posed there was never eaten. The probe did not need `credit_meals`.
- **The 480 u pins are 900 u/s glides** (`POND_GLIDE`), each with the line to the mouth cleared first (`_pond_clear_line`), so nothing is eaten on the way.
- **Added: the host makes the kill.** The probe used to put a KILLED straight into the guest's queue, which is a death the host never decided, and the guest's DIED for it one the referee reports as starving. The host's own field now takes the guest (`_person_gone`).

Both sections end by checking that the host's referees called **no foul** on either honest guest, over every referee the section made: 2 in `pond`, 5 in `server`.

**New tests.** The socket-free ones are a new section, `referee` (`_check_referee()`), which spends no frames. The ones that need a socket are another, `pond referee` (`_check_pond_referee()`), run straight after `pond`: a bare guest session, driven by hand as a modified client would be, arrives in a phone host's water, with the referee watched until R11. `--referee-only` runs the two alone.

| # | Test | Result |
|---|---|---|
| R1 | a 5,000 u teleport | One foul (movement, 2 points). The host moves the body 1,750 u, the budget and its slack. The honest frames after it foul nothing, and the host's place walks to them at the cap, 3.0 s later -- **changed from the plan's "about 1 s"**, because the applied place moves at 1,100 u/s and has 3,250 u to cover |
| R2 | a tier-3 body at the physical peak for 60 s through `rough` | 0 fouls over 1,017 state frames and 4 calls; fastest 788 u/s; movement 7%, heading 18%, calls 50% |
| R3 | 3 s of silence, then the frames at once; and a host that stalls 3 s | 61 frames at once, no foul; a body that swam 1,080 u during the stall, no foul |
| R4 | r36 with no meals; r30 after one ATE | r36 clamped to r26, 4 points; r30 taken |
| R5 | OUT at r30, on a socket | Kept in the host's water, 4 points, and a chewer bites it there |
| R6 | a SISTER with no division; a real one | Nothing placed, 4 points; the real division is the pond section's, with no foul |
| R7 | a new body mid-life after a bite; cytostome 1 to 3; the gift twice | Wound and grace as they were, 4 points; the mouth stays at 1, 4 points; the first gift taken, the second refused, 4 points |
| R8 | five ENTERs in a second while swimming here | No ARRIVE, no arrival's genomes (an arrival resends all 40), the wound as it was; 2 points, once each half second |
| R9 | DIED, swallowed by the friend, while still alive | The body removed, reported as starving; 2 points |
| R10 | a shout from 3,000 u away; one with the wrong reach | Neither reaches the host's membrane, 1 point each; an honest shout is marked on it |
| R11 | a radius cheat on every frame, enforced | Cut 1.02-1.07 s after its first lie, and the guest reads `REFUSE_BROKEN`'s "cut off" |

Beside them, socket-free: a division's tail landing after its SISTER; a sister off the ring; a mother back in the water undivided; a daughter whose SISTER never comes; each stale-body case, including a stale body that looks like a gift and one that lands late; eight bodies in a burst; ENTER legality after a death; the re-entry rule under **both** settings; ten radius lies in 0.3 s making one foul; and 2,000 u after a 3 s host stall making none. Each is one PASS line.

**A cheating guest process, cut.** A scratch harness ran a real guest of this build through the relay with 2% loss, and 8 s after it arrived it began to lie:

| The lie | Cut after the first lie |
|---|---|
| r40 on every frame, fed nothing | 1.28 s by a phone host; 1.13 and 1.12 s by the server, two cheaters at once |
| a 3,000 u jump on every frame | 3.32 s by a phone host; 2.72 and 2.95 s by the server |
| a 3,000 u jump every 0.5 s | 3.70 s by a phone host; 5.18 and 7.07 s by the server |

Each was refused with `REFUSE_BROKEN` ("cut off") and barred for 60 s. The exported server, the binary CI builds, cut two radius liars 1.47 and 1.28 s after their first lies. A radius lie weighs 4 points. A jump weighs 2, each rule is charged at most once every 0.5 s, and the ledger forgets a point a second, so no mover is cut in much under 3 s. A mover that jumps exactly as often as that limit lands some jumps inside the half second after its last foul, which are counted but not charged, and lasts longer. The jump buys nothing from its first frame: the host's place for it walks at 1,100 u/s (B.6).

**Frames.** The whole probe, as CI runs it, three times over: `ALL PASS` each time, with 274 PASS lines (245 on `17e5f09`) and no error or warning line, in 10,200, 10,247 and 10,310 frames and 87.2, 85.9 and 86.4 s, where `17e5f09` took 8,474 frames and 73.9 s. CI stops at 20,000. `referee` spends no frames and `pond referee` 808-816; for the restages, `pond` grew from 3,238 frames to 3,608-3,619 and `server` from 806 to 1,366-1,451. The comment on ci.yml's LAN step still says 8,500-8,900 frames and seventy to seventy-five seconds; this PR does not edit workflows.

**net_lag gains `--swimmer=guest`**: the guest swims, and its frames reach the host through the same link model (`LaggedHost`, a host session that sends every frame it reads through the link before `_on_peer_packet` sees it). It prints the referee's fouls, each budget's closest call, and the fastest speed, sharpest turn and largest radius claimed. The default, `--swimmer=host`, is what it was.

### B.6 What B does not do

The plan's three still hold:

- **An arriving guest's genome cannot be checked.** A guest that swaps in from solo play brings a body the host never saw grow, so a maxed genome is legal; only structural bounds apply. The same goes for its size, up to r40. Having the host own each guest's lineage would be a design change, not hardening.
- **Movement stays the guest's to decide** (shared-pond.md §1.1). The host caps it at what physics allows and does not simulate it, because that is the latency #53-#55 removed.
- **The guest never learns where the host placed it.** A clamped cheater plays in water the host disagrees with. For a cheater that is the right outcome; an honest guest never gets there.

And these, found building it:

- **The speed cap is the same for every body.** A newborn cheater can swim at the tier-3 peak, and anything up to 1,100 u/s is never fouled at all. A cap for each genome is still the obvious next step, and the probe's 900 u/s glides are ready for it.
- **A mover is cut in about 3 s at the soonest** (B.5), where a radius lie is cut in about 1 s. That is the plan's weight of 2, kept: the host's place walks at the cap from the first frame, so a jump gains nothing while the cut is coming. Weighting a jump far past what the budget held at 4 would cut a jumper as fast as a radius lie. That is a one-line change, but it is the owner's to make, because movement is the check a bad link can trip.
- **A sister's heading and genome are taken as sent.** Her place and size are checked. A division draws the daughters' genomes from the mother's DNA, which the host can no more check than an arrival's.
- **The re-entry rule is per connection.** A guest that hangs up and calls again is new to the referee, as it is to A's ledger, and its first arrival is fresh. Carrying bodies across connections means the host remembering them by address. Calling back costs a whole handshake, and a guest cut by the ledger is barred for 60 s anyway.
- **After a death, for up to 10 s, a PERSON that is neither the born body nor the dead one is ignored without a foul** (the first quirk's window). Nothing ignored is applied, so it gains a cheat nothing.
- **Real Wi-Fi.** As for A, two phones on real Wi-Fi for 30 minutes remain to be run. The referee's budgets are the only ones here timing can trip -- movement, heading, calls, arrivals and bodies -- and the relay runs above stand in for that playtest without being it. An honest guest fouled there is a bug in these numbers: set `enforce_referee` to `false` and read the `[net] would foul` lines.

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

**Before each merge** (merging publishes a release): net_probe prints `ALL PASS`, and there is no pending launcher sync. **Two phones on real Wi-Fi for 30 minutes** -- zero strikes and zero drops in the host's log, no `[net] would` line, and `over budget 0` on every `done after` line -- was the gate for anything that enforces a limit only timing can trip. For A the owner waived it and shipped the budgets enforced (A.4), and B's fouls ship enforced the same way (B.1); the playtest still decides whether their numbers stand, and watch mode is the switch if they do not. The A PR carries `Closes #58` and `Closes #56`, the B PR carries `Closes #57`, and #59 stays open until C2 lands.

### Files

- **Part A (built):** `game/net/net_session.gd`, `game/net/wire.gd`, `game/net/lan.gd`, `tools/net_probe.gd`, `docs/server.md`, the comment on `.github/workflows/ci.yml`'s LAN step, and this document.
- **Part B (built):** `game/net/referee.gd` (new), `game/net/pond.gd`, `game/net/net_session.gd`, `tools/net_probe.gd`, `tools/net_lag.gd`, `docs/server.md`, and this document. `game/normal/` is untouched.
- **Part C:** to be decided by the table in C.3.
