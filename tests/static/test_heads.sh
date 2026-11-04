#!/usr/bin/env bash
# tests/static/test_heads.sh — the two heads, one character sheet (tools/build-heads.py, art/heads.txt,
# docs/art/heads.md): every size and state there, symmetric to the pixel, its air where the design
# wants it, its inks counted — and everything made from the sheet is what the sheet makes.
. "$(dirname "$0")/../lib/harness.sh"
sandbox

case_ "the sheet: every size and state of both heads, the ink inside its air, few inks"
out=$(python3 -I -B - "$REPO" <<'PY'
import importlib.util, sys
repo = sys.argv[1]
sp = importlib.util.spec_from_file_location("bh", f"{repo}/tools/build-heads.py")
bh = importlib.util.module_from_spec(sp); sp.loader.exec_module(bh)
s = bh.sheet()
AIR = {"prompt": (1, 18), "bar": (2, 17)}   # the rows the ink may take
INKS = {"prompt": 1, "bar": 3, "32": 4, "56": 4}
for kind, states in (("oni", ("un", "a")), ("kannon", ("closed", "open"))):
    for size, (w, h) in (("prompt", (24, 20)), ("bar", (22, 20)), ("32", (32, 32)), ("56", (56, 56))):
        for st in states:
            n = f"{kind}.{size}.{st}"
            if n not in s:
                print("MISSING", n); continue
            ww, hh, rows = s[n]
            if (ww, hh) != (w, h):
                print("SIZE", n, ww, hh)
            used = sorted({c for r in rows for c in r} - {"."})
            if len(used) > INKS[size]:
                print("INKS", n, used)
            ink = [y for y, r in enumerate(rows) if set(r) - {"."}]
            if size in AIR and (ink[0] < AIR[size][0] or ink[-1] > AIR[size][1]):
                print("AIR", n, ink[0], ink[-1])
            if any(r != r[::-1] for r in rows):
                print("MIRROR", n)
print("sheet done")
PY
)
eq "$out" "sheet done"

case_ "what the sheet makes: the prompt's glyphs, the bar's and the panel's pictures, fetch's sixels, byte for byte; the glyphs in the fonts' source"
G=$TMP/gen; mkdir -p "$G"; cp -r "$REPO"/{tools,art,configs} "$G/"
(cd "$G" && python3 -I -B tools/build-heads.py) >"$TMP/log" 2>&1 && _ok || _no "it failed: $(tail -n 3 "$TMP/log" | tr '\n' ' ')"
d=$(diff -rq "$REPO/configs" "$G/configs" 2>&1; diff -q "$REPO/art/icons.txt" "$G/art/icons.txt" 2>&1)
[[ -z $d ]] && _ok || _no "$d"

case_ "fetch's sixels: 128 × 160, read back pixel for pixel: the drawing, the terminal's own ground through the rest"
out=$(python3 -I -B - "$REPO" <<'PY'
import importlib.util, re, sys
from PIL import Image
repo = sys.argv[1]
sp = importlib.util.spec_from_file_location("bh", f"{repo}/tools/build-heads.py")
bh = importlib.util.module_from_spec(sp); sp.loader.exec_module(bh)
for mood, kind, st in (("dark", "oni", "un"), ("light", "kannon", "closed")):
    six = open(f"{repo}/configs/home/.local/share/fedokawaii/{mood}/head.six", encoding="ascii").read()
    m = re.fullmatch(r'\x1bP0;1;0q"1;1;(\d+);(\d+)(.*)\x1b\\', six, re.S)
    w, h = int(m[1]), int(m[2])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    regs, x, y, reg = {}, 0, 0, 0
    for tok in re.finditer(r"#(\d+);2;(\d+);(\d+);(\d+)|#(\d+)|!(\d+)(.)|(\$)|(-)|([?-~])", m[3]):
        if tok[1]:
            regs[int(tok[1])] = tuple(round(int(tok[i]) * 255 / 100) for i in (2, 3, 4))
        elif tok[5]:
            reg = int(tok[5])
        elif tok[8]:
            x = 0
        elif tok[9]:
            x, y = 0, y + 6
        else:
            n, ch = (int(tok[6]), tok[7]) if tok[6] else (1, tok[10])
            bits = ord(ch) - 63
            for dx in range(n):
                for k in range(6):
                    if bits >> k & 1:
                        im.putpixel((x + dx, y + k), (*regs[reg], 255))
            x += n
    want = bh.fetch_size(kind, st)
    same = (w, h) == want.size and all(
        (im.getpixel((px, py))[3] == 255) == (want.getpixel((px, py))[3] == 255)
        and (not im.getpixel((px, py))[3] or all(abs(a - b) <= 2 for a, b in zip(im.getpixel((px, py)), want.getpixel((px, py)))))
        for py in range(h) for px in range(w))
    print(mood, w, h, same)
PY
)
eq "$out" "$(printf '%s\n' 'dark 128 160 True' 'light 128 160 True')"
done_
