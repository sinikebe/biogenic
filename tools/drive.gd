extends Node
## Dev harness: boots a game scene and feeds it synthetic input, so states that
## only exist mid-play can be photographed and the input path itself gets
## exercised rather than assumed.
##
## Sits between tools/shot.tscn and the game:
##
##   godot --path . --rendering-driver opengl3 res://tools/shot.tscn -- \
##       --scene=res://tools/drive.tscn --hold=d --out=/tmp/turn.png --wait=4
##
## Arguments (all optional, all after the -- that shot.gd also reads):
##   --play=res://...        scene to drive, default normal mode
##   --mode=0|1              force the view: 0 point of view, 1 full vision
##   --scheme=0|1|2          force the control scheme: 0 anywhere (the one that
##                           ships), 1 stick, 2 pads. The choice lives in
##                           `user://`, so without this a scheme cannot be
##                           photographed without writing one the next run --
##                           and every other render in this project -- would
##                           inherit
##   --hold=a|d              hold a steering key for the whole run
##   --drag=<pixels>         press near the middle and drag this far sideways
##   --drag-at=<seconds>     when to start that drag, default 0.5
##   --arm-at=<seconds>      ignore --freeze-on before this time
##   --esc-at=<seconds>      send Escape once, at this time
##   --back-at=<seconds>     fire NOTIFICATION_WM_GO_BACK_REQUEST exactly the
##                           way SceneTree does when Android Back is pressed
##   --tap=<seconds>:<key>   tap a key once at that time; repeatable. Keys are
##                           esc, enter, up, down, left, right, tab, v, and the
##                           two chords shift-left / shift-right. The chords
##                           exist because the strand's move is `Shift`+arrow
##                           read as a **raw** key -- a content pack cannot add
##                           an InputMap action -- so nothing else in this
##                           harness could reach it.
##   --touch=<seconds>:<x>,<y>
##                           press and release one finger at that canvas point;
##                           repeatable. This is how the genome strip's two-tap
##                           arming gets exercised on the input path a phone
##                           actually uses. Coordinates are in canvas units, not
##                           window pixels -- but note the canvas is only 1280
##                           wide at 16:9: `expand` keeps the height at 720 and
##                           widens it, so at 2400x1080 the canvas is 1600 across
##                           and a centred widget is 160 further right.
##                           **Do not pre-scale.** This applies the stretch
##                           transform itself, because the event goes in through
##                           `Input.parse_input_event`, which wants window
##                           pixels -- unlike --hover= below, which does not.
##                           Scaling a coordinate before passing it here puts
##                           the finger 1.5x too far out at 2400x1080 and
##                           produces a tap on nothing, which reads as a
##                           control that does not respond. It has cost one
##                           false bug report already.
##   --press=<seconds>:<x>,<y>[,<finger>]
##                           one finger down at that canvas point and **left
##                           there** -- never released. `finger` is the touch
##                           index and defaults to 0; a second one is the only
##                           way to pose two controls held at once, which is
##                           exactly what `pads` exists for -- `port` and `push`
##                           together, or a dash fired while the stick is over. `--touch=` presses and
##                           releases in the same frame, and a tap commits
##                           nothing by design, so the one rule the choosing
##                           screen turns on -- *a finger resting on a locus is
##                           a read and not a lean* -- cannot be posed with it
##                           at all. Same convention as `--touch=`: seconds
##                           first, canvas coordinates, unscaled.
##   --slide=<seconds>:<x>,<y>[,<finger>]
##                           that finger moves there, as an `InputEventScreenDrag`
##                           with no fresh press. A resting thumb produces one
##                           the moment it shifts by a pixel, which is the case
##                           a press alone cannot pose and the one that decides
##                           whether reading a locus can commit a daughter.
##                           Repeatable, and the same convention again.
##                           **It carries `relative`, and that is
##                           load-bearing.** Godot emulates a mouse motion
##                           from every screen
##                           drag and copies `relative` across unchanged; the
##                           GUI's drag machinery accumulates exactly that, and
##                           `_get_drag_data` is only called once ten pixels
##                           have piled up. Left at zero -- which is what this
##                           sent for its first three phases -- no drag ever
##                           starts, and Godot's own drag-and-drop path looks
##                           dead on touch when it is not.
##   --lift=<seconds>[:<finger>]
##                         release that finger, wherever `--press=` and `--slide=`
##                           have left it. The other half of `--press=`: without
##                           it the harness can only pose gestures that never
##                           end, and *letting go undoes a lean* is a rule the
##                           division screen turns on as hard as the other one.
##   --mouse-press=<seconds>:<x>,<y>
##   --mouse-slide=<seconds>:<x>,<y>
##   --mouse-lift=<seconds>
##                           the same three gestures on the **desktop** path:
##                           left button down and held, the cursor moved with it
##                           still down, and the button released. Canvas
##                           coordinates, unscaled, exactly like --press=.
##                           They exist because the mouse has the same hole the
##                           touch path had -- Godot hit-tests a motion event
##                           whenever no control captured the button -- so
##                           "desktop still works" was a sentence nothing in
##                           this harness could check. --hover= cannot: it warps
##                           the cursor with no button held, which is the one
##                           case that was never broken.
##   --hover=<seconds>:<x>,<y>
##                           warp the mouse to that canvas point, once, at that
##                           time; repeatable. The desktop half of the genome
##                           strip -- point at a tile and read what the gene
##                           does -- has no touch equivalent and therefore no
##                           other way to be photographed. **Canvas units go in
##                           unscaled**, the same as --touch= above and for the
##                           opposite reason: `Viewport.warp_mouse` applies the
##                           stretch transform on the way in, so this one must
##                           not. Either way the number you write is the canvas
##                           coordinate and nothing else.
##   --sample=<gene>         put a gene in the genome's held sample, the state
##                           §3.3 gives a second heartbeat and §5.2 gives the
##                           strip. Reaching it by playing means eating a fourth
##                           gene with a full genome, which is fourteen minutes
##                           and a lot of luck.
##   --sample-left=<secs>    how many of the forty-five seconds that sample has
##                           left, held there, so early, mid-clock and about to
##                           lapse are three photographs instead of one taken
##                           three times. Default is the whole SAMPLE_SECONDS.
##   --wound=<0..1>          hold the player's body at that much damage. Bodies
##                           knit up every frame, so a wound cannot be posed by
##                           setting it once.
##   --freeze-on=<kind>      pause the tree a few frames after this sensation,
##                           so a flash or a beat can be caught at its peak
##   --freeze-delay=<n>      how many frames after it, default 2
##   --freeze-after=<secs>   seconds after it instead of frames, which is the
##                           only frame-rate-independent way to catch an
##                           envelope at its peak
##   --freeze-at=<seconds>   pause the tree at this time
##   --hunger=<0..1>         force the cell's hunger, to photograph what the
##                           starvation floor actually leaves on screen
##   --starve=<seconds>      seconds already spent at full hunger, so the end of
##                           the forty-second grace can be reached in one frame
##   --stalk=<units>         park a hunting cell this far off the cell's front
##                           quarter and hold it there, so dread, a wake and a
##                           lunge can each be photographed at a known range
##   --stalk-at=<deg>        the body-relative bearing --stalk and --hunt park
##                           it on, default 40. 180 is directly astern, which is
##                           where "it ate me with its tail" used to happen
##   --stalk-face=<deg>      force that hunter's heading every frame, as degrees
##                           away from facing the player: 0 is nose-on, 180 is
##                           pointed directly away. Unset leaves it to swim. The
##                           only way to hold a mouth off its target while the
##                           bodies are in contact, which is the whole of the
##                           directional-mouth measurement
##   --food-at=<units>       same, for field cell 1, left drifting. Cell 0 is
##                           what --stalk and --hunt pose, so the two handles
##                           can be used together to frame both halves of the
##                           gape rule in one photograph
##   --gain=<0.7..2.4>       hold membrane sensitivity here, to photograph what
##                           the pause screen's light slider actually buys
##   --hunt=<units>          put a cell that can eat you this far off, once, and
##                           then let it hunt for itself. This is how the
##                           escape-window contract in the design doc gets
##                           measured, since it is made of time and cannot be
##                           photographed.
##   --prey-radius=<r>       give field cell 1 this body radius and a real
##                           genome, so the other half of the gape rule -- a
##                           cell near your own size that you can swallow -- can
##                           be set up on purpose instead of waited for
##   --hunter-gape=<mult>    the hunter's gape as a multiple of your radius,
##                           default 1.40. Below 0.85 it cannot eat you at all
##                           and below 1.35 dread lands part-way up the curve,
##                           which is how the continuity of §7.0 gets shown.
##   --radius=<r>            force the player's body radius, which is the slot
##                           ladder, the gape and the whole of what the water
##                           seeds around you. r40 is where section 3.1 says the
##                           run is won
##   --cell=i,dist,bearing,radius[,gene:tier+gene:tier[,facing]]
##                           park field cell i at that range and body-relative
##                           bearing, with that body and that genome, and hold
##                           it there. Repeatable, and the only way to frame
##                           section 1.1's four relationships in one photograph:
##                           `eat it`, `it eats me`, `both` and `neither` are a
##                           pair of gapes, and waiting for the water to seed
##                           all four at a readable distance is not a test, it
##                           is a lottery. Genes are separated by `+` because a
##                           comma is already the field separator. `facing` is
##                           degrees away from facing the player, default 0:
##                           180 turns its mouth away, which is what proves a
##                           mouth has to be pointed at you to reach you
##   --dna=<g:t[:slot],...>  force the player's DNA only, leaving the body it is
##                           wearing alone. That is the state a cell reaches by
##                           eating -- lifecycle.md §1 -- and the one the pause
##                           strip's three pip states exist to show, so it is the
##                           only way to photograph them without playing a whole
##                           generation. Applied after --genome=.
##   --genome=<g:t[:slot],...>
##                           force the player's genome, e.g.
##                           cytostome:3,cirrus:3,flagellum:3. This is the only
##                           way to reach a tier-3 cell without playing for
##                           fifteen minutes. A third field is the **slot**, and
##                           the slot is the arc the organ is worn on: 0 nose,
##                           1 starboard flank, 2 astern, 3 and 4 the forward
##                           diagonals, 5 and 6 the rear ones. That is how a
##                           beam gets aimed.
##   --check-seeding=<n>     reseed the field n times and print what §1.3's
##                           distribution actually produces, including whether
##                           the drifter floor ever fails. Quits when done.
##   --trace=<seconds>       print the field, dread, threat and the player's
##                           realised speed on that interval
##   --locked                turn the world with the cell, so forward is always
##                           up. The pause screen's camera toggle, reached
##                           without a tap and without writing the choice to
##                           user:// where the next run would inherit it.
##   --forage                steer up the taste gradient, to measure §3.3's
##                           "a meal every 60 to 90 seconds" without a human.
##                           **Needs a nose.** Taste went behind `chemocyte`, so
##                           a forced genome without one has no bearing to climb
##                           and this steers straight: pass
##                           `--genome=cytostome:1,cirrus:1,flagellum:1` and let
##                           the five-second grant land, or force `chemocyte:1`
##   --evade                 play the escape contract in §5.4: hold full steer
##                           while the last wake bearing is ahead, release once
##                           it is astern, and do not waver. This is the only
##                           way to test a window that is made of time.
##   --kill-at=<seconds>     starve the cell to death at that time, so the death
##                           screen, the `watch` offer and the replay itself can
##                           each be photographed without waiting seven minutes
##                           for hunger or gambling on a hunter
##   --panes=<seconds>       raise the two-pane replay screen over the live run
##                           at that time, mirroring it frame for frame. The
##                           split screen is the part of docs/design/replay.md
##                           that had to be rendered rather than reasoned about
##                           (§5), and this is how it gets photographed before
##                           there is a recorder to feed it
##   --capture-cost=<secs>   print the recorder's rolling maximum microseconds
##                           per capture() on that interval. §4.6 asks for a
##                           measurement and refuses to accept the estimate
##   --rects=<seconds>       print `get_global_rect()` for the pause column and
##                           each of its groups, once, at that time. The column
##                           is the one thing in this game measured in canvas
##                           pixels rather than judged by eye -- docs/design/
##                           moving-a-gene.md section 6 -- and a render cannot
##                           show the rect of a container that draws nothing
##   --controls=<seconds>    print what the drawn controls are being told to do
##                           on that interval: which of them is held, by which
##                           pointer, the steer they derive and whether they are
##                           asking for thrust. The pads and the stick have no
##                           other output -- `axoneme` thrust is a velocity add
##                           and never reaches the bus -- so this is the only
##                           way to check two fingers at once from a log
##   --seed=<int>            deterministic drift and impulses
##
## Prints every sensation the membrane bus receives with its timestamp, which is
## how the event bus gets checked end to end. Lives in tools/, which the export
## presets exclude, so none of this ships.
##
## **Driving the game as far as `leave` changes scenes**, and a scene change
## frees whatever `SceneTree.current_scene` points at. `tools/shot.gd` hands
## `current_scene` to the scene it instantiates for exactly this reason; without
## that it would be the harness that gets freed, mid-await, and the run would
## hang rather than fail. If a run of this driver ever stops producing output
## and never exits, that is the shape of the fault -- and `--quit-after <n>` on
## the engine, before the `--`, bounds it whatever happens.

const DEFAULT_SCENE := "res://game/normal/normal_mode.tscn"
const FoodField := preload("res://game/normal/food.gd")
const CellBody := preload("res://game/normal/cell.gd")
## Only for [method Cilia.mouth_gap], which is how far a mouth is from a body.
## The measurement the directional-contact fix has to be judged on, and it
## cannot be judged by eye: two bodies overlapping tells you nothing about
## whether either mouth is on the other.
const Cilia := preload("res://game/vision/cilia.gd")
## The two-pane screen, raised over a live run by --panes. Nothing else in the
## game instances it this way; the replay screen owns it in a real run.
const PanesScreen := preload("res://game/replay/panes.gd")

var _clock := 0.0
## Where each finger was last put, so a slide can carry the `relative` the
## GUI's drag threshold is accumulated from. See [method _send_slide]. Keyed by
## touch index: one entry is the common case and two is what proves `pads`.
var _finger_was: Dictionary = {}
var _esc_at := -1.0
var _esc_sent := false
var _back_at := -1.0
## [[seconds, keycode], ...], consumed as the clock passes each one.
var _taps: Array = []
var _freeze_at := -1.0
var _freeze_on := ""
var _freeze_countdown := -1
var _freeze_delay := 2
var _freeze_after := -1.0
var _bus: Node = null
var _run: Node = null
var _metabolism: Node = null
var _genome: Node = null
var _food: Node = null
var _hunger := -1.0
var _starve := -1.0
var _stalk := -1.0
var _stalk_at := 40.0
## Degrees away from facing the player, or NAN to leave its heading alone.
var _stalk_face := NAN
var _food_at := -1.0
var _gain := -1.0
var _hunt := -1.0
var _trace := -1.0
var _trace_clock := 0.0
## Which control scheme to force, or -1 to take whatever user:// remembers.
var _scheme := -1
var _hunter_gape := 1.40
var _prey_radius := -1.0
var _radius := -1.0
var _genome_spec := ""
var _dna_spec := ""
var _check_seeding := 0
## [[index, distance, bearing_deg, radius, {gene: tier}], ...] from --cell=.
var _posed: Array = []
## [[seconds, canvas position], ...], consumed as the clock passes each one.
var _touches: Array = []
## The same, for the mouse: [[seconds, canvas position], ...].
var _hovers: Array = []
## [[seconds, canvas position], ...] pressed and held, never released -- the
## only way to photograph a finger resting somewhere.
var _presses: Array = []
## [[seconds, canvas position], ...] sent as a drag on finger 0.
var _slides: Array = []
## [[seconds, finger], ...] at which a finger lets go, wherever it has got to.
var _lifts: Array = []
## How often to print the drawn controls' own state, or -1 for never.
var _controls_trace := -1.0
var _controls_clock := 0.0
## When to print the pause column's rects, or -1 for never.
var _rects_at := -1.0
## The desktop three, same shapes: press and hold the left button, move with it
## down, let go.
var _mouse_presses: Array = []
var _mouse_slides: Array = []
var _mouse_lifts: Array = []
## Where each finger was last put, so a release can be sent from the same point
## -- a release at the wrong place is a different gesture.
var _finger: Dictionary = {}
## The same, for the cursor.
var _cursor := Vector2.ZERO
var _sample: StringName = &""
var _sample_left := -1.0
var _wound := -1.0
## Cumulative meals eaten by one field cell off another, which is the one thing
## in section 1.3 that has to be observed rather than argued about. Field cells
## are recycled, so this is accumulated by watching each slot's serial.
var _field_meals := 0
var _watch_serial := PackedInt32Array()
var _watch_meals := PackedInt32Array()
## Seconds to wait before reporting where a cell that just fed ended up.
const AFTER_MEAL_LOOK := 6.0
var _after_meal: Array = []
var _dread_seconds := 0.0
var _dread_area := 0.0
var _run_seconds := 0.0
var _travelled := 0.0
var _last_pos := Vector2.ZERO
var _have_last_pos := false
var _speed_clock := 0.0
var _evade := false
var _locked := false
## World angle of the last wake, so the body-relative bearing can be recomputed
## as the cell turns instead of going stale the moment it does.
var _wake_world := 0.0
var _have_wake := false
var _evade_key := KEY_NONE
var _forage := false
var _taste_bearing := 0.0
var _taste_c := 0.0
var _forage_key := KEY_NONE
var _meals := 0
var _drag_px := 0.0
var _drag_at := 0.5
var _drag_step := 0
## The freeze-on trigger ignores sensations before this time, so a later beat
## can be caught instead of the first one.
var _arm_at := 0.0
## -1 leaves the scene to pick up whatever the mode select last stored.
var _mode := -1
## When to starve the cell to death, for photographing what happens next.
var _kill_at := -1.0
## When to raise the two-pane screen over the live run, and the node once it is.
var _panes_at := -1.0
var _panes: Node = null
## How often to print what capture() costs, and the recorder it is asking.
var _capture_cost := -1.0
var _capture_clock := 0.0
var _recorder: Node = null


func _ready() -> void:
	# The game pauses the tree; the driver has to keep running through it or it
	# could never press anything on a pause screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# And it has to run *after* the game, so that anything it holds in place --
	# a parked hunter, a forced hunger -- survives the frame it set it in.
	process_priority = 1000

	var scene_path := DEFAULT_SCENE
	var hold := ""
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--play="):
			scene_path = text.trim_prefix("--play=")
		elif text.begins_with("--hold="):
			hold = text.trim_prefix("--hold=").to_lower()
		elif text.begins_with("--drag="):
			_drag_px = float(text.trim_prefix("--drag="))
		elif text.begins_with("--drag-at="):
			_drag_at = float(text.trim_prefix("--drag-at="))
		elif text.begins_with("--arm-at="):
			_arm_at = float(text.trim_prefix("--arm-at="))
		elif text.begins_with("--esc-at="):
			_esc_at = float(text.trim_prefix("--esc-at="))
		elif text.begins_with("--back-at="):
			_back_at = float(text.trim_prefix("--back-at="))
		elif text.begins_with("--tap="):
			var parts := text.trim_prefix("--tap=").split(":")
			if parts.size() == 2:
				_taps.append([float(parts[0]), _keycode(parts[1])])
		elif text.begins_with("--freeze-at="):
			_freeze_at = float(text.trim_prefix("--freeze-at="))
		elif text.begins_with("--freeze-on="):
			_freeze_on = text.trim_prefix("--freeze-on=")
		elif text.begins_with("--freeze-delay="):
			_freeze_delay = int(text.trim_prefix("--freeze-delay="))
		elif text.begins_with("--freeze-after="):
			_freeze_after = float(text.trim_prefix("--freeze-after="))
		elif text.begins_with("--mode="):
			_mode = int(text.trim_prefix("--mode="))
		elif text.begins_with("--scheme="):
			_scheme = int(text.trim_prefix("--scheme="))
		elif text.begins_with("--hunger="):
			_hunger = float(text.trim_prefix("--hunger="))
		elif text.begins_with("--starve="):
			_starve = float(text.trim_prefix("--starve="))
		elif text.begins_with("--stalk="):
			_stalk = float(text.trim_prefix("--stalk="))
		elif text.begins_with("--stalk-at="):
			_stalk_at = float(text.trim_prefix("--stalk-at="))
		elif text.begins_with("--stalk-face="):
			_stalk_face = float(text.trim_prefix("--stalk-face="))
		elif text.begins_with("--food-at="):
			_food_at = float(text.trim_prefix("--food-at="))
		elif text.begins_with("--gain="):
			_gain = float(text.trim_prefix("--gain="))
		elif text.begins_with("--hunt="):
			_hunt = float(text.trim_prefix("--hunt="))
		elif text.begins_with("--trace="):
			_trace = float(text.trim_prefix("--trace="))
		elif text.begins_with("--prey-radius="):
			_prey_radius = float(text.trim_prefix("--prey-radius="))
		elif text.begins_with("--hunter-gape="):
			_hunter_gape = float(text.trim_prefix("--hunter-gape="))
		elif text.begins_with("--radius="):
			_radius = float(text.trim_prefix("--radius="))
		elif text.begins_with("--genome="):
			_genome_spec = text.trim_prefix("--genome=")
		elif text.begins_with("--dna="):
			_dna_spec = text.trim_prefix("--dna=")
		elif text.begins_with("--check-seeding="):
			_check_seeding = int(text.trim_prefix("--check-seeding="))
		elif text.begins_with("--cell="):
			_posed.append(_parse_pose(text.trim_prefix("--cell=")))
		elif text.begins_with("--sample-left="):
			_sample_left = float(text.trim_prefix("--sample-left="))
		elif text.begins_with("--sample="):
			_sample = StringName(text.trim_prefix("--sample="))
		elif text.begins_with("--wound="):
			_wound = float(text.trim_prefix("--wound="))
		elif text.begins_with("--hover="):
			var hover := text.trim_prefix("--hover=").split(":")
			if hover.size() == 2:
				var at := hover[1].split(",")
				if at.size() == 2:
					_hovers.append([float(hover[0]),
						Vector2(float(at[0]), float(at[1]))])
		elif text.begins_with("--touch="):
			var touch := text.trim_prefix("--touch=").split(":")
			if touch.size() == 2:
				var xy := touch[1].split(",")
				if xy.size() == 2:
					_touches.append([float(touch[0]),
						Vector2(float(xy[0]), float(xy[1]))])
		elif text.begins_with("--press="):
			var press := text.trim_prefix("--press=").split(":")
			if press.size() == 2:
				var pxy := press[1].split(",")
				if pxy.size() >= 2:
					_presses.append([float(press[0]),
						Vector2(float(pxy[0]), float(pxy[1])),
						int(pxy[2]) if pxy.size() > 2 else 0])
		elif text.begins_with("--slide="):
			var slide := text.trim_prefix("--slide=").split(":")
			if slide.size() == 2:
				var sxy := slide[1].split(",")
				if sxy.size() >= 2:
					_slides.append([float(slide[0]),
						Vector2(float(sxy[0]), float(sxy[1])),
						int(sxy[2]) if sxy.size() > 2 else 0])
		elif text.begins_with("--lift="):
			var lift := text.trim_prefix("--lift=").split(":")
			_lifts.append([float(lift[0]),
				int(lift[1]) if lift.size() > 1 else 0])
		elif text.begins_with("--controls="):
			_controls_trace = float(text.trim_prefix("--controls="))
		elif text.begins_with("--rects="):
			_rects_at = float(text.trim_prefix("--rects="))
		elif text.begins_with("--mouse-press="):
			var mpress := text.trim_prefix("--mouse-press=").split(":")
			if mpress.size() == 2:
				var mpxy := mpress[1].split(",")
				if mpxy.size() == 2:
					_mouse_presses.append([float(mpress[0]),
						Vector2(float(mpxy[0]), float(mpxy[1]))])
		elif text.begins_with("--mouse-slide="):
			var mslide := text.trim_prefix("--mouse-slide=").split(":")
			if mslide.size() == 2:
				var msxy := mslide[1].split(",")
				if msxy.size() == 2:
					_mouse_slides.append([float(mslide[0]),
						Vector2(float(msxy[0]), float(msxy[1]))])
		elif text.begins_with("--mouse-lift="):
			_mouse_lifts.append(float(text.trim_prefix("--mouse-lift=")))
		elif text.begins_with("--kill-at="):
			_kill_at = float(text.trim_prefix("--kill-at="))
		elif text.begins_with("--panes="):
			_panes_at = float(text.trim_prefix("--panes="))
		elif text.begins_with("--capture-cost="):
			_capture_cost = float(text.trim_prefix("--capture-cost="))
		elif text == "--locked":
			_locked = true
		elif text == "--evade":
			_evade = true
		elif text == "--forage":
			_forage = true
		elif text.begins_with("--seed="):
			seed(int(text.trim_prefix("--seed=")))

	if not ResourceLoader.exists(scene_path):
		push_error("[drive] no scene at %s" % scene_path)
		get_tree().quit(1)
		return
	var scene: PackedScene = load(scene_path)
	var run := scene.instantiate()
	if _mode >= 0:
		# Set before the scene enters the tree, which is where it is read.
		run.set("mode", _mode)
		print("[drive] mode forced to ", _mode)
	if _scheme >= 0:
		# Same, and for a sharper reason: the scheme is remembered in user://,
		# so cycling the pause button to photograph one would leave it behind.
		run.set("scheme", _scheme)
		print("[drive] scheme forced to ", _scheme)
	add_child(run)
	_run = run
	_metabolism = _find_script(self, "res://game/normal/metabolism.gd")
	_genome = _find_script(self, "res://game/normal/genome.gd")
	_food = _find_script(self, "res://game/normal/food.gd")

	if _radius > 0.0:
		var body := _find_node_with(self, &"bearing_to")
		if body != null:
			body.radius = _radius
			# The water is seeded around the player's radius, so it has to be
			# seeded again once that has been forced.
			if _food != null:
				_food.setup(body)
			print("[drive] radius forced to %.1f -> %d slots" % [
				_radius, body.slots()])
	if _genome_spec != "" and _genome != null:
		_force_genome(_genome_spec)
	if _dna_spec != "" and _genome != null:
		_force_dna(_dna_spec)
	if _sample != &"" and _genome != null:
		_genome.held_sample = _sample
		_genome.held_remaining = _genome.SAMPLE_SECONDS
		print("[drive] holding a sample of ", _sample)
	if _check_seeding > 0:
		_run_seeding_check(_check_seeding)
		get_tree().quit(0)
		return

	if _food != null:
		_food.eaten.connect(_on_meal)

	_bus = _find_bus(self)
	if _bus != null:
		_bus.sensation.connect(_on_sensation)
	else:
		print("[drive] no membrane bus found under ", scene_path)

	if _hunger >= 0.0 and _metabolism != null:
		_metabolism.set_hunger(_hunger)
		if _starve >= 0.0:
			_metabolism.starve_seconds = _starve
		print("[drive] hunger forced to %.2f -> beat %.2fs at %.2f strength" % [
			_hunger, _metabolism.beat_period(), _metabolism.beat_amplitude()])

	if _stalk >= 0.0 and _food != null:
		_make_hunter(0, _hold_point(_stalk, _stalk_at))
		# Before the first frame, not after it: _make_hunter points the mouth at
		# the player, and the game's own _process runs ahead of this node's, so
		# a hunter turned away only in _hold_world has already had one frame
		# nose-on -- which at contact range is one frame too many.
		_face(0, _stalk_face)
		print("[drive] hunter parked at %.0f units, bearing %+.0f deg, facing %s" % [
			_stalk, _stalk_at,
			"as it likes" if is_nan(_stalk_face) else "%+.0f deg off you" % _stalk_face])
	if _hunt >= 0.0 and _food != null:
		_make_hunter(0, _hold_point(_hunt, _stalk_at))
		_face(0, _stalk_face)
		print("[drive] hunter released from %.0f units" % _hunt)
	if _prey_radius > 0.0 and _food != null:
		var bodies: Array = _food.get("_cells")
		if bodies.size() > 1:
			bodies[1].set("radius", _prey_radius)
			bodies[1].set("drifter", false)
			bodies[1].set("genome", {&"cytostome": 1, &"cirrus": 2})
			print("[drive] field cell 1 forced to r%.1f gape %.1f" % [
				_prey_radius, _food.gape_at(1)])
	if _food_at >= 0.0 and _food != null:
		print("[drive] field cell 1 parked at %.0f units" % _food_at)
	_apply_poses(true)

	if _locked:
		var view := _find_node_with(self, &"set_camera_locked")
		if view != null:
			view.call(&"set_camera_locked", true)
			print("[drive] camera locked: forward is up")

	# `w` is `axoneme`: hold to push. The steer keys are the other two.
	var held := _keycode(hold) if hold == "w" else KEY_NONE
	if hold == "a" or hold == "d":
		held = KEY_A if hold == "a" else KEY_D
	if held != KEY_NONE:
		_send_key(held, true)
		print("[drive] holding ", hold.to_upper())


## Ground truth about a meal, straight off the field: what it weighed against
## this body, which gene came out of it, and what that did to the genome. The
## bus is deliberately not told the first two, so this is the only place they
## can be checked.
func _on_meal(nutrition: float, gene: StringName, _at: Vector2) -> void:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	# **The DNA, not the body.** A meal writes what your daughters will be and
	# leaves the organism it went into alone (lifecycle.md §1), so printing the
	# body here would show a genome that never changes however much you eat.
	print("[meal]  %5.2f  nutrition %.2f of one meal (%.2f hunger)  gene %s -> dna %s  me r%.2f gape %.2f" % [
		_clock, nutrition, 0.5 * nutrition, gene if gene != &"" else &"none",
		_genome_text(_genome.dna() if _genome != null else {}),
		cell.radius if cell != null else 0.0, cell.gape() if cell != null else 0.0])


func _process(delta: float) -> void:
	_clock += delta
	_hold_world()
	_watch_field(delta)
	_step_forage()
	_step_evade()
	_step_trace(delta)
	_step_controls(delta)
	_step_rects()
	_step_kill()
	_step_panes()
	_step_capture_cost(delta)

	if _freeze_countdown > 0:
		_freeze_countdown -= 1
		if _freeze_countdown == 0:
			_freeze()

	if _esc_at >= 0.0 and not _esc_sent and _clock >= _esc_at:
		_esc_sent = true
		_send_key(KEY_ESCAPE, true)
		_send_key(KEY_ESCAPE, false)
		print("[drive] %5.2f  esc" % _clock)

	for i in range(_taps.size() - 1, -1, -1):
		if _clock >= float(_taps[i][0]):
			var code: Key = _taps[i][1]
			_send_key(code, true)
			_send_key(code, false)
			print("[drive] %5.2f  tap %d" % [_clock, code])
			_taps.remove_at(i)

	for i in range(_touches.size() - 1, -1, -1):
		if _clock >= float(_touches[i][0]):
			_send_touch(_touches[i][1])
			_touches.remove_at(i)

	for i in range(_hovers.size() - 1, -1, -1):
		if _clock >= float(_hovers[i][0]):
			_send_hover(_hovers[i][1])
			_hovers.remove_at(i)
	for i in range(_presses.size() - 1, -1, -1):
		if _clock >= float(_presses[i][0]):
			_send_press(_presses[i][1], int(_presses[i][2]))
			_presses.remove_at(i)
	for i in range(_slides.size() - 1, -1, -1):
		if _clock >= float(_slides[i][0]):
			_send_slide(_slides[i][1], int(_slides[i][2]))
			_slides.remove_at(i)
	for i in range(_lifts.size() - 1, -1, -1):
		if _clock >= float(_lifts[i][0]):
			_send_lift(int(_lifts[i][1]))
			_lifts.remove_at(i)
	for i in range(_mouse_presses.size() - 1, -1, -1):
		if _clock >= float(_mouse_presses[i][0]):
			_send_mouse_button(_mouse_presses[i][1], true)
			_mouse_presses.remove_at(i)
	for i in range(_mouse_slides.size() - 1, -1, -1):
		if _clock >= float(_mouse_slides[i][0]):
			_send_mouse_slide(_mouse_slides[i][1])
			_mouse_slides.remove_at(i)
	for i in range(_mouse_lifts.size() - 1, -1, -1):
		if _clock >= float(_mouse_lifts[i]):
			_send_mouse_button(_cursor, false)
			_mouse_lifts.remove_at(i)

	if _back_at >= 0.0 and _clock >= _back_at:
		_back_at = -1.0
		print("[drive] %5.2f  back (quit_on_go_back=%s)" % [
			_clock, get_tree().quit_on_go_back])
		get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)

	if _drag_px != 0.0 and _clock >= _drag_at:
		_step_drag()

	if _freeze_at >= 0.0 and _clock >= _freeze_at:
		_freeze_at = -1.0
		_freeze()


## Straight to the end of the forty-second grace, which is a death this frame.
func _step_kill() -> void:
	if _kill_at < 0.0 or _clock < _kill_at or _metabolism == null:
		return
	_kill_at = -1.0
	_metabolism.set_hunger(1.0)
	_metabolism.starve_seconds = _metabolism.STARVE_GRACE + 1.0
	print("[drive] %5.2f  starved" % _clock)


## **The two panes, over a run that is still being played.** Not the replay --
## there is no recording involved and nothing is being played back -- but the
## same screen, built from the same four shipped views, so that the geometry,
## the clipping and the membrane at 640x632 can be looked at. §5's last bullet.
func _step_panes() -> void:
	if _panes_at < 0.0 or _clock < _panes_at or _run == null:
		return
	_panes_at = -1.0
	_panes = PanesScreen.new()
	_panes.name = "Panes"
	_panes.live = true
	_run.add_child(_panes)
	print("[drive] %5.2f  panes raised over the live run" % _clock)


## What one capture() costs, as a rolling maximum in microseconds. §4.6.
func _step_capture_cost(delta: float) -> void:
	if _capture_cost <= 0.0:
		return
	if _recorder == null:
		_recorder = _find_script(self, "res://game/replay/recorder.gd")
		if _recorder == null:
			_capture_cost = -1.0
			print("[capture] no recorder in this build")
			return
	_capture_clock += delta
	if _capture_clock < _capture_cost:
		return
	_capture_clock = 0.0
	print("[capture] %6.2f  frames %d  peak %d us  last %d us  mean %.1f us" % [
		_clock, _recorder.frames(), _recorder.peak_usec, _recorder.last_usec,
		_recorder.mean_usec()])


## Turn until the taste sits at the top. The dumbest possible forager, which is
## the point: if this cannot feed itself the field is too thin for a person.
func _step_forage() -> void:
	if not _forage:
		return
	# Evading wins. A hunted cell cannot smell its way out of the problem, and
	# it should not try to eat its way out either.
	var want := KEY_NONE
	if _evade_key == KEY_NONE and _taste_c > 0.06 and absf(_taste_bearing) > 0.15:
		want = KEY_D if _taste_bearing > 0.0 else KEY_A
	if want == _forage_key:
		return
	if _forage_key != KEY_NONE:
		_send_key(_forage_key, false)
	if want != KEY_NONE:
		_send_key(want, true)
	_forage_key = want


## Commit away from the wake and stay committed. Turns until the threat is 130
## degrees off the nose, then holds course until it drifts back inside 100 --
## the hysteresis is what "does not waver" means, and wavering is what §5.4 says
## actually costs players the window.
func _step_evade() -> void:
	if not _evade or not _have_wake or _run == null:
		return
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null:
		return
	var rel: float = angle_difference(cell.heading, _wake_world)
	var want := KEY_NONE
	if _evade_key != KEY_NONE:
		if absf(rel) < deg_to_rad(130.0):
			want = _evade_key
	elif absf(rel) < deg_to_rad(100.0):
		# Wake to starboard: turn to port, and the other way round.
		want = KEY_A if rel > 0.0 else KEY_D
	if want == _evade_key:
		return
	if _evade_key != KEY_NONE:
		_send_key(_evade_key, false)
	if want != KEY_NONE:
		_send_key(want, true)
		print("[drive] %5.2f  evade %s (threat %+6.1f deg)" % [
			_clock, "port" if want == KEY_A else "starboard", rad_to_deg(rel)])
	else:
		print("[drive] %5.2f  evade committed (threat %+6.1f deg)" % [
			_clock, rad_to_deg(rel)])
	_evade_key = want


## Everything the simulation half of Phase 5 has to be judged on, once every
## [param --trace] seconds: what the player is, what the water is, who is
## hunting whom and how hard the water is leaning on the membrane.
## What §2.1's three mappings are actually worth right now, read straight off
## the lobes the bus has composed rather than off a photograph.
##
## The thrust bloom and the turn shear share `glow_lobes[0]` -- the loudest
## thing happening to your own skin is the thing you feel -- so a still frame
## cannot separate "the bloom got louder" from "the beat happened to land". The
## uniform can, exactly, which is the only honest way to check a table whose
## whole claim is that three numbers move with a tier.
##
## Reaching for a private member is a thing only tools/ is allowed to do.
func _membrane_text() -> String:
	if _bus == null:
		return "membrane: no bus"
	# Untyped on purpose: get() on a member that has been renamed returns null,
	# and a typed local would turn a stale harness into a crash rather than a
	# line of text saying the harness is stale.
	var raw_lobes: Variant = _bus.get("_glow_lobes")
	var raw_organs: Variant = _bus.get("_organs")
	if not (raw_lobes is PackedVector4Array) or not (raw_organs is PackedInt32Array):
		return "membrane: unavailable"
	var lobes: PackedVector4Array = raw_lobes
	var organs: PackedInt32Array = raw_organs
	if lobes.size() < 3 or organs.size() < 4:
		return "membrane: unavailable"
	var me: Vector4 = lobes[0]
	var light: Vector4 = lobes[2]
	return ("membrane: organs cyt%d cir%d fla%d sti%d  self lobe %.3f at %4.0f deg wide"
		+ "  light %.3f at %4.0f deg wide  flood decay %.1fs") % [
		organs[0], organs[1], organs[2], organs[3],
		me.w, rad_to_deg(acos(clampf(me.z, -1.0, 1.0))),
		light.w, rad_to_deg(acos(clampf(light.z, -1.0, 1.0))),
		_bus.INGEST_DECAY_BY_TIER[organs[0]]]


func _step_trace(delta: float) -> void:
	if _trace <= 0.0 or _food == null or _run == null:
		return
	_trace_clock += delta
	if _trace_clock < _trace:
		return
	_trace_clock = 0.0
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null:
		return

	var hunter: int = _food.hunter()
	var range_text := "     --"
	if hunter >= 0:
		range_text = "%7.1f" % _food.points()[hunter].distance_to(cell.position)
	var speed := _travelled / maxf(_speed_clock, 0.001)
	_travelled = 0.0
	_speed_clock = 0.0
	print("[trace] %6.2f  me r%5.2f gape %5.2f wound %4.2f %s swim %5.1f (real %5.1f) body %s dna %s" % [
		_clock, cell.radius, cell.gape(), cell.wound,
		"alive" if _metabolism != null and _metabolism.is_processing() else " DEAD",
		cell.swim_speed(), speed,
		_genome_text(_genome.tiers() if _genome != null else {}),
		_genome_text(_genome.dna() if _genome != null else {})])
	print("        %s" % _membrane_text())
	print("        dread %.3f  threat %.3f  hunter %s  range %s  upkeep %.2f  hunger %.2f  field meals %d  dread duty %.0f%% mean %.2f" % [
		_food.dread_level, _food.threat,
		"none" if hunter < 0 else str(hunter), range_text,
		_metabolism.upkeep if _metabolism != null else 1.0,
		_metabolism.hunger if _metabolism != null else 0.0, _field_meals,
		100.0 * _dread_seconds / maxf(_run_seconds, 0.001),
		_dread_area / maxf(_run_seconds, 0.001)])
	for i in _food.points().size():
		print("        cell %d  %s" % [i, _field_text(i, cell)])


## The pause column, in canvas pixels. Containers draw nothing, so their extent
## cannot be read off a frame -- and the column is the one surface in this game
## whose fit is a measurement rather than a judgement.
func _step_rects() -> void:
	if _rects_at < 0.0 or _clock < _rects_at or _run == null:
		return
	_rects_at = -1.0
	var base := "Hud/Pause/Center/Buttons"
	var paths := {
		"Buttons": base,
		"Genome": base + "/Genome",
		"Settings": base + "/Settings",
		"Light": base + "/Settings/Light",
		"View": base + "/Settings/View",
		"Feel": base + "/Settings/Feel",
		"Resume": base + "/Resume",
		"Leave": base + "/Leave",
	}
	for name: String in paths:
		var node := _run.get_node_or_null(paths[name])
		if node == null:
			print("[rect]  %-9s absent" % name)
			continue
		var r: Rect2 = node.get_global_rect()
		print("[rect]  %-9s x %7.1f .. %7.1f (w %6.1f)   y %6.1f .. %6.1f (h %5.1f)" % [
			name, r.position.x, r.end.x, r.size.x,
			r.position.y, r.end.y, r.size.y])


## What the drawn controls are being told, straight off the node that owns
## them. The pads and the stick post nothing to the membrane bus -- `axoneme`
## thrust is a velocity add and a turn is a steer -- so a log is the only way to
## see two fingers holding two controls at the same instant.
func _step_controls(delta: float) -> void:
	if _controls_trace <= 0.0 or _run == null:
		return
	_controls_clock += delta
	if _controls_clock < _controls_trace:
		return
	_controls_clock = 0.0
	var node := _run.get_node_or_null("Hud/Controls")
	if node == null:
		print("[ctl]  %6.2f  no controls node" % _clock)
		return
	var owners: Dictionary = node.get("_owner")
	var names := ["stick", "port", "starboard", "push", "dash"]
	var held := PackedStringArray()
	for pointer: int in owners:
		var id: int = owners[pointer]
		held.append("%s#%d" % [
			names[id] if id >= 0 and id < names.size() else "?", pointer])
	var cell := _find_node_with(_run, &"bearing_to")
	print("[ctl]  %6.2f  scheme %d  drawn %s  held [%s]  steer %+5.2f  pushing %s  cell.steer %+5.2f" % [
		_clock, node.scheme, "yes" if node.visible else "no ",
		", ".join(held), node.steer(), "yes" if node.pushing() else "no ",
		cell.steer if cell != null else 0.0])


func _field_text(index: int, cell: Node) -> String:
	var bodies: Array = _food.get("_cells")
	var b: Object = bodies[index]
	var radius: float = b.get("radius")
	var gape: float = _food.gape_at(index)
	var state: int = b.get("state")
	var names := ["drift", "stalk", "break"]
	var target: int = b.get("target")
	var target_text := "-"
	if target == FoodField.TARGET_PLAYER:
		target_text = "player"
	elif target >= 0:
		target_text = "cell %d" % target
	# **Whose mouth is on whom**, which is the whole of the directional contact
	# rule and the one thing two overlapping circles cannot tell you. The gap is
	# from the body's centre to the nearest point of the other's lip bow, so a
	# negative number is a mouth that has closed on it.
	var pos: Vector2 = b.get("pos")
	var heading: float = b.get("heading")
	var its_gap: float = Cilia.mouth_gap(pos, heading, radius, gape,
		cell.position) - cell.radius - gape * Cilia.MOUTH_BITE
	var my_gape: float = cell.gape()
	var my_gap: float = Cilia.mouth_gap(cell.position, cell.heading,
		cell.radius, my_gape, pos) - radius - my_gape * Cilia.MOUTH_BITE
	return "r%5.2f gape %5.2f wound %4.2f %-5s -> %-6s  d %7.1f  mouth on me %+7.1f  my mouth on it %+7.1f  %s  %s%s" % [
		radius, gape, float(b.get("wound")), names[state], target_text,
		cell.position.distance_to(pos), its_gap, my_gap,
		"EATS ME" if gape > cell.radius else "       ",
		"edible" if radius < cell.gape() else "      ",
		"  %s" % _genome_text(b.get("genome"))]


func _genome_text(tiers: Dictionary) -> String:
	var parts: Array[String] = []
	for gene: StringName in tiers:
		parts.append("%s%d" % [str(gene).substr(0, 3), int(tiers[gene])])
	parts.sort()
	return "[%s]" % " ".join(parts)


## Watches the field for cells eating each other. Slots are recycled, so a jump
## in a slot's serial means a different body, not a meal.
func _watch_field(delta: float) -> void:
	if _food == null:
		return
	var bodies: Array = _food.get("_cells")
	if bodies == null:
		return
	if _watch_serial.size() != bodies.size():
		_watch_serial.resize(bodies.size())
		_watch_meals.resize(bodies.size())
	for i in bodies.size():
		var serial: int = bodies[i].get("serial")
		var meals: int = bodies[i].get("meals")
		if serial != _watch_serial[i]:
			_watch_serial[i] = serial
			_watch_meals[i] = meals
			continue
		if meals > _watch_meals[i]:
			_field_meals += meals - _watch_meals[i]
			var here: Vector2 = _food.points()[i]
			print("[field] %5.2f  cell %d ate one and is now r%.2f gape %.2f %s  (%.0f units from you)" % [
				_clock, i, bodies[i].get("radius"), _food.gape_at(i),
				_genome_text(bodies[i].get("genome")), _away(i)])
			# A cell that has just fed is newly dangerous and belongs in the
			# water, not ejected from it. Check where it actually went.
			_after_meal.append([i, serial, here, _clock])
			_watch_meals[i] = meals

	for k in range(_after_meal.size() - 1, -1, -1):
		var mark: Array = _after_meal[k]
		if _clock - float(mark[3]) < AFTER_MEAL_LOOK:
			continue
		_after_meal.remove_at(k)
		var index: int = mark[0]
		if bodies[index].get("serial") != mark[1]:
			continue
		# Its own displacement, not the gap to a player swimming at 56 u/s.
		# A break-off runs at lunge speed, so fleeing shows up as 570-1100
		# units in six seconds; drifting shows up as about 54.
		var moved: float = (mark[2] as Vector2).distance_to(_food.points()[index])
		print("[field] %5.2f  cell %d travelled %4.0f units in the %.0fs after its meal: %s" % [
			_clock, index, moved, AFTER_MEAL_LOOK,
			"drifting" if moved < 200.0 else "BOLTED"])

	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return
	# Only while the cell is actually alive. _set_simulating(false) stops the
	# metabolism, and counting the frozen post-death frames made the duty cycle
	# climb on its own -- an instrument that reports the death as dread.
	if _metabolism != null and _metabolism.is_processing():
		_run_seconds += delta
		_dread_area += _food.dread_level * delta
		if _food.dread_level > 0.05:
			_dread_seconds += delta
	if _have_last_pos:
		_travelled += _last_pos.distance_to(cell.position)
		_speed_clock += delta
	_last_pos = cell.position
	_have_last_pos = true


## Parks whatever the shot needs at a fixed body-relative bearing and range.
## Runs after the simulation has moved, so the range is exact in the frame that
## is photographed. This is the harness reaching into the world on purpose; the
## game itself has no such hook and must not grow one.
func _hold_world() -> void:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return
	if _stalk >= 0.0 and _food != null:
		_place(0, _hold_point(_stalk, _stalk_at))
		_face(0, _stalk_face)
		# **Held committed as well as held in place.** A parked hunter's aim
		# point is behind it within a frame or two of contact, so it breaks off
		# and the pose stops being the thing it claims to be -- and the kill
		# branch is gated on STALK, so a test of *why* a kill did or did not
		# land has to keep the state constant and vary only the geometry.
		var bodies: Array = _food.get("_cells")
		if not bodies.is_empty():
			bodies[0].set("state", FoodField.State.STALK)
			bodies[0].set("target", FoodField.TARGET_PLAYER)
			bodies[0].set("stale", 0.0)
	if _food_at >= 0.0 and _food != null:
		# Reaching for a private member is a thing only tools/ is allowed to do.
		# The bodies are objects rather than packed arrays now, so this writes
		# through instead of handing a whole array back.
		_place(1, _hold_point(_food_at, -35.0))
	if _starve >= 0.0 and _metabolism != null:
		_metabolism.starve_seconds = maxf(_metabolism.starve_seconds, _starve)
	if _wound >= 0.0:
		cell.wound = _wound
	# A held sample runs down whether or not anything is watching, so a posed
	# one has to be put back every frame to stay where it was posed.
	if _sample != &"" and _sample_left >= 0.0 and _genome != null:
		_genome.held_sample = _sample
		_genome.held_remaining = _sample_left
	if _gain >= 0.0 and _bus != null:
		_bus.gain = _gain
	_apply_poses(false)


func _parse_pose(spec: String) -> Array:
	var bits := spec.split(",", false)
	var tiers := {}
	if bits.size() > 4:
		for pair in bits[4].split("+", false):
			var gene := str(pair).split(":")
			if gene.size() == 2:
				tiers[StringName(gene[0].strip_edges())] = int(gene[1])
	return [
		int(bits[0]) if bits.size() > 0 else 0,
		float(bits[1]) if bits.size() > 1 else 400.0,
		float(bits[2]) if bits.size() > 2 else 0.0,
		float(bits[3]) if bits.size() > 3 else 20.0,
		tiers,
		float(bits[5]) if bits.size() > 5 else 0.0,
	]


## Held every frame, because the field keeps swimming and recycling underneath.
## Reaching for a private member is a thing only tools/ is allowed to do.
func _apply_poses(announce: bool) -> void:
	if _posed.is_empty() or _food == null:
		return
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return
	var bodies: Array = _food.get("_cells")
	for pose: Array in _posed:
		var index: int = pose[0]
		if index < 0 or index >= bodies.size():
			continue
		var b: Object = bodies[index]
		b.set("radius", pose[3])
		b.set("genome", (pose[4] as Dictionary).duplicate())
		b.set("drifter", (pose[4] as Dictionary).is_empty())
		b.set("seeded", true)
		b.set("state", FoodField.State.DRIFT)
		b.set("target", FoodField.TARGET_NONE)
		b.set("calm", 999.0)
		b.set("pos", _hold_point(pose[1], pose[2]))
		# Facing the player by default, so the mouth is pointed at the thing it
		# is being read against -- which is the frame a forager actually gets.
		# The sixth field turns it away from that, and 180 is the pose the
		# directional-mouth fix exists for: in contact, mouth pointed elsewhere.
		_face(index, float(pose[5]))
		if announce:
			print("[drive] cell %d posed: r%.1f gape %.1f at %.0f units, facing %+.0f deg off you, %s" % [
				index, float(pose[3]), _food.gape_at(index), float(pose[1]),
				float(pose[5]), _genome_text(pose[4])])


func _hold_point(distance: float, bearing_deg: float) -> Vector2:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null:
		return Vector2.ZERO
	var b := deg_to_rad(bearing_deg)
	var dir: Vector2 = cell.forward() * cos(b) + cell.starboard() * sin(b)
	return cell.position + dir * distance


## Press once, then walk sideways a few frames: the same shape of event stream a
## thumb produces, including the mouse events Godot emulates from touch.
func _step_drag() -> void:
	var mid := get_viewport().get_visible_rect().size * 0.5
	if _drag_step == 0:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.pressed = true
		down.position = mid
		Input.parse_input_event(down)
	elif _drag_step <= 8:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = mid + Vector2(_drag_px * _drag_step / 8.0, 0.0)
		Input.parse_input_event(drag)
	_drag_step += 1


## Pausing the tree freezes the simulation, but the membrane layer deliberately
## keeps beating through a pause -- so for a photograph the bus has to be made
## pausable first, or the envelopes decay away while the shot harness waits.
func _freeze() -> void:
	if get_tree().paused:
		return
	# The game deliberately keeps its membrane and its run node alive through a
	# pause. For a photograph everything under the scene has to stop, or the
	# envelopes decay and the death sequence runs on while the shot harness is
	# still waiting.
	if _run != null:
		_make_pausable(_run)
	if _bus != null:
		_bus.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	print("[drive] %5.2f  frozen" % _clock)


func _make_pausable(node: Node) -> void:
	if node.process_mode == Node.PROCESS_MODE_ALWAYS:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	for child in node.get_children():
		_make_pausable(child)


func _on_sensation(kind: StringName, info: Dictionary) -> void:
	var bearing := ""
	if info.has("bearing"):
		bearing = "  bearing %+6.1f deg" % rad_to_deg(float(info["bearing"]))
	var strength := ""
	if info.has("strength"):
		strength = "  strength %.2f" % float(info["strength"])
	# Parked food would be eaten again every frame, which grows the cell and
	# empties its hunger while the shot harness is still waiting. One meal is
	# what was wanted.
	if kind == &"ingest":
		# Anything parked inside contact range would be eaten again every frame,
		# which grows the cell and empties its hunger while the shot harness is
		# still waiting. One meal is what was wanted.
		_food_at = -1.0
		_posed.clear()
		_meals += 1
		print("[drive] %5.2f  meal %d" % [_clock, _meals])
	if kind == &"taste":
		_taste_bearing = float(info.get("bearing", 0.0))
		_taste_c = float(info.get("strength", 0.0))
	if kind == &"shove" and _run != null:
		var cell := _find_node_with(_run, &"bearing_to")
		if cell != null:
			_wake_world = cell.heading + float(info.get("bearing", 0.0))
			_have_wake = true
	# taste fires every frame by design; only the interesting ones are worth a line.
	if kind == &"taste" or kind == &"shear":
		return
	print("[drive] %5.2f  %-7s%s%s" % [_clock, kind, bearing, strength])
	if _freeze_on != "" and str(kind) == _freeze_on and _clock >= _arm_at:
		if _freeze_after >= 0.0:
			if _freeze_at < 0.0:
				_freeze_at = _clock + _freeze_after
		elif _freeze_countdown < 0:
			_freeze_countdown = maxi(_freeze_delay, 1)


func _keycode(name: String) -> Key:
	match name.to_lower():
		"esc": return KEY_ESCAPE
		"enter": return KEY_ENTER
		"up": return KEY_UP
		"down": return KEY_DOWN
		"left": return KEY_LEFT
		"right": return KEY_RIGHT
		"tab": return KEY_TAB
		# Shift and an arrow is the strand's move, and nothing in the
		# InputMap binds it -- a content pack cannot add an action, so the
		# locus reads the raw key. That makes this the only way to pose it.
		"shift-left": return (KEY_LEFT | KEY_MASK_SHIFT) as Key
		"shift-right": return (KEY_RIGHT | KEY_MASK_SHIFT) as Key
		"v": return KEY_V
		# `myoneme` on desktop, and the one key normal mode did not already use.
		"space": return KEY_SPACE
		"w": return KEY_W
		_: return KEY_NONE


## The mouse, moved to a point in the design canvas. `warp_mouse` is what the
## window manager would do; Godot turns the move into a motion event, which is
## what raises `mouse_entered` on whatever control is under it.
## **Canvas coordinates go in unscaled, unlike [method _send_touch].**
## `Viewport.warp_mouse` takes a point in the viewport's own space and applies
## the stretch transform itself, where `Input.parse_input_event` wants the point
## already in window pixels. Scaling here as well put the cursor 1.5x too far
## out at 2400x1080 and photographed a hover that had not happened.
func _send_hover(canvas: Vector2) -> void:
	get_viewport().warp_mouse(canvas)
	print("[drive] %5.2f  hover canvas %.0f,%.0f" % [
		_clock, canvas.x, canvas.y])


## One finger, down and up, at a point in the **design canvas** rather than in
## the window: the project stretches canvas_items with an expand aspect, so the
## same widget is at the same canvas coordinate at 1280x720 and at 2400x1080 and
## only the margins differ. Sent as a touch, which is the event a phone
## actually produces; Godot emulates the mouse from it.
func _send_touch(canvas: Vector2) -> void:
	var at := canvas * get_viewport().get_screen_transform().get_scale() \
		+ get_viewport().get_screen_transform().get_origin()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = at
		Input.parse_input_event(event)
	print("[drive] %5.2f  touch %.0f,%.0f (canvas %.0f,%.0f)" % [
		_clock, at.x, at.y, canvas.x, canvas.y])


## One finger down and left there. A tap commits nothing by design, so the only
## way to photograph *a finger resting on a locus does not lean* is a press that
## is never released.
func _send_press(canvas: Vector2, finger: int = 0) -> void:
	var at := canvas * get_viewport().get_screen_transform().get_scale() \
		+ get_viewport().get_screen_transform().get_origin()
	_finger[finger] = at
	# Where the first slide measures its `relative` from, so the very first
	# movement of a gesture carries a real delta rather than a whole screen.
	_finger_was[finger] = at
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.pressed = true
	event.position = at
	Input.parse_input_event(event)
	print("[drive] %5.2f  press#%d %.0f,%.0f (canvas %.0f,%.0f)" % [
		_clock, finger, at.x, at.y, canvas.x, canvas.y])


## Finger 0 moves, without a fresh press. A resting thumb produces one of these
## the moment it shifts by a pixel, which is the case a press alone cannot pose.
##
## **`relative` is set, and without it this cannot pose a drag at all.** Godot
## turns a screen drag into an emulated `InputEventMouseMotion` and copies
## `relative` straight across; `Viewport`'s GUI accumulates that into
## `gui.drag_accum` and only calls `_get_drag_data` once it passes ten pixels.
## Sent as zero -- which is what this did until the pause strand needed a real
## drag -- the accumulator never grows, the threshold is never crossed, and a
## working drag-and-drop path photographs as a dead one.
func _send_slide(canvas: Vector2, finger: int = 0) -> void:
	var at := canvas * get_viewport().get_screen_transform().get_scale() \
		+ get_viewport().get_screen_transform().get_origin()
	_finger[finger] = at
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	event.relative = at - (_finger_was.get(finger, at) as Vector2)
	_finger_was[finger] = at
	Input.parse_input_event(event)
	print("[drive] %5.2f  slide#%d %.0f,%.0f (canvas %.0f,%.0f)" % [
		_clock, finger, at.x, at.y, canvas.x, canvas.y])


## Finger 0 lets go, from wherever the last `--press=` or `--slide=` left it.
func _send_lift(finger: int = 0) -> void:
	var at: Vector2 = _finger.get(finger, Vector2.ZERO)
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.pressed = false
	event.position = at
	Input.parse_input_event(event)
	print("[drive] %5.2f  lift#%d %.0f,%.0f" % [_clock, finger, at.x, at.y])


## The desktop half of [method _send_press] and [method _send_lift]: the left
## button, down or up, at a point in the **design canvas**. Sent as a real
## `InputEventMouseButton` rather than through `warp_mouse`, because the button
## state is the whole point and warping cannot carry one.
func _send_mouse_button(canvas: Vector2, pressed: bool) -> void:
	_cursor = canvas
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = _to_window(canvas)
	Input.parse_input_event(event)
	print("[drive] %5.2f  mouse %s canvas %.0f,%.0f" % [
		_clock, "down " if pressed else "up   ", canvas.x, canvas.y])


## The cursor moves with the left button still down -- the desktop twin of
## [method _send_slide], and the event Godot hit-tests afresh whenever no
## control captured the button.
func _send_mouse_slide(canvas: Vector2) -> void:
	var from := _to_window(_cursor)
	var at := _to_window(canvas)
	_cursor = canvas
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = at
	event.relative = at - from
	Input.parse_input_event(event)
	print("[drive] %5.2f  mouse move  canvas %.0f,%.0f" % [
		_clock, canvas.x, canvas.y])


## Canvas to window pixels. `Input.parse_input_event` wants the point already
## stretched; see the note on --touch=.
func _to_window(canvas: Vector2) -> Vector2:
	return canvas * get_viewport().get_screen_transform().get_scale() \
		+ get_viewport().get_screen_transform().get_origin()


## One key, down or up. A keycode may carry `KEY_MASK_SHIFT`, which is masked
## back off and set as the modifier instead: `InputEventKey.keycode` is the bare
## key and `shift_pressed` is the chord, and a control reading a raw
## `InputEventKey` -- which is the only way a content pack can bind one -- sees
## exactly what a real keyboard would send.
func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = (keycode & ~KEY_MASK_SHIFT) as Key
	event.physical_keycode = event.keycode
	event.shift_pressed = (keycode & KEY_MASK_SHIFT) != 0
	event.pressed = pressed
	Input.parse_input_event(event)


## The bus is a node called Signals under the membrane layer; found by walking
## rather than by path so this keeps working if the scene is rearranged.
func _find_bus(node: Node) -> Node:
	return _find_node_with(node, &"set_beat")


## By script path, because two fields can share a method name and the harness
## needs a specific one.
func _find_script(node: Node, path: String) -> Node:
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path == path:
		return node
	for child in node.get_children():
		var found := _find_script(child, path)
		if found != null:
			return found
	return null


func _find_node_with(node: Node, method: StringName) -> Node:
	if node.has_method(method):
		return node
	for child in node.get_children():
		var found := _find_node_with(child, method)
		if found != null:
			return found
	return null


# ---------------------------------------------------------------------------
# Reaching into the world on purpose. The game has no hooks for any of this and
# must not grow any: a simulation that can be posed from outside is one that can
# be posed by accident.
# ---------------------------------------------------------------------------

## Turns field cell [param index] into something that can eat the player, puts
## it at [param at] and starts its run. The gape multiple is the whole point of
## the handle: at 1.40 it is terrifying, at 0.90 it can still eat you but dread
## barely registers, and at 0.80 it cannot.
func _make_hunter(index: int, at: Vector2) -> void:
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null or _food == null:
		return
	var bodies: Array = _food.get("_cells")
	if index >= bodies.size():
		return
	var b: Object = bodies[index]
	# A body the player's own size, with whatever mouth the test asked for. The
	# tier ladder is coarse, so the multiple is written straight into the body
	# rather than approximated by a tier -- this is a measuring instrument.
	b.set("radius", cell.radius)
	b.set("drifter", false)
	b.set("genome", {&"cytostome": 3, &"flagellum": 2})
	b.set("pos", at)
	b.set("state", FoodField.State.STALK)
	b.set("target", FoodField.TARGET_PLAYER)
	b.set("aim", cell.position)
	b.set("aim_clock", 0.0)
	b.set("lost", 0.0)
	b.set("rush", 0.0)
	b.set("best", INF)
	b.set("lunging", false)
	b.set("stroke", 0.2)
	b.set("heading", atan2((cell.position - at).x, -(cell.position - at).y))
	# Scale the radius so the gape comes out at exactly the multiple asked for.
	var tier_gape: float = CellBody.GAPE_BY_TIER[3]
	b.set("radius", cell.radius * _hunter_gape / tier_gape)
	print("[drive] hunter %d: r%.1f gape %.1f against your r%.1f" % [
		index, b.get("radius"), _food.gape_at(index), cell.radius])


func _place(index: int, at: Vector2) -> void:
	var bodies: Array = _food.get("_cells")
	if index < bodies.size():
		bodies[index].set("pos", at)


## Points field cell [param index] [param away] degrees off facing the player,
## every frame, overriding whatever it wanted to swim at. NAN leaves it alone.
##
## The harness reaching into the world on purpose: a mouth that has to be
## pointed at you to reach you cannot be tested by waiting for the water to
## point one the wrong way.
func _face(index: int, away: float) -> void:
	if is_nan(away) or _food == null:
		return
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	var bodies: Array = _food.get("_cells")
	if cell == null or index >= bodies.size():
		return
	var to_player: Vector2 = cell.position - bodies[index].get("pos")
	if to_player.length_squared() <= 0.0001:
		return
	bodies[index].set("heading",
		wrapf(atan2(to_player.x, -to_player.y) + deg_to_rad(away), -PI, PI))


## `cytostome:3,cirrus:2` -- straight into the genome node, before the first
## frame, so the cell boots as whatever the measurement needs it to be.
## `gene:tier` as before, and `gene:tier:slot` to say **which slot**, which is
## which arc, which is which way a directional gene looks. Without the third
## field the genes land in the order they are written, in the first slots that
## will take them -- so `--genome=cytostome:1,ocellus:1` aims the beam forward
## and `ocellus:1:6` aims it over the rear-port quarter.
func _force_genome(spec: String) -> void:
	var made := _parse_genes(spec)
	# **Expressed whole**, which is what a birth does: the harness is forcing a
	# cell, not feeding one, so the body and the DNA are the same thing.
	_genome.express(made[0], made[1])
	print("[drive] genome forced to %s in %s, upkeep %.2f" % [
		_genome_text(made[0]), made[1], _genome.upkeep()])


## **The DNA without the body**, which is the state a cell reaches by eating and
## the one the pause strip exists to show: the organism and the plan disagreeing.
## Reached by playing it is a whole generation of foraging, so it is posed here.
## Reaching for a private member is a thing only tools/ is allowed to do.
func _force_dna(spec: String) -> void:
	var made := _parse_genes(spec)
	_genome.set("_dna", made[0])
	_genome.set("_order", made[1])
	print("[drive] dna forced to %s in %s (body stays %s)" % [
		_genome_text(made[0]), made[1], _genome_text(_genome.tiers())])


## `cytostome:3,cirrus:2` into `[{gene: tier}, layout]`. `gene:tier` as before,
## and `gene:tier:slot` to say **which slot**, which is which arc, which is which
## way a directional gene looks. Without the third field the genes land in the
## order they are written, in the first slots that will take them.
func _parse_genes(spec: String) -> Array:
	var tiers := {}
	var placed := {}
	for pair in spec.split(",", false):
		var bits := str(pair).split(":")
		if bits.size() < 2:
			continue
		var gene := StringName(bits[0].strip_edges())
		tiers[gene] = int(bits[1])
		if bits.size() >= 3:
			placed[gene] = int(bits[2])
	var layout: Array[StringName] = []
	for i in maxi(_genome.slots(), tiers.size()):
		layout.append(&"")
	for gene: StringName in placed:
		var slot := int(placed[gene])
		if slot >= 0 and slot < layout.size():
			layout[slot] = gene
	for gene: StringName in tiers:
		if placed.has(gene) and layout.has(gene):
			continue
		if placed.has(gene):
			# Asked for a slot this body does not have yet -- the ladder is
			# the radius, so `--radius=40` is what buys slots 5 and 6. Say so
			# rather than silently dropping the gene somewhere else.
			print("[drive] slot %d is past this body's %d slots" % [
				int(placed[gene]), layout.size()])
		var free := layout.find(&"")
		if free >= 0:
			layout[free] = gene
	return [tiers, layout]


## §1.3's distribution, measured rather than argued about. Reseeds the whole
## field over and over at a range of player radii and reports what actually
## comes out -- above all whether the field is ever left with no drifter in it,
## which is the invariant the "there is always a way back" claim rests on.
func _run_seeding_check(rounds: int) -> void:
	var cell := _find_node_with(_run, &"bearing_to")
	if cell == null or _food == null:
		print("[check] no simulation to seed")
		return
	var bodies: Array = _food.get("_cells")
	var drifterless := 0
	var min_drifters := 99
	var drifters := 0
	var seeds := 0
	var max_gape := 0.0
	var max_radius := 0.0
	var tier_counts := {0: 0, 1: 0, 2: 0, 3: 0}
	var edible := 0
	var dangerous := 0
	var both := 0
	var buckets := {}

	for round_index in rounds:
		# Sweep the player across the whole arc, because half of §1.3 is the
		# claim that the water is a different picture at r26 and at r40.
		cell.radius = lerpf(CellBody.BASE_RADIUS, 40.0,
			float(round_index % 15) / 14.0)
		_food.setup(cell)
		for k in bodies.size():
			_food.call("_seed", k)
			var live := 0
			for i in bodies.size():
				if bodies[i].get("drifter"):
					live += 1
			min_drifters = mini(min_drifters, live)
			if live == 0:
				drifterless += 1
		for i in bodies.size():
			seeds += 1
			var b: Object = bodies[i]
			var radius: float = b.get("radius")
			var gape: float = _food.gape_at(i)
			if b.get("drifter"):
				drifters += 1
			max_gape = maxf(max_gape, gape)
			max_radius = maxf(max_radius, radius)
			var tier: int = int((b.get("genome") as Dictionary).get(&"cytostome", 0))
			tier_counts[tier] = int(tier_counts[tier]) + 1
			var i_eat: bool = radius < cell.gape()
			var it_eats: bool = cell.radius < gape
			if i_eat and it_eats:
				both += 1
			elif i_eat:
				edible += 1
			elif it_eats:
				dangerous += 1
			# The claim §1.3 had to produce: the born cell and the full-grown
			# cell must not be looking at the same picture at two zoom levels.
			var bucket := int(roundf(cell.radius))
			if not buckets.has(bucket):
				buckets[bucket] = [0, 0, 0, 0]
			var row: Array = buckets[bucket]
			row[0] += 1
			if i_eat and it_eats:
				row[3] += 1
			elif i_eat:
				row[1] += 1
			elif it_eats:
				row[2] += 1

	print("[check] %d rounds, %d seeded bodies" % [rounds, seeds])
	print("[check] drifter-free fields: %d  (minimum drifters seen in a field: %d)"
		% [drifterless, min_drifters])
	print("[check] drifters %.1f%%  cytostome tiers 0/1/2/3: %d/%d/%d/%d" % [
		100.0 * float(drifters) / float(maxi(seeds, 1)),
		tier_counts[0], tier_counts[1], tier_counts[2], tier_counts[3]])
	print("[check] max radius %.2f  max gape %.2f  (ARRIVAL_GAPE_MAX %.1f)" % [
		max_radius, max_gape, FoodField.ARRIVAL_GAPE_MAX])
	for bucket: int in [26, 33, 40]:
		if not buckets.has(bucket):
			continue
		var row: Array = buckets[bucket]
		var n := float(maxi(int(row[0]), 1))
		print("[check] a player at r%d, out of %d bodies: edible %.0f%%  eats me %.0f%%  both %.0f%%  standoff %.0f%%" % [
			bucket, int(row[0]), 100.0 * float(row[1]) / n, 100.0 * float(row[2]) / n,
			100.0 * float(row[3]) / n,
			100.0 * float(int(row[0]) - int(row[1]) - int(row[2]) - int(row[3])) / n])
	print("[check] relationship to the player: edible %.1f%%  eats me %.1f%%  both %.1f%%  standoff %.1f%%" % [
		100.0 * float(edible) / float(maxi(seeds, 1)),
		100.0 * float(dangerous) / float(maxi(seeds, 1)),
		100.0 * float(both) / float(maxi(seeds, 1)),
		100.0 * float(seeds - edible - dangerous - both) / float(maxi(seeds, 1))])


## How far field cell [param index] is from the player right now.
func _away(index: int) -> float:
	var cell := _find_node_with(_run, &"bearing_to") if _run != null else null
	if cell == null or _food == null:
		return 0.0
	return _food.points()[index].distance_to(cell.position)
