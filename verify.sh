#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  verify.sh — proves the machine matches the manifest. Read-only; safe any time.
#
#    fedokawaii verify                   (or: sudo bash fedokawaii.sh verify)
#    sudo bash verify.sh --pre-finalize  used by setup.sh before enabling the login
#
#  System checks always run. Theme checks run once the theme has been applied
#  (otherwise they are listed as "not applied", which is not a failure).
#  Every check fails if its probe fails — a broken tool can never produce a pass.
#  Exit: 0 all passed · 3 something failed (listed at the end) · 2 misuse: not root,
#  or setup has not started · 1 verify itself could not run. Log: /var/log/fedokawaii-verify.log
# ═════════════════════════════════════════════════════════════════════════════
set -uo pipefail
IFS=$'\n\t'
export LC_ALL=C.UTF-8      # every tool's output in one language and format, whatever yours is
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PRE=0
for a in "$@"; do
  case $a in
    --pre-finalize) PRE=1 ;;
    -h|--help) sed -n '3,/^# ═/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $a (bash verify.sh --help)" >&2; exit 2 ;;
  esac
done
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 2; }

STATE_DIR=/var/lib/fedokawaii
LOG_FILE=/var/log/fedokawaii-verify.log; : >"$LOG_FILE"
source "$REPO_DIR/lib/common.sh"
source "$REPO_DIR/lib/manifest.sh"
source "$REPO_DIR/lib/upstream.sh"
source "$REPO_DIR/lib/hygiene.sh"
source "$REPO_DIR/lib/hardware.sh"
read_conf "$REPO_DIR/fedokawaii.conf"
[[ -f $STATE_DIR/user ]] || { echo "setup has not started — nothing to verify yet (try: check)" >&2; exit 2; }
TARGET_USER=$(head -n1 "$STATE_DIR/user" | tr -d '[:space:]'); TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_UID=$(id -u "$TARGET_USER"); TARGET_GID=$(id -g "$TARGET_USER")
export TARGET_USER TARGET_HOME TARGET_UID TARGET_GID
GPU_KIND=$(cat "$STATE_DIR/gpu" 2>/dev/null || echo amd)
THEMED=0; [[ -f $TARGET_HOME/.local/state/fedokawaii/theme-applied ]] && THEMED=1
U() { as_user "$@"; }
dump=$(dnf --dump-main-config 2>/dev/null)
dnfopt() { sed -n "s/^$1 *= *//p" <<<"$dump"; }

hdr "Fedokawaii · verify · $(date '+%F %H:%M')"

# ── system ───────────────────────────────────────────────────────────────────
section "system"
# shellcheck disable=SC1091
source /etc/os-release
# fedokawaii.conf as it is now: each problem on a line of its own (fedokawaii settings checks
# before it saves; an edit by hand may not have been)
cp=$(conf_report)
if [[ -z $cp ]]; then pass "fedokawaii.conf: every value valid"
else while IFS= read -r l; do fail "fedokawaii.conf: $l" "fedokawaii settings"; done <<<"$cp"; fi
check "Fedora $VERSION_ID (44 or newer)"              test "$VERSION_ID" -ge 44
check "SELinux enforcing"                              test "$(getenforce 2>/dev/null)" = Enforcing
check "/ is Btrfs"                                     test "$(findmnt -no FSTYPE /)" = btrfs
# every file in your home is yours — ~/.cache, and ~/Downloads (its own Btrfs subvolume, where
# -xdev would stop) included. Root's would come from a program run as root with your HOME,
# another id's from an archive unpacked as root keeping its owners. The one exception, by
# design: rootless podman's storage, whose image layers belong to the containers' own ids
# (your subordinate ids: Prowlarr's thousands of files)
hstarts=("$TARGET_HOME"); for d in .cache Downloads; do [[ -d $TARGET_HOME/$d && ! -L $TARGET_HOME/$d ]] && hstarts+=("$TARGET_HOME/$d"); done
notmine=$(find "${hstarts[@]}" -xdev \
            -path "$TARGET_HOME/.local/share/containers/storage" -prune -o ! -user "$TARGET_USER" -printf '%u %p\n' 2>/dev/null \
          | sort -u | head -n 3 | sed "s|$TARGET_HOME|~|" | paste -sd ',' | sed 's/,/, /g')
if [[ -z $notmine ]]; then pass "no root-owned files in your home (nor anyone else's; ~/.cache and ~/Downloads included)"
else fail "files in your home that are not yours: $notmine" "a program ran as root with your HOME — send the report (sudo fedokawaii-report)"; fi
check "user in video, render"                          bash -c "id -nG $TARGET_USER | tr ' ' '\n' | grep -cxE 'video|render' | grep -qx 2"
check "EDITOR=nvim system-wide"                        grep -qx 'export EDITOR=nvim' /etc/profile.d/editor.sh
# (a script, never a link: dracut follows a link into nvim and fails on its Lua libraries —
# no boot image, no splash; setup.sh's editor_policy)
check "vi → nvim (a script: dracut never follows it into nvim)" bash -c '[[ ! -L /usr/local/bin/vi && -x /usr/local/bin/vi ]] && grep -qx "exec nvim \"\$@\"" /usr/local/bin/vi'
check "i2c-dev loaded (monitor brightness over DDC/CI)" test -d /sys/module/i2c_dev

# ── packages ─────────────────────────────────────────────────────────────────
section "packages (lib/manifest.sh)"
mapfile -t WANT < <(manifest_all "$GPU_KIND")
# a package Fedora renamed counts (the new one provides the old name); one it retired, that
# the last update could not find anywhere, is a warning — the desktop goes on without it
# (one rpm for them all — a few seconds less than one per package: every package answers with
# its providers' names, or "no package provides NAME"; fewer answers than packages means rpm
# itself failed, and that is said rather than taken for a pass)
q=$(rpm -q --whatprovides --qf '%{NAME}\n' "${WANT[@]}" 2>&1)
mapfile -t miss < <(sed -n 's/^no package provides //p' <<<"$q")
nans=$(grep -cE '^(no package provides .+|[A-Za-z0-9._+-]+)$' <<<"$q")
gone=$(cat "$STATE_DIR/unavailable" 2>/dev/null || true)
# what waits for RPM Fusion or a COPR to catch up with this Fedora (setup recorded it): a warning
WAITING=$(waiting_pkgs)
real=() ret=() wt=()
for p in "${miss[@]}"; do
  if grep -qx -- "$p" <<<"$gone"; then ret+=("$p"); elif grep -qxF -- "$p" <<<"$WAITING"; then wt+=("$p"); else real+=("$p"); fi
done
if ((nans < ${#WANT[@]})); then fail "manifest packages: rpm gave no answer" "its database may be damaged: sudo rpm --rebuilddb, then verify again"
elif ((${#miss[@]} == 0)); then pass "all ${#WANT[@]} manifest packages installed"
elif ((${#real[@]})); then fail "missing packages" "$(IFS=' '; echo "${real[*]}")"
else pass "$((${#WANT[@]} - ${#ret[@]} - ${#wt[@]})) of ${#WANT[@]} manifest packages installed"; fi
((${#ret[@]} == 0)) || warn "no longer in Fedora (renamed or retired)" "$(IFS=' '; echo "${ret[*]}")"
# each one RPM Fusion has not matched yet, with both versions: what it is made for, what
# Fedora has (the base package: libheif for libheif-freeworld, Mesa for the drivers)
while IFS= read -r p; do
  [[ -n $p ]] || continue
  case ${p%.i686} in libheif-freeworld) b=libheif ;; mesa-*-freeworld) b=mesa-filesystem ;; *) b="" ;; esac
  rv=$(dnf -q repoquery --latest-limit=1 --qf '%{version}\n' "${p%.i686}" 2>/dev/null | head -n1)
  fv=${b:+$(rpm -q --qf '%{version}\n' "$b" 2>/dev/null | head -n1)}
  if [[ -z $rv ]]; then warn "$p: RPM Fusion has none for Fedora $VERSION_ID yet" "update or repair adds it when it is out"
  else warn "$p $rv waits for Fedora's $b $rv (this machine has ${fv:-?})" "it installs itself at the update after Fedora's $b reaches $rv"; fi
done < <(waiting rpmfusion)
for c in $(waiting copr); do
  warn "the COPR $c has no build for Fedora $VERSION_ID yet" "$(copr_pkgs "$c" | tr '\n' ' ')left out — update or repair adds it when it has one"
done
# lpf, which built Spotify's app here before Spotify became its web player: gone, with the
# app and recipe (RETIRED_PKGS: dnf's clean-up) and then its account and folder (repair)
q=$(rpm -q lpf lpf-spotify-client spotify-client 2>/dev/null | grep -v 'is not installed' | tr '\n' ' ' || true)
left=$( { getent passwd pkg-build >/dev/null && echo "the user pkg-build"; [[ -e /var/lib/lpf ]] && echo /var/lib/lpf; } | tr '\n' ' ' || true)
if [[ -n ${q// /} ]]; then warn "lpf and Spotify's old app are still installed: $q" "update or repair hands them to dnf's clean-up (Spotify is its web player now)"
elif [[ -n ${left// /} ]]; then warn "lpf's leftovers: $left" "fedokawaii repair removes them"
else pass "no lpf, nothing it left (Spotify is its web player)"; fi

# ── zero redundancy ──────────────────────────────────────────────────────────
section "zero redundancy"
forbid=("${FORBIDDEN_PKGS[@]}") standin=()
# (on AMD Fedora's own Mesa drivers: never — but while RPM Fusion's waits, Fedora's stands in)
if [[ $GPU_KIND == amd ]]; then
  for p in "${FORBIDDEN_amd[@]}"; do
    if waiting rpmfusion | grep -qx "$p-freeworld"; then standin+=("$p"); else forbid+=("$p"); fi
  done
fi
q=$(rpm -q "${forbid[@]}" 2>/dev/null || true)          # (one line per name, whichever the answer)
present=$(grep -v 'is not installed' <<<"$q" | tr '\n' ' ' || true)
if (($(grep -c . <<<"$q" || true) < ${#forbid[@]})); then
  fail "forbidden packages: rpm gave no answer" "its database may be damaged: sudo rpm --rebuilddb, then verify again"
elif [[ -z ${present// /} ]]; then pass "none of ${#forbid[@]} forbidden packages present"
else fail "forbidden packages present" "$present"; fi
# what you installed yourself (reason "user", or an rpm outside dnf): a package a comps group
# brought in — kmscon, which Fedora 45's core group gained, arriving with the move — is the
# release's own, not yours (a dnf without the reason tag: every user-installed name counts)
if ui=$(dnf repoquery --userinstalled --qf '%{name} %{reason}\n' 2>/dev/null) && [[ -n $ui ]]; then
  ui=$(awk 'NF < 2 || tolower($0) ~ / (external )?user$/ { print $1 }' <<<"$ui")
elif ui=$(dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null) && [[ -n $ui ]]; then :; else ui=""; fi
if [[ -n $ui ]]; then
  # (the manifest by its names, and by the names its packages have now — Fedora renames some)
  extras=$(comm -23 <(sort -u <<<"$ui") <({ cat "$STATE_DIR/baseline-userinstalled" 2>/dev/null; printf '%s\n' "${WANT[@]}" "${standin[@]}"
                                             rpm -q --qf '%{NAME}\n' --whatprovides "${WANT[@]}" 2>/dev/null | grep -v ' '; } | sort -u) \
           | grep -v '^kernel' | tr '\n' ' ')
  if [[ -z $extras ]]; then pass "nothing user-installed beyond the manifest"; else fail "installed outside the manifest" "$extras"; fi
else fail "nothing user-installed beyond the manifest" "dnf repoquery failed"; fi
check "no Flatpak, no Snap"                            bash -c 'command -v dnf && ! command -v flatpak && ! command -v snap'
check "one editor (no vim, nano, emacs)"               bash -c 'command -v nvim && ! command -v vim && ! command -v nano && ! command -v emacs'
# nothing doubled, nothing fighting (lib/hygiene.sh) — repair puts each of these right
d=$(hy_duplicates)
if [[ -z $d ]]; then pass "no package installed twice"
else fail "packages installed twice" "$(tr '\n' ' ' <<<"$d")— repair keeps the newer"; fi
d=$(hy_dnf_problems)
if [[ -z $d ]]; then pass "dnf check: every dependency in place"
else fail "dnf check reports problems" "$(head -n 3 <<<"$d" | tr '\n' ' ')— repair"; fi
d=$(hy_services)
if [[ -z $d ]]; then pass "no system service fights the desktop's own"
else fail "services that fight the desktop's own" "$(cut -d'|' -f1 <<<"$d" | tr '\n' ' ')— repair switches them off"; fi
d=$(hy_user_services)
if [[ -z $d ]]; then pass "none of your services fights the session's"
else fail "your services that fight the session's" "$(cut -d'|' -f1 <<<"$d" | tr '\n' ' ')— repair switches them off"; fi
d=$(hy_display_manager)
if [[ $d == greetd.service ]] || [[ -z $d && $PRE == 1 ]]; then pass "the login is greetd's alone"   # (before finalize: none yet)
else fail "the login is ${d:-no login manager at all}" "greetd should be — repair"; fi
d=$(hy_unneeded)
if [[ -z $d ]]; then pass "no dependency left that nothing needs"
else warn "dependencies nothing needs any more" "$(tr '\n' ' ' <<<"$d")— update and repair clear them"; fi
d=$(hy_rpmnew)
if [[ -z $d ]]; then pass "no configuration file left unmerged (.rpmnew, .rpmsave)"
else warn "configuration files to compare by hand" "$(tr '\n' ' ' <<<"$d")"; fi
d=$(hy_leftovers)
if [[ -z $d ]]; then pass "nothing left behind by a stopped run"
else warn "left behind by a stopped run" "$(tr '\n' ' ' <<<"$d")— repair clears it"; fi

# ── repositories & dnf ───────────────────────────────────────────────────────
section "repositories & dnf"
enabled=$(dnf repolist --enabled 2>/dev/null | awk 'NR>1{print $1}')
for r in fedora updates rpmfusion-free rpmfusion-free-updates rpmfusion-nonfree rpmfusion-nonfree-updates brave-browser claude-code; do
  check "repo $r enabled" grep -qx "$r" <<<"$enabled"
done
for c in "${COPRS[@]}"; do
  waiting copr | grep -qxF "$c" && continue        # (no build for this Fedora yet: warned above)
  check "COPR $c enabled" grep -q "copr.*${c#*/}" <<<"$enabled"
done
for pr in brave-origin:brave-browser claude-code:claude-code; do
  check "${pr%%:*} from ${pr#*:} (gpgcheck=1)" \
    bash -c "test \"\$(dnf repoquery --installed --qf '%{from_repo}' ${pr%%:*})\" = ${pr#*:} && grep -qx gpgcheck=1 /etc/yum.repos.d/${pr#*:}.repo"
done
check "dnf max_parallel_downloads=$DNF_PARALLEL"       test "$(dnfopt max_parallel_downloads)" = "$DNF_PARALLEL"
check "dnf fastestmirror on"                           grep -qxiE '1|true' <<<"$(dnfopt fastestmirror)"
check "dnf timeout=20 (slow mirrors dropped)"          test "$(dnfopt timeout)" = 20
check "dnf installonly_limit=2 (dnf5 minimum)"         test "$(dnfopt installonly_limit)" = 2
check "dnf minrate=5k (stalled mirrors dropped)"       grep -qxE '5120|5[kK]' <<<"$(dnfopt minrate)"
check "dnf defaultyes on"                              grep -qxiE '1|true' <<<"$(dnfopt defaultyes)"
# (a list: other files may add to it — both names in it is what counts)
check "no package downloads in the background (dnf's makecache timer masked)" \
  bash -c 'for u in dnf5-makecache.timer dnf-makecache.timer; do systemctl cat "$u" >/dev/null 2>&1 || continue; [[ $(systemctl is-enabled "$u" 2>/dev/null) == masked ]] || exit 1; done'
check "dnf never takes Node 22, PackageKit, Java or LibreOffice's offline help as a weak dependency" \
  bash -c 'l=$(tr ", " "\n\n" <<<"$1"); for w in nodejs "nodejs22*" PackageKit "java-*-openjdk-headless" "libreoffice-help-*"; do grep -qxF "$w" <<<"$l" || exit 1; done' _ "$(dnfopt exclude_from_weak)"

# ── upkeep: the toolkit and its control ──────────────────────────────────────
section "upkeep (fedokawaii · Super+U)"
TK=/usr/local/lib/fedokawaii
check "the toolkit: root's own copy, writable by root alone" \
  bash -c 'test -f "$1/setup.sh" && test -z "$(find "$1" \( ! -user root -o \( ! -type l -perm /022 \) \) -print -quit)"' _ "$TK"
check "the control: fedokawaii is the toolkit's"         cmp -s "$TK/system/fedokawaii" /usr/local/bin/fedokawaii
check "the manifest's packages marked as yours (dnf's clean-up never takes them)" \
  bash -c 'u=$(dnf repoquery --userinstalled --qf "%{name}\n" 2>/dev/null) || exit 1
           for p; do n=$p; rpm -q "$p" >/dev/null 2>&1 || n=$(rpm -q --qf "%{NAME}\n" --whatprovides "$p" 2>/dev/null | awk "NR == 1")
                     grep -qx "${n:-$p}" <<<"$u" || exit 1; done' \
  _ greetd NetworkManager sudo snapper

# ── boot & kernel ────────────────────────────────────────────────────────────
section "boot & kernel"
# the boot menu is the theme's one optional part: when its run could not make it (its mark,
# theme.sh's BOOT_MARK), the theme check below already says so — as a warning while nothing
# has changed since, which must not turn into a failure here and stop setup's gate for good
BOOT_SKIPPED=0; ((THEMED)) && [[ -s $STATE_DIR/boot.failed ]] && BOOT_SKIPPED=1
if ((BOOT_SKIPPED)); then
  info "boot menu: not themed here (the theme check below says why) — left as Fedora set it"
elif ((THEMED && BOOT_MENU_SECONDS > 0)); then
  check "GRUB menu shown for $BOOT_MENU_SECONDS s (themed)" bash -c 'l=$(grub2-editenv - list) && ! grep -qx menu_auto_hide=1 <<<"$l"'
elif [[ -s $STATE_DIR/other-os ]]; then   # (dual boot: setup and Theme leave it shown, even at 0 s)
  check "GRUB menu shown (this machine also starts $(paste -sd, - <"$STATE_DIR/other-os"))" bash -c 'l=$(grub2-editenv - list) && ! grep -qx menu_auto_hide=1 <<<"$l"'
else
  check "GRUB menu hidden (shows after a failed boot)" bash -c 'l=$(grub2-editenv - list) && grep -qx menu_auto_hide=1 <<<"$l"'
fi
check "boot success marked by the desktop, not at boot"  bash -c '[[ $(systemctl --global is-enabled grub-boot-success.timer 2>/dev/null) != enabled ]]'
mapfile -t kv < <(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | grep -v 'not installed' | sort -V)
running=$(uname -r)
# one kernel at rest, the newest (setup.sh: old_kernels_out) — two only while the newest waits for
# a restart, or for its first start to reach the desktop
if ((${#kv[@]} == 1)) && [[ ${kv[0]} == "$running" ]]; then pass "one kernel, the newest, running ($running)"
elif ((${#kv[@]} == 2)) && [[ ${kv[-1]} == "$running" ]]; then
  warn "the kernel before $running is still installed" "it goes a quarter of an hour into a start that reaches the desktop — or now: fedokawaii repair"
elif ((${#kv[@]} >= 1 && ${#kv[@]} <= 2)); then warn "new kernel ${kv[-1]} installed" "restart to use it (running: $running); the one before goes after that"
else fail "one kernel (two at most while a new one settles in)" "installed: $(IFS=" "; echo "${kv[*]:-none}") · running: $running — fedokawaii repair keeps the newest"; fi
check "one kernel kept at every start (fedokawaii-kernels.timer)" systemctl is-enabled --quiet fedokawaii-kernels.timer
# (dracut makes a kernel's boot image from the package's scriptlet, which can fail without
# failing dnf: that entry would not start — repair makes the image again)
noimg=(); for v in "${kv[@]}"; do [[ -s /boot/initramfs-$v.img ]] || noimg+=("$v"); done
if ((${#noimg[@]} == 0)); then pass "every kernel has its boot image (initramfs)"
else fail "kernels without a boot image (initramfs)" "$(IFS=' '; echo "${noimg[*]}") — would not start; repair makes them (dracut)"; fi
check "no rescue kernel or boot entry"                 bash -c '! ls /boot/vmlinuz-0-rescue-* /boot/loader/entries/*-0-rescue*.conf 2>/dev/null | grep -q .'
for b in "${BOOT_ARGS[@]}"; do   # (setup.sh's s_quiet_boot: the splash, nothing else on the screen, no console-size wait)
  check "$b on every boot entry" \
    bash -c 'a=$(grubby --info=ALL | grep "^args=") && [ -n "$a" ] && ! printf "%s\n" "$a" | grep -vqE "[\" ]$1([\" ]|\$)"' _ "$b"
done
# (the ones this start was given: an entry that just gained them shows them from the next)
quiet_now=1; for b in "${BOOT_ARGS[@]}"; do tr ' ' '\n' </proc/cmdline 2>/dev/null | grep -qxF -- "$b" || quiet_now=0; done
if ((quiet_now)); then pass "a quiet boot, this start too (the boot's arguments active)"
else info "the boot's arguments are on every entry; this start had not all of them — they show from the next"; fi
check "a text console shows its cursor at login (/etc/profile.d/fedokawaii-console.sh)" grep -qF '25h' /etc/profile.d/fedokawaii-console.sh
if [[ $GPU_KIND == amd ]]; then
  # (this exact value, a whole argument: an older one, or one LACT cannot use, does not pass)
  check "$AMDGPU_ARG on every boot entry" \
    bash -c 'a=$(grubby --info=ALL | grep "^args=") && [ -n "$a" ] && ! printf "%s\n" "$a" | grep -vqE "[\" ]$1([\" ]|\$)"' _ "$AMDGPU_ARG"
  check "$AMDGPU_ARG active now"                       bash -c 'tr " " "\n" </proc/cmdline | grep -qxF -- "$1"' _ "$AMDGPU_ARG"
fi

# ── GPU & media ──────────────────────────────────────────────────────────────
section "GPU & media"
# the render node of the card the desktop is built for: a desktop with the CPU's own graphics
# switched on beside an AMD card has two, and the integrated one usually comes first
want_vendor=0x1002; [[ $GPU_KIND == intel ]] && want_vendor=0x8086
rnd=""
for n in /dev/dri/renderD*; do
  [[ $(cat "/sys/class/drm/${n##*/}/device/vendor" 2>/dev/null) == "$want_vendor" ]] && { rnd=$n; break; }
done
[[ -n $rnd ]] || rnd=$(compgen -G '/dev/dri/renderD*' | head -n1)
va=$(vainfo --display drm --device "$rnd" 2>/dev/null)
# (Fedora's own VA driver leaves H.264 and HEVC out: while RPM Fusion's waits, a warning)
for p in VAProfileH264High VAProfileHEVCMain; do
  if grep -q "$p" <<<"$va"; then pass "hardware decode: ${p#VAProfile}"
  elif [[ $GPU_KIND == amd ]] && waiting rpmfusion | grep -qx mesa-va-drivers-freeworld; then
    warn "no hardware decode: ${p#VAProfile} yet" "RPM Fusion's VA driver waits for this Fedora's Mesa — such video plays on the CPU meanwhile"
  else fail "hardware decode: ${p#VAProfile}"; fi
done
# AV1 decoding needs AMD RDNA 2+ or Intel Tiger Lake+: older cards get a note, not a failure
if grep -q VAProfileAV1Profile0 <<<"$va"; then pass "hardware decode: AV1Profile0"
elif [[ -n $va ]]; then warn "no AV1 hardware decode" "this GPU predates it; AV1 video decodes on the CPU"
else fail "hardware decode" "vainfo found no VA-API driver on ${rnd:-any render node}"; fi
check "Vulkan driver present"                          compgen -G '/usr/share/vulkan/icd.d/*.json'
if [[ $GPU_KIND == amd ]]; then
  # btop opens the ROCm SMI library by name — librocm_smi64.so.1.0 is, of the names it tries
  # (btop_collect.cpp), the one Fedora's rocm-smi ships; a new soname would quietly lose it
  # the card (the manifest check above already says whether the package is there)
  if rpm -ql rocm-smi 2>/dev/null | grep -qx /usr/lib64/librocm_smi64.so.1.0; then pass "ROCm SMI library for btop (librocm_smi64.so.1.0)"
  else warn "btop's view of the card" "rocm-smi has no librocm_smi64.so.1.0 — btop finds no GPU until it learns the new name (LACT still shows the card)"; fi
fi
enc=$(ffmpeg -hide_banner -encoders 2>/dev/null)
for e in libx264 libx265 libsvtav1 libaom-av1; do check "ffmpeg encoder $e" grep -qw "$e" <<<"$enc"; done

# ── this machine's drivers and firmware (lib/hardware.sh) ────────────────────
section "drivers and firmware"
cpu=$(hw_cpu_vendor)
mapfile -t hw < <(hw_wanted -C | grep . | sort -u)     # (-C: dnf's cached metadata — no network)
miss=(); for p in "${hw[@]}"; do pkg_installed "$p" || miss+=("$p"); done
if ((${#miss[@]} == 0)); then pass "this machine's driver packages installed (${#hw[@]}: $(IFS=' '; echo "${hw[*]:-none needed}"))"
# (missing, the desktop still works: a warning, and update and repair try again — a package
# that would not install must never keep setup from finishing)
else warn "driver packages this machine needs" "$(IFS=' '; echo "${miss[*]}") — update and repair install them"; fi
case $cpu in
  GenuineIntel|AuthenticAMD)
    # (grep reads to the end: -q would stop at the line, and journalctl's write would fail)
    if journalctl -k -b -o cat --no-pager 2>/dev/null | grep -iE 'microcode: (updated early|.*revision)' >/dev/null; then pass "CPU microcode loaded at boot ($cpu)"
    else info "the kernel log says nothing of microcode this boot ($cpu: it may already be current in the firmware)"; fi ;;
esac
d=$(hw_driverless)
if [[ -z $d ]]; then pass "every network, display, sound and USB device has its driver"
else warn "devices no driver holds" "$(tr '\n' ';' <<<"$d") — lspci -nnk names them"; fi
if hw_has_wifi; then
  check "Wi-Fi managed by NetworkManager"              bash -c '! nmcli -t -f TYPE,STATE device | grep -q "^wifi:unmanaged"'
fi
d=$(cat "$STATE_DIR/fw-updates" 2>/dev/null)
if [[ -n $d ]]; then info "firmware updates for this machine's devices (fwupdmgr update applies them): $(tr '\n' ';' <<<"$d")"; fi
# drives — USB sticks, disks, SD cards: udisks opens them for udiskie (and kawa-drives)
check "drives: udisks answers (what you plug in opens)" \
  busctl --system get-property org.freedesktop.UDisks2 /org/freedesktop/UDisks2/Manager org.freedesktop.UDisks2.Manager Version
if modinfo ntfs3 >/dev/null 2>&1; then info "NTFS drives open with the kernel's ntfs3 (ntfs-3g stands by)"
else info "NTFS drives open with ntfs-3g (this kernel has no ntfs3)"; fi

# ── compositor & login ───────────────────────────────────────────────────────
section "compositor & login"
check "dwl $DWL_TAG installed"                         U bash -c "/usr/local/bin/dwl -v 2>&1 | grep -q '${DWL_TAG#v}'"
check "dwl at the pinned commit"                       test "$(U git -C "$TARGET_HOME/.local/src/dwl" rev-parse HEAD 2>/dev/null)" = "$DWL_COMMIT"
check "dwl built with XWayland (Steam, X11 apps)"      U bash -c 'ldd /usr/local/bin/dwl | grep -q libxcb'
# (the whole patch, as theme.sh tests it: it would come off cleanly — fed on stdin, as root
# reads the toolkit's copy)
dwl_patched() { U git -C "$TARGET_HOME/.local/src/dwl" apply --reverse --check - <"$REPO_DIR/src/dwl/dwl.patch" >/dev/null 2>&1; }
check "dwl.patch applied (keys, gaps, frames, centring, layout, the pen, the theme's borders)" dwl_patched
check "dwl's own wlroots $DWL_WLROOTS kept"             wlr_kept
check "dwl finds every library (its wlroots: its own)"  U bash -c 'l=$(ldd /usr/local/bin/dwl) && ! grep -q "not found" <<<"$l" && grep -qF "$1/lib/libwlroots" <<<"$l"' _ "$(wlr_home)"
check "session launcher (start-dwl)"                   test -x /usr/local/bin/start-dwl
check "keyboard layouts $KB_LAYOUTS"                   grep -q "XKB_DEFAULT_LAYOUT=\"$KB_LAYOUTS\"" /usr/local/bin/start-dwl
check "greetd SELinux module loaded"                   bash -c 'semodule -l | grep -qw greetd'
check "greetd runs the login screen (kawa-greet in cage) for $TARGET_USER" grep -qxF "command = \"env \$(/usr/local/bin/start-dwl --gpu) \\\"XCURSOR_THEME=Sumi-\$(cat /var/lib/fedokawaii-greeter/theme)\\\" systemd-cat -t kawa-greet cage -d -s -- /usr/local/bin/kawa-greet $TARGET_USER\"" /etc/greetd/fedokawaii.toml
check "greetd reads fedokawaii.toml"                   bash -c 'systemctl cat greetd.service | grep -qx "ExecStart=/usr/bin/greetd --config /etc/greetd/fedokawaii.toml"'
# (its drop-in: tty1 its own — no text login under the login screen — and started once the
# splash has gone, never taking the screen from it: setup.sh's greetd_config)
check "greetd owns tty1 and follows the boot splash (its drop-in)" bash -c 'u=$(systemctl cat greetd.service) && grep -qE "^Conflicts=.*getty@tty1\.service" <<<"$u" && grep -qE "^After=.*plymouth-quit-wait\.service" <<<"$u"'
check "a login screen that cannot start is said on tty1, not a black screen (greetd's OnFailure)" bash -c 'systemctl cat greetd.service | grep -qx "OnFailure=fedokawaii-login-failed.service" && grep -q "The login screen could not start" /etc/systemd/system/fedokawaii-login-failed.service'
check "the health report (fedokawaii-report) is the toolkit's" cmp -s "$TK/system/fedokawaii-report" /usr/local/bin/fedokawaii-report
((PRE)) || check "the health report runs once, on the first start"  systemctl is-enabled --quiet fedokawaii-report.service   # (finalize enables it)
check "the login screen (kawa-greet) installed"          test -x /usr/local/bin/kawa-greet
check "the login screen's look, both themes (/usr/local/share/fedokawaii/greeter)" bash -c 'for t in dark light; do d=/usr/local/share/fedokawaii/greeter/$t; for f in gtklock.css padlock.png seal-{1..7}.png; do [[ -s $d/$f ]] || exit 1; done; done'
check "the login screen follows your theme (/var/lib/fedokawaii-greeter is yours)" test "$(stat -c %U /var/lib/fedokawaii-greeter 2>/dev/null)" = "$TARGET_USER"
check "the pixel font crisp for every account (/etc/fonts/conf.d)" test -s /etc/fonts/conf.d/60-fedokawaii-pixel.conf
check "the lock screen's words (\"ちがう · wrong password\")" cmp -s "$REPO_DIR/art/gtklock.mo" /usr/share/locale/fk/LC_MESSAGES/gtklock.mo
# the file dialog: yazi through xdg-desktop-portal-termfilechooser, which setup.sh builds — the
# only one (portals.conf names no other), so not built means apps have no file dialog at all
tfc=/usr/local/libexec/xdg-desktop-portal-termfilechooser
if [[ ! -e $tfc ]]; then
  fail "yazi file dialog not built (termfilechooser): apps cannot open or save files" "update or repair builds it"
else
  check "yazi file dialog: termfilechooser ${TFC_TAG:-?} runs" U bash -c '[[ $("$1" -v 2>/dev/null) == "xdg-desktop-portal-termfilechooser ${2#v}" ]]' _ "$tfc" "${TFC_TAG:-}"
  check "termfilechooser known to the portals, D-Bus, systemd" test -f /usr/local/share/xdg-desktop-portal/portals/termfilechooser.portal \
    -a -f /usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.termfilechooser.service \
    -a -f /usr/local/lib/systemd/user/xdg-desktop-portal-termfilechooser.service
fi

# ── services ─────────────────────────────────────────────────────────────────
section "services"
svcs=("${SVC_SYSTEM[@]}"); [[ $GPU_KIND == amd ]] && svcs+=("${SVC_SYSTEM_amd[@]}")
for s in "${svcs[@]}"; do
  [[ $PRE == 1 && ( $s == greetd.service || $s == snapper-* ) ]] && continue
  [[ $s == lactd.service ]] && grep -qx lact <<<"$WAITING" && continue   # (LACT waits for its COPR: warned above)
  check "$s enabled" systemctl is-enabled --quiet "$s"
done
for s in "${SVC_USER_GLOBAL[@]}"; do check "user unit $s enabled" bash -c "systemctl --global is-enabled $s | grep -qx enabled"; done
check "tuned profile fedokawaii (always-plugged desktop)" bash -c 'tuned-adm active 2>/dev/null | grep -q fedokawaii'
check "Wi-Fi power saving off"                         test -f /etc/NetworkManager/conf.d/90-fedokawaii.conf
check "Bluetooth dongle power saving off (btusb)"      grep -qx 'options btusb enable_autosuspend=0' /etc/modprobe.d/fedokawaii-btusb.conf
# the sound card's codec awake (no click as it wakes): set for every start, and in force now
# when the driver is loaded (a card that is not Intel HDA has no such setting: nothing to say)
if ! grep -qx 'options snd_hda_intel power_save=0' /etc/modprobe.d/fedokawaii-audio.conf 2>/dev/null; then
  fail "the sound card never naps (no click at a volume change)" "/etc/modprobe.d/fedokawaii-audio.conf missing — repair puts it in"
elif [[ -r /sys/module/snd_hda_intel/parameters/power_save && $(cat /sys/module/snd_hda_intel/parameters/power_save) != 0 ]]; then
  fail "the sound card never naps (no click at a volume change)" "snd_hda_intel power_save is $(cat /sys/module/snd_hda_intel/parameters/power_save) now — repair sets 0"
else pass "the sound card never naps (no click at a volume change)"; fi
[[ $STEAM == yes ]] && check "ntsync ready for Proton (/dev/ntsync)" test -c /dev/ntsync
check "linger on (update, repair, verify reach your services)" test -f "/var/lib/systemd/linger/$TARGET_USER"
check "sleep is suspend only (no hibernation)"           grep -qx 'AllowHibernation=no' /etc/systemd/sleep.conf.d/90-fedokawaii.conf
check "every sleep locked first (the Sleep key is dwl's)"    grep -qx 'HandleSuspendKey=ignore' /etc/systemd/logind.conf.d/90-fedokawaii.conf
check "shutdown waits 30 s at most for your services"  grep -qx 'TimeoutStopSec=30s' '/etc/systemd/system/user@.service.d/fedokawaii.conf'
check "a restart waits for Steam to close properly (25 s at most)" grep -qx 'InhibitDelayMaxSec=25' /etc/systemd/logind.conf.d/90-fedokawaii.conf
check "secrets.sh private (yours, chmod 600)"          bash -c '[[ ! -e $1 ]] || [[ $(stat -c "%a %U" "$1") == "600 $2" ]]' _ "$TARGET_HOME/.config/fedokawaii/secrets.sh" "$TARGET_USER"
# torrents: one key, in secrets.sh only; Prowlarr takes it, torrra gets it from kawa-torrra
# shellcheck disable=SC2016  # expanded by the user's bash, after sourcing the file
pkey=$(U bash -c '. "$1" >/dev/null 2>&1; printf %s "${PROWLARR_API_KEY:-}"' _ "$TARGET_HOME/.config/fedokawaii/secrets.sh" 2>/dev/null) || pkey=""
prowlarr_get() {   # prowlarr_get PATH — the key goes to curl on stdin, never as an argument
  printf 'header = "X-Api-Key: %s"\n' "$pkey" | U curl -fsS --max-time 5 -K - "http://127.0.0.1:9696/api/v1/$1"
}
# (tested here, in this shell: the key never goes on a command line)
if [[ $pkey =~ ^[0-9a-f]{32}$ ]]; then pass "Prowlarr key in secrets.sh (PROWLARR_API_KEY)"
else fail "Prowlarr key in secrets.sh (PROWLARR_API_KEY)" "missing or not 32 hex characters — repair makes one"; fi
check "Prowlarr container file current"                cmp -s "$REPO_DIR/system/prowlarr.container" "$TARGET_HOME/.config/containers/systemd/prowlarr.container"
# Its start waits for nothing online: quadlet's default dependency on podman's
# podman-user-wait-network-online.service polls the system's network-online.target, which no
# unit pulls in on this desktop's boots — 90 s, then a failed start ([Quadlet]
# DefaultDependencies=false in the container file takes it out; systemd's own view asked here)
pdeps=$(U systemctl --user show -p Wants -p After --value prowlarr.service 2>/dev/null) || pdeps=""
if [[ $pdeps == *podman-user-wait-network-online* ]]; then
  fail "Prowlarr's start waits for the network to be online (podman-user-wait-network-online.service: 90 s, then a failure)" "repair puts the current container file in"
else pass "Prowlarr's start waits on nothing online (it answers on 127.0.0.1 only)"; fi
# Prowlarr runs on demand: started for these checks, and stopped again after if it was not
# running before; one already running is not started again (a start job then would only
# re-run its dependencies, and say nothing about Prowlarr)
prowlarr_was=0; U systemctl --user is-active --quiet prowlarr.service && prowlarr_was=1
if ((prowlarr_was)); then pass "Prowlarr starts (it runs on demand) — running already"
else
  info "starting Prowlarr to check it (a few seconds)"
  check "Prowlarr starts (it runs on demand)"         U systemctl --user start prowlarr.service
fi
check "Prowlarr answers on 127.0.0.1:9696"             U curl -fsS --max-time 5 -o /dev/null http://127.0.0.1:9696/ping
check "Prowlarr takes the key from secrets.sh"         prowlarr_get health
# no login: it answers on this computer only, so its page opens with nothing asked —
# authentication "external" (the container file), and its page itself, not a sign-in
pauth=$(prowlarr_get system/status 2>/dev/null | jq -r '.authentication // empty' 2>/dev/null) || pauth=""
pcode=$(U curl -s --max-time 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:9696/ 2>/dev/null) || pcode=""
if [[ $pauth == external && $pcode == 200 ]]; then pass "Prowlarr's page opens with no login (it answers on 127.0.0.1 only)"
else fail "Prowlarr's page opens with no login" "authentication: ${pauth:-?}, its page answered ${pcode:-nothing} — repair puts the current container file in"; fi
check "Prowlarr's files are yours (~/.config/prowlarr)" bash -c '[[ -d $1 && -z $(find "$1" ! -user "$2" -print -quit) ]]' _ "$TARGET_HOME/.config/prowlarr" "$TARGET_USER"
# the usual public indexers setup adds (system/prowlarr-indexers.py): each there, by its
# definition (switched off by you counts: yours to decide)
ix_want=$(sed -n 's/^INDEXERS = \[\(.*\)/\1/p; /^            (/p' "$REPO_DIR/system/prowlarr-indexers.py" | grep -o '("[A-Za-z0-9]*"' | tr -d '("' | tr 'A-Z' 'a-z' | sort)
ix_have=$(prowlarr_get indexer 2>/dev/null | jq -r '.[].definitionName // empty' 2>/dev/null | tr 'A-Z' 'a-z' | sort)
ix_miss=$(comm -23 <(printf '%s\n' "$ix_want") <(printf '%s\n' "$ix_have") | paste -sd ' ')
nidx=$(prowlarr_get indexer 2>/dev/null | jq '[.[] | select(.enable)] | length' 2>/dev/null) || nidx=0
if [[ -z $ix_miss ]]; then pass "Prowlarr's indexers: all $(wc -l <<<"$ix_want") of the usual ones, $nidx switched on"
else warn "Prowlarr's indexers missing: $ix_miss" "fedokawaii repair adds them (online)"; fi
((prowlarr_was)) || U systemctl --user stop --no-block prowlarr.service 2>/dev/null || true
dbb=$(U podman info --format '{{.Host.DatabaseBackend}}' 2>/dev/null) || dbb=""
if [[ $dbb == sqlite ]]; then pass "podman database: sqlite (ready for Podman 6)"
else warn "podman database: ${dbb:-unknown}" "Podman 6 (Fedora 45) reads only sqlite — podman system migrate --migrate-db"; fi
if [[ $(stat -f -c %T "$TARGET_HOME") == btrfs ]]; then
  # shellcheck disable=SC2088  # literal ~ in labels
  if btrfs subvolume show "$TARGET_HOME/Downloads" >/dev/null 2>&1; then pass "~/Downloads kept out of /home's snapshots (own subvolume)"
  else warn "~/Downloads is inside /home's snapshots" "a deleted download keeps its space until the last snapshot holding it expires"; fi
fi
# the firewall's ports — when firewalld runs (Fedora's, from @core). Without it (taken out, or
# switched off) nothing filters at all: setup says so and goes on (s_ssh, torrent_port), and
# so does this — a warning, never a failure that would stop setup's gate for good
fw=1; firewall-cmd -q --state 2>/dev/null || fw=0
if ((fw)); then
  ports=$(firewall-cmd --list-ports 2>/dev/null) || ports="(firewalld not answering)"
  fwsvc=$(firewall-cmd --list-services 2>/dev/null) || fwsvc="(firewalld not answering)"
  check "torrent port 6881 open (tcp + udp)"           bash -c "grep -q 6881/tcp <<<'$ports' && grep -q 6881/udp <<<'$ports'"
  check "LocalSend's port $LOCALSEND_PORT open (tcp + udp)" bash -c "grep -q $LOCALSEND_PORT/tcp <<<'$ports' && grep -q $LOCALSEND_PORT/udp <<<'$ports'"
else
  warn "no firewall running (firewalld)" "nothing filters connections from outside; the ports of torrra (6881) and LocalSend ($LOCALSEND_PORT) are open anyway"
fi
if [[ $SSH_SERVER == no ]]; then
  check "sshd off (SSH_SERVER=no)"                     bash -c '! systemctl is-enabled --quiet sshd.service'
  ((fw)) && check "firewall: no ssh / cockpit"         bash -c "[[ '$fwsvc' != *'not answering'* ]] && ! grep -qwE 'ssh|cockpit' <<<'$fwsvc'"
else
  check "sshd on (SSH_SERVER=yes)"                     systemctl is-enabled --quiet sshd.service
fi

# ── upstream binaries ────────────────────────────────────────────────────────
section "upstream binaries (lib/upstream.sh)"
for e in "${UPSTREAM[@]}"; do
  IFS='|' read -r name _ tag _ _ bins <<<"$e"; IFS=' ' read -r -a list <<<"$bins"
  [[ $(up_tag "$name") == "$tag" ]] || { fail "$name is not the pinned $tag" "repair puts it back"; continue; }
  for b in "${list[@]}"; do
    f=$TARGET_HOME/.local/bin/$b
    if [[ ! -x $f ]]; then fail "$b missing" "repair puts it back"; continue; fi
    if grep -q 'not found' <<<"$(U ldd "$f" 2>/dev/null)"; then fail "$b has missing libraries"; continue; fi
    check "$b $tag runs" U timeout 10 "$f" --version
  done
done
check "Fusion Pixel 12 $FUSION_TAG (the desktop's font, for every account)" test -s "$FUSION_DIR/fusion-pixel-12px-monospaced-ja.ttf" -a "$(cat "$FUSION_DIR/.version" 2>/dev/null)" = "$FUSION_TAG"
# Syncplay, from its pinned source (setup carries on without it: update and repair fetch it)
case $(up_tag syncplay) in
  "") warn "Syncplay not installed yet" "update and repair fetch it (watching together waits till then)" ;;
  "$(syncplay_pin)")
    check "Syncplay $SYNCPLAY_TAG loads (Fedora's python3, Twisted with TLS, certifi, pem)" syncplay_runs
    check "syncplay runs without a window (--no-gui --version)" U timeout 20 "$TARGET_HOME/.local/bin/syncplay" --version ;;
  *) fail "Syncplay is not the pinned $SYNCPLAY_TAG with this toolkit's fixes" "update and repair put it in" ;;
esac
# LocalSend, its pinned release (setup carries on without it: update and repair fetch it)
localsend_libs_ok() {   # (ldd runs as you: the file is yours, and root never runs what is in your home)
  U test -x "$(localsend_dir)/localsend_app" && [[ -z $(missing_libs "$(localsend_dir)/localsend_app") ]]
}
case $(up_tag localsend) in
  "") warn "LocalSend not installed yet" "update and repair fetch it (sending to a phone waits till then)" ;;
  "$LOCALSEND_TAG")
    check "LocalSend $LOCALSEND_TAG finds every library it needs" \
      localsend_libs_ok
    check "localsend starts it (~/.local/bin/localsend)" test "$(readlink -f "$TARGET_HOME/.local/bin/localsend")" = "$(localsend_dir)/localsend_app" ;;
  *) fail "LocalSend is not the pinned $LOCALSEND_TAG" "update and repair put it in" ;;
esac
# ble.sh, from its pinned source (setup carries on without it: the shell is plain bash meanwhile)
case $(up_tag blesh) in
  "") warn "ble.sh not installed yet" "update and repair fetch it (till then the shell types without colours or suggestions)" ;;
  "$BLESH_COMMIT") check "ble.sh ${BLESH_COMMIT:0:7} loads (the shell's colours, suggestions and menus)" blesh_runs ;;
  *) fail "ble.sh is not the pinned ${BLESH_COMMIT:0:7}" "update and repair put it in" ;;
esac
for e in "${NERD_FONTS[@]}"; do
  f=${e%%|*}
  check "$f Nerd Font $NERD_FONTS_TAG"                 test "$(up_tag "nerd-$f")" = "$NERD_FONTS_TAG" -a -n "$(compgen -G "$(font_dir "$f")/*.[ot]tf")"
done
# (GE-Proton comes from GitHub, and setup carries on without it: Steam has its own Proton)
if [[ $STEAM == yes ]]; then
  if [[ -z $(up_tag ge-proton) ]]; then warn "GE-Proton not installed yet" "Steam's own Proton works meanwhile — update tries again"
  else check "GE-Proton $(up_tag ge-proton)" test -d "$(proton_dir)/$(up_tag ge-proton)"; fi
fi

# ── applications (do they actually start?) ──────────────────────────────────
section "applications"
# Brave, hidden (no screen needed), in a profile of its own: started is when its DevTools port
# answers — the browser process up and serving. (Not --dump-dom: Brave Origin's headless mode
# keeps running without ever carrying it out.) Its whole process group is ended after
check "Brave Origin starts (headless: its DevTools port answers)" \
  U bash -c 'd=$(mktemp -d); setsid brave-origin --headless --disable-gpu --user-data-dir="$d" --remote-debugging-port=0 about:blank >/dev/null 2>&1 & p=$! r=1
    for _ in $(seq 60); do
      if [[ -s $d/DevToolsActivePort ]]; then
        curl -s --max-time 5 "http://127.0.0.1:$(head -n1 "$d/DevToolsActivePort")/json/version" | grep -q "\"Browser\"" && r=0; break
      fi
      kill -0 "$p" 2>/dev/null || break; sleep 1
    done
    kill -- -"$p" 2>/dev/null; sleep 1; kill -9 -- -"$p" 2>/dev/null; rm -rf "$d"; exit $r'
check "Claude Code runs"                               U timeout 20 claude --version
# herdr (Agents), started as its launcher entry starts it — on a terminal of its own (a
# pseudo-terminal, 120×36: herdr refuses one of no size), from ~/repos, with your config —
# but in a home of its own for the two seconds, so it neither attaches to the agents you
# have running nor leaves a server behind: your config clean to herdr itself (no unknown
# key, no wrong type), ~/repos there, its server up in the folder it was started from, and
# the window's side attached to it
herdr_starts() {
  U bash -c 'd=$(mktemp -d /tmp/fk-herdr.XXXXXX) r=1
    mkdir -p "$d/.config/herdr" "$d/repos" && cp ~/.config/herdr/config.toml "$d/.config/herdr/" \
      && test -d ~/repos && HOME=$d herdr config check >/dev/null 2>&1 \
      && (cd "$d/repos" && HOME=$d TERM=xterm-256color timeout -k 2 15 python3 -I -c "
import fcntl, os, pty, select, signal, struct, termios, time
pid, fd = pty.fork()
if pid == 0:
    fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack(\"HHHH\", 36, 120, 0, 0))
    os.execvp(\"herdr\", [\"herdr\"])
end = time.monotonic() + 2
while time.monotonic() < end:
    if select.select([fd], [], [], 0.1)[0]:
        try: os.read(fd, 65536)
        except OSError: break
os.kill(pid, signal.SIGTERM); os.waitpid(pid, 0)" >/dev/null 2>&1 </dev/null; true) \
      && grep -q "endpoint handshake succeeded" "$d/.config/herdr/herdr-client.log" \
      && grep -qx ".*created startup workspace cwd=$d/repos" "$d/.config/herdr/herdr-server.log" && r=0
    HOME=$d herdr server stop >/dev/null 2>&1; rm -rf "$d"; exit $r'
}
# (its config and its launcher entry come with the theme)
((THEMED)) && check "herdr starts (Agents: your config clean, its server up in ~/repos, a window attached)" herdr_starts
check "LazyVim plugins installed"                      test -d "$TARGET_HOME/.local/share/nvim/lazy/LazyVim"
check "torrra $TORRRA_VERSION loads (Python 3.13, libtorrent, Textual)" U "$TARGET_HOME/.local/share/pipx/venvs/torrra/bin/python" -I -c 'import sys, importlib.metadata as m, torrra, libtorrent, torrra.app; assert sys.version_info[:2] == (3, 13) and m.version("torrra") == sys.argv[1]' "$TORRRA_VERSION"
check "torrra runs through kawa-torrra" U bash -c 'test -f /etc/profile.d/kawa-torrra.sh && kawa-torrra --version'
check "torrra uses Prowlarr, and no key in its config" bash -c 'grep -qx "default = \"prowlarr\"" "$1" && ! grep -q api_key "$1"' _ "$TARGET_HOME/.config/torrra/config.toml"
check "mpv in the bar and on the media keys (mpv-mpris)" test -f /etc/mpv/scripts/mpris.so
check "yt-dlp can answer YouTube's challenges (Node.js ≥ 20)" bash -c 'v=$(node --version 2>/dev/null) || exit 1; v=${v#v}; ((${v%%.*} >= 20))'
check "lazygit runs"                                   U lazygit --version
check "qalc runs"                                      U qalc -t 1+1
check "restic runs (backups to another disk: kawa-backup)" U restic version
[[ $STEAM == yes ]] && check "user in gamemode group"  bash -c "id -nG $TARGET_USER | grep -qw gamemode"

# ── snapshots ────────────────────────────────────────────────────────────────
if ((PRE == 0)); then
  section "snapshots"
  check "snapper config for /"                         test -f /etc/snapper/configs/root
  # (yours to delete when space runs short — the next move to a Fedora takes a new one)
  if [[ $(snapper -c root list 2>/dev/null) == *"fedokawaii baseline"* ]]; then pass "baseline snapshot exists"
  else warn "no baseline snapshot" "deleted? the next move to a new Fedora takes one; or now: sudo snapper -c root create -d \"fedokawaii baseline\""; fi
  check "pre/post snapshot around every dnf run"       test -x /usr/local/sbin/kawa-snap -a -f /etc/dnf/libdnf5-plugins/actions.d/fedokawaii-snapper.actions
  check "snapshots kept within bounds (a fifth of the disk stays free)" \
    bash -c 'snapper --csvout -c root get-config | grep -qE "^FREE_LIMIT,0\.2"'
  # the monthly scrub: on, and what the last one found (a disk going bad shows up here first)
  if [[ $(findmnt -no FSTYPE / 2>/dev/null) == btrfs ]]; then
    check "the monthly Btrfs scrub is on"              systemctl is-enabled --quiet fedokawaii-scrub.timer
    sc=$(btrfs scrub status / 2>/dev/null) || sc=""
    if [[ -z $sc || $sc == *"no stats available"* || $sc != *"Error summary"* ]]; then
      info "no scrub has run yet (the first comes within a month)"
    elif [[ $sc == *"no errors found"* ]]; then pass "the last scrub found no errors"
    else fail "the last scrub found errors" "$(grep -m1 'Error summary' <<<"$sc") — copy what you keep to another disk now, then: sudo btrfs device stats /"; fi
  fi
fi

# ── theme (only once applied) ────────────────────────────────────────────────
section "theme"
if ((THEMED == 0)); then
  info "not applied — menu → Theme when you want it (setup alone gives dwl with upstream defaults)"
else
  info "applied $(cat "$TARGET_HOME/.local/state/fedokawaii/theme-applied")"
  # (4: in sync, but the boot menu and console could not be made here — the theme run
  # carries on without them, so they are not what stops a finished setup)
  trc=0; tout=$(bash "$REPO_DIR/theme.sh" --user "$TARGET_USER" --check 2>&1) || trc=$?
  case $trc in
    0) pass "every file in sync with the repo" ;;
    4) pass "every file in sync with the repo"
       while IFS= read -r tl; do warn "${tl#"${tl%%[![:space:]]*}"}" "repair, or the next theme run, tries again"; done \
         < <(sed 's/\x1b\[[0-9;]*m//g' <<<"$tout" | sed -n '/not made here/,$p' | tail -n +2) ;;
    *) fail "every file in sync with the repo" "fedokawaii drift lists what differs; the theme run puts it back" ;;
  esac
  if grep -q 'vt.default_red=15,' /proc/cmdline; then pass "console palette active (the login console)"
  else info "console palette recorded for the kernel; it shows after the next boot"; fi
  check "dwl built from src/dwl/config.h"            cmp -s "$REPO_DIR/src/dwl/config.h" "$TARGET_HOME/.local/src/dwl/config.h"
  check "foot config valid"                            U foot --check-config
  check "fuzzel config valid"                          U fuzzel --check-config
  # every fuzzel option the menus use must exist in the installed fuzzel (≥ 1.14 for --mesg)
  fzhelp=$(U fuzzel --help 2>&1) fzbad=""
  for f in $(grep -oE 'args\+?=\([^)]*\)' "$REPO_DIR/bin/kawa-menu" | grep -o -- '--[a-z][a-z-]*' | sort -u); do
    grep -q -- "$f" <<<"$fzhelp" || fzbad+=" $f"
  done
  if [[ -n $fzhelp && -z $fzbad ]]; then pass "every fuzzel option the menus use exists"; else fail "fuzzel options" "${fzbad:-fuzzel missing}"; fi
  check "waybar config valid JSON"                     bash -c "grep -v '^[[:space:]]*//' $TARGET_HOME/.config/waybar/config.jsonc | jq -e ."
  # (a typo there stops udiskie, and with it every drive opening by itself)
  check "udiskie config valid YAML"                    U /usr/bin/python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$TARGET_HOME/.config/udiskie/config.yml"
  mode=$(readlink "$TARGET_HOME/.config/fedokawaii/current"); mode=${mode##*/}
  check "theme link → ${mode:-none} (dark or light)"   test -r "$TARGET_HOME/.config/fedokawaii/current/colors.sh"
  check "Qt palette has 3 × 21 colours"                awk -F, '/_colors=/{n++; if (NF!=21) bad=1} END{exit (n!=3 || bad)}' "$TARGET_HOME/.config/fedokawaii/current/qt6ct-colors.conf"
  check "GTK and the portal follow the theme (prefer-$mode)" grep -q "prefer-$mode" <<<"$(U gsettings get org.gnome.desktop.interface color-scheme 2>&1)"
  gtk=Fedokawaii; [[ $mode == dark ]] && gtk=Fedokawaii-dark
  check "GTK 3 theme $gtk (adw-gtk3 + the palette)"    grep -q "'$gtk'" <<<"$(U gsettings get org.gnome.desktop.interface gtk-theme 2>&1)"
  check "no window buttons in title bars (GTK, Brave)"  grep -qx "':'" <<<"$(U gsettings get org.gnome.desktop.wm.preferences button-layout 2>&1)"
  check "folders open in yazi, text in neovim"         test "$(U xdg-mime query default inode/directory) $(U xdg-mime query default text/plain)" = "kawa-files.desktop kawa-edit.desktop"
  check "links open in Brave Origin"                   test "$(U xdg-mime query default x-scheme-handler/https)" = brave-origin.desktop
  check "file dialogs → yazi (FileChooser: termfilechooser, the only one)" \
    grep -qx 'org.freedesktop.impl.portal.FileChooser=termfilechooser' "$TARGET_HOME/.config/xdg-desktop-portal/wlroots-portals.conf"
  check "the file dialog runs kawa-pick (executable)" \
    bash -c 'grep -qx "cmd=$1/.local/bin/kawa-pick" "$1/.config/xdg-desktop-portal-termfilechooser/config" && test -x "$1/.local/bin/kawa-pick"' _ "$TARGET_HOME"
  check "Brave starts with screen-share sound (launcher entry → ~/.local/bin/brave-origin)" \
    grep -q "^Exec=$TARGET_HOME/.local/bin/brave-origin" "$TARGET_HOME/.local/share/applications/brave-origin.desktop"
  if [[ -r /usr/share/applications/com.brave.Origin.desktop ]]; then   # (brave/brave-browser#52193)
    check "Brave listed once in the launcher (its second entry hidden)" \
      bash -c 'sed -n "/^\[Desktop Entry\]/,/^\[/p" "$1" | grep -qx NoDisplay=true' _ "$TARGET_HOME/.local/share/applications/com.brave.Origin.desktop"
  fi
  # set once by Theme; what you choose in Brave afterwards is yours, so only a note
  if jq -e '((.extensions.theme.id // "") != "" or .extensions.theme.system_theme == 1) and .brave.new_tab_page.background.type == "color"' \
       "$TARGET_HOME/.config/BraveSoftware/Brave-Origin/Default/Preferences" >/dev/null 2>&1; then
    pass "Brave in the desktop's colours (GTK mode, ground-coloured new tab)"
  else warn "Brave not in the desktop's colours" "your choice in Brave — or Settings → Appearance → Theme → GTK"; fi
  check "magnet links and .torrent files open in torrra" test "$(U xdg-mime query default x-scheme-handler/magnet) $(U xdg-mime query default application/x-bittorrent)" = "kawa-torrents.desktop kawa-torrents.desktop"
  check "GTK 3 themes find adw-gtk3"                   bash -c 'for t in "" -dark; do f=$(sed -n "s|.*url(\"file://\([^\"]*\)\").*|\1|p" "$1/Fedokawaii$t/gtk-3.0/gtk.css"); [[ -r $f ]] || exit 1; done' _ "$TARGET_HOME/.local/share/themes"
  check "monospace → JetBrainsMono Nerd Font"          grep -q JetBrainsMono <<<"$(U fc-match monospace 2>&1)"
  check "Arabic → Noto Naskh Arabic"                   grep -q Naskh <<<"$(U fc-match 'sans-serif:lang=ar' 2>&1)"
  check "Japanese / Chinese / Korean → Noto Sans CJK"  U bash -c 'for l in ja zh-cn ko; do [[ $(fc-match "sans-serif:lang=$l") == *"Noto Sans CJK"* ]] || exit 1; done'
  check "mpv: the theme's colours, players follow switches" test -r "$TARGET_HOME/.config/fedokawaii/current/mpv.conf" -a -f "$TARGET_HOME/.config/mpv/scripts/kawa-ipc.lua"
  # (the backup itself is not checked: its drive may not be plugged in — fedokawaii status says when the last one was)
  check "the backup's exclude list in place (kawa-backup)" test -s "$TARGET_HOME/.config/fedokawaii/backup-exclude"
  check "Syncplay plays in mpv (~/.config/syncplay.ini)" grep -q '^playerpath = .*mpv$' "$TARGET_HOME/.config/syncplay.ini"
  check "neovim colourscheme gruvbox (remapped)"       U sh -c 'timeout 60 nvim --headless "+lua io.write(vim.g.colors_name or \"\")" +qa 2>&1 | grep -q gruvbox'
  # both Sumi variants, each with its other names (left_ptr: a link that leads to a pointer),
  # and the default theme the one of the theme in use (kawa-theme keeps them together)
  check "Sumi pointers in place (both, with their X11 names; the default the theme's)" \
    bash -c 'for v in dark light; do [[ -s $1/Sumi-$v/cursors/default && -L $1/Sumi-$v/cursors/left_ptr && -s $1/Sumi-$v/cursors/left_ptr ]] || exit 1; done
             m=$(readlink "$2"); m=${m%/}; [[ ${m##*/} == light ]] && m=light || m=dark
             [[ $(readlink "$3") == "$1/Sumi-$m" ]]' _ /usr/share/icons "$TARGET_HOME/.config/fedokawaii/current" "$TARGET_HOME/.local/share/icons/default"
  check "desktop font → Fusion Pixel 12, crisp at 24 px (no smoothing)" grep -q '^Fusion Pixel 12px Mono ja False$' <<<"$(U fc-match -f '%{family} %{antialias}' 'Fusion Pixel 12px Mono ja:pixelsize=24' 2>&1)"
  check "pixel icons → Sumi Icons"                     grep -q 'Sumi Icons' <<<"$(U fc-match 'Sumi Icons' 2>&1)"
  check "pixel icons in the terminal → Sumi Icons Term"  grep -q 'Sumi Icons Term' <<<"$(U fc-match 'Sumi Icons Term' 2>&1)"
  # without a Wayland display it simply runs the command: proves it links (that it was built
  # from src/ the theme check above says)
  check "transitions (kawa-veil) runnable"             U env -u WAYLAND_DISPLAY "$TARGET_HOME/.local/bin/kawa-veil" -- true
  check "clipboard and wallpaper windows (fzf ≥ 0.68)" bash -c 'v=$(fzf --version 2>/dev/null) || exit 1; IFS=. read -r a b _ <<<"${v%% *}"; ((a > 0 || b >= 68))'
  check "wallpaper previews (ImageMagick draws sixels)" bash -c 'magick -size 2x2 xc:black sixel:- | grep -q "^.P"'
  art=$TARGET_HOME/.local/share/fedokawaii
  check "the lock screen's pictures, both themes (padlock, the seven seals)" \
    bash -c 'for t in dark light; do for f in padlock seal-{1..7}; do [[ -s $1/$t/$f.png ]] || exit 1; done; done' _ "$art"
  if [[ $WALLPAPER_PACK == yes ]]; then
    want=$(grep -cE '^(dark|light) ' "$art/wallpapers.list" 2>/dev/null || echo 0)
    have=$(find "$art/wallpapers" -name '*.src' 2>/dev/null | wc -l)
    if ((have >= want && want > 0)); then pass "wallpaper pack: $have pictures"
    else warn "wallpaper pack: $have of $want pictures fetched" "re-run Theme when online (kawa-wallpaper --pack)"; fi
    # drawn ahead for the monitor (a switch is then instant): complete, and none older than its picture
    if wc=$(U kawa-wallpaper --cache-status 2>&1); then pass "wallpaper cache: every pack picture drawn for the screen and current"
    else warn "wallpaper cache: $(grep -m1 -E 'not drawn yet|no monitor' <<<"$wc" | sed 's/^wallpaper cache: //')" "it is drawn in the background at the next login (or now: kawa-wallpaper --cache)"; fi
  fi
  check "music meter (cava) runs"                      U timeout 5 cava -v
  ((BOOT_SKIPPED)) || check "boot menu theme installed" bash -c 'test -s /boot/grub2/themes/sumi/theme.txt && grep -q grub2/themes/sumi/theme.txt /boot/grub2/grub.cfg'
  ((BOOT_SKIPPED)) || check "boot splash: the sumi theme (起動中 · starting Fedora)" bash -c '[[ $(plymouth-set-default-theme) == sumi ]] && test -s /usr/share/plymouth/themes/sumi/sumi.script'
  # (in every kernel's boot image, where Plymouth reads it — whatever the boot menu's part
  # did: a dracut that failed leaves images with Plymouth's text themes only. Repair: the
  # theme run makes them again)
  noimg=(); for v in "${kv[@]}"; do
    lsinitrd "/boot/initramfs-$v.img" 2>/dev/null | grep -q usr/share/plymouth/themes/sumi/sumi.script || noimg+=("$v")
  done
  if ((${#kv[@]} && ${#noimg[@]} == 0)); then pass "the splash in every boot image (lsinitrd)"
  else fail "the splash in every boot image (lsinitrd)" "not in $(IFS=' '; echo "${noimg[*]:-any}") — the boot shows text, not the splash; fedokawaii repair makes them again (dracut)"; fi
  # shellcheck disable=SC2088  # literal ~ in a label
  check "~/.bashrc loads ~/.bashrc.d"                  grep -q bashrc.d "$TARGET_HOME/.bashrc"
fi

# ── live session (only while you are logged in) ─────────────────────────────
if pgrep -u "$TARGET_UID" -x dwl >/dev/null; then
  section "live session"
  check "PipeWire + WirePlumber running steadily (no crash at start)" pw_steady
  # the portals behind file dialogs and screen sharing start only inside a graphical session
  check "graphical session known to systemd"           U systemctl --user is-active --quiet dwl-session.target graphical-session.target
  portal() { U busctl --user get-property org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop "$@" 2>/dev/null; }
  # (xdg-desktop-portal-wlr starts on demand, so at rest it is not running and the frontend's
  # answer can come before it does: started here and asked again for 3 s; stopped again after
  # when it was not running — its first share starts it the same way)
  xdpw_was=0; U systemctl --user is-active --quiet xdg-desktop-portal-wlr.service && xdpw_was=1
  U systemctl --user start xdg-desktop-portal-wlr.service 2>/dev/null
  fcv=$(portal org.freedesktop.portal.FileChooser version) scs=""
  for _ in $(seq 30); do scs=$(portal org.freedesktop.portal.ScreenCast AvailableSourceTypes); [[ $scs == "u 3" ]] && break; sleep 0.1; done
  ((xdpw_was)) || U systemctl --user stop --no-block xdg-desktop-portal-wlr.service 2>/dev/null
  check "file dialog portal (FileChooser ${fcv#u })"     bash -c '[[ $1 =~ ^u\ ([0-9]+)$ ]] && ((BASH_REMATCH[1] >= 3))' _ "$fcv"
  check "screen sharing portal: screens + windows"     test "$scs" = "u 3"
  # "Share" (~/.config/pipewire/pipewire.conf.d/60-share.conf) asked for by its node name, in
  # PipeWire's own list: a loopback's nodes share a node.link-group, and WirePlumber 0.5's
  # wpctl status lists such nodes under "Filters" by node.name ("share_sink"), never by their
  # description — grepping its output for "Share" failed with the output there
  check "\"Share\" output for calls (PipeWire node share_sink, an Audio/Sink; \"Monitor of Share\" is its microphone)" \
    jq -e 'any(.[]; .type == "PipeWire:Interface:Node" and .info.props["node.name"] == "share_sink"
                   and .info.props["media.class"] == "Audio/Sink")' <<<"$(U pw-dump 2>/dev/null)"   # (no PipeWire: no input, jq -e fails)
  if ((THEMED)); then
    for p in waybar kawa-panel mako foot swaybg swayidle udiskie kawa-dwlstatus kawa-nowplaying kawa-mem lxqt-policykit-agent; do
      check "$p running" pgrep -u "$TARGET_UID" -f "(^|/)$p( |$)"
    done
    # night light is yours to switch off (quick settings): off is not a fault
    if pgrep -u "$TARGET_UID" -x gammastep >/dev/null; then pass "night light running"
    else info "night light off (quick settings turns it on)"; fi
    WD=$(find "/run/user/$TARGET_UID" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -printf '%f\n' -quit)
    check "clipboard history running"                  pgrep -u "$TARGET_UID" -f 'wl-paste --watch kawa-clip --store'
    check "the drives watcher running (the bar's USB mark at once)" pgrep -u "$TARGET_UID" -f 'kawa-drives watch'
    check "the update season's reminder (timer) running" U systemctl --user is-active --quiet fedokawaii-remind.timer
    check "copies outlive their app (kawa-clipkeep)"   pgrep -u "$TARGET_UID" -x kawa-clipkeep
    IFS=' ' read -r cur best < <(U env WAYLAND_DISPLAY="$WD" wlr-randr | awk -v want="$MONITOR_HZ" '
      /^[^ ]/ { if (c) exit } /^    [0-9]+x[0-9]+ px/ { r[++n] = $1; hz[n] = $3 + 0; if ($0 ~ /current/) { c = $1; ch = $3 + 0 } }
      END { for (i = 1; i <= n; i++) if (r[i] == c && hz[i] <= want + 0.5 && hz[i] > b) b = hz[i]; printf "%d %d\n", ch + 0.5, b + 0.5 }')
    check "refresh ${cur:-?} Hz = best available ≤ $MONITOR_HZ" test "${cur:-0}" -ge "${best:-1}"
    check "mako config loads"                          U env WAYLAND_DISPLAY="$WD" makoctl reload
  fi
  # brightness over DDC/CI depends on the monitor having DDC/CI switched on in its own menu
  if [[ -n $(U ddcutil detect --terse 2>/dev/null | grep -m1 '^Display [0-9]') ]]; then
    pass "a monitor answers DDC/CI (brightness control works)"
  elif compgen -G '/sys/class/backlight/*' >/dev/null && grep -qsx connected /sys/class/drm/card*-eDP-*/status; then
    pass "the laptop's own screen: brightness through its backlight"
  else
    warn "no monitor answered DDC/CI" "switch DDC/CI on in the monitor's on-screen menu, then try Super+]"
  fi
fi

if ((${#FAILS[@]})); then
  if ((PRE)); then _out "  ${C_DIM}most of these fix themselves: fedokawaii repair — then run setup again${C_RESET}"
  else _out "  ${C_DIM}most of these fix themselves: fedokawaii repair${C_RESET}"; fi
fi
summary "verified"; rc=$?
((rc == 0)) || rc=3          # (3: it ran, and things need you — 1 is verify itself failing)
# the outcome, for the menu (Super+U) and repair: WHEN PASSED FAILED WARNINGS
((PRE)) || printf '%s %s %s %s\n' "$(date +%s)" "$PASS" "${#FAILS[@]}" "${#WARNS[@]}" \
  | write_file "$STATE_DIR/last-verify" 0644 || true
exit "$rc"
