extends RefCounted
## **The catalogue** (docs/design/gene-catalogue.md §4): every gene the game
## knows, by key, and every question any file asks of one. A gene's numbers,
## lists, tags, rules, look and words live in its organ's file under `organs/`;
## this is the index of those files and the one place they are read from.
##
## **Lookups are built once**, when this script loads ([method _static_init]),
## into dictionaries and lists: nothing per frame walks the catalogue, and every
## answer is a read of something already built. The lists it hands out are
## read-only -- a list a caller wants to change is one it duplicates first, as it
## would have duplicated the constant it replaces.
##
## **A key this build does not know is still a gene** -- a save's, or a guest's
## on a newer build -- and every question has the answer it always had for one:
## it is its own organ and its own variety, it sits outside, it has no place in
## the order, no tag and no table, and it is drawn and costs upkeep and does
## nothing. Nothing is ever dropped from a genome for not being here.
##
## **Preloads nothing from game/normal, game/net, game/vision or
## game/perception**, and neither do the organ files: everything there preloads
## this, so a preload back would be the cycle `cell.gd` warns about.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Gene := preload("res://game/genes/gene.gd")

## **The index**: one line per organ file, in the order they arrived. Explicit
## because an exported pack cannot be listed reliably, and because a new line
## here is the order of arrival made visible in review. The gene probe lists the
## folder and fails on a file this lacks, or a line with no file.
const ORGANS: Array[GDScript] = [
	preload("res://game/genes/organs/cytostome.gd"),
	preload("res://game/genes/organs/cirrus.gd"),
	preload("res://game/genes/organs/flagellum.gd"),
	preload("res://game/genes/organs/stigma.gd"),
	preload("res://game/genes/organs/ocellus.gd"),
	preload("res://game/genes/organs/chemocyte.gd"),
	preload("res://game/genes/organs/ampulla.gd"),
	preload("res://game/genes/organs/axoneme.gd"),
	preload("res://game/genes/organs/palp.gd"),
	preload("res://game/genes/organs/myoneme.gd"),
	preload("res://game/genes/organs/trichocyst.gd"),
	preload("res://game/genes/organs/pellicle.gd"),
	preload("res://game/genes/organs/toxin.gd"),
	preload("res://game/genes/organs/plastid.gd"),
	preload("res://game/genes/organs/vacuole.gd"),
	preload("res://game/genes/organs/crista.gd"),
	# Retired, and kept known for good (§4.4).
	preload("res://game/genes/organs/rhabdom.gd"),
	preload("res://game/genes/organs/statocyst.gd"),
]

## The tags (gene.gd says what each means), so a reader that preloads this file
## names them without a second preload.
const SENSE := Gene.SENSE
const GIFT := Gene.GIFT
const ALWAYS_EXPRESSED := Gene.ALWAYS_EXPRESSED
const NEVER_DRIFTS := Gene.NEVER_DRIFTS
const RETIRED := Gene.RETIRED
const NOT_ON_DRIFTERS := Gene.NOT_ON_DRIFTERS
const FLOOR_BY_PEERS := Gene.FLOOR_BY_PEERS
## The membrane's channels (gene.gd), for the same reason.
const LIGHT := Gene.LIGHT
const BEAM := Gene.BEAM
const PING := Gene.PING
const SMELL := Gene.SMELL
const TOUCH := Gene.TOUCH
## The shapes an organ is drawn as (gene.gd), for the same reason.
const MAT := Gene.MAT
const OARS := Gene.OARS
const LASH := Gene.LASH
const TUFT := Gene.TUFT
const SPINES := Gene.SPINES
## The shapes drawn on arcs of their own, whatever slot holds them (gene.gd).
const HOME_SHAPES := Gene.HOME_SHAPES

## **The tables of words an organ's file may hold** (gene.gd, "Its words"), by
## constant name, and what each is called here: the words said of a key ...
const KEY_WORDS := {"WORDS": &"word", "EXPLAINS": &"explains", "EXPLAINS_SIDE": &"side",
	"EXPLAINS_STERN": &"stern", "EXPLAINS_PATH": &"paths", "CARRIED_WORDS": &"carried",
	"CARRIED_EXPLAINS": &"carried_explains", "NAMES": &"name"}
## ... the words of the ways its levels fork into, by way, for every key of the
## organ: each way's name, its two card lines, and what it does as it grows ...
const WAY_WORDS := {"PATH_TITLES": &"way_titles", "PATH_LINES": &"way_lines",
	"PATH_SAYS": &"way_says"}
## ... and the words of a part it declares, by the part's qualified name.
const PART_WORDS := {"GENE_SAYS": &"says", "GENE_SENSES": &"sense",
	"GENE_EXPLAINS": &"explains", "GENE_ASLEEP": &"asleep", "GENE_NEEDS": &"needs"}

## **The water's list of what a drifter may be made of**, and the parts genes
## declare to a body's rules, by the names their orders are pinned under below.
const DRIFTERS := &"drifter"
const DECLARES := &"declares"

## **The order four lists shipped in, before there was a catalogue**, pinned.
## Each was written by hand where it was read, in an order of its own, and each
## is walked by something that order is part of: a draw that picks by position
## from the global stream -- the water's draws by weight (`food.gd`), the floor's
## gene taken off the end of its short list (`drop.gd`), the sense a peer is given
## and the free sense a newborn is given -- or the bits `rulebook.gd` numbers in
## the order parts are declared, which a body's rules are read with. Put in any
## other order, the same seed makes another water.
##
## **They pin order only, never membership**: which genes are on a list is each
## gene's own field, and a gene that joins one after these follows them, in
## [method keys]' order. So the gene pass never edits this, and a retired gene
## named here is simply not on its list any more. `declares` names organs, whose
## parts every variant shares ([method declares]); each shipped organ goes by its
## own key.
const SHIPPED_ORDERS := {
	DRIFTERS: [&"cirrus", &"flagellum", &"stigma", &"chemocyte", &"ampulla",
		&"ocellus", &"axoneme", &"palp", &"myoneme",
		&"trichocyst", &"pellicle", &"veneneux", &"plastid", &"vacuole", &"crista"],
	SENSE: [&"chemocyte", &"ampulla", &"ocellus", &"stigma"],
	GIFT: [&"ocellus", &"ampulla", &"chemocyte", &"stigma"],
	DECLARES: [&"ocellus", &"ampulla", &"chemocyte", &"stigma", &"palp", &"myoneme",
		&"axoneme", &"flagellum"],
}

## The fields a variant or a form may set over its organ: everything an organ
## sets but its name, its variants and **the parts it declares**, which are the
## organ's -- every variant of it has them, under the organ's name, and its rules
## read them alike (§6.2; [method declares]).
const OVERRIDES: Array[String] = ["order", "provides", "numbers", "levels", "water", "tags",
	"channel", "born", "look"]

## An empty list, the answer for a name nothing is filed under.
static var _none: Array[StringName] = _read_only([] as Array[StringName])
## An empty look and empty words, the answers for a key with none.
static var _no_look := _frozen_empty()
static var _no_words := _frozen_empty()

## Key to its flat record: an instance of its organ's script, its variant and form
## written over it ([method _resolve]).
static var _records := {}
## Every key: those with a place in the order, by it, then those with none, in
## the index's order.
static var _keys: Array[StringName] = []
## [member _keys] without the retired.
static var _live: Array[StringName] = []
## Key to its place in the order, for the keys that have one.
static var _rank := {}
## Key to every form of its variant, its variety first.
static var _forms := {}
## **Asked of every gene of every body drawn, every frame**, so each is one
## lookup: key to its variety; the keys that are one form of several, as a set;
## and key to the place it sits in.
static var _varieties := {}
static var _formed := {}
static var _places := {}
## Stat to the live keys that provide it, in [member _keys]' order.
static var _providers := {}
## The same, each key beside its table: stat to `[key, table, key, table, ...]`.
## What a body's stat is read through every frame ([method provided]). **Filled
## in place and never replaced**: stats.gd holds this very dictionary.
static var _provided := {}
## Tag to its keys, in order; and tag to the same as a set.
static var _tagged := {}
static var _tag_sets := {}
## The live varieties a drifter may be made of, in order.
static var _drifters: Array[StringName] = []
## **Organ to its own weight in the water's draws**, and organ to whether it holds
## one variant to a body ([method organ_weight], [method one_variant]).
static var _organ_weights := {}
static var _one_variant := {}
## **Key to its organ, and organ to its keys**, every key's, retired and forms
## included, an organ's in the order its file lists them. Asked of every gene of
## every draw the water makes ([method organ_of], [method keys_of_organ]), so each
## is one lookup.
static var _organs := {}
static var _organ_keys := {}
## Key to the copies a newborn wears, and those keys in order.
static var _born := {}
static var _born_order: Array[StringName] = []
## **Organ to the parts it declares**, in the order they are declared; organ to
## its first live key; and whether every organ that declares parts goes by its
## own key alone ([method by_organ]).
static var _declares := {}
static var _first_keys := {}
static var _owners_are_keys := true
## The live keys that earn levels.
static var _levelled: Array[StringName] = []
## Channel to the live keys that drive it.
static var _channels := {}
## What a tool registered ([method register]): each in the place of the index's
## organ of its name, or after the index's own.
static var _registered: Array = []
## **Key to its look**, every key's, a retired one's empty. Asked of every organ of
## every body drawn, every frame, so it is one lookup -- and **filled in place and
## never replaced**, as [member _provided] is, because cilia.gd holds it.
static var _looks := {}
## Shape to the live keys drawn as it, in order. **Filled in place and never
## replaced**, as [member _looks] is, because cilia.gd holds it.
static var _shaped := {}
## **Key to its look's hue, and key to its look's shape**, for every key whose look
## has one -- a retired key's has neither. Each is asked of every organ of every body
## drawn, every frame, so each is one lookup; filled in place, as [member _looks] is,
## because cilia.gd holds both.
static var _hues := {}
static var _shape_of := {}
## Key to its words (gene.gd's word tables): [constant KEY_WORDS]' names to the
## English, which the screens translate.
static var _words := {}
## Qualified part name to its words, [constant PART_WORDS]' names to the English:
## every part an organ's file has words for.
static var _part_words := {}


static func _static_init() -> void:
	_index()


# --- Identity (§4.3) ------------------------------------------------------------------

## Whether [param key] is a gene this build knows, retired ones included.
static func known(key: StringName) -> bool:
	return _records.has(key)


## **The flat record of [param key]**, or null for a key this build does not
## know: every field its organ, variant and form set, and its organ's hooks.
## **The catalogue's own record**: its containers are read-only ([constant
## FROZEN]); its plain fields are not, and must never be written.
static func gene(key: StringName) -> Gene:
	return _records.get(key, null) as Gene


## **Every key, in order**: those with a place in the order by it -- today's
## `GENE_ORDER` -- then those with none. Retired keys are in it: they are known.
static func keys() -> Array[StringName]:
	return _keys


## [method keys] without the retired: every gene a body can come to wear today.
static func live() -> Array[StringName]:
	return _live


## **[param key]'s place in the order**, the tie-break of `genome.gd`'s
## `dominant_of`; -1 for a key with none, retired before there was a catalogue,
## and for a key this build does not know.
static func rank(key: StringName) -> int:
	return int(_rank.get(key, -1))


## The organ [param key] is a form of: itself for a key this build does not know.
static func organ_of(key: StringName) -> StringName:
	return _organs.get(key, key)


## **Every key filed under [param organ]**, its variants' forms and the retired
## among them, in the order its file lists them; none for a name no organ goes by.
static func keys_of_organ(organ: StringName) -> Array[StringName]:
	return _organ_keys.get(organ, _none)


## The variant [param key] is a form of, `&""` for an organ's own key -- its
## implicit first variant -- and for a key this build does not know.
static func variant_of(key: StringName) -> StringName:
	var record := gene(key)
	return record.variant if record != null else &""


## **The place [param key] sits in**: outside for every gene of one form and for
## a key this build does not know.
static func place_of(key: StringName) -> StringName:
	return _places.get(key, Gene.OUTSIDE)


## **Every form of [param key]'s variant**, its variety first; itself alone for
## a gene of one form.
static func forms_of(key: StringName) -> Array[StringName]:
	if _forms.has(key):
		return _forms[key]
	return _read_only([key] as Array[StringName])


## Whether [param key] is one form of a variant with others: true exactly when its
## variant sits in more than one place -- the toxin's two forms, today.
static func has_forms(key: StringName) -> bool:
	return _formed.has(key)


## **[param key]'s variety**: the first form of its variant, the name it goes by
## where no place is known yet -- the water's draws, the floor's count, two meals
## found to be one. Itself for a gene of one form.
static func variety(key: StringName) -> StringName:
	return _varieties.get(key, key)


## **[param key]'s variant, in [param place]**: the form it is there, or `&""`
## where it cannot sit -- inside, for a gene of one form outside.
static func form_in(key: StringName, place: StringName) -> StringName:
	for form: StringName in forms_of(key):
		if place_of(form) == place:
			return form
	return &""


## The kind of dose [param key] delivers, by doses.gd's name, `&""` for none.
static func dose_of(key: StringName) -> StringName:
	var record := gene(key)
	return record.dose if record != null else &""


# --- Tags and the water (§9) ---------------------------------------------------------------

## **The keys tagged [param tag]**, in order: a pinned list's shipped order first
## ([constant SHIPPED_ORDERS]), then [method keys]' order. Live keys only, but for
## [constant RETIRED] itself.
static func tagged(tag: StringName) -> Array[StringName]:
	return _tagged.get(tag, _none)


## Whether [param key] is on [method tagged]'s list for [param tag].
static func has_tag(key: StringName, tag: StringName) -> bool:
	return _tag_sets.has(tag) and (_tag_sets[tag] as Dictionary).has(key)


## **What a drifter may be made of** (`food.gd`'s draws): every live variety whose
## water says so, in order.
static func drifters() -> Array[StringName]:
	return _drifters


## **How often the water draws [param key]** against the other varieties of its
## organ: its variant's weight, 1 where it sets none and for a key this build does
## not know. The organ is drawn first, by [method organ_weight].
static func weight(key: StringName) -> int:
	var record := gene(key)
	return int(record.water.get("weight", 1)) if record != null else 1


## **How often the water draws [param organ]** against the others (§6.1): the
## weight its file sets, or, where only its variants set one, its first variety's
## -- so an organ of one variant is drawn exactly as its key was, and the toxin's
## strains share the toxin's draws rather than add to them (dna-slots.md §8.3).
## Its key's weight for a name this build files no organ under.
static func organ_weight(organ: StringName) -> int:
	var own: Variant = _organ_weights.get(organ)
	return int(own) if own != null else weight(organ)


## Whether [param organ] holds one variant to a body (gene.gd's `one_variant`).
static func one_variant(organ: StringName) -> bool:
	return _one_variant.has(organ)


## **The organs of [param keys], each once**, in the order its first key comes.
static func organs_in(keys: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in keys:
		var organ := organ_of(key)
		if not out.has(organ):
			out.append(organ)
	return out


## **The keys of [param keys] that are [param organ]'s**, in order.
static func of_organ(keys: Array[StringName], organ: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in keys:
		if organ_of(key) == organ:
			out.append(key)
	return out


## **One of [param varieties] -- one organ's -- by their weights** (§6.1): the one
## there is, with no number drawn, for an organ of one variety, which is every organ
## today; otherwise one roll of the global stream, as every draw of the water's is.
## `&""` for none.
static func pick_variety(varieties: Array[StringName]) -> StringName:
	if varieties.size() <= 1:
		return varieties[0] if not varieties.is_empty() else &""
	var total := 0
	for key: StringName in varieties:
		total += weight(key)
	var roll := randi_range(1, maxi(total, 1))
	for key: StringName in varieties:
		roll -= weight(key)
		if roll <= 0:
			return key
	return varieties[varieties.size() - 1]


## **The born cell's body** (`genome.gd`): key to the copies a newborn wears, in
## order -- a mouth, a cirrus and a tail, one each.
static func born() -> Dictionary:
	return _born


## The born cell's organs: the keys of [method born], in order. **Where each is
## seated is the body plan's**: its home slot, the row of `body_plan.gd` that names
## it (`home_layout`) -- the nose, the flank and the tail.
static func born_order() -> Array[StringName]:
	return _born_order


# --- Rules and levels -----------------------------------------------------------------

## **Organ to the parts it declares to a body's rules** (behaviour.md §3), in the
## shape `rulebook.gd`'s vocabulary reads, in the order they are declared. **The
## parts are the organ's**: every variant of it has them, under the organ's name --
## `chemocyte.smell` whichever nose a body wears -- so an instinct reads them alike,
## and a list saved under one variant reads under the next. A body's rules count
## them by organ ([method by_organ]).
static func declares() -> Dictionary:
	return _declares


## **[param levels] -- a key to the level it works at -- by organ**: each organ to
## the highest level of any live key of it, which is what a body's rules count its
## parts by (rulebook.gd's owners are the organs of [method declares]). A retired
## key brings nothing, as it provides nothing (§4.4), and a key this build does not
## know stands for itself. **[param levels] itself while every organ that declares
## parts goes by its own key alone** -- every one today -- so nothing is made.
static func by_organ(levels: Dictionary) -> Dictionary:
	if _owners_are_keys:
		return levels
	var out := {}
	for key: Variant in levels:
		var record := gene(StringName(key))
		if record != null and record.tags.has(RETIRED):
			continue
		var organ: StringName = record.organ if record != null else StringName(key)
		out[organ] = maxi(int(out.get(organ, 0)), int(levels[key]))
	return out


## **The first live key of [param organ]** -- its first variant's variety -- what
## the organ is drawn as where no key is known: a part's chip on the instincts
## page. The organ itself for one this build does not know.
static func first_key(organ: StringName) -> StringName:
	return _first_keys.get(organ, organ)


## The live keys that earn levels.
static func levelled() -> Array[StringName]:
	return _levelled


## Whether [param key] earns levels.
static func has_levels(key: StringName) -> bool:
	return _levelled.has(key)


## **How [param key] earns levels**: `step`, `fork` and `paths` (gene.gd); empty
## for a gene that does not.
static func levels(key: StringName) -> Dictionary:
	var record := gene(key)
	return record.levels if record != null else {}


## **[param key]'s own number [param name]** (gene.gd's `numbers`), or null.
static func number(key: StringName, name: StringName) -> Variant:
	var record := gene(key)
	return record.numbers.get(name) if record != null else null


## **The number [param name] of the organ a body wearing [param tiers] provides
## [param stat] with** -- or of the first that provides it, for a body that wears
## none: the tail's hold level, the dart's stun. The mechanic asks the organ it
## acts through, and never names it: [method worn_provider]'s, or, given the
## body's [param layout] -- a mechanic with a place, the dart's --
## [method seated_provider]'s. [param otherwise] when nothing provides the stat any
## more -- every organ that did retired (§4.4) -- or the organ has no such number.
static func number_for(tiers: Dictionary, stat: StringName, name: StringName,
		otherwise: Variant = null, layout: Array = []) -> Variant:
	var all: Array[StringName] = _providers.get(stat, _none)
	if all.is_empty():
		return otherwise
	var key := seated_provider(layout, tiers, stat)
	if key == &"":
		key = all[0]
	return (_records[key] as Gene).numbers.get(name, otherwise)


## **What [param key] adds to the metabolic multiplier at [param level] down
## [param path]**, by its organ's own price; -1 for a gene with none, which
## `genome.gd` charges at the old per-tier rate, by level.
static func upkeep_at(key: StringName, level: int, path: StringName) -> float:
	var record := gene(key)
	return record.upkeep_at(level, path) if record != null else -1.0


# --- Numbers (§5) -------------------------------------------------------------------------

## **The live keys that provide [param stat]**, in order. A body's stat is read
## through `stats.gd`, which combines what it wears of them.
static func providers(stat: StringName) -> Array[StringName]:
	return _providers.get(stat, _none)


## **Every stat's [method providers], each beside its table**: stat to `[key,
## table, key, table, ...]`, each list read-only. What `stats.gd` reads a body's
## value through, every frame. **It is the catalogue's own dictionary**, which
## stats.gd holds once and reads as its own: every index refills it in place --
## [method register] and [method forget] too -- and never replaces it, so the
## holder is never stale. **It is the one container here that is not read-only**,
## so that it can be refilled in place: never write it.
static func provided() -> Dictionary:
	return _provided


## The first of [method providers], `&""` for a stat nothing provides.
static func first_provider(stat: StringName) -> StringName:
	var all := providers(stat)
	return all[0] if not all.is_empty() else &""


## Whether [param key] provides [param stat].
static func provides(key: StringName, stat: StringName) -> bool:
	var record := gene(key)
	return record != null and record.provides.has(stat)


## **[param key]'s table for [param stat]**, by tier, index 0 the stat's value
## with no provider; empty for a key that does not provide it.
static func table(key: StringName, stat: StringName) -> Array:
	var record := gene(key)
	return record.provides.get(stat, []) if record != null else []


## **The organ a body wearing [param tiers] provides [param stat] with**: the
## first of [method providers] it wears, in the catalogue's order, `&""` for
## none. One instance per mechanic (§5.2): what a mechanic with no place acts
## from -- the tail's level, the mouth. One with a place asks
## [method seated_provider].
static func worn_provider(tiers: Dictionary, stat: StringName) -> StringName:
	for key: StringName in _providers.get(stat, _none):
		if int(tiers.get(key, 0)) > 0:
			return key
	return &""


## **The organ a mechanic with a place acts from** (§5.2; stats.gd's `SEATED`):
## the first provider of [param stat] a body wearing [param tiers] wears **in slot
## order** -- [param layout], its slots, the body plan's numbering -- so a body
## with two eyes casts from the one in the lower slot, at that one's level, and its
## stat still combines both by its row. A provider worn in no slot of [param layout]
## -- a layout this body has none of yet -- answers in the catalogue's order, as
## [method worn_provider]; `&""` for none. **A stat of one provider never reads the
## layout** -- every stat today -- so its answer is [method worn_provider]'s.
static func seated_provider(layout: Array, tiers: Dictionary, stat: StringName) -> StringName:
	var all: Array[StringName] = _providers.get(stat, _none)
	if all.size() > 1:
		for key: Variant in layout:
			if key != &"" and int(tiers.get(key, 0)) > 0 and all.has(key):
				return key
	return worn_provider(tiers, stat)


## The channel [param key] drives (gene.gd), `&""` for none.
static func channel_of(key: StringName) -> StringName:
	var record := gene(key)
	return record.channel if record != null else &""


## **The organ a body wearing [param tiers] drives [param channel] with**: the
## first live key on that channel it wears, `&""` for none.
static func worn_on(tiers: Dictionary, channel: StringName) -> StringName:
	for key: StringName in _channels.get(channel, _none):
		if int(tiers.get(key, 0)) > 0:
			return key
	return &""


# --- Looks and words (§7.1, §8) ----------------------------------------------------------

## **[param key]'s look** (gene.gd's `look`), read-only; empty for a key this build
## does not know, or a retired one.
static func look(key: StringName) -> Dictionary:
	return _looks.get(key, _no_look)


## **Every key's look, by key**: the catalogue's own dictionary, which cilia.gd
## holds once and reads every frame as its own. Every index refills it in place --
## [method register] and [method forget] too -- and never replaces it. Read it;
## never write it.
static func looks() -> Dictionary:
	return _looks


## **The live keys drawn as [param shape]** (gene.gd's SHAPES), in order: how
## cilia.gd finds the organ it draws on a home arc without its name.
static func shaped(shape: StringName) -> Array[StringName]:
	return _shaped.get(shape, _none)


## **Every shape's [method shaped], by shape**: the catalogue's own dictionary, which
## cilia.gd holds once and reads every frame as its own, filled in place as
## [method looks] is. Read it; never write it.
static func shapes() -> Dictionary:
	return _shaped


## **Every key's hue, by key** -- its look's `hue` -- for the keys that have one: the
## catalogue's own dictionary, held by cilia.gd as [method looks] is. Read it; never
## write it.
static func hues() -> Dictionary:
	return _hues


## **Every key's shape, by key** -- its look's `shape` -- for the keys that have one,
## held by cilia.gd as [method hues] is.
static func shape_by_key() -> Dictionary:
	return _shape_of


## **The first live key on membrane [param channel]**, `&""` for none: whose hue a
## channel's lobe is drawn in (signal_bus.gd).
static func first_on(channel: StringName) -> StringName:
	var all: Array[StringName] = _channels.get(channel, _none)
	return all[0] if not all.is_empty() else &""


## **[param key]'s words** (gene.gd's word tables), read-only: [constant
## KEY_WORDS]' names -- `word`, `explains`, `side`, `stern`, `paths` (way to its
## line), `carried`, `carried_explains`, `name` -- and [constant WAY_WORDS]' --
## `way_titles`, `way_lines`, `way_says`, each way to its words -- to the
## English, a key absent where its file has none. The screens translate them
## (figure.gd, normal_mode.gd).
static func words(key: StringName) -> Dictionary:
	return _words.get(key, _no_words)


## **The words of the part [param part]** an organ declares (`palp.touch`),
## read-only: [constant PART_WORDS]' names -- `says`, `sense`, `explains`,
## `asleep`, `needs` -- to the English; empty for a part no organ has words for.
## The instincts page translates them (genome.gd's `words_of`).
static func part_words(part: StringName) -> Dictionary:
	return _part_words.get(part, _no_words)


# --- Tools -----------------------------------------------------------------------------------

## **A tool's seam: a gene of its own** (§4.3), filed as an organ's file would be,
## and every lookup built again: after the index's, as a new organ's file is -- or,
## **for an organ of a name the index already has, in that organ's place**, as an
## edit to its file would be. So a variant of a shipped organ is posed as it will
## be written: the organ's own file with one more entry. As `food.gd`'s `declare()`
## lets a probe declare a part, this lets one put a synthetic gene through every
## system. Nothing in the game calls it.
static func register(organ: Gene) -> void:
	_registered.append(organ)
	_index()


## Takes back everything [method register] filed under [param organ_name], and puts
## back the index's own organ of that name where one stood in for it.
static func forget(organ_name: StringName) -> void:
	_registered = _registered.filter(func(one: Gene) -> bool: return one.organ != organ_name)
	_index()


# --- Building the lookups -----------------------------------------------------------------

## Reads every organ, resolves each into its keys' records, and builds every
## lookup above from them.
static func _index() -> void:
	var organs: Array = []
	for script: GDScript in ORGANS:
		organs.append(script.new())
	# What a tool registered: in the place of the organ of its name, or after them all
	# ([method register]).
	for one: Gene in _registered:
		var at := -1
		for k in organs.size():
			if (organs[k] as Gene).organ == one.organ:
				at = k
				break
		if at >= 0:
			organs[at] = one
		else:
			organs.append(one)
	var records := {}
	var resolved: Array = []
	# Each key's words, and every part's, from its organ file's word tables.
	var words := {}
	var part_words := {}
	var organ_weights := {}
	var one_variant := {}
	for organ: Gene in organs:
		var tables := (organ.get_script() as GDScript).get_script_constant_map()
		# The organ's own weight, read before a variant writes over its water.
		var own: Variant = organ.water.get("weight")
		if organ.one_variant:
			one_variant[organ.organ] = true
		for record: Gene in _resolve(organ):
			if records.has(record.key):
				push_error("[catalogue] %s is keyed twice: the second is not filed" % record.key)
				continue
			records[record.key] = record
			resolved.append(record)
			words[record.key] = _words_in(tables, record.key)
			if not organ_weights.has(record.organ):
				organ_weights[record.organ] = int(own if own != null
					else record.water.get("weight", 1))
		_part_words_into(part_words, tables)
	_organ_weights = organ_weights
	_one_variant = one_variant
	for record: Gene in resolved:
		for field: StringName in FROZEN:
			_freeze(record.get(field))
	_records = records
	var organs_of := {}
	var organ_keys := {}
	for key: StringName in records:
		var organ: StringName = (records[key] as Gene).organ
		organs_of[key] = organ
		if not organ_keys.has(organ):
			organ_keys[organ] = [] as Array[StringName]
		(organ_keys[organ] as Array).append(key)
	for organ: StringName in organ_keys:
		_read_only(organ_keys[organ])
	_organs = organs_of
	_organ_keys = organ_keys
	_freeze(words)
	_words = words
	_freeze(part_words)
	_part_words = part_words
	# In place: cilia.gd holds these dictionaries ([method looks], [method hues],
	# [method shape_by_key]).
	_looks.clear()
	_hues.clear()
	_shape_of.clear()
	for record: Gene in resolved:
		_looks[record.key] = record.look
		if record.look.has("hue"):
			_hues[record.key] = record.look["hue"]
		if record.look.has("shape"):
			_shape_of[record.key] = StringName(record.look["shape"])
	var ordered := resolved.filter(func(one: Gene) -> bool: return one.order >= 0)
	ordered.sort_custom(func(a: Gene, b: Gene) -> bool: return a.order < b.order)
	var keys: Array[StringName] = []
	var live: Array[StringName] = []
	_rank = {}
	for record: Gene in ordered + resolved.filter(func(one: Gene) -> bool: return one.order < 0):
		keys.append(record.key)
		if not record.tags.has(RETIRED):
			live.append(record.key)
		if record.order >= 0:
			_rank[record.key] = record.order
	_keys = _read_only(keys)
	_live = _read_only(live)
	# The forms of each variant, in the order its organ lists them.
	var groups := {}
	for record: Gene in resolved:
		var group := "%s/%s" % [record.organ, record.variant]
		if not groups.has(group):
			groups[group] = [] as Array[StringName]
		(groups[group] as Array).append(record.key)
	_forms = {}
	_formed = {}
	_varieties = {}
	for group: String in groups:
		var forms: Array[StringName] = _read_only(groups[group])
		for key: StringName in forms:
			_forms[key] = forms
			_varieties[key] = forms[0]
			if forms.size() > 1:
				_formed[key] = true
	_places = {}
	for record: Gene in resolved:
		_places[record.key] = record.place
	# In place: cilia.gd holds this dictionary ([method shapes]).
	var shaped := {}
	for key: StringName in live:
		var shape := StringName((records[key] as Gene).look.get("shape", &""))
		if shape == &"":
			continue
		if not shaped.has(shape):
			shaped[shape] = [] as Array[StringName]
		(shaped[shape] as Array).append(key)
	_shaped.clear()
	for shape: StringName in shaped:
		_shaped[shape] = _read_only(shaped[shape])
	_providers = {}
	_channels = {}
	var born := {}
	var born_order: Array[StringName] = []
	var levelled: Array[StringName] = []
	var drifters: Array[StringName] = []
	var declaring: Array[StringName] = []
	var organ_declares := {}
	var first_keys := {}
	var owners_are_keys := true
	for key: StringName in live:
		var record: Gene = records[key]
		for stat: StringName in record.provides:
			if not _providers.has(stat):
				_providers[stat] = [] as Array[StringName]
			(_providers[stat] as Array).append(key)
		if record.channel != &"":
			if not _channels.has(record.channel):
				_channels[record.channel] = [] as Array[StringName]
			(_channels[record.channel] as Array).append(key)
		if record.born > 0:
			born[key] = record.born
			born_order.append(key)
		if not record.levels.is_empty():
			levelled.append(key)
		if bool(record.water.get("drifter", false)) and variety(key) == key:
			drifters.append(key)
		if not first_keys.has(record.organ):
			first_keys[record.organ] = key
		if not record.declares.is_empty():
			if not organ_declares.has(record.organ):
				declaring.append(record.organ)
				organ_declares[record.organ] = record.declares
			owners_are_keys = owners_are_keys and key == record.organ
	# In place: stats.gd holds this dictionary ([method provided]).
	_provided.clear()
	for stat: StringName in _providers:
		_read_only(_providers[stat])
		var pairs := []
		for key: StringName in _providers[stat]:
			pairs.append(key)
			pairs.append((records[key] as Gene).provides[stat])
		_provided[stat] = _read_only_pairs(pairs)
	for channel: StringName in _channels:
		_read_only(_channels[channel])
	born.make_read_only()
	_born = born
	_born_order = _read_only(born_order)
	_levelled = _read_only(levelled)
	_drifters = _read_only(_pinned(drifters, SHIPPED_ORDERS[DRIFTERS]))
	var declared := {}
	for organ: StringName in _pinned(declaring, SHIPPED_ORDERS[DECLARES]):
		declared[organ] = organ_declares[organ]
	declared.make_read_only()
	_declares = declared
	_first_keys = first_keys
	_owners_are_keys = owners_are_keys
	_tagged = {}
	_tag_sets = {}
	for tag: StringName in Gene.TAGS:
		var members: Array[StringName] = []
		for key: StringName in (keys if tag == RETIRED else live):
			if (records[key] as Gene).tags.has(tag):
				members.append(key)
		var listed := _pinned(members, SHIPPED_ORDERS.get(tag, []))
		_tagged[tag] = _read_only(listed)
		var members_set := {}
		for key: StringName in listed:
			members_set[key] = true
		_tag_sets[tag] = members_set


## **[param organ]'s keys, each a flat record** (§4.2, §6.2). **First the organ
## itself, keyed by its name** -- its implicit first variant, the organ as it shipped
## -- unless it lists variants and has no place in the order of its own (below).
## Then one record per form of every variant it lists, in its order -- a fresh
## instance of the organ's script, the organ's fields copied onto it, then its
## variant's and its form's written over them. A variant with no forms is one,
## outside. **A variant is born with no copies** unless it says otherwise: `born`
## is the one field it does not take from its organ, or every newborn would wear
## both tails.
##
## **An organ with variants and no `order` of its own is no key itself**: its
## variants are all it files, the first listed being the organ as it shipped. That
## is the toxin, whose first strain sits in two places, each form with its key and
## its order. Every other organ has a place in the order, so adding a variant to it
## is one entry and its own key never leaves the catalogue.
static func _resolve(organ: Gene) -> Array:
	var out: Array = []
	if organ.variants.is_empty() or organ.order >= 0:
		organ.key = organ.organ
		out.append(organ)
	for entry: Dictionary in organ.variants:
		var forms: Dictionary = entry.get("forms", {})
		if forms.is_empty():
			# **A variant with no forms is one form, outside** (gene.gd): keyed by its
			# own `key`, or by its name.
			var own := StringName(entry.get("key", entry.get("variant", &"")))
			if own == &"":
				push_error("[catalogue] a variant of %s has no forms, no key and no name:"
					% organ.organ + " it is not filed")
				continue
			forms = {Gene.OUTSIDE: own}
		for place: Variant in forms:
			var form: Variant = forms[place]
			var record: Gene = organ.get_script().new()
			record.organ = organ.organ
			record.variants = organ.variants
			# The parts are the organ's, on every variant and form ([method declares]).
			record.declares = organ.declares
			_write_over(record, _fields_of(organ))
			# No copies at birth unless the variant or its form says so (above).
			record.born = 0
			_write_over(record, entry)
			if form is Dictionary:
				_write_over(record, form)
				record.key = StringName((form as Dictionary).get("key", &""))
			else:
				record.key = StringName(form)
			record.variant = StringName(entry.get("variant", &""))
			record.place = StringName(place)
			record.dose = StringName(entry.get("dose", &""))
			out.append(record)
	return out


## **[param key]'s words in an organ file's word tables** -- [param tables], its
## script's constants -- by [constant KEY_WORDS]' names.
static func _words_in(tables: Dictionary, key: StringName) -> Dictionary:
	var out := {}
	for table: String in KEY_WORDS:
		var entries: Variant = tables.get(table)
		if entries is Dictionary and (entries as Dictionary).has(key):
			out[KEY_WORDS[table]] = entries[key]
	for table: String in WAY_WORDS:
		var ways: Variant = tables.get(table)
		if ways is Dictionary:
			out[WAY_WORDS[table]] = ways
	return out


## Adds the words of every part an organ file's [param tables] have words for to
## [param into], part to [constant PART_WORDS]' names.
static func _part_words_into(into: Dictionary, tables: Dictionary) -> void:
	for table: String in PART_WORDS:
		var entries: Variant = tables.get(table)
		if not entries is Dictionary:
			continue
		for part: Variant in entries:
			if not into.has(part):
				into[part] = {}
			(into[part] as Dictionary)[PART_WORDS[table]] = entries[part]


## An empty dictionary, read-only.
static func _frozen_empty() -> Dictionary:
	var out := {}
	out.make_read_only()
	return out


## The fields of [param organ] a variant may set over, as a dictionary.
static func _fields_of(organ: Gene) -> Dictionary:
	var out := {}
	for field: String in OVERRIDES:
		out[field] = organ.get(field)
	return out


## Writes [param fields] over [param record], those of [constant OVERRIDES] only:
## a dictionary field key by key over a copy of what it had, the tags added to
## the ones it had, any other whole.
static func _write_over(record: Gene, fields: Dictionary) -> void:
	for field: Variant in fields:
		var name := String(field)
		if not OVERRIDES.has(name):
			continue
		var value: Variant = fields[field]
		if name == "tags":
			# **Tags add up** (gene.gd): a tag on an organ is on every variant and form
			# of it, so a variant's or a form's tags are added to what it has.
			var tags: Array[StringName] = []
			tags.assign(record.tags)
			for tag: Variant in value:
				if not tags.has(StringName(tag)):
					tags.append(StringName(tag))
			record.tags = tags
		elif value is Dictionary and record.get(name) is Dictionary:
			var merged: Dictionary = (record.get(name) as Dictionary).duplicate()
			merged.merge(value, true)
			record.set(name, merged)
		else:
			record.set(name, value)


## [param keys] with the ones [param shipped] names first, in its order, and the
## rest after them in their own.
static func _pinned(keys: Array[StringName], shipped: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in shipped:
		if keys.has(StringName(key)):
			out.append(StringName(key))
	for key: StringName in keys:
		if not out.has(key):
			out.append(key)
	return out


## **Every container a record holds, read-only all the way down** ([method _freeze]):
## what [method gene], [method levels], [method declares], [method table] and the
## rest hand out is the catalogue's own, and a reader that wrote into it would
## change that gene for every body.
const FROZEN: Array[StringName] = [&"provides", &"numbers", &"levels", &"water", &"tags",
	&"declares", &"variants", &"look"]


## [param value] made read-only, and every dictionary and array inside it.
static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for inner: Variant in (value as Dictionary).values():
			_freeze(inner)
		(value as Dictionary).make_read_only()
	elif value is Array:
		for inner: Variant in (value as Array):
			_freeze(inner)
		(value as Array).make_read_only()


## [param list], made read-only and handed back.
static func _read_only(list: Array[StringName]) -> Array[StringName]:
	list.make_read_only()
	return list


## [param pairs], `[key, table, ...]`, made read-only and handed back. The tables
## in it are the organs' own, not copies.
static func _read_only_pairs(pairs: Array) -> Array:
	pairs.make_read_only()
	return pairs
