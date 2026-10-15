#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  check.sh — is this machine ready for setup? Read-only; changes nothing.
#
#    sudo bash check.sh
#
#  ✘ blocks setup · ! worth knowing, does not block · · information
#  setup.sh runs this automatically before phase 1 and stops on any ✘.
# ═════════════════════════════════════════════════════════════════════════════
set -uo pipefail
IFS=$'\n\t'
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo bash check.sh" >&2; exit 2; }
LOG_FILE=/var/log/fedokawai-check.log; : >"$LOG_FILE"
source "$REPO_DIR/lib/common.sh"
read_conf "$REPO_DIR/fedokawai.conf"
STATE_DIR=/var/lib/fedokawai

hdr "Fedokawai · readiness check"

# ── configuration ────────────────────────────────────────────────────────────
section "fedokawai.conf"
problems=$(conf_report)
if [[ -z $problems ]]; then pass "all values valid"
else while IFS= read -r p; do fail "$p"; done <<<"$problems"; fi

# ── platform ─────────────────────────────────────────────────────────────────
section "platform"
# shellcheck disable=SC1091
source /etc/os-release
check "x86_64 CPU ($(uname -m))"                   test "$(uname -m)" = x86_64
if [[ ${ID:-} != fedora ]]; then fail "Fedora Linux" "this is ${PRETTY_NAME:-unknown}"
elif ((VERSION_ID < 44)); then fail "Fedora $VERSION_ID" "too old — needs 44 or 45 (dnf5, wlroots 0.20). Upgrade or reinstall"
elif ((VERSION_ID > 45)); then warn "Fedora $VERSION_ID" "newer than tested (44/45); check DWL_TAG matches its wlroots"
else pass "Fedora $VERSION_ID (supported)"; fi
if [[ ${VARIANT_ID:-} == server ]]; then pass "Fedora Server edition"
else warn "edition is '${VARIANT_ID:-none}'" "built for Server minimal; other editions may carry a desktop already"; fi
check "dnf5 is the package manager"                bash -c 'dnf --version 2>&1 | grep -q "dnf5"'

desk=$(rpm -q gnome-shell plasma-workspace gdm sddm lightdm xfce4-session cinnamon 2>/dev/null | grep -v 'not installed' | tr '\n' ' ')
if [[ -z $desk ]]; then pass "minimal install (no desktop environment present)"
else fail "a desktop environment is installed" "$desk— reinstall choosing Minimal Install"; fi
# what the build's gate would refuse hours in (one tool per job) — said now, with the command;
# the editors, the rescue image and ffmpeg-free setup removes or swaps itself
# shellcheck source=lib/manifest.sh
source "$REPO_DIR/lib/manifest.sh"
present=()
skip=" $(IFS=' '; echo "${PKG_REMOVE[*]}") ffmpeg-free "   # (space-joined: IFS here is newline)
for p in "${FORBIDDEN_PKGS[@]}"; do
  [[ $skip == *" $p "* ]] && continue
  if rpm -q "$p" >/dev/null 2>&1; then present+=("$p"); fi
done
if ((${#present[@]} == 0)); then pass "nothing installed that the desktop replaces"
else
  p=$(IFS=' '; echo "${present[*]}")
  fail "installed, but the desktop has its own: $p" "sudo dnf remove $p"
fi
if [[ -d /sys/firmware/efi ]]; then
  sb=$(od -An -tu1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | tr -d ' ')
  info "UEFI boot · Secure Boot ${sb:+$([[ $sb == 1 ]] && echo on || echo off)} (both fine: Fedora's kernel and amdgpu are signed)"
else
  info "legacy BIOS boot (fine)"
fi

# ── storage: the installer choices that matter ───────────────────────────────
section "storage (installer choices)"
fstype=$(findmnt -no FSTYPE /); opts=$(findmnt -no OPTIONS /)
if [[ $fstype == btrfs ]]; then pass "/ is Btrfs"
else fail "/ is $fstype, not Btrfs" "reinstall: Installation Destination → Custom → Btrfs → create automatically"; fi
if [[ $opts == *subvol=/root* || $opts == *subvol=root* ]]; then pass "Fedora subvolume layout (root)"
elif [[ $fstype == btrfs ]]; then warn "unusual root subvolume" "$(grep -o 'subvol=[^,]*' <<<"$opts")"; fi
[[ $opts == *compress=zstd* ]] && pass "transparent zstd compression on /" || info "no compression on / (Fedora's default is zstd:1)"
if [[ $(findmnt -no FSTYPE /home) == btrfs ]]; then pass "/home on Btrfs (snapshots cover it)"; else info "/home is not a separate Btrfs subvolume"; fi
[[ $(findmnt -no FSTYPE /boot) == ext4 ]] && pass "/boot is a separate ext4 partition" || info "/boot layout: $(findmnt -no FSTYPE /boot 2>/dev/null || echo 'inside /')"
lsblk -no TYPE | grep -qx crypt && info "disk encryption (LUKS) on — you'll type the passphrase at every boot" || info "no disk encryption"
free_gb=$(df -BG --output=avail / | tail -1 | tr -dc 0-9)
if ((free_gb >= 40)); then pass "${free_gb} GB free on /"
elif ((free_gb >= 20)); then warn "${free_gb} GB free on /" "enough to build; games need much more"
else fail "${free_gb} GB free on /" "needs at least 20 GB"; fi

# ── memory ───────────────────────────────────────────────────────────────────
section "memory"
# (MemTotal is a little under the RAM fitted — firmware and the kernel keep some — so a
# "4 GB" machine shows about 3.7 GiB: compared in MiB with that margin)
mem_mb=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 )); mem_gb=$(( (mem_mb + 512) / 1024 ))
if ((mem_mb >= 7168)); then pass "${mem_gb} GB RAM"; elif ((mem_mb >= 3584)); then warn "${mem_gb} GB RAM" "works; 8 GB+ recommended"; else fail "${mem_gb} GB RAM" "needs 4 GB+"; fi
swapon --show=NAME --noheadings 2>/dev/null | grep -q zram && pass "zram swap active (Fedora default)" || info "no zram swap"

# ── user & security ──────────────────────────────────────────────────────────
section "user & security"
user=${USERNAME:-${SUDO_USER:-}}
if [[ -z $user || $user == root ]]; then fail "run through sudo from your own user" "e.g. sudo bash check.sh, not as root directly"
elif ! id "$user" >/dev/null 2>&1; then fail "user $user does not exist"
else
  pass "desktop user: $user"
  check "$user is an administrator (wheel)"       bash -c "id -nG $user | tr ' ' '\n' | grep -qx wheel"
  home=$(getent passwd "$user" | cut -d: -f6)
  check "home directory $home exists"             test -d "$home"
  # shellcheck disable=SC2088  # literal ~ in labels
  if grep -q bashrc.d "$home/.bashrc" 2>/dev/null; then pass "~/.bashrc loads ~/.bashrc.d (Fedora default)"
  else warn "~/.bashrc does not load ~/.bashrc.d" "theme.sh needs it: cp /etc/skel/.bashrc ~/"; fi
fi
sel=$(getenforce 2>/dev/null)
if [[ $sel == Enforcing ]]; then pass "SELinux enforcing"
elif [[ $sel == Permissive ]]; then fail "SELinux is permissive" "set SELINUX=enforcing in /etc/selinux/config, then reboot"
else fail "SELinux is ${sel:-unavailable}" "turn it back on: sudo grubby --update-kernel ALL --remove-args selinux; sudo fixfiles -F onboot; reboot"; fi
[[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null) == yes ]] && pass "clock synchronised (NTP)" \
  || warn "clock not synchronised" "TLS downloads can fail with a wrong clock: timedatectl set-ntp true"
[[ -n ${SSH_CONNECTION:-} ]] && warn "running over SSH" "setup reboots and continues on the machine's own screen (tty1)"
[[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]] && warn "running inside a graphical session" "run from the text console"

# ── updates & reboots ────────────────────────────────────────────────────────
section "updates"
upd=$(dnf -q check-upgrade --refresh 2>/dev/null); rc=$?
case $rc in
  0)   pass "system is fully up to date" ;;
  100) n=$(grep -c '\S' <<<"$upd"); info "$n package updates pending — setup installs them first (phase 1)" ;;
  *)   fail "could not query updates" "dnf check-upgrade exited $rc (network or repo problem?)" ;;
esac
newest=$(rpm -q --last kernel-core 2>/dev/null); newest=${newest%%$'\n'*}; newest=${newest%% *}; newest=${newest#kernel-core-}
if [[ -z $newest ]]; then fail "could not read the installed kernels (rpm)"
elif [[ $newest != "$(uname -r)" ]]; then warn "a newer kernel ($newest) is installed but not running" "reboot before setup"
else pass "running the newest installed kernel ($(uname -r))"; fi
if [[ -f $STATE_DIR/phase ]]; then info "setup already started: phase $(<"$STATE_DIR/phase")"; fi

# ── network: every source the build downloads from ───────────────────────────
section "network"
if ip route show default 2>/dev/null | grep -q .; then pass "default route ($(ip route show default | awk '{print $5; exit}'))"
else fail "no default route" "connect ethernet (nmtui)"; fi
reachable() {   # reachable HOST — any HTTP answer at all counts
  [[ $(curl -sS -o /dev/null -w '%{http_code}' --proto '=https' --connect-timeout 10 --max-time 20 "https://$1/" 2>/dev/null) =~ ^[1-5][0-9][0-9]$ ]]
}
for h in mirrors.fedoraproject.org mirrors.rpmfusion.org copr.fedorainfracloud.org \
         brave-browser-rpm-release.s3.brave.com downloads.claude.ai codeberg.org \
         api.github.com github.com release-assets.githubusercontent.com raw.githubusercontent.com \
         lscr.io ghcr.io pypi.org files.pythonhosted.org; do
  if reachable "$h"; then pass "reachable: $h"; else fail "unreachable: $h" "DNS, firewall or proxy?"; fi
done
# the weather line is a nicety, not part of the build: it may be down without stopping setup
if reachable wttr.in; then pass "reachable: wttr.in (weather)"; else warn "unreachable: wttr.in" "quick settings shows the city without the weather until it answers"; fi
# the one thing a later Fedora can lack that ends setup hours in: dwl's wlroots (a machine
# that already keeps its own copy needs nothing from this Fedora)
if [[ -f /usr/local/lib/fedokawai-wlroots-$DWL_WLROOTS/cflags ]]; then
  pass "wlroots $DWL_WLROOTS: dwl's own copy is kept"
elif w=$(dnf -q repoquery --whatprovides "pkgconfig(wlroots-$DWL_WLROOTS)" --qf '%{name}-%{version}\n' 2>/dev/null); then
  if [[ -n $w ]]; then pass "wlroots $DWL_WLROOTS in this Fedora ($(head -n1 <<<"$w")) — dwl $DWL_TAG builds"
  else fail "wlroots $DWL_WLROOTS is not in Fedora $VERSION_ID" "dwl $DWL_TAG needs it: install Fedora 44 or 45, then move up with fedokawai upgrade"; fi
else warn "could not ask the repositories for wlroots $DWL_WLROOTS" "offline? setup checks again when it builds dwl"; fi

# ── hardware ─────────────────────────────────────────────────────────────────
section "hardware"
gpus=""
for d in /sys/class/drm/card[0-9]*/device; do
  [[ -r $d/vendor ]] || continue
  case $(<"$d/vendor") in
    0x1002) gpus+="amd:$(basename "$(readlink -f "$d/driver" 2>/dev/null)") " ;;
    0x8086) gpus+="intel:$(basename "$(readlink -f "$d/driver" 2>/dev/null)") " ;;
    0x10de) gpus+="nvidia " ;;
  esac
done
case $gpus in
  *amd:amdgpu*) pass "AMD GPU on the amdgpu driver" ;;
  *amd:*)       fail "AMD GPU found but amdgpu is not driving it" "$gpus" ;;
  *intel:*)     pass "Intel GPU (${gpus% })" ;;
  *nvidia*)     fail "NVIDIA only" "this build targets AMD/Intel (open drivers)" ;;
  *)            fail "no GPU detected" "set GPU= in fedokawai.conf if this is wrong" ;;
esac
[[ $GPU != auto && $gpus != *"$GPU:"* ]] && warn "GPU=$GPU in fedokawai.conf" "but detected: ${gpus:-none}"
ls /sys/class/bluetooth/hci* >/dev/null 2>&1 && pass "Bluetooth adapter present" || warn "no Bluetooth adapter seen" "plug the dongle in before setup"
nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q '^ethernet:connected' && pass "ethernet connected" || info "not on ethernet (Wi-Fi works too)"

# ── verdict ──────────────────────────────────────────────────────────────────
if summary "READY for setup"; then exit 0; fi
_out "${C_RED}NOT READY — fix the ✘ items above, then run the check again.${C_RESET}"
exit 1
