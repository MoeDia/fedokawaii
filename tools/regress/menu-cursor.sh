#!/usr/bin/env bash
# tools/regress/menu-cursor.sh — never again a cursor that leaves its ends behind (found 4 Nov in the review's
# highlight page: a row's lacquer reaches a cell beyond the content either side, but only the content was
# redrawn when the cursor moved, so the row it left kept two stubs and the row it reached had none): the power
# menu in the kit, the cursor walked down and up, each row's band measured at each step, both moods.
#   bash tools/regress/menu-cursor.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-cursor.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
panel; nap 1
setsid -f kawa-power; nap 1.5
shot s0
key Down; nap 0.4; shot s1
key Down; nap 0.4; shot s2
key Up; nap 0.4; shot s3
key Escape; nap 0.6
PLAY
for mood in dark light; do
  bash "$here/../kit.sh" --theme "$mood" --time 40 "$@" --out "$out/$mood" --play "$out/play.sh" play >"$out/$mood.log" 2>&1 \
    || { echo "menu-cursor: the kit failed ($mood): $(tail -n 2 "$out/$mood.log")" >&2; exit 2; }
done
python3 -I - "$out" <<'PY'
import sys
import numpy as np
from PIL import Image
out = sys.argv[1]
bad = []
for mood in ("dark", "light"):
    seen = []
    for s in range(4):
        im = np.asarray(Image.open(f"{out}/{mood}/s{s}.png").convert("RGB")).astype(int)
        # the lacquer: the red of the runs of 40 px or more (no word's, no icon's)
        red = (im[:, :, 0] - im[:, :, 1] > 60) & (im[:, :, 0] - im[:, :, 2] > 60)
        rows = np.flatnonzero(red[40:].sum(axis=1) >= 40) + 40
        if not len(rows):
            bad.append(f"{mood} s{s}: no cursor")
            continue
        y = int(rows[len(rows) // 2])
        x = int(np.flatnonzero(red[y]).min())
        lacquer = im[y, x]
        same = (im == lacquer).all(axis=2)
        band = np.flatnonzero(same[rows.min():rows.max() + 1].any(axis=0))
        seen.append((int(band.min()), int(band.max())))
        # nothing of it anywhere else on the screen: a stub is its colour off the cursor's rows
        off = same.copy()
        off[:40] = False
        off[rows.min():rows.max() + 1] = False
        if off.sum():
            ys, xs = np.nonzero(off)
            bad.append(f"{mood} s{s}: {int(off.sum())} px of the lacquer off the cursor's rows, first at {int(xs[0])},{int(ys[0])}")
    if len(set(seen)) > 1:
        bad.append(f"{mood}: the cursor's ends move between rows: {seen}")
print("menu-cursor: " + ("; ".join(bad) if bad else "held: the cursor whole on every row, nothing left behind"))
sys.exit(1 if bad else 0)
PY
