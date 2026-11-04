#!/usr/bin/env bash
# tools/vm-inject/release-move.sh — the next Fedora through the update button, for real, in the
# harness VM (T46; update-design.md §4.4, §5 row 32; lib/move.sh). From the VM state "pressed" (an
# up-to-date Fedora N-1 with this desktop): the toolkit applied, a green verdict standing in for the
# test VM (a VM cannot start a VM: tools/vm-preflight.sh proves that part on the PC), the first press
# says "ready", `upgrade --now` runs everything up to the restart. There the VM is stopped and saved
# as the state "armed", once; each case starts from it:
#   green  the offline transaction, the unit before the login, kept: Fedora N, the desktop up, verify
#          against the press's baseline, the next press "up to date", the trial closed at a good start
#   cut    the power gone in the offline transaction: the next start finds it not whole — the pinned
#          snapshot back, one restart, Fedora N-1 as it was, said, "waits" for a month
#   red    Fedora N comes up, the desktop's check fails there: the same way back
#   bash tools/vm-inject/release-move.sh VM TREE N [build] [green] [cut] [red]
# Out: a line a case on stdout, everything in /dev/shm/r27/inject/move-CASE/. Exit 0 every case held ·
# 1 one did not · 2 the VM could not run.
set -u
vm=${1:?} src=${2:?} n=${3:?}; shift 3
cases=("$@"); ((${#cases[@]})) || cases=(build green cut red)
# shellcheck source=tools/vm-inject/lib.sh
. "$(dirname "$0")/lib.sh"
# shellcheck disable=SC2154  # (here, log, out: lib.sh's)
bad=0
state_has() { bash "$here/vm-snap.sh" "$vm" list | grep -qx "$1"; }
U=/var/lib/fedokawaii/update

build() {
  inj_init "$vm" "$src" move-build
  inj_from pressed
  run --apply "$src" >>"$log" 2>&1 || { row BROKEN "the toolkit could not go in"; return 1; }
  run "printf 'green %s test\n\n' \"\$(date +%s)\" | sudo tee $U/preflight-$n >/dev/null"
  run 'sudo mkdir -p ~/.config/fedokawaii; printf "WAIT=0\n" >~/.config/fedokawaii/upkeep.conf'
  press update
  if ! grep -q "Fedora $n is ready: press update again" <<<"$INJ_OUT"; then row BROKEN "the first press never said ready ($(tail -n1 <<<"$INJ_OUT"))"; return 1; fi
  local told; told=$(run "sudo cat $U/move-told"); [[ $told == "$n" ]] || { row BROKEN "move-told: $told"; return 1; }
  run 'sudo rm -f /tmp/press.rc /tmp/press.out; rm -f ~/.config/fedokawaii/upkeep.conf'
  local s=$SECONDS
  press_bg upgrade --now
  # (the restart arranged: stopped right there — everything armed, kept as the state each case starts from)
  local end=$((SECONDS + 7200))
  until run 'test -L /system-update' 2>/dev/null; do
    ((SECONDS < end)) || { press_words; row BROKEN "no restart arranged in two hours: $(tail -n1 <<<"$INJ_OUT")"; return 1; }
    if run 'test -s /tmp/press.rc' 2>/dev/null; then press_words; row BROKEN "the run ended without a restart: $(tail -n3 <<<"$INJ_OUT" | tr '\n' ' ')"; return 1; fi
    sleep 3
  done
  run 'sudo sync' >/dev/null 2>&1
  press_words; cut_power
  bash "$here/vm-snap.sh" "$vm" save armed >>"$log" 2>&1 || { row BROKEN "the state could not be saved"; return 1; }
  row held "armed in $((SECONDS - s)) s"
}
case_green() {
  inj_from_armed() { bash "$here/vm-snap.sh" "$vm" revert armed && virsh -q -c qemu:///session start "fk-$vm"; }
  inj_init "$vm" "$src" move-green
  inj_from_armed >>"$log" 2>&1 || { echo "the VM did not start from armed" >&2; exit 2; }
  local s=$SECONDS
  sleep 60; run --wait 7200 >>"$log" 2>&1 || { row BROKEN "no ssh in two hours"; return 1; }
  bash "$here/vm-snap.sh" "$vm" nice 10 >>"$log" 2>&1
  # (its first ssh may be the offline start's end, before its own restart: until the unit has judged)
  local end=$((SECONDS + 5400)) v
  until [[ $(run "sudo test -e $U/move || echo gone") == gone && $(run '. /etc/os-release; echo "$VERSION_ID"') == "$n" ]]; do
    ((SECONDS < end)) || break
    sleep 10
  done
  run 'sudo journalctl -b -u fedokawaii-after-upgrade.service --no-pager -o cat | sed "s/\x1b\[[0-9;]*[a-zA-Z]//g"' >"$out/after.log" 2>&1
  local t=$((SECONDS - s))
  sleep 30
  facts >/dev/null
  v=$(run '. /etc/os-release; echo "$VERSION_ID"')
  if [[ $v != "$n" ]]; then row BROKEN "still Fedora $v after $t s: $(sed -n '/== report/,/== holds/p' "$out/facts.txt" | sed -n 3p)"; return 1; fi
  # a good start: the desktop, two minutes, the trial over
  run 'grep -q initial_session /etc/greetd/fedokawaii.toml && echo session-kept; sudo systemctl reboot' >>"$log" 2>&1; sleep 25
  run --wait 900 >>"$log" 2>&1
  for _ in $(seq 40); do run "sudo test -e $U/probation" || break; sleep 10; done
  cp "$out/facts.txt" "$out/facts-first-start.txt"
  facts >/dev/null
  press update
  printf 'press after it: %s\n' "$(grep -m1 -E '^.*update done' <<<"$INJ_OUT")" >>"$out/facts.txt"
  local res; res=$(run "sudo cut -d' ' -f4 $U/last-upgrade")
  if run "sudo test -e $U/probation"; then row BROKEN "the trial never closed"; return 1; fi
  grep -q 'dwl up' "$out/facts.txt" && grep -q 'bar up' "$out/facts.txt" || { row BROKEN "no desktop on Fedora $n"; return 1; }
  row held "Fedora $n in $t s ($res), the desktop up, the trial closed; next press: $(run "sudo sed -n 2p $U/report")"
}
case_cut() {
  inj_init "$vm" "$src" move-cut
  { bash "$here/vm-snap.sh" "$vm" revert armed && virsh -q -c qemu:///session start "fk-$vm"; } >>"$log" 2>&1 || exit 2
  # (the offline start has no ssh: its transaction seen from the disk's writes — three minutes of them are well inside it)
  local s=$SECONDS
  sleep 240; cut_power
  { virsh -q -c qemu:///session start "fk-$vm"; } >>"$log" 2>&1
  sleep 60; run --wait 3600 >>"$log" 2>&1 || { row BROKEN "no ssh after the cut"; return 1; }
  bash "$here/vm-snap.sh" "$vm" nice 10 >>"$log" 2>&1
  local end=$((SECONDS + 3600)) v
  until [[ $(run '. /etc/os-release; echo "$VERSION_ID"') == $((n - 1)) && $(run "sudo test -e $U/move || echo gone") == gone ]]; do
    ((SECONDS < end)) || break; sleep 10
  done
  sleep 60; facts >/dev/null
  run 'sudo journalctl -b -1 -u fedokawaii-after-upgrade.service --no-pager -o cat | sed "s/\x1b\[[0-9;]*[a-zA-Z]//g"' >"$out/after.log" 2>&1
  v=$(run '. /etc/os-release; echo "$VERSION_ID"')
  [[ $v == $((n - 1)) ]] || { row BROKEN "on Fedora $v after the cut"; return 1; }
  run "sudo test -e $U/move-red-$n" || { row BROKEN "no red verdict kept"; return 1; }
  grep -q 'dwl up' "$out/facts.txt" || { row BROKEN "no desktop after the way back"; return 1; }
  row held "back on Fedora $v in $((SECONDS - s)) s: $(sed -n '/^== for you/,/^== verify/p' "$out/facts.txt" | sed -n 2p)"
}
case_red() {
  inj_init "$vm" "$src" move-red
  { bash "$here/vm-snap.sh" "$vm" revert armed && virsh -q -c qemu:///session start "fk-$vm"; } >>"$log" 2>&1 || exit 2
  # (the offline start cannot be reached: the break waits in the unit's own drop-in, written into the
  # saved disk through a boot of the armed state would run the transaction — so here: once the new
  # release is up and the unit runs, the bar's binary made unrunnable, as if the release broke it)
  local s=$SECONDS end=$((SECONDS + 5400))
  sleep 60; run --wait 7200 >>"$log" 2>&1 || { row BROKEN "no ssh"; return 1; }
  bash "$here/vm-snap.sh" "$vm" nice 10 >>"$log" 2>&1
  until [[ $(run '. /etc/os-release; echo "$VERSION_ID"') == "$n" ]]; do ((SECONDS < end)) || { row BROKEN "Fedora $n never came up"; return 1; }; sleep 5; done
  run 'sudo chmod 000 /usr/bin/waybar' >>"$log" 2>&1
  end=$((SECONDS + 5400))
  until [[ $(run '. /etc/os-release; echo "$VERSION_ID"') == $((n - 1)) && $(run "sudo test -e $U/move || echo gone") == gone ]]; do
    ((SECONDS < end)) || break; sleep 10
  done
  sleep 60; facts >/dev/null
  run 'sudo journalctl -b -1 -u fedokawaii-after-upgrade.service --no-pager -o cat | sed "s/\x1b\[[0-9;]*[a-zA-Z]//g"' >"$out/after.log" 2>&1
  local v; v=$(run '. /etc/os-release; echo "$VERSION_ID"')
  [[ $v == $((n - 1)) ]] || { row BROKEN "on Fedora $v with a red check"; return 1; }
  grep -q 'bar up' "$out/facts.txt" || { row BROKEN "no bar after the way back"; return 1; }
  row held "red on Fedora $n → back on $v in $((SECONDS - s)) s: $(sed -n '/^== for you/,/^== verify/p' "$out/facts.txt" | sed -n 2p)"
}
for c in "${cases[@]}"; do
  case $c in
    build) build || bad=1 ;;
    green) case_green || bad=1 ;;
    cut) case_cut || bad=1 ;;
    red) case_red || bad=1 ;;
    *) echo "release-move: unknown case $c" >&2; exit 2 ;;
  esac
  bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
done
exit "$bad"
