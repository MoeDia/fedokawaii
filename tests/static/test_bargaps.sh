#!/usr/bin/env bash
# tests/static/test_bargaps.sh — the bar's spacing, worked out from the drawings and the style,
# to the pixel (the numbers style.css's header promises, and the bar measures on screen):
#   · an icon before a value (icons.sh's ICON_BAR_*): its ink from the module's edge (no air
#     before it), exactly 8 px from its ink to the value's, whatever the icon's own air
#   · every module with an icon and a value draws it with ICON_BAR_*, never "icon value"
#   · no module holds a fixed width (which would put cloth after the value)
#   · the tiles (紙 kami): each a border-image of its theme's picture (kami-tile, kami-red at
#     the two ends, kami-scroll round the clock) sliced as drawn — §4's frame on 27 rows: air
#     0–2, the hairline on 3 and 24 (corners left out), the paper 4–23, the shadow 25–26 — the
#     14 px line on the paper's rows 3–16
#   · 8 px from the paper's edge to the ink both sides inside a tile (each glyph's air
#     counted); 4 px hairline to hairline within a group, 12 between groups, the outer
#     hairlines on x 8 and x 1911
#   · the layout's mark and the window's name one tile; the stamp's seal centred on its
#     numeral; the clock's parts in one scroll, 14 px of air apart
# (tools/regress/bar-geometry.sh measures the same on a real bar, headless.)
. "$(dirname "$0")/../lib/harness.sh"

case_ "ICON_BAR_*: each icon's ink from the pen, 8 px from it to the value's"
out=$(python3 -I - "$REPO" 2>&1 <<'EOF'
import re, sys
root = sys.argv[1]
src = open(root + "/tools/build-icons.py").read().split("if __name__")[0]
g = {"__name__": "bi", "__file__": root + "/tools/build-icons.py"}
exec(compile(src, "build-icons", "exec"), g)
icons = g["twins"](g["parse"](open(root + "/art/icons.txt").read()))
by_cp = {g["FIRST"] + i: ic for i, ic in enumerate(icons)}
bad, n = [], 0
for line in open(root + "/configs/home/.config/fedokawaii/icons.sh"):
    m = re.match(r"ICON_BAR_(\w+)=\$'(.*)'$", line.strip())
    if not m:
        continue
    n += 1
    text = bytes(int(h, 16) for h in m.group(2).split("\\x")[1:]).decode()
    x, ink, first = 0, None, None
    for ch in text:
        ic = by_cp[ord(ch)]
        cols = [i for r in ic["rows"] for i, c in enumerate(r) if c == "#"]
        if cols:
            ink = (x + ic["x"] + min(cols), x + ic["x"] + max(cols))
            first = ink[0] if first is None else first
        x += ic["adv"]
    name = m.group(1).lower()
    if first != 0:
        bad.append(f"{name}: its ink starts {first} px from the pen")
    if x - ink[1] - 1 != g["BAR_GAP"] or g["BAR_GAP"] != 8:
        bad.append(f"{name}: {x - ink[1] - 1} px to the value")
if n < 40:
    bad.append(f"only {n} ICON_BAR_* found")
print("\n".join(bad))
EOF
)
[[ -z $out ]] && _ok || _no "$out"

case_ "the modules draw an icon before a value with ICON_BAR_* (no space between)"
bad=$(grep -nE '\$ICON_(VOL_[0-4]|VOL_MUTE|BRI_[0-4]|MEMORY|USB|HOURGLASS)\b[^"]* (\$|%|<span)|"%s %s<span|"%s %d' \
  "$REPO/bin/kawa-volume" "$REPO/bin/kawa-brightness" "$REPO/bin/kawa-mem" "$REPO/bin/kawa-drives" "$REPO/bin/kawa-timer" \
  | grep -vE ':[0-9]+:\s*#|notify-send|line (row|on)')
[[ -z $bad ]] && _ok || _no "$bad"
for f in kawa-volume kawa-brightness kawa-mem kawa-drives kawa-timer kawa-weather; do
  grep -q 'ICON_BAR_' "$REPO/bin/$f" || _no "$f draws no ICON_BAR_"
done
grep -q 'ic[f"bar_dl_{frame}"]' "$REPO/bin/kawa-downloads" && _ok || _no "kawa-downloads draws its icon with a space"

CSS=$REPO/configs/home/.config/waybar/style.css
case_ "no module of the bar holds a fixed width"
bad=$(grep -nE 'min-width: *[0-9]+px' "$CSS" | grep -vE 'min-width: *(0|1)px')
[[ -z $bad ]] && _ok || _no "$bad"

case_ "the tiles, from the style and the drawings: 27 rows (the frame of §4), 8 px paper to ink, 4 / 12 px hairline to hairline, the outer hairlines on x 8 and x 1911, the stamp's numeral inside its seal, the clock's parts 14 px apart"
out=$(python3 -I - "$REPO" 2>&1 <<'EOF'
import re, sys
from PIL import Image, ImageFont, ImageDraw
root = sys.argv[1]
css = re.sub(r"/\*.*?\*/", "", open(root + "/configs/home/.config/waybar/style.css").read(), flags=re.S)
rules = []
for sel, body in re.findall(r"([^{}]+)\{([^}]*)\}", css):
    props = dict((k.strip(), v.strip()) for k, v in (p.split(":", 1) for p in body.split(";") if ":" in p))
    rules.append(([x.strip() for x in sel.split(",")], props))
def px(v): return int(v.strip().rstrip("px"))
def four(v):
    n = [px(x) for x in v.split()]
    return n * 4 if len(n) == 1 else n * 2 if len(n) == 2 else n + [n[1]] if len(n) == 3 else n
def matches(sel, x):
    want = set(re.findall(r"[#.][\w-]+", sel))
    if any(w.startswith("#custom-tag") for w in want): want.add(".tag")
    have = re.findall(r"[#.][\w-]+", x)
    return bool(have) and ":" not in x and set(have) <= want
def box(sel):
    """padding, margin, border-width (top right bottom left) and the rest of one element"""
    b = {"padding": [0] * 4, "margin": [0] * 4, "border-width": [0] * 4}
    other = {}
    for sels, p in rules:
        if not any(matches(sel, x) for x in sels): continue
        for k, v in p.items():
            if k in b: b[k] = four(v)
            elif re.match(r"(padding|margin)-(top|right|bottom|left)$|border-(top|right|bottom|left)-width$", k):
                kind = "border-width" if k.startswith("border") else k.split("-")[0]
                side = next(s_ for s_ in ("top", "right", "bottom", "left") if s_ in k)
                b[kind][("top", "right", "bottom", "left").index(side)] = px(v)
            else: other[k] = v
    return b["padding"], b["margin"], b["border-width"], other
bad = []
def want(what, got, n):
    if got != n: bad.append(f"{what}: {got}, not {n}")
src = open(root + "/tools/build-icons.py").read().split("if __name__")[0]
g = {"__name__": "bi", "__file__": root + "/tools/build-icons.py"}
exec(compile(src, "build-icons", "exec"), g)
ic = {i["name"]: i for i in g["parse"](open(root + "/art/icons.txt").read())}
IL = lambda n: g["left_air"](ic[n]); IR = lambda n: g["right_air"](ic[n])
SUMI = ImageFont.truetype(root + "/system/fonts/SumiUI.ttf", 14)
def air(ch):
    im = Image.new("L", (48, 24)); ImageDraw.Draw(im).text((8, 0), ch, font=SUMI, fill=255)
    xs = [x for x in range(48) for y in range(24) if im.getpixel((x, y)) > 128]
    return min(xs) - 8, int(SUMI.getlength(ch)) - (max(xs) - 8) - 1
T = root + "/configs/home/.config/fedokawaii/themes/"
cfg = re.sub(r"^\s*//.*$", "", open(root + "/configs/home/.config/waybar/config.jsonc").read(), flags=re.M)
height = int(re.search(r'"height":\s*(\d+)', cfg).group(1)); want("the bar's height", height, 27)
want("its margin under it (the exclusive zone ends on the lower hairline)", int(re.search(r'"margin-bottom":\s*(-?\d+)', cfg).group(1)), -2)
# the pictures (§4's frame): air on rows 0–2, the hairline on 3 and 24 (its corners left out),
# the paper 4–23, the shadow 25–26 a pixel further right each, a column at the right from row 5
for th in ("dark", "light"):
    for n in ("kami-tile.png", "kami-red.png", "kami-red-lit.png"):
        im = Image.open(T + th + "/" + n).convert("RGBA"); a = lambda x, y: im.getpixel((x, y)); w = im.size[0]
        want(f"{th}/{n}: its height", im.size[1], height)
        hair = a(0, 10)
        if any(a(x, y)[3] for x in range(w) for y in (0, 1, 2)): bad.append(f"{th}/{n}: ink above the hairline")
        if not (a(1, 3) == hair == a(w - 3, 3) == a(1, 24) == a(w - 2, 10) and not a(0, 3)[3] and not a(w - 2, 3)[3] and not a(0, 24)[3]):
            bad.append(f"{th}/{n}: the hairline not on rows 3 and 24, columns 0 and {w - 2}, its corners left out")
        fill = a(1, 4)
        if not all(a(x, y) == fill for x in range(1, w - 2) for y in range(4, 24)): bad.append(f"{th}/{n}: more than one fill inside the hairline (a second frame)")
        s1, s2 = a(1, 25), a(2, 26)
        if not (s1[3] and s2[3] and not a(1, 26)[3] and a(w - 2, 25) == s1 and not a(w - 1, 25)[3] and a(w - 1, 26) == s2
                and a(w - 1, 5) == s2 and not a(w - 1, 4)[3]):
            bad.append(f"{th}/{n}: not §4's shadow (two rows, the second a pixel further right; the column from the hairline's second row)")
    seal = Image.open(T + th + "/kami-seal.png").convert("RGBA")
    want(f"{th}/kami-seal.png: its size", seal.size, (16, 16))
    for old in ("kami-seal-narrow.png", "washi.png", "hems.png", "seam.png", "cell-bare-36.png", "clock.png", "stitch.png", "hem.png"):
        if __import__("os").path.exists(T + th + "/" + old): bad.append(f"{th}/{old}: still there")
    sc = Image.open(T + th + "/kami-scroll.png").convert("RGBA")
    want(f"{th}/kami-scroll.png: its height", sc.size[1], height)
tiles = ["#custom-torii", "#custom-menu", "#focused"] + [f"#custom-tag{k}" for k in range(1, 10)] + \
        ["#custom-nowplaying", "#custom-timer", "#custom-record", "#custom-mode", "#custom-drives", "#custom-downloads",
         "#custom-kb", "#custom-mem", "#custom-volume", "#custom-brightness", "#custom-weather"]
for sel in tiles:
    p_, m_, b_, o = box(sel)
    kind = "kami-red.png" if sel in ("#custom-torii", "#custom-menu") else "kami-tile.png"
    bi = o.get("border-image", "")
    if kind not in bi or not bi.split(")")[1].strip().startswith("4 2 3 2"): bad.append(f"{sel}: border-image {bi}")
    want(f"{sel}: its border (the picture's slices)", b_, [4, 2, 3, 2])
    inner = sel == "#focused"
    if not inner: want(f"{sel}: the 14 px line on the paper's rows 3–16", (p_[0], p_[2]), (3, 3))
for sel in ("#custom-layout", "#custom-title"):
    want(f"{sel} (inside one tile): its line", (box(sel)[0][0], box(sel)[0][2]), (3, 3))
    want(f"{sel} (inside one tile): no frame of its own", box(sel)[2], [0, 0, 0, 0])
# 8 px from the paper's edge to the ink: the paper's first column is in the picture (the left
# slice: the hairline and one column), so the padding is 7 less the first glyph's air; on the
# right the padding is 8 less the last glyph's air (the right slice: the hairline, the shadow)
L = lambda s, ink: 1 + box(s)[0][3] + ink
R = lambda s, ink: ink + box(s)[0][1]
for sel, l, r in (("#custom-torii", IL("torii"), IR("torii")), ("#custom-menu", IL("cat"), IR("cat")),
                  ("#custom-tag1", IL("ws-1"), IR("ws-1")), ("#custom-tag4", IL("ws-4"), IR("ws-4")),
                  ("#custom-volume", 0, air("%")[1]), ("#custom-mem", 0, air("G")[1]), ("#custom-weather", 0, air("°")[1]),
                  ("#custom-kb", air("U")[0], air("S")[1]), ("#custom-timer", 0, air("5")[1]), ("#custom-mode", 0, 0)):
    want(f"{sel}: the paper → its ink", L(sel, l), 8)
    want(f"{sel}: its ink → the paper", R(sel, r), 8)
# the layout's mark and the window's name in one tile: the mark 8 from the paper, the name 8
# after the mark (less its first letter's air: the classes l1–l3), 8 to the paper's end
want("#custom-layout: the paper → the mark", 1 + box("#custom-layout")[0][3] + IL("spiral"), 8)
want("#custom-layout.alone: the mark → the paper", IR("spiral") + box("#custom-layout.alone")[0][1], 8)
want("the mark → the name", IR("spiral") + box("#custom-layout")[0][1] + box("#custom-title")[0][3], 8)
for n in (1, 2, 3):
    want(f"#custom-title.l{n}: the mark → its ink", IR("spiral") + box("#custom-layout")[0][1] + box(f"#custom-title.l{n}")[0][3] + n, 8)
    want(f"#custom-title.r{n}: its ink → the paper", n + box(f"#custom-title.r{n}")[0][1], 8)
# the stamp: its seal 16 px laid 4 2 into the padding box — centred on the numeral's 10 × 10
# (the numeral 8 px into the paper: the padding box starts one column in), two rows of paper
# above and below it
p_ = box("#custom-tag1")[0]
sp = box(".tag.selected")[3].get("background-position", "").split(",")[0].split()
sx, sy = px(sp[0]), px(sp[1])
want("the seal across: centred on the numeral", (1 + sx) + 8, 1 + p_[3] + 5)
want("the seal down: rows 6–21 (2 of paper above it)", 4 + sy, 6)
# hairline to hairline: a tile's box ends with the shadow's column, so the margin is the gap less 1
gap = lambda s: 1 + box(s)[1][3]
for sel in [f"#custom-tag{k}" for k in range(2, 10)] + ["#custom-timer", "#custom-volume", "#custom-weather"]:
    want(f"→ {sel} (within a group)", gap(sel), 4)
for sel in ("#custom-tag1", "#focused", "#custom-menu"):
    want(f"→ {sel} (between groups)", gap(sel), 12)
want("the screen's left edge → the torii's hairline (x 8)", box("#custom-torii")[1][3], 8)
want("the cat's hairline → the screen's right edge (x 1911: 8 px of air, the shadow's column in them)", 1 + box("#custom-menu")[1][1], 8)
# the clock: the scroll sliced 4 4 3 6 (the rod; the rod and two columns of paper); 8 px from
# the rods to the ink; 14 px of air between its parts, each letter's own air counted
o = box("#when")[3]
if "kami-scroll.png" not in o.get("border-image", "") or "4 4 3 6" not in o.get("border-image", ""): bad.append(f"#when: {o.get('border-image')}")
want("#when's border", box("#when")[2], [4, 4, 3, 6])
want("the left rod → the date's ink: 8, and the 7 the time is longer", 2 + box("#when")[0][3] + box("#custom-date")[0][3] + air("2")[0], 15)
want("the time's ink → the right rod", air("M")[1] + box("#custom-time")[0][1] + box("#when")[0][1], 8)
want("the time 7 px longer than the date (11 figures and letters, 10)", (len("09:14:08 PM") - len("27∕10∕2026")) * 7, 7)
# each day's kanji: 14 px to the date and to the time (its own air taken back by its class)
for k, cls in (("火", ""), ("水", ""), ("木", ""), ("金", ""), ("土", ""), ("月", ".mon"), ("日", ".sun")):
    d = box("#custom-day" + cls); al, ar = air(k)
    want(f"the date → {k}", air("6")[1] + box("#custom-date")[0][1] + d[1][3] + d[0][3] + al, 14)
    want(f"{k} → the time", ar + d[0][1] + box("#custom-time")[0][3] + air("0")[0], 14)
t1 = box("#custom-time.l1")
want("{kanji} → the time from 10 to 12 o'clock (its 1's air)", air("火")[1] + box("#custom-day")[0][1] + t1[1][3] + t1[0][3] + air("1")[0], 14)
want("…and the time's box as wide as at any other hour", t1[1][3] + t1[0][1], 0)
# the wings (while music plays): 14 px to the date and from the time, their columns' air counted
want("the left wing → the date", IR("eq-0") + box("#custom-wing-left")[0][1] + air("2")[0], 14)
want("the time → the right wing", air("M")[1] + box("#custom-wing-right")[0][3] + IL("eq-0"), 14)
want("the left rod → the left wing's ink", 2 + box("#when")[0][3] + box("#custom-wing-left")[1][3] + IL("eq-0"), 15)
want("the right wing's ink → the right rod", IR("eq-0") + box("#custom-wing-right")[1][1] + box("#when")[0][1], 8)
print("\n".join(bad))
EOF
)
[[ -z $out ]] && _ok || _no "$out"

done_
