extends RefCounted
## **The heartbeat, heard and felt** (docs/design/sound-and-touch.md §3): the
## game's first sound and its first touch, on the bus's `beat`. The edge that
## names a heart: game/feel/feel.gd plays a cue and game/feel/tone.gd makes a
## sound, and neither knows this is one.
##
## The owner, 2026-10-16: *"Time to make sound and vibrations. First, the
## heartbeat. Very Light vibration and sound so it doesn't drive players crazy and
## mask other sounds"*. So, a lub-dub:
##
## - **Low, and nothing else.** A soft thump at 50 to 100 Hz, its overtones gone by
##   about 400 Hz: the band no other sound will want, so it masks none of them.
##   A little knock at three and a half times its pitch is what a phone's own
##   speaker, which plays nothing much under 300 Hz, can carry of it.
## - **Quiet.** The lub peaks at [constant LUB_DB], the dub four decibels under it,
##   both at a beat of full strength. Low sound is heard as much quieter than its
##   level says, so this is the quietest thing the game will play.
## - **Brief.** The two last half a second of a beat that comes every 2.4 seconds
##   at rest: the rest of the beat is silence for whatever else is playing.
## - **A tick in the hand, not a buzz.** Android plays an amplitude where the phone
##   can, and full strength where it cannot (GodotNativeBridge's `vibrate`, Godot
##   4.7.2), so the buzzes are kept short enough to be a tick on either: 20 ms at a
##   fifth of full, then 14 ms at an eighth.
##
## Every number here is a starting value (sound-and-touch.md §6 says what to watch).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Tone := preload("res://game/feel/tone.gd")

## **The lub**: the first and stronger sound, on the beat itself.
const LUB := {
	"from_hz": 80.0, "to_hz": 52.0, "glide": 0.035, "attack": 0.006, "decay": 0.05,
	"length": 0.3, "drive": 2.4, "knock": 0.25, "knock_ratio": 3.5,
	"knock_decay": 0.012, "cut_hz": 420.0,
}
## **The dub**: a little higher and shorter, a moment later.
const DUB := {
	"from_hz": 96.0, "to_hz": 62.0, "glide": 0.03, "attack": 0.005, "decay": 0.038,
	"length": 0.24, "drive": 2.2, "knock": 0.25, "knock_ratio": 3.5,
	"knock_decay": 0.012, "cut_hz": 480.0,
}
## Their volumes at a beat of full strength, in dB of full scale.
const LUB_DB := -20.0
const DUB_DB := -24.0
## **The buzzes**: milliseconds, and amplitude 0..1, at a beat of full strength.
const LUB_BUZZ_MS := 20
const LUB_BUZZ := 0.2
const DUB_BUZZ_MS := 14
const DUB_BUZZ := 0.12
## **The dub's delay**: this long after the lub, and never more than this share of
## the beat's period, so a racing heart's dub still lands inside its own beat.
const DUB_AFTER := 0.24
const DUB_SHARE := 0.32

## The two sounds, made once a process: a few milliseconds of arithmetic.
static var _parts: Array = []


## **The cue**, for game/feel/feel.gd's `cue(&"beat", ...)`.
static func parts() -> Array:
	if _parts.is_empty():
		_parts = [
			{"sound": Tone.thump(LUB), "db": LUB_DB, "buzz_ms": LUB_BUZZ_MS,
				"buzz": LUB_BUZZ},
			{"sound": Tone.thump(DUB), "db": DUB_DB, "buzz_ms": DUB_BUZZ_MS,
				"buzz": DUB_BUZZ, "after": DUB_AFTER, "share": DUB_SHARE},
		]
	return _parts
