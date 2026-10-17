#!/usr/bin/env bash
# tests/installer/test_setup_wait.sh — setup.sh when a repository has not caught up with this
# Fedora (a fresh install near a release, or just after a Mesa update): RPM Fusion's freeworld
# VA driver and libheif-freeworld made for another version of Fedora's Mesa and libheif, and
# LACT's COPR with no build for this release. Setup installs everything else, records what
# waits, says so once, and verify only warns; update and repair try again and clear the record
# once the repositories have caught up. Any other failure still stops setup, as before.
. "$(dirname "$0")/lib.sh"
CLONE=/home/fkuser/fedokawaii
TK=/usr/local/lib/fedokawaii
setup() { fkrun bash "$CLONE/setup.sh" "$@"; }
resume() { fkrun bash "$TK/setup.sh" --resume "$@"; }
tk() { fkrun bash "$TK/setup.sh" "$@"; }
# out_of_step — RPM Fusion's builds a version behind Fedora's Mesa and libheif
out_of_step() {
  fkh behind mesa-va-drivers-freeworld libheif-freeworld mesa-va-drivers-freeworld.i686
  fkh versions "mesa-va-drivers-freeworld 26.2.4" "mesa-filesystem 26.2.5" "libheif-freeworld 1.23.5" "libheif 1.23.6"
}
caught_up() { fkh behind; fkh versions "mesa-va-drivers-freeworld 26.2.5" "mesa-filesystem 26.2.5" \
  "libheif-freeworld 1.23.6" "libheif 1.23.6"; }

world fresh; releases
fkh_add available mesa-filesystem libheif
setup --no-reboot; eq "$RC" 0 "phase 1"
reboot_world; keep phase2

# ── RPM Fusion and a COPR behind this Fedora: setup goes on ──────────────────────
case_ "phase 2: RPM Fusion's builds out of step and LACT's COPR without a build — the rest installed, what waits recorded and said once"
out_of_step; fkh copr-nochroot ilyaz/LACT
resume --no-reboot; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
eq "$(state phase)" 3
eq "$(state pending-rpmfusion | tr '\n' ' ')" "libheif-freeworld mesa-va-drivers-freeworld "
eq "$(state pending-copr)" ilyaz/LACT
for p in ffmpeg mpv yt-dlp amd-gpu-firmware rpmfusion-free-release; do pkg_has "$p" || _no "$p not installed"; done; _ok
pkg_has mesa-vulkan-drivers && _ok || _no "no Vulkan driver: Fedora's is the desktop's"
pkg_has lact && _no "LACT installed without its COPR" || _ok
grep -qx 'enabled lactd.service' "$FKH/units" && _no "lactd enabled without LACT" || _ok
eq "$(grep -c "RPM Fusion's video drivers are not out for this Fedora yet — update or repair adds them when they are" <<<"$OUT")" 1 "said once"
has "$OUT" "RPM Fusion's HEIC photo support (libheif-freeworld) is not out for this Fedora yet"
has "$OUT" "the COPR ilyaz/LACT has no build for Fedora 44 yet — lact left out until it has"
reboot_world; keep phase3

case_ "phase 3: Steam's 32-bit drivers wait with their 64-bit ones; the gate and the final check pass, with warnings"
resume --no-reboot; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n4 | tr '\n' '|')"
eq "$(state phase)" "done"
lacks "$(state pending-rpmfusion)" vulkan; has "$(state pending-rpmfusion)" mesa-va-drivers-freeworld.i686
pkg_has mesa-vulkan-drivers.i686 && _ok || _no "Steam's 32-bit Vulkan driver (Fedora's) not installed"
pkg_has steam && _ok || _no "Steam not installed"
has "$OUT" "! waiting for RPM Fusion to catch up with Fedora 44 — libheif-freeworld mesa-va-drivers-freeworld"
has "$OUT" "! the COPR ilyaz/LACT has no build for Fedora 44 yet — lact left out"
lacks "$OUT" "✘ forbidden packages present"; lacks "$OUT" "✘ installed outside the manifest"; lacks "$OUT" "✘ missing packages"
keep waiting

case_ "verify while they wait: Fedora's VA driver (no H.264, no HEVC) is a warning, not a failure"
printf '      VAProfileAV1Profile0   : VAEntrypointVLD\n' >"$FKH/vainfo-renderD128"
fkrun bash "$TK/verify.sh"; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "! no hardware decode: H264High yet — RPM Fusion's VA driver waits for this Fedora's Mesa"
case_ "…and once nothing waits any more, the same is a failure again (Fedora's Vulkan driver is no fault: it is the desktop's)"
rm -f "$W/var/lib/fedokawaii/pending-rpmfusion"
fkrun bash "$TK/verify.sh"; eq "$RC" 3
has "$OUT" "✘ hardware decode: H264High"; lacks "$OUT" "✘ forbidden packages present"

# ── update and repair, once the repositories have caught up ───────────────────
case_ "update: RPM Fusion caught up — its builds put in (Fedora's Vulkan driver stays), the record cleared; the COPR still waits"
back waiting; caught_up
tk --update; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
[[ ! -e $W/var/lib/fedokawaii/pending-rpmfusion ]] && _ok || _no "still recorded: $(state pending-rpmfusion | tr '\n' ' ')"
for p in mesa-va-drivers-freeworld libheif-freeworld mesa-va-drivers-freeworld.i686 mesa-vulkan-drivers mesa-vulkan-drivers.i686; do
  pkg_has "$p" || _no "$p not installed"
done; _ok
pkg_has mesa-vulkan-drivers-freeworld && _no "RPM Fusion's Vulkan driver installed" || _ok
not_called 'allowerasing.*vulkan|vulkan.*allowerasing'
eq "$(state pending-copr)" ilyaz/LACT; has "$OUT" "! the COPR ilyaz/LACT has no build for Fedora 44 yet"
case_ "repair: the COPR has a build now — enabled, LACT installed and its service on, the record cleared"
fkh copr-nochroot
tk --repair; eq "$RC" 0 "$(grep -E '✘|still needs' <<<"$OUT" | head -n3 | tr '\n' '|')"
[[ ! -e $W/var/lib/fedokawaii/pending-copr ]] && _ok || _no "still recorded"
pkg_has lact && _ok || _no "LACT not installed"
grep -qx 'enabled lactd.service' "$FKH/units" && _ok || _no "lactd not enabled"
has "$OUT" "the COPR ilyaz/LACT has a build for Fedora 44 now — enabled"
case_ "update while still out of step: nothing tried in vain, nothing failed, still recorded"
back waiting; reset_calls
tk --update; eq "$RC" 0
not_called 'dnf\] -y install .*freeworld'; has "$(state pending-rpmfusion)" mesa-va-drivers-freeworld
lacks "$OUT" "not updated this time"

# ── a machine an earlier setup gave RPM Fusion's Vulkan driver ────────────────
case_ "repair: RPM Fusion's Vulkan driver (an earlier setup's, its 64-bit one taken out by its 32-bit one) — Fedora's in both arches, the record of it gone, verify clean"
back waiting; caught_up
fkh_del installed mesa-vulkan-drivers.i686; fkh_add installed mesa-vulkan-drivers-freeworld mesa-vulkan-drivers-freeworld.i686
fkh_add installed PackageKit; fkh_add userinstalled "PackageKit Weak Dependency"
echo mesa-vulkan-drivers-freeworld >>"$W/var/lib/fedokawaii/pending-rpmfusion"
fkrun bash "$TK/verify.sh"; eq "$RC" 3
has "$OUT" "✘ forbidden packages present"; has "$OUT" "mesa-vulkan-drivers-freeworld"
reset_calls
tk --repair; eq "$RC" 0 "$(grep -E '✘|still needs' <<<"$OUT" | head -n3 | tr '\n' '|')"
called 'dnf\] -y swap --allowerasing mesa-vulkan-drivers-freeworld mesa-vulkan-drivers$'
called 'dnf\] -y swap --allowerasing mesa-vulkan-drivers-freeworld.i686 mesa-vulkan-drivers.i686$'
for p in mesa-vulkan-drivers mesa-vulkan-drivers.i686; do pkg_has "$p" || _no "$p not installed"; done; _ok
for p in mesa-vulkan-drivers-freeworld mesa-vulkan-drivers-freeworld.i686 PackageKit; do pkg_has "$p" && _no "$p still installed"; done; _ok
lacks "$(state pending-rpmfusion)" vulkan
fkrun bash "$TK/verify.sh"; lacks "$OUT" "✘ forbidden packages present"; has "$OUT" "✔ dnf never takes Node 22 or PackageKit as a weak dependency"

# ── any other failure still stops ─────────────────────────────────────────────
case_ "a freeworld driver that will not install while the versions agree (a mirror broken, say): phase 2 stops as before"
back phase2; caught_up; fkh dnf-fail 'install mesa-va-drivers-freeworld'
resume --no-reboot; eq "$RC" 1
has "$OUT" "could not install mesa-va-drivers-freeworld"; eq "$(state phase)" 2
[[ ! -e $W/var/lib/fedokawaii/pending-rpmfusion ]] && _ok || _no "recorded as waiting"
case_ "a COPR that fails for another reason (not a missing build): phase 2 stops as before"
back phase2; caught_up; fkh dnf-fail 'copr enable'
resume --no-reboot; eq "$RC" 1
has "$OUT" "could not enable the COPR ilyaz/LACT"
[[ ! -e $W/var/lib/fedokawaii/pending-copr ]] && _ok || _no "recorded as waiting"

done_
