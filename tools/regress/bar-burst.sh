#!/usr/bin/env bash
# tools/regress/bar-burst.sh — the bar through a burst of workspace switches (T19k-1, the owner's
# 19:19 report: "the bar flickers for a split second when switching workspaces rapidly"): a
# headless kit (tools/kit.sh: dwl on the real GPU, the real waybar) with a terminal on 1 and on
# 2, then 1 ↔ 2 every 40 ms, 24 times, while the screen's top 40 rows are shot as fast as grim
# allows (~14 ms a shot), then six more 180 ms apart. Then each shot's bar (rows 0 … BAR-1) and the rows under it are
# sorted into states: the bar's own (each must be a state it rests in — a seal, the clock —
# never a torn or blank one) and what the windows draw against its edge.
#   bash tools/regress/bar-burst.sh [--dwl BIN] [--out DIR] [--bar ROWS]
# Exit 0 nothing pops · 1 a pop or a frame changing colour under the bar (said) · 2 the kit could not run
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
# (slower: each window gets well into its dissolve before it is sent back)
seq=(); for n in $(seq 6); do seq+=(-M logo -k 2 -m logo -s 180 -M logo -k 1 -m logo -s 180); done
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
# a pop: under the bar, the windows' frames (their top lines' lit pixels) jumping by more than
# one dissolve step between two shots — a dissolve moves a quarter of a line a step (the 4 × 4
# Bayer order: a row of cells comes a quarter at a time), and at ~14 ms a shot never more than
# one step (17.5 ms each over 280 ms); more is a window snapped whole or gone. The frame's
# colour too: a window's frame turning grey ↔ red under the bar with the switches is a flicker
lit, col = [], []
for f in files:
    im = Image.open(f).convert("RGB")
    g = im.convert("L").crop((0, bar, 1920, 40))
    lit.append(sum(g.point(lambda v: 255 if v > 70 else 0).histogram()[255:]))
    row = [im.getpixel((x, bar + 6)) for x in range(10, 1910, 7)]
    red = sum(1 for r, gg, b in row if r > 180 and gg < 120); grey = sum(1 for r, gg, b in row if 90 < r < 150 and abs(r - gg) < 20)
    col.append("red" if red > grey and red > 20 else "grey" if grey > 20 else "")
step = 1920 / 4 * 1.25
pops = [i for i in range(1, len(lit)) if abs(lit[i] - lit[i - 1]) > step]
turns = sum(1 for a, b in zip(col, col[1:]) if a and b and a != b)
print(f"pops under the bar: {len(pops)}" + (f" (shots {', '.join(map(str, pops[:12]))})" if pops else ""))
print(f"frame colour changes under the bar: {turns}")
sys.exit(1 if pops or turns else 0)
PY
