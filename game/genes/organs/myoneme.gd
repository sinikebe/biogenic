extends "res://game/genes/gene.gd"
## `myoneme`: **the dash**. A burst of speed for a tap, paid for in hunger -- a
## better myoneme is a cheaper dash, not a bigger one, so it stays a decision.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **The burst**, by tier.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const DASH_SPEED_BY_TIER: Array[float] = [0.0, 190.0, 240.0, 300.0]
## **What a dash costs, as a share of a born cell's tank**: 2.2, 1.6 and 1.2 s
## of rest. The run pays it as those seconds, through metabolism.gd's `spend`,
## like every other cost, so `crista` makes it cheaper and a bigger `vacuole`
## tank makes it a smaller share (gene-stats.md §11, owner's call 2, answered
## *yes* on 2026-09-29). It was a fixed share of the bar that neither softened;
## a born cell pays what it did.
const DASH_COST_BY_TIER: Array[float] = [0.0, 0.060, 0.045, 0.032]


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
const WORDS := {&"myoneme": "dash"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"myoneme": "tap for a burst of speed, paid for in hunger"}
## **What its action is called** on an instinct's chip (automation.md §13.1).
##
## TRANSLATORS: The name of an action the player's cell can be told to do by one
## of its "instincts" (rules the player writes: "when <a sense reports
## something> -> <do this>"), on a small chip. Lowercase, a few short words.
## "dash": a burst forward; "push": thrust held on; "hold still": stop the tail
## (the flagellum, which swims) from beating, and keep it still.
## ROOM: 112 px at 15 px
const GENE_SAYS := {&"myoneme.dash": "dash"}
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
const GENE_EXPLAINS := {&"myoneme.dash": "dash · a burst forward, on its cooldown, paid in hunger."}


func _init() -> void:
	organ = &"myoneme"
	order = 9
	provides = {&"dash_speed": DASH_SPEED_BY_TIER, &"dash_cost": DASH_COST_BY_TIER}
	water = {"weight": 2, "drifter": true}
	declares = {"out": [{"name": &"dash", "claims": [&"dash"]}]}
	# **Its look** (gene-catalogue.md §7.1): a tuft of five, in the rose cilia.gd
	# held in reserve (genes-and-cilia.md §4.4).
	look = {"shape": TUFT, "hue": Color(0.94, 0.42, 0.68), "count": 5}  # dash, 333 deg


## **Its numbers on the pause screen** (gene.gd's `lines`): how hard a dash bursts, how
## often, and what it burns.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var cell: Variant = ctx["cell"]
	var metabolism: Variant = ctx["metabolism"]
	var burn := float(ctx.get("burn", 1.0))
	var burst := stat_at(&"dash_speed", t)
	# **Seconds of rest, scaled by `crista`** (owner's call 2, §11): the
	# run pays a dash through metabolism.gd's `spend`, as every other
	# cost is paid, so a bigger tank no longer makes it dearer.
	#
	# TRANSLATORS: The burst-of-speed gene (`myoneme`, shown as `dash`): a tap
	# gives a short burst. "Again after {} s" is the wait before the next one.
	return [[Readout.item("a burst of {} µm a second, about {} µm in all",
			[burst, burst / cell.DRAG], [U.SPEED, U.DISTANCE]),
		Readout.item("again after {} s", [cell.DASH_COOLDOWN], [U.TIME])],
		[Readout.item("each dash burns {} s", [stat_at(&"dash_cost", t)
			* metabolism.HUNGER_SECONDS * burn], [U.ENERGY]), wear]]
