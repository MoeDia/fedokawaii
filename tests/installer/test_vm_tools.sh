#!/usr/bin/env bash
# tests/installer/test_vm_tools.sh — the test-VM harness's own logic with stand-ins (no VM is
# started): vm-run's ssh (the harness key, the VM's local port, never the owner's keys), vm-snap's
# states (an overlay over the read-only base; save and revert copy the overlay and the UEFI
# variables; fresh = an empty overlay again), and every misuse refused with 2.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
T=$REPO/tools
H=$HOME/VM/harness
mkdir -p "$H/t1" && echo 2299 >"$H/t1/port" && : >"$H/id_ed25519" && : >"$H/t1/base.qcow2" && echo overlay0 >"$H/t1/disk.qcow2"
echo vars0 >"$H/t1/nvram.base.fd" && echo vars-now >"$TMP/vars.fd"
stub ssh 'echo ran'
stub virsh 'case "$*" in *domstate*) echo "shut off" ;; *dumpxml*) echo "<nvram template=\"x\">'"$TMP"'/vars.fd</nvram>" ;; esac'
stub qemu-img 'for a; do f=$a; done; echo fresh-overlay >"$f"'

case_ "vm-run: ssh as dia to 127.0.0.1 on the VM's port with the harness key — and nothing else"
rc 0 bash "$T/vm-run.sh" t1 uname -a
called "ssh -q -o BatchMode=yes .* -i $H/id_ed25519 -p 2299 dia@127.0.0.1 uname -a"
not_called "\.ssh/id_"
case_ "vm-snap: save keeps the overlay and the UEFI variables; revert puts them back; fresh = a new overlay"
rc 0 bash "$T/vm-snap.sh" t1 save s1
eq "$(cat "$H/t1/state-s1.qcow2") $(cat "$H/t1/state-s1.fd")" "overlay0 vars-now"
echo changed >"$H/t1/disk.qcow2"; echo vars-changed >"$TMP/vars.fd"
rc 0 bash "$T/vm-snap.sh" t1 revert s1
eq "$(cat "$H/t1/disk.qcow2") $(cat "$TMP/vars.fd")" "overlay0 vars-now"
rc 0 bash "$T/vm-snap.sh" t1 revert fresh
eq "$(cat "$H/t1/disk.qcow2") $(cat "$TMP/vars.fd")" "fresh-overlay vars0"
called "qemu-img create -q -f qcow2 -b $H/t1/base.qcow2 -F qcow2 $H/t1/disk.qcow2"
eq "$(bash "$T/vm-snap.sh" t1 list)" "s1"
rc 1 bash "$T/vm-snap.sh" t1 revert nosuch
case_ "misuse: 2 (no such VM, bad names, no command)"
rc 2 bash "$T/vm-snap.sh" nosuch list
rc 2 bash "$T/vm-snap.sh" t1 save "Bad Name"
rc 2 bash "$T/vm-snap.sh" t1 save fresh
rc 2 bash "$T/vm-snap.sh" t1 frobnicate
rc 2 bash "$T/vm-run.sh" t1
rc 2 bash "$T/vm-run.sh" nosuch true
rc 2 bash "$T/vm-create.sh" "Bad Name"
rc 2 bash "$T/vm-smoke.sh" nosuch
done_
