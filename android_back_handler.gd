extends Node
## Gère le bouton Back Android pour le launcher.
##
## Quand on est dans le launcher, le bouton Back doit quitter l'application.
## Ce nœud est un autoload qui écoute NOTIFICATION_WM_GO_BACK_REQUEST et
## quitte l'application uniquement lorsque la scène racine est le launcher.


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().root.get_child_count() > 0:
			var root_scene := get_tree().root.get_child(0)
			if root_scene.name == "Launcher":
				get_tree().quit()
