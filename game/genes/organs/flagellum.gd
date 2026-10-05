extends "res://game/genes/gene.gd"
## `flagellum`: **the tail**. It fires a random forward impulse on its own
## schedule and the cell coasts (docs/design/perception.md §2): sluggish and
## slippery on purpose.
##
## Tier 0 is the cell that has lost this organ entirely (§9.7 allows it). It is
## **not in the design**: its tables are extrapolated one step below tier 1 on the
## ladder's own spacing, which is the least invented answer available.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit

## **Speed added along the heading by one beat**, by tier.
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const IMPULSE_SPEED_BY_TIER: Array[float] = [118.0, 138.0, 162.0, 190.0]
## **Seconds between impulses**, resampled after each one, by tier.
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const IMPULSE_GAP_MIN_BY_TIER: Array[float] = [2.00, 1.70, 1.45, 1.20]
const IMPULSE_GAP_MAX_BY_TIER: Array[float] = [4.30, 3.60, 3.00, 2.50]

## **A tail can be held still from its second copy** (docs/design/
## automation.md §5.2, rows 29, 37 and 38): the one number the hand's hold and
## a body's rules both ask, of the tail's level -- `genome.gd`'s `level_of`,
## which for every gene but the beam is its worn copies. A held tail does not
## beat, costs nothing, and **keeps its clock**: the stroke clock stands still
## and is never reset, so two strokes are never closer than the shortest gap
## above however a hold comes and goes (`cell.gd`'s `_process`). Below it the
## tail beats on its own, for every body that swims. Not a table a host's
## referee judges by: a held tail only ever makes a body slower.
const HOLD_LEVEL := 2


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
const WORDS := {&"flagellum": "swim"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"flagellum": "your tail beats harder, and more often"}
## **What its action is called** on an instinct's chip (automation.md §13.1).
##
## TRANSLATORS: The name of an action the player's cell can be told to do by one
## of its "instincts" (rules the player writes: "when <a sense reports
## something> -> <do this>"), on a small chip. Lowercase, a few short words.
## "dash": a burst forward; "push": thrust held on; "hold still": stop the tail
## (the flagellum, which swims) from beating, and keep it still.
## ROOM: 112 px at 15 px
const GENE_SAYS := {&"flagellum.hold": "hold still"}
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
	&"flagellum.hold": "hold still · hold your tail still and keep steering, for free. needs two"
		+ " copies of your tail.",
}
## **What an instinct using it says while it waits for its level.**
##
## TRANSLATORS: Said of an "instinct" (a rule the player wrote) that cannot act
## yet, because the action it uses needs a gene carried twice. "Asleep" is the
## state's name; "two copies of your tail" means the tail gene (the flagellum)
## carried twice in the cell's DNA. Lowercase.
## ROOM: 856 px at 14 px
const GENE_ASLEEP := {&"flagellum.hold": "asleep: needs two copies of your tail"}
## **What the page says when it is picked too early.**
##
## TRANSLATORS: Said when the player picks an action their cell cannot do yet,
## because it needs a gene carried twice. "hold still" is the action's name, as on
## its chip; "two copies of your tail" means the tail gene (the flagellum)
## carried twice in the cell's DNA. Lowercase.
## ROOM: 856 px at 14 px
const GENE_NEEDS := {&"flagellum.hold": "hold still needs two copies of your tail"}


func _init() -> void:
	organ = &"flagellum"
	order = 2
	provides = {&"impulse_speed": IMPULSE_SPEED_BY_TIER,
		&"impulse_gap_min": IMPULSE_GAP_MIN_BY_TIER,
		&"impulse_gap_max": IMPULSE_GAP_MAX_BY_TIER}
	numbers = {&"hold_level": HOLD_LEVEL}
	water = {"weight": 4, "drifter": true}
	born = 1
	# **The hold** (automation.md §4.3): it holds the tail still and only the
	# tail, claiming the `swimming` trigger `body.swim` claims, from the second
	# copy (rows 29 and 38). Declared last of every gene's parts, so its owner's
	# bits come after every other.
	declares = {"out": [{"name": &"hold", "claims": [&"swimming"], "level": HOLD_LEVEL}]}
	# **Its look** (gene-catalogue.md §7.1): the lash at the stern, six strands. Six
	# on its tile too, 17 px long: the tallest organ on a tile, which the explaining
	# line's glyph is measured by (figure.gd's EXPLAIN_ORGAN_SEAT).
	look = {"shape": LASH, "hue": Color(0.80, 0.42, 0.95), "count": 6,  # swim, 291 deg
		"tile_count": 6, "tile_length": 17.0}


## **Its numbers on the pause screen** (gene.gd's `lines`): how fast it swims, how often
## it beats, and what beating burns.
func lines(t: int, _level: int, _path: StringName, ctx: Dictionary, _slot: int,
		wear: Dictionary) -> Array:
	var cell: Variant = ctx["cell"]
	var burn := float(ctx.get("burn", 1.0))
	var low := stat_at(&"impulse_gap_min", t)
	var high := stat_at(&"impulse_gap_max", t)
	var beat: float = (ctx["beat"] as Callable).call(stat_at(&"impulse_speed", t), burn)
	# TRANSLATORS: The tail gene (`flagellum`, shown as `swim`). "A beat" is one
	# stroke of the tail. "µm" is micrometres, the unit of distance in the game
	# world; keep it.
	return [[Readout.item("swims about {} µm a second", [cell.speed_of({key: t})],
			[U.SPEED]),
		Readout.item("a beat every {}–{} s", [low, high], [U.TIME, U.TIME])],
		[Readout.item("beating burns {} s a second, {} s a beat",
			[beat / ((low + high) * 0.5), beat], [U.RATE, U.ENERGY]), wear]]
