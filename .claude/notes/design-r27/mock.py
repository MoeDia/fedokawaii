#!/usr/bin/env python3
"""T09 mock: the new grid sketched with the real faces and the Wada palette (not a deliverable).
   python3 -I mock.py REPO OUTDIR [variant…]"""
import importlib.util, sys, pathlib
from PIL import Image, ImageDraw, ImageFont

REPO, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
VAR = set(sys.argv[3:])
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location("wp", REPO / "tools/wada-palette.py")
wp = importlib.util.module_from_spec(spec); spec.loader.exec_module(wp)
P, KAMI, TILE, EDITOR = wp.palette()
UI = ImageFont.truetype(str(pathlib.Path.home() / ".cache/r27-fonts/jfdotfont/x/JF-Dot-Shinonome14.ttf"), 14)
TERM = ImageFont.truetype(str(pathlib.Path.home() / ".cache/r27-fonts/udev-gothic-nf-2.2.0/x/UDEVGothic_NF_v2.2.0/UDEVGothicNF-Regular.ttf"), 16)
UI_ASC = UI.getmetrics()[0]          # PIL draws at the ascender's top: the em's top is a row below (ascent 13 = em 14 - 1)

def rgb(h, a=255):
    if isinstance(h, tuple): return h if len(h) == 4 else h + (a,)
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def ui_text(im, x, em_top, s, col):
    """Sumi UI at 14 px, unsmoothed, its em's top row at em_top (the em: rows em_top..em_top+13)."""
    layer = Image.new("1", im.size, 0); d = ImageDraw.Draw(layer); d.fontmode = "1"
    d.text((x, em_top - 1), s, font=UI, fill=1)
    im.paste(Image.new("RGBA", im.size, rgb(col)), (0, 0), layer)
    return x + int(UI.getlength(s))

def term_text(im, x, y, s, col):
    d = ImageDraw.Draw(im); d.fontmode = "L"
    d.text((x, y + 1), s, font=TERM, fill=rgb(col))

def bitmap(im, x, y, rows, col):
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch == "#": im.putpixel((x + i, y + j), rgb(col))

def blend(im, x, y, col):
    if 0 <= x < im.width and 0 <= y < im.height:
        base = im.getpixel((x, y)); c = rgb(col); a = c[3] / 255
        im.putpixel((x, y), tuple(round(base[i] * (1 - a) + c[i] * a) for i in range(3)) + (255,))

# ── 12 × 12 icons, 1 px strokes (the regular face's weight), for the mock only ──────────
ICONS = {
 "speaker": ["....#.......", "...##.......", "..#.#...#...", "##..#....#..", "#...#..#..#.", "#...#...#.#.",
             "#...#...#.#.", "#...#..#..#.", "##..#....#..", "..#.#...#...", "...##.......", "....#......."],
 "sun2":    [".....##.....", "..#......#..", "...........#", "....####....", "...#....#...", "#..#....#..#",
             "#..#....#..#", "...#....#...", "....####....", "#...........", "..#......#..", ".....##....."],
 "chip":    ["..#.#..#.#..", "............", "#.########.#", "..#......#..", "#.#.####.#.#", "..#.#..#.#..",
             "..#.#..#.#..", "#.#.####.#.#", "..#......#..", "#.########.#", "............", "..#.#..#.#.."],
 "wave":    ["............", "............", "....####....", "..##....##..", ".#........#.", "....####....",
             "...#....#...", "............", ".....##.....", ".....##.....", "............", "............"],
 "folder":  ["............", "####........", "#...#.......", "#....######.", "#..........#", "#..........#",
             "#..........#", "#..........#", "#..........#", "#..........#", "############", "............"],
 "gear":    [".....##.....", "..#.#..#.#..", ".#.#....#.#.", "..#..##..#..", ".#..#..#..#.", "#..#....#..#",
             "#..#....#..#", ".#..#..#..#.", "..#..##..#..", ".#.#....#.#.", "..#.#..#.#..", ".....##....."],
 "shield":  ["####....####", "#...####...#", "#..........#", "#....##....#", "#...#..#...#", "#...#..#...#",
             ".#...##...#.", ".#...##...#.", "..#..##..#..", "...#....#...", "....#..#....", ".....##....."],
 "update":  [".....#......", "....###.....", "...#.#.#....", ".....#......", ".....#......", "..#..#..#...",
             ".#...#...#..", "#.........#.", "#.........#.", ".#.......#..", "..#######...", "............"],
}
TORII = ["##...........##", "###############", ".#############.", "...##.....##...", "...##.....##...", "###############",
         "...##.....##...", "...##.....##...", "...##.....##...", "...##.....##...", "...##.....##...", "...##.....##...",
         "...##.....##...", "...##.....##...", "...##.....##..."]
DEMON = ["..#.........#..", ".##.........##.", ".###.#####.###.", "..############.", "..#.#######.#..", ".#############.",
         ".##..#####..##.", ".#.##.###.##.#.", ".#############.", "..###.....###..", "..##.#.#.#.##..", "...#########...",
         "....#.#.#.#....", ".....#####.....", "...............",]
SMALL = {1: [".........", ".........", ".........", ".........", "#########", ".........", ".........", ".........", "........."],
         2: [".........", ".#######.", ".........", ".........", ".........", ".........", ".........", "#########", "........."],
         3: [".#######.", ".........", ".........", "..#####..", ".........", ".........", ".........", "#########", "........."]}

# ── the bar: 27 rows ──────────────────────────────────────────────────────────────────────
B_AIR, B_HT, B_P0, B_P1, B_HB = 3, 3, 4, 23, 24      # hairline 3, paper 4–23 (one 20 px row), hairline 24, shadow 25–26
B_EM = B_P0 + 3                                       # em 7–20: caps 9–18 (5 rows of paper either side), kanji 7–20 (3)

def tile(im, x0, x1, fill, m):
    """paper x0..x1 inclusive, its hairline round it (corners cut), the shadow down-right."""
    k = KAMI[m]
    for y in range(B_P0, B_P1 + 1):
        for x in range(x0, x1 + 1): im.putpixel((x, y), rgb(fill))
    for x in range(x0, x1 + 1): blend(im, x, B_HT, k["hair"]); blend(im, x, B_HB, k["hair"])
    for y in range(B_P0, B_P1 + 1): blend(im, x0 - 1, y, k["hair"]); blend(im, x1 + 1, y, k["hair"])
    for i, a in enumerate(k["shadow"]):
        for x in range(x0 + i, x1 + 2 + i): blend(im, x, B_HB + 1 + i, a)
        for y in range(B_P0 + 1 + i, B_HB + 1 + i): blend(im, x1 + 2 + i, y, a)

def seal(im, cx, cy, d, col):
    r = d / 2
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r: im.putpixel((x, y), rgb(col))

def bar(im, m):
    p = P[m]; t = TILE[m]; W = im.width
    x = 9
    # the torii on vermilion
    tile(im, x, x + 30, KAMI[m]["red"], m); bitmap(im, x + 8, B_EM, TORII, p["text_on_accent"]); x += 31 + 6
    # workspaces: 一 二 三 (三 current: a vermilion seal, its numeral black and small inside)
    for n in (1, 2, 3):
        tile(im, x, x + 24, t, m)
        cx, cy = x + 12.5, (B_P0 + B_P1 + 1) / 2
        if n == 3:
            seal(im, cx, cy, 17, KAMI[m]["red"]); bitmap(im, x + 8, B_P0 + 6, SMALL[n], wp.w("Black"))
        else:
            bitmap(im, x + 8, B_P0 + 6, SMALL[n], p["text"])
        x += 25 + 4
    x += 6
    tile(im, x, x + 100, t, m); xx = ui_text(im, x + 8, B_EM, "▤", p["muted"]); ui_text(im, x + 8 + 14 + 8, B_EM, "yazi", p["text"])
    # the clock's scroll, centred
    date = "27/10/2026"; tm = "04:59 AM"
    wd = int(UI.getlength(date)); wt = int(UI.getlength(tm)); wk = 14
    total = wd + 14 + wk + 14 + wt
    cx = W // 2; x0 = cx - wk // 2 - 14 - wd - 8
    tile(im, x0, x0 + 8 + total + 8 - 1, t, m)
    xa = x0 + 8
    for i, ch in enumerate(date):
        xa = ui_text(im, xa, B_EM, ch, p["accent_text"] if ch == "/" else p["text"])
    xa += 14; ui_text(im, xa, B_EM, "火", p["accent_text"]); xa += wk + 14; ui_text(im, xa, B_EM, tm, p["strong"])
    # the right: US, volume, RAM, the weather, the demon on vermilion
    x = W - 9 - 31 - 2
    tile(im, x, x + 30, KAMI[m]["red"], m); bitmap(im, x + 8, B_EM, DEMON, p["text_on_accent"])
    right = [("sun2", "+31°"), ("chip", "8%"), ("speaker", "40%"), (None, "US")]
    for ic, val in right:
        w = (12 + 8 if ic else 0) + int(UI.getlength(val))
        x -= 4 + w + 16
        tile(im, x, x + w + 15, t, m); xx = x + 8
        if ic: bitmap(im, xx, B_EM + 1, ICONS[ic], p["text"]); xx += 12 + 8
        ui_text(im, xx, B_EM, val, p["accent_text"] if val == "US" else p["text"])

# ── a frame for what floats on the screen: a 1 px hairline, a 2 px shadow down-right ─────────
def frame(im, x0, y0, x1, y1, m, line=None):
    k = KAMI[m]; c = line or k["hair"]
    for x in range(x0, x1 + 1): blend(im, x, y0, c); blend(im, x, y1, c)
    for y in range(y0 + 1, y1): blend(im, x0, y, c); blend(im, x1, y, c)
    for i, a in enumerate(k["shadow"]):
        for x in range(x0 + 1 + i, x1 + 2 + i): blend(im, x, y1 + 1 + i, a)
        for y in range(y0 + 1 + i, y1 + 1 + i): blend(im, x1 + 1 + i, y, a)

def fill(im, x0, y0, x1, y1, col, a=255):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): blend(im, x, y, rgb(col, a))

# ── a GUI panel on the 8 × 20 grid ───────────────────────────────────────────────────────────
ROW, CELL = 20, 8
def gui_panel(im, x0, y0, m, gap_under_heading):
    p = P[m]
    cols = 47; pad = 16
    rows_list = [("h", "speaker", "sound"), ("r", "speaker", "output", "speakers"), ("r", "wave", "microphone", "on"),
                 ("c", "chip", "memory", "8 % of 30 GB"), ("h", "gear", "system"), ("r", "update", "update", "2 weeks"),
                 ("r", "shield", "snapshots", "12"), ("r", "folder", "backups", "never")]
    h = pad
    for r in rows_list:
        h += ROW + (gap_under_heading if r[0] == "h" else 0) + (ROW if r[0] == "h" and r is not rows_list[0] else 0)
    h += pad
    w = pad + cols * CELL + pad
    fill(im, x0, y0, x0 + w - 1, y0 + h - 1, p["ground"], 235)
    frame(im, x0 - 1, y0 - 1, x0 + w, y0 + h, m)
    y = y0 + pad
    for i, r in enumerate(rows_list):
        if r[0] == "h":
            if i: y += ROW
            em = y + 3
            bitmap(im, x0 + pad, em + 1, ICONS[r[1]], p["accent_text"])
            xx = ui_text(im, x0 + pad + 12 + 8, em, r[2], p["strong"]) + 8
            for x in range(xx, x0 + w - pad): blend(im, x, em + 7, p["edge2"])
            y += ROW + gap_under_heading
        else:
            if r[0] == "c":
                fill(im, x0 + pad - 8, y, x0 + w - pad + 7, y + ROW - 1, p["accent"])
                ink, val_ink = p["text_on_accent"], p["text_on_accent"]
            else:
                ink, val_ink = p["text"], p["muted"]
            em = y + 3
            bitmap(im, x0 + pad + 8, em + 1, ICONS[r[1]], ink)
            ui_text(im, x0 + pad + 8 + 12 + 8, em, r[2], ink)
            vw = int(UI.getlength(r[3])); ui_text(im, x0 + w - pad - vw, em, r[3], val_ink)
            y += ROW
    return w, h

# ── a TUI panel (foot, Sumi Term 16 px in 8 × 20 cells) ─────────────────────────────────────
def tui_panel(im, x0, y0, m, cols, lines, blank_under_heading):
    p = P[m]
    w, h = cols * CELL + 2 * 8, lines * ROW + 2 * 8
    fill(im, x0, y0, x0 + w - 1, y0 + h - 1, p["ground"], 235)
    frame(im, x0 - 1, y0 - 1, x0 + w, y0 + h, m, line=p["accent"])
    ox, oy = x0 + 8, y0 + 8
    L = 1
    sec = [("sound", [("output", "speakers"), ("microphone", "on")]), ("system", [("update", "2 weeks"), ("snapshots", "12"), ("backups", "never")])]
    for si, (name, items) in enumerate(sec):
        if si: L += 2
        term_text(im, ox + 2 * CELL, oy + L * ROW, "\U000f0425", p["accent_text"])
        term_text(im, ox + 5 * CELL, oy + L * ROW, name, p["strong"])
        x = ox + (5 + len(name) + 1) * CELL
        d = ImageDraw.Draw(im)
        term_text(im, x, oy + L * ROW, "─" * (cols - 2 - (5 + len(name) + 1)), p["edge2"])
        L += 1 + blank_under_heading
        for j, (k, v) in enumerate(items):
            if si == 1 and j == 0:
                fill(im, ox + 1 * CELL, oy + L * ROW, ox + (cols - 1) * CELL - 1, oy + L * ROW + ROW - 1, p["accent"])
                ink, vink = p["text_on_accent"], p["text_on_accent"]
            else: ink, vink = p["text"], p["muted"]
            term_text(im, ox + 3 * CELL, oy + L * ROW, "\U000f02dc", ink)
            term_text(im, ox + 6 * CELL, oy + L * ROW, k, ink)
            term_text(im, ox + (cols - 2 - len(v)) * CELL, oy + L * ROW, v, vink)
            L += 1
    return w, h

def wallpaper(m):
    src = {"dark": "dark/cat-window-night.src", "light": "light/akahito-coast.src"}[m]
    im = Image.open(pathlib.Path.home() / ".local/share/fedokawaii/wallpapers" / src).convert("RGBA")
    return im.resize((1920, 1080), Image.LANCZOS)

for m in ("dark", "light"):
    im = wallpaper(m)
    bar(im, m)
    # two tiled windows: gaps 8 (outer, inner); their top 8 below the bar's 27
    G = 8; top = 27 + G
    lw = (1920 - 3 * G) // 2
    for i, (x0, focused) in enumerate([(G, True), (G + lw + G, False)]):
        fill(im, x0, top, x0 + lw - 1, 1080 - G - 1, P[m]["ground"], 235)
        frame(im, x0, top, x0 + lw - 1, 1080 - G - 1, m, line=P[m]["accent"] if focused else None)
    for i in range(14):
        term_text(im, G + 1 + 8, top + 1 + 8 + i * ROW, f"{i+1:3d}  local wall = theme.wallpaper(\"{m}\") -- 漢字かな ascii", P[m]["text"] if i % 3 else P[m]["muted"])
    gw, gh = gui_panel(im, 1920 - 8 - 412 - 2, top + 8, m, 8)
    tui_panel(im, G + lw + G + 40, top + 400, m, 50, 13, 1)
    im.convert("RGB").save(OUT / f"full-{m}.png")
    im.crop((0, 0, 640, 60)).resize((1920, 180), Image.NEAREST).convert("RGB").save(OUT / f"bar-left-{m}.png")
    im.crop((800, 0, 1120, 60)).resize((960, 180), Image.NEAREST).convert("RGB").save(OUT / f"bar-mid-{m}.png")
    im.crop((1500, 0, 1920, 60)).resize((1260, 180), Image.NEAREST).convert("RGB").save(OUT / f"bar-right-{m}.png")
    im.crop((1920 - 8 - 412 - 12, top - 4, 1920, top + 8 + gh + 12)).resize(((412 + 20) * 2, (gh + 24) * 2), Image.NEAREST).convert("RGB").save(OUT / f"gui-{m}.png")
    im.crop((G + lw + G + 30, top + 390, G + lw + G + 40 + 50 * 8 + 30, top + 400 + 13 * 20 + 30)).resize(((50 * 8 + 40) * 2, (13 * 20 + 40) * 2), Image.NEAREST).convert("RGB").save(OUT / f"tui-{m}.png")
print("ok", OUT)
