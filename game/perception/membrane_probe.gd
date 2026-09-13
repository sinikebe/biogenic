extends Node
## No gameplay: just the membrane plus a driver that holds one signal state, so
## every state in docs/design/perception.md §3 can be photographed with
## tools/shot.tscn before anything is wired to it.
##
##   godot --path . --rendering-driver opengl3 res://tools/shot.tscn -- \
##       --scene=res://game/perception/membrane_probe.tscn \
##       --state=nutrient_near --out=/tmp/near.png --wait=3
##
## With no --state it cycles every state, DWELL seconds each. Every state is
## held by re-posting the sensation each frame, so a screenshot taken at any
## moment looks the same -- no timing games.
##
## --beat=peak pins the metabolic beat at its peak and --beat=off silences it,
## which is how you check the thing §3 warns about: whether the beat swamps the
## signal underneath it.

const STATES: PackedStringArray = [
	"rest", "beat", "turn", "nutrient_far", "nutrient_near",
	"wake", "contact", "dread", "dread_wake", "ingest",
]

## Seconds per state when cycling.
const DWELL := 2.5
## Off the front and to starboard, so a bearing is obviously a bearing.
const TEST_BEARING := deg_to_rad(40.0)

## Concentrations for the two taste states: wide and barely there, versus deep
## inside the field.
const FAR_CONCENTRATION := 0.30
const NEAR_CONCENTRATION := 1.0

const MembraneLayer := preload("res://game/perception/membrane.gd")

@onready var _membrane: MembraneLayer = $Membrane
@onready var _bus := _membrane.bus

var _state := ""
var _beat := "run"
var _cycle := false
var _clock := 0.0
var _index := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--state="):
			_state = text.trim_prefix("--state=")
		elif text.begins_with("--beat="):
			_beat = text.trim_prefix("--beat=")
	if _beat == "off":
		_bus.set_beat(2.4, 0.0)
	if _state.is_empty() or not STATES.has(_state):
		if not _state.is_empty():
			push_warning("[probe] unknown state %s; cycling instead" % _state)
		_cycle = true
		_state = STATES[0]
	_enter(_state)


func _process(delta: float) -> void:
	if _cycle:
		_clock += delta
		if _clock >= DWELL:
			_clock = 0.0
			_index = (_index + 1) % STATES.size()
			_state = STATES[_index]
			_enter(_state)
			print("[probe] ", _state)
	_hold(_state)
	if _beat == "peak":
		_bus.pulse_now()


## One-shot part of a state: dread has to ramp, so it starts the moment the
## state is entered and takes about ten seconds to arrive.
func _enter(state: String) -> void:
	_bus.dread(0.95 if state.begins_with("dread") else 0.0)


## Per-frame part. Re-posting an impulsive sensation every frame pins its
## envelope at its peak, which is exactly what a photograph needs.
func _hold(state: String) -> void:
	match state:
		"beat":
			_bus.pulse_now()
		"turn":
			_bus.shear(1.0)
		"nutrient_far":
			_bus.taste(TEST_BEARING, FAR_CONCENTRATION)
		"nutrient_near":
			_bus.taste(TEST_BEARING, NEAR_CONCENTRATION)
		"wake", "dread_wake":
			_bus.shove(TEST_BEARING, 0.95)
		"contact":
			_bus.hit(TEST_BEARING, 1.0)
		"ingest":
			_bus.ingest()
		_:
			pass
