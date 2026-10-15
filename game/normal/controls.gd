extends Control
## **The drawn controls: one for each thing the hand can do** (docs/design/
## gene-controls.md). The owner, 2026-10-15: *"No more controls without buttons.
## Add a proper control element for each gene (small button if binary entry, a
## slider if analogic entry, etc.) the control type must reflect the gene's
## behavior."* So open water is never a control: every steer, push, dash, hold and
## cling is a drawn object, and its shape says how the gene behaves.
##
## - **turn**: the body's steering, which the `cirrus` makes faster. Analogue,
##   left and right, and nothing once let go -- so a slider across the bottom-left
##   corner, a knob in a channel that comes home the moment nothing holds it. It is
##   always there: a body with no cirrus still turns, slowly.
## - **every part a worn gene declares with a `"button"`** (gene.gd's `declares`),
##   by the part's own kind. A `held` part is a pad that acts while it is held (the
##   tail's hold, the cling). A `tap` part is a pad that fires once on the press
##   (the dash). A `lever` part is a slider pushed up from rest, which acts at that
##   strength while it is held and drops back when it is let go (the push).
##
## **The controls are a readout of the genome** (gene-lines-and-the-pause-target.md
## §4.1): a gene's control arrives with the gene, and goes with it. The pads stack
## up the right edge from the corner -- taps first, so the dash has the corner --
## and the levers stand in the bottom row inboard of them.
##
## **This node never enters the GUI pass, and that is not tidiness.** It is a
## `Control` for its rect and nothing else: `MOUSE_FILTER_IGNORE`, no children,
## no `gui_input`, no focus. normal_mode.gd's own comment records what a
## `MOUSE_FILTER_STOP` control in the playfield costs -- Godot hit-tests a drag
## afresh whenever the press did not land on a `Control`, and a STOP control
## handed a pointer event consumes it whether it wanted it or not, which cost a
## release blocker on the genome strand. A slider in the bottom-left corner is
## that same defect in the corner a thumb actually rests in. Everything here is
## hit-tested by hand, and the two nodes that already own input in their own
## phase drive it: cell.gd while the cell is swimming, normal_mode.gd from the
## pinch of a division onward. They call [method press], [method adopt],
## [method move] and [method release] and nothing else; [method hit] is the one
## place a rect meets a position and it is reached only from the first two of
## those, inside this file.
##
## **One pointer per control, not one pointer.** `_owner` maps a touch index (or
## [constant POINTER_MOUSE]) to the control it grabbed at the press, and every
## later event of that gesture is dispatched on whose finger it is rather than
## on what it is over. That is what lets the turn and the push be held at once,
## and a dash be fired while the turn is deflected.
##
## **Interface subtracts light; the body emits it.** The membrane's grammar is
## *light, at a bearing, means a sensation*, so a control at the rim has to be a
## dark, hard-edged object that occludes. Rounded rectangles, never circles -- a
## ring is the shape the water is made of. The marks are the organism's own
## glyphs in the organ's own hue, at [constant MARK_REST].
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Cilia := preload("res://game/vision/cilia.gd")
## The organs the controls work the body through, found by what each provides.
const Catalogue := preload("res://game/genes/catalogue.gd")

# --- What there is to hold --------------------------------------------------

## Nothing under the point.
const NONE := -1
## **The turn**: the body's own steering, always drawn.
const TURN := 0
## **A gene's control**: the first is this id, the next one more, and so on -- one
## per part of [member _parts], in its order.
const PART := 1

## **The kinds a part's control may be** (gene.gd's `declares`).
const HELD := &"held"
const TAP := &"tap"
const LEVER := &"lever"

## The mouse, as a pointer index. Touch indices are >= 0, so -1 is free.
const POINTER_MOUSE := -1

# --- Geometry (docs/design/controls.md §2; gene-controls.md §3) --------------
# One baseline. Every pad is 96 canvas px square, bottom-aligned, EDGE from the
# bottom and from its own side -- the launcher's `edge_margin` and PauseTap's own
# offsets, so the game has one margin and not three. At canvas height 720 the
# bottom row occupies y 576 .. 672.

const EDGE := 48.0
## 96 canvas px is 9.1 mm at 2400x1080 -- the ~9 mm perception.md §3 says a
## thumb actually needs, and twice CLAUDE.md's 48 px floor, which is a floor for
## a finger on a precise target and not for a thumb bracing a phone.
const BOX := 96.0
## Between two controls, because a mis-hit there is a different verb.
const PAD_GAP := 24.0
## The turn's well: twice a pad across, so the knob has a throw each way.
const STICK_W := 192.0
const KNOB := 56.0
## Full-scale deflection, each way, from the knob's home. 4.5 mm of thumb roll
## at 2400x1080: a slider you pivot rather than a drag you reach for.
const THROW := 48.0
## Below this the knob is home. Remapped rather than clipped, so the first
## degree of steer past it is the first degree of steer.
const DEAD := 6.0
## The channel a knob rides: 6 px across the well's waist, and a slot rather than
## a bowl. A bowl promises a second axis the simulation does not have.
const TRACK_H := 6.0
## **A lever's travel**, from rest at the bottom to full at the top: the turn's
## whole throw, one way. Its well is a pad wide and this much taller than one, so
## the knob rests on the bottom row's centre line, beside the pads.
const LEVER_THROW := 96.0
const LEVER_H := BOX + LEVER_THROW

# --- The marks --------------------------------------------------------------

## Alpha every mark is drawn at. Set by measurement, not by eye (controls.md
## §4): at 0.42 the loudest block was a dead heat with the figure, and a dead heat
## is not losing.
const MARK_REST := 0.36
## Held. On a phone that is under the thumb; it is for the desktop cursor, for
## the light that spills past a fingertip, and -- at a division -- for being the
## only confirmation a lean has ever had.
const MARK_HELD := 0.92
## **A tap recharging** -- the dash on its cooldown: its mark at this share of
## rest, and a line along the foot of its well filling back up, so the pad says
## *not yet* and *how long* without a word.
const MARK_COOLING := 0.35
const RECHARGE_H := 3.0
const RECHARGE_INSET := 14.0

## **The organ the turn is drawn as** -- the `cirrus`, which steers -- and its hue,
## found by what it provides. `static var` rather than `const` because a constant
## expression in GDScript cannot contain a call.
static var TURN_ORGAN: StringName = Catalogue.first_provider(&"turn_rate")
static var TURN_HUE: Color = Cilia.hue_for(&"turn_rate")
## Hold -- `flagellum`, the tail it holds still: moving's shade 0 (gene-looks.md
## §1), the hue of its mark.
static var HOLD_HUE: Color = Cilia.hue_for(&"impulse_speed")
## **The push's hue and the dash's organ**, which the instincts page draws its
## chips for those actions in (programs_page.gd): here, beside the turn's and the
## hold's, so the marks of one action are asked of one place.
static var PUSH_HUE: Color = Cilia.hue_for(&"push_accel")
static var DASH_ORGAN: StringName = Catalogue.first_provider(&"dash_speed")

## [method Cilia.draw_slot_dart] owns its own alpha -- 0.95 on the dart -- and
## it is shared with the pause strand and the choosing screen, so it is not
## forked to take one. The mark is quietened by dimming the *tone* instead:
## over a near-black well, `tone * k` at alpha 0.95 composites as `tone` at
## alpha `0.95 * k`.
const DART_INK := 0.95
## **No compass bezel on a control.** `draw_slot_dart` draws a ring around its
## dart, and in its home use that ring is the compass the dart is a needle on --
## *this is a bearing around the body*. A control has no bearing to be on, and
## a circle is the one shape diegetic-hud.md section 4 forbids by name.
const DART_RING := false
## Slot 1 is the starboard cirrus arc, bearing 92.5 degrees -- a dart that
## points to starboard; the port dart is the same call under a mirror. Slot 0 is
## the nose, bearing 0 -- a dart that points the way you go, which is up a lever.
const DART_SLOT := 1
const DART_AHEAD := 0
## The turn's darts sit at each end of the channel, small because that is all the
## room there is: the knob is 56 wide and travels 96, so a 192 px well leaves 20
## px at each end. A dart any bigger would be under the knob at full deflection,
## which is the one moment it is being asked about. A lever's sits at its top.
const STICK_DART_R := 7.0
const STICK_DART_X := 13.0

## **A pad's organ**: the gene's own tile -- the same glyph the pause screen draws
## beside that gene's name -- at this scale, seated this far down: the tile is a
## dome, its arc opening upward and nothing below its own centre, and 18 puts
## equal air above its topmost stroke and below its arc.
const TILE_SCALE := 2.0
const TILE_SEAT := 18.0
## **A knob's organ**: the same tile, smaller, riding the knob -- so the slider
## that turns carries the cirrus, and the lever that pushes the axoneme.
const KNOB_TILE_SCALE := 0.95
const KNOB_TILE_SEAT := 9.5

## `hold` is **one stroke of the tail's wave running into a stop bar**
## (automation-ux.md §6.2): a polyline 64 px wide, 1.25 wavelengths, its swing
## of 8 px damped to flat over the first 62 % of it, and a bar 26 px tall 6 px
## past its end. The same picture the instincts page puts on the hold's chip --
## the tail's own tile would say *swim*, and this pad says *stop swimming*.
const HOLD_PART := &"hold"
const HOLD_SPAN := 64.0
const HOLD_WAVES := 1.25
const HOLD_AMP := 8.0
const HOLD_DAMPED := 0.62
const HOLD_STEPS := 24
const HOLD_WIDTH := 2.6
const HOLD_BAR := 26.0
const HOLD_BAR_WIDTH := 3.2
const HOLD_BAR_GAP := 6.0

## pointer index -> control id, for the life of that gesture.
var _owner: Dictionary = {}
## The turn's knob, offset from home in canvas px, -THROW .. +THROW.
var _stick_x := 0.0
## **Each lever's knob**, by its part's qualified name, 0 .. LEVER_THROW up from
## rest. Keyed by part and not by id, so a gene arriving ahead of it in the list
## never hands its push to another control.
var _lever_up: Dictionary = {}
## **The parts drawn**, `[part, name, organ, level, kind]` each (`cell.gd`'s
## `buttons`), in order: control [constant PART] + k is the k-th.
var _parts: Array = []
## Each part's place: its row up the pad column, or its column inboard of it for
## a lever. Made with [member _parts].
var _places := PackedInt32Array()
## **How much of its wait a tap has left**, 0 .. 1, by its own name (`cell.gd`'s
## `cooling`): drawn as a pad recharging.
var _cooling: Dictionary = {}
var _acting := true

var _well: StyleBoxFlat = null
var _well_lit: StyleBoxFlat = null
var _knob: StyleBoxFlat = null
var _knob_lit: StyleBoxFlat = null
var _track: StyleBoxFlat = null


func _ready() -> void:
	# Belt and braces on top of the scene: this node is a rect and a picture,
	# and it must never be handed a pointer event by the GUI.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# The layout is derived from `size` every frame it is drawn, so a viewport
	# that changes shape has to repaint. Nothing here asks for a window.
	resized.connect(queue_redraw)


## Handed the four slabs rather than building them, so the wells a thumb presses
## are literally the same object the pause target is made of. normal_mode.gd
## owns `_well()`; one copy of that builder is the point.
func setup(wells: Dictionary) -> void:
	_well = wells.get(&"well")
	_well_lit = wells.get(&"well_lit")
	_knob = wells.get(&"knob")
	_knob_lit = wells.get(&"knob_lit")
	_track = StyleBoxFlat.new()
	_track.bg_color = Color(0.855, 0.953, 0.933, 0.07)
	_track.set_corner_radius_all(int(TRACK_H * 0.5))
	queue_redraw()


## What is on screen this frame. [param shown] is the whole block; [param quiet]
## is the pinch of a division, where the genes' controls go and the turn stays;
## [param parts] is `cell.gd`'s `buttons`, a control each -- **a control exists
## only while the gene that works it does**; [param cooling] is `cell.gd`'s
## `cooling`, how much of its wait each tap has left.
func update(shown: bool, quiet: bool, parts: Array = [], cooling: Dictionary = {}) -> void:
	var acting := not quiet
	if cooling != _cooling:
		_cooling = cooling.duplicate()
		queue_redraw()
	if visible == shown and _acting == acting and _parts == parts:
		return
	visible = shown
	_acting = acting
	if _parts != parts:
		_set_parts(parts)
	# A control that stopped being drawn cannot stay held: the thumb on it is
	# now a thumb on open water, which is inert. Done here rather than by the
	# caller so the two cannot disagree.
	for pointer: int in _owner.keys():
		if not _live(_owner[pointer]):
			_owner.erase(pointer)
	for part: StringName in _lever_up.keys():
		if not _held_part(part):
			_lever_up.erase(part)
	if not shown:
		_owner.clear()
		_lever_up.clear()
		_stick_x = 0.0
	queue_redraw()


## **A new list of parts**: each placed, and every finger that held a part's
## control moved to wherever that part is now, by its name -- or let go, for a
## part that went.
func _set_parts(parts: Array) -> void:
	var held_by := {}
	for pointer: int in _owner:
		var id: int = _owner[pointer]
		held_by[pointer] = &"" if id == TURN else part_of(id)
	_parts = parts.duplicate()
	_places.resize(_parts.size())
	var pads := 0
	for want: StringName in [TAP, HELD]:
		for k in _parts.size():
			if kind_of(PART + k) == want:
				_places[k] = pads
				pads += 1
	var levers := 0
	for k in _parts.size():
		if kind_of(PART + k) == LEVER:
			_places[k] = levers
			levers += 1
	for pointer: int in held_by:
		if held_by[pointer] == &"":
			continue
		var id := _id_of(held_by[pointer])
		if id == NONE:
			_owner.erase(pointer)
		else:
			_owner[pointer] = id


# ---------------------------------------------------------------------------
# Geometry. Bottom-anchored and corner-anchored, so the baseline is identical
# at 1280x720 and at 2400x1080 -- the canvas is 720 tall at both -- and the two
# blocks slide outward with the extra width instead of reflowing.
# ---------------------------------------------------------------------------

func rect_of(id: int) -> Rect2:
	var top := size.y - EDGE - BOX
	if id == TURN:
		return Rect2(EDGE, top, STICK_W, BOX)
	var k := id - PART
	if k < 0 or k >= _parts.size():
		return Rect2()
	var place := float(_places[k])
	if kind_of(id) == LEVER:
		# Inboard of the pad column, one column further in for each lever.
		return Rect2(size.x - EDGE - BOX - (PAD_GAP + BOX) * (place + 1.0),
			size.y - EDGE - LEVER_H, BOX, LEVER_H)
	# **A pad**: stacked up the right edge from the corner, where the right thumb
	# rests and reaches up from.
	return Rect2(size.x - EDGE - BOX, top - (BOX + PAD_GAP) * place, BOX, BOX)


## Which control is drawn at all right now.
func _live(id: int) -> bool:
	if not visible:
		return false
	if id == TURN:
		return true
	return id >= PART and id - PART < _parts.size() and _acting


## The control under a canvas point, or [constant NONE]. **The only place a rect
## is ever compared against a position**, and it is consulted at first contact
## only -- from [method press] and [method adopt], both in this file. Every
## later event of a gesture is dispatched on whose finger it is, so nothing ever
## asks what is under a finger now.
func hit(at: Vector2) -> int:
	for id in _parts.size() + PART:
		if _live(id) and rect_of(id).has_point(at):
			return id
	return NONE


## **The kind of control [param id] is**: [constant HELD], [constant TAP] or
## [constant LEVER] for a part's, `&""` for the turn or nothing.
func kind_of(id: int) -> StringName:
	var k := id - PART
	if k < 0 or k >= _parts.size():
		return &""
	return StringName(_parts[k][4])


## **The part [param id] works, by its own name** -- `dash`, `cling` -- or `&""`
## for the turn or nothing.
func name_of(id: int) -> StringName:
	var k := id - PART
	if k < 0 or k >= _parts.size():
		return &""
	return StringName(_parts[k][1])


## The part [param id] works, by its qualified name -- `myoneme.dash` -- or `&""`.
func part_of(id: int) -> StringName:
	var k := id - PART
	if k < 0 or k >= _parts.size():
		return &""
	return StringName(_parts[k][0])


## The control of the part qualified [param part], or [constant NONE].
func _id_of(part: StringName) -> int:
	for k in _parts.size():
		if StringName(_parts[k][0]) == part:
			return PART + k
	return NONE


func _held(id: int) -> bool:
	for pointer: int in _owner:
		if _owner[pointer] == id:
			return true
	return false


func _held_part(part: StringName) -> bool:
	var id := _id_of(part)
	return id != NONE and _held(id)


# ---------------------------------------------------------------------------
# The gesture. Three calls, and the only state they keep is whose finger owns
# what -- never what is under a finger now.
# ---------------------------------------------------------------------------

## A press at [param at]. Returns the control it landed on, or [constant NONE]
## for open water, which is inert.
func press(pointer: int, at: Vector2) -> int:
	if not _one_pointer(pointer):
		return NONE
	if _owner.has(pointer):
		return _owner[pointer]
	var id := hit(at)
	if id == NONE:
		return NONE
	_owner[pointer] = id
	_aim(id, at)
	queue_redraw()
	return id


## A drag. True when that pointer belongs to a control, whatever it is over now:
## a thumb that rolls off the edge of the control it is holding keeps holding it.
func move(pointer: int, at: Vector2) -> bool:
	if not _owner.has(pointer):
		return false
	if _aim(_owner[pointer], at):
		queue_redraw()
	return true


## **A thumb already down is adopted**, and only onto the turn. Its press
## happened before there was anything to lean at -- during the quickening, or
## before the pinch -- so the only event that finger will ever produce is a
## drag. Refused for every gene's control, none of which is a lean.
func adopt(pointer: int, at: Vector2) -> int:
	if not _one_pointer(pointer):
		return NONE
	if _owner.has(pointer):
		return _owner[pointer]
	if hit(at) != TURN:
		return NONE
	_owner[pointer] = TURN
	_aim(TURN, at)
	queue_redraw()
	return TURN


## A release. Returns what was let go, or [constant NONE] if that pointer was
## never ours.
func release(pointer: int) -> int:
	if not _owner.has(pointer):
		return NONE
	var id: int = _owner[pointer]
	_owner.erase(pointer)
	# A slider that stayed deflected would act forever. Its knob comes home the
	# instant nothing is holding it out.
	if id == TURN and not _held(TURN):
		_stick_x = 0.0
	elif kind_of(id) == LEVER and not _held(id):
		_lever_up.erase(part_of(id))
	queue_redraw()
	return id


## **Godot emulates a mouse from every touch**, so on a phone each press arrives
## twice -- once as itself and once as a click at the same point -- and left
## alone the pair would fill the table with a phantom finger holding the control
## the real one is on. The rule is stated instead: **a real touch evicts the
## emulated mouse, and the mouse does not claim while a finger is down.** A
## desktop mouse is untouched, because on a desktop no touch ever arrives.
##
## Returns false when this pointer must not claim anything.
func _one_pointer(pointer: int) -> bool:
	if pointer >= 0:
		_owner.erase(POINTER_MOUSE)
		return true
	for held: int in _owner:
		if held >= 0:
			return false
	return true


## Drops every pointer. Called beside `cell.release()` wherever a finger still
## down must stop meaning anything: the pause screen opening, the app losing
## focus, the autopilot taking the cell.
func let_go() -> void:
	if _owner.is_empty() and _stick_x == 0.0 and _lever_up.is_empty():
		return
	_owner.clear()
	_stick_x = 0.0
	_lever_up.clear()
	queue_redraw()


## **A slider's knob follows the finger, absolutely**: a fixed slider's whole
## worth is a **known centre**, and one that recentred on every press would be a
## drag on open water with a picture on it. Returns whether [param id] has a knob.
func _aim(id: int, at: Vector2) -> bool:
	if id == TURN:
		_stick_x = clampf(at.x - rect_of(TURN).get_center().x, -THROW, THROW)
		return true
	if kind_of(id) == LEVER:
		_lever_up[part_of(id)] = clampf(_lever_rest(rect_of(id)) - at.y, 0.0, LEVER_THROW)
		return true
	return false


## Where a lever's knob rests: on the bottom row's centre line.
func _lever_rest(box: Rect2) -> float:
	return box.end.y - BOX * 0.5


## A knob's offset past [constant DEAD], remapped to 0 .. 1 of [param throw].
static func _past_dead(offset: float, throw: float) -> float:
	if absf(offset) <= DEAD:
		return 0.0
	return clampf((offset - signf(offset) * DEAD) / (throw - DEAD), -1.0, 1.0)


# ---------------------------------------------------------------------------
# What the cell asks: the turn, and each part by its own name.
# ---------------------------------------------------------------------------

## The turn, -1 hard to port .. +1 hard to starboard, while it is held.
func steer() -> float:
	if not _held(TURN):
		return 0.0
	return _past_dead(_stick_x, THROW)


## True while the turn is held. At a division that is what decides the lean,
## because a thumb parked on it sits at canvas x 144 whichever way it is pushing
## -- the port half either way. The screen half stays live for a finger anywhere
## else, and it is the floor.
func steering() -> bool:
	return _held(TURN)


## **True while the pad of the part named [param name]** -- `cling`, `hold` --
## **is held.** `cell.gd` asks it of the parts its body has.
func holds(name: StringName) -> bool:
	for k in _parts.size():
		if StringName(_parts[k][1]) == name and _held(PART + k):
			return true
	return false


## **How far the lever of the part named [param name] is pushed**, 0 .. 1, while
## it is held -- `push` -- and 0 for one at rest, let go or not there.
func lever(name: StringName) -> float:
	var most := 0.0
	for k in _parts.size():
		if StringName(_parts[k][1]) != name or kind_of(PART + k) != LEVER:
			continue
		if _held(PART + k):
			most = maxf(most, _past_dead(float(_lever_up.get(_parts[k][0], 0.0)),
				LEVER_THROW))
	return most


# ---------------------------------------------------------------------------
# Drawing.
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _well == null:
		return
	for id in _parts.size() + PART:
		if not _live(id):
			continue
		var box := rect_of(id)
		var lit := _held(id)
		draw_style_box(_well_lit if lit else _well, box)
		var ink := MARK_HELD if lit else MARK_REST
		if id == TURN:
			_draw_turn(box, lit, ink)
			continue
		var k := id - PART
		var organ := Catalogue.first_key(StringName(_parts[k][2]))
		match kind_of(id):
			LEVER:
				_draw_lever(box, organ, float(_lever_up.get(_parts[k][0], 0.0)), lit, ink)
			_:
				var waiting := float(_cooling.get(_parts[k][1], 0.0))
				if waiting > 0.0:
					ink *= MARK_COOLING
					_draw_recharge(box, 1.0 - waiting)
				if StringName(_parts[k][1]) == HOLD_PART:
					draw_hold_mark(self, box.get_center(), ink)
				else:
					Cilia.draw_tile_organ(self, organ, 1,
						box.get_center() + Vector2(0.0, TILE_SEAT), ink, TILE_SCALE)


## The turn: a channel across the well's waist, a dart at each end pointing the
## way that end turns you, and the knob carrying the cirrus.
func _draw_turn(box: Rect2, lit: bool, ink: float) -> void:
	var mid := box.get_center()
	var knob := mid + Vector2(_stick_x, 0.0)
	_draw_track(Rect2(mid.x - THROW, mid.y - TRACK_H * 0.5, THROW * 2.0, TRACK_H), knob)
	_draw_dart(Vector2(box.end.x - STICK_DART_X, mid.y), 1.0, ink)
	_draw_dart(Vector2(box.position.x + STICK_DART_X, mid.y), -1.0, ink)
	_draw_knob(knob, TURN_ORGAN, lit, ink)


## A lever: a channel up the well from where the knob rests, a dart at its top
## pointing the way you go, and the knob carrying the organ, [param up] above
## rest.
func _draw_lever(box: Rect2, organ: StringName, up: float, lit: bool, ink: float) -> void:
	var rest := Vector2(box.get_center().x, _lever_rest(box))
	var knob := rest - Vector2(0.0, up)
	_draw_track(Rect2(rest.x - TRACK_H * 0.5, rest.y - LEVER_THROW, TRACK_H, LEVER_THROW),
		knob)
	Cilia.draw_slot_dart(self, DART_AHEAD, Cilia.hue(organ) * (ink / DART_INK),
		Vector2(rest.x, box.position.y + STICK_DART_X), STICK_DART_R, DART_RING)
	_draw_knob(knob, organ, lit, ink)


## **A channel, and never under its knob**: the knob is a watermark with an edge,
## and a track running on through it crossed the organ riding it. So [param run]
## is drawn as the two pieces either side of the knob at [param knob].
func _draw_track(run: Rect2, knob: Vector2) -> void:
	var half := KNOB * 0.5
	var across := run.size.x >= run.size.y
	var from := run.position.x if across else run.position.y
	var to := run.end.x if across else run.end.y
	var at := knob.x if across else knob.y
	for piece: Vector2 in [Vector2(from, minf(at - half, to)), Vector2(maxf(at + half, from), to)]:
		if piece.y - piece.x < 1.0:
			continue
		draw_style_box(_track, Rect2(piece.x, run.position.y, piece.y - piece.x, run.size.y)
			if across else Rect2(run.position.x, piece.x, run.size.x, piece.y - piece.x))


## A knob at [param centre], with [param organ]'s tile riding it.
func _draw_knob(centre: Vector2, organ: StringName, lit: bool, ink: float) -> void:
	draw_style_box(_knob_lit if lit else _knob, Rect2(centre - Vector2(KNOB, KNOB) * 0.5,
		Vector2(KNOB, KNOB)))
	Cilia.draw_tile_organ(self, organ, 1, centre + Vector2(0.0, KNOB_TILE_SEAT), ink,
		KNOB_TILE_SCALE)


## **A tap filling back up**: a line along the foot of its well, [param ready] of
## the way across.
func _draw_recharge(box: Rect2, ready: float) -> void:
	var span := box.size.x - RECHARGE_INSET * 2.0
	draw_style_box(_track, Rect2(box.position.x + RECHARGE_INSET,
		box.end.y - RECHARGE_INSET, span * clampf(ready, 0.0, 1.0), RECHARGE_H))


## **The hold's mark** (automation-ux.md §6.2), centred on [param centre] at
## [param ink] and [param scale]: one stroke of the tail's wave, its swing dying
## away to flat, and the bar it stops at. Static, so the page that names the
## hold draws the same picture on its chip.
static func draw_hold_mark(canvas: CanvasItem, centre: Vector2, ink: float,
		scale: float = 1.0) -> void:
	var tone := Color(HOLD_HUE, ink)
	var span := HOLD_SPAN * scale
	var whole := span + (HOLD_BAR_GAP + HOLD_BAR_WIDTH * 0.5) * scale
	var from := centre.x - whole * 0.5
	var points := PackedVector2Array()
	for i in HOLD_STEPS + 1:
		var u := float(i) / float(HOLD_STEPS)
		var swing := 1.0 - clampf(u / HOLD_DAMPED, 0.0, 1.0)
		points.append(Vector2(from + u * span,
			centre.y + sin(u * HOLD_WAVES * TAU) * HOLD_AMP * scale * swing))
	canvas.draw_polyline(points, tone, HOLD_WIDTH * scale, true)
	var bar_x := from + span + HOLD_BAR_GAP * scale
	var half := HOLD_BAR * scale * 0.5
	canvas.draw_line(Vector2(bar_x, centre.y - half), Vector2(bar_x, centre.y + half), tone,
		HOLD_BAR_WIDTH * scale, true)


## The turn's dart, quietened and -- to port -- mirrored. [param side] is +1 to
## starboard and -1 to port.
func _draw_dart(centre: Vector2, side: float, ink: float) -> void:
	var tone := TURN_HUE * (ink / DART_INK)
	if side > 0.0:
		Cilia.draw_slot_dart(self, DART_SLOT, tone, centre, STICK_DART_R, DART_RING)
		return
	# The arc table has no port lateral slot, so port is starboard under a
	# mirror rather than a second call with a made-up bearing.
	draw_set_transform(centre, 0.0, Vector2(-1.0, 1.0))
	Cilia.draw_slot_dart(self, DART_SLOT, tone, Vector2.ZERO, STICK_DART_R, DART_RING)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
