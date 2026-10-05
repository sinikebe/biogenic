extends RefCounted
## **One organ** (docs/design/gene-catalogue.md §4.2): what a gene builds, and
## every fact any system asks of it -- its numbers, its place in the water, its
## tags, what it gives a body's rules, its look, its words and its lines on the
## pause screen -- in one file of its own under `organs/`. An organ's file extends
## this one and sets the fields it needs in `_init()`; every field it leaves keeps
## the default written here.
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

## **The two places** (docs/design/dna-slots.md §2): the slots round the body,
## and the one inside it. `genome.gd`'s OUTSIDE_PLACE and INSIDE_PLACE are
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
## - `not_on_drifters`: no drifter carries it, in any form, so the drop's
##   defenceless food stays harmless to eat (ocean.md §5.8) -- the toxin
##   (`food.gd`, `drop.gd`).
## - `floor_by_peers`: the gene floor gives it back through the next peer, never a
##   drifter, its place by a coin -- the toxin again (gene-catalogue.md §6.4).
##   Every variant of it inherits both, so a second strain is covered by every rule.
const SENSE := &"sense"
const GIFT := &"gift"
const ALWAYS_EXPRESSED := &"always_expressed"
const NEVER_DRIFTS := &"never_drifts"
const RETIRED := &"retired"
const NOT_ON_DRIFTERS := &"not_on_drifters"
const FLOOR_BY_PEERS := &"floor_by_peers"
## Every tag an organ may carry. The gene probe fails on any other.
const TAGS: Array[StringName] = [SENSE, GIFT, ALWAYS_EXPRESSED, NEVER_DRIFTS, RETIRED,
	NOT_ON_DRIFTERS, FLOOR_BY_PEERS]

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

## **The families and the shape kinds** (docs/design/gene-looks.md §1, §2, §7): what
## an organ looks like is its family's colour and a kind's build, both data. Neither
## file preloads anything of the game. `cilia.gd` draws by kind and never by a gene's
## name.
const Families := preload("res://game/genes/families.gd")
const Kinds := preload("res://game/genes/kinds.gd")
## The five families, for an organ's [member family].
const EATING := Families.EATING
const MOVING := Families.MOVING
const SENSING := Families.SENSING
const DEFENDING := Families.DEFENDING
const METABOLISM := Families.METABOLISM
## The nine kinds, for a look's `shape`: the mouth's `mat`; the movers' `oars`,
## `lash` and `coil`; the senses' `tuft` and `lens`; the defences' `spines` and
## `plates`; metabolism's `organelle`. Their tips, forms and accent marks are
## `Kinds.TIP_*`, `Kinds.FORM_*` and `Kinds.MARK_*`.
const MAT := Kinds.MAT
const OARS := Kinds.OARS
const LASH := Kinds.LASH
const COIL := Kinds.COIL
const TUFT := Kinds.TUFT
const LENS := Kinds.LENS
const SPINES := Kinds.SPINES
const PLATES := Kinds.PLATES
const ORGANELLE := Kinds.ORGANELLE
## Every shape there is. The gene probe fails on any other.
const SHAPES := Kinds.KINDS

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
## may be made of it (false if unset). **The water draws an organ first, then one
## of its variants** (gene-catalogue.md §6.1): an organ by its own weight -- this
## field as its file sets it, or, where only its variants set one, its first
## variety's -- and then a variant by the weight each answers, its share of the
## organ's draws. **A variant is drawn by its variety**, its first form: its other
## forms answer the same weight and are in no list of the water's.
var water := {}

## **Its tags**: any of [constant TAGS]. A variant's or a form's are added to its
## organ's, never in place of them.
var tags: Array[StringName] = []

## **The channel it drives** on the membrane, one of [constant CHANNELS], for a
## sense organ: how a mechanic finds the organ of a channel with no number of its
## own -- the shade, which `food.gd` and `normal_mode.gd` gate on whether the
## body wears the eyespot. `&""` for an organ that drives none.
var channel: StringName = &""

## **Its look** (docs/design/gene-looks.md §2, §7): what `cilia.gd` draws it as, on a
## body and on a genome tile -- `shape`, a kind its [member family] is built as
## ([constant SHAPES]); that kind's parameters where it wants other than their
## defaults (`kinds.gd`: a count, a length, a tip, a bend, a form ...); and
## `shade`, which of its family's three it wears, the middle where it sets none.
## **No colour**: its hue is its family's shade, which the catalogue works out, so
## two organs of one family share a colour and are told apart by shape. **A variant
## sets `accent` and nothing else** in its look -- `disc`, `ring`, `diamond` or `bar`,
## drawn at its kind's seat, unlike its organ's and every sibling's -- and keeps
## everything else of its organ's, so it reads as its organ at a glance (§3). Empty
## for a retired gene, which draws as a gene the build does not know: a plain tuft
## in no family's colour.
var look := {}

## **Its family** (docs/design/gene-looks.md §1): one of `families.gd`'s five --
## eating, moving, sensing, defending or metabolism -- whose colour it wears and
## whose builds its look picks from. **The organ's own**: a variant never sets it,
## so a variant is its organ's colour. `&""` for a retired gene with no look.
var family: StringName = &""

## **The copies a newborn wears of it** (`genome.gd`'s born cell): the mouth, the
## cirrus and the tail, one each. 0 for a gene no cell is born with, and for a
## variant that does not set it: a variant does not take its organ's. The host's
## referee judges by this: a change moves Wire.RULES, not Wire.PROTOCOL (wire.gd).
var born := 0

## **One variant to a body** (gene-catalogue.md §6.3): placing a second variant of
## this organ writes over the first, as the inside's one poison does, and the water
## and drift never give a body a second. Off for every organ today, since nothing
## today can carry two: the gene pass sets it per organ when it adds variants. The
## organ's own, never a variant's.
var one_variant := false

## **What it gives a body's rules** (docs/design/behaviour.md §3), in the shape
## `rulebook.gd`'s vocabulary reads: `{"in": [...], "out": [...]}`, the inputs it
## senses and the outputs it triggers. Empty for an organ that only acts on its
## own, as the dart, the call and the mouth do (§3.3). A part may wait for a
## level (automation.md §4.3). Its words are its file's (below).
var declares := {}

# --- Its words (gene-catalogue.md §8.1) -----------------------------------------------
#
# **An organ's words are constants of its own file**, each a table keyed by the
# key it is said of -- or, for a part it declares, by the part's qualified name,
# `palp.touch` -- and each with the TRANSLATORS note, the ROOM and the CONTEXT its
# strings had before there were organ files: tools/i18n_pot.gd lists every such
# constant in the template, so a translator reads what they always read. The
# catalogue reads them by name (its KEY_WORDS and PART_WORDS) and the screens
# translate what it hands them:
#
#   WORDS           its chip word, one short word         figure.gd's word_of
#   EXPLAINS        what it does, one line                 figure.gd's explains
#   EXPLAINS_SIDE   that line for a venom on a side, and
#   EXPLAINS_STERN  at the stern
#   EXPLAINS_PATH   way to the line once a fork is taken
#   CARRIED_WORDS   its word while it waits to be placed, for a gene of forms
#   CARRIED_EXPLAINS  and its line then
#   NAMES           its name on screen where it is not its key (not translated)
#   VARIANT_WORDS   a variant's word, after its organ's name on the explaining
#                   line -- `toxicyst · paralysing` -- for every variant but the
#                   organ as shipped                       figure.gd's explain_name
#   GENE_SAYS       an action part's chip                  program_words.gd
#   GENE_SENSES     a sense part's chip, in the context `sense`
#   GENE_EXPLAINS   a part's line on the instincts page
#   GENE_ASLEEP     what an instinct using a part says while it waits for a level
#   GENE_NEEDS      what the page says when it is picked too early
#
# An organ whose levels fork has the words of its ways too, keyed by way and said
# of every key of the organ (the catalogue's WAY_WORDS; normal_mode.gd's way
# cards):
#
#   PATH_TITLES     each way's name
#   PATH_LINES      each way's two lines on its card
#   PATH_SAYS       what each way does as it grows, after its name
#
# A variant has keys of its own, so it brings its own words in the same tables.

## **Its variants after the first** (§6): each a dictionary with its `variant`
## name, the `dose` it delivers (the toxin's strain, doses.gd's name for a kind),
## its `forms` -- place to the form's key, or to a dictionary with the form's `key`
## and anything the form sets of its own -- and anything else the variant sets over
## its organ. A variant's first form is its variety. **A variant with no `forms` is
## one form, outside**, keyed by its own `key` or, without one, by its name. Empty
## for an organ of one variant.
##
## **The organ's own key is its first variant**, implicit: the organ as it shipped,
## filed under [member organ] (gene-catalogue.md §6.2). So a faster tail is one
## entry, and the tail keeps its key: `[{"variant": &"swift", "key": &"swiftail",
## "order": 17, "look": {"accent": &"disc"}, "provides": {...}}]`. **A variant sets
## its own `order`** -- the next one -- or it would take its organ's and tie it in
## `dominant_of`, which the gene probe fails; and **it is born with no copies**, its
## `born` 0 unless it says, the one field it does not take from its organ.
## **An organ with no `order` of its own lists its first variant here too**, and its
## name is no key: the toxin, whose first strain sits in two places, each form with
## its own key and order.
var variants: Array = []

# --- What the catalogue writes, per key ------------------------------------------------

## **The key**: the permanent name of this one form, what the DNA, the body, the
## wire, saves and the replay hold. 1 to 16 letters `a-z` (Wire.NAME_MAX), for
## good once shipped (§4.4).
var key: StringName = &""
## The variant this form is of: `&""` for the organ's own key, its implicit first
## variant, so every variant [member variants] lists needs a name of its own.
var variant: StringName = &""
## The place this form sits in: [constant OUTSIDE] or [constant INSIDE].
var place: StringName = OUTSIDE
## The kind of dose this form delivers, by doses.gd's name, `&""` for none.
var dose: StringName = &""


# --- Hooks: what an organ answers that is no plain field -------------------------------

## **[param stat] at [param t] copies of this key**, off its own table and clamped
## to it, as `stats.gd`'s `value` reads a table: what a line of its own ([method
## lines]) says. **0 for a stat it does not provide**, where `value` answers the
## stat's value with no provider: this file cannot ask `stats.gd`, which loads the
## organ files, and a line only ever reads a stat its own organ provides.
func stat_at(stat: StringName, t: int) -> float:
	var table: Array = provides.get(stat, [])
	if table.is_empty():
		return 0.0
	return float(table[clampi(t, 0, table.size() - 1)])


## **What it adds to the metabolic multiplier at [param level] down [param path]**,
## for an organ that prices its own levels (docs/design/beam-levels.md §5): the
## beam's price per level is the beam's. -1 for an organ with no price of its
## own, which `genome.gd` charges at the old per-tier rate, by level.
func upkeep_at(_level: int, _path: StringName) -> float:
	return -1.0


## **What one stack of its dose does**, a readout item, for a key that delivers a
## dose ([member dose]): each kind its own line, read off the key's own dose --
## a second strain says its kind's, never harm's. Empty for a key with no dose, and
## for a kind its organ has no line for, which the gene probe fails.
func dose_line(_ctx: Dictionary) -> Dictionary:
	return {}


## **Its numbers on the pause screen** (gene-catalogue.md §8.4; gene-stats.md §5):
## `[what it does, what it costs]`, each an array of readout items, for this key
## worn at [param t] copies -- or, for an organ that levels, at [param level]
## down [param path] -- worn at [param slot] (-1 where nobody knows). [param ctx]
## is `gene_stats.gd`'s context: the body's own terms (`burn`, `reserve`, `sun`,
## `tank`, `radius`); the scripts a line reads numbers from (`cell`,
## `metabolism`, `food`, `bus`, `genome`), passed in because an organ preloads
## none of them; and the screen's own `beat` and `wear_item`, so that a line
## prices as the screen does. [param wear] is the costs line's last item, what
## wearing it costs at [param t]. `[[], []]` for an organ with no lines, which
## draws nothing.
func lines(_t: int, _level: int, _path: StringName, _ctx: Dictionary, _slot: int,
		_wear: Dictionary) -> Array:
	return [[], []]
