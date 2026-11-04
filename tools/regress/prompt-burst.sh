#!/usr/bin/env bash
# tools/regress/prompt-burst.sh — never again a doubled prompt line when terminals open in a burst
# (r26-7: "misalignment when many terminals open quickly" — foot's clear pushed the screen into
# its scrollback, so a window retiled under a prompt showed the heading twice): eight real foot
# windows 50 ms apart, each a bash with your prompt (~/.bashrc.d/fedokawaii.sh) and ble.sh, three
# times; every window must show exactly one prompt line — counted by the folder block's top edge
# (paper_folder, foot's colour 27: the head before it is a picture that changes with its mood).
# Headless (tools/kit.sh, the real GPU).
#   bash tools/regress/prompt-burst.sh [KIT OPTION…]
# Exit 0 held · 1 a burst showed more or fewer prompts than windows (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-burst.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
mkdir -p "$HOME/.bashrc.d" "$HOME/.local/share" && cp "$REAL/.bashrc.d/fedokawaii.sh" "$HOME/.bashrc.d/"
ln -s "$REAL/.local/share/blesh" "$HOME/.local/share/blesh"
# (ble.sh's caches built first, as the installer's blesh_warm and a login's first terminal do)
printf '%s\n' "source $HOME/.local/share/blesh/ble.sh --attach=none --norc" 'exit 0' >"$HOME/warm.rc"
TERM=foot python3 -I -c 'import pty, sys; pty.spawn(["bash", "--rcfile", sys.argv[1], "-i"])' "$HOME/warm.rc" </dev/null >/dev/null 2>&1
for b in 1 2 3; do
  chord logo $b; nap 0.3
  for i in 1 2 3 4 5 6 7 8; do foot bash -i >/dev/null 2>&1 & sleep 0.05; done
  nap 6; shot "burst$b"; nap 8; shot "late$b"
done
PLAY
sed -i "1i REAL=$HOME" "$out/play.sh"
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" --time 160 play >"$out/kit.log" 2>&1 || { echo "prompt-burst: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
# (each prompt's folder block: a row of its paper at least 24 px long with none above it)
th=$HOME/.config/foot/foot.ini
[[ " $* " == *" --repo-art "* ]] && th=$here/../../configs/home/.config/foot/foot.ini
paper=$(sed -n '/^\[colors-dark\]/,/^\[/s/^27=//p' "$th"); [[ $paper =~ ^[0-9a-f]{6}$ ]] || { echo "prompt-burst: no paper_folder in $th" >&2; exit 2; }
count() { python3 -I -c '
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert("RGB"))
m = np.all(a == tuple(bytes.fromhex(sys.argv[2])), axis=2)
n = 0
for y in range(41, m.shape[0]):
    row, above, x = m[y], m[y - 1], 0
    while x < m.shape[1]:
        if not row[x]:
            x += 1
            continue
        x1 = x
        while x1 < m.shape[1] and row[x1]:
            x1 += 1
        n += x1 - x >= 24 and not above[x + 10]
        x = x1
print(n)' "$1" "$paper"; }
for b in 1 2 3; do
  [[ -s $out/late$b.png ]] || { echo "prompt-burst: no shot of burst $b" >&2; exit 2; }
  n=$(count "$out/burst$b.png") || exit 2; m=$(count "$out/late$b.png") || exit 2
  # (a loaded machine may be slow to draw the last prompt: more than eight is the fault at any time, fewer
  # only once they have had their time)
  ((n <= 8)) || { echo "prompt-burst: burst $b — $n prompt lines in 8 windows" >&2; exit 1; }
  [[ $m == 8 ]] || { echo "prompt-burst: burst $b — $m prompt lines in 8 windows, 14 s on" >&2; exit 1; }
done
echo "prompt-burst: held — three bursts of 8 windows, one prompt line in each"
