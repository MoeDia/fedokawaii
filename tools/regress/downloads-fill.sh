#!/usr/bin/env bash
# tools/regress/downloads-fill.sh — never again a download's progress that does not show (the owner's
# report: no percent; his 1 Nov note: the bar drawn inside the icon, perfectly in place): the real bar in
# a headless kit, a job of each percent, its tray measured to the pixel in both moods: one pixel a step
# (5 %), asagi to the 16th, flame to the 18th, the accent to the 20th, all inside the tray's rows.
#   bash tools/regress/downloads-fill.sh [KIT OPTION…]   (e.g. --bin bin --repo-art)
# Exit 0 held · 1 the fill is wrong (each said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-fill.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
# (the arrow moves over the tray: six shots a level, 8 frames a second — the fullest is the fill)
cp "$HOME/.config/fedokawaii/current/colors.sh" "$KIT_OUT/colors.sh"
kawa-downloads watch >/dev/null 2>&1 &          # (it wakes the bar's mark, asleep while nothing comes in)
sleep 600 & J=$!
d=$XDG_RUNTIME_DIR/kawa-downloads; mkdir -p "$d"
for p in 4 5 25 50 62 80 85 90 95 99 100; do
  printf 'a.iso\t%s\t100\t/tmp/a.iso\n' "$p" >"$d/pack.$J.t"; mv "$d/pack.$J.t" "$d/pack.$J"
  nap 2.6
  for s in 0 1 2 3 4 5 6 7; do shot "p$p-$s" 1500,0 260x27; nap 0.07; done
done
kill $J
PLAY
rc=0
for m in dark light; do
  mkdir -p "$out/$m"
  # (--repo-art takes the repository's themes, colours among them: the flame's)
  bash "$here/../kit.sh" --theme "$m" "$@" --out "$out/$m" --play "$out/play.sh" --time 200 play >"$out/kit.log" 2>&1 \
    || { echo "downloads-fill: the kit did not run ($m): $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
  python3 -I - "$out/$m" "$m" <<'MEASURE' || rc=1
import glob, os, re, sys
from PIL import Image
d, mood = sys.argv[1:3]
c = {k: v.split()[0].strip('"') for k, v in (l.split("=", 1) for l in open(f"{d}/colors.sh") if l.startswith("C_") and "=" in l) if v.split()}
rgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
teal, flame, accent = rgb(c["C_TEAL"]), rgb(c["C_FLAME"]), rgb(c["C_ACCENT"])
bad = 0
for p in (4, 5, 25, 50, 62, 80, 85, 90, 95, 99, 100):
    n = min(20, p // 5)
    want = [min(n, 16), max(0, min(n, 18) - 16), max(0, n - 18)]
    if flame == accent:                                 # (the light mood: one brick red for both)
        want = [want[0], want[1] + want[2], 0]
    want = tuple(want)
    best, where = (0, 0, 0), set()
    for f in glob.glob(f"{d}/p{p}-*.png"):
        im = Image.open(f).convert("RGB"); px = im.load()
        got = [0, 0, 0]; at = set()
        for y in range(im.height):
            for x in range(im.width):
                v = px[x, y]
                if v in (teal, flame, accent):
                    got[(teal, flame, accent).index(v)] += 1; at.add(y)
        if sum(got) > sum(best): best, where = tuple(got), at
    # (the rows it lies in: two, side by side, once a column has its top)
    rows = sorted(where)
    ok = best == want and (not rows or rows[-1] - rows[0] <= 1)
    print(f"  {mood} {p:3d}%: {n:2d} steps, asagi·flame·accent {best[0]}·{best[1]}·{best[2]} (want {want[0]}·{want[1]}·{want[2]}), rows {rows}{'' if ok else '   ✘'}")
    bad += not ok
sys.exit(1 if bad else 0)
MEASURE
done
((rc == 0)) && echo "downloads-fill: held — one pixel a step, in a meter's inks, in the tray, both moods" || echo "downloads-fill: the fill is wrong (above)"
exit "$rc"
