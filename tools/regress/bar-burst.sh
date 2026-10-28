#!/usr/bin/env bash
# tools/regress/bar-burst.sh — the bar through a burst of workspace switches (T19k-1, the owner's
# 19:19 report: "the bar flickers for a split second when switching workspaces rapidly"): a
# headless kit (tools/kit.sh: dwl on the real GPU, the real waybar) with a terminal on 1 and on
# 2, then 1 ↔ 2 every 40 ms, 24 times, while the screen's top 40 rows are shot as fast as grim
# allows (~14 ms a shot). Then each shot's bar (rows 0 … BAR-1) and the rows under it are
# sorted into states: the bar's own (each must be a state it rests in — a seal, the clock —
# never a torn or blank one) and what the windows draw against its edge.
#   bash tools/regress/bar-burst.sh [--dwl BIN] [--out DIR] [--bar ROWS]
# Exit 0 no flash · 1 a flash under the bar (said: which shots) · 2 the kit could not run
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
dwl=/usr/local/bin/dwl out=/dev/shm/r27/bar-burst bar=27
while (($#)); do case $1 in --dwl) dwl=$2; shift 2 ;; --out) out=$2; shift 2 ;; --bar) bar=$2; shift 2 ;; *) echo "usage: $0 [--dwl BIN] [--out DIR] [--bar ROWS]" >&2; exit 2 ;; esac; done
rm -rf "$out"; mkdir -p "$out"
play=$out/burst.play
cat >"$play" <<'PLAY'
chord logo Return; nap 1.2
chord logo 2; nap 0.4
chord logo Return; nap 1.2
chord logo 1; nap 0.8
( i=0; while [[ ! -e $KIT_OUT/stop ]]; do grim -g "0,0 1920x40" "$KIT_OUT/b$(printf %04d "$i").png"; i=$((i + 1)); done ) &
nap 0.3
seq=(); for n in $(seq 12); do seq+=(-M logo -k 2 -m logo -s 40 -M logo -k 1 -m logo -s 40); done
wtype -s 300 "${seq[@]}"
nap 0.8
touch "$KIT_OUT/stop"; wait
say "bar shots: $(ls "$KIT_OUT"/b*.png | wc -l)"
PLAY
bash "$here/tools/kit.sh" --dwl "$dwl" --play "$play" --out "$out" --time 90 play >"$out/kit.log" 2>&1 || { echo "bar-burst: the kit did not run (see $out/kit.log)" >&2; exit 2; }
python3 -I - "$out" "$bar" <<'PY'
import glob, hashlib, sys
from PIL import Image
out, bar = sys.argv[1], int(sys.argv[2])
files = sorted(glob.glob(out + "/b*.png"))
def states(box):
    order = []
    for f in files:
        order.append(hashlib.md5(Image.open(f).convert("RGB").crop(box).tobytes()).hexdigest()[:6])
    runs = []
    for h in order:
        if runs and runs[-1][0] == h: runs[-1][1] += 1
        else: runs.append([h, 1])
    return order, runs
for name, box in (("the bar", (0, 0, 1920, bar)), ("under it", (0, bar, 1920, 40))):
    order, runs = states(box)
    print(f"{name}: {len(files)} shots, {len(set(order))} states, {len(runs)} runs, "
          f"{sum(1 for _, n in runs if n == 1)} shown for one shot only")
    print("  " + " ".join(f"{h[:4]}×{n}" for h, n in runs))
# a flash: under the bar, the windows' lit pixels (their frames' top lines) in one shot more
# than 300 away from both neighbours, the same way — a frame shown whole, dashed or gone for
# one shot (the dwl before animturn: a dashed top frame at every switch)
lit = []
for f in files:
    im = Image.open(f).convert("L").crop((0, bar, 1920, 40))
    lit.append(sum(im.point(lambda v: 255 if v > 70 else 0).histogram()[255:]))
flashes = [i for i in range(1, len(lit) - 1)
           if (lit[i] - lit[i - 1]) * (lit[i] - lit[i + 1]) > 0 and min(abs(lit[i] - lit[i - 1]), abs(lit[i] - lit[i + 1])) > 300]
print(f"flashes under the bar: {len(flashes)}" + (f" (shots {', '.join(map(str, flashes[:12]))})" if flashes else ""))
sys.exit(1 if flashes else 0)
PY
