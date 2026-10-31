#!/usr/bin/env bash
# tools/regress/dial.sh — never again (r27-19k-7, the master's review of quick settings' dial):
# the dial measured from its pixels, both moods — its frame in place (338 × 338, 8 px from the
# screen's right edge, its top on y 33), the forty beads mirror images across the middle, each
# corner's picture centred in its place, and the middle's block (picture or level, then its
# rows) centred on the middle in every state shot: at rest (the face), an hour, an arc (the
# pointer over a bead), a corner. Headless
# (tools/kit.sh, the real GPU).
#   bash tools/regress/dial.sh [KIT OPTION…]      (e.g. --bin bin --repo-art: before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-dial.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
# (the arc: the pointer over the brightness's tenth bead — hovered only: a click would set the
# real monitor's brightness through kawa-quick)
cat >"$out/play.sh" <<'PLAY'
panel
kawa-quick >/dev/null 2>&1 &
nap 2; shot rest
key Right; nap 0.3; shot theme
at 1655 207; nap 0.4; shot arc
at 1880 340; nap 0.4; shot corner
PLAY
fail=0
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 ||
    { echo "dial: the kit failed ($th): $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  python3 -I - "$out/$th" "$th" <<'PY' || fail=1
import sys
import numpy as np
from PIL import Image
d, th = sys.argv[1], sys.argv[2]
bad = []
def load(n):
    return np.asarray(Image.open(f"{d}/{n}.png").convert("RGB")).astype(int)
rest = load("rest")
H, W, _ = rest.shape
ground = rest[H - 3, 3]
ink = np.any(np.abs(rest - ground) > 8, axis=2)
# the frame: the columns and rows that are ink for most of the panel's height (its hairlines)
# (the shadow is ink too, a column right of the right hairline from its third row down and two
# rows under the bottom one: the hairlines are the long runs that reach the frame's first rows)
cols = np.nonzero(ink[40:360, 1400:].sum(axis=0) > 250)[0] + 1400
rows = np.nonzero(ink[31:600, 1400:].sum(axis=1) > 250)[0] + 31
if not len(cols) or not len(rows):
    print(f"dial ({th}): no frame found", file=sys.stderr); sys.exit(1)
fy0, fx0 = rows.min(), cols.min()
fx1 = max(c for c in cols if ink[fy0 + 1, c])                 # (the shadow's column starts lower)
fy1 = max(r for r in rows if not ink[r, fx1])                 # (the hairline's corner is cut; the shadow's row reaches it)
if (fx1 - fx0 + 1, fy1 - fy0 + 1, W - 1 - fx1, fy0) != (338, 338, 8, 33):
    bad.append(f"the frame {fx0}–{fx1} × {fy0}–{fy1} (338 × 338, 8 from the right edge, top 33)")
cx0, cy0 = fx0 + 17, fy0 + 17                      # the content's top left; the middle at +152
content = ink[cy0:cy0 + 304, cx0:cx0 + 304]
# (the hours' places are mirror images — test_panel proves it from the layout —; each picture
# keeps the air it was drawn with, so their ink is not measured for symmetry here)
# each corner: its picture's ink centred in its 36 px place (flush with the corner, 4 px into the
# pad — the round power sign overshoots the framed ones by a pixel, as round letters do)
for qx in (-4, 304 - 32):
    for qy in (-4, 304 - 32):
        q = ink[cy0 + qy:cy0 + qy + 36, cx0 + qx:cx0 + qx + 36]
        qys, qxs = np.nonzero(q)
        ox, oy = (qxs.min() + qxs.max() + 1) / 2 - 18, (qys.min() + qys.max() + 1) / 2 - 18
        if not (-0.5 <= ox <= 0 and -0.5 <= oy <= 0):
            bad.append(f"the corner at {qx},{qy}: its ink off its place's centre by {ox:+.1f}, {oy:+.1f}")
# the beads: the ring between radius 82 and 94 round the middle, mirrored across the upright
yy, xx = np.mgrid[0:304, 0:304]
r = np.hypot(xx + .5 - 152, yy + .5 - 152)
ring = content & (r > 82) & (r < 94)
if not np.array_equal(ring, ring[:, ::-1]):
    bad.append(f"the beads are not mirror images ({int((ring != ring[:, ::-1]).sum())} pixels differ)")
# the middle: the ink within 70 px of the middle (inside the beads), its block centred
def middle(n, ref=None):
    a = load(n)
    m = np.any(np.abs(a - ground) > 8, axis=2)[cy0:cy0 + 304, cx0:cx0 + 304] & (r < 70)
    ys, xs = np.nonzero(m)
    return (ys.min(), ys.max(), xs.min(), xs.max()) if len(ys) else None
for n in ("rest", "theme", "arc", "corner"):
    b = middle(n)
    if b is None:
        bad.append(f"{n}: nothing in the middle"); continue
    top, foot, left, right = b
    dy, dx = (top + foot + 1) / 2 - 152, (left + right + 1) / 2 - 152
    # (centred by the pictures' ink and the rows' capitals: a descender — "power", "light" —
    # hangs a pixel below; nothing more)
    if abs(dy) > 1 or abs(dx) > 1:
        bad.append(f"{n}: the middle's ink {left}–{right} × {top}–{foot} is off the middle by {dx:+.1f}, {dy:+.1f}")
for b in bad:
    print(f"dial ({th}): {b}", file=sys.stderr)
print(f"dial ({th}): frame {fx0}–{fx1} × {fy0}–{fy1}; corners centred in their places; beads mirrored; middle centred (rest, hour, arc, corner)" if not bad else "", end="\n" if not bad else "")
sys.exit(1 if bad else 0)
PY
done
((fail)) && exit 1
echo "dial: held — both moods"
