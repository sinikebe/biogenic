extends RefCounted
## **The numbers behind every gene** (docs/design/gene-stats.md §5, §6), for a
## player who asked to see them. The one place gene names meet the readout
## (game/mechanics/readout.gd), which knows units and never genes.
##
## **Every value is read off the game's own constants** -- cell.gd, genome.gd,
## metabolism.gd, food.gd and signal_bus.gd -- so a rebalance moves the screen by
## itself, and nothing here is a second copy of a number. A row is a template
## and its values. A gene with no row draws nothing, just as the pause screen
## says nothing for a gene it has no line for: a later gene arriving over older
## content, or a retired one, reads as a name and no numbers.
##
## **The numbers are the body's own** (§1.4): its copies, its beam's level and
## way, its own `crista` and `vacuole`. Energy is in `energy.md`'s seconds of
## rest, read against the tank the caption states; a time second follows
## *every*, *in*, *after* or *over*, and an energy second follows *burns*,
## *worth*, *holds* or *makes* (§4). Distance is in µm, the world's own unit
## (owner's call 1, §11, answered on 2026-09-29).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Readout := preload("res://game/mechanics/readout.gd")
const RayFan := preload("res://game/mechanics/ray_fan.gd")
const CellBody := preload("res://game/normal/cell.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const MetabolismNode := preload("res://game/normal/metabolism.gd")
const FoodField := preload("res://game/normal/food.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")

const U := Readout.Unit

## The odds line's words for a copy count, as the pause screen's hint says them.
const COPIES: Array[String] = ["", "one copy", "two copies", "three copies"]

## Below this a gene costs nothing to wear, and says so.
const FREE_BELOW := 0.0005


## **The body's own terms** (§6.2), from a `{gene: copies}` body: what `crista`
## leaves of every cost, how much bigger `vacuole` makes the tank, and what
## `plastid` makes.
static func context(body: Dictionary) -> Dictionary:
	return {
		"burn": CellBody.BURN_BY_TIER[_index(body, &"crista", CellBody.BURN_BY_TIER.size())],
		"reserve": CellBody.STORE_BY_TIER[_index(body, &"vacuole",
			CellBody.STORE_BY_TIER.size())],
		"sun": CellBody.SUN_BY_TIER[_index(body, &"plastid", CellBody.SUN_BY_TIER.size())],
	}


static func _index(body: Dictionary, gene: StringName, size: int) -> int:
	return clampi(int(body.get(gene, 0)), 0, size - 1)


## **`[what it does, what it costs]`** for [param gene] worn at [param copies],
## in the body [param ctx] describes ([method context]). Each is an array of
## readout items, and `[[], []]` for a gene with no row. A levelled gene reads
## [param level] and [param path] instead of its copies (§5.2).
static func lines(gene: StringName, copies: int, level: int, path: StringName,
		ctx: Dictionary) -> Array:
	var t := clampi(copies, 1, GenomeNode.TIER_MAX)
	var burn := float(ctx.get("burn", 1.0))
	var wear := wear_item(GenomeNode.UPKEEP_PER_TIER * float(t - 1), burn)
	match gene:
		&"cytostome":
			var gape := CellBody.GAPE_BY_TIER[t]
			var bite := CellBody.BITE_BY_TIER[t]
			# The biggest meal is a body just inside the gape, and a meal is
			# worth its size against yours, clamped as food.gd clamps it.
			var share := MetabolismNode.MEAL * clampf(gape, FoodField.MEAL_MIN,
				FoodField.MEAL_MAX)
			var meal := Readout.item("its biggest meal fills you") if share >= 1.0 \
				else Readout.item("its biggest meal is worth {} s", [share * _tank(ctx)],
					[U.ENERGY])
			# What a bite takes depends on where it lands (cell.gd's `flank`):
			# the least at the nose, the most at the tail, so the line says both.
			return [[Readout.item("swallows whole under {} × your size", [gape], [U.TIMES]),
				Readout.item("bites take {} head-on, {} from behind",
					[bite * CellBody.FLANK_AHEAD, bite * CellBody.FLANK_ASTERN],
					[U.SHARE, U.SHARE])],
				[meal, wear]]
		&"cirrus":
			var rate := CellBody.TURN_RATE_BY_TIER[t]
			return [[Readout.item("a half turn in {} s", [PI / rate], [U.TIME]),
				Readout.item("the turn builds over {} s", [CellBody.TURN_RESPONSE_BY_TIER[t]],
					[U.TIME])],
				[Readout.item("turning burns {} s a second, {} s a half turn",
					[rate * CellBody.TURN_COST * burn, PI * CellBody.TURN_COST * burn],
					[U.RATE, U.ENERGY]), wear]]
		&"flagellum":
			var low := CellBody.IMPULSE_GAP_MIN_BY_TIER[t]
			var high := CellBody.IMPULSE_GAP_MAX_BY_TIER[t]
			var beat := _beat(t, burn)
			return [[Readout.item("swims about {} µm a second", [CellBody.speed_for(t)],
					[U.SPEED]),
				Readout.item("a beat every {}–{} s", [low, high], [U.TIME, U.TIME])],
				[Readout.item("beating burns {} s a second, {} s a beat",
					[beat / ((low + high) * 0.5), beat], [U.RATE, U.ENERGY]), wear]]
		&"stigma":
			return [[Readout.item("feels bodies over {} × your size",
					[FoodField.SHADOW_MIN_RATIO], [U.TIMES]),
				Readout.item("out to {} µm", [FoodField.SHADOW_RANGE], [U.DISTANCE]),
				Readout.item("a bearing to within {}", [SignalBus.LIGHT_HALFWIDTH_DEG[t]],
					[U.ANGLE])],
				[wear]]
		&"ocellus":
			return _beam(level, path, burn)
		&"chemocyte":
			return [[Readout.item("smells food out to {} µm", [CellBody.SMELL_RANGE_BY_TIER[t]],
					[U.DISTANCE]),
				Readout.item("{} as strong behind it", [FoodField.SMELL_BEHIND], [U.SHARE])],
				[wear]]
		&"ampulla":
			var through := CellBody.PING_THROUGH_BY_TIER[t]
			var past := Readout.item("stopped by any body") if through <= 0.0 \
				else Readout.item("{} passes a body", [through], [U.SHARE])
			return [[Readout.item("a ping every {} s", [CellBody.PING_PERIOD_BY_TIER[t]],
					[U.TIME]),
				Readout.item("out to {} µm", [CellBody.PING_RANGE_BY_TIER[t]], [U.DISTANCE]),
				Readout.item("the nearest {} answer", [FoodField.PING_RETURNS_BY_TIER[t]],
					[U.COUNT]),
				past],
				[wear]]
		&"axoneme":
			var push := CellBody.PUSH_ACCEL_BY_TIER[t]
			return [[Readout.item("holding on adds up to {} µm a second",
					[push / CellBody.DRAG], [U.SPEED])],
				[Readout.item("pushing burns {} s a second",
					[push * CellBody.STROKE_COST * burn], [U.RATE]), wear]]
		&"palp":
			return [[Readout.item("feels a body within {} µm of your skin",
					[CellBody.TOUCH_RANGE_BY_TIER[t]], [U.DISTANCE])],
				[wear]]
		&"myoneme":
			var burst := CellBody.DASH_SPEED_BY_TIER[t]
			# **Seconds of rest, scaled by `crista`** (owner's call 2, §11): the
			# run pays a dash through metabolism.gd's `spend`, as every other
			# cost is paid, so a bigger tank no longer makes it dearer.
			return [[Readout.item("a burst of {} µm a second, about {} µm in all",
					[burst, burst / CellBody.DRAG], [U.SPEED, U.DISTANCE]),
				Readout.item("again after {} s", [CellBody.DASH_COOLDOWN], [U.TIME])],
				[Readout.item("each dash burns {} s", [CellBody.DASH_COST_BY_TIER[t]
					* MetabolismNode.HUNGER_SECONDS * burn], [U.ENERGY]), wear]]
		&"trichocyst":
			return [[Readout.item("a dart at a hunter within {} µm, {} either side",
					[CellBody.DART_RANGE_BY_TIER[t], CellBody.DART_ARC_DEG * 0.5],
					[U.DISTANCE, U.ANGLE]),
				Readout.item("again after {} s", [CellBody.DART_COOLDOWN_BY_TIER[t]], [U.TIME])],
				[wear]]
		&"pellicle":
			var armour := CellBody.ARMOR_BY_TIER[t]
			return [[Readout.item("to a mouth you are {} × your size", [armour], [U.TIMES]),
				Readout.item("bites take {} less", [1.0 - 1.0 / armour], [U.SHARE])],
				[wear]]
		&"toxicyst":
			# The same seconds of rest, scaled the same way, as the dash above.
			return [[Readout.item("a biter takes back {} of its bite",
					[CellBody.VENOM_BITE_BACK_BY_TIER[t]], [U.SHARE]),
				Readout.item("a swallower dies, and you are spat out")],
				[Readout.item("being spat out burns {} s", [CellBody.VENOM_COST_BY_TIER[t]
					* MetabolismNode.HUNGER_SECONDS * burn], [U.ENERGY]), wear]]
		&"plastid":
			# Not scaled by `crista`: metabolism.gd takes the sun off the bill
			# as it is, after the bill has been discounted.
			return [[Readout.item("makes {} s of food every second", [CellBody.SUN_BY_TIER[t]],
					[U.RATE])],
				[wear]]
		&"vacuole":
			return [[Readout.item("a full tank holds {} s, not {}",
					[MetabolismNode.HUNGER_SECONDS * CellBody.STORE_BY_TIER[t],
						MetabolismNode.HUNGER_SECONDS], [U.ENERGY, U.ENERGY])],
				[wear]]
		&"crista":
			return [[Readout.item("everything burns {} less", [1.0 - CellBody.BURN_BY_TIER[t]],
					[U.SHARE])],
				[wear]]
	return [[], []]


## **The beam, by its level and its way** (§5.2): the fan from
## `CellBody.beam_shape`, and the price genome.gd charges for it.
static func _beam(level: int, path: StringName, burn: float) -> Array:
	var at := maxi(level, 1)
	var shape := CellBody.beam_shape(at, path)
	var rays := int(shape[0])
	var half := float(shape[1])
	var sweep := float(shape[2])
	var fan := 2.0 * half
	var reach := Readout.item("reaches {} µm", [shape[3]], [U.DISTANCE])
	var price := CellBody.levelled_upkeep(&"ocellus", at, path)
	if price < 0.0:
		price = GenomeNode.UPKEEP_PER_TIER * float(at - 1)
	var costs := [wear_item(price, burn)]
	if rays <= 1:
		return [[Readout.item("{} ray", [rays], [U.COUNT]), reach], costs]
	if sweep > 0.0:
		var lit := RayFan.revisit_of(rays, deg_to_rad(half), deg_to_rad(sweep))
		return [[Readout.item("{} rays sweeping {}", [rays, fan], [U.COUNT, U.ANGLE]),
			Readout.item("every bearing lit within {} s", [lit], [U.TIME]), reach], costs]
	# Past the fork, extending: more rays than the top rung has, so the spacing
	# between them is what a level buys, and it is said.
	var top := mini(CellBody.BEAM_FORK_LEVEL, CellBody.BEAM_COUNT_BY_TIER.size() - 1)
	if rays > CellBody.BEAM_COUNT_BY_TIER[top]:
		return [[Readout.item("{} rays across {}, one every {}",
			[rays, fan, fan / float(rays - 1)], [U.COUNT, U.ANGLE, U.ANGLE]), reach], costs]
	return [[Readout.item("{} rays across {}", [rays, fan], [U.COUNT, U.ANGLE]), reach],
		costs]


## **What wearing a gene costs**: its own share of genome.gd's upkeep, as a
## rate. One copy costs nothing to wear, and that is worth reading.
static func wear_item(extra_upkeep: float, burn: float) -> Dictionary:
	var rate := extra_upkeep * burn
	if rate < FREE_BELOW:
		return Readout.item("free to wear")
	return Readout.item("wearing it burns {} s a second", [rate], [U.RATE])


## One beat of a tail worn at [param tier], in seconds of rest: the speed it
## adds on average, at the stroke's price, after `crista`.
static func _beat(tier: int, burn: float) -> float:
	var t := clampi(tier, 0, CellBody.IMPULSE_SPEED_BY_TIER.size() - 1)
	return CellBody.IMPULSE_SPEED_BY_TIER[t] * CellBody.IMPULSE_MEAN \
		* CellBody.STROKE_COST * burn


static func _tank(ctx: Dictionary) -> float:
	return MetabolismNode.HUNGER_SECONDS * float(ctx.get("reserve", 1.0))


## **The next level, for the end of a worn beam's costs line** (§5.2):
## `level 2 after 40 strikes`. A strike is one different body in the beam in
## one second, at most `BEAM_XP_CAP` a second, which is exactly what earns.
static func progress_item(level: int, to_next: float) -> Dictionary:
	var strikes := maxf(ceilf(to_next), 1.0)
	return Readout.item("level {} after {} strike" if strikes == 1.0
		else "level {} after {} strikes", [level + 1, strikes], [U.COUNT, U.COUNT])


## **The odds, with their percentage** (§5.4): `one copy · 55% of daughters
## wear it`. A certainty still says so in words.
static func odds_text(copies: int) -> String:
	var n := clampi(copies, 1, mini(GenomeNode.TIER_MAX, COPIES.size() - 1))
	var chance := GenomeNode.EXPRESS_CHANCE[n]
	if chance >= 1.0:
		return "%s · a daughter always wears it" % COPIES[n]
	return "%s · %s of daughters wear it" % [COPIES[n], Readout.format(chance, U.SHARE)]


## **The caption's clause** (§5.4, §6.2): how big this body is, what its full
## tank holds, and how long that lasts drifting -- the one number every cost
## adds up to. [param upkeep] is genome.gd's `upkeep()` for [param body]; the
## tail beats on its own schedule whether or not anyone steers, so it is in.
static func cell_items(radius: float, body: Dictionary, upkeep: float) -> Array:
	var ctx := context(body)
	var t := clampi(int(body.get(&"flagellum", 0)), 0,
		CellBody.IMPULSE_GAP_MIN_BY_TIER.size() - 1)
	var gap := (CellBody.IMPULSE_GAP_MIN_BY_TIER[t] + CellBody.IMPULSE_GAP_MAX_BY_TIER[t]) * 0.5
	var tail := _beat(t, float(ctx["burn"])) / gap
	var drifting := _tank(ctx) / maxf(maxf(upkeep - float(ctx["sun"]), 0.0) + tail, 0.05)
	return [Readout.item("{} µm across", [radius * 2.0], [U.DISTANCE]),
		Readout.item("a full tank: {} s, {} s drifting", [_tank(ctx), drifting],
			[U.ENERGY, U.ENERGY])]
