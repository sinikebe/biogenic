# Placing a gene: a tap chooses, a button writes

The owner, 2026-10-16:

> Double tapping a slot to put a gene can lead to mistakes. remove that. I think
> you can use a bit more of the screen to display all gene slots instead of having
> to enter a sub screen as well.

Status: **built**. This page is the rule as it stands. It replaces, wherever they
say otherwise:
- the two taps of dna-body.md §6, dna-slots-ux.md §3, moving-a-gene.md §3.7 and
  beam-levels.md §8.3;
- the slot view of gene-sockets.md §5.2;
- the four-second lapse and the 300 ms guard everywhere they appear.

The older specs keep their reasoning, which is still how the screen got here.

---

## 0. In one place

1. **A tap on a slot only chooses it.** The choice can be undone at no cost: tap
   another slot, the tray, or the same slot again, and nothing is written.
2. **A button under the figure does the writing, and it says what it writes**:
   `place swim here`, `write venom over eat`, `add a copy to venom`,
   `put venom in sting's slot`. It stands where the verb line was, only while the
   chosen slot has something to do, and goes as soon as it has done it.
3. **A gene's own slots are on the figure**: a small chip each, off the right end of
   its gene's chip, threaded to its helix. There is no separate view to open. Every
   slot the body and its genes have is on one screen, and while a gene waits,
   everywhere it can go is lit at once.
4. **A drag still places in one gesture where nothing is lost**: a waiting gene let
   go over an empty slot, or over an empty slot of a gene's own, lands there. Let go
   over a gene, it only chooses that slot, and the button writes.
5. **The fork works the same way**: the button opens the two ways
   (`choose how beam grows`), a tap reads a way, and the button takes it
   (`choose fill · for good`).

---

## 1. A tap chooses; the button writes

**Why a button and not something else.** Two taps on the same chip was the confirm,
with a 300 ms guard between them. On a phone a thumb that lands twice, or a tap that
reaches the chip as both a touch and the mouse click Godot emulates from it, is two
taps. The guard narrowed that and could not close it. A drag-only placement was the
other candidate. It keeps one gesture for the empty slot, which it already had (§4),
but it cannot confirm writing over a gene: the drop is the only moment there is, and
it lands under the finger, wherever that is. A button:
- **is somewhere else.** It sits under the lines, at least 76 px below the lowest chip
  at 1280x720, so no second landing of the same thumb reaches it;
- **says what it does.** A confirm that names both genes (`write venom over eat`) is
  read at the one moment it matters, where a second tap said nothing;
- **leaves after one press.** Placing spends the gene in hand, so the button goes
  with it, and a second press lands on the verb line, which does nothing.

**The rules:**
- **A tap on a chip chooses it**: a ring slot, a gene's own slot, a way on the fork's
  cards. With a gene in hand that is the arm. With none, it is a reading. A tap on
  the chip already chosen changes nothing, and it does not deselect either, for the
  reason the code gives (a deselected chip keeps Godot's focus ring with nothing
  under it).
- **The button is offered when, and only when, pressing it would do something**:
  - a gene in hand and a slot chosen that takes it;
  - a slot of a gene's own that takes it;
  - nothing in hand and a slot whose fork is open;
  - a way chosen on the cards.

  Otherwise the row is the verb line it always was: `tap a slot · your daughters may
  wear it`, `swim works only outside`, `venom has three copies already`,
  `this slot takes burn`, `drag it to another slot`.
- **It asks the genome again when pressed** ([method _on_place_pressed]): a button
  that said one thing and did another would be the worst control on the screen. In
  a pond the queue can change under the open menu, and then it writes nothing and
  the screen catches up.
- **Nothing is offered while anything is in the air.** During a drag the row is the
  verb line, reporting the gesture.
- **A choice no longer lapses.** Arming used to lapse after four seconds, so that a
  slot left armed was not a trap one stray tap from writing. Now nothing but the
  button writes, so a choice left standing is a player reading, and the lapse would
  only have taken the button away from under a thumb on its way to it.
- **A hovered chip is read, and the button keeps naming the chosen one.** Desktop
  only. The button names its genes, so it is never ambiguous about which.
- **After placing, the slot stays chosen as a receipt**, unless another gene waits.
  Then that gene goes in hand and nothing is chosen. The button must never be
  offered for a slot the player did not choose for the gene now in hand.
- **The keyboard**: `Enter` on the chosen chip does what the button says. A key
  press is one press, never a doubled touch, so the keyboard keeps its confirm on
  the chip. The button takes no focus: it comes and goes with the choice, and a
  control the keyboard stood on that then vanished would strand it.

**The look.** The camera toggle's slab, 48 tall for the touch rule and at least 232
wide (`resume`'s width), with its words in 16 px in the column's teal for *this
responds* (`PLACE_TINT`). It grows down into the canvas under the lines, as the
numbers do (gene-stats.md §3.1), so nothing above it moves when it appears.
- With the numbers off, the lines end at 662 of 720.
- With them on, at 708.

---

## 2. A gene's own slots, on the figure

**The chip.** `SOCKET_SIZE` 56 x 56, which is chip height and over the 48 px touch
rule. It holds:
- one lobe of helix, the ring chip's own lobe, centred;
- its rider's copies as rungs, worn or carried, as on the ring;
- its word under it at the ring's 14 px: the rider's, or, faint, what the slot
  takes (`venom`, `burn`).

A gene's slot is not a slot of the body, so it is one lobe and not three. Its copies
are rungs alone, because three pips beside `venom` would not fit in 56 px, and the
lines under the figure say the count when the slot is read.

**The stem.** A short line from the end of its gene's helix, or of the slot before
it, to its lobe, so a gene and its slots read as one strand that branches. While a
gene waits:
- **a slot that takes it** lights its stem in that gene's hue, tints its lens, and
  shows the gene's word as it would land (`venom`);
- **a slot that does not** drops its weave and word to the refused ink.

So the owner's earlier rule -- *"It must be easy to see which slots are valid for a
gene we're about to equip"* (gene-sockets.md) -- now holds across the whole figure
at once, body and genes alike.

**Chosen**, its lens fills and it previews the gene landing: rungs in the incoming
hue, at the copies it waited with. The lines read it:
- the line names what is in it, or what it takes, then the slot's line
  (`venom · every bite leaves it too`);
- the row under says `nothing in this slot yet`, or what a rider written over loses,
  or `a daughter wears it whenever she wears eat`;
- the body lights its gene's arc.

**Where.** Off the right end of the gene's chip, level with it, `SOCKET_GAP` 4 px
apart, outside slots only: no gene with slots of its own can be worn inside.
**The ring's columns move apart to make room** (figure.gd's `_lay_out`):
- the column pitch is the chip, the widest gene's slots and `RING_GAP` 12 px, never
  less than the old 150;
- with one slot per gene that is **168**, and the figure's box is **516 x 372**,
  from 420;
- the box keeps the old 12 px margins and ends where the right column's slots do,
  so the body is not at its middle: the chips are, and they are what the tray and
  the lines are centred over;
- the fork's cards are centred in the wider box.

Nothing else on the column moves: the genome column was already 560 wide.

**How many it makes room for** is the most any gene in the catalogue has
(`SOCKETS_DRAWN`), read when the figure lays itself out, so a gene with more slots
widens the figure without anyone remembering to.

**The cells screen** (cells-ux.md §3.3) draws them too, read-only, from the same
function.

**The keyboard:**
- `→` from a chip goes on to its first slot, along its slots, and on from the last
  to where the chip's own `→` went;
- `←` comes back the same way, into the last slot of the chip to the left;
- `↑` and `↓` from a slot go where its chip's do;
- Tab goes round clockwise as before, each chip's slots after it.

**A drag:**
- a waiting gene carried out of the tray can be let go over a gene's slot that takes
  it: into an empty one it is put there (`let go to put venom in sting's slot`);
- over a rider it only chooses the slot (`let go, then press below to write venom
  over burn`);
- a gene moved off the ring never lands in a gene's slot;
- a slot's chip never starts a drag: what is in it goes where its gene goes
  (gene-sockets.md §4);
- while its gene is in the air, its slots draw nothing.

---

## 3. What went

- The slot view: its scene node, its `‹ genome` way back, its keys and Back's step
  out of it.
- The second tap everywhere: on a ring slot, on a slot of a gene's own, and on a
  fork's card. Also the priming on the press and landing on the lift that made the
  second tap safe from a drag, which only existed because the press was ambiguous.
- The 300 ms guard and the four-second lapse, on the slots and on the cards.
- The ports at a chip's right end: the slots' own chips replace them.
- Fifteen lines of words, and ten new ones (§4).

---

## 4. Words

The button's, `PLACE_*`: `place %s here`, `write %s over %s`, `add a copy to %s`,
`put %s in %s's slot`, `choose how %s grows`, `choose %s · for good`.

The verb line's new ones: `let go, then press below to write %s over %s`,
`let go, then press below to add a copy to %s`, `let go to put %s in %s's slot`,
`tap a way to read it`.

French in `fr.po`, rendered at 2400x1080. The longest,
`mettre venin dans l'emplacement de mange`, makes a button 380 canvas px wide of
the 560 the column gives it.

---

## 5. What to watch when playing

- **Whether the button is found.** It replaces the line a player used to read, in the
  same place. If a first placement stalls at a chosen slot, the button needs to be
  louder: the lever is its slab (`_slab(0.2)`) and `PLACE_TINT`.
- **Whether the top row is too busy.** With a slot beside the mouth and the sting,
  the top row is six chips across. If the word of a gene's slot reads as part of its
  gene's (`eat ••• venom`), the lever is `SOCKET_GAP`, or a dimmer word for an empty
  slot.
- **A second batch of gene slots** (gene-sockets.md §3) would give the mouth, the
  sting and the tail two each:
  - the pitch would go to 228 and the box to 696;
  - that is 64 px over the 632 the pause screen leaves it at 1280x720 (gene_probe's
    `FIGURE_BESIDE`);
  - the gene probe fails it until the batch makes room: a narrower slot chip, or a
    narrower side column at that width.

---

## 6. Checks

**The gene probe**: room on the pause figure, which now covers a gene's own slots.
- the figure makes room for the widest gene's slots;
- every slot's chip is inside the box, and no chip or slot overlaps another;
- the box fits beside the side column at 1280 wide.

The shipped seats are pinned by column, since the pitch now follows the catalogue.

**Rendered and judged at both shapes**, through the input path a phone uses
(`--touch=`, `--press=`, `--slide=`, `--lift=`):
- a toxin in hand, every slot lit or refused;
- a gene's slot tapped: the preview and `put venom in eat's slot`;
- the button pressed: venom in the mouth's slot, the tray empty, the receipt;
- a ring slot tapped twice inside 100 ms: chosen, nothing written,
  `write venom over swim` waiting;
- the button pressed: venom over the tail, and the tail's own slot gone with it;
- a toxin dragged onto the sting's slot: `let go to put venom in sting's slot`, and
  let go, the sting's barbs on the body;
- a fork: `choose how beam grows`, the cards, a way tapped twice and nothing taken,
  `choose fill · for good`, taken;
- French at 2400x1080.
