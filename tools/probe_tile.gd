extends Control
## THROWAWAY probe for docs/design/lifecycle.md. Delete after rendering.
##
## The genome strip with the two registers on it: what the body wears (rooted,
## filled pips) against what the DNA carries (lifted off the seat, ring pips).
## Poses one row of tiles in every state the strip can reach, so the claim that
## the difference reads at 76 px can be looked at instead of asserted.

const Cilia := preload("res://game/vision/cilia.gd")

const BASE := Color(0.023, 0.055, 0.05, 1)
const TILE := 76.0
const GAP := 20.0

const TILE_BG_OCCUPIED := Color(0.063, 0.141, 0.125, 0.62)
const TILE_BG_EMPTY := Color(0.047, 0.082, 0.075, 0.50)
const TILE_BG_HELD := Color(0.063, 0.141, 0.125, 0.80)
const EMPTY_BORDER := Color(0.141, 0.278, 0.247, 0.85)
const EMPTY_PLUS := Color(0.141, 0.278, 0.247, 0.75)
const LABEL_TINT := Color(0.855, 0.953, 0.933, 0.66)
const LABEL_TINT_LOUD := Color(0.855, 0.953, 0.933, 0.92)
const LABEL_SIZE := 13
const LABEL_BASELINE := 15.0
const PIP_RADIUS := 2.6
const PIP_GAP := 9.0
const PIP_BOTTOM := 9.0

## How far an unexpressed organ's bristles are lifted off their seat, in tile
## pixels. The whole of "this is not attached to you".
const LIFT := 0.0
## Alpha of an unexpressed organ's strokes, against 0.88 for a worn one.
const GHOST_ALPHA := 0.52

const WORDS := {
	&"cytostome": "eat", &"cirrus": "turn", &"flagellum": "swim",
	&"chemocyte": "smell", &"ocellus": "beam", &"ampulla": "ping",
	&"vacuole": "store", &"myoneme": "dash",
}

## slot, gene, body tier, dna tier, label
var row := [
	[0, &"cytostome", 2, 2],
	[1, &"cirrus", 1, 3],
	[2, &"flagellum", 2, 2],
	[3, &"ocellus", 0, 1],
	[4, &"chemocyte", 2, 2],
	[5, &"", 0, 0],
	[6, &"", 0, 0],
]
var held: StringName = &"myoneme"

var _clock := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--no-sample":
			held = &""
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BASE)
	var font := get_theme_default_font()
	var count := row.size() + (2 if held != &"" else 0)
	var width := count * TILE + (count - 1) * GAP
	# The slots stay centred; the sample and its arrow hang off to the left.
	var x := (size.x - row.size() * TILE - (row.size() - 1) * GAP) * 0.5
	var y := size.y * 0.5 - TILE * 0.5

	if held != &"":
		_tile(font, Vector2(x - 2.0 * (TILE + GAP) + 44.0, y), -1, held, 1, 1,
			TILE_BG_HELD, true)
		var mid := Vector2(x - TILE - GAP + 44.0 + 15.0, y + TILE * 0.5)
		draw_line(mid - Vector2(11, 0), mid + Vector2(9, 0),
			Color(0.855, 0.953, 0.933, 0.34), 1.6, true)
		draw_line(mid + Vector2(9, 0), mid + Vector2(2, -6),
			Color(0.855, 0.953, 0.933, 0.34), 1.6, true)
		draw_line(mid + Vector2(9, 0), mid + Vector2(2, 6),
			Color(0.855, 0.953, 0.933, 0.34), 1.6, true)

	for entry in row:
		_tile(font, Vector2(x, y), int(entry[0]), entry[1], int(entry[2]),
			int(entry[3]), TILE_BG_OCCUPIED, false)
		x += TILE + GAP

	if font != null:
		draw_string(font, Vector2(0.0, y - 26.0), "dna",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 15,
			Color(0.855, 0.953, 0.933, 0.45))
		draw_string(font, Vector2(0.0, y + TILE + 30.0),
			"tap a slot · your daughters wear it",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14,
			Color(0.855, 0.953, 0.933, 0.38))


func _tile(font: Font, at: Vector2, slot: int, gene: StringName, body_tier: int,
		dna_tier: int, bg: Color, loud: bool) -> void:
	var box := Vector2(TILE, TILE)
	var rect := Rect2(at, box)
	var empty := gene == &""
	draw_rect(rect, TILE_BG_EMPTY if empty else bg, true)
	var edge := EMPTY_BORDER if empty else Color(Cilia.hue(gene), 0.45)
	if loud:
		edge = Color(Cilia.hue(gene), 0.90)
	draw_rect(rect, edge, false, 2.0 if loud else 1.0)

	if empty:
		var mid := at + box * 0.5
		draw_line(mid - Vector2(8, 0), mid + Vector2(8, 0), EMPTY_PLUS, 1.6, true)
		draw_line(mid - Vector2(0, 8), mid + Vector2(0, 8), EMPTY_PLUS, 1.6, true)
		_compass(at, slot, Color(0.855, 0.953, 0.933, 0.6))
		return

	if font != null:
		draw_string(font, at + Vector2(0.0, LABEL_BASELINE), WORDS.get(gene, String(gene)),
			HORIZONTAL_ALIGNMENT_CENTER, box.x, LABEL_SIZE,
			LABEL_TINT_LOUD if loud else LABEL_TINT)

	# The organ. Worn organs are rooted on the seat; an organ the DNA carries
	# and the body does not is lifted clear of it.
	var worn := body_tier > 0
	_organ(at, gene, 0.0 if worn else LIFT,
		Cilia.TILE_STROKE_ALPHA if worn else GHOST_ALPHA, worn)
	_compass(at, slot, Cilia.hue(gene))

	# Pips: filled to what the body wears, rings to what the DNA carries, a
	# faint outline for the rest. Filled against ring is shape, not colour.
	var tone := Cilia.hue(gene)
	var y := at.y + box.y - PIP_BOTTOM
	for i in 3:
		var p := Vector2(at.x + box.x * 0.5 + (float(i) - 1.0) * PIP_GAP, y)
		if i < body_tier:
			draw_circle(p, PIP_RADIUS, Color(tone, 0.92), true, -1.0, true)
		elif i < dna_tier:
			draw_circle(p, PIP_RADIUS, Color(tone, 0.85), false, 1.4, true)
		else:
			draw_circle(p, PIP_RADIUS, Color(tone, 0.22), false, 1.2, true)


func _organ(at: Vector2, gene: StringName, lift: float, alpha: float,
		seat: bool) -> void:
	var tone := Cilia.hue(gene)
	var centre := at + Vector2(TILE * 0.5, TILE * Cilia.TILE_CENTRE_Y)
	draw_arc(centre, Cilia.TILE_ARC_RADIUS, Cilia.TILE_ARC_FROM,
		Cilia.TILE_ARC_TO, 32, Color(tone, Cilia.TILE_ARC_ALPHA),
		Cilia.TILE_ARC_WIDTH, true)
	var count := int(Cilia.TILE_COUNT.get(gene,
		Cilia.EARNED_COUNT.get(gene, Cilia.TILE_COUNT_EARNED)))
	var length := float(Cilia.TILE_LEN.get(gene, Cilia.TILE_LEN_EARNED))
	if not Cilia.TILE_COUNT.has(gene):
		draw_circle(centre + Vector2(0.0, -(Cilia.TILE_ARC_RADIUS + lift) * 0.62),
			Cilia.TILE_PIGMENT, Color(tone, alpha), true, -1.0, true)
	for i in count:
		var u := (float(i) + 0.5) / float(count)
		var angle := lerpf(Cilia.TILE_ARC_FROM, Cilia.TILE_ARC_TO, u)
		var dir := Vector2(cos(angle), sin(angle))
		var root := centre + dir * (Cilia.TILE_ARC_RADIUS + lift)
		var span := length * (0.86 + 0.20 * sin(u * PI))
		draw_line(root, root + dir * span, Color(tone, alpha),
			Cilia.TILE_ARC_WIDTH, true)


func _compass(at: Vector2, slot: int, tone: Color) -> void:
	if slot < 0:
		return
	var centre := at + Vector2(Cilia.TILE_COMPASS_X, Cilia.TILE_COMPASS_Y)
	draw_arc(centre, Cilia.TILE_COMPASS_R, 0.0, TAU, 20, Color(tone, 0.28), 1.0, true)
	var bearing := Cilia.slot_bearing(slot)
	var dir := Vector2(sin(bearing), -cos(bearing))
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		centre + dir * Cilia.TILE_COMPASS_R,
		centre - dir * (Cilia.TILE_COMPASS_R * 0.55) + side * (Cilia.TILE_COMPASS_R * 0.70),
		centre - dir * (Cilia.TILE_COMPASS_R * 0.10),
		centre - dir * (Cilia.TILE_COMPASS_R * 0.55) - side * (Cilia.TILE_COMPASS_R * 0.70)]),
		Color(tone, 0.95))
