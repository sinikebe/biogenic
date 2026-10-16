# The self-hosted CI runner

> **In use for dev** (the owner, 2026-10-16: *"Set it for dev and trigger ci"*):
> dev's work runs on the self-hosted runner, and `main`'s on GitHub's machines
> (§1). The whole plan for going private, in order, is docs/going-private.md.

The owner, 2026-10-16, on taking the repository private: *"A self hosted runner
running of an LXC container"*, chosen over running the checks in the public
releases repository, or paying for GitHub's minutes.

**Why.** On a public repository, GitHub Actions minutes cost nothing. On a private
one they come out of a monthly allowance, about 2,000 minutes on the free plan.

Measured over 15 and 16 October:
- a pull request's CI takes about 12 minutes, mostly the drop probe (4.5) and the
  LAN session (3.9);
- a merge into `dev` publishes the dev app, about 2 minutes;
- GitHub rounds every job up to a whole minute.

A busy day came to about 110 minutes, so the allowance would last under three
weeks. A runner of our own costs no hosted minutes, keeps its logs and builds
private, and keeps Godot, Java and the Android SDK between runs.

GitHub announced a small per-minute fee for self-hosted runners on private
repositories for 2026, then delayed it. If it applies, it is a fraction of a cent
a minute: check GitHub's pricing page.

## 1. Switching

Every job's `runs-on` -- `ci.yml`, `release.yml`, `launcher-version.yml` and
`sync-launcher.yml` -- picks the machine by what the job is for:

- **dev's work runs on the self-hosted runner**: a pull request into `dev` from
  this repository, and a push or a manual run on `dev` (the dev app's publish, a
  launcher sync started on `dev`). It asks for the `self-hosted` label, which
  every self-hosted runner carries, so no variable is needed;
- **a fork's pull request never does.** Its code is a stranger's, and the runner
  sits on the owner's own machine. It runs on GitHub's;
- **everything else runs on GitHub's machines**: a release into `main`, the
  release's own publish, and the scheduled launcher sync, which starts from
  `main`.

Two repository variables move them (Settings → Secrets and variables → Actions →
Variables):

- **`CI_RUNNER_DEV`**: where dev's work runs instead. Set it to `ubuntu-latest` to
  send dev back to GitHub's machines whenever the container will be down for a
  while. A job whose runner is offline waits in the queue (up to a day) and then
  fails. Delete it to come back to the runner.
- **`CI_RUNNER`**: where everything else runs, `ubuntu-latest` while it is unset.
  Set it to the runner's label (§3) once the runner has carried dev for a while,
  and `main`'s releases move to it too.

## 2. The container

- **Unprivileged LXC, x86_64, Ubuntu 24.04**, the closest match to GitHub's
  `ubuntu-latest`. Godot's Linux build, the Android SDK and the export templates
  are all x86_64.
- **Nesting on** (on Proxmox: the container's Options → Features → Nesting). The
  "Take the network from under a host" check runs a server in a network
  namespace of its own (`sudo unshare --net`), and an unprivileged container
  without nesting refuses it.
- **About 4 cores, 2 to 4 GB of memory, and 20 GB of disk.** The disk holds the
  Android SDK, Java, Godot and its export templates, which persist between runs. A
  run's own files go in its workspace and its temporary directory.
- **Memory, measured** (2026-10-16, one Godot process at a time, its peak resident
  size; a CI job runs its steps one after another, so the largest is what counts):
  - a content pack's export, 818 MB;
  - the drop probe, 488 MB;
  - the LAN session (net probe, host and guests in one process), 388 MB;
  - the gene probe, 362 MB;
  - check 8's minute of play, 293 MB.

  The APK's and the Windows executable's exports were not measured: they need the
  export templates, which the container this was measured in did not have. They
  pack and sign what the pack export packs, so expect them near it, plus Java's
  for the APK's signing. Add the runner service and the system, under 1 GB. **2 GB
  is the least to try, 4 GB is comfortable**, and swap of 2 to 4 GB turns a spike
  into a slow step instead of a killed one. The first runs on a small container
  are that measurement: a step killed for memory ends with exit code 137.
- **Outbound HTTPS only, nothing inbound**: a runner polls GitHub, nothing calls
  it. It downloads from GitHub, Godot's release downloads, Google's Android
  repository and the Ubuntu mirrors.
- **Keep it apart from everything else.** It runs whatever code a pull request
  contains, including the code a Claude session writes. So treat it as untrusted:
  - no mounts of the host's folders;
  - no route to the rest of the network;
  - no other service in the same container;
  - not on the machine that hosts the pond server, or that server's players feel
    every CI run.

## 3. Inside it

```
apt-get update
apt-get install -y git curl ca-certificates zip unzip python3 jq shellcheck sudo iproute2
# The GitHub CLI, which the release scripts publish with (`gh release ...`):
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update && apt-get install -y gh

# git: without it actions/checkout downloads a bare archive, and every step that
# reads the history fails (`check_binary_skew.py`, the patch notes). iproute2 is
# `ip`, which the network steps call inside `sudo unshare --net`.
#
# The runner's own user, with passwordless sudo inside the container: the
# workflows call `sudo` for `unshare --net` and `apt-get`, as on GitHub's machines.
adduser --disabled-password --gecos "" runner
echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner
```

**Then register it**, as that user: go to this repository's Settings → Actions →
Runners → New self-hosted runner → Linux, x64. GitHub shows the download and a
one-time registration token. dev's jobs ask for the `self-hosted` label every
runner has (§1). When `config.sh` asks for labels, add one of your own too, such as
`biogenic`: it is what `CI_RUNNER` names when `main`'s releases move to the runner. Install it as a service, so it
survives a restart:

```
sudo ./svc.sh install runner
sudo ./svc.sh start
```

The registration token is single-use and short-lived, and it stays on that
machine. Nothing about the container goes into this repository: no address, no
hostname, and no token (CLAUDE.md, "Nothing personal in the repo").

## 4. What a runner of our own changes

- **/tmp may be memory.** Debian 13 mounts a tmpfs on `/tmp`, and the first run on
  a 1 GB container was killed there: `ci/install_godot.sh` downloads Godot's 1 GB
  export templates into a `mktemp -d` and unpacks them beside the download. So
  every workflow that installs Godot first points `TMPDIR` at the runner's own
  temp folder, which is on disk and emptied after each job. `findmnt /tmp` says
  which the container has; `systemctl mask tmp.mount` and a restart put it back on
  disk for everything else.

- **The disk persists between jobs**, which GitHub's machines never do:
  - the workspace is cleaned by `actions/checkout`, so `.godot/` and every build
    starts fresh;
  - the game's `user://` folder is not: the probes' worlds, cells, library and
    settings would carry into the next run. So `ci.yml` and `release.yml` start
    with "Start from no saved data", which removes
    `~/.local/share/godot/app_userdata/Biogenic*` and nothing else; the export
    templates beside it stay;
  - `~/godot`, the editor settings, Java and the SDK persisting is the point: they
    are verified or rewritten on every run.
- **The signing key** is written into the job's temporary directory and shredded
  at the end, `if: always()` (`release.yml`), so it never outlives the job, here
  as on GitHub's machines. The keystore and its passwords stay in the
  repository's secrets.
- **One job at a time.** A pull request's CI and a merge's release queue behind
  each other rather than running side by side. That is minutes of waiting, not
  failures.

## 5. Trying it

Once the runner shows as **Idle** under Settings → Actions → Runners, open a pull
request into `dev`, or run CI by hand on `dev`. Then compare:
- the same checks pass (ALL PASS from each probe, and check 8's hash unchanged);
- the logs show the runner's name rather than "GitHub Actions";
- the time. The first run downloads Java, the Android SDK and Godot, and later
  runs reuse them.
