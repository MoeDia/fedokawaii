#!/usr/bin/env bash
# tests/installer/test_manifest.sh — lib/manifest.sh, the single source of truth: no package
# both wanted and forbidden, none listed twice, the base tools a Minimal Install lacks listed
# (tar, grubby, diffutils, man-db — and what the scripts call: python3, glib2, fontconfig),
# retired ones out of the lists, Steam's only with STEAM=yes, the GPU's by GPU, what upstream
# and the hardware recorded counted in, the user units verify checks. Pure: no fake machine.
FK_PURE=1 . "$(dirname "$0")/lib.sh"
sandbox
m() { ( STATE_DIR=$TMP/state; STEAM=${STEAM:-yes}; . "$REPO/lib/manifest.sh"; eval "$1" ); }
all() { m "manifest_all ${1:-amd}"; }

case_ "every list parses; the manifest for AMD and for Intel"
a=$(all amd); i=$(all intel)
((${#a} > 0 && ${#i} > 0)) && _ok || _no "empty manifest"
has "$a" lact; lacks "$i" lact; has "$i" intel-media-driver; has "$a" mesa-vulkan-drivers-freeworld

case_ "no package listed twice"
eq "$(all amd | sort | uniq -d)" "" "twice in the AMD manifest"
eq "$(all intel | sort | uniq -d)" "" "twice in the Intel manifest"

case_ "nothing both wanted and forbidden (AMD's forbidden too); nothing removed that is wanted"
eq "$(comm -12 <(all amd | sort -u) <(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}" "${FORBIDDEN_amd[@]}"' | sort -u))" ""
eq "$(comm -12 <(all intel | sort -u) <(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}"' | sort -u))" ""
eq "$(comm -12 <(all amd | sort -u) <(m 'printf "%s\n" "${PKG_REMOVE[@]}"' | sort -u))" ""
case_ "every package setup removes is also forbidden afterwards (verify keeps it out)"
eq "$(comm -23 <(m 'printf "%s\n" "${PKG_REMOVE[@]}"' | sort -u) <(m 'printf "%s\n" "${FORBIDDEN_PKGS[@]}"' | sort -u))" ""
case_ "retired packages are out of every list"
eq "$(comm -12 <(all amd | sort -u) <(m 'printf "%s\n" "${RETIRED_PKGS[@]}"' | sort -u))" ""

case_ "the base tools a Minimal Install lacks, and the programs the scripts call, are listed (never assumed)"
b=$(m 'printf "%s\n" "${PKG_BASE[@]}"')
for p in tar grubby diffutils man-db python3 git jq gnupg2 dnf5-plugins pciutils; do grep -qx "$p" <<<"$b" || _no "$p not in PKG_BASE"; done; _ok
for p in glib2 fontconfig udisks2 dconf; do grep -qx "$p" <<<"$a" || _no "$p not in the manifest"; done; _ok

case_ "STEAM=no: Steam's packages out; yes: in"
STEAM=no; has "$(all amd)" mpv; lacks "$(all amd)" steam; lacks "$(all amd)" ntsync-autoload
STEAM=yes; has "$(all amd)" steam; has "$(all amd)" ntsync-autoload

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
