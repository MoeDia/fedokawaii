#!/usr/bin/env bash
# tests/static/test_bargaps.sh — the bar's spacing, worked out from the drawings and the style,
# to the pixel (the numbers style.css's header promises, and the bar measures on screen):
#   · an icon before a value (icons.sh's ICON_BAR_*): its ink from the module's edge (no air
#     before it), exactly 8 px from its ink to the value's, whatever the icon's own air
#   · every module with an icon and a value draws it with ICON_BAR_*, never "icon value"
#   · no module holds a fixed width (which would put cloth after the value)
#   · the tiles (紙 kami): each a border-image of its theme's picture (kami-tile, kami-red at
#     the corners, kami-scroll round the clock) sliced as drawn — the hairline on rows 2 and
#     28, the paper 3–27 with its rule on 5 and 25, the shadow 29–30 — the text line on rows
#     8–23 (an icon alone a row higher)
#   · 8 px from the paper's edge to the ink both sides inside a tile (each glyph's air
#     counted); 4 px paper to paper within a group, 10 between groups, 6 to the screen's edges
#   · the layout and the title a tile each; the clock's parts in one scroll, 14 px of air apart
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
grep -q 'bar_download' "$REPO/bin/kawa-downloads" && _ok || _no "kawa-downloads draws its icon with a space"

CSS=$REPO/configs/home/.config/waybar/style.css
case_ "no module of the bar holds a fixed width"
bad=$(grep -nE 'min-width: *[0-9]+px' "$CSS" | grep -vE 'min-width: *(0|1)px')
[[ -z $bad ]] && _ok || _no "$bad"

case_ "the tiles, from the style and the drawings: the pictures' rows, 8 px paper to ink, 4 / 10 / 6 px paper to paper, the layout and the title a tile each, the clock's parts 14 px apart in the scroll"
out=$(python3 -I -B - "$REPO" 2>&1 <<'EOF'
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
SUMI = ImageFont.truetype(root + "/system/fonts/SumiUI.ttf", 16)
def air(ch):
    im = Image.new("L", (48, 24)); ImageDraw.Draw(im).text((8, 0), ch, font=SUMI, fill=255)
    xs = [x for x in range(48) for y in range(24) if im.getpixel((x, y)) > 128]
    return min(xs) - 8, int(SUMI.getlength(ch)) - (max(xs) - 8) - 1
T = root + "/configs/home/.config/fedokawaii/themes/"
cfg = re.sub(r"^\s*//.*$", "", open(root + "/configs/home/.config/waybar/config.jsonc").read(), flags=re.M)
height = int(re.search(r'"height":\s*(\d+)', cfg).group(1)); want("the bar's height", height, 31)
# the pictures: the hairline on rows 2 and 28, the paper's rule on 5 and 25, the shadow 29–30,
# nothing on rows 0–1; a tile's slices: the hairline its outer column, then two of paper, the rule
for th in ("dark", "light"):
    for n, w in (("kami-tile.png", 12), ("kami-red.png", 12), ("kami-scroll.png", 19)):
        im = Image.open(T + th + "/" + n).convert("RGBA"); a = lambda x, y: im.getpixel((x, y))
        want(f"{th}/{n}: its size", im.size, (w, height))
        if n != "kami-scroll.png" and any(a(x, y)[3] for x in range(w) for y in (0, 1)): bad.append(f"{th}/{n}: ink above the hairline")
        if not (a(3, 2) == a(3, 28) and a(3, 2)[3] and not a(3, 1)[3] if n != "kami-scroll.png" else a(9, 28)[3]): bad.append(f"{th}/{n}: no hairline on rows 2 and 28")
        if not all(a(5, y)[3] for y in (29, 30)): bad.append(f"{th}/{n}: no shadow on rows 29–30")
        if n != "kami-scroll.png":
            r = a(5, 5)
            if not (a(5, 25) == r and a(3, 15) == r and a(7, 15) == r and a(5, 4) != r and a(0, 15) == a(3, 2)):
                bad.append(f"{th}/{n}: the rule not on rows 5 and 25, columns 3 and 7 (the hairline in column 0)")
    try: Image.open(T + th + "/kami-fibre.png")
    except OSError: bad.append(f"{th}/kami-fibre.png: missing")
    # the seal drawn to the workspace tile's padding box exactly: its numeral's 16 px and
    # the padding (26 × 19; 25 for 四 七 九, whose tile is a pixel narrower)
    for n, k in (("kami-seal.png", "#custom-tag1"), ("kami-seal-narrow.png", "#custom-tag4")):
        p_ = box(k)[0]
        want(f"{th}/{n}: its size, the tile's padding box", Image.open(T + th + "/" + n).size, (p_[3] + 16 + p_[1], p_[0] + 16 + p_[2]))
    for old in ("washi.png", "hems.png", "seam.png", "cell-bare-36.png", "clock.png", "stitch.png", "hem.png"):
        if __import__("os").path.exists(T + th + "/" + old): bad.append(f"{th}/{old}: still there")
for k in range(1, 10):
    w_ = "kami-seal-narrow.png" if k in (4, 7, 9) else "kami-seal.png"
    if f'/{w_}"' not in box(f"#custom-tag{k}.selected")[3].get("background-image", ""): bad.append(f"#custom-tag{k}.selected: not on {w_}")
tiles = ["#custom-torii", "#custom-menu", "#custom-layout", "#custom-title"] + [f"#custom-tag{k}" for k in range(1, 10)] + \
        ["#custom-nowplaying", "#custom-timer", "#custom-record", "#custom-mode", "#custom-drives", "#custom-downloads",
         "#custom-steam", "#custom-kb", "#custom-mem", "#custom-volume", "#custom-brightness", "#custom-weather"]
for sel in tiles:
    p_, m_, b_, o = box(sel)
    kind = "kami-red.png" if sel in ("#custom-torii", "#custom-menu") else "kami-tile.png"
    if kind not in o.get("border-image", "") or not o.get("border-image", "").split(")")[1].strip().startswith("6 5 6 4"):
        bad.append(f"{sel}: border-image {o.get('border-image')}")
    want(f"{sel}: its border", b_, [6, 5, 6, 4])
    alone = sel in ("#custom-torii", "#custom-menu", "#custom-layout", "#custom-steam")
    want(f"{sel}: the line on rows {'7–22' if alone else '8–23'}", (b_[0] + p_[0], b_[0] + p_[0] + 16 + p_[2] + b_[2]), ((7, height) if alone else (8, height)))
L = lambda s, ink: 3 + box(s)[0][3] + ink                 # (the paper's edge → the ink: the border's 3 of paper)
R = lambda s, ink: ink + box(s)[0][1] + 3
for sel, l, r in (("#custom-torii", IL("torii"), IR("torii")), ("#custom-menu", IL("cat"), IR("cat")),
                  ("#custom-tag1", 0, 0), ("#custom-tag4", 0, 1), ("#custom-volume", 0, 0), ("#custom-weather", 0, 3),
                  ("#custom-steam", IL("gamepad"), IR("gamepad")), ("#custom-layout", IL("tile"), IR("tile")), ("#custom-title", 0, None)):
    if l is not None: want(f"{sel}: the paper → its ink", L(sel, l), 8)
    if r is not None: want(f"{sel}: its ink → the paper", R(sel, r), 8)
# paper to paper: a tile's right edge 2 columns of hairline and shadow, the next's left 1
gap = lambda s: 2 + box(s)[1][3] + 1
for sel in [f"#custom-tag{k}" for k in range(2, 10)] + ["#custom-timer", "#custom-volume", "#custom-weather"]:
    want(f"→ {sel} (within a group)", gap(sel), 4)
for sel in ("#custom-tag1", "#custom-layout", "#custom-menu"):
    want(f"→ {sel} (between groups)", gap(sel), 10)
want("the screen's left edge → the torii", box("#custom-torii")[1][3] + 1, 6)
want("the cat → the screen's right edge", 2 + box("#custom-menu")[1][1], 6)
# the clock: the scroll sliced 6 8 6 8; the wings 8 eq columns
# (4 px each), the date "Wed 21 Oct" 80 px, the time "09:14:08 PM" 88
pw = lambda s: box(s)[0][3] + box(s)[0][1]
o = box("#when")[3]
if "kami-scroll.png" not in o.get("border-image", "") or "6 8 6 8" not in o.get("border-image", ""): bad.append(f"#when: {o.get('border-image')}")
want("#when's border", box("#when")[2], [6, 8, 6, 8])
# (14 px of air between the clock's parts, each letter's own air counted: the wing's last
# column has 1, the date's month its letter's (a class each — width.sh's air), the time's
# first figure none, AM/PM's M a column)
want("#custom-wing-left: the padding after it", box("#custom-wing-left")[0][1], 13)
want("#custom-day: the padding after it", box("#custom-day")[0][1], 14)
want("#custom-date: the padding after it (a month ending in no air)", box("#custom-date")[0][1], 14)
for n in (1, 2, 3):
    want(f"#custom-date.r{n}: the padding after it", box(f"#custom-date.r{n}")[0][1], 14 - n)
want("#custom-wing-right: the padding before it", box("#custom-wing-right")[0][3], 12)
want("Monday's (月) box as wide as any day's", pw("#custom-day.mon"), pw("#custom-day"))
print("\n".join(bad))
EOF
)
[[ -z $out ]] && _ok || _no "$out"

done_
