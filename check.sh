#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  check.sh — is this machine ready for setup? Read-only; changes nothing.
#
#    sudo bash check.sh
#
#  ✘ blocks setup · ! worth knowing, does not block · · information
#  setup.sh runs this automatically before phase 1 and stops on any ✘.
#  Exit: 0 ready · 1 not ready (the ✘ lines say why) · 2 misuse (not root)
# ═════════════════════════════════════════════════════════════════════════════
set -uo pipefail
IFS=$'\n\t'
export LC_ALL=C.UTF-8      # every tool's output in one language and format, whatever yours is
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
for a in "$@"; do
  case $a in
    -h|--help) sed -n '3,/^# ═/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $a (bash check.sh --help)" >&2; exit 2 ;;
  esac
done
[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo bash check.sh" >&2; exit 2; }
LOG_FILE=/var/log/fedokawaii-check.log; : >"$LOG_FILE"
source "$REPO_DIR/lib/common.sh"
read_conf "$REPO_DIR/fedokawaii.conf"
STATE_DIR=/var/lib/fedokawaii

hdr "Fedokawaii · readiness check"

# ── configuration ────────────────────────────────────────────────────────────
section "fedokawaii.conf"
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
elif [[ ${REDHAT_BUGZILLA_PRODUCT_VERSION:-} == rawhide ]]; then warn "Fedora Rawhide ($VERSION_ID)" "Fedora's development branch, changing every day — tested on the releases 44 and 45"
elif ((VERSION_ID > 45)); then warn "Fedora $VERSION_ID" "newer than tested (44/45): setup can build dwl only if this release has its wlroots (network, below)"
else pass "Fedora $VERSION_ID (supported)"; fi
# the starting point: the installer's Custom Operating System (Fedora's core, no edition named:
# os-release has no VARIANT_ID — what the handbook picks) or Server's Minimal Install. Any other
# edition is a desktop edition, which brings a desktop of its own
case ${VARIANT_ID:-} in
  "")     pass "Fedora's minimal base (Custom Operating System, no edition)" ;;
  server) pass "Fedora Server edition (Minimal Install)" ;;
  *)      warn "edition is '$VARIANT_ID'" "built for a minimal install (Custom Operating System, or Server's Minimal Install); a desktop edition brings a desktop of its own" ;;
esac
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
  case $sb in 1) sb=on ;; 0) sb=off ;; *) sb="state unknown" ;; esac
  info "UEFI boot · Secure Boot $sb (either is fine: Fedora's kernel and its drivers are signed)"
else
  info "legacy BIOS boot (fine)"
fi

# ── storage: the installer choices that matter ───────────────────────────────
section "storage (installer choices)"
fstype=$(findmnt -no FSTYPE /); rootopts=$(findmnt -no OPTIONS /)
if [[ $fstype == btrfs ]]; then pass "/ is Btrfs"
else fail "/ is $fstype, not Btrfs" "reinstall: Installation Destination → Custom → Btrfs → create automatically"; fi
if [[ $rootopts == *subvol=/root* || $rootopts == *subvol=root* ]]; then pass "Fedora subvolume layout (root)"
elif [[ $fstype == btrfs ]]; then warn "unusual root subvolume" "$(grep -o 'subvol=[^,]*' <<<"$rootopts")"; fi
[[ $rootopts == *compress=zstd* ]] && pass "transparent zstd compression on /" || info "no compression on / (Fedora's default is zstd:1)"
if [[ $(findmnt -no FSTYPE /home) == btrfs ]]; then pass "/home on Btrfs (snapshots cover it)"; else info "/home is not a separate Btrfs subvolume"; fi
[[ $(findmnt -no FSTYPE /boot) == ext4 ]] && pass "/boot is a separate ext4 partition" || info "/boot layout: $(findmnt -no FSTYPE /boot 2>/dev/null || echo 'inside /')"
grep -qx crypt < <(lsblk -no TYPE) && info "disk encryption (LUKS) on — you'll type the passphrase at every boot" || info "no disk encryption"
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
grep -q zram < <(swapon --show=NAME --noheadings 2>/dev/null) && pass "zram swap active (Fedora default)" || info "no zram swap"

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
# (sudo drops SSH_CONNECTION and WAYLAND_DISPLAY from the environment: the terminal tells —
# a pseudo-terminal is SSH or a terminal window, the machine's own console is a /dev/ttyN.
# sudo may run the command in a pseudo-terminal of its own (its default since 1.9.14):
# SUDO_TTY (sudo 1.9.17 on) names the one you typed in.
# Fedora 45's consoles are pseudo-terminals too, of kmscon, which draws them: it is up the
# line of this run's parent processes, before any dwl or foot)
on_kmscon() {
  local p=$PPID n c
  for ((n = 0; n < 40 && p > 1; n++)); do
    c=$(cat "/proc/$p/comm" 2>/dev/null) || return 1
    case $c in kmscon) return 0 ;; dwl*|foot) return 1 ;; esac
    p=$(sed -n 's/^PPid:[[:space:]]*//p' "/proc/$p/status" 2>/dev/null)
    [[ $p =~ ^[0-9]+$ ]] || return 1
  done
  return 1
}
tty_now=${SUDO_TTY:-$(tty 2>/dev/null)} || tty_now=""
if [[ -n ${SSH_CONNECTION:-} ]] || { [[ $tty_now == /dev/pts/* ]] && ! on_kmscon; }; then
  warn "running over SSH or in a terminal window (${tty_now:-SSH})" "setup reboots and continues on the machine's own screen (tty1)"
fi
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
if grep -q . < <(ip route show default 2>/dev/null); then pass "default route ($(ip route show default | awk '{print $5; exit}'))"
else fail "no default route" "connect ethernet (nmtui)"; fi
reachable() {   # reachable HOST — any HTTP answer at all counts (CURL_RC: curl's own status)
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' --proto '=https' --connect-timeout 10 --max-time 20 "https://$1/" 2>/dev/null); CURL_RC=$?
  [[ $code =~ ^[1-5][0-9][0-9]$ ]]
}
CURL_RC=0
for h in mirrors.fedoraproject.org download1.rpmfusion.org copr.fedorainfracloud.org \
         brave-browser-rpm-release.s3.brave.com downloads.claude.ai codeberg.org \
         api.github.com github.com release-assets.githubusercontent.com raw.githubusercontent.com \
         lscr.io ghcr.io pypi.org files.pythonhosted.org; do
  if reachable "$h"; then pass "reachable: $h"
  # (60: the site answered, its certificate was refused — a clock years off does that to every site)
  elif ((CURL_RC == 60)); then fail "unreachable: $h" "its certificate is refused: the clock is wrong? ($(date '+%F %H:%M') — timedatectl set-ntp true)"
  else fail "unreachable: $h" "DNS, firewall or proxy?"; fi
done
# the weather is a nicety, not part of the build: it may be down without stopping setup
if reachable api.open-meteo.com; then pass "reachable: api.open-meteo.com (weather)"; else warn "unreachable: api.open-meteo.com" "the bar shows no weather until it answers"; fi
# the one thing a later Fedora can lack that ends setup hours in: dwl's wlroots (a machine
# that already keeps its own copy needs nothing from this Fedora)
if [[ -f /usr/local/lib/fedokawaii-wlroots-$DWL_WLROOTS/cflags ]]; then
  pass "wlroots $DWL_WLROOTS: dwl's own copy is kept"
elif w=$(dnf -q repoquery --whatprovides "pkgconfig(wlroots-$DWL_WLROOTS)" --qf '%{name}-%{version}\n' 2>/dev/null); then
  if [[ -n $w ]]; then pass "wlroots $DWL_WLROOTS in this Fedora ($(head -n1 <<<"$w")) — dwl $DWL_TAG builds"
  else fail "wlroots $DWL_WLROOTS is not in Fedora $VERSION_ID" "dwl $DWL_TAG needs it: install Fedora 44 or 45, then move up with fedokawaii upgrade"; fi
else warn "could not ask the repositories for wlroots $DWL_WLROOTS" "offline? setup checks again when it builds dwl"; fi
# …and the COPR (LACT): one not built for this release yet — a new Fedora's first days — is
# only a warning: setup leaves its packages out, and update or repair add them once it is built
ch=fedora-$VERSION_ID-x86_64; [[ ${REDHAT_BUGZILLA_PRODUCT_VERSION:-} == rawhide ]] && ch=fedora-rawhide-x86_64
re="\"$ch\"[[:space:]]*:"
for c in "${COPRS[@]}"; do
  j=$(curl -fsS --proto '=https' --connect-timeout 10 --max-time 20 \
        "https://copr.fedorainfracloud.org/api_3/project?ownername=${c%%/*}&projectname=${c#*/}" 2>/dev/null) || j=""
  if [[ $j != *'"chroot_repos"'* ]]; then warn "could not ask COPR whether $c builds for Fedora $VERSION_ID" "setup finds out in phase 2"
  elif [[ $j =~ $re ]]; then pass "COPR $c builds for Fedora $VERSION_ID"
  else warn "COPR $c has nothing for Fedora $VERSION_ID yet" "setup leaves $(copr_pkgs "$c" | tr '\n' ' ')out; update or repair add it once it is built"; fi
done

# ── hardware ─────────────────────────────────────────────────────────────────
section "hardware"
# shellcheck source=lib/hardware.sh
source "$REPO_DIR/lib/hardware.sh"
gpus=""      # (each card with the driver holding it, for the messages)
for d in /sys/class/drm/card[0-9]*/device; do
  [[ -r $d/vendor ]] || continue
  gpus+="$(<"$d/vendor"):$(basename "$(readlink -f "$d/driver" 2>/dev/null)") "
done
case $(hw_gpu) in
  amd)    if [[ $gpus == *0x1002:amdgpu* ]]; then pass "AMD GPU on the amdgpu driver"
          else fail "AMD GPU found but amdgpu is not driving it" "${gpus% }"; fi ;;
  intel)  pass "Intel GPU (${gpus% })" ;;
  nvidia) fail "NVIDIA only" "this build targets AMD/Intel (open drivers)" ;;
  vm)     fail "a virtual machine's display (${gpus% })" "the desktop needs an AMD or Intel GPU: setup's last check (hardware video decoding) cannot pass here" ;;
  *)      # no card the kernel drives: one too new for this kernel is named in fedokawaii.conf
          if [[ $GPU != auto ]]; then warn "no GPU seen by the kernel" "GPU=$GPU in fedokawaii.conf: setup installs its drivers"
          else fail "no AMD or Intel GPU seen by the kernel" "a card too new for this kernel: set GPU= in fedokawaii.conf"; fi ;;
esac
[[ $GPU != auto && $(hw_gpu) != none && $(hw_gpu) != "$GPU" ]] && warn "GPU=$GPU in fedokawaii.conf" "but this machine's card is $(hw_gpu)"
# the tuning is a desktop's (setup: s_tuning) — on a battery it costs hours
hw_is_laptop && warn "a laptop" "setup tunes for an always-plugged desktop (full CPU speed, Wi-Fi never napping): the battery runs down faster"
ls /sys/class/bluetooth/hci* >/dev/null 2>&1 && pass "Bluetooth adapter present" || warn "no Bluetooth adapter seen" "plug the dongle in before setup"
# what setup will add for this hardware (lib/hardware.sh) — said now, nothing installed yet
case $(hw_cpu_vendor) in
  GenuineIntel) info "Intel CPU — setup adds its microcode (microcode_ctl)" ;;
  AuthenticAMD) info "AMD CPU — setup adds its microcode (amd-ucode-firmware)" ;;
esac
hw_has_wifi && info "a Wi-Fi radio — setup adds NetworkManager's Wi-Fi part (wired is still the better start)"
hw_has_sof && info "Intel's audio DSP drives the sound card — setup adds its firmware (alsa-sof-firmware)"
fwmiss=$(hw_missing_firmware | tr '\n' ' ')
[[ -z ${fwmiss// /} ]] || info "the kernel asked for firmware it did not find: ${fwmiss}— setup installs what provides it"
nodrv=$(hw_driverless | tr '\n' ';')
[[ -z $nodrv ]] && pass "every network, display, sound and USB device has a driver" \
  || warn "devices no driver holds" "${nodrv} — lspci -nnk names them; such a device will not work here"
grep -q '^ethernet:connected' < <(nmcli -t -f TYPE,STATE device 2>/dev/null) && pass "ethernet connected" || info "not on ethernet (Wi-Fi works too)"

# ── verdict ──────────────────────────────────────────────────────────────────
if summary "READY for setup"; then exit 0; fi
_out "${C_RED}NOT READY — fix the ✘ items above, then run the check again.${C_RESET}"
exit 1
