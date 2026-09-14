extends Node
## What a cell is made of: which organs it has, at what tier, and what that
## costs it to carry.
##
## Genome size is **capacity, not currency** -- there are no genetic points.
## Slots come from body radius (cell.gd's ladder), and what fills them comes
## from what the cell has eaten: you absorb whatever the prey was most made of.
## Every tier above the first raises the metabolic rate, so a strong build is
## one that starves. docs/design/genes-and-cilia.md §3.
##
## This node **computes and does not post**, exactly like food.gd: normal_mode.gd
## reads [method upkeep] once a frame and writes it to metabolism, and it stays
## the only node in the run that talks to the signal bus. A genome that emitted
## its own sensations would be a second door into the membrane.
##
## The statics at the bottom are the same rules applied to a plain
## `{gene: tier}` dictionary, because every other cell in the water carries one
## of those (food.gd) and there must not be two definitions of what a genome
## does. Only the player's genome is a node; a node per drifter would be four
## nodes of overhead to hold four dictionaries.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")

## What eating something did. Returned by [method integrate] so the caller --
## and, in Phase 5B, the genome strip -- can react without re-deriving it.
enum Result {
	NOTHING,     ## the prey carried no gene, or there was nothing to do
	INTEGRATED,  ## a new gene, at tier 1, in a free slot
	RAISED,      ## a gene already held, one tier higher
	SATURATED,   ## already at TIER_MAX: nutrition only
	HELD,        ## no free slot: the sample waits SAMPLE_SECONDS for a decision
	NO_ROOM,     ## the static half's answer to HELD -- see integrate_into()
}

## Three organs, three tiers. Tier 0 is "does not have this organ at all", which
## is a real state: drifters have no cytostome (§1.3), and §9.7 lets the player
## put a fourth gene over their own mouth and live with the consequences.
const TIER_MAX := 3

## Arc order, from §4.1, and therefore the tie-break for [method dominant_of]:
## the body is drawn in this order, so the cell you can see is the gene you get.
## Genes outside this list are later phases' and sort after it, in genome order.
##
## Phase 5B: `stigma` is carried, integrated and inherited here like any other
## gene, and it does nothing yet -- §6 gives it the light lobe, which needs
## LOBE_LIGHT in signal_bus.gd. A slot spent on it today is a slot spent on
## nothing, which is §9.7's irreversible mistake arriving early.
const GENE_ORDER: Array[StringName] = [
	&"cytostome", &"cirrus", &"flagellum", &"stigma"]

## The starting cell is already full: three slots, three organs, all tier 1.
## You are not an empty vessel; you are mediocre at three things. §1.
const BORN := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}

## The price of power, paid in the one channel the game already reads -- the
## beat. One tier-3 gene starves in 420 / 1.36 = 309s. §3.2, and the owner has
## settled that this ships at 0.18 to be judged by playing (§9.3).
const UPKEEP_PER_TIER := 0.18

## How long a sample waits for a slot before it is simply gone. There is no
## discard control and there does not need to be one. §3.3.
const SAMPLE_SECONDS := 45.0

## The gene whose sample is waiting for a free slot, or &"" for none.
##
## Phase 5B: this is the state, and nothing yet expresses it. §3.3 puts a second,
## smaller heartbeat behind every beat while a sample is held -- `pulse_now()` on
## a delay, in signal_bus.gd's _step_beat -- and full vision draws it as a disc
## of the gene's hue inside the body. §5.2's two-tap swap is what resolves it.
## Both are the rendering half; the clock below runs regardless, so a sample
## already lapses at the right time.
var held_sample: StringName = &""
## Seconds left on that sample.
var held_remaining := 0.0

var _tiers := {}
var _cell: CellBody = null


func _ready() -> void:
	if _tiers.is_empty():
		_tiers = BORN.duplicate()


## Binds the genome to the body whose radius decides its capacity. Called by
## normal_mode.gd, which also hands the cell a reference back the other way --
## the cell reads its drive constants out of here.
func setup(cell: CellBody) -> void:
	_cell = cell
	reset()


## Every run starts as the basic cell. Death keeps nothing: §9.4.
func reset() -> void:
	_tiers = BORN.duplicate()
	held_sample = &""
	held_remaining = 0.0


func _process(delta: float) -> void:
	if held_sample == &"":
		return
	held_remaining -= delta
	if held_remaining <= 0.0:
		held_sample = &""
		held_remaining = 0.0


## Tier of one gene, 0 if the cell does not have that organ.
func tier(gene: StringName) -> int:
	return int(_tiers.get(gene, 0))


## The live `{gene: tier}` map. Read it; do not write it -- [method integrate]
## is the only thing allowed to, and Phase 5B's swap will go through here too.
func tiers() -> Dictionary:
	return _tiers


## How many slots the body can carry right now. The arithmetic lives in cell.gd
## next to the radius it is made of; this is the accessor everything else uses.
func slots() -> int:
	return CellBody.slots_for(_cell.radius) if _cell != null else CellBody.SLOT_MIN


## How many are in use.
func filled() -> int:
	return _tiers.size()


## The metabolic multiplier, 1.0 for a cell that is tier 1 across the board.
func upkeep() -> float:
	return upkeep_of(_tiers)


## What this cell is most made of, which is what eating it gives you. §3.4.
func dominant() -> StringName:
	return dominant_of(_tiers)


## A meal's gene, by §3.2's four cases. Returns which one happened.
func integrate(gene: StringName) -> int:
	var result := integrate_into(_tiers, gene, slots())
	if result != Result.NO_ROOM:
		return result
	# Nothing blocks and nothing is lost yet: the sample waits, and the player
	# is told by a second, smaller heartbeat rather than by a screen. A sample
	# arriving while one is already held replaces it -- the newest thing you
	# swallowed is the one in you.
	held_sample = gene
	held_remaining = SAMPLE_SECONDS
	return Result.HELD


# ---------------------------------------------------------------------------
# The same rules, on a plain dictionary. Every other cell in the water carries
# one of these, and they must obey exactly the rules the player's genome does --
# that is the whole of §1.2, and the moment there are two definitions of "can
# this eat that" the water stops being the same game as the player is playing.
# ---------------------------------------------------------------------------

static func tier_of(tiers: Dictionary, gene: StringName) -> int:
	return int(tiers.get(gene, 0))


static func upkeep_of(tiers: Dictionary) -> float:
	var extra := 0
	for value: int in tiers.values():
		extra += maxi(value - 1, 0)
	return 1.0 + UPKEEP_PER_TIER * float(extra)


## The highest-tier gene, ties broken by arc order. Deterministic on purpose:
## the dominant gene is also what the cell looks like, so what you can see
## before you commit is exactly what you get.
static func dominant_of(tiers: Dictionary) -> StringName:
	var best: StringName = &""
	var best_tier := 0
	for gene: StringName in GENE_ORDER:
		var value := int(tiers.get(gene, 0))
		if value > best_tier:
			best_tier = value
			best = gene
	for gene: StringName in tiers:
		if GENE_ORDER.has(gene):
			continue
		var value := int(tiers[gene])
		if value > best_tier:
			best_tier = value
			best = gene
	return best


## Writes [param gene] into [param tiers] in place. [param capacity] is how many
## slots the body has. Returns a [enum Result]; a full genome comes back as
## NO_ROOM, which only the node half knows what to do about (it holds it).
static func integrate_into(tiers: Dictionary, gene: StringName, capacity: int) -> int:
	if gene == &"":
		return Result.NOTHING
	if tiers.has(gene):
		var value := int(tiers[gene])
		if value >= TIER_MAX:
			return Result.SATURATED
		tiers[gene] = value + 1
		return Result.RAISED
	if tiers.size() >= capacity:
		return Result.NO_ROOM
	tiers[gene] = 1
	return Result.INTEGRATED
