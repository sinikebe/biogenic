# The dedicated server

A headless Linux build of Biogenic that keeps the shared pond open for two
players on your home Wi-Fi, so that neither phone has to be the host. A phone
joins it exactly the way it joins a friend's phone: **within earshot → answer →
four taps on the ring**. It updates itself from the same GitHub releases as the
phones and the PC build, every ten minutes, and never while anyone is in it.

It is written for a small Proxmox LXC container with no desktop, and runs on
any x86_64 Debian or Ubuntu machine with systemd.

> **Home Wi-Fi by default; friends outside the house by invite only.** Its LAN
> port, UDP 45771, answers a call only from an address on a local network --
> loopback, the private ranges (10/8, 172.16/12, 192.168/16), 100.64/10,
> link-local, its own /24, and IPv6 loopback, unique-local and link-local --
> and hangs up on anything else with one line in its log. It also sizes and
> checks every frame, cuts a guest that keeps sending what no Biogenic build
> sends or far more than any phone sends, and checks what every guest *says*
> (§3; issues #56, #57 and #58, `docs/design/net-hardening.md` parts A and B).
> **Never forward 45771.** A friend outside the house comes in through a second
> port, UDP 45772, which exists only while you have minted at least one invite:
> the call is encrypted, the server proves itself with a certificate the invite
> pins, and the friend proves the invite's secret before anything else is
> taken (§9; issue #59, part C). With no invites, nothing listens for the
> internet at all.

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
[server] internet: nothing listens for the internet: there are no invites. To let a friend in from outside, set --reach, then --invite=<name> (docs/server.md).
```

The third line is about friends outside the house (§9): until you mint an
invite, it says nothing listens for them.

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
sending what no Biogenic build sends or for saying what no honest game can, and
a second in which far more arrived at the port than two phones could send. Each
kind of line is printed at most once every ten seconds for each address -- calls
from outside the network, and calls turned away because too many came from
everywhere at once, once every ten seconds for all of them together -- and the
next one says how many like it were held back, so a noisy device cannot fill
the journal. And every guest gets one line as it goes, however it goes, saying
how long it stayed, what it sent, how many times it went over its budgets, and
how many fouls the referee called on it (below). These lines name the caller's
address; the journal is on your machine, not in the repository. For example,
with placeholder addresses:

```
[net] refused 203.0.113.9: not on this network -- a call from outside needs an invite, on port 45772
[net] hung up on 1587052382 (192.0.2.40): different versions
[net] cut 694971552 (192.0.2.41): malformed: an event of type 4 that does not read -- 12 points -- barred 60 s
[net] 1945108233 (192.0.2.42) done after 1800 s -- frames 51234, events 312, over budget 0, points 0, fouls 0
```

**The rate limits are enforced.** How many frames, bytes and events a guest
may send each second are the only limits a slow or bursty Wi-Fi could trip on
an honest phone. Measured through a jittery link, the busiest honest guest used
about a quarter of them, and a synthetic worst case four fifths, but not yet on
two real phones on real Wi-Fi. A guest over them loses the frames past its
budget, and one that keeps flooding is cut:

```
[net] cut 1945108233 (192.0.2.42): flooding: 241 frames over its budget in a second (120 a second, 240 at once) -- 12 points -- barred 60 s
```

**Every `done after` line from an honest phone should say `over budget 0`.**
If one does not, or an honest phone is cut, the limits are too tight for that
Wi-Fi, not the phone misbehaving: file an issue with the log lines. Setting
`enforce_budgets` to `false` in `game/net/net_session.gd` is the switch back to
**watch mode**, in which the server takes every frame and only logs what it
*would* have done (`[net] would drop ...`, `[net] would cut ...`).

**What a guest says is checked too, and that is enforced as well.** The server
knows how big each guest's cell can be -- it fed it every meal it ate in its
water -- how fast any cell can swim, what a body wears, and when an arrival, a
division or a death is due. A guest's word that breaks one of those rules is a
*foul*: the server keeps its own answer instead (a body no bigger than it was
fed, a place no further than it could swim, no arrival while one is already
swimming), and the foul costs one to four points on the same ledger as the
limits, each rule at most twice a second. Ten points cut the guest:

```
[net] 694971552 (192.0.2.41) fouled: radius: r40.00, where the host has fed it to r26.00 -- 4 points
[net] 694971552 (192.0.2.41) is at 7 of 10 points: fouled: radius: r40.00, where the host has fed it to r26.00
[net] cut 694971552 (192.0.2.41): fouled: radius: r40.00, where the host has fed it to r26.00 -- 11 points -- barred 60 s
```

A foul line names the rule first -- `movement`, `heading`, `radius`,
`dividing`, `shout`, `arrival`, `body`, `sister` or `death` -- and then what
broke it. **An honest phone never fouls**, so every `done after` line from one
should also say `fouls 0`. If one does not, file an issue with the lines.
Setting `enforce_referee` to `false` in `game/net/net_session.gd` is watch mode
for the referee: the lines read `[net] would foul ...` and `[net] would cut
... -- watching the referee, not enforcing it`, and no foul costs a point. The
server keeps its own answers either way.

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
- **Do not forward 45771 on your router.** See the note at the top.
- **UDP 45772 is the internet's**, and only while there are invites (§9). It is
  the one port to forward, and only if you want friends outside the house.
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
  public address on 45771 -- which can only reach it through a forwarded port,
  or over IPv6 -- is refused as not on this network: friends outside come in
  by invite, on 45772 (§9). **"cut off"** (or
  "refused", on an older build) is a phone the server cut for sending frames no
  Biogenic build sends, or far more of them than any phone sends. Its screen
  says "the other end would not take what this game sent. update both from the
  launcher, then call again in a minute": the server bars its address for a
  minute after a cut, so a call straight back is the "they hung up" above.
- **The server keeps restarting** -- `systemctl status biogenic-server` shows it
  starting again every five seconds, and `journalctl -u biogenic-server -e`
  shows how each start ends. After an update, that is the new build failing on
  this machine in a way its version check could not see: go back to the
  previous build (§6). `could not listen` is not this -- the server stays up
  and tries again by itself, after five seconds and then twice as long each
  time, up to every five minutes. It means something else holds UDP 45771, or
  the network was not up yet.
- **`no phone can join by code`** -- the server is listening, but its address
  ends in .0 or .255 (which a network wider than a /24 can hand out), and a
  code only carries a last number from 1 to 254. Give the container another
  address -- a DHCP reservation or a static one -- and restart the service.

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

## 9. Internet play: friends outside the house

A friend who is not on your Wi-Fi gets in with an **invite**: one line of text
you mint on the server and send them in any messaging app. They paste it once
in Biogenic -- play, then **by invite**, then **paste invite** -- and from then
on they tap **call**. It is all done from the server's command line. The home
Wi-Fi's four taps are untouched, and a phone never listens on the internet.

What an invite is, in brief (`docs/design/net-hardening.md` part C has the
rest):

- **One per friend**, with its own secret, so you can shut one friend out
  without touching anybody else, and the log says who came in.
- **The server's certificate, whole.** The friend's phone talks only to the
  server that minted the invite, encrypted from the first packet, so a man in
  the middle has nothing it will accept.
- **A secret that never crosses the wire.** The phone proves it holds it, over
  two fresh random numbers, before the server takes a single frame of play.

Every address here is a placeholder -- `203.0.113.7` from RFC 5737's
documentation range, `pond.example.net` from RFC 2606's. Use your own.

### 9.1 Run the jobs as the service's user

Every invite job is the server binary with one flag after `--`. It does its job
and exits: it does not host, check for updates or open a port, so it is safe to
run beside the service. Run it **as the service's own user, with its home**, or
it writes a book the service never reads:

```sh
sudo -u biogenic HOME=/var/lib/biogenic /opt/biogenic/biogenic-server.x86_64 --headless -- --invites
```

Below, `$BIOGENIC` stands for everything up to and including that `--`:

```sh
BIOGENIC="sudo -u biogenic HOME=/var/lib/biogenic /opt/biogenic/biogenic-server.x86_64 --headless --"
```

Each job says what it did in lines starting `[server]` and exits 0. A job it
refuses exits 1, with a sentence that names the fix. Run as root by mistake, it
says so first.

### 9.2 Tell it where friends call

Friends need an address that reaches your router from the internet: your
public IP address, or a name that leads to it -- a dynamic-DNS name, if your
address changes. Set it once:

```sh
$BIOGENIC --reach=203.0.113.7            # or --reach=pond.example.net
```

It is kept in the server's `user://` and nowhere else. If your router forwards
a different outside port to 45772, say which: `--reach=pond.example.net:50000`.
An IPv6 address goes in brackets: `--reach=[2001:db8::7]:45772`. An address
inside your own network gets a warning, because friends outside can never
reach it.

Every invite carries the address it was minted with, so after changing
`--reach`, mint again for anybody who has one.

### 9.3 Forward one port

On your router, forward **UDP 45772** -- or the outside port you gave `--reach`
-- to the container's UDP 45772. That is the only port to forward, ever: 45771
stays inside. If the container runs `ufw`: `ufw allow 45772/udp`.

### 9.4 Mint an invite, and send it

```sh
$BIOGENIC --invite=sam
```

```
[server] made the server's key and certificate: /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/pond/key.pem (only this user can read it)
[server] invite for sam written to /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/invites/sam.txt, calling 203.0.113.7:45772 -- send its one line to sam and nobody else, and in Biogenic they tap play, then by invite, then paste invite.
[server] a running server takes it within seconds.
```

The first mint makes the server's key -- RSA-2048, `rw-------` -- and its
self-signed certificate, named `biogenic-pond` and valid from 2020 to 2099, so
a phone whose clock is years out still accepts it. A label is 1 to 24 of `a-z`,
`0-9`, `-` and `_`. It names the friend in the log and the file.

**The secret is never printed**, only the file's path. Copy the line out of the
file and into your messaging app:

```sh
sudo cat /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/invites/sam.txt
```

It is one line of about 1.1 KB, starting `biogenic-invite:`. It does not matter
if the app wraps it, or if you write a sentence before or after it: the game
finds it. A copy that lost a piece is caught on the phone, as damaged, before it
ever calls. Treat the line like a house key: whoever holds it swims in your pond
as sam until you revoke it.

**The running server picks it up by itself**, within two seconds. The first
invite opens the internet listener, and the log says so:

```
[server] invites: sam added
[server] internet: listening on port 45772/udp for 1 invite (sam). Friends call 203.0.113.7:45772: forward that port, UDP, to this machine's 45772/udp -- the one port to forward.
```

### 9.5 List, replace and revoke

```sh
$BIOGENIC --invites          # labels, when each was made and when it last came in
$BIOGENIC --invite=sam       # again: a new secret, and the line sent before stops working
$BIOGENIC --revoke=sam       # that invite stops working
```

```
[server] friends call 203.0.113.7:45772; the server listens on 45772/udp for them.
[server] 2 invites:
[server]   kit -- made 2026-09-20 18:02 UTC, last joined never
[server]   sam -- made 2026-09-25 14:03 UTC, last joined 2026-09-25 18:10 UTC
```

A running server notices a revoke or a replacement within two seconds, and a
friend swimming on that invite is cut, reading "invite no longer works"
(`[server] invites: sam revoked`). With no invites left the internet listener
closes, and nothing listens for the internet until you mint again.

### 9.6 Limit callers at the firewall

The server's own door already turns away a caller that comes too often (§3),
but it only sees one once the encrypted handshake is done. A firewall rule per
source address stops a flood before that. With nftables -- in the container, or
on the Proxmox host's firewall in front of it:

```
# Biogenic's internet listener, UDP 45772: new calls and datagrams, per source.
table inet biogenic {
	set calls4 { type ipv4_addr; flags dynamic, timeout; timeout 1m; }
	set calls6 { type ipv6_addr; flags dynamic, timeout; timeout 1m; }
	set flood4 { type ipv4_addr; flags dynamic, timeout; timeout 1m; }
	set flood6 { type ipv6_addr; flags dynamic, timeout; timeout 1m; }
	chain input {
		type filter hook input priority filter - 1; policy accept;
		udp dport 45772 ct state new update @calls4 { ip saddr limit rate over 10/minute burst 20 packets } counter drop
		udp dport 45772 ct state new update @calls6 { ip6 saddr and ffff:ffff:ffff:ffff:: limit rate over 10/minute burst 20 packets } counter drop
		udp dport 45772 update @flood4 { ip saddr limit rate over 400/second burst 800 packets } counter drop
		udp dport 45772 update @flood6 { ip6 saddr and ffff:ffff:ffff:ffff:: limit rate over 400/second burst 800 packets } counter drop
	}
}
```

Each address -- each /64, over IPv6 -- gets twenty new calls, then ten a
minute, and 800 datagrams, then 400 a second. A call is one new flow (two after
one that failed, which the phone checks once more), and a friend swimming sends
at most about a hundred datagrams a second. Two friends behind one router share
an address, and fit. Check the file with `nft -c -f <file>` before loading it.

### 9.7 Keep the engine's handshake errors out of the journal

A caller that is not a Biogenic build -- a port scanner, anything speaking plain
UDP to 45772 -- makes the engine itself print an error line for each handshake
it cannot finish, before any of the server's own code sees the caller, so the
server's limiter cannot hold them back. Give the unit a journal rate limit:
`systemctl edit biogenic-server`, and in the editor that opens,

```ini
[Service]
LogRateLimitIntervalSec=30s
LogRateLimitBurst=200
```

then `systemctl restart biogenic-server`. Past 200 lines in 30 s, journald keeps
the rest out and says how many it suppressed. The limit covers every line the
unit prints, but the server's own are already at most one of each kind per
address every ten seconds (§3), so on an ordinary day it never bites.

The engine's lines look like these, and none of them is the server failing:

- `ERROR: TLS handshake error: -30464` -- a datagram that was not a handshake:
  plain UDP, or a handshake the listener had no room for.
- `ERROR: TLS handshake error: -30592` -- the caller refused this certificate:
  an invite from another server, or one from before `--new-key`.
- `ERROR: Parameter "p_mutex->mutex" is null.`, three at a time, whenever the
  internet listener closes: a bug in Godot 4.7's DTLS server, harmless.

### 9.8 A new key

If the key may have been copied, make a new one:

```sh
$BIOGENIC --new-key
```

Every invite made with the old key stops working, because each carries the old
certificate, and the book is emptied. Mint each friend again and send each the
new line. A running server changes to the new key by itself, and a friend still
swimming on an old invite is cut.

### 9.9 When a friend cannot get in

What their phone says, and what to look for in `journalctl -u biogenic-server`:

- **"no answer"** -- nothing answered within eight seconds. The port is not
  forwarded, `--reach` names the wrong address (`--invites` shows it), the
  server is down, or the friend's network blocks UDP. No `[net]` line: the
  call never reached the server. The same, from a network that stays silent
  rather than refusing, when nothing listens (below).
- **"no server there"** -- the address refused the call: nothing listens on
  that port. With no invites the internet listener is closed (`[server]
  internet: nothing listens for the internet`), or the router forwards to the
  wrong port or machine.
- **"a different server"** -- something answered with another certificate: the
  key was replaced (`--new-key`) after this invite was minted, or the address
  now leads somewhere else. Mint them a new one.
- **"invite no longer works"** -- the server refused the invite: revoked,
  replaced, or never one of yours. The log says which:
  ```
  [net] hung up on 1587052382 (198.51.100.4): no invite it could prove -- the wrong secret for the invite for sam -- barred 60 s
  [net] hung up on 1587052382 (198.51.100.4): no invite it could prove -- a key id no invite has -- barred 60 s
  ```
  A refused invite bars the address for a minute, and ten for a second one
  within ten minutes. The phone does not call on it again until a new one is
  pasted.
- **"nowhere by that name"** -- the name in the invite did not resolve: check
  your dynamic-DNS name.
- **"different versions"** -- the phone or the server is older. The server
  updates itself once its water is empty (§4), the phone from its launcher.
- **"already two"** -- two friends are in. The limit counts the home Wi-Fi and
  the internet together.

A friend who got in is one line as they arrive and one as they go, naming the
invite:

```
[net] 694971552 (203.0.113.9) proved the invite for sam
[net] 694971552 (203.0.113.9, invite sam) done after 1800 s -- frames 51234, events 312, over budget 0, points 0, fouls 0
```

A guest from the internet is held to exactly the rules a guest on the LAN is
(§3): the same budgets, the same referee, the same cuts -- and the server's
door keeps its own count of callers for each port, so a storm on 45772 never
turns away a phone on the Wi-Fi.
