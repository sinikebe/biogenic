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
## empties under the measurement and no meal hides what was spent. Prints the
## burn as a multiple of a resting body, and when a cell burning that is empty
## and when it dies, fed to the end of the grace, from metabolism.gd's own
## constants. It stops at a division: a daughter is a different body.
##
## Otherwise it counts meals -- the field's `eaten` -- over `--probe-until=`
## seconds of simulated life. A division's pinch and choice are not simulated
## and do not count, and the choice is answered by leaning port, so a run never
## waits on the choosing screen. Two ways to look for food besides drive.gd's
## own `--sniff`:
##
## - `--seek=R` steers at the nearest body the mouth can take within R units:
##   a player in full vision going for the food on the screen. Turning only;
##   a born cell has no push.
## - `--ping` knows of that body only once an echo would have brought it back,
##   at the cell's own `ampulla` period and reach, and steers at where it was:
##   a crude radar player, which acts on each echo once.
##
## Prints the first meal, the meals, the longest wait, what the bar averaged
## and how much of the time was spent in the grace, the divisions, and how the
## run ended. Excluded from export (`tools/*` on every preset), so none of it
## ships.

const FoodField := preload("res://game/normal/food.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")
const NormalMode := preload("res://game/normal/normal_mode.gd")

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
var _seek := 0.0
var _ping := false
var _spent := 0.0
var _meal_times: Array[float] = []
var _worth := 0.0
var _hunger_seconds := 0.0
var _grace_seconds := 0.0
var _divisions := 0
var _dividing := false
var _end := ""
var _key := 0
var _look := 0.0
var _ping_clock := 0.0
var _echo_at := -1.0
var _echo := Vector2.ZERO
var _aim := Vector2.ZERO
var _aiming := false
var _meals_seen := 0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--probe-until="):
			_until = float(a.trim_prefix("--probe-until="))
		elif a == "--burn":
			_burn = true
		elif a.begins_with("--seek="):
			_seek = float(a.trim_prefix("--seek="))
		elif a == "--ping":
			_ping = true
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
		if _met != null and _burn:
			_met.set_hunger(MARK)
	if _run != null and _met != null and _end == "":
		_step(delta)
	if _t >= _until or _end != "":
		_report()
		quit()
	return false


func _step(delta: float) -> void:
	var hunger := float(_met.get("hunger"))
	if int(_run.get("_life")) != NormalMode.Life.ALIVE:
		if not _burn:
			_end = "%s at %.0f s" % ["starved" if hunger >= 1.0 else "eaten", _live]
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
	if _dividing or not _met.can_process():
		return
	_live += delta
	if _burn:
		if hunger > MARK:
			_spent += hunger - MARK
		_met.set_hunger(MARK)
		return
	_hunger_seconds += hunger * delta
	if hunger >= 1.0:
		_grace_seconds += delta
	if _seek > 0.0 or _ping:
		_steer(delta)


func _on_eaten(nutrition: float, _gene: StringName, _at: Vector2) -> void:
	_meal_times.append(_live)
	_worth += nutrition


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


## The nearest body [param cell]'s mouth can take within [param reach], or
## `Vector2.INF`.
func _nearest(cell: Node, reach: float) -> Vector2:
	var at: Vector2 = cell.get("position")
	var gape: float = cell.call("gape")
	var best := reach
	var found := Vector2.INF
	for body: Object in _food.call("bodies"):
		if not body.get("seeded") or float(body.get("radius")) >= gape:
			continue
		var d: float = (body.get("pos") as Vector2).distance_to(at)
		if d < best:
			best = d
			found = body.get("pos")
	return found


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
			var heard := _nearest(cell, float(cell.call("ping_range")))
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
		want = _nearest(cell, _seek)
	_look = 0.0
	if want == Vector2.INF:
		_press(0)
		return
	var off := want - at
	var diff := angle_difference(float(cell.get("heading")), atan2(off.x, -off.y))
	_press(1 if diff > AIM_SLOP else (-1 if diff < -AIM_SLOP else 0))


func _report() -> void:
	if _burn:
		var rate := _spent / maxf(_live, 1e-6)
		var empty := 1.0 / maxf(rate, 1e-9)
		print("[forage] %.0f s simulated%s: burn x%.2f of rest, empty at %.1f s, dead at %.1f s"
			% [_live, " until it divided" if _end == "divided" else "",
			rate * Metabolism.HUNGER_SECONDS, empty, empty + Metabolism.STARVE_GRACE])
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
