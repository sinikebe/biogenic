# Languages

Biogenic is written in English, and every sentence a player reads goes through
Godot's gettext translation with **the English itself as the message id**: there
are no keys. A language is **one file in this folder**. The device's language
picks it, and English is the fallback.

| File | What it is |
|---|---|
| `biogenic.pot` | The template: every message, with notes for the translator. Generated; do not edit. |
| `<locale>.po` | One language: `fr.po`, `pt_BR.po`. Written by hand, starting from the template. |
| `i18n.gd` | Finds the `.po` files and registers them when the first game screen loads. |
| `tools/i18n_pot.gd` | Writes the template, checks it and the `.po` files, and makes a pseudolocalized stand-in for a language. Never ships. |

## Add a language

1. `cp game/i18n/biogenic.pot game/i18n/fr.po`. **The file's name is the locale**:
   `fr`, `pt_BR`, `zh_Hans`.
2. Fill the header: `"Language: fr\n"` and `Plural-Forms:` for the language
   (French `nplurals=2; plural=(n > 1);`, German and Spanish `(n != 1)`, Japanese
   `nplurals=1; plural=0;`, Russian and Polish have three forms: look the rule
   up). **A `.po` with a plural message and no valid `Plural-Forms` does not load
   at all**: the whole language is dropped, with one warning in the log.
3. Translate: fill every `msgstr` (and `msgstr[0]`, `msgstr[1]`... for a
   plural). A message left empty shows in English, so a language can ship
   half-done. Read the `#.` notes: they say where a message appears, what its
   placeholders are, and how much room it has.
4. Check it: `godot --headless --path . res://tools/i18n_pot.tscn -- --lint-po`
   (a placeholder lost or reordered, a header left blank, a message that is no
   longer in the template).
5. Look at it: `godot --path . --language fr` (any run takes `--language`; so
   does `tools/shot.tscn`). Every screen has to be looked at: see **Room** below.
6. Commit the file. **That is all.** No registration, no project setting.

**Why there is no registration step.** A `.po` can be listed in Project Settings
> Localization, and that works for a build, but a content pack mounts over the
binary *after* the engine has read its settings (measured: the pack's
`project.binary` is not read again). A language registered there would need a
new APK, which is a `binary_version` bump for a text file. `i18n.gd` finds the
files at run time instead, so a language travels in the content pack like any
other file under `game/`. Registering one in project.godot as well is harmless.
The one setting project.godot does carry is `internationalization/locale/fallback`,
`en`: a device whose language has no file here reads English. It is the engine's own
default, written down, so it never needs a new APK.

**Which screens and which processes.** The catalog is registered when the first
game screen loads (`mode_select`, `earshot`, `normal_mode` each preload
`i18n.gd`: do not remove that line), before any of the screen's nodes exist.
A process with no screen -- the dedicated server, every `--headless` probe --
registers nothing, so the server's log and the probes' comparisons stay English
on a machine set to any language. The launcher's own screens come before the game
and are not covered here.

## Regenerate the template

After adding or changing any player-facing text:

    godot --headless --path . res://tools/i18n_pot.tscn -- --write

`--check` writes nothing and exits 1 when the template is out of date, or when the
code asks for a translation the tool cannot read. The output is deterministic (no
date, no line numbers), so a change that touches no sentence does not touch the
template. Godot's own editor can write a `.pot` too, but it cannot see a sentence
kept in a constant, which is where most of this game's are: use the tool.

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
  with `# TRANSLATORS "the exact text": the note`.
- `# TRANSLATORS: ...` on the comment lines directly above a statement (or in a
  constant's doc comment, or above a `func`, for every message in it) becomes the
  `#.` note the translator reads, up to the first empty comment line. **Say where
  it appears, what each `%s` / `{}` is, and how much room it has.**
- `# ROOM: 440 px at 15 px` on the line below a note says how wide the text may be
  and in what size of type, for anything that does not wrap. The tool measures the
  English in the game's own font, prints it in the note, and `--lint-po` holds every
  translation to it. Give it to any message that has little room to spare.
- **Translate the template first, then fill in the values**: `tr("level %d") % n`,
  never `tr("level %d" % n)`.
- **A whole sentence is one message.** Never join pieces of a sentence that were
  translated separately; give the translator the sentence with placeholders in it,
  one message for each wording (`"... yours. ..."` and `"... theirs. ..."`, not one
  sentence with a word dropped in). A line of fragments joined with ` · ` is a
  list, not a sentence, and is fine.
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
placed yet. **Water** is the game world, and a friend's **water** is the shared
world their phone or server keeps. An **invite** is a one-line message a friend
sends by any chat app, which is pasted into the game once. The **launcher** is the
app's main menu, which installs updates.

Keep every placeholder -- `%s`, `%d`, `{}` -- and their order, and every unit and
sign beside a number (`µm`, `s`, `×`, `°`, `%`). `{}` is a number the game writes
in a brighter tint.

**Room.** Nothing wraps or shrinks: a string that is too long runs into its
neighbour or off the screen, at 1280 x 720, which is the narrowest the game gets.
A message that has to fit says so in its `#.` notes -- "Room: at most 47 px in
13 px type; the English takes 44 px", measured in the game's own font -- and
`--lint-po` measures every translation against it. These are the tight ones, the
tightest first:

| What | Room | Longest English | A translation may be longer by |
|---|---|---|---|
| a gene's line on the pause screen (what it does) | 440 px, 15 px type | 417 px | 5 % |
| a gene's short word on a chip | 47 px, 13 px type | 44 px (`venom`) | 6 % |
| a fork card's two lines | 185 px, 14 px type | 172 px | 7 % |
| the tray's "waiting" | 64 px, 15 px type | 54 px | 18 % |
| a sentence on the earshot screens, one line | 1180 px, 17 px type | 982 px | 20 % |
| "numbers", the switch | 80 px, 14 px type | 61 px | 31 % |
| the replay's `leave` and speed buttons | 64 px, 17 px type | 44 px | 45 % |

Two more that no single message owns. A gene's numbers are phrases joined into
two lines, and a line has about 650 px before it meets the column at its left:
the longest English one takes 540 px. And the pause screen's caption, which has
560 px with the numbers on (English: up to about 540): past that the whole screen
shifts sideways to make room. **In short, a translation should be no longer than
the English; French and German usually are, so the gene lines and the cards'
lines are where the work is.**

## Checking a language

- `--lint-po` as above, before anything else.
- Run each screen with `--language <locale>` at 1280 x 720 and at 2400 x 1080
  (`tools/shot.tscn`; `docs/design/gene-stats.md` section 8 has the poses).
- To find where a language will not fit before it exists:
  `godot --headless --path . res://tools/i18n_pot.tscn -- --pseudo=/tmp/fr.po`
  writes the template run through Godot's pseudolocalizer (accents, 30 % longer,
  in `[brackets]`). Put that file in a *copy* of the project as `game/i18n/fr.po`
  (never in this one: it would ship), run each screen with `--language fr`, and look
  for what is cut off or collides. Anything still in plain English was missed by
  `tr()`. `--lint-po` on the copy lists every message whose measured room 30 % more
  text would break. (The engine's own `internationalization/pseudolocalization`
  settings do much the same, but pad the text of a Label a second time, so they
  overstate what will not fit.)

## Not covered

- The launcher's own screens (`addons/launcher/`): the template owns them.
- The dedicated server's console, and so the line an owner sends a friend: it names
  the buttons in English, whatever language the friend's game is in.
- Numbers are written with a decimal point in every language (`Readout.number`).
- Right-to-left layout is not handled, and a script the default font and the
  system's fallback fonts do not cover is untested. Word-breaking data for Thai,
  Khmer, Lao and Burmese needs `internationalization/locale/include_text_server_data`,
  which is a project setting and so a binary bump.
