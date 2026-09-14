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
## Phase 4 adds the two deaths. [method collapse] and [method revive] own every
## frame of them, for the same reason: the membrane closing is a uniform write,
## and uniform writes live here. See docs/design/food-and-predators.md §6.
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

## The shader's own defaults, kept here because the death frames fade them to
## black and something has to know what to fade back to.
const BASE_COLOR := Vector3(0.023, 0.055, 0.05)
const DREAD_COLOR := Vector3(0.013, 0.030, 0.043)

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
## Dread costs something, which is what stops it being mood: a hunted cell
## smells at 40% and its bearing jitter doubles. It cannot smell its way out of
## the problem. docs/design/food-and-predators.md §4.2.
const TASTE_DREAD_SUPPRESS := 0.6

const WAKE_CAP := 0.95
const WAKE_HALFWIDTH_DEG := 34.0
const WAKE_ATTACK := 0.07
const WAKE_DECAY := 0.26

const PULSE_ATTACK := 0.09
const PULSE_DECAY := 0.42

const INGEST_ATTACK := 0.12
const INGEST_DECAY := 1.2

## Dread rises over about ten seconds and falls in about four and a half. The
## asymmetry is the whole of §5.4: relief has to arrive fast enough that a
## player can connect it to the turn they just committed to, or escape cannot
## be learnt at all.
const DREAD_RATE := 0.095
const DREAD_FALL_RATE := 0.22
## Arrhythmia is dread's *first* tell, twenty seconds before the drain shows.
## Scaled in from 0.05, not gated at 0.4: a gate makes the rhythm break all at
## once, which reads as a glitch rather than as a body in trouble.
const DREAD_JITTER := 0.40
## Under full dread the beat lands at 0.15 of its strength. Measured, not
## inferred: docs/design/food-and-predators.md §5.2 renders 0.15 as (7,27,27)
## against perception.md's own dread row of (7,26,26).
##
## This is also **the floor**, not just the multiplier. Every stressor in the
## game multiplies into the beat, and the rule is that dread is the dimmest the
## game is ever allowed to be and nothing may compound past it. The clamp is in
## [method beat_strength] and it is the only one; a second constant here could
## drift away from this one and quietly reintroduce the bug.
const DREAD_BEAT_FLOOR := 0.15
## Jitter on a slow beat must not leave the screen empty for eight seconds. The
## ceiling never cuts an authored period -- a dying cell really does beat at
## 7.5s -- it only stops the random half of it running away.
const BEAT_PERIOD_MAX := 6.5

## How much a continuous signal has to move before subscribers are told again.
const POST_EPSILON := 0.02
const POST_ANGLE_EPSILON := 0.05

## An unused lobe: cos(halfwidth) = 2 can never be reached by a dot product.
const IDLE_LOBE := Vector4(0.0, -1.0, 2.0, 0.0)

## Lobe slots. 2 and 3 are headroom for later senses -- see §4.
const LOBE_SELF := 0
const LOBE_NUTRIENT := 1

# --- Death ------------------------------------------------------------------
# docs/design/food-and-predators.md §6. Predation slams the membrane shut;
# starvation lets it sink. Both end at the same black screen, which holds until
# the player asks for another cell.

## Predation: the strike, then the collapse, then black.
const DEATH_STRIKE := 0.15
const DEATH_COLLAPSE := 0.75
const DEATH_BLACK := 0.35
## The specified "measurably nothing" after the screen goes black, before the
## membrane starts asking to be touched.
const DEATH_HOLD := 1.80
const DEATH_RETURN := 0.90
## Where the aperture ends up. Never push_px: pushing the SDF offsets a rounded
## box by a constant, so past corner_px the radius goes negative and the contour
## becomes a hard-cornered rectangle. Raising the inset shrinks half_ext and the
## corner radius with it, so the shape passes stadium -> slit and is never a
## rectangle. §6.2.
const DEATH_INSET := 300.0
const DEATH_FLASH := 0.80

## Starvation: the same aperture, three times slower, with no white in it. It
## has been telegraphed for minutes; it does not get to be loud.
const FAINT_COLLAPSE := 2.60
const FAINT_BLACK := 1.20

## The invitation, and the only answer to "how does a player know a tap is
## wanted on a black screen with no widgets". It is the beat the cell used to
## have, still trying, parting the closed membrane a little each time and
## failing to open it. It never resolves on its own, so a screen that is merely
## waiting never looks like a screen that is still playing.
const INVITE_PERIOD := 2.4
## Seconds to reach full strength. The first breath is already visible; this is
## how long it takes to become insistent.
const INVITE_RISE := 6.0
const INVITE_FLOOR := 0.5
const INVITE_PULSE := 0.62
const INVITE_OPEN_PX := 34.0

# --- Sensitivity ------------------------------------------------------------
## Membrane sensitivity, the escape hatch perception.md §3 reserved and Phase 4
## finally needs: a starving, hunted cell renders at (6,23,23), which on an LCD
## phone in daylight is close to invisible. Exposed on the pause screen, where
## the problem is actually felt and the membrane is still visible behind the
## scrim, so the player sees the effect live as they drag.
## The control exists to *rescue* a dim screen in daylight, so it only goes up.
##
## It used to bottom out at 0.70, and at that setting a starving, hunted cell
## renders (5,19,20) -- within a unit or two of the (5,15,17) frame that the
## beat floor in beat_strength() exists to make unreachable. A slider that can
## undo a guarantee by another route is worse than no slider, and nothing wants
## the game dimmer than its designed values.
const GAIN_MIN := 1.0
const GAIN_MAX := 2.40
const GAIN_DEFAULT := 1.0
const GAIN_STEP := 0.05

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

	## Pinned from outside, for the death frames the bus drives directly rather
	## than through an envelope. Keeps _peak honest so a later fire() behaves.
	func hold(level: float) -> void:
		value = maxf(level, 0.0)
		_peak = value
		_rising = false

	func reset() -> void:
		value = 0.0
		_peak = 0.0
		_rising = false


## Membrane sensitivity. Ships at 1.0; the pause screen moves it.
var gain := GAIN_DEFAULT

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
var _said_dread := 0.0

var _beat_period := 2.4
var _beat_amplitude := 1.0
## Randomised per beat once dread is up; recomputed at every beat.
var _beat_this_period := 2.4
var _beat_phase := 0.72

# Death. While _dying, nothing else in this file writes a uniform: collapse()
# and revive() own every frame of it.
var _dying := false
var _base_hue := BASE_COLOR
var _dread_hue := DREAD_COLOR
## Negative means "use the geometry inset"; the death frames raise it.
var _inset_override := -1.0
## What the cell's last beat is worth. The quiet death is lit by it and nothing
## else, so the aperture closing is visible without a gram of white in it.
var _last_pulse := 0.0


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
##
## The cap lives here rather than in whatever posted it, so there is one place
## it can be wrong. Subscribers are told the capped value, not the request.
func shove(bearing: float, strength: float) -> void:
	var s := minf(maxf(strength, 0.0), WAKE_CAP)
	_wake.fire(s, bearing)
	sensation.emit(&"shove", {"bearing": bearing, "strength": s})


## Contact. A hard flash of the whole contour plus a bruise where it landed.
func hit(bearing: float, strength: float = 1.0) -> void:
	var s := clampf(strength, 0.0, 1.0)
	_flash.fire(FLASH_PEAK * s)
	_bruise.fire(BRUISE_PEAK * s, bearing)
	sensation.emit(&"hit", {"bearing": bearing, "strength": s})


## The water going wrong. Ramps toward [param level] over about ten seconds and
## falls away over about four and a half.
func dread(level: float) -> void:
	var next := clampf(level, 0.0, 1.0)
	_dread_target = next
	# Continuous, posted every frame by the run, so it is gated like taste: an
	# ungated emit here allocates a dictionary sixty times a second to say the
	# same number, for the whole of every run.
	if absf(next - _said_dread) > POST_EPSILON or (next == 0.0) != (_said_dread == 0.0):
		_said_dread = next
		sensation.emit(&"dread", {"strength": next})


## The one licensed flood of the interior.
##
## [param payload] is the Phase 5 seam and nothing else: the gene rolled on the
## meal will arrive here and tint `ingest_color`. Phase 4 always passes {} and
## nothing reads it. Note that a payload is still not a position -- whatever
## lands here has to be something the cell could actually taste.
func ingest(payload: Dictionary = {}) -> void:
	_ingest.fire(1.0)
	sensation.emit(&"ingest", payload)


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
##
## **The one clamp.** Dread drains the beat and starvation drains the beat and
## they multiply; at full both that is 0.35 x 0.1925 = 0.067, which renders as a
## ghost of a contour on black. The rule is that dread is the dimmest the game
## is ever allowed to be and nothing compounds past it, so the floor IS
## [constant DREAD_BEAT_FLOOR] -- not a second number that could drift from it,
## and unbreakable by the third and fourth stressor Phase 5 adds.
func beat_strength() -> float:
	return maxf(_beat_amplitude * lerpf(1.0, DREAD_BEAT_FLOOR, _dread), DREAD_BEAT_FLOOR)


## Fires the beat immediately at [param scale] of its current strength, for the
## probe and for a scene that wants the membrane alive on its first frame.
func pulse_now(scale: float = 1.0) -> void:
	_pulse.fire(beat_strength() * clampf(scale, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Death. docs/design/food-and-predators.md §6, with the owner's change to §9.1:
# the black holds until the player touches the screen.
# ---------------------------------------------------------------------------

## Seconds from the start of a death to the moment the aperture is shut and a
## tap is a sensible thing to want. Whoever owns the run stops accepting input
## before this and starts accepting it after.
static func death_shut_at(loud: bool) -> float:
	return (DEATH_STRIKE + DEATH_COLLAPSE) if loud else FAINT_COLLAPSE


## Every frame of dying, driven by elapsed seconds so the caller owns no state
## but a clock. [param t] keeps counting through the wait, which has no end
## until [method revive] is called.
##
## [param loud] is predation: the strike, the white, 0.75s. False is starvation,
## which has been telegraphed for minutes and does not get to be loud.
func collapse(t: float, loud: bool = true) -> void:
	if not _dying:
		_dying = true
		# One last beat, at exactly the strength this cell had. Not a new
		# constant: beat_strength() is already floored, so the quiet death
		# cannot be invisible however starved and however hunted it was.
		_last_pulse = maxf(_pulse.value, beat_strength())

	var start := DEATH_STRIKE if loud else 0.0
	var span := DEATH_COLLAPSE if loud else FAINT_COLLAPSE
	var black := DEATH_BLACK if loud else FAINT_BLACK
	var shut := start + span
	var dark := shut + black
	var wait := dark + DEATH_HOLD

	# t squared, so it starts as a sag and ends as a slam.
	var u := clampf((t - start) / span, 0.0, 1.0)
	_inset_override = lerpf(_inset, DEATH_INSET, u * u)

	var fade := clampf((t - shut) / maxf(black, 0.001), 0.0, 1.0)
	_base_hue = BASE_COLOR * (1.0 - fade)
	_dread_hue = DREAD_COLOR * (1.0 - fade)

	if loud:
		# Held white, from `flash` and never from a pressure lobe: a pressure
		# lobe adds its own constant offset to the SDF and brings the rectangle
		# straight back. §6.2.
		_flash.hold(DEATH_FLASH * clampf(t / FLASH_ATTACK, 0.0, 1.0) * (1.0 - fade))
		_pulse.hold(0.0)
	else:
		_flash.hold(0.0)
		# The quiet death's whole signature is that the last beat fades out and
		# no beat follows it. You sit waiting, wondering whether it is coming
		# back, and it is not. It outlasts the closing by the width of the fade
		# to black, so the aperture is lit the whole way down.
		_pulse.hold(_last_pulse * pow(1.0 - clampf(t / (span + black), 0.0, 1.0), 0.7))

	# Every glow lobe idled the moment the collapse starts: nothing the cell
	# could smell matters now, and a bruise riding the aperture down reads as a
	# second event.
	if t >= start:
		_idle_lobes()
	_ingest.hold(0.0)
	_wake.hold(0.0)

	if t >= wait:
		_invite(t - wait)

	_apply()


## The dead membrane asking to be touched. Nothing else is on screen, so this is
## the whole of the affordance: the old beat, faint, prising the shut aperture
## open by thirty-odd pixels and losing it again, forever.
func _invite(u: float) -> void:
	var amp := lerpf(INVITE_FLOOR, 1.0, clampf(u / INVITE_RISE, 0.0, 1.0))
	var phase := fmod(u, INVITE_PERIOD) / INVITE_PERIOD
	# A heartbeat, not a sine: fast in, slow out, then a silence long enough
	# that the next one is an event rather than a flicker.
	var shape := 0.0
	if phase < 0.14:
		shape = phase / 0.14
	elif phase < 0.72:
		shape = 1.0 - (phase - 0.14) / 0.58
	shape = clampf(shape, 0.0, 1.0)
	shape = shape * shape * (3.0 - 2.0 * shape)
	_pulse.hold(INVITE_PULSE * amp * shape)
	_inset_override = DEATH_INSET - INVITE_OPEN_PX * amp * shape


## The aperture opening again on a new cell. [param t] is seconds since the tap.
func revive(t: float) -> void:
	_dying = true
	var u := clampf(t / DEATH_RETURN, 0.0, 1.0)
	var open := 1.0 - (1.0 - u) * (1.0 - u)
	_inset_override = lerpf(DEATH_INSET, _inset, open)
	_base_hue = BASE_COLOR * u
	_dread_hue = DREAD_COLOR * u
	_flash.hold(0.0)
	_pulse.hold(0.0)
	_idle_lobes()
	if u >= 1.0:
		_end_collapse()
	_apply()


func _idle_lobes() -> void:
	for i in 4:
		_glow_lobes[i] = IDLE_LOBE
	_press_lobes[0] = IDLE_LOBE
	_press_lobes[1] = IDLE_LOBE


## Back to a membrane with nothing wrong with it. The first beat is fired by
## whoever owns the run, on arrival.
func _end_collapse() -> void:
	_dying = false
	_inset_override = -1.0
	_base_hue = BASE_COLOR
	_dread_hue = DREAD_COLOR
	_dread = 0.0
	_dread_target = 0.0
	_taste_c = 0.0
	_taste_bearing = 0.0
	_taste_bearing_lp = 0.0
	_taste_jitter = 0.0
	_said_taste = -1.0
	_said_shear = 0.0
	_said_dread = 0.0
	_shear = 0.0
	_last_pulse = 0.0
	for env: Env in [_pulse, _thrust, _bruise, _flash, _wake, _ingest]:
		env.reset()
	_idle_lobes()
	_beat_phase = 0.0
	_beat_this_period = _beat_period


# ---------------------------------------------------------------------------
# Envelopes
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Dying is driven entirely by collapse()/revive(), which the run calls every
	# frame. Stepping envelopes underneath them would fight the death frames for
	# the same uniforms.
	if _dying:
		return

	_step_beat(delta)

	_pulse.step(delta)
	_thrust.step(delta)
	_bruise.step(delta)
	_flash.step(delta)
	_wake.step(delta)
	_ingest.step(delta)

	_shear = maxf(_shear - delta * (SHEAR_PEAK / SHEAR_DECAY), 0.0)
	# Asymmetric: ten seconds to arrive, four and a half to let go.
	_dread = move_toward(_dread, _dread_target,
		delta * (DREAD_RATE if _dread_target > _dread else DREAD_FALL_RATE))

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
	# Scaled in, not gated: the rhythm starts coming apart while the drain is
	# still twenty seconds from being visible, and arrhythmia reads at any
	# brightness, on any screen, in daylight.
	var shake := smoothstep(0.05, 0.45, _dread) * DREAD_JITTER
	var jitter := 1.0
	if shake > 0.0:
		jitter = randf_range(1.0 - shake, 1.0 + shake)
	# The ceiling never shortens an authored period -- a dying cell really does
	# beat at 7.5s -- it only stops the random half of it emptying the screen.
	var ceiling := maxf(BEAT_PERIOD_MAX, _beat_period)
	_beat_this_period = clampf(_beat_period * jitter, 0.05, ceiling)


func _step_taste(delta: float) -> void:
	_taste_bearing_lp = lerp_angle(
		_taste_bearing_lp, _taste_bearing, 1.0 - exp(-delta / TASTE_BEARING_TAU))
	_taste_jitter_clock += delta
	var step := 1.0 / TASTE_JITTER_HZ
	if _taste_jitter_clock >= step:
		_taste_jitter_clock = fmod(_taste_jitter_clock, step)
		# Dread doubles the confusion as well as muffling the signal.
		var spread := deg_to_rad(lerpf(
			TASTE_JITTER_WIDE_DEG, TASTE_JITTER_TIGHT_DEG, _taste_c)) * (1.0 + _dread)
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
		# Suppressed, not deleted: a hunted cell can still smell, badly.
		var intensity := smoothstep(TASTE_FLOOR, 1.0, _taste_c) * TASTE_PEAK \
			* (1.0 - TASTE_DREAD_SUPPRESS * _dread)
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
	_material.set_shader_parameter("inset_px",
		_inset_override if _inset_override >= 0.0 else _inset)
	_material.set_shader_parameter("base_color", _base_hue)
	_material.set_shader_parameter("dread_color", _dread_hue)
	_material.set_shader_parameter("pulse", _pulse.value)
	_material.set_shader_parameter("glow_lobes", _glow_lobes)
	_material.set_shader_parameter("press_lobes", _press_lobes)
	_material.set_shader_parameter("flash", _flash.value)
	_material.set_shader_parameter("ingest", _ingest.value)
	_material.set_shader_parameter("dread", _dread)
	_material.set_shader_parameter("gain", gain)
