extends CanvasLayer
## **The dev app's frame readout** (docs/design/ocean.md §14.1, §14.2): how
## long a frame takes, its median and its 95th percentile over the last ten
## seconds; **the share of those frames dropped** -- an interval longer than
## [constant DROPPED_AFTER] periods of the rate the game is held to -- which is
## what the phone gate reads; how much of a frame the water's own `_process`
## took, as a median over the same ten seconds; and how many bodies the water
## stepped a frame. What 1a-1 reads of today's water is the baseline the drop is
## read against, so a frame that fails says whether the water is the cause.
## **And, since the water divides** (docs/design/lineage.md §4), its hunters'
## mean generation and how many families they come from: the water evolving,
## in the dev app and nowhere a player looks. **And, since its rules change at
## every division** (docs/design/behaviour.md §7.3), how many behaviours its
## hunters carry and the share of them still on the founders' rules: the water
## learning, in the same place.
##
## **Why dropped and not the p95.** A frame is timed from one to the next, so
## vsync is in it: a phone holding a steady 60 reads a p95 a little over 16.7 ms
## from the jitter of its own clock, and a 90 or 120 Hz phone's p95 stays under
## 16.7 ms while it drops frames. A dropped frame is one that came more than
## half a period late. **The rate is the display's, or [constant HELD_HZ] on a
## faster one**: the game has no frame cap, and a 120 Hz phone holding a steady
## 60 has dropped nothing -- held to its own rate, the gate would ask for 120.
## The p95 stays on the table, for information.
##
## **Only on the dev app.** It is built only in a build that follows a branch's
## rolling prerelease -- `BuildInfo.release_branch` not empty -- read the way
## game/net/channel.gd reads it: with no BuildInfo to ask, it is a release
## build. **A release build draws nothing and costs nothing**: [method attach]
## asks once, when the run starts, and adds no node, no clock and no drawing.
## CI and the fingerprints run release-stamped, so nothing they measure sees it.
##
## **What it measures.** A frame is the time from one frame to the next, taken
## at the same point of every frame -- what a player sees, vsync's wait
## included. Frames under the pause page are not counted, and neither is the
## gap a pause or a phone that left the app leaves: **the ten seconds are ten
## seconds of play**, on a clock that only runs with the frames it counts, so a
## pause in the middle of a test neither adds to the window nor cuts it short.
## The water is timed by two hands of a stopwatch
## seated either side of it in the tree, with its own process mode and priority,
## so the engine runs them in the order opening hand, water, closing hand and
## nothing about when the water runs changes: tools/drive.gd's `--field-cost`,
## which measured §4.4's table, carried into the game. A frame in which the
## water did not run -- paused, dividing, dead, replaying -- is not a sample.
##
## **Where it sits**: a small table at the top right, on a panel cut like the
## pause target's at the top left -- the same rounded slab in the same teal --
## so the two corners carry the game's two pieces of chrome and the table sits
## on something rather than floating in the water. The screen's edge is the
## membrane, and the band reaches 154 px in at its deepest wobble
## (membrane.gdshader: 28 px of inset, 104 of band, 22 of wobble), so the panel
## starts [constant INSET] in and never covers one of its marks. Clear of the
## pause target and of the thumbs' wells at the bottom corners. No figure takes
## more than [constant FIGURE_GLYPHS] glyphs, so the panel keeps one width from
## one refresh to the next instead of breathing with the digits.
## The words and numbers are the pause screen's (figure.gd's NUMBERS_*):
## words in the pale tint and the numbers a little brighter, with a dark edge
## round every letter.
##
## **It steps aside for the game's own pages.** While the water stands still in
## a running game -- the division's choosing screen, a death, the replay -- it
## is hidden, and still counts the frames. **While the pause page is up it is
## hidden and counts nothing**: a frame drawn under a menu is not one the gate
## reads, and in a pond the water runs on under the menu. It is back as the page
## closes, with what it last showed until its next refresh.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Self := preload("res://game/dev/frame_readout.gd")

## How far back every figure looks: ten seconds, in microseconds.
const WINDOW_USEC := 10000000
## How often the figures are worked out and drawn again, in seconds.
const REFRESH := 0.5
## The most frames a window holds: ten seconds at 400 a second.
const CAPACITY := 4096
## The panel's top right corner, in from the screen's top right corner: past
## the membrane's band all round.
const INSET := Vector2(160.0, 160.0)
## **A frame is dropped** when it took longer than this many periods of the
## rate it is held to: the display showed the frame before it twice.
const DROPPED_AFTER := 1.5
## **The rate a frame is held to**: the display's own, or this when the display
## is faster -- or will not say, as a headless run and some desktops will not.
const HELD_HZ := 60.0
## The pause screen's numbers' tints -- words at 0.42 and the numbers at 0.70
## of the column's pale tint (figure.gd's NUMBERS_*) -- and its 14 px, 19
## apart...
const FONT_SIZE := 14
const PITCH := 19.0
## ...grown to 16 px, 21 apart, on a screen wider than 16:9: a phone's, read at
## a glance in play, and with the room for it -- room enough to say the rate a
## frame is dropped against, `of 60 Hz`, which at 16:9 would make the panel half
## as wide again.
const FONT_SIZE_WIDE := 16
const PITCH_WIDE := 21.0
const WIDE := 1400.0
## The frame's three rows, the water's two, its families' two and its
## behaviours' two, told apart by this much more between them.
const GROUP_GAP := 5.0
const WORD := Color(0.855, 0.953, 0.933, 0.42)
const VALUE := Color(0.855, 0.953, 0.933, 0.70)
## A dark edge round every letter, in the water's own base colour.
const EDGE := Color(0.023, 0.055, 0.05, 0.85)
const EDGE_SIZE := 4
## Between a row's name and its number, and between a number and its unit.
const GAP := 6.0
const UNIT_GAP := 3.0
## **The most glyphs a figure takes**: a figure that would take more drops a
## decimal -- 100.0 is shown as 100, a 12.34 ms water as 12.3 -- so the
## numbers keep one column width and the panel one size.
const FIGURE_GLYPHS := 4
## **The panel: the pause target's slab** (normal_mode.gd's `_well`): its
## rounded corner, its one-pixel edge and its two teals. The pause target rests
## at a fill of 0.13 because it asks to be ignored; this one has a table to keep
## legible over a lit cell, so it takes the slab's fill at 0.62 and its edge at
## 0.20 -- the same two colours, drawn to be read through.
const PANEL_FILL := Color(0.063, 0.141, 0.125, 0.62)
const PANEL_EDGE := Color(0.12, 0.70, 0.58, 0.20)
const PANEL_CORNER := 12
## The table's room inside the panel: with the font's own ascent and descent,
## 7 to 10 px of panel round the letters at 16:9.
const PAD := Vector2(7.0, 6.0)

## **A tool's seam**, as channel.gd's: while it is set, this process poses as a
## build of that branch -- "" poses as a release build -- until it is set back
## to null. Nothing a player or an owner runs sets it, and no flag reaches it.
static var posing: Variant = null

## The node whose own `_process` is timed.
var water: Node = null
## **Asked every frame: whether a page covers the water** -- the pause menu,
## which in a pond stands over water that runs on. Unset, nothing does.
var covered := Callable()

var _frames := Recent.new(CAPACITY)
var _water := Recent.new(CAPACITY)
## When the last frame was taken, and which frame it was: an interval is only
## counted between two frames that followed each other.
var _last_at := -1
var _last_frame := -1
## **The window's clock**, in microseconds: every interval counted, added up.
## It stands still while nothing is counted.
var _played := 0
var _clock := 0.0
## What is drawn: `[name, number, unit, starts a group]` a row.
var _rows: Array = []
var _table: Control = null
var _panel: StyleBoxFlat = null


## **Puts a readout over [param host], timing [param watched]'s own
## `_process`** -- on the dev app -- and stepping aside while [param covered]
## says a page is up. Anywhere else it returns null having added nothing at all.
static func attach(host: Node, watched: Node, covered := Callable()) -> Node:
	if host == null or watched == null or watched.get_parent() == null:
		return null
	if branch().is_empty():
		return null
	var readout: CanvasLayer = Self.new()
	readout.name = "FrameReadout"
	readout.water = watched
	readout.covered = covered
	host.add_child(readout)
	return readout


## `BuildInfo.release_branch`, or "" when there is no BuildInfo to ask -- read
## as game/net/channel.gd reads it.
static func branch() -> String:
	if posing != null:
		return str(posing)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return ""
	var info := tree.root.get_node_or_null(^"BuildInfo")
	var said: Variant = info.get("release_branch") if info != null else null
	return said if said is String else ""


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = StyleBoxFlat.new()
	_panel.bg_color = PANEL_FILL
	_panel.border_color = PANEL_EDGE
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(PANEL_CORNER)
	_table = Control.new()
	_table.name = "Table"
	_table.set_anchors_preset(Control.PRESET_FULL_RECT)
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table.draw.connect(_draw_table)
	add_child(_table)
	_seat_hands()
	_rows = _figures()


func _process(delta: float) -> void:
	var aside := _aside()
	var shown := not aside and is_instance_valid(water) and water.is_processing()
	if visible != shown:
		visible = shown
	if aside:
		_last_frame = -1
		return
	var now := Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	if _last_frame >= 0 and frame == _last_frame + 1:
		_played += now - _last_at
		_frames.push(_played, float(now - _last_at) / 1000.0, WINDOW_USEC)
	_last_at = now
	_last_frame = frame
	_clock += delta
	if _clock >= REFRESH:
		_clock = 0.0
		_rows = _figures()
		_table.queue_redraw()


func _notification(what: int) -> void:
	# A phone that left the app stopped the loop: the frame after it is not a
	# frame anybody waited for.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_RESUMED:
		_last_frame = -1


## **Nothing is counted or shown**: a page covers the water, or the tree is
## stopped.
func _aside() -> bool:
	return get_tree().paused or (covered.is_valid() and bool(covered.call()))


## Called by the closing hand, with how long the water took this frame.
func water_ran(usec: int) -> void:
	if not _aside():
		_water.push(_played, float(usec) / 1000.0, WINDOW_USEC)


## The frames' intervals in the window, in milliseconds, smallest first.
func frames_now() -> PackedFloat32Array:
	return _frames.sorted(_played, WINDOW_USEC)


## The water's own times in the window, in milliseconds, smallest first.
func water_now() -> PackedFloat32Array:
	return _water.sorted(_played, WINDOW_USEC)


## **The rows, as they are now**: a frame's median, its 95th percentile and
## the share dropped at the rate it is held to -- named after it where there is
## room; the water's median, and the bodies it stepped; **and, for a water that
## keeps a record of its families** (docs/design/lineage.md §4, §6.4), the
## hunters' mean generation and how many of the water's founders they descend
## from, so the owner can watch the water evolve while playing it; **and, for a
## water whose cells carry rules** (docs/design/behaviour.md §7.3), how many
## different lists of rules its hunters carry and the share of them still on the
## founders' seven, in percent, so the owner can watch it learn. A figure with
## nothing behind it yet is a dash: a friend's drop, seen from inside it, keeps
## no record here.
func _figures() -> Array:
	var frames := frames_now()
	var water_ms := water_now()
	var stepped := _stepped()
	var hz := refresh_rate()
	var share := dropped(frames, hz)
	var against := " of %d Hz" % roundi(hz) if _wide() else ""
	var rows := [
		["frame", _rank(frames, 0.5, 1), "ms", false],
		["p95", _rank(frames, 0.95, 1), "ms", false],
		["dropped", figure(share, 1) if share >= 0.0 else "–", "%" + against, false],
		["water", _rank(water_ms, 0.5, 2), "ms", true],
		["stepped", str(stepped) if stepped >= 0 else "–", "", false],
	]
	if is_instance_valid(water) and water.has_method(&"lineage_counts"):
		var counts: Array = water.call(&"lineage_counts")
		var known := counts.size() == 2
		rows.append(["generation", figure(float(counts[0]), 1) if known else "–", "", true])
		rows.append(["families", str(int(counts[1])) if known else "–", "", false])
	if is_instance_valid(water) and water.has_method(&"behaviour_counts"):
		var kinds: Array = water.call(&"behaviour_counts")
		var known := kinds.size() == 2
		rows.append(["behaviours", str(int(kinds[0])) if known else "–", "", true])
		rows.append(["unchanged", figure(float(kinds[1]), 1) if known else "–", "%", false])
	return rows


## **The share of [param intervals] dropped**, in percent: those longer than
## [constant DROPPED_AFTER] periods of what a display of [param hz] is held
## to. -1 for none.
static func dropped(intervals: PackedFloat32Array, hz: float) -> float:
	if intervals.is_empty():
		return -1.0
	var late := DROPPED_AFTER * 1000.0 / usable_rate(hz)
	var count := 0
	for ms: float in intervals:
		if ms > late:
			count += 1
	return 100.0 * float(count) / float(intervals.size())


## The rate this display's frames are held to, in Hz.
static func refresh_rate() -> float:
	return usable_rate(DisplayServer.screen_get_refresh_rate())


## **What a display of [param hz] is held to**: its own rate up to
## [constant HELD_HZ], and [constant HELD_HZ] when it said nothing usable.
static func usable_rate(hz: float) -> float:
	return minf(hz, HELD_HZ) if hz > 0.0 else HELD_HZ


## The value at [param share] of [param sorted], nearest rank -- as
## `--field-cost` reads its p50 and p90 -- with [param decimals].
static func _rank(sorted: PackedFloat32Array, share: float, decimals: int) -> String:
	if sorted.is_empty():
		return "–"
	return figure(sorted[int(share * float(sorted.size() - 1))], decimals)


## [param value] with [param decimals], or with fewer where that would take
## more than [constant FIGURE_GLYPHS] glyphs.
static func figure(value: float, decimals: int) -> String:
	var places := maxi(decimals, 0)
	var text := ("%." + str(places) + "f") % value
	while text.length() > FIGURE_GLYPHS and places > 0:
		places -= 1
		text = ("%." + str(places) + "f") % value
	return text


## **How many bodies the water stepped in a frame.** A water that counts them
## says so through `stepped_bodies()`; today's water steps every body it holds,
## every frame, so it is the bodies in it.
func _stepped() -> int:
	if water == null or not is_instance_valid(water):
		return -1
	if water.has_method(&"stepped_bodies"):
		return int(water.call(&"stepped_bodies"))
	if not water.has_method(&"bodies"):
		return -1
	var count := 0
	for body: Object in water.call(&"bodies"):
		if body.get(&"seeded"):
			count += 1
	return count


## Seats the stopwatch's two hands either side of the water.
func _seat_hands() -> void:
	var parent := water.get_parent()
	var opening := Hand.new()
	opening.name = "FrameReadoutOpen"
	opening.water = water
	var closing := Hand.new()
	closing.name = "FrameReadoutClose"
	closing.water = water
	closing.opening = opening
	closing.readout = self
	for hand: Node in [opening, closing]:
		hand.process_mode = water.process_mode
		hand.process_priority = water.process_priority
	parent.add_child(opening)
	parent.move_child(opening, water.get_index())
	parent.add_child(closing)
	parent.move_child(closing, water.get_index() + 1)


## The table: names left, numbers right-aligned in a column, units after them,
## on its panel. The dark edge first, under everything, then the letters.
func _draw_table() -> void:
	var font := _table.get_theme_default_font()
	if font == null or _rows.is_empty():
		return
	var at := _layout(font, _rows, _table.size.x)
	var panel: Rect2 = at.panel
	var size: int = at.size
	var column: float = at.names + GAP + at.numbers
	_table.draw_style_box(_panel, panel)
	var left := panel.position.x + PAD.x
	var y := panel.position.y + PAD.y + font.get_ascent(size)
	var lines := PackedFloat32Array()
	for row: Array in _rows:
		y += GROUP_GAP if row[3] else 0.0
		lines.append(roundf(y))
		y += at.pitch
	for edge in [true, false]:
		for i in _rows.size():
			var row: Array = _rows[i]
			var number_x := roundf(left + column - _width(font, row[1], size))
			_piece(font, size, Vector2(left, lines[i]), row[0], WORD, edge)
			_piece(font, size, Vector2(number_x, lines[i]), row[1], VALUE, edge)
			_piece(font, size, Vector2(left + column + UNIT_GAP, lines[i]), row[2], WORD,
				edge)


## **Where the panel goes** for [param rows] on a canvas [param width] wide: its
## right edge and its top [constant INSET] in from the top right corner, and its
## size the table's and its [constant PAD]. `{panel, size, pitch, names,
## numbers}`: the rectangle, the font size and row pitch it is drawn at, and
## the widths of the name and number columns.
static func _layout(font: Font, rows: Array, width: float) -> Dictionary:
	var wide := width >= WIDE
	var size := FONT_SIZE_WIDE if wide else FONT_SIZE
	var pitch := PITCH_WIDE if wide else PITCH
	var names := 0.0
	var numbers := 0.0
	var units := 0.0
	var gaps := 0.0
	for row: Array in rows:
		names = maxf(names, _width(font, row[0], size))
		numbers = maxf(numbers, _width(font, row[1], size))
		units = maxf(units, _width(font, row[2], size))
		gaps += GROUP_GAP if row[3] else 0.0
	var across := names + GAP + numbers + UNIT_GAP + units
	var down := font.get_ascent(size) + font.get_descent(size) \
		+ pitch * float(rows.size() - 1) + gaps
	var panel := Rect2(width - INSET.x - across - 2.0 * PAD.x, INSET.y,
		across + 2.0 * PAD.x, down + 2.0 * PAD.y)
	panel.position = panel.position.round()
	panel.size = panel.size.round()
	return {panel = panel, size = size, pitch = pitch, names = names, numbers = numbers}


## A screen wider than 16:9, which has the room for the larger table.
func _wide() -> bool:
	return _table != null and _table.size.x >= WIDE


func _piece(font: Font, size: int, at: Vector2, text: String, tint: Color,
		edge: bool) -> void:
	if text.is_empty():
		return
	if edge:
		_table.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			size, EDGE_SIZE, EDGE)
	else:
		_table.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, tint)


static func _width(font: Font, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


## **The last ten seconds of one figure**: a ring of values with the moment
## each was taken, forgetting what falls out of the window as it goes.
class Recent:
	var _at := PackedInt64Array()
	var _values := PackedFloat32Array()
	## Where the next value goes, and how many the ring holds.
	var _next := 0
	var _held := 0

	func _init(capacity: int) -> void:
		_at.resize(maxi(capacity, 1))
		_values.resize(maxi(capacity, 1))

	func push(now: int, value: float, span: int) -> void:
		_at[_next] = now
		_values[_next] = value
		_next = (_next + 1) % _at.size()
		_held = mini(_held + 1, _at.size())
		_forget(now, span)

	## What the window holds at [param now], smallest first.
	func sorted(now: int, span: int) -> PackedFloat32Array:
		_forget(now, span)
		var size := _at.size()
		var first := (_next - _held + size) % size
		var out: PackedFloat32Array
		if first + _held <= size:
			out = _values.slice(first, first + _held)
		else:
			out = _values.slice(first)
			out.append_array(_values.slice(0, _next))
		out.sort()
		return out

	func _forget(now: int, span: int) -> void:
		var size := _at.size()
		while _held > 0 and _at[(_next - _held + size) % size] < now - span:
			_held -= 1


## **One hand of the stopwatch round the water's `_process`.** The opening hand
## reads the clock as its last act and the closing hand as its first, so almost
## nothing but the water lies between the two readings.
class Hand extends Node:
	var water: Node = null
	## Set on the closing hand only: the opening one, and whom to tell.
	var opening: Hand = null
	var readout: Node = null
	var at := -1

	func _process(_delta: float) -> void:
		if opening == null:
			at = Time.get_ticks_usec() if is_instance_valid(water) and water.is_processing() \
				else -1
			return
		var now := Time.get_ticks_usec()
		if opening.at >= 0:
			readout.call(&"water_ran", now - opening.at)
			opening.at = -1
