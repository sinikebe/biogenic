# A line per gene, and a way to reach pause

The owner's ask, in one sentence each:

> "Add a quick explanation of genes when selected in the menu."

> "And add a button to reach pause. Back is annoying to use as it hides on full
> screen apps so it's 2 actions to click it."

Two changes, both on surfaces that already exist. Nothing new to teach, no new
screen, no new input, no new binary. Extends `genes-and-cilia.md` §5 (the genome
strip) and takes the exemption `diegetic-hud.md` §3 did not have.

## 1. The eighteen lines

Voice: lowercase, plain, no jargon — the register of `choose a view` and
`a sense grew`. **Each line says what the gene does for the player, not what the
organelle is.** No line names another gene, because a player reading *armor* has
not necessarily met the mouth yet. No line carries a number: the tier is the
pips' job, and `+30%` is the classic HUD this game spent two phases not building.

| gene | word | line |
| --- | --- | --- |
| `cytostome` | *eat* | a wider mouth swallows bigger things whole |
| `cirrus` | *turn* | turns you faster, and sooner after you ask |
| `flagellum` | *swim* | your tail beats harder, and more often |
| `stigma` | *see* | feels the shadow of anything big, however dark |
| `ocellus` | *beam* | a ray out of that side, marking whatever it strikes |
| `chemocyte` | *smell* | smells food, and which way it is |
| `ampulla` | *ping* | a pulse that answers off everything, not just food |
| `axoneme` | *push* | holding on pushes you, instead of only steering |
| `statocyst` | *level* | always knows which way is up, however you turn |
| `rhabdom` | *focus* | sharpens where a smell is coming from |
| `palp` | *touch* | feels what is against you, with no light at all |
| `myoneme` | *dash* | tap for a burst of speed, paid for in hunger |
| `trichocyst` | *sting* | a dart at whatever closes in on that side |
| `pellicle` | *armor* | thicker skin, so bites take less and fewer mouths fit |
| `toxicyst` | *venom* | whatever bites you pays, and whatever swallows you dies |
| `plastid` | *sun* | makes a little of its own food, so you starve slower |
| `vacuole` | *store* | a bigger tank, so hunger takes longer to reach you |
| `crista` | *burn* | burns cleaner, so everything you carry costs less |

And one for a slot with nothing in it, because an empty slot still has the one
thing the compass on its tile is drawing:

> nothing here yet · an organ here would look this way

**`that side` in `ocellus` and `trichocyst` is deliberate.** Those are the two
genes whose slot decides where they look, and the tile they sit on already draws
the compass the phrase points at. The line is where *why the slot mattered*
finally gets said in words.

### 1.1 The biological name goes on this line

§8 says the biological name "never reaches the screen". The argument it gives is
the glance: four short verbs are parsed at arm's length and nine letters of Greek
are not, **on the surface whose whole job is a quick decision**. That argument is
about the tile, and the tile keeps the plain word.

The explanation line is not a glance. It is read because the player stopped to
read it. So it leads with the name:

```
ampulla · a pulse that answers off everything, not just food
```

`ampulla` is drawn in the gene's own hue — the hue of the tile border just
tapped, and of that organ on the player's own body — and the sentence in the pale
tint every other word on this column wears. That colour difference is what makes
it read as a name and a sentence rather than as one clause.

§9.1 gives every gene two names on purpose. A name no player ever meets is a
convention for the compiler; CLAUDE.md's *realism is a tool* is the argument that
`ampulla` is worth meeting, and this is the only line in the game that can carry
it. **§8's rule is narrowed to the tile, not repealed.**

## 2. "Selected" means selected, and that had to change

Arming was the obvious hook and it was checked against the code first. It does
not work as it stood: `_make_tile` set `live = index >= 0 and held_sample != ""`,
so **a tile only accepted input while a gene was waiting to be placed.** That is
a few seconds of a fourteen-minute run. For the rest of it the strip is a
picture, and a picture cannot be asked what `ampulla` does.

So arming is generalised rather than reused:

| | before | now |
| --- | --- | --- |
| tap a tile | only while a sample is held | always |
| what the first tap does | arms for a commit | **selects**: the line under the strip becomes that gene's |
| what a second tap does | commits the swap | commits **only if** a sample is held and the tile is a real slot; otherwise nothing |
| the sample tile | inert | selectable, never committable — it is the gene you most need to read |
| arming lapses after 4 s | always | **only when it is committable** |
| on opening pause | nothing selected | the sample if held, else the first gene carried |

**Nothing became easier to do by accident.** The one irreversible action in the
game — §9.7's swap — still needs a held sample, still needs two taps on the same
tile, and still has `ARM_GUARD_MS = 300` between them. What changed is that a tap
with no sample behind it now does something instead of nothing.

Three consequences worth writing down:

- **The lapse rule inverts.** `ARM_TIMEOUT_MS` exists so a strip left armed is
  not a trap. A selection with nothing to commit is not a trap, it is a player
  reading a sentence, and four seconds is not long enough to read one twice. So
  only a committable selection lapses, and when one does it falls back to the
  sample rather than to nothing.
- **A second tap on a non-committable tile is a no-op, not a deselect.** It was
  built as a deselect and the render killed it: Godot focuses a control on click,
  so the tile keeps a pale focus ring whether or not it is selected — and a
  deselect left a ringed tile with an empty sentence under it. The surface
  pointing at something and then refusing to say what is worse than a tap that
  changes nothing.
- **A commit leaves the placed slot selected.** The sample is spent, so nothing
  about that selection is committable any more. It is a receipt: the line under
  the strip is now the gene that just landed, at the one moment in a run the
  player most wants to know what they have given their daughters.

**Desktop gets hover on top.** Pointing at a tile shows its line without
selecting it; moving off restores the selected tile's. That is the cheapest
possible way to read all eighteen, and it costs a touch player nothing because a
thumb has no hover — which is exactly why the tap path is the one that is tested.
Hover deliberately does not restyle the tile: a tile that lit under the cursor
would be promising a second tap it has not been given, and the cursor is already
sitting on the answer.

## 3. Where the line went, and what it cost

Between `Row` and `Hint`, inside the existing `Genome` box. Reading order is
*dna → the tiles → what this one does → what to do about it*.

```
Hud/Pause/Center/Buttons/Genome   VBoxContainer  separation = 10
  ├── Caption  Label  "dna"  15px  Color(0.855, 0.953, 0.933, 0.45)
  ├── Row      HBoxContainer  separation = 20  alignment = CENTER
  ├── Explain  HBoxContainer  separation = 4   alignment = CENTER   <-- NEW
  │     ├── Gene  Label  15px  Color(gene hue, 0.95)
  │     └── Says  Label  15px  Color(0.855, 0.953, 0.933, 0.62)
  └── Hint     Label  14px  Color(0.855, 0.953, 0.933, 0.38)
```

`Explain` carries `custom_minimum_size = Vector2(0, 21)` so the column does not
change height when the line is empty. Measured: the first lit row of the column
sits at the same canvas y with a gene's line, with an empty slot's line, and with
no line at all — the layout does not move.

**Two rows, not one, and the reason is that both are wanted at once.** The hint
already carries `tap a slot · your daughters wear it` and `tap again to place`.
Folding the explanation into it would mean choosing, and the moment it would have
to choose is the moment a player is about to overwrite a gene — which is exactly
when *what that gene does* matters most. So they are separate lines and both are
on screen together.

### Measured

Measured off the render, not off the scene: the first lit row of `dna` down to
the bottom edge of the `leave` slab, in canvas px, on the widest state the game
can reach (7 slots, a sample held).

| | before | with the line |
| --- | --- | --- |
| column, top .. bottom | y 47 .. 681 | **y 31 .. 697** |
| column height of 720 | 634 | **666** |
| clear above / below | 47 / 39 | **31 / 23** |

**The line costs 32 canvas px.** A second tile row was measured last pass at 86
and did not fit; one text line does, with 23px of clearance under `leave` at the
tightest end.

| | canvas px |
| --- | --- |
| longest line, `toxicyst`, with its name, at 15px | **484** |
| widest strip it sits under (7 slots + sample + arrow + tail) | 652 |
| the line at 3 slots — wider than the strip | fine; every group on the column is centred, so the column simply becomes as wide as its widest row |

The canvas is 720 tall at **both** shapes — `expand` only ever widens it — so the
vertical stack is identical, and this is the one measurement that decides whether
it fits. Confirmed rather than assumed: the text of the column runs y 31 .. 677
at 1280x720 and y 31 .. 677 at 2400x1080, to the pixel.

**Reflow on a tall phone:** none vertically. Horizontally the canvas is 1600
wide, the strip and the line stay centred and gain 160px of margin each side.

## 4. The pause target

**The problem is Android and it is real.** Back is the only way in on a phone,
and in a fullscreen app the gesture bar is hidden — so reaching pause is a swipe
to reveal it and then a swipe to use it. Two actions for the one control every
other control lives behind. **Back and `Esc` are untouched.** This is a target,
not a replacement.

`diegetic-hud.md` §3 bans numbers, letters and icons in the playfield. That rule
is about *readouts* — it exists so the HUD cannot compete with the senses — and
a control the player presses is not a readout. The lead has resolved the
collision in favour of the control. What the rule still binds is the volume.

### 4.1 What it is

| | |
| --- | --- |
| node | `Hud/PauseTap`, a `Control`, before `Hud/Pause` in the tree so the scrim covers it |
| anchor | top left, offsets `(48, 48, 104, 104)` |
| size | **56 x 56 canvas px** — above CLAUDE.md's 48, and 84 device px at 2400x1080 |
| well | `StyleBoxFlat`, corner radius 12, 1px border |
| well, rest | bg `Color(0.063, 0.141, 0.125, 0.13)`, border `Color(0.12, 0.70, 0.58, 0.09)` |
| well, hover | bg `Color(0.063, 0.141, 0.125, 0.58)`, border `Color(0.12, 0.70, 0.58, 0.48)` |
| bars | two, 4 x 18, 6px apart, corner radius 2, `Color(0.855, 0.953, 0.933, a)` |
| bars, rest / hover | `a = 0.17` / `a = 0.92` |
| focus | **`FOCUS_NONE`** |
| visible | only while `ALIVE`, not dividing, not paused |

**Top left, one launcher edge margin in.** The launcher puts `BIOGENIC` in that
corner at `edge_margin = 48`; the corner the player has already seen carrying
this game's chrome is the corner the game keeps it in. It is also away from where
a thumb rests in landscape — the bottom two corners — so the steering drag cannot
start on it.

**A geometric mark, on purpose.** The water contains no straight lines and no
right angles: that is precisely what the diegetic rule bought. A rounded slab
with two bars in it therefore cannot be mistaken for a sensation, and the grammar
that says *this is interface* was already paid for. The slab is the pause
column's own colour and radius, so what you tap looks like a piece of the surface
it opens.

**Quiet, and always there.** A phone has no hover, so a control that appeared on
touch would need a touch to find — and a touch in the playfield already steers
and dashes. It is visible at all times and faint enough to ignore. The mouse gets
the bright state, which costs a touch player nothing.

**`FOCUS_NONE` is not an oversight.** The playfield has no other focusable
control, so a focusable one would hand the arrow keys to GUI navigation the
moment anyone pressed Tab — and the arrow keys are how the cell is steered.
Desktop has `Esc`; this target is for the thumb that has no Back gesture to find.

**Hidden wherever pause cannot be reached.** `_toggle_pause` refuses during a
division (the choice has no timeout and no default) and a dead cell's Back is the
exit rather than the pause. A control that is drawn and does nothing teaches the
player that tapping it does nothing.

### 4.2 The tap has to be swallowed

An unclaimed press in the playfield is a steer, and a short unclaimed press is a
`myoneme` dash that costs hunger. The handler calls `accept_event()`.

Godot delivers a phone touch **twice** — once as itself and once as an emulated
click — so both copies are claimed, and `_toggle_pause`'s existing same-frame
guard is what stops the pair from toggling twice. That guard was written for
Android Back arriving as both a notification and a key; it earns its keep again
here.

Measured, both with a tier-2 `myoneme` in the genome:

| tap at | what the bus saw |
| --- | --- |
| canvas `76,76` (the target) | nothing — no thrust, no steer; the pause screen opened |
| canvas `640,600` (open water) | `thrust bearing +0.0 deg strength 1.00` — the dash, as it should |

### 4.3 It loses to the signals

Glance peak is the σ = 6 px Gaussian peak on the 8-bit output — the same
measurement `diegetic-hud.md` §4 uses, and the only fair way to compare a 4px bar
against a 200px swell.

**The number that matters is what the target *adds*, not what its corner reads**,
because the membrane's contour runs through that corner and brightens and dims
with the beat. So each frame is measured twice: the top-left corner, which has
the target, against the bottom-left corner of the same frame, which has the same
contour geometry and no target.

| frame | corner with the target | same corner, bare | **the target adds** | the body in that frame |
| --- | --- | --- | --- | --- |
| point of view, 1280x720 | 30 | 17 | **+13** | self figure 60 |
| point of view, 1280x720, brighter beat | 51 | 43 | **+8** | self figure 60 |
| point of view, 2400x1080 | 30 | 14 | **+16** | self figure 71 |
| full vision, 1280x720 | 34 | 21 | **+13** | own cell 142 |
| full vision, 2400x1080 | 29 | 11 | **+18** | own cell 185 |

**8 to 18 of glance**, against a self figure at 60–71 and the player's own cell
at 142–185 — four to nine times under the quietest thing it shares a screen with,
and an order of magnitude under `diegetic-hud.md` §4's held-sample mark at 62.9.
Hovered it comes to 87, and that is a mouse and a deliberate act.

The worst case was posed on purpose: a hunter at 150 units on the forward-port
quarter with `gain` at maximum, so a saturated `stigma` lobe blazes across exactly
the pixels the target occupies. The lobe reads 219 there and the corner reads 218
— **the target does not add light, it subtracts it.** The well is a 13%-alpha
dark teal, so over a bright lobe it is a slightly darker patch and the bars vanish
into the glare. The silhouette survives, the position is known, and the signal
wins outright. That is the ranking `diegetic-hud.md` §4 asks for, reached without
an alpha ramp.

## 5. What was rendered

At 1280x720 and 2400x1080, `--rendering-driver opengl3`, through
`tools/drive.tscn`.

| frame | judgement |
| --- | --- |
| point of view, calm, both shapes | passes. The target sits in the dark wedge outside the membrane's rounded corner; at 720 the contour grazes its lower edge and reads as passing behind a translucent pane, which is honest |
| full vision, calm, both shapes | passes. Quieter against a lit world than against the dark one, which is the right way round |
| target at rest vs hovered, zoomed 2x | passes. Rest is a watermark, hover is unmistakably a control |
| tap the target, point of view 1280x720 | passes. One tap reaches pause; `cytostome` is selected on arrival with its line under the strip |
| tap the target, full vision 2400x1080 | passes. Same, and the column is centred on the 1600-wide canvas |
| tapping the target with a `myoneme` genome | passes. No thrust on the bus; the control tap in open water does fire one |
| 7 slots + held sample, armed on an occupied tile, both shapes | **the case most likely to overflow.** Passes: `ampulla` + its line under a 652px strip with a sample block hanging off the left, `tap again to place` below it. Nothing overflows, nothing collides |
| the longest line — `toxicyst`, 484px | passes, inside the strip's own width at 7 slots and centred at 3 |
| an empty slot selected | passes. Bright teal 2px border, `nothing here yet · an organ here would look this way`, no name |
| hover on a tile while another is selected, both shapes | passes. The line follows the cursor and the selected tile keeps its border |
| two taps on an empty slot with a sample held | passes. `dash` lands in the slot, the sample block goes, the strip re-centres and the line becomes the receipt |
| a tile selected, photographed 7 s later | passes. Still selected — the lapse only applies to a committable selection |
| Back, at 2.0 s | passes. Still pauses |
| during a division (`--radius=40`) | passes — no target drawn |
| during a death (`--hunger=1 --starve=44`) | passes — no target drawn |
| on the pause screen | passes — no target drawn; the scrim would cover it anyway |
| `Enter` on `resume` after `Esc` | passes. The keyboard path out of pause is unchanged and the target comes back |
| three `Tab`s then `Enter` from `resume` | passes. Lands on the second tile and selects it: the strip is readable with no mouse and no thumb |

**A harness bug was found and fixed on the way.** `--hover=` was added to
`tools/drive.gd` because the desktop half of the strip has no touch equivalent
and no other way to be photographed. Its first version scaled the canvas point by
the stretch transform the way `--touch=` has to — but `Viewport.warp_mouse` takes
a point in the viewport's own space and applies that transform itself, so at
2400x1080 the cursor landed 1.5x too far out and the shot showed a hover that had
not happened. The lesson is the harness's own: **check the tool before believing
the frame.**

## 6. Left open

1. **No hover ring on the tile.** On desktop the cursor is the only thing tying
   the line to the tile it describes while a *different* tile is selected. A 1px
   pale outline would close that, at the cost of a fifth tile treatment on a
   surface that already carries four. Left out; re-judge it if anyone reports
   reading the wrong line.
2. **The target does not announce itself.** It could brighten for the first few
   seconds of a run and settle. Not built: the owner's problem is reaching pause,
   not knowing it exists, and the onboarding line already owns the opening.
3. **Top left rather than top right.** The argument is the launcher's title
   corner and it is an argument about identity, not ergonomics — both top corners
   are equally reachable in a two-handed landscape grip. Cheap to flip if a
   player says otherwise.
4. **The strip now costs six to eight `Tab` stops.** Tiles come before the
   light slider in tree order, so tabbing forward from `leave` wraps onto the
   strip and walks it before reaching anything else. That is the price of making
   eighteen lines reachable without a mouse, and it is paid only by a player who
   tabs; `Esc` and the buttons are where they were.
5. **Tapping a gap between tiles does nothing**, because the 20px separation
   belongs to no tile. It is 1.5mm on a phone and a mis-tap costs nothing, so it
   is not worth widening the targets and losing the gap that makes a mis-tap
   cheap — but it is the reason a thumb sometimes has to try twice.
