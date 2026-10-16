extends RefCounted
## **Specimens for the water's rarity** (docs/design/gene-rarity.md §5.1, §11.3): the
## catalogue table 5.1 calls **the mixed hundred** -- one way the gene pass might reach a
## hundred genes: 20 new organs, 2 common, 6 uncommon and 12 rare, and 65 rare variants
## spread evenly over every organ the drifters carry, today's and the new, the commons'
## too -- 99 varieties in the drifters' pool. Registered in the catalogue the way the gene
## probe registers its own (`Catalogue.register`), and taken out again.
## `tools/drop_probe.gd`'s `rarity` section draws from it and runs a drop on it, and
## `tools/eco_probe.gd -- --genes=crowded` files it before a long run, to watch the floor
## work.
##
## Keys a save or the wire would never hold (letters `a-z`, from `zmix`), orders from
## 2000, no copies at birth, no look and no number: a body wearing one is drawn as a gene
## the build does not know and is read at nothing. What the water draws, makes and keeps
## of them is the subject.
##
## Excluded from export (`tools/*`), so it never ships. No class_name, for the reason
## signal_bus.gd gives.

const Gene := preload("res://game/genes/gene.gd")
const Catalogue := preload("res://game/genes/catalogue.gd")
const Rarity := preload("res://game/genes/rarity.gd")

## **The new organs** (table 5.1's mixed row): how many of each class, commonest first.
const NEW_ORGANS: Array = [[&"common", 2], [&"uncommon", 6], [&"rare", 12]]
## **The rare variants**, dealt round every organ the drifters carry, in the drifters'
## order and then the new organs' -- two to most, one to the last few.
const RARE_VARIANTS := 65
## The class every variant here is.
const VARIANT_CLASS := &"rare"
## Where the new organs' and the variants' orders start.
const ORGAN_ORDER := 2000
const VARIANT_ORDER := 3000


## **Files the mixed hundred**: the new organs, then every organ the drifters carry given
## its share of the rare variants -- a shipped one as a copy of its own file with the
## variants added, in that file's place, as the gene pass would write them. The organs'
## names, to [method forget] them by. [param extra], an organ name to entries, adds those
## entries to the organ of that name as well -- a new organ's name or a shipped one's.
static func file_mixed(extra: Dictionary = {}) -> Array[StringName]:
	var organs: Array[StringName] = []
	var fresh := {}
	var k := 0
	for row: Array in NEW_ORGANS:
		for n in int(row[1]):
			var organ := Gene.new()
			organ.organ = StringName("zmix" + _letters(k))
			organ.order = ORGAN_ORDER + k
			organ.water = {"rarity": StringName(row[0]), "drifter": true}
			fresh[organ.organ] = organ
			k += 1
	# Every organ the drifters carry: today's first, in the drifters' order, then the new.
	var carried: Array[StringName] = []
	for key: StringName in Catalogue.drifters():
		var organ := Catalogue.organ_of(key)
		if not Catalogue.has_tag(key, Catalogue.NOT_ON_DRIFTERS) and not carried.has(organ):
			carried.append(organ)
	for name: StringName in fresh:
		carried.append(name)
	var dealt := {}
	for v in RARE_VARIANTS:
		var to: StringName = carried[v % carried.size()]
		var key := StringName("zmixv" + _letters(v))
		if not dealt.has(to):
			dealt[to] = []
		(dealt[to] as Array).append({"variant": key, "key": key, "order": VARIANT_ORDER + v,
			"water": {"rarity": VARIANT_CLASS}})
	for name: Variant in extra:
		if not dealt.has(name):
			dealt[name] = []
		(dealt[name] as Array).append_array(extra[name])
	for name: StringName in carried:
		var organ: Gene = fresh.get(name, null)
		if organ == null:
			organ = (Catalogue.gene(Catalogue.first_key(name)).get_script() as GDScript).new()
		organ.variants = organ.variants + dealt.get(name, [])
		Catalogue.register(organ)
		organs.append(name)
	return organs


## Takes back everything filed under [param organs], each organ of a shipped name back to
## its own file.
static func forget(organs: Array[StringName]) -> void:
	for organ: StringName in organs:
		Catalogue.forget(organ)


## **The new organs' names**, by class: what [method file_mixed] files, before it files
## it.
static func new_organs(name: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var k := 0
	for row: Array in NEW_ORGANS:
		for n in int(row[1]):
			if StringName(row[0]) == name:
				out.append(StringName("zmix" + _letters(k)))
			k += 1
	return out


## [param k] in two letters, `aa` to `zz`.
static func _letters(k: int) -> String:
	return char(97 + (k / 26) % 26) + char(97 + k % 26)
