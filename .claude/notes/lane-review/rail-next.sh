#!/usr/bin/env bash
# tools/regress/rail.sh — never again a rail through the words (lane-review, 4 Nov: the fusuma's rail ran 284 px
# inside the outgoing window, a switch during a move piled rails up, and every such switch stopped the windows
# dead; then the strip kept what the wave had left behind: after a double switch the old window lay 210 px over
# the new workspace until the move's end, and went in one frame): a real recording, one row of the screen, of a
# clean move, a move turned back at 180 ms, a double switch at 110 ms, a burst of four at 120 ms, two windows on each
# workspace. In every frame: at most two rails, no rail between a focused window's two hairlines; once the last
# rail has gone, no focused hairline but near the ones the move ends on.
#   bash tools/regress/rail.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-rail.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY_END'
# five workspaces, two windows on each, the right one focused: its hairlines are on the row for most of a move
for t in 1 2 3 4 5; do
  chord logo "$t"; nap 0.3
  foot sh -c 'exec sleep 300' & nap 0.8
  foot sh -c 'exec sleep 300' & nap 0.8
done
chord logo 1; nap 1
wf-recorder -g "0,1050 1920x2" -c rawvideo -f "$KIT_OUT/moves.nut" -m nut >/dev/null 2>&1 & rec=$!
nap 0.6
chord logo 2; nap 1
chord logo 1; nap 1
# (turned back at 180 ms; a double switch at 110 ms, the window behind the strip's clock; a burst at 120 ms)
wtype -s 300 -M logo -k 2 -m logo -s 180 -M logo -k 1 -m logo; nap 1
wtype -s 300 -M logo -k 2 -m logo -s 110 -M logo -k 3 -m logo; nap 1
chord logo 1; nap 1
wtype -s 300 -M logo -k 2 -m logo -s 120 -M logo -k 3 -m logo -s 120 -M logo -k 4 -m logo -s 120 -M logo -k 5 -m logo; nap 1
kill -INT "$rec"; wait "$rec" 2>/dev/null
PLAY_END
bash "$here/../kit.sh" --theme dark --time 150 "$@" --out "$out/kit" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "rail: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
[[ -s $out/kit/moves.nut ]] || { echo "rail: no recording" >&2; exit 2; }
ffmpeg -v error -i "$out/kit/moves.nut" -fps_mode passthrough -vf "crop=1920:1:0:0,format=rgb24" -f rawvideo "$out/row.rgb" \
  || { echo "rail: the recording could not be read" >&2; exit 2; }
python3 -I - "$out/row.rgb" <<'PY_END'
import sys
import numpy as np
a = np.fromfile(sys.argv[1], np.uint8).reshape(-1, 1920, 3).astype(int)
ACC, LACQUER = np.array([0xeb, 0x53, 0x24]), np.array([0x82, 0x24, 0x1f])   # (the windows' hairline; the rail's wood)
PAST = 48                                    # (coming to rest: past its place, a burst's speed in it, or the last of the wave)
def runs(row, ink):
    xs = np.flatnonzero(np.abs(row - ink).sum(axis=1) < 8)
    out = []
    for x in xs:
        if out and x == out[-1][1] + 1:
            out[-1][1] = int(x)
        else:
            out.append([int(x), int(x)])
    return out
def hairs(row):
    return [q[0] for q in runs(row, ACC)]
rest = hairs(a[0])
if len(rest) != 2:
    print(f"rail: at rest {rest}: not two hairlines of a focused window")
    sys.exit(2)
W = rest[1] - rest[0]
bad, rails, moved = [], 0, 0
wides = [runs(row, LACQUER) for row in a]
thins = [hairs(row) for row in a]
for i, (wide, thin) in enumerate(zip(wides, thins)):
    if i and (a[i] != a[i - 1]).any():
        moved += 1
    rails = max(rails, len(wide))
    if len(wide) > 2:
        bad.append(f"frame {i}: {len(wide)} rails at once at {[q[0] for q in wide]}")
    for l in thin:
        if l + W in thin:
            for q in wide:
                if l < q[0] and q[1] < l + W:
                    bad.append(f"frame {i}: the rail at {q[0]} inside the window {l}…{l + W}")
# each move, from the frame the row leaves its rest to the frame it is back: once its last rail has gone, nothing
# but the workspace coming to rest may show a hairline
i = 0
while i < len(a):
    if (a[i] == a[0]).all():
        i += 1
        continue
    j = i
    while j < len(a) and not (a[j] == a[0]).all():
        j += 1
    last = max((k for k in range(i, j) if wides[k]), default=i - 1)
    for k in range(last + 1, j):
        for x in thins[k]:
            if min(abs(x - y) for y in rest) > PAST:
                bad.append(f"frame {k}: a hairline at {x}, no rail left: a window of the workspace left behind on the screen")
    i = j
if moved < 20:
    bad.append(f"only {moved} frames moved: nothing was tested")
if not rails:
    bad.append("no rail seen in any frame")
print("rail: " + ("; ".join(bad[:6]) + f" … {len(bad)} in all" if bad else f"held — {len(a)} frames, {moved} moving, at most {rails} rails, each between the windows, nothing left behind"))
sys.exit(1 if bad else 0)
PY_END
