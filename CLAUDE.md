# Biogenic

A Godot 4.7 game for Android and Windows that updates itself from this
repository's GitHub releases.

## Git workflow — no exceptions

- **`main` is the only branch that matters.** Work is never left sitting on a
  feature branch. Every task ends committed, pushed, and merged to `main`.
- **Never leave anything local.** Uncommitted or unpushed work does not exist.
  A clean tree and a merged branch are the definition of done, not a tidy-up.
- **Work that comes from an issue gets a pull request that closes it.** Open the
  PR as though the branch had been created from the issue itself, and put a
  `Closes #N` line in the body so merging closes the issue. Closing keywords are
  only honoured when the PR targets the default branch — ours always do.
  The cross-repository form (`Closes owner/repo#N`) links the two, but closing
  still needs write access on that repository. We have none on the template, so
  a template issue is closed by hand over there — never by a merge here.
- **Check for a pending launcher upgrade immediately before every merge.** Look
  for an open `launcher-sync` pull request, or compare the `commit` in
  `addons/launcher/.launcher-sync.json` against the template's `main`. If one is
  waiting, do not merge past it: take the new launcher, re-test your own changes
  against it, fix whatever broke, and merge the two together. Merging your work
  first and syncing afterwards means the combination ships to players untested —
  the launcher is most of what the app *is*, so "it worked before the sync" is
  not evidence about the release you are actually cutting.

### What a merge costs

Merging to `main` **publishes a release to players.**
`.github/workflows/release.yml` exports the APK, the Windows executable and both
content packs, writes `manifest.json`, and publishes them as the latest release.
Installed games pick it up on their next launch. There is no staging environment
and no manual gate.

So the review happens *before* the merge. There is no "fix it in the next one"
that does not also ship.

Bump `binary_version` in `version.json` in the same commit when a change cannot
ship as a content pack: an engine upgrade, a new permission, a native plugin, a
new icon, or a launcher sync that moves `build_info.gd` (see below). Everything
else goes out as content.

## The launcher is not ours

`addons/launcher/` and `ci/` are synced wholesale from
[`sinikebe/godot-launcher-template`](https://github.com/sinikebe/godot-launcher-template)
by `.github/workflows/sync-launcher.yml`. **Editing either is pointless and
expensive** — the next sync reverts it silently, and you find out a release
later.

**The template repository is read-only to this project.** No commits, no pull
requests, no clones, ever. A launcher bug is communicated by **filing a GitHub
issue against the template**. That is the only channel.

`.github/workflows/` cannot be synced either — a `contents`-scoped token cannot
write it — so the sync job only reports drift there and copying across is manual.

Everything Biogenic-specific about the launcher lives in `launcher_config.tres`.

### A sync does not reach an installed game on its own

`addons/launcher/` rides in the content pack, so most of a synced launcher
arrives with the next content update. `build_info.gd` does not. It is autoload
number one *because* it mounts the pack, so it is compiled from the binary
before the pack exists, and the `launcher_version.gd` it `preload`s resolves at
that same moment. That is why the stamp in the corner names the launcher the
**APK was built with**, never the one actually running.

`UpdateService` offers a new binary only when the manifest's `binary_version`
exceeds the installed one — never on a commit, a date, or a launcher version. So
a sync that moves `build_info.gd` needs `binary_version` bumped in the same
merge, or that one file stays frozen on every installed device for good.

It has already happened: an APK built on 14 September carried launcher 1.0.0,
the sync to 2.1.0 landed hours later and shipped as content, and five days on
the phone was running 2.1.0 everywhere except the file that prints the version —
so it still read `launcher 1.0.0 · 15fe20fd`. Nothing was broken, but nothing
could have fixed it either: no content pack can replace that file.

## Run it. Do not guess.

Godot 4.7 runs here and `xvfb` is installed, so the project can be imported,
booted and **photographed** locally. Install the editor once:

```
curl -fsSL -o /tmp/godot.zip \
  https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip -q -o /tmp/godot.zip -d /tmp/g && mkdir -p ~/godot
mv /tmp/g/Godot_v4.7-stable_linux.x86_64 ~/godot/godot && chmod +x ~/godot/godot
```

Then import once, and screenshot any scene:

```
xvfb-run -a ~/godot/godot --path . --import
xvfb-run -a -s "-screen 0 1280x720x24" ~/godot/godot --path . \
    --rendering-driver opengl3 res://tools/shot.tscn -- \
    --out=/tmp/shot.png --wait=3.0
```

`tools/shot.gd` takes `--scene=`, `--out=`, `--wait=` and `--size=WxH`; it
defaults to the launcher and is excluded from export, so it never ships. Shoot
at 1280x720 **and** at 2400x1080 — phone-shaped is where layout breaks.

Pass `--rendering-driver opengl3`: this container has no Vulkan, and the project
is GL Compatibility anyway. Audio fails to open and falls back to a dummy
driver; that is the container, not a bug.

### Comparing two frames? Pass `--seed=` — and prove it first

`tools/drive.gd --seed=` is what makes a run reproducible, and for five phases
it did not cover the membrane: `signal_bus.gd` jitters the beat and the taste
bearing off a **private** generator, on purpose, and a private generator that
nothing seeds is a private generator nothing can repeat. Three byte-identical
runs of one `--freeze-at` command differed by up to **34.9% of the frame**.
`--seed=` now seeds the bus as well.

So, before any A/B: **render the frame three times and diff it.** If it is not
0 differing pixels, whatever you were about to measure is smaller than the
noise. `docs/design/perception.md` §4.1 is the long version and the numbers.

### Nothing is done until someone has looked at it

A screenshot is the evidence. "The code looks right" is not, and neither is a
green CI boot — the project can import, run and still be ugly or unreadable.
This binds the UX/UI role especially: a screen is finished when it has been
rendered and judged to look good, at both shapes.

Check the harness itself when a shot looks wrong. Its first version forced
`content_scale_size`, which overrode the project's `expand` stretch and rendered
1:1 — inventing a layout bug that did not exist.

### Still true, because CI is what ships

- Every `ext_resource` path must exist — `ls` it, do not assume.
- `load_steps` must equal the number of resource entries plus one; `format=3`.
- Nothing in `_ready()` may assume a window, an input device or a network:
  `.github/workflows/ci.yml` boots the project headless, with no display.

## Engine constraints

Godot 4.7, **GL Compatibility** renderer on both targets, which rules out
Forward+ only features. Two reasons, both worth knowing before anyone proposes
changing it: Forward+ needs Vulkan, which costs real Android device coverage on
older and cheaper handsets; and this container has no Vulkan at all, so a
Forward+ feature could not be photographed, CI-booted or measured here — it would
ship on the strength of somebody's opinion. Base viewport 1280x720,
`canvas_items` stretch, `expand` aspect.

**C#, third-party addons, GDExtensions and Android Kotlin plugins are not
forbidden. They are expensive, and the player pays.** None of them can ride in a
content pack: a pack is GDScript and resources mounted over `res://`, and
Android's linker only loads native libraries out of the APK's own `lib/`. So each
one moves `binary_version`, which means the player must accept an *install*
rather than take a content update — and a refused Android install strands them in
`NEEDS_PERMISSION` with no way back but a manual reinstall.

Three costs that are not obvious until you are paying them:

- **A GDExtension is compiled per platform and per architecture.** This APK ships
  `arm64-v8a` and `armeabi-v7a`, and Windows needs `x86_64`. That is an NDK,
  `godot-cpp`, and a build step CI does not have.
- **It is pinned to the engine.** `godot-cpp` must match 4.7, so an engine
  upgrade recompiles everything.
- **A Kotlin plugin needs Godot's custom Android build** — the Gradle path, an
  `android/build` directory in the project, and a changed export pipeline.

Reach for one when it is the right answer, and say in the commit why nothing
cheaper would do. An Android foreground service is exactly that case: it is the
only way a phone host survives the screen going off, because
`GodotGLRenderView.onActivityStopped()` calls `pauseGLThread()` and the whole
main loop stops — `multiplayer->poll()` included. No amount of GDScript reaches
that.

C# is the one still worth arguing against on its merits rather than its price: it
needs the .NET export template, which is a different engine binary, and Android
is its weakest target. Android is
**landscape-locked**: `window/handheld/orientation=4` is `SCREEN_SENSOR_LANDSCAPE`,
which flips between the two landscape directions and never reaches portrait (full
sensor is `6`). Do not build portrait-specific layout for a mode the app cannot
enter. Touch targets stay at 48px minimum.

## Putting a decision to the owner

Some calls are not ours: names, balance numbers that can only be judged by
playing, and anything that changes what the game *is*. When work stops on one of
those, present it as a table, never as prose:

| # | Question | Options | What it means |
|---|---|---|---|
| 1 | The short question | Each option, with **✓ recommended** on one | The same thing again in plain words, no jargon |

One row per decision. Always recommend one option and say which — an unmarked
list makes the owner do the analysis twice. The last column exists so the
decision can be made without reading the spec: say what actually changes for the
player, not what changes in the code.

Keep the nuance under the table, not inside it. A blocker that needs three
paragraphs to explain is usually two decisions wearing one coat.

## Realism is a tool, and gameplay is the point

**Gameplay decides. Where realism serves it, use realism.** Those are not in
tension most of the time, and when they are, the game wins — but reaching for
the real answer first is usually cheaper than inventing one, and it is usually
better.

This is a description of what already works here, not a new direction:

- The steering organ was going to be `kinety` until someone checked. A kinety is
  the ciliature that *swims*, which this design gives to `flagellum`; the organ
  that actually steers is a `cirrus`, and it is a tuft — which is exactly what
  the renderer was already drawing. The real answer was also the clearer one.
- The radar gene is `ampulla`, after the ampullae of Lorenzini, which are real
  electroreception. A shark's sixth sense is nature's radar, so the name costs
  nothing to learn and explains the mechanic on sight.
- The laser is `ocellus`, a real eyespot, carrying an ability no eyespot has.
  That is the pattern: **map an invented ability onto a real organ**, rather
  than invent a name to go with it.
- Defence needed no new genes, because a cell that turns its nose onto an
  attacker is already harder to bite. The biology handed the mechanic over.

Where it does not serve, drop it without apology. Cells do not fire lasers, a
run is not a life cycle at real timescales, and nothing here is a simulation of
anything. The test is always *does this make the game better to play* — realism
is one of the better ways to answer yes, not a constraint on the answer.

A useful consequence: when a mechanic needs a name, look up what the real
organelle is called before making one up. When a mechanic feels arbitrary, ask
what a real cell does about that problem. Often there is an answer, and it is
more interesting than the invented one.

## The game

Game code lives in `game/`. `play_scene` in `launcher_config.tres` points the
launcher's Play button at its entry scene. Design specs live in `docs/design/`.
