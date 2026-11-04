#!/usr/bin/env python3
"""tools/build-heads.py — the two heads, one character sheet (art direction §1; the owner, 4 Nov:
"less colours, more conventional, more RED; monotone, classic Japanese", then "more detailed, more
badass, samurai style, EPIC": so detail by line, not by colour; docs/art/heads.md).

    python3 tools/build-heads.py            # writes what the heads are made into (below)
    python3 tools/build-heads.py --sheet DIR   # also every size side by side, 1× and 4×, for the eye

A samurai oni and Marishiten, never downscaled: the small sizes are pixels by hand (art/heads.txt: the
left half, mirrored when built), the large ones brush strokes at their own size (oni(), angel() below:
a line's width is chosen for the size, not scaled from another). Writes, all committed:
    art/icons.txt                         the prompt's glyphs (then tools/build-icons.py)
    themes/MOOD/face.png, face-open.png   the bar's end tile, 22 × 20, the tile's paper through the rest
    .local/share/fedokawaii/MOOD/head.six fetch's picture, a sixel of 144 × 180: 18 cells × 9 lines
tools/build-lock.py takes the lock's heads from here.

Each head has two states at every size. The oni: 吽 shut, the teeth locked, and 阿 he roars, as the
temple guardians' pair (A-Un). Marishiten: her eyes closed, or open.
Needs Pillow and numpy.
"""
import argparse
import importlib.util
import math
import pathlib
import re

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEET = ROOT / "art/heads.txt"
ICONS = ROOT / "art/icons.txt"
_spec = importlib.util.spec_from_file_location("wada_palette", ROOT / "tools/wada-palette.py")
_wada = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_wada)
_P = _wada.palette()[0]
D_, L_ = _P["dark"], _P["light"]

# the inks, by the palette's names. The oni: the seal's red in three values, sumi, bone. The angel:
# sumi, gofun, the seal's red (and its deep) in the urna and the lips only
INKS = {
    "oni": {"K": D_["lo"], "D": D_["accent_lo"], "R": D_["accent"], "H": D_["accent_hi"], "W": D_["strong"]},
    "angel": {"K": L_["strong"], "P": L_["key"], "R": L_["accent"], "r": D_["select"]},
}
# the prompt's glyphs: one ink, 24 × 20, drawn as art/icons.txt's two glyphs, 16 and 8 wide
GLYPHS = (("head-oni", "oni.prompt.un"), ("head-oni-roar", "oni.prompt.a"),
          ("head-angel", "angel.prompt.closed"), ("head-angel-open", "angel.prompt.open"))


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ── the sheet: art/heads.txt ──────────────────────────────────────────────────────────────

def sheet():
    """{name: (w, h, rows)}: each its rows whole, the left half mirrored ('.' is the paper)."""
    out, name, rows, w, h = {}, None, [], 0, 0

    def close():
        if name:
            if len(rows) != h:
                raise SystemExit(f"art/heads.txt: {name}: {len(rows)} rows, not {h}")
            out[name] = (w, h, rows)
    for n, raw in enumerate(SHEET.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.rstrip()
        if not line or line == "#" or line.startswith("# "):      # (a row of ink may start with '#')
            continue
        if line.startswith("@"):
            close()
            f = line[1:].split()
            name, w, h, rows = f[0], int(f[1]), int(f[2]), []
        else:
            if len(line) != (w + 1) // 2:
                raise SystemExit(f"art/heads.txt:{n}: {name}: {len(line)} columns, not {(w + 1) // 2}")
            rows.append(line + line[::-1][w % 2:])
    close()
    return out


def picture(name):
    """A hand-drawn size as RGBA: the paper transparent, its inks by the head's name."""
    w, h, rows = sheet()[name]
    return of_rows(rows, name.split(".")[0])


def of_rows(rows, kind, mono=None):
    w, h = len(rows[0]), len(rows)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                px[x, y] = (*rgb(mono or INKS[kind][c]), 255)
    return im


# ── a canvas of ink letters, no antialiasing, brush strokes that swell and taper ─────────────

class Canvas:
    def __init__(self, w, h):
        self.w, self.h, self.cx = w, h, w / 2
        self.a = np.full((h, w), ".", dtype="<U1")

    def poly_mask(self, pts):
        """a polygon: a pixel is in when its centre is"""
        m = np.zeros((self.h, self.w), bool)
        ys = [p[1] for p in pts]
        for y in range(max(int(min(ys)) - 1, 0), min(int(max(ys)) + 2, self.h)):
            yc, xs = y + 0.5, []
            for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1], strict=True):
                if (y0 <= yc < y1) or (y1 <= yc < y0):
                    xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[::2], xs[1::2], strict=True):
                x0, x1 = max(math.ceil(a - 0.5), 0), min(math.floor(b - 0.5), self.w - 1)
                if x1 >= x0:
                    m[y, x0:x1 + 1] = True
        return m

    def fill(self, m, ink, clip=None, only=None):
        if clip is not None:
            m = m & clip
        if only is not None:
            m = m & np.isin(self.a, list(only))
        self.a[m] = ink

    def poly(self, pts, ink, clip=None, only=None):
        self.fill(self.poly_mask(pts), ink, clip, only)

    def ell(self, cx, cy, rx, ry, ink, clip=None, rot=0.0):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        dx, dy = xx + 0.5 - cx, yy + 0.5 - cy
        c, s = math.cos(rot), math.sin(rot)
        self.fill(((dx * c + dy * s) / rx) ** 2 + ((-dx * s + dy * c) / ry) ** 2 <= 1, ink, clip)

    def stroke_mask(self, pts, w=1.0, w1=None, prof=None):
        """a brush through pts (smoothed): width w → w1, or w × prof(t); a line of 1 px stays 1 px"""
        path = spline(pts)
        seg = np.hypot(*np.diff(path, axis=0).T)
        m = np.zeros((self.h, self.w), bool)
        n = max(int(seg.sum() * 3), 2)
        cum = np.r_[0, np.cumsum(seg)] / max(seg.sum(), 1e-9)
        ts = np.linspace(0, 1, n)
        for t, x, y in zip(ts, np.interp(ts, cum, path[:, 0]), np.interp(ts, cum, path[:, 1]), strict=True):
            wd = w if w1 is None else w + (w1 - w) * t
            if prof is not None:
                wd = w * prof(t)
            if wd <= 1.05:
                px, py = math.floor(x), math.floor(y)
                if 0 <= px < self.w and 0 <= py < self.h:
                    m[py, px] = True
                continue
            r = wd / 2
            for py in range(max(int(y - r - 1), 0), min(int(y + r + 2), self.h)):
                for px in range(max(int(x - r - 1), 0), min(int(x + r + 2), self.w)):
                    if (px + 0.5 - x) ** 2 + (py + 0.5 - y) ** 2 <= r * r:
                        m[py, px] = True
        return thin_corners(m) if (w1 is None and prof is None and w <= 1.05) else m

    def stroke(self, pts, ink, w=1.0, w1=None, prof=None, clip=None, only=None):
        self.fill(self.stroke_mask(pts, w, w1, prof), ink, clip, only)

    def outline(self, m, ink, clip=None, only=None):
        """the 1 px key line round a shape, outside it"""
        self.fill(dilate(m) & ~m, ink, clip, only)

    def mirrored(self):
        """the left half, mirrored: a face is symmetric to the pixel"""
        for x in range(self.w // 2):
            self.a[:, self.w - 1 - x] = self.a[:, x]
        return self

    def image(self, kind):
        ink = {k: rgb(v) for k, v in INKS[kind].items()}
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = im.load()
        for y in range(self.h):
            for x in range(self.w):
                c = self.a[y, x]
                if c != ".":
                    px[x, y] = (*ink[c], 255)
        return im


def spline(pts, closed=False, per=16):
    """Catmull-Rom through pts"""
    p = np.array(pts, dtype=float)
    if len(p) < 3:
        return p
    q = np.vstack([p[-1], p, p[0], p[1]]) if closed else np.vstack([2 * p[0] - p[1], p, 2 * p[-1] - p[-2]])
    out = []
    for i in range(1, len(q) - 2):
        a, b, c, d = q[i - 1], q[i], q[i + 1], q[i + 2]
        for t in np.linspace(0, 1, per, endpoint=False):
            out.append(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t ** 3))
    out.append(q[-2])
    return np.array(out)


def round_(pts, per=6):
    return [tuple(q) for q in spline(pts, closed=True, per=per)]


def dilate(m):
    d = m.copy()
    d[1:, :] |= m[:-1, :]
    d[:-1, :] |= m[1:, :]
    d[:, 1:] |= m[:, :-1]
    d[:, :-1] |= m[:, 1:]
    return d


def erode(m):
    return ~dilate(~m)


def thin_corners(m):
    """pixel-perfect: a 1 px line loses the corner pixel of each L"""
    out = m.copy()
    for y in range(1, m.shape[0] - 1):
        for x in range(1, m.shape[1] - 1):
            if out[y, x]:
                n, s, e, w = out[y - 1, x], out[y + 1, x], out[y, x + 1], out[y, x - 1]
                if (n and e and not s and not w and not out[y - 1, x + 1]) or (n and w and not s and not e and not out[y - 1, x - 1]) \
                        or (s and e and not n and not w and not out[y + 1, x + 1]) or (s and w and not n and not e and not out[y + 1, x - 1]):
                    out[y, x] = False
    return out


def swell(t):
    return 0.25 + 0.95 * math.sin(math.pi * t)


def taper(t):
    return (1 - t) ** 0.8 + 0.05


# ── the oni, large: the fetch and the lock ───────────────────────────────────────────────────

def hatch(c, m, ink, gap=3, slope=1):
    """lines cut across a shape, a woodblock's shade: every GAP px on a slant"""
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    c.fill(m & (((xx + slope * yy) % gap) == 0), ink)


def oni(open_=0.0, w=240, h=350, f=1.0, top=66, horn=1.0):
    """The demon as a samurai of the red companies (akazonae): OPEN_, how far the mouth is open, 0 (the
    teeth locked) … 1; F the size; HORN the kuwagata's length. Design units: x from the mirror line, y
    down. Red lacquer, sumi line and hatching, bone; key lines stay 1 px whatever the size."""
    c = Canvas(w, h)
    o, j = open_, 24 * open_

    def P(pts):
        return [(c.cx - x * f, (y + top) * f) for x, y in pts]

    def R(pts, per=6):
        return P(round_(pts, per))

    def S(pts):                         # both sides of the mirror line: a closed shape from its half
        return pts + [(-x, y) for x, y in reversed(pts[1:-1])]

    # ── the neck guard (shikoro) behind all: four lames flaring out, laced
    y0 = 96
    for x0, x1, ya, yb in ((60, 104, y0, y0 + 26), (60, 112, y0 + 22, y0 + 50), (60, 120, y0 + 46, y0 + 74), (60, 126, y0 + 70, y0 + 98)):
        lame = c.poly_mask(P([(x0, ya), (x1 - 8, ya - 2), (x1, ya + 6), (x1 + 2, yb - 6), (x1 - 4, yb), (x0, yb + 4)]))
        c.fill(lame, "D")
        c.outline(lame, "K")
        # its lit edge, its lacing: paired ticks of bone down the lame
        c.stroke(P([(x0, ya + 3), (x1 - 6, ya + 2)]), "R", 2 * f, clip=lame)
        for xk in range(int(x0) + 8, int(x1) - 2, 10):
            c.stroke(P([(xk, ya + 9), (xk + 0.5, yb - 7)]), "K", 3.0 * f, clip=lame)
            c.stroke(P([(xk, ya + 10), (xk + 0.5, yb - 8)]), "W", 1.0, clip=lame)
    # ── the throat guard (yodarekake) under the chin
    for hw, ya, yb in ((58, 238 + j, 260 + j), (52, 256 + j, 276 + j), (44, 272 + j, 290 + j)):
        pl = c.poly_mask(P(S([(0, ya), (hw, ya), (hw + 2, yb - 4), (hw - 6, yb), (0, yb + 2)])))
        c.fill(pl, "D")
        c.outline(pl, "K")
        for xk in range(4, hw - 2, 9):
            c.stroke(P([(xk, ya + 6), (xk, yb - 5)]), "K", 3.0 * f, clip=pl)
            c.stroke(P([(xk, ya + 7), (xk, yb - 6)]), "W", 1.0, clip=pl)
    # the fringe of its last lame
    for xk in range(2, 40, 5):
        c.stroke(P([(xk, 290 + j), (xk + 1, 296 + j)]), "K", 2.2 * f, 0.8)

    # ── the wings (fukigaeshi): folded back from the helmet either side
    wing = c.poly_mask(P([(58, 44), (96, 30), (116, 44), (112, 66), (84, 90), (62, 92)]))
    c.fill(wing, "R")
    c.outline(wing, "K")
    c.stroke(P([(66, 50), (96, 38), (108, 48), (104, 62), (80, 82), (66, 84)]), "K", 1.0, clip=wing)
    hatch(c, wing & c.poly_mask(P([(62, 74), (84, 62), (112, 58), (112, 70), (84, 90), (62, 92)])), "D", 2)
    # the crest on the wing: a ring
    c.ell(c.cx - 88 * f, (58 + top) * f, 7 * f, 7 * f, "K")
    c.ell(c.cx - 88 * f, (58 + top) * f, 4.5 * f, 4.5 * f, "W")
    c.ell(c.cx - 88 * f, (58 + top) * f, 2 * f, 2 * f, "R")

    # ── the bowl (hachi): ribbed lacquer, a rivet at each rib, its crown ring
    bowl = c.poly_mask(R(S([(0, 4), (24, 6), (48, 20), (64, 42), (70, 66), (66, 76), (0, 76)])))
    c.fill(bowl, "D")
    c.outline(bowl, "K")
    for k in (-1, 1, 3, 5):
        a = k * 0.21
        tip = (math.sin(a) * 12, 8)
        foot = (math.sin(a) * 78, 76)
        mid = (math.sin(a) * 66, 26 + abs(a) * 8)
        c.stroke(P([tip, mid, foot]), "K", 2.0 * f, clip=bowl)
        c.stroke(P([(tip[0] - 2.6, tip[1]), (mid[0] - 3, mid[1]), (foot[0] - 3, foot[1])]), "R", 3.0 * f, clip=bowl)
        for t in (0.3, 0.6, 0.86):
            x, y = spline(P([tip, mid, foot]))[int(t * 32)]
            c.ell(x + 1.2 * f, y, 1.4 * f, 1.4 * f, "W", clip=bowl)
    c.ell(c.cx, (9 + top) * f, 7 * f, 4 * f, "K")
    c.ell(c.cx, (9 + top) * f, 4 * f, 2.2 * f, "W")

    # ── the horns (kuwagata): two blades of bone from the front plate, curving up and in
    def up(pts):
        return [(x, 54 + (y - 54) * horn) for x, y in pts]
    hc = up([(16, 54), (34, 30), (50, 0), (54, -30), (42, -62)])
    blade = c.stroke_mask(P(hc), 22 * f, prof=lambda t: 0.72 + 0.28 * math.sin(math.pi * t * 0.8) - t ** 3 * 0.98)
    c.fill(blade, "W")
    c.outline(blade, "K")
    # its ridge and the hatch on its under side
    c.stroke(P(up([(18, 50), (36, 28), (48, 0), (52, -28), (44, -52)])), "K", 1.0, clip=blade)
    under = blade & c.stroke_mask(P([(p[0] + 6, p[1] + 3) for p in hc]), 11 * f, prof=lambda t: 1 - t ** 2)
    hatch(c, under, "K", 3, -1)
    # the front plate and its sun
    plate = c.poly_mask(R(S([(0, 30), (16, 36), (26, 52), (24, 72), (0, 76)])))
    c.fill(plate, "R")
    c.outline(plate, "K")
    c.ell(c.cx, (54 + top) * f, 11 * f, 11 * f, "K")
    c.ell(c.cx, (54 + top) * f, 8 * f, 8 * f, "W")
    c.ell(c.cx, (54 + top) * f, 5.5 * f, 5.5 * f, "R")

    # ── the face (somen): lacquer over a demon's bones
    half = [(0, 76), (40, 74), (70, 80), (82, 104), (84, 128), (96, 150), (90, 176), (82, 198), (70, 222 + j * 0.5), (50, 240 + j * 0.9), (24, 252 + j), (0, 254 + j)]
    face = c.poly_mask(P(round_(half + [(-x, y) for x, y in reversed(half[1:-1])], 4)))
    c.fill(face, "R")
    # the temple and under the cheekbone turn away: deep shu, hatched
    for pts in ([(100, 90), (74, 78), (70, 96), (76, 130), (92, 148), (100, 150)], [(96, 176), (76, 190), (70, 202), (76, 226), (100, 214)]):
        m = c.poly_mask(P(pts)) & face
        c.fill(m, "D")
        hatch(c, m, "K", 3)
    # the peak (mabizashi): a heavy lip of lacquer over the brows, its edge in bone
    peak = c.poly_mask(P(S([(0, 62), (40, 60), (72, 68), (84, 88), (70, 84), (40, 78), (0, 82)])))
    c.fill(peak, "D")
    c.outline(peak, "K")
    c.stroke(P([(0, 66), (40, 64), (70, 72)]), "R", 3 * f, clip=peak)
    c.stroke(P([(0, 80), (40, 76), (72, 84)]), "W", 1.6 * f, clip=peak)
    # the sockets, cut as planes, the eye of bone in them under a heavy lid
    socket = c.poly_mask(P([(10, 124), (24, 110), (56, 100), (74, 106), (72, 130), (48, 148), (26, 148), (14, 138)]))
    c.fill(socket, "D", clip=face)
    hatch(c, socket & c.poly_mask(P([(14, 138), (26, 148), (48, 148), (72, 130), (72, 122), (46, 140), (28, 142)])), "K", 2)
    eye = c.poly_mask(P(round_([(14, 134), (28, 124), (46, 116), (64, 110), (66, 120), (54, 134), (36, 140), (22, 139)], 5)))
    c.fill(eye, "W")
    c.ell(c.cx - 38 * f, (125 + top) * f, 6.4 * f, 7 * f, "K", clip=eye)
    c.outline(eye, "K")
    c.stroke(P([(10, 138), (24, 122), (46, 112), (70, 104), (80, 98)]), "K", 5 * f, prof=lambda t: 0.3 + 0.9 * math.sin(math.pi * t ** 0.8))
    c.stroke(P([(16, 146), (36, 150), (58, 140)]), "K", 1.8 * f, prof=swell)
    c.stroke(P([(70, 124), (80, 128), (88, 136)]), "K", 1.8 * f, prof=taper)
    c.stroke(P([(66, 132), (76, 140), (84, 150)]), "K", 1.8 * f, prof=taper)
    # the brows: sumi flames over a ridge of lit lacquer, knotted in the middle
    c.stroke(P([(14, 104), (36, 92), (72, 88)]), "H", 3 * f, prof=swell, clip=face)
    c.stroke(P([(3, 112), (20, 100), (46, 92), (84, 86)]), "K", 14 * f, prof=lambda t: 0.45 + 0.75 * math.sin(math.pi * t ** 0.65))
    for x0, y0, x1, y1, wd in ((70, 86, 96, 72, 7), (56, 90, 80, 74, 7), (42, 92, 58, 80, 6), (76, 90, 102, 88, 6)):
        c.stroke(P([(x0, y0), ((x0 + x1) / 2 + 1, (y0 + y1) / 2 + 2), (x1, y1)]), "K", wd * f, prof=taper)
    c.stroke(P([(6, 112), (3, 100), (5, 86)]), "K", 3.2 * f, prof=taper, clip=face)
    c.stroke(P([(12, 110), (12, 102), (16, 92)]), "K", 2 * f, prof=taper, clip=face)
    # the nose: a hook of lacquer, nostrils flared, cut
    nose = c.poly_mask(P(round_([(6, 112), (10, 132), (16, 152), (30, 160), (32, 172), (18, 182), (0, 184)] + [(-18, 182), (-32, 172), (-30, 160), (-16, 152), (-10, 132), (-6, 112)], 5)))
    c.fill(nose, "R", clip=face)
    c.fill(c.poly_mask(P([(6, 116), (12, 136), (18, 152), (28, 160), (14, 160), (6, 140)])) & face, "D")
    c.outline(nose, "K", only="RDH")
    c.stroke(P([(1, 120), (1, 152)]), "H", 5 * f, prof=swell)
    c.stroke(P([(0, 164), (8, 166)]), "H", 5 * f, prof=swell)
    c.ell(c.cx - 16 * f, (174 + top) * f, 7.5 * f, 3.6 * f, "K", rot=0.2)
    # the cheeks: the folds from the nose round the mouth, the armourer's lines under the cheekbone
    c.stroke(P([(36, 156), (54, 166), (72, 188), (80, 218)]), "K", 4 * f, prof=swell)
    c.stroke(P([(46, 150), (66, 152), (90, 168)]), "K", 2.2 * f, prof=swell, clip=face)
    c.stroke(P([(54, 160), (68, 164), (84, 178)]), "K", 1.6 * f, prof=swell, clip=face)
    c.stroke(P([(62, 170), (72, 176), (82, 190)]), "K", 1.4 * f, prof=swell, clip=face)
    c.stroke(P([(58, 146), (78, 148), (94, 158)]), "H", 3 * f, prof=swell, clip=face)

    def tusk(y0, tall):
        pts = [(50, y0), (58, y0 - tall * 0.5), (56, y0 - tall)]
        m = c.stroke_mask(P(pts), 13 * f, prof=lambda t: (1 - t) ** 0.7 + 0.05)
        c.fill(m, "W")
        c.outline(m, "K")
        hatch(c, m & c.stroke_mask(P([(p[0] + 3.4, p[1]) for p in pts]), 5 * f, prof=taper), "K", 3)

    def lips(outer, inner):
        lm = c.poly_mask(P(round_(outer + [(-x, y) for x, y in reversed(outer[1:-1])])))
        mm = c.poly_mask(P(round_(inner + [(-x, y) for x, y in reversed(inner[1:-1])])))
        c.fill(lm & ~mm, "D")
        c.outline(lm, "K")
        return mm

    if o == 0:
        mm = lips([(0, 188), (16, 182), (38, 183), (58, 194), (72, 214), (58, 220), (44, 222), (24, 224), (0, 225)],
                  [(0, 194), (16, 189), (38, 190), (56, 199), (66, 212), (56, 212), (44, 213), (24, 215), (0, 216)])
        c.fill(mm, "W")
        c.outline(mm, "K", only="D")
        c.stroke(P([(0, 204), (24, 201), (44, 202), (66, 212)]), "K", 2.2 * f, prof=lambda t: 0.7 + 0.4 * math.sin(math.pi * t), clip=mm)
        for x0 in (0.5, 11, 22, 33, 43, 53):
            c.stroke(P([(x0, 186), (x0 + 0.6 * x0 / 20, 220)]), "K", 1.1 * f, clip=mm)
        fang = c.stroke_mask(P([(47, 190), (49, 198), (46, 208)]), 11 * f, prof=lambda t: (1 - t) ** 0.7 + 0.05) & mm
        c.fill(fang, "W")
        c.outline(fang, "K", clip=mm)
        c.stroke(P([(0, 230), (20, 229), (42, 223)]), "K", 2.0 * f, prof=swell)
    else:
        def upper(ex):
            return [(0, 192 - ex), (16, 186 - ex), (38, 187 - ex), (58, 197 - ex * 0.6), (66 + 4 * o, 210 + 4 * o)]

        def lower(ex):
            return [(66 + 4 * o, 210 + 4 * o), (58, 204 + 16 * o + ex), (44, 198 + 36 * o + ex), (24, 192 + 50 * o + ex), (0, 192 + 56 * o + ex)]
        mm = lips(upper(8) + lower(10)[1:-1], upper(0) + lower(0)[1:-1])
        c.fill(mm, "K")
        if o > 0.4:
            c.fill(mm & ~erode(erode(erode(mm))), "D")
            tongue = c.poly_mask(P(round_([(0, 190 + 45 * o), (14, 190 + 43 * o), (28, 190 + 45 * o), (32, 190 + 56 * o), (0, 190 + 60 * o)])))
            c.fill(tongue, "D", clip=mm)
            c.stroke(P([(0, 192 + 45 * o), (0, 190 + 54 * o)]), "K", 1.2 * f)
        c.outline(mm, "K", only="D")

        def teeth(xs, y_at, tall, wd, up):
            for x0 in xs:
                y0, s = y_at(x0), -1 if up else 1
                t = [(x0 - wd / 2, y0 - s * 3), (x0 + wd / 2, y0 - s * 3), (x0 + wd / 2 - 0.5, y0 + s * tall * 0.55), (x0, y0 + s * tall), (x0 - wd / 2 + 0.5, y0 + s * tall * 0.55)]
                m = c.poly_mask(P(t)) & mm
                c.fill(m, "W")
                c.outline(m, "K", clip=mm)

        def low(x):
            return 192 + 56 * o - (x / 58) ** 2 * (34 * o + 2)

        def high(x):
            return 192 - 6 * (x / 16 if x < 16 else 1 - (x - 16) / 42 * 0.9)
        teeth((7, 18, 29), low, 8, 10, True)
        teeth((39,), low, 7, 8, True)
        teeth((6, 17, 28), high, 10, 10, False)
        teeth((38,), high, 9, 8, False)
        fang = c.stroke_mask(P([(48, 190), (50, 202 + 4 * o), (46, 210 + 8 * o)]), 12 * f, prof=lambda t: (1 - t) ** 0.7 + 0.05) & mm
        c.fill(fang, "W")
        c.outline(fang, "K", clip=mm)
        c.stroke(P([(0, 244 + 22 * o), (22, 242 + 21 * o), (44, 232 + 16 * o)]), "K", 1.8 * f, prof=swell)

    # the moustache (hige): a heavy sweep of sumi from under the nose, down past the corners of the mouth, its strands cut in it
    hige = c.stroke_mask(P([(3, 184), (26, 182), (52, 192), (68, 214)]), 11 * f, prof=lambda t: 0.5 + 0.6 * math.sin(math.pi * min(t * 1.25, 1)) - 0.5 * t ** 3)
    hige |= c.stroke_mask(P([(30, 186), (50, 200), (60, 224)]), 6 * f, prof=taper)
    hige |= c.stroke_mask(P([(44, 186), (66, 198), (80, 222)]), 5 * f, prof=taper)
    c.fill(hige, "K")
    for a_, b_, d_ in (((10, 183), (28, 183), (50, 193)), ((22, 182), (40, 187), (58, 204))):
        c.stroke(P([a_, b_, d_]), "D", 1.0, clip=hige)
    tusk(220 + 22 * o, 44 + 6 * o)
    # the chin's beard: a point of sumi over the throat guard, strands cut in it, tufts along the jaw
    beard = c.poly_mask(P(round_([(0, 236 + j), (14, 236 + j), (24, 246 + j), (20, 266 + j), (10, 284 + j), (0, 298 + j)] + [(-10, 284 + j), (-20, 266 + j), (-24, 246 + j), (-14, 236 + j)], 3)))
    c.fill(beard, "K")
    for x0 in (3, 9, 15):
        c.stroke(P([(x0, 242 + j), (x0 + 1, 258 + j), (x0 - 2, 276 + j - x0 * 0.6)]), "D", 1.0, clip=beard)
    for a_, b_, d_ in (((30, 240 + j), (36, 252 + j), (34, 266 + j)), ((42, 234 + j), (50, 244 + j), (50, 258 + j))):
        c.stroke(P([a_, b_, d_]), "K", 5 * f, prof=taper)
    # the cord (shinobi-no-o): from the cheek's hook under the chin, tied in a knot
    c.stroke(P([(86, 186), (78, 232 + j * 0.6), (40, 262 + j), (0, 270 + j)]), "K", 3.6 * f)
    c.stroke(P([(86, 186), (78, 232 + j * 0.6), (40, 262 + j), (0, 270 + j)]), "W", 1.6 * f)
    c.ell(c.cx - 86 * f, (186 + top) * f, 3.2 * f, 3.2 * f, "K")
    c.ell(c.cx - 86 * f, (186 + top) * f, 1.6 * f, 1.6 * f, "W")
    c.ell(c.cx, (272 + j + top) * f, 6 * f, 5 * f, "K")
    c.ell(c.cx, (272 + j + top) * f, 3.6 * f, 3 * f, "W")
    c.outline(face, "K", only="DR")
    return c.mirrored()


# ── the angel, large ─────────────────────────────────────────────────────────────────────────

TOP_ANGEL = 70


def angel(open_=0.0, eyes=False, w=240, h=380, f=1.0, top=TOP_ANGEL, bust=True):
    """Marishiten (摩利支天), the samurai's own guardian, goddess of light: sumi line and hatching on
    gofun, red only in the urna and the lips; a nimbus of blades, a war-crown, laced armour. OPEN_: how
    far the sutra in her hands is unrolled, 0 (rolled, sealed) … 1; EYES: open; BUST: down to the hands
    and the scroll, or the head and shoulders only."""
    c = Canvas(w, h)

    def P(pts):
        return [(c.cx - x * f, (y + top) * f) for x, y in pts]

    def R(pts, per=6):
        return P(round_(pts, per))

    def S(pts):
        return pts + [(-x, y) for x, y in reversed(pts[1:-1])]

    # ── the nimbus: a ring and its rays, blades of sumi, long and short
    cy = (118 + top) * f
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(xx + 0.5 - c.cx, yy + 0.5 - cy) / f
    for k in range(56):
        a = 2 * math.pi * (k + 0.5) / 56
        r0, r1 = 110, (140 if k % 4 == 0 else 126 if k % 2 == 0 else 118)
        pts = [(c.cx + q * f * math.cos(a), cy + q * f * math.sin(a)) for q in (r0, (r0 + r1) / 2, r1)]
        c.stroke(pts, "K", (5.5 if k % 4 == 0 else 4) * f, prof=lambda t: (1 - t) ** 0.8 + 0.02)
    c.a[(r >= 104) & (r < 104 + 1 / f)] = "K"
    c.a[(r >= 109) & (r < 109 + 1 / f)] = "K"
    # beads on the ring
    for k in range(40):
        a = 2 * math.pi * k / 40
        c.ell(c.cx + 106.5 * f * math.cos(a), cy + 106.5 * f * math.sin(a), 1.2 * f, 1.2 * f, "K")

    # ── the hair behind: sumi, falling in long locks, the ends lifting
    hair = c.poly_mask(R([(0, 30), (34, 32), (58, 50), (76, 84), (84, 124), (88, 170), (96, 214), (100, 236), (84, 240), (70, 232), (60, 196), (54, 150), (0, 120)]))
    c.fill(hair, "K")
    for pts in ([(70, 110), (76, 160), (84, 214)], [(62, 130), (66, 170), (72, 216)], [(78, 130), (86, 180), (94, 226)]):
        c.stroke(P(pts), "P", 1.0, clip=hair)

    # ── the armour: shoulder plates (ō-sode), laced lames as the demon's; the breast plate
    if True:
        body = c.poly_mask(P([(0, 200), (24, 202), (44, 212), (64, 224), (84, 240), (84, 400), (0, 400)]))
        c.fill(body, "P")
        c.outline(body, "K")
        # the sode: five lames each side, hanging from the shoulder, flaring, laced
        for i in range(5):
            ya, yb = 222 + i * 22 + (0 if i else 6), 248 + i * 22
            x0, x1 = 64 - i * 0.5, 96 + i * 6
            lame = c.poly_mask(P([(x0, ya + 6), (x1 - 8, ya - (0 if i else 6)), (x1, ya + 4), (x1 + 1, yb - 4), (x1 - 4, yb), (x0, yb + 4)]))
            c.fill(lame, "P")
            c.outline(lame, "K")
            for xk in range(int(x0) + 7, int(x1) - 3, 8):
                c.stroke(P([(xk, ya + 9), (xk + 0.4, yb - 6)]), "K", 1.0, clip=lame)
            hatch(c, lame & c.poly_mask(P([(x0, yb - 6), (x1 + 2, yb - 7), (x1 + 2, yb + 2), (x0, yb + 6)])), "K", 2)
        # the collar and the breast: a deep V, lines of lacing, a boss
        neck = c.poly_mask(R([(0, 186), (22, 186), (24, 204), (32, 216), (0, 236)]))
        c.fill(neck, "P")
        c.stroke(P([(23, 190), (24, 204), (34, 216)]), "K", 1.5 * f, prof=swell)
        for y0 in (198, 206):
            c.stroke(P([(0, y0 + 2), (10, y0 + 1), (19, y0 - 3)]), "K", 1.0)
        for off, wd in ((0, 1.0), (5, 1.0)):
            c.stroke(P([(0, 258 + off), (22, 236 + off), (44, 218 + off), (62, 210 + off)]), "K", wd)
        # the V's hatched band
        vband = c.poly_mask(P([(0, 258), (22, 236), (44, 218), (62, 210), (62, 215), (44, 223), (22, 241), (0, 263)]))
        hatch(c, vband, "K", 2)
        # the breast plate: its upper lames laced, a crest in the middle, the sides turned away
        for y0 in (252, 266):
            c.stroke(P([(26, y0 - 8), (44, y0 - 18), (60, y0 - 26)]), "K", 1.0, clip=body)
            for xk in range(30, 60, 7):
                yk = y0 - 8 - (xk - 26) * 0.53
                c.stroke(P([(xk, yk + 2), (xk, yk + 8)]), "K", 1.0, clip=body)
        hatch(c, body & c.poly_mask(P([(62, 226), (50, 234), (46, 262), (50, 340), (62, 340)])), "K", 3, -1)
        c.ell(c.cx, (246 + top) * f, 9 * f, 9 * f, "K")
        c.ell(c.cx, (246 + top) * f, 7 * f, 7 * f, "P")
        c.ell(c.cx, (246 + top) * f, 3.6 * f, 3.6 * f, "K")

    # ── the face: full, a soft oval
    fo = [(0, 62), (26, 64), (48, 78), (58, 108), (57, 138), (48, 166), (28, 186), (0, 192)]
    face = c.poly_mask(P(round_(fo + [(-x, y) for x, y in reversed(fo[1:-1])], 8)))
    c.fill(face, "P")
    c.stroke(P([(57, 138), (48, 166), (28, 186), (0, 192)]), "K", 1.6 * f, prof=lambda t: 0.5 + 0.7 * t)
    # the hair's edge on the brow, kewari
    c.poly(R([(0, 62), (18, 68), (40, 80), (52, 104), (58, 128), (70, 120), (66, 80), (42, 54), (0, 46)]), "K")
    for x0, y0 in ((6, 66), (13, 69), (20, 72), (27, 77), (34, 83), (40, 90), (45, 97), (49, 105)):
        c.stroke(P([(x0 - 1, y0 - 2), (x0 + 0.5, y0 + 2.5)]), "K", 1.0, clip=face)
    # the ear, its ring and tassel
    ear = c.poly_mask(R([(56, 112), (66, 112), (70, 128), (66, 152), (64, 170), (58, 170), (56, 150)]))
    c.fill(ear, "P")
    c.outline(ear, "K")
    c.stroke(P([(61, 122), (64, 134), (60, 150)]), "K", 1.0)
    c.ell(c.cx - 62 * f, (178 + top) * f, 5 * f, 5 * f, "K")
    c.ell(c.cx - 62 * f, (178 + top) * f, 2.6 * f, 2.6 * f, "P")
    for dx in (-3, 0, 3):
        c.stroke(P([(62 + dx, 183), (62 + dx, 196)]), "K", 1.0)

    # ── the war-crown: a band of lotus, a tall blade in the middle, peaks like a helmet's, a sun
    band = [(0, 44), (28, 46), (52, 56), (60, 68), (40, 62), (20, 57), (0, 55)]
    crown_b = c.poly_mask(P(band + [(-x, y) for x, y in reversed(band[1:-1])]))
    # the side peaks
    for (ax, ay, bx, by, tx, ty) in ((8, 50, 30, 50, 18, 6), (26, 50, 48, 56, 44, 12), (44, 54, 62, 68, 70, 26)):
        pk = c.poly_mask(P([(ax, ay), (tx, ty), (bx, by)]))
        c.fill(pk, "P")
        c.outline(pk, "K")
        hatch(c, pk & c.poly_mask(P([(tx, ty), (bx, by), ((ax + bx) / 2 + 2, (ay + by) / 2)])), "K", 2)
    # the middle blade
    blade = c.poly_mask(P(S([(0, -46), (5, -30), (9, 4), (14, 30), (10, 50), (0, 52)])))
    c.fill(blade, "P")
    c.outline(blade, "K")
    c.stroke(P([(0, -38), (0, 2)]), "K", 1.0, clip=blade)
    hatch(c, blade & c.poly_mask(P([(0, -46), (9, 4), (14, 30), (0, 30)])), "K", 2)
    # the flaming jewel on the blade (hōju): a teardrop, its point up
    jewel = c.poly_mask(P(S([(0, 2), (4, 10), (9, 20), (8, 29), (0, 33)])))
    c.fill(jewel, "K")
    c.fill(c.poly_mask(P(S([(0, 9), (3, 15), (5.5, 22), (5, 26), (0, 29)]))), "P")
    c.stroke(P([(3, 26), (0, 20), (-2, 14)]), "K", 1.0)
    c.fill(crown_b, "P")
    c.outline(crown_b, "K")
    for xk in range(4, 56, 8):
        c.stroke(P([(xk, 47 + xk * 0.15), (xk + 1, 54 + xk * 0.2)]), "K", 1.0, clip=crown_b)

    # ── the features
    c.ell(c.cx, (95 + top) * f, 3.2 * f, 3.2 * f, "R")
    c.stroke(P([(52, 110), (32, 100), (14, 104), (8, 118)]), "K", 2.4 * f, prof=swell)
    c.stroke(P([(8, 118), (7.5, 146)]), "K", 1.0)
    if eyes:      # open, level, calm
        eye = c.poly_mask(R([(14, 132), (28, 127), (46, 124), (54, 125), (42, 133), (24, 136)], 5))
        c.fill(eye, "P")
        c.ell(c.cx - 33 * f, (129 + top) * f, 4.6 * f, 5.4 * f, "K", clip=eye)
        c.stroke(P([(10, 133), (28, 125), (46, 122), (60, 122)]), "K", 3.4 * f, prof=lambda t: 0.5 + 0.7 * math.sin(math.pi * t))
        c.stroke(P([(20, 137), (34, 137), (50, 128)]), "K", 1.0)
    else:
        c.stroke(P([(13, 130), (28, 137), (52, 126)]), "K", 3 * f, prof=lambda t: 0.4 + 0.8 * math.sin(math.pi * t))
        c.stroke(P([(15, 121), (30, 119), (46, 120)]), "K", 1.0)
    c.stroke(P([(12, 153), (7, 156), (0, 155)]), "K", 1.4 * f, prof=swell)
    c.poly(R([(0, 168), (4, 166.5), (8, 168.5), (12, 170), (7, 170.5), (0, 170)]), "R")
    c.poly(R([(0, 170), (7, 170.5), (10, 170), (5, 173.5), (0, 174)]), "r")
    c.stroke(P([(0, 170), (7, 170), (13, 169)]), "K", 1.0)
    c.stroke(P([(0, 180), (7, 179.5)]), "K", 1.0)
    # under the chin, the neck turns away: a few lines of shade
    hatch(c, neck & c.poly_mask(P(S([(0, 192), (20, 188), (22, 196), (0, 200)]))), "K", 2)
    if bust:
        scroll(c, P, S, open_, f, top)
    return c.mirrored()


def scroll(c, P, S, o, f, top):
    """the sutra in her hands: rolled, sealed in the seal's red; unrolling, its two rods go apart, a hand
    on each, the sleeves following; the paper between them, ruled, where the password is brushed"""
    e = o * o * (3 - 2 * o)
    rx, y0, y1 = 7 + 62 * e, 264, 312
    if e > 0:
        paper = c.poly_mask(P([(rx, y0 + 6), (-rx, y0 + 6), (-rx, y1 - 6), (rx, y1 - 6)]))
        c.fill(paper, "P")
        c.outline(paper, "K")
        for y in (y0 + 9, y1 - 9):        # (the sutra's ruled border)
            c.stroke(P([(rx, y), (-rx, y)]), "K", 1.0, clip=paper)
    # the sleeve: from the sode down to the hand, the armour's forearm hatched
    sleeve = c.stroke_mask(P([(116, 334), (rx + 40, 322), (rx + 11, 306)]), 24 * f, 15 * f)
    c.fill(sleeve, "P")
    c.outline(sleeve, "K")
    hatch(c, sleeve & c.stroke_mask(P([(116, 344), (rx + 40, 332), (rx + 11, 314)]), 10 * f), "K", 2)
    for t in (0.3, 0.55, 0.8):
        x, y = rx + 11 + (105 - rx) * t, 306 + 28 * t
        c.stroke(P([(x + 2, y - 8), (x - 2, y + 8)]), "K", 1.0, clip=sleeve)
    # the rod: a roller, its caps
    rod = c.poly_mask(P([(rx - 5, y0), (rx + 5, y0), (rx + 5, y1), (rx - 5, y1)]))
    c.fill(rod, "P")
    c.outline(rod, "K")
    c.stroke(P([(rx - 3, y0 + 1), (rx - 3, y1 - 1)]), "K", 1.0, clip=rod)
    for y in (y0, y1):
        c.ell(c.cx - rx * f, (y + top) * f, 7 * f, 3 * f, "K")
    # the hand on it
    hand = c.poly_mask(P(round_([(rx - 7, 296), (rx + 2, 292), (rx + 11, 294), (rx + 15, 304), (rx + 12, 314), (rx + 2, 316), (rx - 7, 312)], 5)))
    c.fill(hand, "P")
    c.outline(hand, "K")
    for y in (299, 304, 309):
        c.stroke(P([(rx - 6, y), (rx + 6, y + 0.5)]), "K", 1.0, clip=hand)
    if e < 0.02:                         # rolled: its band and the seal
        band = c.poly_mask(P(S([(0, y0 + 10), (9, y0 + 10), (9, y1 - 26), (0, y1 - 26)])))
        c.fill(band, "R")
        c.outline(band, "K")
        c.ell(c.cx, (y0 + 16 + top) * f, 3.5 * f, 3.5 * f, "P", clip=band)


# ── the sizes ────────────────────────────────────────────────────────────────────────────────

def fetch_size(kind, state):
    """fetch's art, the heads' hero: 144 × 180, 18 cells × 9 lines of the terminal (8 × 20 a cell)."""
    if kind == "oni":
        return oni(1.0 if state == "a" else 0.0, w=144, h=180, f=0.5, top=46, horn=0.72).image("oni")
    return angel(eyes=state == "open", w=144, h=180, f=0.5, top=50, bust=False).image("angel")


def sixel(im):
    """RGBA → a sixel: the transparent stays the terminal's (P2 = 1), one register an ink, whole."""
    w, h = im.size
    px = im.load()
    inks = sorted({px[x, y][:3] for y in range(h) for x in range(w) if px[x, y][3]})
    out = ['\x1bP0;1;0q"1;1;%d;%d' % (w, h)]
    out += ["#%d;2;%d;%d;%d" % (i, *(round(v * 100 / 255) for v in c)) for i, c in enumerate(inks)]
    for y0 in range(0, h, 6):
        for i, c in enumerate(inks):
            cols = [sum(1 << k for k in range(min(6, h - y0)) if px[x, y0 + k][3] and px[x, y0 + k][:3] == c) for x in range(w)]
            if not any(cols):
                continue
            line, x, end = ["#%d" % i], 0, max(k for k in range(w) if cols[k]) + 1
            while x < end:
                n = 1
                while x + n < end and cols[x + n] == cols[x]:
                    n += 1
                ch = chr(63 + cols[x])
                line.append("!%d%s" % (n, ch) if n > 3 else ch * n)
                x += n
            out.append("".join(line) + "$")
        out.append("-")
    return "".join(out) + "\x1b\\"


# ── the prompt's glyphs into art/icons.txt ───────────────────────────────────────────────────

def write_glyphs():
    s = sheet()
    text = ICONS.read_text(encoding="utf-8")
    for icon, name in GLYPHS:
        rows = s[name][2]
        for suffix, cut in (("", (0, 16)), ("-2", (16, 24))):
            block = f"@{icon}{suffix}\n" + "\n".join(r[cut[0]:cut[1]] for r in rows) + "\n"
            text, n = re.subn(rf"^@{re.escape(icon)}{re.escape(suffix)}\n(?:[.#]+\n)+", block.replace("\\", r"\\"), text, flags=re.M)
            if n != 1:
                raise SystemExit(f"art/icons.txt: @{icon}{suffix} found {n} times")
    ICONS.write_text(text, encoding="utf-8")


# ── the sheet to look at ─────────────────────────────────────────────────────────────────────

GROUND = {"oni": rgb("25201a"), "angel": rgb("f9f5de")}   # (the bar tile's paper, as the bar shows them)


def looks(d):
    """DIR/heads-MOOD.png: every size and state side by side, 1× above, 4× below."""
    d.mkdir(parents=True, exist_ok=True)
    s = sheet()
    for kind, states in (("oni", ("un", "a")), ("angel", ("closed", "open"))):
        mono = {"oni": D_["accent"], "angel": L_["strong"]}[kind]
        items = []
        for st in states:
            items.append(of_rows(s[f"{kind}.prompt.{st}"][2], kind, mono))
        for size in ("bar", "32"):
            for st in states:
                items.append(picture(f"{kind}.{size}.{st}"))
        for st in states:
            items.append(fetch_size(kind, st))
        if kind == "oni":
            big = [oni(0.0, f=0.8, w=240, h=320, top=64, horn=0.72), oni(1.0, f=0.8, w=240, h=320, top=64, horn=0.72)]
        else:
            big = [angel(0.0, False, f=0.82, w=240, h=330, top=70), angel(1.0, True, f=0.82, w=240, h=330, top=70)]
        big = [b.image(kind) for b in big]
        k = 4
        wide = sum(i.width * k + 12 for i in items) + 12
        tall = max(i.height for i in items) * (k + 1) + 36
        tall = max(tall, big[0].height + 24)
        sheet_im = Image.new("RGB", (max(wide, 2 * big[0].width + 36 + 200), tall + big[0].height + 12), GROUND[kind])
        x = 12
        for i in items:
            sheet_im.paste(i, (x, 12), i)
            sheet_im.paste(i.resize((i.width * k, i.height * k), Image.NEAREST), (x, 24 + max(j.height for j in items)), i.resize((i.width * k, i.height * k), Image.NEAREST))
            x += i.width * k + 12
        x = 12
        for b in big:
            sheet_im.paste(b, (x, tall), b)
            x += b.width + 12
        sheet_im.save(d / f"heads-{kind}.png")


def write_outputs():
    write_glyphs()
    themes = ROOT / "configs/home/.config/fedokawaii/themes"
    share = ROOT / "configs/home/.local/share/fedokawaii"
    for mood, kind, shut, open_ in (("dark", "oni", "un", "a"), ("light", "angel", "closed", "open")):
        picture(f"{kind}.bar.{shut}").save(themes / mood / "face.png", optimize=True)
        picture(f"{kind}.bar.{open_}").save(themes / mood / "face-open.png", optimize=True)
        (share / mood / "head.six").write_text(sixel(fetch_size(kind, shut)), encoding="ascii")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--sheet", type=pathlib.Path)
    a = ap.parse_args()
    write_outputs()
    if a.sheet:
        looks(a.sheet)


if __name__ == "__main__":
    main()
