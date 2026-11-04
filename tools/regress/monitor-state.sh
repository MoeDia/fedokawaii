#!/usr/bin/env bash
# tools/regress/monitor-state.sh — never again "turning the monitor on always lands on workspace 1" (owner, 26 Oct
# 14:07; r27-2): a headless dwl with a window on workspace 3, the layout changed, then the monitor off and
# on as the desktop does it: power off (wlopm, the idle and the quick-settings' key; a key lights it) and output
# off (wlr-randr, what a monitor's own button looks like to the session): back on workspace 3, the same
# window focused, every pixel of the screen as it was. The real cable's cut: tools/hotplug-test.sh (root).
#   bash tools/regress/monitor-state.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-mon.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY_END'
at 1900 1000
chord logo 3; nap 0.8
foot sh -c 'printf "on workspace three\n"; exec sleep 200' >/dev/null 2>&1 & nap 1
foot sh -c 'printf "the other window\n"; exec sleep 200' >/dev/null 2>&1 & nap 1
chord logo y; nap 0.8; shot before
o=$(wlr-randr | sed -n '1s/ .*//p')
say "output $o"
wlopm --off "$o"; nap 2; say "power: $(wlopm | tr '\n' ' ')"
wtype -s 300 -k space; nap 2; shot after-power
wlr-randr --output "$o" --off; nap 1.5
wlr-randr --output "$o" --on --custom-mode 1920x1080@144Hz; nap 3; shot after-output
PLAY_END
bash "$here/../kit.sh" --theme dark "$@" --time 60 --out "$out/dark" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "monitor-state: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
python3 -I - "$out/dark" <<'PY_END'
import os, sys
import numpy as np
from PIL import Image
d = sys.argv[1]
def load(n):
    p = os.path.join(d, n + ".png")
    if not os.path.exists(p):
        print(f"monitor-state: no shot {n}")
        sys.exit(2)
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16)
before = load("before")
bad = []
for n, what in (("after-power", "its power off and on"), ("after-output", "the output off and on")):
    a = load(n)
    if a.shape != before.shape:
        bad.append(f"{what}: the screen {a.shape[1]} × {a.shape[0]}")
        continue
    moved = np.any(a != before, axis=-1)
    moved[:27, 700:1250] = False           # (the clock may have turned a minute)
    moved[:27, 1600:] = False              # (the memory's figure, the level)
    if int(moved.sum()) > 320:             # (the space typed: its cursor one cell on, two cells of 8 × 20)
        ys, xs = np.nonzero(moved)
        bad.append(f"{what}: {int(moved.sum())} px changed, x {xs.min()}–{xs.max()}, y {ys.min()}–{ys.max()}")
print("\n".join(f"monitor-state: {b}" for b in bad) if bad else "monitor-state: held — workspace 3, its layout and its focus back as they were, by power and by output, pixel for pixel")
sys.exit(1 if bad else 0)
PY_END
