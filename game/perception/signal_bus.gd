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
## `stigma`, the first earned gene: the light-sensitive spot, and the same amber
## the gene wears on the outside (docs/design/genes-and-cilia.md §4.4). Slot 2
## has been reserved since Phase 1 for exactly this.
const LIGHT_COLOR := Vector3(0.98, 0.78, 0.30)
## `ocellus`, the beam. The fourth glow slot, held empty since Phase 1 and spent
## here -- and it is the last one, so no gene after this one gets a colour of
## its own on the membrane. Same indigo-violet the gene wears on the outside.
const BEAM_COLOR := Vector3(0.62, 0.55, 1.00)

## The shader's own defaults, kept here because the death frames fade them to
## black and something has to know what to fade back to.
const BASE_COLOR := Vector3(0.023, 0.055, 0.05)
const DREAD_COLOR := Vector3(0.013, 0.030, 0.043)

# --- Measured values. Every number below is from the signal table in
# --- docs/design/perception.md §3; change them there first.
#
# --- Three of them are indexed by an organ's tier rather than flat, and that is
# --- genes-and-cilia.md §2.1 -- the answer to the tension §2 opens with.
# --- **Point of view cannot see its own cilia**, so a tier change has to be a
# --- change in a sensation the player already knows. The discovery §2.1 rests
# --- on is that the membrane's three self-signals and the cell's three cilia
# --- are the same three organs seen from inside and from outside:
# ---
# ---   cytostome / eat   is the metabolic beat and the flood that follows it
# ---   cirrus    / turn  is the shear on the outside of the turn
# ---   flagellum / swim  is the thrust bloom at bearing 0
# ---
# --- So a flagellum-specialised cell feels its own push harder and more
# --- sharply, and a big mouth savours the meal longer. No new shader term, no
# --- new lobe, no HUD -- and tier 1 reproduces every shipped Phase 1-4 value
# --- exactly, so nothing that has been rendered and judged before moves.
# ---
# --- Index 0 is the cell that has lost the organ entirely, which §9.7 allows by
# --- letting a fourth gene go over any of the three. It is not in the design:
# --- it is extrapolated one step below tier 1 on the ladder's own spacing,
# --- which is what cell.gd's drive tables do and the least invented answer
# --- available.

## The cell's own impulse blooming at its front, by `flagellum` tier. Louder and
## tighter with a better tail: 0.14/60 degrees at tier 1, 0.25/44 at tier 3.
const THRUST_PEAK_BY_TIER: Array[float] = [0.10, 0.14, 0.19, 0.25]
const THRUST_HALFWIDTH_BY_TIER: Array[float] = [68.0, 60.0, 52.0, 44.0]
const THRUST_ATTACK := 0.06
const THRUST_DECAY := 0.5

## Water shearing past the membrane on the outside of a turn, by `cirrus` tier.
##
## The tier lands here and **only** here: cell.gd's [method CellBody.shear_rate]
## returns demand-or-rotation normalised to -1..1 on purpose, so it is the same
## number at every tier and this table is the whole of the difference. That is
## the right way round -- de-normalising the rate as well would count the tier
## twice, and a tier-3 cirrus would shear at 0.31 against a designed 0.19.
const SHEAR_PEAK_BY_TIER: Array[float] = [0.07, 0.10, 0.14, 0.19]
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
## How long the flood takes to drain, by `cytostome` tier: a bigger mouth
## savours the meal longer. Attack is deliberately flat -- what a wider mouth
## buys is the lingering, not a faster swallow.
const INGEST_DECAY_BY_TIER: Array[float] = [1.0, 1.2, 1.5, 1.9]

# --- The stigma (§6) --------------------------------------------------------
## What the light-sensitive spot is worth on the contour. Deliberately modest:
## it is the *sharpest* thing on the membrane, not the loudest, and sharpness is
## what it was bought for.
const LIGHT_PEAK := 0.28
## By tier. Taste is 78 degrees wide at range and only 26 on top of the food;
## the stigma is its tier's width at **every** range. It does not jitter and it
## does not lag, and those two properties are most of what a slot is paying for.
const LIGHT_HALFWIDTH_DEG: Array[float] = [0.0, 26.0, 19.0, 13.0]
## Below this the lobe is idled rather than drawn at nothing.
const LIGHT_FLOOR := 0.02

# --- The genes that reach the membrane --------------------------------------
# Four of the new organs are senses, so four of them land here. Nothing below
# adds a uniform: the beam takes the last free glow lobe, `level` takes the last
# free *pressure* lobe, `touch` fires the bruise envelope the membrane has had
# since Phase 1, and `focus` narrows a lobe that already exists.

## `ocellus` / beam. **The only thing you can see**: the point where the beam
## hits something, at that bearing and nothing else. Louder than the stigma's
## lobe because it is a fact rather than a hint, and tighter with tier -- a
## better eye resolves the hit more precisely, it does not shout about it.
const BEAM_PEAK := 0.46
const BEAM_HALFWIDTH_DEG: Array[float] = [0.0, 14.0, 11.0, 8.0]
const BEAM_FLOOR := 0.02

## `statocyst` / level. Absolute up, as a steady dent that does **not** turn
## with the body -- turn the cell and it walks round the contour, which is the
## whole readout. A pressure lobe rather than a glow one on purpose: it is not a
## thing out there, it is which way is up, and the game already has one channel
## that means "something is pressing on you from over there".
const LEVEL_PUSH_BY_TIER: Array[float] = [0.0, 0.13, 0.17, 0.23]
const LEVEL_HALFWIDTH_DEG: Array[float] = [0.0, 30.0, 22.0, 15.0]

## `palp` / touch. Feeling a body at close range with no light at all: the
## bruise envelope, held at a level rather than struck, so it reads as pressure
## against the skin rather than as a collision. Capped below BRUISE_PEAK so a
## real contact always buries it.
const TOUCH_PEAK := 0.26

## `rhabdom` / focus. A multiplier on the taste lobe's width and on its bearing
## jitter, which are the two things that make the scent direction vague. It buys
## sharpness in the channel the player has used since the first minute.
const FOCUS_BY_TIER: Array[float] = [1.0, 0.74, 0.56, 0.40]

## `ampulla` / ping. One electroreceptive pulse, and a mark on the contour for
## every body it comes back off. **It shares [constant LOBE_BEAM] with the
## ocellus** -- there are four glow lobes in the shader and a fifth is a new
## uniform and a new binary -- and that sharing is honest rather than a
## compromise: both mean *a hard surface, that way, that far*, and the loudest
## one wins exactly as the three self-signals do in lobe 0.
##
## What keeps them apart on screen is time, not colour. The beam is a steady
## mark that sits where the ray is pointed for as long as it is pointed there; a
## ping is a run of short marks walking outward, one per body, spaced by their
## own flight time. Louder than the beam, because a return is a whole body
## answering rather than a ray clipping one, and shorter-lived than anything
## else on the contour.
const PING_PEAK := 0.55
const PING_HALFWIDTH_DEG: Array[float] = [0.0, 17.0, 13.0, 10.0]
const PING_ATTACK := 0.035
## Shorter than food.gd's PING_MIN_GAP, so a sweep reads as separate marks
## rather than as one smear that wanders across the contour. The two constants
## are a pair: raise this above that one and the series becomes a chord again.
const PING_DECAY := 0.15

## The earned senses, in genome order: `ocellus`, `statocyst`, `rhabdom`, then
## the two this phase adds. Written once a frame by [method sense_organs],
## exactly like [method organs].
const SENSE_OCELLUS := 0
const SENSE_STATOCYST := 1
const SENSE_RHABDOM := 2
const SENSE_CHEMOCYTE := 3
const SENSE_AMPULLA := 4

# --- A held sample is a second heartbeat (§3.3) -----------------------------
# The one new point-of-view signal Phase 5 adds, and the answer to "how does a
# player with no HUD know a decision is waiting". It is rhythm, which
# food-and-predators.md §5.1 established as the channel that survives
# everything: it outlives dread and it outlives starvation.
#
# It is **teal, not the gene's colour** -- perception.md's rule stands, the
# contour carries bearing and intensity and never identity. The echo says
# *there is something in you that is not resolved*, and nothing else. It costs
# no interior and no new uniform: it is pulse_now() on a delay.

## How loud the echo is, as a fraction of the beat it follows.
const HELD_ECHO := 0.44
## Seconds after the beat. 0.58 clears PULSE_ATTACK + PULSE_DECAY = 0.51, so the
## two pulses are separate. Below a 1.7s beat period the delay compresses and at
## rich-food periods the two merge into a flutter -- which is acceptable,
## because it is still not the normal rhythm. Do not add a uniform to fix it.
const HELD_ECHO_DELAY := 0.58
## The echo weakens over the last seconds of the sample, so a lapse is felt
## coming rather than noticed afterwards.
const HELD_FADE := 15.0

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

## Lobe slots. 3 is headroom for a later sense -- see perception.md §4.
const LOBE_SELF := 0
const LOBE_NUTRIENT := 1
## Reserved since Phase 1 and spent by Phase 5 on the `stigma`.
const LOBE_LIGHT := 2
## The last free glow slot, spent on the `ocellus` beam. There are four and the
## shader has four; a fifth would be a new uniform and a new binary.
const LOBE_BEAM := 3

## Organ slots in [method organs], in genes-and-cilia.md §4.1's arc order --
## which is the order the body is drawn in, the order ties break in, and now the
## order the membrane is told in. One ordering, everywhere.
const ORGAN_CYTOSTOME := 0
const ORGAN_CIRRUS := 1
const ORGAN_FLAGELLUM := 2
const ORGAN_STIGMA := 3
const ORGAN_TIER_MAX := 3

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

	## How long this envelope takes to drain, when that is a property of the
	## body rather than a constant. §2.1 gives a bigger `cytostome` a longer
	## flood, and the body it belongs to can change mid-decay -- a meal that
	## raises the tier arrives during the flood it caused -- so this is written
	## every frame rather than at construction. Changing it mid-decay just bends
	## the remaining fall, because [method step] divides by it afresh.
	func retune_decay(decay: float) -> void:
		_decay = maxf(decay, 0.001)

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
var _ingest := Env.new(INGEST_ATTACK, INGEST_DECAY_BY_TIER[1])
var _ping := Env.new(PING_ATTACK, PING_DECAY)

## **What body this membrane is attached to** (§2.1), in `genes-and-cilia.md`'s
## arc order: `cytostome`, `cirrus`, `flagellum`, `stigma`. Written once a frame
## by [method organs], exactly the way metabolism's state arrives through
## [method set_beat] -- a continuous property of the organism that shapes the
## discrete events, rather than an argument riding on each one. That keeps every
## sensation entry point about the sensation, which is what the audio and
## haptics subscribers downstream of [signal sensation] will be reading.
##
## Defaults are the born cell: mediocre at three things and blind. Nothing here
## may become a way to describe what is *outside* the cell.
var _organs := PackedInt32Array([1, 1, 1, 0])
## `ocellus`, `statocyst`, `rhabdom`, `chemocyte`, `ampulla`. A born cell has
## none of them -- **including the nose**, which is the change this phase makes
## to what "born" means. Taste was innate from Phase 1 to Phase 5.
var _senses := PackedInt32Array([0, 0, 0, 0, 0])

## Shear has no attack at all -- it is the proof that the player is connected to
## something, so it must answer the same frame the turn starts.
var _shear := 0.0
var _shear_bearing := 0.0

var _taste_c := 0.0
var _taste_bearing := 0.0
var _taste_bearing_lp := 0.0
var _taste_jitter := 0.0
var _taste_jitter_clock := 0.0

## **This node's own generator, and it must stay its own.** Every other random
## draw in the project comes off the global stream, which is what makes a run
## reproducible from a seed at a fixed timestep -- measured byte-identical over
## 200 seconds of real foraging. The bus is a VIEW, and a view drawing from that
## stream puts the perception layer inside the simulation.
##
## It was, and the symptom was worse than it sounds. `Membrane` is
## `process_mode = 3`, so this node keeps stepping while the tree is paused
## while every simulation node stops. Five seconds on the pause screen pulled
## about seven draws out of the shared stream, and at equal SIMULATION time
## afterwards all 34 bodies were somewhere else -- one cell at 800.7 units
## against 912.4. How long you left the pause screen open changed the world.
##
## That contradicted this file's own neighbours: normal_mode.gd's header, and
## perception.md §4's "if a view ever changes how the cell behaves, full vision
## stops being evidence". vision.gd was measured innocent; this file was not.
##
## So: every draw in this file goes through `_rng`, and no draw in this file
## ever calls the global `randf`/`randi` again. That is a structural guarantee
## rather than a discipline -- a future sensation cannot reintroduce the bug by
## forgetting a gate.
var _rng := RandomNumberGenerator.new()

var _dread := 0.0
var _dread_target := 0.0

## The shadow of something big, at its true bearing. No envelope: it is a
## continuous state like taste, posted every frame by whoever owns the run.
var _light := 0.0
var _light_bearing := 0.0

## Where the beam is hitting something and how near, and which way is up. Both
## continuous, both posted every frame, neither with an envelope.
var _beam := 0.0
var _beam_bearing := 0.0
var _level := 0.0
var _level_bearing := 0.0

## Seconds left on the held sample, 0 for none, and the echo it schedules.
var _held := 0.0
var _echo_at := 0.0
## Negative means nothing is waiting.
var _echo_in := -1.0

## What the next flood floods with. The gene's hue while a gene arrived with the
## meal, nutrient green otherwise -- which is every meal Phase 4 ever served.
var _ingest_hue := NUTRIENT_COLOR

# Last values announced on [signal sensation], for the gate above.
var _said_taste := -1.0
var _said_taste_bearing := 0.0
var _said_shear := 0.0
var _said_dread := 0.0
var _said_light := -1.0
var _said_light_bearing := 0.0
var _said_beam := -1.0
var _said_beam_bearing := 0.0

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
		SELF_COLOR, NUTRIENT_COLOR, LIGHT_COLOR, BEAM_COLOR])
	_material.set_shader_parameter("glow_colors", colors)
	_apply()


## Viewport size and contour inset, both in canvas pixels.
func set_geometry(rect: Vector2, inset: float) -> void:
	_rect = Vector2(maxf(rect.x, 1.0), maxf(rect.y, 1.0))
	_inset = maxf(inset, 0.0)


## **The light setting, on the material now rather than on the next frame.**
##
## A run sets [member gain] as a plain property and gets away with it, because
## it is stepping envelopes sixty times a second and every one of those frames
## ends in the same `_apply()` that writes this uniform. A screen that is not
## stepping has no next frame to rely on -- the replay's panes write a recorded
## block instead -- so it says it here and it lands at once.
##
## Clamped rather than trusted: this is reached from a stored file.
func apply_gain(value: float) -> void:
	gain = clampf(value, GAIN_MIN, GAIN_MAX)
	_apply()


# ---------------------------------------------------------------------------
# The membrane as a block of numbers. docs/design/replay.md §4.1.
#
# **The replay records the membrane as uniforms, not as the sensations that
# produced them.** Re-running the sensations at playback would re-roll the taste
# jitter and the beat jitter off this node's own generator, and a replay that
# shows a *different* jitter from the one the player actually steered on is a
# replay that lies about the one thing the screen exists to check.
#
# So these two functions, and this file stays the only one that knows a uniform
# name. Three uniforms are deliberately NOT in the block: `rect_px` and
# `inset_px` are the geometry of whatever rect is being drawn into -- a pane is
# half a screen wide and has its own -- and `gain` is a setting the player owns
# now, not a fact about the run that ended.
# ---------------------------------------------------------------------------

## Floats one captured membrane takes. Thirty-seven, and the count is checked
## against the block layout below rather than trusted.
const BLOCK_FLOATS := 37


## Writes this membrane's state into [param out] at [param at]. No allocation:
## it is called once a frame from the recorder's hot loop.
func capture_block(out: PackedFloat32Array, at: int) -> void:
	out[at] = _base_hue.x
	out[at + 1] = _base_hue.y
	out[at + 2] = _base_hue.z
	out[at + 3] = _dread_hue.x
	out[at + 4] = _dread_hue.y
	out[at + 5] = _dread_hue.z
	out[at + 6] = _pulse.value
	var i := at + 7
	for lobe: Vector4 in _glow_lobes:
		out[i] = lobe.x
		out[i + 1] = lobe.y
		out[i + 2] = lobe.z
		out[i + 3] = lobe.w
		i += 4
	for lobe: Vector4 in _press_lobes:
		out[i] = lobe.x
		out[i + 1] = lobe.y
		out[i + 2] = lobe.z
		out[i + 3] = lobe.w
		i += 4
	out[at + 31] = _flash.value
	out[at + 32] = _ingest.value
	out[at + 33] = _ingest_hue.x
	out[at + 34] = _ingest_hue.y
	out[at + 35] = _ingest_hue.z
	out[at + 36] = _dread


## Puts a captured membrane back on the shader, through this node's own state so
## that it stays the only writer of a uniform. The caller stops this node
## processing first -- an envelope stepping underneath a written block would
## fight it for the same uniforms, exactly as the death frames would.
func write_block(block: PackedFloat32Array, at: int) -> void:
	_base_hue = Vector3(block[at], block[at + 1], block[at + 2])
	_dread_hue = Vector3(block[at + 3], block[at + 4], block[at + 5])
	_pulse.hold(block[at + 6])
	var i := at + 7
	for slot in _glow_lobes.size():
		_glow_lobes[slot] = Vector4(block[i], block[i + 1], block[i + 2],
			block[i + 3])
		i += 4
	for slot in _press_lobes.size():
		_press_lobes[slot] = Vector4(block[i], block[i + 1], block[i + 2],
			block[i + 3])
		i += 4
	_flash.hold(block[at + 31])
	_ingest.hold(block[at + 32])
	_ingest_hue = Vector3(block[at + 33], block[at + 34], block[at + 35])
	_dread = block[at + 36]
	_apply()


## **What organs this cell has, and how good they are** -- genes-and-cilia.md
## §2.1. Posted every frame by whoever owns the run, like [method set_beat],
## and the only thing in this file that is about the body rather than about
## what is happening to it.
##
## Nothing new appears on the membrane because of this. Three signals the player
## has known since Phase 1 change magnitude and shape: the thrust bloom gets
## louder and tighter with a better tail, the turn shear gets stronger with a
## better cirrus, and the ingest flood lingers with a wider mouth. That is the
## whole of §2's answer to *"point of view cannot see its own cilia"* -- you do
## not look at what you can do, you feel it, and you always have.
##
## It carries **no identity and no position**. Four small integers about this
## cell's own anatomy are not a fact about anything else in the water, which is
## the line perception.md draws and this does not cross.
func organs(cytostome: int, cirrus: int, flagellum: int, stigma: int) -> void:
	_organs[ORGAN_CYTOSTOME] = clampi(cytostome, 0, ORGAN_TIER_MAX)
	_organs[ORGAN_CIRRUS] = clampi(cirrus, 0, ORGAN_TIER_MAX)
	_organs[ORGAN_FLAGELLUM] = clampi(flagellum, 0, ORGAN_TIER_MAX)
	_organs[ORGAN_STIGMA] = clampi(stigma, 0, ORGAN_TIER_MAX)
	# The flood's decay is the only one of the three that lives inside an
	# envelope rather than being read at the moment it is used, so it is pushed
	# rather than pulled.
	_ingest.retune_decay(INGEST_DECAY_BY_TIER[_organs[ORGAN_CYTOSTOME]])


## **What earned senses this cell has**, beside [method organs] and for exactly
## the same reason: a tier is a property of the organ, not of the thing it
## senses, so it arrives once a frame rather than riding on every event.
##
## Same rule as [method organs] and it is not a loophole: three small integers
## about this cell's own anatomy are not a fact about anything in the water.
func sense_organs(ocellus: int, statocyst: int, rhabdom: int,
		chemocyte: int = 0, ampulla: int = 0) -> void:
	_senses[SENSE_OCELLUS] = clampi(ocellus, 0, ORGAN_TIER_MAX)
	_senses[SENSE_STATOCYST] = clampi(statocyst, 0, ORGAN_TIER_MAX)
	_senses[SENSE_RHABDOM] = clampi(rhabdom, 0, ORGAN_TIER_MAX)
	_senses[SENSE_CHEMOCYTE] = clampi(chemocyte, 0, ORGAN_TIER_MAX)
	_senses[SENSE_AMPULLA] = clampi(ampulla, 0, ORGAN_TIER_MAX)


# ---------------------------------------------------------------------------
# Sensations. Everything gameplay is allowed to say to the membrane.
# ---------------------------------------------------------------------------

## Chemistry soaking through the band. Continuous: post it every frame with the
## current concentration, 0 for "nothing out there".
##
## **A cell with no `chemocyte` smells nothing**, enforced here as well as at
## the call site, exactly the way [method light] is gated on the `stigma`. This
## was innate for five phases and is not any more: the green band is the one
## signal that says *food, that way*, and a sense that is handed out for free is
## a sense that can never be a decision.
##
## It is still the only sense that lies -- the low-pass, the jitter and dread's
## suppression all stay where they were. What the tier buys is reach, and reach
## is applied before this: food.gd sums only what is inside the nose.
func taste(bearing: float, concentration: float) -> void:
	var smelt := _senses[SENSE_CHEMOCYTE] > 0
	_taste_bearing = bearing if smelt else 0.0
	_taste_c = clampf(concentration, 0.0, 1.0) if smelt else 0.0
	# Continuous signals are posted every frame; only tell subscribers when
	# something actually moved, or this allocates sixty dictionaries a second.
	if absf(_taste_c - _said_taste) > POST_EPSILON \
			or absf(angle_difference(_taste_bearing, _said_taste_bearing)) > POST_ANGLE_EPSILON:
		_said_taste = _taste_c
		_said_taste_bearing = _taste_bearing
		sensation.emit(&"taste", {"bearing": _taste_bearing, "strength": _taste_c})


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


## The shadow of something bigger than you, passing between the cell and the
## light above. The `stigma`, §6.
##
## [param bearing] is body-relative like every other bearing here. How sharp the
## lobe is comes from the `stigma` tier in [method organs], not from an argument
## here -- the tier is a property of the organ, not of the shadow.
##
## **A cell with no stigma reports nothing at all**, which is enforced here as
## well as at the call site. The caller already declines to hand over a bearing
## it has no organ to have sensed; this is the backstop that makes "an organ you
## have not grown is silent" a property of the bus rather than a discipline four
## call sites have to remember.
##
## **Dread does not muffle it, and that is the purchase.** Dread is a blocked
## chemoreceptor; light is a different organ, so TASTE_DREAD_SUPPRESS has no
## business here. At the moment the player can see least, the thing they bought
## still works.
##
## It says *mass*, never danger: a shadow's size is a fact about a body, so the
## small cell with the huge mouth casts none and the mouthless giant casts a
## large one. That is honest optics and it keeps "never an identity".
func light(bearing: float, strength: float) -> void:
	var seen := _organs[ORGAN_STIGMA] > 0
	_light = clampf(strength, 0.0, 1.0) if seen else 0.0
	_light_bearing = bearing if seen else 0.0
	if absf(_light - _said_light) > POST_EPSILON \
			or absf(angle_difference(_light_bearing, _said_light_bearing)) > POST_ANGLE_EPSILON:
		_said_light = _light
		_said_light_bearing = _light_bearing
		sensation.emit(&"light", {"bearing": _light_bearing, "strength": _light})


## **The beam found something.** [param bearing] is where along the beam, which
## is the beam's own bearing, and [param strength] is how near the hit is -- 1
## at the cell's nose, 0 at the end of its reach.
##
## This is the whole of what an `ocellus` gives point of view: *there is a
## surface, that way, that far*. It says nothing about what the surface is, so
## it stays inside perception.md's "never an identity" the way every other lobe
## does. A cell with no ocellus reports nothing, enforced here as well as at the
## call site, exactly as [method light] is.
func beam(bearing: float, strength: float) -> void:
	var seen := _senses[SENSE_OCELLUS] > 0
	_beam = clampf(strength, 0.0, 1.0) if seen else 0.0
	_beam_bearing = bearing if seen else 0.0
	if absf(_beam - _said_beam) > POST_EPSILON \
			or absf(angle_difference(_beam_bearing, _said_beam_bearing)) > POST_ANGLE_EPSILON:
		_said_beam = _beam
		_said_beam_bearing = _beam_bearing
		sensation.emit(&"beam", {"bearing": _beam_bearing, "strength": _beam})


## **A return came back.** `ampulla`: one mark on the contour for one body the
## pulse found, at its bearing, [param strength] 1 against the skin and 0 at the
## edge of reach. Fired once per return, several times per pulse, spaced by the
## returns' own flight times -- so a pulse arrives as a sweep and not as a
## chord. See [constant PING_PEAK] for why it shares the beam's lobe.
##
## It says *a body*, not *a meal* and not *a threat*: that is the whole purchase
## over the scent field, and it keeps perception.md's "never an identity"
## because a body is the least a return can possibly mean. A cell with no
## ampulla reports nothing, enforced here as well as at the call site.
func ping(bearing: float, strength: float) -> void:
	if _senses[SENSE_AMPULLA] <= 0:
		return
	var s := clampf(strength, 0.0, 1.0)
	if s <= 0.0:
		return
	_ping.fire(PING_PEAK * s, bearing)
	sensation.emit(&"ping", {"bearing": bearing, "strength": s})


## **Which way is up**, in a game where the body is the only frame of reference
## there has ever been. [param bearing] is body-relative like everything else --
## that is the point: it is the one bearing that moves when you turn and stays
## still when you do not.
##
## Not gated for subscribers: it changes every frame a turning cell exists, and
## a gate that fires every frame is a gate that costs more than it saves.
func level(bearing: float, strength: float) -> void:
	var seen := _senses[SENSE_STATOCYST] > 0
	_level = clampf(strength, 0.0, 1.0) if seen else 0.0
	_level_bearing = bearing if seen else 0.0


## **Something solid is right there**, felt and not seen. `palp`: the bruise
## envelope held at a level instead of struck, so it is pressure rather than
## collision, and no flash -- there is nothing sudden about touching something
## you were already up against.
func touch(bearing: float, strength: float) -> void:
	var s := clampf(strength, 0.0, 1.0)
	if s <= 0.0:
		return
	_bruise.fire(TOUCH_PEAK * s, bearing)


## A gene swallowed with nowhere to put it. [param remaining] is seconds left on
## the sample and 0 is "nothing held"; posted every frame, like taste and dread.
##
## Nothing is drawn for this and nothing new is written: it schedules a second,
## smaller pulse behind each beat (§3.3). The player is told a decision is
## waiting by the rhythm of their own body, which is the only channel that
## survives dread and starvation both.
func hold(remaining: float) -> void:
	var next := maxf(remaining, 0.0)
	var was := _held > 0.0
	_held = next
	if next <= 0.0:
		_echo_in = -1.0
	if (next > 0.0) != was:
		sensation.emit(&"hold", {"strength": 1.0 if next > 0.0 else 0.0})


## The one licensed flood of the interior.
##
## [param payload] carries `gene` and `color`: §2.2 spends the seam Phase 4
## reserved and makes the flood the gene's own hue, which is the only place a
## gene is ever identified on the sensory screen. It is a contact event --
## chemistry already inside you -- and it is bounded to this one signal and this
## one frame. **Do not let it spread to the band.**
##
## A payload is still not a position: whatever lands here has to be something
## the cell could actually taste. A meal with no gene floods nutrient green,
## exactly as every Phase 4 meal did.
func ingest(payload: Dictionary = {}) -> void:
	# Read defensively rather than with a typed get(): this payload crosses a
	# public seam that later phases and an audio layer will both write to, and a
	# wrong type here would be a crash on the most common action in the game.
	_ingest_hue = NUTRIENT_COLOR
	if payload.get("color") is Color:
		var tone: Color = payload["color"]
		if tone.a > 0.0:
			_ingest_hue = Vector3(tone.r, tone.g, tone.b)
	_ingest.fire(1.0)
	sensation.emit(&"ingest", payload)


## Self-signal: the cell's own impulse blooming at its front. How hard and how
## tightly it blooms is the `flagellum` tier, out of [method organs] (§2.1).
func thrust(strength: float = 1.0) -> void:
	_thrust.fire(THRUST_PEAK_BY_TIER[_organs[ORGAN_FLAGELLUM]]
		* clampf(strength, 0.0, 1.0))
	sensation.emit(&"thrust", {"bearing": 0.0, "strength": strength})


## Self-signal: water shearing past the membrane on the outside of a turn.
## [param rate] is signed and normalised, -1 hard to port, +1 hard to starboard
## **at every tier** -- how hard that normalised push actually shears is the
## `cirrus` tier, out of [method organs] (§2.1), and nowhere else.
func shear(rate: float) -> void:
	var r := clampf(rate, -1.0, 1.0)
	var level := SHEAR_PEAK_BY_TIER[_organs[ORGAN_CIRRUS]] * absf(r)
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


## **What the beat is doing right now**, 0..1. A read, not a write, and the only
## one in this file: the proprioceptive figure at the centre of the point-of-view
## screen brightens its nucleus on the same heartbeat the contour does, and two
## clocks for one heart would drift apart on screen where it would be seen.
## Whoever owns the run reads this and hands it on; nothing else may.
func pulse() -> float:
	return _pulse.value


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
	_ping.hold(0.0)

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
	_light = 0.0
	_light_bearing = 0.0
	_beam = 0.0
	_beam_bearing = 0.0
	_said_beam = -1.0
	_level = 0.0
	_level_bearing = 0.0
	_held = 0.0
	_echo_in = -1.0
	_echo_at = 0.0
	_ingest_hue = NUTRIENT_COLOR
	_said_taste = -1.0
	_said_shear = 0.0
	_said_dread = 0.0
	_said_light = -1.0
	_shear = 0.0
	_last_pulse = 0.0
	for env: Env in [_pulse, _thrust, _bruise, _flash, _wake, _ingest, _ping]:
		env.reset()
	# A new cell is the born cell: mediocre at three things and blind. The run
	# posts the real answer on its first frame, but the first frame of a new
	# life is the one beat the player is watching for, and it must not land at
	# the dead cell's tiers. After the envelope resets, because this retunes one
	# of them.
	organs(1, 1, 1, 0)
	sense_organs(0, 0, 0, 0, 0)
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
	_ping.step(delta)

	# Decays at its own peak over its own time, so a tier-3 cirrus does not
	# also hold the shear on for longer than a tier-1 one: what the tier buys
	# is how hard the water pushes back, not how long it takes to let go.
	_shear = maxf(_shear - delta
		* (SHEAR_PEAK_BY_TIER[_organs[ORGAN_CIRRUS]] / SHEAR_DECAY), 0.0)
	# Asymmetric: ten seconds to arrive, four and a half to let go.
	_dread = move_toward(_dread, _dread_target,
		delta * (DREAD_RATE if _dread_target > _dread else DREAD_FALL_RATE))

	_step_taste(delta)
	_compose_lobes()
	_apply()


func _step_beat(delta: float) -> void:
	# The echo first, so a beat landing this frame schedules the *next* echo
	# rather than cancelling the one it is still waiting on.
	if _echo_in >= 0.0:
		_echo_in -= delta
		if _echo_in <= 0.0:
			_echo_in = -1.0
			pulse_now(_echo_at)
			sensation.emit(&"echo", {"strength": _echo_at})

	_beat_phase += delta / _beat_this_period
	if _beat_phase < 1.0:
		return
	_beat_phase -= floorf(_beat_phase)
	pulse_now()
	if _held > 0.0:
		# Weaker as the sample runs out, so the lapse is felt coming. The delay
		# is capped at a third of the period as well as at HELD_ECHO_DELAY, so
		# on a fast beat the echo stays inside its own beat instead of landing
		# on top of the next one.
		_echo_at = HELD_ECHO * minf(_held / HELD_FADE, 1.0)
		_echo_in = minf(HELD_ECHO_DELAY, 0.34 * _beat_this_period)
	# The beat is the game's one permanent signal and the hunger readout, so it
	# is the first thing an audio layer will want to hear about.
	sensation.emit(&"beat", {"strength": beat_strength(), "period": _beat_period})
	# Scaled in, not gated: the rhythm starts coming apart while the drain is
	# still twenty seconds from being visible, and arrhythmia reads at any
	# brightness, on any screen, in daylight.
	var shake := smoothstep(0.05, 0.45, _dread) * DREAD_JITTER
	var jitter := 1.0
	if shake > 0.0:
		jitter = _rng.randf_range(1.0 - shake, 1.0 + shake)
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
			TASTE_JITTER_WIDE_DEG, TASTE_JITTER_TIGHT_DEG, _taste_c)) \
			* (1.0 + _dread) * FOCUS_BY_TIER[_senses[SENSE_RHABDOM]]
		_taste_jitter = _rng.randf_range(-spread, spread)


## Lobe 0 carries every self-sensation, so the three compete instead of summing:
## the loudest thing happening to your own skin is the thing you feel. A bruise
## (0.35) buries a thrust bloom (0.14), which is the right way round.
func _compose_lobes() -> void:
	var level := _thrust.value
	var bearing := 0.0
	var halfwidth := THRUST_HALFWIDTH_BY_TIER[_organs[ORGAN_FLAGELLUM]]
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
		var width := lerpf(TASTE_WIDE_DEG, TASTE_TIGHT_DEG, _taste_c) \
			* FOCUS_BY_TIER[_senses[SENSE_RHABDOM]]
		_glow_lobes[LOBE_NUTRIENT] = _lobe(
			_taste_bearing_lp + _taste_jitter, width, intensity)
	else:
		_glow_lobes[LOBE_NUTRIENT] = IDLE_LOBE

	# The stigma. No low-pass on the bearing and no jitter added to it: the
	# whole of what this gene sells is that direction can be certain. And no
	# dread term -- see light().
	if _light > LIGHT_FLOOR:
		_glow_lobes[LOBE_LIGHT] = _lobe(
			_light_bearing,
			LIGHT_HALFWIDTH_DEG[_organs[ORGAN_STIGMA]], LIGHT_PEAK * _light)
	else:
		_glow_lobes[LOBE_LIGHT] = IDLE_LOBE

	# The last glow slot, shared by the beam and the ping. They compete rather
	# than sum, exactly as the three self-signals do in lobe 0: the loudest
	# thing out there is the thing worth telling a blind cell about. A ping
	# return punches through a steady beam for a quarter of a second and then
	# gives it back, which is the right way round -- a body answering is a newer
	# fact than a ray that has been resting on something for seconds.
	var hard := BEAM_PEAK * _beam if _beam > BEAM_FLOOR else 0.0
	var hard_bearing := _beam_bearing
	var hard_width := BEAM_HALFWIDTH_DEG[_senses[SENSE_OCELLUS]]
	if _ping.value > hard:
		hard = _ping.value
		hard_bearing = _ping.bearing
		hard_width = PING_HALFWIDTH_DEG[_senses[SENSE_AMPULLA]]
	_glow_lobes[LOBE_BEAM] = _lobe(hard_bearing, hard_width, hard)

	if _wake.value > 0.0:
		_press_lobes[0] = _lobe(_wake.bearing, WAKE_HALFWIDTH_DEG, _wake.value)
	else:
		_press_lobes[0] = IDLE_LOBE

	# Absolute up, in the last pressure slot. Steady, so it is the only mark on
	# the membrane that is not an event -- and it walks round the contour as the
	# cell turns, which is the whole of what a statocyst knows.
	var level_tier := _senses[SENSE_STATOCYST]
	if _level > 0.0 and level_tier > 0:
		_press_lobes[1] = _lobe(_level_bearing,
			LEVEL_HALFWIDTH_DEG[level_tier], LEVEL_PUSH_BY_TIER[level_tier] * _level)
	else:
		_press_lobes[1] = IDLE_LOBE


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
	_material.set_shader_parameter("ingest_color", _ingest_hue)
	_material.set_shader_parameter("dread", _dread)
	_material.set_shader_parameter("gain", gain)
