extends Node
## CI probe: **the genes, as data** (docs/design/gene-catalogue.md §12.1). Every
## gene's numbers, lists, tags, rules, look and words live in its organ's file under
## game/genes/organs/, and everything that reads one asks the catalogue. What a
## render cannot show is a gene that is half there: a key the wire refuses, a
## table one entry short, a live gene with no class in the water, a sense no
## channel carries, an organ file the index forgot. Each of those works alone and
## fails somewhere else -- in a shared pond, a seeded water, a save -- so it fails
## here first.
##
## **Static, and a few seconds**: it reads the catalogue and the files, and plays
## nothing. What it checks (§15): the keys -- names the wire carries, one form's
## each, in their shipped order, organ and variant names their own, every variant
## at an order of its own, and an organ's own key retired alone only as the toxin is
## laid out, never by a tag on the organ over a live variant; the index
## against the folder, and every tag, channel, place and field one there is; the
## water's drifters, senses, gift and born cell, and the lists a draw or a bit reads
## in their shipped order; how rare each gene is (docs/design/gene-rarity.md §11.3) --
## the ladder, a class on every live organ and none on a form, the habitats, a weight
## in the water for every variety of its pool and in drift for every one drift may
## bring, the commons' share, a variety the water never makes taking nothing of its
## organ's place there, what the water holds of each class and what its floor costs,
## and the word a player reads for each class (rarity-word-ux.md §7) -- and the senses
## by channel and the gift by two tags; every stat table's length and first entry,
## every row, and a provider for every stat, live or retired; the founders' parts
## declared, and every declared part wired in a water cell and in yours; what each
## mechanic asks of the organ it finds by a stat; and organs registered and
## forgotten -- forms, tags that add up, variants of no forms, an organ that calls
## with no period, a part nothing wires, a look drawn at once. Then what a gene
## looks like and says (§7.1, §8): every live gene's look, its words and its
## parts' words, no word table naming what is not its organ's, its numbers on the
## pause screen; and its look by gene-looks.md §8 -- a family there is and a kind it
## is built as, every parameter its kind's, no two organs of a family alike at a
## glance, a tile that fits, every variant its own accent -- and the families'
## colours, measured in OKLCH, every copy of a hue its source's and every sense on a
## channel with a lobe. Then the body plan
## (§10, §12.1): ids unique and none a save before stamps kept forgotten, arcs that
## do not overlap, radii that only rise to the divide, a home for each born organ,
## the copies of its counts and the wire's limits its own, room on the pause figure
## -- each shown failing a plan that breaks it -- and today's plan held to the one
## that shipped, and the plan saves before stamps were kept under to its own pin,
## which never moves; and a plan of the probe's own put through a cell's file and a
## world's, the genome, the wire and the figure, and taken out again (§12.3). Then a
## gene of the probe's own -- an organ with two variants, one in two places -- put
## through the genome, the water, the body, its instinct parts, the wire, a cell's
## file, the referee and the pause screen, held to one variant a body, and taken out
## again; a faster tail, one entry in the tail's own file, its parts offered on the
## instincts page to a body that wears it alone; and a second strain of the toxin, one
## entry of one place in its own file, covered by its organ's tags (§12.3). Then what
## the first variant of a shipped organ meets (§15.6): a peer born with the organ
## drawing its other variants, one measure of an organ's level for its rules and its
## tail's hold, one variant a body wherever a body comes to carry one, a group of stats
## taken from one provider, a person's order written before its genome, and a mechanic
## with a place taking every number from the one organ it acts from -- two darts, two
## radars, by your cell, the water, a person, the referee and the rules (§5.2); and the
## rulebook numbering owners past one word of bits (§13). And -- a number, not a
## failure (§8.3) -- the gene words with no French; and how many gene names are
## written into game/ outside game/genes/, which `-- --names` fails on (§12.2, CI's
## "Check the gene names").
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
const Rules := preload("res://game/net/rules.gd")
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
## The instincts page, whose offers a variant's parts are checked through.
const ProgramsPage := preload("res://game/normal/programs_page.gd")

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

## **The stats a mechanic reads together, as one organ's** -- `stats.gd`'s groups, by
## its rows' `group`, in its rows' order, kept here as well so that a change there
## fails here first -- so every organ that provides one of a group provides all of it:
## a stroke is its speed and its two gaps; a turn its rate and how fast it answers; a
## beam its reach, its rays and their fan; a call its reach, its period and how much
## of it passes a body; a dash its burst and its price; a dart its reach and its rest.
## An organ that gave one alone would be read at the others' values with no provider
## -- a call every 0 s, which the referee divides by, or a tail's speed beating at the
## gaps of no tail. And a body wearing two providers takes a whole group from one.
const TOGETHER: Array = [
	[&"impulse_speed", &"impulse_gap_min", &"impulse_gap_max"],
	[&"turn_rate", &"turn_response"],
	[&"beam_range", &"beam_count", &"beam_fan_deg"],
	[&"ping_range", &"ping_period", &"ping_through"],
	[&"dash_speed", &"dash_cost"],
	[&"dart_range", &"dart_cooldown"],
]

## **The families and the kinds** (docs/design/gene-looks.md §1, §2, §7): what a
## look is checked against.
const Families := preload("res://game/genes/families.gd")
const Kinds := preload("res://game/genes/kinds.gd")
## **The ladder a gene's `water.rarity` names a row of** (docs/design/gene-rarity.md §2).
const Rarity := preload("res://game/genes/rarity.gd")
## **The water's three compositions** (gene-rarity.md §5, §11.3 item 5): how sighted the
## player a drop is made for is -- a newborn's, a sighted one's, a fully sighted one's --
## each setting how many drifters stand in it, `Drop.food_count` of the share it calls for.
const SIGHTED: Array[float] = [0.2, 0.6, 1.0]
## **The fields a gene's `water` holds** (gene.gd): its class, whether the water makes
## it, and its places. A field outside them is read by nothing -- `weight`, which the
## draws read until gene-rarity.md's phase 7-2, above all -- and would only mislead.
const WATER_FIELDS: Array[String] = ["rarity", "drifter", "habitats"]
## **What the floor's load failing says** (§11.3 item 6): past it, the floor cannot keep
## its promise, and the answer is a design -- places -- not a retuning.
const CROWDED := "the drop cannot keep this many genes at their counts: see gene-rarity.md §5.4"
## **The families' colours, measured in OKLCH** (gene-looks.md §1.3, §8, checks 6 to
## 9), on the `Color`s themselves: a family's shades within [constant
## SHADE_LIGHTNESS] of one lightness, stepping in hue by [constant SHADE_STEP_MIN] to
## [constant SHADE_STEP_MAX] degrees -- a whisper, never a tier; every shade at least
## [constant BAND_GAP] degrees from every other family's; at least [constant
## MEANING_GAP] from self teal and threat red, the two colours whose meaning is a
## relationship, and every family but eating that far from food green too; and any
## two families' lightness [constant LIGHTNESS_GAP] apart, which is what keeps the
## pairs colour blindness merges apart. **The step's floor is 4.5, not the design's
## 5**: written to two decimals, eating's shades step 5.1 and 4.9 degrees.
const SHADE_LIGHTNESS := 0.02
const SHADE_STEP_MIN := 4.5
const SHADE_STEP_MAX := 10.0
const BAND_GAP := 20.0
const MEANING_GAP := 30.0
const LIGHTNESS_GAP := 0.04
## **What a tile holds** (gene-looks.md §8, check 4), about its organ's centre, in the
## tile's own px at one scale: the 76 px tile, its centre [constant TILE_CENTRE] down
## it; and the explaining line's glyph box, `Figure.EXPLAIN_ORGAN_SIZE` at
## `Figure.EXPLAIN_ORGAN_SCALE` with the organ's centre at `EXPLAIN_ORGAN_SEAT`, which
## the line's row was measured with. Every live organ's tile inside both.
const TILE_SIDE := 76.0
const TILE_CENTRE := TILE_SIDE * Cilia.TILE_CENTRE_Y
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
## **The files the gate reads** (§12.2), by extension, each to the marker its
## language starts a comment with: every script, scene, resource and shader under
## game/. Not the translations (`.po`, `.pot`), whose comments and contexts name genes
## for a translator, not for code.
const GATED := {"gd": "#", "tscn": ";", "tres": ";", "gdshader": "//"}

## **The body plan in this commit, written out by hand** (§10.1): what a reader keeps
## of it -- the counts `CellBody.SLOT_MIN` and `SLOT_MAX`, `Genome.INSIDE`,
## `INSIDE_SLOTS` and `STERN`, `Wire.ORDER_MAX` and `GENES_MAX`, and the ladder -- and
## the ring the pause figure lays out; and below, its rows. Phase 2 held them to what
## `cell.gd`, `cilia.gd`, `genome.gd` and the figure had written before the plan was
## data, so the move changed nothing. **A plan change fails the check that holds
## today's plan to them, on purpose** -- as a new gene appends to [constant SHIPPED] --
## and its message says what to move: these and the rows, in the same commit, and the
## protocol with them ([constant PLAN_MOVED]).
const SHIPPED_COUNTS: Array = [3, 7, 7, 1, 2, 7, 9, 3.5]
const SHIPPED_SEATS: Array[Vector2] = [Vector2(0.0, -138.0), Vector2(150.0, 0.0),
	Vector2(0.0, 168.0), Vector2(150.0, -138.0), Vector2(-150.0, -138.0),
	Vector2(150.0, 168.0), Vector2(-150.0, 168.0), Vector2(0.0, 6.0)]
const SHIPPED_NEIGHBOURS: Array = [[4, -1, 3, 7], [7, 3, -1, 5], [6, 7, 5, -1],
	[0, -1, -1, 1], [-1, -1, 0, 6], [2, 1, -1, -1], [-1, 4, 2, -1], [-1, 0, 1, 2]]
const SHIPPED_RING: Array[int] = [0, 3, 1, 5, 2, 6, 4, 7]
## **Its rows** (§10.1), which the arcs, the ladder, the front and the stern are read
## off where today's is held to them. The broken plans each plan check is shown failing
## on are made from it too, and the synthetic plan's cell is kept under it ([method
## _synthetic_plan]), so a change to today's plan fails the one check that holds today's
## to these pins, whose message says what to move, and no check that merely started
## from today's. **What is made from it finds its slots by id and by place, never by
## index**, so it holds when the pins move. None of its slots had left it
## ([constant SHIPPED_RETIRED]).
const SHIPPED_PLAN: Array[Dictionary] = [
	{"id": &"nose", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.FRONT_ANATOMY,
		"arc": Vector2(-42.0, 42.0), "earned": BodyPlan.ALWAYS, "home": &"cytostome"},
	{"id": &"starboard", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.SIDE_ANATOMY,
		"arc": Vector2(66.0, 118.0), "earned": BodyPlan.ALWAYS, "home": &"cirrus"},
	{"id": &"tail", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.STERN_ANATOMY,
		"arc": Vector2(146.0, 214.0), "earned": BodyPlan.ALWAYS, "home": &"flagellum"},
	{"id": &"fore_starboard", "place": BodyPlan.OUTSIDE_PLACE,
		"anatomy": BodyPlan.FRONT_ANATOMY, "arc": Vector2(42.0, 66.0), "earned": 29.5},
	{"id": &"fore_port", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.FRONT_ANATOMY,
		"arc": Vector2(-66.0, -42.0), "earned": 33.0},
	{"id": &"aft_starboard", "place": BodyPlan.OUTSIDE_PLACE,
		"anatomy": BodyPlan.SIDE_ANATOMY, "arc": Vector2(118.0, 146.0), "earned": 36.5},
	{"id": &"aft_port", "place": BodyPlan.OUTSIDE_PLACE, "anatomy": BodyPlan.SIDE_ANATOMY,
		"arc": Vector2(-146.0, -118.0), "earned": 40.0},
	{"id": &"inside", "place": BodyPlan.INSIDE_PLACE, "earned": BodyPlan.ALWAYS},
]
const SHIPPED_RETIRED: Array[Dictionary] = []
## **What to move when today's plan changes**, said where it fails: the pins, and
## `Wire.RULES` -- the plan's fingerprint rides in the handshake's rules (§11.3) -- but
## never the protocol.
const PLAN_MOVED := ("today's plan changed: move SHIPPED_PLAN, SHIPPED_COUNTS, SHIPPED_SEATS,"
	+ " SHIPPED_NEIGHBOURS and SHIPPED_RING to the new plan in the same commit. The plan's"
	+ " fingerprint is in the rules the handshake carries, so net_probe's Wire.RULES moves"
	+ " too -- and no Wire.PROTOCOL: builds on other plans refuse each other at the"
	+ " handshake by themselves. A change of the slots' count also moves net_probe's wire"
	+ " sizes")
## **The ids every save before the stamp was kept under, in their order** (§10.3):
## `BodyPlan.BEFORE_STAMPS`, written out again here, and apart from [constant
## SHIPPED_PLAN], because that pin moves with a plan change and this one never does.
## A save with no stamp -- every one kept before phase 2, players' among them --
## names no slot: the order its genes are in is all it has, and this list is what
## reads it. An edit to it seats an eye where a palp was in every such save at its
## next load, and nothing else notices: the constant agrees with itself wherever it
## is read.
const SHIPPED_BEFORE_STAMPS: Array[String] = ["nose", "starboard", "tail", "fore_starboard",
	"fore_port", "aft_starboard", "aft_port", "inside"]
## What to do when `BodyPlan.BEFORE_STAMPS` has moved, said where it fails.
const BEFORE_MOVED := ("BodyPlan.BEFORE_STAMPS changed: put it back. It is not today's plan but"
	+ " the one every save before stamps was kept under, and it never moves -- a plan change"
	+ " moves SHIPPED_PLAN and today's rows, never this")

## **A body plan of the probe's own** (§10.3, §12.3), swapped in and out as `register`
## and `forget` put an organ through: the plan as it shipped ([constant SHIPPED_PLAN])
## with **a slot moved** -- the rear starboard diagonal, four degrees narrower and one
## index forward -- **one removed** -- the forward port diagonal, retired -- and **two
## added**: the port flank, in the cell the shipped figure leaves empty, and a bow slot
## on the removed one's arc under an id of its own. Eight slots outside, so everything
## the plan sizes grows by one, and rungs that are not an even ladder.
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
	# **The gate of §12.2 alone**, as CI's "Check the gene names" step runs it.
	if OS.get_cmdline_user_args().has("--names"):
		_names_gate()
		get_tree().quit(0 if _failed == 0 else 1)
		return
	_keys()
	_own_orders()
	_retired_alone()
	_index()
	_water()
	_rarity()
	_senses_and_gift()
	_tables()
	_rules()
	_owner_bits()
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
	_synthetic_gene()
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
			# A variant of no name would be one variant with the organ's own key,
			# whose name is none (gene.gd's `variant`): its forms would be the organ's.
			if variant == &"":
				clashes.append("%s lists a variant with no name" % organ.organ)
			elif variants.has(variant):
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


## **Retiring an organ's own key is not tagging the organ** (§4.4, §6.2): an organ's
## tags are every variant's -- tags add up -- so an organ tagged `retired` retires every
## variant it lists with its own key. One tagged so whose variants do not each say
## `retired` too fails, saying how to retire its own key alone -- the toxin's layout --
## or every one of them. Shown on organs of the probe's own: one tagged over a live
## variant, which fails here and would retire the variant; and the same laid out as the
## toxin is, which passes, its old key retired at its old order and still the first of
## its keys (phase 6's `as_shipped`), its variant live.
func _retired_alone() -> void:
	var before := Array(Catalogue.keys())
	var faults := _retire_faults(_organs())
	var store := Catalogue.first_provider(&"store")
	var script := Catalogue.gene(store).get_script() as GDScript
	var shipped: Gene = script.new()
	var kept := {"variant": &"probekeep", "order": 963, "look": {"accent": Kinds.MARK_RING}}
	# Tagged: the organ retired over a live variant -- found, and the variant retired.
	var tagged: Gene = script.new()
	var tags: Array[StringName] = []
	tags.assign(tagged.tags)
	tags.append(Gene.RETIRED)
	tagged.tags = tags
	tagged.variants = [kept]
	var found := _retire_faults([tagged])
	Catalogue.register(tagged)
	var dragged := Catalogue.has_tag(&"probekeep", Catalogue.RETIRED)
	Catalogue.forget(tagged.organ)
	# Laid out as the toxin is: no order of its own, its first variant listed first with
	# the key, the order and the born it had, and retired.
	var laid: Gene = script.new()
	laid.order = -1
	laid.variants = [{"variant": &"plain", "key": store, "order": shipped.order,
		"born": shipped.born, "tags": [Gene.RETIRED]}, kept]
	var clean := _retire_faults([laid])
	Catalogue.register(laid)
	var took := [Catalogue.has_tag(store, Catalogue.RETIRED), Catalogue.rank(store),
		Catalogue.keys_of_organ(laid.organ)[0], Catalogue.live().has(&"probekeep"),
		Catalogue.has_tag(&"probekeep", Catalogue.RETIRED)]
	Catalogue.forget(laid.organ)
	_check(("an organ's own key retires alone only as the toxin is laid out: %s; one of the"
		+ " probe's own tagged retired over a live variant is found (%s), and registered"
		+ " retires it too (%s); laid out as the toxin is -- no order of its own, its first"
		+ " variant listed first with the key, order and born it had, retired -- %s retires"
		+ " at its order and stays the first of its keys, its variant live: %s") % [
		("none of the %d organs tags itself retired over a variant that does not say so"
			% _organs().size()) if faults.is_empty() else _retire_how(faults),
		", ".join(PackedStringArray(found)), dragged, store, str(took)],
		faults.is_empty() and found == ["%s (probekeep)" % store] and dragged
		and clean.is_empty()
		and took == [true, shipped.order, store, true, false]
		and Array(Catalogue.keys()) == before)


## **Each organ of [param organs] tagged `retired` over a variant that does not say it
## too**, as `organ (variants)`: tags add up, so the organ's tag retires each of them.
static func _retire_faults(organs: Array) -> Array[String]:
	var out: Array[String] = []
	for organ: Gene in organs:
		if not organ.tags.has(Gene.RETIRED):
			continue
		var silent: Array[String] = []
		for entry: Dictionary in organ.variants:
			if not _says_retired(entry):
				silent.append(String(entry.get("variant", &"")))
		if not silent.is_empty():
			out.append("%s (%s)" % [organ.organ, ", ".join(PackedStringArray(silent))])
	return out


## Whether a variant's [param entry] tags itself `retired`: in its own tags, or in every
## form's.
static func _says_retired(entry: Dictionary) -> bool:
	if (entry.get("tags", []) as Array).has(Gene.RETIRED):
		return true
	var forms: Dictionary = entry.get("forms", {})
	for place: Variant in forms:
		var form: Variant = forms[place]
		if not (form is Dictionary
				and ((form as Dictionary).get("tags", []) as Array).has(Gene.RETIRED)):
			return false
	return not forms.is_empty()


## **What to do about [param faults]**, the failure's sentence.
static func _retire_how(faults: Array[String]) -> String:
	return ("%s -- each tagged retired, which retires every variant it lists with it. To"
		% ", ".join(PackedStringArray(faults)) + " retire only its own key, lay it out as"
		+ " the toxin is: the organ's `order = -1` and no `retired` of its own, and its"
		+ " first variant listed first with the key, the order and the born the organ had,"
		+ " retired -- `{\"variant\": &\"plain\", \"key\": &\"<organ>\", \"order\": <its order>,"
		+ " \"born\": <its born>, \"tags\": [RETIRED]}` -- then the others, live. To retire"
		+ " them all, tag each variant retired too")


## **Every variant an organ's file lists has an order of its own** (§6.2): set in its
## entry or its form, and no other key's. The organ's own key -- its implicit first
## variant -- keeps the organ's order, so a variant that set none would take it, and
## tie the organ in `dominant_of`: a body wearing both at one copy count would be
## drawn as either, and eating it would give either. Two keys of one order do the
## same.
func _own_orders() -> void:
	var next := 0
	for key: StringName in Catalogue.keys():
		next = maxi(next, Catalogue.rank(key) + 1)
	var bad: Array[String] = []
	var listed := 0
	for organ: Gene in _organs():
		for entry: Dictionary in organ.variants:
			var forms: Dictionary = entry.get("forms", {})
			var filed: Array = []
			if forms.is_empty():
				filed.append([StringName(entry.get("key", entry.get("variant", &""))),
					entry.get("order")])
			for place: Variant in forms:
				var form: Variant = forms[place]
				if form is Dictionary:
					filed.append([StringName((form as Dictionary).get("key", &"")),
						(form as Dictionary).get("order", entry.get("order"))])
				else:
					filed.append([StringName(form), entry.get("order")])
			for one: Array in filed:
				listed += 1
				if one[1] != null:
					continue
				bad.append(("%s, a variant of %s, has no order of its own: it would take the"
					+ " organ's, %d, %s. Give it the next, %d, and append it to SHIPPED") % [
					one[0], organ.organ, organ.order,
					("and tie %s in dominant_of -- a body wearing both at one copy count would"
						+ " be drawn as either, and eating it would give either") % organ.organ
						if organ.order >= 0 else "which is no place in the order", next])
	var by_order := {}
	for key: StringName in Catalogue.keys():
		var rank := Catalogue.rank(key)
		if rank < 0:
			continue
		if by_order.has(rank):
			bad.append("%s and %s share the order %d, and tie in dominant_of" % [by_order[rank],
				key, rank])
		by_order[rank] = key
	_check("every variant an organ's file lists has an order of its own, no other key's: %d of"
		% listed + " them, the next order %d%s" % [next, "" if bad.is_empty() else ": "
			+ "; ".join(bad)], bad.is_empty())


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

## The water's pool, every variety and no mouth; every sense has a channel, and
## every gift is a sense. A gene's weight in the water is its class's
## ([method _rarity]).
func _water() -> void:
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


# --- Rarity (docs/design/gene-rarity.md §2, §3.3, §11.3) ------------------------------------

## **How rare each gene is, and what keeping them costs the water** (gene-rarity.md
## §11.3, the gene probe's items 1 to 6): the ladder sound; a class on every live organ,
## a variant's a row of the ladder where it sets one, none on a form; every habitat one
## a water declares, none on a form; a weight in the water for every live variety the
## water's pool holds, none for a retired key, and the commons at least their share of
## the drifters' draw; the water's arithmetic printed -- what each class holds and what
## the floor costs, at a newborn's, a sighted and a fully sighted player's composition --
## and the floor's load under its budget at all three. The ladder, the classes and the
## habitats are each shown failing on what breaks them, and the weights on organs of the
## probe's own: a rare kind of a common organ takes its place from its organ alone, a
## second strain that sets no class splits the toxin's, enough uncommon organs to crowd
## the commons leave them their share, and a variant the water never makes takes
## nothing of its organ's place in the water, only its share in drift. The floor's load
## is shown failing on a crowd worked out by the ladder's own arithmetic.
func _rarity() -> void:
	# 1. The ladder.
	var ladder := _ladder_faults(Rarity.LADDER, Rarity.COMMON_SHARE)
	var broken := {
		"a class twice": [_row(&"common", 4.0, 2), _row(&"common", 2.0, 2)],
		"weights rising": [_row(&"common", 2.0, 2), _row(&"uncommon", 4.0, 2)],
		"a weight of nothing": [_row(&"common", 4.0, 2), _row(&"rare", 0.0, 1)],
		"a floor of nothing": [_row(&"common", 4.0, 2), _row(&"rare", 0.5, 0)],
		"no class at all": [],
	}
	var caught: Array[String] = []
	for how: String in broken:
		if not _ladder_faults(broken[how], Rarity.COMMON_SHARE).is_empty():
			caught.append(how)
	for share: float in [0.0, 1.0]:
		if not _ladder_faults(Rarity.LADDER, share).is_empty():
			caught.append("COMMON_SHARE %.0f" % share)
	_check(("the ladder: %s, each weighing more than the next and keeping a carrier or more,"
		+ " COMMON_SHARE %.3f between 0 and 1%s; and a ladder broken each of %d ways is found:"
		+ " %s") % [_ladder_said(), Rarity.COMMON_SHARE,
		"" if ladder.is_empty() else " -- NOT: " + "; ".join(ladder), broken.size() + 2,
		", ".join(caught)], ladder.is_empty() and caught.size() == broken.size() + 2)
	# 2. A class on every live organ; a variant's a row where it sets one; none on a form.
	var classes := _class_faults(_organs())
	var planted := _planted_classes()
	var found: Array[String] = []
	for how: String in planted:
		if not _class_faults([planted[how]]).is_empty():
			found.append(how)
	var unclassed := Gene.new()
	unclassed.organ = &"probeold"
	unclassed.tags = [Gene.RETIRED]
	_check(("a class on every live organ, a row of the ladder: %s; a variant's own a row too,"
		+ " no form setting one, and no water a field nothing reads%s; and each of %d organs"
		+ " planted wrong is found (%s), while a retired organ needs none (%s)") % [
		_classes_said(),
		"" if classes.is_empty() else " -- NOT: " + "; ".join(classes), planted.size(),
		", ".join(found), str(_class_faults([unclassed]).is_empty())],
		classes.is_empty() and found.size() == planted.size()
		and _class_faults([unclassed]).is_empty())
	# 3. Habitats: only ones a water declares -- none yet -- and none on a form.
	var strays := _habitat_faults(_organs())
	var roams := Gene.new()
	roams.organ = &"proberoam"
	roams.water = {"rarity": Rarity.commonest(), "habitats": [&"probeshallows"]}
	var form_roams := Gene.new()
	form_roams.organ = &"proberoamform"
	form_roams.water = {"rarity": Rarity.commonest()}
	form_roams.variants = [{"variant": &"plain", "forms": {
		Gene.INSIDE: {"key": &"proberoamin", "order": 980, "water": {"habitats": []}}}}]
	var homebody := Gene.new()
	homebody.organ = &"probehome"
	homebody.water = {"rarity": Rarity.commonest(), "habitats": []}
	_check(("every habitat a gene names is one a water declares -- %s declared, so every list"
		+ " empty%s -- and none set on a form; a habitat no water declares is found (%s), and"
		+ " so is a form that sets its own (%s), while an empty list is none (%s)") % [
		str(Drop.HABITATS), "" if strays.is_empty() else " -- NOT: " + "; ".join(strays),
		str(not _habitat_faults([roams]).is_empty()),
		str(not _habitat_faults([form_roams]).is_empty()),
		str(_habitat_faults([homebody]).is_empty())],
		strays.is_empty() and not _habitat_faults([roams]).is_empty()
		and not _habitat_faults([form_roams]).is_empty() and _habitat_faults([homebody]).is_empty())
	# 4. A weight for every live variety of the water's pool, and in drift for every one
	# drift may bring; none for a retired key, nor in drift for one tagged never_drifts;
	# and the commons their share.
	var weightless: Array[StringName] = []
	for key: StringName in Catalogue.drifters():
		if not (Catalogue.water_weight(key) > 0.0):
			weightless.append(key)
	var drifting := 0
	for key: StringName in Catalogue.live():
		if Catalogue.variety(key) != key or Catalogue.has_tag(key, Catalogue.NEVER_DRIFTS):
			continue
		drifting += 1
		if not (Catalogue.drift_weight(key) > 0.0):
			weightless.append(key)
	var heavy: Array[StringName] = []
	for key: StringName in Catalogue.keys():
		if (Catalogue.has_tag(key, Catalogue.RETIRED) and (Catalogue.water_weight(key) != 0.0
				or Catalogue.drift_weight(key) != 0.0)) \
				or (Catalogue.has_tag(key, Catalogue.NEVER_DRIFTS)
				and Catalogue.drift_weight(key) != 0.0):
			heavy.append(key)
	var commons := _commons_share()
	_check(("a weight in the water for every live variety of the water's pool, %d of them, and"
		+ " in drift for every one drift may bring, %d%s; none for a retired key, nor in drift"
		+ " for one tagged never_drifts%s; and the commons hold %.1f %% of the drifters' draw,"
		+ " at least COMMON_SHARE's %.1f %%") % [Catalogue.drifters().size(), drifting,
		"" if weightless.is_empty() else " -- NOT %s" % str(weightless),
		"" if heavy.is_empty() else " -- NOT %s" % str(heavy), 100.0 * commons,
		100.0 * Rarity.COMMON_SHARE],
		weightless.is_empty() and heavy.is_empty() and not Catalogue.drifters().is_empty()
		and drifting > 0 and commons >= Rarity.COMMON_SHARE - 1e-9)
	_rare_kind()
	_strains_split()
	_crowded_commons()
	_out_of_pool()
	# 5 and 6. The water's arithmetic, and the floor's load.
	var loads := _floor_loads(_pool_weights())
	print("[gene-probe] NOTE the water by class (gene-rarity.md §5, §11.3): %s" % _arithmetic())
	var over := _over_budget(loads)
	var crowd := _floor_loads(_crowd_weights(170))
	_check(("the floor's load is under its budget, one drifter in %d, at every composition --"
		+ " its expected share of the drifters %s in a newborn's, a sighted and a fully"
		+ " sighted player's drop%s; and a crowd of 170 rare organs more, by the ladder's own"
		+ " arithmetic, would cost %s and is found") % [Drop.GENE_FLOOR_GAP, _percents(loads),
		"" if not over else " -- " + CROWDED, _percents(crowd)],
		not over and _over_budget(crowd))
	_rarity_words()


## **The word a player reads for each class** (docs/design/rarity-word-ux.md §3, §7
## item 2): every class of the ladder has its word in rarity.gd's `WORDS`, one lowercase
## word; every word there names a class; every class in `MARKED` is one; and each word is
## in the template under the context `rarity`, as the screens ask for it. Each is shown
## failing on tables planted wrong. Its French is said and never failed: a word not yet
## translated shows in English (§8.3), as a gene word does.
func _rarity_words() -> void:
	var faults := _word_faults(Rarity.classes(), Rarity.WORDS, Rarity.MARKED)
	var some := Rarity.classes()
	var first: StringName = some[0]
	var last: StringName = some[some.size() - 1]
	var fewer := Rarity.WORDS.duplicate()
	fewer.erase(last)
	var more := Rarity.WORDS.duplicate()
	more[&"probelegendary"] = "legendary"
	var blank := Rarity.WORDS.duplicate()
	blank[first] = ""
	var loud := Rarity.WORDS.duplicate()
	loud[first] = String(Rarity.WORDS[first]).to_upper()
	var planted := {
		"a class with no word": [fewer, Rarity.MARKED],
		"a word for no class": [more, Rarity.MARKED],
		"an empty word": [blank, Rarity.MARKED],
		"a word with capitals": [loud, Rarity.MARKED],
		"a marked class off the ladder": [Rarity.WORDS, [&"probelegendary"]],
	}
	var caught: Array[String] = []
	for how: String in planted:
		if not _word_faults(some, planted[how][0], planted[how][1]).is_empty():
			caught.append(how)
	var held := _template_ids()
	var unlisted: Array[String] = []
	for name: StringName in Rarity.WORDS:
		if not held.has("rarity\u0004" + String(Rarity.WORDS[name])):
			unlisted.append("\"%s\"" % Rarity.WORDS[name])
	if not unlisted.is_empty():
		faults.append("not in the template under the context rarity, so no translator sees it: "
			+ ", ".join(unlisted))
	_check(("a word for every class of the ladder and none for a class it has not, %s; marked"
		+ " %s; each in the template under the context `rarity`%s; and %d tables planted wrong"
		+ " are found (%s)") % [str(Rarity.WORDS.values()), str(Rarity.MARKED),
		"" if faults.is_empty() else " -- NOT: " + "; ".join(faults), planted.size(),
		", ".join(caught)], faults.is_empty() and caught.size() == planted.size())
	var fr := load(FRENCH) as Translation
	if fr == null:
		print("[gene-probe] NOTE no French at %s, so no rarity word is checked for one" % FRENCH)
		return
	var said := PackedStringArray()
	for name: StringName in Rarity.WORDS:
		var french := String(fr.get_message(StringName(Rarity.WORDS[name]), &"rarity"))
		said.append("%s %s" % [Rarity.WORDS[name], "\"%s\"" % french if not french.is_empty()
			else "NOT TRANSLATED"])
	print("[gene-probe] NOTE the rarity words in French: %s" % ", ".join(said))


## **What is wrong with the words [param words] give the classes [param classes]**, and
## the classes [param marked] marks (rarity-word-ux.md §3): a class with no word, or an
## empty one; a word that is not lowercase; a word for a name that is no class; a marked
## name that is no class.
static func _word_faults(classes: Array, words: Dictionary, marked: Array) -> Array[String]:
	var out: Array[String] = []
	for name: Variant in classes:
		var said: Variant = words.get(name)
		if not said is String or (said as String).is_empty():
			out.append("%s has no word" % name)
		elif (said as String) != (said as String).to_lower():
			out.append("%s's word \"%s\" is not lowercase" % [name, said])
	for name: Variant in words:
		if not classes.has(name):
			out.append("a word for %s, which is no class" % name)
	for name: Variant in marked:
		if not classes.has(name):
			out.append("%s is marked, and is no class" % name)
	return out


## A row of a ladder: [param name], its weight and its floor.
static func _row(name: StringName, weight: float, keeps: int) -> Dictionary:
	return {"class": name, "weight": weight, "floor": keeps}


## **What is wrong with [param ladder] and [param share]** (gene-rarity.md §11.3 item
## 1): every class named, once; every weight finite, above 0 and below the one above it;
## every floor 1 or more; and the commons' share between 0 and 1.
static func _ladder_faults(ladder: Array, share: float) -> Array[String]:
	var out: Array[String] = []
	if ladder.is_empty():
		out.append("no class at all")
	var seen := {}
	var above := INF
	for row: Variant in ladder:
		if not row is Dictionary:
			out.append("a row that is no dictionary")
			continue
		var name := StringName((row as Dictionary).get("class", &""))
		var weight := float((row as Dictionary).get("weight", 0.0))
		var keeps := int((row as Dictionary).get("floor", 0))
		if name == &"":
			out.append("a row with no class")
		elif seen.has(name):
			out.append("%s twice" % name)
		seen[name] = true
		if not (weight > 0.0) or not is_finite(weight):
			out.append("%s weighs %s, not above 0" % [name, weight])
		elif weight >= above:
			out.append("%s weighs %s, not less than the class above it" % [name, weight])
		above = weight
		if keeps < 1:
			out.append("%s keeps %d carriers, not 1 or more" % [name, keeps])
	if not (share > 0.0 and share < 1.0):
		out.append("COMMON_SHARE %s, not between 0 and 1" % share)
	return out


## The ladder in words: each class, its weight and its floor.
static func _ladder_said() -> String:
	var said := PackedStringArray()
	for row: Dictionary in Rarity.LADDER:
		said.append("%s %s, keeping %d" % [row["class"], row["weight"], row["floor"]])
	return ", ".join(said)


## **What is wrong with the classes [param organs]' files give** (gene-rarity.md §11.3
## item 2): a live organ names one of the ladder's in its `water.rarity`; a variant that
## sets its own names one too; a form never sets one -- it is its variant in one place.
## A retired organ needs none, and one it keeps for the record is still a row. And no
## `water` holds a field nothing reads ([constant WATER_FIELDS]): a gene's class is the
## whole of its place in the water.
static func _class_faults(organs: Array) -> Array[String]:
	var out: Array[String] = []
	for organ: Gene in organs:
		out.append_array(_stray_water(String(organ.organ), organ.water))
		for entry: Dictionary in organ.variants:
			var water: Variant = entry.get("water", {})
			if water is Dictionary:
				out.append_array(_stray_water("%s's variant %s" % [organ.organ,
					entry.get("variant", &"")], water))
			var forms: Dictionary = entry.get("forms", {})
			for place: Variant in forms:
				var form: Variant = forms[place]
				if form is Dictionary and (form as Dictionary).get("water", {}) is Dictionary:
					out.append_array(_stray_water("%s's form %s" % [organ.organ,
						(form as Dictionary).get("key", place)], (form as Dictionary).get("water", {})))
		var own: Variant = organ.water.get("rarity")
		if own == null:
			if _live_in_file(organ):
				out.append(("%s names no class in its water: give it `\"rarity\"`, one of %s"
					+ " (gene-rarity.md §4, and game/genes/README.md: when unsure, rare)") % [
					organ.organ, str(Rarity.classes())])
		elif not (own is StringName or own is String) or not Rarity.has(StringName(own)):
			out.append("%s's class %s is no row of the ladder %s" % [organ.organ, own,
				str(Rarity.classes())])
		for entry: Dictionary in organ.variants:
			var water: Variant = entry.get("water", {})
			if water is Dictionary and (water as Dictionary).has("rarity"):
				var mine: Variant = water["rarity"]
				if not (mine is StringName or mine is String) or not Rarity.has(StringName(mine)):
					out.append("%s's variant %s: its class %s is no row of the ladder" % [
						organ.organ, entry.get("variant", &""), mine])
			var forms: Dictionary = entry.get("forms", {})
			for place: Variant in forms:
				var form: Variant = forms[place]
				if form is Dictionary and (form as Dictionary).get("water", {}) is Dictionary \
						and ((form as Dictionary).get("water", {}) as Dictionary).has("rarity"):
					out.append(("%s's form %s sets a class: a form is its variant in one place,"
						+ " as rare as its variant, and never sets one") % [organ.organ,
						(form as Dictionary).get("key", place)])
	return out


## The fields of [param water], [param who]'s, that nothing reads ([constant WATER_FIELDS]).
static func _stray_water(who: String, water: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for field: Variant in water:
		if not WATER_FIELDS.has(String(field)):
			out.append(("%s's water sets %s, which nothing reads: a gene's place in the water"
				+ " is its class (game/genes/README.md, Rarity)") % [who, field])
	return out


## **Organs planted wrong, by how** (item 2): one naming no class, one naming a class the
## ladder has no row for, one whose variant does, one whose form sets a class, and one
## whose water sets a weight beside its class, as the draws read until phase 7-2.
func _planted_classes() -> Dictionary:
	var none := Gene.new()
	none.organ = &"probenone"
	none.water = {"drifter": true}
	var off := Gene.new()
	off.organ = &"probeoff"
	off.water = {"rarity": &"legendary", "drifter": true}
	var variant := Gene.new()
	variant.organ = &"probevariant"
	variant.order = 981
	variant.water = {"rarity": Rarity.commonest()}
	variant.variants = [{"variant": &"odd", "order": 982, "water": {"rarity": &"legendary"}}]
	var formed := Gene.new()
	formed.organ = &"probeformed"
	formed.water = {"rarity": Rarity.commonest()}
	formed.variants = [{"variant": &"plain", "forms": {
		Gene.INSIDE: {"key": &"probeformin", "order": 983},
		Gene.OUTSIDE: {"key": &"probeformout", "order": 984,
			"water": {"rarity": Rarity.classes()[Rarity.LADDER.size() - 1]}}}}]
	var weighed := Gene.new()
	weighed.organ = &"probeweighed"
	weighed.water = {"rarity": Rarity.commonest(), "weight": 4, "drifter": true}
	return {"no class": none, "a class off the ladder": off, "a variant's off it": variant,
		"a form's own": formed, "a weight beside its class": weighed}


## Every class with the live organs that name it, in the ladder's order.
static func _classes_said() -> String:
	var said := PackedStringArray()
	for name: StringName in Rarity.classes():
		var organs: Array[StringName] = []
		for key: StringName in Catalogue.live():
			var organ := Catalogue.organ_of(key)
			if Catalogue.rarity_of(key) == name and not organs.has(organ):
				organs.append(organ)
		said.append("%s %s" % [name, ", ".join(PackedStringArray(organs)) if not organs.is_empty()
			else "none"])
	return "; ".join(said)


## **Whether [param organ]'s file files a live key**: its own, unless it is retired or
## is no key; or a variant not retired.
static func _live_in_file(organ: Gene) -> bool:
	if organ.tags.has(Gene.RETIRED):
		return false
	if organ.variants.is_empty() or organ.order >= 0:
		return true
	for entry: Dictionary in organ.variants:
		if not _says_retired(entry):
			return true
	return false


## **What is wrong with the habitats [param organs]' files name** (gene-rarity.md
## §11.3 item 3): each one a water declares -- `drop.gd`'s HABITATS, none yet -- in a
## list on an organ or a variant, and none on a form.
static func _habitat_faults(organs: Array) -> Array[String]:
	var out: Array[String] = []
	for organ: Gene in organs:
		out.append_array(_strays(String(organ.organ), organ.water))
		for entry: Dictionary in organ.variants:
			var water: Variant = entry.get("water", {})
			if water is Dictionary:
				out.append_array(_strays("%s's variant %s" % [organ.organ,
					entry.get("variant", &"")], water))
			var forms: Dictionary = entry.get("forms", {})
			for place: Variant in forms:
				var form: Variant = forms[place]
				if form is Dictionary and (form as Dictionary).get("water", {}) is Dictionary \
						and ((form as Dictionary).get("water", {}) as Dictionary).has("habitats"):
					out.append("%s's form %s sets habitats: a form never does" % [organ.organ,
						(form as Dictionary).get("key", place)])
	return out


## The habitats [param water] names that no water declares, as [param who]'s.
static func _strays(who: String, water: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not water.has("habitats"):
		return out
	var named: Variant = water["habitats"]
	if not named is Array:
		out.append("%s's habitats are no list" % who)
		return out
	for name: Variant in named:
		if not Drop.HABITATS.has(StringName(name)):
			out.append("%s names the habitat %s, which no water declares (drop.gd's HABITATS:"
				% [who, name] + " %s)" % str(Drop.HABITATS))
	return out


## **The drifters' pool**: every live variety a drifter may be made of -- the water's
## pool without what is tagged `not_on_drifters` -- as the catalogue's weights' share
## of the commons is worked out over it.
static func _drifters_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in Catalogue.drifters():
		if not Catalogue.has_tag(key, Catalogue.NOT_ON_DRIFTERS):
			out.append(key)
	return out


## **The share of the drifters' draw the commons hold** by the catalogue's weights:
## the varieties of every organ of the ladder's first class, against the pool's whole.
## An organ is a common by its own file's class, as the catalogue counts the commons'
## third -- not by a key's, which a rarer variant can make rarer than its organ.
static func _commons_share() -> float:
	var commons := 0.0
	var all := 0.0
	for key: StringName in _drifters_pool():
		var weight := Catalogue.water_weight(key)
		all += weight
		if Catalogue.organ_rarity(Catalogue.organ_of(key)) == Rarity.commonest():
			commons += weight
	return commons / all if all > 0.0 else 1.0


## **The drifters' pool, each variety's `[weight, floor]`** by the catalogue.
static func _pool_weights() -> Array:
	var out: Array = []
	for key: StringName in _drifters_pool():
		out.append([Catalogue.water_weight(key), Catalogue.floor_of(key)])
	return out


## **Today's drifters' pool and [param rares] rare organs more, each variety's `[weight,
## floor]`, worked out by the ladder's own arithmetic** (gene-rarity.md §2.2, §2.3), apart
## from the catalogue's: every organ of today's pool its class's weight -- one variety to
## an organ -- the new ones the ladder's last class, and every organ but the commons
## scaled so that the commons keep their share.
static func _crowd_weights(rares: int) -> Array:
	var rows: Array = []
	for key: StringName in _drifters_pool():
		rows.append([Rarity.weight(Catalogue.rarity_of(key)), Catalogue.floor_of(key),
			Catalogue.rarity_of(key) == Rarity.commonest()])
	var rarest: StringName = Rarity.classes()[Rarity.LADDER.size() - 1]
	for k in rares:
		rows.append([Rarity.weight(rarest), Rarity.least(rarest), false])
	var commons := 0.0
	var rest := 0.0
	for row: Array in rows:
		if bool(row[2]):
			commons += float(row[0])
		else:
			rest += float(row[0])
	var scale := 1.0
	if commons > 0.0 and rest > 0.0 and commons / (commons + rest) < Rarity.COMMON_SHARE:
		scale = commons * (1.0 - Rarity.COMMON_SHARE) / (Rarity.COMMON_SHARE * rest)
	var out: Array = []
	for row: Array in rows:
		out.append([float(row[0]) * (1.0 if bool(row[2]) else scale), int(row[1])])
	return out


## **How many drifters stand in a drop made for a player this [param sighted]**:
## `Drop.food_count` of the share the water calls for (food.gd's `_drifter_share`).
static func _drifters_standing(sighted: float) -> float:
	return Drop.food_count(lerpf(FoodField.BLIND_DRIFTER_SHARE, FoodField.DRIFTER_SHARE, sighted))


## **The floor's expected share of the drifters made**, at each of [constant SIGHTED]
## (gene-rarity.md §5.3): a variety short of its count gets a drifter, which lives as
## long as any, so the floor keeps about as many standing as the draw leaves its
## varieties short -- `Σ E[(floor − X)⁺]`, X a Poisson count of mean `D × share` -- and
## its share is that over D, the drifters standing. [param rows] are `[weight, floor]`.
static func _floor_loads(rows: Array) -> Array[float]:
	var total := 0.0
	for row: Array in rows:
		total += float(row[0])
	var out: Array[float] = []
	for sighted: float in SIGHTED:
		var standing := _drifters_standing(sighted)
		var kept := 0.0
		for row: Array in rows:
			var mean := standing * float(row[0]) / maxf(total, 1e-9)
			kept += _short_of(int(row[1]), mean)
		out.append(kept / maxf(standing, 1e-9))
	return out


## `E[(keeps − X)⁺]` for X Poisson of mean [param mean]: how far short of [param keeps]
## the draw leaves a variety, on average.
static func _short_of(keeps: int, mean: float) -> float:
	var sum := 0.0
	var chance := exp(-mean)
	for k in keeps:
		sum += float(keeps - k) * chance
		chance *= mean / float(k + 1)
	return sum


## Whether any of [param loads] passes the floor's budget, one drifter in GENE_FLOOR_GAP.
static func _over_budget(loads: Array[float]) -> bool:
	for share: float in loads:
		if share >= 1.0 / float(Drop.GENE_FLOOR_GAP):
			return true
	return false


## [param loads] as percentages, a newborn's first.
static func _percents(loads: Array[float]) -> String:
	var said := PackedStringArray()
	for share: float in loads:
		said.append("%.1f %%" % (100.0 * share))
	return " / ".join(said)


## **The water's arithmetic, in words** (gene-rarity.md §11.3 item 5): for each class,
## how many varieties of the drifters' pool are of it and each one's expected drifters
## at the three compositions; the senses' share of the draw; and the floor's expected
## share of the drifters. A pull request that adds genes shows what they cost, here.
static func _arithmetic() -> String:
	var pool := _drifters_pool()
	var total := 0.0
	for key: StringName in pool:
		total += Catalogue.water_weight(key)
	var standing: Array[float] = []
	for sighted: float in SIGHTED:
		standing.append(_drifters_standing(sighted))
	var classes := PackedStringArray()
	for name: StringName in Rarity.classes():
		var least := INF
		var most := 0.0
		var n := 0
		for key: StringName in pool:
			if Catalogue.rarity_of(key) != name:
				continue
			n += 1
			least = minf(least, Catalogue.water_weight(key))
			most = maxf(most, Catalogue.water_weight(key))
		if n == 0:
			classes.append("%s none" % name)
			continue
		var each := PackedStringArray()
		for d: float in standing:
			each.append(("%.1f" % (d * least / total)) if is_equal_approx(least, most)
				else "%.1f-%.1f" % [d * least / total, d * most / total])
		classes.append("%s %d, %s drifters each" % [name, n, " / ".join(each)])
	var senses := 0.0
	for key: StringName in pool:
		if Catalogue.has_tag(key, Catalogue.SENSE):
			senses += Catalogue.water_weight(key)
	var counts := PackedStringArray()
	for d: float in standing:
		counts.append("%.0f" % d)
	return ("%s -- in a drop of %s drifters (a newborn's / a sighted / a fully sighted"
		+ " player's); the senses %.1f %% of the draw; the floor's expected share of the"
		+ " drifters %s, by the weights the water draws by") % ["; ".join(classes),
		" / ".join(counts), 100.0 * senses / maxf(total, 1e-9),
		_percents(_floor_loads(_pool_weights()))]


## **A rare kind of a common organ** (gene-rarity.md §2.2): the first common organ of
## the drifters' pool given one more variant, rare, one entry in its own file -- its
## place in the water taken from its organ alone, `4 × ½ ÷ 4½` of it, every other gene's
## weight what it was; rare itself, kept at one carrier, its organ's own key still common;
## and the catalogue as it was once it is forgotten.
func _rare_kind() -> void:
	var before := _weights_now()
	var common := &""
	for key: StringName in _drifters_pool():
		if Catalogue.rarity_of(key) == Rarity.commonest():
			common = key
			break
	var organ: Gene = (Catalogue.gene(common).get_script() as GDScript).new()
	var rarest: StringName = Rarity.classes()[Rarity.LADDER.size() - 1]
	organ.variants = organ.variants + [{"variant": &"probescarce", "order": 985,
		"look": {"accent": Kinds.MARK_BAR}, "water": {"rarity": rarest}}]
	Catalogue.register(organ)
	var w_common := Rarity.weight(Rarity.commonest())
	var w_rare := Rarity.weight(rarest)
	var shares := [Catalogue.water_weight(&"probescarce"), Catalogue.water_weight(common)]
	var said := [Catalogue.rarity_of(&"probescarce"), Catalogue.floor_of(&"probescarce"),
		Catalogue.rarity_of(common), Catalogue.floor_of(common)]
	var others := 0
	var during := _weights_now()
	for key: StringName in before:
		if key != common and not is_equal_approx(float(during.get(key, -1.0)), float(before[key])):
			others += 1
	# **A pick among the organ's varieties** -- the gift's, whatever their water --
	# takes each by its class's share of the organ.
	seed(985)
	var picked := 0
	const PICKS := 9000
	for i in PICKS:
		if Catalogue.pick_variety([common, &"probescarce"] as Array[StringName]) == &"probescarce":
			picked += 1
	var picks_expected := float(PICKS) * w_rare / (w_common + w_rare)
	Catalogue.forget(Catalogue.organ_of(common))
	var after := _weights_now()
	_check(("a rare kind of %s, one entry in its file, takes its place in the water from its"
		+ " organ alone: %.3f of it to %.3f left (%.3f), %d other genes' weights moved; a pick"
		+ " among the organ's varieties, the gift's, takes it %d times in %d (%.0f by its"
		+ " class's share); it is %s, kept at %d, %s %s at %d; and forgotten, every weight is"
		+ " what it was (%s)") % [common, shares[0], shares[1], w_common, others, picked, PICKS,
		picks_expected, said[0], said[1], common, said[2], said[3], str(after == before)],
		is_equal_approx(float(shares[0]), w_common * w_rare / (w_common + w_rare))
		and is_equal_approx(float(shares[1]), w_common * w_common / (w_common + w_rare))
		and is_equal_approx(float(shares[0]) + float(shares[1]), w_common) and others == 0
		and absf(float(picked) / picks_expected - 1.0) < 0.15
		and said == [rarest, Rarity.least(rarest), Rarity.commonest(),
			Rarity.least(Rarity.commonest())] and after == before)


## **A second strain of the toxin that sets no class splits its organ's place evenly**
## (gene-rarity.md §2.2; dna-slots.md §8.3): the toxin's strains share today's toxin, and
## do not double it.
func _strains_split() -> void:
	var dosed := &""
	for key: StringName in Catalogue.drifters():
		if Catalogue.has_tag(key, Catalogue.FLOOR_BY_PEERS):
			dosed = key
			break
	var whole := Catalogue.water_weight(dosed)
	var organ: Gene = (Catalogue.gene(dosed).get_script() as GDScript).new()
	organ.variants = organ.variants + [{"variant": &"probesplit", "order": 986,
		"look": {"accent": Kinds.MARK_DIAMOND}, "water": {"drifter": true}}]
	Catalogue.register(organ)
	var halves := [Catalogue.water_weight(dosed), Catalogue.water_weight(&"probesplit"),
		Catalogue.rarity_of(&"probesplit")]
	Catalogue.forget(Catalogue.organ_of(dosed))
	_check(("and a second strain of %s that sets no class is its organ's class, %s, and splits"
		+ " its place evenly: %.2f and %.2f of the %.2f it weighed alone, %.2f again once"
		+ " forgotten") % [Catalogue.organ_of(dosed), halves[2], halves[0], halves[1], whole,
		Catalogue.water_weight(dosed)],
		is_equal_approx(float(halves[0]), whole * 0.5) and is_equal_approx(float(halves[1]),
		whole * 0.5) and halves[2] == Catalogue.rarity_of(dosed)
		and is_equal_approx(Catalogue.water_weight(dosed), whole))


## **The commons keep their share** (gene-rarity.md §2.3): uncommon organs of the
## probe's own, three of them, filed until the commons would hold less than
## COMMON_SHARE of the drifters' draw -- they hold it exactly, every common its weight,
## and every other organ scaled alike, in drift as in the water: one set of weights,
## where every variety of an organ is in the pool and drifts.
func _crowded_commons() -> void:
	var before := _weights_now()
	var share_before := _commons_share()
	var common := &""
	var other := &""
	for key: StringName in _drifters_pool():
		if common == &"" and Catalogue.rarity_of(key) == Rarity.commonest():
			common = key
		elif other == &"" and Catalogue.rarity_of(key) != Rarity.commonest():
			other = key
	var uncommon: StringName = Rarity.classes()[1]
	var names: Array[StringName] = [&"probewidea", &"probewideb", &"probewidec"]
	for k in names.size():
		var wide := Gene.new()
		wide.organ = names[k]
		wide.order = 987 + k
		wide.water = {"rarity": uncommon, "drifter": true}
		Catalogue.register(wide)
	var share := _commons_share()
	var weights := [Catalogue.water_weight(common), Catalogue.water_weight(other),
		Catalogue.water_weight(names[0])]
	var unlike: Array[StringName] = []
	for key: StringName in Catalogue.drifters():
		if not is_equal_approx(Catalogue.drift_weight(key), Catalogue.water_weight(key)):
			unlike.append(key)
	for name: StringName in names:
		Catalogue.forget(name)
	var scale := float(weights[1]) / float(before[other])
	_check(("and three uncommon organs of the probe's own crowd the commons from %.1f %% of the"
		+ " drifters' draw: they keep %.1f %%, COMMON_SHARE's, %s its %.1f, %s scaled by %.3f"
		+ " like the newcomers (%.3f), and in drift every variety of the pool weighs what it"
		+ " weighs in the water%s; and forgotten, every weight is what it was (%s)") % [
		100.0 * share_before, 100.0 * share, common, weights[0], other, scale,
		float(weights[2]) / Rarity.weight(uncommon),
		"" if unlike.is_empty() else " -- NOT %s" % str(unlike), str(_weights_now() == before)],
		share_before > Rarity.COMMON_SHARE and is_equal_approx(share, Rarity.COMMON_SHARE)
		and is_equal_approx(float(weights[0]), float(before[common])) and scale < 1.0
		and is_equal_approx(float(weights[2]), Rarity.weight(uncommon) * scale)
		and unlike.is_empty() and _weights_now() == before)


## **A variety the water never makes takes nothing of its organ's place there**
## (gene-catalogue.md §15.8; 7-1's review, its one finding): the first common organ of the
## drifters' pool given one more variant, `"drifter": false`, one entry in its own file.
## **In the water nothing moves**: its own weight is 0 and every other key's is what it
## was -- its sibling keeps the organ's whole place, the commons their share, every other
## organ its weight -- and it is in no pool. **In drift it takes its share of its organ**,
## its class's against its sibling's, from that sibling alone, every other key's drift
## weight what it was. And forgotten, every weight is back.
func _out_of_pool() -> void:
	var before := _weights_now()
	var drifts_before := _drift_weights_now()
	var share_before := _commons_share()
	var common := &""
	for key: StringName in _drifters_pool():
		if Catalogue.organ_rarity(Catalogue.organ_of(key)) == Rarity.commonest() \
				and Catalogue.keys_of_organ(Catalogue.organ_of(key)).size() == 1:
			common = key
			break
	var organ: Gene = (Catalogue.gene(common).get_script() as GDScript).new()
	organ.variants = organ.variants + [{"variant": &"probeaside", "order": 993,
		"look": {"accent": Kinds.MARK_RING}, "water": {"drifter": false}}]
	Catalogue.register(organ)
	var during := _weights_now()
	var drifts := _drift_weights_now()
	var moved: Array[StringName] = []
	for key: StringName in before:
		if not is_equal_approx(float(during.get(key, -1.0)), float(before[key])):
			moved.append(key)
	var drift_moved: Array[StringName] = []
	for key: StringName in drifts_before:
		if key != common and not is_equal_approx(float(drifts.get(key, -1.0)),
				float(drifts_before[key])):
			drift_moved.append(key)
	var said := [Catalogue.water_weight(&"probeaside"), Catalogue.drift_weight(&"probeaside"),
		Catalogue.drift_weight(common), float(drifts_before[common]),
		Catalogue.drifters().has(&"probeaside"), _commons_share(),
		Catalogue.rarity_of(&"probeaside"), Catalogue.floor_of(&"probeaside")]
	Catalogue.forget(Catalogue.organ_of(common))
	var after := [_weights_now() == before, _drift_weights_now() == drifts_before]
	_check(("and a variant of %s the water never makes, one entry in its file with"
		+ " `\"drifter\": false`, takes nothing of its organ's place in the water -- it"
		+ " weighs %.2f there, in no pool (%s), and %d other keys' weights moved, the commons"
		+ " holding %.1f %% as before (%.1f %%) -- while drift may bring it at its share, %.2f,"
		+ " which %s gives up from %.2f to %.2f, %d other keys' drift weights moved; it is %s,"
		+ " kept at %d were it in the water; and forgotten, every weight is back (%s, %s)") % [
		common, said[0], str(said[4]), moved.size(), 100.0 * float(said[5]),
		100.0 * share_before, said[1], common, said[3], said[2], drift_moved.size(), said[6],
		said[7], str(after[0]), str(after[1])],
		moved.is_empty() and float(said[0]) == 0.0 and not bool(said[4])
		and is_equal_approx(float(said[5]), share_before)
		and is_equal_approx(float(said[1]), float(said[3]) * 0.5)
		and is_equal_approx(float(said[2]), float(said[3]) * 0.5)
		and drift_moved.is_empty() and said[6] == Catalogue.rarity_of(common)
		and after == [true, true])


## **The senses by channel, and the gift by two tags** (docs/design/gene-rarity.md §3.4,
## §3.5, §11.3): a second nose of the probe's own -- a sense on the smell channel, and
## no gift -- filed beside today's four. A body wearing the nose at two and the second
## at three sees three tiers, not five; today's four at any copies, their sum. One
## wearing only the second nose needs no gift, from the water (`Drop.give_sense`) or at
## five seconds (`NormalMode.free_sense`), and draws no number for it; a blind one is
## given one of the gift tag's, never it, at any pick -- the water's in the order it
## always drew them. Draws no number, and leaves the catalogue as it was.
func _senses_and_gift() -> void:
	var before := Array(Catalogue.keys())
	var smell := Catalogue.first_on(Catalogue.SMELL)
	var four := {}
	var sum := 0
	var tier := 1
	for sense: StringName in Catalogue.tagged(Catalogue.SENSE):
		four[sense] = tier
		sum += tier
		tier = tier % Genome.TIER_MAX + 1
	var nose := Gene.new()
	nose.organ = &"probenose"
	nose.order = 980
	nose.tags = [Catalogue.SENSE]
	nose.channel = Catalogue.SMELL
	nose.water = {"rarity": Rarity.classes()[Rarity.LADDER.size() - 1]}
	Catalogue.register(nose)
	var sees := [FoodField.sense_tiers({smell: 2, &"probenose": 3}),
		FoodField.sense_tiers({&"probenose": 3}), FoodField.sense_tiers(four),
		FoodField.sense_tiers(Catalogue.born())]
	var rolled := [0]
	var roll := func() -> int:
		rolled[0] += 1
		return rolled[0]
	var worn := {&"cytostome": 1, &"probenose": 1}
	var needs := [Drop.give_sense(worn.duplicate(), Catalogue.tagged(Catalogue.SENSE),
		Drop.water_gifts(), 0), NormalMode.free_sense(worn, roll), rolled[0]]
	var water := {}
	var newborn := {}
	for pick in 8:
		var blind := {&"cytostome": 1}
		Drop.give_sense(blind, Catalogue.tagged(Catalogue.SENSE), Drop.water_gifts(), pick)
		for gene: StringName in blind:
			if gene != &"cytostome":
				water[gene] = true
		newborn[NormalMode.free_sense(Catalogue.born(), roll)] = true
	var lists := [Catalogue.tagged(Catalogue.SENSE).size(), Catalogue.tagged(Catalogue.GIFT).size(),
		Array(Drop.water_gifts()) == Array(Catalogue.tagged(Catalogue.SENSE)).filter(
			func(key: StringName) -> bool: return Catalogue.has_tag(key, Catalogue.GIFT))]
	Catalogue.forget(&"probenose")
	_check(("the senses by channel: %s at two and a second nose at three see %s tiers, the"
		+ " second alone %s, today's four at %s their sum %s, a born cell %s; and the gift by"
		+ " two tags -- a body wearing only the second nose is given none by the water (%s)"
		+ " or at five seconds (%s), drawing %d numbers, and the blind are given %s by the"
		+ " water and %s at five seconds over eight picks, never it -- %d senses, %d gifts,"
		+ " the water's in the senses' order (%s)") % [smell, sees[0], sees[1],
		str(four.values()), sees[2], sees[3], str(not needs[0]), str(needs[1] == &""),
		needs[2], str(water.keys()), str(newborn.keys()), lists[0], lists[1], str(lists[2])],
		sees == [3.0, 3.0, float(sum), 0.0] and needs == [false, &"", 0]
		and water.size() == lists[1] and not water.has(&"probenose")
		and newborn.size() == lists[1] and not newborn.has(&"probenose")
		and not newborn.has(&"") and lists[0] == lists[1] + 1 and lists[2]
		and Array(Catalogue.keys()) == before)


## Every key's weight in the water now, by key.
static func _weights_now() -> Dictionary:
	var out := {}
	for key: StringName in Catalogue.keys():
		out[key] = Catalogue.water_weight(key)
	return out


## Every key's weight in drift now, by key.
static func _drift_weights_now() -> Dictionary:
	var out := {}
	for key: StringName in Catalogue.keys():
		out[key] = Catalogue.drift_weight(key)
	return out


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
		if not row.has("unit") or not row.has("judged") or not row.has("contact") \
				or not row.get("group") is StringName:
			rows_bad.append("%s has no unit, no judged, no contact or no group" % stat)
		else:
			# A group is named by its first stat, which is its own group's and comes first.
			var lead: StringName = row["group"]
			if lead != &"" and (not Stats.ROWS.has(lead) or Stats.ROWS[lead].get("group") != lead
					or Stats.ROWS.keys().find(lead) > Stats.ROWS.keys().find(stat)):
				rows_bad.append("%s is grouped by %s, which is not its group's first stat"
					% [stat, lead])
	_check(("every row says which way is better, how providers combine -- a sum from 0, a"
		+ " product from 1 -- its unit, whether the referee judges it, whether the host"
		+ " decides a contact by it and the group it is read in; judged: %s, contact: %s%s")
		% [str(Stats.judged()), str(Stats.contact()),
			"" if rows_bad.is_empty() else ": " + "; ".join(rows_bad)], rows_bad.is_empty())
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


## **The rulebook has no ceiling on owners** (§13, §15.6): the game's tables and seventy
## owners more, each declaring a sense, an action and an action at level 2, number every
## owner-and-level -- 151 bits, past the one int that held them all -- and the game's
## own bits are where they were. A body with only the last owner, at level 2, has that
## owner's parts and no other's: its rules wake and fire, the first owner's sleep, its
## level's part wakes at 2 and not at 1, and a change draws from it and from what every
## body has, never from an owner it lacks.
func _owner_bits() -> void:
	var tables := [CellBody.DECLARES, Metabolism.DECLARES, Catalogue.declares()]
	var game: Rulebook.Vocabulary = Rulebook.vocabulary(tables)
	var table := {}
	for i in 70:
		table[StringName("probeowner%d" % i)] = {
			"in": [{"name": &"sense", "bearing": false, "values": {&"level": &"level"}}],
			"out": [{"name": &"act", "claims": [&"probeact"]},
				{"name": &"late", "claims": [&"probelate"], "level": 2}]}
	var vocab: Rulebook.Vocabulary = Rulebook.vocabulary(tables + [table])
	var kept := true
	for owner: StringName in game.owners:
		kept = kept and vocab.owners[owner] == game.owners[owner] \
			and str(vocab.levels.get(owner)) == str(game.levels.get(owner))
	for name: StringName in game.inputs:
		kept = kept and (vocab.inputs[name] as Rulebook.InputDecl).bit \
			== (game.inputs[name] as Rulebook.InputDecl).bit
	for name: StringName in game.outputs:
		kept = kept and (vocab.outputs[name] as Rulebook.OutputDecl).bit \
			== (game.outputs[name] as Rulebook.OutputDecl).bit
	var everybody := FoodField.everybody()
	var last := &"probeowner69"
	var at_two := Rulebook.worn(vocab, {last: 2}, everybody)
	var at_one := Rulebook.worn(vocab, {last: 1}, everybody)
	var others := 0
	for owner: StringName in table:
		if owner != last and (Rulebook.has_bit(at_two, int(vocab.owners[owner]))
				or Rulebook.has_bit(at_two, int(vocab.levels[owner][2]))):
			others += 1
	var mine := [Rulebook.has_bit(at_two, int(vocab.owners[last])),
		Rulebook.has_bit(at_two, int(vocab.levels[last][2])),
		Rulebook.has_bit(at_one, int(vocab.levels[last][2]))]
	var list := Rulebook.parse("probeowner69.sense -> probeowner69.act\n"
		+ "probeowner0.sense -> probeowner0.act\nprobeowner69.sense -> probeowner69.late",
		vocab)
	var read := func(_input: StringName) -> Array: return [[0.5]]
	var fired := []
	Rulebook.choose(list, read, at_two, {}, {}, 1, fired)
	var acted: Array = fired.map(func(one: Array) -> int: return int(one[0]))
	Rulebook.choose(list, read, Rulebook.worn(vocab, {&"probeowner0": 2}, everybody), {}, {},
		1, fired)
	var first: Array = fired.map(func(one: Array) -> int: return int(one[0]))
	# A mask of no words has no owner: the last owner's rules, which need only bits
	# past the first word, do not fire for it.
	Rulebook.choose(list, read, PackedInt64Array(), {}, {}, 1, fired)
	var nobody: Array = fired.map(func(one: Array) -> int: return int(one[0]))
	var states := []
	Rulebook.choose(list, read, at_one, {}, {}, 1, fired, states)
	var slept: Array = states.map(func(one: Array) -> String:
		return String(Rulebook.State.keys()[int(one[0])]).to_lower())
	# A change of the first rule, again and again: what it draws is the last owner's, or
	# every body's, or the rulebook's own.
	seed(29)
	var strays: Array[String] = []
	var one := Rulebook.parse("probeowner69.sense -> probeowner69.act", vocab)
	for i in 60:
		var child: Rulebook.Behaviour = Rulebook.changed(one, vocab, at_two,
			{Rulebook.REPLACE: 1.0}, 8)[0]
		for part: StringName in [child.rules[0].input, child.rules[0].output]:
			var owner := String(part).get_slice(".", 0)
			if part != Rulebook.ALWAYS and owner != String(last) \
					and not everybody.has(StringName(owner)) and not strays.has(String(part)):
				strays.append(String(part))
	_check(("the rulebook has no ceiling on owners: the game's tables and 70 owners more number"
		+ " %d bits in %d words, the game's %d where they were (%s); a body with only the last"
		+ " owner has its bits (%s) and %d other's; of a rule of it, one of the first owner's"
		+ " and one of its level 2, the rules that act are %s at its level 2 and say %s at"
		+ " 1, %s for a body with only the first owner and %s for a mask of none; and a"
		+ " change draws nothing it lacks%s") % [vocab.bits, vocab.words, game.bits, str(kept),
		str(mine), others, str(acted), str(slept), str(first), str(nobody),
		"" if strays.is_empty() else ": " + ", ".join(strays)],
		vocab.bits == game.bits + 140 and vocab.words == (vocab.bits + Rulebook.WORD - 1)
			/ Rulebook.WORD and vocab.words >= 3 and game.words == 1 and kept
		and mine == [true, true, false] and others == 0 and acted == [0, 2] and first == [1]
		and nobody.is_empty() and slept == ["acted", "asleep", "asleep"] and strays.is_empty())


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
## it: every stat of the group it reads together (stats.gd's `groups`), the tail
## its hold level, the dart its stun, the beam its shape, its price and its
## levels. Then an organ that calls with no period is registered, to show this
## fails on one -- and that the referee holds it to a rate all the same.
func _mechanics() -> void:
	# **A group is one provider's** (§15.6): the groups are stats.gd's, as they shipped,
	# and each of their stats combines by `best` -- a body takes the whole group from the
	# provider best on its first stat, so a row that said a sum or a product would say
	# what no body does, and the limits read off it (`Stats.top`) would be no bound.
	var groups := Stats.groups()
	var not_best: Array[StringName] = []
	for group: Array in groups:
		for stat: StringName in group:
			if Stats.ROWS[stat]["combine"] != Stats.BEST:
				not_best.append(stat)
	var moved := not _same_list(groups, TOGETHER)
	_check(("the %d groups of stats a mechanic reads together are stats.gd's, as they shipped,"
		% groups.size() + " and every stat of them combines by best%s%s") % [""
		if not_best.is_empty() else ": not %s" % str(not_best), "" if not moved
		else ("; stats.gd's rows group them %s, the probe's TOGETHER %s: what a mechanic"
			+ " reads together changed, so change both, and say why") % [str(groups),
			str(TOGETHER)]],
		not moved and not_best.is_empty())
	var missing := _unanswered()
	for key: StringName in Catalogue.levelled():
		var levels := Catalogue.levels(key)
		if float(levels.get("step", 0.0)) <= 0.0 or int(levels.get("fork", -1)) < 0 \
				or typeof(levels.get("paths")) != TYPE_ARRAY:
			missing.append("%s's levels %s" % [key, str(levels)])
		elif Catalogue.upkeep_at(key, 2, &"") < 0.0:
			missing.append("%s's price per level" % key)
	_check(("every organ a mechanic finds by its stat answers it: all of the %d groups of"
		% Stats.groups().size() + " stats it reads together, the tail its hold level, the dart its"
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
## one line each: a stat of a group (stats.gd's `groups`) missing, or a number
## or hook of the organ's own.
func _unanswered() -> Array[String]:
	var missing: Array[String] = []
	for group: Array in Stats.groups():
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
	organ.water = {"rarity": Rarity.classes()[1]}
	organ.variants = [{"variant": &"plain", "dose": &"harm",
		"water": {"drifter": false}, "tags": [Catalogue.NEVER_DRIFTS],
		"forms": {Gene.INSIDE: {"key": &"probein", "order": 900},
			Gene.OUTSIDE: {"key": &"probeout", "order": 901, "tags": [Catalogue.SENSE],
				"provides": {&"armor": [1.0, 1.25, 1.25, 1.25]}}}}]
	# **Its look, drawn at once**: cilia.gd holds the catalogue's hues and shapes, which
	# every index fills in place, so a new organ's colour -- its family's -- is there
	# without a reload, and every key of it takes its organ's family.
	organ.family = Gene.SENSING
	organ.look = {"shape": Gene.TUFT, "count": 3}
	var bare := Stats.of({&"probeout": 1}, &"armor")
	# **Beside the first live organ of armour** -- whichever it is, so that retiring
	# one is still its tag alone (§16) -- or alone, with none.
	var beside := Catalogue.first_provider(&"armor")
	var pair := {&"probeout": 1}
	if beside != &"":
		pair[beside] = 1
	var other := Stats.value(beside, &"armor", 1)
	Catalogue.register(organ)
	var drawn := [Cilia.hue(&"probeout"), Catalogue.shaped(Gene.TUFT).has(&"probeout")
		and Cilia.hue(&"probein") == Cilia.hue(&"probeout")]
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
		and not Catalogue.drifters().has(&"probein") and Catalogue.rarity_of(&"probeout") \
			== Rarity.classes()[1] and Catalogue.water_weight(&"probeout") == 0.0 \
		and Catalogue.drift_weight(&"probeout") == 0.0 and Catalogue.drift_weight(&"probein") == 0.0
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
	_check(("a registered organ's two forms answer as the toxin's do -- out of the water's pool"
		+ " and never drifting, weighing nothing in the water or in drift though it is %s --"
		+ " and forgetting it leaves the catalogue as it was; its armour reads through the"
		+ " stats at once -- %s alone,"
		+ " %s beside %s, %s again once forgotten (%s before)") % [Rarity.classes()[1],
		read[0], read[1], beside if beside != &"" else "nothing", read[2], bare], filed
		and Array(Catalogue.keys()) == before and not Catalogue.known(&"probein")
		and bare == 1.0 and read[0] == 1.25 and is_equal_approx(read[1], other * 1.25)
		and read[2] == 1.0)
	_check(("and its look is drawn at once, by the dictionaries cilia.gd holds: its family's"
		+ " colour %s while filed, on both forms, a tuft among the tufts, and the unknown"
		+ " tint once forgotten") % str(drawn[0]), drawn[0] == Families.shade(Gene.SENSING)
		and drawn[1] and drawn[2] == Cilia.UNKNOWN_TINT)
	_check("and a variant's and a form's tags add to their organ's, never replace them:"
		+ " outside %s, inside %s" % [str(tags[0]), str(tags[1])], added)
	# **An organ's first variant is one entry** (§6.2): the organ as it shipped keeps
	# its own key, first, with its order and its copies at birth; the entry is filed
	# after it, outside, under its name -- it has no forms and no key of its own --
	# with an order of its own and no copies at birth, though its organ has one.
	var tail := Gene.new()
	tail.organ = &"probetail"
	tail.order = 940
	tail.born = 1
	tail.provides = {&"armor": [1.0, 1.1, 1.1, 1.1]}
	tail.variants = [{"variant": &"probeswift", "order": 941,
		"provides": {&"armor": [1.0, 1.5, 1.5, 1.5]}}]
	Catalogue.register(tail)
	var one_each := true
	for key: StringName in [&"probetail", &"probeswift"]:
		one_each = one_each and Catalogue.known(key) and Catalogue.place_of(key) == Gene.OUTSIDE \
			and Catalogue.variety(key) == key and not Catalogue.has_forms(key) \
			and Catalogue.form_in(key, Gene.OUTSIDE) == key \
			and Catalogue.form_in(key, Gene.INSIDE) == &"" and not Genome.is_inside_form(key)
	var armours := [Stats.of({&"probetail": 1}, &"armor"), Stats.of({&"probeswift": 1}, &"armor")]
	var filed_keys := _keys_of(tail)
	var ranks := [Catalogue.rank(&"probetail"), Catalogue.rank(&"probeswift")]
	var births := [int(Catalogue.born().get(&"probetail", 0)),
		int(Catalogue.born().get(&"probeswift", 0))]
	Catalogue.forget(&"probetail")
	_check(("and an organ's first variant is one entry: the organ keeps its own key, its order"
		+ " and its copies at birth, and the entry is filed after it, outside, under its name,"
		+ " at its own order and born with none -- %s, ranked %s, born %s, armour %s and %s")
		% [str(filed_keys), str(ranks), str(births), armours[0], armours[1]], one_each
		and filed_keys == [&"probetail", &"probeswift"] and armours == [1.1, 1.5]
		and ranks == [940, 941] and births == [1, 0]
		and Array(Catalogue.keys()) == before and not Catalogue.born().has(&"probetail"))


# --- Looks (gene-looks.md §2, §3, §7, §8) ------------------------------------------------

## **Every look, by its family and its kind** (gene-looks.md §8, checks 1 to 5), for
## every live organ, and every retired one that kept its look -- a body wearing it is
## still drawn by it (§16). A retired organ with none draws as a gene this build does
## not know, a plain tuft in no family's colour.
func _looks() -> void:
	var drawn: Array[StringName] = []
	drawn.append_array(Catalogue.live())
	for key: StringName in Catalogue.tagged(Catalogue.RETIRED):
		if not Catalogue.gene(key).look.is_empty():
			drawn.append(key)
	# 1 and 2: a family there is, a kind it is built as, no colour of its own, every
	# parameter its kind's and in range, a shade of three, an accent only on a variant.
	var bad: Array[String] = []
	var kinds := {}
	for key: StringName in drawn:
		var raw: Dictionary = Catalogue.gene(key).look
		var family := Catalogue.family_of(key)
		var kind := StringName(raw.get("shape", &""))
		if not Families.has(family):
			bad.append("%s's family %s" % [key, family if family != &"" else &"(none)"])
		elif not Families.allows(family, kind):
			bad.append("%s's shape %s, which %s is not built as (%s)" % [key, kind, family,
				str(Families.FAMILIES[family]["kinds"])])
		if raw.has("hue"):
			bad.append("%s's hue: its colour is its family's" % key)
		for fault: String in Kinds.faults(raw, not Catalogue.as_shipped(key)):
			if not fault.contains("field hue"):
				bad.append("%s's %s" % [key, fault])
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	_check(("1, 2. every live gene's look is its family's -- a family there is, a kind it is"
		+ " built as, no colour of its own -- and every parameter one its kind knows, in"
		+ " range, a shade of 0, 1 or 2, an accent only on a variant; %d of them, %d retired"
		+ " that kept a look: %s%s") % [drawn.size(), drawn.size() - Catalogue.live().size(),
			str(kinds), "" if bad.is_empty() else "; wrong: %s" % "; ".join(bad)],
		bad.is_empty() and not drawn.is_empty())

	# 3: no two organs of a family alike at a glance -- the same kind and the same
	# structural parameters -- whatever their counts and lengths.
	var organs: Array[StringName] = []
	for key: StringName in drawn:
		if not organs.has(Catalogue.organ_of(key)):
			organs.append(Catalogue.organ_of(key))
	var seen := {}
	var alike: Array[String] = []
	for organ: StringName in organs:
		var shipped: StringName = Catalogue.keys_of_organ(organ)[0]
		var family := Catalogue.family_of(shipped)
		var signature := str(Kinds.signature(Catalogue.gene(shipped).look))
		if not seen.has(family):
			seen[family] = {}
		var mine: Dictionary = seen[family]
		if mine.has(signature):
			alike.append(("%s and %s, both %s %s: tell one apart by a new tip, form or head"
				+ " in kinds.gd -- a count or a length is never a difference")
				% [mine[signature], organ, family, signature])
		else:
			mine[signature] = organ
	var room := PackedStringArray()
	for family: StringName in Families.FAMILIES:
		room.append("%s %d" % [family, (seen.get(family, {}) as Dictionary).size()])
	_check(("3. no two organs of one family are alike at a glance -- the same kind and the"
		+ " same tip, bend, form, waves, turns or lips -- whatever their counts and lengths;"
		+ " builds in use: %s%s") % [", ".join(room),
			"" if alike.is_empty() else "; alike: %s" % "; ".join(alike)], alike.is_empty())

	# 4: every tile fits the tile and the explaining line's row.
	var glyph := Rect2(-Figure.EXPLAIN_ORGAN_SEAT / Figure.EXPLAIN_ORGAN_SCALE,
		Figure.EXPLAIN_ORGAN_SIZE / Figure.EXPLAIN_ORGAN_SCALE)
	var room_box := glyph.intersection(Rect2(-TILE_SIDE * 0.5, -TILE_CENTRE, TILE_SIDE,
		TILE_SIDE))
	var over: Array[String] = []
	var top := 0.0
	var top_key := &""
	for key: StringName in drawn:
		var bounds := Cilia.tile_bounds(key)
		if not room_box.encloses(bounds):
			over.append("%s %s" % [key, str(bounds)])
		if -bounds.position.y > top:
			top = -bounds.position.y
			top_key = key
	_check(("4. every live organ's tile, built as it is drawn and drawn on nothing, stays"
		+ " inside the %.0f px tile and the explaining line's %s glyph box at %.1f -- %s in"
		+ " tile px; the tallest %s, %.1f px above its centre%s") % [TILE_SIDE,
			str(Figure.EXPLAIN_ORGAN_SIZE), Figure.EXPLAIN_ORGAN_SCALE, str(room_box), top_key,
			top, "" if over.is_empty() else "; outside: %s" % "; ".join(over)],
		over.is_empty())

	# 5: every variant but the organ as shipped wears an accent of its own.
	var accents: Array[String] = []
	var worn := 0
	for organ: StringName in organs:
		var keys := Catalogue.keys_of_organ(organ)
		var shipped := Catalogue.variant_of(keys[0])
		var own_mark := StringName(Catalogue.look(keys[0]).get("shipped", Kinds.MARK_NONE))
		var spare := Kinds.ACCENTS.filter(func(mark: StringName) -> bool:
			return mark != own_mark)
		var used := {}
		var variants := {}
		for key: StringName in keys:
			variants[Catalogue.variant_of(key)] = StringName(Catalogue.look(key).get("accent",
				&""))
		for variant: StringName in variants:
			var accent: StringName = variants[variant]
			if variant == shipped:
				if accent != &"":
					accents.append("%s as shipped wears %s: the organ as shipped shows its"
						% [organ, accent] + " seat's own mark")
				continue
			worn += 1
			if not Kinds.ACCENTS.has(accent):
				accents.append("%s's variant %s sets no accent of %s" % [organ, variant,
					str(Kinds.ACCENTS)])
			elif accent == own_mark:
				accents.append("%s's variant %s wears %s, its organ's own mark" % [organ,
					variant, accent])
			elif used.has(accent):
				accents.append("%s's variants %s and %s both wear %s" % [organ,
					used[accent], variant, accent])
			used[accent] = variant
		if variants.size() - 1 > spare.size():
			accents.append(("%s has %d variants besides the organ as shipped and its seat %d"
				+ " marks to spare: make a new organ") % [organ, variants.size() - 1,
				spare.size()])
	# A variant sets its accent and nothing else of a look; a form, nothing of one.
	for organ: Gene in _organs():
		for entry: Dictionary in organ.variants:
			for field: Variant in entry.get("look", {}):
				if not Kinds.VARIANT_FIELDS.has(String(field)):
					accents.append("%s's variant %s sets its look's %s: a variant sets an"
						% [organ.organ, entry.get("variant", &""), field] + " accent and nothing else")
			var forms: Dictionary = entry.get("forms", {})
			for place: Variant in forms:
				if forms[place] is Dictionary and (forms[place] as Dictionary).has("look"):
					accents.append("%s's form %s sets a look: a form wears its variant's"
						% [organ.organ, place])
	_check(("5. every variant but its organ as shipped wears an accent -- a disc, a ring, a"
		+ " diamond or a bar at its kind's seat -- unlike its organ's mark and every"
		+ " sibling's, and sets nothing else of a look; %d variant%s today%s") % [worn,
			"" if worn == 1 else "s", "" if accents.is_empty() else ": %s" % "; ".join(accents)],
		accents.is_empty())


# --- Words (§8.1) and lines (§8.4) -----------------------------------------------------------

## **Every live gene's words**: a chip word and its line; its word and line in
## hand where it is one form of several; a variant's word after its organ's name;
## every way's words where its levels fork; and for every part it declares, its word -- a sense's or an action's -- its
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
		# **A venom says where it works** (the 1b review's finding 4): every provider of
		# `venom_stacks` -- whose mechanic is the bite at the front and a sting on a side
		# or at the stern -- has its line on a side and at the stern, or a second strain
		# would say its front line on the flank.
		if Catalogue.provides(key, &"venom_stacks"):
			needed.append_array([&"side", &"stern"] as Array[StringName])
		# **A variant names itself after its organ** (gene-looks.md §4): every variant
		# but the organ as shipped has its word for `organ · variant`.
		if not Catalogue.as_shipped(key):
			needed.append(&"variant")
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
	# **A dose says what one stack of its own kind does** (the 1b review's finding
	# 4): every live key that delivers one answers its organ's `dose_line`, so a
	# second strain never says harm's.
	var dosed: Array[String] = []
	for key: StringName in Catalogue.live():
		if Catalogue.dose_of(key) == &"":
			continue
		dosed.append(String(key))
		var said: Dictionary = Catalogue.gene(key).dose_line(ctx)
		if said.is_empty():
			bad.append("%s says nothing of a stack of its %s" % [key, Catalogue.dose_of(key)])
	var silent: Array[StringName] = _said_nothing()
	silent.append(&"probeunknown")
	for key: StringName in silent:
		if GeneStats.lines(key, 2, 0, &"", ctx) != [[], []]:
			bad.append("%s draws a row" % key)
	_check(("every live gene says what it does and what it costs on the pause screen -- %d"
		+ " readings, every copy count, level, way and slot -- every key with a dose what a"
		+ " stack of its own kind does (%s), and a key with no lines, %s, draws"
		+ " nothing%s") % [rows_read, ", ".join(dosed),
			str(silent), "" if bad.is_empty() else ": wrong: %s" % ", ".join(bad)],
		bad.is_empty())


# --- Colours (gene-looks.md §1.3, §5, §8) ------------------------------------------------

## **The families' colours, measured** (gene-looks.md §8, checks 6 to 11): each
## family's shades one lightness and a whisper of hue apart; every band clear of every
## other, of self teal and threat red, and -- but eating's -- of food green; the
## families' lightness apart; **every copy of a hue its source's**, and every mark a
## mechanic draws one family's; and every sense on a channel the membrane has a lobe
## for.
func _colours() -> void:
	var bands: Array[String] = []
	var shades: Array = []
	var lightness := {}
	for family: StringName in Families.FAMILIES:
		var row: Array = Families.FAMILIES[family]["shades"]
		if row.size() != 3:
			bands.append("%s has %d shades, not 3" % [family, row.size()])
			continue
		var lch: Array[Vector3] = []
		for i in row.size():
			lch.append(_oklch(row[i]))
			shades.append([family, i, lch[i]])
		var lo := minf(lch[0].x, minf(lch[1].x, lch[2].x))
		var hi := maxf(lch[0].x, maxf(lch[1].x, lch[2].x))
		lightness[family] = (lch[0].x + lch[1].x + lch[2].x) / 3.0
		if hi - lo > SHADE_LIGHTNESS:
			bands.append("%s's shades %.3f apart in lightness" % [family, hi - lo])
		for i in range(1, 3):
			var step := _apart(lch[i - 1].z, lch[i].z)
			if step < SHADE_STEP_MIN or step > SHADE_STEP_MAX:
				bands.append("%s's shades %d and %d %.1f degrees apart" % [family, i - 1, i, step])
	_check(("6. every family's three shades share a lightness within %.2f and step %.1f to"
		+ " %.0f degrees of OKLCH hue: a whisper, never a tier%s") % [SHADE_LIGHTNESS,
			SHADE_STEP_MIN, SHADE_STEP_MAX, "" if bands.is_empty() else ": %s" % "; ".join(bands)],
		bands.is_empty() and Families.FAMILIES.size() == 5)
	var near: Array[String] = []
	var nearest := 360.0
	for i in shades.size():
		for j in range(i + 1, shades.size()):
			if shades[i][0] == shades[j][0]:
				continue
			var gap := _apart((shades[i][2] as Vector3).z, (shades[j][2] as Vector3).z)
			nearest = minf(nearest, gap)
			if gap < BAND_GAP:
				near.append("%s %d and %s %d %.1f" % [shades[i][0], shades[i][1], shades[j][0],
					shades[j][1], gap])
	_check("7. every shade at least %.0f degrees of OKLCH hue from every other family's, the" \
		% BAND_GAP + " nearest %.1f%s" % [nearest, "" if near.is_empty()
			else ": %s" % ", ".join(near)], near.is_empty())
	var marks := {&"self teal": [_oklch(Cilia.SELF_TINT).z, false],
		&"threat red": [_oklch(Cilia.PREDATOR_TINT).z, false],
		&"food green": [_oklch(_color(SignalBus.NUTRIENT_COLOR)).z, true]}
	var meaning: Array[String] = []
	var said := PackedStringArray()
	for mark: StringName in marks:
		var at: float = marks[mark][0]
		var closest := 360.0
		for shade: Array in shades:
			if bool(marks[mark][1]) and shade[0] == Families.EATING:
				continue
			var gap := _apart((shade[2] as Vector3).z, at)
			closest = minf(closest, gap)
			if gap < MEANING_GAP:
				meaning.append("%s %d %.1f from %s" % [shade[0], shade[1], gap, mark])
		said.append("%s %.1f" % [mark, closest])
	_check(("8. every shade at least %.0f degrees from self teal and threat red, and every"
		+ " family's but eating's from food green: %s%s") % [MEANING_GAP, ", ".join(said),
			"" if meaning.is_empty() else "; too near: %s" % ", ".join(meaning)],
		meaning.is_empty())
	var dark: Array[String] = []
	var least := 1.0
	var families: Array = lightness.keys()
	for i in families.size():
		for j in range(i + 1, families.size()):
			var gap := absf(float(lightness[families[i]]) - float(lightness[families[j]]))
			least = minf(least, gap)
			if gap < LIGHTNESS_GAP:
				dark.append("%s and %s %.3f" % [families[i], families[j], gap])
	_check("9. any two families at least %.2f apart in OKLab lightness, the least %.3f%s" % [
		LIGHTNESS_GAP, least, "" if dark.is_empty() else ": %s" % ", ".join(dark)],
		dark.is_empty())

	# 10: every copy of a hue is its source's, and every mark one family's.
	var wrong: Array[String] = []
	var copies := 0
	for lobe: Array in [[&"beam", SignalBus.BEAM_COLOR, Catalogue.BEAM],
			[&"ping", SignalBus.PING_COLOR, Catalogue.PING]]:
		copies += 1
		if not _same(lobe[1], Catalogue.first_on(lobe[2])):
			wrong.append("the membrane's %s lobe" % lobe[0])
		var family := _one_family(Array(Catalogue.tagged(Catalogue.SENSE)).filter(
			func(key: StringName) -> bool: return Catalogue.channel_of(key) == lobe[2]))
		if family == &"":
			wrong.append("the %s channel's organs, of more than one family" % lobe[0])
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
		if _one_family(Array(Catalogue.providers(pad[2]))) == &"":
			wrong.append("the %s pad's organs, of more than one family" % pad[0])
	copies += 1
	var code: Color = Earshot.CODE_COLOR
	if not _same(Vector3(code.r, code.g, code.b), Catalogue.first_on(Catalogue.PING)):
		wrong.append("the earshot's call code")
	# **A variant keeps its organ's colour** (gene-looks.md §3.2): every key of an
	# organ one hue, so no mark moves with the variant a body wears.
	var organs := {}
	for key: StringName in Catalogue.live():
		var organ := Catalogue.organ_of(key)
		if organs.has(organ) and Cilia.hue(key) != Cilia.hue(organs[organ]):
			wrong.append("%s's hue, not its organ %s's" % [key, organ])
		organs[organ] = organs.get(organ, key)
	_check(("10. every one of the %d copies of a hue is its source's -- the membrane's beam"
		+ " and ping lobes, the strain colours, the three pads, the call code -- the light"
		+ " lobe light's own amber; every mark one family's, and every key of an organ its"
		+ " organ's hue%s") % [copies, "" if wrong.is_empty() else "; not: %s" % ", ".join(wrong)],
		wrong.is_empty())

	# 11: every sense drives a channel the membrane has a lobe for.
	var lobeless: Array[String] = []
	for key: StringName in Catalogue.live():
		var channel := Catalogue.channel_of(key)
		if (channel != &"" or Catalogue.has_tag(key, Catalogue.SENSE)) \
				and not SignalBus.CHANNEL_LOBES.has(channel):
			lobeless.append("%s on %s" % [key, channel if channel != &"" else &"(none)"])
	_check(("11. every sense names a channel the membrane has a lobe for -- %s; a new channel"
		+ " is code, a lobe of its own%s") % [str(SignalBus.CHANNEL_LOBES),
			"" if lobeless.is_empty() else ": not %s" % ", ".join(lobeless)],
		lobeless.is_empty())


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
	# newborn's, the born radius and the divide -- by the shipped rows' rule.
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
		if CellBody.slots_for(radius) != _slots_by_rows(SHIPPED_PLAN, radius):
			miscounted.append(radius)
	var outside := _outside_indexes(SHIPPED_PLAN)
	var always := outside.size() - _earned_indexes(SHIPPED_PLAN).size()
	var arcs: Array[Vector2] = []
	var front: Array[int] = []
	var stern := -1
	for k: int in outside:
		arcs.append(SHIPPED_PLAN[k]["arc"])
		match StringName(SHIPPED_PLAN[k]["anatomy"]):
			BodyPlan.FRONT_ANATOMY:
				front.append(k)
			BodyPlan.STERN_ANATOMY:
				stern = k if stern < 0 else stern
	var arcs_ok := true
	for slot in arcs.size():
		arcs_ok = arcs_ok and Cilia.arc_for_slot(slot) == arcs[slot] \
			and Cilia.slot_bearing(slot) == _shipped_bearing(arcs[slot])
	# Every index past them as ever: below, the first earned arc; past, the last.
	arcs_ok = arcs_ok and Cilia.arc_for_slot(-1) == arcs[always] \
		and Cilia.arc_for_slot(arcs.size()) == arcs.back() \
		and Cilia.arc_for_slot(99) == arcs.back() \
		and Cilia.slot_bearing(-1) == _shipped_bearing(arcs[always])
	# The ladder is a step, or every rung for a plan whose ladder is not even: a list
	# here either way, as a pin can write one.
	var ladder: Variant = BodyPlan.ladder()
	var counts := [CellBody.SLOT_MIN, CellBody.SLOT_MAX, Genome.INSIDE, Genome.INSIDE_SLOTS,
		Genome.STERN, Wire.ORDER_MAX, Wire.GENES_MAX,
		Array(ladder) if ladder is PackedFloat64Array else ladder]
	var ring := _same_list(Figure.SLOT_SEAT, SHIPPED_SEATS) \
		and _same_list(Figure.SLOT_NEIGHBOUR, SHIPPED_NEIGHBOURS) \
		and _same_list(Figure.SLOT_RING, SHIPPED_RING)
	var born := BodyPlan.home_layout(Catalogue.born_order())
	var homes: Array[StringName] = []
	var ids := PackedStringArray()
	for row: Dictionary in SHIPPED_PLAN:
		ids.append(String(row["id"]))
		if row.has("home"):
			while homes.size() < SHIPPED_PLAN.find(row):
				homes.append(&"")
			homes.append(StringName(row["home"]))
	var rows_ok := BodyPlan.rows() == SHIPPED_PLAN and BodyPlan.retired() == SHIPPED_RETIRED
	var shipped := rows_ok and miscounted.is_empty() and arcs_ok and counts == SHIPPED_COUNTS \
		and _same_list(Genome.FRONT, front) and Genome.STERN == stern and ring \
		and _same_list(born, homes) and BodyPlan.stamp() == ids
	_check(("and today's plan is the one that shipped: its rows SHIPPED_PLAN's (%s), and by them"
		+ " the slots of %d radii (%s miscounted), the arcs and bearings of every index (%s),"
		+ " the front %s and the stern %d; the counts %s; the ring the figure had written out"
		+ " (%s); a born body seated %s; and the stamp its ids (%s)%s") % [str(rows_ok),
		radii.size(), str(miscounted.slice(0, 4)), str(arcs_ok), str(Genome.FRONT),
		Genome.STERN, str(counts), str(ring), str(born), str(BodyPlan.stamp()),
		"" if shipped else " -- " + PLAN_MOVED], shipped)
	# **The plan saves before stamps were kept under**, held to its own pin and not to
	# SHIPPED_PLAN's ids: today's plan may move, and this may not.
	var before_kept := BodyPlan.BEFORE_STAMPS == SHIPPED_BEFORE_STAMPS
	_check("and the plan every save before stamps was kept under is still the one it was: %s%s"
		% [str(BodyPlan.BEFORE_STAMPS), "" if before_kept else " -- " + BEFORE_MOVED],
		before_kept)
	# **Each check fails a plan that breaks it**: one broken plan a check, swapped in,
	# and today's again after. Each is made from the plan as it shipped, its slots
	# found by place -- the first two earned, the last outside, a home -- so that a
	# change to today's plan never makes one of these miss.
	var broken := {}
	var earned := _earned_indexes(SHIPPED_PLAN)
	var twice := SHIPPED_PLAN.duplicate(true)
	twice[earned[1]]["id"] = twice[earned[0]]["id"]
	broken["twice"] = twice
	var lost := SHIPPED_PLAN.duplicate(true)
	lost.remove_at(earned[1])
	broken["is not known"] = lost
	var overlapping := SHIPPED_PLAN.duplicate(true)
	overlapping[earned[1]]["arc"] = overlapping[earned[0]]["arc"]
	broken["overlap"] = overlapping
	var falling := SHIPPED_PLAN.duplicate(true)
	falling[earned[0]]["earned"] = SHIPPED_PLAN[earned[1]]["earned"]
	falling[earned[1]]["earned"] = SHIPPED_PLAN[earned[0]]["earned"]
	broken["fall"] = falling
	var short := SHIPPED_PLAN.duplicate(true)
	short[outside.back()]["earned"] = CellBody.DIVIDE_RADIUS - 1.0
	broken["DIVIDE_RADIUS"] = short
	var homeless := SHIPPED_PLAN.duplicate(true)
	for row: Dictionary in homeless:
		if row.has("home"):
			row.erase("home")
			break
	broken["home slots"] = homeless
	var crowded := SHIPPED_PLAN.duplicate(true)
	crowded.append({"id": &"inside_two", "place": BodyPlan.INSIDE_PLACE,
		"earned": BodyPlan.ALWAYS})
	broken["no room"] = crowded
	# Two more slots inside: a locus each on the choosing screen, which runs past the
	# canvas's foot (and the pause figure has no seat for them either).
	var tall := crowded.duplicate(true)
	tall.append({"id": &"inside_three", "place": BodyPlan.INSIDE_PLACE,
		"earned": BodyPlan.ALWAYS})
	broken["run off the canvas"] = tall
	var missed: Array[String] = []
	for fault: String in broken:
		BodyPlan.use(broken[fault], SHIPPED_RETIRED)
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
	# **Room on the choosing screen** (normal_mode.gd's `_build_choosing`): a locus a
	# slot between its two caps, and its words under them, above the foot of the
	# shortest canvas there is -- landscape-locked, every one is at least this tall.
	var loci := NormalMode._choose_loci()
	var foot := NormalMode.CHOOSE_COLUMN_TOP + float(loci + 2 * NormalMode.CHOOSE_CAP_LOBES) \
		* NormalMode.CHOOSE_PITCH + NormalMode.CHOOSE_SAYS_GAP + NormalMode.CHOOSE_SAYS_H
	var canvas := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if foot > canvas:
		out.append("the choosing screen's %d loci run off the canvas, to %.0f px of %.0f"
			% [loci, foot, canvas])
	return out


## **A plan of the probe's own, end to end** (§10.3, §12.3): a cell kept under the plan
## as it shipped ([constant SHIPPED_PLAN]) -- in its own file and, as a build before
## slots left it, in a world's -- loaded under [constant PLAN_TEST], every gene in its
## slot by id and the removed slot's gene on the arc nearest it, nothing lost; the
## genome's rules, the venom's sides, the wire's limits and the pause figure on that
## plan; a cell kept under it loaded on the shipped plan again; and today's plan back,
## all of it, after. **Today's plan is never read here**: a change to it fails the
## check that holds it to the pins, and none of these. Every expectation is written by
## slot id and laid out by the plan it is read under.
func _synthetic_plan() -> void:
	var before := _plan_snapshot()
	BodyPlan.use(SHIPPED_PLAN, SHIPPED_RETIRED)
	var dna := {&"cytostome": 2, &"cirrus": 1, &"flagellum": 3, &"ocellus": 1, &"palp": 1,
		&"toxicyst": 2, &"ampulla": 1, &"veneneux": 2}
	# Each gene by the id of its slot: the DNA's; the body's, which still wears the
	# stigma the DNA has since written its eyespot over; and the second daughter's,
	# her eyespot and palp shifted.
	var kept_ids := {&"nose": &"cytostome", &"starboard": &"cirrus", &"tail": &"flagellum",
		&"fore_starboard": &"ocellus", &"fore_port": &"palp", &"aft_starboard": &"toxicyst",
		&"aft_port": &"ampulla"}
	var worn_ids := kept_ids.duplicate()
	worn_ids[&"fore_starboard"] = &"stigma"
	var swapped_ids := kept_ids.duplicate()
	swapped_ids[&"fore_starboard"] = &"palp"
	swapped_ids[&"fore_port"] = &"ocellus"
	var order := _seated(SHIPPED_PLAN, kept_ids)
	var worn := _seated(SHIPPED_PLAN, worn_ids)
	var swapped := _seated(SHIPPED_PLAN, swapped_ids)
	var body := dna.duplicate()
	body.erase(&"ocellus")
	body[&"stigma"] = 1
	var kept := Genome.new()
	kept.express(dna, order, body, worn)
	var state: Dictionary = kept.to_state()
	kept.free()
	# A cell kept before stamps had its slots in the order they were kept under: the
	# pin's, so that a change to BodyPlan.BEFORE_STAMPS is a gene in the wrong slot here.
	var unstamped := state.duplicate(true)
	unstamped.erase("plan")
	unstamped["order"] = _laid_before_stamps(kept_ids)
	unstamped["worn"] = _laid_before_stamps(worn_ids)
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
	var test_ids := _read_by_id(kept_ids, PLAN_TEST, PLAN_TEST_RETIRED)
	var expect_order := _seated(PLAN_TEST, test_ids)
	var expect_worn := _seated(PLAN_TEST, _read_by_id(worn_ids, PLAN_TEST, PLAN_TEST_RETIRED))
	var expect_swapped := _seated(PLAN_TEST, _read_by_id(swapped_ids, PLAN_TEST,
		PLAN_TEST_RETIRED))
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
	# A stamp of no ids is no plan's: a file holding one is refused, as one of the
	# wrong type is.
	var no_ids := cell.duplicate(true)
	no_ids["genome"]["plan"] = PackedStringArray()
	var refused_empty := not BodyPlan.is_stamp(PackedStringArray()) \
		and DropSave.bad_cell(no_ids) != ""
	var daughters: Array = from_cell.get("cell", {}).get("daughters", [])
	var offered := daughters.size() == 2 \
		and _same_list(Genome.layout_from(daughters[0]["order"], daughters[0].get("plan")),
			expect_order) \
		and _same_list(Genome.layout_from(daughters[1]["order"], daughters[1].get("plan")),
			expect_swapped)
	_check(("a body plan of the probe's own -- a slot moved, one removed, two added, %d"
		+ " outside -- holds to every check a plan is held to%s; a cell kept under the plan"
		+ " as it shipped, in its own file and in a world's (written %s, read %s), and one"
		+ " kept before stamps, load with every gene in its slot by id and the removed"
		+ " slot's on the free arc nearest it, the DNA, the body and the inside whole: %s;"
		+ " and the daughters on offer the same (%s); a stamp of no ids is refused (%s)")
		% [_outside_indexes(PLAN_TEST).size(),
		"" if faults.is_empty() else " -- " + "; ".join(faults), str(wrote), str(readable),
		"; ".join(loaded), str(offered), str(refused_empty)],
		faults.is_empty() and wrote == [OK, OK] and readable and by_id and offered
		and refused_empty)

	# **The genome's rules on it**: the counts, the ladder, the places, a move out of
	# its last slot outside, and the venom's side read off the plan.
	var on_plan: Node = genomes[0]
	var outside := _outside_indexes(PLAN_TEST)
	var front: Array[int] = []
	var stern := -1
	for k: int in outside:
		match StringName(PLAN_TEST[k]["anatomy"]):
			BodyPlan.FRONT_ANATOMY:
				front.append(k)
			BodyPlan.STERN_ANATOMY:
				stern = k
	var radii: Array[float] = [FoodField.DRIFTER_MIN, CellBody.BASE_RADIUS, 29.5, 31.0, 34.0,
		37.0, 39.99, CellBody.DIVIDE_RADIUS]
	var ladder: Array[int] = []
	var by_rows: Array[int] = []
	for radius: float in radii:
		ladder.append(CellBody.slots_for(radius))
		by_rows.append(_slots_by_rows(PLAN_TEST, radius))
	# The removed slot's gene, on the arc nearest it, and the one slot left free.
	var moved_from := expect_order.find(test_ids.get(_bow_of(test_ids, kept_ids), &""))
	var moved_to := expect_order.find(&"")
	var moved: bool = on_plan.move(moved_from, moved_to)
	var after_move: Array = on_plan.layout().duplicate()
	var stings := FoodField.toxins_of(body, _worn_of(on_plan))
	var sting_at := NAN
	for k in range(0, stings.size(), FoodField.TOX_STRIDE):
		if int(stings[k]) == FoodField.HOW_STING:
			sting_at = stings[k + 3]
	var venom := expect_worn.find(&"toxicyst")
	var shipped_venom: Vector2 = SHIPPED_PLAN[_outside_indexes(SHIPPED_PLAN)[
		worn.find(&"toxicyst")]]["arc"]
	var many := dna.duplicate()
	many[&"stigma"] = 1
	many[&"chemocyte"] = 1
	var drawn := Cilia.default_order(many)
	_check(("and the genome's rules follow it: slots %s at r13 to r40, its rows' %s; inside"
		+ " from %d with %d, the front %s and the stern %d; the gene in slot %d, its last"
		+ " outside, moves to the free slot %d (%s: %s); the venom on the moved rear diagonal"
		+ " stings along its bearing (%.4f, the plan's %.4f); and a water body's default"
		+ " order seats %d outside") % [str(ladder), str(by_rows), Genome.INSIDE,
		Genome.INSIDE_SLOTS, str(Genome.FRONT), Genome.STERN, moved_from, moved_to, str(moved),
		str(after_move), sting_at, Cilia.slot_bearing(venom), drawn.size()],
		ladder == by_rows and Genome.INSIDE == outside.size()
		and Genome.INSIDE_SLOTS == PLAN_TEST.size() - outside.size()
		and _same_list(Genome.FRONT, front) and Genome.STERN == stern
		and Genome.place_of(outside.size() - 1) == Genome.OUTSIDE_PLACE
		and Genome.place_of(outside.size()) == Genome.INSIDE_PLACE
		and moved_from == outside.back() and moved
		and after_move[moved_to] == expect_order[moved_from] and after_move[moved_from] == &""
		and sting_at == Cilia.slot_bearing(venom) and sting_at != _shipped_bearing(shipped_venom)
		and drawn.size() == outside.size())

	# **The wire's limits follow it**: a body of as many genes as it carries, on every
	# slot it has outside, crosses on it, and the referee takes its order; a plan with
	# fewer slots outside -- the shipped one -- refuses the same frame.
	var ten := body.duplicate()
	ten[&"chemocyte"] = 1
	ten[&"axoneme"] = 1
	var eight: Array[StringName] = expect_worn.duplicate()
	eight[moved_to] = &"chemocyte"
	var frame := Wire.event(1, Wire.EVENT_PERSON, Wire.person_payload(false, ten, eight))
	var crossed := Wire.take_person(frame)
	var limits := [Wire.ORDER_MAX, Wire.GENES_MAX, Wire.PERSON_MAX]
	var genes_max := PLAN_TEST.size() + 1
	var expect_limits := [outside.size(), genes_max, Wire.EVENT_HEADER + 1
		+ (1 + genes_max * (1 + Wire.NAME_MAX + 1)) + (1 + outside.size() * (1 + Wire.NAME_MAX))]
	var fits := Referee._order_fits(ten, eight)

	# **The figure lays it out**: the port flank in the cell the shipped plan leaves
	# empty, the bow on the removed slot's, the ring by bearing, and the inside's arrows.
	var seats := Figure.SLOT_SEAT.duplicate()
	var ring := Figure.SLOT_RING.duplicate()
	var inside_at := _index_in(PLAN_TEST, &"inside")
	var inside_ways: Array = Figure.SLOT_NEIGHBOUR[inside_at].duplicate()

	# **And back**: a cell kept under it, loaded on the shipped plan -- an id that plan
	# never knew takes the first free slot -- and everything today's plan sizes as it
	# was once today's is back.
	var later: Dictionary = (genomes[1] as Node).to_state()
	var offer_later: Array = NormalMode._daughters_by_name([{"tiers": dna,
		"order": (genomes[1] as Node).layout(), "body": body, "mutation": &""}])
	for one: Node in genomes:
		one.free()
	BodyPlan.use(SHIPPED_PLAN, SHIPPED_RETIRED)
	var back_order := _seated(SHIPPED_PLAN, _read_by_id(test_ids, SHIPPED_PLAN, SHIPPED_RETIRED))
	var back_worn := _seated(SHIPPED_PLAN, _read_by_id(_read_by_id(worn_ids, PLAN_TEST,
		PLAN_TEST_RETIRED), SHIPPED_PLAN, SHIPPED_RETIRED))
	var offered_back := _same_list(Genome.layout_from(offer_later[0]["order"],
		offer_later[0].get("plan")), back_order)
	var refused := Wire.take_person(frame).is_empty()
	var home := Genome.new()
	home.set_state(later)
	var round_trip := _same_list(home.layout(), back_order) \
		and _same_list(home.body_layout(), back_worn) and home.dna() == dna \
		and home.tiers() == body and _same_list(back_order, order) and _same_list(back_worn, worn)
	var back_home := "%s / %s" % [str(home.layout()), str(home.body_layout())]
	home.free()
	BodyPlan.restore()
	var fewer := _outside_indexes(SHIPPED_PLAN).size() < outside.size()
	_check(("and the wire's limits follow it -- %s slots, genes and PERSON bytes -- so a body"
		+ " of %d genes on %d slots crosses (%s) and the referee takes its order (%s), where"
		+ " the shipped plan, with %d outside, refuses the same frame (%s)") % [str(limits),
		ten.size(), eight.size(), str(not crossed.is_empty()), str(fits),
		_outside_indexes(SHIPPED_PLAN).size(), str(refused)],
		limits == expect_limits and ten.size() == genes_max and eight.size() == outside.size()
		and crossed.size() == 3 and (crossed[1] as Dictionary) == ten
		and _same_list(crossed[2], eight) and fits and refused == fewer)
	_check(("and the pause figure lays it out: seats %s, Tab round %s, and from the inside"
		+ " left to the port flank, %s") % [str(seats), str(ring), str(inside_ways)],
		seats.size() == PLAN_TEST.size()
		and seats[_index_in(PLAN_TEST, &"port")] == Vector2(-150.0, 0.0)
		and seats[_index_in(PLAN_TEST, &"bow_port")] == Vector2(-150.0, -138.0)
		and seats[_index_in(PLAN_TEST, &"aft_starboard")] == Vector2(150.0, 168.0)
		and seats[inside_at] == Vector2(0.0, 6.0)
		and _same_list(ring, _indexes_of(PLAN_TEST, [&"nose", &"fore_starboard", &"starboard",
			&"aft_starboard", &"tail", &"aft_port", &"port", &"bow_port", &"inside"]))
		and _same_list(inside_ways, _indexes_of(PLAN_TEST, [&"port", &"nose", &"starboard",
			&"tail"])))
	var after := _plan_snapshot()
	for path: String in [cell_path, drop_path]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PLAN_FILES)
	_check(("and a cell kept under it loads on the plan as it shipped with every gene where it"
		+ " was: %s, and a daughter it was offered the same (%s); and today's plan is back,"
		+ " all of it, after (%s)") % [back_home, str(offered_back), str(after == before)],
		round_trip and offered_back and after == before)


## [param by_id] laid out as a cell kept before stamps had it: by the ids it was kept
## under ([constant SHIPPED_BEFORE_STAMPS]), in their order -- never by
## `BodyPlan.BEFORE_STAMPS`, which is what loading it is checked against.
static func _laid_before_stamps(by_id: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in SHIPPED_BEFORE_STAMPS:
		out.append(String(by_id.get(StringName(id), &"")))
	return out


## **The slots [param plan]'s rows give a body of [param radius]**, by its rule: every
## outside slot earned at that radius or below, and never fewer than those always
## earned. What `slots_for` is held to, worked out from the rows alone.
static func _slots_by_rows(plan: Array[Dictionary], radius: float) -> int:
	var count := 0
	var always := 0
	var outside := _outside_indexes(plan)
	for k: int in outside:
		var earned := float(plan[k]["earned"])
		if earned <= BodyPlan.ALWAYS:
			always += 1
		if earned <= radius:
			count += 1
	return clampi(count, always, outside.size())


## **The id the removed slot's gene took** on the probe's plan: the one id of
## [param test_ids] that [param kept_ids] had no gene in.
static func _bow_of(test_ids: Dictionary, kept_ids: Dictionary) -> StringName:
	for id: StringName in test_ids:
		if not kept_ids.has(id):
			return id
	return &""


## The indexes of [param ids] in [param plan], in their order.
static func _indexes_of(plan: Array[Dictionary], ids: Array) -> Array[int]:
	var out: Array[int] = []
	for id: Variant in ids:
		out.append(_index_in(plan, StringName(id)))
	return out


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


## The indexes of [param plan]'s outside rows, in order.
static func _outside_indexes(plan: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for k in plan.size():
		if StringName(plan[k]["place"]) == BodyPlan.OUTSIDE_PLACE:
			out.append(k)
	return out


## The indexes of [param plan]'s outside rows a body earns by growing, in order: those
## earned at a radius, not always.
static func _earned_indexes(plan: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for k: int in _outside_indexes(plan):
		if float(plan[k]["earned"]) > BodyPlan.ALWAYS:
			out.append(k)
	return out


## The index of the row [param id] in [param plan], -1 for none.
static func _index_in(plan: Array[Dictionary], id: StringName) -> int:
	for k in plan.size():
		if StringName(plan[k]["id"]) == id:
			return k
	return -1


## **[param by_id] -- slot id to gene -- as [param plan]'s outside layout**: each gene
## in its id's slot, `&""` in every slot it names none of. How an expectation is
## written by id and laid out by whichever plan it is read under.
static func _seated(plan: Array[Dictionary], by_id: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: int in _outside_indexes(plan):
		out.append(StringName(by_id.get(StringName(plan[k]["id"]), &"")))
	return out


## **[param kept] -- slot id to gene -- as [param plan] reads it** (§10.3), by the rule
## and not by `body_plan.gd`'s code: a gene whose id is [param plan]'s stays in its
## slot; one whose slot left it, among [param gone], goes to the free outside slot
## nearest by bearing the arc it was in; and one whose id it never knew to the first
## free one.
static func _read_by_id(kept: Dictionary, plan: Array[Dictionary],
		gone: Array[Dictionary]) -> Dictionary:
	var out := {}
	var left: Array[StringName] = []
	for id: StringName in kept:
		if _index_in(plan, id) >= 0:
			out[id] = kept[id]
		else:
			left.append(id)
	for id: StringName in left:
		var was := _index_in(gone, id)
		var from: float = BodyPlan.arc_bearing(gone[was]["arc"]) if was >= 0 else NAN
		var best := &""
		var best_off := INF
		for k: int in _outside_indexes(plan):
			var free := StringName(plan[k]["id"])
			if out.has(free):
				continue
			if is_nan(from):
				best = free
				break
			var off := absf(angle_difference(from, BodyPlan.arc_bearing(plan[k]["arc"])))
			if off < best_off:
				best_off = off
				best = free
		if best != &"":
			out[best] = kept[id]
	return out


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


## Whether two lists hold the same values in the same order, whatever their types.
static func _same_list(a: Variant, b: Variant) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		if a[k] != b[k]:
			return false
	return true


# --- A gene of the probe's own, end to end (§12.3) ------------------------------------------

## **The probe's own organ** (§12.3), as an organ's file has it: a gland with **two
## variants, one of them in two places** -- its plain strain inside (`probegin`, which
## keeps a little more) and out (`probegout`, a nose), and a keen strain outside alone
## (`probegkeen`, a better nose) -- with its words, its look and its numbers on the
## pause screen. Its outside forms provide a sense with a place (stats.gd's `SEATED`),
## so a body wearing both smells from the first in slot order; and the probe has it
## declare the part a nose declares, under the same name.
class ProbeGland extends "res://game/genes/gene.gd":
	const Readout := preload("res://game/mechanics/readout.gd")
	const U := Readout.Unit
	const WORDS := {&"probegin": "gland", &"probegout": "gland", &"probegkeen": "keen"}
	const EXPLAINS := {&"probegin": "keeps a little more", &"probegout": "smells a little",
		&"probegkeen": "smells far"}
	## The keen strain's word after its organ's name on the explaining line.
	const VARIANT_WORDS := {&"probegkeen": "keener"}
	## Its look: a sense's hooked bristles; and the keen strain's accent, a ring.
	const KEEN_ACCENT := Kinds.MARK_RING

	func _init() -> void:
		organ = &"probegland"
		water = {"rarity": &"uncommon", "drifter": true}
		family = SENSING
		look = {"shape": TUFT, "count": 3, "tip": Kinds.TIP_HOOK}
		variants = [
			{"variant": &"plain",
				"forms": {
					INSIDE: {"key": &"probegin", "order": 910,
						"provides": {&"store": [1.0, 1.1, 1.2, 1.3]}},
					OUTSIDE: {"key": &"probegout", "order": 911,
						"provides": {&"smell_range": [0.0, 300.0, 400.0, 500.0]}},
				}},
			{"variant": &"keen", "key": &"probegkeen", "order": 912,
				"look": {"accent": KEEN_ACCENT},
				"provides": {&"smell_range": [0.0, 600.0, 800.0, 1000.0]}},
		]

	## Every stat it provides at [param t] copies, and what wearing it costs.
	func lines(t: int, _level: int, _path: StringName, _ctx: Dictionary, _slot: int,
			wear: Dictionary) -> Array:
		var said: Array = []
		for stat: StringName in provides:
			said.append(Readout.item("%s {}" % stat, [stat_at(stat, t)], [U.COUNT]))
		return [said, [wear]]


## **A gene of the probe's own, through every system a gene goes through** (§12.3):
## [ProbeGland] registered, worn, and taken out again. Then the same organ holding one
## variant to a body (`one_variant`, §6.3), and a variant of a shipped organ
## ([method _variant_of_shipped]).
func _synthetic_gene() -> void:
	var before := Array(Catalogue.keys())
	var bits_before := _vocabulary_bits()
	var gland := ProbeGland.new()
	gland.declares = {"in": [_declared_input(&"smell")]}
	Catalogue.register(gland)
	FoodField.declare([])

	# **Filed**: three keys, two varieties, one organ, its place in the water an uncommon
	# organ's, shared evenly by its two strains, which set no class of their own.
	var keys: Array[StringName] = [&"probegin", &"probegout", &"probegkeen"]
	var uncommon := 0.0
	for key: StringName in _drifters_pool():
		if Catalogue.organ_rarity(Catalogue.organ_of(key)) == Rarity.classes()[1] \
				and Catalogue.keys_of_organ(Catalogue.organ_of(key)).size() == 1:
			uncommon = Catalogue.water_weight(key)
			break
	var strains := [Catalogue.water_weight(&"probegin"), Catalogue.water_weight(&"probegkeen"),
		Catalogue.water_weight(&"probegout")]
	var filed := Catalogue.keys().size() == before.size() + 3
	for key: StringName in keys:
		filed = filed and Catalogue.known(key) and Catalogue.organ_of(key) == &"probegland"
	filed = filed and Catalogue.variety(&"probegout") == &"probegin" \
		and Catalogue.variety(&"probegkeen") == &"probegkeen" \
		and Catalogue.has_forms(&"probegin") and not Catalogue.has_forms(&"probegkeen") \
		and Genome.is_inside_form(&"probegin") and not Genome.is_inside_form(&"probegkeen") \
		and Catalogue.drifters().has(&"probegin") and Catalogue.drifters().has(&"probegkeen") \
		and not Catalogue.drifters().has(&"probegout") \
		and uncommon > 0.0 and is_equal_approx(float(strains[0]) + float(strains[1]), uncommon) \
		and is_equal_approx(float(strains[0]), float(strains[1])) and strains[2] == strains[0] \
		and not Catalogue.one_variant(&"probegland")
	_check(("a gene of the probe's own -- an organ with two variants, one in two places --"
		+ " is filed: %s, varieties %s and %s, the organ weighing %.2f in the water, an"
		+ " uncommon organ's, and its strains %.2f and %.2f, the outside form its variety's")
		% [str(keys), Catalogue.variety(&"probegout"), Catalogue.variety(&"probegkeen"),
		float(strains[0]) + float(strains[1]), strains[0], strains[1]], filed)

	# **The genome**: integrated and placed outside -- its outside form -- and inside, the
	# keen strain beside it as a locus of its own, raised alone, moved, expressed.
	var cell: Node = CellBody.new()
	cell.radius = CellBody.DIVIDE_RADIUS
	var genome: Node = Genome.new()
	genome.setup(cell)
	cell.genome = genome
	var steps: Array = []
	steps.append(genome.integrate(&"probegin"))
	steps.append(genome.place(3))
	steps.append(genome.integrate(&"probegkeen"))
	steps.append(genome.place(4))
	steps.append(genome.integrate(&"probegin"))
	steps.append(genome.place(Genome.INSIDE))
	steps.append(genome.integrate(&"probegkeen"))
	var placed: Dictionary = genome.dna().duplicate()
	var moved: bool = genome.move(3, 5)
	genome.express(genome.dna(), genome.layout())
	var layout: Array = genome.layout().duplicate()
	var worn: Dictionary = genome.tiers().duplicate()
	var held := Genome.Result.HELD
	var genome_ok: bool = steps == [held, Genome.Result.INTEGRATED, held, Genome.Result.INTEGRATED,
			held, Genome.Result.INTEGRATED, Genome.Result.RAISED] \
		and int(placed.get(&"probegout", 0)) == 1 and int(placed.get(&"probegin", 0)) == 1 \
		and int(placed.get(&"probegkeen", 0)) == 2 and moved \
		and layout[5] == &"probegout" and layout[4] == &"probegkeen" and layout[3] == &"" \
		and genome.inside_layout().has(&"probegin") and worn == genome.dna()
	# **Mutated**: every kind applies to a DNA holding it, and what each leaves is a
	# genome -- every slot names a gene it carries, no inside form in a slot.
	var kinds := {}
	var sane := true
	seed(3)
	for i in 300:
		var next: Array = Genome.mutated(genome.dna(), genome.layout())
		kinds[next[2]] = int(kinds.get(next[2], 0)) + 1
		for gene: Variant in next[1]:
			if gene != &"" and (not (next[0] as Dictionary).has(gene)
					or Genome.is_inside_form(StringName(gene))):
				sane = false
	genome_ok = genome_ok and sane and kinds.has(&"shift") and kinds.has(&"trade") \
		and kinds.has(&"drift")
	_check(("the genome takes it: integrated, placed outside as its outside form and inside"
		+ " as its inside one, the keen strain a locus of its own raised alone (%s; %s),"
		+ " moved and expressed (%s), and mutated 300 times by every kind (%s), each leaving"
		+ " a genome") % [str(steps), str(placed), str(layout), str(kinds)], genome_ok)

	# **The water**: the spawner draws each strain by its weight in the water, the
	# organ's place shared between them; the floor counts each strain apart; drift
	# brings each.
	seed(11)
	var draws := {}
	var pool: Array[StringName] = Catalogue.drifters().duplicate()
	var total := 0.0
	for key: StringName in pool:
		total += Catalogue.water_weight(key)
	for i in 6000:
		var drawn := FoodField._draw_gene(pool)
		draws[drawn] = int(draws.get(drawn, 0)) + 1
	var gland_draws := int(draws.get(&"probegin", 0)) + int(draws.get(&"probegkeen", 0))
	var expected := 6000.0 * (float(strains[0]) + float(strains[1])) / total
	var keen_share := float(draws.get(&"probegkeen", 0)) / maxf(float(gland_draws), 1.0)
	var counts := {}
	for gene: StringName in Catalogue.drifters():
		counts[gene] = Catalogue.floor_of(gene)
	counts.erase(&"probegin")
	counts.erase(&"probegkeen")
	for body: Dictionary in [{&"probegout": 1}, {&"probegin": 2}, {&"probegkeen": 1}]:
		for gene: StringName in body:
			var kind := Genome.variety(gene)
			counts[kind] = int(counts.get(kind, 0)) + 1
	var queue := Drop.gene_floor()
	Drop.count_floor(queue, counts)
	var short := queue.due
	var short_said := str(queue.short)
	var taken := Drop.take_drifter_gene(queue)
	seed(5)
	var brought := {}
	for i in 600:
		var tiers := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}
		if Genome._mutate_drift(tiers, [] as Array[StringName]):
			for gene: StringName in tiers:
				if Catalogue.organ_of(gene) == &"probegland":
					brought[gene] = int(brought.get(gene, 0)) + 1
	_check(("the water takes it: the spawner draws the organ %d times in 6000 (%.0f by its"
		+ " weight) and the keen strain %.0f%% of them (a half by theirs); the floor counts"
		+ " each strain apart -- two carriers of the plain one in either form, one of the"
		+ " keen -- and gives a drifter the keen one (%s, short %s); and drift brings each"
		+ " (%s)") % [gland_draws, expected, 100.0 * keen_share, taken, short_said,
		str(brought)],
		absf(float(gland_draws) - expected) < expected * 0.25 and keen_share > 0.4
		and keen_share < 0.6 and short.size() == 0 and short_said.contains("probegkeen")
		and not short_said.contains("probegin") and taken == &"probegkeen"
		and brought.has(&"probegkeen") and (brought.has(&"probegin") or brought.has(&"probegout")))

	# **The body**: its stats by their rows, its family's colour on every key and the keen
	# strain told by its accent and named after its organ, and the mechanic with a place
	# acting from the first provider in slot order -- every number of it that one's, its
	# reach too, never the best of the two (stats.gd's `seated`).
	var both := {&"probegout": 2, &"probegkeen": 1}
	var smell := [Stats.of({&"probegout": 2}, &"smell_range"), Stats.of(both, &"smell_range")]
	var store := Stats.of({&"probegin": 3}, &"store")
	var hues := [Cilia.hue(&"probegout"), Cilia.hue(&"probegin"), Cilia.hue(&"probegkeen")]
	var marked := [Cilia.accent_of(&"probegout"), Cilia.accent_of(&"probegkeen"),
		Figure.explain_name(&"probegout"), Figure.explain_name(&"probegkeen")]
	var seats: Array = []
	for worn_layout: Array in [[&"cytostome", &"cirrus", &"flagellum", &"", &"probegkeen",
			&"probegout"], [&"cytostome", &"cirrus", &"flagellum", &"probegout", &"",
			&"probegkeen"]]:
		var body := Catalogue.born().duplicate()
		body.merge(both, true)
		genome.express(body, worn_layout, null, worn_layout)
		var water_order: Array = worn_layout
		seats.append([cell.provider(&"smell_range"), cell.tier_for(&"smell_range"),
			cell.stat(&"smell_range"), FoodField._seat_of(water_order, body, &"smell_range")])
	_check(("the body takes it: a nose of %s alone, %s the most beside the keen strain, as"
		+ " its row says -- what a bound reads -- and %s of store inside; drawn in its family's"
		+ " colour, every key (%s), the keen strain told by its accent and named after its"
		+ " organ (%s); and the smell acts from the first nose in slot order, its reach that"
		+ " nose's, here and in the water: %s") % [smell[0], smell[1], store, str(hues),
		str(marked), str(seats)],
		smell == [400.0, 600.0] and is_equal_approx(store, 1.3)
		and hues == [Families.shade(Gene.SENSING), Families.shade(Gene.SENSING),
			Families.shade(Gene.SENSING)]
		and marked == [&"", ProbeGland.KEEN_ACCENT, "probegout", "probegin · keener"]
		and seats[0] == [&"probegkeen", 1, 600.0, 4] and seats[1] == [&"probegout", 2, 400.0, 3])

	# **Its parts**: wired by the name it declares them under, in a water cell and in
	# yours; a body wearing either strain has them; and no bit a list was read with moved.
	var field: Node = FoodField.new()
	field.call(&"_wire")
	var metabolism: Node = Metabolism.new()
	var own: RefCounted = OwnRules.new()
	own.call(&"setup", cell, field, metabolism, genome)
	var vocab := FoodField.vocabulary()
	var part := &"probegland.smell"
	var owner_bit := int(vocab.owners.get(&"probegland", -1))
	var wears := []
	for strain: Dictionary in [{&"probegkeen": 1}, {&"probegout": 2}, {&"cytostome": 1}]:
		wears.append(Rulebook.has_bit(Rulebook.worn(vocab, Catalogue.by_organ(strain),
			FoodField.everybody()), owner_bit))
	var kept_bits := _bits_kept(bits_before, _vocabulary_bits())
	_check(("its part %s is read in a water cell (%s) and in yours (%s), a body wearing"
		+ " either strain has it and one wearing neither does not (%s), and every bit the"
		+ " vocabulary had is where it was (%s)") % [part,
		str((field.get("_readers") as Dictionary).has(part)),
		str((own.get("_readers") as Dictionary).has(part)), str(wears), kept_bits],
		(field.get("_readers") as Dictionary).has(part)
		and (own.get("_readers") as Dictionary).has(part) and owner_bit >= 0
		and wears == [true, true, false] and kept_bits == "")

	# **The wire, a cell's file and the referee.**
	var body_now: Dictionary = genome.tiers().duplicate()
	var order_now: Array = Array(genome.body_layout())
	var crossed := Wire.take_person(Wire.event(1, Wire.EVENT_PERSON,
		Wire.person_payload(false, body_now, order_now)))
	var state: Dictionary = genome.to_state()
	var kept := _empty_of(DropSave.CELL)
	kept["genome"] = state
	kept["body"]["radius"] = CellBody.DIVIDE_RADIUS
	DirAccess.make_dir_recursive_absolute(PLAN_FILES)
	var path := PLAN_FILES.path_join("gland.save")
	var wrote := CellSave.write(path, CellSave.compose("", "", 0, 0, -1.0, {}, kept))
	var read := CellSave.read(path)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PLAN_FILES)
	var back: Node = Genome.new()
	back.set_state(read.get("cell", {}).get("genome", {}))
	var whole: bool = back.dna() == genome.dna() and back.tiers() == genome.tiers() \
		and _same_list(back.layout(), genome.layout()) \
		and _same_list(back.body_layout(), genome.body_layout()) \
		and _same_list(back.inside_layout(), genome.inside_layout())
	back.free()
	var referee := Referee.new(0.0)
	var took := referee.judge_person(0.0, true, body_now, order_now, false)
	var entered := referee.judge_enter(0.0, CellBody.BASE_RADIUS, false)
	referee.arrive(0.0, Vector2.ZERO, CellBody.BASE_RADIUS)
	var speed := CellBody.swim_speed_of(body_now)
	var at := Vector2.ZERO
	for i in 120:
		at += Vector2(0.0, -speed / 60.0)
		referee.claim(float(i + 1) / 60.0, at, 0.0, CellBody.BASE_RADIUS,
			Vector2(0.0, -speed), 0.0, false)
	var fouls := referee.take_fouls()
	_check(("and the wire carries a body wearing it whole (%s), a cell's file keeps it whole"
		+ " (written %s, %s), and the referee takes that body -- %s, entered %s -- and two"
		+ " seconds of it swimming at its own %.0f u/s with %d fouls") % [
		str(not crossed.is_empty() and crossed[1] == body_now
			and _same_list(crossed[2], order_now)), error_string(wrote), str(whole),
		str(took), str(entered), speed, fouls.size()],
		not crossed.is_empty() and crossed[1] == body_now and _same_list(crossed[2], order_now)
		and wrote == OK and whole and took == [true] and entered and fouls.is_empty())

	# **The pause screen**: its words, and its numbers at every copy count.
	var ctx := GeneStats.context({})
	var rows_ok := true
	var said: Array = []
	for key: StringName in keys:
		for copies in range(1, Genome.TIER_MAX + 1):
			var rows: Array = GeneStats.lines(key, copies, 0, &"", ctx)
			rows_ok = rows_ok and rows.size() == 2 and (rows[0] as Array).size() \
				== Catalogue.gene(key).provides.size() and (rows[1] as Array).size() == 1
		said.append(String(Catalogue.words(key).get(&"word", "")))
	_check("and the pause screen has its numbers at every copy count, and its words: %s"
		% str(said), rows_ok and said == ["gland", "gland", "keen"])

	for node: Node in [field, metabolism, genome, cell]:
		node.free()
	Catalogue.forget(&"probegland")
	FoodField.declare([])

	# **One variant to a body** (§6.3): the same organ, switched on. Placing the keen
	# strain writes over the plain one, in a genome and in a water cell's, and drift
	# brings no strain of it to a lineage that carries one.
	# The floor gives it back through peers, as the toxin's strains, so that the floor
	# below is the one a strain held to one a body meets.
	var single := ProbeGland.new()
	single.one_variant = true
	single.tags = [Catalogue.FLOOR_BY_PEERS]
	Catalogue.register(single)
	var grown: Node = CellBody.new()
	grown.radius = CellBody.DIVIDE_RADIUS
	var one: Node = Genome.new()
	one.setup(grown)
	one.integrate(&"probegin")
	one.place(3)
	one.integrate(&"probegin")
	one.place(Genome.INSIDE)
	var had: Dictionary = one.dna().duplicate()
	one.integrate(&"probegkeen")
	var over_said: Array = one.placing(&"probegkeen", 4)
	one.place(4)
	var after: Dictionary = one.dna().duplicate()
	var after_layout: Array = one.layout().duplicate()
	one.free()
	grown.free()
	var water := {&"cytostome": 1, &"probegout": 2, &"probegin": 1}
	Genome.integrate_into(water, &"probegkeen", CellBody.SLOT_MAX)
	seed(5)
	var again := 0
	for i in 600:
		var tiers := {&"cytostome": 1, &"cirrus": 1, &"probegout": 1}
		if Genome._mutate_drift(tiers, [] as Array[StringName]):
			for gene: StringName in tiers:
				if gene != &"probegout" and Catalogue.organ_of(gene) == &"probegland":
					again += 1
	# **The rest of call 8** (§15.6): a sample of the keen strain left to lapse writes over
	# the plain one in its slot -- with no room, where it used to be gone, and with room
	# -- and the floor gives no peer the keen strain beside the plain one it wears.
	var lapsed := [_lapsed_over(7), _lapsed_over(6)]
	var floor_field: Node = FoodField.new()
	_owe(floor_field, [&"probegkeen"])
	var peer: RefCounted = FoodField.Body.new()
	peer.set(&"radius", CellBody.DIVIDE_RADIUS)
	var peer_worn := Catalogue.born().duplicate()
	peer_worn[&"probegout"] = 1
	peer.set(&"genome", peer_worn)
	floor_field.call(&"_give_back_by_peer", peer)
	var floor_said := [(peer.get(&"genome") as Dictionary).has(&"probegkeen"),
		((floor_field.get(&"_gene_floor") as RefCounted).get(&"due") as Array).has(&"probegkeen"),
		Drop.takes_back({&"probegin": 1}, &"probegkeen"),
		Drop.takes_back(Catalogue.born(), &"probegkeen")]
	floor_field.free()
	var switched := Catalogue.one_variant(&"probegland")
	Catalogue.forget(&"probegland")
	_check(("and switched to one variant a body, placing the keen strain writes over the"
		+ " plain one in both its places (%s, then %s, %s), and says which (%s); a water cell's"
		+ " meal does too (%s), and drift brings no strain of it to a lineage that carries one"
		+ " (%d in 600)") % [str(had), str(after), str(after_layout), str(over_said), str(water),
		again],
		switched and had.has(&"probegout") and had.has(&"probegin")
		and not after.has(&"probegout") and not after.has(&"probegin")
		and int(after.get(&"probegkeen", 0)) == 1 and not after_layout.has(&"probegout")
		and over_said == [Genome.PLACE_WRITE, 4, &"probegout"]
		and water.has(&"probegkeen") and not water.has(&"probegout")
		and not water.has(&"probegin") and again == 0)
	_check(("and a sample of the keen strain left to lapse writes over the plain one in its"
		+ " slot, with no room (%s) and with room (%s); and the floor gives no peer the keen"
		+ " strain beside the plain one it wears -- given %s, still short %s -- nor one that"
		+ " carries the plain one inside (%s), and gives one wearing neither (%s)") % [
		str(lapsed[0]), str(lapsed[1]), str(floor_said[0]), str(floor_said[1]),
		str(floor_said[2]), str(floor_said[3])],
		lapsed == [[3, true], [3, true]] and floor_said == [false, true, false, true])

	_check(("and forgotten, the catalogue and the vocabulary are as they were: %d keys, every"
		+ " bit where it was (%s)") % [Catalogue.keys().size(),
		_bits_kept(bits_before, _vocabulary_bits())],
		Array(Catalogue.keys()) == before and _bits_kept(bits_before, _vocabulary_bits()) == ""
		and _vocabulary_bits().size() == bits_before.size())
	_variant_of_shipped()


## **A variant of a shipped organ** (§6.2, §12.3): a faster tail, as the gene pass will
## write it -- **one entry in the tail's own file**, its speed's table its own and an
## order of its own, registered in that file's place. The tail keeps its key, and the
## variant is born with no copies. The drop's fingerprint and the handshake's see it,
## as the referee's caps do; a body wearing it beside the plain tail is read by the
## stat rows; its parts are the tail's, and the vocabulary does not move; and the
## instincts page offers them to a body that wears it alone.
func _variant_of_shipped() -> void:
	var before := Array(Catalogue.keys())
	var bits_before := _vocabulary_bits()
	var plain := Catalogue.first_provider(&"impulse_speed")
	var rules_before := DropSave.rules_text()
	var NetProbe := load("res://tools/net_probe.gd")
	var wire_before := Rules.text()
	var peak_before := float(NetProbe.call(&"_stacked_peak"))
	var top_before := Stats.top(&"impulse_speed")
	var tail: Gene = (Catalogue.gene(plain).get_script() as GDScript).new()
	var plain_speed: Array = Catalogue.table(plain, &"impulse_speed")
	var swift: Array = []
	for value: Variant in plain_speed:
		swift.append(float(value) * 1.6)
	swift[0] = plain_speed[0]
	var slower: Array = Catalogue.table(plain, &"impulse_gap_min").duplicate()
	for k in range(1, slower.size()):
		slower[k] = float(slower[k]) + 0.4
	var born_before := Catalogue.born().duplicate()
	tail.variants = [{"variant": &"probeswift", "order": 920,
		"look": {"accent": Kinds.MARK_DISC},
		"provides": {&"impulse_speed": swift, &"impulse_gap_min": slower}}]
	var entries := _keys_of(tail)
	Catalogue.register(tail)
	var organ := Catalogue.organ_of(&"probeswift")
	var rules_with := DropSave.rules_text()
	var wire_with := Rules.text()
	var peak_with := float(NetProbe.call(&"_stacked_peak"))
	var top_with := Stats.top(&"impulse_speed")
	var together := {plain: 2, &"probeswift": 1}
	var speeds := [Stats.of({plain: 2}, &"impulse_speed"),
		Stats.of({&"probeswift": 1}, &"impulse_speed"), Stats.of(together, &"impulse_speed")]
	var gaps := [Stats.of({plain: 2}, &"impulse_gap_min"),
		Stats.of({&"probeswift": 1}, &"impulse_gap_min"), Stats.of(together, &"impulse_gap_min")]
	var vocab := FoodField.vocabulary()
	var tails := Rulebook.worn(vocab, Catalogue.by_organ({&"probeswift": 2}), FoodField.everybody())
	var plains := Rulebook.worn(vocab, {plain: 2}, FoodField.everybody())
	var rows: Array = GeneStats.lines(&"probeswift", 2, 0, &"", GeneStats.context({}))
	# The file registered is the one filed, in the shipped file's place: the tail's own key
	# is its record, not a second of it dropped beside the shipped one.
	var born_same := not Catalogue.born().has(&"probeswift") and Catalogue.born() == born_before \
		and Catalogue.gene(plain) == tail and Catalogue.rank(plain) == SHIPPED.find(plain)
	var page := _offered_alike(vocab, organ, &"probeswift", plain)
	# **Drawn as its organ is, plus its accent**: the tail's colour and kind, a disc at
	# its basal body, and `organ · variant` at the head of its line.
	var looks := [Cilia.hue(&"probeswift") == Cilia.hue(plain),
		Catalogue.look(&"probeswift")["shape"] == Catalogue.look(plain)["shape"],
		Cilia.accent_of(&"probeswift"), Cilia.accent_of(plain),
		Figure.explain_name(&"probeswift")]
	var peers := _peers_wearing(&"probeswift", plain)
	var mixed := Catalogue.born().duplicate()
	mixed[&"probeswift"] = 3
	var measured := _tail_levels(mixed, organ)
	Catalogue.forget(organ)
	var rules_after := DropSave.rules_text()
	var wire_after := Rules.text()
	_check(("and a faster %s, one entry in its own file, registered in its place (%s, the"
		+ " tail's key kept and the variant born with none), is %s's own: the drop's"
		+ " rules (%s) and the handshake's (%s) fingerprint it, and are as they were once it is"
		+ " gone; the caps see it -- the fastest a body goes %.0f u/s with it, %.0f without,"
		+ " against the referee's %.0f%s -- and a body wearing it beside the plain tail swims at"
		+ " the faster one's speed with the faster one's gaps, a group being one provider's"
		+ " (%s, %s); its"
		+ " parts are the tail's, bit for bit, in a vocabulary that did not move (%s); and the"
		+ " pause screen reads its own numbers") % [plain, str(entries), organ,
		str(rules_with != rules_before), str(wire_with != wire_before), peak_with, peak_before,
		Referee.SPEED_MAX, ", which net_probe's check of the caps fails on until they move"
			if peak_with >= Referee.SPEED_MAX else "", str(speeds), str(gaps),
		_bits_kept(bits_before, _vocabulary_bits())],
		entries == [plain, &"probeswift"] and organ == Catalogue.organ_of(plain) and born_same
		and rules_with != rules_before and rules_after == rules_before
		and rules_with.contains(Stats.label(&"impulse_speed") + ".probeswift=")
		and wire_with != wire_before and wire_after == wire_before
		and top_with > top_before and peak_with > peak_before
		and speeds[2] == maxf(speeds[0], speeds[1]) and speeds[1] > speeds[0]
		and gaps[2] == gaps[1] and gaps[1] > gaps[0]
		and tails == plains and Rulebook.has_bit(tails, int(vocab.owners.get(organ, -1)))
		and _bits_kept(bits_before, _vocabulary_bits()) == ""
		and rows.size() == 2 and not (rows[0] as Array).is_empty()
		and Array(Catalogue.keys()) == before)
	_check("and it is drawn as its organ is, plus its accent: the same colour and kind %s,"
		% str(looks.slice(0, 2)) + " a %s where the tail wears %s, and named %s" % [looks[2],
			"nothing" if looks[3] == &"" else looks[3], looks[4]],
		looks[0] and looks[1] and looks[2] == Kinds.MARK_DISC and looks[3] == &""
		and looks[4] == "%s · probeswift" % Genome.name_of(plain))
	_check(("and the instincts page offers a body that wears the faster %s alone, or carries"
		+ " it unworn, what it offers one with the plain tail at every copy count -- %s's parts"
		+ " %s, waiting at one copy %s, carried %s -- counting parts by organ, as the body's"
		+ " rules do") % [plain, organ, str(page[1]), str(page[2]), str(page[3])], page[0])
	# **A peer's born organs are its born keys** (§15.6): the organ's other variants stay
	# in its pool -- unless the organ holds one variant to a body.
	var single: Gene = (Catalogue.gene(plain).get_script() as GDScript).new()
	single.one_variant = true
	single.variants = tail.variants
	Catalogue.register(single)
	var peers_single := _peers_wearing(&"probeswift", plain)
	Catalogue.forget(organ)
	_check(("and one measure of a part owner's level: a plain %s at one copy beside the faster"
		+ " one at three works at %d for its rules, at %d for the hand's hold, which can hold it"
		+ " (%s), and at %d in the water, where a rest holds it (%s)") % [plain, measured[0],
		measured[1], str(measured[2]), measured[3], str(measured[4])],
		measured == [3, 3, true, 3, true])
	_check(("and a peer's born organs are its born keys, the organ's other variants left in its"
		+ " pool: of 400 peers made at r40, %d draw the faster %s beside the one they were born"
		+ " with, and %d once the organ holds one variant a body") % [peers, plain, peers_single],
		peers > 0 and peers_single == 0 and Array(Catalogue.keys()) == before)
	_strain_of_shipped()


## **What [param body] works [param organ] at** (gene-catalogue.md §15.6): `[its rules'
## level, your cell's tail level, whether your cell can hold it, a water body's tail
## level, whether a rest holds a water body's]` -- one measure, the rules', for all.
static func _tail_levels(body: Dictionary, organ: StringName) -> Array:
	var cell: Node = CellBody.new()
	var genome: Node = Genome.new()
	genome.setup(cell)
	cell.genome = genome
	genome.express(body, Cilia.default_order(body))
	var yours := [int(cell.tail_level()), bool(cell.can_hold())]
	genome.free()
	cell.free()
	var field: Node = FoodField.new()
	var water: RefCounted = FoodField.Body.new()
	water.set(&"genome", body.duplicate())
	field.call(&"_refresh_body", water)
	field.free()
	return [int(Catalogue.by_organ(body).get(organ, 0)), yours[0], yours[1],
		int(water.get(&"tail_level")),
		int(water.get(&"tail_level")) >= int(water.get(&"stat_hold"))]


## **Where a sample of the probe's keen strain goes when it lapses**, the gland held to
## one variant a body: a cell at the divide radius whose DNA carries the plain strain
## outside, at slot 3, among [param genes] genes outside -- 7 fills every slot. `[the
## slot the keen strain is in afterwards, -1 for none; whether the plain one is gone]`.
static func _lapsed_over(genes: int) -> Array:
	var cell: Node = CellBody.new()
	cell.radius = CellBody.DIVIDE_RADIUS
	var genome: Node = Genome.new()
	genome.setup(cell)
	var dna := {}
	var order: Array[StringName] = [&"cytostome", &"cirrus", &"flagellum", &"probegout",
		&"chemocyte", &"ampulla", &"stigma"]
	order.resize(genes)
	for gene: StringName in order:
		dna[gene] = 1
	genome.express(dna, order)
	genome.integrate(&"probegkeen")
	genome.call(&"_process", Genome.SAMPLE_SECONDS + 1.0)
	var out := [genome.layout().find(&"probegkeen"), not genome.dna().has(&"probegout")]
	genome.free()
	cell.free()
	return out


## **The gene floor of [param field] as a count that found [param genes] short leaves
## it** (docs/design/gene-rarity.md §3.3): every one of them due, in that order, and its
## budget as it was -- the seam a check poses a short gene through (food.gd's
## `_gene_floor`).
static func _owe(field: Object, genes: Array) -> void:
	var queue: RefCounted = field.get(&"_gene_floor")
	queue.call(&"restore", genes, genes, int(queue.get(&"since")))


## **How many of 400 peers made at r40 wear [param variant] beside [param plain]**:
## the drop's own peer, `food.gd`'s `_draw_living`, on a seeded stream.
static func _peers_wearing(variant: StringName, plain: StringName) -> int:
	var field: Node = FoodField.new()
	seed(17)
	var wearing := 0
	for i in 400:
		var peer: Dictionary = field.call(&"_draw_living", CellBody.DIVIDE_RADIUS, 1.0)
		if peer.has(variant) and peer.has(plain):
			wearing += 1
	field.free()
	return wearing


## **What the instincts page offers a body of [param variant] alone, against one of
## [param plain] alone** -- worn at every copy count, and carried unworn -- through the
## page's own `ProgramsPage.offers`: `[alike, parts, waiting, carried]`. `alike` holds
## when each pair is the same offer and the variant's body is offered every part
## [param organ] declares, worn and carried; `parts` are those parts, and `waiting`
## and `carried` what the variant's body was offered as such at one copy.
static func _offered_alike(vocab: Rulebook.Vocabulary, organ: StringName, variant: StringName,
		plain: StringName) -> Array:
	var parts: Array[StringName] = []
	for table: Dictionary in [vocab.inputs, vocab.outputs]:
		for name: StringName in table:
			if StringName((table[name] as Object).get(&"owner")) == organ:
				parts.append(name)
	var alike := not parts.is_empty()
	var waiting := {}
	var carried := {}
	for copies in range(1, Genome.TIER_MAX + 1):
		var worn := {variant: copies}
		var plain_worn := {plain: copies}
		var as_variant: Dictionary = ProgramsPage.offers(vocab, worn, worn)
		var unworn: Dictionary = ProgramsPage.offers(vocab, worn, {})
		alike = alike and as_variant == ProgramsPage.offers(vocab, plain_worn, plain_worn) \
			and unworn == ProgramsPage.offers(vocab, plain_worn, {})
		for part: StringName in parts:
			alike = alike and ((as_variant["inputs"] as Array).has(part)
				or (as_variant["outputs"] as Array).has(part)) \
				and not (as_variant["carried"] as Dictionary).has(part) \
				and (unworn["carried"] as Dictionary).has(part)
		if copies == 1:
			waiting = as_variant["waiting"]
			carried = unworn["carried"]
	return [alike, parts, waiting, carried]


## **A second strain of the shipped organ with a dose** -- the toxin's -- as one
## entry of one place in that organ's own file (gene-catalogue.md §6.4), registered
## in its place: every rule that was the toxin's special case covers it by its
## organ's tags, so no drifter carries it and the floor gives it back through a
## peer, into the one place it has; its venom is delivered at the front and on a
## side, by its own kind; and its lines say what a stack of that kind does.
func _strain_of_shipped() -> void:
	var before := Array(Catalogue.keys())
	var dosed := &""
	for key: StringName in Catalogue.live():
		if Catalogue.dose_of(key) != &"" and Catalogue.provides(key, &"venom_stacks"):
			dosed = key
			break
	var organ: Gene = (Catalogue.gene(dosed).get_script() as GDScript).new()
	var stacks: Array = Catalogue.table(dosed, &"venom_stacks")
	var shipped := Catalogue.keys_of_organ(Catalogue.organ_of(dosed)).duplicate()
	organ.variants = organ.variants + [{"variant": &"probebarb", "dose": Catalogue.dose_of(dosed),
		"order": 930, "water": {"drifter": true},
		"look": {"accent": Kinds.MARK_DIAMOND},
		"provides": {&"venom_stacks": stacks}}]
	Catalogue.register(organ)
	var kept := Array(Catalogue.keys_of_organ(Catalogue.organ_of(dosed))) \
		== Array(shipped) + [&"probebarb"]
	var strain := &"probebarb"
	var tagged := Catalogue.has_tag(strain, Catalogue.NOT_ON_DRIFTERS) \
		and Catalogue.has_tag(strain, Catalogue.FLOOR_BY_PEERS)
	var drifting := Drop.drifter_genes(Catalogue.drifters()).has(strain)
	var short := Drop.gene_floor()
	short.restore([strain], [strain], short.since)
	var to_drifter := Drop.take_drifter_gene(short)
	var field: Node = FoodField.new()
	_owe(field, [strain])
	var by_peer: StringName = field.call(&"_peer_short")
	field.free()
	var peer := Catalogue.born().duplicate()
	Drop.give_back(peer, strain, CellBody.SLOT_MAX, Catalogue.tagged(Catalogue.SENSE), 0, true)
	var kind := float(Doses.kind_of(Catalogue.dose_of(strain)))
	var bite := FoodField.toxins_of({strain: 2}, [strain])
	var side := FoodField.toxins_of({strain: 2}, [&"", strain])
	var said := Catalogue.gene(strain).dose_line(GeneStats.context({}))
	# **Its beads are its accent** (gene-looks.md §3.3): the toxin's colour, diamonds.
	var beads := [Cilia.hue(strain) == Cilia.hue(dosed), Cilia.accent_of(strain),
		Figure.explain_name(strain)]
	var gone := Catalogue.organ_of(strain)
	Catalogue.forget(gone)
	_check(("and a second strain of %s, one entry of one place in its own file (its first"
		+ " strain's keys kept: %s), is covered by every rule"
		+ " that was the toxin's: tagged %s, no drifter carries it (%s), the floor gives it"
		+ " back through a peer (%s), into its one place (%s); its venom bites at the front"
		+ " and stings on a side, by its own kind (%s; %s); it says what a stack of its"
		+ " dose does; and it is the toxin's colour with %s beads, named %s") % [gone,
		str(kept), str(tagged), str(not drifting and to_drifter == &""), by_peer,
		str(peer.get(strain, 0)), str(bite), str(side), beads[1], beads[2]],
		kept and tagged and not drifting and to_drifter == &"" and by_peer == strain
		and int(peer.get(strain, 0)) == 1
		and bite == PackedFloat64Array([FoodField.HOW_BITE, kind, float(stacks[2]), 0.0])
		and side == PackedFloat64Array([FoodField.HOW_STING, kind, float(stacks[2]),
			Cilia.slot_bearing(1)])
		and not said.is_empty() and Array(Catalogue.keys()) == before
		and beads == [true, Kinds.MARK_DIAMOND, "%s · probebarb" % Genome.name_of(dosed)])
	_person_order()
	_seated_one_organ()


## **A person's order is written before its genome** (gene-catalogue.md §15.6): with a
## second dart -- one entry in the dart's own file, its stun its own -- a person who
## wears both and moves them round is read under the order they wear them in now, by a
## replay's field and by a pond's: the dart that fires first in slot order is the one
## whose stun its body has. Both ways round, so neither dart passes by being first in
## the catalogue's order.
func _person_order() -> void:
	var before := Array(Catalogue.keys())
	var dart := Catalogue.first_provider(&"dart_range")
	var organ: Gene = (Catalogue.gene(dart).get_script() as GDScript).new()
	organ.variants = [{"variant": &"probestun", "order": 950, "numbers": {&"stun": 9.0},
		"look": {"accent": Kinds.MARK_BAR}}]
	Catalogue.register(organ)
	var body := Catalogue.born().duplicate()
	body[dart] = 1
	body[&"probestun"] = 1
	var first: Array = Array(Catalogue.born_order()) + [dart, &"probestun"]
	var second: Array = Array(Catalogue.born_order()) + [&"probestun", dart]
	var cell: Node = CellBody.new()
	var field: Node = FoodField.new()
	field.call(&"open_replay", cell, 0)
	field.call(&"open_replay_person")
	var cells: Array = field.get(&"_cells")
	var stuns := []
	for orders: Array in [[first, second], [second, first]]:
		field.call(&"restore_person_genome", body, orders[0])
		field.call(&"restore_person_genome", body, orders[1])
		stuns.append(float((cells[FoodField.PERSON_SLOT] as Object).get(&"stat_dart_stun")))
		field.call(&"set_person_genome", body, orders[0])
		field.call(&"set_person_genome", body, orders[1])
		stuns.append(float((cells[FoodField.PERSON_SLOT] as Object).get(&"stat_dart_stun")))
	var own := float(Catalogue.number(dart, &"stun"))
	field.free()
	cell.free()
	Catalogue.forget(Catalogue.organ_of(dart))
	_check(("and a person's order is written before its genome: wearing a second dart beside"
		+ " %s and moving them round, its stun is the dart first in slot order now -- %s, by"
		+ " a replay's field and a pond's, each way round") % [dart, str(stuns)],
		stuns == [9.0, 9.0, own, own] and own != 9.0 and Array(Catalogue.keys()) == before)


## **A seated mechanic is one organ's** (§5.2, §15.6; stats.gd's `SEATED`): a body
## wearing two organs of a mechanic with a place -- the second one entry in the first's
## own file, every number of it its own -- acts from the one first in slot order and
## takes every number from it, never another organ's beside it. Each way round, so
## neither passes by being first in the catalogue's order or best on its reach:
##
## - **two darts**, read by the stats (`Stats.seated`), by your cell, by a water cell
##   and by a person: the reach, the rest, the stun and the copies of the dart that
##   fires ([method _seated_darts]);
## - **two radars**, read by your cell, by a water cell's eye and by the referee a host
##   judges your calls by: the reach, the period, the pass and the copies of the one
##   that calls ([method _seated_radars]);
##
## and the rules two builds agree on carry it (rules.gd): a line naming the seat of
## each judged or contact stat of the two once a second organ provides it, and none
## while one does.
func _seated_one_organ() -> void:
	var shipped := Rules.text()
	_seated_darts(shipped)
	_seated_radars(shipped)


func _seated_darts(shipped: String) -> void:
	var before := Array(Catalogue.keys())
	var dart := Catalogue.first_provider(&"dart_range")
	var organ: Gene = (Catalogue.gene(dart).get_script() as GDScript).new()
	var reach: Array = Catalogue.table(dart, &"dart_range").duplicate()
	var rest: Array = Catalogue.table(dart, &"dart_cooldown").duplicate()
	for k in range(1, reach.size()):
		reach[k] = float(reach[k]) * 1.5
		rest[k] = float(rest[k]) + 1.0
	organ.variants = [{"variant": &"probefar", "order": 960, "numbers": {&"stun": 9.0},
		"look": {"accent": Kinds.MARK_BAR},
		"provides": {&"dart_range": reach, &"dart_cooldown": rest}}]
	Catalogue.register(organ)
	var text := Rules.text()
	var dna := Catalogue.born().duplicate()
	dna[dart] = 2
	dna[&"probefar"] = 1
	var orders := [Array(Catalogue.born_order()) + [dart, &"probefar"],
		Array(Catalogue.born_order()) + [&"probefar", dart]]
	# What the dart first in slot order gives, each way round: its reach, its rest, its
	# stun and its copies -- the shipped dart at two, the far one at one.
	var wanted := [[Stats.value(dart, &"dart_range", 2), Stats.value(dart, &"dart_cooldown", 2),
			float(Catalogue.number(dart, &"stun")), 2],
		[float(reach[1]), float(rest[1]), 9.0, 1]]
	var cell: Node = CellBody.new()
	var field: Node = FoodField.new()
	field.call(&"open_replay", cell, 0)
	field.call(&"open_replay_person")
	field.call(&"restore_person", Vector2.ZERO, 0.0, CellBody.DIVIDE_RADIUS, 0.0, 0.0, true)
	var person: Object = (field.get(&"_cells") as Array)[FoodField.PERSON_SLOT]
	var got := []
	for k in 2:
		var order: Array = orders[k]
		var read := [[Stats.seated(order, dna, &"dart_range"),
			Stats.seated(order, dna, &"dart_cooldown"), CellBody.dart_stun(dna, order),
			Stats.seated_tier(order, dna, &"dart_range")]]
		# Your cell, its genome expressed in that order.
		var yours: Node = CellBody.new()
		yours.radius = CellBody.DIVIDE_RADIUS
		var genome: Node = Genome.new()
		genome.setup(yours)
		genome.express(dna, order)
		yours.genome = genome
		read.append([yours.stat(&"dart_range"), yours.stat(&"dart_cooldown"),
			CellBody.dart_stun(yours.worn(), yours.seats()), yours.tier_for(&"dart_range")])
		genome.free()
		yours.free()
		# A water cell wearing it in that order, and a person, as a pond writes one.
		var water := FoodField.Body.new()
		water.order = order
		water.genome = dna.duplicate()
		read.append([water.stat_dart_range, water.stat_dart_cooldown, water.stat_dart_stun,
			water.stat_dart_tier])
		field.call(&"set_person_genome", dna, order)
		var p: Object = person.get(&"person")
		read.append([float(p.get(&"dart_range")), float(p.get(&"dart_cooldown")),
			float(person.get(&"stat_dart_stun")), int(person.get(&"stat_dart_tier"))])
		got.append(read)
	field.free()
	cell.free()
	Catalogue.forget(Catalogue.organ_of(dart))
	var mixed := _mixed(got, wanted, ["the shipped dart first", "the far one first"],
		["the stats", "your cell", "a water cell", "a person"])
	var stray := _seats_in(shipped)
	if not stray.is_empty():
		mixed.append("with one organ to each, the shipped rules name seats all the same: "
			+ ", ".join(PackedStringArray(stray)))
	var seats := _seat_lines(text, [&"dart_range", &"dart_cooldown"], &"dart_range")
	_check(("and a mechanic with a place is one organ's: wearing two darts, %s and a far one"
		+ " with a longer reach, a longer rest and a stun of its own, the stats, your cell,"
		+ " a water cell and a person each take the reach, the rest, the stun and the copies"
		+ " of the dart first in slot order, each way round -- %s and %s; and the rules name"
		+ " the dart's seat once two organs dart (%s), and no seat while one does%s") % [dart,
		str(wanted[0]), str(wanted[1]), seats, "" if mixed.is_empty() else ": "
		+ "; ".join(PackedStringArray(mixed))],
		mixed.is_empty() and wanted[0] != wanted[1] and seats == "both"
		and Array(Catalogue.keys()) == before)


func _seated_radars(shipped: String) -> void:
	var before := Array(Catalogue.keys())
	var radar := Catalogue.first_provider(&"ping_range")
	var organ: Gene = (Catalogue.gene(radar).get_script() as GDScript).new()
	var reach: Array = Catalogue.table(radar, &"ping_range").duplicate()
	var period: Array = Catalogue.table(radar, &"ping_period").duplicate()
	var through: Array = Catalogue.table(radar, &"ping_through").duplicate()
	for k in range(1, reach.size()):
		reach[k] = float(reach[k]) * 1.5
		period[k] = float(period[k]) + 4.0
		through[k] = 0.9
	organ.variants = [{"variant": &"probeloud", "order": 961,
		"look": {"accent": Kinds.MARK_BAR},
		"provides": {&"ping_range": reach, &"ping_period": period, &"ping_through": through}}]
	Catalogue.register(organ)
	var text := Rules.text()
	var ways: Array = [[radar, &"probeloud"], [&"probeloud", radar]]
	# What the radar first in slot order gives, each way round -- the shipped one at two
	# copies, the loud one at one: its reach, its period, its pass and its copies, and
	# to the referee its reach and the calls a second its period allows.
	var wanted := [[Stats.value(radar, &"ping_range", 2), Stats.value(radar, &"ping_period", 2),
			Stats.value(radar, &"ping_through", 2), 2],
		[float(reach[1]), float(period[1]), float(through[1]), 1]]
	for one: Array in wanted:
		one.append(1.0 / maxf(float(one[1]) - Referee.SHOUT_EARLY, 1.0))
	var field: Node = FoodField.new()
	var got := []
	for k in 2:
		var pair: Array = ways[k]
		# Its tiers written in that order too, as a water cell's slots follow them.
		var dna := Catalogue.born().duplicate()
		for key: StringName in pair:
			dna[key] = 2 if key == radar else 1
		var order: Array = Array(Catalogue.born_order()) + pair
		var read := []
		var yours: Node = CellBody.new()
		yours.radius = CellBody.DIVIDE_RADIUS
		var genome: Node = Genome.new()
		genome.setup(yours)
		genome.express(dna, order)
		yours.genome = genome
		read.append([yours.ping_range(), yours.ping_period(), yours.ping_through(),
			yours.ping_tier(), _rate_of(yours.ping_period())])
		genome.free()
		yours.free()
		var water := FoodField.Body.new()
		water.radius = CellBody.BASE_RADIUS
		water.genome = dna.duplicate()
		var eye: Object = field.call(&"_eye_of", water)
		read.append([float(eye.get(&"ping_range")), float(eye.get(&"ping_period")),
			float(eye.get(&"ping_through")), int(eye.get(&"ping_tier")),
			_rate_of(float(eye.get(&"ping_period")))])
		# The referee, told the body in that order; and one told it the other way round
		# first, then this way -- the same tiers, its radars moved -- which keeps the
		# reach it had for the calls on their way.
		var ref := Referee.new(0.0)
		ref.judge_person(0.0, true, dna, order, false)
		read.append([float(ref.call(&"_reach")), wanted[k][1], wanted[k][2], wanted[k][3],
			float(ref.shouts.rate)])
		var moved := Referee.new(0.0)
		moved.judge_person(0.0, true, dna, Array(Catalogue.born_order()) + [pair[1], pair[0]],
			false)
		var had := float(moved.call(&"_reach"))
		var took: Array = moved.judge_person(1.0, false, dna, order, false)
		read.append([float(moved.call(&"_reach")), wanted[k][1], wanted[k][2], wanted[k][3],
			float(moved.shouts.rate)] if took == [false]
				and is_equal_approx(float(moved.get(&"_reach_before")), had) else [took])
		got.append(read)
	field.free()
	Catalogue.forget(Catalogue.organ_of(radar))
	var mixed := _mixed(got, wanted, ["the shipped radar first", "the loud one first"],
		["your cell", "a water cell's eye", "the referee", "the referee, its radars moved"])
	var stray := _seats_in(shipped)
	if not stray.is_empty():
		mixed.append("with one organ to each, the shipped rules name seats all the same: "
			+ ", ".join(PackedStringArray(stray)))
	var seats := _seat_lines(text, [&"ping_range", &"ping_period"], &"ping_range")
	_check(("and so is a radar: wearing two, %s and a loud one calling further, slower and"
		+ " through more, your cell, a water cell's eye and the referee each take the reach,"
		+ " the period, the pass and the copies of the one first in slot order, each way"
		+ " round -- %s and %s -- the referee its reach and its calls a second, and the same"
		+ " body said in its other order moves them, keeping the old reach for the calls on"
		+ " their way; and the rules name the radar's seat once two organs call (%s), and no"
		+ " seat while one does%s") % [radar, str(wanted[0]), str(wanted[1]), seats,
		"" if mixed.is_empty() else ": " + "; ".join(PackedStringArray(mixed))],
		mixed.is_empty() and wanted[0] != wanted[1] and seats == "both"
		and Array(Catalogue.keys()) == before)


## **Calls a second a referee allows at [param period]** (referee.gd's `_shout_rate`).
static func _rate_of(period: float) -> float:
	return 1.0 / maxf(period - Referee.SHOUT_EARLY, 1.0)


## **Where [param got] mixes**: each reader's row, by way, against what the organ
## first in slot order gives, as `way, reader: got, not wanted`.
static func _mixed(got: Array, wanted: Array, ways: Array, who: Array) -> Array[String]:
	var mixed: Array[String] = []
	for k in ways.size():
		for w in who.size():
			if str(got[k][w]) != str(wanted[k]):
				mixed.append("%s, %s: %s, not %s" % [ways[k], who[w], str(got[k][w]),
					str(wanted[k])])
	return mixed


## **Whether [param text] names [param seat] as the seat of every stat of [param stats]**
## (rules.gd): `both` when it does, else the lines it has.
static func _seat_lines(text: String, stats: Array, seat: StringName) -> String:
	var found := _seats_in(text)
	var want: Array[String] = []
	for stat: StringName in stats:
		want.append("stat.%s.seat=%s" % [stat, seat])
	if found == want:
		return "both"
	return "none" if found.is_empty() else ", ".join(PackedStringArray(found))


## **The lines of [param text] naming a seat** (rules.gd): none while every mechanic
## with a place has one organ to provide it.
static func _seats_in(text: String) -> Array[String]:
	var found: Array[String] = []
	for line: String in text.split("\n"):
		if line.contains(".seat="):
			found.append(line)
	return found


## The part [param name] an organ of the catalogue declares as an input, its
## declaration -- what the probe's gland declares under the same name.
static func _declared_input(name: StringName) -> Dictionary:
	var declared := Catalogue.declares()
	for organ: StringName in declared:
		for one: Dictionary in (declared[organ] as Dictionary).get("in", []):
			if StringName(one["name"]) == name:
				return one
	return {}


## **Every bit the vocabulary has**, by what holds it: each owner's, each owner's
## levels', each part's and each claim's.
static func _vocabulary_bits() -> Dictionary:
	var vocab := FoodField.vocabulary()
	var out := {}
	for owner: StringName in vocab.owners:
		out["owner " + String(owner)] = int(vocab.owners[owner])
	for owner: StringName in vocab.levels:
		out["levels " + String(owner)] = str(vocab.levels[owner])
	for name: StringName in vocab.inputs:
		out["in " + String(name)] = (vocab.inputs[name] as Rulebook.InputDecl).bit
	for name: StringName in vocab.outputs:
		var output: Rulebook.OutputDecl = vocab.outputs[name]
		out["out " + String(name)] = [output.bit, output.claims]
	for claim: StringName in vocab.claims:
		out["claim " + String(claim)] = int(vocab.claims[claim])
	return out


## What of [param before] is not in [param now] as it was, `""` for nothing.
static func _bits_kept(before: Dictionary, now: Dictionary) -> String:
	var moved: Array[String] = []
	for what: String in before:
		if not now.has(what) or str(now[what]) != str(before[what]):
			moved.append(what)
	return ", ".join(moved)


# --- Gene names in code (§12.2) ----------------------------------------------------------------

## **Every gene name written into game/ outside game/genes/** (§12.2), in any file
## the gate reads ([constant GATED]): a name the catalogue knows -- a key, retired ones
## too; an organ's, which is no key when its variants list their own (`toxin`); a
## variant's -- quoted alone, `"palp"`, `&"palp"`, `'palp'`, `&'palp'`, or with a part
## it declares, `&"flagellum.hold"`; or, in a script, written bare as a dictionary's
## key, `{flagellum = 2}`, which GDScript reads as the string `"flagellum"`
## ([method _bare_keys]). One `path:line: the line` for each. Comments aside -- a line
## of one, and a line's tail from its marker on, outside a string -- and tools/ is not
## looked in: a probe names genes on purpose. **A name built by concatenation or a
## format -- `"%s.hold" % organ` -- is not caught**, nor one inside a longer string --
## `"flagellum hold"` -- nor a string with an escaped quote in it: nothing read line by
## line can tell those from words, so the playbook says not to write one.
func _name_literals() -> Array[String]:
	var out: Array[String] = []
	var named := _names_pattern()
	var names := {}
	for name: String in _gene_names():
		names[name] = true
	for path: String in _texts_in(GAME_DIR):
		if path.begins_with(GENES_DIR + "/"):
			continue
		var marker: String = GATED[path.get_extension()]
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var codes: Array[String] = []
		var block := false
		for k in lines.size():
			if marker == "//":
				var cut := _shader_code(lines[k], block)
				codes.append(cut[0])
				block = cut[1]
			else:
				codes.append(_code_of(lines[k], marker))
		var bare: Array[int] = []
		if path.get_extension() == "gd":
			bare = _bare_keys(codes, names)
		for k in lines.size():
			for _each in named.search_all(codes[k]).size() + bare.count(k):
				out.append("%s:%d: %s" % [path.trim_prefix(GAME_DIR + "/"), k + 1,
					lines[k].strip_edges()])
	return out


## **A script's dictionary keys written bare that are gene names** -- `{flagellum = 2}`,
## a Lua-style key, which GDScript reads as the string `"flagellum"` -- as the index of
## the line each is on, once for each, read off [param codes], its lines without their
## comments. A key is a name written right after a `{`, or after a `,` within one, and
## followed by a lone `=`; strings are blanked first, and the braces are followed from
## line to line, so a dictionary written over several is read whole. A parameter with a
## default, `func f(flagellum := 2)`, is no key, and is not caught.
static func _bare_keys(codes: Array[String], names: Dictionary) -> Array[int]:
	var found: Array[int] = []
	var open: Array[String] = []
	var key_next := false
	for k in codes.size():
		var code := _blank_strings(codes[k])
		var at := 0
		while at < code.length():
			var c := code[at]
			if c == "{" or c == "[" or c == "(":
				open.append(c)
				key_next = c == "{"
			elif c == "}" or c == "]" or c == ")":
				if not open.is_empty():
					open.pop_back()
				key_next = false
			elif c == ",":
				key_next = not open.is_empty() and open.back() == "{"
			elif c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
				var end := at + 1
				while end < code.length() and (code[end] == "_" or (code[end] >= "a"
						and code[end] <= "z") or (code[end] >= "A" and code[end] <= "Z")
						or (code[end] >= "0" and code[end] <= "9")):
					end += 1
				var after := code.substr(end).strip_edges(true, false)
				if key_next and names.has(code.substr(at, end - at)) \
						and after.begins_with("=") and not after.begins_with("=="):
					found.append(k)
				key_next = false
				at = end
				continue
			elif c != " " and c != "\t":
				key_next = false
			at += 1
	return found


## **[param code] with what its strings hold blanked**, quotes kept: so a brace, a comma
## or a name in words is no code.
static func _blank_strings(code: String) -> String:
	var out := ""
	var quote := ""
	var k := 0
	while k < code.length():
		var c := code[k]
		if quote != "":
			if c == "\\":
				out += "  "
				k += 2
				continue
			if c == quote:
				quote = ""
				out += c
			else:
				out += " "
		else:
			if c == "\"" or c == "'":
				quote = c
			out += c
		k += 1
	return out


## **Every name the gate looks for**, each once: every key the catalogue knows,
## retired ones too, every organ's name and every variant's.
static func _gene_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key: StringName in Catalogue.keys():
		for name: StringName in [key, Catalogue.organ_of(key), Catalogue.variant_of(key)]:
			if name != &"" and not names.has(String(name)):
				names.append(String(name))
	return names


## **What the gate looks for, as one pattern**: a quoted string that is one of
## [method _gene_names], or one of them, a dot and a part. The quote that closes it is
## the one that opened it.
static func _names_pattern() -> RegEx:
	var names := PackedStringArray()
	for name: String in _gene_names():
		names.append(_escaped(name))
	var pattern := RegEx.new()
	pattern.compile("([\"'])(?:%s)(?:\\.[A-Za-z0-9_-]+)?\\1" % "|".join(names))
	return pattern


## [param text] with every character a pattern would read as more than itself escaped.
static func _escaped(text: String) -> String:
	var out := ""
	for c: String in text:
		out += c if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") \
			or c == "_" else "\\" + c
	return out


## **[param line] without its comment**: everything from [param marker] on, where the
## marker stands outside a string -- so a `"#ff8800"` or a `"%s ; %s"` is code, and a
## name in a trailing comment is not. A line inside a string that spans lines is read
## as code, which can only find more.
static func _code_of(line: String, marker: String) -> String:
	var quote := ""
	var k := 0
	while k < line.length():
		var c := line[k]
		if quote != "":
			if c == "\\":
				k += 2
				continue
			if c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif line.substr(k, marker.length()) == marker:
			return line.substr(0, k)
		k += 1
	return line


## **A shader's [param line] without its comments**, `//` to the end and `/* ... */`
## within and across lines, [param block] saying whether the line before ended inside
## one: `[the code, whether this line ends inside one]`. A shader has no strings.
static func _shader_code(line: String, block: bool) -> Array:
	var code := ""
	var k := 0
	while k < line.length():
		if block:
			var close := line.find("*/", k)
			if close < 0:
				return [code, true]
			k = close + 2
			block = false
			continue
		var tail := line.find("//", k)
		var open := line.find("/*", k)
		if open >= 0 and (tail < 0 or open < tail):
			code += line.substr(k, open - k)
			k = open + 2
			block = true
			continue
		code += line.substr(k, tail - k) if tail >= 0 else line.substr(k)
		break
	return [code, block]


## **How many gene names are written into game/ outside game/genes/**, by file:
## a note in the full run, beside the gate that fails on any ([method _names_gate]).
func _names_left() -> void:
	var found := {}
	for one: String in _name_literals():
		var path := one.get_slice(":", 0)
		found[path] = int(found.get(path, 0)) + 1
	var parts := PackedStringArray()
	for path: String in found:
		parts.append("%s %d" % [path, int(found[path])])
	print("[gene-probe] NOTE %d gene names in game/ outside game/genes/, which CI's gate"
		% _name_literals().size() + " fails on (-- --names): %s"
		% ("none" if parts.is_empty() else ", ".join(parts)))


## **The gate** (§12.2), as CI's "Check the gene names" runs it (`-- --names`): every
## gene name written into game/ outside game/genes/ is a failure, one line each, and
## `ALL PASS` only for none. A mechanic asks the catalogue for an organ by its stat,
## its tag or its channel, so that a gene added, varied or retired is one entry in
## its organ's file and nothing else moves.
func _names_gate() -> void:
	var found := _name_literals()
	for one: String in found:
		print("[gene-names] FAIL %s" % one)
	print(("[gene-names] %d gene names in game/ outside game/genes/ -- the %d names of %d"
		+ " keys, their organs and their variants looked for, quoted alone or with a part"
		+ " or written bare as a dictionary's key, in %d scripts, scenes, resources and"
		+ " shaders; comments and tools/ aside") % [found.size(),
		_gene_names().size(), Catalogue.keys().size(),
		_texts_in(GAME_DIR).filter(func(path: String) -> bool:
			return not path.begins_with(GENES_DIR + "/")).size()])
	print("[gene-names] ALL PASS" if found.is_empty() else "[gene-names] FAILED %d" % found.size())
	_failed += found.size()


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


## The entries of an organ file's word table [param name] in [param tables], or of a
## table's own inner table: none where it is not a dictionary.
static func _table(tables: Variant, name: Variant) -> Array:
	var table: Variant = (tables as Dictionary).get(name) if tables is Dictionary else null
	return (table as Dictionary).keys() if table is Dictionary else []


## How far apart two hues are, in degrees round the wheel.
static func _apart(a: float, b: float) -> float:
	var gap := absf(a - b)
	return minf(gap, 360.0 - gap)


## Whether [param rgb], a copy of a hue as the shader takes it, is [param key]'s --
## its family's shade.
static func _same(rgb: Vector3, key: StringName) -> bool:
	var hue := Catalogue.hue_of(key)
	return hue.a > 0.0 and rgb.is_equal_approx(Vector3(hue.r, hue.g, hue.b))


## **The one family [param keys] are all of**, `&""` for none or more than one.
static func _one_family(keys: Array) -> StringName:
	var family := &""
	for key: Variant in keys:
		var own := Catalogue.family_of(StringName(key))
		if family != &"" and own != family:
			return &""
		family = own
	return family


## [param rgb] as a colour.
static func _color(rgb: Vector3) -> Color:
	return Color(rgb.x, rgb.y, rgb.z)


## **[param tone] in OKLCH** (Björn Ottosson's OKLab, 2020): its lightness, its chroma
## and its hue in degrees, as gene-looks.md §1.3 measured the families.
static func _oklch(tone: Color) -> Vector3:
	var lin: Array[float] = []
	for c: float in [tone.r, tone.g, tone.b]:
		lin.append(c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4))
	var l := pow(0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2],
		1.0 / 3.0)
	var m := pow(0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2],
		1.0 / 3.0)
	var s := pow(0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2],
		1.0 / 3.0)
	var lightness := 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
	var a := 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
	var b := 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	return Vector3(lightness, Vector2(a, b).length(), fposmod(rad_to_deg(atan2(b, a)), 360.0))


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
## them: its own name first -- its implicit first variant -- unless it lists
## variants and has no order of its own, as the toxin does; then a variant's own key
## -- or its name -- for a variant of no forms, and every form's for one of forms.
## `&""` for a variant with none of the three, which the catalogue cannot file, so
## that the count of forms says so.
static func _keys_of(organ: Gene) -> Array[StringName]:
	var out: Array[StringName] = []
	if organ.variants.is_empty() or organ.order >= 0:
		out.append(organ.organ)
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


## Every file under [param dir] the gate reads ([constant GATED]), in order.
static func _texts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if GATED.has(file.get_extension()):
			out.append(dir + "/" + file)
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_texts_in(dir + "/" + sub))
	return out
