extends Control
## **A gauge** (docs/design/energy-gauge.md): how full something is, how much it
## holds, and how fast it is going -- a bar to read at a glance, two numbers to read
## exactly, and the next few seconds drawn on the bar itself.
##
## **The first of the HUD's readouts, and built so the next ones are the same
## object.** It knows a level, a capacity and a rate, in the readout's units, and
## nothing of what they measure: the energy's names, its mark and its numbers are
## put in by the edge that reads it (normal_mode.gd), as CLAUDE.md asks of every
## mechanic a later game reuses. Gauges sit in a row in the top-left corner, after
## the pause target, each [constant WIDTH] wide (§2).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Readout := preload("res://game/mechanics/readout.gd")

## **The slab is the pause target's height**, so the corner reads as one row of
## chrome rather than a button and a panel (§2.1).
const HEIGHT := 56.0
## Wide enough for a bar that a glance can read to a tenth, and for the two numbers
## under it at their longest -- `88.8 / 888` and `-88.8/s` -- with room between.
const WIDTH := 216.0
const PAD := 12.0
## **The mark that says what this gauge is of**, in the box it is drawn in.
const ICON_BOX := Vector2(14.0, 22.0)
const ICON_GAP := 10.0
## The bar: thick enough to read its fill at arm's length on a phone (15 device px
## at 2400x1080), thin enough that the two numbers fit under it.
const BAR_TOP := 14.0
const BAR_H := 10.0
const TEXT_SIZE := 14
const TEXT_BASE := 44.0

## **The colours, by how it stands** (§2.3): full, low and out. Low is where the
## caller says the warning starts; out is an empty bar, where a grace runs.
const FULL := Color(0.40, 0.86, 0.72)
const LOW := Color(0.97, 0.72, 0.32)
const OUT := Color(0.96, 0.38, 0.34)
## The fill blends from full to low over this much of the bar, centred on where the
## warning starts, so the colour turns as the warning does without a hard step.
const LOW_BLEND := 0.1
const TRACK := Color(0.855, 0.953, 0.933, 0.08)
const WORD := Color(0.855, 0.953, 0.933, 0.55)
const VALUE := Color(0.855, 0.953, 0.933, 0.92)
## **The next few seconds** (§2.2): the end of the fill that the rate will take in
## [member horizon] seconds, struck through with dark stripes over the fill's own
## colour. Not drawn fainter: it was, and when all that is left was in it the whole
## bar went dim at exactly the moment it had to be seen.
const AHEAD_STRIPE := Color(0.02, 0.06, 0.05, 0.5)
const AHEAD_PITCH := 6.0
const AHEAD_WIDTH := 2.0

## **A lump that falls off stays a moment** (§2.4): a stroke, a dash, a bite. Its
## part of the bar is drawn pale for [constant TRAIL_HOLD], then shrinks at
## [constant TRAIL_SPEED] of the bar a second. Smaller than [constant TRAIL_MIN] of
## the bar in one reading is the steady drain, and leaves nothing behind.
const TRAIL_MIN := 0.012
const TRAIL_HOLD := 0.25
const TRAIL_SPEED := 0.6
const TRAIL := Color(0.92, 0.97, 0.95, 0.5)
## **What comes in glows** as it fills, for [constant GAIN_FADE] seconds.
const GAIN_MIN := 0.012
const GAIN_FADE := 0.7
const GAIN := Color(0.92, 0.97, 0.95, 0.85)
## **The grace beats** while the bar is empty: once a second, the strip that is
## left of it brightening and dimming between these two.
const OUT_PULSE := Vector2(0.45, 1.0)

## **What it reads**: how full, 0 to 1; what that is when full; what goes out a
## second, in the same unit -- more than nothing for going out.
var level := 1.0
var capacity := 0.0
var rate := 0.0
## How many seconds ahead the end of the fill is drawn for (§2.2).
var horizon := 5.0
## Below this level the colour turns to [constant LOW].
var low_from := 0.5
## Seconds left once it is empty, and how many there were: a grace. -1 for a gauge
## with none, or not yet empty.
var out_left := -1.0
var out_total := 0.0
## **Its mark**: a polygon in a unit box, drawn in the colour it stands at.
var icon := PackedVector2Array()

var _well: StyleBoxFlat = null
## One box every piece of the bar is drawn with, recoloured as it goes: a flat box
## draws its rounded ends without overlapping itself, which a rect and two circles
## at a fraction of alpha would not.
var _piece := StyleBoxFlat.new()
var _trail := -1.0
var _trail_hold := 0.0
var _gain_from := -1.0
var _gain_left := 0.0
var _clock := 0.0


func _ready() -> void:
	_piece.anti_aliasing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	set_process(false)


## Handed the slab rather than building it, as the drawn controls are: what the
## pause target is made of, at its resting light (normal_mode.gd's `_well()`).
func setup(well: StyleBoxFlat, mark: PackedVector2Array) -> void:
	_well = well
	icon = mark
	queue_redraw()


## **One reading.** A level that fell by a lump leaves its trail; one that rose
## glows where it rose. Redraws only when something it draws has changed.
func read(new_level: float, new_capacity: float, new_rate: float,
		left: float = -1.0, total: float = 0.0) -> void:
	new_level = clampf(new_level, 0.0, 1.0)
	if new_level < level - TRAIL_MIN:
		_trail = maxf(_trail, level)
		_trail_hold = TRAIL_HOLD
		set_process(true)
	elif new_level > level + GAIN_MIN:
		_gain_from = level if _gain_left <= 0.0 else minf(_gain_from, level)
		_gain_left = GAIN_FADE
		set_process(true)
	if out_left < 0.0 and left >= 0.0:
		set_process(true)
	var changed := not is_equal_approx(new_level, level) \
		or not is_equal_approx(new_capacity, capacity) \
		or absf(new_rate - rate) > 0.0005 or not is_equal_approx(left, out_left)
	level = new_level
	capacity = new_capacity
	rate = new_rate
	out_left = left
	out_total = total
	if changed:
		queue_redraw()


## Forgets the trail and the glow: a new life starts on a quiet bar, at
## [param at] -- its full tank is no meal, and does not glow as one.
func settle(at: float = 1.0) -> void:
	level = clampf(at, 0.0, 1.0)
	_trail = -1.0
	_gain_left = 0.0
	_clock = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if _trail >= 0.0:
		if _trail_hold > 0.0:
			_trail_hold -= delta
		else:
			_trail -= TRAIL_SPEED * delta
			if _trail <= level:
				_trail = -1.0
	if _gain_left > 0.0:
		_gain_left = maxf(_gain_left - delta, 0.0)
	queue_redraw()
	if _trail < 0.0 and _gain_left <= 0.0 and out_left < 0.0:
		set_process(false)


## **The colour it stands at**: full, turning low around [member low_from], out
## while a grace runs.
func tint() -> Color:
	if out_left >= 0.0:
		return OUT
	var t := clampf((low_from + LOW_BLEND * 0.5 - level) / LOW_BLEND, 0.0, 1.0)
	return FULL.lerp(LOW, t)


func _draw() -> void:
	if _well != null:
		draw_style_box(_well, Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)))
	var tone := tint()
	_draw_icon(tone)
	var left := PAD + ICON_BOX.x + ICON_GAP
	var bar := Rect2(left, BAR_TOP, WIDTH - PAD - left, BAR_H)
	_draw_bar(bar, tone)
	_draw_numbers(bar)


func _draw_icon(tone: Color) -> void:
	if icon.size() < 3:
		return
	var at := Vector2(PAD, (HEIGHT - ICON_BOX.y) * 0.5)
	var points := PackedVector2Array()
	for p: Vector2 in icon:
		points.append(at + p * ICON_BOX)
	draw_colored_polygon(points, Color(tone, 0.9))


## The track, the fill with its next seconds fainter at the end, a lump's trail
## and a meal's glow -- or, empty, the grace that is left.
func _draw_bar(bar: Rect2, tone: Color) -> void:
	var radius := BAR_H * 0.5
	_rounded(bar, Color(OUT, 0.16) if out_left >= 0.0 else TRACK, radius)
	if out_left >= 0.0:
		var share := clampf(out_left / maxf(out_total, 0.001), 0.0, 1.0)
		var beat := 0.5 + 0.5 * cos(_clock * TAU)
		var strip := Rect2(bar.position + Vector2(0.0, BAR_H * 0.25),
			Vector2(bar.size.x * share, BAR_H * 0.5))
		_rounded(strip, Color(OUT, lerpf(OUT_PULSE.x, OUT_PULSE.y, beat)), BAR_H * 0.25)
		return
	if _trail > level:
		_rounded(_span(bar, level, _trail), TRAIL, radius, false)
	var ahead := 0.0
	if capacity > 0.0:
		ahead = clampf(rate * horizon / capacity, 0.0, level)
	_rounded(_span(bar, 0.0, level), tone, radius)
	if ahead > 0.0:
		_stripes(_span(bar, level - ahead, level))
	if _gain_left > 0.0 and _gain_from < level:
		var glow := Color(GAIN, GAIN.a * _gain_left / GAIN_FADE)
		_rounded(_span(bar, _gain_from, level), glow, radius, _gain_from <= 0.0)


## **Under the bar**: what it holds of what it can, on the left, and what goes out a
## second on the right -- or, empty, how long the grace has left.
func _draw_numbers(bar: Rect2) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var held: Array = [[amount(level * capacity), true], [" / " + amount(capacity), false]]
	_draw_runs(font, held, bar.position.x, false)
	var right: Array
	if out_left >= 0.0:
		# TRANSLATORS: Under the energy gauge in the top-left corner, once the
		# cell's food tank is empty: how many whole seconds the cell has left to
		# eat before it dies. {} is the number. 14 px type, right-aligned under the
		# gauge's bar.
		# ROOM: 90 px at 14 px with 10
		right = _filled(tr("{} s left"), str(int(ceilf(out_left))))
	else:
		# TRANSLATORS: Under the energy gauge in the top-left corner: how much of the
		# cell's food tank it burns each second, in the same unit as the "23 / 36"
		# beside it. {} is the number; the minus sign says it goes out, and "/s" is
		# "each second" -- keep it as short.
		# ROOM: 80 px at 14 px with 12.5
		right = _filled(tr("−{}/s"), amount(rate))
	_draw_runs(font, right, bar.end.x, true)


## **An amount as the gauge writes it**: one decimal under ten, whole from ten on,
## and the decimal kept when it is a zero -- a number read every frame that changed
## width as it crossed a whole one would twitch.
static func amount(value: float) -> String:
	if absf(value) < 9.95:
		return "%.1f" % value
	return "%d" % int(roundf(value))


## [param template] with [param value] where its `{}` is, as runs: the value is
## drawn brighter than the words, as readout.gd draws a line.
static func _filled(template: String, value: String) -> Array:
	var at := template.find("{}")
	if at < 0:
		return [[template, false]]
	var out: Array = []
	if at > 0:
		out.append([template.left(at), false])
	out.append([value, true])
	if at + 2 < template.length():
		out.append([template.substr(at + 2), false])
	return out


func _draw_runs(font: Font, line: Array, x: float, from_right: bool) -> void:
	if from_right:
		x -= Readout.width(font, TEXT_SIZE, line)
	x = roundf(x)
	for run: Array in line:
		var piece := String(run[0])
		draw_string(font, Vector2(x, TEXT_BASE), piece, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			TEXT_SIZE, VALUE if bool(run[1]) else WORD)
		x += font.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE).x


## **Diagonal stripes across [param rect]**, cut at its two sides: what says the
## stretch of fill under them is on its way out.
func _stripes(rect: Rect2) -> void:
	var h := rect.size.y
	if rect.size.x <= 0.0 or h <= 0.0:
		return
	var x := rect.position.x - h
	while x < rect.end.x:
		# The stripe runs up and to the right at 45 degrees from (x, bottom); the
		# part of it inside the rect's two sides is drawn.
		var t0 := clampf((rect.position.x - x) / h, 0.0, 1.0)
		var t1 := clampf((rect.end.x - x) / h, 0.0, 1.0)
		if t1 > t0:
			draw_line(Vector2(x + t0 * h, rect.end.y - t0 * h),
				Vector2(x + t1 * h, rect.end.y - t1 * h), AHEAD_STRIPE, AHEAD_WIDTH, true)
		x += AHEAD_PITCH


## The part of [param bar] from [param from] to [param to], shares of its length.
func _span(bar: Rect2, from: float, to: float) -> Rect2:
	from = clampf(from, 0.0, 1.0)
	to = clampf(to, from, 1.0)
	return Rect2(bar.position.x + bar.size.x * from, bar.position.y,
		bar.size.x * (to - from), bar.size.y)


## A bar's piece, its ends round where [param round_left] and [param round_right]
## say and square where it meets another piece.
func _rounded(rect: Rect2, colour: Color, radius: float, round_left: bool = true,
		round_right: bool = true) -> void:
	if rect.size.x <= 0.0 or colour.a <= 0.0:
		return
	var r := int(roundf(radius))
	_piece.bg_color = colour
	_piece.corner_radius_top_left = r if round_left else 0
	_piece.corner_radius_bottom_left = r if round_left else 0
	_piece.corner_radius_top_right = r if round_right else 0
	_piece.corner_radius_bottom_right = r if round_right else 0
	draw_style_box(_piece, rect)
