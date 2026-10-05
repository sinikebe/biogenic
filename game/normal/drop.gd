extends RefCounted
## **The drop**: a round drop of pond water twelve millimetres across, on a
## glass slide, and everything in it all the time (docs/design/ocean.md). This
## file is the environment -- this water's numbers by name, and the decisions
## only this water makes -- and a second water is a second file like it.
##
## **What it knows**: the drop, its edge (the meniscus), its snow of detritus
## (flocs), how many live in it, and four decisions: **what is short**,
## **whose turn it is**, **where a run starts** and **what a new body is made
## of** (§13). **What it does not know** is how the arithmetic works: the rim
## is a `basin.gd`, nearness a `space_grid.gd`, the spawner's debt a
## `replenish.gd` and the snow a `snowfall.gd`, all in game/mechanics/ and none
## of them knowing it is water. Nor does it draw or run a cell: food.gd's
## `_seed_drifter`, `_seed_peer` and `_draw_genome` make the body, to the plan,
## the gift and the gene pool decided here.
##
## **food.gd holds one of these for a run in the drop** (its `setup_drop`),
## and asks it every one of those decisions; a run with a session up plays
## today's water and never makes one (§10.1). It does not preload food.gd, so
## food.gd can preload it: a list of the catalogue's -- the genes a drifter can
## carry, the senses -- is passed in by the caller.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Basin := preload("res://game/mechanics/basin.gd")
const SpaceGrid := preload("res://game/mechanics/space_grid.gd")
const Replenish := preload("res://game/mechanics/replenish.gd")
const Snowfall := preload("res://game/mechanics/snowfall.gd")
const Rulebook := preload("res://game/mechanics/rulebook.gd")
const Genome := preload("res://game/normal/genome.gd")
## The genes there are (docs/design/gene-catalogue.md): the born cell's body plan.
const Catalogue := preload("res://game/genes/catalogue.gd")

# --- Size and shape (§2) -----------------------------------------------------

## The meniscus: 6 mm from the middle, a drop 12 mm across (row 1). One world
## unit is one µm.
const RADIUS := 6000.0
## The band inside the rim where the water thins: full vision's lit film, and
## where a drifting body turns back rather than grind along the edge (§3).
const SHALLOWS := 240.0

# --- The edge: the meniscus (§3) ------------------------------------------------

## How fast a drifting body in the shallows turns toward the middle, radians a
## second at the rim, falling to nothing at the band's inner edge.
const SHORE_TURN := 1.4
## The player against the meniscus: the share of its speed into the rim it
## keeps, how fast it must be going into it to feel it, and how often it can.
const SHORE_RESTITUTION := 0.2
const SHORE_FELT_SPEED := 6.0
const SHORE_GAP := 0.6
## An `ampulla` hears the rim as one body this wide, at its nearest point: the
## widest, longest echo in the game.
const EDGE_ECHO_RADIUS := 80.0
## A `stigma` sees the rim as a shadow this deep at the closest, against a
## body's 1, fading to nothing at food.gd's SHADOW_RANGE.
const EDGE_SHADOW := 0.6

# --- Everything in it, all the time (§4) --------------------------------------

## A bucket of the grid, and one of them past the rim all round.
const GRID_CELL := 400.0
## What a query asks past its reach, for what moved since a body was filed.
const GRID_SLACK := 40.0
## A prey search looks this near first: a winner within it is the winner.
const PREY_NEAR := 400.0
## Within this of a player, every frame: the view on the widest phone, its
## camera's lead and a margin.
const LOD_FULL := 1100.0
## Within this, every second frame, with the time it is owed: past the
## farthest any sense reaches.
const LOD_NEAR := 2000.0
## Past it, a body with a mouth steps on its tick: its slot modulo this, so a
## tick is a stride through the bodies, never a scan. Even, so a body in the
## half-rate band is always stepped on its tick.
const LOD_EVERY := 8
## And a body with no mouth -- a drifter, a floc -- once in this many ticks.
const LOD_SLOW := 4
## The far rate with nobody in the drop at all: the server's empty room
## (§10.3). The same as [constant LOD_EVERY], so the room is one drop whether
## anyone is in it or not.
const EMPTY_LOD_EVERY := 8

# --- How many, how often, where (§6) ------------------------------------------

## Living bodies per µm²: 4.9 per million, 554 in the drop. What a player
## swims through in today's water, not its nominal 3.74 (§6.1).
const DENSITY := 4.9e-6
## A shortfall is paid back over this many seconds...
const SPAWN_TAU := 5.0
## ...a half second at a time...
const SPAWN_TICK := 0.5
## ...and no more than this many bodies a tick.
const SPAWN_BURST := 8
## **The share of today's hunters the spawner keeps at least** (lineage.md
## §2.2, §5): all of them. In pack 1 it was the share of the whole population
## the spawner kept up; since bodies divide (pack 2) it is **a floor** -- the
## owner's "at least as many as today" -- under which a peer is made, and over
## which the hunters are what their families feed ([method hunter_floor]).
const SPAWN_SHARE := 1.0
## **The floor is paid back within this many seconds** (lineage.md §5), where
## the food keeps [constant SPAWN_TAU]: daughters die fast, and a floor paid
## back over five seconds stood about five seconds of deaths under today's count.
const FLOOR_TAU := 1.0
## Candidate points drawn for each new body, and the thinnest taken...
const SPAWN_TRIES := 12
## ...by how many living bodies lie within this of it.
const SPAWN_SCAN := 800.0
## Half the candidates are drawn in a ring this wide just past a player's
## hide reach, so a grazed-out place refills from the horizon inward.
const SPAWN_RING := 800.0
## Nothing new is made nearer the rim than this: the prototype's number
## (§6.3), never measured on its own.
const SPAWN_INSET := 80.0
## What full vision shows round a player on the widest phone, a 20:9 screen's
## half-diagonal of 877 and the camera's lead of 72: nothing is made inside it.
const VIEW_REACH := 949.0
## And past every reach, this much more.
const HIDE_MARGIN := 100.0
## Every gene a drifter can carry is carried by at least this many living
## bodies: short of it, the next drifter carries it (§6.4)...
const GENE_FLOOR := 2
## ...counted every this many seconds.
const GENE_FLOOR_EVERY := 2.0
## The drifter floor: with no living drifter within a player's hide reach and
## this much more, one is made just past its horizon, ahead of it. **The hide
## reach for a body with a mouth** -- about 1,500 for a born cell -- although
## what it makes is a drifter, as the prototype's floor had it (§6.4)...
const DRIFTER_FLOOR_SLACK := 600.0
## ...between this far and this far past that reach: the prototype's numbers,
## never measured on their own...
const DRIFTER_FLOOR_NEAR := 50.0
const DRIFTER_FLOOR_FAR := 350.0
## ...at most once in this many seconds.
const DRIFTER_FLOOR_GAP := 10.0
## A new body is fed. A drop being made for the first time is a drop that was
## already there, so its tanks are drawn up to this (§5.8).
const FIRST_HUNGER_MAX := 0.4
## Where the first fill puts its bodies, this far inside the rim at least: the
## prototype's number (§6.3), never measured on its own.
const FILL_INSET := 60.0

# --- Food that isn't alive: flocs (§7) -----------------------------------------

## Snow falls everywhere at one rate: flocs per million µm² a second, 8 a
## second over the whole drop.
const SNOW := 0.072
## A flake stays with a chance of `1 - n / (SNOW_SHARE * expected)`, where n
## counts the living bodies within SNOW_SCAN of it and expected is the drop's
## density over that disc: a place holding half its share keeps nothing.
const SNOW_SCAN := 800.0
const SNOW_SHARE := 0.5
## Nothing lands nearer the rim than this: the prototype's number (§7.2), never
## measured on its own.
const SNOW_INSET := 40.0
## A floc settles into view over this many seconds: its scent, its drawing and
## its edibility ramp from nothing, and nothing eats it before it has settled.
const FLOC_SETTLE := 5.0
## It dissolves after this long, give or take this share, over the same five
## seconds in reverse. Flocs never move.
const FLOC_LIFE := 120.0
const FLOC_LIFE_SPREAD := 0.25
## A floc's radius: always in a born cell's mouth.
const FLOC_MIN := 8.0
const FLOC_MAX := 14.0
## What eating a floc grows a body by: nothing (row 6). Food, and only food.
const FLOC_GROWTH := 0.0
## A body that dies of hunger or of poison leaves a floc where it died, this
## share of its radius, already settled; no smaller than a floc, no bigger than
## this (§7.4).
const REMAINS_SHARE := 0.5
const REMAINS_MAX := 18.0
## A drop being made for the first time already holds this many settled flocs,
## anywhere in it: §5.9's thirty at the first census, the prototype's stock at
## a drop's making, never measured on its own. The snow and the dead keep the
## count from there.
const FIRST_FLOCS := 30

# --- Where a run starts (§8.1) --------------------------------------------------

## Points drawn for a start, each at least this far inside the rim...
const START_TRIES := 64
const START_INSET := 1000.0
## ...none with anything edible within this: the first meal is found, not
## handed over...
const START_CLEAR := 400.0
## ...ties on dread going to the most food within this...
const START_FOOD := 1100.0
## ...and whatever could swallow a born cell and is still within dread's reach
## of the start is moved straight out to that reach and this much more.
const START_PUSH := 100.0

## **The gene no drifter carries** (row 13, and docs/design/dna-slots.md §9): the
## toxin, by its variety's name, in either of its forms -- venom outside, poison
## inside. The drop's defenceless food is never poisonous to eat, and a mouthless
## drifter's venom would bite nothing anyway; a drop short of it gets it back
## through the next peer, its place by a coin.
const TOXIN := &"veneneux"

# --- How its cells behave (docs/design/behaviour.md §5, §6) --------------------

## **The founders' rules** (behaviour.md §5.1, row 22): what every body this
## water makes carries -- today's hunting, re-derived under the owner's rule
## that a body knows only what its own senses report. In plain words: *rest for
## five seconds after eating, and while less than a third hungry. Otherwise turn
## toward an echo of something smaller than my mouth; otherwise toward whatever
## my laser touches; otherwise, when the smell of food fades, turn at random.
## Swim, and push at half strength.* A rule for an organ a founder lacks is
## passed over, and waits, inherited, for a daughter who grows the organ.
##
## `HUNT_AT` and `REST_MEAL`, today's constants, are the 0.3 and the 5 here:
## values in each body's rules, not rules of the water. A body whose `brain` is
## null carries these (food.gd). A second water writes its own founders in its
## own file.
const FOUNDERS: Array[String] = [
	"metabolism.fed below 5 -> body.rest",
	"metabolism.hunger below 0.3 -> body.rest",
	"ampulla.echo size below mouth -> body.turn-toward",
	"ocellus.beam -> body.turn-toward",
	"chemocyte.smell level falling -> body.turn-random",
	"always -> body.swim",
	"always -> axoneme.push 0.5",
]
## **The most rules a list holds** (behaviour.md §6.2): one phone screen (§11).
## A change at division never copies a rule past it.
const MOST_RULES := 8
## **The kinds of change at a division, by weight** (behaviour.md §6.2, §6.5),
## by rulebook.gd's names for them: mostly the small step -- a test's value or a
## push's strength one place along its ladder -- then a part replaced, which is
## where new rules come from, and the three that reorder, grow and shrink a
## list. Starting values, for the playtest: a water that never changes wants
## more replace, and one that cannot keep a way of hunting more nudge.
const CHANGES := {&"nudge": 5.0, &"replace": 2.0, &"swap": 1.0, &"copy": 1.0, &"drop": 1.0}

## The meniscus: a disc of [constant RADIUS] round wherever the drop is.
var meniscus: Basin = null
## Which bodies are near a place, over the square round the drop.
var grid: SpaceGrid = null
## The spawner's debt: against the drop's population in pack 1, and since
## bodies divide against the food's shortfall and the hunters' under their
## floor, summed (lineage.md §5).
var spawner: Replenish = null
## The snow.
var snow: Snowfall = null


func _init(center := Vector2.ZERO) -> void:
	meniscus = Basin.new(center, RADIUS)
	grid = SpaceGrid.new(center, RADIUS + GRID_CELL, GRID_CELL)
	spawner = Replenish.new(roundi(float(target()) * SPAWN_SHARE), SPAWN_TAU,
		SPAWN_BURST)
	snow = Snowfall.new(SNOW * 1e-6, SNOW_SHARE)


# --- The drop's own arithmetic ---------------------------------------------------

## **How many live in the drop**: its density over its area, 554.
static func target() -> int:
	return roundi(DENSITY * PI * RADIUS * RADIUS)


## How many living bodies a place of [constant SNOW_SCAN] round a flake holds at
## the drop's density: 9.9.
static func snow_expected() -> float:
	return DENSITY * PI * SNOW_SCAN * SNOW_SCAN


## **A player's hide reach for one kind of body** (§6.3): nothing of that kind
## is made nearer than this. The view on the widest phone, and every reach the
## player's senses have -- [param senses], the widest of its smell, its ping
## and its beam -- and [param dread] as well when the body has a mouth, which a
## membrane dreads; then [constant HIDE_MARGIN]. A mouthless body raises no
## dread, so for a born cell a drifter may be made at 1,050 to 1,200 by which
## sense it was given, and a peer at 1,500.
static func hide_reach(senses: float, dread: float, mouth: bool) -> float:
	var reach := maxf(VIEW_REACH, senses)
	if mouth:
		reach = maxf(reach, dread)
	return reach + HIDE_MARGIN


## **How fast a body [param depth] inside the rim turns off the shore**,
## radians a second: [constant SHORE_TURN] at the rim, nothing at the inner
## edge of the shallows and beyond. Only a body heading outward turns; the
## caller knows which way it is heading.
static func shore_turn(depth: float) -> float:
	return SHORE_TURN * (1.0 - clampf(depth / SHALLOWS, 0.0, 1.0))


## The radius of the floc a body of radius [param r] leaves where it died.
static func remains_radius(r: float) -> float:
	return clampf(r * REMAINS_SHARE, FLOC_MIN, REMAINS_MAX)


## A fallen floc's radius.
static func floc_radius() -> float:
	return randf_range(FLOC_MIN, FLOC_MAX)


## How long a floc lasts before it dissolves.
static func floc_life() -> float:
	return FLOC_LIFE * randf_range(1.0 - FLOC_LIFE_SPREAD, 1.0 + FLOC_LIFE_SPREAD)


## The hunger a new body starts at: fed, unless it is part of the first fill of
## a drop, which was already there before anyone looked.
static func made_hunger(first_fill: bool) -> float:
	return randf_range(0.0, FIRST_HUNGER_MAX) if first_fill else 0.0


# --- What is short (§6.4) ------------------------------------------------------

## **Whether the next body is a drifter**: when the living drop's share of
## drifters is under [param share], the share the players' senses call for --
## asked of the standing drop rather than of each arrival, because hunters eat
## drifters faster than anything else dies. Pack 1's spawner, which made every
## body; pack 2's keeps each kind to its own count below.
static func wants_drifter(living: int, drifters: int, share: float) -> bool:
	return float(drifters) < share * float(maxi(living, 1))


## **The food's count** (lineage.md §5): the drifters the spawner keeps, their
## [param share] of [method target] -- 457 at a newborn's composition and 354 at
## a sighted player's -- **whatever the hunters number**. Drifters never divide,
## so the spawner makes every one.
static func food_count(share: float) -> float:
	return share * float(target())


## **The hunters' floor** (lineage.md §2.2, §5): today's count -- what pack 1's
## spawner kept, `(1 - share) * target()`, 96.4 at a newborn's composition and
## 200.5 at a sighted player's -- times [param keep], [constant SPAWN_SHARE] in
## the game. Under it the spawner makes a peer; over it births decide.
static func hunter_floor(share: float, keep := SPAWN_SHARE) -> float:
	return (1.0 - share) * float(target()) * keep


## **The genes the drop is down to its last carriers of**: every one of
## [param genes] that fewer than [constant GENE_FLOOR] living bodies carry,
## given [param counts] of carriers by gene, in [param genes]' order.
static func short_genes(counts: Dictionary, genes: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for gene: StringName in genes:
		if int(counts.get(gene, 0)) < GENE_FLOOR:
			out.append(gene)
	return out


## **The gene the next drifter carries for the floor**, taken off
## [param short]: the last there that is not the toxin, in any form, which comes
## back through a peer instead. Empty when nothing a drifter may carry is short.
static func take_drifter_gene(short: Array[StringName]) -> StringName:
	for i in range(short.size() - 1, -1, -1):
		if Genome.variety(short[i]) != TOXIN:
			var gene := short[i]
			short.remove_at(i)
			return gene
	return &""


# --- Whose turn it is (§6.4, §10.2) ------------------------------------------------

## **The player the next body is made for**, after [param turn], among
## [param players]: each in turn, as the owner answered in shared-pond.md §6
## row 2. Always 0 for one player or none.
static func next_turn(turn: int, players: int) -> int:
	if players < 2:
		return 0
	return posmod(turn + 1, players)


# --- What a new body is made of (§5.8) ----------------------------------------------

## **A peer's body plan**: a born cell's -- a mouth, a `cirrus` and a
## `flagellum` -- at tiers drawn as today, before anything else is drawn into
## the slots its radius has. A cell made to live, where today's peers are a
## mouth and whatever the dice give.
static func peer_plan() -> Array[StringName]:
	var plan: Array[StringName] = []
	for gene: StringName in Catalogue.born():
		plan.append(gene)
	return plan


## **The gift**: a peer that carries none of [param senses] is given one at
## tier 1, in a bonus slot -- as the player's newborn is at five seconds: the
## organ [param pick] names among theirs, then one of its varieties by weight
## (gene-catalogue.md §6.1), which with one variety to an organ is `senses[pick]`.
## Returns whether it was.
static func give_sense(tiers: Dictionary, senses: Array[StringName], pick: int) -> bool:
	if senses.is_empty():
		return false
	for sense: StringName in senses:
		if int(tiers.get(sense, 0)) > 0:
			return false
	var organs := Catalogue.organs_in(senses)
	tiers[Catalogue.pick_variety(Catalogue.of_organ(senses,
		organs[posmod(pick, organs.size())]))] = 1
	return true


## **What a drifter's one gene is drawn from**: [param genes] without the
## toxin, in any of its forms (row 13).
static func drifter_genes(genes: Array[StringName]) -> Array[StringName]:
	var pool: Array[StringName] = []
	for gene: StringName in genes:
		if Genome.variety(gene) != TOXIN:
			pool.append(gene)
	return pool


## **What a water cell's two daughters are made of** (lineage.md §3.1, §3.3,
## row 19): `[faithful, changed, kind]` -- one her [param dna] as it is, the
## other with one mutation, **every division**, by the player's own
## `Genome.mutated`, called as the choosing screen calls it. A water cell has
## no slot layout, so of the player's three kinds a shift has nothing to move
## and `kind` is a trade or a drift. Which daughter is which is the caller's
## coin. Draws from the global stream: a division is the simulation's.
static func daughter_dna(dna: Dictionary) -> Array:
	var rolled: Array = Genome.mutated(dna, [])
	return [dna.duplicate(), rolled[0], rolled[2]]


## **What a water cell's two daughters' rules are** (behaviour.md §6.1-§6.3):
## `[faithful, changed, kind]` -- one her mother's [param list] as it is, the
## other with one change of [constant CHANGES]' kinds, no longer than
## [constant MOST_RULES], drawing anything new from [param vocab]'s parts whose
## owners [param owners] holds: the body's, the metabolism's and every gene the
## changed daughter's DNA carries, worn or not (`Rulebook.worn` over her DNA). The
## daughter whose DNA [method daughter_dna] changed is the one who carries the
## changed list, and the caller's coin says which daughter that is. `kind` is
## rulebook.gd's word for the change, empty for a list nothing can change. Draws
## from the global stream: a division is the simulation's.
static func daughter_behaviours(list: Rulebook.Behaviour, vocab: Rulebook.Vocabulary,
		owners: int) -> Array:
	var rolled: Array = Rulebook.changed(list, vocab, owners, CHANGES, MOST_RULES)
	return [list, rolled[0], rolled[1]]


## **The toxin back through a peer**, when the floor wants it: at tier 1, and
## [param inside] -- the coin -- as poison, or outside as venom (docs/design/
## dna-slots.md §9). Poison takes no arc. Venom takes one, as the old gene did: a
## peer with no room outside gives up a gene for it -- `pick` chooses which --
## but never one of its body plan or of [param senses], so it stays a cell that
## can live; with nothing else to give up, it takes a bonus slot. Nothing, for a
## peer that carries the toxin in either form.
static func give_toxin(tiers: Dictionary, slots: int, senses: Array[StringName],
		pick: int, inside: bool) -> void:
	for form: StringName in Genome.forms_of(TOXIN):
		if int(tiers.get(form, 0)) > 0:
			return
	var form := Genome.form_in(TOXIN, Genome.INSIDE_PLACE if inside else Genome.OUTSIDE_PLACE)
	if not Genome.is_inside_form(form) and Genome.count_outside(tiers) >= slots:
		var plan := peer_plan()
		var spare: Array[StringName] = []
		for gene: StringName in tiers:
			if not plan.has(gene) and not senses.has(gene) and not Genome.is_inside_form(gene):
				spare.append(gene)
		if not spare.is_empty():
			tiers.erase(spare[posmod(pick, spare.size())])
	tiers[form] = 1


# --- Where things go ------------------------------------------------------------------

## A point drawn evenly over the drop, at least [param inset] inside the rim.
func uniform_point(inset: float) -> Vector2:
	var reach := maxf(RADIUS - inset, 0.0) * sqrt(randf())
	var angle := randf_range(-PI, PI)
	return meniscus.center + Vector2(cos(angle), sin(angle)) * reach


## **Where the spawner may put the next body** (§6.3): [constant SPAWN_TRIES]
## points, every second one in the ring [constant SPAWN_RING] wide just past
## the hide reach of the player whose turn it is and the rest anywhere in the
## drop, each kept only if it lies outside every player's hide reach.
## [param players] are where the players are and [param hides] their hide
## reaches for the kind being made. The spawner takes the thinnest of what is
## left ([method Replenish.thinnest]); with nothing left, nothing is made.
func spawn_candidates(players: PackedVector2Array, hides: PackedFloat32Array,
		turn: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for t in SPAWN_TRIES:
		var at := Vector2.ZERO
		if t % 2 == 1 and not players.is_empty():
			var k := clampi(turn, 0, players.size() - 1)
			var hide := float(hides[k]) if k < hides.size() else 0.0
			var angle := randf_range(-PI, PI)
			at = players[k] + Vector2(cos(angle), sin(angle)) \
				* randf_range(hide, hide + SPAWN_RING)
			if not meniscus.inside(at, SPAWN_INSET):
				continue
		else:
			at = uniform_point(SPAWN_INSET)
		if Replenish.hidden(at, players, hides):
			out.append(at)
	return out


## **Where a run starts** (§8.1, row 9): of [constant START_TRIES] points at
## least [constant START_INSET] inside the rim, those with anything edible
## within [constant START_CLEAR] thrown away, the one where a born cell would
## feel the least dread; ties to the most food within [constant START_FOOD].
## [param food_near] takes a point and a reach and says how much edible lies
## within it; [param dread_at] takes a point and says what a born cell there
## would dread. The middle, if every point had food on top of it.
func quiet_start(food_near: Callable, dread_at: Callable) -> Vector2:
	var best := meniscus.center
	var least := INF
	var most := -1
	for t in START_TRIES:
		var at := uniform_point(START_INSET)
		if int(food_near.call(at, START_CLEAR)) > 0:
			continue
		var dread := float(dread_at.call(at))
		var food := int(food_near.call(at, START_FOOD))
		# A millionth of dread is a tie: the sum is over bodies at distances,
		# and two starts that feel nothing both read 0 to within that.
		if dread < least - 1e-6 or (absf(dread - least) <= 1e-6 and food > most):
			best = at
			least = dread
			most = food
	return best


## **Where a body at [param at] that could swallow a newborn starting at
## [param start] is moved**: straight out from the start to [param reach] --
## dread's -- and [constant START_PUSH] more, held inside the rim at its
## [param r].
##
## **And slid along the rim when the rim holds it back** (the review's S3). A
## start may be as little as [constant START_INSET] inside the rim, less than
## the push, so a mouth on the rim's side of it is put back on the circle
## `RADIUS - r` -- which can still be inside dread's reach of the start. It is
## slid along that circle, on the side it was on, to the nearest point clear
## of the start by the whole push. From anywhere a start can be there is one:
## the far side of the circle is `RADIUS - r` and more from it.
func pushed_clear(start: Vector2, at: Vector2, reach: float, r: float) -> Vector2:
	var off := at - start
	var away := off.normalized() if off.length_squared() > 1e-6 else Vector2.RIGHT
	var clear := reach + START_PUSH
	var put := meniscus.contain(start + away * clear, r)
	if put.distance_to(start) >= clear - 1e-3:
		return put
	var centre := meniscus.center
	var ring := maxf(meniscus.radius - maxf(r, 0.0), 0.0)
	var from := start - centre
	var s := from.length()
	if s <= 1e-3 or ring <= 0.0:
		return put
	# |start - q|² = s² + ring² - 2 s ring cos(φ) for q on the circle, φ its
	# angle from the start's own bearing: clear once cos(φ) is at most this.
	var most := clampf((s * s + ring * ring - clear * clear) / (2.0 * s * ring), -1.0, 1.0)
	var bearing := from.angle()
	var side := angle_difference(bearing, (put - centre).angle())
	var turn := acos(most) * (-1.0 if side < 0.0 else 1.0)
	return meniscus.contain(centre + Vector2.from_angle(bearing + turn) * ring, r)


## **The drop moves by [param by]**: its rim and its grid with it. Every body
## must be moved as far and filed in the grid again -- the grid starts over.
## How a run starts where the cell already is, so the camera does not jump.
func shift(by: Vector2) -> void:
	meniscus.center += by
	grid.setup(meniscus.center, RADIUS + GRID_CELL, GRID_CELL)
