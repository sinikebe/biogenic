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
##     mismatch, **asks it for its version to see that it starts on this
##     machine** ([method preflight]), and swaps it in with one `rename()` next
##     to the running file: the running process keeps the old inode, and the
##     next start is the new build. And then it restarts --
##
## -- **only once the pond has had nobody in it -- no guest, and no phone in the
## house in the middle of joining -- for [member restart_after] seconds.** A
## restart is an exit; `systemd`'s `Restart=always` starts the new build
## (`server/biogenic-server.service`).
## Never [code]UpdateService.restart_app()[/code], which spawns a child the
## service manager does not know about.
##
## A failed check or download changes nothing and is tried again at the next
## check -- except a build it has refused, which is not fetched again while the
## manifest gives it the same checksum and this process runs. Content built for
## another binary than this one is never taken. Every decision is one plain
## `[server] update:` line on stdout, which is what `journalctl -u
## biogenic-server` shows.
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
## **The most a build download may weigh before it is abandoned** (#77). The
## swap refuses any download whose bytes do not hash to the manifest's sha256
## ([method swap_binary]), but the hash is checked only once the whole file is
## on disk -- so without a ceiling a manifest naming a valid-looking build and a
## url that never stopped sending could fill the disk before the mismatch was
## caught. Each download is held to twice the size the manifest declares for it
## ([method _download]); this is the backstop for a manifest that declares none,
## or lies about it. `HTTPRequest` counts the bytes as they arrive -- against a
## Content-Length when there is one, and against the running total when there is
## not (a chunked or lying length) -- and gives up the moment either crosses the
## limit. Well above any real server build (tens of megabytes), well under the
## smallest sensible disk.
const DOWNLOAD_MAX := 512 * 1024 * 1024
const USER_AGENT := "BiogenicServer/1.0"

## The server wants to restart now, to finish [param why]. It is empty.
signal restart_wanted(why: String)
## Every decision, as the line it is printed as -- for tools; the journal has
## stdout.
signal said(line: String)

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
## mount from restarting the server every half minute forever. **In memory
## only**: the next start of the process -- a reboot, a crash -- tries each
## once more, which costs one download and one restart.
var _refused := {}
## **Builds refused before they were swapped in** -- a download whose SHA-256
## is not the manifest's, or a build that does not start on this machine -- as
## `{version: the manifest's sha256 for it then}`. Not downloaded again while
## the manifest still says that about that version: a release that stays
## broken would otherwise cost the whole build, 74 MB, every ten minutes, some
## ten gigabytes a day. A new checksum for it is tried. In memory, like
## [member _refused].
var _refused_builds := {}
## The refused build last said to be skipped, `"version:sha256"`: said once.
var _skip_said := ""


func _ready() -> void:
	if service == null:
		service = get_node_or_null(^"/root/UpdateService")
	if exe_path.is_empty():
		exe_path = OS.get_executable_path()
	if can_apply:
		_sweep()
	_read_note()


## **What a stop in the middle of an update left behind**: a download, or a
## copy of the running build half made -- some 74 MB each, and nothing but the
## next binary update would ever have replaced them. The finished `.previous`
## stays: it is the way back.
func _sweep() -> void:
	for leftover: String in [_download_path(), exe_path + ".previous.part"]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(leftover)
			_say("removed %s, left by a stop in the middle of an update" % leftover)


## **Once a frame, from the server**, with how many peers a restart would
## interrupt -- `NetSession.company()`: every greeted guest, and every caller
## on the LAN still greeting, but never a caller on the internet listener that
## has proved nothing, or a stranger calling every few seconds could hold an
## update off for good. Restarts when that has been 0 for
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
		elif now - _empty_since >= restart_after and not busy:
			# Not in the middle of a check: a newer download may be on its way,
			# and it is worth the restart it would otherwise cost.
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
	# The launcher offers content whenever the binary number has not gone up --
	# including when it has gone *down*, and a pack built for another binary is
	# not this one's to mount.
	var built_for := int((service.manifest as Dictionary).get("binary_version", -1)) \
		if service.manifest is Dictionary else -1
	if built_for != _binary():
		_say("content %d is published for binary %d, and this is binary %d; not"
			% [version, built_for, _binary()] + " taking it")
		return
	if _refused.has("content:%d" % version):
		_say("content %d did not mount after the last restart; not trying it"
			% version + " again while this server runs")
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
		% version + " empty for %s s" % str(snappedf(restart_after, 0.01)))


func _take_binary() -> void:
	var version := int(service.pending_version)
	if _refused.has("binary:%d" % version):
		_say("binary %d was swapped in before and this is still binary %d; not"
			% [version, _binary()] + " trying it again while this server runs")
		return
	if staged == "binary" and version <= staged_version:
		_say("binary %d is in place; restarting when the pond is empty" % version)
		return
	if not can_apply:
		_say("binary %d is published (running %d); not replacing %s: this is not"
			% [version, _binary(), exe_path] + " an exported server build")
		return
	var artifact: Dictionary = service.pending_artifact
	var sha := str(artifact.get("sha256", "")).strip_edges().to_lower()
	if str(_refused_builds.get(version, "")) == sha and not sha.is_empty():
		if _skip_said != "%d:%s" % [version, sha]:
			_skip_said = "%d:%s" % [version, sha]
			_say("binary %d was refused, and the manifest still gives it the same"
				% version + " checksum; not downloading it again until that changes")
		return
	_say("binary %d is published (running %d); downloading %s"
		% [version, _binary(), str(artifact.get("url", "?"))])
	var swapped: bool = await swap_binary(artifact, version)
	if not swapped:
		return
	staged = "binary"
	staged_version = version
	_waiting_said = false
	_empty_since = -1.0
	_say("binary %d is in place; restarting once the pond has been empty for %s s"
		% [version, str(snappedf(restart_after, 0.01))])


## **Download [param artifact] next to [member exe_path], verify it, and swap
## it in.** Returns true only when the new build is in place.
##
## Written alongside and renamed over, which is atomic on one filesystem and
## allowed over a running executable on Linux: the process keeps the inode it
## is running from, and every later start gets the new file. The build it
## replaced is kept as `.previous`, for a rollback by hand -- and a build that
## arrives while another is still waiting to be started replaces that one, and
## leaves `.previous` as the build that ran. Refused, with the running build
## and `.previous` untouched and the download deleted, on a missing checksum,
## a checksum that does not match, or a build that does not start here
## ([method preflight]); the last two are remembered ([member _refused_builds]).
##
## Guests may be swimming through all of it, so nothing here takes more than a
## frame's worth at once: the download is on `HTTPRequest`'s thread, the
## hashing and the copy go a megabyte a frame ([method sha256_of]), and the
## pre-flight takes some 25 ms.
func swap_binary(artifact: Dictionary, version: int) -> bool:
	var url := str(artifact.get("url", ""))
	var expected := str(artifact.get("sha256", "")).strip_edges().to_lower()
	if url.is_empty() or expected.is_empty():
		_say("binary %d refused: the manifest gives no %s" % [version,
			"url" if url.is_empty() else "checksum"])
		return false
	var part := _download_path()
	if not await _download(url, part, version, int(artifact.get("size", -1))):
		DirAccess.remove_absolute(part)
		return false
	var actual: String = await sha256_of(part)
	if actual != expected:
		DirAccess.remove_absolute(part)
		if not actual.is_empty():
			# A download that could not be read back says nothing about the
			# release: this machine's disk, and the next check tries again.
			_refused_builds[version] = expected
		_say("binary %d refused: checksum mismatch -- the manifest says %s, the"
			% [version, expected] + " download is %s; keeping the running build"
			% (actual if not actual.is_empty() else "unreadable"))
		return false
	var mode := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER \
		| FileAccess.UNIX_EXECUTE_OWNER | FileAccess.UNIX_READ_GROUP \
		| FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_READ_OTHER \
		| FileAccess.UNIX_EXECUTE_OTHER
	FileAccess.set_unix_permissions(part, mode)
	var ran := preflight(part)
	if not bool(ran["ok"]):
		DirAccess.remove_absolute(part)
		if int(ran["code"]) == -1:
			# No process could be started to ask: this machine's trouble for
			# now, not the build's, so it is not remembered against it.
			_say("binary %d: could not start anything to ask it for its version;"
				% version + " keeping the running build, and trying again in %d min"
				% roundi(check_every / 60.0))
			return false
		_refused_builds[version] = expected
		_say("binary %d refused: it does not start on this machine -- %s; keeping"
			% [version, str(ran["why"])] + " the running build")
		return false
	# The copy worth keeping is of the build that ran. One that is only waiting
	# for the pond to empty never has, and `.previous` already holds the one
	# this process is.
	var over_staged := staged == "binary"
	if not over_staged and FileAccess.file_exists(exe_path):
		if await _copy_paced(exe_path, exe_path + ".previous"):
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
	_say("binary %d verified (sha256 %s), starts here (%s), and swapped in at %s%s"
		% [version, expected, str(ran["version"]), exe_path,
			"; binary %d, waiting there, never ran, so %s.previous was left as it"
				% [staged_version, exe_path] + " was" if over_staged else ""])
	return true


## **Does the build at [param path] start on this machine?** It is asked for
## its version -- `--headless --version`, which an exported server answers in
## some 25 ms without loading the game or opening a port -- and must exit 0 and
## name a version. CI started this same build, on its own runner; this is what
## says it starts on this one. A build that needs a newer glibc or a newer CPU
## than this container has fails here, and is never swapped in to fail at every
## restart instead. Returns `{ok, code, version, why}`; `code` is -1 when no
## process could be started to ask.
func preflight(path: String) -> Dictionary:
	var output: Array = []
	var code := OS.execute(path, PackedStringArray(["--headless", "--version"]), output)
	var said := str(output[0]).strip_edges().get_slice("\n", 0) \
		if not output.is_empty() else ""
	if code == 0 and _names_a_version(said):
		return {"ok": true, "code": code, "version": said, "why": ""}
	return {"ok": false, "code": code, "version": said,
		"why": "`--version` exited %d and said %s"
			% [code, "\"%s\"" % said.left(80) if not said.is_empty() else "nothing"]}


## **"4.7.stable.official.5b4e0cb0f", or any other `N.M...`.** The exit code
## alone is not enough: Godot reads it through popen without asking whether
## the child exited or was killed, so a build that dies on a signal can come
## back as 0 with nothing said -- and that is what this refuses. Any major
## version passes, on purpose: the build that moves Godot to 5 is swapped in by
## the updater every server already runs, so a check for "4." written here
## would refuse it everywhere, with no content update able to reach the check
## in time.
static func _names_a_version(said: String) -> bool:
	var parts := said.split(".")
	return parts.size() >= 2 and parts[0].is_valid_int() and int(parts[0]) > 0 \
		and not parts[1].is_empty() and parts[1].left(1).is_valid_int()


## **SHA-256 of a file**, as lowercase hex, or "" if it cannot be read.
## Awaitable, and paced at a megabyte a frame while in the tree: a server build
## is some 74 MB, and hashing all of it at once stops the pond for about a
## quarter of a second (measured: 230 ms) under whoever is swimming in it.
func sha256_of(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		var chunk := file.get_buffer(1 << 20)
		if chunk.is_empty():
			return ""
		hashing.update(chunk)
		await _next_frame()
	return hashing.finish().hex_encode()


## [param from] copied to [param to], paced like [method sha256_of], and
## through `to.part` and a rename, so a stop that lands halfway leaves the last
## whole copy where it was. False if anything fails, with the part removed.
func _copy_paced(from: String, to: String) -> bool:
	var part := to + ".part"
	var source := FileAccess.open(from, FileAccess.READ)
	var target := FileAccess.open(part, FileAccess.WRITE)
	var ok := source != null and target != null
	while ok and source.get_position() < source.get_length():
		var chunk := source.get_buffer(1 << 20)
		ok = not chunk.is_empty() and target.store_buffer(chunk)
		await _next_frame()
	if target != null:
		target.close()
	ok = ok and DirAccess.rename_absolute(part, to) == OK
	if not ok:
		DirAccess.remove_absolute(part)
	return ok


func _next_frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame


## Where a new build is downloaded to: beside the running one, hidden.
func _download_path() -> String:
	return exe_path.get_base_dir().path_join("." + exe_path.get_file() + ".download")


func _download(url: String, dest: String, version: int, declared: int = -1) -> bool:
	var http := HTTPRequest.new()
	http.timeout = DOWNLOAD_TIMEOUT
	http.use_threads = true
	# GitHub serves release assets from a redirect to a signed CDN URL.
	http.max_redirects = 8
	# **A ceiling on what lands on disk before the checksum is even reached**
	# (#77): twice the size the manifest declares, but never past DOWNLOAD_MAX,
	# which holds even when the manifest is the thing lying. HTTPRequest gives up
	# the moment the bytes cross it, so a url that never stops sending cannot
	# fill the disk.
	var cap := mini(DOWNLOAD_MAX, declared * 2) if declared > 0 else DOWNLOAD_MAX
	http.body_size_limit = cap
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
	if outcome == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		what = "the download went past its %d-byte ceiling -- abandoned before it" % cap \
			+ " could fill the disk"
	elif outcome == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN \
			or outcome == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		what += ", could not write %s -- disk full, or not writable by this user" % dest
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
	var why := "%s %d, with the pond empty for %s s" % [staged, staged_version,
		str(snappedf(restart_after, 0.01))]
	staged = ""
	_say("restarting to finish %s" % why)
	restart_wanted.emit(why)


## **Did the last restart take?** A note left by [method _restart] names what it
## was for. If this process is not running it -- a pack that would not mount, a
## build that is not the one announced -- that version is not tried again by
## this process ([member _refused]).
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
		% [kind, version, kind, running, why, version] + " while this server runs")


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
	said.emit(line)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
