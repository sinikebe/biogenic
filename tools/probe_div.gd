extends Control
## THROWAWAY probe for docs/design/lifecycle.md. Delete after rendering.
##
## Poses the division choice: two daughters drawn by cilia.gd from two genomes,
## at the scales each view would use, so the claim "the two are distinguishable
## before you commit" can be looked at instead of asserted.

const Cilia := preload("res://game/vision/cilia.gd")
const CellBody := preload("res://game/normal/cell.gd")

const BASE := Color(0.023, 0.055, 0.05, 1)

## --mode=pov uses soma.gd's SCALE 1.7 and FADE 0.34; --mode=world uses ZOOM 1.
var mode := "pov"
## Which daughter the player is leaning into: -1 port, +1 starboard, 0 neither.
var lean := 0
## How far apart, in canvas px, the two bodies sit either side of centre.
var spread := 132.0
## Which mutation to pose on the starboard daughter.
var kind := "trade"
var fade_override := -1.0

var _clock := 0.0

const MOTHER := {
	&"cytostome": 2, &"cirrus": 2, &"flagellum": 2,
	&"chemocyte": 2, &"ocellus": 1, &"vacuole": 1,
}
const MOTHER_ORDER: Array[StringName] = [
	&"cytostome", &"cirrus", &"flagellum", &"ocellus", &"chemocyte", &"vacuole", &""]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--mode="):
			mode = text.trim_prefix("--mode=")
		elif text.begins_with("--lean="):
			lean = int(text.trim_prefix("--lean="))
		elif text.begins_with("--spread="):
			spread = float(text.trim_prefix("--spread="))
		elif text.begins_with("--kind="):
			kind = text.trim_prefix("--kind=")
		elif text.begins_with("--fade="):
			fade_override = float(text.trim_prefix("--fade="))
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _daughter() -> Array:
	var tiers := MOTHER.duplicate()
	var order: Array[StringName] = MOTHER_ORDER.duplicate()
	match kind:
		"trade":
			# One tier moved from one organ to another: the subtlest mutation.
			tiers[&"flagellum"] = 1
			tiers[&"cirrus"] = 3
		"drift":
			# One gene replaced by one the lineage does not carry.
			tiers.erase(&"chemocyte")
			tiers[&"ampulla"] = 2
			order[4] = &"ampulla"
		"shift":
			# The same genome, one organ on a different arc.
			order[3] = &""
			order[5] = &"ocellus"
	return [tiers, order]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BASE)
	var r := 28.3
	var scale := 1.7 if mode == "pov" else 1.0
	var fade := 0.34 if mode == "pov" else 1.0
	if fade_override >= 0.0:
		fade = fade_override
	var centre := size * 0.5
	var pair := _daughter()

	var seats := [centre - Vector2(spread, 0.0), centre + Vector2(spread, 0.0)]
	var genomes := [[MOTHER, MOTHER_ORDER], pair]
	for i in 2:
		var side := -1 if i == 0 else 1
		var lit := 1.0
		if lean != 0:
			lit = 1.0 if side == lean else 0.34
		var tiers: Dictionary = genomes[i][0]
		var order: Array = genomes[i][1]
		Cilia.draw_cell(self, seats[i], 0.0, r * scale, tiers,
			CellBody.gape_of(int(tiers.get(&"cytostome", 0)), r) * scale,
			r * scale, true, _clock + float(i) * 3.1, fade * lit, 0.0,
			0.0, float(i) * 1.7, 1.0, order, 0.0)
