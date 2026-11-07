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
for name, size, most in (("head-32", (32, 30), 12), ("head-48", (48, 48), 12)):
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
            if name == "head-32" and (rows[0] < 1 or rows[-1] > 28):   # (a row of paper before each hairline)
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
         docs/learn/chess/README.md docs/lessons/seals.txt docs/learn/typing/README.md docs/learn/pieces/011-the-bar.md \
         configs/home/.local/lib/fedokawaii/kawatype/art.py configs/home/.local/lib/fedokawaii/kawatype/hands.txt tools/build-typing-art.py \
         system/plymouth/sumi/sumi.script system/plymouth/sumi/sumi.plymouth tools/build-art.py tools/build-iso-art.py iso/screens/console.py; do
  out=$(grep -n -i -E 'demon|angel|\boni\b|tennin|HEAD_ONI|ICON_ONI' "$REPO/$f" | grep -v -E 'head-(oni|angel)' || true)
  eq "$out" "" "$f"
done
done_

case_ "no demon or angel outside the wallpapers (his note d, 6 Nov; dn01): no word for one in what ships, no file named for one"
# the wallpapers keep theirs: their list, the masters' pictures and sources; the typing app's English word lists are words.
# PENDING: the old lock's family, which d1d replaces (with sa31's lock): once a file is clean, its line goes.
PENDING=(bin/kawa-lock configs/home/.config/fedokawaii/lock.ui src/kawa-lockmod/kawa-lockmod.c system/kawa-greet art/heads.txt art/ink/SOURCES.md)
WORDS='\b(oni|onis|angels?|demons?|tennin|hannya|marishiten|akuma|tenshi)\b'
mapfile -t files < <(cd "$REPO" && git ls-files bin configs system iso src lib art theme.sh setup.sh fedokawaii.sh verify.sh \
  | grep -v -E '^art/masters/|^configs/home/\.local/share/fedokawaii/wallpapers\.list$|/kawatype/(words|sentences|passages)\.txt$')
out=$(cd "$REPO" && grep -l -I -i -E "$WORDS" "${files[@]}" | grep -v -x -F -f <(printf '%s\n' "${PENDING[@]}") || true)
eq "$out" "" "files that name a demon or angel"
for f in "${PENDING[@]}"; do
  grep -q -I -i -E "$WORDS" "$REPO/$f" && _ok || _no "$f is clean now: take it off PENDING"
done
out=$(cd "$REPO" && git ls-files | grep -v '^art/masters/' | grep -i -E '(^|[/_.-])(oni|angels?|demons?|tennin|hannya|marishiten)([/_.-]|$)' || true)
eq "$out" "" "files named for a demon or angel"
done_

case_ "the boot splash and the ISO's crest are the head's own pixels, whole ×8 and ×5, and the splash's old painting is gone"
[[ ! -e $REPO/system/plymouth/sumi/mask.png ]] && _ok || _no "mask.png is back"
out=$(cd "$REPO" && python3 -I -B - <<'PY'
import importlib.util
from PIL import Image
spec = importlib.util.spec_from_file_location("bh", "tools/build-head.py")
bh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bh)
for name, state in (("head", "shut"), ("head-open", "open")):
    im = Image.open(f"system/plymouth/sumi/{name}.png").convert("RGBA")
    want = bh.picture("dark", 40, state, 48, 50)
    print(name, im.size, im.tobytes() == want.resize((384, 400), Image.NEAREST).tobytes())
PY
)
eq "$out" "$(printf '%s\n' 'head (384, 400) True' 'head-open (384, 400) True')"
tmp=$(mktemp -d)
python3 -I -B "$REPO/tools/build-iso-art.py" --console "$tmp" >/dev/null
out=$(python3 -I -B - "$tmp/console/glyphs.py" <<'PY'
import runpy, sys
g = runpy.run_path(sys.argv[1])
print(g["CREST_COLS"], g["CREST_ROWS"], len(g["G"]["crest"]))
PY
)
eq "$out" "21 9 189" "the crest's tiles fill its 21 × 9"
rm -rf "$tmp"
grep -q 'lock-map-shiro.png' "$REPO/tools/build-iso.sh" && ! grep -q 'lock-scene' "$REPO/tools/build-iso.sh" && _ok || _no "tools/build-iso.sh still takes the lock's painting"
done_
