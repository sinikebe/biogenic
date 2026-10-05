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
## **Every gene there is** (docs/design/gene-catalogue.md): its order, its forms,
## its tags and its numbers, by key. Every rule here is generic and asks it.
const Catalogue := preload("res://game/genes/catalogue.gd")
const Stats := preload("res://game/genes/stats.gd")
## **The body plan** (docs/design/gene-catalogue.md §10): every slot, its place and
## its anatomy, and the home seats. It preloads nothing.
const BodyPlan := preload("res://game/genes/body_plan.gd")

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
## The host's referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
const TIER_MAX := 3
## **The copies the gift is worn at** ([method _express_gift]): one. The host's referee
## judges a born body's gift by it (game/net/rules.gd).
const GIFT_TIER := 1

# **The order genes are ranked in** -- the tie-break of `dominant_of`, arc order
# from §4.1, so the cell you can see is the gene you get -- is each gene's own
# `order` now, in its organ's file, and the catalogue's `keys()` lists every gene
# in it. It is append-only, and a gene that left it before there was a catalogue
# (`rhabdom`, `statocyst`) has no place in it: it is ranked as a name this build
# does not know, as it was when it left.
#
# **A gene that is not in the catalogue is still a gene.** `dominant_of` ranks it
# after every known one and `tier_of` is a `.get`, so a `{gene: tier}` map that
# names one keeps it, pays upkeep on it and draws it in cilia.gd's UNKNOWN_TINT.
# Nothing is silently dropped from a genome here.

# --- Places and forms (docs/design/dna-slots.md §2, §3) -------------------------
# The owner, 2026-10-03: *"We need add body internal slots. Those express inside
# the body. The direction slots express outside the body."* **Two places**: the
# slots round the body are outside, as they always were -- each the arc of
# skin it is worn on -- and one slot is inside it. A gene may be a different
# *form* in each place, with a name of its own, so every `{name: copies}` map in
# the game -- the DNA, the body, a water cell's genome, the wire, a save, the
# replay -- still holds each name once, as it always has.

## **The inside of a body**: every slot from this index on is inside the body,
## and every slot before it is an arc of the skin, outside. Arcs are earned by
## growing; the inside is every cell's from birth. **These four are the body
## plan's** (`body_plan.gd`), under the names every reader knows them by, read again
## whenever the plan changes ([method _read_plan]).
static var INSIDE: int = BodyPlan.INSIDE
## **How much room the inside has**: one slot today, for the one gene that has an
## inside form. More inside genes, or more strains, are where it would grow
## (dna-slots.md §19). Structure, not balance.
static var INSIDE_SLOTS: int = BodyPlan.INSIDE_SLOTS
## The two places, by the owner's words.
const OUTSIDE_PLACE := BodyPlan.OUTSIDE_PLACE
const INSIDE_PLACE := BodyPlan.INSIDE_PLACE
## **The front**: the arcs that touch the mouth's own, the nose and the two
## either side of it. Anatomy, not a place: an outside toxin in one of them acts
## through the bite, and on any other arc it stings what bites that side
## (dna-slots.md §2.3). The plan's own list, refilled in place when it changes.
static var FRONT: Array[int] = BodyPlan.FRONT
## **The stern**: the arc behind, the tail's. An outside toxin here stings what
## bites from behind; named for the words that say so, and nothing else.
static var STERN: int = BodyPlan.STERN


static func _static_init() -> void:
	BodyPlan.listen(_read_plan)


## The plan changed (`body_plan.gd`'s `use`, a tool's): its slots again.
static func _read_plan() -> void:
	INSIDE = BodyPlan.INSIDE
	INSIDE_SLOTS = BodyPlan.INSIDE_SLOTS
	FRONT = BodyPlan.FRONT
	STERN = BodyPlan.STERN


# **A gene that is a different form in another place** is the catalogue's to
# say: every key is one form of its organ's variant, in one place, and the first
# form a variant lists is its variety -- the name the gene goes by where no place
# is known yet: the water's draws, the floor's count, and two meals in the tray
# found to be one. The toxin is today's one gene with two (organs/toxin.gd);
# every other is itself, outside. The statics below ask the catalogue.

## What a second tap would do with a waiting gene ([method placing]): write it
## here, add a copy to the form it makes where that form already is, refuse as
## full, or refuse because the gene faces out.
const PLACE_WRITE := &"write"
const PLACE_RAISE := &"raise"
const PLACE_FULL := &"full"
const PLACE_FACES_OUT := &"faces_out"
## Why a move is refused ([method move_refusal]): there is nothing to move, a
## gene that faces out would go inside, or one end would become a form already
## carried in a third slot.
const MOVE_NOTHING := &"nothing"
const MOVE_FACES_OUT := &"faces_out"
const MOVE_COLLISION := &"collision"

# **What each gene gives a body's rules** (docs/design/behaviour.md §3) is its
# organ's `declares`, read through the catalogue's `declares()`: the inputs it
# senses and the outputs it triggers, by name -- so a gene brings its own blocks,
# and rules can read and drive it, the save keeps it and mutation draws it
# without one being written by hand (§3.5). The body's own parts are declared in
# `cell.gd` and the metabolism's in `metabolism.gd`, in the same shape. **And so
# are their words**: each organ's file has its parts' (gene.gd's word tables), and
# the values every sense reports are program_words.gd's.


## **A part's words, in the language of the moment** (automation.md §13.1), for
## the parts the genes declare: `{"says": its chip, "explains": its line,
## "asleep": what an instinct using it says while it waits for its level,
## "needs": what the page says when it is picked too early}`, a key absent where
## there are none -- its organ file's (`GENE_SENSES`, `GENE_SAYS`, `GENE_EXPLAINS`,
## `GENE_ASLEEP`, `GENE_NEEDS`), through the catalogue. `cell.gd` answers the same
## way for the body's parts, so the page asks the file that declares a part, and a
## gene brings its own words.
##
## i18n-ok: the organ files' word tables, which the template lists from there.
static func words_of(part: StringName) -> Dictionary:
	var words := Catalogue.part_words(part)
	var out := {}
	if words.has(&"sense"):
		out["says"] = String(TranslationServer.translate(words[&"sense"], &"sense"))
	elif words.has(&"says"):
		out["says"] = String(TranslationServer.translate(words[&"says"]))
	if words.has(&"explains"):
		out["explains"] = String(TranslationServer.translate(words[&"explains"]))
	if words.has(&"asleep"):
		out["asleep"] = String(TranslationServer.translate(words[&"asleep"]))
	if words.has(&"needs"):
		out["needs"] = String(TranslationServer.translate(words[&"needs"]))
	return out

# **The starting cell is already full**: three slots, three organs, all tier 1
# -- each organ's own `born` (the catalogue's `born()`). You are not an empty
# vessel; you are mediocre at three things. §1.

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

# **The mouth always expresses**: a gene tagged `always_expressed`. The same
# argument `_mutate_drift` already makes: a daughter born with no mouth is not
# one of two builds to choose between, it is a body that cannot feed itself, and
# nobody would pick it. One exception, tagged, rather than a rule with a soft
# edge.

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
## SLOT_MAX, so by the time the body has earned every slot the leg-up is gone. Reset
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
## **Bumped whenever [member _body] changes** -- [method express] (and through it
## [method set_state]), [method _express_gift] and a form's conversion: what
## `cell.gd` reads its stats off once a body by (docs/design/gene-catalogue.md
## §15, as built 1a). Anything else that ever writes the body bumps it too.
var body_version := 0
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
## §3): gene to Progression, for the genes whose organ says how it levels
## (the catalogue's `levelled()`).
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
		express(Catalogue.born(), BodyPlan.home_layout(Catalogue.born_order()))
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
	express(Catalogue.born(), BodyPlan.home_layout(Catalogue.born_order()))


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
	_put_in_place(body == null)
	bonus_slots = 0
	_gift = &""
	# A death, a forced genome and a replayed one start with nothing waiting. A
	# birth does too, and then gets back what her mother had not yet placed:
	# normal_mode.gd's `_be_born()` hands it over through [method carry].
	_waiting.clear()
	_levels = inherited
	_tend_levels()
	_sync_order()
	body_version += 1


## **Every DNA form in its place** (docs/design/dna-slots.md §5.6), before
## anything reads it. A birth is in place already -- placing, moving and
## mutating keep it so -- and this does nothing there. It is what migrates a
## save written before there was an inside, and what makes a pose honest:
##
## - **a gene posed at an inside index** (`--genome=...,toxicyst:2:7`) becomes its
##   inside form; one that faces out cannot sit there, and is seated outside;
## - **an inside form found in the outside layout** -- a save's `veneneux` in
##   slot 3 -- leaves its slot and goes inside, if the inside has room; otherwise
##   it becomes its outside form in place, if that is not carried, and otherwise
##   it stays and the log says so (no save can hold this);
## - **the body keeps every organ it wears**: an inside form it wears only loses
##   its outside slot in the body's layout, because inside nothing has an arc.
##
## [param whole] is a body expressed whole from this DNA -- a pose, a run's first
## cell -- whose organs follow the DNA's forms; a body handed in (a birth's roll,
## a save) is kept as it came.
func _put_in_place(whole: bool) -> void:
	for slot in range(INSIDE, _order.size()):
		var gene := _order[slot]
		_order[slot] = &""
		if gene == &"" or not _dna.has(gene):
			continue
		var inner := form_in(gene, INSIDE_PLACE)
		if inner == &"":
			print("[genome] %s faces out, and cannot sit inside: it is seated outside" % gene)
		elif inner != gene and not _dna.has(inner):
			_convert(gene, inner, whole)
	while _order.size() > INSIDE:
		_order.pop_back()
	var room := INSIDE_SLOTS
	for gene: StringName in _dna:
		if is_inside_form(gene) and not _order.has(gene):
			room -= 1
	for slot in _order.size():
		var gene := _order[slot]
		if gene == &"" or not is_inside_form(gene):
			continue
		if room > 0:
			room -= 1
			_order[slot] = &""
			print("[genome] %s moved inside from slot %d" % [gene, slot])
			continue
		var outer := form_in(gene, OUTSIDE_PLACE)
		if outer != &"" and not _dna.has(outer):
			_convert(gene, outer, whole)
			_order[slot] = outer
			print("[genome] %s had no room inside: it is %s in slot %d" % [gene, outer, slot])
			continue
		print("[genome] %s has no room inside and no outside form to be: kept inside, over its room"
			% gene)
	# Nothing inside has an arc: an inside form worn, or anything posed at an
	# inside index, keeps no seat on the skin.
	for gene: StringName in _body_slots.keys():
		if is_inside_form(gene) or int(_body_slots[gene]) >= INSIDE:
			_body_slots.erase(gene)


## One form becomes another, at its copies, in the DNA -- and on the body too
## when the body was expressed whole from it ([param whole]), with its arc.
func _convert(from: StringName, to: StringName, whole: bool) -> void:
	_dna[to] = _dna[from]
	_dna.erase(from)
	if whole and _body.has(from) and not _body.has(to):
		_body[to] = _body[from]
		_body.erase(from)
		body_version += 1
		if _body_slots.has(from):
			if not is_inside_form(to):
				_body_slots[to] = _body_slots[from]
			_body_slots.erase(from)
	if _levels.has(from) and not _levels.has(to):
		_levels[to] = _levels[from]


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
	#
	# **Never a gene with forms** (dna-slots.md §5.1): carrying one form of the
	# toxin does not say whether this copy is more of it or the other form. That
	# is the placement, and it is the player's.
	for i in range(_waiting.size() - 1, -1, -1):
		if not has_forms(_waiting[i].gene) and _dna.has(_waiting[i].gene):
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
## ordinary meal. A layout the bonus cannot widen -- every slot, or a newborn's
## inherited layout already longer than her body -- still has no room for it,
## exactly as the single held sample never did.
##
## **A strain of an organ that holds one variant to a body** (gene.gd's
## `one_variant`), whose other strain the DNA carries, writes over that strain in
## its slot, room or none (gene-catalogue.md §6.3) -- as a full water cell's meal of
## one writes over the strain it wears ([method integrate_into]). *Anywhere*, for an
## organ you carry, is where it is. Every organ today holds its variants side by
## side, and none comes here.
func _lapse(waiting: Waiting) -> void:
	for slot: int in _other_strains(waiting.gene):
		if form_at(waiting.gene, slot) != &"":
			_settle(waiting, slot)
			return
	if has_forms(waiting.gene):
		_lapse_form(waiting)
		return
	var free := _first_free()
	if free < 0 and waiting.gene == _gift and slots() < CellBody.SLOT_MAX:
		bonus_slots += 1
		free = _first_free()
	if free >= 0:
		_settle(waiting, free)


## **A toxin left to lapse** (dna-slots.md §5.3) goes to the first of these that
## applies: more copies of the form it was eaten as, carried with room; more of
## the other form, carried with room; the form it was eaten as, new, in a free
## slot of its place -- the inside, or the first free arc; the other form, new,
## in a free slot of the other place; or it is gone. Forty-five seconds of not
## choosing still means *anywhere*: for a gene you carry *anywhere* is more of
## it, and for one you do not, it is where you ate it from.
func _lapse_form(waiting: Waiting) -> void:
	var tried: Array[StringName] = [waiting.gene]
	for form: StringName in forms_of(waiting.gene):
		if not tried.has(form):
			tried.append(form)
	for form: StringName in tried:
		if _dna.has(form) and int(_dna[form]) < TIER_MAX:
			_raise(form, waiting.copies)
			return
	for form: StringName in tried:
		if _dna.has(form):
			continue
		if is_inside_form(form):
			if count_inside(_dna) < INSIDE_SLOTS:
				_write_inside(form, waiting.copies, INSIDE)
				return
			continue
		var free := _first_free()
		if free >= 0:
			_write(free, form, waiting.copies)
			return


## Writes one waiting gene into the DNA: into [param slot], or -- when its gene
## is already there, which is the only case [param slot] may be -1 -- as more
## copies of the locus that already carries it, never a second locus.
##
## If it was the anti-blindness grant it also lands on the *body*, whichever way
## it arrived: otherwise eating the same gene inside the forty-five seconds
## would quietly cancel the one rescue in the game and leave a blind cell blind.
##
## **A gene with forms becomes the form of the slot it lands in**
## (dna-slots.md §5.2): placed where that form is already carried, it adds its
## copies there and the tapped slot is left alone; placed inside, it goes inside,
## over the inside form there if the inside is full; otherwise it is written into
## the slot, over whatever is there. A gene that faces out is never written
## inside: nothing happens, and the screen never asks.
func _settle(waiting: Waiting, slot: int) -> int:
	if has_forms(waiting.gene) and slot >= 0:
		var form := form_at(waiting.gene, slot)
		if form == &"":
			return Result.NOTHING
		if _dna.has(form):
			_raise(form, waiting.copies)
			return Result.RAISED
		if is_inside(slot):
			_write_inside(form, waiting.copies, slot)
			return Result.INTEGRATED
		_write(slot, form, waiting.copies)
		return Result.INTEGRATED
	if slot >= 0 and is_inside(slot):
		return Result.NOTHING
	if _dna.has(waiting.gene):
		if waiting.gene == _gift:
			_express_gift(waiting.gene, _order.find(waiting.gene))
		_raise(waiting.gene, waiting.copies)
		return Result.RAISED
	_write(slot, waiting.gene, waiting.copies)
	return Result.INTEGRATED


## [param copies] more copies of [param form], which the DNA carries, up to
## three: wherever it is, the tapped slot left alone.
func _raise(form: StringName, copies: int) -> void:
	_dna[form] = mini(int(_dna[form]) + maxi(copies, 0), TIER_MAX)


## [param form], an inside form, written inside at [param copies] -- over the
## inside form in [param slot] when the inside is full, which is the inside's
## one irreversible write, as writing over an arc is the outside's.
func _write_inside(form: StringName, copies: int, slot: int) -> void:
	_over_other_variants(_dna, form, _order)
	if count_inside(_dna) >= INSIDE_SLOTS:
		var held := inside_layout()
		var over: StringName = held[clampi(slot - INSIDE, 0, held.size() - 1)]
		if over == &"":
			for gene: StringName in held:
				if gene != &"":
					over = gene
					break
		if over != &"":
			_dna.erase(over)
	_dna[form] = clampi(copies, 1, TIER_MAX)
	_tend_levels()


## **One variant to a body** (gene-catalogue.md §6.3): for an organ that holds one
## (gene.gd's `one_variant`), [param gene] about to be written into [param tiers]
## writes over every other variant of its organ there, in any form -- as the
## inside's one poison is written over -- and its slot in [param seats], if it has
## one, is left empty. Its own variant's other forms stay. Nothing for an organ of
## variants side by side, which is every organ today.
static func _over_other_variants(tiers: Dictionary, gene: StringName, seats: Array) -> void:
	var organ := Catalogue.organ_of(gene)
	if not Catalogue.one_variant(organ):
		return
	var own := Catalogue.variant_of(gene)
	for other: Variant in tiers.keys():
		var key := StringName(other)
		if _other_strain(key, organ, own):
			tiers.erase(key)
			var at := seats.find(key)
			if at >= 0:
				seats[at] = &""


## **The slots of the strains writing [param gene] would take out** (gene-catalogue.md
## §6.3): for an organ that holds one variant to a body, every slot of the DNA that
## carries another variant of it -- the outside in order, then the inside. None for an
## organ of variants side by side, which is every organ today, and nothing is read.
func _other_strains(gene: StringName) -> Array[int]:
	var out: Array[int] = []
	var organ := Catalogue.organ_of(gene)
	if not Catalogue.one_variant(organ):
		return out
	var own := Catalogue.variant_of(gene)
	_sync_order()
	for slot in _order.size():
		if _other_strain(_order[slot], organ, own):
			out.append(slot)
	var held := inside_layout()
	for k in held.size():
		if _other_strain(held[k], organ, own):
			out.append(INSIDE + k)
	return out


## Whether [param key] is another variant of [param organ] than [param own].
static func _other_strain(key: StringName, organ: StringName, own: StringName) -> bool:
	return key != &"" and Catalogue.organ_of(key) == organ and Catalogue.variant_of(key) != own


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
	return upkeep_with_levels(_body, _levels)


## **[method upkeep] from plain values** (docs/design/cells.md §6.5): the body
## [param body], gene to tier, and the lineage's [param levels], gene to
## progression -- so a screen that shows a cell from its file prices it as the
## run does, without a genome.
static func upkeep_with_levels(body: Dictionary, levels: Dictionary) -> float:
	var priced := {}
	for gene: StringName in levels:
		if not body.has(gene):
			continue
		var grown: Progression = levels[gene]
		var at := grown.effective_level()
		var cost := CellBody.levelled_upkeep(gene, at, grown.path)
		priced[gene] = cost if cost >= 0.0 \
			else UPKEEP_PER_TIER * float(maxi(at - 1, 0))
	return upkeep_of(body, priced)


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
	if Catalogue.has_levels(gene) and (_body.has(gene) or _dna.has(gene)):
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
##
## **And `plan`, the body plan's slot ids by index** (gene-catalogue.md §10.3),
## which the two layouts are kept under: a build on another plan puts each gene
## back in its slot by id ([method layout_from]). A file before it has none, and
## was kept under today's plan; a build before it never asks.
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
		"plan": BodyPlan.stamp(),
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
	var order := layout_from(state["order"], state.get("plan"))
	var worn := layout_from(state["worn"], state.get("plan"))
	express(tiers_from_names(state["dna"]), order, tiers_from_names(state["body"]), worn)
	restore_levels(state["levels"])
	bonus_slots = int(state["bonus"])
	_gift = StringName(state["gift"])
	for one: Array in state["waiting"]:
		_waiting.append(Waiting.new(StringName(one[0]), clampi(int(one[1]), 1, TIER_MAX),
			float(one[2])))
	_sync_order()


## **A slot layout as a file keeps it, on the body plan in use**
## (gene-catalogue.md §10.3): [param names], gene names by slot, kept under the
## plan whose ids [param plan] stamps -- `null` for a file kept before the stamp,
## under today's plan. Under the plan in use it is read as it is; under another,
## every gene goes back to its slot by id, and one whose slot is gone to the free
## slot nearest it, or out of the layout and into the DNA alone: never dropped
## (body_plan.gd's `migrate`).
static func layout_from(names: Variant, plan: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for gene: Variant in BodyPlan.migrate(Array(names), BodyPlan.written(plan)):
		out.append(StringName(gene))
	return out


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
	for gene: StringName in Catalogue.levelled():
		if (_dna.has(gene) or _body.has(gene)) and not _levels.has(gene):
			_levels[gene] = progression_for(gene)
	for gene: StringName in _levels.keys():
		if not _dna.has(gene) and not _body.has(gene):
			_levels.erase(gene)


## **A fresh progression for [param gene]**, at level 1, by the rules its organ
## levels by (gene.gd's `levels`): what a gene arriving in a lineage starts with,
## and what a screen that shows a cell from its file rebuilds a level on.
static func progression_for(gene: StringName) -> Progression:
	var rules := Catalogue.levels(gene)
	var paths: Array[StringName] = []
	paths.assign(rules.get("paths", []))
	return Progression.new(float(rules["step"]), int(rules.get("fork", 0)), paths)


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
##
## **Except for a gene with forms** (dna-slots.md §5.1), which waits even when
## you carry it: carrying the poison does not say whether this copy should go to
## the poison or become a venom. That decision is the placement, the owner's
## *"put its genes how he wants to"*. It is food alone only when every form of it
## is carried at three copies already.
func integrate(gene: StringName) -> int:
	if gene == &"":
		return Result.NOTHING
	if has_forms(gene):
		var room := false
		for form: StringName in forms_of(gene):
			if int(_dna.get(form, 0)) < TIER_MAX:
				room = true
				break
		if not room:
			return Result.SATURATED
		return _hold(gene)
	if _dna.has(gene):
		var value := int(_dna[gene])
		if value >= TIER_MAX:
			return Result.SATURATED
		_dna[gene] = value + 1
		return Result.RAISED
	return _hold(gene)


## A meal that waits for its place: at the back of the queue with a full clock,
## or -- the same gene again before it was placed, which for a gene with forms
## is any form of the same variety -- one more copy of the sample that waits.
func _hold(gene: StringName) -> int:
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
	# newest meal is the one it waits from. A toxin keeps the name of the form
	# it was first eaten as, which only its lapse reads.
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
##
## **The inside is a slot too** ([member INSIDE]): a toxin placed there is
## poison. A gene that faces out is refused there and keeps waiting -- nothing
## is spent on a placement that cannot be.
func place(slot: int, which: int = 0) -> int:
	if which < 0 or which >= _waiting.size():
		return Result.NOTHING
	_sync_order()
	if slot < 0:
		return Result.NOTHING
	if is_inside(slot):
		if slot >= INSIDE + INSIDE_SLOTS or form_at(_waiting[which].gene, slot) == &"":
			return Result.NOTHING
	elif slot >= _order.size():
		return Result.NOTHING
	# It reached the DNA by another route while it waited: [method _settle]
	# raises that locus, and certainly writes no second copy in a second slot.
	return _settle(_waiting.pop_at(which), slot)


## **What a second tap on [param slot] would do with the waiting [param gene]**
## (dna-slots.md §5.2), as `[what, where, over]`: [constant PLACE_WRITE] here;
## [constant PLACE_RAISE], a copy added to the form it makes, which is already
## carried in slot `where`; [constant PLACE_FULL], that form is at three copies
## and the tap would spend the sample for nothing; [constant PLACE_FACES_OUT], a
## gene that cannot sit there at all. The screen's armed preview, its line and
## its guard all ask this, so the three never disagree.
##
## `over` is **the strain a write takes out** (gene-catalogue.md §6.3): for an organ
## that holds one variant to a body (gene.gd's `one_variant`), the key of another
## variant of it the DNA carries -- the first in slot order -- which the write takes
## out wherever it is; `&""` for none, which is every placement today. No screen says
## it yet: its words wait for the first organ that turns the switch on.
func placing(gene: StringName, slot: int) -> Array:
	var form := form_at(gene, slot)
	if form == &"":
		return [PLACE_FACES_OUT, -1, &""]
	if _dna.has(form):
		return [PLACE_FULL if int(_dna[form]) >= TIER_MAX else PLACE_RAISE,
			dna_slot(form), &""]
	var over := _other_strains(form)
	return [PLACE_WRITE, slot, _slot_gene(over[0]) if not over.is_empty() else &""]


## **Where the DNA carries [param form]**: its outside slot, the inside slot that
## holds it, or -1 for a form it does not carry.
func dna_slot(form: StringName) -> int:
	if not _dna.has(form):
		return -1
	if is_inside_form(form):
		return INSIDE + maxi(inside_layout().find(form), 0)
	_sync_order()
	return _order.find(form)


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


## Where [param gene] is in the queue, or -1. **A gene with forms is found by
## its variety**: two meals of one toxin are one sample, whichever form each was
## eaten as (dna-slots.md §5.1).
func waiting_index(gene: StringName) -> int:
	var kind := variety(gene)
	for i in _waiting.size():
		if variety(_waiting[i].gene) == kind:
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
##
## **Across inside and outside it converts** (dna-slots.md §5.4): each of the two
## becomes the form of its new place, with its own slot's copies -- swapping
## your venom (slot 3, three copies) with your poison (one copy) gives three
## copies of poison and one of venom at slot 3. Between two outside slots the
## toxin stays venom, and only where it works changes. **Refused, changing
## nothing**, when either end would become nothing -- a gene that faces out,
## moved or swapped inside -- or a form already carried in a third slot: that
## would merge two slots into one and lose copies, and a move never destroys.
## [method can_move] answers the same question for the screen.
func move(from: int, to: int) -> bool:
	if move_refusal(from, to) != &"":
		return false
	var lifted := _slot_gene(from)
	var displaced := _slot_gene(to)
	if not is_inside(from) and not is_inside(to):
		_order[from] = displaced
		_order[to] = lifted
		return true
	var landed := form_at(lifted, to)
	var back := form_at(displaced, from) if displaced != &"" else &""
	var lifted_copies := int(_dna[lifted])
	var displaced_copies := int(_dna.get(displaced, 0))
	_dna.erase(lifted)
	if displaced != &"":
		_dna.erase(displaced)
	_dna[landed] = lifted_copies
	if back != &"":
		_dna[back] = displaced_copies
	for pair: Array in [[lifted, landed], [displaced, back]]:
		var was: StringName = pair[0]
		var now: StringName = pair[1]
		if was != now and now != &"" and _levels.has(was) and not _levels.has(now):
			_levels[now] = _levels[was]
	if not is_inside(from):
		_order[from] = back
	if not is_inside(to):
		_order[to] = landed
	_tend_levels()
	return true


## **Whether [method move] would move anything**, without moving it.
func can_move(from: int, to: int) -> bool:
	return move_refusal(from, to) == &""


## **Why [method move] would refuse**, or `&""` when it would not:
## [constant MOVE_NOTHING] (no move -- the same slot, a slot off the strand, an
## empty source), [constant MOVE_FACES_OUT] (a gene that faces out would go
## inside) or [constant MOVE_COLLISION] (one end would become a form already
## carried in a third slot). The screen says the second and third in words.
func move_refusal(from: int, to: int) -> StringName:
	_sync_order()
	if from == to or not _slot_ok(from) or not _slot_ok(to):
		return MOVE_NOTHING
	var lifted := _slot_gene(from)
	if lifted == &"":
		return MOVE_NOTHING
	var displaced := _slot_gene(to)
	var landed := form_at(lifted, to)
	if landed == &"":
		return MOVE_FACES_OUT
	var back := &""
	if displaced != &"":
		back = form_at(displaced, from)
		if back == &"":
			return MOVE_FACES_OUT
	if landed != lifted and landed != displaced and _dna.has(landed):
		return MOVE_COLLISION
	if back != &"" and back != displaced and back != lifted and _dna.has(back):
		return MOVE_COLLISION
	return &""


## Whether [param slot] is one a move may name: a slot of the DNA's outside
## layout, or the inside.
func _slot_ok(slot: int) -> bool:
	if is_inside(slot):
		return slot < INSIDE + INSIDE_SLOTS
	return slot >= 0 and slot < _order.size()


## **The form in [param slot]**, the inside included, `&""` for an empty one.
func _slot_gene(slot: int) -> StringName:
	if is_inside(slot):
		var held := inside_layout()
		var k := slot - INSIDE
		return held[k] if k >= 0 and k < held.size() else &""
	return _order[slot] if slot >= 0 and slot < _order.size() else &""


## **What the DNA carries inside** (dna-slots.md §2.2): its inside forms, in
## the catalogue's order and then any other, padded with `&""` to
## [member INSIDE_SLOTS]. **The inside keeps no order of its own**: nothing
## inside faces anywhere, so which inside slot holds what means nothing, and it is
## read off the DNA rather than kept -- which is why no save, no message and no
## rule of the referee's changes for it.
func inside_layout() -> Array[StringName]:
	return _inside_of(_dna)


## **What the body wears inside**: the same, off the body.
func body_inside() -> Array[StringName]:
	return _inside_of(_body)


## **The inside of [param tiers]**, a DNA or a body, gene to tier: what
## [method inside_layout] is of a genome, for a screen that has its file and no
## genome (docs/design/cells.md §6.6).
static func inside_of(tiers: Dictionary) -> Array[StringName]:
	return _inside_of(tiers)


static func _inside_of(tiers: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for gene: StringName in Catalogue.keys():
		if is_inside_form(gene) and tiers.has(gene):
			out.append(gene)
	for gene: StringName in tiers:
		if is_inside_form(gene) and not out.has(gene):
			out.append(gene)
	while out.size() < INSIDE_SLOTS:
		out.append(&"")
	return out


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
	_over_other_variants(_dna, gene, _order)
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
	_body[gene] = maxi(int(_body.get(gene, 0)), GIFT_TIER)
	body_version += 1
	if slot >= 0:
		_body_slots[gene] = slot
	_tend_levels()


func _first_free() -> int:
	_sync_order()
	return _order.find(&"")


## Keeps the layout the width of the body and free of anything the genome no
## longer carries. Growth only ever widens it, so nothing is dropped by this;
## the erase branch is what keeps a swap honest.
##
## **It seats outside forms only** (dna-slots.md §5.6): the layout is the
## outside's, and an inside form is never put into it.
func _sync_order() -> void:
	for gene: StringName in _dna:
		if is_inside_form(gene):
			continue
		if not _order.has(gene):
			var free := _order.find(&"")
			if free >= 0:
				_order[free] = gene
			else:
				_order.append(gene)
	for i in _order.size():
		if _order[i] != &"" and (not _dna.has(_order[i]) or is_inside_form(_order[i])):
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
	# `burn` is the one stat that buys upkeep back (`crista`'s), and it is
	# applied as a multiplier on the whole bill rather than as a subtraction: it
	# is worth most to the expensive build, which is the one that needs it.
	var burn := Stats.of(tiers, &"burn")
	return (1.0 + UPKEEP_PER_TIER * float(extra) + levelled) * burn


## The highest-tier gene, ties broken by arc order. Deterministic on purpose:
## the dominant gene is also what the cell looks like, so what you can see
## before you commit is exactly what you get.
##
## **Ties by rank** (the catalogue's `rank()`): of two genes at the same tier the
## earlier in the order wins, a gene with a place in it beats one with none, and
## two with none -- retired before the catalogue, or unknown to this build -- go
## by the genome's own dictionary order. One pass over what the body wears, not
## over every gene there is.
static func dominant_of(tiers: Dictionary) -> StringName:
	var best: StringName = &""
	var best_tier := 0
	var best_rank := -1
	for gene: StringName in tiers:
		var value := int(tiers[gene])
		if value <= 0 or value < best_tier:
			continue
		var rank := Catalogue.rank(gene)
		if value == best_tier and (rank < 0 or (best_rank >= 0 and rank > best_rank)):
			continue
		best_tier = value
		best = gene
		best_rank = rank
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
		if Catalogue.has_tag(gene, Catalogue.ALWAYS_EXPRESSED) \
				or randf() < EXPRESS_CHANCE[copies]:
			body[gene] = copies
	return body


## How likely one locus is to reach a daughter, for the one line on the pause
## screen that says so. The strand draws the copies; this is what they mean.
static func express_chance(gene: StringName, copies: int) -> float:
	if copies <= 0:
		return 0.0
	if Catalogue.has_tag(gene, Catalogue.ALWAYS_EXPRESSED):
		return 1.0
	return EXPRESS_CHANCE[clampi(copies, 0, TIER_MAX)]


## Writes [param gene] into [param tiers] in place. [param capacity] is how many
## slots the body has. Returns a [enum Result]; a full genome comes back as
## NO_ROOM, which only the node half knows what to do about (it holds it).
##
## **Room is by place** (dna-slots.md §5.7): an inside form asks for room
## inside, [member INSIDE_SLOTS], and every other gene for room outside,
## [param capacity] -- so a water cell's poison takes no arc. A genome with
## nothing inside counts exactly as it always did.
static func integrate_into(tiers: Dictionary, gene: StringName, capacity: int) -> int:
	if gene == &"":
		return Result.NOTHING
	if not tiers.has(gene):
		_over_other_variants(tiers, gene, [])
	if tiers.has(gene):
		var value := int(tiers[gene])
		if value >= TIER_MAX:
			return Result.SATURATED
		tiers[gene] = value + 1
		return Result.RAISED
	if is_inside_form(gene):
		if count_inside(tiers) >= INSIDE_SLOTS:
			return Result.NO_ROOM
	elif count_outside(tiers) >= capacity:
		return Result.NO_ROOM
	tiers[gene] = 1
	return Result.INTEGRATED


# --- Places and forms, as statics (docs/design/dna-slots.md §2, §3) ------------
# What a place, a form and a variety are, for any `{gene: tier}` map -- the
# player's genome node asks these as every cell in the water does.

## **The place [param slot] is in**: inside from [member INSIDE] on, outside
## before it.
static func place_of(slot: int) -> StringName:
	return INSIDE_PLACE if slot >= INSIDE else OUTSIDE_PLACE


## Whether [param slot] is inside the body.
static func is_inside(slot: int) -> bool:
	return slot >= INSIDE


## Whether [param slot] is at the front: the nose and the arc either side of it.
static func is_front(slot: int) -> bool:
	return FRONT.has(slot)


## **The place [param form] sits in**: its own, by the catalogue, and outside for
## a gene of one form.
static func place_of_form(form: StringName) -> StringName:
	return Catalogue.place_of(form)


## Whether [param form] sits inside: never in the outside layout, never on an arc.
static func is_inside_form(form: StringName) -> bool:
	return Catalogue.place_of(form) == INSIDE_PLACE


## Whether [param form] is one form of a gene with others.
static func has_forms(form: StringName) -> bool:
	return Catalogue.has_forms(form)


## **[param form]'s gene and strain, in [param place]**: the toxin's poison
## inside and its venom outside; a gene of one form is itself outside and
## `&""` -- it cannot sit there -- inside.
static func form_in(form: StringName, place: StringName) -> StringName:
	return Catalogue.form_in(form, place)


## [method form_in] at the place of [param slot]: what [param form] becomes there.
static func form_at(form: StringName, slot: int) -> StringName:
	return form_in(form, place_of(slot))


## Whether [param form] may sit in [param slot] as itself.
static func fits(form: StringName, slot: int) -> bool:
	return form != &"" and form_at(form, slot) == form


## **[param form]'s variety**: the first listed form of its gene and strain, the
## name it goes by where no place is known -- `veneneux` for both of the toxin's
## forms, today. Itself for a gene of one form.
static func variety(form: StringName) -> StringName:
	return Catalogue.variety(form)


## **Every form of [param form]'s gene and strain**, its variety first; itself
## alone for a gene of one form.
static func forms_of(form: StringName) -> Array[StringName]:
	return Catalogue.forms_of(form)


## The strain [param form] is of -- the kind of dose it delivers -- or `&""` for a
## gene of one form.
static func strain_of(form: StringName) -> StringName:
	return Catalogue.dose_of(form)


## **The name [param gene] goes by on screen**, where it is not its key (owner's
## row 1): its organ file's `NAMES` -- `toxicyst` for both of the toxin's forms --
## and its own key for every other gene. The keys never change; they are in saves
## and on the wire for good.
static func name_of(gene: StringName) -> String:
	return String(Catalogue.words(gene).get(&"name", gene))


## How many inside forms [param tiers] holds.
static func count_inside(tiers: Dictionary) -> int:
	var n := 0
	for gene: StringName in tiers:
		if is_inside_form(gene):
			n += 1
	return n


## How many genes of [param tiers] face out: the ones that take an arc.
static func count_outside(tiers: Dictionary) -> int:
	return tiers.size() - count_inside(tiers)


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
## **The mouth is never the gene that is replaced, nor the one that comes**: a
## gene tagged `never_drifts`. Every other trade here is even; losing the mouth is
## not, and a daughter born without one is a choice no one would make rather than
## a choice between two builds.
##
## **The toxin, by three rules** (dna-slots.md §5.5), and a genome with no toxin
## draws exactly what it always drew:
##
## - **what comes is a gene, not a form**: the pool leaves out every form but each
##   variety's first, and any variety the lineage carries in any form -- so the
##   toxin comes by `veneneux`'s name, as often as it ever did, and a lineage that
##   carries venom does not draw it again as poison;
## - **a toxin that comes takes the form of the slot it lands in**: venom, since
##   the gene it replaces sat outside. A water cell has no slots ([param seats]
##   empty), so its place is one more coin, drawn only when the toxin is what
##   comes;
## - **the poison that goes, inside, is replaced by a gene that faces out**, which
##   needs a free outside slot: a hole in a daughter's layout, or, for a water
##   cell, fewer genes outside than the plan has slots. With none, the drift does
##   not apply, and the caller's next kind is tried.
static func _mutate_drift(tiers: Dictionary, seats: Array[StringName]) -> bool:
	var goes: Array[StringName] = []
	var carried := {}
	var organs_carried := {}
	for gene: StringName in tiers:
		if not Catalogue.has_tag(gene, Catalogue.NEVER_DRIFTS):
			goes.append(gene)
		carried[variety(gene)] = true
		organs_carried[Catalogue.organ_of(gene)] = true
	# **What may come**: every live gene by the catalogue's order, a variety and
	# not yet carried -- and none of an organ that holds one variant to a body
	# (`one_variant`) while the lineage carries any of it.
	var comes: Array[StringName] = []
	for gene: StringName in Catalogue.live():
		var organ := Catalogue.organ_of(gene)
		if not Catalogue.has_tag(gene, Catalogue.NEVER_DRIFTS) and variety(gene) == gene \
				and not carried.has(gene) \
				and not (Catalogue.one_variant(organ) and organs_carried.has(organ)):
			comes.append(gene)
	if goes.is_empty() or comes.is_empty():
		return false
	var out: StringName = goes[randi() % goes.size()]
	# **An organ first -- an even draw, as it always was -- then one of its
	# varieties by their weights** (gene-catalogue.md §6.1): with one variety to
	# an organ, which is every organ today, the draw it always was.
	var organs := Catalogue.organs_in(comes)
	var into := Catalogue.pick_variety(Catalogue.of_organ(comes,
		organs[randi() % organs.size()]))
	var water := seats.is_empty()
	var form := into
	if has_forms(into):
		# The slot it lands in decides, and that slot is the outside one the gene
		# it replaces held. A water cell has none to read: a coin.
		if water:
			form = into if randi() % 2 == 0 else form_in(into, OUTSIDE_PLACE)
		else:
			form = form_in(into, OUTSIDE_PLACE)
	var tier := int(tiers[out])
	if is_inside_form(out) and not is_inside_form(form):
		# The poison goes and a gene that faces out comes: it needs an arc.
		if water:
			if count_outside(tiers) >= CellBody.SLOT_MAX:
				return false
		else:
			var hole := seats.find(&"")
			if hole < 0:
				return false
			seats[hole] = form
		tiers[form] = tier
		tiers.erase(out)
		return true
	tiers[form] = tier
	tiers.erase(out)
	var slot := seats.find(out)
	if slot >= 0:
		seats[slot] = &"" if is_inside_form(form) else form
	return true
