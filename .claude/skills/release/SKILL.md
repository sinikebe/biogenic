---
name: release
description: Ship everything on `dev` to players as one release with one patch note. Opens the pull request from `dev` to `main`, checks the whole bundle quickly, shows the owner the patch note players will read, checks for a pending launcher upgrade, and merges. Use it only when the owner asks for a release ("/release", "release", "ship it", "put it out"). A release reaches every player's device on their next launch, so never start one on your own.
disable-model-invocation: true
---

# Release

`dev` is where work lands; `main` is what players have (CLAUDE.md, "Git
workflow"). A release is the one pull request that moves everything on `dev`
since the previous release into `main`. Merging it runs
`.github/workflows/release.yml`, which builds and publishes the release every
installed game picks up on its next launch, the dedicated server included.

Every change in it was already reviewed in its own pull request into `dev`, and
the owner has played it on the dev app. So this is a **quick check that the
bundle is whole and safe to publish**, not a second review of each change. Do
not reopen design questions or restyle code here. If something blocks, stop and
say what: a fix goes to `dev` through its own pull request, never onto the
release.

The owner asking for the release is the go-ahead. Merge when the checks below
pass, and stop without merging when one does not.

## 1. Is there anything to release?

```
git fetch origin main dev --tags
git log --oneline origin/main..origin/dev
git log --oneline --no-merges origin/dev..origin/main
```

- **Nothing in the first list:** tell the owner there is nothing to release, and
  stop.
- **Anything in the second list** means `main` got a commit that is not a
  release, which should never happen. Stop and tell the owner; do not paper over
  it by merging.

## 2. A launcher upgrade waiting?

Never release past a pending launcher upgrade (CLAUDE.md, "Git workflow"). It is
waiting if either is true:

- an open pull request from the `launcher-sync` branch exists;
- the `commit` in `addons/launcher/.launcher-sync.json` on `dev` differs from
  `git ls-remote https://github.com/sinikebe/godot-launcher-template refs/heads/main`.

If one is waiting: take it into `dev` the usual way (its pull request targets
`dev`, and merges once CI is green), tell the owner it is on the dev app, and
stop. The release waits until they have played it.

## 3. The patch note

`ci/collect_changes.sh` builds the release's patch note from the subject line of
every non-merge commit since the previous release tag. It drops lines starting
with `bump `, `chore`, `ci:`, `wip`, `merge ` or `revert ` (case-insensitive).
Preview exactly what players will read:

```
prev="$(git tag --list 'v*+*' | awk -F'+' 'NF==2 && $2 ~ /^[0-9]+$/ {print $2"\t"$0}' \
  | sort -n -k1,1 | tail -1 | cut -f2-)"
git log --no-merges --pretty=format:%s "$prev..origin/dev" \
  | grep -viE '^(bump |chore|ci:|wip|merge |revert )' | grep -v '^[[:space:]]*$'
```

- **Each line is the squash title of one pull request into `dev`,** so the note
  is one entry listing every change. Nothing here can reword a line: history is
  not rewritten. If one reads badly for a player, say so in the report. The fix
  is care with the next titles, not a rewrite.
- **Empty preview** (every change is a `chore`): do not release. A release with
  no player-facing line wipes the patch-note history players carry
  (sinikebe/godot-launcher-template#51). Tell the owner, and stop.

## 4. Look at the whole, quickly

Only what a bundle can get wrong that no single pull request could:

- **`binary_version`.** Compare `version.json` on `main` and `dev`. It must have
  gone up if anything in the bundle needs a new app build: an engine upgrade
  (`GODOT_VERSION` in the workflows), a new permission (`export_presets.cfg`), a
  native plugin, a new icon, or a launcher sync that moved
  `addons/launcher/build_info.gd`. A missing bump is a blocker.
- **The launcher's files.** `git diff --stat origin/main...origin/dev --
  addons/launcher ci` must show only what launcher syncs brought.
- **Nothing personal.** Skim `git diff origin/main...origin/dev` for real
  addresses, hostnames, emails and keys. Documentation addresses (192.0.2.x,
  198.51.100.x, 203.0.113.x, 2001:db8::), loopback, and the test namespace's
  10.77.0.5 are fine.
- **The protocol.** If `Wire.PROTOCOL` in `game/net/wire.gd` changed, updated
  and not-yet-updated players refuse each other until everyone has the release.
  Say so in the report.

## 5. Open the pull request

Base `main`, head `dev`, titled `Release YYYY-MM-DD`. The body, for the owner:

- **The patch note**, exactly as previewed in step 3.
- **Binary or content:** a new app build that players must install, or a content
  update that arrives on its own. If it is a binary release, say so in one line:
  the dedicated server also replaces its executable once its pond is empty.
- **The issues it ships.** Every `Closes #N` found in
  `git log --format=%B "$prev..origin/dev"` goes in as its own `Closes #N`
  line. GitHub closes each one when the release reaches `main`, if merging into
  `dev` has not already.
- **Anything step 4 flagged.**
- **If the dev app did not exist for this release** (before
  sinikebe/godot-launcher-template#54 landed): the release was not tried on a
  device.

Wait for CI on the pull request. `Export check` must pass: it builds exactly
what the release will publish. `github-advanced-security` fails on every pull
request here, from GitHub's own model error, and is not a blocker.

## 6. Merge

Check step 2 again immediately before merging. Then merge with a **merge
commit**, never squash or rebase, titled `Release YYYY-MM-DD (#N)`:

- **A squash would collapse the whole release into one line of patch note,**
  and cut `main`'s history off from `dev`'s, so the next release would show
  this one's changes again.
- **A merge commit keeps each change's line,** and is itself left out of the
  note.

If the repository refuses merge commits, stop and ask the owner to allow them
(Settings → General → Pull Requests → "Allow merge commits"). Do not squash
instead.

**Then make sure `dev` still exists.** This repository deletes a pull request's
head branch when it merges, and the head of a release is `dev`. If
`git ls-remote origin refs/heads/dev` comes back empty, put it back where it
was, at the release's second parent:

```
git fetch origin main
git push origin "$(git rev-parse origin/main^2):refs/heads/dev"
```

## 7. Confirm it shipped

- The `Release` workflow run for the merge commit on `main` succeeds.
- The new release is the latest one, and its `manifest.json` lists the patch
  note previewed in step 3.
- Tell the owner, plainly:
  - the release's tag;
  - whether players take an install or a content update;
  - the patch note;
  - the issues it closed;
  - anything step 4 flagged.
