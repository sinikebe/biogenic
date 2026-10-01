extends SceneTree
## **Every screen lays out in the shipped build as it does in this tree.**
##
## The exporter re-saves every scene in binary, and for an instanced Control it
## can write an override the text scene never had. Measured on 2026-10-01:
## - It gave the settings corner `anchors_preset = 0` on the view chooser, on
##   earshot and on the pause screen. That shrank the corner to nothing and drew
##   its gear 104 px past the screen's left edge on every phone, while every run
##   from this tree and every screenshot of it looked right. Writing the layout
##   the Godot editor would write on the instance (`layout_mode` and the anchors)
##   fixed it.
## - It gave every Control of `far.tscn`, then an inherited scene of earshot,
##   `layout_mode = 0` or `anchors_preset = 0`. That had piled the whole "by
##   invite" screen into its top-left corner on phones since it shipped. Writing
##   layout lines did not help an inherited scene, so far.tscn now holds an
##   earshot instance instead.
##
## So this loads every scene under game/ twice: from this tree, and from an
## exported content pack mounted over it. It instantiates each, without adding
## it to the tree, so no `_ready` runs, and compares every Control's layout:
## anchors, offsets, grow, size flags, minimum size and visibility. Any
## difference fails.
##
##   godot --headless --path . --script res://tools/export_layout_probe.gd -- \
##       --pack=build/content/content-android.pck
##
## Excluded from export with the rest of tools/, so it never ships.

const ROOT := "res://game"
const FIELDS: Array[StringName] = [&"anchor_left", &"anchor_top", &"anchor_right",
	&"anchor_bottom", &"offset_left", &"offset_top", &"offset_right", &"offset_bottom",
	&"grow_horizontal", &"grow_vertical", &"size_flags_horizontal",
	&"size_flags_vertical", &"custom_minimum_size", &"visible"]
## A float that differs by less than this is the same number written two ways.
const EPSILON := 0.01


func _initialize() -> void:
	var pack := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pack="):
			pack = arg.trim_prefix("--pack=")
	if pack.is_empty() or not FileAccess.file_exists(pack):
		print("[export-layout] FAIL: no exported content pack at --pack=%s" % pack)
		quit(1)
		return
	var scenes := _scenes(ROOT)
	var here := {}
	for path in scenes:
		here[path] = _layout(path)
	if not ProjectSettings.load_resource_pack(pack, true):
		print("[export-layout] FAIL: %s did not mount" % pack)
		quit(1)
		return
	var failed := 0
	var controls := 0
	for path in scenes:
		var source: Variant = here[path]
		var shipped: Variant = _layout(path)
		if source == null or shipped == null:
			print("[export-layout] FAIL %s: did not load %s" % [path,
				"here" if source == null else "from the pack"])
			failed += 1
			continue
		for node: String in (source as Dictionary):
			controls += 1
			if not (shipped as Dictionary).has(node):
				print("[export-layout] FAIL %s: %s is missing from the export" % [path, node])
				failed += 1
				continue
			for field: StringName in FIELDS:
				var a: Variant = source[node][field]
				var b: Variant = shipped[node][field]
				if not _same(a, b):
					print("[export-layout] FAIL %s: %s.%s is %s here and %s in the export"
						% [path, node, field, a, b])
					failed += 1
	if failed == 0:
		print("[export-layout] ALL PASS: %d scenes, %d controls lay out as in the source"
			% [scenes.size(), controls])
	else:
		print("[export-layout] %d FAILED" % failed)
	quit(0 if failed == 0 else 1)


## Every `.tscn` under [param dir], sorted, so two runs list them alike.
func _scenes(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tscn":
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_scenes(dir.path_join(sub)))
	found.sort()
	return found


## Every Control in the scene at [param path], by its path from the scene's root:
## the [constant FIELDS] it was loaded with -- empty for a scene with none, null
## for one that does not load. Loaded past every cache, so after the pack is
## mounted this reads the exported scene, and the scenes it instances.
func _layout(path: String) -> Variant:
	var scene := ResourceLoader.load(path, "PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	if root == null:
		return null
	var out := {}
	_walk(root, root, out)
	root.free()
	return out


func _walk(root: Node, node: Node, out: Dictionary) -> void:
	if node is Control:
		var record := {}
		for field: StringName in FIELDS:
			record[field] = node.get(field)
		out[str(root.get_path_to(node))] = record
	for child in node.get_children():
		_walk(root, child, out)


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		return absf(float(a) - float(b)) < EPSILON
	if typeof(a) == TYPE_VECTOR2 and typeof(b) == TYPE_VECTOR2:
		return (a as Vector2).distance_to(b as Vector2) < EPSILON
	return a == b
