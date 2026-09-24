# Biogenic

A Godot 4.7 game, built for Android and Windows, that keeps itself up to date.

Install it once. From then on the launcher checks this repository's releases on
launch and applies whatever it finds — a new APK on Android, or just a content
pack plus a restart when the change doesn't need a new binary.

## Download

| Platform | File | Notes |
|---|---|---|
| Android | [**biogenic.apk**](https://github.com/sinikebe/biogenic/releases/latest/download/biogenic.apk) | Updates itself in place after the first install |
| Windows | [**Biogenic.exe**](https://github.com/sinikebe/biogenic/releases/latest/download/Biogenic.exe) | One self-contained file, nothing to unpack |
| Linux server | [**install-server.sh**](https://github.com/sinikebe/biogenic/releases/latest/download/install-server.sh) | Hosts the shared pond on your home Wi-Fi, headless, and updates itself: [docs/server.md](docs/server.md) |

All builds live on the [releases page](https://github.com/sinikebe/biogenic/releases/latest),
with `SHA256SUMS` alongside them if you want to verify a download.

On Android the first install needs "install unknown apps" allowed for whichever
app opens the APK — your browser or your file manager. Later updates are handled
by the game itself, which asks for that permission once.

## The launcher

The main menu, the updater and the release pipeline are **not maintained here**.
They come from [`sinikebe/godot-launcher-template`](https://github.com/sinikebe/godot-launcher-template)
and land in this repo under `addons/launcher/` and `ci/`.

> **Do not edit `addons/launcher/` or `ci/` in this repo.** The sync job replaces
> both wholesale, so any change there is silently reverted on the next run. Fix
> the launcher in the template instead; it flows back here automatically.

Everything Biogenic-specific about the launcher — title, tagline, background,
button placement, which repo to poll — lives in
[launcher_config.tres](launcher_config.tres). The
[template README](https://github.com/sinikebe/godot-launcher-template#making-it-yours)
documents every field.

[.github/workflows/sync-launcher.yml](.github/workflows/sync-launcher.yml) runs
daily, pulls the template, boots the project to prove it still loads, and opens
a pull request if anything changed. Merging it releases to players, so it stops
short of that on purpose.

## How updating works

The release feed carries two version numbers, and the app compares both:

- **binary version** — bumped by hand in [version.json](version.json) when a
  change can only ship as a new APK/EXE: a Godot upgrade, a new permission, a
  native plugin, a new icon.
- **content version** — bumped automatically on every release. Scenes, scripts,
  art, audio, tuning. These ship as a `.pck` that the app downloads and mounts
  at the next launch, with no reinstall.

A new binary always wins over a pending content pack, since the binary carries
its own content with it. Every download is checked against the SHA-256 in the
manifest before anything is installed, and a mismatch is discarded.

Each update comes with patch notes, shown before the download starts and
readable at any time from **What's new**, including offline.

The full mechanism — and how to set up Android release signing — is documented in
[the template's docs/UPDATES.md](https://github.com/sinikebe/godot-launcher-template/blob/main/docs/UPDATES.md).

## Developing

Open the project with **Godot 4.7** — no C#, no extra addons.

```
godot --path . --import     # first time only
godot --path .              # run it
```

A local run reports itself as version `0` for both binary and content, so it
always considers any published release newer. That's deliberate: it makes the
update path easy to exercise while developing.

### Layout

| Path | |
|---|---|
| [launcher_config.tres](launcher_config.tres) | **Everything you change about the launcher** |
| [version.json](version.json) | The one file you edit to bump a version |
| `addons/launcher/` | Synced from the template — do not edit |
| `ci/` | Synced from the template — do not edit |
| [build_version.gd](build_version.gd) | Generated at build time; the committed copy holds dev defaults |

### Adding the game

`play_scene` in [launcher_config.tres](launcher_config.tres) is empty. Point it
at your first scene and **Play** will load it; until then the button explains
itself instead of failing quietly. To take the action over entirely, connect the
launcher's `play_requested` signal.

## Releasing

Merge to `main`. That's the whole flow — the
[release workflow](.github/workflows/release.yml) exports the APK, the Windows
executable and both content packs, writes `manifest.json`, and publishes them as
the latest release. Players pick it up on their next launch.

Bump `binary_version` in [version.json](version.json) in the same commit whenever
the change needs a new binary; leave it alone and the release goes out as a
content-only update.
