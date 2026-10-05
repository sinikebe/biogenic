extends Control
## **The programs page** (docs/design/automation-ux.md §1 to §4, §7.1): the pause
## screen's second page, beside the genome. Two views: **the library**, your
## programs in their order with a switch each, and **a program**, its instincts
## as rows -- with the inspector that edits what is selected, the ladder that sets
## a test, and the autopilot's copy beside `resume`. And the autopilot's icon
## itself, drawn here for the water, the page and the replay alike.
##
## **What it knows**: how to show and edit what `library.gd` keeps -- names, lines
## and switches -- through the rulebook's text, and what every rule did on the
## last tick (`own_rules.gd`'s states) or would do now (its dry run). **What it
## does not**: how a list is chosen, merged or read, which is `rulebook.gd`'s and
## `library.gd`'s, or what a sense reports, which is `food.gd`'s. It does no rule
## arithmetic. A part's words are its declaring file's, asked through
## `program_words.gd`, so a new gene brings its own.
##
## **Built once, in code**: a pool of controls for each of the eight rows, placed
## and shown again on every [method refresh], so a press never lands on a control
## a refresh has freed under it. Only the inspector is built again, when what is
## selected changes. Every target is at least 48 canvas px.
##
## No class_name, for the reason signal_bus.gd gives. Preload it by path.

const Library := preload("res://game/normal/library.gd")
const OwnRules := preload("res://game/normal/own_rules.gd")
const Rulebook := preload("res://game/mechanics/rulebook.gd")
const ProgramWords := preload("res://game/normal/program_words.gd")
const FoodField := preload("res://game/normal/food.gd")
const Cilia := preload("res://game/vision/cilia.gd")
## The organs the body's own parts act through, found by what each provides.
const Catalogue := preload("res://game/genes/catalogue.gd")
const ControlsNode := preload("res://game/normal/controls.gd")
const GenomeNode := preload("res://game/normal/genome.gd")

enum View { LIBRARY, PROGRAM }

# --- Geometry (automation-ux.md §2.1, §2.2, §3) ----------------------------------

const EDGE := 48.0
const HEAD_Y := 48.0
const HEAD_H := 56.0
const ROWS_Y := 120.0
const ROW_H := 48.0
const ROW_SEP := 10.0
const ROWS := 8
const LINES_Y := 586.0
## Two margins, the tools column and the gap: what the rows are not.
const TOOLS_W := 296.0
const TOOLS_GAP := 32.0
const ROWS_MAX := 900.0
const INNER := 264.0
const INSPECTOR_H := 420.0
const RESUME_W := 228.0
const AUTOPILOT_W := 56.0
## A program's row: its switch, its `›`, and the four trigger columns ending 8 px
## before the `›`.
const SWITCH_W := 64.0
const OPEN_W := 48.0
const COLUMN_W := 44.0
const COLUMNS_GAP := 8.0
const NAME_X := 76.0
## An instinct's row: chips 6 apart, the glyph's room and the word's padding.
const CHIP_SEP := 6.0
const CHIP_PAD := 12.0
const GLYPH_W := 30.0
const ADD_TEST_W := 48.0
## The arc's ends: 10 past the last chip, 8 short of the action.
const ARC_FROM := 10.0
const ARC_TO := 8.0
## A choice cell, the comparison's and the push's: 128 x 48; the value picker's
## three across.
const CELL_W := 128.0
const VALUE_W := 82.0
## What rides above a finger while it drags (moving-a-gene.md §3.3).
const DRAG_LIFT := 34.0
## **How long a row's state takes to change** (§3.2): a cross-fade, not a cut.
const FADE := 0.12
## **An inspector trigger line's word** (§2.4): where it starts, clear of the
## mark at (12, 16) -- the dash's burst reaches about x 28 -- and the room it is
## trimmed to, the inspector's 264 less that.
const TRIGGER_WORD_X := 34.0
const TRIGGER_LINE_W := 230.0
## How many tests the pool holds a row: one for each value the widest sense
## carries, the beam's and the echo's bearing included.
const TESTS_MOST := 4
## The places' slots (row 39): 10 x 16, 4 apart.
const PLACE := Vector2(10.0, 16.0)
const PLACE_GAP := 4.0
## The pips a part waiting for its organ's copies wears (§4.2): the genome page's.
const PIP_R := 3.4
const PIP_PITCH := 10.0
const PIP_GAP := 7.0
const PIP_ROOM_R := 1.6

# --- Colours (automation-ux.md §2.1) ------------------------------------------------

const FILL := Color(0.063, 0.141, 0.125)
const PALE := Color(0.855, 0.953, 0.933)
const LIT := Color(0.49, 1.0, 0.831)
const TEAL := Color(0.12, 0.70, 0.58)
const MINT := Color(0.588, 1.0, 0.859)
const SELECT := Color(0.588, 1.0, 0.859, 0.85)
const SELECTED := Color(0.086, 0.204, 0.176, 0.85)
const CAPTION := Color(0.855, 0.953, 0.933, 0.45)
const WARN := Color(0.855, 0.953, 0.933, 0.82)
const EXPLAIN := Color(0.855, 0.953, 0.933, 0.62)
const HINT := Color(0.855, 0.953, 0.933, 0.38)
const ACT := Color(0.588, 1.0, 0.859, 0.50)
const ALWAYS_EDGE := Color(0.42, 0.80, 0.72)
## A part that cannot be read, waits for its organ, or sleeps: everything at this.
const ASLEEP := 0.42
const DIMMED := 0.35

## **The glyph** (UX §5.1), about the centre of the 56 px well: an instinct in
## miniature -- a sense, its nerve, and the page's two endings, a chevron while
## your programs have the cell and a T-bar while your hand holds them back.
const AUTOPILOT_SENSE := Rect2(-17.0, -8.0, 11.0, 16.0)
const AUTOPILOT_NERVE := Vector2(-6.0, 15.0)
const AUTOPILOT_LIT := Color(0.49, 1.0, 0.831)
## **The on glyph's ink** (UX §5.1, §9.3). The spec's starting value, 0.85, was
## measured by the glance test (controls.md §3.2's method, three renders diffed to
## 0 pixels) at a σ = 6 px peak of 87 in point of view at 1280x720 and 109 at
## 2400x1080, against the soma figure's 58 and 74: louder than the cell itself,
## which §9.3 forbids. At 0.35 it is 53 and 62, under the figure at both shapes,
## and the lit well and the chevron still tell on from off.
const AUTOPILOT_ON_INK := 0.35

## **The triggers, as the library's columns** (§2.3): the claims the vocabulary
## declares, in this order, each drawn as the pad that works it by hand.
const COLUMNS: Array[StringName] = [&"steering", &"swimming", &"dash", &"push"]
## **Which organ draws a part of the body's own** on its chip, by the stat the
## part acts through: the turns are the organ that turns the body -- the cirrus --
## and a swim the one that swims it -- the flagellum; a gene's parts are its own
## organ's, and the rest the cell's own egg.
const BODY_STATS := {
	&"body.turn-toward": &"turn_rate",
	&"body.turn-away": &"turn_rate",
	&"body.turn-random": &"turn_rate",
	&"body.swim": &"impulse_speed",
}
## **The part that holds the tail still wears the hold's mark** (§3.3): the pad and
## the page use one picture. By the name its organ declares it by, `hold`, so every
## variant of the tail's is marked alike (rulebook.gd's `part_of`).
const HOLD_PART := &"hold"
## **What a gene's part does, as the hints' verb**, by the name its organ declares
## it by: the dash dashes, the push pushes, the hold holds the tail.
const PART_VERBS := {&"dash": &"dash", &"push": &"push", HOLD_PART: &"hold"}

# --- Words (automation-ux.md §8) ------------------------------------------------------

## TRANSLATORS: The words on the chip under the settings gear that turns the pause
## screen's pages, in 17 px type. "programs ›" turns to the player's programs:
## lists of "instincts", rules the player writes for the cell's autopilot.
## "genome ›" turns back to the genome. "‹ programs" goes from one program back to
## the list of them. Keep each arrow on its side. Lowercase. The chip must stay
## clear of a row of four waiting genes beside it.
## ROOM: 120 px at 17 px
const CHIP_SAYS := {
	&"programs": "programs ›",
	&"genome": "genome ›",
	&"back": "‹ programs",
}
## TRANSLATORS: The title of the pause screen's page of programs, at its top left
## in 16 px type: a "program" is a named list of the cell's "instincts", rules
## the player writes that drive the cell on autopilot. Lowercase.
## ROOM: 140 px at 16 px
const TITLE := "programs"
## TRANSLATORS: The line beside the title of the page of programs, in 15 px type.
## "On autopilot": while the player has handed the cell to the programs. "The
## higher program wins": when two programs that are on want the same thing, the
## one higher in the list gets it. Lowercase.
## ROOM: 560 px at 15 px
const LIBRARY_NOTE := "what your cell does on autopilot · the higher program wins"
## TRANSLATORS: The line beside a program's name at the top of its page, in 15 px
## type: of the program's "instincts" (rules: "when a sense reports something ->
## do this"), the first one from the top whose test is met decides. Lowercase.
## ROOM: 560 px at 15 px
const PROGRAM_NOTE := "the first instinct that fits, from the top, wins"
## TRANSLATORS: The same line, for a program switched off. Lowercase.
## ROOM: 560 px at 15 px
const OFF_NOTE := "off: this program does nothing until you turn it on"
## TRANSLATORS: The same line, in a game shared with a friend, where the water
## keeps moving under the pause screen, while the autopilot drives the player's
## cell: the player's programs are steering it as they read. Lowercase.
## ROOM: 560 px at 15 px
const POND_ON_NOTE := "the water is still moving · your programs have your cell"

## TRANSLATORS: What a program's row says when it holds no "instincts" (rules) yet.
## One lowercase word, in 14 px type.
## ROOM: 90 px at 14 px
const EMPTY := "empty"
## TRANSLATORS: After the count on a program's row ("7 instincts · no room"): the
## program is off and cannot be turned on, because the programs that are on share
## eight places for their instincts and too few are free. Lowercase.
## ROOM: 90 px at 14 px
const NO_ROOM := "no room"
## TRANSLATORS: The places the programs that are on share, at the top right of the
## page of programs in 14 px type, before eight small boxes: "6 of 8" places
## taken. The first %d is how many are taken, the second how many there are.
## ROOM: 52 px at 14 px with 8, 8
const PLACES := "%d of %d"

## TRANSLATORS: The two buttons that make a program, in the list of programs, in
## 15 px type. "new program": an empty one. "copy a water cell's program": a copy
## of the program the cells living in the water are born with. Lowercase.
## ROOM: 308 px at 15 px
const ADD_SAYS := {
	&"new": "new program",
	&"copy": "copy a water cell's program",
}
## TRANSLATORS: The row that adds an "instinct" (a rule) to a program, in 15 px
## type, after a plus sign. Lowercase.
## ROOM: 400 px at 15 px
const ADD_INSTINCT := "add an instinct"
## TRANSLATORS: Said in the empty place under a program's last "instinct" (rule)
## when the programs that are on already use all the places they share: %d is how
## many there are (8). Lowercase, in 14 px type.
## ROOM: 830 px at 14 px with 8
const PLACES_FULL := "the %d places are full: switch a program off, or remove an instinct"

## TRANSLATORS: The words of the inspector, the panel at the right of the page of
## programs, with a program selected: "on · 7 instincts" or "off · 2 instincts"
## under its name, in 14 px type; %s is the count. "On": the autopilot runs this
## program; "off": it skips it. Lowercase.
## ROOM: 264 px at 14 px with 99 instincts
const STATE_SAYS := {
	&"on": "on · %s",
	&"off": "off · %s",
}
## TRANSLATORS: The inspector's buttons for a program, in 15 px type: "open ›"
## shows its instincts (a button 264 px wide); "rename" and "copy" (128 px wide
## each); "delete this program" (264 px wide). Lowercase.
## ROOM: 100 px at 15 px
const BUTTON_SAYS := {
	&"open": "open ›",
	&"rename": "rename",
	&"copy": "copy",
}
## TRANSLATORS: The inspector's button that deletes the selected program, after
## asking, in 15 px type on a button 264 px wide. Lowercase.
## ROOM: 230 px at 15 px
const DELETE := "delete this program"
## TRANSLATORS: The four things a program can move, each the name of a column of
## the list of programs and of a line of the inspector, in 14 px type: "steering"
## (turning), "tail" (the tail beating or held still), "dash" (a burst forward),
## "push" (thrust held on). Nouns, lowercase, one short word each.
## ROOM: 90 px at 14 px
## CONTEXT: trigger
const TRIGGER_SAYS := {
	&"steering": "steering",
	&"swimming": "tail",
	&"dash": "dash",
	&"push": "push",
}
## TRANSLATORS: Where a program stands on one of the four things it moves, after
## that thing's name in the inspector ("steering · first"), in 14 px type.
## "first": no program above it moves that. "after %s": the program named
## (in quotation marks) is above it and moves that too, so it wins. "never": a
## program above it always moves that, so this one never can. "asleep": the cell
## does not wear the organ this program needs for it. Lowercase.
## ROOM: 140 px at 14 px
const ORDER_SAYS := {
	&"first": "first",
	&"never": "never",
	&"asleep": "asleep",
}
## TRANSLATORS: The same, "after %s": the program named by %s (in quotation
## marks) is above it and moves that thing too, so it wins. Lowercase.
## ROOM: 180 px at 14 px with “program 99”
const ORDER_AFTER := "after %s"
## TRANSLATORS: The line under the list of programs that says where the selected
## program runs, after its name and a middle dot, in 15 px type: %d is how many
## programs are on, %s a program's name in quotation marks. "Off": the autopilot
## skips a program that is off; "empty": it holds no instincts yet. Lowercase.
## ROOM: 600 px at 15 px
const PLACE_SAYS := {
	&"only": "the only program on",
	&"off": "off: the autopilot skips it",
	&"empty": "empty: open it to give it instincts",
}
## TRANSLATORS: The same line, for a program that runs first: %d is how many
## programs are on. Lowercase.
## ROOM: 600 px at 15 px with 8
const PLACE_FIRST := "runs first of the %d that are on"
## TRANSLATORS: The same line, for a program between two others that are on: each
## %s is a program's name in quotation marks. Lowercase.
## ROOM: 600 px at 15 px with “program 99”, “program 99”
const PLACE_MIDDLE := "runs after %s, before %s"
## TRANSLATORS: The same line, for a program that runs last: %s is the program
## just above it, in quotation marks. Lowercase.
## ROOM: 600 px at 15 px with “program 99”
const PLACE_LAST := "runs last, after %s"
## TRANSLATORS: What a program's instinct does when another program's, or one
## above it in the same program, holds it back, as a phrase finishing a sentence
## (see the messages it is used in): "already steers", "already swims", "already
## holds your tail" (keeps the tail still), "already rests", "already dashes",
## "already pushes", "already acts". Lowercase.
## ROOM: 200 px at 14 px
const ALREADY := {
	&"steer": "already steers",
	&"swim": "already swims",
	&"hold": "already holds your tail",
	&"rest": "already rests",
	&"dash": "already dashes",
	&"push": "already pushes",
	&"act": "already acts",
}
## TRANSLATORS: The same, for an instinct that holds every one below it back
## whatever happens: "always steers", "always swims"... Lowercase.
## ROOM: 200 px at 14 px
const ALWAYS_DOES := {
	&"steer": "always steers",
	&"swim": "always swims",
	&"hold": "always holds your tail",
	&"rest": "always rests",
	&"dash": "always dashes",
	&"push": "always pushes",
	&"act": "always acts",
}
## TRANSLATORS: Said under an "instinct" (a rule of a program) that is held back
## on this moment, in 14 px type. %s finishes the sentence: "already steers",
## "already swims"... Lowercase.
## ROOM: 856 px at 14 px with already
const HELD := "held back: an instinct above %s"
## TRANSLATORS: The same, when the instinct holding it back belongs to another
## program, higher in the list: the first %s is its name in quotation marks, the
## second finishes the sentence ("already steers"). Lowercase.
## ROOM: 856 px at 14 px with “program 99”, already
const HELD_BY := "held back: %s, above, %s"
## TRANSLATORS: Said under an instinct that can never act, because one above it
## acts whatever happens and wants the same thing: %s finishes the sentence,
## "always swims", "always steers"... Lowercase.
## ROOM: 856 px at 14 px with always
const NEVER := "never acts: an instinct above %s"
## TRANSLATORS: The same, when that instinct belongs to a program higher in the
## list: the first %s is its name in quotation marks. Lowercase.
## ROOM: 856 px at 14 px with “program 99”, always
const NEVER_BY := "never acts: %s, above, %s"
## TRANSLATORS: Said under the list of programs: one of the selected program's
## instincts is held back at this moment by a program higher in the list, named
## (in quotation marks) by %s; the second %s finishes the sentence ("already
## steers"). Lowercase.
## ROOM: 856 px at 14 px with “program 99”, already
const HELD_NOW := "held back now: %s, above, %s"
## TRANSLATORS: Said under the list of programs: the selected program (the first
## %s, in quotation marks) can never move one thing -- the second %s, "steering",
## "tail", "dash" or "push" -- because a program above it (the third %s) always
## does; the fourth %s finishes the sentence, "always swims". Lowercase.
## ROOM: 856 px at 14 px with “program 99”, trigger, “program 99”, always
const NEVER_MOVES := "%s never moves your %s: %s, above, %s"
## TRANSLATORS: Said when a program cannot be turned on: the programs that are on
## share eight places for their instincts. The first %s is its name in quotation
## marks, the %d's how many places it needs and how many are free. Lowercase.
## ROOM: 856 px at 14 px with “program 99”, 8, 8
const NO_ROOM_SAYS := "no room: %s needs %d places, %d are free · switch a program off first"
## TRANSLATORS: The states of an "instinct" (a rule), said under the list of them
## when one is selected, in 14 px type. "acting now": it is what the cell is doing.
## "waiting": its sense reports nothing, or what it reports does not pass the
## instinct's test; %s is the sense's name. "this version cannot read this
## instinct": it was written by a later version of the game, and is kept as it
## is. "pick what it does": a new instinct still needs its sense or its action.
## Lowercase.
## ROOM: 856 px at 14 px
const STATE_HINTS := {
	&"acting": "acting now",
	&"unread": "this version cannot read this instinct · it is kept",
	&"half": "pick what it does · until then it does nothing",
}
## TRANSLATORS: The same, for an instinct whose sense, named by %s ("echo",
## "smell"), reports nothing at this moment, or reports something that does not
## pass the instinct's test. Lowercase.
## ROOM: 856 px at 14 px with sense
const WAITING_SAYS := {
	&"quiet": "waiting: %s reports nothing",
	&"failed": "waiting: %s reports, the test is not met",
}
## TRANSLATORS: Said of an instinct that cannot act because the cell does not
## wear the organ it needs; %s is the sense's or the action's name ("push").
## Lowercase.
## ROOM: 856 px at 14 px with action
const ASLEEP_SAYS := "asleep: your body does not wear %s"
## TRANSLATORS: Said when the player picks a turn under a sense that does not say
## where things are (or such a sense under a turn): %s is the turn's name, "turn
## toward" or "turn away". Lowercase.
## ROOM: 856 px at 14 px with body
const NEEDS_WHERE := "%s needs a sense that says where"
## TRANSLATORS: The autopilot: a button that hands the player's cell to their
## programs. Its line under the page, when it is pointed at: its name, a middle
## dot, what it does. "Steer": the player's own steering takes the cell back.
## Lowercase.
## ROOM: 856 px at 15 px
const AUTOPILOT_EXPLAINS := ("autopilot · hand your cell to your programs. tap it again,"
	+ " or steer, to take it back.")
## TRANSLATORS: What the page says when the autopilot button is pressed, in 14 px
## type. "dead": no program is on, so it cannot be used. "on": your programs will
## have your cell when you resume the game ("pond": in a game shared with a
## friend, where the water keeps moving, they have it already). "off": your cell
## is yours again. Lowercase.
## ROOM: 856 px at 14 px
const AUTOPILOT_SAYS := {
	&"dead": "turn a program on to use the autopilot",
	&"on": "autopilot on: your programs have your cell when you resume",
	&"pond": "autopilot on: your programs have your cell",
	&"off": "autopilot off: your cell is yours",
}
## TRANSLATORS: The line of help at the bottom of the page of programs, in 14 px
## type, saying what can be done now. A "program" is a list of "instincts"; an
## instinct is a rule ("when a sense reports something -> do this"), built of
## blocks: its sense, its tests and its action. "+" is the button that adds one.
## Lowercase.
## ROOM: 856 px at 14 px
const ACT_SAYS := {
	&"library": "tap a program to see it · drag a program up to let it win",
	&"library_drag": "let go to move this program here",
	&"library_empty": "tap + to write your first program",
	&"program": "tap a block to change it · drag an instinct up or down to change which wins",
	&"program_empty": "tap + to give this program its first instinct",
	&"program_drag": "let go to move this instinct here",
	&"stay": "let go to leave it where it is",
	&"sense": "pick what this instinct listens to",
	&"action": "pick what your cell does",
	&"test": "tap a choice · it takes effect at once",
}
## TRANSLATORS: The inspector, the panel at the right of the page, explaining what
## a program and an instinct are when there is nothing to edit yet. "head" is its
## title in 17 px type; "nothing" says a program is still empty; the two
## explanations wrap in 14 px type in a panel 264 px wide; "senses" and
## "actions" head the lists of words the player's cell can use. Lowercase.
## ROOM: 264 px at 17 px
const INSPECTOR_SAYS := {
	&"none": "no programs yet",
	&"new": "new instinct",
	&"value": "test what?",
}
## TRANSLATORS: Under that title, in 14 px type in a panel 264 px wide: a
## program holds no instincts yet; then what the cell can sense and do, each a
## caption over a list of words. Lowercase.
## ROOM: 264 px at 14 px
const LEGEND_SAYS := {
	&"nothing": "nothing in it yet",
	&"senses": "what you can sense",
	&"actions": "what you can do",
}
## TRANSLATORS: Explanations in the inspector, wrapping over several lines of 14 px
## type in a panel 264 px wide (at most nine lines). "library": what a program is
## and how the autopilot uses them. "program": what an instinct is. Lowercase,
## full sentences.
const LEGEND_EXPLAINS := {
	&"library": "a program is a list of instincts: when a sense reports something, your"
		+ " cell acts. turn programs on, then the autopilot, and they drive your cell. the"
		+ " higher program wins.",
	&"program": "an instinct is something your cell does by itself on autopilot: when a"
		+ " sense reports something, it acts. the first instinct that fits, from the top,"
		+ " wins.",
}
## TRANSLATORS: The inspector's remove buttons, in 15 px type on a button 264 px
## wide: take this test, or the whole instinct, out of the program. Lowercase.
## ROOM: 230 px at 15 px
const REMOVE_SAYS := {
	&"test": "remove this test",
	&"instinct": "remove this instinct",
}
## TRANSLATORS: What the selected test's sense reports at this moment, under the
## ladder that sets the test, in 14 px type: %s is the reading -- "350 µm",
## "62%", "smaller than my mouth", several joined with commas -- or "nothing".
## Lowercase.
## ROOM: 264 px at 14 px with 1450 µm 1450 µm
const NOW := "now: %s"
## TRANSLATORS: What a sense reports when it reports nothing at all, in "now:
## nothing". Lowercase.
## ROOM: 180 px at 14 px
const NOTHING := "nothing"
## TRANSLATORS: What a count of seconds since something happened reports when it
## has not happened yet -- "meal" for a cell that has not eaten -- in "now: not
## yet". Lowercase.
## ROOM: 180 px at 14 px
const NOT_YET := "not yet"
## TRANSLATORS: The title of the sheet that renames one of the player's programs
## (lists of the cell's "instincts"), in 22 px type.
## ROOM: 512 px at 22 px
const RENAME_TITLE := "rename this program"
## TRANSLATORS: Under "delete <name>?" for a program with no instincts: nothing is
## lost. A full sentence.
const GONE_EMPTY := "it holds no instincts: nothing is lost."

# --- State -------------------------------------------------------------------------

## The run this page is on (normal_mode.gd), untyped: it preloads this file.
var _run: Node = null
var _library: Library = null
var _instincts: OwnRules = null
var _chip: Button = null
var _vocab: Rulebook.Vocabulary = null
## **Where the page is**: the view, and the program selected in the library or
## open in a program. Kept for the run: pause opens where it was left (§1.2).
var _view := View.LIBRARY
var _program := 0
## **What is selected in a program**: its row -- the row after the last
## instinct is the add row, or the half-built instinct -- and the part of it: 0
## the sense, 1 to 4 a test, [constant PART_ACTION] the action,
## [constant PART_ADD_TEST] its `+`.
var _row := 0
var _part := 0
const PART_ACTION := -1
const PART_ADD_TEST := -2
## **The half-built instinct** (§3.4): `{"input", "output"}`, each &"" until
## picked. The page's alone: it never acts and is never saved.
var _draft := {}
## The add-test `+` asking which value to test (§4.3).
var _asking := false
## A line a tap said on `Hint`, until the selection moves.
var _said := ""
## **What every rule of the merged list did** -- the last tick's in a pond, or
## the dry run's -- and which rules can never act ([method Rulebook.never]).
var _states: Array = []
var _never := PackedInt32Array()
var _tick_seen := -1
var _worn := 0
## **A drag in flight** (§2.6, §4.5): what is lifted, and the gap it would land in.
var _drag_from := -1
var _drag_gap := -1
## What the mouse or the keyboard is on, for `Explain`: `[row, part]`, or [].
var _hover: Array = []
var _ap_hot := false
## The inspector's control to give the focus back to after it is built again.
var _focus_key := ""
## The controls a placing shows, so the rest can be hidden after.
var _placing := {}
## **What each row looked like, and since when** (§3.2): states cross-fade over
## [constant FADE], so a pond's 7.5 ticks a second never flicker. Per row, the
## look it is fading from and to -- a program row's state, or a library row's
## `[drives now, its four column marks]` -- and when the change began; and the
## view and program they are of, a change of which starts them afresh.
var _look_was: Array = []
var _look_now: Array = []
var _look_at: Array[float] = []
var _looks_of := ""
var _rows_x := EDGE
var _rows_w := 856.0
var _input_w := 111.0
var _output_w := 142.0

var _head: Control = null
var _head_switch: Button = null
var _area: Control = null
var _row_nodes: Array[Control] = []
var _switches: Array[Button] = []
var _bodies: Array[Button] = []
var _opens: Array[Button] = []
var _adds: Array[Button] = []
var _copies: Array[Button] = []
var _senses: Array[Button] = []
var _tests: Array = []
var _add_tests: Array[Button] = []
var _actions: Array[Button] = []
var _lines: VBoxContainer = null
var _ex_name: Label = null
var _ex_says: Label = null
var _hint: Label = null
var _act: Label = null
var _tools: VBoxContainer = null
var _inspector: PanelContainer = null
## The inspector's room, which clips: what is built there never grows the panel
## and pushes `resume` down.
var _room: Control = null
var _box: VBoxContainer = null
var _resume: Button = null
var _autopilot: Button = null
var _ladder: Control = null


# --- Setting up ------------------------------------------------------------------

## **Handed what it shows**: the run, its library, its instincts and the page chip.
## [param resume] is the genome page's own `resume`, whose look the page's copy
## takes. Builds the page, hidden.
func setup(run: Node, library: Library, instincts: OwnRules, chip: Button,
		resume: Button = null) -> void:
	_run = run
	_library = library
	_instincts = instincts
	_chip = chip
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build(resume)
	_style_chip()
	hide()


func _build(resume_style: Button) -> void:
	_head = Control.new()
	_head.name = "Head"
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.draw.connect(_draw_head)
	add_child(_head)
	_head_switch = _blank_button("Switch")
	_head_switch.pressed.connect(_on_head_switch)
	_head_switch.draw.connect(_draw_head_switch)
	_hot_redraw(_head_switch)
	_head.add_child(_head_switch)

	# **The rows' area takes a drop that lands between rows** (§2.6): a row's
	# controls take one that lands on them.
	_area = Control.new()
	_area.name = "Rows"
	_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_area.draw.connect(_draw_area)
	_area.set_drag_forwarding(Callable(), _can_drop.bind(_area), _drop.bind(_area))
	add_child(_area)
	for j in ROWS:
		var row := Control.new()
		row.name = "Row%d" % j
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.draw.connect(_draw_row.bind(j))
		_area.add_child(row)
		_row_nodes.append(row)
		# **The keyboard selects as it goes** (§2.6): focus on any of a row's
		# controls selects its program, as a press does -- selecting costs nothing
		# -- so the inspector, `Explain`, the lit places and `Tab` follow the keys,
		# and `Enter` opens the program the page is showing.
		var switch := _row_button(row, "Switch", j)
		switch.pressed.connect(_on_switch.bind(j))
		switch.draw.connect(_draw_switch.bind(switch, j))
		switch.focus_entered.connect(_select_program.bind(j))
		_switches.append(switch)
		var body := _row_button(row, "Body", j)
		body.button_down.connect(_select_program.bind(j))
		body.pressed.connect(_select_program.bind(j))
		body.gui_input.connect(_on_body_key.bind(j))
		body.draw.connect(_draw_body_focus.bind(body, j))
		body.focus_entered.connect(_select_program.bind(j))
		_bodies.append(body)
		var open := _row_button(row, "Open", j)
		open.button_down.connect(_select_program.bind(j))
		open.pressed.connect(_open_from_row.bind(j))
		open.draw.connect(_draw_open.bind(open, j))
		open.focus_entered.connect(_select_program.bind(j))
		_opens.append(open)
		var add := _row_button(row, "Add", j)
		add.pressed.connect(_on_add.bind(j))
		add.draw.connect(_draw_add.bind(add, j))
		_adds.append(add)
		var copy := _row_button(row, "Copy", j)
		copy.pressed.connect(_on_copy_founders)
		copy.draw.connect(_draw_copy.bind(copy, j))
		_copies.append(copy)
		var sense := _row_button(row, "Sense", j)
		sense.button_down.connect(_select_part.bind(j, 0))
		sense.pressed.connect(_select_part.bind(j, 0))
		sense.gui_input.connect(_on_chip_key.bind(j))
		sense.draw.connect(_draw_sense.bind(sense, j))
		_senses.append(sense)
		var tests: Array[Button] = []
		for t in TESTS_MOST:
			var test := _row_button(row, "Test%d" % t, j)
			test.button_down.connect(_select_part.bind(j, t + 1))
			test.pressed.connect(_select_part.bind(j, t + 1))
			test.gui_input.connect(_on_chip_key.bind(j))
			test.draw.connect(_draw_test.bind(test, j, t))
			tests.append(test)
		_tests.append(tests)
		var add_test := _row_button(row, "AddTest", j)
		add_test.pressed.connect(_on_add_test.bind(j))
		add_test.draw.connect(_draw_add_test.bind(add_test, j))
		_add_tests.append(add_test)
		var action := _row_button(row, "Action", j)
		action.button_down.connect(_select_part.bind(j, PART_ACTION))
		action.pressed.connect(_select_part.bind(j, PART_ACTION))
		action.gui_input.connect(_on_chip_key.bind(j))
		action.draw.connect(_draw_action.bind(action, j))
		_actions.append(action)

	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_theme_constant_override("separation", 6)
	add_child(_lines)
	var explain := HBoxContainer.new()
	explain.name = "Explain"
	explain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	explain.alignment = BoxContainer.ALIGNMENT_CENTER
	explain.add_theme_constant_override("separation", 6)
	explain.custom_minimum_size = Vector2(0.0, 26.0)
	_lines.add_child(explain)
	_ex_name = _label(15, Color(PALE, 0.95))
	_ex_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	explain.add_child(_ex_name)
	_ex_says = _label(15, EXPLAIN)
	_ex_says.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	explain.add_child(_ex_says)
	_hint = _label(14, HINT)
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(0.0, 20.0)
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lines.add_child(_hint)
	_act = _label(14, ACT)
	_act.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_act.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act.custom_minimum_size = Vector2(0.0, 20.0)
	_act.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lines.add_child(_act)

	# **The tools column hangs from the right margin** (§2.1), under the page
	# chip: the inspector, then `resume` and the autopilot.
	_tools = VBoxContainer.new()
	_tools.name = "Tools"
	_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tools.add_theme_constant_override("separation", 12)
	_tools.anchor_left = 1.0
	_tools.anchor_right = 1.0
	_tools.offset_left = -EDGE - TOOLS_W
	_tools.offset_right = -EDGE
	_tools.offset_top = 184.0
	_tools.offset_bottom = 672.0
	add_child(_tools)
	_inspector = PanelContainer.new()
	_inspector.name = "Inspector"
	_inspector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspector.custom_minimum_size = Vector2(TOOLS_W, INSPECTOR_H)
	var panel := _box_style(Color(FILL, 0.45), Color(TEAL, 0.26), 1)
	panel.content_margin_left = 16.0
	panel.content_margin_right = 16.0
	panel.content_margin_top = 14.0
	panel.content_margin_bottom = 14.0
	_inspector.add_theme_stylebox_override("panel", panel)
	_tools.add_child(_inspector)
	_room = Control.new()
	_room.name = "Room"
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.clip_contents = true
	_room.custom_minimum_size = Vector2(INNER, INSPECTOR_H - 28.0)
	_inspector.add_child(_room)
	var bottom := HBoxContainer.new()
	bottom.name = "Bottom"
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 12)
	_tools.add_child(bottom)
	_resume = Button.new()
	_resume.name = "Resume"
	_resume.text = "resume"
	_resume.custom_minimum_size = Vector2(RESUME_W, AUTOPILOT_W)
	_resume.focus_mode = Control.FOCUS_ALL
	if resume_style != null:
		for kind: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled",
				&"hover_pressed"]:
			if resume_style.has_theme_stylebox_override(kind):
				_resume.add_theme_stylebox_override(kind,
					resume_style.get_theme_stylebox(kind))
		for kind: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
				&"font_focus_color", &"font_hover_pressed_color"]:
			if resume_style.has_theme_color_override(kind):
				_resume.add_theme_color_override(kind, resume_style.get_theme_color(kind))
		if resume_style.has_theme_font_size_override(&"font_size"):
			_resume.add_theme_font_size_override(&"font_size",
				resume_style.get_theme_font_size(&"font_size"))
	_resume.pressed.connect(_on_resume)
	_resume.mouse_entered.connect(_set_hover.bind([]))
	bottom.add_child(_resume)
	_autopilot = _blank_button("Autopilot")
	_autopilot.custom_minimum_size = Vector2(AUTOPILOT_W, AUTOPILOT_W)
	_autopilot.pressed.connect(_on_autopilot)
	_autopilot.draw.connect(_draw_page_autopilot)
	_autopilot.mouse_entered.connect(_set_autopilot_hot.bind(true))
	_autopilot.mouse_exited.connect(_set_autopilot_hot.bind(false))
	_autopilot.focus_entered.connect(_set_autopilot_hot.bind(true))
	_autopilot.focus_exited.connect(_set_autopilot_hot.bind(false))
	bottom.add_child(_autopilot)


## A button that draws itself: no box of Godot's, the focus its own mark.
func _blank_button(named: String) -> Button:
	var button := Button.new()
	button.name = named
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	for kind: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled",
			&"hover_pressed", &"normal_mirrored", &"hover_mirrored", &"pressed_mirrored",
			&"disabled_mirrored", &"hover_pressed_mirrored"]:
		button.add_theme_stylebox_override(kind, empty)
	return button


## One of a row's pooled controls: drawn by the page, dragged from, dropped on.
func _row_button(row: Control, named: String, j: int) -> Button:
	var button := _blank_button(named)
	button.hide()
	button.set_drag_forwarding(_get_drag.bind(j), _can_drop.bind(button), _drop.bind(button))
	_hot_redraw(button)
	button.mouse_entered.connect(_set_hover_of.bind(button))
	button.focus_entered.connect(_set_hover_of.bind(button))
	button.mouse_exited.connect(_set_hover.bind([]))
	button.focus_exited.connect(_set_hover.bind([]))
	row.add_child(button)
	return button


func _hot_redraw(button: Button) -> void:
	for changed: Signal in [button.mouse_entered, button.mouse_exited, button.focus_entered,
			button.focus_exited, button.button_down, button.button_up]:
		changed.connect(button.queue_redraw)


func _label(size: int, ink: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", ink)
	return label


## **The page chip** (§1.1): the gear's own box, 17 px, growing to the left.
func _style_chip() -> void:
	if _chip == null:
		return
	_chip.focus_mode = Control.FOCUS_ALL
	_chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_chip.add_theme_font_size_override(&"font_size", 17)
	var rest := _box_style(Color(0.063, 0.141, 0.125, 0.902), Color(0.141, 0.278, 0.247), 1, 8)
	var hot := _box_style(Color(0.086, 0.204, 0.176, 0.95), Color(TEAL, 0.62), 1, 8)
	var focus := _box_style(Color(0.0, 0.0, 0.0, 0.0), SELECT, 2, 8)
	for box: StyleBoxFlat in [rest, hot, focus]:
		box.content_margin_left = 18.0
		box.content_margin_right = 18.0
	_chip.add_theme_stylebox_override(&"normal", rest)
	_chip.add_theme_stylebox_override(&"hover", hot)
	_chip.add_theme_stylebox_override(&"pressed", hot)
	_chip.add_theme_stylebox_override(&"hover_pressed", hot)
	_chip.add_theme_stylebox_override(&"focus", focus)
	for kind: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_focus_color", &"font_hover_pressed_color"]:
		_chip.add_theme_color_override(kind, Color(PALE, 0.95))
	_chip.custom_minimum_size = Vector2(112.0, 56.0)
	_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _box_style(fill: Color, edge: Color, width: int, radius: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


# --- What the run calls ---------------------------------------------------------------

## **The library**, shown, with a program selected -- the one last open, else the
## first -- as pause opens on it or the chip turns to it. The keyboard goes to
## `resume`, as the genome page's does, unless [param keys] -- Back from a
## program by a key -- puts it on the program's row.
func show_library(keys := false) -> void:
	_view = View.LIBRARY
	_close_program()
	show()
	refresh()
	_give_focus(keys)


## **Program [param i], open** (§3), selected in the library behind it: its first
## acting instinct's sense selected, else its first instinct's, else its add row.
## [param keys] puts the keyboard on what is selected.
func open_program(i: int, keys := false) -> void:
	if _library == null or i < 0 or i >= _library.size():
		return
	_program = i
	_view = View.PROGRAM
	_draft = {}
	_asking = false
	_said = ""
	show()
	_compute_states()
	var lines := _library.programs[i].lines
	_row = lines.size()
	_part = 0
	for j in lines.size():
		if _state_of_row(j) == Rulebook.State.ACTED:
			_row = j
			break
	if _row == lines.size() and not lines.is_empty():
		_row = 0
	refresh()
	_give_focus(keys)


## **Shown as pause opens**, on the view it was left on.
func reopen() -> void:
	if _library == null:
		return
	if _view == View.PROGRAM and _program < _library.size():
		open_program(_program)
	else:
		show_library()


## **Back, or `Esc`** (§1.2): inside a program it goes back to the library and
## says so; in the library it does nothing, and the run resumes.
func back() -> bool:
	if not visible:
		return false
	if get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	if _view == View.PROGRAM:
		show_library(true)
		return true
	return false


## **A tool's seam** (tools/drive.gd `--page-select=`): select as a press would --
## in the library program `n` (from 1); in a program `<row>:<part>`, the row from
## 1 and the part `sense`, `test1` to `test4`, `action`, `add` (its `+`) or `new`
## (the add row).
func pose_select(spec: String) -> void:
	if _view == View.LIBRARY:
		_select_program(int(spec) - 1)
		return
	var parts := spec.split(":")
	var row := int(parts[0]) - 1
	var what := parts[1] if parts.size() > 1 else "sense"
	match what:
		"sense":
			_select_part(row, 0)
		"action":
			_select_part(row, PART_ACTION)
		"add":
			_select_part(row, 0)
			_on_add_test(row)
		"new":
			_on_add(row)
		_:
			if what.begins_with("test"):
				_select_part(row, int(what.substr(4)))


func _give_focus(keys: bool) -> void:
	if keys:
		_focus_selected()
	elif _resume != null and is_visible_in_tree():
		_resume.grab_focus()


## **The page goes** -- pause closing, a division or a death: a half-built
## instinct with it, and a drag.
func closed() -> void:
	_close_program()
	_said = ""
	_drag_from = -1
	_drag_gap = -1


func _close_program() -> void:
	_draft = {}
	_asking = false


## The autopilot was switched: the page's copy and words say so.
func autopilot_changed() -> void:
	if _autopilot != null:
		_autopilot.queue_redraw()
	if visible:
		_head.queue_redraw()
		_say_lines()


## **The chip's word** for the page it would turn to: `programs ›` from the genome
## page, `genome ›` from the library, `‹ programs` from a program.
func say_chip(genome_shown: bool) -> void:
	if _chip == null:
		return
	var key := &"programs" if genome_shown else (&"back" if _view == View.PROGRAM \
		else &"genome")
	_chip.text = tr(CHIP_SAYS[key])


## The chip pressed, on this page: up from a program, or back to the genome
## (which the run does, and says by returning false).
func chip_pressed() -> bool:
	if _view == View.PROGRAM:
		show_library(_by_keys())
		return true
	return false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			# Deferred (settings.md §3.3): the tree is still telling every node.
			if is_node_ready() and _library != null:
				_said = ""
				refresh.call_deferred()
		NOTIFICATION_RESIZED:
			if _library != null and visible:
				refresh.call_deferred()
		NOTIFICATION_DRAG_END:
			if _drag_from >= 0 or _drag_gap >= 0:
				_drag_from = -1
				_drag_gap = -1
				_redraw_rows()
				_say_lines()


func _process(_delta: float) -> void:
	if not visible or _library == null:
		return
	if _fading():
		_area.queue_redraw()
		for j in ROWS:
			_row_nodes[j].queue_redraw()
			for button: Button in _pool(j):
				if button.visible:
					button.queue_redraw()
	# **In a pond the rows update with every tick** (§7.1): the last tick's
	# states while the autopilot drives, the dry run's while it does not.
	if bool(_run.call(&"_session_up")) and _instincts.tick != _tick_seen:
		_tick_seen = _instincts.tick
		_compute_states()
		_redraw_rows()
		_say_lines()


# --- The model, read -----------------------------------------------------------------

## **Everything said again and placed again** from the library: after an edit, a
## switch, a move, a change of language or of shape.
func refresh() -> void:
	if _library == null:
		return
	_vocab = FoodField.vocabulary()
	if _program >= _library.size():
		_program = maxi(_library.size() - 1, 0)
	if _view == View.PROGRAM and _library.size() == 0:
		_view = View.LIBRARY
	_compute_states()
	_layout()
	_clamp_selection()
	_place_rows()
	_build_inspector()
	_say_lines()
	_head.queue_redraw()
	_autopilot.queue_redraw()
	if visible:
		say_chip(false)


## **What every rule did, or would do**: in a pond the last tick's while the
## autopilot drives; otherwise the dry run -- read from the last frame's reports,
## acting on nothing and remembering nothing (§7.1).
func _compute_states() -> void:
	_states = []
	_never = PackedInt32Array()
	if _library == null:
		return
	_vocab = FoodField.vocabulary()
	_worn = int(_instincts.call(&"worn"))
	var merged := _library.merged(_vocab)
	if merged == null:
		return
	_never = Rulebook.never(merged, _worn)
	if _instincts.list != merged:
		return
	if _instincts.driving and not _instincts.states.is_empty():
		_states = _instincts.states.duplicate()
	else:
		_states = _instincts.dry_run()


## The state of merged rule [param k], or -1 for none known.
func _state_at(k: int) -> int:
	if k < 0 or k >= _states.size():
		return -1
	return int((_states[k] as Array)[0])


## The merged rule that held rule [param k] back, or -1.
func _held_by(k: int) -> int:
	if k < 0 or k >= _states.size():
		return -1
	return int((_states[k] as Array)[1])


## **Row [param j] of the open program's state**, as the page draws it.
func _state_of_row(j: int) -> int:
	var k := _library.merged_index(_program, j) if _program < _library.size() else -1
	return _state_at(k)


func _list() -> Rulebook.Behaviour:
	if _library == null or _program >= _library.size():
		return null
	return _library.list_of(_program, FoodField.vocabulary())


func _lines_of(i: int) -> PackedStringArray:
	return _library.programs[i].lines if i >= 0 and i < _library.size() \
		else PackedStringArray()


## Whether [param rule]'s organs are all worn.
func _awake(rule: Rulebook.Rule) -> bool:
	return rule.inert or (rule.needs & _worn) == rule.needs


## The triggers [param rule] claims, as the columns' indices.
func _columns_of(rule: Rulebook.Rule) -> Array[int]:
	var out: Array[int] = []
	if rule.inert:
		return out
	for c in COLUMNS.size():
		var bit := int(_vocab.claims.get(COLUMNS[c], 0))
		if bit != 0 and (rule.claims & bit) != 0:
			out.append(c)
	return out


## **What the rule that holds another back is doing**, as the hints' verb: the
## turn steers, a swim swims, a hold holds the tail, a rest rests.
func _verb_of(rule: Rulebook.Rule) -> StringName:
	if rule == null or rule.inert:
		return &"act"
	match rule.output:
		&"body.turn-toward", &"body.turn-away", &"body.turn-random":
			return &"steer"
		&"body.swim":
			return &"swim"
		&"body.rest":
			return &"rest"
	if organ_of(rule.output) != &"":
		return PART_VERBS.get(Rulebook.part_of(rule.output), &"act")
	return &"act"


func _merged_rule(k: int) -> Rulebook.Rule:
	var merged := _library.merged(_vocab)
	if merged == null or k < 0 or k >= merged.rules.size():
		return null
	return merged.rules[k]


func _quoted_name(i: int) -> String:
	return ProgramWords.quoted(_library.name_of(i))


# --- Layout (§2.1) ---------------------------------------------------------------------

func _layout() -> void:
	var canvas := size if size.x > 0.0 else get_viewport_rect().size
	_rows_w = minf(canvas.x - 2.0 * EDGE - TOOLS_W - TOOLS_GAP, ROWS_MAX)
	_rows_x = EDGE + floorf((canvas.x - 2.0 * EDGE - TOOLS_W - TOOLS_GAP - _rows_w) * 0.5)
	_head.position = Vector2(_rows_x, HEAD_Y)
	_head.size = Vector2(_rows_w, HEAD_H)
	_area.position = Vector2(_rows_x, ROWS_Y)
	_area.size = Vector2(_rows_w, ROWS * ROW_H + (ROWS - 1) * ROW_SEP)
	for j in ROWS:
		_row_nodes[j].position = Vector2(0.0, j * (ROW_H + ROW_SEP))
		_row_nodes[j].size = Vector2(_rows_w, ROW_H)
	_lines.position = Vector2(_rows_x, LINES_Y)
	_lines.size = Vector2(_rows_w, 78.0)
	var widths := chip_widths(_font())
	_input_w = widths.x
	_output_w = widths.y


func _font() -> Font:
	var font := get_theme_default_font()
	return font if font != null else ThemeDB.fallback_font


## **The sense and action columns' widths** (§3.2): the widest sense word at 15 px
## plus the glyph's room and the padding, and the widest action, `push · full`
## included -- in the language of the moment, over the whole vocabulary.
static func chip_widths(font: Font) -> Vector2:
	var vocab := FoodField.vocabulary()
	var widest_in := _text_w(font, ProgramWords.says(Rulebook.ALWAYS), 15)
	for input: StringName in vocab.inputs:
		widest_in = maxf(widest_in, _text_w(font, ProgramWords.says(input), 15))
	var widest_out := 0.0
	for output: StringName in vocab.outputs:
		var decl: Rulebook.OutputDecl = vocab.outputs[output]
		var said := ProgramWords.says(output)
		widest_out = maxf(widest_out, _text_w(font, said, 15))
		for option: float in decl.options:
			widest_out = maxf(widest_out, _text_w(font,
				said + " · " + ProgramWords.option_text(option), 15))
	return Vector2(ceilf(widest_in + GLYPH_W + 2.0 * CHIP_PAD),
		ceilf(widest_out + GLYPH_W + 2.0 * CHIP_PAD))


static func _text_w(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


## A test chip's width: its phrase at 14 px and the padding, 48 at least.
func _test_w(clause: Rulebook.Clause) -> float:
	return maxf(ceilf(_text_w(_font(), ProgramWords.test_text(clause), 14) + 2.0 * CHIP_PAD),
		48.0)


func _copy_w() -> float:
	return ceilf(_text_w(_font(), tr(ADD_SAYS[&"copy"]), 15) + 40.0)


# --- Selection --------------------------------------------------------------------------

func _clamp_selection() -> void:
	if _view == View.LIBRARY:
		_program = clampi(_program, 0, maxi(_library.size() - 1, 0))
		return
	var lines := _lines_of(_program)
	_row = clampi(_row, 0, lines.size())
	if _row == lines.size():
		if _draft.is_empty():
			_part = 0
		elif _part != 0 and _part != PART_ACTION:
			_part = 0
		return
	var list := _list()
	var rule: Rulebook.Rule = list.rules[_row] if list != null and _row < list.rules.size() \
		else null
	if rule == null or rule.inert:
		_part = 0
		return
	if _part > rule.clauses.size():
		_part = rule.clauses.size() if rule.clauses.size() > 0 else 0
	if _part == PART_ADD_TEST and not _can_add_test(rule):
		_part = 0


## **A program selected** in the library (§2.2): on the press, harmless and
## idempotent, so the second copy of a phone touch changes nothing.
func _select_program(j: int) -> void:
	if _view != View.LIBRARY or j >= _library.size():
		return
	if _program == j:
		return
	_program = j
	_said = ""
	_place_rows()
	_build_inspector()
	_say_lines()
	_head.queue_redraw()


## **A part of an instinct selected** (§4.1): on the press, harmless and
## idempotent.
func _select_part(j: int, part: int) -> void:
	if _view != View.PROGRAM:
		return
	if _row == j and _part == part and not _asking:
		return
	_row = j
	_part = part
	_asking = false
	_said = ""
	_clamp_selection()
	_place_rows()
	_build_inspector()
	_say_lines()


func _focus_selected() -> void:
	if not visible:
		return
	var target: Control = null
	if _view == View.LIBRARY:
		if _library.size() > 0:
			target = _bodies[_program]
		else:
			target = _adds[0]
	else:
		target = _selected_button()
	if target != null and target.is_visible_in_tree():
		target.grab_focus()
	elif _resume != null:
		_resume.grab_focus()


func _selected_button() -> Button:
	if _row >= ROWS:
		return null
	if _row == _lines_of(_program).size() and _draft.is_empty():
		return _adds[_row]
	match _part:
		0:
			return _senses[_row]
		PART_ACTION:
			return _actions[_row]
		PART_ADD_TEST:
			return _add_tests[_row]
	if _part >= 1 and _part <= TESTS_MOST:
		return (_tests[_row] as Array)[_part - 1]
	return _senses[_row]


func _set_hover_of(button: Button) -> void:
	var row := button.get_parent()
	var j := _row_nodes.find(row)
	if j < 0:
		return
	var part := 0
	if button == _actions[j]:
		part = PART_ACTION
	elif button == _add_tests[j]:
		part = PART_ADD_TEST
	elif (_tests[j] as Array).has(button):
		part = (_tests[j] as Array).find(button) + 1
	elif button != _senses[j]:
		_set_hover([])
		return
	_set_hover([j, part])


func _set_hover(on: Array) -> void:
	if _hover == on:
		return
	_hover = on
	_say_lines()


# --- Placing the rows -------------------------------------------------------------------

func _place_rows() -> void:
	# **Only what goes is hidden**: hiding the control a finger is pressing lets
	# go of the press, and a drag can then never start from it.
	_placing = {}
	if _view == View.LIBRARY:
		_place_library()
	else:
		_place_program()
	for j in ROWS:
		for button: Button in _pool(j):
			if not _placing.has(button):
				button.hide()
	_head_switch.visible = _view == View.PROGRAM and _program < _library.size()
	if _head_switch.visible:
		var title_w := _text_w(_font(), _library.name_of(_program), 16)
		var x := maxf(title_w + 12.0, 124.0 - _rows_x)
		_head_switch.position = Vector2(x, 4.0)
		_head_switch.size = Vector2(SWITCH_W, ROW_H)
	_redraw_rows()
	_link_focus()


func _pool(j: int) -> Array[Button]:
	var out: Array[Button] = [_switches[j], _bodies[j], _opens[j], _adds[j], _copies[j],
		_senses[j], _add_tests[j], _actions[j]]
	for test: Button in _tests[j]:
		out.append(test)
	return out


func _put(button: Button, at: Rect2) -> void:
	_placing[button] = true
	button.position = at.position
	button.size = at.size
	button.show()


func _place_library() -> void:
	var n := _library.size()
	for j in mini(n, ROWS):
		_put(_switches[j], Rect2(0.0, 0.0, SWITCH_W, ROW_H))
		_put(_bodies[j], Rect2(SWITCH_W, 0.0, _rows_w - SWITCH_W - OPEN_W, ROW_H))
		_put(_opens[j], Rect2(_rows_w - OPEN_W, 0.0, OPEN_W, ROW_H))
	if n >= ROWS:
		return
	var copy_w := _copy_w()
	if n == 0:
		_put(_adds[0], Rect2(0.0, 0.0, _rows_w, ROW_H))
		_put(_copies[1], Rect2(0.0, 0.0, copy_w, ROW_H))
		return
	_put(_adds[n], Rect2(0.0, 0.0, _rows_w - copy_w - 12.0, ROW_H))
	_put(_copies[n], Rect2(_rows_w - copy_w, 0.0, copy_w, ROW_H))


func _place_program() -> void:
	var list := _list()
	if list == null:
		return
	var n := list.rules.size()
	for j in mini(n, ROWS):
		var rule := list.rules[j]
		if rule.inert:
			_put(_senses[j], Rect2(0.0, 0.0, _rows_w, ROW_H))
			continue
		var lay := _chips_of(rule, j == _row)
		_put(_senses[j], lay["sense"])
		var tests: Array = lay["tests"]
		for t in mini(tests.size(), TESTS_MOST):
			_put((_tests[j] as Array)[t], tests[t])
		var add: Rect2 = lay["add"]
		if add.size.x > 0.0:
			_put(_add_tests[j], add)
		_put(_actions[j], lay["action"])
	if n >= ROWS:
		return
	if not _draft.is_empty():
		_put(_senses[n], Rect2(0.0, 0.0, _input_w, ROW_H))
		_put(_actions[n], Rect2(_rows_w - _output_w, 0.0, _output_w, ROW_H))
	elif _library.can_add(_program):
		_put(_adds[n], Rect2(0.0, 0.0, _rows_w, ROW_H))


## **An instinct's chips, laid out** (§3.2): its sense at 0, a chip per test, the
## `+` on the selected row while a value is untested, and its action against the
## right edge.
func _chips_of(rule: Rulebook.Rule, selected: bool) -> Dictionary:
	var out := {"sense": Rect2(0.0, 0.0, _input_w, ROW_H), "tests": [], "add": Rect2(),
		"action": Rect2(_rows_w - _output_w, 0.0, _output_w, ROW_H)}
	var x := _input_w + CHIP_SEP
	for clause: Rulebook.Clause in rule.clauses:
		var w := _test_w(clause)
		(out["tests"] as Array).append(Rect2(x, 0.0, w, ROW_H))
		x += w + CHIP_SEP
	if selected and _can_add_test(rule):
		out["add"] = Rect2(x, 0.0, ADD_TEST_W, ROW_H)
		x += ADD_TEST_W + CHIP_SEP
	out["end"] = x - CHIP_SEP
	return out


func _can_add_test(rule: Rulebook.Rule) -> bool:
	if rule == null or rule.inert or rule.input == Rulebook.ALWAYS:
		return false
	var decl := _vocab.inputs.get(rule.input) as Rulebook.InputDecl
	return decl != null and rule.clauses.size() < decl.values.size()


func _redraw_rows() -> void:
	_note_looks()
	_area.queue_redraw()
	for j in ROWS:
		_row_nodes[j].queue_redraw()
		for button: Button in _pool(j):
			if button.visible:
				button.queue_redraw()


## **The keyboard's way through the page** (§2.6, §4.6): the arrows by Godot's
## own neighbours, which the rows' grid makes right; and **Tab round one loop** --
## from any row to the inspector, through it to `resume`, the autopilot, and back
## to what is selected in the rows -- so Tab never wanders off to the corner.
func _link_focus() -> void:
	if _resume == null or _autopilot == null:
		return
	var tools := _inspector_controls()
	var first: Control = tools[0] if not tools.is_empty() else _resume
	for j in ROWS:
		for button: Button in _pool(j):
			if button.visible:
				button.focus_next = button.get_path_to(first)
				button.focus_previous = button.get_path_to(_autopilot)
	if _head_switch.visible:
		_head_switch.focus_next = _head_switch.get_path_to(first)
		_head_switch.focus_previous = _head_switch.get_path_to(_autopilot)
	for k in tools.size():
		var control: Control = tools[k]
		control.focus_next = control.get_path_to(tools[k + 1] if k + 1 < tools.size() else _resume)
		if k > 0:
			control.focus_previous = control.get_path_to(tools[k - 1])
	var back_to := _selected_target()
	_resume.focus_next = _resume.get_path_to(_autopilot)
	_resume.focus_previous = _resume.get_path_to(tools[tools.size() - 1] if not tools.is_empty()
		else back_to)
	_autopilot.focus_previous = _autopilot.get_path_to(_resume)
	_autopilot.focus_next = _autopilot.get_path_to(back_to)
	if not tools.is_empty():
		tools[0].focus_previous = tools[0].get_path_to(back_to)


## What Tab comes back to in the rows: the selected program's row, the selected
## part of an instinct, or the add row.
func _selected_target() -> Control:
	var target: Control = null
	if _view == View.LIBRARY:
		target = _bodies[_program] if _program < _library.size() else _adds[0]
	else:
		target = _selected_button()
	if target == null or not target.visible:
		target = _resume
	return target


## The inspector's controls the keyboard can reach, in order.
func _inspector_controls() -> Array[Control]:
	var out: Array[Control] = []
	if _box == null:
		return out
	for node: Node in _box.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_ALL and control.visible:
			out.append(control)
	return out


# --- Drawing the rows ---------------------------------------------------------------------

## **Each row's look, noted**: a row whose look changed starts a fade from the
## one it had; a new view or program starts every row afresh, with no fade.
func _note_looks() -> void:
	var key := "%d/%d/%d" % [_view, _program, _library.size() if _library != null else 0]
	var fresh := key != _looks_of or _look_now.size() != ROWS
	_looks_of = key
	if _look_now.size() != ROWS:
		_look_was.resize(ROWS)
		_look_now.resize(ROWS)
		_look_at.resize(ROWS)
	var now := Time.get_ticks_msec() / 1000.0
	for j in ROWS:
		var look: Variant = _look_of(j) if _view == View.PROGRAM else _library_look(j)
		if fresh:
			_look_was[j] = look
			_look_now[j] = look
			_look_at[j] = -INF
		elif look != _look_now[j]:
			_look_was[j] = _look_now[j]
			_look_now[j] = look
			_look_at[j] = now


## How far row [param j] is through its fade, 0 at its start and 1 once done.
func _blend(j: int) -> float:
	if j >= _look_at.size():
		return 1.0
	return clampf((Time.get_ticks_msec() / 1000.0 - _look_at[j]) / FADE, 0.0, 1.0)


## **How much of [param looks] row [param j] shows**, faded: 1 when it is in one
## of them now and was before, 0 in neither, and the fade between.
func _amount(j: int, looks: Array) -> float:
	if j >= _look_now.size():
		return 0.0
	var was := 1.0 if looks.has(_look_was[j]) else 0.0
	var is_now := 1.0 if looks.has(_look_now[j]) else 0.0
	return lerpf(was, is_now, _blend(j))


## Whether any row is still fading, so the page keeps drawing until none is.
func _fading() -> bool:
	for j in _look_at.size():
		if _blend(j) < 1.0:
			return true
	return false


## **A library row's look**: whether its program drives the cell now, and what
## each column shows (§2.3).
func _library_look(j: int) -> Variant:
	if _library == null or j >= _library.size():
		return []
	return [_drives_now(j), _program_columns(j)]


func _draw_area() -> void:
	# **Where a drag would land** (§2.6): a lit line in the gap nearest the
	# pointer, a dot at each end.
	if _drag_from < 0 or _drag_gap < 0:
		return
	var y := _drag_gap * (ROW_H + ROW_SEP) - ROW_SEP * 0.5
	var ink := Color(LIT, 0.95)
	_area.draw_line(Vector2(-10.0, y), Vector2(_rows_w + 10.0, y), ink, 2.5, true)
	_area.draw_circle(Vector2(-10.0, y), 4.5, ink, true, -1.0, true)
	_area.draw_circle(Vector2(_rows_w + 10.0, y), 4.5, ink, true, -1.0, true)


func _draw_row(j: int) -> void:
	var row := _row_nodes[j]
	if _view == View.LIBRARY:
		_draw_library_row(row, j)
	else:
		_draw_program_row(row, j)


func _draw_library_row(row: Control, j: int) -> void:
	var n := _library.size()
	var r := Rect2(Vector2.ZERO, row.size)
	if j >= n:
		if n == 0 and j == 0:
			# **The invitation** (§2.7): the add row, filled and lit.
			row.draw_style_box(_box_style(Color(FILL, 0.55), Color(0, 0, 0, 0), 0), r)
			_dashed_box(row, r, Color(LIT, 0.55), 1.4, 6.0, 6.0)
		elif (n == 0 and j == 1) or j == n:
			pass
		else:
			_dashed_box(row, r, Color(PALE, 0.09), 1.0, 6.0, 6.0)
		return
	if _drag_from == j:
		# **Its place, hollow**, while it is in the air.
		_dashed_box(row, r, Color(PALE, 0.30), 1.2, 5.0, 6.0)
		return
	var one: Library.Program = _library.programs[j]
	var selected := j == _program
	var t := _blend(j)
	var was: Array = _look_was[j] if j < _look_was.size() and _look_was[j] is Array \
		and not (_look_was[j] as Array).is_empty() else _library_look(j)
	var now_look: Array = _library_look(j)
	var driving := lerpf(1.0 if bool(was[0]) else 0.0, 1.0 if bool(now_look[0]) else 0.0, t)
	if driving > 0.0:
		row.draw_style_box(_box_style(Color(LIT, 0.045 * driving), Color(0, 0, 0, 0), 0, 10),
			Rect2(Vector2(-6.0, -4.0), row.size + Vector2(12.0, 8.0)))
	var box: StyleBoxFlat
	if selected:
		box = _box_style(SELECTED, SELECT, 2)
	elif one.on:
		box = _box_style(Color(FILL, 0.55), Color(TEAL, 0.30), 1)
	else:
		box = _box_style(Color(FILL, 0.30), Color(PALE, 0.10), 1)
	row.draw_style_box(box, r)
	# The count, right-aligned before the columns; the name trimmed before it.
	var columns_x := _rows_w - OPEN_W - COLUMNS_GAP - COLUMN_W * COLUMNS.size()
	var texts := _row_texts(j)
	var count: String = texts[0]
	var count_x: float = texts[1]
	_text(row, Vector2(count_x, ROW_H * 0.5), count, 14, Color(PALE, 0.45 if one.on else 0.30))
	var name: String = texts[2]
	_text(row, Vector2(NAME_X, ROW_H * 0.5), name, 15, Color(PALE, 0.92 if one.on else 0.50))
	# The trigger columns (§2.3), each fading from what it showed.
	var marks: Array = now_look[1]
	var marks_was: Array = was[1]
	for c in COLUMNS.size():
		var centre := Vector2(columns_x + COLUMN_W * c + COLUMN_W * 0.5, ROW_H * 0.5)
		if String(marks_was[c]) != String(marks[c]) and t < 1.0:
			_draw_column_state(row, c, centre, String(marks_was[c]), 1.0 - t)
			_draw_column_state(row, c, centre, String(marks[c]), t)
		else:
			_draw_column_state(row, c, centre, String(marks[c]), 1.0)


## **A library row's words as it draws them**: `[its count, where the count
## starts, its name trimmed with an ellipsis 16 px before the count]`.
func _row_texts(j: int) -> Array:
	var font := _font()
	var one: Library.Program = _library.programs[j]
	var columns_x := _rows_w - OPEN_W - COLUMNS_GAP - COLUMN_W * COLUMNS.size()
	var count := _count_text(one.lines.size())
	if not one.on and not _library.fits(j):
		count += " · " + tr(NO_ROOM)
	var count_x := columns_x - 16.0 - _text_w(font, count, 14)
	return [count, count_x, _trimmed(font, _library.name_of(j), 15, count_x - 16.0 - NAME_X)]


## **A library row with the keyboard on it** (§2.6): its program's name
## underlined, 2 px of [constant SELECT] at y 38 under the name as the row draws
## it -- under the name rather than along the row's foot, where a selected row's
## own 2 px edge would read as a doubled line. Keyboard focus only: a press gives
## a row's controls a hidden focus, and its selection says the rest.
func _draw_body_focus(body: Button, j: int) -> void:
	if _view != View.LIBRARY or j >= _library.size() or not body.has_focus(true):
		return
	var x := NAME_X - SWITCH_W
	var w := _text_w(_font(), String(_row_texts(j)[2]), 15)
	body.draw_line(Vector2(x, 38.0), Vector2(x + w, 38.0), SELECT, 2.0, true)


## **One column of a program's row**, as [param mark] shows it (§2.3), at
## [param k] of its light.
func _draw_column_state(row: Control, c: int, centre: Vector2, mark: String, k: float) -> void:
	if mark == "" or k <= 0.0:
		return
	match mark:
		"now":
			row.draw_style_box(_box_style(Color(LIT, 0.14 * k), Color(LIT, 0.55 * k), 1),
				Rect2(centre - Vector2(17.0, 17.0), Vector2(34.0, 34.0)))
			draw_column_mark(row, c, centre, 0.98 * k)
		"moves":
			draw_column_mark(row, c, centre, 0.80 * k)
		"never":
			draw_column_mark(row, c, centre, 0.34 * k)
			_draw_never_bar(row, centre.x, 0.0, k)
		_:
			draw_column_mark(row, c, centre, 0.30 * k)


## **The page's mark for inhibition** over a column (§2.3): a stem from y 3 to 10
## and a 16 px bar at y 10.5.
func _draw_never_bar(node: CanvasItem, x: float, top := 0.0, k := 1.0) -> void:
	var ink := Color(PALE, 0.70 * k)
	node.draw_line(Vector2(x, top + 3.0), Vector2(x, top + 10.0), ink, 2.4, true)
	node.draw_line(Vector2(x - 8.0, top + 10.5), Vector2(x + 8.0, top + 10.5), ink, 2.4, true)


## **What program [param i] shows in each column** (§2.3): "" for a trigger it
## does not move; "off" while it is off or every instinct there sleeps; "never"
## when a program above that is on always wins it; "now" when one of its
## instincts won it on the last tick or would now; "moves" otherwise.
func _program_columns(i: int) -> Array[String]:
	var out: Array[String] = ["", "", "", ""]
	var one: Library.Program = _library.programs[i]
	var list := _library.list_of(i, _vocab)
	for c in COLUMNS.size():
		var claiming: Array[int] = []
		for j in list.rules.size():
			if _columns_of(list.rules[j]).has(c):
				claiming.append(j)
		if claiming.is_empty():
			continue
		if not one.on:
			out[c] = "off"
			continue
		var awake := false
		var now := false
		var all_never := true
		for j: int in claiming:
			var rule := list.rules[j]
			if not _awake(rule):
				continue
			awake = true
			var k := _library.merged_index(i, j)
			if _state_at(k) == Rulebook.State.ACTED:
				now = true
			var blocker := _never[k] if k >= 0 and k < _never.size() else -1
			if blocker < 0 or _library.owner_of(blocker).x == i:
				all_never = false
		if not awake:
			out[c] = "off"
		elif now:
			out[c] = "now"
		elif all_never:
			out[c] = "never"
		else:
			out[c] = "moves"
	return out


## Whether program [param i] drives the cell now: one of its instincts acted.
func _drives_now(i: int) -> bool:
	if not _library.programs[i].on:
		return false
	for j in _library.programs[i].lines.size():
		if _state_at(_library.merged_index(i, j)) == Rulebook.State.ACTED:
			return true
	return false


## TRANSLATORS: How many "instincts" (rules) a program holds, on its row in 14 px
## type: "1 instinct", "7 instincts". Lowercase.
## ROOM: 90 px at 14 px with 7
func _count_text(n: int) -> String:
	if n == 0:
		return tr(EMPTY)
	return tr_n("%d instinct", "%d instincts", n) % n


## **The trigger's mark**, as the pad that works it by hand draws it, small
## (§2.3): the turn pad's dart, one stroke of the tail, the myoneme's burst, the
## push pad's three waves. Static, for the inspector's lines too.
static func draw_column_mark(node: CanvasItem, column: int, centre: Vector2, ink: float) -> void:
	match column:
		0:
			Cilia.draw_slot_dart(node, 1, ControlsNode.TURN_HUE * Color(ink, ink, ink, 1.0),
				centre, 9.0, false)
		1:
			var points := PackedVector2Array()
			for i in 17:
				var u := float(i) / 16.0
				points.append(centre + Vector2((u - 0.5) * 24.0, -sin(u * TAU) * 4.5))
			node.draw_polyline(points, Color(ControlsNode.HOLD_HUE, ink), 2.2, true)
		2:
			Cilia.draw_tile_organ(node, ControlsNode.DASH_ORGAN, 1, centre + Vector2(0.0, 5.0),
				ink, 0.75)
		3:
			for row in 3:
				var points := PackedVector2Array()
				var lift := (float(row) - 1.0) * -6.5
				for i in 13:
					var u := float(i) / 12.0
					points.append(centre + Vector2((u - 0.5) * 22.0,
						lift + sin(u * TAU + float(row) * 0.22 * TAU) * 2.4))
				node.draw_polyline(points, Color(ControlsNode.PUSH_HUE, ink), 1.6, true)


func _draw_switch(button: Button, j: int) -> void:
	if _view != View.LIBRARY or j >= _library.size() or _drag_from == j:
		return
	draw_switch(button, _library.programs[j].on, button.is_hovered() or button.has_focus())
	if button.has_focus():
		_focus_mark(button)


func _draw_head_switch() -> void:
	if _program >= _library.size():
		return
	draw_switch(_head_switch, _library.programs[_program].on, _head_switch.is_hovered())
	if _head_switch.has_focus():
		_focus_mark(_head_switch)


## **A program's switch** (§2.2): a track 40 x 20 with a square knob, at the right
## and lit when on, at the left and pale when off. Rounded squares, never a
## circle (`controls.md` §4).
static func draw_switch(node: CanvasItem, on: bool, hot: bool) -> void:
	var track := Rect2(12.0, 14.0, 40.0, 20.0)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	box.anti_aliasing = true
	if on:
		box.bg_color = Color(0.086, 0.204, 0.176, 0.95)
		box.border_color = Color(TEAL, 0.95 if hot else 0.80)
	else:
		box.bg_color = Color(FILL, 0.60)
		box.border_color = Color(PALE, 0.47 if hot else 0.22)
	node.draw_style_box(box, track)
	var knob := StyleBoxFlat.new()
	knob.set_corner_radius_all(4)
	knob.anti_aliasing = true
	knob.bg_color = Color(LIT, 0.95) if on else Color(PALE, 0.40)
	node.draw_style_box(knob, Rect2(Vector2(35.0 if on else 15.0, 17.0), Vector2(14.0, 14.0)))


func _draw_open(button: Button, j: int) -> void:
	if j >= _library.size() or _drag_from == j:
		return
	var on := _library.programs[j].on
	var ink := Color(PALE, 0.95 if button.is_hovered() or button.has_focus() \
		else (0.70 if on else 0.45))
	var c := Vector2(OPEN_W * 0.5, ROW_H * 0.5)
	button.draw_polyline(PackedVector2Array([c + Vector2(-3.5, -8.0), c + Vector2(4.0, 0.0),
		c + Vector2(-3.5, 8.0)]), ink, 2.0, true)
	if button.has_focus():
		_focus_mark(button)


func _draw_add(button: Button, j: int) -> void:
	var r := Rect2(Vector2.ZERO, button.size)
	var hot := button.is_hovered() or button.has_focus()
	var invitation := (_view == View.LIBRARY and _library.size() == 0) \
		or (_view == View.PROGRAM and _lines_of(_program).is_empty())
	var word := tr(ADD_SAYS[&"new"]) if _view == View.LIBRARY else tr(ADD_INSTINCT)
	if invitation:
		_dashed_box(button, r, Color(LIT, 0.70 if hot else 0.55), 1.4, 6.0, 6.0)
		_plus(button, Vector2(22.0, ROW_H * 0.5), Color(MINT, 0.85))
		_text(button, Vector2(40.0, ROW_H * 0.5), word, 16, Color(MINT, 0.85))
	else:
		_dashed_box(button, r, Color(LIT, 0.55 if hot else 0.40), 1.2, 6.0, 6.0)
		_plus(button, Vector2(20.0, ROW_H * 0.5), Color(MINT, 0.70))
		_text(button, Vector2(34.0, ROW_H * 0.5), word, 15, Color(MINT, 0.70))
	if button.has_focus():
		_focus_mark(button)


func _draw_copy(button: Button, _j: int) -> void:
	var r := Rect2(Vector2.ZERO, button.size)
	var hot := button.is_hovered() or button.has_focus()
	button.draw_style_box(_box_style(Color(FILL, 0.40), Color(TEAL, 0.55 if hot else 0.30), 1), r)
	var word := tr(ADD_SAYS[&"copy"])
	var w := _text_w(_font(), word, 15)
	_text(button, Vector2((button.size.x - w) * 0.5, ROW_H * 0.5), word, 15, Color(PALE, 0.78))
	if button.has_focus():
		_focus_mark(button)


func _draw_program_row(row: Control, j: int) -> void:
	var list := _list()
	if list == null:
		return
	var n := list.rules.size()
	var r := Rect2(Vector2.ZERO, row.size)
	if j >= n:
		if j == n and not _draft.is_empty():
			return
		if j == n and _library.can_add(_program):
			return
		_dashed_box(row, r, Color(PALE, 0.09), 1.0, 6.0, 6.0)
		if j == n and n < ROWS and _library.programs[_program].on and _library.room() <= 0:
			_text(row, Vector2(CHIP_PAD + 4.0, ROW_H * 0.5), tr(PLACES_FULL) % Library.MOST, 14,
				CAPTION)
		return
	if _drag_from == j:
		_dashed_box(row, r, Color(PALE, 0.30), 1.2, 5.0, 6.0)
		return
	var rule := list.rules[j]
	if rule.inert:
		return
	var acting := _amount(j, ["acting"])
	if acting > 0.0:
		row.draw_style_box(_box_style(Color(LIT, 0.045 * acting), Color(0, 0, 0, 0), 0, 10),
			Rect2(Vector2(-6.0, -4.0), row.size + Vector2(12.0, 8.0)))
	# **The arc** (§3.2): from the last chip to the action, in the row's state --
	# the one it had fading out under the one it has.
	var lay := _chips_of(rule, j == _row)
	var x0 := float(lay["end"]) + ARC_FROM
	var x1 := (lay["action"] as Rect2).position.x - ARC_TO
	var t := _blend(j)
	var now_look := _look_of(j)
	# The look it is fading from: a program row's, only ever a String -- a
	# library row's, left from before a switch of view, is no fade at all.
	var was_look: String = _look_was[j] if j < _look_was.size() and _look_was[j] is String \
		else now_look
	if t < 1.0 and was_look != now_look:
		_draw_arc(row, was_look, x0, x1, 1.0 - t)
		_draw_arc(row, now_look, x0, x1, t)
	else:
		_draw_arc(row, now_look, x0, x1, 1.0)


## **An instinct's arc** (§3.2) from [param x0] to [param x1], as [param look]
## draws it, at [param k] of its light: a lit line and a chevron while it acts, a
## T-bar while held back, a pale T-bar where it never can, and a quiet line and
## head otherwise.
func _draw_arc(row: Control, look: String, x0: float, x1: float, k: float) -> void:
	if k <= 0.0:
		return
	var y := ROW_H * 0.5
	var fade := ASLEEP if look == "asleep" else 1.0
	match look:
		"acting":
			row.draw_line(Vector2(x0, y), Vector2(x1, y), Color(LIT, 0.85 * k), 2.0, true)
			row.draw_polyline(PackedVector2Array([Vector2(x1 - 8.0, y - 6.0), Vector2(x1, y),
				Vector2(x1 - 8.0, y + 6.0)]), Color(LIT, 0.95 * k), 2.0, true)
		"held":
			row.draw_line(Vector2(x0, y), Vector2(x1 - 1.0, y), Color(LIT, 0.45 * k), 1.6, true)
			row.draw_line(Vector2(x1, y - 8.0), Vector2(x1, y + 8.0), Color(LIT, 0.80 * k), 2.4,
				true)
		"never":
			row.draw_line(Vector2(x0, y), Vector2(x1 - 1.0, y), Color(PALE, 0.14 * k), 1.2, true)
			row.draw_line(Vector2(x1, y - 8.0), Vector2(x1, y + 8.0), Color(PALE, 0.50 * k), 2.4,
				true)
		_:
			row.draw_line(Vector2(x0, y), Vector2(x1, y), Color(PALE, 0.10 * fade * k), 1.2, true)
			row.draw_polyline(PackedVector2Array([Vector2(x1 - 6.0, y - 5.0), Vector2(x1, y),
				Vector2(x1 - 6.0, y + 5.0)]), Color(PALE, 0.28 * fade * k), 1.5, true)


## **How row [param j] of the open program looks** (§3.2): `acting`, `held`,
## `never`, `failed`, `quiet`, `asleep`, `unread`, or `rest` while the program is
## off.
func _look_of(j: int) -> String:
	var list := _list()
	if list == null or j >= list.rules.size():
		return "rest"
	var rule := list.rules[j]
	if rule.inert:
		return "unread"
	if not _awake(rule):
		return "asleep"
	if not _library.programs[_program].on:
		return "rest"
	var k := _library.merged_index(_program, j)
	var blocker := _never[k] if k >= 0 and k < _never.size() else -1
	var state := _state_at(k)
	if blocker >= 0 and state != Rulebook.State.ACTED:
		return "never"
	match state:
		Rulebook.State.ACTED:
			return "acting"
		Rulebook.State.HELD:
			return "held"
		Rulebook.State.FAILED:
			return "failed"
		Rulebook.State.QUIET:
			return "quiet"
		Rulebook.State.ASLEEP:
			return "asleep"
		Rulebook.State.UNREAD:
			return "unread"
	return "rest"


func _draw_sense(button: Button, j: int) -> void:
	if _view != View.PROGRAM or _drag_from == j:
		return
	var list := _list()
	var r := Rect2(Vector2.ZERO, button.size)
	var selected := j == _row and _part == 0 and not _asking
	var hot := button.is_hovered()
	if list != null and j < list.rules.size():
		var rule := list.rules[j]
		if rule.inert:
			# **A rule this version cannot read** (§3.2): one wide chip, its line.
			var box := _box_style(Color(FILL, 0.40 * ASLEEP), Color(PALE, 0.16 * ASLEEP), 1)
			if selected:
				box = _box_style(SELECTED, SELECT, 2)
			button.draw_style_box(box, r)
			_text(button, Vector2(CHIP_PAD, ROW_H * 0.5), _trimmed(_font(), rule.text, 14,
				button.size.x - 2.0 * CHIP_PAD), 14, Color(PALE, 0.78 * ASLEEP))
			if button.has_focus():
				_focus_mark(button)
			return
		var fade := lerpf(1.0, ASLEEP, _amount(j, ["asleep"]))
		var lit := _amount(j, ["acting", "held"])
		var hue := part_hue(rule.input)
		_chip_box(button, r, hue, lit, selected, fade, hot)
		var failed := _amount(j, ["failed"])
		if failed > 0.0 and not selected and rule.input != Rulebook.ALWAYS:
			button.draw_style_box(_box_style(Color(0, 0, 0, 0), Color(hue, 0.60 * failed), 1), r)
		draw_part_glyph(button, rule.input, Vector2(CHIP_PAD + 10.0, ROW_H * 0.5),
			lerpf(0.60, 0.95, lit) * fade)
		_text(button, Vector2(CHIP_PAD + GLYPH_W, ROW_H * 0.5), ProgramWords.says(rule.input),
			15, Color(PALE, (0.95 if selected else lerpf(0.80, 0.95, lit)) * fade))
	else:
		# **A half-built instinct's sense** (§3.4): picked, or a dashed blank.
		var input: StringName = _draft.get("input", &"")
		if input == &"":
			_dashed_box(button, r, Color(SELECT, 0.85) if selected else Color(PALE, 0.30),
				2.0 if selected else 1.2, 5.0, 6.0)
		else:
			_chip_box(button, r, part_hue(input), 0.0, selected, 1.0, hot)
			draw_part_glyph(button, input, Vector2(CHIP_PAD + 10.0, ROW_H * 0.5), 0.60)
			_text(button, Vector2(CHIP_PAD + GLYPH_W, ROW_H * 0.5), ProgramWords.says(input),
				15, Color(PALE, 0.80))
	if button.has_focus():
		_focus_mark(button)


func _draw_test(button: Button, j: int, t: int) -> void:
	var list := _list()
	if _view != View.PROGRAM or list == null or j >= list.rules.size() or _drag_from == j:
		return
	var rule := list.rules[j]
	if t >= rule.clauses.size():
		return
	var fade := lerpf(1.0, ASLEEP, _amount(j, ["asleep"]))
	var lit := _amount(j, ["acting", "held"])
	var selected := j == _row and _part == t + 1
	var r := Rect2(Vector2.ZERO, button.size)
	var box: StyleBoxFlat
	if selected:
		box = _box_style(SELECTED, SELECT, 2)
	else:
		var edge := Color(PALE, 0.16).lerp(Color(LIT, 0.55), lit)
		if button.is_hovered():
			edge.a = minf(edge.a + 0.25, 0.95)
		box = _box_style(Color(FILL, lerpf(0.40, 0.62, lit) * fade), Color(edge, edge.a * fade), 1)
	button.draw_style_box(box, r)
	var said := ProgramWords.test_text(rule.clauses[t])
	var w := _text_w(_font(), said, 14)
	_text(button, Vector2((button.size.x - w) * 0.5, ROW_H * 0.5), said, 14,
		Color(PALE, (0.95 if selected else lerpf(0.78, 0.95, lit)) * fade))
	if button.has_focus():
		_focus_mark(button)


func _draw_add_test(button: Button, _j: int) -> void:
	var r := Rect2(Vector2.ZERO, button.size)
	var selected := _part == PART_ADD_TEST
	_dashed_box(button, r, SELECT if selected else Color(PALE, 0.42 if button.is_hovered() \
		else 0.26), 2.0 if selected else 1.0, 4.0, 6.0)
	_plus(button, r.get_center(), Color(PALE, 0.70 if selected else 0.42))
	if button.has_focus():
		_focus_mark(button)


func _draw_action(button: Button, j: int) -> void:
	if _view != View.PROGRAM or _drag_from == j:
		return
	var list := _list()
	var r := Rect2(Vector2.ZERO, button.size)
	var selected := j == _row and _part == PART_ACTION
	var hot := button.is_hovered()
	if list != null and j < list.rules.size():
		var rule := list.rules[j]
		var fade := lerpf(1.0, ASLEEP, _amount(j, ["asleep"]))
		var lit := _amount(j, ["acting"])
		_chip_box(button, r, part_hue(rule.output), lit, selected, fade, hot)
		draw_part_glyph(button, rule.output, Vector2(CHIP_PAD + 10.0, ROW_H * 0.5),
			lerpf(0.60, 0.95, lit) * fade)
		_text(button, Vector2(CHIP_PAD + GLYPH_W, ROW_H * 0.5), ProgramWords.action_text(rule),
			15, Color(PALE, (0.95 if selected else lerpf(0.80, 0.95, lit)) * fade))
	else:
		var output: StringName = _draft.get("output", &"")
		if output == &"":
			_dashed_box(button, r, Color(SELECT, 0.85) if selected else Color(PALE, 0.30),
				2.0 if selected else 1.2, 5.0, 6.0)
		else:
			_chip_box(button, r, part_hue(output), 0.0, selected, 1.0, hot)
			draw_part_glyph(button, output, Vector2(CHIP_PAD + 10.0, ROW_H * 0.5), 0.60)
			_text(button, Vector2(CHIP_PAD + GLYPH_W, ROW_H * 0.5), ProgramWords.says(output),
				15, Color(PALE, 0.80))
	if button.has_focus():
		_focus_mark(button)


## **A sense's or an action's box** (§3.3 of the landed spec): at rest, lit or
## selected; hovered, its edge brighter.
func _chip_box(node: CanvasItem, r: Rect2, hue: Color, lit: float, selected: bool, fade: float,
		hot: bool) -> void:
	var box: StyleBoxFlat
	if selected:
		box = _box_style(SELECTED, SELECT, 2)
	else:
		var edge := minf(0.38 + (0.25 if hot else 0.0), 0.95)
		var rest_fill := Color(FILL, 0.55 * fade)
		var lit_fill := Color(FILL, 0.70).lerp(Color(hue, 0.70), 0.16)
		box = _box_style(rest_fill.lerp(lit_fill, lit),
			Color(hue, edge * fade).lerp(Color(hue, 0.85), lit), 1)
	node.draw_style_box(box, r)


## **The keyboard's mark** (§3.3 of the landed spec): the strand's underline --
## for the keyboard's focus only. A press gives the control it lands on a hidden
## focus, and an underline there would double a selected row's own edge; the
## pause screen's theme buttons hide that focus too.
func _focus_mark(node: Control) -> void:
	if not node.has_focus(true):
		return
	node.draw_line(Vector2(14.0, 44.0), Vector2(node.size.x - 14.0, 44.0), SELECT, 2.0, true)


# --- Parts: their hue and their mark --------------------------------------------------

## **The organ that reports or does [param part]**, as the key it is drawn as: a
## gene's own -- its organ's first key, whichever variant a body wears
## (catalogue.gd's `first_key`) -- the cirrus for a turn and the flagellum for a
## swim ([constant BODY_STATS]), or &"" for the cell's own and `always`.
static func organ_of(part: StringName) -> StringName:
	if BODY_STATS.has(part):
		return Catalogue.first_provider(BODY_STATS[part])
	var vocab := FoodField.vocabulary()
	var owner := &""
	if vocab.inputs.has(part):
		owner = (vocab.inputs[part] as Rulebook.InputDecl).owner
	elif vocab.outputs.has(part):
		owner = (vocab.outputs[part] as Rulebook.OutputDecl).owner
	if owner == &"" or FoodField.everybody().has(owner):
		return &""
	return Catalogue.first_key(owner)


## Whether [param part] is the one that holds the tail still: a gene's part its
## organ declares as [constant HOLD_PART].
static func _holds_tail(part: StringName) -> bool:
	return Rulebook.part_of(part) == HOLD_PART and organ_of(part) != &""


## **A part's hue**: its organ's, the cell's own for the body's and the
## metabolism's parts, and `always`'s own teal.
static func part_hue(part: StringName) -> Color:
	if part == Rulebook.ALWAYS:
		return ALWAYS_EDGE
	var organ := organ_of(part)
	return Cilia.hue(organ) if organ != &"" else Cilia.SELF_TINT


## **A part's mark, small, about [param at]** (§3.2): its organ as the genome
## page draws a tile; the hold's own mark for a part that holds the tail; the
## cell's egg for the body's and the metabolism's own; nothing for `always`.
static func draw_part_glyph(node: CanvasItem, part: StringName, at: Vector2, alpha: float) -> void:
	if part == Rulebook.ALWAYS or part == &"":
		return
	if _holds_tail(part):
		_draw_hold_glyph(node, at, alpha)
		return
	var organ := organ_of(part)
	if organ != &"":
		Cilia.draw_tile_organ(node, organ, 1, at + Vector2(0.0, 7.0), alpha, 0.55)
		return
	var egg := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		var r := 6.6 * (1.0 + 0.16 * cos(a + PI * 0.5))
		egg.append(at + Vector2(sin(a) * r * 0.80, -cos(a) * r))
	node.draw_colored_polygon(egg, Color(Cilia.SELF_TINT, alpha * 0.30))
	node.draw_polyline(egg, Color(Cilia.SELF_TINT, alpha * 0.95), 1.4, true)


## **The hold's mark at a chip's size** (§3.3): a 19 px stroke of the tail dying
## to flat, running into a 14 px bar, in the flagellum's hue -- the hold pad's.
static func _draw_hold_glyph(node: CanvasItem, at: Vector2, alpha: float) -> void:
	var tone := Color(ControlsNode.HOLD_HUE, alpha)
	var span := 19.0
	var from := at.x - 12.0
	var points := PackedVector2Array()
	for i in 17:
		var u := float(i) / 16.0
		var swing := 1.0 - clampf(u / 0.62, 0.0, 1.0)
		points.append(Vector2(from + u * span, at.y + sin(u * 1.25 * TAU) * 3.2 * swing))
	node.draw_polyline(points, tone, 1.8, true)
	var bar := from + span + 3.0
	node.draw_line(Vector2(bar, at.y - 7.0), Vector2(bar, at.y + 7.0), tone, 2.2, true)


# --- The head (§2.1, §3.1, §7.1) -----------------------------------------------------

func _draw_head() -> void:
	var font := _font()
	var title := tr(TITLE) if _view == View.LIBRARY else _library.name_of(_program)
	var title_w := _text_w(font, title, 16)
	_text(_head, Vector2(0.0, HEAD_H * 0.5), title, 16, Color(PALE, 0.80))
	var note_x := title_w + 16.0
	if _view == View.PROGRAM:
		note_x = _head_switch.position.x + SWITCH_W + 16.0
	var note := _head_note()
	var right := _rows_w
	if _view == View.LIBRARY and _library.size() > 0:
		right = _draw_places() - 16.0
	_text(_head, Vector2(note_x, HEAD_H * 0.5), _trimmed(font, note[0], 15, right - note_x), 15,
		note[1])


## **The head's line** (§7.1), in its order of priority, and its tint.
func _head_note() -> Array:
	if bool(_run.call(&"_session_up")):
		if bool(_run.get(&"_cell").get(&"autopilot")):
			return [tr(POND_ON_NOTE), WARN]
		# The pause screen's own warning, said there already.
		return [tr("the water is still moving · you can still be eaten"), WARN]
	if _view == View.PROGRAM:
		if not _library.programs[_program].on:
			return [tr(OFF_NOTE), CAPTION]
		return [tr(PROGRAM_NOTE), CAPTION]
	return [tr(LIBRARY_NOTE), CAPTION]


## **The places** (row 39, §2.8): `6 of 8`, then eight slots, the selected
## program's bright, right-aligned to the head. Returns where they begin.
func _draw_places() -> float:
	var slots_w := PLACE.x * Library.MOST + PLACE_GAP * (Library.MOST - 1)
	var x0 := _rows_w - slots_w
	var y := (HEAD_H - PLACE.y) * 0.5
	var k := 0
	for i in _library.size():
		var one: Library.Program = _library.programs[i]
		if not one.on:
			continue
		for line in one.lines.size():
			if k >= Library.MOST:
				break
			var box := _box_style(Color(LIT, 0.95 if i == _program else 0.40), Color(0, 0, 0, 0),
				0, 3)
			_head.draw_style_box(box, Rect2(Vector2(x0 + k * (PLACE.x + PLACE_GAP), y), PLACE))
			k += 1
	for free in range(k, Library.MOST):
		var box := _box_style(Color(0, 0, 0, 0), Color(PALE, 0.30), 1, 3)
		_head.draw_style_box(box, Rect2(Vector2(x0 + free * (PLACE.x + PLACE_GAP), y), PLACE))
	var said := tr(PLACES) % [_library.taken(), Library.MOST]
	var w := _text_w(_font(), said, 14)
	_text(_head, Vector2(x0 - 8.0 - w, HEAD_H * 0.5), said, 14, CAPTION)
	return x0 - 8.0 - w


# --- The lines under the rows (§2.4, §3.2, §7.1) ----------------------------------------

func _say_lines() -> void:
	if _library == null or _ex_name == null:
		return
	var explain := _explained()
	_ex_name.text = explain[0]
	_ex_name.add_theme_color_override(&"font_color", explain[1])
	_ex_says.text = explain[2]
	_ex_says.visible = explain[2] != ""
	_hint.text = _said if _said != "" else _hint_now()
	_act.text = _act_now()


## **`Explain`**: `[name, its tint, what follows]` -- what the mouse or the keys
## are on, else what is selected.
func _explained() -> Array:
	if _ap_hot:
		return _split(tr(AUTOPILOT_EXPLAINS), LIT)
	if _view == View.LIBRARY:
		if _library.size() == 0 or _program >= _library.size():
			return ["", PALE, ""]
		return [_library.name_of(_program), Color(PALE, 0.95), "· " + _place_text(_program)]
	var at: Array = _hover if not _hover.is_empty() else [_row, _part]
	var part := _part_at(int(at[0]), int(at[1]))
	if part == &"":
		return ["", PALE, ""]
	var said := ProgramWords.explains(part)
	if said == "":
		return [ProgramWords.says(part), part_hue(part).lerp(PALE, 0.25), ""]
	return _split(said, part_hue(_hue_part(int(at[0]), int(at[1]), part)).lerp(PALE, 0.25))


## A sentence `word · what it is` as `[word, tint, "· what it is"]`.
func _split(said: String, tint: Color) -> Array:
	var at := said.find(" · ")
	if at < 0:
		return ["", tint, said]
	return [said.substr(0, at), Color(tint, 0.95), said.substr(at + 1)]


## **The part at row [param j], part [param part]**: an input, an output or a
## test's value -- or &"" for none.
func _part_at(j: int, part: int) -> StringName:
	var list := _list()
	if list == null:
		return &""
	if j >= list.rules.size():
		if _draft.is_empty() or j != list.rules.size():
			return &""
		return StringName(_draft.get("input" if part == 0 else "output", &""))
	var rule := list.rules[j]
	if rule.inert:
		return &""
	if part == 0:
		return rule.input
	if part == PART_ACTION:
		return rule.output
	if part >= 1 and part <= rule.clauses.size():
		return rule.clauses[part - 1].value
	return &""


## Which part a value's tint follows: its sense's.
func _hue_part(j: int, part: int, found: StringName) -> StringName:
	if part >= 1:
		var list := _list()
		if list != null and j < list.rules.size():
			return list.rules[j].input
	return found


## **Where program [param i] runs** (§2.4): its place among the programs that are
## on.
func _place_text(i: int) -> String:
	var one: Library.Program = _library.programs[i]
	if one.lines.is_empty():
		return tr(PLACE_SAYS[&"empty"])
	if not one.on:
		return tr(PLACE_SAYS[&"off"])
	var on: Array[int] = []
	for k in _library.size():
		if _library.programs[k].on and not _library.programs[k].lines.is_empty():
			on.append(k)
	if on.size() == 1:
		return tr(PLACE_SAYS[&"only"])
	var at := on.find(i)
	if at == 0:
		return tr(PLACE_FIRST) % on.size()
	if at == on.size() - 1:
		return tr(PLACE_LAST) % _quoted_name(on[at - 1])
	return tr(PLACE_MIDDLE) % [_quoted_name(on[at - 1]), _quoted_name(on[at + 1])]


## **`Hint`**, when no tap has said anything: in the library the live hold, else a
## column that can never act; in a program the selected row's state.
func _hint_now() -> String:
	if _view == View.LIBRARY:
		return _library_hint()
	var list := _list()
	if list == null:
		return ""
	if _row >= list.rules.size():
		return tr(STATE_HINTS[&"half"]) if not _draft.is_empty() else ""
	var rule := list.rules[_row]
	match _look_of(_row):
		"acting":
			return tr(STATE_HINTS[&"acting"])
		"held":
			var k := _library.merged_index(_program, _row)
			var by := _held_by(k)
			return _held_line(by, false)
		"never":
			var k := _library.merged_index(_program, _row)
			return _never_line(_never[k])
		"failed":
			return tr(WAITING_SAYS[&"failed"]) % ProgramWords.says(rule.input)
		"quiet":
			return tr(WAITING_SAYS[&"quiet"]) % ProgramWords.says(rule.input)
		"asleep":
			return _asleep_line(rule)
		"unread":
			return tr(STATE_HINTS[&"unread"])
	return ""


## The line for an instinct held back by merged rule [param by]: in this program,
## or naming the program above.
func _held_line(by: int, now: bool) -> String:
	var blocker := _merged_rule(by)
	var verb := tr(ALREADY[_verb_of(blocker)])
	var owner := _library.owner_of(by).x
	if owner == _program and not now:
		return tr(HELD) % verb
	return tr(HELD_NOW if now else HELD_BY) % [_quoted_name(owner), verb]


## The line for an instinct that never acts because of merged rule [param by].
func _never_line(by: int) -> String:
	var blocker := _merged_rule(by)
	var verb := tr(ALWAYS_DOES[_verb_of(blocker)])
	var owner := _library.owner_of(by).x
	if owner == _program:
		return tr(NEVER) % verb
	return tr(NEVER_BY) % [_quoted_name(owner), verb]


## **Why an instinct sleeps**: its part waits for its organ's copies, or the body
## does not wear what it needs.
func _asleep_line(rule: Rulebook.Rule) -> String:
	for part: StringName in [rule.output, rule.input]:
		var decl: Variant = _vocab.inputs.get(part, _vocab.outputs.get(part, null))
		if decl == null:
			continue
		var bit := int(decl.get(&"bit"))
		if (bit & _worn) == bit:
			continue
		var level_words := ProgramWords.asleep(part)
		if int(decl.get(&"level")) > 1 and level_words != "" \
				and (int(_vocab.owners.get(decl.get(&"owner"), 0)) & _worn) != 0:
			return level_words
		return tr(ASLEEP_SAYS) % ProgramWords.says(part)
	return ""


func _library_hint() -> String:
	if _library.size() == 0 or _program >= _library.size():
		return ""
	var i := _program
	var one: Library.Program = _library.programs[i]
	if not one.on:
		return ""
	# A live hold first: one of its instincts held back by a program above --
	# unless what holds it is the very `always` that means it can never act.
	# Then the line that cannot change is the one to give, and it agrees with
	# the inspector's `never` (automation-ux.md §2.4).
	for j in one.lines.size():
		var k := _library.merged_index(i, j)
		if _state_at(k) == Rulebook.State.HELD:
			var by := _held_by(k)
			if by >= 0 and k < _never.size() and _never[k] == by:
				continue
			if by >= 0 and _library.owner_of(by).x != i:
				return _held_line(by, true)
	# Then what cannot change: a trigger it can never move.
	var marks := _program_columns(i)
	for c in COLUMNS.size():
		if marks[c] != "never":
			continue
		var list := _library.list_of(i, _vocab)
		for j in list.rules.size():
			if not _columns_of(list.rules[j]).has(c):
				continue
			var k := _library.merged_index(i, j)
			var by := _never[k] if k < _never.size() else -1
			if by < 0:
				continue
			return tr(NEVER_MOVES) % [_quoted_name(i), tr(TRIGGER_SAYS[COLUMNS[c]], &"trigger"),
				_quoted_name(_library.owner_of(by).x), tr(ALWAYS_DOES[_verb_of(_merged_rule(by))])]
	return ""


func _act_now() -> String:
	if _view == View.LIBRARY:
		if _drag_from >= 0:
			return tr(ACT_SAYS[&"stay"] if _drag_stays() else ACT_SAYS[&"library_drag"])
		if _library.size() == 0:
			return tr(ACT_SAYS[&"library_empty"])
		return tr(ACT_SAYS[&"library"])
	if _drag_from >= 0:
		return tr(ACT_SAYS[&"stay"] if _drag_stays() else ACT_SAYS[&"program_drag"])
	var lines := _lines_of(_program)
	if lines.is_empty() and _draft.is_empty():
		return tr(ACT_SAYS[&"program_empty"])
	if _row >= lines.size():
		if _draft.is_empty():
			return tr(ACT_SAYS[&"program"])
		return tr(ACT_SAYS[&"action"] if _part == PART_ACTION else ACT_SAYS[&"sense"])
	match _part:
		0:
			return tr(ACT_SAYS[&"sense"])
		PART_ACTION:
			return tr(ACT_SAYS[&"action"])
		PART_ADD_TEST:
			return tr(ACT_SAYS[&"test"])
	return tr(ACT_SAYS[&"test"])


# --- Changing the library --------------------------------------------------------------

## **The library changed under the page**: the run merges again, the instincts
## take it at their next tick, and the page says it all again.
func _changed() -> void:
	_run.call(&"_library_changed")
	refresh()


func _on_switch(j: int) -> void:
	if j >= _library.size():
		return
	_select_program(j)
	_flip(j)


func _on_head_switch() -> void:
	_flip(_program)


## **Program [param i] switched** (§2.2): refused when it does not fit the eight,
## and `Hint` says why (row 39).
func _flip(i: int) -> void:
	var one: Library.Program = _library.programs[i]
	if not _library.switch(i, not one.on):
		_said = tr(NO_ROOM_SAYS) % [_quoted_name(i), one.lines.size(), _library.room()]
		_say_lines()
		return
	_said = ""
	_changed()


func _open_from_row(j: int) -> void:
	if j < _library.size():
		open_program(j, _by_keys())


## Whether what was just pressed was pressed by a key -- `Enter` or `Space`, or a
## pad's accept -- so the keyboard follows it into the view it opens. A button's
## `pressed` comes on the key's release, when the accept is no longer down: it was
## just released, in the frame that pressed the button.
func _by_keys() -> bool:
	return Input.is_action_pressed(&"ui_accept") or Input.is_action_just_released(&"ui_accept")


func _on_body_key(event: InputEvent, j: int) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_bodies[j].accept_event()
		if j < _library.size():
			open_program(j, true)
		return
	if key.shift_pressed and (key.keycode == KEY_UP or key.keycode == KEY_DOWN):
		_bodies[j].accept_event()
		var to := j + (-1 if key.keycode == KEY_UP else 1)
		if to < 0 or to >= _library.size():
			return
		_library.move(j, to)
		_program = to
		_changed()
		_bodies[to].grab_focus()


func _on_chip_key(event: InputEvent, j: int) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if not key.shift_pressed or (key.keycode != KEY_UP and key.keycode != KEY_DOWN):
		return
	get_viewport().set_input_as_handled()
	var lines := _lines_of(_program)
	var to := j + (-1 if key.keycode == KEY_UP else 1)
	if j >= lines.size() or to < 0 or to >= lines.size():
		return
	_move_line(j, to)
	_row = to
	refresh()
	var target := _selected_button()
	if target != null:
		target.grab_focus()


## **An add row pressed**: a new program in the library, a half-built instinct
## in a program.
func _on_add(j: int) -> void:
	if _view == View.LIBRARY:
		var at := _library.add_new()
		if at < 0:
			return
		# **A new program opens with its add row selected** (§2.5).
		_run.call(&"_library_changed")
		open_program(at)
		return
	if not _library.can_add(_program):
		return
	_draft = {"input": &"", "output": &""}
	_row = j
	_part = 0
	_said = ""
	refresh()
	var target := _selected_button()
	if target != null:
		target.grab_focus()


func _on_copy_founders() -> void:
	var at := _library.add_founders()
	if at < 0:
		return
	_program = at
	_said = ""
	_changed()
	_bodies[at].grab_focus()


## **A drag begins** (§2.6, §4.5): a program from any part of its row, an
## instinct from any of its chips. Rows never move during it.
func _get_drag(at: Vector2, j: int) -> Variant:
	if _view == View.LIBRARY:
		if j >= _library.size():
			return null
		_select_program(j)
		_drag_from = j
		_drag_gap = j
		set_drag_preview(_pill(at, j))
		_redraw_rows()
		_say_lines()
		return {"programs": j}
	var list := _list()
	if list == null or j >= list.rules.size():
		return null
	_drag_from = j
	_drag_gap = j
	set_drag_preview(_pill(at, j))
	_redraw_rows()
	_say_lines()
	return {"instincts": j}


## **Where a drag would land**, from the pointer over [param on] at [param at] in
## its own coordinates -- the event's own place, which a finger's emulated mouse
## gives and the desktop cursor may not -- as the gap nearest it.
func _can_drop(at: Vector2, data: Variant, on: Control) -> bool:
	if not (data is Dictionary) or _drag_from < 0:
		return false
	_aim_drag(on.get_global_transform() * at)
	return true


func _aim_drag(pointer: Vector2) -> void:
	var count := _library.size() if _view == View.LIBRARY else _lines_of(_program).size()
	var local := _area.get_global_transform().affine_inverse() * pointer
	var gap := clampi(roundi(local.y / (ROW_H + ROW_SEP)), 0, count)
	if not Rect2(Vector2.ZERO, _area.size).grow(12.0).has_point(local):
		gap = -1
	if gap != _drag_gap:
		_drag_gap = gap
		_area.queue_redraw()
		_say_lines()


## **A drag that leaves the rows lands nowhere**, and draws no line: followed
## from every pointer event while one is in flight.
func _input(event: InputEvent) -> void:
	if _drag_from < 0 or not visible:
		return
	if event is InputEventMouseMotion:
		_aim_drag((event as InputEventMouseMotion).position)
	elif event is InputEventScreenDrag:
		_aim_drag((event as InputEventScreenDrag).position)


func _drop(at: Vector2, data: Variant, on: Control) -> void:
	if not (data is Dictionary) or _drag_from < 0:
		return
	# Where the finger let go, which is the drop's own place.
	_aim_drag(on.get_global_transform() * at)
	if _drag_gap < 0:
		return
	var from := _drag_from
	var to := _drag_gap - 1 if _drag_gap > from else _drag_gap
	_drag_from = -1
	_drag_gap = -1
	if to == from:
		refresh()
		return
	if _view == View.LIBRARY:
		_library.move(from, to)
		_program = to
		_changed()
		return
	_move_line(from, to)
	_row = to
	refresh()


func _drag_stays() -> bool:
	return _drag_gap == _drag_from or _drag_gap == _drag_from + 1 or _drag_gap < 0


func _move_line(from: int, to: int) -> void:
	var lines := _lines_of(_program).duplicate()
	var line := lines[from]
	lines.remove_at(from)
	lines.insert(to, line)
	_set_lines(lines)


## **The program in the air** (§2.6): a pill of its switch, name and marks -- or
## the instinct's sense, an arrow and its action -- lifted over the pointer.
func _pill(grab: Vector2, j: int) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := Control.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := 0.0
	if _view == View.LIBRARY:
		var marks := 0
		for mark: String in _program_columns(j):
			marks += 1 if mark != "" else 0
		width = minf(NAME_X + _text_w(_font(), _library.name_of(j), 15) + 24.0
			+ COLUMN_W * marks + 8.0, _rows_w * 0.6)
	else:
		width = _input_w + CHIP_SEP + 36.0 + CHIP_SEP + _output_w
	pill.size = Vector2(width, ROW_H)
	pill.position = Vector2(-minf(maxf(grab.x, 24.0), width * 0.5), -DRAG_LIFT - ROW_H)
	pill.draw.connect(_draw_pill.bind(pill, j))
	holder.add_child(pill)
	return holder


func _draw_pill(pill: Control, j: int) -> void:
	pill.draw_style_box(_box_style(Color(0, 0, 0, 0.40), Color(0, 0, 0, 0), 0, 10),
		Rect2(Vector2(-6.0, 6.0), pill.size + Vector2(12.0, 6.0)))
	if _view == View.LIBRARY:
		if j >= _library.size():
			return
		pill.draw_style_box(_box_style(Color(0.086, 0.204, 0.176, 0.95), Color(LIT, 0.70), 1),
			Rect2(Vector2.ZERO, pill.size))
		draw_switch(pill, _library.programs[j].on, false)
		var name := _library.name_of(j)
		_text(pill, Vector2(NAME_X, ROW_H * 0.5), name, 15, Color(PALE, 0.95))
		var x := NAME_X + _text_w(_font(), name, 15) + 24.0
		var marks := _program_columns(j)
		for c in COLUMNS.size():
			if marks[c] == "":
				continue
			draw_column_mark(pill, c, Vector2(x + COLUMN_W * 0.5, ROW_H * 0.5), 0.90)
			x += COLUMN_W
		return
	var list := _list()
	if list == null or j >= list.rules.size():
		return
	var rule := list.rules[j]
	var r_in := Rect2(Vector2.ZERO, Vector2(_input_w, ROW_H))
	_chip_box(pill, r_in, part_hue(rule.input), 1.0, false, 1.0, false)
	draw_part_glyph(pill, rule.input, Vector2(CHIP_PAD + 10.0, ROW_H * 0.5), 0.95)
	_text(pill, Vector2(CHIP_PAD + GLYPH_W, ROW_H * 0.5), ProgramWords.says(rule.input), 15,
		Color(PALE, 0.95))
	var y := ROW_H * 0.5
	var x0 := _input_w + CHIP_SEP + 2.0
	var x1 := x0 + 32.0
	pill.draw_line(Vector2(x0, y), Vector2(x1, y), Color(PALE, 0.70), 1.6, true)
	pill.draw_polyline(PackedVector2Array([Vector2(x1 - 6.0, y - 5.0), Vector2(x1, y),
		Vector2(x1 - 6.0, y + 5.0)]), Color(PALE, 0.70), 1.6, true)
	var r_out := Rect2(Vector2(x1 + CHIP_SEP + 2.0, 0.0), Vector2(_output_w, ROW_H))
	_chip_box(pill, r_out, part_hue(rule.output), 1.0, false, 1.0, false)
	draw_part_glyph(pill, rule.output, r_out.position + Vector2(CHIP_PAD + 10.0, ROW_H * 0.5),
		0.95)
	_text(pill, r_out.position + Vector2(CHIP_PAD + GLYPH_W, ROW_H * 0.5),
		ProgramWords.action_text(rule), 15, Color(PALE, 0.95))


# --- Changing a program -------------------------------------------------------------------

## **The open program's instincts become [param lines]** -- refused, and said, when
## the eight are full -- and every list made again (§3.7: an edit acts at the next
## tick). [param rebuild] false keeps the inspector as it is, for the ladder being
## dragged.
func _set_lines(lines: PackedStringArray, rebuild := true) -> bool:
	if not _library.set_lines(_program, lines):
		_said = tr(PLACES_FULL) % Library.MOST
		_say_lines()
		return false
	_run.call(&"_library_changed")
	if rebuild:
		refresh()
	else:
		_compute_states()
		_place_rows()
		_say_lines()
		_head.queue_redraw()
	return true


## **An instinct as the page edits it**: its sense, its tests -- `{value, test,
## step, ref, named}` each -- its action and its option.
static func edit_of(rule: Rulebook.Rule) -> Dictionary:
	var clauses: Array = []
	for clause: Rulebook.Clause in rule.clauses:
		clauses.append({"value": clause.value, "test": int(clause.test), "step": clause.step,
			"ref": clause.ref, "named": clause.named})
	return {"input": rule.input, "clauses": clauses, "output": rule.output,
		"option": rule.option}


## **The line an edit writes** (behaviour.md §8): by declared name, as a file keeps
## it -- which `rulebook.gd` reads back as the same instinct (check 16).
static func line_of(edit: Dictionary) -> String:
	var words := PackedStringArray([String(edit["input"])])
	for clause: Dictionary in edit["clauses"]:
		if bool(clause.get("named", true)):
			words.append(String(clause["value"]))
		var test := int(clause["test"])
		words.append(Rulebook.TEST_WORDS[test])
		if test == Rulebook.Test.BELOW or test == Rulebook.Test.ABOVE:
			var ref: StringName = clause.get("ref", &"")
			words.append(String(ref) if ref != &"" else Rulebook.number(float(clause["step"])))
	words.append(Rulebook.ARROW)
	words.append(String(edit["output"]))
	var option := float(edit.get("option", NAN))
	if not is_nan(option):
		words.append(Rulebook.number(option))
	return " ".join(words)


## **A new test on [param value] of [param input]** (§4.3): `below` the ladder's
## middle rung, or smaller than my mouth.
static func new_test(input: Rulebook.InputDecl, value: StringName) -> Dictionary:
	var kind := input.kinds[input.at(value)]
	var clause := {"value": value, "test": int(Rulebook.Test.BELOW), "step": 0.0, "ref": &"",
		"named": value != input.lone()}
	if kind == Rulebook.SIZE:
		clause["ref"] = Rulebook.REFERENCES[0]
	else:
		var rungs := rungs_offered(kind)
		clause["step"] = float(rungs[rungs.size() / 2]) if not rungs.is_empty() else 0.0
	return clause


## **The rungs the page offers a test of [param kind]** (§4.3): the rulebook's
## ladder, or for a size what it is put against. Nothing off a ladder.
static func rungs_offered(kind: StringName) -> Array:
	if kind == Rulebook.SIZE:
		return Rulebook.REFERENCES
	return Rulebook.LADDERS.get(kind, [])


## **What the page offers to pick** (§4.2): whatever the body and the metabolism
## declare, and every part of a gene your DNA carries or your body wears -- in
## [param dna] copies and [param levels], what each worn gene works at --
## `{inputs, outputs}` in the vocabulary's order, the genes' first, `always`
## last; with `carried` (a gene carried and not worn) and `waiting` (a part
## waiting for its organ's level: the level it needs) for the ones that cannot
## act yet.
static func offers(vocab: Rulebook.Vocabulary, dna: Dictionary, levels: Dictionary) -> Dictionary:
	var everybody := FoodField.everybody()
	var genes_in: Array[StringName] = []
	var own_in: Array[StringName] = []
	var genes_out: Array[StringName] = []
	var own_out: Array[StringName] = []
	var carried := {}
	var waiting := {}
	for pair: Array in [[vocab.inputs, genes_in, own_in], [vocab.outputs, genes_out, own_out]]:
		var table: Dictionary = pair[0]
		for name: StringName in table:
			var decl: Variant = table[name]
			var owner: StringName = decl.get(&"owner")
			var level := int(decl.get(&"level"))
			if everybody.has(owner):
				(pair[2] as Array).append(name)
				continue
			var worn := int(levels.get(owner, 0))
			if worn <= 0 and int(dna.get(owner, 0)) <= 0:
				continue
			(pair[1] as Array).append(name)
			if worn <= 0:
				carried[name] = true
			elif worn < level:
				waiting[name] = level
	var inputs: Array[StringName] = []
	inputs.append_array(genes_in)
	inputs.append_array(own_in)
	inputs.append(Rulebook.ALWAYS)
	var outputs: Array[StringName] = []
	outputs.append_array(own_out)
	outputs.append_array(genes_out)
	return {"inputs": inputs, "outputs": outputs, "carried": carried, "waiting": waiting}


## **Every instinct the page can build** (check 16): each sense the vocabulary
## declares, bare and with each test it offers on each value at every rung, and
## each action with each option -- as lines, by the page's own [method line_of].
static func every_instinct(vocab: Rulebook.Vocabulary) -> Array:
	var out: Array = []
	var inputs: Array = [Rulebook.ALWAYS]
	inputs.append_array(vocab.inputs.keys())
	for input_name: StringName in inputs:
		var input := vocab.inputs.get(input_name) as Rulebook.InputDecl
		for output_name: StringName in vocab.outputs:
			var output: Rulebook.OutputDecl = vocab.outputs[output_name]
			if output.needs == Rulebook.BEARING and (input == null or not input.bearing):
				continue
			var options: Array = output.options if not output.options.is_empty() else [NAN]
			for option: float in options:
				out.append(line_of({"input": input_name, "clauses": [], "output": output_name,
					"option": option}))
		if input == null:
			continue
		var action := &"body.turn-random"
		var every: Array = []
		for value: StringName in input.values:
			var kind := input.kinds[input.at(value)]
			for test in 4:
				var rungs: Array = rungs_offered(kind) if test < 2 else [null]
				for rung: Variant in rungs:
					var clause := new_test(input, value)
					clause["test"] = test
					if rung != null and kind == Rulebook.SIZE:
						clause["ref"] = rung
					elif rung != null:
						clause["step"] = float(rung)
					out.append(line_of({"input": input_name, "clauses": [clause],
						"output": action, "option": NAN}))
			every.append(new_test(input, value))
		out.append(line_of({"input": input_name, "clauses": every, "output": action,
			"option": NAN}))
	return out


func _edit_rule(j: int, change: Callable, rebuild := true) -> void:
	var list := _list()
	if list == null or j >= list.rules.size():
		return
	var edit := edit_of(list.rules[j])
	change.call(edit)
	var lines := _lines_of(_program).duplicate()
	lines[j] = line_of(edit)
	_set_lines(lines, rebuild)


## **A sense picked** (§4.2): for an instinct, keeping the tests the new sense can
## carry, matched by value name; for a half-built one, the selection moves to its
## action.
func _pick_input(input: StringName) -> void:
	var lines := _lines_of(_program)
	if _row >= lines.size():
		_draft["input"] = input
		_part = PART_ACTION
		_finish_draft()
		return
	var decl := _vocab.inputs.get(input) as Rulebook.InputDecl
	_edit_rule(_row, func(edit: Dictionary) -> void:
		edit["input"] = input
		var kept: Array = []
		if decl != null:
			for clause: Dictionary in edit["clauses"]:
				var at := decl.at(StringName(clause["value"]))
				if at >= 0 and decl.kinds[at] == _kind_of(StringName(clause["value"])):
					clause["named"] = StringName(clause["value"]) != decl.lone()
					kept.append(clause)
		edit["clauses"] = kept)


## The kind a value has in this vocabulary, by its name.
func _kind_of(value: StringName) -> StringName:
	for input: Rulebook.InputDecl in _vocab.inputs.values():
		var at := input.at(value)
		if at >= 0:
			return input.kinds[at]
	return &""


## **An action picked**: with its first option, for one that takes one.
func _pick_output(output: StringName) -> void:
	var decl := _vocab.outputs.get(output) as Rulebook.OutputDecl
	var option := float(decl.options[0]) if decl != null and not decl.options.is_empty() else NAN
	var lines := _lines_of(_program)
	if _row >= lines.size():
		_draft["output"] = output
		_draft["option"] = option
		if StringName(_draft.get("input", &"")) == &"":
			_part = 0
		_finish_draft()
		return
	_edit_rule(_row, func(edit: Dictionary) -> void:
		edit["output"] = output
		edit["option"] = option)


## **A half-built instinct made whole** once its sense and its action are both
## picked: it runs from the next tick (§3.4).
func _finish_draft() -> void:
	var input: StringName = _draft.get("input", &"")
	var output: StringName = _draft.get("output", &"")
	if input == &"" or output == &"":
		refresh()
		return
	var line := line_of({"input": input, "clauses": [], "output": output,
		"option": float(_draft.get("option", NAN))})
	var lines := _lines_of(_program).duplicate()
	lines.append(line)
	_draft = {}
	if not _set_lines(lines):
		return
	_part = PART_ACTION


func _on_add_test(j: int) -> void:
	var list := _list()
	if list == null or j >= list.rules.size():
		return
	var rule := list.rules[j]
	var decl := _vocab.inputs.get(rule.input) as Rulebook.InputDecl
	if decl == null:
		return
	var free := _untested(rule, decl)
	_row = j
	if free.size() == 1:
		_add_test(free[0])
		return
	# **More than one value untested: the inspector asks which** (§4.3).
	_part = PART_ADD_TEST
	_asking = true
	_said = ""
	_place_rows()
	_build_inspector()
	_say_lines()


func _untested(rule: Rulebook.Rule, decl: Rulebook.InputDecl) -> Array[StringName]:
	var free: Array[StringName] = []
	for value: StringName in decl.values:
		var taken := false
		for clause: Rulebook.Clause in rule.clauses:
			taken = taken or clause.value == value
		if not taken:
			free.append(value)
	return free


func _add_test(value: StringName) -> void:
	var list := _list()
	if list == null or _row >= list.rules.size():
		return
	var decl := _vocab.inputs.get(list.rules[_row].input) as Rulebook.InputDecl
	var at := list.rules[_row].clauses.size()
	_asking = false
	_edit_rule(_row, func(edit: Dictionary) -> void:
		(edit["clauses"] as Array).append(new_test(decl, value)))
	_part = at + 1
	refresh()


func _remove_test() -> void:
	var t := _part - 1
	_edit_rule(_row, func(edit: Dictionary) -> void:
		(edit["clauses"] as Array).remove_at(t))
	_part = 0
	refresh()


func _remove_instinct() -> void:
	var lines := _lines_of(_program)
	if _row >= lines.size():
		_draft = {}
		_part = 0
		refresh()
		return
	var kept := lines.duplicate()
	kept.remove_at(_row)
	_part = 0
	_set_lines(kept)


func _set_compare(test: int) -> void:
	var t := _part - 1
	_edit_rule(_row, func(edit: Dictionary) -> void:
		var clause: Dictionary = (edit["clauses"] as Array)[t]
		var was := int(clause["test"])
		clause["test"] = test
		if (test == Rulebook.Test.BELOW or test == Rulebook.Test.ABOVE) \
				and was != Rulebook.Test.BELOW and was != Rulebook.Test.ABOVE:
			var kind := _kind_of(StringName(clause["value"]))
			var rungs := rungs_offered(kind)
			if kind == Rulebook.SIZE:
				clause["ref"] = Rulebook.REFERENCES[0]
			elif not rungs.is_empty():
				clause["step"] = float(rungs[rungs.size() / 2]))


func _set_rung(index: int, rebuild := true) -> void:
	var t := _part - 1
	_edit_rule(_row, func(edit: Dictionary) -> void:
		var clause: Dictionary = (edit["clauses"] as Array)[t]
		var kind := _kind_of(StringName(clause["value"]))
		var rungs := rungs_offered(kind)
		if rungs.is_empty():
			return
		var rung: Variant = rungs[clampi(index, 0, rungs.size() - 1)]
		if kind == Rulebook.SIZE:
			clause["ref"] = rung
		else:
			clause["step"] = float(rung), rebuild)


func _set_option(option: float) -> void:
	_edit_rule(_row, func(edit: Dictionary) -> void:
		edit["option"] = option)


# --- The inspector (§2.4, §2.7, §3.4, §4) --------------------------------------------------

func _build_inspector() -> void:
	if _inspector == null:
		return
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and _box != null and _box.is_ancestor_of(focused):
		_focus_key = str(focused.get_meta(&"key", ""))
	elif focused != _ladder or _ladder == null:
		_focus_key = ""
	if _box != null:
		_room.remove_child(_box)
		_box.queue_free()
	_ladder = null
	_box = VBoxContainer.new()
	_box.name = "Box"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 8)
	_box.position = Vector2.ZERO
	_box.size = Vector2(INNER, 0.0)
	_room.add_child(_box)
	if _view == View.LIBRARY:
		if _library.size() == 0:
			_legend_inspector(tr(INSPECTOR_SAYS[&"none"]), "", tr(LEGEND_EXPLAINS[&"library"]))
		else:
			_program_inspector()
	else:
		_part_inspector()
	_link_focus()
	if _focus_key != "":
		for node: Node in _box.find_children("*", "Control", true, false):
			if str(node.get_meta(&"key", "")) == _focus_key:
				(node as Control).grab_focus.call_deferred()
				break


func _program_inspector() -> void:
	var i := _program
	var one: Library.Program = _library.programs[i]
	var name := _label(17, Color(PALE, 0.98))
	name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name.text = _library.name_of(i)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(INNER, 0.0)
	_box.add_child(name)
	var state := _label(14, CAPTION)
	state.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	state.text = tr(STATE_SAYS[&"on" if one.on else &"off"]) % _count_text(one.lines.size())
	_box.add_child(state)
	var marks := _program_columns(i)
	for c in COLUMNS.size():
		if marks[c] == "":
			continue
		var line := Control.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.custom_minimum_size = Vector2(INNER, 30.0)
		line.draw.connect(_draw_trigger_line.bind(line, c, marks[c]))
		_box.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(gap)
	var open := _tool_button(tr(BUTTON_SAYS[&"open"]), INNER, "open", true)
	open.pressed.connect(_open_from_row.bind(i))
	_box.add_child(open)
	var pair := HBoxContainer.new()
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_theme_constant_override("separation", 8)
	_box.add_child(pair)
	var rename := _tool_button(tr(BUTTON_SAYS[&"rename"]), CELL_W, "rename")
	rename.pressed.connect(_on_rename)
	pair.add_child(rename)
	var copy := _tool_button(tr(BUTTON_SAYS[&"copy"]), CELL_W, "copy")
	copy.disabled = _library.size() >= Library.LIBRARY_MOST
	copy.pressed.connect(_on_copy)
	pair.add_child(copy)
	var delete := _tool_button(tr(DELETE), INNER, "delete")
	delete.pressed.connect(_on_delete)
	_box.add_child(delete)


## **One line per trigger a program moves** (§2.4): its mark, then where the
## program stands on it -- `steering · first`, `steering · after “flee”`, `tail ·
## never`, `push · asleep` -- or the trigger's word alone for a program off.
func _draw_trigger_line(line: Control, c: int, mark: String) -> void:
	var one: Library.Program = _library.programs[_program]
	var centre := Vector2(12.0, 16.0)
	var word := tr(TRIGGER_SAYS[COLUMNS[c]], &"trigger")
	var said := word
	var ink := EXPLAIN
	if not one.on:
		draw_column_mark(line, c, centre, 0.45)
		ink = Color(PALE, 0.45)
	else:
		match mark:
			"never":
				draw_column_mark(line, c, centre, 0.34)
				_draw_never_bar(line, centre.x, -2.0)
				said += " · " + tr(ORDER_SAYS[&"never"])
				ink = WARN
			"off":
				draw_column_mark(line, c, centre, 0.30)
				said += " · " + tr(ORDER_SAYS[&"asleep"])
			_:
				draw_column_mark(line, c, centre, 0.85)
				var above := _above_on(_program, c)
				said += " · " + (tr(ORDER_SAYS[&"first"]) if above < 0 \
					else tr(ORDER_AFTER) % _quoted_name(above))
	# The word at x 34, clear of the widest mark -- the dash's burst ends about
	# x 28 -- and trimmed at the line's room, the inspector's 264 less that.
	_text(line, Vector2(TRIGGER_WORD_X, 16.0), _trimmed(_font(), said, 14, TRIGGER_LINE_W), 14,
		ink)


## The nearest program above [param i] that is on and moves column [param c], or -1.
func _above_on(i: int, c: int) -> int:
	for k in range(i - 1, -1, -1):
		if not _library.programs[k].on:
			continue
		var list := _library.list_of(k, _vocab)
		for rule: Rulebook.Rule in list.rules:
			if _awake(rule) and _columns_of(rule).has(c):
				return k
	return -1


func _tool_button(word: String, width: float, key: String, main := false) -> Button:
	var button := Button.new()
	button.text = word
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size = Vector2(width, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta(&"key", key)
	button.add_theme_font_size_override(&"font_size", 15)
	var fill := Color(0.086, 0.204, 0.176, 0.80) if main else Color(FILL, 0.35)
	var edge := Color(TEAL, 0.62) if main else Color(TEAL, 0.22)
	var width_px := 2 if main else 1
	var rest := _box_style(fill, edge, width_px)
	var hot := _box_style(fill.lightened(0.06), Color(edge, minf(edge.a + 0.25, 0.95)), width_px)
	var focus := _box_style(Color(0, 0, 0, 0), SELECT, 2)
	var off := _box_style(Color(FILL, 0.20), Color(PALE, 0.08), 1)
	button.add_theme_stylebox_override(&"normal", rest)
	button.add_theme_stylebox_override(&"hover", hot)
	button.add_theme_stylebox_override(&"pressed", hot)
	button.add_theme_stylebox_override(&"hover_pressed", hot)
	button.add_theme_stylebox_override(&"focus", focus)
	button.add_theme_stylebox_override(&"disabled", off)
	var ink := Color(MINT, 0.92) if main else Color(PALE, 0.70)
	for kind: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_focus_color", &"font_hover_pressed_color"]:
		button.add_theme_color_override(kind, ink)
	button.add_theme_color_override(&"font_disabled_color", Color(PALE, 0.25))
	return button


## **The inspector with nothing to edit yet** (§2.7, §3.4): a title, a line, an
## explanation, and your vocabulary read off your own genes.
func _legend_inspector(title: String, caption: String, explanation: String) -> void:
	var head := _label(17, Color(PALE, 0.98))
	head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	head.text = title
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.custom_minimum_size = Vector2(INNER, 0.0)
	_box.add_child(head)
	if caption != "":
		var under := _label(14, CAPTION)
		under.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		under.text = caption
		under.set_meta(&"spare", 1)
		_box.add_child(under)
	var said := _label(14, EXPLAIN)
	said.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	said.text = explanation
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.custom_minimum_size = Vector2(INNER, 0.0)
	said.add_theme_constant_override(&"line_spacing", 0)
	said.set_meta(&"spare", 2)
	_box.add_child(said)
	# **Your whole vocabulary has to fit** under the explanation, in every
	# language, with every organ worn: the legend's rows are as tight as its words.
	_box.add_theme_constant_override("separation", 6)
	var offered := _offers()
	for group: Array in [[tr(LEGEND_SAYS[&"senses"]), offered["inputs"]],
			[tr(LEGEND_SAYS[&"actions"]), offered["outputs"]]]:
		var cap := _label(14, CAPTION)
		cap.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		cap.text = group[0]
		_box.add_child(cap)
		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.custom_minimum_size = Vector2(INNER, 0.0)
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 0)
		for part: StringName in group[1]:
			if (offered["carried"] as Dictionary).has(part):
				continue
			var waits := (offered["waiting"] as Dictionary).has(part)
			var word := ProgramWords.says(part)
			var cell := Control.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var width := _text_w(_font(), word, 15) + 28.0
			if waits:
				width += PIP_GAP + PIP_R * 2.0 + PIP_PITCH * float(GenomeNode.TIER_MAX - 1)
			cell.custom_minimum_size = Vector2(width, 25.0)
			cell.draw.connect(_draw_legend_word.bind(cell, part, word,
				int((offered["waiting"] as Dictionary).get(part, 0))))
			flow.add_child(cell)
		_box.add_child(flow)
	_fit_legend.call_deferred(_box)


## **The vocabulary always shows whole**: where a body wears so many organs that
## a language's words would run past the inspector, the line under the title goes
## first and then the explanation, so what you can sense and do is never cut.
func _fit_legend(box: VBoxContainer) -> void:
	if box != _box or not is_instance_valid(box):
		return
	for spare in [1, 2]:
		if box.get_combined_minimum_size().y <= _room.size.y:
			return
		for child: Node in box.get_children():
			if int(child.get_meta(&"spare", 0)) == spare:
				(child as Control).hide()


func _draw_legend_word(cell: Control, part: StringName, word: String, needs: int) -> void:
	var a := DIMMED if needs > 0 else 1.0
	draw_part_glyph(cell, part, Vector2(10.0, 13.0), 0.85 * a)
	var hue := part_hue(part)
	_text(cell, Vector2(28.0, 12.5), word, 15, Color(hue.lerp(PALE, 0.45), 0.92 * a))
	if needs > 0:
		var x := 28.0 + _text_w(_font(), word, 15) + PIP_GAP + PIP_R
		draw_pips(cell, Vector2(x, 13.0), hue, needs)


## **The genome page's pips for the copies a part needs** (§2.8, §4.2): a disc
## for each, a room dot after them.
static func draw_pips(node: CanvasItem, first: Vector2, hue: Color, copies: int) -> void:
	for i in GenomeNode.TIER_MAX:
		var at := first + Vector2(PIP_PITCH * float(i), 0.0)
		if i < copies:
			node.draw_circle(at, PIP_R, Color(hue, 0.85), true, -1.0, true)
		else:
			node.draw_circle(at, PIP_ROOM_R, Color(PALE, 0.30), true, -1.0, true)


func _offers() -> Dictionary:
	var genome: Node = _run.get(&"_genome")
	var levels := {}
	var tiers: Dictionary = genome.call(&"tiers")
	for gene: StringName in tiers:
		if int(tiers[gene]) > 0:
			levels[gene] = maxi(int(genome.call(&"level_of", gene)), 1)
	return offers(FoodField.vocabulary(), genome.call(&"dna"), levels)


## **The inspector in a program**, by what is selected: the add row's
## explanation, a sense's or an action's choices, a test's editor, or the value
## a new test asks for.
func _part_inspector() -> void:
	var list := _list()
	var lines := _lines_of(_program)
	if list == null:
		return
	var one: Library.Program = _library.programs[_program]
	if _row >= lines.size() and _draft.is_empty():
		_legend_inspector(_library.name_of(_program), tr(LEGEND_SAYS[&"nothing"]) \
			if lines.is_empty() else tr(STATE_SAYS[&"on" if one.on else &"off"])
			% _count_text(lines.size()), tr(LEGEND_EXPLAINS[&"program"]))
		return
	if _row >= lines.size():
		_choices_inspector(StringName(_draft.get("input", &"")),
			StringName(_draft.get("output", &"")), _part == PART_ACTION, null)
		return
	var rule := list.rules[_row]
	if rule.inert:
		_head_line(&"", tr(STATE_HINTS[&"unread"]))
		_remove_button(&"instinct")
		return
	if _asking:
		_value_inspector(rule)
		return
	if _part >= 1 and _part <= rule.clauses.size():
		_test_inspector(rule, rule.clauses[_part - 1])
		return
	_choices_inspector(rule.input, rule.output, _part == PART_ACTION, rule)


## The inspector's head: the part's mark and its word, 17 px, its hue toward
## `PALE` (§4.1).
func _head_line(part: StringName, word: String) -> void:
	var head := Control.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.custom_minimum_size = Vector2(INNER, 28.0)
	head.draw.connect(func() -> void:
		var x := 0.0
		if part != &"" and part != Rulebook.ALWAYS:
			draw_part_glyph(head, part, Vector2(12.0, 14.0), 0.95)
			x = 30.0
		var tint := part_hue(part).lerp(PALE, 0.25) if part != &"" else PALE
		_text(head, Vector2(x, 14.0), _trimmed(_font(), word, 17, INNER - x), 17,
			Color(tint, 0.98)))
	_box.add_child(head)


func _remove_button(what: StringName) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(gap)
	var button := _tool_button(tr(REMOVE_SAYS[what]), INNER, "remove_" + String(what))
	button.pressed.connect(_remove_test if what == &"test" else _remove_instinct)
	_box.add_child(button)


## **A sense's or an action's choices** (§4.2): whatever can be picked, two to a
## row; what cannot fit dimmed and inert, saying why; a carried gene marked; a
## part waiting for its organ's copies dimmed and badged.
func _choices_inspector(input: StringName, output: StringName, outputs: bool,
		rule: Rulebook.Rule) -> void:
	var current := output if outputs else input
	_head_line(current, ProgramWords.says(current) if current != &"" \
		else tr(INSPECTOR_SAYS[&"new"]))
	var offered := _offers()
	var names: Array = offered["outputs"] if outputs else offered["inputs"]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_box.add_child(grid)
	var in_decl := _vocab.inputs.get(input) as Rulebook.InputDecl
	var out_decl := _vocab.outputs.get(output) as Rulebook.OutputDecl
	for part: StringName in names:
		var why := ""
		if outputs:
			var decl := _vocab.outputs.get(part) as Rulebook.OutputDecl
			if decl != null and decl.needs == Rulebook.BEARING and input != &"" \
					and (in_decl == null or not in_decl.bearing):
				why = tr(NEEDS_WHERE) % ProgramWords.says(part)
		elif out_decl != null and out_decl.needs == Rulebook.BEARING:
			var decl := _vocab.inputs.get(part) as Rulebook.InputDecl
			if decl == null or not decl.bearing:
				why = tr(NEEDS_WHERE) % ProgramWords.says(output)
		var needs := int((offered["waiting"] as Dictionary).get(part, 0))
		if needs > 0 and why == "":
			why = ProgramWords.needs(part)
			if why == "":
				why = tr(ASLEEP_SAYS) % ProgramWords.says(part)
		var cell := _blank_button(String(part))
		cell.custom_minimum_size = Vector2(CELL_W, 48.0)
		cell.set_meta(&"key", "choice_" + String(part))
		var carried := (offered["carried"] as Dictionary).has(part)
		cell.draw.connect(_draw_choice.bind(cell, part, part == current, why != "", carried,
			needs))
		_hot_redraw(cell)
		if why != "":
			cell.pressed.connect(_say_why.bind(why))
		elif outputs:
			cell.pressed.connect(_pick_output.bind(part))
		else:
			cell.pressed.connect(_pick_input.bind(part))
		cell.mouse_entered.connect(_hover_explain.bind(part))
		cell.mouse_exited.connect(_set_hover.bind([]))
		grid.add_child(cell)
	# **`push` offers its strength** under the grid when it is the current choice.
	if outputs and out_decl != null and not out_decl.options.is_empty() and rule != null:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		for option: float in out_decl.options:
			var cell := _word_cell(ProgramWords.option_text(option), CELL_W,
				is_equal_approx(option, rule.option), "option_%s" % Rulebook.number(option))
			cell.pressed.connect(_set_option.bind(option))
			row.add_child(cell)
		_box.add_child(row)
	_remove_button(&"instinct")


func _hover_explain(part: StringName) -> void:
	var said := ProgramWords.explains(part)
	if said == "":
		return
	var split := _split(said, part_hue(part).lerp(PALE, 0.25))
	_ex_name.text = split[0]
	_ex_name.add_theme_color_override(&"font_color", split[1])
	_ex_says.text = split[2]
	_ex_says.visible = true


func _say_why(why: String) -> void:
	_said = why
	_say_lines()


func _draw_choice(cell: Button, part: StringName, current: bool, dimmed: bool, carried: bool,
		needs: int) -> void:
	var r := Rect2(Vector2.ZERO, cell.size)
	var hue := part_hue(part)
	var a := DIMMED if dimmed else 1.0
	var hot := cell.is_hovered() and not dimmed
	if carried:
		cell.draw_style_box(_box_style(Color(FILL, 0.40), Color(hue, 0.30), 1), r)
		draw_part_glyph(cell, part, Vector2(19.0, 24.0), 0.40)
		var word := ProgramWords.says(part)
		_text(cell, Vector2(36.0, 24.0), word, 14, Color(PALE, 0.42))
		# The genome's ring pip: carried, not worn.
		cell.draw_arc(Vector2(36.0 + _text_w(_font(), word, 14) + 9.0, 25.0), 3.4, 0.0, TAU, 16,
			Color(hue, 0.85), 1.4, true)
	else:
		if current:
			cell.draw_style_box(_box_style(SELECTED, SELECT, 2), r)
		else:
			cell.draw_style_box(_box_style(Color(FILL, 0.55 * a),
				Color(hue, minf((0.40 + (0.25 if hot else 0.0)) * a, 0.95)), 1), r)
		draw_part_glyph(cell, part, Vector2(19.0, 24.0), 0.90 * a)
		_text(cell, Vector2(36.0, 24.0), _trimmed(_font(), ProgramWords.says(part), 14,
			cell.size.x - 40.0), 14, Color(PALE, 0.90 * a))
	if needs > 0:
		draw_pips(cell, Vector2(cell.size.x - 33.4, 10.0), hue, needs)
	if cell.has_focus():
		_focus_mark(cell)


## A cell with a word: a comparison, a reference, a strength, a value.
func _word_cell(word: String, width: float, current: bool, key: String) -> Button:
	var cell := _blank_button(key)
	cell.custom_minimum_size = Vector2(width, 48.0)
	cell.set_meta(&"key", key)
	cell.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, cell.size)
		if current:
			cell.draw_style_box(_box_style(SELECTED, SELECT, 2), r)
		else:
			var edge := 0.41 if cell.is_hovered() else 0.16
			cell.draw_style_box(_box_style(Color(FILL, 0.50), Color(PALE, edge), 1), r)
		var said := _trimmed(_font(), word, 14, width - 12.0)
		var w := _text_w(_font(), said, 14)
		_text(cell, Vector2((width - w) * 0.5, 24.0), said, 14, Color(PALE, 0.95 if current \
			else 0.80))
		if cell.has_focus():
			_focus_mark(cell))
	_hot_redraw(cell)
	return cell


## **`test what?`** (§4.3): one cell per value not yet tested, three across.
func _value_inspector(rule: Rulebook.Rule) -> void:
	var decl := _vocab.inputs.get(rule.input) as Rulebook.InputDecl
	_head_line(rule.input, tr(INSPECTOR_SAYS[&"value"]))
	var row := HFlowContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("h_separation", 9)
	row.add_theme_constant_override("v_separation", 8)
	row.custom_minimum_size = Vector2(INNER, 0.0)
	for value: StringName in _untested(rule, decl):
		var cell := _word_cell(ProgramWords.says(value), VALUE_W, false, "value_" + String(value))
		cell.pressed.connect(_add_test.bind(value))
		cell.mouse_entered.connect(_hover_explain.bind(value))
		row.add_child(cell)
	_box.add_child(row)


## **A test's editor** (§4.3): the comparison, two by two; the step on its ladder,
## or what a size is put against; and what the sense reports now.
func _test_inspector(rule: Rulebook.Rule, clause: Rulebook.Clause) -> void:
	_head_line(rule.input, "%s · %s" % [ProgramWords.says(rule.input),
		ProgramWords.says(clause.value)])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for test in 4:
		var cell := _word_cell(ProgramWords.compare_text(clause.kind, test), CELL_W,
			test == int(clause.test), "compare_%d" % test)
		cell.pressed.connect(_set_compare.bind(test))
		grid.add_child(cell)
	_box.add_child(grid)
	var stepped := clause.test == Rulebook.Test.BELOW or clause.test == Rulebook.Test.ABOVE
	if stepped and clause.kind == Rulebook.SIZE:
		var refs := HBoxContainer.new()
		refs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		refs.add_theme_constant_override("separation", 8)
		var offered := rungs_offered(Rulebook.SIZE)
		for k in offered.size():
			var cell := _word_cell(ProgramWords.step_text(Rulebook.SIZE, 0.0, offered[k]),
				CELL_W, StringName(offered[k]) == clause.ref, "rung_%d" % k)
			cell.pressed.connect(_set_rung.bind(k))
			refs.add_child(cell)
		_box.add_child(refs)
	elif stepped:
		_ladder = _make_ladder(rule, clause)
		_box.add_child(_ladder)
	var now := _label(14, Color(MINT, 0.62))
	now.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	now.text = tr(NOW) % _reading(rule, clause)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	now.custom_minimum_size = Vector2(INNER, 0.0)
	_box.add_child(now)
	_remove_button(&"test")


## **What the sense reports now, for this test's value** (§4.3 item 3): each
## report's value in the kind's unit, or `nothing`.
func _reading(rule: Rulebook.Rule, clause: Rulebook.Clause) -> String:
	var reports := _reports(rule.input)
	if reports.is_empty():
		return tr(NOTHING)
	var said := PackedStringArray()
	for report: Array in reports:
		if clause.at < 0 or clause.at >= report.size():
			continue
		var value := float(report[clause.at])
		if not is_finite(value):
			said.append(tr(NOT_YET))
		elif clause.kind == Rulebook.SIZE:
			var refs: Dictionary = _instincts.get(&"_refs")
			var ref := float(refs.get(clause.ref, 0.0))
			said.append(ProgramWords.size_text(0 if value < ref else 1, clause.ref))
		else:
			said.append(_value_text(clause.kind, Rulebook.measure(clause.kind, value)))
		if said.size() >= 3:
			break
	return ", ".join(said) if not said.is_empty() else tr(NOTHING)


func _value_text(kind: StringName, value: float) -> String:
	match kind:
		&"level":
			return ProgramWords.step_text(kind, snappedf(value, 0.01), &"")
		&"seconds", &"distance", &"bearing":
			return ProgramWords.step_text(kind, roundf(value), &"")
	return Rulebook.number(snappedf(value, 0.01))


func _reports(input: StringName) -> Array:
	if input == Rulebook.ALWAYS:
		return [[]]
	return _instincts.report(input)


## **The ladder** (§4.3): a rail with a tick per rung, the rung in use under a
## rounded-square knob and its value over it, the two ends quietly, and a
## triangle under the rail for each report. A tap snaps to the nearest rung, a
## drag rung to rung, `←`/`→` step one.
func _make_ladder(rule: Rulebook.Rule, clause: Rulebook.Clause) -> Control:
	var ladder := Control.new()
	ladder.name = "Ladder"
	ladder.custom_minimum_size = Vector2(INNER, 74.0)
	ladder.focus_mode = Control.FOCUS_ALL
	ladder.mouse_filter = Control.MOUSE_FILTER_STOP
	ladder.set_meta(&"key", "ladder")
	var rungs := rungs_offered(clause.kind)
	var at := 0
	for k in rungs.size():
		if is_equal_approx(float(rungs[k]), clause.step):
			at = k
	ladder.set_meta(&"at", at)
	ladder.draw.connect(_draw_ladder.bind(ladder, rule, clause, rungs))
	ladder.gui_input.connect(_on_ladder_input.bind(ladder, rungs))
	for changed: Signal in [ladder.focus_entered, ladder.focus_exited]:
		changed.connect(ladder.queue_redraw)
	return ladder


func _rail_x(k: int, n: int) -> float:
	return lerpf(14.0, INNER - 14.0, float(k) / float(maxi(n - 1, 1)))


func _draw_ladder(ladder: Control, rule: Rulebook.Rule, clause: Rulebook.Clause,
		rungs: Array) -> void:
	var n := rungs.size()
	if n == 0:
		return
	var at := int(ladder.get_meta(&"at", 0))
	var y := 44.0
	ladder.draw_style_box(_box_style(Color(FILL, 0.85), Color(TEAL, 0.35), 1, 3),
		Rect2(Vector2(10.0, y - 3.0), Vector2(INNER - 20.0, 6.0)))
	for k in n:
		var x := _rail_x(k, n)
		var on := k <= at
		ladder.draw_line(Vector2(x, y - 9.0), Vector2(x, y + 9.0),
			Color(LIT if on else PALE, 0.55 if on else 0.25), 2.0, true)
	# What the sense reports now: a triangle under the rail per report.
	for report: Array in _reports(rule.input):
		if clause.at < 0 or clause.at >= report.size():
			continue
		var value := Rulebook.measure(clause.kind, float(report[clause.at]))
		var f := 0.0
		for k in n - 1:
			var a := float(rungs[k])
			var b := float(rungs[k + 1])
			if value >= a and value <= b:
				f = (float(k) + (value - a) / maxf(b - a, 0.0001)) / float(n - 1)
		if value > float(rungs[n - 1]):
			f = 1.0
		var nx := lerpf(14.0, INNER - 14.0, f)
		ladder.draw_colored_polygon(PackedVector2Array([Vector2(nx, y + 17.0),
			Vector2(nx - 5.0, y + 25.0), Vector2(nx + 5.0, y + 25.0)]), Color(LIT, 0.85))
	var kx := _rail_x(at, n)
	ladder.draw_style_box(_box_style(Color(0.086, 0.204, 0.176, 1.0), SELECT, 2, 6),
		Rect2(Vector2(kx - 12.0, y - 14.0), Vector2(24.0, 28.0)))
	var label := ProgramWords.step_text(clause.kind, float(rungs[at]), &"")
	var lw := _text_w(_font(), label, 15)
	_text(ladder, Vector2(clampf(kx - lw * 0.5, 0.0, INNER - lw), 11.0), label, 15,
		Color(PALE, 0.95))
	if at != 0:
		_text(ladder, Vector2(0.0, 11.0), ProgramWords.step_text(clause.kind, float(rungs[0]),
			&""), 12, Color(PALE, 0.40))
	if at != n - 1:
		var hi := ProgramWords.step_text(clause.kind, float(rungs[n - 1]), &"")
		_text(ladder, Vector2(INNER - _text_w(_font(), hi, 12), 11.0), hi, 12, Color(PALE, 0.40))
	if ladder.has_focus():
		ladder.draw_line(Vector2(14.0, 72.0), Vector2(INNER - 14.0, 72.0), SELECT, 2.0, true)


func _on_ladder_input(event: InputEvent, ladder: Control, rungs: Array) -> void:
	var n := rungs.size()
	if n == 0:
		return
	var at := int(ladder.get_meta(&"at", 0))
	var to := at
	if event is InputEventKey and event.is_pressed():
		var key := event as InputEventKey
		if key.keycode == KEY_LEFT:
			to = at - 1
		elif key.keycode == KEY_RIGHT:
			to = at + 1
		else:
			return
		ladder.accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		ladder.accept_event()
		if not click.pressed:
			# The drag's last rung is kept: the inspector is said again, once.
			_build_inspector()
			return
		to = _nearest_rung(click.position.x, n)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		ladder.accept_event()
		to = _nearest_rung(motion.position.x, n)
	else:
		return
	to = clampi(to, 0, n - 1)
	if to == at:
		return
	ladder.set_meta(&"at", to)
	ladder.queue_redraw()
	_set_rung(to, false)


func _nearest_rung(x: float, n: int) -> int:
	var best := 0
	for k in n:
		if absf(_rail_x(k, n) - x) < absf(_rail_x(best, n) - x):
			best = k
	return best


# --- The sheets (§2.5) ---------------------------------------------------------------

func _corner() -> Node:
	return _run.get(&"_corner") if _run != null else null


func _on_rename() -> void:
	var corner := _corner()
	if corner == null or _program >= _library.size():
		return
	var i := _program
	corner.call(&"open_naming_for", tr(RENAME_TITLE), _library.name_of(i),
		Library.default_name(_library.programs[i].auto), func(typed: String) -> void:
			_library.rename(i, typed)
			_focus_key = "rename"
			_changed())


func _on_copy() -> void:
	var at := _library.copy(_program)
	if at < 0:
		return
	_program = at
	_changed()


func _on_delete() -> void:
	var corner := _corner()
	if corner == null or _program >= _library.size():
		return
	var i := _program
	var n := _library.programs[i].lines.size()
	# TRANSLATORS: Under "delete <name>?", in 17 px type, wrapping: the program's
	# instincts are deleted with it; %d is how many. A full sentence.
	var line := tr(GONE_EMPTY) if n == 0 \
		else tr_n("its %d instinct is gone for good.", "its %d instincts are gone for good.", n) % n
	corner.call(&"open_confirm_for", _library.name_of(i), line, func() -> void:
		_library.delete(i)
		_program = clampi(i, 0, maxi(_library.size() - 1, 0))
		_changed()
		_focus_selected())


# --- Resume and the autopilot's copy (§5.3) ---------------------------------------------

func _on_resume() -> void:
	_run.call(&"_toggle_pause")


func _on_autopilot() -> void:
	if not _library.runnable():
		_said = tr(AUTOPILOT_SAYS[&"dead"])
		_say_lines()
		return
	_run.call(&"_toggle_autopilot")
	var on := bool(_run.get(&"_cell").get(&"autopilot"))
	if on:
		_said = tr(AUTOPILOT_SAYS[&"pond" if bool(_run.call(&"_session_up")) else &"on"])
	else:
		_said = tr(AUTOPILOT_SAYS[&"off"])
	_head.queue_redraw()
	_say_lines()


func _set_autopilot_hot(hot: bool) -> void:
	if _ap_hot == hot:
		return
	_ap_hot = hot
	_autopilot.queue_redraw()
	_say_lines()


func _draw_page_autopilot() -> void:
	var cell: Node = _run.get(&"_cell") if _run != null else null
	var on := cell != null and bool(cell.get(&"autopilot"))
	draw_autopilot(_autopilot, on, _ap_hot and _library.runnable(), 0.0, 0.0,
		not _library.runnable())


# --- Drawing helpers --------------------------------------------------------------------

## [param text] at [param size], its left at x and its middle at y of [param at].
func _text(node: CanvasItem, at: Vector2, text: String, font_size: int, ink: Color) -> void:
	var font := _font()
	var base := at.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	node.draw_string(font, Vector2(at.x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
		ink)


## [param text] cut to [param room] px with an ellipsis.
static func _trimmed(font: Font, text: String, font_size: int, room: float) -> String:
	if room <= 0.0:
		return ""
	if _text_w(font, text, font_size) <= room:
		return text
	var kept := text
	while kept.length() > 0 and _text_w(font, kept + "…", font_size) > room:
		kept = kept.left(kept.length() - 1)
	return kept.strip_edges(false, true) + "…"


func _plus(node: CanvasItem, at: Vector2, ink: Color) -> void:
	node.draw_line(at + Vector2(-6.0, 0.0), at + Vector2(6.0, 0.0), ink, 2.0, true)
	node.draw_line(at + Vector2(0.0, -6.0), at + Vector2(0.0, 6.0), ink, 2.0, true)


func _dashed_box(node: CanvasItem, rect: Rect2, ink: Color, width: float, dash: float,
		radius: float) -> void:
	_dashed_rounded(node, rect, ink, width, dash, radius)


## **The autopilot's icon, on [param node]'s whole rect** (UX §5.1): the well, at
## rest or lit, and the glyph -- a sense, its nerve, and a chevron while
## [param on], a T-bar while off. [param hot] is the mouse over it or a press;
## [param fall] how much of the lit well a takeover has left, 1 to 0;
## [param breath] the one breath, 0 to 1. [param disabled] is the page's copy
## while nothing can run: no fill, a dashed outline, the glyph faint. Static, so
## the page and the replay draw the very same picture.
static func draw_autopilot(node: Control, on: bool, hot: bool, fall: float = 0.0,
		breath: float = 0.0, disabled: bool = false) -> void:
	var box := Rect2(Vector2.ZERO, node.size)
	var c := box.size * 0.5
	if disabled:
		_dashed_rounded(node, box.grow(-0.5), Color(0.855, 0.953, 0.933, 0.16), 1.0, 4.0, 12.0)
		_autopilot_glyph(node, c, false, Color(0.855, 0.953, 0.933, 0.16))
		return
	# The well: the pause tap's at rest, lit while on, hot under a pointer.
	var fill := 0.13
	var edge := 0.09
	if hot:
		fill = 0.58
		edge = 0.48
	elif on:
		fill = 0.58
		edge = 0.55
	else:
		var lit := maxf(fall, breath)
		fill = lerpf(0.13, 0.58, lit)
		edge = lerpf(0.09, 0.55 if fall > 0.0 else 0.48, lit)
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.063, 0.141, 0.125, fill)
	well.border_color = Color(0.12, 0.70, 0.58, edge)
	well.set_border_width_all(1)
	well.set_corner_radius_all(12)
	node.draw_style_box(well, box)
	var ink := Color(0.855, 0.953, 0.933, 0.92) if hot \
		else (Color(AUTOPILOT_LIT, AUTOPILOT_ON_INK) if on \
		else Color(0.855, 0.953, 0.933, lerpf(0.30, 0.92, breath)))
	_autopilot_glyph(node, c, on, ink)


static func _autopilot_glyph(node: Control, c: Vector2, on: bool, ink: Color) -> void:
	var sense := Rect2(c + AUTOPILOT_SENSE.position, AUTOPILOT_SENSE.size)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(ink, 0.35 * ink.a) if on else Color(0, 0, 0, 0)
	box.border_color = ink
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.anti_aliasing = true
	node.draw_style_box(box, sense)
	node.draw_line(c + Vector2(AUTOPILOT_NERVE.x, 0.0), c + Vector2(AUTOPILOT_NERVE.y, 0.0),
		ink, 2.4, true)
	if on:
		node.draw_polyline(PackedVector2Array([c + Vector2(9.0, -6.5), c + Vector2(15.5, 0.0),
			c + Vector2(9.0, 6.5)]), ink, 2.4, true)
	else:
		node.draw_line(c + Vector2(15.0, -9.0), c + Vector2(15.0, 9.0), ink, 2.8, true)


## A rounded box drawn dashed: [param radius] at the corners, as arcs.
static func _dashed_rounded(node: CanvasItem, rect: Rect2, ink: Color, width: float, dash: float,
		radius: float) -> void:
	var p := rect.position
	var s := rect.size
	var r := minf(radius, minf(s.x, s.y) * 0.5)
	node.draw_dashed_line(p + Vector2(r, 0.0), p + Vector2(s.x - r, 0.0), ink, width, dash)
	node.draw_dashed_line(p + Vector2(r, s.y), p + Vector2(s.x - r, s.y), ink, width, dash)
	node.draw_dashed_line(p + Vector2(0.0, r), p + Vector2(0.0, s.y - r), ink, width, dash)
	node.draw_dashed_line(p + Vector2(s.x, r), p + Vector2(s.x, s.y - r), ink, width, dash)
	for corner: Array in [[p + Vector2(r, r), PI, 1.5 * PI], [p + Vector2(s.x - r, r), 1.5 * PI, TAU],
			[p + Vector2(s.x - r, s.y - r), 0.0, 0.5 * PI], [p + Vector2(r, s.y - r), 0.5 * PI, PI]]:
		node.draw_arc(corner[0], r, corner[1], corner[2], 6, ink, width, true)


# --- The rooms the lint holds (automation-ux.md §8) ---------------------------------------

## **The tightest instinct row, in the language of the moment** (`ROW_ROOM`): for
## every sense, its widest test on each value it carries and the widest action,
## the arc left in a row [param row_w] wide -- `[px, sense]` for the sense that
## leaves least. Built with the page's own widths, so the lint measures what the
## page draws.
static func row_room(font: Font, row_w: float = 856.0) -> Array:
	var vocab := FoodField.vocabulary()
	var widths := chip_widths(font)
	var worst := [INF, ""]
	for name: StringName in vocab.inputs:
		var input: Rulebook.InputDecl = vocab.inputs[name]
		var x := widths.x + CHIP_SEP
		for value: StringName in input.values:
			var kind := input.kinds[input.at(value)]
			var widest := 48.0
			for test in 4:
				var rungs: Array = rungs_offered(kind) if test < 2 else [null]
				for rung: Variant in rungs:
					var clause := Rulebook.Clause.new()
					clause.value = value
					clause.kind = kind
					clause.test = test as Rulebook.Test
					if rung != null and kind == Rulebook.SIZE:
						clause.ref = rung
					elif rung != null:
						clause.step = float(rung)
					widest = maxf(widest, ceilf(_text_w(font, ProgramWords.test_text(clause), 14)
						+ 2.0 * CHIP_PAD))
			x += widest + CHIP_SEP
		var arc := row_w - widths.y - (x - CHIP_SEP)
		if arc < float(worst[0]):
			worst = [arc, ProgramWords.says(name)]
	return worst


## **The widest line of the inspector's triggers** (§2.4), in the language of the
## moment: a trigger's word and where a program stands on it, after a default
## name -- the eighth, as long as a library of eight makes one -- as `[px, the
## line]`, against [constant TRIGGER_LINE_W] px at 14 px.
static func trigger_line_room(font: Font) -> Array:
	var named := ProgramWords.quoted(Library.default_name([Library.NEW, Library.LIBRARY_MOST]))
	var orders: Array[String] = [String(TranslationServer.translate(ORDER_AFTER)) % named]
	for key: StringName in ORDER_SAYS:
		orders.append(String(TranslationServer.translate(ORDER_SAYS[key])))
	var widest := [0.0, ""]
	for trigger: StringName in TRIGGER_SAYS:
		var word := String(TranslationServer.translate(TRIGGER_SAYS[trigger], &"trigger"))
		for order: String in orders:
			var line := word + " · " + order
			var w := _text_w(font, line, 14)
			if w > float(widest[0]):
				widest = [w, line]
	return widest
