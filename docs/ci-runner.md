# The self-hosted CI runner

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

Every job's `runs-on` is `${{ vars.CI_RUNNER || 'ubuntu-latest' }}`:
`ci.yml`, `release.yml`, `launcher-version.yml` and `sync-launcher.yml`.

- **To use the runner:** go to Settings → Secrets and variables → Actions →
  Variables and add `CI_RUNNER`. Its value is the runner's label (§3), for example
  `biogenic`.
- **To go back to GitHub's machines:** delete the variable. Do this whenever the
  container will be down for a while. A job whose runner is offline waits in the
  queue (up to a day) and then fails.

Nothing changes until the variable exists.

## 2. The container

- **Unprivileged LXC, x86_64, Ubuntu 24.04**, the closest match to GitHub's
  `ubuntu-latest`. Godot's Linux build, the Android SDK and the export templates
  are all x86_64.
- **Nesting on** (on Proxmox: the container's Options → Features → Nesting). The
  "Take the network from under a host" check runs a server in a network
  namespace of its own (`sudo unshare --net`), and an unprivileged container
  without nesting refuses it.
- **About 4 cores, 8 GB of memory and 20 GB of disk.** The disk holds the Android
  SDK, Java, Godot and its export templates, which persist between runs. A run's
  own files go in its workspace and its temporary directory.
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
apt-get install -y git curl ca-certificates zip unzip python3 jq shellcheck sudo
# The GitHub CLI, which the release scripts publish with (`gh release ...`):
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update && apt-get install -y gh

# The runner's own user, with passwordless sudo inside the container: the
# workflows call `sudo` for `unshare --net` and `apt-get`, as on GitHub's machines.
adduser --disabled-password --gecos "" runner
echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner
```

**Then register it**, as that user: go to this repository's Settings → Actions →
Runners → New self-hosted runner → Linux, x64. GitHub shows the download and a
one-time registration token. When `config.sh` asks for labels, add `biogenic` (or
any label, which `CI_RUNNER` must then match). Install it as a service, so it
survives a restart:

```
sudo ./svc.sh install runner
sudo ./svc.sh start
```

The registration token is single-use and short-lived, and it stays on that
machine. Nothing about the container goes into this repository: no address, no
hostname, and no token (CLAUDE.md, "Nothing personal in the repo").

## 4. What a runner of our own changes

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

Once the runner shows as **Idle** under Settings → Actions → Runners, set
`CI_RUNNER` and re-run a pull request's CI. Then compare:
- the same checks pass (ALL PASS from each probe, and check 8's hash unchanged);
- the logs show the runner's name rather than "GitHub Actions";
- the time. The first run downloads Java, the Android SDK and Godot, and later
  runs reuse them.
