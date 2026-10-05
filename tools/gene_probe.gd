extends Node
## CI probe: **the genes, as data** (docs/design/gene-catalogue.md §12.1). Every
## gene's numbers, lists, tags, rules, look and words live in its organ's file under
## game/genes/organs/, and everything that reads one asks the catalogue. What a
## render cannot show is a gene that is half there: a key the wire refuses, a
## table one entry short, a live gene with no weight in the water, a sense no
## channel carries, an organ file the index forgot. Each of those works alone and
## fails somewhere else -- in a shared pond, a seeded water, a save -- so it fails
## here first.
##
## **Static, and a few seconds**: it reads the catalogue and the files, and plays
## nothing. What it checks (§15): the keys -- names the wire carries, one form's
## each, in their shipped order, organ and variant names their own; the index
## against the folder, and every tag, channel, place and field one there is; the
## water's weights, drifters, senses, gift and born cell, and the lists a draw or
## a bit reads in their shipped order; every stat table's length and first entry,
## every row, and a provider for every stat, live or retired; the founders' parts
## declared, and every declared part wired in a water cell and in yours; what each
## mechanic asks of the organ it finds by a stat; and organs registered and
## forgotten -- forms, tags that add up, variants of no forms, an organ that calls
## with no period, a part nothing wires, a look drawn at once. Then what a gene
## looks like and says (§7.1, §8): every live gene's look, its words and its
## parts' words, no word table naming what is not its organ's, its numbers on the
## pause screen, and the colours -- no two hues nearer than today's floor, none on
## self teal or threat red, and every copy of a hue its organ's. Then the body plan
## (§10, §12.1): ids unique and none a save before stamps kept forgotten, arcs that
## do not overlap, radii that only rise to the divide, a home for each born organ,
## the copies of its counts and the wire's limits its own, room on the pause figure
## -- each shown failing a plan that breaks it -- and today's plan held to the one
## that shipped; and a plan of the probe's own put through a cell's file and a
## world's, the genome, the wire and the figure, and taken out again (§12.3). And
## -- numbers, not yet failures (§8.3, §12.2) -- the gene words with no French, and
## how many gene names are still written into game/ outside game/genes/.
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
const GeneStats := preload("res://game/normal/gene_stats.gd")
const Doses := preload("res://game/mechanics/doses.gd")
## The views that draw a gene's hue, or keep one: what the colour checks read.
const Cilia := preload("res://game/vision/cilia.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
const Controls := preload("res://game/normal/controls.gd")
const Earshot := preload("res://game/net/earshot.gd")
## **The body plan** (gene-catalogue.md §10), and what lays it out and keeps it: the
## pause figure, a cell's file and a world's, and the daughters a division offers as
## a file keeps them.
const BodyPlan := preload("res://game/genes/body_plan.gd")
const Figure := preload("res://game/normal/figure.gd")
const DropSave := preload("res://game/normal/drop_save.gd")
const CellSave := preload("res://game/normal/cell_save.gd")
const NormalMode := preload("res://game/normal/normal_mode.gd")

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
## joins**, and the probe fails until it has; a gene leaving one -- retired, say
## -- changes every seeded draw, and is the commit that updates this.
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

## **What a look may hold today** (gene.gd's `look`): phase 6 adds a kind's
## parameters, and this list with them.
const LOOK_FIELDS: Array[String] = ["shape", "hue", "count", "tile_count", "tile_length"]
## **The colours as they are** (§12.1), as HSV hue in degrees (`Color.h`): no two
## genes' hues nearer than [constant HUE_FLOOR_DEG] -- today's narrowest gap but the
## pairs below, `cirrus` and `vacuole`'s 10.2, rounded down -- and none within
## [constant CLEAR_DEG] of self teal (`Cilia.SELF_TINT`) or threat red
## (`Cilia.PREDATOR_TINT`), the two colours whose meaning is a relationship. Two
## forms of one strain are one colour on purpose, and are one hue here.
const HUE_FLOOR_DEG := 10.0
const CLEAR_DEG := 25.0
## **The pairs that already break those rules**, two genes or a gene and `teal` or
## `red`: kept as they are until phase 6, whose families replace both rules
## (gene-looks.md §8). Nothing is added here to let a new gene through.
const KEPT_UNTIL_FAMILIES: Array = [
	[&"palp", &"crista"], [&"stigma", &"plastid"], [&"flagellum", &"trichocyst"],
	[&"pellicle", &"teal"], [&"myoneme", &"red"],
]
## The game's French, whose missing gene words are listed (§8.3).
const FRENCH := "res://game/i18n/fr.po"
## **The template every translation starts from** (§8.2): a word the catalogue hands
## out that is not in it reaches no translator, and ships in English for good.
const TEMPLATE := "res://game/i18n/biogenic.pot"

## The folder the index must match, file for file.
const ORGANS_DIR := "res://game/genes/organs"
## Where the gene names left in code are counted (§12.2), and what is exempt.
const GAME_DIR := "res://game"
const GENES_DIR := "res://game/genes"

## **The body plan as it shipped before it was data** (§10.1): `cell.gd`'s ladder --
## three slots at r26, one more every 3.5, seven at most -- `cilia.gd`'s arcs,
## genome.gd's front and stern, and the ring the pause figure had written out. Phase
## 2 derives every one of them from `body_plan.gd`, and this holds today's plan to
## them, so the move changed nothing. **A plan change fails it on purpose**: the rows
## and these move in the same commit, as a new gene appends to [constant SHIPPED].
const SHIPPED_LADDER := {"base": 26.0, "step": 3.5, "fewest": 3, "most": 7}
const SHIPPED_ARCS: Array[Vector2] = [Vector2(-42.0, 42.0), Vector2(66.0, 118.0),
	Vector2(146.0, 214.0), Vector2(42.0, 66.0), Vector2(-66.0, -42.0),
	Vector2(118.0, 146.0), Vector2(-146.0, -118.0)]
const SHIPPED_FRONT: Array[int] = [0, 3, 4]
const SHIPPED_STERN := 2
const SHIPPED_SEATS: Array[Vector2] = [Vector2(0.0, -138.0), Vector2(150.0, 0.0),
	Vector2(0.0, 168.0), Vector2(150.0, -138.0), Vector2(-150.0, -138.0),
	Vector2(150.0, 168.0), Vector2(-150.0, 168.0), Vector2(0.0, 6.0)]
const SHIPPED_NEIGHBOURS: Array = [[4, -1, 3, 7], [7, 3, -1, 5], [6, 7, 5, -1],
	[0, -1, -1, 1], [-1, -1, 0, 6], [2, 1, -1, -1], [-1, 4, 2, -1], [-1, 0, 1, 2]]
const SHIPPED_RING: Array[int] = [0, 3, 1, 5, 2, 6, 4, 7]

## **A body plan of the probe's own** (§10.3, §12.3), swapped in and out as `register`
## and `forget` put an organ through: today's with **a slot moved** -- the rear
## starboard diagonal, four degrees narrower and one index forward -- **one removed**
## -- the forward port diagonal, retired -- and **two added**: the port flank, in the
## cell today's figure leaves empty, and a bow slot on the removed one's arc under an
## id of its own. Eight slots outside, so everything the plan sizes grows by one, and
## rungs that are not an even ladder.
const PLAN_TEST: Array[Dictionary] = [
	{"id": &"nose", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.FRONT_ANATOMY,
		"arc": Vector2(-42.0, 42.0), "earned": BodyPlan.ALWAYS, "home": &"cytostome"},
	{"id": &"starboard", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.SIDE_ANATOMY,
		"arc": Vector2(66.0, 118.0), "earned": BodyPlan.ALWAYS, "home": &"cirrus"},
	{"id": &"tail", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.STERN_ANATOMY,
		"arc": Vector2(146.0, 214.0), "earned": BodyPlan.ALWAYS, "home": &"flagellum"},
	{"id": &"fore_starboard", "place": BodyPlan.OUTSIDE_PLACE,
		"anatomy": BodyPlan.FRONT_ANATOMY, "arc": Vector2(42.0, 66.0), "earned": 29.5},
	{"id": &"aft_starboard", "place": BodyPlan.OUTSIDE_PLACE,
		"anatomy": BodyPlan.SIDE_ANATOMY, "arc": Vector2(122.0, 146.0), "earned": 31.0},
	{"id": &"port", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.SIDE_ANATOMY,
		"arc": Vector2(-110.0, -70.0), "earned": 34.0},
	{"id": &"aft_port", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.SIDE_ANATOMY,
		"arc": Vector2(-146.0, -118.0), "earned": 37.0},
	{"id": &"bow_port", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.FRONT_ANATOMY,
		"arc": Vector2(-66.0, -42.0), "earned": 40.0},
	{"id": &"inside", "place": BodyPlan.INSIDE_PLACE, "earned": BodyPlan.ALWAYS},
]
const PLAN_TEST_RETIRED: Array[Dictionary] = [
	{"id": &"fore_port", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.FRONT_ANATOMY,
		"arc": Vector2(-66.0, -42.0), "earned": 33.0},
]
## Where the files the probe keeps under one plan and reads under the other go.
const PLAN_FILES := "user://gene_probe_plan"

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
	_looks()
	_words()
	_template()
	_lines()
	_colours()
	_plan()
	_synthetic_plan()
	_untranslated()
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
			var variant := StringName(entry.get("variant", &""))
			if variants.has(variant):
				clashes.append("%s's variant %s twice" % [organ.organ, variant])
			variants[variant] = true
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
	# Every key as filed, so a variant's tags and a form's channel are held too.
	for key: StringName in Catalogue.keys():
		var record := Catalogue.gene(key)
		for tag: StringName in record.tags:
			if not Gene.TAGS.has(tag):
				bad.append("%s's tag %s" % [key, tag])
		if record.channel != &"" and not Gene.CHANNELS.has(record.channel):
			bad.append("%s's channel %s" % [key, record.channel])
	for organ: Gene in _organs():
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
		if now == shipped:
			continue
		if now.slice(0, shipped.size()) == shipped:
			moved.append("%s has %s after them: append it to SHIPPED_LISTS" % [list,
				str(now.slice(shipped.size()))])
		else:
			moved.append("%s is %s" % [list, str(now)])
	_check("the drifters, the senses, the gift and the genes that declare parts are the lists"
		+ " that shipped, in their order, and any gene that joins one appended to it here%s"
		% ("" if moved.is_empty() else ": %s" % "; ".join(moved)), moved.is_empty())


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
	# **Its look, drawn at once**: cilia.gd holds the catalogue's hues and shapes, which
	# every index fills in place, so a new organ's hue is there without a reload.
	organ.look = {"shape": Gene.TUFT, "hue": Color(0.10, 0.20, 0.30), "count": 3}
	var bare := Stats.of({&"probeout": 1}, &"armor")
	# **Beside the first live organ of armour** -- whichever it is, so that retiring
	# one is still its tag alone (§16) -- or alone, with none.
	var beside := Catalogue.first_provider(&"armor")
	var pair := {&"probeout": 1}
	if beside != &"":
		pair[beside] = 1
	var other := Stats.value(beside, &"armor", 1)
	Catalogue.register(organ)
	var drawn := [Cilia.hue(&"probeout"), Catalogue.shaped(Gene.TUFT).has(&"probeout")]
	# Read through stats.gd, which holds the catalogue's dictionary: the new
	# organ's armour at once, and a second provider combined by the row's rule.
	var read := [Stats.of({&"probeout": 1}, &"armor"), Stats.of(pair, &"armor")]
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
	drawn.append(Cilia.hue(&"probeout"))
	_check(("a registered organ's two forms answer as the toxin's do, and forgetting it leaves"
		+ " the catalogue as it was; its armour reads through the stats at once -- %s alone,"
		+ " %s beside %s, %s again once forgotten (%s before)") % [read[0], read[1],
		beside if beside != &"" else "nothing", read[2], bare], filed
		and Array(Catalogue.keys()) == before and not Catalogue.known(&"probein")
		and bare == 1.0 and read[0] == 1.25 and is_equal_approx(read[1], other * 1.25)
		and read[2] == 1.0)
	_check(("and its look is drawn at once, by the dictionaries cilia.gd holds: its hue %s"
		+ " while filed, a tuft among the tufts, and the reserved indigo once forgotten")
		% str(drawn[0]), drawn[0] == Color(0.10, 0.20, 0.30) and drawn[1]
		and drawn[2] == Cilia.RESERVED_HUES[0])
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


# --- Looks (§7.1) ----------------------------------------------------------------------------

## **Every live gene's look**: a shape there is, a hue, its strokes where its
## shape counts them and a home shape's tile, and nothing a look does not hold. A
## retired gene has none, so that it draws as a gene this build does not know.
func _looks() -> void:
	var bad: Array[String] = []
	var drawn: Array[StringName] = []
	drawn.append_array(Catalogue.live())
	# **A retired key's look may stay or go** (§16: retiring a gene is its tag and
	# nothing else): one that stays is still how a body wearing it is drawn, so it is
	# held as a live one's is.
	for key: StringName in Catalogue.tagged(Catalogue.RETIRED):
		if not Catalogue.look(key).is_empty():
			drawn.append(key)
	for key: StringName in drawn:
		var look := Catalogue.look(key)
		var shape := StringName(look.get("shape", &""))
		if not Gene.SHAPES.has(shape):
			bad.append("%s's shape %s" % [key, shape if shape != &"" else &"(none)"])
		if not look.get("hue") is Color:
			bad.append("%s's hue" % key)
		if Gene.COUNTED.has(shape) and not _counts(look.get("count")):
			bad.append("%s's count" % key)
		if Gene.HOME_SHAPES.has(shape) and not (_counts(look.get("tile_count"))
				and float(look.get("tile_length", 0.0)) > 0.0):
			bad.append("%s's tile" % key)
		for field: Variant in look:
			if not LOOK_FIELDS.has(String(field)):
				bad.append("%s's look field %s" % [key, field])
	var shapes := PackedStringArray()
	for shape: StringName in Gene.SHAPES:
		shapes.append("%s %d" % [shape, Catalogue.shaped(shape).size()])
	_check(("every live gene has a look -- a shape there is, a hue, its strokes where its shape"
		+ " counts them and a home shape's tile -- and so does every retired one that kept"
		+ " its look, %d of them: %s%s") % [drawn.size() - Catalogue.live().size(),
			", ".join(shapes), "" if bad.is_empty() else "; wrong: %s" % ", ".join(bad)],
		bad.is_empty())


# --- Words (§8.1) and lines (§8.4) -----------------------------------------------------------

## **Every live gene's words**: a chip word and its line; its word and line in
## hand where it is one form of several; every way's words where its levels fork;
## and for every part it declares, its word -- a sense's or an action's -- its
## line, and what an instinct says while the part waits for a level. And no word
## table in an organ's file is keyed by a key, a part or a way not its organ's:
## words for what nobody is, which nobody is shown.
func _words() -> void:
	var bad: Array[String] = []
	for key: StringName in Catalogue.live():
		var words := Catalogue.words(key)
		var needed: Array[StringName] = [&"word", &"explains"]
		if Catalogue.has_forms(key):
			needed.append_array([&"carried", &"carried_explains"] as Array[StringName])
		for name: StringName in needed:
			if not _said(words.get(name)):
				bad.append("%s's %s" % [key, name])
		for way: Variant in Catalogue.levels(key).get("paths", []):
			for name: StringName in [&"way_titles", &"way_says", &"paths"]:
				if not _said((words.get(name, {}) as Dictionary).get(way)):
					bad.append("%s's %s for %s" % [key, name, way])
			var two: Variant = (words.get(&"way_lines", {}) as Dictionary).get(way)
			if not (two is Array and (two as Array).size() == 2 and _said(two[0])
					and _said(two[1])):
				bad.append("%s's way_lines for %s" % [key, way])
	var parts := _declared_parts()
	for part: StringName in parts:
		var said := Catalogue.part_words(part)
		var decl: Dictionary = parts[part]
		var needed: Array[StringName] = [&"sense" if decl["side"] == "in" else &"says",
			&"explains"]
		if decl.has("level"):
			needed.append_array([&"asleep", &"needs"] as Array[StringName])
		for name: StringName in needed:
			if not _said(said.get(name)):
				bad.append("%s's %s" % [part, name])
	for organ: Gene in _organs():
		var tables := (organ.get_script() as GDScript).get_script_constant_map()
		var keys := _keys_of(organ)
		var ways: Array = []
		for key: StringName in keys:
			ways.append_array(Catalogue.levels(key).get("paths", []))
		var own := {}
		for part: StringName in parts:
			if keys.has(StringName(String(part).get_slice(".", 0))):
				own[part] = true
		for table: String in Catalogue.KEY_WORDS:
			for entry: Variant in _table(tables, table):
				if not keys.has(StringName(entry)):
					bad.append("%s's %s says %s, not one of its keys" % [organ.organ, table, entry])
				elif table == "EXPLAINS_PATH":
					for way: Variant in _table(tables[table], entry):
						if not ways.has(way):
							bad.append("%s's %s has a way %s it has not"
								% [organ.organ, table, way])
		for table: String in Catalogue.PART_WORDS:
			for entry: Variant in _table(tables, table):
				if not own.has(StringName(entry)):
					bad.append("%s's %s says %s, not a part it declares"
						% [organ.organ, table, entry])
		for table: String in Catalogue.WAY_WORDS:
			for entry: Variant in _table(tables, table):
				if not ways.has(entry):
					bad.append("%s's %s has a way %s it has not" % [organ.organ, table, entry])
	_check(("every live gene has its chip word and its line, its words in hand where it has"
		+ " forms and every way's where it forks, and every one of the %d parts the genes"
		+ " declare its word, its line and, waiting for a level, what it says; no word table"
		+ " is keyed by what is not its organ's%s") % [parts.size(),
			"" if bad.is_empty() else ": missing or stray: %s" % ", ".join(bad)], bad.is_empty())


## **Every word the catalogue hands out is in the template, and every live chip word
## fits its rooms** (§8.2, §8.3). The translation tool lists a word table only where
## it carries a TRANSLATORS note, and measures a word only against a ROOM line: a
## table with no note, or a note with no room, passed every check before this one.
## So every word of every key and every part is looked up in the template, under the
## context it is said in; and every live gene's chip word, in English and in French,
## is measured in the fallback font against the two places it is drawn -- the
## choosing screen's word block (`normal_mode.gd`'s `CHOOSE_BLOCK_W` less
## `CHOOSE_WORD_X`, at its `LABEL_SIZE`) and a chip, beside its three pips
## (`figure.gd`'s `SLOT_SIZE`, at `CHIP_WORD`).
func _template() -> void:
	var held := _template_ids()
	var said := {}
	for key: StringName in Catalogue.keys():
		var english: Array = []
		var words := Catalogue.words(key)
		for name: StringName in words:
			if name != &"name":
				_strings_into(english, words[name], "")
		for one: Array in english:
			said[one] = String(key)
	var parts := _declared_parts()
	for part: StringName in parts:
		var own := Catalogue.part_words(part)
		for name: StringName in own:
			var english: Array = []
			_strings_into(english, own[name], "sense" if name == &"sense" else "")
			for one: Array in english:
				said[one] = String(part)
	var missing: Array[String] = []
	for one: Array in said:
		var id := String(one[0]) if String(one[1]).is_empty() \
			else "%s\u0004%s" % [one[1], one[0]]
		if not held.has(id):
			missing.append("%s's \"%s\"" % [said[one], one[0]])
	_check(("every word the catalogue hands out, %d of them, is in the template, %d messages"
		+ " (%s)%s") % [said.size(), held.size(), TEMPLATE.get_file(),
			"" if missing.is_empty() else ": not there, so no translator sees it: "
			+ ", ".join(missing)], missing.is_empty() and not held.is_empty())
	var font := ThemeDB.fallback_font
	var block := NormalMode.CHOOSE_BLOCK_W - NormalMode.CHOOSE_WORD_X
	var beside := Figure.PIP_GAP + Figure.PIP_PITCH * float(Genome.TIER_MAX - 1) \
		+ Figure.PIP_R * 2.0
	if Figure.LEVEL_SEAT == Figure.LevelSeat.AFTER_PIPS:
		beside += Figure.LEVEL_AFTER_GAP + maxf(font.get_string_size("99",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, Figure.LEVEL_SIZE).x, font.get_string_size("999",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, Figure.LEVEL_SIZE_SMALL).x)
	var chip := Figure.SLOT_SIZE.x - beside
	var fr := load(FRENCH) as Translation
	var over: Array[String] = []
	var widest := {"block": ["", 0.0], "chip": ["", 0.0]}
	for key: StringName in Catalogue.live():
		var word := String(Catalogue.words(key).get(&"word", ""))
		var french := String(fr.get_message(StringName(word))) if fr != null else ""
		for each: String in [word, french]:
			if each.is_empty():
				continue
			var small := font.get_string_size(each, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				NormalMode.LABEL_SIZE).x
			var big := font.get_string_size(each, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				Figure.CHIP_WORD).x
			if small > float(widest["block"][1]):
				widest["block"] = [each, small]
			if big > float(widest["chip"][1]):
				widest["chip"] = [each, big]
			if small > block:
				over.append("%s's \"%s\" %.1f px in the choosing screen's %.0f" % [key, each,
					small, block])
			if big > chip:
				over.append("%s's \"%s\" %.1f px on a chip's %.1f" % [key, each, big, chip])
	_check(("and every live chip word fits where it is drawn, in English and in French: the"
		+ " choosing screen's %.0f px at %d px -- the widest \"%s\", %.1f -- and a chip's %.1f"
		+ " beside its pips at %d px -- the widest \"%s\", %.1f%s") % [block,
		NormalMode.LABEL_SIZE, widest["block"][0], widest["block"][1], chip, Figure.CHIP_WORD,
		widest["chip"][0], widest["chip"][1],
		"" if over.is_empty() else ": too wide: " + ", ".join(over)], over.is_empty())


## Every message the template holds, by gettext's own key: the context, `\u0004` and
## the id where it has a context, and the id alone where not -- a plural's id too.
func _template_ids() -> Dictionary:
	var out := {}
	var entry := {"msgctxt": "", "msgid": "", "msgid_plural": ""}
	var field := ""
	for line: String in FileAccess.get_file_as_string(TEMPLATE).split("\n"):
		var body := line.strip_edges()
		if body.begins_with("\""):
			if entry.has(field):
				entry[field] = String(entry[field]) + _quoted(body)
			continue
		var space := body.find(" ")
		var word := body.substr(0, space) if space > 0 else body
		if word.begins_with("msgstr"):
			var context := String(entry["msgctxt"])
			for id: String in [String(entry["msgid"]), String(entry["msgid_plural"])]:
				if not id.is_empty():
					out[id if context.is_empty() else context + "\u0004" + id] = true
			entry = {"msgctxt": "", "msgid": "", "msgid_plural": ""}
			field = ""
		elif entry.has(word):
			field = word
			entry[word] = _quoted(body.substr(space + 1))
		else:
			field = ""
	return out


## The text of one quoted `.po` string, its escapes read.
static func _quoted(text: String) -> String:
	var t := text.strip_edges()
	if t.length() < 2 or not t.begins_with("\"") or not t.ends_with("\""):
		return ""
	return t.substr(1, t.length() - 2).c_unescape()


## **Every live gene has its numbers on the pause screen** -- what it does and what
## it costs, at every copy count, and at its first level and down each way where it
## levels -- and a retired gene, and a key this build does not know, draw nothing:
## a row with nothing in it is drawn as nothing at all. A gene that does not level
## is read in every slot too, as the pause screen reads it, so that every line its
## organ's file can say is said once here; worn somewhere, it still says what it
## costs (a side venom the switch made inert says nothing else).
func _lines() -> void:
	var ctx := GeneStats.context({})
	var bad: Array[String] = []
	var rows_read := 0
	for key: StringName in Catalogue.live():
		var levels := Catalogue.levels(key)
		var cases: Array = [[0, &""]]
		if not levels.is_empty():
			cases = [[1, &""]]
			for way: Variant in levels.get("paths", []):
				cases.append([int(levels.get("fork", 1)), StringName(way)])
		var slots: Array = [-1] if not levels.is_empty() else range(-1, CellBody.SLOT_MAX + 1)
		for copies in range(1, Genome.TIER_MAX + 1):
			for case: Array in cases:
				for slot: int in slots:
					var rows: Array = GeneStats.lines(key, copies, case[0], case[1], ctx, slot)
					rows_read += 1
					if rows.size() != 2 or (rows[1] as Array).is_empty() \
							or (slot < 0 and (rows[0] as Array).is_empty()):
						bad.append("%s at %d copies, level %d%s, slot %d" % [key, copies,
							case[0], " down " + String(case[1]) if case[1] != &"" else "", slot])
	# **A retired key needs no lines** (§16): its organ's file may keep them, and a
	# body still wearing it reads them. One whose file says none draws nothing, as
	# a key this build does not know draws nothing.
	var silent: Array[StringName] = _said_nothing()
	silent.append(&"probeunknown")
	for key: StringName in silent:
		if GeneStats.lines(key, 2, 0, &"", ctx) != [[], []]:
			bad.append("%s draws a row" % key)
	_check(("every live gene says what it does and what it costs on the pause screen -- %d"
		+ " readings, every copy count, level, way and slot -- and a key with no lines, %s,"
		+ " draws nothing%s") % [rows_read,
			str(silent), "" if bad.is_empty() else ": wrong: %s" % ", ".join(bad)],
		bad.is_empty())


# --- Colours (§12.1) ---------------------------------------------------------------------

## **No two genes' hues nearer than today's floor, and none within 25° of self teal
## or threat red**, but the pairs that already were; and **every copy of a gene's
## hue is its organ's**: the membrane's lobes are the hues of the organs on their
## channels, its strains the hues of the forms that deliver them, the call code the
## ping's, and each pad the organ it works through.
func _colours() -> void:
	var hues := {}
	for key: StringName in Catalogue.live():
		var hue: Variant = Catalogue.look(key).get("hue")
		if hue is Color:
			hues[key] = (hue as Color).h * 360.0
	var marks := {&"teal": Cilia.SELF_TINT.h * 360.0, &"red": Cilia.PREDATOR_TINT.h * 360.0}
	var close: Array[String] = []
	var kept: Array[String] = []
	var nearest := 360.0
	var keys: Array = hues.keys()
	for i in keys.size():
		var a: StringName = keys[i]
		for j in range(i + 1, keys.size()):
			var b: StringName = keys[j]
			if Catalogue.forms_of(a).has(b):
				continue
			var gap := _apart(float(hues[a]), float(hues[b]))
			if _kept(a, b):
				kept.append("%s and %s %.1f°" % [a, b, gap])
			elif gap < HUE_FLOOR_DEG:
				close.append("%s and %s %.1f°" % [a, b, gap])
			else:
				nearest = minf(nearest, gap)
		for mark: StringName in marks:
			var gap := _apart(float(hues[a]), float(marks[mark]))
			if gap >= CLEAR_DEG:
				continue
			if _kept(a, mark):
				kept.append("%s and %s %.1f°" % [a, mark, gap])
			else:
				close.append("%s and %s %.1f°" % [a, mark, gap])
	_check(("no two genes' hues nearer than %.0f° -- the nearest now %.1f° -- and none within"
		+ " %.0f° of self teal or threat red, but the %d kept until phase 6: %s%s") % [
			HUE_FLOOR_DEG, nearest, CLEAR_DEG, kept.size(), ", ".join(kept),
			"" if close.is_empty() else "; too near: %s" % ", ".join(close)],
		close.is_empty() and kept.size() == _kept_live())
	if kept.size() != _kept_live():
		print("[gene-probe] NOTE kept until phase 6, and no longer near: take it off the list")
	var wrong: Array[String] = []
	var copies := 0
	for lobe: Array in [[&"light", SignalBus.LIGHT_COLOR, Catalogue.LIGHT],
			[&"beam", SignalBus.BEAM_COLOR, Catalogue.BEAM],
			[&"ping", SignalBus.PING_COLOR, Catalogue.PING]]:
		copies += 1
		if not _same(lobe[1], Catalogue.first_on(lobe[2])):
			wrong.append("the membrane's %s lobe" % lobe[0])
	for kind in Doses.Kind.size():
		var form := _delivering(kind)
		if form == &"":
			continue
		copies += 1
		var cilia := Cilia.dose_hue(kind)
		if not _same(SignalBus.STRAIN_COLORS[kind], form) \
				or not _same(Vector3(cilia.r, cilia.g, cilia.b), form):
			wrong.append("the strain colour of %s" % Doses.Kind.keys()[kind])
	for pad: Array in [[&"turn", Controls.TURN_HUE, &"turn_rate"],
			[&"push", Controls.PUSH_HUE, &"push_accel"],
			[&"hold", Controls.HOLD_HUE, &"impulse_speed"]]:
		copies += 1
		var tone: Color = pad[1]
		if not _same(Vector3(tone.r, tone.g, tone.b), Catalogue.first_provider(pad[2])):
			wrong.append("the %s pad" % pad[0])
	copies += 1
	var code: Color = Earshot.CODE_COLOR
	if not _same(Vector3(code.r, code.g, code.b), Catalogue.first_on(Catalogue.PING)):
		wrong.append("the earshot's call code")
	_check(("every one of the %d copies of a gene's hue is its organ's -- the membrane's light,"
		+ " beam and ping lobes, its strain colours, the three pads, the call code%s") % [copies,
			"" if wrong.is_empty() else "; not: %s" % ", ".join(wrong)], wrong.is_empty())


## **The gene words with no French** (§8.3), listed and never failed: a word not
## yet translated ships in English, and the gene pass sees it here. A name on
## screen is a scientific name, and is not translated.
func _untranslated() -> void:
	var fr := load(FRENCH) as Translation
	if fr == null:
		print("[gene-probe] NOTE no French at %s, so no gene word is checked for one" % FRENCH)
		return
	var missing := PackedStringArray()
	var said := 0
	var parts := _declared_parts()
	for key: StringName in Catalogue.live():
		var english: Array = []
		var words := Catalogue.words(key)
		for name: StringName in words:
			if name != &"name":
				_strings_into(english, words[name], "")
		for part: StringName in parts:
			if String(part).get_slice(".", 0) == String(key):
				var own := Catalogue.part_words(part)
				for name: StringName in own:
					_strings_into(english, own[name], "sense" if name == &"sense" else "")
		var lacking := PackedStringArray()
		var seen := {}
		for one: Array in english:
			if seen.has(one):
				continue
			seen[one] = true
			said += 1
			if String(fr.get_message(StringName(one[0]), StringName(one[1]))).is_empty():
				lacking.append("\"%s\"" % one[0])
		if not lacking.is_empty():
			missing.append("%s: %s" % [key, ", ".join(lacking)])
	print("[gene-probe] NOTE gene words with no French, of %d: %s" % [said,
		"none" if missing.is_empty() else "; ".join(missing)])


# --- The body plan (§10, §12.1, §12.3) ------------------------------------------------------

## **The body plan** (§12.1): every check a plan is held to, on today's; today's held
## to the plan as it shipped (§10.1), its ladder on a sweep of radii the water holds;
## and a broken plan for each check, swapped in, which must fail that check.
func _plan() -> void:
	var faults := _plan_faults()
	_check(("the body plan: %d slots, %d outside; ids unique, and every id a save before"
		+ " stamps kept still known; outside arcs that do not overlap and radii that only"
		+ " rise, the last earned at DIVIDE_RADIUS %.0f; a home for every born organ and"
		+ " nothing else, always earned; the copies of its counts its own, the wire's"
		+ " limits at least its own and its tiers genome.gd's; and room on the pause figure"
		+ " for every slot%s") % [BodyPlan.SLOTS, BodyPlan.SLOT_MAX, CellBody.DIVIDE_RADIUS,
		"" if faults.is_empty() else " -- " + "; ".join(faults)], faults.is_empty())
	# **Today's plan, as it shipped**: the count of every radius on a sweep -- each 200th
	# of a unit to sixty, every rung and a hair either side of it, the drifters' sizes, a
	# newborn's, the born radius and the divide -- by the formula `slots_for` was.
	var radii: Array[float] = [FoodField.DRIFTER_MIN, FoodField.DRIFTER_MAX,
		CellBody.BASE_RADIUS, CellBody.daughter_radius(CellBody.DIVIDE_RADIUS),
		CellBody.DIVIDE_RADIUS, FoodField.ARRIVAL_RADIUS_MAX]
	for step in 12001:
		radii.append(float(step) * 0.005)
	for row: Dictionary in BodyPlan.rows():
		for hair: float in [0.0, 1e-6, 1e-9, 1e-12]:
			radii.append(float(row["earned"]) - hair)
			radii.append(float(row["earned"]) + hair)
	var miscounted: Array[float] = []
	for radius: float in radii:
		if CellBody.slots_for(radius) != _shipped_slots(radius):
			miscounted.append(radius)
	var arcs_ok := true
	for slot in SHIPPED_ARCS.size():
		arcs_ok = arcs_ok and Cilia.arc_for_slot(slot) == SHIPPED_ARCS[slot] \
			and Cilia.slot_bearing(slot) == _shipped_bearing(SHIPPED_ARCS[slot])
	# Every index past them as ever: below, the first earned arc; past, the last.
	arcs_ok = arcs_ok and Cilia.arc_for_slot(-1) == SHIPPED_ARCS[3] \
		and Cilia.arc_for_slot(7) == SHIPPED_ARCS[6] and Cilia.arc_for_slot(99) == SHIPPED_ARCS[6] \
		and Cilia.slot_bearing(-1) == _shipped_bearing(SHIPPED_ARCS[3])
	var counts := [CellBody.SLOT_MIN, CellBody.SLOT_MAX, Genome.INSIDE, Genome.INSIDE_SLOTS,
		Genome.STERN, Wire.ORDER_MAX, Wire.GENES_MAX, BodyPlan.ladder()]
	var ring := _same_list(Figure.SLOT_SEAT, SHIPPED_SEATS) \
		and _same_list(Figure.SLOT_NEIGHBOUR, SHIPPED_NEIGHBOURS) \
		and _same_list(Figure.SLOT_RING, SHIPPED_RING)
	var born := BodyPlan.home_layout(Catalogue.born_order())
	_check(("and today's plan is the one that shipped: the slots of %d radii by the ladder"
		+ " `slots_for` was (%s miscounted), the arcs and bearings of every index (%s), the"
		+ " counts %s, the front %s, the ring the figure had written out (%s), a born body"
		+ " seated %s, and the stamp the ids a save before stamps was kept under (%s)") % [
		radii.size(), str(miscounted.slice(0, 4)), str(arcs_ok), str(counts),
		str(Genome.FRONT), str(ring), str(born), str(BodyPlan.stamp())],
		miscounted.is_empty() and arcs_ok and counts == [3, 7, 7, 1, 2, 7, 9, 3.5]
		and _same_list(Genome.FRONT, SHIPPED_FRONT) and Genome.STERN == SHIPPED_STERN and ring
		and _same_list(born, Catalogue.born_order())
		and BodyPlan.stamp() == PackedStringArray(BodyPlan.BEFORE_STAMPS))
	# **Each check fails a plan that breaks it**: one broken plan a check, swapped in,
	# and today's again after.
	var broken := {}
	var twice := BodyPlan.TODAY.duplicate(true)
	twice[4]["id"] = &"fore_starboard"
	broken["twice"] = [twice, []]
	var lost := BodyPlan.TODAY.duplicate(true)
	lost.remove_at(4)
	broken["is not known"] = [lost, []]
	var overlapping := BodyPlan.TODAY.duplicate(true)
	overlapping[3]["arc"] = Vector2(30.0, 66.0)
	broken["overlap"] = [overlapping, []]
	var falling := BodyPlan.TODAY.duplicate(true)
	falling[4]["earned"] = 36.5
	falling[5]["earned"] = 33.0
	broken["fall"] = [falling, []]
	var short := BodyPlan.TODAY.duplicate(true)
	short[6]["earned"] = 39.0
	broken["DIVIDE_RADIUS"] = [short, []]
	var homeless := BodyPlan.TODAY.duplicate(true)
	homeless[2].erase("home")
	broken["home slots"] = [homeless, []]
	var crowded := BodyPlan.TODAY.duplicate(true)
	crowded.append({"id": &"inside_two", "place": BodyPlan.INSIDE_PLACE,
		"earned": BodyPlan.ALWAYS})
	broken["no room"] = [crowded, []]
	var missed: Array[String] = []
	for fault: String in broken:
		BodyPlan.use(broken[fault][0], broken[fault][1])
		var said := "; ".join(_plan_faults())
		if not said.contains(fault):
			missed.append("%s (said: %s)" % [fault, said])
	BodyPlan.restore()
	_check("and each check fails a plan that breaks it -- %s -- and today's is back after%s"
		% [", ".join(broken.keys()), "" if missed.is_empty() else ": MISSED " + ", ".join(missed)],
		missed.is_empty() and _plan_faults().is_empty() and Figure.CROWDED.is_empty())


## **What is wrong with the plan in use**, a phrase a fault, and none for a good plan
## (§12.1): every check a plan is held to, today's or one a tool swaps in.
func _plan_faults() -> Array[String]:
	var out: Array[String] = []
	var rows := BodyPlan.rows()
	var ids := {}
	for row: Dictionary in rows + BodyPlan.retired():
		var id := StringName(row.get("id", &""))
		if id == &"" or ids.has(id):
			out.append("id \"%s\" twice, or none" % id)
		ids[id] = true
	for id: String in BodyPlan.BEFORE_STAMPS:
		if not ids.has(StringName(id)):
			out.append("%s, a slot saves before stamps keep genes in, is not known" % id)
	var outside: Array[Dictionary] = []
	var inside := 0
	for row: Dictionary in rows:
		var id := String(row.get("id", ""))
		match StringName(row.get("place", &"")):
			BodyPlan.OUTSIDE_PLACE:
				if inside > 0:
					out.append("%s is outside, after the inside" % id)
				if not [BodyPlan.FRONT_ANATOMY, BodyPlan.SIDE_ANATOMY,
						BodyPlan.STERN_ANATOMY].has(StringName(row.get("anatomy", &""))):
					out.append("%s has no anatomy" % id)
				var arc: Variant = row.get("arc")
				if not arc is Vector2 or (arc as Vector2).x >= (arc as Vector2).y \
						or (arc as Vector2).y - (arc as Vector2).x > 360.0:
					out.append("%s has no arc" % id)
				outside.append(row)
			BodyPlan.INSIDE_PLACE:
				inside += 1
				if row.has("arc") or row.has("anatomy"):
					out.append("%s is inside and has an arc or an anatomy" % id)
			_:
				out.append("%s is in no place" % id)
		var earned: Variant = row.get("earned")
		if not earned is float or not is_finite(float(earned)) or float(earned) < 0.0:
			out.append("%s is earned at no radius" % id)
	if inside < 1:
		out.append("nothing is inside")
	for i in outside.size():
		for j in range(i + 1, outside.size()):
			if outside[i].get("arc") is Vector2 and outside[j].get("arc") is Vector2 \
					and _overlap(outside[i]["arc"], outside[j]["arc"]):
				out.append("%s and %s overlap" % [outside[i]["id"], outside[j]["id"]])
	var sterns := 0
	for k in outside.size():
		if k > 0 and float(outside[k].get("earned", 0.0)) < float(outside[k - 1].get("earned", 0.0)):
			out.append("radii fall at %s" % outside[k]["id"])
		if StringName(outside[k].get("anatomy", &"")) == BodyPlan.STERN_ANATOMY:
			sterns += 1
	if sterns > 1:
		out.append("%d sterns" % sterns)
	if outside.is_empty() or float(outside.back().get("earned", 0.0)) != CellBody.DIVIDE_RADIUS:
		out.append("the last slot outside is not earned at DIVIDE_RADIUS %.1f"
			% CellBody.DIVIDE_RADIUS)
	# **A home for every born organ, and for nothing else**, earned at any radius: a
	# born body wears them, and a drifter has every slot that is always earned.
	var homes := {}
	for row: Dictionary in rows:
		if row.has("home"):
			homes[row["home"]] = int(homes.get(row["home"], 0)) + 1
			if float(row.get("earned", 0.0)) != BodyPlan.ALWAYS:
				out.append("%s, a home, is not always earned" % row["id"])
	for gene: StringName in Catalogue.born():
		if int(homes.get(gene, 0)) != 1:
			out.append("%s, born, has %d home slots" % [gene, int(homes.get(gene, 0))])
	for gene: Variant in homes:
		if not Catalogue.born().has(gene):
			out.append("%s has a home and is not born" % gene)
	# **Every copy of a count the plan's own**, and the wire's limits at least its own.
	if CellBody.SLOT_MIN != BodyPlan.SLOT_MIN or CellBody.SLOT_MAX != BodyPlan.SLOT_MAX \
			or Genome.INSIDE != BodyPlan.INSIDE or Genome.INSIDE_SLOTS != BodyPlan.INSIDE_SLOTS \
			or not _same_list(Genome.FRONT, BodyPlan.FRONT) or Genome.STERN != BodyPlan.STERN:
		out.append("a copy of the plan's counts is not the plan's")
	if Wire.ORDER_MAX < BodyPlan.SLOT_MAX or Wire.GENES_MAX < BodyPlan.SLOTS + 1:
		out.append("the wire carries %d slots and %d genes, for %d and %d" % [Wire.ORDER_MAX,
			Wire.GENES_MAX, BodyPlan.SLOT_MAX, BodyPlan.SLOTS + 1])
	if Wire.TIER_TOP != Genome.TIER_MAX:
		out.append("the wire's tiers end at %d, genome.gd's at %d" % [Wire.TIER_TOP,
			Genome.TIER_MAX])
	# **Room on the pause figure** (§10.4): a seat for every slot, a cell of its own,
	# and every chip inside the figure's box.
	if Figure.SLOT_SEAT.size() != BodyPlan.SLOTS:
		out.append("the figure seats %d of %d slots" % [Figure.SLOT_SEAT.size(), BodyPlan.SLOTS])
	if not Figure.CROWDED.is_empty():
		out.append("the pause figure has no room for slot %s" % str(Figure.CROWDED))
	var box := Rect2(Vector2.ZERO, Figure.FIGURE_SIZE)
	for slot in Figure.SLOT_SEAT.size():
		if not box.encloses(Rect2(Figure.chip_at(slot), Figure.SLOT_SIZE)):
			out.append("chip %d leaves the figure" % slot)
	return out


## **A plan of the probe's own, end to end** (§10.3, §12.3): a cell kept under today's
## plan -- in its own file and, as a build before slots left it, in a world's --
## loaded under [constant PLAN_TEST], every gene in its slot by id and the removed
## slot's gene on the arc nearest it, nothing lost; the genome's rules, the venom's
## sides, the wire's limits and the pause figure on that plan; a cell kept under it
## loaded on today's again; and today's plan back, all of it, after.
func _synthetic_plan() -> void:
	var before := _plan_snapshot()
	var dna := {&"cytostome": 2, &"cirrus": 1, &"flagellum": 3, &"ocellus": 1, &"palp": 1,
		&"toxicyst": 2, &"ampulla": 1, &"veneneux": 2}
	var order: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum", &"ocellus", &"palp",
		&"toxicyst", &"ampulla"]
	# The body still wears the stigma the DNA has since written its eyespot over.
	var body := dna.duplicate()
	body.erase(&"ocellus")
	body[&"stigma"] = 1
	var worn: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum", &"stigma", &"palp",
		&"toxicyst", &"ampulla"]
	var swapped: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum", &"palp",
		&"ocellus", &"toxicyst", &"ampulla"]
	var kept := Genome.new()
	kept.express(dna, order, body, worn)
	var state: Dictionary = kept.to_state()
	kept.free()
	var unstamped := state.duplicate(true)
	unstamped.erase("plan")
	var cell := _empty_of(DropSave.CELL)
	cell["genome"] = state
	cell["body"]["radius"] = CellBody.DIVIDE_RADIUS
	cell["generation"] = 3
	cell["daughters"] = NormalMode._daughters_by_name([
		{"tiers": dna, "order": order, "body": body, "mutation": &""},
		{"tiers": dna, "order": swapped, "body": body, "mutation": &"shift"}])
	# A world with no water in it, as a build before slots kept it: the cell in it.
	var water := _empty_of(DropSave.SHAPE["drop"] as Dictionary)
	water["clocks"] = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	DirAccess.make_dir_recursive_absolute(PLAN_FILES)
	var cell_path := PLAN_FILES.path_join("cell.save")
	var drop_path := PLAN_FILES.path_join("drop.save")
	var wrote := [CellSave.write(cell_path, CellSave.compose("", "", 0, 0, -1.0, {}, cell)),
		DropSave.write(drop_path, DropSave.compose(water, {"": cell}))]

	BodyPlan.use(PLAN_TEST, PLAN_TEST_RETIRED)
	var faults := _plan_faults()
	var from_cell := CellSave.read(cell_path)
	var from_drop := DropSave.read(drop_path)
	var readable := not from_cell.is_empty() and not from_drop.is_empty() \
		and DropSave.cells_of(from_drop).has("")
	var expect_order: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum", &"ocellus",
		&"toxicyst", &"", &"ampulla", &"palp"]
	var expect_worn: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum", &"stigma",
		&"toxicyst", &"", &"ampulla", &"palp"]
	var expect_swapped: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum", &"palp",
		&"toxicyst", &"", &"ampulla", &"ocellus"]
	var loaded: Array[String] = []
	var genomes: Array = []
	for source: Dictionary in [from_cell.get("cell", {}).get("genome", {}),
			DropSave.cells_of(from_drop).get("", {}).get("genome", {}), unstamped]:
		var one := Genome.new()
		if not source.is_empty():
			one.set_state(source)
		genomes.append(one)
		loaded.append("%s / %s" % [str(one.layout()), str(one.body_layout())])
	var by_id := true
	for one: Node in genomes:
		by_id = by_id and _same_list(one.layout(), expect_order) \
			and _same_list(one.body_layout(), expect_worn) and one.dna() == dna \
			and one.tiers() == body and _same_list(one.inside_layout(), [&"veneneux"])
	var daughters: Array = from_cell.get("cell", {}).get("daughters", [])
	var offered := daughters.size() == 2 \
		and _same_list(Genome.layout_from(daughters[0]["order"], daughters[0].get("plan")),
			expect_order) \
		and _same_list(Genome.layout_from(daughters[1]["order"], daughters[1].get("plan")),
			expect_swapped)
	_check(("a body plan of the probe's own -- a slot moved, one removed, two added, eight"
		+ " outside -- holds to every check a plan is held to%s; a cell kept under today's,"
		+ " in its own file and in a world's (written %s, read %s), and one kept before"
		+ " stamps, load with every gene in its slot by id and the removed slot's on the"
		+ " free arc nearest it, the DNA, the body and the inside whole: %s; and the"
		+ " daughters on offer the same (%s)") % [
		"" if faults.is_empty() else " -- " + "; ".join(faults), str(wrote), str(readable),
		"; ".join(loaded), str(offered)],
		faults.is_empty() and wrote == [OK, OK] and readable and by_id and offered)

	# **The genome's rules on it**: the counts, the ladder, the places, a move into the
	# slot today's plan would call the inside, and the venom's side read off the plan.
	var on_plan: Node = genomes[0]
	var ladder: Array[int] = []
	for radius: float in [FoodField.DRIFTER_MIN, CellBody.BASE_RADIUS, 29.5, 31.0, 34.0, 37.0,
			39.99, CellBody.DIVIDE_RADIUS]:
		ladder.append(CellBody.slots_for(radius))
	var moved: bool = on_plan.move(7, 5)
	var after_move: Array = on_plan.layout().duplicate()
	var stings := FoodField.toxins_of(body, _worn_of(on_plan))
	var sting_at := NAN
	for k in range(0, stings.size(), FoodField.TOX_STRIDE):
		if int(stings[k]) == FoodField.HOW_STING:
			sting_at = stings[k + 3]
	var many := dna.duplicate()
	many[&"stigma"] = 1
	many[&"chemocyte"] = 1
	var drawn := Cilia.default_order(many)
	_check(("and the genome's rules follow it: slots %s at r13 to r40, inside from %d with %d,"
		+ " the front %s and the stern %d; a gene moves into slot 7, outside now (%s: %s); the"
		+ " venom on the moved rear diagonal stings along its bearing (%.4f, the plan's %.4f);"
		+ " and a water body's default order seats %d outside") % [str(ladder), Genome.INSIDE,
		Genome.INSIDE_SLOTS, str(Genome.FRONT), Genome.STERN, str(moved), str(after_move),
		sting_at, Cilia.slot_bearing(4), drawn.size()],
		ladder == [3, 3, 4, 5, 6, 7, 7, 8] and Genome.INSIDE == 8 and Genome.INSIDE_SLOTS == 1
		and _same_list(Genome.FRONT, [0, 3, 7]) and Genome.STERN == 2
		and Genome.place_of(7) == Genome.OUTSIDE_PLACE and Genome.place_of(8) == Genome.INSIDE_PLACE
		and moved and after_move[5] == &"palp" and after_move[7] == &""
		and sting_at == Cilia.slot_bearing(4) and sting_at != _shipped_bearing(SHIPPED_ARCS[5])
		and drawn.size() == 8)

	# **The wire's limits follow it**: a body of ten genes with eight slots crosses on it,
	# and the referee takes its order; today's plan refuses the same frame.
	var ten := body.duplicate()
	ten[&"chemocyte"] = 1
	ten[&"axoneme"] = 1
	var eight: Array[StringName] = expect_worn.duplicate()
	eight[5] = &"chemocyte"
	var frame := Wire.event(1, Wire.EVENT_PERSON, Wire.person_payload(false, ten, eight))
	var crossed := Wire.take_person(frame)
	var limits := [Wire.ORDER_MAX, Wire.GENES_MAX, Wire.PERSON_MAX]
	var fits := Referee._order_fits(ten, eight)

	# **The figure lays it out**: the port flank in the cell today's leaves empty, the
	# bow on the removed slot's, the ring by bearing, and the inside's arrows.
	var seats := Figure.SLOT_SEAT.duplicate()
	var ring := Figure.SLOT_RING.duplicate()
	var inside_ways: Array = Figure.SLOT_NEIGHBOUR[8].duplicate()

	# **And back**: a cell kept under it, loaded on today's plan -- an id today's never
	# knew takes the first free slot -- and everything today's plan sizes as it was.
	var later: Dictionary = (genomes[1] as Node).to_state()
	var offer_later: Array = NormalMode._daughters_by_name([{"tiers": dna,
		"order": (genomes[1] as Node).layout(), "body": body, "mutation": &""}])
	for one: Node in genomes:
		one.free()
	BodyPlan.restore()
	var offered_back := _same_list(Genome.layout_from(offer_later[0]["order"],
		offer_later[0].get("plan")), order)
	var refused := Wire.take_person(frame).is_empty()
	var home := Genome.new()
	home.set_state(later)
	var round_trip := _same_list(home.layout(), order) and _same_list(home.body_layout(), worn) \
		and home.dna() == dna and home.tiers() == body
	var back_home := "%s / %s" % [str(home.layout()), str(home.body_layout())]
	home.free()
	_check(("and the wire's limits follow it -- %s slots, genes and PERSON bytes -- so a body"
		+ " of ten genes on eight slots crosses (%s) and the referee takes its order (%s),"
		+ " where today's plan refuses the same frame (%s)") % [str(limits),
		str(not crossed.is_empty()), str(fits), str(refused)],
		limits == [8, 10, Wire.EVENT_HEADER + 1 + (1 + 10 * (1 + Wire.NAME_MAX + 1))
			+ (1 + 8 * (1 + Wire.NAME_MAX))]
		and crossed.size() == 3 and (crossed[1] as Dictionary) == ten
		and _same_list(crossed[2], eight) and fits and refused)
	_check(("and the pause figure lays it out: seats %s, Tab round %s, and from the inside"
		+ " left to the port flank, %s") % [str(seats), str(ring), str(inside_ways)],
		seats.size() == 9 and seats[5] == Vector2(-150.0, 0.0) and seats[7] == Vector2(-150.0, -138.0)
		and seats[4] == Vector2(150.0, 168.0) and seats[8] == Vector2(0.0, 6.0)
		and _same_list(ring, [0, 3, 1, 4, 2, 6, 5, 7, 8]) and inside_ways == [5, 0, 1, 2])
	var after := _plan_snapshot()
	for path: String in [cell_path, drop_path]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PLAN_FILES)
	_check(("and a cell kept under it loads on today's plan with every gene where it was: %s,"
		+ " and a daughter it was offered the same (%s); and today's plan is back, all of it,"
		+ " after (%s)") % [back_home, str(offered_back), str(after == before)],
		round_trip and offered_back and after == before)


## Everything a plan sizes or lays out, to tell today's plan is back after another.
func _plan_snapshot() -> Array:
	return [BodyPlan.fingerprint(), BodyPlan.stamp(), CellBody.SLOT_MIN, CellBody.SLOT_MAX,
		Genome.INSIDE, Genome.INSIDE_SLOTS, Genome.FRONT.duplicate(), Genome.STERN,
		Figure.SLOT_SEAT.duplicate(), Figure.SLOT_NEIGHBOUR.duplicate(true),
		Figure.SLOT_RING.duplicate(), Wire.GENES_MAX, Wire.ORDER_MAX, Wire.PERSON_MAX,
		Wire.SISTER_MAX, DropSave.rules(), Cilia.slot_bearing(5), Cilia.arc_for_slot(-1),
		Cilia.default_order(Catalogue.born()), CellBody.slots_for(36.5)]


## The body layout of [param genome], as a list a toxin's seats are read from.
static func _worn_of(genome: Node) -> Array:
	return Array(genome.body_layout())


## **The slots a radius earned by the ladder `slots_for` was** before the plan
## (§10.1): [constant SHIPPED_LADDER]'s formula, as `cell.gd` wrote it.
static func _shipped_slots(radius: float) -> int:
	var fewest := int(SHIPPED_LADDER["fewest"])
	return clampi(fewest + int((radius - float(SHIPPED_LADDER["base"]))
		/ float(SHIPPED_LADDER["step"])), fewest, int(SHIPPED_LADDER["most"]))


## **The bearing an arc looked along before the plan**, as `cilia.gd` worked it out.
static func _shipped_bearing(arc: Vector2) -> float:
	var t := deg_to_rad((arc.x + arc.y) * 0.5)
	return atan2(sin(t) * (1.0 - Cilia.OVOID_PINCH * cos(t)) * Cilia.OVOID_ACROSS,
		cos(t) * Cilia.OVOID_ALONG)


## Whether two arcs of skin, in degrees, share more than an edge, round the circle.
static func _overlap(a: Vector2, b: Vector2) -> bool:
	for turn: float in [-360.0, 0.0, 360.0]:
		if maxf(a.x, b.x + turn) < minf(a.y, b.y + turn):
			return true
	return false


## **Every key of [param shape], each the empty value of its type**: a file of that
## shape with nothing in it yet.
static func _empty_of(shape: Dictionary) -> Dictionary:
	var out := {}
	for key: String in shape:
		var want: Variant = shape[key]
		if want is Dictionary:
			out[key] = _empty_of(want)
		elif int(want) == TYPE_STRING:
			out[key] = ""
		else:
			out[key] = type_convert(null, int(want))
	return out


## **The retired keys whose organ's file says no lines**: those that draw nothing on
## the pause screen. A key retired later keeps its organ's `lines` -- retiring is the
## tag alone (§16) -- and a body still wearing it reads them.
func _said_nothing() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in Catalogue.tagged(Catalogue.RETIRED):
		var organ := Catalogue.gene(key)
		var source := (organ.get_script() as GDScript).source_code if organ != null else ""
		if not source.contains("func lines("):
			out.append(key)
	return out


## **How many of [constant KEPT_UNTIL_FAMILIES] are still pairs of live colours**: a
## pair with a retired key in it is no pair any more -- a retired key is not among
## the colours checked -- and drops out of the count (§16).
func _kept_live() -> int:
	var count := 0
	for pair: Array in KEPT_UNTIL_FAMILIES:
		var live := true
		for one: StringName in pair:
			if Catalogue.known(one) and Catalogue.has_tag(one, Catalogue.RETIRED):
				live = false
		if live:
			count += 1
	return count


## Whether two lists hold the same values in the same order, whatever their types.
static func _same_list(a: Variant, b: Variant) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		if a[k] != b[k]:
			return false
	return true


# --- Gene names left in code (§12.2) ----------------------------------------------------------

## **How many gene names are left written into game/ outside game/genes/** --
## `&"<key>"` and `"<key>"` alike, comments aside: what phase 5's gate will fail
## on (§12.2). A number, not a failure, until then.
func _names_left() -> void:
	var found := {}
	var total := 0
	var named := 0
	for path: String in _scripts_in(GAME_DIR):
		if path.begins_with(GENES_DIR + "/"):
			continue
		var text := FileAccess.get_file_as_string(path)
		var here := 0
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for key: StringName in Catalogue.keys():
				# `"key"` is in `&"key"` too, so this counts both.
				here += line.count('"%s"' % key)
				named += line.count('&"%s"' % key)
		if here > 0:
			found[path.trim_prefix(GAME_DIR + "/")] = here
			total += here
	var files: Array = found.keys()
	files.sort_custom(func(a: String, b: String) -> bool:
		return int(found[a]) > int(found[b]) or (found[a] == found[b] and a < b))
	var parts := PackedStringArray()
	for path: String in files:
		parts.append("%s %d" % [path, int(found[path])])
	print(("[gene-probe] NOTE %d gene names left in game/ outside game/genes/ -- %d"
		+ " &\"<key>\", %d \"<key>\" -- in %d files: ") % [total, named, total - named,
			files.size()] + ", ".join(parts))


# --- Helpers ----------------------------------------------------------------------------------

## Every part the genes declare, by its qualified name: its declaration, and the
## side it is on (`in`, a sense; `out`, an action) as `side`.
func _declared_parts() -> Dictionary:
	var out := {}
	var declared := Catalogue.declares()
	for key: StringName in declared:
		for side: String in ["in", "out"]:
			for part: Dictionary in (declared[key] as Dictionary).get(side, []):
				var decl := part.duplicate()
				decl["side"] = side
				out[StringName("%s.%s" % [key, part["name"]])] = decl
	return out


## Whether [param value] is words: a string with something in it.
static func _said(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty()


## Whether [param value] is a count of strokes: a whole number above nought.
static func _counts(value: Variant) -> bool:
	return value is int and int(value) > 0


## The entries of an organ file's word table [param name] in [param tables], or of a
## table's own inner table: none where it is not a dictionary.
static func _table(tables: Variant, name: Variant) -> Array:
	var table: Variant = (tables as Dictionary).get(name) if tables is Dictionary else null
	return (table as Dictionary).keys() if table is Dictionary else []


## How far apart two hues are, in degrees round the wheel.
static func _apart(a: float, b: float) -> float:
	var gap := absf(a - b)
	return minf(gap, 360.0 - gap)


## Whether [param a] and [param b] are a pair kept until phase 6.
static func _kept(a: StringName, b: StringName) -> bool:
	for pair: Array in KEPT_UNTIL_FAMILIES:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false


## Whether [param rgb], a copy of a hue as the shader takes it, is [param key]'s.
static func _same(rgb: Vector3, key: StringName) -> bool:
	var hue: Variant = Catalogue.look(key).get("hue")
	return hue is Color and rgb.is_equal_approx(Vector3(hue.r, hue.g, hue.b))


## The first live form that delivers a load of [param kind], `&""` for none.
static func _delivering(kind: int) -> StringName:
	for key: StringName in Catalogue.live():
		var dose := Catalogue.dose_of(key)
		if dose != &"" and Doses.kind_of(dose) == kind:
			return key
	return &""


## Adds every string in [param value] -- a string, or a table or list of them --
## to [param into], each as `[text, context]`.
static func _strings_into(into: Array, value: Variant, context: String) -> void:
	if value is String:
		if not (value as String).is_empty():
			into.append([value, context])
	elif value is Dictionary:
		for inner: Variant in (value as Dictionary).values():
			_strings_into(into, inner, context)
	elif value is Array:
		for inner: Variant in value:
			_strings_into(into, inner, context)

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
