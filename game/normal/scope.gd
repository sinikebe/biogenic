extends "res://game/normal/sense_tile.gd"
## **A sense's scope** (docs/design/sense-tiles.md §7): the tile, widened into an
## A-scope -- a radar's oscilloscope -- for a sense that calls and listens. Range
## runs left to right under a scale, the call is a spike at nothing, each answer a
## spike where it came from as high as it was strong, and a sweep moves right as
## the call's round trip runs, so an answer appears exactly as the sweep reaches
## it: the cell knows an echo only when it lands.
##
## **The last sweep stays behind the cursor, faint**, until the sweep reaches it:
## a phosphor's persistence. The display is never empty for the eight to fifteen
## seconds of a call, and a body that moved between two calls shows as a spike
## that walked.
##
## Generic, as its tile is: it knows a reach, where the sweep is, a call and its
## answers by distance, strength and depth, and the gene whose tile it widens.
## Which sense it is and where its numbers come from are the edge's
## (normal_mode.gd's `_update_sense_tiles()` and `_post_pings()`).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## **How wide the trace is**, beside the organ's square: room for a scale of three
## or four numbers.
const TRACE_W := 168.0
## Where the trace sits in the slab: its first pixel (nothing, 0 units) a little in
## from the organ, its top, its baseline, and a margin at the right end.
const TRACE_X := 60.0
const TRACE_TOP := 9.0
const BASE_Y := 35.0
const TRACE_RIGHT := 10.0
## **The scale**: a tick every [method _step] units, its numbers under it in this
## size, and the unit at the axis's end, on the baseline, where an axis names
## itself. The unit is a symbol, so it is not translated.
const TICK_H := 3.0
const LABEL_SIZE := 10
const LABEL_Y := 48.0
const UNIT := "µm"
const UNIT_GAP := 4.0
const SCALE_INK := Color(0.855, 0.953, 0.933, 0.42)
const BASELINE_INK := Color(0.855, 0.953, 0.933, 0.16)
## **A spike**: as high as the square root of its strength, so a faint echo still
## stands clear of the grass; as wide as its body's depth, and never thinner than
## this. The call's own spike is full height.
const SPIKE_SIGMA := 1.4
const GRASS := 0.035
## The trace's ink: this sweep's, the last one's ghost, and the cursor.
const LIVE_ALPHA := 0.92
const GHOST_ALPHA := 0.26
const CURSOR_ALPHA := 0.42
const LINE_W := 1.4

## **The scale's full distance**, in the water's units: the sense's reach.
var reach := 0.0
## Where the sweep is, in units from the organ, or -1 while nothing is calling.
var sweep := -1.0

## This call's answers and the last one's, `[distance, strength, depth]`.
var _spikes: Array = []
var _ghosts: Array = []
## Which call this is, for the grass: it changes with each call and holds still
## between them, so the trace does not flicker.
var _calls := 0


func _width() -> float:
	return TRACE_X + TRACE_W


## **A call goes out**: the sweep starts again at nothing, and what the last one
## found becomes its ghost.
func call_out() -> void:
	_ghosts = _spikes
	_spikes = []
	_calls += 1
	sweep = 0.0
	queue_redraw()


## **An answer lands** from [param distance] units away, at [param strength] (0..1),
## off a body [param depth] units deep.
func echo(distance: float, strength: float, depth: float = 0.0) -> void:
	_spikes.append([maxf(distance, 0.0), clampf(strength, 0.0, 1.0), maxf(depth, 0.0)])
	queue_redraw()


## **Where the sweep is now**, in units, or -1 for nowhere; [param range] the
## scale's full distance. Redraws only when either has moved.
func at(distance: float, range_units: float) -> void:
	if is_equal_approx(distance, sweep) and is_equal_approx(range_units, reach):
		return
	sweep = distance
	reach = range_units
	queue_redraw()


## A new life starts on an empty scope, as on a quiet tile.
func settle() -> void:
	super.settle()
	_spikes.clear()
	_ghosts.clear()
	sweep = -1.0


func _draw_reading() -> void:
	var left := TRACE_X
	var right := _width() - TRACE_RIGHT - _unit_width() - UNIT_GAP
	draw_line(Vector2(left, BASE_Y), Vector2(right, BASE_Y), BASELINE_INK, 1.0, true)
	_draw_scale(left, right)
	if not active or reach <= 0.0:
		return
	var hue: Color = Cilia.hue(gene)
	var cursor: float = right if sweep < 0.0 else _x_of(sweep, left, right)
	if not _ghosts.is_empty() and cursor < right:
		_trace(_ghosts, cursor, right, left, right, Color(hue, GHOST_ALPHA), false)
	if sweep >= 0.0:
		_trace(_spikes, left, cursor, left, right, Color(hue, LIVE_ALPHA), true)
		draw_line(Vector2(cursor, TRACE_TOP), Vector2(cursor, BASE_Y),
			Color(hue, CURSOR_ALPHA), 1.0, true)


## The ticks and their numbers, and the unit at the axis's end; a number that
## would run into the next, or off the slab, is left out.
func _draw_scale(left: float, right: float) -> void:
	if reach <= 0.0:
		return
	var font := get_theme_default_font()
	var ink := SCALE_INK if active else Color(GREY, SCALE_INK.a * 0.7)
	if font != null:
		draw_string(font, Vector2(right + UNIT_GAP, BASE_Y + LABEL_SIZE * 0.35), UNIT,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, ink)
	var limit := _width() - TRACE_RIGHT * 0.5
	var step := _step(reach)
	var edge := -INF
	var d := 0.0
	while d <= reach + 0.5:
		var x := _x_of(d, left, right)
		draw_line(Vector2(x, BASE_Y), Vector2(x, BASE_Y + TICK_H), ink, 1.0, true)
		if font != null:
			var text := str(int(round(d)))
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				LABEL_SIZE).x
			var at := maxf(x - w * 0.5, left - 2.0)
			if at > edge + 4.0 and at + w < limit:
				draw_string(font, Vector2(at, LABEL_Y), text, HORIZONTAL_ALIGNMENT_LEFT,
					-1.0, LABEL_SIZE, ink)
				edge = at + w
		d += step


## **One trace** from [param x0] to [param x1]: the grass, each spike of
## [param spikes] as a bell, and the call's own at nothing when [param bang].
func _trace(spikes: Array, x0: float, x1: float, left: float, right: float,
		tone: Color, bang: bool) -> void:
	if x1 - x0 < 1.0:
		return
	var height := BASE_Y - TRACE_TOP
	var bells: Array = []
	if bang:
		bells.append([left, 1.0, SPIKE_SIGMA])
	for spike: Array in spikes:
		var sigma := maxf(SPIKE_SIGMA, float(spike[2]) / reach * (right - left) * 0.5)
		bells.append([_x_of(float(spike[0]), left, right), sqrt(float(spike[1])), sigma])
	var points := PackedVector2Array()
	var x := x0
	while x <= x1:
		var amp := GRASS * _grass(x)
		for bell: Array in bells:
			var off := (x - float(bell[0])) / float(bell[2])
			if absf(off) < 4.0:
				amp = maxf(amp, float(bell[1]) * exp(-0.5 * off * off))
		points.append(Vector2(x, BASE_Y - height * amp))
		x += 1.0
	if points.size() >= 2:
		draw_polyline(points, tone, LINE_W, true)


func _unit_width() -> float:
	var font := get_theme_default_font()
	return font.get_string_size(UNIT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE).x \
		if font != null else 0.0


func _x_of(distance: float, left: float, right: float) -> float:
	return left + clampf(distance / reach, 0.0, 1.0) * (right - left)


## **A tick every so many units**: 250 for a short reach, 500 for the ping's
## 1100 to 1900, so the scale carries three or four numbers.
static func _step(range_units: float) -> float:
	for step: float in [100.0, 250.0, 500.0, 1000.0, 2500.0]:
		if range_units / step <= 4.0:
			return step
	return 5000.0


## The grass under the trace: a fixed pattern of this call's, never a random draw
## (signal_bus.gd says why nothing in a view may draw from the game's stream).
func _grass(x: float) -> float:
	var h := sin(floorf(x) * 12.9898 + float(_calls) * 78.233) * 43758.5453
	return h - floorf(h)
