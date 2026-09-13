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
new icon. Everything else goes out as content.

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

## There is no Godot binary here

No editor, no import, no headless boot, no screenshot. Scenes and resources are
hand-written as Godot 4.7 text format and reasoned about, never run locally.

CI (`.github/workflows/ci.yml`) imports and headless-boots the project. That is
the first time anything actually executes, so:

- Every `ext_resource` path must exist — `ls` it, do not assume.
- `load_steps` must equal the number of resource entries plus one; `format=3`.
- Nothing in `_ready()` may assume a window, an input device or a network.

## Engine constraints

Godot 4.7, **GL Compatibility** renderer on both targets — no Forward+ only
features. No C#, no addons, no native plugins: each of those forces a new binary.
Base viewport 1280x720, `canvas_items` stretch, `expand` aspect. Android is
**landscape-locked**: `window/handheld/orientation=4` is `SCREEN_SENSOR_LANDSCAPE`,
which flips between the two landscape directions and never reaches portrait (full
sensor is `6`). Do not build portrait-specific layout for a mode the app cannot
enter. Touch targets stay at 48px minimum.

## The game

Game code lives in `game/`. `play_scene` in `launcher_config.tres` points the
launcher's Play button at its entry scene. Design specs live in `docs/design/`.
