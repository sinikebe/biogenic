extends RefCounted
## **What two builds in one shared pond must agree on, written out and fingerprinted**
## (docs/design/gene-catalogue.md §11.3).
##
## A host judges each guest by its own copy of what the referee reads, and decides
## every contact -- a mouth on a body, a bite, a dose -- by its own tables, while the
## guest swims, feels and wears its doses by its own. Two builds whose copies differ
## share a pond one of them misjudges: a guest that grows as its own build grows is
## fouled and cut by a host on the old numbers, measured at 1.05 s after its first
## meal (net-hardening.md B.6). So the handshake carries this text's fingerprint, and
## two builds whose fingerprints differ refuse each other there, with the sentence
## that names the update (net_session.gd). **Nobody has to remember anything**: a gene
## that changes a judged table, a contact table or the body plan changes the text,
## and the text is the fingerprint. A gene that changes nothing judged -- a sense, a
## look, a stats line -- is not in it, and an older build keeps it as a name.
##
## **Written from the catalogue**, one line a value, in a fixed order:
##
## 1. every stat a row marks `judged` -- the referee judges a guest by it -- or
##    `contact` -- the host decides a contact by it (stats.gd) -- in the rows' order,
##    by every organ that provides it: the first under the line its table always had
##    (`Stats.label`), any other after it with its key. A new judged table is in it
##    without anyone listing it;
## 2. the run's numbers the referee judges a guest by that no organ provides, under
##    the names they have where they are defined;
## 3. the contact rules no table holds: the bite's gap and flank, `bite_damage` and
##    the doses' constants, by sample where a rule is a function;
## 4. the referee's own limits;
## 5. the body plan's fingerprint (body_plan.gd), so builds on other plans -- other
##    slot counts, other arcs -- refuse each other too.
##
## `tools/net_probe.gd` writes the same text again from the real constants, by name,
## and fails when the two differ, saying at which line; and `Wire.RULES` pins its
## SHA-256, so a build's rules change only on purpose (wire.gd). Moving that pin is
## the whole of it: `Wire.PROTOCOL` moves only when a message's format does.
##
## **It loads the game, so the wire does not**: wire.gd stays a file anything can
## load, and the session that speaks the handshake loads this. Nothing here loads
## anything under `game/net/` but the referee, which loads none of it either.
##
## No class_name, for the reason signal_bus.gd gives.

const Catalogue := preload("res://game/genes/catalogue.gd")
const Stats := preload("res://game/genes/stats.gd")
const BodyPlan := preload("res://game/genes/body_plan.gd")
const CellBody := preload("res://game/normal/cell.gd")
const FoodField := preload("res://game/normal/food.gd")
const Genome := preload("res://game/normal/genome.gd")
const Doses := preload("res://game/mechanics/doses.gd")
const Referee := preload("res://game/net/referee.gd")

## **The fingerprint's length**, in bytes: SHA-256's. The handshake carries it whole
## (wire.gd's `RULES_SIZE`).
const SIZE := 32

## **The referee's own limits**, by the names they have in referee.gd: the caps over
## motion, the slack on a radius and a ring, the shout's and the arrival's banks,
## the re-entry and the stall. A limit added to its judgement belongs here.
const REFEREE_LIMITS: Array[String] = ["MOVE_RATE", "MOVE_HOLD", "MOVE_SLACK", "TURN_RATE",
	"TURN_HOLD", "TURN_SLACK", "SPEED_MAX", "TURNING_MAX", "RADIUS_SLACK", "DAUGHTER_RADIUS",
	"OUT_STILL", "BIRTH_WAIT", "SISTER_DISTANCE", "SISTER_RING", "SHOUT_REACH", "SHOUT_PAST",
	"SHOUT_BANK", "SHOUT_EARLY", "ENTER_BANK", "ENTER_EVERY", "RADIUS_EPSILON", "PERSON_RATE",
	"PERSON_BANK", "FIRST_SENSES", "STALE_FOR", "REENTRY_KEEPS_WOUND", "REENTRY_WITHIN",
	"STALL_CREDIT"]


## **The fingerprint**: the SHA-256 of [method text], [constant SIZE] bytes, as the
## handshake carries it. Worked out from the catalogue in use each time it is asked,
## so a tool that registers or forgets an organ asks it of the catalogue it made.
static func fingerprint() -> PackedByteArray:
	return text().sha256_buffer()


## The same, as hex: what the server's log and `Wire.RULES` say.
static func hex() -> String:
	return text().sha256_text()


## **Every value two builds in one pond must agree on**, one `name=value` a line, in
## the order this file's note gives.
static func text() -> String:
	var lines: PackedStringArray = []
	var put := func(name: String, value: Variant) -> void:
		lines.append("%s=%s" % [name, value_text(value)])
	# 1. The stats two ends must agree on, by every organ that provides each.
	for stat: StringName in Stats.ROWS:
		var row: Dictionary = Stats.ROWS[stat]
		if not bool(row["judged"]) and not bool(row["contact"]):
			continue
		var providers := Catalogue.providers(stat)
		for k in providers.size():
			put.call(Stats.label(stat) + ("" if k == 0 else "." + String(providers[k])),
				Catalogue.table(providers[k], stat))
	# 2. The run's numbers the referee judges by. cell.gd: size, growth, division and
	# mending, and the motion its caps sit over.
	put.call("cell.BASE_RADIUS", CellBody.BASE_RADIUS)
	put.call("cell.GROWTH_PER_MEAL", CellBody.GROWTH_PER_MEAL)
	put.call("cell.DIVIDE_RADIUS", CellBody.DIVIDE_RADIUS)
	put.call("cell.DIVIDE_SPLIT", CellBody.DIVIDE_SPLIT)
	put.call("cell.daughter_radius", CellBody.daughter_radius(CellBody.DIVIDE_RADIUS))
	put.call("cell.MEND_SECONDS", CellBody.MEND_SECONDS)
	put.call("cell.mended(0.5,10)", CellBody.mended(0.5, 10.0))
	put.call("cell.IMPULSE_KICK", CellBody.IMPULSE_KICK)
	put.call("cell.DRAG", CellBody.DRAG)
	put.call("cell.DASH_COOLDOWN", CellBody.DASH_COOLDOWN)
	put.call("cell.WANDER_RATE", CellBody.WANDER_RATE)
	# food.gd: the grace, and what a contact and a death are called.
	put.call("food.FIRST_DELAY", FoodField.FIRST_DELAY)
	put.call("food.Contact", FoodField.Contact)
	put.call("food.Cause", FoodField.Cause)
	put.call("food.By", FoodField.By)
	# **The drop** (ocean.md §10.5): a floc grows nobody, so a graze is never a meal to
	# the referee; the rim, by a sample, holds a claim in and puts a sister by it; and
	# the two eating rules the host decides, a sample each -- a mouth swallows a
	# player that fits on contact (row 15), armour makes a body bigger to a mouth
	# (row 5).
	put.call("drop.FLOC_GROWTH", FoodField.Drop.FLOC_GROWTH)
	var held: Vector2 = FoodField.Drop.new().meniscus.contain(Vector2(7000.0, 125.0),
		Referee.DAUGHTER_RADIUS)
	put.call("drop.contain(7000,125;r28.28).x", held.x)
	put.call("drop.contain(7000,125;r28.28).y", held.y)
	put.call("food.swallows_player(not hunting, on contact)",
		FoodField.swallows_player(false, FoodField.CONTACT_SWALLOW, 20.0, 30.0))
	put.call("food.armoured_size(r30, pellicle 2)",
		FoodField.armoured_size(30.0, Stats.at(&"armor", 2), FoodField.ARMOUR_SWALLOW))
	# The run's sister ring, by the referee's copy of it -- the run's own is a scene's
	# constant this file cannot load without a cycle, and the probe holds the two
	# equal -- and the free senses, the catalogue's `gift` tag.
	put.call("run.SISTER_DISTANCE", Referee.SISTER_DISTANCE)
	put.call("run.FIRST_SENSES", Catalogue.tagged(Catalogue.GIFT))
	# genome.gd: the tiers, a born body -- each organ's own `born` -- and the gift's.
	put.call("genome.TIER_MAX", Genome.TIER_MAX)
	put.call("genome.BORN", Catalogue.born())
	put.call("genome.gift_tier", Genome.GIFT_TIER)
	# 3. **The contact rules no table holds** (shared-pond.md §7): the host decides
	# every bite and dose by these, and a guest feels and wears its own by them.
	put.call("cell.BITE_GAP", CellBody.BITE_GAP)
	put.call("cell.FLANK_AHEAD", CellBody.FLANK_AHEAD)
	put.call("cell.FLANK_ASTERN", CellBody.FLANK_ASTERN)
	put.call("cell.bite_damage(0.3,20,r30,1.3,ahead)",
		CellBody.bite_damage(0.3, 20.0, 30.0, 1.3, 0.0))
	put.call("cell.bite_damage(0.3,40,r30,1,astern)",
		CellBody.bite_damage(0.3, 40.0, 30.0, 1.0, PI))
	put.call("cell.VENOM_ARC_DEG", CellBody.VENOM_ARC_DEG)
	put.call("cell.VENOM_SIDES", CellBody.VENOM_SIDES)
	put.call("cell.HARM_PER_STACK", CellBody.HARM_PER_STACK)
	put.call("cell.DOSE_TAU_BY_KIND", CellBody.DOSE_TAU_BY_KIND)
	put.call("cell.DOSE_GONE", CellBody.DOSE_GONE)
	put.call("cell.DOSE_SIZE", CellBody.DOSE_SIZE)
	put.call("doses.felt(2,r30)", Doses.felt(2.0, 30.0, CellBody.DOSE_SIZE))
	# 4. The referee's own limits. **The gift's senses are no copy**: the referee
	# reads the catalogue's `gift` tag (§11.1), so its line is written from there.
	var referee: Dictionary = (Referee as Script).get_script_constant_map()
	for name: String in REFEREE_LIMITS:
		put.call("referee." + name, Catalogue.tagged(Catalogue.GIFT) if name == "FIRST_SENSES"
			else referee[name])
	# 5. The body plan.
	put.call("plan.fingerprint", BodyPlan.fingerprint())
	return "\n".join(lines)


## **One value, written the same way on every machine**: six places for a float, a
## list comma-joined, a dictionary by its keys in order.
static func value_text(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return "%.6f" % float(value)
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for each: Variant in value:
				parts.append(value_text(each))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = (value as Dictionary).keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var parts: PackedStringArray = []
			for key: Variant in keys:
				parts.append("%s:%s" % [str(key), value_text(value[key])])
			return "{" + ",".join(parts) + "}"
	return str(value)
