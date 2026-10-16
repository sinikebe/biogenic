extends Node
## **What the body is heard and felt as** (docs/design/sound-and-touch.md): the
## signal bus's second listener, on the seam perception.md §5 kept open -- every
## `sensation` the bus posts is offered here, and a kind given a cue plays it:
## sounds, and short buzzes of the phone in the hand.
##
## **A cue** is a list of parts, each one moment of it:
##
## | key | what |
## | --- | --- |
## | `sound` | an AudioStream to play, or none |
## | `db` | its volume at a sensation of strength 1 |
## | `buzz_ms`, `buzz` | a buzz of the hand that long, at that amplitude (0..1) at strength 1, or none |
## | `after` | seconds after the sensation, 0 for at once |
## | `share` | and never later than this share of the sensation's `period`, so a quickening rhythm keeps its parts inside one beat |
##
## A sensation's `strength` scales every part: the sound by its amplitude, the buzz
## by its own. So whatever dims a sensation on screen dims what is heard and felt
## of it, with no rule of its own here.
##
## **The player's two switches** are on the settings sheet (game/menu/corner.gd),
## both on until turned off: [member sound_on] mutes the whole game's mix, and
## [member vibration_on] stops every buzz. They are kept in `user://` through
## RunState and applied at boot, before any screen (game/boot.gd).
##
## Generic, as CLAUDE.md asks of every mechanic a later game reuses: it knows kinds
## and parts, and nothing of what they mean. game/feel/heart.gd names the
## heartbeat, and game/normal/normal_mode.gd says when a buzz may be felt.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## A part played: [param kind]'s part [param index], heard at [param db] or not
## heard at all ([param sounded] false: no sound, or sound off), and buzzed for
## [param ms] at [param amplitude] or not (0). For the probe; nothing in the game
## listens.
signal fired(kind: StringName, index: int, sounded: bool, db: float, ms: int,
	amplitude: float)

const RunState := preload("res://game/run_state.gd")

## How many sounds can overlap: the end of one beat under the start of the next,
## and one more.
const VOICES := 3
## The quietest a strength is taken as, so a whisper of a sensation is very quiet
## rather than minus infinity decibels.
const QUIETEST := 0.001

## **The player's switches**, as last applied by [method apply]: whether the game
## makes a sound, and whether it buzzes the hand.
static var sound_on := true
static var vibration_on := true
## For tools: -1 asks the platform whether a hand can be buzzed, 0 or 1 says so.
static var handheld := -1

## **Who buzzes the hand**: the platform, or a probe's counter. Called with the
## length in milliseconds and the amplitude, 0..1.
var buzzer := func(ms: int, amplitude: float) -> void:
	Input.vibrate_handheld(ms, amplitude)

## The cues, by the kind of sensation they answer.
var _cues := {}
## Parts still to come: `[seconds, kind, index, strength, felt]`, soonest first.
var _due: Array = []
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


## **The switches, from `user://`**: read once, at boot, and again by nothing but
## a switch thrown.
static func apply() -> void:
	sound_on = RunState.load_sound()
	vibration_on = RunState.load_vibration()
	_mute()


## The sound switch thrown: kept, and the mix muted or not at once.
static func set_sound(on: bool) -> void:
	sound_on = on
	RunState.save_sound(on)
	_mute()


## The vibration switch thrown: kept, and the next buzz obeys it.
static func set_vibration(on: bool) -> void:
	vibration_on = on
	RunState.save_vibration(on)


## **Whether this device has a hand to buzz**: a phone, not a desktop. The
## vibration switch shows only where it is true.
static func can_vibrate() -> bool:
	if handheld >= 0:
		return handheld > 0
	return OS.has_feature("android") or OS.has_feature("ios")


## The whole mix, muted while the sound switch is off: every sound the game will
## ever make goes through it, so a new one needs no switch of its own.
static func _mute() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, not sound_on)


func _ready() -> void:
	# The bus beats on under the pause scrim (signal_bus.gd), so what is heard of
	# it does as well: a beat's second part, and the sounds themselves, finish
	# while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		add_child(voice)
		_voices.append(voice)


## **[param kind] answers with [param parts]** from now on.
func cue(kind: StringName, parts: Array) -> void:
	_cues[kind] = parts


## **A sensation**, as the bus posted it: [param kind] and its `strength` and
## `period`. Its cue plays at once and over the moments after; [param felt] false
## keeps every buzz of it out of the hand and plays its sounds alone.
func hear(kind: StringName, info: Dictionary, felt: bool = true) -> void:
	var parts: Array = _cues.get(kind, [])
	if parts.is_empty():
		return
	var strength := clampf(float(info.get("strength", 1.0)), 0.0, 1.0)
	var period := float(info.get("period", 0.0))
	for index in parts.size():
		var part: Dictionary = parts[index]
		var after := float(part.get("after", 0.0))
		var share := float(part.get("share", 0.0))
		if share > 0.0 and period > 0.0:
			after = minf(after, share * period)
		if after <= 0.0:
			_fire(kind, index, strength, felt)
		else:
			_due.append([after, kind, index, strength, felt])
	_due.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


## **Nothing more of anything heard**: what is still to come is dropped and what
## is playing stops. A new life, and a run left.
func quiet() -> void:
	_due.clear()
	for voice in _voices:
		voice.stop()


func _process(delta: float) -> void:
	step(delta)


## **[param delta] seconds on**: every part that has come due plays, in order.
func step(delta: float) -> void:
	for due: Array in _due:
		due[0] = float(due[0]) - delta
	while not _due.is_empty() and float(_due[0][0]) <= 0.0:
		var due: Array = _due.pop_front()
		_fire(due[1], int(due[2]), float(due[3]), bool(due[4]))


func _fire(kind: StringName, index: int, strength: float, felt: bool) -> void:
	var parts: Array = _cues.get(kind, [])
	if index >= parts.size():
		return
	var part: Dictionary = parts[index]
	var sound: AudioStream = part.get("sound")
	var db := float(part.get("db", 0.0)) + linear_to_db(maxf(strength, QUIETEST))
	var sounded := sound != null and sound_on and not _voices.is_empty()
	if sounded:
		var voice := _voices[_next_voice]
		_next_voice = (_next_voice + 1) % _voices.size()
		voice.stream = sound
		voice.volume_db = db
		voice.play()
	var ms := int(part.get("buzz_ms", 0))
	var amplitude := float(part.get("buzz", 0.0)) * strength
	var buzzed := felt and vibration_on and ms > 0 and amplitude > 0.0 and can_vibrate()
	if buzzed:
		buzzer.call(ms, amplitude)
	fired.emit(kind, index, sounded, db, ms if buzzed else 0, amplitude if buzzed else 0.0)
