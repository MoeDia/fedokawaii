#!/usr/bin/env bash
# tools/regress/menu-cursor.sh — never again a cursor that leaves its ends behind (found 4 Nov in the review's
# highlight page: only the content was redrawn when the cursor moved, so the row it left kept two stubs): the timer's
# menu in the kit, the cursor walked down and up, each row's band measured at each step, both moods — the tint the
# content's width on the row's 20 rows, its 2 px edge at the left (§4), none of it anywhere else.
#   bash tools/regress/menu-cursor.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-cursor.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
panel; ready
say "select $(sed -n 's/^select=//p' "$HOME/.config/fedokawaii/current/panel.conf")"
say "edge $(sed -n 's/^select_edge=//p' "$HOME/.config/fedokawaii/current/panel.conf")"
setsid -f kawa-timer; nap 1.5
shot s0
key Down; nap 0.4; shot s1
key Down; nap 0.4; shot s2
key Up; nap 0.4; shot s3
key Escape; nap 0.6
PLAY
for mood in dark light; do
  bash "$here/../kit.sh" --theme "$mood" --time 280 "$@" --out "$out/$mood" --play "$out/play.sh" play >"$out/$mood.log" 2>&1 \
    || { echo "menu-cursor: the kit failed ($mood): $(tail -n 2 "$out/$mood.log")" >&2; exit 2; }
done
python3 -I - "$out" <<'PY'
import sys
import numpy as np
from PIL import Image
out = sys.argv[1]
bad = []
for mood in ("dark", "light"):
    say = dict(ln.split() for ln in open(f"{out}/{mood}/play.log") if len(ln.split()) == 2)
    rgb = lambda h: np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)])
    tint, edge = rgb(say["select"]), rgb(say["edge"])
    seen, tops = [], []
    for s in range(4):
        im = np.asarray(Image.open(f"{out}/{mood}/s{s}.png").convert("RGB")).astype(int)
        same = (im == tint).all(axis=2)
        same[:40] = False
        rows = np.flatnonzero(same.sum(axis=1) >= 40)
        if not len(rows):
            bad.append(f"{mood} s{s}: no cursor")
            continue
        band = np.flatnonzero(same[rows.min():rows.max() + 1].any(axis=0))
        seen.append((int(band.min()), int(band.max())))
        tops.append(int(rows.min()))
        if rows.max() - rows.min() + 1 != 20:
            bad.append(f"{mood} s{s}: the band {rows.max() - rows.min() + 1} rows")
        e = np.flatnonzero((im[int(rows.min()) + 1] == edge).all(axis=1))
        e = e[(e >= band.min() - 2) & (e <= band.min())]
        if len(e) != 2:
            bad.append(f"{mood} s{s}: its edge {len(e)} px, not 2")
        # nothing of it anywhere else on the screen: a stub is its colour off the cursor's rows
        off = same.copy()
        off[rows.min():rows.max() + 1] = False
        if off.sum():
            ys, xs = np.nonzero(off)
            bad.append(f"{mood} s{s}: {int(off.sum())} px of the tint off the cursor's rows, first at {int(xs[0])},{int(ys[0])}")
    if len(set(seen)) > 1:
        bad.append(f"{mood}: the cursor's ends move between rows: {seen}")
    if len(tops) == 4 and not (tops[0] < tops[1] < tops[2] and tops[3] == tops[1]):
        bad.append(f"{mood}: the cursor did not walk: {tops}")
print("menu-cursor: " + ("; ".join(bad) if bad else "held: the cursor whole on every row, its edge 2 px, nothing left behind"))
sys.exit(1 if bad else 0)
PY
