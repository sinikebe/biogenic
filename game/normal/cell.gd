extends Node
## The player's cell: a position, a heading, and a drive that is not obedient.
##
## The basic cell has one organelle and no steering muscle worth the name. It
## fires a random forward impulse on its own schedule and coasts; the player can
## lean on its orientation, slowly. Movement being sluggish and slippery is the
## design, not a bug to be tuned out -- see docs/design/perception.md §2, where
## the whole opening depends on drift the player does not command.
##
## Nothing here is drawn. The cell *is* the viewport; what it feels comes out on
## the membrane.
##
## No class_name on purpose -- see the note at the top of signal_bus.gd.

## **How a load wears and what it does** (docs/design/dna-slots.md §6): the
## generic arithmetic, which knows no gene. This file holds the game's numbers for
## it, beside every other table, and every body's wound is stepped through
## [method dosed]. doses.gd preloads nothing, so there is no cycle.
const Doses := preload("res://game/mechanics/doses.gd")
## **The genes** (docs/design/gene-catalogue.md): every organ's numbers live in
## its own file, and this one reads a body's as stats -- `turn_rate`, `gape` --
## through stats.gd, never by a gene's name. Neither preloads anything of
## game/normal, so there is no cycle.
const Catalogue := preload("res://game/genes/catalogue.gd")
const Stats := preload("res://game/genes/stats.gd")
## **The body plan** (docs/design/gene-catalogue.md §10): every slot, and how many a
## radius earns. It preloads nothing.
const BodyPlan := preload("res://game/genes/body_plan.gd")

## Emitted when an impulse fires, so the membrane can bloom at the front.
signal impulsed(strength: float)
## **A new press of a control the hand drives with**, while the autopilot has the
## cell (docs/design/automation.md §2.3, row 36): a steer, a push, a dash or the
## hold, by the scheme's own rules -- a finger on the water under `anywhere`, a
## drawn control under `stick` and `pads`, a key. The run takes the cell back on
## it, in the same frame, before the press does what it does. Never for a press
## that was already down, nor while the hand is silenced.
signal took_back
## `myoneme` -- a burst of speed the player asked for, and what it cost. The
## cell cannot spend hunger itself: metabolism belongs to the run, so the price
## rides out on the signal and the run pays it.
signal dashed(cost: float)

## Body radius in world units. A variable, not a constant, because it is the one
## number in the game that means three things at once: what can eat me, what I
## can eat, and how much genome I can carry.
## docs/design/genes-and-cilia.md §1.1 and §3.1.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const BASE_RADIUS := 26.0
## One meal, four units of radius. **A generation is three meals**, which is the
## owner's "divide the split requirements by four": a daughter is born at 28.28
## and divides at 40, so `(40 - 28.28) / 4` is 2.93.
##
## This is the dial and [constant DIVIDE_RADIUS] is not, because forty carries
## three couplings a smaller number would break: `slots_for(40)` is 7, the body
## has exactly seven arcs, and `food.ARRIVAL_GAPE_MAX` is 40 so the water never
## seeds a mouth that can swallow a full-grown cell in one contact.
##
## **It is the whole water's growth, not the player's.** food.gd's `_devour`
## reads the same constant, so a cell that has been feeding grows four times
## faster too -- docs/design/genes-and-cilia.md §1.2 gets louder rather than
## being switched off for everything except the player, which is the one thing
## §1.3 forbids.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const GROWTH_PER_MEAL := 4.0

var radius := BASE_RADIUS

# --- Integrity -------------------------------------------------------------
# **What a mouth does to a body it cannot swallow.** The gape rule still decides
# *swallowed whole* against *bitten*, so everything §1.1.1 draws still means what
# it meant; this is what happens on the other side of that line. It is a
# property of a body and not of the player, so every cell in the water carries
# one -- food.gd's Body has the same field, mended by the same static below.

## How long a body takes to knit a whole wound back up, in seconds of not being
## bitten. Slow enough that a fight is not undone by swimming away for a moment,
## fast enough that surviving one means something. **The first number to move if
## biting feels wrong**, ahead of the bite table below.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const MEND_SECONDS := 75.0

## Seconds between bites from one mouth. One mouth, one bite, whatever it is
## resting against -- so a cell wedged between two others does not chew both.
const BITE_GAP := 0.85

## Where on a body a bite lands, and therefore how much of it lands. The nose is
## 1.0 because that is where the target's own mouth is and where it is thickest;
## astern nothing it has can answer. A cosine, so there is no angle at which the
## damage steps. docs/design/edibility.md §1.2.
##
## **2.10 is the number to move, and it is the whole difficulty of flanking.**
## It is not measurable from a still frame; it is the first thing to change if
## taking a big cell apart feels either hopeless or free.
const FLANK_AHEAD := 1.00
const FLANK_ASTERN := 2.10

## How far off the arc it is worn on a `trichocyst` can answer. The dart used to
## be a scalar range and fired at whatever was near, which under a positional
## rule is a defence with no position: **a dart in a rear slot is the answer to
## being flanked**, and placement becomes a defensive decision rather than only
## an offensive one. §2.
const DART_ARC_DEG := 110.0

## 0 is whole and 1 is a body that has come apart. There is no bar for this
## anywhere: point of view feels each bite as a `hit` at the bearing it came
## from, and full vision draws the tears (cilia.gd).
var wound := 0.0
## **This body's loads**, stacks of each of doses.gd's kinds (docs/design/
## dna-slots.md §6.1): what venom and poison left in it, wearing off. 64 bits,
## because a load wears down like a clock and every clock here is kept in 64.
## Written by the field, which decides every dose -- or, on a guest, by the host's
## snapshot -- and worn here with the wound, every frame. Being born, a death and
## a reset clear them.
var loads := Doses.none()

## The genome this cell wears. Written by normal_mode.gd, which is the only
## place the two halves are introduced to each other.
##
## Deliberately typed as plain [Node]: genome.gd preloads *this* file for the
## slot ladder, and a preload back the other way is a cycle GDScript will not
## resolve. Null is legal and means the born cell -- nothing in here may assume
## the wiring has happened, because a headless boot builds this node first.
var genome: Node = null

# --- Slots -----------------------------------------------------------------
## **Genome size is capacity, not currency**: a body earns its slots by growing,
## three at birth and seven at radius 40 -- and seven is every arc a body has, which
## is why [constant DIVIDE_RADIUS] is where it divides. §3.1. **The slots are the
## body plan's** (`body_plan.gd`, which writes out the radius each is earned at and
## says why the ladder is what it is); these are its fewest and its most, under the
## names every reader knows them by, read again whenever the plan changes.
static var SLOT_MIN: int = BodyPlan.SLOT_MIN
static var SLOT_MAX: int = BodyPlan.SLOT_MAX


static func _static_init() -> void:
	BodyPlan.listen(_read_plan)


## The plan changed (`body_plan.gd`'s `use`, a tool's): its slots again.
static func _read_plan() -> void:
	SLOT_MIN = BodyPlan.SLOT_MIN
	SLOT_MAX = BodyPlan.SLOT_MAX


# --- The end of a body, and the beginning of two -----------------------------
# docs/design/lifecycle.md §2. **Forty is where a body runs out of places to put
# an organ**: SLOT_MAX is 7, the body has exactly seven arcs, and slots_for(40)
# is 7. Growth past it is the one thing a cell can do that buys nothing it can
# pass on, so the player's radius clamps here and the body divides instead.
#
# The old justifications for 40 -- "nothing left in the water can eat you" and
# "the genome fills on the same meal" -- are both withdrawn by
# docs/design/edibility.md §4 and by measurement respectively. The capacity
# argument stands on its own and is the only one left.

## Where a body divides, and where its radius stops.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const DIVIDE_RADIUS := 40.0
## Two meals out, and where the nucleus starts to double.
##
## **Moved from 37 with [constant GROWTH_PER_MEAL], because it is written in
## meals and not in units.** At four units a meal, a warning starting at 37 is
## three quarters of one meal wide: a cell at 36.28 shows nothing and the next
## mouthful takes it straight to 40, so the most legible "about to divide"
## image in the game would have fired on no frame anybody saw.
const DIVIDE_WARN_RADIUS := 32.0
## Of the mother's **area**, not her radius -- so a daughter is 40/sqrt(2) and
## slots_for(28.28) is 3, the same room to manoeuvre a run starts with. None of
## that was arranged; it falls out of conserving area on a ladder that was
## already there.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const DIVIDE_SPLIT := 0.5


## What each daughter of a body of [param mother_radius] is born at.
static func daughter_radius(mother_radius: float = DIVIDE_RADIUS) -> float:
	return mother_radius * sqrt(DIVIDE_SPLIT)

# --- Drive -----------------------------------------------------------------
# What the drive does with what the genome buys. **Every number a gene buys is
# its organ's own** (game/genes/organs/) and is read here as a stat -- the
# tail's beat as `impulse_speed`, the cirrus's turn as `turn_rate` -- so this
# file names no gene. What is left here is the drive's own: the water's drag,
# the beat's scatter, the wander. §7.2.

## **How an instinct steers onto the heading it holds** (automation.md §4.2): in
## proportion to how far off it is, inside this band, and at full rate outside
## it. The cirrus's lag times its rate is about 0.68 rad at every tier, so full
## rate to the heading would carry the turn about that far past it; a band of
## about twice that settles with a few degrees of overshoot. Radians, a starting
## value (§15). Not a table: a host's referee judges the motion, never this.
const HOLD_BAND := 1.3
## Mean of the per-impulse strength roll below, for [method speed_of].
const IMPULSE_MEAN := 0.85
## Net speed over path speed. One impulse of v0 decaying at DRAG contributes
## exactly v0/DRAG of displacement however long it is left to, so a train of
## them every T seconds makes v0/(DRAG*T) along the heading and there is no free
## parameter in it -- except that the heading is not straight. This is the
## measured shortfall, set so a tier-1 cell comes out at the 56.5 u/s that
## Phase 4 measured over 40 seeds and hard-coded into the pursuit.
const SPREAD_LOSS := 0.945
## The organelle does not aim well: each impulse strays this far off the heading
## and kicks the heading itself by about this much.
const IMPULSE_SPREAD := 0.24
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const IMPULSE_KICK := 0.16
## Water is thick at this scale. Velocity loses 1/e of itself every 1/DRAG s.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const DRAG := 0.74

# --- What the earned genes buy ----------------------------------------------
# Every table that was here is its organ's own now (game/genes/organs/), and is
# read as a stat: the beam's reach, rays and fan, the nose's and the ping's
# ranges, the push, the dash, the armour, the tank, the burn, the light, touch,
# the dart and the toxin's stacks. The beam's fork and prices are the beam's,
# and the levels any gene earns are its file's `levels`. What stays here is what
# the mechanics themselves need.

## How much of the push's terminal speed the water assumes you are using when it
## leads a chase. **The other half of the push's own measurement**: a hunter that
## scaled to your tail alone would be outrun by a gene it cannot see. Half,
## because you are not pushing all of the time -- so a pushing cell is still
## faster than the lead it is given, and a coasting one is over-led and easier
## to dodge. Both of those are the right way round.
const PUSH_CHASE_SHARE := 0.5

## The dash's cooldown.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const DASH_COOLDOWN := 1.4
## A press shorter than this, that moved less than this far, is a tap and not a
## steer. Both halves matter: a thumb that slid is steering.
const TAP_SECONDS := 0.28
const TAP_SLOP := 26.0

# --- The toxin: venom outside, poison inside (docs/design/dna-slots.md §6, §7) --
# **Doses replace both of what `veneneux` did** -- the bite-back share and the
# swallower that died while the player was spat out. A dose is stacks that wear
# off over seconds and act while they last, the owner's rule of 2026-09-30, and a
# body carrying harm does not mend. Every value here is a starting value (§15):
# balance waits for players. How many stacks each form delivers, by its copies,
# is the toxin's own (game/genes/organs/toxin.gd).

## **The body a stack is quoted for**: a born cell. A load acts on any other body
## as `stacks x (DOSE_SIZE / r)^2` (doses.gd's `felt`).
const DOSE_SIZE := BASE_RADIUS
## **What one stack of harm takes out of a body of [constant DOSE_SIZE]**, as it
## wears off: about 70 % of a born mouth's head-on bite (0.07). Into the same
## wound bites tear, so full vision's tears show it.
const HARM_PER_STACK := 0.05
## **How fast each kind of load wears off**, by doses.gd's `Kind`: harm over
## about a fight (a stern kill takes 13 s), paralysis short so it opens a window
## and does not lock anybody out, sleep longer because a bite ends it. Phase 1
## delivers harm alone.
const DOSE_TAU_BY_KIND: Array[float] = [6.0, 4.0, 8.0]
## **Below this a load is gone**, cleared whole: one stack lasts
## `6 x ln 5 = 9.7 s`, so a light dose stops a body mending for about ten.
const DOSE_GONE := 0.2
## **How far round its slot's bearing a venom on a side or the stern stings** a
## mouth that bites there: the dart's own arc, so the two weapons that guard a side
## reach as far round it.
const VENOM_ARC_DEG := 110.0
## **Whether a venom on a side or the stern stings at all.** False makes it inert
## there, and venom works through the bite alone: the switch, should the owner read
## *"the direction slots express outside"* as the mouth only (dna-slots.md §22.2).
const VENOM_SIDES := true

# --- Steering --------------------------------------------------------------
## The water pushes back: a slow random walk on the heading the player never
## asked for and cannot switch off.
## The host's referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
const WANDER_RATE := 0.13
const WANDER_TAU := 2.6

# --- What moving costs (docs/design/energy.md) -------------------------------
# **Every stroke and every turn is paid for**, in seconds of rest: how long a
# resting body of upkeep 1 takes to burn as much (metabolism.gd's `spend`). The
# owner, 2026-09-29: starving should come sooner, "not necessarily by reducing
# the storage. It can be by adding consumption. [...] each swim should consume
# energy. turning should also consume energy."
#
# The costs are paid on what the body actually does, not on what was asked of
# it: the speed a stroke adds and the angle the body turns. So a better
# flagellum, which beats harder and more often, costs more to run and still
# costs the same per unit of speed, and a better cirrus turns faster for the
# same price per degree. What an organ buys is how fast; what it costs is how
# much. None of this crosses the wire -- hunger is each player's own.

## **Seconds of rest per unit of speed a stroke adds** -- a beat of the
## flagellum, on the speed it gives, and a held push, on the speed it adds each
## frame. A tier-1 beat adds 117 u/s on average and costs 1.3 s of rest, and the
## flagellum beating on its own schedule comes to half again what a resting body
## burns. The dash is not in it: the stat `dash_cost` is its price, and it is
## paid in the same seconds of rest, through the same `spend`, so `crista` and
## `vacuole` soften both alike.
const STROKE_COST := 0.0113


## **What holding [param speed] against the drag costs a body, in seconds of
## rest a second**: the speed the drag takes out each second, grossed up by what
## a stroke loses to spreading, at [constant STROKE_COST] per unit of it. The
## player's flagellum pays per beat, on the speed each beat adds; a water body
## swims at a steady speed and pays for holding it -- 0.50 a second at a born
## cell's 56.5, what the player's flagellum costs it either way
## (docs/design/ocean.md §5.2). One table, so the water prices a swim from the
## player's own.
static func stroke_cost(speed: float) -> float:
	return maxf(speed, 0.0) * DRAG / SPREAD_LOSS * STROKE_COST


## **Seconds of rest per radian the body turns under steering.** A half turn
## costs about 4 s of rest, and turning flat out at tier 1 burns 0.8 of a
## resting body's rate on top of everything else. The water's own wander is
## free: it is not the cirrus doing it.
const TURN_COST := 1.3

# --- Input -----------------------------------------------------------------
## Canvas pixels of drag for a full-rate turn.
const DRAG_SPAN := 190.0
## Below this the player is not really steering, so onboarding stays up.
const STEER_DEADZONE := 0.12

# --- What the body gives a body's rules (docs/design/behaviour.md §3) ----------
## **The body's own parts**, in the shape of `genome.gd`'s DECLARES: what every
## body has whatever its genes. It feels a `hit` -- a bite or a dart landing on
## its membrane, at a bearing and a strength, as the player feels one -- and it
## has the triggers every body has (§3.3): it turns toward or away from what a
## sense reports, which needs a bearing, or turns at random; it swims, on its
## flagellum's own beat; and it rests, which claims every trigger there is. Its
## `cirrus` only makes these faster, so it declares nothing.
##
## **Under row 37** (docs/design/automation.md §5.3) a tail beats unless it is
## held, so `swim` claims the tail -- the `swimming` trigger -- and keeps a rule
## below it from holding it; and `rest` stops steering, the push and the dash
## at every level, and holds the tail too only at the tail's hold level
## ([method hold_level]). The tail's own `hold` is declared in its organ's file,
## at that level.
const DECLARES := {
	&"body": {
		"in": [{"name": &"hit", "bearing": true, "values": {&"strength": &"level"}}],
		"out": [
			{"name": &"turn-toward", "claims": [&"steering"], "needs": &"bearing"},
			{"name": &"turn-away", "claims": [&"steering"], "needs": &"bearing"},
			{"name": &"turn-random", "claims": [&"steering"]},
			{"name": &"swim", "claims": [&"swimming"]},
			{"name": &"rest", "claims": [&"all"]},
		],
	},
}

## **What the body's parts are called** (docs/design/automation.md §13.1), beside
## [constant DECLARES], by qualified name and by value name: the words the
## programs page puts on a part's chip. Read through [method words_of].
##
## TRANSLATORS: The name of a sense or an action on a small chip of the player's
## "instincts" (rules the player writes: "when <a sense reports something> -> <do
## this>"), or of a value a sense reports. Lowercase, one or two short words.
## "hit": a bite landing on the cell. "turn toward" / "turn away": steer to or
## from where the sense says it is. "tumble": a sudden turn to a random side, as
## swimming bacteria do. "swim": keep the tail beating. "rest": stop moving on
## purpose and drift with the water.
## ROOM: 112 px at 15 px
const BODY_SAYS := {
	&"body.hit": "hit",
	&"body.turn-toward": "turn toward",
	&"body.turn-away": "turn away",
	&"body.turn-random": "tumble",
	&"body.swim": "swim",
	&"body.rest": "rest",
}
## **What the values its senses report are called**, by value name: a test is put
## to one of them.
##
## TRANSLATORS: The name of a value a sense of the player's cell reports, which an
## "instinct" can test, on a small choice cell: "strength", how hard a bite was.
## Lowercase, one short word.
## ROOM: 70 px at 14 px
const BODY_VALUES := {
	&"strength": "strength",
}
## **The line that explains each of them**, beside the chip: the chip's word, a
## middle dot, and what it is or makes the cell do, in plain words.
##
## TRANSLATORS: Explains one sense, action or value of the player's "instincts",
## on one line under them: its name (the same word as on its chip), a middle dot,
## then what it is or does, lowercase. "Your tail" is the cell's flagellum, which
## swims; "two copies" means the gene is carried twice in the cell's DNA, which
## is what lets the tail be held still; "below" means the instincts lower in the
## list.
## ROOM: 856 px at 15 px
const BODY_EXPLAINS := {
	&"body.hit": "hit · a bite landing on you: where it came from, and how hard.",
	&"body.turn-toward": "turn toward · steer for where the sense says it is.",
	&"body.turn-away": "turn away · steer away from where the sense says it is.",
	&"body.turn-random": "tumble · a quarter to a half turn, to a random side.",
	&"body.swim": "swim · keep your tail beating, so nothing below holds it still.",
	&"body.rest": "rest · stop steering, pushing and dashing, and drift. with two copies of"
		+ " your tail, hold it still too.",
	&"strength": "strength · how hard the bite was, from a graze to a full bite.",
}


## **A part's words, in the language of the moment** (automation.md §13.1), for
## the parts [constant DECLARES] names and the values they report: `{"says": its
## chip, "explains": its line}`, a key absent where there are none. `genome.gd`
## and `metabolism.gd` answer the same way for their parts, so the page asks the
## file that declares a part, and a gene that brings a part brings its words.
static func words_of(part: StringName) -> Dictionary:
	var out := {}
	if BODY_SAYS.has(part):
		out["says"] = String(TranslationServer.translate(BODY_SAYS[part]))
	elif BODY_VALUES.has(part):
		out["says"] = String(TranslationServer.translate(BODY_VALUES[part]))
	if BODY_EXPLAINS.has(part):
		out["explains"] = String(TranslationServer.translate(BODY_EXPLAINS[part]))
	return out

## Nothing held. Touch indices are >= 0 and the mouse is -1, so -2 is free.
const POINTER_NONE := -2
const POINTER_MOUSE := -1

var position := Vector2.ZERO
## Radians, clockwise from world north. Front is the top of the screen.
var heading := 0.0
var velocity := Vector2.ZERO
## Signed steering demand, -1 hard to port .. +1 hard to starboard.
var steer := 0.0

var _omega := 0.0
var _wander := 0.0
var _impulse_timer := 0.0
var _dash_timer := 0.0
## **Whether the tail was held still on this body's last step** -- by the hand,
## at [method hold_level] -- as [method _process] read it: what the views draw
## still, and what the step that stopped the stroke clock decided.
var _held := false
## **What this body wears buys it, read once a body** ([method _bought_now]): the
## genome and its body's version they were read off; stat to value, stat to the
## organ that provides it and to its tier, channel to the organ that drives it;
## and the realised speed and the tail's hold level, -1 until read.
var _bought_from: Node = null
var _bought_at: Variant = -1
var _bought := {}
var _providers := {}
var _tiers := {}
var _channels := {}
var _swim := -1.0
var _hold := -1
## Seconds of rest this body has spent moving since the run last took them
## ([method take_effort]).
var _effort := 0.0
## When the current press started and where, so a tap can be told from a steer.
var _pointer_at := 0.0
var _pointer_from := 0.0
## -2 nothing held, -1 the mouse, >= 0 the touch index that owns the drag.
## **One slot, and that is correct for `anywhere` and only for `anywhere`**: a
## resting palm must not fight the steering thumb when the whole screen is the
## control. The other two schemes need a finger per control, and that lives in
## [member controls], keyed by pointer index -- so `port` and `push` can be held
## at once, and a dash can be fired while the stick is deflected.
var _pointer := POINTER_NONE
var _pointer_anchor := 0.0
var _pointer_x := 0.0

## The drawn controls, or null under `anywhere` and in any scene that has none.
## **Untyped on purpose.** cilia.gd preloads genome.gd, which preloads this
## file, and controls.gd preloads cilia.gd -- so a preload back the other way
## would be a cycle GDScript will not resolve.
var controls: Node = null

## **Deaf to the player's steering, while the body goes on.** True makes
## [method _read_steer] answer nothing and silences [method _pushing] and the
## dash, the keys this file polls directly included -- and nothing else: the
## drift, the impulses and the drag carry on, so the cell is let go rather than
## stopped. For a menu open over water that does not stop (shared-pond.md
## §1.7), where the arrows are moving menu focus and must not also turn the
## cell. False by default, and nothing sets it yet.
##
## **It silences what the cell does with a pointer, not whether it takes one.**
## [method _unhandled_input] goes on running, so a finger that goes down on the
## water while this is true is still claimed -- by the floating stick here, or
## by a drawn control through `controls.press()` -- and is still held, and
## steering, the moment it clears. So whoever flips it calls [method release]
## and `controls.let_go()` at the same moment, both ways round: exactly the
## pair the pause screen and a lost focus already call.
##
## **It silences the hand only** (automation.md §2.4, §13): the autopilot drives
## through it, so a pond's open menu lets your programs steer while you edit.
var steering_off := false

## **Whether the autopilot has the cell** (automation.md §2): set by the run, and
## nothing here sets it. While it does, the steer, the push and the tail are what
## [member instincts] claim, and the hand's keys and fingers move nothing until a
## new press takes the cell back ([signal took_back]).
var autopilot := false
## **The instincts that drive the cell while the autopilot has it**:
## `own_rules.gd`, set by the run. Untyped for the reason [member controls] is.
var instincts: RefCounted = null
## **What the hand asked to steer this frame**, -1 .. +1, whoever had the cell:
## what the run's onboarding waits for (automation.md §18.1), never an
## instinct's turn.
var hand_steer := 0.0


func _ready() -> void:
	_impulse_timer = randf_range(0.6, 1.4)


## A new cell in new water, for the restart after a death.
##
## [param keep_place] is a birth rather than a restart: a daughter carries on
## from where her mother was and pointing the way her mother pointed, so the
## world view's camera does not jump at the one moment the player is looking
## hardest at the middle of the screen. Everything else about her is new.
func reset(keep_place: bool = false) -> void:
	if not keep_place:
		position = Vector2.ZERO
		heading = randf_range(-PI, PI)
	velocity = Vector2.ZERO
	radius = BASE_RADIUS
	wound = 0.0
	loads.fill(0.0)
	_omega = 0.0
	_wander = 0.0
	_impulse_timer = randf_range(0.6, 1.4)
	_dash_timer = 0.0
	_effort = 0.0
	_held = false
	release()


## **This body as plain types**, for a drop kept with its cell in it (ocean.md
## §9.2, row 17): where it is, which way it points and how it is moving, its
## size and its wound, and what its tail and its dash are in the middle of --
## the turn, the drift, the clocks of the next impulse and the next dash, and
## the effort not yet paid for. Nothing a finger was doing: it comes back let go.
func body_state() -> Dictionary:
	return {
		"at": position,
		"heading": heading,
		"velocity": velocity,
		"radius": radius,
		"wound": wound,
		"omega": _omega,
		"wander": _wander,
		"impulse": _impulse_timer,
		"dash": _dash_timer,
		"effort": _effort,
	}


## Puts back what [method body_state] took, and lets go of anything held. The
## loads are not in it -- a file keeps them beside the body, as `cell.loads`
## ([method restore_loads]) -- so a body put back carries none until they are.
func restore_body(state: Dictionary) -> void:
	position = state["at"]
	heading = float(state["heading"])
	velocity = state["velocity"]
	radius = float(state["radius"])
	wound = float(state["wound"])
	_omega = float(state["omega"])
	_wander = float(state["wander"])
	_impulse_timer = float(state["impulse"])
	_dash_timer = float(state["dash"])
	_effort = float(state["effort"])
	loads.fill(0.0)
	_held = false
	release()


## **The loads, written back** -- from a kept drop's `cell.loads`, a host's
## snapshot or a replay: each kind as many stacks as [param kept] says, and none
## where it says nothing. Copied, never held: a packed array is passed by
## reference.
func restore_loads(kept: PackedFloat64Array) -> void:
	for k in loads.size():
		loads[k] = maxf(kept[k], 0.0) if k < kept.size() and is_finite(kept[k]) else 0.0


## **A body's wound after [param delta] seconds, with its [param loads]**
## (docs/design/dna-slots.md §6.2) -- the one dose step every body takes, the
## cell on this device here, every water body and every person in food.gd. With
## nothing in it, it is [method mended], exactly. With harm in it, the stacks that
## wore off this step go into the wound -- [constant HARM_PER_STACK] a stack,
## diluted by the body's [param body_radius] -- and **the wound mends only for
## the part of the step after the harm ran out**: a body carrying harm does not
## mend. [param loads] are worn in place.
static func dosed(loads: PackedFloat64Array, hurt: float, body_radius: float,
		delta: float) -> float:
	if not Doses.any(loads):
		return mended(hurt, delta)
	var worn := Doses.wear(loads, delta, DOSE_TAU_BY_KIND, DOSE_GONE)
	var harmed := clampf(hurt + worn[0] * HARM_PER_STACK
		* Doses.felt(1.0, body_radius, DOSE_SIZE), 0.0, 1.0)
	return mended(harmed, worn[1])


func _process(delta: float) -> void:
	# **The hand, or the heading the instincts hold** (automation.md §4.2, §18.4):
	# while the autopilot has the cell its instincts steer, in proportion inside
	# HOLD_BAND, and the hand's keys and fingers move nothing.
	hand_steer = _read_steer()
	steer = float(instincts.call(&"steer_for", heading)) if _driven() else hand_steer

	# The body knits itself back up whenever nothing is chewing on it. Here
	# rather than in the water, because it is a thing a body does and not a
	# thing that happens to it -- and because _set_simulating() stops this node
	# on a death, which is exactly when it should stop.
	#
	# **And its loads wear here, with it** (dna-slots.md §6.2): harm tears it as
	# it wears off, and it does not mend while harm is in it. A wound made whole
	# this way is found by the field, at the top of its contacts with this cell,
	# which is where every death of this cell is told -- on a guest never, since
	# the host owns that death and the next snapshot's wound is the truth.
	wound = dosed(loads, wound, radius, delta)

	_omega = lerpf(_omega, steer * turn_rate(), 1.0 - exp(-delta / turn_response()))
	# Ornstein-Uhlenbeck-ish drift: a heading nudge that wanders instead of
	# buzzing, so it reads as current rather than as noise.
	var pull := 1.0 - exp(-delta / WANDER_TAU)
	_wander = lerpf(_wander, randf_range(-WANDER_RATE, WANDER_RATE), pull)
	heading = wrapf(heading + (_omega + _wander) * delta, -PI, PI)
	# The turn the cirrus made, and only that: the wander above is the water's.
	_effort += absf(_omega) * delta * TURN_COST

	# **A held tail keeps its clock** (automation.md §5.2): while it is held the
	# stroke clock stands still -- never reset -- so the beat it was counting
	# down to comes on its own time once it is let go, and two strokes are never
	# closer than the tier's shortest gap however often a hold comes and goes.
	# That is the host's referee's movement budget, "impulses as often as their
	# clock allows". A held tail fires nothing, so it costs nothing.
	_held = can_hold() and _holding()
	if not _held:
		_impulse_timer -= delta
		if _impulse_timer <= 0.0:
			_fire_impulse()

	# `axoneme`: thrust you asked for, on top of the involuntary one. Held keys
	# on desktop, a finger on the screen anywhere on touch -- the same gesture
	# that steers, because pushing and turning are things you do together and a
	# second control would cost a pixel of screen the design does not have.
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	var push := stat(&"push_accel")
	# **A strength, not a yes or no** (automation.md §4.2): the hand's is full, and
	# an instinct's a half or full, at that share of the thrust and of its price.
	var strength := _push_strength()
	if push > 0.0 and strength > 0.0:
		var thrust := push if strength >= 1.0 else push * strength
		velocity += forward() * thrust * delta
		_effort += thrust * delta * STROKE_COST

	velocity *= exp(-DRAG * delta)
	position += velocity * delta


func _fire_impulse() -> void:
	_impulse_timer = randf_range(impulse_gap_min(), impulse_gap_max())
	heading = wrapf(heading + randf_range(-IMPULSE_KICK, IMPULSE_KICK), -PI, PI)
	var strength := randf_range(0.7, 1.0)
	var aim := heading + randf_range(-IMPULSE_SPREAD, IMPULSE_SPREAD)
	velocity += Vector2(sin(aim), -cos(aim)) * impulse_speed() * strength
	_effort += impulse_speed() * strength * STROKE_COST
	impulsed.emit(strength)


# ---------------------------------------------------------------------------
# What the genome buys. Every one of these is a read, not a stored value: a
# gene integrated mid-run has to take effect on the next frame, and a cached
# copy is one more thing that can be stale when it matters. **Each is a stat**
# (game/genes/stats.gd): the body's providers of it, at the copies it wears.
# ---------------------------------------------------------------------------

## Tier of one gene, 1 if there is no genome attached yet -- the born cell is
## tier 1 across the board, so an unwired cell behaves exactly as Phase 4 did.
func tier(gene: StringName) -> int:
	return genome.tier(gene) if genome != null else 1


## Tier of an **earned** gene, 0 if there is no genome attached yet. Separate
## from [method tier] on purpose: that one answers 1 for an unwired cell because
## the born cell is tier 1 at the three home organs, and answering 1 for a gene
## nobody has grown would hand a headless boot a laser.
func extra(gene: StringName) -> int:
	return genome.tier(gene) if genome != null else 0


## **What this body wears**, gene to copies: its genome's body, or the born
## cell's while no genome is wired -- the cell a headless boot builds first,
## which swims as Phase 4's did, tier 1 at its three home organs and nothing
## else. Read it; do not write it.
func worn() -> Dictionary:
	return genome.tiers() if genome != null else Catalogue.born()


## **This body's [param which]** (stats.gd): what it wears of the stat's
## providers, combined -- `turn_rate`, `gape`, `armor`. Read off the stats once a
## body ([method _bought_now]).
func stat(which: StringName) -> float:
	var bought := _bought_now()
	var known: Variant = bought.get(which)
	if known == null:
		known = Stats.of(worn(), which)
		bought[which] = known
	return known


## **The organ this body provides [param which] with**, `&""` for none: the mouth
## is what provides `gape`, the ping what provides `ping_range`. Where a mechanic
## needs the organ itself -- the arc it is worn on, its level -- it asks this,
## never a name (gene-catalogue.md §5.2).
func provider(which: StringName) -> StringName:
	_bought_now()
	var known: Variant = _providers.get(which)
	if known == null:
		known = Catalogue.worn_provider(worn(), which)
		_providers[which] = known
	return known


## **The copies this body wears that organ at**, 0 for none: what a mechanic
## indexes a table of its own by -- the membrane's envelopes, the ping's
## resolution.
func tier_for(which: StringName) -> int:
	_bought_now()
	var known: Variant = _tiers.get(which)
	if known == null:
		known = Stats.tier(worn(), which)
		_tiers[which] = known
	return known


## **The organ this body drives membrane [param channel] with** (gene.gd's
## channels), `&""` for none: how the shade finds the eyespot, which buys no
## number of its own.
func on_channel(channel: StringName) -> StringName:
	_bought_now()
	var known: Variant = _channels.get(channel)
	if known == null:
		known = Catalogue.worn_on(worn(), channel)
		_channels[channel] = known
	return known


## **What this body wears buys it, read once a body** (docs/design/gene-catalogue.md
## §15, as built 1a): every stat asked of it, by name -- and, beside, its organs
## by stat and by channel, its tiers by stat, its realised speed and its tail's
## hold level. The drive, the run and the water ask them every frame; what it
## wears changes only when its genome expresses a body (`genome.gd`'s
## `body_version`) or another genome is wired in, and then all of it is read
## again, as it is asked. Returns the stats, emptied if they were stale.
func _bought_now() -> Dictionary:
	var version: Variant = genome.get(&"body_version") if genome != null else -1
	if genome != _bought_from or version != _bought_at:
		_bought_from = genome
		_bought_at = version
		_bought.clear()
		_providers.clear()
		_tiers.clear()
		_channels.clear()
		_swim = -1.0
		_hold = -1
	return _bought


## How wide this cell's mouth opens, in world units. Anything whose radius is
## below this fits in it, and nothing else does. [method gape_of]'s arithmetic,
## its `gape` read once a body.
func gape() -> float:
	return stat(&"gape") * radius


## **How big this body is to a mouth**, which `pellicle` makes larger than it
## looks. Every "can that eat me" test in the water reads this and not
## [member radius]; every "how much is that worth" test reads the radius, so
## armour never made you a bigger meal. [method swallow_radius_of]'s arithmetic,
## its `armor` read once a body.
func swallow_radius() -> float:
	return radius * stat(&"armor")


## [method swallow_radius] for a body that is not this node: its
## [param body_radius] and what it wears, [param tiers]. In the drop every body's
## armour is asked this way, a water cell's as a player's (ocean.md §5.7, row 5).
static func swallow_radius_of(body_radius: float, tiers: Dictionary) -> float:
	return body_radius * Stats.of(tiers, &"armor")


## How far this cell's beams reach, 0 for a cell with no beam. Which way
## they point is a question about the genome's *layout*, and it is asked where
## the arc table lives -- this file cannot preload cilia.gd, because
## cilia -> genome -> cell would be a preload cycle.
func beam_range() -> float:
	return float(beam_shape(beam_level(), beam_path(), provider(&"beam_range"))[3])


## **The level this body's beam works at**, 0 for a body with no beam. The
## level and not the copies (beam-levels.md §0 row 5), held at the fork until a
## path is taken.
func beam_level() -> int:
	var beam := provider(&"beam_range")
	if beam == &"":
		return 0
	return maxi(int(genome.level_of(beam)), 1)


## Which way this body's beam has grown past the fork, &"" before it has.
func beam_path() -> StringName:
	var beam := provider(&"beam_range")
	if beam == &"":
		return &""
	return StringName(genome.path_of(beam))


## **The beam at [param level] down [param path]**: `[rays, half-span in
## degrees, sweep in degrees a second, reach]`, as the organ that casts it --
## [param beam], or the first that provides `beam_range` -- grows with its level
## (`ocellus.gd`'s `shape_at`). No beam at all at level 0, or from an organ that
## casts none. beam-levels.md §4.
static func beam_shape(level: int, path: StringName, beam := &"") -> Array:
	var organ := Catalogue.gene(beam if beam != &"" else Catalogue.first_provider(&"beam_range"))
	if level <= 0 or organ == null or not organ.has_method(&"shape_at"):
		return [0, 0.0, 0.0, 0.0]
	return organ.call(&"shape_at", level, path)


## **What a levelled gene adds to the metabolic multiplier**, in place of the
## `UPKEEP_PER_TIER` its copies used to cost. The genome asks this for every
## gene that earns levels the body wears, and the organ answers with its own
## price (gene.gd's `upkeep_at`): the beam's is the beam's. -1 for a gene with no
## price of its own, which the genome charges at the old per-tier rate, by level.
static func levelled_upkeep(gene: StringName, level: int, path: StringName) -> float:
	return Catalogue.upkeep_at(gene, level, path)


## How far this cell can smell, 0 for a cell with no nose.
func smell_range() -> float:
	return stat(&"smell_range")


## How far a ping carries, 0 for a cell with no organ that calls.
func ping_range() -> float:
	return stat(&"ping_range")


## Seconds between pings, 0 for a cell with no organ that calls.
func ping_period() -> float:
	return stat(&"ping_period")


## How much of a pulse survives one body in the way, 0 at the first tier. Which
## *way* the pulse leaves is a question about the genome's layout and is asked
## where the arc table lives, exactly as the beam's bearing is -- this file
## cannot preload cilia.gd.
func ping_through() -> float:
	return stat(&"ping_through")


## **The tier of the organ that calls**, clamped to its tables, 0 for a cell
## with none. The three above turn the tier into a distance, a period and a
## fraction; the field needs the index as well, because how many bodies one
## pulse answers for and how finely it reports each one are the organ's own
## resolution and not a property of anything in the water.
func ping_tier() -> int:
	return tier_for(&"ping_range")


## How many genes this body can carry.
func slots() -> int:
	return slots_for(radius)


func impulse_speed() -> float:
	return stat(&"impulse_speed")


func impulse_gap_min() -> float:
	return stat(&"impulse_gap_min")


func impulse_gap_max() -> float:
	return stat(&"impulse_gap_max")


## **The level this body's tail works at**: `genome.gd`'s `level_of` of the
## organ that beats, which for a tail is its worn copies -- 1 for an unwired cell,
## which is the born one, and 0 for a body with no tail. What
## [method hold_level] is asked of.
func tail_level() -> int:
	if genome == null:
		return 1
	var tail := provider(&"impulse_speed")
	return int(genome.level_of(tail)) if tail != &"" else 0


## Whether this tail can be held still at all: at [method hold_level] or more.
## What draws the hold's control (controls.gd), and what its key and a rule ask.
func can_hold() -> bool:
	_bought_now()
	if _hold < 0:
		_hold = hold_level(worn())
	return tail_level() >= _hold


## **The level a tail can be held still from**: the tail's own number
## (`flagellum.gd`'s HOLD_LEVEL), of the organ that beats which [param tiers]
## wears -- or of the first that beats, for a body that wears none. A held tail
## does not beat, costs nothing and keeps its clock ([method _process]).
## [constant HOLD_NEVER] once no organ beats at all.
static func hold_level(tiers: Dictionary) -> int:
	return int(Catalogue.number_for(tiers, &"impulse_speed", &"hold_level", HOLD_NEVER))


## **The hold level with no organ that beats at all**, every one retired
## (gene-catalogue.md §4.4): one no tail reaches, so nothing is ever held.
const HOLD_NEVER := 1 << 16


## **How long a dart stuns what it hits**, in seconds: the dart's own number
## (`trichocyst.gd`'s DART_STUN), of the dart [param tiers] wears -- or of the
## first organ that darts, for a body that wears none. 0 once no organ darts.
static func dart_stun(tiers: Dictionary) -> float:
	return float(Catalogue.number_for(tiers, &"dart_range", &"stun", 0.0))


## **Whether the tail is held still**, as this body's last step had it: what both
## views draw still (soma.gd, vision.gd). False at a level-1 tail whatever the
## hand does.
func tail_held() -> bool:
	return _held


## **The held tail a replay writes back** (automation.md §11), as it writes the
## rest of a recorded frame onto this body: what both views draw still.
func restore_held(on: bool) -> void:
	_held = on


func turn_rate() -> float:
	return stat(&"turn_rate")


func turn_response() -> float:
	return stat(&"turn_response")


## The net speed this cell actually makes, which is what anything chasing it
## has to lead. §7.1: this replaces Phase 4's hard-coded 56.5, so the chase
## stays a chase at every tier and only `cirrus` improves the dodge.
func swim_speed() -> float:
	_bought_now()
	if _swim < 0.0:
		_swim = swim_speed_of(worn())
	return _swim


## [method swim_speed] for a body that is not this node: the same arithmetic,
## fed what it wears instead of a genome. **One definition with two callers** --
## a player in a shared pond is a body in the field, not a node here, and the
## water has to lead that chase exactly as it leads this one
## (shared-pond.md §1.2).
static func swim_speed_of(tiers: Dictionary) -> float:
	return speed_of(tiers) + PUSH_CHASE_SHARE * Stats.of(tiers, &"push_accel") / DRAG


# --- The same, for a cell that is not this one -----------------------------
# Every other body in the water is a `{gene: tier}` dictionary in food.gd, not
# a node. These are how it asks the same questions, so there is exactly one
# definition of what a tier buys.

## How wide the mouth of a body wearing [param tiers] opens, in world units: its
## `gape` -- a multiple of its radius -- times [param body_radius].
static func gape_of(tiers: Dictionary, body_radius: float) -> float:
	return Stats.of(tiers, &"gape") * body_radius


## **What one bite is worth.** One definition, asked in both directions: the
## water runs it for a cell chewing on the player and for the player chewing on
## a cell, and neither gets its own arithmetic.
##
## Three terms, and none of them is a new stat:
##
## - the **`bite`** of the mouth doing it -- its mouth's stat, [param bite];
## - **how near the target came to fitting in it** -- `gape / radius`, which is
##   1 for a body that has only just outgrown this mouth and falls away as it
##   grows. That is what keeps the bite continuous with the swallow instead of
##   making a mouth equally dangerous to everything it cannot eat;
## - the target's **`armor`** -- its `pellicle`'s, [param armor] -- which already
##   means "how hard this body is to get down" and now also means how much of a
##   bite it turns away.
##
## [param target_radius] is the body, not its swallow radius: armour is counted
## once, on the bottom of this expression, and counting it twice would make
## pellicle the only gene in the game with a square in it.
##
## [param theta] is **where on the body it landed**, measured at the target
## between its own heading and the direction the mouth arrived from: 0 is dead
## ahead and PI is dead astern. One definition, asked in both directions, so the
## water chewing on the player and the player chewing on the water read the same
## table. §1.2.
static func bite_damage(bite: float, gape: float, target_radius: float,
		armor: float, theta: float) -> float:
	if bite <= 0.0:
		return 0.0
	return bite * minf(gape / maxf(target_radius, 0.001), 1.0) * flank(theta) \
		/ armor


## How much of a bite arriving on bearing [param theta] actually lands. A
## cosine: there is no angle at which the damage steps, and turning your nose
## onto an attacker is what takes it back to 1.0 -- which is `cirrus`'s new job
## and the whole of §2.
static func flank(theta: float) -> float:
	return lerpf(FLANK_AHEAD, FLANK_ASTERN, 0.5 - 0.5 * cos(theta))


## A wound knitting up over [param delta] seconds. Every body in the water uses
## this one -- the player's through [method _process], the field's through
## food.gd -- so there is one definition of how fast a cell recovers.
static func mended(hurt: float, delta: float) -> float:
	return clampf(hurt - delta / MEND_SECONDS, 0.0, 1.0)


## **How many outside slots a body of [param body_radius] has earned**: the body
## plan's count -- every slot earned at that radius or below.
static func slots_for(body_radius: float) -> int:
	return BodyPlan.slots_for(body_radius)


## **The realised speed of a body's tail**, from what it wears, [param tiers]:
## one beat's speed at the beat's mean strength, over the mean gap, less what
## the scatter costs -- its `impulse_speed` and `impulse_gap_min` and `_max`.
## A body with no tail is the extrapolated tier 0 of them, as it always was.
static func speed_of(tiers: Dictionary) -> float:
	var gap := (Stats.of(tiers, &"impulse_gap_min") + Stats.of(tiers, &"impulse_gap_max")) \
		* 0.5
	return Stats.of(tiers, &"impulse_speed") * IMPULSE_MEAN * SPREAD_LOSS / (DRAG * gap)


## **How fast the heading is turning right now**, in radians a second: the
## steering and the drift, which is everything that turns this body smoothly.
## An impulse's kick is not in it -- that is a step, not a rate, and it is sent
## as the step it is. What the other player's screen carries this heading
## forward by, for the fraction of a second between two frames.
func heading_rate() -> float:
	return _omega + _wander


## World direction the cell is facing.
func forward() -> Vector2:
	return Vector2(sin(heading), -cos(heading))


## World direction off the cell's right flank.
func starboard() -> Vector2:
	return Vector2(cos(heading), sin(heading))


## Body-relative bearing of a world point: radians clockwise from the front,
## which is the only way this game is allowed to describe a direction.
func bearing_to(point: Vector2) -> float:
	var offset := point - position
	return atan2(offset.dot(starboard()), offset.dot(forward()))


## How hard the membrane should be shearing right now, signed and normalised.
##
## Takes the larger of demand and actual rotation on purpose. The turn itself
## builds over about a second, but the wash has to answer the same frame the
## player pushes -- that answer is the only proof they are connected to
## anything, and a second of lag destroys it.
func shear_rate() -> float:
	var turning := _omega / turn_rate()
	return steer if absf(steer) > absf(turning) else turning


## **What moving has cost since the last call**, in seconds of rest, and nothing
## after it: every stroke, every frame of a held push and every radian turned
## (docs/design/energy.md). The cell cannot spend hunger itself -- metabolism
## belongs to the run -- so the run takes this once a frame and pays it with
## metabolism.gd's `spend`, the way the dash's price rides out on `dashed`.
func take_effort() -> float:
	var spent := _effort
	_effort = 0.0
	return spent


## Knocked off course by something solid. [param normal] points from the thing
## into the cell.
func bump(normal: Vector2, restitution: float = 0.55) -> void:
	var into := velocity.dot(-normal)
	if into <= 0.0:
		return
	velocity += normal * into * (1.0 + restitution)
	position += normal * 2.0


## Drops any held drag. Called when the game pauses, so a finger still down when
## the pause opened does not keep steering afterwards.
##
## **The drawn controls are not dropped here**, and that is deliberate: this is
## also what the pinch of a division calls, and the steering control has to
## survive it. `controls.let_go()` is the other half, called from the two places
## that really do mean *every finger stops counting* -- the pause screen opening
## and the app losing focus.
func release() -> void:
	_pointer = POINTER_NONE
	steer = 0.0


## Drops the held drag **only if [param index] is the pointer holding it**, and
## answers whether it was. [method release] lets go of whatever is held, which
## is right for a pause and wrong for normal_mode.gd's placing gesture
## (dna-body.md §8): that gesture takes one finger off the steering, and it was
## measured taking the wrong one -- a second finger held on the body dropped the
## first finger's steer from +0.42 to 0. This is the one-finger half.
func release_pointer(index: int) -> bool:
	if index == POINTER_NONE or _pointer != index:
		return false
	release()
	return true


# ---------------------------------------------------------------------------
# Input. Drag on touch, A/D or the arrows on desktop; both work at once and
# neither costs a pixel of screen.
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Touch is read straight, and the mouse only claims the pointer when touch
	# has not. Godot emulates mouse events from touch by default, so the two
	# arrive as a pair on Android; this is what stops them fighting. Positions
	# are absolute rather than relative for the same reason -- a duplicated
	# event then changes nothing.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_claim(touch.index, touch.position)
			return
		# **`_dropped()` is not a predicate -- it lets the control go.** It has
		# to run on every release, whoever owned the pointer, and only then does
		# its answer decide whether this was also the floating stick's gesture.
		# Written as `not _dropped(i) and _pointer == i` that was correct by
		# evaluation order alone: reverse the two and a pad is never released at
		# all, because the cheap-looking test in front would skip the call. The
		# named local says which of those two lines this is, and this is the
		# input path every player is on.
		var released_a_control := _dropped(touch.index)
		if not released_a_control and _pointer == touch.index:
			_let_go()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _moved(drag.index, drag.position):
			return
		if _pointer == drag.index:
			_pointer_x = drag.position.x
		return

	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_claim(POINTER_MOUSE, click.position)
			return
		# The same release, the same reason it is named. See the touch branch.
		var released_a_control := _dropped(POINTER_MOUSE)
		if not released_a_control and _pointer == POINTER_MOUSE:
			_let_go()
		return

	if event is InputEventKey:
		# `myoneme` on desktop. Space is the only key normal mode spends besides
		# the steer keys, the push and hold keys (polled, in `_pushing` and
		# `_holding`), V and R, and it is the one key nothing else wants.
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			# **A new press of a key the hand drives with takes the cell back**
			# (row 36): a key held through the switching-on sends no new press,
			# and takes nothing back until it is pressed again.
			if _hand_key(key):
				_hand_pressed()
			if key.keycode == KEY_SPACE:
				_dash()
		return

	# A pad's d-pad steers as the arrows do, through the same actions, and a new
	# press of it is the hand's as much as a key's.
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		for action: StringName in HAND_ACTIONS:
			if event.is_action_pressed(action):
				_hand_pressed()
				break
		return

	if event is InputEventMouseMotion:
		var moved := event as InputEventMouseMotion
		if _moved(POINTER_MOUSE, moved.position):
			return
		if _pointer == POINTER_MOUSE:
			_pointer_x = moved.position.x


## **A press, offered to the drawn controls first.** Under `anywhere` there are
## none, [method Controls.press] answers `NONE` on every point, and what follows
## is exactly the floating stick this file has always been. Under `stick` and
## `pads` a press that misses every control is **nothing at all**: no steer, no
## thrust, no dash. The water is inert under those schemes, which is the scheme
## the player chose.
##
## The dash fires here, on the press, and never on the release -- a dash that
## waits for a lift is a dash that arrives after the thing that was chasing you.
##
## **And it is the hand, by the scheme's own rule** (automation.md §2.3): a press
## a drawn control takes, or under `anywhere` a press anywhere on the water --
## which is also where a dash, a push and the placing of a gene begin. Under
## `stick` and `pads` open water is inert and takes nothing back. While the
## autopilot has the cell that press takes it back first, on this frame, and
## then does what it does.
func _claim(index: int, at: Vector2) -> void:
	if controls != null:
		var id: int = controls.press(index, at)
		if id != controls.NONE or controls.floating():
			_hand_pressed()
		if id == controls.DASH:
			_dash()
			return
		if id != controls.NONE:
			return
		if not controls.floating():
			return
	else:
		_hand_pressed()
	if _pointer == POINTER_NONE:
		_grab(index, at.x)


## **A new press of the hand's** (row 36): the autopilot, if it has the cell,
## gives it back -- the run hears [signal took_back] and switches it off in the
## same frame. Nothing while the hand is silenced: a pond's open menu is moving
## focus, not taking the cell.
func _hand_pressed() -> void:
	if autopilot and not steering_off:
		took_back.emit()


## The keys the hand drives with: steering, the push and the hold, by their
## actions and by the letters read raw, and the dash's Space.
const HAND_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
const HAND_KEYS: Array[int] = [KEY_A, KEY_D, KEY_W, KEY_S, KEY_SPACE]


func _hand_key(key: InputEventKey) -> bool:
	if HAND_KEYS.has(key.keycode) or HAND_KEYS.has(key.physical_keycode):
		return true
	for action: StringName in HAND_ACTIONS:
		if key.is_action_pressed(action):
			return true
	return false


## True when that pointer belongs to a drawn control, which owns every later
## event of its gesture. Ownership is decided once, at the press, and keyed by
## pointer index -- nothing here ever asks what is under a finger now.
func _moved(index: int, at: Vector2) -> bool:
	return controls != null and controls.move(index, at)


func _dropped(index: int) -> bool:
	return controls != null and controls.release(index) != controls.NONE


func _grab(index: int, x: float) -> void:
	_pointer = index
	_pointer_anchor = x
	_pointer_x = x
	_pointer_at = float(Time.get_ticks_msec()) * 0.001
	_pointer_from = x


## A press ending. **Short and still is a tap, which is `myoneme`; anything
## else was a steer.** One gesture carries both, so the dash costs no pixel of
## screen and no second finger -- and a player with no myoneme just lifts their
## thumb, exactly as they always have.
func _let_go() -> void:
	var held := float(Time.get_ticks_msec()) * 0.001 - _pointer_at
	var moved := absf(_pointer_x - _pointer_from)
	release()
	if held <= TAP_SECONDS and moved <= TAP_SLOP:
		_dash()


## True while the player is asking for thrust: a key down, or a finger on the
## screen. Deliberately the same gesture that steers -- pushing and turning are
## things you do at the same time.
func _pushing() -> bool:
	if steering_off:
		return false
	if Input.is_action_pressed(&"ui_up") or Input.is_key_pressed(KEY_W):
		return true
	if controls != null and not controls.floating():
		# Touching the stick, under `stick`; the `push` pad, under `pads`.
		return controls.pushing()
	return _pointer != POINTER_NONE


## **True while the hand holds the tail still** (automation.md §5.2;
## automation-ux.md §6): `S` or `↓` held -- the opposite of `W` and `↑`, which
## push -- or the hold pad, which controls.gd draws under every scheme once the
## tail can be held. Held, not toggled, as push is: let go and the tail beats on
## its own clock. Only asked of a tail at [method hold_level] ([method
## _process]), so at a level-1 tail the key does nothing. `S` and `↓` are read
## the way `W` and `↑` are, and a content pack adds no action for them.
func _holding() -> bool:
	# **The instincts' hold, while the autopilot has the cell**: the flagellum's
	# own, or a rest at this level (automation.md §4.2).
	if _driven():
		return bool(instincts.call(&"holds_tail"))
	if steering_off:
		return false
	if Input.is_action_pressed(&"ui_down") or Input.is_key_pressed(KEY_S):
		return true
	return controls != null and bool(controls.holding())


## **The push's strength this frame**: an instinct's half or full while the
## autopilot has the cell, otherwise the hand's, which is full or nothing.
func _push_strength() -> float:
	if _driven():
		return float(instincts.call(&"push_strength"))
	return 1.0 if _pushing() else 0.0


## Whether the instincts drive this frame.
func _driven() -> bool:
	return autopilot and instincts != null


## **A dash an instinct fires** (automation.md §4.2): the hand's own burst, on its
## cooldown and at its price -- past [member steering_off], which silences the
## hand only, as a water body's rules fire its dash.
func instinct_dash() -> void:
	_dash_now()


## The burst. Costs hunger, which the cell does not own, so the price leaves on
## a signal and the run pays it.
func _dash() -> void:
	if steering_off:
		return
	_dash_now()


func _dash_now() -> void:
	var speed := stat(&"dash_speed")
	if speed <= 0.0 or _dash_timer > 0.0:
		return
	_dash_timer = DASH_COOLDOWN
	velocity += forward() * speed
	dashed.emit(stat(&"dash_cost"))
	impulsed.emit(1.0)


func _read_steer() -> float:
	if steering_off:
		return 0.0
	var keys := 0.0
	if Input.is_action_pressed(&"ui_left") or Input.is_key_pressed(KEY_A):
		keys -= 1.0
	if Input.is_action_pressed(&"ui_right") or Input.is_key_pressed(KEY_D):
		keys += 1.0
	if keys != 0.0:
		return keys
	# **Keys are unchanged under every scheme.** The scheme is a touch choice; a
	# desktop player who picks `pads` gets the pads *and* the keys.
	if controls != null and not controls.floating():
		return controls.steer()
	if _pointer == POINTER_NONE:
		return 0.0
	return clampf((_pointer_x - _pointer_anchor) / DRAG_SPAN, -1.0, 1.0)
