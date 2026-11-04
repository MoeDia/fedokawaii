#!/usr/bin/env bash
# tools/regress/clipboard.sh — never again a copy that does not arrive (owner 27 Oct 14:27: "fix copy/paste
# problems everywhere"; r27-17c): the real foot and neovim on a real dwl, kawa-clipkeep and the history running
# as autostart starts them. Each cell of the matrix a real copy and a real paste:
#   a word selected in foot → the clipboard and the primary · pasted with Ctrl+Shift+V · pasted with the middle
#   button · a copy whose window then closed · a picture, its bytes and its kind · 6 MB of text, whole ·
#   neovim's y → the desktop's clipboard, its p ← the desktop's, x and dd leaving it alone · the history lists
#   them, newest first.
#   bash tools/regress/clipboard.sh [KIT OPTION…]
# Exit 0 held · 1 broken (each cell said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-clip.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
python3 -I -c 'import sys; from PIL import Image; Image.effect_noise((64, 48), 40).convert("RGB").save(sys.argv[1])' "$out/pic.png" \
  || { echo "clipboard: no picture made" >&2; exit 2; }
cat >"$out/play.sh" <<PLAY_END
PIC=$out/pic.png
PLAY_END
cat >>"$out/play.sh" <<'PLAY_END'
cell() {   # cell NAME GOT WANT
  if [ "$2" = "$3" ]; then say "ok $1"; else say "BAD $1: got [$(printf %s "$2" | head -c 80)], want [$(printf %s "$3" | head -c 80)]"; fi
}
ctrlshift() { wtype -s 200 -M ctrl -M shift -k "$1" -m shift -m ctrl; sleep 0.3; }
kawa-clipkeep </dev/null >/dev/null 2>&1 &
wl-paste --watch kawa-clip --store </dev/null >/dev/null 2>&1 &
nap 0.8
# (a tiled window fills the screen: its first text row at about y 50, the word's first letters at x 40)
foot -T words sh -c 'printf "copythisword and more\n"; exec sleep 300' >/dev/null 2>&1 & A=$!
nap 1.2
at 40 52; wlrctl pointer click left; sleep 0.05; wlrctl pointer click left; nap 0.5
cell "foot: a word selected → the clipboard" "$(wl-paste -n 2>/dev/null)" copythisword
cell "foot: a word selected → the primary" "$(wl-paste -p -n 2>/dev/null)" copythisword
kill "$A"; wait "$A" 2>/dev/null
# (kawa-clipkeep offers it again a moment after: on a loaded machine a longer moment)
for _ in $(seq 24); do [ "$(wl-paste -n 2>/dev/null)" = copythisword ] && break; nap 0.25; done
cell "a copy whose window closed: still there" "$(wl-paste -n 2>/dev/null)" copythisword

foot -T paste sh -c 'exec cat >"$KIT_OUT/pasted.txt"' >/dev/null 2>&1 & B=$!
nap 1.2
printf 'from the desktop' | wl-copy; nap 0.3
ctrlshift v; wtype -s 100 -k Return; nap 0.4
cell "foot: Ctrl+Shift+V" "$(sed -n 1p "$KIT_OUT/pasted.txt" 2>/dev/null)" "from the desktop"
printf 'the primary one' | wl-copy -p; nap 0.3
at 400 400; wlrctl pointer click middle; nap 0.3; wtype -s 100 -k Return; nap 0.4
cell "foot: the middle button" "$(sed -n 2p "$KIT_OUT/pasted.txt" 2>/dev/null)" "the primary one"
kill "$B"; wait "$B" 2>/dev/null; nap 0.5

wl-copy -t image/png <"$PIC"; nap 0.6
cell "a picture: its kind" "$(wl-paste --list-types 2>/dev/null | head -n 1)" image/png
wl-paste -t image/png >"$KIT_OUT/pic-back.png" 2>/dev/null
cell "a picture: its bytes" "$(cmp "$PIC" "$KIT_OUT/pic-back.png" 2>&1)" ""

python3 -I -c 'import random; print("".join(random.choice("abcdef ") for _ in range(6000000)))' >"$KIT_OUT/big.txt"
wl-copy <"$KIT_OUT/big.txt"; nap 1.5
cell "6 MB of text: whole" "$(wl-paste -n 2>/dev/null | sha256sum)" "$(sha256sum <"$KIT_OUT/big.txt")"
rm -f "$KIT_OUT/big.txt"

printf 'the line to yank\nthe second line\nthe third line\n' >"$KIT_OUT/edit.txt"
foot -T nv nvim "$KIT_OUT/edit.txt" >/dev/null 2>&1 & C=$!
nap 3.5
wtype -s 150 -- 'yy'; nap 0.6
cell "neovim: y → the desktop's clipboard" "$(wl-paste -n 2>/dev/null)" "the line to yank"
wtype -s 150 -- 'x'; nap 0.3; wtype -s 150 -- 'j'; wtype -s 150 -- 'dd'; nap 0.5
cell "neovim: x and dd leave it alone" "$(wl-paste -n 2>/dev/null)" "the line to yank"
printf 'pasted in the editor\n' | wl-copy; nap 0.3
wtype -s 150 -- 'G'; wtype -s 150 -- 'p'; wtype -s 150 -- ':w'; wtype -k Return; nap 0.6
cell "neovim: p ← the desktop's clipboard" "$(tail -n 1 "$KIT_OUT/edit.txt")" "pasted in the editor"
kill "$C"; wait "$C" 2>/dev/null; nap 0.5

printf 'the newest copy' | wl-copy; nap 0.8
l=$(kawa-clip --list 2>/dev/null)
cell "the history: the newest first" "$(printf '%s\n' "$l" | head -n 1 | grep -c 'the newest copy')" 1
cell "the history: the picture named" "$(printf '%s\n' "$l" | grep -c '64.*48')" 1
say done
PLAY_END
bash "$here/../kit.sh" --theme dark "$@" --time 90 --out "$out/o" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "clipboard: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
log=$out/o/play.log
grep -q '^done$' "$log" 2>/dev/null || { echo "clipboard: the play did not end: $(tail -n 2 "$log" 2>/dev/null)" >&2; exit 2; }
if grep -q '^BAD ' "$log"; then sed -n 's/^BAD /clipboard: /p' "$log"; exit 1; fi
echo "clipboard: held — $(grep -c '^ok ' "$log") cells: foot, the primary, a closed window's copy, a picture, 6 MB, neovim, the history"
