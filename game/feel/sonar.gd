extends RefCounted
## **The ping, heard** (docs/design/sound-and-touch.md §9): a beep as the
## `ampulla` calls, and a different, shorter one for each echo as it comes home,
## as loud as the echo is. The edge that names a sonar: game/feel/feel.gd plays a
## cue and game/feel/tone.gd makes a sound, and neither knows this is one.
##
## The owner, 2026-10-16: *"Now, a beep for the sonar, and a different tone for
## emission and echoes. With variable intensity for echoes depending on time
## traveling."* So:
##
## - **The call falls; an echo is a pip above it.** The call sweeps down from 1.5
##   kHz to 1.05 kHz over a fifth of a second, the way a bat's call sweeps: it
##   is the cell's own act, and the longer of the two. An echo is a short pip at
##   2 kHz, higher than the call ever is -- small and bright, so three to five of
##   them a call read as answers and never as more calls.
## - **An echo is as loud as it is strong.** Its strength is the level
##   food.gd's `ping_level` gives it, which falls with the path it travelled, out
##   and back: about 0.9 off a body a hundred units away, 0.4 at eight hundred,
##   0.15 at the edge of reach, at one copy. Played as amplitude, that is about
##   16 dB from the nearest to the farthest: how long an echo took to come home is
##   how loud it is. A body half behind another comes back quieter as well,
##   because it is.
## - **The band the heart left.** Both sit between 1 and 2.5 kHz, where a phone's
##   speaker is at its best and the heartbeat has nothing (sound-and-touch.md
##   §2.2), and both are short: the call is under a quarter of a second of a call
##   every 8.8 to 15.2 seconds.
## - **Quiet, still.** The call peaks at [constant CALL_DB], an echo of full
##   strength at [constant ECHO_DB]. A tone this high is heard as much louder
##   than the heart at the same level, so these are already the louder thing.
##
## No buzz: the owner asked the ping for sound. Every number here is a starting
## value (sound-and-touch.md §9.4 says what to watch).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Tone := preload("res://game/feel/tone.gd")

## **The call**: a falling beep, on the call itself.
const CALL := {
	"from_hz": 1500.0, "to_hz": 1050.0, "glide": 0.06, "attack": 0.004, "decay": 0.07,
	"length": 0.22, "drive": 0.8, "cut_hz": 6000.0,
}
## **An echo**: a short pip, higher than the call ever is.
const ECHO := {
	"from_hz": 2050.0, "to_hz": 1980.0, "glide": 0.02, "attack": 0.003, "decay": 0.026,
	"length": 0.1, "drive": 0.3, "cut_hz": 4500.0,
}
## Their volumes, in dB of full scale: the call's, and an echo's at strength 1.
const CALL_DB := -22.0
const ECHO_DB := -22.0

static var _call: Array = []
static var _echo: Array = []


## **The call's cue**, for game/feel/feel.gd's `cue()` on the call.
static func call_parts() -> Array:
	if _call.is_empty():
		_call = [{"sound": Tone.thump(CALL), "db": CALL_DB}]
	return _call


## **An echo's cue**, for `cue()` on the bus's `ping`: as loud as the echo is.
static func echo_parts() -> Array:
	if _echo.is_empty():
		_echo = [{"sound": Tone.thump(ECHO), "db": ECHO_DB}]
	return _echo
