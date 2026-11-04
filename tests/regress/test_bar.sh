#!/usr/bin/env bash
# tests/regress/test_bar.sh — never again the bar growing with a title (r26-fu-4: 46 px with Arabic,
# emoji, Thai), a stray pixel in the television (r27-bar-10, the master's trace), the weather's sun
# taken for the brightness icon (r27-bar-13), or Steam on the bar (the owner, 27 Oct). The pixels of
# the running bar: tools/regress/bar-titles.sh and tv-frames.sh; here what makes them.
. "$(dirname "$0")/lib.sh"
. "$REPO/tests/session/lib.sh"
session_sandbox
config .config/fedokawaii/icons.sh

case_ "a title of any script: its line height fixed, under the bar's paper"
for t in 'مرحبا بالعالم' '🎉 party 👍🏽' 'สวัสดีชาวโลก' '日本語のタイトル' 'plain'; do
  rm -rf "$BAR"; block DP-1 1 1 1 0 '(@)' 0 "$t" | kawa-dwlstatus
  j=$(bar title)
  h=$(sed -n "s/.*line_height='\([0-9]*\)'.*/\1/p" <<<"$j")
  [[ -n $h ]] && _ok || _no "[$t]: no line height of its own: the fallback face's would grow the bar ($j)"
  ((${h:-99999} <= 20 * 1024)) && _ok || _no "[$t]: line height $h is more than the paper's 20 rows"
done
item r26-fu-4 "Arabic, emoji, Thai, Japanese: line height ${h:-?} (Pango units: $((${h:-0} / 1024)) px), the paper 20 rows"

case_ "the television's four frames: no stray pixel, the set itself never moves"
out=$(python3 -I - "$REPO/art/icons.txt" <<'PY'
import re, sys
art, name = {}, None
for line in open(sys.argv[1], encoding="utf8"):
    line = line.rstrip("\n")
    if line.startswith("@"):
        name = line[1:].split()[0]
        art[name] = []
    elif name and re.fullmatch(r"[.#]+", line):
        art[name].append(line)
    elif not line.strip():
        name = None
f = [art[f"tv-{i}"] for i in range(4)]
bad, moved = [], []
if len({(len(x), len(x[0])) for x in f}) != 1:
    bad.append("the frames are not one size")
base = f[0]
full = [i for i, r in enumerate(base) if set(r) == {"#"}]     # the cabinet's top and bottom rows
top, bottom = full[0], full[-1]
for n, x in enumerate(f[1:], 1):
    d = [(r, c) for r in range(len(base)) for c in range(len(base[0])) if x[r][c] != base[r][c]]
    moved.append(len(d))
    if not d:
        bad.append(f"frame {n} is frame 0")
    for r, c in d:
        inside = top < r < bottom and 0 < c < len(base[0]) - 1
        if not (inside or r < top):         # the picture inside, or the antenna above
            bad.append(f"frame {n}: a stray pixel at row {r}, column {c}")
print(" ".join(map(str, moved)))
print("\n".join(bad))
PY
)
{ read -r moved; bad=$(cat); } <<<"$out"
eq "$bad" "" "$bad"
item r27-bar-10 "frames 1–3 change ${moved// /, } pixels of frame 0, all inside the set or on the antenna"

case_ "the weather's sun is not the brightness: two different pictures"
if python3 -I -c 'import PIL' 2>/dev/null; then
  m=$(python3 -I - "$REPO/art/icons.txt" "$REPO/configs/home/.config/fedokawaii/themes/dark/sky-clear.png" <<'PY'
import re, sys
from PIL import Image
art, name = {}, None
for line in open(sys.argv[1], encoding="utf8"):
    line = line.rstrip("\n")
    if line.startswith("@"):
        name = line[1:].split()[0]
        art[name] = []
    elif name and re.fullmatch(r"[.#]+", line):
        art[name].append(line)
    elif not line.strip():
        name = None
im = Image.open(sys.argv[2]).convert("RGBA")
w, h = im.size
px = im.load()
sky = {(y, x) for y in range(h) for x in range(w) if px[x, y][3] > 128}
best = 1.0
for n in (f"bri-{i}" for i in range(5)):
    pts = {(y, x) for y, r in enumerate(art[n]) for x, c in enumerate(r) if c == "#"}
    # the likeness at its best offset (Jaccard): the same picture is 1
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            moved = {(y + dy, x + dx) for y, x in pts}
            like = len(moved & sky) / max(1, len(moved | sky))
            best = min(best, 1 - like)
print(f"{1 - best:.2f}")
PY
  )
  python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 0.6 else 1)' "${m:-1}" && _ok || _no "the sky's clear picture and the brightness icon are ${m} alike"
  item r27-bar-13 "the two pictures at most $m alike"
fi

case_ "no Steam on the bar: no tile, no joystick, no tooltip"
w=$REPO/configs/home/.config/waybar
lacks "$(grep -il 'steam\|joystick' "$w"/* 2>/dev/null)" "$w" "the bar's configs still name it: $(grep -il 'steam\|joystick' "$w"/* 2>/dev/null)"
lacks "$(grep -n 'steam' "$REPO/bin/kawa-bar" "$REPO/bin/kawa-dwlstatus" 2>/dev/null)" "steam" "the bar's own scripts"
item "r27-bar-9 r27-bar-11 r24-16 r27-vm-1" "waybar's config, style, kawa-bar, kawa-dwlstatus: no Steam"
done_
