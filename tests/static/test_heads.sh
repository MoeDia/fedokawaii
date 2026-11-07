#!/usr/bin/env bash
# tests/static/test_heads.sh — the head: the Fedora logo, bloody and lighty (tools/build-head.py, docs/art/heads.md; the
# owner, 6 Nov): each file its size and alpha, whole inks, its states apart; the prompt's glyphs one ink and what the tool
# writes; fetch's sixels read back at whole pixels; nothing left of the old heads.
. "$(dirname "$0")/../lib/harness.sh"
sandbox

case_ "the pictures: size, alpha, ink inside its air, few inks (pixel art), the two states apart, the moods apart"
out=$(python3 -I -B - "$REPO" <<'PY'
import sys
import numpy as np
from PIL import Image
themes = f"{sys.argv[1]}/configs/home/.config/fedokawaii/themes"
for name, size, most in (("face", (22, 20), 12), ("head-48", (48, 48), 12)):
    shut = {}
    for mood in ("dark", "light"):
        states = []
        for suffix in ("", "-open"):
            n = f"{mood}/{name}{suffix}.png"
            im = Image.open(f"{themes}/{n}")
            if im.mode != "RGBA" or im.size != size:
                print("SIZE", n, im.mode, im.size); continue
            a = np.asarray(im)
            states.append(a)
            rows = np.nonzero(a[..., 3].max(1))[0]
            if name == "face" and (rows[0] < 1 or rows[-1] > 18):
                print("AIR", n, rows[0], rows[-1])
            if set(np.unique(a[..., 3])) != {0, 255}:
                print("ALPHA", n)
            if len({tuple(p) for p in a.reshape(-1, 4)}) > most:
                print("INKS", n)
        if len(states) == 2 and (states[0] == states[1]).all():
            print("SAME", mood, name)
        shut[mood] = states[0]
    if (shut["dark"] == shut["light"]).all():
        print("MOODS", name)
print("pictures done")
PY
)
eq "$out" "pictures done"

case_ "the prompt's glyphs: one ink, 24 × 20, a row of air above and below, its states apart, in the fonts' source as the tool writes them"
G=$TMP/gen; mkdir -p "$G"; cp -r "$REPO"/{tools,art} "$G/"
out=$(cd "$G" && python3 -I -B - <<'PY'
import importlib.util
sp = importlib.util.spec_from_file_location("bh", "tools/build-head.py")
bh = importlib.util.module_from_spec(sp); sp.loader.exec_module(bh)
rows = {name: bh.glyph(*how) for name, how in bh.GLYPHS.items()}
for name, r in rows.items():
    if len(r) != 20 or {len(x) for x in r} != {24} or set("".join(r)) - set(".#"):
        print("SHAPE", name)
    ink = [y for y, x in enumerate(r) if "#" in x]
    if ink[0] < 1 or ink[-1] > 18:
        print("AIR", name, ink[0], ink[-1])
for a, b in (("head-bloody", "head-bloody-run"), ("head-lighty", "head-lighty-open")):
    if rows[a] == rows[b]:
        print("SAME", a)
bh.write_glyphs()
print("glyphs done")
PY
)
eq "$out" "glyphs done"
d=$(diff -q "$REPO/art/icons.txt" "$G/art/icons.txt" 2>&1)
[[ -z $d ]] && _ok || _no "$d"

case_ "fetch's sixels: 288 × 300, as the tool makes them, in blocks of 6 × 6; fetch's room for them"
out=$(python3 -I -B - "$REPO" <<'PY'
import importlib.util, pathlib, sys
repo = pathlib.Path(sys.argv[1])
sp = importlib.util.spec_from_file_location("bh", repo / "tools/build-head.py")
bh = importlib.util.module_from_spec(sp); sp.loader.exec_module(bh)
for mood in ("dark", "light"):
    six = (repo / f"configs/home/.local/share/fedokawaii/{mood}/head.six").read_text(encoding="ascii")
    im = bh.fetch_picture(mood)
    print(mood, im.size, six == bh.sixel(im), six.startswith('\x1bP0;1;0q"1;1;288;300'))
PY
)
eq "$out" "$(printf '%s\n' 'dark (288, 300) True True' 'light (288, 300) True True')"
eq "$(sed -n 's/^HEAD_CELLS=\([0-9]*\) HEAD_LINES=\([0-9]*\) FACTS_AT=\([0-9]*\).*/\1 \2 \3/p' "$REPO/bin/fetch")" "36 15 42" "bin/fetch: 36 × 8 = 288, 15 × 20 = 300, the facts at 2 + 36 + 3 + 1"

case_ "no old head on the head's surfaces"
for f in bin/kawa-bar bin/fetch bin/kawa-theme configs/home/.bashrc.d/fedokawaii.sh configs/home/.config/waybar/config.jsonc configs/home/.config/fedokawaii/icons.sh art/icons.txt \
         configs/home/.local/lib/fedokawaii/kawa-chess/syllabus.py configs/home/.local/lib/fedokawaii/kawa-chess/home.py \
         configs/home/.local/lib/fedokawaii/kawa-chess/play.py configs/home/.local/share/fedokawaii/chess/faces.txt \
         docs/learn/chess/README.md docs/lessons/seals.txt; do
  out=$(grep -n -i -E 'demon|angel|\boni\b|tennin|HEAD_ONI|ICON_ONI' "$REPO/$f" | grep -v -E 'head-(oni|angel)' || true)
  eq "$out" "" "$f"
done
done_
