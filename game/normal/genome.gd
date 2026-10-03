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
const Progression := preload("res://game/mechanics/progression.gd")

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
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
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
##
## **`rhabdom` was removed from this list and nothing closed over the gap**, for
## the same reason: the order is a tie-break, so lifting one entry out of the
## middle leaves every remaining pair in the order it was already in. `statocyst`
## / level went the same way on 2026-09-28: the owner judged it useless, since
## knowing which way is up says nothing about the water. This list
## is also what [method _mutate_drift] draws a replacement gene from, so a gene
## that is not on it can never re-enter a lineage. three-senses.md §8 row 2 is
## the decision and food.gd's DRIFTER_GENES carries the reasoning.
##
## **A gene that is not on this list is still a gene.** [method dominant_of] has
## an explicit second pass for exactly that case and [method tier_of] is a
## `.get`, so a `{gene: tier}` map that names a retired organ keeps it, pays
## upkeep on it and draws it in cilia.gd's reserved hue. Nothing is silently
## dropped from a genome here.
const GENE_ORDER: Array[StringName] = [
	&"cytostome", &"cirrus", &"flagellum", &"stigma",
	&"ocellus", &"chemocyte", &"ampulla",
	&"axoneme", &"palp", &"myoneme",
	&"trichocyst", &"pellicle", &"veneneux", &"plastid", &"vacuole", &"crista"]

## **What each gene gives a body's rules** (docs/design/behaviour.md §3): the
## inputs it senses and the outputs it triggers, by name, beside the list a
## gene is named in -- so a gene added here brings its own blocks, and rules can
## read and drive it, the save keeps it and mutation draws it without one being
## written by hand (§3.5). The body's own parts are declared in `cell.gd` and the
## metabolism's in `metabolism.gd`, in the same shape.
##
## An input has a name, says whether it carries a bearing, and lists the values
## it carries, each of a kind the rulebook knows (`rulebook.gd`'s ladders). An
## output has a name, the triggers it claims, and may take an option -- a push's
## strength. A gene that only acts on its own, as the dart, the call and the
## mouth do, declares nothing (§3.3). Organs are what declare: what each input
## reports is the organ's, computed for any body by `food.gd`.
##
## **A part may wait for a level** (docs/design/automation.md §4.3): `"level"`
## says the owner must work at that level or more for the part to be there --
## its worn copies, for every gene but the beam. The flagellum's `hold` is the
## first: it holds the tail still and only the tail, claiming the `swimming`
## trigger `body.swim` claims, from the second copy (`cell.gd`'s HOLD_LEVEL,
## rows 29 and 38). Declared last, so its owner's bits come after every other.
const DECLARES := {
	&"ocellus": {"in": [{"name": &"beam", "bearing": true,
		"values": {&"distance": &"distance"}}]},
	&"ampulla": {"in": [{"name": &"echo", "bearing": true,
		"values": {&"distance": &"distance", &"size": &"size"}}]},
	&"chemocyte": {"in": [{"name": &"smell", "bearing": false,
		"values": {&"level": &"level"}}]},
	&"stigma": {"in": [{"name": &"shadow", "bearing": true,
		"values": {&"level": &"level"}}]},
	&"palp": {"in": [{"name": &"touch", "bearing": true,
		"values": {&"closeness": &"level"}}]},
	&"myoneme": {"out": [{"name": &"dash", "claims": [&"dash"]}]},
	&"axoneme": {"out": [{"name": &"push", "claims": [&"push"],
		"options": [0.5, 1.0]}]},
	&"flagellum": {"out": [{"name": &"hold", "claims": [&"swimming"],
		"level": CellBody.HOLD_LEVEL}]},
}

## **What the genes' parts are called** (docs/design/automation.md §13.1), beside
## [constant DECLARES], by qualified name: the words the programs page puts on a
## part's chip -- each organ's sense and action, as the player knows the organ.
## Read through [method words_of].
##
## TRANSLATORS: The name of an action the player's cell can be told to do by one
## of its "instincts" (rules the player writes: "when <a sense reports
## something> -> <do this>"), on a small chip. Lowercase, a few short words.
## "dash": a burst forward; "push": thrust held on; "hold still": stop the tail
## (the flagellum, which swims) from beating, and keep it still.
## ROOM: 112 px at 15 px
const GENE_SAYS := {
	&"myoneme.dash": "dash",
	&"axoneme.push": "push",
	&"flagellum.hold": "hold still",
}
## **What the genes' senses are called**, on an instinct's chip: what each organ
## reports, as the player knows it. Words of their own, apart from the organs'
## names on the genome page, which a language may say differently.
##
## TRANSLATORS: The name of a sense on a small chip of the player's "instincts"
## (rules: "when <a sense reports something> -> <do this>"): what one organ of the
## cell reports. "beam": what the light the cell's ocellus casts lands on; "echo":
## what comes back of the cell's ping; "smell": the smell of food; "shadow": the
## shade of something big; "touch": something against the cell's skin, felt by
## its palps. Lowercase, one short word.
## ROOM: 112 px at 15 px
## CONTEXT: sense
const GENE_SENSES := {
	&"ocellus.beam": "beam",
	&"ampulla.echo": "echo",
	&"chemocyte.smell": "smell",
	&"stigma.shadow": "shadow",
	&"palp.touch": "touch",
}
## **What the values the genes' senses report are called**, by value name: a test
## is put to one of them.
##
## TRANSLATORS: The name of a value a sense of the player's cell reports, which an
## "instinct" can test, on a small choice cell. Lowercase, one short word.
## "distance": how far away; "size": how big; "level": how strong; "closeness":
## how near, for touch.
## ROOM: 70 px at 14 px
const GENE_VALUES := {
	&"distance": "distance",
	&"size": "size",
	&"level": "level",
	&"closeness": "closeness",
}
## **The line that explains each of them**, beside the chip: the chip's word, a
## middle dot, and what it is or makes the cell do, in plain words.
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
	&"ocellus.beam": "beam · the nearest thing each ray of your beam stops on: where, and how"
		+ " far.",
	&"ampulla.echo": "echo · what your ping hears back: where it came from, how far, and how"
		+ " big it rings.",
	&"chemocyte.smell": "smell · how strongly food your mouth could take smells, along your"
		+ " nose.",
	&"stigma.shadow": "shadow · the shade of anything your size or bigger: where, and how dark.",
	&"palp.touch": "touch · the nearest thing against your skin: where, and how close.",
	&"myoneme.dash": "dash · a burst forward, on its cooldown, paid in hunger.",
	&"axoneme.push": "push · thrust while this holds, at half or full, paid as you go.",
	&"flagellum.hold": "hold still · hold your tail still and keep steering, for free. needs"
		+ " two copies of your tail.",
	&"distance": "distance · how far away it is.",
	&"size": "size · how big it rings, against your mouth or your whole body.",
	&"level": "level · how strong it is, from nothing to full.",
	&"closeness": "closeness · how near it is, from the edge of your reach to your skin.",
}
## **What a part that waits for a level says while it waits**: beside an
## instinct that uses it, which is asleep until the organ reaches that level.
##
## TRANSLATORS: Said of an "instinct" (a rule the player wrote) that cannot act
## yet, because the action it uses needs a gene carried twice. "Asleep" is the
## state's name; "two copies of your tail" means the tail gene (the flagellum)
## carried twice in the cell's DNA. Lowercase.
## ROOM: 856 px at 14 px
const GENE_ASLEEP := {
	&"flagellum.hold": "asleep: needs two copies of your tail",
}
## **What the page says when a part that waits for a level is picked too early**.
##
## TRANSLATORS: Said when the player picks an action their cell cannot do yet,
## because it needs a gene carried twice. "hold still" is the action's name, as on
## its chip; "two copies of your tail" means the tail gene (the flagellum)
## carried twice in the cell's DNA. Lowercase.
## ROOM: 856 px at 14 px
const GENE_NEEDS := {
	&"flagellum.hold": "hold still needs two copies of your tail",
}


## **A part's words, in the language of the moment** (automation.md §13.1), for
## the parts [constant DECLARES] names: `{"says": its chip, "explains": its
## line, "asleep": what an instinct using it says while it waits for its level,
## "needs": what the page says when it is picked too early}`, a key absent where
## there are none. `cell.gd` answers the same way for the body's parts, so the
## page asks the file that declares a part, and a gene brings its own words.
static func words_of(part: StringName) -> Dictionary:
	var out := {}
	if GENE_SENSES.has(part):
		out["says"] = String(TranslationServer.translate(GENE_SENSES[part], &"sense"))
	elif GENE_SAYS.has(part):
		out["says"] = String(TranslationServer.translate(GENE_SAYS[part]))
	elif GENE_VALUES.has(part):
		out["says"] = String(TranslationServer.translate(GENE_VALUES[part]))
	if GENE_EXPLAINS.has(part):
		out["explains"] = String(TranslationServer.translate(GENE_EXPLAINS[part]))
	if GENE_ASLEEP.has(part):
		out["asleep"] = String(TranslationServer.translate(GENE_ASLEEP[part]))
	if GENE_NEEDS.has(part):
		out["needs"] = String(TranslationServer.translate(GENE_NEEDS[part]))
	return out

## The starting cell is already full: three slots, three organs, all tier 1.
## You are not an empty vessel; you are mediocre at three things. §1.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const BORN := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}

## The price of power, paid in the one channel the game already reads -- the
## beat. At rest, one tier-3 gene empties the tank in 36 / 1.36 = 26 s rather
## than 36; moving is paid on top (docs/design/energy.md). §3.2, and the owner
## has settled that this ships at 0.18 to be judged by playing (§9.3).
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

## One gene waiting for a slot: which gene, how many copies of it have been
## eaten since it arrived, and how many seconds it has left.
class Waiting:
	var gene: StringName
	var copies: int
	var left: float

	func _init(what: StringName, count: int, seconds: float) -> void:
		gene = what
		copies = count
		left = seconds


## **Every gene waiting for a slot, soonest to lapse first.** Issue #118: this
## used to be one held sample, and the next new gene overwrote it -- eating two
## in a row threw the first away before the player was ever offered it, and
## dna-strand.md §6.3 had already said that at three meals a generation that is
## a large share of what you swallow. Now a second gene waits behind the first.
##
## **The order is the lapse order, and it holds by construction**: every clock
## runs at the same rate, and anything that starts a clock -- a new gene, the
## same gene eaten again, a birth -- starts it full and puts it at the back. So
## the head is always the next to lapse, and it is also the one a placement
## takes unless the player picks another ([method place]).
##
## **Read off the body**, in both views: cilia.gd's `draw_pending` draws the
## head as a vesicle adrift inside the cell, circling the nucleus, with a tuft
## of the organ it would become floating clear of the skin and a thread toward
## the arc it could go on. Point of view used to get a second, smaller heartbeat
## behind every beat as well (§3.3); the owner took it off the beat on
## 2026-09-29. §5.2's two-tap swap on the pause screen, or holding the body, is
## what resolves it, through [method place].
var _waiting: Array[Waiting] = []

## The gene at the head of the queue -- the one a placement takes and the one
## the body draws -- or &"" for none.
##
## **Assigning it is a pose, not a meal**: the queue becomes that one gene at one
## copy with a full clock, or empties for &"". Only the dev harness and the
## replay write it, and the replay restores exactly what it recorded, which is
## the head -- so neither has to know there is a queue behind it.
var held_sample: StringName:
	get:
		return _waiting[0].gene if not _waiting.is_empty() else &""
	set(gene):
		_waiting.clear()
		if gene != &"":
			_waiting.append(Waiting.new(gene, 1, SAMPLE_SECONDS))
## Seconds left on [member held_sample], 0 with nothing waiting. Assigning sets
## the head's clock, which is how a posed sample and the replay hold it still.
var held_remaining: float:
	get:
		return _waiting[0].left if not _waiting.is_empty() else 0.0
	set(seconds):
		if not _waiting.is_empty():
			_waiting[0].left = seconds

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

## **One progression per gene that earns levels** (docs/design/beam-levels.md
## §3): gene to Progression, for the genes in cell.gd's LEVELLED.
##
## **The level is the lineage's, not the body's.** It is kept while the body
## wears the gene or the DNA carries it, so a daughter who carries the beam
## without growing it keeps its level for her own daughters -- a coin toss at
## one copy must not wipe out an hour of use, or copies would matter more than
## the level again, which is decision 5 backwards. It is dropped when neither
## register has the gene, which is an eviction or a drift.
##
## **Never in [member _body] or [member _dna]**, and that is load-bearing: the
## worn map is what crosses the wire, and a shared pond's referee holds it fixed
## for a whole life. A level written into it would make the first level-up a
## foul. Beside it, nothing another machine can see changes (§6).
var _levels := {}

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
##
## [param worn] is **which slot each organ is worn in**, in the shape
## [method body_layout] returns. Left `null` the two layouts are born agreeing,
## which is what a birth is: an organ grows on the arc its gene sits on. It is
## passed only by the replay, which is restoring a body that had since drifted
## from its DNA -- a gene move parts them, and re-deriving the body's slots from
## [param order] would draw the organ where the DNA has it rather than where it
## was worn. `null` and not an empty array for the same reason [param body]
## is: an empty layout is a real one, and it means nothing is worn anywhere.
##
## [param levels] is **the lineage's levels** (beam-levels.md §3), gene to
## progression, as [method levels] returns them: a birth passes her mother's,
## and she keeps a copy of each one for a gene in her own DNA or body. Left
## `null` -- a death, a forced genome, the replay -- every levelled gene starts
## at level 1. Copied before anything is replaced, so passing this genome's own
## [method levels] is safe.
func express(dna: Dictionary, order: Array, body: Variant = null,
		worn: Variant = null, levels: Variant = null) -> void:
	var inherited := {}
	if levels != null:
		for gene: Variant in (levels as Dictionary):
			inherited[StringName(gene)] = (levels[gene] as RefCounted).copy()
	_dna = dna.duplicate()
	_order = []
	for gene: Variant in order:
		_order.append(StringName(gene))
	_body = (body as Dictionary).duplicate() if body != null else _dna.duplicate()
	_body_slots = {}
	# **An empty `worn` means a caller got it wrong, never a real cell.**
	# [method body_layout] sizes its result by `maxi(slots(), _order.size())` and
	# `slots()` is at least three, so a genuine worn map is never empty -- while
	# an empty one here would seat no organ at all: `slot_of` would answer -1 for
	# every gene, every directional organ would point dead ahead and `soma.gd`
	# would draw no fringe, silently, for the whole run. That is precisely the
	# failure this parameter was added to clean up, and a default is not a guard
	# against passing the wrong thing on purpose. Falling back to `_order` gives
	# the born-agreeing answer, which is wrong only for a cell that has moved a
	# gene rather than wrong for every cell.
	var seats: Array = _order
	if worn != null and not (worn as Array).is_empty():
		seats = worn as Array
	for slot in seats.size():
		var gene := StringName(seats[slot])
		if gene != &"" and _body.has(gene):
			_body_slots[gene] = slot
	bonus_slots = 0
	_gift = &""
	# A death, a forced genome and a replayed one start with nothing waiting. A
	# birth does too, and then gets back what her mother had not yet placed:
	# normal_mode.gd's `_be_born()` hands it over through [method carry].
	_waiting.clear()
	_levels = inherited
	_tend_levels()
	_sync_order()


func _process(delta: float) -> void:
	_sync_order()
	if _waiting.is_empty():
		return
	# **A slot opening no longer places the sample, and that is the change.**
	# Phase 5 auto-filled the first free slot, which meant the player only ever
	# chose a slot on the swap path -- that is, only once the genome was full,
	# which is the *end* of a run. The slot is the arc, so auto-placing is the
	# game aiming the player's laser for them. It waits for a tap now.
	#
	# What still resolves itself is the case where there is nothing left for a
	# sample to be: its gene reached the DNA by some other route while it
	# waited -- a daughter whose one mutation drew that very gene, say.
	for i in range(_waiting.size() - 1, -1, -1):
		if _dna.has(_waiting[i].gene):
			_settle(_waiting.pop_at(i), -1)
	# **Every clock runs, not only the head's**: each meal is given its own
	# forty-five seconds. The head is always the next to lapse (see
	# [member _waiting]), so the lapses come off the front.
	for waiting: Waiting in _waiting:
		waiting.left -= delta
	while not _waiting.is_empty() and _waiting[0].left <= 0.0:
		_lapse(_waiting.pop_front())


## **A lapse with room still settles.** Forty-five seconds of not choosing is an
## answer -- "anywhere" -- and throwing the gene away for it would punish a
## player who never opens the pause screen by quietly deleting the whole
## progression. With no room it is simply gone, exactly as it always was.
##
## **The gift gets one more chance at room.** It came with a slot of its own
## ([member bonus_slots]), but with a queue a gene eaten meanwhile can lapse into
## that slot first -- so the gift is given one more, the same leg-up the grant
## already gives, rather than the one rescue in the game evaporating behind an
## ordinary meal. A layout the bonus cannot widen -- seven loci, or a newborn's
## inherited layout already longer than her body -- still has no room for it,
## exactly as the single held sample never did.
func _lapse(waiting: Waiting) -> void:
	var free := _first_free()
	if free < 0 and waiting.gene == _gift and slots() < CellBody.SLOT_MAX:
		bonus_slots += 1
		free = _first_free()
	if free >= 0:
		_settle(waiting, free)


## Writes one waiting gene into the DNA: into [param slot], or -- when its gene
## is already there, which is the only case [param slot] may be -1 -- as more
## copies of the locus that already carries it, never a second locus.
##
## If it was the anti-blindness grant it also lands on the *body*, whichever way
## it arrived: otherwise eating the same gene inside the forty-five seconds
## would quietly cancel the one rescue in the game and leave a blind cell blind.
func _settle(waiting: Waiting, slot: int) -> int:
	if _dna.has(waiting.gene):
		if waiting.gene == _gift:
			_express_gift(waiting.gene, _order.find(waiting.gene))
		for copy in waiting.copies:
			integrate_into(_dna, waiting.gene, maxi(slots(), _order.size()))
		return Result.RAISED
	_write(slot, waiting.gene, waiting.copies)
	return Result.INTEGRATED


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
##
## **A levelled gene is priced by its level, not its copies** (beam-levels.md
## §5). Copies stopped buying strength, so they stopped costing anything: what
## the body pays for its beam is the beam it actually has.
func upkeep() -> float:
	var priced := {}
	for gene: StringName in _levels:
		if not _body.has(gene):
			continue
		var grown: Progression = _levels[gene]
		var at := grown.effective_level()
		var cost := CellBody.levelled_upkeep(gene, at, grown.path)
		priced[gene] = cost if cost >= 0.0 \
			else UPKEEP_PER_TIER * float(maxi(at - 1, 0))
	return upkeep_of(_body, priced)


# --- Levels (docs/design/beam-levels.md) ------------------------------------

## The lineage's levels, gene to progression. Read it; do not write it -- hand
## it to [method express] at a birth, which copies what the daughter keeps.
func levels() -> Dictionary:
	return _levels


## **The levels a daughter can inherit**: those of the genes this DNA carries.
## A gene only this body still wears -- its DNA written over -- ends with the
## body, as the pause screen says when the placement is made
## (beam-levels.md §8.2), so a drift that brings the same gene back to a
## daughter brings it back new, at level 1.
func heritable_levels() -> Dictionary:
	var out := {}
	for gene: StringName in _levels:
		if _dna.has(gene):
			out[gene] = _levels[gene]
	return out


## The progression [param gene] levels with, or null for a gene that does not
## level or that neither register carries.
func progression(gene: StringName) -> Progression:
	return _levels.get(gene, null) as Progression


## **The level [param gene] works at**: held at the fork until a path is
## taken. A gene that does not level answers its worn tier, which is what its
## strength has always been.
func level_of(gene: StringName) -> int:
	var grown := progression(gene)
	if grown != null:
		return grown.effective_level()
	if CellBody.LEVELLED.has(gene) and (_body.has(gene) or _dna.has(gene)):
		return 1
	return tier(gene)


## The path [param gene] has taken at its fork, &"" before it has, or for a gene
## with no fork.
func path_of(gene: StringName) -> StringName:
	var grown := progression(gene)
	return grown.path if grown != null else &""


## True while [param gene]'s fork is open and waiting to be taken.
func can_choose(gene: StringName) -> bool:
	var grown := progression(gene)
	return grown != null and grown.can_choose()


## Takes [param path] at [param gene]'s fork, for good. False and nothing
## changes when the fork is not open or the path is not one it offers.
func choose(gene: StringName, path: StringName) -> bool:
	var grown := progression(gene)
	return grown != null and grown.choose(path)


## **Experience for [param gene], earned by using it.** Only a body that wears
## the organ can use it, so a gene carried in the DNA and not grown earns
## nothing. Returns true when this took the gene up a level.
func earn(gene: StringName, amount: float) -> bool:
	var grown := progression(gene)
	if grown == null or not _body.has(gene):
		return false
	var before := grown.level()
	grown.earn(amount)
	return grown.level() > before


## The levels' state, gene to `[xp, path]`: what a recording keeps.
func level_state() -> Dictionary:
	var out := {}
	for gene: StringName in _levels:
		out[gene] = (_levels[gene] as Progression).to_state()
	return out


## Puts back what [method level_state] took, for the genes this genome still
## levels. The replay calls it after its [method express].
func restore_levels(state: Dictionary) -> void:
	for gene: Variant in state:
		var grown := progression(StringName(gene))
		if grown != null:
			grown.set_state(state[gene] as Array)


## **This genome as plain types**, every gene by its name (ocean.md §9.2, row
## 17): the DNA and where each gene sits in it, the body and where each organ is
## worn -- the two differ a generation in, and neither can be derived from the
## other -- the slots the body did not earn, the gift not yet placed, every
## waiting gene with its copies and the seconds it has left, and the lineage's
## levels. A gene this build does not know is kept by the name it has.
func to_state() -> Dictionary:
	var waiting: Array = []
	for one: Waiting in _waiting:
		waiting.append([String(one.gene), one.copies, one.left])
	var levels := {}
	for gene: StringName in _levels:
		var grown: Progression = _levels[gene]
		levels[String(gene)] = [grown.xp, String(grown.path)]
	return {
		"dna": tiers_by_name(_dna),
		"order": PackedStringArray(layout()),
		"body": tiers_by_name(_body),
		"worn": PackedStringArray(body_layout()),
		"bonus": bonus_slots,
		"gift": String(_gift),
		"waiting": waiting,
		"levels": levels,
	}


## Puts back what [method to_state] took: the body expressed as it was worn over
## the DNA as it was written, then the levels, the bonus slots, the gift and the
## queue, each clock where it had got to -- which no birth does, since a birth
## starts every clock full ([method carry]).
func set_state(state: Dictionary) -> void:
	var order: Array = []
	for gene: String in state["order"]:
		order.append(StringName(gene))
	var worn: Array = []
	for gene: String in state["worn"]:
		worn.append(StringName(gene))
	express(tiers_from_names(state["dna"]), order, tiers_from_names(state["body"]), worn)
	restore_levels(state["levels"])
	bonus_slots = int(state["bonus"])
	_gift = StringName(state["gift"])
	for one: Array in state["waiting"]:
		_waiting.append(Waiting.new(StringName(one[0]), clampi(int(one[1]), 1, TIER_MAX),
			float(one[2])))
	_sync_order()


## `{gene: tier}` with every gene a String: how a file keeps a genome.
static func tiers_by_name(tiers: Dictionary) -> Dictionary:
	var out := {}
	for gene: Variant in tiers:
		out[String(gene)] = int(tiers[gene])
	return out


## And back, every name a gene again.
static func tiers_from_names(named: Dictionary) -> Dictionary:
	var out := {}
	for gene: Variant in named:
		out[StringName(gene)] = int(named[gene])
	return out


## **Keeps [member _levels] in step with the two registers**: a progression for
## every levelled gene either one holds, a fresh one at level 1 for a gene just
## arrived, and none for a gene neither holds any more.
func _tend_levels() -> void:
	for gene: StringName in CellBody.LEVELLED:
		if (_dna.has(gene) or _body.has(gene)) and not _levels.has(gene):
			var rules: Array = CellBody.LEVELLED[gene]
			_levels[gene] = Progression.new(float(rules[0]), int(rules[1]),
				rules[2])
	for gene: StringName in _levels.keys():
		if not _dna.has(gene) and not _body.has(gene):
			_levels.erase(gene)


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
	# is told by the body, which draws it, rather than by a screen. **A sample
	# arriving while another waits queues behind it** (#118) -- it used to
	# replace it, and the first gene was gone before anyone was asked.
	var at := waiting_index(gene)
	if at < 0:
		_waiting.append(Waiting.new(gene, 1, SAMPLE_SECONDS))
		return Result.HELD
	# **The same gene again, before it was placed, is one more copy of it** --
	# exactly what eating it again would have done had it been placed in
	# between -- and its clock starts over, so it moves to the back: the
	# newest meal is the one it waits from.
	var again: Waiting = _waiting.pop_at(at)
	again.copies = mini(again.copies + 1, TIER_MAX)
	again.left = SAMPLE_SECONDS
	_waiting.append(again)
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


## Puts a waiting gene into DNA [param slot], at the copies it waited with, over
## whatever is there. §5.2's two-tap swap, and §9.7's one irreversible action in
## the game: the player may drop it over their own `cytostome` and fall to gape
## 0.58r, which cannot be undone. It is either a real and interesting mistake or
## a soft lock, and §1.3's drifter floor is what makes it the first -- there is
## always something small enough left to eat.
##
## [param which] is the waiting gene's place in the queue: the head unless the
## player picked another.
##
## **The slot the player tapped is the slot the gene lands in**, empty or not.
## That is the one placement decision in the game, and [member _order] is what
## makes it survivable: the gene goes to that index whatever else is empty, so
## the arc it will be worn on is the arc the tile's compass promised.
func place(slot: int, which: int = 0) -> int:
	if which < 0 or which >= _waiting.size():
		return Result.NOTHING
	_sync_order()
	if slot < 0 or slot >= _order.size():
		return Result.NOTHING
	# It reached the DNA by another route while it waited: [method _settle]
	# raises that locus, and certainly writes no second copy in a second slot.
	return _settle(_waiting.pop_at(which), slot)


## Every gene waiting for a slot, head first. A fresh array: read it.
func waiting() -> Array[StringName]:
	var out: Array[StringName] = []
	for one: Waiting in _waiting:
		out.append(one.gene)
	return out


## How many copies of [param gene] are waiting to be placed, 0 if it is not.
## What a placement will write, and so the level a waiting gene is read at.
func waiting_copies(gene: StringName) -> int:
	var at := waiting_index(gene)
	return _waiting[at].copies if at >= 0 else 0


## Seconds [param gene] has left to wait before it lapses, 0 if it is not
## waiting.
func waiting_left(gene: StringName) -> float:
	var at := waiting_index(gene)
	return _waiting[at].left if at >= 0 else 0.0


## Where [param gene] is in the queue, or -1.
func waiting_index(gene: StringName) -> int:
	for i in _waiting.size():
		if _waiting[i].gene == gene:
			return i
	return -1


## **Everything still waiting, handed over and emptied** -- the mother's half of
## a division. See [method carry].
func take_waiting() -> Array[Waiting]:
	var out := _waiting.duplicate()
	_waiting.clear()
	return out


## **What was still waiting goes with the daughter** (#118). A gene outside the
## chromosome is a plasmid, and a dividing cell passes its plasmids on to its
## daughters; the one the player goes on living as wakes carrying whatever her
## mother had not placed yet, still waiting to be placed. It used to be dropped
## by the [method express] a birth runs -- silently, and always for the gene in
## the meal that finished the growth, which starts the split the same frame and
## never had a chance at all.
##
## **Each clock starts full**, in the order they came: a new body is a new
## forty-five seconds. And none of them is the gift any more -- [method express]
## has already forgotten it -- because the grant was for the mother's body; a
## daughter who cannot sense is given her own.
func carry(samples: Array[Waiting]) -> void:
	for one: Waiting in samples:
		if waiting_index(one.gene) >= 0:
			continue
		_waiting.append(Waiting.new(one.gene, one.copies, SAMPLE_SECONDS))


## **Two loci trade places in the DNA, and nothing else changes.** The body is
## left alone -- [member _body], [member _body_slots] and every tier are
## untouched -- so the organs stay exactly where they are worn and the move
## reaches the player's daughters rather than the player. Nothing is created and
## nothing is destroyed, which is what makes a move free and repeatable and
## leaves genes-and-cilia.md §9.7's eviction the one irreversible action there
## is: a move cannot bring back a gene a placement wrote over, because that gene
## is no longer in [member _dna] for any rearrangement to find.
##
## **Swapping rather than refusing**, because it is the operation the game
## already performs on the player's behalf: [method _mutate_shift] -- one of the
## three mutations a daughter can carry -- moves a gene to a different slot,
## swapping with whatever was there. An empty destination is the degenerate case
## of that same swap, so there is one rule and not two.
##
## Returns false and changes nothing when there is no move to make: the same
## locus twice, either index off the strand, or an empty source.
func move(from: int, to: int) -> bool:
	_sync_order()
	if from == to:
		return false
	if from < 0 or from >= _order.size():
		return false
	if to < 0 or to >= _order.size():
		return false
	if _order[from] == &"":
		return false
	var lifted := _order[from]
	_order[from] = _order[to]
	_order[to] = lifted
	return true


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


## Puts [param copies] of [param gene] in DNA [param slot], evicting whatever was
## there. One copy for a gene eaten once; more for one eaten again while it
## waited (#118), which is what placing it between the two meals would have
## written.
##
## The body is left alone: an organ you are wearing stays worn even after the
## DNA has written something else over its slot, which is what makes §9.7's
## irreversible mistake gentler and better -- dropping a gene over your own
## `cytostome` now costs your *daughters* a mouth, and you have a whole
## generation to see it coming on the strip and put it right.
func _write(slot: int, gene: StringName, copies: int = 1) -> void:
	var old := _order[slot]
	if old != &"":
		_dna.erase(old)
	_order[slot] = gene
	_dna[gene] = clampi(copies, 1, TIER_MAX)
	_express_gift(gene, slot)
	# A new gene starts at level 1; the one written over keeps its level only
	# while this body still wears it.
	_tend_levels()


## The one exception to *a body is fixed*, and the reason is in [member _gift]:
## an invariant against blindness that only rescued the next generation would
## not be one. Does nothing for any other gene.
func _express_gift(gene: StringName, slot: int) -> void:
	if gene == &"" or gene != _gift:
		return
	_gift = &""
	# Tier 1: the host's referee judges by this -- change it with Wire.PROTOCOL
	# and Wire.RULES (wire.gd).
	_body[gene] = maxi(int(_body.get(gene, 0)), 1)
	if slot >= 0:
		_body_slots[gene] = slot
	_tend_levels()


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


## [param priced] is gene to what that gene adds to the multiplier, for a gene
## whose price is not its copies -- a levelled one, priced by its level. Every
## other gene pays `UPKEEP_PER_TIER` for each tier above the first, as it always
## has. Empty for every cell in the water, which has no levels.
static func upkeep_of(tiers: Dictionary, priced: Dictionary = {}) -> float:
	var extra := 0
	var levelled := 0.0
	for gene: Variant in tiers:
		if priced.has(gene):
			levelled += float(priced[gene])
			continue
		extra += maxi(int(tiers[gene]) - 1, 0)
	# `crista` / burn is the one gene that buys upkeep back, and it is applied
	# as a multiplier on the whole bill rather than as a subtraction: it is
	# worth most to the expensive build, which is the one that needs it.
	var burn := CellBody.BURN_BY_TIER[clampi(tier_of(tiers, &"crista"), 0,
		CellBody.BURN_BY_TIER.size() - 1)]
	return (1.0 + UPKEEP_PER_TIER * float(extra) + levelled) * burn


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
