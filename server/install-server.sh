#!/usr/bin/env bash
# Installs, repairs or updates Biogenic's dedicated server on Debian or Ubuntu
# -- written for a Proxmox LXC with no desktop -- as a systemd service.
#
#   curl -fsSLO https://github.com/sinikebe/biogenic/releases/latest/download/install-server.sh
#   less install-server.sh          # it is short: read it before you run it
#   sudo bash install-server.sh             # install, or update what the server cannot
#   sudo bash install-server.sh --purge     # the same, from a clean kit (below)
#   sudo bash install-server.sh --dev       # a second server, for dev (below)
#   sudo bash install-server.sh --purge --dev
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
# With --dev, every name above is the dev server's own instead (below).
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
# --dev installs a second server, which follows dev: the pond the dev app
# plays in before a release (docs/server.md, "A dev server"). Its build, unit
# and firewall rules come from dev's rolling prerelease, branch-dev, checked
# against that release's SHA256SUMS the same way, and the unit and the rules
# are then made its own -- derive_dev below. Every name is its own: the account
# biogenic-dev, /var/lib/biogenic-dev, /opt/biogenic-dev, the unit
# biogenic-server-dev.service and its overrides, /run/biogenic-dev, and the
# rules in /etc/biogenic-dev as the table inet biogenic_dev -- and so are its
# ports, UDP 45781 and 45782, since a dev build takes its own pair. It runs
# beside the live server, on the same machine if need be, and neither install
# touches the other: --purge --dev purges the dev kit alone, --purge the live
# one alone. Until a release carries this installer, take it from dev's:
#
#   curl -fsSLO https://github.com/sinikebe/biogenic/releases/download/branch-dev/install-server.sh
#
# BIOGENIC_REPO=owner/name installs from another fork's releases, and
# BIOGENIC_RELEASE_URL, used as it is, from anywhere curl can read one
# release's assets from -- a mirror, or file:///some/dir holding them.
set -euo pipefail

REPO="${BIOGENIC_REPO:-sinikebe/biogenic}"
BINARY="biogenic-server.x86_64"
# The unit's name in a release. The live server installs it as it is; the dev
# server installs one made from it, under its own name.
KIT_UNIT="biogenic-server.service"
NFT_CONF="nftables-internet.conf"

say() { printf '==> %s\n' "$*"; }
die() { printf 'install-server: %s\n' "$*" >&2; exit 1; }

purge=0
dev=0
for arg in "$@"; do
	case "$arg" in
		--purge) purge=1 ;;
		--dev) dev=1 ;;
		*) die "unknown option $arg -- the only ones are --purge and --dev" ;;
	esac
done

# Everything this install owns, by name. The dev server's are the live one's
# with -dev after them -- biogenic_dev for the nft table, whose names take an
# underscore and no hyphen -- so no path, unit, account or table of one is ever
# the other's.
if (( dev )); then
	NAME="biogenic-dev"
	UNIT="biogenic-server-dev.service"
	TABLE="biogenic_dev"
	PORT="45781"
	NET_PORT="45782"
	WHICH="dev"
	COMMENT="Biogenic dev server"
else
	NAME="biogenic"
	UNIT="$KIT_UNIT"
	TABLE="biogenic"
	PORT="45771"
	NET_PORT="45772"
	WHICH="latest"
	COMMENT="Biogenic dedicated server"
fi
PREFIX="/opt/$NAME"
STATE="/var/lib/$NAME"
ACCOUNT="$NAME"
RUN_DIR="/run/$NAME"
NFT_DIR="/etc/$NAME"
UNIT_FILE="/etc/systemd/system/$UNIT"
OVERRIDES="/etc/systemd/system/$UNIT.d"

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

# **The dev kit, made from the release's own unit and rules** ($1 and $2, both
# already checked against SHA256SUMS) into $3 and $4: the dev server's account,
# paths, ports and table in place of the live one's, and nothing else changed.
# The server/ files stay as they are, so the live install of the same release
# finds its own files unchanged. Every substitution is fixed text, anchored to
# a directive, a whole path or a whole port; whatever the release's files say
# that none of them reaches is caught after them, and then nothing is
# installed -- a dev unit left naming a live path would run a second server in
# the live one's files.
derive_dev() {
	local unit="$1" rules="$2" unit_out="$3" rules_out="$4" left
	{
		echo "# The dev server's unit, made by install-server.sh --dev from the release's own"
		echo "# $KIT_UNIT: the dev server's account, paths and ports in place"
		echo "# of the live server's (docs/server.md, \"A dev server\")."
		echo "#"
		sed -E \
			-e 's#^Description=Biogenic dedicated server#Description=Biogenic dev server#' \
			-e 's#^(User|Group|StateDirectory|RuntimeDirectory)=biogenic$#\1=biogenic-dev#' \
			-e 's#^(WorkingDirectory=|Environment=HOME=)/var/lib/biogenic$#\1/var/lib/biogenic-dev#' \
			-e 's#^ExecStart=/opt/biogenic/biogenic-server\.x86_64 #ExecStart=/opt/biogenic-dev/biogenic-server.x86_64 #' \
			-e '/^Exec(Start|Stop)=/ s#/run/biogenic/stop([ ;]|$)#/run/biogenic-dev/stop\1#g' \
			-e '/^[[:space:]]*#/ s#(/opt|/var/lib|/run)/biogenic([^-[:alnum:]_]|$)#\1/biogenic-dev\2#g' \
			-e '/^[[:space:]]*#/ s#\.local/share/godot/app_userdata/Biogenic([^[:alnum:]_]|$)#.local/share/biogenic-dev\1#g' \
			-e '/^[[:space:]]*#/ s#(^|[^0-9])4577([12])([^0-9]|$)#\14578\2\3#g' \
			"$unit"
	} > "$unit_out"
	{
		# Its first line stays first: `#!/usr/sbin/nft -f`.
		if head -n 1 "$rules" | grep -q '^#!'; then head -n 1 "$rules"; fi
		echo "# The dev server's rules, made by install-server.sh --dev from the release's"
		echo "# own $NFT_CONF: its own table, biogenic_dev, on its own ports,"
		echo "# 45781 and 45782. Loaded beside the live server's, each keeps to its own."
		echo "#"
		sed -E \
			-e '1{/^#!/d}' \
			-e 's#^(delete )?table inet biogenic( \{)?$#\1table inet biogenic_dev\2#' \
			-e 's#^([[:space:]]+udp dport )4577([12]) #\14578\2 #' \
			-e "s|^# What the internet may send Biogenic's server|# What the internet may send Biogenic's dev server|" \
			-e '/^[[:space:]]*#/ s#/etc/biogenic/#/etc/biogenic-dev/#g' \
			-e '/^[[:space:]]*#/ s#(^|[^0-9])4577([12])([^0-9]|$)#\14578\2\3#g' \
			"$rules"
	} > "$rules_out"
	# Nothing of the live server's is left: no path, account, user:// or port
	# in the unit, no table, path or port in the rules.
	left="$(grep -nE '(/opt|/var/lib|/run|/etc)/biogenic([^-]|$)|=biogenic$|app_userdata/Biogenic|4577[12]' \
		"$unit_out" || true)"
	[[ -z "$left" ]] || die "the dev unit made from the release's still names the live server's -- installing nothing:"$'\n'"$left"
	left="$(grep -nE 'table inet biogenic([^_]|$)|/etc/biogenic([^-]|$)|4577[12]' "$rules_out" || true)"
	[[ -z "$left" ]] || die "the dev rules made from the release's still name the live server's -- installing nothing:"$'\n'"$left"
	# And everything the dev server needs is there: each directive once, and
	# every rule of the live table's, on the dev ports.
	local want
	for want in '^User=biogenic-dev$' '^Group=biogenic-dev$' '^StateDirectory=biogenic-dev$' \
			'^RuntimeDirectory=biogenic-dev$' '^WorkingDirectory=/var/lib/biogenic-dev$' \
			'^Environment=HOME=/var/lib/biogenic-dev$' '^Description=Biogenic dev server' \
			'^ExecStart=/opt/biogenic-dev/biogenic-server\.x86_64 .*--stop-file=/run/biogenic-dev/stop( |$)' \
			'^ExecStop=.* touch /run/biogenic-dev/stop;'; do
		[[ "$(grep -cE "$want" "$unit_out")" -eq 1 ]] \
			|| die "the dev unit made from the release's has no one line matching $want -- installing nothing"
	done
	[[ "$(grep -cE '^(delete )?table inet biogenic_dev( \{)?$' "$rules_out")" -eq \
		"$(grep -cE '^(delete )?table inet biogenic( \{)?$' "$rules")" ]] \
		&& [[ "$(grep -cE 'udp dport 4578[12] ' "$rules_out")" -eq \
			"$(grep -cE 'udp dport 4577[12] ' "$rules")" ]] \
		&& [[ "$(grep -cE 'udp dport 4578[12] ' "$rules_out")" -gt 0 ]] \
		|| die "the dev rules made from the release's do not hold every rule of the live table's -- installing nothing"
}

[[ ${EUID} -eq 0 ]] || die "run it as root: sudo bash $0"
[[ "$(uname -m)" == "x86_64" ]] || die "the server is built for x86_64, and this is $(uname -m)"
command -v systemctl >/dev/null 2>&1 || die "this needs systemd, and there is no systemctl here"
# systemctl alone proves nothing: a Docker container has it and no systemd.
[[ -d /run/systemd/system ]] \
	|| die "this needs systemd running as the service manager, and it is not running here"
if (( dev )); then
	say "this is the dev server: it follows dev, and hosts the dev app's pond before a release"
	say "it uses UDP $PORT and $NET_PORT, and is separate from the live server: its own account," \
		"files, unit and firewall table, and nothing here touches the live server's"
fi

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
		--shell /usr/sbin/nologin --comment "$COMMENT" "$ACCOUNT"
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
#    The dev server's come from dev's rolling prerelease, one tag refreshed in
#    place on every push to dev: a push published in the middle of an install
#    can hand over a build from one and SHA256SUMS from the other, and then the
#    check refuses both.
if [[ -n "${BIOGENIC_RELEASE_URL:-}" ]]; then
	BASE="$BIOGENIC_RELEASE_URL"
elif (( dev )); then
	BASE="https://github.com/${REPO}/releases/download/branch-dev"
	say "dev's rolling prerelease is branch-dev"
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
say "downloading the $WHICH server from ${BASE}/"
for file in "$BINARY" "$KIT_UNIT" "$NFT_CONF" SHA256SUMS; do
	curl -fsSL --retry 3 -o "$work/$file" "$BASE/$file" \
		|| die "could not download $file from $BASE/ -- is a release with the server published?"
done
awk -v a="$BINARY" -v b="$KIT_UNIT" -v c="$NFT_CONF" '$2 == a || $2 == b || $2 == c' \
	"$work/SHA256SUMS" > "$work/wanted.sums"
[[ "$(wc -l < "$work/wanted.sums")" -eq 3 ]] \
	|| die "SHA256SUMS does not list $BINARY, $KIT_UNIT and $NFT_CONF; installing nothing"
(cd "$work" && sha256sum --check --strict --quiet wanted.sums) \
	|| die "checksum mismatch; installing nothing$( (( dev )) && echo " -- branch-dev is" \
		"refreshed on every push to dev: if one was publishing, run this again in a few minutes")"
say "the build, the unit and the firewall rules match SHA256SUMS"
# The rules this server lays down: the release's own, or the dev server's,
# made from them with its unit -- after the check, so from verified files only.
RULES="$work/$NFT_CONF"
if (( dev )); then
	mkdir "$work/dev"
	derive_dev "$work/$KIT_UNIT" "$work/$NFT_CONF" "$work/$UNIT" "$work/dev/$NFT_CONF"
	RULES="$work/dev/$NFT_CONF"
	say "the dev unit and rules made from them: $UNIT, and the table inet $TABLE for UDP" \
		"$PORT and $NET_PORT"
fi

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
			"serves. Keep --stop-file=$RUN_DIR/stop on that line (docs/server.md §6)"
	fi
fi

# 5b. The firewall rules for both ports, laid down but never loaded: a network
#     firewall is the owner's to review and turn on (docs/server.md §5, §9.6).
#     The file replaces the whole table when it is loaded, so loading this
#     release's copy over an older one never doubles a rule.
install -d -m 0755 "$NFT_DIR"
if cmp -s "$RULES" "$NFT_DIR/$NFT_CONF"; then
	rules="unchanged"
else
	rules="$([[ -e "$NFT_DIR/$NFT_CONF" ]] && echo updated || echo installed)"
	install -o root -g root -m 0644 "$RULES" "$NFT_DIR/$NFT_CONF"
fi
if ! command -v nft >/dev/null 2>&1; then
	say "firewall rules at $NFT_DIR/$NFT_CONF ($rules; nftables is not installed here)" \
		"-- review, then load them with nft, or on the Proxmox host"
elif nft list table inet "$TABLE" >/dev/null 2>&1; then
	if [[ "$rules" != unchanged ]]; then
		say "firewall rules at $NFT_DIR/$NFT_CONF ($rules) -- a $TABLE table is loaded;" \
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
if (( dev )); then
	cat <<EOF

This is the dev server. Only the dev app finds it -- the players' app calls the
live server's ports -- and it takes every push to dev by itself, within ten
minutes, once its pond is empty. Its jobs (--reach, --invite and the rest,
docs/server.md §9.1) run as $ACCOUNT, with its own home and build:
  runuser -u $ACCOUNT -- env HOME=$STATE $PREFIX/$BINARY --headless -- --invites
EOF
fi
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
