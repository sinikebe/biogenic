extends Node
## Photographs the earshot screen in each of the states a player can be in, and
## **drives it with real input events to get there** -- a touch, a mouse click
## and a keyboard chord, one of each, so the shot is evidence about the input
## path as well as about the layout.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##       --rendering-driver opengl3 res://tools/earshot_shot.tscn -- \
##       --page=answering --out=/tmp/a.png --size=1280x720
##
## LAN pages: `choose`, `calling`, `answering`, `together`, `refused`.
##
## `--their=<protocol>` is the protocol the other end speaks on `refused`,
## default one newer than this build. Pass one *older* to photograph the case
## that actually happens after a protocol bump: this phone took the update and
## the friend's did not.
##
## `together` and `refused` need somebody on the other end, so this opens a
## second session of its own on the same machine and lets the screen's own tap
## code find it -- which makes those two shots an end-to-end test of the join
## and not a mock of it.
##
## **Far pages** (docs/design/invites-ux.md §10) load `far.tscn`, and every
## invite gets onto the page the way a friend's does: the harness fills the
## clipboard with `DisplayServer.clipboard_set()` and presses paste -- by touch
## on some pages and with a Ctrl+V key event on others. Every far page starts
## with nothing kept; whatever this machine kept is put back afterwards.
##
##   `far`, `far-pasted`, `far-kept`, `far-long`, `far-v6`, `far-pasted-new`,
##   `far-pasted-same`, `far-bad` (clipboard `hello`), `far-bad-kept`,
##   `far-damaged`, `far-newer`, `far-forget`, `far-forgotten`,
##   `far-calling` (`--u=` picks where the pulse is: 0.15 is inside the
##   membrane, 0.6 outside), `far-together`, `far-refused-back`, and one
##   `far-trouble-<key>` for each of `Invite.SAYS`' calling keys.
##
## **Where a far page needs a server, it is the real one**: `server.tscn` in a
## process of its own, `--no-update`, with an invite minted into this project's
## user dir by the command line's own code, `--reach=127.0.0.1` -- because the
## page reads the session, and a session is only welcomed by a real host. Its
## label is `earshot-shot`; it is revoked, `--reach` is put back as it was, and a
## key and certificate this run made are removed, once the shot is taken. It
## listens on UDP 45771 and 45772 of this machine. The pages that use it:
## `far-together`, `far-refused-back`, and the troubles `not_this_pond` (an
## invite pinned to another certificate), `invite_refused` (a revoked one),
## `game_older` and `server_older` (this game made to speak one protocol
## older or newer before its HELLO), `already_two` (two LAN guests in first),
## `cut_off` (a second PROOF after the welcome, which the server cuts) and
## `hung_up` (the server stopped under the call).
##
## The rest need no server: `no_invite` (the kept invite gone by the time call
## is pressed), `no_such_place` (a name under `.invalid`, which RFC 2606 keeps
## from ever resolving), `no_answer` (198.51.100.1, RFC 5737's TEST-NET-2,
## which nothing answers -- the spec's 192.0.2.1 is the gateway in the
## container this was built in, and refuses at once), `not_running` (loopback,
## with nothing on the port) and `could_not_call`, **which only a device with no
## network gives**: run that page under `unshare -n`, which is flight mode.
## Every far page prints what the screen shows -- each Label's text and its
## width in its own font, every button's rect and which has the focus, and the
## link and its `trouble_key` -- so a page that went somewhere else says so.
##
## Excluded from export (`tools/*` on both presets), so none of it ships.

const SCREEN := "res://game/net/earshot.tscn"
const FAR_SCREEN := "res://game/net/far.tscn"
const MODE_SELECT := "res://game/mode_select.tscn"
const SERVER_SCENE := "res://game/server/server.tscn"
const NetSession := preload("res://game/net/net_session.gd")
const Lan := preload("res://game/net/lan.gd")
const Wire := preload("res://game/net/wire.gd")
const Invite := preload("res://game/net/invite.gd")
const InviteBook := preload("res://game/server/invite_book.gd")
const Earshot := preload("res://game/net/earshot.gd")

## **The harness's own key and certificate**, kept between runs: every invite
## it pastes that no server of ours answers is pinned to it, and so is the one
## that calls the real server and finds another certificate there.
const OWN_ROOT := "user://earshot_shot"
## The real server's invites, minted into this project's own book.
const LABEL := "earshot-shot"
const LABEL_GONE := "earshot-shot-gone"
## Placeholder addresses only (RFC 2606, RFC 5737, RFC 3849).
const NAMED := "example.net"
const NOWHERE := "pond.example.invalid"
const SILENT := "198.51.100.1"
const V6 := "2001:db8::5"
## Sixty characters, for the receipt's ellipsis.
const LONG_NAME := "biogenic-pond-at-home.dynamic-dns-provider.home.example.net"

var _screen: Control = null
var _other: Node = null
var _watchdog: Timer = null
## Extra guests a page opened, closed on the way out.
var _extras: Array = []
## The server process, and what it has said so far.
var _server_pid := -1
var _server_io: FileAccess = null
var _server_err: FileAccess = null
var _server_said := ""
var _server_partial := ""
var _stop_file := ""
## What this machine had before a far page touched it, put back afterwards:
## its kept invite and its server's `--reach` (null for none), and whether its
## server had a key at all.
var _kept_before: Variant = null
var _reach_before: Variant = null
var _key_before := true
var _minted := false
var _far_page := false
## The lines minted for the real server: its good invite and a revoked one.
var _served := ""
var _revoked := ""


## A hard stop, so a harness that gets stuck is a failed run rather than a job
## that hangs until something kills it.
func _init() -> void:
	_watchdog = Timer.new()
	_watchdog.wait_time = 40.0
	_watchdog.one_shot = true
	_watchdog.autostart = true
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.timeout.connect(_overran)
	add_child(_watchdog)


func _overran() -> void:
	push_error("[earshot-shot] gave up waiting")
	_kill_server()
	_put_back()
	get_tree().quit(1)


func _process(_delta: float) -> void:
	_drain_server()


func _ready() -> void:
	var page := "choose"
	var their := Wire.PROTOCOL + 1
	var out_path := "user://earshot.png"
	var wait := 1.0
	var size := Vector2i.ZERO
	var u := -1.0
	var address := ""
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--page="):
			page = text.trim_prefix("--page=")
		elif text.begins_with("--their="):
			their = int(text.trim_prefix("--their="))
		elif text.begins_with("--out="):
			out_path = text.trim_prefix("--out=")
		elif text.begins_with("--wait="):
			wait = float(text.trim_prefix("--wait="))
		elif text.begins_with("--u="):
			u = float(text.trim_prefix("--u="))
		elif text.begins_with("--address="):
			address = text.trim_prefix("--address=")
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				size = Vector2i(int(parts[0]), int(parts[1]))
	# Window only. Touching content_scale_size would override the project's
	# canvas_items/expand stretch and render 1:1 -- tools/shot.gd's own note.
	if size != Vector2i.ZERO:
		get_window().size = size

	_far_page = page.begins_with("far")
	if _far_page:
		# A server to boot, a key to make and an eight-second call to wait out.
		_watchdog.start(60.0)
		# **Every far page starts with nothing kept**, before the screen reads it.
		_kept_before = _bytes_or_null(Invite.KEPT)
		Invite.forget()

	var packed: PackedScene = load(FAR_SCREEN if _far_page else SCREEN)
	_screen = packed.instantiate()
	get_tree().root.add_child.call_deferred(_screen)
	await _screen.ready
	get_tree().current_scene = _screen
	await _settle(0.4)

	match page:
		"calling":
			await _calling()
		"answering":
			await _answering()
		"together":
			await _together(Wire.PROTOCOL)
		"refused":
			await _together(their)
		_:
			if _far_page and not await _far(page, address):
				await _finish(1)
				return

	await _settle(wait)
	if _far_page and u >= 0.0:
		await _pulse_at(u)
	else:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_path) != OK:
		push_error("[earshot-shot] could not write %s" % out_path)
		await _finish(1)
		return
	print("[earshot-shot] %s  %dx%d  page=%s" % [
		out_path, image.get_width(), image.get_height(), page])
	if _far_page:
		_report(page)
	await _finish(0)


## Press `call` with the mouse. A real click, through the theme's own button.
func _calling() -> void:
	await _click(_screen.get_node(^"Buttons/First"))
	await _settle(0.5)


## Press `answer` with a touch, then tap two bearings -- one with a finger, one
## with the keyboard -- so the half-finished code in the shot got there the way
## a player's would.
func _answering() -> void:
	await _touch(_screen.get_node(^"Buttons/Second"))
	await _settle(0.3)
	await _tap_bearing(7)
	await _settle(0.2)
	await _key_to(2)
	await _settle(0.3)


## Somebody on the other end: a second session, hosting, on this same machine.
## The screen then finds it with nothing but its own tap code and its own /24
## derivation, which is the whole join path end to end.
func _together(their_protocol: int) -> void:
	var host: Node = NetSession.new()
	host.name = "Other"
	host.protocol_override = their_protocol
	get_tree().root.add_child.call_deferred(host)
	await host.ready
	_other = host
	if not host.host():
		push_error("[earshot-shot] nothing to host on")
		return
	var code := Lan.code_for(Lan.octet_of(host.address))
	await _touch(_screen.get_node(^"Buttons/Second"))
	await _settle(0.3)
	for digit: int in code:
		await _tap_bearing(digit)
		await _settle(0.12)
	await _settle(2.0)


# ---------------------------------------------------------------------------
# The far pages.
# ---------------------------------------------------------------------------

## Drive [param page] from a far visit with nothing kept. False, with an error
## said, when it could not get there.
func _far(page: String, address: String) -> bool:
	match page:
		"far":
			pass
		"far-pasted":
			# A chat app's message, wrapped where the app wrapped it.
			await _paste_by_touch(_wrapped(_message(_line_for(NAMED))))
		"far-kept", "far-long", "far-v6":
			var at: String = {"far-kept": NAMED, "far-long": LONG_NAME, "far-v6": V6}[page]
			if not address.is_empty():
				at = address
			await _paste_by_key(_message(_line_for(at)))
			# A returning friend: out to the chooser, and back in by its button.
			if not await _come_back():
				return false
		"far-pasted-new":
			await _paste_by_touch(_line_for(NAMED))
			await _paste_by_touch(_message(_line_for(NAMED)))
		"far-pasted-same":
			var line := _line_for(NAMED)
			await _paste_by_touch(_message(line))
			await _paste_by_key("again: " + line)
		"far-bad":
			await _paste_by_touch("hello")
		"far-bad-kept":
			await _paste_by_touch(_line_for(NAMED))
			await _paste_by_key("hello")
		"far-damaged":
			var line := _line_for(NAMED)
			# Cut short on the way, the way a message limit cuts it.
			await _paste_by_key(_message(line.substr(0, line.length() - 40)))
		"far-newer":
			await _paste_by_touch(_message(_newer_line()))
		"far-forget":
			await _paste_by_key(_line_for(NAMED))
			await _touch(_button("forget"))
		"far-forgotten":
			await _paste_by_key(_line_for(NAMED))
			await _touch(_button("forget"))
			await _settle(0.2)
			await _touch(_button("forget"))
		"far-calling":
			await _paste_by_key(_line_for(SILENT))
			await _click(_button("call"))
			if not await _until_page(Earshot.Page.FAR_CALLING, 2.0):
				return false
		"far-together":
			if not await _server_up():
				return false
			await _paste_by_touch(_message(_served))
			await _click(_button("call"))
			if not await _until_page(Earshot.Page.TOGETHER, 10.0):
				return false
		"far-refused-back":
			if not await _server_up():
				return false
			await _paste_by_key(_message(_revoked))
			await _click(_button("call"))
			if not await _until_page(Earshot.Page.TROUBLE, 10.0):
				return false
			# Leave, and come back later the way a player does: the chooser's
			# far button, with the same invite kept and the same game running.
			await _touch(_button("leave"))
			if not await _until_scene(MODE_SELECT) or not await _into_far():
				return false
		_:
			if not page.begins_with("far-trouble-"):
				push_error("[earshot-shot] no page called %s" % page)
				return false
			return await _trouble(page.trim_prefix("far-trouble-"))
	await _settle(0.3)
	await _park_mouse()
	return true


## One TROUBLE page, per `trouble_key` (§6.3), by the failure itself.
func _trouble(key: String) -> bool:
	match key:
		"no_invite":
			await _paste_by_touch(_line_for(NAMED))
			# The kept invite, gone by the time call is pressed: the only way
			# a page that offers call has nothing to call with.
			Invite.forget()
			await _click(_button("call"))
		"could_not_call":
			# Needs a device with no network: `unshare -n`.
			await _paste_by_touch(_line_for(NAMED))
			await _click(_button("call"))
		"no_such_place":
			await _paste_by_key(_line_for(NOWHERE))
			await _click(_button("call"))
		"no_answer":
			await _paste_by_key(_line_for(SILENT))
			await _click(_button("call"))
		"not_running":
			await _paste_by_touch(_line_for("127.0.0.1"))
			await _click(_button("call"))
		"not_this_pond", "invite_refused", "game_older", "server_older", \
				"already_two", "cut_off", "hung_up":
			if not await _server_up():
				return false
			await _trouble_at_server(key)
		_:
			push_error("[earshot-shot] no trouble called %s" % key)
			return false
	if not await _until_page(Earshot.Page.TROUBLE, NetSession.INVITE_REACH_TIMEOUT
			+ NetSession.RESOLVE_TIMEOUT + 2.0):
		return false
	await _settle(0.3)
	await _park_mouse()
	return true


## The real server's half of the troubles.
func _trouble_at_server(key: String) -> void:
	match key:
		"not_this_pond":
			await _paste_by_touch(_message(_line_for("127.0.0.1")))
			await _click(_button("call"))
		"invite_refused":
			await _paste_by_key(_message(_revoked))
			await _click(_button("call"))
		"game_older", "server_older":
			await _paste_by_touch(_served)
			await _click(_button("call"))
			# Before its HELLO, which waits for the transport: this game made to
			# speak one protocol older, or newer, than the server it calls.
			var session: Node = _screen.get("_session")
			if session != null:
				session.protocol_override = Wire.PROTOCOL + (-1 if key == "game_older" else 1)
		"already_two":
			for i in 2:
				var guest: Node = NetSession.new()
				guest.name = "Guest%d" % i
				get_tree().root.add_child(guest)
				_extras.append(guest)
				guest.join("127.0.0.1")
			await _until(_extras_together, 6.0)
			await _paste_by_key(_served)
			await _click(_button("call"))
		"cut_off", "hung_up":
			await _paste_by_touch(_message(_served))
			await _click(_button("call"))
			if not await _until_page(Earshot.Page.TOGETHER, 10.0):
				return
			await _settle(0.5)
			if key == "hung_up":
				_stop_server()
				return
			# A second PROOF after the welcome, which the server's gate cuts
			# (net-hardening.md C, S6): sent from this game's own session.
			var session: Node = _screen.get("_session")
			var kept := Invite.kept()
			var ids: Array = session.peer_ids()
			var crypto := Crypto.new()
			session._to(int(ids[0]) if not ids.is_empty() else 0, Wire.proof(kept["key_id"],
				crypto.generate_random_bytes(Wire.NONCE_SIZE),
				crypto.generate_random_bytes(Wire.MAC_SIZE)))


## Out to the chooser with Esc, and back in by its far button, with a touch.
func _come_back() -> bool:
	await _settle(0.2)
	await _key(KEY_ESCAPE)
	if not await _until_scene(MODE_SELECT):
		return false
	return await _into_far()


## From the chooser, into the far screen by its button.
func _into_far() -> bool:
	await _settle(0.3)
	var chooser := get_tree().current_scene
	await _touch(chooser.get_node(^"Center/Column/Company/FarBlock/Far"))
	if not await _until_scene(FAR_SCREEN):
		return false
	_screen = get_tree().current_scene as Control
	await _settle(0.4)
	await _park_mouse()
	return true


func _paste_by_touch(text: String) -> void:
	DisplayServer.clipboard_set(text)
	var paste := _paste_button()
	if paste == null:
		push_error("[earshot-shot] no paste button on this page")
		return
	await _touch(paste)
	await _settle(0.2)


func _paste_by_key(text: String) -> void:
	DisplayServer.clipboard_set(text)
	await _chord(KEY_V, true)
	print("[earshot-shot] ctrl+v")
	await _settle(0.2)


## The page's paste button: paste invite, or paste new.
func _paste_button() -> Button:
	for text: String in ["paste invite", "paste new"]:
		var found := _find(text)
		if found != null:
			return found
	return null


## The visible button reading [param text], or null, said.
func _button(text: String) -> Button:
	var found := _find(text)
	if found == null:
		push_error("[earshot-shot] no button reads '%s'" % text)
	return found


func _find(text: String) -> Button:
	for name: String in ["First", "Second", "Third"]:
		var button: Button = _screen.get_node("Buttons/" + name)
		if button.visible and button.text == text:
			return button
	return null


## A friend's whole message, as it arrives: the invite inside a sentence.
static func _message(line: String) -> String:
	return "here is my invite: %s -- see you in the water!" % line


## Broken every 61 characters, as a messaging app breaks a long word.
static func _wrapped(text: String) -> String:
	var out := PackedStringArray()
	for at in range(0, text.length(), 61):
		out.append(text.substr(at, 61))
	return "\n".join(out)


## An invite to [param address], pinned to the harness's own certificate.
func _line_for(address: String) -> String:
	var identity := _own_identity()
	if identity.is_empty():
		return ""
	var crypto := Crypto.new()
	return Invite.format(address, Invite.PORT, crypto.generate_random_bytes(Invite.KEY_ID_SIZE),
		crypto.generate_random_bytes(Invite.SECRET_SIZE), identity[2])


## A whole, checked invite of a format newer than this build reads.
func _newer_line() -> String:
	var body := _line_for(NAMED).trim_prefix(Invite.PREFIX)
	var inner := "%d.%s" % [Invite.VERSION + 1, body.get_slice(".", 1)]
	return Invite.PREFIX + inner + "." + inner.sha256_text().substr(0, Invite.CHECK_CHARS)


func _own_identity() -> Array:
	var identity := InviteBook.load_identity(OWN_ROOT)
	if identity.is_empty():
		InviteBook.make_identity(OWN_ROOT)
		identity = InviteBook.load_identity(OWN_ROOT)
	return identity


## Wait until the screen is on [param page], or [param seconds] of wall time.
func _until_page(page: int, seconds: float) -> bool:
	var got := await _until(_on_page.bind(page), seconds)
	if not got:
		push_error("[earshot-shot] the screen never reached %s: it is on %s"
			% [Earshot.Page.keys()[page], Earshot.Page.keys()[int(_screen.get("_page"))]])
	return got


func _until_scene(path: String) -> bool:
	var got := await _until(_on_scene.bind(path), 3.0)
	if not got:
		push_error("[earshot-shot] %s never came up" % path)
	return got


func _on_page(page: int) -> bool:
	return is_instance_valid(_screen) and int(_screen.get("_page")) == page


func _on_scene(path: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == path


func _extras_together() -> bool:
	for guest: Node in _extras:
		if int(guest.link) != NetSession.Link.TOGETHER:
			return false
	return true


func _server_ready() -> bool:
	return _server_said.contains("[server] READY")


func _server_gone() -> bool:
	return not OS.is_process_running(_server_pid)


## Wall time, not frames: every clock in a session is wall time.
func _until(done: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		await get_tree().process_frame
	return bool(done.call())


## **The first frame at or after [param u] of a pulse's flight**, waiting out
## the rest of one already past it. Whatever the frame rate, the frame kept is
## the one drawn with the clock it reports.
func _pulse_at(u: float) -> void:
	var want := u * Earshot.PULSE_TRAVEL
	var armed := false
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw
		var at := fmod(float(_screen.get("_clock")), Earshot.PULSE_EVERY)
		if at < want:
			armed = true
		elif armed and at < want + 0.25:
			break
	var at := fmod(float(_screen.get("_clock")), Earshot.PULSE_EVERY)
	print("[earshot-shot] the pulse at %.3f s of its flight: u %.3f, radius %.1f" % [at,
		at / Earshot.PULSE_TRAVEL, Earshot.PULSE_FROM + Earshot.PULSE_SPREAD
			* (1.0 - pow(1.0 - minf(at / Earshot.PULSE_TRAVEL, 1.0), 2.0))])


## **What the page shows, measured**: every Label's text and its width in its
## own font and size, against the canvas; every button's rect, and which one
## holds the focus; the ring's focus mode; and the link.
func _report(page: String) -> void:
	var canvas := get_viewport().get_visible_rect().size
	print("[earshot-shot] %s: page %s, far %s, canvas %dx%d" % [page,
		Earshot.Page.keys()[int(_screen.get("_page"))], str(_screen.get("far")),
		roundi(canvas.x), roundi(canvas.y)])
	for path: String in ["Heading", "Line", "Receipt", "Hint"]:
		var label: Label = _screen.get_node(path)
		var font := label.get_theme_font(&"font")
		var px := label.get_theme_font_size(&"font_size")
		var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var box := label.get_global_rect()
		print("[earshot-shot]   %-8s %2d px  '%s'  %.0f px wide, x %.0f-%.0f of %.0f, y %.0f-%.0f, %d line"
			% [path, px, label.text, width, (canvas.x - width) * 0.5, (canvas.x + width) * 0.5,
				canvas.x, box.position.y, box.end.y, label.get_line_count()])
	var focus := get_viewport().gui_get_focus_owner()
	for name: String in ["First", "Second", "Third"]:
		var button: Button = _screen.get_node("Buttons/" + name)
		if not button.visible:
			continue
		var box := button.get_global_rect()
		print("[earshot-shot]   %-6s '%s'  x %.0f-%.0f, y %.0f-%.0f, %.0fx%.0f%s" % [name,
			button.text, box.position.x, box.end.x, box.position.y, box.end.y, box.size.x,
			box.size.y, "  FOCUS" if button == focus else ""])
	var ring: Control = _screen.get_node(^"Ring")
	var ring_box := ring.get_global_rect()
	print("[earshot-shot]   focus on %s; ring x %.0f-%.0f, y %.0f-%.0f, focus mode %d" % [
		"nothing" if focus == null else str(focus.name), ring_box.position.x, ring_box.end.x,
		ring_box.position.y, ring_box.end.y, ring.focus_mode])
	var session: Node = _screen.get("_session")
	if session != null and is_instance_valid(session):
		print("[earshot-shot]   link %s, trouble_key '%s', by invite %s" % [
			NetSession.Link.keys()[int(session.link)], str(session.trouble_key),
			str(session.by_invite())])
	else:
		print("[earshot-shot]   no session")


# ---------------------------------------------------------------------------
# The real server, in a process of its own.
# ---------------------------------------------------------------------------

## **Mint, then boot the server scene** and wait for its READY, which it says
## once its internet listener is open.
func _server_up() -> bool:
	var where := InviteBook.paths()
	_key_before = FileAccess.file_exists(str(where["key"]))
	_reach_before = _bytes_or_null(str(where["reach"]))
	_minted = true
	var minted: Array = InviteBook.run(PackedStringArray(["--reach=127.0.0.1",
		"--invite=" + LABEL, "--invite=" + LABEL_GONE]))
	_served = _text_of(InviteBook.line_path(LABEL))
	_revoked = _text_of(InviteBook.line_path(LABEL_GONE))
	var revoked: Array = InviteBook.run(PackedStringArray(["--revoke=" + LABEL_GONE]))
	for line: String in Array(minted[1]) + Array(revoked[1]):
		print("[earshot-shot] mint: " + line)
	if int(minted[0]) != 0 or int(revoked[0]) != 0 or _served.is_empty() or _revoked.is_empty():
		push_error("[earshot-shot] could not mint the server's invites")
		return false
	_stop_file = ProjectSettings.globalize_path("user://earshot_shot.stop")
	DirAccess.remove_absolute(_stop_file)
	var got := OS.execute_with_pipe(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), SERVER_SCENE, "--",
		"--no-update", "--stop-file=" + _stop_file]), false)
	if got.is_empty():
		push_error("[earshot-shot] could not start the server")
		return false
	_server_pid = int(got["pid"])
	_server_io = got["stdio"]
	_server_err = got["stderr"]
	var ready := await _until(_server_ready, 20.0)
	if not ready:
		push_error("[earshot-shot] the server never said READY")
	return ready


## Ask the server to stop, the way its service does: by the stop file.
func _stop_server() -> void:
	if _server_pid < 0 or _stop_file.is_empty():
		return
	var file := FileAccess.open(_stop_file, FileAccess.WRITE)
	if file != null:
		file.close()


func _server_down() -> void:
	if _server_pid < 0:
		return
	_stop_server()
	await _until(_server_gone, 5.0)
	_drain_server()
	_kill_server()


func _kill_server() -> void:
	if _server_pid >= 0 and OS.is_process_running(_server_pid):
		OS.kill(_server_pid)
	_server_pid = -1
	if not _stop_file.is_empty():
		DirAccess.remove_absolute(_stop_file)


## The server's output, a line at a time, into this one's.
func _drain_server() -> void:
	for pipe: FileAccess in [_server_io, _server_err]:
		if pipe == null:
			continue
		var chunk := pipe.get_buffer(65536)
		if chunk.is_empty():
			continue
		var text := _server_partial + chunk.get_string_from_utf8()
		var lines := text.split("\n")
		_server_partial = lines[lines.size() - 1]
		for i in lines.size() - 1:
			_server_said += lines[i] + "\n"
			print("[earshot-shot] server: " + lines[i])


## **This machine as it was**: the kept invite, and the server's book --
## the label revoked, `--reach` as it was, and a key this run made, gone.
func _put_back() -> void:
	if _far_page:
		if _kept_before == null:
			Invite.forget()
		else:
			Invite.write_private(Invite.KEPT, _kept_before)
	if not _minted:
		return
	_minted = false
	InviteBook.run(PackedStringArray(["--revoke=" + LABEL]))
	var where := InviteBook.paths()
	if _reach_before == null:
		DirAccess.remove_absolute(str(where["reach"]))
	else:
		Invite.write_private(str(where["reach"]), _reach_before)
	if not _key_before and InviteBook.entries().is_empty():
		for what: String in ["key", "cert", "book", "joined"]:
			DirAccess.remove_absolute(str(where[what]))
		DirAccess.remove_absolute(str(where["lines"]))
		DirAccess.remove_absolute(str(where["pond"]))


func _finish(code: int) -> void:
	for guest: Node in _extras:
		if is_instance_valid(guest):
			guest.close()
	await _server_down()
	_put_back()
	get_tree().quit(code)


static func _bytes_or_null(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_bytes(path)


static func _text_of(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()


# ---------------------------------------------------------------------------
# Input, sent the way a device sends it.
# ---------------------------------------------------------------------------

func _tap_bearing(digit: int) -> void:
	var ring: Control = _screen.get_node(^"Ring")
	var bearing := Lan.bearing_of(digit)
	var radius := float(_screen.RING_RADIUS)
	var at: Vector2 = ring.global_position + ring.size * 0.5 \
		+ Vector2(sin(bearing), -cos(bearing)) * radius
	await _touch_at(at)


func _click(control: Control) -> void:
	if control == null:
		return
	var at := control.global_position + control.size * 0.5
	var where := _to_window(at)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = where
		event.global_position = where
		Input.parse_input_event(event)
		await get_tree().process_frame
	print("[earshot-shot] click at canvas %.0f,%.0f" % [at.x, at.y])


func _touch(control: Control) -> void:
	if control == null:
		return
	await _touch_at(control.global_position + control.size * 0.5)


func _touch_at(canvas: Vector2) -> void:
	var where := _to_window(canvas)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = where
		Input.parse_input_event(event)
		await get_tree().process_frame
	print("[earshot-shot] touch at canvas %.0f,%.0f" % [canvas.x, canvas.y])


## **A lifted finger leaves no hover on a phone**, and the mouse a touch is
## emulated as would: it is moved off the buttons before a far page's shot.
func _park_mouse() -> void:
	var event := InputEventMouseMotion.new()
	event.position = _to_window(Vector2(4.0, 4.0))
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame


## The keyboard path: walk the cursor round the ring with `ui_right` and commit
## with `ui_accept`. Built-in actions only -- a new InputMap action would be a
## project.godot change and therefore a binary bump.
func _key_to(digit: int) -> void:
	var ring: Control = _screen.get_node(^"Ring")
	ring.grab_focus()
	await get_tree().process_frame
	for i in Lan.BEARINGS:
		if int(_screen._cursor) == digit:
			break
		await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	print("[earshot-shot] keyed a tap at bearing %d" % digit)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


## A key held with Ctrl: `ui_paste` is Ctrl+V.
func _chord(keycode: Key, ctrl: bool) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _to_window(canvas: Vector2) -> Vector2:
	return canvas * get_viewport().get_screen_transform().get_scale() \
		+ get_viewport().get_screen_transform().get_origin()


func _settle(seconds: float) -> void:
	var spent := 0.0
	while spent < seconds:
		await get_tree().process_frame
		spent += 1.0 / 60.0
