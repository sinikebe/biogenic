# Shared pond: what each player sees

Player-facing states for two players in one body of water on LAN. The netcode
is `shared-pond.md`; this file is what draws and what is said. Owner decisions,
final: one pond, a friend you text; a dividing player leaves the water and
returns as the chosen daughter where they left; one eating rule for every cell;
**A**, death is a tap on the black and a return as a generation-1 cell near your
friend, and nobody's death resets the pond, the host's included; **B**, pause
stops nothing.

**Status: specified and mocked, not built.** A scratch harness, not committed,
drew the unbuilt marks with the shipped routines over a real `drive.tscn` run at
1280x720 and 2400x1080: pause under B at scrim 0.5, 0.70 and 0.86, the ghost, a
friend wearing a threat bow, the held pond, and the notices. **Not seen:** any
fade in motion, the §0.5 beat, anything on a device.

## 0. Five rules every state shares

**0.1 A friend is now a body.** Today `_draw_peer` draws the friend with empty
tiers and zero gape and passes `is_self`, which hides the threat bow, on purpose:
*"their mouth cannot reach you"*. In one pond it can. So the friend is drawn by
`Cilia.draw_cell` like every body: worn tiers, order, gape, wound, and
`double = smoothstep(32, 40, r)` so the nucleus warns of a division. They get the
scent haze on the same curve as anything you could swallow. They stay
**untinted**, because `SELF_TINT` is still the one colour no water cell wears,
but they **can threaten**: the red toothed bow shows whenever their gape exceeds
your radius. The person marks stay as shipped: the halo (`HALO_STEPS` 7,
`0.013·(1−k)·0.6`), the trail (`MOTION_TINT`, `PEER_TRAIL_ALPHA` 0.13), and the
off-frame edge mark (`SELF_TINT` arc 0.78, barb 0.85, `PEER_MARK_INSET` 64).

**0.2 Presence fades; the body does not.** In one pond no single body can be out
of date on its own. The host simulates the guest, so the guest's place is exact
on the host's screen, and the guest's whole pond stops when the host's phone
does (§5). So **the dashed doubt ring and the `atan(doubt/d)` widening of the
edge mark are retired in the pond**: a ring round one body, in a water where
every body is equally out of date, would claim the rest are current. What fades
instead is *presence* (halo, trail, edge mark), on the shipped confidence curve:
`PEER_FRESH` 1.2 s → `PEER_LOST` 9.0 s, squared, floor `PEER_FLOOR` 0.30. A body
in the water is always drawn at 1.0, because it can bite.

**0.3 Out of the water is a ghost.** Body, halo and edge mark at
`DIVIDE_FADE_DIM` 0.34, the alpha the division already gives the daughter you
decline. No threat bow, no new trail points, and nothing collides with it.

**0.4 One line.** Every sentence goes on the existing `Hud/Onboarding` label
(18 px, `Color(0.855, 0.953, 0.933, 0.55)`, `anchor_top` 0.72) through `_say()`,
with the sense line's timing: in over `ONBOARD_FADE_IN` 1.1 s, held
`SENSE_LINE_HOLD` 7.0 s, out over `ONBOARD_FADE_OUT` 0.8 s. A line never covers
the steering onboarding line, a division, the black, the replay or the open
menu. It waits in a one-slot queue where the newest wins, and it is dropped, or
faded out early, the moment what it reports stops being true. Each carries a
fact about another person that no sense can, as the earshot screen already does:

| when | the line | seat |
|---|---|---|
| your water is replaced by theirs | `you are in their water` | guest |
| their cell arrives | `they are in your water` | host |
| they die, to the water or by starving | `they died · they come back near you` | either |
| you ate them | `you ate them · they come back near you` | either |
| `SILENCE` 6.0 s with nothing heard | `their phone went quiet`, no timer; it goes when they are heard | either |
| the host's water is gone | `their water is gone · this one is yours` | guest |
| the guest is gone | `they left`, earshot's own string | host |

**0.5 "The water changes" is one beat, used for entering (§1) and for swimming
on alone (§5).** `_hush()`. The world goes out and back in through
`vision.set_active(false/true)`, `FADE_SECONDS` 0.22 s each way, with the camera
snapped and the trails cleared in between. `_bus.revive(t)` runs over
`DEATH_RETURN` 0.9 s, then `pulse_now()`. Meanwhile the controls behave as at a
pinch: the steering control stays drawn but does nothing, and the action pads
go. This is the aperture that already opens on every new water (a birth, a
newborn daughter, a return from death), so it says *new water* without a new
beat. It never closes the aperture first, because closing means death.

## 1. Entering the pond

| seat | full vision | point of view |
|---|---|---|
| **guest** | The §0.5 beat. You arrive `SISTER_DISTANCE` 560 units from the host along the world horizontal, so in north-up (the default) they are in your first frame. After the beat: `you are in their water`. | The same beat on the membrane, then the line. From here the host is a body your senses find like any other, plus their shouts. |
| **host** | The guest's body fades in from 0 to 1 over `DEATH_RETURN` 0.9 s where it lands: body, halo and edge mark together, trail empty. At the end: `they are in your water`. | The line only. |

If the pond already exists when the guest's run starts, there is no swap: the
run opens as today and the line waits `ONBOARD_DELAY` 2.2 s. The swap waits for
an ordinary frame. It never happens while the guest is dead (the tap on the
black wakes straight into the pond), dividing, or in the menu.

## 2. Your friend divides

| their phase | full vision (either seat) | point of view |
|---|---|---|
| from r32 | Their nucleus doubles, worked out from their radius alone. | nothing new |
| quicken, 2.4 s | Unchanged: still in the water and still edible. | unchanged |
| pinch, 1.5 s | They leave the water. The body pinches (`pinch` 0 → 1) and falls to the ghost's 0.34 over the same 1.5 s. The trail stops. | Every sense stops finding them and their shouts stop: a body out of the water answers nothing. |
| choosing, no timeout | The ghost holds: 0.34, fully pinched, two nuclei, breathing on `cilia.gd`'s own clock. | nothing |
| commit, 0.9 s | The ghost becomes the daughter where it stood: alpha 0.34 → 1.0, pinch 1 → 0, radius 40 → 28.28, her tiers. The sister she declined, tinted and now a water cell, fades in at 560 on her side with §1's fade. | They are back, as a smaller body. |

**No line for this:** at three meals a generation a friend divides every 30–45
s, and a notice that often is noise. Mocked: the waist and the two nuclei read
as *dividing*, not as *quiet* (whose body stays at full) or as a water cell.
**Your own division in the pond** dims the world to `DIVIDE_WORLD_FADE` 0.22 at
the **pinch**, where you leave the water, not at the parting. Behind the
daughters the pond keeps moving at 0.22 and shows what you are coming back to.
There is no field reseed.

## 3. Your friend dies, waits, and comes back

| event | full vision | point of view |
|---|---|---|
| eaten by the water (swallowed, or chewed apart) | The body goes in the frame it happens. A `SELF_TINT` meal ring marks the spot: `_draw_meals`' own ring, r → 3.6 r over `GHOST_LIFE` 2.4 s, alpha `0.45·(1−t)²`, 1.6 px. | nothing drawn |
| starved | The body fades 1 → 0 over `FAINT_COLLAPSE` 2.6 s, the tempo of their own quiet death. No ring. | nothing drawn |
| eaten by you | Nothing is added. Your own meal ring and ingest flood, in their gene's hue, already fire. | the ingest flood |
| any of the three | The halo, trail and edge mark go with the body. `they died · …` or `you ate them · …` | the same line |
| they sit on their black | nothing: they are in no water | nothing |
| they tap | They arrive 560 units from you along the world horizontal, with the 0.9 s arrival fade (if you have no body, where yours last was). A line still waiting is dropped. | nothing; they are a small new body |

## 4. You die while your friend plays on

The black is today's black: collapse, `DEATH_HOLD`, the invitation, `watch`,
and no text. **The pond runs on underneath** on the host's phone, even when the
host is the one who died, so `_die()` and the division's pinch must stop only
your own cell. A tap runs `revive` over 0.9 s straight into the pond near your
friend, at generation 1, with no reseed; in full vision your friend is in the
first frame. Back on the black still leaves the run; when the host does it, the
guest goes straight to the §5 takeover with no wait. **The replay must record
the friend as a body** and draw them as they were drawn live. Today a replay has
no peer in it (`panes.gd` never calls `set_session`), so a player your friend
ate would `watch` themselves being eaten by nothing.

## 5. A phone goes quiet, or is gone

`keep_screen_on` is true here (checked), so a phone laid down on the black stays
awake; a phone goes quiet by the power button or by leaving the app.

**The guest goes quiet (host's screen).** Their body stays at 1.0, drifting on
the host's simulation: edible, and still biting, which is B's rule applied
without their consent. Their presence (halo, trail, edge mark) follows §0.2's
curve down to 0.30. At 6.0 s, in both views: `their phone went quiet`. When the
link is gone the body fades out over 0.9 s, the arrival fade reversed, and the
line is `they left`.

**The host goes quiet (guest's screen).** The pond lives on the host's phone, so
it stops:

| | full vision | point of view |
|---|---|---|
| from 1.2 s: the pond is held | `set_dim(DIVIDE_WORLD_FADE)` 0.22, through the view's own 0.22 s fade. Your cell is drawn outside the dim at full, as the daughters are, heading needle kept. The host dims with their water. No doubt ring. | `_hush()`: every sensation lets go. The beat goes on and the figure stays. |
| both views | The steering control stays drawn but does nothing, and the action pads go. The pause target stays, so leaving is always two taps away. | the same |
| 6.0 s | `their phone went quiet` | the same |
| heard again | The world returns to 1.0 over 0.22 s and the line fades out. | Sensations resume. |
| gone (owner row 1) | The §0.5 beat, onto a fresh water seeded round your cell, which keeps its body, genome, generation and hunger. `their water is gone · this one is yours`, said once. Pause is ordinary again. | the same |

Mocked at 2400x1080: the dimmed world reads as *stopped*, not *broken*, because
the membrane and its beat stay lit. If the host's water comes back after the
guest has swum on alone (owner row 2), the guest gets §1's beat and line again.
A guest whose own phone was the quiet one tries the host first (earshot's
`REACH_TIMEOUT` 4 s) before swimming on alone, so waking is one beat, not two.

## 6. Pause under B

The menu opens over a live pond. Four things make that unmistakable, and only
the first two are new.

1. **The water behind the scrim is visibly live.** Point of view keeps
   `SCRIM_POV` 0.5; the membrane is the outer band the column never reaches, and
   a bite now flashes there. Full vision gets **`SCRIM_POND := Color(0.023,
   0.055, 0.05, 0.70)`** instead of 0.86, which exists because *"the water is
   not what they came to read"*. Under B it is. Mocked at both shapes: at 0.5
   the centred cell's cilia run through `camera`; at 0.70 every caption reads
   and a hunter and the friend are plainly there.
2. **A warning line.** New node `Hud/Pause/Center/Buttons/Resume/Warn`, a
   `Label` that is a child of the button so the VBox never lays it out. Anchors
   left/right 0.5 and top/bottom 0; offsets −300 / 300 / −35 / −13; 15 px;
   `Color(0.855, 0.953, 0.933, 0.82)`, the buttons' own text colour; centred;
   `MOUSE_FILTER_IGNORE`. Text: `the water is still moving · you can still be
   eaten`. It sits in the existing 48 px gap between Settings and Resume (y
   479–501 at both shapes, 13 px clear of each), so the column, 629 of 720 px
   tall, grows by 0 px. Hidden while the pond is held (§5), when it is false.
3. **Your cell is let go and drifts**; the drawn controls stay drawn and dead.
4. **Nothing else moves.** `resume` and `leave` keep 232×56 px and their 48 px
   gap, and the two-bar glyph still opens the menu.

**Wiring.** The tree is never paused while a friend is in the pond, on either
seat; with no friend in it, pause is today's pause. `Hud/Pause` keeps its
default `MOUSE_FILTER_STOP`, which becomes load-bearing: a press that misses
every widget dies there instead of steering a live cell. The cell's input is off
while the menu is up, including the keys `cell.gd` polls directly, because the
arrows also move menu focus. `_update_pause_tap()` and the strand's arming clock
key on the menu being open, not on `get_tree().paused`.

## 7. Eating your friend, or being eaten

**Needs no new language.** Swallowing or chewing a friend, or being swallowed or
chewed by one, is the same `hit`, collapse and ingest flood as with any cell. In
point of view a friend is a body of their size and nothing more; one your own
size is odourless (`multiplayer.md` §8), which is honest. The only change is
§0.1's: their mouth, threat bow, scent haze and wound become visible, hidden
today only because a friend could not eat you. Add `you ate them` (§0.4). The
eaten player's black gets no text: `watch` answers *what was that*, which is why
§4's replay requirement is not optional.

## 8. Godot-ready, and what the wire must carry

- **`cilia.gd`:** one optional trailing argument, `untinted := false`. The
  friend is drawn with `is_self` false, so the threat bow can show, and
  `untinted` true, so the body stays `SELF_TINT`. Existing calls are unchanged.
- **`vision.gd`:** the §0.1–0.3 drawing, with presence as one scalar; the
  ghost, return, arrival, departure and death fades; no `_draw_doubt` and no
  doubt term in `_draw_peer_mark` while a pond is up; your own cell drawn outside
  `_dim` while the pond is held.
- **`normal_mode.gd`:** `SCRIM_POND`, B's pause path, the §0.4 queue, the held
  pond, the §0.5 beat, the division dim moved to the pinch, and death and
  division stopping only your own cell, with no reseed.
- **`normal_mode.tscn`:** the `Warn` label, a node rather than a resource, so
  `load_steps` is unchanged. **The replay:** the friend recorded as a body.
- **`tools/drive.gd`:** needs flags to pose a friend who is out of the water,
  dead, quiet or held. §9 cannot be shot without them.
- **For `shared-pond.md`:** per friend, the wire carries worn tiers and order
  (not DNA), radius, heading, gape or cytostome tier, wound, and a state (in
  water; out of water since *t*; dead, eaten or starved and by whom), plus
  arrival and departure events. The guest keeps its own cell's full state for
  the takeover. None of it reaches the signal bus; point of view gets the lines.

## 9. Renders the build must pass, at both shapes

Use `--seed=` for every shot, and zero-diff three runs before any A/B.

1. A friend with fringe and threat bow beside your own cell: both read as
   people, and the bow reads as a threat.
2. The friend's ghost mid-choice, beside a water cell and a quiet friend.
3. A friend arriving 560 units away in north-up. **1280x720 is the tight
   shape:** if the camera's lead puts the body on the frame edge, move the
   arrival to 480, not the frame.
4. The guest's entry beat at 0.45 s and after; the held pond at 3 s and 7 s;
   the takeover mid-beat and after. All in both views.
5. Pause under B, with a hunter in frame and a bite landing while the menu is
   open. **Judge it in motion on a phone:** 0.70 is a mock's number.
6. Your own division in the pond, dimming from the pinch with the friend moving
   behind the daughters.
7. A death replay where the friend was the killer: the friend is drawn.

## 10. Left open: owner's call

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | How long does the pond wait for a phone that went quiet? | **until the connection gives up by itself, about 5–10 s ✓ recommended** / 30 s / 2 minutes | While the host's phone is quiet, the guest's water is frozen and they can only wait or leave. While the guest's phone is quiet, their cell drifts in the host's water and can be eaten. When the wait ends, the guest swims on alone and keeps their cell. |
| 2 | When a dropped friend's water comes back, do the two swim together again? | **yes, automatically ✓ recommended** / no, both leave and call again from the code screen | Yes: the guest is carried back into the host's water with the same arrival as the first time, and both keep their cells. No: a dropped pond is over, and sharing again restarts both players at the first generation. |

The rows lean on each other: a short wait is only kind because rejoining is
automatic; if row 2 is *no*, row 1 should be 30 s, raising the connection's own
give-up time. To watch in play, not decide: under A, a friend you just ate
returns 560 units away, as a cell you can probably swallow.
