extends Node
## **The dedicated server keeps itself current**, from the same release feed the
## phones and PCs read (`addons/launcher/update_service.gd`), and never while
## somebody is swimming.
##
## Every [member check_every] seconds, and once at start, it asks the launcher's
## `UpdateService.check_for_updates()` what is published, and then:
##
##   - **content newer**: `apply_pending_update()` downloads the pack, checks it
##     against the manifest's SHA-256 and stages it in `user://content`, where
##     `build_info.gd` mounts it at the next start. So the server restarts --
##   - **binary newer**: the launcher has no way to replace a Linux build (it
##     opens the releases page), so this downloads the manifest's `binary:linux`
##     artifact itself, hashes it with a `HashingContext`, refuses it on any
##     mismatch, and swaps it in with one `rename()` next to the running file:
##     the running process keeps the old inode, and the next start is the new
##     build. And then it restarts --
##
## -- **only once the pond has had nobody in it, connected or connecting, for
## [member restart_after] seconds.** A restart is an exit; `systemd`'s
## `Restart=always` starts the new build (`server/biogenic-server.service`).
## Never [code]UpdateService.restart_app()[/code], which spawns a child the
## service manager does not know about.
##
## A failed check or download changes nothing and is tried again at the next
## check. Every decision is one plain `[server] update:` line on stdout, which
## is what `journalctl -u biogenic-server` shows.
##
## **Only an exported server build applies anything** ([member can_apply]). Run
## from the editor or a source tree, the executable is the Godot editor and
## `user://` is the developer's: it checks and says what it would do, and does
## none of it.
##
## No class_name, and no autoload: see the note at the top of signal_bus.gd.

## For its `State` enum only: the values `check_for_updates()` returns. Nothing
## in the launcher is called from here but its two public coroutines.
const Service := preload("res://addons/launcher/update_service.gd")

## The owner's number: ten minutes between checks.
const CHECK_EVERY := 600.0
## How long the pond must stay empty before a staged update restarts it. Long
## enough that a guest who has just left and is calling again -- after a
## refusal, say -- is not met by a server going down under them.
const RESTART_AFTER := 30.0
## The download's whole budget: the launcher's own, for the same reason it
## gives (`HTTPRequest.timeout` is wall time from the request, not idle time).
const DOWNLOAD_TIMEOUT := 1800.0
const USER_AGENT := "BiogenicServer/1.0"

## The server wants to restart now, to finish [param why]. It is empty.
signal restart_wanted(why: String)

## **Seams, set before this node enters the tree**: the update service
## (the `UpdateService` autoload unless a test hands in its own), the file a
## binary update replaces (`OS.get_executable_path()` unless given), whether
## anything may be applied at all, and where the note about a pending restart
## is kept.
var service: Object = null
var exe_path := ""
var can_apply := false
var note_path := "user://server_update.json"
var check_every := CHECK_EVERY
var restart_after := RESTART_AFTER

## What is waiting for an empty pond: "", "content" or "binary", and its version.
var staged := ""
var staged_version := 0
## A check is in flight.
var busy := false
## How many checks have finished, for tools.
var checks := 0

var _next_check := 0.0
var _empty_since := -1.0
var _waiting_said := false
## Versions that were applied and did not take, `"content:106"` and the like:
## not tried again by this process, which is what stops a pack that will not
## mount from restarting the server every half minute forever.
var _refused := {}


func _ready() -> void:
	if service == null:
		service = get_node_or_null(^"/root/UpdateService")
	if exe_path.is_empty():
		exe_path = OS.get_executable_path()
	_read_note()


## **Once a frame, from the server**, with how many peers the session has --
## greeted or still greeting. Restarts when that has been 0 for
## [member restart_after] with something staged; starts a check when one is due.
func tick(peers: int) -> void:
	var now := _now()
	if not staged.is_empty():
		if peers > 0:
			_empty_since = -1.0
			if not _waiting_said:
				_waiting_said = true
				_say("%s %d is staged; waiting for the pond to empty (%d here)"
					% [staged, staged_version, peers])
		elif _empty_since < 0.0:
			_empty_since = now
		elif now - _empty_since >= restart_after:
			_restart()
			return
	if not busy and now >= _next_check:
		_next_check = now + check_every
		check()


## **One check, and whatever it leads to.** Awaitable; safe to call while one is
## running, which it ignores.
func check() -> void:
	if busy:
		return
	if service == null:
		_say("no update service here; not checking")
		return
	busy = true
	var result: int = await service.check_for_updates()
	var name := str((service.manifest as Dictionary).get("version_name", "?")) \
		if service.manifest is Dictionary else "?"
	match result:
		Service.State.UP_TO_DATE:
			_say("up to date (v%s, binary %d, content %d)" % [name, _binary(),
				_content()])
		Service.State.CONTENT_READY:
			await _take_content()
		Service.State.BINARY_READY:
			await _take_binary()
		Service.State.UNAVAILABLE:
			_say("nothing this build can take: %s -- checking again in %d min"
				% [_why(), roundi(check_every / 60.0)])
		_:
			_say("check failed: %s -- trying again in %d min"
				% [_why(), roundi(check_every / 60.0)])
	checks += 1
	busy = false


func _take_content() -> void:
	var version := int(service.pending_version)
	if _refused.has("content:%d" % version):
		_say("content %d did not mount after the last restart; not trying it"
			% version + " again until something newer is published")
		return
	if staged == "binary":
		# A new build carries newer content than any pack, and is coming.
		_say("content %d is published, but binary %d is already waiting"
			% [version, staged_version])
		return
	if staged == "content" and version <= staged_version:
		_say("content %d is staged; restarting when the pond is empty" % version)
		return
	if not can_apply:
		_say("content %d is published (running %d); not applying it: this is not"
			% [version, _content()] + " an exported server build")
		return
	_say("content %d is published (running %d); downloading and verifying it"
		% [version, _content()])
	var result: int = await service.apply_pending_update()
	if result != Service.State.RESTART_REQUIRED:
		_say("content %d failed: %s -- trying again in %d min"
			% [version, _why(), roundi(check_every / 60.0)])
		return
	staged = "content"
	staged_version = version
	_waiting_said = false
	_empty_since = -1.0
	_say("content %d verified and staged; restarting once the pond has been"
		% version + " empty for %d s" % roundi(restart_after))


func _take_binary() -> void:
	var version := int(service.pending_version)
	if _refused.has("binary:%d" % version):
		_say("binary %d was swapped in before and this is still binary %d; not"
			% [version, _binary()] + " trying it again until something newer is"
			+ " published")
		return
	if staged == "binary" and version <= staged_version:
		_say("binary %d is in place; restarting when the pond is empty" % version)
		return
	if not can_apply:
		_say("binary %d is published (running %d); not replacing %s: this is not"
			% [version, _binary(), exe_path] + " an exported server build")
		return
	var artifact: Dictionary = service.pending_artifact
	_say("binary %d is published (running %d); downloading %s"
		% [version, _binary(), str(artifact.get("url", "?"))])
	var swapped: bool = await swap_binary(artifact, version)
	if not swapped:
		return
	staged = "binary"
	staged_version = version
	_waiting_said = false
	_empty_since = -1.0
	_say("binary %d is in place; restarting once the pond has been empty for %d s"
		% [version, roundi(restart_after)])


## **Download [param artifact] next to [member exe_path], verify it, and swap
## it in.** Returns true only when the new build is in place.
##
## Written alongside and renamed over, which is atomic on one filesystem and
## allowed over a running executable on Linux: the process keeps the inode it
## is running from, and every later start gets the new file. The build it
## replaced is kept as `.previous`, for a rollback by hand. Refused, with the
## running build untouched and the download deleted, on a missing checksum or
## a checksum that does not match.
func swap_binary(artifact: Dictionary, version: int) -> bool:
	var url := str(artifact.get("url", ""))
	var expected := str(artifact.get("sha256", "")).strip_edges().to_lower()
	if url.is_empty() or expected.is_empty():
		_say("binary %d refused: the manifest gives no %s" % [version,
			"url" if url.is_empty() else "checksum"])
		return false
	var part := exe_path.get_base_dir().path_join("." + exe_path.get_file()
		+ ".download")
	if not await _download(url, part, version):
		DirAccess.remove_absolute(part)
		return false
	var actual := sha256_of(part)
	if actual != expected:
		DirAccess.remove_absolute(part)
		_say("binary %d refused: checksum mismatch -- the manifest says %s, the"
			% [version, expected] + " download is %s; keeping the running build"
			% (actual if not actual.is_empty() else "unreadable"))
		return false
	var mode := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER \
		| FileAccess.UNIX_EXECUTE_OWNER | FileAccess.UNIX_READ_GROUP \
		| FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_READ_OTHER \
		| FileAccess.UNIX_EXECUTE_OTHER
	FileAccess.set_unix_permissions(part, mode)
	if FileAccess.file_exists(exe_path):
		if DirAccess.copy_absolute(exe_path, exe_path + ".previous") == OK:
			FileAccess.set_unix_permissions(exe_path + ".previous", mode)
		else:
			_say("could not keep a copy of the running build as %s.previous;"
				% exe_path + " going on without one")
	var err := DirAccess.rename_absolute(part, exe_path)
	if err != OK:
		DirAccess.remove_absolute(part)
		_say("binary %d verified but could not be moved over %s (error %d);"
			% [version, exe_path, err] + " keeping the running build")
		return false
	_say("binary %d verified (sha256 %s) and swapped in at %s"
		% [version, expected, exe_path])
	return true


## SHA-256 of a file, as lowercase hex, streamed a megabyte at a time: a
## server build is tens of megabytes. "" if it cannot be read.
static func sha256_of(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		hashing.update(file.get_buffer(1 << 20))
	return hashing.finish().hex_encode()


func _download(url: String, dest: String, version: int) -> bool:
	var http := HTTPRequest.new()
	http.timeout = DOWNLOAD_TIMEOUT
	http.use_threads = true
	# GitHub serves release assets from a redirect to a signed CDN URL.
	http.max_redirects = 8
	http.download_file = dest
	add_child(http)
	var err := http.request(url, PackedStringArray(["User-Agent: " + USER_AGENT,
		"Accept: */*"]))
	if err != OK:
		http.queue_free()
		_say("binary %d: could not start the download (error %d); trying again in"
			% [version, err] + " %d min" % roundi(check_every / 60.0))
		return false
	var said: Array = await http.request_completed
	http.queue_free()
	var outcome := int(said[0])
	var code := int(said[1])
	if outcome == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		return true
	var what := "HTTP %d" % code if outcome == HTTPRequest.RESULT_SUCCESS \
		else "HTTPRequest result %d" % outcome
	if outcome == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN \
			or outcome == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		what += ", could not write %s -- is its folder writable by this user?" % dest
	_say("binary %d: download failed (%s); trying again in %d min"
		% [version, what, roundi(check_every / 60.0)])
	return false


## **The restart, noted first**: what it is for, so the next start can tell
## whether it took. The server does the exiting.
func _restart() -> void:
	var file := FileAccess.open(note_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"kind": staged, "version": staged_version}))
		file.close()
	var why := "%s %d, with the pond empty for %d s" % [staged, staged_version,
		roundi(restart_after)]
	staged = ""
	_say("restarting to finish %s" % why)
	restart_wanted.emit(why)


## **Did the last restart take?** A note left by [method _restart] names what it
## was for. If this process is not running it -- a pack that would not mount, a
## build that is not the one announced -- that version is not tried again here.
func _read_note() -> void:
	if not FileAccess.file_exists(note_path):
		return
	var file := FileAccess.open(note_path, FileAccess.READ)
	var said: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if file != null:
		file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(note_path)
		if note_path.begins_with("user://") else note_path)
	if not said is Dictionary:
		return
	var kind := str(said.get("kind", ""))
	var version := int(said.get("version", 0))
	var running := _binary() if kind == "binary" else _content()
	if kind != "binary" and kind != "content":
		return
	if running >= version:
		_say("restarted onto %s %d, as planned" % [kind, version])
		return
	_refused["%s:%d" % [kind, version]] = true
	var why := ""
	var info := get_node_or_null(^"/root/BuildInfo")
	if kind == "content" and info != null and not str(info.pack_error).is_empty():
		why = " (%s)" % str(info.pack_error)
	_say("restarted for %s %d, but this is still %s %d%s; not trying %d again"
		% [kind, version, kind, running, why, version])


func _binary() -> int:
	var info := get_node_or_null(^"/root/BuildInfo")
	return int(info.binary_version) if info != null else 0


func _content() -> int:
	var info := get_node_or_null(^"/root/BuildInfo")
	return int(info.content_version) if info != null else 0


func _why() -> String:
	var said := str(service.last_error) if service != null else ""
	return said if not said.is_empty() else "no reason given"


func _say(line: String) -> void:
	print("[server] update: " + line)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
