extends RefCounted
## **The genes a body carries in its genes' own slots** (docs/design/gene-sockets.md):
## the one shape every system keeps them in, and every question asked of it.
##
## **A riders map** is host key to its slots, in the order the host's file declares
## them (gene.gd's `sockets`), each `[rider key, copies]`, an empty slot `[&"", 0]`.
## A host with nothing in any slot is not in it. It sits beside a `{key: copies}` map,
## never inside one: **a rider is no gene of the body's** (§4), so nothing that reads
## a body's stats, its upkeep's tiers, its controls, its instincts or what eating it
## gives ever sees one -- only a host's mechanic asking for what its slots give
## ([method value]).
##
## A host or a rider this build does not know is kept by name and does nothing, as an
## unknown gene is: a slot it does not know of is kept where it stands.
##
## Preloads only the catalogue, which preloads nothing of the game. No class_name,
## for the reason signal_bus.gd gives. Preload it by path.

const Catalogue := preload("res://game/genes/catalogue.gd")

## The most copies a rider has, as a gene does (genome.gd's TIER_MAX).
const COPIES_MAX := 3

## What [method put] did.
enum Put {
	NOTHING,   ## it does not fit, or the slot is full of it already
	WROTE,     ## into an empty slot, or over another rider
	RAISED,    ## one more copy of the rider already there
}


## **A copy of [param riders]** that shares nothing with it: every slot its own
## array, every name a StringName. Anything that is not a riders map reads as an
## empty one.
static func copy(riders: Variant) -> Dictionary:
	var out := {}
	if not riders is Dictionary:
		return out
	for host: Variant in riders:
		var slots: Variant = riders[host]
		if not slots is Array:
			continue
		var kept: Array = []
		var any := false
		for one: Variant in slots:
			var rider := &""
			var copies := 0
			if one is Array and (one as Array).size() >= 2:
				rider = StringName(str(one[0]))
				copies = clampi(int(one[1]), 0, COPIES_MAX)
			if rider == &"" or copies <= 0:
				rider = &""
				copies = 0
			else:
				any = true
			kept.append([rider, copies])
		if any:
			out[StringName(str(host))] = kept
	return out


## **[param riders] for the hosts [param tiers] holds**: what a body wears of its DNA's
## riders (a rider is worn when its host is), and what a DNA keeps once a host has
## left it -- a write over the host takes them, as it takes itself.
static func kept(riders: Dictionary, tiers: Dictionary) -> Dictionary:
	var out := {}
	for host: StringName in riders:
		if int(tiers.get(host, 0)) > 0:
			out[host] = _slots_copy(riders[host])
	return out


## **The slots of [param host]**, `[rider, copies]` each, as many as it declares: a
## fresh array, an empty slot `[&"", 0]`. A host this build does not know answers the
## slots it was kept with.
static func of(riders: Dictionary, host: StringName) -> Array:
	var count := Catalogue.sockets(host).size()
	var held: Array = riders.get(host, [])
	var out: Array = []
	for at in maxi(count, held.size()):
		if at < held.size():
			out.append([StringName(held[at][0]), int(held[at][1])])
		else:
			out.append([&"", 0])
	return out


## **The rider in slot [param socket] of [param host]**, `&""` for none.
static func rider_at(riders: Dictionary, host: StringName, socket: int) -> StringName:
	var held: Array = riders.get(host, [])
	return StringName(held[socket][0]) if socket >= 0 and socket < held.size() else &""


## **Its copies**, 0 for none.
static func copies_at(riders: Dictionary, host: StringName, socket: int) -> int:
	var held: Array = riders.get(host, [])
	return int(held[socket][1]) if socket >= 0 and socket < held.size() else 0


## **What [param host]'s slots give it by [param stat]**: the first of its slots that
## gives the stat, read at its rider's copies -- its table's own `[0]` while it is
## empty. [param none] for a host none of whose slots gives it. This is the whole of
## what a rider does: a host's mechanic asks it, by the stat's name, and never asks
## what rides. **A rider that does not fit its slot gives nothing** -- one this build
## does not know, kept by name, or one no honest build put there.
static func value(riders: Dictionary, host: StringName, stat: StringName,
		none: float) -> float:
	var all := Catalogue.sockets(host)
	for socket in all.size():
		var gives: Dictionary = (all[socket] as Dictionary).get("gives", {})
		if gives.has(stat):
			var rider := rider_at(riders, host, socket)
			var copies := copies_at(riders, host, socket) \
				if rider != &"" and Catalogue.fits(host, socket, rider) else 0
			return Catalogue.gives(host, socket, stat, copies, none)
	return none


## **What the slots of the gene that provides [param provided] give it** by
## [param stat], for a body wearing [param tiers]: [method value] of whichever gene
## a mechanic acts through -- the tail's strokes through the provider of its speed.
## [param none] for a body that wears no provider of it.
static func through(riders: Dictionary, tiers: Dictionary, provided: StringName,
		stat: StringName, none: float) -> float:
	var host := Catalogue.worn_provider(tiers, provided)
	return value(riders, host, stat, none) if host != &"" else none


## **The rider that gives [param host] its [param stat]**, `&""` for none: whose
## strain a dose is of (the catalogue's `dose_of`).
static func giver(riders: Dictionary, host: StringName, stat: StringName) -> StringName:
	var all := Catalogue.sockets(host)
	for socket in all.size():
		if ((all[socket] as Dictionary).get("gives", {}) as Dictionary).has(stat):
			var rider := rider_at(riders, host, socket)
			return rider if rider != &"" and Catalogue.fits(host, socket, rider) else &""
	return &""


## **The first slot that would take [param gene]**, as `[host, socket]`, of the hosts
## [param tiers] carries, in order: an empty one, or one that holds it below
## [constant COPIES_MAX]. `[]` for none. What makes a meal wait for the player
## (genome.gd's `integrate`), and where a water cell's meal with no room on its body
## goes (`integrate_into`).
static func room_for(riders: Dictionary, tiers: Dictionary, gene: StringName) -> Array:
	var rider := Catalogue.rides_as(gene)
	if rider == &"":
		return []
	for host: StringName in Catalogue.keys():
		if int(tiers.get(host, 0)) <= 0:
			continue
		for socket in Catalogue.sockets(host).size():
			if not Catalogue.fits(host, socket, gene):
				continue
			var there := rider_at(riders, host, socket)
			if there == &"" or (there == rider
					and copies_at(riders, host, socket) < COPIES_MAX):
				return [host, socket]
	return []


## **[param gene] put into slot [param socket] of [param host]** in [param riders],
## at [param copies]: written into an empty slot or over another rider, or added to
## the same rider's copies up to [constant COPIES_MAX]. A [enum Put]. A gene of forms
## goes in as the key it rides as.
static func put(riders: Dictionary, host: StringName, socket: int, gene: StringName,
		copies: int) -> int:
	if not Catalogue.fits(host, socket, gene) or copies <= 0:
		return Put.NOTHING
	var rider := Catalogue.rides_as(gene)
	var slots := of(riders, host)
	var there: Array = slots[socket]
	if there[0] == rider:
		if int(there[1]) >= COPIES_MAX:
			return Put.NOTHING
		there[1] = mini(int(there[1]) + copies, COPIES_MAX)
		riders[host] = slots
		return Put.RAISED
	slots[socket] = [rider, mini(copies, COPIES_MAX)]
	riders[host] = slots
	return Put.WROTE


## **What putting [param gene] into slot [param socket] of [param host] would do**,
## without doing it: a [enum Put], NOTHING for a gene that does not fit or a slot
## full of it.
static func putting(riders: Dictionary, host: StringName, socket: int,
		gene: StringName) -> int:
	if not Catalogue.fits(host, socket, gene):
		return Put.NOTHING
	var rider := Catalogue.rides_as(gene)
	if rider_at(riders, host, socket) == rider:
		return Put.RAISED if copies_at(riders, host, socket) < COPIES_MAX else Put.NOTHING
	return Put.WROTE


## **Whether any slot of [param host] takes [param gene]**, full or not: what lights
## its ports with a gene in hand.
static func takes_any(host: StringName, gene: StringName) -> bool:
	for socket in Catalogue.sockets(host).size():
		if Catalogue.fits(host, socket, gene):
			return true
	return false


## **Every rider's copies past the first**, summed: what they add to the upkeep's
## bill, as a gene's do (genome.gd's `upkeep_of`).
static func extra_copies(riders: Dictionary) -> int:
	var extra := 0
	for host: StringName in riders:
		for one: Array in riders[host]:
			extra += maxi(int(one[1]) - 1, 0)
	return extra


## How many riders [param riders] holds.
static func count(riders: Dictionary) -> int:
	var n := 0
	for host: StringName in riders:
		for one: Array in riders[host]:
			if StringName(one[0]) != &"":
				n += 1
	return n


## **[param riders] as a file keeps them**: every name a String.
static func by_name(riders: Dictionary) -> Dictionary:
	var out := {}
	for host: StringName in riders:
		var slots: Array = []
		for one: Array in riders[host]:
			slots.append([String(one[0]), int(one[1])])
		out[String(host)] = slots
	return out


## **Whether [param a] and [param b] hold the same riders**, slot for slot.
static func same(a: Dictionary, b: Dictionary) -> bool:
	return by_name(copy(a)) == by_name(copy(b))


## **A number that changes whenever [param riders] does**: what a cache of a body's
## records keys on beside its genome (food.gd's `_toxins_at`).
static func sign_of(riders: Dictionary) -> int:
	return hash(by_name(riders)) if not riders.is_empty() else 0


## **What is wrong with [param riders] for a body wearing [param tiers]**, `""` for
## nothing: a host it does not wear, more slots than the host declares, a rider that
## does not fit its slot, copies out of 1 to 3. What the host's referee asks of a
## guest's body (referee.gd), and the drop's load of its own file.
static func problem(riders: Dictionary, tiers: Dictionary) -> String:
	for host: StringName in riders:
		if int(tiers.get(host, 0)) <= 0:
			return "a rider on %s, which it does not wear" % host
		var slots: Array = riders[host]
		var count := Catalogue.sockets(host).size()
		if slots.size() > count:
			return "%d slots on %s, which has %d" % [slots.size(), host, count]
		for socket in slots.size():
			var rider := StringName(slots[socket][0])
			var copies := int(slots[socket][1])
			if rider == &"":
				continue
			if not Catalogue.fits(host, socket, rider) or Catalogue.rides_as(rider) != rider:
				return "%s does not fit slot %d of %s" % [rider, socket, host]
			if copies < 1 or copies > COPIES_MAX:
				return "%s at %d copies" % [rider, copies]
	return ""


static func _slots_copy(slots: Array) -> Array:
	var out: Array = []
	for one: Array in slots:
		out.append([StringName(one[0]), int(one[1])])
	return out
