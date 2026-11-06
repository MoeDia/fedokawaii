#!/usr/bin/env bash
# tests/content/test_stick.sh — kawa-stick: the installer on a USB stick. A file stands for the stick; lsblk says
# what is plugged in: only a USB drive big enough is offered, never a disk inside the PC, nothing is written before
# enter, a bad ISO and a stick that gives back something else are told.
. "$(dirname "$0")/lib.sh"

setup() {
  sandbox
  WORLD=$TMP/w; mkdir -p "$WORLD" "$HOME/Downloads"; export WORLD
  head -c 3000000 /dev/urandom >"$HOME/Downloads/fedokawaii-20261104.iso"
  (cd "$HOME/Downloads" && sha256sum fedokawaii-20261104.iso >fedokawaii-20261104.iso.sha256)
  export LSBLK='{"blockdevices":[{"name":"/dev/nvme0n1","size":1000204886016,"model":"Lexar","tran":"nvme","type":"disk"},{"name":"/dev/sdb","size":32000000000,"model":"SanDisk  ","tran":"usb","type":"disk"},{"name":"/dev/sdc","size":1000000,"model":"tiny","tran":"usb","type":"disk"}]}'
  stub lsblk 'case " $* " in *" -J "*) printf "%s" "$LSBLK" ;; *) printf "%s\n%s1\n" "$4" "$4" ;; esac'
  stub sudo 'exec "$@"'
  stub dd 'for a; do case $a in if=*) i=${a#if=} ;; esac; done; cp "$i" "$WORLD/stick"'
  stub cmp 'exec /usr/bin/cmp -n "$2" "$4" "$WORLD/stick"'
  stub udisksctl
}

case_ "--help answers (KEY-03), nothing touched"
setup; out=$(kawa-stick --help 2>&1); eq "$?" 0 "$out"; has "$out" "kawa-stick [ISO]"

case_ "a USB drive big enough is named, chosen by its number, and written only after enter: read back, switched off"
setup
out=$(printf '1\n' | kawa-stick 2>&1); eq "$?" 0 "$out"
has "$out" "SanDisk"; lacks "$out" "Lexar"; lacks "$out" "tiny"; has "$out" "safe to unplug"
/usr/bin/cmp -s "$HOME/Downloads/fedokawaii-20261104.iso" "$WORLD/stick" && _ok || _no "the stick differs"
called "udisksctl power-off -b /dev/sdb"; called "udisksctl unmount -b /dev/sdb1"

case_ "any other key leaves it alone: nothing written"
setup
out=$(printf '1x' | kawa-stick 2>&1); eq "$?" 4 "$out"
[[ ! -e $WORLD/stick ]] && _ok || _no "written without enter"; not_called "^dd "

case_ "enter alone, one drive plugged in: nothing is picked, nothing written"
setup
out=$(printf '\n\n' | kawa-stick 2>&1); eq "$?" 4 "$out"
[[ ! -e $WORLD/stick ]] && _ok || _no "written on a bare enter"; not_called "^dd "

case_ "never the drive of your backups: by its label, by a folder on it; never a drive of your things: named so, or with the folder on it"
drive() {   # drive LABEL MOUNT — the one USB drive plugged in
  export LSBLK='{"blockdevices":[{"name":"/dev/sdb","size":32000000000,"model":"Backup","tran":"usb","type":"disk","label":null,"mountpoint":null,"children":[{"name":"/dev/sdb1","size":32000000000,"model":null,"tran":null,"type":"part","label":"'"$1"'","mountpoint":"'"$2"'"}]}]}'
}
setup; stub kawa-backup 'echo MYBACKUP'; drive MYBACKUP ""
out=$(printf '1\n' | kawa-stick 2>&1); eq "$?" 4 "$out"; has "$out" "your backups"; not_called "^dd "; lacks "$out" "Backup"
setup; stub kawa-backup 'echo /run/media/me/DRIVE/backup'; drive DRIVE /run/media/me/DRIVE
out=$(printf '1\n' | kawa-stick 2>&1); eq "$?" 4 "$out"; not_called "^dd "
setup; stub kawa-backup 'echo sftp:me@host:/x'; drive FKCARRY ""
out=$(printf '1\n' | kawa-stick 2>&1); eq "$?" 4 "$out"; not_called "^dd "
setup; stub kawa-backup; mkdir -p "$TMP/m/fedokawaii-carry"; drive THINGS "$TMP/m"
out=$(printf '1\n' | kawa-stick 2>&1); eq "$?" 4 "$out"; not_called "^dd "
setup; stub kawa-backup 'echo MYBACKUP'; mkdir -p "$TMP/m"; drive OTHER "$TMP/m"
out=$(printf '1\n' | kawa-stick 2>&1); eq "$?" 0 "$out"; has "$out" "safe to unplug"

case_ "never a disk inside the PC; no USB drive: said"
setup
export LSBLK='{"blockdevices":[{"name":"/dev/nvme0n1","size":1000204886016,"model":"Lexar","tran":"nvme","type":"disk"}]}'
out=$(printf '\n' | kawa-stick 2>&1); eq "$?" 4 "$out"
has "$out" "no USB drive"; not_called "^dd "

case_ "an ISO that is not as it was built is told, and nothing written"
setup
printf 'x' >>"$HOME/Downloads/fedokawaii-20261104.iso"
out=$(printf '\n' | kawa-stick 2>&1); eq "$?" 1 "$out"
has "$out" "not as it was built"; [[ ! -e $WORLD/stick ]] && _ok || _no "written"

case_ "a stick that gives back something else is told"
setup
stub cmp 'exit 1'
out=$(printf '1\n' | kawa-stick 2>&1); eq "$?" 1 "$out"
has "$out" "take another"

case_ "several: chosen by its number; a wrong key leaves all alone"
setup
export LSBLK='{"blockdevices":[{"name":"/dev/sdb","size":32000000000,"model":"One","tran":"usb","type":"disk"},{"name":"/dev/sdd","size":64000000000,"model":"Two","tran":"usb","type":"disk"}]}'
out=$(printf '2\n' | kawa-stick 2>&1); eq "$?" 0 "$out"
has "$out" "Two"; called "udisksctl power-off -b /dev/sdd"
out=$(printf '9' | kawa-stick 2>&1); eq "$?" 4 "$out"

done_
