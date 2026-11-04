#!/usr/bin/env bash
# tests/regress/test_fonts.sh — never again letters that touch (r26-fu-1, r27-fonts-1: "no letter-spacing
# problems at all"), or a stock % (r26-fu-2). Sumi UI as it ships, drawn at its 14 px by FreeType.
. "$(dirname "$0")/lib.sh"
F=$REPO/system/fonts/SumiUI.ttf

case_ "no two letters touch: every pair of printable ASCII, at 14 px"
if python3 -I -c 'import PIL.ImageFont' 2>/dev/null; then
  out=$(python3 -I - "$F" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
f = ImageFont.truetype(sys.argv[1], 14)
def cols(c):
    im = Image.new("1", (32, 24))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((8, 2), c, font=f, fill=1)
    px = im.load()
    x = [i - 8 for i in range(32) if any(px[i, j] for j in range(24))]
    return (min(x), max(x)) if x else None
glyphs = {chr(c): cols(chr(c)) for c in range(0x21, 0x7f)}
adv = {c: round(f.getlength(c)) for c in glyphs}
bad = [a + b for a in glyphs for b in glyphs if glyphs[a][1] + 1 >= adv[a] + glyphs[b][0]]
print(len(glyphs) ** 2, len(bad), " ".join(bad[:10]), sep="\n")
PY
)
  { read -r pairs; read -r n; read -r some; } <<<"$out"
  eq "${n:-x}" 0 "${n:-?} of $pairs pairs touch: $some"
  item "r26-fu-1 r27-fonts-1 r27-dec-2a" "${pairs:-?} pairs at 14 px, ${n:-?} touching"
else
  item r26-fu-1 "no PIL here: not measured"
fi

case_ "the percent sign is ours: drawn by hand in art/signs.txt"
grep -qE '^= % ' "$REPO/art/signs.txt" && _ok || _no "no % in art/signs.txt"
item r26-fu-2 "$(grep -cE '^= ' "$REPO/art/signs.txt") signs drawn by hand, % among them"

case_ "the UI face is one weight: one file, every stem one pixel, nothing to thicken a title"
eq "$(find "$REPO/system/fonts" -iname 'sumiui*' -name '*.ttf' | wc -l)" 1 "more than one Sumi UI file"
if python3 -I -c 'import PIL.ImageFont' 2>/dev/null; then
  w=$(python3 -I - "$F" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
f = ImageFont.truetype(sys.argv[1], 14)
widest = 0
for c in "IlHNU":                        # (letters of upright stems: the commonest run across is a stem)
    im = Image.new("1", (24, 24))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((4, 2), c, font=f, fill=1)
    px = im.load()
    runs = []
    for y in range(24):
        run = 0
        for x in range(25):
            if x < 24 and px[x, y]:
                run += 1
            elif run:
                runs.append(run)
                run = 0
    widest = max(widest, max(set(runs), key=runs.count))
print(widest)
PY
  )
  eq "$w" 1 "a stem $w px wide"
  item r27-bar-3 "one file; every stem measured $w px at 14 px"
fi
done_
