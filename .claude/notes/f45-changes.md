# Fedora 45 — every change triaged for fedokawaii (T46b; decisions by main, 1 Nov 2026 19:10–19:40)

Facts and links: `f45-changes-raw.md` (the research agent's digest, 1 Nov 18:22: the ChangeSet
oldid=787860, 46 accepted changes, the F45 repos queried that day). This file adds only what each
means HERE and the decision: **adopt** (use it) · **adapt** (we must change something) · **verify**
(nothing to change as far as the code shows; proven in the F45 VM / on the PC after its upgrade) ·
**none** (does not touch us). Checks of our own code are named with the command that showed them.

## Python first (the owner named it)

| What | Here | Decision |
|---|---|---|
| python3 3.14.8 → **3.15.0** (Changes/Python3.15) | 52 Python programs of ours (`git ls-files '*.py'` + python shebangs, list in /dev/shm/r27p/py-files.txt): bin/kawa-panel, bin/kawa-downloads, system/kawa-greet, system/fedokawaii-latency, system/prowlarr-indexers.py, tools/*.py, docs/build/*.py, tests/*.py | **verify — done for the code, open for the run:** every one COMPILES under CPython 3.15.0rc3 with `-W error` (no SyntaxWarning, 0 of 52 failed); every stdlib module they import (67 names) loads under 3.15 with `-W error` (no DeprecationWarning); none uses an API 3.15 removed or deprecated (grep of What's New 3.15's lists: sre_*, glob0/1, load_module, is_reserved, java_ver, co_lnotab, wave marks, ByteString, utcnow, codecs.open, CGI handler, asyncio policies, logging.warn, commonprefix, FileType, `__version__`: none). The third-party imports (gi, cairo, PIL, numpy, scipy, fontTools, yaml, pikepdf, dbus_next, markdown) come from F45's own rebuilt RPMs; the F45 smoke (r27-50) already ran the greeter, the panel and the checks on 3.15.0. OPEN (T46's re-run after 3 Nov): run the desktop's Python with `PYTHONWARNINGS=error::DeprecationWarning` in vm-smoke f45 (the panel's menus, kawa-greet, kawa-downloads, the build tools) — a warning is a red. |
| PEP 686: UTF-8 is the default encoding | our open() calls name encoding="utf-8" where it matters (3.14 needs it) | **none** — keep them while the PC is on 44 |
| PEP 810 explicit lazy imports (`lazy import`) | could shave start-up of kawa-panel / kawa-greet | **none now** — syntax 3.14 cannot parse; the toolkit runs on 44 until the PC moves. Re-weigh after the PC's upgrade (measure the panel's start first: T60) |
| Setuptools 82+ (pkg_resources removed) | `grep -rln pkg_resources --include=*.py`: none | **none** |
| torrra's CPython (uv, 3.13) | setup.sh torrra_up pins `uv python install 3.13`: libtorrent's PyPI wheels stop at cp313 (pypi.org/pypi/libtorrent/json, 1 Nov: 2.1.1, cp39–cp313) | **adapt in T29:** Fedora ships `rb_libtorrent-python3` 2.0.11 built for the system Python (F44 2.0.11-5.fc44 for 3.14; F45 2.0.11-9.fc45) — torrra in a venv on Fedora's python3 with `--system-site-packages` would drop uv's second CPython (a whole interpreter, ~100 MB, its own update path). Measure in T29 (torrra's own probe, start time, a download); keep 3.13 until that is green |
| s_dev: uv's newest CPython for his learning (python3.14 in ~/.local/bin) | `uv python install` takes uv's newest; Fedora's uv 0.12.24 lists 3.15.0rc3, not the final | **verify** — after the upgrade uv 0.13.5 (F45) lists 3.15 final; s_dev's next run moves him on. Note for T42: ~/.local/bin/python3.13 and python3.14 links exist (uv's; 3.13 is torrra's) |
| Pandas 3, python-dateutil deprecated | not used (grep) | **none** |

## The 46 accepted changes

### Toolchain and languages
| Change | Here | Decision |
|---|---|---|
| GNU toolchain: gcc 16.2, binutils 2.47, **glibc 2.44**, gdb 17.2 | dwl, the private wlroots 0.20, kawa-saver, kawa-lockmod, the C helpers are built on the PC | **verify** — after the move the after-dnf guard rebuilds dwl (its private wlroots against F45's libs); the F45 smoke built all of them from scratch on F45 (r27-50: dwl + wlroots, the lock module, the saver) |
| LLVM 23 (soname change) | not installed; Mesa links it | **none** directly — see "RPM Fusion's Mesa skew" below |
| Go 1.27, Perl 5.44, Lua 5.5, Erlang 27, Rails 8.1, Lazarus, CMake variables, Protobuf | none of ours (no `go build`, no perl/lua scripts; nvim uses LuaJIT, yazi its own Lua) | **none** |

### Base system
| Change | Here | Decision |
|---|---|---|
| RPM 6.1 (keystore lock: queries work during a transaction) | the menus' `rpm -q` while an update runs | **none** — a gain for free |
| **Enforcing signature checking by default** (%_pkgverify_level all) | (1) setup installs RPM Fusion's release RPMs from files: checked first (rpmfusion_signed) and with localpkg_gpgcheck=1 — already needs the key; (2) **tools/vm-inject's broken packages for T49** are built unsigned | **adapt (T49):** the injected packages must be signed with a throw-away key imported in the VM (or installed with dnf5's per-package override) — an unsigned one is refused on 45; (1) **verify** in the F45 smoke's phase 1 (it passed RPM Fusion's step on 45 already: r27-50) |
| Restrict ptrace by default (Yama 1) | we read /proc/PID/environ (session env for grim/tests), never attach; no strace/gdb in bin/ or tools/ (grep) | **none** — environ reads are not ptrace attaches (Yama checks PTRACE_MODE_ATTACH only); verify in the F45 VM that `tools/` shots still get the session env |
| **kmscon as the VT console** | greetd on tty1; setup's resume prints on tty1 (fedokawaii-resume), update-resume before the login screen; fedokawaii-report already checks `kmsconvt@tty1` is not active (BOOT-21) | **verify (T46):** the F45 smoke booted to the desktop (r27-50) — re-check after the release: no kmscon on tty1, greetd owns it; setup's resume text readable on tty1 (fbcon there). **adopt (T56):** the ISO's question and progress screens may run in kmscon with our face and palette (its own font and colour options) — decided in T55's research |
| OpenSSL 4.0 (libssl.so.4; openssl3-libs compat) | `readelf -d` of every non-RPM binary of ours (/usr/local/{bin,sbin}, ~/.local/bin, the private wlroots): NONE links libssl/libcrypto directly (satty only through RPM libraries, which F45 rebuilt) | **none** |
| Crypto userspace API restricted | no AF_ALG users | **none** |
| PAM in chpasswd/newusers | setup never sets a password (the owner types his own; the ISO's T56 user creation is Kickstart's) | **verify (T56)**: the ISO's user step on 45 |
| Authselect NIS profile removed | not used | **none** |
| NetworkManager IPv6-mostly (CLAT) | transparent | **none**; T39's IPv6 parity rules keep 192.0.0.0/29 (CLAT) working — **verify** in T39 |
| grub-cc (confidential computing) | not used | **none** |
| DRM panic QR frontend | a panic shows Fedora's QR page | **none** (T01b's pstore/journal evidence unchanged) |
| xmlsec 1.3, Stratis in Anaconda | not used (Btrfs is ours) | **none** |

### Graphics and desktop
| Change | Here | Decision |
|---|---|---|
| **Fontconfig 2.18** (local fonts may match differently; check `fc-scan -f "%{genericfamily}"`) | our faces in system/fonts + 60-fedokawaii-pixel.conf aliases | **verify (T46):** in the F45 VM, `fc-match` for every family the desktop names (UI face, Sumi Term → UDEV Gothic NF, the icon font) returns our file, and each face's genericfamily is set; a mismatch → a rule in 60-fedokawaii-pixel.conf |
| IBus 1.5.35 | not installed (no input method) | **none** |
| oo7 replaces GNOME Keyring as the default secret service | a Workstation/KDE comps default; our manifest names what we install, and gnome-keyring 51.1 stays packaged in 45 | **none now** — two F45 blockers were oo7's (ssh passphrase, Online Accounts); revisit only if gnome-keyring is retired |

### Packaging
| Change | Here | Decision |
|---|---|---|
| **Repo configs to /usr/share/dnf5/repos.d** (Fedora's; a modified /etc copy overrides the /usr one entirely) | we never edit Fedora's .repo files (setopt goes to /etc/dnf/repos.override.d); our brave-browser and claude-code .repo files stay in /etc/yum.repos.d (verify.sh:193 reads only those two) | **verify (T46):** after the PC's upgrade no /etc/yum.repos.d/fedora*.repo left behind (an .rpmsave/.rpmnew or a stale copy would shadow the new one) — a verify row "Fedora's repository files come from the system (/usr), none shadowed in /etc" for 45+ |
| Versioned libgit2, NodeJS metapackages, MySQL 9.7, MariaDB 12.3, ODBC, LibreOffice HTML help + dictionaries, Sequoia %openpgpverify | nodejs24-npm-bin is ours (its version string changed: 11.16.0-1.24.18.0.4.fc45 — same Node 24); LibreOffice's apps are ours (26.8) | **none** (the manifest's names all resolve in 45: 189/189, raw §5.6) |

### Other
| Change | Here | Decision |
|---|---|---|
| **Podman 6** (slirp4netns, cgroups v1, BoltDB gone) | Prowlarr's quadlet: no Network= (netavark), `podman info` here: sqlite · netavark · cgroups v2 | **none** — all three already what 6 keeps; **verify** Prowlarr up after the upgrade (verify has its row) |
| encapsule, image-builder ISOs, Anaconda WebUI for Atomic, remote WebUI install, Ignition+Butane, Flatpak filtering | not ours (T55 studies Fedora's media tooling: image-builder is now how Atomic ISOs are built — weigh it beside mkksiso/lorax) | **none** here; **T55** reads image-builder's docs |

## Version jumps outside the ChangeSet that touch us
| Package | 44 → 45 | Decision |
|---|---|---|
| **systemd 259.10 → 262.1** | NEWS 260–262: SysV/rc-local gone (we have none: grep); nspawn `--user=` → `--uid=` (our nspawn calls pass no --user: grep); `journalctl -F` with filters refused (we never use -F: grep); Type=notify-reload rule (none of our units); StartLimitIntervalSec on CLOCK_BOOTTIME; logind Can*() new answers (we call none: grep) | **verify (T46)**; and r27-49-pid1 (259.10's PID 1 crash on a reload during its own upgrade) gets re-tried on 262 in the VM when T46 runs: the storm proof on F45 |
| **plymouth 24.004 → 26.134** | our splash is a script-plugin theme (Window/Image/Sprite/Plymouth calls only) | **verify (T46):** the F45 smoke installed it into every boot image — LOOK at it: QEMU screendump of the F45 VM's boot and shutdown (both moods), against the F44 frames |
| foot 1.27 → 1.28, gtk4 4.22 → 4.24, glib2 2.88 → 2.90, libinput 1.31 → 1.32, dconf 0.49 → 51.0, NetworkManager 1.58, firewalld 2.5, selinux-policy 45 | each in use | **verify (T46/T58):** foot's 1.28 changelog read in T58 (new options worth taking); firewalld 2.5 against T39's rules; the rest by vm-smoke f45 + verify |
| **RPM Fusion's Mesa skew** (freeworld 26.2.6 needs mesa 26.2.6; F45 stable has 26.2.5, updates-testing 26.2.6) | mesa-va-drivers-freeworld is ours | **none to build** — rf_pair already takes Fedora's matching mesa from updates-testing (that package only); on release day re-check; the upgrade's own "RPM Fusion out of step" path holds the move until it agrees (T46) |
| libheif-freeworld 1.23.5 (45) < 1.23.6 (44) | ours | **verify (T46):** the upgrade must not downgrade-fail on it (dnf system-upgrade with --allowerasing is not ours to use: the pre-flight names it) |
| kernel 7.2.13 (same upstream, -300.fc45) | the trial and probation | **none** |
| wlroots 0.20.2 in both | dwl uses our private 0.20 build | **none** |

## What gets built (each with its task and test)
1. T49: the VM's injected broken packages signed (or installed with dnf5's per-package override) — red on F45 otherwise. Accept: the bisect proof on F45.
2. T46 re-run of vm-smoke f45 after 3 Nov with: `PYTHONWARNINGS=error::DeprecationWarning` for the desktop's Python; `fc-match` of our families; the splash's frames (screendump); no kmscon on tty1; Prowlarr up; no shadowed Fedora .repo in /etc. Accept: all green, frames looked at.
3. verify.sh (45+): Fedora's repository files from /usr, none shadowed in /etc (after the PC's move). Accept: a test_verify row each way.
4. T29: torrra on Fedora's python3 + rb_libtorrent-python3, measured against uv's 3.13; adopt if green (drops a CPython).
5. T55/T56: kmscon for the ISO's text screens (themed) and image-builder weighed beside mkksiso.
