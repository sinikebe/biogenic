extends Node
## Hunger, and the one place where hunger becomes a beat.
##
## The owner's decision (docs/design/perception.md §6.2): the metabolic beat
## rate *is* the hunger readout. One signal carries both "I exist" and "I am
## running out", so hunger is a perception parameter, not just a survival
## number. Everything that maps hunger to how the membrane reads lives in this
## file and nowhere else -- change starvation balance here and you can see, in
## the same screenful, what it does to legibility.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## Emitted whenever hunger moves, for anything that wants to watch starvation
## without polling.
signal hunger_changed(hunger: float)

## Beat period when fed and in plain water. The rest state of the whole game.
const REST_PERIOD := 2.4
## The floor on the beat *rate* while there is still time to fix it. A starving
## cell beats this slowly -- the membrane must still be there to read.
const STARVED_PERIOD := 4.8
## Deep inside a nutrient field.
const RICH_PERIOD := 0.55
## Past the point of fixing: the last forty seconds stretch to here. Intervals
## long enough that you sit waiting, wondering whether it is coming back. Rate
## is free -- it costs no light, and nothing else is using it at that moment.
const DYING_PERIOD := 7.5

const FULL_AMPLITUDE := 1.0
## The floor on the beat *strength*, and the more important of the two floors.
## A beat that decays to nothing leaves no membrane at all, which reads as a
## broken screen rather than as dying. It holds through the grace as well: the
## floor rule has no exceptions, and only the period is allowed past it.
const STARVED_AMPLITUDE := 0.35

## Seconds of swimming from fed to starved. Seven minutes, so with competent
## foraging -- a meal every 60 to 90 seconds -- the bar is usually somewhere in
## the middle and the beat is usually saying something.
##
## **Move this first if the pace is wrong.** docs/design/food-and-predators.md §3.3.
const HUNGER_SECONDS := 420.0
## What a meal your own size is worth. Near half a bar on purpose: a single meal
## is felt and two are needed.
##
## **This stays a const.** §3.2 took it off the tier table: if `cytostome` tier
## raised the value of a meal as well as the gape, every tier of it would
## increase your slack after upkeep *and* widen the menu, which makes the mouth
## a strictly dominant gene with no reason ever to put anything else in a slot.
## The meal is scaled by what the prey weighed instead, at the call site --
## food.gd measures it against your body, not against your gape.
const MEAL := 0.50
## Seconds at full hunger before the cell dies. It exists so that food ten
## seconds away is still worth swimming for.
const STARVE_GRACE := 40.0

## 0.0 just fed, 1.0 fully starved.
var hunger := 0.0
## Nutrient concentration at the cell, 0..1, written by the food field.
var concentration := 0.0
## Metabolic multiplier, written once a frame by the run exactly as
## [member concentration] is: 1.0 for a cell that is tier 1 across the board,
## and higher for every tier above that. **The price of power, and it is paid in
## the channel the game already reads** -- a cell with one tier-3 gene starves in
## 420 / 1.36 = 309s, and that arrives as a beat that will not settle rather than
## as a number on a screen. genome.gd owns what it comes to;
## docs/design/genes-and-cilia.md §3.2.
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
## Seconds held at full hunger. Public so the dev harness can photograph the end
## of the grace without waiting forty seconds for it.
var starve_seconds := 0.0


func _process(delta: float) -> void:
	if HUNGER_SECONDS > 0.0:
		var rate := maxf(upkeep - photosynthesis, 0.0) / maxf(reserve, 0.05)
		set_hunger(hunger + delta * rate / HUNGER_SECONDS)
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


## A meal. Eating at full does not waste the food -- the caller still fires
## ingest and still rolls the gene, so there is always a reason to eat.
func feed(amount: float) -> void:
	set_hunger(hunger - amount)


## Back to a cell with nothing wrong with it.
func reset() -> void:
	starve_seconds = 0.0
	concentration = 0.0
	upkeep = 1.0
	reserve = 1.0
	photosynthesis = 0.0
	set_hunger(0.0)


## How far into the last forty seconds, 0..1.
func dying() -> float:
	if STARVE_GRACE <= 0.0:
		return 1.0 if hunger >= 1.0 else 0.0
	return clampf(starve_seconds / STARVE_GRACE, 0.0, 1.0)


## The grace has run out.
func starved() -> bool:
	return hunger >= 1.0 and starve_seconds >= STARVE_GRACE


## THE mapping, half one. Seconds between beats.
##
## Starving stretches the period toward [constant STARVED_PERIOD] and then, in
## the last forty seconds, toward [constant DYING_PERIOD]. Chemistry is a
## *multiplier* on whatever that came to, not a second lerp that replaces it:
## nested, a starving cell in rich food beat at 0.55s, exactly as fast as a
## healthy one, and starvation became invisible at the moment the player most
## needed to read it. Multiplied, a starving cell's best possible beat is 1.10s
## against a fed cell's 0.55s, so "my best beat is getting worse" survives a
## meal. docs/design/food-and-predators.md §2.1.
func beat_period() -> float:
	var starved := lerpf(REST_PERIOD, STARVED_PERIOD, hunger)
	starved = lerpf(starved, DYING_PERIOD, dying())
	return starved * lerpf(1.0, RICH_PERIOD / REST_PERIOD, sqrt(clampf(concentration, 0.0, 1.0)))


## THE mapping, half two. How hard each beat lands, 0..1.
func beat_amplitude() -> float:
	return lerpf(FULL_AMPLITUDE, STARVED_AMPLITUDE, hunger)
