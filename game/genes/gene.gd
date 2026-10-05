extends RefCounted
## **One organ** (docs/design/gene-catalogue.md §4.2): what a gene builds, and
## every fact any system asks of it -- its numbers, its place in the water, its
## tags and what it gives a body's rules -- in one file of its own under
## `organs/`. An organ's file extends this one and sets the fields it needs in
## `_init()`; every field it leaves keeps the default written here.
##
## **An organ, its variants and their forms** (§3, §6.1). A variant is the organ
## built differently: its own numbers, its own name and its own place in the
## water, the same mechanic. A form is a variant in one place -- the toxin's one
## strain is `veneneux` inside and `toxicyst` outside. A form sets anything its
## variant sets and a variant anything its organ sets; a dictionary field is
## written over key by key, so a variant that sets one table keeps the organ's
## others, and tags add up, so a variant that sets one keeps the organ's. An
## organ with no [member variants] is one variant in one place, and its one key
## is its organ's name.
##
## **The catalogue resolves that inheritance once**, when it loads, into one flat
## record per key -- a fresh instance of the organ's own script, with its variant
## and its form written over it -- so every reader asks about a key and never
## walks the inheritance, and a hook is the organ's own whichever form it is.
##
## **It preloads nothing from game/normal, game/net, game/vision or
## game/perception**, and nor may an organ's file: `genome.gd`, `cell.gd`,
## `food.gd` and the referee all preload the catalogue, so anything the catalogue
## preloaded back would be the cycle `cell.gd` already warns about. A hook takes
## what it needs as arguments.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

# --- The words fields are written in ------------------------------------------------

## **The two places** (docs/design/dna-slots.md §2): the seven slots round the
## body, and the one inside it. `genome.gd`'s OUTSIDE_PLACE and INSIDE_PLACE are
## these.
const OUTSIDE := &"outside"
const INSIDE := &"inside"

## **The tags** (§3): facts about a gene other systems ask, through the
## catalogue's `tagged()` and `has_tag()`. A tag on an organ is on every variant
## and form of it.
##
## - `sense`: it answers *where is something*. The water counts how many tiers of
##   these a player wears to decide how much of it can hurt them, and gives one to
##   a peer that has none (`food.gd`, `drop.gd`).
## - `gift`: the free sense a newborn with none is given at five seconds is drawn
##   from these, flat (`normal_mode.gd`), and a host's referee lets a guest's body
##   gain one of them, once (`referee.gd`). Every one is a `sense` too.
## - `always_expressed`: a daughter always wears it, whatever its copies -- the
##   mouth, because a body born without one cannot feed itself (`genome.gd`).
## - `never_drifts`: a drift never writes over it and never brings it: the mouth
##   again, for the same reason (`genome.gd`'s `_mutate_drift`).
## - `retired`: known, drawn and inert (§4.4). It drops out of every list above
##   and every pool the water, drift and the gift draw from, and provides nothing.
##   Its key stays known for good, because saves and the wire keep it.
const SENSE := &"sense"
const GIFT := &"gift"
const ALWAYS_EXPRESSED := &"always_expressed"
const NEVER_DRIFTS := &"never_drifts"
const RETIRED := &"retired"
## Every tag an organ may carry. The gene probe fails on any other.
const TAGS: Array[StringName] = [SENSE, GIFT, ALWAYS_EXPRESSED, NEVER_DRIFTS, RETIRED]

## **The membrane's channels** (§7.3): which one a sense organ drives -- the
## shade of a body (`light`), what the beam strikes (`beam`), what the ping hears
## back (`ping`), food along the nose (`smell`), and something against the skin
## (`touch`). A sense on a channel that exists is data; a new channel is code.
const LIGHT := &"light"
const BEAM := &"beam"
const PING := &"ping"
const SMELL := &"smell"
const TOUCH := &"touch"
## Every channel there is. The gene probe fails on any other.
const CHANNELS: Array[StringName] = [LIGHT, BEAM, PING, SMELL, TOUCH]

# --- What an organ's file sets ---------------------------------------------------------

## **The organ**: what its gene builds -- one look, one mechanic, one set of
## numbers -- and the key of its one form while it has one variant in one place.
## Read by the catalogue (`organ_of`), and through it by everything that asks
## which forms are one gene (`genome.gd`'s forms).
var organ: StringName = &""

## **Its place in the order**: the tie-break of `genome.gd`'s `dominant_of` --
## of two genes worn at the same copies the body is drawn as the earlier, and
## eating it gives that one -- and the order every list of keys comes in.
## **Append-only** (§4.4): a new gene takes the next number, and none ever moves,
## or a body drawn one way is drawn another. A form sets its own, as the toxin's
## two do. -1 is no place at all: a gene taken out of the order before the
## catalogue existed, which `dominant_of` ranks as it ranks a name it does not
## know -- exactly as it did when that gene left.
var order := -1

## **The stats it provides** (§5): stat to its value at each tier, index 0 being
## the stat's value with no provider -- `stats.gd`'s row -- and one entry for each
## copy up to `genome.gd`'s TIER_MAX. Every body's stat is read through
## `stats.gd`, which knows no gene; the fingerprints that list every table
## (`drop_save.gd`'s rules, `tools/net_probe.gd`'s RULES) read them from here.
var provides := {}

## **Its own numbers**, by name, that are no table by tier: what its mechanic
## asks of the organ wearing it, through the catalogue's `number()` -- the tail's
## level that can be held still, the dart's stun, the beam's costs.
var numbers := {}

## **How it earns levels** (docs/design/beam-levels.md), for an organ that does:
## `step` (what going from level L to L + 1 costs, over L), `fork` (the level its
## fork opens at, 0 for none) and `paths` (what the fork offers, an
## `Array[StringName]`). Empty for an organ whose strength is its copies. Read by
## `genome.gd`, which keeps a progression for every gene that levels.
var levels := {}

## **Its place in the water** (§9): `weight`, how often a draw takes it against
## the others (`food.gd`'s draws; 1 if unset), and `drifter`, whether a drifter
## may be made of it (false if unset). **The water draws a variant by its
## variety**, its first form: its other forms answer the same weight and are in
## no list of the water's.
var water := {}

## **Its tags**: any of [constant TAGS]. A variant's or a form's are added to its
## organ's, never in place of them.
var tags: Array[StringName] = []

## **The channel it drives** on the membrane, one of [constant CHANNELS], for a
## sense organ: how a mechanic finds the organ of a channel with no number of its
## own -- the shade, which `food.gd` and `normal_mode.gd` gate on whether the
## body wears the eyespot. `&""` for an organ that drives none.
var channel: StringName = &""

## **The copies a newborn wears of it** (`genome.gd`'s born cell): the mouth, the
## cirrus and the tail, one each. 0 for a gene no cell is born with. The host's
## referee judges by this: change it with Wire.PROTOCOL and Wire.RULES (wire.gd).
var born := 0

## **What it gives a body's rules** (docs/design/behaviour.md §3), in the shape
## `rulebook.gd`'s vocabulary reads: `{"in": [...], "out": [...]}`, the inputs it
## senses and the outputs it triggers. Empty for an organ that only acts on its
## own, as the dart, the call and the mouth do (§3.3). A part may wait for a
## level (automation.md §4.3). Its words are still `genome.gd`'s.
var declares := {}

## **Its variants**, the first being the organ as it shipped (§6): each a
## dictionary with its `variant` name, the `dose` it delivers (the toxin's
## strain, doses.gd's name for a kind), its `forms` -- place to the form's key,
## or to a dictionary with the form's `key` and anything the form sets of its own
## -- and anything else the variant sets over its organ. A variant's first form
## is its variety. Empty for an organ of one variant in one place.
var variants: Array = []

# --- What the catalogue writes, per key ------------------------------------------------

## **The key**: the permanent name of this one form, what the DNA, the body, the
## wire, saves and the replay hold. 1 to 16 letters `a-z` (Wire.NAME_MAX), for
## good once shipped (§4.4).
var key: StringName = &""
## The variant this form is of, `&""` for an organ of one.
var variant: StringName = &""
## The place this form sits in: [constant OUTSIDE] or [constant INSIDE].
var place: StringName = OUTSIDE
## The kind of dose this form delivers, by doses.gd's name, `&""` for none.
var dose: StringName = &""


# --- Hooks: what an organ answers that is no plain field -------------------------------

## **What it adds to the metabolic multiplier at [param level] down [param path]**,
## for an organ that prices its own levels (docs/design/beam-levels.md §5): the
## beam's price per level is the beam's. -1 for an organ with no price of its
## own, which `genome.gd` charges at the old per-tier rate, by level.
func upkeep_at(_level: int, _path: StringName) -> float:
	return -1.0
