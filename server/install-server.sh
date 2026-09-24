#!/usr/bin/env bash
# Installs, repairs or updates Biogenic's dedicated server on Debian or Ubuntu
# -- written for a Proxmox LXC with no desktop -- as a systemd service.
#
#   curl -fsSLO https://github.com/sinikebe/biogenic/releases/latest/download/install-server.sh
#   less install-server.sh          # it is short: read it before you run it
#   sudo bash install-server.sh
#
# In order, and every step is safe to run again:
#   1. makes sure curl and the CA certificates are there;
#   2. creates the system user `biogenic` (no login shell, home /var/lib/biogenic,
#      which is where Godot keeps the server's user:// -- staged content packs,
#      update state, its own log files);
#   3. downloads the latest server build, its unit file and SHA256SUMS from the
#      latest release, and installs nothing unless both files match;
#   4. puts the build in /opt/biogenic, owned by `biogenic`, because the server
#      replaces its own binary when a new one is published;
#   5. installs biogenic-server.service, enables it, and starts or restarts it;
#   6. prints the address and the join code the server logs.
#
# Nothing here touches your router or your firewall. The server is for your
# home LAN only; docs/server.md says why, and what internet play would take.
#
# BIOGENIC_REPO=owner/name installs from another fork's releases, and
# BIOGENIC_RELEASE_URL from anywhere curl can read a release's assets from --
# a mirror, or file:///some/dir holding them.
set -euo pipefail

REPO="${BIOGENIC_REPO:-sinikebe/biogenic}"
BASE="${BIOGENIC_RELEASE_URL:-https://github.com/${REPO}/releases/latest/download}"
PREFIX="/opt/biogenic"
STATE="/var/lib/biogenic"
ACCOUNT="biogenic"
BINARY="biogenic-server.x86_64"
UNIT="biogenic-server.service"
PORT="45771"

say() { printf '==> %s\n' "$*"; }
die() { printf 'install-server: %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "run it as root: sudo bash $0"
[[ "$(uname -m)" == "x86_64" ]] || die "the server is built for x86_64, and this is $(uname -m)"
command -v systemctl >/dev/null 2>&1 || die "this needs systemd, and there is no systemctl here"

# 1. What the rest needs. coreutils (sha256sum, install, timeout, tail) and
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
install -d -m 0755 "$PREFIX" "$STATE"
chown "$ACCOUNT:$ACCOUNT" "$PREFIX" "$STATE"

# 3. The latest release's build and unit, checked against its SHA256SUMS, which
#    CI writes over every asset it publishes.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
say "downloading the latest server from ${BASE}/"
for file in "$BINARY" "$UNIT" SHA256SUMS; do
	curl -fsSL --retry 3 -o "$work/$file" "$BASE/$file" \
		|| die "could not download $file from $BASE/ -- is a release with the server published?"
done
awk -v a="$BINARY" -v b="$UNIT" '$2 == a || $2 == b' "$work/SHA256SUMS" > "$work/wanted.sums"
[[ "$(wc -l < "$work/wanted.sums")" -eq 2 ]] \
	|| die "SHA256SUMS does not list both $BINARY and $UNIT; installing nothing"
(cd "$work" && sha256sum --check --strict --quiet wanted.sums) \
	|| die "checksum mismatch; installing nothing"
say "both files match SHA256SUMS"

# 4. The build: written next to the old one and renamed over it, so a server
#    that is running keeps running until the restart below.
install -o "$ACCOUNT" -g "$ACCOUNT" -m 0755 "$work/$BINARY" "$PREFIX/.$BINARY.install"
mv -f "$PREFIX/.$BINARY.install" "$PREFIX/$BINARY"
chown -R "$ACCOUNT:$ACCOUNT" "$PREFIX"
say "installed $PREFIX/$BINARY"

# 5. The service.
install -o root -g root -m 0644 "$work/$UNIT" "/etc/systemd/system/$UNIT"
systemctl daemon-reload
systemctl enable --quiet "$UNIT"
since="$(date '+%Y-%m-%d %H:%M:%S')"
if systemctl is-active --quiet "$UNIT"; then
	say "restarting $UNIT (anyone in the pond is dropped and swims on alone)"
	systemctl restart "$UNIT"
else
	say "starting $UNIT"
	systemctl start "$UNIT"
fi

# 6. Where it is, as it says itself.
ready=""
for _ in $(seq 1 30); do
	ready="$(journalctl -u "$UNIT" --since "$since" -o cat --no-pager 2>/dev/null \
		| grep -E '^\[server\] (READY|to join|could not listen)' || true)"
	if grep -q '^\[server\] READY' <<<"$ready"; then
		break
	fi
	sleep 1
done
echo
if grep -q '^\[server\] READY' <<<"$ready"; then
	printf '%s\n' "$ready"
else
	printf '%s\n' "$ready"
	say "the server has not said READY yet; its log: journalctl -u $UNIT -e"
fi
cat <<EOF

The address and the code again, any time:
  journalctl -u $UNIT -o cat | grep -E '^\[server\] (READY|listening|to join)' | tail -2
Everything it says, as it says it:
  journalctl -u $UNIT -f

It listens on UDP $PORT, for your home network only. Do not forward that port on
your router: internet play is not built yet (docs/server.md).
EOF
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
	echo
	echo "ufw is active here. Let the LAN in, and only the LAN, with something like:"
	echo "  sudo ufw allow from 192.0.2.0/24 to any port $PORT proto udp"
	echo "(192.0.2.0/24 is a placeholder: use your own network's range.)"
fi
