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
## founders' parts and the gift, the index against the folder, a gene registered
## and forgotten, and -- a number, not yet a failure (§12.2) -- how many gene
## names are still written into game/ outside game/genes/.
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
const Drop := preload("res://game/normal/drop.gd")
const Rulebook := preload("res://game/mechanics/rulebook.gd")
const Wire := preload("res://game/net/wire.gd")

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
	_check("keys() is the order, today's GENE_ORDER, then the placeless: %s"
		% str(Catalogue.keys()), order == SHIPPED
		and Array(Catalogue.live()) == Array(SHIPPED))
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
	for name: String in DirAccess.get_files_at(ORGANS_DIR):
		if name.ends_with(".gd"):
			files.append(name)
	var missing := files.filter(func(name: String) -> bool: return not indexed.has(name))
	var stray := indexed.filter(func(name: String) -> bool: return not files.has(name))
	var doubled := indexed.filter(func(name: String) -> bool: return indexed.count(name) > 1)
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
			bad.append_array(_unknown_fields(organ.organ, entry, ["variant", "dose", "forms"]))
			var forms: Dictionary = entry.get("forms", {})
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
	var unprovided: Array[StringName] = []
	for stat: StringName in Stats.ROWS:
		if Catalogue.providers(stat).is_empty():
			unprovided.append(stat)
	_check(("every one of the %d tables has %d finite entries, the first its stat's value"
		+ " with no provider, and every one of the %d stats a provider%s%s") % [tables,
			Genome.TIER_MAX + 1, Stats.ROWS.size(),
			"" if bad.is_empty() else ": " + "; ".join(bad),
			"" if unprovided.is_empty() else "; none for %s" % str(unprovided)],
		bad.is_empty() and unprovided.is_empty() and tables > 0)
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
	_check("the genes declare parts in their shipped order, each at a level a gene reaches: %s"
		% str(declarers), levelled_ok
		and declarers.slice(0, 8) == [&"ocellus", &"ampulla", &"chemocyte", &"stigma",
			&"palp", &"myoneme", &"axoneme", &"flagellum"])


# --- What the mechanics ask of an organ (§5.2, §5.3) ---------------------------------------

## Every organ a mechanic finds by its stat answers what that mechanic asks of
## it: the tail its hold level, the dart its stun, the beam its shape, its price
## and its levels.
func _mechanics() -> void:
	var missing: Array[String] = []
	for key: StringName in Catalogue.providers(&"impulse_speed"):
		if Catalogue.number(key, &"hold_level") == null:
			missing.append("%s's hold_level" % key)
	for key: StringName in Catalogue.providers(&"dart_range"):
		if Catalogue.number(key, &"stun") == null:
			missing.append("%s's stun" % key)
	for key: StringName in Catalogue.providers(&"beam_range"):
		var organ := Catalogue.gene(key)
		if not organ.has_method(&"shape_at"):
			missing.append("%s's shape_at" % key)
		if Catalogue.number(key, &"xp_cap") == null:
			missing.append("%s's xp_cap" % key)
		for stat: StringName in [&"beam_count", &"beam_fan_deg"]:
			if not Catalogue.provides(key, stat):
				missing.append("%s's %s" % [key, stat])
	for key: StringName in Catalogue.levelled():
		var levels := Catalogue.levels(key)
		if float(levels.get("step", 0.0)) <= 0.0 or int(levels.get("fork", -1)) < 0 \
				or typeof(levels.get("paths")) != TYPE_ARRAY:
			missing.append("%s's levels %s" % [key, str(levels)])
		elif Catalogue.upkeep_at(key, 2, &"") < 0.0:
			missing.append("%s's price per level" % key)
	_check(("every organ a mechanic finds by its stat answers it: the tail its hold level,"
		+ " the dart its stun, the beam its shape, xp cap and price, every levelled gene its"
		+ " levels%s") % ("" if missing.is_empty() else ": not " + ", ".join(missing)),
		missing.is_empty() and not Catalogue.levelled().is_empty())
	var mouth := Catalogue.first_provider(&"gape")
	_check("the mouth -- what provides a gape, %s -- is always expressed and never drifts"
		% mouth, mouth != &"" and Catalogue.has_tag(mouth, Catalogue.ALWAYS_EXPRESSED)
		and Catalogue.has_tag(mouth, Catalogue.NEVER_DRIFTS) and Catalogue.born().has(mouth))


# --- A gene registered and forgotten (§4.3) -------------------------------------------------

## A synthetic organ with one variant in two places, filed and taken back: its
## forms answer as the toxin's do, and the catalogue is as it was after.
func _register() -> void:
	var before := Array(Catalogue.keys())
	var organ := Gene.new()
	organ.organ = &"probeorgan"
	organ.variants = [{"variant": &"plain", "dose": &"harm",
		"water": {"weight": 1, "drifter": false},
		"forms": {Gene.INSIDE: {"key": &"probein", "order": 900},
			Gene.OUTSIDE: {"key": &"probeout", "order": 901,
				"provides": {&"armor": [1.0, 1.0, 1.0, 1.0]}}}}]
	Catalogue.register(organ)
	var filed := Catalogue.known(&"probein") and Catalogue.known(&"probeout") \
		and Catalogue.has_forms(&"probein") and Catalogue.variety(&"probeout") == &"probein" \
		and Catalogue.form_in(&"probein", Gene.OUTSIDE) == &"probeout" \
		and Catalogue.form_in(&"probeout", Gene.INSIDE) == &"probein" \
		and Genome.is_inside_form(&"probein") and not Genome.is_inside_form(&"probeout") \
		and Catalogue.dose_of(&"probeout") == &"harm" and Catalogue.rank(&"probeout") == 901 \
		and Catalogue.provides(&"probeout", &"armor") \
		and not Catalogue.provides(&"probein", &"armor") \
		and Catalogue.weight(&"probeout") == 1 and not Catalogue.drifters().has(&"probein")
	Catalogue.forget(&"probeorgan")
	_check("a registered organ's two forms answer as the toxin's do, and forgetting it leaves"
		+ " the catalogue as it was", filed and Array(Catalogue.keys()) == before
		and not Catalogue.known(&"probein"))


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
## them: its own name for an organ of one form.
static func _keys_of(organ: Gene) -> Array[StringName]:
	var out: Array[StringName] = []
	if organ.variants.is_empty():
		out.append(organ.organ)
		return out
	for entry: Dictionary in organ.variants:
		var forms: Dictionary = entry.get("forms", {})
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
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir + "/" + name)
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir + "/" + sub))
	return out
