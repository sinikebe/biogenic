# The dedicated server

A headless Linux build of Biogenic that keeps the shared pond open for two
players on your home Wi-Fi, so that neither phone has to be the host. A phone
joins it exactly the way it joins a friend's phone: **within earshot → answer →
four taps on the ring**. It updates itself from the same GitHub releases as the
phones and the PC build, every ten minutes, and never while anyone is in it.

It is written for a small Proxmox LXC container with no desktop, and runs on
any x86_64 Debian or Ubuntu machine with systemd.

> **Home Wi-Fi only, for now -- and the server enforces it.** It answers a call
> only from an address on a local network -- loopback, the private ranges
> (10/8, 172.16/12, 192.168/16), 100.64/10, link-local, its own /24, and IPv6
> loopback, unique-local and link-local -- and hangs up on anything else with
> one line in its log. It also sizes and checks every frame, limits how often
> and how much each guest may send, and cuts a guest that keeps breaking the
> rules (issues #56 and #58; `docs/design/net-hardening.md`, part A). Internet
> play still needs the rest: the server checking what a guest *says* (#57) and
> an authenticated, encrypted handshake (#59), then a forwarded UDP port and a
> way for a phone to enter an address rather than tap a code. None of that is
> built, and the guard stays on until it is. **Do not forward the server's port
> on your router**: a forwarded port only lets strangers knock on a door that
> does not open for them.

Every address below is a placeholder from RFC 5737's documentation range,
`192.0.2.0/24`. Put your own network's numbers in their place.

## 1. Make the container

In Proxmox, create a container from a **Debian 12** (or Ubuntu 24.04) template.
Unprivileged is fine. The server is small: measured on the exported build, it
sits at about 100 MB of memory and 1% of one core while it waits, so 1 core,
512 MB and a 2 GB disk leave plenty of room.

The one setting that matters is the network. The container must be **on the
same network as the phones, and on the same /24** -- the first three numbers of
its address the same as theirs. The join code carries only the last number: a
phone that taps it assumes everything before it is its own.

- Bridge the container's `eth0` to your LAN bridge (`vmbr0` on a stock
  install), not to a NAT or internal one.
- Give it a fixed address, or a DHCP reservation on your router, so that its
  code never changes. For example: the phones get `192.0.2.x` from the router,
  and the container is `192.0.2.12`.

From the Proxmox host's shell that is, with your own template, storage and
container ID:

```sh
pct create 120 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname biogenic --cores 1 --memory 512 --rootfs local-lvm:2 \
  --unprivileged 1 --net0 name=eth0,bridge=vmbr0,ip=dhcp --onboot 1
pct start 120
pct enter 120
```

## 2. Install the server

Inside the container, as root:

```sh
apt-get update && apt-get install -y curl
curl -fsSLO https://github.com/sinikebe/biogenic/releases/latest/download/install-server.sh
less install-server.sh      # it is short: read what you are about to run
bash install-server.sh
```

The installer is safe to run again at any time -- to repair an install, or to
pull the newest build by hand. In order, it:

1. installs `curl` and the CA certificates if they are missing;
2. creates a system user, `biogenic`, with no login shell and its home at
   `/var/lib/biogenic` -- where Godot keeps the server's `user://`: staged
   content packs, the update state, and its own log files, all kept across
   restarts, reboots and reinstalls;
3. downloads `biogenic-server.x86_64`, `biogenic-server.service` and
   `SHA256SUMS`, all three from the release that is the latest when it starts
   -- looked up once, so a release published halfway through cannot mix two --
   and installs nothing unless both files match their checksums;
4. puts the build in `/opt/biogenic`, owned by `biogenic`, because the server
   replaces its own binary when a new one is published;
5. installs the unit into `/etc/systemd/system/`, enables it and starts it (or
   restarts it, if it was running);
6. prints what the server says about where it is.

## 3. Find the code

The server logs its address and its code when it starts, and again every five
minutes, so the newest two lines of its log always have them:

```sh
journalctl -u biogenic-server -o cat | grep -E '^\[server\] (READY|listening|to join)' | tail -2
```

It looks like this -- for a server at the placeholder `192.0.2.12`:

```
[server] READY -- listening on 192.0.2.12 port 45771/udp, code 1, 7, 12, 12 o'clock
[server] to join: a phone on this wi-fi (192.0.2.x) opens within earshot, taps answer, and taps the ring at 1, 7, 12, 12 o'clock, in that order. LAN only: do not forward this port.
```

The code is four marks on the ring the phone shows under **answer**, written as
positions on a clock: the ring has twelve, **12 o'clock is the top**, and they go
clockwise. So `1, 7, 12, 12 o'clock` is: the mark at one o'clock, then seven,
then the top, and the top again. The fourth tap is a check digit -- a mis-tap
is caught on the phone at once, as "that is not a code".

To play: both phones on the same Wi-Fi as the server open **within earshot**,
tap **answer**, and tap the code. Each then chooses a view and swims. Each sees
the other as the friend, exactly as with a phone host, and the water is the
server's. A third phone is told "already two".

`journalctl -u biogenic-server -f` follows everything it says: guests joining,
arriving, dying and leaving, and every update decision.

It also says, in lines that start `[net]`, whenever it turns a caller away or
hangs up on one: a call from outside the local network, an address calling too
often, a caller that never said hello or runs another version, a guest cut for
sending what no Biogenic build sends, and a second in which far more arrived at
the port than two phones could send. Each kind of line is printed at most once
every ten seconds for each address -- calls from outside the network, and calls
turned away because too many came from everywhere at once, once every ten
seconds for all of them together -- and the next one says how many like it were
held back, so a noisy device cannot fill the journal. These lines name the
caller's address; the journal is on your machine, not in the repository. For
example, with placeholder addresses:

```
[net] refused 203.0.113.9: not on this network (LAN-only until #59)
[net] hung up on 1587052382 (192.0.2.40): different versions
[net] cut 694971552 (192.0.2.41): flooding: 241 frames over its budget in a second (120 a second, 240 at once) -- 12 points -- barred 60 s
```

## 4. How it updates

The server reads the same release manifest the phones and the PC build read,
once when it starts and then every ten minutes, and every decision it makes is
one `[server] update:` line in its log.

- **A newer content pack** -- most releases -- is downloaded, checked against
  the manifest's SHA-256 and staged; it takes effect when the server restarts.
  A pack published for another binary than the one running is not taken.
- **A newer binary** -- an engine upgrade, and the like -- is downloaded next to
  the running build, its SHA-256 checked, and then **asked for its version**,
  the pre-flight: a build that does not start on this machine -- one that needs
  a newer glibc or a newer CPU than the container has -- is refused there,
  before it replaces anything. A build that answers is renamed over the running
  one in one step: the running server carries on from the file it started
  from, and the next start is the new build. The build it replaced is kept as
  `/opt/biogenic/biogenic-server.x86_64.previous`; if a newer one arrives
  before the server has restarted onto the last, `.previous` stays the build
  that actually ran.
- **A refused build** -- its checksum wrong, or not starting here -- is deleted
  and the running build left alone, and it is not downloaded again while the
  manifest gives it the same checksum; the log says so once. The server
  remembers that for as long as it runs; after a restart it tries such a build
  once more.
- **The restart waits for an empty pond**: nobody connected, and nobody
  connecting, for thirty seconds. Then the server exits and systemd starts it
  again (`Restart=always`). **It never restarts with a player connected**, so an
  update can wait for as long as somebody is swimming.
- A check or download that fails changes nothing, and is tried again ten
  minutes later.
- **What a restart does not fix.** A content pack that does not mount leaves
  the server on the content it had, and it does not try that pack again for as
  long as it runs -- but it remembers that only in memory: after a reboot or a
  crash it downloads the pack once more, restarts once more when the pond is
  empty, and gives it up again, one wasted download and restart for every
  start. A build that passes its version check and still cannot run is worse:
  it fails at every start, and systemd starts it again every five seconds, for
  good. Only going back to the previous build brings the server back (§6).

Phones take updates when their players accept them, and the server takes them
within ten minutes of a release. A phone on an older protocol is told
"different versions" when it tries to join: update it from the launcher and
join again.

## 5. The port

The server listens on **UDP 45771**, on every address the container has. The
phones reach it across your LAN and nothing else needs to.

- If the container runs a firewall, let the LAN in on that port and only the
  LAN. With `ufw`, for example: `ufw allow from 192.0.2.0/24 to any port 45771
  proto udp`, with your own range in place of the placeholder.
- **Do not forward the port on your router.** See the note at the top.
- A router's "guest network" or "client isolation" stops devices on it from
  reaching each other, and so stops a phone from reaching the server. Put the
  phones on the main Wi-Fi.

## 6. Every day

```sh
systemctl status biogenic-server        # is it running, and since when
journalctl -u biogenic-server -f        # what it is saying
systemctl restart biogenic-server       # restart now (anyone in the pond swims on alone)
systemctl stop biogenic-server          # stop it until the next boot or start
systemctl disable --now biogenic-server # stop it and keep it stopped
```

**Stopping is clean.** Godot does not catch SIGTERM, so the unit's `ExecStop`
asks first: it leaves a file the server looks for four times a second, and the
server tells its guests it is going -- each phone takes over its own water at
once, rather than after a connection timeout -- and exits. SIGTERM is only the
backstop.

**Going back to the previous build**, if a new one misbehaves or will not
start -- `systemctl status biogenic-server` showing it starting over and over,
every five seconds:

```sh
systemctl stop biogenic-server
cd /opt/biogenic
mv biogenic-server.x86_64.previous biogenic-server.x86_64
```

The build you left is still the latest release, and the server would take it
again at its first check. So before starting it, tell it not to update until a
fixed release is out: `systemctl edit biogenic-server`, and in the editor that
opens,

```ini
[Service]
ExecStart=
ExecStart=/opt/biogenic/biogenic-server.x86_64 --headless -- --stop-file=/run/biogenic/stop --no-update
```

and then `systemctl start biogenic-server`. Once the fix is published,
`systemctl revert biogenic-server` and `systemctl restart biogenic-server` turn
updates back on, and the server takes the fix at its first check, as it starts.

**Uninstalling:**

```sh
systemctl disable --now biogenic-server
rm /etc/systemd/system/biogenic-server.service && systemctl daemon-reload
rm -r /opt/biogenic /var/lib/biogenic
userdel biogenic
```

## 7. When a phone cannot find it

- **"no answer"** -- the phone reached for an address and nothing answered.
  Check the phone is on the same Wi-Fi, and on the same /24: the server's log
  says `a phone on this wi-fi (192.0.2.x)`, and the phone's own address must
  start the same way. The line beginning `[server] adapters:` lists every
  address the container has and which one the code is for.
- **"different versions"** -- one of them is older. Update the phone from the
  launcher; if the phone is newer, the server catches up within ten minutes of
  the release.
- **"already two"** -- two phones are in already. A phone that has just left
  holds its place until its connection times out: ENet holds a vanished peer
  for 5 to 30 seconds.
- **"they hung up" the moment it connects** -- the server turned it away at the
  door, and the journal says why in a `[net] refused` line: most often a phone
  that called again and again within a few seconds (it can call again a few
  seconds later), or one barred for a minute after it was cut. A caller from a
  public address -- which can only reach the server through a forwarded port,
  or over IPv6 -- is refused as not on this network. **"cut off"** (or
  "refused", on an older build) is a phone the server cut for sending frames no
  Biogenic build sends: update both from the launcher.
- **The server keeps restarting** -- `systemctl status biogenic-server` shows it
  starting again every five seconds, and `journalctl -u biogenic-server -e`
  shows how each start ends. After an update, that is the new build failing on
  this machine in a way its version check could not see: go back to the
  previous build (§6). `could not listen` is not this -- the server stays up
  and tries again by itself, after five seconds and then twice as long each
  time, up to every five minutes. It means something else holds UDP 45771, or
  the network was not up yet.

## 8. What is inside

- It is the same game, exported by `.github/workflows/release.yml` with the
  **Linux Server** preset: x86_64, the game embedded in the executable, and the
  custom feature `server`, which makes `project.godot`'s
  `run/main_scene.server` boot `game/server/server.tscn` instead of the
  launcher. On Android and Windows that setting is inert.
- It ships in every release as `binary:linux` (`biogenic-server.x86_64`) and
  `content:linux` (`content-linux.pck`) in the same manifest as the phones and
  the PC build, beside `install-server.sh` and `biogenic-server.service`. The
  `linux` key is the server's: a Linux desktop client, if one is ever made,
  needs a key of its own, or it would be offered the server as its update.
- It hosts the pond with no cell of its own (`game/net/pond.gd`,
  `game/normal/food.gd`'s `open_dedicated()`): each guest is sent the other as
  the friend, in the slot where a phone host puts itself, so a phone joins it
  on PROTOCOL 4 with no code it did not already have.
- Its log is flushed a line at a time (`run/flush_stdout_on_print.server`):
  without that, measured, nothing it printed reached the journal until the
  buffer filled, and a kill lost it all.
- CI exports it on every pull request and boots the exported binary headless:
  it has to say `[server] READY` and stop cleanly on its stop file, with no
  script errors, and answer `--version` as the pre-flight wants every new build
  to (`.github/workflows/ci.yml`; `release.yml` does the same before it
  publishes). `tools/net_probe.gd` runs a server with two real guests over
  loopback, and its update decisions against a fake release feed.
