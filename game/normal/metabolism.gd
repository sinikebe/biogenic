extends Node
## Hunger, and the one place where hunger becomes a beat.
##
## The owner's decision (docs/design/perception.md §6.2): the metabolic beat
## rate *is* the hunger readout. One signal carries both "I exist" and "I am
## running out", so hunger is a perception parameter, not just a survival
## number.
##
## **Food, a waiting gene and a coming division are off it** (the owner,
## 2026-09-29: "too much info from one thing"). The beat used to quicken in rich
## water, echo a second time for a gene waiting to be placed, and run up before
## a division. Food is found with the senses now; a waiting gene and a coming
## division are read off the cell, which draws both in either view. What is
## left is hunger, from this file, and dread's stumble and drain, which
## signal_bus.gd lays over it.
##
## Everything that maps hunger to how the membrane reads lives in this file and
## nowhere else -- change starvation balance here and you can see, in the same
## screenful, what it does to legibility.
##
## **Starving is an alarm, said three ways** (docs/design/hunger.md; the owner,
## 2026-10-03: "I often die of hunger without noticing anything"). The beat it
## replaces slowed and dimmed as death came, and a warning that gets quieter as
## the danger rises read as nothing at all. Now, from half a tank, the beat
## races at full strength ([method beat_period]) and the body goes slack
## ([method hungry], which the run draws as creases); when the tank empties the
## membrane falls in, and closes further through the grace ([method faint]). A
## meal undoes all three. No words, and no balance moved: these are thresholds
## for *noticing*, and the pace, the meal and the grace are below as they were.
##
## **The arithmetic of a tank is in static functions** -- [method rest_rate],
## [method effort_cost], [method meal] -- and this node's [method _process],
## [method spend] and [method feed] are their callers, as the water's bodies
## will be (docs/design/ocean.md §5.2, §14.1). So the player's pace and the
## drop's are one definition: a change to one is a change to the other, and
## drop_probe's metabolism check holds the node and the functions to the same
## hunger. They know a tank and nothing else -- light and absorption are the
## callers' names for an income.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## Emitted whenever hunger moves, for anything that wants to watch starvation
## without polling.
signal hunger_changed(hunger: float)

## Beat period when fed. The rest state of the whole game.
const REST_PERIOD := 2.4
## **Where the warning starts: half a tank.** At the usual pace that is twenty
## seconds from death, longer than a good forager's gap between meals (median
## 12.5 s, energy.md §7.3), so a cell that eats on time meets it only on its
## way to the next meal. hunger.md §3.
const HUNGRY_FROM := 0.5
## Seconds between beats when the tank is empty: twice the rest rate. The beat
## quickens toward it in a straight line from [constant HUNGRY_FROM].
const EMPTY_PERIOD := 1.2
## And at the very end of the grace: 80 a minute, three times the rest rate,
## and still longer than one beat's envelope lasts, so the beats stay separate
## instead of blurring into a glow.
const LAST_PERIOD := 0.75
## **How far the membrane falls the moment the tank empties**, as a share of
## the whole fall: the empty tank is an *event*, because it is where this
## game's own rule changes (spending stops and the grace starts). The rest of
## the fall comes through the grace.
const FAINT_ONSET := 0.35
## Every beat lands at full strength: hunger never dims it, only dread does.
## `STARVED_PERIOD` 4.8, `DYING_PERIOD` 7.5 and `STARVED_AMPLITUDE` 0.35 are
## retired with the slowing, dimming beat they drew (hunger.md §2.1).
const FULL_AMPLITUDE := 1.0

## Seconds from fed to starved **for a body at rest**, which no living cell is:
## every stroke and every turn is paid on top ([method spend],
## docs/design/energy.md).
##
## **Thirty-six, so a born cell that never eats dies at thirty seconds.** The
## owner, 2026-09-29: "starve after 30 seconds with spawn gear". Steering a
## third of the time, a born cell burns 1.78 times a resting one, so it is empty
## at 20 s, and [constant STARVE_GRACE] is the last ten. Drifting, it dies at
## 34 s; turning all the time, at 26 s. It was 420, seven minutes at rest. What
## moving costs is priced in seconds of rest, so it came down with this and kept
## its share.
##
## **This is the pace, and [constant MEAL] moves with it**: a meal has to buy
## enough of the tank to reach the next one (energy.md §7). cell.gd's
## `STROKE_COST` and `TURN_COST` are how much of the pace moving takes.
##
## **Owner's call 1** (energy.md §7.6), answered on 2026-09-29 with the
## recommended option: dead at thirty, twenty to empty and ten of grace. The
## other two were 45 with a grace of 5, and 53 with 10 (empty at thirty, dead
## at forty).
const HUNGER_SECONDS := 36.0
## What a meal your own size is worth: **the whole bar**. A drifter a born cell
## can swallow is worth half to four-fifths of it.
##
## It was half a bar, "so a single meal is felt and two are needed", while the
## bar lasted seven minutes. At thirty seconds half a bar is ten seconds of
## life, and a cell steered at every meal it could see on the screen, one every
## twelve seconds, starved in about half of its three-minute games. A whole bar
## loses a third fewer and keeps the bar in the middle on average. The rest are
## lost to stretches with no food on the screen that outlast a full tank, which
## no meal bridges (energy.md §7). **Owner's call 2** (energy.md §7.6),
## answered on 2026-09-29 with the recommended option: the whole bar, over three
## quarters and half.
##
## **This stays a const.** §3.2 took it off the tier table: if `cytostome` tier
## raised the value of a meal as well as the gape, every tier of it would
## increase your slack after upkeep *and* widen the menu, which makes the mouth
## a strictly dominant gene with no reason ever to put anything else in a slot.
## The meal is scaled by what the prey weighed instead, at the call site --
## food.gd measures it against your body, not against your gape.
const MEAL := 1.0
## Seconds at full hunger before the cell dies. It exists so that food ten
## seconds away is still worth swimming for, and now it is exactly that: ten of
## the thirty seconds a born cell has. It was forty while the tank was seven
## minutes (energy.md §7). The other half of **owner's call 1**, with
## [constant HUNGER_SECONDS].
const STARVE_GRACE := 10.0
## **What a body with no `cytostome` takes from the water**, in seconds of rest
## a second: exactly a one-gene drifter's upkeep, so a drifter at rest holds its
## tank where it is and dies only when something eats it (ocean.md §5.3, row
## 11). An income like `plastid`'s light, summed with it by the caller.
## Nothing in a run reads it yet: the drop's water and a mouthless player take
## it up in the next phase (§14.2).
const ABSORB := 1.0
## The smallest tank the arithmetic divides by, as a share of a born cell's.
const RESERVE_MIN := 0.05

## **What the metabolism gives a body's rules** (docs/design/behaviour.md §3.2),
## in the shape of `genome.gd`'s DECLARES: its `hunger`, the tank as a level,
## which the player feels as the beat; and `fed`, the seconds since its last
## meal -- a cell, a floc or you -- which a body knows because it is digesting.
## No bearing in either: they are the body's own state.
const DECLARES := {
	&"metabolism": {"in": [
		{"name": &"hunger", "bearing": false, "values": {&"level": &"level"}},
		{"name": &"fed", "bearing": false, "values": {&"seconds": &"seconds"}},
	]},
}

## **What the metabolism's parts are called** (docs/design/automation.md §13.1),
## beside [constant DECLARES], by qualified name: the words the programs page puts
## on a part's chip. Read through [method words_of].
##
## TRANSLATORS: The name of a sense on a small chip of the player's "instincts"
## (rules the player writes: "when <a sense reports something> -> <do this>").
## Lowercase, one short word. "hunger": how empty the cell's tank is; "meal": the
## time since the cell last ate.
## ROOM: 112 px at 15 px
const METABOLISM_SAYS := {
	&"metabolism.hunger": "hunger",
	&"metabolism.fed": "meal",
}
## **What the values they report are called**, by value name.
##
## TRANSLATORS: The name of a value a sense of the player's cell reports, which an
## "instinct" can test, on a small choice cell. Lowercase, one short word.
## "level": how full or empty; "seconds": how long ago.
## ROOM: 70 px at 14 px
const METABOLISM_VALUES := {
	&"level": "level",
	&"seconds": "seconds",
}
## **The line that explains each of them**: the chip's word, a middle dot, and
## what it is, in plain words.
##
## TRANSLATORS: Explains one sense or value of the player's "instincts", on one
## line under them: its name (the same word as on its chip), a middle dot, then
## what it is, lowercase. "Your tank" is how much food the cell has left; "the
## beat you feel" is the heartbeat the game plays, which slows as the tank empties.
## ROOM: 856 px at 15 px
const METABOLISM_EXPLAINS := {
	&"metabolism.hunger": "hunger · how empty your tank is: the beat you feel.",
	&"metabolism.fed": "meal · how long since you last ate: a cell, a floc, or one you"
		+ " chewed apart.",
	&"seconds": "seconds · how long ago, in seconds.",
}


## **A part's words, in the language of the moment** (automation.md §13.1), for
## the parts [constant DECLARES] names and the values they report: `{"says": its
## chip, "explains": its line}`, a key absent where there are none -- as
## `genome.gd` and `cell.gd` answer for theirs.
static func words_of(part: StringName) -> Dictionary:
	var out := {}
	if METABOLISM_SAYS.has(part):
		out["says"] = String(TranslationServer.translate(METABOLISM_SAYS[part]))
	elif METABOLISM_VALUES.has(part):
		out["says"] = String(TranslationServer.translate(METABOLISM_VALUES[part]))
	if METABOLISM_EXPLAINS.has(part):
		out["explains"] = String(TranslationServer.translate(METABOLISM_EXPLAINS[part]))
	return out

## 0.0 just fed, 1.0 fully starved.
var hunger := 0.0
## Metabolic multiplier, written once a frame by the run: 1.0 for a cell that
## is tier 1 across the board, and higher for every tier above that. **The
## price of power, and it is paid in the channel the game already reads** -- at
## rest a cell with one tier-3 gene is empty in 36 / 1.36 = 26 s rather than 36,
## sooner once it moves ([method spend]), and that arrives as a beat that will
## not settle rather than as a number on a screen. genome.gd owns what it comes
## to; docs/design/genes-and-cilia.md §3.2.
var upkeep := 1.0
## `vacuole` / store: how much bigger this cell's reserve is than a born
## cell's. Written once a frame by the run, like [member upkeep]. A larger tank
## is the same tank drained more slowly -- hunger is normalised 0..1, so there
## is nowhere else for capacity to go.
var reserve := 1.0
## `plastid` / sun: a fraction of upkeep that simply does not happen, because
## the cell is making it. Subtracted from the rate rather than added to feeding,
## so it reads on the beat as "this body runs cheap" and never as a meal.
var photosynthesis := 0.0
## `crista` / burn: what effort costs, as a multiplier on [method spend].
## Written once a frame by the run, like [member reserve]. [member upkeep] has
## the same multiplier folded in already (genome.gd's `upkeep_of`); this is the
## one mitochondrion paying for what the body *does* as well as for being alive.
var burn := 1.0
## Seconds held at full hunger. Public so the dev harness can photograph the end
## of the grace without waiting it out.
var starve_seconds := 0.0


## Being alive, at [method rest_rate]: `plastid`'s light is this body's income.
## Written `delta * rate / HUNGER_SECONDS`, in that order, as it always was, and
## checked bit for bit against the node before it once, over 1.2 million calls,
## by 1a-1's build and again by its review. The fingerprints cannot see it: no
## fingerprint run eats, and a hunger pinned at full hides a reordered sum. What
## CI holds is this node against the static functions to 1e-6 (drop_probe) and
## the thirty-second death to within two frames (levels_probe).
func _process(delta: float) -> void:
	if HUNGER_SECONDS > 0.0:
		set_hunger(hunger + delta * rest_rate(upkeep, photosynthesis, reserve)
			/ HUNGER_SECONDS)
	if hunger >= 1.0:
		starve_seconds += delta
	else:
		starve_seconds = 0.0


func set_hunger(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if next < 1.0:
		starve_seconds = 0.0
	if next == hunger:
		return
	hunger = next
	hunger_changed.emit(hunger)


## A meal worth [param nutrition] of one whole meal: the prey's size against
## this body's, clamped, as food.gd's `eaten` carries it. Eating at full does
## not waste the food -- the caller still fires ingest and still rolls the gene,
## so there is always a reason to eat.
func feed(nutrition: float) -> void:
	set_hunger(hunger - meal(nutrition))


## **Energy the body spent doing something**, in seconds of rest: how long a
## resting cell of upkeep 1 takes to burn as much. What moving costs is paid
## here (cell.gd's `take_effort`, docs/design/energy.md), and so are a dash and
## being spat out by venom, which used to take a fixed share of the bar instead
## (gene-stats.md §11, owner's call 2). Being alive is paid in [method _process],
## at [member upkeep].
##
## Scaled like everything else on the bar: [member burn] makes it cheaper and
## [member reserve] makes it a smaller share of a bigger tank. It stops at full
## hunger and never touches the grace, which is time on purpose: swimming for
## food in the last ten seconds is exactly what the grace is for.
func spend(rest_seconds: float) -> void:
	if rest_seconds <= 0.0 or HUNGER_SECONDS <= 0.0:
		return
	set_hunger(hunger + effort_cost(rest_seconds, burn, reserve))


# --- The tank's arithmetic (docs/design/ocean.md §5.2) ------------------------
# Every body's, the player's through the three callers above. A unit of rest is
# one second of a born cell doing nothing: 1.0 a second at rest, and a share of
# the bar is that over HUNGER_SECONDS.

## **How fast a body at rest burns, in seconds of rest a second**: its
## [param upkeep_rate] less its [param income], over its [param reserve_size].
## Never below nothing -- an income that covers the upkeep holds the tank, it
## does not fill it. A caller turns it into hunger as
## `delta * rest_rate(...) / HUNGER_SECONDS`, which is exact over any stretch in
## which the three do not change.
static func rest_rate(upkeep_rate: float, income: float, reserve_size: float) -> float:
	return maxf(upkeep_rate - income, 0.0) / maxf(reserve_size, RESERVE_MIN)


## **What [param seconds] of rest spent on an effort take out of a tank**, as a
## share of the bar: a stroke, a turn, a dash, venom's sting. [param burn_rate]
## makes it cheaper and a bigger [param reserve_size] makes it a smaller share.
## Nothing for nothing spent.
static func effort_cost(seconds: float, burn_rate: float, reserve_size: float) -> float:
	if seconds <= 0.0 or HUNGER_SECONDS <= 0.0:
		return 0.0
	return seconds * burn_rate / (HUNGER_SECONDS * maxf(reserve_size, RESERVE_MIN))


## **What a meal is worth**, as a share of the bar: [param nutrition] of one
## whole meal, which is the prey's size against the eater's.
static func meal(nutrition: float) -> float:
	return MEAL * nutrition


## Back to a cell with nothing wrong with it.
func reset() -> void:
	starve_seconds = 0.0
	upkeep = 1.0
	reserve = 1.0
	photosynthesis = 0.0
	burn = 1.0
	set_hunger(0.0)


## How far into the grace, 0..1.
func dying() -> float:
	if STARVE_GRACE <= 0.0:
		return 1.0 if hunger >= 1.0 else 0.0
	return clampf(starve_seconds / STARVE_GRACE, 0.0, 1.0)


## The grace has run out.
func starved() -> bool:
	return hunger >= 1.0 and starve_seconds >= STARVE_GRACE


## **How far into the warning**, 0..1: nothing above [constant HUNGRY_FROM],
## rising in a straight line to 1 at empty, and 1 through the grace. The beat
## quickens on it and the body goes slack on it -- normal_mode.gd eases the
## drawn slack toward it, so a meal fills the body out rather than popping it.
func hungry() -> float:
	return clampf((hunger - HUNGRY_FROM) / (1.0 - HUNGRY_FROM), 0.0, 1.0)


## THE mapping, half one. Seconds between beats: [constant REST_PERIOD] above
## half a tank, **quicker as the tank empties** to [constant EMPTY_PERIOD], then
## quicker again through the grace to [constant LAST_PERIOD]. **Hunger alone.**
## The water's richness used to multiply this down to 0.55 s beside food
## (food-and-predators.md §2.1); the owner took it off on 2026-09-29, because
## food is what the senses are for, so the same hunger beats the same rhythm
## wherever the cell is.
func beat_period() -> float:
	return lerpf(lerpf(REST_PERIOD, EMPTY_PERIOD, hungry()), LAST_PERIOD, dying())


## THE mapping, half two. How hard each beat lands, 0..1: **always full.**
## Hunger never dims the beat; dread does, in signal_bus.gd's
## `beat_strength()`, and that drain is dread's own signature.
func beat_amplitude() -> float:
	return FULL_AMPLITUDE


## **How far the membrane has fallen in**, 0..1: nothing while there is food in
## the tank, [constant FAINT_ONSET] the moment it is empty, and all of it as the
## grace runs out. The run posts it to the bus every frame (signal_bus.gd's
## `faint()`), which owns how far that is in pixels and how fast it moves.
func faint() -> float:
	return lerpf(FAINT_ONSET, 1.0, dying()) if hunger >= 1.0 else 0.0
