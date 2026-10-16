# Venom rides: a toxin goes inside, or in a gene's slot

The owner, 2026-10-16:

> Eat + toxin does the same as toxin outside. Remove toxin outside. Toxin can only
> be in eat or inside body.

Status: **built**. This page is the rule as it stands. Wherever they say a toxin can
go on a slot round the body, it replaces:
- dna-slots.md §3 and §5 (venom at the front, on a side, at the stern);
- dna-slots-ux.md §2 and §3;
- the examples of placing.md that write venom over a gene on the ring.

The older specs keep their reasoning, which is still how the toxin got here.

---

## 0. In one place

1. **A toxin has two places**:
   - **inside the body**, where it is poison, as before;
   - **a gene's own slot that takes it**, where it is venom: the mouth's, so every
     bite leaves it too (gene-sockets.md §3).

   The seven slots round the body refuse it. Venom is never worn on the body.
2. **Why:** a toxin in the mouth's slot already did what venom at the front did.
   Venom on a side or at the stern, which a biter took in its own mouth, was the
   one thing the ring gave a toxin that the slots did not, and it goes with the
   ring.
3. **The sting's slot still takes venom**, for its dart. The owner's words name
   the mouth, but the sting's slot was the owner's own example the day before
   (gene-sockets.md, the owner's quote). It is in the decision table that came
   with this change. Taking it out is one line, the sting's `takes`.
4. **A meal of a toxin still waits in the tray.** While it waits, everywhere it can
   go is lit at once: the inside, and every gene's slot that takes it. Tapped onto
   a slot round the body, it says `toxin goes inside, or in a lit gene's slot`.
5. **A save from before moves its venom**:
   - venom worn round the body goes into the first gene's slot that takes it (the
     mouth's, then the sting's), at its copies, up to three;
   - where no gene has room, it is let go;
   - this holds in the DNA and on the body, for the player and for every water
     cell in a kept drop.
6. **The water:**
   - the floor gives the toxin back through a peer, and its coin chooses between
     poison inside and venom in the peer's mouth's slot. A peer with no slot that
     takes it gets poison;
   - drift brings the toxin as poison or not at all: with the inside full, the
     next kind is tried;
   - venom in a mouth's slot counts as carrying the toxin, for the floor's census.
7. **The shared pond:**
   - venom's side and stern numbers were rules the host's referee copied, so
     `Wire.RULES` moved;
   - a player on the old content cannot play with one on the new until the older
     one updates;
   - no message changed, so `Wire.PROTOCOL` did not move.

---

## 1. What went

- **Venom's own numbers**: `VENOM_STACKS_BY_TIER` and the `venom_stacks` row. A
  bite's venom is the mouth's slot's `bite_dose` and a dart's is the sting's
  `sting_dose`, which were already there.
- **The ring's venom**: `VENOM_ARC_DEG` and `VENOM_SIDES` in cell.gd, the side and
  stern lines, and venom biting back into a biter's mouth (`HOW_STING`, a record
  number that is now never written).
- **Five lines of words**, and one rewritten (§3).

---

## 2. The form

`gene.gd` has a third place, `RIDING`. A form there is never worn on the body and
takes no slot round it. It is what a gene's slot holds. The toxin's venom,
`toxicyst`, is that form. Its key and order are unchanged, so every save and every
gene list still names it.

- `Catalogue.rides_as` prefers a gene's riding form, so a toxin put in a slot is
  written as `toxicyst` whatever form it was eaten as.
- A riding form provides the body nothing. What it gives is its host's slot's
  table, read by the host's mechanic (`Riders.value`).
- Its look moved with it. The mouth's fangs are drawn from the rider in its slot.
  They no longer come from venom worn at the front.

The mechanic stays generic: nothing outside `game/genes/` names the toxin. Any later
gene can have a riding form.

---

## 3. Words

- The arm line, while a toxin waits: `tap a lit slot · poison inside, venom in a
  gene's slot`, from `tap a slot · venom outside, poison inside`.
- A toxin tapped or let go over a slot round the body: `toxin goes inside, or in a
  lit gene's slot`.
- Poison moved out to the ring: `poison works only inside`.

French in `fr.po`. The longest, `appuyez sur un emplacement allumé · poison dedans,
venin dans celui d'un gène`, fits the 560 px row at 14 px.

---

## 4. What to watch when playing

- **Whether a player finds the mouth's slot.** If a first toxin goes inside every
  time, the levers are the arm line and the lit slot's glow (placing.md §2).
- **Whether venom gets rarer in the water.** The floor's coin still puts half its
  toxins in a mouth. Drift no longer brings venom at all. If venomous hunters thin
  out over a long run, the lever is the coin in `_give_back_by_peer`.

Both are balance, which waits for players (`CLAUDE.md`).

---

## 5. Checks

- **The gene probe**: venom only rides. It cannot be posed on the body, it draws no
  numbers of its own, and a water body's venom reaches a bite only through its
  mouth's slot.
- **The drop probe**:
  - placements refuse the ring for a toxin;
  - venom posed round the body moves into a slot, or is let go;
  - ten thousand random operations never leave a riding form on a body;
  - the floor gives venom to a peer's mouth;
  - the floor's census counts it;
  - the seeded runs were recorded again (the toxin's draws moved).
- **The net probe's referee**: the rules without venom's side and stern lines, and
  `Wire.RULES` moved to them.
- **The levels probe**: poison's rows, and none for venom.
- **Rendered at both shapes**: the pause screen with a toxin in hand (the ring dark,
  the inside and the mouth's slot lit), the refusal line over a ring slot, and a
  mouth with venom in its slot wearing its fangs.
