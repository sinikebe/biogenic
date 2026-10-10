extends RefCounted
## **The numbers behind every gene** (docs/design/gene-stats.md §5, §6), for a
## player who asked to see them, in the readout's items (game/mechanics/
## readout.gd), which know units and never genes. **Each organ says its own**
## (gene-catalogue.md §8.4): its file's `lines` hook, handed this screen's context
## -- the body's terms, the scripts its numbers come from and what wearing it
## costs. This file keeps the rest: the context, the costs line's last item, the
## odds and the caption.
##
## **Every value is read off the game's own numbers** -- each gene's own tables,
## and cell.gd's, genome.gd's, metabolism.gd's, food.gd's and signal_bus.gd's --
## so a rebalance moves the screen by itself, and nothing is a second copy of a
## number. A row is a template and its values. A gene with no row draws nothing,
## just as the pause screen says nothing for a gene it has no line for: a later
## gene arriving over older content, or a retired one, reads as a name and no
## numbers.
##
## **The numbers are the body's own** (§1.4): its copies, its beam's level and
## way, its own `burn` and `store`. Energy is in `energy.md`'s seconds of
## rest, read against the tank the caption states; a time second follows
## *every*, *in*, *after* or *over*, and an energy second follows *burns*,
## *worth*, *holds* or *makes* (§4). Distance is in µm, the world's own unit
## (owner's call 1, §11, answered on 2026-09-29).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Readout := preload("res://game/mechanics/readout.gd")
const CellBody := preload("res://game/normal/cell.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const MetabolismNode := preload("res://game/normal/metabolism.gd")
const FoodField := preload("res://game/normal/food.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
const Catalogue := preload("res://game/genes/catalogue.gd")
const Stats := preload("res://game/genes/stats.gd")

const U := Readout.Unit

## The odds line's words for a copy count, as the pause screen's hint says them.
##
## TRANSLATORS: How many copies of a gene the cell's DNA holds, in words, at the
## start of the odds line ("one copy · 55% of daughters wear it"). One to three;
## the numbers are spelled out on purpose.
const COPIES: Array[String] = ["", "one copy", "two copies", "three copies"]

## Below this a gene costs nothing to wear, and says so.
const FREE_BELOW := 0.0005


## **The body's own terms** (§6.2), from a `{gene: copies}` body: what its
## `burn` leaves of every cost, how much bigger its `store` makes the tank and
## what its `sun` makes -- each the stats', so no gene is named -- and its
## [param radius], which a dose is felt against (docs/design/dna-slots.md §6.1).
## **And what an organ's own lines read with** (gene.gd's `lines`): the tank those
## make, the scripts its numbers come from, which an organ may not preload, and
## this screen's own pricing, so a line prices as the screen does.
static func context(body: Dictionary, radius: float = CellBody.BASE_RADIUS) -> Dictionary:
	var reserve := Stats.of(body, &"store")
	return {
		"burn": Stats.of(body, &"burn"),
		"reserve": reserve,
		"sun": Stats.of(body, &"sun"),
		"radius": radius,
		"tank": MetabolismNode.HUNGER_SECONDS * reserve,
		"cell": CellBody,
		"metabolism": MetabolismNode,
		"food": FoodField,
		"bus": SignalBus,
		"genome": GenomeNode,
		"beat": _beat,
		"wear_item": wear_item,
	}


## **`[what it does, what it costs]`** for [param gene] worn at [param copies],
## in the body [param ctx] describes ([method context]). Each is an array of
## readout items, and `[[], []]` for a gene with no row. A levelled gene reads
## [param level] and [param path] instead of its copies (§5.2). [param slot] is
## where it is worn, for a gene whose numbers depend on it -- venom at the front
## and on a side are two rows -- and -1 where nobody knows.
##
## **Each organ says its own** (gene-catalogue.md §8.4): its file's `lines` hook,
## handed the context and what wearing it costs. A gene with no row draws nothing,
## as a retired one and a later one arriving over older content do.
static func lines(gene: StringName, copies: int, level: int, path: StringName,
		ctx: Dictionary, slot: int = -1) -> Array:
	var organ := Catalogue.gene(gene)
	if organ == null:
		return [[], []]
	var t := clampi(copies, 1, GenomeNode.TIER_MAX)
	var burn := float(ctx.get("burn", 1.0))
	var wear := wear_item(GenomeNode.UPKEEP_PER_TIER * float(t - 1), burn)
	# A context built without context() -- a bare `{}` -- still has what a line reads.
	var full := ctx if ctx.has("cell") else _completed(ctx)
	return organ.lines(t, level, path, full, slot, wear)


## [param ctx] with what [method context] adds for an organ's lines, for a caller
## that built its own.
static func _completed(ctx: Dictionary) -> Dictionary:
	var out := context({}, float(ctx.get("radius", CellBody.BASE_RADIUS)))
	out.merge(ctx, true)
	out["tank"] = MetabolismNode.HUNGER_SECONDS * float(out.get("reserve", 1.0))
	return out


## **What wearing a gene costs**: its own share of genome.gd's upkeep, as a
## rate. One copy costs nothing to wear, and that is worth reading.
##
## TRANSLATORS: The last item of a gene's costs line: what wearing the gene costs
## the cell. "Wearing" a gene is having it as an organ. "Burns {} s a second" is
## energy used, in seconds of the food tank, each second.
static func wear_item(extra_upkeep: float, burn: float) -> Dictionary:
	var rate := extra_upkeep * burn
	if rate < FREE_BELOW:
		return Readout.item("free to wear")
	return Readout.item("wearing it burns {} s a second", [rate], [U.RATE])


## One beat of a tail whose beat adds [param speed], in seconds of rest: the
## speed it adds on average, at the stroke's price, after `crista`.
static func _beat(speed: float, burn: float) -> float:
	return speed * CellBody.IMPULSE_MEAN * CellBody.STROKE_COST * burn


static func _tank(ctx: Dictionary) -> float:
	return MetabolismNode.HUNGER_SECONDS * float(ctx.get("reserve", 1.0))


## **The next level, for the end of a worn beam's costs line** (§5.2):
## `level 2 after 40 strikes`. A strike is one different body in the beam in
## one second, at most the beam's `xp_cap` a second, which is exactly what earns.
static func progress_item(level: int, to_next: float) -> Dictionary:
	var strikes := maxf(ceilf(to_next), 1.0)
	# TRANSLATORS: The last item of the beam's costs line: the next level, and how
	# many "strikes" earn it. A strike is one different body touched by the beam
	# in one second. The English has a singular for one strike and a plural for
	# any other number: give the forms your language needs.
	return Readout.item_n("level {} after {} strike", "level {} after {} strikes",
		int(strikes), [level + 1, strikes], [U.COUNT, U.COUNT])


## **The odds, with their percentage** (§5.4): `one copy · 55% of daughters
## wear it`. A certainty still says so in words.
static func odds_text(copies: int) -> String:
	var n := clampi(copies, 1, mini(GenomeNode.TIER_MAX, COPIES.size() - 1))
	var chance := GenomeNode.EXPRESS_CHANCE[n]
	var how_many := String(TranslationServer.translate(COPIES[n]))
	if chance >= 1.0:
		# TRANSLATORS: The odds line (14 px type) when the numbers switch is on: the
		# copies of the gene in words (see "one copy"), a middle dot, then whether a
		# daughter cell wears the gene. %s is "one copy", "two copies" or "three
		# copies", already translated: keep it first. The gene's rarity word, a level
		# and a gauge may share the row, which has 576 px.
		# ROOM: 350 px at 14 px with copies
		return String(TranslationServer.translate("%s · a daughter always wears it")) \
			% how_many
	# TRANSLATORS: The same line when the chance is not certain. The first %s is the
	# copies in words, as above; the second is a percentage such as "55%", so the
	# line reads "one copy · 55% of daughters wear it". Keep both %s in this order.
	# ROOM: 350 px at 14 px with copies, 80%
	return String(TranslationServer.translate("%s · %s of daughters wear it")) \
		% [how_many, Readout.format(chance, U.SHARE)]


## **The caption's clause** (§5.4, §6.2): how big this body is, what its full
## tank holds, and how long that lasts drifting -- the one number every cost
## adds up to. [param upkeep] is genome.gd's `upkeep()` for [param body]; the
## tail beats on its own schedule whether or not anyone steers, so it is in.
static func cell_items(radius: float, body: Dictionary, upkeep: float) -> Array:
	var ctx := context(body)
	var gap := (Stats.of(body, &"impulse_gap_min") + Stats.of(body, &"impulse_gap_max")) * 0.5
	var tail := _beat(Stats.of(body, &"impulse_speed"), float(ctx["burn"])) / gap
	var drifting := _tank(ctx) / maxf(maxf(upkeep - float(ctx["sun"]), 0.0) + tail, 0.05)
	# TRANSLATORS: Two items added to the pause screen's caption when the numbers
	# switch is on: the cell's width, and its food tank in seconds, then how long
	# the food lasts while the cell just drifts ("a full tank: 36 s, 12 s
	# drifting"). The whole caption is a small line in 15 px type.
	return [Readout.item("{} µm across", [radius * 2.0], [U.DISTANCE]),
		Readout.item("a full tank: {} s, {} s drifting", [_tank(ctx), drifting],
			[U.ENERGY, U.ENERGY])]
