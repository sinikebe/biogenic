extends RefCounted
## **Different things touched, counted a second at a time, and capped.** Touch
## the same thing sixty times in a second and it counts once; touch four
## different things and it counts [member cap]. The beam earns its experience
## this way (docs/design/beam-levels.md §2), and nothing here knows it.
##
## Counting *different* things rather than touches is what lets two ways of
## touching earn alike: many rays that are always on and a few that pass over
## the same things in turn both come to about the things there were.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The most one window can count.
var cap := 3
## How long a window is, in seconds.
var window := 1.0

var _clock := 0.0
var _seen := {}


func _init(most: int = 3, seconds: float = 1.0) -> void:
	cap = maxi(most, 0)
	window = maxf(seconds, 0.001)


## [param id] was touched in the window now running.
func touch(id: int) -> void:
	_seen[id] = true


## Moves the window on by [param delta] seconds. When a window closes, returns
## how many different things it saw, capped; otherwise 0.
func step(delta: float) -> int:
	_clock += maxf(delta, 0.0)
	if _clock < window:
		return 0
	_clock = fmod(_clock, window)
	var counted := mini(_seen.size(), cap)
	_seen.clear()
	return counted


## Starts over with nothing seen and a fresh window.
func reset() -> void:
	_clock = 0.0
	_seen.clear()
