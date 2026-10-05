extends Node
## **Watching the run back, from both sides.**
##
## The owner's sentence: *record a run, then when you die let me watch a 2-sided
## replay, one normal view and the other with full vision, so I can see what I
## did given my sensors.* The value is precisely the gap between the two panes
## -- what you perceived against what was actually there -- which is the
## principle the project has held since Phase 3, full vision exists to catch the
## membrane lying, turned round and aimed at the player's own mistakes.
##
## This file is the small half of the feature. `panes.gd` is the screen;
## `recorder.gd` is the sixty seconds; this reads one out into the other, and
## hangs two buttons underneath.
##
## **The transport is minimal on purpose.** Play/pause with a loop, one speed
## toggle through 1x, 2x, 4x, 1/4x and 1/2x, and `leave`. No scrub bar, no jump
## buttons, no frame step: the panes are the feature and a video editor grafted
## onto them is the part of the ask that is disproportionate. A button tapped
## sixty times to cross a second is not a control; 1/4x with a pause does the
## same job in one tap. docs/design/replay.md §5 and owner's call 5 in §7.
##
## Nothing here is freed on a death and nothing here is written to disk. Closing
## it is `queue_free()`; the ring dies with the run that made it.
##
## **The water it shows is its own** (docs/design/ocean.md §11): a `Food` made
## here, holding the recorded bodies, the flocs and the rim, and nothing else.
## The run's field is the drop, which outlives the run and which the player
## swims back into after watching, so nothing here ever writes to it.
##
## **In a shared pond, so is everything else** (docs/design/shared-pond.md §5,
## Phase 3). The friend plays on while you watch -- the host's water keeps
## stepping and keeps being sent, dead host or not -- and the wire reads this
## run's own cell and genome on the black: what this cell wears, for PERSON, and
## where it died, for where a returning friend lands. So in a session the
## recording is written onto a cell, a genome and grit of this screen's own
## ([member private_nodes]), and the run's are never touched. The friend is in
## the water it shows, a body in the field's person slot, drawn as the live view
## draws them.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Panes := preload("res://game/replay/panes.gd")
const RecorderNode := preload("res://game/replay/recorder.gd")
const CellBody := preload("res://game/normal/cell.gd")
## The genes (docs/design/gene-catalogue.md): which organ calls, by its stat.
const Catalogue := preload("res://game/genes/catalogue.gd")
const RayFan := preload("res://game/mechanics/ray_fan.gd")
const MotesField := preload("res://game/normal/motes.gd")
const FoodField := preload("res://game/normal/food.gd")
const GenomeNode := preload("res://game/normal/genome.gd")
const SignalBus := preload("res://game/perception/signal_bus.gd")
## For `slot_bearing` alone: the `ampulla`'s arc is not in the ring, because it
## is derivable from the genome the ring already carries.
const Cilia := preload("res://game/vision/cilia.gd")
## **For three numbers**, and they have to be these three: the daughters'
## brightnesses are what the recorder wrote a single `commit` float out of, and
## a second table of them here would be a division that looks different in the
## replay from the one the player just watched. Safe to preload because
## `normal_mode.gd` reaches this file by path and loads it on the press.
const Run := preload("res://game/normal/normal_mode.gd")
## The eye's flare, the run's own envelope (beam-levels.md §8.5).
const Swell := preload("res://game/mechanics/swell.gd")

## Where the transport sits, which is the band the panes gave up. Never over
## them: the membrane's band is 104px deep from every edge, and a bar floating
## over the bottom would sit exactly on the astern channel -- which is where
## *it ate me from behind* is written. §4.4.
const BUTTON_HEIGHT := 48.0
const PLAY_WIDTH := 112.0
const SPEED_WIDTH := 96.0
const LEAVE_WIDTH := 96.0
## **Not 12, and the number comes from the pause screen's own note.** That file
## measured its 56px buttons at about 5.3mm on a 2400x1080 phone and put *48*
## canvas px of dead water between the safe control and the destructive one --
## "do not tighten it back up for looks". Twelve canvas px is 18 device px on
## that phone, about 1.1mm: a thumb going for the speed toggle lands on `leave`.
## `leave` here is reversible -- closing the screen puts the `watch` offer back,
## so a mis-tap costs one tap and not the replay -- which is why this is 32 and
## not the pause screen's 48. Thirty-two is 2.9mm, and the row still clears both
## captions at 1280x720 and at 2400x1080.
const BUTTON_GAP := 32.0
## How far up the band the row of controls starts, under the captions.
const ROW_TOP := 32.0

## **Faster first, then slower** (the owner, 2026-09-29: "the ability to speed
## up the replay after death"). A born cell that never eats lives thirty
## seconds, so the replay is mostly the run-up and the part worth watching is
## the end. A tap goes to 2x and 4x to skim it, and the next tap from 4x drops
## straight to 1/4x -- the one tap a player wants as the death arrives -- then
## 1/2x, then back to 1x. Still one toggle (replay.md §7 row 5). Slower than a
## quarter is a still, and there is a pause button for that; faster than four
## crosses a life in eight seconds, which is a blur.
const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 0.25, 0.5]
## TRANSLATORS: The replay's speed button: how fast the replay plays, as a
## multiple of real time ("2x" is twice as fast, "1/4x" a quarter as fast). The
## same in almost every language; change the "x" only if your language writes a
## multiplication sign differently.
## ROOM: 64 px at 17 px
const SPEED_TEXT: Array[String] = ["1x", "2x", "4x", "1/4x", "1/2x"]

## Set by the run before this scene enters the tree.
var recorder: RecorderNode = null
## **Whether the run's own cell, genome and grit are off limits**, set by the run
## before this scene enters the tree: true in a session (shared-pond.md §5,
## Phase 3), where the wire reads them on the black and this screen writes onto
## nodes of its own instead ([method _make_own]). False is single player, where
## a run keeps nothing and scribbling on its nodes is free -- and is exactly what
## this screen always did.
var private_nodes := false

var _panes: Panes = null
var _cell: CellBody = null
var _motes: MotesField = null
## **The replay's own field**, never the run's. See [method _water].
var _food: FoodField = null
var _genome: GenomeNode = null
## The run's bus, found only so the panes can read the player's light setting
## off it. Nothing here writes to it -- the run's membrane is detached while
## this screen is up and the panes have a bus of their own.
var _bus: SignalBus = null

var _ui: CanvasLayer = null
var _blocker: Control = null
var _play_button: Button = null
var _speed_button: Button = null
var _leave_button: Button = null

var _frame := PackedFloat32Array()
## This cell's loads, read back each frame. One array, written in place.
var _loads := PackedFloat64Array([0.0, 0.0, 0.0])
## Seconds into the window, and the recorded frame the cursor is sitting on.
var _at := 0.0
var _index := 0
var _speed := 0
var _playing := true
## How far each event stream has been replayed, so an event fires once per pass.
var _sensation_at := 0
var _mark_at := 0
var _delta_at := 0
var _daughters: Array = []
## **Your programs and what drove your cell** (automation.md §11), as the
## recording last said: the programs that were on, and `[drives, held, mask]`.
var _programs: Array = []
var _acts: Array = [false, false, 0]
## The flocs the recording has settled and not cleared, by id: when it said so
## and `[place, radius, settle, life]` as it said them. Drawn by time.
var _flocs := {}
## **The eye, as the run drew it** (beam-levels.md §8.4-§8.5). It buds off the
## levels each delta restores, and it flares when a level it is handed rises --
## armed there, and cued by the next recorded beat, exactly as the run does it.
## **Never on a seek**: a rewind forgets every level it has seen, so the first
## pass after one only learns them.
var _eye_flare := Swell.new(Run.EYE_FLARE_RISE, 0.0, Run.EYE_FLARE_FALL)
var _eye_gene: StringName = &""
var _eye_levels := {}
var _view := Vector2(1280.0, 720.0)
## Set by a rewind and answered after the next seek, once the body is back at
## the start of the window, so the world view forgets its history there and not
## at the death it has just left.
var _forget := false
## The nodes [method _make_own] made, never in the tree, freed with this screen.
var _own: Array[Node] = []


func _ready() -> void:
	_frame.resize(RecorderNode.STRIDE)
	_find(get_parent())
	if private_nodes:
		_make_own()
	_food = _water()
	_panes = Panes.new()
	_panes.name = "Panes"
	_panes.watch(_cell, _motes, _food, _genome, _bus)
	add_child(_panes)
	_build_transport()
	_rewind()
	# Ahead of the panes' own layers, which is what makes the first frame the
	# recording's rather than the dead run's.
	process_priority = -10


func _process(delta: float) -> void:
	if recorder == null or recorder.frames() < 2:
		return
	if _playing:
		_at += delta * SPEEDS[_speed]
		# On the replay's clock, so a slowed replay flares slowly too.
		_eye_flare.step(delta * SPEEDS[_speed])
		var span := recorder.span()
		if _at >= span:
			# **Looping, not stopping.** The mistake is usually three seconds
			# long and nobody finds it the first time through.
			_at = 0.0
			_rewind()
	_seek()
	if _forget:
		_forget = false
		_panes.rewound()


## **The nodes of this screen's own go with it.** Never in the tree, so nothing
## frees them but this -- called after every child has left, so no view is
## reading them by then.
func _exit_tree() -> void:
	for node: Node in _own:
		if is_instance_valid(node):
			node.free()
	_own.clear()


# ---------------------------------------------------------------------------
# Playback. The recorded per-frame delta paces this, so a stretch the phone
# rendered at 30 fps replays at the speed it happened.
# ---------------------------------------------------------------------------

func _seek() -> void:
	while _index + 1 < recorder.frames() and recorder.time_of(_index + 1) <= _at:
		_index += 1
	var here := recorder.time_of(_index)
	var next := recorder.time_of(mini(_index + 1, recorder.frames() - 1))
	var u := 0.0 if next <= here else (_at - here) / (next - here)
	recorder.sample(_index, u, _frame)
	_apply_deltas()
	_write_state()
	_fire_events()


## The recorded state, written straight onto the run's own frozen cell, genome
## and grit, which are not simulating and never will again -- *a run keeps
## nothing* of its cell, and `_wake_up()` builds every one of them afresh -- or,
## in a session, onto this screen's own ([member private_nodes]); and onto this
## screen's own field, which is the water as the cell had it, the friend in it.
func _write_state() -> void:
	if _cell != null:
		_cell.position = Vector2(_frame[0], _frame[1])
		_cell.heading = _frame[2]
		_cell.velocity = Vector2(_frame[3], _frame[4])
		_cell.radius = _frame[5]
		_cell.wound = _frame[6]
		_cell.steer = _frame[7]
		# **What it carried** (docs/design/dna-slots.md §13), for the stain on
		# the figure in both panes.
		for k in _loads.size():
			_loads[k] = _frame[RecorderNode.AT_LOADS + k]
		_cell.restore_loads(_loads)
		_panes.set_dose(FoodField.felt_of(_cell.loads, _cell.radius))
	if _food != null:
		for i in RecorderNode.BODIES:
			var at := RecorderNode.AT_BODIES + i * RecorderNode.BODY_FLOATS
			_food.restore_body(i, Vector2(_frame[at], _frame[at + 1]),
				_frame[at + 2], _frame[at + 3], _frame[at + 4])
			_food.restore_loads(i, _frame[at + RecorderNode.BODY_LOADS])
		_write_friend()
		_write_flocs()
		_food.beams = _read_beams()
		_food.ping_fronts = _read_ping_fronts()
		_food.ping_echoes = _read_ping_echoes()
		_food.ping_range = _frame[RecorderNode.AT_PING_RANGE]
		# **Where the organ was**, off the body layout the PLAYER delta now
		# carries. The wavefront leaves the membrane at the `ampulla`'s own arc
		# and both panes read that bearing off the field, so what this needs is
		# the slot the organ was *worn* in -- which is recorded, because it
		# cannot be worked back out of the DNA once a move has parted the two.
		# It still costs no ring floats: a delta is a dictionary.
		_food.ping_bearing = _ping_bearing()
		_food.ping_through = _cell.ping_through() if _cell != null else 0.0
		# **How long a sweep's hits are held**, off the restored level and path
		# (beam-levels.md §7), so both panes fade them as the run did.
		_food.beam_hold = _beam_hold()
		# **Before the world pane draws**, which is what `process_priority`
		# -10 buys: `vision.gd` asks the field who is hunting and draws the
		# three predator rings round the answer. Rounded rather than cast --
		# the float is an index and the lerp is stepped, but -1.0 arriving as
		# -0.9999 would truncate to 0 and put rings on an innocent drifter.
		_food.restore_hunter(int(roundf(_frame[RecorderNode.AT_HUNTER])))
		# **And who killed the cell**, on the frames the recording names it,
		# for the rings `vision.gd` draws when nothing is hunting (§11).
		_food.restore_killer(int(roundf(_frame[RecorderNode.AT_KILLER])))
	if _motes != null:
		for i in RecorderNode.MOTES:
			var at := RecorderNode.AT_MOTES + i * 2
			_motes.restore_point(i, Vector2(_frame[at], _frame[at + 1]))
	if _genome != null:
		_genome.held_remaining = _frame[RecorderNode.AT_HELD]
	_panes.set_division(_read_division())
	# How slack the body was: the body's half of hunger, as the run drew it.
	_panes.set_slack(_frame[RecorderNode.AT_SLACK])
	# The same question the run asks of its genome, asked of the one restored.
	_panes.set_eye(Run.eye_of(_genome, _eye_gene, _eye_flare.value()))
	_panes.push_block(_frame, RecorderNode.AT_MEMBRANE)


## **The friend, where the recording has them** (shared-pond.md §5, Phase 3):
## their body in the field's person slot, nobody when the recording says so, and
## their silence for the world view to fade their presence by. Nothing in a
## recording with no friend in it, which is every single player's.
func _write_friend() -> void:
	if not _food.pond_open():
		return
	var at := RecorderNode.AT_PERSON
	_food.restore_person(Vector2(_frame[at], _frame[at + 1]), _frame[at + 2],
		_frame[at + 3], _frame[at + 4], _frame[at + RecorderNode.PERSON_LOADS],
		_frame[at + RecorderNode.PERSON_WET] > 0.5)
	_panes.set_friend_quiet(_frame[at + RecorderNode.PERSON_QUIET])


## **Every floc the recording has settled, where it lies and as far as it has
## settled by now**: a floc never moves, and its fade is a function of time, so
## it was recorded once and is drawn from that every frame -- on the replay's own
## clock, so a slowed replay settles slowly too.
func _write_flocs() -> void:
	var t := _window(_at)
	for id: int in _flocs:
		var row: Array = _flocs[id]
		var floc: Array = row[1]
		_food.restore_floc(id, floc[0], float(floc[1]), FoodField.floc_settle_after(
			float(floc[2]), float(floc[3]), t - float(row[0])))


## Which way the organ that calls -- the provider of `ping_range`, the
## `ampulla` -- was pointing on the body being watched. The slot is the arc and
## the arc is the bearing, exactly as `normal_mode.gd` resolves it, and it is the
## slot the organ was **worn** in: a gene dropped over its locus takes it out of
## the DNA and leaves the organ on the body, so a body slot survives a DNA that
## no longer mentions the gene at all.
##
## Dead ahead for a run that never wore one -- which also never drew a wave,
## because a cell with no organ that calls has no reach and no pulse in flight.
## Of several, the one the run called from: the first in slot order
## (gene-catalogue.md §5.2).
func _ping_bearing() -> float:
	if _genome == null:
		return 0.0
	var caller := Catalogue.seated_provider(_genome.body_layout(), _genome.tiers(),
		&"ping_range")
	return Cilia.bearing_of(_genome, caller) if caller != &"" else 0.0


## The revisit time of the beam being watched, 0 for a fan that does not sweep
## -- the same number `normal_mode.gd` hands the field live.
func _beam_hold() -> float:
	if _cell == null:
		return 0.0
	var shape := CellBody.beam_shape(_cell.beam_level(), _cell.beam_path(),
		_cell.provider(&"beam_range"))
	return RayFan.revisit_of(int(shape[0]), deg_to_rad(float(shape[1])),
		deg_to_rad(float(shape[2])))


func _read_beams() -> Array:
	var out: Array = []
	for slot in RecorderNode.BEAMS:
		var at := RecorderNode.AT_BEAMS + slot * RecorderNode.BEAM_FLOATS
		if _frame[at + 1] <= 0.0 and _frame[at + 2] <= 0.0:
			continue
		out.append([_frame[at], _frame[at + 1], _frame[at + 2] > 0.5])
	return out


## **The wave going out**, as radii from the organ. Recorded newest-first and
## handed back that way: both views only iterate, and the field's own "oldest
## first" is about which one is about to expire, which a replay never asks.
func _read_ping_fronts() -> Array:
	var out: Array = []
	for slot in RecorderNode.PING_FRONTS:
		var r := _frame[RecorderNode.AT_PING_FRONTS + slot]
		if r <= 0.0:
			continue
		out.append(r)
	return out


## **The echoes coming home**, exactly the four scalars the live field hands the
## views: `[radius, bearing, halfwidth_deg, level]`. A radius of -1 or a level of
## 0 is an empty slot.
##
## These four are **stepped** between recorded frames rather than lerped, and
## [method RecorderNode.sample] is where that is enforced and why: an echo slot
## is not an identity, so slot 2 in two consecutive frames is routinely two
## different bodies.
func _read_ping_echoes() -> Array:
	var out: Array = []
	for slot in RecorderNode.PING_ECHOES:
		var at := RecorderNode.AT_PING_ECHOES + slot * RecorderNode.ECHO_FLOATS
		if _frame[at] <= 0.0 or _frame[at + 3] <= 0.0:
			continue
		out.append([_frame[at], _frame[at + 1], _frame[at + 2], _frame[at + 3]])
	return out


## The four recorded floats turned back into the dictionary the two views read.
## `commit` is unpacked here and nowhere else -- see [method
## RecorderNode._capture_division] for what is in it.
func _read_division() -> Dictionary:
	var double := _frame[RecorderNode.AT_DOUBLE]
	var pinch := _frame[RecorderNode.AT_PINCH]
	if double <= 0.0 and pinch <= 0.0 and _daughters.is_empty():
		return {}
	var out := {"double": double, "pinch": pinch}
	if _daughters.size() != 2:
		return out
	var commit := _frame[RecorderNode.AT_COMMIT]
	out["spread"] = _frame[RecorderNode.AT_SPREAD]
	out["radius"] = CellBody.daughter_radius(CellBody.DIVIDE_RADIUS)
	var fades := [Run.DIVIDE_FADE_IDLE, Run.DIVIDE_FADE_IDLE]
	var sheds := [0.0, 0.0]
	if absf(commit) >= 2.0:
		var going := 0 if commit > 0.0 else 1
		sheds[going] = absf(commit) - 2.0
		fades[going] = Run.DIVIDE_FADE_DIM * (1.0 - sheds[going])
		fades[1 - going] = Run.DIVIDE_FADE
	elif absf(commit) > 0.0:
		var t := clampf(absf(commit)
			/ maxf(Run.DIVIDE_FADE - Run.DIVIDE_FADE_DIM, 0.001), 0.0, 1.0)
		var leaned := 0 if commit > 0.0 else 1
		fades[leaned] = lerpf(Run.DIVIDE_FADE_IDLE, Run.DIVIDE_FADE, t)
		fades[1 - leaned] = lerpf(Run.DIVIDE_FADE_IDLE, Run.DIVIDE_FADE_DIM, t)
	var pair: Array = []
	for side in 2:
		var one: Dictionary = _daughters[side]
		pair.append({
			"tiers": one["tiers"],
			"order": one["order"],
			"fade": fades[side],
			"shed": sheds[side],
		})
	out["bodies"] = pair
	return out


## Genomes, layouts, held samples, the two daughters, the rim and the flocs:
## stepped at the timestamps the recorder wrote them, never interpolated.
func _apply_deltas() -> void:
	var rows: Array = recorder.deltas()
	while _delta_at < rows.size() and float(rows[_delta_at][0]) <= _window(_at):
		var row: Array = rows[_delta_at]
		_delta_at += 1
		match int(row[1]):
			RecorderNode.Delta.PLAYER:
				var state: Dictionary = row[3]
				if _genome != null:
					# **Four registers, and the fourth is not derivable.**
					# `order` is where the DNA keeps its genes and `worn` is
					# where the body keeps its organs; a move parts them, and
					# expressing without the fourth rebuilds the body's slots
					# out of the DNA's -- which is the soma's fringe and the
					# `ampulla`'s wave both drawn on an arc nothing was ever
					# worn on. docs/design/replay.md §4.1.
					_genome.express(state["dna"], state["order"],
						state["body"], state["worn"])
					_genome.restore_levels(state.get("levels", {}))
					_genome.bonus_slots = int(state["bonus"])
					_genome.held_sample = state["sample"]
			RecorderNode.Delta.BODY:
				if _food != null:
					_food.restore_genome(int(row[2]), row[3])
			RecorderNode.Delta.DAUGHTERS:
				_daughters = row[3]
			RecorderNode.Delta.RIM:
				var rim: Array = row[3]
				if _food != null:
					_food.restore_rim(rim[0], float(rim[1]))
			RecorderNode.Delta.SETTLE:
				_flocs[int(row[2])] = [float(row[0]), row[3]]
			RecorderNode.Delta.CLEAR:
				_flocs.erase(int(row[2]))
				if _food != null:
					_food.clear_floc(int(row[2]))
			RecorderNode.Delta.PROGRAMS:
				_programs = row[3]
				_panes.set_programs(_programs)
			RecorderNode.Delta.ACTS:
				_acts = row[3]
				# **The held tail, drawn still** by both views, as it was.
				if _cell != null:
					_cell.restore_held(bool(_acts[1]))
				_panes.set_acts(_acts)
			RecorderNode.Delta.PERSON:
				# **What the friend wears**: their fringe, and the mouth their
				# threat bow is measured by.
				var worn: Array = row[3]
				if _food != null:
					_food.restore_person_genome(worn[0], worn[1])
			_:
				pass
	_watch_levels()


## **A level the replay is handed, rising, arms the flare** -- the run's rule,
## on the recording's levels. A level first seen since a rewind is only learned:
## the pass that restores the window's opening state must not flare for it.
func _watch_levels() -> void:
	if _genome == null:
		return
	for gene: StringName in _genome.levels():
		var at: int = _genome.progression(gene).level()
		if _eye_levels.has(gene) and at > int(_eye_levels[gene]):
			_eye_gene = gene
			_eye_flare.arm()
		_eye_levels[gene] = at


## Sensations back on the replay's own bus, and ground truth straight into the
## world pane's marks. Both are one pass per loop.
func _fire_events() -> void:
	var t := _window(_at)
	var sens: Array = recorder.sensations()
	while _sensation_at < sens.size() and float(sens[_sensation_at][0]) <= t:
		var row: Array = sens[_sensation_at]
		_sensation_at += 1
		var info := {"bearing": row[2], "strength": row[3]}
		if row.size() > 4 and row[4] is Vector3 and row[4] != Vector3.ZERO:
			info["tint"] = row[4]
		_panes.feel(row[1], info)
		# The recorded heartbeat is the flare's cue, as the live one was.
		if row[1] == &"beat":
			_eye_flare.cue()
	var marks: Array = recorder.marks()
	while _mark_at < marks.size() and float(marks[_mark_at][0]) <= t:
		var row: Array = marks[_mark_at]
		_mark_at += 1
		if row[1] == &"struck":
			_panes.mark_struck(row[2])
		elif row[1] == &"gone":
			# How the friend left, as the run told its view: the recorder keeps
			# it where a meal keeps its nutrition.
			_panes.friend_gone(int(row[3]), row[2])
		else:
			_panes.mark_meal(float(row[3]), row[4], row[2])


## Event timestamps are in the run's clock and the cursor runs from zero at the
## start of the window, so everything that reads one against the other goes
## through here.
func _window(at: float) -> float:
	return at + recorder.origin()


func _rewind() -> void:
	_index = 0
	_sensation_at = 0
	_mark_at = 0
	_delta_at = 0
	_daughters = []
	_programs = []
	_acts = [false, false, 0]
	if _cell != null:
		_cell.restore_held(false)
	if _panes != null:
		_panes.set_programs(_programs)
		_panes.set_acts(_acts)
	# The window's flocs are settled again from its first deltas.
	_flocs.clear()
	if _food != null:
		_food.clear_flocs()
	# A seek is not a level-up: the flare goes, and the levels are learned
	# afresh from the window's first delta.
	_eye_flare.clear()
	_eye_levels = {}
	_forget = true


# ---------------------------------------------------------------------------
# The transport. Three controls, all at least 48px, in the 96px band the panes
# gave up. The register is the pause screen's exactly: this is a panel the
# player consults, not a sensory screen.
# ---------------------------------------------------------------------------

func _build_transport() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "Transport"
	_ui.layer = Panes.LAYER_LEGEND + 1

	# **Nothing behind this screen is listening.** A tap anywhere on the black
	# still restarts the run, and the run is still in WAITING behind these
	# panes; a full-rect control that stops the pointer is what keeps a tap
	# meant for `pause` from being a tap meant for `another cell`.
	_blocker = Control.new()
	_blocker.name = "Blocker"
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_blocker)

	# TRANSLATORS: The replay's first button: "pause" while the replay plays, "play"
	# while it is paused. The word is what pressing the button does. The button is
	# fixed, so a long word runs into the speed button beside it.
	# ROOM: 80 px at 17 px
	_play_button = _button(tr("pause"), PLAY_WIDTH)
	_play_button.pressed.connect(_toggle_play)
	_speed_button = _button(tr(SPEED_TEXT[0]), SPEED_WIDTH)
	_speed_button.pressed.connect(_cycle_speed)
	# TRANSLATORS: The replay's last button: close the replay and go back to the
	# game. The same word is the pause screen's button that leaves the game. The
	# replay's button is the narrower: a long word runs into the speed button.
	# ROOM: 64 px at 17 px
	_leave_button = _button(tr("leave"), LEAVE_WIDTH)
	_leave_button.pressed.connect(_close)
	for control: Button in [_play_button, _speed_button, _leave_button]:
		_ui.add_child(control)
	add_child(_ui)

	_relayout()
	get_viewport().size_changed.connect(_relayout)


func _button(text: String, width: float) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_font_size_override("font_size", 17)
	control.add_theme_color_override("font_color",
		Color(0.855, 0.953, 0.933, 0.82))
	control.add_theme_color_override("font_hover_color",
		Color(0.855, 0.953, 0.933, 1.0))
	control.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	control.add_theme_stylebox_override("normal", _slab(0.0))
	control.add_theme_stylebox_override("hover", _slab(0.35))
	control.add_theme_stylebox_override("pressed", _slab(0.5))
	return control


## The pause screen's slab, and the same one: every group on a panel the player
## consults is a surface, with one edge and one radius.
func _slab(lift: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.063, 0.141, 0.125, 0.55 + lift * 0.5)
	box.border_color = Color(0.12, 0.70, 0.58, 0.35 + lift * 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


func _relayout() -> void:
	var rect := get_viewport().get_visible_rect()
	if rect.size.x > 1.0 and rect.size.y > 1.0:
		_view = rect.size
	var total := PLAY_WIDTH + SPEED_WIDTH + LEAVE_WIDTH + BUTTON_GAP * 2.0
	var x := (_view.x - total) * 0.5
	var y := _view.y - Panes.BAND + ROW_TOP
	for pair: Array in [[_play_button, PLAY_WIDTH], [_speed_button, SPEED_WIDTH],
			[_leave_button, LEAVE_WIDTH]]:
		var control: Button = pair[0]
		var width: float = pair[1]
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		control.position = Vector2(x, y)
		control.size = Vector2(width, BUTTON_HEIGHT)
		x += width + BUTTON_GAP


func _toggle_play() -> void:
	_playing = not _playing
	# TRANSLATORS: The replay's first button: "pause" while the replay plays, "play"
	# while it is paused. The word is what pressing the button does. The button is
	# fixed, so a long word runs into the speed button beside it.
	# ROOM: 80 px at 17 px
	_play_button.text = tr("pause") if _playing else tr("play")


func _cycle_speed() -> void:
	_speed = (_speed + 1) % SPEEDS.size()
	_speed_button.text = tr(SPEED_TEXT[_speed])


func _close() -> void:
	var run := get_parent()
	if run != null and run.has_method(&"_replay_closed"):
		run.call_deferred(&"_replay_closed")
	else:
		queue_free()


## **Modal.** Everything is consumed while this screen is up: behind it is a run
## in WAITING, where any tap at all starts the next cell.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_close()
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Finding the run's frozen nodes. By type, from the parent, exactly as
# vision.gd does -- nothing has to hand this screen anything. **Not its field**:
# the water this screen shows is its own.
# ---------------------------------------------------------------------------

func _find(root: Node) -> void:
	if root == null:
		return
	_walk(root)
	if recorder == null:
		for child in root.get_children():
			if child is RecorderNode:
				recorder = child as RecorderNode
				break


## **The replay's own field** (docs/design/ocean.md §11): the recorded bodies in
## their slots, the flocs and the rim, and the cell being watched as its player.
## Never stepped -- every number in it is the recording's -- and the views read
## it as they read a live one. Its not processing is also what tells the marks
## layer that a beam in it is not being cast now. The run's own field, the drop
## the player returns to, is never touched.
func _water() -> FoodField:
	var water := FoodField.new()
	water.name = "Water"
	water.process_mode = Node.PROCESS_MODE_DISABLED
	water.open_replay(_cell, RecorderNode.BODIES)
	# **And the friend's slot**, when the recording has a friend in it: a pond's
	# field, so the world view draws them as it does in a live one.
	if recorder != null and recorder.holds_person():
		water.open_replay_person()
	add_child(water)
	water.set_process(false)
	var rim: Array = recorder.rim() if recorder != null else []
	if rim.size() == 2:
		water.restore_rim(rim[0], float(rim[1]))
	return water


## **A cell, a genome and grit of this screen's own**, in a session
## ([member private_nodes]): copies of the run's as they lie on the black, which
## the recording is then written onto exactly as it would be onto the run's --
## so the panes draw the same thing either way, and the run's are left as the
## death left them. While this screen is up a dead host's guest can come back,
## and lands by where the host's cell died; and the pond tells the other player
## what this cell wears whenever it changes, which a replay of an earlier body
## would otherwise change every loop -- PERSONs a host's referee holds a guest to.
##
## **Never in the tree.** A node that enters it runs its `_ready`, and cell.gd's
## draws from the random stream -- the one the live water is seeded from, which
## goes on stepping under this screen. Freed in [method _exit_tree].
func _make_own() -> void:
	var cell := CellBody.new()
	var genome := GenomeNode.new()
	var motes := MotesField.new()
	_own = [cell, genome, motes]
	cell.genome = genome
	if _cell != null:
		cell.restore_body(_cell.body_state())
		cell.restore_loads(_cell.loads)
		cell.restore_held(_cell.tail_held())
		cell.steer = _cell.steer
	genome.setup(cell)
	if _genome != null:
		genome.set_state(_genome.to_state())
	motes.open_replay(_motes.points() if _motes != null else PackedVector2Array())
	_cell = cell
	_genome = genome
	_motes = motes


func _walk(node: Node) -> void:
	if _cell == null and node is CellBody:
		_cell = node as CellBody
	elif _motes == null and node is MotesField:
		_motes = node as MotesField
	elif _genome == null and node is GenomeNode:
		_genome = node as GenomeNode
	elif _bus == null and node is SignalBus:
		_bus = node as SignalBus
	for child in node.get_children():
		_walk(child)
