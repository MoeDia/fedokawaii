#!/usr/bin/env bash
# tools/regress/rail.sh — never again a rail through the words (lane-review, 4 Nov: the fusuma's rail ran 284 px
# inside the outgoing window, a switch during a move piled rails up, and every such switch stopped the windows
# dead): a real recording of a clean move, a move turned back at 180 ms, a burst of four at 120 ms. On a row under
# the bar, in every frame, each rail's run lies between the windows it divides (the focused windows' vermilion
# hairlines: never two windows' edges on one side of it), at most two rails at once.
#   bash tools/regress/rail.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-rail.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY_END'
# four workspaces, a window on each, set apart so the row crosses them
for t in 1 2 3 4 5; do
  chord logo "$t"; nap 0.3
  foot sh -c 'exec sleep 300' & nap 0.8
done
chord logo 1; nap 1
wf-recorder -c rawvideo -f "$KIT_OUT/moves.nut" -m nut >/dev/null 2>&1 & rec=$!
nap 0.6
chord logo 2; nap 1
chord logo 1; nap 1
# (turned back at 180 ms; then a burst at 120 ms)
wtype -s 300 -M logo -k 2 -m logo -s 180 -M logo -k 1 -m logo; nap 1
wtype -s 300 -M logo -k 2 -m logo -s 120 -M logo -k 3 -m logo -s 120 -M logo -k 4 -m logo -s 120 -M logo -k 5 -m logo; nap 1
kill -INT "$rec"; wait "$rec" 2>/dev/null
PLAY_END
bash "$here/../kit.sh" --theme dark --time 150 "$@" --out "$out/kit" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "rail: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
[[ -s $out/kit/moves.nut ]] || { echo "rail: no recording" >&2; exit 2; }
ffmpeg -v error -i "$out/kit/moves.nut" -fps_mode passthrough -vf "crop=1920:1:0:1050,format=rgb24" -f rawvideo "$out/row.rgb" \
  || { echo "rail: the recording could not be read" >&2; exit 2; }
python3 -I - "$out/row.rgb" <<'PY_END'
import sys
import numpy as np
a = np.fromfile(sys.argv[1], np.uint8).reshape(-1, 1920, 3).astype(int)
ACC, LACQUER = np.array([0xeb, 0x53, 0x24]), np.array([0x82, 0x24, 0x1f])   # (the windows' hairline; the rail's wood)
def runs(row, ink):
    xs = np.flatnonzero(np.abs(row - ink).sum(axis=1) < 8)
    out = []
    for x in xs:
        if out and x == out[-1][1] + 1:
            out[-1][1] = int(x)
        else:
            out.append([int(x), int(x)])
    return out
RAIL = 6                                     # (the rail's wood: three of the wallpapers' pixels, cut at the screen's edge)
bad, moved, rails = [], 0, 0
prev = None
for i, row in enumerate(a):
    if prev is not None and (row != prev).any():
        moved += 1
    prev = row
    wide = [q for q in runs(row, LACQUER) if q[1] - q[0] + 1 >= RAIL or q[0] == 0 or q[1] == 1919]
    thin = [q[0] for q in runs(row, ACC)]
    rails = max(rails, len(wide))
    if len(wide) > 2:
        bad.append(f"frame {i}: {len(wide)} rails at once at {[q[0] for q in wide]}")
    # (the windows nearly fill the screen, so a stretch of the row the rails cut holds one window's edge, not two:
    # two in one stretch, narrower than a window, are a rail inside a window or windows across each other)
    edges = [-1] + [e for q in wide for e in q] + [1920]
    for lo, hi in zip(edges[::2], edges[1::2]):
        here = [x for x in thin if lo < x < hi]
        if wide and len(here) > 1 and hi - lo < 1800:
            bad.append(f"frame {i}: a window's edges at {here} between {lo} and {hi}, rails at {[q[0] for q in wide]}")
if moved < 20:
    bad.append(f"only {moved} frames moved: nothing was tested")
if not rails:
    bad.append("no rail seen in any frame")
print("rail: " + ("; ".join(bad[:6]) + f" … {len(bad)} in all" if bad else f"held — {len(a)} frames, {moved} moving, at most {rails} rails, each between the windows"))
sys.exit(1 if bad else 0)
PY_END
