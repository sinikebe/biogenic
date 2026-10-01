extends RefCounted
## **The game's languages: every `<locale>.po` in this folder, registered with
## the engine as the first screen loads.** A language is one file here and
## nothing else -- see README.md beside this script.
##
## **Why this exists, when Project Settings can register a `.po`.** A content
## pack mounts over the binary *after* the engine has read its project settings
## -- measured with `ProjectSettings.load_resource_pack`: the pack carries a
## `project.binary`, and the settings in it are not read again -- so a language
## registered there reaches a phone only with a new APK: a `binary_version`
## bump for a text file. Found here at run time, a `.po` travels in the content
## pack like every other file under `game/`, and a language is a content update.
## Registering one in project.godot as well is harmless: the engine holds one
## resource per file, and adding it twice adds it once.
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
## No class_name on purpose -- see the note at the top of signal_bus.gd. Preload
## it by path, **in every screen the player can open first**, and do not remove
## the line for being unused: loading it is the whole of what it does.

## Where the catalogs are, and where this file lives.
const DIR := "res://game/i18n"

## What was registered, by locale, so a second call has nothing to do.
static var _registered := PackedStringArray()
static var _done := false


## Runs once, when the first screen to preload this script loads it.
static func _static_init() -> void:
	register()


## Registers every `<locale>.po` in [constant DIR] with the TranslationServer,
## once, and returns the locales it found. Safe to call again: the second call
## returns the same list and does nothing.
##
## **The file's name is its locale** (`fr.po`, `pt_BR.po`, `pt-BR.po`), and it
## wins over the file's own `Language:` header. A `.po` with no header is read by
## the engine as English, and a translated English would translate every screen
## for every player. A name that is not a locale the engine knows is left alone
## and said once, in the log.
static func register() -> PackedStringArray:
	if _done:
		return _registered
	_done = true
	if DisplayServer.get_name() == "headless":
		return _registered
	for file: String in DirAccess.get_files_at(DIR):
		var name := file.trim_suffix(".remap")
		if name.get_extension() != "po":
			continue
		var locale := TranslationServer.standardize_locale(name.get_basename())
		if TranslationServer.get_locale_name(locale).is_empty():
			push_warning("[I18n] %s is not named for a locale the engine knows; ignored." % name)
			continue
		var catalog := load(DIR.path_join(name)) as Translation
		if catalog == null:
			push_warning("[I18n] %s did not load as a translation; ignored." % name)
			continue
		catalog.locale = locale
		TranslationServer.add_translation(catalog)
		_registered.append(locale)
	return _registered
