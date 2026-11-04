#!/usr/bin/env bash
# tests/content/test_carry.sh — kawa-carry: your own things across a wipe (the owner, 4 Nov 17:46), the drive a folder here,
# with the real restic (skipped where it is not installed): what goes, the trip to the drive, a wiped home of another
# name, all of it back: nothing of the new system replaced but secrets.sh; a wrong password changes nothing.
. "$(dirname "$0")/lib.sh"
command -v restic >/dev/null || { skipped "no restic here"; done_; exit 0; }
sandbox; config .config/fedokawaii/carry.list
export RESTIC_PASSWORD=trip-pass
H1=$HOME D=$TMP/drive; mkdir -p "$D"
mkdir -p "$HOME/Notes" "$HOME/Books" "$HOME/repos/mine" "$HOME/repos/fk-lane" "$HOME/.ssh" "$HOME/Downloads" "$HOME/.config/fedokawaii"
echo "a line" >"$HOME/Notes/notes.md"; echo "todo" >"$HOME/Notes/todo.md"; echo "book" >"$HOME/Books/日本語の本.pdf"
echo code >"$HOME/repos/mine/a.c"; echo stray >"$HOME/repos/fk-lane/x"; echo key >"$HOME/.ssh/id"; chmod 600 "$HOME/.ssh/id"
echo big >"$HOME/Downloads/film"
printf 'export KEY=old\n' >"$HOME/.config/fedokawaii/secrets.sh"; chmod 600 "$HOME/.config/fedokawaii/secrets.sh"

case_ "list: what goes, with its size; only what is here; never Downloads"
out=$(kawa-carry list); has "$out" "Notes"; has "$out" ".ssh"; has "$out" ".config/fedokawaii/secrets.sh"; lacks "$out" "Downloads"; lacks "$out" "Music"

case_ "pack: to the drive, encrypted, read back, then and only then safe to wipe"
printf 'CITY="Cairo"\n' >"$TMP/settings.conf"; export KAWA_CARRY_SETTINGS=$TMP/settings.conf
out=$(kawa-carry pack "$D" 2>&1); r=$?; eq "$r" 0 "exit: $out"; has "$out" "safe to wipe"
[[ -e $HOME/.local/state/fedokawaii/carried.told ]] && _ok || _no "this system took them: its next login would say to bring them back"
[[ -e $D/fedokawaii-carry/config ]] && _ok || _no "no repository on the drive"
lacks "$(find "$D" -type f -exec cat {} + 2>/dev/null | tr -d '\0' | grep -a -c 'export KEY=old')" "1" "secrets.sh not readable on the drive"

case_ "back, on a wiped system under another home: all of it there, the rights kept, the new system's own files untouched, secrets.sh yours"
N=$TMP/newhome; mkdir -p "$N/.config/fedokawaii" "$N/Notes"; cp -a "$H1/.config/fedokawaii/." "$N/.config/fedokawaii/"; rm -f "$N/.config/fedokawaii/secrets.sh"
printf 'empty\n' >"$N/.config/fedokawaii/secrets.sh"; echo "new" >"$N/Notes/notes.md"
HOME=$N XDG_STATE_HOME=$N/.local/state kawa-carry back "$D" >"$TMP/o" 2>&1; eq "$?" 0 "exit: $(cat "$TMP/o")"
eq "$(cat "$N/Notes/todo.md")" todo; eq "$(cat "$N/Books/日本語の本.pdf")" book; eq "$(cat "$N/repos/mine/a.c")" code
eq "$(cat "$N/Notes/notes.md")" new "what the new system has stays"
eq "$(cat "$N/.config/fedokawaii/secrets.sh")" "export KEY=old" "secrets.sh is yours"
eq "$(stat -c %a "$N/.ssh/id")" 600; eq "$(stat -c %a "$N/.config/fedokawaii/secrets.sh")" 600
[[ -e $N/repos/fk-lane ]] && _no "a lane's worktree came along" || _ok
[[ -e $N/Downloads ]] && _no "Downloads came along" || _ok
[[ -e $N/.local/state/fedokawaii/carried ]] && _ok || _no "not marked as done"
eq "$(cat "$N/.config/fedokawaii/carried-settings.conf")" 'CITY="Cairo"' "your settings, outside your home, came along"
has "$(cat "$TMP/o")" "carried-settings.conf"
eq "$(find "$N" -maxdepth 1 -name '.carry.*' | wc -l)" 0 "nothing left over in the home: $(ls -a "$N" | tr '\n' ' ')"

case_ "a wrong password: said, nothing changed"
M=$TMP/third; mkdir -p "$M/.config/fedokawaii"; cp -a "$H1/.config/fedokawaii/icons.sh" "$M/.config/fedokawaii/"
RESTIC_PASSWORD=wrong HOME=$M XDG_STATE_HOME=$M/.local/state kawa-carry back "$D" >"$TMP/o" 2>&1; eq "$?" 1 "exit"
has "$(cat "$TMP/o")" "nothing was changed"; [[ -e $M/Notes ]] && _no "something came back" || _ok

case_ "misuse: exit 2"
rc 2 kawa-carry bogus; rc 2 kawa-carry

done_
