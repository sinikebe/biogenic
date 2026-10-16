# Going private: the plan, on hold

The owner, 2026-10-16:
- *"I plan to pass the repo private soon. We need to integrate a git token to
  keep getting updates. Unless there's another way"*;
- then *"Okay for the second public repo containing only the releases"*, and
  *"LXC runner, and release now"*;
- then *"I can't set the runner yet. You'll have to hold this up while we keep
  working on genes"*.

**Status: on hold until the runner is set up.** The repository is still public, and
every installed game still updates from it. Nothing below needs doing until the
owner picks it up again.

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
- **The runner, for dev** (2026-10-16, the owner: *"Set it for dev and trigger
  ci"*). dev's checks run on the self-hosted runner, and a fork's pull request,
  everything on `main` and every publish on GitHub's machines
  (docs/ci-runner.md §1). Publishing went back to GitHub's machines the same
  day: the runner uploads to GitHub's release server at about 1.5 Mbit/s
  (docs/ci-runner.md §6).

## 3. To do, in this order

1. **The runner.** Set up by the owner, and carrying dev's checks since
   2026-10-16. Publishing stays on GitHub's machines, about 2 of the allowance's
   minutes a merge, until the runner's upload to GitHub is fast
   (docs/ci-runner.md §6).
2. **The template issue** (§4 below). The template's release scripts publish to
   the repository they run in, and work out the patch note from that repository's
   tags, so publishing elsewhere is theirs to support. A Claude session was
   refused write access to the template on 2026-10-16, so either the owner files
   it, or a session given that access does.
3. **The public releases repository.** The owner creates an empty public repo and
   picks its name. The owner also creates a fine-grained token that can write to
   that repo only, kept as a secret here.
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

## 4. The template issue, as drafted

> **Support a private game repository: publish releases to a separate public
> repo, and choose the CI runner by a variable**
>
> **The situation.** A game made from this template (Biogenic) is going private.
> Installed games update from
> `https://github.com/<update_repo>/releases/latest/download/manifest.json` with
> no token, which works only while the repository is public.
>
> Shipping a token in the app is not an option:
> - anyone can pull it out of the APK;
> - on GitHub, a token that can read a private repository's releases can read all
>   its code (releases fall under "Contents");
> - it expires, and every installed game would then stop updating for good.
>
> So the plan is a second, **public repository that holds only releases**. The
> code stays private, players need nothing, and the token that publishes lives
> in Actions secrets only. The launcher side already works: `update_repo` points
> at the public repo.
>
> **What the release scripts would need**, since today they assume the code repo
> and the release repo are one:
> 1. `ci/publish_release.sh` builds `DOWNLOAD_BASE` from `GITHUB_REPOSITORY`, and
>    runs `gh release` against the current repo. It needs a release-repo setting
>    (say `RELEASE_REPO`, defaulting to `GITHUB_REPOSITORY`) used for both the
>    URLs and `gh` (`GH_REPO`). It also needs a token with `contents: write` on
>    that repo (say a `RELEASE_TOKEN` secret).
> 2. `ci/make_manifest.py --repo` already takes the repo, so `release.yml` would
>    pass `RELEASE_REPO`.
> 3. `ci/collect_changes.sh` finds the previous release with
>    `git tag --list 'v*+*'`, and downloads its manifest with `gh release
>    download`. The download should come from `RELEASE_REPO`. And `gh release
>    create` tags the repo it publishes to, so in a releases-only repo the tag
>    points at that repo's own commit. The code repo also needs the tag at the
>    released commit, pushed by the release job, or the patch note has no
>    "since".
> 4. `release.yml` wires the above, `branch-<name>` prereleases included.
>
> **And the runner, for private repos.** Actions minutes cost money there.
> Biogenic's workflows run dev's checks on a self-hosted runner and the rest on
> `${{ vars.CI_RUNNER || 'ubuntu-latest' }}`, publishing on
> `${{ vars.CI_RUNNER_PUBLISH || 'ubuntu-latest' }}`, and start by removing `~/.local/share/godot/app_userdata/<project name>*`,
> which a persistent self-hosted runner would otherwise carry between jobs. In
> the template's own workflows, that would leave no drift in a game's
> `.github/workflows/`.
>
> **One small thing noticed while releasing:** `MAX_CHANGES_PER_ENTRY = 20` in
> `ci/make_manifest.py` cut a 22-line release to its newest 20 lines in the
> in-game patch note, while the release page kept all 22.
