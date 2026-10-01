# Languages

Biogenic is written in English, and every sentence a player reads goes through
Godot's gettext translation with **the English itself as the message id**: there
are no keys. A language is **one file per catalog**, and there are two catalogs:
the game's own words, and the words of the launcher's screens (the app's main
menu, which is the template's and has a template of its own). The device's
language picks the file, and English is the fallback -- until the player picks a
language from the settings sheet (the gear in the top-right corner of the game's
screens, and of the pause screen in a run), which is kept and wins from then on
(**The language the player chose**).

| File | What it is |
|---|---|
| `biogenic.pot` | The game's template: every message, with notes for the translator. Generated; do not edit. |
| `<locale>.po` | The game in one language: `fr.po` (French, the first), `pt_BR.po`. Written by hand, from the template. |
| `addons/launcher/launcher.pot` | The launcher's template, written by the template repository and replaced by every launcher sync. Copy it; do not edit it. |
| `launcher/<locale>.po` | The launcher in one language: `launcher/fr.po`. Made from `launcher.pot`. |
| `i18n.gd` | Finds both kinds of `.po` and registers them when the first game screen loads, applies the language the player chose, and lists the languages for the settings sheet. |
| `tools/i18n_pot.gd` | Writes the game's template, checks every catalog, and makes a pseudolocalized stand-in for a language. Never ships. |
| `tools/launcher_translated.tscn` | The launcher built after the catalogs are registered, for a screenshot. Never ships. |

A language is complete when it has both files, and it can ship with either one, or
half of either: a message left empty shows in English. **`fr.po` is the first game
catalog**, and the model to follow (see **A worked example**); no launcher catalog
exists yet.

## Add a language

**The game.**

1. `cp game/i18n/biogenic.pot game/i18n/de.po` (for a new language; **`fr.po` is
   French and exists**). **The file's name is the locale, in the engine's spelling**:
   a language code in lower case, then an optional script and an optional country,
   joined by `_` or `-`: `de`, `pt_BR` (or `pt-BR`), `zh_Hans`. The game and the lint
   refuse a name that is not one: `DE.po`, `de_XX.po`, `german.po`.
2. Fill the header: `"Language: de\n"` (the same locale) and `Plural-Forms:` for the
   language (French `nplurals=2; plural=(n > 1);`, German and Spanish `(n != 1)`,
   Japanese `nplurals=1; plural=0;`, Russian and Polish have three forms: look the
   rule up). **When `nplurals` is not 2, every plural message must change its
   number of `msgstr[N]` lines to match -- the empty ones too.** One plural message
   with the wrong number makes the engine refuse the whole file, and the language
   is dropped without a word on screen (measured; the lint says which message).
3. Translate: fill every `msgstr` (and `msgstr[0]`, `msgstr[1]`... for a plural).
   Read the `#.` notes: they say where a message appears, what its placeholders
   are, and how much room it has. The game's voice is lowercase; the launcher's is
   not (below). **Start with `msgid "English"`: it is not the word for English but
   the language's own name, in itself and with its own capitals** -- `Deutsch`,
   `Português (Brasil)` -- because it is the language's row in the settings sheet's
   list, where a player who reads only this language has to find it. The lint fails
   the file until it is translated, and fails `English` itself.
4. `godot --headless --path . res://tools/i18n_pot.tscn -- --lint-all` until it says
   `ALL PASS` (what it checks is below).
5. Look at it: `godot --path . --language de` (any run takes `--language`; so does
   `tools/shot.tscn`), or pick it from the settings sheet. Every screen has to be
   looked at: see **Room**.
6. Commit the file. **That is all.** No registration, no project setting: the
   language is in the settings sheet's list as soon as the file is in the folder.

**The launcher.** The same, with these differences:

1. `mkdir -p game/i18n/launcher && cp addons/launcher/launcher.pot game/i18n/launcher/fr.po`.
   **Not inside `addons/launcher/` or `ci/`**: every launcher sync replaces both
   wholesale, and a `.po` left there is deleted. (The header of `launcher.pot` says
   to put the file in `res://locale/` and register it in project.godot. Do not: the
   game reads `game/i18n/launcher/` only, and the lint fails on a `.po` anywhere
   else. **Why project.godot is the wrong place**: it is read from the APK when the
   engine starts, before BuildInfo has mounted the content pack, so a catalog
   registered there is the APK's copy, and a content pack's new or changed `.po` is
   never read. A language would cost an app install for every edit.)
2. Header as above: `Language:` and `Plural-Forms:`. The launcher's only plural
   message is "…and %d more change(s)." Under `nplurals=1` it has one `msgstr[0]`.
3. The launcher's voice is the English's: sentences, capitals and full stops. Keep
   the ellipsis `…` and the middle dot `·` where the English has them. Some msgids
   start with spaces (`"     <- installed"`): keep the spacing in the translation.
4. The launcher's words: a **content update** is a small download of the game's files
   that needs no reinstall; an **app build** is a new version of the app itself, which
   has to be installed; **patch notes** are the list of changes in a release; the
   **manifest** is the file that lists the releases the app reads, and appears in error
   messages; **GitHub** and **APK** are names and stay as they are.
5. Three words on the launcher's first screen are the game's, not the template's:
   **play**, **quit** and the line under the title (`build {build} · updates itself`).
   They are in `biogenic.pot`, so they go in the *game's* `fr.po`; keep `{build}`.

**Placeholders, for both.** Keep every `%s`, `%d`, `%.1f` and `{}` / `{name}`, and
every unit and sign beside a number (`µm`, `s`, `×`, `°`). To put two of them in
another order, **number them**: `"%2$s sur %1$s"` is fine, `"%s sur %s"` with the
meanings swapped is not (both are `%s`, so nothing can tell, and the values land
the wrong way round). Do not mix numbered and plain ones in one message. A literal
percent sign is `%%` in a message that has placeholders (`"100 %%"`; a lone `%` or
a `% ` is a script error at run time), and a plain `%` in one that has none. `{}` is
a number the game writes in a brighter tint; its order cannot change.

## A worked example: `fr.po`

`game/i18n/fr.po` is the first game catalog, and shows what a finished one is:

- **The header** says `"Language: fr\n"` and `"Plural-Forms: nplurals=2; plural=(n > 1);"`.
  French counts 0 and 1 as singular, so its rule is `n > 1` and not the template's
  `n != 1`. Its five plural messages (rays, strikes, seconds) each have `msgstr[0]`
  and `msgstr[1]`, with every `{}` kept.
- **It names itself**: `msgid "English"` is `msgstr "Français"`, with its capital,
  which is how the settings sheet lists it.
- **The words that have to fit** are short: a chip has 47 px, so the gene words are
  `mange`, `tourne`, `nage`, ...; the tray's caption `attente` ("waiting") is a word
  that also suits a fork's chip, because the template's note says the same word
  captions both.
- **What the lint made it change.** A raw control byte had stood where an en dash
  was meant (`{}<0x13>{} s`), which no editor shows and no screen draws. And a gene's
  numbers line is built from several messages, so no one message is too wide:
  at three copies the ping's line took 653 px of the 650 there are before it meets the
  Leave button, and `un ping toutes les {} s` became `ping toutes les {} s` (632 px).
- **What the lint says about it today:**

      [i18n] the lines the game composes, in English: numbers lines at most 550 px of 650, the pause caption at most 543 px of 560, a world's line at most 260 px of 280
      [i18n] game/i18n/fr.po: 302 of 304 messages translated, 2 not translated -- reported, not failed
      [i18n]   built with the game's own code: numbers lines at most 632 px of 650 (the first numbers line of ping (ampulla), at 3 copies), the pause caption at most 533 px of 560, a world's line at most 253 px of 280
      [i18n]   in the template, not in the catalog (2):
      [i18n]     "build {build} · updates itself"
      [i18n]     "quit"
      [i18n] ALL PASS: 1 catalog(s) checked

  The two it lists are the launcher's first-screen words (`launcher_config.tres`),
  which the template gained after the catalog was written. That is a catalog **behind**
  its template: reported, not failed, and the game shows those two in English until
  someone adds them (`msgid "quit"` and the tagline, as the template has them, with
  `{build}` kept). The launcher's translator can do it in the same pull request.

## The lint

    godot --headless --path . res://tools/i18n_pot.tscn -- --lint-all
    godot --headless --path . res://tools/i18n_pot.tscn -- --lint-all --strict

It reads every `game/i18n/*.po` against `biogenic.pot` and every
`game/i18n/launcher/*.po` against `addons/launcher/launcher.pot`, and **passes when
there is no `.po` at all**. CI runs the first form ("Check the translation
catalogs"); the second is for a pull request that claims a complete language.

| Fails (exit 1, `PROBLEM` lines) | Only reported (`--strict` fails on them too) |
|---|---|
| a file the engine will not load, or a name that is not a locale | a message left untranslated, or marked `fuzzy` (the engine ignores those) |
| a header whose `Language:` is not the file's locale, or whose `Plural-Forms:` is empty, unfilled or a rule the engine reads differently from its words (asked of the engine itself, for 26 counts) | a message the template has and the catalog has not: the catalog is **older** than its template |
| a plural message with a different number of `msgstr[]` forms than `nplurals`, or with only some forms filled | a message the catalog has and the template has not: the catalog is **newer**, or the message was reworded since |
| a placeholder lost, added, retyped or reordered; numbered and plain mixed; a `%` that is not a placeholder | |
| a control character in a translation, other than a line feed: a raw 0x13 where a dash was meant is invisible in an editor and a box on screen | |
| text wider than the room a message has, a placeholder measured with the widest word that can stand in it (game catalogs; see **Room**) | |
| a gene's numbers line, the pause caption, or a world's line in the world menu, wider than its room: the game's own code builds them in the language being checked | |
| a message defined twice, or translated differently by the game's catalog and the launcher's for one language (the engine takes whichever loaded last) | |
| a catalog none of whose messages is in its template (a launcher file in the game's folder, or the other way round) | |
| a `.po` anywhere but the two folders (the game never reads it, and `addons/` and `ci/` are wiped by a sync) | |
| a game catalog whose `English` is missing, empty, fuzzy or still `English`: it is the name the settings sheet lists the language under, in that language, and without it a player who reads only that language may not find their own | |

**Why a stale catalog is only reported.** The template moves ahead of every catalog
whenever a sentence is reworded or the launcher is synced, and the game then shows
that sentence in English, which works. Failing CI for it would hold every such change
-- the launcher-sync pull request, which nobody is there to fix, included -- up on
a translation. The one thing it cannot see is a typo in a msgid, which looks like
a stale message and an untranslated one at once: both are listed, so a translator
can match them.

## Update a language when a template changes

The game's template changes when a pull request rewords a sentence (it regenerates
`biogenic.pot`, below); the launcher's changes when a launcher sync brings a new
`addons/launcher/launcher.pot`. **Neither touches the catalogs and neither fails CI**:
the new or reworded messages show in English until someone updates the catalog, in a
pull request of its own.

1. After a sync: `git diff <the sync's parent> HEAD -- addons/launcher/launcher.pot`
   shows what was added, reworded or removed. Or just run the lint: it lists every
   message "in the template, not in the catalog" and "in the catalog, not in the
   template", up to 40 of each.
2. For each message the template has and the catalog lacks: add an entry, the
   `msgid` (and `msgid_plural`) copied from the template, and translate it.
3. For each message the catalog has and the template lacks: if it was **reworded**,
   change its `msgid` to the new English and check that the translation still says
   the same; if it was **removed**, delete the entry.
4. Keep `Language:` and `Plural-Forms:`. A tool such as `msgmerge` does steps 2 and 3
   but marks changed entries `fuzzy`: read them and delete the `#, fuzzy` line.
5. `--lint-all --strict` clean, commit.

## Regenerate the game's template

After adding or changing any player-facing text:

    godot --headless --path . res://tools/i18n_pot.tscn -- --write

`--check` writes nothing and exits 1 when the template is out of date, or when the
code asks for a translation the tool cannot read (CI runs it: "Check the translation
template"). The output is deterministic (no date, no line numbers), so a change that
touches no sentence does not touch the template. Godot's own editor can write a
`.pot` too, but it cannot see a sentence kept in a constant, which is where most of
this game's are: use the tool. The launcher's template is not made here: it is the
template repository's (`ci/make_pot.py` there).

## Making a string translatable

The rule: **the English is the message id, and it goes through `tr()`**.

- In a node: `tr("the English")`. With a number that changes the words:
  `tr_n("%d second", "%d seconds", n) % n`.
- Where `self` is not available (a `static func`, a `RefCounted`):
  `TranslationServer.translate("the English")`, and `translate_plural(...)`.
- A readout phrase for a gene's numbers: `Readout.item("out to {} µm", ...)`
  translates its template inside, so `{}` stays in the translated text.
  `Readout.item_n(...)` takes a singular, a plural and a count.
- A table of words in a `const`: a constant cannot call a function, so mark it
  with a `TRANSLATORS:` comment and translate where it is used with
  `tr(WORDS[gene])`. The tool lists every plain string in a marked constant, and
  refuses a `tr()` of anything it cannot read unless the expression names a marked
  constant (or the statement says `# i18n-ok:` and why).
- Text in a `.tscn` is translated by the Control that shows it, and the tool reads
  it from the scene. A scene has no place for a note: give it one from any script
  with `# TRANSLATORS "the exact text": the note`. The same goes for the words in
  `launcher_config.tres` (`play_text`, `quit_text`, `tagline`, `extra_buttons`),
  which the launcher looks up in the game's catalog: the tool reads them, and their
  notes are in `i18n.gd`.
- `# TRANSLATORS: ...` on the comment lines directly above a statement (or in a
  constant's doc comment, or above a `func`, for every message in it) becomes the
  `#.` note the translator reads, up to the first empty comment line. **Say where
  it appears, what each `%s` / `{}` is, and how much room it has.**
- `# ROOM: 440 px at 15 px` on the line below a note says how wide the text may be
  and in what size of type, for anything that does not wrap. The tool measures the
  English in the game's own font, prints it in the note, and `--lint-all` holds every
  translation to it. Give it to any message that has little room to spare. **A
  message with placeholders says what goes in them**, one word for each, after `with`:
  `# ROOM: 560 px at 14 px with word, 99` measures the text with the widest gene word
  the language has for the `%s` and `99` for the `%d`. A word is the name of a table
  (`word` is `WORDS`, `way` is `PATH_TITLES`, `copies` is `COPIES`; `FILL_TABLES` in
  the tool lists them) or the text itself, which has a digit in it (`99`, `80%`); a
  table that fills two placeholders gives its two widest, because one line never names
  the same gene twice. `--check` fails on a ROOM with too few or too many words, a word
  it does not know, a line it cannot read, and an English text wider than its own room.
- **A line the game builds from several messages has no room of its own**: a gene's
  numbers line, the pause caption, and a world's line in the world menu (its generation
  and its age). `--lint-all` builds them in each language with the game's code
  (`gene_stats.gd`: every gene, every copy count, every level and way, every body that
  changes a number; `drops.gd`: every generation phrase with the widest age), so a new
  gene is covered without being named. Their budgets are constants at the top of the
  tool (`NUMBERS_ROOM`, `CAPTION_ROOM`, `STATS_ROOM`), with the layout they come from;
  change them with the layout.
- **Translate the template first, then fill in the values**: `tr("level %d") % n`,
  never `tr("level %d" % n)`.
- **A whole sentence is one message.** Never join pieces of a sentence that were
  translated separately; give the translator the sentence with placeholders in it,
  one message for each wording (`"... yours. ..."` and `"... theirs. ..."`, not one
  sentence with a word dropped in). A line of fragments joined with ` · ` is a
  list, not a sentence, and is fine.
- **Text set from code does not follow a change of language; say it again.** The
  player can change the language with a screen open (the settings sheet), and a
  Control keeps the words it was given, not the message: `label.text = tr("x")` set
  in French stays French after a switch to English (measured,
  docs/design/settings.md §3.3). A scene's own `text = "x"` follows by itself. So a
  screen sets its words in one function -- `_say()` in mode_select.gd, `_say_page()`
  in earshot.gd, `_say_again()` in normal_mode.gd -- called from `_ready()` and again
  on `NOTIFICATION_TRANSLATION_CHANGED`, **always with `call_deferred()`**: the
  engine sends that notification while it walks the tree, which refuses a node added
  from inside it, and a node hears one as it enters the tree, before `_ready()`, so
  guard with `is_node_ready()`. Something kept to be said later is kept as *which*
  sentence (a name, a key) and translated as it is shown, never kept translated.
- **Never decide anything by reading translated text**, and never `tr()` a string
  that goes to a log: a server's console says what it said before.
- **Not translated**: a gene's scientific name (`cytostome`, `veneneux`, ...: they
  are drawn from code, never listed), the dev app's frame readout, server and
  probe output, and anything a player never sees.

## For the translator

The game's voice is lowercase, plain, and short; keep that where the language
allows it. A **cell** is the player's creature. A **gene** is a piece of its DNA
that makes it grow an **organ**, and each gene has a short word on a **chip** and
a longer scientific name that is never translated. The DNA is what a **daughter**
(one of the two cells a cell divides into) inherits; the **body** is what this
cell **wears** now: a gene is **worn** when the body shows it, **carried** when
only the DNA holds it. A **copy** is how many times a gene is in the DNA, one to
three. A **slot** is one of seven places round the body where a gene sits, and to
**place** a gene is to put it in one; a gene **waiting** has been eaten and not
placed yet. **Water** is what the cell swims in, and a friend's **water** is the
one their phone or server keeps. An **invite** is a one-line message a friend
sends by any chat app, which is pasted into the game once. The **launcher** is the
app's main menu, which installs updates. A **world** is one of the three the
player keeps: a drop of water with everything living in it, kept between launches,
and named by the player (the code calls it a drop). **A name the player typed is
never translated**; a world that has not been named wears one of the game's
default names (`pond water`, `rain barrel`...), which are translated like any
other message, and follows the language.

**Room.** Nothing in the game wraps or shrinks: a string that is too long runs into
its neighbour or off the screen, at 1280 x 720, which is the narrowest the game gets.
A message that has to fit says so in its `#.` notes -- "Room: at most 47 px in
13 px type; the English takes 44 px", measured in the game's own font -- and
`--lint-all` measures every translation against it. These are the tight ones, the
tightest first:

| What | Room | Longest English | A translation may be longer by |
|---|---|---|---|
| the pause caption with the numbers on: `genome · <generation> · <size> · <tank>`, built whole | 560 px, 15 px type | 543 px | 3 % |
| a gene's line on the pause screen (what it does) | 440 px, 15 px type | 417 px | 5 % |
| a gene's short word on a chip | 47 px, 13 px type | 44 px (`venom`) | 6 % |
| a fork card's two lines | 185 px, 14 px type | 172 px | 7 % |
| a world's line in the world menu: `<generation> · <age>`, built whole | 280 px, 15 px type | 260 px | 7 % |
| the tray's "waiting" | 64 px, 15 px type | 54 px | 18 % |
| a gene's numbers line (two to a gene), built whole | 650 px, 14 px type | 550 px | 18 % |
| a sentence on the earshot screens, one line | 1180 px, 17 px type | 982 px | 20 % |
| "numbers", the switch | 80 px, 14 px type | 61 px | 31 % |
| the replay's `leave` and speed buttons | 64 px, 17 px type | 44 px | 45 % |

The three built-whole rows have no message of their own: a gene's numbers are phrases
joined with a middle dot into two lines, centred, and a line of more than 650 px runs
into the Leave button at its left (the button's edge is 344 px from the line's middle;
650 px leaves 19 px of air). The pause caption is a label in a column 560 px wide: past
that the column, and the whole screen, shifts sideways to make room. A world's line has
the 280 px under its name in a menu row; a longer one ends in "…". The lint builds all
three with the game's own code in the language it is checking, so **every phrase counts
towards them, and each has to be about as short as its English**. The hint and
instruction rows under the figure have 560 px (430 px when a level and a gauge share the
row), and the English takes at most 355 of them, so they are roomy; they are measured
with the widest gene word in every `%s`. **In short, a translation should be no longer
than the English; French and German usually are, so the gene lines, the numbers phrases
and the cards' lines are where the work is.**

**The launcher has no limit the lint can measure honestly**, because its text wraps
or its controls grow. Measured at 1280 x 720 with every launcher message made
longer by Godot's pseudolocalizer: at twice the English length (and at three times)
everything fits -- the update bar's status text wraps onto more lines, and the
dialogs widen; at four times the bar's two buttons leave the status text a column
of about 200 px, which wraps into a dozen lines and covers the menu. So: **keep a
launcher message about as long as the English, and a button's or a dialog title's
words (they do not wrap) under twice it.** The lint measures no launcher width.

## Checking a language

- `--lint-all` as above, before anything else.
- Run each screen with `--language <locale>` at 1280 x 720 and at 2400 x 1080
  (`tools/shot.tscn`; `docs/design/gene-stats.md` section 8 has the poses).
- **The launcher, translated**: look at it through
  `tools/launcher_translated.tscn`, which loads `i18n.gd` as a game screen does and
  then builds the launcher: `godot --path . --language fr --rendering-driver opengl3
  res://tools/shot.tscn -- --scene=res://tools/launcher_translated.tscn
  --out=/tmp/launcher_fr.png`, and again with `--size=2400x1080`.
- To find where a language will not fit before it exists:
  `godot --headless --path . res://tools/i18n_pot.tscn -- --pseudo=/tmp/fr.po`
  (add `--launcher` for the launcher's template) writes the template run through
  Godot's pseudolocalizer (accents, 30 % longer, in `[brackets]`). Put that file in a
  *copy* of the project as `game/i18n/fr.po` (`game/i18n/launcher/fr.po` for the
  launcher's; never in this project: it would ship), run each screen with
  `--language fr`, and look for what is cut off or collides. Anything still in plain
  English was missed by `tr()`. `--lint-all` on the copy lists every game message
  whose measured room 30 % more text would break. (The engine's own
  `internationalization/pseudolocalization` settings do much the same, but pad the
  text of a Label a second time, so they overstate what will not fit.)

## Which screens, and the launcher's first screen

The catalogs are registered when the first game screen loads (`mode_select`,
`earshot`, `normal_mode` each preload `i18n.gd`: do not remove that line), before
any of the screen's nodes exist. A process with no screen -- the dedicated server,
every `--headless` probe -- registers nothing, so the server's log and the probes'
comparisons stay English on a machine set to any language. The one setting
project.godot carries is `internationalization/locale/fallback`, `en`: the engine's
own default, written down, so it never needs a new APK.

**The language the player chose.** The gear in the top-right corner of every game
screen -- in a run, of the pause screen -- opens the settings sheet, whose list is
English and every game catalog, each named in its own words (its `msgid "English"`).
A choice applies at once, with the sheet still open, and is kept in
`user://normal_mode.cfg` as `[app] locale`. `I18n.register()` applies the kept one
right after registering the catalogs, so the first game screen is built in it --
except in a process with no screen; when `--language` was given, so
`tools/shot.tscn --language fr` shoots French whatever this machine kept; and when
that language's game catalog has gone, when the device's is followed again. A player
who never opens the list keeps following the device. **Picking a language to look at
it changes what this machine's later runs open in**, English included: English is
then kept on a machine set to another language. Delete the `[app] locale` key to
follow the device again.

**The launcher's first screen, from binary 6 on.** `game/boot.gd` -- an autoload,
`GameBoot`, registered in project.godot after the template's two -- preloads
`i18n.gd`. Autoloads load before the main scene and after BuildInfo has mounted the
content pack, so the catalogs register and the player's saved language applies
before the launcher's first frame. The game's own words there -- play, settings, quit
and the tagline, which `launcher_config.tres` holds -- are in the chosen language from
a cold start, wherever they are translated; the launcher's own words, its update bar
and dialogs, wait for a launcher catalog in `game/i18n/launcher/`. The registration
needed a new APK (`binary_version` 6, the owner, 2026-10-01: "There's no problem
with installing a new apk"); the script and `i18n.gd` still come from the pack.

**Before binary 6 it was English on every start.** Measured with a throwaway
launcher catalog (never committed) and `--language fr`: the launcher is the main
scene, so it is built before any game script has loaded `i18n.gd`; at that moment no
catalog is registered, and the title block, the play and quit buttons, the update
bar and its buttons all read English. Once the player has pressed Play and come Back
-- a game screen has loaded, `fr` is registered, and the launcher is built again --
every launcher string is translated, `play`, `quit` and the tagline included (the
version stamp at the bottom is not text anyone translates). So a player in another
language meets an English launcher on each cold start, and a translated one from the
second time it is shown. The language the player chose waits for the same moment: it
is applied by `I18n.register()`, which has not run while the first launcher is built.

**How it was decided.** The launcher's first view translates only if the catalogs
register before its scene is built. There were three ways: a change to the template's launcher (`I18n.register()` before it
builds), the APK's own project.godot (the APK's copy of the file again), or --
measured in a scratch copy, not tried from an exported pack, and leaning on the
template's loading order -- a content-only one: point `launcher_config.tres` at a
game-owned `extends LauncherConfig` script that preloads `i18n.gd`. BuildInfo loads
that config right after mounting the pack, so the catalogs register before the
launcher exists, and the cold-start launcher translated in full. The owner first
chose to wait for the template to add a startup hook,
[sinikebe/godot-launcher-template#68](https://github.com/sinikebe/godot-launcher-template/issues/68),
then, with the settings button wanted on that screen too, the APK's project.godot:
our own autoload (`docs/design/settings.md` §1.4). #68 stays the cleaner path, and
`GameBoot` can move onto it once it lands.

## Not covered

- The dedicated server's console, and so the line an owner sends a friend: it names
  the buttons in English, whatever language the friend's game is in.
- Numbers are written with a decimal point in every language (`Readout.number`).
- Right-to-left layout is not handled, and a script the default font and the
  system's fallback fonts do not cover is untested. Word-breaking data for Thai,
  Khmer, Lao and Burmese needs `internationalization/locale/include_text_server_data`,
  which is a project setting and so a binary bump.
