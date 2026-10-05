extends RefCounted
## **Your instincts, wired to your body** (docs/design/automation.md §2, §4, §13):
## each declared input to the report of what your organ's frame already sensed,
## each declared output to your body, the tick, and the autopilot's handover.
##
## **What it knows**: the player's wiring. An input is the report `food.gd`'s
## shared `report_*` function makes of what the player's membrane got that frame
## -- the nose, the eyespot, the palps and the beam as the field sensed them for
## the membrane, the call's returns the field keeps for this, the tank, the
## meal clock, a bite not yet felt -- so an instinct reads exactly what a water
## cell's reader would, and senses nothing again (§4.1). An output is the
## water's own trigger, run on [member body] -- a `food.gd` `Body` that holds
## what the instincts hold: the heading, the claims, the random turn, what they
## read last tick -- except the dash, which is the cell's own. `cell.gd` reads
## the claims for its steer, its push, its tail and its dash. **What it does not
## know**: how a list is chosen or changed (`rulebook.gd`'s), the library, a
## screen, or the hand.
##
## **The tick** is the water's: every [constant Drop.LOD_EVERY] frames the run
## steps, on a count of its own that runs whether or not the autopilot drives,
## so the autopilot takes the cell at the next tick, at most eight frames after
## it is switched on. The list is read only while it drives (§12).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Rulebook := preload("res://game/mechanics/rulebook.gd")
const FoodField := preload("res://game/normal/food.gd")
const CellBody := preload("res://game/normal/cell.gd")
const Drop := preload("res://game/normal/drop.gd")
const Catalogue := preload("res://game/genes/catalogue.gd")

## **What the instincts are holding**: a water body's fields, run by the water's
## own triggers -- the heading they steer for, the claims of the last tick, the
## random turn, what they read last tick, the list they act from.
var body := FoodField.Body.new()
## The merged list the autopilot runs (`library.gd`'s), or null for nothing.
var list: Rulebook.Behaviour = null
## **The programs it was merged from**, `[name, lines]` each in order: what the
## replay records (§11). Made again with the list.
var programs: Array = []
## Bumped whenever the list is given again, so a recorder knows when to write it.
var revision := 0
## **Whether the autopilot drives**: the instincts are read on every tick and the
## cell does what they claim.
var driving := false
## Ticks counted since the run began, and the frames toward the next.
var tick := 0
var _frames := 0
## Seconds this cell has been stepped, the clock its meals are timed on.
var clock := 0.0
## When it last ate on [member clock]: -INF for a new cell, which has not.
var ate_at := -INF
## **What the last tick did**: its winners (rulebook.gd's `choose`), every rule's
## state ([enum Rulebook.State]), and the rules that acted, as a mask of their
## places in the list.
var fired: Array = []
var states: Array = []
var acted := 0

var _cell: CellBody = null
var _food: FoodField = null
var _metabolism: Node = null
var _genome: Node = null
## Each declared input to what reports it for the player, and each output to
## what performs it on [member body].
var _readers := {}
var _triggers := {}
var _read_with := Callable()
## The sizes a size is measured against: the player's own mouth and body.
var _refs := {&"mouth": 0.0, &"body": 0.0}


## **Wired to the player's body**: [param cell], the water it senses
## [param food], its [param metabolism] and its [param genome] -- untyped,
## because the genome preloads the cell, as the cell's own field says.
func setup(cell: CellBody, food: FoodField, metabolism: Node, genome: Node) -> void:
	_cell = cell
	_food = food
	_metabolism = metabolism
	_genome = genome
	_read_with = _read
	# Methods, not lambdas: a lambda holds this object, and a table of them on
	# the object itself is a cycle nothing frees.
	_readers = {
		&"metabolism.hunger": _report_hunger,
		&"metabolism.fed": _report_fed,
		&"body.hit": _report_hit,
	}
	# The genes' parts by the names their organs declare them by, as the water's
	# are (food.gd's `wire_parts`): every variant of an organ is read as it is.
	FoodField.wire_parts(_readers, {&"smell": _report_smell, &"shadow": _report_shadow,
		&"touch": _report_touch, &"beam": _report_beam, &"echo": _report_echo}, true)
	_triggers = {}
	for output: StringName in FoodField.vocabulary().outputs:
		var act: Callable = _food.trigger(output)
		if act.is_valid():
			_triggers[output] = act
	# **The dash is your cell's own**, on its cooldown and at its price, fired
	# past the menu's silence the way a water body's dash is fired by its rules.
	FoodField.wire_parts(_triggers, {&"dash": _dash}, false)


# --- What each organ's frame reports (§4.1): food.gd's own reports -----------------

func _report_hunger() -> Array:
	return FoodField.report_hunger(float(_metabolism.get(&"hunger")))


func _report_fed() -> Array:
	return FoodField.report_fed(clock - ate_at)


func _report_hit() -> Array:
	return FoodField.report_hit(_food.player_hit, _food.player_hit_from, _cell.heading)


func _report_smell() -> Array:
	return FoodField.report_smell(_food.own_eye())


func _report_shadow() -> Array:
	return FoodField.report_shadow(_food.own_eye())


func _report_touch() -> Array:
	return FoodField.report_touch(_food.own_eye())


func _report_beam() -> Array:
	return FoodField.report_beam(_food.beams, _food.own_eye().heading)


func _report_echo() -> Array:
	return FoodField.report_echo(_food.player_calls, _food.own_eye(), _food.call_clock())


## `myoneme.dash`, in the water's signature: the cell's own dash.
func _dash(_i: int, _b: FoodField.Body, _k: int, _report: Array, _before: Variant,
		_tick: int) -> void:
	_cell.instinct_dash()


## **A tool's seam: a gene of its own, read for the player** (§13.1, check 20):
## [param input]'s report, as [param report] makes it. Nothing in the game calls
## this; a gene the game declares has its report above.
func register(input: StringName, report: Callable) -> void:
	_readers[input] = report


## And the trigger a tool's gene performs on [member body], in the water's
## signature.
func register_trigger(output: StringName, act: Callable) -> void:
	_triggers[output] = act


## **What [param input] reports for the player now**: nothing for a name with
## nothing wired to it.
func _read(input: StringName) -> Array:
	var reader: Callable = _readers.get(input, Callable())
	return reader.call() if reader.is_valid() else []


## The same, for a page or a probe: every input this player could read.
func report(input: StringName) -> Array:
	return _read(input)


# --- The tick ----------------------------------------------------------------------

## **One frame of the run** (§12): counted toward the tick, and on the tick, the
## list read and acted on -- while the autopilot drives -- and a bite not yet felt
## let go, acted on or not, as a water cell's is on its tick.
func step(delta: float) -> void:
	clock += delta
	_frames += 1
	if _frames % Drop.LOD_EVERY != 0:
		return
	tick += 1
	if driving and list != null:
		_decide()
	_food.player_hit = 0.0


## **One tick of the instincts** (behaviour.md §4.1, automation.md §4.2): read from
## the top with one winner a trigger by `rulebook.gd`, each input read at most
## once and only for an organ the body wears at the level its part needs, and
## each winner performed on [member body] by the water's own trigger. What
## nothing claimed is what a body does on its own: no new heading, no push, and
## its tail beats.
func _decide() -> void:
	_refresh_body()
	Rulebook.choose(list, _read_with, worn(), _refs, body.memory, tick, fired, states)
	body.resting = false
	body.swimming = false
	body.push = 0.0
	body.tail_held = false
	acted = 0
	for won: Array in fired:
		var k := int(won[0])
		if k < 62:
			acted |= 1 << k
		var act: Callable = _triggers.get(list.rules[k].output, Callable())
		if act.is_valid():
			act.call(-1, body, k, won[1], won[2], tick)
	body.hit = 0.0


## The player's body, as [member body] tells the triggers about it: where it is,
## which way it points, its size, its tail's level and the list it acts from.
func _refresh_body() -> void:
	body.pos = _cell.position
	body.heading = _cell.heading
	body.radius = _cell.radius
	body.tail_level = _cell.tail_level()
	body.brain = list
	_refs[&"mouth"] = _cell.gape()
	_refs[&"body"] = _cell.radius


## **What of the vocabulary the player's body has, as the rulebook's bits**
## (§4.1, §4.3): every gene the body wears at the level `genome.gd`'s `level_of`
## answers -- the beam's earned level, every other gene's worn copies -- counted by
## organ (catalogue.gd's `by_organ`), and what every body has. A gene the DNA carries and the body does not wear is not
## there: an instinct for it is asleep.
func worn() -> int:
	var parts := {}
	var tiers: Dictionary = _genome.call(&"tiers")
	for gene: StringName in tiers:
		if int(tiers[gene]) > 0:
			parts[gene] = maxi(int(_genome.call(&"level_of", gene)), 1)
	return Rulebook.worn(FoodField.vocabulary(), Catalogue.by_organ(parts),
		FoodField.everybody())


## **What the programs would do now if the autopilot were on** (automation-ux.md
## §7.1): every rule's state, read from the last frame's reports. **It acts on
## nothing and remembers nothing**: the tick's memory is read through a copy, no
## trigger runs, and nothing is drawn from the random stream.
func dry_run() -> Array:
	if list == null:
		return []
	_refresh_body()
	var memory := body.memory.duplicate(true)
	var out: Array = []
	var said: Array = []
	Rulebook.choose(list, _read_with, worn(), _refs, memory, tick + 1, out, said)
	return said


# --- What the cell reads (cell.gd) -------------------------------------------------

## **The steer for a body facing [param heading]**: in proportion to how far the
## heading the instincts hold is, inside [constant CellBody.HOLD_BAND], so the
## cirrus's lag settles onto it (§4.2). Nothing held, or resting, steers nothing.
func steer_for(heading: float) -> float:
	if not body.holding or body.resting:
		return 0.0
	return clampf(angle_difference(heading, body.steer) / CellBody.HOLD_BAND, -1.0, 1.0)


## **The push's strength** the instincts claimed: 0, a half or full.
func push_strength() -> float:
	return 0.0 if body.resting else body.push


## Whether the instincts hold the tail still: by the flagellum's hold, or a rest
## at its level.
func holds_tail() -> bool:
	return body.tail_held


# --- The handover (§2.2, §2.3) ------------------------------------------------------

## **The autopilot takes the cell**: from its next tick, with nothing held from
## before -- no heading, no turn, no memory, no bite felt long ago.
func engage() -> void:
	driving = true
	_forget()


## **The hand takes it back** (row 36), or a death or nothing left to run: what
## the instincts held goes with it, and the tail beats on its own clock again.
func let_go() -> void:
	driving = false
	_forget()


## **The list the autopilot runs from now**, and the programs it is made of:
## made again whenever the library's order, a switch or a program that is on
## changes (§3.3). **An edit acts at the next tick and clears what the instincts
## held**, as a takeover does (§3.7).
func set_list(merged: Rulebook.Behaviour, from: Array) -> void:
	list = merged
	programs = from
	revision += 1
	_forget()


## **A meal**: a cell, a floc, or one chewed apart (§4.1).
func ate() -> void:
	ate_at = clock


## **A new body**, at a birth or a return: it has not eaten (§4.1), and its
## instincts hold nothing. The autopilot is the run's to keep or not.
func new_body() -> void:
	ate_at = -INF
	_forget()


## Seconds since the cell last ate, INF for never: what a world's file keeps.
func fed() -> float:
	return clock - ate_at


## Puts back [param seconds] since the cell last ate.
func set_fed(seconds: float) -> void:
	ate_at = clock - seconds


func _forget() -> void:
	body.holding = false
	body.resting = false
	body.swimming = false
	body.push = 0.0
	body.tail_held = false
	body.tumble = -1
	body.tumble_tick = -1
	body.hit = 0.0
	if not body.memory.is_empty():
		body.memory.clear()
	fired.clear()
	states.clear()
	acted = 0
	if _food != null:
		_food.player_hit = 0.0
