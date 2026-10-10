extends RefCounted
## **A floor, and the queue to it**: kinds of something, each kept at a least count of
## its own; which of them are short of it, first come first served; and a budget -- at
## most one in [member gap] of what is made goes to the queue. The drop's gene floor is
## the first user (docs/design/gene-rarity.md §3.3): its kinds are the varieties the
## water keeps, its least counts their classes' floors, and what is made its drifters.
##
## **Nothing here knows what a kind is, or what is made.** A kind is any id, a count is
## whatever the caller counted, and a least count is the caller's to say. Which made
## thing a kind goes on, and which kinds may go on it, is the caller's too: it asks
## [method open] before it makes one, [method take] for the kind, and tells
## [method made] either way. game/normal/drop.gd decides all of that for the drop.
##
## **First come first served.** Each [method count] notes the count at which it first
## found a kind short, and forgets it once the kind is back at its least. The kinds
## short at a count queue by that note -- the one short longest first -- and kinds
## first found short at the same count in the order the caller listed them. So with
## many kinds short at once, none waits behind the same others at every count.
##
## **The budget.** [method open] is true once [member gap] - 1 things or more have
## been made since the queue's last, and it starts true. So at most one in [member gap]
## of what is made is the queue's, whatever is short, and the rest are the caller's.
##
## Named for what it does: a floor's queue. (The design called it `kinds_floor.gd`,
## before phase 6 of gene-catalogue.md gave "kinds" to the shapes an organ is built as,
## `game/genes/kinds.gd`.) No class_name, for the reason signal_bus.gd gives. Preload it
## by path.

## **At most one in this many of what is made is the queue's.**
var gap := 4
## **How many have been made since the queue's last**, up to [member gap] - 1, where
## the queue may take the next. Starts there.
var since := 3
## **Every kind short at the last count, in the order the queue serves them**: the one
## first found short first. Read it; [method count] writes it.
var short: Array = []
## **Those of [member short] not yet given since that count**, in the same order: what
## [method take] takes from. A caller may drop one it will not give this time; it stays
## in [member short], in its place, and is due again at the next count while it is short.
var due: Array = []

## Kind to the number of the count that first found it short, for every kind of
## [member short].
var _found := {}
## How many counts there have been.
var _counted := 0


func _init(every := 4) -> void:
	gap = maxi(every, 1)
	since = gap - 1


## **A count**: [param have] holds how many of each kind there are, [param kinds] is
## every kind kept -- in the order kinds first found short together are served in --
## and [param least] each one's least count; a kind it does not name has none, and is
## never short. A kind with fewer than its least is short. One still short keeps its
## place; one back at its least is forgotten; one found short now queues after every
## kind found before. Every kind short is due again.
func count(have: Dictionary, kinds: Array, least: Dictionary) -> void:
	_counted += 1
	var found := {}
	var rows: Array = []
	for k in kinds.size():
		var kind: Variant = kinds[k]
		if found.has(kind) or int(have.get(kind, 0)) >= int(least.get(kind, 0)):
			continue
		var first := int(_found.get(kind, _counted))
		found[kind] = first
		rows.append([first, k, kind])
	# By the count that first found each, then by its place in [param kinds]: no two
	# rows alike, so the order is the same however the sort goes about it.
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	_found = found
	short = []
	for row: Array in rows:
		short.append(row[2])
	due = short.duplicate()


## **Whether the next thing made may be the queue's**: [member gap] - 1 made or more
## since its last.
func open() -> bool:
	return since >= gap - 1


## **The first kind due that [param accept] takes** -- a Callable of one kind, true
## for one the thing being made may carry -- taken off [member due]; null for none.
## The budget is the caller's to ask first ([method open]) and to tell after
## ([method made]).
func take(accept: Callable) -> Variant:
	for k in due.size():
		if bool(accept.call(due[k])):
			var kind: Variant = due[k]
			due.remove_at(k)
			return kind
	return null


## **One thing made**: the queue's when [param by_queue], which spends the budget, or
## another's, which refills it by one.
func made(by_queue: bool) -> void:
	since = 0 if by_queue else mini(since + 1, gap - 1)


## **The queue as a count left it**, put back: [param found], every kind short at that
## count in the order it serves them -- [member short] as it was -- [param owed], those
## still due, and [param made_since], [member since]. What a kept drop restores, so it
## goes on as one that never stopped: each kind keeps its place against the others, and
## any found short later still queues after them all.
func restore(found: Array, owed: Array, made_since: int) -> void:
	_found = {}
	short = []
	for kind: Variant in found:
		if not _found.has(kind):
			short.append(kind)
			_found[kind] = short.size()
	_counted = short.size()
	due = []
	for kind: Variant in owed:
		if _found.has(kind) and not due.has(kind):
			due.append(kind)
	since = clampi(made_since, 0, gap - 1)
