#!/usr/bin/env bash
# tools/regress/rail.sh — the workspace move's rail stands between the two workspaces (§11; lane-review, 4 Nov): a kit
# play, two windows on 1, one on 2 and on 3: a clean move, a move back after 180 ms, a burst of four moves 120 ms
# apart, recorded and measured on a row under the bar (a recording's pace is only for looking; positions are what is
# judged here). On a clean move the rail is never over the window leaving; a move back has one rail; a burst at most
# two, one to a seam. Headless (tools/kit.sh, the real GPU).
#   bash tools/regress/rail.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-rail.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<PLAY
OUT=$out
PLAY
cat >>"$out/play.sh" <<'PLAY'
panel; warm; nap 1.5
chord logo Return; nap 1.5
chord logo Return; nap 1.5
chord logo 2; nap 1
chord logo Return; nap 1.5
chord logo 3; nap 1
chord logo Return; nap 1.5
chord logo 1; nap 1.2
rec() { wf-recorder -y -c ffv1 -f "$1" >/dev/null 2>&1 & R=$!; nap 1; }
fin() { kill -INT "$R"; wait "$R" 2>/dev/null; }
rec "$OUT/clean.mkv"; chord logo 2; nap 1; fin
chord logo 1; nap 1.2
rec "$OUT/back.mkv"; chord logo 2 & sleep 0.18; chord logo 1 & nap 1.4; fin
nap 0.8
rec "$OUT/burst.mkv"; chord logo 2 & sleep 0.12; chord logo 3 & sleep 0.12; chord logo 4 & sleep 0.12; chord logo 5 & nap 1.6; fin
PLAY
bash "$here/../kit.sh" --theme dark --time 90 "$@" --out "$out/k" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "rail: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
for n in clean back burst; do
  [[ -s $out/$n.mkv ]] || { echo "rail: no recording of $n" >&2; exit 2; }
  mkdir -p "$out/$n"; ffmpeg -v error -i "$out/$n.mkv" -fps_mode passthrough "$out/$n/%05d.png" || exit 2
done
python3 -I - "$out" "${KIT_THEME_DIR:-$HOME/.config/fedokawaii/themes/dark}" <<'PY'
import glob, sys
import numpy as np
from PIL import Image
out, theme = sys.argv[1:]
col = {w[0]: w[1] for w in (l.split() for l in open(f"{theme}/dwl.colors") if l.strip() and not l.startswith("#"))}
rgb = lambda h: np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)])
FOCUS, RAIL = rgb(col["focus"]), rgb(col.get("lacquer", col["focus"])[:6])
WIDE = 9                                     # the lacquer: three of the wallpapers' pixels
def runs(a, ink):
    xs = np.flatnonzero(np.abs(a[1050].astype(int) - ink).sum(axis=1) < 8)
    r = []
    for x in xs:
        if r and x == r[-1][0] + r[-1][1]:
            r[-1][1] += 1
        else:
            r.append([int(x), 1])
    return r
def frames(n):
    for f in sorted(glob.glob(f"{out}/{n}/*.png")):
        yield f[-9:-4], np.asarray(Image.open(f).convert("RGB"))
def rails(a):
    return [x for x, w in runs(a, RAIL) if w == WIDE or (w > 1 and (x == 0 or x + w == 1920))]
def hairs(a):
    return [x for x, w in runs(a, FOCUS) if w == 1]
bad, seen = [], {}
# (the clean move: the focused window leaving is 721 wide, on the right; one hairline left of the rail is its right
# one only when the left one has gone past the screen's edge — anything else: the rail is over it)
first = next(frames("clean"))[1]
h0 = hairs(first)
W = h0[1] - h0[0] if len(h0) == 2 else 0
if not W:
    bad.append(f"clean: the focused window not where it should be: {h0}")
n = 0
for name, a in frames("clean"):
    rr = rails(a)
    n += bool(rr)
    if len(rr) > 1:
        bad.append(f"clean {name}: {len(rr)} rails {rr}")
    for r in rr:
        left = [h for h in hairs(a) if h < r]
        if len(left) == 1 and left[0] - W >= 0:
            bad.append(f"clean {name}: the rail at {r} over the window from {left[0]}")
seen["clean"] = n
for part, most in (("back", 1), ("burst", 2)):
    n = 0
    for name, a in frames(part):
        rr = rails(a)
        n += bool(rr)
        if len(rr) > most:
            bad.append(f"{part} {name}: {len(rr)} rails {rr}")
    seen[part] = n
if not all(seen.values()):
    bad.append(f"no rail seen in a move: {seen}")
print("rail: " + ("; ".join(bad[:6]) if bad else f"held — between the two workspaces in every frame, one on a move back, two at most in a burst ({seen})"))
sys.exit(1 if bad else 0)
PY
