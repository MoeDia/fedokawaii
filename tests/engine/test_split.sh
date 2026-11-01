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
  T=$TMP/split/top D=$TMP/split.d
  mkdir -p "$T/root/home/dia" "$T/root/var/log" "$T/root/var/lib/fedokawaii" "$T/root/etc" "$T/root/.snapshots/1/snapshot"
  echo his >"$T/root/home/dia/notes.txt"; echo log >"$T/root/var/log/boot.log"
  pointed "$REPO/system/fedokawaii-split" "$STUBS/fedokawaii-split" \
    's|\[\[ \$EUID -eq 0 \]\]|[[ ${FK_EUID:-0} -eq 0 ]]|' \
    "s|^D=/var/lib/fedokawaii/split |D=$D |" "s|^F=/var/lib/fedokawaii/split.failed |F=$TMP/split.failed |" \
    "s|^top=/run/fedokawaii-split/top |top=$T |" "s|/system-update|$TMP/system-update|g" \
    "s|LOG=/var/log/fedokawaii-split.log|LOG=$TMP/var-log/fedokawaii-split.log|"
  mkdir -p "$TMP/var-log"
  # (findmnt: / the root subvolume of /dev/vda3; each layout path mounted from [/NAME] when FK_FLAT)
  stub findmnt 'case "$*" in
  *--fstab*) echo rw,subvol=root,compress=zstd:1 ;; *FSTYPE*) echo btrfs ;;
  *"--mountpoint /home"*) [ -n "${FK_FLAT:-}" ] && echo "/dev/vda3[/home]" || { [ -n "${FK_OTHER:-}" ] && echo /dev/sdb1; } ;;
  *"--mountpoint /var/log"*) [ -n "${FK_FLAT:-}" ] && echo "/dev/vda3[/log]" ;;
  *"--mountpoint /var/lib/fedokawaii/update"*) [ -n "${FK_FLAT:-}" ] && echo "/dev/vda3[/fk]" ;;
  *"--mountpoint /.snapshots"*) [ -n "${FK_FLAT:-}" ] && echo "/dev/vda3[/snapshots]" ;;
  *SOURCE*) echo "/dev/vda3[/root]" ;;
esac'
  stub mountpoint "[ \"\$2\" = \"$T\" ]"
  stub mount; stub umount; stub restorecon; stub plymouth; stub journalctl; stub systemctl
  stub btrfs 'case "$1 $2" in
  "filesystem usage") printf "    Free (estimated):\t\t%s\t(min: 1)\n" "${FK_FREE:-500000000000}" ;;
  "filesystem sync") ;;
  "subvolume list") printf "%s" "${FK_NESTED:-}" ;;
  "subvolume show") exit 1 ;;   # (no folder here is a subvolume)
  "subvolume delete") echo "delete $*" >>"'"$TMP"'/deleted" ;;
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
fresh; mkdir "$T/home"; out=$(fedokawaii-split arm 2>&1); eq "$?" 1; has "$out" "already at the top"; [[ ! -e $TMP/system-update ]] && _ok || _no "armed"
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
called '^systemctl reboot'; eq "$(cat "$T/root/home/dia/notes.txt")" his
has "$(cat "$T/root/var/log/fedokawaii-split.log")" "the layout stays as it was"

# ── clean ────────────────────────────────────────────────────────────────────────────────
case_ "clean: the copies hidden under the new mounts removed"
fresh; mkdir -p "$T/root/home/dia/.config"; echo x >"$T/root/home/dia/.config/y"
FK_FLAT=1 fedokawaii-split clean; eq "$?" 0
[[ -z $(ls -A "$T/root/home") && -z $(ls -A "$T/root/var/log") ]] && _ok || _no "left: $(ls -A "$T/root/home" "$T/root/var/log")"
case_ "…a subvolume still inside the old /home: that copy left whole, said"
fresh; out=$(FK_FLAT=1 FK_NESTED="ID 258 gen 1 top level 256 path <FS_TREE>/root/home/dia/Downloads
" fedokawaii-split clean 2>&1); eq "$?" 0; has "$out" "a subvolume is still inside the old /home"
eq "$(cat "$T/root/home/dia/notes.txt")" his; [[ -z $(ls -A "$T/root/var/log") ]] && _ok || _no "the old /var/log not removed"
case_ "…not flat: nothing removed"
fresh; fedokawaii-split clean; eq "$?" 0; eq "$(cat "$T/root/home/dia/notes.txt")" his

done_
