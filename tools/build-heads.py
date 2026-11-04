#!/usr/bin/env python3
"""tools/build-heads.py — the two heads, one character sheet (art direction §1; the owner, 4 Nov:
"less colours, more conventional, more RED; monotone, classic Japanese"; docs/art/heads.md).

    python3 tools/build-heads.py            # writes what the heads are made into (below)
    python3 tools/build-heads.py --sheet DIR   # also every size side by side, 1× and 4×, for the eye

An oni and a Kannon, never downscaled: the small sizes are pixels by hand (art/heads.txt: the left
half, mirrored when built), the large ones brush strokes at their own size (oni(), kannon() below:
a line's width is chosen for the size, not scaled from another). Writes, all committed:
    art/icons.txt                         the prompt's glyphs (then tools/build-icons.py)
    themes/MOOD/face.png, face-open.png   the bar's end tile, 22 × 20, the tile's paper through the rest
    themes/MOOD/face-big.png              quick settings' middle, 56 × 56
    .local/share/fedokawaii/MOOD/head.six fetch's picture, a sixel of 128 × 160: 16 cells × 8 lines
tools/build-lock.py takes the lock's heads from here.

Each head has two states at every size. The oni: 吽 shut, the teeth locked, and 阿 open, as the
temple guardians' pair (A-Un); by Noh's demon masks — shikami's grimace, tobide's open mouth. The
Kannon: her eyes closed, or half open with the gaze lowered.
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

# the inks, by the palette's names. The oni: the seal's red in three values, sumi, bone. The Kannon:
# sumi, gofun, gold leaf (and its shade), the seal's red (and its deep)
INKS = {
    "oni": {"K": D_["lo"], "D": D_["accent_lo"], "R": D_["accent"], "H": D_["accent_hi"], "W": D_["strong"]},
    "kannon": {"K": L_["strong"], "P": L_["key"], "G": L_["gold"], "g": L_["yellow"], "R": L_["accent"], "r": D_["select"]},
}
# the prompt's glyphs: one ink, 24 × 20, drawn as art/icons.txt's two glyphs, 16 and 8 wide
GLYPHS = (("head-oni", "oni.prompt.un"), ("head-oni-roar", "oni.prompt.a"),
          ("head-kannon", "kannon.prompt.closed"), ("head-kannon-open", "kannon.prompt.open"))


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
        if not line or line.startswith("#"):
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
            for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
                if (y0 <= yc < y1) or (y1 <= yc < y0):
                    xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[::2], xs[1::2]):
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

def oni(open_=0.0, w=216, h=326, f=1.0, top=30, mane=True):
    """OPEN_: how far the mouth is open, 0 (the teeth locked) … 1. Design units: x from the mirror
    line, y down; F the size. Key lines stay 1 px whatever the size."""
    c = Canvas(w, h)
    o, j = open_, 24 * open_

    def P(pts):
        return [(c.cx - x * f, (y + top) * f) for x, y in pts]

    if mane:     # locks of sumi behind everything, flaring from the crown down both sides
        locks = [((5, 44), (7, 28), (1, 14)), ((16, 44), (22, 26), (18, 12)), ((28, 44), (38, 28), (40, 14)),
                 ((70, 66), (92, 44), (104, 14)), ((78, 82), (102, 66), (116, 44)), ((84, 104), (108, 94), (122, 74)),
                 ((88, 126), (112, 122), (126, 106)), ((92, 146), (114, 150), (126, 136)), ((92, 166), (112, 176), (124, 166)),
                 ((88, 186), (106, 200), (118, 196)), ((80, 204), (94, 222), (106, 224)), ((62, 234 + j), (70, 254 + j), (82, 262 + j)),
                 ((42, 250 + j), (48, 270 + j), (58, 282 + j)), ((20, 256 + j), (22, 278 + j), (30, 294 + j)), ((5, 258 + j), (5, 276 + j), (2, 292 + j))]
        hair = c.poly_mask(P(round_([(0, 34), (40, 30), (72, 56), (96, 110), (100, 160), (88, 206), (60, 180), (0, 90)])))
        for a, b, d in locks:
            hair |= c.stroke_mask(P([a, b, d]), 24 * f, prof=taper)
        c.fill(hair, "K")
        for a, b, d in locks[3:]:
            c.stroke(P([(a[0] + 6, a[1] + 4), (b[0], b[1] + 2), (d[0] - 2, d[1] + 3)]), "D", 1.6 * f, prof=taper, clip=hair)
        for x0 in (10, 26, 44, 60):
            c.stroke(P([(x0, 58), (x0 + 3, 44), (x0 + 12, 34)]), "D", 1.6 * f, prof=taper, clip=hair)

    # the horns: ringed bone
    hc = [(40, 58), (56, 40), (68, 24), (74, 6), (68, -12)]
    horn = c.stroke_mask(P(hc), 30 * f, prof=lambda t: (1 - t) ** 0.62 + 0.04)
    c.fill(horn, "W")
    path = spline(P(hc))
    for t in (0.10, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8):
        k = int(t * (len(path) - 1))
        x0, y0 = path[k]
        dx, dy = path[min(k + 3, len(path) - 1)] - path[max(k - 3, 0)]
        n = np.hypot(dx, dy)
        nx, ny = -dy / n, dx / n
        hw = 15 * f * (1 - t) ** 0.62 + 1
        c.stroke([(x0 - nx * hw, y0 - ny * hw), (x0 + dx / n * 2.5 * f, y0 + dy / n * 2.5 * f), (x0 + nx * hw, y0 + ny * hw)], "K", 1.0, clip=horn)
    c.outline(horn, "K")

    # the face: forehead flat, cheekbones jutting, a notch, the jaw squared
    half = [(0, 50), (30, 50), (58, 60), (76, 78), (84, 104), (86, 128), (98, 150), (92, 176), (84, 198), (72, 222 + j * 0.5),
            (50, 240 + j * 0.9), (24, 252 + j), (0, 254 + j)]
    face = c.poly_mask(P(round_(half + [(-x, y) for x, y in reversed(half[1:-1])], 4)))
    c.fill(face, "R")
    # deep shu, cut as planes
    for plane in ([(100, 96), (70, 66), (64, 84), (72, 100), (78, 128), (92, 146), (100, 150)],                  # the temple
                  [(10, 122), (24, 108), (56, 96), (72, 106), (70, 130), (48, 148), (26, 148), (14, 138)],      # the socket
                  [(96, 178), (78, 190), (72, 200), (78, 226), (100, 214)],                                     # under the cheekbone
                  [(4, 106), (9, 106), (18, 140), (30, 156), (24, 158), (12, 146), (6, 128)],                   # the nose's side
                  [(36, 168), (50, 172), (66, 190), (72, 214), (62, 200), (50, 182)],                           # the fold's shade
                  [(0, 226 + j), (24, 222 + j), (44, 218 + j), (58, 226 + j * 0.9), (30, 238 + j), (0, 240 + j)]):  # under the lip
        c.poly(P(plane), "D", clip=face)
    # lit shu: only ridges
    for pts, wd in (([(14, 104), (36, 92), (68, 86)], 3.0), ([(1, 122), (1, 150)], 5.0), ([(0, 158), (7, 160)], 5.0),
                    ([(58, 146), (76, 148), (92, 160)], 3.5), ([(10, 244 + j), (30, 240 + j)], 3.0)):
        c.stroke(P(pts), "H", wd * f, prof=swell, clip=face)
    # the forehead: three furrows, the knot over the nose
    for y0, xa, xb in ((60, 8, 46), (69, 12, 56), (78, 18, 62)):
        c.stroke(P([(xa, y0 + 4), ((xa + xb) / 2, y0 - 2), (xb, y0 + 4)]), "K", 2.2 * f, prof=swell, clip=face)
    c.stroke(P([(4, 94), (3, 82), (7, 68)]), "K", 3 * f, prof=taper, clip=face)
    c.stroke(P([(10, 96), (12, 86), (16, 78)]), "K", 1.8 * f, prof=taper, clip=face)
    # the eyes: bone almonds slanting out, a small hard pupil under the lid
    eye = c.poly_mask(P(round_([(14, 134), (28, 124), (46, 116), (64, 110), (66, 120), (54, 134), (36, 140), (22, 139)], 5)))
    c.fill(eye, "W")
    c.ell(c.cx - 38 * f, (125 + top) * f, 7 * f, 7.5 * f, "K", clip=eye)
    c.outline(eye, "K")
    c.stroke(P([(10, 138), (24, 122), (46, 112), (70, 104), (78, 98)]), "K", 5 * f, prof=lambda t: 0.3 + 0.9 * math.sin(math.pi * t ** 0.8))
    c.stroke(P([(16, 146), (36, 150), (58, 140)]), "K", 1.8 * f, prof=swell)
    c.stroke(P([(66, 122), (76, 124), (84, 130)]), "K", 1.8 * f, prof=taper)
    c.stroke(P([(62, 130), (72, 136), (80, 144)]), "K", 1.8 * f, prof=taper)
    # the brows: sumi flames, knotted in the middle
    c.stroke(P([(3, 112), (20, 98), (46, 86), (80, 76)]), "K", 15 * f, prof=lambda t: 0.45 + 0.75 * math.sin(math.pi * t ** 0.65))
    for x0, y0, x1, y1, wd in ((70, 76, 94, 60, 7), (56, 80, 76, 60, 7), (42, 84, 56, 66, 6), (28, 92, 38, 76, 5), (76, 80, 100, 76, 6)):
        c.stroke(P([(x0, y0), ((x0 + x1) / 2 + 1, (y0 + y1) / 2 + 2), (x1, y1)]), "K", wd * f, prof=taper)
    # the nose: flat, wings flaring, nostrils cut
    c.stroke(P([(4, 176), (14, 180), (28, 174), (33, 160), (26, 148)]), "K", 2.6 * f, prof=swell)
    c.ell(c.cx - 14 * f, (170 + top) * f, 7.5 * f, 4 * f, "K", rot=0.2)
    c.stroke(P([(6, 176), (0, 180)]), "K", 1.2 * f)
    for y0 in (112, 118):
        c.stroke(P([(0, y0 + 1), (6, y0), (11, y0 + 2)]), "K", 1.2 * f)
    c.stroke(P([(9, 150), (7, 134), (5, 122)]), "K", 1.2 * f)
    # the folds: nose to the corner of the mouth, the cheek over them
    c.stroke(P([(34, 156), (54, 166), (72, 188), (80, 216)]), "K", 4.0 * f, prof=swell)
    c.stroke(P([(44, 150), (64, 154), (86, 168)]), "K", 2.0 * f, prof=swell)

    def tusk(y0, tall):
        pts = [(50, y0), (57, y0 - tall * 0.5), (55, y0 - tall)]
        m = c.stroke_mask(P(pts), 13 * f, prof=lambda t: (1 - t) ** 0.7 + 0.05)
        c.fill(m, "W")
        c.outline(m, "K")

    def lips(outer, inner):
        lm = c.poly_mask(P(round_(outer + [(-x, y) for x, y in reversed(outer[1:-1])])))
        mm = c.poly_mask(P(round_(inner + [(-x, y) for x, y in reversed(inner[1:-1])])))
        c.fill(lm & ~mm, "D")
        c.outline(lm, "K")
        return mm

    if o == 0:
        # 吽 shut: the teeth locked between drawn lips, a line that bites, the fangs and tusks over them
        mm = lips([(0, 178), (16, 170), (38, 171), (58, 184), (72, 208), (58, 214), (44, 218), (24, 221), (0, 222)],
                  [(0, 186), (16, 179), (38, 180), (56, 191), (66, 206), (56, 206), (44, 208), (24, 211), (0, 212)])
        c.fill(mm, "W")
        c.outline(mm, "K", only="D")
        c.stroke(P([(0, 199), (24, 196), (44, 197), (66, 206)]), "K", 2.2 * f, prof=lambda t: 0.7 + 0.4 * math.sin(math.pi * t), clip=mm)
        for x0 in (0.5, 11, 22, 33, 43, 53):
            c.stroke(P([(x0, 178), (x0 + 0.6 * x0 / 20, 216)]), "K", 1.1 * f, clip=mm)
        fang = c.stroke_mask(P([(47, 182), (49, 192), (46, 202)]), 11 * f, prof=lambda t: (1 - t) ** 0.7 + 0.05) & mm
        c.fill(fang, "W")
        c.outline(fang, "K", clip=mm)
        c.stroke(P([(0, 226), (20, 225), (42, 219)]), "K", 2.0 * f, prof=swell)
        for x0 in (0.5, 8, 15):      # the chin's crumple
            c.stroke(P([(x0, 234), (x0 + x0 * 0.12, 241)]), "K", 1.2 * f)
        tusk(216, 44)
    else:
        # 阿 open, by how far: lips drawn back, the teeth, the gate
        def upper(ex):
            return [(0, 186 - ex), (16, 178 - ex), (38, 179 - ex), (58, 191 - ex * 0.6), (66 + 4 * o, 206 + 4 * o)]

        def lower(ex):
            return [(66 + 4 * o, 206 + 4 * o), (58, 200 + 16 * o + ex), (44, 194 + 36 * o + ex), (24, 188 + 50 * o + ex), (0, 188 + 56 * o + ex)]
        mm = lips(upper(9) + lower(10)[1:-1], upper(0) + lower(0)[1:-1])
        c.fill(mm, "K")
        if o > 0.4:     # the throat's rim of deep shu, the tongue low
            c.fill(mm & ~erode(erode(erode(mm))), "D")
            tongue = c.poly_mask(P(round_([(0, 186 + 45 * o), (14, 186 + 43 * o), (28, 186 + 45 * o), (32, 186 + 56 * o), (0, 186 + 60 * o)])))
            c.fill(tongue, "D", clip=mm)
            c.stroke(P([(0, 188 + 45 * o), (0, 186 + 54 * o)]), "K", 1.2 * f)
        c.outline(mm, "K", only="D")

        def teeth(xs, y_at, tall, wd, up):
            for x0 in xs:
                y0, s = y_at(x0), -1 if up else 1
                t = [(x0 - wd / 2, y0 - s * 3), (x0 + wd / 2, y0 - s * 3), (x0 + wd / 2 - 0.5, y0 + s * tall * 0.55), (x0, y0 + s * tall), (x0 - wd / 2 + 0.5, y0 + s * tall * 0.55)]
                m = c.poly_mask(P(t)) & mm
                c.fill(m, "W")
                c.outline(m, "K", clip=mm)

        def low(x):
            return 188 + 56 * o - (x / 58) ** 2 * (34 * o + 2)

        def high(x):
            return 186 - 7 * (x / 16 if x < 16 else 1 - (x - 16) / 42 * 0.9)
        teeth((7, 18, 29), low, 8, 10, True)
        teeth((39,), low, 7, 8, True)
        teeth((6, 17, 28), high, 10, 10, False)
        teeth((38,), high, 9, 8, False)
        fang = c.stroke_mask(P([(48, 186), (50, 198 + 4 * o), (46, 206 + 8 * o)]), 12 * f, prof=lambda t: (1 - t) ** 0.7 + 0.05) & mm
        c.fill(fang, "W")
        c.outline(fang, "K", clip=mm)
        tusk(216 + 22 * o, 42 + 8 * o)
        c.stroke(P([(0, 240 + 22 * o), (22, 238 + 21 * o), (44, 228 + 16 * o)]), "K", 1.8 * f, prof=swell)
    c.outline(face, "K", only="DR")
    return c.mirrored()


# ── the Kannon, large ────────────────────────────────────────────────────────────────────────

def petal(c, P, bx, by, ang, ln, wd):
    """one lotus petal from its base: two brush curves meeting in a sharp tip; gofun, its tip the
    seal's red over a step of dither, a key line, a vein"""
    ca, sa = math.cos(ang), math.sin(ang)

    def at(u, v):
        return (bx + u * sa + v * ca, by - u * ca + v * sa)
    side = spline([at(0, 0), at(ln * 0.22, wd * 0.36), at(ln * 0.52, wd * 0.5), at(ln * 0.82, wd * 0.2), at(ln, 0)], per=8)
    back = spline([at(ln, 0), at(ln * 0.82, -wd * 0.2), at(ln * 0.52, -wd * 0.5), at(ln * 0.22, -wd * 0.36), at(0, 0)], per=8)
    m = c.poly_mask(P([tuple(p) for p in side] + [tuple(p) for p in back[1:]]))
    c.fill(m, "P")
    u0 = ln * 0.64
    bowl = spline([at(u0 + ln * 0.12, wd * 0.6), at(u0, 0), at(u0 + ln * 0.12, -wd * 0.6)], per=8)
    tm = c.poly_mask(P([tuple(p) for p in bowl] + [at(ln * 1.1, -wd * 0.6), at(ln * 1.1, wd * 0.6)])) & m
    c.fill(tm, "R")
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    c.fill(dilate(dilate(tm)) & m & ~tm & ((xx + yy) % 2 == 0), "R")
    c.outline(m, "K")
    c.stroke(P([at(ln * 0.12, 0), at(ln * 0.55, 0)]), "K", 1.0, clip=m)


def lotus(c, P, o, f, top, by):
    """the flower by how far it is open (O: 0 the bud … 1): seen from a little above, a rosette round
    its heart, the far petals behind the heart, the near ones before it; shut, all of them upright,
    the near ones wrapping the far."""
    e, deg = o * o * (3 - 2 * o), math.pi / 180
    yc, hw, hh = by - 34 * e, 46 * e, 9 * e

    def ring(angles, l1, w1, in_=0.9):
        for th in angles:
            sn, cs = math.sin(th * deg), math.cos(th * deg)
            bx, by_ = sn * 6 * (1 - e) + sn * hw * in_ * e, by * (1 - e) + (yc - cs * hh * in_) * e
            tx, ty = sn * 5 * (1 - e) + (sn * hw * in_ + sn * l1) * e, (by - 88 + abs(th) / 180 * 16) * (1 - e) + (yc - cs * hh * in_ - cs * l1 * 0.62) * e
            ln = math.hypot(tx - bx, ty - by_)
            petal(c, P, bx, by_, math.atan2(tx - bx, by_ - ty), ln, 30 * (1 - e) + w1 * e)
    # the far petals, the sides (shut, only those that show)
    ring((0, 24, -24) if e < 0.02 else (0, 24, -24, 48, -48, 72, -72, 96, -96), 54, 30)
    if e > 0.2:     # the heart: lacquer in a gold rim, where the password lies
        c.ell(c.cx, (yc + top) * f, (hw + 2) * f, (hh + 2) * f, "G")
        c.ell(c.cx, (yc + top) * f, hw * f, hh * f, "r")
        a, b = hw + 2.5, hh + 2.5
        c.outline(c.poly_mask(P(round_([(a, yc), (a * 0.72, yc - b * 0.72), (0, yc - b), (-a * 0.72, yc - b * 0.72), (-a, yc), (-a * 0.72, yc + b * 0.72), (0, yc + b), (a * 0.72, yc + b * 0.72)], 8))), "K")
    # the near ones
    ring((150, -150, 180) if e < 0.02 else (122, -122, 150, -150, 180), 44, 30, 1.04)


def kannon(open_=0.0, eyes=False, w=216, h=352, f=1.0, top=6, bust=True):
    """OPEN_: how far the lotus is open, 0 … 1; EYES: half open, the gaze lowered. BUST: down to the
    hands and the flower, or the head and shoulders only."""
    c = Canvas(w, h)

    def P(pts):
        return [(c.cx - x * f, (y + top) * f) for x, y in pts]

    def S(pts, per=6):
        return P(round_(pts, per))

    # the nimbus: a ring of gold between two sumi lines, kirikane's dots on it, centred on the face
    yy, xx = np.mgrid[0:h, 0:w]
    cy = (116 + top) * f
    r = np.hypot(xx + 0.5 - c.cx, yy + 0.5 - cy) / f
    ang = np.arctan2(yy + 0.5 - cy, xx + 0.5 - c.cx)
    ring = (r >= 100) & (r < 108)
    c.a[ring] = "G"
    c.a[(r >= 100 - 1 / f) & (r < 100)] = "K"
    c.a[(r >= 108) & (r < 108 + 1 / f)] = "K"
    a = np.round(ang / (2 * np.pi / 48)) * (2 * np.pi / 48)
    c.a[(np.hypot(c.cx + 104 * f * np.cos(a) - xx - 0.5, cy + 104 * f * np.sin(a) - yy - 0.5) < 1.5 * f) & ring] = "g"
    # the long hair: sumi, falling to the shoulders; the top-knot
    c.poly(S([(0, 28), (30, 30), (56, 46), (74, 80), (80, 120), (82, 166), (86, 204), (84, 228), (64, 232), (58, 190), (54, 150), (0, 120)]), "K")
    c.poly(S([(0, 2), (14, 4), (26, 16), (28, 32), (20, 44), (0, 48)]), "K")
    # the robe: white, wide, in long brush lines
    robe = c.poly_mask(P([(0, 198), (24, 200), (40, 208), (84, 226), (112, 262), (120, 320), (118, 400), (0, 400)]))
    c.fill(robe, "P")
    c.outline(robe, "K")
    neck = c.poly_mask(S([(0, 186), (22, 186), (24, 204), (32, 216), (0, 236)]))
    c.fill(neck, "P")
    c.stroke(P([(23, 190), (24, 204), (34, 216)]), "K", 1.5 * f, prof=swell)
    for y0 in (198, 206):
        c.stroke(P([(0, y0 + 2), (10, y0 + 1), (19, y0 - 3)]), "K", 1.0)
    # the collar: a deep V edged in gold
    c.stroke(P([(0, 256), (20, 234), (40, 216), (58, 208)]), "G", 5 * f)
    c.stroke(P([(0, 252), (20, 231), (40, 213), (58, 205)]), "K", 1.0)
    c.stroke(P([(0, 261), (21, 239), (42, 221), (62, 212)]), "K", 1.0)
    for pts in ([(62, 226), (84, 250), (96, 292), (94, 340)], [(46, 240), (66, 270), (76, 306), (72, 340)], [(92, 240), (108, 276), (112, 320)]):
        c.stroke(P(pts), "K", 2.4 * f, prof=swell)
    if bust:      # kirikane on the robe: cut gold flowers on a slanted lattice; the necklace, its jewels
        yy, xx = np.mgrid[0:h, 0:w]
        on = robe & (c.a == "P")
        lat = 9
        grid = ((xx // lat) + (yy // lat)) % 2 == 0
        dot = (np.abs(xx % lat - lat // 2) + np.abs(yy % lat - lat // 2) <= 1) & grid
        c.fill(dot & on, "G")
        c.stroke(P([(0, 236), (16, 228), (32, 216), (44, 208)]), "G", 2.6 * f)
        for x0, y0 in ((0, 236), (14, 229), (28, 219), (40, 211)):
            c.ell(c.cx - x0 * f, (y0 + top) * f, 2.2 * f, 2.2 * f, "R")
    # the face: full, a soft oval
    fo = [(0, 62), (26, 64), (48, 78), (58, 108), (57, 138), (48, 166), (28, 186), (0, 192)]
    face = c.poly_mask(P(round_(fo + [(-x, y) for x, y in reversed(fo[1:-1])], 8)))
    c.fill(face, "P")
    c.stroke(P([(57, 138), (48, 166), (28, 186), (0, 192)]), "K", 1.6 * f, prof=lambda t: 0.5 + 0.7 * t)
    # the hair's edge on the brow, parted; kewari, the fine strands a print's hair is carved in
    c.poly(S([(0, 62), (18, 68), (40, 80), (52, 104), (58, 128), (70, 120), (66, 80), (42, 54), (0, 46)]), "K")
    for x0, y0 in ((6, 66), (13, 69), (20, 72), (27, 77), (34, 83), (40, 90), (45, 97), (49, 105)):
        c.stroke(P([(x0 - 1, y0 - 2), (x0 + 0.5, y0 + 2.5)]), "K", 1.0, clip=face)
    # the ear, long-lobed, its gold drop
    ear = c.poly_mask(S([(56, 112), (66, 112), (70, 128), (66, 152), (64, 170), (58, 170), (56, 150)]))
    c.fill(ear, "P")
    c.outline(ear, "K")
    c.stroke(P([(61, 122), (64, 134), (60, 150)]), "K", 1.0)
    drop = c.poly_mask(S([(56, 178), (61, 170), (67, 178), (61, 186)], 4))
    c.fill(drop, "G")
    c.outline(drop, "K")
    # the crown (hōkan): three peaks of gold, the small Amida in its middle, red jewels
    crown = [(0, 18), (7, 26), (12, 36), (24, 42), (34, 30), (42, 42), (56, 52), (58, 64), (40, 62), (20, 56), (0, 54)]
    cm = c.poly_mask(P(crown + [(-x, y) for x, y in reversed(crown[1:-1])]))
    c.fill(cm, "G")
    c.outline(cm, "K")
    c.stroke(P([(0, 49), (22, 51), (44, 57)]), "K", 1.0, clip=cm)
    for x0, y0 in ((14, 45), (30, 45), (46, 53)):
        c.ell(c.cx - x0 * f, (y0 + top) * f, 2.2 * f, 2.2 * f, "R")
    cc = c.poly_mask(P(round_([(6, 34), (0, 26), (-6, 34), (0, 42)], 8)))
    c.fill(cc, "P")
    c.outline(cc, "K", clip=cm)
    c.ell(c.cx, (32 + top) * f, 1.8 * f, 1.8 * f, "g")
    # the features, in the thinnest brush: the urna, the brow running into the nose
    c.ell(c.cx, (95 + top) * f, 3.2 * f, 3.2 * f, "R")
    c.stroke(P([(50, 109), (32, 101), (14, 105), (8, 118)]), "K", 1.8 * f, prof=swell)
    c.stroke(P([(8, 118), (7.5, 146)]), "K", 1.0)
    c.stroke(P([(15, 121), (30, 119), (46, 121)]), "K", 1.0)
    if eyes:      # half open, the gaze lowered: a slit under a heavy lid
        eye = c.poly_mask(S([(14, 131), (28, 129), (48, 128), (50, 130), (30, 135), (17, 134)], 5))
        c.fill(eye, "P")
        c.ell(c.cx - 30 * f, (131 + top) * f, 4.2 * f, 4.8 * f, "K", clip=eye)
        c.stroke(P([(12, 132), (28, 127.5), (52, 127)]), "K", 2.8 * f, prof=lambda t: 0.6 + 0.6 * math.sin(math.pi * t))
        c.stroke(P([(17, 136), (32, 137), (48, 131)]), "K", 1.0)
    else:
        c.stroke(P([(13, 130), (28, 137), (50, 127)]), "K", 2.8 * f, prof=lambda t: 0.4 + 0.8 * math.sin(math.pi * t))
    c.stroke(P([(12, 153), (7, 156), (0, 155)]), "K", 1.4 * f, prof=swell)
    # the lips: small, a smile in the corners
    c.poly(S([(0, 168), (4, 166.5), (8, 168.5), (12, 170), (7, 170.5), (0, 170)]), "R")
    c.poly(S([(0, 170), (7, 170.5), (10, 170), (5, 173.5), (0, 174)]), "r")
    c.stroke(P([(0, 170), (7, 170), (13, 169)]), "K", 1.0)
    c.stroke(P([(0, 180), (7, 179.5)]), "K", 1.0)
    if bust:
        # the hands (dhyāna): palms up, fingers across, the thumbs touching under the flower
        hand = c.poly_mask(S([(0, 316), (14, 312), (38, 311), (52, 317), (57, 328), (46, 338), (22, 342), (0, 340)]))
        c.fill(hand, "P")
        c.outline(hand, "K")
        for pts in ([(5, 322), (26, 319), (50, 323)], [(7, 329), (28, 327), (50, 331)], [(9, 335), (28, 334), (42, 336)]):
            c.stroke(P(pts), "K", 1.0, clip=hand)
        thumb = c.poly_mask(S([(1, 312), (10, 305), (22, 306), (32, 314), (20, 318), (6, 318)], 5))
        c.fill(thumb, "P")
        c.outline(thumb, "K")
        c.stroke(P([(60, 304), (54, 322), (58, 344)]), "G", 4 * f)
        c.stroke(P([(62, 304), (56, 322), (60, 344)]), "K", 1.0)
        c.stroke(P([(57.5, 304), (51.5, 322), (55.5, 344)]), "K", 1.0)
        lotus(c, P, open_, f, top, 314)
    return c.mirrored()


# ── the sizes ────────────────────────────────────────────────────────────────────────────────

def fetch_size(kind, state):
    """fetch's art: 128 × 160, 16 cells × 8 lines of the terminal (8 × 20 a cell), one key line."""
    if kind == "oni":
        return oni(1.0 if state == "a" else 0.0, w=128, h=160, f=0.5, top=14, mane=False).image("oni")
    return kannon(eyes=state == "open", w=128, h=160, f=0.5, top=6, bust=False).image("kannon")


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
            line, x = ["#%d" % i], 0
            while x < w:
                n = 1
                while x + n < w and cols[x + n] == cols[x]:
                    n += 1
                ch = chr(63 + cols[x])
                line.append("!%d%s" % (n, ch) if n > 3 else ch * n)
                x += n
            out.append("".join(line).rstrip("?") + "$")
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
            text, n = re.subn(rf"^@{re.escape(icon)}{re.escape(suffix)}\n(?:[.#]+\n)+", lambda _: block, text, flags=re.M)
            if n != 1:
                raise SystemExit(f"art/icons.txt: @{icon}{suffix} found {n} times")
    ICONS.write_text(text, encoding="utf-8")


# ── the sheet to look at ─────────────────────────────────────────────────────────────────────

GROUND = {"oni": rgb("25201a"), "kannon": rgb("f9f5de")}   # (the bar tile's paper, as the bar shows them)


def looks(d):
    """DIR/heads-MOOD.png: every size and state side by side, 1× above, 4× below."""
    d.mkdir(parents=True, exist_ok=True)
    s = sheet()
    for kind, states in (("oni", ("un", "a")), ("kannon", ("closed", "open"))):
        mono = {"oni": D_["accent"], "kannon": L_["strong"]}[kind]
        items = []
        for st in states:
            items.append(of_rows(s[f"{kind}.prompt.{st}"][2], kind, mono))
        for size in ("bar", "32", "56"):
            for st in states:
                items.append(picture(f"{kind}.{size}.{st}"))
        for st in states:
            items.append(fetch_size(kind, st))
        if kind == "oni":
            big = [oni(0.0, w=216, h=326, f=0.9, top=30), oni(1.0, w=216, h=326, f=0.9, top=30)]
        else:
            big = [kannon(0.0, False, w=216, h=330, f=0.9), kannon(1.0, True, w=216, h=330, f=0.9)]
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
    for mood, kind, shut, open_ in (("dark", "oni", "un", "a"), ("light", "kannon", "closed", "open")):
        picture(f"{kind}.bar.{shut}").save(themes / mood / "face.png", optimize=True)
        picture(f"{kind}.bar.{open_}").save(themes / mood / "face-open.png", optimize=True)
        picture(f"{kind}.56.{shut}").save(themes / mood / "face-big.png", optimize=True)
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
