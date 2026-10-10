extends "res://game/genes/gene.gd"
## `axoneme`: **the push**. Thrust along the heading while the player holds, in
## units per second squared. **The flagellum made voluntary**: the random
## involuntary impulse keeps firing underneath it at whatever tier the tail is,
## and this adds a push you asked for on top.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **The push's acceleration**, by tier. Held against DRAG these settle at 81 /
## 115 / 155 units per second, against a born cell's realised 56.5. **Measured,
## and the first numbers were wrong by a factor of two**: at 230 the terminal
## speed is 310, and since the chase scales its cruise off the prey's own speed,
## a hunter could not physically close on a pushing cell at any tier. Dread
## stopped meaning anything, which is most of the game.
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const PUSH_ACCEL_BY_TIER: Array[float] = [0.0, 60.0, 85.0, 115.0]


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
const WORDS := {&"axoneme": "push"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"axoneme": "holding on pushes you, instead of only steering"}
## **What its action is called** on an instinct's chip (automation.md §13.1).
##
## TRANSLATORS: The name of an action the player's cell can be told to do by one
## of its "instincts" (rules the player writes: "when <a sense reports
## something> -> <do this>"), on a small chip. Lowercase, a few short words.
## "dash": a burst forward; "push": thrust held on; "hold still": stop the tail
## (the flagellum, which swims) from beating, and keep it still.
## ROOM: 112 px at 15 px
const GENE_SAYS := {&"axoneme.push": "push"}
## **The line that explains it** on the instincts page.
##
## TRANSLATORS: Explains one sense, action or value of the player's "instincts",
## on one line under them: its name (the same words as on its chip), a middle
## dot, then what it is or does, lowercase. "Your ping" is the cell's ampulla,
## which calls and listens; "your beam" its ocellus; "your nose" its chemocyte;
## "your eyespot" its stigma; "your palps" its palp. "Your tail" is the cell's
## flagellum, which swims; "two copies" means the gene is carried twice in the
## cell's DNA, which is what lets the tail be held still. "For free" means it
## costs no food.
## ROOM: 856 px at 15 px
const GENE_EXPLAINS := {
	&"axoneme.push": "push · thrust while this holds, at half or full, paid as you go.",
}


func _init() -> void:
	organ = &"axoneme"
	order = 7
	provides = {&"push_accel": PUSH_ACCEL_BY_TIER}
	# **Uncommon, as every organ a run is built from** (gene-rarity.md §4). This
	# comment once wanted the beam and the voluntary push the rarest things in the
	# water, the two that change the most about a run; the weight they shipped never
	# made them so, and making them `rare` is a balance change, made from play
	# (gene-rarity.md §12).
	water = {"rarity": &"uncommon", "weight": 2, "drifter": true}
	declares = {"out": [{"name": &"push", "claims": [&"push"], "options": [0.5, 1.0]}]}
	# **Its look** (gene-looks.md §6): the flagellum's evolution, so it is the tail's
	# build -- one whip carrying two waves, smooth where the dash's spring is sharp.
	# Moving's shade 2.
	family = MOVING
	look = {"shape": LASH, "shade": 2, "count": 1, "length": 0.50, "wave": 0.22,
		"waves": 2.1}


## **Its numbers on the pause screen** (gene.gd's `lines`): how much holding on adds,
## and what pushing burns.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var cell: Variant = ctx["cell"]
	var burn := float(ctx.get("burn", 1.0))
	var push := stat_at(&"push_accel", t)
	# TRANSLATORS: The thrust gene (`axoneme`, shown as `push`): holding a finger
	# (or a key) on the water pushes the cell instead of only steering it.
	return [[Readout.item("holding on adds up to {} µm a second",
			[push / cell.DRAG], [U.SPEED])],
		[Readout.item("pushing burns {} s a second",
			[push * cell.STROKE_COST * burn], [U.RATE]), wear]]
