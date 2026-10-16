extends RefCounted
## **A sound made in code** (docs/design/sound-and-touch.md §2): a sine that falls
## in pitch as it dies away, softly driven so it carries a few overtones, and
## low-passed so it carries nothing else. At 50 Hz it is a thump (the heart); at
## 1.5 kHz, a beep (the ping). The game has no audio
## files, and this makes it need none: a few numbers are the whole of a sound, a
## change to one ships as content, and the probe can read the waves it plays.
##
## Generic, as CLAUDE.md asks of every mechanic a later game reuses: it knows a
## spec, never what the sound is for. game/feel/heart.gd is the edge that names
## a heartbeat.
##
## **A spec** is a Dictionary, every key optional:
##
## | key | what | default |
## | --- | --- | --- |
## | `from_hz`, `to_hz` | the pitch it starts at and falls to | 80, 52 |
## | `glide` | how fast it falls, seconds per e-fold | 0.035 |
## | `attack` | its raised-cosine rise, seconds: no click | 0.006 |
## | `decay` | how fast it dies, seconds per e-fold | 0.05 |
## | `length` | how long the sound is; the last 20 ms fade to nothing | 0.3 |
## | `drive` | how hard it is driven (tanh): overtones at three and five times | 2.4 |
## | `knock`, `knock_ratio`, `knock_decay` | a quieter partial at that many times the pitch, dying faster: what a phone's speaker can play of it | 0, 3.5, 0.012 |
## | `cut_hz` | two one-pole low-passes: nothing much above it survives | 420 |
##
## Every sound comes out at a peak of exactly 1, so how loud it plays is the
## player's volume and nothing else.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The rate it is made at: the output's, so nothing is resampled.
const RATE := 44100
## The tail's fade, so a sound never ends on a step.
const TAIL_FADE := 0.02


## **The thump [param spec] describes**, as a stream to play.
static func thump(spec: Dictionary) -> AudioStreamWAV:
	return stream_of(thump_samples(spec))


## **Its samples**, -1..1, at [constant RATE]: what [method thump] plays, and what
## the probe reads.
static func thump_samples(spec: Dictionary) -> PackedFloat32Array:
	var from_hz := float(spec.get("from_hz", 80.0))
	var to_hz := float(spec.get("to_hz", 52.0))
	var glide := maxf(float(spec.get("glide", 0.035)), 0.001)
	var attack := maxf(float(spec.get("attack", 0.006)), 0.001)
	var decay := maxf(float(spec.get("decay", 0.05)), 0.001)
	var length := maxf(float(spec.get("length", 0.3)), attack + TAIL_FADE)
	var drive := maxf(float(spec.get("drive", 2.4)), 0.01)
	var knock := float(spec.get("knock", 0.0))
	var knock_ratio := float(spec.get("knock_ratio", 3.5))
	var knock_decay := maxf(float(spec.get("knock_decay", 0.012)), 0.001)
	var cut_hz := float(spec.get("cut_hz", 420.0))
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var norm := tanh(drive)
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (to_hz + (from_hz - to_hz) * exp(-t / glide)) / RATE
		var env: float = 0.5 - 0.5 * cos(PI * t / attack) if t < attack \
			else exp(-(t - attack) / decay)
		var x := env * sin(phase)
		if knock > 0.0:
			x += knock * env * exp(-t / knock_decay) * sin(phase * knock_ratio)
		out[i] = tanh(drive * x) / norm
	# Two passes of one pole: twelve decibels an octave above the cut.
	var a := exp(-TAU * cut_hz / RATE)
	for _pass in 2:
		var held := 0.0
		for i in n:
			held = (1.0 - a) * out[i] + a * held
			out[i] = held
	var fade := mini(int(RATE * TAIL_FADE), n)
	for k in fade:
		out[n - 1 - k] *= float(k) / float(fade)
	var peak := 0.0
	for v: float in out:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		for i in n:
			out[i] /= peak
	return out


## **Samples as a stream**: 16-bit, mono, at [constant RATE].
static func stream_of(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
