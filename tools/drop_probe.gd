extends Node
## CI probe: **the drop** (docs/design/ocean.md §14.3). The mechanics a finite
## water is built on -- the grid, the basin, the replenisher, the snowfall --
## against brute force and against their own arithmetic; the drop's own
## decisions, each on its own; and one tank for every body: the player's
## metabolism node against the static functions the water will call.
##
## Phase 1a-1 builds checks 1, 2, 7 and 10's identity, and the replenish and
## snow arithmetic. Checks 3 to 6, 8, 9 and 11 need the drop in the water and
## come with it in 1a-2; 12 is 1b's save. **And the dev app's frame readout** (§14.2), run
## for real: CI runs release-stamped, so nothing else here ever runs its frames.
##
## **Every check here fails with its fix taken out**, and was shown to by
## mutation when it was written: a grid that forgets the edge buckets stand for
## everything past them, a basin that puts a body back on the rim in 32 bits
## without pulling it inside, a replenisher whose debt outgrows its shortfall, a
## Poisson draw cut off at 64, a node that works out its own rate.
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

## Somewhere other than the origin, as the drop is once a run has started in it.
const OFF_CENTRE := Vector2(-1234.5, 2345.25)

var _failed := 0


## **A water body's tank, as the drop will keep one** (§5.2): stepped at
## whatever rate its distance gives it, with the time it is owed, paying what
## it did since it was last stepped -- through the same static functions the
## player's node calls.
class Tank:
	var hunger := 0.0
	var effort := 0.0
	var upkeep := 1.0
	var income := 0.0
	var reserve := 1.0
	var burn := 1.0

	func step(dt: float) -> void:
		hunger = clampf(hunger
			+ dt * Metabolism.rest_rate(upkeep, income, reserve) / Metabolism.HUNGER_SECONDS
			+ Metabolism.effort_cost(effort, burn, reserve), 0.0, 1.0)
		effort = 0.0

	func eat(nutrition: float) -> void:
		hunger = clampf(hunger - Metabolism.meal(nutrition), 0.0, 1.0)


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


func _ready() -> void:
	seed(20260930)
	_grid()
	_basin()
	_replenish()
	_snowfall()
	_drop()
	_lod()
	_tank()
	await _readout()
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
## frame at a time as the run steps it, the water body at the rates its
## distance would give it: every frame, then every second frame, then on its
## tick, with the time it is owed.
func _tank() -> void:
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
		var tank := Tank.new()
		tank.hunger = 0.3
		tank.upkeep = met.upkeep
		tank.income = met.photosynthesis
		tank.reserve = met.reserve
		tank.burn = met.burn
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
			tank.effort += effort
			# A meal every ten seconds, worth three fifths of what is missing, so
			# neither tank is ever pinned at empty or at full: a pinned tank
			# would agree with anything.
			var meal := f > 0 and f % 600 == 0
			var every := 1 if f < 1200 else (2 if f < 2400 else Drop.LOD_EVERY)
			if f % every == every - 1 or meal or f == frames - 1:
				tank.step(float(f - last) * dt)
				last = f
			if meal:
				var nutrition := 0.6 * float(met.hunger) / Metabolism.MEAL
				met.feed(nutrition)
				tank.eat(nutrition)
			low = minf(low, met.hunger)
			high = maxf(high, met.hunger)
		worst = maxf(worst, absf(float(met.hunger) - tank.hunger))
		met.free()
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
