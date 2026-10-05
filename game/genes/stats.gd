extends RefCounted
## **The stats** (docs/design/gene-catalogue.md §5): every number a mechanic reads
## off a body, by name, with no gene in it -- `turn_rate`, `armor`, `ping_range`.
## A gene provides stats (gene.gd's `provides`); a mechanic reads a body's, here,
## and never asks which gene gave it.
##
## **A stat a body has** is its providers' values at the copies it wears of each,
## combined by the stat's row; with none, it is the stat's value with no provider.
## Today every stat has exactly one provider, so every combine rule gives the
## number the table it was always read from gives. A rule only starts to matter
## when the gene pass adds a second provider of a stat, and it is set here then.
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
## judges a guest by it -- every table `Wire.RULES` fingerprints, so changing one
## changes the protocol (wire.gd).
const ROWS := {
	# The mouth.
	&"gape": {"none": 0.58, "better": HIGHER, "combine": BEST, "unit": "x radius",
		"judged": false},
	&"bite": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "of a body",
		"judged": false},
	# The tail.
	&"impulse_speed": {"none": 118.0, "better": HIGHER, "combine": BEST,
		"unit": "µm/s", "judged": true},
	&"impulse_gap_min": {"none": 2.0, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": true},
	&"impulse_gap_max": {"none": 4.3, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": false},
	# Steering.
	&"turn_rate": {"none": 0.48, "better": HIGHER, "combine": BEST, "unit": "rad/s",
		"judged": true},
	&"turn_response": {"none": 1.43, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": false},
	# The beam, by its level's rung.
	&"beam_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": false},
	&"beam_count": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "rays",
		"judged": false},
	&"beam_fan_deg": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "deg",
		"judged": false},
	# The nose.
	&"smell_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": false},
	# The ping.
	&"ping_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": true},
	&"ping_period": {"none": 0.0, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": true},
	&"ping_through": {"none": 0.0, "better": HIGHER, "combine": BEST,
		"unit": "of a pulse", "judged": false},
	# The push and the dash.
	&"push_accel": {"none": 0.0, "better": HIGHER, "combine": SUM, "unit": "µm/s²",
		"judged": true},
	&"dash_speed": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm/s",
		"judged": true},
	&"dash_cost": {"none": 0.0, "better": LOWER, "combine": BEST, "unit": "of a tank",
		"judged": false},
	# The body's own: its armour, its tank, its burn and its light.
	&"armor": {"none": 1.0, "better": HIGHER, "combine": PRODUCT, "unit": "x size",
		"judged": false},
	&"store": {"none": 1.0, "better": HIGHER, "combine": PRODUCT, "unit": "x tank",
		"judged": false},
	&"burn": {"none": 1.0, "better": LOWER, "combine": PRODUCT, "unit": "x upkeep",
		"judged": false},
	&"sun": {"none": 0.0, "better": HIGHER, "combine": SUM, "unit": "of upkeep",
		"judged": false},
	# Touch.
	&"touch_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": false},
	# The dart.
	&"dart_range": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "µm",
		"judged": false},
	&"dart_cooldown": {"none": 0.0, "better": LOWER, "combine": BEST, "unit": "s",
		"judged": false},
	# The toxin: venom outside, poison inside (docs/design/dna-slots.md §6).
	&"venom_stacks": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "stacks",
		"judged": false},
	&"poison_stacks": {"none": 0.0, "better": HIGHER, "combine": BEST, "unit": "stacks",
		"judged": false},
	&"swallow_stacks": {"none": 0.0, "better": HIGHER, "combine": BEST,
		"unit": "stacks", "judged": false},
}

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
static func of(tiers: Dictionary, stat: StringName) -> float:
	var pairs: Array = _provided.get(stat, NO_PAIRS)
	if pairs.size() == 2:
		var worn := int(tiers.get(pairs[0], 0))
		if worn <= 0:
			return float((ROWS[stat] as Dictionary)["none"])
		var only: Array = pairs[1]
		return float(only[mini(worn, only.size() - 1)])
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


## **The copies a body wearing [param tiers] wears its first provider of
## [param stat] at**, clamped to its table; 0 for none. What a mechanic that
## indexes a table of its own by the organ's tier reads (gene-catalogue.md §5.1):
## the ping's resolution in `food.gd`, the membrane's envelopes in
## `signal_bus.gd`.
static func tier(tiers: Dictionary, stat: StringName) -> int:
	var pairs: Array = _provided.get(stat, NO_PAIRS)
	for i in range(0, pairs.size(), 2):
		var copies := int(tiers.get(pairs[i], 0))
		if copies > 0:
			return mini(copies, (pairs[i + 1] as Array).size() - 1)
	return 0


## **[param stat] at [param copies] of [param key]**: its own table's, clamped,
## and the value with no provider for a key that does not provide it.
static func value(key: StringName, stat: StringName, copies: int) -> float:
	var table: Array = Catalogue.table(key, stat)
	if table.is_empty():
		return none(stat)
	return float(table[clampi(copies, 0, table.size() - 1)])


## [param stat] at [param copies] of its first provider: a number read at a tier a
## caller already holds -- a tool's, or a stat of a body only ever worn whole.
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


## **The best [param stat] any provider reaches at any copies**, by its row's
## `better`: how far the farthest call carries, for a limit no body passes.
static func top(stat: StringName) -> float:
	var row: Dictionary = ROWS[stat]
	var higher: bool = row["better"] == HIGHER
	var best := float(row["none"])
	var pairs: Array = _provided.get(stat, NO_PAIRS)
	for i in range(1, pairs.size(), 2):
		for given: Variant in pairs[i]:
			var at_copies := float(given)
			if (at_copies > best) if higher else (at_copies < best):
				best = at_copies
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
