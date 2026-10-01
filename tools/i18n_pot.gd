extends Node
## **Writes game/i18n/biogenic.pot**, the template every language is made from,
## by reading the game's own source: a string is a message when the code asks for
## its translation, and this finds every such place. Godot's editor can write a
## .pot too, but only from the editor, and it cannot see a string kept in a
## constant -- which is where most of this game's sentences are.
##
##   godot --headless --path . res://tools/i18n_pot.tscn -- --write
##   godot --headless --path . res://tools/i18n_pot.tscn -- --check
##   godot --headless --path . res://tools/i18n_pot.tscn -- --lint-po
##   godot --headless --path . res://tools/i18n_pot.tscn -- --pseudo=/tmp/fr.po
##
## `--write` (the default) rewrites the template. `--check` writes nothing and
## fails (exit 1) when the template on disk is not what the source now says, or
## when the source asks for a translation this cannot read. `--lint-po` reads
## every `<locale>.po` in game/i18n/ against the template -- a placeholder lost,
## a header unfilled, a message gone stale -- so a translator's file is checked
## before the game ever sees it. `--pseudo=<file>` writes the template as a
## language of its own, every message run once through Godot's pseudolocalizer
## (accents, 30 % longer, in brackets), to find what will not fit before a real
## language exists; it is written where it is told and never into game/i18n/. The
## output of the others is deterministic: no date, no line numbers, so the same
## source gives the same bytes and a pull request that changes no sentence does
## not touch the template.
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
##     `game/**/*.tscn`.
## A `# TRANSLATORS:` comment on the lines directly above a statement (or in the
## doc comment of a constant, or above a `func`, for every message in it) is
## written into the template as an extracted comment for the translator, up to the
## first empty comment line. Text that lives in a scene file has no statement to
## hang a comment on, so a comment can name its message instead --
## `# TRANSLATORS "choose a view": ...` -- in any script.
##
## **A message that must fit says how much room it has**, in a comment line of its
## own beside the TRANSLATORS one: `# ROOM: 47 px at 13 px`. The template then says
## "room: at most 47 px in 13 px type; the English takes 44 px", measured in the
## font the game draws with, and `--lint-po` measures every translation against it:
## the one check on a translator's file that no reading can do.
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
## listed for a translator and shown in English -- the commonest way to miss one.
##
## Excluded from export (`tools/*` on every preset), so none of it ships.

const POT_PATH := "res://game/i18n/biogenic.pot"
const PO_DIR := "res://game/i18n"
const ROOT := "res://game"
## Text that is not shown to a player: the dev app's frame readout, and the
## dedicated server, whose log is the owner's and stays in English.
const SKIP_DIRS: Array[String] = ["res://game/dev", "res://game/server"]
## Node properties a scene can hold text in, which a Control translates itself.
const SCENE_TEXT := ["text", "tooltip_text", "placeholder_text", "title"]
const WRAP := 78

enum K { IDENT, STR, NAME, NUM, PUNCT }

## The comment every `Readout.item` template gets, whatever its own notes say.
const READOUT_NOTE := "A phrase of a gene's numbers, in 14 px type; {} is a number the game " \
	+ "writes, so keep every {}, its unit (µm, s, ×, °) and its order. Phrases are joined " \
	+ "with a middle dot into a line of about 650 px; the longest English line takes 540 px."
## What a `ROOM:` line looks like, once its words are read.
const ROOM_MARK := "\u0001ROOM "

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
var _files := 0
var _tokens := {}
## The constants marked with `TRANSLATORS:`, by name. Which file does not matter:
## a name two files share is read as either.
var _marked := {}
## The constants some `tr()` names, so that one that none does can be said.
var _named_in_calls := {}


func _ready() -> void:
	var mode := "--write"
	var target := ""
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text in ["--write", "--check", "--lint-po"]:
			mode = text
		elif text.begins_with("--pseudo="):
			mode = "--pseudo"
			target = text.trim_prefix("--pseudo=")
	var code := _run(mode, target)
	get_tree().quit(code)


func _run(mode: String, target: String = "") -> int:
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
		"--lint-po":
			code = maxi(code, _lint_po())
		"--pseudo":
			if code == 0:
				code = _write_pseudo(target)
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
func _notes_above(toks: Toks, at: int) -> Array[String]:
	var above: Array[String] = []
	var l := at - 1
	while toks.comments.has(l):
		above.push_front(String(toks.comments[l]))
		l -= 1
	var notes: Array[String] = []
	var current := ""
	var open := false
	var room := RegEx.new()
	room.compile(r"^ROOM:\s*(\d+)\s*px\s+at\s+(\d+)\s*px")
	for raw in above:
		var body := raw.lstrip("#").strip_edges()
		var m := room.search(body)
		if m != null:
			if open:
				notes.append(current)
				open = false
			notes.append(ROOM_MARK + m.get_string(1) + " " + m.get_string(2))
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
		var notes := _notes_above(toks, toks.line[i])
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
		_add(whole, "", "", path, notes, auto, "const")


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
		if note.begins_with(ROOM_MARK):
			var at := note.trim_prefix(ROOM_MARK).split(" ")
			# One message in several places keeps the tightest room it is given.
			if not entry.has("room") or int(at[0]) < int(entry["room"][0]):
				entry["room"] = [int(at[0]), int(at[1])]
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
			var room: Array = e["room"]
			var said := "Room: at most %d px in %d px type" % [room[0], room[1]]
			var english := _width(String(e["id"]), room[1])
			if english >= 0.0:
				said += "; the English takes %d px" % int(ceilf(english))
			out.append_array(_wrap("#. ", said + "."))
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


## **The template as a language of its own**, for `--pseudo=<file>`: every message
## through Godot's own pseudolocalizer once, so it is accented, 30 % longer, and
## wrapped in brackets, and anything still in plain English on a screen was missed
## by `tr()`. Written outside game/i18n/ on purpose -- a file there ships. README.md
## says how to look at it. (The engine's `internationalization/pseudolocalization`
## settings do the same to every string, but pad a Label's text a second time.)
func _write_pseudo(path: String) -> int:
	if path.is_empty() or path.begins_with(PO_DIR):
		print("[i18n] --pseudo=<file> wants a path outside %s, which would ship it" % PO_DIR)
		return 1
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
	for key in _order:
		var e: Dictionary = _entries[key]
		out.append("")
		if e["ctx"] != "":
			out.append("msgctxt " + _quote(e["ctx"]))
		out.append("msgid " + _quote(e["id"]))
		if e["plural"] != "":
			out.append("msgid_plural " + _quote(e["plural"]))
			out.append("msgstr[0] " + _quote(String(TranslationServer.pseudolocalize(e["id"]))))
			out.append("msgstr[1] " + _quote(String(TranslationServer.pseudolocalize(e["plural"]))))
		else:
			out.append("msgstr " + _quote(String(TranslationServer.pseudolocalize(e["id"]))))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("[i18n] cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return 1
	file.store_string("\n".join(out) + "\n")
	file.close()
	print("[i18n] wrote %s: %d messages, pseudolocalized" % [path, _order.size()])
	return 0


## How wide [param text] is drawn at [param size], in the font the game draws
## with; -1 for a message with a placeholder, which is not one width.
func _width(text: String, size: int) -> float:
	if text.contains("%") or text.contains("{}"):
		return -1.0
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


func _flags(text: String) -> PackedStringArray:
	var flags := PackedStringArray()
	var c := RegEx.new()
	c.compile(r"%[-+#0]*(?:\d+|\*)?(?:\.\d+)?[sdfxXoeEgGc]")
	if c.search(text) != null:
		flags.append("c-format")
	if text.contains("{}"):
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
# Reading a translator's file.
# ---------------------------------------------------------------------------

## Checks every `.po` in game/i18n/ against the template, and returns 1 for a
## file the game would translate wrongly.
func _lint_po() -> int:
	var bad := 0
	var found := 0
	for file in DirAccess.get_files_at(PO_DIR):
		if file.get_extension() != "po":
			continue
		found += 1
		bad += _lint_one(PO_DIR.path_join(file))
	if found == 0:
		print("[i18n] no .po in %s; nothing to check" % PO_DIR)
	elif bad == 0:
		print("[i18n] ALL PASS: %d translation files" % found)
	return 1 if bad > 0 else 0


## Returns how many problems [param path] has.
func _lint_one(path: String) -> int:
	var name := path.get_file()
	var locale := TranslationServer.standardize_locale(name.get_basename())
	var problems := 0
	if TranslationServer.get_locale_name(locale).is_empty():
		print("[i18n] %s: the file name is not a locale the engine knows" % name)
		return 1
	# What the game does with it: a file the engine will not load is a language that
	# is silently missing, and the commonest cause is a plural message with no valid
	# `Plural-Forms:` in the header.
	if not load(path) is Translation:
		print("[i18n] %s: the engine cannot load it, so the game would drop the language" % name)
		problems += 1
	var catalog := _read_po(path)
	var header: String = catalog.get("", "")
	if not header.contains("Language: " + name.get_basename()):
		print("[i18n] %s: the header's Language: should say %s" % [name, name.get_basename()])
		problems += 1
	if header.contains("INTEGER") or not header.contains("Plural-Forms: nplurals="):
		print("[i18n] %s: the header's Plural-Forms: is not filled in" % name)
		problems += 1
	var template := _read_po(POT_PATH)
	var translated := 0
	var missing := 0
	for key: String in template:
		if key == "":
			continue
		var theirs: String = catalog.get(key, "")
		if theirs.is_empty():
			missing += 1
			continue
		translated += 1
		var want := _placeholders(key.get_slice("\u0004", 1))
		for form: String in theirs.split("\u0005"):
			if _placeholders(form) != want:
				print("[i18n] %s: placeholders differ in \"%s\" -> \"%s\"" % [
					name, key.get_slice("\u0004", 1), form])
				problems += 1
	for key: String in _entries:
		var entry: Dictionary = _entries[key]
		if not entry.has("room"):
			continue
		for form: String in String(catalog.get(key, "")).split("\u0005"):
			var wide := _width(form, entry["room"][1])
			if wide > float(entry["room"][0]):
				print("[i18n] %s: \"%s\" is %d px wide in %d px type; the room is %d px" % [
					name, form, int(ceilf(wide)), entry["room"][1], entry["room"][0]])
				problems += 1
	for key: String in catalog:
		if key != "" and not template.has(key):
			print("[i18n] %s: no such message in the template (stale?): \"%s\"" % [
				name, key.get_slice("\u0004", 1)])
			problems += 1
	print("[i18n] %s: %d of %d messages translated, %d problems" % [
		name, translated, template.size() - 1, problems])
	return problems


## The placeholders of a message, in order: %s, %d and so on, and {}.
func _placeholders(text: String) -> String:
	var re := RegEx.new()
	re.compile(r"%[-+#0]*(?:\d+|\*)?(?:\.\d+)?[sdfxXoeEgGc]|\{\}")
	var found := PackedStringArray()
	for m in re.search_all(text):
		found.append(m.get_string())
	return " ".join(found)


## A .po or .pot as `{context \u0004 msgid: msgstr}`, a plural's forms joined with
## \u0005, and the header under "". Enough for the checks above, not a general
## reader: it takes the file a translator is told to write.
func _read_po(path: String) -> Dictionary:
	var out := {}
	var ctx := ""
	var id := ""
	var forms := PackedStringArray()
	var into := ""
	var have_id := false
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := String(raw).strip_edges()
		if line.begins_with("#"):
			continue
		if line.begins_with("msgctxt "):
			_flush(out, ctx, id, forms, have_id)
			ctx = _unquote(line.trim_prefix("msgctxt "))
			id = ""
			forms = PackedStringArray()
			have_id = false
			into = "ctx"
		elif line.begins_with("msgid_plural "):
			into = "plural"
		elif line.begins_with("msgid "):
			if have_id or into == "str":
				_flush(out, ctx, id, forms, have_id)
				ctx = ""
				forms = PackedStringArray()
			id = _unquote(line.trim_prefix("msgid "))
			have_id = true
			into = "id"
		elif line.begins_with("msgstr["):
			forms.append(_unquote(line.substr(line.find("]") + 2)))
			into = "str"
		elif line.begins_with("msgstr "):
			forms = PackedStringArray([_unquote(line.trim_prefix("msgstr "))])
			into = "str"
		elif line.begins_with("\""):
			var more := _unquote(line)
			match into:
				"id": id += more
				"ctx": ctx += more
				"str":
					if forms.size() > 0:
						forms[forms.size() - 1] += more
	_flush(out, ctx, id, forms, have_id)
	return out


func _flush(out: Dictionary, ctx: String, id: String, forms: PackedStringArray, have: bool) -> void:
	if not have:
		return
	out[ctx + "\u0004" + id if id != "" else ""] = "\u0005".join(forms)


func _unquote(text: String) -> String:
	var body := text.strip_edges()
	if body.length() >= 2 and body.begins_with("\"") and body.ends_with("\""):
		body = body.substr(1, body.length() - 2)
	return body.replace("\\n", "\n").replace("\\\"", "\"").replace("\\\\", "\\")
