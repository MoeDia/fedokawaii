#!/usr/bin/env bash
# tools/vm-inject/overlay-restore.sh — a snapshot started as the boot menu starts it (on a layer in
# memory: systemd.volatile=overlay), then made the system from there with `kawa-snap restore`
# (update-design.md §3.1, the master's T48 finding 12; T48's "read-only snapshot boot"). In the
# harness VM from "built": the flat layout made (setup.sh --layout, a start, clean), snapshot S
# taken, then a mark written to the running system (/etc/fk-marker) and his files made. The start
# into S uses the very kernel line grub-btrfs wrote for S (/boot/grub2/grub-btrfs.cfg), in a
# one-time boot entry chosen by grub2-reboot — the menu's own path, without its keys.
# Asserted in S: / an overlay, no mark (the system as S had it), /home today's (his files, mounted
# from home), kawa-snap list marks S booted; after `kawa-snap restore S` (no --with-home) and a
# start: / the root subvolume again, still no mark, his files the same, the layout flat, the
# one-time entry gone.
#   bash tools/vm-inject/overlay-restore.sh [VM]   (VM f44)
# Out: a summary on stdout, the log in /dev/shm/r27/overlay-restore.log. Exit 0 whole · 1 not · 2 the VM.
# shellcheck disable=SC2015  # (A && yes || no: yes only prints, it never fails)
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
vm=${1:-f44}
log=/dev/shm/r27/overlay-restore.log; mkdir -p "${log%/*}"; : >"$log"
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
chk() { local o; o=$(run "$1" 2>&1); printf '$ %s\n%s\n' "$1" "$o" >>"$log"; printf '%s' "$o"; }
restart() { run 'sudo systemctl reboot' >>"$log" 2>&1; sleep 25; run --wait 900 >>"$log" 2>&1; }
bad=0; no() { echo "  ✘ $*"; bad=1; }; yes() { echo "  ✔ $*"; }
{ bash "$here/vm-snap.sh" "$vm" revert built && bash "$here/vm-snap.sh" "$vm" start && run --wait 600; } >>"$log" 2>&1 \
  || { echo "overlay-restore: the VM did not start" >&2; exit 2; }
{ run --repo && run 'sudo cp -a ~/fedokawaii/. /usr/local/lib/fedokawaii/ && sudo install -m 755 ~/fedokawaii/system/kawa-snap /usr/local/sbin/kawa-snap'; } >>"$log" 2>&1 \
  || { echo "overlay-restore: the toolkit could not go in" >&2; exit 2; }
# the flat layout first (the PC's from now on)
[[ $(chk 'sudo bash /usr/local/lib/fedokawaii/setup.sh --layout >/dev/null 2>&1; sudo fedokawaii-split state') == armed ]] \
  || { echo "overlay-restore: the split was not armed" >&2; exit 2; }
restart || { echo "overlay-restore: no start after the split" >&2; exit 2; }
[[ $(chk 'sudo bash /usr/local/lib/fedokawaii/setup.sh --layout >/dev/null 2>&1; sudo fedokawaii-split state') == flat ]] \
  && yes "the layout flat, its old copies cleaned" || no "the layout: not flat"
# S, then the running system moves on: a mark in it, his files in /home
S=$(chk 'sudo snapper -c root create -t single -p -d overlay-restore' | tr -dc 0-9)
run 'echo live | sudo tee /etc/fk-marker >/dev/null; mkdir -p ~/today; head -c 1M /dev/urandom >~/today/f; sync' >>"$log" 2>&1
# shellcheck disable=SC2016  # (expanded in the VM)
files='cd ~ && find today -type f -print0 | sort -z | xargs -0 sha256sum'
before=$(chk "$files")
# the one-time entry: grub-btrfs's own kernel line for S
cfg=$(chk 'sudo kawa-snap boot >/dev/null; sudo cat /boot/grub2/grub-btrfs.cfg')
line=$(grep -F "snapshots/$S/snapshot\"" <<<"$cfg" | grep -E '^[[:space:]]*linux ' | head -n1)
kern=$(sed -E 's/^[[:space:]]*linux[[:space:]]+"([^"]+)".*/\1/' <<<"$line")
opts=$(sed -E 's/^[[:space:]]*linux[[:space:]]+"[^"]+"[[:space:]]*//' <<<"$line")
[[ $kern == /vmlinuz-* && $opts == *systemd.volatile=overlay* && $opts == *"snapshots/$S/snapshot"* ]] \
  || { echo "overlay-restore: no boot menu entry for snapshot $S (grub-btrfs.cfg)" >&2; exit 1; }
k=${kern#/vmlinuz-}
run "printf 'title snapshot $S (overlay-restore)\nversion $k\nlinux $kern\ninitrd /initramfs-$k.img\noptions %s\n' '$opts' | sudo tee /boot/loader/entries/fk-overlay.conf >/dev/null && sudo grub2-reboot fk-overlay" >>"$log" 2>&1
restart || { echo "overlay-restore: snapshot $S did not start" >&2; exit 1; }
# (the one-time entry gone at once, as a key press leaves none: it names the same kernel file as
# the real entry, and `grubby --set-default /boot/vmlinuz-K` in the restore could pick it)
run 'sudo rm -f /boot/loader/entries/fk-overlay.conf' >>"$log" 2>&1
# shellcheck disable=SC2016  # (expanded in the VM)
in=$(chk 'findmnt -no FSTYPE /; cat /etc/fk-marker 2>/dev/null || echo no-mark; findmnt -no SOURCE /home; sudo kawa-snap list | awk -F"\t" "\$5 == \"booted\" { print \"booted=\" \$1 }"')
[[ $(sed -n 1p <<<"$in") == overlay ]] && yes "snapshot $S started on a layer in memory" || no "/ is not an overlay: $(sed -n 1p <<<"$in")"
[[ $in == *no-mark* ]] && yes "the system as S had it (no mark)" || no "the mark is there: not S"
[[ $in == *"[/home]"* ]] && yes "/home from its subvolume" || no "/home not mounted from home"
[[ $in == *"booted=$S"* ]] && yes "kawa-snap list marks $S booted" || no "kawa-snap list: no booted mark for $S"
[[ $(chk "$files") == "$before" ]] && yes "his files today's in S" || no "his files differ in S"
r=$(chk "sudo kawa-snap restore $S 2>&1 | tail -n 1; echo rc=\${PIPESTATUS[0]}")
[[ $r == *rc=0* ]] && yes "kawa-snap restore $S from inside S" || no "the restore from S: $r"
restart || { echo "overlay-restore: no start after the restore" >&2; exit 1; }
end=$(chk 'findmnt -no FSTYPE,SOURCE /; cat /etc/fk-marker 2>/dev/null || echo no-mark; sudo fedokawaii-split state; sudo grub2-editenv list | grep saved_entry')
[[ $end == "btrfs "*"[/root]"* ]] && yes "/ the root subvolume again" || no "/ after the restore: $(sed -n 1p <<<"$end")"
[[ $end == *no-mark* ]] && yes "the restored system is S (no mark)" || no "the mark survived the restore"
[[ $end == *$'\n'flat* ]] && yes "the layout flat" || no "the layout after the restore: not flat"
[[ $(chk "$files") == "$before" ]] && yes "his files the same after the restore" || no "his files changed with the restore"
bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
exit "$bad"
