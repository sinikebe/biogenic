extends Node
## CI probe: **the genes, as data** (docs/design/gene-catalogue.md §12.1). Every
## gene's numbers, lists, tags and rules live in its organ's file under
## game/genes/organs/, and everything that reads one asks the catalogue. What a
## render cannot show is a gene that is half there: a key the wire refuses, a
## table one entry short, a gene the water can never make, a sense no channel
## carries, an organ file the index forgot. Each of those works alone and fails
## somewhere else -- in a shared pond, a seeded water, a save -- so it fails here
## first.
##
## **Static, and a few seconds**: it reads the catalogue and the files, and plays
## nothing. Phase 1a's checks (§15): the keys, the water, the stat tables, the
## founders' parts and the gift, every declared part wired in a water cell and in
## yours, the index against the folder, a gene registered and forgotten, and -- a
## number, not yet a failure (§12.2) -- how many gene names are still written into
## game/ outside game/genes/.
##
## Prints one line per check and `ALL PASS` only if every one held; CI asserts on
## that marker rather than on the exit code, because Godot exits 0 after a script
## error too.
##
## Excluded from export (`tools/*`), so it never ships. No class_name, for the
## reason signal_bus.gd gives.

const Gene := preload("res://game/genes/gene.gd")
const Catalogue := preload("res://game/genes/catalogue.gd")
const Stats := preload("res://game/genes/stats.gd")
const Genome := preload("res://game/normal/genome.gd")
const CellBody := preload("res://game/normal/cell.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")
const FoodField := preload("res://game/normal/food.gd")
const OwnRules := preload("res://game/normal/own_rules.gd")
const Drop := preload("res://game/normal/drop.gd")
const Rulebook := preload("res://game/mechanics/rulebook.gd")
const Wire := preload("res://game/net/wire.gd")
const Referee := preload("res://game/net/referee.gd")

## **Every key that ever shipped, in its order** -- its place is its index -- and
## the ones retired before the catalogue, which have none. Keys are permanent
## once shipped (§4.4): saves and the wire keep them, and the order is the
## tie-break of what a body is drawn as. **A new gene appends its key here**, in
## the commit that adds it, with the next order; nothing here is ever removed or
## moved, and a gene retired later stays where it is.
const SHIPPED: Array[StringName] = [
	&"cytostome", &"cirrus", &"flagellum", &"stigma",
	&"ocellus", &"chemocyte", &"ampulla",
	&"axoneme", &"palp", &"myoneme",
	&"trichocyst", &"pellicle", &"veneneux", &"plastid", &"vacuole", &"crista",
	&"toxicyst"]
const SHIPPED_PLACELESS: Array[StringName] = [&"rhabdom", &"statocyst"]
## **The order each list a draw or a bit reads shipped in** -- catalogue.gd's
## `SHIPPED_ORDERS`, kept here as well so that a change there fails here: what a
## drifter is drawn from, by weight in this order; the senses the water counts;
## the gift, drawn `randi() % 4` in this order; and the genes that declare parts,
## in the order the rulebook gives them bits. A seeded water, a rule's bits and
## `Wire.RULES` all hang on these orders. **A new gene appends to the lists it
## joins**; a gene leaving one -- retired, say -- changes every seeded draw, and
## is the commit that updates this.
const SHIPPED_LISTS := {
	&"drifter": [&"cirrus", &"flagellum", &"stigma", &"chemocyte", &"ampulla",
		&"ocellus", &"axoneme", &"palp", &"myoneme",
		&"trichocyst", &"pellicle", &"veneneux", &"plastid", &"vacuole", &"crista"],
	&"sense": [&"chemocyte", &"ampulla", &"ocellus", &"stigma"],
	&"gift": [&"ocellus", &"ampulla", &"chemocyte", &"stigma"],
	&"declares": [&"ocellus", &"ampulla", &"chemocyte", &"stigma", &"palp", &"myoneme",
		&"axoneme", &"flagellum"],
}

## **The stats a mechanic reads together, as one organ's** -- so every organ that
## provides one of a group provides all of it: a call is its reach, its period
## and how much of it passes a body; a stroke its speed and its two gaps; a turn
## its rate and how fast it answers; a dash its burst and its price; a dart its
## reach and its rest; a beam its reach, its rays and their fan. An organ that
## gave one alone would be read at the others' values with no provider -- a call
## every 0 s, which the referee divides by, or a tail's speed beating at the
## gaps of no tail.
const TOGETHER: Array = [
	[&"ping_range", &"ping_period", &"ping_through"],
	[&"impulse_speed", &"impulse_gap_min", &"impulse_gap_max"],
	[&"turn_rate", &"turn_response"],
	[&"dash_speed", &"dash_cost"],
	[&"dart_range", &"dart_cooldown"],
	[&"beam_range", &"beam_count", &"beam_fan_deg"],
]

## The folder the index must match, file for file.
const ORGANS_DIR := "res://game/genes/organs"
## Where the gene names left in code are counted (§12.2), and what is exempt.
const GAME_DIR := "res://game"
const GENES_DIR := "res://game/genes"

var _failed := 0


func _ready() -> void:
	_keys()
	_index()
	_water()
	_tables()
	_rules()
	_wiring()
	_mechanics()
	_register()
	_names_left()
	print("[gene-probe] ALL PASS" if _failed == 0 else "[gene-probe] FAILED %d" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("[gene-probe] %s %s" % ["PASS" if ok else "FAIL", what])


# --- The keys (§4.4) -----------------------------------------------------------------

## Every key a name the wire carries, each once, and every shipped key still
## there in its place.
func _keys() -> void:
	var refused: Array[StringName] = []
	for key: StringName in Catalogue.keys():
		if not Wire._name_ok(String(key)):
			refused.append(key)
	_check("every one of the %d keys is 1 to %d letters a-z, a name the wire carries%s"
		% [Catalogue.keys().size(), Wire.NAME_MAX,
			"" if refused.is_empty() else ": not %s" % str(refused)], refused.is_empty())
	# Unique: every form of every organ file is filed, none dropped as a second
	# of its key (the catalogue keeps the first and says so).
	var forms := 0
	var seen := {}
	var twice: Array[StringName] = []
	for organ: Gene in _organs():
		for key: StringName in _keys_of(organ):
			forms += 1
			if seen.has(key):
				twice.append(key)
			seen[key] = true
	_check("every key is one form's alone: %d forms in the organ files, %d keys filed%s"
		% [forms, Catalogue.keys().size(), "" if twice.is_empty() else ", %s twice" % str(twice)],
		twice.is_empty() and forms == Catalogue.keys().size())
	# Unique names: the catalogue finds a variant's forms by its organ's name and
	# its own, so two files of one organ name -- a copy of toxin.gd, say -- or two
	# variants of one name in a file would answer for each other's forms.
	var organs := {}
	var clashes: Array[String] = []
	for organ: Gene in _organs():
		if organs.has(organ.organ):
			clashes.append("organ %s twice" % organ.organ)
		organs[organ.organ] = true
		var variants := {}
		for entry: Dictionary in organ.variants:
			var name := StringName(entry.get("variant", &""))
			if variants.has(name):
				clashes.append("%s's variant %s twice" % [organ.organ, name])
			variants[name] = true
	_check("every organ's name is its own, %d of them, and every variant's within its organ%s"
		% [organs.size(), "" if clashes.is_empty() else ": " + ", ".join(clashes)],
		clashes.is_empty())
	var moved: Array[String] = []
	for i in SHIPPED.size():
		if Catalogue.rank(SHIPPED[i]) != i:
			moved.append("%s at %d, not %d" % [SHIPPED[i], Catalogue.rank(SHIPPED[i]), i])
	for key: StringName in SHIPPED_PLACELESS:
		if not Catalogue.known(key) or Catalogue.rank(key) != -1:
			moved.append("%s %s" % [key, "unknown" if not Catalogue.known(key) else "ranked"])
	var unlisted: Array[StringName] = []
	for key: StringName in Catalogue.keys():
		if not SHIPPED.has(key) and not SHIPPED_PLACELESS.has(key):
			unlisted.append(key)
	_check(("every shipped key is known in its place in the order, %d of them, and the two"
		+ " retired before the catalogue known with none%s%s") % [SHIPPED.size(),
			"" if moved.is_empty() else ": " + ", ".join(moved),
			"" if unlisted.is_empty()
				else "; new keys %s must be appended to SHIPPED" % str(unlisted)],
		moved.is_empty() and unlisted.is_empty())
	var order: Array[StringName] = []
	order.assign(Catalogue.keys().slice(0, SHIPPED.size()))
	# A gene retired later keeps its place in the order and leaves the live ones.
	var live := SHIPPED.filter(func(key: StringName) -> bool:
		return not Catalogue.has_tag(key, Catalogue.RETIRED))
	_check("keys() is the order, today's GENE_ORDER, then the placeless, and live() the same"
		+ " less any retired: %s" % str(Catalogue.keys()), order == SHIPPED
		and Array(Catalogue.live()) == Array(live))
	var retired_ok := true
	for key: StringName in SHIPPED_PLACELESS:
		retired_ok = retired_ok and Catalogue.has_tag(key, Catalogue.RETIRED) \
			and not Catalogue.live().has(key) and not Catalogue.drifters().has(key) \
			and Catalogue.tagged(Catalogue.GIFT).find(key) < 0
	_check("rhabdom and statocyst are known, retired, and in no list that makes a gene",
		retired_ok)


# --- The index (§4.1) ------------------------------------------------------------------

## The index lists every organ file in the folder, and nothing else.
func _index() -> void:
	var indexed: Array[String] = []
	for script: GDScript in Catalogue.ORGANS:
		indexed.append(script.resource_path.get_file())
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(ORGANS_DIR):
		if file.ends_with(".gd"):
			files.append(file)
	var missing := files.filter(func(file: String) -> bool: return not indexed.has(file))
	var stray := indexed.filter(func(file: String) -> bool: return not files.has(file))
	var doubled := indexed.filter(func(file: String) -> bool: return indexed.count(file) > 1)
	_check("the index lists every one of the %d organ files once, and nothing else%s%s%s"
		% [files.size(), "" if missing.is_empty() else "; not indexed: %s" % str(missing),
			"" if stray.is_empty() else "; no file: %s" % str(stray),
			"" if doubled.is_empty() else "; twice: %s" % str(doubled)],
		missing.is_empty() and stray.is_empty() and doubled.is_empty()
			and files.size() == indexed.size())
	var bad: Array[String] = []
	for organ: Gene in _organs():
		for tag: StringName in organ.tags:
			if not Gene.TAGS.has(tag):
				bad.append("%s's tag %s" % [organ.organ, tag])
		if organ.channel != &"" and not Gene.CHANNELS.has(organ.channel):
			bad.append("%s's channel %s" % [organ.organ, organ.channel])
		for entry: Dictionary in organ.variants:
			var forms: Dictionary = entry.get("forms", {})
			# A variant of no forms is keyed by its own `key`; one of forms keys each.
			bad.append_array(_unknown_fields(organ.organ, entry,
				["variant", "dose", "forms"] + (["key"] if forms.is_empty() else [])))
			for place: Variant in forms:
				if StringName(place) != Gene.OUTSIDE and StringName(place) != Gene.INSIDE:
					bad.append("%s's place %s" % [organ.organ, place])
				if forms[place] is Dictionary:
					bad.append_array(_unknown_fields(organ.organ, forms[place], ["key"]))
	_check("every tag, channel, place and field a variant or form sets is one there is%s"
		% ("" if bad.is_empty() else ": not %s" % ", ".join(bad)),
		bad.is_empty() and Genome.OUTSIDE_PLACE == Gene.OUTSIDE
			and Genome.INSIDE_PLACE == Gene.INSIDE)


# --- The water (§9) ----------------------------------------------------------------------

## Every live gene has a weight in the water; every sense has a channel, and
## every gift is a sense.
func _water() -> void:
	var weightless: Array[StringName] = []
	for key: StringName in Catalogue.live():
		if Catalogue.variety(key) != key:
			continue
		var weight: Variant = Catalogue.gene(key).water.get("weight")
		if weight == null or int(weight) < 1:
			weightless.append(key)
	_check("every live variety has a weight of its own in the water%s"
		% ("" if weightless.is_empty() else ": not %s" % str(weightless)),
		weightless.is_empty())
	var drifters_ok := true
	for key: StringName in Catalogue.drifters():
		drifters_ok = drifters_ok and Catalogue.variety(key) == key \
			and not Catalogue.provides(key, &"gape")
	_check("a drifter may be made of %d genes, every one a variety and none a mouth: %s"
		% [Catalogue.drifters().size(), str(Catalogue.drifters())], drifters_ok
		and not Catalogue.drifters().is_empty())
	var deaf: Array[StringName] = []
	for key: StringName in Catalogue.tagged(Catalogue.SENSE):
		if Catalogue.channel_of(key) == &"":
			deaf.append(key)
	_check("every sense is tagged with the channel it drives: %s%s"
		% [str(Catalogue.tagged(Catalogue.SENSE)),
			"" if deaf.is_empty() else "; none for %s" % str(deaf)],
		deaf.is_empty() and not Catalogue.tagged(Catalogue.SENSE).is_empty())
	var not_senses: Array[StringName] = []
	for key: StringName in Catalogue.tagged(Catalogue.GIFT):
		if not Catalogue.has_tag(key, Catalogue.SENSE):
			not_senses.append(key)
	_check("every gift gene is a sense: %s%s" % [str(Catalogue.tagged(Catalogue.GIFT)),
		"" if not_senses.is_empty() else "; not %s" % str(not_senses)],
		not_senses.is_empty() and not Catalogue.tagged(Catalogue.GIFT).is_empty())
	var born_ok := not Catalogue.born().is_empty()
	for key: StringName in Catalogue.born():
		var copies := int(Catalogue.born()[key])
		born_ok = born_ok and copies >= 1 and copies <= Genome.TIER_MAX
	_check("a born cell wears %s, one to %d copies each, in order %s"
		% [str(Catalogue.born()), Genome.TIER_MAX, str(Catalogue.born_order())],
		born_ok and Array(Catalogue.born_order()) == Catalogue.born().keys())
	var moved: Array[String] = []
	for list: StringName in SHIPPED_LISTS:
		var shipped: Array = SHIPPED_LISTS[list]
		var now := _listed(list)
		if now.slice(0, shipped.size()) != shipped:
			moved.append("%s is %s" % [list, str(now)])
	_check("the drifters, the senses, the gift and the genes that declare parts come in the"
		+ " order they shipped, any new one after them%s" % ("" if moved.is_empty()
			else ": %s" % "; ".join(moved)), moved.is_empty())


## [param list] of [constant SHIPPED_LISTS] as the catalogue has it now.
func _listed(list: StringName) -> Array:
	match list:
		&"drifter":
			return Array(Catalogue.drifters())
		&"sense":
			return Array(Catalogue.tagged(Catalogue.SENSE))
		&"gift":
			return Array(Catalogue.tagged(Catalogue.GIFT))
		&"declares":
			return Catalogue.declares().keys()
	return []


# --- The stats (§5.1, §12.1) ---------------------------------------------------------------

## Every table `TIER_MAX + 1` finite entries, index 0 the stat's value with no
## provider, every stat provided of a row there is, and every row provided.
func _tables() -> void:
	var bad: Array[String] = []
	var tables := 0
	for key: StringName in Catalogue.keys():
		var record := Catalogue.gene(key)
		for stat: StringName in record.provides:
			tables += 1
			if not Stats.ROWS.has(stat):
				bad.append("%s's %s has no row" % [key, stat])
				continue
			var table: Array = record.provides[stat]
			if table.size() != Genome.TIER_MAX + 1:
				bad.append("%s's %s has %d entries" % [key, stat, table.size()])
				continue
			if float(table[0]) != Stats.none(stat):
				bad.append("%s's %s starts at %s, not %s" % [key, stat, str(table[0]),
					str(Stats.none(stat))])
			for at: Variant in table:
				var number := typeof(at) == TYPE_FLOAT or typeof(at) == TYPE_INT
				if not number or not is_finite(float(at)):
					bad.append("%s's %s holds %s" % [key, stat, str(at)])
	# **A stat whose every provider retired is still a stat** (§4.4): a body reads
	# it at its value with no provider, which retiring the organ asks for. A row
	# nothing ever provided is a mistake.
	var unprovided: Array[StringName] = []
	var retired_only: Array[String] = []
	for stat: StringName in Stats.ROWS:
		if not Catalogue.providers(stat).is_empty():
			continue
		var retired: Array[StringName] = []
		for key: StringName in Catalogue.tagged(Catalogue.RETIRED):
			if Catalogue.provides(key, stat):
				retired.append(key)
		if retired.is_empty():
			unprovided.append(stat)
		else:
			retired_only.append("%s (%s)" % [stat, ", ".join(retired)])
	_check(("every one of the %d tables has %d finite entries, the first its stat's value"
		+ " with no provider, and every one of the %d stats a provider, live or retired%s%s")
		% [tables, Genome.TIER_MAX + 1, Stats.ROWS.size(),
			"" if bad.is_empty() else ": " + "; ".join(bad),
			"" if unprovided.is_empty() else "; none ever for %s" % str(unprovided)],
		bad.is_empty() and unprovided.is_empty() and tables > 0)
	print("[gene-probe] NOTE stats only retired organs provide, read at their value with no"
		+ " provider: %s" % (", ".join(retired_only) if not retired_only.is_empty() else "none"))
	var rows_bad: Array[String] = []
	for stat: StringName in Stats.ROWS:
		var row: Dictionary = Stats.ROWS[stat]
		var better: StringName = row.get("better", &"")
		var combine: StringName = row.get("combine", &"")
		if better != Stats.HIGHER and better != Stats.LOWER:
			rows_bad.append("%s is better %s" % [stat, better])
		if combine == Stats.SUM and Stats.none(stat) != 0.0 \
				or combine == Stats.PRODUCT and Stats.none(stat) != 1.0 \
				or not [Stats.BEST, Stats.SUM, Stats.PRODUCT].has(combine):
			rows_bad.append("%s combines by %s from %s" % [stat, combine, str(row.get("none"))])
		if not row.has("unit") or not row.has("judged"):
			rows_bad.append("%s has no unit or no judged" % stat)
	_check(("every row says which way is better, how providers combine -- a sum from 0, a"
		+ " product from 1 -- its unit and whether the referee judges it; judged: %s%s")
		% [str(Stats.judged()), "" if rows_bad.is_empty() else ": " + "; ".join(rows_bad)],
		rows_bad.is_empty())
	# One provider each today, so every combine rule gives the table's own number.
	var crowded: Array[StringName] = []
	for stat: StringName in Stats.ROWS:
		if Catalogue.providers(stat).size() > 1:
			crowded.append(stat)
	print("[gene-probe] NOTE stats with more than one provider, combined by their rows: %s"
		% (str(crowded) if not crowded.is_empty() else "none"))


# --- The rules (§9, §12.1 cross-checks) --------------------------------------------------

## Every part the founders' rules name is declared, by the body, the metabolism
## or a gene.
func _rules() -> void:
	var vocab: Rulebook.Vocabulary = Rulebook.vocabulary([CellBody.DECLARES,
		Metabolism.DECLARES, Catalogue.declares()])
	var named := 0
	var unknown: Array[String] = []
	for line: String in Drop.FOUNDERS:
		for word: String in line.split(" ", false):
			# A part is `owner.name`; a test's value -- `0.3` -- is a number.
			if not word.contains(".") or word.is_valid_float():
				continue
			named += 1
			if not vocab.inputs.has(StringName(word)) and not vocab.outputs.has(StringName(word)):
				unknown.append(word)
	_check("every one of the %d parts the founders' %d rules name is declared%s"
		% [named, Drop.FOUNDERS.size(), "" if unknown.is_empty() else ": not %s" % str(unknown)],
		unknown.is_empty() and named > 0)
	var declarers: Array[StringName] = []
	declarers.assign(Catalogue.declares().keys())
	var levelled_ok := true
	for key: StringName in Catalogue.declares():
		var parts: Dictionary = Catalogue.declares()[key]
		for side: String in ["in", "out"]:
			for one: Dictionary in parts.get(side, []):
				levelled_ok = levelled_ok and int(one.get("level", 1)) >= 1 \
					and int(one.get("level", 1)) <= Genome.TIER_MAX
	var shipped: Array = SHIPPED_LISTS[&"declares"]
	_check("the genes declare parts in their shipped order, each at a level a gene reaches: %s"
		% str(declarers), levelled_ok
		and Array(declarers).slice(0, shipped.size()) == shipped)


## **Every part a gene declares is wired, in a water cell and in yours** (§12.1):
## an input has a reader in the water (`food.gd`'s `_wire`) and one of the
## player's (`own_rules.gd`'s `setup`), and an output a trigger in each. A part
## with none is a rule that names it and reads nothing, or does nothing, in one
## body and not the other, and says so nowhere. Then an organ that declares a
## part nothing wires is registered, to show this check fails on one.
func _wiring() -> void:
	var field: Node = FoodField.new()
	field.call(&"_wire")
	var cell: Node = CellBody.new()
	var metabolism: Node = Metabolism.new()
	var genome: Node = Genome.new()
	var own: RefCounted = OwnRules.new()
	own.call(&"setup", cell, field, metabolism, genome)
	var parts: Array[StringName] = []
	var unwired := _unwired(field, own, parts)
	_check("every one of the %d parts the genes declare is read, or performed, by a water"
		% parts.size() + " cell and by yours: %s%s" % [str(parts), "" if unwired.is_empty()
			else "; %s" % ", ".join(unwired)], unwired.is_empty() and not parts.is_empty())
	var organ := Gene.new()
	organ.organ = &"probewired"
	organ.declares = {"in": [{"name": &"glow", "bearing": false,
		"values": {&"level": &"level"}}], "out": [{"name": &"blink", "claims": [&"blink"]}]}
	Catalogue.register(organ)
	var caught := _unwired(field, own, [] as Array[StringName])
	Catalogue.forget(&"probewired")
	_check("and an organ declaring an input and an output nothing wires is caught on both"
		+ " sides: %s" % ", ".join(caught), caught.size() == 4
		and caught.all(func(line: String) -> bool: return line.begins_with("probewired.")))
	for node: Node in [field, cell, metabolism, genome]:
		node.free()


## What of the genes' declared parts [param field] (a water cell's) and
## [param own] (yours) leave unwired, one line each; the parts looked at are
## appended to [param parts].
func _unwired(field: Node, own: RefCounted, parts: Array[StringName]) -> Array[String]:
	var water_readers: Dictionary = field.get("_readers")
	var your_readers: Dictionary = own.get("_readers")
	var your_triggers: Dictionary = own.get("_triggers")
	var out: Array[String] = []
	var declares := Catalogue.declares()
	for key: StringName in declares:
		var declared: Dictionary = declares[key]
		for one: Dictionary in declared.get("in", []):
			var part := StringName("%s.%s" % [key, one["name"]])
			parts.append(part)
			if not water_readers.has(part):
				out.append("%s has no reader in the water" % part)
			if not your_readers.has(part):
				out.append("%s has no reader of yours" % part)
		for one: Dictionary in declared.get("out", []):
			var part := StringName("%s.%s" % [key, one["name"]])
			parts.append(part)
			if not (field.call(&"trigger", part) as Callable).is_valid():
				out.append("%s has no trigger in the water" % part)
			if not your_triggers.has(part):
				out.append("%s has no trigger of yours" % part)
	return out


# --- What the mechanics ask of an organ (§5.2, §5.3) ---------------------------------------

## Every organ a mechanic finds by its stat answers what that mechanic asks of
## it: every stat of the group it reads together ([constant TOGETHER]), the tail
## its hold level, the dart its stun, the beam its shape, its price and its
## levels. Then an organ that calls with no period is registered, to show this
## fails on one -- and that the referee holds it to a rate all the same.
func _mechanics() -> void:
	var missing := _unanswered()
	for key: StringName in Catalogue.levelled():
		var levels := Catalogue.levels(key)
		if float(levels.get("step", 0.0)) <= 0.0 or int(levels.get("fork", -1)) < 0 \
				or typeof(levels.get("paths")) != TYPE_ARRAY:
			missing.append("%s's levels %s" % [key, str(levels)])
		elif Catalogue.upkeep_at(key, 2, &"") < 0.0:
			missing.append("%s's price per level" % key)
	_check(("every organ a mechanic finds by its stat answers it: all of the %d groups of"
		% TOGETHER.size() + " stats it reads together, the tail its hold level, the dart its"
		+ " stun, the beam its shape, xp cap and price, every levelled gene its levels%s")
		% ("" if missing.is_empty() else ": not " + ", ".join(missing)),
		missing.is_empty() and not Catalogue.levelled().is_empty())
	var mouth := Catalogue.first_provider(&"gape")
	_check("the mouth -- what provides a gape, %s -- is always expressed and never drifts"
		% mouth, mouth != &"" and Catalogue.has_tag(mouth, Catalogue.ALWAYS_EXPRESSED)
		and Catalogue.has_tag(mouth, Catalogue.NEVER_DRIFTS) and Catalogue.born().has(mouth))
	# An organ that calls and gives no period: caught, and the referee -- which
	# divides by the period -- still holds a guest wearing it to a rate.
	var organ := Gene.new()
	organ.organ = &"probecall"
	organ.provides = {&"ping_range": [0.0, 900.0, 900.0, 900.0]}
	Catalogue.register(organ)
	var caught := _unanswered()
	var rate := Referee._shout_rate({&"probecall": 2})
	Catalogue.forget(&"probecall")
	_check(("and an organ that calls with no period of its own is caught -- %s -- and held"
		+ " to %.4f calls a second, not divided by nothing") % [", ".join(caught), rate],
		caught.has("probecall's ping_period") and caught.has("probecall's ping_through")
		and is_finite(rate) and rate > 0.0 and rate <= 1.0)


## What the organs providing each stat leave unanswered of what a mechanic asks,
## one line each: a stat of a group ([constant TOGETHER]) missing, or a number
## or hook of the organ's own.
func _unanswered() -> Array[String]:
	var missing: Array[String] = []
	for group: Array in TOGETHER:
		for stat: StringName in group:
			for key: StringName in Catalogue.providers(stat):
				for other: StringName in group:
					if not Catalogue.provides(key, other) \
							and not missing.has("%s's %s" % [key, other]):
						missing.append("%s's %s" % [key, other])
	for key: StringName in Catalogue.providers(&"impulse_speed"):
		if Catalogue.number(key, &"hold_level") == null:
			missing.append("%s's hold_level" % key)
	for key: StringName in Catalogue.providers(&"dart_range"):
		if Catalogue.number(key, &"stun") == null:
			missing.append("%s's stun" % key)
	for key: StringName in Catalogue.providers(&"beam_range"):
		if not Catalogue.gene(key).has_method(&"shape_at"):
			missing.append("%s's shape_at" % key)
		if Catalogue.number(key, &"xp_cap") == null:
			missing.append("%s's xp_cap" % key)
	return missing


# --- A gene registered and forgotten (§4.3) -------------------------------------------------

## A synthetic organ with one variant in two places, filed and taken back: its
## forms answer as the toxin's do, and the catalogue is as it was after.
func _register() -> void:
	var before := Array(Catalogue.keys())
	var organ := Gene.new()
	organ.organ = &"probeorgan"
	organ.tags = [Catalogue.ALWAYS_EXPRESSED]
	organ.variants = [{"variant": &"plain", "dose": &"harm",
		"water": {"weight": 1, "drifter": false}, "tags": [Catalogue.NEVER_DRIFTS],
		"forms": {Gene.INSIDE: {"key": &"probein", "order": 900},
			Gene.OUTSIDE: {"key": &"probeout", "order": 901, "tags": [Catalogue.SENSE],
				"provides": {&"armor": [1.0, 1.25, 1.25, 1.25]}}}}]
	var bare := Stats.of({&"probeout": 1}, &"armor")
	Catalogue.register(organ)
	# Read through stats.gd, which holds the catalogue's dictionary: the new
	# organ's armour at once, and a second provider combined by the row's rule.
	var read := [Stats.of({&"probeout": 1}, &"armor"),
		Stats.of({&"pellicle": 1, &"probeout": 1}, &"armor")]
	var filed := Catalogue.known(&"probein") and Catalogue.known(&"probeout") \
		and Catalogue.has_forms(&"probein") and Catalogue.variety(&"probeout") == &"probein" \
		and Catalogue.form_in(&"probein", Gene.OUTSIDE) == &"probeout" \
		and Catalogue.form_in(&"probeout", Gene.INSIDE) == &"probein" \
		and Genome.is_inside_form(&"probein") and not Genome.is_inside_form(&"probeout") \
		and Catalogue.dose_of(&"probeout") == &"harm" and Catalogue.rank(&"probeout") == 901 \
		and Catalogue.provides(&"probeout", &"armor") \
		and not Catalogue.provides(&"probein", &"armor") \
		and Catalogue.weight(&"probeout") == 1 and not Catalogue.drifters().has(&"probein")
	# **Tags add up** (gene.gd): the organ's on both forms, the variant's on both,
	# the outside form's on it alone.
	var tags := [Catalogue.gene(&"probeout").tags, Catalogue.gene(&"probein").tags]
	var added := Catalogue.has_tag(&"probeout", Catalogue.ALWAYS_EXPRESSED) \
		and Catalogue.has_tag(&"probeout", Catalogue.NEVER_DRIFTS) \
		and Catalogue.has_tag(&"probeout", Catalogue.SENSE) \
		and Catalogue.has_tag(&"probein", Catalogue.ALWAYS_EXPRESSED) \
		and Catalogue.has_tag(&"probein", Catalogue.NEVER_DRIFTS) \
		and not Catalogue.has_tag(&"probein", Catalogue.SENSE)
	Catalogue.forget(&"probeorgan")
	read.append(Stats.of({&"probeout": 1}, &"armor"))
	_check(("a registered organ's two forms answer as the toxin's do, and forgetting it leaves"
		+ " the catalogue as it was; its armour reads through the stats at once -- %s alone,"
		+ " %s beside a pellicle, %s again once forgotten (%s before)") % [read[0], read[1],
		read[2], bare], filed and Array(Catalogue.keys()) == before
		and not Catalogue.known(&"probein") and bare == 1.0 and read[0] == 1.25
		and is_equal_approx(read[1], 1.14 * 1.25) and read[2] == 1.0)
	_check("and a variant's and a form's tags add to their organ's, never replace them:"
		+ " outside %s, inside %s" % [str(tags[0]), str(tags[1])], added)
	# **A variant with no forms is one entry** (gene.gd): filed outside under its
	# own key, or its name -- the organ as it shipped and a faster one beside it.
	var tail := Gene.new()
	tail.organ = &"probetail"
	tail.provides = {&"armor": [1.0, 1.1, 1.1, 1.1]}
	tail.variants = [{"variant": &"plain", "key": &"probetail"},
		{"variant": &"probeswift", "provides": {&"armor": [1.0, 1.5, 1.5, 1.5]}}]
	Catalogue.register(tail)
	var one_each := true
	for key: StringName in [&"probetail", &"probeswift"]:
		one_each = one_each and Catalogue.known(key) and Catalogue.place_of(key) == Gene.OUTSIDE \
			and Catalogue.variety(key) == key and not Catalogue.has_forms(key) \
			and Catalogue.form_in(key, Gene.OUTSIDE) == key \
			and Catalogue.form_in(key, Gene.INSIDE) == &"" and not Genome.is_inside_form(key)
	var armours := [Stats.of({&"probetail": 1}, &"armor"), Stats.of({&"probeswift": 1}, &"armor")]
	var filed_keys := _keys_of(tail)
	Catalogue.forget(&"probetail")
	_check(("and a variant with no forms is one entry, outside, under its key or its name:"
		+ " %s, armour %s and %s") % [str(filed_keys), armours[0], armours[1]], one_each
		and filed_keys == [&"probetail", &"probeswift"] and armours == [1.1, 1.5]
		and Array(Catalogue.keys()) == before)


# --- Gene names left in code (§12.2) ----------------------------------------------------------

## **How many `&"<key>"` literals are left in game/ outside game/genes/**, comments
## aside: what phase 5's gate will fail on. A number, not a failure, until then.
func _names_left() -> void:
	var found := {}
	var total := 0
	for path: String in _scripts_in(GAME_DIR):
		if path.begins_with(GENES_DIR + "/"):
			continue
		var text := FileAccess.get_file_as_string(path)
		var here := 0
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for key: StringName in Catalogue.keys():
				here += line.count('&"%s"' % key)
		if here > 0:
			found[path.trim_prefix(GAME_DIR + "/")] = here
			total += here
	var files: Array = found.keys()
	files.sort_custom(func(a: String, b: String) -> bool:
		return int(found[a]) > int(found[b]) or (found[a] == found[b] and a < b))
	var parts := PackedStringArray()
	for path: String in files:
		parts.append("%s %d" % [path, int(found[path])])
	print("[gene-probe] NOTE %d &\"<key>\" literals left in game/ outside game/genes/, in %d"
		% [total, files.size()] + " files: " + ", ".join(parts))


# --- Helpers ----------------------------------------------------------------------------------

## A fresh instance of every organ file the index lists.
func _organs() -> Array[Gene]:
	var out: Array[Gene] = []
	for script: GDScript in Catalogue.ORGANS:
		out.append(script.new())
	return out


## The keys [param organ]'s file says its forms are, as the catalogue resolves
## them: its own name for an organ of one form, and a variant's own key -- or its
## name -- for a variant of none. `&""` for a variant with none of the three,
## which the catalogue cannot file, so that the count of forms says so.
static func _keys_of(organ: Gene) -> Array[StringName]:
	var out: Array[StringName] = []
	if organ.variants.is_empty():
		out.append(organ.organ)
		return out
	for entry: Dictionary in organ.variants:
		var forms: Dictionary = entry.get("forms", {})
		if forms.is_empty():
			out.append(StringName(entry.get("key", entry.get("variant", &""))))
			continue
		for place: Variant in forms:
			var form: Variant = forms[place]
			out.append(StringName((form as Dictionary).get("key", &"")) if form is Dictionary
				else StringName(form))
	return out


## The fields of [param fields] a variant or form may not set, by [param organ]'s
## name; [param own] are the entry's own words.
static func _unknown_fields(organ: StringName, fields: Dictionary, own: Array) -> Array[String]:
	var out: Array[String] = []
	for field: Variant in fields:
		if not own.has(String(field)) and not Catalogue.OVERRIDES.has(String(field)):
			out.append("%s's field %s" % [organ, field])
	return out


## Every `.gd` file under [param dir], in order.
static func _scripts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + "/" + file)
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir + "/" + sub))
	return out
