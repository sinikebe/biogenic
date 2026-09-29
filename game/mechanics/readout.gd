extends RefCounted
## **A line of words with numbers in it**, for a player who asked to see the
## numbers (docs/design/gene-stats.md §4, §6.1). The words say what a number
## measures, and the numbers are drawn a little brighter than the words so the
## eye finds them -- never brighter than the line they explain.
##
## **Nothing here knows what it describes.** An item is a template with `{}`
## where each value goes, the values, and the unit each one is in: an organ, a
## body or a ship's part all read the same. The names live at the edge that
## builds the items (game/normal/gene_stats.gd), which is the rule CLAUDE.md sets
## for every mechanic a later game is meant to reuse.
##
## No class_name, for the reason signal_bus.gd gives: a content pack mounts over
## an older binary, and a global class a pack introduces is not in that binary's
## class list. Preload it by path.

## What a value measures, which decides how it is written (§4). The unit's own
## word -- `µm`, `s`, `a second` -- is in the template, not here: it is a word,
## and it keeps the words' tint.
enum Unit { DISTANCE, SPEED, TIME, ENERGY, RATE, TIMES, SHARE, ANGLE, COUNT }

## Between two items on one line.
const SEP := " · "


## **One value, written by its unit's rule** (§4):
## - a distance, a speed, an angle and a count are whole: `620`, `57`, `26°`;
## - a time keeps up to two decimals, trailing zeros dropped, and one from ten
##   on: `5.07`, `1.45`, `3`, `15.2`;
## - an amount of energy keeps one decimal, and is whole from ten on: `1.3`,
##   `36`;
## - a rate and a ratio of sizes keep two, zeros and all: `0.50`, `1.30`;
## - a share is a whole percentage: `7%`.
static func format(value: float, unit: int) -> String:
	return number(value, unit) + suffix(unit)


## The digits of [method format], without the sign that closes a share or an
## angle. The digits are what is drawn brighter; the sign is the unit's, and it
## keeps the words' tint as every other unit does (§3.3).
static func number(value: float, unit: int) -> String:
	match unit:
		Unit.DISTANCE, Unit.SPEED, Unit.ANGLE, Unit.COUNT:
			return _trimmed(roundf(value), 0)
		Unit.TIME:
			return _trimmed(value, 2 if absf(value) < 10.0 else 1)
		Unit.ENERGY:
			if absf(value) < 10.0:
				return _trimmed(value, 1)
			return _trimmed(roundf(value), 0)
		Unit.RATE, Unit.TIMES:
			return "%.2f" % value
		Unit.SHARE:
			return _trimmed(roundf(value * 100.0), 0)
	return _trimmed(value, 2)


## The sign after the digits: `%` for a share, `°` for an angle, and nothing
## for a unit whose word is in the template.
static func suffix(unit: int) -> String:
	match unit:
		Unit.SHARE:
			return "%"
		Unit.ANGLE:
			return "°"
	return ""


## **`String.num` keeps a whole number's `.0` in Godot 4.7** (and `"%.1f" %
## 1.45` prints `1.4`), so this trims it. A value that rounds to nothing is
## written `0`, never `-0`.
static func _trimmed(value: float, decimals: int) -> String:
	var text := String.num(value, decimals).trim_suffix(".0")
	return "0" if text == "-0" else text


## One item: `item("out to {} µm", [620.0], [Unit.DISTANCE])`. Words alone
## need no values: `item("free to wear")`.
static func item(text: String, values: Array = [], units: Array = []) -> Dictionary:
	return {"text": text, "values": values, "units": units}


## **A line of items as runs** `[text, is_value]`, [constant SEP] between two
## items, and neighbouring runs of the same kind merged. A `{}` with no value
## for it is dropped rather than guessed at.
static func runs(items: Array) -> Array:
	var out: Array = []
	for i in items.size():
		if i > 0:
			_append(out, SEP, false)
		var it: Dictionary = items[i]
		var values: Array = it.get("values", [])
		var units: Array = it.get("units", [])
		var parts := String(it.get("text", "")).split("{}")
		for p in parts.size():
			_append(out, parts[p], false)
			if p == parts.size() - 1 or p >= values.size():
				continue
			var unit: int = int(units[p]) if p < units.size() else Unit.COUNT
			_append(out, number(float(values[p]), unit), true)
			_append(out, suffix(unit), false)
	return out


static func _append(runs_so_far: Array, piece: String, is_value: bool) -> void:
	if piece.is_empty():
		return
	if not runs_so_far.is_empty():
		var last: Array = runs_so_far[runs_so_far.size() - 1]
		if bool(last[1]) == is_value:
			last[0] = String(last[0]) + piece
			return
	runs_so_far.append([piece, is_value])


## The line as one plain string, for a surface that draws in a single tint.
static func plain(items: Array) -> String:
	var out := ""
	for run: Array in runs(items):
		out += String(run[0])
	return out


## How wide [param line] -- runs, as [method runs] makes them -- is drawn.
static func width(font: Font, size: int, line: Array) -> float:
	var total := 0.0
	for run: Array in line:
		total += font.get_string_size(String(run[0]), HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, size).x
	return total


## **Draws [param line] centred on [param centre_x]**, its baseline at
## [param baseline]: words in [param word], values in [param value]. The start
## is snapped to a whole pixel, as a centred label's is.
static func draw(canvas: CanvasItem, font: Font, size: int, line: Array,
		centre_x: float, baseline: float, word: Color, value: Color) -> void:
	var x := roundf(centre_x - width(font, size, line) * 0.5)
	for run: Array in line:
		var piece := String(run[0])
		canvas.draw_string(font, Vector2(x, baseline), piece,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, value if bool(run[1]) else word)
		x += font.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
