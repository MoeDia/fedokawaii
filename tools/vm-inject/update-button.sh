#!/usr/bin/env bash
# tools/vm-inject/update-button.sh — the update button's own path in the harness VM from "built"
# (T45 (h); the master's must-fix 4): `fedokawaii.sh update` as Super+U runs it (root's front →
# fedokawaii-update.service → its output followed, its exit status back), a second press while it
# runs (root's front, and the menu's own as the user: both only follow, nothing started twice),
# then a run that stops (another dnf5 running): its status non-zero, said.
#   bash tools/vm-inject/update-button.sh [VM] [REPO]   (VM f45; REPO this repository)
# Out: a line a check on stdout, everything in /dev/shm/r27/update-button-VM/. Exit 0 all held ·
# 1 one did not · 2 the VM could not run.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
vm=${1:-f45} src=${2:-$(cd "$here/.." && pwd)}
out=/dev/shm/r27/update-button-$vm; rm -rf "$out"; mkdir -p "$out"; log=$out/run.log
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
bad=0
ok() { if eval "$2"; then printf '%-58s held\n' "$1"; else printf '%-58s BROKEN\n' "$1"; bad=1; fi; }
{ bash "$here/vm-snap.sh" "$vm" revert built && bash "$here/vm-snap.sh" "$vm" start && run --wait 600; } >>"$log" 2>&1 \
  || { echo "update-button: the VM did not start" >&2; exit 2; }
# (applied as the PC is before a press: a toolkit newer than the VM's theme and builds would make
# the desktop check red before the update — then it could see nothing after it)
{ run --apply "$src"; } >>"$log" 2>&1 \
  || { echo "update-button: the toolkit could not go in" >&2; exit 2; }
# the first press, in the background of the VM; once its unit runs and is past the checks before
# it (the fetch has begun), the second (root's front) and the third (the menu as the user, no
# password) — each follows to the end; the unit's invocation read at each press: one for all
# (each press detached from ssh's own output: else ssh waits for it to end — the next press would
# come only after the run)
inv() { run 'systemctl show -p InvocationID --value fedokawaii-update.service'; }
# (SELinux's denials until now marked: the presses' own read afterwards — ausearch(8) --checkpoint;
# the instrument itself recorded: auditd running and its log there — else "no denial" proves nothing,
# ausearch exits 1 with nothing printed for a missing log as for nothing found)
run 'systemctl is-active auditd; sudo test -s /var/log/audit/audit.log && echo "log there"; sudo ausearch --checkpoint /tmp/avc.ck -m avc >/dev/null 2>&1; true' >"$out/avc-instrument.txt" 2>&1
run 'sudo setsid -f bash -c "bash /usr/local/lib/fedokawaii/fedokawaii.sh update >/tmp/first.out 2>&1; echo \$? >/tmp/first.rc" </dev/null >/dev/null 2>&1' >>"$log" 2>&1
for _ in $(seq 120); do
  run 'systemctl is-active --quiet fedokawaii-update.service && grep -q "upgrade --store=" /var/lib/fedokawaii/update/run.log' && break; sleep 5
done
inv1=$(inv)
run 'sudo setsid -f bash -c "bash /usr/local/lib/fedokawaii/fedokawaii.sh update >/tmp/second.out 2>&1; echo \$? >/tmp/second.rc" </dev/null >/dev/null 2>&1
     setsid -f bash -c "fedokawaii update >/tmp/third.out 2>&1; echo \$? >/tmp/third.rc" </dev/null >/dev/null 2>&1' >>"$log" 2>&1
sleep 5; inv2=$(inv)
printf 'invocations: at the first press %s, after the second and third %s\n' "$inv1" "$inv2" >>"$log"
for _ in $(seq 90); do run 'test -s /tmp/first.rc && test -s /tmp/second.rc && test -s /tmp/third.rc' && break; sleep 10; done
run 'for f in first second third; do echo "== $f rc $(cat /tmp/$f.rc 2>/dev/null) last: $(grep -v "^$" /tmp/$f.out | tail -n 1)"; done
     echo "== log last: $(grep -v "^$" /var/lib/fedokawaii/update/run.log | tail -n 1)"
     echo "== starts: $(sudo journalctl -b --no-pager -o cat | grep -c "Started fedokawaii-update.service")"
     echo "== report: $(sudo head -n 2 /var/lib/fedokawaii/update/report | tr "\n" " ")"' >"$out/state.txt" 2>&1
cat "$out/state.txt" >>"$log"
st=$(cat "$out/state.txt")
last() { sed -n "s/^== $1 rc [0-9]* last: //p" <<<"$st"; }
ok "the press: exit 0" 'grep -q "^== first rc 0 " <<<"$st"'
ok "the press: its terminal's last line is the run's own" '[[ -n $(last first) && $(last first) == "$(sed -n "s/^== log last: //p" <<<"$st")" ]]'
ok "a second press (root's front): followed to the end, exit 0" 'grep -q "^== second rc 0 " <<<"$st" && [[ $(last second) == "$(last first)" ]]'
ok "the menu's press (as the user): followed, exit 0" 'grep -q "^== third rc 0 " <<<"$st" && [[ $(last third) == "$(last first)" ]]'
ok "one unit started for the three presses" 'grep -q "^== starts: 1$" <<<"$st"'
ok "…one invocation, the presses past its checks before it" '[[ $inv1 =~ ^[0-9a-f]{32}$ && $inv2 == "$inv1" ]]'
# (its own unit: the desktop check runs — a green run never says the desktop does not start)
run 'sudo journalctl -b --no-pager -o short-precise -u fedokawaii-update.service -u "fedokawaii-dnf-*"; echo "== run.log"; sed "s/\x1b\[[0-9;]*m//g" /var/lib/fedokawaii/update/run.log' >"$out/units.txt" 2>&1
ok "the desktop check green before and after (no \"the desktop does not start\")" '! grep -q "the desktop does not start" "$out/units.txt" && grep -q "the checks before it" "$out/units.txt"'
ok "the report: ok" 'grep -qE "^== report: [0-9]+ (ok|current) " <<<"$st"'
# (no confined program denied anything in the presses — the scriptlets inherit what dnf's unit gives)
run 'sudo ausearch --checkpoint /tmp/avc.ck -m avc -i 2>/dev/null | grep "^type=AVC"' >"$out/avc.txt" 2>&1
ok "no SELinux denial in the presses (avc.txt; auditd on, its log there)" 'grep -qx active "$out/avc-instrument.txt" && grep -qx "log there" "$out/avc-instrument.txt" && ! grep -q denied "$out/avc.txt"'
# a run that stops: another dnf5 holds the packages — its status comes back, said
run 'cp /usr/bin/sleep /tmp/dnf5 && setsid -f /tmp/dnf5 120; sudo bash /usr/local/lib/fedokawaii/fedokawaii.sh update >/tmp/stop.out 2>&1; echo "rc $?"; grep -v "^$" /tmp/stop.out | tail -n 2; pkill -x dnf5' >"$out/stop.txt" 2>&1
cat "$out/stop.txt" >>"$log"
ok "a stopped run: its exit status (1), the reason said" 'grep -q "^rc 1$" "$out/stop.txt" && grep -q "another package manager is running (dnf5)" "$out/stop.txt"'
bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
exit "$bad"
