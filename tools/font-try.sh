#!/usr/bin/env bash
# tools/font-try.sh — a candidate font tried in the desktop's real surfaces (tools/kit.sh), both
# themes, beside today's: the bar and the notices for a UI face, the terminal (the prompt, a
# listing) for a coding face — at the pixel size it is drawn for. The configs name the faces
# "Sumi UI" and "Sumi Term"; here those names are drawn with the candidate (a fontconfig alias)
# and the sizes changed in the kit's copies only. Nothing installed, nothing of the session touched.
#   bash tools/font-try.sh ui NAME PX FONTFILE…          UI face at PX (waybar, mako)
#   bash tools/font-try.sh term NAME PX LINE FONTFILE…   coding face at PX, foot's line LINE px
# → /dev/shm/r27/fonts/try/NAME.png: dark above light, each scene beside today's (left).
# Exit 0 · 1 a render failed · 2 misuse.
set -u
here=$(cd "$(dirname "$0")" && pwd)
kind=${1:-} name=${2:-} px=${3:-}
[[ $kind == @(ui|term) && $name =~ ^[A-Za-z0-9._-]+$ && $px =~ ^[0-9]+$ ]] \
  || { echo "usage: bash tools/font-try.sh ui NAME PX FONTFILE… | term NAME PX LINE FONTFILE…" >&2; exit 2; }
shift 3
line=""
[[ $kind == term ]] && { line=${1:-}; shift; [[ $line =~ ^[0-9]+$ ]] || { echo "font-try: term needs LINE" >&2; exit 2; }; }
(($#)) || { echo "font-try: no font file" >&2; exit 2; }
out=/dev/shm/r27/fonts/try
fd=$(mktemp -d /tmp/font-try.XXXXXX)
trap 'rm -rf "$fd"' EXIT
for f in "$@"; do [[ -f $f ]] || { echo "font-try: no $f" >&2; exit 2; }; ln -s "$(realpath "$f")" "$fd/"; done
family=$(fc-scan --format '%{family[0]}\n' "$1" | head -n 1)
[[ -n $family ]] || { echo "font-try: fontconfig cannot read $1" >&2; exit 1; }
if [[ $kind == ui ]]; then
  scenes=(bar notice) args=(--font "Sumi UI=$family"
    --edit "waybar/style.css:s/font-size: 16px/font-size: ${px}px/"
    --edit "mako/config:s/Noto Kufi Arabic 16px/Noto Kufi Arabic ${px}px/")
else
  scenes=(term) args=(--font "Sumi Term=$family"
    --edit "foot/foot.ini:s/Sumi Term:pixelsize=20/Sumi Term:pixelsize=$px/g"
    --edit "foot/foot.ini:s/^line-height=.*/line-height=${line}px/"
    --edit "foot/foot.ini:s/^font-size-adjustment=.*/font-size-adjustment=${px}px/")
fi
for t in dark light; do
  bash "$here/kit.sh" --theme "$t" --out "$out/$name/$t" --fontdir "$fd" "${args[@]}" "${scenes[@]}" >/dev/null || exit 1
  [[ -f $out/today/$t/${scenes[0]}.png ]] || bash "$here/kit.sh" --theme "$t" --out "$out/today/$t" bar notice term >/dev/null || exit 1
done
python3 -I - "$out" "$name" "${scenes[@]}" <<'PY'
import sys
from PIL import Image
out, name, scenes = sys.argv[1], sys.argv[2], sys.argv[3:]
crop = {"bar": (0, 0, 1920, 40), "notice": (0, 0, 540, 330), "term": (0, 30, 1100, 360)}   # (kit's bar and notice: already their own size)
rows = []
for t in ("dark", "light"):
    for s in scenes:
        x, y, w, h = crop[s]
        a = Image.open(f"{out}/today/{t}/{s}.png").crop((x, y, x + w, y + h))
        b = Image.open(f"{out}/{name}/{t}/{s}.png").crop((x, y, x + w, y + h))
        if s == "bar":                      # (the bar: its two halves, one above the other)
            a = a.crop((0, 0, 960, h)); b = b.crop((0, 0, 960, h)); w = 960
        rows.append((a, b, w, h))
W = max(2 * w + 12 for _, _, w, _ in rows)
H = sum(h + 8 for _, _, _, h in rows)
sheet = Image.new("RGB", (W, H), (80, 80, 80))
y = 0
for a, b, w, h in rows:
    sheet.paste(a, (0, y)); sheet.paste(b, (w + 12, y)); y += h + 8
sheet.save(f"{out}/{name}.png")
print(f"{out}/{name}.png")
PY
