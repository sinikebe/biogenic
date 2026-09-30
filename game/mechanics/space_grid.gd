extends RefCounted
## **Which things are near a place**: a square cut into buckets, each bucket a
## list threaded through two packed arrays, so nothing is allocated as things
## come, move and go. The drop's bodies are the first user
## (docs/design/ocean.md §4.2), and later waters are meant to reuse it.
##
## **Nothing here knows what an id is.** A caller files every id it wants found
## at the point it is at, moves it when it moves, takes it out when it goes, and
## asks for the ids near a circle.
##
## **A query can answer more than the truth and never less.** It hands back
## every id in every bucket the circle touches, and the caller keeps its own
## exact distance test on what comes back. That is the whole contract, and
## drop_probe's grid check holds it against brute force.
##
## **Incremental.** An id changes bucket only when a move crosses a bucket
## line, which [method move] finds with a subtraction and a compare. Rebuilt
## every frame, the prototype's grid cost 280-320 µs a frame; kept this way,
## 9-12 µs (§4.2).
##
## A point off the square is filed in the nearest edge bucket, so it is still
## found -- only less cheaply. The edge buckets stand for everything beyond
## them, and every query treats them so.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## Side of one bucket, in the caller's units.
var size := 400.0
## The square's top-left corner.
var origin := Vector2.ZERO
## Buckets across and down. The square is `columns * size` on a side.
var columns := 1
var rows := 1

## The first id in each bucket, -1 for an empty one.
var _head := PackedInt32Array()
## The id after each id in its bucket, -1 at the end of one.
var _next := PackedInt32Array()
## The bucket each id is filed in, -1 for an id that is not.
var _where := PackedInt32Array()
## A hair past every reach asked for: a ten-thousandth of a bucket. A caller
## whose own distance test rounds the other way at a bucket line still gets
## back everything it keeps.
var _pad := 0.04


## A square of side `2 * half` round [param center], cut into buckets of side
## [param bucket].
func _init(center := Vector2.ZERO, half := 0.0, bucket := 400.0) -> void:
	setup(center, half, bucket)


## **Starts over on a new square**, every id forgotten. Also how the whole
## square moves: set it up again round the new centre and file every id anew.
func setup(center: Vector2, half: float, bucket: float) -> void:
	size = maxf(bucket, 0.001)
	_pad = size * 1e-4
	columns = maxi(ceili(2.0 * maxf(half, 0.0) / size), 1)
	rows = columns
	origin = center - Vector2(float(columns), float(rows)) * size * 0.5
	_head.resize(columns * rows)
	_head.fill(-1)
	_where.fill(-1)


## The bucket [param at] falls in, clamped onto the square.
func bucket_of(at: Vector2) -> int:
	var cx := clampi(floori((at.x - origin.x) / size), 0, columns - 1)
	var cy := clampi(floori((at.y - origin.y) / size), 0, rows - 1)
	return cy * columns + cx


## Whether [param id] is filed.
func has(id: int) -> bool:
	return id >= 0 and id < _where.size() and _where[id] >= 0


## **Files [param id] at [param at].** An id that is already filed is moved
## there, so inserting twice never lists one id in two buckets.
func insert(id: int, at: Vector2) -> void:
	if id < 0:
		return
	if id >= _where.size():
		_grow(id + 1)
	var c := bucket_of(at)
	var was := _where[id]
	if was == c:
		return
	if was >= 0:
		_unlink(id, was)
	_next[id] = _head[c]
	_head[c] = id
	_where[id] = c


## **[param id] is now at [param at].** Re-filed only if that is another
## bucket; returns whether it was. An id that was never filed is filed.
func move(id: int, at: Vector2) -> bool:
	if id < 0:
		return false
	if id >= _where.size() or _where[id] != bucket_of(at):
		insert(id, at)
		return true
	return false


## [param id] is gone. Nothing happens for an id that is not filed.
func remove(id: int) -> void:
	if not has(id):
		return
	_unlink(id, _where[id])
	_where[id] = -1


## **Appends to [param out] every id in every bucket the circle round
## [param at] of radius [param reach] touches.** The caller tests the exact
## distance. Row by row, only the buckets the circle's chord across that row
## reaches, so a wide query does not pay for the corners of its square. A reach
## within one bucket takes the box round the circle instead, as the prototype's
## grid did for every reach: at three buckets a side at most there are no
## corners worth the trimming, and not trimming is faster.
func query(at: Vector2, reach: float, out: PackedInt32Array) -> void:
	var r := maxf(reach, 0.0) + _pad
	var y0 := clampi(floori((at.y - r - origin.y) / size), 0, rows - 1)
	var y1 := clampi(floori((at.y + r - origin.y) / size), 0, rows - 1)
	if r <= size:
		var bx0 := clampi(floori((at.x - r - origin.x) / size), 0, columns - 1)
		var bx1 := clampi(floori((at.x + r - origin.x) / size), 0, columns - 1)
		for cy in range(y0, y1 + 1):
			var row := cy * columns
			for cx in range(bx0, bx1 + 1):
				var i := _head[row + cx]
				while i >= 0:
					out.append(i)
					i = _next[i]
		return
	for cy in range(y0, y1 + 1):
		# How far the centre is from this row, the edge rows reaching on past
		# the square: they hold everything filed beyond it.
		var dy := 0.0
		var top := origin.y + float(cy) * size
		if cy > 0 and at.y < top:
			dy = top - at.y
		elif cy < rows - 1 and at.y > top + size:
			dy = at.y - (top + size)
		if dy > r:
			continue
		var chord := sqrt(r * r - dy * dy)
		var x0 := clampi(floori((at.x - chord - origin.x) / size), 0, columns - 1)
		var x1 := clampi(floori((at.x + chord - origin.x) / size), 0, columns - 1)
		var row := cy * columns
		for cx in range(x0, x1 + 1):
			var i := _head[row + cx]
			while i >= 0:
				out.append(i)
				i = _next[i]


func _grow(capacity: int) -> void:
	var old := _where.size()
	var room := maxi(capacity, old * 2)
	_next.resize(room)
	_where.resize(room)
	for k in range(old, room):
		_where[k] = -1


## Takes [param id] out of bucket [param c]'s list. A bucket holds a handful of
## ids at the densities this is sized for, so the walk is short.
func _unlink(id: int, c: int) -> void:
	var i := _head[c]
	if i == id:
		_head[c] = _next[id]
		return
	while i >= 0:
		var n := _next[i]
		if n == id:
			_next[i] = _next[id]
			return
		i = n
