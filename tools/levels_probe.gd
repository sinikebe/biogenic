extends Node
## CI probe: **levels, the lineage, the price, and the fan** (docs/design/
## beam-levels.md). Everything here is arithmetic and bookkeeping that a render
## cannot show and a player would only find an hour into a run: a level that
## does not survive a division, a fork that can be taken twice, a sweep that a
## slow phone crosses with gaps in it, a skip that drops a body a ray would
## have hit.
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

const BORN_ORDER: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum"]

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
	mother.earn(&"ocellus", Progression.xp_at(5, CellBody.BEAM_XP_STEP))
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
	reborn.express(GenomeNode.BORN, BORN_ORDER)
	reborn.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"])
	_check("a death, or a forced genome, starts over at level 1",
		reborn.level_of(&"ocellus") == 1)

	# Written over in the DNA: kept while the body still wears it.
	var over := _genome()
	over.express({&"cytostome": 1, &"ocellus": 1}, [&"cytostome", &"ocellus"])
	over.earn(&"ocellus", Progression.xp_at(3, CellBody.BEAM_XP_STEP))
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
			one.earn(&"ocellus", Progression.xp_at(at, CellBody.BEAM_XP_STEP))
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
	burned.earn(&"ocellus", Progression.xp_at(5, CellBody.BEAM_XP_STEP))
	burned.choose(&"ocellus", &"extend")
	_check("crista still discounts the whole bill, the level's part included",
		is_equal_approx(burned.upkeep(), 1.72 * CellBody.BURN_BY_TIER[1]))


# --- The shape (§4) ------------------------------------------------------------

func _shape() -> void:
	var same := true
	for at in range(1, 4):
		var shape := CellBody.beam_shape(at, &"")
		same = same and int(shape[0]) == CellBody.BEAM_COUNT_BY_TIER[at] \
			and is_equal_approx(float(shape[1]), CellBody.BEAM_FAN_DEG_BY_TIER[at]) \
			and is_equal_approx(float(shape[3]), CellBody.BEAM_RANGE_BY_TIER[at])
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
		int(CellBody.beam_shape(500, &"extend")[0]) == CellBody.BEAM_RAYS_MAX)


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
