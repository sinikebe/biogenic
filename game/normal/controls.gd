extends Control
## PROTOTYPE -- the on-screen control schemes. Drawing and hit-testing only.
##
## MOUSE_FILTER_IGNORE end to end on purpose: it never enters the GUI pass, so
## it can never eat a steering drag or a division lean the way a Control with
## STOP would.

enum { WATER, STICK, PADS }
enum { NONE = -1, ST, PORT, STARBOARD, PUSH, DASH }

const EDGE := 48.0
const PAD := 96.0
const PAD_GAP := 24.0
const STICK_W := 192.0
const STICK_H := 96.0
const KNOB := 56.0
const THROW := 48.0
const DEAD := 6.0

const RADIUS := 12.0
const WELL_FILL := Color(0.063, 0.141, 0.125, 0.13)
const WELL_EDGE := Color(0.12, 0.70, 0.58, 0.09)
const WELL_FILL_HOT := Color(0.063, 0.141, 0.125, 0.58)
const WELL_EDGE_HOT := Color(0.12, 0.70, 0.58, 0.48)
const INK := Color(0.855, 0.953, 0.933, 1.0)
const MARK_REST := 0.42
const MARK_HOT := 0.92
const KNOB_REST := 0.045
const KNOB_EDGE := 0.28
const TRACK_ALPHA := 0.07
const TRACK_DART := 0.34

const Cilia := preload("res://game/vision/cilia.gd")

var scheme := WATER
var has_push := false
var has_dash := false
## -1 none, else the control index a pointer is holding.
var held := NONE
var knob_x := 0.0
var hot := NONE
var _steer := 0.0

var _rest: StyleBoxFlat = null
var _lit: StyleBoxFlat = null
var _knob_rest: StyleBoxFlat = null
var _knob_lit: StyleBoxFlat = null
var _track: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rest = _box(WELL_FILL, WELL_EDGE, RADIUS)
	_lit = _box(WELL_FILL_HOT, WELL_EDGE_HOT, RADIUS)
	_knob_rest = _box(Color(INK, KNOB_REST), Color(INK, KNOB_EDGE), RADIUS)
	_knob_lit = _box(Color(INK, 0.16), Color(INK, 0.80), RADIUS)
	_track = _box(Color(INK, TRACK_ALPHA), Color(INK, 0.0), 3.0)


func _box(fill: Color, edge: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(radius))
	return box


func rect_of(which: int) -> Rect2:
	var s := size
	var base := s.y - EDGE - PAD
	match which:
		ST:
			return Rect2(EDGE, s.y - EDGE - STICK_H, STICK_W, STICK_H)
		PORT:
			return Rect2(EDGE, base, PAD, PAD)
		STARBOARD:
			return Rect2(EDGE + PAD + PAD_GAP, base, PAD, PAD)
		DASH:
			return Rect2(s.x - EDGE - PAD, base, PAD, PAD)
		PUSH:
			return Rect2(s.x - EDGE - PAD - PAD_GAP - PAD, base, PAD, PAD)
	return Rect2()


func live() -> Array:
	var out: Array = []
	match scheme:
		STICK:
			out.append(ST)
			if has_dash:
				out.append(DASH)
		PADS:
			out.append(PORT)
			out.append(STARBOARD)
			if has_push:
				out.append(PUSH)
			if has_dash:
				out.append(DASH)
	return out


func hit(at: Vector2) -> int:
	for which: int in live():
		if rect_of(which).has_point(at):
			return which
	return NONE


## Signed steer for a pointer at [param at], while [member held] owns it.
func steer_held() -> float:
	return _steer


func steer_for(at: Vector2) -> float:
	_steer = _steer_for(at)
	return _steer


func _steer_for(at: Vector2) -> float:
	if held == ST:
		var mid := rect_of(ST).get_center().x
		var dx := clampf(at.x - mid, -THROW, THROW)
		knob_x = dx
		if absf(dx) <= DEAD:
			return 0.0
		return signf(dx) * (absf(dx) - DEAD) / (THROW - DEAD)
	if held == PORT:
		return -1.0
	if held == STARBOARD:
		return 1.0
	return 0.0


func grab(which: int, at: Vector2) -> void:
	held = which
	knob_x = 0.0
	_steer = 0.0
	if which == ST:
		steer_for(at)
	queue_redraw()


func let_go() -> void:
	held = NONE
	knob_x = 0.0
	_steer = 0.0
	queue_redraw()


func _draw() -> void:
	for which: int in live():
		var r := rect_of(which)
		var on := held == which or hot == which
		_well(r, on)
		match which:
			ST:
				_stick(r)
			PORT:
				_oars(r, -1.0, on)
			STARBOARD:
				_oars(r, 1.0, on)
			PUSH:
				_organ(r, &"axoneme", on)
			DASH:
				_organ(r, &"myoneme", on)


func _well(r: Rect2, on: bool) -> void:
	draw_style_box(_lit if on else _rest, r)


func _stick(r: Rect2) -> void:
	var mid := r.get_center()
	# The channel: what says left and right, and only left and right.
	draw_style_box(_track, Rect2(mid.x - THROW - 3.0, mid.y - 3.0,
		THROW * 2.0 + 6.0, 6.0))
	# A dart at each end of the throw, in the cirrus's own hue: the same mark the
	# strand puts under every locus, saying the same thing -- this way round.
	for side: float in [-1.0, 1.0]:
		_dart(Vector2(mid.x + side * (THROW + 15.0), mid.y), side,
			Cilia.hue(&"cirrus"), TRACK_DART)
	var k := Rect2(mid.x + knob_x - KNOB * 0.5, mid.y - KNOB * 0.5, KNOB, KNOB)
	draw_style_box(_knob_lit if held == ST else _knob_rest, k)


func _dart(seat: Vector2, side: float, tone: Color, alpha: float,
		rr: float = 11.0) -> void:
	var d := Vector2(side, 0.0)
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([
		seat + d * rr,
		seat - d * (rr * 0.55) + n * (rr * 0.70),
		seat - d * (rr * 0.10),
		seat - d * (rr * 0.55) - n * (rr * 0.70)]), Color(tone, alpha))


func _organ(r: Rect2, gene: StringName, on: bool) -> void:
	var tone := Cilia.hue(gene)
	var a := MARK_HOT if on else MARK_REST
	var c := r.get_center()
	if gene == &"axoneme":
		# **Swim** is a wave, not a burst: three strokes of the same metachronal
		# beat the body wears, lying along the way you go.
		for i in 3:
			var y := c.y - 18.0 + float(i) * 18.0
			var pts := PackedVector2Array()
			for k in 13:
				var u := float(k) / 12.0
				pts.append(Vector2(c.x - 28.0 + u * 56.0,
					y + 6.0 * sin(u * TAU + float(i) * 0.9)))
			draw_polyline(pts, Color(tone, a * (1.0 - 0.18 * float(i))), 3.0, true)
		return
	# **Dash** is a burst: one contraction, radiating, with the pigment at the
	# heart of it. The myoneme's own tile mark, at twice the size.
	Cilia.draw_tile_organ_tinted(self, gene, 1, c + Vector2(0, 8), tone, a, 2.0)


## The cirrus, with every oar swept the way the turn goes, and the game's own
## filled dart under it. The sweep alone was rendered first and it is a pair of
## similar tufts at arm's length; `cilia.gd` reached the same conclusion about
## the strand's compass -- *a filled dart is unmistakable* -- and this is that
## mark, doing that job again. §7.
func _oars(r: Rect2, side: float, on: bool) -> void:
	var tone := Cilia.hue(&"cirrus")
	var a := MARK_HOT if on else MARK_REST
	var c := r.get_center() + Vector2(-side * 4.0, -2.0)
	var arc_r := 22.0
	draw_arc(c, arc_r, Cilia.TILE_ARC_FROM, Cilia.TILE_ARC_TO, 32,
		Color(tone, 0.34 * a / Cilia.TILE_STROKE_ALPHA), 3.0, true)
	for i in 5:
		var u := (float(i) + 0.5) / 5.0
		var ang := lerpf(Cilia.TILE_ARC_FROM, Cilia.TILE_ARC_TO, u)
		var dir := Vector2(cos(ang), sin(ang))
		var root := c + dir * arc_r
		var t := u if side > 0.0 else 1.0 - u
		draw_line(root, root + dir.rotated(side * lerpf(0.55, 1.5, t))
			* (26.0 * lerpf(0.72, 1.12, t)), Color(tone, a), 3.0, true)
	# The dart, on the beam, pointing the way the body will come round.
	_dart(r.get_center() + Vector2(0.0, 30.0), side, tone, a * 1.05)
