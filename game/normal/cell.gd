extends Node
## The player's cell: a position, a heading, and a drive that is not obedient.
##
## The basic cell has one organelle and no steering muscle worth the name. It
## fires a random forward impulse on its own schedule and coasts; the player can
## lean on its orientation, slowly. Movement being sluggish and slippery is the
## design, not a bug to be tuned out -- see docs/design/perception.md §2, where
## the whole opening depends on drift the player does not command.
##
## Nothing here is drawn. The cell *is* the viewport; what it feels comes out on
## the membrane.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## Emitted when an impulse fires, so the membrane can bloom at the front.
signal impulsed(strength: float)

## Body radius in world units. A variable, not a constant, because it is the one
## number in the game that means three things at once: what can eat me, what I
## can eat, and how much genome I can carry.
## docs/design/genes-and-cilia.md §1.1 and §3.1.
const BASE_RADIUS := 26.0
## One meal, one unit of radius. Phase 4 shipped 0.5 as an admitted placeholder;
## §3.1 makes the ladder a count of meals, so fourteen meals is a full genome
## and a 14-21 minute arc -- a session, not a campaign.
const GROWTH_PER_MEAL := 1.0

var radius := BASE_RADIUS

## The genome this cell wears. Written by normal_mode.gd, which is the only
## place the two halves are introduced to each other.
##
## Deliberately typed as plain [Node]: genome.gd preloads *this* file for the
## slot ladder, and a preload back the other way is a cycle GDScript will not
## resolve. Null is legal and means the born cell -- nothing in here may assume
## the wiring has happened, because a headless boot builds this node first.
var genome: Node = null

# --- The gape --------------------------------------------------------------
## How wide the mouth opens, as a multiple of body radius, by cytostome tier.
## Index 0 is a cell with no mouth at all, which is a real state: drifters have
## no cytostome, and §9.7 lets the player put a fourth gene over their own.
##
## **This is the whole edibility rule.** A can eat B when `B.radius < A.gape()`,
## evaluated in both directions independently, which is what makes a small cell
## with an enormous mouth both prey and predator. §1.1.
const GAPE_BY_TIER: Array[float] = [0.58, 0.82, 1.05, 1.40]

# --- Slots -----------------------------------------------------------------
## Genome size is capacity, not currency: one more slot per this much growth.
## Three slots at birth, seven at radius 40 -- the same radius at which nothing
## the water seeds can swallow you. §3.1.
const SLOT_RADIUS := 3.5
const SLOT_MIN := 3
const SLOT_MAX := 7

# --- Drive -----------------------------------------------------------------
# Every number in this block is indexed by a gene tier rather than fixed, and
# the mapping lives here -- next to the constant it replaces -- for the same
# reason perception.md §6.2 put the hunger-to-beat mapping in one place. §7.2.
#
# Tier 0 is the cell that has lost this organ entirely (§9.7 allows it). It is
# **not in the design**: it is extrapolated one step below tier 1 on the
# ladder's own spacing, which is the least invented answer available.

## Speed added along the heading by one flagellar beat, by `flagellum` tier.
const IMPULSE_SPEED_BY_TIER: Array[float] = [118.0, 138.0, 162.0, 190.0]
## Seconds between impulses, resampled after each one, by `flagellum` tier.
const IMPULSE_GAP_MIN_BY_TIER: Array[float] = [2.00, 1.70, 1.45, 1.20]
const IMPULSE_GAP_MAX_BY_TIER: Array[float] = [4.30, 3.60, 3.00, 2.50]
## Mean of the per-impulse strength roll below, for [method speed_for].
const IMPULSE_MEAN := 0.85
## Net speed over path speed. One impulse of v0 decaying at DRAG contributes
## exactly v0/DRAG of displacement however long it is left to, so a train of
## them every T seconds makes v0/(DRAG*T) along the heading and there is no free
## parameter in it -- except that the heading is not straight. This is the
## measured shortfall, set so a tier-1 cell comes out at the 56.5 u/s that
## Phase 4 measured over 40 seeds and hard-coded into the pursuit.
const SPREAD_LOSS := 0.945
## The organelle does not aim well: each impulse strays this far off the heading
## and kicks the heading itself by about this much.
const IMPULSE_SPREAD := 0.24
const IMPULSE_KICK := 0.16
## Water is thick at this scale. Velocity loses 1/e of itself every 1/DRAG s.
const DRAG := 0.74

# --- Steering --------------------------------------------------------------
## Flat out, the cell turns this fast, by `cirrus` tier. Tier 1 is about
## 35 deg/s, so a half turn costs five seconds: slow on purpose. Tier 3 is
## 58 deg/s, and §7.1 gives the whole of the improved dodge to this one number.
const TURN_RATE_BY_TIER: Array[float] = [0.48, 0.62, 0.80, 1.02]
## Seconds for the turn to actually build. The lag is what makes steering feel
## like leaning on something rather than driving it; a better cirrus shortens it.
const TURN_RESPONSE_BY_TIER: Array[float] = [1.43, 1.10, 0.85, 0.65]
## The water pushes back: a slow random walk on the heading the player never
## asked for and cannot switch off.
const WANDER_RATE := 0.13
const WANDER_TAU := 2.6

# --- Input -----------------------------------------------------------------
## Canvas pixels of drag for a full-rate turn.
const DRAG_SPAN := 190.0
## Below this the player is not really steering, so onboarding stays up.
const STEER_DEADZONE := 0.12

var position := Vector2.ZERO
## Radians, clockwise from world north. Front is the top of the screen.
var heading := 0.0
var velocity := Vector2.ZERO
## Signed steering demand, -1 hard to port .. +1 hard to starboard.
var steer := 0.0

var _omega := 0.0
var _wander := 0.0
var _impulse_timer := 0.0
## -2 nothing held, -1 the mouse, >= 0 the touch index that owns the drag.
var _pointer := -2
var _pointer_anchor := 0.0
var _pointer_x := 0.0


func _ready() -> void:
	_impulse_timer = randf_range(0.6, 1.4)


## A new cell in new water, for the restart after a death.
func reset() -> void:
	position = Vector2.ZERO
	heading = randf_range(-PI, PI)
	velocity = Vector2.ZERO
	radius = BASE_RADIUS
	_omega = 0.0
	_wander = 0.0
	_impulse_timer = randf_range(0.6, 1.4)
	release()


func _process(delta: float) -> void:
	steer = _read_steer()

	_omega = lerpf(_omega, steer * turn_rate(), 1.0 - exp(-delta / turn_response()))
	# Ornstein-Uhlenbeck-ish drift: a heading nudge that wanders instead of
	# buzzing, so it reads as current rather than as noise.
	var pull := 1.0 - exp(-delta / WANDER_TAU)
	_wander = lerpf(_wander, randf_range(-WANDER_RATE, WANDER_RATE), pull)
	heading = wrapf(heading + (_omega + _wander) * delta, -PI, PI)

	_impulse_timer -= delta
	if _impulse_timer <= 0.0:
		_fire_impulse()

	velocity *= exp(-DRAG * delta)
	position += velocity * delta


func _fire_impulse() -> void:
	_impulse_timer = randf_range(impulse_gap_min(), impulse_gap_max())
	heading = wrapf(heading + randf_range(-IMPULSE_KICK, IMPULSE_KICK), -PI, PI)
	var strength := randf_range(0.7, 1.0)
	var aim := heading + randf_range(-IMPULSE_SPREAD, IMPULSE_SPREAD)
	velocity += Vector2(sin(aim), -cos(aim)) * impulse_speed() * strength
	impulsed.emit(strength)


# ---------------------------------------------------------------------------
# What the genome buys. Every one of these is a read, not a stored value: a
# gene integrated mid-run has to take effect on the next frame, and a cached
# copy is one more thing that can be stale when it matters.
# ---------------------------------------------------------------------------

## Tier of one gene, 1 if there is no genome attached yet -- the born cell is
## tier 1 across the board, so an unwired cell behaves exactly as Phase 4 did.
func tier(gene: StringName) -> int:
	return genome.tier(gene) if genome != null else 1


## How wide this cell's mouth opens, in world units. Anything whose radius is
## below this fits in it, and nothing else does.
func gape() -> float:
	return gape_of(tier(&"cytostome"), radius)


## How many genes this body can carry.
func slots() -> int:
	return slots_for(radius)


func impulse_speed() -> float:
	return IMPULSE_SPEED_BY_TIER[_tier_index(tier(&"flagellum"))]


func impulse_gap_min() -> float:
	return IMPULSE_GAP_MIN_BY_TIER[_tier_index(tier(&"flagellum"))]


func impulse_gap_max() -> float:
	return IMPULSE_GAP_MAX_BY_TIER[_tier_index(tier(&"flagellum"))]


func turn_rate() -> float:
	return TURN_RATE_BY_TIER[_tier_index(tier(&"cirrus"))]


func turn_response() -> float:
	return TURN_RESPONSE_BY_TIER[_tier_index(tier(&"cirrus"))]


## The net speed this cell actually makes, which is what anything chasing it
## has to lead. §7.1: this replaces Phase 4's hard-coded 56.5, so the chase
## stays a chase at every tier and only `cirrus` improves the dodge.
func swim_speed() -> float:
	return speed_for(tier(&"flagellum"))


# --- The same, for a cell that is not this one -----------------------------
# Every other body in the water is a `{gene: tier}` dictionary in food.gd, not
# a node. These are how it asks the same questions, so there is exactly one
# definition of what a tier buys.

static func gape_of(cytostome_tier: int, body_radius: float) -> float:
	return GAPE_BY_TIER[_tier_index(cytostome_tier)] * body_radius


static func slots_for(body_radius: float) -> int:
	return clampi(SLOT_MIN + int((body_radius - BASE_RADIUS) / SLOT_RADIUS),
		SLOT_MIN, SLOT_MAX)


static func turn_rate_for(cirrus_tier: int) -> float:
	return TURN_RATE_BY_TIER[_tier_index(cirrus_tier)]


static func speed_for(flagellum_tier: int) -> float:
	var index := _tier_index(flagellum_tier)
	var gap := (IMPULSE_GAP_MIN_BY_TIER[index] + IMPULSE_GAP_MAX_BY_TIER[index]) * 0.5
	return IMPULSE_SPEED_BY_TIER[index] * IMPULSE_MEAN * SPREAD_LOSS / (DRAG * gap)


static func _tier_index(value: int) -> int:
	return clampi(value, 0, GAPE_BY_TIER.size() - 1)


## World direction the cell is facing.
func forward() -> Vector2:
	return Vector2(sin(heading), -cos(heading))


## World direction off the cell's right flank.
func starboard() -> Vector2:
	return Vector2(cos(heading), sin(heading))


## Body-relative bearing of a world point: radians clockwise from the front,
## which is the only way this game is allowed to describe a direction.
func bearing_to(point: Vector2) -> float:
	var offset := point - position
	return atan2(offset.dot(starboard()), offset.dot(forward()))


## How hard the membrane should be shearing right now, signed and normalised.
##
## Takes the larger of demand and actual rotation on purpose. The turn itself
## builds over about a second, but the wash has to answer the same frame the
## player pushes -- that answer is the only proof they are connected to
## anything, and a second of lag destroys it.
func shear_rate() -> float:
	var turning := _omega / turn_rate()
	return steer if absf(steer) > absf(turning) else turning


## Knocked off course by something solid. [param normal] points from the thing
## into the cell.
func bump(normal: Vector2, restitution: float = 0.55) -> void:
	var into := velocity.dot(-normal)
	if into <= 0.0:
		return
	velocity += normal * into * (1.0 + restitution)
	position += normal * 2.0


## Drops any held drag. Called when the game pauses, so a finger still down when
## the pause opened does not keep steering afterwards.
func release() -> void:
	_pointer = -2
	steer = 0.0


# ---------------------------------------------------------------------------
# Input. Drag on touch, A/D or the arrows on desktop; both work at once and
# neither costs a pixel of screen.
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Touch is read straight, and the mouse only claims the pointer when touch
	# has not. Godot emulates mouse events from touch by default, so the two
	# arrive as a pair on Android; this is what stops them fighting. Positions
	# are absolute rather than relative for the same reason -- a duplicated
	# event then changes nothing.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _pointer == -2:
				_grab(touch.index, touch.position.x)
		elif _pointer == touch.index:
			release()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _pointer == drag.index:
			_pointer_x = drag.position.x
		return

	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			if _pointer == -2:
				_grab(-1, click.position.x)
		elif _pointer == -1:
			release()
		return

	if event is InputEventMouseMotion and _pointer == -1:
		_pointer_x = (event as InputEventMouseMotion).position.x


func _grab(index: int, x: float) -> void:
	_pointer = index
	_pointer_anchor = x
	_pointer_x = x


func _read_steer() -> float:
	var keys := 0.0
	if Input.is_action_pressed(&"ui_left") or Input.is_key_pressed(KEY_A):
		keys -= 1.0
	if Input.is_action_pressed(&"ui_right") or Input.is_key_pressed(KEY_D):
		keys += 1.0
	if keys != 0.0:
		return keys
	if _pointer == -2:
		return 0.0
	return clampf((_pointer_x - _pointer_anchor) / DRAG_SPAN, -1.0, 1.0)
