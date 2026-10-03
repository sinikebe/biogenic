extends Node
## **Writes game/i18n/biogenic.pot**, the template every language is made from,
## by reading the game's own source: a string is a message when the code asks for
## its translation, and this finds every such place. Godot's editor can write a
## .pot too, but only from the editor, and it cannot see a string kept in a
## constant -- which is where most of this game's sentences are.
##
##   godot --headless --path . res://tools/i18n_pot.tscn -- --write
##   godot --headless --path . res://tools/i18n_pot.tscn -- --check
##   godot --headless --path . res://tools/i18n_pot.tscn -- --lint-all [--strict]
##   godot --headless --path . res://tools/i18n_pot.tscn -- --pseudo=/tmp/fr.po [--launcher]
##
## `--write` (the default) rewrites the template. `--check` writes nothing and
## fails (exit 1) when the template on disk is not what the source now says, when
## the source asks for a translation this cannot read, or when a ROOM is unreadable
## or narrower than its own English. `--lint-all` reads every catalog --
## `game/i18n/<locale>.po` against the game's template, and
## `game/i18n/launcher/<locale>.po` against the launcher's, which the launcher
## template ships as addons/launcher/launcher.pot -- and fails on what would break
## the game or mistranslate it (a placeholder lost, a plural message with the wrong
## number of forms, a control character, text wider than its room, a game catalog
## that does not name its own language) while only reporting what is untranslated
## or stale; `--strict` fails on those too. It
## passes with no catalog at all. `--pseudo=<file>` writes a template as a language
## of its own, every message run once through Godot's pseudolocalizer (accents, 30 %
## longer, in brackets), to find what will not fit before a real language exists; it
## is written where it is told and never into game/i18n/. Any other argument is
## refused, because the default is to rewrite the template. The output of the writers
## is deterministic: no date, no line numbers, so the same source gives the same bytes
## and a pull request that changes no sentence does not touch the template.
##
## **What counts as a message** (and the only things that do), in `game/**/*.gd`
## outside game/dev/ and game/server/ -- the dev app's readout and the server's
## log are not for a player:
##   - a literal given to `tr()`, `tr_n()`, `TranslationServer.translate()` or
##     `.translate_plural()` -- the second form is for code with no `self`, where
##     `tr()` is not callable, and a context is the optional last argument;
##   - the template given to `Readout.item()` or `Readout.item_n()`, which
##     translates it inside (game/mechanics/readout.gd);
##   - every plain string in a `const` whose comment carries `TRANSLATORS:` -- a
##     table of words or sentences, translated where it is used with `tr(NAME[...])`.
##     A `const` cannot call a function, so this is how a constant takes part;
##   - a literal assigned to `.text`, `.tooltip_text`, `.placeholder_text` or
##     `.title`, which a Control translates by itself, as Godot's own extractor does;
##   - the `text`, `tooltip_text`, `placeholder_text` and `title` of every node in
##     `game/**/*.tscn`;
##   - the `play_text`, `quit_text`, `tagline` and `extra_buttons` of the game's
##     launcher_config.tres, which the launcher shows and looks up in the game's own
##     catalog.
## A `# TRANSLATORS:` comment on the lines directly above a statement (or in the
## doc comment of a constant, or above a `func`, for every message in it) is
## written into the template as an extracted comment for the translator, up to the
## first empty comment line. **A constant's words can carry a context**, as `tr()`'s
## second argument does: a `## CONTEXT: <word>` line beside its TRANSLATORS one puts
## every string of the constant under that `msgctxt`, for a word another message
## already spells the same way and a language says differently (an organ's name
## on the genome page and the sense it reports on an instinct). The code then
## translates it with that context. Text that lives in a scene file has no statement to
## hang a comment on, so a comment can name its message instead --
## `# TRANSLATORS "choose a view": ...` -- in any script.
##
## **A message that must fit says how much room it has**, in a comment line of its
## own beside the TRANSLATORS one: `# ROOM: 47 px at 13 px`. The template then says
## "room: at most 47 px in 13 px type; the English takes 44 px", measured in the
## font the game draws with, and `--lint-all` measures every translation against it:
## the one check on a translator's file that no reading can do. **A message with
## placeholders says what goes in them**, `# ROOM: 560 px at 14 px with word, 99`:
## the text is measured with the widest gene word the catalog has in place of the
## first `%s` and `99` in place of the `%d`. A `with` word is the name of a table of
## words (FILL_TABLES) or the text itself, which has a digit in it. And where several
## messages are drawn as one line -- a gene's numbers, the pause caption, a world's line
## in the world menu -- no one of them has the room, so `--lint-all` builds those lines
## with the game's own code, in the language being checked, and measures them (see
## SCREENS below).
##
## **What it refuses** (`--check` exits 1): a `tr()` of something it cannot read --
## a variable, a call -- unless the expression names a constant that is marked as
## above, because then the strings are in the template already and the call only
## looks one up. Without that, a new message would be translated at run time and
## missing from the template, silently, until the first language was added. The one
## other way out is a comment, on the lines above the statement or the function,
## that says `i18n-ok:` and why: for the few places that translate what their
## callers hand them, which the callers' own literals have already listed. And the
## other way round: a constant marked with `TRANSLATORS:` that no `tr()` names is
## listed for a translator and shown in English -- the commonest way to miss one. (A
## catalog's `get_message()` names one too: it looks a message up as `tr()` does.)
##
## Excluded from export (`tools/*` on every preset), so none of it ships.

const POT_PATH := "res://game/i18n/biogenic.pot"
const PO_DIR := "res://game/i18n"
## The launcher's own screens are the template's, and it ships its own template; its
## catalogs live here, outside addons/launcher/, which every launcher sync replaces.
const LAUNCHER_POT_PATH := "res://addons/launcher/launcher.pot"
const LAUNCHER_PO_DIR := "res://game/i18n/launcher"
## The game's launcher_config.tres, whose words the launcher shows and translates
## with the game's own catalog (the project setting `launcher/config_path` names it).
const CONFIG_PATH := "res://launcher_config.tres"
const CONFIG_TEXT := ["play_text", "quit_text", "tagline"]
const ROOT := "res://game"
## Text that is not shown to a player: the dev app's frame readout, and the
## dedicated server, whose log is the owner's and stays in English.
const SKIP_DIRS: Array[String] = ["res://game/dev", "res://game/server"]
## Node properties a scene can hold text in, which a Control translates itself.
const SCENE_TEXT := ["text", "tooltip_text", "placeholder_text", "title"]
const WRAP := 78

## The two kinds of catalog: a language is at most one file of each, `fr.po` for the
## game and `launcher/fr.po` for the launcher's screens, each made from its own
## template. Only the game's messages carry a measured room (a `ROOM:` line in the
## source): the launcher's text wraps, or its controls grow.
const CATALOGS := [
	{"name": "game", "dir": PO_DIR, "pot": POT_PATH, "rooms": true},
	{"name": "launcher", "dir": LAUNCHER_PO_DIR, "pot": LAUNCHER_POT_PATH, "rooms": false},
]
## Counts that tell every plural rule in use apart: 0, 1, 2, the few, the teens, the
## twenties, the hundreds and a thousand.
const PROBE_COUNTS := [0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 20, 21, 22, 23, 24, 25,
	100, 101, 102, 111, 112, 1000, 1001]
## How many messages of one kind a report lists before it says "and N more".
const LIST_AT_MOST := 40

## What a word after `with` in a ROOM stands for: the constant, marked with TRANSLATORS:,
## that holds the words. A table gives its widest entry in the language being checked (the
## English where the catalog has not translated it), and when it fills two placeholders of
## one message, its two widest, because one line never names the same gene twice. Any other
## word after `with` is the text itself and has a digit in it: `99`, `80%`.
const FILL_TABLES := {"word": "WORDS", "way": "PATH_TITLES", "copies": "COPIES",
	"sense": "GENE_SENSES", "action": "GENE_SAYS", "body": "BODY_SAYS", "ref": "REFERENCE_SAYS",
	"trigger": "TRIGGER_SAYS", "already": "ALREADY", "always": "ALWAYS_DOES"}
## How the template says each table's entry, the first time and when it comes again.
const FILL_SAYS := {
	"word": ["your widest gene word", "your second widest"],
	"way": ["your widest way name", "your other way name"],
	"copies": ["your widest copies phrase", "your second widest"],
	"sense": ["your widest sense word", "your second widest"],
	"action": ["your widest action word", "your second widest"],
	"body": ["your widest word of the body's own", "your second widest"],
	"ref": ["your wider of \"my mouth\" and \"me\"", "the other"],
	"trigger": ["your widest of \"steering\", \"tail\", \"dash\" and \"push\"",
		"your second widest"],
	"already": ["your widest \"already steers\" phrase", "your second widest"],
	"always": ["your widest \"always swims\" phrase", "your second widest"],
}

## **The lines the game composes from several messages and draws as one** (SCREENS):
## no message has a room of its own there, so each is built with the game's own code, in
## the language being checked, and measured whole. A gene's numbers are two lines of items
## joined with a middle dot (game/normal/gene_stats.gd, drawn by `Readout.draw`), centred
## under the figure of the pause screen at 14 px: the Leave button is 344 px from the middle
## of the line, so 650 px leaves it 19 px of air; a longer line runs into it. The pause
## screen's caption is a label in a column 560 px wide (normal_mode.tscn, Genome): a label
## wider than that makes the column, and so the whole screen, wider.
const NUMBERS_ROOM := 650
const NUMBERS_SIZE := 14
const CAPTION_ROOM := 560
const CAPTION_SIZE := 15
## **A world's line in "your worlds"** (docs/design/settings.md §4.3, §7): its generation
## and its age joined with a middle dot (game/normal/drops.gd's `line`, where a world is a
## drop), under the world's name at 15 px. The menu is 640 px; less its margins, the row's two 112 px buttons and
## their gaps, and the row's 52 px for the mark and 16 at the right, 280 are left, and a
## longer line ends in "…".
const STATS_ROOM := 280
const STATS_SIZE := 15
## **An instinct's row on the programs page** (docs/design/automation-ux.md §8,
## `ROW_ROOM`): for every sense, its widest test on each value it carries and the
## widest action, laid out as the page lays them at 1280 -- a row 856 px wide --
## must leave this much of the arc between them, or the row reads as chips with no
## nerve. And each line of the inspector's triggers, a trigger's word and where a
## program stands on it after a default name, fits the inspector's 230 px at 14.
## Both are measured by the page's own code (`programs_page.gd`).
const ROW_ROOM := 40
const TRIGGER_LINE_ROOM := 230
## The scripts that build those lines, loaded only when a game catalog is being checked.
const SCREEN_SCRIPTS := {
	"stats": "res://game/normal/gene_stats.gd",
	"readout": "res://game/mechanics/readout.gd",
	"genome": "res://game/normal/genome.gd",
	"cell": "res://game/normal/cell.gd",
	"i18n": "res://game/i18n/i18n.gd",
	"drops": "res://game/normal/drops.gd",
	"programs": "res://game/normal/programs_page.gd",
}

enum K { IDENT, STR, NAME, NUM, PUNCT }

## The comment every `Readout.item` template gets, whatever its own notes say.
const READOUT_NOTE := "A phrase of a gene's numbers, in 14 px type; {} is a number the game " \
	+ "writes, so keep every {}, its unit (µm, s, ×, °) and its order. Phrases are joined " \
	+ "with a middle dot into a line of at most 650 px; the longest English line takes 550 px."
## What a `ROOM:` line looks like, once its words are read: the mark, then its px,
## its type size and its `with` words, apart by FIELD.
const ROOM_MARK := "\u0001ROOM "
const FIELD := "\u0002"
## And a `CONTEXT:` line, once read.
const CONTEXT_MARK := "\u0001CONTEXT "

## One file's code as tokens, kept in parallel arrays: a run of a thousand lines is
## tens of thousands of them, and an object each would be slow to make.
class Toks:
	var kind := PackedInt32Array()
	var text := PackedStringArray()
	var line := PackedInt32Array()
	## 1 for the first token of a statement: after a newline outside any bracket
	## that is not a line continuation.
	var first := PackedByteArray()
	## How far in the line the token is: 0 for a statement of the script itself,
	## more for one inside a function.
	var col := PackedInt32Array()
	## The comments that are alone on their line, by line number.
	var comments := {}

	func size() -> int:
		return kind.size()

## Notes addressed to a message by name: `[msgid, note, path, line]`.
var _named: Array = []

## Every message found: `{key: {ctx, id, plural, refs, notes, auto, kind}}`, and
## the keys in the order they were first met.
var _entries := {}
var _order: Array[String] = []
var _problems: Array[String] = []
## `--strict`: a message not translated, or stale, fails the lint instead of being reported.
var _strict := false
var _files := 0
var _tokens := {}
## The constants marked with `TRANSLATORS:`, by name. Which file does not matter:
## a name two files share is read as either.
var _marked := {}
## The constants some `tr()` names, so that one that none does can be said.
var _named_in_calls := {}
## The strings of every constant marked with `TRANSLATORS:`, by its name, in the order
## they are written: the tables a ROOM's `with` words name (FILL_TABLES).
var _const_ids := {}
## The same for a table with keys (`WORDS`): `{name: {key: first string}}`.
var _const_pairs := {}


func _ready() -> void:
	var mode := "--write"
	var target := ""
	var launcher := false
	var unknown: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text in ["--write", "--check", "--lint-all"]:
			mode = text
		elif text == "--lint-po":
			mode = "--lint-all"
		elif text == "--strict":
			_strict = true
		elif text == "--launcher":
			launcher = true
		elif text.begins_with("--pseudo="):
			mode = "--pseudo"
			target = text.trim_prefix("--pseudo=")
		else:
			unknown.append(text)
	# An unknown flag must not fall through to the default, which rewrites the template.
	if not unknown.is_empty():
		print("[i18n] unknown argument(s): %s" % " ".join(unknown))
		print("[i18n] usage: -- --write | --check | --lint-all [--strict] | --pseudo=<file> [--launcher]")
		get_tree().quit(2)
		return
	var code := _run(mode, target, launcher)
	get_tree().quit(code)


func _run(mode: String, target: String = "", launcher: bool = false) -> int:
	_collect()
	var made := _pot_text()
	var code := 0
	for problem in _problems:
		print("[i18n] PROBLEM ", problem)
	if not _problems.is_empty():
		code = 1
	match mode:
		"--write":
			if code == 0:
				var out := FileAccess.open(POT_PATH, FileAccess.WRITE)
				if out == null:
					print("[i18n] cannot write %s (error %d)" % [POT_PATH, FileAccess.get_open_error()])
					return 1
				out.store_string(made)
				out.close()
				print("[i18n] wrote %s: %d messages from %d files" % [POT_PATH, _order.size(), _files])
			else:
				print("[i18n] not written: the source asks for translations this cannot read")
		"--check":
			var have := FileAccess.get_file_as_string(POT_PATH)
			if have != made:
				print("[i18n] STALE %s is not what the source says; run with --write" % POT_PATH)
				_say_difference(have, made)
				code = 1
			elif code == 0:
				print("[i18n] ALL PASS: %s is current, %d messages from %d files" % [
					POT_PATH, _order.size(), _files])
		"--lint-all":
			code = maxi(code, _lint_all())
		"--pseudo":
			if code == 0:
				code = _write_pseudo(target, launcher)
	return code


# ---------------------------------------------------------------------------
# Reading the source.
# ---------------------------------------------------------------------------

func _collect() -> void:
	var gd: Array[String] = []
	var scenes: Array[String] = []
	_walk(ROOT, gd, scenes)
	gd.sort()
	scenes.sort()
	# Two passes: a call can name a marked constant that a later file defines.
	for path in gd:
		_tokens[path] = _tokenize(FileAccess.get_file_as_string(path))
		_find_marked(path)
	var files: Array[String] = []
	files.append_array(gd)
	files.append_array(scenes)
	files.sort()
	for path in files:
		_files += 1
		if path.ends_with(".gd"):
			_read_code(path)
		else:
			_read_scene(path)
	_files += 1
	_read_config()
	for name: String in _marked:
		if not _named_in_calls.has(name):
			_problems.append(("%s: `%s` is marked with TRANSLATORS: but no tr() names it,"
				+ " so it is listed and never translated") % [_marked[name], name])
	for named: Array in _named:
		var key := "\u0004" + String(named[0])
		if not _entries.has(key):
			_problems.append("%s:%d: a note for \"%s\", which is not a message" % [
				named[2], named[3], named[0]])
		elif not named[1] in _entries[key]["notes"]:
			_entries[key]["notes"].append(named[1])
	_check_rooms()


func _walk(dir: String, gd: Array[String], scenes: Array[String]) -> void:
	if dir in SKIP_DIRS:
		return
	for sub in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(sub), gd, scenes)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			gd.append(dir.path_join(file))
		elif file.ends_with(".tscn"):
			scenes.append(dir.path_join(file))


## The tokens of GDScript source: strings (with their escapes read), names,
## numbers and punctuation, and the comments that stand alone on a line.
func _tokenize(src: String) -> Toks:
	var toks := Toks.new()
	var re := RegEx.new()
	# comment | triple-quoted | string, &"name" or ^"path" | identifier | number
	# | newline | any other mark. \x22 is the double quote and \x27 the apostrophe.
	re.compile(r"(?<c>#[^\n]*)|(?<t>\x22\x22\x22[\s\S]*?\x22\x22\x22)|(?<s>[&^]?\x22(?:[^\x22\\\n]|\\.)*\x22|\x27(?:[^\x27\\\n]|\\.)*\x27)|(?<i>[A-Za-z_][A-Za-z_0-9]*)|(?<n>[0-9][A-Za-z_0-9.]*)|(?<l>\n)|(?<p>\S)")
	var line := 1
	var depth := 0
	var start := true
	var line_has_code := false
	var line_from := 0
	var last := ""
	for m in re.search_all(src):
		var c := m.get_string("c")
		if not c.is_empty():
			if not line_has_code:
				toks.comments[line] = c
			continue
		var l := m.get_string("l")
		if not l.is_empty():
			line += 1
			line_from = m.get_end()
			line_has_code = false
			if depth <= 0 and last != "\\":
				start = true
			continue
		var kind := K.PUNCT
		var text := ""
		var t := m.get_string("t")
		var s := m.get_string("s")
		if not t.is_empty():
			kind = K.STR
			text = t.substr(3, t.length() - 6)
		elif not s.is_empty():
			kind = K.NAME if s[0] == "&" or s[0] == "^" else K.STR
			var body := s.substr(1) if kind == K.NAME else s
			text = _unescape(body.substr(1, body.length() - 2))
		elif not m.get_string("i").is_empty():
			kind = K.IDENT
			text = m.get_string("i")
		elif not m.get_string("n").is_empty():
			kind = K.NUM
			text = m.get_string("n")
		else:
			text = m.get_string("p")
			if text in ["(", "[", "{"]:
				depth += 1
			elif text in [")", "]", "}"]:
				depth -= 1
		toks.kind.append(kind)
		toks.text.append(text)
		toks.line.append(line)
		toks.first.append(1 if start else 0)
		toks.col.append(m.get_start() - line_from)
		start = false
		line_has_code = true
		last = text
		if not t.is_empty():
			line += t.count("\n")
			line_from = m.get_start() + t.rfind("\n") + 1
	return toks


## A GDScript string's body, without the quotes, with its escapes read.
func _unescape(body: String) -> String:
	if not body.contains("\\"):
		return body
	var out := ""
	var i := 0
	while i < body.length():
		var ch := body[i]
		if ch != "\\" or i + 1 >= body.length():
			out += ch
			i += 1
			continue
		var next := body[i + 1]
		match next:
			"n": out += "\n"
			"t": out += "\t"
			"r": out += "\r"
			"u":
				out += String.chr(body.substr(i + 2, 4).hex_to_int())
				i += 4
			_: out += next
		i += 2
	return out


## Notes the translator wrote on the comment lines directly above [param at]:
## each `TRANSLATORS:` paragraph, to its first empty comment line.
func _notes_above(toks: Toks, at: int, path: String = "") -> Array[String]:
	var above: Array[String] = []
	var lines: Array[int] = []
	var l := at - 1
	while toks.comments.has(l):
		above.push_front(String(toks.comments[l]))
		lines.push_front(l)
		l -= 1
	var notes: Array[String] = []
	var current := ""
	var open := false
	var room := RegEx.new()
	room.compile(r"^ROOM:\s*(\d+)\s*px\s+at\s+(\d+)\s*px(?:\s+with\s+(\S.*?))?\s*$")
	var context := RegEx.new()
	context.compile(r"^CONTEXT:\s*(\S+)\s*$")
	for k in above.size():
		var body := above[k].lstrip("#").strip_edges()
		var said := context.search(body)
		if said != null:
			if open:
				notes.append(current)
				open = false
			notes.append(CONTEXT_MARK + said.get_string(1))
			continue
		var m := room.search(body)
		if m != null:
			if open:
				notes.append(current)
				open = false
			notes.append(ROOM_MARK + m.get_string(1) + FIELD + m.get_string(2) + FIELD + m.get_string(3))
			continue
		if body.begins_with("ROOM:") and not path.is_empty():
			_problems.append(("%s:%d: a ROOM: line this cannot read: it is `ROOM: <px> px at <size> px`,"
				+ " and then, for a message with placeholders, `with <what goes in each>`") % [path, lines[k]])
			continue
		if body.begins_with("TRANSLATORS:"):
			if open:
				notes.append(current)
			current = body.trim_prefix("TRANSLATORS:").strip_edges()
			open = true
		elif open and not body.is_empty():
			current += " " + body
		elif open:
			notes.append(current)
			open = false
	if open:
		notes.append(current)
	return notes


## Whether the comment lines directly above [param at] say `i18n-ok:`.
func _pragma_above(toks: Toks, at: int) -> bool:
	var l := at - 1
	while toks.comments.has(l):
		if String(toks.comments[l]).contains("i18n-ok:"):
			return true
		l -= 1
	return false


## Notes addressed to a message by name, for text that lives in a scene file:
## `# TRANSLATORS "choose a view": the note`, which goes on to the comment lines
## below it, to the first empty one.
func _read_named_notes(path: String, toks: Toks) -> void:
	var re := RegEx.new()
	re.compile(r'^#+\s*TRANSLATORS\s+"((?:[^"\\]|\\.)*)":\s*(.*)$')
	var lines: Array = toks.comments.keys()
	lines.sort()
	for l: int in lines:
		var m := re.search(String(toks.comments[l]))
		if m == null:
			continue
		var note := m.get_string(2)
		var next := l + 1
		while toks.comments.has(next):
			var body := String(toks.comments[next]).lstrip("#").strip_edges()
			if body.is_empty() or body.begins_with("TRANSLATORS"):
				break
			note += " " + body
			next += 1
		_named.append([_unescape(m.get_string(1)), note.strip_edges(), path, l])


## The next statement after [param i], as the index it starts at.
func _statement_end(toks: Toks, i: int) -> int:
	var j := i + 1
	while j < toks.size() and toks.first[j] == 0:
		j += 1
	return j


func _find_marked(path: String) -> void:
	var toks: Toks = _tokens[path]
	var i := 0
	while i < toks.size():
		var j := _statement_end(toks, i)
		if toks.kind[i] == K.IDENT and toks.text[i] == "const" and i + 1 < j \
				and not _notes_above(toks, toks.line[i]).is_empty():
			_marked[toks.text[i + 1]] = path
		i = j


func _read_code(path: String) -> void:
	var toks: Toks = _tokens[path]
	_read_named_notes(path, toks)
	# The notes above a `func` apply to every message in it, besides the ones above
	# the statement itself: they say what a whole function's messages are.
	var in_function: Array[String] = []
	var function_ok := false
	var i := 0
	while i < toks.size():
		var j := _statement_end(toks, i)
		var notes := _notes_above(toks, toks.line[i], path)
		if toks.col[i] == 0:
			in_function = []
			function_ok = false
			var at := i + 1 if toks.text[i] == "static" else i
			if toks.text[at] == "func":
				in_function = notes
				function_ok = _pragma_above(toks, toks.line[i])
		if toks.kind[i] == K.IDENT and toks.text[i] == "const":
			if not notes.is_empty():
				_read_const(path, toks, i, j, notes)
		else:
			var all: Array[String] = []
			all.append_array(in_function)
			for note in notes:
				if not note in all:
					all.append(note)
			_read_calls(path, toks, i, j, all,
				function_ok or _pragma_above(toks, toks.line[i]))
		i = j


## The strings of a marked constant: every plain string in its value, with the
## keys of the tables it sits in, so a translator is told which entry a line is.
func _read_const(path: String, toks: Toks, from: int, to: int, notes: Array[String]) -> void:
	var eq := from
	while eq < to and not (toks.kind[eq] == K.PUNCT and toks.text[eq] == "="):
		eq += 1
	var frames: Array = []
	var table := toks.text[from + 1] if from + 1 < to else ""
	var i := eq + 1
	while i < to:
		var kind := toks.kind[i]
		var text := toks.text[i]
		if kind == K.PUNCT:
			if text == "{":
				frames.push_back({"dict": true, "key": ""})
			elif text == "[" or text == "(":
				frames.push_back({"dict": false, "key": ""})
			elif text == "}" or text == "]" or text == ")":
				if not frames.is_empty():
					frames.pop_back()
			elif text == "," and not frames.is_empty():
				frames.back()["key"] = ""
			i += 1
			continue
		if kind != K.STR and kind != K.NAME:
			i += 1
			continue
		var in_dict: bool = not frames.is_empty() and frames.back()["dict"]
		if in_dict and frames.back()["key"] == "" and i + 1 < to \
				and toks.kind[i + 1] == K.PUNCT and toks.text[i + 1] == ":":
			frames.back()["key"] = text
			i += 2
			continue
		if kind == K.NAME:
			i += 1
			continue
		var whole := text
		while i + 2 < to and toks.kind[i + 1] == K.PUNCT and toks.text[i + 1] == "+" \
				and toks.kind[i + 2] == K.STR:
			whole += toks.text[i + 2]
			i += 2
		i += 1
		if whole.is_empty():
			continue
		var keys: Array[String] = []
		for frame: Dictionary in frames:
			if frame["dict"] and frame["key"] != "":
				keys.append(frame["key"])
		var auto: Array[String] = []
		if not keys.is_empty():
			auto.append("entry: " + "/".join(keys))
		var ids: Array = _const_ids.get(table, [])
		if not whole in ids:
			ids.append(whole)
		_const_ids[table] = ids
		if not keys.is_empty():
			var pairs: Dictionary = _const_pairs.get(table, {})
			if not pairs.has(keys[0]):
				pairs[keys[0]] = whole
			_const_pairs[table] = pairs
		_add(whole, _context_of(notes), "", path, notes, auto, "const")


## The context a constant's `CONTEXT:` line gives its strings, or "".
func _context_of(notes: Array[String]) -> String:
	for note in notes:
		if note.begins_with(CONTEXT_MARK):
			return note.trim_prefix(CONTEXT_MARK)
	return ""


## The calls in one statement that ask for a translation.
func _read_calls(path: String, toks: Toks, from: int, to: int, notes: Array[String],
		allowed: bool) -> void:
	for i in range(from, to):
		if toks.kind[i] != K.IDENT:
			continue
		var name := toks.text[i]
		var form := ""
		var kind := "code"
		var before := toks.text[i - 1] if i > from else ""
		match name:
			"tr", "atr":
				form = "tr"
				if before == "." and not (i - 2 >= from and toks.text[i - 2] == "self"):
					continue
			"tr_n", "atr_n":
				form = "tr_n"
			"translate", "translate_plural":
				if not (before == "." and i - 2 >= from and toks.text[i - 2] == "TranslationServer"):
					continue
				form = "tr" if name == "translate" else "tr_n"
			"item", "item_n":
				if not (before == "." and i - 2 >= from and toks.text[i - 2] == "Readout"):
					continue
				form = "tr" if name == "item" else "tr_n"
				kind = "readout"
			"text", "tooltip_text", "placeholder_text", "title":
				_read_assignment(path, toks, i, to, notes)
				continue
			"get_message":
				# **One catalog asked for one message**, as i18n.gd asks each game
				# catalog for its own name: `catalog.get_message(OWN_NAME)`. A marked
				# constant handed to it is looked up by its English, exactly as a tr()
				# looks it up, so it is named as a tr() would name it. Nothing is
				# listed from the call: the constant lists itself.
				if before == "." and i + 1 < to and toks.text[i + 1] == "(":
					var looked := _args(toks, i + 1, to)
					if not looked.is_empty():
						for k in range(looked[0][0], looked[0][1]):
							if toks.kind[k] == K.IDENT:
								_named_in_calls[toks.text[k]] = true
				continue
			_:
				continue
		if i + 1 >= to or toks.text[i + 1] != "(":
			continue
		var args := _args(toks, i + 1, to)
		if args.is_empty():
			continue
		for arg: Array in args.slice(0, 2):
			for k in range(arg[0], arg[1]):
				if toks.kind[k] == K.IDENT:
					_named_in_calls[toks.text[k]] = true
		var msgid: Variant = _literal(toks, args[0])
		if msgid == null:
			if not allowed and not _names_marked(toks, args[0]):
				_problems.append(("%s:%d: %s() of something that is not a literal and names no"
					+ " `TRANSLATORS:` constant -- the template cannot list it")
					% [path, toks.line[i], name])
			continue
		var plural := ""
		var ctx := ""
		if form == "tr_n":
			var p = _literal(toks, args[1]) if args.size() > 1 else null
			if p == null:
				_problems.append("%s:%d: %s() with a plural that is not a literal" % [path, toks.line[i], name])
				continue
			plural = p
		var ctx_at := 3 if form == "tr_n" else 1
		if kind == "readout":
			ctx_at = 99
		if args.size() > ctx_at:
			var c = _literal(toks, args[ctx_at])
			if c != null:
				ctx = c
		_add(msgid, ctx, plural, path, notes, [], kind)


## `.text = "literal"`: a Control translates its own text, so the literal is a
## message, and the template must list it.
func _read_assignment(path: String, toks: Toks, i: int, to: int, notes: Array[String]) -> void:
	if i == 0 or toks.text[i - 1] != "." or i + 2 >= to or toks.text[i + 1] != "=":
		return
	var value: Variant = _literal(toks, [i + 2, to])
	if value != null and not String(value).is_empty():
		_add(String(value), "", "", path, notes, [], "code")


## The argument ranges `[from, to)` of the call whose `(` is at [param open].
func _args(toks: Toks, open: int, to: int) -> Array:
	var out: Array = []
	var depth := 0
	var from := open + 1
	for i in range(open, to):
		var text := toks.text[i]
		if toks.kind[i] != K.PUNCT:
			continue
		if text == "(" or text == "[" or text == "{":
			depth += 1
		elif text == ")" or text == "]" or text == "}":
			depth -= 1
			if depth == 0:
				if i > from:
					out.append([from, i])
				return out
		elif text == "," and depth == 1:
			out.append([from, i])
			from = i + 1
	return []


## The string a range of tokens is, when it is one literal or several joined with
## `+`; null when it is anything else.
func _literal(toks: Toks, range_: Array) -> Variant:
	var from: int = range_[0]
	var to: int = range_[1]
	while to - from >= 2 and toks.text[from] == "(" and toks.text[to - 1] == ")":
		from += 1
		to -= 1
	var out := ""
	var i := from
	while i < to:
		if toks.kind[i] != K.STR:
			return null
		out += toks.text[i]
		i += 1
		if i < to:
			if toks.text[i] != "+":
				return null
			i += 1
			if i >= to:
				return null
	return out if from < to else null


## Whether an expression names a constant marked with `TRANSLATORS:`.
func _names_marked(toks: Toks, range_: Array) -> bool:
	for i in range(range_[0], range_[1]):
		if toks.kind[i] == K.IDENT and _marked.has(toks.text[i]):
			return true
	return false


func _read_scene(path: String) -> void:
	var node := ""
	var type := ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := String(raw)
		if line.begins_with("[node "):
			var name := _between(line, "name=\"", "\"")
			var parent := _between(line, "parent=\"", "\"")
			type = _between(line, "type=\"", "\"")
			node = name if parent.is_empty() or parent == "." else parent + "/" + name
			if type.is_empty():
				type = "node"
			continue
		var at := line.find(" = \"")
		if at < 0 or not line.ends_with("\""):
			continue
		var key := line.substr(0, at)
		if not key in SCENE_TEXT:
			continue
		var value := _unescape(line.substr(at + 4, line.length() - at - 5))
		if value.is_empty():
			continue
		_add(value, "", "", path, [], ["%s \"%s\" in %s" % [type, node.get_file(), path.trim_prefix("res://")]], "scene")


## **The words in the game's launcher_config.tres**: the Play and Quit buttons, any
## extra button, and the tagline. The launcher shows them on its first screen and
## translates them with the game's own catalog, not its own, so they are listed here
## with the game's other words. (The title is a name and stays as it is.)
func _read_config() -> void:
	var path := str(ProjectSettings.get_setting("launcher/config_path", CONFIG_PATH))
	if not FileAccess.file_exists(path):
		return
	var quoted := RegEx.new()
	quoted.compile(r"\x22((?:[^\x22\\]|\\.)*)\x22")
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := String(raw)
		var at := line.find(" = ")
		if at < 0:
			continue
		var key := line.substr(0, at)
		if not key in CONFIG_TEXT and key != "extra_buttons":
			continue
		for m in quoted.search_all(line.substr(at + 3)):
			var value := _unescape(m.get_string(1))
			if not value.is_empty():
				_add(value, "", "", path, [], ["Setting \"%s\" in %s" % [key, path.trim_prefix("res://")]], "config")


func _between(text: String, open: String, close: String) -> String:
	var a := text.find(open)
	if a < 0:
		return ""
	a += open.length()
	var b := text.find(close, a)
	return text.substr(a, b - a) if b >= 0 else ""


func _add(id: String, ctx: String, plural: String, path: String, notes: Array[String],
		auto: Array[String], kind: String) -> void:
	var key := ctx + "\u0004" + id
	var entry: Dictionary = _entries.get(key, {})
	if entry.is_empty():
		entry = {"ctx": ctx, "id": id, "plural": plural, "refs": [], "notes": [], "auto": [], "kinds": []}
		_entries[key] = entry
		_order.append(key)
	elif plural != "" and entry["plural"] != "" and entry["plural"] != plural:
		_problems.append("%s: \"%s\" has two different plurals: \"%s\" and \"%s\"" % [
			path, id, entry["plural"], plural])
	elif plural != "":
		entry["plural"] = plural
	var ref := path.trim_prefix("res://")
	if not ref in entry["refs"]:
		entry["refs"].append(ref)
	for note in notes:
		if note.begins_with(CONTEXT_MARK):
			continue
		if note.begins_with(ROOM_MARK):
			var at := note.trim_prefix(ROOM_MARK).split(FIELD)
			var fills: Array = []
			for word in String(at[2]).split(","):
				if not word.strip_edges().is_empty():
					fills.append(word.strip_edges())
			# One message in several places keeps the tightest room it is given.
			if not entry.has("room") or int(at[0]) < int(entry["room"][0]):
				entry["room"] = [int(at[0]), int(at[1]), fills]
		elif not note in entry["notes"]:
			entry["notes"].append(note)
	for note in auto:
		if not note in entry["auto"]:
			entry["auto"].append(note)
	if not kind in entry["kinds"]:
		entry["kinds"].append(kind)


# ---------------------------------------------------------------------------
# Writing the template.
# ---------------------------------------------------------------------------

func _pot_text() -> String:
	var out := PackedStringArray()
	out.append("# Biogenic message catalog template.")
	out.append("#")
	out.append("# Written by tools/i18n_pot.gd from the game's source: do not edit it by hand.")
	out.append("# Run the tool again instead; game/i18n/README.md says how, and how to make a")
	out.append("# language from this file.")
	out.append("#")
	out.append("msgid \"\"")
	out.append("msgstr \"\"")
	for header in [
			"Project-Id-Version: Biogenic",
			"MIME-Version: 1.0",
			"Content-Type: text/plain; charset=UTF-8",
			"Content-Transfer-Encoding: 8bit",
			"Language: ",
			"Plural-Forms: nplurals=2; plural=(n != 1);",
			"X-Generator: tools/i18n_pot.gd"]:
		out.append("\"%s\\n\"" % header)
	for key in _order:
		var e: Dictionary = _entries[key]
		out.append("")
		for note in e["notes"]:
			out.append_array(_wrap("#. ", note))
		for note in e["auto"]:
			out.append_array(_wrap("#. ", note))
		if "readout" in e["kinds"]:
			out.append_array(_wrap("#. ", READOUT_NOTE))
		elif String(e["id"]).contains("{}"):
			out.append_array(_wrap("#. ", "{} is a number the game writes; keep every {}, in this order."))
		if e.has("room"):
			out.append_array(_wrap("#. ", _room_note(e)))
		out.append("#: " + " ".join(e["refs"]))
		var flags := _flags(String(e["id"]) + String(e["plural"]))
		if not flags.is_empty():
			out.append("#, " + ", ".join(flags))
		if e["ctx"] != "":
			out.append("msgctxt " + _quote(e["ctx"]))
		out.append("msgid " + _quote(e["id"]))
		if e["plural"] != "":
			out.append("msgid_plural " + _quote(e["plural"]))
			out.append("msgstr[0] \"\"")
			out.append("msgstr[1] \"\"")
		else:
			out.append("msgstr \"\"")
	return "\n".join(out) + "\n"


## **A template as a language of its own**, for `--pseudo=<file>` (the game's) and
## `--pseudo=<file> --launcher` (the launcher's): every message through Godot's own
## pseudolocalizer once, so it is accented, 30 % longer, and wrapped in brackets, and
## anything still in plain English on a screen was missed by `tr()`. Written outside
## game/i18n/ on purpose -- a file there ships. README.md says how to look at it.
## (The engine's `internationalization/pseudolocalization` settings do the same to
## every string, but pad a Label's text a second time.)
func _write_pseudo(path: String, launcher: bool) -> int:
	if path.is_empty() or path.begins_with(PO_DIR):
		print("[i18n] --pseudo=<file> wants a path outside %s, which would ship it" % PO_DIR)
		return 1
	var template_path := LAUNCHER_POT_PATH if launcher else POT_PATH
	if not FileAccess.file_exists(template_path):
		print("[i18n] there is no template at %s" % template_path)
		return 1
	var template := _parse_po(template_path)
	ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", 0.3)
	ProjectSettings.set_setting("internationalization/pseudolocalization/prefix", "[")
	ProjectSettings.set_setting("internationalization/pseudolocalization/suffix", "]")
	TranslationServer.reload_pseudolocalization()
	var out := PackedStringArray()
	out.append("msgid \"\"")
	out.append("msgstr \"\"")
	for header in [
			"Language: fr",
			"Content-Type: text/plain; charset=UTF-8",
			"Plural-Forms: nplurals=2; plural=(n != 1);"]:
		out.append("\"%s\\n\"" % header)
	var count := 0
	for e: Dictionary in template["entries"]:
		out.append("")
		if e["ctx"] != "":
			out.append("msgctxt " + _quote(e["ctx"]))
		out.append("msgid " + _quote(e["id"]))
		if e["has_plural"]:
			out.append("msgid_plural " + _quote(e["plural"]))
			out.append("msgstr[0] " + _quote(_pseudo(e["id"])))
			out.append("msgstr[1] " + _quote(_pseudo(e["plural"])))
		else:
			out.append("msgstr " + _quote(_pseudo(e["id"])))
		count += 1
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("[i18n] cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return 1
	file.store_string("\n".join(out) + "\n")
	file.close()
	print("[i18n] wrote %s: %d messages from %s, pseudolocalized" % [path, count, template_path])
	return 0


## [param text] through the pseudolocalizer, which keeps `{}` as it is and accents the
## name in `{name}`: the names are put back, in order.
func _pseudo(text: String) -> String:
	var named := RegEx.new()
	named.compile(r"\{[A-Za-z_]+\}")
	var names: Array[String] = []
	for m in named.search_all(text):
		names.append(m.get_string())
	var said := String(TranslationServer.pseudolocalize(named.sub(text, "{}", true)))
	for name in names:
		var at := said.find("{}")
		if at < 0:
			break
		said = said.substr(0, at) + name + said.substr(at + 2)
	return said


## How wide [param text] is drawn at [param size], in the font the game draws with.
func _width_of(text: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


## **How wide [param text] is in the room [param room] describes** (`[px, size, fills]`):
## as it is, or -- when it has placeholders -- with what the room's `with` words put in
## them, the widest the catalog allows ([param texts] is its translations by English
## message; empty for the English). -1 for a text with placeholders and a room that does
## not say what goes in them: there is no honest width to measure.
func _room_width(text: String, room: Array, texts: Dictionary) -> float:
	var size: int = room[1]
	if _count_holes(text) == 0:
		return _width_of(text, size)
	var fills: Array = room[2]
	if fills.is_empty():
		return -1.0
	return _width_of(_filled(text, _fill_values(fills, size, texts)), size)


## The template's sentence about a message's room: "Room: at most 560 px in 14 px type,
## measured with your widest gene word and 99 in place of the placeholders; the English
## takes 355 px."
func _room_note(e: Dictionary) -> String:
	var room: Array = e["room"]
	var said := "Room: at most %d px in %d px type" % [room[0], room[1]]
	var fills: Array = room[2]
	if not fills.is_empty():
		said += ", measured with %s in place of the placeholders" % _fills_say(fills)
	var english := _room_width(String(e["id"]), room, {})
	if english >= 0.0:
		said += "; the English takes %d px" % int(ceilf(english))
	return said + "."


## What a room's `with` words say to a translator: "your widest gene word and 99".
func _fills_say(fills: Array) -> String:
	var said: Array[String] = []
	var seen := {}
	for fill: String in fills:
		if FILL_TABLES.has(fill):
			var nth := int(seen.get(fill, 0))
			seen[fill] = nth + 1
			said.append(String(FILL_SAYS[fill][mini(nth, 1)]))
		else:
			said.append(fill)
	if said.size() < 2:
		return "".join(said)
	return ", ".join(said.slice(0, said.size() - 1)) + " and " + said[said.size() - 1]


## **What goes in a message's placeholders for the widest line it can make**: one string
## for each of [param fills], in order. A table word gives the widest entry of its table at
## [param size], in [param texts] (the catalog's translations by English message, English
## where it has none), and a table that fills two placeholders gives its two widest; any
## other word is the text itself.
func _fill_values(fills: Array, size: int, texts: Dictionary) -> Array:
	var taken := {}
	var out: Array = []
	for fill: String in fills:
		if not FILL_TABLES.has(fill):
			out.append(fill)
			continue
		var ranked := _ranked_words(String(FILL_TABLES[fill]), size, texts)
		var nth := int(taken.get(fill, 0))
		taken[fill] = nth + 1
		out.append("" if ranked.is_empty() else String(ranked[mini(nth, ranked.size() - 1)]))
	return out


## The entries of the table [param table], widest first at [param size].
func _ranked_words(table: String, size: int, texts: Dictionary) -> Array:
	var words: Array = []
	for id: String in _const_ids.get(table, []):
		words.append(String(texts.get(id, id)))
	words.sort_custom(func(a: String, b: String) -> bool: return _width_of(a, size) > _width_of(b, size))
	return words


## [param text] with its placeholders replaced by [param values]: plain ones in order,
## numbered ones (`%2$s`) by their number, `{}` in order; `%%` is a `%`.
func _filled(text: String, values: Array) -> String:
	if values.is_empty():
		return text
	var out := ""
	var at := 0
	var bare := 0
	var braced := 0
	for m in _holes_re().search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var token := m.get_string()
		if token == "%%":
			out += "%"
		elif token == "%":
			out += token
		elif token.begins_with("{"):
			out += String(values[mini(braced, values.size() - 1)])
			braced += 1
		else:
			var index := bare
			if m.get_string(1).is_empty():
				bare += 1
			else:
				index = int(m.get_string(1)) - 1
			out += String(values[clampi(index, 0, values.size() - 1)])
	return out + text.substr(at)


## How many placeholders a message has: `%s`, `%d`, `{}` and the like, each argument once.
func _count_holes(text: String) -> int:
	var holes := _holes(text)
	return (holes["slots"] as Dictionary).size() + (holes["braces"] as Array).size()


## **The rooms have to be sayable, and the English has to fit them**: a message with
## placeholders says what goes in them -- as many words after `with` as it has
## placeholders -- and a word after `with` is a table or a text with a digit in it. A room
## the English itself overflows is a mistake in the source, found here and not by a
## translator.
func _check_rooms() -> void:
	for key: String in _order:
		var e: Dictionary = _entries[key]
		if not e.has("room"):
			continue
		var room: Array = e["room"]
		var id := String(e["id"])
		var where := "%s: \"%s\"" % [e["refs"][0], _short(id)]
		var fills: Array = room[2]
		var fine := true
		for fill: String in fills:
			if FILL_TABLES.has(fill):
				if not _const_ids.has(FILL_TABLES[fill]):
					_problems.append("%s: ROOM says `with %s`, but no constant %s is marked with TRANSLATORS:" % [
						where, fill, FILL_TABLES[fill]])
					fine = false
			elif not _has_digit(fill):
				_problems.append(("%s: ROOM says `with %s`, which is not a table (%s) and has no digit"
					+ " in it, so it is not a text") % [where, fill, ", ".join(FILL_TABLES.keys())])
				fine = false
		var holes := _count_holes(id)
		if holes != fills.size():
			_problems.append(("%s: has %d placeholder(s) and its ROOM names what goes in %d: write"
				+ " `ROOM: %d px at %d px with ...`, one word for each") % [where, holes, fills.size(), room[0], room[1]])
			fine = false
		if not fine:
			continue
		var english := _room_width(id, room, {})
		if english > float(room[0]):
			_problems.append("%s: the English takes %d px and its room is %d px" % [
				where, int(ceilf(english)), room[0]])


func _has_digit(text: String) -> bool:
	for i in text.length():
		if text[i] >= "0" and text[i] <= "9":
			return true
	return false


func _flags(text: String) -> PackedStringArray:
	var flags := PackedStringArray()
	var c := RegEx.new()
	c.compile(r"%[-+#0]*(?:\d+|\*)?(?:\.\d+)?[sdfxXoeEgGc]")
	if c.search(text) != null:
		flags.append("c-format")
	var braces := RegEx.new()
	braces.compile(r"\{[A-Za-z_]*\}")
	if braces.search(text) != null:
		flags.append("python-brace-format")
	return flags


func _quote(text: String) -> String:
	return "\"" + text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""


## [param text] as comment lines of at most [constant WRAP] columns, each starting
## with [param prefix], broken between words.
func _wrap(prefix: String, text: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var current := ""
	for word in text.split(" ", false):
		if not current.is_empty() and prefix.length() + current.length() + 1 + word.length() > WRAP:
			lines.append(prefix + current)
			current = word
		else:
			current = word if current.is_empty() else current + " " + word
	if not current.is_empty():
		lines.append(prefix + current)
	return lines


## What differs between the template on disk and the one just made: messages added
## or gone, enough to say what to look at.
func _say_difference(have: String, made: String) -> void:
	var was := _msgids_of(have)
	var now := _msgids_of(made)
	var shown := 0
	for id in now:
		if not was.has(id) and shown < 8:
			print("[i18n]   new: ", id)
			shown += 1
	for id in was:
		if not now.has(id) and shown < 8:
			print("[i18n]   gone: ", id)
			shown += 1
	if shown == 0:
		print("[i18n]   (the messages are the same; a comment, a reference or a flag differs)")


func _msgids_of(pot: String) -> Dictionary:
	var ids := {}
	for line in pot.split("\n"):
		if line.begins_with("msgid \"") and line != "msgid \"\"":
			ids[line] = true
	return ids


# ---------------------------------------------------------------------------
# Checking the translators' files.
# ---------------------------------------------------------------------------

## **Checks every catalog against the template it was made from**, and returns 1
## when one would break the game or mistranslate it.
##
## **What fails**: a file the engine cannot load (the commonest cause is a plural
## message with a different number of `msgstr[]` forms than the header's
## `nplurals`, which drops the whole language); a file name that is not a locale; a
## header whose `Language:` or `Plural-Forms:` is not filled in, or whose plural rule
## the engine reads differently from its words; a placeholder lost, added or
## reordered, which the game's `%` would turn into a script error; a `%` that is not
## a placeholder; a plural message half translated; a control character in a
## translation (a raw 0x13 where a dash was meant is invisible in an editor and a
## box on screen); text wider than the room a message has (`ROOM:`, game catalogs
## only), measured with the widest word that can stand in a placeholder; a gene's
## numbers line, the pause caption or a world's line wider than its room, built with the
## game's own code in the language being checked (SCREENS); a message defined twice, or
## differently in two catalogs of one language; a catalog none of whose messages is in
## its template (a launcher catalog in the game's folder, or the other way round); a
## `.po` in any other folder, which the game never reads; a game catalog that does not
## name its own language -- its translation of "English" missing, empty, fuzzy or still
## "English" -- which the game's language list shows it under ([method _lint_own_name]).
##
## **What is only reported** (and fails under `--strict`): a message left
## untranslated or marked fuzzy, which the game shows in English; a message the
## template has and the catalog has not (the catalog is older than its template);
## one the catalog has and the template has not (newer, or reworded since). The
## template moves ahead of every catalog whenever a sentence is reworded or the
## launcher is synced, and the game then shows that sentence in English, which
## works. Failing CI for it would hold every such change up on a translation --
## the launcher-sync pull request included, which nobody is there to fix -- so a
## partial translation lands, and `--strict` is for the pull request that claims a
## complete one.
func _lint_all() -> int:
	var checked := 0
	var failed := 0
	var by_locale := {}
	for set: Dictionary in CATALOGS:
		var files := _po_files(set["dir"])
		if files.is_empty():
			continue
		if not FileAccess.file_exists(set["pot"]):
			print("[i18n] PROBLEM %s is missing, so the %d catalog(s) in %s cannot be checked" % [
				String(set["pot"]).trim_prefix("res://"), files.size(),
				String(set["dir"]).trim_prefix("res://")])
			failed += 1
			continue
		var template := _parse_po(set["pot"])
		for file in files:
			var result := _lint_catalog(String(set["dir"]).path_join(file), template, set)
			checked += 1
			if int(result["problems"]) > 0:
				failed += 1
			if not by_locale.has(result["locale"]):
				by_locale[result["locale"]] = []
			by_locale[result["locale"]].append(result)
	for locale: String in by_locale:
		var group: Array = by_locale[locale]
		for i in group.size():
			for j in range(i + 1, group.size()):
				failed += _lint_conflicts(group[i], group[j])
	failed += _english_problems
	var strays: Array[String] = []
	_stray_po("res://", strays)
	for stray in strays:
		print(("[i18n] PROBLEM %s is a language file where the game never looks: it reads game/i18n/"
			+ " and game/i18n/launcher/ only (and addons/ and ci/ are replaced by every launcher sync)")
			% stray.trim_prefix("res://"))
		failed += 1
	if failed > 0:
		print("[i18n] FAILED: %d of %d catalog(s) have problems (above)" % [failed, checked])
		return 1
	if checked == 0:
		print("[i18n] ALL PASS: no .po in %s or %s; nothing to check" % [PO_DIR, LAUNCHER_PO_DIR])
	else:
		print("[i18n] ALL PASS: %d catalog(s) checked" % checked)
	return 0


## The `.po` files in [param dir], by name; none when there is no such folder.
func _po_files(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "po":
			found.append(file)
	found.sort()
	return found


## Every `.po` under [param dir] that is not in a catalog folder.
func _stray_po(dir: String, found: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_stray_po(dir.path_join(sub), found)
	if dir.trim_suffix("/") in [PO_DIR, LAUNCHER_PO_DIR]:
		return
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "po":
			found.append(dir.path_join(file))


## Checks one catalog; returns what it found: `{path, locale, problems, hard, texts}`.
## `hard` counts the problems that make the catalog unsafe to run the game's code on
## (a placeholder the game's `%` would choke on, a plural rule the engine misreads, a
## file it will not load): the lines the game composes are measured only without them.
func _lint_catalog(path: String, template: Dictionary, set: Dictionary) -> Dictionary:
	var shown := path.trim_prefix("res://")
	var stem := path.get_file().get_basename()
	var locale := _locale_of(stem)
	var result := {"path": path, "shown": shown, "locale": locale, "problems": 0, "hard": 0, "texts": {}}
	if locale.is_empty():
		_problem(result, shown, ("the file name is not a locale: a language code in lower case, then"
			+ " an optional script and country -- fr.po, pt_BR.po, zh_Hans.po"))
		return result
	if locale != stem.replace("-", "_"):
		print("[i18n] %s: the engine spells this locale \"%s\", and the game registers it so" % [shown, locale])
	var catalog := _parse_po(path)
	for error: String in catalog["errors"]:
		_problem(result, shown, error)

	# The header: a language the engine can name, and a plural rule it reads as written.
	var header: String = catalog["header"]
	var said := _header_line(header, "Language")
	if TranslationServer.standardize_locale(said) != locale:
		_problem(result, shown, "the header says \"Language: %s\"; it has to say \"Language: %s\"" % [said, locale])
	var plural_forms := _header_line(header, "Plural-Forms")
	var found := _plural_re().search(plural_forms)
	var forms_n := 0
	if found == null or int(found.get_string(1)) < 1 or plural_forms.contains("INTEGER") \
			or plural_forms.contains("EXPRESSION"):
		_problem(result, shown, "the header's Plural-Forms: is not filled in, for example \"nplurals=2; plural=(n != 1);\"")
	else:
		forms_n = int(found.get_string(1))
		var why := _probe_plural(plural_forms, forms_n)
		if not why.is_empty():
			_problem(result, shown, "the header's \"Plural-Forms: %s\" %s" % [plural_forms, why])

	# The messages, against the template's.
	var wanted := {}
	for t: Dictionary in template["entries"]:
		if t["id"] != "":
			wanted[String(t["ctx"]) + "\u0004" + String(t["id"])] = t
	# The catalog's own words by English message, for the placeholders a room's `with` names.
	var texts := {}
	for e: Dictionary in catalog["entries"]:
		var spoken: Array = e["forms"]
		if e["ctx"] == "" and e["id"] != "" and not bool(e["fuzzy"]) and not spoken.is_empty() \
				and not String(spoken[0]).is_empty():
			texts[e["id"]] = String(spoken[0])
	var seen := {}
	var translated := 0
	var untranslated := 0
	var fuzzy := 0
	var stale: Array[String] = []
	var entries := 0
	for e: Dictionary in catalog["entries"]:
		if e["id"] == "":
			continue
		entries += 1
		var key := String(e["ctx"]) + "\u0004" + String(e["id"])
		var where := "%s:%d" % [shown, e["line"]]
		if seen.has(key):
			_problem(result, where, "\"%s\" is defined twice (first on line %d)" % [_short(e["id"]), seen[key]])
			continue
		seen[key] = e["line"]
		if not wanted.has(key):
			stale.append(e["id"])
			continue
		var state := _lint_message(result, where, e, wanted[key], forms_n, set["rooms"], key, texts)
		match state:
			"translated":
				translated += 1
			"fuzzy":
				fuzzy += 1
				untranslated += 1
			"empty":
				untranslated += 1
	var missing: Array[String] = []
	for key: String in wanted:
		if not seen.has(key):
			missing.append(wanted[key]["id"])
	var wrong_folder := entries > 0 and stale.size() == entries
	if wrong_folder:
		_problem(result, shown, "none of its %d messages is in %s: is it a catalog for the %s?" % [
			entries, String(set["pot"]).trim_prefix("res://"),
			"launcher" if set["name"] == "game" else "game"])
	# The engine has the last word: a file it will not load is a language that is missing.
	var loaded: Translation = null
	if int(result["hard"]) == 0:
		loaded = _load_engine(path)
		if loaded == null:
			_problem(result, shown, ("the engine cannot load it, so the game would drop the language"
				+ " (a plural message with a different number of msgstr[] forms than nplurals is the"
				+ " commonest cause)"))
	# The lines the game builds from several messages, in this language.
	var screens := ""
	if loaded != null and bool(set["rooms"]) and int(result["hard"]) == 0:
		screens = _lint_screens(result, shown, locale, loaded)
	# The name the game's language list shows this language under.
	if set["name"] == "game":
		_lint_own_name(result, shown, locale, catalog)

	# What it says about itself.
	var line := "%s: %d of %d messages translated" % [shown, translated, wanted.size()]
	var untouched := untranslated + missing.size()
	if untouched > 0:
		line += ", %d not translated" % untouched
	if fuzzy > 0:
		line += " (%d marked fuzzy, which the engine ignores)" % fuzzy
	if not stale.is_empty():
		line += ", %d stale" % stale.size()
	var tail := ""
	if untouched + stale.size() > 0:
		tail = " -- fails under --strict" if _strict else " -- reported, not failed"
	print("[i18n] ", line, tail)
	if not screens.is_empty():
		print("[i18n]   ", screens)
	if not wrong_folder:
		_list("  in the template, not in the catalog", missing)
		_list("  in the catalog, not in the template", stale)
	if _strict:
		if untouched > 0:
			_problem(result, shown, "--strict: %d message(s) not translated" % untouched)
		if not stale.is_empty():
			_problem(result, shown, "--strict: %d stale message(s)" % stale.size())
	return result


## **A game catalog names its own language, in that language.** The game's
## language list (docs/design/settings.md §3.1) shows every game catalog under its
## translation of i18n.gd's OWN_NAME, the msgid "English" -- which is not the word
## for English, but "Français", "Deutsch": the name a player who reads only that
## language looks for. So it fails, unlike any other untranslated message, when it
## is missing, empty or fuzzy -- the list would show the engine's English name
## instead ("French") -- and when it says "English", which reads the same as the
## English row. Only about how the list looks, so the game's own code still runs on
## the catalog.
func _lint_own_name(result: Dictionary, shown: String, locale: String, catalog: Dictionary) -> void:
	var script := _script("i18n")
	var own := String(_script_const(script, "OWN_NAME")) if script != null \
		and _script_const(script, "OWN_NAME") != null else "English"
	var said := ""
	var fuzzy := false
	var where := shown
	for e: Dictionary in catalog["entries"]:
		if e["ctx"] != "" or e["id"] != own:
			continue
		where = "%s:%d" % [shown, e["line"]]
		var forms: Array = e["forms"]
		fuzzy = bool(e["fuzzy"])
		if not forms.is_empty():
			said = String(forms[0]).strip_edges()
		break
	if said.is_empty() or fuzzy:
		var why := "is not translated" if said.is_empty() else "is marked fuzzy, which the engine ignores"
		_problem(result, where, ("\"%s\" %s. It is not the word for English: it is the name of this"
			+ " catalog's own language, in that language (\"Français\", \"Deutsch\"), and the game's"
			+ " language list shows the language under it. Without it the list says \"%s\", the engine's"
			+ " English name, which a player who reads only this language may not find")
			% [own, why, TranslationServer.get_locale_name(locale)], true)
	elif said.to_lower() == own.to_lower():
		_problem(result, where, ("\"%s\" -> \"%s\": it is not the word for English but the name of this"
			+ " catalog's own language, in that language (\"Français\", \"Deutsch\"). The game's language"
			+ " list shows the language under it, and \"%s\" reads the same as the English row")
			% [own, said, said], true)


## One message of a catalog against its template's. Returns what it is:
## "translated", "fuzzy", "empty", or "" for one the checks refused.
func _lint_message(result: Dictionary, where: String, e: Dictionary, want: Dictionary,
		forms_n: int, rooms: bool, key: String, texts: Dictionary) -> String:
	var id := String(e["id"])
	var forms: Array = e["forms"]
	var plural := String(want["plural"]) != ""
	if plural != bool(e["has_plural"]):
		_problem(result, where, "\"%s\" %s a plural message in the template" % [
			_short(id), "is" if plural else "is not"])
		return ""
	if plural and forms_n > 0 and forms.size() != forms_n:
		_problem(result, where, ("\"%s\" has %d msgstr[] form(s) and the header says nplurals=%d:"
			+ " every plural message needs exactly %d, empty ones included") % [
				_short(id), forms.size(), forms_n, forms_n])
		return ""
	var filled := 0
	for form: String in forms:
		if not form.is_empty():
			filled += 1
	if filled == 0 or bool(e["fuzzy"]):
		return "fuzzy" if bool(e["fuzzy"]) and filled > 0 else "empty"
	if filled < forms.size():
		_problem(result, where, "\"%s\" is translated in %d of its %d forms" % [
			_short(id), filled, forms.size()])
		return ""
	var holes := _holes(id)
	var room: Array = _entries[key]["room"] if rooms and _entries.has(key) and _entries[key].has("room") else []
	var clean := true
	for form: String in forms:
		var why := _holes_problem(holes, _holes(form))
		if not why.is_empty():
			_problem(result, where, "\"%s\" -> \"%s\" %s" % [_short(id), _short(form), why])
			clean = false
			continue
		var odd := _odd_character(form)
		if not odd.is_empty():
			_problem(result, where, ("\"%s\" -> \"%s\" has a control character, %s, which no screen can draw:"
				+ " a dash, a quote or a space that was mistyped; delete it and type the character meant") % [
					_short(id), _short(form), odd], true)
			clean = false
		var padding := _padding_problem(id, form)
		if not padding.is_empty():
			_problem(result, where, "\"%s\" -> \"%s\" %s" % [_short(id), _short(form), padding], true)
			clean = false
		if not room.is_empty():
			var wide := _room_width(form, room, texts)
			if wide > float(room[0]):
				var fills: Array = room[2]
				var measured := ""
				if not fills.is_empty():
					measured = " (measured as \"%s\")" % _short(_filled(form, _fill_values(fills, room[1], texts)))
				_problem(result, where, "\"%s\" -> \"%s\" is %d px wide in %d px type; the room is %d px%s" % [
					_short(id), _short(form), int(ceilf(wide)), room[1], room[0], measured], true)
				clean = false
	if not clean:
		return ""
	result["texts"][key] = "\u0005".join(forms)
	return "translated"


## The same message translated differently in two catalogs of one language: the
## engine takes whichever it loaded last, so it is a coin the game tosses.
func _lint_conflicts(a: Dictionary, b: Dictionary) -> int:
	var clash := 0
	for key: String in a["texts"]:
		if b["texts"].has(key) and a["texts"][key] != b["texts"][key]:
			print("[i18n] PROBLEM %s and %s translate \"%s\" differently: the engine takes either" % [
				a["shown"], b["shown"], _short(key.get_slice("\u0004", 1))])
			clash += 1
	return 1 if clash > 0 else 0


## The scripts a check needs, by SCREEN_SCRIPTS key, loaded the first time one is wanted.
var _scripts := {}
## The composed lines in English, measured once, and how many of them overflow their room.
var _english := {}
var _english_problems := 0


## One of the SCREEN_SCRIPTS, or null when it does not load.
func _script(key: String) -> GDScript:
	if not _scripts.has(key):
		_scripts[key] = load(String(SCREEN_SCRIPTS[key])) as GDScript
		if key == "i18n":
			# Where a screen exists, loading it registers the real catalogs: none is wanted
			# here, where the catalogs are checked one at a time.
			TranslationServer.clear()
	return _scripts[key]


## A constant of a loaded script.
func _script_const(script: GDScript, name: String) -> Variant:
	return script.get_script_constant_map().get(name)


## The locale a catalog's file name stands for, by the game's own rule (i18n.gd), so that
## this and the game cannot disagree about a name; "" when it is not one.
func _locale_of(file_name: String) -> String:
	var script := _script("i18n")
	if script == null:
		return ""
	return String(script.call(&"locale_of", file_name))


## **The catalog as the engine reads it**: its text is copied to user:// and loaded from
## there, so what is checked is the file as it is now -- not a copy imported earlier -- and
## by the engine's own reader. Null when the engine will not load it.
func _load_engine(path: String) -> Translation:
	var copy := "user://i18n_lint_catalog.po"
	var file := FileAccess.open(copy, FileAccess.WRITE)
	if file == null:
		return load(path) as Translation
	file.store_string(FileAccess.get_file_as_string(path))
	file.close()
	var loaded := ResourceLoader.load(copy, "", ResourceLoader.CACHE_MODE_IGNORE) as Translation
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))
	return loaded


## **Builds the lines the game composes from several messages** -- a gene's numbers, the
## pause caption, a world's line -- in the language of [param translation], with the game's
## own code, and measures each against its room (SCREENS). Returns what it found, for the
## report; "" when the game's scripts would not load, which is a problem of its own.
func _lint_screens(result: Dictionary, shown: String, locale: String, translation: Translation) -> String:
	if _english_screens().is_empty():
		_problem(result, shown, ("the lines the game composes could not be measured: gene_stats.gd, or a"
			+ " script it uses, did not load"))
		return ""
	var before := TranslationServer.get_locale()
	translation.locale = locale
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(locale)
	var now := _measure_screens()
	TranslationServer.set_locale(before)
	TranslationServer.remove_translation(translation)
	if now.is_empty():
		return ""
	var widest := 0.0
	for row: Array in now["numbers"]:
		widest = maxf(widest, float(row[0]))
		if float(row[0]) > NUMBERS_ROOM:
			_problem(result, shown, ("%s is %d px wide in %d px type; the room is %d px, and a longer line"
				+ " runs into the Leave button: \"%s\"") % [
					row[2], ceili(float(row[0])), NUMBERS_SIZE, NUMBERS_ROOM, _short(String(row[1]))], true)
	var lead: Array = now["lead"]
	var rest: Array = now["rest"]
	var caption := float(lead[0]) + float(rest[0])
	if float(lead[0]) > CAPTION_ROOM:
		_problem(result, shown, ("the pause caption is %d px wide in %d px type, with no numbers on it; the room is"
			+ " %d px, and a wider label makes the whole pause screen wider: \"%s\"") % [
				ceili(float(lead[0])), CAPTION_SIZE, CAPTION_ROOM, _short(String(lead[1]))], true)
	elif caption > CAPTION_ROOM:
		_problem(result, shown, ("the pause caption with the numbers on is %d px wide in %d px type; the room is"
			+ " %d px, and a wider label makes the whole pause screen wider: \"%s\"") % [
				ceili(caption), CAPTION_SIZE, CAPTION_ROOM, _short(String(lead[1]) + String(rest[1]))], true)
	var line: Array = now["line"]
	if float(line[0]) > STATS_ROOM:
		_problem(result, shown, ("a world's line in \"your worlds\" is %d px wide in %d px type; the room is"
			+ " %d px, and a longer line ends in \"…\": \"%s\"") % [ceili(float(line[0])), STATS_SIZE,
				STATS_ROOM, _short(String(line[1]))], true)
	var row: Array = now["row"]
	if float(row[0]) < ROW_ROOM:
		_problem(result, shown, ("an instinct's row on the programs page leaves %d px of arc on %s"
			+ " with its widest tests and action; it needs at least %d px, or the row reads as chips"
			+ " with nothing joining them") % [floori(float(row[0])), row[1], ROW_ROOM], true)
	var trigger: Array = now["trigger"]
	if float(trigger[0]) > TRIGGER_LINE_ROOM:
		_problem(result, shown, ("a line of the programs inspector's triggers is %d px wide in 14 px"
			+ " type; the room is %d px: \"%s\"") % [ceili(float(trigger[0])), TRIGGER_LINE_ROOM,
			_short(String(trigger[1]))], true)
	var rows: Array = now["numbers"]
	var tightest := String((rows[0] as Array)[2]) if not rows.is_empty() else "none"
	return ("built with the game's own code: numbers lines at most %d px of %d (%s), the pause caption"
		+ " at most %d px of %d, a world's line at most %d px of %d, an instinct's row %d px of arc"
		+ " (%s, at least %d), the inspector's trigger lines at most %d px of %d") % [ceili(widest),
		NUMBERS_ROOM, tightest, ceili(caption), CAPTION_ROOM, ceili(float(line[0])), STATS_ROOM,
		floori(float(row[0])), row[1], ROW_ROOM, ceili(float(trigger[0])), TRIGGER_LINE_ROOM]


## The composed lines in English, measured once, with the line that says so; a line that
## overflows its room in English is a mistake in the game and fails the lint, whoever
## translates it. Empty when the game's scripts will not load.
func _english_screens() -> Dictionary:
	if not _english.is_empty():
		return _english
	TranslationServer.clear()
	var now := _measure_screens()
	if now.is_empty():
		return now
	_english = now
	var widest := 0.0
	for row: Array in now["numbers"]:
		widest = maxf(widest, float(row[0]))
		if float(row[0]) > NUMBERS_ROOM:
			print("[i18n] PROBLEM English: %s is %d px wide in %d px type; the room is %d px: \"%s\"" % [
				row[2], ceili(float(row[0])), NUMBERS_SIZE, NUMBERS_ROOM, row[1]])
			_english_problems += 1
	var lead: Array = now["lead"]
	var rest: Array = now["rest"]
	var caption := float(lead[0]) + float(rest[0])
	if caption > CAPTION_ROOM:
		print(("[i18n] PROBLEM English: the pause caption with the numbers on is %d px wide in %d px"
			+ " type; the room is %d px: \"%s\"") % [
				ceili(caption), CAPTION_SIZE, CAPTION_ROOM, String(lead[1]) + String(rest[1])])
		_english_problems += 1
	var line: Array = now["line"]
	if float(line[0]) > STATS_ROOM:
		print("[i18n] PROBLEM English: a world's line is %d px wide in %d px type; the room is %d px: \"%s\"" % [
			ceili(float(line[0])), STATS_SIZE, STATS_ROOM, String(line[1])])
		_english_problems += 1
	var row: Array = now["row"]
	if float(row[0]) < ROW_ROOM:
		print("[i18n] PROBLEM English: an instinct's row leaves %d px of arc on %s; it needs %d" % [
			floori(float(row[0])), row[1], ROW_ROOM])
		_english_problems += 1
	var trigger: Array = now["trigger"]
	if float(trigger[0]) > TRIGGER_LINE_ROOM:
		print("[i18n] PROBLEM English: a trigger line is %d px wide; the room is %d px: \"%s\"" % [
			ceili(float(trigger[0])), TRIGGER_LINE_ROOM, String(trigger[1])])
		_english_problems += 1
	print(("[i18n] the lines the game composes, in English: numbers lines at most %d px of %d,"
		+ " the pause caption at most %d px of %d, a world's line at most %d px of %d, an instinct's"
		+ " row %d px of arc (%s, at least %d), the inspector's trigger lines at most %d px of %d") % [
		ceili(widest), NUMBERS_ROOM, ceili(caption), CAPTION_ROOM, ceili(float(line[0])), STATS_ROOM,
		floori(float(row[0])), row[1], ROW_ROOM, ceili(float(trigger[0])), TRIGGER_LINE_ROOM])
	return _english


## **Builds every line the game composes**, in the language the TranslationServer is set to,
## and returns the widest of each kind: `numbers`, one `[width, text, label]` per gene and
## line, widest first; `lead`, the widest `genome · <generation>`; `rest`, the widest
## numbers clause after it; `line`, the widest world's line ([method _widest_drop_line]).
## They are made by the game's own functions (gene_stats.gd, drops.gd) for
## every gene at every copy count, every level and way of a levelled gene, and every body
## that changes a number -- so a new gene, or a new tier, is covered without being named.
## Empty when a script, or a constant it needs, is missing.
func _measure_screens() -> Dictionary:
	var stats := _script("stats")
	var readout := _script("readout")
	var genome := _script("genome")
	var cell := _script("cell")
	if stats == null or readout == null or genome == null or cell == null:
		return {}
	var genes: Array = _script_const(genome, "GENE_ORDER") if _script_const(genome, "GENE_ORDER") != null else []
	var levelled: Dictionary = _script_const(cell, "LEVELLED") if _script_const(cell, "LEVELLED") != null else {}
	var tier_max := int(_script_const(genome, "TIER_MAX"))
	var divide := float(_script_const(cell, "DIVIDE_RADIUS"))
	var sep := String(_script_const(readout, "SEP"))
	if genes.is_empty() or tier_max < 1 or not _const_ids.has("GENERATIONS"):
		return {}
	var font := ThemeDB.fallback_font
	var words: Dictionary = _const_pairs.get("WORDS", {})
	var ways: Array[StringName] = [&""]
	for way: String in (_const_pairs.get("PATH_TITLES", {}) as Dictionary):
		ways.append(StringName(way))
	# The bodies that change a number: how much `crista` leaves of every cost, how big
	# `vacuole` makes the tank, what `plastid` makes. A levelled gene has many more rows, and
	# they depend on those less, so it is read in three bodies only.
	var all_bodies: Array[Dictionary] = []
	for crista in tier_max + 1:
		for vacuole in tier_max + 1:
			for plastid in tier_max + 1:
				all_bodies.append({&"crista": crista, &"vacuole": vacuole, &"plastid": plastid})
	var few_bodies: Array[Dictionary] = [{}, {&"vacuole": tier_max},
		{&"crista": tier_max, &"vacuole": tier_max, &"plastid": tier_max}]
	var worst := {}
	for gene: StringName in genes:
		var grows := levelled.has(gene)
		var bodies := few_bodies if grows else all_bodies
		var levels: Array = range(1, 100) if grows else [0]
		var paths: Array = ways if grows else [&""]
		for copies in range(1, tier_max + 1):
			for body: Dictionary in bodies:
				var ctx: Dictionary = stats.call(&"context", body)
				for level: int in levels:
					for way: StringName in paths:
						var rows: Array = stats.call(&"lines", gene, copies, level, way, ctx)
						for i in mini(rows.size(), 2):
							var items: Array = rows[i]
							if grows and i == 1:
								# A worn gene that levels ends its costs with the next level.
								items = items.duplicate()
								items.append(stats.call(&"progress_item", level, 999.0))
							var wide := float(readout.call(&"width", font, NUMBERS_SIZE,
								readout.call(&"runs", items)))
							var tag := "%s/%d" % [gene, i]
							if worst.has(tag) and wide <= float((worst[tag] as Array)[0]):
								continue
							var about := "%d cop%s" % [copies, "y" if copies == 1 else "ies"]
							if grows:
								about = "level %d, %s" % [level, ("way " + String(way)) if way != &"" else "no way chosen"]
							worst[tag] = [wide, String(readout.call(&"plain", items)),
								"the %s numbers line of %s (%s), at %s" % [
									"first" if i == 0 else "second", words.get(String(gene), String(gene)), gene, about]]
	var numbers: Array = worst.values()
	numbers.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	# The caption: the widest generation, and the widest clause the numbers add to it.
	var lead_format := String(TranslationServer.translate("genome · %s"))
	var generations: Array[String] = []
	for id: String in _const_ids["GENERATIONS"]:
		generations.append(String(TranslationServer.translate(id)))
	# Past the tenth the caption counts; 99 is already a long run.
	generations.append(_filled(String(TranslationServer.translate("generation %d")), ["99"]))
	var lead: Array = [0.0, ""]
	for generation: String in generations:
		var text := _filled(lead_format, [generation])
		var wide := _width_of(text, CAPTION_SIZE)
		if wide > float(lead[0]):
			lead = [wide, text]
	var rest: Array = [0.0, ""]
	for crista in tier_max + 1:
		for vacuole in tier_max + 1:
			for plastid in tier_max + 1:
				for flagellum in tier_max + 1:
					var body := {&"crista": crista, &"vacuole": vacuole, &"plastid": plastid,
						&"flagellum": flagellum}
					for radius: float in [divide, 6.0]:
						for upkeep: float in [0.0, 0.1, 0.5, 1.0, 2.0]:
							var text := sep + String(readout.call(&"plain",
								stats.call(&"cell_items", radius, body, upkeep)))
							var wide := _width_of(text, CAPTION_SIZE)
							if wide > float(rest[0]):
								rest = [wide, text]
	var line := _widest_drop_line()
	if line.is_empty():
		return {}
	var page := _script("programs")
	if page == null:
		return {}
	var row: Array = page.call(&"row_room", ThemeDB.fallback_font)
	var trigger: Array = page.call(&"trigger_line_room", ThemeDB.fallback_font)
	return {"numbers": numbers, "lead": lead, "rest": rest, "line": line, "row": row,
		"trigger": trigger}


## **The widest line a world's row can say** (STATS_ROOM), `[width, text]`, built with the
## game's own `Drops.line`: every generation phrase -- none, the ten, and the counted one at
## 99 -- with the widest age it says, found over every count of minutes, hours and days
## (to 999) the game uses. Empty when drops.gd will not load.
func _widest_drop_line() -> Array:
	var drops := _script("drops")
	if drops == null:
		return []
	var ages: Array[float] = []
	for minutes in range(1, 60):
		ages.append(minutes * 60.0 + 30.0)
	for hours in range(1, 48):
		ages.append(hours * 3600.0 + 60.0)
	for days in range(2, 1000):
		ages.append(days * 86400.0 + 60.0)
	var widest_age := 0.0
	var lived := ages[0]
	for seconds: float in ages:
		var wide := _width_of(String(drops.call(&"age_text", seconds)), STATS_SIZE)
		if wide > widest_age:
			widest_age = wide
			lived = seconds
	var generations: Array = range(0, 11)
	generations.append(99)
	var widest: Array = [0.0, ""]
	for generation: int in generations:
		var text := String(drops.call(&"line", generation, lived))
		var wide := _width_of(text, STATS_SIZE)
		if wide > float(widest[0]):
			widest = [wide, text]
	return widest


## [param soft] says the problem is only about how the text looks (too wide, a stray
## control character): the game's code can still be run on a catalog that has it.
func _problem(result: Dictionary, where: String, text: String, soft: bool = false) -> void:
	print("[i18n] PROBLEM %s: %s" % [where, text])
	result["problems"] = int(result["problems"]) + 1
	if not soft:
		result["hard"] = int(result["hard"]) + 1


## At most [constant LIST_AT_MOST] messages under a heading, one to a line.
func _list(heading: String, messages: Array[String]) -> void:
	if messages.is_empty():
		return
	print("[i18n] %s (%d):" % [heading, messages.size()])
	for i in mini(messages.size(), LIST_AT_MOST):
		print("[i18n]     \"%s\"" % _short(messages[i]))
	if messages.size() > LIST_AT_MOST:
		print("[i18n]     ... and %d more" % (messages.size() - LIST_AT_MOST))


## [param text] cut to a line's worth, for a report, with any control character spelled out.
func _short(text: String) -> String:
	var one := _visible(text).replace("\n", " ")
	return one if one.length() <= 90 else one.substr(0, 87) + "..."


## Why the spaces and line breaks at the ends of [param form] will not do for
## [param english]'s, in words; "" when they match. The English pads a line it is
## joined to (`"     <- installed"`), or does not, and a translation that trims the one
## or adds the other -- a trailing space is invisible in an editor -- breaks the join.
func _padding_problem(english: String, form: String) -> String:
	var lead_en := english.substr(0, english.length() - english.lstrip(" \n").length())
	var lead_tr := form.substr(0, form.length() - form.lstrip(" \n").length())
	if lead_en != lead_tr:
		return "starts with %s; the English starts with %s: keep the English's spacing" % [
			_describe_padding(lead_tr), _describe_padding(lead_en)]
	var trail_en := english.substr(english.rstrip(" \n").length())
	var trail_tr := form.substr(form.rstrip(" \n").length())
	if trail_en != trail_tr:
		return "ends with %s; the English ends with %s: keep the English's spacing" % [
			_describe_padding(trail_tr), _describe_padding(trail_en)]
	return ""


func _describe_padding(padding: String) -> String:
	if padding.is_empty():
		return "no space"
	var breaks := padding.count("\n")
	var spaces := padding.length() - breaks
	var parts: Array[String] = []
	if spaces > 0:
		parts.append("%d space%s" % [spaces, "" if spaces == 1 else "s"])
	if breaks > 0:
		parts.append("%d line break%s" % [breaks, "" if breaks == 1 else "s"])
	return " and ".join(parts)


## Whether the character code [param c] is something no screen can draw: a control
## character other than a line feed, DEL, a C1 control, or the replacement character that
## bad decoding leaves behind.
func _is_odd(c: int) -> bool:
	return (c < 32 and c != 10) or c == 127 or (c >= 128 and c < 160) or c == 0xFFFD


## The first character of [param text] that [method _is_odd] refuses, as "U+0013 at
## character 15"; "" when there is none.
func _odd_character(text: String) -> String:
	for i in text.length():
		var c := text.unicode_at(i)
		if _is_odd(c):
			return "U+%04X at character %d" % [c, i + 1]
	return ""


## [param text] with every character [method _is_odd] refuses written out as `<U+0013>`,
## so a report never prints one.
func _visible(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		out += "<U+%04X>" % c if _is_odd(c) else text[i]
	return out


## The value of a header line such as `Plural-Forms: nplurals=2; plural=(n != 1);`.
func _header_line(header: String, key: String) -> String:
	for line in header.split("\n"):
		if String(line).begins_with(key + ":"):
			return String(line).trim_prefix(key + ":").strip_edges()
	return ""


var _plural_regex: RegEx = null
var _holes_regex: RegEx = null


func _holes_re() -> RegEx:
	if _holes_regex == null:
		_holes_regex = RegEx.new()
		_holes_regex.compile(r"%%|%(?:(\d+)\$)?([-+0]*\d*(?:\.\d+)?[sdoxXcfv])|%|\{[A-Za-z_]*\}")
	return _holes_regex


func _plural_re() -> RegEx:
	if _plural_regex == null:
		_plural_regex = RegEx.new()
		_plural_regex.compile(r"nplurals\s*=\s*(\d+)\s*;\s*plural\s*=\s*(.+?)\s*;?\s*$")
	return _plural_regex


## **Which form the engine picks for each count under a plural rule**, asked of the
## engine itself: the header is written into a one-message catalog of its own, read
## back, and 26 counts that tell every rule in use apart are put to it. Returns what
## is wrong with the rule in words, or "" when every count gets a form that exists
## and every form is some count's. A rule the engine cannot read answers form 0 to
## everything, and a rule that names a form beyond `nplurals` gets an empty string:
## neither is visible in the file.
func _probe_plural(plural_forms: String, forms_n: int) -> String:
	var probe := "user://i18n_lint_probe.po"
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return ""
	var forms := ""
	for i in forms_n:
		forms += "msgstr[%d] \"F%d\"\n" % [i, i]
	file.store_string("msgid \"\"\nmsgstr \"\"\n\"Language: en\\n\"\n"
		+ "\"Content-Type: text/plain; charset=UTF-8\\n\"\n"
		+ "\"Plural-Forms: " + plural_forms + "\\n\"\n\n"
		+ "msgid \"t\"\nmsgid_plural \"ts\"\n" + forms)
	file.close()
	var probed := ResourceLoader.load(probe, "", ResourceLoader.CACHE_MODE_IGNORE) as Translation
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
	if probed == null:
		return "cannot be read by the engine"
	var reached := {}
	for count: int in PROBE_COUNTS:
		var form := String(probed.get_plural_message("t", "ts", count))
		if form.is_empty():
			return "gives a count of %d a form that does not exist (nplurals is %d)" % [count, forms_n]
		reached[form] = true
	for i in forms_n:
		if not reached.has("F%d" % i):
			return "never selects form %d: the rule and nplurals disagree, or the rule cannot be read" % i
	return ""


## **The placeholders of a message**: `slots` maps the argument each takes (1, 2, ...
## for plain `%s`, N for `%N$s`) to what it asks for (`s`, `d`, `.1f`); `braces` are
## the `{}` and `{name}`; `mixed` says plain and numbered were both used; `stray`
## counts a `%` that is neither a placeholder nor `%%`. What Godot's `%` accepts, as
## measured: s d o x X c f v, with `-`, `+`, `0`, a width and a precision, and an
## index; `%e`, `%g`, `%i`, `%u` and a `%` before a space are script errors.
func _holes(text: String) -> Dictionary:
	var slots := {}
	var braces: Array[String] = []
	var bare := 0
	var numbered := 0
	var stray := 0
	var doubled := 0
	for m in _holes_re().search_all(text):
		var token := m.get_string()
		if token == "%%":
			doubled += 1
		elif token == "%":
			stray += 1
		elif token.begins_with("{"):
			braces.append(token)
		elif not m.get_string(1).is_empty():
			numbered += 1
			slots[int(m.get_string(1))] = m.get_string(2)
		else:
			bare += 1
			slots[bare] = m.get_string(2)
	braces.sort()
	return {"slots": slots, "braces": braces, "mixed": bare > 0 and numbered > 0,
		"stray": stray, "doubled": doubled}


## Why a translation's placeholders will not do for the message's own, in words;
## "" when they will. Numbered ones may reorder (`%2$s %1$s`), plain ones may not.
func _holes_problem(want: Dictionary, got: Dictionary) -> String:
	if got["mixed"]:
		return "mixes numbered placeholders (%1$s) with plain ones (%s): use one kind"
	if want["slots"] != got["slots"]:
		return "has the placeholders [%s]; the English has [%s]" % [_show_holes(got), _show_holes(want)]
	if want["braces"] != got["braces"]:
		return "has the braces [%s]; the English has [%s]" % [
			" ".join(got["braces"]), " ".join(want["braces"])]
	var formatted: bool = not (want["slots"] as Dictionary).is_empty()
	if formatted and int(got["stray"]) > 0:
		return "has a % that is not a placeholder: write %% for a percent sign"
	if not formatted and int(got["doubled"]) > int(want["doubled"]):
		return "has %% in a message the game does not format, so it would show two percent signs: write one %"
	return ""


func _show_holes(holes: Dictionary) -> String:
	var slots: Dictionary = holes["slots"]
	var keys := slots.keys()
	keys.sort()
	var shown: Array[String] = []
	for index: int in keys:
		shown.append("%" + String(slots[index]))
	return " ".join(shown) if not shown.is_empty() else "none"


## **A .po or .pot read into its entries**: `{header, entries, errors}`, an entry
## being `{ctx, id, plural, has_plural, forms, fuzzy, line}`. Comments are skipped,
## except the `fuzzy` flag, which the engine honours by ignoring the entry, and
## obsolete `#~` entries, which it ignores too. Enough for the checks above, not a
## general reader: it takes the file a translator is told to write.
func _parse_po(path: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	var errors: Array[String] = []
	var header := ""
	var current := {}
	var into := ""
	var pending_fuzzy := false
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := String(lines[i]).strip_edges()
		if line.begins_with("#,"):
			pending_fuzzy = pending_fuzzy or line.contains("fuzzy")
			continue
		if line.is_empty() or line.begins_with("#"):
			continue
		var at := i + 1
		if line.begins_with("msgctxt "):
			_close_entry(entries, current)
			current = _new_entry(at, pending_fuzzy)
			pending_fuzzy = false
			current["ctx"] = _unquote(line.trim_prefix("msgctxt "))
			into = "ctx"
		elif line.begins_with("msgid_plural "):
			current["plural"] = _unquote(line.trim_prefix("msgid_plural "))
			current["has_plural"] = true
			into = "plural"
		elif line.begins_with("msgid "):
			if current.is_empty() or current["id"] != null:
				_close_entry(entries, current)
				var ctx: String = current["ctx"] if not current.is_empty() and current["id"] == null else ""
				current = _new_entry(at, pending_fuzzy)
				current["ctx"] = ctx
				pending_fuzzy = false
			current["id"] = _unquote(line.trim_prefix("msgid "))
			current["line"] = at
			into = "id"
		elif line.begins_with("msgstr["):
			var close := line.find("]")
			if current.is_empty() or close < 0:
				errors.append("%s:%d: a msgstr[] with no msgid" % [path.trim_prefix("res://"), at])
				continue
			if int(line.substr(7, close - 7)) != current["forms"].size():
				errors.append("%s:%d: msgstr[%s] is out of order" % [
					path.trim_prefix("res://"), at, line.substr(7, close - 7)])
			current["forms"].append(_unquote(line.substr(close + 1)))
			into = "form"
		elif line.begins_with("msgstr "):
			if current.is_empty():
				errors.append("%s:%d: a msgstr with no msgid" % [path.trim_prefix("res://"), at])
				continue
			current["forms"] = [_unquote(line.trim_prefix("msgstr "))]
			into = "form"
		elif line.begins_with("\""):
			if current.is_empty():
				continue
			var more := _unquote(line)
			match into:
				"ctx": current["ctx"] += more
				"id": current["id"] += more
				"plural": current["plural"] += more
				"form":
					if not current["forms"].is_empty():
						current["forms"][current["forms"].size() - 1] += more
		else:
			errors.append("%s:%d: cannot read this line: %s" % [path.trim_prefix("res://"), at, _short(line)])
	_close_entry(entries, current)
	var kept: Array[Dictionary] = []
	for e in entries:
		if e["id"] == "" and e["ctx"] == "" and header.is_empty() and not e["forms"].is_empty():
			header = e["forms"][0]
		else:
			kept.append(e)
	return {"header": header, "entries": kept, "errors": errors}


func _new_entry(line: int, fuzzy: bool) -> Dictionary:
	return {"ctx": "", "id": null, "plural": "", "has_plural": false, "forms": [],
		"fuzzy": fuzzy, "line": line}


func _close_entry(entries: Array[Dictionary], current: Dictionary) -> void:
	if current.is_empty() or current["id"] == null:
		return
	entries.append(current)


func _unquote(text: String) -> String:
	var body := text.strip_edges()
	if body.length() >= 2 and body.begins_with("\"") and body.ends_with("\""):
		body = body.substr(1, body.length() - 2)
	return _unescape(body)
