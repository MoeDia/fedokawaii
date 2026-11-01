#!/usr/bin/env bash
# tools/vm-inject/update-button.sh — the update button's own path in the harness VM from "built"
# (T45 (h); the master's must-fix 4): `fedokawaii.sh update` as Super+U runs it (root's front →
# fedokawaii-update.service → its output followed, its exit status back), a second press while it
# runs (root's front, and the menu's own as the user: both only follow, nothing started twice),
# then a run that stops (another dnf5 running): its status non-zero, said.
#   bash tools/vm-inject/update-button.sh [VM] [REPO]   (VM f44b; REPO this repository)
# Out: a line a check on stdout, everything in /dev/shm/r27/update-button-VM/. Exit 0 all held ·
# 1 one did not · 2 the VM could not run.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
vm=${1:-f44b} src=${2:-$(cd "$here/.." && pwd)}
out=/dev/shm/r27/update-button-$vm; rm -rf "$out"; mkdir -p "$out"; log=$out/run.log
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
bad=0
ok() { if eval "$2"; then printf '%-58s held\n' "$1"; else printf '%-58s BROKEN\n' "$1"; bad=1; fi; }
{ bash "$here/vm-snap.sh" "$vm" revert built && bash "$here/vm-snap.sh" "$vm" start && run --wait 600; } >>"$log" 2>&1 \
  || { echo "update-button: the VM did not start" >&2; exit 2; }
{ run --repo "$src" && run 'sudo cp -a ~/fedokawaii/. /usr/local/lib/fedokawaii/ && sudo install -m 755 ~/fedokawaii/system/kawa-snap /usr/local/sbin/kawa-snap && sudo install -m 755 ~/fedokawaii/system/fedokawaii /usr/local/bin/fedokawaii'
  run 'rpm -q systemd-container >/dev/null || sudo dnf -y -q install systemd-container'; } >>"$log" 2>&1 \
  || { echo "update-button: the toolkit could not go in" >&2; exit 2; }
# the first press, in the background of the VM; 40 s later the second (root's front) and the third
# (the menu as the user, no password) — each follows to the end
# (each press detached from ssh's own output: else ssh waits for it to end — the next press would
# come only after the run)
run 'sudo setsid -f bash -c "bash /usr/local/lib/fedokawaii/fedokawaii.sh update >/tmp/first.out 2>&1; echo \$? >/tmp/first.rc" </dev/null >/dev/null 2>&1' >>"$log" 2>&1
sleep 40
run 'sudo setsid -f bash -c "bash /usr/local/lib/fedokawaii/fedokawaii.sh update >/tmp/second.out 2>&1; echo \$? >/tmp/second.rc" </dev/null >/dev/null 2>&1
     setsid -f bash -c "fedokawaii update >/tmp/third.out 2>&1; echo \$? >/tmp/third.rc" </dev/null >/dev/null 2>&1' >>"$log" 2>&1
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
ok "the report: ok" 'grep -qE "^== report: [0-9]+ (ok|current) " <<<"$st"'
# a run that stops: another dnf5 holds the packages — its status comes back, said
run 'cp /usr/bin/sleep /tmp/dnf5 && setsid -f /tmp/dnf5 120; sudo bash /usr/local/lib/fedokawaii/fedokawaii.sh update >/tmp/stop.out 2>&1; echo "rc $?"; grep -v "^$" /tmp/stop.out | tail -n 2; pkill -x dnf5' >"$out/stop.txt" 2>&1
cat "$out/stop.txt" >>"$log"
ok "a stopped run: its exit status (1), the reason said" 'grep -q "^rc 1$" "$out/stop.txt" && grep -q "another package manager is running (dnf5)" "$out/stop.txt"'
bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
exit "$bad"
