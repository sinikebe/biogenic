extends Control
## The drawn controls, for the two schemes that have any.
##
## docs/design/controls.md. The owner asked for "a left right joystick and
## buttons", chosen from the pause menu. There are three schemes and this file
## draws two of them: `stick` is a knob in a channel plus a dash pad, `pads` is
## two turn pads plus a push pad and a dash pad. `anywhere` -- the scheme that
## ships and the default -- draws nothing at all, and under it this node is
## invisible and inert.
##
## **This node never enters the GUI pass, and that is not tidiness.** It is a
## `Control` for its rect and nothing else: `MOUSE_FILTER_IGNORE`, no children,
## no `gui_input`, no focus. normal_mode.gd's own comment records what a
## `MOUSE_FILTER_STOP` control in the playfield costs -- Godot hit-tests a drag
## afresh whenever the press did not land on a `Control`, and a STOP control
## handed a pointer event consumes it whether it wanted it or not, which cost a
## release blocker on the genome strand. A stick in the bottom-left corner is
## that same defect in the corner a thumb actually rests in. Everything here is
## hit-tested by hand, from [method hit], by the two nodes that already own
## input in their own phase: cell.gd while the cell is swimming, normal_mode.gd
## during a division.
##
## **One pointer per control, not one pointer.** `_owner` maps a touch index (or
## [constant POINTER_MOUSE]) to the control it grabbed at the press, and every
## later event of that gesture is dispatched on whose finger it is rather than
## on what it is over. That is what lets `port` and `push` be held at once, and
## a dash be fired while the stick is deflected.
##
## **Interface subtracts light; the body emits it.** The membrane's grammar is
## *light, at a bearing, means a sensation*, so a control at the rim has to be a
## dark, hard-edged object that occludes. Rounded rectangles, never circles -- a
## ring is the shape the water is made of. The marks are the organism's own
## glyphs in the organ's own hue, at [constant MARK_REST].
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

const Cilia := preload("res://game/vision/cilia.gd")
const RunState := preload("res://game/run_state.gd")

# --- What there is to hold --------------------------------------------------

## Nothing under the point.
const NONE := -1
const STICK := 0
const PORT := 1
const STARBOARD := 2
const PUSH := 3
const DASH := 4

## Draw and hit-test order. Never overlapping, so the order is only a
## convention -- but a stated one is cheaper than a proof.
const ORDER: Array[int] = [STICK, PORT, STARBOARD, PUSH, DASH]

## The mouse, as a pointer index. Touch indices are >= 0, so -1 is free.
const POINTER_MOUSE := -1

# --- Geometry (docs/design/controls.md §2) ----------------------------------
# One baseline. Every control is 96 canvas px tall, bottom-aligned, EDGE from
# the bottom and from its own side -- the launcher's `edge_margin` and
# PauseTap's own offsets, so the game has one margin and not three. At canvas
# height 720 every control occupies y 576 .. 672.

const EDGE := 48.0
## 96 canvas px is 9.1 mm at 2400x1080 -- the ~9 mm perception.md §3 says a
## thumb actually needs, and twice CLAUDE.md's 48 px floor, which is a floor for
## a finger on a precise target and not for a thumb bracing a phone.
const BOX := 96.0
## Between the two turn pads, because a mis-hit there is the *opposite* of what
## was asked; and between `push` and `dash` for the same reason.
const PAD_GAP := 24.0
const STICK_W := 192.0
const KNOB := 56.0
## Full-scale deflection, each way, from the knob's home. 4.5 mm of thumb roll
## at 2400x1080: a stick you pivot rather than a drag you reach for.
const THROW := 48.0
## Below this the stick is centred. Remapped rather than clipped, so the first
## degree of steer past it is the first degree of steer.
const DEAD := 6.0
## The channel the knob rides: 6 px across the well's waist, and a slot rather
## than a bowl. A bowl promises a second axis the simulation does not have.
const TRACK_H := 6.0

# --- The marks --------------------------------------------------------------

## Alpha every mark is drawn at. Set by measurement, not by eye: the first pass
## at 0.42 put the `pads` block at 66.4 glance against a 65.2 soma figure, which
## is a dead heat, and a dead heat is not losing.
const MARK_REST := 0.36
## Held. On a phone that is under the thumb; it is for the desktop cursor, for
## the light that spills past a fingertip, and -- at a division -- for being the
## only confirmation a lean has ever had.
const MARK_HELD := 0.92

## `cirrus` / turn and `axoneme` / push, read off the one hue table.
const TURN_HUE := Color(0.36, 0.62, 0.98)
const PUSH_HUE := Color(0.98, 0.44, 0.90)

## [method Cilia.draw_slot_dart] owns its own alphas -- 0.95 on the dart, 0.28
## on its compass ring -- and it is shared with the pause strand and the
## choosing screen, so it is not forked to take one. The mark is quietened by
## dimming the *tone* instead: over a near-black well, `tone * k` at alpha 0.95
## composites as `tone` at alpha `0.95 * k`.
const DART_INK := 0.95
## Slot 1 is the starboard cirrus arc, bearing 92.5 degrees -- a dart that
## points to starboard. The port dart is the same call under a mirror, because
## the arc table has no port lateral slot: the cirrus is a pair worn as one.
const DART_SLOT := 1
## On a turn pad the dart sits **under** the oars, at the foot of the well. The
## first build put it above them and it read as an arrow in a circle -- a button
## icon, not an organ. Below the tuft it is a caption on a body.
const DART_R := 9.0
const DART_LIFT := -30.0
## On the stick the same dart sits at each end of the channel, and it is smaller
## because that is all the room there is: the knob is 56 wide and travels 96, so
## a 192 px well leaves 20 px at each end. A dart any bigger would be under the
## knob at full deflection, which is the one moment it is being asked about.
const STICK_DART_R := 7.0
const STICK_DART_X := 13.0

## The turn pad's oars: the cirrus tuft the body already wears, rooted on the
## same upward dome [method Cilia.draw_tile_organ] uses and **swung the way the
## turn goes, the swing growing across the row**. The last oar has come right
## round to lie along the turn; the first has barely left the vertical. That
## gradient is the mark's whole sentence, and it is the metachronal order a real
## ciliature beats in.
const OARS := 5
## The dome, seated above the dart. Same 187..353 degrees the tile glyph opens
## through, so a turn pad and a gene tile are the same vocabulary.
const OAR_SEAT := -6.0
const OAR_ARC := 12.0
const OAR_FROM := 1.04 * PI
const OAR_TO := 1.96 * PI
const OAR_LEN := 26.0
const OAR_SWING_FROM := 6.0
const OAR_SWING_TO := 95.0
## Where the oar bends, and how much further round the tip has come.
## cilia.gd's own cirrus vocabulary: a knee, and more swing beyond it.
const OAR_KNEE := 0.6
const OAR_BEND := 1.35
const OAR_WIDTH := 2.2

## `push` is **not** the `axoneme` tile glyph. Rendered side by side, `axoneme`
## (306 deg) and `myoneme` (333 deg) are near-twins in shape *and* hue -- both a
## radial burst with a pigment at the heart -- and at 96 px the two pads were
## the same picture. So `push` is three strokes of the body's own metachronal
## wave, with the crests marching forward: **swim is a wave, dash is a burst.**
const WAVE_ROWS := 3
const WAVE_SPAN := 68.0
const WAVE_GAP := 21.0
const WAVE_AMP := 7.0
const WAVE_STEPS := 18
const WAVE_WIDTH := 2.4
## How far the crest of each row lags the one behind it, in wavelengths. The
## wave travels toward the front of the cell, which is the top of the screen,
## which is the way you go.
const WAVE_MARCH := 0.22

## `dash` is the `myoneme` burst -- the same glyph the pause screen draws beside
## that gene's name, so the player meets the mark on the surface where the
## scheme is chosen.
const BURST_SCALE := 2.0
## The tile glyph is a dome: its arc opens upward and it has nothing below its
## own centre, so seating it at the well's centre would hang it off the top.
## 18 is what puts equal air above the topmost stroke and below the arc.
const BURST_SEAT := 18.0

## Which scheme is being drawn. [constant RunState.Scheme.ANYWHERE] draws
## nothing, which is the whole of the shipped scheme being untouched.
var scheme := RunState.Scheme.ANYWHERE

## pointer index -> control id, for the life of that gesture.
var _owner: Dictionary = {}
## Knob offset from home, in canvas px, -THROW .. +THROW.
var _stick_x := 0.0
## Whether `push` and `dash` are drawn at all: the organ that works them has to
## exist, and they go at the pinch of a division because there is nothing left
## for them to do.
var _has_push := false
var _has_dash := false
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
## is the pinch of a division, where the two action pads go and the steering
## control stays; [param push] and [param dash] are the genome -- **a pad exists
## only when the organ that works it does.**
func update(shown: bool, quiet: bool, push: bool, dash: bool) -> void:
	var acting := not quiet
	if visible == shown and _acting == acting and _has_push == push \
			and _has_dash == dash:
		return
	visible = shown
	_acting = acting
	_has_push = push
	_has_dash = dash
	# A control that stopped being drawn cannot stay held: the thumb on it is
	# now a thumb on open water, and under `stick` and `pads` open water is
	# inert. Done here rather than by the caller so the two cannot disagree.
	for pointer: int in _owner.keys():
		if not _live(_owner[pointer]):
			_owner.erase(pointer)
	if not shown:
		_owner.clear()
		_stick_x = 0.0
	queue_redraw()


func set_scheme(value: int) -> void:
	if scheme == value:
		return
	scheme = value
	let_go()
	# **Unconditionally**, and a render is what found that out: cycling from
	# `stick` to `pads` changes neither the node's visibility nor what is held,
	# so neither [method let_go] nor [method update] queued anything and the
	# corner kept drawing the old scheme under the scrim -- with the word
	# beside it already changed. The preview *is* the explanation (§5.1), so a
	# stale one is the one failure this control cannot have.
	queue_redraw()


## True while the water itself is the control, which is the scheme that ships.
## cell.gd reads this rather than the scheme number: under `anywhere` its input
## path is exactly what it was, and that is the contract this file keeps.
func floating() -> bool:
	return scheme == RunState.Scheme.ANYWHERE


# ---------------------------------------------------------------------------
# Geometry. Bottom-anchored and corner-anchored, so the baseline is identical
# at 1280x720 and at 2400x1080 -- the canvas is 720 tall at both -- and the two
# blocks slide outward with the extra width instead of reflowing.
# ---------------------------------------------------------------------------

func rect_of(id: int) -> Rect2:
	var top := size.y - EDGE - BOX
	match id:
		STICK:
			return Rect2(EDGE, top, STICK_W, BOX)
		PORT:
			return Rect2(EDGE, top, BOX, BOX)
		STARBOARD:
			return Rect2(EDGE + BOX + PAD_GAP, top, BOX, BOX)
		PUSH:
			return Rect2(size.x - EDGE - BOX * 2.0 - PAD_GAP, top, BOX, BOX)
		DASH:
			return Rect2(size.x - EDGE - BOX, top, BOX, BOX)
		_:
			return Rect2()


## Which control is drawn at all right now.
func _live(id: int) -> bool:
	if not visible:
		return false
	match id:
		STICK:
			return scheme == RunState.Scheme.STICK
		PORT, STARBOARD:
			return scheme == RunState.Scheme.PADS
		PUSH:
			return scheme == RunState.Scheme.PADS and _has_push and _acting
		DASH:
			return scheme != RunState.Scheme.ANYWHERE and _has_dash and _acting
		_:
			return false


## The control under a canvas point, or [constant NONE]. The only place a rect
## is ever compared against a position.
func hit(at: Vector2) -> int:
	for id: int in ORDER:
		if _live(id) and rect_of(id).has_point(at):
			return id
	return NONE


func _held(id: int) -> bool:
	for pointer: int in _owner:
		if _owner[pointer] == id:
			return true
	return false


# ---------------------------------------------------------------------------
# The gesture. Three calls, and the only state they keep is whose finger owns
# what -- never what is under a finger now.
# ---------------------------------------------------------------------------

## A press at [param at]. Returns the control it landed on, or [constant NONE]
## for open water, which under these two schemes is inert.
func press(pointer: int, at: Vector2) -> int:
	if not _one_pointer(pointer):
		return NONE
	if _owner.has(pointer):
		return _owner[pointer]
	var id := hit(at)
	if id == NONE:
		return NONE
	_owner[pointer] = id
	if id == STICK:
		_aim(at)
	queue_redraw()
	return id


## A drag. True when that pointer belongs to a control, whatever it is over now:
## a thumb that rolls off the edge of the pad it is holding keeps holding it.
func move(pointer: int, at: Vector2) -> bool:
	if not _owner.has(pointer):
		return false
	if _owner[pointer] == STICK:
		_aim(at)
		queue_redraw()
	return true


## **A thumb already down is adopted**, and only onto a steering control. Its
## press happened before there was anything to lean at -- during the quickening,
## or before the pinch -- so the only event that finger will ever produce is a
## drag. Refused for `push` and `dash`, which are not leans.
func adopt(pointer: int, at: Vector2) -> int:
	if not _one_pointer(pointer):
		return NONE
	if _owner.has(pointer):
		return _owner[pointer]
	var id := hit(at)
	if id != STICK and id != PORT and id != STARBOARD:
		return NONE
	_owner[pointer] = id
	if id == STICK:
		_aim(at)
	queue_redraw()
	return id


## A release. Returns what was let go, or [constant NONE] if that pointer was
## never ours.
func release(pointer: int) -> int:
	if not _owner.has(pointer):
		return NONE
	var id: int = _owner[pointer]
	_owner.erase(pointer)
	if id == STICK and not _held(STICK):
		# A stick that stayed deflected would steer forever. The knob comes
		# home the instant nothing is holding it out.
		_stick_x = 0.0
	queue_redraw()
	return id


## **Godot emulates a mouse from every touch**, so on a phone each press arrives
## twice -- once as itself and once as a click at the same point -- and left
## alone the pair would fill the table with a phantom finger holding the control
## the real one is on. cell.gd's single slot solved that by taking whichever
## arrived first and ignoring the other; a table keyed by pointer cannot, so the
## rule is stated instead: **a real touch evicts the emulated mouse, and the
## mouse does not claim while a finger is down.** A desktop mouse is untouched,
## because on a desktop no touch ever arrives.
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
## focus, the scheme changing under a thumb.
func let_go() -> void:
	if _owner.is_empty() and _stick_x == 0.0:
		return
	_owner.clear()
	_stick_x = 0.0
	queue_redraw()


## The knob is absolute, not relative: a fixed stick's whole advantage over the
## scheme that ships is a **known centre**, and one that recentred on every
## press would be `anywhere` with a picture on it.
func _aim(at: Vector2) -> void:
	_stick_x = clampf(at.x - rect_of(STICK).get_center().x, -THROW, THROW)


# ---------------------------------------------------------------------------
# What the cell asks. Three verbs, each independent of the others -- which is
# the whole reason `pads` exists: it is the only scheme that can turn without
# swimming.
# ---------------------------------------------------------------------------

func steer() -> float:
	match scheme:
		RunState.Scheme.STICK:
			if not _held(STICK) or absf(_stick_x) <= DEAD:
				return 0.0
			return clampf((_stick_x - signf(_stick_x) * DEAD) / (THROW - DEAD),
				-1.0, 1.0)
		RunState.Scheme.PADS:
			var want := 0.0
			if _held(PORT):
				want -= 1.0
			if _held(STARBOARD):
				want += 1.0
			return want
		_:
			return 0.0


func pushing() -> bool:
	match scheme:
		RunState.Scheme.STICK:
			return _held(STICK)
		RunState.Scheme.PADS:
			return _held(PUSH)
		_:
			return false


## True while a **steering** control is held. At a division that is what decides
## the lean, because a thumb parked on the stick sits at canvas x 144 whichever
## way it is pushing -- which is the port half either way -- and under `pads`
## both turn pads are in the port half. The screen half stays live for a finger
## anywhere else, and it is the floor.
func steering() -> bool:
	return _held(STICK) or _held(PORT) or _held(STARBOARD)


# ---------------------------------------------------------------------------
# Drawing.
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _well == null or scheme == RunState.Scheme.ANYWHERE:
		return
	for id: int in ORDER:
		if not _live(id):
			continue
		var box := rect_of(id)
		var lit := _held(id)
		draw_style_box(_well_lit if lit else _well, box)
		var ink := MARK_HELD if lit else MARK_REST
		match id:
			STICK:
				_draw_channel(box, lit, ink)
			PORT:
				_draw_turn(box, -1.0, ink)
			STARBOARD:
				_draw_turn(box, 1.0, ink)
			PUSH:
				_draw_wave(box, ink)
			DASH:
				_draw_burst(box, ink)


func _draw_channel(box: Rect2, lit: bool, ink: float) -> void:
	var mid := box.get_center()
	draw_style_box(_track, Rect2(mid.x - THROW, mid.y - TRACK_H * 0.5,
		THROW * 2.0, TRACK_H))
	# A dart at each end, pointing the way that end turns you.
	_draw_dart(Vector2(box.end.x - STICK_DART_X, mid.y), 1.0, ink, STICK_DART_R)
	_draw_dart(Vector2(box.position.x + STICK_DART_X, mid.y), -1.0, ink,
		STICK_DART_R)
	draw_style_box(_knob_lit if lit else _knob, Rect2(
		mid.x + _stick_x - KNOB * 0.5, mid.y - KNOB * 0.5, KNOB, KNOB))


func _draw_turn(box: Rect2, side: float, ink: float) -> void:
	var mid := box.get_center()
	# The oars first, the dart under them. Built once without the dart and
	# rendered as two similar tufts -- draw_slot_dart's own comment had already
	# reached the same conclusion for the strand's compass, *a filled dart is
	# unmistakable*, so it is that mark doing that job again.
	var seat := mid + Vector2(0.0, OAR_SEAT)
	var strokes := PackedVector2Array()
	for i in OARS:
		var u := (float(i) + 0.5) / float(OARS)
		# The swing grows in the direction the turn goes, so port and starboard
		# are mirror images rather than the same picture twice.
		var along := u if side > 0.0 else 1.0 - u
		var out := Vector2.RIGHT.rotated(lerpf(OAR_FROM, OAR_TO, u))
		var swing := deg_to_rad(
			lerpf(OAR_SWING_FROM, OAR_SWING_TO, along)) * side
		var root := seat + out * OAR_ARC
		var knee := root + out.rotated(swing) * (OAR_LEN * OAR_KNEE)
		var tip := knee + out.rotated(swing * OAR_BEND) \
			* (OAR_LEN * (1.0 - OAR_KNEE))
		strokes.append(root)
		strokes.append(knee)
		strokes.append(knee)
		strokes.append(tip)
	draw_multiline(strokes, Color(TURN_HUE, ink), OAR_WIDTH, true)
	_draw_dart(mid + Vector2(0.0, -DART_LIFT), side, ink)


func _draw_wave(box: Rect2, ink: float) -> void:
	var mid := box.get_center()
	for row in WAVE_ROWS:
		# Row 0 is the aftmost. The crest marches forward across the rows, which
		# is what makes three wavy lines a *wave* and not three wavy lines.
		var lift := (float(row) - float(WAVE_ROWS - 1) * 0.5) * -WAVE_GAP
		var phase := float(row) * WAVE_MARCH * TAU
		var points := PackedVector2Array()
		for i in WAVE_STEPS + 1:
			var u := float(i) / float(WAVE_STEPS)
			points.append(Vector2(
				mid.x + (u - 0.5) * WAVE_SPAN,
				mid.y + lift + sin(u * TAU + phase) * WAVE_AMP))
		draw_polyline(points, Color(PUSH_HUE, ink), WAVE_WIDTH, true)


func _draw_burst(box: Rect2, ink: float) -> void:
	Cilia.draw_tile_organ(self, &"myoneme", 1,
		box.get_center() + Vector2(0.0, BURST_SEAT), ink, BURST_SCALE)


## The shared dart, quietened and -- to port -- mirrored. [param side] is +1 to
## starboard and -1 to port.
func _draw_dart(centre: Vector2, side: float, ink: float,
		radius: float = DART_R) -> void:
	var tone := TURN_HUE * (ink / DART_INK)
	if side > 0.0:
		Cilia.draw_slot_dart(self, DART_SLOT, tone, centre, radius)
		return
	# The arc table has no port lateral slot, so port is starboard under a
	# mirror rather than a second call with a made-up bearing.
	draw_set_transform(centre, 0.0, Vector2(-1.0, 1.0))
	Cilia.draw_slot_dart(self, DART_SLOT, tone, Vector2.ZERO, radius)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
