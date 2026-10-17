extends "res://game/genes/gene.gd"
## **The toxin** (docs/design/dna-slots.md §3, §6): one organ in two places.
## Inside it is `veneneux`, poison -- French for *poisonous*, the name it shipped
## under -- for whatever bites or swallows the body. **In a gene's own slot** it is
## `toxicyst`, venom -- the real organ, the harpoon hunting ciliates fire from round
## their mouths -- on every bite of the mouth whose slot holds it, and every sting
## of the sting's (docs/design/gene-sockets.md). Doses replace both of what the old
## `veneneux` did: stacks that wear off over seconds and act while they last
## (`cell.gd`'s dose numbers).
##
## **Never on the body's outside slots** (the owner, 2026-10-16: *"Eat + toxin does
## the same as toxin outside. Remove toxin outside. Toxin can only be in eat or
## inside body."*). Venom at the front was the mouth's slot's venom by another
## road, so the road went: `toxicyst` is a form of the riding place
## ([constant RIDING]), which the body never wears and the outside slots refuse.
## A save that wore it outside puts it in the mouth's slot (genome.gd's
## `_put_in_place`).
##
## **Its one variant is its corrosive strain**, whose dose is harm. A second
## strain is a second entry in [member variants], with its own two keys
## (dna-slots.md §8.3): every rule that reads forms already covers it. The keys
## are permanent once shipped, because saves and the wire keep them, and the
## name on screen is its NAMES below, not the key.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit
## The kinds of load (game/mechanics/doses.gd, which preloads nothing): what one
## stack of a dose does.
const Doses := preload("res://game/mechanics/doses.gd")

## `veneneux` / **poison**, inside: the stacks whatever bites the body takes, a
## bite, by copies -- the price of chewing a poisonous cell, in place of the old
## bite-back share.
## The host decides every contact by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const POISON_STACKS_BY_TIER: Array[float] = [0.0, 1.0, 2.0, 3.0]
## **And what whatever swallows it takes**, by copies: one copy takes 0.8 of a
## born swallower, three kill anything up to r40. The swallowed body is eaten all
## the same (owner's row 5): nobody is spat out any more.
## The host decides every contact by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const SWALLOW_STACKS_BY_TIER: Array[float] = [0.0, 16.0, 32.0, 48.0]


# --- Its words (gene.gd; gene-catalogue.md §8.1) -------------------------------------

## **Its chip word** (gene.gd's word tables): the plain word, never the biological
## name -- one short word for what it does, read at arm's length (figure.gd).
##
## TRANSLATORS: A gene's name as the player reads it on a chip beside three small
## dots: one short lowercase word, a verb or a noun for what the gene does. The
## `entry` line says which gene it names (its scientific name, never translated).
## It has to be short: prefer the shortest everyday word. The same words appear
## inside sentences such as "let go to swap eat and ping".
## ROOM: 47 px at 13 px
const WORDS := {
	&"veneneux": "poison",
	&"toxicyst": "venom",
}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. The `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {
	&"veneneux": "whatever bites or swallows you takes your poison",
	&"toxicyst": "your bite leaves venom, which goes on hurting",
}
## **A toxin not yet placed is neither form**: the tray, the hand and a drag call
## it this until it lands (dna-slots-ux.md §3.5).
##
## TRANSLATORS: The word for a toxin gene that has been eaten and is waiting to be
## placed, on its chip in the tray and on a finger dragging it. Placed in the slot
## of another gene, such as the mouth's, it becomes `venom`; inside the body it
## becomes `poison`; until then it is neither.
## One short lowercase word, like the other gene words.
## ROOM: 47 px at 13 px
const CARRIED_WORDS := {&"veneneux": "toxin", &"toxicyst": "toxin"}
## **And its line in hand**, before a slot says which form it becomes.
##
## TRANSLATORS: The gene line for a toxin that is waiting, before a slot is
## chosen: it hurts over time, and becomes venom or poison depending on where it
## is placed. After the gene's scientific name and a middle dot. No longer than
## the English.
## ROOM: 440 px at 15 px
const CARRIED_EXPLAINS := {
	&"veneneux": "a toxin that goes on hurting, as venom or as poison",
	&"toxicyst": "a toxin that goes on hurting, as venom or as poison",
}
## **Its name on screen**, where it is not its key (owner's row 1): both
## forms are `toxicyst`. Not translated: a scientific name.
const NAMES := {&"veneneux": "toxicyst", &"toxicyst": "toxicyst"}


func _init() -> void:
	organ = &"toxin"
	# **No drifter carries it, and the floor gives it back through a peer**
	# (gene-catalogue.md §6.4; dna-slots.md §9): the drop's defenceless food stays
	# harmless to eat, and a mouthless drifter's venom would bite nothing anyway.
	# Every strain inherits both.
	tags = [NOT_ON_DRIFTERS, FLOOR_BY_PEERS]
	# **Uncommon, as every organ a run is built from** (gene-rarity.md §4): the
	# organ's class, which every strain shares unless it sets its own -- a strain that
	# sets none splits the toxin's place in the water evenly with its siblings, the
	# die dna-slots.md §8.3 asks for. Its drifter flag is the strain's own, below: a
	# strain that sets none is no part of the water's pool, and takes nothing of its
	# siblings' place there (gene-catalogue.md §15.8).
	water = {"rarity": &"uncommon"}
	variants = [
		# The first form listed is the variety: the name the toxin goes by where no
		# place is known yet -- the water's draws, the floor's count, and two meals
		# in the tray found to be one. `veneneux` was the gene before there were
		# places, so it is the inside form and comes first.
		{"variant": &"corrosive", "dose": &"harm",
			"water": {"drifter": true},
			"forms": {
				INSIDE: {"key": &"veneneux", "order": 12,
					"provides": {&"poison_stacks": POISON_STACKS_BY_TIER,
						&"swallow_stacks": SWALLOW_STACKS_BY_TIER}},
				# Appended, last, when there came to be places: at the end so that
				# no tie between two genes that already existed changed. Outside
				# once; riding since 2026-10-16, when the body's outside slots
				# stopped taking it. A rider provides the body nothing: what it
				# gives its gene is that gene's slot's own table.
				RIDING: {"key": &"toxicyst", "order": 16},
			}},
	]
	# **Its look** (gene-looks.md §2.1, §3.3): bead-headed spines, two a copy, drawn
	# by place -- fangs on the lips of a mouth whose slot holds it, and inside their
	# beads alone, granules under the whole skin (cilia.gd). **Every strain wears
	# defending's orange**, the colour of warning, in both its forms, and is told by
	# its beads: a strain after this one sets an accent -- a paralysing one's beads
	# are diamonds, a sleeping one's rings (dna-slots-ux.md §2.6) -- and a load is
	# drawn in the hue of the organ that delivered it. Lime, corrosive's hue of its
	# own, went with the families.
	family = DEFENDING
	look = {"shape": SPINES, "tip": Kinds.TIP_BEAD, "per_copy": 2, "length": 0.26,
		"fan": 16.0, "lips": true}


## **Its numbers on the pause screen** (gene.gd's `lines`): poison's, inside. Venom
## rides in a gene's slot, and a slot's gene shows no numbers of its own: what it
## gives is its slot's line (gene-sockets.md §5).
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	if place == INSIDE:
		return _poison_lines(t, ctx, wear)
	return [[], [wear]]


## **Poison** (§3.3): what a biter takes a bite and a swallower takes in one,
## then what one stack does.
##
## TRANSLATORS: The poison gene (`veneneux`, shown as `poison`), inside the cell:
## whatever bites the cell takes this many "stacks" of poison with each bite, and
## whatever swallows it takes this many at once. A "stack" is one dose of the
## toxin. Give the forms your language needs for the count.
func _poison_lines(tier: int, ctx: Dictionary, wear: Dictionary) -> Array:
	var bite := stat_at(&"poison_stacks", tier)
	var gulp := stat_at(&"swallow_stacks", tier)
	return [[Readout.item_n("whatever bites you takes {} stack a bite",
			"whatever bites you takes {} stacks a bite", int(roundf(bite)), [bite],
			[U.COUNT]),
		Readout.item_n("a swallower takes {} stack", "a swallower takes {} stacks",
			int(roundf(gulp)), [gulp], [U.COUNT])],
		_with_dose([], ctx) + [wear]]


## [param items] with what one stack of this key's dose does after them, where its
## kind has a line ([method dose_line]).
func _with_dose(items: Array, ctx: Dictionary) -> Array:
	var said := dose_line(ctx)
	if not said.is_empty():
		items.append(said)
	return items


## **What one stack of this strain's dose does** (gene.gd's `dose_line`), read off
## its own [member dose] -- the 1b review's finding 4: a second strain says its own
## kind, never harm's. **Harm** takes a share of a body the reader's size, diluted as
## every dose is (doses.gd's `felt`), over the stack's life down to the cutoff --
## `tau x ln(1 / DOSE_GONE)`, 9.7 s for harm. A kind with no line yet says nothing
## here, and the gene probe fails a live strain of it until it has one.
##
## TRANSLATORS: What one "stack" (one dose) of a toxin does: it takes this share
## of a body the size of the player's cell, a percentage, over this many seconds.
func dose_line(ctx: Dictionary) -> Dictionary:
	var kind := Doses.kind_of(dose)
	if kind != Doses.Kind.HARM:
		return {}
	var cell: Variant = ctx["cell"]
	var share: float = cell.HARM_PER_STACK * Doses.felt(1.0,
		float(ctx.get("radius", cell.BASE_RADIUS)), cell.DOSE_SIZE)
	var life: float = cell.DOSE_TAU_BY_KIND[kind] * log(1.0 / cell.DOSE_GONE)
	return Readout.item("a stack takes {} of a body your size over {} s", [share, life],
		[U.SHARE, U.TIME])
