# Settings, languages and named drops

The owner, 2026-10-01:

> "I need a way to select the language.
> I need a way to start a new drop if I want to (we could have 3 slots for worlds
> that we can name)
> That means we need a settings menu available from everywhere, including in game.
> For the world selection, it could be a select menu visible from any screen except
> in game and when joining another game"

**Status: designed, prototyped on the real screens, photographed at 1280x720 and
2400x1080, and built: phase 1 (the language) and phase 2 (the worlds).** The
prototype lived in a scratch worktree and is not in the repository; §9 says what was
shot and what judging changed. The owner answered §11 on 2026-10-01: the player's
word is **world**, and the code's, like `ocean.md`'s, stays **drop**. This extends
`ocean.md` §9 (the drop is kept), `controls.md` §5 (the scheme chooser),
`invites-ux.md` §1 (the earshot pages) and `game/i18n/README.md`.

---

## 0. Decided here, in one place

- **One corner, on every screen.** A gear for settings and, where a world can be
  chosen, a chip with the world's name, in the top-right corner, 48 px from the
  edges: the pause tap's mirror. In a game the gear is on the pause screen (§1).
- **Settings holds the language, and only that, for now.** Light, camera and
  controls stay on the pause screen, where their effect shows as they are set
  (§2.1, owner row 1).
- **The language list** is English and every game catalog, each named in its own
  language ("Français"). A choice applies at once, without a restart, is saved in
  `user://`, and is applied before the first game screen is built (§3).
- **Three worlds, one selected.** The chip opens "your worlds": one tap selects a
  world, an empty row is "new world", and any world except the one you are in can be
  deleted (§4, §5). A world is what the code calls a drop (owner row 5).
- **No player loses a world.** Today's `user://drop.save` becomes slot 1, at the same
  path, untouched. A small index names the slots (§6).
- **Phases 1 and 2 ship as content.** Phase 3, the launcher, needs one project
  setting -- the game's own autoload -- and so `binary_version` 6 (§1.4, §8).

---

## 1. The corner

### 1.1 Where it is, screen by screen

| screen | gear | world chip |
|---|---|---|
| the launcher (the template's) | a `settings` button in its menu (§1.4) | no (owner row 4) |
| the view chooser, `mode_select` | yes | yes |
| within earshot, while this phone is or may become the host: CHOOSE, CALLING, and TOGETHER and TROUBLE while `session.hosting` | yes | yes |
| within earshot as a guest: ANSWERING, and TOGETHER and TROUBLE without `hosting` | yes | no |
| every far page (by invite, so always a guest) | yes | no |
| a run: the pause screen | yes | no |
| a run: playing, dying, dividing, the replay | no | no |

In `earshot.gd` the chip's rule is one line, read again in `_go_to()`:
`show_drop = not far and (session == null or session.hosting)`.

**In a run, settings is reached only through pause.** The water carries exactly one
control, the pause tap (`diegetic-hud.md` §3 and the pause-tap note in
`normal_mode.gd`). A second one would be the first thing on the water that is not
about the water. Pause can be reached whenever the cell is alive and not dividing.
The death screen and the replay have no pause either; Back from them leads to the
view chooser, which has the gear.

### 1.2 Geometry

```
                                        1280 x 720, canvas px
                                   x 948 ............... 1164   1176 ... 1232
                                   ┌──────────────────────┐   ┌──────────┐
  y 48                             │ world  pond water  ⌄ │   │    ⚙     │
  y 104                            └──────────────────────┘   └──────────┘
```

```
Corner          Control, full rect, mouse IGNORE, theme = addons/launcher/theme/launcher_theme.tres
├─ Cluster      HBoxContainer, anchors (1,0)-(1,0), offset_right -48, offset_top 48,
│  │            grow_horizontal BEGIN, separation 12, mouse IGNORE
│  ├─ Chip      Button, 56 tall, as wide as its words up to 340, clip_contents, FOCUS_ALL
│  │  └─ Inside HBoxContainer, full rect, offset_left 18, offset_right -44, separation 10, IGNORE
│  │     ├─ Caption  Label 17 px  "world"
│  │     └─ Name     Label 17 px, EXPAND, trimmed with an ellipsis, auto-translate off
│  └─ Gear      Button 56 x 56, no text, tooltip "settings", glyph drawn
├─ Veil         ColorRect, full rect, Color(0.004, 0.016, 0.014, 0.784), mouse STOP, hidden
├─ Settings     §2      (each layer hidden until opened; a press on the Veil closes the top one)
├─ Drops        §4.2
├─ Naming       §5.1
└─ Confirm      §4.4
```

`game/menu/corner.tscn` is the **last child** of `ModeSelect` and of `Earshot`, so
`far.tscn` inherits it. In the run it is the last child of `Hud/Pause` with
`show_drop = false`, so it hides with the pause screen. `_set_menu(false)` also calls
`corner.close_all()`, so a sheet left open when a death or a takeover shut pause is
not still open the next time pause is.

Build the four layers as static nodes in the scene, not in code. Then changing the
language only means setting text again, never adding nodes (§3.3). The only rows
made in code are the language list, which is built once in `_ready()`.

**Looks.** The chip and the gear use the launcher theme's own Button boxes: normal
`Color(0.063, 0.141, 0.125, 0.902)` with border `Color(0.141, 0.278, 0.247, 1)`, hover
border `Color(0.239, 0.863, 0.592, 0.702)`, and a 2 px focus ring
`Color(0.490, 1.0, 0.831, 0.612)`, radius 8. The chip keeps `content_margin_right`
44 for its chevron. The chip's caption is `Color(0.855, 0.953, 0.933, 0.52)`, the
same as the pause screen's captions, and its name is `Color(0.855, 0.953, 0.933, 1)`.

**Glyphs, drawn and not textured**, as the pause tap is:

- **Gear:** one closed line through 8 teeth. Tips are at r 11 and roots at r 8.2; a
  tooth spans ±0.17 of a step at the tip and ±0.30 at the root. Add a ring at r 3.4.
  Both are 2 px and antialiased, in ink `Color(0.855, 0.953, 0.933, 0.8)`, or 0.95
  while hovered or focused.
- **Chevron:** (-5.5, -2.5) → (0, 3) → (5.5, -2.5) round (width - 26, height / 2),
  2 px, alpha 0.8.

**Why top-right:**

- It is the one corner that is free on every screen. The launcher's title is top
  left, the view chooser and the earshot pages centre their content, and the pause
  column ends at x 444 and the genome at 1068.
- It is away from resting thumbs, which are the bottom corners.
- It is the pause tap's mirror, so a double tap on pause never lands on the gear.

**Why these glyphs and words:**

- **The gear** is the one icon nearly every player already reads as settings. It
  needs no translation and no room.
- **An outline**, like the game's other strokes, because the filled version read as
  a blob at 1:1.
- **The chip says `world` before the name.** The name alone ("pond water ⌄") read
  as a label, not as a thing to press.

### 1.3 Touch, mouse, keyboard

- **Touch:** every target is 56 px tall or more; the world rows are 68. The chip and
  the gear are 12 px apart, and both only open a menu, so a mis-tap costs one Back.
- **Mouse:** hover states, and tooltips on the gear ("settings") and the chip ("your
  worlds").
- **Keyboard:** the cluster takes focus. Set `focus_neighbor_top` of each screen's
  topmost control to the chip, or to the gear where the chip is hidden, and the
  cluster's `focus_neighbor_bottom` back to that control. On ANSWERING the ring owns
  the arrows, so the corner is reached there by Tab, mouse or touch.
- **Back and Esc** close the corner's top layer first, and only then do what they do
  today. They arrive in a different order:
  - Esc reaches the corner first, because input goes to the last child first, so the
    corner takes it itself. Measured: with the sheet open over the view chooser, Esc
    closed the sheet and the view chooser stayed.
  - Android Back reaches the screen first, because a notification goes parent first.
    Measured: with the sheet open, Back left the view chooser for the launcher. So
    **every screen's Back handler asks `corner.close_top()` first, and stops if it
    returns true.** In `normal_mode.gd` this check comes before the replay, the fork
    and pause. The corner never listens for Back itself; if it did, one Back would
    close two layers.

### 1.4 The launcher

**Built with the game's own autoload, not #68** -- the owner, 2026-10-01: "There's no
problem with installing a new apk". `game/boot.gd`, registered in project.godot as
`GameBoot` after the template's two autoloads, is the hook §10 asks the template
for: it preloads `i18n.gd`, so the catalogs register and the saved language
applies before the launcher's first frame; it hears `custom_button_pressed` on
every launcher; and while the sheet is up it holds `quit_on_go_back` off, because
the launcher has no Back of its own and Back there quits the app. Its registration
is the one change that needs the APK (`binary_version` 6); the script itself, and
`i18n.gd`, still come from the content pack. Once #68 lands, the hook can move onto
the template's.

`launcher_config.tres` gets `extra_buttons = PackedStringArray("settings")`, which
puts a third button between play and quit (rendered). Pressing it emits
`custom_button_pressed("settings")`. That is the untranslated label, so the game
matches on the English and never on what is on screen. The game's hook then opens
the settings sheet over the launcher: a `Corner` with its cluster hidden. When the
sheet closes, focus goes back to the `settings` button.

**Ship nothing here before the hook.** A `settings` button that nothing hears is a
dead control. §8 phase 3 has the rest.

---

## 2. The settings sheet

```
Settings     CenterContainer, full rect, IGNORE
└─ Panel     PanelContainer, min width 520
   └─ Box    VBoxContainer, separation 12
      ├─ Title      Label 22 px Color(0.404, 0.639, 0.588, 1), centred   "settings"
      ├─ (gap 2)
      ├─ Caption    Label 16 px Color(0.855, 0.953, 0.933, 0.52)          "language"
      ├─ Languages  ScrollContainer, vertical auto, height min(n, 6) x 64 - 8
      │  └─ Rows    VBoxContainer, separation 8, one row per language (§3.1)
      ├─ Warn       Label 15 px Color(0.855, 0.953, 0.933, 0.82), centred, in a pond only:
      │             "the water is still moving · you can still be eaten" (the pause screen's own)
      ├─ (gap 6)
      └─ Close      Button 232 x 56, 20 px, SHRINK_CENTER                 "close"
```

**The panel** is the launcher's dialog panel made opaque: fill
`Color(0.035, 0.086, 0.078, 1.0)`, 1 px border `Color(0.141, 0.302, 0.267, 1)`, radius
12, margins 24 / 20. At the launcher's 0.949 alpha, the view chooser's `full vision`
ghosted through behind the title (rendered).

**A language row** is a Button 472 x 56 at 20 px, its text left-aligned with
`content_margin_left` 52, with the launcher's Button boxes and auto-translate off
(§3.1). Its mark sits at x 26:

| row | box | mark at x 26 |
|---|---|---|
| the language in use | "current": fill `Color(0.047, 0.110, 0.098, 1)`, border `Color(0.239, 0.863, 0.592, 0.85)` | filled dot, r 6, `Color(0.490, 1.0, 0.831, 1)` |
| every other language | the launcher's Button | empty ring, r 6, 1.5 px, `Color(0.855, 0.953, 0.933, 0.35)` |

**What it does:**

- It opens with focus on the language in use.
- Tapping a row applies that language at once and saves it. The sheet stays open, now
  in that language, which is the best confirmation there is. There is no apply
  button.
- `close`, Back, Esc, or a press on the veil closes it, and focus returns to whatever
  opened it.
- In a pond the water keeps moving under the menu (`shared-pond.md` §1.7), and the
  sheet covers the pause screen's warning, so it repeats it.
- At 1280x720 with two languages the sheet is 520 x 338, centred. Six languages show
  at once; from the seventh, the list scrolls.

### 2.1 Why only the language

Each of the pause screen's three settings is there because you see it work as you
change it:

- **Light:** "this is where the problem is felt: the membrane is still beating behind
  the scrim" (`normal_mode.gd`).
- **Camera:** the water turns, or stops turning, behind the scrim.
- **Controls:** "the controls stay drawn while paused… that is the entire
  explanation" (`controls.md` §5.1).

Moving them into settings means setting them blind. Copying them means two homes for
one setting, which drift apart. The language is the one setting that has no home
yet, belongs to the whole app, and is the same wherever it is set. Owner row 1 has
the alternatives.

---

## 3. Languages

### 3.1 The list

- **What is listed:** English, then every `game/i18n/<locale>.po`. Only the game's
  catalogs count: a language with no game half would show its launcher words over an
  English game.
- **Order:** sorted by the name shown (`naturalnocasecmp_to`).
- **Each language is named in its own words:** "English", "Français", "Português
  (Brasil)". A player who cannot read the current language must still be able to
  find theirs. Names keep their own capitals: this is the one place the game is not
  lowercase, because people look for a language the way it is written.
- **The name comes from the catalog.** The engine knows only English names
  (`get_locale_name("fr")` returns "French"; checked). A table of names in code would
  break the README's promise that a language is one file.
  - Every game catalog translates the msgid `English` as its own name:
    `msgid "English"` → `msgstr "Français"`. Keep the msgid in a marked constant
    (`OWN_NAME`), so the template lists it.
  - The English row shows the msgid itself.
  - A catalog that leaves it untranslated is listed under the engine's English name
    ("French"), and `--lint-all` reports it.
  - A catalog that translates it as `English` fails the lint, because two rows would
    then read the same.
- **The rows never translate themselves.** A row's text is the msgid `English`, and a
  Button whose text is a msgid retranslates itself (§3.3). Left on, the English row
  would read "Français" in French.
- **The language in use** is the catalog with the best
  `TranslationServer.compare_locales()` score against the current locale, or English
  when none scores.

### 3.2 Saved, and applied before the first game screen

- **Where it is kept:** `RunState` gains `[app] locale` in `user://normal_mode.cfg`,
  beside the view, light, camera and controls.
  - Absent means "follow the device", as today.
  - The list sets it. A player who never opens the list never has one.
  - `en` keeps English on a device set to another language.
- **When it is applied:** by `I18n.register()`, right after it registers the
  catalogs. That runs as the first game screen's script loads, before that screen's
  nodes exist, so the view chooser is already in the chosen language.
- **When it is not applied:**
  - in a headless process, so the server and the probes stay English, as today;
  - when the saved locale no longer has a game catalog; the game then follows the
    device;
  - when something overrode the device's language for this run. `--language` does not
    show up in `OS.get_cmdline_args()` (checked), but it leaves
    `TranslationServer.get_locale()` different from
    `standardize_locale(OS.get_locale())` at that moment (checked with `fr` and `de`),
    so that is the test. `tools/shot.tscn --language fr` therefore still shoots French,
    whatever this machine saved.
- **The launcher:** from binary 6, `GameBoot` sets the catalogs and the chosen
  language before its first frame (§1.4). Before that, its first view followed the
  device, and only its second, after Play and Back, the chosen language.

### 3.3 Live: what retranslates itself, and what does not

Measured on 4.7.2 with `set_locale()` at run time, en → fr → en:

| text | en → fr | fr → en |
|---|---|---|
| a scene's msgid (`text = "choose a view"`), or code setting a raw msgid or a placeholder | yes | yes |
| code sets `tr(msgid)` while in English | yes, by accident: the stored English is the msgid | - |
| code sets `tr(msgid)` while in French | - | **no**, it stays French |
| code sets `tr(template) % value` | **no** | **no** |
| auto-translate off, set by code | **no** | **no** |

**So the scene's words look after themselves, and everything this game builds with
`tr()` -- which is most of it -- must be set again.** The trap is the second row: a
test from English to French looks fine. French to English shows the problem. Over the
pause screen, after a switch back to English (rendered):

- **back in English:** `light`, `camera`, `controls`, `resume`, `leave` and the gene
  words on the figure;
- **still French:** `nord en haut`, `partout`, `génome · 1re génération` and the three
  lines under the figure.

On `NOTIFICATION_TRANSLATION_CHANGED`, each screen sets its words again. Measured: a
node also gets it once as it enters the tree, before any change, so guard with
`is_node_ready()`; after that, each `set_locale()` delivers it exactly once, inside
the call:

| screen | what it sets again |
|---|---|
| `corner.gd` | its own words, the chip's default name, the open layer |
| `mode_select.gd` | the hint, and the far button and its note: move them from `_ready()` into a `_say()` that both call |
| `earshot.gd` | the page. Split `_go_to()` into the page change and a `_say_page()` that only sets words: no focus, no clock reset, and `_after` is not consumed |
| `normal_mode.gd` | `_update_view_button()`, `_update_scheme_button()`, `_update_caption()`, `_build_genome_strip()`, `_update_explain()`, `_update_hint()`, `_update_act()`, the onboarding line's text, and `queue_redraw()` on anything that draws words |

**Always defer the re-say.** `set_locale()` sends this notification down the tree
while it walks the children, and the tree refuses a node added from inside it
("Parent node is busy setting up children, `add_child()` failed"). Measured: the
sheet vanished. `_build_genome_strip()` adds nodes, so call every re-say with
`call_deferred()`. The replay and the choosing screen cannot be on screen while
settings is open. The launcher is the template's (§10).

---

## 4. Worlds

### 4.1 What a world is, to the player

> **Cells leave the worlds: `cells.md` and `cells-ux.md`** (designed 2026-10-04, not
> built yet). A world keeps its water and nothing else. Your cells are kept in slots
> of their own, three for each view, and are chosen beside each view's button. What
> this section says of cells is replaced there: the cells a world keeps, a world's
> cell lines (§4.3), the delete line (§4.4) and the index's `generation` keys (§6.2)
> (`cells-ux.md` §5, `cells.md` §3.3).

A world is a drop of water with everything living in it, kept between launches
(`ocean.md` §9), together with the cells you left in it: one for each view, never
played in the other (`ocean.md` §9.5). You have room for three and are in one at a
time. The selected world is the one that:

- a run plays in;
- a host serves to a friend;
- a guest's cell comes from, and goes back to -- the cell of the view it plays in.

**"world" is the player's word** (owner row 5, answered in §11). The code and
`ocean.md` keep "drop" for the same thing -- `drops.gd`, `drops.cfg`, `drop.save` --
and so does this document wherever it means the files and the code; wherever it
means what the player reads, it says world. "water" stays the word for whatever you
are swimming in, a friend's included.

### 4.2 The chip, and "your worlds"

The chip shows `world` and the selected world's name: two labels, so the caption is
translated and a typed name never is, and a drawn chevron that says it opens (§1.2).
Pressing it opens the menu under it:

```
Drops        Control, full rect, IGNORE
└─ Panel     PanelContainer, min width 640, anchors (1,0)-(1,0), offset_right -48,
   │         offset_top 112, grow_horizontal BEGIN
   └─ Box    VBoxContainer, separation 10
      ├─ Caption   Label 16 px Color(0.855, 0.953, 0.933, 0.52)   "your worlds"
      ├─ Row1..3   HBoxContainer, separation 10
      │  ├─ Pick     Button, EXPAND x 68, + 25 a line past the first; content_margin_left 52, mark at x 26
      │  │  └─ Lines VBoxContainer, full rect, offsets 52 / -16, centred, IGNORE
      │  │     ├─ Name   Label 20 px Color(0.855, 0.953, 0.933, 1), ellipsis, auto-translate off
      │  │     └─ Stats  Label 15 px Color(0.482, 0.686, 0.643, 1), ellipsis, a line each (§4.3)
      │  ├─ Rename   Button 112 x 68, 15 px, quiet box
      │  └─ Delete   Button 112 x 68, 15 px, quiet box; on the selected row, an empty 112 x 68 Control
      └─ Note      Label 15 px Color(0.318, 0.463, 0.435, 1)
                   "each world keeps its own water, and your cell in it"
```

It spans x 592..1232, y 112..440 at 1280x720 with a line under every name. **A row
grows by one line of its Stats type, 25 px, for each line past the first** (§4.3),
and its rename and delete grow with it: with a world keeping both cells, one keeping
one and one keeping none, the panel is y 112..516. At 2400x1080 it moves with the
right edge, to x 912..1552 of 1600. A row's states:

| row | mark at x 26 | box | Name | Stats |
|---|---|---|---|---|
| the selected world | filled dot as §2 | "current", as §2 | its name | its line, §4.3 |
| another world | empty ring as §2 | the launcher's Button | its name | its line |
| an empty slot | a plus, arms 6 px, 2 px, `Color(0.855, 0.953, 0.933, 0.6)` | fill `Color(0.063, 0.141, 0.125, 0.25)`, border `Color(0.141, 0.278, 0.247, 0.8)` | "new world", alpha 0.82 | none |

**The quiet box** for rename and delete is the pause screen's toggle slab: fill
`Color(0.063, 0.141, 0.125, 0.55)`, border `Color(0.12, 0.70, 0.58, 0.30)`, radius 8,
text `Color(0.855, 0.953, 0.933, 0.78)`. They matter less than the row they belong
to. At the launcher's weight, the four of them out-shouted the names (rendered).

### 4.3 What a row says

> **From `cells.md` on (designed, not built yet), a world's row says its age and
> nothing else** (`cells-ux.md` §5). The cell lines below are what the game shows
> until then.

**The world's age, and under it a line for each view that keeps a cell in it**
(`ocean.md` §9.5), in the order the view chooser offers them:

```
pond water
2 hours old
full vision · fourth generation
point of view · seventh generation
```

- **Age:** the world's, in whole minutes under an hour, hours under 48, then days:
  "25 minutes old", "2 hours old", "3 days old". Under a minute is "1 minute old": a
  world that has been swum in is never nothing old.
- **A cell's line, `<view> · <generation>`:** the view in the view chooser's own
  button words, and the cell's generation in the pause caption's own words ("fourth
  generation", "generation 12"). Nothing new to translate: both were already
  translated. Each line is built whole and has the row's 280 px to itself.

The other cases:

- A world where no cell waits -- its last cells died, or it was only ever left after
  a death -- says only its age.
- A world never swum in says "not swum in yet": it has no file yet, or its last keep
  left it at no age with no cell.

**Why lines and not one line.** The one line said `<generation> · <age>` for the one
cell there was. With a cell per view it has to name the view, and one view's cell
with the age is already up to 366 px of the 280 ("point of view · seventh generation
· 59 minutes old"); two cells would be over 470. So each fact has its line, and the
row grows. Rendered at both shapes with both cells, one and none (§9): the age stays
right under every name, the views line up across rows, and a row with no cell is
the row it always was.
- **No row shows families.** The owner answered "not yet" to showing lineage anywhere
  a player looks (`lineage.md` §4, row 21).

The age is the world's own clock, which only runs while it is played (`ocean.md`
§9.1). So "2 hours old" means two hours played in it, which is also what the fiction
says.

### 4.4 The rules

- **Select:** a tap on a world's row selects it and closes the menu, and the chip
  shows it. It takes one tap because choosing is what the menu is for; a tap on the
  world you are in just closes it.
- **New:** a tap on an empty row opens naming (§5) with the next default name. `make
  it` makes the world, selects it, and closes everything. Its water is made the first
  time it is played, as a fresh install's is today.
- **Rename:** opens naming with the world's name. `rename` saves it and goes back to
  the menu, which shows the new name.
- **Delete:** opens Confirm, below, and on `delete` empties the row and goes back to
  the menu.
- **The world you are in cannot be deleted**, so its row has no delete. To start
  over, make a new world or pick another, then delete the old one. That way there is
  always a selected world, and a mis-tap can never cost the world you are about to
  play (owner row 8).
- **Duplicate names are allowed.** Rows are told apart by their place and their line.

```
Confirm      CenterContainer, full rect, IGNORE
└─ Panel     PanelContainer, min width 560
   └─ Box    VBoxContainer, separation 14
      ├─ Title    Label 22 px Color(0.404, 0.639, 0.588, 1), centred, autowrap, width 512
      │           "delete %s?" with the world's name, auto-translate off
      ├─ Line     Label 17 px Color(0.482, 0.686, 0.643, 1), centred, autowrap
      │           "everything living in it, and your cell with it, is gone for good."
      ├─ (gap 4)
      └─ Actions  HBoxContainer, centred, separation 24
         ├─ Keep    Button 208 x 56, 20 px, focused   "keep"
         └─ Delete  Button 208 x 56, 20 px            "delete"
```

This is the earshot screen's "forget this invite?" page, one more time. `keep` is the
safe answer and has focus. Back means keep. While it is up, the chip and the gear
hide, as they do under naming (§5.1).

### 4.5 Switching, a run in progress, a pond, the server

- **No run is ever switched under you.** The chip is on no screen a run is played
  from.
- **Each world keeps its own cells**, one for each view (`ocean.md` §9.5). A cell
  left mid-run is in its world's file (`ocean.md` §9.1), so switching at the view
  chooser loses nothing: the other world waits, frozen, with its cells where they
  were. Choosing the other view opens the same water on that view's cell, or on a
  new one.
- **A host serves the selected world.** Nothing changes here: the run's own drop is
  the pond (`ocean.md` §10.2). Changing the selection on CALLING or TOGETHER, before
  the run starts, changes what the friend will swim in.
- **A guest's cell comes from its selected world and goes back to it**, marked
  `elsewhere` (`ocean.md` §9.1) -- the cell of the view it plays in, from that view's
  place and back to it (§9.5). The chip is hidden on every guest page, so the
  selection cannot change while joining.
- **The dedicated server is not affected.** It keeps `user://rooms/1.save`
  (`server.gd`'s `ROOM_PATH`), never builds a screen, and never reads the drop index.
- **The dev app** has its own `user://`, and so its own three worlds.

---

## 5. Naming

### 5.1 The sheet

```
Naming       Control, full rect, IGNORE
└─ Panel     PanelContainer, min width 560, anchors (0.5,0)-(0.5,0), offset_top 48, grow_horizontal BOTH
   └─ Box    VBoxContainer, separation 16
      ├─ Title    Label 22 px Color(0.404, 0.639, 0.588, 1), centred   "a new world" / "rename this world"
      ├─ Field    LineEdit 512 x 60, 22 px, max_length 20, select_all_on_focus,
      │           context menu and emoji menu off, auto-translate off
      └─ Actions  HBoxContainer, centred, separation 24
         ├─ Back  Button 160 x 56, 20 px   "back": to the menu, nothing changed
         └─ Make  Button 232 x 56, 20 px   "make it" / "rename"
```

**The field:**

| part | value |
|---|---|
| box, normal | fill `Color(0.023, 0.055, 0.05, 1)`, 1 px border `Color(0.141, 0.302, 0.267, 1)` |
| box, focused | 2 px border `Color(0.239, 0.863, 0.592, 0.85)` |
| box shape | radius 8, margins 16 / 10 |
| ink | `Color(0.855, 0.953, 0.933, 1)` |
| placeholder | `Color(0.855, 0.953, 0.933, 0.35)` |
| caret | `Color(0.490, 1.0, 0.831, 1)`, 2 px |
| selection | `Color(0.239, 0.863, 0.592, 0.38)`, selected ink `Color(1, 1, 1, 1)` |

Enter does what Make does; Esc and Back do what Back does. **Esc has to be caught
first:** a LineEdit being typed in keeps Esc for itself and only stops editing on
it, so the corner reads Esc in `_input`, before the field, while the field has the
keyboard. **While naming is up, the chip and the gear hide:** the panel shares their
band at y 48, and the widest chip reaches x 824, under the panel's right edge at
920.

**The panel is anchored to the top on purpose.** It spans y 48..267 of 720. An
Android keyboard covers about the bottom half of a landscape phone, so the field and
both buttons stay above it. `earshot.gd` refused a text field for an address for two
reasons: there was no style for one, and that keyboard. Here both are answered: the
boxes are defined above, and the panel sits out of the keyboard's way. A name also
has no wrong answer, which an address does. This has not been seen on a device
(§12).

### 5.2 Names

- **Naming costs one tap.** The sheet opens with the text selected: typing replaces
  it, and `make it` keeps it.
- **Trimmed** at both ends. An empty name means the default name.
- **Up to 20 characters** (owner row 7). The widest ordinary name fits whole
  everywhere. A name of very wide letters is shortened with "…" on the chip (221 px
  for the name beside `world`, 210 beside `monde`) and in the menu (280 px), never in
  the field (480 px fits 20 `W` at 22 px).
- **A typed name is the player's own words and is never translated.** Every Label and
  LineEdit that shows one has auto-translate off, and nothing passes one to `tr()`.
  A world named `play` stays `play` in French; a raw msgid would retranslate itself
  (§3.3).
- **Default names** (owner row 6) are the water a microscopist takes a drop from:
  `pond water`, `rain barrel`, `hay infusion`, `ditch water`, `birdbath`,
  `tide pool`, `puddle`, `vase water`, `wet moss`, `pepper water` (Leeuwenhoek's,
  1676).
  - A new world gets the first one no other world wears, or is called.
  - A world that keeps its default stores which one, not the words, and the name is
    translated each time it is said, so it follows the language (`eau de mare`),
    and is said again on a change of language like every other word.
  - Typing a default's own words, in English or in any language the game has a
    catalog for, keeps the default; so does leaving the offered name as it is.
  - A typed name is stored as typed.

---

## 6. The files

### 6.1 Three drops, with today's file first

| slot | file |
|---|---|
| 1 | `user://drop.save`: today's file, at the same path, never moved |
| 2 | `user://drop_2.save` |
| 3 | `user://drop_3.save` |

Each file keeps today's format, untouched: `FORMAT` stays 1, with its `.tmp` and
`.save.old` beside it as `drop_save.gd` makes them. **Slot 1 is not moved**, for two
reasons:

- there is no migration that could fail half-way;
- a build without this change still finds the player's drop where it always was.
  That happens when a pack fails to mount and the APK runs its own content.

### 6.2 The index: `user://drops.cfg`

> **From `cells.md` §3.3 on (designed, not built yet), the `generation` keys go.**
> `note_kept(slot, lived)` keeps the age alone, and the cells' own index is
> `user://cells.cfg`.

```
[drops]
selected=1          ; the drop a run opens, 1..3
[1]
name=""             ; typed, as typed; "" while it wears its default
default=0           ; which default name
lived=7800.0        ; the drop's age at its last keep, in whole seconds
generation=4        ; full vision's cell's generation at its last keep; 0 for no cell
generation_pov=7    ; point of view's, only while a point-of-view cell waits
```

**A generation for each view** (`ocean.md` §9.5): `generation` is the first view's,
full vision's, as it always was, so a build from before the split still reads it;
every other view's is `generation_<view>`, under the name `run_state.gd`'s
`CELL_KEYS` keeps its cell by, and read by that pattern, so a view added later is
kept by a build that does not know it.

A slot is empty when it has neither a section nor a file. The index is written beside
itself as `drops.tmp`, read back and compared with what was meant, and renamed over,
as a drop is. **The age is kept in whole seconds:** the engine's text reader gives
back about one double in three a last digit off (7,581 of 20,000 on 4.7.2), which
failed that comparison, and the menu says nothing finer than a minute.

### 6.3 Reading it, and the first launch after the update

**Reading never writes.** Whatever has to be rebuilt is rebuilt again on every read,
from the same files the same way, and written with the next change: a selection, a
name, a delete, or a run's keep. A screen that only shows the worlds, and every tool
and probe, leaves `drops.cfg` as it found it.

1. **There is no `drops.cfg`.** Every slot with a file is a world, with the next free
   default name, and the first one there is is selected: slot 1, on a fresh install
   and on the first launch after the update. Slot 1 is made, with default name 0,
   only when there is no world at all, so a lost index never puts a new world in the
   place of one the player has. A file's `lived` and each view's `generation` come
   from a new `DropSave.peek(path)`, which decodes and checks as `read()` does but
   **never moves a file aside**. It costs about 2 ms on a desktop for 600 bodies, on every read
   until the index is written.
2. **A slot file has no section**, because the index was lost or is older than the
   file. It is read as in step 1, with the next free default name. A world is never
   treated as garbage for having no name.
3. **A section has no file.** That world has not been swum in yet.
4. **The index does not read, or selects a slot that is empty.** It is rebuilt from
   the files as in step 1, and the first world there is is selected.

### 6.4 What changes in code

- **`game/normal/drops.gd`** is new: a `RefCounted` with static functions, no
  class_name, preloaded by path. It holds the slots, the selection, the paths, the
  names, the index and its upkeep. The menus and the run both read it; it knows
  nothing of either.
- **`normal_mode.gd`:**
  - `var keep := DropSave.PATH` becomes `var keep := Drops.SELECTED`. That is a
    marker, resolved once as the run opens, before `_open_drop()`, to the selected
    drop's path; the run remembers the slot. Tools still set `keep` to `""` or to a
    file of their own, so no tool run touches the index.
  - After every successful `_keep_drop()` write to a slot, it calls
    `Drops.note_kept(slot, drop age, view, cell generation)`, which writes that view's
    generation and leaves every other view's (`ocean.md` §9.5). The menu never opens
    a 30 KB drop to say how old it is.
- **The generation words:** the menu says the generation with the pause caption's own
  phrases (`GENERATIONS`, `generation %d`). Move them, with `_generation_text()`,
  to a static function that both can call, so the menu never preloads
  `normal_mode.gd`.
- **`drop_save.gd`** gains `peek()`. `PATH` stays slot 1's path.
- **Delete** removes the slot's `.save`, `.tmp` and `.save.old`, then its section.
- **`server.gd`:** nothing changes.

---

## 7. Every new string

Every one goes through `tr()`, with a `TRANSLATORS:` note and, where room is tight,
a `ROOM:` line (README, "Making a string translatable"). Sizes are in px of type;
"room" is in canvas px at 1280x720.

| msgid | where, and its note | room |
|---|---|---|
| `English` | **Not the word for English: the name of the catalog's own language, in that language, as a speaker writes it in a list ("Français", "Deutsch").** It is the language's row in the language list. Held in a marked constant | 400 px at 20 |
| `settings` | the sheet's title (22); the gear's tooltip; the launcher's menu button (20, a 300 px button) once #68 lands | 250 px at 20 |
| `language` | the caption above the list (16) | 472 px at 16 |
| `close` | the sheet's button (20, 232 wide) | 180 px at 20 |
| `world` | the chip's caption before the name (17). A world is one of the three the player keeps: a drop of water and everything in it | 80 px at 17 |
| `your worlds` | the menu's caption (16); the chip's tooltip | 592 px at 16 |
| `new world` | an empty row (20) | 280 px at 20 |
| `rename` | a row's button (15, 112 wide); naming's confirm (20, 232 wide) | 88 px at 15 |
| `delete` | a row's button (15); the confirm's button (20, 208 wide) | 88 px at 15 |
| `a new world`, `rename this world` | naming's title (22) | 512 px at 22 |
| `back` | naming's button (20, 160 wide) | 116 px at 20 |
| `make it` | naming's confirm (20, 232 wide): make the new world; "it" is the world | 188 px at 20 |
| `delete %s?` | the confirm's title (22, wraps); `%s` is the world's name, the player's words or a default | wraps |
| `everything living in it, and your cell with it, is gone for good.` | under it (17, wraps; a full sentence, with a full stop) | wraps |
| `each world keeps its own water, and your cell in it` | the menu's footnote (15) | 592 px at 15 |
| `not swum in yet` | a row's line (15) | the line's 280 |
| `%d minute old` / `%d minutes old`, `%d hour old` / `%d hours old`, `%d day old` / `%d days old` | plurals; the world's age, at the end of a row's line | the line's 280 |
| the ten default names (§5.2) | a `TRANSLATORS` constant: "A world's name until the player types one: a real place a microscopist takes a water sample from. Short, lowercase, at most 20 characters" | 220 px at 20 |

**Reused, with their notes extended:**

- `keep`: the safe answer to deleting a world, as well as to forgetting an invite. Its
  room shrinks from about 220 to 164 px at 20, because the button is 208 wide here
  and 264 on the earshot page.
- `first generation` … `tenth generation` and `generation %d`: also a world's line.
- `full vision` and `point of view`: also the start of a cell's line in a world's row
  (`ocean.md` §9.5), the view as the view chooser's buttons name it.
- `the water is still moving · you can still be eaten`: also the sheet, in a pond.

**A row's lines are built whole**, like the gene numbers lines and the pause caption:
the age, and `<view> · <generation>` for each view's cell, each in 280 px at 15 px.
The English takes at most 247 ("point of view · seventh generation") and the French
235 (`âgé de`, as `monde` is masculine). The lint's built lines (`STATS_ROOM`) are
composed with every age, and with every view and every generation phrase.

**Phase 2's README** gains a glossary line: "A **world** is one of the three the
player keeps: a drop of water with everything living in it, kept between launches,
and named by the player (the code calls it a drop)." The French is `monde`, which
is masculine, so its line says `âgé de` and `pas encore exploré`, and naming's
`make it` is `le créer`.

---

## 8. Build phases

**Three pull requests.** The first touches no save, and the second is mostly the
save. The third, the launcher, waited for #68 until the owner chose a new APK
instead; it rides with the second.

| phase | the player gets | what is built | checks before `dev` |
|---|---|---|---|
| **1. Language** | "The game's language can be chosen, from every screen and from pause" | `corner.tscn` with the gear only; the settings sheet; Back handling in `mode_select`, `earshot` and `normal_mode`; `RunState` locale; `I18n.register()` applies it; the re-say on every screen (§3.3); `msgid "English"` in `fr.po`; the README | `--lint-all` (with the new `English` rule), `--check`; frames at both sizes: the gear on the view chooser, a far page and pause; the sheet open; after picking Français; **pause after French → English with no French left**; the sheet in a pond (`drive.gd --pond=host`) |
| **2. Worlds** | "Three worlds you can name, and a new one whenever you like" | `drops.gd`, `DropSave.peek()`, `keep` → the selected drop, `note_kept`; the chip, the menu, naming and confirm; the chip's rule on earshot | `drop_probe` gains: an existing `drop.save` with no index becomes slot 1 with the same bytes; new, rename and delete round trip; the selected drop cannot be deleted; a lost index is rebuilt; a tool run with `keep` empty never writes `drops.cfg`. Frames: three slots with one empty, naming (new and rename), confirm, French, the widest name, the chip on CHOOSE and its absence on ANSWERING and far |
| **3. The launcher** | the launcher's own `settings` button, and its first view in the chosen language | `game/boot.gd`, the `GameBoot` autoload: preloads `I18n`, connects every launcher's `custom_button_pressed`, opens the sheet, holds `quit_on_go_back` off while it is up; `extra_buttons = ["settings"]` **in the same merge, never before**; `binary_version` 6 for the autoload's registration | the Back probe opens the sheet from the launcher's button and closes it by Back and by Esc, the app staying and Back quitting again after; frames: the launcher with `settings`, the sheet over it, a cold start with French saved |

Phases 1 and 2 ship as content; phase 3 is the one APK.

**Six things the build must not get wrong:**

1. Defer every re-say.
2. Keep auto-translate off on language rows and typed names.
3. Every Back handler asks the corner first.
4. `_set_menu(false)` closes the corner.
5. `extra_buttons` ships only with the hook.
6. Never decide anything by reading translated text: the list keys on locales, and the
   launcher's button on its English label.

---

## 9. Rendered, and judged

**What was shot.** The prototype was built on the real screens and shot with
`tools/shot.tscn` under `--rendering-driver opengl3`, at 1280x720 and 2400x1080. The
pause frames went through `tools/drive.tscn` with real input: `--esc-at`, then
`--touch` on the gear and on a language row. Every state in this document was shot:
the corner on the view chooser, CHOOSE and a far page; the settings sheet before and
after picking Français; the menu in English and French; naming and renaming;
confirm; the gear on pause and settings over it; pause after French → English; the
widest name; and the launcher with `settings`, before and after a live switch.

**What judging changed:**

| first version | what it looked like | now |
|---|---|---|
| a filled gear | a blob at 1:1 | an outline, 2 px |
| the name alone on the chip | a label, not a button | `world` in caption ink, then the name |
| panel at 0.949 alpha | `full vision` ghosted behind the title | opaque |
| rename and delete in launcher buttons | four boxes out-shouted the names | the quiet slab, 15 px |
| "new world" over "empty" | it said the same thing twice | "new world" alone |
| the sheet rebuilt inside the notification | it vanished on a language change | deferred (§3.3) |
| delete on every row | the world you are in was one mis-tap from gone | none on the selected row |
| row actions 104 wide | French `renommer` took 78 of 80 px | 112 wide |
| one line, `<generation> · <age>`, once a world kept a cell per view (`ocean.md` §9.5) | naming the view made it 342 to 366 px of the 280, two cells over 470 | the age, then a line for each view's cell; the row grows 25 px a line, and its own buttons with it (§4.3) |

**Fits, at both shapes.** At 1280x720 the cluster at its widest starts at x 824. The
longest heading on an earshot page that shows the chip is "different versions",
188 px, so the two are at least 90 px apart; "within earshot" leaves 107. The menu,
the sheets and naming do not reflow; they follow the right edge or the centre. On a
phone, only the space between the groups grows.

---

## 10. The launcher: what it needs, and one problem

**What the hook must do.** #68, as the owner widened it, has to let game code do three
things:

1. run after the pack mounts and before the launcher's first screen is built, to
   register the catalogs and apply the saved language;
2. reach the launcher once it is built, to hear `custom_button_pressed`;
3. add the sheet over it.

**A problem worth an issue against the template: the launcher does not retranslate
when the language changes while it is on screen.** Measured with a throwaway
launcher catalog and a live switch to French over the launcher:

- **retranslated:** `play`, `settings` and `quit` became `jouer`, `réglages` and
  `quitter`;
- **stayed English:** the tagline, "New app version available (v0.2.0).", "What's
  new" and "Update app".

The cause is that those nodes have auto-translate off and are filled once with
`tr()`. It matters now that `GameBoot` lets the player change the language on that
screen (§1.4): the menu follows at once, the rest on the next start. The
ask: on `NOTIFICATION_TRANSLATION_CHANGED`, rebuild the tagline, refresh the update
bar, and say an open overlay again. It could be a comment on #68 or an issue beside
it.

---

## 11. Owner's decisions

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | What does settings hold besides the language? | **Nothing else for now ✓ recommended** · also the control scheme · everything on the pause screen (light, camera, controls) | Light, camera and controls stay on the pause screen, where you see the water change as you set them. Settings starts as a short list of languages and grows only when something has no better home. Moving them means setting them without seeing what they do. |
| 2 | Where is settings during a game? | **A gear in the pause screen's top-right corner ✓ recommended** · a fourth button in the pause screen's left column · a gear on the water, beside pause | You pause, then tap the gear, in the same corner as on every other screen. Nothing new is drawn over the water while you play. The pause column has no room for a fourth button without being rebuilt. |
| 3 | Where is settings on the launcher, once the template allows it (#68)? | **A "settings" button between play and quit ✓ recommended** · the same gear as everywhere else, top right | The app's first screen gets a third button, made the way the template intends. A gear there would match the other screens, but the game would have to push it into the template's screen itself. |
| 4 | Is the drop shown on the launcher's own screen? | **No, from the next screen on ✓ recommended** · yes, top right, once #68 lands | The drop's name appears on the view chooser, one tap after play, which is where it is used. On the first screen, the game would be placing its own button on the template's screen, where a launcher update could later put something in the same corner. |
| 5 | What does the game call a world? | **"drop" ✓ recommended** · "water" · "world" | The menu says "your drops" and "new drop". It is your word and the fiction's: a drop of pond water under the microscope. "water" already means whatever you are swimming in, a friend's included. |
| 6 | What is a new drop called before you name it? | **Water a microscopist would sample: "pond water", "rain barrel", "hay infusion"… ✓ recommended** · "drop 1", "drop 2", "drop 3" · nothing, you must type one | Each drop starts with a real place it came from, and you can type over it. The numbers are plain and forgettable; the empty name makes you type before you can play. |
| 7 | How long can a name be? | **20 characters ✓ recommended** · 12 · 32 | 20 fits whole wherever it is shown for any ordinary name. Only a name of very wide letters gets "…" on the button that shows it. |
| 8 | Can a drop be deleted? | **Yes, any drop except the one you are in ✓ recommended** · no, only "start over" · yes, even the one you are in | To start over, make a new drop or pick another, then delete the old one. You can never delete the drop you are about to play by mistake, and the game never has to invent a drop to replace one you deleted. |

Rows 1 to 4 decide what is built. Rows 5 to 8 are words and limits: the build can start
on the recommendations, and changing any of them later is a string or a constant.

**Answered 2026-10-01: the recommended option on every row but 5, which is "world".**
"All recommended except 5 : world"

- **Row 1:** settings holds the language and nothing else. Light, camera and controls
  stay on the pause screen.
- **Row 2:** in a game, settings is the gear in the pause screen's top-right corner.
- **Row 3:** the launcher gets a `settings` button between play and quit (§1.4).
- **Row 4:** the launcher's own screen shows no world; the chip starts on the view
  chooser.
- **Row 5: world.** The player reads `world`, `your worlds`, `new world`, `a new world`
  and `rename this world`, and French `monde`. The code, its files and `ocean.md`
  keep "drop" (§4.1), and "water" is still whatever you swim in. It was a string,
  as promised: the words changed and nothing else did.
- **Row 6:** water a microscopist would sample, translated, pre-selected so typing
  replaces it (§5.2).
- **Row 7:** 20 characters.
- **Row 8:** any world but the one you are in can be deleted.

---

## 12. Left open

1. **The Android keyboard has not been seen.** The container has no virtual keyboard
   (`FEATURE_VIRTUAL_KEYBOARD` is false here). The naming panel keeps everything in
   the top 267 px of 720. Whether a landscape keyboard goes full screen over it
   depends on how Godot's Android text field is flagged. Check it on the dev app with
   phase 2.
2. **Punch-hole cameras.** In one of its two landscape directions, a phone's
   punch-hole can sit in a top corner. The corner mirrors the pause tap, which has the
   same exposure; neither reads `DisplayServer.get_display_safe_area()`.
3. **Emoji, and scripts the default font lacks, in a typed name** are untested. At
   worst they show as boxes.
4. **No "follow the device" row.** A player who never picks a language keeps following
   the device; one who picks is kept to that choice. A way back is one more row, if
   the owner wants it.
5. **The death screen and the replay** have no gear, as they have no pause.
6. **The launcher's first view** is in the chosen language from binary 6 (`GameBoot`,
   §1.4); before it, it followed the device.
