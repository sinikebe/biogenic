# A gene's own slots

The owner, in the gene pass (2026-10-15):

> Now, a gene slot pass. For instance, sting could have an extra slot allowing to
> combine another gene to it. Poison gene could be added to this slot so the sting
> gets poisonous.

and, on the table of pairings that followed:

> No 7 yet.
>
> An equipped gene opens a new slot view. Each gene will have specific number of
> slots. It must be easy to see which slots are valid for a gene we're about to
> equip
>
> It only changes the main gene
>
> Yes for the gene's file

Status: **first batch built** (§3: the slots, their screen and three pairings); the
second batch is §3's other rows. This page is the rule, the screen, the starting
numbers and what to watch when playing.

---

## 0. In one place

1. **Some genes have slots of their own.** The gene's file says how many and what
   each one takes. A gene in one of them changes that gene and nothing else.
2. **On the pause screen, a placed gene with slots opens a view of them.** The view
   shows the gene, its slots, what is in each and what each one takes.
3. **While a gene waits to be placed, everywhere it can go is lit.** It shows as a
   faint gene on every empty body slot that takes it, and on every gene's slot that
   takes it. What cannot take it stays dark.
4. **A slot's gene is a placement like any other.** It is written to the DNA and
   reaches the daughters, and the body wears it from birth. Writing over a gene
   takes the genes in its slots with it.
5. **The water's cells grow them too.** A meal that finds no room on the body goes
   into a slot that takes it.
6. **The shared pond moved.** The wire carries the slots (`Wire.PROTOCOL` 9) and the
   rules carry what each one gives (`Wire.RULES`), so this content and the content
   before cannot share a pond until both update.

---

## 1. Words

- **Slot**, to the player: a place a gene goes. The body has its slots
  (`dna-slots.md`); now a gene can have slots too. The screen says "slot" for both,
  and context tells them apart: the body's ring, or one gene's view.
- **Socket**, in the code: one of a gene's own slots, so that a slot index never
  means two things in one function. `gene.gd`'s `sockets`.
- **Host**: the gene a socket belongs to. **Rider**: the gene in it.

---

## 2. What a gene's file says

```gdscript
sockets = [
	{"takes": [&"toxin"], "gives": {&"sting_dose": [0.0, 1.0, 2.0, 3.0]}},
]
```

- **One entry per slot**, in the order the view draws them. No entry means no slots,
  which is every gene that is not a host.
- **`takes`**: the organs that fit, by organ name, so every strain of the toxin fits
  a slot that takes the toxin. A gene of forms rides as its outside form: a toxin in
  a slot is venom (`toxicyst`).
- **`gives`**: what the rider gives its host, as a table by the rider's copies,
  index 0 being no rider (as `provides` reads, `gene.gd`). The host's mechanic reads
  it by name and knows no rider: the sting asks for its `sting_dose`, never for a
  toxin.
- **It is the organ's own**, as `declares` is: a variant keeps its organ's slots.
- **Its words** are the host file's `SOCKET_EXPLAINS`, one line per slot, said
  after the slot's word: `venom · every sting leaves it too`.

The gene probe fails a slot that takes no live organ, takes its own organ, gives a
number nothing reads, gives a table of the wrong length, or has no words.

---

## 3. The pairings

| # | Host + rider | What it gives | Batch |
|---|---|---|---|
| 1 | **sting** (`trichocyst`) + **toxin** | every sting leaves the toxin's dose too: `sting_dose` 1 / 2 / 3 stacks, the dose its strain delivers (harm today) | **first** |
| 2 | sting + **cling** (`haptonema`) | the stung body is held a moment | second |
| 3 | **eat** (`cytostome`) + **toxin** | every bite leaves the toxin's dose, as venom at the front does: `bite_dose` 1 / 2 / 3 stacks | **first** |
| 4 | eat + **dash** (`myoneme`) | a dash that ends on prey bites at once | second |
| 5 | cling + eat | what you hold slowly feeds you | second |
| 6 | cling + toxin | what you hold takes the dose while you hold it | second |
| 7 | beam + toxin | — | **not yet** (the owner, 2026-10-15) |
| 8 | beam / ping + **smell** (`chemocyte`) | marks and echoes say what each thing is | second |
| 9 | **swim** (`flagellum`) + toxin | a trail of toxin behind you | second |
| 10 | **swim**, **push** (`axoneme`), **dash** + **burn** (`crista`) | that gene costs less hunger: `effort` × 0.70 / 0.55 / 0.40 | **first** |

So after the first batch a gene's slots are: sting 1 (toxin), eat 1 (toxin), swim 1
(burn), push 1 (burn), dash 1 (burn). The second batch adds sting's second (cling),
eat's second (dash), cling's two (eat, toxin), the beam's and the ping's one (smell),
and swim's second (toxin).

### 3.1 The first batch's starting numbers

- **`sting_dose` 1 / 2 / 3 stacks** by the rider's copies: the venom a bite at the
  front leaves at the same copies (`toxin.gd`'s `VENOM_STACKS_BY_TIER`). A sting is a
  bite you did not have to aim, so it leaves what a bite leaves. Felt by size, as
  every dose is (`Doses.felt`).
- **`bite_dose` 1 / 2 / 3 stacks**: the same table, for the same reason. Venom in the
  mouth's slot is venom at the front without spending a body slot on it.
- **`effort` × 0.70 / 0.55 / 0.40** on what that one gene costs to use: a tail's
  strokes, a push's thrust, a dash's price. The crista on the body takes 12 / 23 /
  34 % off everything (`BURN_BY_TIER`); in one gene's slot it takes more off less.
  Burn on the body still multiplies on top.

Balance waits for players: these are starting values, and §8 says what to watch.

---

## 4. The rules of a rider

- **It changes its host and nothing else.** A rider provides no stat to the body,
  has no control and no instinct, and its organ is not drawn on the skin. A burn in
  the tail's slot does nothing to the mouth.
- **Its copies are its strength.** It earns no levels.
- **It is worn when its host is.** A daughter who wears the sting wears what is in
  its slots; one whose sting did not express wears neither.
- **It is placed like any gene** (§5), into the DNA, for the daughters. The body
  wears what it was born with, as it does everywhere else.
- **Its host takes it along.** A gene moved to another body slot keeps its slots'
  genes. A gene written over loses them, as it loses itself.
- **One gene can be on the body and in a slot at once**, each with its own copies:
  venom at the front and venom in the sting are two genes.
- **It costs what any gene costs**: nothing for its first copy and
  `UPKEEP_PER_TIER` for each one after (`genome.gd`'s `upkeep_of`).
- **A meal waits when a slot can take it.** Eating a gene you carry used to add a
  copy at once. Now, if one of your genes has a slot that takes it, and that slot is
  empty or holds it below three copies, the meal waits to be placed like a new gene,
  so the choice is yours. Left to lapse, it adds the copy to the body's gene, as it
  always did. Into a slot it goes only by your hand.
- **A daughter inherits her mother's slots exactly.** Her one mutation does not touch
  them yet: a drift that replaces a host takes its riders, as a write does.
- **The water's cells** (`food.gd`) place a meal the old way first: a copy more of a
  gene they carry, or a new gene in a free body slot. **Only a meal with no room on
  the body** goes into the first slot that takes it, empty or holding it below three
  copies, its hosts taken in the genes' order. It used to be lost. So riders appear
  in the water's full-grown lineages first, and a toxin goes into the mouth's slot
  before the sting's: every cell has a mouth.

---

## 5. The screen

### 5.1 The ring

- **A chip whose gene has slots shows them**: one small port per slot at the chip's
  right end, hollow for an empty slot, filled in its rider's hue.
- **With a gene in hand, everywhere it can go is lit**:
  - every empty body slot that takes it draws the gene faint, as the toxin's
    `venom` and `poison` ghosts always did, now for every gene;
  - every port that takes it glows in its hue.
  
  A slot with nothing lit cannot take it.
- **A chip with slots opens on its second tap**, with nothing in hand or with a gene
  in hand that one of its slots takes. The first tap reads it, and the line under the
  figure says `tap again to open sting's slots`, with `· venom fits` when the gene
  in hand fits. With a gene in hand that none of its slots takes, the second tap
  writes over it, as it always did.
- **A drag from the tray onto a chip whose slots take the gene opens them**, with
  the slot that takes it armed.

### 5.2 The slot view

It replaces the figure in the same 420 × 372, as the fork's cards do:

- **The host at the top**, its chip, with its organ drawn large above the word. With
  a gene in hand that is not the host, two taps on it write over it, as on the ring.
- **Its slots in a row below**, one chip each, threaded to the host. An empty one
  draws what it takes, faint: `venom`, `burn`. A full one draws its rider, word and
  copies.
- **With a gene in hand**, the slots that take it are lit, as on the ring, and the
  others are drawn refused.
- **Taps**: one reads a slot or arms it, two place (`tap again to put venom in
  sting's slot`; `tap again for one more copy`; `tap again to put venom over burn`).
  The 300 ms guard and the four-second arm hold as they do on the ring.
- **Closing**: a `‹ back` chip at the top left, `Esc`, or resume. Placing does not
  close it, so the player sees the gene land.
- **The lines under it** read the slot: its word in its rider's hue, or its takes
  word for an empty one, then the slot's line.
- **Keys**: `←` and `→` walk the host and the slots; `Enter` taps.

### 5.3 In the water

**A host with riders wears a bead per rider** at its organ's root, inside the skin,
in the rider's hue. A water cell's sting carrying venom can be seen before it is
touched. A body's organs are drawn as they always were.

---

## 6. The shared pond

- **The wire carries the riders** in PERSON (a guest's worn riders), SISTER (her
  DNA's) and GENOME (a water body's worn riders, for drawing): `u8 hosts, (name,
  u8 sockets, (name, u8 copies)*)*`, a host at most once, at most `SOCKETS_MAX`
  (4) sockets. A format change, so **`Wire.PROTOCOL` moves to 9**.
- **The referee judges riders as it judges the worn body.** Each host is worn, each
  socket is one the host declares, each rider fits, and copies are 1 to 3. They are
  fixed for a life and may change only at a new body.
- **`rules.gd` writes every host's slots and gifts.** A sting's dose and a bite's
  dose are contact rules the host decides by, so **`Wire.RULES` moves**.
- **Only the host doses.** A mirror draws riders and never acts on them, as it
  never stings.

---

## 7. Saves and the replay

- The player's genome keeps `riders` (the DNA's) and `body_riders` (the body's),
  host to slots by name. A file without them has none.
- A daughter kept for the choosing beat keeps her riders. The drop's file keeps each
  body's worn and DNA riders.
- The replay records both with the genome, and plays them back.
- A rider or host this build does not know is kept by name and does nothing, as an
  unknown gene is.

---

## 8. What to watch when playing

- **Whether a poison sting is worth a slot of the sting's.** If venom on the sting
  feels weak, the lever is `sting_dose`. If it feels like the only build, the lever
  is the same table, not a cap.
- **Whether the mouth's venom makes the front slot's venom pointless.** It is the
  same dose for no body slot. If nobody puts venom at the front any more, either
  table can move.
- **Whether meals waiting for a slot feel like a chore.** Every eaten copy of a gene
  a slot takes now waits. If that is too many decisions, the rule can narrow to an
  empty slot only.
- **Whether the water's riders show up at all.** They need a full body first (§4).
  If the water never grows them, the levers are that rule's order and the water's
  rarity of toxins and crista. **And whether venomous mouths take over**: a full
  cell's toxin goes to its mouth before its sting, so venom bites may become common
  in old lineages. The lever is the order the hosts are tried in.

---

## 9. Checks

- **The gene probe**: every socket's shape; a rider's stats never reach the body; a
  rider's gifts read off its copies; placing, writing over a host, moving a host,
  saving and loading, a division, the lapse of a waiting copy, and upkeep with
  riders.
- **The drop probe**: a sting with venom in its slot doses what it stings, a sting
  without one does not; a mouth with venom in its slot doses what it bites; a burn in
  the tail's slot makes its strokes cheaper and nothing else; a full water cell's
  meal goes into a slot.
- **The net probe**: the riders round-trip on PERSON, SISTER and GENOME; the referee
  refuses a rider on a host not worn, on a socket not declared, or that does not fit;
  the rules pin.
- **Rendered and judged at both shapes**: the ring with a gene in hand and its lit
  slots and ports, the slot view empty, armed and full, and a cell in the water with
  a rider's bead.
