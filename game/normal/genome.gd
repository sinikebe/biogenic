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
## and the genome strip on the pause screen -- can react without re-deriving it.
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
## `stigma` is carried, integrated and inherited here like any other gene. What
## it buys is §6's light lobe -- a sharp, certain bearing on **mass**, at its
## tier's width at every range, which dread cannot muffle. It is silent about
## the two cells §1.1 exists to create, and deliberately: a shadow is a fact
## about a body, not about a mouth.
const GENE_ORDER: Array[StringName] = [
	&"cytostome", &"cirrus", &"flagellum", &"stigma",
	&"ocellus", &"axoneme", &"statocyst", &"rhabdom", &"palp", &"myoneme",
	&"trichocyst", &"pellicle", &"toxicyst", &"plastid", &"vacuole", &"crista"]

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
## Expressed twice, which is what having two views is for. Point of view gets a
## second, smaller heartbeat behind every beat (§3.3): `pulse_now()` on a delay,
## in signal_bus.gd's _step_beat, carrying no identity at all -- only *there is
## something in you that is not resolved*. Full vision gets the literal thing, a
## disc of the gene's hue inside the body. §5.2's two-tap swap on the pause
## screen is what resolves it, through [method replace].
var held_sample: StringName = &""
## Seconds left on that sample.
var held_remaining := 0.0

var _tiers := {}
## **Slot index to gene, `&""` for an empty slot.** The dictionary above says
## what this cell has; this says *where*, and where is the arc it is worn on
## (cilia.gd's [method arc_for_slot]). A directional gene reads its facing off
## that arc, so this array is the whole of the player's one placement decision.
##
## It has holes on purpose: a dictionary cannot, and "put the beam in the
## forward-right diagonal while slots 4 and 6 are still empty" needs one.
var _order: Array[StringName] = []
var _cell: CellBody = null


func _ready() -> void:
	if _tiers.is_empty():
		_tiers = BORN.duplicate()
	_sync_order()


## Binds the genome to the body whose radius decides its capacity. Called by
## normal_mode.gd, which also hands the cell a reference back the other way --
## the cell reads its drive constants out of here.
func setup(cell: CellBody) -> void:
	_cell = cell
	reset()


## Every run starts as the basic cell. Death keeps nothing: §9.4.
func reset() -> void:
	_tiers = BORN.duplicate()
	_order = [&"cytostome", &"cirrus", &"flagellum"]
	_sync_order()
	held_sample = &""
	held_remaining = 0.0


func _process(delta: float) -> void:
	_sync_order()
	if held_sample == &"":
		return
	# **A slot opening no longer places the sample, and that is the change.**
	# Phase 5 auto-filled the first free slot, which meant the player only ever
	# chose a slot on the swap path -- that is, only once the genome was full,
	# which is the *end* of a run. The slot is the arc, so auto-placing is the
	# game aiming the player's laser for them. It waits for a tap now.
	#
	# What still resolves itself is the case where there is nothing left for the
	# sample to be: the gene arrived by some other route while it was held.
	if _tiers.has(held_sample):
		integrate_into(_tiers, held_sample, slots())
		held_sample = &""
		held_remaining = 0.0
		return
	held_remaining -= delta
	if held_remaining > 0.0:
		return
	# **A lapse with room still settles.** Forty-five seconds of not choosing is
	# an answer -- "anywhere" -- and throwing the gene away for it would punish
	# a player who never opens the pause screen by quietly deleting the whole
	# progression. With no room it is simply gone, exactly as it always was.
	var free := _first_free()
	if free >= 0:
		_write(free, held_sample)
	held_sample = &""
	held_remaining = 0.0


## Tier of one gene, 0 if the cell does not have that organ.
func tier(gene: StringName) -> int:
	return int(_tiers.get(gene, 0))


## The live `{gene: tier}` map. Read it; do not write it -- [method integrate]
## and [method replace] are the only things allowed to.
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


## A meal's gene, by §3.2's four cases -- with one of them rewritten.
##
## **A gene you do not already carry is always a placement decision**, free slot
## or not. It arrives as a held sample and waits for the player to say which
## slot, because the slot is the arc and the arc is where the organ looks. The
## old behaviour -- drop it in the first empty slot and tell nobody -- gave the
## player a say only once the genome was full, which is the one moment the
## choice is also destructive. Now it is a choice every time, made on the strip
## that already existed, with the two taps that already existed.
##
## Raising a tier is not a placement decision: the organ is already somewhere.
func integrate(gene: StringName) -> int:
	if gene == &"":
		return Result.NOTHING
	if _tiers.has(gene):
		var value := int(_tiers[gene])
		if value >= TIER_MAX:
			return Result.SATURATED
		_tiers[gene] = value + 1
		return Result.RAISED
	# Nothing blocks and nothing is lost yet: the sample waits, and the player
	# is told by a second, smaller heartbeat rather than by a screen. A sample
	# arriving while one is already held replaces it -- the newest thing you
	# swallowed is the one in you.
	held_sample = gene
	held_remaining = SAMPLE_SECONDS
	return Result.HELD


## Puts the held sample over [param gene], at tier 1. §5.2's two-tap swap, and
## §9.7's one irreversible action in the game: the player may drop this over
## their own `cytostome` and fall to gape 0.58r, which cannot be undone. It is
## either a real and interesting mistake or a soft lock, and §1.3's drifter
## floor is what makes it the first -- there is always something small enough
## left to eat.
##
## **The slot the player tapped is the slot the gene lands in**, empty or not.
## That is the one placement decision in the game, and [member _order] is what
## makes it survivable: the gene goes to that index whatever else is empty, so
## the arc it will be worn on is the arc the tile's compass promised.
func place(slot: int) -> int:
	if held_sample == &"":
		return Result.NOTHING
	_sync_order()
	if slot < 0 or slot >= _order.size():
		return Result.NOTHING
	var taking := held_sample
	held_sample = &""
	held_remaining = 0.0
	if _tiers.has(taking):
		# It arrived by another route while the sample was held. Nothing to do,
		# and certainly not a second copy in a second slot.
		return Result.NOTHING
	_write(slot, taking)
	return Result.INTEGRATED


## The gene in each slot, `&""` for empty. Read it; do not write it.
func layout() -> Array[StringName]:
	_sync_order()
	return _order


## Which slot a gene is worn in, or -1. The one question a directional gene
## asks, because the answer is the arc and the arc is the bearing.
func slot_of(gene: StringName) -> int:
	_sync_order()
	return _order.find(gene)


## Puts [param gene] in [param slot], evicting whatever was there.
func _write(slot: int, gene: StringName) -> void:
	var old := _order[slot]
	if old != &"":
		_tiers.erase(old)
	_order[slot] = gene
	_tiers[gene] = 1


func _first_free() -> int:
	_sync_order()
	return _order.find(&"")


## Keeps the layout the width of the body and free of anything the genome no
## longer carries. Growth only ever widens it, so nothing is dropped by this;
## the erase branch is what keeps a swap honest.
func _sync_order() -> void:
	for gene: StringName in _tiers:
		if not _order.has(gene):
			var free := _order.find(&"")
			if free >= 0:
				_order[free] = gene
			else:
				_order.append(gene)
	for i in _order.size():
		if _order[i] != &"" and not _tiers.has(_order[i]):
			_order[i] = &""
	var want := slots()
	while _order.size() < want:
		_order.append(&"")


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
	# `crista` / burn is the one gene that buys upkeep back, and it is applied
	# as a multiplier on the whole bill rather than as a subtraction: it is
	# worth most to the expensive build, which is the one that needs it.
	var burn := CellBody.BURN_BY_TIER[clampi(tier_of(tiers, &"crista"), 0,
		CellBody.BURN_BY_TIER.size() - 1)]
	return (1.0 + UPKEEP_PER_TIER * float(extra)) * burn


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
