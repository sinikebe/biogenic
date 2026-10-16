extends RefCounted
## **Specimens for photographing looks** (docs/design/gene-looks.md §9.4): variants of
## shipped organs, each wearing an accent, and organs no file holds, each a value of a
## kind's parameter no shipped organ uses -- registered in the catalogue the way the
## gene probe registers its own (`Catalogue.register`), drawn, and taken out again.
## Today's content has no variant but the organs as shipped, so a variant's accent can
## only be seen through these. `tools/looks_sheet.tscn` lays them out (`--variants=1`,
## `--room=1`) and `tools/drive.tscn -- --specimens=1` files the variants before a run
## is built, so the pause screen and the tray can be shot holding one. **The gene
## pass renders a new organ or variant this way**, beside its nearest neighbours.
##
## Keys a save or the wire would never hold (letters `a-z`, the wire's), orders from
## 950, no copies at birth. Their words are their keys and their variants' names: a
## specimen is a stand-in for the words a variant brings.
##
## Excluded from export (`tools/*`), so it never ships. No class_name, for the reason
## signal_bus.gd gives.

const Gene := preload("res://game/genes/gene.gd")
const Catalogue := preload("res://game/genes/catalogue.gd")
const Kinds := preload("res://game/genes/kinds.gd")

## **The variants**: an organ, by a stat or a tag that finds it, and its variants'
## entries -- each its own key, order and accent, and a strain its dose and forms.
## The organ as shipped stays its own file's, so each copy holds only the variants.
## **The ringed eye is rare** (docs/design/rarity-word-ux.md §7 item 8), a rare kind of
## an uncommon organ: no gene in today's water is rare, so this is how the screens' rare
## word is shot (`tools/drive.tscn -- --specimens=1 --sample=ocellusb`), through the
## catalogue's own rule for a variant -- the rarer of its organ's class and its own.
const VARIANTS: Array = [
	[&"beam_range", [
		{"variant": &"ringed", "key": &"ocellusb", "order": 950, "born": 0,
			"look": {"accent": Kinds.MARK_RING}, "water": {"rarity": &"rare"}},
		{"variant": &"keeled", "key": &"ocellusc", "order": 951, "born": 0,
			"look": {"accent": Kinds.MARK_DIAMOND}}]],
	[&"light", [
		{"variant": &"barred", "key": &"stigmab", "order": 952, "born": 0,
			"look": {"accent": Kinds.MARK_BAR}}]],
	[&"impulse_speed", [
		{"variant": &"rooted", "key": &"flagellumb", "order": 953, "born": 0,
			"look": {"accent": Kinds.MARK_DISC}}]],
	[&"venom_stacks", [
		{"variant": &"paralysing", "dose": &"paralysis", "look": {"accent": Kinds.MARK_DIAMOND},
			"forms": {Gene.INSIDE: {"key": &"paraneux", "order": 954},
				Gene.OUTSIDE: {"key": &"paracyst", "order": 955}}},
		{"variant": &"sleeping", "dose": &"sleep", "look": {"accent": Kinds.MARK_RING},
			"forms": {Gene.INSIDE: {"key": &"hypnoneux", "order": 956},
				Gene.OUTSIDE: {"key": &"hypnocyst", "order": 957}}}]],
	[&"sun", [
		{"variant": &"ringed", "key": &"plastidb", "order": 958, "born": 0,
			"look": {"accent": Kinds.MARK_RING}}]],
	[&"store", [
		{"variant": &"cored", "key": &"vacuoleb", "order": 959, "born": 0,
			"look": {"accent": Kinds.MARK_DISC}}]],
]

## **The organs no file holds** (gene-looks.md §2.4): what the vocabulary has room for
## without new drawing -- a hooked and a three-way tip, ringed tips bent, a barbed
## spine, a stack and a star, a two-wave lash, a four-turn coil. Key, family, look.
const ROOM: Array = [
	[&"zsensehook", Gene.SENSING,
		{"shape": Kinds.TUFT, "shade": 2, "length": 0.32, "tip": Kinds.TIP_HOOK}],
	[&"zsensetri", Gene.SENSING,
		{"shape": Kinds.TUFT, "shade": 0, "length": 0.32, "tip": Kinds.TIP_TRI}],
	[&"zsenseringbent", Gene.SENSING,
		{"shape": Kinds.TUFT, "count": 2, "length": 0.50, "tip": Kinds.TIP_RING,
			"bend": 30.0}],
	[&"zspinebarb", Gene.DEFENDING,
		{"shape": Kinds.SPINES, "shade": 2, "length": 0.32, "tip": Kinds.TIP_BARB}],
	[&"zgolgi", Gene.METABOLISM, {"shape": Kinds.ORGANELLE, "shade": 0,
		"form": Kinds.FORM_STACK}],
	[&"zcontract", Gene.METABOLISM, {"shape": Kinds.ORGANELLE, "shade": 2,
		"form": Kinds.FORM_STAR}],
	[&"zlashtwo", Gene.MOVING, {"shape": Kinds.LASH, "shade": 2, "count": 3,
		"length": 0.40, "wave": 0.20, "waves": 2.0}],
	[&"zcoilfour", Gene.MOVING, {"shape": Kinds.COIL, "shade": 0, "length": 0.44,
		"turns": 4}],
]


## **Files every variant of [constant VARIANTS]**, each organ a copy of its own file
## holding only the variants; the organs' names, to [method forget] them by.
static func file_variants() -> Array[StringName]:
	var organs: Array[StringName] = []
	for row: Array in VARIANTS:
		var organ := _organ_by(row[0])
		if organ == null:
			continue
		organ.variants = row[1]
		Catalogue.register(organ)
		organs.append(organ.organ)
	return organs


## **Files every organ of [constant ROOM]**: each one form outside, in its family, at
## no copies at birth and drifting nowhere.
static func file_room() -> Array[StringName]:
	var organs: Array[StringName] = []
	var order := 970
	for row: Array in ROOM:
		var organ := Gene.new()
		organ.organ = row[0]
		organ.order = order
		organ.family = row[1]
		organ.look = row[2]
		organ.water = {"drifter": false}
		Catalogue.register(organ)
		organs.append(organ.organ)
		order += 1
	return organs


## Takes back everything filed under [param organs].
static func forget(organs: Array[StringName]) -> void:
	for organ: StringName in organs:
		Catalogue.forget(organ)


## **A fresh copy of the organ [param found]** -- a stat it provides, or a channel it
## drives -- from its own file, so the copy is that organ in every field; null where
## nothing is found.
static func _organ_by(found: StringName) -> Gene:
	var key := Catalogue.first_provider(found)
	if key == &"":
		key = Catalogue.first_on(found)
	if key == &"":
		return null
	return (Catalogue.gene(key).get_script() as GDScript).new()
