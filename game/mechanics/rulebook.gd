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
## claims, what it needs and the options it takes; the level a part waits for,
## where its declaration names one (docs/design/automation.md §4.3); the kinds
## and their ladders; the four tests. **Choosing** ([method choose]): from the
## top, one winner per trigger, each input read at most once a tick through a
## callable the caller hands over. **Text** ([method parse], [method text_of]):
## a list to and from its lines by declared name, a name it does not know kept
## as a rule that never fires and written back as it came. **One change**
## ([method changed], §6.2): a new list one small step from a list, drawn from a
## vocabulary's parts and the global stream; and what two lists say, compared
## ([method same_rule], [method key_of]).
##
## **What it does not know**: a gene, a cell, a sense or the water. Every name it
## reads comes out of the declaration tables it is handed ([method vocabulary]),
## and what an input reports or an output does is the caller's (food.gd's
## wiring). Which parts a change may draw, how the kinds of change are weighed
## and how long a list may grow are the caller's too (drop.gd's).
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

## **How many owner bits one word of a mask holds**: an int's 64, less its sign, so a
## word is never negative. A vocabulary numbers its owners-and-levels one after another
## with no end, and a mask of them -- what a body wears ([method worn]), what the parts
## waiting for a level are -- is as many words as its vocabulary needs
## ([member Vocabulary.words]). One word today: eleven bits.
const WORD := 63

## The four tests (§3.1): below or above a step on the value's ladder or a
## reference, and rising or falling since the last tick.
enum Test { BELOW, ABOVE, RISING, FALLING }
const TEST_WORDS: Array[String] = ["below", "above", "rising", "falling"]

## **What each rule did on a tick** (docs/design/automation.md §8.2 item 4, §13),
## for a caller that asks [method choose] for it: it acted; it was held back,
## because a rule above it had already claimed a trigger it claims and it would
## otherwise have acted; it is asleep, an owner it needs is not there; its input
## was quiet, reporting nothing; its input reported and no report passed its
## tests; or it cannot be read at all.
enum State { ACTED, HELD, ASLEEP, QUIET, FAILED, UNREAD }

## **The kinds of change** (§6.2), each by the name a caller weighs it by
## ([method changed]): one test's step or one output's option one place along
## its ladder; one rule's input, one of its tests or its output replaced; two
## neighbouring rules swapped; a rule copied in directly under itself; a rule
## dropped.
const NUDGE := &"nudge"
const REPLACE := &"replace"
const SWAP := &"swap"
const COPY := &"copy"
const DROP := &"drop"
## What a replace replaces in a rule: its input, with fresh tests; one of its
## tests -- another in its place, one added or one removed; or its output.
const INPUT_PART := &"input"
const TEST_PART := &"test"
const OUTPUT_PART := &"output"


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
	## Each owner a table declares, to **the number of its bit** at the first level:
	## what [method worn] sets for a body that has that owner, and what a rule needs
	## of it. **Numbered, with no ceiling** (gene-catalogue.md §13): bit `n` is in word
	## `n / WORD` of a mask ([method has_bit]), so a vocabulary of any number of owners
	## and levels has a bit for each. The game numbers eleven, one word.
	var owners := {}
	## **The parts an owner brings at a level above the first** (automation.md
	## §4.3): owner to `{level: bit}`, one bit for each owner-and-level a table
	## declares, numbered as [member owners]' are. [method worn] sets it for a body
	## whose owner works at that level or more, so a part declared at level 2 is there
	## from its owner's level 2.
	var levels := {}
	## Every bit [member levels] holds, as a mask: the parts that wait for a level.
	var levelled := PackedInt64Array()
	## **How many bits it numbers, and the words a mask of them takes**, at least one.
	var bits := 0
	var words := 1


## One declared input. Its reports are Arrays of its values in [member values]'
## order -- its bearing first, where it carries one, in radians off the nose --
## and may carry more after them, which no test reads.
class InputDecl:
	var name := &""
	var owner := &""
	var bearing := false
	var values: Array[StringName] = []
	var kinds: Array[StringName] = []
	## The level its owner must work at for it to be there -- 1 unless its
	## declaration says `"level"` -- and the number of the vocabulary's bit for that
	## owner-and-level ([member Vocabulary.owners]): what a rule reading it needs.
	var level := 1
	var bit := 0

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
	## The level its owner must work at, and the number of that owner-and-level's
	## bit, as an input's ([member InputDecl.level]).
	var level := 1
	var bit := 0


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
	## **The owners it needs there**, as the vocabulary's bits: its output's, and its
	## input's unless that is [constant ALWAYS] -- those in a mask's first word here,
	## as one int, so the check [method choose] makes of every rule on every tick is
	## one `&`; and any past it in [member far], word by word from the second. Empty
	## while its vocabulary has one word, which the game's has.
	var needs := 0
	var far := PackedInt64Array()
	## The output's option, NAN for one that takes none.
	var option := NAN


## **A behaviour** (§2.1): an ordered list of rules. Shared, never written
## through: a body that carries one carries the list itself, and a change makes
## a new one ([method changed]), which shares every rule it did not change --
## so a rule is never written through either.
class Behaviour:
	var rules: Array[Rule] = []
	## Each rule's input as a slot every rule of the list reading that input
	## shares, -1 for [constant ALWAYS] and an inert rule; and how many slots
	## there are. What lets [method choose] read an input once a tick without
	## asking a dictionary. Made on the list's first choice ([method index]).
	var slots := PackedInt32Array()
	var inputs := 0
	## **What it says, as one string** ([method key_of]), made on first asking
	## and kept, since the list never changes.
	var key := ""
	var keyed := false

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
## Per [method choose] asked for states: an input read early, for a rule held
## back, and its reading of the tick before -- kept for the rule further down
## that reads it for real, which then reads nothing again.
static var _peek_now: Array = []
static var _peek_before: Array = []
## What [constant ALWAYS] reports.
static var _always: Array = [[]]


# --- The vocabulary (§3.1, §3.5) ----------------------------------------------

## **A vocabulary from declaration tables** (§3.1): each table maps an owner's
## name -- a gene, or a part every body has -- to `{"in": [...], "out": [...]}`,
## each input `{"name", "bearing", "values": {value: kind}, "level"?}` and each
## output `{"name", "claims", "needs"?, "options"?, "level"?}`. A later table's
## owner of the same name adds to the earlier's. Triggers are numbered as they
## are first claimed.
##
## **A part with a `"level"`** (automation.md §4.3) is there only while its
## owner works at that level or more: its owner-and-level has a bit of its own,
## numbered after every bit before it, so a part at a level moves no bit a list
## was read with. An owner's first bit is its first level's, whatever its parts.
## **Bits are numbered, not packed** ([constant WORD]): there is no end to them.
static func vocabulary(tables: Array) -> Vocabulary:
	var vocab := Vocabulary.new()
	var claiming: Array = []
	var bits := 0
	for table: Dictionary in tables:
		for owner: Variant in table:
			var parts: Dictionary = table[owner]
			var named := StringName(owner)
			if not vocab.owners.has(named):
				vocab.owners[named] = bits
				bits += 1
			for one: Dictionary in parts.get("in", []):
				var input := InputDecl.new()
				input.owner = named
				input.name = StringName("%s.%s" % [owner, one["name"]])
				input.bearing = bool(one.get("bearing", false))
				if input.bearing:
					input.values.append(BEARING)
					input.kinds.append(BEARING)
				var values: Dictionary = one.get("values", {})
				for value: Variant in values:
					input.values.append(StringName(value))
					input.kinds.append(StringName(values[value]))
				input.level = maxi(int(one.get("level", 1)), 1)
				bits = _level_bit(vocab, named, input.level, bits)
				input.bit = _bit_of(vocab, named, input.level)
				vocab.inputs[input.name] = input
			for one: Dictionary in parts.get("out", []):
				var output := OutputDecl.new()
				output.owner = named
				output.name = StringName("%s.%s" % [owner, one["name"]])
				output.needs = StringName(one.get("needs", &""))
				for option: Variant in one.get("options", []):
					output.options.append(float(option))
				output.level = maxi(int(one.get("level", 1)), 1)
				bits = _level_bit(vocab, named, output.level, bits)
				output.bit = _bit_of(vocab, named, output.level)
				vocab.outputs[output.name] = output
				claiming.append([output, one.get("claims", [])])
	vocab.bits = bits
	vocab.words = maxi((bits + WORD - 1) / WORD, 1)
	vocab.levelled.resize(vocab.words)
	for owner: StringName in vocab.levels:
		for level: int in vocab.levels[owner]:
			_mark(vocab.levelled, int(vocab.levels[owner][level]))
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


## **The part [param name] names, without its owner**: `smell` of
## `chemocyte.smell` -- what its owner declared it as, which is what a reader or a
## trigger can be wired by whatever the owner is called. [param name] itself for a
## name with no owner, [constant ALWAYS].
static func part_of(name: StringName) -> StringName:
	var text := String(name)
	var dot := text.find(".")
	return StringName(text.substr(dot + 1)) if dot >= 0 else name


## [param owner]'s bit at [param level] in [param vocab], made the next bit --
## [param bits] -- when it is the first part declared there. Returns how many
## bits there are now.
static func _level_bit(vocab: Vocabulary, owner: StringName, level: int, bits: int) -> int:
	if level <= 1:
		return bits
	var at: Dictionary = vocab.levels.get(owner, {})
	if not at.has(level):
		at[level] = bits
		vocab.levels[owner] = at
		bits += 1
	return bits


## The number of the bit a part of [param owner]'s at [param level] needs.
static func _bit_of(vocab: Vocabulary, owner: StringName, level: int) -> int:
	if level <= 1:
		return int(vocab.owners[owner])
	return int((vocab.levels[owner] as Dictionary)[level])


## **The owners a body has, as bits** for [method choose]: each of [param vocab]'s
## that [param parts] holds above zero -- what the body wears, a gene to the
## level it works at -- or that [param always] holds, what every body has, at
## the first level unless [param parts] says more. **And each part at a level**
## (automation.md §4.3), from the level its owner works at: a gene's worn copies
## for a water cell, the level `genome.gd`'s `level_of` answers for the player,
## a DNA's copies for what a change may draw. **A mask of [member Vocabulary.words]
## words**, the first built as one int, as the whole of it always was.
static func worn(vocab: Vocabulary, parts: Dictionary, always: Dictionary) -> PackedInt64Array:
	var near := 0
	var mask := PackedInt64Array()
	mask.resize(vocab.words)
	for owner: StringName in vocab.owners:
		var level := int(parts.get(owner, 0))
		if always.has(owner):
			level = maxi(level, 1)
		if level <= 0:
			continue
		var bit := int(vocab.owners[owner])
		if bit < WORD:
			near |= 1 << bit
		else:
			_mark(mask, bit)
		var at: Dictionary = vocab.levels.get(owner, {})
		for need: int in at:
			if level >= need:
				bit = int(at[need])
				if bit < WORD:
					near |= 1 << bit
				else:
					_mark(mask, bit)
	mask[0] = near
	return mask


## **Whether [param mask] holds bit [param bit]**, by its number: false for -1, no
## bit, and for a bit past the mask's words.
static func has_bit(mask: PackedInt64Array, bit: int) -> bool:
	if bit < 0 or bit / WORD >= mask.size():
		return false
	return (mask[bit / WORD] & (1 << (bit % WORD))) != 0


## **Whether a body whose owners are [param worn] has every owner [param rule]
## needs** -- what [method choose] asks of each rule, asked by a page.
static func awake(rule: Rule, worn: PackedInt64Array) -> bool:
	var near: int = worn[0] if not worn.is_empty() else 0
	return (near & rule.needs) == rule.needs \
		and (rule.far.is_empty() or _covers(worn, rule.far))


## **[param mask] without the bits of [param other]**: a new mask, [param mask]
## left as it was.
static func without(mask: PackedInt64Array, other: PackedInt64Array) -> PackedInt64Array:
	var out := mask.duplicate()
	for w in mini(out.size(), other.size()):
		out[w] &= ~other[w]
	return out


## Bit [param bit] set in [param mask], which has its word.
static func _mark(mask: PackedInt64Array, bit: int) -> void:
	mask[bit / WORD] |= 1 << (bit % WORD)


## **Whether [param worn]'s words past the first hold every bit of [param far]**, a
## rule's needs there ([member Rule.far]).
static func _covers(worn: PackedInt64Array, far: PackedInt64Array) -> bool:
	for w in far.size():
		var need := far[w]
		if need != 0 and (w + 1 >= worn.size() or (worn[w + 1] & need) != need):
			return false
	return true


## [param bit] added to what [param rule] needs: to [member Rule.needs] in the first
## word, to [member Rule.far] past it.
static func _need(rule: Rule, bit: int) -> void:
	if bit < WORD:
		rule.needs |= 1 << bit
		return
	var w := bit / WORD - 1
	if rule.far.size() <= w:
		rule.far.resize(w + 1)
	rule.far[w] |= 1 << (bit % WORD)


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
	_need(rule, output.bit)
	if input != null:
		_need(rule, input.bit)
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
## input whose owner is not there never reports, and is never read. The first word
## of [param worn] is read once, and each rule's needs there tested with one `&`, as
## when the whole mask was one int; a later word only for a vocabulary that has one.
##
## **Each input is read at most once a tick**, through [param read] (input name
## to its reports), and only when a rule reaches it whose output could still
## fire. [param memory] is the body's own: input name to `[tick, reports]`, the
## last time each was read -- what rising and falling are measured against, and
## only when that was [param tick] - 1. [param refs] is the sizes a size is put
## against, by name.
##
## **[param states], when a caller passes an Array, says what every rule did**
## (automation.md §13): see [method _choose_stating]. Left null -- as the water
## leaves it -- this is the choice pack 3 shipped, line for line.
static func choose(list: Behaviour, read: Callable, worn: PackedInt64Array, refs: Dictionary,
		memory: Dictionary, tick: int, out: Array, states: Variant = null) -> void:
	if states != null:
		_choose_stating(list, read, worn, refs, memory, tick, out, states as Array)
		return
	out.clear()
	var rules := list.rules
	if list.slots.size() != rules.size():
		list.index()
	var slots := list.slots
	if _now.size() < list.inputs:
		_now.resize(list.inputs)
		_before.resize(list.inputs)
	var near: int = worn[0] if not worn.is_empty() else 0
	var wide := worn.size() > 1
	var claimed := 0
	var have := 0
	for k in rules.size():
		var rule := rules[k]
		if rule.inert or (claimed & rule.claims) != 0 or (near & rule.needs) != rule.needs:
			continue
		if wide and not _covers(worn, rule.far):
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


## **[method choose], saying as well what every rule did** (automation.md §8.2
## item 4, §13): into [param states] one `[state, by, taken]` a rule, in list
## order -- its [enum State]; for a rule held back, the index of the rule above
## that claimed first a trigger it claims, and the triggers it found claimed, as
## bits; -1 and 0 for every other state.
##
## **It chooses exactly as [method choose] does, and remembers the same.** A rule
## is held back only when it would have acted, so its input is read to know --
## through the same callable, but **as a peek**: not remembered, and not counted
## as the input's read this tick. The rule further down that reads the input for
## real takes the peek's reports, so the callable is still asked once an input a
## tick, and what is remembered is what it would have been. [param read] must
## answer the same within one tick, as a body's senses do.
static func _choose_stating(list: Behaviour, read: Callable, worn: PackedInt64Array,
		refs: Dictionary, memory: Dictionary, tick: int, out: Array, states: Array) -> void:
	out.clear()
	states.clear()
	var rules := list.rules
	if list.slots.size() != rules.size():
		list.index()
	var slots := list.slots
	if _now.size() < list.inputs:
		_now.resize(list.inputs)
		_before.resize(list.inputs)
	if _peek_now.size() < list.inputs:
		_peek_now.resize(list.inputs)
		_peek_before.resize(list.inputs)
	var claimed := 0
	var have := 0
	var peeked := 0
	# Each trigger claimed, as its bit, to the rule that claimed it.
	var claimer := {}
	for k in rules.size():
		var rule := rules[k]
		if rule.inert:
			states.append([State.UNREAD, -1, 0])
			continue
		if not awake(rule, worn):
			states.append([State.ASLEEP, -1, 0])
			continue
		var taken := claimed & rule.claims
		var reports: Array = _always
		var before: Variant = null
		var slot := slots[k]
		if slot >= 0:
			var bit := 1 << slot
			if (have & bit) != 0:
				reports = _now[slot]
				before = _before[slot]
			elif taken != 0:
				if (peeked & bit) == 0:
					peeked |= bit
					_peek_now[slot] = read.call(rule.input)
					var then: Variant = memory.get(rule.input)
					_peek_before[slot] = then[1] if then != null and int(then[0]) == tick - 1 \
						else null
				reports = _peek_now[slot]
				before = _peek_before[slot]
			else:
				have |= bit
				reports = _peek_now[slot] if (peeked & bit) != 0 else read.call(rule.input)
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
		var found: Variant = null
		if rule.clauses.is_empty():
			if not reports.is_empty():
				found = reports[0]
		else:
			for report: Array in reports:
				if _passes(rule, report, before, refs):
					found = report
					break
		if found == null:
			states.append([State.QUIET if reports.is_empty() else State.FAILED, -1, 0])
			continue
		if taken != 0:
			var by := -1
			for bit: int in claimer:
				if (taken & bit) != 0 and (by < 0 or int(claimer[bit]) < by):
					by = int(claimer[bit])
			states.append([State.HELD, by, taken])
			continue
		claimed |= rule.claims
		var rest := rule.claims
		while rest != 0:
			var low := rest & -rest
			if not claimer.has(low):
				claimer[low] = k
			rest &= ~low
		out.append([k, found, before])
		states.append([State.ACTED, -1, 0])


## **Lists read one after another as one** (automation.md §3.3, §13): a new list
## of [param lists]' rules, in their order -- the first list's from the top,
## then the second's -- **shared**, never copied, so each rule is the very rule
## its own list holds and nothing is written through. [method choose] reads it
## as it reads any list: the first rule that fits wins its triggers, so a list
## above wins a contradiction.
static func merged(lists: Array) -> Behaviour:
	var out := Behaviour.new()
	for list: Behaviour in lists:
		out.rules.append_array(list.rules)
	return out


## **Which rules can never act, and why** (automation-ux.md §2.3, §3.2): for
## each rule of [param list], the index of a rule above it that takes a trigger
## it claims on every tick, or -1. Such a rule is **unconditional** -- `always`
## with no test, readable and awake in [param worn] -- and no rule above it that
## could act claims any trigger it claims, so nothing ever holds it back. A rule
## asleep in [param worn], or one that can itself never act, holds nothing.
## Written to be sure rather than complete: a rule this does not name may still
## never act, by some chance of the water's, and the page says so only of the
## ones that are certain.
static func never(list: Behaviour, worn: PackedInt64Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(list.rules.size())
	out.fill(-1)
	# Every trigger a rule above could claim, and those an unconditional one
	# always does, as each bit to that rule.
	var could := 0
	var always := {}
	for k in list.rules.size():
		var rule := list.rules[k]
		if rule.inert or not awake(rule, worn):
			continue
		var by := -1
		for bit: int in always:
			if (rule.claims & bit) != 0 and (by < 0 or int(always[bit]) < by):
				by = int(always[bit])
		if by >= 0:
			out[k] = by
			continue
		if rule.input == ALWAYS and rule.clauses.is_empty() and (could & rule.claims) == 0:
			var rest := rule.claims
			while rest != 0:
				var low := rest & -rest
				if not always.has(low):
					always[low] = k
				rest &= ~low
		could |= rule.claims
	return out


## **A value as its kind is measured**: a bearing as degrees off the nose to
## either side; every other kind as it is.
static func measure(kind: StringName, value: float) -> float:
	if kind == BEARING:
		return absf(rad_to_deg(value))
	return value


# --- One change (§6.2, §6.3) ---------------------------------------------------------

## **One change to [param list]** (§6.2): `[the changed list, its kind]`. The
## kind is drawn by [param weights] -- a kind's name to its weight -- among the
## kinds that can change this list, then what it changes is drawn; every draw
## from the global stream, which the caller's seed seeds. [param most] is the
## most rules a list holds.
##
## **What a change may draw** (§6.3): [param vocab]'s parts whose owner is in
## [param owners] -- [method worn]'s bits -- and the rulebook's own
## [constant ALWAYS]. A rule already in the list may read or drive a part from
## outside them: it is changed where it is, and only what is drawn new is held
## to them.
##
## **Every change is valid and changes something** (§6.2). A nudge moves a
## test's step, or an output's option, to the next rung up or down its ladder,
## and at the end of the ladder goes the other way. A replace draws a part other
## than the one it replaces. A swap is of two neighbouring rules that differ. A
## copy needs room under [param most]; a drop and a swap need two rules. A rule
## keeps at most one test on each value its input carries, and an output that
## needs a bearing keeps an input that carries one. A rule this build cannot
## read is never changed inside, only swapped, copied or dropped whole.
##
## **Nothing is written through**: the change is a new list sharing every rule
## it did not change, and the rule it changed is a new rule. A list nothing can
## change -- one with no rules -- comes back itself, with no kind.
static func changed(list: Behaviour, vocab: Vocabulary, owners: PackedInt64Array,
		weights: Dictionary, most: int) -> Array:
	var rules := list.rules
	var n := rules.size()
	var nudges := _nudges(list, vocab)
	# Whether any rule can be replaced: which ones, only once a replace is drawn.
	var replace := false
	for k in n:
		if _can_replace(rules[k], vocab, owners):
			replace = true
			break
	var swaps := PackedInt32Array()
	for k in n - 1:
		if not same_rule(rules[k], rules[k + 1]):
			swaps.append(k)
	var can := {NUDGE: not nudges.is_empty(), REPLACE: replace,
		SWAP: not swaps.is_empty(), COPY: n >= 1 and n < most, DROP: n >= 2}
	var total := 0.0
	for named: Variant in weights:
		if bool(can.get(named, false)):
			total += maxf(float(weights[named]), 0.0)
	if total <= 0.0:
		return [list, &""]
	# The weights' own order, which is the caller's table's: a draw past the last
	# boundary by a rounding error lands on the last kind that can change it.
	var pick := randf() * total
	var kind := &""
	for each: Variant in weights:
		var weight := maxf(float(weights[each]), 0.0)
		if not bool(can.get(each, false)) or weight <= 0.0:
			continue
		kind = StringName(each)
		if pick < weight:
			break
		pick -= weight
	var out := Behaviour.new()
	out.rules.assign(rules)
	match kind:
		NUDGE:
			var at: Array = nudges[randi() % nudges.size()]
			out.rules[int(at[0])] = _nudged(rules[int(at[0])], int(at[1]), vocab)
		REPLACE:
			var replaceable := PackedInt32Array()
			for at in n:
				if _can_replace(rules[at], vocab, owners):
					replaceable.append(at)
			var k := replaceable[randi() % replaceable.size()]
			out.rules[k] = _replaced(rules[k], vocab, owners)
		SWAP:
			var k := swaps[randi() % swaps.size()]
			out.rules[k] = rules[k + 1]
			out.rules[k + 1] = rules[k]
		COPY:
			var k := randi() % n
			out.rules.insert(k + 1, rules[k])
		DROP:
			out.rules.remove_at(randi() % n)
	return [out, kind]


## **Whether two rules say the same**: the same input, the same test on each
## value -- in whatever order they are written, and whether or not a test names
## its input's only value -- the same output and the same option. Two rules this
## build cannot read say the same when their lines are the same.
static func same_rule(a: Rule, b: Rule) -> bool:
	if a == b:
		return true
	if a.inert or b.inert:
		return a.inert and b.inert and a.text == b.text
	if a.input != b.input or a.output != b.output or a.clauses.size() != b.clauses.size():
		return false
	if is_nan(a.option) != is_nan(b.option) or (not is_nan(a.option) and a.option != b.option):
		return false
	for clause: Clause in a.clauses:
		var matched := false
		for other: Clause in b.clauses:
			if other.value == clause.value:
				matched = _same_clause(clause, other)
				break
		if not matched:
			return false
	return true


## **Whether two lists say the same**, rule by rule ([method same_rule]).
static func same(a: Behaviour, b: Behaviour) -> bool:
	if a == b:
		return true
	if a.rules.size() != b.rules.size():
		return false
	for k in a.rules.size():
		if not same_rule(a.rules[k], b.rules[k]):
			return false
	return true


## **What [param list] says, as one string**: equal for two lists that say the
## same ([method same]) and different otherwise, which is what lets a caller
## count how many different lists there are. Made on first asking and kept on
## the list, which never changes.
static func key_of(list: Behaviour) -> String:
	if not list.keyed:
		var lines := PackedStringArray()
		for rule: Rule in list.rules:
			lines.append(_said(rule))
		list.key = "\n".join(lines)
		list.keyed = true
	return list.key


## One rule as [method key_of] writes it: every test naming its value, in the
## order its input carries them; a rule this build cannot read as its line.
static func _said(rule: Rule) -> String:
	if rule.inert:
		return "? " + rule.text
	var tests: Array = []
	for clause: Clause in rule.clauses:
		var words := "%s %s" % [clause.value, TEST_WORDS[clause.test]]
		if clause.test == Test.BELOW or clause.test == Test.ABOVE:
			words += " " + (String(clause.ref) if clause.kind == SIZE else number(clause.step))
		tests.append([clause.at, words])
	tests.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	var said := String(rule.input)
	for test: Array in tests:
		said += " " + String(test[1])
	said += " %s %s" % [ARROW, rule.output]
	if not is_nan(rule.option):
		said += " " + number(rule.option)
	return said


## Whether two tests put the same value to the same test against the same step
## or reference.
static func _same_clause(a: Clause, b: Clause) -> bool:
	if a.value != b.value or a.test != b.test:
		return false
	if a.test == Test.BELOW or a.test == Test.ABOVE:
		return a.step == b.step and a.ref == b.ref
	return true


## **The rungs a test of [param kind] is put against**: its ladder, or for a
## size the references the body knows of itself. None for a kind the rulebook
## does not know, whose tests can only rise or fall.
static func _rungs(kind: StringName) -> Array:
	if kind == SIZE:
		return REFERENCES
	return LADDERS.get(kind, [])


## **Every step a nudge can move in [param list]**: `[rule, test]` for each test
## against a step or a reference with a ladder to move along, and `[rule, -1]`
## for each output that takes more than one option.
static func _nudges(list: Behaviour, vocab: Vocabulary) -> Array:
	var out: Array = []
	for k in list.rules.size():
		var rule := list.rules[k]
		if rule.inert:
			continue
		for c in rule.clauses.size():
			var clause := rule.clauses[c]
			if (clause.test == Test.BELOW or clause.test == Test.ABOVE) \
					and _rungs(clause.kind).size() >= 2:
				out.append([k, c])
		var output := vocab.outputs.get(rule.output) as OutputDecl
		if output != null and not is_nan(rule.option) and output.options.size() >= 2:
			out.append([k, -1])
	return out


## [param rule] with test [param c] -- or, at -1, its option -- one rung up or
## down, by a coin: the other way at the end of the ladder (§6.2).
static func _nudged(rule: Rule, c: int, vocab: Vocabulary) -> Rule:
	var up := randf() < 0.5
	var next := _copy_of(rule)
	if c < 0:
		var output := vocab.outputs[rule.output] as OutputDecl
		next.option = _step_along(output.options, rule.option, up)
	else:
		var clause := _clause_copy(rule.clauses[c])
		if clause.kind == SIZE:
			var at := REFERENCES.find(clause.ref)
			var to := at + (1 if up else -1)
			if to < 0 or to >= REFERENCES.size():
				to = at - (1 if up else -1)
			clause.ref = REFERENCES[clampi(to, 0, REFERENCES.size() - 1)]
		else:
			clause.step = _step_along(_rungs(clause.kind), clause.step, up)
		next.clauses[c] = clause
	_finish(next, vocab)
	return next


## **The next rung of [param ladder] past [param value]**, up or down: the
## nearest above it or below it -- so a value between two rungs, as a file may
## keep one, moves onto one -- and the other way where there is none.
static func _step_along(ladder: Array, value: float, up: bool) -> float:
	var above := INF
	var below := -INF
	for rung: Variant in ladder:
		var at := float(rung)
		if at > value and at < above:
			above = at
		if at < value and at > below:
			below = at
	if (up and above < INF) or below == -INF:
		return above
	return below


## **What a replace can change in [param rule]**, given what could stand in for
## its input ([param inputs], [method _inputs_for]) and its output
## ([param outputs], [method _outputs_for]): its input, when another input
## could; a test, when its input carries a value; its output, when another
## output could. Nothing in a rule this build cannot read, nor in one read by
## another vocabulary than [param vocab].
static func _replaceable_parts(rule: Rule, vocab: Vocabulary, inputs: Array[StringName],
		outputs: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	if not _readable(rule, vocab):
		return out
	if not inputs.is_empty():
		out.append(INPUT_PART)
	if rule.input != ALWAYS and not (vocab.inputs[rule.input] as InputDecl).values.is_empty():
		out.append(TEST_PART)
	if not outputs.is_empty():
		out.append(OUTPUT_PART)
	return out


## **Whether a replace can change [param rule] at all**: what
## [method _replaceable_parts] says, asked the short way -- a test can always be
## added or taken away where its input carries a value, and otherwise the first
## input or output that could stand in will do.
static func _can_replace(rule: Rule, vocab: Vocabulary, owners: PackedInt64Array) -> bool:
	if not _readable(rule, vocab):
		return false
	if rule.input != ALWAYS and not (vocab.inputs[rule.input] as InputDecl).values.is_empty():
		return true
	return not _inputs_for(rule, vocab, owners, true).is_empty() \
		or not _outputs_for(rule, vocab, owners, true).is_empty()


## Whether [param rule] is one [param vocab] reads: not inert, and its input and
## output both its.
static func _readable(rule: Rule, vocab: Vocabulary) -> bool:
	return not rule.inert and vocab.outputs.has(rule.output) \
		and (rule.input == ALWAYS or vocab.inputs.has(rule.input))


## **The inputs that could stand in for [param rule]'s**: every input whose
## owner-and-level is in [param owners], and [constant ALWAYS], but its own --
## and only those with a bearing when its output needs one. With [param one],
## the first found.
static func _inputs_for(rule: Rule, vocab: Vocabulary, owners: PackedInt64Array,
		one := false) -> Array[StringName]:
	var output := vocab.outputs[rule.output] as OutputDecl
	var bearing := output.needs == BEARING
	var out: Array[StringName] = []
	if rule.input != ALWAYS and not bearing:
		out.append(ALWAYS)
		if one:
			return out
	for name: StringName in vocab.inputs:
		var input := vocab.inputs[name] as InputDecl
		if name != rule.input and has_bit(owners, input.bit) \
				and (input.bearing or not bearing):
			out.append(name)
			if one:
				return out
	return out


## **The outputs that could stand in for [param rule]'s**: every output whose
## owner-and-level is in [param owners] but its own, and only those that need no
## bearing when its input carries none. With [param one], the first found.
static func _outputs_for(rule: Rule, vocab: Vocabulary, owners: PackedInt64Array,
		one := false) -> Array[StringName]:
	var input := vocab.inputs.get(rule.input) as InputDecl
	var bearing := input != null and input.bearing
	var out: Array[StringName] = []
	for name: StringName in vocab.outputs:
		var output := vocab.outputs[name] as OutputDecl
		if name != rule.output and has_bit(owners, output.bit) \
				and (output.needs != BEARING or bearing):
			out.append(name)
			if one:
				return out
	return out


## [param rule] with one part replaced (§6.2): which part by a draw among those
## that can be, then what stands in for it.
static func _replaced(rule: Rule, vocab: Vocabulary, owners: PackedInt64Array) -> Rule:
	var inputs := _inputs_for(rule, vocab, owners)
	var outputs := _outputs_for(rule, vocab, owners)
	var parts := _replaceable_parts(rule, vocab, inputs, outputs)
	var part := parts[randi() % parts.size()]
	var next := _copy_of(rule)
	match part:
		INPUT_PART:
			next.input = inputs[randi() % inputs.size()]
			next.in_owner = &""
			next.clauses.clear()
			var input := vocab.inputs.get(next.input) as InputDecl
			if input != null:
				next.in_owner = input.owner
				# **Fresh tests**: none, or one on a value it carries -- by a coin.
				if not input.values.is_empty() and randf() < 0.5:
					next.clauses.append(_fresh(input, randi() % input.values.size()))
		TEST_PART:
			_retested(next, vocab.inputs[rule.input] as InputDecl)
		OUTPUT_PART:
			var output := vocab.outputs[outputs[randi() % outputs.size()]] as OutputDecl
			next.output = output.name
			next.out_owner = output.owner
			next.claims = output.claims
			next.option = NAN if output.options.is_empty() \
				else output.options[randi() % output.options.size()]
	_finish(next, vocab)
	return next


## **One of [param rule]'s tests replaced** (§6.2), in place: another in its
## place -- on its value or on one its input carries untested -- or one added on
## a value untested, or one removed; by a draw among those that can be.
static func _retested(rule: Rule, input: InputDecl) -> void:
	var free: Array[int] = []
	for at in input.values.size():
		var tested := false
		for clause: Clause in rule.clauses:
			tested = tested or clause.at == at
		if not tested:
			free.append(at)
	var ways: Array[int] = []
	if not rule.clauses.is_empty():
		ways.append_array([0, 1])
	if not free.is_empty():
		ways.append(2)
	match ways[randi() % ways.size()]:
		0:
			var c := randi() % rule.clauses.size()
			var was := rule.clauses[c]
			var places := free.duplicate()
			places.append(was.at)
			var fresh := _fresh(input, places[randi() % places.size()])
			while _same_clause(fresh, was):
				fresh = _fresh(input, places[randi() % places.size()])
			rule.clauses[c] = fresh
		1:
			rule.clauses.remove_at(randi() % rule.clauses.size())
		2:
			rule.clauses.append(_fresh(input, free[randi() % free.size()]))


## **A test drawn afresh** on [param input]'s value at [param at]: any of the
## four, against a rung of its ladder drawn as well -- or only rising or
## falling, for a kind with no ladder. Written the shortest way: its value named
## unless it is the only one its input carries besides a bearing.
static func _fresh(input: InputDecl, at: int) -> Clause:
	var clause := Clause.new()
	clause.value = input.values[at]
	clause.at = at
	clause.kind = input.kinds[at]
	clause.degrees = clause.kind == BEARING
	clause.named = input.lone() != clause.value
	var rungs := _rungs(clause.kind)
	clause.test = (randi() % 4 if not rungs.is_empty() else 2 + randi() % 2) as Test
	if clause.test == Test.BELOW or clause.test == Test.ABOVE:
		var rung: Variant = rungs[randi() % rungs.size()]
		if clause.kind == SIZE:
			clause.ref = StringName(rung)
		else:
			clause.step = float(rung)
	return clause


## A new rule with [param rule]'s parts, its tests a new array of the same
## tests: changed and finished by the caller.
static func _copy_of(rule: Rule) -> Rule:
	var next := Rule.new()
	next.text = rule.text
	next.inert = rule.inert
	next.input = rule.input
	next.in_owner = rule.in_owner
	next.clauses.assign(rule.clauses)
	next.output = rule.output
	next.out_owner = rule.out_owner
	next.claims = rule.claims
	next.needs = rule.needs
	next.far = rule.far.duplicate()
	next.option = rule.option
	return next


static func _clause_copy(clause: Clause) -> Clause:
	var next := Clause.new()
	next.value = clause.value
	next.at = clause.at
	next.kind = clause.kind
	next.test = clause.test
	next.step = clause.step
	next.ref = clause.ref
	next.named = clause.named
	next.degrees = clause.degrees
	return next


## [param rule] made whole after a change, as [method rule_from] would make it
## from its line: the owners it needs, at the level each part needs, and the
## line itself.
static func _finish(rule: Rule, vocab: Vocabulary) -> void:
	rule.inert = false
	rule.needs = 0
	rule.far = PackedInt64Array()
	_need(rule, (vocab.outputs[rule.output] as OutputDecl).bit)
	if rule.input != ALWAYS:
		_need(rule, (vocab.inputs[rule.input] as InputDecl).bit)
	rule.text = line_of(rule)
