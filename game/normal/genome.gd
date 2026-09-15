extends Node
## What a cell is made of: which organs it has, at what tier, and what that
## costs it to carry.
##
## **Two registers, and they are the whole of docs/design/lifecycle.md §1.** A
## body is fixed; a genome is not. The cell you are swimming is the genome you
## were born with, expressed whole, and nothing you eat this life changes it.
## What you eat writes **DNA**, and DNA is what your daughters are made of.
##
## So this node holds a pair of maps rather than one:
##
## - [method tiers] / [method tier] are **the body**: what is drawn, what the
##   drive reads, what upkeep is paid on, what eating you would give. Written
##   once, at birth, by [method express].
## - [method dna] / [method dna_tier] are **what you are writing**: the strip on
##   the pause screen, the thing a daughter is made of. Written by eating.
##
## At birth the two are identical, which is what "expressed whole" means. They
## diverge over one generation and are made one again by the next division.
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
## `chemocyte` and `ampulla` are inserted after `ocellus` rather than anywhere
## more natural, so that no tie between two genes that already existed changes
## which one a body is drawn as.
const GENE_ORDER: Array[StringName] = [
	&"cytostome", &"cirrus", &"flagellum", &"stigma",
	&"ocellus", &"chemocyte", &"ampulla",
	&"axoneme", &"statocyst", &"rhabdom", &"palp", &"myoneme",
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

# --- Expression: a copy is a chance, and three copies is a certainty ---------
# docs/design/dna-strand.md §3. **Eating a gene puts it in the DNA; the DNA is
# what a daughter is rolled from.** Every locus on the strand carries between
# one and three copies -- what the tier ladder has always counted -- and copy
# number is what decides whether a daughter wears the organ at all.
#
# Gene dosage is real: more copies of a gene means more of it is transcribed.
# That is the whole justification for hanging this on the tier rather than
# inventing a second number, and it is why the strand draws the tier as
# **rungs** and not as pips.

## Indexed by copies. One copy is a coin toss, two is likely, three is certain
## -- so a player who wants a gene guaranteed can buy the guarantee by feeding
## it, which is the answer to "a chance takes determinism out of the build".
const EXPRESS_CHANCE: Array[float] = [0.0, 0.55, 0.80, 1.00]

## **The mouth always expresses.** The same argument [method _mutate_drift]
## already makes: a daughter born with no cytostome is not one of two builds to
## choose between, it is a body that cannot feed itself, and nobody would pick
## it. One exception, named, rather than a rule with a soft edge.
const ALWAYS_EXPRESSED: Array[StringName] = [&"cytostome"]

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

## **Slots the body did not earn.** Exactly one thing grants these: the free
## sensing gene normal_mode.gd hands over at five seconds.
##
## It exists because the born cell is *already full* -- three slots, three
## organs -- so a sample granted into it would have nowhere to lapse to and
## would simply evaporate after forty-five seconds, leaving a player who never
## opened the pause screen with no sense at all. That is the one outcome the
## grant exists to make impossible, so the gift comes with somewhere to put it.
##
## It is absorbed rather than permanent: [method slots] still clamps at
## SLOT_MAX, so by the time the body has earned seven the leg-up is gone. Reset
## with everything else on death.
var bonus_slots := 0

## The DNA: what this cell is writing, and what its daughters will be.
var _dna := {}
## **Slot index to gene, `&""` for an empty slot.** The dictionary above says
## what this DNA carries; this says *where*, and where is the arc it is worn on
## (cilia.gd's [method arc_for_slot]). A directional gene reads its facing off
## that arc, so this array is the whole of the player's one placement decision.
##
## It has holes on purpose: a dictionary cannot, and "put the beam in the
## forward-right diagonal while slots 4 and 6 are still empty" needs one.
##
## **It may be longer than [method slots], and that is intended**: a newborn
## carries her mother's whole DNA on a body two thirds the size, so she may
## replace but not add until she grows.
var _order: Array[StringName] = []

## The body: what this cell actually wears, fixed at birth.
var _body := {}
## Gene to slot for the body, also fixed at birth. A dictionary rather than an
## array because the only question ever asked of it is *which arc is this organ
## on*, and because the body may keep an organ the DNA has since replaced --
## which an index into the DNA's layout could not express.
var _body_slots := {}

## The one gene that is expressed on the body it lands on rather than only on
## the DNA: normal_mode.gd's five-second grant. §6 calls it an invariant against
## blindness, and an invariant that only rescued the *next* generation would not
## be one. It is not a meal -- it is the body growing an organ it was born able
## to grow -- so it is the one thing that does not wait for a division.
var _gift: StringName = &""

var _cell: CellBody = null


func _ready() -> void:
	if _dna.is_empty():
		express(BORN, [&"cytostome", &"cirrus", &"flagellum"])
	_sync_order()


## Binds the genome to the body whose radius decides its capacity. Called by
## normal_mode.gd, which also hands the cell a reference back the other way --
## the cell reads its drive constants out of here.
func setup(cell: CellBody) -> void:
	_cell = cell
	reset()


## Every run starts as the basic cell. **A run keeps nothing; a lineage keeps
## everything** -- lifecycle.md §1.5, replacing §9.4. Death is still a clean
## restart as the born cell, three organs, all tier 1.
func reset() -> void:
	express(BORN, [&"cytostome", &"cirrus", &"flagellum"])


## **A body born of a DNA.** The two registers are set here and nowhere else: a
## division, a death, and the dev harness forcing a genome. [param dna] and
## [param order] are copied, never held.
##
## [param body] is **what of that DNA this body actually wears**, and it is what
## the expression roll ([method expressed]) returns. Left `null` it means
## *expressed whole*, which is what a run's first cell and a forced genome both
## are; a daughter is handed a rolled subset instead, and whatever failed to
## express stays in her DNA to be rolled again by her own daughters.
##
## **`null` and not an empty dictionary**, because "nothing expressed" is a real
## roll: a DNA with no cytostome in it has no guaranteed gene, and every other
## locus can miss. Defaulting on emptiness would silently express that cell
## whole -- the one body the roll had just said should be bare.
func express(dna: Dictionary, order: Array, body: Variant = null) -> void:
	_dna = dna.duplicate()
	_order = []
	for gene: Variant in order:
		_order.append(StringName(gene))
	_body = (body as Dictionary).duplicate() if body != null else _dna.duplicate()
	_body_slots = {}
	for slot in _order.size():
		var gene: StringName = _order[slot]
		if gene != &"" and _body.has(gene):
			_body_slots[gene] = slot
	bonus_slots = 0
	_gift = &""
	held_sample = &""
	held_remaining = 0.0
	_sync_order()


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
	if _dna.has(held_sample):
		# It arrived by another route. If it was the anti-blindness grant, it
		# still has to land on the *body* -- otherwise eating the same gene
		# inside the forty-five seconds would quietly cancel the one rescue in
		# the game and leave a blind cell blind.
		if held_sample == _gift:
			_express_gift(held_sample, _order.find(held_sample))
		integrate_into(_dna, held_sample, maxi(slots(), _order.size()))
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


## Tier of one organ **this body wears**, 0 if it does not wear it. This is what
## the drive, the gape and every encounter in the water read: a tier raised in
## the DNA this life is a tier your daughters get, not one you grow.
func tier(gene: StringName) -> int:
	return int(_body.get(gene, 0))


## The live `{gene: tier}` map of **the body**. Read it; do not write it. It is
## what draw_cell draws, what upkeep is paid on and what eating this cell would
## give, because all three are questions about the organism and not about what
## it is writing.
func tiers() -> Dictionary:
	return _body


## The live `{gene: tier}` map of **the DNA**. Read it; do not write it --
## [method integrate] and [method place] are the only things allowed to.
func dna() -> Dictionary:
	return _dna


## Tier of one gene in the DNA, 0 if the lineage does not carry it.
func dna_tier(gene: StringName) -> int:
	return int(_dna.get(gene, 0))


## How many slots the body can carry right now. The arithmetic lives in cell.gd
## next to the radius it is made of; this is the accessor everything else uses.
func slots() -> int:
	var earned := CellBody.slots_for(_cell.radius) if _cell != null else CellBody.SLOT_MIN
	return clampi(earned + bonus_slots, CellBody.SLOT_MIN, CellBody.SLOT_MAX)


## How many DNA slots are in use.
func filled() -> int:
	return _dna.size()


## The metabolic multiplier, 1.0 for a cell that is tier 1 across the board.
##
## **Paid on the body, not on the DNA.** You carry what you wear -- which is
## what makes lifecycle.md §5's late game a subtraction problem: a newborn
## expresses a dense DNA whole, on a body that started at 28 units, and pays for
## all of it from her first second.
func upkeep() -> float:
	return upkeep_of(_body)


## What this cell is most made of, which is what eating it gives you. §3.4.
func dominant() -> StringName:
	return dominant_of(_body)


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
	if _dna.has(gene):
		var value := int(_dna[gene])
		if value >= TIER_MAX:
			return Result.SATURATED
		_dna[gene] = value + 1
		return Result.RAISED
	# Nothing blocks and nothing is lost yet: the sample waits, and the player
	# is told by a second, smaller heartbeat rather than by a screen. A sample
	# arriving while one is already held replaces it -- the newest thing you
	# swallowed is the one in you.
	held_sample = gene
	held_remaining = SAMPLE_SECONDS
	return Result.HELD


## **The free sense, and the one gene that lands on the body as well as on the
## DNA.** See [member _gift]. Everything else about it is an ordinary held
## sample: it waits for a slot, it can be placed anywhere, and it lapses into
## the first free one.
func gift(gene: StringName) -> int:
	var result := integrate(gene)
	if result == Result.HELD:
		_gift = gene
	return result


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
	if _dna.has(taking):
		# It arrived by another route while the sample was held. Nothing to do,
		# and certainly not a second copy in a second slot.
		return Result.NOTHING
	_write(slot, taking)
	return Result.INTEGRATED


## **The DNA's** slot layout, `&""` for empty. Read it; do not write it. This is
## what the pause strip draws and what an empty socket on the body stands for --
## a hole in the DNA is where a loose gene is going.
func layout() -> Array[StringName]:
	_sync_order()
	return _order


## **The body's** slot layout, which is where its organs actually are. Built on
## demand from [member _body_slots]: the two layouts agree at birth and drift
## apart over one generation, and the difference is exactly the organ the body
## still wears after the DNA has replaced it.
func body_layout() -> Array[StringName]:
	var out: Array[StringName] = []
	out.resize(maxi(slots(), _order.size()))
	out.fill(&"")
	for gene: StringName in _body_slots:
		var slot := int(_body_slots[gene])
		if slot >= 0 and slot < out.size():
			out[slot] = gene
	return out


## Which slot an organ is worn in **on this body**, or -1. The one question a
## directional gene asks, because the answer is the arc and the arc is the
## bearing -- and the organ is on the body, not in the DNA.
func slot_of(gene: StringName) -> int:
	return int(_body_slots.get(gene, -1))


## Puts [param gene] in DNA [param slot], evicting whatever was there.
##
## The body is left alone: an organ you are wearing stays worn even after the
## DNA has written something else over its slot, which is what makes §9.7's
## irreversible mistake gentler and better -- dropping a gene over your own
## `cytostome` now costs your *daughters* a mouth, and you have a whole
## generation to see it coming on the strip and put it right.
func _write(slot: int, gene: StringName) -> void:
	var old := _order[slot]
	if old != &"":
		_dna.erase(old)
	_order[slot] = gene
	_dna[gene] = 1
	_express_gift(gene, slot)


## The one exception to *a body is fixed*, and the reason is in [member _gift]:
## an invariant against blindness that only rescued the next generation would
## not be one. Does nothing for any other gene.
func _express_gift(gene: StringName, slot: int) -> void:
	if gene == &"" or gene != _gift:
		return
	_gift = &""
	_body[gene] = maxi(int(_body.get(gene, 0)), 1)
	if slot >= 0:
		_body_slots[gene] = slot


func _first_free() -> int:
	_sync_order()
	return _order.find(&"")


## Keeps the layout the width of the body and free of anything the genome no
## longer carries. Growth only ever widens it, so nothing is dropped by this;
## the erase branch is what keeps a swap honest.
func _sync_order() -> void:
	for gene: StringName in _dna:
		if not _order.has(gene):
			var free := _order.find(&"")
			if free >= 0:
				_order[free] = gene
			else:
				_order.append(gene)
	for i in _order.size():
		if _order[i] != &"" and not _dna.has(_order[i]):
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


## **What one daughter is made of: a roll against the DNA, gene by gene.**
## Returns a `{gene: tier}` map of the organs that expressed, at the copy number
## the DNA carries -- a gene that expresses is worn at full strength, because
## copies are how likely it is and not how strong it is.
##
## Rolled once per daughter, so the two daughters of one division differ in
## **body** as well as in the one mutation that differs in their DNA. That is
## what makes the choosing beat a reading rather than a formality, and it is
## also why a failed roll is not a punishment: the player sees both bodies drawn
## before committing, so the odds shown on the strand are the odds of *one* of
## two draws -- `1 - (1 - p)^2`, which at one copy is 0.80 across the pair.
##
## **Runs in the simulation, so the global stream is the right one.** The pause
## screen may not draw from it (that was a shipped bug -- the strip was moving
## the water); a division is not a view.
static func expressed(dna: Dictionary) -> Dictionary:
	var body := {}
	for gene: StringName in dna:
		var copies := clampi(int(dna[gene]), 0, TIER_MAX)
		if copies <= 0:
			continue
		if ALWAYS_EXPRESSED.has(gene) or randf() < EXPRESS_CHANCE[copies]:
			body[gene] = copies
	return body


## How likely one locus is to reach a daughter, for the one line on the pause
## screen that says so. The strand draws the copies; this is what they mean.
static func express_chance(gene: StringName, copies: int) -> float:
	if copies <= 0:
		return 0.0
	if ALWAYS_EXPRESSED.has(gene):
		return 1.0
	return EXPRESS_CHANCE[clampi(copies, 0, TIER_MAX)]


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


# ---------------------------------------------------------------------------
# The mutation. lifecycle.md §2.2: one, drawn from three kinds, all **sideways**
# -- none is better or worse than the DNA it came from, or the choice collapses
# into "take the good one" and there is no decision in it at all.
#
# Rendered, all three read: drift is unmistakable, shift and trade read on
# comparison. That is the right ordering, because comparison is the only thing
# the player is being asked to do.
# ---------------------------------------------------------------------------

## How many mutations separate the two daughters.
const MUTATION_COUNT := 1

## One mutated copy of [param dna] and [param order]. Returns
## `[dna, order, kind]`; `kind` is the word for what changed, `&""` if nothing
## could (a one-gene DNA with nowhere to move it).
##
## The three kinds are tried in a random order and the first that applies wins,
## so a DNA that cannot be traded is shifted rather than left alone.
static func mutated(dna: Dictionary, order: Array) -> Array:
	var next := dna.duplicate()
	var seats: Array[StringName] = []
	for gene: Variant in order:
		seats.append(StringName(gene))
	var kinds: Array[StringName] = [&"shift", &"trade", &"drift"]
	kinds.shuffle()
	for kind: StringName in kinds:
		var done := false
		match kind:
			&"shift":
				done = _mutate_shift(seats)
			&"trade":
				done = _mutate_trade(next)
			_:
				done = _mutate_drift(next, seats)
		if done:
			return [next, seats, kind]
	return [next, seats, &""]


## One gene moves to a different slot, swapping with whatever was there. The
## slot is the arc, so an organ appears somewhere else on the body -- and a
## directional gene starts looking somewhere else.
static func _mutate_shift(seats: Array[StringName]) -> bool:
	if seats.size() < 2:
		return false
	var filled_slots: Array[int] = []
	for i in seats.size():
		if seats[i] != &"":
			filled_slots.append(i)
	if filled_slots.is_empty():
		return false
	var from: int = filled_slots[randi() % filled_slots.size()]
	var to := randi() % seats.size()
	if to == from:
		to = (from + 1 + randi() % (seats.size() - 1)) % seats.size()
	var held := seats[from]
	seats[from] = seats[to]
	seats[to] = held
	return true


## One gene up a tier, another down. Neither end may leave the DNA: a gene
## traded out of existence is an organ deleted, which is not sideways.
static func _mutate_trade(tiers: Dictionary) -> bool:
	var givers: Array[StringName] = []
	var takers: Array[StringName] = []
	for gene: StringName in tiers:
		var value := int(tiers[gene])
		if value >= 2:
			givers.append(gene)
		if value < TIER_MAX:
			takers.append(gene)
	if givers.is_empty():
		return false
	var giver: StringName = givers[randi() % givers.size()]
	takers.erase(giver)
	if takers.is_empty():
		return false
	var taker: StringName = takers[randi() % takers.size()]
	tiers[giver] = int(tiers[giver]) - 1
	tiers[taker] = int(tiers[taker]) + 1
	return true


## One gene is replaced by one the lineage does not carry, at the same tier: a
## whole organ changes colour and shape, which is why this is the kind that is
## unmistakable at a glance.
##
## **The mouth is never the gene that is replaced.** Every other trade here is
## even; losing the cytostome is not, and a daughter born without a mouth is a
## choice no one would make rather than a choice between two builds.
static func _mutate_drift(tiers: Dictionary, seats: Array[StringName]) -> bool:
	var goes: Array[StringName] = []
	for gene: StringName in tiers:
		if gene != &"cytostome":
			goes.append(gene)
	var comes: Array[StringName] = []
	for gene: StringName in GENE_ORDER:
		if gene != &"cytostome" and not tiers.has(gene):
			comes.append(gene)
	if goes.is_empty() or comes.is_empty():
		return false
	var out: StringName = goes[randi() % goes.size()]
	var into: StringName = comes[randi() % comes.size()]
	tiers[into] = int(tiers[out])
	tiers.erase(out)
	var slot := seats.find(out)
	if slot >= 0:
		seats[slot] = into
	return true
