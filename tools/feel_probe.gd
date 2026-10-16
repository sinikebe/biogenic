extends Node
## **The heartbeat and the ping, heard and felt, checked**
## (docs/design/sound-and-touch.md §7, §9.5): what a render cannot show, because
## nothing of it is drawn.
##
##   godot --headless --path . --fixed-fps 60 res://tools/feel_probe.tscn
##   godot --headless --path . res://tools/feel_probe.tscn -- --wav=/tmp/heart.wav
##
## 1. **The sound** is low, quiet and clean: a peak of 1 that plays at the heart's
##    volume, nothing of it above 1 kHz and almost nothing above 400 Hz (the band
##    every later sound is left), most of it under 150 Hz, and no click -- it rises
##    from silence and ends in it.
## 2. **The cue** plays the lub at once and the dub after it, inside one beat at any
##    pace; a beat's strength scales both; and a buzz is short and weak, and comes
##    only when it may be felt, with vibration on, on a device with a hand.
## 3. **The switches** are on until turned off, are kept, and mute the whole mix.
## 4. **The sheet** shows the vibration row only where there is a hand to buzz,
##    and a tap throws its switch.
## 5. **A run**: every beat the bus makes is heard, lub and dub, and felt in the
##    water but not on the pause screen.
## 6. **The ping's sounds** (§9): the call and an echo sit above the heart's band
##    and below a hiss, start and end in silence, the call is the longer and the
##    echo the higher; an echo is as loud as it is strong, and neither buzzes.
## 7. **A run with a ping**: every call is heard, every echo the bus posts is
##    heard at its own strength, and the scope's sweep runs and holds a spike for
##    each echo since the call.
##
## `--wav=<path>` also writes a listening sample: the heart at rest, then racing,
## at the volumes the game plays it at. `--sonar-wav=<path>` writes the ping's:
## two calls, each answered by four bodies at 270, 430, 660 and 1000 units, each
## echo landing when it would and as loud as it would be at one copy.
##
## Excluded from export (`tools/*` on every preset), so none of it ships.

const Feel := preload("res://game/feel/feel.gd")
const Heart := preload("res://game/feel/heart.gd")
const Tone := preload("res://game/feel/tone.gd")
const Sonar := preload("res://game/feel/sonar.gd")
const FoodField := preload("res://game/normal/food.gd")
const Cilia := preload("res://game/vision/cilia.gd")
const RunState := preload("res://game/run_state.gd")
const CORNER := "res://game/menu/corner.tscn"
const RUN := "res://game/normal/normal_mode.tscn"

## The bands the sound must stay out of, as a share of its energy at most.
const ABOVE_400 := 0.01
const ABOVE_1K := 0.0005
## And the share it must have under 150 Hz at least.
const UNDER_150 := 0.9
## The largest step one sample may take: a click is a step.
const MAX_STEP := 0.05
## The loudest it may play, in dB of full scale, at a beat of full strength.
const LOUDEST_DB := -18.0
## The longest and strongest a buzz may be.
const LONGEST_BUZZ_MS := 25
const STRONGEST_BUZZ := 0.25
## The ping's bands: at most this share under 400 Hz (the heart's) and above 5 kHz.
const PING_UNDER_400 := 0.01
const PING_ABOVE_5K := 0.01
## The bodies the sonar sample's calls are answered by, in units to their near edge.
const SAMPLE_BODIES: Array[float] = [270.0, 430.0, 660.0, 1000.0]

var _failed := 0


func _ready() -> void:
	var wav := ""
	var sonar_wav := ""
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--wav="):
			wav = str(arg).trim_prefix("--wav=")
		elif str(arg).begins_with("--sonar-wav="):
			sonar_wav = str(arg).trim_prefix("--sonar-wav=")
	var sound_was := RunState.load_sound()
	var vibration_was := RunState.load_vibration()
	_sound()
	_cue()
	_switches()
	await _sheet()
	await _run()
	_sonar()
	await _sonar_run()
	if wav != "":
		_write(wav)
	if sonar_wav != "":
		_write_sonar(sonar_wav)
	# Whatever this machine had, put back.
	Feel.set_sound(sound_was)
	Feel.set_vibration(vibration_was)
	Feel.handheld = -1
	print("[feel-probe] ALL PASS" if _failed == 0 else "[feel-probe] FAILED %d" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("[feel-probe] %s %s" % ["PASS" if ok else "FAIL", what])


# --- 1. The sound ------------------------------------------------------------

func _sound() -> void:
	for named: Array in [["lub", Heart.LUB, Heart.LUB_DB], ["dub", Heart.DUB, Heart.DUB_DB]]:
		var samples := Tone.thump_samples(named[1])
		var peak := 0.0
		var step := 0.0
		for i in samples.size():
			peak = maxf(peak, absf(samples[i]))
			if i > 0:
				step = maxf(step, absf(samples[i] - samples[i - 1]))
		var total := _energy(samples)
		var above_400 := _energy(_high_pass(samples, 400.0)) / total
		var above_1k := _energy(_high_pass(samples, 1000.0)) / total
		var under_150 := 1.0 - _energy(_high_pass(samples, 150.0)) / total
		_check("1. the %s: %.2f s, peak %.3f, played at %.0f dBFS (at most %.0f); %.1f %% of it under 150 Hz (at least %.0f), %.3f %% above 400 Hz (at most %.1f), %.4f %% above 1 kHz (at most %.2f); its largest step %.4f (at most %.2f), from %.4f to %.4f"
			% [named[0], samples.size() / float(Tone.RATE), peak, named[2], LOUDEST_DB,
				under_150 * 100.0, UNDER_150 * 100.0, above_400 * 100.0, ABOVE_400 * 100.0,
				above_1k * 100.0, ABOVE_1K * 100.0, step, MAX_STEP, samples[0],
				samples[samples.size() - 1]],
			is_equal_approx(peak, 1.0) and float(named[2]) <= LOUDEST_DB
			and under_150 >= UNDER_150 and above_400 <= ABOVE_400 and above_1k <= ABOVE_1K
			and step <= MAX_STEP and absf(samples[0]) < 0.001
			and samples[samples.size() - 1] == 0.0)
	_check("1. the dub is quieter than the lub (%.0f dB under it) and the stream is the samples, 16-bit at %d Hz"
		% [Heart.LUB_DB - Heart.DUB_DB, Tone.RATE],
		Heart.DUB_DB < Heart.LUB_DB
		and Tone.thump(Heart.LUB).data.size() == Tone.thump_samples(Heart.LUB).size() * 2
		and Tone.thump(Heart.LUB).mix_rate == Tone.RATE)


static func _energy(samples: PackedFloat32Array) -> float:
	var sum := 0.0
	for v: float in samples:
		sum += v * v
	return maxf(sum, 1e-12)


## Twelve decibels an octave under [param hz] a pass: Butterworth, through the
## bilinear transform, as a measuring instrument and never as a sound.
static func _high_pass(samples: PackedFloat32Array, hz: float, passes: int = 1) \
		-> PackedFloat32Array:
	var out := samples
	for p in passes:
		out = _high_pass_once(out, hz)
	return out


## And its mirror, over [param hz].
static func _low_pass(samples: PackedFloat32Array, hz: float, passes: int = 1) \
		-> PackedFloat32Array:
	var out := samples
	for p in passes:
		out = _biquad(out, hz, false)
	return out


static func _high_pass_once(samples: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	return _biquad(samples, hz, true)


static func _biquad(samples: PackedFloat32Array, hz: float, high: bool) -> PackedFloat32Array:
	var w := tan(PI * hz / Tone.RATE)
	var k := 1.0 / (1.0 + sqrt(2.0) * w + w * w)
	var a1 := 2.0 * (w * w - 1.0) * k
	var a2 := (1.0 - sqrt(2.0) * w + w * w) * k
	# High: k (1, -2, 1). Low: k w^2 (1, 2, 1).
	var b0: float = k if high else k * w * w
	var b1: float = -2.0 * k if high else 2.0 * k * w * w
	var out := PackedFloat32Array()
	out.resize(samples.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in samples.size():
		var x := samples[i]
		var y := b0 * x + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


# --- 2. The cue --------------------------------------------------------------

func _cue() -> void:
	Feel.sound_on = true
	Feel.vibration_on = true
	Feel.handheld = 1
	var feel: Feel = Feel.new()
	add_child(feel)
	feel.set_process(false)
	feel.cue(&"beat", Heart.parts())
	var buzzes: Array = []
	feel.buzzer = func(ms: int, amplitude: float) -> void: buzzes.append([ms, amplitude])
	var played: Array = []
	feel.fired.connect(func(kind: StringName, index: int, sounded: bool, db: float, ms: int,
			amplitude: float) -> void: played.append([kind, index, sounded, db, ms, amplitude]))

	feel.hear(&"beat", {"strength": 1.0, "period": 2.4})
	var lub_now := played.size() == 1 and int(played[0][1]) == 0 and bool(played[0][2])
	feel.step(Heart.DUB_AFTER - 0.01)
	var dub_not_yet := played.size() == 1
	feel.step(0.02)
	var dub_then := played.size() == 2 and int(played[1][1]) == 1 and bool(played[1][2])
	_check("2. a beat at rest: the lub at once (%s), the dub %.2f s after it and not before (%s, %s), each heard, at %s dB"
		% [lub_now, Heart.DUB_AFTER, dub_not_yet, dub_then,
			str(played.map(func(e: Array) -> String: return "%.1f" % float(e[3])))],
		lub_now and dub_not_yet and dub_then and is_equal_approx(float(played[0][3]), Heart.LUB_DB)
		and is_equal_approx(float(played[1][3]), Heart.DUB_DB))
	var short_and_weak := buzzes.size() == 2
	for buzz: Array in buzzes:
		short_and_weak = short_and_weak and int(buzz[0]) > 0 \
			and int(buzz[0]) <= LONGEST_BUZZ_MS and float(buzz[1]) > 0.0 \
			and float(buzz[1]) <= STRONGEST_BUZZ
	_check("2. two buzzes, each at most %d ms and %.2f: %s" % [LONGEST_BUZZ_MS, STRONGEST_BUZZ,
		str(buzzes)], short_and_weak)

	# Racing: the dub comes inside the beat.
	played.clear()
	feel.hear(&"beat", {"strength": 1.0, "period": 0.4})
	var inside := Heart.DUB_SHARE * 0.4
	feel.step(inside - 0.005)
	var early := played.size() == 1
	feel.step(0.01)
	_check("2. a racing beat of 0.4 s: its dub at %.3f s, inside the beat (%s, %s)"
		% [inside, early, played.size() == 2], early and played.size() == 2 and inside < 0.4)

	# Dimmed: a beat at 0.15 is quieter and weaker by as much.
	played.clear()
	buzzes.clear()
	feel.hear(&"beat", {"strength": 0.15, "period": 2.4})
	feel.step(1.0)
	var quieter := played.size() == 2 and is_equal_approx(float(played[0][3]),
		Heart.LUB_DB + linear_to_db(0.15))
	var weaker := buzzes.size() == 2 and is_equal_approx(float(buzzes[0][1]),
		Heart.LUB_BUZZ * 0.15)
	_check("2. a beat at 0.15 of its strength plays %.1f dB and buzzes at %.3f"
		% [float(played[0][3]) if played.size() > 0 else 0.0,
			float(buzzes[0][1]) if buzzes.size() > 0 else 0.0], quieter and weaker)

	# Gated: not felt, vibration off, no hand, sound off, an unknown kind.
	var gates := {}
	for gate: String in ["not felt", "vibration off", "no hand", "sound off", "unknown"]:
		played.clear()
		buzzes.clear()
		Feel.vibration_on = gate != "vibration off"
		Feel.handheld = 0 if gate == "no hand" else 1
		Feel.sound_on = gate != "sound off"
		feel.hear(&"taste" if gate == "unknown" else &"beat",
			{"strength": 1.0, "period": 2.4}, gate != "not felt")
		feel.step(1.0)
		var heard := played.filter(func(e: Array) -> bool: return bool(e[2])).size()
		gates[gate] = [heard, buzzes.size()]
	Feel.sound_on = true
	Feel.vibration_on = true
	Feel.handheld = 1
	_check("2. heard and buzzed, by gate: %s -- each gate stops the buzz, sound off stops the sound and nothing else does, and an unknown kind plays nothing"
		% str(gates),
		gates["not felt"] == [2, 0] and gates["vibration off"] == [2, 0]
		and gates["no hand"] == [2, 0] and gates["sound off"] == [0, 2]
		and gates["unknown"] == [0, 0])

	# Quiet: nothing still to come is played.
	played.clear()
	feel.hear(&"beat", {"strength": 1.0, "period": 2.4})
	feel.quiet()
	feel.step(1.0)
	_check("2. quiet() drops the dub still to come: %d part played after the lub" % (played.size() - 1),
		played.size() == 1)
	feel.free()


# --- 3. The switches ---------------------------------------------------------

func _switches() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	Feel.set_sound(false)
	var off := not RunState.load_sound() and AudioServer.is_bus_mute(master)
	Feel.set_sound(true)
	var on := RunState.load_sound() and not AudioServer.is_bus_mute(master)
	Feel.set_vibration(false)
	var still := not RunState.load_vibration()
	Feel.set_vibration(true)
	Feel.vibration_on = false
	Feel.apply()
	_check("3. the switches: sound off is kept and mutes the mix (%s), on unmutes it (%s); vibration off is kept (%s) and apply() reads it back (%s)"
		% [off, on, still, Feel.vibration_on], off and on and still and Feel.vibration_on)
	var config := ConfigFile.new()
	config.load(RunState.PATH)
	for key: String in ["sound", "vibration"]:
		if config.has_section_key("app", key):
			config.erase_section_key("app", key)
	config.save(RunState.PATH)
	_check("3. with nothing kept, both are on (%s, %s)" % [RunState.load_sound(),
		RunState.load_vibration()], RunState.load_sound() and RunState.load_vibration())


# --- 4. The sheet ------------------------------------------------------------

func _sheet() -> void:
	var rows := {}
	for hand: int in [0, 1]:
		Feel.handheld = hand
		var corner: Control = (load(CORNER) as PackedScene).instantiate()
		add_child(corner)
		await get_tree().process_frame
		var sound: Button = corner.get_node(^"Settings/Panel/Box/Feel/Sound")
		var vibration: Button = corner.get_node(^"Settings/Panel/Box/Feel/Vibration")
		rows[hand] = vibration.visible
		if hand == 1:
			sound.pressed.emit()
			var thrown := not Feel.sound_on
			sound.pressed.emit()
			vibration.pressed.emit()
			var buzz_thrown := not Feel.vibration_on
			vibration.pressed.emit()
			_check("4. a tap throws a switch and a second throws it back: sound %s, vibration %s; both on again (%s, %s)"
				% [thrown, buzz_thrown, Feel.sound_on, Feel.vibration_on],
				thrown and buzz_thrown and Feel.sound_on and Feel.vibration_on)
		corner.free()
	Feel.handheld = 1
	_check("4. the vibration row shows with a hand to buzz (%s) and not without one (%s)"
		% [rows[1], rows[0]], rows[1] and not rows[0])


# --- 5. A run ----------------------------------------------------------------

func _run() -> void:
	Feel.handheld = 1
	var run: Node = (load(RUN) as PackedScene).instantiate()
	for key: StringName in [&"keep", &"cells_at", &"library_at"]:
		if key in run:
			run.set(key, "")
	add_child(run)
	var feel: Feel = run.get_node(^"Feel")
	var bus: Node = run.get("_bus")
	var buzzes := [0]
	feel.buzzer = func(_ms: int, _amplitude: float) -> void: buzzes[0] += 1
	var heard := [0]
	feel.fired.connect(func(kind: StringName, _index: int, sounded: bool, _db: float,
			_ms: int, _amplitude: float) -> void:
		if sounded and kind == &"beat":
			heard[0] += 1)
	var beats := [0]
	bus.sensation.connect(func(kind: StringName, _info: Dictionary) -> void:
		if kind == &"beat":
			beats[0] += 1)
	await _seconds(6.0)
	var water := [beats[0], heard[0], buzzes[0]]
	run.call(&"_toggle_pause")
	beats[0] = 0
	heard[0] = 0
	buzzes[0] = 0
	await _seconds(6.0)
	var paused := [beats[0], heard[0], buzzes[0]]
	run.call(&"_toggle_pause")
	_check("5. a run in the water: %d beats, %d sounds and %d buzzes -- two of each a beat, the last dub perhaps still to come"
		% water, water[0] >= 2 and water[1] >= water[0] * 2 - 1 and water[1] <= water[0] * 2
		and water[2] == water[1])
	_check("5. on the pause screen: %d beats, %d sounds and %d buzzes -- heard, never felt"
		% paused, paused[0] >= 2 and paused[1] >= paused[0] * 2 - 1 and paused[2] == 0)
	run.queue_free()
	await get_tree().process_frame


# --- 6. The ping's sounds -----------------------------------------------------

func _sonar() -> void:
	var shapes := {}
	for named: Array in [["call", Sonar.CALL, Sonar.CALL_DB], ["echo", Sonar.ECHO, Sonar.ECHO_DB]]:
		var samples := Tone.thump_samples(named[1])
		var total := _energy(samples)
		# Each band through a filter that keeps only it, three passes deep, 36 dB an
		# octave: one pass at 5 kHz let through 2.8 % of a 2 kHz tone's energy, and the
		# complement of a high-pass at 400 Hz counted its droop at 1 kHz -- the
		# instrument, not the sound (measured).
		var under_400 := _energy(_low_pass(samples, 400.0, 3)) / total
		var above_5k := _energy(_high_pass(samples, 5000.0, 3)) / total
		shapes[named[0]] = samples.size()
		_check("6. the ping's %s: %.2f s at %.0f dBFS (at most %.0f), %.3f %% under 400 Hz (at most %.1f), %.3f %% above 5 kHz (at most %.1f), from %.4f to %.4f"
			% [named[0], samples.size() / float(Tone.RATE), named[2], LOUDEST_DB,
				under_400 * 100.0, PING_UNDER_400 * 100.0, above_5k * 100.0,
				PING_ABOVE_5K * 100.0, samples[0], samples[samples.size() - 1]],
			float(named[2]) <= LOUDEST_DB and under_400 <= PING_UNDER_400
			and above_5k <= PING_ABOVE_5K and absf(samples[0]) < 0.001
			and samples[samples.size() - 1] == 0.0)
	_check("6. the call is the longer (%d samples against %d) and an echo the higher: it starts at %.0f Hz, above the call's %.0f to %.0f"
		% [shapes["call"], shapes["echo"], Sonar.ECHO["from_hz"], Sonar.CALL["from_hz"],
			Sonar.CALL["to_hz"]],
		int(shapes["call"]) > int(shapes["echo"])
		and float(Sonar.ECHO["to_hz"]) > float(Sonar.CALL["from_hz"]))
	Feel.sound_on = true
	Feel.vibration_on = true
	Feel.handheld = 1
	var feel: Feel = Feel.new()
	add_child(feel)
	feel.set_process(false)
	feel.cue(&"call", Sonar.call_parts())
	feel.cue(&"ping", Sonar.echo_parts())
	var buzzes := [0]
	feel.buzzer = func(_ms: int, _amplitude: float) -> void: buzzes[0] += 1
	var played: Array = []
	feel.fired.connect(func(kind: StringName, _index: int, sounded: bool, db: float, _ms: int,
			_amplitude: float) -> void: played.append([kind, sounded, db]))
	feel.hear(&"call", {"strength": 1.0}, true)
	var near := FoodField.ping_level(2.0 * 100.0, 1100.0)
	var far := FoodField.ping_level(2.0 * 1000.0, 1100.0)
	feel.hear(&"ping", {"strength": near}, true)
	feel.hear(&"ping", {"strength": far}, true)
	feel.step(1.0)
	var spread := float(played[1][2]) - float(played[2][2]) if played.size() == 3 else 0.0
	_check("6. a call at %.0f dB; an echo off a body 100 units out at %.2f plays %.1f dB, one off a body 1000 out at %.2f plays %.1f dB -- %.1f dB apart, as their strengths are; no buzz (%d)"
		% [float(played[0][2]) if played.size() > 0 else 0.0, near,
			float(played[1][2]) if played.size() > 1 else 0.0, far,
			float(played[2][2]) if played.size() > 2 else 0.0, spread, buzzes[0]],
		played.size() == 3 and bool(played[0][1]) and bool(played[1][1])
		and bool(played[2][1]) and is_equal_approx(float(played[0][2]), Sonar.CALL_DB)
		and is_equal_approx(spread, linear_to_db(near / far)) and spread > 10.0
		and buzzes[0] == 0)
	feel.free()


# --- 7. A run with a ping ------------------------------------------------------

func _sonar_run() -> void:
	var run: Node = (load(RUN) as PackedScene).instantiate()
	for key: StringName in [&"keep", &"cells_at", &"library_at"]:
		if key in run:
			run.set(key, "")
	add_child(run)
	var tiers := {&"cytostome": 1, &"cirrus": 1, &"flagellum": 1, &"ampulla": 1}
	(run.get("_genome") as Node).call(&"express", tiers, Cilia.default_order(tiers))
	var feel: Feel = run.get_node(^"Feel")
	var bus: Node = run.get("_bus")
	var counts := {"calls": 0, "pings": 0, "heard": 0, "since": 0, "wrong": 0}
	# The run hears the bus before this probe does -- it connected first -- so an
	# echo's sound has played by the time its sensation reaches the check below.
	var last_db := [INF]
	feel.fired.connect(func(kind: StringName, _index: int, sounded: bool, db: float,
			_ms: int, _amplitude: float) -> void:
		if kind == &"call" and sounded:
			counts["calls"] += 1
			counts["since"] = 0
		elif kind == &"ping" and sounded:
			counts["heard"] += 1
			last_db[0] = db)
	bus.sensation.connect(func(kind: StringName, info: Dictionary) -> void:
		if kind == &"ping":
			counts["pings"] += 1
			counts["since"] += 1
			var strength := float(info.get("strength", 0.0))
			if not is_equal_approx(float(last_db[0]),
					Sonar.ECHO_DB + linear_to_db(maxf(strength, 0.001))):
				counts["wrong"] += 1
			last_db[0] = INF)
	await _seconds(12.0)
	var scope: Node = run.call(&"_ping_scope")
	var spikes: int = (scope.get("_spikes") as Array).size() if scope != null else -1
	var sweep: float = float(scope.get("sweep")) if scope != null else -1.0
	_check("7. a run with a ping, 12 s: %d calls heard, %d echoes posted and %d heard, %d at a volume not their strength's"
		% [counts["calls"], counts["pings"], counts["heard"], counts["wrong"]],
		counts["calls"] >= 1 and counts["heard"] == counts["pings"] and counts["wrong"] == 0)
	_check("7. its scope: the sweep is out at %.0f units, and holds %d spikes for the %d echoes since the last call"
		% [sweep, spikes, counts["since"]],
		scope != null and sweep > 0.0 and spikes == counts["since"])
	run.queue_free()
	await get_tree().process_frame


## [param seconds] of frames, at the 60 a second `--fixed-fps 60` steps them at.
func _seconds(seconds: float) -> void:
	for f in int(seconds * 60.0):
		await get_tree().process_frame


# --- The listening sample ----------------------------------------------------

## **The heart as a player hears it**: five beats at rest, 2.4 s apart, then eight
## racing at 0.6 s -- each lub and dub at its own volume, mixed into one file.
func _write(path: String) -> void:
	var lub := Tone.thump_samples(Heart.LUB)
	var dub := Tone.thump_samples(Heart.DUB)
	var beats: Array[float] = []
	var t := 0.3
	for i in 5:
		beats.append(t)
		t += 2.4
	for i in 8:
		beats.append(t)
		t += 0.6
	var mix := PackedFloat32Array()
	mix.resize(int((t + 0.6) * Tone.RATE))
	var lub_gain := db_to_linear(Heart.LUB_DB)
	var dub_gain := db_to_linear(Heart.DUB_DB)
	for k in beats.size():
		var period := 2.4 if k < 5 else 0.6
		var at := int(beats[k] * Tone.RATE)
		var dub_at := at + int(minf(Heart.DUB_AFTER, Heart.DUB_SHARE * period) * Tone.RATE)
		for i in lub.size():
			mix[at + i] += lub[i] * lub_gain
		for i in dub.size():
			mix[dub_at + i] += dub[i] * dub_gain
	var stream := Tone.stream_of(mix)
	var err := stream.save_to_wav(path)
	_check("the listening sample: %.1f s written to %s (%s)" % [t + 0.6, path, error_string(err)],
		err == OK)


## **The ping as a player hears it**: two calls 8.8 s apart, each answered by
## [constant SAMPLE_BODIES] -- each echo landing when it would, `2d / PING_SPEED`
## after its call, as loud as `ping_level` makes it at one copy.
func _write_sonar(path: String) -> void:
	var call := Tone.thump_samples(Sonar.CALL)
	var pip := Tone.thump_samples(Sonar.ECHO)
	var length := 0.3 + 8.8 * 2.0
	var mix := PackedFloat32Array()
	mix.resize(int(length * Tone.RATE))
	for k in 2:
		var at := 0.3 + 8.8 * k
		_add(mix, call, at, db_to_linear(Sonar.CALL_DB))
		for distance: float in SAMPLE_BODIES:
			var level := FoodField.ping_level(2.0 * distance, 1100.0)
			_add(mix, pip, at + 2.0 * distance / FoodField.PING_SPEED,
				db_to_linear(Sonar.ECHO_DB) * level)
	var err := Tone.stream_of(mix).save_to_wav(path)
	_check("the ping's listening sample: %.1f s written to %s (%s)" % [length, path,
		error_string(err)], err == OK)


static func _add(mix: PackedFloat32Array, sound: PackedFloat32Array, at: float,
		gain: float) -> void:
	var from := int(at * Tone.RATE)
	for i in sound.size():
		if from + i < mix.size():
			mix[from + i] += sound[i] * gain
