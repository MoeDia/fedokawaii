#!/usr/bin/env python3
"""tools/power-options.py — the options for the power menu (r28 f13): three layouts, drawn pixel by pixel
from the real palette, Sumi UI, the heads and the five seal pictures of panel-art.txt; nothing built into
kawa-panel. The top row is today's dialog from the kit (its shots, as tools/regress/power-dialog.sh plays it).

    python3 tools/power-options.py DARK.png LIGHT.png OUT.jpg
"""
import importlib.util
import math
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("build_themes", ROOT / "tools/build-themes.py")
BT = importlib.util.module_from_spec(spec)
spec.loader.exec_module(BT)

ACTIONS = [("t-lock", "lock", 0), ("t-sleep", "sleep", 0), ("t-logout", "log out", 1), ("t-restart", "restart", 0), ("t-off", "shut down", 5)]
CHIPS = ((16, 0), (17, 0), (47, 1), (0, 25), (1, 42), (63, 14), (62, 46), (63, 47), (34, 63), (35, 62))      # (bin/kawa-panel)
UP = "up 11h 52m"
CELL = (472, 400)
PAPER = {"dark": "181715", "light": "e5e0bf"}      # (today's dialog, measured in the kit)
HAIR = {"dark": "7e725b", "light": "262c29"}
BACK = {"dark": "141515", "light": "918f7c"}       # (the desktop under the dim)
FONT = ImageFont.truetype("/usr/local/share/fonts/fedokawaii/SumiUI.ttf", 14)
TEXT_H = 14


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) if isinstance(h, str) else tuple(h)


def mix(a, b, t):
    a, b = rgb(a), rgb(b)
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def blocks(path):
    """@name rows: the seal pictures of panel-art.txt, the heads of heads.txt (the right half its mirror)."""
    out, name = {}, None
    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("@"):
            name = line[1:].split()[0]
            out[name] = []
        elif not line.strip() or line.startswith("#"):
            name = None
        elif name:
            out[name].append(line)
    return out


ART = blocks(ROOT / "configs/home/.config/fedokawaii/panel-art.txt")
HEADS = blocks(ROOT / "art/heads.txt")


class Canvas:
    def __init__(self, mood, w=CELL[0], h=CELL[1]):
        self.m, self.p = mood, BT.P[mood]
        self.paper = rgb(PAPER[mood])
        self.im = Image.new("RGB", (w, h), rgb(BACK[mood]))
        self.d = ImageDraw.Draw(self.im)
        self.d.fontmode = "1"

    def c(self, name):
        return rgb(self.p[name]) if isinstance(name, str) and name in self.p else rgb(name)

    def box(self, x, y, w, h, c):
        self.d.rectangle((x, y, x + w - 1, y + h - 1), fill=self.c(c))

    def stepped(self, x, y, w, h, c, n=2):
        """A rectangle with its corners stepped (n rows of steps)."""
        for i in range(n + 1):
            self.box(x + n - i, y + i, w - 2 * (n - i), h - 2 * i, c)

    def frame(self, x, y, w, h, fill=None):
        self.box(x, y, w, h, HAIR[self.m])
        self.box(x + 1, y + 1, w - 2, h - 2, fill or self.paper)

    def pic(self, name, x, y, ink):
        ink = self.c(ink)
        for j, row in enumerate(ART[name]):
            for i, ch in enumerate(row):
                if ch == "#":
                    self.im.putpixel((x + i, y + j), ink)

    def head(self, name, x, y):
        p = self.p
        ink = {"K": "111314", "#": "111314", "R": p["accent"], "D": p["accent_lo"], "W": "f5ecc2", "P": "f8f3d8"}
        for j, row in enumerate(HEADS[name]):
            for i, ch in enumerate(row):
                if ch in ink:
                    self.im.putpixel((x + i, y + j), rgb(ink[ch]))
                    self.im.putpixel((x + 2 * len(row) - 1 - i, y + j), rgb(ink[ch]))

    def text(self, s, x, base, c):
        self.d.text((x, base), s, font=FONT, fill=self.c(c), anchor="ls")

    def centre(self, s, cx, base, c):
        self.text(s, cx - round(FONT.getlength(s)) // 2, base, c)

    def accel(self, s, i, x, base, c):
        """The word's key: one rule under its letter."""
        a = round(FONT.getlength(s[:i]))
        b = round(FONT.getlength(s[:i + 1]))
        self.box(x + a, base + 2, b - a - 1, 1, c)

    def disc(self, cx, cy, r, c, keep=None):
        ink = self.c(c)
        n = int(r) + 2
        for y in range(int(cy) - n, int(cy) + n + 1):
            for x in range(int(cx) - n, int(cx) + n + 1):
                if math.hypot(x - cx, y - cy) <= r and (keep is None or keep(x, y)):
                    self.im.putpixel((x, y), ink)


def tile(g, x, y, name, state):
    """Today's seal, 64 square, its rim and chips (design-system §4)."""
    S = 64
    fill = {"rest": "key", "on": "accent", "asked": "accent_hi"}[state]
    g.stepped(x, y, S, S, fill)
    if state == "rest":
        for dx, dy, w, h in ((3, 0, S - 6, 2), (3, S - 2, S - 6, 2), (0, 3, 2, S - 6), (S - 2, 3, 2, S - 6),
                             (2, 1, 2, 2), (S - 4, 1, 2, 2), (1, 2, 2, 2), (S - 3, 2, 2, 2),
                             (2, S - 3, 2, 2), (S - 4, S - 3, 2, 2), (1, S - 4, 2, 2), (S - 3, S - 4, 2, 2)):
            g.box(x + dx, y + dy, w, h, "edge2")
    for dx, dy in CHIPS:
        g.box(x + dx, y + dy, 1, 1, g.paper)
    g.pic(name, x + 12, y + 12, "text_on_accent" if state != "rest" else "muted")


# ── 1 jiku: the row kept, on a scroll between two rods; what cannot be undone stands apart ───────
def rod(g, x, y, h):
    p = g.p
    if g.m == "dark":
        bands = [p["lo"], p["accent_lo"], p["lacquer"], mix(p["lacquer"], p["accent_hi"], .45), p["lacquer"], p["accent_lo"], p["lo"]]
    else:
        bands = [p["art_ink"], p["art_umber"], p["art_olive"], mix(p["art_olive"], p["hi"], .4), p["art_olive"], p["art_umber"], p["art_ink"]]
    widths = [1, 2, 3, 2, 3, 2, 1]
    a = x
    for c, w in zip(bands, widths, strict=False):
        g.box(a, y, w, h, c)
        a += w
    gold, deep = g.c("gold"), mix(g.c("gold"), p["lo"] if g.m == "dark" else p["art_ink"], .45)
    for top in (y - 8, y + h):                     # the caps: a ring, then a knob one narrower
        g.box(x, top + (0 if top < y else 4), 14, 4, gold)
        g.box(x + 2, top + (4 if top < y else 0), 10, 4, deep)
        g.box(x + 5, top + (0 if top < y else 4), 4, 4, mix(gold, "ffffff", .3))


def jiku(g, on, asked):
    W, H = 430, 140
    x0, y0 = (CELL[0] - W - 28) // 2, 24
    rod(g, x0, y0 + 2, H - 4)
    rod(g, x0 + W + 14, y0 + 2, H - 4)
    g.frame(x0 + 14, y0, W, H)
    g.box(x0 + 15, y0 + 1, 2, H - 2, "gold")                       # the silk's edges
    g.box(x0 + W + 11, y0 + 1, 2, H - 2, "gold")
    x, y = x0 + 14 + 23, y0 + 14
    gaps = [12, 12, 28, 12]
    xs = []
    for i in range(5):
        xs.append(x)
        x += 64 + (gaps[i] if i < 4 else 0)
    rec = mix(g.paper, g.p["accent_lo"], .26 if g.m == "dark" else .12)      # the recess under restart and shut down
    g.stepped(xs[3] - 8, y - 6, 64 * 2 + 12 + 16, 64 + 6 + 28, rec)
    for i, (pic, word, k) in enumerate(ACTIONS):
        st = "asked" if asked == i else "on" if on == i else "rest"
        tile(g, xs[i], y, pic, st)
        w = round(FONT.getlength(word))
        tx = xs[i] + (64 - w) // 2
        ink = "strong" if st != "rest" else "text"
        g.text(word, tx, y + 64 + 16, ink)
        g.accel(word, k, tx, y + 64 + 16, "accent_text")
    base = y0 + H - 12
    cx = x0 + 14 + W // 2
    if asked is not None:
        g.centre("press again to " + ACTIONS[asked][1], cx, base, "strong")
    else:
        g.centre(UP, cx, base, "muted")
    return x0, y0, W + 28, H


# ── 2 tanzaku: a poem slip beside a list; the same rows and keys as every other menu ─────────────
def tanzaku(g, on, asked):
    BAND, ROW, W = 44, 46, 344
    H = ROW * 5 + 10 + 35
    x0, y0 = (CELL[0] - W) // 2, 20
    g.frame(x0, y0, W, H)
    band = mix(g.p["lacquer"], g.p["lo"], .25) if g.m == "dark" else mix(g.p["bblue"], g.p["text"], .45)
    g.box(x0 + 1, y0 + 1, BAND, H - 2, band)
    weave = mix(band, g.c("gold"), .16)
    for b in range(y0 + 1, y0 + H - 1):            # the demon's lozenges, the angel's waves
        for a in range(x0 + 1, x0 + 1 + BAND):
            u, v = a - x0 - 1, b - y0 - 1
            if g.m == "dark":
                hit = abs((u % 12) - 6) == (v % 12) % 7 and (v % 12) < 7 or abs((u % 12) - 6) == 12 - (v % 12) and (v % 12) >= 7
            else:
                row = v // 6
                dx = (u + (8 if row % 2 else 0)) % 16 - 8
                hit = int(math.hypot(dx, (v % 6) + 3)) in (5, 8)
            if hit:
                g.im.putpixel((a, b), weave)
    g.box(x0 + 1 + BAND, y0 + 1, 2, H - 2, "gold")
    g.box(x0 + 3, y0 + 3, BAND - 4, 1, mix(band, g.c("gold"), .55))
    g.box(x0 + 3, y0 + H - 4, BAND - 4, 1, mix(band, g.c("gold"), .55))
    g.box(x0 + 1 + (BAND - 36) // 2, y0 + 12, 36, 36, band)
    g.head("oni.32.un" if g.m == "dark" else "angel.32.closed", x0 + 1 + (BAND - 32) // 2, y0 + 14)
    g.box(x0 + 1 + (BAND - 20) // 2, y0 + H - 34, 20, 20, band)
    g.stepped(x0 + 1 + (BAND - 16) // 2, y0 + H - 32, 16, 16, g.p["accent"], 1)
    cx = x0 + BAND + 3 + 6
    cw = W - BAND - 3 - 6 - 7
    y = y0 + 7
    keys = "lsord"
    for i, (pic, word, _k) in enumerate(ACTIONS):
        if i == 3:                                 # what cannot be undone stands below a wave
            for a in range(cx + 2, cx + cw - 2, 8):
                g.box(a, y + 5, 4, 1, "edge2")
                g.box(a + 4, y + 4, 4, 1, "edge2")
            y += 10
        st = "asked" if asked == i else "on" if on == i else "rest"
        if st != "rest":
            g.stepped(cx, y, cw, ROW - 2, "accent_hi" if st == "asked" else "accent")
        ink = "text_on_accent" if st != "rest" else "muted"
        g.pic(pic, cx + 4, y + 2, ink)
        label = "press again to " + word if st == "asked" else word
        base = y + (ROW - 2) // 2 + 5
        g.text(label, cx + 54, base, "text_on_accent" if st != "rest" else "text")
        kw, kx = 18, cx + cw - 18 - 8                  # the key, a cap of its own
        if st != "asked":
            g.stepped(kx, y + (ROW - 2 - 20) // 2, kw, 20, "key" if st == "rest" else mix(g.c("accent"), g.c("text_on_accent"), .82), 1)
            g.centre(keys[i], kx + kw // 2 + 1, base, "muted" if st == "rest" else "accent")
        y += ROW
    g.text(UP, cx + 54, y + 21, "muted")
    return x0, y0, W, H


# ── 3 umebachi: the five-petalled plum crest; each petal a choice, its heart says which ─────────
def umebachi(g, on, asked):
    R, d, r = 190, 116, 62
    cx, cy = CELL[0] // 2, CELL[1] // 2
    g.disc(cx, cy, R, HAIR[g.m])
    g.disc(cx, cy, R - 1, g.paper)
    g.disc(cx, cy, R - 4, "edge2")
    g.disc(cx, cy, R - 6, g.paper)
    petals = []
    for i in range(5):
        a = math.radians(-90 + 72 * i)
        petals.append((cx + round(d * math.cos(a)), cy + round(d * math.sin(a))))
    for i, (px, py) in enumerate(petals):
        st = "asked" if asked == i else "on" if on == i else "rest"
        if st != "rest":                           # the torch's glow / the angel's halo round it, a checker
            halo = "accent_lo" if g.m == "dark" else "edge2"
            g.disc(px, py, r + 4, halo, keep=lambda x, y, px=px, py=py: (x + y) % 2 == 0 and math.hypot(x - px, y - py) > r)
        if st == "rest":
            g.disc(px, py, r, "edge2")
            g.disc(px, py, r - 2, "key")
        else:
            g.disc(px, py, r, "accent_hi" if st == "asked" else "accent")
        g.pic(ACTIONS[i][0], px - 20, py - 20, "text_on_accent" if st != "rest" else "muted")
    for i in range(5):                             # the stamens: gold, between two petals
        a = math.radians(-90 + 36 + 72 * i)
        sx, sy = cx + round(72 * math.cos(a)), cy + round(72 * math.sin(a))
        g.stepped(sx - 2, sy - 2, 5, 5, "gold", 1)
    heart = g.p["lacquer"] if g.m == "dark" else g.p["lit"]
    g.disc(cx, cy, 48, "gold")
    g.disc(cx, cy, 47, heart)
    ink = g.p["text_on_lacquer"] if g.m == "dark" else g.p["lit_text"]
    soft = mix(ink, heart, .28)
    i = asked if asked is not None else on
    g.centre(ACTIONS[i][1], cx, cy - 3, ink)
    g.centre("press again" if asked is not None else UP, cx, cy + 13, ink if asked is not None else soft)
    return cx - R, cy - R, 2 * R, 2 * R


# what each zoom shows: rows from the dialog's top (or, for the crest, round its heart)
OPTIONS = [("1 jiku", jiku, lambda b: (b[1] + 8, b[1] + 118)),
           ("2 tanzaku", tanzaku, lambda b: (b[1] - 4, b[1] + 100)),
           ("3 umebachi", umebachi, lambda b: (CELL[1] // 2 - 52, CELL[1] // 2 + 52))]


def main(dark, light, out):
    today = {}
    for m, path in (("dark", dark), ("light", light)):
        today[m] = Image.open(path).convert("RGB").crop((739, 443, 1181, 638))
    rows = [Image.new("RGB", (1920, today["dark"].height), (0, 0, 0))]
    for i, m in enumerate(("dark", "light")):
        rows[0].paste(Image.new("RGB", (960, today[m].height), rgb(BACK[m])), (i * 960, 0))
        rows[0].paste(today[m], (i * 960 + 259, 0))
    for label, fn, part in OPTIONS:
        row = []
        boxes = []
        for m in ("dark", "light"):
            for on, asked in ((0, None), (4, 4)):
                g = Canvas(m)
                box = fn(g, on, asked)
                row.append(g.im)
                boxes.append(box)
        top = max(0, min(b[1] for b in boxes) - 12)
        bot = min(CELL[1], max(b[1] + b[3] for b in boxes) + 16)
        strip = Image.new("RGB", (1920, bot - top + 18), (0, 0, 0))
        for i, im in enumerate(row):
            strip.paste(im.crop((0, top, CELL[0], bot)), (i * 480 + 4, 18))
        ImageDraw.Draw(strip).text((4, 14), label, font=FONT, fill=rgb(BT.P["dark"]["faint"]), anchor="ls")
        rows.append(strip)
        # twice: the first armed in the dark, the first at rest in the light
        z0, z1 = part(boxes[0])
        zoom = Image.new("RGB", (1920, (z1 - z0) * 2), (0, 0, 0))
        for im, x in ((row[1], 8), (row[2], 968)):
            zoom.paste(im.crop((0, z0, CELL[0], z1)).resize((CELL[0] * 2, (z1 - z0) * 2), Image.NEAREST), (x, 0))
        rows.append(zoom)
    total = sum(r.height + 2 for r in rows)
    sheet = Image.new("RGB", (1920, total), (0, 0, 0))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height + 2
    for q in range(88, 49, -2):                    # the page takes 300 KB
        sheet.save(out, quality=q, subsampling=0, optimize=True)
        if pathlib.Path(out).stat().st_size < 299_000:
            break
    print(out, sheet.size, q, pathlib.Path(out).stat().st_size)


if __name__ == "__main__":
    main(*sys.argv[1:4])
