extends Node
## The launcher as it looks from the second time it is shown: with the catalogs
## registered, so a translator can look at their words on it.
##
## The launcher is the main scene, so the app builds it before any game script has
## loaded game/i18n/i18n.gd, and its first view is English in every language
## (game/i18n/README.md, "the launcher's first screen"). This preloads i18n.gd first,
## which is what a game screen does, and then builds the launcher:
##
##   godot --path . --language fr --rendering-driver opengl3 res://tools/shot.tscn -- \
##       --scene=res://tools/launcher_translated.tscn --out=/tmp/launcher_fr.png
##
## Excluded from export with the rest of tools/, so it never ships.

const I18n := preload("res://game/i18n/i18n.gd")


func _ready() -> void:
	I18n.register()
	var launcher := load("res://addons/launcher/launcher.tscn") as PackedScene
	if launcher == null:
		push_error("[launcher_translated] the launcher scene did not load")
		return
	add_child(launcher.instantiate())
