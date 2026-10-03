extends SceneTree
## **The chase contract at a hunter's own speed** (docs/design/ocean.md §5.7,
## §15.6; food-and-predators.md §5.4.1): a cell that does nothing is caught, and
## one that turns away and commits escapes. Wraps tools/drive.tscn with its
## `--hunt=` and `--evade`, and prints whether the posed hunter caught the cell
## within `--chase-for=` seconds, and how many runs it ended without a kill.
##
##   godot --headless --path . --fixed-fps 60 -s res://tools/chase_probe.gd -- \
##       --seed=1 --mode=0 --scheme=0 --hunt=900 --chase-for=40 --desert=1500 \
##       [--evade] [--hunter-genome=cytostome:3,flagellum:1[,myoneme:1]] [--own-speed=0]
##
## **In the drop the hunter is a body of its own** (drive.gd), in a slot nothing
## else uses, so the opening -- which moves the first drifter along the cell's
## first motion -- never moves it (§15.6, §16 item 13). **Pass `--desert=`**:
## the drop is full, and a hunter posed on top of a body it can swallow eats that
## on its first frame, rests, and never runs at you -- seed 1 without it reads
## "escaped" for a cell that did nothing. `--drop=0` runs today's water, where
## the posed hunter is body 0 and the opening can move it, as the document's
## rows were measured. `--own-speed=0` is today's 1.2 and 1.7 times the prey's
## speed. The cell is born, so FIRST_DELAY forbids a second run at it inside
## the forty seconds: this measures one pass -- though in the drop a mouth that
## fits still swallows on contact (row 15), so a missed pass the hunter then
## drifts into ends in a catch, as it would in play.
##
## Prints `[chase] caught|escaped at t s, runs ended n`. Excluded from export
## (`tools/*` on every preset), so none of it ships.

const FoodField := preload("res://game/normal/food.gd")

var _drive: Node
var _food: Node
var _t := 0.0
var _for := 40.0
var _caught := -1.0
var _ended := 0
var _was_stalking := false


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--chase-for="):
			_for = float(a.trim_prefix("--chase-for="))
	_drive = (load("res://tools/drive.tscn") as PackedScene).instantiate()
	root.add_child(_drive)


func _process(delta: float) -> bool:
	_t += delta
	if _food == null:
		_food = _drive.get("_food")
		if _food != null:
			_food.connect(&"killed", func(_b: float) -> void:
				if _caught < 0.0:
					_caught = _t)
	if _food != null:
		var cells: Array = _food.get("_cells")
		var slot := int(_drive.get("_hunter_slot"))
		if slot < cells.size():
			var stalking := int(cells[slot].get("state")) == FoodField.State.STALK
			if _was_stalking and not stalking and _caught < 0.0:
				_ended += 1
			_was_stalking = stalking
	if _caught >= 0.0 or _t >= _for:
		print("[chase] %s at %.1f s, runs ended %d" % [
			"caught" if _caught >= 0.0 else "escaped", _caught if _caught >= 0.0 else _t,
			_ended])
		quit()
	return false
