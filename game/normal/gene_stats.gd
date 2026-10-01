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
##
## TRANSLATORS: How many copies of a gene the cell's DNA holds, in words, at the
## start of the odds line ("one copy · 55% of daughters wear it"). One to three;
## the numbers are spelled out on purpose.
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
			var share := MetabolismNode.meal(clampf(gape, FoodField.MEAL_MIN,
				FoodField.MEAL_MAX))
			# What a bite takes depends on where it lands (cell.gd's `flank`):
			# the least at the nose, the most at the tail, so the line says both.
			#
			# TRANSLATORS: The mouth gene (`cytostome`, shown as `eat`). "Its biggest
			# meal" is the largest body this mouth can swallow; "worth {} s" is how
			# many seconds of food it gives the cell. "Your size" is the cell's own
			# size. "Head-on" is when the bitten body faces the mouth, "from behind"
			# when it turns away.
			return [[Readout.item("swallows whole under {} × your size", [gape], [U.TIMES]),
				Readout.item("bites take {} head-on, {} from behind",
					[bite * CellBody.FLANK_AHEAD, bite * CellBody.FLANK_ASTERN],
					[U.SHARE, U.SHARE])],
				[Readout.item("its biggest meal fills you") if share >= 1.0
					else Readout.item("its biggest meal is worth {} s", [share * _tank(ctx)],
						[U.ENERGY]), wear]]
		&"cirrus":
			var rate := CellBody.TURN_RATE_BY_TIER[t]
			# TRANSLATORS: The steering gene (`cirrus`, shown as `turn`). "A half turn"
			# is turning round through 180 degrees; "burns {} s a second" is the
			# energy it uses, in seconds of the food tank, each second.
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
			# TRANSLATORS: The tail gene (`flagellum`, shown as `swim`). "A beat" is one
			# stroke of the tail. "µm" is micrometres, the unit of distance in the game
			# world; keep it.
			return [[Readout.item("swims about {} µm a second", [CellBody.speed_for(t)],
					[U.SPEED]),
				Readout.item("a beat every {}–{} s", [low, high], [U.TIME, U.TIME])],
				[Readout.item("beating burns {} s a second, {} s a beat",
					[beat / ((low + high) * 0.5), beat], [U.RATE, U.ENERGY]), wear]]
		&"stigma":
			# TRANSLATORS: The shadow-sensing gene (`stigma`, shown as `see`): it feels
			# the shadow of large bodies. "A bearing to within {}" means the direction
			# of a body is known to within that many degrees.
			return [[Readout.item("feels bodies over {} × your size",
					[FoodField.SHADOW_MIN_RATIO], [U.TIMES]),
				Readout.item("out to {} µm", [FoodField.SHADOW_RANGE], [U.DISTANCE]),
				Readout.item("a bearing to within {}", [SignalBus.LIGHT_HALFWIDTH_DEG[t]],
					[U.ANGLE])],
				[wear]]
		&"ocellus":
			return _beam(level, path, burn)
		&"chemocyte":
			# TRANSLATORS: The smell gene (`chemocyte`, shown as `smell`). "{} as strong
			# behind it" compares what it smells behind the cell with what it smells in
			# front, as a percentage.
			return [[Readout.item("smells food out to {} µm", [CellBody.SMELL_RANGE_BY_TIER[t]],
					[U.DISTANCE]),
				Readout.item("{} as strong behind it", [FoodField.SMELL_BEHIND], [U.SHARE])],
				[wear]]
		&"ampulla":
			var through := CellBody.PING_THROUGH_BY_TIER[t]
			# TRANSLATORS: The pulse gene (`ampulla`, shown as `ping`): a pulse that
			# answers back off every body it meets. "The nearest {} answer" means the
			# {} closest bodies send an answer (three to five, so always several);
			# "passes a body" is how much of the pulse goes on past a body in its way.
			return [[Readout.item("a ping every {} s", [CellBody.PING_PERIOD_BY_TIER[t]],
					[U.TIME]),
				Readout.item("out to {} µm", [CellBody.PING_RANGE_BY_TIER[t]], [U.DISTANCE]),
				Readout.item("the nearest {} answer", [FoodField.PING_RETURNS_BY_TIER[t]],
					[U.COUNT]),
				Readout.item("stopped by any body") if through <= 0.0
					else Readout.item("{} passes a body", [through], [U.SHARE])],
				[wear]]
		&"axoneme":
			var push := CellBody.PUSH_ACCEL_BY_TIER[t]
			# TRANSLATORS: The thrust gene (`axoneme`, shown as `push`): holding a finger
			# (or a key) on the water pushes the cell instead of only steering it.
			return [[Readout.item("holding on adds up to {} µm a second",
					[push / CellBody.DRAG], [U.SPEED])],
				[Readout.item("pushing burns {} s a second",
					[push * CellBody.STROKE_COST * burn], [U.RATE]), wear]]
		&"palp":
			# TRANSLATORS: The touch gene (`palp`, shown as `touch`): it feels what is
			# against the cell with no light at all.
			return [[Readout.item("feels a body within {} µm of your skin",
					[CellBody.TOUCH_RANGE_BY_TIER[t]], [U.DISTANCE])],
				[wear]]
		&"myoneme":
			var burst := CellBody.DASH_SPEED_BY_TIER[t]
			# **Seconds of rest, scaled by `crista`** (owner's call 2, §11): the
			# run pays a dash through metabolism.gd's `spend`, as every other
			# cost is paid, so a bigger tank no longer makes it dearer.
			#
			# TRANSLATORS: The burst-of-speed gene (`myoneme`, shown as `dash`): a tap
			# gives a short burst. "Again after {} s" is the wait before the next one.
			return [[Readout.item("a burst of {} µm a second, about {} µm in all",
					[burst, burst / CellBody.DRAG], [U.SPEED, U.DISTANCE]),
				Readout.item("again after {} s", [CellBody.DASH_COOLDOWN], [U.TIME])],
				[Readout.item("each dash burns {} s", [CellBody.DASH_COST_BY_TIER[t]
					* MetabolismNode.HUNGER_SECONDS * burn], [U.ENERGY]), wear]]
		&"trichocyst":
			# TRANSLATORS: The dart gene (`trichocyst`, shown as `sting`): it fires a dart
			# at a hunter that closes in on that side of the body. "{} either side" is
			# the angle, in degrees, to each side of straight ahead that it covers.
			return [[Readout.item("a dart at a hunter within {} µm, {} either side",
					[CellBody.DART_RANGE_BY_TIER[t], CellBody.DART_ARC_DEG * 0.5],
					[U.DISTANCE, U.ANGLE]),
				Readout.item("again after {} s", [CellBody.DART_COOLDOWN_BY_TIER[t]], [U.TIME])],
				[wear]]
		&"pellicle":
			var armour := CellBody.ARMOR_BY_TIER[t]
			# TRANSLATORS: The thicker-skin gene (`pellicle`, shown as `armor`). "To a mouth
			# you are {} × your size" means a hunting mouth must be that much wider than
			# the cell to swallow it, because of the skin.
			return [[Readout.item("to a mouth you are {} × your size", [armour], [U.TIMES]),
				Readout.item("bites take {} less", [1.0 - 1.0 / armour], [U.SHARE])],
				[wear]]
		&"veneneux":
			# The same seconds of rest, scaled the same way, as the dash above.
			#
			# TRANSLATORS: The poison gene (`veneneux`, shown as `venom`): a body that
			# bites the cell has to give part of its bite back, and a body that swallows
			# the cell dies while the cell is spat out alive, which costs the cell some
			# energy ("burns {} s").
			return [[Readout.item("a biter takes back {} of its bite",
					[CellBody.VENOM_BITE_BACK_BY_TIER[t]], [U.SHARE]),
				Readout.item("a swallower dies, and you are spat out")],
				[Readout.item("being spat out burns {} s", [CellBody.VENOM_COST_BY_TIER[t]
					* MetabolismNode.HUNGER_SECONDS * burn], [U.ENERGY]), wear]]
		&"plastid":
			# Not scaled by `crista`: metabolism.gd takes the sun off the bill
			# as it is, after the bill has been discounted.
			#
			# TRANSLATORS: The light-eating gene (`plastid`, shown as `sun`): the cell
			# makes a little food of its own from light.
			return [[Readout.item("makes {} s of food every second", [CellBody.SUN_BY_TIER[t]],
					[U.RATE])],
				[wear]]
		&"vacuole":
			# TRANSLATORS: The bigger-tank gene (`vacuole`, shown as `store`): the cell can
			# keep more food, so hunger takes longer to arrive. "A full tank holds {} s,
			# not {}" compares with the tank of a cell without it, in seconds of food.
			return [[Readout.item("a full tank holds {} s, not {}",
					[MetabolismNode.HUNGER_SECONDS * CellBody.STORE_BY_TIER[t],
						MetabolismNode.HUNGER_SECONDS], [U.ENERGY, U.ENERGY])],
				[wear]]
		&"crista":
			# TRANSLATORS: The cleaner-burning gene (`crista`, shown as `burn`): everything
			# the cell carries costs less energy to keep.
			return [[Readout.item("everything burns {} less", [1.0 - CellBody.BURN_BY_TIER[t]],
					[U.SHARE])],
				[wear]]
	return [[], []]


## **The beam, by its level and its way** (§5.2): the fan from
## `CellBody.beam_shape`, and the price genome.gd charges for it.
##
## TRANSLATORS: The light-ray gene (`ocellus`, shown as `beam`): it fires "rays",
## thin beams of light that mark whatever they strike. The number of rays is the
## count (2 to 64): give the forms your language needs for it. The singular of
## the two-part phrases is never shown in English, since a fan has at least two
## rays, but give it anyway. "{} rays across {}" is the angle the fan of rays
## covers, in degrees. "Every bearing lit within {} s" means the sweep has
## covered every direction of the fan within that many seconds.
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
		return [[Readout.item_n("{} ray sweeping {}", "{} rays sweeping {}", rays,
				[rays, fan], [U.COUNT, U.ANGLE]),
			Readout.item("every bearing lit within {} s", [lit], [U.TIME]), reach], costs]
	# Past the fork, extending: more rays than the top rung has, so the spacing
	# between them is what a level buys, and it is said.
	var top := mini(CellBody.BEAM_FORK_LEVEL, CellBody.BEAM_COUNT_BY_TIER.size() - 1)
	if rays > CellBody.BEAM_COUNT_BY_TIER[top]:
		return [[Readout.item_n("{} ray across {}, one every {}",
			"{} rays across {}, one every {}", rays,
			[rays, fan, fan / float(rays - 1)], [U.COUNT, U.ANGLE, U.ANGLE]), reach], costs]
	return [[Readout.item_n("{} ray across {}", "{} rays across {}", rays,
			[rays, fan], [U.COUNT, U.ANGLE]), reach],
		costs]


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
		# copies", already translated: keep it first. A level and a gauge may share
		# the row, which is 560 px wide.
		# ROOM: 430 px at 14 px with copies
		return String(TranslationServer.translate("%s · a daughter always wears it")) \
			% how_many
	# TRANSLATORS: The same line when the chance is not certain. The first %s is the
	# copies in words, as above; the second is a percentage such as "55%", so the
	# line reads "one copy · 55% of daughters wear it". Keep both %s in this order.
	# ROOM: 430 px at 14 px with copies, 80%
	return String(TranslationServer.translate("%s · %s of daughters wear it")) \
		% [how_many, Readout.format(chance, U.SHARE)]


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
	# TRANSLATORS: Two items added to the pause screen's caption when the numbers
	# switch is on: the cell's width, and its food tank in seconds, then how long
	# the food lasts while the cell just drifts ("a full tank: 36 s, 12 s
	# drifting"). The whole caption is a small line in 15 px type.
	return [Readout.item("{} µm across", [radius * 2.0], [U.DISTANCE]),
		Readout.item("a full tank: {} s, {} s drifting", [_tank(ctx), drifting],
			[U.ENERGY, U.ENERGY])]
