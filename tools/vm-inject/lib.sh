# shellcheck shell=bash
# tools/vm-inject/lib.sh — what the failure injections share (T49; sourced). Each row starts its VM
# from a saved state, breaks one thing, presses the button as Super+U presses it, restores nothing by
# hand, and reads the end state: the report, the notice, the machine's facts.
#   inj_init VM SRC NAME   the VM, the frozen tree the toolkit comes from, the evidence's folder
#   inj_from STATE         that state, started, at low priority (the PC comes first)
#   run CMD… | run --wait  in the VM, as dia (tools/vm-run.sh)
#   press [ARGS]           the button: fedokawaii.sh update (or upgrade ARGS), detached, followed to
#                          its end; INJ_RC its status, INJ_OUT its words without colours
#   press_bg [ARGS]        the same, not followed (press_wait: until the unit is gone)
#   phase_is WORD [S]      until the run's phase is WORD (S seconds, 900)
#   cut                    the power gone, now
#   facts                  the end state, for the evidence: report, phase, snapshots, kernels, holds, verify
#   row OK|BROKEN WHAT     the row's line, its status in INJ_BAD
set -u
inj_init() {
  vm=$1 src=$2 out=/dev/shm/r27/inject/$3 name=$3
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  rm -rf "$out"; mkdir -p "$out"; log=$out/run.log; : >"$log"; INJ_BAD=0
}
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
inj_from() {
  { bash "$here/vm-snap.sh" "$vm" revert "$1" && bash "$here/vm-snap.sh" "$vm" start && bash "$here/vm-snap.sh" "$vm" nice 10; } >>"$log" 2>&1 \
    || { echo "$name: the VM did not start from $1" >&2; exit 2; }
}
INJ_RC=""; INJ_OUT=""
press_bg() {   # (detached: a move restarts the VM under it)
  local a=(update); (($#)) && a=("$@")
  run "sudo setsid -f bash -c 'FK_TERM=dumb bash /usr/local/lib/fedokawaii/fedokawaii.sh ${a[*]} >/tmp/press.out 2>&1; echo \$? >/tmp/press.rc' </dev/null >/dev/null 2>&1; sleep 2" >>"$log" 2>&1
}
press_wait() {   # press_wait [S] → 0 ended · 1 not within S seconds (3600)
  local end=$((SECONDS + ${1:-3600}))
  while ((SECONDS < end)); do
    run 'test -s /tmp/press.rc' 2>/dev/null && { INJ_RC=$(run 'cat /tmp/press.rc'); press_words; return 0; }
    sleep 5
  done
  press_words; return 1
}
press_words() { INJ_OUT=$(run 'sed "s/\x1b\[[0-9;]*[a-zA-Z]//g" /tmp/press.out' 2>/dev/null); printf '%s\n' "$INJ_OUT" >"$out/press.out"; }
press() { run 'sudo rm -f /tmp/press.rc /tmp/press.out' >>"$log" 2>&1; press_bg "$@"; press_wait; }
phase_is() {   # phase_is WORD [S]
  local end=$((SECONDS + ${2:-900}))
  while ((SECONDS < end)); do
    [[ $(run 'sudo cut -d" " -f1 /var/lib/fedokawaii/update/phase 2>/dev/null') == "$1" ]] && return 0
    sleep 1
  done
  return 1
}
cut_power() { virsh -q -c qemu:///session destroy "fk-$vm" >>"$log" 2>&1; }
restart_vm() { bash "$here/vm-snap.sh" "$vm" start >>"$log" 2>&1 && bash "$here/vm-snap.sh" "$vm" nice 10 >>"$log" 2>&1; }
facts() {
  run 'U=/var/lib/fedokawaii/update
    echo "== release $(. /etc/os-release; echo "$VERSION_ID") · kernel $(uname -r) · $(rpm -q kernel-core | tr "\n" " ")"
    for f in phase report holds snap probation move move-told last-upgrade why; do echo "== $f"; sudo cat "$U/$f" 2>/dev/null; done
    echo "== for you"; for f in ~/.local/state/fedokawaii/for-you/*; do [[ -f $f ]] && { echo "${f##*/}: $(tr "\n" " " <"$f")"; }; done
    echo "== verify"; sudo cat /var/lib/fedokawaii/last-verify 2>/dev/null; sudo cat /var/lib/fedokawaii/last-verify-fails 2>/dev/null | head -n 20
    echo "== snapshots"; sudo snapper -c root list --columns number,cleanup,description | tail -n 6
    echo "== versionlock"; sudo dnf -q versionlock list 2>/dev/null | head -n 20
    echo "== copy left"; sudo btrfs subvolume list / | grep -c "root.cand"
    echo "== desktop"; pgrep -x dwl >/dev/null && echo "dwl up"; pgrep -x waybar >/dev/null && echo "bar up"' 2>&1 | tee "$out/facts.txt"
}
row() {
  printf '%-22s %-7s %s\n' "$name" "$1" "$2" | tee -a "$out/row"
  [[ $1 == held ]] || INJ_BAD=1
}
