extends RefCounted
## The little the game remembers between runs: which view was last chosen, how
## bright the membrane is, whether the one line of onboarding has been read, and
## the language the player chose. And the views themselves, named once: what each
## is called on screen, and the name each keeps its cells under (docs/design/
## cells.md §1.2).
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

## **Each view keeps cells of its own** (docs/design/cells.md §1.2, ocean.md
## §9.5): three slots for each view, and a cell grown in one is never played in
## the other -- seeing everything is not the same game as feeling your way. This
## is the name each view's cells are kept under: in a cell's file and its slot's
## file name (cells.gd, cell_save.gd), and in the worlds a build before cells.md
## wrote, which kept "a cell per view" in the world's file (drop_save.gd) and its
## index (drops.gd). None of them knows a view by meaning.
##
## **Full vision's is "", the one cell every world kept before there were two.**
## Where an old cell was grown cannot be told, and the rule is there to protect
## point of view, so an old cell is full vision's and point of view starts a new
## one. A third view appends a name here, as it appends to [enum Mode].
const CELL_KEYS := {Mode.FULL_VISION: "", Mode.POV: "pov"}

## **What each view is called on screen**: the words of the mode select's own two
## buttons, so a world's line in "your worlds" names a view as the player chose it.
##
## TRANSLATORS: The two views, as the buttons that start a game say them. Also the
## start of a line in the menu of the player's worlds, in 15 px type, for the cell
## that waits in a world for that view: "point of view · fourth generation", where
## the whole line has 280 px.
const VIEW_WORDS := {Mode.FULL_VISION: "full vision", Mode.POV: "point of view"}

## The views in the order the mode select offers them, top first: the order a
## world's line lists their cells in.
const VIEW_ORDER: Array[int] = [Mode.FULL_VISION, Mode.POV]


## **The name [param mode]'s cell is kept under** ([constant CELL_KEYS]). A view
## this build does not know is drawn blind -- only full vision draws the water --
## so it keeps point of view's cell, never full vision's.
static func cell_key(mode: int) -> String:
	return str(CELL_KEYS.get(mode, CELL_KEYS[Mode.POV]))

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


## **Whether a gene's numbers are shown** on the pause screen and the choosing
## screen (docs/design/gene-stats.md §2.2). Remembered beside the camera lock
## for the reason it is: the player who wants the numbers turns them on once and
## reads them from then on, and the one who never asks never sees one. Off by
## default.
static func load_numbers() -> bool:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return false
	return bool(config.get_value("run", "numbers", false))


static func save_numbers(value: bool) -> void:
	_store("run", "numbers", value)


## **The language this player chose** in the settings sheet, as the locale of the
## catalog it picked (`fr`, `pt_BR`, or `en` for the English the game is written
## in), or "" for none: the game follows the device's language, as it did before
## there was a choice. Only the list writes it, so a player who never opens it
## never has one (docs/design/settings.md §3.2). It belongs to the whole app
## rather than to a run, hence its own section; game/i18n/i18n.gd applies it.
static func load_locale() -> String:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return ""
	return str(config.get_value("app", "locale", ""))


static func save_locale(locale: String) -> void:
	_store("app", "locale", locale)


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
