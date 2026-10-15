extends Control
## **A sense's tile** (docs/design/sense-tiles.md): the organ that senses, drawn as its
## tile, lit by what it senses, and a thin bar under it for how much -- grey while
## the organ is not at work. The second kind of readout in the HUD's row, after the
## energy gauge, and as generic: it knows a gene's key (to draw it), a glow, a level,
## whether it is at work, and events that flash it. Which sense it is and where its
## numbers come from are the edge's (normal_mode.gd's `_update_gauges()`), as
## CLAUDE.md asks of every mechanic a later game reuses.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Cilia := preload("res://game/vision/cilia.gd")

## **The pause target's size**, so the row is one height and a tile one step of it.
const SIZE := 56.0
## The organ, a third again the size of a control pad's, so a glow reads at a glance.
const ORGAN_SCALE := 1.35
## Where its dome's centre sits, from the top: the organ stands on the dome, so the
## centre is low and the bristles fill the middle of the tile.
const ORGAN_Y := 37.0
## **The bar**: how much the sense picks up, 0 to 1, along the tile's foot.
const BAR_INSET := 12.0
const BAR_Y := 45.0
const BAR_H := 4.0
const TRACK := Color(0.855, 0.953, 0.933, 0.08)
## **An event's flash falls to nothing over this**: an echo coming home is a moment,
## not a level, so the tile lights at the echo's strength and fades.
const FLASH_FALL := 0.6
## **Not at work: grey**, faint, and no bar -- carried by the lineage and not worn by
## this body, or the senses held through a division.
const GREY := Color(0.62, 0.67, 0.66)
const GREY_ALPHA := 0.42

## The gene its tile draws.
var gene: StringName = &""
## How lit, 0..1, how much, 0..1, and whether it is at work.
var glow := 0.0
var level := 0.0
var active := true

var _well: StyleBoxFlat = null
var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SIZE, SIZE)
	set_process(false)


## Handed the slab, as the gauge is, and the gene it draws.
func setup(well: StyleBoxFlat, key: StringName) -> void:
	_well = well
	gene = key
	queue_redraw()


## **One reading**: lit [param new_glow], at [param new_level], at work or not.
## Redraws only when something it draws has changed.
func read(new_glow: float, new_level: float, at_work: bool) -> void:
	new_glow = clampf(new_glow, 0.0, 1.0)
	new_level = clampf(new_level, 0.0, 1.0)
	if is_equal_approx(new_glow, glow) and is_equal_approx(new_level, level) \
			and at_work == active:
		return
	glow = new_glow
	level = new_level
	active = at_work
	queue_redraw()


## **An event**: lit at [param strength] for a moment, fading over [constant
## FLASH_FALL] -- the next one lights it again.
func flash(strength: float) -> void:
	_flash = maxf(_flash, clampf(strength, 0.0, 1.0))
	set_process(true)
	queue_redraw()


## Forgets a flash: a new life starts on a quiet tile.
func settle() -> void:
	_flash = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta / FLASH_FALL)
	queue_redraw()
	if _flash <= 0.0:
		set_process(false)


func _draw() -> void:
	if _well != null:
		draw_style_box(_well, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)))
	if gene == &"":
		return
	var at := Vector2(SIZE * 0.5, ORGAN_Y)
	if not active:
		Cilia.draw_tile_organ(self, gene, 1, at, GREY_ALPHA, ORGAN_SCALE, 0.0, GREY)
		return
	Cilia.draw_tile_organ(self, gene, 1, at, Cilia.TILE_STROKE_ALPHA, ORGAN_SCALE,
		maxf(glow, _flash))
	var bar := Rect2(BAR_INSET, BAR_Y, SIZE - BAR_INSET * 2.0, BAR_H)
	draw_rect(bar, TRACK)
	if level > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * level, bar.size.y)),
			Color(Cilia.hue(gene), 0.9))
