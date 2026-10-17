extends RefCounted
## **A field of view over round things**: what an eye at one point sees of the
## circles round it. Nearer things hide what is behind them, an eye sees only
## inside its field, light sets how far it sees, and its sharpness sets how
## much of a small thing comes through. docs/design/sight.md.
##
## Nothing here knows what the eye is on or what the things are: a thing is a
## bearing, a distance, a radius and an id, and the caller decides what an id
## means, what a sighting is worth to it and what it draws. Later versions of
## the game reuse this with other parts, which is why no cell or gene is named
## in this file.
##
## Bearings are radians about any one zero the caller keeps -- `food.gd` uses the
## body's front, clockwise -- and every angle here is measured in that frame.
##
## No class_name, for the reason signal_bus.gd gives: a content pack mounts over
## an older binary, and a global class a pack introduces is not in that binary's
## class list. Preload it by path.


## **What an eye looking along [param middle], [param half] radians either side,
## sees of [param things]**: each `[bearing, distance, radius, id]`, its distance
## from the eye to its centre.
##
## Returns each thing at least part of which is in the field and not behind
## something nearer, nearest first, as `[bearing, distance, radius, id, seen]`:
## the middle of the widest part of it left in sight, and how wide all of what is
## left is, in radians. A thing the eye is inside fills the field.
##
## **Nearer first by its near side**, `distance - radius`, which is the order a
## ray out of the eye meets them in for any two that do not overlap.
static func view(things: Array, middle: float, half: float) -> Array:
	var order := things.duplicate()
	order.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[1]) - float(a[2]) < float(b[1]) - float(b[2]))
	# What is already hidden: disjoint [low, high] pairs about `middle`, in order.
	var covered := PackedFloat32Array()
	var out: Array = []
	for thing: Array in order:
		var d := float(thing[1])
		var r := float(thing[2])
		var rel := angle_difference(middle, float(thing[0]))
		var w := PI * 0.5 if d <= r else asin(r / d)
		var low := maxf(rel - w, -half)
		var high := minf(rel + w, half)
		if low >= high:
			continue
		var seen := 0.0
		var best_low := 0.0
		var best_high := 0.0
		var at := low
		var k := 0
		while at < high:
			# Skip the hidden pairs that end before `at`.
			while k < covered.size() and covered[k + 1] <= at:
				k += 2
			var next_low := high
			if k < covered.size():
				if covered[k] <= at:
					at = covered[k + 1]
					continue
				next_low = minf(covered[k], high)
			if next_low > at:
				seen += next_low - at
				if next_low - at > best_high - best_low:
					best_low = at
					best_high = next_low
			at = next_low
		covered = _cover(covered, low, high)
		if seen <= 0.0:
			continue
		out.append([wrapf(middle + 0.5 * (best_low + best_high), -PI, PI), d, r,
			thing[3], seen])
	return out


## **Where a ray out of the eye along [param bearing] first meets one of
## [param things]**, `[bearing, distance, radius, id]` as [method view] takes
## them: the distance to it, or [param reach] when it meets nothing nearer.
static func cast(things: Array, bearing: float, reach: float) -> float:
	var best := reach
	for thing: Array in things:
		var d := float(thing[1])
		var r := float(thing[2])
		var off := angle_difference(bearing, float(thing[0]))
		var along := d * cos(off)
		if along <= 0.0 or along - r > best:
			continue
		var perp := absf(d * sin(off))
		if perp >= r:
			continue
		var hit := along - sqrt(maxf(r * r - perp * perp, 0.0))
		if hit >= 0.0 and hit < best:
			best = hit
	return best


## **How much of a thing [param seen] radians wide comes through an eye that
## blurs over [param blur] radians**, 0..1: all of it once it is as wide as the
## blur, and in proportion below that -- a small thing smeared over a wide blur
## is a faint one.
static func clarity(seen: float, blur: float) -> float:
	if blur <= 0.0:
		return 1.0 if seen > 0.0 else 0.0
	return clampf(seen / blur, 0.0, 1.0)


## **How much of a thing at [param distance] the water lets through**, 0..1: all
## of it inside [param core], nothing at [param reach], a straight ramp between.
static func haze(distance: float, core: float, reach: float) -> float:
	if reach <= core:
		return 1.0 if distance < reach else 0.0
	return clampf((reach - distance) / (reach - core), 0.0, 1.0)


## **How much an eye keeps in [param light]**, 0..1: [param dark] of it with no
## light at all, everything in full light.
static func seeing(light: float, dark: float) -> float:
	return lerpf(dark, 1.0, clampf(light, 0.0, 1.0))


## **How wide an eye at [param level] blurs**, in the unit [param start] and
## [param finest] are in: [param start] at level 1, sharper every level and
## never past [param finest] -- each level takes off less than the one before.
static func blur_at(level: int, start: float, finest: float) -> float:
	return finest + (start - finest) / float(maxi(level, 1))


## [param covered] with [param low]..[param high] added, still disjoint and in
## order.
static func _cover(covered: PackedFloat32Array, low: float, high: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var placed := false
	var k := 0
	while k < covered.size():
		var a := covered[k]
		var b := covered[k + 1]
		if b < low:
			out.append(a)
			out.append(b)
		elif a > high:
			if not placed:
				out.append(low)
				out.append(high)
				placed = true
			out.append(a)
			out.append(b)
		else:
			low = minf(low, a)
			high = maxf(high, b)
		k += 2
	if not placed:
		out.append(low)
		out.append(high)
	return out
