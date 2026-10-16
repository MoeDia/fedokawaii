#!/usr/bin/env bash
# tests/installer/test_check.sh — check.sh, the readiness check setup runs first, on a fake fresh
# Fedora 44 Server (and 45): ready as the README's installer settings leave it (exit 0) — and each
# installer choice or machine state that would stop setup hours in named as ✘ (exit 1), what
# does not block as !, and misuse as exit 2. (Its GPU, laptop, Wi-Fi and boot lines: test_hardware.sh)
. "$(dirname "$0")/lib.sh"
C=/home/fkuser/fedokawaii/check.sh
chk() { fkrun bash "$C" "$@"; }
osr() { sed -i "s/^$1=.*/$1=$2/" "$W/etc/os-release"; }

world fresh
keep fresh

case_ "the machine as the README's installer settings leave it, with the shipped fedokawaii.conf: ready (exit 0)"
chk; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "✔ all values valid"; has "$OUT" "✔ Fedora 44 (supported)"; has "$OUT" "✔ Fedora Server edition"
has "$OUT" "✔ / is Btrfs"; has "$OUT" "✔ desktop user: fkuser"; has "$OUT" "✔ fkuser is an administrator (wheel)"
has "$OUT" "✔ reachable: codeberg.org"; has "$OUT" "✔ wlroots 0.20 in this Fedora"
has "$OUT" "✔ COPR ilyaz/LACT builds for Fedora 44"; lacks "$OUT" "dejan/lazygit" "lazygit is a release now, not a COPR"
has "$OUT" "READY for setup"; lacks "$OUT" "✘"
[[ -s $W/var/log/fedokawaii-check.log ]] && _ok || _no "no log"
not_called 'dnf\] -y|systemctl\] (enable|disable)|grubby\] --update'
case_ "misuse: an unknown option, not root (exit 2); --help (0)"
chk --frobnicate; eq "$RC" 2; has "$OUT" "unknown option"
fkrun runuser -u fkuser -- bash "$C"; eq "$RC" 2; has "$OUT" "run with sudo"
chk --help; eq "$RC" 0; has "$OUT" "is this machine ready for setup"

case_ "everything an installer or a machine can get wrong at once: each a ✘ line, not ready (exit 1)"
osr VERSION_ID 43; osr VARIANT_ID workstation
fkh_add installed gnome-shell firefox
fkh fstype-_ xfs; fkh df-free-gb 15
printf 'MemTotal:        3000000 kB\n' >"$W/proc/meminfo"
sed -i 's/^\(wheel:[^:]*:[^:]*:\).*/\1/' "$W/etc/group"
fkh selinux Permissive; fkh rc-check-upgrade 1; fkh no-route; fkh unreachable codeberg.org
fkh_del available wlroots-devel
chk; eq "$RC" 1
has "$OUT" "✘ Fedora 43 — too old"
has "$OUT" "! edition is 'workstation'"
has "$OUT" "✘ a desktop environment is installed — gnome-shell"
has "$OUT" "✘ installed, but the desktop has its own: firefox — sudo dnf remove firefox"
has "$OUT" "✘ / is xfs, not Btrfs"; has "$OUT" "✘ 15 GB free on / — needs at least 20 GB"
has "$OUT" "✘ 3 GB RAM — needs 4 GB+"; has "$OUT" "✘ fkuser is an administrator (wheel)"
has "$OUT" "✘ SELinux is permissive"; has "$OUT" "✘ could not query updates"
has "$OUT" "✘ no default route"; has "$OUT" "✘ unreachable: codeberg.org"
has "$OUT" "✘ wlroots 0.20 is not in Fedora 43"
has "$OUT" "NOT READY — fix the ✘ items above"
case_ "nano and vim, the rescue image, ffmpeg-free: setup takes those out itself — never a ✘"
back fresh; fkh_add installed ffmpeg-free vim-enhanced
chk; eq "$RC" 0; has "$OUT" "✔ nothing installed that the desktop replaces"

case_ "what does not block: a newer Fedora, 30 GB free, 6 GB RAM, the clock not synced, updates pending, a newer kernel, over SSH, no Bluetooth, wttr.in down"
back fresh; osr VERSION_ID 46; fkh df-free-gb 30
printf 'MemTotal:        6000000 kB\n' >"$W/proc/meminfo"
fkh ntp no; fkh rc-check-upgrade 100; fkh newest-kernel 6.19.9-200.fc44.x86_64
rm -rf "$W/sys/class/bluetooth"; fkh unreachable wttr.in
fkrun env SSH_CONNECTION="10.0.0.2 5000 10.0.0.1 22" bash "$C"; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "! Fedora 46 — newer than tested"; has "$OUT" "! 30 GB free on /"; has "$OUT" "! 6 GB RAM"
has "$OUT" "! clock not synchronised"; has "$OUT" "2 package updates pending"
has "$OUT" "! a newer kernel (6.19.9-200.fc44.x86_64) is installed but not running"
has "$OUT" "! running over SSH"; has "$OUT" "! no Bluetooth adapter seen"; has "$OUT" "! unreachable: wttr.in"
has "$OUT" "READY for setup"

case_ "a 4 GB machine (the kernel shows about 3.7 GiB): enough, with a note"
back fresh; printf 'MemTotal:        3880000 kB\n' >"$W/proc/meminfo"
chk; has "$OUT" "! 4 GB RAM — works; 8 GB+ recommended"

case_ "SELinux off; root logged in directly (no sudo, no USERNAME): each a ✘ saying what to do"
back fresh; fkh selinux Disabled
fkrun env -u SUDO_USER bash "$C"; eq "$RC" 1
has "$OUT" "✘ SELinux is Disabled — turn it back on"; has "$OUT" "✘ run through sudo from your own user"
case_ "a user whose ~/.bashrc does not read ~/.bashrc.d: a warning (theme.sh needs it)"
back fresh; echo "# mine" >"$W/home/fkuser/.bashrc"
chk; eq "$RC" 0; has "$OUT" "! ~/.bashrc does not load ~/.bashrc.d"

case_ "offline: the repositories cannot be asked — every host ✘, the wlroots question a warning"
back fresh; fkh net off
chk; eq "$RC" 1; has "$OUT" "✘ unreachable: mirrors.fedoraproject.org"; has "$OUT" "! could not ask the repositories for wlroots 0.20"
case_ "a wrong clock: every site's certificate refused — the clock named, not DNS or a firewall"
back fresh; fkh clock wrong
chk; eq "$RC" 1; has "$OUT" "✘ unreachable: mirrors.fedoraproject.org — its certificate is refused: the clock is wrong?"
has "$OUT" "timedatectl set-ntp true"; lacks "$OUT" "DNS, firewall or proxy?"
case_ "setup already started: said"
back fresh; echo 2 >"$W/var/lib/fedokawaii/phase"
chk; has "$OUT" "setup already started: phase 2"

case_ "a fresh Fedora 45 Server: supported, ready (exit 0)"
back fresh; fedora_release 45
chk; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "✔ Fedora 45 (supported)"; has "$OUT" "READY for setup"
case_ "where it runs: sudo's own pseudo-terminal is looked past (SUDO_TTY) — the console says nothing, SSH or a window warns"
fkrun env SUDO_TTY=/dev/pts/0 kmscon bash "$C"; eq "$RC" 0
lacks "$OUT" "running over SSH" "Fedora 45's console is kmscon's pseudo-terminal: the machine's own screen"
fkrun env SUDO_TTY=/dev/pts/3 bash "$C"; has "$OUT" "! running over SSH or in a terminal window (/dev/pts/3)"
back fresh; fkrun env SUDO_TTY=/dev/tty1 bash "$C"; lacks "$OUT" "running over SSH" "Fedora 44's console, /dev/tty1"
case_ "Rawhide: named as Fedora's development branch — a warning, not a stop"
back fresh; osr VERSION_ID 46; echo REDHAT_BUGZILLA_PRODUCT_VERSION=rawhide >>"$W/etc/os-release"
fkh copr-without "ilyaz/LACT fedora-46-x86_64"       # (until 46 branches off, COPR builds it as fedora-rawhide)
chk; eq "$RC" 0; has "$OUT" "! Fedora Rawhide (46) — Fedora's development branch"
has "$OUT" "✔ COPR ilyaz/LACT builds for Fedora 46" "Rawhide's COPR builds are fedora-rawhide"
case_ "a COPR not built for this release yet (a new Fedora's first days): a warning — setup leaves LACT out and adds it later"
back fresh; fedora_release 45; fkh copr-without "ilyaz/LACT fedora-45-x86_64"
chk; eq "$RC" 0 "a COPR that waits never stops the check"
has "$OUT" "! COPR ilyaz/LACT has nothing for Fedora 45 yet — setup leaves lact out; update or repair add it once it is built"
lacks "$OUT" "✘ COPR"
case_ "… COPR not answering: a warning, setup finds out itself"
back fresh; fkh unreachable copr.fedorainfracloud.org
chk; has "$OUT" "! could not ask COPR whether ilyaz/LACT builds for Fedora 44"

done_
