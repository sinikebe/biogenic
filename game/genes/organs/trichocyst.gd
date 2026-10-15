extends "res://game/genes/gene.gd"
## `trichocyst`: **the sting**, a contact weapon. A real trichocyst is a spindle
## under the skin that fires its thread when something touches it, and so does
## this one: **whatever touches the body on the arc it is worn on is wounded**,
## food, friend or hunter, whether the cell wants it or not, and then it waits out
## its cooldown (the owner, 2026-10-15: "Sting is a contact weapon. It hurts,
## whether you want it or not"). No instinct and no button fires it: a sting is
## the body's, not a behaviour. **A sting in a rear slot is the answer to being
## flanked**, so placing it is still a defensive decision (`cell.gd`'s
## DART_ARC_DEG). The code still calls the organ's discharge its dart.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit
## How a wound is felt on a body of another size (game/mechanics/doses.gd, which
## preloads nothing).
const Doses := preload("res://game/mechanics/doses.gd")

## **The wound a sting gives**, by tier, as a share of a body the size of a born
## cell -- felt on any other body as `wound x (DOSE_SIZE / r)^2`, as a dose's
## stack is (doses.gd's `felt`), so a big body shrugs off what tears a small one.
## About one born mouth's head-on bite (0.07) at one copy, a little over two at
## three: a sting is a bite you did not have to aim. It never finishes a body
## (cell.gd's STING_MOST). Starting values; balance waits for players.
## The host decides every contact by these: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const DART_WOUND_BY_TIER: Array[float] = [0.0, 0.08, 0.12, 0.16]
## **How long before it can sting again**, by tier: the spindle is spent, and a
## new one has to grow. Kept from the dart it was.
const DART_COOLDOWN_BY_TIER: Array[float] = [0.0, 26.0, 18.0, 11.0]


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
const WORDS := {&"trichocyst": "sting"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"trichocyst": "stings whatever touches that side, on its own"}
## **The line of each of its own slots** (docs/design/gene-sockets.md §2), keyed
## `host.taken`: what the gene in it does to this one, after the slot's word.
##
## TRANSLATORS: What a gene placed in one of another gene's own slots does to that
## gene, in one line shown after the placed gene's word and a middle dot: "venom ·
## every sting leaves it too". "It" is the placed gene. Lowercase, plain words, no
## numbers, no longer than the English: it shares the explanation's line. The
## `entry` line says which gene's slot, then which gene it takes.
## ROOM: 440 px at 15 px
const SOCKET_EXPLAINS := {&"trichocyst.toxin": "every sting leaves it too"}


func _init() -> void:
	organ = &"trichocyst"
	order = 10
	provides = {&"dart_wound": DART_WOUND_BY_TIER, &"dart_cooldown": DART_COOLDOWN_BY_TIER}
	water = {"rarity": &"uncommon", "drifter": true}
	# **Its look** (gene-looks.md §6): spear-headed spines, darts -- a trichocyst's
	# real spindles -- in defending's orange.
	family = DEFENDING
	look = {"shape": SPINES, "shade": 2, "length": 0.32, "tip": Kinds.TIP_SPEAR}
	# **Its own slot** (gene-sockets.md §3 row 1): a toxin in it, and every sting
	# leaves the toxin's dose as well -- the venom a bite at the front leaves at the
	# same copies (toxin.gd's VENOM_STACKS_BY_TIER): a sting is a bite you did not
	# have to aim. Starting values; balance waits for players.
	sockets = [{"takes": [&"toxin"], "gives": {&"sting_dose": [0.0, 1.0, 2.0, 3.0]}}]


## **Its numbers on the pause screen** (gene.gd's `lines`): what its sting takes out
## of a body your size, how wide it guards, and how often.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var cell: Variant = ctx["cell"]
	var wound := stat_at(&"dart_wound", t) * Doses.felt(1.0,
		float(ctx.get("radius", cell.BASE_RADIUS)), cell.DOSE_SIZE)
	# TRANSLATORS: The sting gene (`trichocyst`, shown as `sting`): whatever touches
	# that side of the body is stung. "takes {} of a body your size" is the wound,
	# a percentage; "{} either side" is the angle, in degrees, to each side of the
	# middle of that side that it covers.
	return [[Readout.item("a sting takes {} of a body your size, {} either side",
			[wound, cell.DART_ARC_DEG * 0.5], [U.SHARE, U.ANGLE]),
		Readout.item("again after {} s", [stat_at(&"dart_cooldown", t)],
			[U.TIME])],
		[wear]]
