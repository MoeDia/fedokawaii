#!/usr/bin/env bash
# tests/static/test_heads.sh — the two heads, cut in ink at every size (tools/ink_heads.py, docs/art/heads.md; the
# owner, 4 Nov 19:12: no pixel art for the heads): each file its size and alpha, smooth, its ink inside its air, its
# states apart; the prompt's glyphs one ink and what the tool holds; fetch's sixels read back, the room fetch makes.
. "$(dirname "$0")/../lib/harness.sh"
sandbox

case_ "the pictures: size, alpha, ink inside its air, smooth (never pixel art), the two states apart"
out=$(python3 -I -B - "$REPO" <<'PY'
import sys
import numpy as np
from PIL import Image
themes = f"{sys.argv[1]}/configs/home/.config/fedokawaii/themes"
for mood in ("dark", "light"):
    for name, size, floor in (("face", (22, 20), 40), ("head-48", (48, 48), 150), ("head-56", (56, 56), 200)):
        states = []
        for suffix in ("", "-open"):
            n = f"{mood}/{name}{suffix}.png"
            im = Image.open(f"{themes}/{n}")
            if im.mode != "RGBA" or im.size != size:
                print("SIZE", n, im.mode, im.size); continue
            a = np.asarray(im)
            states.append(a)
            rows = np.nonzero(a[..., 3].max(1) > 32)[0]
            if name == "face" and (rows[0] < 1 or rows[-1] > 18):
                print("AIR", n, rows[0], rows[-1])
            inks = len({tuple(p) for p in a.reshape(-1, 4)})
            if inks < floor:
                print("FLAT", n, inks)
            if not (a[..., 3] == 0).any() or not (a[..., 3] == 255).any():
                print("ALPHA", n)
        if len(states) == 2 and (states[0] == states[1]).all():
            print("SAME", mood, name)
print("pictures done")
PY
)
eq "$out" "pictures done"

case_ "the prompt's glyphs: one ink, 24 × 20, a row of air above and below, the demon symmetric, in the fonts' source as the tool holds them"
G=$TMP/gen; mkdir -p "$G"; cp -r "$REPO"/{tools,art} "$G/"
out=$(cd "$G" && python3 -I -B - <<'PY'
import importlib.util, pathlib
sp = importlib.util.spec_from_file_location("ih", "tools/ink_heads.py")
ih = importlib.util.module_from_spec(sp); sp.loader.exec_module(ih)
for name, rows in ih.GLYPHS.items():
    if len(rows) != 20 or {len(r) for r in rows} != {24} or set("".join(rows)) - set(".#"):
        print("SHAPE", name)
    ink = [y for y, r in enumerate(rows) if "#" in r]
    if ink[0] < 1 or ink[-1] > 18:
        print("AIR", name, ink[0], ink[-1])
    if "oni" in name and any(r != r[::-1] for r in rows):
        print("MIRROR", name)
for a, b in (("head-oni", "head-oni-roar"), ("head-angel", "head-angel-open")):
    if ih.GLYPHS[a] == ih.GLYPHS[b]:
        print("SAME", a)
ih.write_glyphs()
print("glyphs done")
PY
)
eq "$out" "glyphs done"
d=$(diff -q "$REPO/art/icons.txt" "$G/art/icons.txt" 2>&1)
[[ -z $d ]] && _ok || _no "$d"

case_ "fetch's sixels: 288 × 300, read back: few inks, the figure opaque, the terminal's own ground through the rest, the angel's gold kept; fetch's room for them"
out=$(python3 -I -B - "$REPO" <<'PY'
import importlib.util, pathlib, sys
import numpy as np
repo = pathlib.Path(sys.argv[1])
sp = importlib.util.spec_from_file_location("ih", repo / "tools/ink_heads.py")
ih = importlib.util.module_from_spec(sp); sp.loader.exec_module(ih)
for mood in ("dark", "light"):
    im = ih.portrait_of(repo / f"configs/home/.local/share/fedokawaii/{mood}/head.six")
    a = np.asarray(im)
    inks = {tuple(p[:3]) for p in a.reshape(-1, 4) if p[3]}
    warm = any(int(r) - int(b) > 60 for r, g, b in inks)
    print(mood, im.size, len(inks) <= 32, 0.2 < (a[..., 3] > 0).mean() < 0.95, warm == (mood == "light"))
PY
)
eq "$out" "$(printf '%s\n' 'dark (288, 300) True True True' 'light (288, 300) True True True')"
eq "$(sed -n 's/^HEAD_CELLS=\([0-9]*\) HEAD_LINES=\([0-9]*\) FACTS_AT=\([0-9]*\).*/\1 \2 \3/p' "$REPO/bin/fetch")" "36 15 42" "bin/fetch: 36 × 8 = 288, 15 × 20 = 300, the facts at 2 + 36 + 3 + 1"
done_
