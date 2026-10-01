extends Node
## CI probe: **the drop** (docs/design/ocean.md §14.3). The mechanics a finite
## water is built on -- the grid, the basin, the replenisher, the snowfall --
## against brute force and against their own arithmetic; the drop's own
## decisions, each on its own; one tank for every body: the player's metabolism
## node against the water's own; and **the drop in the water** -- nothing made
## where it can be seen, nothing past the rim, growth that stops, the floors,
## one seed one drop, flocs, and one body for every cell -- over five minutes
## of a drop and on bodies posed in one. **And the dev app's frame readout**
## (§14.2), run for real: CI runs release-stamped, so nothing else here ever
## runs its frames. **And 13, the replay on the drop** (§11): the 48 nearest in
## slots they keep, today's water recorded as it always was, flocs as SETTLE and
## CLEAR, the killer, and a replay that leaves the drop untouched. **And 12, the
## save, as far as 1b-1 needs it** (§9): the bodies to the bit through the file,
## a real run left and opened again on the same drop and the same cell, an
## unknown format, and a changed `rules`. The room's census is 1b-2's. **And
## pack 2's, so far** (docs/design/lineage.md §11.3, 2-1): the lineage kept to
## the bit and a file without it loaded as founders, the sister a daughter in
## full, and the identity gate -- with nothing dividing, `dev`'s census lines.
##
## **Every check here fails with its fix taken out**, and was shown to by
## mutation when it was written: a grid that forgets the edge buckets stand for
## everything past them, a basin that puts a body back on the rim in 32 bits
## without pulling it inside, a replenisher whose debt outgrows its shortfall, a
## Poisson draw cut off at 64, a node that works out its own rate. And 1a-2's:
## a spawner that hides a peer at a drifter's reach, a body left past the rim, a
## growth with no ceiling, a drifter drawn from the venom list, a prey search
## that stops too far out, a floc eaten unsettled, a poisoned body that leaves
## nothing, a body armoured against the player only. And 1a-3's: a body that
## loses its slot while it stays near, newcomers out of the field's order, a
## floc never cleared, a seal that names no killer, a replay that writes onto
## the run's own field. And 1b-1's: a load that forgets a mouth's clock, a run
## that opens on the drop but not on the cell, a daughter pair not kept, an
## unknown format left where it was, a radius left past the cap, and the
## fingerprint's tables sorted as StringNames. And pack 2's first, 2-1's: a save
## that drops the DNA, a grace kept in 32 bits, a DNA kept out of its order, a
## 1b body or cell come back with no line, a column read without being checked,
## a cell's record not kept, a sister who is the daughter's child, carries only
## her body or, in a pond, nothing at all, a meal that writes only the DNA, and
## a sister who wears what she carries.
##
## Headless and deterministic: one seed, set first. Prints one line per check
## and `ALL PASS` only if every one held; CI asserts on that marker rather than
## on the exit code, because Godot exits 0 after a script error too.

const SpaceGrid := preload("res://game/mechanics/space_grid.gd")
const Basin := preload("res://game/mechanics/basin.gd")
const Replenish := preload("res://game/mechanics/replenish.gd")
const Snowfall := preload("res://game/mechanics/snowfall.gd")
const Drop := preload("res://game/normal/drop.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")
const CellBody := preload("res://game/normal/cell.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const FoodField := preload("res://game/normal/food.gd")
const FrameReadout := preload("res://game/dev/frame_readout.gd")
const MotesField := preload("res://game/normal/motes.gd")
const Cilia := preload("res://game/vision/cilia.gd")
const RecorderNode := preload("res://game/replay/recorder.gd")
const DropSave := preload("res://game/normal/drop_save.gd")
const Descent := preload("res://game/mechanics/descent.gd")

## Somewhere other than the origin, as the drop is once a run has started in it.
const OFF_CENTRE := Vector2(-1234.5, 2345.25)

var _failed := 0


## **A water that takes a known time**: at least [constant BUSY_USEC] of its own
## `_process` a frame, and three bodies of food.gd's own kind in it, one of them
## a retired slot.
class BusyWater extends Node:
	const BUSY_USEC := 300
	var held: Array = []

	func _init() -> void:
		for seeded: bool in [true, false, true, true]:
			var b := FoodField.Body.new()
			b.seeded = seeded
			held.append(b)

	func _process(_delta: float) -> void:
		var until := Time.get_ticks_usec() + BUSY_USEC
		while Time.get_ticks_usec() < until:
			pass

	func bodies() -> Array:
		return held


## **The drop, watched from inside**: food.gd's own field with a tally on every
## door a rule passes through -- what the spawner makes, how a body leaves, each
## swim, each run begun and each run given up, each count of the genes -- so a
## check reads what happened in every frame of a run and not only at its end.
## Each hook calls the field's own function; nothing about the drop changes.
class WatchedDrop extends "res://game/normal/food.gd":
	var made := 0
	var made_gape := 0.0
	var venom_drifters := 0
	var causes := {}
	var swims := 0
	var fast := 0
	var burst_without := 0
	var searches := 0
	var fast_search := 0
	var runs_begun := 0
	var blind_runs := 0
	var given_up := 0
	var fled := 0
	var counts := 0
	var lost_genes := 0
	var still_short := 0
	var _short_before: Array[StringName] = []
	## The slot the last body came in by: a sister, which nothing returns.
	var last_spawned := -1

	func _spawn(at: Vector2, drifter: bool, sensed: float, fill := false,
			body_radius := 0.0, tiers := {}, mine := -1.0) -> int:
		var index: int = super._spawn(at, drifter, sensed, fill, body_radius, tiers, mine)
		last_spawned = index
		var b: Body = _cells[index]
		if body_radius <= 0.0:
			made += 1
			if b.drifter:
				venom_drifters += 1 if b.genome.has(&"veneneux") else 0
			else:
				made_gape = maxf(made_gape, _gape(b))
		return index

	func _drop_lose(index: int, cause: int) -> void:
		var b: Body = _cells[index]
		if b.seeded and not b.inert:
			causes[cause] = int(causes.get(cause, 0)) + 1
		super._drop_lose(index, cause)

	func _swim(b: Body, delta: float, speed: float) -> void:
		swims += 1
		if speed > b.cruise + b.dash_v + 1e-3:
			fast += 1
		if b.dash_v > 0.0 and Genome.tier_of(b.genome, &"myoneme") <= 0:
			burst_without += 1
		super._swim(b, delta, speed)

	func _drift_in_drop(index: int, b: Body, delta: float) -> void:
		super._drift_in_drop(index, b, delta)
		if b.speed > DRIFT_SPEED + 1e-3:
			searches += 1
			if b.speed > b.cruise + 1e-3:
				fast_search += 1

	## A run begins: at something its own senses find, by the tables and not by
	## the field's own function -- the whole reach of its nose, radar, beam and
	## palp, a floc by nose, beam or palp alone, its eyespot's for a body big
	## enough to cast a shadow, and touch.
	func _start_run(b: Body, target: int, serial: int) -> void:
		runs_begun += 1
		var at: Vector2 = _cell.position if target == TARGET_PLAYER else _cells[target].pos
		var size: float = _cell.radius if target == TARGET_PLAYER else _cells[target].radius
		var floc: bool = target != TARGET_PLAYER and _cells[target].inert
		var g := b.genome
		var smell: float = CellBody.SMELL_RANGE_BY_TIER[Genome.tier_of(g, &"chemocyte")]
		var ping: float = CellBody.PING_RANGE_BY_TIER[Genome.tier_of(g, &"ampulla")]
		var beam: float = CellBody.BEAM_RANGE_BY_TIER[Genome.tier_of(g, &"ocellus")]
		var touch: float = CellBody.TOUCH_RANGE_BY_TIER[Genome.tier_of(g, &"palp")]
		var eye := SHADOW_RANGE if Genome.tier_of(g, &"stigma") > 0 else 0.0
		var d := b.pos.distance_to(at)
		var found := d <= b.radius + size
		if floc:
			found = found or d <= maxf(smell, maxf(beam, touch))
		else:
			found = found or d <= maxf(maxf(smell, ping), maxf(beam, touch)) \
				or (d <= eye and size >= SHADOW_MIN_RATIO * b.radius)
		if not found:
			blind_runs += 1
		super._start_run(b, target, serial)

	func _break_off(b: Body) -> void:
		super._break_off(b)
		given_up += 1
		if b.state == State.BREAK or b.calm != REST_MISS:
			fled += 1

	func _count_genes() -> void:
		super._count_genes()
		counts += 1
		var carriers := {}
		for b in _cells:
			if b.seeded and not b.inert:
				for gene: StringName in b.genome:
					carriers[gene] = int(carriers.get(gene, 0)) + 1
		for gene: StringName in DRIFTER_GENES:
			var n := int(carriers.get(gene, 0))
			if n == 0:
				lost_genes += 1
			if n < Drop.GENE_FLOOR and _short_before.has(gene):
				still_short += 1
		_short_before = _gene_short.duplicate()


func _ready() -> void:
	seed(20260930)
	_grid()
	_basin()
	_replenish()
	_snowfall()
	_drop()
	_lod()
	_tank()
	_spawns()
	_containment()
	_five_minutes()
	_determinism()
	_identity()
	_flocs()
	await _flocs_fed()
	_one_body()
	await _replay()
	await _readout()
	await _save()
	await _sister_lineage()
	print("[drop-probe] ALL PASS" if _failed == 0
		else "[drop-probe] FAILED %d" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("[drop-probe] %s %s" % ["PASS" if ok else "FAIL", what])


# --- 1. The grid never misses ---------------------------------------------------

func _grid() -> void:
	var half := Drop.RADIUS + Drop.GRID_CELL
	var grid := SpaceGrid.new(OFF_CENTRE, half, Drop.GRID_CELL)
	# Ids three apart, so the grid grows past its first room; about one body in
	# ten filed off the square, where the edge buckets have to stand for it.
	var count := 700
	var span := 3 * count
	var at := PackedVector2Array()
	at.resize(span)
	var filed := PackedByteArray()
	filed.resize(span)
	for k in count:
		var id := 3 * k
		at[id] = _anywhere(OFF_CENTRE, half * 1.15)
		filed[id] = 1
		grid.insert(id, at[id])
	var seen := PackedInt32Array()
	seen.resize(span)
	var out := PackedInt32Array()
	var truths := 0
	var missed := 0
	var twice := 0
	var ghosts := 0
	var answered := 0
	var queries := 10000
	var broke := -1
	var touched := PackedInt32Array()
	for q in queries:
		# The water moves between two questions: most bodies a frame's travel,
		# some a leap across the drop, a few out of it and back in.
		touched.resize(0)
		for m in 3:
			var id := 3 * (randi() % count)
			touched.append(grid.bucket_of(at[id]))
			if filed[id] == 0:
				grid.insert(id, at[id])
				filed[id] = 1
				continue
			var roll := randf()
			if roll < 0.04:
				grid.remove(id)
				filed[id] = 0
				continue
			var leap := randf_range(0.0, 15.0) if roll < 0.8 else randf_range(0.0, 3000.0)
			at[id] += Vector2.from_angle(randf() * TAU) * leap
			grid.move(id, at[id])
			touched.append(grid.bucket_of(at[id]))
		# A list that came apart would send the query round it for ever: stop
		# here and say so instead.
		if not _lists_sound(grid, touched, count):
			broke = q
			break
		var here := _anywhere(OFF_CENTRE, half * 1.2)
		# Every reach a pass asks: separation's few tens, a prey search's two
		# thousand and the players' scan list past it.
		var reach := randf_range(0.0, 60.0) if q % 4 == 0 else randf_range(0.0, 2400.0)
		out.resize(0)
		grid.query(here, reach, out)
		answered += out.size()
		var stamp := q + 1
		for id: int in out:
			if seen[id] == stamp:
				twice += 1
			seen[id] = stamp
			if filed[id] == 0:
				ghosts += 1
		for k in count:
			var id := 3 * k
			if filed[id] == 1 and at[id].distance_squared_to(here) <= reach * reach:
				truths += 1
				if seen[id] != stamp:
					missed += 1
	var every := PackedInt32Array()
	for c in grid.columns * grid.rows:
		every.append(c)
	var sound := broke < 0 and _lists_sound(grid, every, count)
	var asked := queries if broke < 0 else broke
	_check(("the grid never misses: %d queries against brute force%s, %d bodies within"
		+ " reach, %d missed; nothing twice (%d) and nothing taken out (%d); %.1f"
		+ " answered for each one in reach; every body in the one bucket it is filed in:"
		+ " %s") % [asked, "" if broke < 0 else " before its lists came apart", truths,
		missed, twice, ghosts, float(answered) / maxf(float(truths), 1.0),
		"yes" if sound else "no"],
		missed == 0 and twice == 0 and ghosts == 0 and truths > 5 * queries and sound)
	_grid_lines()


## **Whether the lists of [param buckets] hold together**: every id in one is
## filed in that bucket, and no list runs on past [param most] ids -- which a
## list that has come round on itself would. Reaches into the grid's own
## arrays, as only tools/ may.
func _lists_sound(grid: SpaceGrid, buckets: PackedInt32Array, most: int) -> bool:
	var head: PackedInt32Array = grid.get(&"_head")
	var next: PackedInt32Array = grid.get(&"_next")
	var where: PackedInt32Array = grid.get(&"_where")
	for c: int in buckets:
		var i := head[c]
		var steps := 0
		while i >= 0:
			steps += 1
			if steps > most or i >= where.size() or where[i] != c:
				return false
			i = next[i]
	return true


## **At a bucket line, a caller whose 32-bit distance rounds the other way.**
## A body a hair to one side of a line, asked for from exactly its rounded
## distance on the other: the caller keeps it, so the grid has to hand it back.
func _grid_lines() -> void:
	var grid := SpaceGrid.new(Vector2.ZERO, 8000.0, 400.0)
	var line := 1200.0
	var reach := 4096.0
	var below := PackedFloat32Array([line - 1e-4])[0]
	var beyond := PackedFloat32Array([line - reach - 2.44140625e-4])[0]
	# [body, asked from]: from the right of a body just below a line, from the
	# left of one on it, and the same down the page.
	var cases := [
		[Vector2(below, 37.0), Vector2(line + reach, 37.0)],
		[Vector2(line, 37.0), Vector2(beyond, 37.0)],
		[Vector2(37.0, below), Vector2(37.0, line + reach)],
		[Vector2(37.0, line), Vector2(37.0, beyond)],
	]
	var kept := 0
	var missed := 0
	var out := PackedInt32Array()
	for i in cases.size():
		var body: Vector2 = cases[i][0]
		var from: Vector2 = cases[i][1]
		grid.insert(i, body)
		if body.distance_squared_to(from) > reach * reach:
			continue
		kept += 1
		out.resize(0)
		grid.query(from, reach, out)
		if not out.has(i):
			missed += 1
		grid.remove(i)
	_check("and at a bucket line: %d bodies a caller's 32-bit test keeps across one," % kept
		+ " %d missed" % missed, kept == cases.size() and missed == 0)


# --- 2. The basin ------------------------------------------------------------------

func _basin() -> void:
	var basin := Basin.new(OFF_CENTRE, Drop.RADIUS)
	var trials := 1500
	var worst_contain := 0.0
	var worst_depth := 0.0
	var worst_rim := 0.0
	var worst_exit := 0.0
	var outside := 0
	var wrong_inside := 0
	var contained := 0
	var escaped := 0
	for t in trials:
		var p := _anywhere(OFF_CENTRE, Drop.RADIUS * 1.5)
		var r := randf_range(0.0, 60.0) if t % 50 != 0 \
			else randf_range(Drop.RADIUS, 1.5 * Drop.RADIUS)
		var d := _dist(p, OFF_CENTRE)
		var limit := maxf(Drop.RADIUS - r, 0.0)
		# contain: the nearest point of the disc a body of this radius may be in.
		var want := p if d <= limit else _on_circle(OFF_CENTRE, limit,
			_nearest_angle(OFF_CENTRE, limit, p))
		var got := basin.contain(p, r)
		worst_contain = maxf(worst_contain, _dist(got, want))
		if d > limit:
			outside += 1
		contained += 1
		if not basin.inside(got, r):
			escaped += 1
		# inside, against the distance itself.
		if basin.inside(p, r) != (d <= limit):
			wrong_inside += 1
		# depth and the nearest point of the rim, against the rim sampled. The
		# distance stays in 64 bits; only the point is stored in 32.
		var angle := _nearest_angle(OFF_CENTRE, Drop.RADIUS, p)
		var from_rim := _dist_to(OFF_CENTRE.x + Drop.RADIUS * cos(angle),
			OFF_CENTRE.y + Drop.RADIUS * sin(angle), p) * (1.0 if d <= Drop.RADIUS else -1.0)
		worst_depth = maxf(worst_depth, absf(basin.depth(p) - from_rim))
		worst_rim = maxf(worst_rim, _dist(basin.nearest_rim(p),
			_on_circle(OFF_CENTRE, Drop.RADIUS, angle)))
		# exit_along, against a ray walked out and bisected.
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(0.1, 50.0)
		worst_exit = maxf(worst_exit, absf(basin.exit_along(p, dir) - _walk_out(OFF_CENTRE,
			Drop.RADIUS, p, dir)))
	_check(("the basin against brute force over %d points (%d past the rim): contain"
		+ " within %.4f, depth %.6f, nearest_rim %.4f, exit_along %.4f; inside wrong %d")
		% [trials, outside, worst_contain, worst_depth, worst_rim, worst_exit, wrong_inside],
		worst_contain < 0.01 and worst_depth < 1e-6 and worst_rim < 0.01
		and worst_exit < 1e-3 and wrong_inside == 0 and outside > 300)
	_check("a contained point is inside: %d of %d, rounded to 32 bits" % [
		contained - escaped, contained], escaped == 0)
	# The rim itself: at the centre, and along a ray from the rim outward.
	var from_middle := basin.nearest_rim(OFF_CENTRE)
	var at_rim := basin.nearest_rim(OFF_CENTRE + Vector2(3.0, 4.0))
	_check("the centre's nearest rim is on the rim (%.4f off), and a ray leaving from"
		% absf(_dist(from_middle, OFF_CENTRE) - Drop.RADIUS)
		+ " the rim outward travels %.4f" % basin.exit_along(at_rim, at_rim - OFF_CENTRE),
		absf(_dist(from_middle, OFF_CENTRE) - Drop.RADIUS) < 0.01
		and basin.exit_along(at_rim, at_rim - OFF_CENTRE) < 0.01)


## The angle of the point of the circle of [param radius] round [param c]
## nearest [param p], found the slow way: the circle sampled, then the best
## sample's neighbourhood narrowed down. Nothing here shares the basin's
## arithmetic.
func _nearest_angle(c: Vector2, radius: float, p: Vector2) -> float:
	var samples := 720
	var best := 0.0
	var best_d := INF
	for k in samples:
		var a := TAU * float(k) / float(samples)
		var d := _dist_to(c.x + radius * cos(a), c.y + radius * sin(a), p)
		if d < best_d:
			best_d = d
			best = a
	var low := best - TAU / float(samples)
	var high := best + TAU / float(samples)
	for i in 80:
		var a := lerpf(low, high, 1.0 / 3.0)
		var b := lerpf(low, high, 2.0 / 3.0)
		if _dist_to(c.x + radius * cos(a), c.y + radius * sin(a), p) \
				<= _dist_to(c.x + radius * cos(b), c.y + radius * sin(b), p):
			high = b
		else:
			low = a
	return (low + high) * 0.5


func _on_circle(c: Vector2, radius: float, angle: float) -> Vector2:
	return Vector2(c.x + radius * cos(angle), c.y + radius * sin(angle))


## How far a ray from [param origin] along [param dir] runs before it leaves the
## disc, walked: out in steps, then bisected to the crossing. 0 when the walk
## never finds the disc ahead of it.
func _walk_out(c: Vector2, radius: float, origin: Vector2, dir: Vector2) -> float:
	var length := sqrt(dir.x * dir.x + dir.y * dir.y)
	var ux := dir.x / length
	var uy := dir.y / length
	var reach := _dist(origin, c) + radius + 10.0
	var step := 4.0
	var last_in := -1.0
	var t := 0.0
	while t <= reach:
		if _dist_to(origin.x + ux * t, origin.y + uy * t, c) <= radius:
			last_in = t
		t += step
	if last_in < 0.0:
		return 0.0
	var low := last_in
	var high := last_in + step
	for i in 60:
		var mid := (low + high) * 0.5
		if _dist_to(origin.x + ux * mid, origin.y + uy * mid, c) <= radius:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


# --- The replenisher, in isolation ------------------------------------------------

func _replenish() -> void:
	var target := Drop.target()
	var spawner := Replenish.new(target, Drop.SPAWN_TAU, Drop.SPAWN_BURST)
	# One tick: a shortfall of 20 over half a second is two bodies; one of 7 is
	# 0.7 of a body, owed and not made; a drop that is full again owes nothing.
	var one := spawner.due(target - 20, Drop.SPAWN_TICK)
	var partial := spawner.due(target - 7, Drop.SPAWN_TICK)
	var owed := spawner.debt
	var full := spawner.due(target, Drop.SPAWN_TICK)
	var over := spawner.due(target + 30, Drop.SPAWN_TICK)
	_check("a shortfall of 20 pays back 2 a half second (%d); one of 7 makes %d and owes"
		% [one, partial] + " %.2f; a full drop and an over-full one make nothing (%d, %d)"
		% [owed, full, over] + " and owe nothing (%.2f)" % spawner.debt,
		one == 2 and partial == 0 and is_equal_approx(owed, 0.7) and full == 0
		and over == 0 and spawner.debt == 0.0)
	# The burst, and a debt that cannot outgrow what is missing.
	spawner.reset()
	var most := 0
	var living := 0
	for tick in 60:
		var made := spawner.due(living, Drop.SPAWN_TICK)
		most = maxi(most, made)
		living += made
	var stuck := Replenish.new(target, Drop.SPAWN_TAU, 0)
	for tick in 200:
		stuck.due(target - 12, Drop.SPAWN_TICK)
	stuck.refund(3)
	_check(("from empty, never more than %d a tick (%d); nowhere to put anything, the"
		+ " debt stops at the 12 missing (%.2f) and a refund is owed again (%.2f)") % [
		Drop.SPAWN_BURST, most, stuck.debt - 3.0, stuck.debt],
		most == Drop.SPAWN_BURST and is_equal_approx(stuck.debt, 15.0))
	# Refilling: a shortfall of 40 with nothing dying comes back along
	# 1 - (1 - tick / tau)^n, the half-second ticks of 1 - exp(-t / tau).
	spawner.reset()
	living = target - 40
	for tick in 10:
		living += spawner.due(living, Drop.SPAWN_TICK)
	var back := float(living - (target - 40))
	var curve := 40.0 * (1.0 - pow(1.0 - Drop.SPAWN_TICK / Drop.SPAWN_TAU, 10.0))
	_check("40 short and nothing dying, %d are back after one tau of %.0f s (%.1f by the curve)"
		% [roundi(back), Drop.SPAWN_TAU, curve], absf(back - curve) <= 1.0)
	# §6.2: a drop losing k bodies a second settles about k * tau short -- 95 %
	# of its target at a newborn's composition, 91 % at a sighted player's.
	var held := PackedFloat32Array()
	for per_minute: float in [355.0, 635.0]:
		spawner.reset()
		living = target
		var dying := 0.0
		var sum := 0.0
		var ticks := 0
		for tick in 2400:
			dying += per_minute / 60.0 * Drop.SPAWN_TICK
			var died := floori(dying)
			dying -= float(died)
			living -= died
			living += spawner.due(living, Drop.SPAWN_TICK)
			if tick >= 800:
				sum += float(living)
				ticks += 1
		held.append(sum / float(ticks) / float(target))
	_check("losing 355 and 635 a minute, the drop holds %.1f %% and %.1f %% of its %d"
		% [held[0] * 100.0, held[1] * 100.0, target] + " -- §6.2's 95 and 91",
		roundi(held[0] * 100.0) == 95 and roundi(held[1] * 100.0) == 91)
	# The thinnest candidate, against brute force: fewest wins, the first of a tie.
	var wrong := 0
	for trial in 500:
		var candidates := PackedVector2Array()
		var counts := {}
		for k in randi() % 13:
			var p := Vector2(float(trial), float(k))
			candidates.append(p)
			counts[p] = randi() % 6
		var want := -1
		for k in candidates.size():
			if want < 0 or int(counts[candidates[k]]) < int(counts[candidates[want]]):
				want = k
		if Replenish.thinnest(candidates, func(p: Vector2) -> int: return counts[p]) != want:
			wrong += 1
	_check("the thinnest of up to 12 candidates, 500 times against brute force: %d wrong"
		% wrong, wrong == 0)
	# Hidden from every observer, against brute force, and at the reach itself.
	wrong = 0
	for trial in 3000:
		var observers := PackedVector2Array()
		var reaches := PackedFloat32Array()
		for k in randi() % 4:
			observers.append(_anywhere(Vector2.ZERO, 3000.0))
			reaches.append(randf_range(0.0, 2000.0))
		var p := _anywhere(Vector2.ZERO, 3000.0)
		var want := true
		for k in observers.size():
			if _dist(p, observers[k]) < reaches[k]:
				want = false
		if Replenish.hidden(p, observers, reaches) != want:
			wrong += 1
	var edge := Replenish.hidden(Vector2(1000.0, 0.0), PackedVector2Array([Vector2.ZERO]),
		PackedFloat32Array([1000.0]))
	var within := Replenish.hidden(Vector2(999.9, 0.0), PackedVector2Array([Vector2.ZERO]),
		PackedFloat32Array([1000.0]))
	_check("hidden from up to 3 observers, 3000 times against brute force: %d wrong;" % wrong
		+ " at the reach hidden (%s), a tenth inside it not (%s)" % [edge, within],
		wrong == 0 and edge and not within
		and Replenish.hidden(Vector2.ZERO, PackedVector2Array(), PackedFloat32Array()))


# --- The snowfall, in isolation --------------------------------------------------

func _snowfall() -> void:
	var snow := Snowfall.new(Drop.SNOW * 1e-6, Drop.SNOW_SHARE)
	var area := PI * Drop.RADIUS * Drop.RADIUS
	var mean := snow.rate * area * Drop.SPAWN_TICK
	var draws := 20000
	var sum := 0.0
	var squares := 0.0
	for i in draws:
		var n := float(snow.falls(area, Drop.SPAWN_TICK))
		sum += n
		squares += n * n
	var got := sum / float(draws)
	var spread := squares / float(draws) - got * got
	_check(("the drop's snow: %.2f flakes a second over the drop, %.3f a half second by"
		+ " %d draws against %.3f, variance %.3f -- a Poisson draw's own") % [
		snow.rate * area, got, draws, mean, spread],
		absf(snow.rate * area - 8.14) < 0.01 and absf(got - mean) < 0.015 * mean
		and absf(spread - mean) < 0.05 * mean)
	# A large mean is not cut short: the prototype's draw stopped at 64.
	sum = 0.0
	for i in 5000:
		sum += float(Snowfall.poisson(100.0))
	_check("a mean of 100 draws %.2f on average -- nothing cut short" % (sum / 5000.0),
		absf(sum / 5000.0 - 100.0) < 1.0 and Snowfall.poisson(0.0) == 0)
	# The keep chance: all of it where nothing is, none at half the share.
	var expected := Drop.snow_expected()
	var chances := PackedFloat32Array([snow.keep_chance(0.0, expected),
		snow.keep_chance(expected * Drop.SNOW_SHARE * 0.5, expected),
		snow.keep_chance(expected * Drop.SNOW_SHARE, expected),
		snow.keep_chance(3.0 * expected, expected), snow.keep_chance(0.0, 0.0),
		snow.keep_chance(1.0, 0.0)])
	_check("a flake is kept %.2f where nothing is, %.2f at a quarter, %.2f at half the"
		% [chances[0], chances[1], chances[2]] + " drop's %.1f cells, %.2f above; with no mean"
		% [expected, chances[3]] + " %.0f and %.0f" % [chances[4], chances[5]],
		absf(expected - 9.85) < 0.01 and chances[0] == 1.0 and is_equal_approx(chances[1], 0.5)
		and chances[2] == 0.0 and chances[3] == 0.0 and chances[4] == 1.0 and chances[5] == 0.0)
	var kept := 0
	var count := 0.7 * expected * Drop.SNOW_SHARE
	for i in draws:
		if snow.keeps(count, expected):
			kept += 1
	_check("where the chance is 0.30, %d of %d flakes stay" % [kept, draws],
		absf(float(kept) / float(draws) - 0.3) < 0.015)


# --- The drop's own decisions ------------------------------------------------------

func _drop() -> void:
	var drop := Drop.new(OFF_CENTRE)
	_check("the drop holds %d bodies at %.1f per million square micrometres, Ø %.0f mm"
		% [Drop.target(), Drop.DENSITY * 1e6, 2.0 * Drop.RADIUS / 1000.0],
		Drop.target() == 554 and drop.spawner.target == 554
		and drop.meniscus.center == OFF_CENTRE and drop.meniscus.radius == Drop.RADIUS)
	# The hide reach (§6.3), for a born cell with each free sense.
	var reaches := PackedFloat32Array()
	for sense: StringName in FoodField.SENSE_GENES:
		var tiers := {sense: 1}
		var senses := maxf(maxf(CellBody.SMELL_RANGE_BY_TIER[GenomeNode.tier_of(tiers,
			&"chemocyte")], CellBody.PING_RANGE_BY_TIER[GenomeNode.tier_of(tiers,
			&"ampulla")]), CellBody.BEAM_RANGE_BY_TIER[GenomeNode.tier_of(tiers, &"ocellus")])
		reaches.append(Drop.hide_reach(senses, FoodField.DREAD_RANGE, false))
	var peer := Drop.hide_reach(CellBody.PING_RANGE_BY_TIER[1], FoodField.DREAD_RANGE, true)
	var low := reaches[0]
	var high := reaches[0]
	for reach in reaches:
		low = minf(low, reach)
		high = maxf(high, reach)
	_check("for a born cell a drifter is made %.0f to %.0f away, by its sense, and a peer"
		% [low, high] + " %.0f -- §6.3's 1,050 to 1,200 and 1,500" % peer,
		absf(low - 1049.0) < 0.5 and high == 1200.0 and peer == 1500.0)
	# What is short.
	var genes := FoodField.DRIFTER_GENES.duplicate()
	var counts := {}
	for gene: StringName in genes:
		counts[gene] = 5
	counts[&"palp"] = 1
	counts[Drop.VENOM] = 0
	counts[&"crista"] = 2
	var short := Drop.short_genes(counts, genes)
	var first := Drop.take_drifter_gene(short)
	var second := Drop.take_drifter_gene(short)
	_check(("the floor finds %s short of %d; a drifter takes palp (%s), never venom (%s),"
		+ " which is left for a peer (%s)") % [str(Drop.short_genes(counts, genes)),
		Drop.GENE_FLOOR, first, second, str(short)],
		first == &"palp" and second == &"" and short == [Drop.VENOM])
	var shares := [Drop.wants_drifter(100, 44, 0.45), Drop.wants_drifter(100, 45, 0.45),
		Drop.wants_drifter(0, 0, 0.92)]
	_check("a drifter is made while the living share is under the one wanted: %s" % str(shares),
		shares == [true, false, true])
	var turns := [Drop.next_turn(0, 1), Drop.next_turn(0, 2), Drop.next_turn(1, 2),
		Drop.next_turn(2, 3), Drop.next_turn(0, 0)]
	_check("new bodies are made for the players in turn: %s" % str(turns),
		turns == [0, 1, 0, 0, 0])
	# What a new body is made of (§5.8).
	var pool := Drop.drifter_genes(FoodField.DRIFTER_GENES)
	_check("a drifter draws its gene from %d of the %d, all but venom" % [pool.size(),
		FoodField.DRIFTER_GENES.size()], not pool.has(Drop.VENOM)
		and pool.size() == FoodField.DRIFTER_GENES.size() - 1)
	var plan := Drop.peer_plan()
	var blind := {&"cytostome": 2, &"cirrus": 1, &"flagellum": 3}
	var given := Drop.give_sense(blind, FoodField.SENSE_GENES, 7)
	var sighted := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"stigma": 2}
	var again := Drop.give_sense(sighted, FoodField.SENSE_GENES, 7)
	_check("a peer starts from a born cell's plan %s; a blind one is given %s at tier 1," % [
		str(plan), str(blind.keys().slice(3))] + " a sighted one nothing",
		plan == [&"cytostome", &"cirrus", &"flagellum"] and given and not again
		and blind.size() == 4 and int(blind[FoodField.SENSE_GENES[3]]) == 1
		and sighted.size() == 4)
	var full := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"ampulla": 1, &"crista": 2}
	Drop.give_venom(full, 5, FoodField.SENSE_GENES, 3)
	var bare := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"chemocyte": 1}
	Drop.give_venom(bare, 3, FoodField.SENSE_GENES, 3)
	_check("venom back through a full peer takes a spare slot, never the plan or a sense"
		+ " (%s); with none spare, a bonus one (%s)" % [str(full.keys()), str(bare.keys())],
		full.has(Drop.VENOM) and not full.has(&"crista") and full.has(&"ampulla")
		and full.size() == 5 and bare.size() == 5 and bare.has(Drop.VENOM))
	# Where a new body may go: out of every player's reach, and in the drop.
	var players := PackedVector2Array([OFF_CENTRE + Vector2(1500.0, -800.0),
		OFF_CENTRE + Vector2(-4500.0, 3000.0)])
	var hides := PackedFloat32Array([1500.0, 1200.0])
	var drawn := 0
	var ringed := 0
	var bad := 0
	for round in 400:
		var turn := round % 2
		for at: Vector2 in drop.spawn_candidates(players, hides, turn):
			drawn += 1
			if not drop.meniscus.inside(at, Drop.SPAWN_INSET) \
					or not Replenish.hidden(at, players, hides):
				bad += 1
			var d := _dist(at, players[turn])
			if d >= hides[turn] and d <= hides[turn] + Drop.SPAWN_RING:
				ringed += 1
	_check(("spawn candidates: %d drawn, %d of them in the ring past the player whose"
		+ " turn it is, %d inside a hide reach or past the rim") % [drawn, ringed, bad],
		bad == 0 and drawn > 3000 and float(ringed) > 0.35 * float(drawn))
	# Where a run starts, against the same points chosen by hand.
	var tried: Array = []
	var food_near := func(p: Vector2, reach: float) -> int:
		if reach == Drop.START_CLEAR:
			tried.append(p)
			return 1 if fmod(absf(p.x), 7.0) < 1.0 else 0
		return int(absf(p.y)) % 5
	var dread_at := func(p: Vector2) -> float:
		return 0.0 if fmod(absf(p.y), 3.0) < 1.5 else absf(p.x) / 6000.0
	var start := drop.quiet_start(food_near, dread_at)
	var want := drop.meniscus.center
	var least := INF
	var most := -1
	var deep := true
	var clear := 0
	for p: Vector2 in tried:
		deep = deep and drop.meniscus.inside(p, Drop.START_INSET)
		if fmod(absf(p.x), 7.0) < 1.0:
			continue
		clear += 1
		var dread: float = dread_at.call(p)
		var food := int(absf(p.y)) % 5
		if dread < least - 1e-6 or (absf(dread - least) <= 1e-6 and food > most):
			want = p
			least = dread
			most = food
	var tied := 0
	for p: Vector2 in tried:
		if fmod(absf(p.x), 7.0) >= 1.0 and absf(float(dread_at.call(p)) - least) <= 1e-6:
			tied += 1
	_check(("a run starts at the quietest of %d points: of the %d with no meal on top, the"
		+ " %d that dread nothing tie and the one with most food (%d) wins; none within"
		+ " %.0f of the rim") % [tried.size(), clear, tied, most, Drop.START_INSET],
		tried.size() == Drop.START_TRIES and start == want and deep and clear < tried.size()
		and tied >= 2)
	var pushed := drop.pushed_clear(OFF_CENTRE, OFF_CENTRE + Vector2(300.0, 400.0),
		FoodField.DREAD_RANGE, 30.0)
	_check("a mouth that could swallow a newborn is moved out to %.0f from its start"
		% _dist(pushed, OFF_CENTRE), absf(_dist(pushed, OFF_CENTRE)
		- FoodField.DREAD_RANGE - Drop.START_PUSH) < 0.01)
	# A start is drawn evenly over its disc: half of the draws within the radius
	# that holds half its area. And one 1,100 µm in from the rim, with the mouth
	# on the rim's side, pushes that mouth back inside, not out of the drop.
	var disc := Drop.RADIUS - Drop.START_INSET
	var within := 0
	var outside := 0
	for i in 20000:
		var d := _dist(drop.uniform_point(Drop.START_INSET), drop.meniscus.center)
		if d <= disc / sqrt(2.0):
			within += 1
		if d > disc + 1e-3:
			outside += 1
	var edge_start := drop.meniscus.center + Vector2(Drop.RADIUS - 1100.0, 0.0)
	var edge_push := drop.pushed_clear(edge_start, edge_start + Vector2(300.0, 0.0),
		FoodField.DREAD_RANGE, 30.0)
	_check(("a start is drawn evenly: %.3f of 20,000 within %.0f of the centre, which holds"
		+ " half the disc, and %d past it; a mouth on the rim's side of a start 1,100 in"
		+ " is pushed to %.1f inside the rim") % [float(within) / 20000.0,
		disc / sqrt(2.0), outside, drop.meniscus.depth(edge_push)],
		absf(float(within) / 20000.0 - 0.5) <= 0.01 and outside == 0
		and drop.meniscus.inside(edge_push, 30.0))
	# **The review's S3**: the rim holds a pushed mouth back, and it must still
	# end clear of dread's reach of the start. From a start as near the rim as
	# one may be, mouths all round it at every distance inside dread's reach, of
	# every size a body can be: each is slid along the rim until it clears.
	var nearest := INF
	var held := 0
	var escaped := 0
	var worst_start := drop.meniscus.center + Vector2(0.0, -(Drop.RADIUS - Drop.START_INSET))
	for k in 72:
		for reach: float in [60.0, 700.0, 1350.0]:
			for r: float in [13.0, 40.0]:
				var mouth := worst_start + Vector2.from_angle(TAU * float(k) / 72.0) * reach
				var put := drop.pushed_clear(worst_start, mouth, FoodField.DREAD_RANGE, r)
				nearest = minf(nearest, _dist(put, worst_start))
				if drop.meniscus.depth(put) < Drop.START_PUSH:
					held += 1
				if not drop.meniscus.inside(put, r):
					escaped += 1
	_check(("S3: from a start %.0f inside the rim, 432 mouths moved out land at least %.0f"
		+ " from it (dread reaches %.0f), %d of them slid along the rim, %d past it") % [
		Drop.START_INSET, nearest, FoodField.DREAD_RANGE, held, escaped],
		nearest >= FoodField.DREAD_RANGE and held > 0 and escaped == 0)
	# What a new thing is made with: a body made in play is fed, one of a first
	# fill up to FIRST_HUNGER_MAX; a fallen floc fits a born cell's mouth and lasts
	# FLOC_LIFE give or take its spread.
	var fed := [Drop.made_hunger(false), Drop.made_hunger(false)]
	var made := Vector2(INF, -INF)
	var flocs := Vector2(INF, -INF)
	var lives := Vector2(INF, -INF)
	for i in 2000:
		var h := Drop.made_hunger(true)
		made = Vector2(minf(made.x, h), maxf(made.y, h))
		var fr := Drop.floc_radius()
		flocs = Vector2(minf(flocs.x, fr), maxf(flocs.y, fr))
		var fl := Drop.floc_life()
		lives = Vector2(minf(lives.x, fl), maxf(lives.y, fl))
	var gape := CellBody.gape_of(1, CellBody.BASE_RADIUS)
	_check(("a body made in play starts fed (%s), one of a first fill at %.2f to %.2f; a"
		+ " floc is %.1f to %.1f µm, inside a born cell's gape of %.1f, and lasts %.0f to"
		+ " %.0f s") % [str(fed), made.x, made.y, flocs.x, flocs.y, gape, lives.x, lives.y],
		fed == [0.0, 0.0] and made.x >= 0.0 and made.y <= Drop.FIRST_HUNGER_MAX
		and made.y > 0.3 and flocs.x >= Drop.FLOC_MIN and flocs.y <= Drop.FLOC_MAX
		and Drop.FLOC_MAX < gape and lives.x >= 90.0 and lives.y <= 150.0
		and lives.x < 95.0 and lives.y > 145.0)
	# The shore, the remains, and the drop moving under a start.
	var turn_rates := PackedFloat32Array([Drop.shore_turn(0.0),
		Drop.shore_turn(Drop.SHALLOWS * 0.5), Drop.shore_turn(Drop.SHALLOWS),
		Drop.shore_turn(3000.0)])
	var remains := PackedFloat32Array([Drop.remains_radius(13.0), Drop.remains_radius(30.0),
		Drop.remains_radius(40.0)])
	drop.grid.insert(5, OFF_CENTRE)
	drop.shift(Vector2(100.0, -50.0))
	_check(("the shore turns a body %.2f, %.2f, %.2f and %.2f rad/s at the rim, half"
		+ " into the shallows, at their edge and beyond; remains of r13, r30, r40 are"
		+ " %.1f, %.1f, %.1f; a shifted drop moves its rim and forgets its grid") % [
		turn_rates[0], turn_rates[1], turn_rates[2], turn_rates[3], remains[0],
		remains[1], remains[2]],
		is_equal_approx(turn_rates[0], Drop.SHORE_TURN)
		and is_equal_approx(turn_rates[1], Drop.SHORE_TURN * 0.5)
		and turn_rates[2] == 0.0 and turn_rates[3] == 0.0
		and remains == PackedFloat32Array([8.0, 15.0, 18.0])
		and drop.meniscus.center == OFF_CENTRE + Vector2(100.0, -50.0)
		and not drop.grid.has(5))


# --- 7. The LOD reaches past the senses ----------------------------------------------

## **Nothing is stepped at a lower rate where it can be sensed** (§4.3), from
## the tables alone: `LOD_NEAR` past the farthest ping, the widest body and the
## grid's slack, and past every other reach; `LOD_FULL` past the view and the
## widest body; `LOD_EVERY` even. A sense that one day reaches further fails
## here instead of being slowed where it is felt.
func _lod() -> void:
	var widest := CellBody.DIVIDE_RADIUS
	var ping := 0.0
	for reach: float in CellBody.PING_RANGE_BY_TIER:
		ping = maxf(ping, reach)
	var beam := 0.0
	for level in range(1, 13):
		for path: StringName in [&"", &"extend", &"sweep"]:
			beam = maxf(beam, float(CellBody.beam_shape(level, path)[3]))
	var smell := 0.0
	for reach: float in CellBody.SMELL_RANGE_BY_TIER:
		smell = maxf(smell, reach)
	var touch := 0.0
	for reach: float in CellBody.TOUCH_RANGE_BY_TIER:
		touch = maxf(touch, reach)
	var others := {"scent": FoodField.SCENT_RANGE, "smell": smell,
		"dread": FoodField.DREAD_RANGE, "beam": beam, "touch": touch,
		"notice": FoodField.NOTICE_RANGE}
	var farthest := 0.0
	for key: String in others:
		farthest = maxf(farthest, float(others[key]))
	_check(("7. the LOD reaches past the senses: LOD_NEAR %.0f against a ping of %.0f, the"
		+ " widest body's %.0f and %.0f of slack, and the rest %s; LOD_FULL %.0f against"
		+ " the view's %.0f and that body; LOD_EVERY %d, even") % [Drop.LOD_NEAR, ping,
		widest, Drop.GRID_SLACK, str(others), Drop.LOD_FULL, Drop.VIEW_REACH,
		Drop.LOD_EVERY],
		Drop.LOD_NEAR >= ping + widest + Drop.GRID_SLACK
		and Drop.LOD_NEAR >= farthest + widest
		and Drop.LOD_FULL >= Drop.VIEW_REACH + widest and Drop.LOD_FULL < Drop.LOD_NEAR
		and Drop.LOD_EVERY % 2 == 0)


# --- 10. One tank ----------------------------------------------------------------------

## **A water body and the player's metabolism node, with the same genome, fed
## the same efforts over the same 60 s, end at the same hunger** -- the node a
## frame at a time as the run steps it, the water body in food.gd's own tank at
## the rates its distance would give it: every frame, then every second frame,
## then on its tick, with the time it is owed. The body's terms -- its upkeep,
## store, burn, and light and absorption -- are the field's own reading of its
## genome, so they are held to the node's too.
func _tank() -> void:
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var genomes := [
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1},
		{&"cytostome": 2, &"cirrus": 1, &"flagellum": 3, &"vacuole": 2, &"plastid": 3,
			&"crista": 2, &"ampulla": 1},
		# A player who put a gene over its own mouth absorbs, as `plastid` is
		# light: the caller's income (§5.3).
		{&"cirrus": 2, &"flagellum": 1, &"chemocyte": 1},
	]
	var worst := 0.0
	var low := 1.0
	var high := 0.0
	var frames := 3600
	var dt := 1.0 / 60.0
	var dash := CellBody.DASH_COST_BY_TIER[1] * Metabolism.HUNGER_SECONDS
	for tiers: Dictionary in genomes:
		var met: Node = Metabolism.new()
		met.upkeep = GenomeNode.upkeep_of(tiers)
		met.reserve = CellBody.STORE_BY_TIER[GenomeNode.tier_of(tiers, &"vacuole")]
		met.photosynthesis = CellBody.SUN_BY_TIER[GenomeNode.tier_of(tiers, &"plastid")] \
			+ (Metabolism.ABSORB if GenomeNode.tier_of(tiers, &"cytostome") == 0 else 0.0)
		met.burn = CellBody.BURN_BY_TIER[GenomeNode.tier_of(tiers, &"crista")]
		met.set_hunger(0.3)
		var index := _pose(field, Vector2(1500.0, 0.0), 30.0, tiers, 0.0, 0.3)
		var tank: Object = (field.get("_cells") as Array)[index]
		var last := -1
		for f in frames:
			# What the body did this frame, in seconds of rest: a stroke now and
			# then, steering a third of the time, and one dash.
			var effort := 0.0
			if randf() < 1.0 / 120.0:
				effort += randf_range(0.9, 1.3)
			if randf() < 1.0 / 3.0:
				effort += randf_range(0.0, 0.02)
			if f == 1500:
				effort += dash
			# The run pays the effort, then the node is alive for the frame, then
			# the water feeds it.
			met.spend(effort)
			met.call(&"_process", dt)
			tank.set("effort", float(tank.get("effort")) + effort)
			# A meal every ten seconds, worth three fifths of what is missing, so
			# neither tank is ever pinned at empty or at full: a pinned tank
			# would agree with anything.
			var meal := f > 0 and f % 600 == 0
			var every := 1 if f < 1200 else (2 if f < 2400 else Drop.LOD_EVERY)
			if f % every == every - 1 or meal or f == frames - 1:
				field._tank(index, tank, float(f - last) * dt)
				last = f
			if meal:
				var nutrition := 0.6 * float(met.hunger) / Metabolism.MEAL
				met.feed(nutrition)
				field._feed_water(tank, nutrition)
			low = minf(low, met.hunger)
			high = maxf(high, met.hunger)
		worst = maxf(worst, absf(float(met.hunger) - float(tank.get("hunger"))))
		met.free()
		field._drop_lose(index, 0)
	_done(water)
	_check(("one tank: 3 genomes, the node a frame at a time and the water body at its"
		+ " rates, 60 s of the same efforts and meals, end %s apart (hunger ran %.2f"
		+ " to %.2f, never pinned)") % [String.num_scientific(worst), low, high],
		worst < 1e-6 and low > 0.0 and high < 1.0)
	# A body with no mouth at rest: every drifter the water makes holds its tank,
	# neither burning it nor -- with light or a mitochondrion to spare -- filling it.
	var starving := PackedStringArray()
	for gene: StringName in Drop.drifter_genes(FoodField.DRIFTER_GENES):
		var tiers := {gene: 1}
		var rate := Metabolism.rest_rate(GenomeNode.upkeep_of(tiers),
			CellBody.SUN_BY_TIER[GenomeNode.tier_of(tiers, &"plastid")] + Metabolism.ABSORB,
			CellBody.STORE_BY_TIER[GenomeNode.tier_of(tiers, &"vacuole")])
		if rate != 0.0:
			starving.append(str(gene))
	# And §5.3's number: a born cell without its mouth, absorbing, steering a
	# third of the time, is empty at about 46 s.
	var gap := (CellBody.IMPULSE_GAP_MIN_BY_TIER[1] + CellBody.IMPULSE_GAP_MAX_BY_TIER[1]) * 0.5
	var beating := CellBody.IMPULSE_SPEED_BY_TIER[1] * CellBody.IMPULSE_MEAN \
		* CellBody.STROKE_COST / gap
	var turning := CellBody.TURN_RATE_BY_TIER[1] * CellBody.TURN_COST
	var mouthless := {&"cirrus": 1, &"flagellum": 1, &"chemocyte": 1}
	var per_second := Metabolism.rest_rate(GenomeNode.upkeep_of(mouthless), Metabolism.ABSORB,
		1.0) / Metabolism.HUNGER_SECONDS + Metabolism.effort_cost(beating + turning / 3.0, 1.0,
		1.0)
	_check(("a mouthless body at rest neither starves nor fills: %d of %d drifter genes burn"
		+ " or gain anything (%s); a born cell without its mouth is empty at %.1f s --"
		+ " §5.3's 46") % [
		starving.size(), Drop.drifter_genes(FoodField.DRIFTER_GENES).size(),
		", ".join(starving), 1.0 / per_second],
		starving.is_empty() and absf(1.0 / per_second - 46.0) < 1.0)
	# The tank's arithmetic at its edges: nothing spent costs nothing, a body
	# with no store is held to RESERVE_MIN's rather than emptied at once, and a
	# mouthless body absorbs exactly the upkeep of the one organ it needs to live.
	var none := [Metabolism.effort_cost(-1.0, 1.0, 1.0), Metabolism.effort_cost(0.0, 1.0, 1.0)]
	var storeless := [Metabolism.rest_rate(1.0, 0.0, 0.0),
		Metabolism.effort_cost(1.0, 1.0, 0.0) * Metabolism.HUNGER_SECONDS]
	var organ := GenomeNode.upkeep_of({&"cirrus": 1})
	_check(("a tank's edges: effort of -1 s and of 0 s costs %s; with no store at all a"
		+ " body burns %s -- 1 / %.2f -- rather than all of it at once; ABSORB %.3f is the"
		+ " upkeep of one cirrus, %.3f") % [str(none), str(storeless), Metabolism.RESERVE_MIN,
		Metabolism.ABSORB, organ],
		none == [0.0, 0.0] and Metabolism.RESERVE_MIN > 0.0
		and is_equal_approx(storeless[0], 1.0 / Metabolism.RESERVE_MIN)
		and is_equal_approx(storeless[1], 1.0 / Metabolism.RESERVE_MIN)
		and Metabolism.ABSORB == organ)


# --- The drop in the water (§14.3: checks 3 to 6, 8, 9 and 11) ----------------------------

## **A born ghost player and the drop made round it**, stepped by hand one fixed
## frame at a time: out of the water until a check puts it in, still, and with
## everything alive within [param desert] of it taken away, so bodies can be
## posed in the clear. [param sensed] makes the drop for a player that sighted.
func _water(desert := 0.0, sensed := -1.0) -> Array:
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	var field := WatchedDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.desert = desert
	field.sensed_override = sensed
	add_child(field)
	field.setup_drop(cell)
	field.in_water = false
	return [field, cell]


func _done(water: Array) -> void:
	(water[0] as Node).queue_free()
	(water[1] as Node).free()


## A body [param index] of [param field]'s, posed: at [param at], facing
## [param facing], its tank at [param hunger], resting as long as it is left.
func _pose(field: Node, at: Vector2, radius: float, tiers: Dictionary, facing := 0.0,
		hunger := 0.5) -> int:
	var index: int = field.pose_body(at, radius, tiers)
	var b: Object = (field.get("_cells") as Array)[index]
	b.set("heading", facing)
	b.set("hunger", hunger)
	b.set("calm", 999.0)
	return index


## The heading from [param from] that points at [param to].
func _facing(from: Vector2, to: Vector2) -> float:
	var v := to - from
	return atan2(v.x, -v.y)


## The settled flocs within a unit of [param at] in [param field].
func _flocs_at(field: Node, at: Vector2) -> Array:
	var out := []
	for b: Object in field.get("_cells"):
		if b.get("seeded") and b.get("inert") and _dist(b.get("pos"), at) < 1.0:
			out.append(b)
	return out


# --- 3. Nothing is made where it can be seen ---------------------------------------------

## **2,000 bodies made with one player and 2,000 with two, and none inside any
## player's hide reach for its kind** (§6.3) -- a drifter out of the view and the
## player's own senses, a peer out of dread's reach as well -- through the
## field's own door, for a player with a tier-1 radar. Each is taken away again,
## so the drop stays at its size. **And the first drifter**, held until the cell
## first moves and then put along that motion, is out of the view both times.
func _spawns() -> void:
	var water := _water()
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	field.ping_range = CellBody.PING_RANGE_BY_TIER[1]
	var hides := [Drop.hide_reach(field.ping_range, FoodField.DREAD_RANGE, false),
		Drop.hide_reach(field.ping_range, FoodField.DREAD_RANGE, true)]
	var cells: Array = field.get("_cells")
	var first: Object = cells[int(field.get("_first_index"))]
	var held_at := _dist(first.get("pos"), cell.position)
	var made := [0, 0]
	var kinds := [0, 0]
	var inside := 0
	var outside := 0
	var players := [PackedVector2Array([cell.position]),
		PackedVector2Array([cell.position, cell.position + Vector2(2600.0, 1800.0)])]
	for round in 2:
		var at: PackedVector2Array = players[round]
		var reaches := PackedFloat32Array()
		for p: Vector2 in at:
			reaches.append(field.ping_range)
		for k in 2000:
			# Made for a player who sees everything and for one who sees
			# nothing, in turn: the two drifter shares, 0.45 and 0.92.
			field.set("_made_for", PackedFloat64Array([cell.radius, 1.0 if k % 2 == 0
				else 0.0]))
			var index := field._make_one(at, reaches)
			if index < 0:
				continue
			made[round] += 1
			var b: Object = (field.get("_cells") as Array)[index]
			var peer := 0 if b.get("drifter") else 1
			kinds[peer] += 1
			for p: Vector2 in at:
				if _dist(b.get("pos"), p) < float(hides[peer]):
					inside += 1
			if not field.basin().inside(b.get("pos"), Drop.SPAWN_INSET):
				outside += 1
			field._drop_lose(index, 0)
	cell.velocity = Vector2(30.0, -40.0)
	field.in_water = true
	field._process(1.0 / 60.0)
	var placed_at := _dist(first.get("pos"), cell.position)
	_check(("3. nothing is made where it can be seen: %d and %d bodies made with one player"
		+ " and with two (%d drifters, %d peers), %d inside a player's hide reach (%.0f for"
		+ " a drifter, %.0f for a peer), %d past the rim; the first drifter %.0f away"
		+ " before the cell moves and %.0f after, out of the view's %.0f") % [made[0], made[1],
		kinds[0], kinds[1], inside, hides[0], hides[1], outside, held_at, placed_at,
		Drop.VIEW_REACH],
		made[0] >= 1990 and made[1] >= 1990 and kinds[0] > 500 and kinds[1] > 500
		and inside == 0 and outside == 0 and held_at >= Drop.VIEW_REACH
		and placed_at >= Drop.VIEW_REACH)
	_done(water)


# --- 4. Containment ------------------------------------------------------------------------

## **After 1,800 frames no body's centre past `RADIUS - r`, the player's
## included; no mote past the rim** (§3.1). A run started 120 inside the rim,
## facing it, the cell pressing straight into it at a stroke's speed the whole
## time -- knocked at the rim's bearing, and at most once in SHORE_GAP -- with its
## grit, the authored first mote included, round it. Bodies are looked at every
## half second, the cell and the grit every frame.
func _containment() -> void:
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	var field := WatchedDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.start_mode = &"edge"
	field.edge_gap = 120.0
	field.grace = 1e6
	field.contact_swallow = false
	add_child(field)
	field.setup_drop(cell)
	field.in_water = true
	var motes := MotesField.new()
	motes.setup(cell, field.basin())
	var rim: RefCounted = field.basin()
	var centre: Vector2 = rim.get(&"center")
	var edge: float = rim.get(&"radius")
	var knocks: Array = []
	field.shored.connect(func(bearing: float, _strength: float, _at: Vector2) -> void:
		knocks.append([float(field.get("_t")), bearing]))
	# And water bodies that only their own step holds: hungry hunters spread
	# along the rim away from the cell, a few units inside where they are held,
	# none touching another or able to eat one, with no sense to find food by --
	# so they swim straight out to look for it, past the rim in a frame, if
	# their step did not hold them.
	var out0 := (cell.position - centre).normalized()
	for k in 24:
		var along := out0.rotated(deg_to_rad((5.0 + 2.5 * float(k / 2)) * (1.0 if k % 2 == 0
			else -1.0)))
		var hungry := _pose(field, centre + along * (edge - 33.0), 30.0,
			{&"cytostome": 1, &"cirrus": 1, &"flagellum": 2}, atan2(along.x, -along.y), 0.9)
		var hb: Object = (field.get("_cells") as Array)[hungry]
		hb.set("calm", 0.0)
		hb.set("searching", true)
	var worst_body := INF
	var worst_cell := INF
	var worst_mote := INF
	var bodies_seen := 0
	for f in 1800:
		var out := (cell.position - centre).normalized()
		cell.heading = atan2(out.x, -out.y)
		cell.velocity = out * 120.0
		cell.position += cell.velocity / 60.0
		field._process(1.0 / 60.0)
		motes._process(1.0 / 60.0)
		worst_cell = minf(worst_cell, edge - cell.radius - _dist(cell.position, centre))
		for p: Vector2 in motes.points():
			worst_mote = minf(worst_mote, edge - MotesField.MOTE_RADIUS - _dist(p, centre))
		if f % 30 == 29:
			for b: Object in field.get("_cells"):
				if b.get("seeded"):
					bodies_seen += 1
					worst_body = minf(worst_body,
						edge - float(b.get("radius")) - _dist(b.get("pos"), centre))
	var gap := INF
	var off_bearing := 0.0
	for k in knocks.size():
		off_bearing = maxf(off_bearing, absf(float(knocks[k][1])))
		if k > 0:
			gap = minf(gap, float(knocks[k][0]) - float(knocks[k - 1][0]))
	_check(("4. containment: 1,800 frames of a cell pressing into the rim; of %d looks at"
		+ " a body the nearest to the rim was %.3f inside where it is held, the cell %.3f"
		+ " and its grit %.3f; knocked %d times, at most %.1f deg off dead ahead, at"
		+ " least %.2f s apart (SHORE_GAP %.1f)") % [bodies_seen, worst_body, worst_cell,
		worst_mote, knocks.size(), rad_to_deg(off_bearing), gap, Drop.SHORE_GAP],
		worst_body >= -1e-3 and worst_cell >= -1e-3 and worst_mote >= -1e-3
		and knocks.size() >= 20 and gap >= Drop.SHORE_GAP - 1e-6
		and off_bearing < deg_to_rad(1.0) and bodies_seen > 30000)
	motes.free()
	field.queue_free()
	cell.free()


# --- 5, 6 and 11: five minutes of a drop ----------------------------------------------------

## **Five minutes of a drop made for a fully sighted player** (§14.3), with a
## still ghost player in it, watched from inside:
##
## - 5, growth: no body over DIVIDE_RADIUS, and none *made* with a mouth wider
##   than ARRIVAL_GAPE_MAX -- a grown one may have it (row 5);
## - 6, the floors: every drifter gene carried at every count, and a gene found
##   short back at GENE_FLOOR by the next; a living drifter within the floor's
##   reach of the still player every second; no drifter made with venom;
## - 11, one body: every body that left the drop living left by one of the four
##   causes and nothing else, and every body made is living or left; no swim
##   faster than its own tail and its dash, no burst without a `myoneme`, a
##   search at its own speed; no run begun at what its own senses cannot find,
##   and no miss that ended in a flight.
func _five_minutes() -> void:
	var water := _water(0.0, 1.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var biggest := 0.0
	var at_forty := 0
	var floor_checks := 0
	var floor_missed := 0
	for f in 5 * 60 * 60:
		field._process(1.0 / 60.0)
		if f % 60 != 59:
			continue
		floor_checks += 1
		if field._count_drifters_at(cell.position,
				field._hide_reach(true) + Drop.DRIFTER_FLOOR_SLACK) == 0:
			floor_missed += 1
		for b: Object in field.get("_cells"):
			if b.get("seeded") and not b.get("inert"):
				biggest = maxf(biggest, float(b.get("radius")))
				if float(b.get("radius")) >= CellBody.DIVIDE_RADIUS - 1e-3:
					at_forty += 1
	var living := 0
	var venomous := 0
	for b: Object in field.get("_cells"):
		if b.get("seeded") and not b.get("inert"):
			living += 1
			if b.get("drifter") and (b.get("genome") as Dictionary).has(&"veneneux"):
				venomous += 1
	_check(("5. growth: five minutes of a drop made for a sighted player, the biggest body"
		+ " r%.2f (DIVIDE_RADIUS %.0f; %d looks at one there), and of %d bodies made the"
		+ " widest mouth %.2f (ARRIVAL_GAPE_MAX %.0f)") % [biggest, CellBody.DIVIDE_RADIUS,
		at_forty, field.made, field.made_gape, FoodField.ARRIVAL_GAPE_MAX],
		biggest <= CellBody.DIVIDE_RADIUS + 1e-4 and at_forty > 0
		and field.made_gape <= FoodField.ARRIVAL_GAPE_MAX and field.made > 1000)
	_check(("6. the floors: at %d gene counts a drifter gene carried by nobody %d times and"
		+ " one still short at the count after %d; a living drifter within the floor's"
		+ " reach of the still player at %d of %d checks; drifters made with venom %d,"
		+ " living with it %d") % [field.counts, field.lost_genes, field.still_short,
		floor_checks - floor_missed, floor_checks, field.venom_drifters, venomous],
		field.counts >= 140 and field.lost_genes == 0 and field.still_short == 0
		and floor_missed == 0 and floor_checks >= 300 and field.venom_drifters == 0
		and venomous == 0)
	var gone := 0
	for cause: int in field.causes:
		gone += int(field.causes[cause])
	var four := 0
	for cause: int in [FoodField.Cause.SWALLOWED, FoodField.Cause.CHEWED,
			FoodField.Cause.STARVED, FoodField.Cause.POISONED]:
		four += int(field.causes.get(cause, 0))
	_check(("11. one body, five minutes: %d bodies gone -- %d swallowed, %d chewed, %d"
		+ " starved, %d poisoned, %d any other way -- and %d made = %d living + %d gone;"
		+ " %d swims, %d faster than its own tail and dash, %d bursts without a myoneme,"
		+ " %d searching frames, %d faster than its tail; %d runs begun, %d at what its"
		+ " senses cannot find; %d given up, %d of them in a flight") % [gone,
		int(field.causes.get(FoodField.Cause.SWALLOWED, 0)),
		int(field.causes.get(FoodField.Cause.CHEWED, 0)),
		int(field.causes.get(FoodField.Cause.STARVED, 0)),
		int(field.causes.get(FoodField.Cause.POISONED, 0)), gone - four, field.made,
		living, gone, field.swims, field.fast, field.burst_without, field.searches,
		field.fast_search, field.runs_begun, field.blind_runs, field.given_up, field.fled],
		gone - four == 0 and gone > 500 and field.made == living + gone
		and int(field.causes.get(FoodField.Cause.STARVED, 0)) > 0
		and field.swims > 10000 and field.fast == 0 and field.burst_without == 0
		and field.searches > 1000 and field.fast_search == 0 and field.runs_begun > 500
		and field.blind_runs == 0 and field.given_up > 100 and field.fled == 0)
	_done(water)


# --- 8. Determinism -------------------------------------------------------------------------

## **One seed, one drop** (§14.3): forty seconds of a drop made for a sighted
## player twice from one seed print the same census line to the byte -- the
## checksum of every body's place, size and tank included -- and so does the
## same seed with the near-first prey search off: nearest wins, so the search
## that looks near first finds the same body (§4.2).
func _determinism() -> void:
	var lines: Array[String] = []
	for near_first: bool in [true, true, false]:
		seed(8088)
		var water := _water(0.0, 0.6)
		var field: WatchedDrop = water[0]
		field.near_first = near_first
		for f in 40 * 60:
			field._process(1.0 / 60.0)
		lines.append(field.census_line())
		_done(water)
	seed(20260930)
	var sums := PackedStringArray()
	for line in lines:
		sums.append(line.get_slice("| sum ", 1))
	_check(("8. determinism: one seed, forty seconds of a sighted player's drop, twice and"
		+ " with the near-first search off: census checksums %s, the lines %s") % [
		", ".join(sums), "the same" if lines[0] == lines[1] and lines[0] == lines[2]
		else "DIFFERENT"],
		lines[0] == lines[1] and lines[0] == lines[2] and lines[0].contains("living"))


# --- 9. Flocs ---------------------------------------------------------------------------------

## **None edible before it has settled** (§7.2): a floc landing in the player's
## mouth is taken the frame it has settled and not before, and one held in a
## resting hunter's mouth too -- and that hunter's graze fed it and grew nothing
## (§7.3). **Remains** (§7.4) lie where a body died of hunger and of poison, and
## nowhere a body was swallowed or chewed.
func _flocs() -> void:
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var cells: Array = field.get("_cells")
	cell.heading = 0.0
	field.in_water = true
	var got := [-1.0, 0.0, -1.0]
	field.grazed.connect(func(nutrition: float, _at: Vector2) -> void:
		if got[0] < 0.0:
			got[0] = float(field.get("_t"))
			got[1] = nutrition)
	var in_mouth := cell.position + Vector2(0.0, -(cell.radius + 6.0))
	var touching := Cilia.mouth_touches(cell.position, cell.heading, cell.radius, cell.gape(),
		in_mouth, 9.0)
	field._spawn_floc(in_mouth, 9.0, false)
	# A resting hunter 600 off, well inside the view's every-frame reach, a floc
	# landing where its mouth is: held there, as its mouth drifts.
	var hunter := _pose(field, cell.position + Vector2(600.0, 0.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"chemocyte": 1}, PI * 0.5, 0.6)
	var hb: Object = cells[hunter]
	var genes_before := (hb.get("genome") as Dictionary).duplicate()
	var r_before := float(hb.get("radius"))
	var held := field._spawn_floc(Vector2.ZERO, 9.0, false)
	var held_serial := int((cells[held] as Object).get("serial"))
	var hunger_before := 0.0
	for f in 8 * 60:
		if got[2] < 0.0:
			var h_at: Vector2 = hb.get("pos")
			var ahead := Vector2(sin(float(hb.get("heading"))), -cos(float(hb.get("heading"))))
			(cells[held] as Object).set("pos", h_at + ahead * (float(hb.get("radius")) + 6.0))
			field.refile(held)
			hunger_before = float(hb.get("hunger"))
		field._process(1.0 / 60.0)
		if got[2] < 0.0 and (not (cells[held] as Object).get("seeded")
				or int((cells[held] as Object).get("serial")) != held_serial):
			got[2] = float(field.get("_t"))
		if got[0] >= 0.0 and got[2] >= 0.0:
			break
	var hunger_after := float(hb.get("hunger"))
	var fed: bool = hunger_after < hunger_before - 0.2 and float(hb.get("radius")) == r_before \
		and hb.get("genome") == genes_before
	# Remains: a hunter starving out its grace, a biter poisoned by what it bit,
	# a prey swallowed and a prey chewed apart -- each posed in the clear.
	var p := cell.position
	var starving := _pose(field, p + Vector2(-800.0, 400.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, 0.0, 1.0)
	(cells[starving] as Object).set("starve", Metabolism.STARVE_GRACE - 1e-4)
	var starved_at: Vector2 = (cells[starving] as Object).get("pos")
	field._tank(starving, cells[starving], 1.0 / 60.0)
	var biter := _pose(field, p + Vector2(-800.0, -400.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var bitten := _pose(field, p + Vector2(-800.0, -350.0), 40.0,
		{&"cytostome": 1, &"veneneux": 3})
	(cells[biter] as Object).set("wound", 0.99)
	var poisoned_at: Vector2 = (cells[biter] as Object).get("pos")
	field._mouth_on_drop(biter, cells[biter], bitten, cells[bitten],
		field._gape(cells[biter]))
	var swallower := _pose(field, p + Vector2(800.0, 900.0), 40.0,
		{&"cytostome": 3, &"cirrus": 1, &"flagellum": 1})
	var swallowed := _pose(field, p + Vector2(800.0, 960.0), 18.0, {&"cirrus": 1})
	var swallowed_at: Vector2 = (cells[swallowed] as Object).get("pos")
	field._mouth_on_drop(swallower, cells[swallower], swallowed, cells[swallowed],
		field._gape(cells[swallower]))
	var chewer := _pose(field, p + Vector2(-400.0, 1200.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var chewed := _pose(field, p + Vector2(-400.0, 1250.0), 40.0,
		{&"cytostome": 1, &"cirrus": 1})
	(cells[chewed] as Object).set("wound", 0.99)
	var chewed_at: Vector2 = (cells[chewed] as Object).get("pos")
	field._mouth_on_drop(chewer, cells[chewer], chewed, cells[chewed],
		field._gape(cells[chewer]))
	var remains := [_flocs_at(field, starved_at).size(), _flocs_at(field, poisoned_at).size(),
		_flocs_at(field, swallowed_at).size(), _flocs_at(field, chewed_at).size()]
	var sizes := []
	for at: Vector2 in [starved_at, poisoned_at]:
		var found := _flocs_at(field, at)
		sizes.append(float(found[0].get("radius")) if not found.is_empty() else -1.0)
	_check(("9. flocs: one landing in the player's mouth is taken at %.2f s, once settled"
		+ " (FLOC_SETTLE %.0f; the mouth on it %s), worth %.2f; one held in a resting"
		+ " hunter's at %.2f s, its hunger %.2f -> %.2f and its r%.0f and genes as they"
		+ " were (%s); remains where a body died of hunger (%d, r%.1f) and of poison (%d,"
		+ " r%.1f), none where one was swallowed (%d) or chewed (%d)") % [got[0],
		Drop.FLOC_SETTLE, "yes" if touching else "NO", got[1], got[2], hunger_before,
		hunger_after, r_before, "yes" if fed else "NO", remains[0], sizes[0], remains[1],
		sizes[1], remains[2], remains[3]],
		touching and got[0] >= Drop.FLOC_SETTLE - 1e-3 and got[0] < Drop.FLOC_SETTLE + 0.1
		and got[2] >= Drop.FLOC_SETTLE - 1e-3 and got[2] < Drop.FLOC_SETTLE + 0.2
		and absf(got[1] - FoodField._meal_value_for(9.0, cell.radius)) < 1e-6 and fed
		and remains == [1, 1, 0, 0]
		and is_equal_approx(sizes[0], Drop.remains_radius(30.0))
		and is_equal_approx(sizes[1], Drop.remains_radius(30.0)))
	_done(water)


## **A graze feeds and grows nothing**, on the run's own handler (§7.3): the bar
## falls by the meal every body's goes through, and the body and its genes stay
## as they were. The run is the real one, in the drop, built headless.
func _flocs_fed() -> void:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 0)
	run.set("scheme", 0)
	run.set("keep", "")
	add_child(run)
	await get_tree().process_frame
	var met: Node = run.get("_metabolism")
	var cell: CellBody = run.get("_cell")
	var genome: Node = run.get("_genome")
	var food: Node = run.get("_food")
	met.set_hunger(0.6)
	var radius := cell.radius
	var tiers: Dictionary = (genome.call(&"tiers") as Dictionary).duplicate()
	run.call(&"_on_grazed", 0.4, cell.position + Vector2(0.0, -40.0))
	var after := float(met.get("hunger"))
	_check(("9. a graze on the run's own handler, in the drop (%s): the bar %.2f -> %.3f"
		+ " (a meal of 0.40 is %.3f), r%.0f -> r%.0f, genes %s") % [
		"yes" if food.call(&"in_drop") else "NO", 0.6, after, Metabolism.meal(0.4), radius,
		cell.radius, "as they were" if genome.call(&"tiers") == tiers else "CHANGED"],
		bool(food.call(&"in_drop")) and absf(after - (0.6 - Metabolism.meal(0.4))) < 1e-6
		and cell.radius == radius and genome.call(&"tiers") == tiers)
	run.queue_free()
	await get_tree().process_frame


# --- 11. One body, posed ---------------------------------------------------------------------

## **One mouth rule for every body** (§5.6, §5.7), each on bodies posed in the
## clear: a mouth swallows a player that fits on contact, hunting or not (row
## 15), and is fed by it; `pellicle` makes a body too big for a mouth it would
## otherwise fit (row 5); venom as today (row 12) -- whatever swallows a venomous
## player dies of it and leaves remains, and a player swallows a venomous cell
## safely; a water cell's dart breaks a run at it; and the taste field and the
## bloom weigh a body by the size its mouth measures.
func _one_body() -> void:
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var cells: Array = field.get("_cells")
	cell.heading = 0.0
	field.in_water = true
	var p := cell.position
	var said := {"killed": 0, "stung": 0, "ate": 0}
	field.killed.connect(func(_b: float) -> void: said["killed"] += 1)
	field.stung.connect(func(_b: float) -> void: said["stung"] += 1)
	field.eaten.connect(func(_n: float, _g: StringName, _a: Vector2) -> void: said["ate"] += 1)
	var big := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1}
	# Row 15: a resting r40 mouth, not hunting anyone, its mouth on the player.
	var at := p + Vector2(0.0, -(40.0 + cell.radius) * 0.95)
	var h := _pose(field, at, 40.0, big, _facing(at, p), 0.5)
	var hb: Object = cells[h]
	var mouth_on := Cilia.mouth_touches(at, hb.get("heading"), 40.0, field._gape(hb), p,
		cell.radius)
	field.set("_near", field.bodies_near(p, 2500.0))
	var dead: bool = field._contacts_with(null)
	var swallow := [dead, said["killed"], int(field.get("died_of")) == FoodField.Cause.SWALLOWED,
		float(hb.get("hunger")) < 0.5, int(hb.get("meals")) == 1, float(hb.get("calm")),
		int(hb.get("state")) == FoodField.State.DRIFT]
	# The switch the other way: only a run swallows, so this one only bites.
	field.contact_swallow = false
	var h2 := _pose(field, at + Vector2(0.1, 0.0), 40.0, big, _facing(at, p), 0.5)
	(cells[h] as Object).set("pos", p + Vector2(3000.0, 0.0))
	field.refile(h)
	field.set("_near", field.bodies_near(p, 2500.0))
	var spared: bool = not field._contacts_with(null) and said["killed"] == 1
	field.contact_swallow = true
	cell.wound = 0.0
	(cells[h2] as Object).set("pos", p + Vector2(3000.0, 300.0))
	field.refile(h2)
	# Row 12: a venomous player is spat out alive; what swallowed it dies of it.
	field.venom_cost = CellBody.VENOM_COST_BY_TIER[3]
	var v := _pose(field, at, 40.0, big, _facing(at, p), 0.5)
	var v_at: Vector2 = (cells[v] as Object).get("pos")
	field.set("_near", field.bodies_near(p, 2500.0))
	var stung_dead: bool = field._contacts_with(null)
	var venom_out := [stung_dead, said["stung"], said["killed"],
		not (cells[v] as Object).get("seeded") or (cells[v] as Object).get("inert"),
		_flocs_at(field, v_at).size()]
	field.venom_cost = -1.0
	# And a player swallows a venomous water cell safely: an r15 one in its mouth.
	var small_at := p + Vector2(0.0, -(cell.radius + 12.0))
	var s := _pose(field, small_at, 15.0, {&"cytostome": 1, &"veneneux": 3}, PI, 0.5)
	field.set("_near", field.bodies_near(p, 2500.0))
	var safe: bool = not field._contacts_with(null)
	var venom_in := [safe, said["ate"], said["killed"], not (cells[s] as Object).get("seeded")]
	# Row 5: `pellicle` on a water body puts it past a mouth its bare radius fits.
	var mouth := _pose(field, p + Vector2(-900.0, 0.0), 30.0,
		{&"cytostome": 2, &"cirrus": 1, &"flagellum": 1})
	var mb: Object = cells[mouth]
	var gape: float = field._gape(mb)
	var armoured := _pose(field, p + Vector2(-900.0, -60.0), 24.0,
		{&"cirrus": 1, &"pellicle": 3})
	var bare := _pose(field, p + Vector2(-900.0, 60.0), 24.0, {&"cirrus": 1})
	field._mouth_on_drop(mouth, mb, armoured, cells[armoured], gape)
	(mb as Object).set("bite", 0.0)
	var kept := bool((cells[armoured] as Object).get("seeded")) \
		and float((cells[armoured] as Object).get("wound")) > 0.0
	field._mouth_on_drop(mouth, mb, bare, cells[bare], gape)
	var taken: bool = not (cells[bare] as Object).get("seeded")
	# The dart: a hunter stalking a cell whose `trichocyst` looks at it, in range.
	var prey := _pose(field, p + Vector2(900.0, -900.0), 26.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"trichocyst": 1}, 0.0)
	var pb: Object = cells[prey]
	var arc := float(pb.get("heading")) + float(pb.get("dart_bearing"))
	var stalker := _pose(field, (pb.get("pos") as Vector2)
		+ Vector2(sin(arc), -cos(arc)) * 100.0, 30.0, big, 0.0)
	var sb: Object = cells[stalker]
	field._start_run(sb, prey, int(pb.get("serial")))
	sb.set("orienting", false)
	field._step_stalk(stalker, sb, 1.0 / 60.0)
	var darted := [int(sb.get("state")) == FoodField.State.DRIFT,
		is_equal_approx(float(sb.get("calm")), FoodField.REST_MISS),
		float(pb.get("dart_clock")) > 0.0]
	# The taste and the bloom, by the size the mouth measures: an r18 body 300
	# ahead, bare and then with a thick skin that puts it past a born gape.
	field.smell_range = CellBody.SMELL_RANGE_BY_TIER[1]
	field.smell_bearing = 0.0
	var tasted := []
	var bloom := []
	for skin: int in [0, 3]:
		var tiers := {&"cirrus": 1}
		if skin > 0:
			tiers[&"pellicle"] = skin
		var t := _pose(field, p + Vector2(0.0, -300.0), 18.0, tiers)
		field.set("_near", PackedInt32Array([t]))
		field._step_sense()
		tasted.append(float(field.get("taste_level")))
		bloom.append(FoodField.taste_weight(field.swallow_size_of(t), cell.gape()))
		field._drop_lose(t, 0)
	_check(("11. a mouth on the player swallows it on contact, hunting or not (touching %s,"
		+ " killed %s, swallowed %s), and is fed by it (hunger down %s, a meal %s, resting"
		+ " %.0f s, %s); with the switch off it only bites (%s)") % [str(mouth_on),
		str(swallow[0]), str(swallow[2]), str(swallow[3]), str(swallow[4]), swallow[5],
		"drifting" if swallow[6] else "NOT drifting", str(spared)],
		mouth_on and swallow[0] and swallow[1] == 1 and swallow[2] and swallow[3]
		and swallow[4] and is_equal_approx(float(swallow[5]), FoodField.REST_MEAL)
		and swallow[6] and spared)
	_check(("11. venom as today: a mouth that swallows a venomous player dies of it"
		+ " (player dead %s, stung %d, killed %d, the mouth gone %s, remains %d); a player"
		+ " swallows a venomous cell safely (dead %s, meals %d, killed %d, gone %s)") % [
		str(venom_out[0]), venom_out[1], venom_out[2], str(venom_out[3]), venom_out[4],
		str(not venom_in[0]), venom_in[1], venom_in[2], str(venom_in[3])],
		not venom_out[0] and venom_out[1] == 1 and venom_out[2] == 1 and venom_out[3]
		and venom_out[4] == 1 and venom_in[0] and venom_in[1] == 1 and venom_in[2] == 1
		and venom_in[3])
	_check(("11. pellicle: an r24 body with a tier-3 skin is chewed by a mouth of %.1f"
		+ " (%s), the same body bare is swallowed (%s); a water cell's dart breaks a run"
		+ " at it (%s); the taste %.3f bare and %.3f armoured, the bloom %.2f and %.2f")
		% [gape, str(kept), str(taken), str(darted), tasted[0], tasted[1], bloom[0],
		bloom[1]],
		kept and taken and darted == [true, true, true] and tasted[0] > 0.05
		and tasted[1] == 0.0 and bloom[0] == 1.0 and bloom[1] == 0.0)
	_done(water)


# --- 13. The replay on the drop (§11) --------------------------------------------------------

## **A run's recorder, on water stepped by hand**: a still cell, a field and
## the recorder last, as they are in a run, none of them processing on its own.
## [method _rig_step] steps the water one fixed frame and has the recorder take
## it, as the run's frame does. [param drop] false is today's water.
func _rig(drop: bool, desert := 0.0) -> Array:
	var rig := Node.new()
	rig.name = "Rig"
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	cell.process_mode = Node.PROCESS_MODE_DISABLED
	rig.add_child(cell)
	var field := WatchedDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.desert = desert
	rig.add_child(field)
	var recorder := RecorderNode.new()
	recorder.process_mode = Node.PROCESS_MODE_DISABLED
	rig.add_child(recorder)
	add_child(rig)
	if drop:
		field.setup_drop(cell)
	else:
		field.setup(cell)
	field.in_water = false
	return [rig, field, cell, recorder]


func _rig_step(rig: Array, frames: int, move := Vector2.ZERO) -> void:
	for f in frames:
		(rig[2] as CellBody).position += move
		(rig[1] as Node)._process(1.0 / 60.0)
		(rig[3] as Node)._process(1.0 / 60.0)


## Where the recorder's newest frame starts in its ring.
func _newest(recorder: Node) -> int:
	var head := int(recorder.get("_head"))
	return ((head - 1 + RecorderNode.CAPACITY) % RecorderNode.CAPACITY) * RecorderNode.STRIDE


## [param x] as the ring holds it.
func _f32(x: float) -> float:
	var one := PackedFloat32Array([x])
	return one[0]


## The replay screen over [param recorder]'s sealed ring, as the run raises it:
## a child of the run, handed the recorder before it enters the tree. Driven by
## hand from here, one seek at a time.
func _raise_replay(run: Node, recorder: Node) -> Node:
	var screen: Node = (load("res://game/replay/replay.tscn") as PackedScene).instantiate()
	screen.set(&"recorder", recorder)
	run.add_child(screen)
	screen.set_process(false)
	return screen


func _seek(screen: Node, at: float) -> void:
	screen.set(&"_at", at)
	screen.call(&"_seek")


## Every body in [param field] as a row of what the replay could have written.
func _snapshot(field: Node) -> Array:
	var out := []
	for b: Object in field.get("_cells"):
		out.append([b.get("pos"), b.get("heading"), b.get("radius"), b.get("wound"),
			(b.get("genome") as Dictionary).duplicate(), b.get("seeded"), b.get("state"),
			b.get("target"), b.get("id"), b.get("settle"), b.get("hunger")])
	return out


func _replay() -> void:
	_replay_slots()
	_replay_bubble()
	_replay_flocs()
	_replay_killer()
	await _replay_run()


## **The 48 nearest, each in a slot it keeps** (§11): a drop stepped four
## seconds with the cell crossing it, and after every frame the slots hold
## exactly the living bodies nearest the cell within the recorder's reach, at
## most 48, their places and sizes as the field had them; a body never changes
## slot while it stays among them; an empty slot is radius 0.
func _replay_slots() -> void:
	var rig := _rig(true)
	var field: WatchedDrop = rig[1]
	var cell: CellBody = rig[2]
	var rec: Node = rig[3]
	var toward: Vector2 = ((field.basin().get(&"center") as Vector2) - cell.position) \
		.normalized() * 10.0
	var before := {}
	var wrong_set := 0
	var moved := 0
	var bad := 0
	var arrivals := 0
	var filled := 0
	for f in 240:
		_rig_step(rig, 1, toward)
		var cells: Array = field.get("_cells")
		var keys := PackedInt64Array()
		for i in cells.size():
			var b: Object = cells[i]
			if not b.get("seeded") or b.get("inert"):
				continue
			var d2 := (b.get("pos") as Vector2).distance_squared_to(cell.position)
			if d2 <= RecorderNode.REACH * RecorderNode.REACH:
				keys.append((int(d2) << RecorderNode.INDEX_BITS) | i)
		keys.sort()
		var want := {}
		for k in mini(keys.size(), RecorderNode.BODIES):
			want[int((cells[int(keys[k] & RecorderNode.INDEX_MASK)] as Object).get("serial"))] = 1
		var ring: PackedFloat32Array = rec.get("_ring")
		var at := _newest(rec)
		var serials: PackedInt64Array = rec.get("_slot_serial")
		var indices: PackedInt32Array = rec.get("_slot_index")
		var now := {}
		for s in RecorderNode.BODIES:
			var o := at + RecorderNode.AT_BODIES + s * RecorderNode.BODY_FLOATS
			if serials[s] < 0:
				if ring[o + 3] != 0.0:
					bad += 1
				continue
			var b: Object = cells[indices[s]]
			var p: Vector2 = b.get("pos")
			if int(b.get("serial")) != serials[s] or ring[o] != _f32(p.x) \
					or ring[o + 1] != _f32(p.y) or ring[o + 3] != _f32(float(b.get("radius"))):
				bad += 1
			now[int(serials[s])] = s
			if before.has(int(serials[s])):
				if int(before[int(serials[s])]) != s:
					moved += 1
			else:
				arrivals += 1
		if now.size() != want.size():
			wrong_set += 1
		else:
			for serial: int in want:
				if not now.has(serial):
					wrong_set += 1
					break
		filled = now.size()
		before = now
	_check(("13. the replay's slots: after each of 240 frames of a cell crossing the drop"
		+ " the %d slots hold the living bodies nearest it (%d frames wrong), as the field"
		+ " had them (%d wrong), none changing slot while it stays among them (%d moved),"
		+ " %d arrivals in all, the last frame %d full") % [RecorderNode.BODIES, wrong_set,
		bad, moved, arrivals, filled],
		wrong_set == 0 and bad == 0 and moved == 0 and filled == RecorderNode.BODIES
		and arrivals > RecorderNode.BODIES + 20)
	(rig[0] as Node).queue_free()


## **Today's water records as it always did** (§11): the bubble a run with a
## session still plays, its 34 bodies in the slots of their own indices -- with
## the floats the field had, the hunter as its index, and the rest empty --
## through a cell crossing it fast enough that its bodies are reseeded.
func _replay_bubble() -> void:
	var rig := _rig(false)
	var field: WatchedDrop = rig[1]
	var rec: Node = rig[3]
	var cells: Array = field.get("_cells")
	var bad := 0
	var hunted := 0
	var reseeds := 0
	var last := PackedInt64Array()
	for b: Object in cells:
		last.append(int(b.get("serial")))
	for f in 240:
		(rig[2] as CellBody).position += Vector2(12.0, 0.0)
		field._process(1.0 / 60.0)
		# Something hunting the cell as the frame is taken, so the hunter's
		# float is a slot to check.
		(cells[5] as Object).set("state", FoodField.State.STALK)
		(cells[5] as Object).set("target", FoodField.TARGET_PLAYER)
		rec._process(1.0 / 60.0)
		var ring: PackedFloat32Array = rec.get("_ring")
		var at := _newest(rec)
		var indices: PackedInt32Array = rec.get("_slot_index")
		for s in RecorderNode.BODIES:
			var o := at + RecorderNode.AT_BODIES + s * RecorderNode.BODY_FLOATS
			if s >= FoodField.COUNT:
				if indices[s] >= 0 or ring[o + 3] != 0.0:
					bad += 1
				continue
			var b: Object = cells[s]
			var p: Vector2 = b.get("pos")
			# The gape as the recorder has always written it: its tier's
			# multiplier, held as a float, times the radius.
			var r := float(b.get("radius"))
			var gape := _f32(_f32(CellBody.gape_of(GenomeNode.tier_of(b.get("genome"),
				&"cytostome"), 1.0)) * r)
			if indices[s] != s or ring[o] != _f32(p.x) or ring[o + 1] != _f32(p.y) \
					or ring[o + 2] != _f32(float(b.get("heading"))) or ring[o + 3] != _f32(r) \
					or ring[o + 4] != _f32(float(b.get("wound"))) or ring[o + 5] != gape:
				bad += 1
			if int(b.get("serial")) != last[s]:
				last[s] = int(b.get("serial"))
				reseeds += 1
		var hunter := field.hunter()
		if ring[at + RecorderNode.AT_HUNTER] != float(hunter):
			bad += 1
		if hunter >= 0:
			hunted += 1
	var body_rows := 0
	var off_index := 0
	for row: Array in rec.call(&"deltas"):
		if int(row[1]) == RecorderNode.Delta.BODY:
			body_rows += 1
			if int(row[2]) >= FoodField.COUNT:
				off_index += 1
	_check(("13. today's water records as it did: 240 frames, its %d bodies in the slots"
		+ " of their own indices with the field's floats and the rest empty (%d wrong),"
		+ " the hunter's float its index on %d frames, %d reseeds, %d genome rows none past"
		+ " slot %d (%d)") % [FoodField.COUNT, bad, hunted, reseeds, body_rows,
		FoodField.COUNT - 1, off_index],
		bad == 0 and hunted == 240 and reseeds > 10
		and body_rows >= FoodField.COUNT + reseeds and off_index == 0)
	(rig[0] as Node).queue_free()


## **Flocs as SETTLE and CLEAR** (§11): a flake landing near the cell is told
## once, as it lands, with its place and radius, and once as it is eaten, and it
## settles by the time since as the field steps it; a cell starving in view is
## its slot emptying and a SETTLE where it died, already settled -- and the
## replay's own field has each floc from its SETTLE to its CLEAR, and not
## outside them.
func _replay_flocs() -> void:
	var rig := _rig(true, 3000.0)
	var field: WatchedDrop = rig[1]
	var cell: CellBody = rig[2]
	var rec: Node = rig[3]
	var cells: Array = field.get("_cells")
	var p := cell.position
	var landed := p + Vector2(300.0, 0.0)
	_rig_step(rig, 5)
	var flake := field._spawn_floc(landed, 9.0, false)
	var flake_id := int((cells[flake] as Object).get("id"))
	_rig_step(rig, 150)
	var settled := float((cells[flake] as Object).get("settle"))
	var clock := float(rec.get("_clock"))
	field._consume(flake)
	_rig_step(rig, 5)
	# A hunter starving 500 off: in a slot, then gone, and its remains where it was.
	var starving := _pose(field, p + Vector2(-500.0, 0.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, 0.0, 1.0)
	_rig_step(rig, 5)
	var slot: int = (rec.get("_slot_by_index") as PackedInt32Array)[starving]
	var died_at: Vector2 = (cells[starving] as Object).get("pos")
	(cells[starving] as Object).set("starve", Metabolism.STARVE_GRACE - 1e-4)
	_rig_step(rig, 5)
	var ring: PackedFloat32Array = rec.get("_ring")
	var emptied: bool = slot >= 0 and ring[_newest(rec) + RecorderNode.AT_BODIES
		+ slot * RecorderNode.BODY_FLOATS + 3] == 0.0
	var landings := 0
	var predicted := -1.0
	var clears := 0
	var clear_t := 0.0
	var remains := 0
	var remains_id := -1
	var remains_t := 0.0
	for row: Array in rec.call(&"deltas"):
		var kind := int(row[1])
		if kind == RecorderNode.Delta.SETTLE:
			var floc: Array = row[3]
			if int(row[2]) == flake_id:
				landings += 1
				if (floc[0] as Vector2) == landed and float(floc[1]) == 9.0 \
						and float(floc[2]) < 0.01:
					predicted = FoodField.floc_settle_after(float(floc[2]), float(floc[3]),
						clock - float(row[0]))
			elif (floc[0] as Vector2) == died_at and float(floc[2]) == 1.0 \
					and is_equal_approx(float(floc[1]), Drop.remains_radius(30.0)):
				remains += 1
				remains_id = int(row[2])
				remains_t = float(row[0])
		elif kind == RecorderNode.Delta.CLEAR and int(row[2]) == flake_id:
			clears += 1
			clear_t = float(row[0])
	rec.call(&"seal")
	var screen := _raise_replay(rig[0], rec)
	var water: Node = screen.get("_food")
	var origin := float(rec.call(&"origin"))
	var seen := []
	for t: float in [clear_t - 0.5, clear_t + 0.05, remains_t - 0.05, remains_t + 0.02]:
		_seek(screen, maxf(t - origin, 0.0))
		# The two flocs this check made; the drop's own may be in reach too.
		var here := []
		var map: Dictionary = water.get("_replay_flocs")
		for id: int in [flake_id, remains_id]:
			if not map.has(id):
				continue
			var b: Object = (water.get("_cells") as Array)[int(map[id])]
			if b.get("seeded"):
				here.append([id, b.get("pos"), float(b.get("settle"))])
		seen.append(here)
	_check(("13. flocs: a flake is told once as it lands (%d) and once as it is eaten (%d),"
		+ " settled %.4f after 2.5 s against %.4f by time; a cell starving in view empties"
		+ " its slot (%s) and leaves one SETTLE where it died, settled (%d); the replay's"
		+ " own field has the flake before its CLEAR and not after (%d, %d), the remains"
		+ " not before their SETTLE and then settled where it died (%d, %d)") % [landings,
		clears, settled, predicted, str(emptied), remains, seen[0].size(), seen[1].size(),
		seen[2].size(), seen[3].size()],
		landings == 1 and clears == 1 and absf(settled - predicted) < 1e-6 and emptied
		and remains == 1 and seen[0].size() == 1 and int(seen[0][0][0]) == flake_id
		and (seen[0][0][1] as Vector2) == landed and seen[1].is_empty()
		and seen[2].is_empty() and seen[3].size() == 1 and int(seen[3][0][0]) == remains_id
		and (seen[3][0][1] as Vector2) == died_at and float(seen[3][0][2]) == 1.0)
	(rig[0] as Node).queue_free()


## **Who killed you** (§11): a resting r40 mouth, hunting nobody, half a second
## in a slot before it is put against the cell and swallows it on contact. The
## ring names that slot as the killer on every frame since it took it and on none
## before, and names no hunter on any; the replay's own field answers
## `killer()` with it on those frames and -1 before them, `hunter()` -1 on all
## -- and the truth pane's predator rings go round the killer when nothing hunts.
func _replay_killer() -> void:
	var rig := _rig(true, 3000.0)
	var field: WatchedDrop = rig[1]
	var cell: CellBody = rig[2]
	var rec: Node = rig[3]
	var cells: Array = field.get("_cells")
	cell.heading = 0.0
	field.in_water = true
	# The run's order: the death seals the ring before the frame is taken.
	field.killed.connect(func(_bearing: float) -> void: rec.call(&"seal"))
	_rig_step(rig, 20)
	var p := cell.position
	var far := p + Vector2(0.0, -600.0)
	var k := _pose(field, far, 40.0, {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1},
		_facing(far, p), 0.5)
	_rig_step(rig, 30)
	var slot: int = (rec.get("_slot_by_index") as PackedInt32Array)[k]
	var at := p + Vector2(0.0, -(40.0 + cell.radius) * 0.95)
	(cells[k] as Object).set("pos", at)
	(cells[k] as Object).set("heading", _facing(at, p))
	field.refile(k)
	var tries := 0
	while bool(rec.get("_recording")) and tries < 10:
		_rig_step(rig, 1)
		tries += 1
	var ring: PackedFloat32Array = rec.get("_ring")
	var count: int = rec.call(&"frames")
	var start: int = rec.get("_start")
	var named := 0
	var wrong := 0
	for f in count:
		var o := ((start + f) % RecorderNode.CAPACITY) * RecorderNode.STRIDE
		var killer := int(ring[o + RecorderNode.AT_KILLER])
		if int(ring[o + RecorderNode.AT_HUNTER]) != -1:
			wrong += 1
		if f < 20:
			if killer != -1:
				wrong += 1
		elif killer == slot:
			named += 1
		else:
			wrong += 1
	var screen := _raise_replay(rig[0], rec)
	var water: Node = screen.get("_food")
	var vision: Node = (screen.get("_panes") as Node).get("_vision")
	var answers := []
	for f: int in [10, 30]:
		_seek(screen, float(rec.call(&"time_of", f)) + 0.001)
		answers.append([water.call(&"killer"), water.call(&"hunter"), vision.call(&"_predator")])
	_check(("13. the killer: a resting mouth swallows the cell on contact (%s, slot %d); the"
		+ " ring names it on %d frames of %d since it took its slot and wrongly on %d; the"
		+ " replay's field before it came %s, after %s (killer, hunter, the rings' body)")
		% [str(int(field.died_of) == FoodField.Cause.SWALLOWED and field.died_to == k), slot,
		named, count - 20, wrong, str(answers[0]), str(answers[1])],
		int(field.died_of) == FoodField.Cause.SWALLOWED and field.died_to == k and slot >= 0
		and named == count - 20 and count > 20 and wrong == 0
		and answers[0] == [-1, -1, -1] and answers[1] == [slot, -1, slot])
	(rig[0] as Node).queue_free()


## **The drop the player returns to is not the replay's to touch** (§11): a run
## in the drop starves, its replay is raised through the run's own button,
## played through its window twice and closed -- and every body in the run's
## field is as it was, to the bit; the replay drew from a field of its own, round
## the drop's own rim; and the cell, woken, is back in that same drop with every
## body still in it and one drifter more, its first.
func _replay_run() -> void:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 1)
	run.set("scheme", 0)
	run.set("keep", "")
	add_child(run)
	var rec: Node = run.get("_recorder")
	for f in 3000:
		await get_tree().process_frame
		if float(rec.call(&"span")) >= 2.5:
			break
	var food: Node = run.get("_food")
	var met: Node = run.get("_metabolism")
	met.call(&"set_hunger", 1.0)
	met.set("starve_seconds", Metabolism.STARVE_GRACE + 1.0)
	for f in 3:
		await get_tree().process_frame
	var dead := int(run.get("_life")) != 0
	var before := _snapshot(food)
	var ids := {}
	for b: Object in food.get("_cells"):
		if b.get("seeded"):
			ids[int(b.get("id"))] = float(b.get("radius"))
	# The collapse, skipped: the screen is offered once the run is waiting.
	run.set("_life", 2)
	run.call(&"_watch")
	var screen: Node = run.get("_replay")
	var water: Node = screen.get("_food") if screen != null else null
	for f in 20:
		await get_tree().process_frame
	var span := float(rec.call(&"span"))
	var own := water != null and water != food and bool(water.call(&"in_drop")) \
		and (water.call(&"basin").get(&"center") as Vector2) \
			== (food.call(&"basin").get(&"center") as Vector2)
	if screen != null:
		screen.set_process(false)
		for pass_ in 2:
			screen.call(&"_rewind")
			var t := 0.0
			while t < span:
				_seek(screen, t)
				t += 0.2
	run.call(&"_replay_closed")
	await get_tree().process_frame
	var intact := _snapshot(food) == before
	run.call(&"_wake_up")
	var back := {}
	for b: Object in food.get("_cells"):
		if b.get("seeded"):
			back[int(b.get("id"))] = float(b.get("radius"))
	var kept := 0
	for id: int in ids:
		if back.has(id) and float(back[id]) == float(ids[id]):
			kept += 1
	_check(("13. the drop after a replay: the run died (%s), watched %.1f s of it on a field"
		+ " of its own round the drop's rim (%s), and closed it -- the run's %d bodies as they"
		+ " were (%s); woken, back in the drop (%s) with %d of its %d bodies and %d more")
		% [str(dead), span, str(own), before.size(), str(intact),
		str(food.call(&"in_drop")), kept, ids.size(), back.size() - ids.size()],
		dead and span > 2.0 and own and intact and bool(food.call(&"in_drop"))
		and kept == ids.size() and back.size() == ids.size() + 1)
	run.queue_free()
	# A run, its replay and a ring freed: let that settle before the next check
	# times frames.
	for f in 10:
		await get_tree().process_frame


# --- 12. The save (§9, §14.3): 1b-1's four, and the room's (1b-2) --------------------------

## **Where these checks keep a drop**: a file of their own, never the player's.
const KEEP := "user://drop_probe/drop.save"

## **Every field of a body §9.2 names**, read off the body itself -- not off
## what the save gathered, so a field the save forgot fails here -- and what
## its genome buys, which a load re-derives rather than reads.
const KEPT_FIELDS: Array[String] = ["seeded", "id", "parent", "drifter", "inert", "meals",
	"pos", "heading", "radius", "wound", "age", "last_t", "hunger", "starve", "effort",
	"bite", "dart_clock", "dash_clock", "dash_v", "settle", "life", "genome"]
const DERIVED_FIELDS: Array[String] = ["upkeep", "reserve", "income", "burn", "armour",
	"tox", "cruise", "notice", "notice_floc", "see_big", "dart_bearing"]


## Each check begins with nothing kept, and nothing is left kept after them.
func _save() -> void:
	for check: Callable in [_save_bodies, _save_run, _save_format, _save_rules, _save_room,
			_save_lineage, _save_cell_lineage]:
		_forget_kept()
		await check.call()
	_forget_kept()


## **Save, load, the same bodies to the bit** (§14.3 check 12), and **an unknown
## gene survives**: twenty seconds of a drop, a body posed in it mid-everything
## -- wounded, its mouth, dart and dash on their clocks, a dash still carrying
## it, effort unpaid, empty and starving, carrying a gene this build does not
## know -- through the file's whole path, and loaded into a field of its own.
## Every slot, every field §9.2 names and what its genome buys, to the bit by
## their bytes; the free slots in their order, and the drop's clocks.
func _save_bodies() -> void:
	var water := _water(0.0, 0.6)
	var field: WatchedDrop = water[0]
	for f in 20 * 60:
		field._process(1.0 / 60.0)
	var at: Vector2 = field.basin().get(&"center") + Vector2(900.0, 0.0)
	var posed := _pose(field, at, 30.0, {&"cytostome": 2, &"rhabdom": 2, &"myoneme": 1})
	var b: Object = (field.get("_cells") as Array)[posed]
	for value: Array in [["wound", 0.3], ["bite", 0.4], ["dart_clock", 3.5],
			["dash_clock", 0.7], ["dash_v", 120.0], ["effort", 0.25], ["hunger", 1.0],
			["starve", 2.5], ["meals", 3], ["parent", 17]]:
		b.set(value[0], value[1])
	var wrote := DropSave.write(KEEP, DropSave.compose(field.drop_state(), {}))
	var tmp_left := FileAccess.file_exists(KEEP.get_basename() + ".tmp")
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	var field2 := WatchedDrop.new()
	field2.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(field2)
	var done: Dictionary = field2.load_drop(cell2, back["drop"]) if not back.is_empty() else {}
	var ours: Array = field.get("_cells")
	var theirs: Array = field2.get("_cells")
	# A slot nobody is in keeps whatever its last body left in it, and is only
	# ever asked whether it is empty.
	var differ := 0
	for i in mini(ours.size(), theirs.size()):
		var seeded := bool(ours[i].get("seeded"))
		if seeded != bool(theirs[i].get("seeded")):
			differ += 1
		elif seeded and (var_to_bytes(_row(ours[i], KEPT_FIELDS))
				!= var_to_bytes(_row(theirs[i], KEPT_FIELDS))
				or var_to_bytes(_row(ours[i], DERIVED_FIELDS))
				!= var_to_bytes(_row(theirs[i], DERIVED_FIELDS))):
			differ += 1
	var drop := ["_t", "_frame", "_next_id", "_free", "_eco_clock", "_gene_clock",
		"_floor_clock", "_shore_clock", "_living", "_drifters", "_flocs", "drop_seed"]
	var same_drop := var_to_bytes(_row(field, drop)) == var_to_bytes(_row(field2, drop)) \
		and var_to_bytes(field.basin().get(&"center")) == var_to_bytes(field2.basin().get(&"center"))
	var kept_gene := posed < theirs.size() and bool(theirs[posed].get("seeded")) \
		and int((theirs[posed].get("genome") as Dictionary).get(&"rhabdom", 0)) == 2
	var bytes := FileAccess.get_file_as_bytes(KEEP).size()
	_check(("12. save and load: %d slots, %d bodies written (%s, %d B on disk, no .tmp left:"
		+ " %s) and loaded into a field of their own -- %d slots differ in any field §9.2"
		+ " names or anything its genome buys, to the bit; the drop's clocks, free slots and"
		+ " counts %s; a gene this build does not know, rhabdom:2, %s") % [ours.size(),
		int(done.get("bodies", 0)), error_string(wrote), bytes, str(not tmp_left), differ,
		"the same" if same_drop else "DIFFERENT", "kept" if kept_gene else "LOST"],
		wrote == OK and not tmp_left and not back.is_empty() and ours.size() == theirs.size()
		and differ == 0 and same_drop and kept_gene and int(done.get("bodies", 0)) > 500)
	# A drop that came out of a file goes on as a drop.
	field2.in_water = false
	for f in 120:
		field2._process(1.0 / 60.0)
	field2.queue_free()
	cell2.free()
	_done(water)


## **A room kept and loaded goes on as one that never stopped** (§14.3 check 12,
## the room's case; §10.3): the server's room made anew and left to live with
## nobody in it -- every body on its tick -- for forty seconds, then kept through
## the file's whole path and loaded into a room of its own. From there both live
## thirty seconds more on the same random stream, and their census lines must
## match to the byte: the same population, the same deaths and meals, and the
## same sum of every body's place, size and tank. Whatever the file forgot that
## the drop reads -- a chase, a clock, the grid's order, the floor's short genes
## -- moves the second one off the first.
func _save_room() -> void:
	seed(20261001)
	var cell := CellBody.new()
	var room := WatchedDrop.new()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(room)
	room.open_dedicated(cell)
	for f in 40 * 60:
		room._process(1.0 / 60.0)
	var runs := 0
	for b: Object in room.get("_cells"):
		if b.get("seeded") and int(b.get("state")) == FoodField.State.STALK:
			runs += 1
	var wrote := DropSave.write(KEEP, DropSave.compose(room.drop_state(), {}))
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	var room2 := WatchedDrop.new()
	room2.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(room2)
	var done: Dictionary = room2.open_dedicated(cell2, back["drop"]) if not back.is_empty() \
		else {}
	seed(4242)
	for f in 30 * 60:
		room._process(1.0 / 60.0)
	var ours: String = room.census_line()
	seed(4242)
	for f in 30 * 60:
		room2._process(1.0 / 60.0)
	var theirs: String = room2.census_line()
	var age := room2.drop_age()
	_check(("12. a room kept and loaded (%s, %d bodies, %d of them on a run as it was kept) goes"
		+ " on as one that never stopped: after 30 s more on the same stream the two census"
		+ " lines are %s -- %s") % [error_string(wrote), int(done.get("bodies", 0)), runs,
		"the same" if ours == theirs else "DIFFERENT", ours if ours == theirs
			else ours + " AGAINST " + theirs],
		wrote == OK and not back.is_empty() and runs > 0 and ours == theirs
		and is_equal_approx(age, 70.0) and int(done.get("bodies", 0)) > 500)
	room.queue_free()
	room2.queue_free()
	cell.free()
	cell2.free()


## **Your cell, kept** (row 17): a run with nothing kept opens on a new drop;
## played, and left mid-run -- the app paused, as a phone pauses it -- it keeps
## the drop and the cell; and the next run opens on that drop to the bit, with
## that cell in it where it was, its size, both registers by name with a gene
## this build does not know and a waiting gene on its clock, its tank, its
## generation, its grace -- behind the beat, and with nothing in its replay. And
## the two daughters it had been offered are the two its next pinch offers.
func _save_run() -> void:
	var run := _kept_run()
	var food: Node = run.get("_food")
	var fresh: bool = not bool(run.get("_resumed")) and float(food.call(&"drop_age")) == 0.0 \
		and bool(food.call(&"in_drop"))
	for f in 90:
		await get_tree().process_frame
	var cell: CellBody = run.get("_cell")
	var genome: Node = run.get("_genome")
	var met: Node = run.get("_metabolism")
	cell.radius = 34.0
	genome.call(&"express", {&"cytostome": 2, &"cirrus": 1, &"flagellum": 1, &"rhabdom": 1},
		[&"cytostome", &"cirrus", &"flagellum", &"rhabdom"])
	genome.call(&"integrate", &"stigma")
	genome.set(&"held_remaining", 20.5)
	met.call(&"set_hunger", 0.4)
	run.set("_generation", 3)
	run.set("_parent", 4242)
	run.set("_lineage", 77)
	var pair: Array = run.call(&"_make_daughters")
	run.set("_daughters", pair)
	var was := _kept_cell(run)
	var drop_was: Dictionary = food.call(&"drop_state")
	var age := float(food.call(&"drop_age"))
	run.notification(NOTIFICATION_APPLICATION_PAUSED)
	var kept := FileAccess.file_exists(KEEP)
	run.queue_free()
	await get_tree().process_frame
	var again := _kept_run()
	var food2: Node = again.get("_food")
	var resumed := bool(again.get("_resumed"))
	var same_cell := var_to_bytes(_kept_cell(again)) == var_to_bytes(was)
	var same_drop := var_to_bytes(food2.call(&"drop_state")) == var_to_bytes(drop_was)
	var genome2: Node = again.get("_genome")
	var beat := float(again.get("_water_beat")) >= 0.0
	var ring := float((again.get("_recorder") as Node).call(&"span"))
	var same_pair := _same_pair(again.call(&"_kept_pair"), pair)
	_check(("12. your cell, kept: a run with nothing kept opens on a new drop (%s); left mid-run"
		+ " at %.1f s by the app pausing, it kept the drop (%s); the next opens on it resumed"
		+ " (%s), the drop %s to the bit, the cell -- r%.0f, dna %s, waiting %s, hunger %.2f,"
		+ " generation %d -- %s; behind the beat (%s), its replay %.1f s long; the daughters"
		+ " it was offered offered again at the pinch (%s)") % [str(fresh),
		age, str(kept), str(resumed), "the same" if same_drop else "DIFFERENT",
		(again.get("_cell") as CellBody).radius, genome2.call(&"layout"),
		genome2.call(&"waiting"), float((again.get("_metabolism") as Node).get("hunger")),
		int(again.get("_generation")), "as it was" if same_cell else "CHANGED", str(beat), ring,
		str(same_pair)],
		fresh and kept and resumed and same_drop and same_cell and beat and ring == 0.0
		and int((genome2.call(&"dna") as Dictionary).get(&"rhabdom", 0)) == 1 and same_pair)
	again.queue_free()
	await get_tree().process_frame


## **A format this build does not know starts fresh and keeps the old file**
## (§9.4): the file is not read but moved aside whole as `.old`, and the run
## opens on a new drop, which its next save point keeps in its place -- the old
## file still beside it, as it was: kept once, and not read again.
func _save_format() -> void:
	var water := _water()
	var later := DropSave.compose(water[0].call(&"drop_state"), {})
	later["format"] = DropSave.FORMAT + 1
	_done(water)
	var wrote := DropSave.write(KEEP, later)
	var old_bytes := FileAccess.get_file_as_bytes(KEEP)
	var run := _kept_run()
	var food: Node = run.get("_food")
	var fresh: bool = not bool(run.get("_resumed")) and float(food.call(&"drop_age")) == 0.0 \
		and bool(food.call(&"in_drop"))
	var moved := not FileAccess.file_exists(KEEP) \
		and FileAccess.get_file_as_bytes(KEEP + ".old") == old_bytes
	run.notification(NOTIFICATION_APPLICATION_PAUSED)
	var readable := not DropSave.read(KEEP).is_empty()
	var once := FileAccess.get_file_as_bytes(KEEP + ".old") == old_bytes
	_check(("12. an unknown format: a file of format %d (%s) is not read -- moved aside as .old"
		+ " whole (%s) -- and the run opens on a new drop (%s), which leaving keeps in its"
		+ " place (%s), the old file still beside it as it was (%s)") % [DropSave.FORMAT + 1,
		error_string(wrote), str(moved), str(fresh), str(readable), str(once)],
		wrote == OK and moved and fresh and readable and once and not old_bytes.is_empty())
	run.queue_free()
	await get_tree().process_frame


## **A changed `rules` re-derives and logs** (§9.4): a drop written under another
## fingerprint, with a body grown past this build's cap and one past its rim --
## as a content pack that lowered the cap or shrank the drop would leave it --
## loads whole: every body re-derived from its genome by name by this build's
## tables, the big one trimmed to the cap, the far one put back inside, the
## tanks kept as the share they were; and the log says it was converted, where a
## load under the same rules says nothing of the kind. **And the fingerprint is
## the same in every process**: its tables are listed by name, as Strings --
## sorted as the StringNames they are, they came out in memory's order, which
## moved from one process to the next.
func _save_rules() -> void:
	var names := PackedStringArray()
	for line: String in DropSave.rules_text().split("\n"):
		var name := line.get_slice("=", 0)
		if name.ends_with("_BY_TIER"):
			names.append(name)
	var by_name := names.duplicate()
	by_name.sort()
	var water := _water(0.0, 0.6)
	var field: WatchedDrop = water[0]
	for f in 5 * 60:
		field._process(1.0 / 60.0)
	var data := DropSave.compose(field.drop_state(), {})
	var calm := DropSave.note(data, {"bodies": 1})
	data["rules"] = "0".repeat(64)
	var rows: Dictionary = data["drop"]["bodies"]
	var kinds: PackedByteArray = rows["kind"]
	var big := -1
	var far := -1
	for k in kinds.size():
		if kinds[k] == 0 and big < 0:
			big = k
		elif kinds[k] == 1 and far < 0:
			far = k
	var radius: PackedFloat64Array = rows["radius"]
	radius[big] = CellBody.DIVIDE_RADIUS + 6.0
	rows["radius"] = radius
	var at: PackedVector2Array = rows["at"]
	at[far] = field.basin().get(&"center") + Vector2(Drop.RADIUS + 400.0, 0.0)
	rows["at"] = at
	var hunger: PackedFloat64Array = rows["hunger"]
	hunger[big] = 0.625
	rows["hunger"] = hunger
	_done(water)
	DropSave.write(KEEP, data)
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	var field2 := WatchedDrop.new()
	field2.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(field2)
	var done: Dictionary = field2.load_drop(cell2, back["drop"]) if not back.is_empty() else {}
	var line := DropSave.note(back, done) if not back.is_empty() else ""
	print(line)
	var cells: Array = field2.get("_cells")
	var slots: PackedInt32Array = rows["slot"]
	var b: Object = cells[slots[big]]
	var f: Object = cells[slots[far]]
	var g: Dictionary = b.get("genome")
	var derived := is_equal_approx(float(b.get("upkeep")), GenomeNode.upkeep_of(g)) \
		and float(b.get("cruise")) == CellBody.swim_speed_of(
			GenomeNode.tier_of(g, &"flagellum"), GenomeNode.tier_of(g, &"axoneme")) \
		and float(b.get("cruise")) > 0.0 \
		and float(b.get("reserve")) == CellBody.STORE_BY_TIER[clampi(
			GenomeNode.tier_of(g, &"vacuole"), 0, 3)]
	var inside: bool = (field2.basin() as Object).call(&"inside", f.get("pos"), f.get("radius"))
	_check(("12. a changed rules: a drop written under rules %s loads under %s, every body"
		+ " re-derived from its genome (%s); a body at r%.0f trimmed to r%.2f, one %.0f past"
		+ " the rim put back inside (%s), a tank kept at %.3f; the log says %s -- and under"
		+ " the same rules %s; the fingerprint's %d tables by name (%s)") % [
		str(back.get("rules", "?")).left(8), DropSave.rules().left(8),
		str(derived), CellBody.DIVIDE_RADIUS + 6.0, float(b.get("radius")), 400.0, str(inside),
		float(b.get("hunger")), "CONVERTED" if line.contains("CONVERTED") else "NOTHING",
		"it does not" if not calm.contains("CONVERTED") else "IT DOES TOO", names.size(),
		"yes" if names == by_name else "NO: " + ",".join(names.slice(0, 4))],
		names == by_name and names.size() >= 20
		and not back.is_empty() and derived and float(b.get("radius")) == CellBody.DIVIDE_RADIUS
		and inside and float(b.get("hunger")) == 0.625 and int(done.get("trimmed", 0)) == 1
		and int(done.get("contained", 0)) >= 1 and line.contains("CONVERTED")
		and not calm.contains("CONVERTED"))
	field2.queue_free()
	cell2.free()


## A run of the game that keeps its drop at [constant KEEP], in point of view.
func _kept_run() -> Node:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 0)
	run.set("scheme", 0)
	run.set("keep", KEEP)
	add_child(run)
	return run


## A run's cell as the drop keeps it, read off its nodes -- its record of
## descent among them (lineage.md §4).
func _kept_cell(run: Node) -> Array:
	var met: Node = run.get("_metabolism")
	return [(run.get("_cell") as CellBody).call(&"body_state"),
		(run.get("_genome") as Node).call(&"to_state"), met.get("hunger"),
		met.get("starve_seconds"), run.get("_generation"), run.get("_sense_clock"),
		run.get("_sensed"), (run.get("_food") as Node).call(&"player_state"),
		run.call(&"_record")]


## Whether two divisions offer the same two daughters, side for side: the same
## DNA, layout, body and mutation, to their bytes.
func _same_pair(a: Array, b: Array) -> bool:
	if a.size() != 2 or b.size() != 2:
		return false
	for side in 2:
		for key: String in ["tiers", "order", "body", "mutation"]:
			if var_to_bytes(a[side][key]) != var_to_bytes(b[side][key]):
				return false
	return true


## [param fields] of [param object], in order.
func _row(object: Object, fields: Array) -> Array:
	var out := []
	for name: String in fields:
		out.append(object.get(name))
	return out


## Nothing of these checks left in `user://`.
func _forget_kept() -> void:
	for path: String in [KEEP, KEEP + ".old", KEEP.get_basename() + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(KEEP.get_base_dir()):
		DirAccess.remove_absolute(KEEP.get_base_dir())


# --- Lineage (docs/design/lineage.md §11.3: pack 2's checks 8, 9 and 10, as 2-1 has them) --

## **A body's lineage and the body beside it**, read off the body itself: what
## pack 2 keeps of every body, and what it wears.
const LINEAGE_FIELDS: Array[String] = ["id", "parent", "generation", "lineage", "grace", "dna",
	"genome"]


## **lineage 8, the save: the bodies** (§4). Twenty seconds of a drop, then a
## sister left in it -- wearing less than she carries, a gene this build does
## not know among what she carries, the child of a record three generations
## deep in a line that is not her mother's id -- and a body posed mid-grace: its
## grace a countdown 32 bits cannot hold, its DNA its body's genes in another
## order, which a mutation draws by, and a record of its own. Through the file's
## whole path and into a field of its own, every body's id, parent, generation,
## line, grace, DNA and body come back to the bit, and the file's DNA column is
## empty but for those two, the only bodies whose DNA is not their body. **A 1b
## file** -- the same drop without the four columns, nobody anybody's daughter
## -- is read, and every body comes back a founder: generation 1, its own line,
## its DNA its body, no grace. **And a column that does not hold what it says**
## -- one entry short, a DNA that is not gene names to copies, a grace in 32
## bits -- makes the file unreadable, never half-loaded.
func _save_lineage() -> void:
	var water := _water(0.0, 0.6)
	var field: WatchedDrop = water[0]
	for f in 20 * 60:
		field._process(1.0 / 60.0)
	var mother := Descent.of(field.take_id(), 4242, 3, 77)
	field.put_sister(PI * 0.5, 560.0, CellBody.daughter_radius(),
		{&"cytostome": 1, &"flagellum": 1},
		{&"cytostome": 2, &"flagellum": 1, &"chemocyte": 3, &"kinety": 1}, mother)
	var sister := field.last_spawned
	var at: Vector2 = field.basin().get(&"center") + Vector2(900.0, 0.0)
	var posed := _pose(field, at, 30.0, {&"cytostome": 2, &"rhabdom": 2, &"myoneme": 1})
	var b: Object = (field.get("_cells") as Array)[posed]
	for value: Array in [["grace", 42.0 - 61.0 / 60.0], ["generation", 9], ["lineage", 31],
			["parent", 17], ["dna", {&"rhabdom": 2, &"myoneme": 1, &"cytostome": 2}]]:
		b.set(value[0], value[1])
	var data := DropSave.compose(field.drop_state(), {})
	var wrote := DropSave.write(KEEP, data)
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	var field2 := WatchedDrop.new()
	field2.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(field2)
	if not back.is_empty():
		field2.load_drop(cell2, back["drop"])
	var ours: Array = field.get("_cells")
	var theirs: Array = field2.get("_cells")
	var kept := 0
	var differ := 0
	for i in mini(ours.size(), theirs.size()):
		if not bool(ours[i].get("seeded")):
			continue
		kept += 1
		if not bool(theirs[i].get("seeded")) or var_to_bytes(_row(ours[i], LINEAGE_FIELDS)) \
				!= var_to_bytes(_row(theirs[i], LINEAGE_FIELDS)):
			differ += 1
	var carried := 0
	for one: Dictionary in data["drop"]["bodies"]["dna"]:
		carried += 0 if one.is_empty() else 1
	var her: Object = theirs[sister] if sister < theirs.size() else null
	var daughter := her != null and int(her.get("parent")) == mother[Descent.ID] \
		and int(her.get("generation")) == 4 and int(her.get("lineage")) == 77 \
		and int((her.get("dna") as Dictionary).get(&"kinety", 0)) == 1 \
		and (her.get("genome") as Dictionary).size() == 2
	field2.queue_free()
	cell2.free()
	# **The same drop as 1b wrote it**: no lineage, and nobody anybody's daughter.
	var old := DropSave.compose(field.drop_state(), {})
	var rows: Dictionary = old["drop"]["bodies"]
	for key: String in DropSave.LINEAGE:
		rows.erase(key)
	var nobody := PackedInt32Array()
	nobody.resize((rows["parent"] as PackedInt32Array).size())
	rows["parent"] = nobody
	var wrote_old := DropSave.write(KEEP, old)
	var back_old := DropSave.read(KEEP)
	var cell3 := CellBody.new()
	var field3 := WatchedDrop.new()
	field3.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(field3)
	if not back_old.is_empty():
		field3.load_drop(cell3, back_old["drop"])
	var founders := 0
	var others := 0
	for one: Object in field3.get("_cells"):
		if not bool(one.get("seeded")):
			continue
		if int(one.get("generation")) == 1 and int(one.get("lineage")) == int(one.get("id")) \
				and int(one.get("parent")) == 0 and float(one.get("grace")) == 0.0 \
				and var_to_bytes(one.get("dna")) == var_to_bytes(one.get("genome")):
			founders += 1
		else:
			others += 1
	field3.queue_free()
	cell3.free()
	# **And three columns that do not hold what they say.**
	var whys := PackedStringArray()
	for spoil in 3:
		var spoilt := DropSave.compose(field.drop_state(), {})
		var columns: Dictionary = spoilt["drop"]["bodies"]
		match spoil:
			0:
				var short: PackedInt32Array = columns["generation"]
				short.resize(short.size() - 1)
				columns["generation"] = short
			1:
				(columns["dna"] as Array)[0] = {"cytostome": "two"}
			2:
				columns["grace"] = PackedFloat32Array(Array(columns["grace"]))
		var why := DropSave.unusable(spoilt)
		whys.append(why if not why.is_empty() else "READ")
	_done(water)
	_check(("lineage 8. the save, the bodies: %d written (%s) and loaded into a field of their"
		+ " own, %d differing in id, parent, generation, line, grace, DNA or body, to the bit;"
		+ " the DNA column carries %d, the rest the body's own; the sister back as generation"
		+ " 4 of line 77, her mother's id her parent, carrying a gene this build does not"
		+ " know (%s); a 1b file without the columns (%s) loads %d bodies as founders and %d"
		+ " not; spoilt, the file is unreadable: %s") % [kept, error_string(wrote), differ,
		carried, str(daughter), error_string(wrote_old), founders, others, "; ".join(whys)],
		wrote == OK and not back.is_empty() and ours.size() == theirs.size() and differ == 0
		and kept > 500 and carried == 2 and daughter and wrote_old == OK
		and not back_old.is_empty() and founders == kept and others == 0
		and not whys.has("READ"))


## **lineage 8, the save: your cell** (§4). A run's first cell is generation 1,
## nobody's daughter and the first of its own line, numbered by its drop's
## count; left mid-run with a record three generations deep and opened again,
## it comes back with that record; **and a cell kept before pack 2**, without
## one, comes back with one started from the drop's count -- a line of its own,
## at the generation it had, which the player has seen. A cell whose id is not
## a number makes the file unreadable.
func _save_cell_lineage() -> void:
	var run := _kept_run()
	var food: Node = run.get("_food")
	var first: PackedInt32Array = run.call(&"_record")
	var count := int(food.get("_next_id"))
	var clash := false
	for b: Object in food.get("_cells"):
		if bool(b.get("seeded")) and int(b.get("id")) == first[Descent.ID]:
			clash = true
	var founded := first == Descent.founder(count - 1) and count > 500 and not clash
	run.set("_generation", 5)
	run.set("_parent", 4242)
	run.set("_lineage", 77)
	var was: PackedInt32Array = run.call(&"_record")
	run.notification(NOTIFICATION_APPLICATION_PAUSED)
	var kept := DropSave.read(KEEP)
	run.queue_free()
	await get_tree().process_frame
	var again := _kept_run()
	var back: PackedInt32Array = again.call(&"_record")
	again.queue_free()
	await get_tree().process_frame
	# **The same file as pack 1 kept it**: no record on the cell, no lineage on
	# the bodies.
	var old: Dictionary = kept.duplicate(true)
	if not old.is_empty():
		for key: String in DropSave.CELL_LINEAGE:
			(old["cell"] as Dictionary).erase(key)
		for key: String in DropSave.LINEAGE:
			(old["drop"]["bodies"] as Dictionary).erase(key)
	var wrote := DropSave.write(KEEP, old)
	var next := int(old.get("drop", {}).get("next_id", -1))
	var older := _kept_run()
	var started: PackedInt32Array = older.call(&"_record")
	var resumed := bool(older.get("_resumed"))
	older.queue_free()
	await get_tree().process_frame
	var bad: Dictionary = kept.duplicate(true)
	if not bad.is_empty():
		bad["cell"]["id"] = "seven"
	var why := DropSave.unusable(bad)
	_check(("lineage 8. the save, your cell: a run's first is %s -- the drop's next id, nobody's,"
		+ " generation 1, its own line (%s); left as %s and opened again it is %s; kept"
		+ " before pack 2 (%s) it comes back %s (%s), a line of its own from the drop's next"
		+ " id, %d, at the generation it had; an id that is not a number: %s") % [str(first),
		str(founded), str(was), str(back), error_string(wrote), str(started),
		"resumed" if resumed else "NOT RESUMED", next, why if not why.is_empty() else "READ"],
		founded and not kept.is_empty() and back == was and wrote == OK and resumed
		and started == Descent.of(next, 0, 5, next) and not why.is_empty())


## **lineage 9, the sister** (§4, §11.3 check 9). A run in its drop, its cell
## three generations deep in a line that is not its own id, divides by the
## game's own birth (`_be_born`), handed two daughters -- the declined one
## wearing less than she carries -- and the sister left in the water wears the
## declined daughter's body and carries her DNA, and is the child of the cell
## both divided from: its id her parent, its generation and one, its line. The
## daughter you become has that same record and an id of her own, neither of
## them any body's. **In a pond** the host's sister is the same, and a guest's,
## whom SISTER brings with what she wears and nothing more, is the founder of a
## line of her own, carrying what she wears.
func _sister_lineage() -> void:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 0)
	run.set("scheme", 0)
	run.set("keep", "")
	add_child(run)
	var food: Node = run.get("_food")
	run.set("_generation", 3)
	run.set("_parent", 4242)
	run.set("_lineage", 77)
	var mother: PackedInt32Array = run.call(&"_record")
	var declined := {"tiers": {&"cytostome": 2, &"cirrus": 1, &"flagellum": 1, &"chemocyte": 2},
		"order": [&"cytostome", &"cirrus", &"flagellum", &"chemocyte"],
		"body": {&"cytostome": 2, &"flagellum": 1}, "mutation": &"trade"}
	var chosen := {"tiers": {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1},
		"order": [&"cytostome", &"cirrus", &"flagellum"],
		"body": {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, "mutation": &""}
	run.set("_daughters", [chosen, declined])
	run.set("_chosen", 0)
	run.call(&"_be_born")
	var you: PackedInt32Array = run.call(&"_record")
	var ids := {}
	var sisters: Array[Object] = []
	for b: Object in food.get("_cells"):
		if not bool(b.get("seeded")):
			continue
		ids[int(b.get("id"))] = true
		if not bool(b.get("inert")) and int(b.get("parent")) == mother[Descent.ID]:
			sisters.append(b)
	var her: Object = sisters[0] if sisters.size() == 1 else null
	var hers := Descent.of(int(her.get("id")), int(her.get("parent")),
		int(her.get("generation")), int(her.get("lineage"))) if her != null \
		else PackedInt32Array()
	var wears := her != null and var_to_bytes(her.get("genome")) == var_to_bytes(declined["body"])
	var carries := her != null and var_to_bytes(her.get("dna")) == var_to_bytes(declined["tiers"])
	var child := Descent.child(you[Descent.ID], mother)
	var yours_right := you == child and you[Descent.ID] != mother[Descent.ID] \
		and not ids.has(you[Descent.ID])
	var hers_right := her != null and hers == Descent.child(hers[Descent.ID], mother) \
		and hers[Descent.ID] != you[Descent.ID] and hers[Descent.ID] != mother[Descent.ID]
	run.queue_free()
	await get_tree().process_frame
	# **In a pond**: the host's own sister, and a guest's from the wire.
	var water := _water()
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	field.open_pond()
	field.put_sister(PI * 0.5, 560.0, CellBody.daughter_radius(), declined["body"],
		declined["tiers"], mother)
	var cells: Array = field.get("_cells")
	var host: Object = cells[field.last_spawned]
	var host_right := bool(field.pond_open()) and int(host.get("parent")) == mother[Descent.ID] \
		and int(host.get("generation")) == mother[Descent.GENERATION] + 1 \
		and int(host.get("lineage")) == mother[Descent.LINEAGE] \
		and var_to_bytes(host.get("dna")) == var_to_bytes(declined["tiers"])
	var slot: int = field.place_sister(cell.position + Vector2(-560.0, 0.0), 0.0,
		CellBody.daughter_radius(), declined["body"])
	var guest: Object = cells[slot] if slot >= 0 else null
	var guest_right := guest != null and int(guest.get("parent")) == 0 \
		and int(guest.get("generation")) == 1 and int(guest.get("lineage")) == int(guest.get("id")) \
		and var_to_bytes(guest.get("dna")) == var_to_bytes(guest.get("genome")) \
		and var_to_bytes(guest.get("genome")) == var_to_bytes(declined["body"])
	_done(water)
	_check(("lineage 9. the sister: of %s, the cell you were, you are %s (%s) and she is %s (%s),"
		+ " %d of her; she wears the declined daughter's body (%s) and carries her DNA (%s);"
		+ " in a pond the host's sister is the same (%s), and a guest's, from SISTER, the"
		+ " founder of a line of her own carrying what she wears (%s)") % [str(mother), str(you),
		str(yours_right), str(hers), str(hers_right), sisters.size(), str(wears), str(carries),
		str(host_right), str(guest_right)],
		sisters.size() == 1 and yours_right and hers_right and wears and carries and host_right
		and guest_right)


## The sister the identity gate leaves (lineage 10): what she wears, and -- on
## a build that keeps it -- what she carries besides.
const IDENTITY_BODY := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}
const IDENTITY_DNA := {&"cytostome": 2, &"cirrus": 1, &"flagellum": 1, &"chemocyte": 1}
## **`dev`'s census lines** for [method _identity_lines]' scenario, recorded on
## `dev` at 7f06cf7 -- pack 1, the commit pack 2 began from -- in this project's
## container (Godot 4.7.2, Ubuntu 24.04, glibc 2.39, x86-64), which is what CI
## runs on. **A rule of the drop changed on purpose changes them**: re-record
## them then from this check's own output, which prints both sides of a line
## that differs -- and say so in the commit, because that is the change.
const IDENTITY_LINES: Array[String] = [
	"[census] t 30  living 531 (drifters 437, hunters 94)  flocs 31  | hunters at r40 11, mean r 30.8, hunger 0.51  | could swallow r26/r34/r40 44/15/11  dread 0.78/0.40/0.26  genes 16  | spawned 663  died: swallowed 127 chewed 0 starved 5 (r40 0) poisoned 0  | grazed by the water 5, by drifters 0, dissolved 0, snow kept 1, remains 5  | runs 273 at you 0 misses 132 darts 1 dashes 20  floors: gene 0+0 drifter 0  | sum 2919193787",
	"[census] t 60  living 532 (drifters 439, hunters 93)  flocs 43  | hunters at r40 31, mean r 32.9, hunger 0.45  | could swallow r26/r34/r40 56/19/16  dread 0.87/0.40/0.24  genes 16  | spawned 832  died: swallowed 271 chewed 2 starved 27 (r40 1) poisoned 0  | grazed by the water 16, by drifters 0, dissolved 0, snow kept 2, remains 27  | runs 534 at you 0 misses 250 darts 5 dashes 50  floors: gene 0+0 drifter 0  | sum 642420395",
	"[census] t 30  living 506 (drifters 322, hunters 184)  flocs 40  | hunters at r40 20, mean r 30.5, hunger 0.45  | could swallow r26/r34/r40 116/44/27  dread 1.82/0.72/0.46  genes 16  | spawned 773  died: swallowed 249 chewed 2 starved 16 (r40 0) poisoned 0  | grazed by the water 11, by drifters 0, dissolved 0, snow kept 5, remains 16  | runs 508 at you 0 misses 217 darts 9 dashes 11  floors: gene 0+0 drifter 0  | sum 3550468869",
	"[census] t 60  living 509 (drifters 325, hunters 184)  flocs 46  | hunters at r40 58, mean r 32.5, hunger 0.50  | could swallow r26/r34/r40 123/63/52  dread 2.30/1.14/0.72  genes 16  | spawned 1077  died: swallowed 517 chewed 3 starved 48 (r40 3) poisoned 0  | grazed by the water 40, by drifters 1, dissolved 0, snow kept 9, remains 48  | runs 1085 at you 0 misses 509 darts 12 dashes 39  floors: gene 0+0 drifter 0  | sum 1127331418",
	"[census] t 30  living 543 (drifters 499, hunters 44)  flocs 38  | hunters at r40 3, mean r 30.2, hunger 0.50  | could swallow r26/r34/r40 21/2/0  dread 0.30/0.04/0.00  genes 16  | spawned 605  died: swallowed 57 chewed 0 starved 5 (r40 0) poisoned 0  | grazed by the water 0, by drifters 0, dissolved 0, snow kept 3, remains 5  | runs 124 at you 0 misses 68 darts 2 dashes 0  floors: gene 0+2 drifter 0  | sum 2851272202",
]


## **lineage 10, the identity gate** (§11.2, §11.3 check 10): with nothing
## dividing, the drop's census lines are `dev`'s to the byte on the same seeds
## -- the same population, the same deaths and meals, and the same sum of every
## body's place, size and tank -- so a player can notice nothing of 2-1.
func _identity() -> void:
	var lines := _identity_lines()
	seed(20260930)
	var differ := 0
	for k in maxi(lines.size(), IDENTITY_LINES.size()):
		var ours: String = lines[k] if k < lines.size() else "(none)"
		var theirs: String = IDENTITY_LINES[k] if k < IDENTITY_LINES.size() else "(none)"
		if ours != theirs:
			differ += 1
			print("[drop-probe] lineage 10, line %d, this build: %s" % [k + 1, ours])
			print("[drop-probe] lineage 10, line %d, dev:        %s" % [k + 1, theirs])
	var sums := PackedStringArray()
	for line in lines:
		sums.append(line.get_slice("| sum ", 1))
	_check(("lineage 10. the identity gate: with nothing dividing, %d census lines -- a newborn's"
		+ " drop and a sighted player's, 60 s each, and the empty room, 30 s -- with your id"
		+ " taken from the drop's count and a sister carrying more than she wears, against"
		+ " dev's on the same seeds: %s (sums %s)") % [lines.size(),
		"the same to the byte" if differ == 0 else "%d DIFFER" % differ, ", ".join(sums)],
		differ == 0 and lines.size() == 5)


## **The identity gate's scenario** (lineage 10): a newborn's drop and a sighted
## player's, each from its own seed, 60 s with a census every 30 s, and the
## server's empty room from a third, 30 s. Your cell takes its id from the
## drop's count first, which moves every id after it, and 30 s in a sister is
## left wearing [constant IDENTITY_BODY] and carrying [constant IDENTITY_DNA],
## the child of your record. `dev` ran it with neither -- no id taken, and a
## sister who was her body and nothing more -- so neither may move a thing.
func _identity_lines() -> Array[String]:
	var lines: Array[String] = []
	for each: Array in [[1, 0.2], [2, 0.6]]:
		seed(int(each[0]))
		var cell := CellBody.new()
		cell.radius = CellBody.BASE_RADIUS
		var field := FoodField.new()
		field.process_mode = Node.PROCESS_MODE_DISABLED
		field.sensed_override = float(each[1])
		add_child(field)
		field.setup_drop(cell)
		field.in_water = false
		var yours := Descent.founder(field.take_id())
		for f in 60 * 60:
			field._process(1.0 / 60.0)
			if f == 30 * 60 - 1:
				field.put_sister(PI * 0.5, 560.0, CellBody.daughter_radius(), IDENTITY_BODY,
					IDENTITY_DNA, yours)
			if f % (30 * 60) == 30 * 60 - 1:
				lines.append(field.census_line())
		field.free()
		cell.free()
	seed(3)
	var nobody := CellBody.new()
	var room := FoodField.new()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(room)
	room.open_dedicated(nobody)
	for f in 30 * 60:
		room._process(1.0 / 60.0)
	lines.append(room.census_line())
	room.free()
	nobody.free()
	return lines


# --- The dev app's frame readout (§14.1, §14.2) -------------------------------------------

## Posed as a release build it adds nothing; posed as the dev app it seats its
## stopwatch either side of the water, reads it, steps aside when the water
## stops or the pause page is up, and comes back after. And what the phone gate
## reads, on its own: which frames were dropped, at the rate the game is held to.
func _readout() -> void:
	# A steady 60 Hz phone's own jitter drops nothing, and a frame the display
	# showed twice is dropped. A faster display is held to 60 -- the game has no
	# frame cap -- so a 120 Hz phone at a steady 60 drops nothing either; a
	# slower one is held to its own rate, and one that will not say is taken at 60.
	var at_60 := FrameReadout.dropped(PackedFloat32Array([16.6, 16.8, 17.2, 24.9, 25.1,
		33.3]), 60.0)
	var steady_120 := FrameReadout.dropped(PackedFloat32Array([16.5, 16.7, 16.7, 16.9,
		17.2, 8.3]), 120.0)
	var hitch_120 := FrameReadout.dropped(PackedFloat32Array([16.7, 16.7, 16.7, 33.3]),
		120.0)
	var at_50 := FrameReadout.dropped(PackedFloat32Array([20.0, 20.1, 29.9, 30.1]), 50.0)
	var silent := FrameReadout.dropped(PackedFloat32Array([16.7, 30.0]), -1.0)
	var rates := [FrameReadout.usable_rate(-1.0), FrameReadout.usable_rate(0.0),
		FrameReadout.usable_rate(50.0), FrameReadout.usable_rate(144.0)]
	_check(("a frame is dropped past %.1f periods: 2 of 6 at 60 Hz, jitter included"
		+ " (%.1f %%); a 120 Hz display at a steady 60 drops %.1f %%, and 1 hitch in 4"
		+ " is %.1f %%; at 50 Hz 1 of 4 (%.1f %%); a display that says no rate is held"
		+ " to %s Hz (%.1f %%); held to %s; nothing to count, %.0f")
		% [FrameReadout.DROPPED_AFTER, at_60, steady_120, hitch_120, at_50, str(rates[0]),
		silent, str(rates), FrameReadout.dropped(PackedFloat32Array(), 60.0)],
		absf(at_60 - 100.0 / 3.0) < 1e-4 and steady_120 == 0.0
		and absf(hitch_120 - 25.0) < 1e-4 and absf(at_50 - 25.0) < 1e-4
		and absf(silent - 50.0) < 1e-4 and rates == [60.0, 60.0, 50.0, 60.0]
		and FrameReadout.dropped(PackedFloat32Array(), 60.0) == -1.0)
	# A figure keeps to four glyphs by dropping decimals, so the number column
	# keeps one width whatever the frame does.
	var shown := [FrameReadout.figure(100.0, 1), FrameReadout.figure(99.94, 1),
		FrameReadout.figure(0.534, 2), FrameReadout.figure(12.345, 2),
		FrameReadout.figure(8.26, 1), FrameReadout.figure(1234.56, 1)]
	var widest := 0
	for i in 2000:
		var value := pow(10.0, randf_range(-3.0, 3.99))
		for decimals in [1, 2]:
			widest = maxi(widest, FrameReadout.figure(value, decimals).length())
	_check("a figure keeps to %d glyphs: %s, and the widest of 4,000 below 9,773 takes %d"
		% [FrameReadout.FIGURE_GLYPHS, str(shown), widest],
		shown == ["100", "99.9", "0.53", "12.3", "8.3", "1235"] and widest == 4)
	var host := Node.new()
	add_child(host)
	var water := BusyWater.new()
	host.add_child(water)
	# Whether the pause page is up, as normal_mode.gd answers it.
	var page := [false]
	var covered := func() -> bool: return page[0]
	FrameReadout.posing = ""
	var released := FrameReadout.attach(host, water, covered)
	var alone := host.get_child_count()
	FrameReadout.posing = "dev"
	var readout := FrameReadout.attach(host, water, covered)
	FrameReadout.posing = null
	_check("a release build adds nothing (%d node, readout %s); the dev app adds its table"
		% [alone, released] + " and seats a hand either side of the water (%s | %s)" % [
		_named(host, water.get_index() - 1), _named(host, water.get_index() + 1)],
		released == null and alone == 1 and readout != null
		and _named(host, water.get_index() - 1) == "FrameReadoutOpen"
		and _named(host, water.get_index() + 1) == "FrameReadoutClose")
	if readout == null:
		host.queue_free()
		return
	for i in 40:
		await get_tree().process_frame
	var rows: Array = readout.call(&"_figures")
	var named := []
	for row: Array in rows:
		named.append(row[0])
	var water_ms := float(rows[3][1]) if rows[3][1] != "–" else -1.0
	_check(("over 40 frames it reads, row by row %s: a frame of %s ms (p95 %s), %s %s"
		+ " dropped, the water's %s ms of at least %.2f, and %s bodies stepped of the 3"
		+ " living") % [str(named), rows[0][1], rows[1][1], rows[2][1], rows[2][2],
		rows[3][1], BusyWater.BUSY_USEC / 1000.0, rows[4][1]],
		named == ["frame", "p95", "dropped", "water", "stepped"] and rows[0][1] != "–"
		and rows[1][1] != "–" and rows[2][1].is_valid_float()
		and String(rows[2][2]).begins_with("%")
		and water_ms >= BusyWater.BUSY_USEC / 1000.0 and water_ms < 50.0
		and rows[4][1] == "3")
	water.set_process(false)
	for i in 3:
		await get_tree().process_frame
	var stopped: bool = readout.visible
	water.set_process(true)
	for i in 3:
		await get_tree().process_frame
	_check("it steps aside while the water stands still (%s) and is back when it runs (%s)"
		% ["shown" if stopped else "hidden", "shown" if readout.visible else "hidden"],
		not stopped and readout.visible)
	# **The pause page**: hidden while it is up, and nothing under it counted --
	# not a frame, not the water, which in a pond runs on under the page, and not
	# the gap it leaves. Its frames are made slow here, 30 ms each: counted, they
	# would show. The window's clock stands still with them.
	var frames_before: PackedFloat32Array = readout.call(&"frames_now")
	var water_before: PackedFloat32Array = readout.call(&"water_now")
	var played_before: int = readout.get(&"_played")
	page[0] = true
	var shown_under := 0
	for i in 20:
		await get_tree().process_frame
		if readout.visible:
			shown_under += 1
		OS.delay_msec(30)
	var frames_under: PackedFloat32Array = readout.call(&"frames_now")
	var water_under: PackedFloat32Array = readout.call(&"water_now")
	var played_under: int = readout.get(&"_played")
	page[0] = false
	for i in 12:
		await get_tree().process_frame
	var back: bool = readout.visible
	var after: PackedFloat32Array = readout.call(&"frames_now")
	var played_after: int = readout.get(&"_played")
	var summed := 0.0
	for ms: float in after:
		summed += ms
	# And a tree stopped under it, as the page stops it in single player.
	get_tree().paused = true
	for i in 5:
		await get_tree().process_frame
	var hidden_paused: bool = not readout.visible
	var frames_paused: int = readout.call(&"frames_now").size()
	get_tree().paused = false
	for i in 5:
		await get_tree().process_frame
	_check(("the pause page hides it (shown on %d of 20 frames under it) and it is back"
		+ " when the page closes (%s); under the page %d frames and %d water times"
		+ " counted and its clock moved %d µs; after it the slowest frame in the window"
		+ " is %.1f ms and the clock is the frames it counted, %.1f against %.1f ms; a"
		+ " stopped tree hides it too (%s) and counts nothing (%d)") % [shown_under,
		"shown" if back else "hidden", frames_under.size() - frames_before.size(),
		water_under.size() - water_before.size(), played_under - played_before,
		after[after.size() - 1] if not after.is_empty() else -1.0,
		float(played_after) / 1000.0, summed, "yes" if hidden_paused else "no",
		frames_paused - after.size()],
		shown_under == 0 and back and frames_under.size() == frames_before.size()
		and water_under.size() == water_before.size() and played_under == played_before
		and after.size() >= frames_under.size() + 5 and not after.is_empty()
		and after[after.size() - 1] < 30.0
		and absf(float(played_after) / 1000.0 - summed) < 0.5
		and hidden_paused and frames_paused == after.size())
	host.queue_free()
	await get_tree().process_frame


func _named(parent: Node, index: int) -> String:
	if index < 0 or index >= parent.get_child_count():
		return "nothing"
	return String(parent.get_child(index).name)


# --- Geometry the slow way --------------------------------------------------------------

func _anywhere(c: Vector2, half: float) -> Vector2:
	return c + Vector2(randf_range(-half, half), randf_range(-half, half))


func _dist(a: Vector2, b: Vector2) -> float:
	return _dist_to(a.x, a.y, b)


func _dist_to(x: float, y: float, b: Vector2) -> float:
	var dx := x - b.x
	var dy := y - b.y
	return sqrt(dx * dx + dy * dy)
