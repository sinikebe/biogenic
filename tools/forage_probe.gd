extends SceneTree
## **How long a cell lasts, and how often it eats** (docs/design/energy.md §7).
## Wraps tools/drive.tscn, which reads the same user args, so every drive.gd
## flag -- `--seed=`, `--genome=`, `--hold=`, `--key-down=`, `--sniff` -- plays
## the run as it always does, and this only watches and, if asked, steers.
##
##   godot --headless --path . --fixed-fps 60 -s res://tools/forage_probe.gd -- \
##       --seed=3 --mode=0 --genome=cytostome:1,cirrus:1,flagellum:1,stigma:1 \
##       --burn --probe-until=120
##
## `--burn`: hunger is put back to a low mark every frame, so the tank never
## empties under the measurement and a meal changes nothing. Prints the burn as
## a multiple of a resting body, and when a cell burning that is empty and when
## it dies, fed to the end of the grace, from metabolism.gd's own constants. It
## stops at a division, because a daughter is a different body, and says so if
## the body is eaten.
##
## Otherwise it counts meals -- the field's `eaten` -- for `--probe-until=`
## seconds of the run. Only simulated seconds count as life: a division's pinch
## and choice do not, and the choice is answered by leaning port, so a run never
## waits on the choosing screen. Three ways to look for food besides drive.gd's
## own `--sniff`:
##
## - `--screen=WxH` steers at the nearest body the mouth can take inside a
##   W x H canvas centred on the cell: a player in full vision going for the
##   food on the screen. 1280x720 is a 16:9 screen and 1600x720 a 20:9 phone.
##   The camera is north-up and at vision.gd's ZOOM, which this reads. Turning
##   only; a born cell has no push.
## - `--seek=R` does the same inside R units in every direction, which sees
##   past a real screen's top and bottom. It is here to compare with.
## - `--ping` knows of the nearest such body only once an echo would have
##   brought it back, at the cell's own `ampulla` period and reach, first on
##   its first frame as the organ's, and steers at where it was. A crude radar
##   player that acts on each echo once. It ignores the ampulla's baffles and
##   its own body's shadow, which flatters it.
##
## Prints the first meal, the meals, the longest wait, what the bar averaged
## and how much of the time was spent in the grace, the divisions, and how the
## run ended. Excluded from export (`tools/*` on every preset), so none of it
## ships.
##
## **In the drop** (docs/design/ocean.md §8.3, §15.3) -- a run with no session,
## unless `--drop=0` -- the bot goes for **the living first and a floc only when
## nothing alive is on its screen**, what a player does once they know a floc
## does not grow them, and a body's `pellicle` makes it bigger to the bot's mouth
## as to every mouth there. Two more players:
##
## - `--avoid-venom` passes over a body carrying `veneneux`, as a full-vision
##   player who has learnt the organ's colour does;
## - `--cautious` reads the red lip: it leaves food within CAUTION of a mouth
##   that could swallow it, and turns away from such a mouth that close ahead.
##
## And it prints how a death came -- swallowed, chewed or poisoned --
## `[forage-near]`, the edible bodies within 700 and 1,400 units, the threats and
## the dread met along the path every second, `[forage-compete]`, the targets
## another eater took first, `[forage-times]`, every meal and graze, and the
## drop's census at the end. `--drop=0` prints today's water's `[forage-living]`
## the same way (§15.4).

const FoodField := preload("res://game/normal/food.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")
const NormalMode := preload("res://game/normal/normal_mode.gd")
const VisionLayer := preload("res://game/vision/vision.gd")

## `--burn`'s mark: far from both ends, so no frame's rise is clamped.
const MARK := 0.1
## How often a steering bot looks again, in seconds.
const LOOK := 0.1
## Radians off the nose inside which a steering bot stops turning.
const AIM_SLOP := 0.12

var _drive: Node
var _run: Node
var _met: Node
var _food: Node
var _t := 0.0
var _live := 0.0
var _until := 180.0
var _burn := false
var _seek := INF
## Half the screen, in world units; zero when the bot is not limited to one.
var _screen := Vector2.ZERO
var _ping := false
var _spent := 0.0
var _meal_times: Array[float] = []
## Flocs, which feed and do not grow (the drop's).
var _graze_times: Array[float] = []
var _graze_worth := 0.0
var _worth := 0.0
var _hunger_seconds := 0.0
var _grace_seconds := 0.0
var _divisions := 0
var _dividing := false
var _end := ""
var _key := 0
var _look := 0.0
## Starts full, so the first look pings, as the organ does on its first frame.
var _ping_clock := INF
var _echo_at := -1.0
var _echo := Vector2.ZERO
var _aim := Vector2.ZERO
var _aiming := false
var _meals_seen := 0
## The body the bot is steering at, its id and how many times the bot had fed
## when it chose it -- so a target another mouth took first is counted.
var _tgt: Object = null
var _tgt_id := -1
var _tgt_fed := 0
var _cand: Object = null
var _chases := 0
var _lost := 0
## Sampled every second along the path: edible bodies within 700 and 1,400,
## mouths within 1,400 that could swallow the bot, the dread met, and the
## living within 1,400.
var _near_clock := 0.0
var _near700: Array[int] = []
var _near1400: Array[int] = []
var _threat1400: Array[int] = []
var _dread_samples: Array[float] = []
var _living1400: Array[int] = []
var _avoid_venom := false
var _cautious := false
## How close a mouth that could swallow the cautious bot may be to its food.
const CAUTION := 200.0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--probe-until="):
			_until = float(a.trim_prefix("--probe-until="))
		elif a == "--burn":
			_burn = true
		elif a.begins_with("--seek="):
			_seek = float(a.trim_prefix("--seek="))
		elif a.begins_with("--screen="):
			var wh := a.trim_prefix("--screen=").split("x")
			_screen = Vector2(float(wh[0]), float(wh[1])) * 0.5 / VisionLayer.ZOOM
		elif a == "--ping":
			_ping = true
		elif a == "--avoid-venom":
			_avoid_venom = true
		elif a == "--cautious":
			_cautious = true
	_drive = (load("res://tools/drive.tscn") as PackedScene).instantiate()
	root.add_child(_drive)


func _process(delta: float) -> bool:
	_t += delta
	if _run == null:
		_run = _drive.get("_run")
		_met = _drive.get("_metabolism")
		_food = _drive.get("_food")
		if _food != null:
			_food.connect(&"eaten", _on_eaten)
			_food.connect(&"grazed", _on_grazed)
		if _met != null and _burn:
			_met.set_hunger(MARK)
	if _run != null and _met != null and _end == "":
		_step(delta)
	if _t >= _until or _end != "":
		_report()
		quit()
	return false


func _seeking() -> bool:
	return _screen != Vector2.ZERO or _seek < INF or _ping


func _step(delta: float) -> void:
	var hunger := float(_met.get("hunger"))
	if int(_run.get("_life")) != NormalMode.Life.ALIVE:
		var cause := "starved" if hunger >= 1.0 and not _burn else "eaten"
		match int(_food.get("died_of")) if cause == "eaten" else 0:
			FoodField.Cause.POISONED:
				cause = "eaten (poisoned)"
			FoodField.Cause.CHEWED:
				cause = "eaten (chewed)"
			FoodField.Cause.SWALLOWED:
				cause = "eaten (swallowed)"
		_end = "%s at %.0f s" % [cause, _live]
		return
	var split := int(_run.get("_split"))
	if split == NormalMode.Split.CHOOSING:
		_press(-1)
	elif _key != 0 and _dividing:
		_press(0)
	if split > NormalMode.Split.QUICKEN and not _dividing:
		_divisions += 1
		# A daughter is a different body: `--burn` measures the one it was given.
		if _burn:
			_end = "divided"
			return
	_dividing = split > NormalMode.Split.QUICKEN
	if _dividing or not (_met.is_processing() and _met.can_process()):
		return
	_live += delta
	if _burn:
		if hunger > MARK:
			_spent += hunger - MARK
		_met.set_hunger(MARK)
		return
	_hunger_seconds += hunger * delta
	_near_clock += delta
	if _near_clock >= 1.0:
		_near_clock = 0.0
		_sample_near()
	if hunger >= 1.0:
		_grace_seconds += delta
	if _seeking():
		_steer(delta)


## What was round the bot this second: edible bodies within 700 and 1,400 --
## settled flocs among them -- the mouths within 1,400 that could swallow it,
## the dread it felt, and the living within 1,400.
func _sample_near() -> void:
	var cell: Node = _run.get("_cell")
	var at: Vector2 = cell.get("position")
	var gape: float = cell.call("gape")
	var swallow: float = cell.call("swallow_radius")
	var within700 := 0
	var within1400 := 0
	var threats := 0
	var living := 0
	var bodies: Array = _food.call("bodies")
	for i: int in _food.call("bodies_near", at, 1400.0):
		var body: Object = bodies[i]
		if not bool(body.get("inert")):
			living += 1
			if float(_food.call("gape_at", i)) > swallow:
				threats += 1
		elif float(body.get("settle")) < 1.0:
			continue
		if float(_food.call("swallow_size_of", i)) < gape:
			within1400 += 1
			if (body.get("pos") as Vector2).distance_to(at) <= 700.0:
				within700 += 1
	_dread_samples.append(float(_food.get("dread_level")))
	_living1400.append(living)
	_near700.append(within700)
	_near1400.append(within1400)
	_threat1400.append(threats)


func _on_eaten(nutrition: float, _gene: StringName, _at: Vector2) -> void:
	_meal_times.append(_live)
	_worth += nutrition


func _on_grazed(nutrition: float, _at: Vector2) -> void:
	_graze_times.append(_live)
	_graze_worth += nutrition


func _press(k: int) -> void:
	if k == _key:
		return
	if _key < 0:
		Input.action_release(&"ui_left")
	elif _key > 0:
		Input.action_release(&"ui_right")
	if k < 0:
		Input.action_press(&"ui_left")
	elif k > 0:
		Input.action_press(&"ui_right")
	_key = k


## The nearest body [param cell]'s mouth can take within [param reach] and, if
## the bot has one, on its screen; `Vector2.INF` when there is none. The living
## first: a floc (the drop's) only when nothing alive is there.
func _nearest(cell: Node, reach: float, screen: Vector2) -> Vector2:
	var at: Vector2 = cell.get("position")
	var gape: float = cell.call("gape")
	var best := reach
	var found := Vector2.INF
	var best_floc := reach
	var found_floc := Vector2.INF
	var picked: Object = null
	var picked_floc: Object = null
	var bodies: Array = _food.call("bodies")
	for i in bodies.size():
		var body: Object = bodies[i]
		if not body.get("seeded") or float(_food.call("swallow_size_of", i)) >= gape:
			continue
		var off: Vector2 = (body.get("pos") as Vector2) - at
		if screen != Vector2.ZERO and (absf(off.x) > screen.x or absf(off.y) > screen.y):
			continue
		if bool(body.get("inert")):
			if float(body.get("settle")) >= 1.0 and off.length() < best_floc \
					and not (_cautious and _threat_near(body.get("pos"), cell)):
				best_floc = off.length()
				found_floc = body.get("pos")
				picked_floc = body
			continue
		if _avoid_venom and int((body.get("genome") as Dictionary).get(&"veneneux", 0)) > 0:
			continue
		if off.length() < best and not (_cautious and _threat_near(body.get("pos"), cell)):
			best = off.length()
			found = body.get("pos")
			picked = body
	_cand = picked if found != Vector2.INF else picked_floc
	return found if found != Vector2.INF else found_floc


## Whether a mouth that could swallow [param cell] is within CAUTION of
## [param point]; its place in [member _threat_at].
var _threat_at := Vector2.INF


func _threat_near(point: Vector2, cell: Node) -> bool:
	var swallow: float = cell.call("swallow_radius")
	var bodies: Array = _food.call("bodies")
	var best := CAUTION
	_threat_at = Vector2.INF
	for i: int in _food.call("bodies_near", point, CAUTION):
		var b: Object = bodies[i]
		if bool(b.get("inert")):
			continue
		var d := (b.get("pos") as Vector2).distance_to(point)
		if d < best and float(_food.call("gape_at", i)) > swallow:
			best = d
			_threat_at = b.get("pos")
	return _threat_at != Vector2.INF


func _steer(delta: float) -> void:
	_look += delta
	if _look < LOOK:
		return
	var cell: Node = _run.get("_cell")
	var at: Vector2 = cell.get("position")
	var want := Vector2.INF
	if _ping:
		# An echo from d units is back after 2d at the pulse's speed; the bot
		# acts on it then, at where the body was when the pulse left.
		_ping_clock += _look
		if _meal_times.size() != _meals_seen:
			_meals_seen = _meal_times.size()
			_aiming = false
		if _ping_clock >= float(cell.call("ping_period")):
			_ping_clock = 0.0
			var heard := _nearest(cell, float(cell.call("ping_range")), Vector2.ZERO)
			if heard != Vector2.INF:
				_echo_at = _live + 2.0 * heard.distance_to(at) / FoodField.PING_SPEED
				_echo = heard
		if _echo_at >= 0.0 and _live >= _echo_at:
			_aim = _echo
			_aiming = true
			_echo_at = -1.0
		if _aiming and _aim.distance_to(at) > 20.0:
			want = _aim
		else:
			_aiming = false
	else:
		want = _nearest(cell, _seek, _screen)
		# Was the last target taken by someone else? Gone, or its slot another
		# body's, while the bot has not fed since it chose it.
		var fed := _meal_times.size() + _graze_times.size()
		if _tgt != null:
			var gone := not bool(_tgt.get("seeded")) or int(_tgt.get("id")) != _tgt_id
			if gone and fed == _tgt_fed:
				_lost += 1
				_tgt = null
		if _cand != null and (_cand != _tgt or int(_cand.get("id")) != _tgt_id):
			_chases += 1
			_tgt = _cand
			_tgt_id = int(_cand.get("id"))
			_tgt_fed = fed
		elif _cand == null:
			_tgt = null
	_look = 0.0
	if _cautious and _threat_near(at, cell):
		# A mouth that could swallow it, close: turn away from it first.
		var off_t := at - _threat_at
		var diff_t := angle_difference(float(cell.get("heading")), atan2(off_t.x, -off_t.y))
		_press(1 if diff_t > AIM_SLOP else (-1 if diff_t < -AIM_SLOP else 0))
		return
	if want == Vector2.INF:
		_press(0)
		return
	var off := want - at
	var diff := angle_difference(float(cell.get("heading")), atan2(off.x, -off.y))
	_press(1 if diff > AIM_SLOP else (-1 if diff < -AIM_SLOP else 0))


func _report() -> void:
	print("[forage-compete] chases %d lost %d" % [_chases, _lost])
	if _burn:
		var rate := _spent / maxf(_live, 1e-6)
		var empty := 1.0 / maxf(rate, 1e-9)
		var until := ""
		if _end == "divided":
			until = " until it divided"
		elif _end != "":
			until = ", then %s" % _end
		print("[forage] %.0f s simulated%s: burn x%.2f of rest, empty at %.1f s, dead at %.1f s"
			% [_live, until, rate * Metabolism.HUNGER_SECONDS, empty,
			empty + Metabolism.STARVE_GRACE])
		return
	var first := "none"
	var longest := 0.0
	var last := 0.0
	for when: float in _meal_times:
		if first == "none":
			first = "%.0f s" % when
		longest = maxf(longest, when - last)
		last = when
	longest = maxf(longest, _live - last)
	var meals := _meal_times.size()
	print(("[forage] first meal %s, %d meals in %.0f s, longest wait %.0f s, mean worth"
		+ " %.2f, %s | the bar %.2f on average, in the grace %.0f%% of the time,"
		+ " divided %d") % [first, meals, _live, longest, _worth / maxf(meals, 1),
		_end if _end != "" else "alive", _hunger_seconds / maxf(_live, 1e-6),
		100.0 * _grace_seconds / maxf(_live, 1e-6), _divisions])
	var times := PackedStringArray()
	for when: float in _meal_times:
		times.append("%.1f" % when)
	var grazes := PackedStringArray()
	for when: float in _graze_times:
		grazes.append("%.1f" % when)
	var samples := maxf(float(_near700.size()), 1.0)
	var empty700 := 0
	var empty1400 := 0
	var food700 := 0.0
	var food1400 := 0.0
	var threats := 0.0
	var living := 0.0
	for k in _near700.size():
		empty700 += 1 if _near700[k] == 0 else 0
		empty1400 += 1 if _near1400[k] == 0 else 0
		food700 += _near700[k]
		food1400 += _near1400[k]
		threats += _threat1400[k]
		living += _living1400[k]
	var dread := 0.0
	var high := 0
	for level: float in _dread_samples:
		dread += level
		high += 1 if level >= 0.5 else 0
	print("[forage-living] living<=1400 mean %.2f -> %.2f per million um^2" % [
		living / samples, living / samples / (PI * 1.4 * 1.4)])
	print(("[forage-near] food<=700 mean %.2f empty %.0f%% | food<=1400 mean %.2f empty"
		+ " %.0f%% | threats<=1400 mean %.2f | dread mean %.3f high %.0f%%") % [
		food700 / samples, 100.0 * empty700 / samples, food1400 / samples,
		100.0 * empty1400 / samples, threats / samples, dread / samples,
		100.0 * high / samples])
	print("[forage-times] meals %s | grazes %s | graze worth %.2f | lived %.1f | end %s" % [
		",".join(times), ",".join(grazes), _graze_worth, _live,
		_end if _end != "" else "alive"])
	if _food != null and bool(_food.call(&"in_drop")):
		print(_food.call(&"census_line"))
