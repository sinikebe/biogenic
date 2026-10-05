extends RefCounted
## **The shape kinds** (docs/design/gene-looks.md §2, §3, §7): what an organ is
## drawn as. Nine kinds, each a generator in `cilia.gd` with a few parameters, drawn
## on a body's arc or a tile's dome by the same code. **A new organ picks a kind and
## its numbers**; it needs drawing code only when it wants a parameter value that
## does not exist yet -- a new tip, form or head, which is a few lines in that
## kind's generator, a value here, and a render.
##
## For each kind, this file holds its parameters -- the default, the range or the
## values allowed, and whether it is **structural** (identity: a tip, a bend, a
## form, the waves, the turns, the lips) or **magnitude** (never identity: a count,
## a length, a fan, a wave's swing, a bulge, a size) -- and the **seat** a variant's
## accent goes in, with the mark the seat shows as shipped (§3.1). **Tier is
## magnitude** (§2.3): copies make an organ longer, denser, brighter and wider, and
## an organelle one more of itself, but never change a kind, a tip, a bend, a form,
## the waves or a mark. So the gene probe never counts a count or a length as what
## tells two organs apart.
##
## **Data only**, so the catalogue validates a look without preloading a view
## (gene-catalogue.md §4.1). Preloads nothing.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

# --- The kinds --------------------------------------------------------------------

## The eating build: dense fine cilia just off the skin, a beat travelling along
## them -- oral membranelles.
const MAT := &"mat"
## The moving builds, things that **beat**: rowing strokes with a knee on both flanks
## (cirri); long strands with a wave travelling to the tip (flagella); a zigzag spring
## that draws up and lets go (a myoneme's spasmoneme).
const OARS := &"oars"
const LASH := &"lash"
const COIL := &"coil"
## The sensing builds, things that **stand still** over a pigment: stiff bristles
## (sensory cilia are non-motile), or a lens on the skin (an eyespot's).
const TUFT := &"tuft"
const LENS := &"lens"
## The defending builds, things that are **armed or plated**: hard shafts with heads
## (extrusomes), or scales along the skin (the pellicle's alveolar plates).
const SPINES := &"spines"
const PLATES := &"plates"
## The metabolism build: bodies **inside the skin** at the arc, nothing outside it
## (plastids, vacuoles, mitochondria).
const ORGANELLE := &"organelle"
## Every kind there is. The gene probe fails a look of any other.
const KINDS: Array[StringName] = [MAT, OARS, LASH, COIL, TUFT, LENS, SPINES, PLATES,
	ORGANELLE]

# --- Their structural values --------------------------------------------------------

## A tuft's tips (§2.1): a plain bristle; forked; a ring, the pores of a cluster; a
## crook; three-way, which reads only on a tile.
const TIP_PLAIN := &"plain"
const TIP_FORK := &"fork"
const TIP_RING := &"ring"
const TIP_HOOK := &"hook"
const TIP_TRI := &"tri"
## A spine's heads: a spear (a trichocyst's spindle), a bead (a toxin's), a barbed
## hook, which reads only on a tile.
const TIP_SPEAR := &"spear"
const TIP_BEAD := &"bead"
const TIP_BARB := &"barb"
## An organelle's forms: a solid lens (a plastid); a clear bubble (a vacuole); a
## long rod with a fold (a mitochondrion); a stack of flat cisternae; a bubble with
## canals running out of it (a contractile vacuole).
const FORM_LENS := &"lens"
const FORM_BUBBLE := &"bubble"
const FORM_CAPSULE := &"capsule"
const FORM_STACK := &"stack"
const FORM_STAR := &"star"

# --- Accents (§3) -------------------------------------------------------------------

## **A variant keeps its organ's look and changes one mark, its accent**, drawn at
## its kind's seat: a filled disc; a hollow ring, its stroke 0.42 of its radius; a
## diamond, a square on its point, square to the skin; a bar, a short slab lying
## along the skin. [constant MARK_NONE] is a seat that shows nothing as shipped.
const MARK_NONE := &"none"
const MARK_DISC := &"disc"
const MARK_RING := &"ring"
const MARK_DIAMOND := &"diamond"
const MARK_BAR := &"bar"
## The four a variant may wear. One variant more than its seat has marks to spare
## fails the gene probe: that is a new organ, not a variant.
const ACCENTS: Array[StringName] = [MARK_DISC, MARK_RING, MARK_DIAMOND, MARK_BAR]

## **The seats** (§3.1): the pigment under a sense, a variant's mark drawn at 0.85 of
## the disc; every bead of a bead-headed spine; the centre of each organelle; and a
## **basal body**, 0.11 of the radius inside the skin at the arc's middle, where
## every cilium and flagellum is rooted in a real cell -- so an organ that beats
## shows its variant at its root, where nothing else is drawn.
const SEAT_PIGMENT := &"pigment"
const SEAT_BEADS := &"beads"
const SEAT_CENTRE := &"centre"
const SEAT_BASAL := &"basal"

# --- The parameters -----------------------------------------------------------------

## A parameter that is identity, and one that never is.
const STRUCTURAL := &"structural"
const MAGNITUDE := &"magnitude"
## **How a structural number is compared**, for the probe's *different at a glance*
## (§2.4): a bend by whether there is one (straight or bent); waves and turns by the
## whole number of them (a 2.1-wave whip is a two-wave lash). A tip, a form or the
## lips by the value itself.
const SAME_IF_BOTH_STRAIGHT := &"bent"
const SAME_IF_SAME_WHOLE := &"whole"

## **Every kind's parameters, seat and mark** (§2.1). Lengths are fractions of the
## body radius at one copy; a fan and a bend are degrees. Each parameter is its
## default, its `range` (numbers) or its `values`, and its `role`. A structural
## number says how it is compared (`same`). A kind's `tips` move its seat for a tip
## that carries one: a bead-headed spine's accent is its beads, a spear's its basal
## body. **The home organs are kinds too**: the mouth's mat, the cirrus's oars and the
## tail's lash take today's constants as their defaults, so a born body draws exactly
## what it drew before there were kinds.
const ROWS := {
	MAT: {"seat": SEAT_BASAL, "mark": MARK_NONE, "params": {
		"count": {"default": 15, "range": [4, 24], "role": MAGNITUDE},
		"length": {"default": 0.27, "range": [0.10, 0.50], "role": MAGNITUDE}}},
	OARS: {"seat": SEAT_BASAL, "mark": MARK_NONE, "params": {
		"count": {"default": 5, "range": [1, 8], "role": MAGNITUDE},
		"length": {"default": 0.34, "range": [0.15, 0.60], "role": MAGNITUDE},
		"knee": {"default": 0.62, "range": [0.30, 0.85], "role": MAGNITUDE},
		"bend": {"default": 34.0, "range": [0.0, 60.0], "role": STRUCTURAL,
			"same": SAME_IF_BOTH_STRAIGHT}}},
	LASH: {"seat": SEAT_BASAL, "mark": MARK_NONE, "params": {
		"count": {"default": 6, "range": [1, 8], "role": MAGNITUDE},
		"length": {"default": 0.62, "range": [0.20, 0.80], "role": MAGNITUDE},
		"wave": {"default": 0.26, "range": [0.0, 0.50], "role": MAGNITUDE},
		"waves": {"default": 1.0, "range": [0.5, 4.0], "role": STRUCTURAL,
			"same": SAME_IF_SAME_WHOLE}}},
	COIL: {"seat": SEAT_BASAL, "mark": MARK_NONE, "params": {
		"count": {"default": 1, "range": [1, 3], "role": MAGNITUDE},
		"length": {"default": 0.40, "range": [0.20, 0.60], "role": MAGNITUDE},
		"turns": {"default": 2, "range": [1, 5], "role": STRUCTURAL,
			"same": SAME_IF_SAME_WHOLE}}},
	TUFT: {"seat": SEAT_PIGMENT, "mark": MARK_DISC, "params": {
		"count": {"default": 3, "range": [1, 8], "role": MAGNITUDE},
		"length": {"default": 0.30, "range": [0.12, 0.60], "role": MAGNITUDE},
		"tip": {"default": TIP_PLAIN, "values": [TIP_PLAIN, TIP_FORK, TIP_RING, TIP_HOOK,
			TIP_TRI], "role": STRUCTURAL},
		"bend": {"default": 0.0, "range": [0.0, 45.0], "role": STRUCTURAL,
			"same": SAME_IF_BOTH_STRAIGHT},
		"fan": {"default": 16.0, "range": [0.0, 30.0], "role": MAGNITUDE}}},
	LENS: {"seat": SEAT_PIGMENT, "mark": MARK_DISC, "params": {
		"bulge": {"default": 0.20, "range": [0.10, 0.35], "role": MAGNITUDE}}},
	SPINES: {"seat": SEAT_BASAL, "mark": MARK_NONE, "params": {
		"count": {"default": 3, "range": [1, 6], "role": MAGNITUDE},
		"length": {"default": 0.30, "range": [0.15, 0.50], "role": MAGNITUDE},
		"tip": {"default": TIP_SPEAR, "values": [TIP_SPEAR, TIP_BEAD, TIP_BARB],
			"role": STRUCTURAL},
		"fan": {"default": 14.0, "range": [0.0, 30.0], "role": MAGNITUDE},
		# **n a copy**, in place of `count`, for an organ that grows in pairs; 0 for
		# none.
		"per_copy": {"default": 0, "range": [0, 3], "role": MAGNITUDE},
		# **On the lips** in a front slot: fangs on the lip bow, riding the bite.
		"lips": {"default": false, "values": [false, true], "role": STRUCTURAL}},
		"tips": {TIP_BEAD: {"seat": SEAT_BEADS, "mark": MARK_DISC}}},
	PLATES: {"seat": SEAT_BASAL, "mark": MARK_NONE, "params": {
		"count": {"default": 3, "range": [1, 6], "role": MAGNITUDE}}},
	ORGANELLE: {"seat": SEAT_CENTRE, "mark": MARK_NONE, "params": {
		"form": {"default": FORM_BUBBLE, "values": [FORM_LENS, FORM_BUBBLE, FORM_CAPSULE,
			FORM_STACK, FORM_STAR], "role": STRUCTURAL},
		"size": {"default": 0.17, "range": [0.10, 0.25], "role": MAGNITUDE},
		"depth": {"default": 0.30, "range": [0.15, 0.45], "role": MAGNITUDE}}},
}

## **The fields a look may hold besides its kind's parameters**: its kind (`shape`)
## and its family's shade, 0 to 2 (the middle where it sets none) -- and, on a
## variant, its accent, which is the only field of a look a variant may set (§7).
const LOOK_FIELDS: Array[String] = ["shape", "shade"]
const VARIANT_FIELDS: Array[String] = ["accent"]
## The shade a look takes where it sets none, as families.gd says.
const DEFAULT_SHADE := 1


## Whether [param kind] is one of [constant KINDS].
static func has(kind: StringName) -> bool:
	return ROWS.has(kind)


## **[param look] with every parameter its kind has**, a default where it sets none,
## its `shade`, and its accent's seat resolved: `seat`, `shipped` (the mark the seat
## shows as shipped) and `mark` (what is drawn there: the variant's `accent`, else
## the shipped mark). What `cilia.gd` draws by, one lookup a parameter. A look of no
## kind this file knows -- an unknown key's, which has none -- is a plain tuft.
static func resolved(look: Dictionary) -> Dictionary:
	var kind := StringName(look.get("shape", TUFT))
	if not ROWS.has(kind):
		kind = TUFT
	var row: Dictionary = ROWS[kind]
	var out := {"shape": kind, "shade": int(look.get("shade", DEFAULT_SHADE))}
	var params: Dictionary = row["params"]
	for name: String in params:
		out[name] = look.get(name, (params[name] as Dictionary)["default"])
	var seat: StringName = row["seat"]
	var shipped: StringName = row["mark"]
	var tips: Dictionary = row.get("tips", {})
	if out.has("tip") and tips.has(out["tip"]):
		seat = (tips[out["tip"]] as Dictionary)["seat"]
		shipped = (tips[out["tip"]] as Dictionary)["mark"]
	out["seat"] = seat
	out["shipped"] = shipped
	var accent := StringName(look.get("accent", &""))
	out["accent"] = accent
	out["mark"] = accent if accent != &"" else shipped
	return out


## **What tells [param look] apart at a glance** (§2.4): its kind and its structural
## parameters, each compared as its row says -- never a count, a length or a shade.
## Two organs of one family with the same signature are the same organ to a player.
static func signature(look: Dictionary) -> Array:
	var full := resolved(look)
	var out: Array = [full["shape"]]
	var params: Dictionary = (ROWS[full["shape"]] as Dictionary)["params"]
	for name: String in params:
		var param: Dictionary = params[name]
		if param["role"] != STRUCTURAL:
			continue
		var value: Variant = full[name]
		match StringName(param.get("same", &"")):
			SAME_IF_BOTH_STRAIGHT:
				value = not is_zero_approx(float(value))
			SAME_IF_SAME_WHOLE:
				value = roundi(float(value))
		out.append([name, value])
	return out


## **What is wrong with [param look]'s fields**, one line each, empty for nothing: a
## kind there is, every field one the look or its kind knows, every number inside
## its range and every value one allowed, a shade of 0 to 2 -- and, unless
## [param variant], no accent, which only a variant sets.
static func faults(look: Dictionary, variant := false) -> Array[String]:
	var out: Array[String] = []
	var kind := StringName(look.get("shape", &""))
	if not ROWS.has(kind):
		out.append("its shape %s" % (kind if kind != &"" else &"(none)"))
		return out
	var params: Dictionary = (ROWS[kind] as Dictionary)["params"]
	for field: Variant in look:
		var name := String(field)
		if LOOK_FIELDS.has(name) or (variant and VARIANT_FIELDS.has(name)):
			continue
		if not params.has(name):
			out.append("its look field %s, which a %s has not" % [name, kind])
			continue
		var param: Dictionary = params[name]
		var value: Variant = look[field]
		if param.has("values"):
			if not (param["values"] as Array).has(value):
				out.append("its %s %s, not one of %s" % [name, str(value),
					str(param["values"])])
			continue
		# A count is a whole number; any other number may be written either way.
		var whole := typeof(param["default"]) == TYPE_INT
		var number := typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
		if not number or (whole and typeof(value) != TYPE_INT):
			out.append("its %s %s, not a %s" % [name, str(value),
				"whole number" if whole else "number"])
			continue
		var span: Array = param["range"]
		if float(value) < float(span[0]) or float(value) > float(span[1]):
			out.append("its %s %s, outside %s to %s" % [name, str(value), str(span[0]),
				str(span[1])])
	var shade: Variant = look.get("shade", DEFAULT_SHADE)
	if not shade is int or int(shade) < 0 or int(shade) > 2:
		out.append("its shade %s, not 0, 1 or 2" % str(shade))
	if look.has("accent") and not variant:
		out.append("an accent, which only a variant sets")
	return out
