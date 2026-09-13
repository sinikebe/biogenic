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

## Body radius in world units, used for contact.
const RADIUS := 26.0

# --- Drive -----------------------------------------------------------------
## Speed added along the heading by one flagellar beat.
const IMPULSE_SPEED := 138.0
## Seconds between impulses, resampled after each one.
const IMPULSE_GAP_MIN := 1.7
const IMPULSE_GAP_MAX := 3.6
## The organelle does not aim well: each impulse strays this far off the heading
## and kicks the heading itself by about this much.
const IMPULSE_SPREAD := 0.24
const IMPULSE_KICK := 0.16
## Water is thick at this scale. Velocity loses 1/e of itself every 1/DRAG s.
const DRAG := 0.74

# --- Steering --------------------------------------------------------------
## Flat out, the cell turns this fast: about 35 deg/s, so a half turn costs five
## seconds. Slow on purpose.
const TURN_RATE_MAX := 0.62
## Seconds for the turn to actually build. The lag is what makes steering feel
## like leaning on something rather than driving it.
const TURN_RESPONSE := 1.1
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


func _process(delta: float) -> void:
	steer = _read_steer()

	_omega = lerpf(_omega, steer * TURN_RATE_MAX, 1.0 - exp(-delta / TURN_RESPONSE))
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
	_impulse_timer = randf_range(IMPULSE_GAP_MIN, IMPULSE_GAP_MAX)
	heading = wrapf(heading + randf_range(-IMPULSE_KICK, IMPULSE_KICK), -PI, PI)
	var strength := randf_range(0.7, 1.0)
	var aim := heading + randf_range(-IMPULSE_SPREAD, IMPULSE_SPREAD)
	velocity += Vector2(sin(aim), -cos(aim)) * IMPULSE_SPEED * strength
	impulsed.emit(strength)


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
	var turning := _omega / TURN_RATE_MAX
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
