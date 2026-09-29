extends RefCounted
## **A fan of rays**: how many there are, how wide they spread, and whether they
## sweep. Nothing here knows what a ray finds or what it is for. The beam is the
## first user (docs/design/beam-levels.md §4), and later versions of the game
## are meant to reuse this with other parts.
##
## Angles are radians, measured from the fan's own centre line. Whoever owns the
## fan adds the direction the fan points in.
##
## **Fixed**: the rays are spread evenly from one edge of the fan to the other,
## and a single ray points straight down the centre line.
##
## **Sweeping**: the fan is cut into one equal sector per ray, and each ray
## swings back and forth across its own sector, all of them in step. Together
## they cover the fan with no overlap and no gap, and every bearing in it is
## revisited within [method revisit] seconds.
##
## **The arc each ray crossed this step** is kept beside where it is now
## ([method arc_low], [method arc_high]). Whatever the fan is tested against has
## to test that whole arc: at a fast sweep a ray jumps several degrees a frame,
## more at a low frame rate than a high one, so a thing between two positions is
## otherwise missed by a slow phone and found by a fast one.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## How many rays.
var count := 0
## How far the fan reaches either side of its centre line.
var half_span := 0.0
## How fast each ray crosses its own sector, radians a second. 0 is a fixed fan.
var sweep := 0.0

## How far along its back-and-forth path every ray has travelled, in radians,
## wrapped into one period. Starts a quarter period in, which is the middle of
## a sector: a fan that starts sweeping starts from the centre of each share.
var _travel := -1.0
var _offsets := PackedFloat32Array()
var _low := PackedFloat32Array()
var _high := PackedFloat32Array()


## Sets the fan's shape. Takes effect on the next [method step]; the sweep keeps
## its place in its cycle, so a fan that speeds up does not jump.
func configure(rays: int, half: float, speed: float) -> void:
	count = maxi(rays, 0)
	half_span = maxf(half, 0.0)
	sweep = maxf(speed, 0.0)


## Moves the fan on by [param delta] seconds and works out where every ray is
## and what arc it crossed getting there.
func step(delta: float) -> void:
	_offsets.resize(count)
	_low.resize(count)
	_high.resize(count)
	if count <= 0:
		return
	if sweep <= 0.0 or half_span <= 0.0:
		for i in count:
			var u := 0.0 if count < 2 else -1.0 + 2.0 * float(i) / float(count - 1)
			_offsets[i] = u * half_span
			_low[i] = _offsets[i]
			_high[i] = _offsets[i]
		return
	var width := 2.0 * half_span / float(count)
	var period := 2.0 * width
	if _travel < 0.0:
		_travel = width * 0.5
	var from := _travel
	var moved := sweep * maxf(delta, 0.0)
	var to := from + moved
	# Where on the sector each end of the move is, and whether the move turned
	# round at an edge on the way. Two turns means the whole sector was crossed.
	var start := _position(from, width)
	var finish := _position(to, width)
	var low := minf(start, finish)
	var high := maxf(start, finish)
	if moved >= period:
		low = -width * 0.5
		high = width * 0.5
	else:
		var turn := (floorf(from / width) + 1.0) * width
		while turn <= to:
			if int(roundf(turn / width)) % 2 == 1:
				high = width * 0.5
			else:
				low = -width * 0.5
			turn += width
	_travel = fposmod(to, period)
	for i in count:
		var centre := -half_span + width * (float(i) + 0.5)
		_offsets[i] = centre + finish
		_low[i] = centre + low
		_high[i] = centre + high


## Where each ray points now, from the centre line.
func offsets() -> PackedFloat32Array:
	return _offsets


## The low edge of the arc each ray crossed this step. The same as
## [method offsets] for a fixed fan.
func arc_low() -> PackedFloat32Array:
	return _low


## The high edge of the arc each ray crossed this step.
func arc_high() -> PackedFloat32Array:
	return _high


## **How long a bearing in the fan can go unlit**: a whole back-and-forth,
## because a ray passing one way and back again touches a bearing twice in
## that time and, at the ends of its sector, only once. 0 for a fixed fan,
## whose rays never leave.
func revisit() -> float:
	return revisit_of(count, half_span, sweep)


## [method revisit] for a fan of [param rays] reaching [param half] either side
## and sweeping at [param speed], without building one.
static func revisit_of(rays: int, half: float, speed: float) -> float:
	if speed <= 0.0 or rays <= 0 or half <= 0.0:
		return 0.0
	return 2.0 * (2.0 * half / float(rays)) / speed


## Where on its own sector a ray is after travelling [param travel], from
## `-width / 2` to `width / 2`: out along the sector, then back.
static func _position(travel: float, width: float) -> float:
	var t := fposmod(travel, 2.0 * width)
	if t < width:
		return t - width * 0.5
	return width * 0.5 - (t - width)
