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
> **Never forward 45771**, and keep it off the internet at the firewall too
> (§5): the server's own check is a second line, not the first. A friend
> outside the house comes in through a second port, UDP 45772. **The server
> asks your router to forward that one to it, by UPnP, for as long as it
> runs** -- never 45771 -- and `--no-upnp` turns that off (§9.3). But nothing
> answers on 45772 until you have minted at least one invite: the call is
> encrypted, the server proves itself with a certificate the invite pins, and
> the friend proves the invite's secret before anything else is taken (§9;
> issue #59, part C). With no invites, nothing listens for the internet at
> all: the forward leads to a port nobody answers.

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
  install), not to a NAT or internal one: the phones find the server there,
  and the server finds the router there (§9.3).
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
update it (below). In order, it:

1. installs `curl` and the CA certificates if they are missing;
2. creates a system user, `biogenic`, with no login shell and its home at
   `/var/lib/biogenic` -- where Godot keeps the server's `user://`: staged
   content packs, the update state, its own log files, the invites and the
   server's key, all kept across restarts, reboots and reinstalls, and readable
   by no other account (§9.11);
3. downloads `biogenic-server.x86_64`, `biogenic-server.service`,
   `nftables-internet.conf` and `SHA256SUMS`, all from the release that is the
   latest when it starts -- looked up once, so a release published halfway
   through cannot mix two -- and installs nothing unless all three files match
   their checksums;
4. puts the build in `/opt/biogenic`, owned by `biogenic`, because the server
   replaces its own binary when a new one is published;
5. installs the unit into `/etc/systemd/system/` and enables it, lays the
   firewall rules for both ports in `/etc/biogenic/` without loading them (§5,
   §9.6), and names any `systemctl edit` override still in effect;
6. starts the server -- or restarts it, if the build or the unit changed -- and
   prints what it says about where it is, and whether the router took its
   forward (§9.3).

**Updating.** The server keeps its own build and content current (§4), but
never the files around it: the unit, the firewall rules, the installer. Those
change only when you run the installer again, so do that after a release --
fetched fresh, as above. It says what it replaced, and restarts the server only
if the build or the unit actually changed: with nothing new, nobody in the pond
is dropped.

`bash install-server.sh --purge` does the same from a clean kit. It first
removes the build and its `.previous`, the unit and every `systemctl edit`
override of it, and the rules file, then installs the release's files and
nothing else -- while keeping `/var/lib/biogenic`, so the invites, the server's
key and the address friends dial all survive, and every invite already sent
still works. Firewall rules already loaded are left alone. To wipe everything,
invites included, uninstall (§6) and install again.

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
[upnp] looking for the router, to forward UDP 45772 to this machine for as long as the server runs -- nothing answers there without an invite
[upnp] forwarded UDP 45772 on the router to this machine, 192.0.2.12:45772, for an hour at a time -- renewed every 30 minutes while the server runs, and taken off when it stops
[upnp] the router says this network's public address is 203.0.113.7 -- set --reach=203.0.113.7 to let friends in (docs/server.md §9.2)
```

The third line is about friends outside the house (§9): until you mint an
invite, it says nothing listens for them. The `[upnp]` lines are the server
asking your router to forward the internet's port to it, a few seconds after
READY (§9.3).

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
from outside the network, calls turned away because too many came from
everywhere at once or the two places for callers still saying hello were taken,
and at the internet door (§9) every call turned away and every caller hung up on
before it proved an invite, once every ten seconds for each reason, whatever the
address -- and the next one says how many like it were held back, so a noisy
device cannot fill the journal. And every guest gets one line as it goes,
however it goes, saying
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
  one in one step (Linux's rename): the running server carries on from the
  file it started from, and the next start is the new build. The build it
  replaced is kept as `/opt/biogenic/biogenic-server.x86_64.previous`; if a
  newer one arrives before the server has restarted onto the last, `.previous`
  stays the build that actually ran.
- **A refused build** -- its checksum wrong, or not starting here -- is deleted
  and the running build left alone, and it is not downloaded again while the
  manifest gives it the same checksum; the log says so once. The server
  remembers that for as long as it runs; after a restart it tries such a build
  once more.
- **The restart waits for an empty pond**: nobody connected, and no phone in
  the house connecting, for thirty seconds. A caller from the internet counts
  once it has proved its invite, and not before, so a stranger knocking on 45772
  cannot hold an update off. Then the server exits and systemd starts it
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

The server listens on **UDP 45771** for the home Wi-Fi, on every address the
container has. The phones reach it across your LAN, nothing else needs to, and
the server answers a caller there only from a home network's address (the note
at the top). **That check is a second line, not the first** (issue #69):

- **It counts the server's own /24 as home**, since the tap code assumes one.
  On a container with a public address, that /24 is a neighbour's at your
  provider -- measured: a phone there joined with no invite.
- **It sees each address as it arrives.** A router that forwards 45771 and
  rewrites the sender to its own LAN address -- some do, for "NAT loopback" --
  makes every caller from the internet look like one at home.

So keep 45771 off the internet before it gets that far:

- **At the router: never forward 45771** -- the server never asks for it.
  UDP 45772 is the internet's: the server asks the router to forward it, by
  UPnP, for as long as it runs (§9.3), and nothing answers there without an
  invite (§9). If the router hands out IPv6, check that its firewall does not
  let inbound IPv6 through to the container -- that needs no forward at all.
- **On the machine: load the rules the installer laid down** at
  `/etc/biogenic/nftables-internet.conf` (§9.6). Their last two drop anything
  that reaches 45771 from outside the home ranges -- loopback, 10/8,
  172.16/12, 192.168/16, 100.64/10 and 169.254/16, and over IPv6 `::1`,
  `fc00::/7` and `fe80::/10` -- which closes the first gap and a public IPv6
  address, whatever the router does. A phone at home never meets them. If your
  home network is in none of those ranges, add it to the rule's first set.
  Load the file in the container, or put the same rules on the Proxmox host's
  firewall in front of it: **one of the two owns both ports' rules**, and you
  should know which. With `ufw` in the container instead: `ufw allow from
  192.0.2.0/24 to any port 45771 proto udp` with your own range in place of
  the placeholder, and no other rule for 45771.

Neither the server nor a rule on it can see through a forward that rewrites
the sender; only the router can refuse it. **So check from outside the house**
that nothing reaches 45771. On the server:

```sh
apt-get install -y tcpdump netcat-openbsd
tcpdump -lni any -A 'udp port 45771' | grep --line-buffered outside-test
```

From a device on another network -- a laptop on a phone's hotspot -- send to
your public address (a placeholder here):

```sh
echo outside-test | nc -u -w1 203.0.113.7 45771
```

Nothing printed on the server within a few seconds: the internet does not reach
45771, which is right. A line printed: something forwards it -- take that
forward off the router. The capture sees a datagram before any rule does, so
the answer is the same with the rules loaded or not. Over IPv6, send to the
container's global address instead (`ip -6 addr show scope global` shows it;
`nc -6 -u -w1 2001:db8::7 45771`). Stop the capture with Ctrl-C. A phone at
home joins with its four taps throughout.

A router's "guest network" or "client isolation" stops devices on it from
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
once, rather than after a connection timeout -- takes its forward off the
router (§9.3), and exits. SIGTERM is only the backstop; a server that dies by
it, or crashes, leaves the forward to lapse by itself within the hour.

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
Forget the revert and nothing on the server says so -- but the installer does:
every run names the overrides still in effect, and this one by what it does.

**Uninstalling**, invites and all:

```sh
systemctl disable --now biogenic-server
rm -rf /etc/systemd/system/biogenic-server.service /etc/systemd/system/biogenic-server.service.d
systemctl daemon-reload
rm -rf /opt/biogenic /var/lib/biogenic /etc/biogenic
userdel biogenic
nft delete table inet biogenic   # only if you loaded the firewall rules (§9.6)
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
- **`[net] the LAN listener closed by itself`** -- a send to a phone in the
  house failed, and Godot closed the listener for the house under it: the
  container's network went away, as when its interface goes down and up. The
  line before it in the journal is Godot's `Sending failed!`. Every phone in
  the house is let go, each with its `done after` line, and the listener opens
  again at once on the same port -- `[net] the LAN listener is open again, 0.0
  s on` -- so a phone calls again as after any drop. A friend by invite is not
  touched. Should something else take the port meanwhile, the server says
  `[net] the LAN listener could not open again: port 45771 is taken -- trying
  again in 1 s`, and tries again after one second, two, four, and so on up to
  a minute, until it is free. Each try it loses is Godot's own `Couldn't
  create an ENet host.` in the journal.
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
- It is built by Godot 4.7.2, held byte for byte to a pinned manifest on
  every CI run, with its own mbedTLS 3.6.7 compiled in: `docs/engine.md` says
  what that carries, which advisories were checked against it, and what an
  engine upgrade repeats (issues #78 and #79).
- It forwards its internet port through Godot's own UPnP (miniupnpc 2.3.3:
  IGD only, no NAT-PMP and no PCP), in `game/net/port_forward.gd`, which knows
  nothing of Biogenic but the port it is given. Every call to the router is on
  a worker thread -- a search with no router answering takes about four
  seconds, and the pond never waits for it. `tools/net_probe.gd`'s `upnp`
  section runs it against a stand-in router, and CI's boots of the server
  search the runner's network for one and find none, which holds their exit
  up by what is left of those four seconds and prints nothing wrong.

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
run beside the service. Run it **as the service's own user, with its home** --
from the root shell the install already needed, with `runuser`, which every
Debian and Ubuntu has (it is util-linux, and a Proxmox container template may
have no `sudo`):

```sh
runuser -u biogenic -- env HOME=/var/lib/biogenic /opt/biogenic/biogenic-server.x86_64 --headless -- --invites
```

With `sudo` instead, where it is installed:

```sh
sudo -u biogenic env HOME=/var/lib/biogenic /opt/biogenic/biogenic-server.x86_64 --headless -- --invites
```

Below, `$BIOGENIC` stands for everything up to and including that `--`:

```sh
BIOGENIC="runuser -u biogenic -- env HOME=/var/lib/biogenic /opt/biogenic/biogenic-server.x86_64 --headless --"
```

Each job says what it did in lines starting `[server]` and exits 0. A job it
refuses exits 1, with a sentence that names the fix.

**Run as root into the service's files, a job does nothing.** What root writes
there is root's alone, and the service -- running as `biogenic` -- could not
read it: a revoke it would never see. So a job run as root with `HOME` pointing
at the service's directory refuses and exits 1, giving back the command above,
with your job in it. Run as root with root's own home, it keeps a book of its
own that the service never reads, and says so.

### 9.2 Tell it where friends call

Friends need an address that reaches your router from the internet: your
public IP address, or a name that leads to it -- a dynamic-DNS name, if your
address changes. Set it once:

```sh
$BIOGENIC --reach=203.0.113.7            # or --reach=pond.example.net
```

It is kept in the server's `user://` and nowhere else. The server's log names
the public address your router reports -- `[upnp] the router says this
network's public address is 203.0.113.7 -- set --reach=203.0.113.7 to let
friends in` (§9.3) -- but the server never sets `--reach` itself: the address
friends dial is the one you chose. If your router forwards
a different outside port to 45772, say which: `--reach=pond.example.net:50000`.
An IPv6 address goes in brackets: `--reach=[2001:db8::7]:45772`. An address
inside your own network gets a warning, because friends outside can never
reach it.

Write the address as what it is, because a friend's phone shows it exactly as
written. `--reach` refuses a few things:
- a number written as a name, which a resolver dials as some other address:
  `2130706433` and `127.1` are both 127.0.0.1;
- an address that is no one machine: `0.0.0.0` or `::`, the broadcast address
  `255.255.255.255`, or a multicast one;
- IPv4 inside IPv6 written in hex (`::ffff:7f00:1` is 127.0.0.1), or spelled
  so that it dials another address than it shows (`0:ffff::203.0.113.7` is
  203.0.113.7) -- write the IPv4 address instead;
- a spelling this build does not read the way the call does, such as a part
  padded past three digits (`203.0000.113.7`) -- write it plainly.

Each refusal says why. An address an older build took that this one will not
call is named, with why, in the server's status line, `--invites` and
`--invite`: set `--reach` again, then mint again for anybody with an invite.

**A name is dialled over IPv4 whenever it has an IPv4 address** (an A record),
even when it has an IPv6 one too: a home router forwards a port over IPv4, and
seldom opens one over IPv6. So IPv6 matters only for a name with no IPv4
address at all -- and then UDP 45772 must be open over IPv6, to this machine,
on your router's firewall: a firewall rule, not a forward, and one the
server's UPnP does not make.

Every invite carries the address it was minted with, so after changing
`--reach`, mint again for anybody who has one.

### 9.3 The one port, on the router

**The server forwards it itself.** From its READY until it stops, it asks your
router to forward **UDP 45772** to this machine's UDP 45772 -- by UPnP, the way
a games console does -- whatever the invites: the forward is always there, and
nothing answers behind it until you mint one (§9.4). It asks for an hour at a
time and renews every half hour, and a clean stop -- `systemctl stop`, a
restart, an update -- takes the forward off: asked for once more first, so
that a router that has given the port to another machine since (after a
restart, say) keeps that one, and the log says `left UDP 45772 on the router`.
A server that is killed or crashes leaves its forward to lapse by itself
within the hour. It never asks for 45771, and it never takes 45772 from
anything else that holds it on the router.

A stop takes well under a second when the router answers. One that does not is
waited for five seconds, then as the process ends for up to fifteen seconds a
call, twice at most, before the process ends itself -- but under `systemd`,
SIGTERM comes ten seconds after the stop was asked, whatever is still waiting.
The `[upnp]` line at the five seconds says which it is.

For the router to hear it:

- **UPnP must be on in the router.** It is often called "UPnP", "UPnP IGD" or
  "allow devices to open ports". Godot's UPnP speaks IGD only: a router that
  offers NAT-PMP or PCP and no IGD -- some Apple and newer routers -- is not
  found, and needs the forward by hand (below).
- **The container must be on the LAN bridge** (§1). The router is found by a
  multicast search on the LAN, which a NAT or internal Proxmox bridge does not
  carry.
- **A firewall on the container or the Proxmox host must let the router
  answer.** The search listens for answers on a port of its own, drawn from
  49152 to 65535 for every search and never 45771 or 45772, and the router
  answers there by UDP -- from port 1900 most often, but not always -- which a
  firewall's "replies are allowed" rule does not recognise as a reply: the
  search went to a multicast address, and the answer comes from the router's
  own. With `ufw` active: `ufw allow proto udp from 192.0.2.1 to any port
  49152:65535`, with your router's address in place of the placeholder -- or,
  plainest, `ufw allow proto udp from 192.0.2.1`. With the Proxmox firewall on
  for this container (Datacenter, node or container level, with inbound
  traffic dropped), the same on the host: an inbound rule for UDP from the
  router's address. The shipped nftables rules (§9.6) touch neither.

It says what happened in lines that start `[upnp]` -- one for each thing that
happens, not one for each look. When the router takes the forward:

```
[upnp] forwarded UDP 45772 on the router to this machine, 192.0.2.12:45772, for an hour at a time -- renewed every 30 minutes while the server runs, and taken off when it stops
[upnp] the router says this network's public address is 203.0.113.7 -- set --reach=203.0.113.7 to let friends in (docs/server.md §9.2)
```

A router that takes no forward with a time limit is given one without -- the
line says `with no time limit` -- which the server still takes off when it
stops, but which a killed server leaves on the router until you take it off.
Renewals are silent; one the router refuses is a line, and so is the renewal
that takes after it. A renewal the router does not answer at all is asked again
by a fresh search, since a router that restarted may answer at another port.

**When it cannot**, the line says why, and the server looks again within ten
minutes, saying nothing more until what it finds changes:

| The line says | What it means | What to do |
|---|---|---|
| `no router answered` | No router answered the search. Other devices -- a TV, a printer -- may well have, but only a device that says it is an Internet Gateway Device counts. UPnP is off in the router, most likely; or the router has none; or the search never reaches it, or its answer never gets back (the bridge and the firewall, above). | Turn UPnP on, or forward by hand. |
| `a router answered the search -- UPnP is on -- but what it says it is could not be read` | A router answered, and the description it pointed to could not be fetched, or does not describe a router that forwards ports: one still starting, or a broken UPnP. | Nothing: it looks again. If the line stays, forward by hand. |
| `the router already forwards UDP 45772 elsewhere` | Something holds the port on the router: a forward made by hand -- which some routers hold against UPnP even when it leads to this very machine -- or another machine's. The server leaves it be. | If it leads to this machine, friends get in anyway: `--no-upnp` stops the asking. If not, take it off the router. |
| `the router would not forward UDP 45772 (...)` | The router refused, for the reason in brackets. | Forward by hand. |
| `the router's own internet address is 100.64.x.x, a shared one` | Carrier-grade NAT: your provider shares one address among many homes. No forward anywhere in the house can reach you. | Ask the provider for a public IPv4 address; or friends call over IPv6 (§9.2), which needs a firewall rule, not a forward. |
| `the router's own internet address is 10.x.x.x, a private one: two routers in a row` | This router sits behind another, usually the provider's box. The server asks this one for nothing: its forward alone could not reach you. | Forward UDP 45772 on the outer router to this one, and on this one to the server, by hand -- or put the outer one in bridge mode. |
| `a router answered whose own internet address is not one the internet can call` | One of the two rows above, from a router that would not say which -- miniupnpd, which many routers run, keeps a private address to itself. | As the two rows above. |
| `the router answered, but says it is not connected to the internet` | Its internet side is down. | Nothing: it looks again. |

**By hand**, forward **UDP 45772** -- or the outside port you gave `--reach` --
to the container's UDP 45772. That is the only port to forward, ever: 45771
stays inside. If the container runs `ufw`: `ufw allow 45772/udp`. Then tell
the server not to ask, so that the two never meet:

```sh
$BIOGENIC --no-upnp     # the server asks the router for nothing, and a running one takes its forward off within seconds
$BIOGENIC --upnp        # the server asks again
```

The switch is kept in the server's `user://`, as `--reach` is, so it holds
across restarts, updates and reinstalls; `--invites` says which way it is set.
On the service's own command line -- `systemctl edit`, as in §6 --
`--no-upnp` beside `--stop-file=` holds for that run only, and writes nothing:
the jobs and `--invites` name a running server's own `--no-upnp` or `--upnp`
when they can see it, since it outranks the switch until that server restarts
without it. **Keep `--stop-file=` on that line**: `--no-upnp` with neither it
nor `--no-update` beside it is a job, which exits at once and is started again
every five seconds, and the server never serves. The installer warns of one.

**Keep the router's own page in mind**: its list of forwards shows this one as
`Biogenic server`, and it is the place to check what the router holds.

### 9.4 Mint an invite, and send it

```sh
$BIOGENIC --invite=sam
```

```
[server] made the server's key and certificate: /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/pond/key.pem (only this user can read it); certificate D6:79:5E:66:34:BD:07:5E
[server] invite for sam written to /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/invites/sam.txt, calling 203.0.113.7:45772 -- send its one line to sam and nobody else, and in Biogenic they tap play, then by invite, then paste invite.
[server] a running server takes it within seconds.
```

The first mint makes the server's key -- RSA-2048, `rw-------` -- and its
self-signed certificate, named `biogenic-pond` and valid from 2020 to 2099, so
a phone whose clock is years out still accepts it (§9.8 says why, and how a
key is replaced). A label is 1 to 24 of `a-z`,
`0-9`, `-` and `_`. It names the friend in the log and the file.

**The secret is never printed**, only the file's path. Copy the line out of the
file and into your messaging app:

```sh
cat /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/invites/sam.txt
```

(as root; `sudo cat` from another account).

It is one line of about 1.1 KB, starting `biogenic-invite:`. It does not matter
if the app wraps it, or if you write a sentence before or after it: the game
finds it. A copy that lost a piece is caught on the phone, as damaged, before it
ever calls. Treat the line like a house key: whoever holds it swims in your pond
as sam until you revoke it.

**The running server picks it up by itself**, within two seconds. The first
invite opens the internet listener, and the log says so:

```
[server] invites: sam added
[server] internet: listening on port 45772/udp for 1 invite (sam), certificate D6:79:5E:66:34:BD:07:5E. Friends call 203.0.113.7:45772, which must reach this machine's 45772/udp: the [upnp] lines say whether the router forwards it, and if not, forward it by hand -- the one port to forward (docs/server.md §9.3).
```

### 9.5 List, replace and revoke

```sh
$BIOGENIC --invites          # labels, when each was made and when it last came in
$BIOGENIC --invite=sam       # again: a new secret, and the line sent before stops working
$BIOGENIC --revoke=sam       # that invite stops working
```

```
[server] friends call 203.0.113.7:45772; the server listens on 45772/udp for them.
[server] upnp: on -- the server asks the router to forward 45772/udp to it (--no-upnp turns that off)
[server] 2 invites:
[server]   kit -- made 2026-09-20 18:02 UTC, last joined never
[server]   sam -- made 2026-09-25 14:03 UTC, last joined 2026-09-25 18:10 UTC
```

A running server notices a revoke or a replacement within two seconds, and a
friend swimming on that invite is cut, reading "invite no longer works"
(`[server] invites: sam revoked`). With no invites left the internet listener
closes, and nothing listens for the internet until you mint again.

**The book keeps 100 invites at most** (issue #85). Once it holds 100,
`--invite` with a new name makes nothing and says so: revoke one nobody uses
first -- `--invites` shows when each last joined, and says when the book is
full. A name already in the book is never refused for this, since minting it
again replaces its invite. A book an older build grew past 100 keeps every
invite it holds, and takes no new name until it is back under.

### 9.6 Limit callers at the firewall

The server's own door already turns away a caller that comes too often (§3),
but it only sees one once the encrypted handshake is done. A firewall rule per
source address stops a flood before that. `install-server.sh` lays the rules
down at **`/etc/biogenic/nftables-internet.conf`** already (checked with `nft -c`
where nftables is present) but does **not** load them -- a firewall is yours to
read and turn on. The same file keeps the LAN's port to home addresses (§5).
Review it, then:

```sh
nft -c -f /etc/biogenic/nftables-internet.conf   # check it, load nothing
nft -f    /etc/biogenic/nftables-internet.conf   # load it now
```

Load it in the container, or put the same rules on the Proxmox host's firewall
in front of it; to keep them across reboots, include the file from
`/etc/nftables.conf` and enable `nftables.service`. Loading it replaces the
whole `biogenic` table, so when an update brings a new copy -- the installer
says so, and that the table is loaded -- `nft -f` again applies it without
doubling a rule. The ruleset:

```
# Biogenic's internet listener, UDP 45772: new calls and datagrams, per source,
# and one combined ceiling for all sources at once. And the LAN's, UDP 45771:
# home addresses only.
table inet biogenic
delete table inet biogenic

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
		udp dport 45772 limit rate over 1200/second burst 2400 packets counter drop
		udp dport 45771 ip saddr != { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16 } counter drop
		udp dport 45771 ip6 saddr != { ::1, fc00::/7, fe80::/10 } counter drop
	}
}
```

Each address -- each /64, over IPv6 -- gets twenty new calls, then ten a
minute, and 800 datagrams, then 400 a second. A call is one new flow (two after
one that failed, which the phone checks once more), and a friend swimming sends
at most about a hundred datagrams a second. Two friends behind one router share
an address, and fit. The fifth rule is the ceiling for everyone together --
2400 datagrams, then 1200 a second across the whole port -- so a burst spread
over many addresses cannot pass the per-source rules unbounded. The two after
it are §5's: 45771 answers home addresses and nothing else.

### 9.7 Keep the engine's handshake errors out of the journal

A caller that is not a Biogenic build -- a port scanner, anything speaking plain
UDP to 45772 -- makes the engine itself print an error line for each handshake
it cannot finish, before any of the server's own code sees the caller, so the
server's limiter cannot hold them back. The shipped unit already caps this:

```ini
LogRateLimitIntervalSec=30s
LogRateLimitBurst=200
```

Past 200 lines in 30 s, journald keeps the rest out and says how many it
suppressed. The limit covers every line the unit prints, but the server's own
are already at most one of each kind per address every ten seconds (§3), so on
an ordinary day it never bites. To change it, `systemctl edit biogenic-server`
with your own values and `systemctl restart biogenic-server`.

The engine's lines look like these, and none of them is the server failing:

- `ERROR: TLS handshake error: -30464` -- a datagram that was not a handshake:
  plain UDP, or a handshake the listener had no room for.
- `ERROR: TLS handshake error: -30592` -- the caller refused this certificate:
  an invite from another server, or one from before `--new-key`.
- `ERROR: Parameter "p_mutex->mutex" is null.`, three at a time, whenever the
  internet listener closes: a bug in Godot 4.7's DTLS server, harmless.
- `ERROR: Couldn't add port mapping.`, `ERROR: Couldn't delete port mapping.`
  and `ERROR: Couldn't get external IP address.` -- the router said no to the
  server's forward (§9.3), and the `[upnp]` line straight after says what and
  why. The first also comes once from a router that takes no forward with a
  time limit, just before the server asks for one without.
- `sendto: Network is unreachable` -- UPnP's search found no route for its
  multicast: the container has an address but no route out of it. The
  `[upnp]` line after it says no router answered.
- `connect: Connection refused` -- the router did not answer where it said it
  would, usually because it restarted: the server searches for it afresh, and
  says so only if the renewal does not take (§9.3).
- `bind: Address already in use` -- the port a search drew for itself was
  taken; it draws another at once.

### 9.8 A new key

`--new-key` makes the server a new key and certificate, and every invite made
with the old one stops working: each carries the old certificate, and the book
is emptied. One job can make the key and mint everybody again:

```sh
$BIOGENIC --invites                                  # who to mint again
$BIOGENIC --new-key --invite=kit --invite=sam
```

```
[server] made the server's key and certificate: /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/pond/key.pem (only this user can read it); certificate 46:6C:97:79:19:7D:09:E3
[server] every invite made with the old key no longer works: kit, sam. Mint each of them again.
[server] invite for kit written to /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/invites/kit.txt, calling 203.0.113.7:45772 -- send its one line to kit and nobody else, and in Biogenic they tap play, then by invite, then paste invite.
[server] a running server takes it within seconds.
[server] invite for sam written to /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/invites/sam.txt, calling 203.0.113.7:45772 -- send its one line to sam and nobody else, and in Biogenic they tap play, then by invite, then paste invite.
```

**A running server changes over by itself**, within two seconds: a friend
swimming on an old invite is told "invite no longer works", and the listener
comes back about a second later, answering with the new key. Its listening
line names the certificate the job printed -- that is how you know it took:

```
[server] internet: the server's key changed -- every guest on an invite made with the old one is cut, and the listener reopens with the new one
[server] internet: listening on port 45772/udp for 2 invites (kit, sam), certificate 46:6C:97:79:19:7D:09:E3. Friends call 203.0.113.7:45772, which must reach this machine's 45772/udp: the [upnp] lines say whether the router forwards it, and if not, forward it by hand -- the one port to forward (docs/server.md §9.3).
```

Send each friend their new line (§9.4). Pasted, it replaces the old one on
their phone -- a phone keeps one invite -- and they call as before. **The LAN is
untouched**: its listener has no key, and a phone at home swims on.

**Why the certificate runs from 2020 to 2099.** A phone accepts only the server
that proves it holds the key of the certificate in its invite. The dates add
nothing to that proof, and they cost something: the phone checks them against
its own clock, and a certificate outside them fails, whichever side holds it --
so a phone whose clock is years out would be shut out of a pond it was invited
to. Nor can a certificate be renewed past an invite: one made again on the same
key passes the pin only while the certificate inside the invite is still in
date (net_probe C9, measured on 4.7). A certificate that expired would take
every invite with it; a shorter life would only make this job run on a timer.
So nothing here expires, and **a new key is how a certificate ends.**

**What a copied key lets someone do** -- `pond/key.pem`, from a backup, a copy
of the container, or a disk that left the house:

- **Answer as your server** to any phone whose invite was made with it, if they
  can also get between that phone and the server: your dynamic-DNS account, or
  the network the phone calls over. The phone would swim in their pond, or
  through them in yours.
- **Not read calls already made.** Every call agrees a key of its own that the
  server's key never sees -- two Godot builds settle on ECDHE-RSA with
  ChaCha20-Poly1305, which is forward secret -- so a recording stays sealed.
- **Most likely, more than the key.** Whatever copied it probably copied the
  invite book beside it, and the book lets anybody call as any friend, from
  anywhere, without getting between anybody.

A new key answers all three: the key and every invite go together.

**When to make one**: whenever the key, or anything holding
`/var/lib/biogenic`, may have been copied -- and on a routine of your own if you
want one, since it is the one way to make every line ever sent stop working.
Nothing needs it on a timer.

**If the key may have been copied**, in this order:

1. **Run the job straight away** -- it is the containment. Within two seconds
   every invite made with the old key is refused, and anybody swimming on one
   is told. Nothing needs stopping first. If you cannot reach the server's
   shell yet, turn UPnP off on the router and take the `Biogenic server`
   forward off it (§9.3) until you can -- with UPnP on, the server would put
   the forward back within half an hour: friends read "no answer" meanwhile,
   and the LAN plays on.
2. **Check that it took.** The job exits 0 and prints the new certificate, and
   the journal says the key changed, then names the same certificate:
   ```sh
   journalctl -u biogenic-server --since "-5 min" | grep 'internet:'
   ```
3. **Mint each friend again** and send each line **over a channel you trust** --
   not the chat an old line may have leaked from -- and ask each to paste it,
   which replaces the old invite on their phone: it no longer trusts the old
   key.
4. **A new key does not clean a machine.** If the container itself may have
   been broken into, build a new one (§1, §2) and set it up there: its first
   mint makes a key nobody has seen. `install-server.sh --purge` keeps
   `/var/lib/biogenic`, key included -- it reinstalls the kit, and cleans
   nothing.

**If something goes wrong**

- **The job exits 1, saying nothing was changed**: the old key, certificate and
  invites are exactly as they were -- the new pair is written in full before
  either replaces the old. Fix what it names -- a full disk (`df -h
  /var/lib/biogenic`), or a job run as the wrong user (§9.1) -- and run it
  again.
- **It says the new certificate could not be put in place after the new key**:
  until a run goes through, no invite can call in, which is the safe way to
  fail. Run it again.
- **A friend was offline**: nothing to do until they call. Their old line meets
  "a different server" (§9.9); send them the new one.
- **A new line meets "a different server"**: the server still answers with the
  old key. The certificate in its listening line says which it has; a job run
  as another user kept a book of its own (§9.1).
- **A backup restored over `/var/lib/biogenic`** from before the new key brings
  the old key and invites back, and with them whatever you replaced them for.
  Run `--new-key` again after any such restore.

### 9.9 When a friend cannot get in

What their phone says, and what to look for in `journalctl -u biogenic-server`:

- **"no answer"** -- nothing answered within eight seconds. The port is not
  forwarded -- the `[upnp]` lines say whether the router took the server's
  forward, and why not (§9.3) -- `--reach` names the wrong address
  (`--invites` shows it, and the `[upnp]` line with the router's public
  address is the one to compare it with), the server is down, or the friend's
  network blocks UDP. No `[net]` line: the call never reached the server. The
  same, from a network that stays silent rather than refusing, when nothing
  listens (below).
- **"no server there"** -- the address refused the call: nothing listens on
  that port. With no invites the internet listener is closed (`[server]
  internet: nothing listens for the internet`), or the router forwards to the
  wrong port or machine. It is also closed when the server cannot read its
  invite book -- a job run as another user wrote it -- and says so until it
  can:
  ```
  [server] internet: not listening for the internet: /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic/pond/invites.cfg cannot be read by biogenic, so no invite is taken until it can -- another user wrote it, an invite job run as root most likely. Give the files back with chown -R biogenic: /var/lib/biogenic/.local/share/godot/app_userdata/Biogenic, and run the jobs as biogenic (docs/server.md §9.1).
  ```
  Run that `chown`, and the listener is back within a couple of seconds.
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
  pasted. A friend swimming when the server stops being able to read its book
  reads this too, and needs the game restarted once it reads again.
- **"nowhere by that name"** -- the name in the invite did not resolve: check
  your dynamic-DNS name.
- **"different versions"** -- the phone or the server is older. The server
  updates itself once its water is empty (§4), the phone from its launcher.
  The server bars that phone's address for a minute, so a call again inside it
  reads "they hung up"; it is never barred for longer than that.
- **"already two"** -- two friends are in. The limit counts the home Wi-Fi and
  the internet together.
- **"they hung up"** -- the server closed the call. Most often it proved nothing
  within three seconds -- a link too poor, or not a Biogenic build at all --
  which bars the address for a minute, as a refused invite does; or the address
  was barred already, and the door cut the call the moment it connected:
  ```
  [net] hung up on 1587052382 (198.51.100.4): no greeting -- challenged, and no proof -- barred 60 s
  [net] refused 198.51.100.4 on the internet listener: barred for 41 s more
  ```
  The phone says to call again in a minute, which is the bar; a second one
  within ten minutes lasts ten. The server holds two places for callers still
  proving their invite, and a stranger that proves nothing gives its place up
  to the next caller after a second and a half. Every caller that leaves those
  places without proving an invite is barred, however it leaves -- hanging up,
  or sending anything but the handshake -- and a phone on another version is
  barred for a minute, never ten. Over IPv6, once three addresses from one
  home's block (a /56) are barred, the whole block is:
  ```
  [net] hung up on 1587052382 (198.51.100.4): no greeting -- challenged, and no proof in 1.8 s, and a caller waiting behind it -- barred 60 s
  [net] 1587052382 (198.51.100.4) hung up 0.4 s after it called, having proved nothing -- barred 60 s
  [net] cut 1587052382 (198.51.100.4): spoke before its proof -- barred 60 s
  [net] barred 2001:db8:0:100::/56 for 60 s at the internet door: 3 of its /64s barred inside 600 s
  [net] refused 2001:db8:0:1ff::5 on the internet listener: barred for 41 s more, with the /56 it is in
  ```
  A friend barred with a stranger -- behind the same carrier's shared address,
  or in the same /56 -- waits out the bar too (docs/design/net-hardening.md
  E.3). It is also what a friend swimming reads when
  the server is stopped -- an update never restarts it with anyone in (§4).
- **"cut off"** -- the server's gate or referee cut the friend for sending what
  no Biogenic build sends, or far more than any phone sends (§3). The `[net]
  cut` line names what, and the invite: `[net] cut 694971552 (203.0.113.9,
  invite sam): ...`. It is almost always a build out of date: the phone takes
  the update from its launcher, and the server takes its own (§4).
- **"could not call"** -- the phone could not start the call: it has no
  network at all, or the invite names an IPv6 address and the phone's network
  has none. No `[net]` line: nothing reached the server. For a name, see §9.2.

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

### 9.10 Tighten the service further (optional)

The unit `install-server.sh` lays down already runs the network-facing process
with least privilege that costs nothing on the container of §1: no
capabilities, no new privileges, no writable-and-executable memory, only the
address families it uses, and the syscalls of a service and no more. That is
the shipped default, measured on the exported build.

The next step up seals the filesystem off, so a hole in the process cannot read
or rewrite anything but its own state. Those directives need a **mount
namespace**, which an unprivileged LXC only grants with nesting on, so they are
not in the shipped unit -- a container that follows §1 without nesting would
fail to start the service if they were. To turn them on:

1. On the Proxmox **host**, give the container nesting and restart it:
   ```sh
   pct set 120 --features nesting=1
   pct reboot 120
   ```
   (Or create it in §1 with `--features nesting=1` from the start.)
2. Inside the container, `systemctl edit biogenic-server` and add:
   ```ini
   [Service]
   ProtectSystem=strict
   # The two the process must still write: its own state, and the executable it
   # replaces when it updates itself (§4).
   ReadWritePaths=/opt/biogenic /var/lib/biogenic
   ProtectHome=yes
   PrivateTmp=yes
   PrivateDevices=yes
   ProtectKernelTunables=yes
   ProtectControlGroups=yes
   ProtectProc=invisible
   ProcSubset=pid
   ProtectHostname=yes
   # A syscall allow-list for a service. Broad enough for a Godot build, but
   # test the boot below before you rely on it.
   SystemCallFilter=@system-service
   SystemCallErrorNumber=EPERM
   ```
3. `systemctl daemon-reload && systemctl restart biogenic-server`, then
   **confirm it came up** -- a missing namespace or a filtered syscall shows
   here, not later:
   ```sh
   systemctl status biogenic-server        # active (running), not 226/NAMESPACE
   journalctl -u biogenic-server -n 20      # the READY line, both listeners
   ```
   Then join once from the LAN, and once by invite, and run an invite job
   (§9.1) -- the writable paths above are what let the update and the jobs keep
   working. If the service will not start, remove the drop-in
   (`systemctl edit biogenic-server`, clear it) and it is back to the shipped
   default.

Even sealed this way the account can still rewrite its own next executable --
that is the price of the self-update (§4), and `ReadWritePaths=/opt/biogenic` is
where it is paid. What actually authenticates a new build is a separate,
unfinished piece of work (release signing); the sandbox narrows the blast
radius, it does not replace it.

### 9.11 The logs name who called (issue #90)

Once the internet port is open the server writes a caller's address to its log
on every join, departure and refusal -- an IPv4 address, or an IPv6 one by its
/64 -- beside the invite's label. It never logs a secret or a whole invite
line: only what an operator needs to see who is calling and why one was turned
away (§9.9).

Those lines land in **two** places, and both are the operator's alone:

- The **systemd journal** (`journalctl -u biogenic-server`), which only root and
  the `systemd-journal`/`adm` groups can read.
- Godot's **own log file**, `…/app_userdata/Biogenic/logs/godot.log` under
  `/var/lib/biogenic`, which mirrors the journal line for line. The state tree
  is `0700` and its files `0600` (the unit's `StateDirectoryMode` and `UMask`,
  and the installer), so no other local account can reach it.

What is left to you is **how long they are kept and where they may go**:

- **Retention.** The journal's is systemd's: cap it with `MaxRetentionSec=` (or
  `SystemMaxUse=`) in `/etc/systemd/journald.conf`, or trim now with
  `journalctl --vacuum-time=14d`. Godot's file log is not time-bounded -- it
  keeps a handful of timestamped copies and rotates by count, not age -- so it
  is the journal's retention that decides how far back an address can be read;
  the file copy cannot be switched off without a new build, so bound the journal
  and let disk bound the file, or delete `logs/*.log` on a schedule if you keep
  addresses for less time than a build runs.
- **Sharing.** A support bundle or a public bug report is where an address
  escapes the two private stores above -- redact them before you paste a log,
  and do not attach `journalctl` output or `godot.log` to anything public.
- **Jurisdiction.** Whether an address is personal data, and how long you may
  keep it, depends on where the server runs and who its friends are; decide that
  for your own deployment rather than from a number here.
