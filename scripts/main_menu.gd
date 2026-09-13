extends Control
## Main menu. Owns the update UI; UpdateService owns the update logic.

## Set this once there is a game to start. While it is empty, Play explains
## itself instead of failing silently.
const GAME_SCENE := ""

@onready var _tagline: Label = %Tagline
@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _update_button: Button = %UpdateButton
@onready var _progress: ProgressBar = %UpdateProgress

@onready var _overlay: Control = %UpdateOverlay
@onready var _overlay_title: Label = %OverlayTitle
@onready var _overlay_body: Label = %OverlayBody
@onready var _overlay_primary: Button = %OverlayPrimary
@onready var _overlay_secondary: Button = %OverlaySecondary

## What the overlay's primary button should do when pressed.
var _overlay_action: Callable = Callable()


func _ready() -> void:
	# Reads the live build number rather than a hardcoded string, so every
	# update visibly changes the tagline -- which is the quickest way to confirm
	# from across the room that an update actually landed.
	_tagline.text = "build %d · updates itself" % BuildInfo.content_version
	_version_label.text = BuildInfo.display_version()
	_overlay.hide()
	_progress.hide()

	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_update_button.pressed.connect(_on_update_pressed)
	_overlay_primary.pressed.connect(_on_overlay_primary)
	_overlay_secondary.pressed.connect(_hide_overlay)

	UpdateService.state_changed.connect(_on_update_state_changed)
	UpdateService.progress_changed.connect(_on_progress_changed)

	if not BuildInfo.pack_error.is_empty():
		push_warning("[MainMenu] " + BuildInfo.pack_error)

	_play_button.grab_focus()
	_refresh_update_ui()

	# Let the menu paint before touching the network.
	await get_tree().create_timer(0.4).timeout
	await UpdateService.check_for_updates()


# ---------------------------------------------------------------------------
# Menu actions
# ---------------------------------------------------------------------------

func _on_play_pressed() -> void:
	if GAME_SCENE.is_empty():
		_show_overlay(
			"Not built yet",
			"This is where the game will start. Point MainMenu.GAME_SCENE at your "
			+ "first scene and this button will load it.",
			"OK", Callable(self, "_hide_overlay"), "")
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


## The update button is the single entry point: it checks, then downloads, then
## restarts, depending on where the updater currently is.
func _on_update_pressed() -> void:
	match UpdateService.state:
		UpdateService.State.CONTENT_READY, UpdateService.State.BINARY_READY:
			await _prompt_update()
		UpdateService.State.NEEDS_PERMISSION:
			await UpdateService.retry_install()
		UpdateService.State.RESTART_REQUIRED:
			_prompt_restart()
		_:
			await UpdateService.check_for_updates()


# ---------------------------------------------------------------------------
# Update UI
# ---------------------------------------------------------------------------

func _on_update_state_changed(_new_state: int) -> void:
	_refresh_update_ui()

	match UpdateService.state:
		UpdateService.State.RESTART_REQUIRED:
			_prompt_restart()
		UpdateService.State.INSTALL_HANDOFF:
			_show_overlay(
				"Installing",
				"Confirm the update in the system installer. Biogenic will reopen "
				+ "on the new version once the install finishes.",
				"OK", Callable(self, "_hide_overlay"), "")
		_:
			pass


func _refresh_update_ui() -> void:
	_status_label.text = UpdateService.status_text()

	var busy := UpdateService.state in [
		UpdateService.State.CHECKING,
		UpdateService.State.DOWNLOADING,
		UpdateService.State.VERIFYING,
	]
	_progress.visible = UpdateService.state == UpdateService.State.DOWNLOADING
	_update_button.disabled = busy

	match UpdateService.state:
		UpdateService.State.BINARY_READY:
			_update_button.text = "Update app"
		UpdateService.State.CONTENT_READY:
			_update_button.text = "Download update"
		UpdateService.State.NEEDS_PERMISSION:
			_update_button.text = "Install"
		UpdateService.State.RESTART_REQUIRED:
			_update_button.text = "Restart"
		UpdateService.State.CHECKING:
			_update_button.text = "Checking…"
		UpdateService.State.DOWNLOADING, UpdateService.State.VERIFYING:
			_update_button.text = "Working…"
		_:
			_update_button.text = "Check for updates"


func _on_progress_changed(downloaded: int, total: int) -> void:
	if total > 0:
		_progress.max_value = total
		_progress.value = downloaded
		_status_label.text = "Downloading… %s of %s" % [
			_format_bytes(downloaded), _format_bytes(total)]
	else:
		# No Content-Length: show motion without a bogus percentage.
		_progress.max_value = 1
		_progress.value = 0
		_status_label.text = "Downloading… %s" % _format_bytes(downloaded)


## Shows what the update actually contains before spending a download on it.
func _prompt_update() -> void:
	var notes := UpdateService.pending_notes_text()
	if notes.is_empty():
		# Nothing worth reading; don't make anyone dismiss an empty dialog.
		await UpdateService.apply_pending_update()
		return

	var is_binary := UpdateService.state == UpdateService.State.BINARY_READY
	var size := _format_bytes(int(UpdateService.pending_artifact.get("size", 0)))
	var summary := ("New app build · %s" if is_binary else "Content update · %s") % size

	_show_overlay(
		"What's new in v%s" % UpdateService.manifest.get("version_name", "?"),
		"%s\n\n%s" % [summary, notes],
		"Update now" if is_binary else "Download",
		Callable(self, "_do_apply"),
		"Later")


func _do_apply() -> void:
	await UpdateService.apply_pending_update()


func _prompt_restart() -> void:
	var body := "The update is downloaded. Biogenic needs to restart to finish applying it."
	if OS.has_feature("editor"):
		body += "\n\nRunning from the editor: stop and play the project again."
	_show_overlay("Update ready", body, "Restart now", Callable(self, "_do_restart"), "Later")


func _do_restart() -> void:
	if UpdateService.restart_app():
		return
	_show_overlay(
		"Restart needed",
		"Close Biogenic and open it again to finish the update.",
		"OK", Callable(self, "_hide_overlay"), "")


# ---------------------------------------------------------------------------
# Overlay
# ---------------------------------------------------------------------------

func _show_overlay(title: String, body: String, primary_text: String,
		primary_action: Callable, secondary_text: String) -> void:
	_overlay_title.text = title
	_overlay_body.text = body
	_overlay_primary.text = primary_text
	_overlay_action = primary_action
	_overlay_secondary.text = secondary_text
	_overlay_secondary.visible = not secondary_text.is_empty()
	_overlay.show()
	_overlay_primary.grab_focus()


func _hide_overlay() -> void:
	_overlay.hide()
	_overlay_action = Callable()
	_play_button.grab_focus()


func _on_overlay_primary() -> void:
	var action := _overlay_action
	_hide_overlay()
	if action.is_valid():
		action.call()


func _format_bytes(count: int) -> String:
	if count < 1024:
		return "%d B" % count
	if count < 1024 * 1024:
		return "%.1f KB" % (count / 1024.0)
	return "%.1f MB" % (count / (1024.0 * 1024.0))
