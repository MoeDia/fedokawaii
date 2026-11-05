#!/usr/bin/env bash
# tools/regress/launcher-calc.sh — never again a launcher that flickers through a sum (bug 6, r27-21-bug6b: "it happens
# when typing in the app launcher calculations or conversions"; once a blank frame at each key, then the row
# running through qalc's readings of half-typed words): "5 ft to cm" typed at a typist's pace, every screen
# change recorded, both themes. What is under the line typed on goes from the apps to at most "none" to
# the one answer, and never back: no blank frame, no answer but the last.
#   bash tools/regress/launcher-calc.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-lcalc.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY_END'
panel; nap 1; at 1900 1070
chord logo space; nap 1.5
wf-recorder -c libx264rgb -p crf=0 -p preset=ultrafast -f "$KIT_OUT/rec.mkv" >/dev/null 2>&1 & r=$!
nap 1
wtype -d 110 -- "5 ft to cm"
nap 1.5
kill -INT "$r"; wait "$r" 2>/dev/null
shot done
PLAY_END
fail=0
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "$@" --time 40 --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "launcher-calc: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  [[ -s $out/$th/rec.mkv ]] || { echo "launcher-calc: nothing recorded" >&2; exit 2; }
  mkdir "$out/$th/fr"
  ffmpeg -v error -i "$out/$th/rec.mkv" -fps_mode passthrough "$out/$th/fr/f%04d.png" >/dev/null 2>&1
  python3 -I - "$out/$th" "$th" "$here/shots.py" <<'PY_END' || fail=1
import glob, importlib.util, os, sys
import numpy as np
from PIL import Image
d, th = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("shots", sys.argv[3]); s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
box = s.popups(os.path.join(d, "done.png"))
if len(box) != 1:
    print(f"launcher-calc ({th}): {len(box)} popups on the last shot")
    sys.exit(1)
x0, y0, x1, y1 = box[0]
# under the line typed on: the heading's row and air, the line, a row of air (§7): 80 px under the frame's top
under = (y0 + 80, y1, x0 + 8, x1 - 8)
fs = sorted(glob.glob(os.path.join(d, "fr", "*.png")))
pics, seq = [], []
for f in fs:
    a = np.asarray(Image.open(f).convert("RGB"), dtype=np.int16)[under[0]:under[1], under[2]:under[3]]
    if a.shape[0] < 20:
        continue
    for i, p in enumerate(pics):
        if np.array_equal(a, p):
            break
    else:
        pics.append(a)
        i = len(pics) - 1
    if not seq or seq[-1] != i:
        seq.append(i)
bad = []
if len(seq) < 2:
    bad.append(f"the list never changed in {len(fs)} frames")
if len(pics) > 3:
    bad.append(f"{len(pics)} different lists in {len(fs)} frames (the apps, none, the answer): a state between")
if len(seq) != len(set(seq)):
    bad.append(f"the list went back: {seq}")
last = pics[seq[-1]] if seq else None
if last is not None and len(np.unique(last.reshape(-1, 3), axis=0)) < 3:
    bad.append("the last list holds no answer")
if bad:
    print("\n".join(f"launcher-calc ({th}): {b}" for b in bad))
sys.exit(1 if bad else 0)
PY_END
done
((fail)) && exit 1
echo "launcher-calc: held — the apps, none, the one answer, never back, no blank frame, both themes"
