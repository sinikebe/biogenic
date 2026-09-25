# Invites: a friend's server, from far away

The player's side of `net-hardening.md` C2 (#59): how a friend outside the house
gets into the owner's dedicated server with one pasted invite. The network is
C2's and is built separately; this file is what the player sees, presses and
reads. Owner decisions already made: one invite per friend; the home Wi-Fi needs
none and its join stays exactly as it is; only the dedicated server listens on
the internet, never a phone; the owner can revoke one friend's invite.

**Status: built, and judged** at 8660066 (§10.1). 71 frames were shot with real
input at 1280x720 and 2400x1080: every far page, every trouble key, the chooser
and the five LAN pages. Two changes came
out of the judging and are written in below: the pulse's fade (§4), and a
failed save that must not pass for a kept invite (§2, §6.2). Before the build,
the pages were mocked on the real nodes. Not seen: a device, the Android
clipboard toast, the pulse in motion.

## 0. The flow

1. The owner mints an invite on the server and messages its one line to the
   friend (§9).
2. The friend copies the whole message in their chat app.
3. Biogenic → play → **by invite** (the name is §11 row 1) → **paste invite**.
   The page now shows the server's address and **call**.
4. **call** → a violet pulse leaves the ring → **answered** → full vision or
   point of view → the run, exactly as on the LAN.

Every time after that: play → by invite → call → a view. The home Wi-Fi's
within earshot → answer → four taps is untouched.

## 1. Where it lives: beside within earshot, on the view chooser

**A fourth option on `mode_select`, paired with within earshot**, opening the
earshot scene at its own page. It is not a page inside the earshot screen, for
four reasons, all about what a player does:

- A friend holding an invite reads "within earshot, a friend on the same wi-fi"
  and correctly decides it is not for them. Their door has to say *far away*
  where they look first.
- Back leaves the earshot screen from every page today; only ANSWERING's undo
  differs. A far page one level under CHOOSE would need a Back that climbs, a
  second meaning for one key on one screen.
- The household never sees a far page, and its screen stays byte for byte what
  it is.
- A returning friend needs a LAN guest's four presses, without the four taps.

It still reuses the earshot scene rather than a new one: the same nodes, the
same TOGETHER and TROUBLE pages, and the same rule that the screen reads the
session and never writes the session's sentences.

**The entry is `game/net/far.tscn`**, an inherited scene that sets one
property:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://game/net/earshot.tscn" id="1_earshot"]

[node name="Earshot" instance=ExtResource("1_earshot")]
far = true
```

`earshot.gd` gains `@export var far := false` and reads it for the whole visit.
There is no static to forget to clear. This was tested on 4.7 in the mock: the
root reads `far = true` from `far.tscn` and `false` from `earshot.tscn`.
`mode_select.gd` reaches it by string, as it reaches `earshot.tscn`, so it joins
ci.yml's scene boot loop too. That loop's own comment says why.

### 1.1 The chooser

The third row becomes a pair in the row within earshot sits in today, so
nothing moves vertically.

```
Center (CenterContainer)
  Column (VBoxContainer, separation 44)
    Heading      unchanged
    FullBlock    + size_flags_horizontal = 4
    PovBlock     + size_flags_horizontal = 4
    Company      HBoxContainer: size_flags_horizontal 4, separation 64,
                 alignment 1, mouse_filter 2
      NetBlock   moved here, unchanged but for its note
        Net      Button, COMPANION_SIZE 320x52 (the theme's padding makes
                 it 56 tall, as today), size_flags_horizontal 4
        NetNote  Label 15 px, Color(0.482, 0.686, 0.643, 1), centred,
                 custom_minimum_size (320, 0)
      FarBlock   VBoxContainer, separation 10
        Far      Button, 320x52, size_flags_horizontal 4
        FarNote  Label, exactly as NetNote
```

The shrink flag on FullBlock and PovBlock is load-bearing, the same trap
`mode_select.gd` already documents. Without it the column stretches full vision
and point of view to the pair's 704 px.

| canvas px | 1280x720 | 2400x1080 (canvas 1600x720) |
|---|---|---|
| full vision, point of view | x 410-870; y 210-274, 350-414 (as today) | x 570-1030 |
| within earshot | x 288-608, y 490-546 | x 448-768 |
| far button | x 672-992, y 490-546 | x 832-1152 |
| both notes | y 556-578, boxes 64 px apart | same |

Within earshot's note becomes `a friend on the same wi-fi`. The whole of today's
note is 371 px wide, so side by side it overhangs its 320 px button toward the
far note. That is the only change on the LAN side, and it changes no flow. A
stacked fourth row keeps the note, and it was mocked too. It fills the screen
and reads as four equal choices, when the question is still *which view*.

**Focus** stays on the remembered view. Set `Pov.focus_neighbor_bottom` to Net,
and `focus_neighbor_top` on Net and Far to Pov. The pair is symmetric under
point of view, so the automatic pick is a tie. Measured, it lands on Net, and
only the tie-break decides that. Left and right move between the two.

## 2. One kept invite

- **One slot.** A friend of a friend with a second server is rare, and two
  slots mean a list and a choice before every call. With one slot the other
  server is a paste away, because its message is still in the chat.
- **A paste replaces the kept invite only on success.** Anything that fails to
  read or to save leaves the kept one as it was, and the page says so
  (`still kept`). A save has succeeded only once its bytes read back from the
  disk, before the rename over the old file. Without that check, a full disk
  returned OK and left a 0-byte invite in place of a good one: measured on a
  full 16 KB tmpfs. Godot's `close()` does not report the write it loses.
- **Say the result every time.** A re-minted invite at the same address looks
  identical on screen, so success says `new invite kept`, and pasting the same
  one says `that invite is already kept`.
- **Forget asks first.** The only way back is the friend's message.
- **A dead invite is kept.** A revoked or re-keyed invite is not deleted on its
  own: `paste new` replaces it, and if the owner undoes a revocation the friend
  loses nothing.
- **The clipboard is read in the press handler and nowhere else.** Never on page
  open, on focus or on resume. Android 12+ shows its own toast on each read, so
  the toast must only ever follow the player's own press. Nothing clears the
  clipboard afterwards: the invite is still in the chat anyway, and emptying a
  player's clipboard is a surprise.

## 3. Pages

All of them use `earshot.tscn`'s existing nodes plus one new button (§5).
`name` is §11 row 1, `address` is §5.2's receipt, and the Ring column is §4.

| page | Heading | Ring | Line | Receipt | First · Second · Third | focus | Back, Esc |
|---|---|---|---|---|---|---|---|
| FAR, nothing kept | name | cell | `copy the invite your friend sent you, then paste it here` | `you paste it once · this device keeps it` | paste invite | First | leave |
| FAR, kept | name | cell | `your friend's water, from their invite` | address | call · paste new · forget | First | leave |
| FAR_CALLING | name | cell + pulse | `calling your friend's water` | address | stop | First | leave; the call closes |
| FORGET | `forget this invite?` | cell | `you would need your friend's message to paste it back.` | address | keep · forget | First (keep) | keep: back to FAR |
| TOGETHER, far | `answered` | violet nucleus | `you can hear your friend's water`; today's `quiet for %d seconds` when quiet | address | full vision · point of view | the last view, as today | leave |
| TROUBLE, far | session's `trouble` | dim cell | session's `because` | address | again or paste new (§6.3) · leave | First | leave |

On FAR, the Heading and Line also say what the last press did, until a press
changes the page:

| after | Heading | Line | Receipt | focus |
|---|---|---|---|---|
| a first paste | name | `invite kept` | address | First, now call |
| paste new | name | `new invite kept`, or `that invite is already kept` | address | Second |
| a failed paste (§6.2) | its headline | its sentence | `still kept: ` + address, or empty | the paste button |
| forget | name | `invite forgotten` | as nothing kept | First |
| back from `invite_refused` (§6.3) | name | `your friend's server turned this invite away. paste a new one.` | address | Second (paste new) |

**A refused invite stays refused** until a paste replaces it or the game
restarts. On that invite, call goes straight to the `invite_refused` page
without dialling. The server bars an address for 60 s after a refused proof,
and for 600 s after a second one within ten minutes (`BAR_FIRST`, `BAR_AGAIN`).
So a retry can only earn the longer bar, and then a door that cuts each call
the moment it connects, which reads as `they hung up`. A kept invite that no
longer reads shows as nothing kept.

Transitions:

- chooser → FAR. On FAR, paste (the button or `ui_paste`) stays on FAR and
  shows one of the rows above.
- FAR call → FAR_CALLING, then TOGETHER on a welcome or TROUBLE on any failure.
  stop → FAR, and the session closes.
- FAR forget → FORGET. keep or Back → FAR. forget → FAR, nothing kept.
- TROUBLE again → FAR_CALLING. paste new → the paste, landing on FAR. leave or
  Back → chooser.
- TOGETHER → a view → the run, as today. Leaving the run lands on the chooser,
  which closes the session, as today.

The link decides the page exactly as `_follow_link` does now, except that
REACHING on a far call is FAR_CALLING, not ANSWERING. The session says whether
its call is by invite, and a far visit never reaches CHOOSE, CALLING or
ANSWERING.

## 4. The ring on far pages: a cell, and a call leaving it

Nothing on a far page is tapped on the ring, so the dial is not drawn: no
twelve segments, no marks, no cursor. What is left is the membrane and a
nucleus, so the ring reads as the player's own cell, and the call is a ping
leaving it. The ping is `ampulla` violet, like the code on the LAN pages,
because it is the same act. An empty hairline alone was mocked first and read
as an empty frame. The nucleus made it a cell.

**Violet survives only at high alpha over this wash.** Blended thin over its
teal, `ampulla` violet turns slate blue. The measured hue is 219° at alpha 0.19
against the violet's own 263°. It keeps a hue of 245° or more over the wash's
brightest patches only from about alpha 0.5 up. So the pulse holds its alpha
and loses it late, rather than fading from the start. The first curve,
0.75 × (1 − u)^1.5, was built, and read slate at u ≈ 0.6.

All of it is drawn in the Ring's own space, centre (280, 220), antialiased:

- **membrane**: `draw_arc` at r 160, 96 segments, 2 px,
  `Color(0.404, 0.639, 0.588, 0.16)`, or 0.08 on TROUBLE.
- **nucleus**: `draw_circle` at r 7, `Color(0.404, 0.639, 0.588, 0.24)`, or
  0.12 on TROUBLE. On FAR_CALLING and TOGETHER it is
  `Color(0.655, 0.44, 1.0, 0.85)`.
- **pulse**, on FAR_CALLING only: one at a time, every 1.6 s, travelling 1.2 s
  and resting 0.4 s. With u = t / 1.2: radius 56 + 156 × (1 − (1 − u)²), alpha
  0.8 × (1 − u⁴), width lerp(4, 1.5, u) px, 128 segments,
  `Color(0.655, 0.44, 1.0, alpha)`. Rendered at both shapes, its pixels measure
  hue 261° at u 0.16, 258° at u 0.6 and 248° at u 0.83. Only the thin tail
  past u ≈ 0.9 goes slate, in the last 0.1 s before it vanishes. At its widest,
  r 212, it spans canvas y 88-512, clear of the Heading (which ends at 78) and
  the Line (which starts at 540).
- `_process` redraws the ring every frame on FAR_CALLING, as it does on CALLING.

## 5. Layout: `game/net/earshot.tscn`

There are two changes. Every existing node keeps its place, size and colour.

1. **Buttons** widens to offsets −420 / 602 / 420 / 658 (from ±282). It is
   centred, so one- and two-button pages are pixel-identical to today.
2. **Buttons/Third** is a new Button after Second, with `visible = false` and
   empty text. It gets `BUTTON_SIZE` and `FOCUS_ALL` in `_ready`'s loop with the
   other two, and `_button()` shows it like them.

### 5.1 Where things land (canvas px; every y is the same at both shapes)

| | 1280x720 | 2400x1080 (canvas 1600x720) |
|---|---|---|
| Heading, 22 px, `Color(0.404, 0.639, 0.588, 1)` | y 44-78, full width | same |
| Ring, 560x440 | x 360-920, y 80-520 | x 520-1080 |
| Line, 17 px, `Color(0.482, 0.686, 0.643, 1)` | y 540-568 | same |
| Receipt, 13 px, `Color(0.318, 0.463, 0.435, 1)` | y 572-592 | same |
| one button | x 508-772 | x 668-932 |
| two buttons | x 364-628, 652-916 | x 524-788, 812-1076 |
| three buttons | x 220-484, 508-772, 796-1060 | x 380-644, 668-932, 956-1220 |
| every button | y 602-658, 264x56, 24 px apart | same |
| Hint, 14 px, as the Receipt's colour | y 672-696 | same |

What reflows on a phone: nothing vertically. `expand` turns the extra width into
320 more canvas pixels, and everything here is centred. Every sentence already
fits one line at 1280. Under the button row there is only the Hint, which
ignores the mouse, so a low tap lands in dead space. Side by side the buttons are
24 px apart, as call and answer are.

### 5.2 Budgets

- **A Line is one line**: at most 1000 px of 17 px text in the theme font,
  about 125 characters. Every string in §6 fits. The longest, `cut off`'s,
  measures 982 px. There is no wrap, because a second line would land on the
  Receipt.
- **The Receipt, `address · port`**: the address as the owner typed it, host
  name or IP. IPv6 goes without brackets (`2001:db8::5 · 45772`). Over 48
  characters, keep the first 22 and the last 22 around `…`. The example
  throughout is `example.net · 45772`, an RFC 2606 name and an example port.

## 6. Every string

### 6.1 The screen's own

| where | string |
|---|---|
| chooser button, far page heading | §11 row 1; `by invite` until the owner picks |
| note under it | `a friend far away, who sent you one` with `by invite`; `a friend far away, by the invite they sent` with either other name (292 px, inside 320) |
| note under within earshot | `a friend on the same wi-fi` |
| buttons | `paste invite`, `call`, `paste new`, `forget`, `stop`, `keep`, `again`, `leave` |
| page lines and confirmations | as in §3 |
| Hint, FAR | `ctrl+v pastes · esc leaves`; touch: `back leaves` |
| Hint, FORGET | `esc keeps it`; touch: `back keeps it` |
| Hint, other far pages | `esc leaves`; touch: `back leaves`, as today |

The failure sentences below replace the placeholders in `Invite.SAYS`, the one
table the build in progress keeps them in. The keys are that build's. The
screen shows them and never writes them.

### 6.2 Paste failures, shown on FAR

The paste button keeps focus, so trying again is the same press.

| # | key | when | headline | sentence |
|---|---|---|---|---|
| 1 | `not_found` | nothing was copied, or no invite is in it | `no invite copied` | `copy your friend's whole message, then paste again.` |
| 2 | `damaged` | cut short or garbled (the check) | `invite damaged` | `some of it was lost or changed on the way. copy all of it, or ask your friend to send it again.` |
| 3 | `unknown_version` | an invite format newer than this build reads | `your game is older` | `this invite needs the update. take it from the launcher, restart, and paste again.` |
| 4 | `not_kept` (new) | it read, but `Invite.keep()` could not save it, which in practice means a full device | `invite not kept` | `this device would not save the invite. free up some space, then paste again.` |

Row 4 mirrors `invite kept`. Its receipt says `still kept:` only when §2's
read-back makes that true. It belongs in `Invite.SAYS` with the other three, not
in the screen.

### 6.3 Call failures, on TROUBLE

The screen also needs the key, because the first button depends on it. The
second button is `leave` on every row. The rows marked *new* are the LAN's
refusals and hang-up. A call by invite gets them today in a phone's wording,
which tells the player to update the *other* game from its launcher (a server
updates by itself) and calls the server a cell.

| # | key | when | headline | sentence | First |
|---|---|---|---|---|---|
| – | `no_invite` | nothing kept (these pages never offer call then) | `no invite yet` | `paste the invite your friend sent you first.` | paste invite |
| – | `could_not_call` | no socket; no network address at all (flight mode); or an IPv6 invite on a network with no IPv6 | `could not call` | `this device could not start the call. check it is online, then call again.` | again |
| – | `no_such_place` | the host name does not resolve | `nowhere by that name` | `check this device is online. if it is, ask your friend to check the address in their invite.` | again |
| 4, 10 | `no_answer` | nothing within 8 s: the server is down, the address is wrong, the port is closed, or this network blocks it | `no answer` | `nothing answered at the invite's address. ask your friend if their server is up, or try another network.` | again |
| – | `not_running` | the address refused the call: nothing listens on that port | `no server there` | `the address answered, but no server is listening. ask your friend to check theirs is running, then call again.` | again |
| 5 | `not_this_pond` | another certificate, or the right one under another name | `a different server` | `something else answers at that address now. ask your friend for a new invite, then paste it.` | paste new |
| 6 | `invite_refused` | revoked, replaced, or a proof that failed; the door bars the address for a minute | `invite no longer works` | `it was taken back or replaced. ask your friend for a new one, paste it, and call in a minute.` | paste new |
| 7 | *new* | versions differ, and this game is older | `different versions` | `your game is older than your friend's server. take the update from the launcher, restart, and call again.` | again |
| 7 | *new* | versions differ, and the server is older | `different versions` | `your friend's server is older, and updates itself once nobody is swimming there. call again in ten minutes.` | again |
| 8 | *new* | the server already holds two guests | `already two` | `two cells are already in your friend's water. call again when one of them leaves.` | again |
| 9 | *new* | cut for sending what it would not take | `cut off` | `your friend's server would not take what this game sent. take the update from the launcher, then call again in a minute.` | again |
| – | *new* | any other hang-up, including a refusal this build does not know; a call that proved nothing within 3 s, which the door then bars for a minute; and a call from an address it has barred, which it cuts as it connects | `they hung up` | `your friend's server closed the call. call again in a minute.` | again |

Every sentence names who acts: you, your friend, or nobody (wait). None of them
says DTLS, certificate, HMAC or port forwarding, and none says "pond", which no
player-facing string uses: the player's word is *water*. "server", "address",
"network" and "the invite" are as technical as it gets. The ten minutes in row
7 are the server updater's period, and it applies an update only while nobody
is in the water (`docs/server.md` §4). `nowhere by that name` is the build's own
headline, kept because it is better than the plain one.

## 7. Keyboard, gamepad, touch

- **Focus** is as §3 says. Enter or a pad's accept presses the focused button,
  left and right walk the row, and Tab cycles. **The Ring is `FOCUS_NONE` on
  every far page.** Today one up-press on CHOOSE moves focus onto the Ring,
  which draws no focus at all. This was measured on `main`.
- **Paste from the keyboard with `ui_paste`**, the engine's built-in action:
  Ctrl+V and Shift+Insert (4.7's `core/input/input_map.cpp`, and checked at
  runtime in this project). Handle it in `_unhandled_input`. It does exactly
  what the page's visible paste button does (paste invite, paste new, or
  TROUBLE's paste new), and nothing on a page that has none. It needs no new
  action, so there is no `project.godot` change.
- **Back and Esc leave the screen** from every far page and close any call, as
  on the LAN pages. The one exception is FORGET, where they mean keep: the safe
  answer to the question, much as ANSWERING's Back means back one.
- **Touch**: every target is a 264x56 theme button. Reading the clipboard needs
  no permission.

## 8. What this asks of the call

The network is C2's. These are the player's requirements on it.

- **Nothing blocks a frame.** `ENetConnection.connect_to_host` resolves a host
  name with `IP.resolve_hostname`, which blocks on a cache miss
  (`modules/enet/enet_connection.cpp` and `core/io/ip.cpp`, 4.7-stable). A slow
  or absent DNS would freeze the pulse and the stop button. The build in
  progress already resolves with `IP.resolve_hostname_queue_item` and connects
  to the literal address. Keep it that way.
- **Look the name up fresh on every call:** `IP.clear_cache(address)` before
  queuing it, which the build does. The resolver caches for the life of the
  process, so without it an owner's home address that changes while the game is
  open would stay wrong until a restart, as `no answer`.
- **Every call ends in a sentence**: 8 s for the call and 6 s for the name in
  the build. The pulse is the only sign of progress, with no counter and no
  second line.
- **Kinds the screen can tell apart.** Rows 5 and 6 each need their own key, and
  the build has them: row 6 is `REFUSE_INVITE`, never a silent hang-up, and
  row 5 is a pin failure. C.1 measured that at 16 ms with the transport never
  up. Whatever the session cannot tell apart falls back to `no_answer`.
- **A refused invite is not dialled again** (§3). That memory is the screen's or
  the session's. It needs no wire change.

## 9. The one line the server prints after minting

```
invite for %s written to %s, calling %s -- send its one line to %s and nobody else, and in Biogenic they tap play, then %s, then paste invite.
```

The five values are the label, the file's absolute path, `Invite.reach_text()`,
the label again and the chooser's name. With the placeholder label `sam` and a
placeholder address:

```
invite for sam written to /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/invites/sam.txt, calling pond.example.net:45772 -- send its one line to sam and nobody else, and in Biogenic they tap play, then by invite, then paste invite.
```

This replaces the main line of `invite_book.gd`'s mint, which says the rest
(a replaced label, the lowercase label, "takes it within seconds"). The line
never holds the secret or the invite; the path is how the owner gets at it. It
names the address the invite calls, so an owner who set `--reach` to a
home-network address sees it at minting, not from a friend's `no answer`.

## 10. What "looks right": the render checks, at 1280x720 and 2400x1080

Shoot with `tools/earshot_shot.gd` (loading `far.tscn`) and drive it with real
input. Fill the clipboard with `DisplayServer.clipboard_set()`, which
round-trips under xvfb (checked). Then press paste invite once by touch and once
with a Ctrl+V key event. Pages: `far`, `far-kept`, `far-bad` (clipboard
`hello`), `far-calling` (an invite for an address that never answers),
`far-forget`, `far-together`, and one `far-trouble` per §6.3 row. Shoot the
chooser with `tools/shot.gd`. `no_such_place` can use a name under `.invalid`,
which RFC 2606 guarantees never resolves.

Where the build's harness had to differ, and why:

- **`far-calling` and `no_answer` call 198.51.100.1** (RFC 5737 TEST-NET-2).
  The spec named 192.0.2.1, which is this container's own gateway: it answers
  with ICMP port-unreachable, so the page left for `not_running` at once.
- **`could_not_call` is shot under `unshare -n`**, which is flight mode: only a
  device with no network gives it.
- **An IPv6 invite on a network with no IPv6 reads `could_not_call`.** It used
  to read `not_running`, which blamed the friend's server for this device's
  network. Fixed in `net_session.gd`'s `_diagnose`.
- **A call that must not reach the probes**, such as a re-shoot of the pulse, can
  run in its own namespace with a default route into the loopback, so every
  datagram to 198.51.100.1 vanishes:
  `unshare -n -- bash -c 'ip link set lo up; ip addr add 192.0.2.50/32 dev lo; ip route add default dev lo; …'`.

Check every frame for these:

1. Heading and Line are one line each, and no sentence nears the canvas edge.
   Measure with the font (§5.2), not by eye.
2. The row matches §5.1 to the pixel, 264x56 each. The focused button wears the
   theme's focus ring, and it is the one §3 names.
3. No far page shows a bearing segment. The pulse is violet, measured rather
   than eyeballed, because a dim hue on a dark ground fools the eye: its
   brightest pixels have hue ≥ 245° at u ≈ 0.15 (inside the membrane) and at
   u ≈ 0.6 (outside it). It never touches the Heading or the Line.
4. The Receipt shows address · port. A 60-character name comes out as 22 + `…`
   + 22.
5. At 2400x1080 every node sits at the same canvas y as at 1280x720, centred in
   1600.
6. On the chooser, the pair sits at y 490-546. Each note fits inside its
   button's width, with 64 px between their boxes. Full vision and point of view
   are still 460 wide, and the remembered view has the focus ring.
7. A failed paste on a kept invite shows `still kept:` and the address. A
   successful one says so in the Line.

Two things only a device shows: Android's toast over the button row after a
paste (expected, and the system's), and the pulse in motion.

### 10.1 Judged on the build (8660066), at both shapes

| frames | verdict |
|---|---|
| chooser | **Passes.** Rects exactly as §1.1 at both shapes. The notes are 185 and 259 px inside 320, the boxes 64 px apart. On a real keyboard, Full → Down → Pov → Down → within earshot → Right → by invite → Up → Pov. |
| `far`, `far-pasted`, `far-kept`, `far-long`, `far-v6`, `far-pasted-new`, `far-pasted-same` | **Pass.** Node for node as §5.1. The long name reads `biogenic-pond-at-home.…ider.house.example.net · 45772`: the cut falls after a dot, so it shows four dots, which is the rule working as written. |
| `far-bad`, `far-bad-kept`, `far-damaged`, `far-newer` | **Pass.** Each headline and sentence is one line; `still kept:` shows only with a kept invite; the paste button keeps focus. |
| `far-forget`, `far-forgotten`, `far-refused-back` | **Pass.** `keep` has focus. The refused invite is remembered across a trip through the chooser. |
| `far-calling-u015` | **Passes.** Pulse hue 256°. |
| `far-calling-u06` | **Failed, and the fault was the spec's curve.** The pulse read slate blue, hue 219°. Re-rendered with §4's new curve: 258° at 1280x720, 259° at 2400x1080. |
| `far-together` | **Passes.** The nucleus is violet; the last view has focus. |
| 12 `far-trouble-*` | **Pass.** One line each (the widest, `cut_off`, is 982 px), the right first button with focus, the membrane dimmed. |
| 5 LAN pages | **Pass: 0 px differ from `main`** at both shapes, and `main`'s three runs are 0 px apart. The Ring's `FOCUS_NONE` (§11) is in, and an up-press on CHOOSE now leaves the focus on call, while ANSWERING still takes keyboard taps on the ring. |

Not shot: `not_kept` (§6.2 row 4), which needs a full disk. Its sentence
measures 617 px, and it lays out exactly as `far-bad-kept`.

**Files the build touches**, all content, so no `binary_version` bump:
`game/mode_select.tscn` and `.gd`, `game/net/far.tscn` (new),
`game/net/earshot.tscn` and `.gd`, `game/net/invite.gd` (`SAYS`, §6),
`game/net/net_session.gd` (the new rows of §6.3, and §8),
`game/server/invite_book.gd` (§9), `tools/earshot_shot.gd`, the scene loop in
`.github/workflows/ci.yml`, and `docs/server.md`.

## 11. Left open

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | What is joining a friend's server from far away called on screen? | **across the water ✓ recommended** / far water / by invite | It is the new button beside "within earshot" and the heading of its screen. "across the water" is the far twin of "within earshot", in the word the game already uses for a world ("you are in their water"). "far water" says the same more bluntly. "by invite" only says how you get in. Until you choose, it ships as "by invite". |

On row 1: switching costs two strings and one note (§6.1). The biology was
checked first. Real cells signal far away through the blood (endocrine) and
nearby to their neighbours (paracrine), and pond protists reach new water as
cysts carried on birds' feet. Both are true and apt, and both need explaining,
which fails the test `ampulla` passes: a real name has to explain itself on
sight.

Noticed, and not in this spec's scope:

- **The LAN pages lost keyboard focus** (fixed in the build). One up-press
  moved focus onto the Ring, which draws none. The Ring is now `FOCUS_NONE`
  except on ANSWERING, and the LAN frames are otherwise pixel-identical to
  `main`.
- **An invite minted with a home-network address** (192.168.x and the like)
  can only ever say no answer from outside. §9's line shows the address. A
  warning at minting would go further; that belongs on the server's side.
- **Opening Biogenic by tapping the invite in the chat app** would need an
  Android intent filter: a manifest change, and so a binary bump. Not proposed.
- **The chooser does not remember** that a player last came in by invite. The
  remembered view keeps the focus, as today.
