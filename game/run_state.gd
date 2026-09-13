extends RefCounted
## The little the game remembers between runs: which view was last chosen, and
## whether the one line of onboarding has been read.
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
