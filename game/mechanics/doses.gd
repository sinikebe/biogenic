extends RefCounted
## **Doses**: a body's loads of each kind -- how they wear off, and what each does
## while it lasts (docs/design/dna-slots.md §6).
##
## The owner's *stack*, made generic. **A load is a number of stacks of one kind
## on one body.** It wears off over time, exponentially, and acts while it lasts:
## harm takes the body apart as it wears, paralysis slows it, sleep silences it.
## This file knows the arithmetic of a load and nothing else -- no gene, no cell,
## no toxin, and no number of its own: every tau, every cutoff and every size is
## an argument, and the game's numbers live beside the other tables in
## `cell.gd`. A second water, a second toxin or a second kind adds rows there and
## touches nothing here.
##
## **Why exponential**: `stacks x e^(-t / tau)` is linear in stacks, so a stack
## does the same however many share its body and no stack needs a clock of its
## own -- a load is one number a kind. And it has a closed form, so a step of any
## length is exact: the drop steps its far bodies a fraction of the frames its
## near ones get, and a body stepped every eighth frame must end where one stepped
## every frame does (dna-slots.md §20.3 check 4).
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The kinds of load, and the index of each in a body's loads. **Phase 1 delivers
## harm alone**; paralysis and sleep are laid out now so that phases 3 and 4 add
## kinds and reshape nothing -- the wire, the save and the replay already carry
## three numbers a body.
enum Kind { HARM, PARALYSIS, SLEEP }
## How many kinds a body's loads hold.
const KINDS := 3

## **The kinds by name**, as a form's strain names them (genome.gd's FORMS): the
## one edge where a word meets an index.
const BY_NAME := {&"harm": Kind.HARM, &"paralysis": Kind.PARALYSIS,
	&"sleep": Kind.SLEEP}


## A body's loads with nothing in them: one fresh array a body, never shared --
## a packed array is passed by reference, and two bodies holding one array would
## share every dose.
static func none() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(KINDS)
	out.fill(0.0)
	return out


## The kind a strain named [param strain] delivers, or -1 for none.
static func kind_of(strain: StringName) -> int:
	return int(BY_NAME.get(strain, -1))


## **How strongly [param stacks] act on a body**: `stacks x (size / radius)^2`.
## A dose is an amount, and a body twice as wide has four times the area to spread
## it over -- the game is flat, so area stands for mass -- which is how real
## toxicity is measured too, per unit of body. [param size] is the body a stack is
## quoted for, [param radius] the body it is in.
static func felt(stacks: float, radius: float, size: float) -> float:
	var r := maxf(radius, 0.001)
	return stacks * (size / r) * (size / r)


## **Whether [param loads] carry anything at all**: the one test a body with
## nothing in it costs.
static func any(loads: PackedFloat64Array) -> bool:
	for stacks: float in loads:
		if stacks > 0.0:
			return true
	return false


## **Wears [param loads] by [param delta] seconds**, in place: each kind at its
## own tau in [param taus], in closed form, and a kind that falls below
## [param gone] stacks cleared whole.
##
## Returns `Vector2(harm stacks that wore off, seconds of the step left after the
## harm ran out)`. **Harm is delivered as it wears**, every stack of it -- the
## remainder a cutoff clears is delivered with it, so one stack is worth exactly
## what it says however the steps fall. The seconds left are the part of the step
## mending may have: none while harm is still there, all of it when there was
## none, and the rest of the step after the moment it ran out.
static func wear(loads: PackedFloat64Array, delta: float, taus: Array,
		gone: float) -> Vector2:
	var worn := 0.0
	var left := maxf(delta, 0.0)
	for k in loads.size():
		var stacks := loads[k]
		if stacks <= 0.0:
			continue
		var tau := maxf(float(taus[k]) if k < taus.size() else 1.0, 0.001)
		var after := stacks * exp(-maxf(delta, 0.0) / tau)
		if after < gone:
			# Gone within the step: at `tau ln(stacks / gone)`, the moment it
			# crossed the cutoff -- at once for a load already under it.
			if k == Kind.HARM:
				var out := tau * log(stacks / gone) if stacks > gone else 0.0
				left = maxf(delta - out, 0.0)
				worn = stacks
			after = 0.0
		elif k == Kind.HARM:
			left = 0.0
			worn = stacks - after
		loads[k] = after
	return Vector2(worn, left)


## **How free a body is to move**, 1 free .. 0 stopped, under a paralysing load
## that stops a body of [param size] at [param full] stacks. Phase 3's.
static func still(loads: PackedFloat64Array, radius: float, size: float,
		full: float) -> float:
	if loads.size() <= Kind.PARALYSIS or full <= 0.0:
		return 1.0
	return clampf(1.0 - felt(loads[Kind.PARALYSIS], radius, size) / full, 0.0, 1.0)


## **Whether a body is asleep**: its sleeping load, felt, at least [param at].
## Phase 4's.
static func asleep(loads: PackedFloat64Array, radius: float, size: float,
		at: float) -> bool:
	if loads.size() <= Kind.SLEEP or at <= 0.0:
		return false
	return felt(loads[Kind.SLEEP], radius, size) >= at


## **A hit wakes a body**: its sleeping load goes, before the stacks of that same
## hit are added (dna-slots.md §6.4). Phase 4's.
static func wake(loads: PackedFloat64Array) -> void:
	if loads.size() > Kind.SLEEP:
		loads[Kind.SLEEP] = 0.0


## **Whether a body may mend**: not while it carries any harm. The body cannot
## repair while it is being harmed.
static func mends(loads: PackedFloat64Array) -> bool:
	return loads.size() <= Kind.HARM or loads[Kind.HARM] <= 0.0
