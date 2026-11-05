#!/usr/bin/env bash
# tools/regress/bar-layout.sh — the bar's keyboard tile (the owner's bar redesign: "US red / AR blue and clickable";
# 27 Oct 14:27: capitals while Caps Lock is on): the real bar, both themes: us red, ar blue, AR and US in capitals in
# the same inks, and a click on the tile asks dwl for the next layout; back on us, every pixel as it was.
# The layouts arrive as dwl says them, on the pipe the real kawa-dwlstatus reads: dwl's own switch (kbnext) needs a
# physical keyboard, no headless has one. The click is caught at dwl's fifo; what dwl does then, tests/session and his PC.
#   bash tools/regress/bar-layout.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-blay.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY_END'
status() { printf 'HEADLESS-1 %s\n' "$@" >"/proc/$$/fd/0"; nap 1; }
at 960 600; nap 0.5
shot us 0,0 1920x40
status 'kbcaps 0' 'kblayout 1'; shot ar 0,0 1920x40
status 'kbcaps 1' 'kblayout 1'; shot AR 0,0 1920x40
status 'kbcaps 1' 'kblayout 0'; shot US 0,0 1920x40
status 'kbcaps 0' 'kblayout 0'
# (the tile: the first run of columns where us and ar differ, right of the clock; what comes after is the memory's figure)
python3 -I - "$KIT_OUT/us.png" "$KIT_OUT/ar.png" >"$KIT_OUT/box" <<'PY_END'
import sys
import numpy as np
from PIL import Image
a, b = (np.asarray(Image.open(f).convert("RGB"), dtype=np.int16) for f in sys.argv[1:3])
m = np.any(a != b, axis=-1)
m[:, :1250] = False
cols = np.nonzero(m.any(axis=0))[0]
if cols.size:
    end = cols[0]
    for c in cols[1:]:
        if c - end >= 8:
            break
        end = c
    ys = np.nonzero(m[:, cols[0]:end + 1].any(axis=1))[0]
    print(cols[0], end + 1, ys[0], ys[-1] + 1)
PY_END
read -r x0 x1 y0 y1 <"$KIT_OUT/box" || exit 0
f=$XDG_RUNTIME_DIR/dwl-warm
mv "$f" "$f.dwl" && mkfifo "$f"
timeout 6 head -n 1 "$f" >"$KIT_OUT/clicked" & reader=$!
nap 0.3
at $(((x0 + x1) / 2)) $(((y0 + y1) / 2)); nap 0.3; click
wait "$reader"
mv -f "$f.dwl" "$f"
at 960 600; nap 0.8
shot back 0,0 1920x40
PLAY_END
fail=0
for th in dark light; do
  XKB_DEFAULT_LAYOUT=us,ara XKB_DEFAULT_OPTIONS=grp:alt_shift_toggle \
    bash "$here/../kit.sh" --theme "$th" "$@" --time 120 --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "bar-layout: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  python3 -I - "$out/$th" "$th" <<'PY_END'
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
us, ar, AR, US = load("us"), load("ar"), load("AR"), load("US")
box = open(os.path.join(d, "box")).read().split()
if not box:
    print(f"bar-layout ({th}): the tile did not change with the layout")
    sys.exit(1)
x0, x1, y0, y1 = map(int, box)
def ink(a, b):
    """The colour of what a's letters add to b's in the tile: the commonest far from a's own paper."""
    t = a[:, x0 - 3:x1 + 3]
    moved = np.any(t != b[:, x0 - 3:x1 + 3], axis=-1)
    cols, n = np.unique(t[y0:y1].reshape(-1, 3), axis=0, return_counts=True)
    paper = cols[n.argmax()]
    cols, n = np.unique(t[moved].reshape(-1, 3), axis=0, return_counts=True)
    far = np.abs(cols - paper).sum(axis=1) > 60
    return cols[far][n[far].argmax()] if far.any() else paper
def hx(c):
    return f"#{c[0]:02x}{c[1]:02x}{c[2]:02x}"
def top(a, b):
    """The first row where a and b differ in the tile: how high the letters reach."""
    return int(np.nonzero(np.any(a[:, x0 - 3:x1 + 3] != b[:, x0 - 3:x1 + 3], axis=-1).any(axis=1))[0][0])
bad = []
u, r = ink(us, ar), ink(ar, us)
if not u[0] > u[2]:
    bad.append(f"us is not red: {hx(u)}")
if not r[2] > r[0]:
    bad.append(f"ar is not blue: {hx(r)}")
for name, a, b, want in (("US", US, us, u), ("AR", AR, ar, r)):
    if not np.any(a[:, x0 - 3:x1 + 3] != b[:, x0 - 3:x1 + 3]):
        bad.append(f"{name}: Caps Lock did not change the letters")
    else:
        if top(a, b) >= y0:
            bad.append(f"{name}: no capitals, the letters reach row {top(a, b)}, the small ones {y0}")
        if not np.array_equal(ink(a, b), want):
            bad.append(f"{name} in another ink: {hx(ink(a, b))}, {hx(want)} without Caps Lock")
clicked = open(os.path.join(d, "clicked")).read().strip() if os.path.exists(os.path.join(d, "clicked")) else ""
if clicked != "kb next":
    bad.append(f"a click on the tile asked dwl for {clicked!r}, not 'kb next'")
back = load("back")
moved = np.any(back != us, axis=-1)
moved[:, 700:1250] = False        # (the clock)
moved[:, x1 + 3:] = False         # (the memory's figure, the level)
if moved.any():
    bad.append(f"back on us the bar is not what it was: {int(moved.sum())} px differ")
for b in bad:
    print(f"bar-layout ({th}): {b}")
if not bad:
    print(f"bar-layout ({th}): us {hx(u)} · ar {hx(r)} · capitals reach row {top(US, us)}, small letters {y0} · the tile at x {x0}–{x1}")
sys.exit(1 if bad else 0)
PY_END
  r=$?
  ((r == 2)) && exit 2
  ((r)) && fail=1
done
((fail)) && exit 1
echo "bar-layout: held — us red, ar blue, capitals with Caps Lock in the same inks, a click on the tile asks for the next layout, both themes"
