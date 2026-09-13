extends Node
## Screenshot harness: boots a scene, waits, and writes a PNG.
##
## Nobody on this project can open the Godot editor, so "it looks right" would
## otherwise be a guess. This makes it checkable:
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       res://tools/shot.tscn -- --out=/tmp/shot.png --wait=2.0
##
## Defaults to the launcher. Point --scene at a game scene once one exists.
## Excluded from export, so it never ships to players.

const DEFAULT_SCENE := "res://addons/launcher/launcher.tscn"


func _ready() -> void:
	var scene_path := DEFAULT_SCENE
	var out_path := "user://shot.png"
	var wait := 2.0
	var size := Vector2i.ZERO

	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--scene="):
			scene_path = text.trim_prefix("--scene=")
		elif text.begins_with("--out="):
			out_path = text.trim_prefix("--out=")
		elif text.begins_with("--wait="):
			wait = float(text.trim_prefix("--wait="))
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				size = Vector2i(int(parts[0]), int(parts[1]))

	# Shoot at a chosen window size so one run can prove both a desktop and a
	# phone-shaped screen, which is where layout actually breaks.
	#
	# Set the WINDOW only. Touching content_scale_size overrides the project's
	# canvas_items/expand stretch and renders 1:1, which makes every control look
	# tiny on a phone-sized shot and invents a layout bug that is not there.
	if size != Vector2i.ZERO:
		get_window().size = size

	if not ResourceLoader.exists(scene_path):
		push_error("[shot] No scene at %s" % scene_path)
		get_tree().quit(1)
		return

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("[shot] %s did not load as a PackedScene" % scene_path)
		get_tree().quit(1)
		return
	add_child(packed.instantiate())

	# Let the scene settle: layout, theme, any launch-time async work.
	await get_tree().create_timer(wait).timeout
	# get_image() reads the frame buffer, so it needs a frame to have landed.
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	if error != OK:
		push_error("[shot] Could not write %s (error %d)" % [out_path, error])
		get_tree().quit(1)
		return

	print("[shot] %s  %dx%d  <- %s" % [
		out_path, image.get_width(), image.get_height(), scene_path])
	get_tree().quit()
