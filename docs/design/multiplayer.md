# Multiplayer: what it would mean, and what it would cost

Phase-independent study. The owner asked for every option, hosted on a phone and
hosted on a dedicated server, with the standing note that nothing forces a
single choice.

Status: no multiplayer code exists. Nothing in this document has been rendered,
exported, or run on a phone. Every number below is either read out of this
repository, measured headless on a Linux x86-64 container, or fetched from a
vendor. §9 says which is which, because the gap between them is this document's
largest weakness.

---

## 0. Three corrections that move the answer before anything else

Three premises that every part of this study was built on turned out to be
wrong. Two of them change the recommendation.

### 0.1 Clients do not auto-update. Updating is an opt-in, three-tap flow.

This is the correction that matters most, and it was repeated as established
fact in every option study, every refutation and five of the eight cross-cutting
notes: *"clients auto-update independently"*, *"installed games pick it up on
their next launch"*, *"players converge within one launch"*.

Read the code. `launcher.gd:89-92` calls `UpdateService.check_for_updates()` on
launch. That function ends at `update_service.gd:164` with
`return _finish(State.CONTENT_READY, "")` — **it fetches the manifest and sets a
state, and downloads nothing.** Downloading happens only from
`_on_update_pressed()` (`launcher.gd:243`), i.e. a player pressing a button
labelled `"Download update"` (`launcher.gd:298`). That calls `_prompt_update()`
(`launcher.gd:325`), which shows a *"What's new"* confirmation whenever the
release has changelog notes — and `ci/make_manifest.py` always emits them, so
there is a second confirmation in the normal case. Then the state becomes
`RESTART_REQUIRED`, the button becomes `"Restart"` (`launcher.gd:302`), and the
pack is mounted by `BuildInfo._init()` on the launch after that.
`UpdateService._ready()` is `set_process(false)` and nothing else. And
`grep -rn "UpdateService\|BuildInfo" game/` returns zero hits — the game never
touches either.

**A player can press Play and keep playing on a months-old content pack
indefinitely, with a bar in the corner of a screen they walk past.** The roadmap
already implies this: *"A phase is done when it has shipped to `main` **and
players have it**"*.

Four conclusions in the dossier invert:

| What was concluded | What it becomes |
| --- | --- |
| Skew "fragments the pool on every release" but converges in a launch | Skew is **permanent and unbounded**. The pool never converges on its own. A `PROTOCOL` constant stops being hygiene and becomes the only thing that works. |
| **The ordering hazard** — deploy after `publish_release.sh` and clients auto-update to a protocol the live server does not speak. Called *"the single largest cost multiplayer imposes on this pipeline"* in four studies. | **The race runs the other way.** Clients lag the server, sometimes by many releases. The danger is not publishing early; it is a server that stops speaking protocol N−k for unbounded k. "N and N−1 for one release" is wrong — there is no bound. |
| "Forced update before play is a nudge" | Forcing a **content** update is the only mechanism by which two players ever reach the same pack. It is still dangerous for *binary* updates: a refused Android install lands in `NEEDS_PERMISSION` (`update_service.gd:55`) and strands that player permanently. |
| The asynchronous options' skew tolerance | Gets stronger, for a reason nobody stated: a tolerant `{gene:tier}` decoder is the only wire format that survives an installed base spread across arbitrarily many content versions *forever*. |

Three of the four "decisions expensive to reverse" in the scope work were argued
from the wrong premise. They are re-derived in §7.

### 0.2 There are approximately one or two players, and no way to acquire a third

Nobody asked. The answer is one unauthenticated HTTP request, and it was
available the whole time.

| `api.github.com/repos/sinikebe/biogenic`, measured today | |
| --- | --- |
| Repo created | **2026-09-13** — the project is eight days old |
| Releases | 55 |
| Stars / forks / watchers / subscribers | **0 / 0 / 0 / 0** |
| Description, homepage, topics, discussions | none, none, none, disabled |
| `biogenic.apk` downloads, all 55 releases, all time | **29** |
| `Biogenic.exe` | **16** |
| `content-android.pck` | **55** |
| `manifest.json` | **415** |

`manifest.json` is a launch counter — `launcher_config.gd:110` builds
`releases/latest/download/manifest.json`, `check_on_launch` defaults true, and
`launcher.gd:92` fires it on every launch of every install. Subtract the ~54
that `ci/collect_changes.sh:59` pulls per release build and the fetches this
study itself made, and a few hundred launches over eight days remain.

**This does not mean "don't build it."** It means every option was ranked on
axes that are all downstream of population, and the ranking changes:

- The dedicated server's decisive claim was capacity and reach. At two players
  who already know each other, "reaches the internet" means "reaches one
  specific person."
- The deploy-ordering hazard is severity-scaled by population. Two installs, one
  of them the owner's. You can text the other person.
- **Abuse, moderation, GDPR, DDoS, uninvited peers, rate limiting, child safety,
  matchmaking, lobbies, identity, host migration and reputation all presuppose
  strangers. There are none, and the game is currently unfindable by
  construction** — no store page, no description, no topics, zero stars.
  Those analyses are not wrong; they answer questions that do not arise. Defer
  them wholesale rather than designing against them.
- PlayFab's 1,000-lifetime-player free tier, called "the worst free-tier shape on
  the list," is 999 players of headroom. Supabase's free allowance of ~7
  match-hours per month is more multiplayer than this game will see this year.

Three things survive the reframe, and two of them are the owner's: **is a second
cell readable through the membrane** (§1.3), **what happens to a dividing
player** (§6.2), and **who is the second person** (§10, row 1).

### 0.3 `panes.gd` is one membrane drawn twice, not two view stacks

A claim worth correcting because it would otherwise make §4.1 look cheaper than
it is. The replay's two-pane screen does **not** instantiate two independent
perception stacks: `panes.gd:290-305` instantiates **one** Membrane, takes
`_bus = _membrane.bus`, calls `_bus.set_process(false)`, and then creates a
second `ColorRect` whose material is `_membrane.field.material` — *"One material,
two rects."* Both panes show the same membrane state; one has the world drawn
over it. That is a one-observer, two-view display, not split-screen.

What survives, and it is the valuable half: **the geometry is built and has been
judged at both shapes.** Panes are 640×624 at 1280×720 and 800×624 at 2400×1080,
and `panes.gd:368-371` records why the bearing map survives: *"the shader's
bearing is aspect-corrected: a lobe at -42 degrees lands at the same relative
spot on 640x624 as on 1280x720, so the panes agree with each other and with the
shipped game by construction."* The membrane shader is **proven to render
correctly into a half-width rect at both shapes.** That is the hard part of
split-screen, and it is done.

---

## 1. What multiplayer would mean for this game

### 1.1 The design case is weak, and it should be said first

Multiplayer appears nowhere in `docs/design/roadmap.md` — a full-text search of
all fifteen design documents for "multiplayer", "networked" or "online" returns
nothing. Phases 6 through 9 are the chase re-measured, a third view, a second
water, multicellular bodies. This is new scope competing with an order the owner
has already reasoned about and written down.

Worse, Phase 6 **blocks the interesting half**. The roadmap calls it *"the one
thing in the whole plan that a human has to play rather than measure"*, and its
open values — `CRUISE_OVER_PREY`, `ESCAPE_SECONDS`, `DRIFTER_SHARE`,
`PEER_SPREAD`, `ARRIVAL_GAPE_MAX` — are precisely the ones player-versus-player
predation is load-bearing on. Building PvP against a chase model the project
admits is unmeasured is building on sand.

And the session shape is hostile to the thing the word "multiplayer" usually
buys. A generation is 30–45 seconds (`lifecycle.md` §5). A run is minutes. There
is no account, no persisted genome, no lobby, no friends list. At this
population, any feature that requires two people to press Play within the same
ninety seconds is a feature that is, in practice, never exercised.

**So: this is not a game that is missing other people.** It is a game about
being alone in the dark with a bad sense.

### 1.2 What it would actually be, if it were good

Three things survive that assessment, and they are not the same thing.

**A second speed in the water.** The water contains exactly two speeds:
`DRIFT_SPEED := 9.0` (`food.gd:214`) and a hunter's `CRUISE_OVER_PREY 1.20 ×
your own`, about 68 u/s. A player swims at 56.5 u/s. A second player introduces
a third — **moving fast, on purpose, and not at you** — which is a reading the
water has never produced. The AI has three legible states (DRIFT is a random
walk, STALK converges monotonically, BREAK flees and rests 30–55 s). A player
does none of them cleanly, and the strongest tell is the simplest: **a player
turns and stops.** Nothing in the water does that.

**A dread that never resolves.** An AI's dread always resolves — it commits or it
breaks off. A player near your size contributes continuous dread that does
neither. A dread that sits at 0.3 for ninety seconds and does nothing is a
sensation the game cannot currently produce, and it is genuinely unnerving.

**And it costs nothing in the playfield.** `perception.md` §1: *"Never a
position, never a distance, never a shape, never a count, **never an
identity**."* A player who strongly suspects a mark is a person and cannot
confirm it is in exactly the epistemic posture this game is built to produce. No
new lobe, no new hue, no nameplate. That is `edibility.md` §6's test passed,
which is the highest bar this project sets.

There is also a beat the design has already half-written. `lifecycle.md` §4.2
leaves the declined sister in the water as *"the one cell in the water that is an
exact match for you"*, and §9 row 2 records keeping her because dropping her
*"loses the best free encounter in the design."* Handing that sister to another
player costs one function call and turns the choosing screen's decision into two
axes instead of one: which do I keep, and which do I *release*. That is a new
decision in the game's biggest moment, for free.

### 1.3 The question that gates everything, and it needs no netcode

Seven of the nine option studies list the same open question and none of them
answered it:

> **Can two cells in one body of water be read through the membrane at all?**

The membrane already carries 34 other cells. Whether a player can distinguish
*the human* from the water is not a networking question, and answering it does
not require a single line of netcode. `put_sister()` (`food.gd:2342`) already
places an exact-match body with an arbitrary genome, `tools/drive.gd` can drive
it, and `tools/shot.gd` photographs at 1280×720 and 2400×1080. It is an
afternoon.

`CLAUDE.md` is explicit that nothing is finished until someone has looked at it.
After nine option studies, nine adversarial refutations and eight cross-cutting
investigations, **nobody has rendered a frame with two cells in it.** That is the
single highest-information experiment available and it should happen before any
other work in this document.

---

## 2. What is unavailable under the no-GDExtension rule

The rule eliminates more than anything else in this study, and it eliminates the
options most people reach for first.

**WebRTC is a stub, measured on 4.7.stable.** `ClassDB.class_exists(
"WebRTCPeerConnection")` returns `true` — which is a trap, not evidence.
Instantiating it prints `WARNING: No default WebRTC extension configured. at:
create (modules/webrtc/webrtc_peer_connection.cpp:53)`, `initialize({})` returns
`OK` while doing nothing, and every virtual (`_initialize`,
`_create_data_channel`, `_create_offer`) errors as unimplemented. The same stub
string is present in the shipped Android release template. Godot's own 4.7 docs
say it verbatim: *"These classes are available automatically in HTML5, but
require an external GDExtension plugin on native (non-HTML5) platforms."*

That single fact removes, together:

- **ICE, STUN and TURN.** There is no NAT-traversal machinery in core at all. A
  full `ClassDB.get_class_list()` scan for turn/stun/ice/nat returns only false
  positives.
- **Peer-to-peer over the internet**, in every form. Without hole-punching, two
  phones on two carriers cannot reach each other, and no amount of engineering
  inside this project changes that.
- **Every third-party backend whose Godot SDK is native**: Photon Fusion (a
  GDExtension at 3.0.0-preview, documented as *"not intended for production
  use"*, and its quick-start targets 4.6 rather than 4.7), Colyseus' current
  official SDK (a GDExtension, in beta), all Epic Online Services bindings,
  GodotSteam. Hathora is moot on other grounds: announced shutdown 4 March 2026,
  gone 5 May 2026.
- **C# transports.** The most recent successful Godot 4 multiplayer ship
  (Pratfall, Godot 4.6, four people, six months) solved its transport problem
  with C# plus Epic Online Services plus SteamNetworkingSockets. Every one of
  those is unavailable here, and none of them exists on Android.

**Deterministic lockstep is dead, and for reasons independent of the rule.** The
sim runs entirely in `_process(delta)` (14 files, zero `_physics_process`),
`project.godot` sets no `physics_ticks_per_second` and no `max_fps`, and CI
achieves reproducibility only by forcing `--fixed-fps 60`. Nothing in `game/`
ever calls `seed()` — the only `seed()` in the repository is `tools/drive.gd:614`
— so **a shipped run has no reproducible world at all**, and 37 of the 38 RNG
call sites draw from the process-global stream.

Fixing all that is mechanical. What is not mechanical is cross-platform
bit-equality, and here the dossier's own headline argument should be *withdrawn
and replaced*, because the adversarial pass demolished it: the claimed mechanism
— `sin(heading)` at `cilia.gd:1295` flipping the boolean at `cilia.gd:1323` — is
attenuated by float32 narrowing. Perturbing that site by **ten orders of
magnitude more than a libm ULP** produced bit-identical world state over 7,200
ticks and seven meals; 200,000 random angles perturbed by 2 ULP changed the
resulting float32 zero times. And Godot 4.7 sets `-ffp-contract=off` on Android
and MinGW and `/fp:strict` on MSVC, which is what actually makes `Vector2.dot()`
and `length()` comparable across ARM64 and x86-64 — not IEEE 754 and not the
GDScript VM.

So the honest statement is: **the margin is large and nobody has computed the
failure rate.** Lockstep dies on better grounds anyway. Osmos — same genre, same
absorb-to-grow physics, a team that had shipped the game twice — spent about
three man-years over a year on multiplayer and **never got iOS↔Android
cross-play working**, citing floating-point determinism. Bionic's libm ships in
the device system image with SoC-vendor assembly, so even two arm64 phones on
different Android builds are not guaranteed to agree; `export_presets.cfg:30-31`
ships both `armeabi-v7a` and `arm64-v8a`, so "two Android phones" is not even one
ABI. Lockstep also requires every client to hold the entire world, which is the
exact opposite of this game's premise — a point OpenConflict makes formally:
StarCraft and Warcraft 3 could not cull behind fog *because* they are lockstep,
while Heroes of Newerth could *because* it is not.

**Rollback (GGPO-style) is also out**, for a mundane reason rather than a clever
one. Godot 4.7 ships no rollback support; both known GDScript implementations
(Snopek's, netfox) register **autoloads**, which are `project.godot` entries and
therefore frozen in the binary and unreachable from a content pack. Writing one
from scratch means ~1,800–2,800 lines across twelve files, and the cheap
"client rolls back only its own cell" fallback does not escape the problem it
claims to: `cell.gd:850-858` emits `dashed` and `impulsed` on every re-simulated
frame, and `normal_mode.gd:1068-1071` spends hunger on each one.

Two things that are *not* unavailable, contrary to reasonable assumption:

- **UPnP and DTLS both ship in the Android release template.** Verified by
  extracting `lib/arm64-v8a/libgodot_android.so` from the official 4.7 `.tpz`:
  `UPNP_AddPortMapping`, `User-Agent: Godot Engine/1.0 UPnP/1.1
  MiniUPnPc/2.3.3`, `DTLSServer`, `PacketPeerDTLS` are all present. The
  historical "Android templates omit modules" worry does not apply in 4.7.
- **UPnP needs no Android permission.** The grounding claim that *"UPnP
  discovery is SSDP over multicast, so it rides the same problem"* as broadcast
  is wrong: `thirdparty/miniupnpc/src/minissdpc.c` opens raw BSD sockets, never
  touches Godot's `NetSocket`, and contains zero `IP_ADD_MEMBERSHIP` calls — it
  binds a unicast socket and receives unicast replies. The `MulticastLock` is
  never involved. UPnP's problem is that there is no IGD on a cellular network,
  not a permission.

---

## 3. Phone-hosting over a mobile network: the answer is no, and it is not close

This was the owner's explicit question, so it gets the unsoftened answer. Six
independent blockers, any one of which is fatal on its own.

**1 — CGNAT.** The canonical measurement (Richter et al., IMC 2016, vantage
points covering >60% of the internet's eyeball ASes) found *"CGN deployment is
ubiquitous in cellular networks with more than 90% of all cellular ASes deploying
CGNs"*, with per-measure detection rates of 94.0% / 92.6% / 94.2% — and the paper
states its own method is a **lower bound**. Nothing since has moved the other way:
the CGNAT appliance market is growing at 10.2% CAGR with 5G cited as the driver.
Treat "the phone has a publicly reachable IPv4" as false, unconditionally.

**2 — No port mapping.** There is no Internet Gateway Device on a mobile bearer;
the gateway is the carrier's PGW. Measured here, `UPNP.discover()` returned 27
with zero devices and **blocked the calling thread for 6,007 ms**. Godot core
has UPnP IGD only — no NAT-PMP, no PCP — so Apple-ecosystem and newer routers are
unreachable even on Wi-Fi.

**3 — IPv6 does not rescue it.** Mobile IPv6 is excellent (Google crossed 50%
on 23 April 2026; T-Mobile US runs IPv6-only with 464XLAT), and there is a real
finding here nobody had: **Godot's ENet is fully dual-stack.**
`thirdparty/enet/enet_godot.cpp:78-79` opens with `IP::TYPE_ANY`,
`net_socket_unix.cpp:292-294` and `:702-708` turn that into `IPV6_V6ONLY=0`, every
`ENetAddress` is a 16-byte IPv6 address, and the shipped Android template uses the
bundled build (the `vanilla ENet` IPv4-only error string is absent from the
`.so`). So IPv6-direct costs literally nothing to attempt.

It still does not work, because reachability is carrier policy: T-Mobile US and
AT&T both filter all unsolicited inbound IPv6 with no user-configurable
exception. Deutsche Telekom sells a fixed-IPv6 APN precisely because the default
one does not do this. And under 464XLAT the handset's only globally routable
address is IPv6 — RFC 6877 is explicit that the architecture *"is not fit for
IPv4 peer-to-peer communication or inbound IPv4 connections."* One caveat for the
other target: 464XLAT is a **handset** feature, and Windows 11 implements CLAT
only on cellular interfaces, with Wi-Fi/Ethernet CLAT still in private preview as
of November 2025 — so a Windows client on an IPv6-only network dialling an IPv4
literal fails. Connect by hostname with both records; state that as mandatory,
not as a nicety.

**4 — Hole punching cannot be attempted.** The best contemporary measurement —
4.4 million attempts across 85,000+ networks in 167 countries — gives
**70% ± 7.1%**, and that figure is conditional on relay-assisted ICE machinery
this project does not have, measured on a population of home-broadband and VPS
peers with **no cellular content in the paper at all**, with the residual ~30%
attributed to exactly symmetric/CGNAT mapping, against which punching is
structurally impossible rather than merely unlikely. Tailscale, who are better at
this than anyone, say plainly that two mobile devices on different cellular
networks *"have a good chance they'll have to use DERP"* and that two devices
behind hard NAT *"will almost always need to use a relay."*

Even at 100% success Godot could not use it: `ENetConnection::create_host_bound`
creates and binds its own socket and there is no API to hand ENet an externally
punched `PacketPeerUDP`. **Rule hole punching out formally, and record it, so a
later phase does not reopen it on optimism.**

**5 — The phone stops executing when the screen goes off, and this kills phone-
hosting even on a LAN.** Traced through Godot 4.7-stable source:
`GodotGLRenderView.onActivityStopped()` calls `pauseGLThread()`;
`GLSurfaceView.readyToDraw()` at :1666 requires `!mPaused && mHasSurface` so the
GL thread `wait()`s at :1531; `GodotRenderer.onDrawFrame` never runs, so
`GodotLib.step()` never runs, so `main_loop_iterate()` never runs, so
`scene_tree.cpp:706-707`'s `multiplayer->poll()` never runs. Home, app switch or
screen-off all reach `onStop`; `onActivityPaused` alone (a notification shade)
does not. `godotengine/godot#36583` — *"Enet disconnects when android app is put
into background"* — is open since February 2020, and
`godot-proposals#3347` ("Implement background services on mobile") is still open
with no PR. The standard fix is an Android foreground service, which is a Kotlin
plugin, which `CLAUDE.md:144` forbids outright.

How long you have: ENet's own constants, from the bundled
`thirdparty/enet/enet/enet.h`, are `PEER_TIMEOUT_MINIMUM 5000`,
`PEER_TIMEOUT_MAXIMUM 30000`, `PEER_PING_INTERVAL 500`. The dossier's headline
"5.5 seconds" was re-measured and is a best case: modelling a frozen (rather than
closed) host on the same binary gave **9,736 / 5,383 / 9,735 ms** across three
runs with a converged RTT estimate, and **31,509 ms** un-warmed. The honest
figure is 5–10 s at LAN RTT, up to 30 s otherwise.

> The framing matters more than the number. That is the transport's *disconnect*
> event, not the time to notice. Any snapshot-driven client knows the host is
> gone after one or two missed ticks — tens of milliseconds — because the world
> stops arriving. The UX fix is a client-side staleness timer, not
> `set_timeout()` tuning.

**6 — Also: a public UDP port on a phone is an out-of-memory button.** Measured:
a single ENet peer that never completed the multiplayer handshake made a Godot
host allocate **24 MiB**, and the ceiling is 32 MiB *per peer* —
`ENET_HOST_DEFAULT_MAXIMUM_PACKET_SIZE` and `MAXIMUM_WAITING_DATA` are both
32 MiB, `enet_protocol_handle_send_fragment` allocates the attacker-declared
`totalLength` on the first fragment, and `peer->totalWaitingData` is per-peer
against a host-wide limit. `ENetConnection`'s measured method list has no
`maximum_packet_size` and no `maximum_waiting_data` setter, so **Godot does not
expose either knob** and GDScript cannot lower them. A four-peer host offers
128 MiB of attacker-controlled allocation on a device already holding a ~52 MB
process. The only lever is keeping `max_clients` small.

**Verdict: phone-hosting over the internet is not hard. It is unavailable.**
Phone-hosting on a LAN works and is free — but only while the host player is
actively looking at their screen, which is an acceptable constraint for a
same-room mode and an unacceptable one for anything else.

---

## 4. The option families

### 4.1 Same device — split screen and shared screen

Never studied. Three mentions in the whole corpus, each a dismissive clause.

It is the only family that needs **none** of the netcode floor: no transport, no
protocol constant, no version skew, no NAT, no relay, no server, no deploy
ordering, no auth, no abuse story, no privacy position, no determinism work, no
fixed timestep, no input seam, no binary bump, and no second act to a merge.

Two of the three hard parts are already done and photographed. The membrane
shader renders correctly into a half-width rect at both shapes (§0.3), which is
the part that could have failed. And `controls.gd` already distinguishes two
simultaneous thumbs: `_owner: Dictionary` maps *a touch pointer index* to a
control (`controls.gd:190-191`, `press(pointer, at)` at `:344`).

Three sub-variants:

- **Shared screen, one camera, two cells.** Cheapest. Full vision only, which is
  fine — this variant *is* the full-vision one. Needs `vision.gd` to bind a
  second cell and a camera that frames two points.
- **Split screen, two POV panes.** `panes.gd`'s geometry, one player per pane,
  but a genuinely second `SignalBus` and Membrane per pane, which `panes.gd` does
  **not** currently have. This is the only configuration anywhere in this study
  where one screen shows what two players feel *and* what is really there —
  which makes it the test bench for §1.3.
- **Windows, two gamepads.** Free on half the shipped targets. One blocker to
  name precisely because it surfaces late: `project.godot` has **no `[input]`
  section at all** (sections are `[application] [autoload] [display] [launcher]
  [rendering]`), every action is a Godot built-in, and `tools/drive.gd:44-46`
  records as measured that a content pack cannot add an InputMap action. So
  player two's bindings must not go through InputMap. They do not have to:
  `InputEvent.device` is on the raw event, `normal_mode.gd:2163` already handles
  `InputEventJoypadButton`, and reading `InputEventJoypadMotion` by device index
  needs no action at all. Content-shippable — but only if designed that way from
  the first line.

Honest costs: it is not what the owner asked for; the division freeze stops both
players identically, so it forces that decision too; and split-screen on a phone
is cramped, though 800×624 per pane is exactly the size `panes.gd` already ships.

**It shares its one genuinely expensive item — the seeder rewrite — with every
other shared-water option, and it is the cheapest way to find out whether that
rewrite is worth doing.**

### 4.2 LAN, phone- or desktop-hosted

Works today, ships as pure content, costs nothing. `ENetMultiplayerPeer.
create_server()` on the host, `create_client(ip, port)` on the joiner. Sub-5 ms
RTT, and the host's screen-off problem (§3) is the only real defect — which
**disappears entirely if the host is the Windows build**. Windows is half the
shipped targets, never reaches `onActivityStopped`, is not thermally throttled
and is not on battery. **Windows-host / Android-guest on one Wi-Fi is the
strongest LAN configuration and nobody proposed it.**

Discovery is the one contested item, and the dossier contradicted itself twice.
Resolved at source: `net_socket_android.cpp:98` shows
`set_broadcasting_enabled()` calling `multicast_lock_acquire()`, so **broadcast
takes the same lock as multicast** — the grounding claim that it does not is
wrong. But `GodotNetUtils.java` creates the lock only
`if (PermissionsUtil.hasManifestPermission(context,
"android.permission.CHANGE_WIFI_MULTICAST_STATE"))` and every acquire begins
`if (multicastLock == null) return;` inside a try/catch. So without the
permission **nothing crashes and nothing errors — sending works everywhere, and
receiving is a per-device coin flip** depending on whether the Wi-Fi firmware
filters. That is worse than a clean binary bump, because CI cannot detect it.

Two ways out, both free:

- **A unicast /24 sweep.** Unicast reception is never filtered, so the lock
  question vanishes. Measured: 254 probes in **22.6 ms** with the reply heard on
  the next frame (a second measurement of the same sweep gave 3.8 ms of send
  time — the variance is in the send queue, and the real cost is the reply wait,
  which the ladder budgets at ~2 s anyway). Caveats to validate on hardware: 253
  of those addresses are unresolved so the kernel ARPs each one, which argues for
  two passes about a second apart; and `/24` is an assumption Godot cannot check,
  since `IP.get_local_interfaces()` returns addresses without netmasks.
- **Typing the host's IP** — which is *not* free, and every plan that names it as
  the zero-cost fallback has an unpriced item. `grep -rln "LineEdit\|TextEdit"
  game/ addons/` returns **nothing**: there is no text input anywhere in this
  project. `mode_select.tscn:4` themes the scene with the template-owned
  `launcher_theme.tres`, which styles exactly `Button`, `Label`,
  `PanelContainer` and `ProgressBar` — no `LineEdit` entry, so a field would fall
  back to Godot's default theme inside a scene that has none of it. Add an
  Android soft keyboard over a landscape-locked 1600×720 canvas, unphotographed.

The way out of *that* is the identity work's instinct, and it is right for a
stronger reason than it gave: **a tap-only pictorial code**. Twelve ring
bearings gives 12⁴ = 20,736 codes at four taps, every target ~136 px of arc,
**no `LineEdit` anywhere and therefore no soft keyboard ever**. Bearings are
already the membrane's entire vocabulary. (Seventeen organ glyphs also work —
17³ = 4,913 — but they look like they are describing the room's genome, which
they are not.)

Two open Godot bugs to take seriously before committing: `godotengine/godot#105726`
— ENet clients randomly disconnecting over LAN with no error on either side,
reproduced on 4.3, 4.4.1.stable and 4.5.dev2, still open with no root cause —
and, decisively, **it does not reproduce on localhost**, which is exactly the
single-process CI recipe. Plus `#37186` (server does not notice a force-closed
client). Reproduce both on two real devices for thirty minutes before building on
LAN ENet.

### 4.3 Coupled waters — the option nobody proposed, and the cheapest realtime one

Every option in the dossier assumes one shared body of water and then pays the
same bill: rewriting `food.gd`'s five observer-dependent rules. Nobody asked
whether two players need to share water at all.

**What it is.** Each client runs the shipped simulation unmodified — its own 34
bodies, seeded in its own ring around its own cell, culled at its own `CULL`,
drifter share weighted by its own senses. Nothing about the water is shared or
synchronised. Two rungs:

**Rung A — influence only.** No cell crosses. What crosses is a handful of
events per minute, in the vocabulary the membrane already speaks:

1. *Your ping is a transmission.* Your `ampulla` fires ≤5 returns per 15.2 s. The
   other client receives one event and calls
   `signal_bus.ping(bearing, strength, halfwidth_deg, hold)` — the identical call
   `normal_mode.gd` already makes. They hear you. Pinging becomes how you find
   food **and** how you are found: a look-and-be-seen decision the game does not
   currently have, which follows directly from `three-senses.md` §1.2's own
   baffles reasoning about active sonar.
2. *Your declined sister arrives in their water, live.* `put_sister(bearing,
   distance, body_radius, tiers)` takes a **body-relative bearing and a scalar
   distance** — verified: `var dir := _cell.forward() * cos(bearing) +
   _cell.starboard() * sin(bearing)`. It needs to know nothing about where either
   player is.
3. *Your death leaves a corpse in their water.* Same call, `drifter = true`.
4. *Your growth makes their water harder.* `_sensed()` reads `_cell.extra(gene)`
   and feeds `_drifter_share()` and `_tier_weight()` — it is **already a
   difficulty function parameterised by an observer**. Feed it `max(mine,
   theirs)` and a strong partner raises the tier distribution in your water.
   Shared fate, zero shared state.

**Rung B — the remote cell is a body in your field.** Inject the other player as
an extra `Body`; each player meets the other inside their own ocean. Verified as
cheap: `const COUNT := 34` (`food.gd:75`) is used only in `setup()` at `:915-918`;
every loop is `for i in _cells.size()` and every cached accessor resizes to
`_cells.size()`, so **a 35th body is structurally admissible today**. The work is
an exemption for the remote slot in `_step_recycle` — verified to have no
exemption at all (`food.gd:1685-1688` is an unconditional `if distance > CULL:
_seed(i)`), so your friend would otherwise be silently overwritten by a random
body the moment they drift past 1,700 units.

**What this deletes, itemised against the dossier's own cost table:** the seeder
rewrite (`_seed` origin `:2276`, ring `:2327`, cull `:1687`, `_seed_peer` radius
`:2384-2388`, `_drifter_share`/`_tier_weight` `:2447-2466`); `TARGET_PLAYER := -2`
becoming an index; per-player `hunter()`; `_bite_clock`/`_dart_clock` moving off
the field; the `COUNT` growth the adversarial pass **measured at 3.1× per-world
cost** (580 → 1,785 µs at COUNT 68, because of the O(n²) loops at `food.gd:1443`
and `:1640`) and which cut the server capacity estimate by a factor of three.

At rung A it also deletes: contact adjudication and therefore **authority
altogether** — you can never touch, so nothing needs a referee — and **the
division-freeze problem entirely**, because `_set_simulating(false)` stops *your*
world, which is what it already does and remains correct. `normal_mode.gd:881`'s
unbounded hold survives untouched.

**And it is the most skew-tolerant design available, more than the sensation
stream.** Two clients on different `DRIFT_TURN` and `RING_MIN/MAX` are running
different simulations *in different waters*, where divergence is not merely
survivable but meaningless. Given §0.1 — an installed base permanently spread
across many content versions — that is not a nicety; it is the property that
decides whether anyone is ever matched.

**Its honest weaknesses, stated plainly.** It is *not* two cells in one body of
water. You cannot compete for food, and "there's a big one behind you" is not
true in my water. It delivers presence, not proximity, and if proximity is what
the owner pictures, this is not it. And it raises one real design question: when
a ping arrives, from which bearing? A fixed bearing per session makes your
partner a constant direction you can swim toward forever and never reach — which
is either evocative or a lie the membrane should not tell. Tracking each
player's displacement from their own origin and taking the bearing between those
vectors in a shared *abstract* frame is two floats on the wire and makes "they
went that way" true.

That second answer opens a staging nobody proposed: **if players can converge in
an abstract frame, the expensive shared-water problem only has to be solved for
the seconds they are actually adjacent.** When the displacement vectors come
within `CULL`, one client's water becomes authoritative and the other's is
reseeded around the pair. Every other option treats shared water as
all-or-nothing from frame one. Paying the seeder rewrite only for the rare, brief
case is a cost curve nobody drew.

Thematically it is also the more Biogenic answer, by this repository's own rule
that realism is a tool: a cell has a chemical neighbourhood, not a map. Two cells
that meet share a contact, not an ocean.

### 4.4 Dedicated authoritative server

The main path if realtime shared water is wanted, and the only option that
reaches strangers.

**It works, in stock 4.7, with no GDExtension, no new permission and no
`binary_version` bump.** Two measurements carry it, and both reproduced
independently:

- **The drawing layers are provably not simulation.** Instantiating
  `normal_mode.tscn` headless and calling `set_process(false)` on Vision,
  Membrane, Soma, Returns, Recorder and Hud yields world state bit-identical to
  the full scene after 3,600 frames at seed 12345 — and, on re-measurement,
  after 12,000 frames containing meals, where the state-dependent `_seed()` draw
  counts are exercised. (Two of the six calls are no-ops: `membrane.gd` defines
  no `_process` and Hud is a scriptless `CanvasLayer`. The per-frame perception
  work is in `signal_bus.gd`, which was *not* stopped and costs ~1.4%. So "sim
  alone" is a mislabel — the figure includes the whole bus.)
- **Cost: ~580 µs/world stripped against ~4,900 µs for the full client scene**,
  8.6×, scaling linearly to 16 worlds in one process.

Two corrections that must travel with those numbers:

> **The capacity figure is wrong by about 3×.** Every measured world has one
> observer and `COUNT = 34`. The option's own premise is that the seeder becomes
> observer-independent for two players, which means the field grows — and
> COUNT 34 → 68 was measured at **580 → 1,785 µs**, 3.1× for 2× the bodies,
> because of the O(n²) loops at `food.gd:1443/1448` and `:1640/1644`. That is
> ~5 worlds per core at 60 Hz, **~20 players per €6 box, not 60–120** — before
> any networking, serialization or per-observer sense passes, and on a *shared*
> vCPU where 9.3 ms of a 16.6 ms budget is 56% of a core you do not own.

> **An exported Godot 4.7 release binary cannot be told which scene to run.**
> `--scene`, `--path`, `--main-pack` and `--script` all carry the `[extended]`
> availability icon; 4.7-stable's `SConstruct` declares
> `BoolVariable('disable_path_overrides', ..., True)` and
> `godot-build-scripts/build-linux/build.sh` never passes the flag, so official
> templates ship with overrides off and `main.cpp` aborts. `--headless` and
> `--fixed-fps` are `[release]` and work. So a naive server export boots
> `res://addons/launcher/launcher.tscn` and waits forever for a Play press.
> The fix is a feature-tag override — `run/main_scene.dedicated_server=...` in
> `project.godot` paired with a preset carrying `dedicated_server=true` —
> measured working with the editor binary, never against an actual exported
> template. **Commit to that fix rather than offering two**, and note that the
> key is inert on Android and Windows so no installed client needs to receive it.

Two prerequisites the effort tables missed, both mandatory:

1. **Per-world PRNG.** Sixteen worlds in one single-threaded Godot process is
   incompatible with 38 global-stream RNG sites and no `seed()` anywhere in
   `game/`. Every world perturbs every other world's draws; no world is
   individually reproducible or re-seedable. Routing all 38 sites through
   per-world instance RNGs — and replacing `Array.shuffle()` at `genome.gd:655`
   with a hand-rolled Fisher–Yates, since `shuffle()` follows the *global* seed —
   is a hard prerequisite, not a nicety.
2. **A genuinely fixed tick.** `Engine.max_fps` caps the frame *rate*, not the
   delta; the sim is `_process(delta)` and nothing clamps it. The reproducible
   numbers came from the `--fixed-fps 60` CLI flag, which forces `delta = 1/60`
   regardless of wall time — so a loaded server silently runs sim-time behind
   real-time instead of reporting a problem. A real fixed tick means moving the
   sim to `_physics_process`, which no cost table prices.

And `food.gd`'s observer coupling is an order of magnitude larger than "five
rules": `_cell` appears on **71 lines across 37 distinct functions** —
`_look_for_prey`, `_predict`, `_target_body`, `_step_sense`, `_step_beams`,
`_step_pings`, `_step_touch`, `_step_stalk`, `_step_separate`, `_step_contacts`,
`_bite_from_me`, `_bitten_by`, `_cast_ping`, `_meal_value`, `hunter`, `gape_at`,
`put_sister` and more. The five named are the seeder's; every sensing, targeting
and contact rule is singly-observer-bound too.

Cost and ops: Hetzner CX23 at **€5.49/month**, 2 vCPU / 4 GB, 20 TB EU traffic
(US locations include 1 TB at roughly 4× the price, which collides with any
"endpoints 25 ms away" latency argument unless the player base is European). The
server is genuinely **stateless** — `run_state.gd:36` persists only view mode,
membrane gain and an onboarding flag, so there is nothing to back up. Publishing
needs no `ci/` edit (`publish_release.sh` uploads `"$RELEASE_DIR"/*` wholesale
with automatic `SHA256SUMS`), but `ci/make_manifest.py:33` hard-codes
`VALID_KINDS = ("binary","content")` and `ci/` is template-owned, so the artifact
must ride as `binary:linux-server:...` — never plain `linux`, which
`build_info.gd:171` maps Linux clients to.

### 4.5 Player-operated desktop server — the Terraria model

Absent from the dossier, which collapsed hosting into *phone hosts (LAN)* or
*we rent a box*, and asserted the rented box is *"the ONLY option that reaches
the internet at all."* That is false twice over.

Publish the headless Linux (or Windows) server as a release artifact and let a
player run it. Nearly free to build: one export step in `release.yml`, the Linux
templates are already on the runner (`ci/install_godot.sh:32` unpacks the whole
`.tpz`), and the artifact-kind workaround is already established.

**It dissolves the study's largest stated ongoing cost.** If the server ships in
the same release as the client, client and server are the same `content_version`
by construction for anyone who downloads both. There is no second act to a
merge. It also deletes the monthly bill, the box to patch, the DDoS target with
the owner's name on it, the moderation position, the IP-logging question, and the
"what happens when it's down" question.

And the dossier's case against host-over-internet is built **entirely on
properties of phones and cellular**: CGNAT, no IGD on a bearer,
`onActivityStopped`, thermal throttling, battery, handoff, no privileged ports,
no ACME. A desktop on home Wi-Fi has none of them, and it is the one environment
UPnP IGD was designed for. Nobody asked whether a *desktop* host over the
internet is the same problem. It is not.

Honest costs: Windows Defender's first-listen prompt on an unknown network
(Public profile, inbound blocked, and a standard non-administrator user gets no
usable prompt at all — the same silent per-machine failure shape the study treats
as disqualifying on Android, and it lands on the configuration the study calls
its best case); it fragments into private friend-groups rather than a public
pool, which at N=2 is a **feature**; and it needs a plainly written README rather
than a UI.

### 4.6 Relay

A relay is the only remaining shape for "phone-hosted, playable anywhere",
because both peers dial **out** and nothing is hole-punched. And it is nearly
free: **`SceneMultiplayer.server_relay` defaults to `true`**, and a headless
Godot process with an *empty* scene subtree forwards opaque bytes between
clients — measured, with the relay's own `peer_packet` never firing. Source
confirms the relay preserves the sender's transfer mode and channel before
forwarding, so unreliable packets stay unreliable across both legs, and one
uplink packet fans out to N downlinks.

Four corrections to the enthusiastic reading:

1. **"Zero game code" is not true if you want a version gate.** The relay is the
   one architecture where Godot's free handshake is structurally unavailable:
   `scene_multiplayer.cpp:294-296` handles `SYS_COMMAND_ADD_PEER` by calling
   `_admit_peer()` directly, with the source comment *"Relayed peers are
   automatically accepted"* — `auth_callback` is never consulted. Worse,
   *setting* an auth callback on a relayed client is actively harmful: it starts
   authenticating the relay, the game-blind relay never answers, and **the two
   clients never discover each other at all** (measured: `A_peers=[]` after 240
   frames). Version skew is this project's stated first-class problem, and the
   relay is the one topology where the free tool for it is gone.
2. **The host cannot evict anyone.** Measured: `disconnect_peer()` from a host
   that is merely a relay client fails with `Condition "!_is_active() ||
   !peers.has(p_peer)" is true`, and the guest stays connected.
3. **`get_peers()` on a relayed client includes the relay.** The obvious loop
   `for p in multiplayer.get_peers(): send_state(p)` silently streams the whole
   world to the relay, doubling egress. Invisible on LAN, only appears through a
   relay.
4. **"Never use broadcast `rpc()`"** is a false rule built on a real symptom.
   Plain `rpc()` does log errors on a game-blind relay — but `rpc_id(-1, ...)`
   means "all peers except 1", excludes the relay exactly, and was measured
   delivering cleanly with zero relay-side errors. One character.

Costs: same box as the server, so marginal cost ≈ zero if a server already
exists. Cloudflare Durable Objects is now on the **free** plan (100,000
requests/day, 13,000 GB-s/day), which works out to **~139 session-hours/day free**
at a 20 Hz uplink — the binding limit is requests (20:1 billing on inbound
WebSocket messages), not the duration budget an earlier estimate used. The
disqualifier is not money: **the relay must be TypeScript**, a second codebase
in a second language that can never hold the authority.

The relay's decisive structural property, and it survived every attack: **on a
relay the peer ids never change when authority moves, so host migration is one
reliable message rather than a full reconnect.** Against that, the four-leg path
(guest → relay → host → relay → guest) costs roughly 2.7× a dedicated server's
RTT, and the phone host still wins every contested bite.

### 4.7 Asynchronous — and one correction that reverses its headline

The cheapest family by an order of magnitude, and it needs no netcode at all.
Two ideas are strong and two should be declined.

**The traded genome / the released sister — build this.** A genome is a
`{StringName: int}` map of at most 7 entries from a registry of 17 genes, tiers
1–3. Measured encodings: `var_to_bytes` 188 B, JSON 92 B, index-packed 6 B, and a
name-keyed text form of three-letter prefixes plus a tier digit is **28
characters** — `cyt3amp2che2fla3pel1pla2vac1`. All 18 prefixes including the
retired `rha` are unique. That is a code a player sends over WhatsApp, or a
static file fetched with the `HTTPRequest` the launcher already makes on every
launch.

It is version-proof **by construction**, and this project has already shipped the
proof: `food.gd:149-158` records that retiring `rhabdom` was *"the whole of the
retirement; every table that consumes a gene name still answers for one it has
never heard of, which is why an old `{gene: tier}` map that still names it loads
and draws rather than crashing"*, `cilia.gd:114-120` calls its unknown-gene
fallback hue *"load-bearing rather than defensive"*, and `cell.gd:662`'s
`_tier_index` clamps. Use the name-keyed form, **not** the 6-byte index-packed
one, because `signal_bus.gd:325` records that indices closed over the retired
gene's gap.

Four things must be built in, not retrofitted:

- **Validate.** Unknown names fall back and tiers clamp, but nothing caps the
  *number* of keys. A 200-gene dictionary would be accepted, `Genome.tier_of` is
  a `.get`, and upkeep sums over every key. Whitelist against `GENE_ORDER`, clamp
  tiers to 1..3, cap at `SLOT_MAX` 7. Fifteen lines, and skipping them is the
  most likely way this ships broken.
- **Clamp the arrival ceiling.** `ARRIVAL_GAPE_MAX := 40.0` (`food.gd:117`) is the
  guarantee that the water never seeds a one-contact death. A generation-12
  sister with `cytostome 3` on r40 breaks it.
- **Add an arrival; do not overwrite the sister.** `put_sister` hard-codes
  `var index := 1`, so the obvious twenty-line copy commits exactly the
  substitution `lifecycle.md` §4.2 exists to prevent.
- **The arrival is transient and nothing says so.** `_step_recycle` has no
  exemption for any slot, so a stranger's cell lasts only as long as it takes you
  to swim 1,700 units away, and its disappearance is indistinguishable from an
  ordinary recycle. Either exempt it or accept that the feature is a cameo.

**The daily water — build it second, and not as advertised.** The headline claim
that `seed()` alone fixes the composition was refuted by measurement: three
seeded runs matched at t=0, 0.5 and 1.0 s and **diverged at t=2.0 and every mark
after**, and a 60 Hz run diverged from a 120 Hz run at the same seed by the same
mark. The mechanism is visible: 37 RNG sites are on the global stream and several
fire per frame (`cell.gd:449` every frame, `food.gd:994` per body per frame), so
two devices at different frame rates have consumed different numbers of draws by
the time the first `_step_recycle` reseed fires. The refutation was already
inside this repository — `replay.md`'s determinism table has the row *"seed 12345
at 30 fps against the same seed at 60 | 840 lines differ — a different run."*

So a genuinely shared daily needs the per-world PRNG work **and** a pinned frame
rate. Both ship as pure content. It is ~150–200 lines and it fixes the fact that
no shipped run is reproducible at all, so it is worth doing regardless — but it
is not sixty lines and it must be scoped to a daily mode, because seeding the
global stream makes the whole run reproducible including the mutation rolled at
each division.

**Decline recorded ghosts.** Two independent kills. The world has no shared
frame — it is a 1,700-unit window that follows one cell — and more decisively,
`_step_sense`, `_step_beams`, `_step_touch` and the ping pass are each an O(34)
walk over `_cells`, so **nothing outside those bodies can ever reach
`signal_bus`**. A ghost drawn only by `vision.gd` would be visible in full
vision (the default mode) and unperceivable in point of view — inverting the
invariant that full vision exists to catch the membrane lying. The only workable
ghost is a real body wearing a real genome, which is the traded-genome idea in a
costume. (One nuance: since `cell.gd:421` starts every run at `Vector2.ZERO`, two
runs of the *same* daily seed do share an origin, so "race your own previous run
at today's seed" is a separate idea that was never separated from "another
player's bloodstain." It dies on the perception objection, not the coordinate
one.)

**Decline the leaderboard.** `_generation` is a client-reported integer with no
proof behind it; a board needs a *name*, which is this project's first
user-generated-content moderation surface and its first personal-data
obligation; and a board needs a *write* endpoint, which is the one thing GitHub
Releases cannot be. Making it honest means verifiable replay, which is
unavailable cross-platform.

**Decline replay sharing.** `recorder.gd`'s ring is 4,636,800 bytes, RAM-only by
explicit design, and Godot core has no Android share sheet. The cheap
alternative — input replay, which `replay.md:36-58` records as measured working
over 200 seconds byte-identical — is unavailable, and for a simpler reason than
libm: nothing in the shipped game fixes the timestep, so two copies of the *same*
binary on the *same* architecture diverge at different frame rates.

Two further options in this family, both free, both unconsidered:

- **Scenario sharing — an authored water.** 34 genomes at 5 packed bytes plus
  radii plus a seed plus a starting genome ≈ 200 bytes. A *level*, in a game with
  no levels and no editor, with no server, no identity, and **no moderation
  surface whatsoever** because a stranger can write nothing but combinations from
  a fixed 17-gene vocabulary. It also turns the seeder rewrite from a pure cost
  into a partial answer — an authored water does not need to be seeded relative
  to anybody — and it is the only proposal anywhere here that hands the owner a
  *content pipeline* rather than a system to operate.
- **Aggregate ambient presence.** How many cells are in this water today; how
  many died at generation 3. A static `stats.json` beside the manifest costs
  nothing and gives "you are not alone" with no identity, no free text and no
  write endpoint. `perception.md` §6.1 permits essentially one string in the
  playfield, so this lives on mode-select or the pause screen and never in the
  water.

### 4.8 Two devices, one player — the second screen

Missed because it is not multiplayer. The phone plays POV; a Windows machine on
the same Wi-Fi renders the same run in full vision, live.

Same LAN-ENet transport, same 272 B/frame quantized world stream, and the
non-authoritative client **already exists**: `replay.gd:149-186`'s `_write_state`
writes a flat frame of floats onto the live `Cell`, `Food`, `Motes` and `Genome`
nodes via `restore_body` / `restore_point`, and `replay.gd:477` calls
`_food.set_process(false)`. The four view files render it without knowing
anything changed.

**Zero design risk.** No PvP decision, no division-freeze decision, no seeder
rewrite, no eating each other, no identity, no matchmaking, no owner decisions of
any kind. It is a development instrument that `CLAUDE.md`'s "Run it. Do not
guess." section implicitly wants, and it is the only thing in this study that is
shippable without answering a single design question. If the owner wants to
de-risk the transport, handshake, version refusal and deploy path before
committing to any gameplay question, this is the vehicle.

### 4.9 A user-installed overlay network

Fifty thousand words on NAT traversal — CGNAT rates, 464XLAT, DCUtR percentages,
UPnP, symmetric mapping — and the single most widely-used real-world answer to
"my friend and I want to play a LAN game over the internet" is never mentioned.

Both players install Tailscale (free personal tier; Android, iOS, Windows), join
one tailnet, and each gets a stable `100.64.0.0/10` address. **Biogenic's LAN
ENet code then works unmodified over the internet**, because a tailnet address is
an ordinary unicast IPv4 address: `create_client("100.x.y.z", port)` is the same
call it already is. WireGuard does the traversal; DERP relays are the fallback
and are free at 44 kbit/s.

**Cost to the project: zero lines, zero servers, zero bump, zero ops.** It is a
paragraph in a README. Cost to the player: install an app and accept an invite —
real friction, not something to build UI around. Two caveats so it is not
oversold: Tailscale on Android is a `VpnService` and Android permits one active
VPN at a time, so a player already on a work VPN cannot; and it helps only people
who already trust each other enough to share a tailnet, which is exactly the
population §0.2 says is the only realistic one.

Every study framed the ladder as two rungs — LAN, or run a box. There is a third
rung between them that the project does not pay for.

### 4.10 Transports, and what to write the protocol against

All core, all measured, all needing no bump.

| Transport | Verdict |
| --- | --- |
| **ENet/UDP** | First choice. Three transfer modes, 253 usable channels (Godot silently reserves 2 of 255), MTU 1392, dual-stack. Peer ids are random 32-bit values — only the server is 1 — so **never assume `authority == 1`**. |
| **WebSocket / WSS on 443** | The escape hatch for networks that drop arbitrary outbound UDP. Core, `create_server` works on Android. **No transfer modes at all** — `websocket_multiplayer_peer.cpp` contains zero references to `transfer_mode` or channels, so `set_transfer_mode()` is silently ignored and everything is reliable-ordered. |
| **Plain TLS over TCP on 443** | Never evaluated despite being in the transport study's own title. Same firewall traversal, no HTTP Upgrade for a middlebox to strip, real backpressure via `get_available_bytes`, and — decisively — it **can** be tunnelled through an HTTP CONNECT proxy by hand, since `StreamPeerTLS.connect_to_stream()` accepts an arbitrary `StreamPeer`. `WebSocketPeer` cannot: it has no proxy support (zero `proxy` hits in `wsl_peer.cpp`) and `accept_stream()` is server-only. |
| **Plain HTTP at 5–10 Hz** | The one class already in production here. Absurd at 60 Hz; serious at 10, because the latency work *measured* the sensation stream's information rate at **~4 bytes per second** and the bus emitting **5–7 gated posts per second** across the player's entire sensory world. There is not enough information to fill a 10 Hz stream. `HTTPClient.set_https_proxy()` is CONNECT, so this is the only transport with a complete proxy story. |

Two write-them-down rules, both cheap on day one and expensive to retrofit:
**never assume authority is peer 1**, and **design the protocol for the WebSocket
shape** — one ordered stream, state frames idempotent and drained to newest,
events applied in order. ENet runs that fine; design for ENet's channels first
and the WSS port is a rewrite.

And one measured design rule that inverts the standard recipe: **do not
interpolate the sensation stream.** Sampled against 60 Hz truth, buffered lerp
doubled the mean error and raised the maximum on all five water-derived channels
at 10, 20 and 30 Hz. Sample-and-hold at 20 Hz beats lerp at 30 Hz on every
channel. The maxima are steps, not slews — a body reseeded, a hunter committing —
and those belong on a timestamped event channel, not in the sampled stream.

---

## 5. Stream sensations, not world state

The idea survives, it is the right authority model, and it is not a tier you can
ship on its own. All three of those need saying.

### 5.1 The seam is already a serialization boundary

`normal_mode.gd:602-634` is the only per-frame block that talks to the bus, and
no position crosses it. The exact set is **17 continuous floats plus 8 two-bit
tiers**: `taste(2)`, `dread(1)`, `organs(4 tiers)`, `light(2)`,
`sense_organs(4 tiers)`, `beam(2)`, `ping_out(2)`, `level(2)`, `touch(2)`,
`hold(1)`, `set_beat(2)`, `shear(1)`. Events on top: `ping` (4 scalars, ≤5 per
15.2 s), `hit`, `shove`, `ingest`, `thrust` — under 20 B/s in total.

The upstream half is just as clean: `normal_mode.gd:543-590` writes 13 anatomy
scalars plus up to 3 beam bearings into `food.gd`, **every one of which is a pure
function of the genome and the worn layout.** So the real client→server message
is the genome (21 B packed, on change) plus steer/push/dash.

**Putting a network in the middle changes nothing about the client's rendering
path.** That architectural fact is a stronger argument than either bandwidth or
anti-cheat, both of which are won by margins nobody will feel.

### 5.2 The quantization is already chosen, by the repository

`signal_bus.gd:381-382` sets `POST_EPSILON := 0.02` and `POST_ANGLE_EPSILON :=
0.05` as *"how much a continuous signal has to move before subscribers are told
again."* 0.05 rad over ±π needs 6.97 bits. **One byte per bearing is 0.0245 rad —
finer than the bus's own gate.** Quantizing to a byte discards nothing the bus
does not already discard, and the frame packs to **21 bytes**.

Independent ratification: slither.io's shipped wire format encodes angles as a
single byte, `value × 2π / 256` — the identical 0.0245 rad. Biogenic's own gate is
twice as coarse as a shipped .io game's wire format.

### 5.3 The numbers

| Stream | B/frame | 20 Hz payload | 20 Hz with headers |
| --- | --- | --- | --- |
| Sensation, quantized | 21 | 420 B/s | 1.1 kB/s ≈ **9 kbit/s** |
| Water-derived only (client owns its cell) | 14 | 280 B/s | ≈ 8 kbit/s |
| Composed membrane block (46 floats) | 184 | 3,680 B/s | 35 kbit/s |
| Full-vision world, quantized | 272 | 5,440 B/s | ≈ **49 kbit/s** |
| Recorder frame verbatim | 1,288 | 25,760 B/s | 206 kbit/s |
| `var_to_bytes(Array[Dictionary])` | 26,256 | 525 kB/s | 4.2 Mbit/s |

Three readings:

- **The ratio full-world / sensation is 56–58×**, and it does not matter.
- **Sending causes beats sending effects by 8.8×**: the composed 46-float block
  costs 184 B/frame, the sensations that produce it cost 21. Letting the client's
  own bus compose the lobes is cheaper *and* lets envelopes run at the client's
  frame rate.
- **The packet header dominates.** At 20 Hz, 36 bytes of IPv4+UDP+ENet per packet
  is 720 B/s against a 420 B/s payload — 63% overhead. Measured with a full
  genome, only **0.16 water-derived scalars change per 20 Hz tick**, so a
  delta-coded frame is ~4 bytes of actual information per second.

**Bandwidth is settled and should stop being a criterion.** Even the full world
at 30 Hz is 309 kbit/s. Choose fidelity on authority, latency and design.

One encoding note worth the line: `hold(remaining)` is the noisiest channel on
the wire and carries one bit. It is a monotone countdown that crosses
`POST_EPSILON` on essentially every tick, while the bus itself emits it twice in
ninety seconds. Send it as a deadline on change, never as a per-frame countdown.

### 5.4 Why it is the right authority model — and the two reasons it is not enough

**The prize is version-skew tolerance, not bytes.** In a conventional design the
client derives its own sensations from its own copy of ~35 `food.gd` constants
(`SCENT_RANGE`, `DREAD_*`, `PING_*`, `CHEW_*`, the tier tables). Two content
versions then produce two different games from one world, and the client can show
"I can eat that" where the server says no. In the sensation design the client
agrees on a channel list and a quantization; the ~100 envelope constants stay
local and an older pack renders the same bearings through slightly different
envelopes — **cosmetic drift, never divergence.** Under §0.1's permanent skew,
that is the axis that decides it.

**The second prize is latency tolerance, and the measurements are decisive.**
Steering is a first-order lag: `_omega = lerpf(_omega, steer*turn_rate(), 1 -
exp(-delta/turn_response()))`, with `TURN_RESPONSE_BY_TIER` 0.65–1.43 s. A
tier-1 cell holding the stick hard over reaches only 21.2°/s of its 35.5°/s
maximum after a full second, and a 90° turn takes **2.25–3.72 seconds**. The
heading does not move one `POST_ANGLE_EPSILON` (2.86°) until **470 ms** (tier 1)
or **278 ms** (tier 3) after the stick moves.

Against a shooter's ~0.1 ms budget, this game's is **470 ms** — a factor of
roughly 4,700, and it falls out of five constants that exist for reasons having
nothing to do with networking. The game also already lags itself harder than a
network would: `vision.gd:51` sets `CAM_LAG := 0.30` with a 0.16 s lead, a net
~140 ms of position lag in the shipped single-player game.

**Neither prize survives being the only stream, for two reasons:**

1. **Full vision is the default view.** `run_state.gd:40`:
   `const DEFAULT_MODE := Mode.FULL_VISION`, with the comment *"the owner
   playtests from a phone and the world view is what is being tuned."*
   `vision.gd` draws ground truth from `points()`, `radii()`, `genomes()`,
   `gape_at(i)`, `_motes_node.points()` and `hunter()`. **A sensation-only client
   renders empty water under a correct membrane.** That is fatal, not
   negotiable — unless the owner declares multiplayer to be POV-only, which is a
   decision about what the game is.
2. **The replay recorder reads the world directly.** `recorder.gd:229` reads
   `_food.bodies()`, `_motes.points()` and `_food.hunter()`. On a sensation-only
   client it would record a **frozen world under a live membrane** — strictly
   worse than no replay, since the truth pane exists precisely to catch the
   membrane lying, and `recorder.gd:118-123` records that `AT_HUNTER` was added
   for exactly this failure.

**The shippable shape, therefore:**

- **Always** send the water-derived sensation frame. It is the contract, it is
  the version-proof layer, it is what POV consumes, and it costs 8 kbit/s.
- **Additionally** send the 272 B/frame render-only world to clients that declare
  full vision in the join handshake — one flag, 49 kbit/s, and the replay
  recorder works unchanged.
- **The client owns its own cell outright.** Not prediction — ownership. Three
  channels are proprioceptive, and `cell.gd:686-689` states the rule itself:
  *"the wash has to answer the same frame the player pushes — that answer is the
  only proof they are connected to anything, and a second of lag destroys it."*
  Exact server-side reproduction is impossible anyway, because `cell.gd:449` draws
  `randf` into `_wander` every frame. This removes the need for a per-cell RNG, a
  fixed timestep, an input-command abstraction and a rollback buffer, all at once.
- **Contact resolves once, on the authority.** At `DASH_SPEED_BY_TIER[3]` 300 px/s,
  250 ms is 75 px against a player radius of 26–40. Eating, biting, toxicyst and
  trichocyst all live in `food.gd:1400-1470`.
- **Dead-reckon remote cells** using the sim's own closed form, `p(t) = p₀ +
  v₀(1−e^(−0.74t))/0.74` — exact, not approximate, four lines. It cuts the 100 ms
  p90 error from 9.00 units to **0.06**. The residual p99 spike is entirely the
  involuntary impulse; forwarding it as a 6-byte event, **0.38–0.54 times per
  second**, makes a remote's picture exact at arbitrary lag.

### 5.5 One claim to strike, and the honest anti-cheat statement

Three places in this repository — `food.gd:834-836`, `normal_mode.gd:712-716` and
`ping-as-outline.md` §0 — state that the four ping scalars cannot be inverted:
*"you cannot recover a position from the four of them."* **That is false as
implemented.** `hold = PING_RING × 2 × radius / PING_SPEED` is a pure linear
function of the body's radius with no occlusion term, so `R = 62.5 × hold`
exactly; substituting into the reported half-width gives distance exactly. The
round-trip was verified numerically against the shipped constants: `(13.0, 250.0)
→ (27.884°, 0.2080 s) → (13.0, 250.0)`. Quantizing the width to one byte still
localises to ±1.1 px at 200 px and ±17.7 px at 800.

The design survives, because the *guarantee* is different from the one claimed:
a client learns only what its own organs reported, and the fix decays at the
organ's own cadence — a tier-3 ampulla pings once per 15.2 s, and a tier-1 body
covers 859 px in that time, 45% of the organ's range. Genomes, gape, edibility,
`hunter()`, mote positions and the sister are never sent at all. **Correct the
three claims to the defensible statement.**

And say the whole anti-cheat position plainly: it does not matter here. There is
no economy, no currency, no ranking, no leaderboard, no accounts, no persistence.
The single most valuable thing a wallhack could give a cheater is, in this game,
**a button on the screen the Play button lands on** — `mode_select.gd:38-40` puts
Full vision beside Point of view and full vision is the default. The client is
also not merely recoverable but *published*: `raw.githubusercontent.com` returns
the commented source at HTTP 200 with no authentication. Any effort spent on
obfuscation, `encrypt_pck` or script checksums is wasted.

---

## 6. The costs every shared-water option pays

These are not netcode. They are the reason shared water is expensive whichever
transport wins.

### 6.1 The water is a function of one player

Five rules in `food.gd` each name exactly one cell — `_seed()`'s origin at
`:2276` and its RING_MIN 920 / RING_MAX 1350 ring at `:2327`, `_step_recycle`'s
`CULL` 1700 at `:1687`, `_seed_peer`'s radius off `_cell.radius` at `:2384-2388`,
and `_drifter_share()` / `_tier_weight()` lerping the harmless-drifter share and
the mouth distribution off **the player's own summed sense tiers** at
`:2447-2466`. `motes.gd:33-35` repeats it.

**That relativity is the difficulty curve.** Replacing it with a fixed arena does
not merely cost lines; it removes the mechanism by which the water tracks each
player's size and senses, and it breaks `_other_drifter()`'s floor, which
guarantees *the player* — singular — a meal she can certainly take. A
generation-5 cell and a generation-1 cell in one arena get the same water,
correctly tuned for neither. And the second player would starve on a technicality
unless the drifter floor is re-derived per player.

It is also larger than five rules (§4.4): 71 lines across 37 functions read
`_cell`. Plus `TARGET_PLAYER := -2` (`food.gd:692`) is a single sentinel read at
ten sites, `hunter()` answers for one player, and `_bite_clock`/`_dart_clock` live
on the *field* rather than the cell (`food.gd:892-895` — *"the encounter lives in
this file"*).

**This is the dominant cost of any shared world, it is a gameplay change rather
than an engineering one, and it ships to players with no staging and no gate.**

### 6.2 The division screen stops the world, deliberately and indefinitely

`normal_mode.gd:834` calls `_set_simulating(false)` at the QUICKEN→PINCH
transition, which at `:1357-1360` calls `set_process(false)` on `_cell`,
`_metabolism`, `_motes`, `_food` and `_genome`. The code's own comment: *"The
same call a death makes. The water stops, the body does not."*

The bounded window is **2.5 s, not 4.9** — `DIVIDE_QUICKEN 2.4` is still
simulated; the freeze is `DIVIDE_PINCH 1.5 + DIVIDE_PART 1.0`, then
`DIVIDE_COMMIT 0.9` after the choice. But between them sits `_step_choosing`,
and `normal_mode.gd:881` states the design outright: *"there is no timeout and no
default, so a player who puts the phone down comes back to the same two bodies."*

In shared water the dividing player is either **frozen and edible for an
unbounded time** or **invulnerable for an unbounded time.** There is no third
answer, this affects every transport equally, and it is an owner decision about
what the game is. It also compounds with §3: on Android, putting the phone down
is a guaranteed disconnect within 30 seconds, so the design note that makes the
single-player behaviour correct is exactly what multiplayer cannot honour.

Two further nuances. `_toggle_pause()` refuses to open during a division
(`normal_mode.gd:2177`), so pause and division cannot stack — but it also means
there is no existing mechanism to tell another player "the host is dividing", and
within the 5–10 s ENet window a dividing host and a vanished host look identical.
And `signal_bus.gd:669` notes the bus keeps stepping while the tree is paused, so
a frozen world under a live membrane is exactly the failure the replay design
already names as worse than no output at all.

### 6.3 There is no input abstraction anywhere

`cell.gd:437` calls `_read_steer()` *inside* the sim step, polling
`Input.is_action_pressed` at `:861-875`; `_pushing()` at `:462` consults the
586-line `controls.gd`; and `_dash()` fires from `_let_go()` off
`Time.get_ticks_msec()`, outside `_process` entirely.

Every option that ever sends input needs this seam, it lives in the most
feel-sensitive code in the project, and **it is more expensive to reverse than
the fixed timestep** — which is why it belongs above the timestep in any list of
decisions taken first. Note also that `{steer, push, dash}` does not close it:
a remote intent must carry the on-screen-control state too, or a remote cell
silently never pushes.

### 6.4 Two live single-player bugs that block the fixed tick

`food.gd:994` scales a single random draw by `delta`; `cell.gd:449` draws a
fixed-amplitude innovation once per frame. A random walk's variance must scale
with `sqrt(delta)`. **The game plays measurably differently at 120 Hz than at
60 Hz today**, and nothing anywhere clamps `delta`, so an Android resume hands
the sim an unbounded step in one frame. Everything else in the codebase is
timestep-correct, which makes these the outliers rather than the pattern.

Fix them as single-player bugs, independent of any multiplayer decision, and
screenshot the result — pinning the tick is a gameplay change that has to be
looked at, not a netcode change that can be merged quietly.

### 6.5 The release pipeline

`release.yml` triggers on `push: branches: [main]` with no `environment:` key
anywhere in the file, so there is no deployment-protection gate — confirmed.
`publish_release.sh` is second-to-last.

But `workflow_dispatch:` is **already in the trigger list**, which nobody
noticed. The gate four studies call immovable is one
`if: github.event_name == 'workflow_dispatch'` away, on a file that *is* ours,
and a server-first two-act release is already expressible without touching the
read-only `ci/`.

Combined with §0.1, the ordering hazard is both less urgent and more cheaply
fixable than the dossier claims — and it points the opposite way. The obligation
is not "the server must accept N and N−1 for one release"; it is **the server
must accept N−k for unbounded k, or it must refuse clearly and tell the player
how to update.** A `net.json` published beside the manifest by our own
`release.yml` (`{enabled, min_protocol, relay}`) costs nothing, needs no `ci/`
edit, and is the only kill switch this pipeline can have.

---

## 7. The recommendation: a combination

The owner said nothing forces one choice, and that is correct — but not in the
way the dossier assumed. The cheap combination is not "three transports behind
one protocol." It is **three different features serving three different cases,
two of which need no protocol at all.**

| Case | Answer | Cost |
| --- | --- | --- |
| **Is this feature even possible?** | Two cells in one water, photographed at both shapes, using `put_sister` + `drive.gd` + `shot.gd` | an afternoon, no code shipped |
| **Two people, one room, one device** | Shared screen or split screen (§4.1) | content only, no bump, no netcode, no owner decisions beyond the division |
| **The trace of other people, always on** | Released sister as a genome, fetched over the `HTTPRequest` the launcher already makes (§4.7) | ~300 lines, content only, fails safely to today's behaviour |
| **Two people, two places, cheaply** | Coupled waters, rung A — influence events only (§4.3) | tens of lines over the transport, no authority, no seeder rewrite, no division problem |
| **Two people in the same room, two devices** | LAN ENet, Windows-host preferred, tap-only code or unicast sweep (§4.2) | content only; shares one protocol with the rung below |
| **Two friends, two houses, no infrastructure** | The same LAN build over a Tailscale tailnet (§4.9) | a README paragraph |
| **Two friends, two houses, no third-party app** | Player-operated desktop server shipped in the release (§4.5) | one export step; deletes the bill, the ops and the second act per merge |
| **Strangers, matchmaking, persistence** | A dedicated authoritative server, and only then (§4.4) | €5.49/mo, ~20 players per box, the seeder rewrite, the per-world PRNG, a fixed tick, and a pipeline that is no longer one atomic act |
| **Developer instrument, no design risk** | Second screen (§4.8) | reuses `replay.gd:_write_state` almost verbatim |

The through-line: **LAN ENet, a Tailscale tailnet, a player-run desktop server
and a rented box are all the same client code.** Only the address differs, and
the first three cost nothing to support once the fourth exists — or, more
usefully, the first three mean the fourth may never be needed.

**What to decline, explicitly and in writing, so it is not reopened:**
WebRTC and hole punching; deterministic lockstep; peer-to-peer rollback;
phone-hosting over the internet; every third-party backend (Nakama's distinctive
advantage collapses once you notice that core `WebSocketMultiplayerPeer` already
gives you a relay for free at zero `class_name` cost — and a vendored GDScript
SDK with `class_name` **cannot parse from a content pack**, measured, including
with the class cache shipped inside the pack); asymmetric roles where one player
plays the water; recorded ghosts; and leaderboards.

---

## 8. The incremental path

**Step 0 — photograph two cells in one body of water.** No code ships. `put_sister`
places an exact-match body, `drive.gd` drives it, `shot.gd` photographs POV and
full vision at 1280×720 and 2400×1080, and a human answers: where is she, and is
she coming? **If the membrane cannot show a second person, everything below is
moot, and this costs an afternoon.**

### Step 0 is answered: yes, with one caveat that is a design decision

Measured on `76ea528`, which added `--sister=` to `tools/drive.gd` so the
question could be posed at all. `put_sister()` existed but only as a consequence
of a real division. Seed 7, r30 player carrying `ampulla:2`, sister at −40° and
520 units, photographed in point of view and full vision at 1280×720 and
2400×1080.

**She is found, and only by the ping.** The same seed run with and without her
differs by exactly one event: a mark at **3.93 s, bearing −53.1°**, absent
otherwise. Smell never reports her — `taste 0.000` for the whole run — because
she is the player's own size, so `gape_at()` never makes her edible and she
never enters the scent loop at all. **A peer your own size is odourless.** That
falls out of the edibility model rather than being a choice, and it means smell
is structurally blind to other players of comparable size.

**She is indistinguishable from a rock.** Her mark is strength 0.65, halfwidth
24.6°, hold 0.48 s. Drifters in the same runs: 0.71 / 22.4° / 0.50 s and
0.82 / 27.3° / 0.50 s. Nothing in the four scalars a return carries separates an
agent from a lump of debris.

**Size does read.** A r48 sister against a r30 player draws **31.6° and holds
0.77 s** — visibly a broader wash along the contour at both shapes. The §4 tier
ladder is carrying real information about how big the other person is.

**A big neighbour pins dread, undirected.** `threat 1.000`, dread 0.89 → 0.95,
**100 % duty from the first sample** — but `hunter none` and `range --`
throughout. It says *you are not safe*; it cannot say where from, or whether
they are closing. So the "is she coming?" half of step 0 is currently **no**.

**The verdict.** The membrane can carry a second person, so the gate is passed
and §4.2 is worth building. But today the game would tell a player *something
large is roughly that way, once every twelve seconds*, and nothing else.
Indistinguishable-from-a-rock may well be the right answer for a blind cell —
but it should now be a decision rather than an accident, and the ping mark is
the only channel where that information could go.

**Step 1 — `net.json`, before any netcode.** A file in `build/release/` published
by our own `release.yml`, read with a plain `HTTPRequest` (copying
`update_service.gd`'s `?ts=` cache defence), carrying `{enabled, min_protocol,
relay}`. Zero infrastructure, pure content, and the only gate a no-gate pipeline
can have. Build it first because it is the safety net for everything after.

**Step 2 — the two single-player fixes.** `food.gd:994` and `cell.gd:449`'s
`sqrt(delta)` bugs, plus a `delta` clamp. Justify them as bugs, screenshot the
result, merge them alone.

**Step 3 — the released sister.** Asynchronous, ~300 lines, no bump, forward-
compatible by construction, fails to today's behaviour. Validate the imported
genome (§4.7), clamp the arrival gape, add an arrival rather than overwriting
slot 1, and decide whether it is exempt from `_step_recycle`. This is the first
genuinely multiplayer thing, it improves the *single-player* game, and if it
lands well it may be the multiplayer this game wants.

**Step 4 — same-device local.** Shared screen first (cheapest), split screen
second. It shares the seeder question with every other option and is the only
place to learn the answer without shipping a protocol. It also forces the
division decision, which is useful: better to meet it here than on a network.

**Step 5 — the second screen, or LAN.** Second screen if the goal is to de-risk
the transport with zero design exposure; LAN if the goal is two players in a
room. They are the same transport. Windows-host removes the worst failure mode
for free. Reproduce `godot#105726` on real hardware before committing.

**Step 6 — coupled waters, rung A.** Over whichever transport step 5 established.
This is the cheapest realtime "two people, two places" and it needs neither the
seeder rewrite nor the division answer.

**Step 7 — decide whether anything further is wanted**, with a real answer to
step 0 and a real player on the other end. Only then: the seeder rewrite, the
per-world PRNG, the fixed tick, the input seam, and a box.

Three rules for the sequence. Every step through 6 ships as **pure content at
`binary_version` 3**, provided nothing adds an autoload, a `class_name` or an
InputMap action — the repository already documents the first two rules against
itself at `signal_bus.gd:17-19` and `run_state.gd:5-8`. Refuse connections on a
`PROTOCOL` constant in a `game/` script, **never** on `content_version`, which is
`git rev-list --count HEAD` and moves on docs-only merges. And check in golden
wire captures (`tests/wire/protocol-N.bin`, one per shipped protocol) with CI
asserting the current decoder still reads every one — under §0.1 that is the only
mechanical proof of compatibility with an installed base that may never update.

For CI: the measured recipe is **two `SceneMultiplayer` instances in one headless
process**, bound to two subtrees via `SceneTree.set_multiplayer(api, path)` over
ENet on loopback — full handshake plus bidirectional RPC. It must **assert a
positive output line and be grepped**, because `ci.yml:92-97` and `:218-221`
already document that Godot exits 0 through script errors. Its highest-value
assertion is the version-skew refusal itself. It cannot see latency, loss, NAT,
Android doze, or `#105726`.

---

## 9. What was not verified, and could not be

Stated once and plainly, because summed across the dossier it is this study's
largest property.

**Zero measurements were taken on either shipping target.** Across nine option
studies, nine refutations and eight cross-cutting investigations, no exported
binary was run, no APK was installed, and no frame was rendered. Every capacity
number, every latency number, every "8.6× cheaper with the eyes off" and every
claim about Android backgrounding is inference from a headless Xeon in a
container with no IPv6 and an intercepting proxy.

Specifically unverified:

- **Whether two cells in one body of water read through the membrane.** The
  highest-value unknown, named by seven studies, still unanswered.
- **Whether an exported `dedicated_server` build of this project boots at all.**
  The feature-tag override was tested only with the editor binary — the one
  configuration in which the workaround is *not* load-bearing — and the technique
  is undocumented on the dedicated-server export page.
- **Whether `--fixed-fps` is genuinely `[release]` on an export template.** Every
  timing in this document used it.
- **Godot's UDP receive path and cross-process ENet in this container.** One pass
  reported both broken; a second reproduced both working and traced the first
  result to leaving `max_channels` at 0. Treat container network results as
  unreliable in both directions.
- **IPv6 ENet binding.** Source- and template-verified, never runtime-verified,
  because this container has no IPv6 stack at all.
- **Android broadcast reception without `CHANGE_WIFI_MULTICAST_STATE`**, and the
  unicast /24 sweep's ARP behaviour on a real phone.
- **`godot#105726`** — ENet LAN disconnects — on real hardware. It explicitly does
  not reproduce on localhost.
- **Whether Godot's Android virtual keyboard is usable over a landscape-locked
  1600×720 canvas.** Nothing in this project has ever drawn a text field.
- **Any real network behaviour**: latency, jitter, loss, reordering, MTU, carrier
  UDP policy, Wi-Fi→LTE handoff, thermals, battery.
- **Whether a headless server's performance matches the editor binary.** All
  timings are from the editor build.

Two things *were* closed and can be struck from the open list: a headless server's
launcher autoloads are inert (`UpdateService._ready()` does nothing and the only
caller of `check_for_updates()` is `launcher.gd:92`), and multiplayer appears
nowhere in the design corpus (a full-text search of all fifteen documents returns
nothing).

---

## 10. Left open — owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | Who is the second player? | **a specific person you already know, and you will text them to start ✓ recommended** / a stranger who finds the game / you, on two devices | The game currently has no store page, no description and no stars, so nobody can find it. If the second player is someone you can text, then matchmaking, moderation, abuse, bans and privacy are all work for a person who has no way to arrive — and every one of them can be skipped. |
| 2 | Before anything is built, is the game readable with two cells in it? | **photograph it first, this week ✓ recommended** / decide the shape first and photograph later | Nothing anywhere in this study answers whether the membrane can show you that a second person is there. The code to place a second cell already exists and the camera to photograph it already exists. If the answer is no, none of the rest of this matters. |
| 3 | What does "multiplayer" mean for the first version? | **another player's declined daughter arriving in your water, with no live connection ✓ recommended** / two people in one body of water at the same time | The first ships in about a week, cannot break the solo game, and makes the choosing screen a harder decision — which one do I keep, and which one do I release. The second is weeks to months and forces every hard question below. Your cell is blind either way and cannot tell the difference; you will know. |
| 4 | Do the two players share one body of water, or one water each? | **one water each, with the other person heard rather than met ✓ recommended** / one water both swim in | Sharing means rewriting how the water is built. Today every rule about where food appears is written around one cell, and that relationship *is* the difficulty curve. Hearing each other means your friend's ping reaches you, their discarded daughter swims into your water, and their growth makes yours harder — but you never bump into them. |
| 5 | In shared water, what happens while you are dividing? | **you leave the water for the few seconds it takes ✓ recommended** / you are frozen where you are and can be eaten / you are frozen and untouchable | Dividing stops the world for two and a half seconds and then waits for you to choose, with no clock, on purpose. Leaving the water keeps all of that exactly as it is and nobody can eat a body that is not there. Frozen-and-edible means dividing next to someone is suicide, so nobody will. Frozen-and-untouchable makes the division screen a place to hide. |
| 6 | Can two players eat each other? | **yes, but only by chewing — never in one swallow ✓ recommended** / yes, by the ordinary rule / no, you pass through each other | The ordinary rule means the bigger cell wins in one touch, with no warning and no fight, and the smaller player loses minutes to something they never perceived. Chewing turns it into a thirteen-to-thirty-second struggle decided by who gets behind whom, which arrives on channels the defender actually has. Passing through makes the other person scenery. |
| 7 | Can other cells hear your ping? | **yes ✓ recommended** / no | A ping is a shout. It is how you find things, and making it audible means it is also how things find you. It gives two blind players the only way to say *here* that the fiction allows, and it gives solo play a decision it does not currently have: look, and be seen. |
| 8 | Who runs the server, if there is one? | **a player does, from a release you publish ✓ recommended** / you rent a box / nobody, it is same-room only | A server you publish costs nothing to run, cannot be down, and is always the same version as the client that downloaded it. A rented box costs about five euros a month forever, has to be patched, and turns every release from one act into two — the second of which can fail. |

### The nuance under the table

**Row 1 is load-bearing for rows 5 through 8.** The moment a public lobby or a
match browser exists, "strangers meet strangers" is back, and with it every
question this study defers: stalking, harassment, IP exposure, moderation, and
the need for a ban system a game with no identity cannot implement. An
invite-only session is not a limitation; it is the decision that makes the rest
of the answers cheap.

**Row 4 is the one that decides the budget.** One water each is tens of lines
over whatever transport exists. One shared water is the `food.gd` rewrite — 71
`_cell` references across 37 functions, plus a field that must grow, plus a
measured 3.1× per-world cost increase when it does, plus the per-world PRNG work,
plus a fixed tick, plus contact adjudication, plus rows 5 and 6 answered before a
line is written. Both are legitimate; they are not the same order of magnitude,
and the cheap one is not obviously the worse game.

**Row 5 has a wrinkle the options do not show.** On Android, a backgrounded app
stops executing entirely, so "a player who puts the phone down" — which
`normal_mode.gd:881` deliberately designs for — is a guaranteed disconnect within
thirty seconds once the water is shared. The single-player note is correct and
multiplayer cannot honour it. Removing the dividing player from the water is the
only option that leaves that note untouched.

**Row 6's recommendation is one conditional in `_step_contacts`.** The gape rule
is already symmetric and `put_sister` already establishes that a player-genome
body in the field works, so "yes" needs no new code at all. What needs the code
is "yes, but not the swallow" — and the reason is `edibility.md` §2, which says
in as many words that reading a body's facing is a full-vision fact. In the mode
shared water must be played in, the defender has none of the tools the attack
model assumes, so the swallow reinstates exactly the size veto that spec was
written to overturn.

**Row 8's recommendation carries one flaw worth knowing.** A Windows player
hosting on an unknown network meets the Windows Defender first-listen prompt, and
a standard non-administrator user gets no usable prompt at all — the app is
silently blocked. That is the same undiagnosable per-machine failure shape this
study treats as disqualifying elsewhere, and it lands on the configuration the
row recommends. It is worth the trade against a permanent bill and a second act
per merge, but it is not free and it should not be sold as free.

---

## 11. What would change this document

Three findings, in order of how much they would move it:

1. **A photograph in which a second cell is unreadable.** Everything in §4.1
   through §4.6 is then moot and the async family is the whole answer.
2. **A second player who actually exists.** §0.2 rewrites the ranking. Most of
   the deferred work in §7 stops being deferrable.
3. **Phase 6 completed.** The chase re-measured against a real genome is the
   evidence player-versus-player is currently missing, and `roadmap.md`'s own
   standing rule — *"Nothing is built before the thing it is evidence about"* —
   says so.
