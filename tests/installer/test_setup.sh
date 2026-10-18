#!/usr/bin/env bash
# tests/installer/test_setup.sh — setup.sh from a fresh Fedora 44 Server (Minimal Install) to the
# finished desktop in the fake machine: phase 1 → reboot → 2 → reboot → 3, the resume unit that
# carries it across restarts (and keeps greetd off tty1 meanwhile), a run stopped half-way and
# started again (a power cut mid-phase: duplicates tidied at the gate), the state files missing
# or damaged, the verify gate and repair before the login exists, misuse, --status, --reset.
# (Hardware and network cases: test_setup_hw.sh)
. "$(dirname "$0")/lib.sh"
CLONE=/home/fkuser/fedokawaii
TK=/usr/local/lib/fedokawaii
setup() { fkrun bash "$CLONE/setup.sh" "$@"; }          # as you start it: from your clone, with sudo
resume() { fkrun bash "$TK/setup.sh" --resume "$@"; }   # as the resume unit starts it after a restart

world fresh; releases
unit=$W/etc/systemd/system/fedokawaii-resume.service
keep fresh

# ── the whole build ──────────────────────────────────────────────────────────
case_ "phase 1: the check, then each step; then the resume unit, the toolkit, and a restart"
fkh_add installed systemd-oomd-defaults        # (not in a Minimal Install: as if a desktop group had brought it)
setup; eq "$RC" 0 "exit"
has "$OUT" "READY for setup"; has "$OUT" "✔ 1.7 inbound SSH (no)"
eq "$(state phase)" 2; eq "$(state user)" fkuser
[[ -f $unit ]] && _ok || _no "no resume unit"
has "$(cat "$unit")" "ExecStart=/usr/bin/bash $TK/setup.sh --resume"
has "$(cat "$unit")" "Conflicts=getty@tty1.service kmsconvt@tty1.service greetd.service" "greetd held off tty1 while setup resumes"
has "$(cat "$unit")" "TTYPath=/dev/tty1"
called 'systemctl\] enable fedokawaii-resume.service'
[[ -f $W$TK/setup.sh && -x $W/usr/local/bin/fedokawaii ]] && _ok || _no "the toolkit and its command not installed"
eq "$(fk stat -c %U "$TK/setup.sh")" root "the toolkit is root's"
called 'systemctl\] reboot'
pkg_has tar && pkg_has grubby && pkg_has diffutils && pkg_has man-db && _ok || _no "the base tools (tar, grubby, diffutils, man-db) not installed"
pkg_has nano && _no "nano still there" || _ok
pkg_has systemd-oomd-defaults && _no "systemd-oomd-defaults still there (its kill would take the whole session)" || _ok
eq "$(grep -v '^#' "$W/etc/modprobe.d/fedokawaii-btusb.conf" 2>/dev/null)" "options btusb enable_autosuspend=0" "the Bluetooth dongle never sleeps"
eq "$(grep -v '^#' "$W/etc/systemd/logind.conf.d/90-fedokawaii.conf" 2>/dev/null | tr '\n' ' ')" "[Login] HandleSuspendKey=ignore HandleSuspendKeyLongPress=ignore InhibitDelayMaxSec=15 " "the Sleep key left to dwl (locked first), any sleep waiting for the lock"
# (Node 22, which neovim brings through tree-sitter-cli's recommendation, never taken as a weak
# dependency — set before the first install, and dnf reads it back so)
has "$(cat "$W/etc/dnf/libdnf5.conf.d/90-fedokawaii.conf")" "exclude_from_weak=nodejs,nodejs22*,PackageKit,java-*-openjdk-headless,libreoffice-help-*"
lacks "$OUT" "dnf shows exclude_from_weak"
# (dnf's metadata timer, static on Fedora 44: masked — `disable` cannot turn a static unit off)
grep -qx "masked dnf5-makecache.timer" "$FKH/units" && _ok || _no "dnf5-makecache.timer not masked"
not_called 'systemctl\] disable --now dnf5-makecache'
eq "$(cat "$FKH/hostname" 2>/dev/null)" fedokawaii "a machine with no name gets one"
eq "$(cat "$FKH/timezone" 2>/dev/null)" "Asia/Dubai"
has "$(cat "$W/etc/dnf/libdnf5.conf.d/90-fedokawaii.conf")" "max_parallel_downloads=10"
has "$(cat "$FKH/grubenv")" "menu_auto_hide=1" "one system: Fedora's hidden menu"
has "$(head -n1 "$FKH/grub-args")" "systemd.tty.term.console=dumb" "no console-size wait at boot (every entry)"
eq "$(grep -c systemd.tty.term.console=dumb "$FKH/grub-args")" 2
lacks "$(cat "$FKH/fw-services")" "ssh" "SSH_SERVER=no closes ssh in the firewall"
not_called 'firewall-cmd\] .*--reload' "the firewall is changed in place, never reloaded (a reload drops other programs' rules)"
grep -qx 'enabled sshd.service' "$FKH/units" && _no "sshd still enabled" || _ok
reboot_world; keep phase2

case_ "phase 2 (resumed by the unit after the restart): repositories, the GPU's drivers, media"
resume --no-reboot; eq "$RC" 0
eq "$(state phase)" 3; eq "$(state gpu)" amd
for p in rpmfusion-free-release rpmfusion-nonfree-release mesa-va-drivers-freeworld mesa-vulkan-drivers lact rocm-smi ffmpeg mpv amd-ucode-firmware; do
  pkg_has "$p" || _no "$p not installed"
done; _ok
pkg_has mesa-vulkan-drivers-freeworld && _no "RPM Fusion's Vulkan driver installed" || _ok
has "$(head -n1 "$FKH/grub-args")" "amdgpu.ppfeaturemask=0xfff7ffff"
called 'dracut\] -f --regenerate-all'
eq "$(state hardware-pkgs)" amd-ucode-firmware
reboot_world; keep phase3

case_ "phase 3: dwl and the desktop, the gate, then the login enabled last and the resume unit gone"
# (GitHub refusing GE-Proton's release list once, the file dialog's first build failing, and
# LazyVim's plugin clones failing the first time: none stops the build, the gate tries again)
fkh fail-curl-ge-api 1; fkh fail-meson 1; fkh fail-nvim-plugins 1
# (garbage the end sweeps: the download the clone was unpacked from, twelve theme runs' backups)
B=$W/home/fkuser/.local/state/fedokawaii/backup
for i in $(seq -w 1 12); do mkdir -p "$B/202601${i}-120000"; done; mkdir -p "$W/home/fkuser/Downloads"; : >"$W/home/fkuser/Downloads/fedokawaii.zip"; touch -d '1 hour ago' "$W/home/fkuser/Downloads/fedokawaii.zip"   # (downloaded before it was unpacked)
chown "$FK_UID:$FK_UID" "$W/home/fkuser/.local"; chown -R "$FK_UID:$FK_UID" "$W/home/fkuser/.local/state" "$W/home/fkuser/Downloads"
resume --no-reboot; eq "$RC" 0
eq "$(state phase)" "done"
has "$OUT" "✔ 3.13 verify gate"; has "$OUT" "✔ verified"
[[ ! -e $unit ]] && _ok || _no "the resume unit is still installed"
grep -qx 'enabled greetd.service' "$FKH/units" && _ok || _no "greetd not enabled"
g=" $(fk id -nG fkuser) "; has "$g" " video "; has "$g" " render "; lacks "$g" " input " "never in the input group (every key readable)"
grep -qx "global-enabled grub-boot-success.timer" "$FKH/units" && _no "Fedora's every-session boot-success timer still on: with linger any boot would count" || _ok
[[ -s $W/var/lib/fedokawaii/input-group-out ]] && _ok || _no "not recorded: a later update would look again"
has "$(cat "$W/etc/systemd/system/user@.service.d/fedokawaii.conf" 2>/dev/null)" $'[Service]\nTimeoutStopSec=30s' "shutdown never waits long on your services"
has "$(cat "$W/etc/systemd/system/greetd.service.d/fedokawaii.conf")" "Conflicts=getty@tty1.service kmsconvt@tty1.service" "greetd holds tty1 against agetty and Fedora 45's kmscon"
eq "$(cat "$FKH/default-target")" graphical.target
has "$(cat "$FKH/snaps")" "fedokawaii baseline"
[[ -x $W/usr/local/bin/dwl && -s $W/usr/local/lib/fedokawaii-wlroots-0.20/cflags ]] && _ok || _no "dwl or its wlroots not in place"
for t in satty yazi ya bluetui lazygit; do [[ -x $W/home/fkuser/.local/bin/$t ]] || _no "$t not installed"; done; _ok
eq "$(cat "$W/home/fkuser/.local/share/fedokawaii/upstream/ge-proton" 2>/dev/null)" GE-Proton10-25
eq "$(cat "$W/home/fkuser/.local/share/fedokawaii/upstream/syncplay" 2>/dev/null)" "$(. "$REPO/lib/upstream.sh"; syncplay_pin)" "Syncplay (3.07c) at its pinned commit, with our patch"
[[ -x $W/home/fkuser/.local/bin/syncplay && -f $W/home/fkuser/.local/share/fedokawaii/syncplay/syncplay/client.py ]] && _ok || _no "Syncplay not installed"
eq "$(cat "$W/home/fkuser/.local/share/fedokawaii/upstream/blesh" 2>/dev/null)" "$(. "$REPO/lib/upstream.sh"; echo "$BLESH_COMMIT")" "ble.sh (3.07d) at its pinned commit"
[[ -f $W/home/fkuser/.local/share/blesh/ble.sh ]] && _ok || _no "ble.sh not installed"
# (the clone setup was started from: gone at the end — the toolkit has all of it)
[[ ! -e $W$CLONE ]] && _ok || _no "the clone ~/fedokawaii is still there"
has "$OUT" "~/fedokawaii removed: the toolkit has all of it"
[[ -x $W$TK/setup.sh ]] && _ok || _no "the toolkit went with it"
[[ ! -e $W/home/fkuser/Downloads/fedokawaii.zip && -d $W/home/fkuser/Downloads ]] && _ok || _no "the download it came from is still there (or Downloads went with it)"
eq "$(ls "$B" | wc -l)" 10 "ten theme backups kept: $(ls "$B" | tr '\n' ' ')"
[[ -d $B/20260112-120000 && -d $B/20260103-120000 && ! -e $B/20260102-120000 && ! -e $B/20260101-120000 ]] && _ok || _no "not the newest kept: $(ls "$B" | tr '\n' ' ')"
# the sweep before the baseline (a snapshot keeps every cached download for good)
c=$(grep -n '\[dnf\] clean packages' "$W/var/lib/fkh/calls.log" | tail -n1 | cut -d: -f1); b=$(grep -n 'fedokawaii baseline' "$W/var/lib/fkh/calls.log" | tail -n1 | cut -d: -f1)
[[ -n $c && -n $b ]] && ((c < b)) && _ok || _no "dnf's packages cleaned at line [$c], the baseline taken at [$b]"
case_ "torrra: installed by pipx with its pinned libraries, pipx's own command off your PATH; 6881 open"
called "pipx\] install --force --python python3.13 --pip-args=-c .*/system/torrra-constraints.txt torrra=="
[[ -L $W/home/fkuser/.local/share/pipx/bin/torrra && ! -e $W/home/fkuser/.local/bin/torrra && ! -L $W/home/fkuser/.local/bin/torrra ]] \
  && _ok || _no "pipx's torrra is in ~/.local/bin"
eq "$(sort "$FKH/fw-ports" | tr '\n' ' ')" "53317/tcp 53317/udp 6881/tcp 6881/udp " "torrra's port and LocalSend's"
case_ "the gate's second tries: GE-Proton, the yazi file dialog and LazyVim's plugins, each put in place there"
has "$OUT" "GE-Proton is not installed yet"; has "$OUT" "file dialogs stay GTK's for now"
has "$OUT" "✔ GE-Proton10-25 → Steam compatibilitytools.d"; has "$OUT" "file dialogs: yazi (termfilechooser v1.4.3)"
called "nvim\] --headless \+Lazy! install"
[[ -d $W/home/fkuser/.local/share/nvim/lazy/LazyVim && -x $W/usr/local/libexec/xdg-desktop-portal-termfilechooser ]] && _ok || _no "LazyVim or the file dialog missing"
case_ "after the build: verify passes (exit 0), and setup run again only says so"
fkrun bash "$TK/verify.sh"; eq "$RC" 0 "verify: $(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"; has "$OUT" "✔ verified"
reset_calls; fkrun bash "$TK/setup.sh"; eq "$RC" 0; has "$OUT" "already built"      # (the clone is gone: the toolkit's)
not_called 'dnf\] -y install'
case_ "the clone holds a file of yours (or a changed fedokawaii.conf): packed into ~/.local/state first; the project's files go, yours stays"
back phase3; echo "my notes" >"$W$CLONE/notes.txt"; chown "$FK_UID:$FK_UID" "$W$CLONE/notes.txt"
resume --no-reboot; eq "$RC" 0; eq "$(state phase)" "done"
eq "$(ls -A "$W$CLONE" 2>&1)" "notes.txt" "only your file is left"
has "$OUT" "~/fedokawaii: the project's files removed; the rest is yours and stays (notes.txt)"
has "$OUT" "~/fedokawaii: it differs from the toolkit — the whole folder is kept, packed, in ~/.local/state/fedokawaii/started-from-"
a=$(ls "$W"/home/fkuser/.local/state/fedokawaii/started-from-*.tar.gz 2>/dev/null | tail -n1)
eq "$(tar -xzOf "$a" fedokawaii/notes.txt 2>/dev/null)" "my notes" "your file is in the pack"
eq "$(fk stat -c %U "${a#"$W"}")" fkuser "the pack is yours"
back phase3; sed -i 's/^MONITOR_HZ=.*/MONITOR_HZ="60"/' "$W$CLONE/fedokawaii.conf"; chown "$FK_UID:$FK_UID" "$W$CLONE/fedokawaii.conf"
resume --no-reboot; [[ ! -e $W$CLONE ]] && _ok || _no "the clone is still there"
has "$OUT" "~/fedokawaii: its fedokawaii.conf changed after this run read it — the whole folder is kept, packed"
case_ "the pack cannot be made (a file in it you cannot read, the disk full): the clone stays, and the log says so"
back phase3; echo "mine" >"$W$CLONE/notes.txt"; chown "$FK_UID:$FK_UID" "$W$CLONE/notes.txt"; chmod 000 "$W$CLONE/notes.txt"   # (unreadable)
resume --no-reboot; eq "$(state phase)" "done"
[[ -f $W$CLONE/notes.txt ]] && _ok || _no "removed without its pack"
has "$OUT" "kept: it differs from the toolkit, and it could not be packed first"
eq "$(ls "$W"/home/fkuser/.local/state/fedokawaii/started-from-* 2>/dev/null)" "" "no half-made pack left"
case_ "a working copy fedokawaii copy made (its .git knows the settings it was made with): never removed"
back phase3; mkdir -p "$W$CLONE/.git"; : >"$W$CLONE/.git/fedokawaii-conf-base"; chown -R "$FK_UID:$FK_UID" "$W$CLONE/.git"
resume --no-reboot; [[ -d $W$CLONE ]] && _ok || _no "your working copy was removed"
has "$OUT" "~/fedokawaii kept: it is your working copy"
case_ "phase 3 run from the clone (as setup is started again by hand): the clone goes after the final check, which runs from the toolkit"
back phase3; reset_calls
setup --no-reboot; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
eq "$(state phase)" "done"; has "$OUT" "~/fedokawaii removed: the toolkit has all of it"
lacks "$OUT" "No such file"; lacks "$OUT" "final verification failed"
[[ ! -e $W$CLONE ]] && _ok || _no "the clone is still there"
[[ $(grep -n 'removed: the toolkit' <<<"$OUT" | cut -d: -f1) -gt $(grep -n '✔ verified' <<<"$OUT" | tail -n1 | cut -d: -f1) ]] && _ok || _no "removed before the final check"

case_ "Fedora 45: phase 2 takes RPM Fusion's release packages for 45, and goes on as on 44"
back phase2; fedora_release 45
resume --no-reboot; eq "$RC" 0; eq "$(state phase)" 3; has "$OUT" "Fedora 45 · phase 2"
called 'mirrors\.rpmfusion\.org/free/fedora/rpmfusion-free-release-45\.noarch\.rpm'
called 'mirrors\.rpmfusion\.org/nonfree/fedora/rpmfusion-nonfree-release-45\.noarch\.rpm'
not_called 'release-44\.noarch'

# ── stopped half-way, started again ──────────────────────────────────────────
case_ "a step that fails (a mirror down for good): the line and the log named, exit 1, the phase kept"
back phase2; fkh dnf-fail 'install .*ffmpeg'
resume --no-reboot; eq "$RC" 1
has "$OUT" "✘ line"; has "$OUT" "log: /var/log/fedokawaii.log"
has "$OUT" "in s_media(), called from line"; has "$OUT" ": dnf -y install ffmpeg --allowerasing (exit 1)" "the red line names the command that failed"
has "$OUT" "Setup stopped — the reason is above"; has "$OUT" "restart the computer: setup continues by itself"
has "$OUT" "Alt+F2"
eq "$(state phase)" 2
case_ "…the next start: the finished steps skipped, on from the one that failed"
rm -f "$FKH/dnf-fail"; resume --no-reboot; eq "$RC" 0
has "$OUT" "skip (done): 2.1 repositories"; has "$OUT" "skip (done): 2.2 GPU drivers"; has "$OUT" "✔ 2.3 ffmpeg"
eq "$(state phase)" 3

case_ "ffmpeg installed but unable to start (RPM Fusion's build behind one of Fedora's libraries): said so, not as a missing encoder"
back phase2; fkh ffmpeg-broken
resume --no-reboot; eq "$RC" 1; has "$OUT" "ffmpeg does not start"; lacks "$OUT" "lacks encoder"; lacks "$OUT" "✘ line"
rm -f "$FKH/ffmpeg-broken"
case_ "a power cut in phase 1's update: run again, the packages left twice are tidied before it is tried again"
back fresh; fkh fail-dnf-upgrade 1
setup --no-reboot; eq "$RC" 1 "the cut-off update stops the run"
setup --no-reboot; eq "$RC" 0 "the run again: $(grep -E '✘' <<<"$OUT" | head -n2 | tr '\n' '|')"
called 'dnf\] -y remove --duplicates'; eq "$(cat "$FKH/dups")" "" "no package left twice"; eq "$(state phase)" 2
case_ "…and in phase 2: the restart resumes it, and it goes through"
back phase2; fkh dups "glibc-2.43-2.fc44.x86_64"
resume --no-reboot; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n2 | tr '\n' '|')"
eq "$(cat "$FKH/dups")" "" "no package left twice"; eq "$(state phase)" 3

case_ "the gate finds a problem repair can fix (a dnf problem distro-sync clears): setup repairs it itself, checks again, and goes on to the login"
back phase3; fkh dnfcheck "package: foo-1.0-1.fc44.x86_64" "  dependency: libbar.so.1()(64bit)" "   problem: missing dependency"
fkh distro-sync-fixes
resume --no-reboot; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "verify found problems (above) — setup repairs them now"; has "$OUT" "repaired: verify passes now"
eq "$(cat "$FKH/dnfcheck")" "" "dnf's problem fixed"
eq "$(state phase)" "done"; grep -qx 'enabled greetd.service' "$FKH/units" && _ok || _no "the login not switched on"
rm -f "$FKH/distro-sync-fixes"
case_ "a power cut mid-transaction and a dnf problem repair cannot fix: duplicates tidied, repaired once, then it stops before the login"
back phase3; fkh dups "kernel-core-6.19.1-200.fc44.x86_64"
fkh dnfcheck "package: foo-1.0-1.fc44.x86_64" "  dependency: libbar.so.1()(64bit)" "   problem: missing dependency"
resume --no-reboot; eq "$RC" 1
called 'dnf\] -y remove --duplicates'; eq "$(cat "$FKH/dups")" "" "the older copies removed"
has "$OUT" "setup repairs them now"; has "$OUT" "repair: nothing doubled or fighting"
has "$OUT" "verify still finds problems after repairing"; has "$OUT" "then run setup again"
eq "$(state phase)" 3
grep -qx 'enabled greetd.service' "$FKH/units" && _no "greetd enabled before the gate passed (by its repair, too)" || _ok
case_ "…repair may run now (before, it would only say the build is not finished), and puts it right"
fkh distro-sync-fixes; fkrun bash "$TK/setup.sh" --repair
lacks "$OUT" "the build is not finished"; has "$OUT" "repair: nothing doubled or fighting"
eq "$(cat "$FKH/dnfcheck")" "" "dnf's problem fixed"
case_ "…the final check failing after the login is on: the resumed run says restart, log in, run repair"
fkh systemctl-fail 'is-enabled --quiet fedokawaii-scrub.timer'
resume --no-reboot; [[ $RC != 0 ]] && _ok || _no "a failed final check ended 0"
has "$OUT" "skip (done): 3.12 theme"; has "$OUT" "✔ 3.13 verify gate"
has "$OUT" "The desktop is installed, but its last steps found a problem"; has "$OUT" "fedokawaii repair"
eq "$(state phase)" "done"
case_ "repair before the build reached its gate: refused, with what to do"
back phase2; fkrun bash "$TK/setup.sh" --repair; eq "$RC" 1; has "$OUT" "the build is not finished — run setup again"

# ── the state files ──────────────────────────────────────────────────────────
case_ "the phase file gone: phase 1 again, every finished step skipped, nothing redone"
back phase3; rm -f "$W/var/lib/fedokawaii/phase"
setup --no-reboot; eq "$RC" 0
has "$OUT" "skip (done): 1.0 readiness check"; has "$OUT" "skip (done): 1.7 inbound SSH"
eq "$(state phase)" 2
case_ "the phase file with a Windows line end, or blank lines: read as the phase it says"
back phase3; printf '3\r\n\n' >"$W/var/lib/fedokawaii/phase"
fkh dnf-fail 'install .*gcc'                          # (stops at 3.01: enough to see which phase ran)
resume --no-reboot; has "$OUT" "phase 3 · fkuser"; has "$OUT" "── 3.01 build dependencies"
rm -f "$FKH/dnf-fail"
case_ "the phase file damaged: stops, says what it should hold and how to start over (exit 1)"
back phase3; printf 'garbage\n' >"$W/var/lib/fedokawaii/phase"
resume --no-reboot; eq "$RC" 1
has "$OUT" "should be 1, 2, 3 or done"; has "$OUT" "--reset"
case_ "the user record names nobody (damaged, or the user renamed): said at once, nothing done"
back phase3; printf 'ghost\n' >"$W/var/lib/fedokawaii/user"
resume --no-reboot; eq "$RC" 1; has "$OUT" "names 'ghost', who is not a user of this machine"
not_called 'dnf\] -y'
case_ "the user record empty: the same"
back phase3; : >"$W/var/lib/fedokawaii/user"
resume --no-reboot; eq "$RC" 1; has "$OUT" "is not a user of this machine"
case_ "a second run while one is going (the lock): refused, exit 1"
back phase3
fkrun bash -c "exec 9>/var/lib/fedokawaii/lock; flock 9; bash $TK/setup.sh --no-reboot; exit \$?"
eq "$RC" 1; has "$OUT" "another Fedokawaii run (an update, a repair, setup or Theme) is going on"

# ── options ──────────────────────────────────────────────────────────────────
case_ "misuse: an unknown option (exit 2, nothing touched); not root (exit 2); --help (0)"
back fresh
setup --frobnicate; eq "$RC" 2; has "$OUT" "unknown option: --frobnicate"
[[ ! -e $W/var/lib/fedokawaii/lock && ! -e $W/var/log/fedokawaii.log ]] && _ok || _no "a misused run touched the system"
fkrun runuser -u fkuser -- bash "$CLONE/setup.sh"; eq "$RC" 2; has "$OUT" "run with sudo"
setup --help; eq "$RC" 0; has "$OUT" "--no-reboot"
case_ "--status: the phase, the user, the finished steps — read-only, also while a run holds the lock"
back phase3
fkrun bash -c "exec 9>/var/lib/fedokawaii/lock; flock 9; bash $TK/setup.sh --status; exit \$?"
eq "$RC" 0; has "$OUT" "phase 3 · user fkuser · Fedora 44"; has "$OUT" "✔ 2.2 GPU drivers"
case_ "--reset: progress forgotten (the user and the baseline kept), the resume unit gone"
fkrun bash "$TK/setup.sh" --reset; eq "$RC" 0
eq "$(state phase)" ""; eq "$(state user)" fkuser; [[ -s $W/var/lib/fedokawaii/baseline-userinstalled ]] && _ok || _no "baseline lost"
compgen -G "$W/var/lib/fedokawaii/done.*" >/dev/null && _no "done marks left" || _ok
[[ ! -e $unit ]] && _ok || _no "resume unit left"

done_
