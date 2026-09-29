extends RefCounted
## **One swell: up, held, and back down, once.** Something happens, the swell
## is armed, and on the next cue it rises over [member rise] seconds, holds for
## [member hold] and falls away over [member fall]. Nothing here knows what
## happened or what swells. The beam's level-up is the first user -- its eyespot
## flares, and the pause target breathes when the beam's fork opens
## (docs/design/beam-levels.md §8.4-§8.5).
##
## **Armed, then cued, because an event is not a moment to show it.** A level
## is earned in the middle of a frame; it is *seen* on the next heartbeat,
## because that is the one rhythm the player is already watching. Whoever owns
## the swell decides what the cue is, and whether one may land now -- a pause
## screen over the body is a cue nobody would see.
##
## Both ends ease: `smoothstep` up and `1 - smoothstep` down, so a swell that
## starts and ends at nothing never jumps.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## Seconds from nothing to the top.
var rise := 0.15
## Seconds at the top.
var hold := 0.0
## Seconds from the top back to nothing.
var fall := 1.05

## Seconds since the swell began, or -1 while none is running.
var _age := -1.0
var _armed := false


func _init(up: float = 0.15, at_top: float = 0.0, down: float = 1.05) -> void:
	rise = maxf(up, 0.0)
	hold = maxf(at_top, 0.0)
	fall = maxf(down, 0.0)


## Something happened: the next [method cue] begins a swell.
func arm() -> void:
	_armed = true


## True while a swell waits for its cue.
func armed() -> bool:
	return _armed


## The moment to show it. Begins a swell if one is armed, and returns whether
## it did.
func cue() -> bool:
	if not _armed:
		return false
	_armed = false
	start()
	return true


## Begins a swell now, armed or not. One already running starts again from
## nothing -- two events in quick succession are one swell, not two stacked.
func start() -> void:
	_age = 0.0


## Moves a running swell on by [param delta] seconds, and ends it at the bottom.
func step(delta: float) -> void:
	if _age < 0.0:
		return
	_age += maxf(delta, 0.0)
	if _age >= rise + hold + fall:
		_age = -1.0


## How far up the swell is, 0 to 1.
func value() -> float:
	if _age < 0.0:
		return 0.0
	if _age < rise:
		return smoothstep(0.0, rise, _age)
	if _age < rise + hold:
		return 1.0
	return 1.0 - smoothstep(rise + hold, rise + hold + fall, _age)


## True from the start of a swell to the end of its fall.
func running() -> bool:
	return _age >= 0.0


## Forgets the swell and anything armed: a death, a birth, a replay that
## jumped.
func clear() -> void:
	_age = -1.0
	_armed = false
