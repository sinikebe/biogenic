extends SceneTree
## **The single-player identity gate's differential half** (shared-pond.md §5):
## a reference `food.gd` -- `main`'s -- beside this build's, stepped from
## identical adversarial water with the global stream reseeded identically
## before every call, compared after each on every `Body` member both have, the
## field's carried state, the cell, the signal log and the next `randi()`.
## With no pond opened the two must agree to the bit.
##
##   git show main:game/normal/food.gd > /tmp/food_main.gd
##   godot --headless --path . -s res://tools/field_diff.gd -- \
##       --old=/tmp/food_main.gd [--trials=4000] [--long=150] [--frames=600]
##
## The fingerprint (`drive.gd --fingerprint=`) holds a whole run to the bit;
## this holds every function to it on water no run would make -- NaN and
## infinite radii, a NaN place, a whale, a pack of wounded bodies, a cell that
## grows mid-pass because its `eaten` handler grows it, as the run's does. That
## is the half that catches a bound that skips a real contact once in ten
## thousand pairs: measured on this file's own pre-checks, dropping the water
## pass's rebuild failed 5 of 45,858 checks, and dropping the water's mouth from
## the players' bound failed 818.
##
## Per trial: `setup()` itself, the contact pass and separation on the
## untouched water, the prey search of every body at five reaches, one reseed,
## the solo sister, and whole frames. Prints `[field-diff] ALL EQUAL` or
## `[field-diff] MISMATCH` with the first differing entry. Excluded from export
## (`tools/*` on both presets), so none of it ships.
##
## **And a phone's pond, the same way** (`--pond=`, `--pond-long=`): the two
## fields opened as a pond with **one person** in it -- a phone host and its
## guest -- on two waters' worth of adversarial bodies, the person posed,
## armed, venomous or not and often within a mouth of this cell, and then the
## contact pass, separation, every prey search, the recycle, both snapshots,
## both sisters, the person's lifecycle calls and whole frames with the person
## re-reported every third one, as a guest's state frames do; then a mirror of
## that water on each side, fed the same snapshots. Compared on everything
## above plus the pond's own members, every person's record and both person
## signals. This is what holds a change that teaches the field a *second*
## person (the dedicated host, `game/server/`) to leaving the one-person pond
## exactly as it was: the same calls, the same bits, the same draws.

var NewFood: GDScript = null
var OldFood: GDScript = null
const NewCell := preload("res://game/normal/cell.gd")

const BODY_KEYS: Array[StringName] = [
	&"pos", &"heading", &"radius", &"genome", &"drifter", &"seeded", &"serial",
	&"meals", &"wound", &"bite", &"state", &"target", &"target_serial",
	&"calm", &"stale", &"flee_from", &"aim", &"aim_clock", &"lost", &"rush",
	&"best", &"lunging", &"break_clock", &"stroke", &"wander"]
const FIELD_KEYS: Array[StringName] = [
	&"concentration", &"dread_level", &"threat", &"shadow", &"shadow_bearing",
	&"taste_level", &"touch_level", &"touch_bearing", &"beams", &"pings",
	&"ping_fronts", &"ping_echoes", &"ping_listen", &"_echoes", &"_pulses",
	&"_ping_clock", &"_ping_age", &"_dart_clock", &"_bite_clock",
	&"_first_pending", &"_first_hunt", &"_serial"]
const CELL_KEYS: Array[StringName] = [&"position", &"heading", &"velocity",
	&"radius", &"wound", &"steer"]
const KINDS := ["plain", "nan_radius", "inf_radius", "nan_pos", "nan_unseeded",
	"whale", "tiny", "wounded_pack", "growing"]

## What a genome node answers, for a cell nobody built a genome for.
class StubGenome extends Node:
	var t := {}

	func tier(g: StringName) -> int:
		return int(t.get(g, 0))

	func tiers() -> Dictionary:
		return t

var fails := 0
var checks := 0
var shown := 0
var events := {}
var old_food: Node
var new_food: Node
var old_cell: Node
var new_cell: Node
var old_log: Array = []
var new_log: Array = []
## The run's _on_eaten, on both sides, only in "growing" trials.
var growing := false
## True while the pond trials run: [method _snap] reads the pond's members too.
var pond_mode := false

## What the pond adds to a body, and to the field, and what a person is.
const POND_BODY_KEYS: Array[StringName] = [&"speed", &"order", &"tuned"]
const PERSON_KEYS: Array[StringName] = [&"at", &"facing", &"launch", &"turning",
	&"age", &"velocity", &"swim_speed", &"armour", &"dart_range", &"dart_cooldown",
	&"dart_bearing", &"dart_clock", &"venom_cost", &"first_hunt", &"in_water",
	&"quiet"]
const POND_FIELD_KEYS: Array[StringName] = [&"in_water", &"anchored", &"died_of",
	&"died_by", &"_pond", &"_mirror", &"_water", &"_changes", &"_seeded_for",
	&"_stamp", &"_anchor_ids", &"_anchor_at", &"_snap_at", &"_snap_age", &"_book",
	&"smell_bearing", &"ping_bearing", &"dart_bearing", &"dart_range"]
const PERSON_GENES: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum",
	&"pellicle", &"toxicyst", &"trichocyst", &"axoneme", &"chemocyte", &"ampulla"]


func _initialize() -> void:
	var trials := 4000
	var new_path := "res://game/normal/food.gd"
	var old_path := ""
	var long_trials := 150
	var long_frames := 600
	var first := 0
	var pond_trials := 1500
	var pond_long := 60
	for arg in OS.get_cmdline_user_args():
		var s := str(arg)
		if s.begins_with("--trials="):
			trials = int(s.trim_prefix("--trials="))
		elif s.begins_with("--long="):
			long_trials = int(s.trim_prefix("--long="))
		elif s.begins_with("--new="):
			new_path = s.trim_prefix("--new=")
		elif s.begins_with("--old="):
			old_path = s.trim_prefix("--old=")
		elif s.begins_with("--frames="):
			long_frames = int(s.trim_prefix("--frames="))
		elif s.begins_with("--first="):
			first = int(s.trim_prefix("--first="))
		elif s.begins_with("--pond="):
			pond_trials = int(s.trim_prefix("--pond="))
		elif s.begins_with("--pond-long="):
			pond_long = int(s.trim_prefix("--pond-long="))
	if old_path.is_empty() or (not FileAccess.file_exists(old_path)
			and not ResourceLoader.exists(old_path)):
		print("[field-diff] no reference: pass --old=<main's food.gd>")
		quit(1)
		return
	NewFood = load(new_path)
	OldFood = load(old_path)
	print("[field-diff] this build: ", new_path, "  reference: ", old_path)
	old_food = OldFood.new()
	new_food = NewFood.new()
	old_cell = NewCell.new()
	new_cell = NewCell.new()
	old_cell.genome = StubGenome.new()
	new_cell.genome = StubGenome.new()
	_wire(old_food, old_log, old_cell)
	_wire(new_food, new_log, new_cell)
	for trial in range(first, first + trials):
		_trial(trial, 4)
	for trial in long_trials:
		_trial(100000 + first + trial, long_frames)
	var solo_checks := checks
	pond_mode = true
	for trial in range(first, first + pond_trials):
		_pond_trial(trial, 4)
	for trial in pond_long:
		_pond_trial(100000 + first + trial, long_frames)
	pond_mode = false
	print("[field-diff] solo checks %d, pond checks %d (%d trials, %d of %d frames)"
		% [solo_checks, checks - solo_checks, pond_trials, pond_long, long_frames])
	print("[field-diff] checks %d  fails %d  events %s" % [checks, fails, str(events)])
	print("[field-diff] %s" % ("ALL EQUAL" if fails == 0 else "MISMATCH"))
	for node: Node in [old_food, new_food, old_cell.genome, new_cell.genome,
			old_cell, new_cell]:
		node.free()
	quit(0 if fails == 0 else 1)


func _wire(food: Node, log: Array, cell: Node) -> void:
	food.eaten.connect(func(n: float, g: StringName, at: Vector2) -> void:
		log.append(["eaten", n, g, at])
		# normal_mode.gd's _on_eaten, in miniature: the body grows and the gene
		# goes into what it wears, before the pass looks at the next body.
		if growing:
			cell.radius = minf(cell.radius + NewCell.GROWTH_PER_MEAL,
				NewCell.DIVIDE_RADIUS)
			var tiers: Dictionary = cell.genome.t
			for gene: StringName in [&"pellicle", &"toxicyst", &"cytostome"]:
				tiers[gene] = (int(tiers.get(gene, 0)) + 1) % 4)
	food.waked.connect(func(b: float, s: float) -> void: log.append(["waked", b, s]))
	food.killed.connect(func(b: float) -> void: log.append(["killed", b]))
	food.bitten.connect(func(b: float, s: float) -> void: log.append(["bitten", b, s]))
	food.stung.connect(func(b: float) -> void: log.append(["stung", b]))
	food.darted.connect(func(b: float) -> void: log.append(["darted", b]))
	food.pulsed.connect(func() -> void: log.append(["pulsed"]))
	# The person's two, which only a pond emits: a single-player trial never
	# hears them, so wiring them here changes nothing there.
	food.person_touched.connect(func(what: int, at: Vector2, level: float, by: int,
			gene: StringName) -> void:
		log.append(["person_touched", what, at, level, by, gene]))
	food.person_died.connect(func(cause: int, by: int, at: Vector2) -> void:
		log.append(["person_died", cause, by, at]))



func _make_state(rng: RandomNumberGenerator, kind: String) -> Dictionary:
	var st := {}
	var player := Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-50.0, 50.0))
	var boxes := [30.0, 70.0, 140.0, 300.0, 900.0]
	var box: float = boxes[rng.randi_range(0, boxes.size() - 1)]
	var centre := player + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 1300.0)
	if rng.randf() < 0.35 or kind == "growing":
		centre = player + Vector2(rng.randf_range(-80.0, 80.0), rng.randf_range(-80.0, 80.0))
	var bodies := []
	for i in 34:
		var d := {}
		d[&"pos"] = centre + Vector2(rng.randf_range(-box, box), rng.randf_range(-box, box))
		d[&"heading"] = rng.randf_range(-PI, PI)
		var roll := rng.randf()
		var radius := 0.0
		if kind == "tiny":
			radius = rng.randf_range(0.2, 6.0)
		elif kind == "growing":
			# Mostly swallowable, so meals land mid-pass and grow the cell.
			radius = rng.randf_range(4.0, 30.0)
		elif roll < 0.45:
			radius = rng.randf_range(13.0, 40.0)
		elif roll < 0.70:
			radius = rng.randf_range(40.0, 90.0)
		elif roll < 0.80:
			radius = rng.randf_range(0.5, 13.0)
		elif roll < 0.88:
			radius = rng.randf_range(90.0, 250.0)
		else:
			radius = rng.randf_range(20.0, 30.0)
		d[&"radius"] = radius
		d[&"drifter"] = rng.randf() < 0.3
		var g := {}
		if not d[&"drifter"] or rng.randf() < 0.15:
			g[&"cytostome"] = rng.randi_range(0, 3)
		for gene: StringName in [&"pellicle", &"toxicyst", &"flagellum", &"cirrus", &"chemocyte"]:
			if rng.randf() < 0.45:
				g[gene] = rng.randi_range(1, 3)
		if g.is_empty():
			g[&"stigma"] = 1
		d[&"genome"] = g
		d[&"seeded"] = rng.randf() > 0.05
		if not d[&"seeded"] and rng.randf() < 0.7:
			d[&"radius"] = 0.0
		d[&"serial"] = i + 1
		d[&"meals"] = rng.randi_range(0, 5)
		var w := rng.randf()
		if kind == "wounded_pack":
			w = rng.randf() * 0.5
		d[&"wound"] = rng.randf_range(0.85, 1.0) if w < 0.35 \
			else (1.0 if w < 0.42 else rng.randf_range(0.0, 0.85))
		d[&"bite"] = 0.0 if rng.randf() < 0.75 else rng.randf_range(0.0, 1.0)
		d[&"state"] = rng.randi_range(0, 2)
		var target := -1
		if d[&"state"] == 1:
			target = -2 if rng.randf() < 0.4 else rng.randi_range(0, 33)
		elif rng.randf() < 0.1:
			target = rng.randi_range(-2, 33)
		d[&"target"] = target
		d[&"target_serial"] = (target + 1) if (target >= 0 and rng.randf() < 0.85) else rng.randi_range(0, 40)
		d[&"calm"] = 0.0 if rng.randf() < 0.6 else rng.randf_range(0.0, 50.0)
		d[&"stale"] = 0.0 if rng.randf() < 0.7 else rng.randf_range(0.0, 2.0)
		d[&"flee_from"] = d[&"pos"] + Vector2(rng.randf_range(-300.0, 300.0), rng.randf_range(-300.0, 300.0))
		d[&"aim"] = d[&"pos"] + Vector2(rng.randf_range(-300.0, 300.0), rng.randf_range(-300.0, 300.0))
		d[&"aim_clock"] = rng.randf_range(-0.5, 2.0)
		d[&"lost"] = 0.0 if rng.randf() < 0.7 else rng.randf_range(0.0, 1.0)
		d[&"rush"] = rng.randf_range(0.0, 25.0)
		d[&"best"] = INF if rng.randf() < 0.5 else rng.randf_range(0.0, 800.0)
		d[&"lunging"] = rng.randf() < 0.3
		d[&"break_clock"] = rng.randf_range(0.0, 21.0)
		d[&"stroke"] = rng.randf_range(-0.5, 1.5)
		d[&"wander"] = rng.randf_range(-0.1, 0.1)
		bodies.append(d)
	var victim := rng.randi_range(0, 33)
	match kind:
		"nan_radius":
			bodies[victim][&"radius"] = NAN
			bodies[victim][&"seeded"] = true
		"inf_radius":
			bodies[victim][&"radius"] = INF
			bodies[victim][&"seeded"] = true
		"nan_pos":
			bodies[victim][&"pos"] = Vector2(NAN, NAN)
		"nan_unseeded":
			bodies[victim][&"radius"] = NAN
			bodies[victim][&"seeded"] = false
		"whale":
			bodies[victim][&"radius"] = rng.randf_range(400.0, 1500.0)
			bodies[victim][&"seeded"] = true
			bodies[victim][&"drifter"] = false
			bodies[victim][&"genome"] = {&"cytostome": 3}
	st[&"bodies"] = bodies
	st[&"player"] = player
	st[&"cell_heading"] = rng.randf_range(-PI, PI)
	st[&"cell_velocity"] = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 120.0)
	st[&"cell_radius"] = rng.randf_range(14.0, 48.0)
	st[&"cell_wound"] = 0.0 if rng.randf() < 0.5 else rng.randf_range(0.0, 0.97)
	var ct := {&"cytostome": rng.randi_range(0, 3), &"cirrus": rng.randi_range(0, 3),
		&"flagellum": rng.randi_range(0, 3)}
	if kind == "growing":
		ct[&"cytostome"] = 3
	for gene: StringName in [&"pellicle", &"toxicyst", &"axoneme", &"chemocyte", &"ampulla", &"ocellus", &"palp", &"trichocyst"]:
		if rng.randf() < 0.4:
			ct[gene] = rng.randi_range(1, 3)
	st[&"cell_tiers"] = ct
	st[&"first_hunt"] = 0.0 if rng.randf() < 0.7 else rng.randf_range(0.0, 42.0)
	st[&"venom_cost"] = -1.0 if rng.randf() < 0.7 else 0.05
	st[&"bite_clock"] = 0.0 if rng.randf() < 0.7 else rng.randf_range(0.0, 1.0)
	st[&"dart_range"] = 0.0 if rng.randf() < 0.7 else rng.randf_range(50.0, 200.0)
	st[&"dart_bearing"] = rng.randf_range(-PI, PI)
	st[&"smell_range"] = 0.0 if rng.randf() < 0.5 else 900.0
	st[&"ping"] = rng.randf() < 0.3
	st[&"beams"] = rng.randf() < 0.3
	st[&"touch"] = 0.0 if rng.randf() < 0.6 else 230.0
	st[&"sister"] = [rng.randf_range(-PI, PI), rng.randf_range(0.0, 900.0),
		rng.randf_range(14.0, 40.0)]
	return st


func _apply(food: Node, cell: Node, st: Dictionary) -> void:
	var cells: Array = food.get("_cells")
	for i in mini(cells.size(), (st[&"bodies"] as Array).size()):
		var b: Object = cells[i]
		var d: Dictionary = st[&"bodies"][i]
		for k: StringName in BODY_KEYS:
			var v: Variant = d[k]
			if v is Dictionary:
				v = (v as Dictionary).duplicate(true)
			b.set(k, v)
	food.set("_serial", 100)
	food.set("_first_pending", false)
	food.set("_first_hunt", st[&"first_hunt"])
	food.set("venom_cost", st[&"venom_cost"])
	food.set("_bite_clock", st[&"bite_clock"])
	food.set("_dart_clock", 0.0)
	food.set("dart_range", st[&"dart_range"])
	food.set("dart_cooldown", 5.0)
	food.set("dart_bearing", st[&"dart_bearing"])
	food.set("smell_range", st[&"smell_range"])
	food.set("touch_range", st[&"touch"])
	if st[&"ping"]:
		food.set("ping_range", 1500.0)
		food.set("ping_period", 1.0)
		food.set("ping_tier", 2)
		food.set("ping_through", 0.34)
		food.set("ping_bearing", 0.3)
	else:
		food.set("ping_range", 0.0)
		food.set("ping_period", 0.0)
	if st[&"beams"]:
		food.set("beam_range", 900.0)
		food.set("beam_bearings", PackedFloat32Array([-0.4, 0.4]))
	else:
		food.set("beam_range", 0.0)
		food.set("beam_bearings", PackedFloat32Array())
	cell.set("position", st[&"player"])
	cell.set("heading", st[&"cell_heading"])
	cell.set("velocity", st[&"cell_velocity"])
	cell.set("radius", st[&"cell_radius"])
	cell.set("wound", st[&"cell_wound"])
	cell.get("genome").t = (st[&"cell_tiers"] as Dictionary).duplicate()


func _snap(food: Node, cell: Node) -> Array:
	var out := []
	for b: Object in food.get("_cells"):
		var row := []
		for k: StringName in BODY_KEYS:
			row.append(b.get(k))
		out.append(row)
	for k: StringName in FIELD_KEYS:
		out.append(food.get(k))
	for k: StringName in CELL_KEYS:
		out.append(cell.get(k))
	out.append((cell.get("genome").t as Dictionary).duplicate())
	if not pond_mode:
		return out
	for b: Object in food.get("_cells"):
		var row := []
		for k: StringName in POND_BODY_KEYS:
			row.append(b.get(k))
		var person: Object = b.get("person")
		if person == null:
			row.append(null)
		else:
			for k: StringName in PERSON_KEYS:
				row.append(person.get(k))
		out.append(row)
	for k: StringName in POND_FIELD_KEYS:
		out.append(food.get(k))
	return out


func _fresh(trial: int, st: Dictionary, kind: String) -> bool:
	growing = false
	# The setup itself, before any state is applied: both from the same stream,
	# on the same cell, and the stream compared after.
	old_cell.set("position", st[&"player"])
	new_cell.set("position", st[&"player"])
	old_cell.set("radius", st[&"cell_radius"])
	new_cell.set("radius", st[&"cell_radius"])
	old_cell.get("genome").t = (st[&"cell_tiers"] as Dictionary).duplicate()
	new_cell.get("genome").t = (st[&"cell_tiers"] as Dictionary).duplicate()
	seed(trial)
	old_food.setup(old_cell)
	var xo := randi()
	seed(trial)
	new_food.setup(new_cell)
	var xn := randi()
	old_log.clear()
	new_log.clear()
	var same := _compare("setup", trial, kind, xo, xn)
	_apply(old_food, old_cell, st)
	_apply(new_food, new_cell, st)
	old_log.clear()
	new_log.clear()
	growing = kind == "growing"
	return same


func _compare(what: String, trial: int, kind: String, extra_old: Variant = null,
		extra_new: Variant = null) -> bool:
	checks += 1
	var so := _snap(old_food, old_cell)
	var sn := _snap(new_food, new_cell)
	var same := var_to_bytes(so) == var_to_bytes(sn) \
		and var_to_bytes(old_log) == var_to_bytes(new_log) \
		and var_to_bytes(extra_old) == var_to_bytes(extra_new)
	if same:
		return true
	fails += 1
	if shown < 12:
		shown += 1
		print("[field-diff] MISMATCH trial %d kind %s at %s" % [trial, kind, what])
		for i in mini(so.size(), sn.size()):
			if var_to_bytes(so[i]) != var_to_bytes(sn[i]):
				print("   first differing entry %d: old %s | new %s" % [i, str(so[i]), str(sn[i])])
				break
		if var_to_bytes(old_log) != var_to_bytes(new_log):
			print("   logs: old %s | new %s" % [str(old_log), str(new_log)])
		if var_to_bytes(extra_old) != var_to_bytes(extra_new):
			print("   extra: old %s | new %s" % [str(extra_old), str(extra_new)])
	return false


func _tally(kind: String) -> void:
	for entry: Array in new_log:
		var key: String = entry[0]
		events[key] = int(events.get(key, 0)) + 1
		# The players' own rules, mouth to mouth: every one of them says so
		# with By.FRIEND (2), so this is the count that shows they ran.
		if (key == "person_touched" and int(entry[4]) == 2) \
				or (key == "person_died" and int(entry[2]) == 2):
			events[key + "_by_friend"] = int(events.get(key + "_by_friend", 0)) + 1
	events["reseeds"] = int(events.get("reseeds", 0)) + int(new_food.get("_serial")) - 100
	events[kind] = int(events.get(kind, 0)) + 1


func _trial(trial: int, frames: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = trial * 7919 + 13
	var kind: String = KINDS[trial % KINDS.size()] if trial < 100000 \
		else (["plain", "growing"][trial % 2])
	var st := _make_state(rng, kind)

	# The contact pass alone, then separation, on the untouched adversarial water.
	if not _fresh(trial, st, kind):
		return
	if not _compare("apply", trial, kind):
		return
	seed(trial * 31 + 1)
	var ro: bool = old_food._step_contacts()
	var xo := randi()
	seed(trial * 31 + 1)
	var rn: bool = new_food._step_contacts()
	var xn := randi()
	_compare("_step_contacts", trial, kind, [ro, xo], [rn, xn])
	_tally(kind)
	seed(trial * 31 + 2)
	old_food._step_separate()
	xo = randi()
	seed(trial * 31 + 2)
	new_food._step_separate()
	xn = randi()
	_compare("_step_separate", trial, kind, xo, xn)

	# The prey search, every body, at a spread of reaches.
	_fresh(trial, st, kind)
	var reaches := [0.0, 50.0, 300.0, 1900.0, INF]
	var oc: Array = old_food.get("_cells")
	var nc: Array = new_food.get("_cells")
	for i in oc.size():
		var reach: float = reaches[(i + trial) % reaches.size()]
		seed(trial * 131 + i)
		old_food._look_for_prey(i, oc[i], reach)
		xo = randi()
		seed(trial * 131 + i)
		new_food._look_for_prey(i, nc[i], reach)
		xn = randi()
		if not _compare("_look_for_prey %d" % i, trial, kind, xo, xn):
			return

	# A reseed, and the solo sister, on adversarial water.
	_fresh(trial, st, kind)
	var slot := trial % 34
	seed(trial * 17 + 5)
	old_food._seed(slot)
	xo = randi()
	seed(trial * 17 + 5)
	new_food._seed(slot)
	xn = randi()
	_compare("_seed %d" % slot, trial, kind, xo, xn)
	var sister: Array = st[&"sister"]
	var tiers := {&"cytostome": 2, &"pellicle": 1}
	seed(trial * 17 + 6)
	old_food.put_sister(float(sister[0]), float(sister[1]), float(sister[2]), tiers)
	xo = randi()
	seed(trial * 17 + 6)
	new_food.put_sister(float(sister[0]), float(sister[1]), float(sister[2]), tiers)
	xn = randi()
	_compare("put_sister", trial, kind, xo, xn)

	# Whole frames.
	_fresh(trial, st, kind)
	for f in frames:
		seed(trial * 7 + f * 1009)
		old_food._process(1.0 / 60.0)
		xo = randi()
		seed(trial * 7 + f * 1009)
		new_food._process(1.0 / 60.0)
		xn = randi()
		if not _compare("_process frame %d" % f, trial, kind, xo, xn):
			return
	_tally(kind + "_frames")


# ---------------------------------------------------------------------------
# A phone's pond: one person, both fields, the same calls.
# ---------------------------------------------------------------------------

## The second water's bodies -- `_make_state`'s, shifted up 34 slots, round a
## second centre, some of them hunting the person -- and the person: a pose
## near this cell or not, a genome, a worn order and the clocks a guest's body
## carries, all drawn from [param rng].
func _make_pond(rng: RandomNumberGenerator, st: Dictionary, kind: String) -> Dictionary:
	var extra := _make_state(rng, kind)
	var player: Vector2 = st[&"player"]
	var shift := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 900.0)
	var bodies: Array = extra[&"bodies"]
	for d: Dictionary in bodies:
		d[&"pos"] = (d[&"pos"] as Vector2) + shift
		d[&"flee_from"] = (d[&"flee_from"] as Vector2) + shift
		d[&"aim"] = (d[&"aim"] as Vector2) + shift
		d[&"serial"] = int(d[&"serial"]) + 34
		var target := int(d[&"target"])
		if target >= 0:
			d[&"target"] = target + (34 if rng.randf() < 0.5 else 0)
			d[&"target_serial"] = int(d[&"target"]) + 1 if rng.randf() < 0.85 \
				else rng.randi_range(0, 80)
	# Some of both waters hunt the person, in slot 68: `place_person` gives
	# them serial 101 on water whose `_serial` `_apply` has set to 100.
	for d: Dictionary in (st[&"bodies"] as Array) + bodies:
		if rng.randf() < 0.12:
			d[&"state"] = 1
			d[&"target"] = 68
			d[&"target_serial"] = 101 if rng.randf() < 0.85 else rng.randi_range(0, 120)
	var pond := {}
	pond[&"bodies"] = bodies
	pond[&"tuned"] = []
	for i in 68:
		(pond[&"tuned"] as Array).append(rng.randi_range(-1, 1))
	# The person: a mouth's length from this cell a third of the time, so the
	# players' own rules -- swallow, poison, chew both ways -- are reached.
	var near := rng.randf() < 0.35 or kind == "growing"
	var person_at := player + Vector2.from_angle(rng.randf() * TAU) \
		* (rng.randf_range(0.0, 90.0) if near else rng.randf_range(60.0, 1500.0))
	pond[&"at"] = person_at
	pond[&"heading"] = rng.randf_range(-PI, PI) if not near \
		else (player - person_at).angle() + PI * 0.5 + rng.randf_range(-0.6, 0.6)
	pond[&"radius"] = rng.randf_range(14.0, 48.0)
	pond[&"velocity"] = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 150.0)
	pond[&"turning"] = rng.randf_range(-1.2, 1.2)
	var tiers := {}
	for gene: StringName in PERSON_GENES:
		if gene == &"cytostome" or rng.randf() < 0.45:
			tiers[gene] = rng.randi_range(0, 3) if gene == &"cytostome" \
				else rng.randi_range(1, 3)
	pond[&"tiers"] = tiers
	var order: Array = []
	for gene: StringName in tiers:
		if rng.randf() < 0.8:
			order.append(gene)
	# Fisher-Yates on this trial's own stream: `shuffle()` draws from the
	# global one, which would make a mismatch impossible to reproduce alone.
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: Variant = order[i]
		order[i] = order[j]
		order[j] = held
	if not order.is_empty() and rng.randf() < 0.3:
		order.insert(rng.randi_range(0, order.size()), &"")
	pond[&"order"] = order
	pond[&"wound"] = 0.0 if rng.randf() < 0.5 else rng.randf_range(0.0, 0.99)
	pond[&"bite"] = 0.0 if rng.randf() < 0.7 else rng.randf_range(0.0, 1.0)
	pond[&"first_hunt"] = 0.0 if rng.randf() < 0.7 else rng.randf_range(0.0, 42.0)
	pond[&"dart_clock"] = 0.0 if rng.randf() < 0.7 else rng.randf_range(0.0, 20.0)
	pond[&"wet"] = rng.randf() < 0.85
	pond[&"quiet"] = rng.randf() < 0.1
	# This cell: in the water, dividing, or dead.
	var roll := rng.randf()
	pond[&"local"] = 0 if roll < 0.8 else (1 if roll < 0.9 else 2)
	pond[&"place"] = [player + Vector2.from_angle(rng.randf() * TAU) * 480.0,
		rng.randf_range(-PI, PI), rng.randf_range(14.0, 40.0)]
	pond[&"sister"] = [player + Vector2.from_angle(rng.randf() * TAU)
		* rng.randf_range(0.0, 700.0), rng.randf_range(-PI, PI),
		rng.randf_range(14.0, 40.0)]
	pond[&"mirror_wound"] = rng.randf_range(0.0, 1.0)
	return pond


func _pond_apply(food: Node, cell: Node, st: Dictionary, pond: Dictionary) -> void:
	_apply(food, cell, st)
	var cells: Array = food.get("_cells")
	var extra: Array = pond[&"bodies"]
	for i in extra.size():
		var b: Object = cells[34 + i]
		var d: Dictionary = extra[i]
		for k: StringName in BODY_KEYS:
			var v: Variant = d[k]
			if v is Dictionary:
				v = (v as Dictionary).duplicate(true)
			b.set(k, v)
	for i in 68:
		(cells[i] as Object).set(&"tuned", int((pond[&"tuned"] as Array)[i]))
	food.place_person(pond[&"at"], float(pond[&"heading"]), float(pond[&"radius"]),
		pond[&"velocity"], float(pond[&"turning"]))
	food.set_person_genome((pond[&"tiers"] as Dictionary).duplicate(),
		(pond[&"order"] as Array).duplicate())
	var pb: Object = cells[68]
	pb.set(&"wound", float(pond[&"wound"]))
	pb.set(&"bite", float(pond[&"bite"]))
	var person: Object = pb.get("person")
	person.set(&"first_hunt", float(pond[&"first_hunt"]))
	person.set(&"dart_clock", float(pond[&"dart_clock"]))
	food.set_person_in_water(bool(pond[&"wet"]))
	food.set_person_quiet(bool(pond[&"quiet"]))
	match int(pond[&"local"]):
		1:
			food.leave_water(false)
		2:
			food.leave_water(true)


## Both fields set up from one stream on one cell, opened as a pond, and given
## the same two waters and person. False if they already differ.
func _pond_fresh(trial: int, st: Dictionary, pond: Dictionary, kind: String) -> bool:
	growing = false
	for cell: Node in [old_cell, new_cell]:
		cell.set("position", st[&"player"])
		cell.set("radius", st[&"cell_radius"])
		cell.get("genome").t = (st[&"cell_tiers"] as Dictionary).duplicate()
	seed(trial)
	old_food.setup(old_cell)
	old_food.open_pond()
	var xo := randi()
	seed(trial)
	new_food.setup(new_cell)
	new_food.open_pond()
	var xn := randi()
	old_log.clear()
	new_log.clear()
	var same := _compare("pond setup", trial, kind, xo, xn)
	_pond_apply(old_food, old_cell, st, pond)
	_pond_apply(new_food, new_cell, st, pond)
	old_log.clear()
	new_log.clear()
	growing = kind == "growing"
	return same


## One call on both fields from one stream, compared with its result.
func _both(what: String, trial: int, kind: String, stream: int, call: Callable) -> bool:
	seed(stream)
	var ro: Variant = call.call(old_food)
	var xo := randi()
	seed(stream)
	var rn: Variant = call.call(new_food)
	var xn := randi()
	return _compare(what, trial, kind, [ro, xo], [rn, xn])


func _pond_trial(trial: int, frames: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = trial * 6007 + 29
	var kind: String = KINDS[trial % KINDS.size()] if trial < 100000 \
		else (["plain", "growing"][trial % 2])
	var st := _make_state(rng, kind)
	var pond := _make_pond(rng, st, kind)
	var dt := 1.0 / 60.0

	# The contact pass -- the water on this cell and on the person, and the two
	# players on each other -- and separation, on the untouched water.
	if not _pond_fresh(trial, st, pond, kind):
		return
	if not _compare("pond apply", trial, kind):
		return
	_both("pond _step_contacts", trial, kind, trial * 31 + 11,
		func(f: Node) -> Variant: return f._step_contacts())
	_both("pond _step_separate", trial, kind, trial * 31 + 12,
		func(f: Node) -> Variant: f._step_separate(); return null)
	_tally("pond_" + kind)

	# Every prey search, the person in reach of every mouth.
	_pond_fresh(trial, st, pond, kind)
	var reaches := [0.0, 50.0, 300.0, 1900.0, INF]
	for i in 68:
		var reach: float = reaches[(i + trial) % reaches.size()]
		if not _both("pond _look_for_prey %d" % i, trial, kind, trial * 131 + i,
				func(f: Node) -> Variant:
					f._look_for_prey(i, (f.get("_cells") as Array)[i], reach)
					return null):
			return

	# The recycle, and the two snapshots it is read by.
	_pond_fresh(trial, st, pond, kind)
	_both("pond _step_pond", trial, kind, trial * 17 + 7,
		func(f: Node) -> Variant: f._step_pond(); return null)
	_both("pond_entries(true)", trial, kind, trial * 17 + 8,
		func(f: Node) -> Variant: return f.pond_entries(true))
	_both("pond_entries(false)", trial, kind, trial * 17 + 9,
		func(f: Node) -> Variant: return f.pond_entries(false))

	# Both sisters: the guest's, by SISTER, and this cell's own.
	_pond_fresh(trial, st, pond, kind)
	var sister: Array = pond[&"sister"]
	var tiers := {&"cytostome": 2, &"pellicle": 1}
	_both("pond place_sister", trial, kind, trial * 17 + 10,
		func(f: Node) -> Variant:
			return f.place_sister(sister[0], float(sister[1]), float(sister[2]), tiers))
	var solo: Array = st[&"sister"]
	_both("pond put_sister", trial, kind, trial * 17 + 11,
		func(f: Node) -> Variant:
			f.put_sister(float(solo[0]), float(solo[1]), float(solo[2]), tiers)
			return null)

	# The person's lifecycle, as the wire drives it.
	_pond_fresh(trial, st, pond, kind)
	var place: Array = pond[&"place"]
	_both("pond renew_person", trial, kind, trial * 17 + 12,
		func(f: Node) -> Variant: f.renew_person(); return f.person() != null)
	_both("pond set_person_in_water", trial, kind, trial * 17 + 13,
		func(f: Node) -> Variant: f.set_person_in_water(false); return null)
	_both("pond remove_person", trial, kind, trial * 17 + 14,
		func(f: Node) -> Variant: f.remove_person(); return f.person() == null)
	_both("pond arrival", trial, kind, trial * 17 + 15,
		func(f: Node) -> Variant:
			f.place_person(place[0], float(place[1]), float(place[2]))
			f.set_person_in_water(true)
			return f.person() != null)
	_both("pond enter_water", trial, kind, trial * 17 + 16,
		func(f: Node) -> Variant: f.enter_water(); return null)

	# Whole frames, the person re-reported every third one as a guest's state
	# frames would put it, and now and then leaving the water or going quiet.
	_pond_fresh(trial, st, pond, kind)
	var from: Vector2 = pond[&"at"]
	var velocity: Vector2 = pond[&"velocity"]
	var heading := float(pond[&"heading"])
	for f in frames:
		if f % 3 == 2:
			var at := from + velocity * (float(f) * dt)
			var wet := (f / 90) % 5 != 3
			var report := func(field: Node) -> Variant:
				if field.person() == null:
					return null
				field.set_person_in_water(wet)
				field.place_person(at, heading + 0.01 * float(f),
					float(pond[&"radius"]), velocity, 0.3)
				field.set_person_quiet((f / 60) % 7 == 5)
				return null
			if not _both("pond report %d" % f, trial, kind, trial * 7 + f * 1013,
					report):
				return
		if not _both("pond _process frame %d" % f, trial, kind, trial * 7 + f * 1009,
				func(field: Node) -> Variant: field._process(dt); return null):
			return
	_tally("pond_" + kind + "_frames")

	# A mirror of that water on each side, fed the same snapshot.
	var entries: Array = old_food.pond_entries(false)
	var wound := float(pond[&"mirror_wound"])
	_both("mirror become", trial, kind, trial * 17 + 20,
		func(f: Node) -> Variant:
			f.become_mirror()
			f.apply_pond(wound, entries)
			f.set_person_genome((pond[&"tiers"] as Dictionary).duplicate(),
				(pond[&"order"] as Array).duplicate())
			return f.person() != null)
	for f in mini(frames, 60):
		if not _both("mirror _process frame %d" % f, trial, kind, trial * 3 + f * 1019,
				func(field: Node) -> Variant: field._process(dt); return null):
			return
