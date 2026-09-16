extends RefCounted
## The little the game remembers between runs: which view was last chosen, how
## bright the membrane is, and whether the one line of onboarding has been read.
##
## One small file in user://, separate from the launcher's own state, and never
## instanced -- everything here is static. It is deliberately not an autoload:
## the two autoloads this project has belong to the launcher template, and a
## third would be a project setting change for four functions.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## The two views of one simulation. Point of view is the game the design is
## built around; full vision draws the world under the same membrane so the
## blind signals can be checked against the truth.
##
## Stored as an integer, so adding a third view later appends to this and
## nothing else has to move.
enum Mode { POV, FULL_VISION }

## Where the player's thumbs live. `ANYWHERE` is the scheme the game shipped
## with -- drag the water, a finger down is thrust, a short still press is the
## dash -- and it stays the default. `STICK` draws a knob in a channel and a
## dash pad; `PADS` draws two turn pads, a push pad and a dash pad.
##
## Stored as an integer for the same reason [enum Mode] is: a fourth scheme
## appends to this and nothing else has to move. A file written by a later build
## that has one falls back to `ANYWHERE` here rather than crashing.
enum Scheme { ANYWHERE, STICK, PADS }

## What a fresh install gets: the game as it was designed. One finger, nothing
## drawn over the water, and the dash costing no pixel and no second thumb.
const DEFAULT_SCHEME := Scheme.ANYWHERE

## Kept at the old path so an installed game does not forget it has already
## shown the onboarding line.
const PATH := "user://normal_mode.cfg"

## What a fresh install gets. Vision, because the owner playtests from a phone
## and the world view is what is being tuned.
const DEFAULT_MODE := Mode.FULL_VISION


static func load_mode() -> int:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return DEFAULT_MODE
	var value := int(config.get_value("run", "mode", DEFAULT_MODE))
	if value != Mode.POV and value != Mode.FULL_VISION:
		return DEFAULT_MODE
	return value


static func save_mode(mode: int) -> void:
	_store("run", "mode", mode)


## Membrane sensitivity, stored next to the mode choice because it is the same
## kind of thing: a property of how this player wants the game presented, not of
## the run. The range and the default belong to the signal bus, which owns
## `gain`; this file only remembers a number.
static func load_gain(fallback: float) -> float:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return fallback
	var value := float(config.get_value("run", "gain", fallback))
	if not is_finite(value):
		return fallback
	return value


static func save_gain(value: float) -> void:
	_store("run", "gain", value)


## **Forward is always up**, or north is. A property of how this player wants
## the game presented, exactly like [method load_gain], so it is remembered in
## the same place. Off by default: the world-anchored camera is what every
## rendered frame of the design was judged at.
static func load_camera_locked() -> bool:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return false
	return bool(config.get_value("run", "camera_locked", false))


static func save_camera_locked(value: bool) -> void:
	_store("run", "camera_locked", value)


## Which control scheme this player chose, from the pause screen. Beside the
## camera lock and for the same reason: it is a property of how this player
## wants to hold the game, not of the run.
static func load_scheme() -> int:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return DEFAULT_SCHEME
	var value := int(config.get_value("run", "scheme", DEFAULT_SCHEME))
	if value < Scheme.ANYWHERE or value > Scheme.PADS:
		return DEFAULT_SCHEME
	return value


static func save_scheme(value: int) -> void:
	_store("run", "scheme", value)


static func onboarding_seen() -> bool:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return false
	return bool(config.get_value("onboarding", "seen", false))


static func mark_onboarding_seen() -> void:
	_store("onboarding", "seen", true)


## Writes only when the value actually changed, so the common case costs a read
## and nothing else.
static func _store(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	# A missing file is the first run, not an error.
	config.load(PATH)
	# has_section_key first: get_value() with a null default is an error in
	# Godot 4.7, not a miss.
	if config.has_section_key(section, key) and config.get_value(section, key) == value:
		return
	config.set_value(section, key, value)
	if config.save(PATH) != OK:
		push_warning("[RunState] Could not write %s" % PATH)
