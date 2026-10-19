#!/usr/bin/env bash
# tests/installer/test_manifest.sh — lib/manifest.sh, the single source of truth: no package
# both wanted and forbidden, none listed twice, the base tools a Minimal Install lacks listed
# (tar, grubby, diffutils, man-db — and what the scripts call: python3, glib2, fontconfig),
# retired ones out of the lists, systemd-oomd's rules kept out, Steam's only with STEAM=yes,
# the GPU's by GPU, what upstream and the hardware recorded counted in, the user units verify
# checks. Pure: no fake machine.
FK_PURE=1 . "$(dirname "$0")/lib.sh"
sandbox
m() { ( STATE_DIR=$TMP/state; STEAM=${STEAM:-yes}; . "$REPO/lib/manifest.sh"; eval "$1" ); }
all() { m "manifest_all ${1:-amd}"; }

case_ "every list parses; the manifest for AMD and for Intel"
a=$(all amd); i=$(all intel)
((${#a} > 0 && ${#i} > 0)) && _ok || _no "empty manifest"
has "$a" lact; lacks "$i" lact; has "$i" intel-media-driver
has "$a" mesa-vulkan-drivers; has "$i" mesa-vulkan-drivers; lacks "$a" mesa-vulkan-drivers-freeworld   # Vulkan: Fedora's own
has "$a" rocm-smi; lacks "$i" rocm-smi                      # btop's view of an AMD card
for p in visidata gdu; do has "$a" "$p"; has "$i" "$p"; done   # the terminal's tables and disk usage

case_ "office is LibreOffice — Writer, Calc, Impress, drawn by GTK 3, English and Arabic spelling — and nothing more of it"
for p in libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-gtk3 hunspell-en hunspell-ar; do
  grep -qx "$p" <<<"$a" || _no "$p not in the manifest"
done; _ok
eq "$(grep -E '^libreoffice' <<<"$a" | sort | tr '\n' ' ')" "libreoffice-calc libreoffice-gtk3 libreoffice-impress libreoffice-writer " "no other part of the suite"
case_ "AbiWord, Gnumeric and sc-im: forbidden (update removes them) and handed back to dnf"
f=$(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}"'); r=$(m 'printf "%s\n" "${RETIRED_PKGS[@]}"')
for p in abiword gnumeric sc-im; do grep -qx "$p" <<<"$f" && grep -qx "$p" <<<"$r" && _ok || _no "$p not forbidden and retired"; done
case_ "Spotify is its web player: lpf, its recipe and the app it built are retired (handed back to dnf), none in the manifest"
for p in lpf lpf-spotify-client spotify-client; do grep -qx "$p" <<<"$r" && _ok || _no "$p not retired"; grep -qx "$p" <<<"$a" && _no "$p in the manifest" || _ok; done
eq "$(m 'echo "${LPF_BUILT[*]:-}${PKG_SPOTIFY[*]:-}"')" "" "no Spotify package lists left"

case_ "no package listed twice"
eq "$(all amd | sort | uniq -d)" "" "twice in the AMD manifest"
eq "$(all intel | sort | uniq -d)" "" "twice in the Intel manifest"

case_ "nothing both wanted and forbidden (AMD's forbidden too); nothing removed that is wanted"
eq "$(comm -12 <(all amd | sort -u) <(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}" "${FORBIDDEN_amd[@]}"' | sort -u))" ""
eq "$(comm -12 <(all intel | sort -u) <(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}"' | sort -u))" ""
eq "$(comm -12 <(all amd | sort -u) <(m 'printf "%s\n" "${PKG_REMOVE[@]}"' | sort -u))" ""
case_ "forbidden by the names Fedora's packages have, not by their commands (rpm -q knows only those)"
f=$(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}"')
has "$f" SwayNotificationCenter; grep -qx swaync <<<"$f" && _no "swaync is a command: its package is SwayNotificationCenter" || _ok
case_ "lazygit from its own release, pinned like yazi (its COPR is no longer kept): no package, no COPR"
lacks "$(all amd)" lazygit; eq "$(m 'echo "${COPRS[*]}"')" "ilyaz/LACT"
has "$(m 'printf "%s\n" "${RETIRED_PKGS[@]}"')" lazygit
u=$( . "$REPO/lib/upstream.sh"; printf '%s\n' "${UPSTREAM[@]}" )
grep -qE '^lazygit\|jesseduffield/lazygit\|v[0-9.]+\|lazygit_[0-9.]+_linux_x86_64\.tar\.gz\|[0-9a-f]{64}\|lazygit$' <<<"$u" && _ok || _no "lazygit not pinned in lib/upstream.sh"
case_ "every package setup removes is also forbidden afterwards (verify keeps it out)"
eq "$(comm -23 <(m 'printf "%s\n" "${PKG_REMOVE[@]}"' | sort -u) <(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}"' | sort -u))" ""
case_ "systemd-oomd's rules (systemd-oomd-defaults): removed in phase 1 and forbidden after — its kill takes a whole cgroup, the session"
grep -qx systemd-oomd-defaults <<<"$(m 'printf "%s\n" "${PKG_REMOVE[@]}"')" && _ok || _no "not in PKG_REMOVE"
grep -qx systemd-oomd-defaults <<<"$(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}"')" && _ok || _no "not in FORBIDDEN_PKGS"
case_ "retired packages are out of every list"
eq "$(comm -12 <(all amd | sort -u) <(m 'printf "%s\n" "${RETIRED_PKGS[@]}"' | sort -u))" ""

case_ "the base tools a Minimal Install lacks, and the programs the scripts call, are listed (never assumed)"
b=$(m 'printf "%s\n" "${PKG_BASE[@]}"')
for p in tar grubby diffutils man-db python3 git jq gnupg2 dnf5-plugins pciutils; do grep -qx "$p" <<<"$b" || _no "$p not in PKG_BASE"; done; _ok
for p in glib2 fontconfig udisks2 dconf; do grep -qx "$p" <<<"$a" || _no "$p not in the manifest"; done; _ok

case_ "Syncplay's own needs are listed (Fedora's Twisted with TLS, pyOpenSSL, certifi, pem) — not Fedora's syncplay, which brings PySide6 and Qt"
for p in python3-twisted python3-twisted+tls python3-pyOpenSSL python3-certifi python3-pem; do grep -qxF "$p" <<<"$a" || _no "$p not in the manifest"; done; _ok
lacks "$(all amd)" $'\nsyncplay\n'; lacks "$(all amd)" pyside

case_ "STEAM=no: Steam's packages out; yes: in"
STEAM=no; has "$(all amd)" mpv; lacks "$(all amd)" steam; lacks "$(all amd)" ntsync-autoload
STEAM=yes; has "$(all amd)" steam; has "$(all amd)" ntsync-autoload
case_ "a game controller: Steam's rules for it (steam-devices) listed with Steam, never assumed to come along"
grep -qx steam-devices <<<"$(all amd)" && _ok || _no "steam-devices not in the manifest"
STEAM=no; grep -qx steam-devices <<<"$(all amd)" && _no "steam-devices without Steam" || _ok; STEAM=yes

case_ "what lib/upstream.sh and lib/hardware.sh recorded belongs to the manifest"
mkdir -p "$TMP/state"; echo openssl3-libs >"$TMP/state/upstream-libs"; printf '%s\n' iwlwifi-mvm-firmware amd-ucode-firmware >"$TMP/state/hardware-pkgs"
a=$(all amd); has "$a" openssl3-libs; has "$a" iwlwifi-mvm-firmware
case_ "an unknown GPU name gives the common list only (never an error)"
x=$(all nvidia); has "$x" mesa-dri-drivers; lacks "$x" lact; lacks "$x" intel-media-driver

case_ "services: the ones verify checks exist in the lists; Fedora's user presets named"
eq "$(m 'printf "%s\n" "${SVC_USER_GLOBAL[@]}"' | tr '\n' ' ')" "pipewire.socket pipewire-pulse.socket wireplumber.service "
has "$(m 'printf "%s\n" "${SVC_SYSTEM[@]}"')" greetd.service; has "$(m 'echo "${SVC_SYSTEM_amd[*]}"')" lactd.service
case_ "every name is a plain package name (no stray spaces, no comment glued on)"
bad=$(all amd | grep -vE '^[A-Za-z0-9][A-Za-z0-9._+-]*$' || true); eq "$bad" ""
case_ "the vendor repositories: HTTPS, and the Claude key's fingerprint is 40 hex digits"
has "$(m 'echo $BRAVE_REPO_URL $CLAUDE_REPO_BASEURL $CLAUDE_KEY_URL')" "https://"
[[ $(m 'echo $CLAUDE_KEY_FPR') =~ ^[0-9A-F]{40}$ ]] && _ok || _no "fingerprint"
lacks "$(m 'echo $BRAVE_REPO_URL $CLAUDE_REPO_BASEURL $CLAUDE_KEY_URL')" "http:"

done_
