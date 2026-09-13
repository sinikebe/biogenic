extends Node
## The membrane's signal bus: the one node that writes membrane shader uniforms.
##
## Gameplay never touches the shader. It posts sensations -- [method taste],
## [method shove], [method hit], [method dread], [method ingest], plus the two
## self-signals [method thrust] and [method shear] -- and this node owns every
## envelope, every lobe slot and every uniform write.
##
## That indirection is the point: audio and haptics become extra subscribers to
## [signal sensation] later without the visual layer changing at all. See
## docs/design/perception.md §3 and §5.
##
## Deliberately has no class_name. Content packs mount over an older binary, and
## a global class name introduced by a pack is not in that binary's class list;
## path-based preload always resolves.

## Every posted sensation, for subscribers that are not the membrane (audio,
## haptics, telemetry). [param info] carries "bearing" (radians, clockwise from
## the cell's front) and "strength" where those make sense.
signal sensation(kind: StringName, info: Dictionary)

# --- Palette. pulse_color is the launcher's rim colour, so Play is a cut with
# --- no flash. Chemistry is the only other hue phase 1 is allowed.
const SELF_COLOR := Vector3(0.12, 0.70, 0.58)
const NUTRIENT_COLOR := Vector3(0.35, 0.88, 0.42)

# --- Measured values. Every number below is from the signal table in
# --- docs/design/perception.md §3; change them there first.
const THRUST_PEAK := 0.14
const THRUST_HALFWIDTH_DEG := 60.0
const THRUST_ATTACK := 0.06
const THRUST_DECAY := 0.5

const SHEAR_PEAK := 0.10
const SHEAR_HALFWIDTH_DEG := 84.0
const SHEAR_DECAY := 0.18

## The lingering bruise left by a contact, at the contact bearing.
const BRUISE_PEAK := 0.35
const BRUISE_HALFWIDTH_DEG := 46.0
const BRUISE_ATTACK := 0.02
const BRUISE_DECAY := 0.6

## Capped below 1.0 on purpose: a pure white contour reads as a UI error.
const FLASH_PEAK := 0.80
const FLASH_ATTACK := 0.016
const FLASH_DECAY := 0.09

const TASTE_PEAK := 0.62
const TASTE_FLOOR := 0.06
const TASTE_WIDE_DEG := 78.0
const TASTE_TIGHT_DEG := 26.0
const TASTE_JITTER_WIDE_DEG := 22.0
const TASTE_JITTER_TIGHT_DEG := 4.0
const TASTE_BEARING_TAU := 0.6
const TASTE_JITTER_HZ := 1.5

const WAKE_CAP := 0.95
const WAKE_HALFWIDTH_DEG := 34.0
const WAKE_ATTACK := 0.07
const WAKE_DECAY := 0.26

const PULSE_ATTACK := 0.09
const PULSE_DECAY := 0.42

const INGEST_ATTACK := 0.12
const INGEST_DECAY := 1.2

## Dread crosses to 0.95 in about ten seconds, and past 0.4 the beat goes
## irregular.
const DREAD_RATE := 0.095
const DREAD_JITTER_GATE := 0.4
const DREAD_JITTER := 0.3
## Under full dread the beat lands at a fifth of its strength: "the contour
## desaturates toward invisibility" in §2. The shader has no term for this -- it
## only shifts the base colour -- so it has to happen here, and measuring the
## spec's own dread render backwards gives a pulse of about 0.2. This is the one
## thing allowed to defeat the starvation floor in game/normal/metabolism.gd,
## and it is temporary by construction.
const DREAD_BEAT_FLOOR := 0.2

## How much a continuous signal has to move before subscribers are told again.
const POST_EPSILON := 0.02
const POST_ANGLE_EPSILON := 0.05

## An unused lobe: cos(halfwidth) = 2 can never be reached by a dot product.
const IDLE_LOBE := Vector4(0.0, -1.0, 2.0, 0.0)

## Lobe slots. 2 and 3 are headroom for later senses -- see §4.
const LOBE_SELF := 0
const LOBE_NUTRIENT := 1

## A linear attack/decay envelope. Impulsive signals fire it and it does the
## rest; holding a state (the probe) just fires it every frame.
class Env:
	var value := 0.0
	var bearing := 0.0
	var _attack := 0.05
	var _decay := 0.3
	var _peak := 0.0
	var _rising := false

	func _init(attack: float, decay: float) -> void:
		_attack = maxf(attack, 0.001)
		_decay = maxf(decay, 0.001)

	func fire(amp: float, at_bearing: float = 0.0) -> void:
		if amp <= value:
			# Already louder than the new hit. Keep the louder decay going and
			# keep ITS bearing: a quieter second contact must not drag the loud
			# one round to where the quiet one happened, which is a sensation
			# the player would feel as the first impact moving.
			_peak = maxf(_peak, value)
			# Deliberately not clearing _rising: a weaker hit arriving mid-attack
			# would otherwise cut the louder one off below its intended peak.
			return
		bearing = at_bearing
		_peak = amp
		_rising = true

	func step(delta: float) -> void:
		if _rising:
			value += delta * (_peak / _attack)
			if value >= _peak:
				value = _peak
				_rising = false
		elif value > 0.0:
			value -= delta * (maxf(_peak, value) / _decay)
			if value <= 0.0:
				value = 0.0
				_peak = 0.0


## Membrane sensitivity, one day a settings slider. Ships at 1.0.
var gain := 1.0

var _material: ShaderMaterial = null
var _rect := Vector2(1280.0, 720.0)
var _inset := 28.0

var _glow_lobes := PackedVector4Array([IDLE_LOBE, IDLE_LOBE, IDLE_LOBE, IDLE_LOBE])
var _press_lobes := PackedVector4Array([IDLE_LOBE, IDLE_LOBE])

var _pulse := Env.new(PULSE_ATTACK, PULSE_DECAY)
var _thrust := Env.new(THRUST_ATTACK, THRUST_DECAY)
var _bruise := Env.new(BRUISE_ATTACK, BRUISE_DECAY)
var _flash := Env.new(FLASH_ATTACK, FLASH_DECAY)
var _wake := Env.new(WAKE_ATTACK, WAKE_DECAY)
var _ingest := Env.new(INGEST_ATTACK, INGEST_DECAY)

## Shear has no attack at all -- it is the proof that the player is connected to
## something, so it must answer the same frame the turn starts.
var _shear := 0.0
var _shear_bearing := 0.0

var _taste_c := 0.0
var _taste_bearing := 0.0
var _taste_bearing_lp := 0.0
var _taste_jitter := 0.0
var _taste_jitter_clock := 0.0

var _dread := 0.0
var _dread_target := 0.0

# Last values announced on [signal sensation], for the gate above.
var _said_taste := -1.0
var _said_taste_bearing := 0.0
var _said_shear := 0.0

var _beat_period := 2.4
var _beat_amplitude := 1.0
## Randomised per beat once dread is high; recomputed at every beat.
var _beat_this_period := 2.4
var _beat_phase := 0.72


# ---------------------------------------------------------------------------
# Wiring
# ---------------------------------------------------------------------------

## Called once by the membrane layer. Nothing else hands this node a material.
func attach(material: ShaderMaterial) -> void:
	_material = material
	if _material == null:
		return
	var colors := PackedVector3Array([
		SELF_COLOR, NUTRIENT_COLOR, Vector3.ZERO, Vector3.ZERO])
	_material.set_shader_parameter("glow_colors", colors)
	_apply()


## Viewport size and contour inset, both in canvas pixels.
func set_geometry(rect: Vector2, inset: float) -> void:
	_rect = Vector2(maxf(rect.x, 1.0), maxf(rect.y, 1.0))
	_inset = maxf(inset, 0.0)


# ---------------------------------------------------------------------------
# Sensations. Everything gameplay is allowed to say to the membrane.
# ---------------------------------------------------------------------------

## Chemistry soaking through the band. Continuous: post it every frame with the
## current concentration, 0 for "nothing out there".
func taste(bearing: float, concentration: float) -> void:
	_taste_bearing = bearing
	_taste_c = clampf(concentration, 0.0, 1.0)
	# Continuous signals are posted every frame; only tell subscribers when
	# something actually moved, or this allocates sixty dictionaries a second.
	if absf(_taste_c - _said_taste) > POST_EPSILON \
			or absf(angle_difference(bearing, _said_taste_bearing)) > POST_ANGLE_EPSILON:
		_said_taste = _taste_c
		_said_taste_bearing = bearing
		sensation.emit(&"taste", {"bearing": bearing, "strength": _taste_c})


## A pressure wave: the contour dents physically inward at one bearing.
func shove(bearing: float, strength: float) -> void:
	_wake.fire(minf(strength, WAKE_CAP), bearing)
	sensation.emit(&"shove", {"bearing": bearing, "strength": strength})


## Contact. A hard flash of the whole contour plus a bruise where it landed.
func hit(bearing: float, strength: float = 1.0) -> void:
	var s := clampf(strength, 0.0, 1.0)
	_flash.fire(FLASH_PEAK * s)
	_bruise.fire(BRUISE_PEAK * s, bearing)
	sensation.emit(&"hit", {"bearing": bearing, "strength": s})


## The water going wrong. Ramps toward [param level] over about ten seconds.
func dread(level: float) -> void:
	_dread_target = clampf(level, 0.0, 1.0)
	sensation.emit(&"dread", {"strength": _dread_target})


## The one licensed flood of the interior.
func ingest() -> void:
	_ingest.fire(1.0)
	sensation.emit(&"ingest", {})


## Self-signal: the cell's own impulse blooming at its front.
func thrust(strength: float = 1.0) -> void:
	_thrust.fire(THRUST_PEAK * clampf(strength, 0.0, 1.0))
	sensation.emit(&"thrust", {"bearing": 0.0, "strength": strength})


## Self-signal: water shearing past the membrane on the outside of a turn.
## [param rate] is signed and normalised, -1 hard to port, +1 hard to starboard.
func shear(rate: float) -> void:
	var r := clampf(rate, -1.0, 1.0)
	var level := SHEAR_PEAK * absf(r)
	if level > _shear:
		_shear = level
	if absf(r) > 0.001:
		# Outside of the turn: turning to starboard shears the port flank.
		_shear_bearing = -PI * 0.5 if r > 0.0 else PI * 0.5
	if absf(r - _said_shear) > POST_EPSILON:
		_said_shear = r
		sensation.emit(&"shear", {"bearing": _shear_bearing, "strength": absf(r)})


## The metabolic beat, driven from exactly one place: see game/normal/metabolism.gd.
func set_beat(period: float, amplitude: float) -> void:
	_beat_period = maxf(period, 0.05)
	_beat_amplitude = clampf(amplitude, 0.0, 1.0)


## What the next beat will actually land with: the strength metabolism asked
## for, less whatever dread is draining out of it.
func beat_strength() -> float:
	return _beat_amplitude * lerpf(1.0, DREAD_BEAT_FLOOR, _dread)


## Fires the beat immediately at [param scale] of its current strength, for the
## probe and for a scene that wants the membrane alive on its first frame.
func pulse_now(scale: float = 1.0) -> void:
	_pulse.fire(beat_strength() * clampf(scale, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Envelopes
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_step_beat(delta)

	_pulse.step(delta)
	_thrust.step(delta)
	_bruise.step(delta)
	_flash.step(delta)
	_wake.step(delta)
	_ingest.step(delta)

	_shear = maxf(_shear - delta * (SHEAR_PEAK / SHEAR_DECAY), 0.0)
	_dread = move_toward(_dread, _dread_target, delta * DREAD_RATE)

	_step_taste(delta)
	_compose_lobes()
	_apply()


func _step_beat(delta: float) -> void:
	_beat_phase += delta / _beat_this_period
	if _beat_phase < 1.0:
		return
	_beat_phase -= floorf(_beat_phase)
	pulse_now()
	# The beat is the game's one permanent signal and the hunger readout, so it
	# is the first thing an audio layer will want to hear about.
	sensation.emit(&"beat", {"strength": beat_strength(), "period": _beat_period})
	# Past the gate the rhythm itself comes apart; that is the whole tell.
	var jitter := 1.0
	if _dread > DREAD_JITTER_GATE:
		jitter = randf_range(1.0 - DREAD_JITTER, 1.0 + DREAD_JITTER)
	_beat_this_period = maxf(_beat_period * jitter, 0.05)


func _step_taste(delta: float) -> void:
	_taste_bearing_lp = lerp_angle(
		_taste_bearing_lp, _taste_bearing, 1.0 - exp(-delta / TASTE_BEARING_TAU))
	_taste_jitter_clock += delta
	var step := 1.0 / TASTE_JITTER_HZ
	if _taste_jitter_clock >= step:
		_taste_jitter_clock = fmod(_taste_jitter_clock, step)
		var spread := deg_to_rad(lerpf(
			TASTE_JITTER_WIDE_DEG, TASTE_JITTER_TIGHT_DEG, _taste_c))
		_taste_jitter = randf_range(-spread, spread)


## Lobe 0 carries every self-sensation, so the three compete instead of summing:
## the loudest thing happening to your own skin is the thing you feel. A bruise
## (0.35) buries a thrust bloom (0.14), which is the right way round.
func _compose_lobes() -> void:
	var level := _thrust.value
	var bearing := 0.0
	var halfwidth := THRUST_HALFWIDTH_DEG
	if _shear > level:
		level = _shear
		bearing = _shear_bearing
		halfwidth = SHEAR_HALFWIDTH_DEG
	if _bruise.value > level:
		level = _bruise.value
		bearing = _bruise.bearing
		halfwidth = BRUISE_HALFWIDTH_DEG
	_glow_lobes[LOBE_SELF] = _lobe(bearing, halfwidth, level)

	if _taste_c > TASTE_FLOOR:
		var intensity := smoothstep(TASTE_FLOOR, 1.0, _taste_c) * TASTE_PEAK
		var width := lerpf(TASTE_WIDE_DEG, TASTE_TIGHT_DEG, _taste_c)
		_glow_lobes[LOBE_NUTRIENT] = _lobe(
			_taste_bearing_lp + _taste_jitter, width, intensity)
	else:
		_glow_lobes[LOBE_NUTRIENT] = IDLE_LOBE

	if _wake.value > 0.0:
		_press_lobes[0] = _lobe(_wake.bearing, WAKE_HALFWIDTH_DEG, _wake.value)
	else:
		_press_lobes[0] = IDLE_LOBE


## A bearing is body-relative, clockwise from the cell's front. Front is the top
## of the screen, starboard the right; the display itself never rotates.
func _lobe(bearing: float, halfwidth_deg: float, level: float) -> Vector4:
	if level <= 0.0:
		return IDLE_LOBE
	return Vector4(
		sin(bearing), -cos(bearing), cos(deg_to_rad(halfwidth_deg)), level)


func _apply() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("rect_px", _rect)
	_material.set_shader_parameter("inset_px", _inset)
	_material.set_shader_parameter("pulse", _pulse.value)
	_material.set_shader_parameter("glow_lobes", _glow_lobes)
	_material.set_shader_parameter("press_lobes", _press_lobes)
	_material.set_shader_parameter("flash", _flash.value)
	_material.set_shader_parameter("ingest", _ingest.value)
	_material.set_shader_parameter("dread", _dread)
	_material.set_shader_parameter("gain", gain)
