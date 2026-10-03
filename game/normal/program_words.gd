extends RefCounted
## **The words of your instincts** (docs/design/automation.md §13.1;
## automation-ux.md §8): what a sense, a value, a test and an action are called
## on the programs page, in the replay and wherever an instinct is said.
##
## **A part's words are its declaring file's**: `cell.gd`, `metabolism.gd` and
## `genome.gd` keep a table beside their DECLARES, so a new gene brings its
## words, not a screen (behaviour.md §3.5). **The rulebook's own words live here**,
## with the page: `always`, the bearing every directed sense carries, the four
## tests in each kind's words, `my mouth` and `me`, and the units. A part with no
## words yet is said by its declared name rather than not at all.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Rulebook := preload("res://game/mechanics/rulebook.gd")
const CellBody := preload("res://game/normal/cell.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")

## TRANSLATORS: The name of the one sense every cell has on the chip of an
## "instinct" (a rule the player writes): it always reports, so an instinct on it
## always acts unless one above it holds it back. Lowercase.
## ROOM: 112 px at 15 px
const RULEBOOK_SAYS := {
	&"always": "always",
}
## TRANSLATORS: The name of a value a sense reports, which an "instinct" can test,
## on a small choice cell: "bearing", how far off the cell's nose the thing is.
## Lowercase, one short word.
## ROOM: 70 px at 14 px
const RULEBOOK_VALUES := {
	&"bearing": "bearing",
}
## TRANSLATORS: Explains one sense or value of the player's "instincts", on one
## line under them: its name (the same word as on its chip), a middle dot, then
## what it is, lowercase. "Nothing above acts": no instinct higher in the list
## acts on the same thing.
## ROOM: 856 px at 15 px
const RULEBOOK_EXPLAINS := {
	&"always": "always · always there: for what your cell does when nothing above acts.",
	&"bearing": "bearing · how far off your nose it is, to either side.",
}

## **The four tests, in each kind's own words** (§3.1's below, above, rising and
## falling) -- the two put against a step, with the step in %s, and the two of
## change -- in the order `rulebook.gd`'s Test is numbered.
##
## TRANSLATORS: A test an "instinct" puts to a value, on a chip, in the kind's own
## words; %s is the step: "below 30%", "under 5 s", "within 350 µm", "within
## 60°". Lowercase. Move %s where your language wants it.
## ROOM: 140 px at 14 px with 1450 µm
const TESTS := {
	&"level": ["below %s", "above %s"],
	&"seconds": ["under %s", "over %s"],
	&"distance": ["within %s", "beyond %s"],
	&"bearing": ["within %s", "beyond %s"],
}
## TRANSLATORS: A test of change an "instinct" puts to a value, on a chip, in the
## kind's own words: since the last moment (a quarter of a second before) it rose
## or fell, went away or came closer, moved off the cell's nose or back toward it.
## Lowercase.
## ROOM: 140 px at 14 px
const TEST_CHANGES := {
	&"level": ["rising", "falling"],
	&"seconds": ["rising", "falling"],
	&"distance": ["going away", "closing in"],
	&"bearing": ["moving aside", "moving ahead"],
}
## TRANSLATORS: A test an "instinct" puts to the size of something it senses, on
## a chip; %s is "my mouth" or "me", what it is measured against: "smaller than my
## mouth" (small enough to swallow whole). Lowercase.
## ROOM: 184 px at 14 px with ref
const SIZE_TESTS := ["smaller than %s", "bigger than %s"]
## TRANSLATORS: A test of change an "instinct" puts to the size of something it
## senses, on a chip: since the last moment it grew or shrank. Lowercase.
## ROOM: 184 px at 14 px
const SIZE_CHANGES := ["growing", "shrinking"]
## **The comparisons alone**, for the inspector's four cells: a translator may move
## the %s of a test above, so these are messages of their own.
##
## TRANSLATORS: One of four choices for the test an "instinct" puts to a value, on
## a cell 128 px wide: the comparison alone, without its step. Lowercase.
## ROOM: 104 px at 14 px
const COMPARES := {
	&"level": ["below", "above", "rising", "falling"],
	&"seconds": ["under", "over", "rising", "falling"],
	&"distance": ["within", "beyond", "going away", "closing in"],
	&"bearing": ["within", "beyond", "moving aside", "moving ahead"],
	&"size": ["smaller than", "bigger than", "growing", "shrinking"],
}
## TRANSLATORS: What the size of something an "instinct" senses is measured
## against: "my mouth" (the cell's own mouth: smaller than it is small enough to
## swallow whole) or "me" (the cell's whole body). Lowercase.
## ROOM: 96 px at 14 px
const REFERENCE_SAYS := {
	&"mouth": "my mouth",
	&"body": "me",
}
## **A step in its unit**, by kind.
##
## TRANSLATORS: A value with its unit: a share as a percentage ("30%"), seconds
## ("5 s"), micrometres ("350 µm"), degrees ("60°"). %d and %s are the number.
## Keep the unit; space it as your language does ("30 %" in French).
## ROOM: 60 px at 14 px with 99
const UNITS := {
	&"level": "%d%%",
	&"seconds": "%s s",
	&"distance": "%s µm",
	&"bearing": "%s°",
}
## TRANSLATORS: How hard a "push" instinct pushes: at "half" its strength or
## "full". Lowercase, one short word.
## ROOM: 60 px at 14 px
const OPTION_SAYS := ["half", "full"]
## TRANSLATORS: A program's name inside a sentence, in your language's quotation
## marks: “flee” (French « fuite »). %s is the name the player gave it.
## ROOM: 230 px at 14 px with program 99
const QUOTED := "“%s”"


## **What [param part] is called**: a sense, an action or a value, in the
## language of the moment -- its declaring file's word, or its declared name.
static func says(part: StringName) -> String:
	var words := _words(part)
	return str(words.get("says", String(part)))


## **The line that explains [param part]**: its word, a middle dot and what it is
## or does -- or "" where there is none.
static func explains(part: StringName) -> String:
	return str(_words(part).get("explains", ""))


## What a part waiting for its organ's level says, "" for none.
static func asleep(part: StringName) -> String:
	return str(_words(part).get("asleep", ""))


## What the page says when a part waiting for a level is picked, "" for none.
static func needs(part: StringName) -> String:
	return str(_words(part).get("needs", ""))


static func _words(part: StringName) -> Dictionary:
	if RULEBOOK_SAYS.has(part) or RULEBOOK_VALUES.has(part):
		var out := {}
		out["says"] = String(TranslationServer.translate(RULEBOOK_SAYS[part]
			if RULEBOOK_SAYS.has(part) else RULEBOOK_VALUES[part]))
		if RULEBOOK_EXPLAINS.has(part):
			out["explains"] = String(TranslationServer.translate(RULEBOOK_EXPLAINS[part]))
		return out
	# Each word from the first file that has it: a value two files report takes
	# its chip from the first and its sentence from whichever file has one --
	# metabolism names hunger's `level`, and the genome explains a level.
	var out := {}
	for table: Dictionary in [CellBody.words_of(part), Metabolism.words_of(part),
			GenomeNode.words_of(part)]:
		for key: String in table:
			if not out.has(key):
				out[key] = table[key]
	return out


## **A test's step in its unit**: `30%`, `5 s`, `350 µm`, `60°`, or what a size is
## measured against.
static func step_text(kind: StringName, step: float, ref: StringName) -> String:
	if kind == Rulebook.SIZE:
		return String(TranslationServer.translate(REFERENCE_SAYS.get(ref, String(ref))))
	match kind:
		&"level":
			return String(TranslationServer.translate(UNITS[&"level"])) % int(roundf(step * 100.0))
		&"seconds", &"distance", &"bearing":
			return String(TranslationServer.translate(UNITS[kind])) % Rulebook.number(step)
	return Rulebook.number(step)


## **A test as its chip says it**: `below 30%`, `within 350 µm`, `rising`.
static func test_text(clause: Rulebook.Clause) -> String:
	var test := int(clause.test)
	if clause.kind == Rulebook.SIZE:
		if test >= 2:
			return String(TranslationServer.translate(SIZE_CHANGES[test - 2]))
		return size_text(test, clause.ref)
	var kind := clause.kind if TESTS.has(clause.kind) else &"level"
	if test >= 2:
		return String(TranslationServer.translate(TEST_CHANGES[kind][test - 2]))
	return String(TranslationServer.translate(TESTS[kind][test])) \
		% step_text(clause.kind, clause.step, clause.ref)


## **A size against [param ref]**: `smaller than my mouth` for [param test] 0,
## `bigger than me` for 1.
static func size_text(test: int, ref: StringName) -> String:
	return String(TranslationServer.translate(SIZE_TESTS[clampi(test, 0, 1)])) \
		% step_text(Rulebook.SIZE, 0.0, ref)


## **A comparison alone**, for the inspector's cells.
static func compare_text(kind: StringName, test: int) -> String:
	var known := kind if COMPARES.has(kind) else &"level"
	return String(TranslationServer.translate(COMPARES[known][clampi(test, 0, 3)]))


## **An action as its chip says it**: its word, and a push's strength after a
## middle dot -- `push · half`.
static func action_text(rule: Rulebook.Rule) -> String:
	var said := says(rule.output)
	if not is_nan(rule.option):
		said += " · " + option_text(rule.option)
	return said


## A push's strength: half, or full.
static func option_text(option: float) -> String:
	return String(TranslationServer.translate(OPTION_SAYS[0 if option < 0.75 else 1]))


## **One instinct in words**, as a row reads (automation-ux.md §7.3): its sense,
## each test after a comma, an arrow and what it does -- `echo, bigger than my
## mouth → turn away`. A rule this build cannot read is its line.
static func rule_text(rule: Rulebook.Rule) -> String:
	if rule.inert:
		return rule.text
	var said := says(rule.input)
	for clause: Rulebook.Clause in rule.clauses:
		said += ", " + test_text(clause)
	return said + " → " + action_text(rule)


## **A program's name inside a sentence**, in the language's quotation marks.
static func quoted(name: String) -> String:
	return String(TranslationServer.translate(QUOTED)) % name
