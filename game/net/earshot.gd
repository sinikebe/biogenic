extends Control
## Within earshot: the screen where two cells find each other, and the only
## place in this game that has ever asked a player for an address.
##
## **It asks for it in bearings.** There is no `LineEdit` here and there will
## not be one: the reasoning is in lan.gd, and the short version is that the
## launcher's theme has no style for a text field and Android would raise a soft
## keyboard over a landscape-locked canvas to fill it. So the host shows four
## marks on a ring and the guest taps them back. Four taps, twelve bearings, and
## the fourth is a check digit -- a mis-tap is caught here, instantly, instead of
## becoming a four-second wait for an address nobody is at.
##
## The ring is drawn in `ampulla` violet on purpose. It is the same colour the
## ping wears everywhere else in the game, because it is the same thing: one
## cell saying *here* in the only vocabulary the fiction has.
##
## **And from far away, by invite** (docs/design/invites-ux.md). The same scene,
## opened as `far.tscn`, which holds it with [member far] set and nothing else:
## an instance, not an inherited scene, because the exporter zeroes every layout
## an inherited scene takes from its base (tools/export_layout_probe.gd). The friend
## pastes the one line the owner's server minted, this device keeps it, and
## every visit after that is call and then a view. A far visit never reaches
## CHOOSE, CALLING or ANSWERING, and the household never sees a far page. Its
## ring is not a dial -- nothing on it is tapped -- but a cell: the membrane
## and a nucleus, and a call is a violet ping leaving it.
##
## Same visual language as the launcher and the view chooser, deliberately.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## **Loading this is what registers the game's languages** (game/i18n/README.md),
## and it has to happen before this scene's nodes exist, which is why it is a
## preload and not a call. Not unused: do not remove it.
const I18n := preload("res://game/i18n/i18n.gd")
const RunState := preload("res://game/run_state.gd")
const NetSession := preload("res://game/net/net_session.gd")
const Lan := preload("res://game/net/lan.gd")
const Invite := preload("res://game/net/invite.gd")

const NORMAL_SCENE := "res://game/normal/normal_mode.tscn"
const MODE_SELECT_SCENE := "res://game/mode_select.tscn"

## Which of the things this screen is at any moment. The first five are the
## LAN's; the last three only a far visit reaches, and it shares TOGETHER and
## TROUBLE with the LAN.
enum Page { CHOOSE, CALLING, ANSWERING, TOGETHER, TROUBLE, FAR, FAR_CALLING, FORGET }

## Well over the 48px minimum, and paired far enough apart that a low tap on one
## lands in dead space rather than on the other -- the same rule the view
## chooser and the pause column are built to.
const BUTTON_SIZE := Vector2(264.0, 56.0)

## The ring the code is written on. 160px puts 84px of arc under each of the
## twelve bearings and 156px of radial band behind it, so every target is over
## three times the 48px minimum in its tight direction.
const RING_RADIUS := 160.0
const HIT_INNER := 62.0
const HIT_OUTER := 218.0
## Half the arc a code mark is drawn over: 11 degrees inside a 30 degree sector,
## so two adjacent marks never touch and the gaps read as gaps.
const MARK_HALF_DEG := 11.0

# --- The palette, and it is the membrane's ----------------------------------
## `ampulla`'s violet, copied from signal_bus.gd's PING_COLOR rather than
## imported: this is a menu, and a menu may not preload the perception stack.
const CODE_COLOR := Color(0.655, 0.44, 1.0)
## The launcher's dim rim green, the same one the view chooser's heading wears.
const RING_COLOR := Color(0.404, 0.639, 0.588)

## How long each mark of the code is lit as the walk goes round, and how long
## the walk rests at the end before starting again. The rest is what tells a
## reader where the code begins.
const WALK_STEP := 0.62
const WALK_REST := 1.1

# --- The far pages' cell (invites-ux.md §4) ----------------------------------
## The membrane's alpha, halved on TROUBLE, where the sentence is the thing to
## read; and the nucleus', which is what makes an empty hairline read as a cell
## rather than as an empty frame -- mocked both ways.
const MEMBRANE_ALPHA := 0.16
const NUCLEUS_ALPHA := 0.24
const NUCLEUS_RADIUS := 7.0
## A nucleus that is calling, or has been answered, is the ping's own violet.
const NUCLEUS_CALLING_ALPHA := 0.85
## **The call leaving the cell**: one pulse at a time, one every 1.6 s -- 1.2 s
## out and 0.4 s at rest -- from r 56 to r 212 on an ease-out, fading as it
## goes. At its widest it spans canvas y 88-512, clear of the Heading, which
## ends at 78, and of the Line, which starts at 540. **It fades late, not
## early**: violet laid thin over this teal wash reads blue, and keeps a hue of
## 245 degrees or more only from about alpha 0.5 up -- so the ring holds its
## colour through most of its flight (measured 261 degrees at u 0.16, 258 at
## 0.6, 248 at 0.83) and thins out only in its last tenth.
const PULSE_EVERY := 1.6
const PULSE_TRAVEL := 1.2
const PULSE_FROM := 56.0
const PULSE_SPREAD := 156.0
const PULSE_ALPHA := 0.8

## **The receipt keeps its port in view.** An address over this many characters
## -- a long dynamic-DNS name -- shows its first and last [constant RECEIPT_KEEP]
## around an ellipsis, so `address · port` stays one short line (§5.2).
const RECEIPT_MOST := 48
const RECEIPT_KEEP := 22
## What the Receipt says while nothing is kept.
##
## TRANSLATORS: The small grey line under the sentence on the "by invite" page
## while no invite has been pasted yet. An invite is a one-line message that a
## friend sends you in any chat app: you copy it, paste it into the game, and
## the game keeps it on this device for every later visit. About 45 characters.
const NOTHING_KEPT := "you paste it once · this device keeps it"
## TOGETHER's Line on a far visit, while the friend's water is not quiet.
##
## TRANSLATORS: Shown once the call is answered. A friend's "water" is the pond
## (the shared game world) their server keeps; "hear" is the game's word for
## being connected. About 35 characters.
const FAR_HEARD := "you can hear your friend's water"

## **Which screen this is for the whole visit**: the LAN's, from
## `earshot.tscn`, or the far one, from `far.tscn`, which holds this scene with
## this set and nothing else. Read, never written, so there is no static to
## forget to clear.
@export var far := false

@onready var _heading: Label = $Heading
@onready var _ring: Control = $Ring
@onready var _line: Label = $Line
@onready var _receipt: Label = $Receipt
@onready var _first: Button = $Buttons/First
@onready var _second: Button = $Buttons/Second
@onready var _third: Button = $Buttons/Third
@onready var _hint: Label = $Hint
## **Settings, from the gear in the top-right corner** (docs/design/settings.md
## §1): the last child, so Esc reaches it before this screen does.
@onready var _corner: Control = $Corner

var _page := Page.CHOOSE
var _session: Node = null
## The four digits the host is showing, or empty.
var _code := PackedInt32Array()
## The digits the guest has tapped so far, up to four.
var _taps := PackedInt32Array()
## Where the keyboard's cursor is sitting on the ring.
var _cursor := 0
var _keyed := false
var _clock := 0.0
var _leaving := false
## **The invite this device keeps**, as [method Invite.kept] read it when a far
## page last looked -- on FAR, and again at every call. Empty for none, and for
## one that no longer reads.
var _kept: Dictionary = {}
## **What the last press on FAR did**, which FAR says until a press changes the
## page (§3): `{says, focus, receipt}` -- which sentence ([method _after_words]
## has them), the button counted from 0 that takes the focus, and the address and
## port it is about. **Which sentence and not its words**, so a change of language
## says it again (docs/design/settings.md §3.3). Set by the press, taken by the
## page change into [member _said_after], and empty when the press said nothing.
var _after: Dictionary = {}
## What the page on screen says the last press did: the [member _after] the page
## change took, said by [method _say_page] -- again, in another language, if the
## language changes under it.
var _said_after: Dictionary = {}
## **The four taps did not make a code**, which ANSWERING says until the next tap.
var _misdialled := false
## Whether TROUBLE's first button pastes (`not_this_pond`, `invite_refused` and
## `no_invite`) rather than calling again, on a far visit.
var _trouble_pastes := false


func _ready() -> void:
	# Android Back must walk back to the view chooser, not kill the app.
	get_tree().quit_on_go_back = false

	_ring.mouse_filter = Control.MOUSE_FILTER_STOP
	# **Focusable on ANSWERING and nowhere else** ([method _go_to]). It is the
	# only page with anything on the ring to press, and the ring draws no focus
	# of its own: measured on `main`, one Up press on any other page moved the
	# keyboard onto it and left nothing on screen saying where it had gone.
	_ring.focus_mode = Control.FOCUS_NONE
	_ring.draw.connect(_draw_ring)
	_ring.gui_input.connect(_on_ring_input)

	for button: Button in [_first, _second, _third]:
		button.custom_minimum_size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_ALL
	_first.pressed.connect(_on_first)
	_second.pressed.connect(_on_second)
	_third.pressed.connect(_on_third)

	if far:
		_kept = Invite.kept()
	# A session can already be open: leaving a run walks back through the view
	# chooser, which closes it, but arriving here twice in one sitting must not
	# find a stale one either.
	_session = NetSession.current
	if _session != null and is_instance_valid(_session):
		_session.link_changed.connect(_on_link_changed)
		_follow_link()
	else:
		_go_to(_home())


func _process(delta: float) -> void:
	_clock += delta
	# The walking mark, the pulse, the quiet-peer clock and nothing else. One
	# redraw a frame on a menu with an animated background already behind it.
	if _page == Page.CALLING or _page == Page.TOGETHER or _page == Page.FAR_CALLING:
		_ring.queue_redraw()
	if _page == Page.CALLING or _page == Page.TOGETHER:
		_say_line()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# **The corner first** (settings.md §1.3): Android Back reaches this
			# screen before the sheet over it, so a sheet that is open is what Back
			# closes, and the page stays.
			if _corner.close_top():
				return
			if _page == Page.FORGET:
				_go_to(Page.FAR)
				return
			_back()
		NOTIFICATION_TRANSLATION_CHANGED:
			# Deferred: the tree is still telling every node, and nothing may be
			# changed under it. The first one comes as the node enters the tree,
			# before `_ready` has said anything, and is let go.
			if is_node_ready():
				_say_page.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# **Ctrl+V, and Shift+Insert**: `ui_paste` is the engine's own action, so
	# there is no new one and no project.godot change. It presses whichever
	# paste button the page shows, and on a page that shows none it does
	# nothing -- which is every LAN page.
	if event.is_action_pressed(&"ui_paste"):
		if _pastes():
			get_viewport().set_input_as_handled()
			_paste()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	# The corner is the last child, so an open sheet has had Esc already; asked
	# again in case the same Back reached it by the other door.
	if _corner.close_top():
		return
	if _page == Page.ANSWERING and not _taps.is_empty():
		_undo_tap()
		return
	if _page == Page.FORGET:
		# Back means keep here: the safe answer to the question, much as
		# ANSWERING's means back one.
		_go_to(Page.FAR)
		return
	_back()


# ---------------------------------------------------------------------------
# The pages.
# ---------------------------------------------------------------------------

## **A page change**: the page, its clock, where the keyboard goes, and its words.
## What the last press did is taken here, and only here ([member _said_after]);
## the words are [method _say_page]'s, which a change of language calls again on
## its own.
func _go_to(page: int) -> void:
	_page = page
	_clock = 0.0
	# Before the words and the focus, which link Up to the chip where it shows.
	_corner.show_drop = _shows_drop()
	# Only ANSWERING has anything on the ring to press.
	_ring.focus_mode = Control.FOCUS_ALL if page == Page.ANSWERING else Control.FOCUS_NONE
	_said_after = _after
	_after = {}
	if page == Page.FAR:
		_kept = Invite.kept()
	if page == Page.TROUBLE:
		# **The first button is the way out of this trouble** (§6.3): a new
		# invite for a server that no longer takes this one or is not the one it
		# names, the first invite when there is none, and the same call again for
		# everything a wait or an update fixes.
		var key := _trouble_key()
		_trouble_pastes = far and (key == &"not_this_pond" or key == &"invite_refused"
			or key == &"no_invite")
	_say_page()
	_focus_page()
	_ring.queue_redraw()


## **The page's words, and nothing else** (docs/design/settings.md §3.3): no
## focus, no clock, and what the last press did is read, never taken. So a change
## of language says a page again and leaves everything on it where it was.
func _say_page() -> void:
	# Shown by the far pages that have three things to offer, and by no other.
	_button(_third, "")
	match _page:
		Page.CHOOSE:
			# TRANSLATORS: The name of this feature and the heading of its first
			# screen: two phones on the same wi-fi finding each other, near enough
			# to hear one another. Also a button on the screen before this one, and
			# the line under the heading once the two are connected.
			_heading.text = tr("within earshot")
			# TRANSLATORS: A "cell" is the player's creature. One player calls (shows
			# a code) and the other answers (taps it in). Shown in 17 px type on one
			# line, centred on the screen.
			# ROOM: 1180 px at 17 px
			_line.text = tr("two cells on one wi-fi, one of them calling")
			_receipt.text = _here_says()
			# TRANSLATORS: A button: start a call, so the other phone can answer it.
			_button(_first, tr("call"))
			# TRANSLATORS: A button: answer the call the other phone is making.
			_button(_second, tr("answer"))
		Page.CALLING:
			# TRANSLATORS: A heading above a ring of marks: the other player is to be
			# shown these marks, and taps them in on their phone. "this" is the code.
			_heading.text = tr("show this")
			# TRANSLATORS: Under the ring while the call is ringing. "answer" as in
			# answering a phone call.
			# ROOM: 1180 px at 17 px
			_line.text = tr("waiting for an answer")
			_receipt.text = _here_says()
			# TRANSLATORS: A button: hang up; stop calling.
			_button(_first, tr("stop"))
			_button(_second, "")
		Page.ANSWERING:
			# TRANSLATORS: A heading above a ring of twelve places: the player taps
			# the four marks the other player is showing, in order, to dial them.
			_heading.text = tr("tap their code")
			_receipt.text = ""
			# TRANSLATORS: A button: undo the last tap of the code, one step back.
			_button(_first, tr("back one"))
			_button(_second, "")
			_say_taps()
		Page.TOGETHER:
			# TRANSLATORS: A heading: the other player has picked up; the two phones
			# are connected.
			_heading.text = tr("answered")
			_line.text = tr(FAR_HEARD) if far else tr("within earshot")
			_receipt.text = _receipt_of(_kept) if far else ""
			# TRANSLATORS: Two buttons that choose how the shared game is drawn: the
			# first shows the water the cell swims in and the membrane over it, the
			# second shows only what the cell itself can feel. Also the two options
			# on the screen where a game is started.
			_button(_first, tr("full vision"))
			# TRANSLATORS: The second of the two buttons above: the view that shows
			# only what the cell itself can feel.
			_button(_second, tr("point of view"))
		Page.TROUBLE:
			_say_trouble()
		Page.FAR:
			_say_far()
		Page.FAR_CALLING:
			_heading.text = tr(Invite.DOOR_NAME)
			# TRANSLATORS: Under the ring while a call to a friend's server is ringing.
			# A friend's "water" is the pond (shared game world) their server keeps.
			# ROOM: 1180 px at 17 px
			_line.text = tr("calling your friend's water")
			_receipt.text = _receipt_of(_kept)
			_button(_first, tr("stop"))
			_button(_second, "")
		Page.FORGET:
			# TRANSLATORS: A question: delete the invite this device keeps?
			_heading.text = tr("forget this invite?")
			# TRANSLATORS: The consequence, under the question. It is a full
			# sentence with a full stop, unlike the lines around it.
			# ROOM: 1180 px at 17 px
			_line.text = tr("you would need your friend's message to paste it back.")
			_receipt.text = _receipt_of(_kept)
			# TRANSLATORS: Two buttons answering the question above: keep the
			# invite, or forget it. "keep" is the safe answer.
			_button(_first, tr("keep"))
			_button(_second, tr("forget"))
	_say_hint()


## **TROUBLE's words**: the session's sentence for how the call ended. On a call
## by invite it is said again from its key, because the session keeps the words it
## was given, in the language of that moment; the LAN's are the session's own, and
## stay as it said them.
func _say_trouble() -> void:
	var said := ""
	var why := ""
	if _session != null and is_instance_valid(_session):
		said = _session.trouble
		why = _session.because
	var key := _trouble_key()
	if far and Invite.SAYS.has(key):
		var again := Invite.says(key)
		said = str(again[0])
		why = str(again[1])
	# TRANSLATORS: A heading, when a call ends and the game has no more
	# precise reason: nobody picked up. The reason, in a sentence, is
	# shown under it.
	_heading.text = said if not said.is_empty() else tr("no answer")
	_line.text = why
	if far:
		_receipt.text = _receipt_of(_kept)
		# TRANSLATORS: A button: try the same call again.
		var fix := tr("again")
		if key == &"no_invite":
			# TRANSLATORS: A button: paste the invite from the clipboard. The
			# invite is a one-line message a friend sent you. Keep it short:
			# the button is 264 px wide, in 20 px type.
			fix = tr("paste invite")
		elif _trouble_pastes:
			# TRANSLATORS: A button: paste a newer invite from the clipboard,
			# to replace the one this device keeps.
			fix = tr("paste new")
		_button(_first, fix)
	else:
		_receipt.text = ""
		_button(_first, tr("again"))
	# TRANSLATORS: A button: leave this screen and go back.
	_button(_second, tr("leave"))


## Which of `Invite.SAYS` the session's trouble is, or &"" for none: a LAN call,
## or a session that has gone.
func _trouble_key() -> StringName:
	if _session == null or not is_instance_valid(_session):
		return &""
	return _session.trouble_key


## **FAR's words: the kept invite, or the way to one.** A returning friend's page
## is call, with the address it calls; a first visit's is paste invite. What the
## last press did replaces the Heading, Line and Receipt until a press changes the
## page, and an invite its server turned away this run says so before anybody
## presses call -- call would only go straight to the same refusal.
func _say_far() -> void:
	# TRANSLATORS: What the game calls the way in to a friend's game far away, by an
	# invite they sent. It is a button on the screen where a game is started, and
	# the heading of this screen. Keep it short: the button is 320 px wide at 20 px.
	_heading.text = tr(Invite.DOOR_NAME)
	if _kept.is_empty():
		# TRANSLATORS: Instruction, in 17 px type on one line. An invite is a
		# one-line message a friend sends you in a chat app: copy it there, then
		# paste it into the game with the button below.
		# ROOM: 1180 px at 17 px
		_line.text = tr("copy the invite your friend sent you, then paste it here")
		_receipt.text = tr(NOTHING_KEPT)
		_button(_first, tr("paste invite"))
		_button(_second, "")
	else:
		# TRANSLATORS: Under the heading when an invite is kept. A friend's
		# "water" is the pond (shared game world) their server keeps.
		# ROOM: 1180 px at 17 px
		_line.text = tr("your friend's water, from their invite")
		_receipt.text = _receipt_of(_kept)
		_button(_first, tr("call"))
		_button(_second, tr("paste new"))
		# TRANSLATORS: A button: delete the invite this device keeps. It asks
		# "forget this invite?" first.
		_button(_third, tr("forget"))
		if NetSession.turned_away(_kept):
			# TRANSLATORS: A full sentence in 17 px type: the friend's server
			# refused this invite earlier in this session. "paste a new one" means
			# paste a newer invite, which the friend must send.
			# ROOM: 1180 px at 17 px
			_line.text = tr("your friend's server turned this invite away. paste a new one.")
	if not _said_after.is_empty():
		var words := _after_words(_said_after)
		_heading.text = str(words[0])
		_line.text = str(words[1])
		_receipt.text = str(words[2])


## **Where the keyboard goes as a page opens** -- not while the settings sheet is
## open over it, which keeps the keyboard until it closes and then hands it to
## the gear, one Down from here.
func _focus_page() -> void:
	# **Up from the buttons is the gear** (settings.md §1.3) -- except on
	# ANSWERING, where the ring above them owns the arrows and the corner is
	# reached by Tab, the mouse or a finger. The ring's own Up goes nowhere.
	if _page == Page.ANSWERING:
		for button: Button in [_first, _second, _third]:
			button.focus_neighbor_top = NodePath()
		_ring.focus_neighbor_top = _ring.get_path_to(_ring)
	else:
		_corner.link_focus(_first, [_second, _third])
	if _corner.is_open():
		return
	match _page:
		Page.ANSWERING:
			_ring.grab_focus()
		Page.TOGETHER:
			var last := RunState.load_mode()
			var start: Button = _second if last == RunState.Mode.POV else _first
			start.grab_focus()
		Page.FAR:
			var focus := 0
			if not _kept.is_empty() and NetSession.turned_away(_kept):
				focus = 1
			if not _said_after.is_empty():
				focus = int(_said_after.get("focus", 0))
			([_first, _second, _third][focus] as Button).grab_focus()
		_:
			_first.grab_focus()


## **Whether the drop chip shows** (docs/design/settings.md §1.1): while this
## phone is, or may become, the host -- CHOOSE, CALLING, and TOGETHER and TROUBLE
## while it hosts -- because the drop a host serves is the one selected, and
## changing it before the run starts changes what the friend will swim in. Never
## on a guest's page, so the drop a guest's cell comes from cannot change while
## it joins; never on a far page, which is always a guest's.
func _shows_drop() -> bool:
	var session: Node = _session if _session != null and is_instance_valid(_session) else null
	return not far and (session == null or bool(session.hosting))


## The page a visit starts on, and comes back to when a call stops.
func _home() -> int:
	return Page.FAR if far else Page.CHOOSE


## What the link is doing, turned into which page is on screen. The screen reads
## the session and never the other way round, so a link that drops for any
## reason lands the player somewhere that explains itself.
func _follow_link() -> void:
	if _session == null or not is_instance_valid(_session):
		_go_to(_home())
		return
	match int(_session.link):
		NetSession.Link.LISTENING:
			_go_to(Page.FAR if far else Page.CALLING)
		NetSession.Link.REACHING:
			# The session says whether its call is by invite: that is a pulse
			# leaving the cell, not a code being tapped.
			var by_invite: bool = far or bool(_session.by_invite())
			_go_to(Page.FAR_CALLING if by_invite else Page.ANSWERING)
		NetSession.Link.TOGETHER:
			_go_to(Page.TOGETHER)
		NetSession.Link.REFUSED, NetSession.Link.FAILED:
			_go_to(Page.TROUBLE)
		_:
			_go_to(_home())


func _on_link_changed(_link: int) -> void:
	_follow_link()


func _on_first() -> void:
	match _page:
		Page.CHOOSE:
			_call_out()
		Page.CALLING:
			_stop()
		Page.ANSWERING:
			_undo_tap()
		Page.TOGETHER:
			_play(RunState.Mode.FULL_VISION)
		Page.TROUBLE:
			if not far:
				_again()
			elif _trouble_pastes:
				_paste()
			else:
				_call_far()
		Page.FAR:
			if _kept.is_empty():
				_paste()
			else:
				_call_far()
		Page.FAR_CALLING:
			_stop()
		Page.FORGET:
			_go_to(Page.FAR)


func _on_second() -> void:
	match _page:
		Page.CHOOSE:
			_answer()
		Page.TOGETHER:
			_play(RunState.Mode.POV)
		Page.TROUBLE:
			_back()
		Page.FAR:
			_paste()
		Page.FORGET:
			_forget()


func _on_third() -> void:
	if _page == Page.FAR:
		_go_to(Page.FORGET)


# ---------------------------------------------------------------------------
# Calling and answering.
# ---------------------------------------------------------------------------

func _open_session() -> Node:
	if _session != null and is_instance_valid(_session):
		return _session
	var node: Node = NetSession.new()
	node.name = "NetSession"
	# Parented to the window root rather than to this scene, so it outlives the
	# change into the run. Not deferred: this only ever runs from a button
	# press, and root is not busy adding children then.
	get_tree().root.add_child(node)
	node.link_changed.connect(_on_link_changed)
	_session = node
	return node


func _call_out() -> void:
	var session := _open_session()
	if not session.host():
		_go_to(Page.TROUBLE)
		return
	_code = Lan.code_for(Lan.octet_of(session.address))
	_go_to(Page.CALLING)


func _answer() -> void:
	_open_session()
	_taps = PackedInt32Array()
	_cursor = 0
	_misdialled = false
	_go_to(Page.ANSWERING)


## Try the same thing again rather than dropping the player back at the fork:
## whichever half of the call they were on is the half they still want, and
## after a version refusal they are going to want it once more after an update.
func _again() -> void:
	var was_host := false
	if _session != null and is_instance_valid(_session):
		was_host = bool(_session.hosting)
	_stop()
	if was_host:
		_call_out()
	else:
		_answer()


## **Call the server the kept invite names**, read again for the call so it
## goes where the file says -- and again after TROUBLE, where `call_invite`
## starts the same session over. The session says how it went, through the
## link: REACHING is FAR_CALLING, and a call that ends at once -- no invite, no
## network, or an invite its server already turned away this run, which is not
## dialled again -- is TROUBLE, in the session's own sentence.
func _call_far() -> void:
	_kept = Invite.kept()
	var session := _open_session()
	session.call_invite(_kept)


func _stop() -> void:
	NetSession.close_current()
	_session = null
	_code = PackedInt32Array()
	_taps = PackedInt32Array()
	_go_to(_home())


func _tap(digit: int) -> void:
	if _page != Page.ANSWERING or _taps.size() >= Lan.DIGITS:
		return
	_misdialled = false
	_taps.append(digit)
	_cursor = digit
	if _taps.size() < Lan.DIGITS:
		_say_taps()
		_ring.queue_redraw()
		return
	var octet := Lan.octet_for(_taps)
	if octet < 0:
		# The check digit earning its tap: a mis-tap dies here, in front of the
		# player, instead of two seconds later as "no answer".
		_taps = PackedInt32Array()
		_misdialled = true
		_say_taps()
		_ring.queue_redraw()
		return
	_say_taps()
	_ring.queue_redraw()
	# An empty address is handed straight to `join`, which owns the sentence for
	# a device that has no network to be on. The screen does not write the
	# session's messages; it reads them.
	_session.join(Lan.host_address(Lan.local_address(), octet))


func _undo_tap() -> void:
	if _taps.is_empty():
		return
	_taps.remove_at(_taps.size() - 1)
	_say_taps()
	_ring.queue_redraw()


## ANSWERING's line: the dots, a code that did not read, or the call going out.
func _say_taps() -> void:
	if _taps.size() >= Lan.DIGITS or (_session != null and is_instance_valid(_session)
			and int(_session.link) == NetSession.Link.REACHING):
		# The taps are all in and the socket is out looking. Saying so beats
		# four filled dots, which look like a screen that has stopped.
		# TRANSLATORS: One word under the ring: the game is reaching out to the other
		# phone now that the whole code is in. Shown while it connects.
		_line.text = tr("reaching")
		return
	if _misdialled:
		# TRANSLATORS: Shown when the four marks tapped in do not form a valid
		# code (a mistap). The player is asked to tap the code in again.
		# ROOM: 1180 px at 17 px
		_line.text = tr("that is not a code. tap it again.")
		return
	var dots := ""
	for i in Lan.DIGITS:
		dots += "●" if i < _taps.size() else "○"
		if i < Lan.DIGITS - 1:
			dots += "  "
	_line.text = dots


func _say_line() -> void:
	if _session == null or not is_instance_valid(_session):
		return
	if _page == Page.TOGETHER:
		if far:
			# The session's own sentence once the water has gone quiet, as on
			# the LAN; until then, the far water's.
			var quiet: float = _session.quiet_for()
			_line.text = _session.peers_say() if quiet >= NetSession.SILENCE else tr(FAR_HEARD)
			return
		var says: String = _session.peers_say()
		_line.text = says if not says.is_empty() else tr("within earshot")
		return
	# Hosting. A refusal we handed out is worth saying: it is the only way the
	# person with the update to install finds out they need it.
	var trouble: String = _session.trouble
	_line.text = trouble if not trouble.is_empty() else tr("waiting for an answer")


## `address · port`: this device's address, and the LAN's port on its channel
## (channel.gd) -- 45781, not the release app's 45771, on a dev build.
func _here_says() -> String:
	var here := Lan.local_address()
	if here.is_empty():
		# TRANSLATORS: A small grey line: this device is not connected to any
		# network, so it has no address to show. Not a sentence; about 15 characters.
		return tr("no network here")
	return "%s · %d" % [here, Lan.channel_port()]


## What Back and Esc do here, said where a player looks for it -- or what Back
## does, on a device where Back is the gesture.
func _say_hint() -> void:
	var touch := _touch_first()
	if _page == Page.FAR:
		# TRANSLATORS: The hint along the bottom edge, in 14 px type. It names the
		# key that does the thing, and the key differs by device: `back` is the
		# Android Back button or gesture, `esc` the Escape key, `ctrl+v` the paste
		# shortcut. Translate the verb ("leaves" = leaves this screen); key names
		# may be written as they are labelled on your keyboards.
		_hint.text = tr("back leaves") if touch else tr("ctrl+v pastes · esc leaves")
	elif _page == Page.FORGET:
		# TRANSLATORS: The same hint, on the question "forget this invite?": the key
		# goes back and keeps the invite.
		_hint.text = tr("back keeps it") if touch else tr("esc keeps it")
	else:
		# TRANSLATORS: The same hint, on every other page: the key leaves this screen.
		_hint.text = tr("back leaves") if touch else tr("esc leaves")


# ---------------------------------------------------------------------------
# The kept invite: pasting and forgetting it.
# ---------------------------------------------------------------------------

## True when the page shows a paste button -- FAR's paste invite or paste new,
## or TROUBLE's paste new -- which is everything `ui_paste` presses.
func _pastes() -> bool:
	if _page == Page.FAR:
		return true
	return _page == Page.TROUBLE and far and _trouble_pastes


## **A paste, from the button or from `ui_paste`**, landing on FAR with a line
## that says what it did (§3). It replaces the kept invite only when it reads:
## anything else leaves the kept one as it was, and says so.
func _paste() -> void:
	if _page == Page.TROUBLE:
		# "The paste, landing on FAR": the call it followed is over.
		NetSession.close_current()
		_session = null
	# **The clipboard is read here, in a press, and nowhere else** (§2): never
	# on opening a page, on focus or on resume. Android 12 and later toast every
	# read, so the toast must only ever follow the player's own press. Nothing
	# empties it afterwards: the invite is still in the chat anyway.
	var read := Invite.parse(DisplayServer.clipboard_get())
	var before := Invite.kept()
	# The paste button keeps the focus after a paste that changed nothing, so
	# trying again is the same press: paste invite with nothing kept, paste new
	# with an invite kept.
	var paste_button := 0 if before.is_empty() else 1
	if int(read["read"]) != Invite.Read.OK:
		_after = {"read": int(read["read"]), "receipt": _receipt_of(before),
			"focus": paste_button}
	elif not before.is_empty() and str(before["line"]) == str(read["line"]):
		# A re-minted invite looks the same on screen as the one it replaces, so
		# the same one pasted again has to say so.
		_after = {"says": &"already_kept", "receipt": _receipt_of(before), "focus": 1}
	elif Invite.keep(read):
		# The first invite kept puts the keyboard on call; a newer one, on paste new.
		_after = {"says": &"kept" if before.is_empty() else &"replaced",
			"receipt": _receipt_of(read), "focus": 0 if before.is_empty() else 1}
	else:
		# `user://` would not take the file (invites-ux.md §6.2, row 4): the
		# kept invite is as it was -- `Invite.write_private` replaces it only
		# once the new one reads back -- and the press is the same to try again.
		_after = {"says": &"not_kept", "receipt": _receipt_of(before),
			"focus": paste_button}
	_go_to(Page.FAR)


func _forget() -> void:
	Invite.forget()
	_after = {"says": &"forgotten", "receipt": "", "focus": 0}
	_go_to(Page.FAR)


## **What a press on FAR did, in the language of the moment** (§3):
## `[heading, line, receipt]` for [param after], one of [member _after]'s.
func _after_words(after: Dictionary) -> Array:
	var receipt := str(after.get("receipt", ""))
	var says := StringName(after.get("says", &""))
	var said: Array = []
	if after.has("read"):
		said = Invite.says_read(int(after["read"]))
	elif Invite.SAYS.has(says):
		said = Invite.says(says)
	if not said.is_empty():
		# A paste that changed nothing: the invite the device already kept is
		# still there, and the line under the sentence says which.
		# TRANSLATORS: A small grey line when a paste failed: the invite the device
		# already kept is still there. %s is that invite's address and port, as in
		# "192.0.2.7 · 45772" -- keep %s as it is.
		var still := "" if receipt.is_empty() else tr("still kept: %s") % receipt
		return [str(said[0]), str(said[1]), still]
	match says:
		&"already_kept":
			# TRANSLATORS: The result of a paste: the invite on the clipboard is the
			# one the device already keeps. A short sentence under the heading.
			return [tr(Invite.DOOR_NAME), tr("that invite is already kept"), receipt]
		&"kept":
			# TRANSLATORS: The result of a paste: the invite was read and saved on
			# this device. Under the heading, with its address and port below.
			return [tr(Invite.DOOR_NAME), tr("invite kept"), receipt]
		&"replaced":
			# TRANSLATORS: The result of a paste: a newer invite was read and
			# replaced the one this device kept.
			return [tr(Invite.DOOR_NAME), tr("new invite kept"), receipt]
		&"forgotten":
			# TRANSLATORS: The result of "forget": the invite was deleted from this
			# device.
			return [tr(Invite.DOOR_NAME), tr("invite forgotten"), tr(NOTHING_KEPT)]
	return [tr(Invite.DOOR_NAME), "", receipt]


## **`address · port`**: the address as the owner typed it, a name or an IP,
## an IPv6 one without brackets; one over [constant RECEIPT_MOST] characters as
## its first and last [constant RECEIPT_KEEP] around `…`. Empty for no invite.
static func _receipt_of(invite: Dictionary) -> String:
	if invite.is_empty():
		return ""
	var address := str(invite.get("address", ""))
	if address.length() > RECEIPT_MOST:
		address = address.left(RECEIPT_KEEP) + "…" + address.right(RECEIPT_KEEP)
	return "%s · %d" % [address, int(invite.get("port", 0))]


# ---------------------------------------------------------------------------
# Leaving.
# ---------------------------------------------------------------------------

func _play(mode: int) -> void:
	if _leaving:
		return
	RunState.save_mode(mode)
	if not ResourceLoader.exists(NORMAL_SCENE):
		push_error("[Earshot] No game at %s" % NORMAL_SCENE)
		return
	_leaving = true
	# The session is deliberately left open and under `/root`: it is what the
	# run picks up, and closing it here would be closing the feature.
	get_tree().change_scene_to_file.call_deferred(NORMAL_SCENE)


func _back() -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(MODE_SELECT_SCENE):
		push_error("[Earshot] No chooser at %s" % MODE_SELECT_SCENE)
		return
	_leaving = true
	NetSession.close_current()
	_session = null
	# Deferred for the reason mode_select.gd's own _back() documents at length:
	# swapping the scene from inside Back's own notification propagation is the
	# tree telling you it is busy.
	get_tree().change_scene_to_file.call_deferred(MODE_SELECT_SCENE)


# ---------------------------------------------------------------------------
# The ring: drawing it, and being tapped on it.
# ---------------------------------------------------------------------------

func _on_ring_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _emulated(touch):
			_tap_at(touch.position)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
				and not _emulated(click):
			_tap_at(click.position)
		return
	# The keyboard and the joypad walk the cursor round the ring. No new
	# InputMap action: `ui_left`, `ui_right` and `ui_accept` are engine
	# built-ins, and a new action would be a project.godot change and therefore
	# a binary bump.
	if not event.is_pressed():
		return
	if event.is_action(&"ui_left") or event.is_action(&"ui_right"):
		var step := -1 if event.is_action(&"ui_left") else 1
		_cursor = posmod(_cursor + step, Lan.BEARINGS)
		_keyed = true
		_ring.accept_event()
		_ring.queue_redraw()
	elif event.is_action(&"ui_accept"):
		_keyed = true
		_ring.accept_event()
		_tap(_cursor)


## **One finger is one tap.** `emulate_mouse_from_touch` is on by default, so a
## single touch on Android arrives here twice -- once as the touch and once as a
## mouse button synthesised from it -- and a discrete action taken twice enters
## the wrong code and blames the player. Rendered and counted: the answering
## screen showed three taps for two fingers before this line existed.
##
## Both real paths stay live rather than leaning on the emulation, so this is
## still right if the setting is ever off.
func _emulated(event: InputEvent) -> bool:
	return event.device == InputEvent.DEVICE_ID_EMULATION


func _tap_at(where: Vector2) -> void:
	if _page != Page.ANSWERING:
		return
	var offset := where - _ring.size * 0.5
	var distance := offset.length()
	if distance < HIT_INNER or distance > HIT_OUTER:
		return
	_keyed = false
	# Bearing clockwise from straight up, which is `cell.gd`'s convention and
	# the membrane's: the ring reads the way the water does.
	_tap(Lan.digit_at(atan2(offset.x, -offset.y)))


func _draw_ring() -> void:
	if far or _page == Page.FAR or _page == Page.FAR_CALLING or _page == Page.FORGET:
		_draw_cell()
		return
	var middle := _ring.size * 0.5
	var half := deg_to_rad(MARK_HALF_DEG)
	# The ring, and then the twelve places on it, drawn as segments rather than
	# as ticks: a tap target the player cannot see is a tap target they will not
	# use, and a dial of twelve reads as *choose one of these* at a glance.
	# Rendered first as hairline ticks, which read as decoration.
	# Halved on the trouble page: there is nothing to tap there and the sentence
	# under it is the only thing worth reading.
	var dial := 0.16 if _page == Page.TROUBLE else 0.32
	_ring.draw_arc(middle, RING_RADIUS, 0.0, TAU, 96,
		Color(RING_COLOR, dial * 0.5), 2.0, true)
	for digit in Lan.BEARINGS:
		var mid := _arc_of(digit)
		_ring.draw_arc(middle, RING_RADIUS, mid - half, mid + half, 16,
			Color(RING_COLOR, dial), 6.0, true)
		if _page == Page.ANSWERING and _keyed and digit == _cursor:
			# Where the keyboard is standing. Outside the ring, so it never
			# covers a mark, and drawn only once a key has been pressed.
			_ring.draw_line(_point(middle, digit, RING_RADIUS + 12.0),
				_point(middle, digit, RING_RADIUS + 26.0),
				Color(RING_COLOR, 0.85), 3.0, true)

	var marks := _marks()
	if marks.is_empty():
		return
	var walking := _walking(marks.size())
	# The thread, inside the ring, in tapping order. It is what says which mark
	# is first without putting a number anywhere near the code.
	for i in marks.size() - 1:
		_ring.draw_line(_point(middle, marks[i], RING_RADIUS - 30.0),
			_point(middle, marks[i + 1], RING_RADIUS - 30.0),
			Color(CODE_COLOR, 0.26), 2.0, true)
	for i in marks.size():
		# Brightest first, dimmest last: a second, static reading of the order,
		# for anyone who does not wait for the walk to come round.
		var fade := 1.0 - 0.16 * float(i)
		var alpha := 1.0 if i == walking else 0.80 * fade
		var width := 12.0 if i == walking else 8.0
		var mid := _arc_of(marks[i])
		_ring.draw_arc(middle, RING_RADIUS, mid - half, mid + half, 20,
			Color(CODE_COLOR, alpha), width, true)


## **The ring on a far page: the player's own cell** (invites-ux.md §4).
## Nothing on it is tapped, so the dial is not drawn -- no twelve segments, no
## marks, no cursor -- and what is left is the membrane and a nucleus. A call
## is a ping leaving it, in `ampulla` violet like the LAN's code, because it is
## the same act; the nucleus wears the violet while it calls and once it is
## answered.
func _draw_cell() -> void:
	var middle := _ring.size * 0.5
	var dim := 0.5 if _page == Page.TROUBLE else 1.0
	_ring.draw_arc(middle, RING_RADIUS, 0.0, TAU, 96,
		Color(RING_COLOR, MEMBRANE_ALPHA * dim), 2.0, true)
	if _page == Page.FAR_CALLING:
		var at := fmod(_clock, PULSE_EVERY)
		if at < PULSE_TRAVEL:
			var u := at / PULSE_TRAVEL
			var radius := PULSE_FROM + PULSE_SPREAD * (1.0 - pow(1.0 - u, 2.0))
			_ring.draw_arc(middle, radius, 0.0, TAU, 128,
				Color(CODE_COLOR, PULSE_ALPHA * (1.0 - pow(u, 4.0))), lerpf(4.0, 1.5, u),
				true)
	var nucleus := Color(RING_COLOR, NUCLEUS_ALPHA * dim)
	if _page == Page.FAR_CALLING or _page == Page.TOGETHER:
		nucleus = Color(CODE_COLOR, NUCLEUS_CALLING_ALPHA)
	_ring.draw_circle(middle, NUCLEUS_RADIUS, nucleus, true, -1.0, true)


## A digit's bearing, in the angle `draw_arc` measures in.
##
## `draw_arc` places a point at `cos(t), sin(t)`; a ring bearing places one at
## `sin(b), -cos(b)`, clockwise from straight up. Those are the same point when
## `t = b - PI/2`, and the quarter turn is the whole of the conversion. Getting
## the sign of `b` wrong here mirrors the code about the vertical axis, which
## draws a perfectly plausible pattern that is not the one the thread runs
## through -- rendered, seen, fixed.
func _arc_of(digit: int) -> float:
	return Lan.bearing_of(digit) - PI * 0.5


## The digits to draw: the host's code, or the guest's taps so far.
func _marks() -> PackedInt32Array:
	if _page == Page.CALLING or (_page == Page.TOGETHER and not _code.is_empty()):
		return _code
	if _page == Page.ANSWERING or _page == Page.TOGETHER:
		return _taps
	return PackedInt32Array()


## Which mark the walk is on, or -1 while it is resting. The rest is the whole
## of how a reader knows where the code starts.
func _walking(count: int) -> int:
	if count <= 0 or _page == Page.ANSWERING:
		return -1
	var cycle := WALK_STEP * float(count) + WALK_REST
	var at := fmod(_clock, cycle)
	var step := int(at / WALK_STEP)
	return step if step < count else -1


func _point(middle: Vector2, digit: int, radius: float) -> Vector2:
	var bearing := Lan.bearing_of(digit)
	# Straight up is digit 0, and clockwise from there -- `cell.gd`'s forward().
	return middle + Vector2(sin(bearing), -cos(bearing)) * radius


func _button(button: Button, text: String) -> void:
	button.text = text
	button.visible = not text.is_empty()


## Which verb to name. Deliberately not asking the DisplayServer, which has no
## answer at all on a headless boot.
func _touch_first() -> bool:
	return OS.has_feature("mobile")
