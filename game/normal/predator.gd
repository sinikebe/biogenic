extends Node
## The thing that is bigger than you.
##
## It is inedible *for now*, and not by species: you can eat anything smaller
## than you and anything bigger can eat you. One comparison, no tag. The
## predator never changes; the player does, half a unit of radius at a time, and
## the readout of that growth is that dread itself fades -- the player feels
## themselves stop being afraid of it long before they could eat it.
## docs/design/food-and-predators.md §4.1.
##
## It makes itself known on two channels, neither of which is a position:
##
## - **dread**, a scalar with no bearing *by mechanism* -- its metabolites
##   saturate the chemoreceptor, and a blocked receptor has no differential to
##   read a direction from. Dread also costs: taste drops to 40% and its bearing
##   jitter doubles, so a hunted cell cannot smell its way out of the problem.
## - **the pressure wake**, one dent per stroke of its flagellum, at its true
##   bearing. The only directional information it ever gives, and intermittent
##   by construction: each wake says where it *was*. The imprecision is in the
##   interval, never in the angle.
##
## Like food, this node computes and does not post. Continuous state is read
## once a frame by whoever owns the run; discrete events are signals.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")

## One stroke of the flagellum, felt at its true bearing. [param strength] is
## 0..1; the cap lives in the signal bus, which owns every envelope.
signal waked(bearing: float, strength: float)
## The membrane closes and you are gone. [param bearing] is where it came from.
signal killed(bearing: float)

## Bigger than the cell's 26, and it stays 40 forever.
const RADIUS := 40.0

# --- Dread ------------------------------------------------------------------
const DREAD_RANGE := 1400.0
const DREAD_CORE := 240.0
const DREAD_CAP := 0.95
## The ratio window. At cell radius 26 this is 1.0; it falls away as the player
## grows, which is the best available readout of a growth curve on a screen with
## no numbers on it.
const THREAT_LOW := 0.85
const THREAT_HIGH := 1.35

# --- The wake ---------------------------------------------------------------
const WAKE_RANGE := 760.0
const WAKE_CORE := 170.0
const STROKE_GAP := 1.45
const STROKE_JITTER := 0.35
## Inside this the stroke gap halves, the wake strength pins and it swims at
## LUNGE. This is the sprint, not the decision.
const LUNGE_RANGE := 220.0
## Inside this it stops correcting: one solution, then a straight line through
## whatever happens next. The decision is made well before the sprint, which is
## why the skill the encounter tests is committing early.
##
## Everything about the dodge lives in this number, and it was measured, not
## chosen. The prediction is a straight line; a cell holding full steer curves
## off one by roughly 130 units over the run this buys, against the 66 the two
## bodies together are wide. At 220 the run is only 2.3s and the curve is 87 --
## a committed turn was eaten about a third of the time. At 420 a cell swimming
## straight stops being caught, which breaks the other half of §5.4. At 310,
## over 14 seeds each: never-steers caught 11/14, commits-away escapes 13/14.
const COMMIT_RANGE := 310.0

# --- Swimming ---------------------------------------------------------------
## 1.20x the cell's measured 56.5 net units/s, and 1.70x when it commits. You
## cannot outswim it -- which is why dread does not mean "flee", it means commit
## away from that bearing now, before it lunges.
const CRUISE := 68.0
const LUNGE := 96.0
## What it believes about its prey, for the lead it swims at. Measured over 40
## seeds of the shipped drive model. §4.3.
const PREY_SPEED := 56.5
## It turns decisively but not instantly, and it is chasing where the cell was
## going, not where the cell is.
const TURN_RATE := 0.62
const WANDER_RATE := 0.09
const WANDER_TAU := 3.2

# --- The escape window ------------------------------------------------------
## The contract, §5.4, stated on the game rather than on this AI: from the
## moment the cell's steering is committed more than 90 degrees away from the
## last wake bearing and stays committed, dread must begin falling within this,
## and the predator must break off. A cell that does nothing must be caught.
##
## It is the p90 time for the shipped drive model to swing its velocity 120
## degrees. The window cannot be made shorter than about six seconds -- the cell
## physically cannot turn faster -- so anything below 7 is cruelty by arithmetic.
const ESCAPE_SECONDS := 7.0
## Free tracking, out where the cell has no bearing to act on anyway.
const AIM_GAP := 1.45
## **The window.** Once it is inside wake range it has committed to an attack
## run, and it swims at a solution this many seconds old. Seven is not a guess:
## it is the p90 time for the cell to swing its velocity 120 degrees, and the
## cell physically cannot turn faster, so anything shorter is cruelty by
## arithmetic.
const LOCK_SECONDS := 7.0
## It re-acquires only while the cell is still roughly where it is swimming. A
## cell that gets outside this and stays outside has broken the pursuit.
const LOCK_CONE_DEG := 70.0
## How many times to settle the intercept. The time to reach the aim depends on
## where the aim is, which depends on the time: three passes is convergence.
const INTERCEPT_STEPS := 3
## Long enough that one frame of geometry cannot end a chase; short enough that
## LOST_GRACE + the time to leave the cone stays inside ESCAPE_SECONDS.
const LOST_GRACE := 0.8
## **How the escape is actually paid off.** An attack run only ever closes; the
## moment the cell has taken this much ground back off the closest approach, the
## run has failed and the hunter sheers off. It reads as the only thing it could
## read as -- it stopped gaining -- and it is what turns a committed turn into
## relief within a few seconds rather than at the end of a timeout.
##
## Wide enough that the cell's own bursty drive cannot trip it: a coasting cell
## loses about thirty units against a cruising predator before its next impulse.
const LOST_GROUND := 90.0
## The backstop under that, for a stern chase that neither closes nor opens.
## Longer dread is longer taste blackout, which starves a player for being good
## at the game, so it is a cap and not a mechanic. §5.4.
const RUSH_SECONDS := 24.0

# --- Coming and going -------------------------------------------------------
## perception.md §2 puts the first dread at 0:45-1:00, which is this plus the
## ten seconds dread takes to arrive.
const FIRST_DELAY := 42.0
## Spawned at the edge of dread, so the water starts going wrong the moment it
## exists.
const SPAWN_MIN := 1400.0
const SPAWN_MAX := 1900.0
## The first one is authored, like mote 0 and food 0. It comes in off the beam
## rather than head-on, because head-on the two close at 124 units/s and the
## whole of perception.md §2's opening -- ten seconds of the water being wrong,
## then the first wake -- happens in five. Off the beam it closes at about
## eighty and the first encounter reads the way it was written.
const FIRST_BEARING_MIN_DEG := 65.0
const FIRST_BEARING_MAX_DEG := 115.0
## Long enough to get a meal in before the next one.
const CALM_MIN := 30.0
const CALM_MAX := 55.0
## How far along its own heading the break-off aims. Only has to be past the
## horizon; the run ends at DREAD_RANGE, not here.
const BREAK_AWAY := 3000.0

enum State { AWAY, STALK, BREAK }

## World position and heading. Public for the full-vision view, which is the
## only thing entitled to either.
var position := Vector2.ZERO
var heading := 0.0
## What the membrane should be told, 0..1. No bearing, ever.
var dread_level := 0.0
## predator radius over cell radius, through the ratio window.
var threat := 1.0

var _cell: CellBody = null
var _state := State.AWAY
var _calm := FIRST_DELAY
var _aim := Vector2.ZERO
var _aim_clock := 0.0
var _lost := 0.0
## True while the run is committed, so the pass can be seen to fail.
var _lunging := false
## Closest approach so far in this attack run.
var _best := INF
var _rush := 0.0
var _stroke := 0.0
var _wander := 0.0
var _first := true


func setup(cell: CellBody) -> void:
	_cell = cell
	_state = State.AWAY
	_calm = FIRST_DELAY
	_first = true
	dread_level = 0.0
	threat = 1.0
	position = cell.position if cell != null else Vector2.ZERO


## Is there anything out there at all. For the full-vision view.
func hunting() -> bool:
	return _state != State.AWAY


## Puts it in the water at [param at] and starts the hunt. Used by the respawn
## and by the dev harness, which needs a predator at a known range to photograph.
func enter(at: Vector2) -> void:
	position = at
	_state = State.STALK
	_lost = 0.0
	_rush = 0.0
	_aim_clock = 0.0
	_lunging = false
	_best = INF
	_stroke = randf_range(0.2, STROKE_GAP)
	_wander = 0.0
	if _cell != null:
		heading = _angle_of(_cell.position - position)
		_aim = _cell.position


func forward() -> Vector2:
	return Vector2(sin(heading), -cos(heading))


## Where the next one comes from. Off the cell's beam the first time, anywhere
## after that -- by then the player knows what dread means.
func _spawn_offset() -> Vector2:
	var distance := randf_range(SPAWN_MIN, SPAWN_MAX)
	if not _first:
		var angle := randf_range(-PI, PI)
		return Vector2(cos(angle), sin(angle)) * distance
	var bearing := randf_range(
		deg_to_rad(FIRST_BEARING_MIN_DEG), deg_to_rad(FIRST_BEARING_MAX_DEG))
	if randf() < 0.5:
		bearing = -bearing
	return (_cell.forward() * cos(bearing) + _cell.starboard() * sin(bearing)) * distance


func _process(delta: float) -> void:
	if _cell == null:
		return

	if _state == State.AWAY:
		dread_level = 0.0
		_calm -= delta
		if _calm <= 0.0:
			enter(_cell.position + _spawn_offset())
			_first = false
		return

	var offset := _cell.position - position
	var d := offset.length()
	threat = smoothstep(THREAT_LOW, THREAT_HIGH, RADIUS / maxf(_cell.radius, 0.001))

	if _state == State.BREAK:
		dread_level = 0.0
		# It leaves at the speed it attacked with. A predator that saunters off
		# at cruise stays inside dread range for a minute and a half, which is a
		# minute and a half of nothing happening to a player who just earned
		# something. Gone past dread range is gone.
		_swim(delta, LUNGE)
		if d > DREAD_RANGE:
			_state = State.AWAY
			_calm = randf_range(CALM_MIN, CALM_MAX)
		return

	if d < _cell.radius + RADIUS:
		dread_level = 0.0
		killed.emit(_cell.bearing_to(position))
		_break_off()
		return

	_step_aim(delta, d, offset)
	if _state != State.STALK:
		return

	_swim(delta, LUNGE if d < LUNGE_RANGE else CRUISE)

	# Dread. Scalar, no bearing, and scaled by how much bigger than you it still
	# is. Nine seconds of closing separate the first dread from the first wake:
	# ten seconds of the water simply being wrong, then a direction.
	var near := clampf((DREAD_RANGE - d) / (DREAD_RANGE - DREAD_CORE), 0.0, 1.0)
	dread_level = near * threat * DREAD_CAP

	_stroke -= delta
	if _stroke <= 0.0:
		var committed := d < LUNGE_RANGE
		_stroke = STROKE_GAP * (0.5 if committed else 1.0) \
			+ randf_range(-STROKE_JITTER, STROKE_JITTER) * (0.5 if committed else 1.0)
		if d < WAKE_RANGE:
			# No bearing jitter. The imprecision is in the interval.
			var push := 1.0 if committed else smoothstep(WAKE_RANGE, WAKE_CORE, d)
			waked.emit(_cell.bearing_to(position), push)


## Course corrections, and the one way out of them.
##
## Outside wake range it tracks freely -- there is nothing the player could do
## about it anyway, because there is no bearing yet. Inside, it has committed to
## an attack run: it swims at a solution that goes stale, and it only re-acquires
## while the cell is still roughly ahead of it. A cell that turns hard and keeps
## turning walks out of that cone while the predator is still swimming at where
## it would have been.
func _step_aim(delta: float, d: float, offset: Vector2) -> void:
	if d > WAKE_RANGE:
		_lost = 0.0
		_rush = 0.0
		_lunging = false
		_best = INF
		_aim_clock -= delta
		if _aim_clock <= 0.0:
			_aim_clock = AIM_GAP
			_aim = _intercept(d)
		return

	_rush += delta
	_best = minf(_best, d)
	var off := absf(angle_difference(heading, _angle_of(offset)))
	if off > deg_to_rad(LOCK_CONE_DEG):
		_lost += delta
	else:
		_lost = 0.0

	if _lost >= LOST_GRACE or _rush >= RUSH_SECONDS or d > _best + LOST_GROUND:
		_break_off()
		return

	if d > COMMIT_RANGE:
		_lunging = false
		_aim_clock -= delta
		if _aim_clock <= 0.0:
			_aim_clock = LOCK_SECONDS
			_aim = _intercept(d)
		return

	# Committed. One fresh solution at the moment the run starts, and then
	# nothing: once it begins at 220 units the encounter is over in 2.3 seconds,
	# and a predator that corrects through the lunge cannot be dodged at all.
	if not _lunging:
		_lunging = true
		_aim = _intercept(d)
		return
	# The pass is over the moment the aim point is behind it. No contact by then
	# is a clean miss, and a clean miss ends the encounter.
	if (_aim - position).dot(forward()) <= 0.0:
		_break_off()


## Where the cell will be, if it keeps doing what it is doing.
##
## Two terms, because the cell's motion has two parts: the average drift along
## the heading it is holding, and the transient of being faster or slower than
## that average right now. The first is made along its *heading* -- precisely
## the thing a turning player changes, and therefore the whole of the dodge.
## The answer is always a straight line, and a cell that keeps turning is never
## on one.
func _intercept(d: float) -> Vector2:
	var speed := maxf(LUNGE if d < LUNGE_RANGE else CRUISE, 1.0)
	var t := clampf(d / speed, 0.0, 9.0)
	var aim := _predict(t)
	# Settle it: how long the swim takes depends on where the aim is, and where
	# the aim is depends on how long the swim takes.
	for i in INTERCEPT_STEPS:
		t = clampf(position.distance_to(aim) / speed, 0.0, 9.0)
		aim = _predict(t)
	return aim


## Where the cell drifts to in [param t] seconds if it keeps this heading, plus
## the transient of being faster or slower than its own average right now,
## coasting out under the water's drag. No free parameter in either term.
func _predict(t: float) -> Vector2:
	var cruise := _cell.forward() * PREY_SPEED
	var k := maxf(CellBody.DRAG, 0.001)
	return _cell.position + cruise * t + (_cell.velocity - cruise) * ((1.0 - exp(-k * t)) / k)


func _break_off() -> void:
	_state = State.BREAK
	dread_level = 0.0
	_lost = 0.0
	_rush = 0.0
	if _cell != null:
		# Away, but not a handbrake turn: it sheers off the line it was on.
		var away := _angle_of(position - _cell.position)
		_aim = position + Vector2(sin(away), -cos(away)) * BREAK_AWAY


func _swim(delta: float, speed: float) -> void:
	var want := _angle_of(_aim - position)
	var turn := clampf(angle_difference(heading, want), -TURN_RATE * delta, TURN_RATE * delta)
	_wander = lerpf(_wander, randf_range(-WANDER_RATE, WANDER_RATE),
		1.0 - exp(-delta / WANDER_TAU))
	heading = wrapf(heading + turn + _wander * delta, -PI, PI)
	position += forward() * speed * delta


## Same convention as the cell: radians clockwise from world north, front is the
## top of the screen.
func _angle_of(v: Vector2) -> float:
	if v.length_squared() <= 0.0:
		return heading
	return atan2(v.x, -v.y)
