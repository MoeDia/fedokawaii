#!/usr/bin/env bash
# tools/vm-inject/restore-cut.sh — `kawa-snap restore` cut by a power loss after each of its steps,
# in the harness VM (tools/vm-create.sh; update-design.md §3.1, §5 row 41): for each step the VM
# starts from its "built" state, gets this repository's kawa-snap, takes a snapshot, marks its
# running root, and restores with KAWA_SNAP_CUT=STEP (an instant restart, nothing synced). After
# it starts again: did it start, which system runs (the marked one or the snapshot), are the
# snapshots there (after one more restore when a cut left them in root.new — kawa-snap finishes
# that), does the running kernel have its modules.
#   bash tools/vm-inject/restore-cut.sh [VM] [STEP…]    (VM: f44; STEPs: all six)
# Out: a table on stdout, the runs' logs in /dev/shm/r27/restore-cut/. Exit 0 every step ended
# in a whole system · 1 one did not · 2 the VM could not run.
set -u
here=$(cd "$(dirname "$0")/.." && pwd); repo=$(cd "$here/.." && pwd)
vm=${1:-f44}; shift 2>/dev/null || true
steps=("$@"); ((${#steps[@]})) || steps=(copied kernels exchanged moved renamed defaulted)
out=/dev/shm/r27/restore-cut; mkdir -p "$out"
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
port=$(cat "$HOME/VM/harness/$vm/port" 2>/dev/null) || { echo "restore-cut: no VM $vm" >&2; exit 2; }
push() { scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$HOME/VM/harness/id_ed25519" -P "$port" "$1" "dia@127.0.0.1:$2"; }
bad=0
printf '%-10s %-6s %-9s %-10s %-7s\n' STEP START RUNNING SNAPSHOTS KERNEL
for st in "${steps[@]}"; do
  log=$out/$st.log; : >"$log"
  { bash "$here/vm-snap.sh" "$vm" revert built && bash "$here/vm-snap.sh" "$vm" start && run --wait 600; } >>"$log" 2>&1 || { echo "restore-cut: the VM did not start" >&2; exit 2; }
  push "$repo/system/kawa-snap" /tmp/kawa-snap >>"$log" 2>&1 && run 'sudo install -m 755 /tmp/kawa-snap /usr/local/sbin/kawa-snap' >>"$log" 2>&1
  n=$(run 'sudo snapper -c root create -t single -p -d restore-cut' 2>>"$log" | tr -dc 0-9)
  run 'echo live | sudo tee /etc/fk-cut-marker >/dev/null; sync' >>"$log" 2>&1
  # the restore, cut: the VM restarts at once (ssh drops); then wait for it again
  timeout 90 bash "$here/vm-run.sh" "$vm" "sudo KAWA_SNAP_CUT=$st /usr/local/sbin/kawa-snap restore $n" >>"$log" 2>&1
  sleep 20
  if run --wait 300 >>"$log" 2>&1; then
    start=ok
    running=$(run '[ -e /etc/fk-cut-marker ] && echo marked || echo snapshot' 2>>"$log")
    snaps=$(run 'sudo snapper -c root list 2>/dev/null | grep -c restore-cut' 2>>"$log")
    if [[ ${snaps:-0} -lt 1 ]]; then   # (left in root.new by a cut after the exchange: finished by the next restore)
      run "sudo /usr/local/sbin/kawa-snap restore $n" >>"$log" 2>&1
      snaps=$(run 'sudo snapper -c root list 2>/dev/null | grep -c restore-cut' 2>>"$log"); snaps="${snaps:-0}*"
    fi
    kern=$(run '[ -d /lib/modules/$(uname -r) ] && echo ok || echo missing' 2>>"$log")
  else start=NO running=- snaps=- kern=-; fi
  printf '%-10s %-6s %-9s %-10s %-7s\n' "$st" "$start" "${running:-?}" "${snaps:-?}" "${kern:-?}"
  [[ $start == ok && ${snaps%\*} -ge 1 && $kern == ok ]] || bad=1
  bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
done
echo "(SNAPSHOTS: the restore-cut snapshot listed by snapper; * = after the next restore finished a cut one)"
exit "$bad"
