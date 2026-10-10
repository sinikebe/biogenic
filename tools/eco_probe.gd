extends SceneTree
## **The drop alone** (docs/design/ocean.md §15.2): the drop stepped for
## simulated minutes with a ghost player in it -- where a run would start, out of
## the water, so nothing hunts it and it senses nothing -- a census every
## `--every=` seconds, and the water's own cost a frame over each window.
##
##   godot --headless --path . -s res://tools/eco_probe.gd -- \
##       --seed=1 --until=1800 --every=300 --sensed=0.2
##
## - `--sensed=<0..1>`: the drop made for a player this sighted -- §5.9's 0.2 is
##   a newborn's composition and 0.6 a sighted player's. Default 0.2.
## - `--empty-room`: nobody at all, not even a ghost to anchor it, so every body
##   is on its tick (§10.3); the ghost is otherwise an anchor, so its
##   surroundings are stepped every frame and the spawner hides from it.
## - `--death-log`: one line per hunter that starves -- its age, meals, radius,
##   upkeep, reach and speed (§5.4's table).
## - `--genes=crowded`: the water of a hundred genes, filed before the drop is made --
##   the mixed hundred of docs/design/gene-rarity.md table 5.1 (`tools/rarity_specimens.gd`)
##   -- to watch the floor keep them over a long run in its `[rarity]` lines:
##   `--genes=crowded --sensed=1 --until=1800`, a fully sighted player's drop, the
##   floor's hardest case (§5.3, §11.3).
## - the drop's own switches, as `tools/drive.gd` takes them: `--lod=`,
##   `--half-rate=`, `--near-first=`, `--skip-still=`, `--own-speed=`,
##   `--notice=senses|fixed`, `--flight=none|all`, `--absorb=`,
##   `--contact-swallow=`, `--armour-swallow=`, `--drifter-toxin=` (or its old
##   name, `--drifter-venom=`); and pack 2's
##   (docs/design/lineage.md §12): `--births=0|1` (0 is pack 1), `--mutate=`,
##   `--floor=`, `--floor-tau=`, `--newborn-grace=`; and pack 3's
##   (docs/design/behaviour.md §12.1): `--rules=0|1`, 0 being pack 2's hand-written
##   hunter -- the reference the rules are measured against -- and
##   `--rule-change=0|1`, 0 being phase 3-1's water, whose rules never change at
##   a division; and pack 4's (docs/design/automation.md §5.4):
##   `--water-tail=pack3|row37`, `pack3` being pack 3's water, where a body swims
##   only while a swim rule fires, and `row37` the game's, where every tail that
##   swims beats unless it is held.
##
## Prints `[census]` lines, each followed by the drop's `[lineage]` line -- its
## hunters' generations, families and what they have become
## (docs/design/lineage.md §4, §6.1) -- its `[rarity]` line -- each class's genes in
## the drop and what the floor has given back of them (docs/design/gene-rarity.md
## §11.1) -- and its `[behaviour]` line -- how its
## hunters' rules fire and what they are doing, and last how many behaviours
## they carry, the share still on the founders' rules and the changes made at
## division (behaviour.md §12.1, §7.3) -- `[eco] cost p50 .. p90 ..` for each
## window, and the drop's counters at the end. The census samples dread from a
## stream of its own, so asking never moves the drop, and a seed prints the same
## lines every time.
## Excluded from export (`tools/*` on every preset), so none of it ships.

const CellBody := preload("res://game/normal/cell.gd")
const Genome := preload("res://game/normal/genome.gd")
## The catalogues `--genes=` files (docs/design/gene-rarity.md §11.3).
const RaritySpecimens := preload("res://tools/rarity_specimens.gd")


## **The field, with one line for every hunter that starves**, when asked.
class LoggedDrop extends "res://game/normal/food.gd":
	var log_deaths := false

	func _drop_lose(index: int, cause: int) -> void:
		var b: Body = _cells[index]
		if log_deaths and cause == Cause.STARVED and b.seeded and not b.drifter:
			print("[death] starved age %.1f meals %d r %.1f upkeep %.2f notice %.0f big %.0f"
				% [b.age, b.meals, b.radius, b.upkeep, b.notice, b.see_big]
				+ " speed %.1f gape %.1f" % [b.cruise, _gape(b)])
		super._drop_lose(index, cause)


var food: Node
var cell: Node
var until := 600.0
var every := 60.0
var t := 0.0
var clock := 0.0
var costs := PackedInt32Array()


func _initialize() -> void:
	var seed_value := 1
	var sensed := 0.2
	var empty := false
	var logged := false
	var genes := ""
	var sets := {}
	for a: String in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		if a.begins_with("--until="):
			until = float(v)
		elif a.begins_with("--every="):
			every = float(v)
		elif a.begins_with("--seed="):
			seed_value = int(v)
		elif a.begins_with("--sensed="):
			sensed = float(v)
		elif a == "--empty-room":
			empty = true
		elif a == "--death-log":
			logged = true
		elif a.begins_with("--genes="):
			genes = v
		elif a.begins_with("--notice="):
			sets[&"notice_by_senses"] = v != "fixed"
		elif a.begins_with("--flight="):
			sets[&"flight"] = v == "all"
		elif a.begins_with("--absorb="):
			sets[&"absorb"] = float(v)
		elif a.begins_with("--births="):
			sets[&"births"] = v == "1"
		elif a.begins_with("--mutate="):
			sets[&"mutate"] = float(v)
		elif a.begins_with("--floor="):
			sets[&"floor_share"] = float(v)
		elif a.begins_with("--floor-tau="):
			sets[&"floor_tau"] = float(v)
		elif a.begins_with("--newborn-grace="):
			sets[&"newborn_grace"] = float(v)
		elif a.begins_with("--rules="):
			sets[&"rules"] = v == "1"
		elif a.begins_with("--rule-change="):
			sets[&"rule_change"] = v == "1"
		elif a.begins_with("--water-tail="):
			sets[&"tails_beat"] = v != "pack3"
		elif a.begins_with("--drifter-toxin=") or a.begins_with("--drifter-venom="):
			# Row 13's switch, renamed with the toxin's two forms
			# (docs/design/dna-slots.md §9); the old name still reads.
			sets[&"drifter_toxin"] = v == "1"
		else:
			for name: String in ["lod", "half-rate", "near-first", "skip-still", "own-speed",
					"contact-swallow", "armour-swallow"]:
				if a.begins_with("--%s=" % name):
					sets[StringName(name.replace("-", "_"))] = v == "1"
	var filed: Array[StringName] = []
	if genes == "crowded":
		filed = RaritySpecimens.file_mixed()
	elif genes != "":
		push_error("[eco] --genes=%s: no such catalogue (crowded is the one)" % genes)
	seed(seed_value)
	cell = CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	food = LoggedDrop.new()
	food.log_deaths = logged
	food.sensed_override = sensed
	for key: StringName in sets:
		food.set(key, sets[key])
	# Stepped by hand below, one fixed frame at a time, and timed.
	food.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(food)
	food.setup_drop(cell)
	food.in_water = false
	food.anchored = not empty
	print("[eco] seed %d  sensed %.2f  %s  switches %s%s" % [seed_value, sensed,
		"an empty room" if empty else "a ghost player, anchored", sets,
		"" if filed.is_empty() else "  genes: the mixed hundred, %d varieties in the water's pool"
		% food.get(&"_drifter_pool").size()])
	print(food.census_line())
	print(food.lineage_line())
	print(food.rarity_line())
	print(food.behaviour_line())


func _process(_delta: float) -> bool:
	var dt := 1.0 / 60.0
	var began := Time.get_ticks_usec()
	food._process(dt)
	costs.append(Time.get_ticks_usec() - began)
	t += dt
	clock += dt
	if clock >= every - 1e-6:
		clock = 0.0
		print(food.census_line())
		print(food.lineage_line())
		print(food.rarity_line())
		print(food.behaviour_line())
		var sorted := costs.duplicate()
		sorted.sort()
		print("[eco] cost p50 %d us  p90 %d us  over %d frames  stepped %d a frame"
			% [sorted[int(0.5 * (sorted.size() - 1))], sorted[int(0.9 * (sorted.size() - 1))],
			sorted.size(), food.stepped_bodies()])
		costs.resize(0)
	if t >= until - 1e-6:
		print("[eco] stats ", food.stats)
		food.queue_free()
		cell.free()
		quit()
	return false
