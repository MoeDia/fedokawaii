#!/usr/bin/env python3
"""tools/bar-options.py — the options for the bigger bar (r28 f12): each drawn pixel by pixel from the
real palette, Shinonome 16 (the next size of Sumi UI's source) and the head; icons drawn at their size,
no scaling, nothing built into waybar. The top rows are today's bar from the kit (tools/kit.sh bar).

    python3 tools/bar-options.py DARK.png LIGHT.png FONTDIR OUT.jpg
"""
import importlib.util
import io
import math
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOME = pathlib.Path.home() / ".cache/r28/kit-tree/home/.config/fedokawaii/themes"
TOP = 3                            # the air over a tile's hairline, as today


def themes():
    spec = importlib.util.spec_from_file_location("build_themes", ROOT / "tools/build-themes.py")
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(mod)
    return mod


BT = themes()


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) if isinstance(h, str) else tuple(h)


def mix(a, b, t):
    a, b = rgb(a), rgb(b)
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ── icons, at their size: a set of pixels ────────────────────────────────────────────────────────
class G(set):
    def rect(self, x0, y0, x1, y1):
        self.update((x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1))
        return self

    def box(self, x0, y0, x1, y1, t=1):
        for i in range(t):
            self.rect(x0 + i, y0 + i, x1 - i, y0 + i).rect(x0 + i, y1 - i, x1 - i, y1 - i)
            self.rect(x0 + i, y0 + i, x0 + i, y1 - i).rect(x1 - i, y0 + i, x1 - i, y1 - i)
        return self

    def ring(self, cx, cy, r, t=1, keep=lambda x, y: True):
        n = int(r + 2)
        for y in range(int(cy) - n, int(cy) + n + 2):
            for x in range(int(cx) - n, int(cx) + n + 2):
                if r - t < math.hypot(x - cx, y - cy) <= r and keep(x, y):
                    self.add((x, y))
        return self


def sun(n, t):
    c, r = (n - 1) / 2, round(n * .25) + (t - 1) * .5
    g = G().ring(c, c, r + .5, t)
    ray = max(2, n // 6)
    a, b = n // 2 - 1, n // 2
    g.rect(a, 0, b, ray - 1).rect(a, n - ray, b, n - 1).rect(0, a, ray - 1, b).rect(n - ray, a, n - 1, b)
    d = max(2, n // 7)
    for i in range(d):                 # the diagonals, a stair
        for k in range(t):
            for x, y in ((1 + i + k, 1 + i), (n - 2 - i - k, 1 + i), (1 + i + k, n - 2 - i), (n - 2 - i - k, n - 2 - i)):
                g.add((x, y))
    return g, n


def memory(n, t):
    top, bot = round(n * .14), round(n * .70)
    g = G().box(0, top, n - 1, bot, t)
    cells = 3
    w = (n - 2 * t - 2 - (cells - 1) * 2) // cells
    x = (n - (cells * w + (cells - 1) * 2)) // 2
    for i in range(cells):
        g.rect(x + i * (w + 2), top + t + 1, x + i * (w + 2) + w - 1, bot - t - 1)
    x = 1
    while x + t <= n - 1:              # the legs
        g.rect(x, bot + 1, x + t - 1, min(n - 1, bot + round(n * .22)))
        x += t + 2
    return g, n


def drive(n, t):
    top, bot = round(n * .22), n - 1 - round(n * .22)
    g = G().box(0, top, n - 1, bot, t)
    y = (top + bot) // 2
    g.rect(t + 2, y, n - t - 2 - round(n * .35), y + t - 1)
    g.rect(n - t - 2 - t, y, n - t - 3, y + t - 1)
    return g, n


def keyboard(n, t):
    top, bot = round(n * .18), n - 1 - round(n * .12)
    g = G().box(0, top, n - 1, bot, t)
    for row in (top + t + 1, top + t + 3 + t - 1):
        for x in range(t + 1, n - t - 1, t + 1 + (t > 1)):
            g.rect(x, row, x + t - 1, row + t - 1)
    g.rect(t + 3, bot - t - 1 - t + 1, n - t - 4, bot - t - 1)
    return g, n


def volume(n, t):
    w = n + n // 2 - (n // 2) % 2
    c = (n - 1) / 2
    g = G()
    h = max(2, round(n * .17))
    bx = round(n * .24)
    g.box(0, round(c - h), bx, round(c + h), t)
    cone = round(n * .28)
    for i in range(cone + 1):           # the cone, up and down from the box
        y = round(c - h) - round(i * (c - h) / cone)
        for k in range(t):
            g.add((bx + i, y + k))
            g.add((bx + i, n - 1 - y - k))
    g.rect(bx + cone, 0, bx + cone + t - 1, n - 1)
    ax = bx + cone
    for r in (n * .26, n * .42, n * .58):
        g.ring(ax + 1, c, r + .5, t, keep=lambda x, y, a=ax: x > a + t and abs(y - c) <= r * .78)
    return G(p for p in g if p[0] < w), w


def layout(n, t):
    g = G().box(0, 1, n - 1, n - 2, t)
    x = round(n * .55)
    y = n // 2
    g.rect(x, 1, x + t - 1, n - 2).rect(x, y, n - 1, y + t - 1)
    return g, n


def torii(n, t):
    g = G()
    g.rect(0, 1, n - 1, 1 + t).rect(1, 0, 1, 0).rect(n - 2, 0, n - 2, 0)   # the upturned lintel
    y = 3 + t + round(n * .08)
    g.rect(2, y, n - 3, y + t - 1)
    p = round(n * .2)
    g.rect(p, 1, p + t, n - 1).rect(n - 1 - p - t, 1, n - 1 - p, n - 1)
    g.rect(n // 2 - 1, 1, n // 2, y)
    return g, n


def sky(n, t):
    """A sun behind a cloud, its outline only; the cloud's pixels and the sun's come back apart."""
    def blob(x, y):
        return (math.hypot(x - n * .36, y - n * .63) < n * .22 or math.hypot(x - n * .66, y - n * .55) < n * .28
                or (n * .33 < x < n * .88 and n * .6 < y < n * .84))
    cloud = G((x, y) for x in range(n) for y in range(n) if blob(x, y))
    hole = G(p for p in cloud if all((p[0] + a, p[1] + b) in cloud for a in range(-t, t + 1) for b in range(-t, t + 1)))
    edge = G(cloud - hole)
    s = G().ring(n * .3, n * .28, n * .22 + .5, t)
    for p in ((n * .3, 0), (0, n * .28)):
        s.add((round(p[0]), round(p[1])))
    return edge, G(s - cloud), n


NARROW = ".:"


def ink(font, ch):
    """The columns a glyph's pixels stand on, from its pen (font.getbbox says the advance)."""
    im = Image.new("1", (32, 32), 0)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((8, 20), ch, font=font, fill=1, anchor="ls")
    l, _, r, _ = im.getbbox()
    return l - 8, r - 8


def length(font, s):
    """The line's width: the mono face's . and : take only their ink and a column either side."""
    n = 0
    for ch in s:
        if ch in NARROW:
            l, r = ink(font, ch)
            n += r - l + 1
        else:
            n += round(font.getlength(ch))
    return n


# ── the canvas ───────────────────────────────────────────────────────────────────────────────────
class Bar:
    def __init__(self, mood, o, fonts):
        self.m, self.o = mood, o
        self.p, self.k = BT.P[mood], BT.KAMI[mood]
        self.tile = rgb(BT.TILE[mood])
        self.hb = TOP + 1 + o["paper"]     # the lower hairline's row
        self.h = self.hb + 4
        self.im = Image.new("RGB", (1920, self.h + 12), rgb(self.p["ground"]))
        self.d = ImageDraw.Draw(self.im)
        self.d.fontmode = "1"
        self.f, self.fb, self.fs = fonts
        self.fibre = Image.open(io.BytesIO(BT.kami_fibre(mood, BT.TILE[mood]))).convert("RGB")

    def blend(self, x, y, c):
        if 0 <= x < 1920 and 0 <= y < self.im.height:
            if len(c) == 4:
                self.im.putpixel((x, y), mix(self.im.getpixel((x, y)), c[:3], c[3] / 255))
            else:
                self.im.putpixel((x, y), rgb(c))

    def pixels(self, g, x, y, c):
        for a, b in g:
            self.blend(x + a, y + b, rgb(c))

    def icon(self, fn, x, c, size=None, t=None):
        size, t = size or self.o["icon"], t or self.o["weight"]
        g, w = fn(size, t)
        self.pixels(g, x, TOP + 1 + (self.o["paper"] - size) // 2, c)
        return w

    def base(self):                    # a 16 px line in the middle of the paper's rows
        return TOP + 1 + (self.o["paper"] - 16) // 2 + 14

    def text(self, s, x, c, font=None):
        font = font or self.f
        start = x
        for ch in s:
            l = ink(font, ch)[0] if ch in NARROW else 0
            self.d.text((x - l, self.base()), ch, font=font, fill=rgb(c), anchor="ls")
            x += length(font, ch)
        return x - start

    def frame(self, x, w, fill=None, fibre=True):
        """The one frame (design-system §4), whatever the size: the corners left out, the shadow's
        two rows, a pixel further right each, a column at its right."""
        k, y0, y1, r = self.k, TOP, self.hb, x + w - 1
        fill = fill or self.tile
        for y in range(y0 + 1, y1):
            for a in range(x + 1, r):
                f = self.fibre.getpixel(((a - x) % 12, (y - y0) % 7)) if fibre else fill
                self.blend(a, y, f)
        for a in range(x + 1, r):
            self.blend(a, y0, k["hair"])
            self.blend(a, y1, k["hair"])
            self.blend(a, y1 + 1, k["shadow"][0])
            self.blend(a + 1, y1 + 2, k["shadow"][1])
        for y in range(y0 + 1, y1):
            self.blend(x, y, k["hair"])
            self.blend(r, y, k["hair"])
            self.blend(r + 1, y, k["shadow"][1])

    # the three clocks' ends: each draws one end, side -1 left, +1 right, x its outer column
    def rods(self, x, side):
        """1 jiku: lacquered rods twice as wide, standing two rows proud, heavy gold caps."""
        k, y0, y1 = self.k, TOP - 2, self.hb + 2
        cols = ["rod_dk", "rod", "rod_hi", "rod_hi", "rod", "rod", "rod", "rod", "rod", "rod_dk"]
        if side > 0:
            cols = cols[::-1]
        gold, hi, lo = rgb(k["gold"]), mix(k["gold"], "ffffff", .45), mix(k["gold"], k["rod_dk"], .5)
        for y in range(y0, y1 + 1):
            cap = y - y0 < 5 or y1 - y < 5
            edge = y in (y0, y1)
            for i, c in enumerate(cols):
                if edge and i in (0, 9):
                    continue
                if cap:
                    v = lo if i in (0, 9) else hi if cols[i] == "rod_hi" and y - y0 != 4 and y1 - y != 4 else gold
                    if y - y0 == 4 or y1 - y == 4:
                        v = rgb(k["rod_dk"])
                else:
                    v = rgb(k[c])
                self.blend(x + i, y, v)
        return 10

    def coil(self, x, side):
        """2 makimono: the paper rolled up at both ends, a real roll: its curl on top, lit down one
        side, tied with a vermilion cord."""
        k, y0, y1, w = self.k, TOP - 3, self.hb + 3, 16
        tile, lit = self.tile, rgb(self.p["strong"])
        dark, warm = rgb(k["rod_dk"]), rgb(k["rod"])
        low = mix(tile, warm, .4 if self.m == "light" else .7)
        top = mix(tile, lit, .8) if self.m == "light" else mix(tile, self.p["text"], .6)
        shade = [.0, .4, .75, 1, 1, 1, .95, .9, .85, .8, .7, .6, .45, .3, .15, .0]
        if side > 0:
            shade = shade[::-1]
        for y in range(y0, y1 + 1):
            for i in range(w):
                rim = abs(i - 7.5) / 8
                if y - y0 < 3 or y1 - y < 3:     # the roll's ends: an ellipse of curl
                    d = min(y - y0, y1 - y)
                    if rim > (.55, .85, 1.0)[d]:
                        continue
                v = mix(low, top, shade[i])
                if i in (0, w - 1):
                    v = mix(tile, dark, .6) if self.m == "light" else mix(low, k["hair"][:3], .6)
                self.blend(x + i, y, v)
        for y in (y0, y0 + 1, y0 + 2):           # the curl seen from above: a spiral, in the ink of the roll's shadow
            for i in range(w):
                rim = abs(i - 7.5)
                if (y == y0 + 1 and 3 <= i <= 12) or (y == y0 and 5 <= i <= 10):
                    self.blend(x + i, y, mix(tile, dark, .6))
                if y == y0 + 1 and 6 <= i <= 9:
                    self.blend(x + i, y, mix(tile, lit, .55))
                if y == y0 + 2 and (i == 1 or i == 14):
                    self.blend(x + i, y, mix(tile, dark, .4))
        c = (y0 + y1) // 2                       # the cord
        red, redhi = rgb(self.k["red"]), rgb(self.p["accent_hi"])
        for y in range(c - 2, c + 3):
            for i in range(w):
                self.blend(x + i, y, redhi if y == c - 2 else mix(red, dark, .35) if y == c + 2 else red)
        for y in range(c - 3, c + 4):            # the knot on the roll's lit side
            for a in range(2):
                self.blend(x + 5 + a, y, rgb(k["gold"]) if a == 0 else mix(rgb(k["gold"]), dark, .4))
        return w

    def knob(self, x, side):
        """3 jikusaki: a rod with turned finials through the whole height of the bar, a brocade band
        (ichimonji) between it and the paper."""
        k, y0, y1 = self.k, TOP - 3, self.hb + 3
        rod_w = 12
        prof = (8, 12, 12, 8, 6, 12, 6)          # the turned end, from its tip inwards
        dark, gold = rgb(k["rod_dk"]), rgb(k["gold"])
        hi = mix(gold, "ffffff", .5)
        lo = mix(gold, dark, .55)
        for y in range(y0, y1 + 1):
            d = min(y - y0, y1 - y)
            if d < len(prof):
                wid = prof[d]
                for i in range((rod_w - wid) // 2, (rod_w + wid) // 2):
                    t = i - (rod_w - wid) // 2
                    v = lo if t in (0, wid - 1) else hi if t == 2 or (d == 0 and t == 3) else gold
                    self.blend(x + i, y, v)
            else:
                cols = [0, 0, "rod_dk", "rod", "rod_hi", "rod_hi", "rod", "rod", "rod", "rod_dk", 0, 0]
                for i, c in enumerate(cols):
                    if c:
                        self.blend(x + i, y, rgb(k[c]))
        return rod_w

    def brocade(self, x, w):
        k, red, dark = self.k, rgb(self.p["lacquer"]), rgb(self.k["rod_dk"])
        gold = rgb(k["gold"])
        for y in range(TOP, self.hb + 1):
            for i in range(w):
                on = (i + y * 3) % 6 == 0 and (y % 2 == 0)
                edge = y in (TOP, self.hb)
                self.blend(x + i, y, gold if edge or i in (0, w - 1) or on else red)
        for i in range(w):
            self.blend(x + i, self.hb + 1, k["shadow"][0])
            self.blend(x + i + 1, self.hb + 2, k["shadow"][1])


def draw(mood, o, fonts):
    global TOP
    TOP = o["top"]
    b = Bar(mood, o, fonts)
    p, k = b.p, b.k
    pad, gap, grp = o["pad"], 4, 12
    x = 8
    # the left end: the torii on vermilion
    w = o["emblem"] + pad * 2
    b.frame(x, w, rgb(k["red"]), fibre=False)
    g, _ = torii(o["emblem"], o["weight"])
    b.pixels(g, x + pad, TOP + 1 + (o["paper"] - o["emblem"]) // 2, p["text_on_accent"])
    x += w + grp
    # the workspaces
    for i, ch in enumerate("一二三"):
        w = o["seal"] + 8 if i == 0 else 16 + pad * 2
        b.frame(x, w)
        if i == 0:
            d = o["seal"]
            sx, sy, r = x + (w - d) // 2, TOP + 1 + (o["paper"] - d) // 2, d / 2
            for a in range(d):
                for c in range(d):
                    if (a + .5 - r) ** 2 + (c + .5 - r) ** 2 <= r * r:
                        b.blend(sx + a, sy + c, rgb(k["red"]))
            b.text(ch, x + (w - 16) // 2, p["text_on_accent"], b.fb)
        else:
            b.text(ch, x + pad, p["text"] if i == 1 else p["faint"])
        x += w + gap
    x += grp - gap
    # the layout's mark and the window's name
    title = "nvim  r28-plan.tsv"
    w = pad + o["icon"] + pad + length(b.f, title) + pad
    b.frame(x, w)
    b.icon(layout, x + pad, p["muted"])
    b.text(title, x + pad + o["icon"] + pad, p["text"])

    # the right end: from the screen's edge in
    x = 1920 - 8
    face = Image.open(HOME / mood / o["face"]).convert("RGBA")
    w = face.width + 8
    x -= w
    b.frame(x, w)
    b.im.paste(face, (x + 4, TOP + 1 + (o["paper"] - face.height) // 2), face)
    x -= grp
    mods = [("sky", "24°"), (sun, "85%"), (volume, "40%"), (memory, "3.0G"), (keyboard, "EN"), (drive, "2")]
    for fn, val in mods:
        tw = length(b.f, val)
        if fn == "sky":
            n = o["icon"]
            w = pad + n + pad + tw + pad
            x -= w
            b.frame(x, w)
            cloud, s, _ = sky(n, o["weight"])
            top = TOP + 1 + (o["paper"] - n) // 2
            b.pixels(s, x + pad, top, p["gold"])
            b.pixels(cloud, x + pad, top, p["text"])
            b.text(val, x + pad + n + pad, p["text"])
        else:
            iw = fn(o["icon"], o["weight"])[1]
            w = pad + iw + pad + tw + pad
            x -= w
            b.frame(x, w)
            b.icon(fn, x + pad, p["muted"])
            b.text(val, x + pad + iw + pad, p["text"])
        x -= gap

    # the middle: the day's kanji on the screen's middle
    day = 960 - 8
    date = "06/11/2026"
    air = o["clockair"]
    dw = length(b.f, date)
    if o["ends"] == "knob":
        hm, sec, ampm = "11:57", ":23", " AM"
        big = ImageFont.truetype(str(fonts[2].path), 14)
        tmp = Image.new("1", (round(big.getlength(hm)), 16), 0)
        td = ImageDraw.Draw(tmp)
        td.fontmode = "1"
        td.text((0, 13), hm, font=big, fill=1, anchor="ls")
        hmw = tmp.width * 2
        sw = length(b.f, sec + ampm)
        tw = hmw + 2 + sw
    else:
        tw = length(b.f, "11:57:23 AM")
    if o["ends"] == "knob":                        # the scroll on the middle; its words evenly apart
        total = dw + 16 + tw + air * 4
        total += total % 2                         # an even width: its middle on the screen's
        x0 = 960 - total // 2
        x1 = x0 + total
        day = x0 + air * 2 + dw
    else:                                          # the kanji on the middle, the two sides level
        side = max(dw, tw)
        x0 = day - air - side - air
        x1 = day + 16 + air + side + air
    end = {"rods": 10, "coil": 16, "knob": 12}[o["ends"]]
    band = 10 if o["ends"] == "knob" else 0
    b.frame(x0 - band - 1, x1 - x0 + 2 * band + 2)
    if band:
        b.brocade(x0 - band, band)
        b.brocade(x1, band)
    fn = {"rods": b.rods, "coil": b.coil, "knob": b.knob}[o["ends"]]
    fn(x0 - band - end, -1)
    fn(x1 + band, 1)
    if o["ends"] == "coil":                        # the rolls' shadow on the paper
        for y in range(TOP + 1, b.hb):
            for a, t in ((0, 90), (1, 45)):
                b.blend(x0 + a, y, rgb(k["rod_dk"]) + (t,))
                b.blend(x1 - 1 - a, y, rgb(k["rod_dk"]) + (t,))
    b.text(date, day - air - dw, p["text"])
    b.text("金", day, p["accent_text"], b.fb)
    tx = day + 16 + air
    if o["ends"] == "knob":
        big2 = tmp.resize((tmp.width * 2, tmp.height * 2), Image.NEAREST)
        y = TOP + 1 + (o["paper"] - big2.height) // 2 + 1
        b.im.paste(rgb(p["strong"]), (tx, y), big2.convert("L"))
        b.text(sec, tx + hmw + 2, p["accent_text"])
        b.text(ampm, tx + hmw + 2 + length(b.f, sec), p["muted"])
    else:
        b.text("11:57:23 AM", tx, p["text"])
    b.ends = (x0 - band - end, x1 + band + end)
    return b


OPTIONS = (
    {"name": "jiku", "top": 3, "paper": 24, "icon": 16, "weight": 1, "emblem": 20, "seal": 20, "pad": 8, "clockair": 16, "ends": "rods", "face": "face.png"},
    {"name": "makimono", "top": 4, "paper": 26, "icon": 18, "weight": 1, "emblem": 22, "seal": 22, "pad": 9, "clockair": 16, "ends": "coil", "face": "face.png"},
    {"name": "jikusaki", "top": 4, "paper": 30, "icon": 20, "weight": 2, "emblem": 24, "seal": 26, "pad": 10, "clockair": 18, "ends": "knob", "face": "head-32.png"},
)


def main(dark, light, fontdir, out):
    fd = pathlib.Path(fontdir)
    fonts = (ImageFont.truetype(str(fd / "JF-Dot-Shinonome16.ttf"), 16),
             ImageFont.truetype(str(fd / "JF-Dot-Shinonome16B.ttf"), 16),
             ImageFont.truetype(str(fd / "JF-Dot-Shinonome14.ttf"), 14))
    rows = [Image.open(dark).convert("RGB").crop((0, 0, 1920, 31)), Image.open(light).convert("RGB").crop((0, 0, 1920, 31))]
    zooms = []
    for o in OPTIONS:
        bars = {m: draw(m, o, fonts) for m in ("dark", "light")}
        rows += [bars["dark"].im, bars["light"].im]
        h = bars["dark"].h
        # three times: the scroll's left end dark, its right end light; twice: the tiles at each end
        left, right = bars["dark"].ends
        row = Image.new("RGB", (1920, h * 3))
        row.paste(bars["dark"].im.crop((left - 6, 0, left + 314, h)).resize((960, h * 3), Image.NEAREST), (0, 0))
        row.paste(bars["light"].im.crop((right - 314, 0, right + 6, h)).resize((960, h * 3), Image.NEAREST), (960, 0))
        zooms.append(row)
        row = Image.new("RGB", (1920, h * 2))
        row.paste(bars["dark"].im.crop((0, 0, 480, h)).resize((960, h * 2), Image.NEAREST), (0, 0))
        row.paste(bars["light"].im.crop((1440, 0, 1920, h)).resize((960, h * 2), Image.NEAREST), (960, 0))
        zooms.append(row)
    total = sum(r.height + 2 for r in rows + zooms)
    sheet = Image.new("RGB", (1920, total), (0, 0, 0))
    y = 0
    for r in rows + zooms:
        sheet.paste(r, (0, y))
        y += r.height + 2
    for q in range(88, 59, -2):                    # the page takes 300 KB
        sheet.save(out, quality=q, subsampling=0, optimize=True)
        if pathlib.Path(out).stat().st_size < 299_000:
            break
    print(out, sheet.size, q, pathlib.Path(out).stat().st_size)


if __name__ == "__main__":
    main(*sys.argv[1:5])
