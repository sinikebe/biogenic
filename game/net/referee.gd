extends RefCounted
## **The referee: what a host checks a guest's word against** (docs/design/
## net-hardening.md part B, issue #57).
##
## A guest's run says where its cell is, how big it is, what it wears, when it
## arrives, divides and dies -- and before this, the host took every word of it.
## Contacts were already the host's to decide (shared-pond.md §1.1); this is the
## rest. One referee per guest, kept by `pond.gd` on the host beside that guest's
## record, and made again with every connection.
##
## **It answers, and the host acts.** Every input comes in through a `judge_*`
## or [method claim] and goes back out as what the host should do with it --
## take it, take a clamped copy, or leave it -- plus a foul for each rule broken,
## queued in [member fouls] with its weight. `pond.gd` hands the fouls to the
## session's ledger (`net_session.gd`'s `strike`), which cuts at ten points or,
## while `enforce_referee` is off, only counts and logs what it would have done.
## The verdicts stand either way: a clamp or a refusal is the host deciding
## about its own water, and it never cuts anybody.
##
## **What it can know, it works out; what it cannot, it bounds.** Every meal a
## guest eats in the pond is one the host decided and sent (a CONTACT ATE), so
## the guest's radius is computed, not trusted. The body a cell wears is fixed at
## birth but for one gift, so a change is checked. A division is announced by the
## guest's own state frames seconds ahead, and an arrival is placed by the host.
## Movement stays the guest's to decide -- the host caps it at what physics
## allows and does not simulate it (B.6).
##
## **It holds no scene.** Every call takes the time and the facts it needs, so
## `tools/net_probe.gd` drives it with no socket and no tree, the way it drives
## `food.gd` in `pond-field`.
##
## RefCounted and preloaded, no node and no class_name, like every other file in
## game/net/ -- see the note at the top of signal_bus.gd.

const CellBody := preload("res://game/normal/cell.gd")
const FoodField := preload("res://game/normal/food.gd")

# --- The rules, by the name the log and the tools call them ------------------
const MOVE := "movement"
const TURN := "heading"
const SIZE := "radius"
const OUT := "dividing"
const SHOUT := "shout"
const ENTER := "arrival"
const BODY := "body"
const SISTER := "sister"
const DIED := "death"
const RULES: Array[String] = [MOVE, TURN, SIZE, OUT, SHOUT, ENTER, BODY, SISTER, DIED]

## **What each foul weighs on the ledger** (A.4's table, last row: one to four
## points). The ledger cuts at ten and forgets a point a second.
const WEIGHT_MOVE := 2.0
const WEIGHT_TURN := 2.0
const WEIGHT_SIZE := 4.0
const WEIGHT_OUT := 4.0
## A shout, an arrival, or bodies faster than the budget: one point, because a
## lost or late frame can make one honest input look early.
const WEIGHT_SHOUT := 1.0
const WEIGHT_ENTER := 1.0
const WEIGHT_BODY_RATE := 1.0
const WEIGHT_BODY := 4.0
const WEIGHT_SISTER := 4.0
const WEIGHT_SISTER_OFF := 2.0
const WEIGHT_DIED := 2.0
## **Each rule fouls at most once in this long**, however many frames break it:
## a cheat that lies on every one of twenty state frames a second is struck
## twice a second, not twenty times.
const FOUL_EVERY := 0.5

# --- Movement: the path the guest claims ---------------------------------------
## **1,100 units a second, 1.5 s of it held, and 100 of slack.** Every speed-up
## the game has, at tier 3 and stacked -- impulses as often as their clock
## allows, a held push, a dash every cooldown -- peaks at 943 units a second
## against the drag (cell.gd's tables; the plan's B.2). Held for 1.5 s, a guest at
## that peak can have its frames bunched behind about 1.8 s of delay before the
## bucket runs dry; the slack is a push out of a body, or a shove.
const MOVE_RATE := 1100.0
const MOVE_HOLD := 1650.0
const MOVE_SLACK := 100.0
## **The heading, the same way: 1.35 radians a second, half a turn held.** A
## tier-3 `cirrus` turns at 1.02 and the drift adds 0.13, and an impulse kicks
## the nose by up to 0.16 at most once every 1.2 s: 1.28 a second, at the very
## worst. **Half a turn is the most any one frame can claim** -- a heading is
## read as the shorter way round from the last -- so with the bank full, no
## frame fouls however long the ones before it were held: a guest turning hard
## through an uplink that stalled. Held at 1.5, the first build fouled a tier-3
## cirrus at full steer after 1.5 s of one (27 of 40 seeds, found in review).
## The heading the host applies follows through `_swing`, on the same numbers,
## so an honest turn is applied as it is claimed: 1.35 a second, and from a full
## bank up to half a turn at once. The slack is two steps of the wire's one-byte
## heading, so rounding never fouls.
const TURN_RATE := 1.35
const TURN_HOLD := PI
const TURN_SLACK := 0.05
## **The motion the host carries a person on is clamped, never fouled**: the
## field coasts a person by its velocity between frames (food.gd's
## `_carry_person`), so a velocity past any body's is a teleport by instalments.
const SPEED_MAX := 1100.0
const TURNING_MAX := 1.5

# --- The body: its size, and dividing ------------------------------------------
## A claimed radius may be this far over what the host has fed it, for the
## float32 on the wire.
const RADIUS_SLACK := 0.05
## **A daughter's radius**, `CellBody.daughter_radius(DIVIDE_RADIUS)` -- 40 over
## the square root of two -- written out because a const cannot call a function.
## `tools/net_probe.gd` holds the two to each other.
const DAUGHTER_RADIUS := 28.284271247461902
## While out of the water, dividing, a body is where it was: frozen to this.
const OUT_STILL := 2.0
## **How long a daughter's first frame may wait for her SISTER.** Her state
## frame is unreliable and her SISTER reliable, on channels that do not wait for
## each other, so the frame can land first; a resend of the SISTER is well
## inside this.
const BIRTH_WAIT := 5.0
## **Where a declined daughter goes: 560 units from her mother**, ±20.
## `normal_mode.gd`'s SISTER_DISTANCE, written out because pond.gd cannot preload
## the run (pond.gd:46-47 of the plan's base); the probe holds the two together.
const SISTER_DISTANCE := 560.0
const SISTER_RING := 20.0

# --- Shouts --------------------------------------------------------------------
## **Where a shout may come from: within 650 units of where the guest swam in
## the last few seconds** -- 100 and half a second at 1,100 a second, the
## plan's number -- measured against every state frame of the last
## [constant SHOUT_PAST], not only the newest: a shout is reliable and a state
## frame is not, so a shout resent after a loss lands behind frames that were
## sent after it.
const SHOUT_REACH := 650.0
const SHOUT_PAST := 4.0
## **Two banked, and one each ping period less a second** -- the fastest the
## worn organ calls. One more after a new body, an arrival or an organ gained,
## because each zeroes the organ's clock and it calls at once (food.gd's
## `_fresh_senses` and `_step_pings`).
const SHOUT_BANK := 2.0
const SHOUT_EARLY := 1.0

# --- Arrivals and bodies -------------------------------------------------------
## **Four arrivals at once, then one every 2 s.** Every arrival makes the host
## send an ARRIVE, a PERSON and up to 68 GENOMEs, and this is what bounds a
## guest that keeps asking (A.9). The plan's two and one in 3 s were too tight
## for an honest one, measured: a loud death shuts in 0.9 s, a tap during the
## collapse is honoured then, and a returning cell is in the water -- and
## edible -- from that tap, so a guest eaten as it comes back asks again every
## two or three seconds. The probe's pond section sends four in five.
const ENTER_BANK := 4.0
const ENTER_EVERY := 2.0
## A new cell is r26 and nothing is bigger than r40; this much either side is
## the float32 the wire carries it in.
const RADIUS_EPSILON := 0.01
## **Two PERSONs a second, six banked**: one with each arrival, one for the
## stale body old builds describe after a death (below), one for the gift, and
## one each time a meal widens the layout.
const PERSON_RATE := 2.0
const PERSON_BANK := 6.0
## **The four senses the free gift is drawn from**, normal_mode.gd's
## FIRST_SENSES, written out for the reason SISTER_DISTANCE is. The one change a
## worn body ever makes: one of these, at tier 1, once.
const FIRST_SENSES: Array[StringName] = [&"ocellus", &"ampulla", &"chemocyte", &"stigma"]
## **After a death, a guest describes its dead body once more** -- every
## protocol-4 build does it, +104 to +108: `pond.gd`'s `_watch_worn` compares
## the dead cell's genome with the born one it has just announced and sends the
## difference, between its ENTER and its ARRIVE. That is a stale body, not a
## change: until the guest says its born body again -- or this long after its
## first frame, if it never had a stale one to describe -- a PERSON that is not
## the arrival's is ignored and never fouled.
const STALE_FOR := 10.0

# --- The re-entry wound rule (owner's decision, 2026-09-25) --------------------
## **A body that leaves the pond and comes back inside 30 s is the same body,
## continued**: it keeps its wound -- as it would have mended in the water -- and
## gets no new grace, only what was left of the old less the time away. So
## neither a wound nor the 42 s of grace can be refreshed by leaving and coming
## back. Fresh, as before, for a connection's first arrival, a return after a
## death, and a re-entry after longer than this. False gives every arrival a
## fresh wound and grace, which is how it was before B.
const REENTRY_KEEPS_WOUND := true
const REENTRY_WITHIN := 30.0

# --- A host stall ---------------------------------------------------------------
## **A host stall is not a teleport.** A host that stops -- a phone in a pocket,
## software GL at a long frame -- takes the whole stall's frames at once, so
## every budget is handed the gap's full refill, past its hold, up to ten
## seconds of it: A.4's rule and numbers.
const STALL_CREDIT := 10.0


## **A budget on wall time**: [member tokens] refill at [member rate] a second
## up to [member hold], and may go [member slack] below nothing. A take that
## finds too little takes what there is and says how much that was.
class Budget extends RefCounted:
	var rate := 0.0
	var hold := 0.0
	var slack := 0.0
	var tokens := 0.0
	var at := 0.0
	## **The closest call**: the most any one charge used of what it had to spend,
	## 1.0 being all of it. Past 1.0 is a foul. For tools, which print it.
	var closest := 0.0
	## What the last take found to spend, slack included: what a foul says.
	var had := 0.0

	func _init(per_second: float, most: float, give: float, now: float) -> void:
		rate = per_second
		hold = most
		slack = give
		tokens = most
		at = now

	## Refilled to [param now]. An overfull budget -- a stall's credit -- is
	## spent down, not trimmed back.
	func refill(now: float) -> void:
		if tokens < hold:
			tokens = minf(hold, tokens + rate * maxf(now - at, 0.0))
		at = now

	## Spends up to [param cost] and returns what it could: less than the cost is
	## an overrun, and leaves the budget at the bottom of its slack.
	func take(cost: float, now: float) -> float:
		refill(now)
		var have := maxf(tokens + slack, 0.0)
		had = have
		if cost > 0.0:
			closest = maxf(closest, cost / maxf(have, 1e-6))
		var given := minf(maxf(cost, 0.0), have)
		tokens -= given
		return given

	## **Anchored**: nothing banked, refilling from [param now] -- an arrival.
	func empty(now: float) -> void:
		tokens = 0.0
		at = now

	func top_up(seconds: float) -> void:
		tokens = maxf(tokens, rate * seconds)


## Set from [constant REENTRY_KEEPS_WOUND]; a seam so the probe can hold both
## settings to their rule, and nothing else ever sets it.
var reentry_keeps_wound := REENTRY_KEEPS_WOUND

# --- For the host, and for tools -------------------------------------------------
## **The fouls not yet handed to the ledger**, as `[rule, weight, why]`, oldest
## first. [method take_fouls] empties it.
var fouls: Array = []
## Rule -> every violation seen, and rule -> the fouls charged for them (at most
## one each [constant FOUL_EVERY]).
var called: Dictionary = {}
var struck: Dictionary = {}
## Inputs judged, by kind.
var judged: Dictionary = {"state": 0, "shout": 0, "enter": 0, "person": 0,
	"sister": 0, "died": 0}
## The fastest claimed speed and turn, and the most a claimed radius ever stood
## over what the host expected, for tools: how near an honest guest came.
var worst_speed := 0.0
var worst_turning := 0.0
var worst_radius := -INF

var move: Budget = null
var turn: Budget = null
var shouts: Budget = null
var enters: Budget = null
var bodies: Budget = null
## Where the host puts the person, and which way it faces: toward the claim,
## no faster than the same numbers allow.
var _follow: Budget = null
var _swing: Budget = null
var _last_struck: Dictionary = {}

# --- The connection ---------------------------------------------------------------
var _arrivals := 0
## A death since the last arrival: the next arrival is fresh...
var _dead := false
## ...and the first arrival asked for after it must be a born cell's, r26.
var _born_next := false
## The last body to leave without dying: when, its wound and grace then, and
## whether it had ever arrived.
var _left_at := -INF
var _left_wound := 0.0
var _left_grace := 0.0
var _left_arrived := true
## The last arrival's grant: `[fresh, wound, grace, measured from]`.
var _grant: Array = []

# --- The body in the water --------------------------------------------------------
## **Arrived**: the host has taken a state frame with a body in it since the
## ENTER that put this body here. Until then the body waits at the arrival.
var arrived := false
## **What the host has fed this body to**: the ENTER's radius, then 4 for every
## ATE sent, up to 40, and a daughter's after a birth. A claim over it fouls.
var expected := 0.0
## An arrival that was not a return from a death: its first frame's radius is
## taken, up to 40 -- a guest swimming alone eats in the round trip of its own
## swap, and an arrival's body is one the host never saw grow anyway (B.6).
var _reanchor := false
var _anchors: Array = []
var _claim_at := Vector2.ZERO
var _claim_heading := 0.0
var _applied_at := Vector2.ZERO
var _applied_heading := 0.0
var _meals := 0
var _meals_at_out := 0
## The tiers the host applied, and the ones the arrival said.
var worn: Dictionary = {}
var _arrival_worn: Dictionary = {}
var _gift_used := false
var _stale_until := -INF
## A SISTER was taken: one PERSON with a new body may follow.
var _birth_open := false
var _out := false
var _frozen := Vector2.ZERO
var _division_open := false
var _sister_taken := false
var _born_by := -INF
## **Where the mother stopped is not known yet**: a division the host heard of
## only from its SISTER (see [method judge_sister]). Her first OUT frame to land
## after it says where.
var _frozen_unknown := false
## **A division still owed its sister after its body went** -- eaten, starved
## or gone from the water with the division open -- until this time, and where
## the mother stopped. A SISTER is reliable and a daughter's state frame is not:
## one SISTER lost on the way lands a resend later, and the daughter it left
## can be eaten in the water in between.
var _sister_owed_by := -INF
var _owed_from := Vector2.ZERO
## `[when, where]` for every state frame of the last [constant SHOUT_PAST].
var _history: Array = []
## The reach of the body before this one, for a shout that was sent before a
## new body and lands after it.
var _reach_before := 0.0


func _init(now: float) -> void:
	move = Budget.new(MOVE_RATE, MOVE_HOLD, MOVE_SLACK, now)
	turn = Budget.new(TURN_RATE, TURN_HOLD, TURN_SLACK, now)
	_follow = Budget.new(MOVE_RATE, MOVE_HOLD, MOVE_SLACK, now)
	_swing = Budget.new(TURN_RATE, TURN_HOLD, TURN_SLACK, now)
	shouts = Budget.new(_shout_rate(0), SHOUT_BANK, 0.0, now)
	enters = Budget.new(1.0 / ENTER_EVERY, ENTER_BANK, 0.0, now)
	bodies = Budget.new(PERSON_RATE, PERSON_BANK, 0.0, now)
	_grant = [true, 0.0, FoodField.FIRST_DELAY, now]


## Every foul since the last call, oldest first; empties the queue.
func take_fouls() -> Array:
	if fouls.is_empty():
		return []
	var out := fouls
	fouls = []
	return out


## Fouls charged so far, every rule together.
func fouled() -> int:
	var total := 0
	for rule: String in struck:
		total += int(struck[rule])
	return total


## **The host stalled for [param seconds]**: what arrives now is the stall's
## backlog, and every budget is handed the gap's refill.
func stalled(seconds: float) -> void:
	var credit := minf(seconds, STALL_CREDIT)
	for budget: Budget in [move, turn, _follow, _swing, shouts, enters, bodies]:
		budget.top_up(credit)


# ---------------------------------------------------------------------------
# What the host did, told to the referee.
# ---------------------------------------------------------------------------

## **The host sent this guest an ATE**: its body will be four units bigger, up
## to forty. The host raises what it expects when it *sends* the meal, so the
## guest's own radius can only lag behind it.
func ate() -> void:
	_meals += 1
	expected = minf(expected + CellBody.GROWTH_PER_MEAL, CellBody.DIVIDE_RADIUS)


## **Tools only**: [param meals] ATEs the probe skipped by setting a radius by
## hand. It records what was skipped; it switches no check off.
func credit_meals(meals: int) -> void:
	for i in maxi(meals, 0):
		ate()


## **The guest's body died** -- the host's field took it, or it starved and
## said so. Its next arrival is fresh, and must be a born cell's.
func died(now: float) -> void:
	_dead = true
	_born_next = true
	_owe_sister(now)
	_end_body()


## **The body left the water without dying**: its POND bit went, or an arrival
## that never happened was asked for again. [param wound] and [param grace] are
## the host's own at that moment, for the re-entry rule.
func left(now: float, wound: float, grace: float) -> void:
	_left_at = now
	_left_wound = wound
	_left_grace = grace
	_left_arrived = arrived
	_owe_sister(now)
	_end_body()


# ---------------------------------------------------------------------------
# The guest's word.
# ---------------------------------------------------------------------------

## **An ENTER**: true to answer it with an arrival. [param present] is whether
## the host has a body for this guest now. Legal when it has none, or has one
## that has not arrived yet -- the retry after an unanswered ENTER.
func judge_enter(now: float, radius: float, present: bool) -> bool:
	judged["enter"] = int(judged["enter"]) + 1
	var born := _born_next
	_born_next = false
	if present and arrived:
		_foul(ENTER, WEIGHT_ENTER, "arrival: asked to arrive while it is swimming here",
			now)
		return false
	if radius < CellBody.BASE_RADIUS - RADIUS_EPSILON \
			or radius > CellBody.DIVIDE_RADIUS + RADIUS_EPSILON:
		_foul(ENTER, WEIGHT_ENTER, "arrival: at r%.2f, where a body is r%.0f to r%.0f"
			% [radius, CellBody.BASE_RADIUS, CellBody.DIVIDE_RADIUS], now)
		return false
	if born and absf(radius - CellBody.BASE_RADIUS) > RADIUS_EPSILON:
		_foul(ENTER, WEIGHT_ENTER, "arrival: back from a death at r%.2f, where a new"
			% radius + " cell is r%.0f" % CellBody.BASE_RADIUS, now)
		return false
	if enters.take(1.0, now) < 1.0:
		_foul(ENTER, WEIGHT_ENTER, "arrival: more than %d at once, then one every %d s"
			% [roundi(ENTER_BANK), roundi(ENTER_EVERY)], now)
		return false
	return true


## **The host has put this guest's new body at [param at]** (after its
## `place_person`), for an ENTER of [param radius]. Returns `[]` for a fresh
## body -- no wound, a new cell's grace -- or `[wound, grace]` for the host to
## give it instead: a re-entry, under [member reentry_keeps_wound].
func arrive(now: float, at: Vector2, radius: float) -> Array:
	var after_death := _dead
	var grant: Array
	if not reentry_keeps_wound or _arrivals == 0 or _dead:
		grant = [true, 0.0, FoodField.FIRST_DELAY, now]
	elif not _left_arrived:
		# The last arrival never happened -- no frame ever put it in the water --
		# so this is that one, asked for again, and gets what it would have.
		grant = _grant
	elif now - _left_at > REENTRY_WITHIN:
		grant = [true, 0.0, FoodField.FIRST_DELAY, now]
	else:
		grant = [false, _left_wound, _left_grace, _left_at]
	var keep_old := not _left_arrived and not _anchors.is_empty() and not after_death
	var old: Array = _anchors.duplicate() if keep_old else []
	_grant = grant
	_arrivals += 1
	_dead = false
	_born_next = false
	_end_body()
	# **Anchored at the arrival**: the first frame must lie within the slack and
	# 1,100 a second since, of where the host put it -- or of the arrival before,
	# if that one never happened: its ARRIVE may still be the one that lands.
	_anchors = [at]
	if not old.is_empty():
		# The one before, and no further: a chain of arrivals that never happened
		# keeps only the newest two, whichever ARRIVE lands.
		_anchors.append(old[0])
	# A SISTER owed to a body before this one would have landed ahead of this
	# ENTER: every event a guest sends travels on one reliable, ordered channel.
	_sister_owed_by = -INF
	_claim_at = at
	_claim_heading = 0.0
	_applied_at = at
	_applied_heading = 0.0
	for budget: Budget in [move, turn, _follow, _swing]:
		budget.empty(now)
	expected = radius
	_reanchor = not after_death
	_meals = 0
	_meals_at_out = 0
	_history.clear()
	# A return from a death is where the stale body is said (see STALE_FOR).
	_stale_until = INF if after_death else -INF
	_shout_bonus()
	if bool(grant[0]):
		return []
	var away := maxf(now - float(grant[3]), 0.0)
	return [CellBody.mended(float(grant[1]), away), maxf(float(grant[2]) - away, 0.0)]


## **A PERSON**: `[]` to leave it unread, or `[new_body]` to apply it -- a new
## body sent out of turn comes back false. [param present] is whether the host
## has a body for this guest now.
##
## A new body is legal with no body in the water -- the PERSON that comes just
## before an ENTER -- or with one that has not arrived, or once after a SISTER,
## which is a birth. Otherwise the worn tiers must be the ones the host already
## has, but for the gift: one of [constant FIRST_SENSES] at tier 1, once a body.
## Whatever the tiers, every slot must name a gene it wears, once.
func judge_person(now: float, new_body: bool, tiers: Dictionary, order: Array,
		present: bool) -> Array:
	judged["person"] = int(judged["person"]) + 1
	if bodies.take(1.0, now) < 1.0:
		_foul(BODY, WEIGHT_BODY_RATE, "body: more than %d said at once, then %d a second"
			% [roundi(PERSON_BANK), roundi(PERSON_RATE)], now)
		return []
	if not _order_fits(tiers, order):
		_foul(BODY, WEIGHT_BODY, "body: its slots name a gene it does not wear, or one"
			+ " twice", now)
		return []
	var fouled := false
	if new_body:
		if not present or not arrived or _birth_open:
			_birth_open = false
			_reach_before = _reach()
			worn = tiers.duplicate()
			_arrival_worn = worn.duplicate()
			_gift_used = false
			_new_shout_rate(now)
			_shout_bonus()
			return [true]
		_foul(BODY, WEIGHT_BODY, "body: a new one out of turn -- taken as the one it"
			+ " has", now)
		fouled = true
	if tiers == worn:
		if _stale(now) and tiers == _arrival_worn:
			_stale_until = -INF
		return [false]
	if _stale(now) and tiers == _arrival_worn:
		# **The born body, said again after the stale one**: it is the body. Any
		# gift the stale one looked like was not one.
		worn = _arrival_worn.duplicate()
		_gift_used = false
		_stale_until = -INF
		_new_shout_rate(now)
		return [false]
	if not _gift_used and _is_gift(worn, tiers):
		var had := _reach()
		worn = tiers.duplicate()
		_gift_used = true
		_new_shout_rate(now)
		if had <= 0.0 and _reach() > 0.0:
			_shout_bonus()
		return [false]
	if _stale(now):
		return []
	if not fouled:
		_foul(BODY, WEIGHT_BODY, "body: %s where it wore %s -- kept the old one"
			% [_tiers_say(tiers), _tiers_say(worn)], now)
	return []


## **A SISTER**: `[]` to place nothing, or `[at, radius]` to place her with --
## put on the ring round her mother and made a daughter's size if she was not.
## [param present] is whether the host has a body for this guest now.
##
## Legal once for each division, and a division is known three ways:
## - **Seen**: an OUT frame at r40 began it.
## - **Unseen**: its OUT frames and its SISTER all landed in one host frame -- a
##   host frozen through the whole of the guest's out window, a phone switched
##   away and back -- and a host takes events before it carries state frames,
##   so the SISTER is heard first. Taken when the body is here, has arrived and
##   has been fed to r40, which is everything one OUT frame would have proved.
## - **Owed**: seen, and its body went before the SISTER landed (see
##   [member _sister_owed_by]).
func judge_sister(now: float, at: Vector2, radius: float, present: bool) -> Array:
	judged["sister"] = int(judged["sister"]) + 1
	if not _division_open and now <= _sister_owed_by:
		# **Owed, and late.** She is still her mother's daughter, so she goes in
		# the water where her mother left her -- but no birth opens, because the
		# body she was born beside has gone. Its next body is an arrival's.
		_sister_owed_by = -INF
		return _sister_placed(now, at, radius, _owed_from, true)
	var mother_seen := true
	if not _division_open:
		if not (present and arrived
				and expected >= CellBody.DIVIDE_RADIUS - RADIUS_SLACK):
			_foul(SISTER, WEIGHT_SISTER, "sister: with no division begun", now)
			return []
		# **Unseen.** Where the mother stopped was never seen, so the ring is not
		# checked: the place is hers to say, as it is for any body she could have
		# swum to and divided at. Her OUT frames still to land are this
		# division's own tail, and the first of them says where she stopped.
		mother_seen = false
		_out = true
		_frozen_unknown = true
		_meals_at_out = _meals
	_division_open = false
	_sister_taken = true
	_birth_open = true
	_born_by = -INF
	# The daughter, and whatever the host fed her if her first frames beat the
	# SISTER here: every meal sent since her mother was last seen out.
	expected = minf(DAUGHTER_RADIUS + CellBody.GROWTH_PER_MEAL
		* float(_meals - _meals_at_out), CellBody.DIVIDE_RADIUS)
	return _sister_placed(now, at, radius, _frozen, mother_seen)


## **Where a sister goes, and at what size**: a daughter's radius, and on the
## ring of [constant SISTER_DISTANCE] round [param mother] when where her mother
## stopped is known ([param ring]) -- put there, with a foul, when she was not.
func _sister_placed(now: float, at: Vector2, radius: float, mother: Vector2,
		ring: bool) -> Array:
	var place := at
	var size := radius
	var off := false
	if absf(radius - DAUGHTER_RADIUS) > RADIUS_SLACK:
		size = DAUGHTER_RADIUS
		off = true
	var apart := at.distance_to(mother)
	if ring and absf(apart - SISTER_DISTANCE) > SISTER_RING:
		var away := (at - mother) / apart if apart > 0.001 else Vector2.RIGHT
		place = mother + away * SISTER_DISTANCE
		off = true
	if off and ring:
		_foul(SISTER, WEIGHT_SISTER_OFF, "sister: r%.2f, %.0f units from her mother --"
			% [radius, apart] + " put at r%.2f on the ring of %.0f" % [DAUGHTER_RADIUS,
				SISTER_DISTANCE], now)
	elif off:
		_foul(SISTER, WEIGHT_SISTER_OFF, "sister: r%.2f -- made r%.2f" % [radius,
			DAUGHTER_RADIUS], now)
	return [place, size]


## **A DIED**: `[]` when there is no body to take out -- a death the host made
## itself, said again -- or `[cause, by]` to report it with. Dying is the
## guest's right, so the body always goes; but only starving is the guest's own
## death to say (cause STARVED, by nobody), and any other is reported as that.
func judge_died(now: float, cause: int, by: int, present: bool) -> Array:
	judged["died"] = int(judged["died"]) + 1
	if not present:
		return []
	died(now)
	if cause == FoodField.Cause.STARVED and by == 0:
		return [cause, by]
	_foul(DIED, WEIGHT_DIED, "death: said it died of cause %d by %d, where only"
		% [cause, by] + " starving is its own to say", now)
	return [FoodField.Cause.STARVED, 0]


## **A shout**: true to let it be heard. [param in_water] is whether the host
## has this guest's body in the water; with none there, only the rate is its
## to judge -- the guest may be swimming alone, in water of its own.
func judge_shout(now: float, at: Vector2, radius: float, reach: float,
		in_water: bool) -> bool:
	judged["shout"] = int(judged["shout"]) + 1
	# **A call that reaches nothing is not a call**, and no receiver plays one
	# (`normal_mode.gd`'s `_hear_others`). Every protocol-4 build sends one when
	# it comes back from the black having worn an organ: its water keeps the dead
	# cell's ping period and range through the return -- the run refreshes them
	# only once its cell is alive again -- and pulses at once, calling with the
	# new born body's reach, which is none. Dropped, uncharged and never fouled.
	if not (reach > 0.0) or not (radius > 0.0):
		return false
	if shouts.take(1.0, now) < 1.0:
		_foul(SHOUT, WEIGHT_SHOUT, "shout: more often than what it wears calls", now)
		return false
	if not in_water:
		return true
	var near := at.distance_to(_claim_at)
	for past: Array in _history:
		if now - float(past[0]) <= SHOUT_PAST:
			near = minf(near, at.distance_to(past[1]))
	if near > SHOUT_REACH:
		_foul(SHOUT, WEIGHT_SHOUT, "shout: from %.0f units off anywhere it swam" % near,
			now)
		return false
	if radius > expected + RADIUS_SLACK:
		_foul(SHOUT, WEIGHT_SHOUT, "shout: at r%.2f, where the host has fed it to r%.2f"
			% [radius, expected], now)
		return false
	var reach_now := _reach()
	if not (reach_now > 0.0 and is_equal_approx(reach, reach_now)) \
			and not (_reach_before > 0.0 and is_equal_approx(reach, _reach_before)):
		_foul(SHOUT, WEIGHT_SHOUT, "shout: reaching %.0f, where what it wears reaches %.0f"
			% [reach, reach_now], now)
		return false
	return true


## **One state frame's body, judged**: `[at, heading, radius, velocity, turning,
## in_water]` for the host to apply. [param out] is the frame's OUT bit.
##
## - **Where**: the path the guest claims is charged to [member move]; a claim
##   past it fouls, and the next frame is measured from the claim, so one late
##   frame cannot foul twice. The host's place follows the claim no faster than
##   the same numbers allow, so a teleport is a walk at the cap.
## - **Which way**: the same, on [member turn].
## - **How big**: never over [member expected], and never under a new cell.
## - **Out of the water**: only at r40, and then where it was.
func claim(now: float, at: Vector2, heading: float, radius: float,
		velocity: Vector2, turning: float, out: bool) -> Array:
	judged["state"] = int(judged["state"]) + 1
	var first := not arrived
	if first:
		arrived = true
		if _stale_until == INF:
			_stale_until = now + STALE_FOR
	_await_birth(now)
	# How big. A division's own OUT frames are its mother's, r40, even landing
	# after her daughter's SISTER has set what the host expects next.
	if _reanchor:
		_reanchor = false
		expected = maxf(expected, minf(radius, CellBody.DIVIDE_RADIUS))
	var bound := maxf(expected, CellBody.DIVIDE_RADIUS) if (out and _out) else expected
	worst_radius = maxf(worst_radius, radius - bound)
	var size := radius
	if radius > bound + RADIUS_SLACK:
		_foul(SIZE, WEIGHT_SIZE, "radius: r%.2f, where the host has fed it to r%.2f"
			% [radius, bound], now)
		size = bound
	size = maxf(size, CellBody.BASE_RADIUS)
	# Out of the water. **Judged as a division begins**: once one is under way,
	# every OUT frame is its own tail -- the daughter's SISTER is reliable and
	# her mother's last OUT frames are not, so a SISTER can land first.
	var wet := true
	var began_out := false
	if out and _out:
		wet = false
		if _frozen_unknown:
			# The first OUT frame of a division heard of only from its SISTER:
			# where the mother stopped, and so where she stays.
			_frozen_unknown = false
			_frozen = at
		if not _sister_taken:
			_meals_at_out = _meals
	elif out:
		if expected < CellBody.DIVIDE_RADIUS - RADIUS_SLACK:
			_foul(OUT, WEIGHT_OUT, "dividing: out of the water at r%.2f, where only r%.0f"
				% [expected, CellBody.DIVIDE_RADIUS] + " divides -- kept in it", now)
		else:
			wet = false
			_out = true
			began_out = true
			_division_open = true
			_sister_taken = false
			_meals_at_out = _meals
	elif _out:
		_out = false
		_frozen_unknown = false
		if not _sister_taken:
			if radius < CellBody.DIVIDE_RADIUS - 1.0:
				_born_by = now + BIRTH_WAIT
			else:
				_division_open = false
				_foul(OUT, WEIGHT_OUT, "dividing: back in the water at r%.2f, undivided"
					% radius, now)
	# Where: the path it claims.
	var from := _claim_at
	if first:
		from = _nearest_anchor(at)
		_applied_at = from
	var went := at.distance_to(from)
	if move.take(went, now) < went - 1e-3:
		_foul(MOVE, WEIGHT_MOVE, "movement: %.0f units at once, where the budget held"
			% went + " %.0f (%.0f a second, %.0f banked, %.0f slack)" % [move.had,
				MOVE_RATE, MOVE_HOLD, MOVE_SLACK], now)
	_claim_at = at
	var towards := _frozen if (_out and not began_out) else at
	if _out and not began_out and at.distance_to(_frozen) > OUT_STILL:
		_foul(OUT, WEIGHT_OUT, "dividing: moved %.1f units while out of the water"
			% at.distance_to(_frozen), now)
	_applied_at = _applied_at.move_toward(towards,
		_follow.take(_applied_at.distance_to(towards), now))
	if began_out:
		_frozen = _applied_at
	# Which way.
	var swung := absf(angle_difference(_claim_heading, heading))
	if turn.take(swung, now) < swung - 1e-4:
		_foul(TURN, WEIGHT_TURN, "heading: turned %.2f rad at once, where the budget held"
			% swung + " %.2f (%.2f a second, %.1f banked)" % [turn.had, TURN_RATE,
				TURN_HOLD], now)
	_claim_heading = heading
	var face := absf(angle_difference(_applied_heading, heading))
	_applied_heading = rotate_toward(_applied_heading, heading, _swing.take(face, now))
	# How it moves.
	worst_speed = maxf(worst_speed, velocity.length() if velocity.is_finite() else INF)
	worst_turning = maxf(worst_turning, absf(turning))
	var motion := velocity.limit_length(SPEED_MAX) if velocity.is_finite() \
		else Vector2.ZERO
	var spin := clampf(turning, -TURNING_MAX, TURNING_MAX) if is_finite(turning) else 0.0
	if not wet:
		motion = Vector2.ZERO
		spin = 0.0
	_history.append([now, at])
	while _history.size() > 1 and (now - float(_history[0][0]) > SHOUT_PAST
			or _history.size() > 160):
		_history.pop_front()
	return [_applied_at, _applied_heading, size, motion, spin, wet]


# ---------------------------------------------------------------------------
# Inside.
# ---------------------------------------------------------------------------

## A rule broken: counted every time, and a foul for the ledger at most once
## each [constant FOUL_EVERY].
func _foul(rule: String, weight: float, why: String, now: float) -> void:
	called[rule] = int(called.get(rule, 0)) + 1
	if now - float(_last_struck.get(rule, -INF)) < FOUL_EVERY:
		return
	_last_struck[rule] = now
	struck[rule] = int(struck.get(rule, 0)) + 1
	fouls.append([rule, weight, why])


## Whatever was true of one body is not true of the next.
func _end_body() -> void:
	arrived = false
	_out = false
	_frozen_unknown = false
	_division_open = false
	_sister_taken = false
	_born_by = -INF
	_birth_open = false
	_reanchor = false


## **A body going with a division open still owes it a sister**, for
## [constant BIRTH_WAIT]: see [member _sister_owed_by].
func _owe_sister(now: float) -> void:
	if _division_open:
		_sister_owed_by = now + BIRTH_WAIT
		_owed_from = _frozen


## **A daughter's frame came with no SISTER**, and the SISTER never followed.
func _await_birth(now: float) -> void:
	if _born_by == -INF or now <= _born_by:
		return
	_born_by = -INF
	if _division_open:
		_division_open = false
		_foul(OUT, WEIGHT_OUT, "dividing: came back a daughter and left no sister", now)


func _nearest_anchor(at: Vector2) -> Vector2:
	var best: Vector2 = _anchors[0] if not _anchors.is_empty() else at
	for anchor: Vector2 in _anchors:
		if at.distance_to(anchor) < at.distance_to(best):
			best = anchor
	return best


## True while an old build may still describe its dead body (STALE_FOR).
func _stale(now: float) -> bool:
	return now < _stale_until


## **The gift**: [param after] is [param before] and one more gene -- one of the
## four senses, at tier 1 -- and nothing else changed.
static func _is_gift(before: Dictionary, after: Dictionary) -> bool:
	if after.size() != before.size() + 1:
		return false
	var added: Variant = null
	for gene: Variant in after:
		if before.has(gene):
			if int(before[gene]) != int(after[gene]):
				return false
		elif added == null:
			added = gene
		else:
			return false
	return added != null and FIRST_SENSES.has(StringName(added)) \
		and int(after[added]) == 1


## Every slot names a gene the body wears, and none twice. A worn gene may have
## no slot: a gift placed over a slot another organ is still worn in.
static func _order_fits(tiers: Dictionary, order: Array) -> bool:
	var seen := {}
	for gene: Variant in order:
		var name := StringName(gene) if gene != null else &""
		if name == &"":
			continue
		if not tiers.has(name) or seen.has(name):
			return false
		seen[name] = true
	return true


## How far what the body wears calls: 0 with no `ampulla`.
func _reach() -> float:
	return CellBody.PING_RANGE_BY_TIER[clampi(int(worn.get(&"ampulla", 0)), 0,
		CellBody.PING_RANGE_BY_TIER.size() - 1)]


## One call each ping period less a second, for the worn organ -- the fastest,
## tier 1's, when there is none to go by.
static func _shout_rate(tier: int) -> float:
	var at := clampi(tier, 1, CellBody.PING_PERIOD_BY_TIER.size() - 1)
	return 1.0 / maxf(CellBody.PING_PERIOD_BY_TIER[at] - SHOUT_EARLY, 1.0)


func _new_shout_rate(now: float) -> void:
	shouts.refill(now)
	shouts.rate = _shout_rate(int(worn.get(&"ampulla", 0)))


## A new body, an arrival or an organ gained zeroes the organ's clock, and it
## calls at once: one more, over the bank.
func _shout_bonus() -> void:
	shouts.tokens = minf(shouts.tokens + 1.0, SHOUT_BANK + 1.0)


static func _tiers_say(tiers: Dictionary) -> String:
	var parts: PackedStringArray = []
	for gene: Variant in tiers:
		parts.append("%s %d" % [str(gene), int(tiers[gene])])
	parts.sort()
	return "{" + ", ".join(parts) + "}"
