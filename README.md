# Biogenic

A Godot 4.7 game, built for Android and Windows, that keeps itself up to date.

Install it once. From then on the main menu checks this repository's releases on
launch and applies whatever it finds — a new APK on Android, or just a content
pack plus a restart when the change doesn't need a new binary.

## Download

| Platform | File | Notes |
|---|---|---|
| Android | [**biogenic.apk**](https://github.com/sinikebe/biogenic/releases/latest/download/biogenic.apk) | Updates itself in place after the first install |
| Windows | [**Biogenic.exe**](https://github.com/sinikebe/biogenic/releases/latest/download/Biogenic.exe) | One self-contained file, nothing to unpack |

All builds live on the [releases page](https://github.com/sinikebe/biogenic/releases/latest),
with `SHA256SUMS` alongside them if you want to verify a download.

On Android the first install needs "install unknown apps" allowed for whichever
app opens the APK — your browser or your file manager. Later updates are handled
by the game itself, which asks for that permission once.

## How updating works

The release feed carries two version numbers, and the app compares both:

- **binary version** — bumped by hand when a change can only ship as a new
  APK/EXE: a Godot upgrade, a new permission, a native plugin, a new icon.
- **content version** — bumped automatically on every release. Scenes, scripts,
  art, audio, tuning. These ship as a `.pck` that the app downloads and mounts
  at the next launch, with no reinstall.

A new binary always wins over a pending content pack, since the binary carries
its own content with it. Every download is checked against the SHA-256 in the
manifest before anything is installed, and a mismatch is discarded.

[docs/UPDATES.md](docs/UPDATES.md) covers the mechanism in full, including how
to release a change and how to set up release signing.

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
| [scenes/main_menu.tscn](scenes/main_menu.tscn) | The menu |
| [scripts/main_menu.gd](scripts/main_menu.gd) | Menu wiring and the update UI |
| [scripts/update_service.gd](scripts/update_service.gd) | Autoload — checks, downloads, verifies, installs |
| [scripts/build_info.gd](scripts/build_info.gd) | Autoload — build identity; mounts content packs at startup |
| [scripts/android_bridge.gd](scripts/android_bridge.gd) | Android install-intent and restart helpers |
| [scripts/build_version.gd](scripts/build_version.gd) | Generated at build time; committed copy holds dev defaults |
| [ci/](ci/) | Build scripts, shared by CI and usable locally |
| [version.json](version.json) | The one file you edit to bump a version |

### Adding the game

`MainMenu.GAME_SCENE` in [scripts/main_menu.gd](scripts/main_menu.gd) is empty.
Point it at your first scene and **Play** will load it; until then the button
explains itself instead of failing quietly.

## Releasing

Merge to `main`. That's the whole flow — the
[release workflow](.github/workflows/release.yml) exports the APK, the Windows
executable and both content packs, writes `manifest.json`, and publishes them as
the latest release. Players pick it up on their next launch.

Bump `binary_version` in [version.json](version.json) in the same commit whenever
the change needs a new binary; leave it alone and the release goes out as a
content-only update.
