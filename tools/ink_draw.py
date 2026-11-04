#!/usr/bin/env python3
"""tools/ink_draw.py — what the engraver adds by hand to a figure (tools/build-ink.py): horns, wild
hair, scrollwork, flames, a brocade collar, each laid down as tone or as cut lines at the working
size (3 × the final). Needs numpy, scipy and Pillow.
"""
import math

import numpy as np
from PIL import Image, ImageDraw


def spline(pts, n=48):
    """a Catmull-Rom curve through pts"""
    p = np.array(pts, dtype=np.float64)
    p = np.vstack([2 * p[0] - p[1], p, 2 * p[-1] - p[-2]])
    out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, n, endpoint=False):
            a = 2 * p[i] + (p[i + 1] - p[i - 1]) * t \
                + (2 * p[i - 1] - 5 * p[i] + 4 * p[i + 1] - p[i + 2]) * t * t \
                + (3 * p[i] - p[i - 1] - 3 * p[i + 1] + p[i + 2]) * t ** 3
            out.append(a / 2)
    out.append(p[-2])
    return np.array(out)


def normals(c):
    d = np.gradient(c, axis=0)
    d /= np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-6)
    return np.stack([-d[:, 1], d[:, 0]], 1)


def stroke_poly(c, w0, w1=0.0, ease=1.0):
    """a tapered stroke's outline: w0 wide at the start, w1 at the end"""
    t = np.linspace(0, 1, len(c))[:, None] ** ease
    w = (w0 * (1 - t) + w1 * t) / 2
    n = normals(c)
    return np.vstack([c + n * w, (c - n * w)[::-1]])


def outline(poly, w):
    """a closed outline's strip"""
    c = np.vstack([poly, poly[:1]]).astype(float)
    n = normals(c)
    return np.vstack([c + n * w / 2, (c - n * w / 2)[::-1]])


class Plate:
    """a working plate: tone (0 black … 1 paper), the figure's mask, the lines cut by hand and the
    lines cleared by hand. Each shape is drawn in its own box: a stroke costs its size, not the plate's"""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.tone = np.ones((h, w), np.float32)
        self.mask = np.zeros((h, w), bool)
        self.ink = np.zeros((h, w), np.float32)
        self.lit = np.zeros((h, w), np.float32)

    def box(self, poly):
        """the polygon rasterised in its box, clipped to the plate: (slices, mask), or (None, None)"""
        p = np.asarray(poly, dtype=np.float64)
        x0, y0 = max(int(p[:, 0].min()) - 1, 0), max(int(p[:, 1].min()) - 1, 0)
        x1, y1 = min(int(p[:, 0].max()) + 2, self.w), min(int(p[:, 1].max()) + 2, self.h)
        if x1 <= x0 or y1 <= y0:
            return None, None
        im = Image.new("1", (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(im).polygon([(float(a) - x0, float(b) - y0) for a, b in p], fill=1)
        return (slice(y0, y1), slice(x0, x1)), np.asarray(im, dtype=bool)

    def fill(self, poly, tone, figure=True):
        """a part in front: its tone, nothing cut in it yet"""
        s, m = self.box(poly)
        if s is None:
            return
        self.tone[s][m] = tone
        self.ink[s][m] = 0
        self.lit[s][m] = 0
        if figure:
            self.mask[s] |= m

    def cut(self, poly):
        s, m = self.box(poly)
        if s is not None:
            self.ink[s][m] = 1

    def clear(self, poly):
        s, m = self.box(poly)
        if s is not None:
            self.lit[s][m] = 1

    def stroke(self, pts, w0, w1=0.0, ease=1.0, n=32):
        self.cut(stroke_poly(spline(pts, n), w0, w1, ease))


def tube(plate, center, w0, w1, light=-0.35, base=0.62, ring_every=0.0, ring_depth=0.25):
    """a horn: a tapered round form on the plate's tone: dark along one side, grooved rings along it"""
    c = spline(center, 64)
    poly = stroke_poly(c, w0, w1, 0.9)
    s, m = plate.box(poly)
    if s is None:
        return
    ys, xs = np.nonzero(m)
    pts = np.stack([xs + s[1].start, ys + s[0].start], 1).astype(np.float32)
    cc = c[::max(1, len(c) // 256)].astype(np.float32)
    nn = normals(cc.astype(np.float64)).astype(np.float32)
    t = np.linspace(0, 1, len(cc))
    width = (w0 * (1 - t ** .9) + w1 * t ** .9) / 2
    best = np.zeros(len(pts), np.int32)
    side = np.zeros(len(pts), np.float32)
    for i in range(0, len(pts), 100000):
        p = pts[i:i + 100000]
        k = ((p[:, None, :] - cc[None, :, :]) ** 2).sum(2).argmin(1)
        best[i:i + 100000] = k
        side[i:i + 100000] = ((p - cc[k]) * nn[k]).sum(1) / np.maximum(width[k], 1)
    tone = base + light * side - 0.34 * side ** 2
    if ring_every:
        # each ring bows round the form: further along at its edges than at its middle
        along = t[best] + ring_every * .55 * side ** 2
        ring = np.abs(((along / ring_every) % 1) - .5) * 2
        tone -= ring_depth * np.clip(1 - ring * 4, 0, 1) * (1 - .5 * t[best])
        tone += .10 * np.clip(ring * 2 - 1.2, 0, 1)
    t_all = plate.tone[s]
    t_all[m] = np.clip(tone, .02, 1)
    plate.mask[s] |= m
    plate.ink[s][m] = 0
    plate.lit[s][m] = 0
    plate.cut(outline(poly, 6))


def lock(plate, rng, x, y, ang, length, strands, spread, wmax, turn, curl):
    """a lock of hair: a few strands along one S that ends in a curl"""
    n = 30
    path, a, p = [], ang, np.array([x, y], float)
    for i in range(n):
        q = i / n
        a += turn * (math.sin(q * math.pi * 1.6) * .075) + curl * (q ** 3) * .33
        p = p + (length / n) * np.array([math.cos(a), math.sin(a)])
        path.append(p.copy())
    path = np.array(path)
    nrm = normals(path)
    for k in range(strands):
        off = (k / max(strands - 1, 1) - .5) * spread
        amp = off * (np.sin(np.linspace(0, math.pi, n)) ** .6)
        c = path + nrm * amp[:, None] + rng.normal(0, 1.2, (n, 2))
        end = int(n * rng.uniform(.72, 1.0))
        plate.cut(stroke_poly(spline(c[:end][::2], 5), rng.uniform(.55, 1) * wmax, 0.6, ease=.75))


def volute(cx, cy, r, turns=2.2, start=0.0, sign=1, n=140, squash=1.0, tilt=0.0):
    """a scroll's spiral, from the rim inwards"""
    t = np.linspace(0, 1, n)
    a = start + sign * t * turns * 2 * math.pi
    rr = r * (1 - t) ** 1.25 + r * .02
    x, y = rr * np.cos(a), rr * np.sin(a) * squash
    ct, st = math.cos(tilt), math.sin(tilt)
    return np.stack([cx + x * ct - y * st, cy + x * st + y * ct], 1)


def scroll(plate, cx, cy, r, sign=1, w=12, start=0.0, tail=None, turns=2.3, squash=1.0, tilt=0.0):
    """a cloud scroll cut into the form: a swelling black line with a bright bevel at its side, a tail if given"""
    c = volute(cx, cy, r, turns, start, sign, squash=squash, tilt=tilt)
    n = normals(c)
    plate.clear(stroke_poly(c + n * w * .95 * sign, w * .8, w * .15, 1.0))
    plate.cut(stroke_poly(c, w, w * .22, 1.0))
    if tail is not None:
        c2 = spline([c[0]] + tail, 30)
        plate.clear(stroke_poly(c2 + normals(c2) * w * .85 * sign, w * .7, 1, 1.0))
        plate.cut(stroke_poly(c2, w, 1.5, 1.0))


def flame(plate, p0, p1, bow=0.2, width=100, lines=3, w=9, waves=1.5):
    """flame lines cut across a form: from one root to fanned tips, each an S that swells and tapers, a lit bevel beside it"""
    p0, p1 = np.array(p0, float), np.array(p1, float)
    d = p1 - p0
    L = math.hypot(*d)
    nrm = np.array([-d[1], d[0]]) / max(L, 1)
    for k in range(lines):
        q = k / max(lines - 1, 1) - .5
        pts = []
        for t in np.linspace(0, 1, 9):
            off = bow * L * math.sin(t * math.pi) + q * width * t \
                + .05 * L * math.sin(t * math.pi * 2 * waves + k * 1.3) * t
            pts.append(p0 + d * t * (1 - abs(q) * .12) + nrm * off)
        c = spline(pts, 12)
        side = 1 if bow >= 0 else -1
        plate.clear(stroke_poly(c + normals(c) * w * .8 * side, w * .55, 1, 1.0))
        plate.cut(stroke_poly(c, w, 1.5, .8))


def seigaiha(plate, poly, cell=64, w=4):
    """waves of the blue sea cut across a shape: the kimono's brocade"""
    s, m = plate.box(poly)
    if s is None:
        return
    h, wd = m.shape
    im = Image.new("L", (wd, h), 0)
    d = ImageDraw.Draw(im)
    row, y = 0, h + cell
    while y > -cell:
        x = -cell + (cell if row % 2 else 0) + (s[1].start % (2 * cell)) * -1
        while x < wd + cell:
            for k in (1.0, .72, .46):
                r = cell * k
                d.arc([x - r, y - r, x + r, y + r], 180, 360, fill=255, width=w)
            x += cell * 2
        y -= cell // 2
        row += 1
    plate.ink[s] = np.maximum(plate.ink[s], (np.asarray(im) > 127) * m.astype(np.float32))
