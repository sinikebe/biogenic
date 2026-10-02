extends Node
## CI probe: **the drop** (docs/design/ocean.md §14.3). The mechanics a finite
## water is built on -- the grid, the basin, the replenisher, the snowfall --
## against brute force and against their own arithmetic; the drop's own
## decisions, each on its own; one tank for every body: the player's metabolism
## node against the water's own; and **the drop in the water** -- nothing made
## where it can be seen, nothing past the rim, growth that stops, the floors,
## one seed one drop, flocs, and one body for every cell -- over five minutes
## of a drop and on bodies posed in one. **And the dev app's frame readout**
## (§14.2), run for real: CI runs release-stamped, so nothing else here ever
## runs its frames. **And 13, the replay on the drop** (§11): the 48 nearest in
## slots they keep, today's water recorded as it always was, flocs as SETTLE and
## CLEAR, the killer, and a replay that leaves the drop untouched. **And 12, the
## save, as far as 1b-1 needs it** (§9): the bodies to the bit through the file,
## a real run left and opened again on the same drop and the same cell, an
## unknown format, and a changed `rules`. The room's census is 1b-2's. **And
## pack 2's** (docs/design/lineage.md §11.3): 2-1's -- the lineage kept to the
## bit and a file without it loaded as founders, the sister a daughter in full,
## and the identity gate, with births off `dev`'s census lines -- and 2-2's, the
## water dividing: over three five-minute drops, every division the player's,
## every daughter's body a roll of her DNA, today's count as the floor, the food
## to its own count whatever the hunters number, no run at a body in its grace,
## a meal that writes the DNA alone (lineage 1 to 6); one seed one drop with
## births (7); a room kept and loaded going on dividing (8); the sister's grace
## (9); and the dev app's readout counting generations and families. **And your
## drops** (docs/design/settings.md §6, §8 phase 2): a run plays the selected one
## and its keep writes the drop's line into the index; the first launch after the
## update finds today's `drop.save` as slot 1, the same bytes; a save this build
## cannot read is never set aside by reading; a lost or unreadable index is
## rebuilt from the files; new, rename and delete round the index; switching the
## selected drop switches the water and the cell; delete never takes the drop you
## are in, nor leaves its files; a tool's run never touches the drops; and a
## default name is said in the language of the moment, a typed one never. **And
## pack 3's first phase** (docs/design/behaviour.md §12.3, phase 3-1), the water
## on rules: 1, with the rules off it is pack 2 to the byte -- the two drops the
## lineage checks read run on pack 2's hunter from seed 1 and print `dev`'s
## five-minute census and lineage lines, and forty seconds of a membrane fed by
## every sense the player can have digest to `dev`'s; 2, a water cell posed as
## you are reads what your organs read, to the float; 3, no magic -- a gene a
## body carries and does not wear is never read, and a reading moves with
## nothing its organs do not reach; 7, the save keeps every body's rules and what
## they had it doing to the bit, loads a pack-2 file on the founders' rules
## resting on, keeps a name it does not know, and a room on rules goes on as one
## that never stopped; 9, in five minutes every founders' rule fires and a nose,
## a radar and a laser each feed a hunter; 10, the wake and both darts answer a
## mouth swimming at you within 35° that could take you, and neither one passing
## nor one too small, and a dart stuns for 5 s. The checks that read pack 2's
## hunter -- its runs, its searches, the grace no run begins at -- read it on the
## reference drops, and the five-minute drop of a sighted player is on rules.
## **And pack 3's second phase** (behaviour.md §12.3, phase 3-2), the rules
## changing at division: 4, ten thousand changes, from the founders' rules and
## from random lists, each within §6.2's limits by this probe's own reading,
## one change of the kind it says from its parent, drawing nothing new from past
## what the body, the metabolism and its DNA declare, and the same through its
## text; 5, every division of a drop on rules gives the daughter whose DNA
## changed her mother's list with one change and her sister her mother's list
## itself, every division on pack 2's hunter both her mother's, and every body
## the water makes, poses or leaves as a sister the founders' rules; 6, one seed
## with the changes on prints the same census, lineage and behaviour lines
## twice, and with them off prints phase 3-1's; 8, a gene declared only here,
## with an input and an output of its own and its reader and trigger wired here,
## is in the vocabulary of a body that carries it, drawn by a change -- straight
## and at a division -- read and acted on by a rule, and saved and loaded by
## name. And check 7 now keeps a room whose rules change as it goes, and the
## readout counts the water's behaviours.
##
## **Every check here fails with its fix taken out**, and was shown to by
## mutation when it was written: a grid that forgets the edge buckets stand for
## everything past them, a basin that puts a body back on the rim in 32 bits
## without pulling it inside, a replenisher whose debt outgrows its shortfall, a
## Poisson draw cut off at 64, a node that works out its own rate. And 1a-2's:
## a spawner that hides a peer at a drifter's reach, a body left past the rim, a
## growth with no ceiling, a drifter drawn from the venom list, a prey search
## that stops too far out, a floc eaten unsettled, a poisoned body that leaves
## nothing, a body armoured against the player only. And 1a-3's: a body that
## loses its slot while it stays near, newcomers out of the field's order, a
## floc never cleared, a seal that names no killer, a replay that writes onto
## the run's own field. And 1b-1's: a load that forgets a mouth's clock, a run
## that opens on the drop but not on the cell, a daughter pair not kept, an
## unknown format left where it was, a radius left past the cap, and the
## fingerprint's tables sorted as StringNames. And pack 2's first, 2-1's: a save
## that drops the DNA, a grace kept in 32 bits, a DNA kept out of its order, a
## 1b body or cell come back with no line, a column read without being checked,
## a cell's record not kept, a sister who is the daughter's child, carries only
## her body or, in a pond, nothing at all, a meal that writes only the DNA, and
## a sister who wears what she carries. And 2-2's, one a rule: a body at forty
## that waits out its rest to divide, daughters who wear their whole DNA, a
## spawner with no floor, one debt over the whole drop again, a prey search blind
## to the grace, a meal that writes the body too, a daughters' coin no seed
## reaches, a load that forgets the grace, a sister born without one, a meal that
## writes the DNA alone with births off, and a readout without its families.
## And your drops': slot 1 moved by the migration, a peek that sets a file aside,
## a read that writes the index, a lost index that forgets the files, a tool's run
## that keeps the selected drop, a run that always plays slot 1, the drop you are
## in deletable, a delete that leaves its `.tmp` and `.save.old`, a menu that
## offers delete on the drop you are in, a keep that does not tell the index, a
## default said only in English, a default's French kept as a typed name, its
## English kept as one in French, a new drop offered a default another wears in
## French, and a naming field left in the language it opened in. And pack 3's
## first phase, one a rule: a number drawn as a body is renewed, a nose that
## weighs a body by its bare radius, a water cell's nose on another arc, a call
## that hears half its reach, a rulebook that reads what a body does not wear, a
## nose that reaches as far as yours, an eyespot read that is not worn, a memory
## the load forgets, a pack-2 file whose hunters stop resting, a list index the
## file does not check, a laser that never reports, "coming for you" with no cone
## or no mouth to take you with, a stun a second short, a stunned body that reads
## its rules, and a dart forgotten before it is felt. And its second phase's: a
## nudge that steps past the end of its ladder, a replace that can draw the part
## it replaces, a swap of two equal rules, a copy with no room, a list dropped to
## nothing, two tests on one value, a turn on an input with no bearing, a change
## drawn from every gene there is, weights the draw ignores, a list written
## through, both daughters changed, the faithful daughter changed, nothing
## changed, a door that keeps a slot's last rules, a change no seed reaches, a
## switch that still draws, a vocabulary deaf to a gene's declaration, a change
## blind to a gene the DNA carries and the body does not wear, and a readout that
## counts lists rather than behaviours.
##
## Headless and deterministic: one seed, set first. Prints one line per check
## and `ALL PASS` only if every one held; CI asserts on that marker rather than
## on the exit code, because Godot exits 0 after a script error too.

const SpaceGrid := preload("res://game/mechanics/space_grid.gd")
const Basin := preload("res://game/mechanics/basin.gd")
const Replenish := preload("res://game/mechanics/replenish.gd")
const Snowfall := preload("res://game/mechanics/snowfall.gd")
const Drop := preload("res://game/normal/drop.gd")
const Metabolism := preload("res://game/normal/metabolism.gd")
const CellBody := preload("res://game/normal/cell.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const FoodField := preload("res://game/normal/food.gd")
const FrameReadout := preload("res://game/dev/frame_readout.gd")
const MotesField := preload("res://game/normal/motes.gd")
const Cilia := preload("res://game/vision/cilia.gd")
const RecorderNode := preload("res://game/replay/recorder.gd")
const DropSave := preload("res://game/normal/drop_save.gd")
const Drops := preload("res://game/normal/drops.gd")
const Descent := preload("res://game/mechanics/descent.gd")
const Rulebook := preload("res://game/mechanics/rulebook.gd")
const RayFan := preload("res://game/mechanics/ray_fan.gd")

## Somewhere other than the origin, as the drop is once a run has started in it.
const OFF_CENTRE := Vector2(-1234.5, 2345.25)

var _failed := 0


## **A water that takes a known time**: at least [constant BUSY_USEC] of its own
## `_process` a frame, and three bodies of food.gd's own kind in it, one of them
## a retired slot.
class BusyWater extends Node:
	const BUSY_USEC := 300
	var held: Array = []

	func _init() -> void:
		for seeded: bool in [true, false, true, true]:
			var b := FoodField.Body.new()
			b.seeded = seeded
			held.append(b)

	func _process(_delta: float) -> void:
		var until := Time.get_ticks_usec() + BUSY_USEC
		while Time.get_ticks_usec() < until:
			pass

	func bodies() -> Array:
		return held


## **The drop, watched from inside**: food.gd's own field with a tally on every
## door a rule passes through -- what the spawner makes, how a body leaves, each
## swim, each run begun and each run given up, each count of the genes -- so a
## check reads what happened in every frame of a run and not only at its end.
## Each hook calls the field's own function; nothing about the drop changes.
class WatchedDrop extends "res://game/normal/food.gd":
	var made := 0
	var made_gape := 0.0
	var venom_drifters := 0
	var causes := {}
	var swims := 0
	var fast := 0
	var burst_without := 0
	var searches := 0
	var fast_search := 0
	var runs_begun := 0
	var blind_runs := 0
	var given_up := 0
	var fled := 0
	var counts := 0
	var lost_genes := 0
	var still_short := 0
	var _short_before: Array[StringName] = []
	## The slot the last body came in by: a sister, which nothing returns.
	var last_spawned := -1
	# --- Pack 2 (docs/design/lineage.md §11.3): every division judged as it
	# happens, every tick a body at forty did not divide on, every meal, every run
	# at a body in its grace and every peer the spawner made over the floor.
	var divisions := 0
	var born := 0
	## What was wrong, counted -- of a division, and of a daughter's body -- with
	## the first few said.
	var faults := 0
	var body_faults := 0
	var said: Array[String] = []
	var kinds := {}
	var held_at_rim := 0
	var at_forty := 0
	var missed := 0
	## Expression, by copies: loci rolled and loci worn, one to three copies (the
	## mouth, always worn, and the senses, which a gift may stand in for, apart).
	var rolled := PackedInt32Array([0, 0, 0, 0])
	var worn := PackedInt32Array([0, 0, 0, 0])
	var meals_judged := 0
	var meal_faults := 0
	var graced_runs := 0
	var runs_at_born := 0
	var graced_eaten := 0
	var peers_over_floor := 0
	var made_kinds := {}
	# --- Pack 3 (docs/design/behaviour.md §12.3): every step of a body on rules
	# against what its own organs can give it, and -- while [member log_reads] is
	# on -- every input read, as `[slot, input]`.
	var moves := 0
	var fast_moves := 0
	var bursts := 0
	var log_reads := false
	var reads: Array = []
	# --- Pack 3's second phase (behaviour.md §6, §12.3 check 5): every division's
	# rules, as `[her mother's lines, whether the daughter whose DNA is hers carries
	# her list itself, the other daughter's lines, whether the other carries it
	# itself]` -- the lines of the founders' rules for a body on them -- and every
	# body a door let in carrying anything but the founders' rules.
	var rule_divisions: Array = []
	var doors := 0
	var off_founders := 0

	func _fault(what: String, of_body := false) -> void:
		if of_body:
			body_faults += 1
		else:
			faults += 1
		if said.size() < 4:
			said.append(what)

	## A body at forty, stepped on its tick, divides on it -- or has died of
	## hunger first, in its tank. Either way it is not the body it was.
	func _step_one(i: int, b: Body, tick: int) -> void:
		var due := births and b.seeded and not b.inert and not b.drifter \
			and b.radius >= CellBody.DIVIDE_RADIUS - 0.01 and (i % Drop.LOD_EVERY) == tick
		var serial := b.serial
		super._step_one(i, b, tick)
		if due:
			at_forty += 1
			if b.serial == serial:
				missed += 1

	## **Every division, judged** (checks 1 and 2): its mother at forty; two
	## daughters at half her area, touching across her heading where she was and
	## facing her way, fed, in their grace, new ids, her children; one carrying
	## her DNA and one a single trade or drift of it, a sense given apart; each
	## wearing a roll of what she carries, the mouth always, and a sense.
	func _divide(i: int, b: Body) -> PackedInt32Array:
		var mother := Descent.of(b.id, b.parent, b.generation, b.lineage)
		var dna := b.dna.duplicate()
		var radius := b.radius
		var at := b.pos
		var heading := b.heading
		var list: Variant = b.brain
		var slots: PackedInt32Array = super._divide(i, b)
		divisions += 1
		if radius < CellBody.DIVIDE_RADIUS - 0.01:
			_fault("divided at r%.2f" % radius)
		if slots.size() != 2:
			_fault("%d daughters" % slots.size())
			return slots
		var r := CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)
		var pair: Array[Body] = [_cells[slots[0]], _cells[slots[1]]]
		for k in 2:
			var d := pair[k]
			born += 1
			if not d.seeded or d.inert or d.drifter or absf(d.radius - r) > 1e-4 \
					or d.hunger != 0.0 or d.grace != newborn_grace or d.heading != heading \
					or d.parent != mother[Descent.ID] or d.lineage != mother[Descent.LINEAGE] \
					or d.generation != mother[Descent.GENERATION] + 1 \
					or d.id <= mother[Descent.ID] or d.id == pair[1 - k].id:
				_fault("daughter %d of %d: r%.2f hunger %.2f grace %.1f record %s" % [k,
					mother[Descent.ID], d.radius, d.hunger, d.grace,
					str([d.id, d.parent, d.generation, d.lineage])])
		# Side by side, touching, across her heading -- unless the rim held one in.
		# To a hundredth: a place is kept in 32 bits, a few ten-thousandths out here.
		var apart := pair[0].pos - pair[1].pos
		var along := absf(apart.dot(Vector2(sin(heading), -cos(heading))))
		var mid := (pair[0].pos + pair[1].pos) * 0.5
		if absf(apart.length() - 2.0 * r) < 1e-2 and along < 1e-2 and mid.distance_to(at) < 1e-2:
			pass
		elif _drop.meniscus.depth(at) < 2.0 * r:
			held_at_rim += 1
		else:
			_fault("daughters %.3f apart, %.3f along her heading, %.3f off her centre"
				% [apart.length(), along, mid.distance_to(at)])
		# One faithful, one changed by a single trade or drift -- a coin says which
		# -- read with and without the sense each may have been given.
		var kind := &""
		var gifts: Array = [[], []]
		var kept := -1
		for f in 2:
			for gf: Array in _given(pair[f]):
				for gc: Array in _given(pair[1 - f]):
					var faithful := _without(pair[f].dna, gf)
					if kind == &"" and faithful == dna and faithful.keys() == dna.keys():
						kind = _one_change(dna, _without(pair[1 - f].dna, gc))
						if kind != &"":
							gifts[f] = gf
							gifts[1 - f] = gc
							kept = f
		if kind == &"":
			_fault("of %s, daughters carry %s and %s" % [str(dna), str(pair[0].dna),
				str(pair[1].dna)])
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		for k in 2:
			_judge_body(pair[k], gifts[k])
		# Her rules (check 5), by which daughter carries her DNA: judged after.
		if kept >= 0:
			rule_divisions.append([_lines_of(list), pair[kept].brain == list,
				_lines_of(pair[1 - kept].brain), pair[1 - kept].brain == list])
		return slots

	## The lines of [param list], the founders' for null.
	func _lines_of(list: Variant) -> PackedStringArray:
		return Rulebook.lines_of(list if list != null else founders())

	## The ways to read what a daughter was given (`Drop.give_sense`): nothing,
	## and -- when she wears one sense alone, at tier 1, and carries it at one
	## copy -- that sense, written to her DNA. A sense her mother carried may be
	## given back to the daughter a drift took it from, and one she carries from
	## her mother or a drift reads the same as one given, so every reading is
	## tried ([method _divide]).
	func _given(d: Body) -> Array:
		var senses: Array[StringName] = []
		for gene: StringName in SENSE_GENES:
			if Genome.tier_of(d.genome, gene) > 0:
				senses.append(gene)
		if senses.size() != 1 or int(d.genome[senses[0]]) != 1 \
				or int(d.dna.get(senses[0], 0)) != 1:
			return [[]]
		return [[], [senses[0]]]

	static func _without(dna: Dictionary, genes: Array) -> Dictionary:
		var out := dna.duplicate()
		for gene: StringName in genes:
			out.erase(gene)
		return out

	## `trade` or `drift` when [param changed] is [param dna] with exactly one of
	## those done to it, and nothing else; empty otherwise. A shift has nothing to
	## move in a body with no layout, so it is never one.
	static func _one_change(dna: Dictionary, changed: Dictionary) -> StringName:
		if changed.size() == dna.size() and changed.keys().all(func(g: StringName) -> bool:
				return dna.has(g)):
			var up := 0
			var down := 0
			for gene: StringName in dna:
				var by := int(changed[gene]) - int(dna[gene])
				if by == 1:
					up += 1
				elif by == -1:
					down += 1
				elif by != 0:
					return &""
			return &"trade" if up == 1 and down == 1 and changed.keys() == dna.keys() else &""
		if changed.size() != dna.size():
			return &""
		var gone: Array[StringName] = []
		var came: Array[StringName] = []
		for gene: StringName in dna:
			if not changed.has(gene):
				gone.append(gene)
			elif int(changed[gene]) != int(dna[gene]):
				return &""
		for gene: StringName in changed:
			if not dna.has(gene):
				came.append(gene)
		if gone.size() == 1 and came.size() == 1 and gone[0] != &"cytostome" \
				and int(changed[came[0]]) == int(dna[gone[0]]):
			return &"drift"
		return &""

	## Her body is a roll of her DNA: every organ worn at the copies she carries
	## -- but a sense she was given, worn alone at tier 1 -- the mouth always, and
	## a sense. Every other locus counts toward how often each number of copies
	## is worn, the mouth and the senses apart.
	func _judge_body(d: Body, gift: Array) -> void:
		var senses: Array[StringName] = []
		for gene: StringName in d.genome:
			if SENSE_GENES.has(gene):
				senses.append(gene)
		for gene: StringName in d.genome:
			var given := gift.has(gene) or (senses.size() == 1 and senses[0] == gene
				and int(d.genome[gene]) == 1 and int(d.dna.get(gene, 0)) >= 1)
			if int(d.dna.get(gene, 0)) != int(d.genome[gene]) and not given:
				_fault("wears %s:%d, carries %d" % [gene, int(d.genome[gene]),
					int(d.dna.get(gene, 0))], true)
		if Genome.tier_of(d.genome, &"cytostome") < 1 \
				or Genome.tier_of(d.genome, &"cytostome") != Genome.tier_of(d.dna, &"cytostome"):
			_fault("a mouth of %d, carrying %d" % [Genome.tier_of(d.genome, &"cytostome"),
				Genome.tier_of(d.dna, &"cytostome")], true)
		if senses.is_empty():
			_fault("born blind: %s" % str(d.genome), true)
		for gene: StringName in d.dna:
			var copies := int(d.dna[gene])
			if gene == &"cytostome" or SENSE_GENES.has(gene) or copies < 1 or copies > 3:
				continue
			rolled[copies] += 1
			if d.genome.has(gene):
				worn[copies] += 1

	## **A meal writes the DNA and never the body** (check 6), by the rule a
	## lapsed sample follows -- a copy more, or a free slot at the new radius.
	func _grow(b: Body, gene: StringName) -> void:
		var body := var_to_bytes(b.genome)
		var expect := b.dna.duplicate()
		super._grow(b, gene)
		if not births:
			return
		Genome.integrate_into(expect, gene, CellBody.slots_for(b.radius))
		meals_judged += 1
		if var_to_bytes(b.genome) != body or var_to_bytes(b.dna) != var_to_bytes(expect):
			meal_faults += 1

	## **What the spawner makes, since bodies divide** (check 4): a peer only
	## under the floor or for venom.
	func _make_one(players: PackedVector2Array, reaches: PackedFloat32Array) -> int:
		var hunters := float(_living - _drifters)
		var over := hunters >= Drop.hunter_floor(_made_share(), floor_share)
		var venom := _venom_short()
		var index: int = super._make_one(players, reaches)
		if births and index >= 0:
			var kind := "drifter" if _cells[index].drifter else "peer"
			made_kinds[kind] = int(made_kinds.get(kind, 0)) + 1
			if kind == "peer" and over and not venom:
				peers_over_floor += 1
		elif births and index == NOTHING_SHORT:
			made_kinds["nothing"] = int(made_kinds.get("nothing", 0)) + 1
		return index

	func _spawn(at: Vector2, drifter: bool, sensed: float, fill := false,
			body_radius := 0.0, tiers := {}, mine := -1.0) -> int:
		var index: int = super._spawn(at, drifter, sensed, fill, body_radius, tiers, mine)
		last_spawned = index
		var b: Body = _cells[index]
		# **Every body comes in on the founders' rules** (check 5): a daughter is
		# handed hers by `_divide` after.
		doors += 1
		if b.brain != null:
			off_founders += 1
		if body_radius <= 0.0:
			made += 1
			if b.drifter:
				venom_drifters += 1 if b.genome.has(&"veneneux") else 0
			else:
				made_gape = maxf(made_gape, _gape(b))
		return index

	func _drop_lose(index: int, cause: int) -> void:
		var b: Body = _cells[index]
		if b.seeded and not b.inert:
			causes[cause] = int(causes.get(cause, 0)) + 1
			# The grace is not armour (§3.4): a mouth a newborn touches eats her.
			if b.grace > 0.0 and (cause == Cause.SWALLOWED or cause == Cause.CHEWED):
				graced_eaten += 1
		super._drop_lose(index, cause)

	func _swim(b: Body, delta: float, speed: float) -> void:
		swims += 1
		if speed > b.cruise + b.dash_v + 1e-3:
			fast += 1
		if b.dash_v > 0.0 and Genome.tier_of(b.genome, &"myoneme") <= 0:
			burst_without += 1
		super._swim(b, delta, speed)

	## **No body on rules faster than its organs** (check 11): its tail or the
	## water's drift, its axoneme at full strength and what is left of a dash, by
	## the tables -- and no burst without a `myoneme`.
	func _move_ruled(b: Body, delta: float) -> void:
		var g := b.genome
		var most := maxf(CellBody.speed_for(Genome.tier_of(g, &"flagellum")), DRIFT_SPEED) \
			+ CellBody.PUSH_ACCEL_BY_TIER[clampi(Genome.tier_of(g, &"axoneme"), 0, 3)] \
			/ CellBody.DRAG + b.dash_v
		var burst := b.dash_v > 0.0 and Genome.tier_of(g, &"myoneme") <= 0
		super._move_ruled(b, delta)
		moves += 1
		if b.speed > most + 1e-3:
			fast_moves += 1
		if burst:
			bursts += 1

	func _read_input(input: StringName) -> Array:
		if log_reads:
			reads.append([_reading_slot, input])
		return super._read_input(input)

	func _drift_in_drop(index: int, b: Body, delta: float) -> void:
		super._drift_in_drop(index, b, delta)
		if b.speed > DRIFT_SPEED + 1e-3:
			searches += 1
			if b.speed > b.cruise + 1e-3:
				fast_search += 1

	## A run begins: at something its own senses find, by the tables and not by
	## the field's own function -- the whole reach of its nose, radar, beam and
	## palp, a floc by nose, beam or palp alone, its eyespot's for a body big
	## enough to cast a shadow, and touch.
	func _start_run(b: Body, target: int, serial: int) -> void:
		runs_begun += 1
		var at: Vector2 = _cell.position if target == TARGET_PLAYER else _cells[target].pos
		var size: float = _cell.radius if target == TARGET_PLAYER else _cells[target].radius
		var floc: bool = target != TARGET_PLAYER and _cells[target].inert
		var g := b.genome
		var smell: float = CellBody.SMELL_RANGE_BY_TIER[Genome.tier_of(g, &"chemocyte")]
		var ping: float = CellBody.PING_RANGE_BY_TIER[Genome.tier_of(g, &"ampulla")]
		var beam: float = CellBody.BEAM_RANGE_BY_TIER[Genome.tier_of(g, &"ocellus")]
		var touch: float = CellBody.TOUCH_RANGE_BY_TIER[Genome.tier_of(g, &"palp")]
		var eye := SHADOW_RANGE if Genome.tier_of(g, &"stigma") > 0 else 0.0
		var d := b.pos.distance_to(at)
		var found := d <= b.radius + size
		if floc:
			found = found or d <= maxf(smell, maxf(beam, touch))
		else:
			found = found or d <= maxf(maxf(smell, ping), maxf(beam, touch)) \
				or (d <= eye and size >= SHADOW_MIN_RATIO * b.radius)
		if not found:
			blind_runs += 1
		# **No run begins at a body in its grace** (check 5): the player's, or a
		# newborn's in the water.
		if (target == TARGET_PLAYER and _first_hunt > 0.0) \
				or (target >= 0 and _cells[target].grace > 0.0):
			graced_runs += 1
		elif target >= 0 and _cells[target].generation > 1:
			runs_at_born += 1
		super._start_run(b, target, serial)

	func _break_off(b: Body) -> void:
		super._break_off(b)
		given_up += 1
		if b.state == State.BREAK or b.calm != REST_MISS:
			fled += 1

	func _count_genes() -> void:
		super._count_genes()
		counts += 1
		var carriers := {}
		for b in _cells:
			if b.seeded and not b.inert:
				for gene: StringName in b.genome:
					carriers[gene] = int(carriers.get(gene, 0)) + 1
		for gene: StringName in DRIFTER_GENES:
			var n := int(carriers.get(gene, 0))
			if n == 0:
				lost_genes += 1
			if n < Drop.GENE_FLOOR and _short_before.has(gene):
				still_short += 1
		_short_before = _gene_short.duplicate()


func _ready() -> void:
	seed(20260930)
	_grid()
	_basin()
	_replenish()
	_snowfall()
	_drop()
	_lod()
	_tank()
	_spawns()
	_containment()
	_five_minutes()
	_lineage()
	_division_rules()
	_determinism()
	_identity()
	_membrane()
	_shared_senses()
	_no_magic()
	_coming_for_you()
	_changes()
	_modular()
	_flocs()
	await _flocs_fed()
	_one_body()
	await _replay()
	await _readout()
	await _readout_families()
	await _save()
	await _drops()
	await _sister_lineage()
	print("[drop-probe] ALL PASS" if _failed == 0
		else "[drop-probe] FAILED %d" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("[drop-probe] %s %s" % ["PASS" if ok else "FAIL", what])


# --- 1. The grid never misses ---------------------------------------------------

func _grid() -> void:
	var half := Drop.RADIUS + Drop.GRID_CELL
	var grid := SpaceGrid.new(OFF_CENTRE, half, Drop.GRID_CELL)
	# Ids three apart, so the grid grows past its first room; about one body in
	# ten filed off the square, where the edge buckets have to stand for it.
	var count := 700
	var span := 3 * count
	var at := PackedVector2Array()
	at.resize(span)
	var filed := PackedByteArray()
	filed.resize(span)
	for k in count:
		var id := 3 * k
		at[id] = _anywhere(OFF_CENTRE, half * 1.15)
		filed[id] = 1
		grid.insert(id, at[id])
	var seen := PackedInt32Array()
	seen.resize(span)
	var out := PackedInt32Array()
	var truths := 0
	var missed := 0
	var twice := 0
	var ghosts := 0
	var answered := 0
	var queries := 10000
	var broke := -1
	var touched := PackedInt32Array()
	for q in queries:
		# The water moves between two questions: most bodies a frame's travel,
		# some a leap across the drop, a few out of it and back in.
		touched.resize(0)
		for m in 3:
			var id := 3 * (randi() % count)
			touched.append(grid.bucket_of(at[id]))
			if filed[id] == 0:
				grid.insert(id, at[id])
				filed[id] = 1
				continue
			var roll := randf()
			if roll < 0.04:
				grid.remove(id)
				filed[id] = 0
				continue
			var leap := randf_range(0.0, 15.0) if roll < 0.8 else randf_range(0.0, 3000.0)
			at[id] += Vector2.from_angle(randf() * TAU) * leap
			grid.move(id, at[id])
			touched.append(grid.bucket_of(at[id]))
		# A list that came apart would send the query round it for ever: stop
		# here and say so instead.
		if not _lists_sound(grid, touched, count):
			broke = q
			break
		var here := _anywhere(OFF_CENTRE, half * 1.2)
		# Every reach a pass asks: separation's few tens, a prey search's two
		# thousand and the players' scan list past it.
		var reach := randf_range(0.0, 60.0) if q % 4 == 0 else randf_range(0.0, 2400.0)
		out.resize(0)
		grid.query(here, reach, out)
		answered += out.size()
		var stamp := q + 1
		for id: int in out:
			if seen[id] == stamp:
				twice += 1
			seen[id] = stamp
			if filed[id] == 0:
				ghosts += 1
		for k in count:
			var id := 3 * k
			if filed[id] == 1 and at[id].distance_squared_to(here) <= reach * reach:
				truths += 1
				if seen[id] != stamp:
					missed += 1
	var every := PackedInt32Array()
	for c in grid.columns * grid.rows:
		every.append(c)
	var sound := broke < 0 and _lists_sound(grid, every, count)
	var asked := queries if broke < 0 else broke
	_check(("the grid never misses: %d queries against brute force%s, %d bodies within"
		+ " reach, %d missed; nothing twice (%d) and nothing taken out (%d); %.1f"
		+ " answered for each one in reach; every body in the one bucket it is filed in:"
		+ " %s") % [asked, "" if broke < 0 else " before its lists came apart", truths,
		missed, twice, ghosts, float(answered) / maxf(float(truths), 1.0),
		"yes" if sound else "no"],
		missed == 0 and twice == 0 and ghosts == 0 and truths > 5 * queries and sound)
	_grid_lines()


## **Whether the lists of [param buckets] hold together**: every id in one is
## filed in that bucket, and no list runs on past [param most] ids -- which a
## list that has come round on itself would. Reaches into the grid's own
## arrays, as only tools/ may.
func _lists_sound(grid: SpaceGrid, buckets: PackedInt32Array, most: int) -> bool:
	var head: PackedInt32Array = grid.get(&"_head")
	var next: PackedInt32Array = grid.get(&"_next")
	var where: PackedInt32Array = grid.get(&"_where")
	for c: int in buckets:
		var i := head[c]
		var steps := 0
		while i >= 0:
			steps += 1
			if steps > most or i >= where.size() or where[i] != c:
				return false
			i = next[i]
	return true


## **At a bucket line, a caller whose 32-bit distance rounds the other way.**
## A body a hair to one side of a line, asked for from exactly its rounded
## distance on the other: the caller keeps it, so the grid has to hand it back.
func _grid_lines() -> void:
	var grid := SpaceGrid.new(Vector2.ZERO, 8000.0, 400.0)
	var line := 1200.0
	var reach := 4096.0
	var below := PackedFloat32Array([line - 1e-4])[0]
	var beyond := PackedFloat32Array([line - reach - 2.44140625e-4])[0]
	# [body, asked from]: from the right of a body just below a line, from the
	# left of one on it, and the same down the page.
	var cases := [
		[Vector2(below, 37.0), Vector2(line + reach, 37.0)],
		[Vector2(line, 37.0), Vector2(beyond, 37.0)],
		[Vector2(37.0, below), Vector2(37.0, line + reach)],
		[Vector2(37.0, line), Vector2(37.0, beyond)],
	]
	var kept := 0
	var missed := 0
	var out := PackedInt32Array()
	for i in cases.size():
		var body: Vector2 = cases[i][0]
		var from: Vector2 = cases[i][1]
		grid.insert(i, body)
		if body.distance_squared_to(from) > reach * reach:
			continue
		kept += 1
		out.resize(0)
		grid.query(from, reach, out)
		if not out.has(i):
			missed += 1
		grid.remove(i)
	_check("and at a bucket line: %d bodies a caller's 32-bit test keeps across one," % kept
		+ " %d missed" % missed, kept == cases.size() and missed == 0)


# --- 2. The basin ------------------------------------------------------------------

func _basin() -> void:
	var basin := Basin.new(OFF_CENTRE, Drop.RADIUS)
	var trials := 1500
	var worst_contain := 0.0
	var worst_depth := 0.0
	var worst_rim := 0.0
	var worst_exit := 0.0
	var outside := 0
	var wrong_inside := 0
	var contained := 0
	var escaped := 0
	for t in trials:
		var p := _anywhere(OFF_CENTRE, Drop.RADIUS * 1.5)
		var r := randf_range(0.0, 60.0) if t % 50 != 0 \
			else randf_range(Drop.RADIUS, 1.5 * Drop.RADIUS)
		var d := _dist(p, OFF_CENTRE)
		var limit := maxf(Drop.RADIUS - r, 0.0)
		# contain: the nearest point of the disc a body of this radius may be in.
		var want := p if d <= limit else _on_circle(OFF_CENTRE, limit,
			_nearest_angle(OFF_CENTRE, limit, p))
		var got := basin.contain(p, r)
		worst_contain = maxf(worst_contain, _dist(got, want))
		if d > limit:
			outside += 1
		contained += 1
		if not basin.inside(got, r):
			escaped += 1
		# inside, against the distance itself.
		if basin.inside(p, r) != (d <= limit):
			wrong_inside += 1
		# depth and the nearest point of the rim, against the rim sampled. The
		# distance stays in 64 bits; only the point is stored in 32.
		var angle := _nearest_angle(OFF_CENTRE, Drop.RADIUS, p)
		var from_rim := _dist_to(OFF_CENTRE.x + Drop.RADIUS * cos(angle),
			OFF_CENTRE.y + Drop.RADIUS * sin(angle), p) * (1.0 if d <= Drop.RADIUS else -1.0)
		worst_depth = maxf(worst_depth, absf(basin.depth(p) - from_rim))
		worst_rim = maxf(worst_rim, _dist(basin.nearest_rim(p),
			_on_circle(OFF_CENTRE, Drop.RADIUS, angle)))
		# exit_along, against a ray walked out and bisected.
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(0.1, 50.0)
		worst_exit = maxf(worst_exit, absf(basin.exit_along(p, dir) - _walk_out(OFF_CENTRE,
			Drop.RADIUS, p, dir)))
	_check(("the basin against brute force over %d points (%d past the rim): contain"
		+ " within %.4f, depth %.6f, nearest_rim %.4f, exit_along %.4f; inside wrong %d")
		% [trials, outside, worst_contain, worst_depth, worst_rim, worst_exit, wrong_inside],
		worst_contain < 0.01 and worst_depth < 1e-6 and worst_rim < 0.01
		and worst_exit < 1e-3 and wrong_inside == 0 and outside > 300)
	_check("a contained point is inside: %d of %d, rounded to 32 bits" % [
		contained - escaped, contained], escaped == 0)
	# The rim itself: at the centre, and along a ray from the rim outward.
	var from_middle := basin.nearest_rim(OFF_CENTRE)
	var at_rim := basin.nearest_rim(OFF_CENTRE + Vector2(3.0, 4.0))
	_check("the centre's nearest rim is on the rim (%.4f off), and a ray leaving from"
		% absf(_dist(from_middle, OFF_CENTRE) - Drop.RADIUS)
		+ " the rim outward travels %.4f" % basin.exit_along(at_rim, at_rim - OFF_CENTRE),
		absf(_dist(from_middle, OFF_CENTRE) - Drop.RADIUS) < 0.01
		and basin.exit_along(at_rim, at_rim - OFF_CENTRE) < 0.01)


## The angle of the point of the circle of [param radius] round [param c]
## nearest [param p], found the slow way: the circle sampled, then the best
## sample's neighbourhood narrowed down. Nothing here shares the basin's
## arithmetic.
func _nearest_angle(c: Vector2, radius: float, p: Vector2) -> float:
	var samples := 720
	var best := 0.0
	var best_d := INF
	for k in samples:
		var a := TAU * float(k) / float(samples)
		var d := _dist_to(c.x + radius * cos(a), c.y + radius * sin(a), p)
		if d < best_d:
			best_d = d
			best = a
	var low := best - TAU / float(samples)
	var high := best + TAU / float(samples)
	for i in 80:
		var a := lerpf(low, high, 1.0 / 3.0)
		var b := lerpf(low, high, 2.0 / 3.0)
		if _dist_to(c.x + radius * cos(a), c.y + radius * sin(a), p) \
				<= _dist_to(c.x + radius * cos(b), c.y + radius * sin(b), p):
			high = b
		else:
			low = a
	return (low + high) * 0.5


func _on_circle(c: Vector2, radius: float, angle: float) -> Vector2:
	return Vector2(c.x + radius * cos(angle), c.y + radius * sin(angle))


## How far a ray from [param origin] along [param dir] runs before it leaves the
## disc, walked: out in steps, then bisected to the crossing. 0 when the walk
## never finds the disc ahead of it.
func _walk_out(c: Vector2, radius: float, origin: Vector2, dir: Vector2) -> float:
	var length := sqrt(dir.x * dir.x + dir.y * dir.y)
	var ux := dir.x / length
	var uy := dir.y / length
	var reach := _dist(origin, c) + radius + 10.0
	var step := 4.0
	var last_in := -1.0
	var t := 0.0
	while t <= reach:
		if _dist_to(origin.x + ux * t, origin.y + uy * t, c) <= radius:
			last_in = t
		t += step
	if last_in < 0.0:
		return 0.0
	var low := last_in
	var high := last_in + step
	for i in 60:
		var mid := (low + high) * 0.5
		if _dist_to(origin.x + ux * mid, origin.y + uy * mid, c) <= radius:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


# --- The replenisher, in isolation ------------------------------------------------

func _replenish() -> void:
	var target := Drop.target()
	var spawner := Replenish.new(target, Drop.SPAWN_TAU, Drop.SPAWN_BURST)
	# One tick: a shortfall of 20 over half a second is two bodies; one of 7 is
	# 0.7 of a body, owed and not made; a drop that is full again owes nothing.
	var one := spawner.due(target - 20, Drop.SPAWN_TICK)
	var partial := spawner.due(target - 7, Drop.SPAWN_TICK)
	var owed := spawner.debt
	var full := spawner.due(target, Drop.SPAWN_TICK)
	var over := spawner.due(target + 30, Drop.SPAWN_TICK)
	_check("a shortfall of 20 pays back 2 a half second (%d); one of 7 makes %d and owes"
		% [one, partial] + " %.2f; a full drop and an over-full one make nothing (%d, %d)"
		% [owed, full, over] + " and owe nothing (%.2f)" % spawner.debt,
		one == 2 and partial == 0 and is_equal_approx(owed, 0.7) and full == 0
		and over == 0 and spawner.debt == 0.0)
	# The burst, and a debt that cannot outgrow what is missing.
	spawner.reset()
	var most := 0
	var living := 0
	for tick in 60:
		var made := spawner.due(living, Drop.SPAWN_TICK)
		most = maxi(most, made)
		living += made
	var stuck := Replenish.new(target, Drop.SPAWN_TAU, 0)
	for tick in 200:
		stuck.due(target - 12, Drop.SPAWN_TICK)
	stuck.refund(3)
	_check(("from empty, never more than %d a tick (%d); nowhere to put anything, the"
		+ " debt stops at the 12 missing (%.2f) and a refund is owed again (%.2f)") % [
		Drop.SPAWN_BURST, most, stuck.debt - 3.0, stuck.debt],
		most == Drop.SPAWN_BURST and is_equal_approx(stuck.debt, 15.0))
	# Refilling: a shortfall of 40 with nothing dying comes back along
	# 1 - (1 - tick / tau)^n, the half-second ticks of 1 - exp(-t / tau).
	spawner.reset()
	living = target - 40
	for tick in 10:
		living += spawner.due(living, Drop.SPAWN_TICK)
	var back := float(living - (target - 40))
	var curve := 40.0 * (1.0 - pow(1.0 - Drop.SPAWN_TICK / Drop.SPAWN_TAU, 10.0))
	_check("40 short and nothing dying, %d are back after one tau of %.0f s (%.1f by the curve)"
		% [roundi(back), Drop.SPAWN_TAU, curve], absf(back - curve) <= 1.0)
	# §6.2: a drop losing k bodies a second settles about k * tau short -- 95 %
	# of its target at a newborn's composition, 91 % at a sighted player's.
	var held := PackedFloat32Array()
	for per_minute: float in [355.0, 635.0]:
		spawner.reset()
		living = target
		var dying := 0.0
		var sum := 0.0
		var ticks := 0
		for tick in 2400:
			dying += per_minute / 60.0 * Drop.SPAWN_TICK
			var died := floori(dying)
			dying -= float(died)
			living -= died
			living += spawner.due(living, Drop.SPAWN_TICK)
			if tick >= 800:
				sum += float(living)
				ticks += 1
		held.append(sum / float(ticks) / float(target))
	_check("losing 355 and 635 a minute, the drop holds %.1f %% and %.1f %% of its %d"
		% [held[0] * 100.0, held[1] * 100.0, target] + " -- §6.2's 95 and 91",
		roundi(held[0] * 100.0) == 95 and roundi(held[1] * 100.0) == 91)
	# The thinnest candidate, against brute force: fewest wins, the first of a tie.
	var wrong := 0
	for trial in 500:
		var candidates := PackedVector2Array()
		var counts := {}
		for k in randi() % 13:
			var p := Vector2(float(trial), float(k))
			candidates.append(p)
			counts[p] = randi() % 6
		var want := -1
		for k in candidates.size():
			if want < 0 or int(counts[candidates[k]]) < int(counts[candidates[want]]):
				want = k
		if Replenish.thinnest(candidates, func(p: Vector2) -> int: return counts[p]) != want:
			wrong += 1
	_check("the thinnest of up to 12 candidates, 500 times against brute force: %d wrong"
		% wrong, wrong == 0)
	# Hidden from every observer, against brute force, and at the reach itself.
	wrong = 0
	for trial in 3000:
		var observers := PackedVector2Array()
		var reaches := PackedFloat32Array()
		for k in randi() % 4:
			observers.append(_anywhere(Vector2.ZERO, 3000.0))
			reaches.append(randf_range(0.0, 2000.0))
		var p := _anywhere(Vector2.ZERO, 3000.0)
		var want := true
		for k in observers.size():
			if _dist(p, observers[k]) < reaches[k]:
				want = false
		if Replenish.hidden(p, observers, reaches) != want:
			wrong += 1
	var edge := Replenish.hidden(Vector2(1000.0, 0.0), PackedVector2Array([Vector2.ZERO]),
		PackedFloat32Array([1000.0]))
	var within := Replenish.hidden(Vector2(999.9, 0.0), PackedVector2Array([Vector2.ZERO]),
		PackedFloat32Array([1000.0]))
	_check("hidden from up to 3 observers, 3000 times against brute force: %d wrong;" % wrong
		+ " at the reach hidden (%s), a tenth inside it not (%s)" % [edge, within],
		wrong == 0 and edge and not within
		and Replenish.hidden(Vector2.ZERO, PackedVector2Array(), PackedFloat32Array()))


# --- The snowfall, in isolation --------------------------------------------------

func _snowfall() -> void:
	var snow := Snowfall.new(Drop.SNOW * 1e-6, Drop.SNOW_SHARE)
	var area := PI * Drop.RADIUS * Drop.RADIUS
	var mean := snow.rate * area * Drop.SPAWN_TICK
	var draws := 20000
	var sum := 0.0
	var squares := 0.0
	for i in draws:
		var n := float(snow.falls(area, Drop.SPAWN_TICK))
		sum += n
		squares += n * n
	var got := sum / float(draws)
	var spread := squares / float(draws) - got * got
	_check(("the drop's snow: %.2f flakes a second over the drop, %.3f a half second by"
		+ " %d draws against %.3f, variance %.3f -- a Poisson draw's own") % [
		snow.rate * area, got, draws, mean, spread],
		absf(snow.rate * area - 8.14) < 0.01 and absf(got - mean) < 0.015 * mean
		and absf(spread - mean) < 0.05 * mean)
	# A large mean is not cut short: the prototype's draw stopped at 64.
	sum = 0.0
	for i in 5000:
		sum += float(Snowfall.poisson(100.0))
	_check("a mean of 100 draws %.2f on average -- nothing cut short" % (sum / 5000.0),
		absf(sum / 5000.0 - 100.0) < 1.0 and Snowfall.poisson(0.0) == 0)
	# The keep chance: all of it where nothing is, none at half the share.
	var expected := Drop.snow_expected()
	var chances := PackedFloat32Array([snow.keep_chance(0.0, expected),
		snow.keep_chance(expected * Drop.SNOW_SHARE * 0.5, expected),
		snow.keep_chance(expected * Drop.SNOW_SHARE, expected),
		snow.keep_chance(3.0 * expected, expected), snow.keep_chance(0.0, 0.0),
		snow.keep_chance(1.0, 0.0)])
	_check("a flake is kept %.2f where nothing is, %.2f at a quarter, %.2f at half the"
		% [chances[0], chances[1], chances[2]] + " drop's %.1f cells, %.2f above; with no mean"
		% [expected, chances[3]] + " %.0f and %.0f" % [chances[4], chances[5]],
		absf(expected - 9.85) < 0.01 and chances[0] == 1.0 and is_equal_approx(chances[1], 0.5)
		and chances[2] == 0.0 and chances[3] == 0.0 and chances[4] == 1.0 and chances[5] == 0.0)
	var kept := 0
	var count := 0.7 * expected * Drop.SNOW_SHARE
	for i in draws:
		if snow.keeps(count, expected):
			kept += 1
	_check("where the chance is 0.30, %d of %d flakes stay" % [kept, draws],
		absf(float(kept) / float(draws) - 0.3) < 0.015)


# --- The drop's own decisions ------------------------------------------------------

func _drop() -> void:
	var drop := Drop.new(OFF_CENTRE)
	_check("the drop holds %d bodies at %.1f per million square micrometres, Ø %.0f mm"
		% [Drop.target(), Drop.DENSITY * 1e6, 2.0 * Drop.RADIUS / 1000.0],
		Drop.target() == 554 and drop.spawner.target == 554
		and drop.meniscus.center == OFF_CENTRE and drop.meniscus.radius == Drop.RADIUS)
	# The hide reach (§6.3), for a born cell with each free sense.
	var reaches := PackedFloat32Array()
	for sense: StringName in FoodField.SENSE_GENES:
		var tiers := {sense: 1}
		var senses := maxf(maxf(CellBody.SMELL_RANGE_BY_TIER[GenomeNode.tier_of(tiers,
			&"chemocyte")], CellBody.PING_RANGE_BY_TIER[GenomeNode.tier_of(tiers,
			&"ampulla")]), CellBody.BEAM_RANGE_BY_TIER[GenomeNode.tier_of(tiers, &"ocellus")])
		reaches.append(Drop.hide_reach(senses, FoodField.DREAD_RANGE, false))
	var peer := Drop.hide_reach(CellBody.PING_RANGE_BY_TIER[1], FoodField.DREAD_RANGE, true)
	var low := reaches[0]
	var high := reaches[0]
	for reach in reaches:
		low = minf(low, reach)
		high = maxf(high, reach)
	_check("for a born cell a drifter is made %.0f to %.0f away, by its sense, and a peer"
		% [low, high] + " %.0f -- §6.3's 1,050 to 1,200 and 1,500" % peer,
		absf(low - 1049.0) < 0.5 and high == 1200.0 and peer == 1500.0)
	# What is short.
	var genes := FoodField.DRIFTER_GENES.duplicate()
	var counts := {}
	for gene: StringName in genes:
		counts[gene] = 5
	counts[&"palp"] = 1
	counts[Drop.VENOM] = 0
	counts[&"crista"] = 2
	var short := Drop.short_genes(counts, genes)
	var first := Drop.take_drifter_gene(short)
	var second := Drop.take_drifter_gene(short)
	_check(("the floor finds %s short of %d; a drifter takes palp (%s), never venom (%s),"
		+ " which is left for a peer (%s)") % [str(Drop.short_genes(counts, genes)),
		Drop.GENE_FLOOR, first, second, str(short)],
		first == &"palp" and second == &"" and short == [Drop.VENOM])
	var shares := [Drop.wants_drifter(100, 44, 0.45), Drop.wants_drifter(100, 45, 0.45),
		Drop.wants_drifter(0, 0, 0.92)]
	_check("a drifter is made while the living share is under the one wanted: %s" % str(shares),
		shares == [true, false, true])
	var turns := [Drop.next_turn(0, 1), Drop.next_turn(0, 2), Drop.next_turn(1, 2),
		Drop.next_turn(2, 3), Drop.next_turn(0, 0)]
	_check("new bodies are made for the players in turn: %s" % str(turns),
		turns == [0, 1, 0, 0, 0])
	# What a new body is made of (§5.8).
	var pool := Drop.drifter_genes(FoodField.DRIFTER_GENES)
	_check("a drifter draws its gene from %d of the %d, all but venom" % [pool.size(),
		FoodField.DRIFTER_GENES.size()], not pool.has(Drop.VENOM)
		and pool.size() == FoodField.DRIFTER_GENES.size() - 1)
	var plan := Drop.peer_plan()
	var blind := {&"cytostome": 2, &"cirrus": 1, &"flagellum": 3}
	var given := Drop.give_sense(blind, FoodField.SENSE_GENES, 7)
	var sighted := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"stigma": 2}
	var again := Drop.give_sense(sighted, FoodField.SENSE_GENES, 7)
	_check("a peer starts from a born cell's plan %s; a blind one is given %s at tier 1," % [
		str(plan), str(blind.keys().slice(3))] + " a sighted one nothing",
		plan == [&"cytostome", &"cirrus", &"flagellum"] and given and not again
		and blind.size() == 4 and int(blind[FoodField.SENSE_GENES[3]]) == 1
		and sighted.size() == 4)
	var full := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"ampulla": 1, &"crista": 2}
	Drop.give_venom(full, 5, FoodField.SENSE_GENES, 3)
	var bare := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"chemocyte": 1}
	Drop.give_venom(bare, 3, FoodField.SENSE_GENES, 3)
	_check("venom back through a full peer takes a spare slot, never the plan or a sense"
		+ " (%s); with none spare, a bonus one (%s)" % [str(full.keys()), str(bare.keys())],
		full.has(Drop.VENOM) and not full.has(&"crista") and full.has(&"ampulla")
		and full.size() == 5 and bare.size() == 5 and bare.has(Drop.VENOM))
	# Where a new body may go: out of every player's reach, and in the drop.
	var players := PackedVector2Array([OFF_CENTRE + Vector2(1500.0, -800.0),
		OFF_CENTRE + Vector2(-4500.0, 3000.0)])
	var hides := PackedFloat32Array([1500.0, 1200.0])
	var drawn := 0
	var ringed := 0
	var bad := 0
	for round in 400:
		var turn := round % 2
		for at: Vector2 in drop.spawn_candidates(players, hides, turn):
			drawn += 1
			if not drop.meniscus.inside(at, Drop.SPAWN_INSET) \
					or not Replenish.hidden(at, players, hides):
				bad += 1
			var d := _dist(at, players[turn])
			if d >= hides[turn] and d <= hides[turn] + Drop.SPAWN_RING:
				ringed += 1
	_check(("spawn candidates: %d drawn, %d of them in the ring past the player whose"
		+ " turn it is, %d inside a hide reach or past the rim") % [drawn, ringed, bad],
		bad == 0 and drawn > 3000 and float(ringed) > 0.35 * float(drawn))
	# Where a run starts, against the same points chosen by hand.
	var tried: Array = []
	var food_near := func(p: Vector2, reach: float) -> int:
		if reach == Drop.START_CLEAR:
			tried.append(p)
			return 1 if fmod(absf(p.x), 7.0) < 1.0 else 0
		return int(absf(p.y)) % 5
	var dread_at := func(p: Vector2) -> float:
		return 0.0 if fmod(absf(p.y), 3.0) < 1.5 else absf(p.x) / 6000.0
	var start := drop.quiet_start(food_near, dread_at)
	var want := drop.meniscus.center
	var least := INF
	var most := -1
	var deep := true
	var clear := 0
	for p: Vector2 in tried:
		deep = deep and drop.meniscus.inside(p, Drop.START_INSET)
		if fmod(absf(p.x), 7.0) < 1.0:
			continue
		clear += 1
		var dread: float = dread_at.call(p)
		var food := int(absf(p.y)) % 5
		if dread < least - 1e-6 or (absf(dread - least) <= 1e-6 and food > most):
			want = p
			least = dread
			most = food
	var tied := 0
	for p: Vector2 in tried:
		if fmod(absf(p.x), 7.0) >= 1.0 and absf(float(dread_at.call(p)) - least) <= 1e-6:
			tied += 1
	_check(("a run starts at the quietest of %d points: of the %d with no meal on top, the"
		+ " %d that dread nothing tie and the one with most food (%d) wins; none within"
		+ " %.0f of the rim") % [tried.size(), clear, tied, most, Drop.START_INSET],
		tried.size() == Drop.START_TRIES and start == want and deep and clear < tried.size()
		and tied >= 2)
	var pushed := drop.pushed_clear(OFF_CENTRE, OFF_CENTRE + Vector2(300.0, 400.0),
		FoodField.DREAD_RANGE, 30.0)
	_check("a mouth that could swallow a newborn is moved out to %.0f from its start"
		% _dist(pushed, OFF_CENTRE), absf(_dist(pushed, OFF_CENTRE)
		- FoodField.DREAD_RANGE - Drop.START_PUSH) < 0.01)
	# A start is drawn evenly over its disc: half of the draws within the radius
	# that holds half its area. And one 1,100 µm in from the rim, with the mouth
	# on the rim's side, pushes that mouth back inside, not out of the drop.
	var disc := Drop.RADIUS - Drop.START_INSET
	var within := 0
	var outside := 0
	for i in 20000:
		var d := _dist(drop.uniform_point(Drop.START_INSET), drop.meniscus.center)
		if d <= disc / sqrt(2.0):
			within += 1
		if d > disc + 1e-3:
			outside += 1
	var edge_start := drop.meniscus.center + Vector2(Drop.RADIUS - 1100.0, 0.0)
	var edge_push := drop.pushed_clear(edge_start, edge_start + Vector2(300.0, 0.0),
		FoodField.DREAD_RANGE, 30.0)
	_check(("a start is drawn evenly: %.3f of 20,000 within %.0f of the centre, which holds"
		+ " half the disc, and %d past it; a mouth on the rim's side of a start 1,100 in"
		+ " is pushed to %.1f inside the rim") % [float(within) / 20000.0,
		disc / sqrt(2.0), outside, drop.meniscus.depth(edge_push)],
		absf(float(within) / 20000.0 - 0.5) <= 0.01 and outside == 0
		and drop.meniscus.inside(edge_push, 30.0))
	# **The review's S3**: the rim holds a pushed mouth back, and it must still
	# end clear of dread's reach of the start. From a start as near the rim as
	# one may be, mouths all round it at every distance inside dread's reach, of
	# every size a body can be: each is slid along the rim until it clears.
	var nearest := INF
	var held := 0
	var escaped := 0
	var worst_start := drop.meniscus.center + Vector2(0.0, -(Drop.RADIUS - Drop.START_INSET))
	for k in 72:
		for reach: float in [60.0, 700.0, 1350.0]:
			for r: float in [13.0, 40.0]:
				var mouth := worst_start + Vector2.from_angle(TAU * float(k) / 72.0) * reach
				var put := drop.pushed_clear(worst_start, mouth, FoodField.DREAD_RANGE, r)
				nearest = minf(nearest, _dist(put, worst_start))
				if drop.meniscus.depth(put) < Drop.START_PUSH:
					held += 1
				if not drop.meniscus.inside(put, r):
					escaped += 1
	_check(("S3: from a start %.0f inside the rim, 432 mouths moved out land at least %.0f"
		+ " from it (dread reaches %.0f), %d of them slid along the rim, %d past it") % [
		Drop.START_INSET, nearest, FoodField.DREAD_RANGE, held, escaped],
		nearest >= FoodField.DREAD_RANGE and held > 0 and escaped == 0)
	# What a new thing is made with: a body made in play is fed, one of a first
	# fill up to FIRST_HUNGER_MAX; a fallen floc fits a born cell's mouth and lasts
	# FLOC_LIFE give or take its spread.
	var fed := [Drop.made_hunger(false), Drop.made_hunger(false)]
	var made := Vector2(INF, -INF)
	var flocs := Vector2(INF, -INF)
	var lives := Vector2(INF, -INF)
	for i in 2000:
		var h := Drop.made_hunger(true)
		made = Vector2(minf(made.x, h), maxf(made.y, h))
		var fr := Drop.floc_radius()
		flocs = Vector2(minf(flocs.x, fr), maxf(flocs.y, fr))
		var fl := Drop.floc_life()
		lives = Vector2(minf(lives.x, fl), maxf(lives.y, fl))
	var gape := CellBody.gape_of(1, CellBody.BASE_RADIUS)
	_check(("a body made in play starts fed (%s), one of a first fill at %.2f to %.2f; a"
		+ " floc is %.1f to %.1f µm, inside a born cell's gape of %.1f, and lasts %.0f to"
		+ " %.0f s") % [str(fed), made.x, made.y, flocs.x, flocs.y, gape, lives.x, lives.y],
		fed == [0.0, 0.0] and made.x >= 0.0 and made.y <= Drop.FIRST_HUNGER_MAX
		and made.y > 0.3 and flocs.x >= Drop.FLOC_MIN and flocs.y <= Drop.FLOC_MAX
		and Drop.FLOC_MAX < gape and lives.x >= 90.0 and lives.y <= 150.0
		and lives.x < 95.0 and lives.y > 145.0)
	# The shore, the remains, and the drop moving under a start.
	var turn_rates := PackedFloat32Array([Drop.shore_turn(0.0),
		Drop.shore_turn(Drop.SHALLOWS * 0.5), Drop.shore_turn(Drop.SHALLOWS),
		Drop.shore_turn(3000.0)])
	var remains := PackedFloat32Array([Drop.remains_radius(13.0), Drop.remains_radius(30.0),
		Drop.remains_radius(40.0)])
	drop.grid.insert(5, OFF_CENTRE)
	drop.shift(Vector2(100.0, -50.0))
	_check(("the shore turns a body %.2f, %.2f, %.2f and %.2f rad/s at the rim, half"
		+ " into the shallows, at their edge and beyond; remains of r13, r30, r40 are"
		+ " %.1f, %.1f, %.1f; a shifted drop moves its rim and forgets its grid") % [
		turn_rates[0], turn_rates[1], turn_rates[2], turn_rates[3], remains[0],
		remains[1], remains[2]],
		is_equal_approx(turn_rates[0], Drop.SHORE_TURN)
		and is_equal_approx(turn_rates[1], Drop.SHORE_TURN * 0.5)
		and turn_rates[2] == 0.0 and turn_rates[3] == 0.0
		and remains == PackedFloat32Array([8.0, 15.0, 18.0])
		and drop.meniscus.center == OFF_CENTRE + Vector2(100.0, -50.0)
		and not drop.grid.has(5))


# --- 7. The LOD reaches past the senses ----------------------------------------------

## **Nothing is stepped at a lower rate where it can be sensed** (§4.3), from
## the tables alone: `LOD_NEAR` past the farthest ping, the widest body and the
## grid's slack, and past every other reach; `LOD_FULL` past the view and the
## widest body; `LOD_EVERY` even. A sense that one day reaches further fails
## here instead of being slowed where it is felt.
func _lod() -> void:
	var widest := CellBody.DIVIDE_RADIUS
	var ping := 0.0
	for reach: float in CellBody.PING_RANGE_BY_TIER:
		ping = maxf(ping, reach)
	var beam := 0.0
	for level in range(1, 13):
		for path: StringName in [&"", &"extend", &"sweep"]:
			beam = maxf(beam, float(CellBody.beam_shape(level, path)[3]))
	var smell := 0.0
	for reach: float in CellBody.SMELL_RANGE_BY_TIER:
		smell = maxf(smell, reach)
	var touch := 0.0
	for reach: float in CellBody.TOUCH_RANGE_BY_TIER:
		touch = maxf(touch, reach)
	var others := {"scent": FoodField.SCENT_RANGE, "smell": smell,
		"dread": FoodField.DREAD_RANGE, "beam": beam, "touch": touch,
		"notice": FoodField.NOTICE_RANGE}
	var farthest := 0.0
	for key: String in others:
		farthest = maxf(farthest, float(others[key]))
	_check(("7. the LOD reaches past the senses: LOD_NEAR %.0f against a ping of %.0f, the"
		+ " widest body's %.0f and %.0f of slack, and the rest %s; LOD_FULL %.0f against"
		+ " the view's %.0f and that body; LOD_EVERY %d, even") % [Drop.LOD_NEAR, ping,
		widest, Drop.GRID_SLACK, str(others), Drop.LOD_FULL, Drop.VIEW_REACH,
		Drop.LOD_EVERY],
		Drop.LOD_NEAR >= ping + widest + Drop.GRID_SLACK
		and Drop.LOD_NEAR >= farthest + widest
		and Drop.LOD_FULL >= Drop.VIEW_REACH + widest and Drop.LOD_FULL < Drop.LOD_NEAR
		and Drop.LOD_EVERY % 2 == 0)


# --- 10. One tank ----------------------------------------------------------------------

## **A water body and the player's metabolism node, with the same genome, fed
## the same efforts over the same 60 s, end at the same hunger** -- the node a
## frame at a time as the run steps it, the water body in food.gd's own tank at
## the rates its distance would give it: every frame, then every second frame,
## then on its tick, with the time it is owed. The body's terms -- its upkeep,
## store, burn, and light and absorption -- are the field's own reading of its
## genome, so they are held to the node's too.
func _tank() -> void:
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var genomes := [
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1},
		{&"cytostome": 2, &"cirrus": 1, &"flagellum": 3, &"vacuole": 2, &"plastid": 3,
			&"crista": 2, &"ampulla": 1},
		# A player who put a gene over its own mouth absorbs, as `plastid` is
		# light: the caller's income (§5.3).
		{&"cirrus": 2, &"flagellum": 1, &"chemocyte": 1},
	]
	var worst := 0.0
	var low := 1.0
	var high := 0.0
	var frames := 3600
	var dt := 1.0 / 60.0
	var dash := CellBody.DASH_COST_BY_TIER[1] * Metabolism.HUNGER_SECONDS
	for tiers: Dictionary in genomes:
		var met: Node = Metabolism.new()
		met.upkeep = GenomeNode.upkeep_of(tiers)
		met.reserve = CellBody.STORE_BY_TIER[GenomeNode.tier_of(tiers, &"vacuole")]
		met.photosynthesis = CellBody.SUN_BY_TIER[GenomeNode.tier_of(tiers, &"plastid")] \
			+ (Metabolism.ABSORB if GenomeNode.tier_of(tiers, &"cytostome") == 0 else 0.0)
		met.burn = CellBody.BURN_BY_TIER[GenomeNode.tier_of(tiers, &"crista")]
		met.set_hunger(0.3)
		var index := _pose(field, Vector2(1500.0, 0.0), 30.0, tiers, 0.0, 0.3)
		var tank: Object = (field.get("_cells") as Array)[index]
		var last := -1
		for f in frames:
			# What the body did this frame, in seconds of rest: a stroke now and
			# then, steering a third of the time, and one dash.
			var effort := 0.0
			if randf() < 1.0 / 120.0:
				effort += randf_range(0.9, 1.3)
			if randf() < 1.0 / 3.0:
				effort += randf_range(0.0, 0.02)
			if f == 1500:
				effort += dash
			# The run pays the effort, then the node is alive for the frame, then
			# the water feeds it.
			met.spend(effort)
			met.call(&"_process", dt)
			tank.set("effort", float(tank.get("effort")) + effort)
			# A meal every ten seconds, worth three fifths of what is missing, so
			# neither tank is ever pinned at empty or at full: a pinned tank
			# would agree with anything.
			var meal := f > 0 and f % 600 == 0
			var every := 1 if f < 1200 else (2 if f < 2400 else Drop.LOD_EVERY)
			if f % every == every - 1 or meal or f == frames - 1:
				field._tank(index, tank, float(f - last) * dt)
				last = f
			if meal:
				var nutrition := 0.6 * float(met.hunger) / Metabolism.MEAL
				met.feed(nutrition)
				field._feed_water(tank, nutrition)
			low = minf(low, met.hunger)
			high = maxf(high, met.hunger)
		worst = maxf(worst, absf(float(met.hunger) - float(tank.get("hunger"))))
		met.free()
		field._drop_lose(index, 0)
	_done(water)
	_check(("one tank: 3 genomes, the node a frame at a time and the water body at its"
		+ " rates, 60 s of the same efforts and meals, end %s apart (hunger ran %.2f"
		+ " to %.2f, never pinned)") % [String.num_scientific(worst), low, high],
		worst < 1e-6 and low > 0.0 and high < 1.0)
	# A body with no mouth at rest: every drifter the water makes holds its tank,
	# neither burning it nor -- with light or a mitochondrion to spare -- filling it.
	var starving := PackedStringArray()
	for gene: StringName in Drop.drifter_genes(FoodField.DRIFTER_GENES):
		var tiers := {gene: 1}
		var rate := Metabolism.rest_rate(GenomeNode.upkeep_of(tiers),
			CellBody.SUN_BY_TIER[GenomeNode.tier_of(tiers, &"plastid")] + Metabolism.ABSORB,
			CellBody.STORE_BY_TIER[GenomeNode.tier_of(tiers, &"vacuole")])
		if rate != 0.0:
			starving.append(str(gene))
	# And §5.3's number: a born cell without its mouth, absorbing, steering a
	# third of the time, is empty at about 46 s.
	var gap := (CellBody.IMPULSE_GAP_MIN_BY_TIER[1] + CellBody.IMPULSE_GAP_MAX_BY_TIER[1]) * 0.5
	var beating := CellBody.IMPULSE_SPEED_BY_TIER[1] * CellBody.IMPULSE_MEAN \
		* CellBody.STROKE_COST / gap
	var turning := CellBody.TURN_RATE_BY_TIER[1] * CellBody.TURN_COST
	var mouthless := {&"cirrus": 1, &"flagellum": 1, &"chemocyte": 1}
	var per_second := Metabolism.rest_rate(GenomeNode.upkeep_of(mouthless), Metabolism.ABSORB,
		1.0) / Metabolism.HUNGER_SECONDS + Metabolism.effort_cost(beating + turning / 3.0, 1.0,
		1.0)
	_check(("a mouthless body at rest neither starves nor fills: %d of %d drifter genes burn"
		+ " or gain anything (%s); a born cell without its mouth is empty at %.1f s --"
		+ " §5.3's 46") % [
		starving.size(), Drop.drifter_genes(FoodField.DRIFTER_GENES).size(),
		", ".join(starving), 1.0 / per_second],
		starving.is_empty() and absf(1.0 / per_second - 46.0) < 1.0)
	# The tank's arithmetic at its edges: nothing spent costs nothing, a body
	# with no store is held to RESERVE_MIN's rather than emptied at once, and a
	# mouthless body absorbs exactly the upkeep of the one organ it needs to live.
	var none := [Metabolism.effort_cost(-1.0, 1.0, 1.0), Metabolism.effort_cost(0.0, 1.0, 1.0)]
	var storeless := [Metabolism.rest_rate(1.0, 0.0, 0.0),
		Metabolism.effort_cost(1.0, 1.0, 0.0) * Metabolism.HUNGER_SECONDS]
	var organ := GenomeNode.upkeep_of({&"cirrus": 1})
	_check(("a tank's edges: effort of -1 s and of 0 s costs %s; with no store at all a"
		+ " body burns %s -- 1 / %.2f -- rather than all of it at once; ABSORB %.3f is the"
		+ " upkeep of one cirrus, %.3f") % [str(none), str(storeless), Metabolism.RESERVE_MIN,
		Metabolism.ABSORB, organ],
		none == [0.0, 0.0] and Metabolism.RESERVE_MIN > 0.0
		and is_equal_approx(storeless[0], 1.0 / Metabolism.RESERVE_MIN)
		and is_equal_approx(storeless[1], 1.0 / Metabolism.RESERVE_MIN)
		and Metabolism.ABSORB == organ)


# --- The drop in the water (§14.3: checks 3 to 6, 8, 9 and 11) ----------------------------

## **A born ghost player and the drop made round it**, stepped by hand one fixed
## frame at a time: out of the water until a check puts it in, still, and with
## everything alive within [param desert] of it taken away, so bodies can be
## posed in the clear. [param sensed] makes the drop for a player that sighted.
## [param rules] false is pack 2's hand-written hunter (behaviour.md §12.3 check 1).
func _water(desert := 0.0, sensed := -1.0, rules := true) -> Array:
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	var field := WatchedDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.desert = desert
	field.sensed_override = sensed
	field.rules = rules
	add_child(field)
	field.setup_drop(cell)
	field.in_water = false
	return [field, cell]


func _done(water: Array) -> void:
	(water[0] as Node).queue_free()
	(water[1] as Node).free()


## A body [param index] of [param field]'s, posed: at [param at], facing
## [param facing], its tank at [param hunger], resting as long as it is left --
## on pack 2's hunter by its `calm`, and on rules by a list that says so
## ([constant RESTING]). A check that wants it to act gives it the founders' rules
## back (`brain` null) or a list of its own.
func _pose(field: Node, at: Vector2, radius: float, tiers: Dictionary, facing := 0.0,
		hunger := 0.5) -> int:
	var index: int = field.pose_body(at, radius, tiers)
	var b: Object = (field.get("_cells") as Array)[index]
	b.set("heading", facing)
	b.set("hunger", hunger)
	b.set("calm", 999.0)
	b.set("brain", _list(RESTING))
	return index


## A posed body's rules: rest, whatever it senses.
const RESTING: Array[String] = ["always -> body.rest"]


## [param lines] as the rules a body carries, by this build's vocabulary.
func _list(lines: Array[String]) -> RefCounted:
	return FoodField.behaviour_from(PackedStringArray(lines))


## The heading from [param from] that points at [param to].
func _facing(from: Vector2, to: Vector2) -> float:
	var v := to - from
	return atan2(v.x, -v.y)


## The settled flocs within a unit of [param at] in [param field].
func _flocs_at(field: Node, at: Vector2) -> Array:
	var out := []
	for b: Object in field.get("_cells"):
		if b.get("seeded") and b.get("inert") and _dist(b.get("pos"), at) < 1.0:
			out.append(b)
	return out


# --- 3. Nothing is made where it can be seen ---------------------------------------------

## **2,000 bodies made with one player and 2,000 with two, and none inside any
## player's hide reach for its kind** (§6.3) -- a drifter out of the view and the
## player's own senses, a peer out of dread's reach as well -- through the
## field's own door, for a player with a tier-1 radar. Each is taken away again,
## so the drop stays at its size. **And the first drifter**, held until the cell
## first moves and then put along that motion, is out of the view both times.
## **Where a body goes is the subject**, and it goes there by one door whatever
## made it: so this asks with births off, whose spawner makes a body every time
## and both kinds by turns. What pack 2's spawner makes is lineage 4's.
func _spawns() -> void:
	var water := _water()
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	field.births = false
	field.ping_range = CellBody.PING_RANGE_BY_TIER[1]
	var hides := [Drop.hide_reach(field.ping_range, FoodField.DREAD_RANGE, false),
		Drop.hide_reach(field.ping_range, FoodField.DREAD_RANGE, true)]
	var cells: Array = field.get("_cells")
	var first: Object = cells[int(field.get("_first_index"))]
	var held_at := _dist(first.get("pos"), cell.position)
	var made := [0, 0]
	var kinds := [0, 0]
	var inside := 0
	var outside := 0
	var players := [PackedVector2Array([cell.position]),
		PackedVector2Array([cell.position, cell.position + Vector2(2600.0, 1800.0)])]
	for round in 2:
		var at: PackedVector2Array = players[round]
		var reaches := PackedFloat32Array()
		for p: Vector2 in at:
			reaches.append(field.ping_range)
		for k in 2000:
			# Made for a player who sees everything and for one who sees
			# nothing, in turn: the two drifter shares, 0.45 and 0.92.
			field.set("_made_for", PackedFloat64Array([cell.radius, 1.0 if k % 2 == 0
				else 0.0]))
			var index := field._make_one(at, reaches)
			if index < 0:
				continue
			made[round] += 1
			var b: Object = (field.get("_cells") as Array)[index]
			var peer := 0 if b.get("drifter") else 1
			kinds[peer] += 1
			for p: Vector2 in at:
				if _dist(b.get("pos"), p) < float(hides[peer]):
					inside += 1
			if not field.basin().inside(b.get("pos"), Drop.SPAWN_INSET):
				outside += 1
			field._drop_lose(index, 0)
	cell.velocity = Vector2(30.0, -40.0)
	field.in_water = true
	field._process(1.0 / 60.0)
	var placed_at := _dist(first.get("pos"), cell.position)
	_check(("3. nothing is made where it can be seen: %d and %d bodies made with one player"
		+ " and with two (%d drifters, %d peers), %d inside a player's hide reach (%.0f for"
		+ " a drifter, %.0f for a peer), %d past the rim; the first drifter %.0f away"
		+ " before the cell moves and %.0f after, out of the view's %.0f") % [made[0], made[1],
		kinds[0], kinds[1], inside, hides[0], hides[1], outside, held_at, placed_at,
		Drop.VIEW_REACH],
		made[0] >= 1990 and made[1] >= 1990 and kinds[0] > 500 and kinds[1] > 500
		and inside == 0 and outside == 0 and held_at >= Drop.VIEW_REACH
		and placed_at >= Drop.VIEW_REACH)
	_done(water)


# --- 4. Containment ------------------------------------------------------------------------

## **After 1,800 frames no body's centre past `RADIUS - r`, the player's
## included; no mote past the rim** (§3.1). A run started 120 inside the rim,
## facing it, the cell pressing straight into it at a stroke's speed the whole
## time -- knocked at the rim's bearing, and at most once in SHORE_GAP -- with its
## grit, the authored first mote included, round it. Bodies are looked at every
## half second, the cell and the grit every frame.
func _containment() -> void:
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	var field := WatchedDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.start_mode = &"edge"
	field.edge_gap = 120.0
	field.grace = 1e6
	field.contact_swallow = false
	add_child(field)
	field.setup_drop(cell)
	field.in_water = true
	var motes := MotesField.new()
	motes.setup(cell, field.basin())
	var rim: RefCounted = field.basin()
	var centre: Vector2 = rim.get(&"center")
	var edge: float = rim.get(&"radius")
	var knocks: Array = []
	field.shored.connect(func(bearing: float, _strength: float, _at: Vector2) -> void:
		knocks.append([float(field.get("_t")), bearing]))
	# And water bodies that only their own step holds: hungry hunters spread
	# along the rim away from the cell, a few units inside where they are held,
	# none touching another or able to eat one, with no sense to find food by --
	# so they swim straight out to look for it, past the rim in a frame, if
	# their step did not hold them.
	var out0 := (cell.position - centre).normalized()
	for k in 24:
		var along := out0.rotated(deg_to_rad((5.0 + 2.5 * float(k / 2)) * (1.0 if k % 2 == 0
			else -1.0)))
		var hungry := _pose(field, centre + along * (edge - 33.0), 30.0,
			{&"cytostome": 1, &"cirrus": 1, &"flagellum": 2}, atan2(along.x, -along.y), 0.9)
		var hb: Object = (field.get("_cells") as Array)[hungry]
		hb.set("calm", 0.0)
		hb.set("searching", true)
		hb.set("brain", null)
	var worst_body := INF
	var worst_cell := INF
	var worst_mote := INF
	var bodies_seen := 0
	for f in 1800:
		var out := (cell.position - centre).normalized()
		cell.heading = atan2(out.x, -out.y)
		cell.velocity = out * 120.0
		cell.position += cell.velocity / 60.0
		field._process(1.0 / 60.0)
		motes._process(1.0 / 60.0)
		worst_cell = minf(worst_cell, edge - cell.radius - _dist(cell.position, centre))
		for p: Vector2 in motes.points():
			worst_mote = minf(worst_mote, edge - MotesField.MOTE_RADIUS - _dist(p, centre))
		if f % 30 == 29:
			for b: Object in field.get("_cells"):
				if b.get("seeded"):
					bodies_seen += 1
					worst_body = minf(worst_body,
						edge - float(b.get("radius")) - _dist(b.get("pos"), centre))
	var gap := INF
	var off_bearing := 0.0
	for k in knocks.size():
		off_bearing = maxf(off_bearing, absf(float(knocks[k][1])))
		if k > 0:
			gap = minf(gap, float(knocks[k][0]) - float(knocks[k - 1][0]))
	_check(("4. containment: 1,800 frames of a cell pressing into the rim; of %d looks at"
		+ " a body the nearest to the rim was %.3f inside where it is held, the cell %.3f"
		+ " and its grit %.3f; knocked %d times, at most %.1f deg off dead ahead, at"
		+ " least %.2f s apart (SHORE_GAP %.1f)") % [bodies_seen, worst_body, worst_cell,
		worst_mote, knocks.size(), rad_to_deg(off_bearing), gap, Drop.SHORE_GAP],
		worst_body >= -1e-3 and worst_cell >= -1e-3 and worst_mote >= -1e-3
		and knocks.size() >= 20 and gap >= Drop.SHORE_GAP - 1e-6
		and off_bearing < deg_to_rad(1.0) and bodies_seen > 30000)
	motes.free()
	field.queue_free()
	cell.free()


# --- 5, 6 and 11: five minutes of a drop ----------------------------------------------------

## **Five minutes of a drop made for a fully sighted player** (§14.3), with a
## still ghost player in it, watched from inside:
##
## - 5, growth: no body over DIVIDE_RADIUS, and none *made* with a mouth wider
##   than ARRIVAL_GAPE_MAX -- a grown one may have it (row 5);
## - 6, the floors: every drifter gene carried at every count, and a gene found
##   short back at GENE_FLOOR by the next; a living drifter within the floor's
##   reach of the still player every second; no drifter made with venom;
## - 11, one body: every body that left the drop living left by one of the four
##   causes or by dividing, and nothing else, and every body made or born is
##   living or left; **on rules** (behaviour.md §4.5) no body faster than its own
##   tail, its axoneme at full and its dash, no burst without a `myoneme` -- and
##   nothing of pack 2's hunter: no run begun, no search, no swim of a run's.
## - 9, **the founders hunt** (behaviour.md §12.3): each of the founders' seven
##   rules fires, and hunters with a nose, a radar and a laser each eat. That the
##   rules are alive, not how well they hunt.
##
## **Since bodies divide** (pack 2) a body at forty divides on its tick, so a
## look once a second finds one there less often: the ticks at forty count too.
## And this is one of the three drops pack 2's checks read ([method _lineage]),
## the one on rules.
func _five_minutes() -> void:
	var water := _water(0.0, 1.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var biggest := 0.0
	var at_forty := 0
	var floor_checks := 0
	var floor_missed := 0
	var seen := {}
	for f in 5 * 60 * 60:
		field._process(1.0 / 60.0)
		if f % 60 != 59:
			continue
		if f % 600 == 599:
			_lineage_look(field, float(f + 1) / 60.0, seen)
		floor_checks += 1
		if field._count_drifters_at(cell.position,
				field._hide_reach(true) + Drop.DRIFTER_FLOOR_SLACK) == 0:
			floor_missed += 1
		for b: Object in field.get("_cells"):
			if b.get("seeded") and not b.get("inert"):
				biggest = maxf(biggest, float(b.get("radius")))
				if float(b.get("radius")) >= CellBody.DIVIDE_RADIUS - 1e-3:
					at_forty += 1
	var living := 0
	var venomous := 0
	for b: Object in field.get("_cells"):
		if b.get("seeded") and not b.get("inert"):
			living += 1
			if b.get("drifter") and (b.get("genome") as Dictionary).has(&"veneneux"):
				venomous += 1
	_check(("5. growth: five minutes of a drop made for a sighted player, the biggest body"
		+ " r%.2f (DIVIDE_RADIUS %.0f; %d looks at one there, %d ticks at forty), and of %d"
		+ " bodies made the widest mouth %.2f (ARRIVAL_GAPE_MAX %.0f)") % [biggest,
		CellBody.DIVIDE_RADIUS, at_forty, field.at_forty, field.made, field.made_gape,
		FoodField.ARRIVAL_GAPE_MAX],
		biggest <= CellBody.DIVIDE_RADIUS + 1e-4 and at_forty + field.at_forty > 0
		and field.made_gape <= FoodField.ARRIVAL_GAPE_MAX and field.made > 1000)
	_check(("6. the floors: at %d gene counts a drifter gene carried by nobody %d times and"
		+ " one still short at the count after %d; a living drifter within the floor's"
		+ " reach of the still player at %d of %d checks; drifters made with venom %d,"
		+ " living with it %d") % [field.counts, field.lost_genes, field.still_short,
		floor_checks - floor_missed, floor_checks, field.venom_drifters, venomous],
		field.counts >= 140 and field.lost_genes == 0 and field.still_short == 0
		and floor_missed == 0 and floor_checks >= 300 and field.venom_drifters == 0
		and venomous == 0)
	var gone := 0
	for cause: int in field.causes:
		gone += int(field.causes[cause])
	var four := 0
	for cause: int in [FoodField.Cause.SWALLOWED, FoodField.Cause.CHEWED,
			FoodField.Cause.STARVED, FoodField.Cause.POISONED]:
		four += int(field.causes.get(cause, 0))
	_check(("11. one body, five minutes: %d bodies gone -- %d swallowed, %d chewed, %d"
		+ " starved, %d poisoned, %d divided, %d any other way -- and %d made + %d born ="
		+ " %d living + %d gone; on rules, %d steps, %d faster than its own tail, axoneme"
		+ " and dash, %d bursts without a myoneme; of pack 2's hunter %d runs begun, %d"
		+ " searching frames and %d swims of a run") % [gone,
		int(field.causes.get(FoodField.Cause.SWALLOWED, 0)),
		int(field.causes.get(FoodField.Cause.CHEWED, 0)),
		int(field.causes.get(FoodField.Cause.STARVED, 0)),
		int(field.causes.get(FoodField.Cause.POISONED, 0)), field.divisions,
		gone - four - field.divisions, field.made, field.born, living, gone, field.moves,
		field.fast_moves, field.bursts, field.runs_begun, field.searches, field.swims],
		gone - four == field.divisions and gone > 500 and field.made + field.born == living + gone
		and int(field.causes.get(FoodField.Cause.STARVED, 0)) > 0
		and field.moves > 10000 and field.fast_moves == 0 and field.bursts == 0
		and field.runs_begun == 0 and field.searches == 0 and field.swims == 0)
	# 9. Each founders' rule by its place in the list, and the meals by sense.
	var stats: Dictionary = field.stats
	var fired := PackedStringArray()
	var silent := 0
	for k in Drop.FOUNDERS.size():
		var n := int(stats.get(FoodField.FIRED[k], 0))
		fired.append(str(n))
		silent += 1 if n <= 0 else 0
	var meals := [int(stats.get(&"meals_nose", 0)), int(stats.get(&"meals_radar", 0)),
		int(stats.get(&"meals_laser", 0))]
	_check(("9. the founders hunt: in five minutes of a sighted player's drop each of the"
		+ " founders' %d rules fired (%s times, top to bottom), and hunters with a nose, a"
		+ " radar and a laser ate %d, %d and %d meals") % [Drop.FOUNDERS.size(),
		"/".join(fired), meals[0], meals[1], meals[2]],
		fired.size() == 7 and silent == 0 and meals[0] > 0 and meals[1] > 0 and meals[2] > 0)
	seen["food"] = float(int(field.get("_drifters"))) / Drop.food_count(field._made_share())
	_lineage_runs.append(_lineage_summary(field, "a fully sighted player's", seen))
	_done(water)


# --- Pack 2: the water divides (docs/design/lineage.md §11.3, checks 1 to 6) -----------------

## What each five-minute drop saw of pack 2's rules: a sighted player's
## ([method _five_minutes]) and a newborn's ([method _lineage]).
var _lineage_runs: Array[Dictionary] = []


## **A census, every ten seconds of a drop**: the hunters against today's count
## once the first minute is over, the least of it kept, and how many of the
## genes the living carry, the least of it kept.
func _lineage_look(field: WatchedDrop, t: float, seen: Dictionary) -> void:
	var hunters := float(int(field.get("_living")) - int(field.get("_drifters")))
	if t > 60.0 + 1e-3:
		var ratio := hunters / Drop.hunter_floor(field._made_share())
		if ratio < float(seen.get("floor", INF)):
			seen["floor"] = ratio
			seen["floor_at"] = t
	var genes := {}
	for b: Object in field.get("_cells"):
		if b.get("seeded") and not b.get("inert"):
			for gene: StringName in b.get("genome"):
				genes[gene] = true
	seen["genes"] = mini(int(seen.get("genes", 99)), genes.size())
	seen["looks"] = int(seen.get("looks", 0)) + 1
	seen["hunters_most"] = maxi(int(seen.get("hunters_most", 0)), int(hunters))


## What one drop's [WatchedDrop] counted of pack 2's rules, and what its
## censuses saw, kept after the field is gone.
func _lineage_summary(field: WatchedDrop, named: String, seen: Dictionary) -> Dictionary:
	var out := seen.duplicate()
	out["name"] = named
	for key: String in ["divisions", "born", "faults", "body_faults", "said", "kinds",
			"held_at_rim", "at_forty", "missed", "rolled", "worn", "meals_judged",
			"meal_faults", "graced_runs", "runs_at_born", "graced_eaten", "peers_over_floor",
			"made_kinds", "runs_begun", "rule_divisions", "doors", "off_founders", "rules"]:
		var value: Variant = field.get(key)
		out[key] = value.duplicate() if value is Dictionary or value is Array \
			or value is PackedInt32Array else value
	out["gifted"] = int((field.get("stats") as Dictionary).get(&"born_gifted", 0))
	out["lineage"] = field.lineage_line()
	return out


## **The water divides** (lineage.md §11.3, checks 1 to 6): five minutes of a
## newborn's drop and five of a sighted player's -- the spec's two compositions,
## 0.2 and 0.6 -- watched from inside as [method _five_minutes] watched a fully
## sighted player's, and read together: the three for what a division, a roll, a
## meal and the grace are, the spec's two for the floor and the spawner.
##
## 1. **A division is the player's**: every body that divided was at forty and
##    every one at forty divided on its tick; two daughters at half its area,
##    touching across its heading, fed, in their grace, new ids, its children;
##    one carrying its DNA, the other one trade or one drift of it, never a
##    shift, both with a mouth.
## 2. **Expression**: every daughter's body a roll of her DNA at the copies it
##    carries -- one copy worn about 55 % of the time, two 80 %, three always --
##    the mouth always, and a sense, at tier 1 if she was given it.
## 3. **The floor**: after the first minute, the hunters at 90 % of today's count
##    or more at every census, at both compositions.
## 4. **The spawner**: no peer while the hunters are at or over the floor but for
##    venom; drifters at 85 % of their count or more after five minutes; every
##    gene, venom included, carried at every census -- and with a hundred
##    hunters posed over the floor, the food is still made
##    ([method _food_over_floor]).
## 5. **The grace**: no run begun at a body in its grace, every `_start_run`
##    over the three drops checked; daughters are hunted once it is over, and a
##    mouth one touches in it still eats her.
## 6. **A water cell's meal writes its DNA, never its body**: every meal.
##
## **The spec's two run on pack 2's hand-written hunter** (`rules` off), from
## seed 1, and are **behaviour.md §12.3 check 1** as well: with the rules off it
## is pack 2 to the byte -- their census and lineage lines at five minutes are
## [constant DEV_LINES], `dev`'s, and the senses the player and the water share
## are pinned by [method _membrane]. The sighted player's drop of
## [method _five_minutes] is on rules, so the division is checked on both.
func _lineage() -> void:
	var lines: Array[String] = []
	for each: Array in [[1, 0.2, "a newborn's"], [1, 0.6, "a sighted player's"]]:
		seed(int(each[0]))
		var water := _water(0.0, float(each[1]), false)
		var field: WatchedDrop = water[0]
		var seen := {"composed": true}
		for f in 5 * 60 * 60:
			field._process(1.0 / 60.0)
			if f % 600 == 599:
				_lineage_look(field, float(f + 1) / 60.0, seen)
		seen["food"] = float(int(field.get("_drifters"))) \
			/ Drop.food_count(field._made_share())
		_lineage_runs.append(_lineage_summary(field, String(each[2]), seen))
		lines.append(field.census_line())
		lines.append(field.lineage_line())
		_done(water)
	seed(20260930)
	var differ := 0
	for k in DEV_LINES.size():
		var ours: String = lines[k] if k < lines.size() else "(none)"
		if ours != DEV_LINES[k]:
			differ += 1
			print("[drop-probe] check 1, line %d, this build: %s" % [k + 1, ours])
			print("[drop-probe] check 1, line %d, dev:        %s" % [k + 1, DEV_LINES[k]])
	_check(("1. with the rules off it is pack 2, the drop: a newborn's drop and a sighted"
		+ " player's, seed 1, five minutes on pack 2's hunter -- their census and lineage"
		+ " lines against dev's: %s") % ["the same to the byte" if differ == 0
		else "%d DIFFER" % differ],
		differ == 0 and lines.size() == DEV_LINES.size())
	var posed := _food_over_floor()
	var runs := _lineage_runs
	var composed: Array[Dictionary] = []
	for run: Dictionary in runs:
		if run.has("composed"):
			composed.append(run)
	var sum := func(key: String) -> int:
		var n := 0
		for run: Dictionary in runs:
			n += int(run[key])
		return n
	var said: Array[String] = []
	var kinds := {}
	var each := PackedStringArray()
	for run: Dictionary in runs:
		said.append_array(run["said"])
		for kind: Variant in run["kinds"]:
			kinds[kind] = int(kinds.get(kind, 0)) + int(run["kinds"][kind])
		each.append("%s %d" % [run["name"], int(run["divisions"])])
	var enough := runs.size() == 3 and composed.size() == 2 \
		and runs.all(func(run: Dictionary) -> bool: return int(run["divisions"]) >= 50)
	_check(("lineage 1. a division is the player's: %d divisions in three drops' five minutes"
		+ " (%s), every mother at r40 and every body at forty on its tick divided on it (%d"
		+ " ticks, %d missed); %d daughters at r%.2f touching across her heading where she"
		+ " was (%d held in by the rim), fed, in their grace, new ids, her children; one"
		+ " faithful and one"
		+ " changed: %s, never a shift; %d faults%s") % [sum.call("divisions"), ", ".join(each),
		sum.call("at_forty"), sum.call("missed"), sum.call("born"),
		CellBody.daughter_radius(CellBody.DIVIDE_RADIUS), sum.call("held_at_rim"), str(kinds),
		sum.call("faults"), "" if said.is_empty() else " -- " + "; ".join(said)],
		enough and sum.call("faults") == 0 and sum.call("missed") == 0
		and sum.call("at_forty") >= sum.call("divisions")
		and sum.call("born") == 2 * sum.call("divisions")
		and kinds.keys().all(func(kind: StringName) -> bool:
			return kind == &"trade" or kind == &"drift")
		and int(kinds.get(&"trade", 0)) > 0 and int(kinds.get(&"drift", 0)) > 0)
	var rolled := PackedInt32Array([0, 0, 0, 0])
	var worn := PackedInt32Array([0, 0, 0, 0])
	for run: Dictionary in runs:
		for copies in 4:
			rolled[copies] += int(run["rolled"][copies])
			worn[copies] += int(run["worn"][copies])
	var share := func(copies: int) -> float:
		return float(worn[copies]) / float(maxi(rolled[copies], 1))
	_check(("lineage 2. expression: every daughter's body a roll of what she carries at the"
		+ " copies she carries, the mouth always and a sense -- given one at tier 1 %d"
		+ " times -- with %d faults; worn at one copy %.2f of %d (%.2f), at two %.2f of %d"
		+ " (%.2f), at three %.2f of %d") % [sum.call("gifted"), sum.call("body_faults"),
		share.call(1), rolled[1], GenomeNode.EXPRESS_CHANCE[1], share.call(2), rolled[2],
		GenomeNode.EXPRESS_CHANCE[2], share.call(3), rolled[3]],
		enough and sum.call("body_faults") == 0 and sum.call("gifted") > 0
		and rolled[1] >= 300 and absf(share.call(1) - GenomeNode.EXPRESS_CHANCE[1]) < 0.08
		and rolled[2] >= 100 and absf(share.call(2) - GenomeNode.EXPRESS_CHANCE[2]) < 0.08
		and rolled[3] >= 50 and worn[3] == rolled[3])
	var floors := PackedStringArray()
	var foods := PackedStringArray()
	var genes := PackedStringArray()
	for run: Dictionary in composed:
		floors.append("%s %.1f %% at %.0f s (at most %d hunters)" % [run["name"],
			100.0 * float(run.get("floor", 0.0)), float(run.get("floor_at", 0.0)),
			int(run["hunters_most"])])
		foods.append("%s %.1f %%" % [run["name"], 100.0 * float(run["food"])])
		genes.append("%s %d at the least of %d" % [run["name"], int(run["genes"]),
			int(run["looks"])])
	_check(("lineage 3. the floor: after the first minute the hunters stood at least at %s"
		+ " of today's count, a census every ten seconds") % ", ".join(floors),
		enough and composed.all(func(run: Dictionary) -> bool:
			return run.has("floor") and float(run["floor"]) >= 0.9))
	var made := {}
	var fed := enough
	for run: Dictionary in composed:
		for kind: Variant in run["made_kinds"]:
			made[kind] = int(made.get(kind, 0)) + int(run["made_kinds"][kind])
		fed = fed and float(run["food"]) >= 0.85 \
			and int(run["genes"]) == GenomeNode.GENE_ORDER.size()
	_check(("lineage 4. the spawner: of what it made %s, %d peers while the hunters stood at"
		+ " or over the floor and venom was not short; drifters after five minutes at %s of"
		+ " their count; every gene carried at every census (%s of %d); with %d hunters"
		+ " posed over the floor and %d drifters taken, %d drifters made in %d s and %d"
		+ " peers but for venom, the food back at %.1f %%") % [str(made),
		sum.call("peers_over_floor"),
		", ".join(foods), ", ".join(genes), GenomeNode.GENE_ORDER.size(), int(posed["over"]),
		int(posed["taken"]), int(posed["drifters"]), int(posed["seconds"]), int(posed["peers"]),
		100.0 * float(posed["food"])],
		fed and sum.call("peers_over_floor") == 0 and int(made.get("peer", 0)) > 0
		and int(posed["drifters"]) >= int(posed["taken"]) / 2 and int(posed["peers"]) == 0
		and float(posed["food"]) >= 0.9)
	_check(("lineage 5. the grace: %d runs begun over the two drops on pack 2's hunter (the"
		+ " rules begin none), %d at a body in its grace; %d at daughters once theirs was"
		+ " over; %d daughters eaten in their grace by a mouth they touched")
		% [sum.call("runs_begun"), sum.call("graced_runs"),
		sum.call("runs_at_born"), sum.call("graced_eaten")],
		enough and sum.call("graced_runs") == 0 and sum.call("runs_at_born") > 20
		and sum.call("graced_eaten") > 0 and sum.call("runs_begun") > 1000)
	_check(("lineage 6. a water cell's meal writes its DNA, never its body: %d meals, %d"
		+ " that wrote the body or not the DNA by the rule") % [sum.call("meals_judged"),
		sum.call("meal_faults")],
		enough and sum.call("meals_judged") > 1000 and sum.call("meal_faults") == 0)
	for run: Dictionary in runs:
		print("[drop-probe] (%s drop at five minutes) %s" % [run["name"], run["lineage"]])


## **The food whatever the hunters number** (check 4): a newborn's drop, a
## hundred hunters posed over today's count where nobody is -- resting, fed --
## and drifters taken out; fifteen seconds later the spawner has made drifters
## back toward their count, and no peer.
func _food_over_floor() -> Dictionary:
	var water := _water(0.0, 0.2)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var share: float = field._made_share()
	var over := int(Drop.hunter_floor(share)) + 100 \
		- (int(field.get("_living")) - int(field.get("_drifters")))
	var centre: Vector2 = field.basin().get(&"center")
	for k in over:
		var at := centre + Vector2.from_angle(TAU * float(k) / float(over)) * 4000.0
		if at.distance_to(cell.position) < 2500.0:
			at = centre + (at - centre) * 0.5
		_pose(field, at, 30.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, 0.0, 0.0)
	var taken := 0
	for i in (field.get("_cells") as Array).size():
		var b: Object = (field.get("_cells") as Array)[i]
		if taken < 60 and bool(b.get("seeded")) and bool(b.get("drifter")) \
				and not bool(b.get("inert")):
			field.take_out(i)
			taken += 1
	var before: Dictionary = field.made_kinds.duplicate()
	var peers_before := field.peers_over_floor
	for f in 15 * 60:
		field._process(1.0 / 60.0)
	var out := {"over": over, "taken": taken, "seconds": 15,
		"drifters": int(field.made_kinds.get("drifter", 0)) - int(before.get("drifter", 0)),
		"peers": field.peers_over_floor - peers_before,
		"food": float(int(field.get("_drifters"))) / Drop.food_count(share)}
	_done(water)
	return out


# --- Pack 3's second phase: a change at every division (behaviour.md §6, §12.3) -----------------

## **5. A division** (behaviour.md §6.1, §6.4, §12.3), over the three drops pack
## 2's checks read: the sighted player's on rules ([method _five_minutes]), whose
## rules change, and the two on pack 2's hunter ([method _lineage]). **On rules**
## every division gives the daughter whose DNA is her mother's that list itself,
## and her sister one change of it -- a new list of a kind [method _change_kinds]
## reads, a family's own or the founders' -- and the five kinds all come. **On
## pack 2's hunter** both daughters carry their mother's. **And every body the
## water lets in carries the founders' rules**: every body each door of those
## drops made; and in a drop of its own, a body posed into the slot of one that
## carried rules of its own, and a sister, the child of the cell she divided from.
func _division_rules() -> void:
	var vocab: RefCounted = FoodField.vocabulary()
	var on := 0
	var off := 0
	var faults := 0
	var said: Array[String] = []
	var kinds := {}
	var doors := 0
	var off_founders := 0
	for run: Dictionary in _lineage_runs:
		doors += int(run["doors"])
		off_founders += int(run["off_founders"])
		for one: Array in run["rule_divisions"]:
			var why := ""
			if not bool(one[1]):
				why = "her faithful daughter does not carry her list"
			elif not bool(run["rules"]):
				off += 1
				if not bool(one[3]):
					why = "on pack 2's hunter, a daughter's rules changed"
			else:
				on += 1
				var can := _change_kinds(FoodField.behaviour_from(one[0]),
					FoodField.behaviour_from(one[2]), vocab)
				if bool(one[3]) or can.is_empty():
					why = "not one change: [%s] to [%s]" % [" / ".join(one[0]), " / ".join(one[2])]
				else:
					# The narrowest reading: a step one rung along is a nudge, though a
					# replace could have drawn it too.
					kinds[can[0]] = int(kinds.get(can[0], 0)) + 1
			if not why.is_empty():
				faults += 1
				if said.size() < 3:
					said.append(why)
	# Posed where a body with rules of its own was, and a sister.
	var water := _water()
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var cells: Array = field.get("_cells")
	var body := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}
	var was := _pose(field, cell.position + Vector2(800.0, 0.0), 30.0, body)
	field.take_out(was)
	var posed: int = field.pose_body(cell.position + Vector2(-800.0, 0.0), 30.0, body)
	var posed_on: bool = posed == was and (cells[posed] as Object).get("brain") == null
	field.put_sister(PI * 0.5, 560.0, CellBody.daughter_radius(), body,
		{&"cytostome": 2, &"cirrus": 1, &"flagellum": 1}, Descent.founder(field.take_id()))
	var sister: Object = cells[field.last_spawned]
	var sister_on: bool = sister.get("brain") == null and int(sister.get("parent")) != 0
	_done(water)
	var every := [&"nudge", &"replace", &"swap", &"copy", &"drop"].all(
		func(kind: StringName) -> bool: return int(kinds.get(kind, 0)) > 0)
	_check(("5. a division: %d on rules, each giving the daughter with her mother's DNA her"
		+ " list itself and her sister one change of it (%s), and %d on pack 2's hunter giving"
		+ " both hers; %d faults%s; of %d bodies the water's doors let in, %d off the founders'"
		+ " rules; a body posed into the slot of one with rules of its own is on them (%s), and"
		+ " a sister (%s)") % [on, str(kinds), off, faults,
		"" if said.is_empty() else " -- " + "; ".join(said), doors, off_founders,
		str(posed_on), str(sister_on)],
		on >= 100 and off >= 100 and faults == 0 and every and doors > 1000
		and off_founders == 0 and posed_on and sister_on)


## **The kinds of change [param child] could be from [param parent], by this
## probe's own reading of §6.2**: a copy of one rule directly under itself, a
## drop, a swap of two neighbours that differ, or one rule changed -- a nudge,
## one step, reference or option one rung along its ladder and nothing else
## moved, or a replace: its input with whatever tests, one test added, removed or
## put in another's place, or its output with whatever option. A nudge is also a
## replace that drew the next rung. Empty when it is not one change: nothing
## changed, or more than one thing.
func _change_kinds(parent: RefCounted, child: RefCounted, vocab: RefCounted) -> Array[StringName]:
	var out: Array[StringName] = []
	var p := _rule_keys(parent)
	var c := _rule_keys(child)
	var n := p.size()
	if c.size() == n + 1:
		for k in n:
			var copied := p.duplicate()
			copied.insert(k + 1, p[k])
			if copied == c:
				out.append(&"copy")
				break
		return out
	if c.size() == n - 1:
		for k in n:
			var dropped := p.duplicate()
			dropped.remove_at(k)
			if dropped == c:
				out.append(&"drop")
				break
		return out
	if c.size() != n:
		return out
	var apart: Array[int] = []
	for k in n:
		if p[k] != c[k]:
			apart.append(k)
	if apart.size() == 2 and apart[1] == apart[0] + 1 and p[apart[0]] == c[apart[1]] \
			and p[apart[1]] == c[apart[0]]:
		out.append(&"swap")
	elif apart.size() == 1:
		out = _rule_change_kinds((parent.get("rules") as Array)[apart[0]],
			(child.get("rules") as Array)[apart[0]], vocab)
	return out


## What one rule changed into another could be: a nudge, a replace, or both.
func _rule_change_kinds(x: Object, y: Object, vocab: RefCounted) -> Array[StringName]:
	var out: Array[StringName] = []
	if bool(x.get("inert")) or bool(y.get("inert")):
		return out
	var xt := _tests_of(x)
	var yt := _tests_of(y)
	var same_in: bool = x.get("input") == y.get("input")
	var same_out: bool = x.get("output") == y.get("output")
	var xo := float(x.get("option"))
	var yo := float(y.get("option"))
	var same_option := (is_nan(xo) and is_nan(yo)) or xo == yo
	var same_tests := _rule_key(x).get_slice(" -> ", 0) == _rule_key(y).get_slice(" -> ", 0)
	if same_in and same_out:
		var output: Object = (vocab.get("outputs") as Dictionary).get(y.get("output"))
		if same_tests and not same_option and output != null \
				and _one_rung(output.get("options"), xo, yo):
			out.append(&"nudge")
		if same_option and xt.size() == yt.size():
			var moved: Array[String] = []
			for value: String in xt:
				if not yt.has(value) or xt[value] != yt[value]:
					moved.append(value)
			if moved.size() == 1 and yt.has(moved[0]):
				var was: Array = xt[moved[0]]
				var now: Array = yt[moved[0]]
				var kind := StringName(now[3])
				var below_above := int(was[0]) == int(now[0]) \
					and (int(now[0]) == Rulebook.Test.BELOW or int(now[0]) == Rulebook.Test.ABOVE)
				if below_above and kind == Rulebook.SIZE \
						and _one_rung(Rulebook.REFERENCES, StringName(was[2]), StringName(now[2])):
					out.append(&"nudge")
				elif below_above and kind != Rulebook.SIZE \
						and _one_rung(Rulebook.LADDERS.get(kind, []), float(was[1]), float(now[1])):
					out.append(&"nudge")
	if not same_in and same_out and same_option:
		out.append(&"replace")
	elif same_in and not same_out and same_tests:
		out.append(&"replace")
	elif same_in and same_out and same_option and _one_test_apart(xt, yt):
		out.append(&"replace")
	return out


## Whether [param b] is the rung of [param rungs] next to [param a], up or down:
## for references their places in the list; for numbers a rung with none
## strictly between, so a value off the ladder steps onto the rung nearest it.
func _one_rung(rungs: Array, a: Variant, b: Variant) -> bool:
	if a is StringName:
		var i := rungs.find(a)
		var j := rungs.find(b)
		return i >= 0 and j >= 0 and absi(i - j) == 1
	var x := float(a)
	var y := float(b)
	if x == y or is_nan(x) or is_nan(y) or not rungs.has(y):
		return false
	for rung: Variant in rungs:
		if float(rung) > minf(x, y) and float(rung) < maxf(x, y):
			return false
	return true


## Whether [param y] is [param x] -- tests by value -- with one test added, one
## removed, or one put in another's place, on its value or another.
func _one_test_apart(x: Dictionary, y: Dictionary) -> bool:
	var gone := 0
	var came := 0
	for value: String in x:
		if not y.has(value) or y[value] != x[value]:
			gone += 1
	for value: String in y:
		if not x.has(value) or x[value] != y[value]:
			came += 1
	return (gone == 0 and came == 1) or (gone == 1 and came == 0) or (gone == 1 and came == 1)


## A rule's tests by value: `[test, step, reference, kind]`, the step and
## reference only where the test is put against one.
func _tests_of(rule: Object) -> Dictionary:
	var out := {}
	for clause: Object in rule.get("clauses"):
		var test := int(clause.get("test"))
		var against := test == Rulebook.Test.BELOW or test == Rulebook.Test.ABOVE
		out[String(clause.get("value"))] = [test, float(clause.get("step")) if against else 0.0,
			String(clause.get("ref")) if against else "", String(clause.get("kind"))]
	return out


## **What a rule says, as this probe reads it**: its input, its tests by value
## in name order, its output and its option -- however its line was written. A
## rule the build cannot read is its line.
func _rule_key(rule: Object) -> String:
	if bool(rule.get("inert")):
		return "? " + String(rule.get("text"))
	var tests := PackedStringArray()
	var by_value := _tests_of(rule)
	for value: String in by_value:
		var one: Array = by_value[value]
		tests.append("%s %d %s %s" % [value, int(one[0]), Rulebook.number(float(one[1])), one[2]])
	tests.sort()
	return "%s [%s] -> %s %s" % [rule.get("input"), ", ".join(tests), rule.get("output"),
		str(rule.get("option"))]


func _rule_keys(list: RefCounted) -> PackedStringArray:
	var out := PackedStringArray()
	for rule: Object in list.get("rules"):
		out.append(_rule_key(rule))
	return out


# --- 8. Determinism -------------------------------------------------------------------------

## **One seed, one drop** (§14.3): forty seconds of a drop made for a sighted
## player twice from one seed print the same census line to the byte -- the
## checksum of every body's place, size and tank included -- and so does the
## same seed with the near-first prey search off: nearest wins, so the search
## that looks near first finds the same body (§4.2). **And with bodies dividing**
## (lineage.md §11.3 check 7): the same lineage line too -- every division, its
## mutation and its daughters' rolls drawn from the one stream -- over forty
## seconds in which the water has divided.
##
## **And 6, with the rules changing** (behaviour.md §12.3): those three runs
## change a daughter's rules at every division, and print the same behaviour
## line too -- the changes made and the behaviours they left. **With the changes
## off** (`rule_change`, `--rule-change=0`) the same forty seconds, at a sighted
## player's composition and a newborn's, are phase 3-1's to the byte: its census
## and lineage lines, and its behaviour line with nothing changed after it
## ([constant THREE_ONE_LINES]). With them on, the first is not -- a switch that
## passed either way would be a switch on nothing.
func _determinism() -> void:
	var lines: Array[String] = []
	var families: Array[String] = []
	var behaviours: Array[String] = []
	for near_first: bool in [true, true, false]:
		seed(8088)
		var water := _water(0.0, 0.6)
		var field: WatchedDrop = water[0]
		field.near_first = near_first
		for f in 40 * 60:
			field._process(1.0 / 60.0)
		lines.append(field.census_line())
		families.append(field.lineage_line())
		behaviours.append(field.behaviour_line())
		_done(water)
	var off: Array[String] = []
	for sensed: float in [0.6, 0.2]:
		seed(8088)
		var water := _water(0.0, sensed)
		var field: WatchedDrop = water[0]
		field.rule_change = false
		for f in 40 * 60:
			field._process(1.0 / 60.0)
		off.append_array([field.census_line(), field.lineage_line(), field.behaviour_line()])
		_done(water)
	seed(20260930)
	var differ := 0
	for k in maxi(off.size(), THREE_ONE_LINES.size()):
		var ours: String = off[k] if k < off.size() else "(none)"
		var theirs: String = THREE_ONE_LINES[k] if k < THREE_ONE_LINES.size() else "(none)"
		if theirs.begins_with("[behaviour]"):
			theirs += UNCHANGED_TAIL
		if ours != theirs:
			differ += 1
			print("[drop-probe] check 6, line %d, this build: %s" % [k + 1, ours])
			print("[drop-probe] check 6, line %d, 3-1:        %s" % [k + 1, theirs])
	var changed := behaviours[0].get_slice("| rules changed ", 1).get_slice(":", 0)
	var kinds := behaviours[0].get_slice("| behaviours ", 1).get_slice("  |", 0)
	_check(("6. determinism: one seed, forty seconds of a sighted player's drop with the rules"
		+ " changing (%s changes, behaviours %s), twice and with the near-first search off: the"
		+ " behaviour lines %s; with the changes off, a sighted player's and a newborn's drop are"
		+ " phase 3-1's -- census, lineage and behaviour lines %s -- and with them on the first is"
		+ " %s") % [changed, kinds, "the same" if behaviours[0] == behaviours[1]
		and behaviours[0] == behaviours[2] else "DIFFERENT",
		"the same to the byte" if differ == 0 else "%d DIFFER" % differ,
		"3-1's -- THE SWITCH DOES NOTHING" if lines[0] == THREE_ONE_LINES[0] else "not 3-1's"],
		behaviours[0] == behaviours[1] and behaviours[0] == behaviours[2]
		and changed.is_valid_int() and int(changed) > 0 and differ == 0 and off.size() == 6
		and lines[0] != THREE_ONE_LINES[0])
	var sums := PackedStringArray()
	for line in lines:
		sums.append(line.get_slice("| sum ", 1))
	var divided := families[0].get_slice("| ", 2).get_slice(" (", 0)
	_check(("8. and lineage 7. determinism: one seed, forty seconds of a sighted player's drop"
		+ " with births, twice and with the near-first search off: census checksums %s, the"
		+ " census lines %s and the lineage lines %s, with %s") % [", ".join(sums),
		"the same" if lines[0] == lines[1] and lines[0] == lines[2] else "DIFFERENT",
		"the same" if families[0] == families[1] and families[0] == families[2]
		else "DIFFERENT", divided],
		lines[0] == lines[1] and lines[0] == lines[2] and lines[0].contains("living")
		and families[0] == families[1] and families[0] == families[2]
		and divided.begins_with("divisions ") and divided != "divisions 0")


## **Phase 3-1's forty seconds** (behaviour.md §12.3 check 6): the census,
## lineage and behaviour lines of [method _determinism]'s scenario -- seed 8088,
## forty seconds, a sighted player's drop and then a newborn's -- as phase 3-1
## printed them on `dev` at 93c61b4, the same as `--rule-change=0` prints them,
## in this project's container (Godot 4.7.2, x86-64), which is what CI runs on.
## **A change to the water made on purpose changes them**: re-record them then
## from the check's own output, and say so in the commit.
const THREE_ONE_LINES: Array[String] = [
	"[census] t 40  living 550 (drifters 354, hunters 196)  flocs 105  | hunters at r40 0, mean r 29.2, hunger 0.52  | could swallow r26/r34/r40 103/41/16  dread 1.63/0.63/0.25  genes 16  | spawned 838  died: swallowed 230 chewed 0 starved 92 (r40 0) poisoned 0  | grazed by the water 14, by drifters 3, dissolved 0, snow kept 0, remains 92  | runs 0 at you 0 misses 0 darts 1 dashes 0  floors: gene 0+0 drifter 0  | sum 1986045848",
	"[lineage] t 40  hunters 196, born 44  generation mean 1.23 max 3  families 181 (largest 2)  dna apart 75  | cruise 68.2 notice 755 mouth 1.51 upkeep 1.28 genes worn 4.32 carried 4.69  tails 182 sighted 196 at r40 0  | divisions 34 (trade 17 drift 17 faithfully 0), daughters 68: tailless 19, given a sense 14  | the spawner's peers 128 (for the floor 128, for venom 0), drifters 155, left to births 0  | worn cyto 1.51 cirr 1.28 flag 1.35 stig 0.32 ocel 0.29 chem 0.23 ampu 0.35 axon 0.07 palp 0.05 myon 0.08 tric 0.08 pell 0.14 vene 0.11 plas 0.02 vacu 0.03 cris 0.06  | commonest 16x cytostome:1,cirrus:1,flagellum:1,ampulla:1 ; 12x cytostome:1,cirrus:1,flagellum:1,ocellus:1 ; 8x cytostome:1,cirrus:1,flagellum:1,stigma:1",
	"[behaviour] t 40  hunters 196: on the founders' rules 196, other lists 0  | founders' rules fired 6983/15402/739/738/3020/35892/854  | meals of hunters with a nose 49, radar 91, laser 66  | water darts 1, stuns 1, your wakes 0  | now holding a heading 76, resting 73, swimming 123, pushing 3, stunned 0, echoes in flight 106",
	"[census] t 40  living 550 (drifters 458, hunters 92)  flocs 73  | hunters at r40 0, mean r 30.5, hunger 0.50  | could swallow r26/r34/r40 49/4/1  dread 0.50/0.04/0.00  genes 16  | spawned 716  died: swallowed 129 chewed 0 starved 48 (r40 0) poisoned 0  | grazed by the water 7, by drifters 0, dissolved 0, snow kept 2, remains 48  | runs 0 at you 0 misses 0 darts 2 dashes 0  floors: gene 0+0 drifter 0  | sum 1742291140",
	"[lineage] t 40  hunters 92, born 18  generation mean 1.20 max 2  families 85 (largest 2)  dna apart 48  | cruise 62.5 notice 800 mouth 1.24 upkeep 1.13 genes worn 4.27 carried 4.71  tails 89 sighted 92 at r40 0  | divisions 11 (trade 6 drift 5 faithfully 0), daughters 22: tailless 5, given a sense 3  | the spawner's peers 34 (for the floor 34, for venom 0), drifters 127, left to births 0  | worn cyto 1.24 cirr 1.13 flag 1.21 stig 0.20 ocel 0.34 chem 0.32 ampu 0.29 axon 0.01 palp 0.03 myon 0.04 tric 0.02 pell 0.03 vene 0.04 plas 0.01 vacu 0.10 cris 0.04  | commonest 11x cytostome:1,cirrus:1,flagellum:1,ampulla:1 ; 10x cytostome:1,cirrus:1,flagellum:1,chemocyte:1 ; 7x cytostome:1,cirrus:1,flagellum:1,ocellus:1",
	"[behaviour] t 40  hunters 92: on the founders' rules 92, other lists 0  | founders' rules fired 4086/7534/395/487/2144/18642/390  | meals of hunters with a nose 36, radar 48, laser 43  | water darts 2, stuns 2, your wakes 0  | now holding a heading 37, resting 37, swimming 55, pushing 1, stunned 0, echoes in flight 51",
]
## What phase 3-2's behaviour line adds after phase 3-1's, for a water whose
## rules never changed: one behaviour, every hunter on it, no change made.
const UNCHANGED_TAIL := "  | behaviours 1, unchanged 100.0 %  | rules changed 0: nudge 0, replace 0, swap 0, copy 0, drop 0"


# --- 9. Flocs ---------------------------------------------------------------------------------

## **None edible before it has settled** (§7.2): a floc landing in the player's
## mouth is taken the frame it has settled and not before, and one held in a
## resting hunter's mouth too -- and that hunter's graze fed it and grew nothing
## (§7.3). **Remains** (§7.4) lie where a body died of hunger and of poison, and
## nowhere a body was swallowed or chewed.
func _flocs() -> void:
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var cells: Array = field.get("_cells")
	cell.heading = 0.0
	field.in_water = true
	var got := [-1.0, 0.0, -1.0]
	field.grazed.connect(func(nutrition: float, _at: Vector2) -> void:
		if got[0] < 0.0:
			got[0] = float(field.get("_t"))
			got[1] = nutrition)
	var in_mouth := cell.position + Vector2(0.0, -(cell.radius + 6.0))
	var touching := Cilia.mouth_touches(cell.position, cell.heading, cell.radius, cell.gape(),
		in_mouth, 9.0)
	field._spawn_floc(in_mouth, 9.0, false)
	# A resting hunter 600 off, well inside the view's every-frame reach, a floc
	# landing where its mouth is: held there, as its mouth drifts.
	var hunter := _pose(field, cell.position + Vector2(600.0, 0.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"chemocyte": 1}, PI * 0.5, 0.6)
	var hb: Object = cells[hunter]
	var genes_before := (hb.get("genome") as Dictionary).duplicate()
	var r_before := float(hb.get("radius"))
	var held := field._spawn_floc(Vector2.ZERO, 9.0, false)
	var held_serial := int((cells[held] as Object).get("serial"))
	var hunger_before := 0.0
	for f in 8 * 60:
		if got[2] < 0.0:
			var h_at: Vector2 = hb.get("pos")
			var ahead := Vector2(sin(float(hb.get("heading"))), -cos(float(hb.get("heading"))))
			(cells[held] as Object).set("pos", h_at + ahead * (float(hb.get("radius")) + 6.0))
			field.refile(held)
			hunger_before = float(hb.get("hunger"))
		field._process(1.0 / 60.0)
		if got[2] < 0.0 and (not (cells[held] as Object).get("seeded")
				or int((cells[held] as Object).get("serial")) != held_serial):
			got[2] = float(field.get("_t"))
		if got[0] >= 0.0 and got[2] >= 0.0:
			break
	var hunger_after := float(hb.get("hunger"))
	var fed: bool = hunger_after < hunger_before - 0.2 and float(hb.get("radius")) == r_before \
		and hb.get("genome") == genes_before
	# Remains: a hunter starving out its grace, a biter poisoned by what it bit,
	# a prey swallowed and a prey chewed apart -- each posed in the clear.
	var p := cell.position
	var starving := _pose(field, p + Vector2(-800.0, 400.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, 0.0, 1.0)
	(cells[starving] as Object).set("starve", Metabolism.STARVE_GRACE - 1e-4)
	var starved_at: Vector2 = (cells[starving] as Object).get("pos")
	field._tank(starving, cells[starving], 1.0 / 60.0)
	var biter := _pose(field, p + Vector2(-800.0, -400.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var bitten := _pose(field, p + Vector2(-800.0, -350.0), 40.0,
		{&"cytostome": 1, &"veneneux": 3})
	(cells[biter] as Object).set("wound", 0.99)
	var poisoned_at: Vector2 = (cells[biter] as Object).get("pos")
	field._mouth_on_drop(biter, cells[biter], bitten, cells[bitten],
		field._gape(cells[biter]))
	var swallower := _pose(field, p + Vector2(800.0, 900.0), 40.0,
		{&"cytostome": 3, &"cirrus": 1, &"flagellum": 1})
	var swallowed := _pose(field, p + Vector2(800.0, 960.0), 18.0, {&"cirrus": 1})
	var swallowed_at: Vector2 = (cells[swallowed] as Object).get("pos")
	field._mouth_on_drop(swallower, cells[swallower], swallowed, cells[swallowed],
		field._gape(cells[swallower]))
	var chewer := _pose(field, p + Vector2(-400.0, 1200.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1})
	var chewed := _pose(field, p + Vector2(-400.0, 1250.0), 40.0,
		{&"cytostome": 1, &"cirrus": 1})
	(cells[chewed] as Object).set("wound", 0.99)
	var chewed_at: Vector2 = (cells[chewed] as Object).get("pos")
	field._mouth_on_drop(chewer, cells[chewer], chewed, cells[chewed],
		field._gape(cells[chewer]))
	var remains := [_flocs_at(field, starved_at).size(), _flocs_at(field, poisoned_at).size(),
		_flocs_at(field, swallowed_at).size(), _flocs_at(field, chewed_at).size()]
	var sizes := []
	for at: Vector2 in [starved_at, poisoned_at]:
		var found := _flocs_at(field, at)
		sizes.append(float(found[0].get("radius")) if not found.is_empty() else -1.0)
	_check(("9. flocs: one landing in the player's mouth is taken at %.2f s, once settled"
		+ " (FLOC_SETTLE %.0f; the mouth on it %s), worth %.2f; one held in a resting"
		+ " hunter's at %.2f s, its hunger %.2f -> %.2f and its r%.0f and genes as they"
		+ " were (%s); remains where a body died of hunger (%d, r%.1f) and of poison (%d,"
		+ " r%.1f), none where one was swallowed (%d) or chewed (%d)") % [got[0],
		Drop.FLOC_SETTLE, "yes" if touching else "NO", got[1], got[2], hunger_before,
		hunger_after, r_before, "yes" if fed else "NO", remains[0], sizes[0], remains[1],
		sizes[1], remains[2], remains[3]],
		touching and got[0] >= Drop.FLOC_SETTLE - 1e-3 and got[0] < Drop.FLOC_SETTLE + 0.1
		and got[2] >= Drop.FLOC_SETTLE - 1e-3 and got[2] < Drop.FLOC_SETTLE + 0.2
		and absf(got[1] - FoodField._meal_value_for(9.0, cell.radius)) < 1e-6 and fed
		and remains == [1, 1, 0, 0]
		and is_equal_approx(sizes[0], Drop.remains_radius(30.0))
		and is_equal_approx(sizes[1], Drop.remains_radius(30.0)))
	_done(water)


## **A graze feeds and grows nothing**, on the run's own handler (§7.3): the bar
## falls by the meal every body's goes through, and the body and its genes stay
## as they were. The run is the real one, in the drop, built headless.
func _flocs_fed() -> void:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 0)
	run.set("scheme", 0)
	run.set("keep", "")
	add_child(run)
	await get_tree().process_frame
	var met: Node = run.get("_metabolism")
	var cell: CellBody = run.get("_cell")
	var genome: Node = run.get("_genome")
	var food: Node = run.get("_food")
	met.set_hunger(0.6)
	var radius := cell.radius
	var tiers: Dictionary = (genome.call(&"tiers") as Dictionary).duplicate()
	run.call(&"_on_grazed", 0.4, cell.position + Vector2(0.0, -40.0))
	var after := float(met.get("hunger"))
	_check(("9. a graze on the run's own handler, in the drop (%s): the bar %.2f -> %.3f"
		+ " (a meal of 0.40 is %.3f), r%.0f -> r%.0f, genes %s") % [
		"yes" if food.call(&"in_drop") else "NO", 0.6, after, Metabolism.meal(0.4), radius,
		cell.radius, "as they were" if genome.call(&"tiers") == tiers else "CHANGED"],
		bool(food.call(&"in_drop")) and absf(after - (0.6 - Metabolism.meal(0.4))) < 1e-6
		and cell.radius == radius and genome.call(&"tiers") == tiers)
	run.queue_free()
	await get_tree().process_frame


# --- 11. One body, posed ---------------------------------------------------------------------

## **One mouth rule for every body** (§5.6, §5.7), each on bodies posed in the
## clear: a mouth swallows a player that fits on contact, hunting or not (row
## 15), and is fed by it; `pellicle` makes a body too big for a mouth it would
## otherwise fit (row 5); venom as today (row 12) -- whatever swallows a venomous
## player dies of it and leaves remains, and a player swallows a venomous cell
## safely; a water cell's dart breaks a run at it; and the taste field and the
## bloom weigh a body by the size its mouth measures.
func _one_body() -> void:
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var cells: Array = field.get("_cells")
	cell.heading = 0.0
	field.in_water = true
	var p := cell.position
	var said := {"killed": 0, "stung": 0, "ate": 0}
	field.killed.connect(func(_b: float) -> void: said["killed"] += 1)
	field.stung.connect(func(_b: float) -> void: said["stung"] += 1)
	field.eaten.connect(func(_n: float, _g: StringName, _a: Vector2) -> void: said["ate"] += 1)
	var big := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1}
	# Row 15: a resting r40 mouth, not hunting anyone, its mouth on the player.
	var at := p + Vector2(0.0, -(40.0 + cell.radius) * 0.95)
	var h := _pose(field, at, 40.0, big, _facing(at, p), 0.5)
	var hb: Object = cells[h]
	var mouth_on := Cilia.mouth_touches(at, hb.get("heading"), 40.0, field._gape(hb), p,
		cell.radius)
	field.set("_near", field.bodies_near(p, 2500.0))
	var dead: bool = field._contacts_with(null)
	var swallow := [dead, said["killed"], int(field.get("died_of")) == FoodField.Cause.SWALLOWED,
		float(hb.get("hunger")) < 0.5, int(hb.get("meals")) == 1, float(hb.get("calm")),
		int(hb.get("state")) == FoodField.State.DRIFT]
	# The switch the other way: only a run swallows, so this one only bites.
	field.contact_swallow = false
	var h2 := _pose(field, at + Vector2(0.1, 0.0), 40.0, big, _facing(at, p), 0.5)
	(cells[h] as Object).set("pos", p + Vector2(3000.0, 0.0))
	field.refile(h)
	field.set("_near", field.bodies_near(p, 2500.0))
	var spared: bool = not field._contacts_with(null) and said["killed"] == 1
	field.contact_swallow = true
	cell.wound = 0.0
	(cells[h2] as Object).set("pos", p + Vector2(3000.0, 300.0))
	field.refile(h2)
	# Row 12: a venomous player is spat out alive; what swallowed it dies of it.
	field.venom_cost = CellBody.VENOM_COST_BY_TIER[3]
	var v := _pose(field, at, 40.0, big, _facing(at, p), 0.5)
	var v_at: Vector2 = (cells[v] as Object).get("pos")
	field.set("_near", field.bodies_near(p, 2500.0))
	var stung_dead: bool = field._contacts_with(null)
	var venom_out := [stung_dead, said["stung"], said["killed"],
		not (cells[v] as Object).get("seeded") or (cells[v] as Object).get("inert"),
		_flocs_at(field, v_at).size()]
	field.venom_cost = -1.0
	# And a player swallows a venomous water cell safely: an r15 one in its mouth.
	var small_at := p + Vector2(0.0, -(cell.radius + 12.0))
	var s := _pose(field, small_at, 15.0, {&"cytostome": 1, &"veneneux": 3}, PI, 0.5)
	field.set("_near", field.bodies_near(p, 2500.0))
	var safe: bool = not field._contacts_with(null)
	var venom_in := [safe, said["ate"], said["killed"], not (cells[s] as Object).get("seeded")]
	# Row 5: `pellicle` on a water body puts it past a mouth its bare radius fits.
	var mouth := _pose(field, p + Vector2(-900.0, 0.0), 30.0,
		{&"cytostome": 2, &"cirrus": 1, &"flagellum": 1})
	var mb: Object = cells[mouth]
	var gape: float = field._gape(mb)
	var armoured := _pose(field, p + Vector2(-900.0, -60.0), 24.0,
		{&"cirrus": 1, &"pellicle": 3})
	var bare := _pose(field, p + Vector2(-900.0, 60.0), 24.0, {&"cirrus": 1})
	field._mouth_on_drop(mouth, mb, armoured, cells[armoured], gape)
	(mb as Object).set("bite", 0.0)
	var kept := bool((cells[armoured] as Object).get("seeded")) \
		and float((cells[armoured] as Object).get("wound")) > 0.0
	field._mouth_on_drop(mouth, mb, bare, cells[bare], gape)
	var taken: bool = not (cells[bare] as Object).get("seeded")
	# The dart: a hunter stalking a cell whose `trichocyst` looks at it, in range.
	var prey := _pose(field, p + Vector2(900.0, -900.0), 26.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"trichocyst": 1}, 0.0)
	var pb: Object = cells[prey]
	var arc := float(pb.get("heading")) + float(pb.get("dart_bearing"))
	var stalker := _pose(field, (pb.get("pos") as Vector2)
		+ Vector2(sin(arc), -cos(arc)) * 100.0, 30.0, big, 0.0)
	var sb: Object = cells[stalker]
	field._start_run(sb, prey, int(pb.get("serial")))
	sb.set("orienting", false)
	field._step_stalk(stalker, sb, 1.0 / 60.0)
	var darted := [int(sb.get("state")) == FoodField.State.DRIFT,
		is_equal_approx(float(sb.get("calm")), FoodField.REST_MISS),
		float(pb.get("dart_clock")) > 0.0]
	# The taste and the bloom, by the size the mouth measures: an r18 body 300
	# ahead, bare and then with a thick skin that puts it past a born gape.
	field.smell_range = CellBody.SMELL_RANGE_BY_TIER[1]
	field.smell_bearing = 0.0
	var tasted := []
	var bloom := []
	for skin: int in [0, 3]:
		var tiers := {&"cirrus": 1}
		if skin > 0:
			tiers[&"pellicle"] = skin
		var t := _pose(field, p + Vector2(0.0, -300.0), 18.0, tiers)
		field.set("_near", PackedInt32Array([t]))
		field._step_sense()
		tasted.append(float(field.get("taste_level")))
		bloom.append(FoodField.taste_weight(field.swallow_size_of(t), cell.gape()))
		field._drop_lose(t, 0)
	_check(("11. a mouth on the player swallows it on contact, hunting or not (touching %s,"
		+ " killed %s, swallowed %s), and is fed by it (hunger down %s, a meal %s, resting"
		+ " %.0f s, %s); with the switch off it only bites (%s)") % [str(mouth_on),
		str(swallow[0]), str(swallow[2]), str(swallow[3]), str(swallow[4]), swallow[5],
		"drifting" if swallow[6] else "NOT drifting", str(spared)],
		mouth_on and swallow[0] and swallow[1] == 1 and swallow[2] and swallow[3]
		and swallow[4] and is_equal_approx(float(swallow[5]), FoodField.REST_MEAL)
		and swallow[6] and spared)
	_check(("11. venom as today: a mouth that swallows a venomous player dies of it"
		+ " (player dead %s, stung %d, killed %d, the mouth gone %s, remains %d); a player"
		+ " swallows a venomous cell safely (dead %s, meals %d, killed %d, gone %s)") % [
		str(venom_out[0]), venom_out[1], venom_out[2], str(venom_out[3]), venom_out[4],
		str(not venom_in[0]), venom_in[1], venom_in[2], str(venom_in[3])],
		not venom_out[0] and venom_out[1] == 1 and venom_out[2] == 1 and venom_out[3]
		and venom_out[4] == 1 and venom_in[0] and venom_in[1] == 1 and venom_in[2] == 1
		and venom_in[3])
	_check(("11. pellicle: an r24 body with a tier-3 skin is chewed by a mouth of %.1f"
		+ " (%s), the same body bare is swallowed (%s); a water cell's dart breaks a run"
		+ " at it (%s); the taste %.3f bare and %.3f armoured, the bloom %.2f and %.2f")
		% [gape, str(kept), str(taken), str(darted), tasted[0], tasted[1], bloom[0],
		bloom[1]],
		kept and taken and darted == [true, true, true] and tasted[0] > 0.05
		and tasted[1] == 0.0 and bloom[0] == 1.0 and bloom[1] == 0.0)
	_done(water)


# --- 13. The replay on the drop (§11) --------------------------------------------------------

## **A run's recorder, on water stepped by hand**: a still cell, a field and
## the recorder last, as they are in a run, none of them processing on its own.
## [method _rig_step] steps the water one fixed frame and has the recorder take
## it, as the run's frame does. [param drop] false is today's water.
func _rig(drop: bool, desert := 0.0) -> Array:
	var rig := Node.new()
	rig.name = "Rig"
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	cell.process_mode = Node.PROCESS_MODE_DISABLED
	rig.add_child(cell)
	var field := WatchedDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.desert = desert
	rig.add_child(field)
	var recorder := RecorderNode.new()
	recorder.process_mode = Node.PROCESS_MODE_DISABLED
	rig.add_child(recorder)
	add_child(rig)
	if drop:
		field.setup_drop(cell)
	else:
		field.setup(cell)
	field.in_water = false
	return [rig, field, cell, recorder]


func _rig_step(rig: Array, frames: int, move := Vector2.ZERO) -> void:
	for f in frames:
		(rig[2] as CellBody).position += move
		(rig[1] as Node)._process(1.0 / 60.0)
		(rig[3] as Node)._process(1.0 / 60.0)


## Where the recorder's newest frame starts in its ring.
func _newest(recorder: Node) -> int:
	var head := int(recorder.get("_head"))
	return ((head - 1 + RecorderNode.CAPACITY) % RecorderNode.CAPACITY) * RecorderNode.STRIDE


## [param x] as the ring holds it.
func _f32(x: float) -> float:
	var one := PackedFloat32Array([x])
	return one[0]


## The replay screen over [param recorder]'s sealed ring, as the run raises it:
## a child of the run, handed the recorder before it enters the tree. Driven by
## hand from here, one seek at a time.
func _raise_replay(run: Node, recorder: Node) -> Node:
	var screen: Node = (load("res://game/replay/replay.tscn") as PackedScene).instantiate()
	screen.set(&"recorder", recorder)
	run.add_child(screen)
	screen.set_process(false)
	return screen


func _seek(screen: Node, at: float) -> void:
	screen.set(&"_at", at)
	screen.call(&"_seek")


## Every body in [param field] as a row of what the replay could have written.
func _snapshot(field: Node) -> Array:
	var out := []
	for b: Object in field.get("_cells"):
		out.append([b.get("pos"), b.get("heading"), b.get("radius"), b.get("wound"),
			(b.get("genome") as Dictionary).duplicate(), b.get("seeded"), b.get("state"),
			b.get("target"), b.get("id"), b.get("settle"), b.get("hunger")])
	return out


func _replay() -> void:
	_replay_slots()
	_replay_bubble()
	_replay_flocs()
	_replay_killer()
	await _replay_run()


## **The 48 nearest, each in a slot it keeps** (§11): a drop stepped four
## seconds with the cell crossing it, and after every frame the slots hold
## exactly the living bodies nearest the cell within the recorder's reach, at
## most 48, their places and sizes as the field had them; a body never changes
## slot while it stays among them; an empty slot is radius 0.
func _replay_slots() -> void:
	var rig := _rig(true)
	var field: WatchedDrop = rig[1]
	var cell: CellBody = rig[2]
	var rec: Node = rig[3]
	var toward: Vector2 = ((field.basin().get(&"center") as Vector2) - cell.position) \
		.normalized() * 10.0
	var before := {}
	var wrong_set := 0
	var moved := 0
	var bad := 0
	var arrivals := 0
	var filled := 0
	for f in 240:
		_rig_step(rig, 1, toward)
		var cells: Array = field.get("_cells")
		var keys := PackedInt64Array()
		for i in cells.size():
			var b: Object = cells[i]
			if not b.get("seeded") or b.get("inert"):
				continue
			var d2 := (b.get("pos") as Vector2).distance_squared_to(cell.position)
			if d2 <= RecorderNode.REACH * RecorderNode.REACH:
				keys.append((int(d2) << RecorderNode.INDEX_BITS) | i)
		keys.sort()
		var want := {}
		for k in mini(keys.size(), RecorderNode.BODIES):
			want[int((cells[int(keys[k] & RecorderNode.INDEX_MASK)] as Object).get("serial"))] = 1
		var ring: PackedFloat32Array = rec.get("_ring")
		var at := _newest(rec)
		var serials: PackedInt64Array = rec.get("_slot_serial")
		var indices: PackedInt32Array = rec.get("_slot_index")
		var now := {}
		for s in RecorderNode.BODIES:
			var o := at + RecorderNode.AT_BODIES + s * RecorderNode.BODY_FLOATS
			if serials[s] < 0:
				if ring[o + 3] != 0.0:
					bad += 1
				continue
			var b: Object = cells[indices[s]]
			var p: Vector2 = b.get("pos")
			if int(b.get("serial")) != serials[s] or ring[o] != _f32(p.x) \
					or ring[o + 1] != _f32(p.y) or ring[o + 3] != _f32(float(b.get("radius"))):
				bad += 1
			now[int(serials[s])] = s
			if before.has(int(serials[s])):
				if int(before[int(serials[s])]) != s:
					moved += 1
			else:
				arrivals += 1
		if now.size() != want.size():
			wrong_set += 1
		else:
			for serial: int in want:
				if not now.has(serial):
					wrong_set += 1
					break
		filled = now.size()
		before = now
	_check(("13. the replay's slots: after each of 240 frames of a cell crossing the drop"
		+ " the %d slots hold the living bodies nearest it (%d frames wrong), as the field"
		+ " had them (%d wrong), none changing slot while it stays among them (%d moved),"
		+ " %d arrivals in all, the last frame %d full") % [RecorderNode.BODIES, wrong_set,
		bad, moved, arrivals, filled],
		wrong_set == 0 and bad == 0 and moved == 0 and filled == RecorderNode.BODIES
		and arrivals > RecorderNode.BODIES + 20)
	(rig[0] as Node).queue_free()


## **Today's water records as it always did** (§11): the bubble a run with a
## session still plays, its 34 bodies in the slots of their own indices -- with
## the floats the field had, the hunter as its index, and the rest empty --
## through a cell crossing it fast enough that its bodies are reseeded.
func _replay_bubble() -> void:
	var rig := _rig(false)
	var field: WatchedDrop = rig[1]
	var rec: Node = rig[3]
	var cells: Array = field.get("_cells")
	var bad := 0
	var hunted := 0
	var reseeds := 0
	var last := PackedInt64Array()
	for b: Object in cells:
		last.append(int(b.get("serial")))
	for f in 240:
		(rig[2] as CellBody).position += Vector2(12.0, 0.0)
		field._process(1.0 / 60.0)
		# Something hunting the cell as the frame is taken, so the hunter's
		# float is a slot to check.
		(cells[5] as Object).set("state", FoodField.State.STALK)
		(cells[5] as Object).set("target", FoodField.TARGET_PLAYER)
		rec._process(1.0 / 60.0)
		var ring: PackedFloat32Array = rec.get("_ring")
		var at := _newest(rec)
		var indices: PackedInt32Array = rec.get("_slot_index")
		for s in RecorderNode.BODIES:
			var o := at + RecorderNode.AT_BODIES + s * RecorderNode.BODY_FLOATS
			if s >= FoodField.COUNT:
				if indices[s] >= 0 or ring[o + 3] != 0.0:
					bad += 1
				continue
			var b: Object = cells[s]
			var p: Vector2 = b.get("pos")
			# The gape as the recorder has always written it: its tier's
			# multiplier, held as a float, times the radius.
			var r := float(b.get("radius"))
			var gape := _f32(_f32(CellBody.gape_of(GenomeNode.tier_of(b.get("genome"),
				&"cytostome"), 1.0)) * r)
			if indices[s] != s or ring[o] != _f32(p.x) or ring[o + 1] != _f32(p.y) \
					or ring[o + 2] != _f32(float(b.get("heading"))) or ring[o + 3] != _f32(r) \
					or ring[o + 4] != _f32(float(b.get("wound"))) or ring[o + 5] != gape:
				bad += 1
			if int(b.get("serial")) != last[s]:
				last[s] = int(b.get("serial"))
				reseeds += 1
		var hunter := field.hunter()
		if ring[at + RecorderNode.AT_HUNTER] != float(hunter):
			bad += 1
		if hunter >= 0:
			hunted += 1
	var body_rows := 0
	var off_index := 0
	for row: Array in rec.call(&"deltas"):
		if int(row[1]) == RecorderNode.Delta.BODY:
			body_rows += 1
			if int(row[2]) >= FoodField.COUNT:
				off_index += 1
	_check(("13. today's water records as it did: 240 frames, its %d bodies in the slots"
		+ " of their own indices with the field's floats and the rest empty (%d wrong),"
		+ " the hunter's float its index on %d frames, %d reseeds, %d genome rows none past"
		+ " slot %d (%d)") % [FoodField.COUNT, bad, hunted, reseeds, body_rows,
		FoodField.COUNT - 1, off_index],
		bad == 0 and hunted == 240 and reseeds > 10
		and body_rows >= FoodField.COUNT + reseeds and off_index == 0)
	(rig[0] as Node).queue_free()


## **Flocs as SETTLE and CLEAR** (§11): a flake landing near the cell is told
## once, as it lands, with its place and radius, and once as it is eaten, and it
## settles by the time since as the field steps it; a cell starving in view is
## its slot emptying and a SETTLE where it died, already settled -- and the
## replay's own field has each floc from its SETTLE to its CLEAR, and not
## outside them.
func _replay_flocs() -> void:
	var rig := _rig(true, 3000.0)
	var field: WatchedDrop = rig[1]
	var cell: CellBody = rig[2]
	var rec: Node = rig[3]
	var cells: Array = field.get("_cells")
	var p := cell.position
	var landed := p + Vector2(300.0, 0.0)
	_rig_step(rig, 5)
	var flake := field._spawn_floc(landed, 9.0, false)
	var flake_id := int((cells[flake] as Object).get("id"))
	_rig_step(rig, 150)
	var settled := float((cells[flake] as Object).get("settle"))
	var clock := float(rec.get("_clock"))
	field._consume(flake)
	_rig_step(rig, 5)
	# A hunter starving 500 off: in a slot, then gone, and its remains where it was.
	var starving := _pose(field, p + Vector2(-500.0, 0.0), 30.0,
		{&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, 0.0, 1.0)
	_rig_step(rig, 5)
	var slot: int = (rec.get("_slot_by_index") as PackedInt32Array)[starving]
	var died_at: Vector2 = (cells[starving] as Object).get("pos")
	(cells[starving] as Object).set("starve", Metabolism.STARVE_GRACE - 1e-4)
	_rig_step(rig, 5)
	var ring: PackedFloat32Array = rec.get("_ring")
	var emptied: bool = slot >= 0 and ring[_newest(rec) + RecorderNode.AT_BODIES
		+ slot * RecorderNode.BODY_FLOATS + 3] == 0.0
	var landings := 0
	var predicted := -1.0
	var clears := 0
	var clear_t := 0.0
	var remains := 0
	var remains_id := -1
	var remains_t := 0.0
	for row: Array in rec.call(&"deltas"):
		var kind := int(row[1])
		if kind == RecorderNode.Delta.SETTLE:
			var floc: Array = row[3]
			if int(row[2]) == flake_id:
				landings += 1
				if (floc[0] as Vector2) == landed and float(floc[1]) == 9.0 \
						and float(floc[2]) < 0.01:
					predicted = FoodField.floc_settle_after(float(floc[2]), float(floc[3]),
						clock - float(row[0]))
			elif (floc[0] as Vector2) == died_at and float(floc[2]) == 1.0 \
					and is_equal_approx(float(floc[1]), Drop.remains_radius(30.0)):
				remains += 1
				remains_id = int(row[2])
				remains_t = float(row[0])
		elif kind == RecorderNode.Delta.CLEAR and int(row[2]) == flake_id:
			clears += 1
			clear_t = float(row[0])
	rec.call(&"seal")
	var screen := _raise_replay(rig[0], rec)
	var water: Node = screen.get("_food")
	var origin := float(rec.call(&"origin"))
	var seen := []
	for t: float in [clear_t - 0.5, clear_t + 0.05, remains_t - 0.05, remains_t + 0.02]:
		_seek(screen, maxf(t - origin, 0.0))
		# The two flocs this check made; the drop's own may be in reach too.
		var here := []
		var map: Dictionary = water.get("_replay_flocs")
		for id: int in [flake_id, remains_id]:
			if not map.has(id):
				continue
			var b: Object = (water.get("_cells") as Array)[int(map[id])]
			if b.get("seeded"):
				here.append([id, b.get("pos"), float(b.get("settle"))])
		seen.append(here)
	_check(("13. flocs: a flake is told once as it lands (%d) and once as it is eaten (%d),"
		+ " settled %.4f after 2.5 s against %.4f by time; a cell starving in view empties"
		+ " its slot (%s) and leaves one SETTLE where it died, settled (%d); the replay's"
		+ " own field has the flake before its CLEAR and not after (%d, %d), the remains"
		+ " not before their SETTLE and then settled where it died (%d, %d)") % [landings,
		clears, settled, predicted, str(emptied), remains, seen[0].size(), seen[1].size(),
		seen[2].size(), seen[3].size()],
		landings == 1 and clears == 1 and absf(settled - predicted) < 1e-6 and emptied
		and remains == 1 and seen[0].size() == 1 and int(seen[0][0][0]) == flake_id
		and (seen[0][0][1] as Vector2) == landed and seen[1].is_empty()
		and seen[2].is_empty() and seen[3].size() == 1 and int(seen[3][0][0]) == remains_id
		and (seen[3][0][1] as Vector2) == died_at and float(seen[3][0][2]) == 1.0)
	(rig[0] as Node).queue_free()


## **Who killed you** (§11): a resting r38 mouth, hunting nobody, half a second
## in a slot before it is put against the cell and swallows it on contact -- r38
## and not the cap, where a body divides on its next tick (pack 2). The
## ring names that slot as the killer on every frame since it took it and on none
## before, and names no hunter on any; the replay's own field answers
## `killer()` with it on those frames and -1 before them, `hunter()` -1 on all
## -- and the truth pane's predator rings go round the killer when nothing hunts.
func _replay_killer() -> void:
	var rig := _rig(true, 3000.0)
	var field: WatchedDrop = rig[1]
	var cell: CellBody = rig[2]
	var rec: Node = rig[3]
	var cells: Array = field.get("_cells")
	cell.heading = 0.0
	field.in_water = true
	# The run's order: the death seals the ring before the frame is taken.
	field.killed.connect(func(_bearing: float) -> void: rec.call(&"seal"))
	_rig_step(rig, 20)
	var p := cell.position
	var far := p + Vector2(0.0, -600.0)
	var k := _pose(field, far, 38.0, {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1},
		_facing(far, p), 0.5)
	_rig_step(rig, 30)
	var slot: int = (rec.get("_slot_by_index") as PackedInt32Array)[k]
	var at := p + Vector2(0.0, -(38.0 + cell.radius) * 0.95)
	(cells[k] as Object).set("pos", at)
	(cells[k] as Object).set("heading", _facing(at, p))
	field.refile(k)
	var tries := 0
	while bool(rec.get("_recording")) and tries < 10:
		_rig_step(rig, 1)
		tries += 1
	var ring: PackedFloat32Array = rec.get("_ring")
	var count: int = rec.call(&"frames")
	var start: int = rec.get("_start")
	var named := 0
	var wrong := 0
	for f in count:
		var o := ((start + f) % RecorderNode.CAPACITY) * RecorderNode.STRIDE
		var killer := int(ring[o + RecorderNode.AT_KILLER])
		if int(ring[o + RecorderNode.AT_HUNTER]) != -1:
			wrong += 1
		if f < 20:
			if killer != -1:
				wrong += 1
		elif killer == slot:
			named += 1
		else:
			wrong += 1
	var screen := _raise_replay(rig[0], rec)
	var water: Node = screen.get("_food")
	var vision: Node = (screen.get("_panes") as Node).get("_vision")
	var answers := []
	for f: int in [10, 30]:
		_seek(screen, float(rec.call(&"time_of", f)) + 0.001)
		answers.append([water.call(&"killer"), water.call(&"hunter"), vision.call(&"_predator")])
	_check(("13. the killer: a resting mouth swallows the cell on contact (%s, slot %d); the"
		+ " ring names it on %d frames of %d since it took its slot and wrongly on %d; the"
		+ " replay's field before it came %s, after %s (killer, hunter, the rings' body)")
		% [str(int(field.died_of) == FoodField.Cause.SWALLOWED and field.died_to == k), slot,
		named, count - 20, wrong, str(answers[0]), str(answers[1])],
		int(field.died_of) == FoodField.Cause.SWALLOWED and field.died_to == k and slot >= 0
		and named == count - 20 and count > 20 and wrong == 0
		and answers[0] == [-1, -1, -1] and answers[1] == [slot, -1, slot])
	(rig[0] as Node).queue_free()


## **The drop the player returns to is not the replay's to touch** (§11): a run
## in the drop starves, its replay is raised through the run's own button,
## played through its window twice and closed -- and every body in the run's
## field is as it was, to the bit; the replay drew from a field of its own, round
## the drop's own rim; and the cell, woken, is back in that same drop with every
## body still in it and one drifter more, its first.
func _replay_run() -> void:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 1)
	run.set("scheme", 0)
	run.set("keep", "")
	add_child(run)
	var rec: Node = run.get("_recorder")
	for f in 3000:
		await get_tree().process_frame
		if float(rec.call(&"span")) >= 2.5:
			break
	var food: Node = run.get("_food")
	var met: Node = run.get("_metabolism")
	met.call(&"set_hunger", 1.0)
	met.set("starve_seconds", Metabolism.STARVE_GRACE + 1.0)
	for f in 3:
		await get_tree().process_frame
	var dead := int(run.get("_life")) != 0
	var before := _snapshot(food)
	var ids := {}
	for b: Object in food.get("_cells"):
		if b.get("seeded"):
			ids[int(b.get("id"))] = float(b.get("radius"))
	# The collapse, skipped: the screen is offered once the run is waiting.
	run.set("_life", 2)
	run.call(&"_watch")
	var screen: Node = run.get("_replay")
	var water: Node = screen.get("_food") if screen != null else null
	for f in 20:
		await get_tree().process_frame
	var span := float(rec.call(&"span"))
	var own := water != null and water != food and bool(water.call(&"in_drop")) \
		and (water.call(&"basin").get(&"center") as Vector2) \
			== (food.call(&"basin").get(&"center") as Vector2)
	if screen != null:
		screen.set_process(false)
		for pass_ in 2:
			screen.call(&"_rewind")
			var t := 0.0
			while t < span:
				_seek(screen, t)
				t += 0.2
	run.call(&"_replay_closed")
	await get_tree().process_frame
	var intact := _snapshot(food) == before
	run.call(&"_wake_up")
	var back := {}
	for b: Object in food.get("_cells"):
		if b.get("seeded"):
			back[int(b.get("id"))] = float(b.get("radius"))
	var kept := 0
	for id: int in ids:
		if back.has(id) and float(back[id]) == float(ids[id]):
			kept += 1
	_check(("13. the drop after a replay: the run died (%s), watched %.1f s of it on a field"
		+ " of its own round the drop's rim (%s), and closed it -- the run's %d bodies as they"
		+ " were (%s); woken, back in the drop (%s) with %d of its %d bodies and %d more")
		% [str(dead), span, str(own), before.size(), str(intact),
		str(food.call(&"in_drop")), kept, ids.size(), back.size() - ids.size()],
		dead and span > 2.0 and own and intact and bool(food.call(&"in_drop"))
		and kept == ids.size() and back.size() == ids.size() + 1)
	run.queue_free()
	# A run, its replay and a ring freed: let that settle before the next check
	# times frames.
	for f in 10:
		await get_tree().process_frame


# --- 12. The save (§9, §14.3): 1b-1's four, and the room's (1b-2) --------------------------

## **Where these checks keep a drop**: a file of their own, never the player's.
const KEEP := "user://drop_probe/drop.save"

## **Every field of a body §9.2 names**, read off the body itself -- not off
## what the save gathered, so a field the save forgot fails here -- and what
## its genome buys, which a load re-derives rather than reads.
const KEPT_FIELDS: Array[String] = ["seeded", "id", "parent", "drifter", "inert", "meals",
	"pos", "heading", "radius", "wound", "age", "last_t", "hunger", "starve", "effort",
	"bite", "dart_clock", "dash_clock", "dash_v", "settle", "life", "genome"]
const DERIVED_FIELDS: Array[String] = ["upkeep", "reserve", "income", "burn", "armour",
	"tox", "cruise", "notice", "notice_floc", "see_big", "dart_bearing", "tail", "turn_rate",
	"thrust", "dart_tier", "worn"]
## **What a body on rules is doing** (pack 3, behaviour.md §8), read off the body
## as [constant KEPT_FIELDS] are; its list is compared by its lines.
const BEHAVIOUR_FIELDS: Array[String] = ["steer", "holding", "resting", "swimming", "push",
	"tumble", "tumble_tick", "stun", "ate_at", "hit", "hit_from", "call_at", "echoes", "memory"]


## Each check begins with nothing kept, and nothing is left kept after them.
func _save() -> void:
	for check: Callable in [_save_bodies, _save_run, _save_format, _save_rules, _save_room,
			_save_lineage, _save_cell_lineage, _save_behaviour]:
		_forget_kept()
		await check.call()
	_forget_kept()


## **Save, load, the same bodies to the bit** (§14.3 check 12), and **an unknown
## gene survives**: twenty seconds of a drop, a body posed in it mid-everything
## -- wounded, its mouth, dart and dash on their clocks, a dash still carrying
## it, effort unpaid, empty and starving, carrying a gene this build does not
## know -- through the file's whole path, and loaded into a field of its own.
## Every slot, every field §9.2 names and what its genome buys, to the bit by
## their bytes; the free slots in their order, and the drop's clocks.
func _save_bodies() -> void:
	var water := _water(0.0, 0.6)
	var field: WatchedDrop = water[0]
	for f in 20 * 60:
		field._process(1.0 / 60.0)
	var at: Vector2 = field.basin().get(&"center") + Vector2(900.0, 0.0)
	var posed := _pose(field, at, 30.0, {&"cytostome": 2, &"rhabdom": 2, &"myoneme": 1})
	var b: Object = (field.get("_cells") as Array)[posed]
	for value: Array in [["wound", 0.3], ["bite", 0.4], ["dart_clock", 3.5],
			["dash_clock", 0.7], ["dash_v", 120.0], ["effort", 0.25], ["hunger", 1.0],
			["starve", 2.5], ["meals", 3], ["parent", 17]]:
		b.set(value[0], value[1])
	# And on rules (pack 3): a heading held, a swim and a push, a random turn, a
	# stun, a meal three seconds ago, a hit not yet felt, a call due, an echo in
	# flight and what its rules last read -- on a list with a name this build
	# does not know.
	var t := float(field.get("_t"))
	for value: Array in [["steer", 1.25], ["holding", true], ["swimming", true], ["push", 0.5],
			["tumble", 4], ["tumble_tick", 77], ["stun", 2.5], ["ate_at", t - 3.25],
			["hit", 0.5], ["hit_from", -2.0], ["call_at", t + 4.0],
			["echoes", [[t + 0.5, Vector2(10.5, -3.25), 120.0, 14.0, t + 0.7]]],
			["memory", {&"chemocyte.smell": [41, [[0.25]]],
				&"ocellus.beam": [41, [[0.3, 220.0, 1.2], [-0.2, 480.0, 0.7]]]}]]:
		b.set(value[0], value[1])
	b.set("brain", _list(["kinety.tingle below 0.5 -> body.rest", "always -> body.swim"]))
	var wrote := DropSave.write(KEEP, DropSave.compose(field.drop_state(), {}))
	var tmp_left := FileAccess.file_exists(KEEP.get_basename() + ".tmp")
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	var field2 := WatchedDrop.new()
	field2.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(field2)
	var done: Dictionary = field2.load_drop(cell2, back["drop"]) if not back.is_empty() else {}
	var ours: Array = field.get("_cells")
	var theirs: Array = field2.get("_cells")
	# A slot nobody is in keeps whatever its last body left in it, and is only
	# ever asked whether it is empty.
	var differ := 0
	for i in mini(ours.size(), theirs.size()):
		var seeded := bool(ours[i].get("seeded"))
		if seeded != bool(theirs[i].get("seeded")):
			differ += 1
		elif seeded and (var_to_bytes(_row(ours[i], KEPT_FIELDS))
				!= var_to_bytes(_row(theirs[i], KEPT_FIELDS))
				or var_to_bytes(_row(ours[i], DERIVED_FIELDS))
				!= var_to_bytes(_row(theirs[i], DERIVED_FIELDS))
				or var_to_bytes(_row(ours[i], BEHAVIOUR_FIELDS))
				!= var_to_bytes(_row(theirs[i], BEHAVIOUR_FIELDS))
				or _lines(ours[i]) != _lines(theirs[i])):
			differ += 1
	var drop := ["_t", "_frame", "_next_id", "_free", "_eco_clock", "_gene_clock",
		"_floor_clock", "_shore_clock", "_living", "_drifters", "_flocs", "drop_seed"]
	var same_drop := var_to_bytes(_row(field, drop)) == var_to_bytes(_row(field2, drop)) \
		and var_to_bytes(field.basin().get(&"center")) == var_to_bytes(field2.basin().get(&"center"))
	var kept_gene := posed < theirs.size() and bool(theirs[posed].get("seeded")) \
		and int((theirs[posed].get("genome") as Dictionary).get(&"rhabdom", 0)) == 2
	var bytes := FileAccess.get_file_as_bytes(KEEP).size()
	_check(("12. save and load: %d slots, %d bodies written (%s, %d B on disk, no .tmp left:"
		+ " %s) and loaded into a field of their own -- %d slots differ in any field §9.2"
		+ " names or anything its genome buys, or in its rules and what they had it doing"
		+ " (pack 3), to the bit; the drop's clocks, free slots and"
		+ " counts %s; a gene this build does not know, rhabdom:2, %s") % [ours.size(),
		int(done.get("bodies", 0)), error_string(wrote), bytes, str(not tmp_left), differ,
		"the same" if same_drop else "DIFFERENT", "kept" if kept_gene else "LOST"],
		wrote == OK and not tmp_left and not back.is_empty() and ours.size() == theirs.size()
		and differ == 0 and same_drop and kept_gene and int(done.get("bodies", 0)) > 500)
	# A drop that came out of a file goes on as a drop.
	field2.in_water = false
	for f in 120:
		field2._process(1.0 / 60.0)
	field2.queue_free()
	cell2.free()
	_done(water)


## **A room kept and loaded goes on as one that never stopped** (§14.3 check 12,
## the room's case; §10.3): the server's room made anew and left to live with
## nobody in it -- every body on its tick -- for forty seconds, then kept through
## the file's whole path and loaded into a room of its own. From there both live
## thirty seconds more on the same random stream, and their census lines must
## match to the byte: the same population, the same deaths and meals, and the
## same sum of every body's place, size and tank. Whatever the file forgot that
## the drop reads -- a chase, a clock, the grid's order, the floor's short genes
## -- moves the second one off the first. **And now dividing** (lineage.md §11.3
## check 8): the room divides through those thirty seconds, and the two lineage
## lines match as well -- every grace, DNA and record the file kept. **And on
## rules that change** (behaviour.md §12.3 check 7, phase 3-2): the lists its
## families carried when it was kept come back by name, its divisions go on
## changing them, and the two behaviour lines match too.
func _save_room() -> void:
	seed(20261001)
	var cell := CellBody.new()
	var room := WatchedDrop.new()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(room)
	room.open_dedicated(cell)
	for f in 40 * 60:
		room._process(1.0 / 60.0)
	# On rules (pack 3) nothing is on a run: what its bodies were doing is the
	# heading each held and the echoes each had in flight.
	var holding := 0
	var echoes := 0
	for b: Object in room.get("_cells"):
		if b.get("seeded"):
			holding += 1 if b.get("holding") else 0
			echoes += (b.get("echoes") as Array).size()
	var wrote := DropSave.write(KEEP, DropSave.compose(room.drop_state(), {}))
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	var room2 := WatchedDrop.new()
	room2.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(room2)
	var done: Dictionary = room2.open_dedicated(cell2, back["drop"]) if not back.is_empty() \
		else {}
	var divided_before := room.divisions
	var kept_lists := (room.drop_state()["behaviours"]["lists"] as Array).size()
	var changed_before := _changes_made(room)
	seed(4242)
	for f in 30 * 60:
		room._process(1.0 / 60.0)
	var ours: String = room.census_line()
	var our_line: String = room.lineage_line()
	var our_rules: String = room.behaviour_line()
	seed(4242)
	for f in 30 * 60:
		room2._process(1.0 / 60.0)
	var theirs: String = room2.census_line()
	var their_line: String = room2.lineage_line()
	var their_rules: String = room2.behaviour_line()
	var age := room2.drop_age()
	var changed := _changes_made(room) - changed_before
	_check(("12. and lineage 8. and 7. a room kept and loaded (%s, %d bodies, on rules, %d of"
		+ " them holding a heading, %d echoes in flight and %d lists of rules as it was kept)"
		+ " goes on as one that never stopped: after 30 s more on the same stream,"
		+ " %d divisions and %d changes of rules in them, the two census lines are %s, the"
		+ " lineage lines %s and the behaviour lines %s -- %s")
		% [error_string(wrote), int(done.get("bodies", 0)), holding, echoes, kept_lists,
		room.divisions - divided_before, changed, "the same" if ours == theirs else "DIFFERENT",
		"the same" if our_line == their_line else "DIFFERENT",
		"the same" if our_rules == their_rules else "DIFFERENT", ours if ours == theirs
			else ours + " AGAINST " + theirs],
		wrote == OK and not back.is_empty() and holding > 0 and echoes > 0 and ours == theirs
		and our_line == their_line and our_rules == their_rules and kept_lists > 0
		and changed > 0 and room.divisions - divided_before > 0
		and room2.divisions == room.divisions - divided_before
		and is_equal_approx(age, 70.0) and int(done.get("bodies", 0)) > 500)
	if our_line != their_line:
		print("[drop-probe] lineage 8, the room: %s AGAINST %s" % [our_line, their_line])
	if our_rules != their_rules:
		print("[drop-probe] check 7, the room: %s AGAINST %s" % [our_rules, their_rules])
	room.queue_free()
	room2.queue_free()
	cell.free()
	cell2.free()


## **Your cell, kept** (row 17): a run with nothing kept opens on a new drop;
## played, and left mid-run -- the app paused, as a phone pauses it -- it keeps
## the drop and the cell; and the next run opens on that drop to the bit, with
## that cell in it where it was, its size, both registers by name with a gene
## this build does not know and a waiting gene on its clock, its tank, its
## generation, its grace -- behind the beat, and with nothing in its replay. And
## the two daughters it had been offered are the two its next pinch offers.
func _save_run() -> void:
	var run := _kept_run()
	var food: Node = run.get("_food")
	var fresh: bool = not bool(run.get("_resumed")) and float(food.call(&"drop_age")) == 0.0 \
		and bool(food.call(&"in_drop"))
	for f in 90:
		await get_tree().process_frame
	var cell: CellBody = run.get("_cell")
	var genome: Node = run.get("_genome")
	var met: Node = run.get("_metabolism")
	cell.radius = 34.0
	genome.call(&"express", {&"cytostome": 2, &"cirrus": 1, &"flagellum": 1, &"rhabdom": 1},
		[&"cytostome", &"cirrus", &"flagellum", &"rhabdom"])
	genome.call(&"integrate", &"stigma")
	genome.set(&"held_remaining", 20.5)
	met.call(&"set_hunger", 0.4)
	run.set("_generation", 3)
	run.set("_parent", 4242)
	run.set("_lineage", 77)
	var pair: Array = run.call(&"_make_daughters")
	run.set("_daughters", pair)
	var was := _kept_cell(run)
	var drop_was: Dictionary = food.call(&"drop_state")
	var age := float(food.call(&"drop_age"))
	run.notification(NOTIFICATION_APPLICATION_PAUSED)
	var kept := FileAccess.file_exists(KEEP)
	run.queue_free()
	await get_tree().process_frame
	var again := _kept_run()
	var food2: Node = again.get("_food")
	var resumed := bool(again.get("_resumed"))
	var same_cell := var_to_bytes(_kept_cell(again)) == var_to_bytes(was)
	var same_drop := var_to_bytes(food2.call(&"drop_state")) == var_to_bytes(drop_was)
	var genome2: Node = again.get("_genome")
	var beat := float(again.get("_water_beat")) >= 0.0
	var ring := float((again.get("_recorder") as Node).call(&"span"))
	var same_pair := _same_pair(again.call(&"_kept_pair"), pair)
	_check(("12. your cell, kept: a run with nothing kept opens on a new drop (%s); left mid-run"
		+ " at %.1f s by the app pausing, it kept the drop (%s); the next opens on it resumed"
		+ " (%s), the drop %s to the bit, the cell -- r%.0f, dna %s, waiting %s, hunger %.2f,"
		+ " generation %d -- %s; behind the beat (%s), its replay %.1f s long; the daughters"
		+ " it was offered offered again at the pinch (%s)") % [str(fresh),
		age, str(kept), str(resumed), "the same" if same_drop else "DIFFERENT",
		(again.get("_cell") as CellBody).radius, genome2.call(&"layout"),
		genome2.call(&"waiting"), float((again.get("_metabolism") as Node).get("hunger")),
		int(again.get("_generation")), "as it was" if same_cell else "CHANGED", str(beat), ring,
		str(same_pair)],
		fresh and kept and resumed and same_drop and same_cell and beat and ring == 0.0
		and int((genome2.call(&"dna") as Dictionary).get(&"rhabdom", 0)) == 1 and same_pair)
	again.queue_free()
	await get_tree().process_frame


## **A format this build does not know starts fresh and keeps the old file**
## (§9.4): the file is not read but moved aside whole as `.old`, and the run
## opens on a new drop, which its next save point keeps in its place -- the old
## file still beside it, as it was: kept once, and not read again.
func _save_format() -> void:
	var water := _water()
	var later := DropSave.compose(water[0].call(&"drop_state"), {})
	later["format"] = DropSave.FORMAT + 1
	_done(water)
	var wrote := DropSave.write(KEEP, later)
	var old_bytes := FileAccess.get_file_as_bytes(KEEP)
	var run := _kept_run()
	var food: Node = run.get("_food")
	var fresh: bool = not bool(run.get("_resumed")) and float(food.call(&"drop_age")) == 0.0 \
		and bool(food.call(&"in_drop"))
	var moved := not FileAccess.file_exists(KEEP) \
		and FileAccess.get_file_as_bytes(KEEP + ".old") == old_bytes
	run.notification(NOTIFICATION_APPLICATION_PAUSED)
	var readable := not DropSave.read(KEEP).is_empty()
	var once := FileAccess.get_file_as_bytes(KEEP + ".old") == old_bytes
	_check(("12. an unknown format: a file of format %d (%s) is not read -- moved aside as .old"
		+ " whole (%s) -- and the run opens on a new drop (%s), which leaving keeps in its"
		+ " place (%s), the old file still beside it as it was (%s)") % [DropSave.FORMAT + 1,
		error_string(wrote), str(moved), str(fresh), str(readable), str(once)],
		wrote == OK and moved and fresh and readable and once and not old_bytes.is_empty())
	run.queue_free()
	await get_tree().process_frame


## **A changed `rules` re-derives and logs** (§9.4): a drop written under another
## fingerprint, with a body grown past this build's cap and one past its rim --
## as a content pack that lowered the cap or shrank the drop would leave it --
## loads whole: every body re-derived from its genome by name by this build's
## tables, the big one trimmed to the cap, the far one put back inside, the
## tanks kept as the share they were; and the log says it was converted, where a
## load under the same rules says nothing of the kind. **And the fingerprint is
## the same in every process**: its tables are listed by name, as Strings --
## sorted as the StringNames they are, they came out in memory's order, which
## moved from one process to the next.
func _save_rules() -> void:
	var names := PackedStringArray()
	for line: String in DropSave.rules_text().split("\n"):
		var name := line.get_slice("=", 0)
		if name.ends_with("_BY_TIER"):
			names.append(name)
	var by_name := names.duplicate()
	by_name.sort()
	var water := _water(0.0, 0.6)
	var field: WatchedDrop = water[0]
	for f in 5 * 60:
		field._process(1.0 / 60.0)
	var data := DropSave.compose(field.drop_state(), {})
	var calm := DropSave.note(data, {"bodies": 1})
	data["rules"] = "0".repeat(64)
	var rows: Dictionary = data["drop"]["bodies"]
	var kinds: PackedByteArray = rows["kind"]
	var big := -1
	var far := -1
	for k in kinds.size():
		if kinds[k] == 0 and big < 0:
			big = k
		elif kinds[k] == 1 and far < 0:
			far = k
	var radius: PackedFloat64Array = rows["radius"]
	radius[big] = CellBody.DIVIDE_RADIUS + 6.0
	rows["radius"] = radius
	var at: PackedVector2Array = rows["at"]
	at[far] = field.basin().get(&"center") + Vector2(Drop.RADIUS + 400.0, 0.0)
	rows["at"] = at
	var hunger: PackedFloat64Array = rows["hunger"]
	hunger[big] = 0.625
	rows["hunger"] = hunger
	_done(water)
	DropSave.write(KEEP, data)
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	var field2 := WatchedDrop.new()
	field2.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(field2)
	var done: Dictionary = field2.load_drop(cell2, back["drop"]) if not back.is_empty() else {}
	var line := DropSave.note(back, done) if not back.is_empty() else ""
	print(line)
	var cells: Array = field2.get("_cells")
	var slots: PackedInt32Array = rows["slot"]
	var b: Object = cells[slots[big]]
	var f: Object = cells[slots[far]]
	var g: Dictionary = b.get("genome")
	var derived := is_equal_approx(float(b.get("upkeep")), GenomeNode.upkeep_of(g)) \
		and float(b.get("cruise")) == CellBody.swim_speed_of(
			GenomeNode.tier_of(g, &"flagellum"), GenomeNode.tier_of(g, &"axoneme")) \
		and float(b.get("cruise")) > 0.0 \
		and float(b.get("reserve")) == CellBody.STORE_BY_TIER[clampi(
			GenomeNode.tier_of(g, &"vacuole"), 0, 3)]
	var inside: bool = (field2.basin() as Object).call(&"inside", f.get("pos"), f.get("radius"))
	_check(("12. a changed rules: a drop written under rules %s loads under %s, every body"
		+ " re-derived from its genome (%s); a body at r%.0f trimmed to r%.2f, one %.0f past"
		+ " the rim put back inside (%s), a tank kept at %.3f; the log says %s -- and under"
		+ " the same rules %s; the fingerprint's %d tables by name (%s)") % [
		str(back.get("rules", "?")).left(8), DropSave.rules().left(8),
		str(derived), CellBody.DIVIDE_RADIUS + 6.0, float(b.get("radius")), 400.0, str(inside),
		float(b.get("hunger")), "CONVERTED" if line.contains("CONVERTED") else "NOTHING",
		"it does not" if not calm.contains("CONVERTED") else "IT DOES TOO", names.size(),
		"yes" if names == by_name else "NO: " + ",".join(names.slice(0, 4))],
		names == by_name and names.size() >= 20
		and not back.is_empty() and derived and float(b.get("radius")) == CellBody.DIVIDE_RADIUS
		and inside and float(b.get("hunger")) == 0.625 and int(done.get("trimmed", 0)) == 1
		and int(done.get("contained", 0)) >= 1 and line.contains("CONVERTED")
		and not calm.contains("CONVERTED"))
	field2.queue_free()
	cell2.free()


## How many changes of rules [param field]'s divisions have made, of every kind.
func _changes_made(field: Node) -> int:
	var n := 0
	for kind: StringName in Drop.CHANGES:
		n += int((field.get("stats") as Dictionary).get(StringName("rules_" + String(kind)), 0))
	return n


## A run of the game that keeps its drop at [constant KEEP], in point of view.
func _kept_run() -> Node:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 0)
	run.set("scheme", 0)
	run.set("keep", KEEP)
	add_child(run)
	return run


## A run's cell as the drop keeps it, read off its nodes -- its record of
## descent among them (lineage.md §4).
func _kept_cell(run: Node) -> Array:
	var met: Node = run.get("_metabolism")
	return [(run.get("_cell") as CellBody).call(&"body_state"),
		(run.get("_genome") as Node).call(&"to_state"), met.get("hunger"),
		met.get("starve_seconds"), run.get("_generation"), run.get("_sense_clock"),
		run.get("_sensed"), (run.get("_food") as Node).call(&"player_state"),
		run.call(&"_record")]


## Whether two divisions offer the same two daughters, side for side: the same
## DNA, layout, body and mutation, to their bytes.
func _same_pair(a: Array, b: Array) -> bool:
	if a.size() != 2 or b.size() != 2:
		return false
	for side in 2:
		for key: String in ["tiers", "order", "body", "mutation"]:
			if var_to_bytes(a[side][key]) != var_to_bytes(b[side][key]):
				return false
	return true


## [param fields] of [param object], in order.
func _row(object: Object, fields: Array) -> Array:
	var out := []
	for name: String in fields:
		out.append(object.get(name))
	return out


## The lines of the rules [param body] carries, and an empty list for the
## founders' (`brain` null).
func _lines(body: Object) -> PackedStringArray:
	var list: Variant = body.get("brain")
	return Rulebook.lines_of(list) if list != null else PackedStringArray()


## **7. The save keeps the rules** (behaviour.md §8, §12.3): a drop with a
## family's list -- carrying a name this build does not know -- on two of its
## hunters, kept and loaded. The list is kept once and the two share it again;
## the rule it cannot read never fires, and is written back as it came; and the
## bodies' columns and the lists come back to the bit. **A pack-2 file** -- that
## drop without pack 3's entries -- loads every hunter on the founders' rules,
## each having eaten as long ago as leaves it resting as long again as its
## `calm`, and one that was not resting never fed. **A version of the lists this
## build does not know** is not read, and every body loads on the founders'.
## **And spoilt**, pack 3's entries make the file unreadable: a body on a list
## the drop does not keep, echoes that are not whole, a memory that is not one.
func _save_behaviour() -> void:
	seed(34)
	var water := _water(0.0, 0.6)
	var field: WatchedDrop = water[0]
	for f in 10 * 60:
		field._process(1.0 / 60.0)
	var cells: Array = field.get("_cells")
	var lines: Array[String] = ["kinety.tingle below 0.5 -> body.rest",
		"metabolism.hunger below 0.4 -> body.rest", "always -> body.swim"]
	var list := _list(lines)
	var family: Array[int] = []
	var resting: Array = []
	for i in cells.size():
		var b: Object = cells[i]
		if not b.get("seeded") or b.get("inert") or b.get("drifter"):
			continue
		if family.size() < 2:
			b.set("brain", list)
			family.append(i)
		elif resting.size() < 3:
			b.set("calm", 1.0 + float(resting.size()))
			resting.append(i)
		else:
			b.set("calm", 0.0)
	var state: Dictionary = field.drop_state()
	var t := float(state["age"])
	var wrote := DropSave.write(KEEP, DropSave.compose(state, {}))
	var back := DropSave.read(KEEP)
	var loaded := _load_into(back["drop"] if not back.is_empty() else {})
	var c2: Array = (loaded[0] as Node).get("_cells")
	var a: Variant = (c2[family[0]] as Object).get("brain")
	var shared: bool = a != null and a == (c2[family[1]] as Object).get("brain")
	var inert: bool = shared and bool((a as RefCounted).get("rules")[0].get("inert"))
	# Kept once, under the one index both bodies name -- among whatever lists the
	# drop's own divisions changed by then (phase 3-2).
	var once := _kept_once(state, family, lines)
	var again: Dictionary = (loaded[0] as Node).call(&"drop_state")
	var written_back := _kept_once(again, family, lines)
	var exact := var_to_bytes(again["bodies"]) == var_to_bytes(state["bodies"]) \
		and var_to_bytes(again["behaviours"]) == var_to_bytes(state["behaviours"])
	_unload(loaded)
	# Pack 2's file: the same drop, none of pack 3's entries.
	var old: Dictionary = state.duplicate(true)
	old.erase("behaviours")
	for key: String in DropSave.BEHAVIOUR:
		(old["bodies"] as Dictionary).erase(key)
	var usable_old := DropSave.unusable(DropSave.compose(old, {})).is_empty()
	loaded = _load_into(old)
	var c3: Array = (loaded[0] as Node).get("_cells")
	var hunters := 0
	var on_founders := 0
	var rest_on := 0
	var never := 0
	for i in c3.size():
		var b: Object = c3[i]
		if not b.get("seeded") or b.get("inert") or b.get("drifter"):
			continue
		hunters += 1
		on_founders += 1 if b.get("brain") == null else 0
		var ate := float(b.get("ate_at"))
		if resting.has(i):
			var calm := 1.0 + float(resting.find(i))
			var fed := t - ate
			rest_on += 1 if ate == t - (FoodField.REST_MEAL - calm) \
				and fed < FoodField.REST_MEAL else 0
		elif float(b.get("calm")) <= 0.0:
			never += 1 if ate == -INF else 0
	var lists_unread := 0
	_unload(loaded)
	# Lists of a version this build does not know.
	var later: Dictionary = state.duplicate(true)
	later["behaviours"]["version"] = DropSave.BEHAVIOURS_VERSION + 1
	later["behaviours"]["lists"] = [42]
	var usable_later := DropSave.unusable(DropSave.compose(later, {})).is_empty()
	loaded = _load_into(later)
	for b: Object in (loaded[0] as Node).get("_cells"):
		if b.get("seeded") and b.get("brain") != null:
			lists_unread += 1
	_unload(loaded)
	# Spoilt, one way at a time.
	var spoilt := PackedStringArray()
	for way in 3:
		var copy: Dictionary = state.duplicate(true)
		var rows: Dictionary = copy["bodies"]
		match way:
			0:
				var column: PackedInt32Array = rows["behaviour"]
				column[0] = 5
				rows["behaviour"] = column
			1:
				var flying: Array = rows["echoes"]
				flying[0] = PackedFloat64Array([1.0, 2.0])
			2:
				var memory: Array = rows["memory"]
				memory[0] = {"chemocyte.smell": [3, [[0.5]]]}
		spoilt.append(DropSave.unusable(DropSave.compose(copy, {})))
	_check(("7. the save keeps the rules: a family's list on %d hunters, with a name this build"
		+ " does not know, kept once (%s), shared again (%s), its unknown rule inert (%s) and"
		+ " written back as it came (%s); the bodies' columns and the lists through the file to"
		+ " the bit (%s); a pack-2 file (readable: %s) loads %d hunters, %d of them on the"
		+ " founders' rules, %d of %d resting on as long as their calm, %d of the rest never fed;"
		+ " lists of version %d (readable: %s) not read, %d bodies off the founders'; spoilt: %s")
		% [family.size(), str(once), str(shared), str(inert), str(written_back), str(exact),
		str(usable_old), hunters, on_founders, rest_on, resting.size(), never,
		DropSave.BEHAVIOURS_VERSION + 1, str(usable_later), lists_unread, "; ".join(spoilt)],
		wrote == OK and once and shared and inert and written_back and exact and usable_old
		and hunters > 50 and on_founders == hunters and rest_on == 3 and never > 50
		and usable_later and lists_unread == 0
		and Array(spoilt).all(func(why: String) -> bool: return not why.is_empty()))
	_done(water)
	seed(20260930)


## Whether [param drop] keeps [param lines] once -- one list among those it keeps
## -- and the bodies in [param slots] all name it.
func _kept_once(drop: Dictionary, slots: Array[int], lines: Array[String]) -> bool:
	var kept: Array = drop["behaviours"]["lists"]
	var rows: Dictionary = drop["bodies"]
	var column: PackedInt32Array = rows["behaviour"]
	var at := (rows["slot"] as PackedInt32Array).find(slots[0])
	var index := column[at] if at >= 0 else -1
	var times := 0
	for list: PackedStringArray in kept:
		times += 1 if list == PackedStringArray(lines) else 0
	var all_name_it := index >= 0 and index < kept.size()
	for i: int in slots:
		var row := (rows["slot"] as PackedInt32Array).find(i)
		all_name_it = all_name_it and row >= 0 and column[row] == index
	return all_name_it and times == 1 and PackedStringArray(kept[index]) == PackedStringArray(lines)


## A field of its own with [param drop] loaded into it, made for the same player
## as [method _water]'s: `[field, cell]`.
func _load_into(drop: Dictionary) -> Array:
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	var field := WatchedDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.sensed_override = 0.6
	add_child(field)
	if not drop.is_empty():
		field.load_drop(cell, drop)
	return [field, cell]


func _unload(loaded: Array) -> void:
	(loaded[0] as Node).queue_free()
	(loaded[1] as Node).free()


## Nothing of these checks left in `user://`.
func _forget_kept() -> void:
	for path: String in [KEEP, KEEP + ".old", KEEP.get_basename() + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(KEEP.get_base_dir()):
		DirAccess.remove_absolute(KEEP.get_base_dir())


# --- Your drops (docs/design/settings.md §6, §8 phase 2) --------------------------------

## **Where these checks keep their drops**: a folder of their own, so its index
## and its three files are never the player's.
const DROPS_ROOT := "user://drop_probe_drops"
const CORNER := "res://game/menu/corner.tscn"
## The French catalog, which drops 9 registers for itself: a probe has no screen,
## so the game registers none (game/i18n/i18n.gd).
const FRENCH := "res://game/i18n/fr.po"

## **The two drops the checks are made of**, each kept by a real run of the game
## through the index: `{bytes, seed, age, slot}` -- the file as the run wrote it,
## the water's seed, its age, and the slot the run resolved.
var _drop_a := {}
var _drop_b := {}


## Each check begins with an empty folder, and nothing is left in it after them.
func _drops() -> void:
	_forget_drops()
	await _drops_kept()
	for check: Callable in [_drops_first_launch, _drops_unusable_first, _drops_lost_index,
			_drops_round_trip, _drops_switch, _drops_delete, _drops_tool_run, _drops_said]:
		_forget_drops()
		await check.call()
	_forget_drops()


## **drops 1. A run keeps the selected drop and tells the index** (§6.4): a run
## whose `keep` is the selected drop of a folder with no index plays slot 1, at
## that folder's `drop.save`, and its keep writes the file and the drop's line --
## its age and its cell's generation -- into a new `drops.cfg`. A new drop in
## slot 2 is selected, the next run plays it from `drop_2.save`, and its keep
## gives slot 2 its own line, slot 1's as it was.
func _drops_kept() -> void:
	var marker := Drops.selected_in(DROPS_ROOT)
	var first := await _drops_run(marker)
	var resolved := [int(first.get("_drop_slot")), str(first.get("keep"))]
	first.set("_generation", 3)
	# A clock of hours and a fraction: the index keeps whole seconds.
	(first.get("_food") as Node).set("_t", 7832.6)
	first.notification(NOTIFICATION_APPLICATION_PAUSED)
	_drop_a = _drop_kept(first, 1)
	first.queue_free()
	await get_tree().process_frame
	var made := Drops.make(2, "", DROPS_ROOT)
	var second := await _drops_run(marker)
	second.set("_generation", 5)
	(second.get("_food") as Node).set("_t", 1501.25)
	second.notification(NOTIFICATION_APPLICATION_PAUSED)
	_drop_b = _drop_kept(second, 2)
	second.queue_free()
	await get_tree().process_frame
	var index := Drops.read(DROPS_ROOT)
	var one := Drops.entry_of(index, 1)
	var two := Drops.entry_of(index, 2)
	_check(("drops 1. a run plays the selected drop and its keep tells the index: slot %d at"
		+ " %s, kept with its line -- %.1f s old in the index for %.2f, generation %d (\"%s\");"
		+ " a new drop in slot 2 selected (%s), played from slot %d, its line %.1f s and"
		+ " generation %d (\"%s\"), slot 1's untouched; two waters (seeds %d and %d)") % [
		resolved[0], str(resolved[1]).get_file(), float(one["lived"]), float(_drop_a["age"]),
		int(one["generation"]), Drops.line_of(one), error_string(made), int(_drop_b["slot"]),
		float(two["lived"]), int(two["generation"]), Drops.line_of(two), int(_drop_a["seed"]),
		int(_drop_b["seed"])],
		resolved == [1, DROPS_ROOT.path_join("drop.save")] and made == OK
		and not (_drop_a["bytes"] as PackedByteArray).is_empty()
		and not (_drop_b["bytes"] as PackedByteArray).is_empty()
		and int(_drop_a["slot"]) == 1 and int(_drop_b["slot"]) == 2
		and float(one["lived"]) == 7832.0 and float(_drop_a["age"]) == 7832.6
		and int(one["generation"]) == 3 and Drops.line_of(one) == "third generation · 2 hours old"
		and float(two["lived"]) == 1501.0 and int(two["generation"]) == 5
		and Drops.line_of(two) == "fifth generation · 25 minutes old"
		and int(index["selected"]) == 2 and int(_drop_a["seed"]) != int(_drop_b["seed"]))


## **drops 2. The first launch after the update** (§6.3, step 1): a `drop.save`
## with no index is slot 1, selected, called by default name 0, its line read
## from the file -- **and the file is the same bytes**, nothing beside it, no
## index written by reading. The first change writes the index, the line in it,
## and the file is still the same bytes. Slot 1 of the player's own drops is
## `DropSave.PATH`, today's drop, exactly.
func _drops_first_launch() -> void:
	var path := Drops.path_of(1, DROPS_ROOT)
	_put(path, _drop_a["bytes"])
	var index := Drops.read(DROPS_ROOT)
	var one := Drops.entry_of(index, 1)
	var same: bool = FileAccess.get_file_as_bytes(path) == _drop_a["bytes"]
	var alone := not FileAccess.file_exists(path + ".old") \
		and not FileAccess.file_exists(path.get_basename() + ".tmp")
	var unwritten := not FileAccess.file_exists(DROPS_ROOT.path_join(Drops.INDEX))
	var chose := Drops.select(1, DROPS_ROOT)
	var config := ConfigFile.new()
	var loaded := config.load(DROPS_ROOT.path_join(Drops.INDEX))
	var section := loaded == OK and int(config.get_value("1", "default", -1)) == 0 \
		and str(config.get_value("1", "name", "?")) == "" \
		and int(config.get_value("1", "generation", -1)) == 3 \
		and float(config.get_value("1", "lived", -1.0)) == floorf(float(_drop_a["age"]))
	var still: bool = FileAccess.get_file_as_bytes(path) == _drop_a["bytes"]
	_check(("drops 2. the first launch after the update: a drop.save with no index is slot 1"
		+ " (%s), selected (%d), \"%s\", %s -- read from the file, which is the same bytes (%s)"
		+ " with nothing set beside it (%s), and no index written by reading (%s); the first"
		+ " change (%s) writes the index with that line in it (%s), the file still the same"
		+ " bytes (%s); the player's slot 1 is %s") % [str(not bool(one["empty"])),
		int(index["selected"]), Drops.name_of(one), Drops.line_of(one), str(same), str(alone),
		str(unwritten), error_string(chose), str(section), str(still), Drops.path_of(1)],
		not bool(one["empty"]) and bool(one["file"]) and int(index["selected"]) == 1
		and Drops.name_of(one) == Drops.DEFAULT_NAMES[0] and int(one["generation"]) == 3
		and float(one["lived"]) == float(_drop_a["age"]) and same and alone and unwritten
		and chose == OK and section and still and Drops.path_of(1) == DropSave.PATH
		and bool(Drops.entry_of(index, 2)["empty"]) and bool(Drops.entry_of(index, 3)["empty"]))


## **drops 3. A drop this build cannot read is not set aside by the menu**
## (§6.3): another build's format at `drop.save`, with no index, is still slot 1,
## "not swum in yet" -- `DropSave.peek` reads it and leaves it where it is, the
## same bytes, nothing beside it. Only a run about to play a drop moves one.
func _drops_unusable_first() -> void:
	var water := _water()
	var later := DropSave.compose(water[0].call(&"drop_state"), {})
	later["format"] = DropSave.FORMAT + 1
	_done(water)
	var path := Drops.path_of(1, DROPS_ROOT)
	DirAccess.make_dir_recursive_absolute(DROPS_ROOT)
	var wrote := DropSave.write(path, later)
	var bytes := FileAccess.get_file_as_bytes(path)
	var index := Drops.read(DROPS_ROOT)
	var one := Drops.entry_of(index, 1)
	var peeked := DropSave.peek(path)
	var same: bool = FileAccess.get_file_as_bytes(path) == bytes and not bytes.is_empty()
	var alone := not FileAccess.file_exists(path + ".old")
	_check(("drops 3. a drop.save of format %d (%s) with no index is slot 1 (%s), \"%s\"; peeked"
		+ " as nothing (%s) and left where it is, the same bytes (%s), nothing set beside it (%s)")
		% [DropSave.FORMAT + 1, error_string(wrote), str(not bool(one["empty"])),
		Drops.line_of(one), str(peeked.is_empty()), str(same), str(alone)],
		wrote == OK and not bool(one["empty"]) and bool(one["file"]) and peeked.is_empty()
		and Drops.line_of(one) == "not swum in yet" and same and alone)


## **drops 4. A lost index is rebuilt from the files** (§6.3, steps 2 and 4):
## three named drops, slot 2 selected, slot 3 never swum in. With the index gone,
## and again with it unreadable, every file is a drop again -- default names in
## slot order, each line read from its file -- slot 3, which had no file, is
## empty, and slot 1 is selected. An index older than a file -- it names slot 1
## only -- gives that file the first default nobody shows, and its line.
func _drops_lost_index() -> void:
	_put(Drops.path_of(1, DROPS_ROOT), _drop_a["bytes"])
	_put(Drops.path_of(2, DROPS_ROOT), _drop_b["bytes"])
	var named := [Drops.rename(1, "my pond", DROPS_ROOT), Drops.rename(2, "my barrel", DROPS_ROOT),
		Drops.make(3, "spare", DROPS_ROOT), Drops.select(2, DROPS_ROOT)]
	var had := Drops.read(DROPS_ROOT)
	var index_path := DROPS_ROOT.path_join(Drops.INDEX)
	var seen: Array[String] = []
	var rebuilt := true
	for how: String in ["gone", "unreadable"]:
		if how == "gone":
			DirAccess.remove_absolute(index_path)
		else:
			_put(index_path, PackedByteArray([0xff, 0xfe, 0x5b, 0x00, 0x3d, 0x0a, 0x5b]))
		var index := Drops.read(DROPS_ROOT)
		var one := Drops.entry_of(index, 1)
		var two := Drops.entry_of(index, 2)
		seen.append("%s: %s / %s, %s / %s, %s, selected %d" % [how, Drops.name_of(one),
			Drops.line_of(one), Drops.name_of(two), Drops.line_of(two),
			"slot 3 empty" if bool(Drops.entry_of(index, 3)["empty"]) else "SLOT 3 KEPT",
			int(index["selected"])])
		rebuilt = rebuilt and Drops.name_of(one) == Drops.DEFAULT_NAMES[0] \
			and Drops.name_of(two) == Drops.DEFAULT_NAMES[1] \
			and int(one["generation"]) == 3 and int(two["generation"]) == 5 \
			and float(one["lived"]) == float(_drop_a["age"]) \
			and float(two["lived"]) == float(_drop_b["age"]) \
			and bool(Drops.entry_of(index, 3)["empty"]) and int(index["selected"]) == 1
	var older := ConfigFile.new()
	older.set_value("drops", "selected", 1)
	older.set_value("1", "name", "my pond")
	older.set_value("1", "default", 0)
	older.set_value("1", "lived", 12.0)
	older.set_value("1", "generation", 3)
	older.save(index_path)
	var index := Drops.read(DROPS_ROOT)
	var two := Drops.entry_of(index, 2)
	var orphan := not bool(two["empty"]) and int(two["default"]) == 0 \
		and int(two["generation"]) == 5 and Drops.name_of(Drops.entry_of(index, 1)) == "my pond"
	seen.append("older: slot 2 %s / %s" % [Drops.name_of(two), Drops.line_of(two)])
	_check("drops 4. a lost index is rebuilt from the files: named %s, selected %d; %s" % [
		", ".join(named.map(func(e: int) -> String: return error_string(e))),
		int(had["selected"]), "; ".join(seen)],
		named.all(func(e: int) -> bool: return e == OK) and int(had["selected"]) == 2
		and Drops.name_of(Drops.entry_of(had, 3)) == "spare" and rebuilt and orphan)


## **drops 5. New, rename and delete, round the index** (§4.4, §5.2): a new drop
## takes the first default no other drop shows, or the name typed -- trimmed, cut
## to NAME_MAX, no control characters -- and is selected; a slot that holds a
## drop cannot be made again; a name emptied, or set to the default's own words,
## is the default again; and the drop you are in cannot be deleted.
func _drops_round_trip() -> void:
	var fresh := Drops.read(DROPS_ROOT)
	var typed := Drops.make(2, "  my\tnew drop  ", DROPS_ROOT)
	var again := Drops.make(2, "twice", DROPS_ROOT)
	var plain := Drops.make(3, "", DROPS_ROOT)
	var index := Drops.read(DROPS_ROOT)
	var two := Drops.entry_of(index, 2)
	var three := Drops.entry_of(index, 3)
	var names := [Drops.name_of(Drops.entry_of(index, 1)), Drops.name_of(two), Drops.name_of(three)]
	var long := Drops.rename(3, "a name much longer than twenty", DROPS_ROOT)
	var cut := Drops.name_of(Drops.entry_of(Drops.read(DROPS_ROOT), 3))
	Drops.rename(3, "   ", DROPS_ROOT)
	var emptied := Drops.entry_of(Drops.read(DROPS_ROOT), 3)
	Drops.rename(2, Drops.DEFAULT_NAMES[1], DROPS_ROOT)
	var own_words := Drops.entry_of(Drops.read(DROPS_ROOT), 2)
	var locked := Drops.delete(3, DROPS_ROOT)
	var gone := Drops.delete(2, DROPS_ROOT)
	var after := Drops.read(DROPS_ROOT)
	_check(("drops 5. new, rename and delete: a fresh folder has slot 1 (%s) selected (%d); new"
		+ " drops %s and %s, the same slot again %s; named %s, the new one \"%s\" -- %s, selected"
		+ " %d; a long name kept as \"%s\" (%s); emptied, \"%s\"; the default's words kept as"
		+ " the default (%s); the drop you are in not deleted (%s), another deleted (%s)") % [
		Drops.name_of(Drops.entry_of(fresh, 1)), int(fresh["selected"]), error_string(typed),
		error_string(plain), error_string(again), str(names), Drops.name_of(three),
		Drops.line_of(three), int(index["selected"]), cut, error_string(long),
		Drops.name_of(emptied), str(str(own_words["name"]).is_empty()), error_string(locked),
		error_string(gone)],
		int(fresh["selected"]) == 1 and not bool(Drops.entry_of(fresh, 1)["empty"])
		and typed == OK and again == ERR_ALREADY_EXISTS and plain == OK
		and names == [Drops.DEFAULT_NAMES[0], "my new drop", Drops.DEFAULT_NAMES[1]]
		and Drops.line_of(three) == "not swum in yet" and int(index["selected"]) == 3
		and long == OK and cut == "a name much longer t" and cut.length() == Drops.NAME_MAX
		and str(emptied["name"]).is_empty() and Drops.name_of(emptied) == Drops.DEFAULT_NAMES[1]
		and str(own_words["name"]).is_empty() and locked == ERR_LOCKED and gone == OK
		and bool(Drops.entry_of(after, 2)["empty"]) and not bool(Drops.entry_of(after, 3)["empty"])
		and int(after["selected"]) == 3)


## **drops 6. Switching the selected drop switches the water and the cell**
## (§4.5): with drop A in slot 1 and drop B in slot 2, a run with slot 1 selected
## opens A's water and A's cell; with slot 2 selected, B's. That run's keep
## writes B's file and B's line, and leaves A's file and line as they were.
func _drops_switch() -> void:
	_put(Drops.path_of(1, DROPS_ROOT), _drop_a["bytes"])
	_put(Drops.path_of(2, DROPS_ROOT), _drop_b["bytes"])
	var marker := Drops.selected_in(DROPS_ROOT)
	var chose_one := Drops.select(1, DROPS_ROOT)
	var one := await _drops_run(marker)
	var got_one := _drops_opened(one)
	one.queue_free()
	await get_tree().process_frame
	var chose_two := Drops.select(2, DROPS_ROOT)
	var two := await _drops_run(marker)
	var got_two := _drops_opened(two)
	two.set("_generation", 6)
	two.notification(NOTIFICATION_APPLICATION_PAUSED)
	two.queue_free()
	await get_tree().process_frame
	var index := Drops.read(DROPS_ROOT)
	var a_same: bool = FileAccess.get_file_as_bytes(Drops.path_of(1, DROPS_ROOT)) == _drop_a["bytes"]
	var b_kept: bool = FileAccess.get_file_as_bytes(Drops.path_of(2, DROPS_ROOT)) != _drop_b["bytes"]
	_check(("drops 6. switching the selected drop: slot 1 selected (%s) opens %s, slot 2 (%s)"
		+ " opens %s -- [slot, seed, generation, resumed], against A's seed %d and B's %d; B's"
		+ " keep wrote B's file (%s) and line (generation %d), A's file the same bytes (%s) and"
		+ " its line generation %d") % [error_string(chose_one), str(got_one),
		error_string(chose_two), str(got_two), int(_drop_a["seed"]), int(_drop_b["seed"]),
		str(b_kept), int(Drops.entry_of(index, 2)["generation"]), str(a_same),
		int(Drops.entry_of(index, 1)["generation"])],
		chose_one == OK and chose_two == OK
		and got_one == [1, int(_drop_a["seed"]), 3, true]
		and got_two == [2, int(_drop_b["seed"]), 5, true]
		and b_kept and a_same and int(Drops.entry_of(index, 2)["generation"]) == 6
		and int(Drops.entry_of(index, 1)["generation"]) == 3)


## **drops 7. Deleting empties a slot, files and all, and never the drop you are
## in** (§4.4, §6.4, owner's row 8): asked to, the index refuses the selected
## drop and leaves its file; another goes with its `.tmp` and `.save.old`, the
## selected one's file untouched. **And the menu**: the drop you are in has no
## delete -- an empty box holds its place -- and a confirm asked for it does not
## open; an emptied row says "new world", which names and makes a drop there and
## selects it; then the other row's own delete, through the confirm, removes its
## file.
func _drops_delete() -> void:
	var one := Drops.path_of(1, DROPS_ROOT)
	var two := Drops.path_of(2, DROPS_ROOT)
	_put(one, _drop_a["bytes"])
	_put(two, _drop_b["bytes"])
	_put(one.get_basename() + ".tmp", PackedByteArray([1, 2, 3]))
	_put(one + ".old", PackedByteArray([4, 5, 6]))
	Drops.select(2, DROPS_ROOT)
	var refused := Drops.delete(2, DROPS_ROOT)
	var kept: bool = FileAccess.get_file_as_bytes(two) == _drop_b["bytes"] \
		and not bool(Drops.entry_of(Drops.read(DROPS_ROOT), 2)["empty"])
	var done := Drops.delete(1, DROPS_ROOT)
	var index := Drops.read(DROPS_ROOT)
	var gone := not FileAccess.file_exists(one) and not FileAccess.file_exists(one + ".old") \
		and not FileAccess.file_exists(one.get_basename() + ".tmp") \
		and bool(Drops.entry_of(index, 1)["empty"])
	var other: bool = FileAccess.get_file_as_bytes(two) == _drop_b["bytes"] \
		and int(index["selected"]) == 2
	# The menu, on the same folder.
	var corner: Control = (load(CORNER) as PackedScene).instantiate()
	corner.set("drops_root", DROPS_ROOT)
	add_child(corner)
	await get_tree().process_frame
	corner.call(&"open_drops")
	await get_tree().process_frame
	var rows := "Drops/Panel/Box/Row%d/"
	var no_delete := not (corner.get_node(rows % 2 + "Delete") as Control).visible \
		and (corner.get_node(rows % 2 + "Hold") as Control).visible \
		and (corner.get_node(rows % 2 + "Rename") as Control).visible
	var new_row := (corner.get_node(rows % 1 + "Pick/Lines/Name") as Label).text == "new world" \
		and not (corner.get_node(rows % 1 + "Rename") as Control).visible \
		and not (corner.get_node(rows % 1 + "Delete") as Control).visible
	corner.call(&"open_confirm", 2)
	var no_confirm: bool = corner.get("_open") == corner.get_node(^"Drops")
	(corner.get_node(rows % 1 + "Pick") as Button).pressed.emit()
	var naming: bool = corner.get("_open") == corner.get_node(^"Naming")
	var offered := (corner.get_node(^"Naming/Panel/Box/Field") as LineEdit).text
	(corner.get_node(^"Naming/Panel/Box/Actions/Make") as Button).pressed.emit()
	var made := Drops.read(DROPS_ROOT)
	var remade := not bool(Drops.entry_of(made, 1)["empty"]) and int(made["selected"]) == 1 \
		and not bool(corner.call(&"is_open"))
	corner.call(&"open_drops")
	await get_tree().process_frame
	var delete_two := corner.get_node(rows % 2 + "Delete") as Button
	var offers := delete_two.visible
	delete_two.pressed.emit()
	var asked: bool = corner.get("_open") == corner.get_node(^"Confirm")
	(corner.get_node(^"Confirm/Panel/Box/Actions/Delete") as Button).pressed.emit()
	var deleted: bool = not FileAccess.file_exists(two) \
		and bool(Drops.entry_of(Drops.read(DROPS_ROOT), 2)["empty"]) \
		and corner.get("_open") == corner.get_node(^"Drops")
	corner.queue_free()
	await get_tree().process_frame
	_check(("drops 7. delete: the drop you are in refused (%s) and its file kept (%s); another"
		+ " deleted (%s) with its .tmp and .save.old (%s), the selected one untouched (%s); the"
		+ " menu shows no delete for the drop you are in (%s) and opens no confirm for it (%s);"
		+ " the emptied row says new world (%s), names \"%s\" (%s) and makes it, selected (%s);"
		+ " then the other row's delete (%s) asks (%s) and removes its file (%s)") % [
		error_string(refused), str(kept), error_string(done), str(gone), str(other),
		str(no_delete), str(no_confirm), str(new_row), offered, str(naming), str(remade),
		str(offers), str(asked), str(deleted)],
		refused == ERR_LOCKED and kept and done == OK and gone and other and no_delete
		and no_confirm and new_row and naming and offered == Drops.DEFAULT_NAMES[0] and remade
		and offers and asked and deleted)


## **drops 8. A tool's run never touches the drops** (§6.4): a run with `keep`
## empty, as every tool's is, paused (a keep), left mid-run by the app pausing (a
## keep), writes no `drops.cfg` and no drop -- the player's own `user://` exactly
## as it was, whatever this machine holds -- and resolves no slot. A run keeping a
## file of its own writes that file and no index beside it.
func _drops_tool_run() -> void:
	var watched: Array[String] = [Drops.ROOT.path_join(Drops.INDEX),
		Drops.ROOT.path_join(Drops.INDEX_TMP)]
	for slot in range(1, Drops.SLOTS + 1):
		watched.append(Drops.path_of(slot))
	var before := _states(watched)
	var run := await _drops_run("")
	var slot := int(run.get("_drop_slot"))
	run.call(&"_set_menu", true)
	await get_tree().process_frame
	run.call(&"_set_menu", false)
	run.notification(NOTIFICATION_APPLICATION_PAUSED)
	run.queue_free()
	await get_tree().process_frame
	var own := DROPS_ROOT.path_join("own.save")
	DirAccess.make_dir_recursive_absolute(DROPS_ROOT)
	var keeper := await _drops_run(own)
	var own_slot := int(keeper.get("_drop_slot"))
	keeper.notification(NOTIFICATION_APPLICATION_PAUSED)
	keeper.queue_free()
	await get_tree().process_frame
	var after := _states(watched)
	var untouched := before == after
	var own_kept := FileAccess.file_exists(own) \
		and not FileAccess.file_exists(DROPS_ROOT.path_join(Drops.INDEX))
	var said := PackedStringArray()
	for state: Array in after:
		said.append("%s %s" % [str(state[0]).get_file(), "%d B" % (state[2] as PackedByteArray).size()
			if bool(state[1]) else "absent"])
	_check(("drops 8. a tool's run never touches the drops: keep empty, paused and left, resolved"
		+ " slot %d, and the player's drops.cfg and drops are as they were (%s: %s); a run keeping"
		+ " a file of its own (slot %d) wrote it with no index beside it (%s)") % [slot,
		str(untouched), ", ".join(said), own_slot, str(own_kept)],
		slot == 0 and own_slot == 0 and untouched and own_kept)


## **drops 9. A default name is said in the language of the moment; a typed one
## never is** (§5.2, §7): with French registered and chosen, the drop wearing the
## first default is called by its French in the index, on the chip, in the menu
## and in the naming field, while the drop the player named keeps their words.
## Renamed with the field untouched, or with the default's English, it goes on
## wearing its default; a new drop is offered the next default in French, never
## one another drop wears. Back in English, the naming field still open, the
## chip and the menu say their English again, the typed name unchanged; and the
## French typed in English keeps the default too. The French expected is the
## catalog's own, so a better translation never breaks this.
func _drops_said() -> void:
	Drops.make(2, "my drop", DROPS_ROOT)
	Drops.select(1, DROPS_ROOT)
	var french := load(FRENCH) as Translation
	var english: Array[String] = [Drops.DEFAULT_NAMES[0], Drops.DEFAULT_NAMES[1]]
	var said: Array[String] = [String(french.get_message(english[0])),
		String(french.get_message(english[1]))]
	var before := TranslationServer.get_locale()
	french.locale = "fr"
	TranslationServer.add_translation(french)
	TranslationServer.set_locale("fr")
	var index := Drops.read(DROPS_ROOT)
	var named := [Drops.name_of(Drops.entry_of(index, 1)), Drops.name_of(Drops.entry_of(index, 2))]
	var corner: Control = (load(CORNER) as PackedScene).instantiate()
	corner.set("drops_root", DROPS_ROOT)
	add_child(corner)
	await get_tree().process_frame
	var chip := corner.get_node(^"Cluster/Chip/Inside/Name") as Label
	var field := corner.get_node(^"Naming/Panel/Box/Field") as LineEdit
	var make := corner.get_node(^"Naming/Panel/Box/Actions/Make") as Button
	var rows := "Drops/Panel/Box/Row%d/"
	var on_chip := chip.text
	corner.call(&"open_drops")
	await get_tree().process_frame
	var in_menu := [(corner.get_node(rows % 1 + "Pick/Lines/Name") as Label).text,
		(corner.get_node(rows % 2 + "Pick/Lines/Name") as Label).text]
	(corner.get_node(rows % 1 + "Rename") as Button).pressed.emit()
	var offered := field.text
	make.pressed.emit()
	var untouched := str(Drops.entry_of(Drops.read(DROPS_ROOT), 1)["name"])
	(corner.get_node(rows % 1 + "Rename") as Button).pressed.emit()
	field.text = english[0]
	make.pressed.emit()
	var in_english := str(Drops.entry_of(Drops.read(DROPS_ROOT), 1)["name"])
	(corner.get_node(rows % 3 + "Pick") as Button).pressed.emit()
	var offered_new := field.text
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	await get_tree().process_frame
	var field_back := field.text
	corner.call(&"close_top")
	await get_tree().process_frame
	var back := [chip.text, (corner.get_node(rows % 1 + "Pick/Lines/Name") as Label).text,
		(corner.get_node(rows % 2 + "Pick/Lines/Name") as Label).text]
	var typed_french := Drops.rename(1, said[0], DROPS_ROOT)
	var french_kept := str(Drops.entry_of(Drops.read(DROPS_ROOT), 1)["name"])
	corner.queue_free()
	TranslationServer.remove_translation(french)
	TranslationServer.set_locale(before)
	await get_tree().process_frame
	_check(("drops 9. a default name is said in the language of the moment, a typed one never:"
		+ " in French slot 1 is \"%s\" in the index, \"%s\" on the chip, %s in the menu; renamed"
		+ " from \"%s\" untouched it keeps its default (%s), and from its English too (%s); a new"
		+ " world is offered \"%s\"; back in English the open field says \"%s\", the chip and the"
		+ " menu %s; and the French typed in English (%s) keeps the default (%s)") % [
		named[0], on_chip, str(in_menu), offered, str(untouched.is_empty()),
		str(in_english.is_empty()), offered_new, field_back, str(back),
		error_string(typed_french), str(french_kept.is_empty())],
		not said[0].is_empty() and said[0] != english[0] and not said[1].is_empty()
		and said[1] != english[1] and named == [said[0], "my drop"] and on_chip == said[0]
		and in_menu == [said[0], "my drop"] and offered == said[0] and untouched.is_empty()
		and in_english.is_empty() and offered_new == said[1] and field_back == english[1]
		and back == [english[0], english[0], "my drop"] and typed_french == OK
		and french_kept.is_empty())


## A run of the game with [param keep], in point of view, given a few frames.
func _drops_run(keep: String) -> Node:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 0)
	run.set("scheme", 0)
	run.set("keep", keep)
	add_child(run)
	for f in 30:
		await get_tree().process_frame
	return run


## What [param run] opened: `[slot, seed, generation, resumed]`.
func _drops_opened(run: Node) -> Array:
	return [int(run.get("_drop_slot")), int((run.get("_food") as Node).get("drop_seed")),
		int(run.get("_generation")), bool(run.get("_resumed"))]


## A kept drop, read off [param run] right after its keep, in slot [param slot].
func _drop_kept(run: Node, slot: int) -> Dictionary:
	var food: Node = run.get("_food")
	return {"bytes": FileAccess.get_file_as_bytes(Drops.path_of(slot, DROPS_ROOT)),
		"seed": int(food.get("drop_seed")), "age": float(food.call(&"drop_age")),
		"slot": int(run.get("_drop_slot"))}


## `[path, exists, bytes, modified]` for each of [param paths].
func _states(paths: Array[String]) -> Array:
	var out: Array = []
	for path: String in paths:
		var here := FileAccess.file_exists(path)
		out.append([path, here, FileAccess.get_file_as_bytes(path) if here else PackedByteArray(),
			FileAccess.get_modified_time(path) if here else 0])
	return out


func _put(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


## Nothing of these checks left in `user://`.
func _forget_drops() -> void:
	if not DirAccess.dir_exists_absolute(DROPS_ROOT):
		return
	for file: String in DirAccess.get_files_at(DROPS_ROOT):
		DirAccess.remove_absolute(DROPS_ROOT.path_join(file))
	DirAccess.remove_absolute(DROPS_ROOT)


# --- Lineage (docs/design/lineage.md §11.3: pack 2's checks 8, 9 and 10, as 2-1 has them) --

## **A body's lineage and the body beside it**, read off the body itself: what
## pack 2 keeps of every body, and what it wears.
const LINEAGE_FIELDS: Array[String] = ["id", "parent", "generation", "lineage", "grace", "dna",
	"genome"]


## **lineage 8, the save: the bodies** (§4). Twenty seconds of a drop, then a
## sister left in it -- wearing less than she carries, a gene this build does
## not know among what she carries, the child of a record three generations
## deep in a line that is not her mother's id -- and a body posed mid-grace: its
## grace a countdown 32 bits cannot hold, its DNA its body's genes in another
## order, which a mutation draws by, and a record of its own. Through the file's
## whole path and into a field of its own, every body's id, parent, generation,
## line, grace, DNA and body come back to the bit, and the file's DNA column is
## empty but for the bodies whose DNA is not their body -- those two, and since
## a meal writes the DNA alone (2-2), every water cell that has eaten. **A 1b
## file** -- the same drop without the four columns, nobody anybody's daughter
## -- is read, and every body comes back a founder: generation 1, its own line,
## its DNA its body, no grace. **And a column that does not hold what it says**
## -- one entry short, a DNA that is not gene names to copies, a grace in 32
## bits -- makes the file unreadable, never half-loaded.
func _save_lineage() -> void:
	var water := _water(0.0, 0.6)
	var field: WatchedDrop = water[0]
	for f in 20 * 60:
		field._process(1.0 / 60.0)
	var mother := Descent.of(field.take_id(), 4242, 3, 77)
	field.put_sister(PI * 0.5, 560.0, CellBody.daughter_radius(),
		{&"cytostome": 1, &"flagellum": 1},
		{&"cytostome": 2, &"flagellum": 1, &"chemocyte": 3, &"kinety": 1}, mother)
	var sister := field.last_spawned
	var at: Vector2 = field.basin().get(&"center") + Vector2(900.0, 0.0)
	var posed := _pose(field, at, 30.0, {&"cytostome": 2, &"rhabdom": 2, &"myoneme": 1})
	var b: Object = (field.get("_cells") as Array)[posed]
	for value: Array in [["grace", 42.0 - 61.0 / 60.0], ["generation", 9], ["lineage", 31],
			["parent", 17], ["dna", {&"rhabdom": 2, &"myoneme": 1, &"cytostome": 2}]]:
		b.set(value[0], value[1])
	var data := DropSave.compose(field.drop_state(), {})
	var wrote := DropSave.write(KEEP, data)
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	var field2 := WatchedDrop.new()
	field2.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(field2)
	if not back.is_empty():
		field2.load_drop(cell2, back["drop"])
	var ours: Array = field.get("_cells")
	var theirs: Array = field2.get("_cells")
	var kept := 0
	var differ := 0
	for i in mini(ours.size(), theirs.size()):
		if not bool(ours[i].get("seeded")):
			continue
		kept += 1
		if not bool(theirs[i].get("seeded")) or var_to_bytes(_row(ours[i], LINEAGE_FIELDS)) \
				!= var_to_bytes(_row(theirs[i], LINEAGE_FIELDS)):
			differ += 1
	var carried := 0
	for one: Dictionary in data["drop"]["bodies"]["dna"]:
		carried += 0 if one.is_empty() else 1
	# Since a meal writes the DNA alone (2-2), every cell that has eaten carries a
	# DNA that is not its body, beside the sister and the posed body.
	var apart := 0
	for one: Object in ours:
		var dna: Dictionary = one.get("dna")
		var body: Dictionary = one.get("genome")
		if bool(one.get("seeded")) and (dna != body or dna.keys() != body.keys()):
			apart += 1
	var her: Object = theirs[sister] if sister < theirs.size() else null
	var daughter := her != null and int(her.get("parent")) == mother[Descent.ID] \
		and int(her.get("generation")) == 4 and int(her.get("lineage")) == 77 \
		and int((her.get("dna") as Dictionary).get(&"kinety", 0)) == 1 \
		and (her.get("genome") as Dictionary).size() == 2
	field2.queue_free()
	cell2.free()
	# **The same drop as 1b wrote it**: no lineage, and nobody anybody's daughter.
	var old := DropSave.compose(field.drop_state(), {})
	var rows: Dictionary = old["drop"]["bodies"]
	for key: String in DropSave.LINEAGE:
		rows.erase(key)
	var nobody := PackedInt32Array()
	nobody.resize((rows["parent"] as PackedInt32Array).size())
	rows["parent"] = nobody
	var wrote_old := DropSave.write(KEEP, old)
	var back_old := DropSave.read(KEEP)
	var cell3 := CellBody.new()
	var field3 := WatchedDrop.new()
	field3.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(field3)
	if not back_old.is_empty():
		field3.load_drop(cell3, back_old["drop"])
	var founders := 0
	var others := 0
	for one: Object in field3.get("_cells"):
		if not bool(one.get("seeded")):
			continue
		if int(one.get("generation")) == 1 and int(one.get("lineage")) == int(one.get("id")) \
				and int(one.get("parent")) == 0 and float(one.get("grace")) == 0.0 \
				and var_to_bytes(one.get("dna")) == var_to_bytes(one.get("genome")):
			founders += 1
		else:
			others += 1
	field3.queue_free()
	cell3.free()
	# **And three columns that do not hold what they say.**
	var whys := PackedStringArray()
	for spoil in 3:
		var spoilt := DropSave.compose(field.drop_state(), {})
		var columns: Dictionary = spoilt["drop"]["bodies"]
		match spoil:
			0:
				var short: PackedInt32Array = columns["generation"]
				short.resize(short.size() - 1)
				columns["generation"] = short
			1:
				(columns["dna"] as Array)[0] = {"cytostome": "two"}
			2:
				columns["grace"] = PackedFloat32Array(Array(columns["grace"]))
		var why := DropSave.unusable(spoilt)
		whys.append(why if not why.is_empty() else "READ")
	_done(water)
	_check(("lineage 8. the save, the bodies: %d written (%s) and loaded into a field of their"
		+ " own, %d differing in id, parent, generation, line, grace, DNA or body, to the bit;"
		+ " the DNA column carries %d, every body whose DNA is not its body (%d), the rest"
		+ " the body's own; the sister back as generation 4 of line 77, her mother's id her"
		+ " parent, carrying a gene this build does not know (%s); a 1b file without the"
		+ " columns (%s) loads %d bodies as founders and %d not; spoilt, the file is"
		+ " unreadable: %s") % [kept, error_string(wrote), differ, carried, apart,
		str(daughter), error_string(wrote_old), founders, others, "; ".join(whys)],
		wrote == OK and not back.is_empty() and ours.size() == theirs.size() and differ == 0
		and kept > 500 and carried == apart and apart > 2 and daughter and wrote_old == OK
		and not back_old.is_empty() and founders == kept and others == 0
		and not whys.has("READ"))


## **lineage 8, the save: your cell** (§4). A run's first cell is generation 1,
## nobody's daughter and the first of its own line, numbered by its drop's
## count; left mid-run with a record three generations deep and opened again,
## it comes back with that record; **and a cell kept before pack 2**, without
## one, comes back with one started from the drop's count -- a line of its own,
## at the generation it had, which the player has seen. A cell whose id is not
## a number makes the file unreadable.
func _save_cell_lineage() -> void:
	var run := _kept_run()
	var food: Node = run.get("_food")
	var first: PackedInt32Array = run.call(&"_record")
	var count := int(food.get("_next_id"))
	var clash := false
	for b: Object in food.get("_cells"):
		if bool(b.get("seeded")) and int(b.get("id")) == first[Descent.ID]:
			clash = true
	var founded := first == Descent.founder(count - 1) and count > 500 and not clash
	run.set("_generation", 5)
	run.set("_parent", 4242)
	run.set("_lineage", 77)
	var was: PackedInt32Array = run.call(&"_record")
	run.notification(NOTIFICATION_APPLICATION_PAUSED)
	var kept := DropSave.read(KEEP)
	run.queue_free()
	await get_tree().process_frame
	var again := _kept_run()
	var back: PackedInt32Array = again.call(&"_record")
	again.queue_free()
	await get_tree().process_frame
	# **The same file as pack 1 kept it**: no record on the cell, no lineage on
	# the bodies.
	var old: Dictionary = kept.duplicate(true)
	if not old.is_empty():
		for key: String in DropSave.CELL_LINEAGE:
			(old["cell"] as Dictionary).erase(key)
		for key: String in DropSave.LINEAGE:
			(old["drop"]["bodies"] as Dictionary).erase(key)
	var wrote := DropSave.write(KEEP, old)
	var next := int(old.get("drop", {}).get("next_id", -1))
	var older := _kept_run()
	var started: PackedInt32Array = older.call(&"_record")
	var resumed := bool(older.get("_resumed"))
	older.queue_free()
	await get_tree().process_frame
	var bad: Dictionary = kept.duplicate(true)
	if not bad.is_empty():
		bad["cell"]["id"] = "seven"
	var why := DropSave.unusable(bad)
	_check(("lineage 8. the save, your cell: a run's first is %s -- the drop's next id, nobody's,"
		+ " generation 1, its own line (%s); left as %s and opened again it is %s; kept"
		+ " before pack 2 (%s) it comes back %s (%s), a line of its own from the drop's next"
		+ " id, %d, at the generation it had; an id that is not a number: %s") % [str(first),
		str(founded), str(was), str(back), error_string(wrote), str(started),
		"resumed" if resumed else "NOT RESUMED", next, why if not why.is_empty() else "READ"],
		founded and not kept.is_empty() and back == was and wrote == OK and resumed
		and started == Descent.of(next, 0, 5, next) and not why.is_empty())


## **lineage 9, the sister** (§4, §11.3 check 9). A run in its drop, its cell
## three generations deep in a line that is not its own id, divides by the
## game's own birth (`_be_born`), handed two daughters -- the declined one
## wearing less than she carries -- and the sister left in the water wears the
## declined daughter's body and carries her DNA, and is the child of the cell
## both divided from: its id her parent, its generation and one, its line. The
## daughter you become has that same record and an id of her own, neither of
## them any body's. **In a pond** the host's sister is the same, and a guest's,
## whom SISTER brings with what she wears and nothing more, is the founder of a
## line of her own, carrying what she wears. **And each has a newborn's grace**
## (2-2, §3.4), the guest's too: every daughter, water or sister.
func _sister_lineage() -> void:
	var run: Node = load("res://game/normal/normal_mode.tscn").instantiate()
	run.set("mode", 0)
	run.set("scheme", 0)
	run.set("keep", "")
	add_child(run)
	var food: Node = run.get("_food")
	run.set("_generation", 3)
	run.set("_parent", 4242)
	run.set("_lineage", 77)
	var mother: PackedInt32Array = run.call(&"_record")
	var declined := {"tiers": {&"cytostome": 2, &"cirrus": 1, &"flagellum": 1, &"chemocyte": 2},
		"order": [&"cytostome", &"cirrus", &"flagellum", &"chemocyte"],
		"body": {&"cytostome": 2, &"flagellum": 1}, "mutation": &"trade"}
	var chosen := {"tiers": {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1},
		"order": [&"cytostome", &"cirrus", &"flagellum"],
		"body": {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, "mutation": &""}
	run.set("_daughters", [chosen, declined])
	run.set("_chosen", 0)
	run.call(&"_be_born")
	var you: PackedInt32Array = run.call(&"_record")
	var ids := {}
	var sisters: Array[Object] = []
	for b: Object in food.get("_cells"):
		if not bool(b.get("seeded")):
			continue
		ids[int(b.get("id"))] = true
		if not bool(b.get("inert")) and int(b.get("parent")) == mother[Descent.ID]:
			sisters.append(b)
	var her: Object = sisters[0] if sisters.size() == 1 else null
	var hers := Descent.of(int(her.get("id")), int(her.get("parent")),
		int(her.get("generation")), int(her.get("lineage"))) if her != null \
		else PackedInt32Array()
	var wears := her != null and var_to_bytes(her.get("genome")) == var_to_bytes(declined["body"])
	var carries := her != null and var_to_bytes(her.get("dna")) == var_to_bytes(declined["tiers"])
	var graces := [float(her.get("grace")) if her != null else -1.0]
	var child := Descent.child(you[Descent.ID], mother)
	var yours_right := you == child and you[Descent.ID] != mother[Descent.ID] \
		and not ids.has(you[Descent.ID])
	var hers_right := her != null and hers == Descent.child(hers[Descent.ID], mother) \
		and hers[Descent.ID] != you[Descent.ID] and hers[Descent.ID] != mother[Descent.ID]
	run.queue_free()
	await get_tree().process_frame
	# **In a pond**: the host's own sister, and a guest's from the wire.
	var water := _water()
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	field.open_pond()
	field.put_sister(PI * 0.5, 560.0, CellBody.daughter_radius(), declined["body"],
		declined["tiers"], mother)
	var cells: Array = field.get("_cells")
	var host: Object = cells[field.last_spawned]
	var host_right := bool(field.pond_open()) and int(host.get("parent")) == mother[Descent.ID] \
		and int(host.get("generation")) == mother[Descent.GENERATION] + 1 \
		and int(host.get("lineage")) == mother[Descent.LINEAGE] \
		and var_to_bytes(host.get("dna")) == var_to_bytes(declined["tiers"])
	var slot: int = field.place_sister(cell.position + Vector2(-560.0, 0.0), 0.0,
		CellBody.daughter_radius(), declined["body"])
	var guest: Object = cells[slot] if slot >= 0 else null
	graces.append(float(host.get("grace")))
	graces.append(float(guest.get("grace")) if guest != null else -1.0)
	var guest_right := guest != null and int(guest.get("parent")) == 0 \
		and int(guest.get("generation")) == 1 and int(guest.get("lineage")) == int(guest.get("id")) \
		and var_to_bytes(guest.get("dna")) == var_to_bytes(guest.get("genome")) \
		and var_to_bytes(guest.get("genome")) == var_to_bytes(declined["body"])
	_done(water)
	_check(("lineage 9. the sister: of %s, the cell you were, you are %s (%s) and she is %s (%s),"
		+ " %d of her; she wears the declined daughter's body (%s) and carries her DNA (%s);"
		+ " in a pond the host's sister is the same (%s), and a guest's, from SISTER, the"
		+ " founder of a line of her own carrying what she wears (%s); their graces %s s, a"
		+ " newborn's %.0f") % [str(mother), str(you), str(yours_right), str(hers),
		str(hers_right), sisters.size(), str(wears), str(carries), str(host_right),
		str(guest_right), str(graces), FoodField.FIRST_DELAY],
		sisters.size() == 1 and yours_right and hers_right and wears and carries and host_right
		and guest_right and graces == [FoodField.FIRST_DELAY, FoodField.FIRST_DELAY,
			FoodField.FIRST_DELAY])


## The sister the identity gate leaves (lineage 10): what she wears, and -- on
## a build that keeps it -- what she carries besides.
const IDENTITY_BODY := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}
const IDENTITY_DNA := {&"cytostome": 2, &"cirrus": 1, &"flagellum": 1, &"chemocyte": 1}
## **`dev`'s census lines** for [method _identity_lines]' scenario, recorded on
## `dev` at 7f06cf7 -- pack 1, the commit pack 2 began from -- in this project's
## container (Godot 4.7.2, Ubuntu 24.04, glibc 2.39, x86-64), which is what CI
## runs on. **A rule of the drop changed on purpose changes them**: re-record
## them then from this check's own output, which prints both sides of a line
## that differs -- and say so in the commit, because that is the change.
const IDENTITY_LINES: Array[String] = [
	"[census] t 30  living 531 (drifters 437, hunters 94)  flocs 31  | hunters at r40 11, mean r 30.8, hunger 0.51  | could swallow r26/r34/r40 44/15/11  dread 0.78/0.40/0.26  genes 16  | spawned 663  died: swallowed 127 chewed 0 starved 5 (r40 0) poisoned 0  | grazed by the water 5, by drifters 0, dissolved 0, snow kept 1, remains 5  | runs 273 at you 0 misses 132 darts 1 dashes 20  floors: gene 0+0 drifter 0  | sum 2919193787",
	"[census] t 60  living 532 (drifters 439, hunters 93)  flocs 43  | hunters at r40 31, mean r 32.9, hunger 0.45  | could swallow r26/r34/r40 56/19/16  dread 0.87/0.40/0.24  genes 16  | spawned 832  died: swallowed 271 chewed 2 starved 27 (r40 1) poisoned 0  | grazed by the water 16, by drifters 0, dissolved 0, snow kept 2, remains 27  | runs 534 at you 0 misses 250 darts 5 dashes 50  floors: gene 0+0 drifter 0  | sum 642420395",
	"[census] t 30  living 506 (drifters 322, hunters 184)  flocs 40  | hunters at r40 20, mean r 30.5, hunger 0.45  | could swallow r26/r34/r40 116/44/27  dread 1.82/0.72/0.46  genes 16  | spawned 773  died: swallowed 249 chewed 2 starved 16 (r40 0) poisoned 0  | grazed by the water 11, by drifters 0, dissolved 0, snow kept 5, remains 16  | runs 508 at you 0 misses 217 darts 9 dashes 11  floors: gene 0+0 drifter 0  | sum 3550468869",
	"[census] t 60  living 509 (drifters 325, hunters 184)  flocs 46  | hunters at r40 58, mean r 32.5, hunger 0.50  | could swallow r26/r34/r40 123/63/52  dread 2.30/1.14/0.72  genes 16  | spawned 1077  died: swallowed 517 chewed 3 starved 48 (r40 3) poisoned 0  | grazed by the water 40, by drifters 1, dissolved 0, snow kept 9, remains 48  | runs 1085 at you 0 misses 509 darts 12 dashes 39  floors: gene 0+0 drifter 0  | sum 1127331418",
	"[census] t 30  living 543 (drifters 499, hunters 44)  flocs 38  | hunters at r40 3, mean r 30.2, hunger 0.50  | could swallow r26/r34/r40 21/2/0  dread 0.30/0.04/0.00  genes 16  | spawned 605  died: swallowed 57 chewed 0 starved 5 (r40 0) poisoned 0  | grazed by the water 0, by drifters 0, dissolved 0, snow kept 3, remains 5  | runs 124 at you 0 misses 68 darts 2 dashes 0  floors: gene 0+2 drifter 0  | sum 2851272202",
]


## **`dev`'s five minutes on pack 2's hunter** (behaviour.md §12.3 check 1): the
## census and lineage lines at 300 s of a newborn's drop (0.2) and a sighted
## player's (0.6), seed 1, as `tools/eco_probe.gd --seed=1 --until=300` printed
## them on `dev` at 29a5231 -- three runs, the same to the byte -- in this
## project's container (Godot 4.7.2, x86-64), which is what CI runs on. The
## rules off, [method _lineage]'s two drops must print them again. **A change to
## pack 2's water made on purpose changes them**: re-record them then from that
## check's own output, and say so in the commit.
const DEV_LINES: Array[String] = [
	"[census] t 300  living 530 (drifters 432, hunters 98)  flocs 62  | hunters at r40 0, mean r 31.2, hunger 0.47  | could swallow r26/r34/r40 62/9/2  dread 0.70/0.17/0.07  genes 16  | spawned 1918  died: swallowed 1539 chewed 38 starved 210 (r40 0) poisoned 0  | grazed by the water 136, by drifters 5, dissolved 54, snow kept 17, remains 210  | runs 2792 at you 0 misses 1299 darts 37 dashes 360  floors: gene 0+0 drifter 0  | sum 2679262745",
	"[lineage] t 300  hunters 98, born 97  generation mean 6.58 max 12  families 25 (largest 12)  dna apart 83  | cruise 95.1 notice 1326 mouth 1.27 upkeep 1.97 genes worn 5.85 carried 7.11  tails 71 sighted 98 at r40 0  | divisions 399 (trade 185 drift 214 faithfully 0), daughters 798: tailless 206, given a sense 110  | the spawner's peers 44 (for the floor 44, for venom 0), drifters 1319, left to births 0  | worn cyto 1.27 cirr 1.71 flag 1.84 stig 0.32 ocel 0.91 chem 1.10 ampu 0.95 axon 0.49 palp 0.34 myon 0.49 tric 0.24 pell 0.81 vene 0.11 plas 0.29 vacu 0.53 cris 0.47  | commonest 1x cytostome:1,ampulla:3,myoneme:2,pellicle:1,vacuole:2,crista:3 ; 1x cytostome:1,chemocyte:1,palp:3,trichocyst:3 ; 1x cytostome:1,cirrus:1,ampulla:2,palp:1,pellicle:1,vacuole:2",
	"[census] t 300  living 546 (drifters 350, hunters 196)  flocs 57  | hunters at r40 0, mean r 30.8, hunger 0.48  | could swallow r26/r34/r40 126/57/40  dread 1.97/1.02/0.57  genes 16  | spawned 3357  died: swallowed 3148 chewed 56 starved 354 (r40 0) poisoned 1  | grazed by the water 303, by drifters 3, dissolved 35, snow kept 13, remains 355  | runs 5390 at you 0 misses 2552 darts 55 dashes 337  floors: gene 0+0 drifter 0  | sum 1492090636",
	"[lineage] t 300  hunters 196, born 127  generation mean 3.71 max 13  families 146 (largest 10)  dna apart 125  | cruise 82.8 notice 1014 mouth 1.65 upkeep 1.62 genes worn 5.09 carried 5.94  tails 168 sighted 196 at r40 0  | divisions 748 (trade 354 drift 394 faithfully 0), daughters 1496: tailless 368, given a sense 252  | the spawner's peers 666 (for the floor 666, for venom 0), drifters 2136, left to births 0  | worn cyto 1.65 cirr 1.61 flag 1.60 stig 0.31 ocel 0.48 chem 0.56 ampu 0.59 axon 0.31 palp 0.16 myon 0.13 tric 0.17 pell 0.49 vene 0.03 plas 0.26 vacu 0.32 cris 0.32  | commonest 7x cytostome:1,cirrus:1,flagellum:1,ocellus:1 ; 6x cytostome:1,cirrus:1,flagellum:1,ampulla:1 ; 6x cytostome:1,cirrus:1,flagellum:1,stigma:1",
]


## **lineage 10, the identity gate** (§11.2, §11.3 check 10): **with births
## off** -- the field's own `births` switch, the seam every pack-2 rule is
## behind -- the drop's census lines are `dev`'s to the byte on the same seeds:
## the same population, the same deaths and meals, and the same sum of every
## body's place, size and tank. So pack 1 is still in this build, whole, and
## nothing of pack 2 leaks past its switch. **And the switch is what holds
## them**: the same scenario with births on has divided, and its first line is
## not `dev`'s -- a gate that passed either way would be a gate on nothing.
func _identity() -> void:
	var lines := _identity_lines(false)
	var on := _identity_lines(true, 1)
	seed(20260930)
	var differ := 0
	for k in maxi(lines.size(), IDENTITY_LINES.size()):
		var ours: String = lines[k] if k < lines.size() else "(none)"
		var theirs: String = IDENTITY_LINES[k] if k < IDENTITY_LINES.size() else "(none)"
		if ours != theirs:
			differ += 1
			print("[drop-probe] lineage 10, line %d, this build: %s" % [k + 1, ours])
			print("[drop-probe] lineage 10, line %d, dev:        %s" % [k + 1, theirs])
	var sums := PackedStringArray()
	for line in lines:
		sums.append(line.get_slice("| sum ", 1))
	var divided := on.size() == 2 and on[1].begins_with("[lineage]") \
		and not on[1].contains("divisions 0 ")
	_check(("lineage 10. the identity gate: with births off, %d census lines -- a newborn's"
		+ " drop and a sighted player's, 60 s each, and the empty room, 30 s -- with your id"
		+ " taken from the drop's count and a sister carrying more than she wears, against"
		+ " dev's on the same seeds: %s (sums %s); with births on the first is %s (%s)") % [
		lines.size(), "the same to the byte" if differ == 0 else "%d DIFFER" % differ,
		", ".join(sums), "dev's -- NOTHING DIVIDED" if on.is_empty() or on[0] == IDENTITY_LINES[0]
		else "not dev's", on[1].get_slice("| ", 2).strip_edges() if on.size() == 2 else "-"],
		differ == 0 and lines.size() == 5 and on.size() == 2 and on[0] != IDENTITY_LINES[0]
		and divided)


## **The identity gate's scenario** (lineage 10): a newborn's drop and a sighted
## player's, each from its own seed, 60 s with a census every 30 s, and the
## server's empty room from a third, 30 s. Your cell takes its id from the
## drop's count first, which moves every id after it, and 30 s in a sister is
## left wearing [constant IDENTITY_BODY] and carrying [constant IDENTITY_DNA],
## the child of your record. `dev` ran it with neither -- no id taken, and a
## sister who was her body and nothing more -- so neither may move a thing.
## Every field has [param births] as asked, and pack 2's hand-written hunter,
## which is pack 1's and `dev`'s (behaviour.md §12.3 check 1); with [param first]
## it stops at the first census -- the newborn's at 30 s -- and adds its lineage
## line after it.
func _identity_lines(births: bool, first := 0) -> Array[String]:
	var lines: Array[String] = []
	for each: Array in [[1, 0.2], [2, 0.6]]:
		seed(int(each[0]))
		var cell := CellBody.new()
		cell.radius = CellBody.BASE_RADIUS
		var field := FoodField.new()
		field.process_mode = Node.PROCESS_MODE_DISABLED
		field.sensed_override = float(each[1])
		field.births = births
		field.rules = false
		add_child(field)
		field.setup_drop(cell)
		field.in_water = false
		var yours := Descent.founder(field.take_id())
		for f in 60 * 60:
			field._process(1.0 / 60.0)
			if f == 30 * 60 - 1:
				field.put_sister(PI * 0.5, 560.0, CellBody.daughter_radius(), IDENTITY_BODY,
					IDENTITY_DNA, yours)
			if f % (30 * 60) == 30 * 60 - 1:
				lines.append(field.census_line())
				if first > 0 and lines.size() >= first:
					lines.append(field.lineage_line())
					break
		field.free()
		cell.free()
		if first > 0:
			return lines
	seed(3)
	var nobody := CellBody.new()
	var room := FoodField.new()
	room.process_mode = Node.PROCESS_MODE_DISABLED
	room.births = births
	room.rules = false
	add_child(room)
	room.open_dedicated(nobody)
	for f in 30 * 60:
		room._process(1.0 / 60.0)
	lines.append(room.census_line())
	room.free()
	nobody.free()
	return lines


# --- Pack 3: the water's rules (docs/design/behaviour.md §12.3) ------------------------------

## **What check 1's membrane digest reads** off the field every frame: every
## sense the player's membrane is fed from, all of which the water's cells now
## share -- the nose and its sum, the eyespot, dread, touch, the rays and what
## they touched, and the call, its fronts, its returns and its clock.
const MEMBRANE: Array[String] = ["concentration", "taste_level", "shadow", "shadow_bearing",
	"threat", "dread_level", "touch_level", "touch_bearing", "beams", "beam_touched", "pings",
	"ping_fronts", "ping_echoes", "ping_listen", "_echoes", "_pulses", "_ping_clock"]
## **`dev`'s membrane**: [method _membrane_digest] as it ran on `dev` at 29a5231,
## three times the same, in this project's container. Re-record it from the
## check's own output when the player's senses change on purpose, and say so in
## the commit.
const DEV_MEMBRANE := "970c04211c3ce3dea7d967ea4d042dafbc46dfc9ce3ab49c1496ad0395d67de5"


## **1. With the rules off it is pack 2, the membrane** (behaviour.md §12.3):
## forty seconds of a cell swimming a loop through a sighted player's drop
## (seed 1) with every sense the player can have -- a nose, an eyespot, three
## rays, a call and a palp -- among pack 2's hunters: the digest of everything
## [constant MEMBRANE] names, every frame, is `dev`'s. Every function the water
## now shares with the player runs in it, so one that moved the player's
## arithmetic by a bit fails here.
func _membrane() -> void:
	var digest := _membrane_digest(false)
	seed(20260930)
	_check(("1. with the rules off it is pack 2, the membrane: forty seconds of a cell"
		+ " crossing a sighted player's drop with a nose, an eyespot, three rays, a call and"
		+ " a palp, every sense it is fed each frame -- digest %s, %s") % [digest.left(16),
		"dev's" if digest == DEV_MEMBRANE else "NOT dev's (%s)" % DEV_MEMBRANE.left(16)],
		digest == DEV_MEMBRANE)


## The digest [method _membrane] checks, the field on [param rules] or off.
func _membrane_digest(rules: bool) -> String:
	seed(1)
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	var field := FoodField.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.sensed_override = 0.6
	field.grace = 1e6
	field.rules = rules
	add_child(field)
	field.setup_drop(cell)
	field.in_water = true
	field.smell_range = CellBody.SMELL_RANGE_BY_TIER[2]
	field.smell_bearing = 0.95
	field.beam_range = CellBody.BEAM_RANGE_BY_TIER[2]
	field.beam_bearings = PackedFloat32Array([-0.94, -0.62, -0.31])
	field.beam_fan_mid = -0.62
	field.beam_fan_half = 0.4
	field.ping_range = CellBody.PING_RANGE_BY_TIER[1]
	field.ping_period = CellBody.PING_PERIOD_BY_TIER[1]
	field.ping_bearing = -2.3
	field.ping_through = CellBody.PING_THROUGH_BY_TIER[1]
	field.ping_tier = 1
	field.touch_range = CellBody.TOUCH_RANGE_BY_TIER[2]
	var start := cell.position
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for f in 40 * 60:
		var t := float(f) / 60.0
		cell.position = start + Vector2(cos(t * 0.25) - 1.0, sin(t * 0.25)) * 600.0
		cell.heading = wrapf(t * 0.4, -PI, PI)
		field._process(1.0 / 60.0)
		var row := []
		for name: String in MEMBRANE:
			row.append(field.get(name))
		hash.update(var_to_bytes(row))
	var out := hash.finish().hex_encode()
	field.free()
	cell.free()
	return out


## **2. A water cell reads what your organs would** (behaviour.md §12.1, §12.3).
## You in the clear, wearing a nose, an eyespot, a palp, a laser and a radar in
## the order a water cell wears them, your organs set from your genome the way
## the run sets them (normal_mode.gd: the cell's reaches, `Cilia.bearing_of`,
## `_aim_beam`), with bodies posed round you: prey on every side, bodies big
## enough to cast a shadow, one at your palp, one on each ray and a floc. You
## read your nose, your shadow, your touch, your rays and your call. Then a
## water cell is posed where you were, as you were -- place, heading, size and
## genome, its organs on its own arcs -- with you out of the water, and reads
## its own. Each reading equals yours to the float: the level; the shadow and its
## bearing; the touch and its bearing; every ray that stops, at its bearing and
## distance; and every return of the call -- when it lands, where it came off,
## how far and how big it says it was, and when it rings out. **And again for a
## call answered from far off**, with nothing near: three bodies 600 to 1,000
## out, past half its reach.
func _shared_senses() -> void:
	seed(31)
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var cells: Array = field.get("_cells")
	var p := cell.position
	var h := 0.7
	cell.heading = h
	var fwd := Vector2(sin(h), -cos(h))
	var stb := Vector2(cos(h), sin(h))
	var tiers := {&"cytostome": 1, &"chemocyte": 2, &"stigma": 1, &"palp": 2, &"ocellus": 2,
		&"ampulla": 1}
	var genome := _your_organs(field, cell, tiers)
	# The water cell, posed first far off -- out of your reach.
	var centre: Vector2 = field.basin().get(&"center")
	var inward := (centre - p).normalized() if p.distance_to(centre) > 1.0 else Vector2.RIGHT
	var twin := _pose(field, p + inward * 2500.0, cell.radius, tiers, h, 0.5)
	var tb: Object = cells[twin]
	# Round you: [ahead, to starboard, radius, genome].
	var round_you := [[420.0, 150.0, 16.0, {&"cirrus": 1}],
		[700.0, -260.0, 18.0, {&"flagellum": 1}],
		[-300.0, 520.0, 14.0, {&"cirrus": 1, &"pellicle": 2}],
		[250.0, -330.0, 40.0, {&"cytostome": 2, &"cirrus": 1}],
		[-150.0, -480.0, 36.0, {&"cytostome": 1}],
		[60.0, 95.0, 20.0, {&"cirrus": 1}],
		[-640.0, 380.0, 30.0, {&"cytostome": 1, &"flagellum": 1}],
		[1150.0, -700.0, 25.0, {&"cirrus": 1}]]
	var ray := 0
	for bearing: float in field.beam_bearings:
		round_you.append([cos(bearing) * (330.0 + 140.0 * ray),
			sin(bearing) * (330.0 + 140.0 * ray), 17.0 + 3.0 * ray, {&"cirrus": 1}])
		ray += 1
	var posed: Array[int] = []
	for one: Array in round_you:
		posed.append(_pose(field, p + fwd * float(one[0]) + stb * float(one[1]),
			float(one[2]), one[3], 0.3, 0.5))
	posed.append(field._spawn_floc(p + fwd * 300.0 + stb * 40.0, 10.0, true))
	var near := _both_read(field, twin, p, h)
	# A call answered from far off: nothing near, three bodies past half its reach.
	tb.set("pos", p + inward * 2500.0)
	field.refile(twin)
	for i: int in posed:
		field.take_out(i)
	for k in 3:
		var bearing := -2.0 + 1.7 * float(k)
		_pose(field, p + (fwd * cos(bearing) + stb * sin(bearing)) * (600.0 + 200.0 * k),
			22.0, {&"cirrus": 1}, 0.0, 0.5)
	var far := _both_read(field, twin, p, h)
	var calls_far: Array = far[5]
	var deepest := 0.0
	for one: Array in calls_far:
		deepest = maxf(deepest, (one[1] as Vector2).distance_to(p))
	var yours: Array = near[0]
	_check(("2. a water cell reads what your organs would: posed where you were as you were,"
		+ " %d bodies and a floc round it -- smell %.4f, a shadow of %.3f at %.1f deg, a touch"
		+ " of %.3f at %.1f deg, %d rays stopping, %d returns of its call -- equal to the"
		+ " float: smell %s, shadow %s, touch %s, rays %s, call %s; and a call answered from"
		+ " as far as %.0f, with nothing near (%d returns): %s") % [round_you.size(),
		float(yours[0]), float(yours[1]), rad_to_deg(float(yours[2])), float(yours[3]),
		rad_to_deg(float(yours[4])), (near[4] as Array).size(), (near[5] as Array).size(),
		str(near[6]), str(near[7]), str(near[8]), str(near[9]), str(near[10]), deepest,
		calls_far.size(), str(far[10])],
		near[6] and near[7] and near[8] and near[9] and near[10] and far[10]
		and float(yours[0]) > 0.05 and float(yours[1]) > 0.0 and float(yours[3]) > 0.0
		and (near[4] as Array).size() >= 2 and (near[5] as Array).size() >= 2
		and calls_far.size() >= 2 and deepest > 0.5 * CellBody.PING_RANGE_BY_TIER[1])
	_done(water)
	genome.free()
	seed(20260930)


## **Your organs from your genome, as the run sets them** (normal_mode.gd): a
## genome node expressing [param tiers] in the order a water cell wears them --
## its laser posed at its tier as its level, since a water cell has no levels --
## on [param cell], and the field told the cell's reaches, the arcs
## `Cilia.bearing_of` gives and the beam `_aim_beam` aims. Returns the node.
func _your_organs(field: WatchedDrop, cell: CellBody, tiers: Dictionary) -> Node:
	var genome: Node = GenomeNode.new()
	genome.express(tiers, Cilia.default_order(tiers))
	var laser: RefCounted = genome.progression(&"ocellus")
	if laser != null:
		laser.set("xp", laser.call("xp_at", int(tiers.get(&"ocellus", 0)),
			float(laser.get("step"))))
	cell.genome = genome
	field.touch_range = CellBody.TOUCH_RANGE_BY_TIER[mini(cell.extra(&"palp"),
		CellBody.TOUCH_RANGE_BY_TIER.size() - 1)]
	field.smell_range = cell.smell_range()
	field.smell_bearing = Cilia.bearing_of(genome, &"chemocyte")
	field.ping_range = cell.ping_range()
	field.ping_period = cell.ping_period()
	field.ping_bearing = Cilia.bearing_of(genome, &"ampulla")
	field.ping_through = cell.ping_through()
	field.ping_tier = cell.ping_tier()
	var shape := CellBody.beam_shape(cell.beam_level(), cell.beam_path())
	var slot: int = genome.slot_of(&"ocellus")
	field.beam_range = float(shape[3])
	var bearings := PackedFloat32Array()
	var arcs := PackedFloat32Array()
	if int(shape[0]) > 0 and slot >= 0:
		var fan := RayFan.new()
		fan.configure(int(shape[0]), deg_to_rad(float(shape[1])), deg_to_rad(float(shape[2])))
		fan.step(0.0)
		var middle := Cilia.slot_bearing(slot)
		var offsets := fan.offsets()
		for k in offsets.size():
			bearings.append(wrapf(middle + offsets[k], -PI, PI))
			if fan.revisit() > 0.0:
				arcs.append(wrapf(middle + fan.arc_low()[k], -PI, PI))
				arcs.append(wrapf(middle + fan.arc_high()[k], -PI, PI))
		field.beam_fan_mid = middle
		field.beam_fan_half = deg_to_rad(float(shape[1]))
	else:
		field.beam_fan_half = -1.0
	field.beam_bearings = bearings
	field.beam_arcs = arcs
	return genome


## You at [param p], facing [param h], reading your nose, shadow, touch, rays and
## call over the bodies the frame would gather round you; then water cell
## [param twin] moved there, as you, with you out of the water, reading its own.
## Returns `[yours, its smell, its shadow, its touch, your rays, your returns as
## a water cell keeps them, and whether each of the five is equal]`.
func _both_read(field: WatchedDrop, twin: int, p: Vector2, h: float) -> Array:
	var tb: Object = (field.get("_cells") as Array)[twin]
	field.in_water = true
	field._refresh_me()
	field.set("_near", field.bodies_near(p, 1800.0))
	field._step_sense()
	field._step_beams()
	field._step_touch()
	(field.get("_echoes") as Array).clear()
	field._cast_ping()
	var yours := [field.taste_level, field.shadow, field.shadow_bearing, field.touch_level,
		field.touch_bearing]
	var your_rays: Array = []
	for one: Array in field.beams:
		if bool(one[2]):
			your_rays.append([float(one[0]), float(one[1])])
	your_rays.sort_custom(func(x: Array, y: Array) -> bool: return x[1] < y[1])
	var t := float(field.get("_t"))
	var your_calls: Array = []
	for one: Array in field.get("_echoes"):
		var due := float(one[0])
		var hold := float(one[4])
		your_calls.append([t + due, one[1], due * FoodField.PING_SPEED * 0.5,
			hold * FoodField.PING_SPEED / (2.0 * FoodField.PING_RING), t + due + hold])
	field.in_water = false
	field._refresh_me()
	tb.set("pos", p)
	tb.set("heading", h)
	field.refile(twin)
	var smell: Array = field._read_smell(twin, tb)
	var shadow: Array = field._read_shadow(twin, tb)
	var touch: Array = field._read_touch(twin, tb)
	var beam: Array = field._read_beam(twin, tb)
	tb.set("call_at", 0.0)
	tb.set("echoes", [])
	field._call_now(twin, tb)
	var same_smell := smell.size() == 1 and float(smell[0][0]) == float(yours[0])
	var same_shadow: bool = (shadow.size() == 1 and float(shadow[0][1]) == float(yours[1])
		and float(shadow[0][0]) == float(yours[2])) or (shadow.is_empty() and yours[1] == 0.0)
	var same_touch: bool = (touch.size() == 1 and float(touch[0][1]) == float(yours[3])
		and float(touch[0][0]) == float(yours[4])) or (touch.is_empty() and yours[3] == 0.0)
	var same_rays := beam.size() == your_rays.size()
	for k in mini(beam.size(), your_rays.size()):
		same_rays = same_rays and float(beam[k][0]) == float(your_rays[k][0]) \
			and float(beam[k][1]) == float(your_rays[k][1])
	var same_calls := var_to_bytes(tb.get("echoes")) == var_to_bytes(your_calls)
	return [yours, smell, shadow, touch, your_rays, your_calls, same_smell, same_shadow,
		same_touch, same_rays, same_calls]


## **3. No magic** (behaviour.md §3.2, §12.3). **A gene a body carries and does
## not wear is not there**: a body carrying a nose, a radar, a laser, an eyespot
## and a palp and wearing none of them, on the founders' rules with prey all round
## it, has none of their inputs read over three seconds of its ticks -- its tank
## and its last meal are -- and asked straight, none of their readers reports.
## **And a reading is its organs' and nothing else's**: a water cell wearing all
## five, posed among bodies with you beside it, reads the same to the float after
## everything its organs do not reach is changed -- every body past the farthest
## of its reaches taken out, every other body's tank, meals, clocks and rules,
## and your own organs. Check 2 holds what it does read to what yours read.
func _no_magic() -> void:
	seed(32)
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var cells: Array = field.get("_cells")
	var p := cell.position
	cell.heading = 0.0
	field.in_water = true
	var senses := {&"chemocyte": 2, &"ampulla": 2, &"ocellus": 2, &"stigma": 1, &"palp": 2}
	var owners: Array[StringName] = [&"chemocyte", &"ampulla", &"ocellus", &"stigma", &"palp"]
	# Carried, not worn: its DNA has all five, its body none.
	var at := p + Vector2(-700.0, 0.0)
	var blind := _pose(field, at, 30.0, {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}, 0.0,
		0.6)
	var bb: Object = cells[blind]
	var carried: Dictionary = (bb.get("genome") as Dictionary).duplicate()
	carried.merge(senses)
	bb.set("dna", carried)
	bb.set("brain", null)
	for k in 6:
		_pose(field, at + Vector2.from_angle(TAU * float(k) / 6.0 + 0.3) * (90.0 + 40.0 * k),
			14.0, {&"cirrus": 1}, 0.0, 0.5)
	# Big enough to cast it a shadow, astern, out of its way.
	_pose(field, at + Vector2(0.0, 420.0), 40.0, {&"cirrus": 1}, 0.0, 0.5)
	field.log_reads = true
	field.reads.clear()
	for f in 3 * 60:
		field._process(1.0 / 60.0)
	field.log_reads = false
	# Wearing all five, among bodies -- one on each of its rays -- you beside it.
	var w_at := p + Vector2(700.0, 0.0)
	var w_tiers := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}
	w_tiers.merge(senses)
	var w := _pose(field, w_at, 30.0, w_tiers, 0.4, 0.6)
	var wb: Object = cells[w]
	for k in 9:
		var r := 15.0 if k % 3 != 0 else 38.0
		_pose(field, w_at + Vector2.from_angle(TAU * float(k) / 9.0 + 0.11)
			* (110.0 + 70.0 * k), r, {&"cirrus": 1}, 0.0, 0.5)
	var ray := 0
	for bearing: float in (wb.get("eye") as Object).get("beam_bearings"):
		var aim := 0.4 + bearing
		_pose(field, w_at + Vector2(sin(aim), -cos(aim)) * (380.0 + 150.0 * ray), 18.0,
			{&"cirrus": 1}, 0.0, 0.5)
		ray += 1
	field._spawn_floc(w_at + Vector2(-60.0, 120.0), 10.0, true)
	var unworn := 0
	var own := 0
	for read: Array in field.reads:
		if int(read[0]) != blind:
			continue
		var owner := StringName(String(read[1]).get_slice(".", 0))
		if owners.has(owner):
			unworn += 1
		else:
			own += 1
	var straight := [field._read_smell(blind, bb), field._read_shadow(blind, bb),
		field._read_touch(blind, bb), field._read_beam(blind, bb), field._read_echo(blind, bb)]
	var silent := straight.all(func(one: Array) -> bool: return one.is_empty())
	# Everything the water cell's organs do not reach, changed.
	var before := _readings(field, w)
	var reach := maxf(maxf(CellBody.SMELL_RANGE_BY_TIER[2], CellBody.PING_RANGE_BY_TIER[2]),
		maxf(CellBody.BEAM_RANGE_BY_TIER[2], FoodField.SHADOW_RANGE)) + 2.0 * Drop.GRID_SLACK \
		+ CellBody.DIVIDE_RADIUS
	var taken := 0
	for i in cells.size():
		var b: Object = cells[i]
		if i != w and bool(b.get("seeded")) and (b.get("pos") as Vector2).distance_to(w_at) > reach:
			field.take_out(i)
			taken += 1
	for i in cells.size():
		var b: Object = cells[i]
		if i == w or not bool(b.get("seeded")):
			continue
		for value: Array in [["hunger", 0.123], ["starve", 1.5], ["effort", 9.0], ["meals", 7],
				["calm", 3.0], ["stun", 2.0], ["ate_at", 1.0], ["dart_clock", 4.0],
				["memory", {}], ["brain", null], ["hit", 0.7]]:
			b.set(value[0], value[1])
	# Your organs, past every one of its own: a reader that asked them would read
	# farther, wider and elsewhere.
	for value: Array in [["smell_range", 5000.0], ["smell_bearing", 2.5],
			["beam_range", 5000.0], ["beam_bearings", PackedFloat32Array([1.5, 2.0, 2.5])],
			["beam_fan_mid", 2.0], ["beam_fan_half", 1.0], ["ping_range", 5000.0],
			["ping_bearing", 3.0], ["ping_through", 0.9], ["ping_tier", 3],
			["touch_range", 2000.0], ["dart_range", 300.0]]:
		field.set(value[0], value[1])
	var after := _readings(field, w)
	var same := var_to_bytes(before) == var_to_bytes(after)
	_check(("3. no magic: a body carrying a nose, a radar, a laser, an eyespot and a palp and"
		+ " wearing none, on the founders' rules among prey -- %d reads of their inputs over three"
		+ " seconds and %d of its own; asked straight they report %s. A water cell wearing all"
		+ " five -- smell %.3f, %d shadows, %d touches, %d rays stopping, %d returns -- after %d"
		+ " bodies past its reach were taken out and every other body's insides and your organs"
		+ " changed: %s") % [unworn, own, "nothing" if silent else "SOMETHING", float(before[0][0][0])
		if not (before[0] as Array).is_empty() else 0.0, (before[1] as Array).size(),
		(before[2] as Array).size(), (before[3] as Array).size(), (before[4] as Array).size(),
		taken, "the same to the float" if same else "DIFFERENT"],
		unworn == 0 and own > 10 and silent and same and taken > 100
		and not (before[0] as Array).is_empty() and float(before[0][0][0]) > 0.05
		and not (before[1] as Array).is_empty() and not (before[2] as Array).is_empty()
		and not (before[3] as Array).is_empty() and (before[4] as Array).size() >= 2)
	_done(water)
	seed(20260930)


## Every reading body [param i] of [param field] takes now, its call made afresh:
## its smell, its shadow, its touch, its rays and its echoes in flight.
func _readings(field: WatchedDrop, i: int) -> Array:
	var b: Object = (field.get("_cells") as Array)[i]
	b.set("call_at", 0.0)
	b.set("echoes", [])
	field._call_now(i, b)
	return [field._read_smell(i, b), field._read_shadow(i, b), field._read_touch(i, b),
		field._read_beam(i, b), (b.get("echoes") as Array).duplicate(true)]


## **10. Coming for you** (behaviour.md §4.3, §12.3), with bodies posed in the
## clear, each alone with you and swimming on the founders' rules. A mouth that
## could swallow you, swimming at you within 35°, is felt as a wake; one swimming
## past at 60°, and one too small to take you swimming straight at you, are not.
## Your dart -- ready, in range, facing it -- fires at the first and at neither of
## the others, and a `trichocyst` in the water fires at a mouth coming for its
## body and at neither of the others. **A dart stuns**: the body rests with its
## rules unread for DART_STUN seconds, to a frame -- and on the first tick it
## reads them again it feels the dart as a `hit` at its bearing, which its rule
## turns it away from.
func _coming_for_you() -> void:
	seed(33)
	var water := _water(3000.0)
	var field: WatchedDrop = water[0]
	var cell: CellBody = water[1]
	var cells: Array = field.get("_cells")
	var p := cell.position
	cell.heading = 0.0
	field.in_water = true
	var wakes: Array = []
	var darts: Array = []
	field.waked.connect(func(bearing: float, _strength: float) -> void: wakes.append(bearing))
	field.darted.connect(func(bearing: float) -> void: darts.append(bearing))
	var big := {&"cytostome": 3, &"cirrus": 1, &"flagellum": 1}
	var small := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}
	var cases := [[15.0, big, 38.0], [60.0, big, 38.0], [0.0, small, 20.0]]
	# Your wake, 500 ahead of you: two and a half seconds each.
	var felt := []
	for one: Array in cases:
		var at := p + Vector2(0.0, -500.0)
		var k := _pose(field, at, float(one[2]), one[1], _facing(at, p) + deg_to_rad(float(one[0])),
			0.6)
		(cells[k] as Object).set("brain", null)
		wakes.clear()
		for f in 150:
			field._process(1.0 / 60.0)
		felt.append(wakes.size())
		field.take_out(k)
	# Your dart, ready and facing ahead, 200 ahead of you: the first is darted --
	# and is on a list that turns away from a hit -- and watched through its stun.
	field.dart_range = CellBody.DART_RANGE_BY_TIER[3]
	field.dart_bearing = 0.0
	field.dart_cooldown = CellBody.DART_COOLDOWN_BY_TIER[3]
	var yours := []
	var stunned_for := 0.0
	var reads_stunned := 0
	var turned := false
	for c in cases.size():
		var one: Array = cases[c]
		field.set("_dart_clock", 0.0)
		var at := p + Vector2(0.0, -200.0)
		var k := _pose(field, at, float(one[2]), one[1], _facing(at, p) + deg_to_rad(float(one[0])),
			0.6)
		var kb: Object = cells[k]
		kb.set("brain", null if c > 0 else _list(["body.hit -> body.turn-away", "always -> body.swim"]))
		darts.clear()
		for f in 30:
			field._process(1.0 / 60.0)
			if c == 0 and not darts.is_empty():
				break
		yours.append(darts.size())
		if c == 0 and darts.size() == 1:
			var stun_at := float(field.get("_t"))
			var from := float(kb.get("hit_from"))
			field.log_reads = true
			field.reads.clear()
			while float(kb.get("stun")) > 0.0 and float(field.get("_t")) < stun_at + 10.0:
				field._process(1.0 / 60.0)
			stunned_for = float(field.get("_t")) - stun_at
			for read: Array in field.reads:
				reads_stunned += 1 if int(read[0]) == k else 0
			for f in Drop.LOD_EVERY + 1:
				field._process(1.0 / 60.0)
			field.log_reads = false
			turned = bool(kb.get("holding")) and absf(angle_difference(float(kb.get("steer")),
				from + PI)) < 1e-6
		field.take_out(k)
	# A trichocyst in the water, resting, out of your wake's reach, its dart's arc
	# on each in turn, 200 off.
	var d_at := p + Vector2(1600.0, 0.0)
	var defender := _pose(field, d_at, 30.0, {&"cytostome": 1, &"trichocyst": 3}, 0.4, 0.6)
	var db: Object = cells[defender]
	var arc := float(db.get("heading")) + float(db.get("dart_bearing"))
	var theirs := []
	for one: Array in cases:
		db.set("dart_clock", 0.0)
		var at := d_at + Vector2(sin(arc), -cos(arc)) * 200.0
		var k := _pose(field, at, float(one[2]), one[1],
			_facing(at, d_at) + deg_to_rad(float(one[0])), 0.6)
		(cells[k] as Object).set("brain", null)
		for f in 30:
			field._process(1.0 / 60.0)
		theirs.append([float(db.get("dart_clock")) > 0.0,
			float((cells[k] as Object).get("stun")) > 0.0])
		field.take_out(k)
	_check(("10. coming for you: wakes from a mouth swimming at you 15 deg off %d, past at 60"
		+ " deg %d, too small to take you %d; your dart at them %s; a trichocyst in the water at"
		+ " them %s (fired, stunned); the dart's stun %.3f s (DART_STUN %.0f), %d reads while"
		+ " stunned, and on its first tick after it turned away from the dart: %s") % [
		felt[0], felt[1], felt[2], str(yours), str(theirs), stunned_for, CellBody.DART_STUN,
		reads_stunned, str(turned)],
		felt[0] >= 1 and felt[1] == 0 and felt[2] == 0 and yours == [1, 0, 0]
		and theirs == [[true, true], [false, false], [false, false]]
		and absf(stunned_for - CellBody.DART_STUN) <= 1.5 / 60.0 and reads_stunned == 0
		and turned)
	_done(water)
	seed(20260930)


## **4. Every change is valid** (behaviour.md §6.2, §6.3, §12.3): ten thousand
## changes by the drop's own `daughter_behaviours`, half from the founders' rules
## and half from random lists -- one rule to eight, now and then with a rule
## this build cannot read, two equal rules side by side, or a step off its
## ladder or past its ends -- each under the owners a random DNA gives. Every
## change holds to §6.2's limits by this probe's own reading ([method _flaws]);
## is one change of the kind it says from its parent ([method _change_kinds]),
## and so differs from it; draws a new input or output only from the body, the
## metabolism and the genes its DNA carries (§6.3); and comes back through its
## text the same. Its parent is never written through. **And the kinds come at
## their weights**: from the founders' rules, where all five can, within two and
## a half points of drop.gd's CHANGES.
func _changes() -> void:
	seed(41)
	var vocab: RefCounted = FoodField.vocabulary()
	var founders: RefCounted = FoodField.founders()
	var everybody := {}
	for owner: StringName in CellBody.DECLARES:
		everybody[owner] = true
	for owner: StringName in Metabolism.DECLARES:
		everybody[owner] = true
	var genes: Array[StringName] = []
	for owner: StringName in vocab.get("owners"):
		if not everybody.has(owner):
			genes.append(owner)
	var counts := {"flawed": 0, "not one": 0, "drawn": 0, "outside": 0, "trips": 0,
		"written": 0}
	var edges := {"one rule": 0, "eight": 0, "unreadable": 0, "equal neighbours": 0,
		"off the ladder": 0}
	var said: Array[String] = []
	var theirs := {}
	var randoms := {}
	for n in 10000:
		var dna := {&"cytostome": 1}
		for gene: StringName in genes:
			if randf() < 0.4:
				dna[gene] = 1 + randi() % 3
		var owners := Rulebook.worn(vocab, dna, everybody)
		var parent: RefCounted = founders if n % 2 == 0 else _random_list(vocab, edges)
		var before := Rulebook.text_of(parent)
		var rolled: Array = Drop.daughter_behaviours(parent, vocab, owners)
		var child: RefCounted = rolled[1]
		var kind: StringName = rolled[2]
		var whys: Array[String] = []
		var flaw := _flaws(child, vocab)
		if not flaw.is_empty():
			counts["flawed"] += 1
			whys.append(flaw)
		var can := _change_kinds(parent, child, vocab)
		if not can.has(kind):
			counts["not one"] += 1
			whys.append("a %s that reads as %s" % [kind, str(can)])
		for part: StringName in _drawn(parent, child):
			counts["drawn"] += 1
			if not _owned(part, vocab, owners):
				counts["outside"] += 1
				whys.append("drew %s, past a DNA of %s" % [part, str(dna.keys())])
		var text := Rulebook.text_of(child)
		var back: RefCounted = Rulebook.parse(text, vocab)
		if Rulebook.text_of(back) != text or _rule_keys(back) != _rule_keys(child) \
				or _inert_count(back) != _inert_count(child):
			counts["trips"] += 1
			whys.append("not the same through its text")
		if Rulebook.text_of(parent) != before or rolled[0] != parent or child == parent \
				or is_same(child.get("rules"), parent.get("rules")):
			counts["written"] += 1
			whys.append("its parent written through")
		if not whys.is_empty() and said.size() < 4:
			said.append("%s, from [%s] to [%s]" % [", ".join(whys), before.replace("\n", " / "),
				text.replace("\n", " / ")])
		var tally := theirs if n % 2 == 0 else randoms
		tally[kind] = int(tally.get(kind, 0)) + 1
	var total := 0.0
	for kind: StringName in Drop.CHANGES:
		total += float(Drop.CHANGES[kind])
	var shares := PackedStringArray()
	var weighed := true
	for kind: StringName in Drop.CHANGES:
		var share := float(theirs.get(kind, 0)) / 5000.0
		var want := float(Drop.CHANGES[kind]) / total
		shares.append("%s %.3f (%.1f)" % [kind, share, want])
		weighed = weighed and absf(share - want) < 0.025
	_check(("4. every change is valid: 10,000 changes, half from the founders' rules (%s, against"
		+ " the weights) and half from random lists (%s; edges %s) -- %d outside §6.2's limits,"
		+ " %d not one change of the kind they say, %d of %d parts drawn new from past their DNA,"
		+ " %d not the same through their text, %d written through their parent%s")
		% [", ".join(shares), str(randoms), str(edges), counts["flawed"], counts["not one"],
		counts["outside"], counts["drawn"], counts["trips"], counts["written"],
		"" if said.is_empty() else " -- " + "; ".join(said)],
		weighed and counts["flawed"] == 0 and counts["not one"] == 0 and counts["outside"] == 0
		and counts["trips"] == 0 and counts["written"] == 0 and counts["drawn"] > 500
		and randoms.size() == 5 and edges.values().all(func(v: int) -> bool: return v >= 50)
		and Rulebook.text_of(founders) == "\n".join(Drop.FOUNDERS))
	seed(20260930)


## **A random list over the whole vocabulary**: one to eight rules, now and then
## one this build cannot read or a copy of the rule above it; counted into
## [param edges] by what makes it an edge.
func _random_list(vocab: RefCounted, edges: Dictionary) -> RefCounted:
	var lines: Array[String] = []
	var n := 1 + randi() % Drop.MOST_RULES
	var equal := false
	for k in n:
		var roll := randf()
		if roll < 0.06:
			lines.append("kinety.tingle below 0.5 -> body.rest")
		elif k > 0 and roll < 0.2:
			lines.append(lines[k - 1])
			equal = true
		else:
			lines.append(_random_rule(vocab, edges))
	if n == 1:
		edges["one rule"] += 1
	if n == Drop.MOST_RULES:
		edges["eight"] += 1
	if lines.has("kinety.tingle below 0.5 -> body.rest"):
		edges["unreadable"] += 1
	if equal:
		edges["equal neighbours"] += 1
	return _list(lines)


## **A random rule's line**: any declared input or always; a test on each value
## it carries about a third of the time -- any of the four, against any rung, a
## reference for a size, or now and then a step between two rungs or past
## either end of the ladder; and any output its input can drive, at any option.
func _random_rule(vocab: RefCounted, edges: Dictionary) -> String:
	var inputs: Array = (vocab.get("inputs") as Dictionary).keys()
	inputs.append(Rulebook.ALWAYS)
	var name: StringName = inputs[randi() % inputs.size()]
	var input: Object = (vocab.get("inputs") as Dictionary).get(name)
	var words := PackedStringArray([String(name)])
	var bearing := false
	if input != null:
		bearing = bool(input.get("bearing"))
		var values: Array = input.get("values")
		var kinds: Array = input.get("kinds")
		for at in values.size():
			if randf() >= 0.35:
				continue
			words.append(String(values[at]))
			var test := randi() % 4
			words.append(Rulebook.TEST_WORDS[test])
			if test > Rulebook.Test.ABOVE:
				continue
			var kind := StringName(kinds[at])
			if kind == Rulebook.SIZE:
				words.append(String(Rulebook.REFERENCES[randi() % Rulebook.REFERENCES.size()]))
				continue
			var ladder: Array = Rulebook.LADDERS[kind]
			var step := float(ladder[randi() % ladder.size()])
			if randf() < 0.15:
				var i := randi() % (ladder.size() - 1)
				step = [(float(ladder[i]) + float(ladder[i + 1])) * 0.5, float(ladder[0]) * 0.5,
					float(ladder[ladder.size() - 1]) * 1.25][randi() % 3]
				edges["off the ladder"] += 1
			words.append(Rulebook.number(step))
	var outputs: Array = []
	for out: StringName in vocab.get("outputs"):
		var output: Object = (vocab.get("outputs") as Dictionary)[out]
		if StringName(output.get("needs")) != Rulebook.BEARING or bearing:
			outputs.append(out)
	var named: StringName = outputs[randi() % outputs.size()]
	words.append(Rulebook.ARROW)
	words.append(String(named))
	var options: Array = (vocab.get("outputs") as Dictionary)[named].get("options")
	if not options.is_empty():
		words.append(Rulebook.number(float(options[randi() % options.size()])))
	return " ".join(words)


## **What is wrong with [param list] by §6.2's limits, as this probe reads them**:
## one to MOST_RULES rules; each it can read reading a declared input -- or
## always, with no test -- with at most one test on each value it carries, each
## on a value it carries, against a step or, for a size, a reference; doing a
## declared output, at one of its options where it takes one; a turn only on an
## input with a bearing; claiming and needing what its parts say. Empty when
## nothing is.
func _flaws(list: RefCounted, vocab: RefCounted) -> String:
	var rules: Array = list.get("rules")
	if rules.is_empty() or rules.size() > Drop.MOST_RULES:
		return "%d rules" % rules.size()
	var owners: Dictionary = vocab.get("owners")
	for rule: Object in rules:
		if bool(rule.get("inert")):
			continue
		var name := StringName(rule.get("input"))
		var input: Object = (vocab.get("inputs") as Dictionary).get(name)
		if name != Rulebook.ALWAYS and input == null:
			return "reads %s, which nothing declares" % name
		var seen := {}
		for clause: Object in rule.get("clauses"):
			if input == null:
				return "a test on always"
			var value := StringName(clause.get("value"))
			if seen.has(value):
				return "two tests on %s's %s" % [name, value]
			seen[value] = true
			var at := (input.get("values") as Array).find(value)
			if at < 0 or int(clause.get("at")) != at \
					or StringName(clause.get("kind")) != StringName((input.get("kinds") as Array)[at]):
				return "a test on %s, which %s does not carry" % [value, name]
			var test := int(clause.get("test"))
			if test == Rulebook.Test.BELOW or test == Rulebook.Test.ABOVE:
				if StringName(clause.get("kind")) == Rulebook.SIZE:
					if not Rulebook.REFERENCES.has(StringName(clause.get("ref"))):
						return "a size against %s" % clause.get("ref")
				elif not is_finite(float(clause.get("step"))) or StringName(clause.get("ref")) != &"":
					return "a step of %s" % clause.get("step")
			elif test != Rulebook.Test.RISING and test != Rulebook.Test.FALLING:
				return "a test %d" % test
		var output: Object = (vocab.get("outputs") as Dictionary).get(rule.get("output"))
		if output == null:
			return "does %s, which nothing declares" % rule.get("output")
		var options: Array = output.get("options")
		var option := float(rule.get("option"))
		if options.is_empty() != is_nan(option) or (not is_nan(option) and not options.has(option)):
			return "%s at %s" % [rule.get("output"), option]
		if StringName(output.get("needs")) == Rulebook.BEARING \
				and (input == null or not bool(input.get("bearing"))):
			return "a turn on %s, which carries no bearing" % name
		var needs := int(owners[output.get("owner")])
		if input != null:
			needs |= int(owners[input.get("owner")])
		if int(rule.get("claims")) != int(output.get("claims")) or int(rule.get("needs")) != needs:
			return "%s claims or needs what its parts do not" % rule.get("text")
	return ""


## **The parts [param child] drew new**, one change from [param parent]: where one
## rule changed, its input if that changed and its output if that did. A copy, a
## drop and a swap draw nothing.
func _drawn(parent: RefCounted, child: RefCounted) -> Array[StringName]:
	var out: Array[StringName] = []
	var p: Array = parent.get("rules")
	var c: Array = child.get("rules")
	if p.size() != c.size():
		return out
	var apart: Array[int] = []
	for k in p.size():
		if _rule_key(p[k]) != _rule_key(c[k]):
			apart.append(k)
	if apart.size() != 1 or bool((c[apart[0]] as Object).get("inert")):
		return out
	var x: Object = p[apart[0]]
	var y: Object = c[apart[0]]
	if x.get("input") != y.get("input"):
		out.append(StringName(y.get("input")))
	if x.get("output") != y.get("output"):
		out.append(StringName(y.get("output")))
	return out


## Whether [param part], an input's or output's name, is always's or of an
## owner in [param owners].
func _owned(part: StringName, vocab: RefCounted, owners: int) -> bool:
	if part == Rulebook.ALWAYS:
		return true
	var decl: Object = (vocab.get("inputs") as Dictionary).get(part)
	if decl == null:
		decl = (vocab.get("outputs") as Dictionary).get(part)
	return decl != null \
		and (owners & int((vocab.get("owners") as Dictionary)[decl.get("owner")])) != 0


func _inert_count(list: RefCounted) -> int:
	var n := 0
	for rule: Object in list.get("rules"):
		n += 1 if bool(rule.get("inert")) else 0
	return n


## **A gene this probe declares and nobody else** (behaviour.md §3.5, §12.3 check
## 8): `trial`, an organ that senses a glow -- a bearing and a level -- and
## triggers a flash, which claims a trigger of its own. Declared as its entry in
## genome.gd's DECLARES would be.
const TRIAL := {&"trial": {
	"in": [{"name": &"glow", "bearing": true, "values": {&"level": &"level"}}],
	"out": [{"name": &"flash", "claims": [&"flash"]}],
}}
## Its rules, as a body carries them: flash at a strong glow, turn toward it,
## swim.
const TRIAL_RULES: Array[String] = ["trial.glow level above 0.5 -> trial.flash",
	"trial.glow -> body.turn-toward", "always -> body.swim"]
## Where its glow comes from: a light this far round from north, at any distance.
const TRIAL_LIGHT := 1.0


## **The drop with `trial`'s organ wired** (§3.5 step 3), as food.gd wires a
## gene's: its reader reports, for any body wearing it, a glow from
## [constant TRIAL_LIGHT] at 0.75, at its bearing off that body's nose; its
## trigger counts each flash, by slot.
class TrialDrop extends WatchedDrop:
	var flashes := {}

	func _wire() -> void:
		super._wire()
		_readers[&"trial.glow"] = _read_glow
		_triggers[&"trial.flash"] = _flash

	func _read_glow(_i: int, b: Body) -> Array:
		return [[angle_difference(b.heading, TRIAL_LIGHT), 0.75, TRIAL_LIGHT]]

	func _flash(i: int, _b: Body, _k: int, _report: Array, _before: Variant, _tick: int) -> void:
		flashes[i] = int(flashes.get(i, 0)) + 1


## **8. Modular** (behaviour.md §3.5, §12.3): [constant TRIAL], declared here
## and nowhere else, its reader and trigger wired here ([TrialDrop]) -- no line
## of rulebook.gd, drop.gd, drop_save.gd or any list names it. **In the
## vocabulary of a body that carries it**: its input and output are named, and
## the bit of its owner is in what a body wearing it wears and in what a DNA
## carrying it may draw from. **Drawn by a change**: of two thousand changes of
## the founders' rules under a DNA that carries it, some read its glow and some
## flash, and under one that does not, none; and of a thousand divisions of a
## body that carries it without wearing it, some changed daughters who carry it
## without wearing it draw it -- from what their DNA declares, not their body.
## **Read and acted on by a rule**: a body wearing it on [constant TRIAL_RULES]
## reads its glow, flashes and turns to the light, and one carrying it without
## wearing it does none of it. **Saved and loaded by name**: through the file
## and loaded, its list comes back read and it flashes again; loaded where the
## gene was never declared, its rules are kept inert and written back as they
## came.
func _modular() -> void:
	seed(43)
	FoodField.declare([TRIAL])
	var vocab: RefCounted = FoodField.vocabulary()
	var owners: Dictionary = vocab.get("owners")
	var bit := int(owners.get(&"trial", 0))
	var named: bool = (vocab.get("inputs") as Dictionary).has(&"trial.glow") \
		and (vocab.get("outputs") as Dictionary).has(&"trial.flash") and bit > 0
	var everybody := {&"body": true, &"metabolism": true}
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	var field := TrialDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.desert = 3000.0
	field.sensed_override = 0.6
	add_child(field)
	field.setup_drop(cell)
	field.in_water = false
	var cells: Array = field.get("_cells")
	var p := cell.position
	var plain := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1}
	var wearing := plain.duplicate()
	wearing[&"trial"] = 1
	var w := _pose(field, p + Vector2(700.0, 0.0), 30.0, wearing, 0.0, 0.6)
	var wb: Object = cells[w]
	wb.set("brain", _list(TRIAL_RULES))
	var c := _pose(field, p + Vector2(-700.0, 0.0), 30.0, plain, 0.0, 0.6)
	var cb: Object = cells[c]
	cb.set("dna", wearing.duplicate())
	cb.set("brain", _list(TRIAL_RULES))
	var in_body := (int(wb.get("worn")) & bit) != 0 and (int(cb.get("worn")) & bit) == 0
	var in_dna := bit > 0 and (Rulebook.worn(vocab, cb.get("dna"), everybody) & bit) != 0
	field.log_reads = true
	field.reads.clear()
	for f in 2 * 60:
		field._process(1.0 / 60.0)
	field.log_reads = false
	var reads := [0, 0]
	for read: Array in field.reads:
		if StringName(read[1]) == &"trial.glow":
			if int(read[0]) == w:
				reads[0] += 1
			elif int(read[0]) == c:
				reads[1] += 1
	var flashed := [int(field.flashes.get(w, 0)), int(field.flashes.get(c, 0))]
	var turned: bool = bool(wb.get("holding")) \
		and absf(angle_difference(float(wb.get("steer")), TRIAL_LIGHT)) < 1e-6
	# Drawn by a change, straight -- the drop's own -- under a DNA that carries
	# it and one that does not.
	var founders: RefCounted = FoodField.founders()
	var with := Rulebook.worn(vocab, wearing, everybody)
	var without := Rulebook.worn(vocab, plain, everybody)
	var drawn := [0, 0, 0, 0]
	for n in 2000:
		var a := Rulebook.text_of(Drop.daughter_behaviours(founders, vocab, with)[1])
		var b := Rulebook.text_of(Drop.daughter_behaviours(founders, vocab, without)[1])
		drawn[0] += 1 if a.contains("trial.glow") else 0
		drawn[1] += 1 if a.contains("trial.flash") else 0
		drawn[2] += 1 if b.contains("trial.glow") else 0
		drawn[3] += 1 if b.contains("trial.flash") else 0
	# And at a division: a body at forty carrying it, not wearing it, on the
	# founders' rules, divided a thousand times -- its changed daughters
	# counted by whether they carry it and do not wear it, which is what tells
	# her DNA from her body.
	var changed := 0
	var unworn := 0
	var drew := 0
	for n in 1000:
		var k := _pose(field, p + Vector2(0.0, 900.0), CellBody.DIVIDE_RADIUS, plain, 0.0, 0.3)
		var kb: Object = cells[k]
		kb.set("dna", wearing.duplicate())
		kb.set("brain", null)
		for j: int in field._divide(k, kb):
			var d: Object = cells[j]
			var list: Variant = d.get("brain")
			changed += 1 if list != null else 0
			if list != null and GenomeNode.tier_of(d.get("dna"), &"trial") > 0 \
					and GenomeNode.tier_of(d.get("genome"), &"trial") == 0:
				unworn += 1
				drew += 1 if Rulebook.text_of(list).contains("trial.") else 0
			field.take_out(j)
	# Saved and loaded by name.
	var wrote := DropSave.write(KEEP, DropSave.compose(field.drop_state(), {}))
	var back := DropSave.read(KEEP)
	var cell2 := CellBody.new()
	cell2.radius = CellBody.BASE_RADIUS
	var field2 := TrialDrop.new()
	field2.process_mode = Node.PROCESS_MODE_DISABLED
	field2.sensed_override = 0.6
	add_child(field2)
	if not back.is_empty():
		field2.load_drop(cell2, back["drop"])
	field2.in_water = false
	var w2: Object = (field2.get("_cells") as Array)[w]
	var list2: Variant = w2.get("brain")
	var kept: bool = list2 != null and Rulebook.lines_of(list2) == PackedStringArray(TRIAL_RULES) \
		and _inert_count(list2) == 0 and GenomeNode.tier_of(w2.get("genome"), &"trial") == 1
	for f in 60:
		field2._process(1.0 / 60.0)
	var again := int(field2.flashes.get(w, 0)) > 0
	# Where it was never declared: the game's own vocabulary again.
	FoodField.declare([])
	var cell3 := CellBody.new()
	cell3.radius = CellBody.BASE_RADIUS
	var field3 := WatchedDrop.new()
	field3.process_mode = Node.PROCESS_MODE_DISABLED
	field3.sensed_override = 0.6
	add_child(field3)
	if not back.is_empty():
		field3.load_drop(cell3, back["drop"])
	var list3: Variant = ((field3.get("_cells") as Array)[w] as Object).get("brain")
	var asleep: bool = list3 != null and _inert_count(list3) == 2 \
		and not bool((list3 as RefCounted).get("rules")[2].get("inert"))
	var as_came := false
	for lines: PackedStringArray in field3.drop_state()["behaviours"]["lists"]:
		as_came = as_came or lines == PackedStringArray(TRIAL_RULES)
	_check(("8. modular: a gene declared only here, its reader and trigger wired here -- in the"
		+ " vocabulary (%s), worn by a body that wears it and not by one that only carries it"
		+ " (%s), drawable for a DNA that carries it (%s); of 2,000 changes of the founders'"
		+ " rules under that DNA %d read its glow and %d flash, under one without it %d and %d;"
		+ " of the %d changed daughters of a body carrying it unworn, %d carried it unworn and"
		+ " %d of those drew it; worn, its glow"
		+ " read %d times, %d flashes and turned to the light (%s); carried unworn, read %d"
		+ " times and %d flashes; saved (%s) and loaded by name, its rules back and read (%s)"
		+ " and flashing again (%s); loaded where it was never declared, inert (%s) and written"
		+ " back as they came (%s)") % [str(named), str(in_body), str(in_dna), drawn[0],
		drawn[1], drawn[2], drawn[3], changed, unworn, drew, reads[0], flashed[0],
		str(turned), reads[1], flashed[1], error_string(wrote), str(kept), str(again),
		str(asleep), str(as_came)],
		named and in_body and in_dna and drawn[0] > 0 and drawn[1] > 0 and drawn[2] == 0
		and drawn[3] == 0 and changed >= 800 and unworn >= 250 and drew > 0 and reads[0] > 0
		and flashed[0] > 0
		and turned and reads[1] == 0 and flashed[1] == 0 and wrote == OK and kept and again
		and asleep and as_came)
	field.queue_free()
	field2.queue_free()
	field3.queue_free()
	cell.free()
	cell2.free()
	cell3.free()
	_forget_kept()
	seed(20260930)


# --- The dev app's frame readout (§14.1, §14.2) -------------------------------------------

## Posed as a release build it adds nothing; posed as the dev app it seats its
## stopwatch either side of the water, reads it, steps aside when the water
## stops or the pause page is up, and comes back after. And what the phone gate
## reads, on its own: which frames were dropped, at the rate the game is held to.
func _readout() -> void:
	# A steady 60 Hz phone's own jitter drops nothing, and a frame the display
	# showed twice is dropped. A faster display is held to 60 -- the game has no
	# frame cap -- so a 120 Hz phone at a steady 60 drops nothing either; a
	# slower one is held to its own rate, and one that will not say is taken at 60.
	var at_60 := FrameReadout.dropped(PackedFloat32Array([16.6, 16.8, 17.2, 24.9, 25.1,
		33.3]), 60.0)
	var steady_120 := FrameReadout.dropped(PackedFloat32Array([16.5, 16.7, 16.7, 16.9,
		17.2, 8.3]), 120.0)
	var hitch_120 := FrameReadout.dropped(PackedFloat32Array([16.7, 16.7, 16.7, 33.3]),
		120.0)
	var at_50 := FrameReadout.dropped(PackedFloat32Array([20.0, 20.1, 29.9, 30.1]), 50.0)
	var silent := FrameReadout.dropped(PackedFloat32Array([16.7, 30.0]), -1.0)
	var rates := [FrameReadout.usable_rate(-1.0), FrameReadout.usable_rate(0.0),
		FrameReadout.usable_rate(50.0), FrameReadout.usable_rate(144.0)]
	_check(("a frame is dropped past %.1f periods: 2 of 6 at 60 Hz, jitter included"
		+ " (%.1f %%); a 120 Hz display at a steady 60 drops %.1f %%, and 1 hitch in 4"
		+ " is %.1f %%; at 50 Hz 1 of 4 (%.1f %%); a display that says no rate is held"
		+ " to %s Hz (%.1f %%); held to %s; nothing to count, %.0f")
		% [FrameReadout.DROPPED_AFTER, at_60, steady_120, hitch_120, at_50, str(rates[0]),
		silent, str(rates), FrameReadout.dropped(PackedFloat32Array(), 60.0)],
		absf(at_60 - 100.0 / 3.0) < 1e-4 and steady_120 == 0.0
		and absf(hitch_120 - 25.0) < 1e-4 and absf(at_50 - 25.0) < 1e-4
		and absf(silent - 50.0) < 1e-4 and rates == [60.0, 60.0, 50.0, 60.0]
		and FrameReadout.dropped(PackedFloat32Array(), 60.0) == -1.0)
	# A figure keeps to four glyphs by dropping decimals, so the number column
	# keeps one width whatever the frame does.
	var shown := [FrameReadout.figure(100.0, 1), FrameReadout.figure(99.94, 1),
		FrameReadout.figure(0.534, 2), FrameReadout.figure(12.345, 2),
		FrameReadout.figure(8.26, 1), FrameReadout.figure(1234.56, 1)]
	var widest := 0
	for i in 2000:
		var value := pow(10.0, randf_range(-3.0, 3.99))
		for decimals in [1, 2]:
			widest = maxi(widest, FrameReadout.figure(value, decimals).length())
	_check("a figure keeps to %d glyphs: %s, and the widest of 4,000 below 9,773 takes %d"
		% [FrameReadout.FIGURE_GLYPHS, str(shown), widest],
		shown == ["100", "99.9", "0.53", "12.3", "8.3", "1235"] and widest == 4)
	var host := Node.new()
	add_child(host)
	var water := BusyWater.new()
	host.add_child(water)
	# Whether the pause page is up, as normal_mode.gd answers it.
	var page := [false]
	var covered := func() -> bool: return page[0]
	FrameReadout.posing = ""
	var released := FrameReadout.attach(host, water, covered)
	var alone := host.get_child_count()
	FrameReadout.posing = "dev"
	var readout := FrameReadout.attach(host, water, covered)
	FrameReadout.posing = null
	_check("a release build adds nothing (%d node, readout %s); the dev app adds its table"
		% [alone, released] + " and seats a hand either side of the water (%s | %s)" % [
		_named(host, water.get_index() - 1), _named(host, water.get_index() + 1)],
		released == null and alone == 1 and readout != null
		and _named(host, water.get_index() - 1) == "FrameReadoutOpen"
		and _named(host, water.get_index() + 1) == "FrameReadoutClose")
	if readout == null:
		host.queue_free()
		return
	for i in 40:
		await get_tree().process_frame
	var rows: Array = readout.call(&"_figures")
	var named := []
	for row: Array in rows:
		named.append(row[0])
	var water_ms := float(rows[3][1]) if rows[3][1] != "–" else -1.0
	_check(("over 40 frames it reads, row by row %s: a frame of %s ms (p95 %s), %s %s"
		+ " dropped, the water's %s ms of at least %.2f, and %s bodies stepped of the 3"
		+ " living") % [str(named), rows[0][1], rows[1][1], rows[2][1], rows[2][2],
		rows[3][1], BusyWater.BUSY_USEC / 1000.0, rows[4][1]],
		named == ["frame", "p95", "dropped", "water", "stepped"] and rows[0][1] != "–"
		and rows[1][1] != "–" and rows[2][1].is_valid_float()
		and String(rows[2][2]).begins_with("%")
		and water_ms >= BusyWater.BUSY_USEC / 1000.0 and water_ms < 50.0
		and rows[4][1] == "3")
	water.set_process(false)
	for i in 3:
		await get_tree().process_frame
	var stopped: bool = readout.visible
	water.set_process(true)
	for i in 3:
		await get_tree().process_frame
	_check("it steps aside while the water stands still (%s) and is back when it runs (%s)"
		% ["shown" if stopped else "hidden", "shown" if readout.visible else "hidden"],
		not stopped and readout.visible)
	# **The pause page**: hidden while it is up, and nothing under it counted --
	# not a frame, not the water, which in a pond runs on under the page, and not
	# the gap it leaves. Its frames are made slow here, 30 ms each: counted, they
	# would show. The window's clock stands still with them.
	var frames_before: PackedFloat32Array = readout.call(&"frames_now")
	var water_before: PackedFloat32Array = readout.call(&"water_now")
	var played_before: int = readout.get(&"_played")
	page[0] = true
	var shown_under := 0
	for i in 20:
		await get_tree().process_frame
		if readout.visible:
			shown_under += 1
		OS.delay_msec(30)
	var frames_under: PackedFloat32Array = readout.call(&"frames_now")
	var water_under: PackedFloat32Array = readout.call(&"water_now")
	var played_under: int = readout.get(&"_played")
	page[0] = false
	for i in 12:
		await get_tree().process_frame
	var back: bool = readout.visible
	var after: PackedFloat32Array = readout.call(&"frames_now")
	var played_after: int = readout.get(&"_played")
	var summed := 0.0
	for ms: float in after:
		summed += ms
	# And a tree stopped under it, as the page stops it in single player.
	get_tree().paused = true
	for i in 5:
		await get_tree().process_frame
	var hidden_paused: bool = not readout.visible
	var frames_paused: int = readout.call(&"frames_now").size()
	get_tree().paused = false
	for i in 5:
		await get_tree().process_frame
	_check(("the pause page hides it (shown on %d of 20 frames under it) and it is back"
		+ " when the page closes (%s); under the page %d frames and %d water times"
		+ " counted and its clock moved %d µs; after it the slowest frame in the window"
		+ " is %.1f ms and the clock is the frames it counted, %.1f against %.1f ms; a"
		+ " stopped tree hides it too (%s) and counts nothing (%d)") % [shown_under,
		"shown" if back else "hidden", frames_under.size() - frames_before.size(),
		water_under.size() - water_before.size(), played_under - played_before,
		after[after.size() - 1] if not after.is_empty() else -1.0,
		float(played_after) / 1000.0, summed, "yes" if hidden_paused else "no",
		frames_paused - after.size()],
		shown_under == 0 and back and frames_under.size() == frames_before.size()
		and water_under.size() == water_before.size() and played_under == played_before
		and after.size() >= frames_under.size() + 5 and not after.is_empty()
		and after[after.size() - 1] < 30.0
		and absf(float(played_after) / 1000.0 - summed) < 0.5
		and hidden_paused and frames_paused == after.size())
	host.queue_free()
	await get_tree().process_frame


## **The water's families on the dev app's readout** (lineage.md §4, §6.4):
## over a drop of its own, two rows under the water's -- the hunters' mean
## generation and how many founders they descend from, in the readout's own
## figures and as the drop counts them; over a friend's drop seen from inside
## it, which keeps no record here, a dash each. A release build draws none of it
## ([method _readout]). **And its behaviours** (behaviour.md §7.3): two rows more
## under those, set apart -- how many different lists its hunters carry and the
## share on the founders' rules, in percent. Different by what they say: the
## hunters are put a quarter each on the founders' rules, on a list of their
## own, on that list written another way, and on the founders' rules read again
## into a list of their own -- two behaviours, half unchanged.
func _readout_families() -> void:
	var holder := Node.new()
	add_child(holder)
	var cell := CellBody.new()
	cell.radius = CellBody.BASE_RADIUS
	var field := WatchedDrop.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	holder.add_child(field)
	field.setup_drop(cell)
	# Every hunter put in one of four families, at generations 2 and 4: a mean of
	# 3 and four families, whatever the water drew.
	var k := 0
	for b: Object in field.get("_cells"):
		if bool(b.get("seeded")) and not bool(b.get("inert")) and not bool(b.get("drifter")):
			b.set("lineage", 9000 + k % 4)
			b.set("generation", 2 if k % 2 == 0 else 4)
			k += 1
	if k % 2 == 1:
		for b: Object in field.get("_cells"):
			if bool(b.get("seeded")) and not bool(b.get("drifter")) and not bool(b.get("inert")):
				b.set("generation", 3)
				break
	# Their rules: a quarter each on the founders' rules, on a list of their own,
	# on it written another way, and on the founders' read into a list again.
	var own := _list(["chemocyte.smell level falling -> body.turn-random", "always -> body.swim"])
	var again := _list(["chemocyte.smell falling -> body.turn-random", "always -> body.swim"])
	var theirs := _list(Drop.FOUNDERS)
	var unchanged := 0
	var h := 0
	for b: Object in field.get("_cells"):
		if bool(b.get("seeded")) and not bool(b.get("inert")) and not bool(b.get("drifter")):
			b.set("brain", [null, own, again, theirs][h % 4])
			unchanged += 1 if h % 4 == 0 or h % 4 == 3 else 0
			h += 1
	FrameReadout.posing = "dev"
	var readout := FrameReadout.attach(holder, field)
	FrameReadout.posing = null
	var rows: Array = readout.call(&"_figures") if readout != null else []
	var counts: Array = field.lineage_counts()
	var kinds: Array = field.behaviour_counts()
	field.become_mirror()
	var away: Array = readout.call(&"_figures") if readout != null else []
	var named := []
	for row: Array in rows:
		named.append(row[0])
	var tail := func(of: Array) -> Array:
		return [of[5][1], of[6][1]] if of.size() == 9 else []
	var last := func(of: Array) -> Array:
		return [of[7][1], of[8][1], of[8][2]] if of.size() == 9 else []
	_check(("lineage, the readout: over a drop of its own, rows %s -- generation %s and"
		+ " families %s over its %d hunters (the drop counts %s), the families' two set"
		+ " apart; over a friend's drop, %s") % [str(named), str(tail.call(rows)[0])
		if rows.size() == 9 else "-", str(tail.call(rows)[1]) if rows.size() == 9 else "-", k,
		str(counts), str(tail.call(away))],
		named == ["frame", "p95", "dropped", "water", "stepped", "generation", "families",
			"behaviours", "unchanged"]
		and tail.call(rows) == ["3.0", "4"] and counts == [3.0, 4] and bool(rows[5][3])
		and not bool(rows[6][3]) and tail.call(away) == ["–", "–"])
	var share := 100.0 * float(unchanged) / float(maxi(h, 1))
	_check(("the readout's behaviours (behaviour.md §7.3): over its %d hunters, a quarter each on"
		+ " the founders' rules, a list of their own, that list written another way and the"
		+ " founders' read again -- behaviours %s, unchanged %s %s (the drop counts %s), the"
		+ " two set apart; over a friend's drop, %s") % [h, str(last.call(rows)[0])
		if rows.size() == 9 else "-", str(last.call(rows)[1]) if rows.size() == 9 else "-",
		str(last.call(rows)[2]) if rows.size() == 9 else "-", str(kinds),
		str(last.call(away).slice(0, 2))],
		h >= 40 and kinds.size() == 2 and int(kinds[0]) == 2
		and absf(float(kinds[1]) - share) < 1e-9
		and last.call(rows) == ["2", FrameReadout.figure(share, 1), "%"] and bool(rows[7][3])
		and not bool(rows[8][3]) and last.call(away).slice(0, 2) == ["–", "–"])
	holder.queue_free()
	cell.free()
	await get_tree().process_frame


func _named(parent: Node, index: int) -> String:
	if index < 0 or index >= parent.get_child_count():
		return "nothing"
	return String(parent.get_child(index).name)


# --- Geometry the slow way --------------------------------------------------------------

func _anywhere(c: Vector2, half: float) -> Vector2:
	return c + Vector2(randf_range(-half, half), randf_range(-half, half))


func _dist(a: Vector2, b: Vector2) -> float:
	return _dist_to(a.x, a.y, b)


func _dist_to(x: float, y: float, b: Vector2) -> float:
	var dx := x - b.x
	var dy := y - b.y
	return sqrt(dx * dx + dy * dy)
