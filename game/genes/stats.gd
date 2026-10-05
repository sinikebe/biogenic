extends RefCounted
## **The stats** (docs/design/gene-catalogue.md §5): every number a mechanic reads
## off a body, by name, with no gene in it -- `turn_rate`, `armor`, `ping_range`.
## A gene provides stats (gene.gd's `provides`); a mechanic reads a body's, here,
## and never asks which gene gave it.
##
## **A stat a body has** is its providers' values at the copies it wears of each,
## combined by the stat's row -- or, for a stat a mechanic reads with others (its
## row's `group`), the value of the one provider the whole group is taken from;
## with none, it is the stat's value with no provider. Today every stat has exactly
## one provider, so every rule gives the number the table it was always read from
## gives. A rule only starts to matter when the gene pass adds a second provider of a
## stat, and it is set here then.
##
## **Each is named after the constant it was** -- `TURN_RATE_BY_TIER` in
## `cell.gd` is `turn_rate` -- so the fingerprints that list every table
## (`drop_save.gd`'s rules, `tools/net_probe.gd`'s RULES) write the lines they
## always wrote ([method label]).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Catalogue := preload("res://game/genes/catalogue.gd")

## Which way is better, for a row's `better`.
const HIGHER := &"higher"
const LOWER := &"lower"
## How several providers combine, for a row's `combine`: the best of them by
## `better`; what each adds, for a stat whose value with no provider is 0; or
## what each multiplies by, for one whose value with no provider is 1.
const BEST := &"best"
const SUM := &"sum"
const PRODUCT := &"product"

## **One row per stat**: `none`, its value with no provider -- index 0 of every
## table that provides it, which means *does not have this organ*; `better`,
## which way is better; `combine`, how several providers combine; `unit`, what it
## is counted in, for the stats screen; `judged`, whether a shared pond's referee
## judges a guest by it; `contact`, whether the host decides a contact by it --
## a mouth, a skin, a bite, a dose, a dart -- which a guest feels by its own; and
## `group`, the stat whose best provider a body takes it from, with the others a
## mechanic reads with it ([method groups]), `&""` for a stat read alone. **A table
## either marks is one two builds in one pond must agree on**: it is in the rules the
## handshake fingerprints (game/net/rules.gd), by every organ that provides it, so a
## change to one keeps builds on the old table apart, by themselves.
const ROWS := {
	# The mouth.
	&"gape": {"none": 0.58, "better": HIGHER, "combine": BEST, "unit": "x radius",
		"judged": false, "contact": true, "group": &""},
	&"bite": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "of a body",
		"judged": false, "contact": true, "group": &""},
	# The tail.
	&"impulse_speed": {"none": 118.0, "better": HIGHER, "combine": BEST,
		"unit": "µm/s", "judged": true, "contact": false, "group": &"impulse_speed"},
	&"impulse_gap_min": {"none": 2.0, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": true, "contact": false, "group": &"impulse_speed"},
	&"impulse_gap_max": {"none": 4.3, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": false, "contact": false, "group": &"impulse_speed"},
	# Steering.
	&"turn_rate": {"none": 0.48, "better": HIGHER, "combine": BEST, "unit": "rad/s",
		"judged": true, "contact": false, "group": &"turn_rate"},
	&"turn_response": {"none": 1.43, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": false, "contact": false, "group": &"turn_rate"},
	# The beam, by its level's rung.
	&"beam_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": false, "contact": false, "group": &"beam_range"},
	&"beam_count": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "rays",
		"judged": false, "contact": false, "group": &"beam_range"},
	&"beam_fan_deg": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "deg",
		"judged": false, "contact": false, "group": &"beam_range"},
	# The nose.
	&"smell_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": false, "contact": false, "group": &""},
	# The ping.
	&"ping_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": true, "contact": false, "group": &"ping_range"},
	&"ping_period": {"none": 0.0, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": true, "contact": false, "group": &"ping_range"},
	&"ping_through": {"none": 0.0, "better": HIGHER, "combine": BEST,
		"unit": "of a pulse", "judged": false, "contact": false, "group": &"ping_range"},
	# The push and the dash.
	&"push_accel": {"none": 0.0, "better": HIGHER, "combine": SUM, "unit": "µm/s²",
		"judged": true, "contact": false, "group": &""},
	&"dash_speed": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm/s",
		"judged": true, "contact": false, "group": &"dash_speed"},
	&"dash_cost": {"none": 0.0, "better": LOWER, "combine": BEST, "unit": "of a tank",
		"judged": false, "contact": false, "group": &"dash_speed"},
	# The body's own: its armour, its tank, its burn and its light.
	&"armor": {"none": 1.0, "better": HIGHER, "combine": PRODUCT, "unit": "x size",
		"judged": false, "contact": true, "group": &""},
	&"store": {"none": 1.0, "better": HIGHER, "combine": PRODUCT, "unit": "x tank",
		"judged": false, "contact": false, "group": &""},
	&"burn": {"none": 1.0, "better": LOWER, "combine": PRODUCT, "unit": "x upkeep",
		"judged": false, "contact": false, "group": &""},
	&"sun": {"none": 0.0, "better": HIGHER, "combine": SUM, "unit": "of upkeep",
		"judged": false, "contact": false, "group": &""},
	# Touch.
	&"touch_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": false, "contact": false, "group": &""},
	# The dart.
	&"dart_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": false, "contact": true, "group": &"dart_range"},
	&"dart_cooldown": {"none": 0.0, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": false, "contact": true, "group": &"dart_range"},
	# The toxin: venom outside, poison inside (docs/design/dna-slots.md §6).
	&"venom_stacks": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "stacks",
		"judged": false, "contact": true, "group": &""},
	&"poison_stacks": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "stacks",
		"judged": false, "contact": true, "group": &""},
	&"swallow_stacks": {"none": 0.0, "better": HIGHER, "combine": BEST,
		"unit": "stacks", "judged": false, "contact": true, "group": &""},
}

## **The stats whose mechanic acts from a place** (gene-catalogue.md §5.2): the
## beam leaves from where its provider is worn, the ping calls from there, the dart
## looks along that arc, and the nose's level is weighted about it. Where a body
## wears several providers of one, the mechanic acts from the first in slot order
## (catalogue.gd's `seated_provider`), and everything it reads off the organ itself
## -- its arc, its level, its tier, its own numbers -- is that organ's; the stat
## still combines by its row. Every other mechanic acts from the first in the
## catalogue's order (`worn_provider`) -- [method organ] says which.
const SEATED: Array[StringName] = [&"beam_range", &"ping_range", &"dart_range",
	&"smell_range"]

## **Each stat's providers beside their tables, `[key, table, ...]`**: the
## catalogue's own dictionary (its `provided()`), held here so that the read
## [method of] makes every frame, for every body, is a lookup in a static of this
## script's rather than a call into another. The catalogue refills it in place
## whenever it indexes and never replaces it, so this is never stale.
static var _provided: Dictionary = Catalogue.provided()
## The pairs of a stat nothing provides.
const NO_PAIRS: Array = []


## **A body's [param stat]**: what it wears of the stat's providers -- its
## [param tiers], key to copies -- each at its copies, combined by the stat's row.
## The value with no provider when it wears none. Copies are clamped to the
## table, as every read of a tier table always was.
##
## **Read every frame, by every body**, so it is one lookup and an index per
## provider worn: [member _provided] has each provider beside its table, and the
## row is only read for a body that wears none or several. A stat of one
## provider -- every stat today -- skips the walk.
##
## **A stat of a group** (its row's `group`, [method groups]) with several providers
## is the value of the one provider the body wears that is best on the group's first
## stat, at its copies -- one organ's for the whole group, never combined.
static func of(tiers: Dictionary, stat: StringName) -> float:
	var pairs: Array = _provided.get(stat, NO_PAIRS)
	if pairs.size() == 2:
		var worn := int(tiers.get(pairs[0], 0))
		if worn <= 0:
			return float((ROWS[stat] as Dictionary)["none"])
		var only: Array = pairs[1]
		return float(only[mini(worn, only.size() - 1)])
	var lead: StringName = (ROWS[stat] as Dictionary)["group"]
	if lead != &"":
		var from := grouped(tiers, lead)
		var own: Array = Catalogue.table(from, stat) if from != &"" else NO_PAIRS
		if own.is_empty():
			return float((ROWS[stat] as Dictionary)["none"])
		return float(own[mini(int(tiers.get(from, 0)), own.size() - 1)])
	var value := 0.0
	var found := false
	for i in range(0, pairs.size(), 2):
		var copies := int(tiers.get(pairs[i], 0))
		if copies <= 0:
			continue
		var table: Array = pairs[i + 1]
		var given := float(table[mini(copies, table.size() - 1)])
		value = _combined(ROWS[stat], value, given) if found else given
		found = true
	return value if found else float((ROWS[stat] as Dictionary)["none"])


## **The stats a mechanic reads together, as one organ's** (gene-catalogue.md §5.1,
## §15.6), by their rows' `group`: each group's stats in [constant ROWS]' order, its
## first the stat its provider is chosen by. A call is its reach, its period and how
## much of it passes a body; a stroke its speed and its two gaps; a turn its rate and
## how fast it answers; a beam its reach, its rays and their fan; a dash its burst
## and its price; a dart its reach and its rest. **A group is one provider's**: a body
## wearing two providers takes every stat of a group from the one that is best on its
## first stat, and never mixes them stat by stat -- two tails swim at the faster one's
## speed with the faster one's gaps, not the other's shorter gap. So every organ that
## provides one stat of a group provides all of it, and a group's stats combine by
## `best`, which the gene probe holds. No stat has two providers today, so no body
## reads a group yet.
static func groups() -> Array:
	var by_lead := {}
	var out: Array = []
	for stat: StringName in ROWS:
		var lead: StringName = (ROWS[stat] as Dictionary)["group"]
		if lead == &"":
			continue
		if not by_lead.has(lead):
			by_lead[lead] = [] as Array[StringName]
			out.append(by_lead[lead])
		(by_lead[lead] as Array).append(stat)
	return out


## **The provider a body wearing [param tiers] takes a group's stats from**
## ([method groups]): of the providers of [param lead], the group's first stat, it
## wears, the one whose value at its copies is best by the row's `better` -- the first
## in the catalogue's order on a tie. `&""` for a body that wears none.
static func grouped(tiers: Dictionary, lead: StringName) -> StringName:
	var pairs: Array = _provided.get(lead, NO_PAIRS)
	var higher: bool = (ROWS[lead] as Dictionary)["better"] == HIGHER
	var best := &""
	var best_value := 0.0
	for i in range(0, pairs.size(), 2):
		var copies := int(tiers.get(pairs[i], 0))
		if copies <= 0:
			continue
		var table: Array = pairs[i + 1]
		var given := float(table[mini(copies, table.size() - 1)])
		if best == &"" or (given > best_value if higher else given < best_value):
			best = pairs[i]
			best_value = given
	return best


## **The copies a body wearing [param tiers] wears its first provider of
## [param stat] at**, in the catalogue's order, clamped to its table; 0 for none.
## What a mechanic that indexes a table of its own by the organ's tier reads
## (gene-catalogue.md §5.1) -- the membrane's envelopes in `signal_bus.gd` -- and
## whether a body wears any. A mechanic with a place reads its own organ's,
## [method tier_of] of [method organ].
static func tier(tiers: Dictionary, stat: StringName) -> int:
	var pairs: Array = _provided.get(stat, NO_PAIRS)
	for i in range(0, pairs.size(), 2):
		var copies := int(tiers.get(pairs[i], 0))
		if copies > 0:
			return mini(copies, (pairs[i + 1] as Array).size() - 1)
	return 0


## **The copies a body wearing [param tiers] wears [param key] at**, clamped to
## its table of [param stat]; 0 for none. [method tier] for the one organ a
## mechanic acts from ([method organ]): the ping's resolution, the beam's rung.
static func tier_of(tiers: Dictionary, key: StringName, stat: StringName) -> int:
	var copies := int(tiers.get(key, 0)) if key != &"" else 0
	if copies <= 0:
		return 0
	return mini(copies, Catalogue.table(key, stat).size() - 1)


## **The organ a body acts from for [param stat]'s mechanic**, `&""` for none: for
## a stat of [constant SEATED], the first provider it wears in slot order --
## [param layout], its slots (catalogue.gd's `seated_provider`) -- and for any
## other, the first in the catalogue's order (`worn_provider`), the layout unread.
static func organ(layout: Array, tiers: Dictionary, stat: StringName) -> StringName:
	if SEATED.has(stat):
		return Catalogue.seated_provider(layout, tiers, stat)
	return Catalogue.worn_provider(tiers, stat)


## **[param stat] at [param copies] of [param key]**: its own table's, clamped,
## and the value with no provider for a key that does not provide it.
static func value(key: StringName, stat: StringName, copies: int) -> float:
	var table: Array = Catalogue.table(key, stat)
	if table.is_empty():
		return none(stat)
	return float(table[clampi(copies, 0, table.size() - 1)])


## [param stat] at [param copies] of its first provider: a number a tool reads at
## a tier it already holds. **No mechanic reads it**: a body's stat is [method
## of]'s, by the providers it wears, and the first provider is not always the one
## worn.
static func at(stat: StringName, copies: int) -> float:
	var pairs: Array = _provided.get(stat, NO_PAIRS)
	if pairs.is_empty() or (pairs[1] as Array).is_empty():
		return none(stat)
	var first: Array = pairs[1]
	return float(first[clampi(copies, 0, first.size() - 1)])


## **The table of [param stat]'s first provider**, read-only: what a fingerprint
## writes and a tool checks. A mechanic reads a body's value with [method of].
static func table(stat: StringName) -> Array:
	return Catalogue.table(Catalogue.first_provider(stat), stat)


## **The best [param stat] any body reaches**, for a limit no body passes: every
## provider at its best copies by the row's `better`, combined by the row's rule
## as a body wearing all of them would have them -- the best of them, their sum
## or their product. How far the farthest call carries; how much push every
## organ that pushes adds up to.
static func top(stat: StringName) -> float:
	var row: Dictionary = ROWS[stat]
	var higher: bool = row["better"] == HIGHER
	var best := float(row["none"])
	var pairs: Array = _provided.get(stat, NO_PAIRS)
	for i in range(1, pairs.size(), 2):
		var own := float(row["none"])
		for given: Variant in pairs[i]:
			var at_copies := float(given)
			if (at_copies > own) if higher else (at_copies < own):
				own = at_copies
		best = _combined(row, best, own)
	return best


## [param stat]'s value with no provider.
static func none(stat: StringName) -> float:
	return float((ROWS[stat] as Dictionary)["none"])


## **Every stat the referee judges by**, in [constant ROWS]' order.
static func judged() -> Array[StringName]:
	var out: Array[StringName] = []
	for stat: StringName in ROWS:
		if bool((ROWS[stat] as Dictionary)["judged"]):
			out.append(stat)
	return out


## **The stats the host decides a contact by** (a row's `contact`), in the rows'
## order: with [method judged], every table the handshake's rules fingerprint.
static func contact() -> Array[StringName]:
	var out: Array[StringName] = []
	for stat: StringName in ROWS:
		if bool((ROWS[stat] as Dictionary)["contact"]):
			out.append(stat)
	return out


## **The line a fingerprint writes [param stat]'s table under**: the constant it
## was, `cell.TURN_RATE_BY_TIER` for `turn_rate`, so the lines are the ones they
## always were.
static func label(stat: StringName) -> String:
	return "cell.%s_BY_TIER" % String(stat).to_upper()


## [param value] and [param given] combined by [param row]'s rule.
static func _combined(row: Dictionary, value: float, given: float) -> float:
	match row["combine"]:
		SUM:
			return value + given
		PRODUCT:
			return value * given
	return maxf(value, given) if row["better"] == HIGHER else minf(value, given)
