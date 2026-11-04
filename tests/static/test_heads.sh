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

case_ "fetch's sixels: 128 × 160, a register an ink, the terminal's own ground through the rest"
for m in dark light; do
  six=$(<"$REPO/configs/home/.local/share/fedokawaii/$m/head.six")
  has "$six" $'\eP0;1;0q"1;1;128;160' "$m: its size"
  has "$six" $'\e\\' "$m: its end"
done
done_
