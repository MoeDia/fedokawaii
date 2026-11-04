#!/usr/bin/env bash
# tests/content/test_carry.sh — kawa-carry: what is yours, across a wipe. A real tar on a folder that
# stands for the drive: what goes and what stays, the round trip byte for byte with its modes, parts
# across the size limit, the read-back that catches a failing drive, a drive too small, an older
# carry-over making way, the newest found on the drives, the first login's offer, and only once.
. "$(dirname "$0")/lib.sh"

home_of_his() {
  sandbox
  W=$TMP/world; mkdir -p "$W"; export W
  DRIVE=$W/media/KINGSTON; mkdir -p "$DRIVE"; export DRIVE
  stub kawa-drives 'case $1 in list) printf "/dev/sdb1\t/dev/sdb\tKINGSTON\t28.9G\tvfat\t%s\n" "$DRIVE" ;; esac'
  stub kawa-term
  cd "$HOME" || exit 1
  mkdir -p Notes "Documents/the old ones" Books Downloads repos/fedokawaii VM Drives .ssh \
    .config/fedokawaii .config/foot .config/BraveSoftware/Brave-Browser/Default/Cache \
    .local/state/fedokawaii/chess .local/state/fedokawaii/saver blasphemous-save-backup-20261022
  echo "- [ ] the list" >Notes/todo.md
  echo "مرحبا" >"Documents/the old ones/العربية.txt"
  echo "日本語" >Documents/日本語.txt
  echo huge >Downloads/huge.iso
  echo tooling >repos/fedokawaii/setup.sh
  echo disk >VM/disk.qcow2
  echo key >.ssh/id_ed25519; chmod 600 .ssh/id_ed25519
  printf 'RESTIC_PASSWORD="x"\n' >.config/fedokawaii/secrets.sh; chmod 600 .config/fedokawaii/secrets.sh
  echo "font=x" >.config/foot/foot.ini
  echo '{"a":1}' >.config/BraveSoftware/Brave-Browser/Default/Preferences
  head -c 4096 /dev/urandom >.config/BraveSoftware/Brave-Browser/Default/Cache/data_0
  echo "1 rating" >.local/state/fedokawaii/chess/progress
  echo x >.local/state/fedokawaii/saver/state
  echo save >blasphemous-save-backup-20261022/savegame
  head -c 3000000 /dev/urandom >Books/big.pdf
  find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum >"$W/before"
  cd - >/dev/null || exit 1
}

case_ "what goes: your folders, keys, browser, progress; never the tooling, the configs or the caches"
home_of_his
out=$(kawa-carry list | cut -f2-)
for p in Notes Documents Books blasphemous-save-backup-20261022 .ssh .config/fedokawaii/secrets.sh .config/BraveSoftware .local/state/fedokawaii/chess; do
  grep -qxF "$p" <<<"$out" && _ok || _no "$p should go: $out"
done
for p in Downloads repos VM Drives .config/foot .local/state/fedokawaii/saver .config; do
  grep -qxF "$p" <<<"$out" && _no "$p should stay" || _ok
done

case_ "save: written, read back, safe to wipe; the record beside it; this PC is not offered its own"
out=$(kawa-carry save --to "$DRIVE" --yes 2>&1); eq "$?" 0 "save: $out"
has "$out" "safe to wipe"
[[ -f $DRIVE/fedokawaii-carry/carry.info ]] && _ok || _no "no record"
[[ ! -e $DRIVE/fedokawaii-carry.new ]] && _ok || _no "the unfinished folder stayed"
grep -q '^sha256=[0-9a-f]\{64\}$' "$DRIVE/fedokawaii-carry/carry.info" && _ok || _no "no sum"
[[ -e $HOME/.local/state/fedokawaii/carry-seen ]] && _ok || _no "no mark"
tar -tf "$DRIVE/fedokawaii-carry/carry.part.0000" >"$W/names"
grep -q 'Default/Cache' "$W/names" && _no "the browser's cache went" || _ok
grep -q 'Downloads' "$W/names" && _no "Downloads went without being asked" || _ok
grep -qF 'العربية' "$W/names" && _ok || _no "an Arabic name was lost"

case_ "the round trip, after the wipe: every file byte for byte, its mode kept; nothing else appears"
mv "$HOME" "$W/old-home"; mkdir -p "$HOME/.local/bin" "$HOME/.config/fedokawaii"
cp -r "$W/old-home/.config/fedokawaii/." "$HOME/.config/fedokawaii/"; rm -f "$HOME/.config/fedokawaii/secrets.sh"
out=$(kawa-carry restore --from "$DRIVE/fedokawaii-carry" --yes 2>&1); eq "$?" 0 "restore: $out"
(cd "$HOME" && sha256sum --quiet -c <(grep -vE 'Downloads|repos/|VM/|foot.ini|Default/Cache|saver/state|\.config/fedokawaii/[^s]|\.config/fedokawaii/s[^e]' "$W/before")) && _ok || _no "a file came back different"
eq "$(stat -c %a "$HOME/.ssh/id_ed25519")" 600 "the key's mode"
eq "$(stat -c %a "$HOME/.config/fedokawaii/secrets.sh")" 600 "the secrets' mode"
[[ ! -e $HOME/repos && ! -e $HOME/VM ]] && _ok || _no "the tooling came along"
rm -rf "$HOME"; mv "$W/old-home" "$HOME"

case_ "Downloads by choice; many parts (the limit of FAT32 for a file): whole again"
export KAWA_CARRY_PART=1048576
out=$(kawa-carry save --to "$DRIVE" --downloads --yes 2>&1); eq "$?" 0 "save: $out"
n=$(compgen -G "$DRIVE/fedokawaii-carry/carry.part.*" | wc -l); ((n >= 3)) && _ok || _no "$n parts"
cat "$DRIVE"/fedokawaii-carry/carry.part.* | tar -tf - | grep -q Downloads/huge.iso && _ok || _no "Downloads did not go"
mkdir "$W/x"; mv "$HOME/Books" "$W/x/Books"
kawa-carry restore --from "$DRIVE/fedokawaii-carry" --yes >/dev/null 2>&1
cmp "$HOME/Books/big.pdf" "$W/x/Books/big.pdf" && _ok || _no "the file across the parts differs"
unset KAWA_CARRY_PART

case_ "a failing drive is told: a byte different comes back as a failure, not as success"
p=$DRIVE/fedokawaii-carry/carry.part.0000
printf 'X' | dd of="$p" bs=1 seek=4000 conv=notrunc status=none
out=$(kawa-carry restore --from "$DRIVE/fedokawaii-carry" --yes 2>&1); eq "$?" 1 "$out"
has "$out" "the drive is failing"

case_ "a drive too small: told, and what it held stays as it was"
home_of_his
kawa-carry save --to "$DRIVE" --yes >/dev/null 2>&1
sum0=$(sha256sum "$DRIVE/fedokawaii-carry/carry.info")
stub df 'printf "Avail\n1000\n"'
head -c 200000000 /dev/zero >"$HOME/Books/grown.bin"
out=$(kawa-carry save --to "$DRIVE" --yes 2>&1); eq "$?" 1 "$out"
has "$out" "does not fit"
eq "$(sha256sum "$DRIVE/fedokawaii-carry/carry.info")" "$sum0" "the older carry-over was touched"
rm -f "$HOME/Books/grown.bin"

case_ "find: the newest on the open drives; none: exit 1"
home_of_his
kawa-carry find >/dev/null; eq "$?" 1 "nothing to find"
kawa-carry save --to "$DRIVE" --yes >/dev/null 2>&1
eq "$(kawa-carry find)" "$DRIVE/fedokawaii-carry"

case_ "the first login: the drive there, a window offers it, once; with the mark, nothing"
rm -f "$HOME/.local/state/fedokawaii/carry-seen"
kawa-carry first; eq "$?" 0
grep -q '^kawa-term.*kawa-carry restore' "$CALLS" && _ok || _no "no window: $(cat "$CALLS")"
[[ -e $HOME/.local/state/fedokawaii/carry-seen ]] && _ok || _no "no mark"
: >"$CALLS"; kawa-carry first; grep -q '^kawa-term' "$CALLS" && _no "offered twice" || _ok

case_ "no drive to write to, a stray argument: said, nothing done"
stub kawa-drives 'exit 0'
home_of_his; stub kawa-drives 'exit 0'
out=$(kawa-carry save --yes 2>&1 </dev/null); eq "$?" 4 "$out"
has "$out" "no drive plugged in"
kawa-carry save --what >/dev/null 2>&1; eq "$?" 2
kawa-carry >/dev/null 2>&1; eq "$?" 2

done_
