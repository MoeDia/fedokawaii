#!/usr/bin/env bash
# tools/regress/bar-layout.sh — the bar's keyboard tile (the owner's bar redesign: "US red / AR blue and clickable"):
# the real bar with two layouts, both themes: the tile red with us, blue once the layout moves on (dwl's own
# "kb next"), and a click on it brings us back, every pixel as it was.
#   bash tools/regress/bar-layout.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-blay.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY_END'
at 960 600
nap 0.5
shot us 0,0 1920x40
echo "kb next" >"$XDG_RUNTIME_DIR/dwl-warm"; nap 1.5
shot ar 0,0 1920x40
# (the tile: where the two differ, the clock's end left out)
read -r x y < <(python3 -I - "$KIT_OUT/us.png" "$KIT_OUT/ar.png" <<'PY_END'
import sys
import numpy as np
from PIL import Image
a, b = (np.asarray(Image.open(f).convert("RGB"), dtype=np.int16) for f in sys.argv[1:3])
m = np.any(a != b, axis=-1)
m[:, 700:1250] = False
ys, xs = np.nonzero(m)
print(int(xs.min() + xs.max()) // 2, int(ys.min() + ys.max()) // 2)
PY_END
)
say "tile $x $y"
at "$x" "$y"; nap 0.3; click; nap 1.5
at 960 600; nap 0.8
shot back 0,0 1920x40
PLAY_END
fail=0
for th in dark light; do
  XKB_DEFAULT_LAYOUT=us,ara XKB_DEFAULT_OPTIONS=grp:alt_shift_toggle \
    bash "$here/../kit.sh" --theme "$th" "$@" --time 120 --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "bar-layout: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  python3 -I - "$out/$th" "$th" <<'PY_END' || fail=1
import os, sys
import numpy as np
from PIL import Image
d, th = sys.argv[1:3]
def load(n):
    p = os.path.join(d, n + ".png")
    if not os.path.exists(p):
        print(f"bar-layout ({th}): no shot {n}")
        sys.exit(2)
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16)
us, ar, back = load("us"), load("ar"), load("back")
m = np.any(us != ar, axis=-1)
m[:, 700:1250] = False
if not m.any():
    print(f"bar-layout ({th}): the tile did not change with the layout")
    sys.exit(1)
ys, xs = np.nonzero(m)
box = (ys.min(), ys.max() + 1, xs.min(), xs.max() + 1)
def ink(a):
    """The colour of the most-changed pixels of the tile's letters: what differs from its paper, the commonest colour in it."""
    t = a[box[0]:box[1], box[2]:box[3]].reshape(-1, 3)
    cols, n = np.unique(t, axis=0, return_counts=True)
    paper = cols[n.argmax()]
    far = np.abs(cols - paper).sum(axis=1) > 60
    return cols[far][n[far].argmax()]
bad = []
u, r = ink(us), ink(ar)
if not u[0] > u[2]:
    bad.append(f"us is not red: #{u[0]:02x}{u[1]:02x}{u[2]:02x}")
if not r[2] > r[0]:
    bad.append(f"ar is not blue: #{r[0]:02x}{r[1]:02x}{r[2]:02x}")
moved = np.any(back != us, axis=-1)
moved[:, 700:1250] = False
moved[:, 1600:] = False           # (the memory's figure, the level)
if moved.any():
    bad.append(f"a click on the tile did not bring us back: {int(moved.sum())} px differ")
for b in bad:
    print(f"bar-layout ({th}): {b}")
sys.exit(1 if bad else 0)
PY_END
done
((fail)) && exit 1
echo "bar-layout: held — us red, ar blue, a click on the tile back to us, both themes"
