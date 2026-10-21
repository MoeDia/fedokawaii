#!/usr/bin/env bash
# tests/static/test_bargaps.sh — the bar's spacing, worked out from the drawings and the style,
# to the pixel (the numbers style.css's header promises, and the bar measures on screen):
#   · an icon before a value (icons.sh's ICON_BAR_*): its ink from the module's edge (no air
#     before it), exactly 8 px from its ink to the value's, whatever the icon's own air
#   · every module with an icon and a value draws it with ICON_BAR_*, never "icon value"
#   · no module holds a fixed width (which would put cloth after the value)
#   · the rhythm, thread to ink: 8 px inside every cell — the torii's and the cat's beni
#     patches, each workspace's cell (36 px, 35 for 四 七 九), each module's on the right
#     (from its seam's thread to its ink, and on to the next cell's thread) —; 16 px from the
#     last workspace's thread to the layout's ink, and on to the title; the clock on the cloth,
#     8 px from either of its seams to the ink beside it, 16 from it to the music's wings
#   · every box exactly its picture's width; the pictures' threads where the boxes expect
#     them (a cell's frame on its edge pixels, a seam's thread in its 2nd column), the patches
#     on rows 4–26, the seams the capitals' height (rows 9–21: three stitches), all centred on
#     row 15; the hem on row 29 alone
#   · the rows: the 16 px line on 8 px of cloth and 7 under it (an icon alone a row higher)
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

case_ "the rhythm, from the style and the drawings: 8 px from thread to ink inside every cell and either side of the clock's seams, 16 to the layout and the title, 16 from the clock to the wings; every box its picture; the rows"
out=$(python3 -I - "$REPO" 2>&1 <<'EOF'
import re, sys
from PIL import Image
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
    """does the rule's selector x apply to the element sel ("#custom-tag4.selected",
    ".tag.urgent" for any workspace)? — by its id and classes"""
    want = set(re.findall(r"[#.][\w-]+", sel))
    if any(w.startswith("#custom-tag") for w in want): want.add(".tag")
    have = re.findall(r"[#.][\w-]+", x)
    return bool(have) and ":" not in x and set(have) <= want
def box(sel):
    pad, mar, other = [0] * 4, [0] * 4, {}
    for sels, p in rules:
        if not any(matches(sel, x) for x in sels): continue
        for k, v in p.items():
            if k == "padding": pad = four(v)
            elif k == "margin": mar = four(v)
            elif k.startswith(("padding-", "margin-")):
                side = ("top", "right", "bottom", "left").index(k.split("-")[1])
                (pad if k.startswith("padding") else mar)[side] = px(v)
            else: other[k] = v
    return pad, mar, other
def pic(sel):
    m = re.findall(r'url\("[^"]*/([^"/]+)"\)', box(sel)[2].get("background-image", ""))
    return m[0] if m else None
bad = []
src = open(root + "/tools/build-icons.py").read().split("if __name__")[0]
g = {"__name__": "bi", "__file__": root + "/tools/build-icons.py"}
exec(compile(src, "build-icons", "exec"), g)
ic = {i["name"]: i for i in g["parse"](open(root + "/art/icons.txt").read())}
L = lambda n: g["left_air"](ic[n]); R = lambda n: g["right_air"](ic[n])
T = root + "/configs/home/.config/fedokawaii/themes/"
def want(what, got, n):
    if got != n: bad.append(f"{what}: {got} px, not {n}")
def threads(theme, name, top=4, n=5):
    """a picture's vertical threads: (width, height, [columns], first row, last row) — a
    thread a running stitch of n stitches down from row top in the colour of its first
    stitch (1, top): 3 px on, 2 off"""
    im = Image.open(T + theme + "/" + name).convert("RGBA"); w, h = im.size
    t = im.getpixel((1, top))
    on = lambda x, y: im.getpixel((x, y)) == t
    run = [y for k in range(n) for y in range(top + 5 * k, top + 3 + 5 * k)]
    gaps = [y for k in range(n - 1) for y in (top + 3 + 5 * k, top + 4 + 5 * k)]
    cols = [x for x in range(w) if all(on(x, y) for y in run) and not any(on(x, y) for y in gaps)]
    rows = [y for y in range(h) if cols and on(cols[0], y)]
    return w, h, cols, min(rows or [0]), max(rows or [0])
from PIL import ImageFont, ImageDraw
SUMI = ImageFont.truetype(root + "/system/fonts/SumiUI.ttf", 16)
def air(ch):
    """Sumi UI's own air either side of a letter's ink (px)"""
    im = Image.new("L", (48, 24)); ImageDraw.Draw(im).text((8, 0), ch, font=SUMI, fill=255)
    xs = [x for x in range(48) for y in range(24) if im.getpixel((x, y)) > 128]
    return min(xs) - 8, int(SUMI.getlength(ch)) - (max(xs) - 8) - 1
cfg = re.sub(r"^\s*//.*$", "", open(root + "/configs/home/.config/waybar/config.jsonc").read(), flags=re.M)
height = int(re.search(r'"height":\s*(\d+)', cfg).group(1))
want("the bar's height", height, 31)
# every picture: a cell its frame on its edge pixels (rows 4–26), a seam its thread in its 2nd
# column (rows 9–21, three stitches, no cross), all centred on row 15, both themes alike
for th in ("dark", "light"):
    for n in ["seam.png"] + [f"cell-{k}-{w}.png" for k in ("bare", "windows", "here", "urgent") for w in (35, 36)] + ["cell-beni-35.png"]:
        sm = n == "seam.png"
        w, h, cols, top, foot = threads(th, n, *((9, 3) if sm else (4, 5)))
        want(f"{th}/{n}: its height", h, height)
        if cols != ([1] if sm else [1, w - 2]): bad.append(f"{th}/{n}: threads in columns {cols}")
        if (top, foot) != ((9, 21) if sm else (4, 26)): bad.append(f"{th}/{n}: thread on rows {top}–{foot}")
        if not sm and w != int(n.split("-")[-1][:2]): bad.append(f"{th}/{n}: {w} px wide")
        im = Image.open(T + th + "/" + n).convert("RGBA")
        if sm and any(im.getpixel((x, y))[3] for x in range(w) for y in list(range(9)) + list(range(23, h))):
            bad.append(f"{th}/seam.png: ink outside rows 9–22 (the thread and its shadow)")
        if any(im.getpixel((0, y))[3] for y in range(h)) and not sm:
            bad.append(f"{th}/{n}: ink left of its frame (a cross's arm: gone in v11)")
        if sm and any(im.getpixel((0, y))[3] for y in range(h)):
            bad.append(f"{th}/seam.png: a cross on it")
    hm = Image.open(T + th + "/hems.png").convert("RGBA")
    hr = [y for y in range(hm.size[1]) if hm.getpixel((1, y))[3]]
    if hm.size[1] != height or hr != [29]: bad.append(f"{th}/hems.png: {hm.size}, stitches on rows {hr} (not 29 alone)")
    if __import__("os").path.exists(T + th + "/clock.png"): bad.append(f"{th}/clock.png: the clock has no patch now")
o = box("window#waybar")[2]
if 'hems.png' not in o.get("background-image", "") or not o.get("background-position", "").startswith("center 0"):
    bad.append("the hems: not laid from the bar's middle (center 0)")
# the rows: the line on 8 px of cloth, 7 under it; an icon alone a row higher
for sel in ("#custom-date", ".tag", "#custom-volume", "#custom-title", "#custom-wing-left"):
    p_ = box(sel)[0]; want(f"{sel}: above the line", p_[0], 8); want(f"{sel}: under it", p_[2], 7)
for sel in ("#custom-torii", "#custom-menu", "#custom-layout", "#custom-steam"):
    p_ = box(sel)[0]; want(f"{sel}: above the icon", p_[0], 7); want(f"{sel}: under it", p_[2], 8)
pad = lambda s, i: box(s)[0][i]
W = lambda s, ink: pad(s, 3) + ink + pad(s, 1)          # (a box: its padding and its line's advance)
# the patches at the corners: 8 px of beni from the frame to the 15 px of ink, each side
for sel, n in (("#custom-torii", "torii"), ("#custom-menu", "cat")):
    if pic(sel) != "cell-beni-35.png": bad.append(f"{sel}: its picture {pic(sel)}")
    want(f"{sel}: its box, its picture's width", W(sel, 16), 35)
    want(f"{sel}: the frame → its ink", pad(sel, 3) - 2 + L(n), 8)
    want(f"{sel}: its ink → the frame", R(n) + pad(sel, 1) - 2, 8)
# the workspaces: each cell its picture, by state; 8 px from either frame to the numeral (四 七
# 九: 15 px of ink in their 16, the cell a pixel narrower)
for k in range(1, 10):
    narrow = k in (4, 7, 9)
    for state, kind in (("", "bare"), (".occupied", "windows"), (".selected", "here"), (".urgent", "urgent")):
        sel = f"#custom-tag{k}{state}"
        want(f"{sel}: its picture", 0 if pic(sel) == f"cell-{kind}-{35 if narrow else 36}.png" else 1, 0)
    sel = f"#custom-tag{k}"
    want(f"{sel}: its box, its picture's width", W(sel, 16), 35 if narrow else 36)
    want(f"{sel}: the frame → the numeral", pad(sel, 3) - 2, 8)
    want(f"{sel}: the numeral → the frame", pad(sel, 1) + (1 if narrow else 0) - 2, 8)
want("the last cell's thread → the layout", 1 + pad("#custom-layout", 3) + L("tile"), 16)
want("layout → title", R("tile") + pad("#custom-layout", 1) + pad("#custom-title", 3), 16)
# the clock on the cloth: the day's kanji between two seams (its box's left and right
# edges), 8 px from each thread to the ink either side — the date's last letter ("Oct", as
# measured), the kanji, the time's first figure (0 or 1: hours 01–12); 16 from the clock's ink
# to the wings' (each eq column 2 px of ink in 4: 1 px of air each side)
L_ = lambda s: air(s[0])[0]; R_ = lambda s: air(s[-1])[1]
ly = [q.strip() for q in box("#custom-day")[2].get("background-position", "").split(",")]
if pic("#custom-day") != "seam.png" or ly != ["left top", "right top"]: bad.append(f"#custom-day: its seams {ly}")
want("the date (…Oct) → the left thread", pad("#custom-date", 1) + 1 + R_("Oct"), 8)
want("the left thread → the kanji (火)", pad("#custom-day", 3) - 2 + L_("火"), 8)
want("the kanji (火) → the right thread", R_("火") + pad("#custom-day", 1) - 3, 8)
for d in ("0", "1"):
    want(f"the right thread → the time ({d}…)", 2 + pad("#custom-time", 3) + L_(d), 8)
want("Monday's box (月: 13 px of ink in its 16) as wide as any day's", W("#custom-day.mon", 16), W("#custom-day", 16))
eqL, eqR = g["left_air"](ic["eq-3"]), g["right_air"](ic["eq-3"])
for d in "MTWFS":
    want(f"the left wing → the date ({d}…)", eqR + pad("#custom-wing-left", 1) + pad("#custom-date", 3) + L_(d), 16)
want("the time (…M) → the right wing", R_("M") + pad("#custom-time", 1) + pad("#custom-wing-right", 3) + eqL, 16)
p_l, p_r = box("#custom-wing-left")[0], box("#custom-wing-right")[0]
want("the wings mirrored (the clock in the middle)", [p_l[0], p_l[1], p_l[2], p_l[3]], [p_r[0], p_r[3], p_r[2], p_r[1]])
# the right: a seam down each cell's left edge, 8 px from its thread to the ink and on to the
# next thread (the last glyph's air counted)
right = ("#custom-nowplaying", "#custom-timer", "#custom-record", "#custom-mode", "#custom-drives",
         "#custom-downloads", "#custom-kb", "#custom-mem", "#custom-volume", "#custom-brightness", "#custom-weather")
for sel in right + ("#custom-steam",):
    if pic(sel) != "seam.png": bad.append(f"{sel}: its picture {pic(sel)}")
for sel in right:
    air = {"#custom-weather": 3}.get(sel, 0)                 # (° stands at the left of its cell)
    want(f"{sel}: its thread → its ink", pad(sel, 3) - 2, 8)
    want(f"{sel}: its ink → the next thread", pad(sel, 1) + air + 1, 8)
want("#custom-downloads.bare (1 px of air each side)", pad("#custom-downloads.bare", 3) - 2 + 1, 8)
want("#custom-downloads.bare → the next thread", pad("#custom-downloads.bare", 1) + 1 + 1, 8)
want("#custom-volume.muted (off: 1 px)", pad("#custom-volume.muted", 1) + 1 + 1, 8)
want("#custom-steam: its thread → the gamepad", pad("#custom-steam", 3) - 2 + L("gamepad"), 8)
want("#custom-steam: the gamepad → the next thread", R("gamepad") + pad("#custom-steam", 1) + 1, 8)
print("\n".join(bad))
EOF
)
[[ -z $out ]] && _ok || _no "$out"

done_
