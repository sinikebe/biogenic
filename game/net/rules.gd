extends RefCounted
## **What two builds in one shared pond must agree on, written out and fingerprinted**
## (docs/design/gene-catalogue.md §11.3).
##
## A host judges each guest by its own copy of what the referee reads, and decides
## every contact -- a mouth on a body, a bite, a dose, a dart -- by its own tables, while
## the guest swims, feels and wears its doses by its own. Two builds whose copies differ
## share a pond one of them misjudges: a guest that grows as its own build grows is
## fouled and cut by a host on the old numbers, measured at 1.05 s after its first
## meal (net-hardening.md B.6). So the handshake carries this text's fingerprint, and
## two builds whose fingerprints differ refuse each other there, with the sentence
## that names the update (net_session.gd). **Nobody has to remember anything**: a gene
## that changes a judged table, a contact table or the body plan changes the text,
## and the text is the fingerprint. A gene that changes nothing judged -- a sense, a
## look, a stats line -- is not in it, and an older build keeps it as a name.
##
## **Written the same on every machine, by construction.** A phone on arm64 or armv7,
## a PC and the Linux server each work this text out for themselves, and one last
## digit that came out otherwise on one of them would keep two honest builds apart,
## with nothing on either screen to say why. So every line keeps three rules:
##
## - **its number is a literal, or comes from literals by + − × ÷ and sqrt only.** IEEE
##   754 rounds each of those to the same bits on every chip, and the engine is built
##   never to fuse a multiply and an add (`-ffp-contract=off`, `/fp:strict`). Anything
##   else -- pow, exp, log, atan2 -- is the C library's, and libraries differ in the
##   last bit;
## - **cos and sin only at 0 and π**, the two angles at which every library returns
##   the same, exact value;
## - **no Vector2 or Transform method** -- `length`, `normalized`, `angle`, `rotated`:
##   theirs is the engine's arithmetic in 32 bits, with the C library under some of
##   it. A Vector2's components may be written and read: storing a double in one rounds
##   it to the nearest 32-bit float, which IEEE fixes.
##
## **And it is written with Godot alone**: a float as a whole number of millionths,
## `str(roundi(x * 1e6))` -- one product, one rounding to the nearest whole number and
## Godot's own digits -- never through `%f`, which is the C library's printf on each
## platform. `tools/net_probe.gd` fails a float whose millionths lie within a thousandth
## of a half, naming its line, so no value is printed on an edge one machine's last bit
## could tip; and a value of a kind [method value_text] does not write digit by digit.
##
## **Written from the catalogue**, one line a value, in a fixed order:
##
## 1. every stat a row marks `judged` -- the referee judges a guest by it -- or
##    `contact` -- the host decides a contact by it (stats.gd) -- in the rows' order:
##    first the stat's row, the fields of it that decide a body's value
##    ([constant ROW_FIELDS]), then its table by every organ that provides it, the
##    first under the line its table always had (`Stats.label`), any other after it
##    with its key. A new judged table is in it without anyone listing it. **Where a
##    body could wear two of those organs and the stat's mechanic acts from a place**
##    (stats.gd's `SEATED`), one line more names the stat whose organ it is read off
##    (stats.gd's `seat_of`): every number of it is that one organ's, the first in the
##    body's slots, never the best of two -- a rule as a row's fields are, written
##    only where it chooses;
## 2. the run's numbers the referee judges a guest by that no organ provides, under
##    the names they have where they are defined;
## 3. the contact rules no table holds: the bite's gap and flank, `bite_damage`, the
##    doses' constants, and the dart's arc and stun, by sample where a rule is a
##    function;
## 4. the referee's own limits ([constant REFEREE_LIMITS]);
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
## **The kinds of list [method value_text] writes item by item**, so a float in one is
## written as every float is.
const LISTS: Array[int] = [TYPE_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY,
	TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY]

## **The fields of a stat's row that decide a body's value**, in the order its line
## writes them, each as `name:value`: the value with no provider, which way is better,
## how several providers combine, and the group whose best provider a body takes the
## whole of (gene-catalogue.md §5.1) -- what stats.gd's `of` and `top` read. Two
## builds whose rows combine two providers otherwise give one body two values, so a
## row is a rule as its tables are. **A field a later build reads to decide a value is
## one more name at the end of this list**, and so one more `name:value` item at the
## end of every row's line that has it, as `group` was in phase 5.
## `tools/net_probe.gd` fails on a field of a row that is neither here nor in
## [constant ROW_FIELDS_UNREAD].
const ROW_FIELDS: Array[String] = ["none", "better", "combine", "group"]
## **The fields of a row that decide no value**, each with why it is not written.
const ROW_FIELDS_UNREAD := {
	"unit": "what the stats screen counts the stat in",
	"judged": "whether the row is here at all, which its lines say",
	"contact": "whether the row is here at all, which its lines say",
}

## **The referee's own limits**, by the names they have in referee.gd and in its
## order: what each foul weighs on the ledger, how often one rule may foul, and the
## ledger's cut and decay, which turn those weights into a cut; the caps over motion, the slack on a radius and a ring, the shout's and the arrival's
## banks, the re-entry and the stall. **Every constant of referee.gd is here or in
## [constant REFEREE_NOT_LIMITS]**, and `tools/net_probe.gd` fails on one in neither,
## so a limit added to the referee's judgement is in the rules or said not to be. One
## list: the probe writes the limits from this one, and sorts referee.gd by it.
const REFEREE_LIMITS: Array[String] = ["WEIGHT_MOVE", "WEIGHT_TURN", "WEIGHT_SIZE",
	"WEIGHT_OUT", "WEIGHT_SHOUT", "WEIGHT_ENTER", "WEIGHT_BODY_RATE", "WEIGHT_BODY",
	"WEIGHT_SISTER", "WEIGHT_SISTER_OFF", "WEIGHT_DIED", "FOUL_EVERY", "STRIKE_CUT",
	"STRIKE_DECAY", "MOVE_RATE", "MOVE_HOLD", "MOVE_SLACK", "TURN_RATE", "TURN_HOLD",
	"TURN_SLACK", "SPEED_MAX", "TURNING_MAX", "RADIUS_SLACK", "DAUGHTER_RADIUS",
	"OUT_STILL", "BIRTH_WAIT", "SISTER_DISTANCE", "SISTER_RING", "SHOUT_REACH",
	"SHOUT_PAST", "SHOUT_BANK", "SHOUT_EARLY", "ENTER_BANK", "ENTER_EVERY",
	"RADIUS_EPSILON", "PERSON_RATE", "PERSON_BANK", "STALE_FOR", "REENTRY_KEEPS_WOUND",
	"REENTRY_WITHIN", "STALL_CREDIT"]
## **The constants of referee.gd that are no limit**, each with why.
const REFEREE_NOT_LIMITS := {
	"CellBody": "a script it loads: what it judges by there is a line above, by name",
	"Catalogue": "a script it loads: the gift and who may call are lines above",
	"Stats": "a script it loads: every table it reads is a line above",
	"FoodField": "a script it loads: the grace and the names of contacts are above",
	"Basin": "a script it loads: the rim's arithmetic, sampled above",
	"MOVE": "a rule's name, as the log and the tools say it: it judges nothing",
	"TURN": "a rule's name, as the log and the tools say it: it judges nothing",
	"SIZE": "a rule's name, as the log and the tools say it: it judges nothing",
	"OUT": "a rule's name, as the log and the tools say it: it judges nothing",
	"SHOUT": "a rule's name, as the log and the tools say it: it judges nothing",
	"ENTER": "a rule's name, as the log and the tools say it: it judges nothing",
	"BODY": "a rule's name, as the log and the tools say it: it judges nothing",
	"SISTER": "a rule's name, as the log and the tools say it: it judges nothing",
	"DIED": "a rule's name, as the log and the tools say it: it judges nothing",
	"RULES": "the rules' names, in the log's order: it judges nothing",
	"Budget": "the class its budgets are made of: their numbers are the limits",
}


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
	# 1. The stats two ends must agree on: each one's row, then its table by every
	# organ that provides it.
	for stat: StringName in Stats.ROWS:
		var row: Dictionary = Stats.ROWS[stat]
		if not bool(row["judged"]) and not bool(row["contact"]):
			continue
		lines.append("stat.%s=%s" % [stat, row_text(row)])
		var providers := Catalogue.providers(stat)
		for k in providers.size():
			put.call(Stats.label(stat) + ("" if k == 0 else "." + String(providers[k])),
				Catalogue.table(providers[k], stat))
		# **Which organ's, where two could be**: a mechanic with a place reads every
		# number of it off the one organ it acts from (stats.gd's `seated`). With one
		# organ to provide it there is nothing to choose, and no line.
		var seat := Stats.seat_of(stat)
		if seat != &"" and providers.size() > 1:
			put.call("stat.%s.seat" % stat, seat)
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
	# equal -- and the free senses, the catalogue's `gift` tag, which the referee
	# reads too (§11.1): no copy of its own any more, so no line of its own.
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
	# **The dart** (behaviour.md §4.3): the host fires a guest's dart at a cell coming
	# for it, on the arc its organ is worn on, and stuns what it hits for the organ's
	# own number -- read at one copy of each organ that darts, as the tables are.
	put.call("cell.DART_ARC_DEG", CellBody.DART_ARC_DEG)
	var darts := Catalogue.providers(&"dart_range")
	for k in darts.size():
		put.call("cell.dart_stun" + ("" if k == 0 else "." + String(darts[k])),
			CellBody.dart_stun({darts[k]: 1}))
	# 4. The referee's own limits.
	var referee: Dictionary = (Referee as Script).get_script_constant_map()
	for name: String in REFEREE_LIMITS:
		put.call("referee." + name, referee.get(name))
	# 5. The body plan.
	put.call("plan.fingerprint", BodyPlan.fingerprint())
	return "\n".join(lines)


## **One value, written the same way on every machine**, by Godot alone: a float as a
## whole number of millionths, a list comma-joined, a dictionary by its keys in order,
## and a whole number, a bool or a name as itself.
static func value_text(value: Variant) -> String:
	var kind := typeof(value)
	if kind == TYPE_FLOAT:
		return str(roundi(float(value) * 1e6))
	if LISTS.has(kind):
		var parts: PackedStringArray = []
		for each: Variant in value:
			parts.append(value_text(each))
		return "[" + ",".join(parts) + "]"
	if kind == TYPE_DICTIONARY:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var parts: PackedStringArray = []
		for key: Variant in keys:
			parts.append("%s:%s" % [str(key), value_text(value[key])])
		return "{" + ",".join(parts) + "}"
	return str(value)


## **A stat's row, as its line says it**: each of [constant ROW_FIELDS] the row has, as
## `name:value`, in that order.
static func row_text(row: Dictionary) -> String:
	var items: PackedStringArray = []
	for field: String in ROW_FIELDS:
		if row.has(field):
			items.append("%s:%s" % [field, value_text(row[field])])
	return ",".join(items)
