#!/usr/bin/env bash
# tools/regress/power-dialog.sh — never an accidental power-off (the owner's page 14, §4): the power dialog in the kit, its
# systemctl a stand-in that only writes down what it was asked. Shut down's first press does nothing but ask, in the foot's
# place; a second at once is no press, nor is any repeat of a key held down; moving away takes it back; the second press after the hold
# does it, once. The dialog centred on the screen to the pixel over the desktop dimmed 40 %; a seal's own letter
# (d: shut down) asks too.
#   bash tools/regress/power-dialog.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-power.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
mkdir -p "$KIT_OUT/stub"; printf '#!/bin/sh\necho "$*" >>"%s/asked"\n' "$KIT_OUT" >"$KIT_OUT/stub/systemctl"; chmod +x "$KIT_OUT/stub/systemctl"
export PATH=$KIT_OUT/stub:$PATH
: >"$KIT_OUT/asked"
panel; ready
shot rest
setsid -f kawa-power; nap 1.2; shot open
key Right Right Right Right; nap 0.3; shot on-off
# (Enter held 1.5 s: dwl's repeat, from 300 ms on every 29 ms; the first press asks, not one repeat is a second)
wtype -s 300 -P Return -s 1500 -p Return; nap 0.3
say "after a held key: $(cat "$KIT_OUT/asked")"
key Left; nap 0.5; key Right; nap 0.5
key Return; nap 0.15; shot asked
say "after the first press: $(cat "$KIT_OUT/asked")"
key Left; nap 0.5; shot away
key Right; nap 0.5; key Return; nap 0.8; key Return
for _ in $(seq 40); do [[ -s $KIT_OUT/asked ]] && break; nap 0.1; done
say "after the second press: $(cat "$KIT_OUT/asked")"
shot done
: >"$KIT_OUT/asked"
setsid -f kawa-power; nap 1.2
key d; nap 0.3; shot key-d
say "after its letter: $(cat "$KIT_OUT/asked")"
key Escape; nap 0.5
PLAY
for mood in dark light; do
  bash "$here/../kit.sh" --theme "$mood" --time 280 "$@" --out "$out/$mood" --play "$out/play.sh" play >"$out/$mood.log" 2>&1 \
    || { echo "power-dialog: the kit failed ($mood): $(tail -n 2 "$out/$mood.log")" >&2; exit 2; }
  grep -q '^after a held key: $' "$out/$mood/play.log" || { echo "power-dialog: Enter held did it ($mood): $(cat "$out/$mood/play.log")" >&2; exit 1; }
  grep -q '^after the first press: $' "$out/$mood/play.log" || { echo "power-dialog: the first press did something ($mood): $(cat "$out/$mood/play.log")" >&2; exit 1; }
  grep -q '^after the second press: poweroff$' "$out/$mood/play.log" || { echo "power-dialog: the second press ($mood): $(grep second "$out/$mood/play.log")" >&2; exit 1; }
  grep -q '^after its letter: $' "$out/$mood/play.log" || { echo "power-dialog: d did it at once ($mood): $(grep letter "$out/$mood/play.log")" >&2; exit 1; }
done
python3 -I - "$out" <<'PY'
import sys
import numpy as np
from PIL import Image
out = sys.argv[1]
bad = []
for mood in ("dark", "light"):
    load = lambda n: np.asarray(Image.open(f"{out}/{mood}/{n}.png").convert("RGB")).astype(int)
    rest, op, asked, away = load("rest"), load("open"), load("asked"), load("away")
    # the dim: a pixel of the bare ground, darkened by Wada's Black at 40 %
    g, d = rest[1070, 5], op[1070, 5]
    want = np.round(g * 0.6 + np.array([0x11, 0x13, 0x14]) * 0.4)
    if np.abs(d - want).max() > 2:
        bad.append(f"{mood}: the dim {d.tolist()}, not {want.tolist()}")
    # the frame centred: what differs from the dim, its hairlines
    diff = (op != d).any(axis=2)
    diff[:40] = False
    ys, xs = np.nonzero(diff)
    # (a hanging scroll, sa16: its rods and their caps either side, the same past each end, over the shadow — the window's
    # every edge drawn, so what differs is the frame's box with the same air either side)
    left, right, top, foot = int(xs.min()), 1919 - int(xs.max()), int(ys.min()), 1079 - int(ys.max())
    if left != right or top != foot:
        bad.append(f"{mood}: the frame's margins {left} {right} · {top} {foot}")
    if not (load("key-d") != op).any():
        bad.append(f"{mood}: d (shut down's letter) asked nothing")
    if not (asked != away).any():
        bad.append(f"{mood}: the first press changed nothing to see, or moving away took nothing back")
print("power-dialog: " + ("; ".join(bad) if bad else "held: the first press asks, a key held down never does it, the second press does it once; centred to the pixel on the dimmed desktop"))
sys.exit(1 if bad else 0)
PY
