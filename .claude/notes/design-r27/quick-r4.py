#!/usr/bin/env python3
"""Quick settings, round four (owner 2026-10-31 23:23: from scratch, no earlier layout, super
minimal, super creative) — three directions, both moods, at 1x with the real faces (Sumi UI 14,
Sumi Icons), the Wada palette and the drawn pictures. Sketches, not a deliverable.
   python3 -I quick-r4.py REPO OUTDIR"""
import importlib.util, math, pathlib, re, sys
from PIL import Image, ImageDraw, ImageFont

REPO, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location("wp", REPO / "tools/wada-palette.py")
wp = importlib.util.module_from_spec(spec); spec.loader.exec_module(wp)
P, KAMI, TILE, _ = wp.palette()
UI = ImageFont.truetype("/usr/local/share/fonts/fedokawaii/SumiUI.ttf", 14)
IC = ImageFont.truetype(str(pathlib.Path.home() / ".local/share/fonts/SumiIcons.ttf"), 14)
CRESTS = pathlib.Path.home() / ".local/share/fedokawaii/crests"
ICONS = {}
for line in (REPO / "configs/home/.config/fedokawaii/icons.sh").read_text().splitlines():
    m = re.match(r"ICON_(\w+)=\$'((?:\\x[0-9a-f]{2})+)'", line)
    if m:
        ICONS[m.group(1).lower()] = bytes(int(h, 16) for h in m.group(2).split("\\x")[1:]).decode()

def items(m):
    dark = m == "dark"
    return [("theme", "moon" if dark else "sun", "tile_moon" if dark else "tile_sun", "theme", "dark" if dark else "light", True),
            ("night", "lantern", "tile_lantern", "night light", "off", False),
            ("vrr", "wave", "tile_wave", "freesync", "games · off", False),
            ("network", "ethernet", "tile_ethernet", "network", "wired", True),
            ("bluetooth", "bluetooth", "tile_bluetooth", "bluetooth", "off", False),
            ("devices", "devices", "tile_devices", "devices", "none", False),
            ("drives", "drive", "tile_drive", "drives", "none", False),
            ("backup", "backup", "tile_backup", "backup", "not set up", False),
            ("dnd", "bell", "tile_bell", "dnd", "off", False),
            ("saver", "saver", "tile_saver", "screensaver", "15 min", True),
            ("record", "record", "tile_record", "record", "off", False),
            ("ocr", "read", "tile_read", "read text", "a region", False)]
ACTS = [("wallpaper", "picture", "wallpaper"), ("screenshot", "camera", "screenshot"),
        ("screenoff", "screen_off", "screen off"), ("power", "power", "power")]
BRI, SND = 70, 45


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def text(d, x, y, s, col, font=UI, centre=False, right=False):
    """s on a 20 px row whose top is y (the em on the row's rows 3-16)."""
    w = int(font.getlength(s))
    if centre:
        x -= w // 2
    if right:
        x -= w
    d.text((x, y + 2), s, font=font, fill=rgb(col))
    return w

def box(d, x, y, w, h, col):
    d.rectangle((x, y, x + w - 1, y + h - 1), fill=rgb(col))

def crest(im, x, y, name, col, scale=1):
    mask = Image.open(CRESTS / f"{name}.png").getchannel("A")
    if scale != 1:
        mask = mask.resize((mask.width * scale, mask.height * scale), Image.NEAREST)
    im.paste(Image.new("RGB", mask.size, rgb(col)), (x, y), mask)

def face(im, x, y, m, scale=1):
    f = Image.open(REPO / f"configs/home/.config/fedokawaii/themes/{m}/face-open.png").convert("RGBA")
    if scale != 1:
        f = f.resize((f.width * scale, f.height * scale), Image.NEAREST)
    im.paste(f, (x, y), f)

def panel(m, w, h):
    """The frame (§4) round content w x h: pad 16, the hairline (corners out), the shadow."""
    p, k = P[m], KAMI[m]
    W, H = w + 34, h + 34
    im = Image.new("RGB", (W + 40, H + 40), (96, 96, 96))
    d = ImageDraw.Draw(im); d.fontmode = "1"
    ox, oy = 20, 20
    box(d, ox, oy, W, H, p["ground"])
    hair = tuple(int(c * k["hair"][3] / 255 + rgb(p["ground"])[i] * (1 - k["hair"][3] / 255)) for i, c in enumerate(k["hair"][:3]))
    hx = "%02x%02x%02x" % hair
    box(d, ox + 1, oy, W - 2, 1, hx); box(d, ox + 1, oy + H - 1, W - 2, 1, hx)
    box(d, ox, oy + 1, 1, H - 2, hx); box(d, ox + W - 1, oy + 1, 1, H - 2, hx)
    return im, d, ox + 17, oy + 17


# ── A · 時計 the dial: the twelve pictures on the hours of a wadokei; the minute marks are the
# two meters (brightness rising up the left, sound up the right); the four actions in the
# corners (the mandala's four guardians); the centre is the face at rest, else the item the
# cursor is on — its picture twice as large, its name, its state.
def dial(m, cur=None):
    p = P[m]
    W, H = 376, 376
    im, d, x0, y0 = panel(m, W, H)
    cx, cy = x0 + W // 2, y0 + H // 2
    R = 164
    its = items(m)
    for k, (key, pic, _, name, state, on) in enumerate(its):
        a = math.radians(30 * k)
        px, py = cx + round(R * math.sin(a)), cy - round(R * math.cos(a))
        if cur == k:
            box(d, px - 18, py - 17, 36, 34, p["select"]); box(d, px - 17, py - 18, 34, 36, p["select"])
            crest(im, px - 14, py - 14, pic, p["text_on_select"])
        else:
            crest(im, px - 14, py - 14, pic, p["accent"] if on else p["muted"])
    # the minute marks: 20 a side, from the bottom up; a 4 px square each
    for side, pct in ((-1, BRI), (1, SND)):
        lit = pct // 5
        for i in range(20):
            a = math.radians(180 - (16 + i * 148 / 19))
            r = 122
            tx, ty = cx + side * round(r * math.sin(a)), cy - round(r * math.cos(a))
            colr = (p["accent"] if i >= 18 else p["flame"] if i >= 16 else p["asagi"]) if i < lit else p["edge2"]
            box(d, tx - 2, ty - 2, 4, 4, colr)
    text(d, cx - 70 - 7, cy + 104, ICONS["bri_3"], p["muted"], IC)
    text(d, cx + 70 - 7, cy + 104, ICONS["vol_2"], p["muted"], IC)
    for (key, ic, name), (ax, ay) in zip(ACTS, ((x0, y0), (x0 + W - 14, y0), (x0, y0 + H - 20), (x0 + W - 14, y0 + H - 20))):
        text(d, ax, ay - 3, ICONS[ic], p["muted"], IC)
    if cur is None:
        face(im, cx - 27, cy - 27, m, 3)
    else:
        key, pic, _, name, state, on = its[cur]
        crest(im, cx - 28, cy - 50, pic, p["accent"] if on else p["text"], 2)
        text(d, cx, cy + 12, name, p["strong"], centre=True)
        text(d, cx, cy + 32, state, p["strong"] if on else p["muted"], centre=True)
    return im


# ── B · 算盤 the soroban: a rod per switch, its one bead up (off) or down on the beam (on), the
# picture over its rod; the meters two wires of twenty beads; the item under the cursor named
# under the frame; the actions a quiet row at the foot.
def bead(d, x, y, w, h, col):
    mid = (h - 1) / 2
    for r in range(h):
        ww = w - 2 * round(abs(r - mid) * (w * 0.32) / mid)
        box(d, x + (w - ww) // 2, y + r, ww, 1, col)

def soroban(m, cur=None):
    p, k = P[m], KAMI[m]
    W = 376
    its = items(m)
    H = 20 + 8 + 80 + 8 + 40 + 16 + 40 + 16 + 20
    im, d, x0, y0 = panel(m, W, H)
    y = y0
    for i, (key, name, pct, ic) in enumerate((("brightness", "brightness", BRI, "bri_3"), ("sound", "sound", SND, "vol_2"))):
        ry = y + i * 20
        text(d, x0 + 8, ry, ICONS[ic], p["muted"], IC)
        text(d, x0 + 32, ry, name, p["text"])
        box(d, x0 + W - 168, ry + 10, 168, 1, k["rod"])
        lit = pct // 5
        for s in range(20):
            colr = (p["accent"] if s >= 18 else p["flame"] if s >= 16 else p["asagi"]) if s < lit else p["edge2"]
            sx = x0 + W - 168 + s * 8 + (0 if s < lit else 8)
            bead(d, sx, ry + 6, 7, 9, colr)
    y += 40 + 16
    col = 30
    left = x0 + (W - 12 * col) // 2
    # the frame: top rail, the beam (the reckoning bar), the rods
    top, beam = y + 24, y + 24 + 50
    box(d, left - 4, top, 12 * col + 8, 4, k["rod"]); box(d, left - 4, top, 12 * col + 8, 1, k["rod_hi"])
    box(d, left - 4, beam, 12 * col + 8, 4, k["rod"]); box(d, left - 4, beam, 12 * col + 8, 1, k["rod_hi"])
    for c, (key, pic, ic, name, state, on) in enumerate(its):
        rx = left + c * col + col // 2
        if cur == c:
            box(d, rx - 14, y - 2, 28, beam + 6 - y + 2, p["select"])
        text(d, rx - 7, y - 3, ICONS[ic], p["text_on_select"] if cur == c else p["accent"] if on else p["muted"], IC)
        box(d, rx - 1, top + 4, 2, beam - top - 4, k["rod_hi"] if cur != c else p["select_lo"])
        by = beam - 12 if on else top + 4
        bead(d, rx - 11, by, 22, 12, p["text_on_select"] if cur == c else p["accent"] if on else k["rod_hi"])
    y = beam + 4 + 12
    if cur is not None:
        _, _, _, name, state, on = its[cur]
        w = text(d, x0 + W // 2 - 4, y, name, p["strong"], right=True)
        text(d, x0 + W // 2 + 4, y, state, p["strong"] if on else p["muted"])
    y += 20 + 16
    for c, (key, ic, name) in enumerate(ACTS):
        cx = x0 + c * 94 + 47
        text(d, cx - 7, y, ICONS[ic], p["muted"], IC)
        text(d, cx, y + 20, name, p["text"], centre=True)
    return im


# ── C · 琴 the koto: every item a string; a switch's bridge stands at the string's left (off)
# or its right (on, the string lit up to it); a meter's bridge at its level; ← → move the bridge.
def ji(d, x, y, col):
    rows = ["....#....", "...###...", "..#####..", "..##.##..", ".##...##.", "##.....##"]
    for r, s in enumerate(rows):
        for c, ch in enumerate(s):
            if ch == "#":
                box(d, x + c, y + r, 1, 1, col)

def koto(m, cur=None):
    p, k = P[m], KAMI[m]
    W = 376
    its = items(m)
    H = 14 * 20 + 16 + 20
    im, d, x0, y0 = panel(m, W, H)
    s0, s1 = x0 + 128, x0 + W
    rows = [("brightness", "bri_3", "brightness", BRI, None), ("sound", "vol_2", "sound", SND, None)]
    rows += [(key, ic, name, state, on) for key, _, ic, name, state, on in its]
    for i, (key, ic, name, v, on) in enumerate(rows):
        ry = y0 + i * 20 + (8 if i >= 2 else 0)
        sel = cur == i
        if sel:
            box(d, x0 - 8, ry, W + 16, 20, p["select"])
        t = lambda c: p["text_on_select"] if sel else c
        text(d, x0 + 8, ry, ICONS[ic], t(p["accent"] if on else p["muted"]), IC)
        text(d, x0 + 32, ry, name, t(p["text"]))
        if on is None:                                    # a meter: the bridge at its level
            bx = s0 + round((s1 - s0 - 9) * v / 100)
            for x in range(s0, bx):
                f = (x - s0) / (s1 - s0)
                box(d, x, ry + 10, 1, 2, t(p["accent"] if f >= .9 else p["flame"] if f >= .8 else p["asagi"]))
            box(d, bx + 9, ry + 10, s1 - bx - 9, 1, t(p["edge2"]))
            ji(d, bx, ry + 5, t(p["text"]))
        else:
            bx = s1 - 9 if on else s0
            if on:
                box(d, s0, ry + 10, bx - s0, 2, t(p["accent"]))
            else:
                box(d, bx + 9, ry + 10, s1 - bx - 9, 1, t(p["edge2"]))
            ji(d, bx, ry + 5, t(p["accent"] if on else p["muted"]))
    y = y0 + 14 * 20 + 8 + 16 - 8
    for c, (key, ic, name) in enumerate(ACTS):
        cx = x0 + c * 94 + 47
        text(d, cx - 4 - int(UI.getlength(name)) // 2 - 7, y, ICONS[ic], p["muted"], IC)
        text(d, cx + 8, y, name, p["text"], centre=True)
    return im


def pair(fn, name, cur):
    a = [fn("dark", None), fn("dark", cur), fn("light", None), fn("light", cur)]
    W = sum(i.width for i in a); H = max(i.height for i in a)
    out = Image.new("RGB", (W, H), (96, 96, 96))
    x = 0
    for i in a:
        out.paste(i, (x, 0)); x += i.width
    out.save(OUT / f"quick-r4-{name}.png")
    out.resize((W * 2, H * 2), Image.NEAREST).save(OUT / f"quick-r4-{name}-2x.png")


pair(dial, "A-dial", 1)
pair(soroban, "B-soroban", 1)
pair(koto, "C-koto", 3)


# ── A, refined: the hours in their final order, a smaller dial, the meters as beads, the
# actions as 28 px pictures (their 14 px icons drawn twice as large: the 2 px stroke of the hours)
ORDER = ["theme", "night", "vrr", "saver", "dnd", "network", "bluetooth", "devices", "drives", "backup", "record", "ocr"]
CORNERS = [("screenshot", "camera"), ("wallpaper", "picture"), ("screenoff", "screen_off"), ("power", "power")]

def icon2(im, x, y, ch, col, scale=2):
    """a 14 px icon drawn scale times as large, its 14 px box at x, y (scaled)."""
    t = Image.new("L", (14, 20), 0)
    dd = ImageDraw.Draw(t); dd.fontmode = "1"
    dd.text((0, 2), ch, font=IC, fill=255)
    t = t.crop((0, 3, 14, 17)).resize((14 * scale, 14 * scale), Image.NEAREST)
    im.paste(Image.new("RGB", t.size, rgb(col)), (x, y), t)

def dot(d, x, y, n, col):
    box(d, x + 1, y, n - 2, n, col); box(d, x, y + 1, n, n - 2, col)

def dial2(m, cur=None, S=304, R=128, rm=None, beads=6, corners2=True):
    p = P[m]
    im, d, x0, y0 = panel(m, S, S)
    c = S // 2
    cx, cy = x0 + c, y0 + c
    byk = {it[0]: it for it in items(m)}
    its = [byk[k] for k in ORDER]
    rm = rm or R - 40
    pos = []
    for k, (key, pic, _, name, state, on) in enumerate(its):
        a = math.radians(30 * k)
        px, py = cx + round(R * math.sin(a)), cy - round(R * math.cos(a))
        pos.append((px, py))
        if cur == k:
            box(d, px - 18, py - 17, 36, 34, p["select"]); box(d, px - 17, py - 18, 34, 36, p["select"])
        crest(im, px - 14, py - 14, pic, p["text_on_select"] if cur == k else p["accent"] if on else p["muted"])
    for i, (side, pct) in enumerate(((-1, BRI), (1, SND))):
        lit = pct // 5
        sel = cur == ("bri", "snd")[i]
        for j in range(20):
            a = math.radians(180 - (22 + j * 136 / 19))
            tx, ty = cx + side * round(rm * math.sin(a)), cy - round(rm * math.cos(a))
            if sel:
                dot(d, tx - beads // 2 - 2, ty - beads // 2 - 2, beads + 4, p["select"])
            colr = (p["text_on_select"] if sel else p["accent"] if j >= 18 else p["flame"] if j >= 16 else p["asagi"]) if j < lit else (p["select_lo"] if sel else p["edge2"])
            dot(d, tx - beads // 2, ty - beads // 2, beads, colr)
    for (key, ic), (ax, ay) in zip(CORNERS, ((x0, y0), (x0 + S - 28, y0), (x0, y0 + S - 28), (x0 + S - 28, y0 + S - 28))):
        if corners2:
            icon2(im, ax, ay, ICONS[ic], p["muted"])
        else:
            text(d, ax, ay - 3, ICONS[ic], p["muted"], IC)
    if cur is None:
        face(im, cx - 27, cy - 27 - 4, m, 3)
    elif cur in ("bri", "snd"):
        name, v, ic = ("brightness", BRI, "bri_3") if cur == "bri" else ("sound", SND, "vol_2")
        icon2(im, cx - 14, cy - 34, ICONS[ic], p["text"])
        text(d, cx, cy + 4, name, p["strong"], centre=True)
        text(d, cx, cy + 24, f"{v} %", p["strong"], centre=True)
    else:
        key, pic, _, name, state, on = its[cur]
        crest(im, cx - 28, cy - 46, pic, p["accent"] if on else p["text"], 2)
        text(d, cx, cy + 14, name, p["strong"], centre=True)
        text(d, cx, cy + 34, state, p["strong"] if on else p["muted"], centre=True)
    return im

def strip(name, ims):
    W = sum(i.width for i in ims); H = max(i.height for i in ims)
    out = Image.new("RGB", (W, H), (96, 96, 96))
    x = 0
    for i in ims:
        out.paste(i, (x, 0)); x += i.width
    out.save(OUT / f"quick-r4-{name}.png")
    out.resize((W * 2, H * 2), Image.NEAREST).save(OUT / f"quick-r4-{name}-2x.png")

strip("A2-dial", [dial2("dark"), dial2("dark", 1), dial2("dark", "snd"), dial2("light"), dial2("light", 1), dial2("light", "snd")])
strip("A2-big", [dial2("dark", None, 376, 164), dial2("light", 4, 376, 164)])
