# Net hardening: limits, a referee, and what an open port needs

This plan covers issues #56, #57, #58 and #59. It has three parts:

- **A** is one PR for #58 and #56 (frames, budgets, admission). **Built, and reviewed.** This part now describes what was built on `main` at `956d586`, what its review found and how each was fixed (marked "after review"), the measurements it rests on, and each place the build differs from the plan and why. The budgets ship enforced, the owner's call; watch mode stays as a switch (A.4).
- **B** is one PR for #57 (the host checks what a guest says). **Built, and reviewed.** This part now describes what was built on top of `17e5f09` (`main` when B began), what its review found and how each was fixed (marked "after review"), the measurements it rests on, and each place the build differs from the plan and why. The fouls ship enforced, and `enforce_referee` is the watch switch (B.1). The re-entry wound rule is on, the owner's decision of 2026-09-25 (B.2). The rules the referee judges by are fingerprinted in `Wire.RULES` (B.2).
- **C** is one PR for #59 (friends outside the house, by invite). **Built.** The owner chose C2 and all four rows of C.3 as recommended. This part keeps the options and the facts they were chosen on (C.1-C.3, with what building it found about them), then describes what was built on top of `4643520` (`main` when C began), the measurements it rests on, each place the build differs from the plan and why, and what it does not do (C.4-C.11). The screens that use it are specified in `docs/design/invites-ux.md` and built separately.

Part C's plan was written against `main` at `d84bfb6`; as built, it names functions, as A and B do, because they outlive a line number.

- **D** is one PR for #91 (a fuzzer for everything that reads what a stranger sends). **Built.** `tools/net_fuzz.gd`, its saved cases, and a CI step that runs both. It changes no game code: it is a check on A, B and C, and says what it covers and what it does not (D.1-D.6).
- **E** is one PR for #103 (strangers keeping the internet door's waiting room full). **Built.** The room makes room for a newcomer, every caller that leaves it unproved is barred, a /56 of barred /64s is barred as one, and a call the door cannot take spends no one else's place (E.1-E.5). A and C are corrected where it changes them, each pointing here.
- **F** is one PR for #104 (a phone host answering a carrier's other subscribers). **Built.** A phone hosts only where its friend can be with it -- never on cellular data -- and its door answers its own /24 alone (F.1-F.3).
- **G** is one PR for #105 (a LAN listener that ENet closes by itself). **Built.** The host says so, lets that listener's guests go and opens it again at once, and the internet listener's guests play on (G.1-G.4).
- **H** is one PR for #106 (invite pastes). **Built.** An invite's address says what it dials, and a paste costs the engine's log four lines at most (H.1-H.4).

The order was A, then B, then C. A carried a guard that made "LAN-only for now" true in the code; C lifts it on one listener, the dedicated server's second, and nowhere else.

## 0. Rules this plan follows

- **Content only.** Every change is GDScript, so no `binary_version` bump. The two ideas that would force one (scanning a code with the camera, a native crypto library) are rejected in C.2.
- **No PROTOCOL bump in A, B or C.** C's new kinds and reason exist only on a listener no protocol-4 build can reach (C.5). A's only new wire value is one refusal reason, `REFUSE_BROKEN`, and every protocol-4 build shows a reason it does not know generically, as "refused" over "the other end hung up" (`Wire.reason_says`, and `_take_refuse`'s last branch). That was checked in the code of all four protocol-4 releases, +104 to +107, and run against a hardened host (A.7).
- **Nothing personal.** Addresses here are documentation ranges (RFC 5737: 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24; RFC 3849 for IPv6: 2001:db8::/32). Keys, invites and server addresses live in `user://` on the device that needs them. A caller's real address appears only in a server's log, which is not the repository.
- **The launcher is not ours.** Nothing here touches `addons/launcher/` or `ci/`.
- **Run it, do not guess.** Every number is derived from a constant in main or a line in 4.7-stable. Where reading the source is not enough, the item is marked **measure first** (A.9), and C's were measured before it was built (C.1).
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
2. **Size cap by direction**, before any byte after byte 0: a guest's frame may be 272 bytes (`Wire.GUEST_OTHER_MAX`, the longest PERSON), a host's 1,262 (`Wire.HOST_FRAME_MAX`, `POND_MAX`). Above it, a host cuts the guest at once and bars its address, with no strike count; a guest drops the frame. An empty frame is malformed.
   - **One kind may go further, since protocol 6: a greeted guest's SISTER**, to 1,342 bytes (`Wire.SISTER_MAX`, also `Wire.GUEST_FRAME_MAX`, the absolute ceiling `_take_datagram` checks first). Her list rides in it (automation.md §10.3).
   - To find a SISTER, `Wire.guest_cap` reads byte 0 and the event's type, byte 5, of a frame past 272, which always has them. It reads nothing else.
   - Before the handshake, anything past 272 is still the oversize cut, whatever its type.
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
| EVENT SISTER 0x08 | guest→host | 22-1,342 | Since protocol 6 (automation.md §10.3): 6 + 13 + the tiers she wears + her DNA in the same format (each at most `TIERS_MAX`, 145) + a count of rules to `MOST_RULES` (8) + each line as 1 + at most `RULE_BYTES_MAX` (128) bytes of `RULE_BYTES`. A real one is under a kilobyte: today's longest line is 87 bytes. The only guest frame allowed past 272 (A.2, step 2). Before protocol 6: 20-164. |
| POND 0x06 | host→guest | 8-1,262 | `POND_MAX` = 8 + 68 × 18 + 30 |
| unknown kind or type | either | within the direction cap (a guest's: 272) | dropped (A.2, step 7) |

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

**The limits** (`_admit`), checked in `_on_peer_connected` before any bookkeeping is created, in an order chosen so that a caller who is barred or not on this network spends nobody else's budget, and **a call its own address's bucket turns away never spends the bucket every address shares**. **Changed by #103 (E.1):** every call is counted against its own address first, and the shared bucket pays only for a call the door takes -- one turned away for its address's transports or for want of room spends nobody else's place; the first build also spared a call the shared bucket turned away its own token, which no longer holds. **Fixed after review:** the first build spent the shared bucket first, so one device calling more than ten times a second locked every other device out. The review reproduced it -- twelve calls from one address, then a first-ever call from another, refused as busy -- and T8 now checks exactly that.

| Limit | Phone host | Server | Why |
|---|---|---|---|
| **LAN-only guard:** the source must be loopback, RFC 1918, 100.64/10, 169.254/16, the host's own /24, or IPv6 loopback, ULA or link-local | on | on for the LAN listener; the internet listener (C) asks for an invite instead | Makes "LAN-only for now" true in code. A forwarded port, or a public IPv6 address the router lets through, hits the guard and is refused with one log line. The host binds the wildcard address, so IPv6 is otherwise open wherever a router allows inbound IPv6. A phone host, since #104, answers its own /24 alone (F). 100.64/10 is allowed because lan.gd counts carrier-grade-NAT Wi-Fi as a home network, and it is also Tailscale's range (C1). The own-/24 rule is there because this container's own address is 192.0.2.2. `Lan.is_local_source(address, own)`. |
| **A peer id of 2 or more** (issue #75) | on | on, on both listeners | ENet takes whatever id a caller offers, and a host addresses every frame by id through `set_target_peer`, where 0 means every peer and a negative id every peer but one. Godot's own builds pick theirs from 2 up, so anything lower is refused at the door, before a frame could be addressed to it, and `_to` never sends to one. Measured on 4.7: ENet drops a caller offering 0 or 1 by itself, but a negative id reached the door, and before this it became a peer |
| ENet slots (`create_server`) | 4 | 6 | `_slots()` = one per guest, the two pending callers, and one half-dead predecessor per guest. Each slot can hold up to 32 MiB of ENet buffering, so no more than this. (The server had 5 before.) |
| greeted guests | 1 | 2 | Beyond this, REFUSE_FULL with its sentence, as before |
| pending (not greeted) | 2 | 2 | A third is cut on arrival (`PENDING_MAX`) -- on the internet listener, unless the elder of the two has proved nothing in 1.5 s, and then the elder goes instead (`EVICT_AFTER`, E.1) |
| handshake grace | 3 s | 3 s | `HELLO_GRACE`, unchanged; a real guest's first frame is its HELLO |
| new connections per address | 1 per 3 s, **burst 8** | same | `CALLS_*`. See below. |
| transports per address | 3 | 3 | Two friends on one NAT, plus a retry (`LIVE_PER_ADDRESS`) |
| new connections, all addresses | 10/s | 10/s | Bounds the cost of a storm from many addresses |
| bars | 60 s after an abuse cut; 10 min for a second one within 10 min | same | "Already two" is not abuse, and on the LAN nor are silence, a protocol refusal or, **changed**, speaking before the handshake (below). On the internet listener every way out of the waiting room without a proof bars -- an old protocol for a minute only -- and a /56 is barred as one once three of its /64s are (E.1). |
| address book | 1,024 entries | same | The limiter's own memory is bounded. Nothing is forgotten until the book is full; then a caller idle for 10 min (`BOOK_IDLE`) goes first, then the one heard from longest ago, and a barred one only if every entry is barred. |

**The guard is a second line, not the first** (issue #69, measured on the exported server in two network namespaces). It takes the host's own /24, which on a public address is a neighbour's at the provider -- a phone at 203.0.113.9 joined a server at 203.0.113.1 with no invite -- and it judges addresses as they arrive, so a router that forwards 45771 and rewrites the sender to its own LAN address makes the whole internet look local. The first line is outside the process: the router forwards nothing to 45771, and `server/nftables-internet.conf` drops what reaches 45771 from outside the home ranges -- the same phone, with it loaded, reached nothing, and one on 192.168.50.0/24 joined as before (docs/server.md §5). **Binding 45771 to the LAN address alone was weighed and not done** -- on the server, and since #104 on a phone either (F.1): that address can change under DHCP while the server runs, and a socket bound to the old one would go deaf; loopback callers -- every net_probe section, and tools on the machine -- would be shut out; and a router's forward arrives at that very address, so it would stop nothing the rule does not.

IPv6 callers are keyed by their /64 (`Lan.source_key`), and on the internet listener a /56 of barred /64s is barred as one (`Lan.wider_key`, E.1). The address book, the buckets, the bars and the log limiter belong to each `host()` call and are cleared by `_reset_socket`. That is also what keeps net_probe's many loopback hosts independent of each other.

**Where the build differs, and why:**

- **The per-address burst is 8, not 4.** The probe's existing server section calls six times from one loopback address in about six seconds (two guests, a third refused "already two", a fourth after one leaves, and two more at the end). With a burst of 4 and one call every 3 s it passed or failed on the runner's speed: it needed about 1.7 tokens for the last pair, and got them only if the section took long enough. A burst of 8 covers the section with no refill at all. What it costs is four more calls in a burst from one LAN address, each of which still meets the pending cap, the transport cap and the grace timer.
- **Speaking before the handshake is a cut, not a bar** -- on the LAN. A port scanner or a confused non-Biogenic client does exactly that, the pending cap and the per-address bucket already bound its cost, and T6 needs a real guest from the same address to join straight after. An oversize frame and a ledger cut do bar. On the internet listener it bars too, since #103 (E.1): no Biogenic build speaks out of turn there.
- **`Lan.is_local_source()` sits beside `_range_rank`, not `_is_private`.** #62 replaced `_is_private` with `_range_rank`, which ranks addresses and refuses none; the guard refuses and ranks none, and its comment says so. It parses IPv6 itself: compressed or in Godot's eight-group form, with a zone or a dotted IPv4 tail, and an IPv4-mapped address is judged as the IPv4 it is.

### A.6 Telemetry

All of it goes through one helper, `_note(what, key, line)`. It prints at most one line per (what, address) every 10 s (`NOTE_EVERY`), and the next line says how many like it were held back. **Added:** a refusal that is about everybody -- a caller from outside the network, or the door taking no calls from anywhere -- is keyed by its reason instead of its address, so a storm from a thousand addresses is one line every 10 s, and the helper only ever remembers callers the door let near it. **Since #103 (E.1)**, so is a waiting room with no place, and **every refusal on the internet door**, where a stranger comes from as many addresses as it likes. Its own memory is bounded by `NOTES_MAX`, 256 kinds-and-keys: when it is full, every hold that has ended goes, and if none has, the one that ends soonest. With the door letting at most ten callers a second near it, that last never happens in practice, but the bound no longer depends on it.

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
[net] refused 203.0.113.9: not on this network -- a call from outside needs an invite, on port 45772
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
- **A barred address can still knock.** The door judges a caller only once ENet has finished its handshake, and the bar is checked before the call buckets, so a barred address can complete handshake after handshake -- each refused at once, the line printed once every 10 s -- and, by never finishing one, can hold every one of the 4 or 6 ENet slots until ENet gives up on it (5-30 s), which keeps every new caller out for as long as it keeps at it. A guest already playing keeps its slot. Only something below GDScript refuses before the handshake: on the server box, a firewall rate limit per source (C.11, and docs/server.md §9.6); on a phone, nothing.
- **An ENTER is answered with about seventy reliable events.** A.4 lets a guest send five events a second, and every ENTER makes the host queue an ARRIVE, a PERSON and up to 68 GENOMEs (about 10 KB) back to it, all reliable, so a guest that acknowledges slowly grows ENet's send queue for as long as it keeps asking. While the budgets are watched, not even the five a second bounds it: only the host's own frame rate does. B's ENTER limit (four at once, then one every 2 s, B.2) bounds it either way.
- **Watched budgets take a flood whole** (A.4). Memory stays bounded -- the queue caps are enforced, and ENet reads at most 256 datagrams a poll -- and the lines are rate-limited, but every frame of a flood is read, parsed and taken until the budgets are turned on.
- **The server's updater waits for an empty pond**, and a caller still saying hello counts (docs/server.md: "nobody connected, and nobody connecting"). A hostile device on the LAN that keeps calling can therefore hold an update back, one call every 3 s after its burst. That is the updater's definition of empty, and it is left as it is -- on the LAN. On the internet listener (part C) a caller counts only once it has proved an invite (C.4), and one that proves nothing in time is barred (C.5).
- **IPv6 could not be run here.** This container has no IPv6 at all, so the guard's IPv6 rules are checked on a table (T11) and against Godot's `IPAddress` string form, but no IPv6 caller has reached a host.
- **Measured on 4.7-stable in this container, 2026-09-24:**
  1. **Cutting a peer inside `peer_connected` with packets already queued is safe.** Four hostile raw `ENetConnection` clients sent 40 packets each in the same datagram as the ACK that completes the handshake. In a control run with no cut, they arrived in the same frame as the connection. With `get_peer(id).peer_disconnect_now()` inside the handler, none were delivered, `peer_disconnected` fired on the next frame, and each hostile client saw its disconnect. The server stayed up, and an ordinary client joined afterwards and exchanged 209 packets, with no error lines, through SceneMultiplayer and through the `ENetMultiplayerPeer` read directly alike. T6 keeps this as a regression check, with its own control.
  2. **`_check_link`'s timing checks with the host reading its own socket:** unchanged, three runs of three, for the route alone (A.1) and again for the build as it stands: 45 places in 2.2 s, 44 frames, a beat of 0 then 3, a dash drawn 13.8-13.9 ms after it started; the pond's quiet host held the guest at 1.207-1.216 s of silence and let it go 2 frames after it resumed.
  3. **Budgets on a real link.** Two phones on real Wi-Fi for 30 minutes remain to be run. The owner chose to ship the budgets enforced before that (A.4), on the strength of the relay runs in A.7: real ENet over real sockets, through 5-40 ms of flight with 5% spikes of 150-250 ms, with and without 2% loss.

## B. #57 in one PR: the host checks what the guest says

**Built, and reviewed.** This part describes what was built on top of `17e5f09` (v0.2.0+108, `main` when B began), which already had A, the dedicated server with two guests (#62) and the pinned ENet throttles (#63). It gives the measurements the build rests on, each place the build differs from the plan and why (marked **changed from the plan**), and what the review found and how each was fixed (marked **after review**). The plan was written against `d84bfb6`, and its line numbers are gone from this part, which names functions instead. The fouls ship **enforced**, like A's budgets, and `enforce_referee` is the watch switch (B.1). The re-entry wound rule is **on: the owner's decision of 2026-09-25** (B.2).

There is no wire change and no PROTOCOL bump, and the PR is content only. `game/normal/` changes in two ways, both after review: a comment at every constant the referee judges by (B.2), and one new line a cut guest is shown (B.1). **The single-player identity gate** (shared-pond.md §5) was run against `9ce89a9`, the build as first reviewed: all six fingerprints identical, `field_diff` `ALL EQUAL` over 486,830 checks, and the four seed-7 renders at 0 pixels at both shapes and in both views, with `9ce89a9`'s own three runs diffing to 0 first.

### B.1 Where the checks live

A new file, **`game/net/referee.gd`**, holds them. It is RefCounted and preloaded, with no class_name, like wire.gd.

- **One referee per guest.** On a phone host there is one per connection: made on the first frame the link is up, and dropped with the link, so a reconnected guest is new to the referee as it is to A's ledger. On the dedicated server there is one per guest record, which is one per person slot (68 or 69) for as long as that guest holds it.
- **It answers, and the host acts.** Every guest input goes in through a `judge_*` call or through `claim`, and comes back as what the host should do: take it, take a clamped copy, or leave it. Each broken rule is queued as a foul with its weight.
- **pond.gd hands every foul to the ledger at once** (`_charge`), through the new public `strike(id, weight, why)` on `net_session.gd`, which feeds A's `_strike`. So a foul can cut a guest in the middle of a frame. After every charge, pond.gd asks `_gone(g)` and hears nothing more from a guest that has been cut: not the rest of its events, not its state frame, not its shouts.
- **It holds no scene.** Every call takes the time and the facts it needs, so net_probe drives it with no socket and no tree (B.5).
- **A host stall is not a teleport.** When a host frame comes more than 0.25 s after the last, pond.gd hands every referee the gap, up to 10 s of it, past each budget's hold (`_mind_stall`). These are A.4's `STALL_GAP` and credit, for A.4's reason: what lands after a stall is the backlog of a host that could not listen.
- **`enforce_referee := true`** on `net_session.gd` is the switch, shaped like `enforce_budgets`. Off is **watch mode**: a foul costs no points. It is counted (`referee_would_strikes`, `referee_would_points` and `referee_would_cuts` in `gate_counts`) and logged as `[net] would foul ...`, and at ten points as `[net] would cut ...`.
  - **Changed from the plan:** the verdicts stand in both modes, refusals as well as clamps. **Watch mode stops a cut, not a verdict.** A clamp or a refusal is the host deciding about its own water, and by itself it cuts nobody. A verdict that is wrong for an honest guest is a bug in its rule, and is fixed in the rule -- as the division during a host freeze was, after review (B.3) -- where waving refusals through while watching would only have hidden it: the `[net] would foul` lines are how the field finds one.
- **Changed from the plan: a phone host's shouts are checked in pond.gd, not in `normal_mode.gd`.** A phone host's session keeps a guest's shouts in `heard`, and the run drains them later in the same frame (`_hear_others`). pond.gd judges each shout the frame it lands (`_judge_heard`) and takes the refused ones out of `heard` before the run reads it. It remembers the ones it lets stand, by identity, so a shout the run has not drained yet -- because its cell is dead, or held -- is not judged or charged twice. The dedicated server asks the same question before it relays a shout to the other guest (`_shout_heard`). That is why `game/normal/` needed no change for it.
- **After review: a cut is said as a cut.** A guest cut by the gate or the referee saw its host's water end as if the host had gone -- `their water is gone · this one is yours` -- though it is barred for 60 s. Its run now says **`cut off from their water · this one is yours`** (`normal_mode.gd`'s `LINE_CUT`, the eighth pond line of shared-pond-ux.md §0.4). The run asks pond.gd's `cut_off()`, which reads the reason the session was refused with (`refused_for`, new): `REFUSE_BROKEN` is a cut. A single-player run never reaches it: it is on the take-over path, behind the session.

The ledger is A's (A.4): points decay at one a second, and ten cut the guest with `REFUSE_BROKEN` and bar its address for 60 s. **Each rule fouls at most once every 0.5 s**, however many frames break it, so a cheat that lies on all twenty state frames a second is struck twice a second, not twenty times.

### B.2 Every guest input, checked

| Input | The host's check, as built | On violation |
|---|---|---|
| **STATE: place** | A movement budget on the path the guest *claims*. It refills at 1,100 u/s, holds 1,650 u, and allows 100 u of slack. **Anchored at the arrival:** the budget is emptied when the host places the body, and the first claimed place is measured from where the host put it -- or from the arrival before, if that one never happened, since its ARRIVE may be the one that lands. The next frame is measured from the claim, not from the clamped place, so one late frame cannot foul twice. The place the host *applies* follows the claim through a second budget with the same numbers. | The host's place walks toward the claim at 1,100 u/s at most. 2 points |
| **STATE: heading** | The same, at 1.35 rad/s with **half a turn (π) held** -- 1.5 before review. A heading is read the shorter way round from the last, so no one frame can claim more than half a turn, and with the bank full no frame fouls however long the ones before it were held. **After review:** at 1.5, a tier-3 cirrus at full steer was fouled after an uplink-only stall of 1.5 s in 27 of 40 seeds, and in all 40 from 1.8 s; at π, in none of 40 at any stall from 0.8 s to 8 s. The heading the host applies follows on the same numbers, so an honest turn is applied as claimed: 1.35 rad/s, and from a full bank up to half a turn at once (B.6). **Added:** 0.05 rad of slack, two steps of the wire's one-byte heading, so rounding never fouls. | Turned toward the claim at the cap. 2 points |
| **STATE: velocity and turning** | Speed clamped to 1,100 u/s, turning to 1.5 rad/s, both zero while out of the water | Clamped, no foul |
| **STATE: radius** | Never over the host's expectation + 0.05. The expectation starts at the ENTER's radius and gains 4 for every ATE the host *sends*, up to 40. After a SISTER it is 28.284, plus 4 for every meal sent since the mother was last seen out. Decreases are always allowed. **Changed from the plan:** after an arrival that is not a return from a death, the first state frame's radius is taken, up to 40: a guest swimming alone eats during the round trip of its own swap, and an arriving body is one the host never saw grow (B.6). **Added:** a claim under r26 is raised to 26, with no foul. | Clamped to the expectation. 4 points |
| **STATE: OUT** | **Judged as a division begins:** an OUT phase may start only when the expectation is 40. While out, the body is out of the water, its place frozen (±2 u) and its motion zero. **Changed from the plan:** every later OUT frame of a phase that began legally is that division's own tail, bounded at r40 even after the SISTER has set the daughter's expectation. The SISTER is reliable and the mother's last OUT frames are not, and they travel on different channels, so the SISTER can land first -- and in the probe it did (B.3). A phase ends in a SISTER, a death, a leave, or a daughter's frame (under r39) whose SISTER lands within 5 s. **After review:** a division whose OUT frames the host never saw is proved by its SISTER instead (the SISTER row), and the OUT frames that land after it are its tail. **Not bounded in time, on purpose** (#102): a division's choice has no timeout and no default (`normal_mode.gd`'s `_step_choosing`), so an honest player can stay out of the water, choosing, for as long as they like. | OUT under r40: kept in the water, 4 points. A move while out: held still, 4 points. Back in the water undivided, or a daughter whose SISTER never came: 4 points |
| **SHOUT** | With the guest's body in the host's water: `at` within 650 u of any place it claimed in the last 4 s -- **changed from the plan**, which measured the newest place only; a shout is reliable and a state frame is not, so a resent shout lands behind frames sent after it. The radius within the expectation. The reach exactly `PING_RANGE_BY_TIER` of the worn `ampulla`, or of the body before, for a shout sent before a new body that lands after it. The rate: one per ping period less 1 s, two banked, plus one after every new body, arrival or organ gained. With no body in the water, only the rate. **Added:** a shout reaching 0, or at r0, is dropped uncharged and never fouled (B.3, the second quirk). **#102:** in the water or out, a shout over r40 (±0.05) or reaching past 1,900 -- the top tier's -- is fouled: out of the water it was judged by the rate alone, and a listener holds a call's mark for as long as its caller's size says, so one at r3e38 held a mark for 4.8e36 s. The body before's reach counts for 4 s (`SHOUT_PAST`) after a new body, where it counted forever; and the new body's bonus is one a body -- a death, an arrival or a birth hands a new one -- however often a new body is said. Every listener also caps what it hears at r40 and 1,900 (`_hear_others`), since a guest has no referee over its host. | Dropped, so nothing is heard or relayed. 1 point |
| **ENTER** | Legal with no body here for this guest, or with one that has not arrived (no state frame with a body since its ENTER). Radius in [26, 40], ±0.01. **Changed from the plan:** only the *first* ENTER after a death must be r26, so no guest can be locked out -- a guest that left the water as the host killed it never heard the kill (a contact is not obeyed out of the pond) and comes back as the body it still is. **#102:** after a death the guest said itself (DIED), which it cannot have missed, every ENTER must be r26 until one arrives, so a refusal can no longer be spent to come back full-grown; and four are banked, then one every 2 s, where the plan had two and then one every 3 s (B.3). What an accepted ENTER's body carries is the re-entry rule's, below. | Not answered: no ARRIVE, and the guest asks again after `REACH_TIMEOUT`, as for a lost ENTER. 1 point |
| **PERSON** | Two a second, six banked. Every slot names a worn gene, once -- **changed from the plan:** a worn gene may have no slot, since the gift can be dropped over a slot another worn organ still sits in (genome.gd's `place`). `new_body` is legal with no body in the water, with one that has not arrived, or once after a SISTER, which is a birth. **#102:** a birth only within 5 s of its SISTER (`BIRTH_WAIT`) -- the daughter's PERSON is sent in the same frame as it -- where one could be held back and spent at any time; and with a body placed and not yet arrived, its tiers are taken but it is not renewed, so the arrival's wound and grace stand: an honest build says its new body before its ENTER, and one said after it was a way round the re-entry rule. Otherwise the worn tiers must be the host's, but for the gift -- **made exact:** one of the four first senses (`ocellus`, `ampulla`, `chemocyte`, `stigma`) at tier 1, once a body. **Added:** the stale body every build describes after a death (B.3, the first quirk). | A `new_body` out of turn: applied as `false`, 4 points. An escalation or a bad order: ignored, the old body kept, 4 points. Over the rate: ignored, 1 point |
| **SISTER** | Once for each division. **After review, a division is known three ways:** *seen*, an OUT at r40 began it; *unseen*, its OUT frames and its SISTER landed in one host frame (B.3) -- taken when the body is here, has arrived and has been fed to r40, which is everything one OUT frame would have proved; and *owed*, seen, and its body died or left before the SISTER landed, within 5 s of going -- a SISTER lost on the way lands a resend later, and the daughter can be eaten in between. Radius exactly 28.284, ±0.05, and 560 u from where the host froze her mother, ±20 -- except on the unseen path, where where she stopped was never seen, so her place is taken as sent, **within the ring's width of anywhere her mother could have swum since her last frame** (#102: the movement budget, a stall credited; farther, put there, 2 points). A place so far off that float32 squares its distance to inf is off the ring, and still put on it rather than on her mother. Heading and genome as sent (B.6). | Out of turn: nothing placed, 4 points. Off the ring or the wrong size: put on the ring at r28.284, 2 points |
| **DIED** | With a body here, the body goes: dying is the guest's right. Only starving (cause 3, by nobody) is the guest's own death to report. With none here, it is a death the host made itself, said again, and nothing. | Reported as starving. 2 points |

**The speed cap, from cell.gd's own tables**, with each organ at its fastest. The probe holds the stacked peak under the cap (`_referee_agrees`).

| Organ | Tier 0 / 1 / 2 / 3 (units per second) | Derived from |
|---|---|---|
| flagellum, impulses as often as allowed | 153 / 193 / 246 / 323 | `IMPULSE_SPEED_BY_TIER` / (1 − e^(−0.74 × gap_min)) |
| axoneme, held push | 0 / 81 / 115 / 155 | `PUSH_ACCEL_BY_TIER` / 0.74 |
| myoneme, a dash every cooldown | 0 / 295 / 372 / 465 | `DASH_SPEED_BY_TIER` / (1 − e^(−0.74 × 1.4)) |
| all three at tier 3, stacked | **943** | wire.gd says "a little under a thousand" |

The cap is 1,100 for every body. A tighter one for each genome is still left out (B.6). **After review**, the probe holds the heading cap the same way: 1.35 rad/s over the hardest turn the tables make, a top-tier `cirrus` flat out (1.02), the drift at its most (0.13) and a top-tier flagellum's kick to the nose as often as it beats (0.16 every 1.2 s): 1.28 rad/s.

**The rules are fingerprinted (after review).** A host judges its guests by its own copy of the game's rules, so a guest on other rules is fouled, then cut and barred: the review measured a content that grows five units a meal, instead of four, cut 1.05 s after its first meal by a host on this build. `Wire.RULES`, beside `PROTOCOL` in wire.gd, is the SHA-256 of **every value the referee judges a guest by or derives a limit from**, and of its own limits -- 55 of them: from cell.gd the radii, growth per meal, division, `MEND_SECONDS` and a sample of `mended()`, the ping tables, and the speed and turn tables its caps sit over; from food.gd the grace and the contact, cause and killer enums; from normal_mode.gd the sister's ring and the free senses; from genome.gd `TIER_MAX`, a born body, and the gift's tier, which is a literal and so is measured on a real genome; and every threshold, bank and window in referee.gd. `tools/net_probe.gd` recomputes it from the real constants (`_rules_text`) as the first check of its `referee` section (`_referee_rules`), and fails with *"a rule the referee judges by changed: bump Wire.PROTOCOL and update Wire.RULES in the same commit"* until both are done. Two builds on different rules are then refused at the handshake, with the sentence that names the update, instead of cut in the middle of a game. Every judged constant in `game/normal/` carries a one-line comment that says so. Measured: with `GROWTH_PER_MEAL` at 5 in a scratch copy, the check fails with that sentence; on the tree, it passes.

**The re-entry wound rule: on, the owner's decision of 2026-09-25.** A player who leaves the pond and comes back within 30 s keeps the old wound and gets no fresh grace. As built, the new body is the one that left, carried on as if it had stayed in the water:

- **Its wound** is the one it left with, mended for the time it was away (`CellBody.mended`).
- **Its grace** is whatever was left of the old one, less the time away, and never below zero.

So leaving and coming back never leaves a body less wounded, or with more grace, than staying would have. A body that leaves after its 42 s have run out -- most of them -- comes back with none.

A body is fresh, as before B, in three cases: the connection's first arrival, a return after a death, and a re-entry after more than 30 s away. An arrival that never happened (no state frame ever put it in the water) and is asked for again gets the grant the first would have had.

The rule is `REENTRY_KEEPS_WOUND` in referee.gd, a change back of that one line if play shows it feels wrong -- and, since the probe fingerprints it with every other value the referee judges by, of `Wire.RULES` with it (above). The probe holds both settings to their rule (B.5). It is per connection (B.6).

### B.3 Latency, jitter, and what honest builds do

**Found in review: a division during a host freeze.** A phone host that stops for longer than a guest's out window -- at least 4.4 s, pinch to birth -- and less than ENet's timeout of about 8 s (an app switch, a call screen) hears the whole division at once when it wakes: the OUT frames, the SISTER and the new body in one frame. A host takes events before it carries state frames, and carries only the newest of the two it keeps, so the referee judged the SISTER with no division begun (4 points) and the new body as out of turn (4 more, 8 of 10). The sister was never placed; the daughter was never renewed, so she kept her mother's wound and grace and serial; her genome was refused for the rest of her life; and the host went on expecting r40. The reviewer's two-process harness, which feeds a real guest to r40 and lets it divide, reproduced it at 4.8 s and 6.8 s on a phone host; rerun here against `9ce89a9`, it reproduced at 4.8 s on a phone host and on the dedicated server alike. **Fixed** by the unseen path (B.2): after the fix, the same freezes place the sister, renew the daughter and expect her at r28.28, with no foul, on both kinds of host; so do the same runs with no freeze. The rarer variant -- a SISTER lost and resent, and the daughter eaten in between -- is the owed path, held by the probe (B.5).

**No honest guest was fouled once that was fixed, measured.** Every row is real ENet over real sockets unless it says otherwise.

| Run | What ran | Fouls, and the closest calls |
|---|---|---|
| net_probe, `pond` | Two real runs through every stage of a pond's life: arrivals, a swallow each way, a tier-3 mouth brought in by a re-entry, a division on real meals, a kill, and deaths with returns | **0** over 2 referees in each of three runs: 184-188 state frames, 17 PERSONs (one of them, after review, a real run's gift), 6 ENTERs, 1 SISTER, 3 DIEDs. Movement 9-10%, heading 2-14%, arrivals 34%, bodies 25% |
| net_probe, `server` | The dedicated server and two guests, restaged the same way | **0** over 5 referees in each of three runs: 272-285 state frames, 19 PERSONs, 11 ENTERs, 3 DIEDs and 1 call. Movement 1%, heading 2-10%, calls 50%, arrivals 33%, bodies 25% |
| net_lag `--pond --swim=120 --link=rough --swimmer=guest` | The guest swims for 120 s, and its frames reach the host through `rough`: 10-50 ms of flight, 5% loss, and a 5% chance of a 100-250 ms spike | **0** over 2,153 state frames, 14 calls, 2 bodies, 1 arrival. Movement 1.2%, heading 5.4%, calls 50.0%, arrivals 25.0%, bodies 19.1%. Fastest 166 of 1,100 u/s, sharpest turn 0.59 of 1.50 rad/s, radius +0.00. 2,302 frames reached the host and 133 were lost |
| R2, socket-free | A tier-3 body swimming flat out for 60 s, moved by cell.gd's own physics, encoded through `Wire.state`, through a model of `rough`; and a body held at the 943 u/s bound itself for 60 s through the same | **0** over 1,017 state frames and 4 calls: fastest 788 u/s, because the game's own physics never lines every speed-up up at its peak at once (after review: the plan called this body "at the physical peak", and it is not). Movement 7%, heading 18%, calls 50%. **0** over 998 frames for the body at 943 u/s, closest call 27% |
| a division in a frozen host | The reviewer's harness: a phone host feeds the guest to r40 on real meals, the guest divides and leans, and the host is frozen (SIGSTOP) from before the pinch until after the birth, 4.8 s and 6.8 s; then the same on the dedicated server; and each with no freeze | Before the fix: 2 fouls, 8 of 10 points, on either kind of host. **After: 0** in all six, each with the sister placed and the daughter renewed |
| real divisions through the relay | The same harness through `relay2.py`, the guest swimming and fed on real meals, dividing, its daughter fed to r40 and dividing again: a phone host and the server, with jitter alone and with 2% loss, 60 s each | **0** in all four, two divisions and two sisters placed in each, every `done after` line `over budget 0, points 0, fouls 0` |
| relay harness, phone pair | About 100 s through `relay2.py`, with jitter alone and again with 2% loss | **0** over 1,313 and 1,358 state frames, and 17 calls, 13 ENTERs, 51-52 PERSONs and 12 DIEDs each. Movement 2.0-2.1%, heading 10.9-13.9%, calls 50%, arrivals 25%, bodies 24.0-24.4% |
| relay harness, server | The same, with two guests at once | **0** on all four referees: 1,288-1,372 state frames, and 17 calls, 12-13 ENTERs, 46-51 PERSONs and 12 DIEDs each. Movement 1.8-2.4%, heading 8.1-11.9%, bodies 24.0-24.4% |
| older guests | Through the relay with 2% loss: a +108 guest (`17e5f09`, main before B) and a +104 guest against the new phone host, and the new server with one of each | **0** on all four: 1,256-1,307 state frames, and 17 calls, 12-13 ENTERs, 46-51 PERSONs and 12 DIEDs each. Movement 1.7-1.9%, heading 9.3-13.3% |
| a host stall | The phone host frozen (SIGSTOP) for 1, 2, 3 and 4 s, 7 s apart, with the guest swimming in its pond | **0** over 868 state frames and 6 calls. Movement 6.0%, heading 7.4%, and the gate clean |
| the exported server | This tree's Linux Server export, the binary CI builds, with two guests through the relay with 2% loss for 68 s, each dying five times and coming back; before review and again after | No `[net]` line but each guest's `done after ... over budget 0, points 0, fouls 0`, both times |
| **#102's tighter rules** (the shout's size and reach out of the water, a new body only before its ENTER or at a birth, the born-cell rule after the guest's own death, one shout bonus a body, the last body's reach for 4 s, an unseen sister within reach of her mother) | Repeated after the change, on the same harnesses: net_lag rough for 120 s; the relay pair and the server, with jitter and with 2% loss, 100 s each; a +108 and a +104 guest against the new phone host and the new server; host stalls of 1-4 s; real divisions on a phone host and the server, with a 4.8 s freeze and without | **0 in every run**: net_lag 2,161 state frames, 14 calls, 3 bodies; the relays 1,785-1,855 state frames a guest, 87-95 events, every `done after` line `over budget 0, points 0, fouls 0`, old builds included; the stalls 975 frames; each division's sister placed and its daughter renewed, ledger 0 |

The relay runs use the harness from #61 (`relay2.py`): every datagram is held for 5-40 ms, and one in twenty for 150-250 ms more, in order. Each run is about 100 s, and each guest wears an `ampulla`, so it shouts. Its bodies swim on their own impulses, starve every 13 s, are taken by the host's water every 17 s, and come back from the black -- but that harness holds every body's radius, so **none of its bodies grows or divides**, which is how the division during a freeze got past it. The division rows above use the reviewer's harness, which feeds a real body on real meals. **Every host's gate and every guest's stayed at zero** -- no strike, no drop, no cut, no refusal -- and every `done after` line said `over budget 0, points 0, fouls 0`. In the referee's own count, not one rule was even broken (`called` stayed empty), so none was held back by the once-per-0.5-s limit either.

**Two quirks of every protocol-4 build**, found by these runs and never fouled:

1. **The dead body, described once more.** After a death, the guest's `pond.gd` (`_watch_worn`) compares the dead cell's genome with the born one it has just announced, and sends the difference as a PERSON, between its ENTER and its ARRIVE. That is a stale body, not a change. The referee ignores a PERSON that is not the arrival's until the guest says its born body again, which every build does once its new cell is alive, or until 10 s after the returning body's first frame (`STALE_FOR`). A stale body that looks like a gift is taken, then undone when the born body is said again. Builds +104 to +108 do this, and so does this one. The fix belongs in the guest's `_watch_worn`, and would change nothing a host can rely on while older builds are still in the water.
2. **A call that reaches nothing.** On the way back from the black, a guest whose dead cell wore an `ampulla` pulses once with the new body's reach, which is none: `normal_mode.gd` refreshes the water's ping range and period only once its cell is alive again. No receiver plays such a call (`_hear_others` skips a reach of 0), so the referee drops it without a word.

**The checks that could hurt an honest player, and why they hold:**

| Check | The risk | Why it holds |
|---|---|---|
| movement | State frames are unreliable and arrive in bunches after a delay | 1.5 s held at 1,100 u/s: a guest at the 943 u/s bound can have its frames held about 1.8 s before a clamp. A host stall is credited up to 10 s. A guest is held after 1.2 s of a quiet host. The deepest draw measured anywhere is 12%. **Measured after review:** the fastest body cell.gd's physics makes, every speed-up at tier 3 and dashing flat out, is not fouled by an uplink-only stall of up to 2.5 s in any of 40 seeds, and is fouled once -- 2 points, never a cut by itself -- in 3 of 40 at 3.0 s and in all from 3.5 s |
| heading | A guest turning hard through an uplink that stalls: its next frame claims the whole turn at once | **After review:** half a turn held (B.2). A tier-3 cirrus at full steer: no foul in any of 40 seeds at any stall from 0.8 s to 8 s, where 1.5 held fouled 27 of 40 at 1.5 s |
| radius | The grown radius could arrive before the ATE that grew it | The host raises its expectation when it *sends* the ATE. Measured: never a hundredth over |
| division | The SISTER is reliable and the mother's last OUT frames are not; a host that stops hears a whole division at once; a SISTER resent can land after its daughter was eaten | **Measured, and why OUT is judged as a division begins:** in the probe's own division, a SISTER landed before the mother's last OUT frame, which the plan's rule would have fouled as OUT at r28.28. **After review:** a division never seen is proved by its SISTER, and one whose daughter went is owed its sister for 5 s (B.2) |
| ENTER, the rate | A guest eaten as it comes back asks again every two or three seconds | A loud death shuts in 0.9 s (a 0.15 s strike and a 0.75 s collapse), a tap during the collapse is honoured then, and a returning cell is in the water, and edible, from that tap. **Measured:** the probe's pond section sends four ENTERs in five seconds, which the plan's two-then-one-every-3-s refused. The built budget's closest call there is 34% |
| ENTER, after a leave | A host takes events before state frames, so the state frame saying the guest left is read after the PERSON and ENTER that follow it, in the same frame | **Added:** `_settle`. Before an event is judged, a body whose guest's POND bit has gone, and which is not waiting to arrive, is let go, as `_carry_guest` would at the end of the frame. Only a lost state frame can still make one honest arrival look early, which is the 1 point the rule allows for |
| SHOUT | Shouts bunch; a new body calls at once; a resent shout lands behind newer frames | Two banked plus one per new body; the place is checked against 4 s of the path |
| the gift | The player can hold the free sample, and the menu can be open | Once a body, with no time limit |
| re-entry | A player who steps out of the host's water and back within 30 s | Comes back as the body that left (B.2): the owner's decision |

### B.4 What B changes, by function

- **`game/net/referee.gd`** (new): the checks above. `Budget`; `judge_enter`, `arrive`, `judge_person`, `judge_sister` (which takes whether the body is here, after review) and `_sister_placed`, `judge_died`, `judge_shout` and `claim` for what the guest says; `ate`, `died`, `left` (both now owing an open division its sister, `_owe_sister`) and `stalled` for what the host did; `take_fouls`. `credit_meals` is for tools: it records meals a tool skipped and switches no check off. `SISTER_DISTANCE` (560), `DAUGHTER_RADIUS` and `FIRST_SENSES` are written out, because pond.gd cannot preload the run; the probe holds each to the run's own.
- **`game/net/pond.gd`:**
  - `Guest.referee`, made by `_new_guest` and `_new_referee`. `referee_of(id)` and `referees_made` (the newest eight) are for tools.
  - `_step_host` makes the phone's referee on the first frame the link is up and drops it with the link. It stops at a cut, and after carrying the state frame it judges the frame's shouts (`_judge_heard`). `_step_dedicated` skips a guest a foul has cut.
  - `_host_hears`: `_settle` first; then each branch asks the referee, charges its fouls, and acts on the answer.
  - After review: `cut_off()`, for a guest's run: its session was refused with `REFUSE_BROKEN`.
  - `_host_enter` tells the referee that a body which never arrived has left, then calls `arrive` after `place_person`, and writes a re-entry's wound and grace over the fresh person's.
  - `_carry_guest` runs the newest track entry through `claim`, and `set_person_in_water` and `place_person` get its answer.
  - `_drop_person` records a leave with its wound and grace (`_leave`); `_on_person_touched` records every ATE it sends; `_on_person_died` records the death.
  - Added: `_mind_stall`, `_charge`, `_peer_of`, `_gone`, `_judge_heard`, `_shout_heard`, `_settle`, `_leave`.
- **`game/net/net_session.gd`:** `strike(id, weight, why)`, `enforce_referee`, `Guard.fouls`, the `fouls` and `referee_*` counters in `gate_counts`, and `, fouls N` at the end of the `done after` line (docs/server.md). After review, `refused_for`: the reason a guest was last refused with.
- **`game/net/wire.gd`:** after review, `RULES` (B.2).
- **`game/normal/`:** after review, comments only at each judged constant -- in cell.gd, food.gd, normal_mode.gd and genome.gd -- and in normal_mode.gd `LINE_CUT` and the one line in `_take_over` that picks it (B.1). `food.gd` still trusts what pond.gd hands it; the referee sits in front of it.
- **`tools/net_probe.gd`** and **`tools/net_lag.gd`**: B.5.

### B.5 net_probe and net_lag

**The restages.** The pond section did things no player can do, and the plan named three of them. The build found a fourth.

- **The mid-life tier-3 mouth is an arrival.** The guest leaves the pond, takes the mouth while alone, and swims back in (`_pond_reenter`): "the guest leaves the pond, grows a tier-3 mouth alone and swims back in 0.92 s, and the host takes the body it arrives with". The server section brings in the second guest's palp and both tier-3 mouths the same way.
- **r40 is reached on real meals.** `_pond_feed` poses a drifter at the tip of the guest's lip bow, in the host's water, until the host has fed it to r40: "the guest grows to r40 on 3 meals the host's water fed it". The tip, because a tier-3 mouth is hollow where `Cilia.mouth_reach` points, and a morsel posed there was never eaten. The probe did not need `credit_meals`.
- **The 480 u pins are 900 u/s glides** (`POND_GLIDE`), each with the line to the mouth cleared first (`_pond_clear_line`), so nothing is eaten on the way.
- **Added: the host makes the kill.** The probe used to put a KILLED straight into the guest's queue, which is a death the host never decided, and the guest's DIED for it one the referee reports as starving. The host's own field now takes the guest (`_person_gone`).

**After review: a real run's gift.** With the mid-life mouth now an arrival, nothing in CI sent the referee the one change a worn body makes in play. The pond section now hands the guest's run its free sense the way the run does (`_step_sense_grant`: a sample held, a slot made) and places it as a player does, so what reaches the host is the run's own PERSON: "the guest's free sense, a stigma, placed as a player places it, is on the host's person 0.01 s later -- its referee took the run's own PERSON as the gift, with no foul".

Both sections end by checking that the host's referees called **no foul** on either honest guest, over every referee the section made: 2 in `pond`, 5 in `server`.

**New tests.** The socket-free ones are a new section, `referee` (`_check_referee()`), which spends no frames. The ones that need a socket are another, `pond referee` (`_check_pond_referee()`), run straight after `pond`: a bare guest session, driven by hand as a modified client would be, arrives in a phone host's water, with the referee watched until R11. `--referee-only` runs the two alone.

| # | Test | Result |
|---|---|---|
| R1 | a 5,000 u teleport | One foul (movement, 2 points). The host moves the body 1,750 u, the budget and its slack. The honest frames after it foul nothing, and the host's place walks to them at the cap, 3.0 s later -- **changed from the plan's "about 1 s"**, because the applied place moves at 1,100 u/s and has 3,250 u to cover |
| R2 | a tier-3 body swimming flat out for 60 s through `rough`; after review, and a body held at the 943 u/s bound | 0 fouls over 1,017 state frames and 4 calls; fastest 788 u/s -- the physics never reaches the bound -- movement 7%, heading 18%, calls 50%; and 0 over 998 frames at 943 u/s, closest call 27% |
| R3 | 3 s of silence, then the frames at once; and a host that stalls 3 s | 61 frames at once, no foul; a body that swam 1,080 u during the stall, no foul |
| R4 | r36 with no meals; r30 after one ATE | r36 clamped to r26, 4 points; r30 taken |
| R5 | OUT at r30, on a socket | Kept in the host's water, 4 points, and a chewer bites it there |
| R6 | a SISTER with no division; a real one | Nothing placed, 4 points; the real division is the pond section's, with no foul |
| R7 | a new body mid-life after a bite; cytostome 1 to 3; the gift twice | Wound and grace as they were, 4 points; the mouth stays at 1, 4 points; the first gift taken, the second refused, 4 points |
| R8 | five ENTERs in a second while swimming here | No ARRIVE, no arrival's genomes (an arrival resends all 40), the wound as it was; 2 points, once each half second |
| R9 | DIED, swallowed by the friend, while still alive | The body removed, reported as starving; 2 points |
| R10 | a shout from 3,000 u away; one with the wrong reach | Neither reaches the host's membrane, 1 point each; an honest shout is marked on it |
| R11 | a radius cheat on every frame, enforced | Cut 1.02-1.07 s after its first lie, and the guest reads `REFUSE_BROKEN`'s "cut off" |

Beside them, socket-free, and first, the rules fingerprint (B.2) and the caps held over the tables. Then: after review, a division never seen -- fed to r40, never seen out, its SISTER and new body heard before its OUT frames, with and without OUT frames left to land -- taken with no foul, the daughter renewed; a second SISTER, one at r38 and one from a body not here, each fouled; a SISTER resent after her daughter was eaten, placed on the ring with no foul, and one later than 5 s, fouled; six arrivals asked for and never made keeping only the newest two anchors; a division's tail landing after its SISTER; a sister off the ring; a mother back in the water undivided; a daughter whose SISTER never comes; each stale-body case, including a stale body that looks like a gift and one that lands late; eight bodies in a burst; ENTER legality after a death; the re-entry rule under **both** settings; ten radius lies in 0.3 s making one foul; and 2,000 u after a 3 s host stall making none. Each is one PASS line.

**A cheating guest process, cut.** A scratch harness ran a real guest of this build through the relay with 2% loss, and 8 s after it arrived it began to lie:

| The lie | Cut after the first lie |
|---|---|
| r40 on every frame, fed nothing | 1.28 s by a phone host; 1.13 and 1.12 s by the server, two cheaters at once |
| a 3,000 u jump on every frame | 3.32 s by a phone host; 2.72 and 2.95 s by the server |
| a 3,000 u jump every 0.5 s | 3.70 s by a phone host; 5.18 and 7.07 s by the server |

Each was refused with `REFUSE_BROKEN` ("cut off") and barred for 60 s, and each cut guest's run now says so (B.1). The exported server, the binary CI builds, cut two radius liars 1.47 and 1.28 s after their first lies. Run again after review: a radius liar cut 1.47 s after its first lie by a phone host, 1.20 and 1.58 s by the server, and 1.25 and 1.38 s by the exported server; a jumper on every frame, 3.05 s. A radius lie weighs 4 points. A jump weighs 2, each rule is charged at most once every 0.5 s, and the ledger forgets a point a second, so no mover is cut in much under 3 s. A mover that jumps exactly as often as that limit lands some jumps inside the half second after its last foul, which are counted but not charged, and lasts longer. The jump buys nothing from its first frame: the host's place for it walks at 1,100 u/s (B.6).

**Frames.** The whole probe, as CI runs it, three times over after review: `ALL PASS` each time, with 279 PASS lines (245 on `17e5f09`, 274 before review) and no error or warning line, in 10,224, 10,615 and 10,301 frames and 84.6, 88.0 and 84.9 s, where `17e5f09` took 8,474 frames and 73.9 s. CI stops at 20,000. `referee` spends no frames and `pond referee` 807-816; for the restages and the gift, `pond` grew from 3,238 frames to 3,607-3,629 and `server` from 806 to 1,384-1,457. The comment on ci.yml's LAN step says so, and names both new sections.

**net_lag gains `--swimmer=guest`**: the guest swims, and its frames reach the host through the same link model (`LaggedHost`, a host session that sends every frame it reads through the link before `_on_peer_packet` sees it). It prints the referee's fouls, each budget's closest call, and the fastest speed, sharpest turn and largest radius claimed. The default, `--swimmer=host`, is what it was.

### B.6 What B does not do

The plan's three still hold:

- **An arriving guest's genome cannot be checked.** A guest that swaps in from solo play brings a body the host never saw grow, so a maxed genome is legal; only structural bounds apply. The same goes for its size, up to r40. Having the host own each guest's lineage would be a design change, not hardening.
- **Movement stays the guest's to decide** (shared-pond.md §1.1). The host caps it at what physics allows and does not simulate it, because that is the latency #53-#55 removed.
- **The guest never learns where the host placed it.** A clamped cheater plays in water the host disagrees with. For a cheater that is the right outcome; an honest guest never gets there.

And these, found building it:

- **The speed cap is the same for every body.** A newborn cheater can swim at the tier-3 peak, and anything up to 1,100 u/s is never fouled at all. A cap for each genome is still the obvious next step, and the probe's 900 u/s glides are ready for it.
- **A heading can be snapped half a turn at once** (after review). The heading the host applies has the same half turn banked as the check, so an honest guest's turn through a stalled uplink is applied as it was claimed, not dragged behind at 1.35 rad/s while the host decides its contacts with the wrong mouth. The price is that a cheat can turn its body on the host by up to half a turn in one frame once the bank is full, then 1.35 rad/s: a head start on aiming, once every 2.3 s or so.
- **A mover is cut in about 3 s at the soonest** (B.5), where a radius lie is cut in about 1 s. That is the plan's weight of 2, kept: the host's place walks at the cap from the first frame, so a jump gains nothing while the cut is coming. Weighting a jump far past what the budget held at 4 would cut a jumper as fast as a radius lie. That is a one-line change, but it is the owner's to make, because movement is the check a bad link can trip.
- **A sister's heading and genome are taken as sent.** Her place and size are checked. A division draws the daughters' genomes from the mother's DNA, which the host can no more check than an arrival's. **On the unseen path her place is taken as sent too** (after review): where her mother stopped was never seen. A cheat gains nothing there that one OUT frame at r40 does not already give it, since a mother can swim to anywhere 560 units from where it wants a sister.
- **The fingerprint cannot see a PROTOCOL bump.** It fails until `Wire.RULES` is updated, and its sentence says to bump `PROTOCOL` in the same commit, but nothing in code can tell a deliberate bump from an update of `RULES` alone. It makes a rule change deliberate; review makes it right. **Gone since protocol 8** (gene-catalogue.md §11.3): the handshake carries the fingerprint the game works out (`game/net/rules.gd`), so builds on other rules refuse each other by themselves, no `PROTOCOL` moves with a rule, and `Wire.RULES` is the pin that makes the change deliberate.
- **The re-entry rule is per connection.** A guest that hangs up and calls again is new to the referee, as it is to A's ledger, and its first arrival is fresh. Carrying bodies across connections means the host remembering them by address. Calling back costs a whole handshake, and a guest cut by the ledger is barred for 60 s anyway.
- **After a death, for up to 10 s, a PERSON that is neither the born body nor the dead one is ignored without a foul** (the first quirk's window). Nothing ignored is applied, so it gains a cheat nothing.
- **Real Wi-Fi.** As for A, two phones on real Wi-Fi for 30 minutes remain to be run. The referee's budgets are the only ones here timing can trip -- movement, heading, calls, arrivals and bodies -- and the relay runs above stand in for that playtest without being it. An honest guest fouled there is a bug in these numbers: set `enforce_referee` to `false` and read the `[net] would foul` lines.

## C. #59 in one PR: friends outside the house, by invite

**Built.** The owner chose C2 and all four rows of C.3 as recommended: a pasted invite with the server's certificate pinned and a secret for each friend; one invite per friend; the home Wi-Fi needs none; and a guest cut for cheating or garbage is told so in a sentence. This part describes what was built on top of `4643520` (`main` when C began), the measurements it rests on, each place the build differs from the plan and why (marked **changed from the plan**), and what it does not do.

It is content only, like A and B. There is **no PROTOCOL bump and `Wire.RULES` is unchanged**: the two new kinds and the new refusal reason exist only on a listener no protocol-4 build can reach, since it has no DTLS client and no way to enter an address (C.5), and nothing the referee judges by moved (net_probe's `_referee_rules` still passes). The LAN, and every phone host, is exactly as it was: the four taps, the port, the door, the gate and the referee. The screens are specified in `docs/design/invites-ux.md` and built separately, on the API in C.7.

### C.1 What Godot 4.7 offers, and what building it found

All of this was read in 4.7-stable and measured in this container. Where the build found something C's first reading did not, it is marked **found**.

- **ENet over DTLS: yes.**
  - `ENetConnection.dtls_server_setup(TLSOptions)` and `dtls_client_setup(hostname, TLSOptions)`, on `ENetMultiplayerPeer.host`, straight after `create_server` or `create_client` and before the first poll: they swap ENet's socket for a DTLS one, which only a socket nothing has read from allows (`thirdparty/enet/enet_godot.cpp`).
  - DTLS 1.2 through mbedTLS, **with cookies**: a spoofed ClientHello gets one stateless HelloVerifyRequest and never a slot. **Found:** the suite negotiated is `0xCCA8`, ECDHE-RSA with ChaCha20-Poly1305, read off the ServerHello by the relay (C.8) -- forward secrecy, and 29 bytes on every record (13 of header, 16 of tag).
  - DTLS is in the official Android 4.7 template (multiplayer.md §2), and the exported Linux server's (C.8).
- **The DTLS server's limits.**
  - **Found: its slots are the ENet host's peer count** (`host->peerCount`, 6 here), and a peer that has finished DTLS and connected to ENet keeps its DTLS slot. So with two guests and two callers waiting, two are left for handshakes; a caller that finds none has its half-made handshake dropped and retries on mbedTLS's own timer. The check reads `peers.size() < max_clients && HANDSHAKING || CONNECTED` -- a precedence slip that changes nothing in practice.
  - At most 16 new sources wait at once (`UDPServer`'s pending list). **Found:** `UDPServer.poll()` drains the whole socket every call -- not ENet's 256 datagrams -- into a 64 KiB queue per source, dropping past it, so a flood's memory is bounded by source.
  - A mid-handshake peer holds its slot for up to 8 s (`ENET_DTLS_TIMEOUT_MS`), and `refuse_new_connections` does work here: the build uses it while the listener closes.
  - Every handshake that fails prints an `ERR_PRINT` on the side that failed. **Found:** the server prints one for each datagram that is not a handshake (`-30464`, `-0x7700`, unexpected message) and for a handshake it had no slot for; the client prints one for a pin that does not match (`-9984`, X509 verify failed), and the server then another for the client's alert (`-30592`).
  - **Found: closing a DTLS listener prints three `godot_mbedtls_mutex_free` error lines**, every time. `CookieContextMbedTLS::clear()` never resets `inited`, so the server's `stop()` and its destructor free the same three mutexes twice (`modules/mbedtls/tls_context_mbedtls.cpp`, `register_types.cpp`). Harmless, and GDScript cannot avoid it. **Gone in 4.7.2:** the fuzzer closed 120 listeners under it and counted none (`docs/engine.md` §5).
- **What a DTLS client can observe** -- measured on loopback, 4.7-stable, in a scratch harness, three calls each, from the call to the status changing; `tools/net_probe.gd`'s C1-C8 hold the same, with the handshake or the second look on top (C.9):

  | Case | The client | Time |
  |---|---|---|
  | the pinned certificate, the right name | connected: ENet's first CONNECT goes out before DTLS is up and waits for its resend | 508-515 ms |
  | another certificate | `connection_failed`: status DISCONNECTED | 10 ms |
  | the right certificate under another name | the same | 9-10 ms |
  | **found:** a port nothing listens on | **the same** -- the DTLS client's UDP socket is *connected*, so it hears the ICMP port-unreachable, and the handshake fails at once | 2-3 ms |
  | a plain ENet listener (the LAN port) | still CONNECTING: the listener reads the handshake as garbage and says nothing | until given up |
  | a plain ENet client at the DTLS port | still CONNECTING, and one server error line per attempt: 5 in 8 s | until given up |
  | a certificate valid from 2090, or one that expired in 2021 | fails as another certificate does | 9 ms |

  **So "it failed fast" says a wrong server or a closed port, and ENet cannot tell which.** The guest takes a second look (C.7): a DTLS handshake with no pin, which any Biogenic server completes and a closed port refuses. **And mbedTLS checks both certificate dates** against the device's clock (`MBEDTLS_HAVE_TIME_DATE` is in Godot's configuration), which is why the server's certificate runs from 2020 to 2099.
- **No client certificates.** The server side is `MBEDTLS_SSL_VERIFY_NONE // TODO client auth.` DTLS proves who the server is and encrypts; the client proves itself inside, with the PROOF (C.5).
- **Pinning a self-signed certificate: yes.** `TLSOptions.client(chain, common_name_override)` verifies against exactly that chain and checks the name; `client_unsafe()` with no chain verifies nothing, which is what the second look uses. `Crypto.generate_self_signed_certificate` marks the certificate CA:TRUE, so it is its own anchor.
- **Pre-shared keys: no**, and **no ECDH, X25519 or big numbers**, so no password-authenticated key exchange. A typed password could be guessed offline by anyone who relayed a handshake; the invite's secret is random and never typed.
- **Crypto on the server: RSA only, and enough.** `generate_rsa` (16-290 ms for 2,048 bits here), `generate_self_signed_certificate`, `generate_random_bytes`, `hmac_digest` (8 µs for a proof), `constant_time_compare`. **Found:** `X509Certificate.save_to_string()` hands back its buffer's closing NUL and prints a Unicode warning every call; `save()` writes the same PEM without it, and the build uses that. `FileAccess.set_unix_permissions` sets 0600 on Linux and Android, and is a no-op on Windows.
- **Found: `create_client` given a host name resolves it on the calling thread** -- `ENetConnection.connect_to_host` calls `IP.resolve_hostname` (`modules/enet/enet_connection.cpp`), and a name not yet cached blocked the frame for 16 ms here, and would for as long as a slow DNS takes. `IP.resolve_hostname_queue_item` returned in 0.02 ms and resolved on the resolver thread. The build resolves there, and dials the address it gets.
- **SceneMultiplayer's own auth** is not used: the host reads its own socket since A, and the same job is two frames in net_session's handshake.
- **WebSocket with TLS** and **the clipboard** are as C.1 first found them. An invite is pasted with one button; there is still no text field.

### C.2 Four designs, and the one chosen

- **C1: a private network (WireGuard or Tailscale), with the game unchanged.**
- **C2: ENet over DTLS, with the server's certificate pinned from a pasted invite, and a per-friend secret proven inside the encrypted channel.** **Chosen.**
- **C3: no DTLS.** The same proof, then a truncated HMAC on every frame.
- **C4: WSS.** C2's pinning and proof over `WebSocketMultiplayerPeer` with TLS.

| | C1 VPN | C2 DTLS + pinned cert + invite | C3 HMAC only | C4 WSS |
|---|---|---|---|---|
| **Passive eavesdropper** | sees only WireGuard ciphertext | sees only DTLS ciphertext: ECDHE with ChaCha20-Poly1305, measured (C.1) | **reads everything**, which fails #59's encryption requirement | sees only TLS ciphertext |
| **Active man-in-the-middle** | defeated: both ends hold keys set up in advance | defeated from the first packet: the pin comes in the invite, not from first contact | cannot forge or alter frames, can drop and delay | defeated |
| **Stranger who can reach the port** | WireGuard does not answer | passes the cookie, costs one RSA signature, then must prove a secret within 3 s or be cut; floods from real addresses need a firewall limit (docs/server.md §9.6) | reaches ENet in plaintext | SYN cookies, TLS, then the proof |
| **What a player does** | installs a VPN app and turns it on to play | pastes the invite once, then taps call | pastes once | pastes once |
| **PROTOCOL bump** | no | no: the new frames exist only on the internet listener | yes, if the LAN carries MACs | no |
| **binary_version bump** | no | no: ENet DTLS, mbedTLS, Crypto and the clipboard are in the stock templates | no | no |
| **Costs** | a third-party app on every device | the engine's DTLS server has TODO-level limits and prints its errors; RSA only | its own crypto, no confidentiality | TCP head-of-line blocking: the 173 ms worst jump net_session measured |

**Rejected outright**, and still: scanning a code inside Biogenic (the CAMERA permission is a binary bump), a native crypto library (a GDExtension per architecture), and a typed password (a text field, and guessable offline).

### C.3 The owner's decisions

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | How do friends outside the house reach the server? | **a pasted invite, pinned and secret (C2) ✓ chosen** / a VPN app on every device (C1) / not yet: LAN only | Each friend pastes one message once, then taps to play. |
| 2 | One invite per friend, or one shared? | **one per friend ✓ chosen** / one shared | You can shut one person out without re-inviting everyone, and the log says who joined. |
| 3 | Does playing on the home Wi-Fi need the invite too? | **no, being in the house is enough ✓ chosen** / yes | LAN play works exactly as before, and older installs still join at home. |
| 4 | What does a guest the host catches cheating, or sending garbage, see? | **cut, with one line saying why ✓ chosen** / cut silently | The line helps an honest player whose install is broken. |

### C.4 The listener and its door

**One session, two transports, on the dedicated server only.**

- **`listen_internet(key, certificate)`** opens a second `ENetMultiplayerPeer` on `Invite.PORT`, 45772 -- next to `Lan.PORT`, 45771 -- with `dtls_server_setup(TLSOptions.server(key, certificate))` straight after `create_server` and before anything polls it. Only a host that greets more than one guest opens it, so a phone host never does. The server opens it when its first invite exists and closes it when none remain (C.6): **with no invites, nothing listens for the internet at all.**
- **Every peer records the listener it came in on** (`peer["via"]`, and `_via` for as long as ENet holds the id), and every send, cut, address lookup and throttle pin goes through that transport (`_to`, `_drop_now` and `_drop_on`, `_address_of`, `_steady_throttle`). `_pump` reads the LAN listener and then the internet one; a datagram from an id the listener does not hold here is a stray.
- **One set of peers.** `_peers` holds both, so the pond and `FoodField.GUESTS_MAX` count both: one LAN guest and one internet guest is an ordinary pond (C.9, L4). `peer_count()` and `guests()` are unchanged.
- **What the updater waits for is the pond's company, not its peers** (`company()`): every greeted guest, from either listener, and every caller on the LAN still saying hello -- a phone in the house in the middle of joining. **A caller on the internet listener counts only once it has proved an invite** and been greeted. The server used to tick its updater with `peer_count()`, which counts every caller; the review measured one silent DTLS caller every 4 s -- `client_unsafe`, no invite needed -- keeping it above 0 on 73% of frames, so a staged update never applied. Checked on the session (C.9, S9) and on the real server's tick (L5).
- **One id, one peer.** ENet makes each listener's ids unique and no more, so a newcomer whose id the other listener holds -- or is hanging up on -- is refused on its own transport, logged (`[net] refused <address>: its id <n> is taken on the other listener, and one id is one peer`) and counted (`refused_twin`), and the listener's later goodbye to that id is ignored. Never merged.

**Each listener keeps its own door** (`_admit(from, via)`): its own address book -- per-address call buckets and bars -- its own bucket for every address together, its own count of transports per address and its own waiting room of two. **Changed from the plan**, which gave only the waiting room and the all-callers bucket to each transport: a hairpinning router can show a LAN phone's own address on the internet listener, and on loopback every caller is one address, so per-address state shared across listeners could still let something arriving over the internet refuse a LAN caller. Now nothing can. The LAN-only guard is the LAN door's alone. Refusals on the internet door are counted twice, in `refused_*` and in `net_refused_*`, and logged as `[net] refused <address> on the internet listener: <reason>` -- one line a reason every 10 s, since #103. **The internet door's waiting room makes room** for a newcomer once its elder has waited 1.5 s, and a /56 of barred /64s is barred as one there (E.1).

**Closing it** (`close_internet`): every guest on it is cut with `REFUSE_INVITE` -- its invite opens nothing now -- and every caller still in its handshake is cut; `refuse_new_connections` goes on; the socket is closed `REFUSE_LINGER` later, so the refusals leave first, with the engine's three error lines (C.1).

### C.5 The handshake on the internet listener

**HELLO, then CHALLENGE, then PROOF, then WELCOME.**

1. **HELLO**, the frozen compatibility check, exactly as on the LAN. A protocol mismatch gets `REFUSE_PROTOCOL` and its sentence **before any authentication**: an old build is told to update, never to ask for a new invite. Since #103 it is barred for a minute as well, and never longer (E.1).
2. **CHALLENGE** (kind `0x07`, host to guest, 17 bytes): a fresh 16-byte nonce from `Crypto.generate_random_bytes`. Never sent by a LAN host.
3. **PROOF** (kind `0x08`, guest to host, 57 bytes): the invite's 8-byte key id, a 16-byte nonce of the guest's, and HMAC-SHA256 keyed with the invite's secret over `"biogenic proof 1"`, the protocol (two bytes, little-endian), the host's nonce, the guest's and the key id (`Invite.proof_mac`). Every piece is a fixed size. The secret never crosses the wire.
4. The host checks it with `Crypto.constant_time_compare` and greets -- or says "already two", which only a caller that proved an invite ever learns.

**The gate before the welcome** (A.2, step 3): a caller on the internet listener may send exactly one HELLO, then, once its CHALLENGE has gone out, exactly one PROOF of exactly 57 bytes. Anything else -- a STATE, an EVENT, a POND, a second HELLO, a PROOF before the CHALLENGE -- is a cut on the spot with no strike, as A cuts a caller that speaks before its hello, and since #103 a bar (E.1). `HELLO_GRACE`, 3 s, covers the whole exchange: a caller that says nothing, and one that says HELLO and then nothing, is told `REFUSE_SILENT` at 3 s and **barred at the internet door as a wrong proof is** -- a minute, ten for a second within ten minutes (C.9, S3). Without the bar, two addresses calling back every 3 s kept the internet waiting room (`PENDING_MAX`, two) full and every invited friend out; with it, their calls back are refused at the door and take no place (S10). **Since #103 (E.1)** a caller that hangs up before its grace is out is barred too -- before, one could hang up at 2.9 s and call straight back, never barred -- and so is one whose place a newcomer takes after 1.5 s. A real guest speaks the moment its transport is up and proves within a few hundred milliseconds; a friend on a link too poor for 3 s hears "they hung up · call again in a minute", which is the bar. On the LAN, silence is still not barred. Measured through the relay, the exchange takes about 0.3 s from the transport coming up (C.8). **After the welcome, a second PROOF** is a cut, told `REFUSE_BROKEN` and barred; on the LAN, where no CHALLENGE is ever sent, a PROOF is a malformed frame (4 points), like a second HELLO. `Wire.size_ok` and `Wire.known` carry both kinds, each from its own side only; a CHALLENGE from a guest is the wrong direction.

**A wrong proof.** A PROOF naming a key id the host does not have, and one whose mac does not check out, get the same answer: `REFUSE_INVITE` (`0x05`, the next reason after `REFUSE_BROKEN`), the linger, the hard cut, and a bar at the internet door -- a minute, ten for a second within ten minutes. **They are indistinguishable to the caller**: an unknown key id is checked against a random decoy secret, so both paths compute one HMAC and one constant-time compare. C2-C3 asserts that the two answers read the same, word for word, and prints how long each took: 0.54 s each at 100 frames a second, and 0.58-0.60 s at 50, in every run so far (C.9) -- measured, not asserted, since a runner's load would make a timing assertion fail on its own. The log says which, and names the label, never the secret:

```
[net] hung up on 1587052382 (198.51.100.4): no invite it could prove -- the wrong secret for the invite for sam -- barred 60 s
[net] hung up on 1587052382 (198.51.100.4): no invite it could prove -- a key id no invite has -- barred 60 s
[net] 694971552 (203.0.113.9) proved the invite for sam
[net] 694971552 (203.0.113.9, invite sam) done after 1800 s -- frames 51234, events 312, over budget 0, points 0, fouls 0
```

"Proved" is printed whatever the limiter says, like the farewell; every other line through `_note`. A guest from the internet is then held to everything A and B hold a LAN guest to: the same budgets, ledger, referee and cuts.

**The guest's side.** `_take_challenge` answers a CHALLENGE only on a call made by invite, only from its host, and only once; any other is dropped (`challenges_dropped`).

### C.6 Invites on the server

**The owner's jobs**, after `--`, in `game/server/invite_book.gd`: `--reach=<host>[:<port>]` (`[v6]:port` for IPv6), `--invite=<label>`, `--revoke=<label>`, `--invites`, and **`--new-key`** (changed from the plan: added, so replacing a leaked key is one job and not a file deletion by hand). Each does its job and exits -- 0 done, 1 refused with a sentence naming the fix -- without hosting, the updater or a port: traced on the exported binary, a job binds no UDP socket at all, where a server binds 45771 and 45772 (C.8). The owner runs them as the service's user (docs/server.md §9.1, `runuser -u biogenic -- env HOME=/var/lib/biogenic ...`).

**Root into another user's files is refused** (`InviteBook.ownership_refusal`, from the review). What root writes is root's and `rw-------`, so a server running as `biogenic` could not read it: the review ran a server as uid 65534 and a `--revoke` as root with `HOME` pointing at the service's directory, and the job said the friend would be dropped within seconds while the server went on with the book it had -- the friend swam on, and the revoked line got in again 9 s later. Now every job on Linux first reads who runs it, from `/proc/self/status` -- no process for that since issues #71 and #84 -- and, as root, who owns the book, `pond/`, `invites/`, `user://`, the directory it sits in and `$HOME` (one `stat`, a few ms); if any of them belongs to another user it does nothing and exits 1 with the command to run instead -- `runuser -u <that user> -- env HOME=<the same home> <this binary> --headless -- <the same job>`. Root in its own `user://` goes on, with a note that the service never reads that book. Godot cannot read a file's owner, hence the `stat`, and **a `stat` that cannot read every one of them fails closed**: the job refuses as though another user owned them (J2). It happens only on Linux; anywhere else the job goes on as before. Measured on the exported binary as the review did it: refused, exit 1 (C.8), and J1 holds the rule itself (C.9).

**What they keep**, under `user://` -- for the service, `/var/lib/biogenic/.local/share/godot/app_userdata/Biogenic` -- and nowhere else:

| File | Holds | Mode | Written by |
|---|---|---|---|
| `pond/key.pem` | the RSA-2048 key | 0600 | the first mint, or `--new-key` |
| `pond/cert.pem` | the self-signed certificate: `CN=biogenic-pond`, valid 2020-01-01 to 2099-12-31 -- on purpose, docs/server.md §9.8 | 0600 | the same |
| `pond/invites.cfg` | the book: per label, a 64-bit key id, a 128-bit secret, when it was made | 0600 | the jobs only |
| `pond/joined.cfg` | when each key id last came in | 0600 | the running server only |
| `pond/reach.cfg` | the address friends dial | 0600 | `--reach` |
| `invites/<label>.txt` | the line to send | 0600, in a 0700 directory | a mint |

**A new key and certificate are written in full before either replaces the old** (issue #89): each goes to a `.next` file through `Invite.write_private`, then the key is renamed over the old key and the certificate over the old certificate, last -- the running server loads the pair again when it sees the certificate change. A disk that fills, or anything else that stops the writes, leaves the old pair and the book as they were, where the first build could leave a new key beside the old certificate, which no invite could call (L10 fails that way against it). The job prints the new certificate's fingerprint -- the first eight bytes of SHA-256 over its DER, as `openssl x509 -fingerprint -sha256` begins -- and the server's listening line names the one it answers with, so the two can be matched.

**Every file is written through `Invite.write_private`**: made empty, set to 0600 while it holds nothing, filled in place, read back -- a full disk lets the write "succeed" and would otherwise rename an empty file over a good one -- and renamed over the old one in one step, so no secret is ever in a file anybody else could read, and a reader sees the old book or the new one and never half. One step is Linux's and Android's rename; on Windows, Godot 4.7 deletes the old file and then moves the new one, which matters only for a guest's kept invite there (C.11). `pond/` is made `rwx------` by whichever job comes first, `--reach` included, and a directory that cannot be made so is a refusal. **Changed from the plan: "last joined" is its own file**, written only by the server, so the server and a job never write one file and a mint is never lost to the server's older copy.

**A mint** needs `--reach` first, and refuses with a sentence naming it until then. The first one makes the key and certificate; a label that exists gets a new key id and secret, so the line sent before stops working, and says so; a new key voids every invite made with the old one, and says which. The book keeps `InviteBook.INVITES_MAX` (100) invites at most (issue #85): a new label past them makes nothing, naming the label and how many to revoke, while a label already in the book is always minted again -- and a book an older build grew past the cap keeps every invite it holds. A label is 1 to 24 of `a-z 0-9 - _` (an uppercase one is lowercased, with a line saying so). The line goes to `invites/<label>.txt`; **only its path is printed**, in the line `docs/design/invites-ux.md` §9 specifies, with the address it calls -- and a warning when that address is inside the house, which friends outside can never reach.

**The running server notices by itself.** Every 2 s (`INVITES_POLL`) it takes the modification time of the book and of the certificate, and reads them only when one changed -- **or when it was changed in the second it was last read in**: a file's time is whole seconds, so a second write inside that second leaves it as it was, and only the bytes can tell. Then (`_watch_invites`): the first invite opens the internet listener; an invite revoked or replaced cuts its guest with `REFUSE_INVITE`, not barred, since the owner decided (`set_invites`); none left closes the listener. It logs by label: `[server] invites: sam added`, `revoked`, `replaced`.

- **A new certificate** (`--new-key`) puts the old listener down with the linger, as `close_internet` does for the last invite going: its guests are told `REFUSE_INVITE` and read "invite no longer works", and the socket goes `REFUSE_LINGER` later. The next look comes just after that and opens a listener with the new key. The first build closed it at once, and `peer_disconnect_now` drops a refusal still queued, so a guest swimming there read "they hung up" (the review; L11 fails that way and passes this one). A LAN guest swims on through it all: that listener has no key. Between the old socket going and the new one opening, about a tenth of a second, a caller finds nothing there.
- **A book or certificate it cannot read fails closed** -- from the review, where the first build said so in one line and went on with the book it had. It may hold a revoke this server cannot see, so every guest on an invite is cut (`REFUSE_INVITE`), the listener closes, and the log says why, naming the file, this server's user and the `chown` that gives the files back; it is looked at again at every look, whatever its time says, since a `chown` changes none, and the listener comes back the look after it reads (L9; and on the exported binary as uid 65534 with a book root wrote, C.8). A directory the server may not look into counts as unreadable too.
- **While the listener is closing**, a look waits for it to go: opening a new one then would put the old down under its own refusals.

**The READY lines say what listens**, a third line after the LAN's two, and again whenever it changes:

```
[server] internet: nothing listens for the internet: there are no invites. To let a friend in from outside, set --reach, then --invite=<name> (docs/server.md).
[server] internet: listening on port 45772/udp for 2 invites (kit, sam), certificate 46:6C:97:79:19:7D:09:E3. Friends call 203.0.113.7:45772, which must reach this machine's 45772/udp: the [upnp] lines say whether the router forwards it, and if not, forward it by hand -- the one port to forward (docs/server.md §9.3).
```

The LAN's line still ends "LAN only: do not forward this port."; the five-minute line ends `-- internet: 2 invites` or `-- internet: off`, and since the UPnP forward (C.11) `-- upnp: forwarded`, `not forwarded` or `off`.

### C.7 The invite, and the call

**The line** (`game/net/invite.gd`):

```
biogenic-invite:<version>.<payload in base64>.<check>
```

- **The payload**, format 1: key id (8), secret (16), port (2, little-endian), the address (a length byte and up to 253 ASCII characters: an IP literal or a host name), and the certificate in DER (a two-byte length and the bytes).
- **The check**: eight hex characters of SHA-256 over `<version>.<payload>`, so a paste cut short or garbled is caught on the phone -- never a refused proof and a barred address -- and a garbled version digit is damage, not a newer build. **The envelope is frozen**: a later format changes the version and the payload, so this build can always tell a newer invite from a damaged one.
- **Standard base64**, not base64url: `_` is italics in several messaging apps and would not survive being shown.
- **1,055 characters** for an IPv4 address, 1,063 for a name -- 976 of them the certificate's 730 bytes. The plan's 1.3 KB was an estimate.
- **The parser** (`Invite.parse`) takes out everything a messaging app may put inside a long line -- spaces, line breaks, tabs, no-break and zero-width characters, soft hyphens, bidirectional marks -- then tries every `biogenic-invite:` in what is left, case-blind, and the first that reads whole wins; a message before or after is never read. It answers `Read.OK`, `NOT_FOUND`, `DAMAGED` or `UNKNOWN_VERSION`, each with its own sentence.

**The guest's session API**, for the screens (`docs/design/invites-ux.md`):

| Call | What it does |
|---|---|
| `Invite.parse(text) -> Dictionary` | `read` (an `Invite.Read`); on `OK` also `address`, `port`, `key_id`, `secret`, `der`, `certificate` and `line`, the invite written out clean |
| `Invite.keep(invite_or_text, path = Invite.KEPT) -> bool` / `Invite.kept(path) -> Dictionary` / `Invite.forget(path)` | the one kept invite, `user://invite.txt`, 0600; a paste that does not read leaves it as it was |
| `Invite.says(key) -> [heading, sentence]`, `Invite.says_read(read)` | every sentence, from `Invite.SAYS`: the designer's §6.2 and §6.3, keyed |
| `Invite.DOOR_NAME` | what the chooser calls the way in: `by invite`, until the owner names it (invites-ux.md §11) |
| `NetSession.call_invite(invite) -> bool` | the call: the same `Link` states as a LAN call, `trouble` and `because` from `Invite.SAYS`, and **`trouble_key`** saying which key |
| `NetSession.by_invite() -> bool` | whether a REACHING link is a far call (FAR_CALLING, not ANSWERING) |
| `NetSession.address`, `Invite.kept()["port"]` | the receipt: `address · port` |
| `NetSession.forget_refusals()` | for tools |

**How a call ends, by what the guest can observe:**

| Link | `trouble_key` | When |
|---|---|---|
| TOGETHER | `&""` | welcomed |
| FAILED | `no_invite` | nothing that reads was handed over |
| FAILED | `could_not_call` | at once: this device has no address but loopback and link-local (flight mode), or no socket -- or an IPv6 address on a network with none, where the second look cannot even aim a socket |
| FAILED | `no_such_place` | the host name has no address: asked for IPv4 and, only when it has none, for IPv6, within 6 s for both (`RESOLVE_TIMEOUT`) |
| FAILED | `no_answer` | nothing within 8 s (`INVITE_REACH_TIMEOUT`, C.8), or the second look heard nothing either |
| FAILED | `not_running` | failed at once, and the second look was refused too: nothing listens on that port |
| FAILED | `not_this_pond` | failed at once, and the second look connected: a server answered with another certificate, or the right one under another name |
| REFUSED | `invite_refused` | `REFUSE_INVITE`: revoked, replaced or never proved -- and **not dialled again** this run (below) |
| REFUSED | `game_older` / `server_older` | `REFUSE_PROTOCOL`, before any proof |
| REFUSED | `already_two` | `REFUSE_FULL` |
| REFUSED | `cut_off` | `REFUSE_BROKEN` |
| REFUSED or FAILED | `hung_up` | any other refusal -- `REFUSE_SILENT` among them, for a call that proved nothing within 3 s, which bars its address -- or a hang-up, which is how a call from a barred address ends: the door cuts it the moment it connects. "call again in a minute" is the bar |

- **The name resolves off the frame**: `IP.clear_cache(address)` first -- the resolver keeps an answer for the life of the process, and an owner's address that changed while the game was open would stay wrong until a restart -- then `IP.resolve_hostname_queue_item`, polled from `_process`, and the call dials the address it gets.
- **IPv4 first, and IPv6 only for a name with no IPv4 address** (from the review): the first lookup asks for `IP.TYPE_IPV4`, and only an answer with nothing in it asks again for `IP.TYPE_IPV6`, in what is left of the 6 s. The first build asked for either, and dialled the first address the system gave; a dynamic-DNS name with an AAAA record, on a home router that forwards 45772 over IPv4 and does not open it over IPv6 -- the usual case -- then sent every friend whose network has IPv6 to a shut door, eight seconds of "no answer", while friends without IPv6 got in. `looked_up` keeps the order for the probe (C8: a name with an IPv4 address is asked once; one with nothing, twice). A name with only an IPv6 address could not be run here: this container has no IPv6, and its hosts file names none.
- **The call**: `create_client(address, port)`, then `peer.host.dtls_client_setup("biogenic-pond", TLSOptions.client(pinned, "biogenic-pond"))` before the first poll, then `_api.multiplayer_peer = peer`, as on the LAN.
- **The second look** (`_diagnose`), after a failure that came before the transport did: a `PacketPeerDTLS` over a fresh `PacketPeerUDP` to the same address, with `TLSOptions.client_unsafe()` -- no pin, no name. Connected, it says goodbye at once (`close_notify`) and the call reads `not_this_pond`; refused, `not_running`; nothing in 3 s (`DIAGNOSE_TIMEOUT`), `no_answer`. It costs a server one handshake, on a call that has already failed.
- **A refused invite is not dialled again** this run (`_turned_away`, a digest of its key id and secret, never the secret): the server bars an address for a minute after a refused proof and ten for a second, so a retry could only earn the longer bar. A new paste is a new invite.
- **Changed from the plan: the LAN's refusals are worded for a server** on a call by invite -- a server updates itself and holds water, not a cell -- which is the designer's §6.3.
- `pond.gd`'s `cut_off()` reads `REFUSE_INVITE` as a cut too, so a guest whose invite is revoked while it swims reads "cut off from their water", not "their water is gone".

### C.8 Measured

**A call's length, through the relay.** `relay2.py`'s harness from #61, adapted (a copy: it also records every datagram's size and reads the DTLS ServerHello): every datagram held 5-40 ms, one in twenty 150-250 ms more, in order. The real server scene, with a book of its own, behind the relay; a guest process calling by invite twenty times, 3.2 s apart, each timed from `call_invite` to TOGETHER and to the transport coming up -- twice, the second time on the tree as it is committed:

| Link | Together | Median | Worst | Transport up: median, worst |
|---|---|---|---|---|
| jitter | 20 of 20, twice | 0.90 s | 1.15-1.20 s | 0.58 s; 0.75-0.82 s |
| jitter, 2% loss | 20 of 20, twice | 0.90-0.92 s | 1.95-2.07 s | 0.60-0.62 s; 1.58-1.73 s |
| jitter, 5% loss | 20 of 20, twice | 0.88-0.95 s | 3.85 s | 0.60 s; 3.73 s |

**So the call waits 8 s, not 4** (`INVITE_REACH_TIMEOUT`, for the transport and again for the handshake). A lost DTLS flight is resent after 1 s and then 2 s (mbedTLS's defaults), and ENet resends a CONNECT that went out before DTLS was up at 0.5, 1.5, 3.5 and 7.5 s: the 5% run's worst landed on the 3.5 s resend, which a 4 s budget would barely have held, and the next is at 7.5 s. The handshake itself, HELLO to WELCOME, took about 0.3 s after the transport, well inside `HELLO_GRACE`.

**The largest datagram, against a 1,400-byte path MTU.** ENet never sends a datagram over its MTU of 1,392 bytes, and DTLS adds 29 to each: the ceiling is 1,421 bytes of UDP payload, 1,449 as an IPv4 packet. Measured through the relays:

| Run | Plain (LAN) | DTLS (internet) |
|---|---|---|
| the 60 s pond below, jitter | 922-927 B | 1,219 B |
| the same, 2% loss | 859-869 B | 1,219 B |
| the game's largest frame, a full POND of 1,262 bytes, with events queued behind it | 1,300 B | 1,329 B |

No datagram in any run was over 1,372 bytes of UDP payload (1,400 on the wire): the most the game sends is 1,357 bytes as IPv4 and 1,377 as IPv6. Only ENet bundling acknowledgements and resends up to its whole MTU could pass 1,400, and none of these runs saw it (C.11).

**Two guests, one by invite, 60 s through the relays** (the server, a LAN guest through one relay to 45771 and an internet guest through another to 45772; both guests wear an `ampulla` and call, starve every 13 s and are taken by the water every 17 s, and come back): with jitter, and again with 2% loss (142 datagrams lost), each run twice, **every guest's `done after` line reads `over budget 0, points 0, fouls 0`**, the server's gate struck, dropped, cut and refused nothing, its referees called no foul -- 798-859 state frames, 11 calls, 8 arrivals and 7-8 deaths each -- and every peer's throttle stayed at 32. The internet guest was together 0.85-0.87 s after its call and in the water 1.27-1.32 s after it, every time.

**The exported server** (`--export-release "Linux Server"`, the binary CI builds, exported twice, the second time from the tree as it is committed): CI's smoke boot as ci.yml runs it -- READY with the internet line, a clean stop, exit 0, no script error, the pre-flight -- and the jobs on the binary itself: `--invite` before `--reach`, a bad label and revoking a label nobody has each exit 1 with their sentence, and the rest 0, the files 0600 in 0700 directories. A guest called it by invite and was together in 538-546 ms; `--revoke` run on the binary cut it within a look at the book -- 1.4 s after the job was started -- reading "invite no longer works", while the listener stayed up for the other invite. `--new-key` run on it while a guest swam: the guest was cut the same way, the listener closed with the emptied book, and after a new mint the old line read `not_this_pond` in 83 ms and the new one was together in 559 ms. `strace -e bind` on a job shows no UDP socket bound; on the server, 45771 once and 45772 twice (ENet's socket, then the DTLS one that replaces it).

**The review's own case, on the exported binary, after its fixes** (in a network namespace of its own): the server run as uid 65534 (`runuser -u nobody`), a guest swimming on its invite, and `--revoke` run as root with `HOME` pointing at the server's directory. The job did nothing and exited 1, naming `runuser -u nobody -- env HOME=... --revoke=sam` -- 427 ms for the whole process, most of it the engine starting. Then a book root wrote, `rw-------`, was put in place by hand: the server cut the guest 1.0 s later, reading "invite no longer works", closed the listener, and said why and what to `chown`. A `chown` back, which changes no modification time, reopened it at the next look.

**Engine error lines.** The probe's `invites` section prints 106 and one warning, the same in each of five runs, and none is a script error: 57 of `-30464` (42 from the storm of D2, whose handshakes found no slot, 5 from the plain ENet caller, and the rest from the bare callers of S and D3); 36 of the mutex bug (twelve listeners closed, three each); 6 from the pins that fail on purpose in C5, C6 and L10 (`-9984` on the client, then `-30592` on the server); and 7 from sends with nowhere to go -- C7's call and its second look, against a closed port, each a `bio_send` line (`-0x6C00`) and then the handshake error with the same number in decimal (`-27648`), with one `Sending failed!` warning, and three more `bio_send` lines as sockets close. ci.yml's LAN step fails on `SCRIPT ERROR` and `Parse Error` only.

### C.9 net_probe: the `invites` section

`_check_invites()` runs last, at 50 frames a second (`INVITES_FPS`): nothing in it is finer than a few tenths of a second, and most of it waits out what a player would -- the 8 s of a call nothing answers, the 3 s of a caller that never proves. A `Logger` catches every line printed while it runs, every job's lines are kept as they come back (`_invites_job`) -- the jobs' own code prints nothing, and a job run from the command line prints them all -- and the last check reads both. `--invites-only` runs it alone. Its books are its own (`user://net_probe_invites/`), and the server section now gives its server an empty one of its own too, so a real book in the same `user://` can open nothing there.

| # | Test | Result |
|---|---|---|
| F1 | An invite to an IPv4 address, an IPv6 one and a name | Each reads back exactly as written: 1,055, 1,055 and 1,063 characters |
| F2 | Line breaks every 61 characters, CRLF, spaces, a zero-width space, a no-break space, a soft hyphen and a tab inside it; a message around it; glued to the words on either side; a damaged invite before a whole one; a capitalised prefix | All five read through to the same invite |
| F3 | Cut at six points, one character changed at seven, a whole version-2 invite, and none at all | 13 of 13 damaged; the newer one `UNKNOWN_VERSION`; none `NOT_FOUND`; three sentences |
| F4 | `--reach` | An address, a name, `[v6]:port` and a bare IPv6 read; 8 of 8 junk refused |
| F5 | The kept invite | Kept clean at 0600; a paste that does not read leaves it; forgotten, gone |
| F6 | CHALLENGE and PROOF, held to A.3's table as T1 holds the rest | 17 and 57 bytes exactly, each from its own side alone; a byte either side, or the other side, refused; each reads back as written |
| C0 | Two invites minted by the jobs' own code | Each its own key id and secret |
| J1 | The rule for a job run as root, given the owners (this probe runs as root in one place and not in another), then this machine as it is | Into files another user owns: refused, naming `runuser -u <them> -- env HOME=... --headless -- <the job>`; root into its own, and any other user: goes on. Asking takes about 6 ms here |
| J2 | The same rule when who owns the files could not be read (issue #71) | Run as root, the job fails closed: refused, rather than write what the service user might not read |
| J3 | The book filled to 100 as mint writes it, then a 101st label; a label already in it; a revoke; then a book of 150 an older build could have made (issue #85) | The 101st refused, named, and told to revoke one, with not a byte of the book, key or certificate changed, and `--invites` saying the book is full; the label in it minted again; after the revoke, the book no longer full and the next label taken; the 150 all kept, and told to revoke 51 |
| C1 | A good invite | TOGETHER over DTLS in 0.56 s, held as alice's, on the internet listener |
| C2-C3 | A wrong secret; a key id nobody has | The same refusal and sentence, word for word; each barred at the internet door (60 s, then 600 s) and not at the LAN's. How long each took is printed, not compared: 0.58-0.60 s each, in every run |
| C4 | An invite revoked before the call | The same refusal; calling it again is refused in 0 ms, without dialling |
| C5-C6 | Another certificate; the right one under another name | `not_this_pond` in 81-93 ms and 115-117 ms, the second look included; each server stays up |
| C7 | A port nothing listens on | `not_running` in 19-20 ms, not `not_this_pond` |
| C8 | An invite by host name; one under `.invalid` | TOGETHER in 0.60 s, looked up for IPv4 alone; `no_such_place`, looked up for IPv4 and then IPv6 |
| C9 | A certificate on the server's own key that ended in 2021, held by the server and then by the invite; one made again on the same key with other dates (issue #89) | Both ended ones `not_this_pond`: the dates are checked on either side, hence 2020 to 2099; the one made again passes an invite that pinned the first, so only a new key voids an invite |
| S1-S2 | A plain ENet caller at 45772; a DTLS caller at 45771 | Both `no answer`; the host up; nobody let near either door |
| S3 | Two strangers from 127.0.0.2 and .3: DTLS, a HELLO, a CHALLENGE, then nothing; and DTLS then nothing at all | Each `REFUSE_SILENT` 3.04 s after it connected, cut, and barred at the internet door (60 s), not at the LAN's |
| S9 | Meanwhile, what the updater waits for (`company()`), beside `peer_count()` | With a silent LAN caller as well, 1 of 3; the two strangers alone, 0 of 2; then a friend who proved an invite, 1 of 1 |
| S10 | Both strangers straight back; then a friend by invite, from .1 | Both refused at the door as barred, taking no place in the waiting room; the friend in |
| S4, S5, S7 | A STATE before its PROOF; a PROOF before any CHALLENGE; a second HELLO -- since #103 each from an address of its own | Each cut the moment it spoke, with no strike -- and since #103 barred |
| S8 | Protocol 3 over DTLS | `REFUSE_PROTOCOL` before any CHALLENGE; a guest reads `game_older`'s sentence. Since #103 barred for a minute, and a minute again the next time -- the bar's end brought forward rather than waited out -- never ten |
| S6 | A good PROOF, a WELCOME, then a second PROOF | Cut with `REFUSE_BROKEN`, barred |
| D1 | Loopback made a stranger to the LAN door (`loopback_is_local`, the seam) | A LAN call from 127.0.0.1 refused as not on this network; an internet call from it proves bob's invite and is in |
| D2 | Fifteen silent internet callers from 127.0.0.1, .2 and .3; a LAN guest in the middle | At most 2 waiting on the internet side, 4 turned away for its waiting room; the LAN guest answered, the LAN door refusing nobody. At the doors themselves: twelve first calls on the internet are 10 answered and 2 busy, then ten LAN callers are all answered |
| D3 | A bare DTLS connection offering a LAN guest's id; a bare plain one offering an internet guest's | Each refused on its own listener; both guests play on, each on its own |
| D4 | A bare caller offering a negative id, at each listener (issue #75) | Refused at the door of either (`refused_id`), never a peer; both guests play on |
| L1 | The real server scene, with an empty book | No internet listener, and its READY says so |
| L2 | `--reach` alone, then a mint, by the jobs' own code | `pond/` `rwx------` from the `--reach`; the listener open 0.42-0.46 s after the mint, with no restart |
| L3 | The files | Key, book, address and line 0600; `pond/` and `invites/` 0700 |
| L4 | A LAN guest and an internet guest | The server's two, one on each listener; each sees the other in the water; `company()` 2 |
| L5 | A stranger on the internet listener beside them, with the server's updater swapped for one that keeps what it is told | Told 2, where `peer_count()` says 3 |
| L6 | Another friend's invite minted, then revoked, while the internet guest swims | Each taken within a look (0.39-0.47 s, then 0.49-0.51 s); the guest swims on, and the listener stays open |
| L7 | `--revoke` of the internet guest's own invite while it swims | `--invites` showed when it last came in; cut 0.48-0.51 s after the revoke, within a look, reading "invite no longer works", its run saying cut off; the LAN guest swims on |
| L8 | No invite left | The listener takes no call from the cut on, and its socket is put down 1.10-1.12 s later, after the linger |
| L9 | A new invite, a friend swimming on it, and the book put out of reach -- a directory where it was, since root, which this probe may run as, reads any file whatever its mode; the same branch as a book another user wrote | The friend cut 0.42-0.44 s later, reading "invite no longer works"; nothing listens for as long as it stays unread, and the log says why; the listener back 0.42-0.50 s after it reads again |
| L10 | `--new-key` while she swims, with every name its certificate is written through blocked by a directory, as a disk that fills after the key would stop it (issue #89) | Exit 1, "nothing was changed": the key, certificate and book byte for byte as they were, no `.next` file left, and she swims on. The first build's key went over before its certificate, and this check fails against it |
| L11 | `--new-key` and a new invite for the same friend in one look, while she swims | She is told 0.09-0.39 s later, reading "invite no longer works" -- the first build left her "they hung up", and this check fails against it -- and the listener is back 1.16 s after that with the new key, its listening line naming the certificate the job printed: her old line meets "a different server", her new one is in, and the LAN guest swims on |
| L12 | `--invite=frank --invites`, and `--revoke=nobody`, each through the server scene itself (`job_args`, the seam) | Their lines printed as `[server]` lines, exit codes 0 and 1, and no session opened |
| -- | Every line printed in the section, and every line a job gave back | None of 244 and 42 holds any of the 26 secrets, invite lines or key texts it made; every kind of job ran |

**The whole probe, as CI runs it** (`--headless --quit-after 20000`), after the review's fixes, five times, each in a network namespace of its own: 317 checks, all PASS, no script error; 12,827 to 13,142 frames, in 137.1 to 139.6 s -- of which the `invites` section's 37 checks took 2,579-2,595 frames and 51.9-52.2 s. CI's backstop is 20,000 frames. The timings in the table are from those runs, at 50 frames a second, so each is good to a frame, 20 ms.

### C.10 Where the build differs from the plan, and why

- **Each listener keeps a whole door**, not only its waiting room and busy bucket (C.4).
- **The second look after a fast failure** is new: a closed port fails as fast as a wrong certificate (C.1), and a player's fix for the two is not the same.
- **`--new-key`** is a job (C.6), and **"last joined" is its own file** (C.6).
- **A second PROOF after the welcome is a cut and a bar**, told `REFUSE_BROKEN`; a PROOF on the LAN is malformed, as a second HELLO is (C.5).
- **The invite is 1,055 characters**, not about 1.3 KB (C.7).
- **The call waits 8 s**, measured (C.8); the name 6 s.
- **The designer's API, taken while building** (`docs/design/invites-ux.md` §6.2, §6.3, §8, §9): the final strings, five more keys for a far call's refusals, `trouble_key`, `by_invite()`, a fresh lookup on every call, no dialling a refused invite, a sentence at once with no network, and the mint line.
- **`tools/net_lag.gd`'s `LaggedHost`** overrides `_take_datagram`, which gained the listener as a third argument, and now matches it.
- **The probe's frame budget.** The `invites` section runs at 50 frames a second, where `limits` runs at 100, to keep CI's backstop well clear.
- **From the independent review**, each with the check that holds it: the updater waits for the pond's company, where it counted every caller (C.4; S9, L5); a caller that proves nothing within the grace is barred on the internet listener (C.5; S3, S10); a book or certificate the server cannot read fails closed, where it went on with the old book (C.6; L9); a job root would run into another user's files is refused (C.6; J1); a new key tells its guests before the socket goes, where they read "they hung up" (C.6; L11); a name is looked up for IPv4 first (C.7; C8); `--reach` makes `pond/` private (C.6; L2); and the no-secret check reads every job's lines, with one job run through the server scene itself (C.9; L12).

### C.11 What C does not do

- **An invite is a bearer token.** Whoever holds the line gets in as that friend until it is revoked: there is no binding to a device. A leaked line is revoked, and the friend gets a new one.
- **No client certificates**, as planned: DTLS proves the server, and the client proves a secret inside it.
- **No NAT traversal.** The owner forwards one UDP port; there is no UPnP, no relay and no hole-punching. A LAN phone with an invite reaches the public address only through a router that loops it back; at home the four taps are the way in.

  > **UPnP since 2026-09-30.** The owner: *"The server should be always exposed imo."* The dedicated server now asks the home router to forward UDP 45772 to it by UPnP IGD -- Godot's own miniupnpc, every call on a worker thread (`game/net/port_forward.gd`) -- from its first READY until it stops, whatever the invites, for an hour at a time and renewed at half; a clean stop takes it off, and a crash leaves it to its lease. `--no-upnp` turns it off, remembered as `--reach` is (docs/server.md §9.3). **What listens behind the forward is unchanged**: nothing, until there is an invite, and a caller proves one before a frame of play (C.5). 45771 is never forwarded: the forward refuses it where each call is made (net_probe `upnp` U6). A forward already on the router is never taken over or removed, and at a stop the server's own is asked for again before it is taken off, so a router that gave the port away since keeps the other machine's. **The search's own port is pinned too**: it listens for the routers' answers on a port drawn from 49152-65535, never 45771 or 45772 (U14). Left to the system it could be any ephemeral port, 45772 among them, and miniupnpc takes whatever datagram reaches it for an answer and fetches the description it names -- so a search port the forward reached would let the internet steer that fetch (found in review). `--reach` stays the owner's to set -- *"Leave always set manually for now"* -- and the server only prints the router's public address as a hint. A router behind another router, or behind carrier-grade NAT, is named as such and asked for nothing, since no forward on it could reach the house. Still no relay and no hole-punching, and nothing over IPv6, which needs a firewall rule on the router rather than a forward.
- **Handshakes from real addresses still cost the server.** Cookies stop spoofed ones; a real address can complete DTLS again and again, each costing an RSA-2048 signature on the server's main thread -- 2.1 ms median here, 4.4 ms at worst over fifty, a frame is 16.7 ms -- and a caller that completes DTLS and ENet and never proves holds a slot for `HELLO_GRACE` at most -- 1.5 s if a newcomer needs it -- and is then barred however it goes (C.5, E.1), so one address can do that once, then not for a minute. The door refuses a storm only after each handshake is paid for. The firewall rule in docs/server.md §9.6, ten new calls a minute from each address, is the lever below GDScript.
- **ENet's 32 MiB per peer** (A.9) is unchanged, and applies to a guest that proved an invite as to any other.
- **The engine's error lines** cannot be limited from GDScript: journald's rate limit (docs/server.md §9.7) is the lever.
- **The datagram ceiling is 1,421 bytes** of UDP payload over DTLS. The game's own largest frame makes 1,329, measured; only ENet filling its whole MTU with acknowledgements and resends could pass a 1,400-byte path, and ENet's MTU cannot be set from GDScript. A path that drops fragments would lose those datagrams, reliable ones to be resent.
- **The fast failures are Linux's and Android's.** A connected UDP socket there hears the ICMP refusal; Windows' own behaviour was not measured, and where a refusal is not heard a closed port reads `no_answer` instead of `not_running`.
- **IPv6 was not run here**: the container has none. An IPv6 `--reach` round-trips in the invite and parses (F1, F4), and the listener is opened exactly as the LAN's is, on `*`, which Godot makes one dual-stack socket on a machine with IPv6 -- here, with none, it is IPv4 on `0.0.0.0`, traced. A name is dialled over IPv4 whenever it has an IPv4 address (C.7), so IPv6 matters only for a name with none, and then 45772 must be open over IPv6 on the owner's router; that fallback's order is checked (C8), but no IPv6-only name has been dialled here.
- **A friend on a link too poor to prove within 3 s is barred** as a stranger is: a minute, and ten for a second time within ten minutes -- and since #103, one still proving 1.5 s in when a newcomer calls, or one that backs out before it has proved (E.3). The phone says "they hung up · call again in a minute", which fits the first; a second one inside ten minutes finds the door shut for ten. A real call proves in about 0.3 s after the transport (C.8), and the call itself waits 8 s for the transport, so this takes a link that delivers the transport and then nothing for 3 s.
- **A guest's kept invite on Windows** is written by a rename that Godot 4.7 makes two steps there -- the old file deleted, then the new one moved -- so a stop between the two leaves only `invite.txt.new`, and the invite is gone until it is pasted again. Linux and Android rename in one step.
- **No expiry.** An invite works until it is revoked or replaced, or the key is -- and the certificate runs to 2099 on purpose: its dates are checked against the phone's clock and protect nothing the pin does not, and it cannot be renewed past the copy inside an invite, so a shorter life would only void every invite on a timer (C9; docs/server.md §9.8, issue #89).
- **Two jobs at once** -- two owners minting in the same second -- can lose one mint: the last writer wins. The book is written in one step, Linux's rename, so it is never torn.

## D. #91 in one PR: a fuzzer for everything a stranger's bytes reach

`tools/net_probe.gd` checks each rule with the case its author thought of. This part adds the cases nobody thought of. **`tools/net_fuzz.gd` feeds every reader of untrusted bytes what a stranger could send, checks what must hold after every step, and prints a replay of anything that breaks it, cut down to the fewest steps that still do.** It is seeded -- one seed is one run -- bounded, and never reachable from outside: the part that opens sockets refuses to run anywhere but a network namespace of its own.

### D.1 Six sections

| Section | What it drives | How |
|---|---|---|
| `wire` | Every `Wire.take_*`, `state_body`, `proof_parts`, `challenge_nonce` and the handshake readers, both directions | 20,000 frames at scale 1: valid frames of every kind, then cut, stretched, bit-flipped, an edge byte, a float made NaN, infinite or huge, the kind or type swapped, two spliced, or junk. **Read only where the gate would read them** (`_admit_frame` steps 2-5, and `_parses` on a host), so a value the gate never lets through is not a finding. |
| `door` | A real host session -- the dedicated server's two-guest host with both listeners, and in one run in four a phone's, one guest and the LAN listener alone -- with every caller driven by hand through the session's own `_on_peer_connected`, `_take_datagram`, `_on_peer_disconnected` and `_process` | 120 runs of at least 50 steps, one in ten eight times as long -- some 14,000 steps in all. Callers connect on either listener from any address, twins under one id, ids no build picks, and now and then no address at all, which is what `_address_of` says of a peer ENet no longer holds; they greet, prove when challenged -- with the right invite, a wrong MAC, a key no invite has, the replacement invite -- then play. **Storms** of a dozen calls at once reach the door's buckets. **Bursts, floods and trickles** reach the budgets and the queues. Each long run **fills a book** -- more callers from distinct places than its 1,024 entries, checked after every one -- and the owner revokes, replaces and restores the invite mid-run. Time moves only when a step says so. |
| `guest` | A guest session, on a LAN call and on a call by invite, fed what a host could send it through `_on_peer_packet` | 150 runs of 40 frames: WELCOMEs right and wrong, REFUSEs, CHALLENGEs -- some from an id that is not the host's -- and every other host frame, spoiled now and then. |
| `invite` | `Invite.parse` | 1,200 pastes: whole invites, cut, chatted around, doubled, a whole conversation of up to 200 KB, with what a messaging app puts in a line, and **junk behind a check that reads** -- the payload spoiled and the check made over it again, so the parse goes as deep as it can. |
| `address` | `Lan.is_local_source` and `Lan.source_key`, and since #103 `Lan.wider_key` | 6,000 addresses made from their numbers and then written -- IPv4, IPv4 in IPv6 clothes, IPv6 compressed or not, in either case, with a zone -- so what each one is is known without parsing it back; and spoiled ones. |
| `referee` | Every judgement: `claim`, `judge_enter`, `arrive`, `judge_person`, `judge_sister`, `judge_shout`, `judge_died`, `died`, `left`, `stalled` | 150 runs of 60, in any order. **What the host decides stays the host's** -- where a body arrives, at a size its ENTER was allowed -- and a state frame is judged only while a body is here, as `pond.gd` does. **What the guest says is anything its reader lets through**: any finite place or size to float32's edge, a heading within half a turn either way, a motion inside `MOTION_MAX` and `TURNING_MAX`. |

**Every case in `tools/net_fuzz_corpus.txt` runs first**, every time -- 70 at #91, 81 since #103 (E.4), 82 since #104 (F.2):

- #107's negative ids, and #75's twin under one id and its full book with a caller of no address;
- #102's sister and shout from float32's edge;
- each way to break the handshake, and each change the owner's hand makes to the door;
- each of the internet door's own refusals;
- the budgets and the silence cut;
- a phone host's queue;
- a value each reader refuses;
- a guest's CHALLENGEs;
- #103's waiting room: a newcomer taking the elder's place, a caller hanging up unproved, a /56 barred as one, and the bucket for everybody paying only for the calls the door took.

**Between them, the saved cases take every path the door can take**, so what the door covers does not depend on the seed. A failure that is fixed goes in there under a note, and stays fixed.

### D.2 What must hold

After every step, or the run fails and prints why:

- **No script error**, and no engine error from anything but the three lines 4.7's DTLS listener prints on every close (C.1), which are counted apart. Since #106 (H.3), an invite paste may cost the log at most `Invite.CERTIFICATES_MAX` lines, each a certificate that does not parse; before it, the invite section counted its engine lines and did not fail on them.
- **The wire**: every value a reader hands on is finite; a state body's radius above zero and its motion inside the caps; a snapshot's count and slots inside its own, and each person's motion inside the caps.
- **The door**:
  - Callers and ids: no peer under an id below 2; none greeted speaking another protocol; each peer's listener the same in `_via` and in its record, and connected there; no LAN peer from outside the house.
  - Before a proof: **nothing a caller says is taken before it is greeted**, and **no caller greeted on the internet listener without a valid proof** -- its second datagram, after its one HELLO, over the nonce it was sent, of an invite the owner holds at that moment. A proof of an invite the owner then takes away proves nothing from there on: its guest must be gone. Nothing but a CHALLENGE or a REFUSE is sent to a caller there before its proof.
  - **Nothing a real ENet would refuse**: no frame sent to an id its listener does not hold or has cut, or to an id below 2, which ENet reads as many peers; and no peer asked of ENet -- to cut it, throttle it or learn its address -- that it does not hold, which is `get_peer`'s engine error on a real host.
  - Bars: **no bar forgotten while it lasts**, unless every caller in a full book is barred -- the rule #75's fix restored. Since #103 (E.4), **no call taken at the door while its address, or on the internet door its /56, is barred** -- before the call or after the room it made -- **no call turned away at a cost to the bucket every address shares**, and **room made only by the caller that has waited longest**, 1.5 s or more, from neither the newcomer's address nor its /56.
  - Budgets: **no peer taken past its budgets** -- its frames, bytes and events at most what its buckets could have paid since it connected.
  - Caps: no more than its guests; the dedicated host's queue holding only greeted guests' events, each inside its own share, and a phone host's inside a host's share; every book and note table inside its cap.
- **The guest**: it greets first and once; it proves an invite **only on a call by invite, only once, and only in answer to a whole CHALLENGE from its host**, with its invite's key id and a MAC over that CHALLENGE's nonce -- never on a LAN call, whatever a LAN host sends.
- **The invite**: a paste read as an invite is a whole one -- a key id and a secret of their sizes, an address a call can use, a port, a certificate -- and none takes half a second to read.
- **The address**: judged local exactly when it is, and put in the /56 it is in -- IPv4, in any clothes, in none (E.1).
- **The referee**: every answer finite, the body inside `BASE_RADIUS`..`DIVIDE_RADIUS`, its motion inside `SPEED_MAX` and `TURNING_MAX`, a sister at a daughter's size.
- **At the end**:
  - **No secret** -- neither invite's, in hex, in base64 or as GDScript prints bytes in a Dictionary -- in any line the run printed.
  - **Every path the door can take, taken**, by the runs or by a saved case, but the eight no run here can reach (D.4). A path that goes untaken fails the run by name, so what the door covers cannot slip unseen.

### D.3 What the door plays, and how

The host is `net_session.gd` itself with five functions taken over, so no caller outside this process can reach it and the clock is the fuzzer's: `_now`, `_address_of`, `_steady_throttle`, `_to` and `_drop_on`. Its pump runs only when a step moves time, and in a namespace of its own nothing ever arrives at the real sockets it reads.

**ENet is played as 4.7 behaves**, each rule measured or read in A and C, or in `enet_multiplayer_peer.cpp`:

- one peer an id on each listener;
- a caller offering 0 or 1 dropped before any signal;
- none past `_slots()`;
- a peer the host cuts is inactive at once, and said gone at the next service;
- `get_peer` on an id the listener does not hold is an engine error, and so is `put_packet` to a peer already reset;
- no new transport while the internet listener closes (`refuse_new_connections`);
- a closed listener takes its transports with it and says nothing, the host having let them go already.

**Isolation.** The door section, and a door replay, run only where loopback is the only interface -- a fresh network namespace -- and otherwise fail at once, saying so. A namespace whose own address would make the "outside" callers' documentation ranges local fails too. CI runs the fuzzer under `sudo unshare --net` and hands Godot back to the job's own user; locally:

```
sudo unshare --net -- bash -c 'ip link set lo up &&
    ip addr add 10.77.0.5/24 dev lo &&
    godot --headless --path . res://tools/net_fuzz.tscn -- --seed=1'
```

`10.77.0.5` is an address the LAN host can take inside a namespace nothing else is in. `--only=wire,guest,invite,address,referee` runs the rest anywhere, since they open no socket.

**Determinism.** Each section seeds its own generator from `--seed`. The invites are drawn from it too, and their certificate is `tools/net_fuzz_cert.pem` -- made once for this, its key thrown away, so it proves and opens nothing. Run twice, a seed prints the same verdict lines; only the timings differ. The door's own DTLS key is made fresh: no caller here speaks DTLS, so nothing depends on its bytes.

**A replay is exact** -- but for an invite paste holding a surrogate on its own (#106), which the replay's UTF-8 cannot carry: rerun that one by its seed. `--replay="<section> <case>"` runs one case:

- **wire**: a frame in hex. Since protocol 6, a saved event may say what the reader must do with it, as `<g|h> takes <hex>` or `<g|h> refuses <hex>`. A saved refusal then fails the day the reader takes it, as an invite's does.
- **door**: steps written `C:id:via:address`, `D:id:via:what:payload`, `X:id:via`, `T:seconds`, `I:revoke|replace|restore` and, since #105, `L` for the LAN listener closing by itself. `P` opens a phone host's run. Two compact steps are written out as they run, with every check after each datagram and each caller: `S:via:count` for a book filled, and `F:id:via:what:count:first` for a flood. A proof is named rather than written, since its nonce is the host's.
- **guest**: its frames, `from:hex`.
- **invite**: a paste in base64 -- since #106 after the word for what it must read as, where that is the point: `ok`, `none`, `damaged` or `newer`.
- **address**: `local` or `remote` -- and since #103 a `/` and the /56 it is in, or `/` alone for none -- then the address.
- **referee**: its steps, with every float a float32 in `var_to_str`'s shortest form, which reads back to the same number (measured over 40,000).

A failure is printed already minimised: frames cut and zeroed, steps taken out in halves, then quarters, down to one.

### D.4 Measured

- **CI runs seed 1 at scale 1: about 4.2 s** at #91, 70 saved cases and some 57,000 generated ones, the import and boot around it -- about 5 s since #103, with 81 saved cases, and 82 since #104. `timeout 300` is the backstop -- a fuzzer that does not parse leaves its scene up forever.
- **Scale 1, seeds 1 to 6, and scale 20, seeds 11 to 15: all pass** -- 80 to 94 s each at scale 20, most of it the door's books and the invite section's long pastes.
- **What the door reached.** Its counts, summed over a run and its saved cases, say which of its 42 paths -- 45 since #103 (E.4) -- were taken, and the run fails if one it can reach was not (D.2). The saved cases alone take every one of them. Eight no run here can reach, by design:
  - `saturated`, which is the real socket's statistics;
  - a closing listener's two `refused_closed`, which ENet's `refuse_new_connections` keeps every caller from;
  - the referee's four foul counts, which are the pond's;
  - `challenges_dropped`, which is a guest's.
- **Nineteen bugs planted one at a time**, each replay failing on the bug and passing on `main`. "Unaided" is seed 1 at scale 1 from an empty corpus, by the run's own checks:

  | # | Planted | Caught unaided by | Minimised to |
  |---|---|---|---|
  | 1 | #107's guard taken out: an id below 2 let in | door | one connect |
  | 2 | any MAC proves | door | connect, HELLO, a wrong-MAC proof |
  | 3 | the twin guard taken out | door | a guest proved on one listener, then its id on the other |
  | 4 | a refusal sent after its cut | door | a LAN guest gone quiet for good (#92) |
  | 5 | a NaN shout let through | wire | one 22-byte frame |
  | 6 | 100.64.0.0/10 not local | address | one address |
  | 7 | the claimed radius not capped | referee | an arrival, then a claim at r1e20 |
  | 8 | a snapshot's motion unchecked | wire | one snapshot |
  | 9 | a guest answering a CHALLENGE on a LAN call | guest | one CHALLENGE |
  | 10 | a guest answering twice | guest | two CHALLENGEs |
  | 11 | the host printing a secret in hex | secrets | -- |
  | 12 | #75's eviction put back: a full book forgetting a barred caller while `""` is unbarred | its saved case; unaided at scale 20, by three seeds of three, in runs 19 to 519 | -- |
  | 13 | a replaced invite's guest kept | door | a guest proved, then the invite replaced |
  | 14 | a wrong proof neither refused nor barred | coverage (`proofs_refused` never moves), and its saved case | -- |
  | 15 | a refusal's linger outliving its caller | door | a silent caller refused, gone, then time |
  | 16 | the budgets only watched | door | 21 events at once |
  | 17 | a peer's record printed whole | secrets | -- |
  | 18 | any protocol greeted | door | a HELLO from protocol 1, then a proof |
  | 19 | a phone host's queue unbounded | door | a phone host's 65th event |

  With the corpus in place, every one of them is caught before any fuzzing starts: by a saved case, or for 11 and 17 by the secrets check.

### D.5 What it found

**Nothing in the code it drives.** One thing about the referee's contract, which is written here so it stays true: `claim()` before any `arrive()` starts the body from the guest's own claimed place, since there is no anchor yet, and two claims at opposite ends of float32 then make a NaN. It cannot happen -- `pond.gd` judges a state frame only for a person, and a person exists only after `_host_enter`, which calls `arrive()` -- and the fuzzer keeps that order, as the host does. A caller of the referee that did not would have to.

**Its independent review found the harness's own gaps**, each closed before the merge and each with a planted bug that now fails (13-19 above):

- invites taken away did not reset what a proof was worth;
- a proof counted whatever the line had said before it;
- the fake ENet forgave asking for a peer it did not hold;
- nothing held the budgets;
- the phone host was never run;
- the secrets check missed GDScript's own print of a Dictionary;
- CI seed 1 no longer reached two budgets -- hence the coverage check and the saved cases that make it seed-proof;
- and CI's second grep gate failed open under `pipefail` on a log this size -- hence here-strings.

### D.6 What D does not do

- **The engine's own C++** -- ENet, `UDPServer`, DTLS and mbedTLS -- is not driven: the door injects callers above ENet, and no caller here completes a handshake. A.1 and C.1 measured those, and the probe's `limits` and `invites` sections hold what they found.
- **The session's own `_to`, `_drop_on`, `_address_of` and `_steady_throttle`** are the fuzzer's, so their own guards -- `_to` refusing an id below 2, for one -- are not exercised. What they would be asked to do is: any call they would make an engine error of fails the run.
- **A host's stall credit** (`_top_up`) is never given: every step that moves time takes a frame first, so no datagram arrives after a gap, and the budget check (D.2) counts on it.
- **Real sockets and real time.** Loss, reordering, latency and a clock that jumps are `tools/net_lag.gd`'s and two phones', not this.
- **`pond.gd`'s run** is not fuzzed. What its handlers apply is either what a reader let through or what the referee answered, and both are. The probe's `pond referee` section drives a hostile guest through a real host's water by hand.
- **An event's own values past finiteness.** A shout's radius or reach of zero or less reads, for instance; what it means is the referee's to judge, and the referee section holds its answers.
- **A guest's `_process`**: a call by invite resolves a name and, when it fails fast, takes a second look over the network (C.7), so the guest section feeds frames only.
- **The server's book and jobs** (`invite_book.gd`, `server.gd`) are the probe's `invites` section's.
- **Non-finite values into the referee**: the wire refuses them before it (A.3, B.1), and the wire section holds that.

## E. #103 in one PR: the internet door's waiting room makes room

The #75 read found that the internet door's waiting room -- two places for callers that have not proved an invite (`PENDING_MAX`) -- could be kept full by strangers, and every friend's call refused as "pending", which the phone shows as "they hung up". Each caller that proved nothing in `HELLO_GRACE` was barred (C.5), but the bar and the call bucket are both keyed by `Lan.source_key` -- one IPv4 address, or one IPv6 /64 -- so callers from a fresh key every 1.5 s held both places, and over IPv6 a home's /56 is 256 fresh keys. Building the fix, and then its review, found cheaper ways still: **three ways out of the room carried no bar at all** -- hanging up before the grace was out, speaking out of turn, and a HELLO on another protocol -- so a handful of addresses, each leaving by one of them and calling straight back, held the room for good. The review held it against a friend with five addresses and no bar, on the real door code.

It is content only: GDScript, no wire change, no PROTOCOL bump, and `Wire.RULES` is unchanged -- the referee judges nothing new, and the door is not the referee.

### E.1 What changed, all at the internet door

- **Every way out of the waiting room without a proof bars the address**, however it goes: silence past the grace (C.5), a newcomer taking the place (below), a wrong proof (C.5), and now **hanging up** (`_left_unproved`, counted as `net_left`), **speaking out of turn** (`_cut_too_soon`: anything but the handshake before it, which no Biogenic build sends there), and **a HELLO on another protocol**. The last is barred **for a minute, never ten**: it may be a friend's phone that has not updated yet, which reads the version sentence first and "call again in a minute" after it. "Already two" is said only to a caller that proved an invite, and is not barred. A refusal takes a caller's record at once, so no caller is barred twice by its own goodbye.
- **Full, the room gives its elder's place to a newcomer** (`EVICT_AFTER`, 1.5 s): a newcomer that finds both places taken, the longer-waiting of them there 1.5 s or more with nothing proved, is taken, and the elder is told `REFUSE_SILENT` and barred as silence is (`_evict`). A real guest proves about 0.3 s after its transport is up (C.8), so 1.5 s is five times that, and a friend never waits behind a caller older than it. **Never room made by a neighbour**: a newcomer from the elder's own address or /56 is refused as the room is full, since the elder's bar would fall on the newcomer's own address and let one address in again and again, pushing out its own.
- **A /56 of barred /64s is barred as one** (`BARS_TO_WIDEN`): once three /64s under one /56 (`Lan.wider_key`) have been barred at the internet door inside `BAR_AGAIN`, the /56 is barred -- a minute, ten for a second time inside ten, by its own count -- and a caller from anywhere in it is refused at the door, "with the /56 it is in". A home or a server is handed a /56 or wider and makes up /64s inside it at will. **IPv4 is never widened**, nor IPv4 in IPv6 clothes: behind carrier-grade NAT one address is already many strangers, and a /24 would be a carrier's worth of them (E.3). The LAN door never widens.
- **The bucket for everybody pays only for a call the door takes.** The door now asks, in order: barred, its /56 or its own address; its address's own bucket, which every call spends; its address's transports; the waiting room; and only then the bucket every address shares. A newcomer turned away for want of room used to spend a place in that bucket, which could then refuse a friend as busy.
- **The log, one line a kind** (A.6): every refusal on the internet door is one line a reason every 10 s, and so are the hang-ups and cuts of callers there that proved nothing -- one key for all of them, and the reason beside a hang-up. A stranger comes from as many addresses as it likes, and a line an address would be a line for every address it spends, which journald's own limit (docs/server.md §9.7) would then cut short, taking the lines that matter with it.

The LAN door is as it was, but for its buckets' order and the full room's one line: silence, an old protocol and speaking out of turn are not barred there, and nobody's place is taken.

### E.2 What holding the room costs now

Both places, each given up to a newcomer 1.5 s in, take an admitted call every 0.75 s -- 80 a minute -- and **every one of them bars where it came from** when it leaves, a minute and then ten for a second time inside ten. An address can have a caller in each place before either leaves, so it gives about two calls, then is barred for most of ten minutes: keeping the room full takes some 400 IPv4 addresses. Over IPv6 the third /64 of a /56 to be barred bars the whole /56, so a /56 gives about eight calls in eleven minutes, and keeping the room full takes about a hundred /56s -- which a /48 holds. **Barring a /48 as one was weighed and not done**: a provider hands its customers /56s out of /48s, so three bad customers would bar 253 others, a friend among them -- carrier-grade NAT's problem (E.3), made new. A firewall rule over a wider prefix, or the provider, is the lever past this. And between refusals a friend's call lands whenever the elder has been there 1.5 s, which the attacker's next call must beat to the door, every time.

**Cheaper than any of this, and not the room's**: an address that completes DTLS and never finishes ENet's own handshake holds ENet slots until ENet gives up on it, 5 to 30 s, and the door never sees it (A.9, "A barred address can still knock"). The firewall's rate limit per source (docs/server.md §9.6) is the lever there.

### E.3 What it costs a friend

- **A friend still proving 1.5 s after its transport came up, when a newcomer calls**, loses its place and is barred: "they hung up · call again in a minute". A real call proves in about 0.3 s (C.8); it takes a link that delivers the transport and then little else, and a stranger calling in that second.
- **A friend who backs out in the few hundred milliseconds between the transport and the proof** is barred for a minute. The phone's own call waits 8 s for the proof, so it never hangs up first by itself.
- **A friend on an older or newer build** reads the version sentence, and if the phone calls again inside the minute, "they hung up · call again in a minute". It is never barred for ten: a phone left behind by an update may call many times before its owner updates it. Its bar still counts toward its /56, though, which is barred by its own count: three old builds on three /64s of one /56 bar the whole /56 for a minute, and a friend on the current build there with them.
- **A friend on a mobile carrier's IPv6** may share a /56 with strangers, since a carrier hands each phone a /64 out of a shared pool, where three barred strangers would bar the friend too. A name is dialled over IPv4 whenever it has an IPv4 address (C.7), so this takes a server with IPv6 alone.
- **The reverse problem stays.** Behind carrier-grade NAT, strangers share one public IPv4 address, and a stranger barred there bars a friend on the same carrier with it -- a minute, ten for a second time. Nothing before a proof can tell the two apart; IPv4 is never widened past the address, so it is no worse than it was.

### E.4 Checked

- **net_probe, `invites` section**, on real DTLS sockets over loopback:

  | # | What | What must hold |
  |---|---|---|
  | R1 | Two strangers from 127.0.0.2 and .3 waiting, the second calling a good while after the first -- one challenged and silent after, one silent -- then first calls from twenty addresses at the door itself | All twenty turned away for want of room, and the bucket for everybody as it was before them |
  | R2 | A friend by invite, from .1, once the elder has waited 1.2 s: its call comes up at ENet's first resend, some 0.55 s on, or at the next a second later | The friend in, and how long after the elder it came printed; the elder, and only the elder, told `REFUSE_SILENT`, barred, and its line printed -- `no greeting -- challenged, and no proof in 1.8 s, and a caller waiting behind it -- barred 60 s` |
  | R3 | A fresh stranger from .4 says HELLO, hangs up before its grace is out, and calls straight back | Barred all the same (`net_left`), its line printed; the call back refused at the door as barred |
  | R4 | At the door itself: two /64s of a /56 and one of the next barred; then a third; three IPv4 addresses; three /64s at the LAN door | Two bar nothing more, nor does the one next door; the third bars the /56 -- a fourth /64 in it refused "with the /56 it is in", one in the next /56 answered; no IPv4 neighbour and no LAN /56 barred |
  | S4-S8 | Changed: speaking out of turn, each from an address of its own; protocol 3, twice from one address, the bar's end brought forward between them | Each out-of-turn caller barred; the old protocol barred for a minute, and a minute again, never ten |

- **net_fuzz** (part D) holds the door to four more rules after every step (D.2): **every caller on the internet listener that leaves the waiting room with nothing proved leaves its address barred**; no call is taken while its address or /56 is barred, before the call or after the room it made; no call turned away spends the bucket for everybody; and room is made only by the caller that has waited longest, 1.5 s or more, from neither the newcomer's address nor its /56. The door's three new counts -- `net_evicted`, `net_left`, `net_barred_wide` -- are paths the coverage check now demands. Eleven new saved cases, 81 in all: the room made at 1.6 s, the elder there longer than the younger; three /64s of a /56 and a fourth refused; twelve callers on each listener, where the bucket for everybody pays for the ten the door took; a hang-up, an out-of-turn caller and an old protocol, each calling back; a neighbour by address and one by /56, neither taking the elder's place; and a /56 and an IPv4 address in IPv6 clothes at the `address` section, whose eight older saved cases now name their /56 too. The `address` section holds `Lan.wider_key` against what each of its 6,000 addresses is -- the /56 of its groups, and none for IPv4 in any clothes or anything spoiled.
- **Twelve bugs planted one at a time**, each run against the fuzzer (seed 1, with the saved cases) and the probe's `invites` section:

  | Planted | The fuzzer | The probe |
  |---|---|---|
  | IPv4 in IPv6 clothes given a /56 | `address`, unaided and by its saved case | -- |
  | IPv4 widened to its /24 | `address`, unaided and by its saved case | -- |
  | a hang-up not barred | unaided, a saved case, and coverage (`net_left`) | R3 |
  | speaking out of turn not barred | unaided, and five saved cases | S4-S5, S7 |
  | an old protocol not barred | unaided, and its saved case | S8 |
  | an old protocol barred for ten minutes the second time | -- | S8 |
  | a caller whose place is taken not barred | unaided, a saved case, and coverage | R2 |
  | a newcomer taking a place at once, not after 1.5 s | unaided, and a saved case | R1, D2, and the server section |
  | the youngest caller's place taken, not the elder's | coverage: `net_evicted` never moves | R2 |
  | a neighbour taking the elder's place | its two saved cases | -- |
  | the bucket for everybody spent before the room is asked | seven saved cases and the unaided run | R1, D2 |
  | a /56's bar not asked at the door | its saved case, and coverage | R4 |

  The review found the three unbarred ways out; the fuzzer had no rule that could, until the first of the four above. Planting the bugs found one thing in the probe itself: R4 first asked for a /56 bar of at most 60 s, and a bar made in the same millisecond as the look is 60 s and a hair, as float arithmetic goes.

### E.5 In the log

```
[net] hung up on 1587052382 (198.51.100.4): no greeting -- challenged, and no proof in 1.8 s, and a caller waiting behind it -- barred 60 s
[net] 1587052382 (198.51.100.4) hung up 0.4 s after it called, having proved nothing -- barred 60 s
[net] cut 1587052382 (198.51.100.4): spoke before its proof -- barred 60 s
[net] hung up on 1587052382 (198.51.100.4): different versions -- barred 60 s
[net] barred 2001:db8:0:100::/56 for 60 s at the internet door: 3 of its /64s barred inside 600 s
[net] refused 2001:db8:0:1ff::5 on the internet listener: barred for 41 s more, with the /56 it is in
```

On the internet door each kind of line -- each reason for a refusal or a hang-up -- is one line every 10 s: the next of its kind ends `(+4 like it held back)`, which is where the other addresses went.

## F. #104 in one PR: a phone host answers on its own network alone

The #75 read found that a phone hosting on the LAN could answer strangers. The LAN door counts every caller from 10/8 and 100.64/10 as in the house, whichever of the phone's interfaces it arrived on; the listener binds every address; and `Lan.pick_address` falls back to a cellular address when it is the only one, and earshot hosts on it. So a phone hosting on mobile data -- or on Wi-Fi with mobile data up -- would answer other subscribers in its carrier's private pool as if they were in the house, and one could join with a plain HELLO: the tap code is not a secret. Whether a carrier lets one subscriber reach another over UDP varies, and many do not; **that was not measured on a real network**, and this closes it either way.

Content only: GDScript, no wire change, no PROTOCOL bump, `Wire.RULES` unchanged, no `binary_version` bump. The dedicated server is as it was (A.5, #69).

### F.1 What changed

- **A phone hosts only where its friend can be with it** (`Lan.hosting_address`, `Lan.pick_hosting`): the same choice as `Lan.pick_address`, or none when that choice is on cellular data -- and then the phone says "no wi-fi here", as it does with no network at all. Cellular is known by its adapter's name (`Lan.CELLULAR_PREFIXES`): Qualcomm's `rmnet`, MediaTek's `ccmni`, Unisoc's `seth_lte` and newer `sipa_eth`, older Android's `pdp`, a laptop's modem (`wwan0`, systemd's `wwp...`), Windows' "Cellular", and `v4-`, the interface Android adds for IPv4 over an IPv6-only network, whose 192.0.0.4 is the same on every phone and reaches nobody. **Cellular ranks below every other adapter**, a tether included, so a phone that is a hotspot hosts on its tether whatever range Android gives it. A guest's side still answers with what `pick_address` picks.
- **A phone host's LAN door answers its own /24 alone, and loopback** (`_admit`, `Lan.same_24`). A friend finds a phone by its code, which is the friend's own /24 with the phone's last number on it, so every friend's call comes from the phone's /24 -- and a carrier's other subscriber calling its cellular address, another /24 of a wider house network, a unique-local or link-local IPv6 caller, is none of them. A dedicated host keeps the wider house door (A.5): its guests on another /24 of the house come by address, and the firewall is its first line (#69).
- **Binding the phone's socket to its address was weighed and not done**, though the issue suggested it and it was first built that way. Godot closes an ENet server whose send fails, and a socket bound to an address fails its sends the moment that address goes -- measured in a namespace here: `sendto` from a socket bound to a vanished address is `ENETUNREACH`, where one bound to every address sends by the next route. So a phone with mobile data on would end its game at the first Wi-Fi hiccup, where today it rides one out if the Wi-Fi comes back within ENet's timeout, with the same address, as it usually does. The door does the same job without that cost; what binding would have added is F.3's first point.

### F.2 Checked

- **net_probe**, two new checks: on adapter lists, a phone on cellular data alone hosts nowhere -- nor on any of eight carriers' and modems' adapters -- though a guest's side still answers with it; beside Wi-Fi it hosts on the Wi-Fi, and when it is a hotspot, on its tether in 192.168/16, 10/8 or 172.16/12 alike. And at the doors themselves: a phone host answers its own /24, in IPv4 clothes or not, and loopback, and refuses another /24 of the house, a carrier's pool, and IPv6's unique-local and link-local callers -- where a dedicated host answers that other /24. 335 checks, all PASS.
- **net_fuzz**: after every step, no LAN peer of a phone host from outside its /24 but loopback; its phone case calls from loopback now, and a new saved case offers a phone the carrier's pool, another /24 and a unique-local caller. Seeds 1 to 3 pass.

### F.3 What F does not do

- **A caller at the phone's cellular address still reaches its socket**, where the carrier lets it: the door refuses it, but only after ENet's handshake, so it can hold ENet's slots for a while as any caller can (A.9, "a barred address can still knock"). Binding would have stopped that, at F.1's cost.
- **A carrier pool that overlaps the home's /24** -- a subscriber at 10.0.0.9 on a carrier, and a home Wi-Fi at 10.0.0.0/24 -- is inside the phone's /24 as the door sees it. It takes a carrier handing out the home's own range, and letting subscribers reach each other.
- **The carrier's behaviour was not measured.** Nobody here has two phones on one carrier; the fix does not depend on whether it lets subscribers reach each other.
- **Cellular is known by name.** A cellular adapter under a name not in the list, and on Windows one whose friendly name is not English ("Mobilfunk", "Cellulaire"), ranks as a real adapter: with no Wi-Fi the phone hosts on it, and beside a Wi-Fi it can still win -- a 10/8 cellular address beats a 172.16/12 Wi-Fi on range, and ties a 10/8 one on the order the adapters are listed in. Its door then answers that /24 of the carrier's pool.
- **A VPN pool is the same shape.** A phone with mobile data and a VPN up, and no Wi-Fi, hosts on the VPN's address -- cellular ranks below it -- and its door answers that /24 of the VPN's pool, where the VPN lets its customers reach each other. Narrower than before #104, when the door answered every private range whichever address won.
- **A friend on the same Wi-Fi as a stranger is in the house** -- that is what the LAN is, and the door's other limits (A) are the lever there.

## G. #105 in one PR: the LAN listener that ENet closes by itself

The #75 read found that a LAN listener ENet closes by itself left its host deaf. 4.7's `ENetMultiplayerPeer.poll()` calls `close()` when a service call fails, and on a plain UDP socket a send the network refuses is such a failure (`enet_godot.cpp` prints `Sending failed!` and returns -1; the DTLS layer swallows its own, which is why the internet listener never does it). `close()` takes every transport on the listener and says nothing to the host. `_pump_one` handled that for the internet listener (C), and for the LAN one did nothing: it returned early on every later frame without a word, kept every record of that listener's peers, stopped `_count_arrivals` counting both listeners, and went on saying LISTENING -- or TOGETHER, with a guest that was gone. The dedicated server hosts once and never again, so it stayed deaf to the house until the service restarted; a phone went on showing a code that nothing answered. **No remote trigger was found**: the likeliest cause is the network going from under the socket, as when an interface goes down and up.

**Measured, before and after**, in a namespace with the host's address on its loopback: a dedicated host with a guest in, the address taken away, and given back five seconds later. On `main` at `9e206f9`, the host's next sends failed -- six `Sending failed!` lines -- and from then on it said TOGETHER with a guest that had gone, printed nothing, and a new guest after the address came back was never answered. With G, the same failure is `[net] the LAN listener closed by itself`, the guest's `done after` line, `[net] the LAN listener is open again, 0.0 s on` and LISTENING, and the new guest is in. `tools/net_drop.gd` is that measurement, and CI runs it (G.3).

Content only: GDScript, no wire change, no PROTOCOL bump, `Wire.RULES` unchanged, no `binary_version` bump.

### G.1 What changed

- **Found where it happens** (`_pump_one`): straight after the `poll()` that closed it -- before anything else that frame reads that listener's peers -- and at the top of any later frame while it stays closed.
- **Said once, and each of its transports let go as its goodbye would have** (`_lan_closed_by_itself`): the line, the count `lan_closed`, and every id on it through `_on_peer_disconnected`. So a guest gets its `done after` line, what it queued is forgotten, and a phone host whose friend was on it goes back to LISTENING with "they left" and shows its code. Its ids and addresses leave `_via` and `_addresses` too, which otherwise went on counting against their address's transports at the door and refusing their ids as twins on the other listener.
- **Opened again at once, on the same port** (`_open_lan`, which `host` now opens with): the server goes on being found by its code, and a phone too, with no new session. **The internet listener and whoever proved an invite there are not touched**, so the server's friends from outside play on. Re-hosting the whole session, which the issue also offered, would have cut them.
- **Tried again after one second, two, four -- up to a minute -- while the port will not open** (`LAN_REOPEN_EVERY`, `LAN_REOPEN_MOST`), as the server's own first listen backs off, and for the same reason: each try the port refuses is 4.7's own `Couldn't create an ENet host.` in the journal, which no limiter of ours reaches. Ours is one warning every 10 s (A.6); open again, the line says how long it was down. A socket bound to every address opens whether or not any network is up, as the measurement shows, so this takes something else holding the port meanwhile. Should it close again inside a second of opening, it waits out that second first.
- **`_count_arrivals` counts each listener on its own**: one that is closed no longer stops the other being counted.
- **A screen that closes the session, or hosts anew, on hearing "they left"** is left to it: the host stops letting go at that guest, and the listener is not opened again behind it.

### G.2 What it costs a player

Nothing new. A guest of a listener that closed was dropped before G too -- ENet's `close()` disconnects every transport on it -- and now it can call again at once, where before nothing answered it until the server restarted or the phone host left its screen.

### G.3 Checked

- **The real thing, in CI** (`tools/net_drop.gd`, the "Take the network from under a host" step): a dedicated host with a guest in, in a network namespace; the address taken away by a root shell there, and the host must say so within `WAIT`, let the guest go and listen again, open; the address back, and a new guest must be in. It closed 0.42 s after the address went -- ENet's ping to the guest, within half a second -- and the whole step takes about a second. It is the one check that a send fails and ENet closes the listener, which an engine upgrade could change.
- **net_probe, `invites` section**, on real sockets over loopback, closing the listener as `poll()` does:

  | # | What | What must hold |
  |---|---|---|
  | H1 | The server, with a LAN guest and one by bob's invite; its LAN listener closed between two frames | The LAN guest let go -- its line, nothing of it kept -- and the listener open again that frame, where it calls back and is in; bob's guest plays on throughout; the log says it once: closed, then open again 0.0 s on |
  | H2 | A phone host with its friend in; the same | Back to LISTENING, "they left", and the friend calling back is in |
  | H3 | A phone host's listener closed inside the very service call a caller came in by -- after the session made its record | Found in that frame, the record let go, and the caller calling again answered on the listener opened anew |
  | H4 | The server's, with the port taken the moment it closed, for 5 s | Tried at once and again after one second, two and four -- 3 tries, where trying every second makes 6 -- and said once; arrivals at the internet listener still counted and its guest playing on; the port free, open again at the next try, 7.0 s on, and a LAN guest in |

  339 checks, all PASS; the probe finishes in 160 to 162 s and 14,400 to 14,500 frames, measured three times.
- **net_fuzz** (part D): a new step, `L`, the LAN listener closing by itself with its transports gone and nothing said, in about one step in 250; after every step, a closed LAN listener open again inside a second -- this port is never anybody else's -- closed exactly when the host thinks so, and no address kept for an id no listener holds. `lan_closed` is a path the coverage check now demands. Two saved cases, 84 in all: a guest and a caller still saying hello on the server, beside a friend by invite; and a phone's listener closed again the moment it opened -- so held closed for a second -- and once more after. Seeds 1 to 6 pass.
- **Eight bugs planted one at a time**, each run against the fuzzer (seed 1, with the saved cases), the probe's `invites` section and `net_drop`:

  | Planted | The fuzzer | The probe | net_drop |
  |---|---|---|---|
  | the bug as filed: nothing handles it | unaided, both saved cases, and coverage | H1-H4 | yes |
  | let go, never opened again | unaided, and a saved case | H1-H4 | yes |
  | opened again, its peers' records kept | unaided, and both saved cases | H1-H3 | yes |
  | found only the frame after the `poll()` that closed it | -- | H3 | -- |
  | `_count_arrivals` stopping with it, as before | -- | H4 | -- |
  | tried every frame | -- | H4 (250 tries) | -- |
  | tried every second, never backing off | -- | H4 (6 tries) | -- |
  | the host never learning it is open again | unaided, both saved cases, and coverage | H4 | -- |

  The probe's `invites` section writes its books under `user://`, so two copies run side by side must each have a data directory of their own, or each wipes the other's and fails checks that have nothing to do with the bug.

### G.4 What G does not do

- **Why a send failed** is not logged: 4.7 says `Sending failed!` with no reason, and the line before ours in the journal is all there is.
- **The internet listener closing by itself** is as C left it: its peers let go, and the server's next look at its invites opens a new one. A phone has none.
- **A guest's own socket failing** ends its call as any lost connection does; that is not this.
- **A dropped Wi-Fi still ends a phone's game where it did.** When the phone's address goes with no other way out, its next send fails and ENet closes the listener, before G as after. G makes the phone say so -- "they left", and its code shown again -- and answer the friend's next call once the Wi-Fi is back, where before it went on showing a friend who had gone and answered nobody.
- **A host keeps the address it began with.** A network that comes back with another address leaves a phone's code, and the server's, naming the old one. The server's listener answers on the new one, but only a friend who knows it can call. A phone's answers nobody there: its door takes its own /24 alone, and that is the old address's (F.1), so a phone back on another /24 refuses every caller from it. Both were so before G, and a new session -- the screen opened again, the service restarted -- is still how to take the new address.

## H. #106 in one PR: an invite says what it dials, and junk costs the log nothing

The #75 read of `game/net/invite.gd` found two low things. Both are in what a paste does on the phone that pastes it -- the player's own action -- and neither involves a secret.

- **An invite could point a phone at its own device without looking like it.**
  - `address_ok` took host names a resolver reads as numbers. glibc reads `2130706433`, `127.1` and `0x7f.0.0.1` as 127.0.0.1.
  - It also took literals that are no one machine: `0.0.0.0`, `255.255.255.255`, `::`, `ff02::1`.
  - The call screen shows the address as written. So for up to 8 s, and one diagnostic handshake, a phone sent DTLS and ENet connection packets somewhere its screen did not name.
  - `--reach` took the same forms, and the server's `_near_warning` said nothing of them.
- **A crafted paste could print thousands of engine error lines.**
  - Junk behind a valid check reached the engine's base64 and X.509 error paths, a line each.
  - The check is no secret: anyone can compute it.
  - The first review of this PR found a third path: a surrogate on its own, which Windows' clipboard hands over from text cut in the middle of a pair. `_squeeze` made a character of each, and each one printed a line.

Content only: GDScript, no wire change, no PROTOCOL bump, `Wire.RULES` unchanged, no `binary_version` bump.

### H.1 What changed

- **An address shows what it dials** (`Invite.address_ok`, with `_numeric` and `_literal_problem`):
  - **A name whose last label is all digits, or starts `0x`, is refused.** That is how a C resolver reads a number, and no top-level domain is either.
  - **A literal is judged as the call dials it.** An IP literal never meets a resolver: `create_client` reads it with Godot's own parser, IPv4 as four decimal numbers. So `203.000.113.007` is 203.0.113.7 on the screen and on the wire alike, and is taken as before.
  - **A literal must be one machine.**
    - Not the unspecified address -- `0.0.0.0` and the rest of 0/8, `::` -- which a socket takes to mean its own device.
    - Not the broadcast address `255.255.255.255`, multicast 224/4, or the reserved 240/4 around them.
    - Not IPv6 multicast, `ff00::/8`.
  - **IPv4 in IPv6 clothes is taken only showing its IPv4 address** -- `::ffff:203.0.113.7`, held to IPv4's rules -- and never in hex, where `::ffff:7f00:1` is 127.0.0.1 unseen.
  - **Nor spelled so that the two readings part.** Godot reads any dotted tail as IPv4 in IPv6 clothes, wherever the `::` sits: `0:ffff::0.0.0.0` dials 0.0.0.0, where the plain reading is an ordinary IPv6 address. A dotted tail is taken only where the plain reading is IPv4 in IPv6 clothes too. The second review found this hole, open in both earlier cuts: an owner could mint an invite to a friend's own device with it, and a crafted line could carry one.
  - **And `Lan` must read it as the call does.** `Lan` is what places an address: a home network, for the owner's warning, and loopback, for a phone offline. So a spelling it cannot read is refused, though Godot would dial it: an IPv4 part padded past three digits, `203.0000.113.7`, or a `::` standing for no group at all. The third review found the IPv4 half of this.
  - **What the call dials is judged first**, so a refusal names the last thing to fix: `::ffff:e000:1` is refused as multicast, not as hex that an owner would then rewrite as `224.0.0.1` and see refused again.
  - Loopback stays: `127.0.0.1` and `::1` say what they are.
- **Refused everywhere an address is asked about:**
  - `--reach` says why, and for a number, what to type instead.
  - The mint (`Invite.format`) makes nothing.
  - A pasted line reads as damaged.
- **A `--reach` stored by an older build that this one will not call is named, not taken for none** (`InviteBook.reach_refused`, `reach_said`). The server's status line, `--invites` and `--invite` each say which address it was and why, and to set it again. Setting a new one still names the invites sent with the old one, to be minted again. A port a hand made no port of -- out of range, or no number at all, which was a script error -- is said to be the port's fault, not the address's, and is never shown as a port: those lines name the address alone (`_stored_text`), since no invite ever called it.
- **What is no character at all is taken out of a paste** (`_squeeze`): a surrogate on its own, and anything past U+10FFFF. None is ever part of an invite.
- **Base64 is checked for shape before it is decoded** (`_base64_whole`): whole groups of four, and `=` only at the end, two at most.
- **A certificate is checked for shape before it is parsed** (`_der_whole`): one DER SEQUENCE, exactly as long as it says.
- **At most `CERTIFICATES_MAX` (4) certificates are parsed from one paste.** What does reach the X.509 parser costs four lines at most. A real paste holds one invite, or two in a copied thread; a fifth candidate with a good check is damage.

### H.2 Measured

The same scratch script, run on `main` and on this PR:

| Paste | `main` | H |
|---|---|---|
| F7's 19 addresses that do not show what they dial | 19 taken | none taken |
| F7's 10 that do, zero-padded and IPv4 in IPv6 clothes among them | 10 taken | 10 taken |
| F7's 5 that dial what they show but that `Lan` reads otherwise | 5 taken | none taken |
| 2,000 invites whose base64 does not decode (the paste is cut at 64 KB) | 1,455 engine lines | 0 |
| 50 invites whose certificate is DER-shaped junk | 50 engine lines | 4 |
| `Invite.parse` of a real invite behind 60,000 surrogates on their own, in memory | 60,000 lines | 0 |

A first cut of H also refused a leading zero and all IPv4 in IPv6 clothes, as a C resolver would misread them. The first review measured what the call dials instead: Godot's parser, which reads them as they show. Both were ways a friend could call before H, and would have left an owner's `--reach` and every invite minted with it silently dead. Both are taken again.

### H.3 Checked

- **net_probe, `invites` section**, three new checks, each with no socket:

  | # | What | What must hold |
  |---|---|---|
  | F7 | 10 addresses that show what they dial, `203.000.113.007` and `::ffff:203.0.113.7` among them; and 19 that do not: `2130706433`, `127.1`, `0x7f.0.0.1`, `0x7f000001`, `017700000001`, `0.0.0.0`, `0.1.2.3`, `255.255.255.255`, `224.0.0.1`, `240.0.0.1`, `::`, `ff02::1`, `::ffff:7f00:1`, `::ffff:0.0.0.1`, `::ffff:224.0.0.1`, `pond.example.123`, `0:ffff::0.0.0.0`, `0000:FFFF::0.0.0.0`, `0:ffff::203.0.113.7`; and 5 that dial what they show but that `Lan` reads otherwise: `203.0000.113.7`, `0203.0.113.7`, `::ffff:203.0000.113.7`, `1:2:3:4:5:6:7::8`, `0:0:0:0:0:0::ffff:203.0.113.7` | The first taken at `--reach`, minted and read back. The others refused at `--reach` with a sentence saying why, never minted, and damage in a line written without the address check. The last five say they are not read the same way |
  | F8 | Three pastes: 2,000 invites whose base64 does not decode; 50 whose certificates are not DER; 50 whose certificates are DER and do not parse. Then a real invite after three of the last kind, and after four. Then one behind 60,000 surrogates on their own | 0 engine lines, 0, and 4. The real invite reads after three, and is damage after four. Behind the surrogates it reads, and nothing is printed |
  | F9 | A `--reach` of `2130706433` stored as an older build could, with an invite minted before it; then a good address with port 70000, and with a port that is no number; then a new `--reach` over the last | Named at `--invites` and at the mint, with why and what to do; setting a new one still says the invites already sent call the old. The bad ports are said to be the port's fault, with no script error, and are never shown as a port: the new `--reach` says the invites already sent call `203.0.113.7`, the address alone |

  342 checks, all PASS.
- **net_fuzz**:
  - The `invite` section now fails a paste that costs the engine's log more than `CERTIFICATES_MAX` lines, or any line but a certificate's that does not parse. Before, it counted them and went on. That now includes the lines a string prints when it does not decode, which the fuzzer's catcher counted nowhere before. Every saved invite case is held to the same rule.
  - Two new mutations: up to 60 spoiled invites, with the whole one after them or not; and a run of surrogates on their own, set into the line.
  - Seventeen saved cases, 101 in all. Each says what it must read as, because the fuzzer's own judge reads an address with the very `address_ok` a bug would break -- as three planted bugs showed, when the first cases said nothing:
    - invites to `0:ffff::0.0.0.0`, `0:ffff::203.0.113.7`, `203.0000.113.7`, `2130706433`, `0.0.0.0`, `::ffff:7f00:1`, `224.0.0.1`, `::`, `ff02::1` and `pond.example.123`, each damage;
    - to `127.0.0.1`, `203.000.113.007` and `::ffff:203.0.113.7`, each of which reads;
    - twenty invites that do not decode;
    - a whole invite after three certificates that do not parse, which reads, and after six, which is damage;
    - a whole invite after six certificates that are not DER at all, which reads.
  - Seeds 1 to 3 pass.
- **Twenty bugs planted one at a time**, each run against the fuzzer's `invite` section (seed 1, with its saved cases) and the probe's `invites` section:

  | Planted | The fuzzer | The probe |
  |---|---|---|
  | base64 decoded without its shape asked | unaided, and a saved case | F8 |
  | a certificate parsed without its DER shape asked | a saved case | F8 |
  | no bound on the certificates one paste parses | a saved case | F8 |
  | surrogates on their own kept in a paste | unaided | F8 |
  | a name whose last label is a number taken | two saved cases | F7, F9 |
  | any IP literal taken | eight saved cases | F7 |
  | 0/8 taken | a saved case | F7 |
  | multicast and reserved IPv4 taken | a saved case | F7 |
  | `::` taken | a saved case | F7 |
  | IPv6 multicast taken | a saved case | F7 |
  | IPv4 in IPv6 clothes taken in hex | a saved case | F7 |
  | a dotted tail taken where the plain reading is not IPv4 in IPv6 clothes, as the first two cuts did | a saved case | F7 |
  | an IPv4 part padded past three digits taken, which `Lan` cannot read | a saved case | F7 |
  | a zero-padded address refused, as the first cut did | a saved case | F7 |
  | IPv4 in IPv6 clothes refused while it shows its address | a saved case | F7 |
  | a stored `--reach` it will not call taken for none | -- | F9 |
  | the invites sent with it not named when it is changed | -- | F9 |
  | a stored port out of range blamed on its good address | -- | F9 |
  | a stored port that is no number read as one: a script error | -- | F9 |
  | a port that is no port shown as one | -- | F9 |

  Planting found two things in the checks themselves. The fuzzer's saved cases passed every address bug until each case said what it must read as. And one bug, planted by deleting a loop's only line, left `invite.gd` unable to parse -- 120 script errors and no verdict at all -- so it was planted again as a `pass`.

  Planting tests the checks, never the rule they hold. The dotted-tail hole was in the rule itself, and every check passed on it: the second review found it by reading Godot's parser. The third review then tested the rule against the engine itself, over 989,524 spellings dialled through `ENetConnection.connect_to_host`: every IPv6 literal the rule takes dials exactly what `Lan` reads. It also found the IPv4 padding that H.1 now refuses.

### H.4 What H does not do

- **A subnet's broadcast address is still dialled.** `192.168.1.255` is one machine's address on a network wider than a /24, so the address alone cannot tell. An invite to the broadcast address of a friend's own network makes their phone call every device on it for up to 8 s. Only a server holding the invite's pinned certificate can answer.
- **The resolver's view of a name was measured with glibc alone.** Android's and Windows' were not checked. The rule refuses any last label a C resolver could read as a number.
- **The clipboard is decoded before the game sees it, and the engine logs lone surrogates as it does so.** On Windows, the engine keeps a lone trail surrogate and says so, across the whole clipboard, not just the 64 KB a paste reads. A lead surrogate that an ordinary character follows is dropped without a word, and 4.7's UTF-16 decoder then adds one stray character at the end of the text -- an engine bug, measured with `get_string_from_utf16`; a paste still reads through it. On Android, the engine says so and puts U+FFFD in its place. Those lines are the engine's, before any paste is read: H.2's "0" is `Invite.parse` of a string already in memory. Not checked on a device.
- **A few spellings that dial what they show are refused**, because `Lan` reads them otherwise, or not at all: an IPv4 part padded past three digits, bare or inside IPv6 (`203.0000.113.7`, `0203.0.113.7`, `::ffff:203.0000.113.7`), and a `::` standing for no group at all (`1:2:3:4:5:6:7::8`, `0:0:0:0:0:0::ffff:203.0.113.7`). Taken, they would pass the owner's home-network warning unseen, and `0127.0.0.1` would not be loopback to a phone offline. `main` took them. Nobody writes them.
- **A friend holding an invite to an address this build will not call** sees the first page again, as if they held none, and a paste of it says damaged. Sending the same line again does not help. Their owner's server says why at every look, and a new `--reach` and a new invite are the way back.
- **Ports are any from 1 to 65535**, as before: a router may map any of them.
- **Two whole invites in one paste**: the first still wins, silently. A "which one?" answer is the owner's to want (the issue's "Also noted").
- **A name that resolves to loopback, or to no one machine** -- `localhost`, or a name a friend's DNS points at 127.0.0.1 -- is still dialled. The name is on the screen, so the invite says what it dials as far as a person can check.

### Files

- **Part A (built):** `game/net/net_session.gd`, `game/net/wire.gd`, `game/net/lan.gd`, `tools/net_probe.gd`, `docs/server.md`, the comment on `.github/workflows/ci.yml`'s LAN step, and this document.
- **Part B (built):** `game/net/referee.gd` (new), `game/net/pond.gd`, `game/net/net_session.gd`, `game/net/wire.gd`, `game/normal/normal_mode.gd` (the cut line, and comments), comments in `game/normal/cell.gd`, `food.gd` and `genome.gd`, `tools/net_probe.gd`, `tools/net_lag.gd`, `docs/server.md`, `docs/design/shared-pond-ux.md`, the comment on `.github/workflows/ci.yml`'s LAN step, and this document.
- **Part D (built):** `tools/net_fuzz.gd`, `tools/net_fuzz.tscn`, `tools/net_fuzz_corpus.txt` and `tools/net_fuzz_cert.pem` (all new, and excluded from export with the rest of `tools/`), the "Fuzz the network code" step in `.github/workflows/ci.yml`, and this document.
- **Part F (built):** `game/net/lan.gd` (`CELLULAR_PREFIXES`, `hosting_address`, `pick_hosting`, `same_24`, the ranking), `game/net/net_session.gd` (`host`, `_admit`), two checks in `tools/net_probe.gd`, the phone door in `tools/net_fuzz.gd` and `tools/net_fuzz_corpus.txt`, and this document.
- **Part H (built):** `game/net/invite.gd` (`address_ok`, `_numeric`, `_literal_problem`, `_v4_problem`, `_unread`, `why_not`, `_squeeze`, `_base64_whole`, `_der_whole`, `CERTIFICATES_MAX`), `game/server/invite_book.gd` (`reach_refused`, `reach_said`, `_stored_text`, `_stored_reach`, `set_reach`, `mint`, `listing`), `game/server/server.gd` (its status line), F7-F9 in `tools/net_probe.gd`, the `invite` section of `tools/net_fuzz.gd` and its saved cases in `tools/net_fuzz_corpus.txt`, `docs/server.md` §9.2, `docs/design/invites-ux.md` §6.2, the comment on `.github/workflows/ci.yml`'s LAN step, and this document.
- **Part G (built):** `game/net/net_session.gd` (`_open_lan`, `_pump_one`, `_lan_closed_by_itself`, `_count_arrivals`), `tools/net_drop.gd` and `tools/net_drop.tscn` (new, and excluded from export with the rest of `tools/`), H1-H4 in `tools/net_probe.gd`, the `L` step in `tools/net_fuzz.gd` and `tools/net_fuzz_corpus.txt`, `docs/server.md` §7, the "Take the network from under a host" step in `.github/workflows/ci.yml` and the comment on its LAN step, and this document.
- **Part E (built):** `game/net/net_session.gd` (`_admit`, `_evict`, `_left_unproved`, `_bar`), `game/net/lan.gd` (`wider_key`), `tools/net_probe.gd` (R1-R4), `tools/net_fuzz.gd` and `tools/net_fuzz_corpus.txt`, `docs/server.md`, the comments on `.github/workflows/ci.yml`'s two network steps, and this document.
- **Pack 4's SISTER (protocol 6, built; automation.md §10.3):** `game/net/wire.gd` (`PROTOCOL`, `MOST_RULES`, `RULE_BYTES_MAX`, `RULE_BYTES`, `SISTER_MIN`/`MAX`, `GUEST_OTHER_MAX`, `guest_cap`, `sister_payload`, `take_sister`), `game/net/net_session.gd` (the gate's step 2, `_oversize`), `game/net/pond.gd` (`sister`, `sister_list`), T1, T2 and checks 24 to 27 in `tools/net_probe.gd`, the SISTER frames and the `takes`/`refuses` replay in `tools/net_fuzz.gd` and `tools/net_fuzz_corpus.txt`, the comment on `.github/workflows/ci.yml`'s LAN step, and this document.
- **Part C (built):** `game/net/invite.gd` (new), `game/server/invite_book.gd` (new), `game/net/net_session.gd`, `game/net/wire.gd`, `game/net/lan.gd` (`is_loopback`), `game/net/pond.gd` (`cut_off`), `game/server/server.gd`, `tools/net_probe.gd`, `tools/net_lag.gd`, `docs/server.md` (§9, and the notes it changes), `server/biogenic-server.service` (its Description), `server/install-server.sh` (its comments and closing lines), `game/server/updater.gd` (what it is told, from the review), the comment on `.github/workflows/ci.yml`'s LAN step, and this document. The screens built on it are `docs/design/invites-ux.md`'s: `game/net/earshot.gd` and `.tscn`, `game/net/far.tscn` (new), `game/mode_select.gd` and `.tscn`, and `tools/earshot_shot.gd`.
