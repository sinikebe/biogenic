extends Node2D
## **The specimen sheet** (docs/design/gene-looks.md §9.4): every live organ the
## catalogue holds, by family, on a body of true size at one copy and at three, and
## beside them its tile -- the vocabulary a player learns, on one screen, so a new
## organ is seen beside its nearest neighbours before it ships. Nothing here names a
## gene: it lists what the catalogue lists.
##
##   godot --path . --rendering-driver opengl3 res://tools/shot.tscn -- \
##       --scene=res://tools/looks_sheet.tscn --out=/tmp/sheet.png --wait=0.5
##
## User args: `--r=<body radius>` (default 30); `--self=1` draws every body as the
## player's own, pure teal; `--clock=<s>` (default 0.6); `--zoom=<k>` scales the
## sheet; `--only=<family>` draws one family large. `--variants=1` lays out the
## variants `tools/looks_specimens.gd` files, each beside its organ as shipped, and
## `--room=1` its organs no file holds, at one copy and three.
##
## Excluded from export (`tools/*`), so it never ships. No class_name, for the
## reason signal_bus.gd gives.

const Cilia := preload("res://game/vision/cilia.gd")
const CellBody := preload("res://game/normal/cell.gd")
const Genome := preload("res://game/normal/genome.gd")
const Catalogue := preload("res://game/genes/catalogue.gd")
const Families := preload("res://game/genes/families.gd")
const BodyPlan := preload("res://game/genes/body_plan.gd")
const Specimens := preload("res://tools/looks_specimens.gd")

## The tile's box on the sheet, and the label's ink.
const TILE_BOX := 60.0
const INK := Color(0.855, 0.953, 0.933, 0.62)
const HEAD := Color(0.855, 0.953, 0.933, 0.7)
## The first free slot an earned organ is seated in, and a side slot, where an organ
## that rides the bite shows its barbs rather than its fangs.
const EARNED_SLOT := 3
const SIDE_SLOT := 5

var r := 30.0
var as_self := false
var clock := 0.6
var zoom := 1.0
var only := ""
var variants := false
var room := false
var _filed: Array[StringName] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var t := str(arg)
		if t.begins_with("--r="):
			r = float(t.trim_prefix("--r="))
		elif t.begins_with("--self="):
			as_self = t.trim_prefix("--self=") == "1"
		elif t.begins_with("--clock="):
			clock = float(t.trim_prefix("--clock="))
		elif t.begins_with("--zoom="):
			zoom = float(t.trim_prefix("--zoom="))
		elif t.begins_with("--only="):
			only = t.trim_prefix("--only=")
		elif t == "--variants=1":
			variants = true
		elif t == "--room=1":
			room = true
	if variants:
		_filed = Specimens.file_variants()
	elif room:
		_filed = Specimens.file_room()
	RenderingServer.set_default_clear_color(Color(0.023, 0.055, 0.05, 1))
	queue_redraw()


func _exit_tree() -> void:
	Specimens.forget(_filed)


## **A born cell's body with [param gene] at [param tier]**, seated where it would
## be: a home organ on its home arc, a variant of one in its place, an inside form
## inside, an organ that rides the bite on a side (where it is barbs), any other on
## the first free arc.
func _body_for(gene: StringName, tier: int) -> Array:
	var tiers := Catalogue.born().duplicate()
	var order: Array = BodyPlan.home_layout(Catalogue.born_order())
	while order.size() < BodyPlan.INSIDE:
		order.append(&"")
	tiers[gene] = tier
	if BodyPlan.homes().has(gene) or Genome.is_inside_form(gene):
		return [tiers, order]
	var shipped: StringName = Catalogue.keys_of_organ(Catalogue.organ_of(gene))[0]
	if shipped != gene and BodyPlan.homes().has(shipped):
		tiers.erase(shipped)
		order[BodyPlan.home_slot(shipped)] = gene
		return [tiers, order]
	order[SIDE_SLOT if bool(Catalogue.look(gene).get("lips", false)) else EARNED_SLOT] = gene
	return [tiers, order]


## The keys of [param family] the sheet shows: every live key's organ as shipped, and
## every form of it.
func _keys_of(family: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in Catalogue.live():
		if Catalogue.family_of(key) == family and Catalogue.as_shipped(key) \
				and not _filed.has(Catalogue.organ_of(key)):
			out.append(key)
	return out


func _draw() -> void:
	if variants:
		_draw_variants()
		return
	if room:
		_draw_room()
		return
	var font := ThemeDB.fallback_font
	var view := get_viewport_rect().size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * zoom)
	var families: Array = Families.FAMILIES.keys()
	var col_w := view.x / zoom / float(families.size())
	var row_h := r * 4.25
	for c in families.size():
		var family: StringName = families[c]
		if only != "" and String(family) != only:
			continue
		var x0 := col_w * float(c) if only == "" else 20.0
		draw_string(font, Vector2(x0 + 10.0, 22.0), String(family),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, HEAD)
		var keys := _keys_of(family)
		for i in keys.size():
			var gene: StringName = keys[i]
			var y := 40.0 + row_h * float(i) + r * 1.5
			for k in 2:
				var pose := _body_for(gene, 1 if k == 0 else 3)
				var tiers: Dictionary = pose[0]
				var at := Vector2(x0 + 40.0 + r * 2.5 * float(k), y)
				Cilia.draw_cell(self, at, 0.0, r, tiers, CellBody.gape_of(tiers, r), 1000.0,
					as_self, clock, 1.0, 0.0, 0.0, float(i) * 1.7 + float(k), 1.0, pose[1])
			_draw_tile(gene, Vector2(x0 + 40.0 + r * 5.0 - 18.0, y - 40.0))
			draw_string(font, Vector2(x0 + 8.0, y + r * 1.62 + 8.0), "%s  %s" % [gene,
				Catalogue.words(gene).get(&"word", "")], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12,
				INK)


## A tile, in its box.
func _draw_tile(gene: StringName, corner: Vector2) -> void:
	draw_rect(Rect2(corner, Vector2(TILE_BOX, TILE_BOX)), Color(0.063, 0.141, 0.125, 0.35))
	Cilia.draw_tile_organ(self, gene, 1,
		corner + Vector2(TILE_BOX * 0.5, TILE_BOX * Cilia.TILE_CENTRE_Y))


## **Every variant filed, beside its organ as shipped**: one row an organ, each at
## two copies on its body and as its tile, labelled with its accent.
func _draw_variants() -> void:
	var font := ThemeDB.fallback_font
	var row_h := r * 3.7
	var organs: Array[StringName] = []
	for organ: StringName in _filed:
		if not organs.has(organ):
			organs.append(organ)
	for i in organs.size():
		var keys: Array[StringName] = []
		for key: StringName in Catalogue.keys_of_organ(organs[i]):
			# One form a variant: the outside one, where a strain shows its barbs.
			if Genome.is_inside_form(key) and Catalogue.form_in(key, Genome.OUTSIDE_PLACE) != &"":
				continue
			keys.append(key)
		var y := 30.0 + r * 1.4 + row_h * float(i)
		for k in keys.size():
			var gene: StringName = keys[k]
			var pose := _body_for(gene, 2)
			var tiers: Dictionary = pose[0]
			var x := 60.0 + float(k) * 300.0
			Cilia.draw_cell(self, Vector2(x, y), 0.0, r, tiers, CellBody.gape_of(tiers, r),
				1000.0, as_self, clock, 1.0, 0.0, 0.0, float(i + k), 1.0, pose[1])
			_draw_tile(gene, Vector2(x + r * 1.9, y - 30.0))
			var accent := Cilia.accent_of(gene)
			draw_string(font, Vector2(x + r * 1.9, y + 44.0), "as shipped" if accent == &""
				else "%s, accent %s" % [Catalogue.variant_of(gene), accent],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, INK)


## **Every organ no file holds**, by family, at one copy and three, and its tile.
func _draw_room() -> void:
	var font := ThemeDB.fallback_font
	var y := 40.0 + r * 1.6
	for family: StringName in Families.FAMILIES:
		var keys: Array[StringName] = []
		for organ: StringName in _filed:
			if Catalogue.family_of(organ) == family:
				keys.append(organ)
		if keys.is_empty():
			continue
		draw_string(font, Vector2(14.0, y - r * 1.55), String(family),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, HEAD)
		var x := 60.0
		for gene: StringName in keys:
			for tier: int in [1, 3]:
				var pose := _body_for(gene, tier)
				Cilia.draw_cell(self, Vector2(x, y), 0.0, r, pose[0],
					CellBody.gape_of(pose[0], r), 1000.0, as_self, clock, 1.0, 0.0, 0.0, x * 0.01,
					1.0, pose[1])
				x += r * 2.5
			_draw_tile(gene, Vector2(x - r * 0.6, y - 30.0))
			var look := Catalogue.look(gene)
			draw_string(font, Vector2(x - r * 5.0, y + r * 2.0), "%s, %s" % [look["shape"],
				_structure(look)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, INK)
			x += 90.0
		y += r * 4.3


## What makes [param look] its own organ: its structural parameters, in words.
func _structure(look: Dictionary) -> String:
	var out := PackedStringArray()
	for one: Variant in Catalogue.Kinds.signature(look).slice(1):
		out.append("%s %s" % [one[0], str(one[1])])
	return ", ".join(out)
