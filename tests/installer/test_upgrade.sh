#!/usr/bin/env bash
# tests/installer/test_upgrade.sh — the next Fedora through the update button (lib/move.sh) on a
# finished install in the fake machine: looked at only when the press ends with this Fedora current;
# out and settled, RPM Fusion has it; the test VM's verdict kept (green goes on, red waits, a newer
# toolkit or a month tries again, "could not run" no verdict); the first press that gets this far only
# says so, the next moves: the whole move in a copy, the pinned snapshot, the download, the unit for
# the next start, the restart. Then that unit: judged by facts, kept, or the snapshot back.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
tk() { fkrun bash "$TK/setup.sh" "$@"; }
press() { tk --update; }
osr() { sed -i "s/^VERSION_ID=.*/VERSION_ID=$1/" "$W/etc/os-release"; sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Fedora Linux $1 (Server Edition)\"/" "$W/etc/os-release"; }
foryou() { cat "$W/home/fkuser/.foryou" 2>/dev/null; }

world built; releases
U=$W/var/lib/fedokawaii/update
unit=$W/etc/systemd/system/fedokawaii-after-upgrade.service
fkh mounts /run/fedokawaii/top
mkdir -p "$W/home/fkuser/.local/bin"
printf '#!/bin/sh\necho "$*" >>"$HOME/.foryou"\n' >"$W/home/fkuser/.local/bin/kawa-foryou"; chmod 755 "$W/home/fkuser/.local/bin/kawa-foryou"
printf '#!/bin/sh\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$W/usr/local/sbin/kawa-snap"; chmod 755 "$W/usr/local/sbin/kawa-snap"
printf '#!/bin/sh\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$W/usr/local/bin/notify-send"; chmod 755 "$W/usr/local/bin/notify-send"
printf 'root=UUID=1 ro rootflags=subvol=root\n' >"$W/etc/kernel/cmdline"
fkh pending-move "bash 5.3-1.fc44 5.3-2.fc45" "fedora-release-common 44-1 45-1"
keep built

case_ "Fedora 45 not out (its release tree not published): the press is an update and nothing more; no test VM"
back built; press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
not_called 'vm-preflight'; not_called 'distro-sync'; not_called 'system-upgrade'; [[ ! -e $U/move-told ]] && _ok || _no "told"
case_ "fedokawaii upgrade while it is not out: said, nothing changed"
tk --upgrade --now; eq "$RC" 0; has "$OUT" "Fedora 45 is not released yet"; not_called 'system-upgrade'
case_ "staged: Fedora's own server still refuses the tree while a mirror would serve it — not released (no mirror asked)"
back built; echo '<repomd/>' >"$FKH/dl/repomd.xml"; fkh unreachable dl.fedoraproject.org
press; eq "$RC" 0; not_called 'vm-preflight'; not_called 'download\.fedoraproject\.org/pub/fedora/linux/releases'
[[ ! -e $W/var/lib/fedokawaii/release-45 ]] && _ok || _no "a release day recorded"

back built; echo '<repomd/>' >"$FKH/dl/repomd.xml"; keep out
case_ "out, settling (7 days): when it is offered is said; no test VM yet"
press; eq "$RC" 0; has "$OUT" "Fedora 45 is out; it settles 7 days — offered in 7 day(s)"; not_called 'vm-preflight'
case_ "--now does not wait; RPM Fusion without Fedora 45: it waits for that, nothing changed"
back out; fkh unreachable download1.rpmfusion.org
tk --upgrade --now; eq "$RC" 0; has "$OUT" "RPM Fusion has no Fedora 45 yet"; not_called 'vm-preflight'; not_called 'system-upgrade'
back out; echo $(( $(date +%s) - 30 * 86400 )) >"$W/var/lib/fedokawaii/release-45"; keep settled

case_ "fedokawaii upgrade (asked in so many words): settled, it moves in this one run; no second press"
back settled; tk --upgrade; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"; called 'vm-preflight'; called 'system-upgrade reboot'; lacks "$OUT" "press update again"
back settled
case_ "the first press with every gate open: the test VM runs, green is kept, it is said — no move, no restart"
press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
called '^fkuser\[vm-preflight\.sh\] 45 --out'; eq "$(cut -d' ' -f1 "$U/preflight-45")" green
eq "$(cat "$U/move-told")" 45; has "$OUT" "Fedora 45 is ready: press update again to move to it (a restart, 20–40 minutes)"
called 'notify-send\] .*Fedora 45 is ready'; not_called 'distro-sync'; not_called 'system-upgrade'; [[ ! -e $unit ]] && _ok || _no "the unit made already"
keep told
case_ "the next press: no second VM; the whole move in a copy, pinned snapshot, download, the unit, the counting, the restart — in that order"
reset_calls; press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
not_called 'vm-preflight'
called 'dnf\] -y --setopt=keepcache=True --releasever=45 distro-sync --store=/var/lib/fedokawaii/update/tx'
called 'systemd-nspawn\] .*--setenv=FK_MOVE=1 .* dnf5 --disable-plugin=actions -y -C replay /tx'
called "snapper\] -c root modify -c  [0-9]+"
called 'dnf\] -y system-upgrade download --releasever=45$'; called 'dnf\] -y system-upgrade reboot'
c=$(grep -n 'FK_MOVE=1' "$CALLS" | head -n1 | cut -d: -f1); s=$(grep -n 'snapper\] -c root create .*before Fedora 45' "$CALLS" | head -n1 | cut -d: -f1)
d=$(grep -n 'system-upgrade download' "$CALLS" | head -n1 | cut -d: -f1); r=$(grep -n 'system-upgrade reboot' "$CALLS" | head -n1 | cut -d: -f1)
((c < s && s < d && d < r)) && _ok || _no "copy $c, snapshot $s, download $d, restart $r — out of order"
[[ -f $unit ]] && _ok || _no "no unit for after the restart"
has "$(cat "$unit" 2>/dev/null)" "ExecStart=/usr/bin/bash $TK/setup.sh --after-upgrade"
has "$(cat "$unit" 2>/dev/null)" "Before=display-manager.service greetd.service"
has "$(cat "$unit" 2>/dev/null)" "SELinuxContext=system_u:system_r:unconfined_service_t:s0"
called 'systemctl\] enable fedokawaii-after-upgrade.service'
read -r f t n _ <"$U/move"; eq "$f $t" "44 45"; eq "$n" "$(cat "$U/snap")" "the pinned snapshot named"
eq "$(awk '{ print $1 }' "$U/move-set" | tr '\n' ' ')" "bash fedora-release-common "
grep -qx 'boot_counter=4' "$FKH/grubenv" && _ok || _no "GRUB's counting not armed: $(cat "$FKH/grubenv")"
has "$(cat "$W/etc/kernel/cmdline")" "rd.shell=0 rd.emergency=reboot rd.retry=30 panic=10"
[[ -e $W/etc/systemd/system.conf.d/90-fedokawaii-probation.conf ]] && _ok || _no "the watchdog not armed"
keep armed

case_ "a COPR with no build for 45: left out of the copy's set and of the download, said"
back told; printf '%s\n' "ilyaz/LACT fedora-45-x86_64" >>"$FKH/copr-without"; reset_calls; press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
has "$OUT" "COPR ilyaz/LACT has nothing for Fedora 45 yet — left out"
called 'distro-sync --store=/var/lib/fedokawaii/update/tx --disablerepo=copr:copr.fedorainfracloud.org:ilyaz:LACT$'
called 'system-upgrade download --releasever=45 --disablerepo=copr:copr.fedorainfracloud.org:ilyaz:LACT$'
case_ "the move resolves only by removing something: dnf may (what the desktop needs comes back after, as the test VM showed)"
back told; fkh move-erase; reset_calls; press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
called 'distro-sync --store=/var/lib/fedokawaii/update/tx --allowerasing$'; called 'system-upgrade download --releasever=45 --allowerasing$'
has "$OUT" "letting it remove what stands in the way"

case_ "red in the test VM: the checks kept, 'Fedora 45 waits', critical; no move"
back settled; printf '%s\n' "verify: the bar is not running" >"$FKH/preflight-red"; chmod 666 "$FKH/preflight-red"
press; eq "$RC" 0; eq "$(head -c3 "$U/preflight-45")" red; has "$(cat "$U/preflight-45")" "verify: the bar is not running"
has "$OUT" "Fedora 45 waits: verify: the bar is not running (Fedora 44 stays as it is)"; called 'notify-send\] -a update -u critical .*Fedora 45 waits'
[[ ! -e $U/move-told ]] && _ok || _no "told ready"
keep vmred
case_ "…the next press does not try again: said from the verdict, the same day no second notice"
reset_calls; press; not_called 'vm-preflight'; has "$OUT" "Fedora 45 waits: verify: the bar is not running"; not_called 'notify-send\] -a update -u critical .*Fedora 45 waits'
case_ "…a month later it is tried again"
back vmred; sed -i "1s/^red [0-9]*/red $(( $(date +%s) - 31 * 86400 ))/" "$U/preflight-45"; rm -f "$FKH/preflight-red"
reset_calls; press; called 'vm-preflight'; eq "$(cut -d' ' -f1 "$U/preflight-45")" green; eq "$(cat "$U/move-told")" 45
case_ "…a newer toolkit tries again at once"
back vmred; sed -i "1s/ [0-9a-f]*\$/ 000000000000/" "$U/preflight-45"; rm -f "$FKH/preflight-red"
reset_calls; press; called 'vm-preflight'; eq "$(cut -d' ' -f1 "$U/preflight-45")" green
case_ "the test VM could not run: no verdict, said, the next press tries again"
back settled; printf '%s\n' "only 12 GB free in your home; the test VM needs 40" >"$FKH/preflight-cannot"; chmod 666 "$FKH/preflight-cannot"
press; eq "$RC" 0; [[ ! -e $U/preflight-45 ]] && _ok || _no "a verdict kept"; has "$OUT" "the test VM for Fedora 45 could not run (only 12 GB free"
rm -f "$FKH/preflight-cannot"; reset_calls; press; called 'vm-preflight'; eq "$(cut -d' ' -f1 "$U/preflight-45")" green

case_ "the copy red: Fedora 45 waits with its reason, nothing snapshotted, nothing armed; the next press does not try it"
back told; fkh cand-red "bash"; reset_calls; press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
has "$OUT" "Fedora 45 waits: dwl does not start with bash"; eq "$(head -c3 "$U/move-red-45")" red
not_called 'snapper\] -c root create .*before Fedora 45'; not_called 'system-upgrade'; [[ ! -e $unit && ! -e $U/move ]] && _ok || _no "armed all the same"
reset_calls; press; not_called 'distro-sync'; has "$OUT" "Fedora 45 waits"
case_ "a kernel on trial: the move waits for the start that proves it — said, nothing done"
back told; echo "7 7.3.1-200.fc44.x86_64 2026-11-04" >"$U/probation"; reset_calls; press
has "$OUT" "a new kernel is on trial: restart, then press update again — Fedora 45 follows"; not_called 'distro-sync'; not_called 'system-upgrade'
case_ "the download stops: nothing armed, cleared, said; the snapshot goes back to the cleanup at the next press"
back told; fkh rc-sysup 1; reset_calls; press; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"
has "$OUT" "Fedora 45 waits: the download stopped"; called 'dnf\] system-upgrade clean'; [[ ! -e $unit && ! -e $U/move ]] && _ok || _no "armed all the same"
n=$(cat "$U/snap"); rm -f "$FKH/rc-sysup"; reset_calls; press; called "snapper\] -c root modify -c number $n"
case_ "dnf cannot arrange the restart: nothing armed is left behind (exit 1)"
back told; fkh rc-reboot 1; reset_calls; press; eq "$RC" 1; has "$OUT" "dnf could not arrange the restart into Fedora 45"
[[ ! -e $unit && ! -e $U/move ]] && _ok || _no "the unit or the record left behind"; called 'grub2-editenv\] - unset boot_counter'
lacks "$(cat "$W/etc/kernel/cmdline")" "rd.shell=0"; [[ ! -e $W/etc/systemd/system.conf.d/90-fedokawaii-probation.conf ]] && _ok || _no "the watchdog stays armed"
case_ "fedokawaii upgrade: the same run, no 'press again'"
back settled; reset_calls; tk --upgrade --now; eq "$RC" 0 "$(tail -n2 <<<"$OUT")"; called 'vm-preflight'; called 'dnf\] -y system-upgrade reboot'
case_ "a move cut before its restart (a power cut): forgotten by the next press, which moves anew"
back armed; rm -f "$W/system-update"; reset_calls; press; has "$OUT" "a move that never restarted is forgotten"; called 'grub2-editenv\] - unset boot_counter'; called 'dnf\] -y system-upgrade reboot'

# ── the start after it ───────────────────────────────────────────────────────────────────────
whole() { osr 45; { echo "bash 5.3-2.fc45"; echo "fedora-release-common 45-1"; } >>"$FKH/evr"; fkh_add installed bash fedora-release-common; }
case_ "after the restart, on Fedora 45, whole: the rest of the move, the checks; kept: recorded, its unit gone, the trial on, the login free"
back armed; whole; n_=$(cut -d' ' -f3 "$U/move"); reset_calls; tk --after-upgrade; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
read -r _ from to res <"$U/last-upgrade"; eq "$from $to" "44 45"; [[ $res =~ ^(ok|partial)$ ]] && _ok || _no "the outcome: [$res]"
[[ ! -e $unit && ! -e $U/move ]] && _ok || _no "the unit or the record left behind"
not_called 'kawa-snap\] restore'; not_called 'systemctl\] reboot'
n=$(cat "$U/snap" 2>/dev/null); [[ -z $n ]] && _ok || _no "the snapshot's pin record stays"
[[ $(tail -n1 "$U/probation") == "$n_ "[0-9]*" "* ]] && _ok || _no "no probation for the move's kernel: $(cat "$U/probation" 2>/dev/null)"
lacks "$(cat "$W/etc/kernel/cmdline")" "rd.shell=0" "future kernels without the trial's arguments"
has "$(cat "$FKH/snaps")" "fedokawaii baseline (Fedora 45)"
[[ $(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update") == "$res" ]] && _ok || _no "the update's record not written by the move"
case_ "…run again (the unit started twice): nothing left to do"
reset_calls; tk --after-upgrade; eq "$RC" 0; not_called 'dnf\]'; not_called 'kawa-snap\]'
case_ "after the restart, still on Fedora 44 (the installation did not take): the snapshot back, one restart, said, Fedora 45 waits"
back armed; rm -f "$W/home/fkuser/.foryou"; n=$(cut -d' ' -f3 "$U/move"); reset_calls; tk --after-upgrade; eq "$RC" 0
called "kawa-snap\] restore $n"; called 'systemctl\] reboot'; called 'grub2-editenv\] - unset boot_counter'
eq "$(cut -d' ' -f2- "$U/last-upgrade")" "44 45 failed"; has "$(cat "$U/move-red-45")" "its installation did not take"
has "$(foryou)" "the move to Fedora 45 was undone: its installation did not take"; [[ ! -e $U/move ]] && _ok || _no "the record stays"
case_ "on Fedora 45 but a package of the set not in: not whole, undone the same way"
back armed; osr 45; echo "bash 5.3-2.fc45" >>"$FKH/evr"; fkh_add installed bash; reset_calls; tk --after-upgrade
called "kawa-snap\] restore"; has "$(cat "$U/move-red-45")" "packages are missing or there twice"
case_ "whole, but the desktop does not start on it: undone, the check named"
back armed; whole; fkh session-red "not running: waybar"; reset_calls; tk --after-upgrade
called "kawa-snap\] restore"; called 'systemctl\] reboot'; has "$(cat "$U/move-red-45")" "the desktop does not start: not running: waybar"
eq "$(cut -d' ' -f4 "$U/last-upgrade")" failed
case_ "the snapshot cannot be put back: never a loop — the record gone, the way back said, no restart"
back armed; printf '#!/bin/sh\nexit 1\n' >"$W/usr/local/sbin/kawa-snap"; rm -f "$W/home/fkuser/.foryou"; reset_calls; tk --after-upgrade
not_called 'systemctl\] reboot'; [[ ! -e $U/move && ! -e $unit ]] && _ok || _no "it would run again"; has "$(foryou)" "could not be put back by itself: Super+U → snapshots"
case_ "a restart cut between the restore and its record: back on 44, no unit: the next start says so, once"
back armed; rm -f "$unit" "$W/home/fkuser/.foryou"; reset_calls; tk --update-resume; eq "$RC" 0
has "$(foryou)" "the move to Fedora 45 was undone"; [[ ! -e $U/move ]] && _ok || _no "the record stays"

done_
