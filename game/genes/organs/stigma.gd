extends "res://game/genes/gene.gd"
## `stigma`: **the eyespot, and it sees** (docs/design/sight.md; the owner,
## 2026-10-16: *"It will act like real vision. It will be impacted by light, have a
## field of view, start blurred and improve with levels, and won't allow, like
## beam, to see behind objects"*).
##
## - **A field**: [constant SIGHT_HALF_DEG] either side of the slot it is worn on.
## - **Light**: it sees [constant SIGHT_RANGE] in full light, and less as the light
##   falls, down to [constant SIGHT_DARK] of that with none.
## - **Blur**: [constant SIGHT_BLUR_START_DEG] at level 1, sharper every level, never
##   past [constant SIGHT_BLUR_FINEST_DEG]. A body narrower than the blur comes
##   through faint. Levels come from seeing: every different body in view in a
##   second, up to [constant SIGHT_XP_CAP].
## - **Nothing behind a body**: what is nearer hides what is behind it.
##
## The mechanic is game/mechanics/sight.gd, which names no eye. `food.gd` asks
## this organ's numbers through the catalogue, by its channel; nothing outside
## game/genes/ names it.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

## The readout's items (game/mechanics/readout.gd, which preloads nothing): what
## [method lines] says this organ's numbers with.
const Readout := preload("res://game/mechanics/readout.gd")
const U := Readout.Unit
## The view, its blur by level (game/mechanics/sight.gd, which preloads nothing).
const Sight := preload("res://game/mechanics/sight.gd")

## **How far it sees in full light**, and how near a body has to be to come through
## the water whole: the shadow's old reach and core, which kept it inside the wake's
## 760 -- the eye sharpens what the cell knows nearby, it does not reach further.
const SIGHT_RANGE := 620.0
const SIGHT_CORE := 180.0
## **Its field, either side of the slot it is worn on**: 120 degrees in all, a third
## of the way round. A starting value: an eyespot is a pigment cup, which sees
## one side well and the other not at all, so where it is worn decides what it
## sees -- as it does the beam's.
const SIGHT_HALF_DEG := 60.0
## **What it keeps in the dark**: its reach and its picture at this share with no
## light at all, everything in full light. Not nothing, because a night that
## blinded every eye would be the "mask" the owner ruled out for night's look
## (daylight.md §0); low enough that a deep or dark eye is a short one.
const SIGHT_DARK := 0.3
## **Its blur, by level** (Sight.blur_at): 36 degrees at level 1, 19 at 2, 13 at 3
## -- where the old lobe's three tiers were -- and on toward 2 for good. A body your
## size 200 µm off is about 15 degrees wide, so a level-1 eye sees it at less than
## half its strength and a level-3 eye whole.
const SIGHT_BLUR_START_DEG := 36.0
const SIGHT_BLUR_FINEST_DEG := 2.0
## **Levels come from seeing**, as the beam's come from touching (beam-levels.md
## §2): one for every different body in view in a second, up to this many, with
## the beam's curve -- level 2 at 40, level 3 at 120.
const SIGHT_XP_STEP := 40.0
const SIGHT_XP_CAP := 3
## **A sharper eye costs more to run, and never much**: this much on the metabolic
## multiplier for all of the sharpening there is, in proportion to how much of it
## a level has reached -- nothing at level 1, half at level 2. One old tier's
## price, so a sharp eye costs about what a second copy did.
const SIGHT_SHARP_COST := 0.18


# --- Its words (gene.gd; gene-catalogue.md §8.1) -------------------------------------

## **Its chip word** (gene.gd's word tables): the plain word, never the biological
## name -- one short word for what it does, read at arm's length (figure.gd).
##
## TRANSLATORS: A gene's name as the player reads it on a chip beside three small
## dots: one short lowercase word, a verb or a noun for what the gene does. The
## `entry` line says which gene it names (its scientific name, never translated).
## It has to be short: prefer the shortest everyday word. The same words appear
## inside sentences such as "let go to swap eat and ping".
## ROOM: 47 px at 13 px
const WORDS := {&"stigma": "see"}
## **What it does to the player, in one line**, after its name on the pause screen.
##
## TRANSLATORS: What a gene does, in one line shown after the gene's scientific
## name and a middle dot: "cytostome · a wider mouth swallows bigger things
## whole". Lowercase, plain words, no numbers. It has little room: it meets the
## "numbers" switch at its right, so a translation should be no longer than the
## English. "That side" is the side of the body where the gene's slot is. The
## `entry` line says which gene.
## ROOM: 440 px at 15 px
const EXPLAINS := {&"stigma": "sees what is in front of it, sharper with use"}
## **What its sense is called** on an instinct's chip: what the organ reports, as
## the player knows it -- a word of its own, apart from its chip word.
##
## TRANSLATORS: The name of a sense on a small chip of the player's "instincts"
## (rules: "when <a sense reports something> -> <do this>"): what one organ of the
## cell reports. "beam": what the light the cell's ocellus casts lands on; "echo":
## what comes back of the cell's ping; "smell": the smell of food; "shadow": a
## body the cell's eyespot sees, dark against the light; "touch": something
## against the cell's skin, felt by its palps. Lowercase, one short word.
## ROOM: 112 px at 15 px
## CONTEXT: sense
const GENE_SENSES := {&"stigma.shadow": "shadow"}
## **The line that explains it** on the instincts page.
##
## TRANSLATORS: Explains one sense, action or value of the player's "instincts",
## on one line under them: its name (the same words as on its chip), a middle
## dot, then what it is or does, lowercase. "Your ping" is the cell's ampulla,
## which calls and listens; "your beam" its ocellus; "your nose" its chemocyte;
## "your eyespot" its stigma; "your palps" its palp. "Your tail" is the cell's
## flagellum, which swims; "two copies" means the gene is carried twice in the
## cell's DNA, which is what lets the tail be held still. "For free" means it
## costs no food.
## ROOM: 856 px at 15 px
const GENE_EXPLAINS := {
	&"stigma.shadow": "shadow · what your eyespot sees in front of it: where, and how clearly.",
}


func _init() -> void:
	organ = &"stigma"
	order = 3
	levels = {"step": SIGHT_XP_STEP, "fork": 0, "paths": [] as Array[StringName],
		"earns": &"sight"}
	numbers = {&"xp_cap": SIGHT_XP_CAP, &"sight_range": SIGHT_RANGE,
		&"sight_core": SIGHT_CORE, &"sight_half_deg": SIGHT_HALF_DEG,
		&"sight_dark": SIGHT_DARK, &"sight_blur_deg": SIGHT_BLUR_START_DEG,
		&"sight_finest_deg": SIGHT_BLUR_FINEST_DEG, &"sharp_cost": SIGHT_SHARP_COST}
	# **Uncommon, as every organ a run is built from** (gene-rarity.md §4): it weighs
	# an uncommon's 2 in the water's draws, as the eye-spot does, where it weighed 3
	# before the draws went by class -- a step the ladder does not have.
	water = {"rarity": &"uncommon", "drifter": true}
	tags = [SENSE, GIFT]
	channel = LIGHT
	declares = {"in": [{"name": &"shadow", "bearing": true,
		"values": {&"level": &"level"}}]}
	# **Its look** (gene-looks.md §6): three short plain bristles over its pigment,
	# the plainest sense.
	family = SENSING
	# **Its tile in the HUD's row** (gene.gd's `readout`; sense-tiles.md): the organ
	# lit by the shadow it is under.
	readout = true
	# **A sense that points pays half** (gene.gd's `upkeep_share`;
	# docs/design/energy.md §8): the owner, 2026-10-15. Since it levels, what it
	# pays is its sharpness ([method upkeep_at]), at half. A starting value, for
	# play to judge.
	upkeep_share = 0.5
	look = {"shape": TUFT, "count": 3, "length": 0.26, "tip": Kinds.TIP_PLAIN}


## **Its blur at [param level]**, in degrees.
func blur_deg_at(level: int) -> float:
	return Sight.blur_at(level, SIGHT_BLUR_START_DEG, SIGHT_BLUR_FINEST_DEG)


## **What its sharpness at [param level] adds to the metabolic multiplier**
## (gene.gd's `upkeep_at`): [constant SIGHT_SHARP_COST] times how much of the
## sharpening there is it has reached. It has no path.
func upkeep_at(level: int, _path: StringName) -> float:
	var span := SIGHT_BLUR_START_DEG - SIGHT_BLUR_FINEST_DEG
	return SIGHT_SHARP_COST * (SIGHT_BLUR_START_DEG - blur_deg_at(level)) / span


## **Its numbers on the pause screen** (gene.gd's `lines`): its field, how far it
## sees in full light and in none, how sharp it is at its level, and what that
## sharpness costs.
##
## TRANSLATORS: The seeing gene (`stigma`, shown as `see`): an eyespot. "{} either
## side" is how far round it sees from where it is worn, in degrees. "Sharp to
## within {}" is its blur: a thing narrower than that many degrees looks faint.
func lines(_t: int, level: int, _path: StringName, ctx: Dictionary, _slot: int,
		_wear: Dictionary) -> Array:
	var burn := float(ctx.get("burn", 1.0))
	var at := maxi(level, 1)
	var costs := [(ctx["wear_item"] as Callable).call(upkeep_at(at, &"") * upkeep_share, burn)]
	return [[Readout.item("sees {} either side", [SIGHT_HALF_DEG], [U.ANGLE]),
			Readout.item("out to {} µm in full light, {} µm in none",
				[SIGHT_RANGE, SIGHT_RANGE * SIGHT_DARK], [U.DISTANCE, U.DISTANCE]),
			Readout.item("sharp to within {}", [blur_deg_at(at)], [U.ANGLE])],
		costs]
