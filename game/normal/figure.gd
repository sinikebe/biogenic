extends RefCounted
## **The figure: a cell's genome, drawn from plain values** (docs/design/cells.md
## §6.2, phase 1). The body and its tethers, the eight chips round it, the tray of
## what waits, and the words under it -- the pause screen's genome group -- as
## static functions of what a cell is: its DNA and its body, their layouts, its
## levels and its waiting genes, its radius, its loads and its slack. Nothing here
## keeps state or takes input. The pause screen keeps both and calls in, and a
## screen that shows a cell nobody is playing calls the same functions with the
## values a file keeps (cells-ux.md §3.3), so a genome has one drawing and one set
## of words, not two that drift apart.
##
## No class_name, for the reason signal_bus.gd gives: a content pack mounts over
## an older binary, and a global class a pack introduces is not in that binary's
## class list. Preload it by path.
#
# ---------------------------------------------------------------------------
# The body and its slots. docs/design/dna-body.md.
#
# **The owner could not read which part of the body an arrow meant, so the
# screen draws the body and puts each slot beside the part it is.** The slot is
# the arc, and the arc is a place on a body the player has been looking at for
# the whole run -- so reading a slot is pointing at it rather than decoding a
# bearing. The figure is the water's own drawing, `Cilia.draw_cell`, nose up and
# still: no second drawing of a cell exists anywhere, and this is not one. Every
# channel the strand carried has a place, and most of them are more literal
# than the place they had:
#
#   which arc         where the chip sits on the 3 x 3 ring, and the faint
#                     tether from it to its arc on the skin
#   the plain word    under the chip's own three-lobe piece of helix
#   the copies        rungs, as on the strand: they are the picture -- and
#                     three pips after the word, which are the reading: a
#                     disc for a copy this body wears, a ring for a copy only
#                     the DNA carries, a dot for room to grow
#   the level         a numeral in the helix's third lobe, for a gene that
#                     levels; its strands part while its fork waits
#                     (beam-levels.md §8)
#   the two registers the drawing is the body and the chips are the DNA; where
#                     the two disagree at an arc, the body names what it wears
#   the selection     the lens fills, the word goes loud, and the arc lights on
#                     the skin -- the owner's sentence answered on the body
#   waiting genes     a tray above the figure, soonest to lapse first, one of
#                     them in hand; the two taps place it, as they always have
#
# **A launcher-themed surface, not the membrane aesthetic.** The membrane is
# what the cell feels; this is what the player consults. It lives on pause
# because pause already has widgets, already has the house style and is already
# reachable by a gesture the player knows.
# ---------------------------------------------------------------------------

const Cilia := preload("res://game/vision/cilia.gd")
const CellBody := preload("res://game/normal/cell.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const GeneStats := preload("res://game/normal/gene_stats.gd")
const Readout := preload("res://game/mechanics/readout.gd")
const Progression := preload("res://game/mechanics/progression.gd")
const Drops := preload("res://game/normal/drops.gd")

## The figure's own box, and where the body sits in it. **Set in code, as the
## choosing screen's column is**: every seat below is measured from
## [constant FIGURE_AT], and a `.tscn` cannot add. The scene carries the same
## size so the tree reads right in an editor; this is what binds.
const FIGURE_SIZE := Vector2(420.0, 372.0)
const FIGURE_AT := Vector2(210.0, 170.0)
## **A fixed radius, not the cell's.** Drawn at the cell's own size the ring of
## slots would move between two pauses as the body grew, and growth is already
## said by the slots that light up. Sixty is what the worst body the game can
## make -- every born organ and four earned ones at level 3 -- leaves room
## around: the mouth's bow clears the nose row by 9 px, the flank oars by 17,
## the tail by 21 (dna-body.md §2).
const FIGURE_R := 60.0
## A mirror is read, so it is drawn nearly whole: quieter than the chips beside
## it, and far louder than the water behind the scrim.
const FIGURE_FADE := 0.85
## One slot, and the whole of its touch target: 144 x 84 device px at
## 2400x1080. Neighbours are 54 px apart across and 82 and 112 down.
const SLOT_SIZE := Vector2(96.0, 56.0)
## Chip centres from the body's centre, by slot index. **A 3 x 3 ring, not a
## circle at true bearings**: words are horizontal, rows and columns give the
## arrow keys a meaning, and every chip still sits within 5.3 degrees of its
## arc's true bearing -- the forward diagonals at 47.4 against 42.1, the rear
## ones at 138.2 against 133.3, the flank at 90 against 92.5.
##
## **There is no port-flank seat, and the empty cell says so.** Slot 1 is the
## flank pair: the cirrus wears both flanks, anything else the starboard one
## (cilia.gd). The hole is truthful, and it has a job: see normal_mode.gd's
## `_light_panel`.
const SLOT_SEAT: Array[Vector2] = [
	Vector2(0.0, -138.0),     # 0 nose
	Vector2(150.0, 0.0),      # 1 starboard flank
	Vector2(0.0, 168.0),      # 2 tail
	Vector2(150.0, -138.0),   # 3 forward starboard
	Vector2(-150.0, -138.0),  # 4 forward port
	Vector2(150.0, 168.0),    # 5 rear starboard
	Vector2(-150.0, 168.0),   # 6 rear port
	# **7, the inside, on the body itself** (docs/design/dna-slots-ux.md §3.1):
	# 6 px aft of its centre. The ring round the body is outside and the chip in
	# it is inside, so the figure says the rule without a word. Not in the empty
	# port-flank cell: that is where full vision's own ghost lands, and a chip
	# there would read as a place on the skin.
	Vector2(0.0, 6.0),
]

## **A tether per live slot**, from the chip's edge to the middle of its arc on
## the skin, drawn under the body so the body wins wherever the two cross. It is
## what makes a diagonal exact -- rendered without, a corner chip is only an
## approximation of an arc -- and it is the line the body's own word sits on
## (dna-body.md §4). A thread and not a leader line: 1.2 px at 0.16, in the
## slot's hue, and bowed, because a ruled line would be the one piece of chart
## furniture on a surface that has none.
const TETHER_WIDTH := 1.2
const TETHER_ALPHA := 0.16
const TETHER_BOW := 0.06
## How far off the skin a tether stops, and how far inside the chip's box it
## starts, so it ends clear of the fringe and begins clear of the chip's word.
const TETHER_LIFT := 4.0
const TETHER_INSET := Vector2(10.0, 4.0)
## **The part being read lights up on the body**: the arc of the selected,
## hovered, armed or drop-target slot, traced on the skin in the hue of whatever
## would be there -- the gene in hand while a slot is armed, the travelling gene
## while one is dragged. The owner's sentence, answered on the body itself.
const ARC_MARK_WIDTH := 3.0
const ARC_MARK_LIFT := 5.0
const ARC_MARK_ALPHA := 0.85
const ARC_MARK_STEPS := 12
## **The inside, lit** (dna-slots-ux.md §3.1): read, hovered, armed or a drop
## target, the inside slot lights the whole inside -- a ring along the ovoid at
## this share of the radius, in the hue of what is or would be there. Every
## outside slot lights its arc; the inside has none.
const INSIDE_MARK_AT := 0.88
const INSIDE_MARK_STEPS := 64
const INSIDE_MARK_WIDTH := 2.0
const INSIDE_MARK_ALPHA := 0.55
## **The inside chip's window**: an ellipse of the base colour under it, so its
## weave and its word read over the nucleus and a stain. 5.1:1 against the
## word's ground with it, 3.7:1 without. An ellipse echoes the body round it and
## has no edge to read as a button.
const INSIDE_BACK := Vector2(50.0, 29.0)
const INSIDE_BACK_STEPS := 48
const INSIDE_BACK_TINT := Color(0.023, 0.055, 0.05, 0.62)
## **A refusal, drawn**: the slot that would refuse keeps no lens and its weave
## falls to this. The line says why.
const REFUSED_INK := 0.45
## **A tap that adds a copy elsewhere** keeps the tapped chip as it is, its lens
## only a trace of the selection: the copy lands on the target, which is lit.
const RAISE_TRACE := 0.35
## **What a toxin would become, before it lands** (dna-slots-ux.md §3.2): while
## one is in hand, every empty live slot it could be written into carries the
## form it would make there -- `venom` round the body, `poison` in it -- as its
## word and the hand's copies in ring pips, no rungs, this quiet. The rule is on
## the figure before the line says it. A slot whose form is carried shows
## nothing: a tap there adds a copy where that form already is, and says so when
## armed.
const GHOST_INK := 0.42
## The same, under a drag: the form the toxin in the air would land as, on the
## empty slot under the finger. Louder, because it is the one slot being asked.
const LAND_INK := 0.75
## **Where the body wears a different organ from the gene its slot now carries,
## the body names it**: that organ's own word, in its own hue, on the tether
## this far out from the skin. The word is needed and a render proved it -- a
## newborn whose forward-starboard slot holds `sting` while her body wears
## `beam` there draws two violet, three-stroke organs, and without the word the
## figure cannot say which one that is (dna-body.md §4). `moving-a-gene.md`
## §2.3's rule, a word only where the two registers disagree, moved from a
## second strand onto the body it describes.
const DISSENT_ALONG := 0.56
const DISSENT_SIZE := 12
const DISSENT_ALPHA := 0.92

## A slot's own piece of helix, inside its 96 x 56 box: three lobes of 28 px,
## from x 6 to 90, the middle one the slot. **An odd count, for the strand's
## reason** -- it begins and ends at a crossing and is widest in the middle, so
## the rungs sit where the backbones are furthest apart. 28 against 22 of swing
## is a 1.27:1 lens, between the choosing screen's 1.33 and the old strand's
## 0.89: it still reads as DNA at a third of the strand's height.
const CHIP_LOBE := 28.0
const CHIP_LOBES := 3
const CHIP_X := 6.0
const CHIP_MID := 19.0
const CHIP_AMP := 11.0
## The word's baseline, and its size -- one up from the strand's 13, because a
## chip is read on its own rather than along a row of neighbours.
const CHIP_BASE := 50.0
const CHIP_WORD := 14
## **The copies are three pips**, after the word, at its x-height. Built three
## ways on one frame (dna-body.md §3.1): seats for three rungs inside the helix
## read as grit at a 28 px lobe, and a digit has no scale -- two of what? -- and
## cannot say worn against carried. Three marks are read without counting, the
## scale is on screen, and filled against hollow is diegetic-hud.md §1's
## integrated against held: the same shape meaning the same thing in the water
## and here, which is shape and so survives greyscale. A gene's *level* is a
## different number and never sits in this row (beam-levels.md §8.1).
##
## **The rungs stay.** They are the same count, and they are what makes a slot a
## piece of DNA rather than a label. The rungs are the picture; the pips are the
## reading.
const PIP_R := 3.4
const PIP_PITCH := 10.0
const PIP_GAP := 7.0
const PIP_LIFT := 4.6
const PIP_RING := 1.4
## Room to grow, as a dot too faint to count as a copy -- which is what puts the
## whole scale on screen whatever the copy count is.
const PIP_ROOM_R := 1.6
const PIP_ROOM_ALPHA := 0.30

## **The level, on its slot** (beam-levels.md §8.1): a numeral for a gene that
## levels, which today is only the beam. Every other chip draws what it always
## drew.
##
## **Owner's call 2** (§8.9), answered on 2026-09-29 with the recommended
## option: where it sits. `LOBE`, recommended, puts it inside
## the third lobe of the chip's helix, the one right of the rungs -- empty on
## every chip, crossed by no tether, and truthful, because the level is
## inherited with the gene, which is what the strand draws. `AFTER_PIPS` is the
## built-and-rejected `M03`: `beam ●•• 12` reads as a count of the dots, and
## `venom` with two digits is 101 px on a 96 px chip. `NONE` leaves the level to
## the line under the figure.
enum LevelSeat { LOBE, AFTER_PIPS, NONE }
const LEVEL_SEAT := LevelSeat.LOBE
## The numeral: the Hud's own font at 12 px, and 10 from level 100 up -- about
## eighty hours of use, so a guard rather than a case. Digits are tabular, 7 px
## each at 12, so `99` is 14 px and fits the widest chip the game makes with
## 2.6 px to spare inside the lobe's backbones.
const LEVEL_SIZE := 12
const LEVEL_SIZE_SMALL := 10
const LEVEL_SMALL_FROM := 100
## Centred on the third lobe, `CHIP_X + 2.5 lobes`, on a baseline that puts
## the digits' ink across the middle of the lens.
const LEVEL_X := CHIP_X + 2.5 * CHIP_LOBE
const LEVEL_BASE := 23.5
## At an open fork the numeral moves into the fork's mouth, and takes the hue.
const LEVEL_FORK_X := 81.0
const LEVEL_FORK_ALPHA := 0.95
## `AFTER_PIPS` only: the gap between the last pip and the numeral.
const LEVEL_AFTER_GAP := 6.0

## **The fork on the slot** (§8.3): lobes 0 and 1 as ever, and then the helix
## stops halfway through its third and its strands part, like a replication
## fork. The weave runs on from `along` 56 to the crest at 70, and from there
## to [constant FORK_TIPS] each strand swings a further [constant FORK_SPREAD]
## as the square of the way out. The tips land at chip x 94, y 1.5 and 36.5 --
## inside the box. The outline changes, not only the colour, so it survives
## greyscale.
const FORK_FROM := 2.0 * CHIP_LOBE
const FORK_TIPS := 88.0
const FORK_SPREAD := 6.5
## **A slot the body has not earned yet** is its helix at this brightness and
## nothing else: no rungs, no word, no tether, no focus and no input. Only the
## first generation shows any -- a daughter inherits a seven-long layout, so
## hers are all live -- and that is exactly when *your body will grow a slot
## here* is news. Empty (bright, live) and unearned (faint, dead) read apart at
## both shapes.
const UNEARNED_INK := 0.32

## **The backbone, the depth alpha, the rung states and the segment count all
## live in `cilia.gd`**, because the division's choosing screen draws the same
## helix on its side and two copies of a drawing drift apart. See
## `Cilia.STRAND_*` and choosing.md §9.1; what stays here is this surface's own
## geometry, which is the only thing the two screens disagree about.
##
## The selected slot's own stretch of backbone, brighter.
const BACKBONE_LIT := 1.25

## The lens between the backbones, filled on the selected slot. Area, not a
## border -- there is no box to put a border on, and a filled lens is the one
## mark that cannot be confused with a rung.
const LENS_SELECTED := 0.20
## A chip's lens is a third the size of the choosing screen's, and needs a
## little more fill to read as selected at all.
const CHIP_LENS := LENS_SELECTED + 0.08
## An empty slot has no gene, so its selection and its tether are the column's
## own pale tint.
const PALE := Color(0.855, 0.953, 0.933)

## **A waiting gene: a base pair that is not in a ladder yet.** A bar with a
## base at each end -- in the tray, and riding a finger across the figure.
const SAMPLE_BAR := 15.0
const SAMPLE_WIDTH := 2.6
const SAMPLE_CAP := 2.5
const SAMPLE_GAP := 6.0    ## between the bar and its word
const SAMPLE_WORD := 13
## Two rings, not a disc: a crisp-edged disc of even tone is the silhouette of a
## widget, which diegetic-hud.md §2 spent three passes establishing.
const SAMPLE_HALO: Array[float] = [9.0, 13.5]
const SAMPLE_HALO_ALPHA: Array[float] = [0.11, 0.05]
## The travelling gene's own box: the width of a chip, and the height of the
## band the strand once reserved for it.
const SAMPLE_BOX := Vector2(96.0, 26.0)

## **The tray above the figure: every gene waiting for a slot, head first**
## (dna-body.md §5), soonest to lapse first -- #118's order. A tray chip is the
## gene's loose base pair, its word and its level as ring pips, because a
## waiting gene is carried by definition: `sting` eaten twice reads two rings
## and a dot, and lands at two.
##
## 48 tall is the touch rule and 116 wide fits the longest word with its pips
## and air either side. **Four fit on a row beside the caption and a fifth
## wraps**: the tray is 560 wide, and five genes at once have been posed and
## still fit the column with 58 px to spare above and below.
const WAIT_SIZE := Vector2(116.0, 48.0)
const WAIT_BAR_X := 16.0
const WAIT_WORD_X := 32.0
## The air right of a chip's last pip: what `venom`, the widest word, leaves at
## 116. A gene this build has no word for is read by its own name, and a name is
## wider than any word -- `statocyst`'s reaches 128 with its pips -- so its chip
## grows to keep this much rather than land its pips on the next chip. See
## [method waiting_width].
const WAIT_AIR := 3.0
## Every gene not in hand is drawn down to this; the one in hand goes loud and
## gains an underline in its own hue.
const WAIT_DIM := 0.55
## The tray's caption, in the voice of every other caption on this column.
##
## TRANSLATORS: A small caption, in 15 px type, at the start of the row of chips
## that wait for the player. Two kinds of chip wait there: genes the cell has just
## eaten and not yet placed on its body, and, after them, a gene's fork, which waits
## for the player to choose how that gene grows (today the beam's, between `fill`
## and `sweep`). **The same word captions both**, so it must say only that they
## wait: not "to place", which is wrong for a fork. One lowercase word. Four chips
## fit on a row beside it; a wider word makes the fourth wrap onto the next row.
## ROOM: 64 px at 15 px
const WAIT_CAPTION := "waiting"
const CAPTION_TINT := Color(0.855, 0.953, 0.933, 0.45)
const CAPTION_SIZE := 15

## **A fork waits with the genes** (beam-levels.md §8.3): one chip per open
## fork, after the waiting genes, because the tray is where this screen keeps
## what waits for the player. It is [constant WAIT_SIZE], and it **neither drags
## nor takes a drop**: it opens the fork's two cards. Its glyph is the slot's
## fork -- a lobe, a half and the parting, `along` 28 to 88 -- at half size, its
## axis on the base pairs' line.
const FORK_GLYPH_FROM := CHIP_LOBE
const FORK_GLYPH_SCALE := 0.5
const FORK_GLYPH_AT := Vector2(7.0, 22.0)
## The gene's word and its level after it, in the level's hue.
const FORK_WORD_X := 44.0
const FORK_WORD_BASE := 27.0
const FORK_LEVEL_GAP := 6.0
## While its cards are up, the chip carries the gene-in-hand mark.
const FORK_OPEN_Y := 45.0

## **What the hint says: how likely the selected slot is to reach a daughter.**
## Eating a gene writes it into the DNA; a daughter is a roll against that DNA,
## and copy number is the odds -- so the one line under the figure is where the
## pips are put into words. It is said *before* the division, on the surface the
## player is already reading, which is the whole of "the chance must be legible
## before, not announced after". The pips draw the level; this line says why it
## matters, which is the owner's call 2 (dna-body.md §13).
##
## TRANSLATORS: The hint under the figure, in 14 px type, about the gene being
## read: how many copies of it the cell's DNA holds (one to three) and so how
## likely a daughter cell is to wear it (to show it as an organ). The copies are
## words, not digits, on purpose. The row is 560 px wide and a level and a gauge
## share it, which leaves the text 430 px.
## ROOM: 430 px at 14 px
const HINT_CHANCE: Array[String] = [
	"",
	"one copy · a daughter may not wear it",
	"two copies · a daughter probably wears it",
	"three copies · a daughter always wears it",
]
## The mouth is the one gene that always expresses (genome.gd's
## ALWAYS_EXPRESSED), so it says so instead of quoting odds it does not obey.
##
## TRANSLATORS: The hint (see the copies line above) for the mouth gene, which
## every daughter always wears. The row may be shared with a level and a gauge.
## ROOM: 430 px at 14 px
const HINT_CERTAIN := "the mouth · a daughter always wears it"
## The choosing screen reads this one as well, under an empty locus of its own.
##
## TRANSLATORS: The hint under an empty place on the body: nothing is there, so
## nothing can be passed on to a daughter from it.
## ROOM: 560 px at 14 px
const HINT_EMPTY := "an empty slot · nothing to pass on from here"

## **The level, in front of the odds** (§8.2): `level 7 ▰▰▱ · two copies · a
## daughter probably wears it`. The level is what a daughter inherits and the
## copies are whether she wears it -- decision 5 of beam-levels.md §0 in one
## line. The banked level, never the one held at the fork.
##
## TRANSLATORS: A gene's level, a whole number that grows with use: "level 7".
## Keep %d. Shown in 14 px type at the start of the hint row, before a gauge and
## the hint itself, which share the row's 560 px with it.
## ROOM: 70 px at 14 px with 99
const HINT_LEVEL := "level %d"
## **A gauge and not a number**, because experience means nothing to a player
## and `progress()` is already a fraction: a 36 x 4 bar at y 9 in its own
## 36 x 20 box, one pixel a thirty-sixth of a level.
const GAUGE_SIZE := Vector2(36.0, 20.0)
const GAUGE_BAR := Rect2(0.0, 9.0, 36.0, 4.0)
const GAUGE_RADIUS := 2
const GAUGE_TRACK := Color(0.855, 0.953, 0.933, 0.14)
const GAUGE_FILL_ALPHA := 0.85

## **A toxin not yet placed is neither form**: the tray, the hand and a drag call
## it this until it lands.
##
## TRANSLATORS: The word for a toxin gene that has been eaten and is waiting to be
## placed, on its chip in the tray and on a finger dragging it. Placed outside the
## body it becomes `venom`, inside it becomes `poison`; until then it is neither.
## One short lowercase word, like the other gene words.
## ROOM: 47 px at 13 px
const TOXIN_WORD := "toxin"
## TRANSLATORS: The gene line for a toxin that is waiting, before a slot is
## chosen: it hurts over time, and becomes venom or poison depending on where it
## is placed. After the gene's scientific name and a middle dot. No longer than
## the English.
## ROOM: 440 px at 15 px
const EXPLAIN_TOXIN := "a toxin that goes on hurting, as venom or as poison"
## TRANSLATORS: The line for the empty slot inside the body (the one slot in the
## middle of the body, not round it): nothing is there yet, and a toxin placed
## there becomes poison.
## ROOM: 520 px at 15 px
const EXPLAIN_INSIDE := "nothing inside yet · a toxin here becomes poison"
## TRANSLATORS: Under that line, for the empty inside slot: the slot is inside the
## cell's body, and a toxin is the only gene that can go there.
## ROOM: 560 px at 14 px
const HINT_INSIDE := "inside your body · only a toxin goes here"

## The second, weaker channel behind the rungs: a gene the body does not wear
## draws its word and its organ fainter. Honest about which one does the work.
const ORGAN_UNEXPRESSED := 0.52
const WORD_UNEXPRESSED := 0.42

## **The plain word, never the biological name.** Four short verbs are parsed
## instantly at arm's length; nine letters of Greek are not, on the one screen
## whose whole job is a quick decision. §5.2, and the nine-character ceiling it
## sets is why a new gene needs a short word as well as a real organ name.
##
## TRANSLATORS: A gene's name as the player reads it on a chip beside three small
## dots: one short lowercase word, a verb or a noun for what the gene does. The
## `entry` line says which gene it names (its scientific name, never translated).
## It has to be short: prefer the shortest everyday word. The same words appear
## inside sentences such as "let go to swap eat and ping".
## ROOM: 47 px at 13 px
const WORDS := {
	&"cytostome": "eat", &"cirrus": "turn", &"flagellum": "swim",
	&"stigma": "see", &"ocellus": "beam", &"axoneme": "push",
	&"palp": "touch",
	&"myoneme": "dash", &"trichocyst": "sting", &"pellicle": "armor",
	&"veneneux": "poison", &"toxicyst": "venom", &"plastid": "sun",
	&"vacuole": "store", &"crista": "burn", &"chemocyte": "smell",
	&"ampulla": "ping",
}

## **One line per gene, and it says what the gene does to the player** -- not
## what the organelle is. Sixteen tiles carrying one word each are enough to
## recognise a gene you already know and not enough to learn one, which is the
## whole of the owner's ask.
##
## The voice is the screen's: lowercase, plain, no jargon, one clause and then
## its consequence. No line names another gene, because a player reading `armor`
## has not necessarily met `cytostome` yet. No line carries a number: levels are
## the pips' job and a line that said "+30%" would be the classic HUD this game
## spent two phases not building.
##
## `that side` in `ocellus` and `trichocyst` is deliberate and it points at the
## arc the slot is tethered to -- the two directional genes are the two whose
## line has to explain why the slot mattered.
##
## **This line is also the one place the biological name reaches the screen, and
## that is a deliberate reading of §8 rather than a breach of it.** The rule §8
## states is that *the slot* wears the plain word, and the argument it gives is
## the glance: four short verbs are parsed at arm's length and nine letters of
## Greek are not, on the surface whose whole job is a quick decision. This line
## is not a glance -- it is read because the player stopped to read it -- so the
## name sits at the head of it and the plain word keeps the slot. §9.1 gives
## every gene two names on purpose; a name no player ever meets is a convention
## for the compiler, and CLAUDE.md's *realism is a tool* is the argument that
## `ampulla` is worth meeting.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {
	&"cytostome": "a wider mouth swallows bigger things whole",
	&"cirrus": "turns you faster, and sooner after you ask",
	&"flagellum": "your tail beats harder, and more often",
	&"stigma": "feels the shadow of anything big, however dark",
	&"ocellus": "a ray out of that side, marking whatever it strikes",
	&"chemocyte": "smells food, strongest where your nose is pointed",
	&"ampulla": "a pulse that answers off everything, not just food",
	&"axoneme": "holding on pushes you, instead of only steering",
	&"palp": "feels what is against you, with no light at all",
	&"myoneme": "tap for a burst of speed, paid for in hunger",
	&"trichocyst": "a dart at whatever closes in on that side",
	&"pellicle": "thicker skin, so bites take less and fewer mouths fit",
	&"veneneux": "whatever bites or swallows you takes your poison",
	&"toxicyst": "your bite leaves venom, which goes on hurting",
	&"plastid": "makes a little of its own food, so you starve slower",
	&"vacuole": "a bigger tank, so hunger takes longer to reach you",
	&"crista": "burns cleaner, so everything you carry costs less",
}
## **Where venom works is its line** (docs/design/dna-slots.md §3.2): at the
## front it rides on your bite, and [constant EXPLAINS] says so; on a side or
## the stern it stings what bites you there, and these say so -- `that side`
## as the beam and the dart already say it, and `from behind` for the stern,
## which a player least thinks of as a side.
##
## TRANSLATORS: The line of the venom gene (`toxicyst`, shown as `venom`) when it
## sits on a side of the body: whatever bites the cell on that side takes venom
## from it. "That side" is the side of the body where the gene's slot is. Same
## limit as the gene lines above: no longer than the English.
## ROOM: 440 px at 15 px
const EXPLAINS_SIDE := {
	&"toxicyst": "whatever bites you on that side takes venom",
}
## TRANSLATORS: The same line when the venom sits at the back of the body, where
## the tail is: whatever bites the cell from behind takes venom from it.
## ROOM: 440 px at 15 px
const EXPLAINS_STERN := {
	&"toxicyst": "whatever bites you from behind takes venom",
}
## **Once a way is taken, the gene's line says which** (beam-levels.md §8.3):
## gene, then path, then what the organ now does -- the pause screen's receipt
## for the choice, and the choosing screen's line for a daughter who inherits
## it. 464 and 446 px with the name in front. A fork still open reads as no
## path yet: the gene's own line above.
##
## TRANSLATORS: As the gene lines above, for a gene that can grow in two ways and
## has been given one: what it does now. The `entry` line gives the gene and the
## way. Same limit: no longer than the English, which is 464 px at most with the
## gene's name in front.
## ROOM: 470 px at 15 px
const EXPLAINS_PATH := {
	&"ocellus": {
		&"extend": "a fan of rays out of that side, one more every level",
		&"sweep": "three rays sweeping that side, faster every level",
	},
}
## An empty slot has no gene to explain, so it explains the one thing it does
## have: a side of the body. The tether from it is what "this side" refers to,
## and on the choosing screen, which reads this line too, the dart is.
##
## TRANSLATORS: The line for an empty slot on the body, in 15 px type, in the place
## where a gene's line goes. An "organ" is what a gene makes the cell grow; "this
## side" is the side of the body the slot is on. No longer than the English (368
## px, 51 characters).
## ROOM: 520 px at 15 px
const EXPLAIN_EMPTY := "nothing here yet · an organ here grows on this side"
## Loud enough to be the thing you are reading, quieter than the word on the
## chip: caption 0.45, hint 0.38, slot word 0.66, this 0.62.
const EXPLAIN_TINT := Color(0.855, 0.953, 0.933, 0.62)
## The name is drawn in the gene's own hue, which is the hue of the rungs the
## player just tapped -- that is what ties the line to the slot with no arrow
## and no animation.
const EXPLAIN_NAME_ALPHA := 0.95

const LABEL_TINT := Color(0.855, 0.953, 0.933, 0.66)
const LABEL_TINT_LOUD := Color(0.855, 0.953, 0.933, 0.92)

## Focus has to be drawn, and it must not be a box: a slot is a piece of DNA and
## not a square. An underline under the chip says where the keyboard is
## standing without rebuilding the thing that was replaced.
const FOCUS_TINT := Color(0.588, 1.0, 0.859, 0.85)
const FOCUS_INSET := 14.0
const FOCUS_WIDTH := 2.0

## The organ drawn beside the explanation, in canvas px of its own box.
const EXPLAIN_ORGAN_SIZE := Vector2(34.0, 26.0)
const EXPLAIN_ORGAN_SCALE := 0.60
## Where in that box the organ's own centre sits. **Measured, not chosen**: the
## tallest organ is `flagellum`, whose strokes reach `TILE_ARC_RADIUS +
## TILE_LEN` above the centre -- 18 px at this scale -- so any seat above 18.5
## puts the tuft outside its own row.
const EXPLAIN_ORGAN_SEAT := Vector2(17.0, 18.5)

## The two lines: 14 px, 19 apart, the first baseline 14 px into a block that
## is 38 tall whether or not anything is in it -- so reading an empty slot moves
## nothing below it (§3.3, §5.3).
const NUMBERS_SIZE := 14
const NUMBERS_PITCH := 19.0
const NUMBERS_BASE := 14.0
const NUMBERS_HEIGHT := 38.0
## The words in the column's pale tint, and the numbers in the same tint a
## little stronger, so the eye finds them -- only the number: its unit keeps the
## words' tint. Drawn at 0.88 the values out-shone the sentence they explain;
## at 0.70 they read as its details (§3.3).
const NUMBERS_WORD := Color(0.855, 0.953, 0.933, 0.42)
const NUMBERS_VALUE := Color(0.855, 0.953, 0.933, 0.70)
## A gene this body does not wear, drawn a little dimmer: the same numbers,
## saying *what a body wearing it would have* (§5.3). **0.85, not the figure's
## own 0.62**: at 0.62 the words fell to the faintest text on the screen, on
## exactly the gene a player holds while deciding where it goes. At 0.85 they
## sit with the odds line, the faintest text the screen already had.
const NUMBERS_DIM := 0.85

## **The switch** (§2.1): a 96 x 48 hit rect and, across its middle, a 96 x 30
## slab with `numbers` centred in it. Teal, because on this column teal means
## *this responds*; a word and not a `+`, because beside a gene on a screen
## about placing genes, a `+` reads as *add a copy*.
const TOGGLE_SLAB := Rect2(0.0, 9.0, 96.0, 30.0)
const TOGGLE_CORNER := 6
## TRANSLATORS: The label of the pause screen's switch that shows the exact
## numbers behind each gene (how fast, how far, what it costs). One lowercase
## word, drawn in 14 px type on a slab 96 px wide.
## ROOM: 80 px at 14 px
const TOGGLE_WORD := "numbers"
const TOGGLE_WORD_SIZE := 14
## The chips' focus mark: an underline, under the slab.
const TOGGLE_FOCUS_Y := 44.0
## Its four states, off, off and hovered or focused, on, and on and hovered or
## focused: `[fill, edge width, edge alpha, word alpha]`. **On differs from
## hovered by its 2 px edge**, this screen's mark for an armed tile
## (genes-and-cilia.md §5.2), so the difference is a shape and survives
## greyscale.
const TOGGLE_STATES: Array = [
	[Color(0.063, 0.141, 0.125, 0.35), 1, 0.22, 0.50],
	[Color(0.063, 0.141, 0.125, 0.55), 1, 0.40, 0.72],
	[Color(0.086, 0.204, 0.176, 0.80), 2, 0.62, 0.80],
	[Color(0.086, 0.204, 0.176, 0.80), 2, 0.78, 0.92],
]
const TOGGLE_EDGE := Color(0.12, 0.70, 0.58)
const TOGGLE_INK := Color(0.588, 1.0, 0.859)


# ---------------------------------------------------------------------------
# Words.
# ---------------------------------------------------------------------------

## The plain word a gene is read by on this surface. A gene this build has no
## word for -- a later phase's, arriving over an older binary in a content pack
## -- falls back to its own name rather than to nothing.
static func word_of(gene: StringName) -> String:
	return String(TranslationServer.translate(WORDS[gene])) if WORDS.has(gene) \
		else String(gene)


## **The word for a gene not yet placed** (dna-slots-ux.md §3.5): a toxin is
## `toxin` in the tray, in hand and on a finger, neither form until it lands.
## Every other gene is its own word.
static func carried_word_of(gene: StringName) -> String:
	return String(TranslationServer.translate(TOXIN_WORD)) \
		if GenomeNode.has_forms(gene) else word_of(gene)


## **What [param gene] does, in the player's terms**: its line, or -- once its
## fork is behind it -- the line for the way it took, [param path]
## (beam-levels.md §8.3). The pause screen and the choosing screen both read it,
## so a daughter reads what her mother chose.
##
## [param slot] is where it is read at, for a gene whose line depends on it:
## venom on a side or the stern says what it does there.
static func explains(gene: StringName, slot: int = -1,
		path: StringName = &"") -> String:
	var taken: Dictionary = EXPLAINS_PATH.get(gene, {})
	if taken.has(path):
		return String(TranslationServer.translate(EXPLAINS_PATH[gene][path]))
	if slot >= 0 and not GenomeNode.is_inside(slot) and not GenomeNode.is_front(slot) \
			and CellBody.VENOM_SIDES:
		if slot == GenomeNode.STERN and EXPLAINS_STERN.has(gene):
			return String(TranslationServer.translate(EXPLAINS_STERN[gene]))
		if EXPLAINS_SIDE.has(gene):
			return String(TranslationServer.translate(EXPLAINS_SIDE[gene]))
	if EXPLAINS.has(gene):
		return String(TranslationServer.translate(EXPLAINS[gene]))
	return ""


## **An empty [param slot] has no gene to explain**, so its line explains what it
## does have: a side of the body -- or, inside, the one gene that goes there.
static func explain_empty(slot: int) -> String:
	if GenomeNode.is_inside(slot):
		return String(TranslationServer.translate(EXPLAIN_INSIDE))
	return String(TranslationServer.translate(EXPLAIN_EMPTY))


## The hint under an empty [param slot]: nothing to pass on from there -- or,
## inside, that only a toxin goes there.
static func hint_empty(slot: int) -> String:
	if GenomeNode.is_inside(slot):
		return String(TranslationServer.translate(HINT_INSIDE))
	return String(TranslationServer.translate(HINT_EMPTY))


## **The odds a copy count gives**, in words -- and with [param numbers] on,
## with their percentage (gene-stats.md §5.4). A certainty says so either way.
static func odds(copies: int, numbers: bool) -> String:
	if numbers:
		return GeneStats.odds_text(copies)
	var at := clampi(copies, 0, HINT_CHANCE.size() - 1)
	return String(TranslationServer.translate(HINT_CHANCE[at])) if at > 0 else ""


## A gene's [param level], at the front of the hint row: "level 7".
static func level_text(level: int) -> String:
	return String(TranslationServer.translate(HINT_LEVEL)) % level


## **The caption, whole** (gene-stats.md §5.4): the [param generation], and with
## [param numbers] on, the body's size at [param radius], what its full tank
## holds and how long that lasts drifting -- in the caption's own size and tint,
## so it is still a caption. [param upkeep] is what the [param body] costs to
## keep, as the genome prices it.
##
## **It carries the generation**, because the hint below the figure carries what
## a slot is worth to a daughter, and it says `genome` because the group is two
## registers, and only the chips are the DNA. How deep the lineage is is the only
## readout of how far into the run the player is, and the nearest thing the game
## has to a score; it moved from the hint to the caption when the hint took on
## the odds -- zero pixels either way. The phrases are drops.gd's, which a drop's
## line in the drop menu says too.
static func caption(generation: int, numbers: bool, radius: float, body: Dictionary,
		upkeep: float) -> String:
	# TRANSLATORS: The caption above the figure on the pause screen, in 15 px
	# type: the word for the cell's whole set of genes, then a middle dot and %s,
	# which is the generation ("first generation"). Keep %s. With the numbers
	# switch on, more is added after it, and the whole caption has 560 px: beyond
	# that the whole pause screen shifts to make room, so keep this short.
	var said := String(TranslationServer.translate("genome · %s")) \
		% Drops.generation_text(generation)
	if numbers:
		said += Readout.SEP + Readout.plain(GeneStats.cell_items(radius, body, upkeep))
	return said


# ---------------------------------------------------------------------------
# The body.
# ---------------------------------------------------------------------------

## **The body register, drawn as a body** on [param canvas], the figure's own
## box: what [param body] wears and where it wears it ([param worn], fixed at
## birth) -- the routine the water uses, nose up, `clock` 0, a still mirror. The
## tethers of the first [param live] slots go first so the body wins where they
## cross; then the cell; then the body's own words where it disagrees with its
## DNA, [param genes] being the gene each slot carries. The part being read is
## [method draw_mark]'s, drawn after this so nothing covers it.
##
## **As slack as the body is** (docs/design/hunger.md §4): a starving cell's
## mirror is crumpled too, its creases still at `clock` 0, by [param slack].
## **And as dosed as it is** (dna-slots-ux.md §3.1): [param felt], what its loads
## do to it (`FoodField.felt_of`), stains round the inside chip's window and pits
## the rim, as hunger's crumple is.
static func draw_body(canvas: Control, body: Dictionary, worn: Array[StringName],
		genes: Array[StringName], live: int, slack: float, felt: Vector3) -> void:
	for slot in live:
		_draw_tether(canvas, slot, _gene_in(genes, slot))
	Cilia.draw_cell(canvas, FIGURE_AT, 0.0, FIGURE_R, body,
		CellBody.gape_of(int(body.get(&"cytostome", 0)), FIGURE_R), FIGURE_R,
		true, 0.0, FIGURE_FADE, 0.0, 0.0, 0.0, 1.0, worn, 0.0, 0.0, 0.0, 0.0,
		false, Cilia.NO_EYE, Cilia.NO_TAIL, slack,
		Cilia.NO_DOSE if felt == Vector3.ZERO else {"felt": felt})
	_draw_dissent(canvas, worn, genes, live)


## The gene [param genes] has at [param slot], or &"".
static func _gene_in(genes: Array[StringName], slot: int) -> StringName:
	if slot >= 0 and slot < genes.size():
		return genes[slot]
	return &""


## One slot's thread, from its chip to the middle of its arc, in its gene's hue
## -- or the column's pale, for a slot with nothing in it yet.
static func _draw_tether(canvas: Control, slot: int, gene: StringName) -> void:
	var tone := Cilia.hue(gene) if gene != &"" else PALE
	var to := skin_at(slot, TETHER_LIFT)
	var from := chip_edge(slot, to)
	var bow := (to - from).orthogonal() * TETHER_BOW
	canvas.draw_polyline(
		PackedVector2Array([from, from.lerp(to, 0.5) + bow, to]),
		Color(tone, TETHER_ALPHA), TETHER_WIDTH, true)


## **Where the body disagrees with its DNA, the body says what it wears**: a
## word at every arc whose organ is not the gene the slot now carries. A slot
## the body leaves empty says nothing -- there is no organ to name, and the
## chip's own floating rungs already say the DNA's gene is not worn.
static func _draw_dissent(canvas: Control, worn: Array[StringName],
		genes: Array[StringName], live: int) -> void:
	var font := canvas.get_theme_default_font()
	if font == null:
		return
	for slot in mini(worn.size(), live):
		var mine := worn[slot]
		if mine == &"" or mine == _gene_in(genes, slot):
			continue
		var near := skin_at(slot, TETHER_LIFT)
		var at := near.lerp(chip_edge(slot, near), DISSENT_ALONG)
		var says := word_of(mine)
		var width := font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			DISSENT_SIZE).x
		canvas.draw_string(font,
			at + Vector2(-width * 0.5, DISSENT_SIZE * 0.36), says,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, DISSENT_SIZE,
			Color(Cilia.hue(mine), DISSENT_ALPHA))


## **The part being read, lit on the skin**: [param slot]'s arc, traced in the
## hue of [param gene] -- whatever is or would be there -- or the column's pale
## for nothing. The inside has no arc, and lights the whole inside instead.
static func draw_mark(canvas: Control, slot: int, gene: StringName) -> void:
	if GenomeNode.is_inside(slot):
		draw_inside_mark(canvas, gene)
		return
	var arc := Cilia.arc_for_slot(slot)
	var points := PackedVector2Array()
	for i in ARC_MARK_STEPS + 1:
		var t := deg_to_rad(lerpf(arc.x, arc.y,
			float(i) / float(ARC_MARK_STEPS)))
		points.append(Cilia.skin_point(FIGURE_AT, 0.0, FIGURE_R, t,
			ARC_MARK_LIFT))
	canvas.draw_polyline(points,
		Color(Cilia.hue(gene) if gene != &"" else PALE, ARC_MARK_ALPHA),
		ARC_MARK_WIDTH, true)


## **The inside, lit**: a ring along the ovoid just inside the rim, in the hue
## of [param gene], or the column's pale for an empty inside.
static func draw_inside_mark(canvas: Control, gene: StringName) -> void:
	var points := PackedVector2Array()
	for i in INSIDE_MARK_STEPS + 1:
		points.append(Cilia.skin_point(FIGURE_AT, 0.0, FIGURE_R * INSIDE_MARK_AT,
			TAU * float(i) / float(INSIDE_MARK_STEPS)))
	canvas.draw_polyline(points,
		Color(Cilia.hue(gene) if gene != &"" else PALE, INSIDE_MARK_ALPHA),
		INSIDE_MARK_WIDTH, true)


## The middle of [param slot]'s arc on this figure's skin, [param lift] off it.
## Slot 1 is the flank pair: its chip and its thread are on the starboard side,
## where anything but the cirrus is worn.
static func skin_at(slot: int, lift: float) -> Vector2:
	var arc := Cilia.arc_for_slot(slot)
	return Cilia.skin_point(FIGURE_AT, 0.0, FIGURE_R,
		deg_to_rad((arc.x + arc.y) * 0.5), lift)


## Where a line from [param slot]'s chip toward [param to] leaves the chip, inset
## so it starts clear of the chip's own word and helix.
static func chip_edge(slot: int, to: Vector2) -> Vector2:
	var centre := FIGURE_AT + SLOT_SEAT[slot]
	var d := to - centre
	var half := SLOT_SIZE * 0.5 - TETHER_INSET
	var k := 1.0
	if absf(d.x) > 0.001:
		k = minf(k, half.x / absf(d.x))
	if absf(d.y) > 0.001:
		k = minf(k, half.y / absf(d.y))
	return centre + d * k


## Where [param slot]'s chip sits in the figure's box: the top-left corner of
## its [constant SLOT_SIZE], centred on its seat.
static func chip_at(slot: int) -> Vector2:
	return FIGURE_AT + SLOT_SEAT[slot] - SLOT_SIZE * 0.5


# ---------------------------------------------------------------------------
# A chip.
# ---------------------------------------------------------------------------

## **One chip, seated at its arc** (the node is [constant SLOT_SIZE]): its piece
## of helix, its copies, its word and its level.
##
## [param gene] is what the chip shows, &"" for nothing -- an empty slot, or the
## slot a gene is in the air from. [param copies] is the DNA's copy count and
## [param worn] how many of those this body expresses; the rungs and the pips
## draw both, which is what makes a chip the two registers rather than one.
## [param tone] is the hue of its lens and [param level] its gene's banked level,
## 0 for a gene that does not level.
##
## The rest is what the screen drawing it has made of the moment, and a screen
## that only reads leaves it be: [param forking] parts the strands where a fork
## waits; [param selected] fills the lens, which is the whole of "selected";
## [param trace] leaves only a trace of it, where a tap adds a copy elsewhere;
## [param refused] drops the weave to [constant REFUSED_INK]; and [param ghost]
## is a form not written yet, at [param ghost_copies] and [param ghost_ink]. The
## keyboard's underline is drawn whenever the node has the focus.
static func draw_chip(node: Control, slot: int, gene: StringName, copies: int,
		worn: int, tone: Color, level: int = 0, forking: bool = false,
		selected: bool = false, trace: bool = false, refused: bool = false,
		ghost: StringName = &"", ghost_copies: int = 0,
		ghost_ink: float = GHOST_INK) -> void:
	# **The inside chip sits on the body, over a window of the base colour**, so
	# its weave and word read over the nucleus and a stain (dna-slots-ux.md §3.1).
	if GenomeNode.is_inside(slot):
		draw_inside_window(node)
	node.draw_set_transform(Vector2(CHIP_X, 0.0))
	# **The lens fills, and that is the whole of "selected".** The middle lobe
	# of three is the slot's own.
	if selected:
		Cilia.draw_lens(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, 0, 1.0, Color(tone, CHIP_LENS))
	elif trace:
		Cilia.draw_lens(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, 0, 1.0, Color(tone, CHIP_LENS * RAISE_TRACE))
	var bright := BACKBONE_LIT if selected else (REFUSED_INK if refused else 1.0)
	# **A fork waiting here parts the strands** (beam-levels.md §8.3): the first
	# two lobes as ever, and then the fork where the third one was.
	if forking:
		Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, CHIP_LOBES - 1, 0, bright, 0)
		Cilia.draw_fork(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, FORK_FROM, FORK_TIPS, FORK_SPREAD, Cilia.hue(gene), bright)
	else:
		Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, CHIP_LOBES, 0, bright, 0)
	if gene != &"":
		Cilia.draw_rungs(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID,
			CHIP_AMP, 0, CHIP_LOBE * 1.5, Cilia.hue(gene), copies, worn)
	node.draw_set_transform(Vector2.ZERO)

	draw_chip_label(node, gene, copies, worn, selected, level)
	if ghost != &"":
		draw_ghost_label(node, ghost, ghost_copies, ghost_ink)
	if LEVEL_SEAT == LevelSeat.LOBE:
		draw_chip_level(node, gene, worn, selected, forking, level)

	if node.has_focus():
		node.draw_line(Vector2(FOCUS_INSET, SLOT_SIZE.y - 1.0),
			Vector2(SLOT_SIZE.x - FOCUS_INSET, SLOT_SIZE.y - 1.0),
			FOCUS_TINT, FOCUS_WIDTH, true)


## **A form not written yet** (dna-slots-ux.md §3.2): its word and
## [param copies] as ring pips, centred as a chip's own reading is, at
## [param ink]. No rungs and no level -- nothing is in the DNA until the tap or
## the drop, and the rungs are the DNA.
static func draw_ghost_label(node: Control, form: StringName, copies: int,
		ink: float) -> void:
	var font := node.get_theme_default_font()
	if font == null:
		return
	var says := word_of(form)
	var width := font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		CHIP_WORD).x
	var left := (SLOT_SIZE.x - width - PIP_GAP
		- PIP_PITCH * float(GenomeNode.TIER_MAX - 1) - PIP_R * 2.0) * 0.5
	node.draw_string(font, Vector2(left, CHIP_BASE), says,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_WORD,
		Color(PALE, LABEL_TINT_LOUD.a * ink))
	draw_pips(node, Vector2(left + width + PIP_GAP + PIP_R, CHIP_BASE - PIP_LIFT),
		Cilia.hue(form), copies, 0, ink)


## **The inside chip's window**: an ellipse of the base colour on the chip's
## centre, drawn first, so the nucleus and a stain sit behind the chip and not
## through its word.
static func draw_inside_window(node: Control) -> void:
	var centre := SLOT_SIZE * 0.5
	var points := PackedVector2Array()
	points.resize(INSIDE_BACK_STEPS)
	for i in INSIDE_BACK_STEPS:
		var a := TAU * float(i) / float(INSIDE_BACK_STEPS)
		points[i] = centre + Vector2(cos(a) * INSIDE_BACK.x, sin(a) * INSIDE_BACK.y)
	node.draw_colored_polygon(points, INSIDE_BACK_TINT)


## A slot the body has not earned: its helix, faint, and nothing else.
static func draw_unearned(node: Control) -> void:
	node.draw_set_transform(Vector2(CHIP_X, 0.0))
	Cilia.draw_weave(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID, CHIP_AMP,
		CHIP_LOBES, 0, UNEARNED_INK, 0)
	node.draw_set_transform(Vector2.ZERO)


## The plain word and the level, centred under the chip as one group so a long
## word and a short one both sit under their own piece of helix.
##
## **The word is the slot's word**: a short verb parsed at arm's length, never
## the biological name. That belongs to the explanation line, which is read
## rather than glanced at.
static func draw_chip_label(node: Control, gene: StringName, copies: int, worn: int,
		selected: bool, level: int = 0) -> void:
	if gene == &"":
		return
	var font := node.get_theme_default_font()
	if font == null:
		return
	var says := word_of(gene)
	var width := font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		CHIP_WORD).x
	var group := width + PIP_GAP + PIP_PITCH * float(GenomeNode.TIER_MAX - 1) \
		+ PIP_R * 2.0
	# Owner's call 2 answered the other way: the level after the pips, in the
	# group, so the whole reading stays centred under its helix.
	var numeral := ""
	var numeral_size := LEVEL_SIZE
	if LEVEL_SEAT == LevelSeat.AFTER_PIPS and level > 0:
		numeral = str(level)
		numeral_size = level_size(level)
		group += LEVEL_AFTER_GAP + font.get_string_size(numeral,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, numeral_size).x
	var left := (SLOT_SIZE.x - group) * 0.5
	var tint := word_tint(selected, worn)
	node.draw_string(font, Vector2(left, CHIP_BASE), says,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_WORD, tint)
	draw_pips(node,
		Vector2(left + width + PIP_GAP + PIP_R, CHIP_BASE - PIP_LIFT),
		Cilia.hue(gene), copies, worn, 1.0)
	if numeral != "":
		node.draw_string(font, Vector2(left + width + PIP_GAP
			+ PIP_PITCH * float(GenomeNode.TIER_MAX - 1) + PIP_R * 2.0
			+ LEVEL_AFTER_GAP, CHIP_BASE), numeral, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, numeral_size, tint)


## The tint a chip's word is drawn in -- and its level, which reads with it.
## Loud while selected; quieter for an organ this body does not wear, the third
## channel agreeing with the floating rungs and the rings.
static func word_tint(selected: bool, worn: int) -> Color:
	if selected:
		return LABEL_TINT_LOUD
	if worn <= 0:
		return Color(PALE, WORD_UNEXPRESSED)
	return LABEL_TINT


## **The level, in the third lobe** (beam-levels.md §8.1): the banked
## [param level] -- `level()`, never the one held at the fork -- centred in the
## lens right of the rungs, in the word's own tint. At an open fork it moves into
## the fork's mouth and takes the gene's hue, so the one chip that is asking for
## something is the one whose number is coloured. Drawn wherever the chip draws
## its word, and so never on a drag source or an empty slot; nothing for a gene
## that does not level, whose level is 0.
static func draw_chip_level(node: Control, gene: StringName, worn: int,
		selected: bool, forking: bool, level: int) -> void:
	if gene == &"":
		return
	var font := node.get_theme_default_font()
	if level <= 0 or font == null:
		return
	var text := str(level)
	var numeral_size := level_size(level)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		numeral_size).x
	var at := LEVEL_FORK_X if forking else LEVEL_X
	node.draw_string(font, Vector2(at - width * 0.5, LEVEL_BASE), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, numeral_size,
		Color(Cilia.hue(gene), LEVEL_FORK_ALPHA) if forking
			else word_tint(selected, worn))


## The numeral's size: [constant LEVEL_SIZE], and one step down from three
## digits, which the lobe was measured to hold at two.
static func level_size(level: int) -> int:
	return LEVEL_SIZE if level < LEVEL_SMALL_FROM else LEVEL_SIZE_SMALL


## Three pips from [param first], a pitch apart: a disc for each copy worn, a
## ring for each copy only carried, a dot for each copy there is still room for.
## [param ink] is the tray's dim; a chip passes 1.
static func draw_pips(node: CanvasItem, first: Vector2, tone: Color, copies: int,
		worn: int, ink: float) -> void:
	for i in GenomeNode.TIER_MAX:
		var at := first + Vector2(PIP_PITCH * float(i), 0.0)
		if i < worn:
			node.draw_circle(at, PIP_R, Color(tone, 0.95 * ink), true, -1.0, true)
		elif i < copies:
			# Stroked inside the disc's radius, so a ring and a disc are the
			# same size and only their fill differs.
			node.draw_arc(at, PIP_R - PIP_RING * 0.5, 0.0, TAU, 16,
				Color(tone, 0.95 * ink), PIP_RING, true)
		else:
			node.draw_circle(at, PIP_ROOM_R, Color(PALE, PIP_ROOM_ALPHA * ink),
				true, -1.0, true)


# ---------------------------------------------------------------------------
# The tray: what waits.
# ---------------------------------------------------------------------------

## The tray's caption, the height of a chip so the row centres on it.
static func make_tray_caption() -> Label:
	var label := Label.new()
	label.name = "Caption"
	label.text = String(TranslationServer.translate(WAIT_CAPTION))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(0.0, WAIT_SIZE.y)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", CAPTION_SIZE)
	label.add_theme_color_override("font_color", CAPTION_TINT)
	return label


## One waiting gene: its loose base pair, its word and its [param copies] as
## rings, [param in_hand] or stepped back to [constant WAIT_DIM].
##
## **The wilt** (dna-body.md §5): its halos fade over its last
## [constant Cilia.HELD_WILT] seconds of [param left], the vesicle's own clock on
## the body, so the tray and the figure in the water say *about to lapse* the
## same way. Only a pond shows it -- single player stops every clock while the
## pause screen is open -- and the pause screen redraws it there.
static func draw_waiting(node: Control, gene: StringName, copies: int, left: float,
		in_hand: bool) -> void:
	var ink := 1.0 if in_hand else WAIT_DIM
	var tone := Cilia.hue(gene)
	var mid := WAIT_SIZE.y * 0.5 - 2.0
	var wilt := clampf(left / Cilia.HELD_WILT, 0.0, 1.0)
	draw_base_pair(node, Vector2(WAIT_BAR_X, mid), tone, ink,
		(1.6 if in_hand else 1.0) * (0.40 + 0.60 * wilt))
	var font := node.get_theme_default_font()
	if font != null:
		# A toxin waits as `toxin`: neither form until it lands (§3.5).
		var says := carried_word_of(gene)
		node.draw_string(font, Vector2(WAIT_WORD_X, mid + 5.0), says,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_WORD,
			LABEL_TINT_LOUD if in_hand else LABEL_TINT)
		var width := font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			CHIP_WORD).x
		# Carried by definition, so rings and never a disc.
		draw_pips(node, Vector2(WAIT_WORD_X + width + PIP_GAP + PIP_R, mid),
			tone, copies, 0, ink)
	# The chip's own width, not WAIT_SIZE's: a name wider than any word grows
	# its chip, and the underline is under the whole of it.
	if in_hand:
		node.draw_line(Vector2(6.0, WAIT_SIZE.y - 3.0),
			Vector2(node.size.x - 6.0, WAIT_SIZE.y - 3.0), Color(tone, 0.55),
			1.5, true)
	if node.has_focus():
		node.draw_line(Vector2(FOCUS_INSET, WAIT_SIZE.y - 1.0),
			Vector2(node.size.x - FOCUS_INSET, WAIT_SIZE.y - 1.0),
			FOCUS_TINT, FOCUS_WIDTH, true)


## How wide [param gene]'s waiting chip is, in [param font]: [constant WAIT_SIZE]
## for every word in [constant WORDS], and wider for a name that is not one -- a
## retired gene's, handed over by a host on older content. The tray is a flow,
## so a wide chip can cost a row but never lands on its neighbour.
static func waiting_width(font: Font, gene: StringName) -> float:
	if font == null:
		return WAIT_SIZE.x
	var width := font.get_string_size(carried_word_of(gene), HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, CHIP_WORD).x
	return maxf(WAIT_SIZE.x, ceilf(WAIT_WORD_X + width + PIP_GAP + PIP_R * 2.0
		+ PIP_PITCH * float(GenomeNode.TIER_MAX - 1) + WAIT_AIR))


## **A base pair that is not in a ladder yet**: a bar with a base at each end,
## inside two faint rings -- the picture of a gene that has not been given a
## place, in the tray and on a finger alike. [param halo] scales the rings.
static func draw_base_pair(node: CanvasItem, bar: Vector2, tone: Color, ink: float,
		halo: float) -> void:
	for i in SAMPLE_HALO.size():
		node.draw_arc(bar, SAMPLE_HALO[i], 0.0, TAU, 24,
			Color(tone, SAMPLE_HALO_ALPHA[i] * halo), 1.4, true)
	var top := bar - Vector2(0.0, SAMPLE_BAR * 0.5)
	var bottom := bar + Vector2(0.0, SAMPLE_BAR * 0.5)
	node.draw_line(top, bottom, Color(tone, 0.94 * ink), SAMPLE_WIDTH, true)
	node.draw_circle(top, SAMPLE_CAP, Color(tone, 0.94 * ink), true, -1.0, true)
	node.draw_circle(bottom, SAMPLE_CAP, Color(tone, 0.94 * ink), true, -1.0,
		true)


## **The travelling gene**: the base pair with [param says] beside it, centred
## as a group on [param centre]. The word stays, because a base pair with no
## word is a coloured dot.
static func draw_sample(node: Control, gene: StringName, says: String,
		centre: Vector2) -> void:
	var tone := Cilia.hue(gene)
	var font := node.get_theme_default_font()
	var width := 0.0
	if font != null:
		width = font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			SAMPLE_WORD).x
	var group := SAMPLE_WIDTH + SAMPLE_GAP + width
	var bar := Vector2(centre.x - group * 0.5 + SAMPLE_WIDTH * 0.5, centre.y)
	draw_base_pair(node, bar, tone, 1.0, 1.0)
	if font != null:
		node.draw_string(font,
			Vector2(bar.x + SAMPLE_WIDTH * 0.5 + SAMPLE_GAP,
				centre.y + SAMPLE_WORD * 0.38),
			says, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SAMPLE_WORD, LABEL_TINT_LOUD)


## **A fork waits with the genes** (beam-levels.md §8.3): the slot's fork, half
## size, then the gene's word and its [param level] in its hue. Loud, and
## carrying the gene-in-hand mark, while its cards are [param open]; stepped
## back, like every other chip in the tray, while a waiting gene is in hand
## ([param dimmed]).
static func draw_fork_chip(node: Control, gene: StringName, level: int, open: bool,
		dimmed: bool) -> void:
	var tone := Cilia.hue(gene)
	var ink := 1.0 if open or not dimmed else WAIT_DIM
	node.draw_set_transform(FORK_GLYPH_AT
		- Vector2(FORK_GLYPH_FROM, CHIP_MID) * FORK_GLYPH_SCALE, 0.0,
		Vector2.ONE * FORK_GLYPH_SCALE)
	Cilia.draw_fork(node, Cilia.STRAND_ALONG_X, CHIP_LOBE, CHIP_MID, CHIP_AMP,
		FORK_GLYPH_FROM, FORK_TIPS, FORK_SPREAD, tone, ink)
	node.draw_set_transform(Vector2.ZERO)
	var font := node.get_theme_default_font()
	if font != null:
		var says := word_of(gene)
		node.draw_string(font, Vector2(FORK_WORD_X, FORK_WORD_BASE), says,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_WORD,
			LABEL_TINT_LOUD if open else LABEL_TINT)
		var width := font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			CHIP_WORD).x
		node.draw_string(font,
			Vector2(FORK_WORD_X + width + FORK_LEVEL_GAP, FORK_WORD_BASE),
			str(level), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			level_size(level), Color(tone, LEVEL_FORK_ALPHA * ink))
	if open:
		node.draw_line(Vector2(6.0, FORK_OPEN_Y),
			Vector2(node.size.x - 6.0, FORK_OPEN_Y), Color(tone, 0.55), 1.5, true)
	if node.has_focus():
		node.draw_line(Vector2(FOCUS_INSET, WAIT_SIZE.y - 1.0),
			Vector2(node.size.x - FOCUS_INSET, WAIT_SIZE.y - 1.0),
			FOCUS_TINT, FOCUS_WIDTH, true)


## How wide a fork's chip is, in [param font]: [constant WAIT_SIZE], and wider
## only for a name no word was written for -- `venom 99`, the widest the game
## makes, ends at 111 of 116. A gene with no [param level] has no fork.
static func fork_chip_width(font: Font, gene: StringName, level: int) -> float:
	if font == null or level <= 0:
		return WAIT_SIZE.x
	var width := font.get_string_size(word_of(gene), HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, CHIP_WORD).x
	var digits := font.get_string_size(str(level),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, level_size(level)).x
	return maxf(WAIT_SIZE.x, ceilf(FORK_WORD_X + width + FORK_LEVEL_GAP + digits
		+ WAIT_AIR))


# ---------------------------------------------------------------------------
# The lines under the figure.
# ---------------------------------------------------------------------------

## **The one organ beside a sentence**: [param gene] at [param tier] copies in
## its row's own box -- strokes at full ink if the body wears it or it waits to
## be placed ([param worn]), weaker for a gene only the DNA carries.
##
## The old tiles drew an organ each, which is what taught a point-of-view
## player the cilia vocabulary (genes-and-cilia.md §2.4). The figure now draws
## every organ the body wears, where it wears it; what it cannot draw is a gene
## the body does not wear -- a waiting one, or one only the DNA carries -- and
## seven small tufts round a ring of chips would be the four-tuft mistake
## diegetic-hud.md §2 already made and measured. One, at the thing the player
## is reading, in the row that already exists, keeps the vocabulary and spends
## 30 px.
static func draw_explain_organ(node: Control, gene: StringName, tier: int,
		worn: bool) -> void:
	Cilia.draw_tile_organ(node, gene, tier, EXPLAIN_ORGAN_SEAT,
		Cilia.TILE_STROKE_ALPHA if worn else ORGAN_UNEXPRESSED,
		EXPLAIN_ORGAN_SCALE)


## **A gene's numbers** (gene-stats.md §5.3): [param gene] at [param copies]
## worn and working at [param level] down [param path], in a [param body] of
## [param radius], read at [param slot] -- and, when [param next] is given, the
## strikes to its next level at the end of the costs. Only a worn gene earns, so
## the caller passes it only for one.
static func numbers_lines(gene: StringName, copies: int, level: int,
		path: StringName, body: Dictionary, radius: float, slot: int,
		next: Progression = null) -> Array:
	var lines: Array = GeneStats.lines(gene, copies, level, path,
		GeneStats.context(body, radius), slot)
	if next != null:
		(lines[1] as Array).append(
			GeneStats.progress_item(next.level(), next.to_next()))
	return lines


## One block's two lines, [param said], centred on [param node]: under the
## figure, or under a daughter's line on the choosing screen. [param dim] for a
## gene the body does not wear.
static func draw_numbers(node: Control, said: Array, dim: bool) -> void:
	var font := node.get_theme_default_font()
	if font == null:
		return
	var ink := NUMBERS_DIM if dim else 1.0
	var words := Color(NUMBERS_WORD, NUMBERS_WORD.a * ink)
	var value := Color(NUMBERS_VALUE, NUMBERS_VALUE.a * ink)
	for i in mini(said.size(), 2):
		var items: Array = said[i]
		if items.is_empty():
			continue
		Readout.draw(node, font, NUMBERS_SIZE, Readout.runs(items), node.size.x * 0.5,
			NUMBERS_BASE + NUMBERS_PITCH * float(i), words, value)


## The switch's four boxes, in [constant TOGGLE_STATES]' order.
static func toggle_boxes() -> Array[StyleBoxFlat]:
	var boxes: Array[StyleBoxFlat] = []
	for state: Array in TOGGLE_STATES:
		boxes.append(flat(state[0], TOGGLE_CORNER,
			Color(TOGGLE_EDGE, float(state[2])), int(state[1])))
	return boxes


## **The `numbers` switch**: its slab in one of four states -- [param on], and
## [param hot] or focused -- out of [param boxes] ([method toggle_boxes]), the
## word, and the chips' focus mark when the keyboard is on it.
static func draw_toggle(node: Control, on: bool, hot: bool,
		boxes: Array[StyleBoxFlat]) -> void:
	if boxes.size() < TOGGLE_STATES.size():
		return
	var state := (2 if on else 0) + (1 if hot or node.has_focus() else 0)
	node.draw_style_box(boxes[state], TOGGLE_SLAB)
	var font := node.get_theme_default_font()
	if font != null:
		var says := String(TranslationServer.translate(TOGGLE_WORD))
		var width := font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			TOGGLE_WORD_SIZE).x
		var centre := TOGGLE_SLAB.get_center()
		var base := centre.y + (font.get_ascent(TOGGLE_WORD_SIZE)
			- font.get_descent(TOGGLE_WORD_SIZE)) * 0.5
		node.draw_string(font, Vector2(centre.x - width * 0.5, base), says,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TOGGLE_WORD_SIZE,
			Color(TOGGLE_INK, float(TOGGLE_STATES[state][3])))
	if node.has_focus():
		node.draw_line(Vector2(FOCUS_INSET, TOGGLE_FOCUS_Y),
			Vector2(node.size.x - FOCUS_INSET, TOGGLE_FOCUS_Y), FOCUS_TINT,
			FOCUS_WIDTH, true)


## **The gauge**: [param track], and the share of the level already earned,
## [param progress], in [param gene]'s hue on [param fill] -- one pixel a
## thirty-sixth of a level.
static func draw_gauge(node: Control, gene: StringName, progress: float,
		track: StyleBoxFlat, fill: StyleBoxFlat) -> void:
	node.draw_style_box(track, GAUGE_BAR)
	var earned := roundf(GAUGE_BAR.size.x * progress)
	if earned <= 0.0:
		return
	fill.bg_color = Color(Cilia.hue(gene), GAUGE_FILL_ALPHA)
	node.draw_style_box(fill,
		Rect2(GAUGE_BAR.position, Vector2(earned, GAUGE_BAR.size.y)))


## A plain rounded box, filled, with an edge if one is asked for.
static func flat(fill: Color, radius: int, edge := Color(0.0, 0.0, 0.0, 0.0),
		width := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	if width > 0:
		box.border_color = edge
		box.set_border_width_all(width)
	return box
