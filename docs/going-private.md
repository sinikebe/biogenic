# Going private: the plan, on hold

The owner, 2026-10-16:
- *"I plan to pass the repo private soon. We need to integrate a git token to
  keep getting updates. Unless there's another way"*;
- then *"Okay for the second public repo containing only the releases"*, and
  *"LXC runner, and release now"*;
- then *"I can't set the runner yet. You'll have to hold this up while we keep
  working on genes"*.

**Status: waiting on the template** (§3, step 2). The runner is up, the releases
repository and its token exist, and the template issue is filed. The repository is
still public, and every installed game still updates from it.

## 1. Decided

| # | Question | Answer | What it means |
|---|---|---|---|
| 1 | Once the code is private, how do installed games find updates? | **A second, public repository that holds only the releases** | Each release's APK, executable, content packs and manifest are published to a public repo with no code in it. Players need no token, and the token that publishes stays in Actions secrets. |
| 2 | Where does CI run once the code is private? | **A self-hosted runner in an LXC container** (docs/ci-runner.md) | The checks, their logs and their builds stay private, and use no hosted minutes. |
| 3 | Release first? | **Yes:** `v0.2.0+220`, 2026-10-16 | It went out while the repo was public. |

**Why not a token in the app:**
- anyone can pull it out of the APK;
- on GitHub, a token that can read a private repository's releases can read all of
  its code, because releases fall under the "Contents" permission;
- when it expires or is revoked, every installed game stops updating for good,
  because the update is what would carry a new one.

## 2. Done

- **The runner switch** (pull request #220). Jobs start from no saved data, and
  docs/ci-runner.md is the container's setup guide.
- **The runner, for everything** (2026-10-16, the owner: *"Set it for dev and
  trigger ci"*, then *"I think we'll move it back to my self hosted runner
  entirely"*). Every check and every publish runs on the self-hosted runner, and
  only a fork's pull request on GitHub's machines (docs/ci-runner.md §1). A
  publish takes about 20 minutes from there, because the upload to GitHub's
  release server is slow (docs/ci-runner.md §6).
- **The template issue**, filed 2026-10-16 as
  [godot-launcher-template#93](https://github.com/sinikebe/godot-launcher-template/issues/93)
  (§4 is its text).
- **The public releases repository**, `sinikebe/biogenic-releases`, created by the
  owner on 2026-10-16 with one commit, so that `gh release create` can tag it.
- **Its token**: the Actions secret `RELEASE_TOKEN` on this repository, set by the
  owner on 2026-10-16, a fine-grained token that can write to the releases
  repository only. Nothing has used it yet: the first publish there is its test,
  and that is the dev app's, which no player sees.

## 3. To do, in this order

1. **The runner.** Done (§2).
2. **The template**, issue #93 (§4 below). The template's release scripts publish
   to the repository they run in, and work out the patch note from that
   repository's tags, so publishing elsewhere is theirs to support. Then the
   launcher sync brings it here, and `release.yml` passes it `biogenic-releases`
   and `RELEASE_TOKEN`.
3. **The public releases repository and its token.** Done (§2).
4. **The switch, in a release.** Once the template supports it, `update_repo` in
   `launcher_config.tres` points at the new repo. So does `REPO` in
   `server/install-server.sh` (and the two URLs in its header). That ships as a
   release while this repo is still public.
5. **Wait.** Every installed copy has to launch once on that release to learn
   the new address, the owner's dev app included. A copy that does not will never
   see another update, and will need a manual reinstall.
6. **Then** the repository goes private.

**What going private hides, and what it does not.** It hides the history, the
design docs, the tools, the issues and work in progress. It does not hide the
game's own scripts: they ship inside every APK and content pack, where they can
be extracted, as they can today.

## 4. The template issue (#93)

Filed 2026-10-16 as
[godot-launcher-template#93](https://github.com/sinikebe/godot-launcher-template/issues/93),
and the issue is the text. In short, it asks the release scripts for:

- a release repository apart from the code's (`RELEASE_REPO`, defaulting to the
  repository they run in), with its own token (`RELEASE_TOKEN`), for the
  publish, the manifest's URLs, the previous release's manifest and the dry run;
- the version tag pushed to the code repository too, at the released commit, or
  the next patch note has no "since";
- a word on the one commit a releases-only repository needs before its first
  release.

It also passes on the runner's slow upload to GitHub's release server, and
`MAX_CHANGES_PER_ENTRY = 20` cutting a 22-line release to 20 lines in the in-game
patch note.
