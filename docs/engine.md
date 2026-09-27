# The engine

Which Godot builds every Biogenic binary, how CI holds it to that, what TLS
library it carries, and what an engine upgrade has to repeat. Issues #78 and
#79.

## 1. What builds a release

| | |
|---|---|
| Engine | Godot **4.7.2-stable**, official build `ed1daf0bf` |
| Pinned in | `GODOT_VERSION` in `.github/workflows/ci.yml`, `release.yml` and `sync-launcher.yml` |
| Installed by | `ci/install_godot.sh`, from the launcher template (it checks nothing: #74) |
| Held to | `.github/engine/godot-4.7.2-stable.sha512`: the editor and all 35 files of the export templates, SHA-512 each |
| Reported by | the server's status line, `Godot 4.7.2-stable (official)`, and `--version`, `4.7.2.stable.official.ed1daf0bf`, which the updater's pre-flight reads |
| `binary_version` | 4 |

**The manifest is checked on every run, not only on a download.** CI caches
`~/godot` and the export templates under a key made of the version, and a cache
hit skips `install_godot.sh`'s download entirely. So the "Verify the engine"
step runs `sha512sum --check --strict` over the files as they stand: a fresh
install and a cache hit are held to the same bytes, and a manifest missing for
the pinned version fails the job. The manifest's own provenance is Godot's
release: each archive was checked against that release's `SHA512-SUMS.txt`
before a file was taken out of it (§4 has the commands).

**Editor settings are named for the series.** 4.7.2 reads
`editor_settings-4.7.tres`, measured; a file named for the patch release is
never read, and the Android export -- which takes the SDK path from editor
settings alone -- fails. The workflows name it with `cut -d. -f1,2`.

## 2. The TLS library inside it

Godot carries its own mbedTLS, compiled into the engine: the exported server
links no TLS library (`ldd`), so the version below is the one that answers on
UDP 45772.

| Engine | mbedTLS | Upstream commit | Source |
|---|---|---|---|
| 4.7-stable | 3.6.5 | `e185d7fd85499c8ce5ca2a54f5cf8fe7dbe3f8df` | `thirdparty/README.md` at the `4.7-stable` tag |
| 4.7.1-stable | 3.6.7 | `068ff080b369adfac81509f9b57b2afabaf82dc5` | the same file at `4.7.1-stable` |
| **4.7.2-stable** | **3.6.7** | `068ff080b369adfac81509f9b57b2afabaf82dc5` | the same file at `4.7.2-stable` |

**Build options** (`thirdparty/mbedtls/include/godot_module_mbedtls_config.h`
at the tag): upstream's default configuration, with the DHE-PSK and DHE-RSA key
exchanges, DES and finite-field Diffie-Hellman taken out; Godot's own entropy
source (`MBEDTLS_NO_PLATFORM_ENTROPY`, `MBEDTLS_ENTROPY_HARDWARE_ALT`) and
threading (`MBEDTLS_THREADING_ALT`); deprecated interfaces removed.
Renegotiation is compiled in, as upstream's default has it -- and refused at
runtime by both roles, measured in §3.

**What uses it here:**
- DTLS 1.2 over ENet on the internet listener (server) and in a phone's call by
  invite (client). The suite negotiated with OpenSSL 3.0 on the wire was
  `ECDHE-RSA-CHACHA20-POLY1305`.
- X.509: the pond's self-signed RSA-2048 certificate, made by the server and
  pinned by the invite (`Invite.certificate_of`).
- RSA key generation and signing, for that certificate.
- The HTTPS client that fetches releases (the launcher's updater, and the
  server's).

## 3. Advisories

**Checked on 2026-09-27** against every advisory on Mbed TLS's list from
October 2025 on: 33, each page read for its affected and fixed versions, and
cross-checked with the ChangeLogs of 3.6.5, 3.6.6 and 3.6.7. There is no 3.6.8
yet: 3.6.7, of 7 July 2026, is the newest release on the 3.6 branch.

- **3.6.5, in 4.7-stable, is affected by 30 of the 33.** 4.7-stable predates
  the March fixes (3.6.6) and the July ones (3.6.7).
- **3.6.7, in 4.7.2, is at or past the fix for 31.** Of the other two,
  CVE-2026-54434 never touched the 3.6 branch, and CVE-2025-66442 has no fix
  anywhere: it is a build matter, and the advisory says builds with
  `MBEDTLS_HAVE_ASM` on Arm and x86 -- Godot's -- are not affected.
- **None is reachable here for more than a low-severity effect.** The table
  says why for each: most need a feature Godot does not compile or this game
  does not use -- a TLS 1.3 server, PSK, EC J-PAKE, PKCS#7, session
  serialisation, DTLS-SRTP, finite-field DH.

| Date | CVE | What | Fixed in 3.6 | On this build's paths |
|---|---|---|---|---|
| 2025-10 | 2025-59438 | Padding oracle through cipher error timing | 3.6.5 | no: CBC padding; the link runs an AEAD suite |
| 2025-10 | 2025-54764 | RSA key generation side channel | 3.6.5 | key generation, already fixed in 3.6.5 |
| 2026-03 | 2026-34876 | CCM multipart tag-length check | 3.6.6 | no: only direct callers of `mbedtls_ccm_finish` |
| 2026-03 | 2026-34873 | TLS 1.3 client impersonation on resumption | 3.6.6 | no: needs a TLS 1.3 server |
| 2026-03 | 2025-66442 | Compiler-induced constant-time violations | none | no: builds with `MBEDTLS_HAVE_ASM` are not affected |
| 2026-03 | 2026-34871 | Linux entropy falls back to `/dev/urandom` | 3.6.6 | no: compiled out -- Godot supplies its own entropy |
| 2026-03 | 2026-34875 | FFDH public key export overflow | 3.6.6 | no: FFDH is not used, DHE is off |
| 2026-03 | 2026-34872 | FFDH peer key checks | 3.6.6 | no: FFDH is not used |
| 2026-03 | 2026-25833 | `x509_inet_pton_ipv6` underflow | 3.6.6 | no: only builds without `AF_INET6` |
| 2026-03 | 2026-34874 | Null dereference setting a distinguished name | 3.6.6 | certificate generation, and only when memory runs out |
| 2026-03 | 2026-25835 | PSA random generator cloning | 3.6.6 | no: the process is never forked or cloned |
| 2026-03 | 2026-34877 | Serialised session data | 3.6.6 (documentation) | no: sessions are never serialised |
| 2026-03 | 2026-25834 | Signature algorithm injection | 3.6.6 | the DTLS and HTTPS clients: a policy bypass, low |
| 2026-07 | 2026-50584 | ChaCha20 counter overflow | 3.6.7 | no: (D)TLS records cannot reach the limit |
| 2026-07 | 2026-54435 | ECC optimised modp side channel | 3.6.7 | ECDHE runs it; needs a long-term scalar reused, local |
| 2026-07 | 2026-54434 | Everest input validation | never on 3.6 | no |
| 2026-07 | 2026-50581 | Extended master secret failure ignored | 3.6.7 | DTLS and TLS 1.2; only on a local hash or memory failure |
| 2026-07 | 2026-50713 | Heap corruption, early DTLS renegotiation | 3.6.7 | no: renegotiation is refused, measured below |
| 2026-07 | 2026-50640 | TLS 1.3 resumption secret error ignored | 3.6.7 | no: needs a TLS 1.3 server |
| 2026-07 | -- | PKCS#7 accepts weak hashes | 3.6.7 | no: PKCS#7 is never used |
| 2026-07 | 2026-35336 | `mbedtls_ecdh_calc_secret` overflow | 3.6.7 | no: only direct callers; TLS is unaffected |
| 2026-07 | 2026-73064 | RNG fault breaks TLS data integrity | 3.6.7 | no: needs a TLS 1.3 server with tickets |
| 2026-07 | 2026-50587 | RSA PKCS#1 v1.5 decryption timing | 3.6.7 | no: only through PSA, which Godot leaves off |
| 2026-07 | 2026-54441 | Signature restrictions on the chain | 3.6.7 (documentation) | no: no restriction is configured |
| 2026-07 | 2026-50585 | Incomplete session reset | 3.6.7 | no: the part left needs DTLS-SRTP, off |
| 2026-07 | 2026-50580 | TLS 1.2 ECDHE-PSK client overflow | 3.6.7 | no: no PSK |
| 2026-07 | 2026-50588 | EC J-PAKE ServerKeyExchange read | 3.6.7 | no: EC J-PAKE is off |
| 2026-07 | 2026-50586 | TLS 1.2 NewSessionTicket disclosure | 3.6.7 | no: no ticket callback |
| 2026-07 | 2026-73096 | TLS 1.3 early data integrity | 3.6.7 | no: early data is off |
| 2026-07 | 2026-25832 | TLS 1.3 client accepts an unadvertised group | 3.6.7 | the HTTPS client on TLS 1.3: low |
| 2026-07 | 2026-50579 | PKCS#7 use-after-free | 3.6.7 | no: PKCS#7 is never used |
| 2026-07 | 2026-49300 | X.509 CA bit forgery | 3.6.7 | needs a malformed certificate trusted as a root |
| 2026-07 | 2026-50583 | Zero-length ECC public key read | 3.6.7 | no: only driver-only ECC builds |

**Entropy.** 3.6.6 made mbedTLS's own Linux fallback read `/dev/random`,
which can block on kernels before 5.6 -- older phones. It does not reach this
build: Godot compiles mbedTLS's platform entropy out
(`MBEDTLS_NO_PLATFORM_ENTROPY`) and feeds it from `OS::get_entropy`, which
reads `getentropy()`, else `/dev/urandom` (`core/crypto/crypto_core.cpp`,
`drivers/unix/os_unix.cpp`).

**CVE-2026-50713** (heap corruption with early renegotiation after a corrupted
DTLS record), measured, not assumed, on the exported 4.7.2 server and on the
4.7.2 client, in a private network namespace:
- **Server:** OpenSSL's DTLS client completes the handshake with the internet
  listener, then asks to renegotiate. The server answers `no_renegotiation`,
  five times as the client resends, and stays up; it stops cleanly afterwards.
- **Client** (what a phone runs when it calls an invite): after the handshake,
  `openssl s_server` sends a HelloRequest, and Godot's DTLS client answers
  `no_renegotiation`.
- **Control:** `openssl s_server -client_renegotiation` accepts the same
  client's request -- a second ServerHello, no alert -- so the probe tells
  refusal from acceptance.

So the advisory's precondition does not hold in either role, and the library is
past its fix besides. The same probe on 4.7-stable, in September, gave the same
refusals (#79).

## 4. What an upgrade repeats

In order; each step's result goes into this document before the pull request
is opened. The upgrade is a binary release: players take an install, and a
server replaces its executable (`docs/server.md` §4).

1. **Fetch and check the release.** From
   `https://github.com/godotengine/godot/releases/download/<V>-stable/`:
   `Godot_v<V>-stable_linux.x86_64.zip`, `Godot_v<V>-stable_export_templates.tpz`
   and `SHA512-SUMS.txt`. Check both archives with
   `grep ' <archive>$' SHA512-SUMS.txt | sha512sum -c -`.
2. **Write the manifest**, from a scratch home laid out as `install_godot.sh`
   lays it: `godot/godot` and
   `.local/share/godot/export_templates/<V>.stable/*`. From that home:
   `{ sha512sum godot/godot; find .local/share/godot/export_templates/<V>.stable -type f | LC_ALL=C sort | xargs sha512sum; } > .github/engine/godot-<V>-stable.sha512`,
   then check it with `sha512sum --check --strict`.
3. **Pin it**: `GODOT_VERSION` in the three workflows, `binary_version` in
   `version.json`, the install lines in `CLAUDE.md`.
4. **Inventory mbedTLS**: the `## mbedtls` section of `thirdparty/README.md` at
   the tag, and the config header above. Check every advisory at
   `https://mbed-tls.readthedocs.io/en/latest/security-advisories/` against that
   version, and update §2 and §3.
5. **Probe renegotiation** on the exported server and on the client, with the
   control, as §3 describes.
6. **Run everything under the new engine**: a clean import leaves the tree
   clean; `tools/net_probe.tscn` and `tools/net_fuzz.tscn`; CI's scene boots.
7. **Compare with the old engine**: `tools/drive.tscn -- --seed=<n>
   --fingerprint=1800` headless at `--fixed-fps 60` prints the same hash on
   both if the simulation did not move by a bit; frames from `tools/shot.tscn`
   with `--seed=` and `--fixed-fps 60` -- proven to repeat first, three renders
   and 0 differing pixels (`docs/design/perception.md` §4.1) -- at 1280x720 and
   2400x1080.
8. **Old binary, new content**: a device that declines the install keeps the
   old engine and may take the new content pack. Stage the new pack as the
   launcher does (`user://update_state.json` naming it, newer than the
   binary's own), boot the old server binary on it, and boot every game scene
   on the old engine from the new Android pack.

## 5. Measured for 4.7.2

Against 4.7-stable, in this container:

| Check | Result |
|---|---|
| A clean import | no error, no warning, no tracked file changed |
| `net_probe`, full | 343 checks, ALL PASS, 164.6 s, 14,470 frames |
| `net_fuzz`, seed 1 | ALL PASS, 101 saved cases |
| Engine error lines in the full probe | 96, where 4.7 prints 153: the 57 missing are 4.7's `godot_mbedtls_mutex_free` lines, three per DTLS listener closed (`net-hardening.md` C.1). The fuzzer closed 120 listeners under 4.7.2 and counted none -- an engine bug 4.7.2 fixed. Every other line is the same kind and count on both |
| CI's seven scene boots | exit 0, no error line, each |
| Simulation fingerprint, seeds 7 and 1009, 1,800 frames | the same SHA-256 on both engines |
| Frames: launcher, mode select, play, full vision and earshot, at 1280x720 and 2400x1080 | 10 of 10 identical to the pixel. The play frame was first shown to repeat: three renders on each engine, 0 differing pixels |
| Renegotiation | refused by the server and by the client; the control accepts |
| The 4.7 server binary on the 4.7.2 content pack, staged as the launcher stages it | mounted, READY, stopped cleanly, no script error |
| The 4.7 engine on the 4.7.2 Android pack: the launcher and five game scenes | exit 0, no error line, each |

**Not measured here:** the Android and Windows exports on a device, which is
the owner's playtest; and the export itself on CI's runner, which the pull
request's own checks do.
