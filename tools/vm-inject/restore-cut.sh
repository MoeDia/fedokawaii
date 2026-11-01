#!/usr/bin/env bash
# tools/vm-inject/restore-cut.sh — `kawa-snap restore` cut by a power loss after each of its steps
# (and once in the middle of putting a kernel back), in the harness VM (tools/vm-create.sh;
# update-design.md §3.1, §5 row 41). The snapshot restored has ANOTHER kernel than the running
# system: made once from "built" and kept as the VM state "two-kernels" — kernel A (the install's)
# in snapshot S, then kernel B installed, started, and A removed from the system (so restoring S
# must put A back into /boot and make it the default). For each step the VM starts from that state,
# gets this repository's toolkit and kawa-snap, marks its running root and restores S with
# KAWA_SNAP_CUT=STEP (an instant restart, nothing synced: sysrq b — the guest's page cache is lost,
# what the host already took is not: the cut model of a lost plug for the OS, not for a disk cache).
# After it starts again, asserted and logged: it started; which system runs (the marked one before
# the exchange, the snapshot after it); the kernel it runs has its modules (a start under B on the
# restored root is put right by setup.sh's kernel_match: the default back to A, one more start);
# then a restore run again finishes a cut one; at the end A is the default, whole in /boot, no
# root.new, root.old kept, kawa-snap list answers. Last: `restore old` back to the marked system.
#   bash tools/vm-inject/restore-cut.sh [VM] [STEP…]   (VM f44; STEPs: copied kernels exchanged
#                                                       defaulted moved renamed adding, then old)
# Out: a table on stdout, every check's output in /dev/shm/r27/restore-cut/STEP.log.
# Exit 0 every step ended in a whole system · 1 one did not · 2 the VM could not run.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
vm=${1:-f44}; shift 2>/dev/null || true
steps=("$@"); ((${#steps[@]})) || steps=(copied kernels exchanged defaulted moved renamed adding old)
out=/dev/shm/r27/restore-cut; mkdir -p "$out"
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
log=/dev/null
say() { printf '%s\n' "$*" >>"$log"; }
chk() { local o; o=$(run "$1" 2>&1); printf '$ %s\n%s\n' "$1" "$o" >>"$log"; printf '%s' "$o"; }
[[ -d $HOME/VM/harness/$vm ]] || { echo "restore-cut: no VM $vm" >&2; exit 2; }
toolkit() {   # this repository's toolkit and kawa-snap into the VM (what apply would install of them)
  run --repo >>"$log" 2>&1 && run 'sudo cp -a ~/fedokawaii/. /usr/local/lib/fedokawaii/ && sudo install -m 755 ~/fedokawaii/system/kawa-snap /usr/local/sbin/kawa-snap' >>"$log" 2>&1
}
boot() { bash "$here/vm-snap.sh" "$vm" start >>"$log" 2>&1 && run --wait 600 >>"$log" 2>&1; }

# ── the state "two-kernels", once ────────────────────────────────────────────────────────────
if ! bash "$here/vm-snap.sh" "$vm" list 2>/dev/null | grep -qx two-kernels; then
  log=$out/prepare.log; : >"$log"
  { bash "$here/vm-snap.sh" "$vm" revert built && boot; } || { echo "restore-cut: the VM did not start" >&2; exit 2; }
  toolkit || { echo "restore-cut: the toolkit could not go in" >&2; exit 2; }
  # (/boot's drivers in every boot image, as setup.sh s_kernels writes it; and — for this harness
  # only — the VM's network driver too, so ssh answers even under a kernel without its modules)
  run 'printf "force_drivers+=\" xfs vfat \"\n" | sudo tee /etc/dracut.conf.d/fedokawaii.conf >/dev/null
       printf "force_drivers+=\" virtio_net net_failover failover \"\n" | sudo tee /etc/dracut.conf.d/zz-vm-harness.conf >/dev/null' >>"$log" 2>&1
  A=$(chk 'uname -r'); say "A=$A"
  S=$(chk 'sudo snapper -c root create -t single -p -d restore-cut' | tr -dc 0-9); say "S=$S"
  run 'sudo dnf -y -q upgrade "kernel*" >/dev/null 2>&1; rpm -q kernel-core' >>"$log" 2>&1
  B=$(chk 'rpm -q --qf "%{version}-%{release}.%{arch}\n" kernel-core | sort -V | tail -n1'); say "B=$B"
  [[ -n $A && -n $B && $A != "$B" && -n $S ]] || { echo "restore-cut: no second kernel to install (A=$A B=$B S=$S)" >&2; exit 2; }
  run "sudo grubby --set-default /boot/vmlinuz-$B && sudo systemctl reboot" >>"$log" 2>&1; sleep 25
  run --wait 600 >>"$log" 2>&1 || { echo "restore-cut: B did not start" >&2; exit 2; }
  [[ $(chk 'uname -r') == "$B" ]] || { echo "restore-cut: B is not running" >&2; exit 2; }
  run "sudo dnf -y -q remove kernel-core-$A kernel-modules-$A kernel-modules-core-$A kernel-$A >/dev/null 2>&1; ls /boot /usr/lib/modules" >>"$log" 2>&1
  [[ $(chk "[ -e /boot/vmlinuz-$A ] || [ -d /usr/lib/modules/$A ] && echo left || echo gone") == gone ]] \
    || { echo "restore-cut: kernel A is still on the system" >&2; exit 2; }
  printf 'A=%s\nB=%s\nS=%s\n' "$A" "$B" "$S" | run 'cat >~/restore-cut.env'
  bash "$here/vm-snap.sh" "$vm" save two-kernels >>"$log" 2>&1 || { echo "restore-cut: the state could not be kept" >&2; exit 2; }
fi

bad=0
printf '%-10s %-6s %-9s %-14s %-8s %-7s %s\n' STEP START RUNNING KERNEL DEFAULT AFTER RESULT
for st in "${steps[@]}"; do
  log=$out/$st.log; : >"$log"
  { bash "$here/vm-snap.sh" "$vm" revert two-kernels && boot; } || { echo "restore-cut: the VM did not start" >&2; exit 2; }
  eval "$(chk 'cat ~/restore-cut.env')"
  toolkit >>"$log" 2>&1
  run 'echo live | sudo tee /etc/fk-cut-marker >/dev/null; sudo touch /run/kawa-snap.cut; sync' >>"$log" 2>&1
  want=snapshot; [[ $st == @(copied|kernels|adding) ]] && want=marked   # (exchanged: cut after its sync — the restored root under the old default kernel)
  case $st in
    old)    # (a whole restore of S, a start, then restore old: back to the marked system and B)
            chk "sudo kawa-snap restore $S --with-home" >/dev/null; run 'sudo systemctl reboot' >>"$log" 2>&1; sleep 25; run --wait 300 >>"$log" 2>&1
            say "after the first restore: $(chk 'uname -r; cat /etc/fk-cut-marker 2>/dev/null || echo snapshot')"
            chk 'sudo kawa-snap restore old --with-home' >/dev/null; run 'sudo systemctl reboot' >>"$log" 2>&1; sleep 25
            want=marked A=$B ;;     # (after restore old: the marked system, its own kernel B)
    adding) # (the cut in the middle of the kernel's add: a watcher inside the VM restarts it 3 s
            # after dracut began making A's image — ssh is too slow to catch a 15-second build)
            run "sudo setsid -f bash -c 'for i in \$(seq 900); do pgrep -f \"[d]racut-install\" >/dev/null && { sleep 3; echo b >/proc/sysrq-trigger; }; sleep 0.1; done'
                 sudo setsid -f bash -c 'kawa-snap restore $S --with-home >/tmp/r.log 2>&1'" >>"$log" 2>&1
            sleep 60
            say "/boot after the cut: $(chk "ls /boot | grep -c -- '$A'; sudo sh -c 'ls /boot/loader/entries | grep -c -- $A'")" ;;
    *)      timeout 300 bash "$here/vm-run.sh" "$vm" "sudo KAWA_SNAP_CUT=$st /usr/local/sbin/kawa-snap restore $S --with-home" >>"$log" 2>&1
            sleep 25 ;;
  esac
  if ! run --wait 300 >>"$log" 2>&1; then
    printf '%-10s %-6s\n' "$st" NO; bad=1; bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1; continue
  fi
  running=$(chk '[ -e /etc/fk-cut-marker ] && echo marked || echo snapshot')
  kern=$(chk 'k=$(uname -r); [ -d /lib/modules/$k ] && echo "$k" || echo "$k-nomod"')
  # (a start under a kernel the restored root has no modules for: kernel_match, then one more start)
  if [[ $kern == *-nomod ]]; then
    chk 'sudo bash /usr/local/lib/fedokawaii/setup.sh --kernels; sudo grubby --default-kernel' >/dev/null
    run 'sudo systemctl reboot' >>"$log" 2>&1; sleep 25; run --wait 300 >>"$log" 2>&1
    kern="$(chk 'k=$(uname -r); [ -d /lib/modules/$k ] && echo "$k" || echo "$k-nomod"')(healed)"
  fi
  # (a cut one finished by the next restore — or, when the cut left nothing to finish, a whole restore)
  after=-
  if [[ $st == @(copied|kernels|adding|exchanged|defaulted|moved|renamed) ]]; then
    o=$(chk "sudo kawa-snap restore $S --with-home; echo rc=\$?"); after=${o##*rc=}
    if [[ $o != *"restore cut short after its exchange is finished"* ]]; then   # (a whole restore ran: start it)
      run 'sudo systemctl reboot' >>"$log" 2>&1; sleep 25; run --wait 300 >>"$log" 2>&1
    fi
  fi
  def=$(chk 'sudo grubby --default-kernel'); def=${def##*/vmlinuz-}
  end=$(chk "uname -r; sudo sh -c '[ -s /boot/initramfs-$A.img ] && ls /boot/loader/entries/*-$A.conf' >/dev/null 2>&1 && echo whole
            sudo mount -o subvolid=5 \$(findmnt -no SOURCE / | sed 's/\\[.*//') /mnt && { [ -d /mnt/root.new ] && echo new; [ -d /mnt/root.old ] && echo old; sudo umount /mnt; }
            sudo kawa-snap list >/dev/null && echo listed")
  say "end: $end"
  result=ok
  [[ $running == "$want" ]] || result="ran $running"
  [[ ${def:-?} == "$A" ]] || result+=" default ${def:-?}"
  [[ $end == *whole* && $end == *old* && $end != *new* && $end == *listed* && $end == "$A"* ]] || result+=" end: $(tr '\n' ' ' <<<"$end")"
  [[ $result == ok ]] || bad=1
  printf '%-10s %-6s %-9s %-14s %-8s %-7s %s\n' "$st" ok "$running" "${kern:0:14}" "${def:0:8}" "${after:-?}" "$result"
  bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
done
echo "(RUNNING right after the cut: marked = the system before the restore, snapshot = the restored one; AFTER: the next restore's exit; at the end the restored kernel is the default, whole in /boot, root.old kept, no root.new)"
exit "$bad"
