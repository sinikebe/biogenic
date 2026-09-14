extends Node
## Dev harness: boots a game scene and feeds it synthetic input, so states that
## only exist mid-play can be photographed and the input path itself gets
## exercised rather than assumed.
##
## Sits between tools/shot.tscn and the game:
##
##   godot --path . --rendering-driver opengl3 res://tools/shot.tscn -- \
##       --scene=res://tools/drive.tscn --hold=d --out=/tmp/turn.png --wait=4
##
## Arguments (all optional, all after the -- that shot.gd also reads):
##   --play=res://...        scene to drive, default normal mode
##   --mode=0|1              force the view: 0 point of view, 1 full vision
##   --hold=a|d              hold a steering key for the whole run
##   --drag=<pixels>         press near the middle and drag this far sideways
##   --drag-at=<seconds>     when to start that drag, default 0.5
##   --arm-at=<seconds>      ignore --freeze-on before this time
##   --esc-at=<seconds>      send Escape once, at this time
##   --back-at=<seconds>     fire NOTIFICATION_WM_GO_BACK_REQUEST exactly the
##                           way SceneTree does when Android Back is pressed
##   --tap=<seconds>:<key>   tap a key once at that time; repeatable. Keys are
##                           esc, enter, up, down, left, right, v
##   --freeze-on=<kind>      pause the tree a few frames after this sensation,
##                           so a flash or a beat can be caught at its peak
##   --freeze-delay=<n>      how many frames after it, default 2
##   --freeze-after=<secs>   seconds after it instead of frames, which is the
##                           only frame-rate-independent way to catch an
##                           envelope at its peak
##   --freeze-at=<seconds>   pause the tree at this time
##   --hunger=<0..1>         force the cell's hunger, to photograph what the
##                           starvation floor actually leaves on screen
##   --starve=<seconds>      seconds already spent at full hunger, so the end of
##                           the forty-second grace can be reached in one frame
##   --stalk=<units>         park a hunting cell this far off the cell's front
##                           quarter and hold it there, so dread, a wake and a
##                           lunge can each be photographed at a known range
##   --food-at=<units>       same, for field cell 1, left drifting. Cell 0 is
##                           what --stalk and --hunt pose, so the two handles
##                           can be used together to frame both halves of the
##                           gape rule in one photograph
##   --gain=<0.7..2.4>       hold membrane sensitivity here, to photograph what
##                           the pause screen's light slider actually buys
##   --hunt=<units>          put a cell that can eat you this far off, once, and
##                           then let it hunt for itself. This is how the
##                           escape-window contract in the design doc gets
##                           measured, since it is made of time and cannot be
##                           photographed.
##   --prey-radius=<r>       give field cell 1 this body radius and a real
##                           genome, so the other half of the gape rule -- a
##                           cell near your own size that you can swallow -- can
##                           be set up on purpose instead of waited for
##   --hunter-gape=<mult>    the hunter's gape as a multiple of your radius,
##                           default 1.40. Below 0.85 it cannot eat you at all
##                           and below 1.35 dread lands part-way up the curve,
##                           which is how the continuity of §7.0 gets shown.
##   --radius=<r>            force the player's body radius, which is the slot
##                           ladder, the gape and the whole of what the water
##                           seeds around you. r40 is where section 3.1 says the
##                           run is won
##   --genome=<g:t,g:t>      force the player's genome, e.g.
##                           cytostome:3,cirrus:3,flagellum:3. This is the only
##                           way to reach a tier-3 cell without playing for
##                           fifteen minutes.
##   --check-seeding=<n>     reseed the field n times and print what §1.3's
##                           distribution actually produces, including whether
##                           the drifter floor ever fails. Quits when done.
##   --trace=<seconds>       print the field, dread, threat and the player's
##                           realised speed on that interval
##   --forage                steer up the taste gradient, to measure §3.3's
##                           "a meal every 60 to 90 seconds" without a human
##   --evade                 play the escape contract in §5.4: hold full steer
##                           while the last wake bearing is ahead, release once
##                           it is astern, and do not waver. This is the only
##                           way to test a window that is made of time.
##   --seed=<int>            deterministic drift and impulses
##
## Prints every sensation the membrane bus receives with its timestamp, which is
## how the event bus gets checked end to end. Lives in tools/, which the export
## presets exclude, so none of this ships.

const DEFAULT_SCENE := "res://game/normal/normal_mode.tscn"
const FoodField := preload("res://game/normal/food.gd")
const CellBody := preload("res://game/normal/cell.gd")

var _clock := 0.0
var _esc_at := -1.0
var _esc_sent := false
var _back_at := -1.0
## [[seconds, keycode], ...], consumed as the clock passes each one.
var _taps: Array = []
var _freeze_at := -1.0
var _freeze_on := ""
var _freeze_countdown := -1
var _freeze_delay := 2
var _freeze_after := -1.0
var _bus: Node = null
var _run: Node = null
var _metabolism: Node = null
var _genome: Node = null
var _food: Node = null
var _hunger := -1.0
var _starve := -1.0
var _stalk := -1.0
var _food_at := -1.0
var _gain := -1.0
var _hunt := -1.0
var _trace := -1.0
var _trace_clock := 0.0
var _hunter_gape := 1.40
var _prey_radius := -1.0
var _radius := -1.0
var _genome_spec := ""
var _check_seeding := 0
## Cumulative meals eaten by one field cell off another, which is the one thing
## in section 1.3 that has to be observed rather than argued about. Field cells
## are recycled, so this is accumulated by watching each slot's serial.
var _field_meals := 0
var _watch_serial := PackedInt32Array()
var _watch_meals := PackedInt32Array()
## Seconds to wait before reporting where a cell that just fed ended up.
const AFTER_MEAL_LOOK := 6.0
var _after_meal: Array = []
var _dread_seconds := 0.0
var _dread_area := 0.0
var _run_seconds := 0.0
var _travelled := 0.0
var _last_pos := Vector2.ZERO
var _have_last_pos := false
var _speed_clock := 0.0
var _evade := false
## World angle of the last wake, so the body-relative bearing can be recomputed
## as the cell turns instead of going stale the moment it does.
var _wake_world := 0.0
var _have_wake := false
var _evade_key := KEY_NONE
var _forage := false
var _taste_bearing := 0.0
var _taste_c := 0.0
var _forage_key := KEY_NONE
var _meals := 0
var _drag_px := 0.0
var _drag_at := 0.5
var _drag_step := 0
## The freeze-on trigger ignores sensations before this time, so a later beat
## can be caught instead of the first one.
var _arm_at := 0.0
## -1 leaves the scene to pick up whatever the mode select last stored.
var _mode := -1


func _ready() -> void:
	# The game pauses the tree; the driver has to keep running through it or it
	# could never press anything on a pause screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# And it has to run *after* the game, so that anything it holds in place --
	# a parked hunter, a forced hunger -- survives the frame it set it in.
	process_priority = 1000

	var scene_path := DEFAULT_SCENE
	var hold := ""
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--play="):
			scene_path = text.trim_prefix("--play=")
		elif text.begins_with("--hold="):
			hold = text.trim_prefix("--hold=").to_lower()
		elif text.begins_with("--drag="):
			_drag_px = float(text.trim_prefix("--drag="))
		elif text.begins_with("--drag-at="):
			_drag_at = float(text.trim_prefix("--drag-at="))
		elif text.begins_with("--arm-at="):
			_arm_at = float(text.trim_prefix("--arm-at="))
		elif text.begins_with("--esc-at="):
			_esc_at = float(text.trim_prefix("--esc-at="))
		elif text.begins_with("--back-at="):
			_back_at = float(text.trim_prefix("--back-at="))
		elif text.begins_with("--tap="):
			var parts := text.trim_prefix("--tap=").split(":")
			if parts.size() == 2:
				_taps.append([float(parts[0]), _keycode(parts[1])])
		elif text.begins_with("--freeze-at="):
			_freeze_at = float(text.trim_prefix("--freeze-at="))
		elif text.begins_with("--freeze-on="):
			_freeze_on = text.trim_prefix("--freeze-on=")
		elif text.begins_with("--freeze-delay="):
			_freeze_delay = int(text.trim_prefix("--freeze-delay="))
		elif text.begins_with("--freeze-after="):
			_freeze_after = float(text.trim_prefix("--freeze-after="))
		elif text.begins_with("--mode="):
			_mode = int(text.trim_prefix("--mode="))
		elif text.begins_with("--hunger="):
			_hunger = float(text.trim_prefix("--hunger="))
		elif text.begins_with("--starve="):
			_starve = float(text.trim_prefix("--starve="))
		elif text.begins_with("--stalk="):
			_stalk = float(text.trim_prefix("--stalk="))
		elif text.begins_with("--food-at="):
			_food_at = float(text.trim_prefix("--food-at="))
		elif text.begins_with("--gain="):
			_gain = float(text.trim_prefix("--gain="))
		elif text.begins_with("--hunt="):
			_hunt = float(text.trim_prefix("--hunt="))
		elif text.begins_with("--trace="):
			_trace = float(text.trim_prefix("--trace="))
		elif text.begins_with("--prey-radius="):
			_prey_radius = float(text.trim_prefix("--prey-radius="))
		elif text.begins_with("--hunter-gape="):
			_hunter_gape = float(text.trim_prefix("--hunter-gape="))
		elif text.begins_with("--radius="):
			_radius = float(text.trim_prefix("--radius="))
		elif text.begins_with("--genome="):
			_genome_spec = text.trim_prefix("--genome=")
		elif text.begins_with("--check-seeding="):
			_check_seeding = int(text.trim_prefix("--check-seeding="))
		elif text == "--evade":
			_evade = true
		elif text == "--forage":
			_forage = true
		elif text.begins_with("--seed="):
			seed(int(text.trim_prefix("--seed=")))

	if not ResourceLoader.exists(scene_path):
		push_error("[drive] no scene at %s" % scene_path)
		get_tree().quit(1)
		return
	var scene: PackedScene = load(scene_path)
	var run := scene.instantiate()
	if _mode >= 0:
		# Set before the scene enters the tree, which is where it is read.
		run.set("mode", _mode)
		print("[drive] mode forced to ", _mode)
	add_child(run)
	_run = run
	_metabolism = _find_script(self, "res://game/normal/metabolism.gd")
	_genome = _find_script(self, "res://game/normal/genome.gd")
	_food = _find_script(self, "res://game/normal/food.gd")

	if _radius > 0.0:
		var body := _find_node_with(self, &"bearing_to")
		if body != null:
			body.radius = _radius
			# The water is seeded around the player's radius, so it has to be
			# seeded again once that has been forced.
			if _food != null:
				_food.setup(body)
			print("[drive] radius forced to %.1f -> %d slots" % [
				_radius, body.slots()])
	if _genome_spec != "" and _genome != null:
		_force_genome(_genome_spec)
	if _check_seeding > 0:
		_run_seeding_check(_check_seeding)
		get_tree().quit(0)
		return

	if _food != null:
		_food.eaten.connect(_on_meal)

	_bus = _find_bus(self)
	if _bus != null:
		_bus.sensation.connect(_on_sensation)
	else:
		print("[drive] no membrane bus found under ", scene_path)

	if _hunger >= 0.0 and _metabolism != null:
		_metabolism.set_hunger(_hunger)
		if _starve >= 0.0:
			_metabolism.starve_seconds = _starve
		print("[drive] hunger forced to %.2f -> beat %.2fs at %.2f strength" % [
			_hunger, _metabolism.beat_period(), _metabolism.beat_amplitude()])

	if _stalk >= 0.0 and _food != null:
		_make_hunter(0, _hold_point(_stalk, 40.0))
		print("[drive] hunter parked at %.0f units" % _stalk)
	if _hunt >= 0.0 and _food != null:
		_make_hunter(0, _hold_point(_hunt, 40.0))
		print("[drive] hunter released from %.0f units" % _hunt)
	if _prey_radius > 0.0 and _food != null:
		var bodies: Array = _food.get("_cells")
		if bodies.size() > 1:
			bodies[1].set("radius", _prey_radius)
			bodies[1].set("drifter", false)
			bodies[1].set("genome", {&"cytostome": 1, &"cirrus": 2})
			print("[drive] field cell 1 forced to r%.1f gape %.1f" % [
				_prey_radius, _food.gape_at(1)])
	if _food_at >= 0.0 and _food != null:
		print("[drive] field cell 1 parked at %.0f units" % _food_at)

	if hold == "a" or hold == "d":
		_send_key(KEY_A if hold == "a" else KEY_D, true)
		print("[drive] holding ", hold.to_upper())


## Ground truth about a meal, straight off the field: what it weighed against
## this body, which gene came out of it, and what that did to the genome. The
## bus is deliberately not told the first two, so this is the only place they
## can be checked.
func _on_meal(nutrition: float, gene: StringName, _at: Vector2) -> void:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	print("[meal]  %5.2f  nutrition %.2f of one meal (%.2f hunger)  gene %s -> %s  me r%.2f gape %.2f" % [
		_clock, nutrition, 0.5 * nutrition, gene if gene != &"" else &"none",
		_genome_text(_genome.tiers() if _genome != null else {}),
		cell.radius if cell != null else 0.0, cell.gape() if cell != null else 0.0])


func _process(delta: float) -> void:
	_clock += delta
	_hold_world()
	_watch_field(delta)
	_step_forage()
	_step_evade()
	_step_trace(delta)

	if _freeze_countdown > 0:
		_freeze_countdown -= 1
		if _freeze_countdown == 0:
			_freeze()

	if _esc_at >= 0.0 and not _esc_sent and _clock >= _esc_at:
		_esc_sent = true
		_send_key(KEY_ESCAPE, true)
		_send_key(KEY_ESCAPE, false)
		print("[drive] %5.2f  esc" % _clock)

	for i in range(_taps.size() - 1, -1, -1):
		if _clock >= float(_taps[i][0]):
			var code: Key = _taps[i][1]
			_send_key(code, true)
			_send_key(code, false)
			print("[drive] %5.2f  tap %d" % [_clock, code])
			_taps.remove_at(i)

	if _back_at >= 0.0 and _clock >= _back_at:
		_back_at = -1.0
		print("[drive] %5.2f  back (quit_on_go_back=%s)" % [
			_clock, get_tree().quit_on_go_back])
		get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)

	if _drag_px != 0.0 and _clock >= _drag_at:
		_step_drag()

	if _freeze_at >= 0.0 and _clock >= _freeze_at:
		_freeze_at = -1.0
		_freeze()


## Turn until the taste sits at the top. The dumbest possible forager, which is
## the point: if this cannot feed itself the field is too thin for a person.
func _step_forage() -> void:
	if not _forage:
		return
	# Evading wins. A hunted cell cannot smell its way out of the problem, and
	# it should not try to eat its way out either.
	var want := KEY_NONE
	if _evade_key == KEY_NONE and _taste_c > 0.06 and absf(_taste_bearing) > 0.15:
		want = KEY_D if _taste_bearing > 0.0 else KEY_A
	if want == _forage_key:
		return
	if _forage_key != KEY_NONE:
		_send_key(_forage_key, false)
	if want != KEY_NONE:
		_send_key(want, true)
	_forage_key = want


## Commit away from the wake and stay committed. Turns until the threat is 130
## degrees off the nose, then holds course until it drifts back inside 100 --
## the hysteresis is what "does not waver" means, and wavering is what §5.4 says
## actually costs players the window.
func _step_evade() -> void:
	if not _evade or not _have_wake or _run == null:
		return
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null:
		return
	var rel: float = angle_difference(cell.heading, _wake_world)
	var want := KEY_NONE
	if _evade_key != KEY_NONE:
		if absf(rel) < deg_to_rad(130.0):
			want = _evade_key
	elif absf(rel) < deg_to_rad(100.0):
		# Wake to starboard: turn to port, and the other way round.
		want = KEY_A if rel > 0.0 else KEY_D
	if want == _evade_key:
		return
	if _evade_key != KEY_NONE:
		_send_key(_evade_key, false)
	if want != KEY_NONE:
		_send_key(want, true)
		print("[drive] %5.2f  evade %s (threat %+6.1f deg)" % [
			_clock, "port" if want == KEY_A else "starboard", rad_to_deg(rel)])
	else:
		print("[drive] %5.2f  evade committed (threat %+6.1f deg)" % [
			_clock, rad_to_deg(rel)])
	_evade_key = want


## Everything the simulation half of Phase 5 has to be judged on, once every
## [param --trace] seconds: what the player is, what the water is, who is
## hunting whom and how hard the water is leaning on the membrane.
func _step_trace(delta: float) -> void:
	if _trace <= 0.0 or _food == null or _run == null:
		return
	_trace_clock += delta
	if _trace_clock < _trace:
		return
	_trace_clock = 0.0
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null:
		return

	var hunter: int = _food.hunter()
	var range_text := "     --"
	if hunter >= 0:
		range_text = "%7.1f" % _food.points()[hunter].distance_to(cell.position)
	var speed := _travelled / maxf(_speed_clock, 0.001)
	_travelled = 0.0
	_speed_clock = 0.0
	print("[trace] %6.2f  me r%5.2f gape %5.2f swim %5.1f (real %5.1f) %s" % [
		_clock, cell.radius, cell.gape(), cell.swim_speed(), speed,
		_genome_text(_genome.tiers() if _genome != null else {})])
	print("        dread %.3f  threat %.3f  hunter %s  range %s  upkeep %.2f  hunger %.2f  field meals %d  dread duty %.0f%% mean %.2f" % [
		_food.dread_level, _food.threat,
		"none" if hunter < 0 else str(hunter), range_text,
		_metabolism.upkeep if _metabolism != null else 1.0,
		_metabolism.hunger if _metabolism != null else 0.0, _field_meals,
		100.0 * _dread_seconds / maxf(_run_seconds, 0.001),
		_dread_area / maxf(_run_seconds, 0.001)])
	for i in _food.points().size():
		print("        cell %d  %s" % [i, _field_text(i, cell)])


func _field_text(index: int, cell: Node) -> String:
	var bodies: Array = _food.get("_cells")
	var b: Object = bodies[index]
	var radius: float = b.get("radius")
	var gape: float = _food.gape_at(index)
	var state: int = b.get("state")
	var names := ["drift", "stalk", "break"]
	var target: int = b.get("target")
	var target_text := "-"
	if target == FoodField.TARGET_PLAYER:
		target_text = "player"
	elif target >= 0:
		target_text = "cell %d" % target
	return "r%5.2f gape %5.2f %-5s -> %-6s  d %7.1f  %s  %s%s" % [
		radius, gape, names[state], target_text,
		cell.position.distance_to(b.get("pos")),
		"EATS ME" if gape > cell.radius else "       ",
		"edible" if radius < cell.gape() else "      ",
		"  %s" % _genome_text(b.get("genome"))]


func _genome_text(tiers: Dictionary) -> String:
	var parts: Array[String] = []
	for gene: StringName in tiers:
		parts.append("%s%d" % [str(gene).substr(0, 3), int(tiers[gene])])
	parts.sort()
	return "[%s]" % " ".join(parts)


## Watches the field for cells eating each other. Slots are recycled, so a jump
## in a slot's serial means a different body, not a meal.
func _watch_field(delta: float) -> void:
	if _food == null:
		return
	var bodies: Array = _food.get("_cells")
	if bodies == null:
		return
	if _watch_serial.size() != bodies.size():
		_watch_serial.resize(bodies.size())
		_watch_meals.resize(bodies.size())
	for i in bodies.size():
		var serial: int = bodies[i].get("serial")
		var meals: int = bodies[i].get("meals")
		if serial != _watch_serial[i]:
			_watch_serial[i] = serial
			_watch_meals[i] = meals
			continue
		if meals > _watch_meals[i]:
			_field_meals += meals - _watch_meals[i]
			var here: Vector2 = _food.points()[i]
			print("[field] %5.2f  cell %d ate one and is now r%.2f gape %.2f %s  (%.0f units from you)" % [
				_clock, i, bodies[i].get("radius"), _food.gape_at(i),
				_genome_text(bodies[i].get("genome")), _away(i)])
			# A cell that has just fed is newly dangerous and belongs in the
			# water, not ejected from it. Check where it actually went.
			_after_meal.append([i, serial, here, _clock])
			_watch_meals[i] = meals

	for k in range(_after_meal.size() - 1, -1, -1):
		var mark: Array = _after_meal[k]
		if _clock - float(mark[3]) < AFTER_MEAL_LOOK:
			continue
		_after_meal.remove_at(k)
		var index: int = mark[0]
		if bodies[index].get("serial") != mark[1]:
			continue
		# Its own displacement, not the gap to a player swimming at 56 u/s.
		# A break-off runs at lunge speed, so fleeing shows up as 570-1100
		# units in six seconds; drifting shows up as about 54.
		var moved: float = (mark[2] as Vector2).distance_to(_food.points()[index])
		print("[field] %5.2f  cell %d travelled %4.0f units in the %.0fs after its meal: %s" % [
			_clock, index, moved, AFTER_MEAL_LOOK,
			"drifting" if moved < 200.0 else "BOLTED"])

	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return
	# Only while the cell is actually alive. _set_simulating(false) stops the
	# metabolism, and counting the frozen post-death frames made the duty cycle
	# climb on its own -- an instrument that reports the death as dread.
	if _metabolism != null and _metabolism.is_processing():
		_run_seconds += delta
		_dread_area += _food.dread_level * delta
		if _food.dread_level > 0.05:
			_dread_seconds += delta
	if _have_last_pos:
		_travelled += _last_pos.distance_to(cell.position)
		_speed_clock += delta
	_last_pos = cell.position
	_have_last_pos = true


## Parks whatever the shot needs at a fixed body-relative bearing and range.
## Runs after the simulation has moved, so the range is exact in the frame that
## is photographed. This is the harness reaching into the world on purpose; the
## game itself has no such hook and must not grow one.
func _hold_world() -> void:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return
	if _stalk >= 0.0 and _food != null:
		_place(0, _hold_point(_stalk, 40.0))
	if _food_at >= 0.0 and _food != null:
		# Reaching for a private member is a thing only tools/ is allowed to do.
		# The bodies are objects rather than packed arrays now, so this writes
		# through instead of handing a whole array back.
		_place(1, _hold_point(_food_at, -35.0))
	if _starve >= 0.0 and _metabolism != null:
		_metabolism.starve_seconds = maxf(_metabolism.starve_seconds, _starve)
	if _gain >= 0.0 and _bus != null:
		_bus.gain = _gain


func _hold_point(distance: float, bearing_deg: float) -> Vector2:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return Vector2.ZERO
	var b := deg_to_rad(bearing_deg)
	var dir: Vector2 = cell.forward() * cos(b) + cell.starboard() * sin(b)
	return cell.position + dir * distance


## Press once, then walk sideways a few frames: the same shape of event stream a
## thumb produces, including the mouse events Godot emulates from touch.
func _step_drag() -> void:
	var mid := get_viewport().get_visible_rect().size * 0.5
	if _drag_step == 0:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.pressed = true
		down.position = mid
		Input.parse_input_event(down)
	elif _drag_step <= 8:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = mid + Vector2(_drag_px * _drag_step / 8.0, 0.0)
		Input.parse_input_event(drag)
	_drag_step += 1


## Pausing the tree freezes the simulation, but the membrane layer deliberately
## keeps beating through a pause -- so for a photograph the bus has to be made
## pausable first, or the envelopes decay away while the shot harness waits.
func _freeze() -> void:
	if get_tree().paused:
		return
	# The game deliberately keeps its membrane and its run node alive through a
	# pause. For a photograph everything under the scene has to stop, or the
	# envelopes decay and the death sequence runs on while the shot harness is
	# still waiting.
	if _run != null:
		_make_pausable(_run)
	if _bus != null:
		_bus.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	print("[drive] %5.2f  frozen" % _clock)


func _make_pausable(node: Node) -> void:
	if node.process_mode == Node.PROCESS_MODE_ALWAYS:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	for child in node.get_children():
		_make_pausable(child)


func _on_sensation(kind: StringName, info: Dictionary) -> void:
	var bearing := ""
	if info.has("bearing"):
		bearing = "  bearing %+6.1f deg" % rad_to_deg(float(info["bearing"]))
	var strength := ""
	if info.has("strength"):
		strength = "  strength %.2f" % float(info["strength"])
	# Parked food would be eaten again every frame, which grows the cell and
	# empties its hunger while the shot harness is still waiting. One meal is
	# what was wanted.
	if kind == &"ingest":
		_food_at = -1.0
		_meals += 1
		print("[drive] %5.2f  meal %d" % [_clock, _meals])
	if kind == &"taste":
		_taste_bearing = float(info.get("bearing", 0.0))
		_taste_c = float(info.get("strength", 0.0))
	if kind == &"shove" and _run != null:
		var cell := _find_node_with(_run, &"bearing_to")
		if cell != null:
			_wake_world = cell.heading + float(info.get("bearing", 0.0))
			_have_wake = true
	# taste fires every frame by design; only the interesting ones are worth a line.
	if kind == &"taste" or kind == &"shear":
		return
	print("[drive] %5.2f  %-7s%s%s" % [_clock, kind, bearing, strength])
	if _freeze_on != "" and str(kind) == _freeze_on and _clock >= _arm_at:
		if _freeze_after >= 0.0:
			if _freeze_at < 0.0:
				_freeze_at = _clock + _freeze_after
		elif _freeze_countdown < 0:
			_freeze_countdown = maxi(_freeze_delay, 1)


func _keycode(name: String) -> Key:
	match name.to_lower():
		"esc": return KEY_ESCAPE
		"enter": return KEY_ENTER
		"up": return KEY_UP
		"down": return KEY_DOWN
		"left": return KEY_LEFT
		"right": return KEY_RIGHT
		"v": return KEY_V
		_: return KEY_NONE


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


## The bus is a node called Signals under the membrane layer; found by walking
## rather than by path so this keeps working if the scene is rearranged.
func _find_bus(node: Node) -> Node:
	return _find_node_with(node, &"set_beat")


## By script path, because two fields can share a method name and the harness
## needs a specific one.
func _find_script(node: Node, path: String) -> Node:
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path == path:
		return node
	for child in node.get_children():
		var found := _find_script(child, path)
		if found != null:
			return found
	return null


func _find_node_with(node: Node, method: StringName) -> Node:
	if node.has_method(method):
		return node
	for child in node.get_children():
		var found := _find_node_with(child, method)
		if found != null:
			return found
	return null


# ---------------------------------------------------------------------------
# Reaching into the world on purpose. The game has no hooks for any of this and
# must not grow any: a simulation that can be posed from outside is one that can
# be posed by accident.
# ---------------------------------------------------------------------------

## Turns field cell [param index] into something that can eat the player, puts
## it at [param at] and starts its run. The gape multiple is the whole point of
## the handle: at 1.40 it is terrifying, at 0.90 it can still eat you but dread
## barely registers, and at 0.80 it cannot.
func _make_hunter(index: int, at: Vector2) -> void:
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null or _food == null:
		return
	var bodies: Array = _food.get("_cells")
	if index >= bodies.size():
		return
	var b: Object = bodies[index]
	# A body the player's own size, with whatever mouth the test asked for. The
	# tier ladder is coarse, so the multiple is written straight into the body
	# rather than approximated by a tier -- this is a measuring instrument.
	b.set("radius", cell.radius)
	b.set("drifter", false)
	b.set("genome", {&"cytostome": 3, &"flagellum": 2})
	b.set("pos", at)
	b.set("state", FoodField.State.STALK)
	b.set("target", FoodField.TARGET_PLAYER)
	b.set("aim", cell.position)
	b.set("aim_clock", 0.0)
	b.set("lost", 0.0)
	b.set("rush", 0.0)
	b.set("best", INF)
	b.set("lunging", false)
	b.set("stroke", 0.2)
	b.set("heading", atan2((cell.position - at).x, -(cell.position - at).y))
	# Scale the radius so the gape comes out at exactly the multiple asked for.
	var tier_gape: float = CellBody.GAPE_BY_TIER[3]
	b.set("radius", cell.radius * _hunter_gape / tier_gape)
	print("[drive] hunter %d: r%.1f gape %.1f against your r%.1f" % [
		index, b.get("radius"), _food.gape_at(index), cell.radius])


func _place(index: int, at: Vector2) -> void:
	var bodies: Array = _food.get("_cells")
	if index < bodies.size():
		bodies[index].set("pos", at)


## `cytostome:3,cirrus:2` -- straight into the genome node, before the first
## frame, so the cell boots as whatever the measurement needs it to be.
func _force_genome(spec: String) -> void:
	var tiers: Dictionary = _genome.tiers()
	tiers.clear()
	for pair in spec.split(",", false):
		var bits := str(pair).split(":")
		if bits.size() == 2:
			tiers[StringName(bits[0].strip_edges())] = int(bits[1])
	print("[drive] genome forced to %s, upkeep %.2f" % [
		_genome_text(tiers), _genome.upkeep()])


## §1.3's distribution, measured rather than argued about. Reseeds the whole
## field over and over at a range of player radii and reports what actually
## comes out -- above all whether the field is ever left with no drifter in it,
## which is the invariant the "there is always a way back" claim rests on.
func _run_seeding_check(rounds: int) -> void:
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null or _food == null:
		print("[check] no simulation to seed")
		return
	var bodies: Array = _food.get("_cells")
	var drifterless := 0
	var min_drifters := 99
	var drifters := 0
	var seeds := 0
	var max_gape := 0.0
	var max_radius := 0.0
	var tier_counts := {0: 0, 1: 0, 2: 0, 3: 0}
	var edible := 0
	var dangerous := 0
	var both := 0
	var buckets := {}

	for round_index in rounds:
		# Sweep the player across the whole arc, because half of §1.3 is the
		# claim that the water is a different picture at r26 and at r40.
		cell.radius = lerpf(CellBody.BASE_RADIUS, 40.0,
			float(round_index % 15) / 14.0)
		_food.setup(cell)
		for k in bodies.size():
			_food.call("_seed", k)
			var live := 0
			for i in bodies.size():
				if bodies[i].get("drifter"):
					live += 1
			min_drifters = mini(min_drifters, live)
			if live == 0:
				drifterless += 1
		for i in bodies.size():
			seeds += 1
			var b: Object = bodies[i]
			var radius: float = b.get("radius")
			var gape: float = _food.gape_at(i)
			if b.get("drifter"):
				drifters += 1
			max_gape = maxf(max_gape, gape)
			max_radius = maxf(max_radius, radius)
			var tier: int = int((b.get("genome") as Dictionary).get(&"cytostome", 0))
			tier_counts[tier] = int(tier_counts[tier]) + 1
			var i_eat: bool = radius < cell.gape()
			var it_eats: bool = cell.radius < gape
			if i_eat and it_eats:
				both += 1
			elif i_eat:
				edible += 1
			elif it_eats:
				dangerous += 1
			# The claim §1.3 had to produce: the born cell and the full-grown
			# cell must not be looking at the same picture at two zoom levels.
			var bucket := int(roundf(cell.radius))
			if not buckets.has(bucket):
				buckets[bucket] = [0, 0, 0, 0]
			var row: Array = buckets[bucket]
			row[0] += 1
			if i_eat and it_eats:
				row[3] += 1
			elif i_eat:
				row[1] += 1
			elif it_eats:
				row[2] += 1

	print("[check] %d rounds, %d seeded bodies" % [rounds, seeds])
	print("[check] drifter-free fields: %d  (minimum drifters seen in a field: %d)"
		% [drifterless, min_drifters])
	print("[check] drifters %.1f%%  cytostome tiers 0/1/2/3: %d/%d/%d/%d" % [
		100.0 * float(drifters) / float(maxi(seeds, 1)),
		tier_counts[0], tier_counts[1], tier_counts[2], tier_counts[3]])
	print("[check] max radius %.2f  max gape %.2f  (ARRIVAL_GAPE_MAX %.1f)" % [
		max_radius, max_gape, FoodField.ARRIVAL_GAPE_MAX])
	for bucket: int in [26, 33, 40]:
		if not buckets.has(bucket):
			continue
		var row: Array = buckets[bucket]
		var n := float(maxi(int(row[0]), 1))
		print("[check] a player at r%d, out of %d bodies: edible %.0f%%  eats me %.0f%%  both %.0f%%  standoff %.0f%%" % [
			bucket, int(row[0]), 100.0 * float(row[1]) / n, 100.0 * float(row[2]) / n,
			100.0 * float(row[3]) / n,
			100.0 * float(int(row[0]) - int(row[1]) - int(row[2]) - int(row[3])) / n])
	print("[check] relationship to the player: edible %.1f%%  eats me %.1f%%  both %.1f%%  standoff %.1f%%" % [
		100.0 * float(edible) / float(maxi(seeds, 1)),
		100.0 * float(dangerous) / float(maxi(seeds, 1)),
		100.0 * float(both) / float(maxi(seeds, 1)),
		100.0 * float(seeds - edible - dangerous - both) / float(maxi(seeds, 1))])


## How far field cell [param index] is from the player right now.
func _away(index: int) -> float:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null or _food == null:
		return 0.0
	return _food.points()[index].distance_to(cell.position)
