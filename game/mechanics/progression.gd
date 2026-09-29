extends RefCounted
## **Experience, a level, and one fork.** Nothing here knows what earns the
## experience or what a level buys: whatever owns a progression decides both.
## The first owner is the beam (docs/design/beam-levels.md). Later versions of
## the game are to reuse these systems with other parts entirely, which is why
## no cell, gene or eye is named in this file.
##
## **The level is derived, never stored.** Going from level L to L + 1 costs
## `step * L`, so level L is reached at `step * L * (L - 1) / 2` in total: each
## level takes a little longer than the last, and none of them is the last.
##
## **The fork.** At [member fork_level] the progression offers [member paths].
## Until one is taken, experience keeps counting but [method effective_level]
## stays at the fork: the levels are banked, and all of them arrive the moment a
## path is taken. A path, once taken, is for good -- the choice is meant to
## matter.
##
## No class_name, for the reason signal_bus.gd gives: a content pack mounts over
## an older binary, and a global class a pack introduces is not in that
## binary's class list. Preload it by path.

## Experience earned. It is never spent and never lost.
var xp := 0.0
## The path taken at the fork, &"" until one is.
var path: StringName = &""
## What going from level L to L + 1 costs, divided by L.
var step := 60.0
## The level the fork opens at, 0 for a progression with no fork.
var fork_level := 0
## What the fork offers. Taking anything else is refused.
var paths: Array[StringName] = []


func _init(cost_step: float = 60.0, fork_at: int = 0,
		choices: Array[StringName] = []) -> void:
	step = maxf(cost_step, 0.001)
	fork_level = maxi(fork_at, 0)
	paths = choices.duplicate()


## The level, 1 with no experience at all.
func level() -> int:
	return level_at(xp, step)


## **The level the owner works at**: [method level], held at the fork until a
## path is taken.
func effective_level() -> int:
	var at := level()
	if fork_level > 0 and path == &"":
		return mini(at, fork_level)
	return at


## True while the fork is open and nothing has been taken.
func can_choose() -> bool:
	return fork_level > 0 and path == &"" and level() >= fork_level


## Takes [param choice] at the fork. False, and nothing changes, when the fork
## is not open or [param choice] is not one of [member paths].
func choose(choice: StringName) -> bool:
	if not can_choose() or not paths.has(choice):
		return false
	path = choice
	return true


## Adds experience. Anything not above zero is ignored.
func earn(amount: float) -> void:
	if amount > 0.0:
		xp += amount


## How far through the current level, 0 at its start and 1 at the next.
func progress() -> float:
	var at := level()
	return clampf((xp - xp_at(at, step)) / (step * float(at)), 0.0, 1.0)


## Experience still to earn before the next level.
func to_next() -> float:
	return maxf(xp_at(level() + 1, step) - xp, 0.0)


## A separate progression with the same rules and the same state. A daughter
## gets one of these, never her mother's.
func copy() -> RefCounted:
	var twin: RefCounted = get_script().new(step, fork_level, paths)
	twin.xp = xp
	twin.path = path
	return twin


## The state, without the rules: what a recording keeps. The rules come back
## from whoever owns the progression, through [method _init].
func to_state() -> Array:
	return [xp, path]


## Puts back what [method to_state] took. A path this progression does not
## offer -- one from some other build -- is left untaken rather than trusted.
func set_state(state: Array) -> void:
	if state.size() < 2:
		return
	xp = maxf(float(state[0]), 0.0)
	var taken := StringName(state[1])
	path = taken if paths.has(taken) else &""


## The level [param total] experience reaches, 1 at none.
static func level_at(total: float, cost_step: float) -> int:
	if total <= 0.0 or cost_step <= 0.0:
		return 1
	var at := int(floorf((1.0 + sqrt(1.0 + 8.0 * total / cost_step)) * 0.5))
	# The square root can land a hair either side of an exact boundary; settle
	# it on the integers, which are what the curve is defined by.
	while at > 1 and xp_at(at, cost_step) > total:
		at -= 1
	while xp_at(at + 1, cost_step) <= total:
		at += 1
	return maxi(at, 1)


## The experience at which level [param at] begins.
static func xp_at(at: int, cost_step: float) -> float:
	return cost_step * float(at) * float(at - 1) * 0.5
