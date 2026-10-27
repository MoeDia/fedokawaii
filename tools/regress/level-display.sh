#!/usr/bin/env bash
# tools/regress/level-display.sh — never again (r27-15c: the level display drawn apart from quick
# settings' meters): the volume key's level shown by the panel's own window, headless
# (tools/kit.sh, the real GPU, both themes), measured against docs/design-system.md §9 —
#   · its frame 258 × 54 (16 px of pad, a row, the hairline), centred, its foot 72 px above the
#     screen's bottom edge; the shadow under it and at its right
#   · its twenty segments, a cell each, lit as the panel lights them: 47 % → nine whole, the tenth
#     lit from its foot
#   · gone 1.2 s after the last key (not there 1.6 s later)
#   bash tools/regress/level-display.sh [KIT OPTION…]   (e.g. --bin bin --repo-art before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-level.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
panel; nap 1.5
. "$HOME/.config/fedokawaii/icons.sh"
kawa-osd "$ICON_VOL_2" volume 47; nap 0.5; shot shown
nap 1.6; shot gone
PLAY
fail=0
no() { echo "level-display ($th): $*" >&2; fail=1; }
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "level-display: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  m=$(python3 -I - "$out/$th/shown.png" "$out/$th/gone.png" <<'EOF'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB"); g = Image.open(sys.argv[2]).convert("RGB")
W, H = im.size; ground = im.getpixel((5, H - 5))
# the frame: the box of what is not the ground in the screen's lower third
pts = [(x, y) for y in range(H * 2 // 3, H) for x in range(W) if im.getpixel((x, y)) != ground]
if not pts:
    print("none"); sys.exit()
xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
# the frame is the box less its shadow (a column right, two rows under)
fw, fh = x1 - x0, y1 - y0 - 1
foot = H - 1 - (y1 - 2)
centre2 = x0 + (x1 - 1)                                   # (twice the frame's middle)
# the segments: on the frame's middle row, runs of one ink 6 px wide from the meter's start
y = y0 + 1 + 16 + 14                                      # (the row's 15th: a segment's foot)
row = [im.getpixel((x, y)) for x in range(x0 + 1 + 16 + 24, x0 + 1 + 16 + 24 + 160)]
segs = [row[i * 8 + 2] for i in range(20)]
lit = sum(1 for c in segs if c == segs[0])
top = [im.getpixel((x0 + 1 + 16 + 24 + 9 * 8 + 2, y0 + 1 + 16 + 5 + r)) for r in range(10)]
part = sum(1 for c in top if c == segs[0])
gone = any(g.getpixel((x, yy)) != ground for yy in range(y0, y1 + 1, 3) for x in range(x0, x1 + 1, 3))
print(fw, fh, foot, centre2, lit, part, int(gone))
EOF
)
  [[ $m != none ]] || { no "nothing shown"; continue; }
  read -r fw fh foot c2 lit part gone <<<"$m"
  ((fw == 258 && fh == 54)) || no "the frame $fw × $fh, not 258 × 54"
  ((foot == 72)) || no "its foot $foot px above the screen's edge, not 72"
  ((c2 >= 1918 && c2 <= 1920)) || no "not centred: the frame's middle ×2 is $c2 (1919 on a 1920 px screen)"
  ((lit == 10)) || no "$lit segments in the first one's ink on their foot row, not 10 (nine whole and the tenth's foot)"
  ((part == 4)) || no "the tenth segment lit $part rows from its foot, not 4 (47 %: 5 % a segment, 2 rows a percent)"
  ((gone == 0)) || no "still there 1.6 s after the key"
done
((fail)) && exit 1
echo "level-display: held — 258 × 54, centred, 72 px above the edge, 47 % as nine segments and the tenth's 4 rows, gone in time, both themes"
