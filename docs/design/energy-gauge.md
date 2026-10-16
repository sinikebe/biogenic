# The energy gauge

The owner, 2026-10-15:

> Also, it's time to have a precise UI for energy (storage, consumption rate) with
> a gauge we can visually read easily. There will be, later, other ui components
> like this one. Just so you know and don't use up all screen estate

This is the first readout on the playfield. Until now the HUD was the body itself
(diegetic-hud.md §1, decision 0: "no panel, no corner, no bar"), and hunger was
read off the beat and the body (hunger.md). That stays as it was. The gauge is an
addition beside it, for the number the body cannot give: how much is left, and how
fast it is going.

## 1. What it says

- **Storage**: how much is in the tank, of how much it holds. `67 / 72`.
- **Consumption rate**: how much goes out a second. `−1.4/s`.
- **The next five seconds**, on the bar itself: the end of the fill that the rate
  will take in five seconds, struck through with stripes. At a glance, a long
  striped end means *this is going fast*. A bar that is all stripes means *empty
  within five seconds*.
- **Once the tank is empty, the grace**: the bar turns red, a red strip shrinks with
  the grace, and the rate gives way to `7 s left`.

**The unit is the one every cost is already paid in**: seconds of rest, how long a
born cell doing nothing takes to burn as much (energy.md §1.1). A born cell's tank
holds 72 since it doubled (energy.md §9; 36 when the gauge was built), and a cell
at rest burns 1.0 a second. So the gauge agrees with the pause screen's numbers
(`a full tank: 72 s`, `wearing it burns 0.09 s a second`, `each dash burns
2.2 s`). A bigger `vacuole` tank is a bigger second number, and a
`plastid` that makes some of its own is a smaller rate.

## 2. How it looks

### 2.1 Where, and how big

**Top left, in a row after the pause target, at its height.** The pause target is a
56 × 56 slab one launcher margin in (48, 48). The gauge is a 216 × 56 slab 12 px
after it, so the corner reads as one row of chrome. The row is a container
(`Hud/Gauges`, an `HBoxContainer`), and **the next readouts go into it**, each a
gauge of its own beside this one.

That is the whole budget: 56 px of height, on the one edge nothing else uses. The
two bottom corners are the thumbs' controls, the middle is the water, and the top
right is the autopilot's switch while it shows. On a 16:9 screen the row has room
for three more gauges this size before it reaches the middle. On a 20:9 phone it
has room for four.

**The slab is the pause target's, filled.** It is built by the same `_well()`, with
fill 0.9 where the pause target has 0.13. A quiet button may let the water show
through it, and a readout may not: at 0.13, and still faintly at 0.72, a cell
passing under the corner drew its outline across the bar and the numbers.

| part | size | where |
| --- | --- | --- |
| slab | 216 × 56, radius 12 | `(116, 48)`, after the pause target |
| mark (a bolt) | 14 × 22 | 12 px in, centred |
| bar | 168 × 10, round ends | 14 px from the top, after the mark |
| numbers | 14 px type | baseline 44: storage left, rate right |

At 2400 × 1080 the canvas is scaled ×1.5, so the bar is 15 device px thick and the
numbers are 21 px.

### 2.2 The next five seconds

The bar's fill is drawn whole in its colour, and **the stretch the rate will take in
the next five seconds is struck through with dark diagonal stripes**. Five seconds
is the window the rate is measured over (§3), so the number and the stripes say the
same five seconds.

The stretch was first drawn fainter instead. At low fill, with all of what was left
inside it, the whole bar went dim at exactly the moment it had to be seen. Stripes
keep the bar bright and say *on its way out*.

### 2.3 Its colours

| it stands at | colour | when |
| --- | --- | --- |
| full | mint, `#66DBB8` | more than a quarter of the tank left |
| low | amber, `#F7B852` | under a quarter: metabolism.gd's `HUNGRY_FROM`, twenty seconds from death, where the beat starts to race and the body to crease (hunger.md §3). It was half a tank before the tank doubled (energy.md §9) |
| out | red, `#F56157` | the tank is empty and the grace is running |

The fill and the bolt take the colour together. Full turns to low over a tenth of
the bar around the quarter, so the colour turns as the warning does, without a hard
step. The colour is never the only signal: the fill's length, the stripes and the
numbers say the same thing.

### 2.4 What changes it

- **A lump that falls off stays a moment**: a stroke of the tail (1.3 of 72), a
  dash, venom. Its part of the bar is drawn pale for a quarter of a second, then
  shrinks away. So each beat of the tail can be seen to cost something. The steady
  drain of being alive leaves nothing behind.
- **A meal glows where it filled**, for 0.7 s.
- **A new life starts on a quiet bar**: a birth or a division clears both, and the
  full tank it starts with does not glow as a meal.

It is shown while the cell lives and the pause screen is shut, as the drawn
controls are: through a division and a pond's still moments, never on the pause
screen, and never dead. It is the same in both views. It says only what the tank
holds, which is a fact about this body, the thing point of view may show
(diegetic-hud.md §3).

## 3. The rate

**What the tank is asked to pay, measured over the last five seconds**:
`metabolism.gd`'s `paying()`. Being alive (upkeep less any income) and everything
paid through `spend` (strokes, turns, a held push, a dash, venom) go into a ring of
twenty quarter-second buckets. A meal is not counted: it comes in, it is not paid.

**Five seconds, so one stroke does not make the number jump.** A born tail beats
every 2.65 s on average, each beat a lump of 1.3. Over a window shorter than two
beats the rate swings by most of a beat between them. Over five, a beat moves it by
about a quarter. Steering harder for a moment still shows inside a breath. A
newborn's first seconds are a rate over what it has lived, not over five.

Nothing reads it but the gauge. The tank is paid exactly as before, and drop_probe's
metabolism check, which holds the node and the static functions to the same hunger,
is untouched.

## 4. Kept generic

`game/normal/gauge.gd` knows a level, a capacity, a rate, a horizon, where *low*
starts and how much grace is left. It draws a mark it is handed. It never says
"energy", "hunger" or "tank". The energy's names, its bolt and its numbers are put
in by `normal_mode.gd`'s `_update_gauges()`, the edge, as CLAUDE.md asks of every
mechanic a later game reuses. A second gauge is one more child of `Hud/Gauges`, one
`setup()` with its own mark and one `read()` a frame.

Its two strings are translated: `−{}/s` and `{} s left`, with French. The numbers are
one decimal under ten and whole from ten on, the decimal kept when it is a zero, so
a number read every frame does not change width as it crosses a whole one.

## 5. Rendered

At 1280 × 720 and 2400 × 1080, in full vision and point of view, on the
thirty-six-second tank it was built on (since the tank doubled it reads `67 / 72`
a few seconds in, and turns amber at a quarter):

- a born cell with a two-copy ping, three quarters full: mint, `27 / 36`, `−1.4/s`,
  the striped end about a quarter of the fill;
- turning flat out from under half: amber, `5.1 / 36`, `−2.2/s`, the whole fill
  striped;
- empty: red, `0.0 / 36`, `7 s left`, the red strip about two thirds across.

## 6. What to watch

- **Is it read?** The bar should be enough at a glance, and the numbers there for
  a player who looks.
- **Do the stripes say "going"** without being explained?
- **Is the corner still quiet enough?** It is the brightest thing in the top left
  now. If it pulls the eye from the water, the levers are the slab's fill and the
  numbers' brightness, not its place.
- **The beat and the gauge together.** Hunger is said by the body, the beat and now
  the bar. If the bar makes the beat redundant, that is worth knowing before the
  next readout comes.
