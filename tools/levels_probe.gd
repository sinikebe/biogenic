extends Node
## CI probe: **levels, the lineage, the price, and the fan** (docs/design/
## beam-levels.md). Everything here is arithmetic and bookkeeping that a render
## cannot show and a player would only find an hour into a run: a level that
## does not survive a division, a fork that can be taken twice, a sweep that a
## slow phone crosses with gaps in it, a skip that drops a body a ray would
## have hit.
##
## **And what moving costs** (docs/design/energy.md): the same kind of number,
## invisible in a frame and felt only as a cell that starves sooner than it
## should, or later.
##
## **And the numbers a player can ask to see** (docs/design/gene-stats.md): the
## formatter's rules, a few rows of the table against the constants they are
## read off, the dash paid the way its row says, and the toxin's rows -- venom
## by where it works, poison, and a stack diluted by the reader's size
## (docs/design/dna-slots.md §3.3).
##
## **And hunger, as the player is warned of it** (docs/design/hunger.md): the
## beat that races, never slows and never dims, the body's slack and the
## membrane's fall, read off the one mapping in metabolism.gd -- a number that
## would show only as a warning that came too late, or not at all.
##
## **And what a dose is worth** (docs/design/dna-slots.md §6.2, §20.3 check 4):
## one stack of harm takes what it says of a body of each size, a body carrying
## harm does not mend and mends from the moment it is gone, and a body stepped
## every eighth frame ends where one stepped every frame does.
##
## Headless and deterministic. Prints one line per check and `ALL PASS` only if
## every one held; CI asserts on that marker rather than on the exit code,
## because Godot exits 0 after a script error too.

const Progression := preload("res://game/mechanics/progression.gd")
const RayFan := preload("res://game/mechanics/ray_fan.gd")
const Tally := preload("res://game/mechanics/tally.gd")
const Afterglow := preload("res://game/mechanics/afterglow.gd")
const CellBody := preload("res://game/normal/cell.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const FoodField := preload("res://game/normal/food.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")
const Readout := preload("res://game/mechanics/readout.gd")
const GeneStats := preload("res://game/normal/gene_stats.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
const Doses := preload("res://game/mechanics/doses.gd")
## The genes, and their numbers by stat (docs/design/gene-catalogue.md).
const Catalogue := preload("res://game/genes/catalogue.gd")
const Stats := preload("res://game/genes/stats.gd")

var _failed := 0
var _nodes: Array[Node] = []


func _ready() -> void:
	_progression()
	_fork()
	_lineage()
	_price()
	_shape()
	_fan()
	_tally_and_glow()
	_field()
	_energy()
	_alarm()
	_gene_stats()
	_doses()
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	print("[levels-probe] ALL PASS" if _failed == 0
		else "[levels-probe] FAILED %d" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("[levels-probe] %s %s" % ["PASS" if ok else "FAIL", what])


# --- The curve ---------------------------------------------------------------

func _progression() -> void:
	var step := 40.0
	var levels := PackedInt32Array()
	for xp: float in [0.0, 39.999, 40.0, 119.999, 120.0, 240.0, 1800.0, 1799.99]:
		levels.append(Progression.level_at(xp, step))
	_check("level is 1 at nothing, 2 at one step, 3 at three, 4 at six, 10 at 45: %s"
		% levels, levels == PackedInt32Array([1, 1, 2, 2, 3, 4, 10, 9]))
	var exact := true
	for at in range(1, 100):
		var start := Progression.xp_at(at, step)
		exact = exact and Progression.level_at(start, step) == at \
			and Progression.level_at(start - 0.001, step) == maxi(at - 1, 1)
	_check("every level from 1 to 99 starts exactly where the curve says", exact)
	var grown := Progression.new(step, 3, [&"a", &"b"] as Array[StringName])
	grown.earn(60.0)
	_check("halfway through level 2, 60 still to go: progress %.2f, next in %.1f"
		% [grown.progress(), grown.to_next()],
		is_equal_approx(grown.progress(), 0.25) and is_equal_approx(grown.to_next(), 60.0))
	grown.earn(-50.0)
	_check("experience is never lost", is_equal_approx(grown.xp, 60.0))


func _fork() -> void:
	var grown := Progression.new(40.0, 3, [&"extend", &"sweep"] as Array[StringName])
	grown.xp = Progression.xp_at(2, 40.0)
	_check("before the fork a path is refused",
		not grown.can_choose() and not grown.choose(&"sweep") and grown.path == &"")
	grown.xp = Progression.xp_at(7, 40.0)
	_check("past the fork with no path, the level banks and it works at 3 (%d, %d)"
		% [grown.level(), grown.effective_level()],
		grown.level() == 7 and grown.effective_level() == 3 and grown.can_choose())
	_check("a path it does not offer is refused",
		not grown.choose(&"laser") and grown.path == &"")
	_check("taking one spends every banked level at once",
		grown.choose(&"sweep") and grown.effective_level() == 7)
	_check("and it is for good", not grown.choose(&"extend") and grown.path == &"sweep")
	var twin: RefCounted = grown.copy()
	twin.earn(1000.0)
	_check("a copy is its own: the original did not move",
		is_equal_approx(grown.xp, Progression.xp_at(7, 40.0)) and twin.path == &"sweep")
	var back := Progression.new(40.0, 3, [&"extend", &"sweep"] as Array[StringName])
	back.set_state([200.0, &"warp"])
	_check("a recorded path this build does not offer comes back untaken",
		back.path == &"" and is_equal_approx(back.xp, 200.0))


# --- The lineage (§3) ----------------------------------------------------------

func _genome() -> Node:
	var g: Node = GenomeNode.new()
	_nodes.append(g)
	return g


func _lineage() -> void:
	var mother := _genome()
	mother.express({&"cytostome": 1, &"cirrus": 1, &"ocellus": 1},
		[&"cytostome", &"cirrus", &"ocellus"])
	_check("a levelled gene arrives at level 1",
		mother.level_of(&"ocellus") == 1 and mother.progression(&"ocellus") != null)
	_check("a gene that does not level has no progression and reads its tier",
		mother.progression(&"cirrus") == null and mother.level_of(&"cirrus") == 1)
	mother.earn(&"ocellus", Progression.xp_at(5, _beam_step()))
	mother.choose(&"ocellus", &"extend")
	_check("worn and used, it levels: %d" % mother.level_of(&"ocellus"),
		mother.level_of(&"ocellus") == 5)

	# A daughter who carries it and grows it, and one who carries it and does not.
	var grew := _genome()
	grew.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"],
		{&"cytostome": 1, &"ocellus": 1}, null, mother.levels())
	var dormant := _genome()
	dormant.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"],
		{&"cytostome": 1}, null, mother.levels())
	_check("a daughter who grew it keeps its level and path",
		grew.level_of(&"ocellus") == 5 and grew.path_of(&"ocellus") == &"extend")
	_check("a daughter who carries it without growing it keeps it too",
		dormant.progression(&"ocellus") != null
		and dormant.progression(&"ocellus").level() == 5)
	_check("and cannot earn with an organ she does not wear",
		not dormant.earn(&"ocellus", 500.0)
		and dormant.progression(&"ocellus").level() == 5)
	grew.earn(&"ocellus", 1000.0)
	_check("each daughter's level is her own", mother.level_of(&"ocellus") == 5)

	var drifted := _genome()
	drifted.express({&"cytostome": 1, &"palp": 1}, [&"cytostome", &"palp"], null,
		null, mother.levels())
	_check("a daughter whose DNA lost the gene loses the level",
		drifted.progression(&"ocellus") == null)

	var reborn := _genome()
	reborn.express(Catalogue.born(), Catalogue.born_order())
	reborn.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"])
	_check("a death, or a forced genome, starts over at level 1",
		reborn.level_of(&"ocellus") == 1)

	# Written over in the DNA: kept while the body still wears it.
	var over := _genome()
	over.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"])
	over.earn(&"ocellus", Progression.xp_at(3, _beam_step()))
	over.integrate(&"palp")
	over.place(1)
	_check("placed over in the DNA, the body still wears it and keeps its level",
		not over.dna().has(&"ocellus") and over.level_of(&"ocellus") == 3)
	var child := _genome()
	child.express(over.dna(), over.layout(), null, null, over.levels())
	_check("and her daughters, who do not carry it, do not inherit it",
		child.progression(&"ocellus") == null)
	var back := _genome()
	back.express({&"cytostome": 1, &"palp": 1, &"ocellus": 1},
		[&"cytostome", &"palp", &"ocellus"], null, null, over.heritable_levels())
	_check("a drift that brings it back to a daughter brings it back new, at 1",
		back.level_of(&"ocellus") == 1 and back.path_of(&"ocellus") == &"")


# --- The price (§5) ------------------------------------------------------------

func _price() -> void:
	var g := _genome()
	g.express({&"cytostome": 1, &"ocellus": 3}, [&"cytostome", &"ocellus"])
	_check("three copies and level 1 cost nothing: copies are odds now (%.2f)"
		% g.upkeep(), is_equal_approx(g.upkeep(), 1.0))
	var rows := []
	var want := {3: [1.36, 1.36], 5: [1.72, 1.54], 10: [2.62, 1.99]}
	var ok := true
	for at: int in want:
		for i in 2:
			var path: StringName = [&"extend", &"sweep"][i]
			var one := _genome()
			one.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"])
			one.earn(&"ocellus", Progression.xp_at(at, _beam_step()))
			one.choose(&"ocellus", path)
			rows.append("%s %d %.2f" % [path, at, one.upkeep()])
			ok = ok and is_equal_approx(one.upkeep(), float(want[at][i]))
	_check("x per ray, y per degree a second of sweep: %s" % ", ".join(rows), ok)
	var water := {&"cytostome": 2, &"ocellus": 3, &"palp": 2}
	_check("a cell in the water, with no levels, pays by copies as it always did",
		is_equal_approx(GenomeNode.upkeep_of(water), 1.0 + 0.18 * 4.0))
	var burned := _genome()
	burned.express({&"cytostome": 1, &"ocellus": 1, &"crista": 1},
		[&"cytostome", &"ocellus", &"crista"])
	burned.earn(&"ocellus", Progression.xp_at(5, _beam_step()))
	burned.choose(&"ocellus", &"extend")
	_check("crista still discounts the whole bill, the level's part included",
		is_equal_approx(burned.upkeep(), 1.72 * Stats.at(&"burn", 1)))


# --- The shape (§4) ------------------------------------------------------------

func _shape() -> void:
	var same := true
	for at in range(1, 4):
		var shape := CellBody.beam_shape(at, &"")
		same = same and int(shape[0]) == Stats.at(&"beam_count", at) \
			and is_equal_approx(float(shape[1]), Stats.at(&"beam_fan_deg", at)) \
			and is_equal_approx(float(shape[3]), Stats.at(&"beam_range", at))
	_check("levels 1 to 3 are exactly the old three rungs", same)
	var extend := CellBody.beam_shape(8, &"extend")
	var sweep := CellBody.beam_shape(8, &"sweep")
	_check("level 8: extension is 8 rays across 50 either side, sweep 3 at %.1f deg/s"
		% float(sweep[2]), int(extend[0]) == 8 and is_equal_approx(float(extend[1]), 50.0)
		and float(extend[2]) == 0.0 and int(sweep[0]) == 3
		and is_equal_approx(float(sweep[2]), 5.0 * 100.0 / 3.0))
	_check("a path this build does not know is held at the fork",
		CellBody.beam_shape(8, &"warp") == CellBody.beam_shape(3, &""))
	_check("no fan grows past the ceiling",
		int(CellBody.beam_shape(500, &"extend")[0])
			== int(Catalogue.number(&"ocellus", &"rays_max")))


# --- The fan (§4.3) ------------------------------------------------------------

func _fan() -> void:
	var fixed := RayFan.new()
	fixed.configure(3, deg_to_rad(50.0), 0.0)
	fixed.step(1.0 / 60.0)
	var o := fixed.offsets()
	_check("a fixed fan of three is -50, 0, +50",
		is_equal_approx(o[0], deg_to_rad(-50.0)) and is_equal_approx(o[1], 0.0)
		and is_equal_approx(o[2], deg_to_rad(50.0)) and fixed.revisit() == 0.0)
	# Frame-rate independence: over one full period, every ray's arcs, laid end
	# to end, cover its whole sector -- at 60 fps and at 20.
	var speed := deg_to_rad(7.0 * 100.0 / 3.0)
	for rate: float in [60.0, 20.0]:
		var fan := RayFan.new()
		fan.configure(3, deg_to_rad(50.0), speed)
		var period := fan.revisit()
		var low := [INF, INF, INF]
		var high := [-INF, -INF, -INF]
		var t := 0.0
		while t < period:
			fan.step(1.0 / rate)
			t += 1.0 / rate
			for i in 3:
				low[i] = minf(low[i], fan.arc_low()[i])
				high[i] = maxf(high[i], fan.arc_high()[i])
		var width := deg_to_rad(100.0 / 3.0)
		var covered := true
		for i in 3:
			var centre := deg_to_rad(-50.0) + width * (float(i) + 0.5)
			covered = covered and absf(low[i] - (centre - width * 0.5)) < 1e-4 \
				and absf(high[i] - (centre + width * 0.5)) < 1e-4
		_check("at %d fps a sweeping ray crosses its whole sector in one revisit (%.2f s)"
			% [int(rate), period], covered)
	var jump := RayFan.new()
	jump.configure(3, deg_to_rad(50.0), deg_to_rad(4000.0))
	jump.step(0.5)
	var whole := true
	for i in 3:
		whole = whole and is_equal_approx(jump.arc_high()[i] - jump.arc_low()[i],
			deg_to_rad(100.0 / 3.0))
	_check("a step longer than a period covers the whole sector", whole)


func _tally_and_glow() -> void:
	var tally := Tally.new(3)
	for id: int in [4, 4, 4, 9, 9]:
		tally.touch(id)
	var early := tally.step(0.5)
	var two := tally.step(0.5)
	for id: int in [1, 2, 3, 5, 6]:
		tally.touch(id)
	var capped := tally.step(1.0)
	_check("different bodies a second, capped: %d, %d, %d" % [early, two, capped],
		early == 0 and two == 2 and capped == 3)
	var glow := Afterglow.new()
	glow.add(Vector2(10, 0))
	glow.step(0.5, 1.0, Vector2.ZERO)
	var half := glow.strength(0, 1.0)
	glow.step(0.6, 1.0, Vector2.ZERO)
	var gone := glow.count()
	glow.add(Vector2(10, 0))
	glow.step(0.0, 1.0, Vector2(1000, 0))
	_check("a mark fades over its life, then goes, and a jump clears the rest",
		is_equal_approx(half, 0.5) and gone == 0 and glow.count() == 0)
	# One mark per `spacing` of a lane's travel, so the trail is the sweep's and
	# not the frame rate's: the same arc crossed in 60 steps and in 30 leaves
	# the same number of marks.
	var counts := []
	for steps: int in [60, 30]:
		var trail := Afterglow.new()
		trail.spacing = deg_to_rad(2.0)
		for i in steps + 1:
			var along := deg_to_rad(30.0) * float(i) / float(steps)
			trail.add(Vector2(float(i), 0.0), 0, along)
		counts.append(trail.count())
	# 15 or 16, depending on which side of the last 2-degree line 30 degrees
	# lands in floating point; what matters is that the two rates agree.
	_check("a ray crossing 30 degrees leaves the same marks at 60 steps and 30: %s"
		% str(counts), counts[0] == counts[1] and counts[0] >= 15)


# --- The field (§4.3, §4.4) ----------------------------------------------------

func _field() -> void:
	seed(20260928)
	var genome := _genome()
	genome.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"])
	var cell: Node = CellBody.new()
	cell.genome = genome
	cell.radius = 30.0
	_nodes.append(cell)
	var field: Node = FoodField.new()
	_nodes.append(field)
	field.setup(cell)
	field.beam_range = 1240.0
	# The skip is only allowed to be faster: against the same water and the same
	# rays, every answer is the same with it as without it.
	var agree := true
	var tried := 0
	for trial in 200:
		cell.heading = randf_range(-PI, PI)
		var mid := randf_range(-PI, PI)
		var half := deg_to_rad(float([0.0, 22.0, 50.0][trial % 3]))
		var rays := PackedFloat32Array()
		var count: int = [1, 2, 3, 8, 20][trial % 5]
		for i in count:
			var u := 0.0 if count < 2 else -1.0 + 2.0 * float(i) / float(count - 1)
			rays.append(wrapf(mid + u * half, -PI, PI))
		field.beam_bearings = rays
		field.beam_arcs = PackedFloat32Array()
		field.beam_fan_half = -1.0
		field.call("_step_beams")
		var without: Array = (field.beams as Array).duplicate(true)
		field.beam_fan_mid = mid
		field.beam_fan_half = half
		field.call("_step_beams")
		agree = agree and var_to_bytes(without) == var_to_bytes(field.beams)
		for beam: Array in without:
			if bool(beam[2]):
				tried += 1
	_check("skipping bodies outside the fan changes no answer, over 200 fans (%d hits)"
		% tried, agree and tried > 0)
	# A sweep's arc finds a body that lies inside it, between where the ray was
	# and where it is now, which a single ray at either end misses.
	var bodies: Array = field.get("_cells")
	var target: Object = bodies[0]
	cell.heading = 0.0
	target.pos = cell.position + cell.forward() * 300.0
	target.radius = 10.0
	for i in range(1, bodies.size()):
		(bodies[i] as Object).pos = cell.position - cell.forward() * 5000.0
	var off := deg_to_rad(12.0)
	field.beam_fan_half = -1.0
	field.beam_bearings = PackedFloat32Array([off])
	field.beam_arcs = PackedFloat32Array()
	field.call("_step_beams")
	var alone: bool = bool(field.beams[0][2])
	field.beam_arcs = PackedFloat32Array([-off, off])
	field.call("_step_beams")
	var swept: bool = bool(field.beams[0][2]) and int(field.beams[0][3]) == 0
	_check("a sweep finds what lies inside the arc it crossed (a ray alone: %s)"
		% alone, swept and not alone
		and (field.beam_touched as PackedInt32Array).has(0))


# --- What moving costs (docs/design/energy.md) ----------------------------------

func _energy() -> void:
	# The table energy.md §2 gives the gene descriptions: each organ as a
	# multiple of a resting body. Move a cost and this moves with it, and so must
	# the table.
	var gap := (Stats.at(&"impulse_gap_min", 1) + Stats.at(&"impulse_gap_max", 1)) * 0.5
	var beating := Stats.at(&"impulse_speed", 1) * CellBody.IMPULSE_MEAN \
		* CellBody.STROKE_COST / gap
	var turning := Stats.at(&"turn_rate", 1) * CellBody.TURN_COST
	var pushing := Stats.at(&"push_accel", 1) * CellBody.STROKE_COST
	_check("at tier 1 the flagellum's own beating costs %.2f of rest, turning flat"
		% beating + " out %.2f and pushing %.2f -- energy.md's 0.50, 0.81, 0.68"
		% [turning, pushing], absf(beating - 0.50) < 0.005
		and absf(turning - 0.81) < 0.005 and absf(pushing - 0.68) < 0.005)

	# The owner's number (energy.md §7): a born cell that never eats, steering a
	# third of the time, dies at thirty seconds. Being alive, its tail's own
	# beating and a third of a flat-out turn, then the grace; seeds 1 to 3
	# measure 30.2 to 30.3 s. Move HUNGER_SECONDS, STARVE_GRACE or a cost and
	# this says so. **Through the tank's own arithmetic** (ocean.md §14.3): the
	# static functions the node and the drop's water both call -- and then the
	# node itself, a frame at a time, dying at the same moment.
	var moving := beating + turning / 3.0
	var per_second := Metabolism.rest_rate(GenomeNode.upkeep_of(Catalogue.born()), 0.0,
		1.0) / Metabolism.HUNGER_SECONDS + Metabolism.effort_cost(moving, 1.0, 1.0)
	var steering := per_second * Metabolism.HUNGER_SECONDS
	var dies_at := 1.0 / per_second + Metabolism.STARVE_GRACE
	var dying: Node = Metabolism.new()
	_nodes.append(dying)
	dying.upkeep = GenomeNode.upkeep_of(Catalogue.born())
	var frames := 0
	while not dying.starved() and frames < 3600:
		dying.spend(moving / 60.0)
		dying.call(&"_process", 1.0 / 60.0)
		frames += 1
	_check("a born cell that never eats and steers a third of the time dies at %.1f s"
		% dies_at + " (burning %.2f of rest) -- the owner's thirty; the node, a frame"
		% steering + " at a time, at %.2f s" % (float(frames) / 60.0),
		absf(dies_at - 30.0) < 1.0 and absf(float(frames) / 60.0 - dies_at) < 2.0 / 60.0)

	# The tank: seconds of rest in, a share of the bar out, and the grace is time.
	var met: Node = Metabolism.new()
	met.set_process(false)
	_nodes.append(met)
	var half_tank := 0.5 * Metabolism.HUNGER_SECONDS
	met.reset()
	met.spend(half_tank)
	var plain: float = met.hunger
	met.reset()
	met.reserve = Stats.at(&"store", 3)
	met.spend(half_tank)
	var stored: float = met.hunger
	met.reset()
	met.burn = Stats.at(&"burn", 3)
	met.spend(half_tank)
	var burned: float = met.hunger
	_check("half a tank of rest spent is half the bar (%.3f), a quarter with store 3"
		% plain + " (%.3f) and 0.66 of a half with burn 3 (%.3f)" % [stored, burned],
		is_equal_approx(plain, 0.5) and is_equal_approx(stored, 0.25)
		and is_equal_approx(burned, 0.5 * Stats.at(&"burn", 3)))
	met.reset()
	met.set_hunger(1.0)
	met.starve_seconds = 12.0
	met.spend(60.0)
	var full_ok: bool = is_equal_approx(met.hunger, 1.0) \
		and is_equal_approx(met.starve_seconds, 12.0)
	met.reset()
	met.spend(0.0)
	met.spend(-30.0)
	_check("spending at full hunger leaves the grace alone, and nothing spent is"
		+ " nothing", full_ok and met.hunger == 0.0)

	# The body: a stroke pays on the speed it adds, a push on the speed it adds
	# each frame, a turn on the angle it turns -- and the water's wander is free.
	var cell: Node = CellBody.new()
	_nodes.append(cell)
	var g := _genome()
	g.express({&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"axoneme": 1},
		[&"cytostome", &"cirrus", &"flagellum", &"axoneme"])
	cell.set("genome", g)
	cell.call("_fire_impulse")
	var stroke: float = cell.call("take_effort")
	var again: float = cell.call("take_effort")
	var speed := Stats.at(&"impulse_speed", 1) * CellBody.STROKE_COST
	_check("one tier-1 stroke costs %.2f s of rest, within %.2f..%.2f for its strength,"
		% [stroke, 0.7 * speed, speed] + " and is paid once",
		stroke >= 0.7 * speed - 1e-6 and stroke <= speed + 1e-6 and again == 0.0)
	cell.set("_impulse_timer", 1000.0)
	cell.set("_omega", Stats.at(&"turn_rate", 1))
	cell.call("_process", 0.1)
	var omega: float = cell.get("_omega")
	var turn: float = cell.call("take_effort")
	cell.set("_omega", 0.0)
	cell.set("_wander", CellBody.WANDER_RATE)
	cell.call("_process", 0.1)
	var wander: float = cell.call("take_effort")
	_check("a turn is paid on the angle the cirrus turned (%.4f for %.4f rad) and the"
		% [turn, absf(omega) * 0.1] + " water's wander costs nothing (%.4f)" % wander,
		is_equal_approx(turn, absf(omega) * 0.1 * CellBody.TURN_COST) and wander == 0.0)
	Input.action_press(&"ui_up")
	cell.call("_process", 0.1)
	Input.action_release(&"ui_up")
	var push: float = cell.call("take_effort")
	var push_want := Stats.at(&"push_accel", 1) * 0.1 * CellBody.STROKE_COST
	cell.set("_effort", 3.0)
	cell.call("reset")
	var after_reset: float = cell.call("take_effort")
	_check("a held push pays on the speed it adds (%.4f, want %.4f), and a new body"
		% [push, push_want] + " owes nothing (%.4f)" % after_reset,
		is_equal_approx(push, push_want) and after_reset == 0.0)


# --- Hunger is an alarm (docs/design/hunger.md §2.1, §7) ------------------------

func _alarm() -> void:
	var met: Node = Metabolism.new()
	met.set_process(false)
	_nodes.append(met)
	# Fed, half a tank, empty, and the end of the grace.
	var periods: Array[float] = []
	var strengths: Array[float] = []
	for hunger: float in [0.0, 0.5, 1.0]:
		met.reset()
		met.set_hunger(hunger)
		periods.append(met.beat_period())
		strengths.append(met.beat_amplitude())
	met.starve_seconds = Metabolism.STARVE_GRACE
	var last: float = met.beat_period()
	strengths.append(met.beat_amplitude())
	_check("the beat comes every %.2f s fed, %.2f s at half a tank and %.2f s empty"
		% [periods[0], periods[1], periods[2]] + " -- 2.4, 2.4 and 1.2",
		is_equal_approx(periods[0], 2.4) and is_equal_approx(periods[1], 2.4)
		and is_equal_approx(periods[2], 1.2))
	_check("and every %.2f s as the grace runs out -- 0.75" % last,
		is_equal_approx(last, 0.75))
	_check("every beat lands at full strength, fed or dying: %s" % [strengths],
		strengths.all(func(a: float) -> bool: return is_equal_approx(a, 1.0)))

	# **Never slower and never dimmer as the danger rises**, which is the whole of
	# §0: a warning that gets quieter as death comes reads as nothing at all.
	var never_slower := true
	var before := INF
	for step in 101:
		met.reset()
		met.set_hunger(float(step) / 100.0)
		never_slower = never_slower and met.beat_period() <= before + 1e-6
		before = met.beat_period()
	for step in 101:
		met.starve_seconds = Metabolism.STARVE_GRACE * float(step) / 100.0
		never_slower = never_slower and met.beat_period() <= before + 1e-6
		before = met.beat_period()
	_check("from fed to the end of the grace the beat never once slows", never_slower)

	met.reset()
	met.set_hunger(0.5)
	var calm: float = met.hungry()
	met.set_hunger(1.0)
	var warned: float = met.hungry()
	_check("the body's warning is %.2f at half a tank and %.2f empty -- 0 and 1"
		% [calm, warned], calm == 0.0 and warned == 1.0)

	met.reset()
	met.set_hunger(0.99)
	var fed_faint: float = met.faint()
	met.set_hunger(1.0)
	var onset: float = met.faint()
	met.starve_seconds = Metabolism.STARVE_GRACE
	var gone: float = met.faint()
	_check("the membrane has fallen %.2f with 1%% of the tank left, %.2f the moment"
		% [fed_faint, onset] + " it is empty and %.2f at the end -- 0, 0.35 and 1"
		% gone, fed_faint == 0.0 and is_equal_approx(onset, 0.35)
		and is_equal_approx(gone, 1.0))

	# No beat faster than the floor even under dread's full jitter, and the floor
	# itself under three flashes a second.
	var fastest := Metabolism.LAST_PERIOD * (1.0 - SignalBus.DREAD_JITTER)
	_check("the fastest beat dread can make of the last one is %.2f s, at or above"
		% fastest + " the bus's floor of %.2f s, and that is under 3 a second"
		% SignalBus.BEAT_PERIOD_MIN,
		fastest >= SignalBus.BEAT_PERIOD_MIN - 1e-6
		and SignalBus.BEAT_PERIOD_MIN >= 1.0 / 3.0)


# --- A gene's numbers (docs/design/gene-stats.md) -------------------------------

func _gene_stats() -> void:
	# §4, one rule per unit -- and the two traps that made it a rule: Godot 4.7's
	# String.num keeps a whole number's ".0", and "%.1f" % 1.45 prints 1.4.
	var cases := [
		[619.6, Readout.Unit.DISTANCE, "620"], [56.5, Readout.Unit.SPEED, "57"],
		[5.0671, Readout.Unit.TIME, "5.07"], [1.45, Readout.Unit.TIME, "1.45"],
		[3.0, Readout.Unit.TIME, "3"], [15.2, Readout.Unit.TIME, "15.2"],
		[26.0, Readout.Unit.TIME, "26"], [1.3255, Readout.Unit.ENERGY, "1.3"],
		[2.0, Readout.Unit.ENERGY, "2"], [29.52, Readout.Unit.ENERGY, "30"],
		[36.0, Readout.Unit.ENERGY, "36"], [0.5, Readout.Unit.RATE, "0.50"],
		[1.3, Readout.Unit.TIMES, "1.30"], [0.07, Readout.Unit.SHARE, "7%"],
		[26.0, Readout.Unit.ANGLE, "26°"], [3.0, Readout.Unit.COUNT, "3"],
		[-0.2, Readout.Unit.COUNT, "0"],
	]
	var wrong := PackedStringArray()
	for want: Array in cases:
		var got := Readout.format(float(want[0]), int(want[1]))
		if got != String(want[2]):
			wrong.append("%s gave %s, not %s" % [want[0], got, want[2]])
	_check("the formatter writes all %d cases by §4's rule%s" % [cases.size(),
		"" if wrong.is_empty() else ": " + ", ".join(wrong)], wrong.is_empty())
	var line := Readout.runs([
		Readout.item("out to {} µm", [620.0], [Readout.Unit.DISTANCE]),
		Readout.item("bites take {} less", [0.12], [Readout.Unit.SHARE]),
		Readout.item("free to wear")])
	_check("a line is words and brighter numbers, each unit in the words and ` · `"
		+ " between items: %s" % str(line), line == [["out to ", false], ["620", true],
		[" µm · bites take ", false], ["12", true], ["% less · free to wear", false]])

	# A few rows of §5's table, read off the constants: move one and its row
	# moves, and so must the table.
	var born := GeneStats.context({})
	var rows := PackedStringArray()
	for gene: StringName in [&"flagellum", &"cirrus", &"ampulla", &"vacuole"]:
		for copies in range(1, 4):
			var said: Array = GeneStats.lines(gene, copies, 0, &"", born)
			rows.append(Readout.plain(said[0]) + " / " + Readout.plain(said[1]))
	_check("flagellum beats burn 0.50, 0.70 and 0.99 s a second, as energy.md §2 says",
		rows[0] == "swims about 57 µm a second · a beat every 1.7–3.6 s / beating burns"
			+ " 0.50 s a second, 1.3 s a beat · free to wear"
		and rows[1].ends_with("/ beating burns 0.70 s a second, 1.6 s a beat · wearing it"
			+ " burns 0.18 s a second")
		and rows[2].ends_with("/ beating burns 0.99 s a second, 1.8 s a beat · wearing it"
			+ " burns 0.36 s a second"))
	_check("a half turn costs 4.1 s at every cirrus, done in 5.07, 3.93 and 3.08 s: %s"
		% rows[3], rows[3].begins_with("a half turn in 5.07 s") and rows[4].begins_with(
		"a half turn in 3.93 s") and rows[5].begins_with("a half turn in 3.08 s")
		and rows[3].contains(", 4.1 s a half turn") and rows[4].contains(", 4.1 s a half turn")
		and rows[5].contains(", 4.1 s a half turn"))
	_check("a ping reaches 1100, 1500 and 1900 µm",
		rows[6].contains("out to 1100 µm") and rows[7].contains("out to 1500 µm")
		and rows[8].contains("out to 1900 µm"))
	_check("a vacuole's tank holds 46, 58 and 72 s: %s" % rows[9],
		rows[9].begins_with("a full tank holds 46 s, not 36") and rows[10].begins_with(
		"a full tank holds 58 s, not 36") and rows[11].begins_with(
		"a full tank holds 72 s, not 36"))
	var eye := _genome()
	eye.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"])
	var grown: Progression = eye.progression(&"ocellus")
	var next := Readout.plain([GeneStats.progress_item(grown.level(), grown.to_next())])
	var beam: Array = GeneStats.lines(&"ocellus", 1, grown.effective_level(), grown.path, born)
	_check("a fresh beam reads `%s` and `%s`" % [Readout.plain(beam[0]), next],
		next == "level 2 after 40 strikes"
		and Readout.plain(beam[0]) == "1 ray · reaches 620 µm")
	# **A gene with no row draws nothing** (gene-catalogue.md §8.4): every live gene
	# has its lines, which the gene probe holds, so it is a retired one whose organ's
	# file has no lines -- retiring is its tag alone (§16), and a gene retired later
	# keeps its lines -- and a key this build does not know that must draw nothing.
	var silent_keys: Array[StringName] = [&"probeunknown"]
	for key: StringName in Catalogue.tagged(Catalogue.RETIRED):
		var organ := Catalogue.gene(key)
		if organ != null \
				and not (organ.get_script() as GDScript).source_code.contains("func lines("):
			silent_keys.append(key)
	var silent := true
	for key: StringName in silent_keys:
		silent = silent and GeneStats.lines(key, 2, 0, &"", born) == [[], []]
	_check("a gene with no row draws nothing -- %s -- as a gene with no line says nothing"
		% str(silent_keys), silent)
	var clause := Readout.plain(GeneStats.cell_items(CellBody.BASE_RADIUS,
		Catalogue.born(), GenomeNode.upkeep_of(Catalogue.born())))
	_check("a newborn's caption says `%s` -- energy.md §7.2 measured 24.0 s to empty"
		% clause, clause == "52 µm across · a full tank: 36 s, 24 s drifting")

	# **The dash is paid as its row says** (§11, call 2), by the run's own
	# handler: seconds of rest through `spend`, so a newborn pays the share it
	# always paid, `crista` pays less, and a bigger tank pays the same seconds
	# out of more. The run is built and never enters the tree. (The venom's
	# spend went with the spitting: a toxin is doses now, dna-slots.md §7.)
	var run: Node = load("res://game/normal/normal_mode.gd").new()
	_nodes.append(run)
	var met: Node = Metabolism.new()
	met.set_process(false)
	_nodes.append(met)
	var field: Node = FoodField.new()
	_nodes.append(field)
	var bus: Node = load("res://game/perception/signal_bus.gd").new()
	_nodes.append(bus)
	run.set("_metabolism", met)
	run.set("_food", field)
	run.set("_bus", bus)
	var dash := Stats.at(&"dash_cost", 1)
	var burn := Stats.at(&"burn", 2)
	var tank := Stats.at(&"store", 3)
	var newborn_dash := _paid(run, met, 0, 0, dash)
	_check("a newborn's dash takes %.3f of the bar, exactly the share it always took"
		% newborn_dash[0], is_equal_approx(newborn_dash[0], dash))
	var burned_dash := _paid(run, met, 2, 0, dash)
	_check("with crista 2 it costs %.2f of it: %.2f s" % [burn, burned_dash[1]],
		is_equal_approx(burned_dash[1], dash * Metabolism.HUNGER_SECONDS * burn))
	var stored_dash := _paid(run, met, 0, 3, dash)
	_check("with vacuole 3 it costs the same seconds (%.2f s), a smaller share"
		% stored_dash[1] + " of a tank %.0f times as big" % tank,
		is_equal_approx(stored_dash[1], dash * Metabolism.HUNGER_SECONDS)
		and is_equal_approx(stored_dash[0], dash / tank))
	var s04 := GeneStats.context({&"crista": 2, &"vacuole": 3})
	var said_dash: float = GeneStats.lines(&"myoneme", 1, 0, &"", s04)[1][0]["values"][0]
	_check("and the numbers say what is paid: `each dash burns %s s`"
		% Readout.format(said_dash, Readout.Unit.ENERGY),
		is_equal_approx(said_dash, _paid(run, met, 2, 3, dash)[1]))
	_toxin_rows()
	var odds := PackedStringArray([GeneStats.odds_text(1), GeneStats.odds_text(2),
		GeneStats.odds_text(3)])
	_check("the odds gain their percentage: %s" % " | ".join(odds),
		odds[0] == "one copy · 55% of daughters wear it"
		and odds[1] == "two copies · 80% of daughters wear it"
		and odds[2] == "three copies · a daughter always wears it")


## **The toxin's rows** (docs/design/dna-slots.md §3.3), read off §15's
## constants: venom by where it works -- the front, a side, the stern -- and
## poison, each with what one stack does, diluted by the reader's own size.
func _toxin_rows() -> void:
	var born := GeneStats.context({})
	var front := Readout.plain(GeneStats.lines(&"toxicyst", 2, 0, &"", born, 3)[0])
	var side := Readout.plain(GeneStats.lines(&"toxicyst", 2, 0, &"", born, 5)[0])
	var stern := Readout.plain(GeneStats.lines(&"toxicyst", 1, 0, &"", born, 2)[0])
	var poison: Array = GeneStats.lines(&"veneneux", 3, 0, &"", born, GenomeNode.INSIDE)
	var big := Readout.plain(GeneStats.lines(&"toxicyst", 3, 0, &"",
		GeneStats.context({}, 40.0), 0)[0])
	_check("front venom reads `%s`" % front, front == "each bite leaves 2 stacks of venom"
		+ " · a stack takes 5% of a body your size over 9.66 s")
	_check("side venom reads `%s`" % side, side.begins_with(
		"whatever bites you on that side takes 2 stacks · a stack takes 5%"))
	_check("stern venom reads `%s`, one stack singular" % stern, stern.begins_with(
		"whatever bites you from behind takes 1 stack · a stack takes 5%"))
	_check("poison reads `%s / %s`" % [Readout.plain(poison[0]), Readout.plain(poison[1])],
		Readout.plain(poison[0]) == "whatever bites you takes 3 stacks a bite"
			+ " · a swallower takes 48 stacks"
		and Readout.plain(poison[1]).begins_with("a stack takes 5% of a body your size"))
	_check("a stack is diluted by the reader's size, (26 / 40)^2: `%s`" % big,
		big.contains("a stack takes 2% of a body your size"))


## One dash of [param cost] paid by the run's own handler out of a body with
## `crista` and `vacuole` at those copies. Returns what it took: `[share of the
## bar, seconds of rest out of that body's tank]`.
func _paid(run: Node, met: Node, crista: int, vacuole: int, cost: float) -> Array:
	met.reset()
	met.burn = Stats.at(&"burn", crista)
	met.reserve = Stats.at(&"store", vacuole)
	run.call("_on_dashed", cost)
	var share: float = met.hunger
	return [share, share * Metabolism.HUNGER_SECONDS * float(met.reserve)]


# --- A dose (docs/design/dna-slots.md §6.2, §20.3 check 4) ------------------------

## **A stack is worth what it says**, through the one dose step every body takes:
## cell.gd's `dosed`, which is the cell on this device's, and food.gd's
## `_dose_step` over it, which is every water body's and every person's.
##
## 1. **One stack of harm takes `HARM_PER_STACK x (26 / r)^2`** of a body at r26,
##    r34 and r40: a body at half a wound, given one stack and stepped at 60 a
##    second until it is gone, ends that much more wounded -- less only the one
##    frame's mending after the moment the harm ran out, far inside the cutoff's
##    worth of a stack, which is delivered with the rest.
## 2. **A body carrying harm does not mend**, frame after frame, and **mends from
##    the moment the harm is gone, within the step**: a step that carries a load
##    across the cutoff delivers all of it and mends for exactly the seconds left
##    after the crossing. A body carrying nothing mends as it always did.
## 3. **A drop body stepped every eighth frame and one stepped every frame end the
##    same** -- the drop steps its far bodies on a tick, with all the time they
##    are owed -- through `_dose_step`, from loads of one, four and a half and
##    twelve stacks, forty seconds of each, across the cutoff.
func _doses() -> void:
	var harm := Doses.Kind.HARM
	var frame := 1.0 / 60.0
	var tau: float = CellBody.DOSE_TAU_BY_KIND[harm]
	var worth := PackedStringArray()
	var exact := true
	for r: float in [26.0, 34.0, 40.0]:
		var loads := Doses.none()
		loads[harm] = 1.0
		var wound := 0.5
		var frames := 0
		while loads[harm] > 0.0 and frames < 60 * 600:
			wound = CellBody.dosed(loads, wound, r, frame)
			frames += 1
		var want := CellBody.HARM_PER_STACK * (CellBody.BASE_RADIUS / r) \
			* (CellBody.BASE_RADIUS / r)
		var took := wound - 0.5
		worth.append("r%.0f %.5f of %.5f in %.2f s" % [r, took, want, float(frames) / 60.0])
		exact = exact and took <= want + 1e-12 \
			and took >= want - frame / CellBody.MEND_SECONDS - 1e-12
	_check(("a stack of harm takes HARM_PER_STACK x (26 / r)^2 of a body, to within one"
		+ " frame's mending (%.5f; a cutoff's worth is %.4f): %s") % [frame
		/ CellBody.MEND_SECONDS, CellBody.HARM_PER_STACK * CellBody.DOSE_GONE,
		", ".join(worth)], exact and CellBody.DOSE_SIZE == CellBody.BASE_RADIUS)

	# 2. No mending while harm is in it; mending from the moment it is gone.
	var loads := Doses.none()
	loads[harm] = 0.3
	var wound := 0.5
	var fell := 0
	var steps := 0
	while loads[harm] > 0.0 and steps < 60 * 60:
		var was := wound
		wound = CellBody.dosed(loads, wound, 26.0, frame)
		steps += 1
		if loads[harm] > 0.0 and wound < was:
			fell += 1
	var after := wound
	var mended_after := CellBody.dosed(loads, after, 26.0, frame)
	var crossing := Doses.none()
	crossing[harm] = 0.3
	var once := CellBody.dosed(crossing, 0.5, 26.0, 3.0)
	var gone_at := tau * log(0.3 / CellBody.DOSE_GONE)
	var want_once := 0.5 + 0.3 * CellBody.HARM_PER_STACK - (3.0 - gone_at) / CellBody.MEND_SECONDS
	var clean := CellBody.dosed(Doses.none(), 0.5, 26.0, 3.0)
	_check(("a body carrying harm never mends (%d of %d frames fell) and mends the frame"
		+ " after it is gone (%.6f to %.6f); a step that carries 0.3 stacks across the"
		+ " cutoff at %.2f s delivers them all and mends the %.2f s after: %.6f, want"
		+ " %.6f; with nothing in it a body mends as it did (%.4f)") % [fell, steps, after,
		mended_after, gone_at, 3.0 - gone_at, once, want_once, clean],
		fell == 0 and steps > 1 and mended_after < after
		and is_equal_approx(mended_after, CellBody.mended(after, frame))
		and absf(once - want_once) < 1e-12 and crossing[harm] == 0.0
		and clean == CellBody.mended(0.5, 3.0))

	# 3. Every eighth frame against every frame, through the drop's own step.
	var field: Node = FoodField.new()
	_nodes.append(field)
	var same := true
	var said := PackedStringArray()
	for stacks: float in [1.0, 4.5, 12.0]:
		var every := FoodField.Body.new()
		var eighth := FoodField.Body.new()
		for b: Object in [every, eighth]:
			b.radius = 30.0
			b.wound = 0.2
			b.loads[harm] = stacks
		for f in 40 * 60:
			field.call(&"_dose_step", 0, every, frame)
			if f % 8 == 7:
				field.call(&"_dose_step", 1, eighth, 8.0 * frame)
		# The closed form: all the harm in, then mending from the moment it ran
		# out to the end, down to none.
		var gone := tau * log(stacks / CellBody.DOSE_GONE)
		var want := maxf(0.2 + stacks * CellBody.HARM_PER_STACK * (CellBody.BASE_RADIUS / 30.0)
			* (CellBody.BASE_RADIUS / 30.0) - (40.0 - gone) / CellBody.MEND_SECONDS, 0.0)
		said.append("%.1f stacks: %.9f and %.9f (%.9f)" % [stacks, float(every.wound),
			float(eighth.wound), want])
		same = same and absf(float(every.wound) - want) < 1e-12 \
			and absf(float(eighth.wound) - want) < 1e-12 \
			and every.loads == eighth.loads and not Doses.any(every.loads)
	_check("a drop body stepped every eighth frame ends where one stepped every frame"
		+ " does, forty seconds across the cutoff, both on the closed form to 1e-12: %s"
		% "; ".join(said), same)


## What going from level L to L + 1 costs the beam, over L: its own step.
static func _beam_step() -> float:
	return float(Catalogue.levels(&"ocellus")["step"])
