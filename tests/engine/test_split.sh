#!/usr/bin/env bash
# tests/engine/test_split.sh — fedokawaii-split, the disk's flat layout: its arguments, the state it
# reads, the checks before it arms (nothing changed when one fails), a start that is not its own,
# the give-up after three starts (put back, the reason and the program's checksum kept, the machine
# restarted), clean (the hidden copies removed, never a folder that holds a subvolume). The disk is
# a folder here and Btrfs a stand-in; the copies, the moves and every cut point run for real in the
# harness VM: tools/vm-inject/split-cut.sh. (The fstab lines: tests/engine/test_snap.sh, through
# kawa-snap restore.)
. "$(dirname "$0")/lib.sh"

fresh() {   # a Fedora layout: root with /home (his file), /var/log, the snapshots inside it
  sandbox
  T=$TMP/split/top D=$TMP/split.d REG=$TMP/subvols
  mkdir -p "$T/root/home/dia" "$T/root/var/log" "$T/root/var/lib/fedokawaii" "$T/root/etc" "$T/root/.snapshots/1/snapshot"
  echo his >"$T/root/home/dia/notes.txt"; echo log >"$T/root/var/log/boot.log"
  printf 'UUID=ab12\t/\tbtrfs\tsubvol=root,compress=zstd:1\t0 0\nUUID=cd34 /boot xfs defaults 0 0\n' >"$T/root/etc/fstab"
  # (subvolumes: folders whose inode is in REG — a rename keeps it, as Btrfs does)
  : >"$REG"; for d in "$T/root" "$T/root/.snapshots" "$T/root/.snapshots/1/snapshot"; do stat -c %i "$d" >>"$REG"; done
  pointed "$REPO/system/fedokawaii-split" "$STUBS/fedokawaii-split" \
    's|\[\[ \$EUID -eq 0 \]\]|[[ ${FK_EUID:-0} -eq 0 ]]|' \
    "s|^D=/var/lib/fedokawaii/split |D=$D |" "s|^F=/var/lib/fedokawaii/split.failed |F=$TMP/split.failed |" \
    "s|^top=/run/fedokawaii-split/top |top=$T |" "s|/system-update|$TMP/system-update|g" \
    "s|LOG=/var/log/fedokawaii-split.log|LOG=$TMP/var-log/fedokawaii-split.log|" \
    "s|/run/fedokawaii-split.lock|$TMP/split.lock|" 's|held "\$p")|held "$top/$T$p")|' \
    's|restorecon /.snapshots|restorecon "$top/$T/.snapshots"|' 's|/usr/local/sbin/kawa-snap boot|kawa-snap boot|'
  mkdir -p "$TMP/var-log"
  # (findmnt: / the root subvolume of /dev/vda3 — or FK_FS; each layout path mounted from [/NAME] when FK_FLAT)
  stub findmnt 'case "$*" in
  *--verify*) ;;
  *--fstab*) echo rw,subvol=root,compress=zstd:1 ;; *FSTYPE*) echo "${FK_FS:-btrfs}" ;;
  *"--mountpoint /home"*) [ -n "${FK_FLAT:-}" ] && echo "/dev/vda3[/home]" || { [ -n "${FK_OTHER:-}" ] && echo /dev/sdb1; } ;;
  *"--mountpoint /var/log"*) [ -n "${FK_FLAT:-}" ] && echo "/dev/vda3[/log]" ;;
  *"--mountpoint /var/lib/fedokawaii/update"*) [ -n "${FK_FLAT:-}" ] && echo "/dev/vda3[/fk]" ;;
  *"--mountpoint /.snapshots"*) [ -n "${FK_FLAT:-}" ] && echo "/dev/vda3[/snapshots]" ;;
  *SOURCE*) echo "/dev/vda3[/root]" ;;
esac'
  stub mountpoint "[ \"\$2\" = \"$T\" ]"
  stub mount; stub umount; stub restorecon; stub plymouth; stub journalctl; stub systemctl; stub kawa-snap
  # (cp: the real one — and FK_GROW, a file a process appends to while the folder is copied)
  stub cp '/usr/bin/cp "$@"; r=$?; [ -n "${FK_GROW:-}" ] && echo more >>"$FK_GROW"; exit $r'
  stub btrfs 'reg='"$REG"' top='"$T"'
is() { [ -e "$1" ] && grep -qx "$(stat -c %i "$1")" "$reg"; }
case "$1 $2" in
  "filesystem usage") printf "    Free (estimated):\t\t%s\t(min: 1)\n" "${FK_FREE:-500000000000}" ;;
  "filesystem sync") ;;
  "subvolume show") is "$3" || exit 1 ;;
  "subvolume create") mkdir "$3" && stat -c %i "$3" >>"$reg" || exit 1 ;;
  "subvolume delete") shift 2; [ "$1" = --commit-after ] && shift; i=$(stat -c %i "$1") && rm -rf "$1" && sed -i "/^$i\$/d" "$reg" ;;
  "subvolume list") if [ "$3" != -o ]; then   # (list /: those at the top level)
      for d in "$top"/*; do is "$d" && echo "ID 1 gen 1 top level 5 path ${d##*/}"; done; exit 0
    fi
    p=$4   # (-o P: the subvolumes right below P)
    find "$p" -mindepth 1 -type d | while IFS= read -r d; do
      is "$d" || continue; a=${d%/*}; up=0
      while [ "$a" != "$p" ]; do is "$a" && up=1; a=${a%/*}; done
      [ $up = 0 ] && echo "ID 1 gen 2 top level 256 path ${d#$top/}"
    done ;;
  *) exit 1 ;;
esac'
}
# ── the arguments, root ──────────────────────────────────────────────────────────────────
fresh
case_ "misuse: no action, an unknown one, fstab without its file and top — exit 2"
rc 2 fedokawaii-split; rc 2 fedokawaii-split bogus; rc 2 fedokawaii-split fstab /etc/fstab; rc 2 fedokawaii-split arm extra
case_ "not root: said, exit 2"
out=$(FK_EUID=1000 fedokawaii-split state 2>&1); eq "$?" 2; has "$out" "runs as root"
case_ "--help: the header, nothing done"
out=$(fedokawaii-split --help); eq "$?" 0; has "$out" "the disk's layout made flat, once"

# ── state ────────────────────────────────────────────────────────────────────────────────
case_ "state: Fedora's one subvolume — nested"
eq "$(fedokawaii-split state)" nested
case_ "…each layout path mounted from its subvolume — flat; old copies under the mounts said"
eq "$(FK_FLAT=1 fedokawaii-split state)" "flat, old copies"
rm -rf "$T/root/home/dia" "$T/root/var/log/boot.log"; eq "$(FK_FLAT=1 fedokawaii-split state)" flat
case_ "…armed: /system-update points at its folder"
fresh; ln -s "$D" "$TMP/system-update"; eq "$(fedokawaii-split state)" armed

# ── arm ──────────────────────────────────────────────────────────────────────────────────
fresh
case_ "arm: the link to its folder, its tries at 0 — the next start does it"
out=$(fedokawaii-split arm 2>&1); eq "$?" 0 "$out"; has "$out" "armed"
eq "$(readlink "$TMP/system-update")" "$D"; eq "$(cat "$D/tries")" 0
case_ "…armed again: nothing changes"
fedokawaii-split arm >/dev/null 2>&1; eq "$?" 0; eq "$(readlink "$TMP/system-update")" "$D"
case_ "…flat already: nothing to arm"
fresh; FK_FLAT=1 fedokawaii-split arm >/dev/null 2>&1; eq "$?" 0; [[ ! -e $TMP/system-update ]] && _ok || _no "armed a flat disk"
case_ "arm refused, nothing changed: another tool's offline update waiting"
fresh; ln -s /var/lib/dnf/system-upgrade "$TMP/system-update"
out=$(fedokawaii-split arm 2>&1); eq "$?" 1; has "$out" "another offline update"; [[ ! -e $D ]] && _ok || _no "its folder made"
case_ "…a subvolume home already at the top (not the split's)"
fresh; mkdir "$T/home"; out=$(fedokawaii-split arm 2>&1); eq "$?" 1; has "$out" "a folder home is already at the top"; [[ ! -e $TMP/system-update ]] && _ok || _no "armed"
fresh; mkdir "$T/home"; stat -c %i "$T/home" >>"$REG"; out=$(fedokawaii-split arm 2>&1); eq "$?" 1; has "$out" "at the top: home"; has "$out" "not armed"
case_ "…/home mounted from another disk (not Fedora's layout)"
fresh; out=$(FK_OTHER=1 fedokawaii-split arm 2>&1); eq "$?" 1; has "$out" "mounted from something else"
case_ "…too little room for the copies (journald's NOCOW files are written again)"
fresh; out=$(FK_FREE=1000 fedokawaii-split arm 2>&1); eq "$?" 1; has "$out" "the split needs"; [[ ! -e $TMP/system-update ]] && _ok || _no "armed"

# ── run ──────────────────────────────────────────────────────────────────────────────────
case_ "run in a start that is not the split's (another offline update, or none): nothing done"
fresh; rc 0 fedokawaii-split run; not_called '^btrfs'; not_called '^systemctl'
fresh; ln -s /var/lib/dnf/system-upgrade "$TMP/system-update"; rc 0 fedokawaii-split run; not_called '^btrfs'
case_ "run, a fourth start (three did not finish it): put back, the reason and its checksum kept, unarmed, restarted"
fresh; fedokawaii-split arm >/dev/null 2>&1; echo 3 >"$D/tries"
fedokawaii-split run >/dev/null 2>&1; eq "$?" 0
has "$(sed -n 1p "$TMP/split.failed")" "three starts did not finish it"
eq "$(sed -n 2p "$TMP/split.failed")" "$(sha256sum <"$STUBS/fedokawaii-split")"
[[ ! -e $TMP/system-update && ! -e $D ]] && _ok || _no "still armed"
called '^systemctl reboot'; eq "$(cat "$T/root/home/dia/notes.txt")" his; called '^kawa-snap boot'
has "$(cat "$T/root/var/log/fedokawaii-split.log")" "the layout stays as it was"

# ── clean ────────────────────────────────────────────────────────────────────────────────
case_ "clean: the copies hidden under the new mounts removed"
fresh; mkdir -p "$T/root/home/dia/.config"; echo x >"$T/root/home/dia/.config/y"
FK_FLAT=1 fedokawaii-split clean; eq "$?" 0
[[ -z $(ls -A "$T/root/home") && -z $(ls -A "$T/root/var/log") ]] && _ok || _no "left: $(ls -A "$T/root/home" "$T/root/var/log")"
case_ "…a subvolume still inside the old /home: that copy left whole, said"
fresh; mkdir "$T/root/home/dia/Downloads"; stat -c %i "$T/root/home/dia/Downloads" >>"$REG"
out=$(FK_FLAT=1 fedokawaii-split clean 2>&1); eq "$?" 0; has "$out" "a subvolume is still inside the old /home"
eq "$(cat "$T/root/home/dia/notes.txt")" his; [[ -z $(ls -A "$T/root/var/log") ]] && _ok || _no "the old /var/log not removed"
case_ "…not flat: nothing removed"
fresh; fedokawaii-split clean; eq "$?" 0; eq "$(cat "$T/root/home/dia/notes.txt")" his

# ── the run, whole, on folders (the VM proves it on Btrfs: tools/vm-inject/split-cut.sh) ─────
case_ "run: the copies compared and named, the snapshots moved, fstab's four lines — unarmed, restarted"
fresh; fedokawaii-split arm >/dev/null 2>&1; fedokawaii-split run >/dev/null 2>&1; eq "$?" 0
for n in home log fk snapshots; do grep -qx "$(stat -c %i "$T/$n" 2>/dev/null)" "$REG" && _ok || _no "no subvolume $n at the top"; done
eq "$(cat "$T/home/dia/notes.txt" 2>&1)" his; eq "$(cat "$T/log/boot.log" 2>&1)" log
[[ -d $T/root/.snapshots && -z $(ls -A "$T/root/.snapshots") && -d $T/snapshots/1/snapshot ]] && _ok || _no "the snapshots not moved"
eq "$(grep -c 'subvol=\(home\|log\|fk\|snapshots\),compress=zstd:1' "$T/root/etc/fstab")" 4
[[ ! -e $TMP/system-update && ! -e $D ]] && _ok || _no "still armed"; called '^systemctl reboot'
has "$(cat "$T/log/fedokawaii-split.log" 2>&1)" "the disk's new layout is made"
# (the boot menu's list made again before the restart: it named root/.snapshots/N — seen on the PC, 1 Nov)
called '^kawa-snap boot'; has "$(cat "$T/log/fedokawaii-split.log" 2>&1)" "the boot menu's snapshots listed again"
case_ "…a file a process holds open and appends to while /var/log is copied (plymouth's boot.log): copied as it was, compared by neither the listing nor the sample"
fresh; sleep 30 3>>"$T/root/var/log/boot.log" & holder=$!   # (fewer than 64 files: the sample takes every one)
fedokawaii-split arm >/dev/null 2>&1; FK_GROW=$T/root/var/log/boot.log fedokawaii-split run >/dev/null 2>&1; eq "$?" 0
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
[[ -d $T/log && ! -e $TMP/split.failed ]] && _ok || _no "put back: $(cat "$TMP/split.failed" 2>&1)"
case_ "…the same file not open: its change is caught — put back, the reason kept"
fresh; fedokawaii-split arm >/dev/null 2>&1; FK_GROW=$T/root/var/log/boot.log fedokawaii-split run >/dev/null 2>&1
has "$(cat "$TMP/split.failed" 2>&1)" "the copy of /var/log"; [[ ! -e $T/log && ! -e $T/home ]] && _ok || _no "a copy left at the top"
eq "$(cat "$T/root/home/dia/notes.txt")" his
case_ "another tool's offline start on a root that is not Btrfs (a snapshot's layer, dnf's upgrade): nothing done, no failure"
fresh; ln -s /var/lib/dnf/system-upgrade "$TMP/system-update"; out=$(FK_FS=overlay fedokawaii-split run 2>&1); eq "$?" 0 "$out"; not_called '^systemctl'
case_ "put back with a kept fstab that is not whole (a cut while it was written): fstab left as it was, said"
fresh; fedokawaii-split arm >/dev/null 2>&1; : >"$D/fstab"; echo fail-copied-log >"$D/cut"
cp "$T/root/etc/fstab" "$TMP/fstab.before"; fedokawaii-split run >/dev/null 2>&1
cmp -s "$T/root/etc/fstab" "$TMP/fstab.before" && _ok || _no "fstab replaced: $(cat "$T/root/etc/fstab")"
has "$(cat "$TMP/split.failed")" "left behind: fstab (the copy kept before was not whole"
case_ "a fifth start: given up, nothing left at the top"
fresh; fedokawaii-split arm >/dev/null 2>&1; echo 4 >"$D/tries"; fedokawaii-split run >/dev/null 2>&1
has "$(cat "$TMP/split.failed")" "three starts did not finish it"; [[ ! -e $T/home && ! -e $TMP/system-update ]] && _ok || _no "left armed or a copy"
case_ "tries damaged (not a number): counted from 0, never an endless restart"
fresh; fedokawaii-split arm >/dev/null 2>&1; echo garbage >"$D/tries"
fedokawaii-split run >/dev/null 2>&1; eq "$?" 0; [[ -d $T/home ]] && _ok || _no "the run stopped"

# ── broken: a half layout is said, never taken for nested or flat ─────────────────────────
case_ "state: a part of the layout at the top while not flat — broken, with the reason kept"
fresh; mkdir "$T/home"; stat -c %i "$T/home" >>"$REG"; printf '2026-11-01 08:00:00 put back — left behind: home\nabc  -\n' >"$TMP/split.failed"
out=$(fedokawaii-split state); has "$out" "broken: the layout half made (at the top: home)"; has "$out" "left behind: home"
out=$(fedokawaii-split arm 2>&1); eq "$?" 1; has "$out" "not armed"; [[ ! -e $TMP/system-update ]] && _ok || _no "armed"

done_
