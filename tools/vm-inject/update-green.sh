#!/usr/bin/env bash
# tools/vm-inject/update-green.sh — the update button's run, end to end, on the harness VM's real
# pending updates (update-design.md §2, §4; T45 (c)): the VM from "built" gets this repository's
# toolkit (the working tree), then `setup.sh --update` runs as the button runs it. Afterwards, read
# and logged: its exit and last lines, the report, the phase, the holds, the pinned snapshot, that
# the copy (root.cand) is gone, the candidate's log, the packages left to update, SELinux's denials
# in the run (none, or it is not green).
#   bash tools/vm-inject/update-green.sh [VM] [REPO]   (VM f44; REPO this repository)
# Out: a summary on stdout, everything in /dev/shm/r27/update-green/. Exit 0 the run kept the
# update with a green report · 1 it did not · 2 the VM could not run.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
vm=${1:-f44} src=${2:-$(cd "$here/.." && pwd)}
out=/dev/shm/r27/update-green; rm -rf "$out"; mkdir -p "$out"; log=$out/run.log
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
{ bash "$here/vm-snap.sh" "$vm" revert built && bash "$here/vm-snap.sh" "$vm" start && run --wait 600; } >>"$log" 2>&1 \
  || { echo "update-green: the VM did not start" >&2; exit 2; }
# (applied as the PC is before a press: the toolkit, the theme, our builds — the desktop check green)
run --apply "$src" >>"$log" 2>&1 || { echo "update-green: the toolkit could not go in" >&2; exit 2; }
pending=$(run 'sudo dnf -q check-upgrade 2>/dev/null | grep -c "\."')
run 'sudo ausearch --checkpoint /tmp/avc.ck -m avc >/dev/null 2>&1; true' >>"$log" 2>&1   # (SELinux's denials until now: marked)
s=$SECONDS
run 'sudo bash /usr/local/lib/fedokawaii/setup.sh --update >/tmp/update.log 2>&1; echo "rc=$?"' >"$out/rc.txt" 2>&1
t=$((SECONDS - s))
run 'sed "s/\x1b\[[0-9;]*m//g" /tmp/update.log' >"$out/update.log" 2>&1
run 'U=/var/lib/fedokawaii/update; for f in phase report holds snap set; do echo "== $f"; sudo cat $U/$f 2>/dev/null; done
     echo "== cand.log"; sudo tail -n 15 $U/cand.log 2>/dev/null
     echo "== the copy"; sudo mount -o subvolid=5 $(findmnt -no SOURCE / | sed "s/\[.*//") /mnt && { ls /mnt; sudo umount /mnt; }
     echo "== snapper"; sudo snapper -c root list --columns number,cleanup,description | tail -n 4
     echo "== left"; sudo dnf -q check-upgrade 2>/dev/null | grep -c "\."; uname -r; rpm -q kernel-core' >"$out/state.txt" 2>&1
run 'sudo ausearch --checkpoint /tmp/avc.ck -m avc -i 2>/dev/null | grep "^type=AVC"' >"$out/avc.txt" 2>&1
bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
rc=$(tr -dc 0-9 <"$out/rc.txt")
printf 'pending before: %s · the run: exit %s in %s s\n' "$pending" "${rc:-?}" "$t"
sed -n '/^== report/,/^== holds/p' "$out/state.txt" | sed '1d;$d'
# (a green run never says the desktop does not start: the check ran and passed, before and after)
grep -q 'the desktop does not start' "$out/update.log" && echo "the desktop check was red: $(grep -m1 'the desktop does not start' "$out/update.log")"
# (nor does SELinux deny anything in it: dnf's scriptlets run with what its unit gives them)
grep -q denied "$out/avc.txt" && echo "SELinux denied $(grep -c denied "$out/avc.txt") thing(s) in the run: $(grep -m1 -o 'denied.*tclass=[a-z_]*' "$out/avc.txt")"
[[ $rc == 0 ]] && grep -A1 '^== report' "$out/state.txt" | grep -qE ' (ok|current)$' && ! grep -q 'the desktop does not start' "$out/update.log" \
  && ! grep -q denied "$out/avc.txt"
