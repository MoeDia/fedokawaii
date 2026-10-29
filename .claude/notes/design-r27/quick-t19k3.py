#!/usr/bin/env python3
"""T19k-3 sketches: quick settings, three directions, both moods, the real faces (Sumi UI 14,
Sumi Icons) and the Wada palette — structure and grammar only (the pictures are today's 14 px
tile icons; T19k-4 draws them anew). Not a deliverable.
   python3 -I quick-t19k3.py REPO OUTDIR"""
import importlib.util, pathlib, re, sys
from PIL import Image, ImageDraw, ImageFont

REPO, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location("wp", REPO / "tools/wada-palette.py")
wp = importlib.util.module_from_spec(spec); spec.loader.exec_module(wp)
P, KAMI, TILE, _ = wp.palette()
UI = ImageFont.truetype("/usr/local/share/fonts/fedokawaii/SumiUI.ttf", 14)
IC = ImageFont.truetype(str(pathlib.Path.home() / ".local/share/fonts/SumiIcons.ttf"), 14)
ICONS = {}
for line in (REPO / "configs/home/.config/fedokawaii/icons.sh").read_text().splitlines():
    m = re.match(r"ICON_(\w+)=\$'((?:\\x[0-9a-f]{2})+)'", line)
    if m:
        ICONS[m.group(1).lower()] = bytes(int(h, 16) for h in m.group(2).split("\\x")[1:]).decode()

ITEMS = [("tile_moon", "theme", "dark", True), ("tile_lantern", "night light", "off", False),
         ("tile_wave", "freesync", "games · off", False), ("tile_ethernet", "network", "wired", True),
         ("tile_bluetooth", "bluetooth", "off", False), ("tile_devices", "devices", "none", False),
         ("tile_drive", "drives", "none", False), ("tile_backup", "backup", "not set up", False),
         ("tile_bell", "dnd", "off", False), ("tile_saver", "screensaver", "15 min", True),
         ("tile_record", "record", "off", False), ("tile_read", "read text", "a region", False)]
CUR = 1          # the cursor on the second item: night light, off


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def text(d, x, y, s, col, font=UI, centre=False):
    w = int(font.getlength(s))
    if centre:
        x -= w // 2
    d.text((x, y - 1), s, font=font, fill=rgb(col))
    return w


def disc(d, cx, cy, r, fill=None, outline=None):
    d.ellipse((cx - r, cy - r, cx + r - 1, cy + r - 1), fill=rgb(fill) if fill else None,
              outline=rgb(outline) if outline else None)


def meters(d, p, x, y, w, cur=False):
    for i, (ic, name, pct) in enumerate((("brightness", "brightness", 70), ("vol_2", "sound", 45))):
        yy = y + i * 20
        text(d, x + 8, yy + 3, ICONS.get(ic, "?"), p["muted"], IC)
        text(d, x + 32, yy + 3, name, p["text"])
        lit = pct // 5
        for s in range(20):
            sx = x + w - 160 + s * 8
            col = (p["accent"] if s >= 18 else p["flame"] if s >= 16 else p["asagi"]) if s < lit else p["edge"]
            d.rectangle((sx, yy + 5, sx + 5, yy + 14), fill=rgb(col))


def frame(m, w, h):
    p = P[m]
    im = Image.new("RGB", (w + 40, h + 40), (90, 90, 90))
    d = ImageDraw.Draw(im); d.fontmode = "1"
    d.rectangle((10, 10, 10 + w - 1, 10 + h - 1), fill=rgb(p["ground"]), outline=rgb(p["edge2"]))
    return im, d, p


def heading(d, p, x, y, w, name="quick settings"):
    text(d, x, y + 3, ICONS.get("settings", "?"), p["accent_text"], IC)
    n = text(d, x + 24, y + 3, name, p["strong"])
    d.line((x + 24 + n + 8, y + 10, x + w - 1, y + 10), fill=rgb(p["edge2"]))


# A — the mon sheet (家紋): no boxes; each item a crest 36 px across on a 4-column sheet,
# its name and state under it; the cursor the lacquer behind the whole cell
def mon(m):
    W, H = 2 * 17 + 376, 2 * 17 + 28 + 40 + 16 + 3 * 92 + 16 + 20
    im, d, p = frame(m, W, H)
    x0, y0 = 10 + 17, 10 + 17
    heading(d, p, x0, y0, 376)
    meters(d, p, x0, y0 + 28, 376)
    gy = y0 + 28 + 40 + 16
    cw = 94
    for i, (ic, name, val, on) in enumerate(ITEMS):
        cx, cy = x0 + (i % 4) * cw + cw // 2, gy + (i // 4) * 92
        cur = i == CUR
        if cur:
            d.rectangle((cx - cw // 2, cy, cx + cw // 2 - 1, cy + 87), fill=rgb(p["select"]))
        ink = p["text_on_select"] if cur else None
        if on:
            disc(d, cx, cy + 4 + 18, 18, fill=ink or p["accent"])
            disc(d, cx, cy + 4 + 18, 15, outline=p["select"] if cur else p["key"])
            text(d, cx, cy + 4 + 18 - 7, ICONS[ic], p["select"] if cur else p["key"], IC, centre=True)
        else:
            disc(d, cx, cy + 4 + 18, 18, outline=ink or p["edge2"])
            text(d, cx, cy + 4 + 18 - 7, ICONS[ic], ink or p["muted"], IC, centre=True)
        text(d, cx, cy + 48, name, ink or (p["text"] if on else p["muted"]), centre=True)
        text(d, cx, cy + 66, val, ink or (p["strong"] if on else p["faint"]), centre=True)
    return im


# B — the ema wall (絵馬): wooden plaques hung from a rod, a row of three; the picture painted
# (vermilion) and a hanko when on, unpainted wood when off; the cursor the lacquer plaque
def ema(m):
    W, H = 2 * 17 + 376, 2 * 17 + 28 + 40 + 16 + 4 * 96 + 8
    im, d, p = frame(m, W, H)
    x0, y0 = 10 + 17, 10 + 17
    heading(d, p, x0, y0, 376)
    meters(d, p, x0, y0 + 28, 376)
    gy = y0 + 28 + 40 + 16
    k = KAMI[m]
    for r in range(4):
        ry = gy + r * 96
        d.rectangle((x0, ry, x0 + 375, ry + 2), fill=rgb(k["rod"]))                  # the rod
        d.rectangle((x0, ry, x0 + 3, ry + 2), fill=rgb(k["gold"])); d.rectangle((x0 + 372, ry, x0 + 375, ry + 2), fill=rgb(k["gold"]))
        for c in range(3):
            i = r * 3 + c
            ic, name, val, on = ITEMS[i]
            px = x0 + c * 128 + 4
            cur = i == CUR
            body = p["select"] if cur else p["key"]
            edge = p["select"] if cur else p["edge2"]
            cx = px + 56
            d.line((cx, ry + 3, cx - 14, ry + 14), fill=rgb(p["muted"])); d.line((cx, ry + 3, cx + 14, ry + 14), fill=rgb(p["muted"]))
            # the plaque: a gable (the ema's roof) over a body 112 × 66
            for yy in range(10):
                d.line((cx - 14 - yy * 4, ry + 14 + yy, cx + 14 + yy * 4 - 1, ry + 14 + yy), fill=rgb(body))
            d.rectangle((px, ry + 24, px + 111, ry + 89), fill=rgb(body), outline=rgb(edge))
            ink = p["text_on_select"] if cur else None
            text(d, cx, ry + 30, ICONS[ic], ink or (p["accent"] if on else p["muted"]), IC, centre=True)
            text(d, cx, ry + 50, name, ink or (p["text"] if on else p["muted"]), centre=True)
            text(d, cx, ry + 68, val, ink or (p["strong"] if on else p["faint"]), centre=True)
            if on and not cur:
                d.rectangle((px + 100, ry + 78, px + 107, ry + 85), fill=rgb(p["accent"]))   # the hanko
    return im


# C — the list (one grammar with Super+U): a row each, its crest (20 px) in the icon column,
# its name, its state right-aligned — on: strong and a vermilion hanko dot; off: faint
def lst(m):
    rows = len(ITEMS)
    W, H = 2 * 17 + 376, 2 * 17 + 28 + 40 + 16 + rows * 24
    im, d, p = frame(m, W, H)
    x0, y0 = 10 + 17, 10 + 17
    heading(d, p, x0, y0, 376)
    meters(d, p, x0, y0 + 28, 376)
    gy = y0 + 28 + 40 + 16
    for i, (ic, name, val, on) in enumerate(ITEMS):
        y = gy + i * 24
        cur = i == CUR
        if cur:
            d.rectangle((x0 - 8, y, x0 + 383, y + 23), fill=rgb(p["select"]))
        ink = p["text_on_select"] if cur else None
        if on:
            disc(d, x0 + 18, y + 12, 10, fill=ink or p["accent"])
            text(d, x0 + 18, y + 5, ICONS[ic], p["select"] if cur else p["key"], IC, centre=True)
        else:
            disc(d, x0 + 18, y + 12, 10, outline=ink or p["edge2"])
            text(d, x0 + 18, y + 5, ICONS[ic], ink or p["muted"], IC, centre=True)
        text(d, x0 + 40, y + 5, name, ink or p["text"])
        w = int(UI.getlength(val))
        text(d, x0 + 376 - w, y + 5, val, ink or (p["strong"] if on else p["faint"]))
    return im


for name, fn in (("A-mon", mon), ("B-ema", ema), ("C-list", lst)):
    a, b = fn("dark"), fn("light")
    sheet = Image.new("RGB", (a.width + b.width, max(a.height, b.height)), (90, 90, 90))
    sheet.paste(a, (0, 0)); sheet.paste(b, (a.width, 0))
    sheet.save(OUT / f"quick-{name}.png")
print("ok")
