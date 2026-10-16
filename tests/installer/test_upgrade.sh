#!/usr/bin/env bash
# tests/installer/test_upgrade.sh — setup.sh's move to the next Fedora (fedokawaii upgrade) on a
# finished install in the fake machine: offered only once the release is out and has settled
# (or with --now), only when RPM Fusion has it, a COPR not built for it left out; then the update
# before it, a snapshot, the download, the unit that finishes the move after the restart — and
# that unit's run on Fedora 45 (or on 44 again, when the installation did not take).
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
tk() { fkrun bash "$TK/setup.sh" "$@"; }
osr() { sed -i "s/^VERSION_ID=.*/VERSION_ID=$1/" "$W/etc/os-release"; }

world built; releases
unit=$W/etc/systemd/system/fedokawaii-after-upgrade.service
keep built

case_ "Fedora 45 not out yet (its release tree not published): said, nothing changed (exit 1)"
tk --upgrade; eq "$RC" 1; has "$OUT" "Fedora 45 is not released yet — nothing changed"
[[ ! -e $unit ]] && _ok || _no "the unit made anyway"; not_called 'system-upgrade'
case_ "out, but settling (60 days): when it is offered is said; --now does not wait"
echo '<repomd/>' >"$FKH/dl/repomd.xml"
tk --upgrade; eq "$RC" 1; has "$OUT" "Fedora 45 is out; it settles 60 days — offered in 60 day(s)"
not_called 'system-upgrade'
keep out
case_ "RPM Fusion has no Fedora 45 yet: refused, nothing changed"
fkh unreachable download1.rpmfusion.org
tk --upgrade --now; eq "$RC" 1; has "$OUT" "RPM Fusion has no Fedora 45 yet"; not_called 'system-upgrade'; not_called 'snapper\] -c root create'

case_ "--now: the system up to date first, a snapshot, the download (COPRs with nothing for 45 left out), the unit for after the restart"
back out; printf '%s\n' "ilyaz/LACT fedora-45-x86_64" >>"$FKH/copr-without"   # (LACT's COPR not built for 45 yet)
tk --upgrade --now; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n2 | tr '\n' '|')"
has "$OUT" "COPR ilyaz/LACT has nothing for Fedora 45 yet — left out"
called 'dnf\] -y upgrade --refresh'
has "$(cat "$FKH/snaps")" "before Fedora 45"; called 'snapper\] -c root create -t single -c number -u important=yes'
called 'dnf\] -y system-upgrade download --releasever=45 --disablerepo=copr:copr.fedorainfracloud.org:ilyaz:LACT$'
[[ -f $unit ]] && _ok || _no "no unit for after the restart"
has "$(cat "$unit" 2>/dev/null)" "ExecStart=/usr/bin/bash $TK/setup.sh --after-upgrade"
called 'systemctl\] enable fedokawaii-after-upgrade.service'
eq "$(cut -d' ' -f2- "$W/var/lib/fedokawaii/upgrade-pending" 2>/dev/null)" "44 45"
called 'dnf\] -y system-upgrade reboot'
keep armed

case_ "a COPR that is built for 45 stays in the move"
back out
tk --upgrade --now; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n2 | tr '\n' '|')"
lacks "$OUT" "has nothing for Fedora 45"; called 'dnf\] -y system-upgrade download --releasever=45$'

case_ "dnf cannot arrange the restart: nothing armed is left behind (exit 1)"
back out; fkh rc-reboot 1
tk --upgrade --now; eq "$RC" 1; has "$OUT" "dnf could not arrange the restart into Fedora 45"
[[ ! -e $unit && ! -e $W/var/lib/fedokawaii/upgrade-pending ]] && _ok || _no "the unit or the pending record left behind"

case_ "after the restart, on Fedora 45: the rest of the move runs once, recorded, the unit gone, a new baseline"
back armed; osr 45; sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Fedora Linux 45 (Server Edition)"/' "$W/etc/os-release"
tk --after-upgrade; eq "$RC" 0
read -r _ from to res <"$W/var/lib/fedokawaii/last-upgrade"
eq "$from $to" "44 45"; [[ $res =~ ^(ok|partial|checks)$ ]] && _ok || _no "the move's outcome: [$res]"
[[ ! -e $unit && ! -e $W/var/lib/fedokawaii/upgrade-pending ]] && _ok || _no "the unit or the pending record left behind"
has "$(cat "$FKH/snaps")" "fedokawaii baseline (Fedora 45)"
[[ $(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update") == "$res" ]] && _ok || _no "the update's record not written by the move"
case_ "…run again (the unit started twice): nothing left to do"
reset_calls; tk --after-upgrade; eq "$RC" 0; not_called 'dnf\]'

case_ "after the restart, still on Fedora 44 (the installation did not take): recorded as failed, the download cleared"
back armed
tk --after-upgrade; eq "$RC" 0
eq "$(cut -d' ' -f2- "$W/var/lib/fedokawaii/last-upgrade")" "44 45 failed"
called 'dnf\] system-upgrade clean'
[[ ! -e $unit && ! -e $W/var/lib/fedokawaii/upgrade-pending ]] && _ok || _no "the unit or the pending record left behind"

done_
