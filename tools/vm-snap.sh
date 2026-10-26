#!/usr/bin/env bash
# tools/vm-snap.sh — a test VM's states (tools/vm-create.sh): its disk is an overlay over the
# fresh install (base.qcow2, never written); a saved state is a copy of that overlay and of the
# UEFI variables (reflink copies on Btrfs: instant, no space until they differ). Simpler than
# libvirt's snapshots, which UEFI guests' internal snapshots do not support.
#   bash tools/vm-snap.sh NAME start | stop          on (and ssh answers) · off (ACPI, then forced after 60 s)
#   bash tools/vm-snap.sh NAME save STATE            the VM stopped and its state kept as STATE
#   bash tools/vm-snap.sh NAME revert fresh|STATE    back to the fresh install, or to STATE (stopped)
#   bash tools/vm-snap.sh NAME list                  the saved states
#   bash tools/vm-snap.sh NAME destroy               the VM and every file of it gone
# Exit 0 · 1 it could not · 2 misuse.
set -u
H=$HOME/VM/harness
V=(virsh -q -c qemu:///session)
name=${1:-} act=${2:-} st=${3:-}
D=$H/$name dom=fk-$name
[[ $name =~ ^[a-z0-9-]+$ && -d $D ]] || { echo "usage: bash tools/vm-snap.sh NAME start|stop|save S|revert fresh|S|list|destroy" >&2; exit 2; }
nvram() { "${V[@]}" dumpxml "$dom" 2>/dev/null | sed -n 's|.*<nvram[^>]*>\(.*\)</nvram>.*|\1|p'; }
running() { [[ $("${V[@]}" domstate "$dom" 2>/dev/null) == running ]]; }
stop() {
  running || return 0
  "${V[@]}" shutdown "$dom" >/dev/null 2>&1
  for _ in $(seq 60); do running || return 0; sleep 1; done
  "${V[@]}" destroy "$dom" >/dev/null 2>&1
  ! running
}
case $act in
  start)
    running || "${V[@]}" start "$dom" >/dev/null || exit 1
    bash "$(dirname "$0")/vm-run.sh" "$name" --wait 600 ;;
  stop) stop || exit 1 ;;
  save)
    [[ $st =~ ^[a-z0-9-]+$ && $st != fresh ]] || { echo "vm-snap: a state's name: letters, digits, dashes (not fresh)" >&2; exit 2; }
    stop || exit 1
    cp --reflink=auto "$D/disk.qcow2" "$D/state-$st.qcow2" && cp --reflink=auto "$(nvram)" "$D/state-$st.fd" || exit 1 ;;
  revert)
    stop || exit 1
    if [[ $st == fresh ]]; then
      rm -f "$D/disk.qcow2" && qemu-img create -q -f qcow2 -b "$D/base.qcow2" -F qcow2 "$D/disk.qcow2" || exit 1
      cp --reflink=auto "$D/nvram.base.fd" "$(nvram)" || exit 1
    else
      [[ -f $D/state-$st.qcow2 ]] || { echo "vm-snap: no state $st (vm-snap.sh $name list)" >&2; exit 1; }
      cp --reflink=auto "$D/state-$st.qcow2" "$D/disk.qcow2" && cp --reflink=auto "$D/state-$st.fd" "$(nvram)" || exit 1
    fi ;;
  list) for f in "$D"/state-*.qcow2; do [[ -f $f ]] && { f=${f##*/state-}; echo "${f%.qcow2}"; }; done; exit 0 ;;
  destroy)
    "${V[@]}" destroy "$dom" >/dev/null 2>&1
    "${V[@]}" undefine --nvram "$dom" >/dev/null 2>&1
    rm -rf -- "$D" ;;
  *) echo "usage: bash tools/vm-snap.sh NAME start|stop|save S|revert fresh|S|list|destroy" >&2; exit 2 ;;
esac
