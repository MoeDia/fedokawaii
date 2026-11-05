#!/usr/bin/env python3
"""tools/ink_heads.py — the demon and the angel at every size under the lock (the owner, 4 Nov 19:12: no
pixel art for the heads; the masters of 19:26: the engraved Hannya, the engraved Renaissance angel).

    python3 tools/ink_heads.py [--sheet DIR] [portraits|small|glyphs|all]

One character everywhere, cut at each size, never a downscale of a larger one:
    themes/MOOD/face.png, face-open.png         the bar's end tile, 22 × 20: its ink on rows 1–18
    themes/MOOD/head-56.png, head-56-open.png   quick settings and the menus, with alpha
    themes/MOOD/head-48.png, head-48-open.png
    .local/share/fedokawaii/MOOD/head.six       fetch's portrait, a sixel of 288 × 300: 36 cells × 15 lines
    art/icons.txt @head-*                       the prompt's glyphs, one ink, 24 × 20 (GLYPHS below)
Rest: the demon's teeth locked, the angel's eyes closed. Open (while its panel is open, a failed command): the
demon roars, the angel looks. The portraits come from tools/build-ink.py's figure and the Gabriel of
art/ink/SOURCES.md, re-cut at their size; the small ones keep the lacquer's and the print's tones under lines cut
by hand at that size. Needs Pillow, numpy, scipy and the plates in ~/.cache/r27-ink/src.
"""
import argparse
import importlib.util
import math
import pathlib
import re

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parent.parent
THEMES = ROOT / "configs/home/.config/fedokawaii/themes"
SHARE = ROOT / "configs/home/.local/share/fedokawaii"
ICONS = ROOT / "art/icons.txt"
SRC = pathlib.Path.home() / ".cache/r27-ink/src"


def _load(name, rel):
    sp = importlib.util.spec_from_file_location(name, ROOT / rel)
    m = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(m)
    return m


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255


# the inks. The demon: sumi, the paper the torch lights, one shu in a roaring throat. The angel: the print's sumi,
# its paper, the ai of its wash, its gold ring
SUMI = hexc("0d0d0c")
PAPER = hexc("f0e2bc")
BONE = hexc("fbf3d4")
SHU = hexc("eb5324")
A_SUMI = hexc("141c20")
A_PAPER = hexc("fbf6df")
A_SKIN = hexc("f6ecd2")
AI = hexc("1f3a5f")
AI_WASH = hexc("6b8aa8")
GOLD = hexc("bd8a26")
GOLD_HI = hexc("e0b24a")


# ── a small plate: drawn at SS × its size, reduced smooth ─────────────────────────────────────

class Cut:
    def __init__(self, w, h, ss=16):
        self.w, self.h, self.ss = w, h, ss
        self.rgb = np.zeros((h * ss, w * ss, 3), np.float32)
        self.a = np.zeros((h * ss, w * ss), np.float32)

    def _mask(self, poly):
        im = Image.new("1", (self.w * self.ss, self.h * self.ss), 0)
        ImageDraw.Draw(im).polygon([(float(x) * self.ss, float(y) * self.ss) for x, y in poly], fill=1)
        return np.asarray(im, dtype=bool)

    def fill(self, poly, ink, clip=None):
        m = self._mask(poly)
        if clip is not None:
            m = m & clip
        self.rgb[m] = ink
        self.a[m] = 1

    def stroke(self, pts, w0, w1, ink, ease=1.0, n=24, clip=None):
        c = spline(pts, n) if len(pts) > 2 else np.array(pts, dtype=np.float64)
        self.fill(stroke_poly(c, w0, w1, ease), ink, clip)

    def dot(self, x, y, rx, ink, ry=None, tilt=0.0, clip=None):
        ry = rx if ry is None else ry
        t = np.linspace(0, 2 * math.pi, 48)
        px, py = rx * np.cos(t), ry * np.sin(t)
        ct, st = math.cos(tilt), math.sin(tilt)
        self.fill(np.stack([x + px * ct - py * st, y + px * st + py * ct], 1), ink, clip)

    def image(self, amount=.55, radius=.75):
        """smooth at its own size, sharpened as a retoucher would: RGBA, alpha premultiplied on the way"""
        pm = self.rgb * self.a[..., None]
        out = []
        for ch in (pm[..., 0], pm[..., 1], pm[..., 2], self.a):
            out.append(np.asarray(Image.fromarray(ch).resize((self.w, self.h), Image.LANCZOS), dtype=np.float32))
        out = [np.clip(ch, 0, 1) for ch in out]
        if amount:
            out = [np.clip(ch + amount * (ch - ndi.gaussian_filter(ch, radius)), 0, 1) for ch in out]
        a = out[3]
        safe = np.maximum(a, 1e-3)
        rgb = np.clip(np.stack(out[:3], 2) / safe[..., None], 0, 1)
        return Image.fromarray(np.dstack([(rgb * 255 + .5).astype(np.uint8), (a * 255 + .5).astype(np.uint8)]), "RGBA")


def spline(pts, n=24):
    """a Catmull-Rom curve through pts"""
    p = np.array(pts, dtype=np.float64)
    p = np.vstack([2 * p[0] - p[1], p, 2 * p[-1] - p[-2]])
    out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, n, endpoint=False):
            a = 2 * p[i] + (p[i + 1] - p[i - 1]) * t + (2 * p[i - 1] - 5 * p[i] + 4 * p[i + 1] - p[i + 2]) * t * t \
                + (3 * p[i] - p[i - 1] - 3 * p[i + 1] + p[i + 2]) * t ** 3
            out.append(a / 2)
    out.append(p[-2])
    return np.array(out)


def stroke_poly(c, w0, w1=0.0, ease=1.0):
    d = np.gradient(c, axis=0)
    d /= np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-6)
    n = np.stack([-d[:, 1], d[:, 0]], 1)
    t = np.linspace(0, 1, len(c))[:, None] ** ease
    w = (w0 * (1 - t) + w1 * t) / 2
    return np.vstack([c + n * w, (c - n * w)[::-1]])


# ── the demon at a menu's size: the mask's own lacquer under lines cut by hand ─────────────────

_bi = None
_mask = None


def build_ink():
    global _bi
    if _bi is None:
        _bi = _load("build_ink", "tools/build-ink.py")
    return _bi


def mask_plate():
    global _mask
    if _mask is None:
        _mask = build_ink().mask_source()
    return _mask


def oni(W, H, o, chin, mask_h):
    """the demon at a menu's size W × H: its chin on row `chin`, its mask `mask_h` tall, jaw opening o (0 shut, 1.3 the roar)"""
    bi = build_ink()
    a, m = mask_plate()
    aa, mm = bi.jaw_at(a, m, o)
    ys = np.nonzero(m)[0]
    ymin, ymax = ys.min(), ys.max()
    s = mask_h / (ymax - ymin)                # target pixels per source pixel
    k = s / .3                                # target pixels per pixel of M1 (the 1024 sheet)
    cx = W / 2
    AX = bi.AXIS
    SS = 16

    def T(mx, my):
        return cx + (mx - 512) * k, chin + (my - 906.67) * k

    def Ts(pts, sgn=1):
        return [T(512 + sgn * (x - 512), y) for x, y in pts]

    P = Cut(W, H, SS)
    dj = 43.5 * (o - 1) * k                   # what the jaw has moved, in target pixels: below the teeth

    # the mane, behind: black clumps first, then single strands of light through them, wild, no two alike
    rng = np.random.default_rng(11)
    for sgn in (-1, 1):
        roots = [(278, 410), (262, 500), (272, 610), (292, 720)]
        ends = [(52, 300), (14, 500), (34, 720), (150, 900)]
        for (rx, ry), (ex, ey) in zip(roots, ends, strict=True):
            sx, sy = T(512 + sgn * (rx - 512), ry)
            tx, ty = T(512 + sgn * (ex - 512), ey)
            tx, ty = min(max(tx, .5), W - .5), min(ty, H - .5)
            mid = ((sx + tx) / 2, (sy + ty) / 2 - abs(tx - sx) * .16)
            P.stroke([(sx, sy), mid, (tx, ty)], 170 * k, .4, SUMI, ease=.75)
        for (rx, ry), (ex, ey) in (((400, 300), (318, 150)), ((462, 272), (432, 130))):
            sx, sy = T(512 + sgn * (rx - 512), ry)
            tx, ty = T(512 + sgn * (ex - 512), ey)
            ty = max(ty, .5)
            P.stroke([(sx, sy), ((sx + tx) / 2 + sgn * 12 * k, (sy + ty) / 2), (tx, ty)], 120 * k, .4, SUMI, ease=.8)
    strands = 7
    for sgn in (-1, 1):
        for j in range(strands):
            q = (j + rng.uniform(-.3, .3)) / max(strands - 1, 1)
            ry = 420 + q * 330
            sx, sy = T(512 + sgn * (270 - 512), ry)
            L = rng.uniform(.62, 1.0)
            ex = 512 + sgn * (-512 + 40 + rng.uniform(0, 60) + 330 * (1 - L))
            ey = 300 + q * 640 + rng.uniform(-30, 30)
            tx, ty = T(ex, ey)
            tx, ty = min(max(tx, .3), W - .3), min(max(ty, .3), H - .3)
            # one long arc out of the jaw, its end falling
            b1 = rng.uniform(.10, .20)
            dx, dy = tx - sx, ty - sy
            mid = (sx + dx * .5 + dy * b1 * sgn, sy + dy * .5 - abs(dx) * b1)
            ink = PAPER * rng.uniform(.62, .95)
            P.stroke([(sx, sy), mid, (tx, ty)], .8, .22, ink, ease=.7)

    # the horns: bone with black rings, over the mane, their tips to the corners
    for sgn in (-1, 1):
        bx, by = T(512 + sgn * 148, 352)
        tip = (1.2, .6)
        tx, ty = (tip[0], tip[1]) if sgn < 0 else (W - tip[0], tip[1])
        L = math.hypot(tx - bx, ty - by)
        nx, ny = (ty - by) / L, -(tx - bx) / L
        bow = .10 * L * sgn
        mx, my = (bx + tx) / 2 + nx * bow, (by + ty) / 2 + ny * bow
        c = spline([(bx, by), (mx, my), (tx, ty)], 40)
        w0 = 96 * k
        P.fill(stroke_poly(c, w0 + 1.0, .9, .9), SUMI)
        P.fill(stroke_poly(c, w0, .35, .9), BONE)
        # the rings: nearer together towards the tip
        rings = int(L / 2.2)
        for r in range(1, rings):
            q = r / rings
            i = int(q ** .82 * (len(c) - 1))
            d = c[min(i + 1, len(c) - 1)] - c[max(i - 1, 0)]
            d /= max(np.linalg.norm(d), 1e-6)
            nr = np.array([-d[1], d[0]])
            w = (w0 * (1 - (i / (len(c) - 1)) ** .9) + .35 * (i / (len(c) - 1)) ** .9) / 2 + .3
            p = c[i]
            P.stroke([p - nr * w, p + d * .25 * w, p + nr * w], .66, .66, SUMI, n=6)

    # the mask, the lacquer's own tones: lifted, with a hard foot
    x0, y0 = AX - (cx / s), ymax - (chin / s)
    grid_y, grid_x = np.mgrid[0:H * SS, 0:W * SS].astype(np.float32)
    sx = x0 + (grid_x + .5) / (SS * s)
    sy = y0 + (grid_y + .5) / (SS * s)
    lum = aa @ np.array([.3, .59, .11], dtype=np.float32)
    grey = aa[..., 0] * .75 + lum * .25
    grey = ndi.gaussian_filter(grey, .55 / s / 2)
    tone = ndi.map_coordinates(grey, [sy, sx], order=1, mode="nearest")
    sil = ndi.map_coordinates(mm.astype(np.float32), [sy, sx], order=1, mode="nearest") > .5
    wide = ndi.gaussian_filter(tone, 8 * SS)
    t = np.clip(.60 + (tone - wide) * 1.9 + (wide - .55) * .30, 0, 1)
    t = np.clip((t - .30) / .42, 0, 1)
    t = t * t * (3 - 2 * t)
    # the lit planes clean, the shadows the lacquer's
    t = .46 + t * .54
    face = SUMI[None, None] * (1 - t[..., None]) + PAPER[None, None] * t[..., None]
    # the silhouette's edge in black, one cut
    edge = ndi.binary_dilation(sil, iterations=int(SS * .55)) & ~sil
    P.rgb[edge] = SUMI
    P.a[edge] = 1
    P.rgb[sil] = face[sil]
    P.a[sil] = 1
    clip = sil

    # ── the lines cut by hand, on the mask ──────────────────────────────────────────────────
    for sgn in (-1, 1):
        # the sockets: black, wide, slanting up to the temple
        ex, ey = T(512 + sgn * (405 - 512), 552)
        tilt = sgn * math.radians(-14)
        P.dot(ex, ey, 84 * k, SUMI, 60 * k, tilt, clip)
        # the eye: a staring plate, its pupil black and turned in
        P.dot(ex, ey + 6 * k, 70 * k, BONE, 35 * k, tilt, clip)
        px, py = T(512 + sgn * (418 - 512), 560)
        P.dot(px, py, 22 * k, SUMI, None, 0, clip)
        # the brow: heavy, cutting the eye's top, knit down to the bridge; the ridge above it lit
        P.stroke(Ts([(306, 478), (392, 506), (462, 528), (492, 566)], sgn), 30 * k, 40 * k, SUMI, n=12, clip=clip)
        P.stroke(Ts([(320, 440), (396, 462), (468, 490)], sgn), 3 * k, 15 * k, BONE, n=12, clip=clip)
        # the fold from the nose round the mouth, the cheek's ball above it lit
        P.stroke(Ts([(420, 640), (372, 650), (338, 692), (352, 748)], sgn), 12 * k, 20 * k, SUMI, n=12, clip=clip)
        # the cheeks' and temples' scrolls: M1's own mark
        for (vx, vy, r) in ((330, 632, 34), (356, 366, 32)):
            x, y = T(512 + sgn * (vx - 512), vy)
            P.dot(x, y, r * k, BONE, None, 0, clip)
            c = []
            for i in range(40):
                q = i / 39
                an = (q * 2 * 2 * math.pi) * sgn
                c.append((x + (r * k) * (1 - q) * math.cos(an), y + (r * k) * (1 - q) * math.sin(an)))
            P.fill(stroke_poly(np.array(c), .85, .55), SUMI, clip)
    # the bridge, bright between the sockets; the furrow above it, flames from the knot: M1's scrollwork, as much as the size carries
    P.fill(Ts([(492, 530), (532, 530), (556, 620), (468, 620)]), PAPER, clip)
    P.stroke(Ts([(512, 330), (508, 420), (512, 500)]), .2, 8 * k + .4, SUMI, n=12, clip=clip)
    for sgn in (-1, 1):
        P.stroke(Ts([(498, 480), (440, 430), (452, 360), (404, 312)], sgn), 13 * k, 1.5 * k, SUMI, n=12, clip=clip)
        P.stroke(Ts([(468, 470), (392, 424), (356, 392)], sgn), 11 * k, 1.5 * k, SUMI, n=12, clip=clip)
    # the nose: broad, its wings cut, the slit of the nostrils black
    for sgn in (-1, 1):
        P.stroke(Ts([(490, 600), (440, 625), (416, 668), (452, 700)], sgn), 8 * k, 16 * k, SUMI, n=12, clip=clip)
    P.fill(np.array(Ts([(440, 682), (512, 668), (584, 682), (590, 702), (512, 696), (434, 702)])), SUMI, clip)
    # the mouth
    up = [(352, 708), (400, 730), (455, 752), (512, 762), (569, 752), (624, 730), (672, 708)]   # the upper teeth's top, the lip's under edge
    low = [(672, 708), (640, 795), (585, 840), (512, 852), (439, 840), (384, 795), (352, 708)]  # the lower lip's upper edge
    upT = Ts(up)
    lowT = [(x, y + dj * min(1, max(0, (172 - abs(ux - 512)) / 60))) for (x, y), (ux, _) in zip(Ts(low), low, strict=True)]
    P.fill(np.array(upT + lowT[1:-1]), SHU if o > 1 else SUMI, clip)
    # the upper teeth: a bright band under the lip, cut into teeth; the fangs long over what is below
    band = 34 * k
    top = spline(upT, 12)
    P.fill(np.vstack([top, (top + np.array([0, band]))[::-1]]), BONE, clip)
    teeth = (396, 440, 484, 540, 584, 628)
    for ux in teeth:
        x, y = T(ux, 742 if abs(ux - 512) > 90 else 758)
        P.stroke([(x, y - .2), (x, y + band * 1.05)], .75, .75, SUMI)
    for sgn in (-1, 1):
        x, y = T(512 + sgn * (428 - 512), 742)
        P.fill([(x - 12 * k - .35, y + 8 * k), (x + 12 * k + .35, y + 8 * k), (x + sgn * .15, y + 86 * k + .6)], BONE, clip)
    # the lower teeth, in the jaw
    lowc = spline(lowT[1:-1], 12)
    q = np.abs(lowc[:, 0] - cx) < 96 * k
    if q.sum() > 3:
        lc = lowc[q]
        P.fill(np.vstack([lc, (lc - np.array([0, 28 * k + .3]))[::-1]]), BONE, clip)
        for ux in (-64, -22, 22, 64):
            x = cx + ux * k
            y = np.interp(x, lc[:, 0], lc[:, 1])
            P.stroke([(x, y), (x, y - 28 * k - .3)], .7, .7, SUMI)
    # the chin's dimple, the wave of the lower lip
    lip = Ts([(390, 862), (452, 884), (512, 870), (572, 884), (634, 862)])
    P.stroke([(x, y + dj) for x, y in lip], 7 * k + .2, 7 * k + .2, SUMI, n=8, clip=clip)
    return P


# ── the angel: the print, its plate read once ───────────────────────────────────────────────

_gab = None
# the plate's own pixels from a sheet read at .6598 (x from 170.5): what the lines below are written in
BUST = .6598
BUST_X0 = 170.5
FACE_POLY = [(742, 215), (800, 188), (870, 190), (915, 225), (918, 290), (905, 345), (882, 395), (850, 425), (805, 442), (755, 420), (712, 375), (705, 300)]
FIGURE_POLY = [(85, 530), (78, 400), (95, 200), (118, 100), (165, 50), (238, 28), (252, 52), (355, 7), (432, 40), (395, 130), (420, 190), (405, 235),
               (470, 255), (505, 190), (525, 245), (530, 50), (558, 15), (640, 110), (665, 195), (640, 250), (615, 285), (632, 395), (668, 470), (640, 525),
               (560, 530), (520, 455), (495, 430), (470, 462), (525, 650), (525, 845), (478, 880), (380, 885), (272, 952), (150, 932), (70, 865), (100, 805),
               (155, 790), (165, 715), (198, 620), (170, 520), (198, 430), (150, 430), (135, 480)]


def gabriel():
    """the Gabriel: (ink coverage 0…1, its solid silhouette) at the plate's size, the frame's line off"""
    global _gab
    if _gab is None:
        ie = build_ink().ie
        g = np.asarray(Image.open(SRC / "schongauer-gabriel.jpg").convert("L"), dtype=np.float32) / 255
        flat = g / np.maximum(ie.blur(g, 120), .2)
        ink = np.clip((.70 - flat) / .22, 0, 1)
        pm = Image.new("L", (g.shape[1], g.shape[0]), 0)
        ImageDraw.Draw(pm).polygon([(x * 4, y * 4) for x, y in FIGURE_POLY], fill=255)
        ink *= np.asarray(pm, dtype=np.float32) / 255
        ink[:30] = 0
        # the figure, solid: its lines closed, its holes filled, at a quarter of the plate
        q = 4
        h, w = ink.shape[0] // q, ink.shape[1] // q
        small = np.asarray(Image.fromarray(ink).resize((w, h), Image.BOX), dtype=np.float32) > .22
        st = ndi.generate_binary_structure(2, 2)
        solid = ndi.binary_fill_holes(ndi.binary_closing(small, st, iterations=5))
        lab, n = ndi.label(solid)
        solid = lab == (1 + int(np.argmax(ndi.sum(solid, lab, range(1, n + 1)))))
        round_ = ndi.gaussian_filter(solid.astype(np.float32), 2.5)
        sil = np.asarray(Image.fromarray(round_).resize((ink.shape[1], ink.shape[0]), Image.BICUBIC), dtype=np.float32) > .5
        _gab = (ink, sil)
    return _gab


def angel_print(W, H, ks, hx, hy, ring, chop, ss=4):
    """the angel at fetch's size: the print's own lines, the ai washed where they gather, the gold ring. The sheet's
    (790, 290) on (hx, hy), ks target pixels per sheet pixel; ring: the halo's radius; chop: the row she ends on"""
    ink, sil = gabriel()
    P = Cut(W, H, ss)
    yy, xx = np.mgrid[0:H * ss, 0:W * ss].astype(np.float32)
    bx = 790 + ((xx + .5) / ss - hx) / ks
    by = 290 + ((yy + .5) / ss - hy) / ks
    sx, sy = BUST_X0 + bx / BUST, by / BUST
    per = 1 / (ks * BUST * ss)                # plate pixels per working pixel
    line = ndi.map_coordinates(ndi.gaussian_filter(ink, per * .5), [sy, sx], order=1, mode="constant")
    solid = ndi.map_coordinates(sil.astype(np.float32), [sy, sx], order=1, mode="constant") > .5
    solid &= yy < chop * ss
    # the ring of light, behind, its rays outside
    cx, cy = hx, hy - 6 * ks
    t = np.linspace(0, 2 * math.pi, 160)
    outer = ring + 1.5
    P.fill(np.stack([cx + outer * np.cos(t), cy + outer * np.sin(t)], 1), GOLD)
    P.a[P._mask(np.stack([cx + ring * np.cos(t), cy + ring * np.sin(t)], 1))] = 0
    n, r0 = 72, outer + .8
    for k in range(n):
        an = k / n * 2 * math.pi
        r1 = r0 + (6 if k % 2 else 13)
        P.fill(stroke_poly(np.array([[cx + r0 * math.cos(an), cy + r0 * math.sin(an)], [cx + r1 * math.cos(an), cy + r1 * math.sin(an)]]), .85, .5), GOLD)
    # the figure, her paper under the lines, one cut round her so she reads on any ground
    wash = np.clip(ndi.gaussian_filter(line, ss * 2.6) * 2.1, 0, 1)
    wash = np.clip(wash * wash * 1.25, 0, 1)
    body = A_PAPER[None, None] * (1 - .78 * wash[..., None]) + AI_WASH[None, None] * .78 * wash[..., None]
    cov = np.clip(line, 0, 1) ** .72
    fig = body * (1 - cov[..., None]) + A_SUMI[None, None] * cov[..., None]
    edge = ndi.binary_dilation(solid, iterations=max(int(ss * .35), 1)) & ~solid
    P.rgb[edge] = A_SUMI
    P.a[edge] = 1
    P.rgb[solid] = fig[solid]
    P.a[solid] = 1
    return P


def sixel(im):
    """RGBA → a sixel: the transparent stays the terminal's (P2 = 1), one register an ink, whole"""
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


# ── the bar's coins: 22 × 20, drawn at that size in its own whole shapes: the same mask, the same head ─────

def oni_bar(roar):
    P = Cut(22, 20)

    def both(pts):
        return [pts, [(22 - x, y) for x, y in pts]]

    chin = 18.7 if roar else 17.9
    # the mane: its black behind the temples, a tuft each side
    for pts in both([(6.0, 5.0), (2.2, 6.5), (.8, 11.5), (2.8, 16.5), (6.2, 15.4)]):
        P.fill(spline(pts + pts[:1], 6), SUMI)
    # the horns: bone, ringed, to the corners
    for pts in both([(7.0, 6.2), (4.2, 4.2), (1.0, 1.1)]):
        c = spline(pts, 24)
        P.fill(stroke_poly(c, 4.0, 1.0, .9), SUMI)
        P.fill(stroke_poly(c, 3.1, .35, .9), BONE)
        for q in (.34, .56, .76):
            i = int(q * (len(c) - 1))
            d = c[i + 1] - c[i - 1]
            d /= np.linalg.norm(d)
            nr = np.array([-d[1], d[0]])
            w = (3.1 * (1 - q) + .35 * q) / 2 + .2
            P.stroke([c[i] - nr * w, c[i] + nr * w], .62, .62, SUMI)
    # the mask
    half = [(11, 2.9), (7.8, 3.3), (5.5, 4.9), (4.2, 7.4), (3.8, 10.2), (4.4, 12.9), (5.8, 15.5), (8.0, chin - 1.2), (11, chin)]
    out = spline(half, 6)
    poly = np.vstack([out, (np.array([22, 0]) + out[::-1] * np.array([-1, 1]))[1:-1]])
    P.fill(stroke_poly(np.vstack([poly, poly[:1]]), .9, .9), SUMI)
    P.fill(poly, PAPER)
    clip = P._mask(poly)
    for sgn in (-1, 1):
        def X(x, sgn=sgn):
            return 11 + sgn * x
        # the socket black, the plate, the pupil
        P.dot(X(3.5), 9.0, 3.2, SUMI, 2.4, sgn * math.radians(-14), clip)
        P.dot(X(3.5), 9.5, 2.75, BONE, 1.6, sgn * math.radians(-14), clip)
        P.dot(X(3.0), 9.6, .72, SUMI, None, 0, clip)
        # the brow, knit down to the bridge
        P.stroke([(X(7.0), 6.0), (X(3.8), 6.9), (X(.9), 8.5)], .95, 1.25, SUMI, clip=clip)
        # the fold round the mouth
        P.stroke([(X(2.4), 11.6), (X(4.2), 12.2), (X(5.0), 13.8)], .6, .6, SUMI, clip=clip)
    P.stroke([(11, 4.6), (11, 7.4)], .25, .7, SUMI)
    # the nose: its wings, the slit
    for sgn in (-1, 1):
        P.stroke([(11 + sgn * 1.0, 10.6), (11 + sgn * 2.0, 11.7), (11 + sgn * 1.3, 12.7)], .55, .7, SUMI, clip=clip)
    P.stroke([(9.5, 12.7), (11, 12.45), (12.5, 12.7)], .7, .7, SUMI)
    # the mouth, ear to ear
    up = [(6.2, 13.1), (8.2, 14.0), (11, 14.45), (13.8, 14.0), (15.8, 13.1)]
    lo = [(15.8, 13.1), (14.6, chin - 2.4), (11, chin - 1.45), (7.4, chin - 2.4), (6.2, 13.1)]
    top = spline(up, 8)
    bot = spline(lo, 8)
    P.fill(np.vstack([top, bot[1:-1]]), SHU if roar else SUMI, clip)
    # the upper teeth, the fangs
    P.fill(np.vstack([top[4:-4], (top[4:-4] + np.array([0, .95]))[::-1]]), BONE, clip)
    for x in (8.2, 9.9, 12.1, 13.8):
        P.stroke([(x, 13.2), (x, 15.6)], .42, .42, SUMI, clip=clip)
    for sgn in (-1, 1):
        x = 11 + sgn * 2.9
        P.fill([(x - .8, 14.2), (x + .8, 14.2), (x, 16.5 if roar else 16.1)], BONE, clip)
    if roar:
        P.stroke([(8.6, chin - 2.3), (11, chin - 1.7), (13.4, chin - 2.3)], .55, .55, SUMI, clip=clip)
    return P


def angel_bar(eyes):
    P = Cut(22, 20)
    cx, cy, r = 11, 10, 8.1
    t = np.linspace(0, 2 * math.pi, 160)
    P.fill(np.stack([cx + (r + .9) * np.cos(t), cy + (r + .9) * np.sin(t)], 1), GOLD)
    P.a[P._mask(np.stack([cx + r * np.cos(t), cy + r * np.sin(t)], 1))] = 0
    clip = P._mask(np.stack([cx + (r + .15) * np.cos(t), cy + (r + .15) * np.sin(t)], 1))
    # the curls: indigo masses falling either side of the face, the left the larger, a few strokes of sumi and light
    for mass in ([(9.0, 4.4), (5.6, 5.4), (3.6, 8.4), (2.6, 12.0), (3.4, 16.4), (7.4, 18.6), (9.6, 15.0), (8.2, 10.0)],
                 [(13.0, 4.2), (15.6, 5.8), (16.8, 9.0), (17.2, 13.4), (15.8, 17.0), (13.2, 17.8), (14.2, 12.0), (15.0, 8.0)]):
        P.fill(spline(mass + mass[:1], 6), AI, clip)
    for a_, m_, b_ in (((6.8, 6.6), (4.6, 10.0), (5.8, 13.4)), ((4.2, 12.2), (3.8, 14.8), (5.6, 16.8)), ((7.6, 11.6), (6.6, 14.4), (8.2, 17.0))):
        P.stroke([a_, m_, b_], .7, .4, A_SUMI, clip=clip)
    for a_, m_, b_ in (((5.4, 8.6), (3.9, 11.0), (4.6, 13.0)), ((6.4, 13.2), (5.4, 15.4), (6.6, 17.4)), ((16.0, 8.8), (16.3, 12.0), (15.4, 15.4))):
        P.stroke([a_, m_, b_], .55, .3, AI_WASH, clip=clip)
    # the collar under her chin
    P.fill([(8.4, 15.4), (11.2, 16.4), (13.8, 15.2), (14.4, 19), (7.8, 19)], A_PAPER, clip)
    P.stroke([(8.8, 15.3), (11.2, 16.6), (13.4, 15.1)], .6, .6, A_SUMI, clip=clip)
    # the face, turned a little to her left
    face = [(11.5, 4.9), (14.4, 5.6), (15.5, 8.2), (15.0, 11.0), (13.4, 13.5), (11.4, 14.6), (9.3, 13.7), (7.6, 11.4), (7.2, 8.4), (8.8, 5.7)]
    P.fill(spline(face + face[:1], 6), A_SUMI)
    inner = [(x + (11.4 - x) * .09, y + (9.7 - y) * .09) for x, y in face]
    P.fill(spline(inner + inner[:1], 6), A_PAPER)
    if eyes:
        for x, y in ((9.6, 9.1), (13.3, 9.2)):
            P.stroke([(x - 1.15, y - .25), (x, y - .85), (x + 1.05, y - .2)], .55, .42, A_SUMI, n=8)
            P.dot(x + .05, y + .1, .6, A_SUMI)
    else:
        for x, y in ((9.6, 9.1), (13.3, 9.2)):
            P.stroke([(x - 1.25, y - .3), (x, y + .55), (x + 1.15, y - .2)], .8, .55, A_SUMI, n=8)
    P.stroke([(12.2, 9.8), (12.4, 11.2), (11.7, 11.55)], .42, .42, A_SUMI, n=8)
    P.stroke([(10.4, 12.75), (11.4, 12.6), (12.6, 12.8)], .7, .5, SHU * .72 + A_SUMI * .28, n=8)
    # the wreath: leaves across the brow, the cross above
    for x, y, a_ in ((4.8, 6.8, -2.6), (6.4, 5.2, -2.3), (8.2, 4.3, -2.0), (14.4, 4.3, -1.15), (16.2, 5.2, -.85), (17.4, 6.8, -.55)):
        P.stroke([(x, y), (x + 1.7 * math.cos(a_), y + 1.7 * math.sin(a_))], 1.05, .2, A_SUMI)
    arc = [(4.6, 7.2), (6.8, 5.2), (11, 4.3), (15.2, 5.2), (17.6, 7.2)]
    P.stroke(arc, .62, .62, A_SUMI, n=8)
    P.stroke([(11, 4.3), (11, 1.4)], .62, .62, A_SUMI)
    P.stroke([(10.1, 2.3), (11.9, 2.3)], .58, .58, A_SUMI)
    return P


def angel_cut(W, H, ks, hx, hy, ring, eyes):
    """the angel at a menu's size: her locks, wreath, face and halo cut by hand after the print: (hx, hy) where the
    sheet's (790, 290) falls"""
    P = Cut(W, H)

    def T(bx, by):
        return hx + (bx - 790) * ks, hy + (by - 290) * ks

    def Ts(pts):
        return [T(*q) for q in pts]

    cx, cy = hx, hy - 6 * ks
    t = np.linspace(0, 2 * math.pi, 160)
    band = .85
    # the ring of light, its rays
    for k in range(32):
        an = k / 32 * 2 * math.pi
        r0, r1 = ring + band + .3, ring + band + (1.6 if k % 2 else 2.9)
        if r1 > 0 and 0 <= cx + r1 * math.cos(an) <= W and 0 <= cy + r1 * math.sin(an) <= H:
            P.fill(stroke_poly(np.array([[cx + r0 * math.cos(an), cy + r0 * math.sin(an)], [cx + r1 * math.cos(an), cy + r1 * math.sin(an)]]), .5, .28), GOLD)
    P.fill(np.stack([cx + (ring + band) * np.cos(t), cy + (ring + band) * np.sin(t)], 1), GOLD)
    P.a[P._mask(np.stack([cx + ring * np.cos(t), cy + ring * np.sin(t)], 1))] = 0
    # the medal: the bust ends on the ring
    yy, xx = np.mgrid[0:H * P.ss, 0:W * P.ss].astype(np.float32)
    d = np.hypot((xx + .5) / P.ss - cx, (yy + .5) / P.ss - cy)
    clip = ~((yy / P.ss > cy) & (d > ring))

    def lock(p0, p1, w0, w1, amp=20, waves=2.4, phase=0.0, curl=1):
        p0, p1 = np.array(p0, float), np.array(p1, float)
        L = np.linalg.norm(p1 - p0)
        n = np.array([-(p1 - p0)[1], (p1 - p0)[0]]) / L
        pts = [T(*(p0 + (p1 - p0) * q + n * amp * math.sin(q * math.pi * 2 * waves + phase) * min(1, q * 2.5))) for q in np.linspace(0, 1, 11)]
        c = spline(pts, 8)
        P.fill(stroke_poly(c, w0 * ks + .75, w1 * ks + .55, .9), A_SUMI, clip)
        P.fill(stroke_poly(c, w0 * ks, w1 * ks, .9), AI, clip)
        # the lock's light, down its middle
        off = c + np.array([.0, .0])
        P.fill(stroke_poly(off, .5, .18, .9), AI_WASH, clip)
        if curl:
            ex, ey = c[-1]
            r = 17 * ks
            P.dot(ex, ey, r + .3, A_SUMI, None, 0, clip)
            P.dot(ex, ey, r * .55, AI_WASH, None, 0, clip)

    # the locks, back to front: the left falls far over the shoulder, the right closer
    for p0, p1, w0, w1, ph in (((690, 230), (512, 410), 62, 30, .4), ((660, 262), (500, 520), 66, 30, 1.8), ((708, 300), (556, 590), 72, 32, 2.9),
                               ((725, 340), (640, 610), 66, 28, .9), ((738, 215), (590, 470), 58, 28, 3.6), ((712, 380), (700, 600), 56, 26, 2.2)):
        lock(p0, p1, w0, w1, phase=ph)
    for p0, p1, w0, w1, ph in (((930, 235), (972, 400), 50, 24, 1.1), ((925, 300), (962, 540), 56, 26, 2.6), ((908, 370), (900, 600), 58, 26, .5)):
        lock(p0, p1, w0, w1, amp=16, phase=ph)
    # the neck and the collar
    P.fill(Ts([(740, 392), (872, 412), (858, 512), (762, 520)]), A_SKIN, clip)
    P.stroke(Ts([(790, 440), (800, 480), (810, 515)]), .4, .4, AI_WASH, clip=clip)
    P.fill(Ts([(716, 500), (806, 560), (866, 500), (925, 640), (640, 640)]), A_PAPER, clip)
    P.stroke(Ts([(716, 500), (806, 560), (866, 500)]), .7, .7, A_SUMI, clip=clip)
    P.stroke(Ts([(806, 560), (800, 640)]), .5, .5, A_SUMI, clip=clip)
    # the hair above the brow
    P.fill(Ts([(696, 262), (722, 190), (780, 146), (860, 150), (922, 200), (936, 268), (900, 220), (840, 190), (770, 196), (724, 236)]), AI, clip)
    # the face, the hatching of its shadow side as a wash
    outline = spline(Ts(FACE_POLY + FACE_POLY[:1]), 8)
    P.fill(stroke_poly(outline, .75, .75), A_SUMI)
    P.fill(outline, A_SKIN)
    fm = P._mask(outline)
    shade = np.clip(1 - np.hypot(((xx + .5) / P.ss - T(835, 300)[0]) / (98 * ks), ((yy + .5) / P.ss - T(835, 300)[1]) / (150 * ks)), 0, 1)
    wash = (1 - np.clip(shade * 3.2, 0, 1)) * .34
    P.rgb[fm] = (A_SKIN[None, None] * (1 - wash[..., None]) + AI_WASH[None, None] * wash[..., None])[fm]
    lw = max(.55, 6.4 * ks)
    P.stroke(Ts([(783, 268), (815, 250), (850, 268)]), lw, lw * .6, A_SUMI, n=8)            # the brows
    P.stroke(Ts([(878, 272), (898, 262), (916, 282)]), lw, lw * .6, A_SUMI, n=8)
    P.stroke(Ts([(868, 272), (874, 330), (866, 358), (842, 362)]), lw * .8, lw * .8, A_SUMI, n=8)   # the nose
    P.stroke(Ts([(812, 384), (842, 378), (872, 388)]), lw * .9, lw * .7, SHU * .62 + A_SUMI * .38, n=8)   # the mouth
    if eyes:
        P.stroke(Ts([(790, 288), (820, 272), (851, 292)]), .68, .5, A_SUMI, n=8)
        P.dot(*T(822, 289), 10.5 * ks + .1, A_SUMI)
        P.stroke(Ts([(878, 296), (896, 282), (914, 300)]), .68, .5, A_SUMI, n=8)
        P.dot(*T(897, 297), 9.5 * ks + .1, A_SUMI)
    else:
        P.stroke(Ts([(790, 286), (820, 300), (851, 288)]), .72, .5, A_SUMI, n=8)
        P.stroke(Ts([(878, 292), (896, 304), (914, 294)]), .72, .5, A_SUMI, n=8)
    # the wreath: two branches meeting over her brow, their leaves, the little cross
    for side in (-1, 1):
        tip = (535, 192) if side < 0 else (1032, 186)
        arc = [(800, 150), ((800 + tip[0]) / 2, 128), tip]
        c = spline(Ts(arc), 10)
        P.fill(stroke_poly(c, 1.0, .35), A_SUMI)
        for i in range(2, len(c), 3):
            q = i / (len(c) - 1)
            base = math.atan2(c[i][1] - c[i - 1][1], c[i][0] - c[i - 1][0])
            for off in (-.75, .75):
                L = (70 - 22 * q) * ks + .7
                e = (c[i][0] + L * math.cos(base + off), c[i][1] + L * math.sin(base + off))
                P.stroke([tuple(c[i]), e], 1.05, .15, A_SUMI, ease=.8)
    P.stroke(Ts([(850, 128), (850, 36)]), .75, .75, A_SUMI)
    P.stroke(Ts([(812, 66), (888, 66)]), .7, .7, A_SUMI)
    return P


# ── the portraits: the figures re-cut at fetch's size ───────────────────────────────────────

SIX_W, SIX_H = 288, 300


def oni_portrait(o=1.3):
    """the lock's figure, cut anew at fetch's size: the same mask, horns, mane and collar, its hatching a size
    the eye can read"""
    bi = build_ink()
    saved = bi.SW, bi.SH, bi.K, bi.DX, bi.DY
    bi.SW, bi.SH, bi.K, bi.DX, bi.DY = SIX_W, SIX_H, .3015, SIX_W * 3 // 2, -45
    try:
        a, m = bi.mask_source()
        bk_i, bk_a = bi.demon_back()
        mk_i, mk_a, box = bi.demon_mask(a, m, o)
        fr_i, fr_l = bi.demon_front(box)
    finally:
        bi.SW, bi.SH, bi.K, bi.DX, bi.DY = saved
    ink = bk_i * (1 - mk_a) + mk_i * mk_a
    ink = np.maximum(ink, fr_i * mk_a) * (1 - fr_l * mk_a)
    alpha = np.maximum(np.maximum(bk_a, mk_a), fr_i)
    yy, xx = np.mgrid[0:SIX_H, 0:SIX_W].astype(np.float32)
    far = np.clip((np.hypot((xx - SIX_W / 2) / 1.0, (yy - 165) / 1.1) - 92) / 70, 0, 1)
    fall = (1 - .42 * far) * (1 - .35 * np.clip((yy - 240) / 60, 0, 1))
    fall = np.maximum(fall, mk_a)
    paper = PAPER[None, None] * fall[..., None]
    rgb = paper * (1 - ink[..., None]) + SUMI[None, None] * ink[..., None]
    return Image.fromarray(np.dstack([(rgb * 255 + .5).astype(np.uint8), (np.clip(alpha, 0, 1) * 255 + .5).astype(np.uint8)]), "RGBA")


def angel_portrait():
    return angel_print(SIX_W, SIX_H, .25, 170, 118, 112, SIX_H - 1).image(amount=.4)


def for_sixel(im, ground, inks=24, gold=None):
    """a sixel's pixels are whole: a thin line's edge mixed with the mood's ink, the rest in few registers"""
    a = np.asarray(im, dtype=np.float32)
    rgb, al = a[..., :3] / 255, a[..., 3:] / 255
    mix = rgb * al + ground * (1 - al)
    keep = al[..., 0] > .30
    flat = Image.fromarray((np.clip(mix, 0, 1) * 255 + .5).astype(np.uint8), "RGB").quantize(inks, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    flat = np.array(flat)
    if gold is not None:
        # (the one warm ink a median cut would average away)
        warm = (rgb[..., 0] - rgb[..., 2]) > .28
        flat[warm] = (gold * 255 + .5).astype(np.uint8)
    return Image.fromarray(np.dstack([flat, keep.astype(np.uint8) * 255]), "RGBA")


# ── the prompt's glyphs: one ink, 24 × 20, the only size with no shading: woodcuts of the same two faces, by hand ─

def half(rows):
    return [r + r[::-1] for r in rows]


GLYPHS = {
    "head-oni": half([
        "............",
        "#...........",
        "##..........",
        ".##.........",
        "..##........",
        "..###....##.",
        "...###.####.",
        "....#######.",
        "#....##..###",
        ".#...#.....#",
        ".....#.##..#",
        "##...#.##..#",
        ".....#.....#",
        "#....##...##",
        ".....#.#####",
        ".....#..#...",
        "......#.#.##",
        "......#.....",
        ".......#####",
        "............"]),
    "head-oni-roar": half([
        "............",
        "#...........",
        "##..........",
        ".##.........",
        "..##........",
        "..###....##.",
        "...###.####.",
        "....#######.",
        "#....##..###",
        ".#...#.....#",
        ".....#.##..#",
        "##...#.##..#",
        ".....#.....#",
        "#....#.#####",
        ".....#.#.#.#",
        ".....#.#....",
        "......#.....",
        "......#.#.##",
        ".......#####",
        "............"]),
    "head-angel": [
        "........................",
        "...........#............",
        "..........###...........",
        "......#.#..#..#.#.......",
        "....#.##########.#......",
        "...#.############.#.....",
        "..#.#####.....#####.#...",
        "..#.####.......####.#...",
        ".#.####..........####.#.",
        ".#.####.#.#..#.#.####.#.",
        ".#.####..#....#..####.#.",
        ".#.####.....#....####.#.",
        ".#.####.....##...####.#.",
        ".#.#####........#####.#.",
        "..#.#####..##..#####.#..",
        "..#.######....######.#..",
        "...#.######..######.#...",
        "....#.####....####.#....",
        ".....#.###....###.#.....",
        "........................"],
    "head-angel-open": [
        "........................",
        "...........#............",
        "..........###...........",
        "......#.#..#..#.#.......",
        "....#.##########.#......",
        "...#.############.#.....",
        "..#.#####.....#####.#...",
        "..#.####.......####.#...",
        ".#.####.##....##.####.#.",
        ".#.####..#....#..####.#.",
        ".#.####..#....#..####.#.",
        ".#.####.....#....####.#.",
        ".#.####.....##...####.#.",
        ".#.#####........#####.#.",
        "..#.#####..##..#####.#..",
        "..#.######....######.#..",
        "...#.######..######.#...",
        "....#.####....####.#....",
        ".....#.###....###.#.....",
        "........................"],
}


def write_glyphs():
    """into art/icons.txt, as its two glyphs each, 16 and 8 wide"""
    text = ICONS.read_text(encoding="utf-8")
    for icon, rows in GLYPHS.items():
        for suffix, cut in (("", (0, 16)), ("-2", (16, 24))):
            block = f"@{icon}{suffix}\n" + "\n".join(r[cut[0]:cut[1]] for r in rows) + "\n"
            text, n = re.subn(rf"^@{re.escape(icon)}{re.escape(suffix)}\n(?:[.#]+\n)+", lambda _, b=block: b, text, flags=re.M)
            if n != 1:
                raise SystemExit(f"art/icons.txt: @{icon}{suffix} found {n} times")
    ICONS.write_text(text, encoding="utf-8")


def glyph_image(rows, ink):
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == "#":
                im.putpixel((x, y), tuple(int(v * 255 + .5) for v in ink) + (255,))
    return im


# ── what they are written into ───────────────────────────────────────────────────────────────

SMALL = {
    "dark": lambda size, st: {
        56: lambda: oni(56, 56, 1.3 if st else 0, 55.5, 45).image(),
        48: lambda: oni(48, 48, 1.3 if st else 0, 47.5, 39).image(),
        22: lambda: oni_bar(st).image(.8, .55),
    }[size](),
    "light": lambda size, st: {
        56: lambda: angel_cut(56, 56, .092, 29, 30.5, 24.8, st).image(.45, .6),
        48: lambda: angel_cut(48, 48, .079, 25, 26, 21.2, st).image(.45, .6),
        22: lambda: angel_bar(st).image(.7, .55),
    }[size](),
}


def write_small():
    for mood, make in SMALL.items():
        d = THEMES / mood
        for st, suffix in ((0, ""), (1, "-open")):
            make(22, st).save(d / f"face{suffix}.png", optimize=True)
            for size in (56, 48):
                make(size, st).save(d / f"head-{size}{suffix}.png", optimize=True)


def write_portraits():
    (SHARE / "dark/head.six").write_text(sixel(for_sixel(oni_portrait(), SUMI)), encoding="ascii")
    (SHARE / "light/head.six").write_text(sixel(for_sixel(angel_portrait(), A_PAPER, gold=GOLD)), encoding="ascii")


def sheets(d):
    """DIR/ink-heads-MOOD.png: every size and state side by side on its real grounds, 1× above, 4× below; the
    portrait at its size. Reads what was written."""
    d.mkdir(parents=True, exist_ok=True)
    # (the bar's paper, from its fibre; a menu's surface; the terminal's ground)
    grounds = {"dark": ((38, 33, 27), (0x1c, 0x19, 0x16), (0x18, 0x17, 0x15), hexc("eb5324")),
               "light": ((249, 246, 224), (0xec, 0xdf, 0xb3), (0xe8, 0xe3, 0xc2), hexc("121b1b"))}
    pair = {"dark": ("head-oni", "head-oni-roar"), "light": ("head-angel", "head-angel-open")}
    for mood, (tile, menu, term, gink) in grounds.items():
        small = []
        for name in pair[mood]:
            small.append((glyph_image(GLYPHS[name], gink), term))
        for suffix in ("", "-open"):
            small.append((Image.open(THEMES / mood / f"face{suffix}.png").convert("RGBA"), tile))
        for size in (48, 56):
            for suffix in ("", "-open"):
                small.append((Image.open(THEMES / mood / f"head-{size}{suffix}.png").convert("RGBA"), menu))
        z = 4
        w = sum(i.width * z + 12 for i, _ in small) + 12
        h = 12 + 56 + 12 + 56 * z + 12
        six = portrait_of(SHARE / mood / "head.six")
        out = Image.new("RGB", (w + 288 + 36, max(h, 300 + 24)), menu)
        x = 12
        for im, g in small:
            b = Image.new("RGBA", im.size, g + (255,))
            b.alpha_composite(im)
            b = b.convert("RGB")
            out.paste(b, (x, 12))
            out.paste(b.resize((b.width * z, b.height * z), Image.NEAREST), (x, 80))
            x += im.width * z + 12
        b = Image.new("RGBA", (288 + 24, out.height), term + (255,))
        b.alpha_composite(six, (12, 12))
        out.paste(b.convert("RGB"), (w + 12, 0))
        out.save(d / f"ink-heads-{mood}.png")


def portrait_of(path):
    """a sixel read back, pixel for pixel"""
    six = path.read_text(encoding="ascii")
    m = re.fullmatch(r'\x1bP0;1;0q"1;1;(\d+);(\d+)(.*)\x1b\\', six, re.S)
    w, h = int(m[1]), int(m[2])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    regs, x, y, reg = {}, 0, 0, 0
    for tok in re.finditer(r"#(\d+);2;(\d+);(\d+);(\d+)|#(\d+)|!(\d+)(.)|(\$)|(-)|([?-~])", m[3]):
        if tok[1]:
            regs[int(tok[1])] = tuple(round(int(tok[i]) * 255 / 100) for i in (2, 3, 4))
        elif tok[5]:
            reg = int(tok[5])
        elif tok[8]:
            x = 0
        elif tok[9]:
            x, y = 0, y + 6
        else:
            n, ch = (int(tok[6]), tok[7]) if tok[6] else (1, tok[10])
            bits = ord(ch) - 63
            for dx in range(n):
                for k in range(6):
                    if bits >> k & 1 and y + k < h:
                        px[x + dx, y + k] = (*regs[reg], 255)
            x += n
    return im


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--sheet", type=pathlib.Path)
    ap.add_argument("what", nargs="?", default="all", choices=("portraits", "small", "glyphs", "all"))
    a = ap.parse_args()
    if a.what in ("small", "all"):
        write_small()
    if a.what in ("portraits", "all"):
        write_portraits()
    if a.what in ("glyphs", "all"):
        write_glyphs()
    if a.sheet:
        sheets(a.sheet)


if __name__ == "__main__":
    main()
