#!/usr/bin/env bash
# tools/vm-inject/split-cut.sh — the disk's flat layout (system/fedokawaii-split) made in the harness
# VM, whole and cut by a power loss at each of its steps, and put back whole after a failure
# (update-design.md §3, §5 row split-cut). Each case starts from the VM state "built" (Fedora's
# one-subvolume layout, a full fedokawaii install), gets this repository's toolkit, his files in
# /home (a plain file, a name with a space, one with a newline, a hard-linked pair, a symlink, a
# fifo, a NOCOW file, an xattr, 64 MiB of noise), a file in ~/Downloads and in ~/VM (subvolumes),
# then setup.sh --layout arms the split and the VM restarts with $D/cut = STEP (a power cut at STEP
# in the first start) or fail-STEP (a failure there: all of it put back).
# Asserted after the VM is up again: his files with their checksums, the hard link, the fifo; for a
# split: the layout flat, ~/Downloads and ~/VM inside home and whole, fstab's four lines, the
# journal on the new log subvolume, snapper lists and makes snapshots in the new place, kawa-snap
# lists them, the boot menu's list names snapshots/N, a resumed split said "start 2" in its log;
# then `fedokawaii-split clean` (the hidden copies gone, no subvolume touched); case "none" also
# restores a snapshot from before the split (no --with-home: his files stay today's). For a
# failure: the old layout, Downloads and VM back in root, split.failed with the reason, and
# setup.sh --layout does not arm the same split again.
#   bash tools/vm-inject/split-cut.sh [VM] [STEP…]   (VM f44; STEPs: none part-home copied-home
#                     copied-log copied-fk moved snapshots fstab fail-copied-home fail-fstab)
# Out: a table on stdout, each case's log in /dev/shm/r27/split-cut/STEP.log.
# Exit 0 every case ended whole · 1 one did not · 2 the VM could not run.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
vm=${1:-f44}; shift 2>/dev/null || true
steps=("$@"); ((${#steps[@]})) || steps=(none part-home copied-home copied-log copied-fk moved snapshots fstab fail-copied-home fail-fstab)
out=/dev/shm/r27/split-cut; mkdir -p "$out"
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
log=/dev/null
say() { printf '%s\n' "$*" >>"$log"; }
chk() { local o; o=$(run "$1" 2>&1); printf '$ %s\n%s\n' "$1" "$o" >>"$log"; printf '%s' "$o"; }
[[ -d $HOME/VM/harness/$vm ]] || { echo "split-cut: no VM $vm" >&2; exit 2; }
restart() { run 'sudo systemctl reboot' >>"$log" 2>&1; sleep 25; run --wait 900 >>"$log" 2>&1; }
# his files, read back: a name, size and checksum per file (the noise's too), the links and the fifo
# shellcheck disable=SC2016  # (run in the VM: its shell expands them)
files='cd ~ && find splitdata Downloads/split VM/split -printf "%y %s %p\n" 2>&1 | sort
       find splitdata Downloads/split VM/split -type f -print0 2>/dev/null | sort -z | xargs -0 sha256sum
       stat -c "%h %n" splitdata/plain; getfattr -n user.fk --only-values splitdata/plain 2>&1; echo
       [ -p splitdata/fifo ] && [ -L splitdata/symlink ] && echo fifo-and-link'
make_files='set -e; cd ~; mkdir -p splitdata; printf "a\n" >splitdata/plain; printf "b\n" >"splitdata/with space"
  printf "c\n" >"splitdata/new
line"; ln splitdata/plain splitdata/hardlink; ln -s plain splitdata/symlink; mkfifo splitdata/fifo
  touch splitdata/nocow; chattr +C splitdata/nocow 2>/dev/null || true; head -c 8M /dev/urandom >splitdata/nocow
  rpm -q attr >/dev/null || sudo dnf -y -q install attr >/dev/null; setfattr -n user.fk -v kept splitdata/plain
  head -c 64M /dev/urandom >splitdata/noise
  btrfs subvolume show Downloads >/dev/null 2>&1 || { rmdir Downloads 2>/dev/null || true; btrfs subvolume create Downloads; }
  btrfs subvolume show VM >/dev/null 2>&1 || btrfs subvolume create VM
  mkdir -p Downloads/split VM/split; head -c 4M /dev/urandom >Downloads/split/d; head -c 4M /dev/urandom >VM/split/v; sync'
# shellcheck disable=SC2016
failed='sudo cat /var/lib/fedokawaii/split.failed; sudo btrfs subvolume list / | sed -n "s/.* path //p"
  sudo snapper -c root list >/dev/null && echo snapper-ok; [ -e /system-update ] && echo armed-still
  sudo bash /usr/local/lib/fedokawaii/setup.sh --layout 2>&1 | tail -n 4; echo "state=$(sudo fedokawaii-split state)"'
# shellcheck disable=SC2016
split='sudo btrfs subvolume list -a / | sed -n "s/.* path //p"
  echo "fstab=$(grep -cE "subvol=(home|log|fk|snapshots)," /etc/fstab)"
  echo "journal=$(findmnt -no SOURCE -T /var/log/journal)"; journalctl -b -n 1 -q --no-pager >/dev/null && echo journal-ok
  n=$(sudo snapper -c root create -p -d split-cut) && sudo test -d /.snapshots/$n/snapshot && echo "snap-ok $n"
  echo "listed=$(sudo kawa-snap list | wc -l)"
  echo "grub=$(sudo grep -c "subvol=.snapshots/" /boot/grub2/grub-btrfs.cfg) stale=$(sudo grep -c "subvol=\"root/.snapshots/" /boot/grub2/grub-btrfs.cfg)"   # (the split lists them itself)
  sudo cat /var/log/fedokawaii-split.log'
# shellcheck disable=SC2016
clean='sudo fedokawaii-split clean; sudo fedokawaii-split state
  sudo mount -o subvolid=5 "$(findmnt -no SOURCE / | sed "s/\[.*//")" /mnt && { ls -A /mnt/root/home /mnt/root/var/log | grep -c .; sudo umount /mnt; }'

bad=0
printf '%-17s %-6s %-7s %-6s %-6s %s\n' STEP START LAYOUT FILES CLEAN RESULT
for st in "${steps[@]}"; do
  log=$out/$st.log; : >"$log"
  { bash "$here/vm-snap.sh" "$vm" revert built && bash "$here/vm-snap.sh" "$vm" start >>"$log" 2>&1 && run --wait 600 >>"$log" 2>&1; } \
    || { echo "split-cut: the VM did not start" >&2; exit 2; }
  { run --repo && run 'sudo cp -a ~/fedokawaii/. /usr/local/lib/fedokawaii/ && sudo install -m 755 ~/fedokawaii/system/kawa-snap /usr/local/sbin/kawa-snap'; } >>"$log" 2>&1 \
    || { echo "split-cut: the toolkit could not go in" >&2; exit 2; }
  run "$make_files" >>"$log" 2>&1 || { echo "split-cut: his files could not be made" >&2; exit 2; }
  before=$(chk "$files")
  pre=$(chk 'sudo snapper -c root --csvout list --columns number | sed 1d | grep -vx 0 | head -n1')
  arm=$(chk 'sudo bash /usr/local/lib/fedokawaii/setup.sh --layout 2>&1 | tail -n 3; sudo fedokawaii-split state')
  if [[ $arm != *armed ]]; then printf '%-17s %-6s %s\n' "$st" - "not armed: ${arm//$'\n'/ }"; bad=1; continue; fi
  [[ $st == none ]] || run "echo $st | sudo tee /var/lib/fedokawaii/split/cut >/dev/null" >>"$log" 2>&1
  if ! restart; then printf '%-17s %-6s\n' "$st" NO; bad=1; bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1; continue; fi
  state=$(chk 'sudo fedokawaii-split state')
  fl=ok; [[ $(chk "$files") == "$before" ]] || fl=DIFF
  result="" cl=-
  if [[ $st == fail-* ]]; then
    [[ $state == nested ]] || result+=" state $state"
    end=$(chk "$failed")
    [[ $end == *"a failure made at ${st#fail-}"* ]] || result+=" no reason kept"
    { grep -qx 'home/dia/Downloads' <<<"$end" && grep -qx 'home/dia/VM' <<<"$end" && grep -qx '.snapshots' <<<"$end"; } || result+=" not back in root"
    [[ $end == *snapper-ok* && $end != *armed-still* ]] || result+=" snapper or still armed"
    [[ $end == *"next toolkit tries again"* && $end == *state=nested* ]] || result+=" armed again"
  else
    [[ $state == "flat, old copies" ]] || result+=" state $state"
    end=$(chk "$split")
    for w in "<FS_TREE>/home" "<FS_TREE>/log" "<FS_TREE>/fk" "<FS_TREE>/snapshots" "<FS_TREE>/home/dia/Downloads" "<FS_TREE>/home/dia/VM"; do
      grep -qx -- "$w" <<<"$end" || result+=" no $w"
    done
    grep -qx 'fstab=4' <<<"$end" || result+=" fstab"
    { grep -q '^journal=.*\[/log\]$' <<<"$end" && [[ $end == *journal-ok* ]]; } || result+=" journal"
    [[ $end == *snap-ok* ]] || result+=" snapper"
    grep -qE '^listed=[1-9]' <<<"$end" || result+=" kawa-snap list"
    grep -qE '^grub=[1-9][0-9]* stale=0$' <<<"$end" || result+=" boot menu"
    [[ $st == none || $end == *"start 2"* ]] || result+=" not resumed"
    c=$(chk "$clean")
    cl=ok; [[ $(sed -n 1p <<<"$c") == flat && $(sed -n 2p <<<"$c") -le 2 ]] || { cl=NO; result+=" clean"; }
    [[ $(chk "$files") == "$before" ]] || { fl=DIFF; result+=" files after clean"; }
    # (a snapshot from before the split restored: the system that day's, his files today's)
    if [[ $st == none && -n $pre ]]; then
      r=$(chk "sudo kawa-snap restore $pre 2>&1 | tail -n 1")
      restart || result+=" no start after the restore"
      [[ $(chk "$files") == "$before" ]] || result+=" his files went back with the restore"
      [[ $(chk 'findmnt -no SOURCE /home; findmnt -no SOURCE /.snapshots' | tr '\n' ' ') == *"[/home]"*"[/snapshots]"* ]] \
        || result+=" not flat after the restore"
      say "restore $pre: $r"
    fi
  fi
  [[ $fl == ok ]] || result+=" files"
  if [[ -z $result ]]; then result=ok; else bad=1; fi
  printf '%-17s %-6s %-7s %-6s %-6s %s\n' "$st" ok "${state%%,*}" "$fl" "$cl" "$result"
  bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
done
echo "(LAYOUT after the split's start: flat or nested · CLEAN: fedokawaii-split clean left root's /home and /var/log empty)"
exit "$bad"
