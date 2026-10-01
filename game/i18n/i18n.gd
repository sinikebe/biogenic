extends RefCounted
## **The game's languages: every `<locale>.po` in this folder, and in launcher/
## beside it, registered with the engine as the first game screen loads.** A
## language is a file here and nothing else -- see README.md beside this script.
##
## **Two folders, one rule.** `game/i18n/<locale>.po` holds the game's own words and
## `game/i18n/launcher/<locale>.po` the words of the launcher's screens, which are
## the template's (addons/launcher/launcher.pot is their template). The launcher's
## folder is here and not beside that template because every launcher sync replaces
## addons/launcher/ and ci/ wholesale. Both are read the same way: the file's name
## is its locale, the engine holds one catalog per file, and two catalogs of one
## language simply add up.
##
## **Why this exists, when Project Settings can register a `.po`.** A content pack
## mounts over the binary *after* the engine has read its project settings --
## measured with `ProjectSettings.load_resource_pack`: the pack carries a
## `project.binary`, and the settings in it are not read again -- so a language
## registered there is loaded from the APK's own copy of the file, at start, before
## BuildInfo has mounted any pack, and a catalog a content update brings or changes
## is never read: it reaches a phone only with a new APK, a `binary_version` bump
## for a text file. Found at run time, a `.po` travels in the content pack like
## every other file under `game/`, and a language is a content update. Registering
## one in project.godot as well is harmless: the engine holds one resource per file,
## and adding it twice adds it once.
##
## **A process with no screen registers nothing**, and that is on purpose. The
## dedicated server and every CI probe run `--headless`; with no catalog, `tr()`
## hands back the English it was given, so a server's log reads the same on a
## machine set to any language, and a probe that compares a sentence compares
## the English one wherever it is run.
##
## **When it runs.** When this script loads, which is when the first screen that
## preloads it is loaded -- before that screen's nodes exist. That matters: a
## `Label` or a `Button` translates the text it is given at the moment it is
## given, so the words in a scene file (`text = "choose a view"`) would stay
## English if the catalog arrived from the screen's `_ready`. The engine chose
## the locale before any of this, from the device or from `--language` on the
## command line, so there is nothing to choose here: a locale with no `.po`
## falls back to the English the code is written in.
##
## **The launcher's first screen is built before this script has loaded**: it is the
## main scene, and no game script is loaded until Play is pressed. So it is English
## on every start, in any language, and a launcher built again after Play and Back
## is translated. README.md has the measurement, and what registering earlier would
## take, which is the owner's call.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd. Preload
## it by path, **in every screen the player can open first**, and do not remove
## the line for being unused: loading it is the whole of what it does.

# --- The words in launcher_config.tres ---------------------------------------------
# The launcher shows them on its first screen and looks them up in the game's own
# catalog, not in the launcher's, so they are listed here with the game's words. The
# title is a name and is not translated. That screen is built before this script has
# loaded, so they stay English until the player has been into the game and back.
#
# TRANSLATORS "play": A button on the launcher's first screen, the first of the menu
# in the middle of it, in 20 px type: it starts the game. One lowercase word, an
# imperative. The same word is the replay's play button. (The launcher is the app's
# main menu, the screen before the game.)
#
# TRANSLATORS "quit": A button on the launcher's first screen, under "play", in 20 px
# type: it closes the app. One lowercase word, an imperative.
#
# TRANSLATORS "build {build} · updates itself": A small line under the game's title on
# the launcher's first screen, in 17 px type. {build} is the number of the game's
# latest content update, put in by the app: keep {build} exactly as it is, once.
# "Updates itself" means the app downloads and installs its updates by itself.

## Where the game's catalogs are, and where this file lives.
const DIR := "res://game/i18n"
## Where the launcher's catalogs are.
const LAUNCHER_DIR := "res://game/i18n/launcher"

## What was registered, by locale, so a second call has nothing to do.
static var _registered := PackedStringArray()
static var _done := false


## Runs once, when the first screen to preload this script loads it.
static func _static_init() -> void:
	register()


## Registers every `<locale>.po` in [constant DIR] and [constant LAUNCHER_DIR] with
## the TranslationServer, once, and returns the locales it found. Safe to call
## again: the second call returns the same list and does nothing.
##
## **The file's name is its locale** (`fr.po`, `pt_BR.po`, `pt-BR.po`), and it
## wins over the file's own `Language:` header. A `.po` with no header is read by
## the engine as English, and a translated English would translate every screen
## for every player. A name that is not a locale ([method locale_of]), or a file
## the engine will not load, is left alone and said once, in the log.
static func register() -> PackedStringArray:
	if _done:
		return _registered
	_done = true
	if DisplayServer.get_name() == "headless":
		return _registered
	for dir: String in [DIR, LAUNCHER_DIR]:
		_register_folder(dir)
	return _registered


## One folder's catalogs. A folder that does not exist has none: the launcher's is
## made by the first launcher translation.
static func _register_folder(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file: String in DirAccess.get_files_at(dir):
		var name := file.trim_suffix(".remap")
		if name.get_extension() != "po":
			continue
		var path := dir.path_join(name)
		var locale := locale_of(name.get_basename())
		if locale.is_empty():
			push_warning("[I18n] %s is not named for a locale the engine knows; ignored." % path)
			continue
		var catalog := load(path) as Translation
		if catalog == null:
			push_warning("[I18n] %s did not load as a translation; ignored." % path)
			continue
		catalog.locale = locale
		TranslationServer.add_translation(catalog)
		if not locale in _registered:
			_registered.append(locale)


## **The locale a catalog's file name stands for**, as the engine writes it (`fr`,
## `pt_BR`, `zh_Hans`), or "" when the name is not one: a language code in lower
## case, then an optional script and an optional country, joined by `_` or `-`.
## `fr.po` and `pt-BR.po` are locales; `FR.po`, `fr_XX.po` and `french.po` are not.
## The engine's own `TranslationServer.get_locale_name()` cannot tell them apart --
## it answers with its argument for any string -- so this asks its lists of known
## languages, scripts and countries instead. A name the engine spells differently
## comes back spelled its way (`iw` is `he`), and tools/i18n_pot.gd says so.
static func locale_of(file_name: String) -> String:
	var locale := TranslationServer.standardize_locale(file_name)
	var parts := locale.split("_")
	if not TranslationServer.get_all_languages().has(parts[0]):
		return ""
	var scripts := TranslationServer.get_all_scripts()
	var countries := TranslationServer.get_all_countries()
	for i in range(1, parts.size()):
		if not (scripts.has(parts[i]) or countries.has(parts[i])):
			return ""
	return locale
