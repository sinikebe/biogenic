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
## The floor on the beat *rate*. A starving cell beats this slowly and no
## slower -- the membrane must still be there to read.
const STARVED_PERIOD := 4.8
## Deep inside a nutrient field. Nothing reaches this yet; food is a later phase.
const RICH_PERIOD := 0.55

const FULL_AMPLITUDE := 1.0
## The floor on the beat *strength*, and the more important of the two floors.
## A beat that decays to nothing leaves no membrane at all, which reads as a
## broken screen rather than as dying.
const STARVED_AMPLITUDE := 0.35

## Seconds of swimming from fed to as starved as this build goes. Half an hour,
## so a session cannot starve out before there is anything to eat. This is the
## number food will rebalance, and it is deliberately the only one.
const HUNGER_SECONDS := 1800.0

## 0.0 just fed, 1.0 fully starved.
var hunger := 0.0
## Nutrient concentration at the cell, 0.0 until food exists. Kept here because
## it is the other half of the same mapping.
var concentration := 0.0


func _process(delta: float) -> void:
	if HUNGER_SECONDS > 0.0:
		set_hunger(hunger + delta / HUNGER_SECONDS)


func set_hunger(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if next == hunger:
		return
	hunger = next
	hunger_changed.emit(hunger)


## For food, when there is food.
func feed(amount: float) -> void:
	set_hunger(hunger - amount)


## THE mapping, half one. Seconds between beats.
##
## Starving stretches the period toward [constant STARVED_PERIOD]; swimming into
## chemistry collapses it toward [constant RICH_PERIOD]. The square root is what
## makes the field's near edge read: a faint 0.2 concentration already pulls the
## period to about 1.6s, which is the "beat quickens" moment in §2.
func beat_period() -> float:
	var starved := lerpf(REST_PERIOD, STARVED_PERIOD, hunger)
	return lerpf(starved, RICH_PERIOD, sqrt(clampf(concentration, 0.0, 1.0)))


## THE mapping, half two. How hard each beat lands, 0..1.
func beat_amplitude() -> float:
	return lerpf(FULL_AMPLITUDE, STARVED_AMPLITUDE, hunger)
