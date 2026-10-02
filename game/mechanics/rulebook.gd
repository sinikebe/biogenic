extends RefCounted
## **Rules a body carries** (docs/design/behaviour.md §2, §3, §4.1, §10): an
## ordered list of `when <input> [is ...] -> <output>`, read from the top on a
## body's tick with one winner for each trigger. Each rule reads one declared
## input, puts up to one test to each value it carries, and names one declared
## output. The water's cells are the first to carry them, and a player's run is
## meant to read the same lists through the same functions (§11).
##
## **What it knows**: declared inputs -- whether one carries a bearing, and the
## values it carries, each of a kind -- and declared outputs -- the triggers each
## claims, what it needs and the options it takes; the kinds and their ladders;
## the four tests. **Choosing** ([method choose]): from the top, one winner per
## trigger, each input read at most once a tick through a callable the caller
## hands over. **Text** ([method parse], [method text_of]): a list to and from
## its lines by declared name, a name it does not know kept as a rule that never
## fires and written back as it came.
##
## **What it does not know**: a gene, a cell, a sense or the water. Every name it
## reads comes out of the declaration tables it is handed ([method vocabulary]),
## and what an input reports or an output does is the caller's (food.gd's
## wiring). One mutation, §6.2's change, is pack 3's next phase.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **The kinds of value an input can carry, and the ladder each steps along**
## (§3.1), in the units the rule's text writes them in. A level is 0 to 1, a
## seconds count and a distance grow by about the same proportion at each step,
## and a bearing is degrees off the nose to either side.
const LADDERS := {
	&"level": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
	&"seconds": [1.0, 2.0, 3.0, 5.0, 8.0, 13.0, 21.0, 34.0],
	&"distance": [50.0, 80.0, 130.0, 220.0, 350.0, 560.0, 900.0, 1450.0],
	&"bearing": [15.0, 30.0, 45.0, 60.0, 90.0, 120.0, 150.0],
}
## **A size is measured against what the body knows of itself** (§3.1): one of
## these, whose values the caller hands over on every [method choose].
const SIZE := &"size"
const REFERENCES: Array[StringName] = [&"mouth", &"body"]
## The kind of the bearing an input carries, where it carries one: one of its
## values, named [constant BEARING] in a rule's text.
const BEARING := &"bearing"

## **The input that always reports**, once and with nothing in it -- the
## rulebook's own, so a list can say *always -> swim*.
const ALWAYS := &"always"
## **The claim that claims every trigger there is** (§4.1): a rest's, so a rest
## above everything else stops everything, a trigger a later gene brings
## included.
const EVERY := &"all"
## Between a rule's input and its output, in its text.
const ARROW := "->"

## The four tests (§3.1): below or above a step on the value's ladder or a
## reference, and rising or falling since the last tick.
enum Test { BELOW, ABOVE, RISING, FALLING }
const TEST_WORDS: Array[String] = ["below", "above", "rising", "falling"]


## **Everything a body's rules can name**, by qualified name `owner.name`: every
## declared input and output of every table the vocabulary was made from.
class Vocabulary:
	## Qualified name to [InputDecl], and to [OutputDecl].
	var inputs := {}
	var outputs := {}
	## Each trigger a declared output claims, to its bit; and every bit, which is
	## what [constant EVERY] claims.
	var claims := {}
	var every := 0
	## Each owner a table declares, to its bit: what [method worn] sets for a
	## body that has that owner, and what a rule needs of it. An int holds 63 of
	## them; the game declares nine.
	var owners := {}


## One declared input. Its reports are Arrays of its values in [member values]'
## order -- its bearing first, where it carries one, in radians off the nose --
## and may carry more after them, which no test reads.
class InputDecl:
	var name := &""
	var owner := &""
	var bearing := false
	var values: Array[StringName] = []
	var kinds: Array[StringName] = []

	## Where [param value] sits in a report, or -1.
	func at(value: StringName) -> int:
		return values.find(value)

	## **The value a test may leave unnamed**: an input's only value besides its
	## bearing, or &"" when it carries more than one.
	func lone() -> StringName:
		var found := &""
		for k in values.size():
			if values[k] == BEARING and bearing:
				continue
			if found != &"":
				return &""
			found = values[k]
		return found


## One declared output: the triggers it claims, as bits, what it needs of the
## input that drives it, and the options it takes, if any.
class OutputDecl:
	var name := &""
	var owner := &""
	var claims := 0
	var needs := &""
	var options: Array[float] = []


## One test of one rule: which value, where it sits in a report, of which kind,
## which test, and the step or reference it is put against. [member named] is
## whether the rule's text names the value, so a list comes back out as it went
## in.
class Clause:
	var value := &""
	var at := -1
	var kind := &""
	var test := Test.BELOW
	var step := 0.0
	var ref := &""
	var named := true
	## Whether the value is a bearing, measured in degrees off the nose to
	## either side ([method measure]).
	var degrees := false


## **One rule.** A rule this build cannot read -- a name it does not know, or a
## shape that is not a rule -- is [member inert]: it never fires and its
## [member text] is written back as it came.
class Rule:
	var text := ""
	var inert := false
	var input := &""
	var in_owner := &""
	var clauses: Array[Clause] = []
	var output := &""
	var out_owner := &""
	var claims := 0
	## The owners it needs there, as the vocabulary's bits: its output's, and
	## its input's unless that is [constant ALWAYS].
	var needs := 0
	## The output's option, NAN for one that takes none.
	var option := NAN


## **A behaviour** (§2.1): an ordered list of rules. Shared, never written
## through: a body that carries one carries the list itself, and a change makes
## a new one.
class Behaviour:
	var rules: Array[Rule] = []
	## Each rule's input as a slot every rule of the list reading that input
	## shares, -1 for [constant ALWAYS] and an inert rule; and how many slots
	## there are. What lets [method choose] read an input once a tick without
	## asking a dictionary. Made on the list's first choice ([method index]).
	var slots := PackedInt32Array()
	var inputs := 0

	func size() -> int:
		return rules.size()

	## Numbers the inputs its rules read, in order of first reading.
	func index() -> void:
		var seen := {}
		slots.resize(rules.size())
		for k in rules.size():
			var rule := rules[k]
			if rule.inert or rule.input == ALWAYS:
				slots[k] = -1
				continue
			if not seen.has(rule.input):
				seen[rule.input] = seen.size()
			slots[k] = int(seen[rule.input])
		inputs = seen.size()


## Per [method choose]: the reports read this tick and the reading of the tick
## before, by the list's slots. One choice at a time; nothing is kept between.
static var _now: Array = []
static var _before: Array = []
## What [constant ALWAYS] reports.
static var _always: Array = [[]]


# --- The vocabulary (§3.1, §3.5) ----------------------------------------------

## **A vocabulary from declaration tables** (§3.1): each table maps an owner's
## name -- a gene, or a part every body has -- to `{"in": [...], "out": [...]}`,
## each input `{"name", "bearing", "values": {value: kind}}` and each output
## `{"name", "claims", "needs"?, "options"?}`. A later table's owner of the same
## name adds to the earlier's. Triggers are numbered as they are first claimed.
static func vocabulary(tables: Array) -> Vocabulary:
	var vocab := Vocabulary.new()
	var claiming: Array = []
	for table: Dictionary in tables:
		for owner: Variant in table:
			var parts: Dictionary = table[owner]
			if not vocab.owners.has(StringName(owner)):
				vocab.owners[StringName(owner)] = 1 << vocab.owners.size()
			for one: Dictionary in parts.get("in", []):
				var input := InputDecl.new()
				input.owner = StringName(owner)
				input.name = StringName("%s.%s" % [owner, one["name"]])
				input.bearing = bool(one.get("bearing", false))
				if input.bearing:
					input.values.append(BEARING)
					input.kinds.append(BEARING)
				var values: Dictionary = one.get("values", {})
				for value: Variant in values:
					input.values.append(StringName(value))
					input.kinds.append(StringName(values[value]))
				vocab.inputs[input.name] = input
			for one: Dictionary in parts.get("out", []):
				var output := OutputDecl.new()
				output.owner = StringName(owner)
				output.name = StringName("%s.%s" % [owner, one["name"]])
				output.needs = StringName(one.get("needs", &""))
				for option: Variant in one.get("options", []):
					output.options.append(float(option))
				vocab.outputs[output.name] = output
				claiming.append([output, one.get("claims", [])])
	for pair: Array in claiming:
		for claim: Variant in pair[1]:
			var named := StringName(claim)
			if named != EVERY and not vocab.claims.has(named):
				vocab.claims[named] = 1 << vocab.claims.size()
	for claim: StringName in vocab.claims:
		vocab.every |= int(vocab.claims[claim])
	for pair: Array in claiming:
		var output: OutputDecl = pair[0]
		for claim: Variant in pair[1]:
			output.claims |= vocab.every if StringName(claim) == EVERY \
				else int(vocab.claims[StringName(claim)])
	return vocab


## **The owners a body has, as bits** for [method choose]: each of [param vocab]'s
## that [param parts] holds above zero -- what the body wears, a gene to its
## tier -- or that [param always] holds, what every body has.
static func worn(vocab: Vocabulary, parts: Dictionary, always: Dictionary) -> int:
	var mask := 0
	for owner: StringName in vocab.owners:
		if always.has(owner) or int(parts.get(owner, 0)) > 0:
			mask |= int(vocab.owners[owner])
	return mask


# --- Text (§5.1, §8) -----------------------------------------------------------

## **A list from its text**, a rule a line, blank lines passed over. A line
## this vocabulary cannot read becomes an inert rule that keeps it.
static func parse(text: String, vocab: Vocabulary) -> Behaviour:
	var list := Behaviour.new()
	for line: String in text.split("\n", false):
		if line.strip_edges().is_empty():
			continue
		list.rules.append(rule_from(line, vocab))
	return list


## **A list from its lines**, one rule each, as a file keeps it.
static func from_lines(lines: PackedStringArray, vocab: Vocabulary) -> Behaviour:
	var list := Behaviour.new()
	for line: String in lines:
		list.rules.append(rule_from(line, vocab))
	return list


## **One rule from its line**: `<input> [<value>] <test> [<step>] ... -> <output>
## [<option>]`. Anything that is not a rule of this vocabulary -- a name it
## does not know, two tests on one value, a test with nothing to put it against,
## a turn on an input with no bearing -- comes back inert, keeping the line.
static func rule_from(line: String, vocab: Vocabulary) -> Rule:
	var rule := Rule.new()
	rule.text = line.strip_edges()
	var words := rule.text.split(" ", false)
	var arrow := words.find(ARROW)
	if arrow < 1 or arrow != words.rfind(ARROW) or arrow >= words.size() - 1:
		rule.inert = true
		return rule
	var input: InputDecl = null
	rule.input = StringName(words[0])
	if rule.input != ALWAYS:
		input = vocab.inputs.get(rule.input) as InputDecl
		if input == null:
			rule.inert = true
			return rule
		rule.in_owner = input.owner
	var k := 1
	while k < arrow:
		if input == null:
			rule.inert = true
			return rule
		var clause := Clause.new()
		var word := String(words[k])
		if input.at(StringName(word)) >= 0:
			clause.value = StringName(word)
			k += 1
		else:
			clause.value = input.lone()
			clause.named = false
		clause.at = input.at(clause.value)
		if clause.at < 0 or k >= arrow:
			rule.inert = true
			return rule
		clause.kind = input.kinds[clause.at]
		clause.degrees = clause.kind == BEARING
		var test := TEST_WORDS.find(String(words[k]))
		if test < 0:
			rule.inert = true
			return rule
		clause.test = test as Test
		k += 1
		if clause.test == Test.BELOW or clause.test == Test.ABOVE:
			if k >= arrow:
				rule.inert = true
				return rule
			var against := String(words[k])
			if clause.kind == SIZE:
				if not REFERENCES.has(StringName(against)):
					rule.inert = true
					return rule
				clause.ref = StringName(against)
			elif against.is_valid_float() and is_finite(against.to_float()):
				clause.step = against.to_float()
			else:
				rule.inert = true
				return rule
			k += 1
		for other: Clause in rule.clauses:
			if other.value == clause.value:
				rule.inert = true
				return rule
		rule.clauses.append(clause)
	var output := vocab.outputs.get(StringName(words[arrow + 1])) as OutputDecl
	if output == null:
		rule.inert = true
		return rule
	rule.output = output.name
	rule.out_owner = output.owner
	rule.claims = output.claims
	rule.needs = int(vocab.owners[output.owner])
	if input != null:
		rule.needs |= int(vocab.owners[input.owner])
	var rest := words.size() - arrow - 2
	if output.options.is_empty():
		if rest != 0:
			rule.inert = true
			return rule
	else:
		if rest != 1 or not String(words[arrow + 2]).is_valid_float() \
				or not output.options.has(String(words[arrow + 2]).to_float()):
			rule.inert = true
			return rule
		rule.option = String(words[arrow + 2]).to_float()
	if output.needs == BEARING and (input == null or not input.bearing):
		rule.inert = true
	return rule


## **A list's text**, a rule a line.
static func text_of(list: Behaviour) -> String:
	return "\n".join(lines_of(list))


## **A list's lines**, one rule each, as a file keeps it.
static func lines_of(list: Behaviour) -> PackedStringArray:
	var out := PackedStringArray()
	for rule: Rule in list.rules:
		out.append(line_of(rule))
	return out


## **One rule's line**: the line it came as, for one this build cannot read;
## otherwise written from its parts, so the line a rule was read from comes back
## the same.
static func line_of(rule: Rule) -> String:
	if rule.inert:
		return rule.text
	var words := PackedStringArray([String(rule.input)])
	for clause: Clause in rule.clauses:
		if clause.named:
			words.append(String(clause.value))
		words.append(TEST_WORDS[clause.test])
		if clause.test == Test.BELOW or clause.test == Test.ABOVE:
			words.append(String(clause.ref) if clause.kind == SIZE else number(clause.step))
	words.append(ARROW)
	words.append(String(rule.output))
	if not is_nan(rule.option):
		words.append(number(rule.option))
	return " ".join(words)


## A step or an option as a line writes it: `5`, `0.3`, `220`.
static func number(value: float) -> String:
	if value == floorf(value) and absf(value) < 1e15:
		return str(int(value))
	return String.num(value)


# --- Choosing (§4.1) -------------------------------------------------------------

## **Which rules fire this tick** (§4.1), into [param out] as `[rule's index,
## the report it acts on, the input's reports the tick before or null]`, in list
## order. Going down [param list], a rule fires when none of the triggers it
## claims was claimed above it this tick, the owners it needs are there, and a
## report of its input passes every test -- the nearest such report, reports
## coming nearest first. Its triggers are then claimed. An inert rule never
## fires.
##
## **An owner is there** when its bit is set in [param worn] ([method worn]). An
## input whose owner is not there never reports, and is never read.
##
## **Each input is read at most once a tick**, through [param read] (input name
## to its reports), and only when a rule reaches it whose output could still
## fire. [param memory] is the body's own: input name to `[tick, reports]`, the
## last time each was read -- what rising and falling are measured against, and
## only when that was [param tick] - 1. [param refs] is the sizes a size is put
## against, by name.
static func choose(list: Behaviour, read: Callable, worn: int, refs: Dictionary,
		memory: Dictionary, tick: int, out: Array) -> void:
	out.clear()
	var rules := list.rules
	if list.slots.size() != rules.size():
		list.index()
	var slots := list.slots
	if _now.size() < list.inputs:
		_now.resize(list.inputs)
		_before.resize(list.inputs)
	var claimed := 0
	var have := 0
	for k in rules.size():
		var rule := rules[k]
		if rule.inert or (claimed & rule.claims) != 0 or (worn & rule.needs) != rule.needs:
			continue
		var reports: Array = _always
		var before: Variant = null
		var slot := slots[k]
		if slot >= 0:
			if (have & (1 << slot)) != 0:
				reports = _now[slot]
				before = _before[slot]
			else:
				have |= 1 << slot
				reports = read.call(rule.input)
				var was: Variant = memory.get(rule.input)
				if was == null:
					memory[rule.input] = [tick, reports]
				else:
					if int(was[0]) == tick - 1:
						before = was[1]
					was[0] = tick
					was[1] = reports
				_now[slot] = reports
				_before[slot] = before
		if rule.clauses.is_empty():
			if not reports.is_empty():
				claimed |= rule.claims
				out.append([k, reports[0], before])
			continue
		for report: Array in reports:
			if _passes(rule, report, before, refs):
				claimed |= rule.claims
				out.append([k, report, before])
				break


## Whether [param report] passes every one of [param rule]'s tests, against
## [param before] -- the input's reports the tick before, nearest first, or
## null -- and the sizes in [param refs]. Each value as [method measure]
## measures it.
static func _passes(rule: Rule, report: Array, before: Variant, refs: Dictionary) -> bool:
	for clause: Clause in rule.clauses:
		var at := clause.at
		if at >= report.size():
			return false
		var now := float(report[at])
		if clause.degrees:
			now = absf(rad_to_deg(now))
		var test := clause.test
		if test == Test.BELOW or test == Test.ABOVE:
			var against := clause.step if clause.ref == &"" \
				else float(refs.get(clause.ref, NAN))
			if not (now < against if test == Test.BELOW else now > against):
				return false
			continue
		if before == null:
			return false
		var was: Array = before
		if was.is_empty() or at >= (was[0] as Array).size():
			return false
		var then := float(was[0][at])
		if clause.degrees:
			then = absf(rad_to_deg(then))
		if not (now > then if test == Test.RISING else now < then):
			return false
	return true


## **A value as its kind is measured**: a bearing as degrees off the nose to
## either side; every other kind as it is.
static func measure(kind: StringName, value: float) -> float:
	if kind == BEARING:
		return absf(rad_to_deg(value))
	return value
