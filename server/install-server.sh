#!/usr/bin/env bash
# Installs, repairs or updates Biogenic's dedicated server on Debian or Ubuntu
# -- written for a Proxmox LXC with no desktop -- as a systemd service.
#
#   curl -fsSLO https://github.com/sinikebe/biogenic/releases/latest/download/install-server.sh
#   less install-server.sh          # it is short: read it before you run it
#   sudo bash install-server.sh             # install, or update what the server cannot
#   sudo bash install-server.sh --purge     # the same, from a clean kit (below)
#
# **Run it again to update.** The server updates its own build and content every
# ten minutes, but never the files around it -- this unit, the firewall rules,
# this installer. Running it again brings those to the latest release, says what
# it replaced, and restarts the server only if the build or the unit actually
# changed: with nothing to replace, nobody in the pond is dropped.
#
# In order, and every step is safe to run again:
#   1. makes sure curl and the CA certificates are there;
#   2. creates the system user `biogenic` (no login shell, home /var/lib/biogenic,
#      which is where Godot keeps the server's user:// -- staged content packs,
#      update state, its own log files, the invites and the server's key);
#   3. downloads the server build, its unit file, the firewall rules and
#      SHA256SUMS, all from the one release that is the latest when it starts,
#      and installs nothing unless all three match;
#   4. puts the build in /opt/biogenic, owned by `biogenic`, because the server
#      replaces its own binary when a new one is published;
#   5. installs biogenic-server.service and enables it, lays the firewall rules
#      for both ports in /etc/biogenic without loading them (docs/server.md §5,
#      §9.6), and names any `systemctl edit` override still in effect;
#   6. starts the server -- or restarts it, if the build or the unit changed --
#      and prints the address and the join code it logs.
#
# --purge first removes the installed kit -- the build and its .previous
# rollback copy, the unit and every `systemctl edit` override of it, the
# firewall rules file -- and then installs it fresh: the release's files and
# nothing else. It keeps /var/lib/biogenic -- the invites, the server's key, the
# address friends dial -- so every invite already sent still works, and it does
# not touch firewall rules already loaded. To wipe those too, uninstall first
# (docs/server.md §6).
#
# Nothing here loads a firewall rule or touches your router -- but the server it
# starts asks your router to forward UDP 45772 to it, by UPnP, for as long as it
# runs (docs/server.md §9.3; --no-upnp turns that off). Nothing answers there
# until you mint an invite: the server is for your home LAN until then, friends
# outside the house come in on that second port by invite only, and
# docs/server.md §9 says how -- including when to load the firewall rules from
# step 5.
#
# BIOGENIC_REPO=owner/name installs from another fork's releases, and
# BIOGENIC_RELEASE_URL, used as it is, from anywhere curl can read one
# release's assets from -- a mirror, or file:///some/dir holding them.
set -euo pipefail

REPO="${BIOGENIC_REPO:-sinikebe/biogenic}"
PREFIX="/opt/biogenic"
STATE="/var/lib/biogenic"
ACCOUNT="biogenic"
BINARY="biogenic-server.x86_64"
UNIT="biogenic-server.service"
UNIT_FILE="/etc/systemd/system/$UNIT"
OVERRIDES="/etc/systemd/system/$UNIT.d"
NFT_CONF="nftables-internet.conf"
NFT_DIR="/etc/biogenic"
PORT="45771"
NET_PORT="45772"

say() { printf '==> %s\n' "$*"; }
die() { printf 'install-server: %s\n' "$*" >&2; exit 1; }
# The server's [upnp] lines since its latest READY, but the one that says it is
# looking: what the router made of the forward. Only since READY, because a
# restart puts the old process's own lines -- "took the forward ... off" as it
# stopped -- in the journal after any time taken before the restart. Arguments
# go to journalctl.
upnp_since_ready() {
	journalctl -u "$UNIT" "$@" -o cat --no-pager 2>/dev/null \
		| awk '/^\[server\] READY/ { said = "" }
			/^\[upnp\] / && !/^\[upnp\] looking for the router/ { said = said $0 "\n" }
			END { printf "%s", said }' || true
}

purge=0
for arg in "$@"; do
	case "$arg" in
		--purge) purge=1 ;;
		*) die "unknown option $arg -- the only one is --purge" ;;
	esac
done

[[ ${EUID} -eq 0 ]] || die "run it as root: sudo bash $0"
[[ "$(uname -m)" == "x86_64" ]] || die "the server is built for x86_64, and this is $(uname -m)"
command -v systemctl >/dev/null 2>&1 || die "this needs systemd, and there is no systemctl here"
# systemctl alone proves nothing: a Docker container has it and no systemd.
[[ -d /run/systemd/system ]] \
	|| die "this needs systemd running as the service manager, and it is not running here"

# 0. --purge: the kit goes, the state stays. `disable --now` stops the server
#    the clean way (its ExecStop tells the guests) and drops the enable link, so
#    nothing dangles once the unit file is gone.
if (( purge )); then
	say "purging the installed kit: $PREFIX, $UNIT_FILE and its overrides, $NFT_DIR"
	say "keeping $STATE -- the invites, the server's key and the address friends dial"
	systemctl disable --now --quiet "$UNIT" 2>/dev/null || true
	rm -rf "$PREFIX" "$UNIT_FILE" "$OVERRIDES" "$NFT_DIR"
	systemctl daemon-reload
fi

# 1. What the rest needs. coreutils (sha256sum, install, cmp, timeout, tail) and
#    passwd (useradd) are in every Debian and Ubuntu base system.
if ! command -v curl >/dev/null 2>&1 || [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
	say "installing curl and ca-certificates"
	apt-get update -qq
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates
fi

# 2. The account the server runs as, and the two directories it owns.
if ! id -u "$ACCOUNT" >/dev/null 2>&1; then
	say "creating the system user $ACCOUNT"
	useradd --system --user-group --home-dir "$STATE" --no-create-home \
		--shell /usr/sbin/nologin --comment "Biogenic dedicated server" "$ACCOUNT"
fi
# The build lives world-readable in $PREFIX; the state tree is private, because
# Godot's log under it carries callers' addresses (issue #90). install -d
# re-applies the mode on an existing tree, chmod takes back what an older
# install left readable, and the unit's StateDirectoryMode and UMask hold both
# at every start.
install -d -m 0755 "$PREFIX"
install -d -m 0700 "$STATE"
chown "$ACCOUNT:$ACCOUNT" "$PREFIX" "$STATE"
chmod -R go-rwx "$STATE"

# 3. The latest release's build, unit and firewall rules, checked against its
#    SHA256SUMS, which CI writes over every asset it publishes -- all from one
#    release. releases/latest/download/ is looked up again for every file, so a
#    release published in the middle of an install could hand over a build from
#    one and SHA256SUMS from the other, and a checksum "mismatch" for nothing.
#    The tag `latest` points at is read once, and everything is fetched from it.
if [[ -n "${BIOGENIC_RELEASE_URL:-}" ]]; then
	BASE="$BIOGENIC_RELEASE_URL"
else
	latest="$(curl -fsS --retry 3 -o /dev/null -w '%{redirect_url}' \
		"https://github.com/${REPO}/releases/latest")" \
		|| die "could not reach https://github.com/${REPO}/releases/latest"
	tag="${latest##*/releases/tag/}"
	[[ "$latest" == */releases/tag/* && -n "$tag" && "$tag" != */* ]] \
		|| die "https://github.com/${REPO}/releases/latest names no release -- is one published?"
	BASE="https://github.com/${REPO}/releases/download/${tag}"
	say "the latest release is ${tag}"
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
say "downloading the latest server from ${BASE}/"
for file in "$BINARY" "$UNIT" "$NFT_CONF" SHA256SUMS; do
	curl -fsSL --retry 3 -o "$work/$file" "$BASE/$file" \
		|| die "could not download $file from $BASE/ -- is a release with the server published?"
done
awk -v a="$BINARY" -v b="$UNIT" -v c="$NFT_CONF" '$2 == a || $2 == b || $2 == c' \
	"$work/SHA256SUMS" > "$work/wanted.sums"
[[ "$(wc -l < "$work/wanted.sums")" -eq 3 ]] \
	|| die "SHA256SUMS does not list $BINARY, $UNIT and $NFT_CONF; installing nothing"
(cd "$work" && sha256sum --check --strict --quiet wanted.sums) \
	|| die "checksum mismatch; installing nothing"
say "the build, the unit and the firewall rules match SHA256SUMS"

# 4. The build: written next to the old one and renamed over it, so a server
#    that is running keeps running until a restart. The same bytes as the
#    installed build -- the server has usually taken the release itself -- are
#    left where they are.
new_build=0
if cmp -s "$work/$BINARY" "$PREFIX/$BINARY"; then
	say "the build in $PREFIX is already this release's -- unchanged"
else
	install -o "$ACCOUNT" -g "$ACCOUNT" -m 0755 "$work/$BINARY" "$PREFIX/.$BINARY.install"
	mv -f "$PREFIX/.$BINARY.install" "$PREFIX/$BINARY"
	new_build=1
	say "installed $PREFIX/$BINARY"
fi
chown -R "$ACCOUNT:$ACCOUNT" "$PREFIX"

# 5. The service.
new_unit=0
if cmp -s "$work/$UNIT" "$UNIT_FILE"; then
	say "the service file is already this release's -- unchanged"
else
	install -o root -g root -m 0644 "$work/$UNIT" "$UNIT_FILE"
	systemctl daemon-reload
	new_unit=1
	say "installed $UNIT_FILE"
fi
systemctl enable --quiet "$UNIT"
# Overrides made with `systemctl edit` sit beside the unit and outlive every
# reinstall but --purge. Most are wanted (docs/server.md §9.10), but one left
# from going back to a previous build (§6) keeps the server from ever updating
# itself again, and nothing else would say so.
if compgen -G "$OVERRIDES/*.conf" >/dev/null; then
	say "systemctl edit overrides in effect (kept; --purge removes them):"
	for override in "$OVERRIDES"/*.conf; do
		printf '      %s\n' "$override"
	done
	if grep -qs -- '--no-update' "$OVERRIDES"/*.conf; then
		say "an override runs the server with --no-update: it will not update itself" \
			"until you remove it -- systemctl revert $UNIT"
	fi
	if grep -qs -- '--no-upnp' "$OVERRIDES"/*.conf; then
		say "an override runs the server with --no-upnp: it will not ask the router to" \
			"forward UDP $NET_PORT -- forward it by hand (docs/server.md §9.3)"
	fi
	# --no-upnp or --upnp with neither --stop-file= nor --no-update beside it is
	# no run but a job (docs/server.md §9.3): it exits at once, systemd starts it
	# again every five seconds, and the server never serves.
	if grep -hs '^[[:space:]]*ExecStart=.' "$OVERRIDES"/*.conf \
			| grep -e '--no-upnp' -e '--upnp' | grep -qv -e '--stop-file=' -e '--no-update'; then
		say "an override's ExecStart= gives --no-upnp or --upnp without --stop-file=: that is" \
			"a job, which exits at once and is started again every 5 s -- the server never" \
			"serves. Keep --stop-file=/run/biogenic/stop on that line (docs/server.md §6)"
	fi
fi

# 5b. The firewall rules for both ports, laid down but never loaded: a network
#     firewall is the owner's to review and turn on (docs/server.md §5, §9.6).
#     The file replaces the whole table when it is loaded, so loading this
#     release's copy over an older one never doubles a rule.
install -d -m 0755 "$NFT_DIR"
if cmp -s "$work/$NFT_CONF" "$NFT_DIR/$NFT_CONF"; then
	rules="unchanged"
else
	rules="$([[ -e "$NFT_DIR/$NFT_CONF" ]] && echo updated || echo installed)"
	install -o root -g root -m 0644 "$work/$NFT_CONF" "$NFT_DIR/$NFT_CONF"
fi
if ! command -v nft >/dev/null 2>&1; then
	say "firewall rules at $NFT_DIR/$NFT_CONF ($rules; nftables is not installed here)" \
		"-- review, then load them with nft, or on the Proxmox host"
elif nft list table inet biogenic >/dev/null 2>&1; then
	if [[ "$rules" != unchanged ]]; then
		say "firewall rules at $NFT_DIR/$NFT_CONF ($rules) -- a biogenic table is loaded;" \
			"apply this release's with: nft -f $NFT_DIR/$NFT_CONF"
	else
		say "firewall rules at $NFT_DIR/$NFT_CONF (unchanged) -- loaded"
	fi
elif nft -c -f "$NFT_DIR/$NFT_CONF" >/dev/null 2>&1; then
	say "firewall rules at $NFT_DIR/$NFT_CONF ($rules, checked, not loaded)" \
		"-- review, then: nft -f $NFT_DIR/$NFT_CONF"
else
	say "firewall rules at $NFT_DIR/$NFT_CONF ($rules) -- nft could not check them here;" \
		"review before loading"
fi

# 6. Running, and where it is, as it says itself. A server already running the
#    build and unit it would be given keeps running: a restart would only drop
#    whoever is in the pond. One that took the build itself and is waiting for
#    an empty pond (docs/server.md §4) keeps waiting, as it would have anyway.
since="$(date '+%Y-%m-%d %H:%M:%S')"
waiting=1
if ! systemctl is-active --quiet "$UNIT"; then
	say "starting $UNIT"
	systemctl start "$UNIT"
elif (( new_build || new_unit )); then
	say "restarting $UNIT for the new $( (( new_build )) && echo build)$( (( new_build && new_unit )) && echo ' and ')$( (( new_unit )) && echo 'service file')" \
		"(anyone in the pond is dropped and swims on alone)"
	systemctl restart "$UNIT"
else
	say "nothing the server runs changed, so it keeps running -- nobody is dropped"
	waiting=0
fi
ready=""
if (( waiting )); then
	for _ in $(seq 1 30); do
		ready="$(journalctl -u "$UNIT" --since "$since" -o cat --no-pager 2>/dev/null \
			| grep -E '^\[server\] (READY|to join|internet|could not listen)' || true)"
		if grep -q '^\[server\] READY' <<<"$ready"; then
			break
		fi
		sleep 1
	done
else
	ready="$(journalctl -u "$UNIT" -o cat --no-pager 2>/dev/null \
		| grep -E '^\[server\] (READY|internet)' | tail -2 || true)"
fi
# 6b. What the router made of the server's forward (docs/server.md §9.3). It
#     asks after READY, and a search that finds no router takes about four
#     seconds, so a few more for its answer.
router=""
if (( waiting )) && grep -q '^\[server\] READY' <<<"$ready"; then
	for _ in $(seq 1 10); do
		router="$(upnp_since_ready --since "$since")"
		[[ -n "$router" ]] && break
		sleep 1
	done
elif ! (( waiting )); then
	router="$(upnp_since_ready | tail -2)"
fi
echo
printf '%s\n' "$ready"
if [[ -n "$router" ]]; then
	printf '%s\n' "$router"
fi
if (( waiting )) && ! grep -q '^\[server\] READY' <<<"$ready"; then
	say "the server has not said READY yet; its log: journalctl -u $UNIT -e"
fi
cat <<EOF

The address and the code again, any time:
  journalctl -u $UNIT -o cat | grep -E '^\[server\] (READY|listening|to join)' | tail -2
Everything it says, as it says it:
  journalctl -u $UNIT -f

It listens on UDP $PORT, for your home network only: never forward that port on
your router -- the server never asks for it. Friends outside the house come in
by invite, on UDP $NET_PORT: the server asks your router to forward that one to
it, by UPnP, for as long as it runs -- its [upnp] lines say whether the router
did, and if not, forward it by hand (docs/server.md §9.3) -- and nothing answers
there until you mint an invite (docs/server.md §9).
EOF
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
	echo
	echo "ufw is active here. Let the LAN in, and only the LAN, with something like:"
	echo "  sudo ufw allow from 192.0.2.0/24 to any port $PORT proto udp"
	echo "(192.0.2.0/24 is a placeholder: use your own network's range.)"
	echo "And let the router answer the server's UPnP search -- which listens on a port"
	echo "from 49152 to 65535 -- or it finds no router:"
	echo "  sudo ufw allow proto udp from 192.0.2.1 to any port 49152:65535"
	echo "(192.0.2.1 is a placeholder: use your router's address -- docs/server.md §9.3.)"
fi
