#!/usr/bin/env python3
"""tools/build-lock.py — the lock screen's scenes as the desktop's own pixel art (T19q 8, art
direction §8), at the wallpapers' grid: 640 × 360, shown 3 × 3 on 1080p (2 × 2, 4 × 4 … elsewhere:
whole pixels). All drawn here, no picture behind it.

    python3 tools/build-lock.py [--preview DIR]

The owner, 4 Nov: "the demon facing me; a secret key opens his mouth; I type; he closes his mouth
like he ate it; the dungeon far denser, ancient carvings of demons and angels fighting" — "the same
for the angel, be smart".

dark: a castle wall (ishigaki) under a stone beam, the war marching along it, the thunder key, the
quote gilded on its lintel (口は禍の門, the mouth is the gate of misfortune), a shimenawa rope with its
paper, two torches lighting three stepped pools stone by stone, flames carved behind the head, two
panels of carved battle — oni against tennin — and the sea's waves on the step; before it all the
samurai demon of tools/build-heads.py. His mouth is the gate: it opens, the password glows in it,
ember by ember; it shuts.
light: the same story in the sky of an old screen: paper, gold mist (suyari-gasumi) between the
scenes of the same battle in sumi, shu and gold, two hanging lanterns in three stepped pools of
paler paper, gold flames, and Marishiten, eyes closed, a sealed sutra in her hands. The sutra is the
gate: it unrolls, her eyes open, the password is brushed on it mark by mark; it rolls up, sealed
(言わぬが花, better left unsaid).

Each scene is flat tones, as old pixel art is: a shape has its tone, its bevels face the nearer
torch, the light raises the tones by whole steps, nothing is smoothed.

Writes, for theme.sh to install, configs/home/.local/share/fedokawaii/MOOD/:
    lock-scene.png   the scene, indexed, its gate open (so a module that draws no frames still works)
    lock-gate.png    the gate's frames side by side, shut first (GATE_FRAMES), the scene under them
    lock-scene.txt   where the module draws on it (the gate's frames, the flames, the password's row,
                     their inks), the file kawa-lockmod and kawa-greet read
    lock-flame.png   8 frames of flame side by side, transparent around it
--preview DIR: each scene at 3 × 3, shut and open, with its flames and six marks; the gate's frames.
Needs Pillow, numpy and scipy.
"""
import argparse
import importlib.util
import math
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "configs/home/.local/share/fedokawaii"
FONT = pathlib.Path("/usr/local/share/fonts/fedokawaii/SumiUI.ttf")     # (theme.sh installs it)
_spec = importlib.util.spec_from_file_location("build_heads", ROOT / "tools/build-heads.py")
bh = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bh)
Canvas, spline, round_, dilate, erode, rgb = bh.Canvas, bh.spline, bh.round_, bh.dilate, bh.erode, bh.rgb
D, L = bh.D_, bh.L_

W, H = 640, 360
QUOTES = {"dark": "口は禍の門", "light": "言わぬが花"}       # (design-system §0: proverbs about keeping words in)
TORCH_X, FLAME_Y = (106, 534), 106                     # the fires' middles
LINTEL = (266, 373, 12, 40)                            # x0 x1 y0 y1: the plaque of the quote, between the horns
FW, FH, FRAMES = 26, 44, 8                             # a flame's frame
FLAME_TOP = 76                                         # its frame's top (the flame stands on the haft's head)
GATE_FRAMES = (0.0, 0.25, 0.5, 0.75, 1.0)              # the gate's frames, shut … open
GATE_PITCH, GATE_N = 7, 8                              # marks 7 px apart, the newest 8 in sight (the caret the 9th)
ONI_AT = (200, 36)                                     # the oni's canvas on the scene (240 × 324, f 0.8)
ANGEL_AT = (200, 22)                                   # the angel's (240 × 338, f 0.82)
RAMP = {"dark": [D["lo"], D["ground"], D["key"], D["edge"], D["edge2"], D["hi"], D["art_umber"], D["art_olive"], D["gold"], D["art_kinari"], D["strong"]]}


# ── carving: what is raised (M) and the lines cut into it (L), flat on the scene ─────────────

class Relief:
    def __init__(self):
        self.c = Canvas(W, H)
        self.M = np.zeros((H, W), bool)
        self.L = np.zeros((H, W), bool)
        self.A = np.zeros((H, W), bool)      # what the light's sky paints in shu: ribbons, fire

    def add(self, m, sep=True, accent=False):
        """a new part in front: its edge cut where it lies over what is there"""
        if sep:
            self.L |= dilate(m) & ~m & self.M
        self.L &= ~m
        self.A = self.A | m if accent else self.A & ~m
        self.M |= m

    def line(self, m):
        self.L |= m & self.M

    def stroke(self, pts, w=1.0, w1=None, prof=None):
        return self.c.stroke_mask(pts, w, w1, prof)


class Place:
    """where a figure stands: x, y (its feet), scale, rotation, flipped"""

    def __init__(self, x, y, s=1.0, rot=0.0, flip=False):
        self.x, self.y, self.s, self.c, self.sn, self.f = x, y, s, math.cos(rot), math.sin(rot), -1 if flip else 1

    def __call__(self, pts):
        return [(self.x + self.f * self.s * (px * self.c - py * self.sn), self.y + self.s * (px * self.sn + py * self.c)) for px, py in pts]


def limb(r, t, a, b, w0, w1):
    return r.stroke(t([a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), b]), w0 * t.s, w1 * t.s)


def disc(r, t, p, rad):
    (x, y), = t([p])
    return r.c.poly_mask(round_([(x + rad * t.s * math.cos(i), y + rad * t.s * math.sin(i)) for i in np.linspace(0, 2 * math.pi, 10, endpoint=False)], 4))


def blade(r, t, a, b, wid=3.0, ln=8.0):
    (x0, y0), (x1, y1) = a, b
    n = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / n, (y1 - y0) / n
    return r.c.poly_mask(t([(x1 + ux * ln, y1 + uy * ln), (x1 - uy * wid, y1 + ux * wid), (x1 - ux * 2, y1 - uy * 2), (x1 + uy * wid, y1 - ux * wid)]))


def foot(r, t, f, toe=4):
    return r.stroke(t([(f[0] - 1, f[1]), (f[0] + toe, f[1] + 0.5)]), 3.6 * t.s, 2.2 * t.s)


def oni_fig(r, t, p):
    """an oni: arms and legs thick, a wedge of a chest, the tiger skin, a big horned head, his club"""
    hip, neck, head = p["hip"], p["neck"], p["head"]
    r.add(limb(r, t, p["sa"], p["ea"], 6.5, 5) | limb(r, t, p["ea"], p["ha"], 5, 4) | disc(r, t, p["ha"], 2.8))
    r.add(limb(r, t, hip, p["ka"], 8.5, 6) | limb(r, t, p["ka"], p["fa"], 6, 4) | foot(r, t, p["fa"]))
    dx, dy = neck[0] - hip[0], neck[1] - hip[1]
    n = math.hypot(dx, dy)
    ux, uy = dx / n, dy / n
    nx, ny = -uy, ux
    r.add(r.c.poly_mask(t(round_([(hip[0] + nx * 5, hip[1] + ny * 5), (neck[0] + nx * 8.5, neck[1] + ny * 8.5), (neck[0] + ux * 2, neck[1] + uy * 2),
                                  (neck[0] - nx * 8.5, neck[1] - ny * 8.5), (hip[0] - nx * 5, hip[1] - ny * 5)], 3))))
    for k, sp in ((0.62, 5.5), (0.34, 4.0)):      # the chest's line, the belly's arc
        r.line(r.stroke(t([(hip[0] + dx * k + nx * sp, hip[1] + dy * k + ny * sp), (hip[0] + dx * (k - 0.07), hip[1] + dy * (k - 0.07)),
                           (hip[0] + dx * k - nx * sp, hip[1] + dy * k - ny * sp)])))
    r.add(limb(r, t, hip, p["kb"], 8.5, 6) | limb(r, t, p["kb"], p["fb"], 6, 4) | foot(r, t, p["fb"]))
    r.add(r.c.poly_mask(t([(hip[0] + nx * 6, hip[1] + ny * 6), (hip[0] - nx * 6, hip[1] - ny * 6), (hip[0] - nx * 7 - ux * 7, hip[1] - ny * 7 - uy * 7),
                           (hip[0] - nx * 3 - ux * 4, hip[1] - ny * 3 - uy * 4), (hip[0] - ux * 8, hip[1] - uy * 8), (hip[0] + nx * 3 - ux * 4, hip[1] + ny * 3 - uy * 4),
                           (hip[0] + nx * 7 - ux * 7, hip[1] + ny * 7 - uy * 7)])))
    hd = disc(r, t, head, 7.0)
    for a0 in (-2.5, -2.0, 2.6, 3.0, -3.0):      # the mane's spikes
        hd |= r.stroke(t([(head[0] + 4 * math.cos(a0), head[1] + 4 * math.sin(a0)), (head[0] + 12 * math.cos(a0), head[1] + 12 * math.sin(a0))]), 3.8 * t.s, 0.8)
    r.add(hd)
    horn = np.zeros_like(r.M)
    for dxh, tipx in ((-3, -6), (3, 7)):
        horn |= r.stroke(t([(head[0] + dxh, head[1] - 5), (head[0] + dxh * 1.7, head[1] - 10), (head[0] + tipx, head[1] - 15)]), 3.8 * t.s, 0.8)
    r.add(horn)
    r.line(r.stroke(t([(head[0] + 2, head[1] - 2), (head[0] + 5.5, head[1] - 1)])))
    r.line(r.stroke(t([(head[0] + 0.5, head[1] + 3), (head[0] + 5.5, head[1] + 3.5), (head[0] + 6.5, head[1] + 1)])))
    if "club" in p:
        a, b = p["club"]
        r.add(r.stroke(t([a, b]), 3.2 * t.s, 7.5 * t.s))
        for k in (0.5, 0.62, 0.74, 0.86, 0.97):      # its studs
            x, y = a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k
            for sgn in (-1, 1):
                (qx, qy), = t([(x + sgn * 1.8, y + sgn * 0.8)])
                if 0 <= int(qy) < H and 0 <= int(qx) < W:
                    r.L[int(qy), int(qx)] = True
    if "spear" in p:
        a, b = p["spear"]
        r.add(r.stroke(t([a, b]), 1.6 * t.s) | blade(r, t, a, b))
    if "rock" in p:
        r.add(disc(r, t, p["rock"], 6.5))
    r.add(limb(r, t, p["sb"], p["eb"], 7, 5.5) | limb(r, t, p["eb"], p["hb"], 5.5, 4.2) | disc(r, t, p["hb"], 3))


def angel_fig(r, t, p):
    """a tennin: her robe a long flame behind her, ribbons, a ring of light, in wide sleeves"""
    hip, neck, head = p["hip"], p["neck"], p["head"]
    for pts in p.get("ribbons", ()):
        r.add(r.stroke(t(pts), 3.0 * t.s, 1.1), sep=False, accent=True)
    fx, fy = p.get("flow", (-14, 34))
    for k, (ox, oy), wd in ((1.0, (0, 0), 14), (0.8, (10, -2), 10), (0.75, (-10, -4), 10)):
        mid = (hip[0] + fx * 0.45 + ox * 0.2 + 3, hip[1] + fy * 0.5 + oy * 0.5)
        end = (hip[0] + (fx + ox) * k, hip[1] + (fy + oy) * k)
        r.add(r.stroke(t([(hip[0], hip[1] - 2), mid, end, (end[0] + fx * 0.25, end[1] + fy * 0.12 - 4)]), wd * t.s,
                       prof=lambda u: 0.55 + 0.75 * math.sin(math.pi * min(u * 1.15, 1)) ** 0.8 - 0.42 * u ** 3))
    for k in (-3.5, 0.5, 4.5):
        r.line(r.stroke(t([(hip[0] + k * 0.5, hip[1] + 2), (hip[0] + fx * 0.3 + k, hip[1] + fy * 0.45), (hip[0] + fx * 0.75 + k, hip[1] + fy * 0.78)])))
    if "ha" in p:
        r.add(limb(r, t, p["sa"], p["ea"], 5, 7) | limb(r, t, p["ea"], p["ha"], 3.2, 2.6) | disc(r, t, p["ha"], 1.9))
    r.add(limb(r, t, hip, neck, 7.5, 8.5))
    (hx, hy), = t([head])
    yy, xx = np.mgrid[0:H, 0:W]
    rr = np.hypot(xx + 0.5 - hx, yy + 0.5 - hy)
    r.M |= (rr >= 9.0 * t.s) & (rr < 9.0 * t.s + 1.2) & ~r.M       # the ring of light behind the head
    r.add(disc(r, t, head, 5.0))
    r.add(disc(r, t, (head[0] - 0.5, head[1] - 6), 2.4))
    r.line(r.stroke(t([(head[0] + 1, head[1] - 0.5), (head[0] + 4, head[1] - 0.5)])))
    if "spear" in p:
        a, b = p["spear"]
        r.add(r.stroke(t([a, b]), 1.5 * t.s) | blade(r, t, a, b, 2.8, 9))
    if "sword" in p:
        a, b = p["sword"]
        r.add(r.stroke(t([a, b]), 3.2 * t.s, 1.0))
        cx, cy = a[0] * 0.9 + b[0] * 0.1, a[1] * 0.9 + b[1] * 0.1
        r.add(r.stroke(t([(cx - 4, cy + 1), (cx + 4, cy - 1)]), 1.6 * t.s))
    if "bow" in p:
        (bx, by), rad = p["bow"]
        arc = [(bx + rad * 0.45 * math.cos(u), by + rad * math.sin(u)) for u in np.linspace(-1.35, 1.35, 7)]
        r.add(r.stroke(t(arc), 2.0 * t.s, 1.0))
        r.add(r.stroke(t([arc[0], (bx - rad * 0.5, by), arc[-1]])), sep=False)
    r.add(limb(r, t, p["sb"], p["eb"], 6, 9) | limb(r, t, p["eb"], p["hb"], 3.4, 2.8) | disc(r, t, p["hb"], 2.1))


def cloud(r, x, y, k=1.0, flip=False):
    """a reiun, the cloud she stands on: bumps, a curling tail"""
    sgn = -1 if flip else 1
    m = np.zeros_like(r.M)
    for dx, dy, rad in ((0, 0, 7), (9, -2, 6), (17, 0, 5), (-8, 1, 5), (4, 3, 6), (13, 3, 5)):
        m |= disc(r, Place(x + sgn * dx * k, y + dy * k), (0, 0), rad * k)
    r.add(m | r.stroke([(x - sgn * 8 * k, y + 3 * k), (x - sgn * 22 * k, y + 5 * k), (x - sgn * 34 * k, y + 1 * k), (x - sgn * 38 * k, y - 3 * k)], 5 * k, 0.9))
    for dx, dy in ((0, -1), (9, -3), (-7, 1)):
        r.line(r.stroke([(x + sgn * (dx - 3) * k, y + (dy + 1) * k), (x + sgn * dx * k, y + (dy - 2) * k), (x + sgn * (dx + 3) * k, y + (dy + 1) * k)]))


def fire(r, x, y, tall=20, k=1.0, seed=0, n=5):
    rng = np.random.default_rng(seed)
    m = np.zeros_like(r.M)
    c = (n - 1) / 2
    for i in range(n):
        x0 = x + (i - c) * 7 * k
        h = tall * (1 - abs(i - c) / (c + 1) * 0.6) * rng.uniform(0.85, 1.15) * k
        b = rng.uniform(-6, 6)
        m |= r.stroke([(x0, y), (x0 + b * 0.4, y - h * 0.5), (x0 + b, y - h)], 8 * k, 0.8)
    r.add(m, accent=True)
    for i in range(n):
        x0 = x + (i - c) * 7 * k
        r.line(r.stroke([(x0, y - 1), (x0 + 1, y - tall * 0.42 * k)]))


def skull(r, x, y, k=1.0):
    r.add(disc(r, Place(x, y), (0, 0), 4.6 * k) | r.c.poly_mask([(x - 2.6 * k, y + 2), (x + 2.6 * k, y + 2), (x + 2 * k, y + 6 * k), (x - 2 * k, y + 6 * k)]))
    for dx in (-2, 2):
        r.L[int(y - 0.5), int(x + dx * k)] = r.L[int(y + 0.5), int(x + dx * k)] = True
    r.L[int(y + 4 * k), int(x)] = True


def bolt(r, a, b, seed=0):
    """lightning from a tennin's cloud: a zigzag"""
    rng = np.random.default_rng(seed)
    n = 5
    pts = [(a[0] + (b[0] - a[0]) * i / n + (rng.uniform(-5, 5) if 0 < i < n else 0), a[1] + (b[1] - a[1]) * i / n) for i in range(n + 1)]
    m = np.zeros_like(r.M)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        m |= r.stroke([(x0, y0), (x1, y1)], 2.4, 1.2)
    r.add(m, sep=False, accent=True)


# poses: x forward, y up negative, the feet at 0; about 56 tall
ONI = {
    "swing": {"hip": (0, -24), "neck": (2, -43), "head": (3, -51), "sa": (-7, -40), "ea": (-17, -48), "ha": (-9, -66), "sb": (10, -40), "eb": (21, -50), "hb": (7, -68),
              "ka": (-11, -12), "fa": (-15, 0), "kb": (13, -14), "fb": (14, 0), "club": ((-13, -62), (30, -88))},
    "lunge": {"hip": (-2, -22), "neck": (8, -40), "head": (13, -47), "sa": (3, -37), "ea": (-7, -33), "ha": (-13, -26), "sb": (13, -37), "eb": (23, -35), "hb": (33, -38),
              "ka": (-14, -11), "fa": (-27, 0), "kb": (13, -14), "fb": (15, 0), "spear": ((-16, -33), (50, -44))},
    "brace": {"hip": (-4, -14), "neck": (0, -33), "head": (3, -41), "sa": (-5, -30), "ea": (-14, -20), "ha": (-16, -7), "sb": (7, -30), "eb": (16, -38), "hb": (13, -50),
              "ka": (-14, -3), "fa": (-27, 0), "kb": (9, -11), "fb": (9, 0), "club": ((16, -42), (0, -76))},
    "fall": {"hip": (0, -22), "neck": (-2, -42), "head": (-4, -50), "sa": (-8, -40), "ea": (-19, -46), "ha": (-29, -40), "sb": (5, -40), "eb": (16, -50), "hb": (25, -56),
             "ka": (-11, -14), "fa": (-21, -6), "kb": (10, -8), "fb": (4, 4)},
    "throw": {"hip": (-3, -24), "neck": (-5, -44), "head": (-3, -52), "sa": (-11, -41), "ea": (-21, -45), "ha": (-27, -58), "sb": (1, -41), "eb": (12, -36), "hb": (22, -40),
              "ka": (-13, -12), "fa": (-13, 0), "kb": (9, -14), "fb": (21, 0), "rock": (-28, -65)},
}
ANGEL = {
    "dive": {"hip": (0, -24), "neck": (0, -44), "head": (0, -52), "sa": (-5, -42), "ea": (-9, -34), "ha": (-3, -26), "sb": (5, -42), "eb": (13, -37), "hb": (22, -32),
             "spear": ((-18, -44), (42, -22)), "flow": (-22, 32),
             "ribbons": [[(-3, -40), (-16, -48), (-30, -40), (-44, -52)], [(3, -36), (-12, -26), (-28, -30), (-46, -22)]]},
    "sword": {"hip": (0, -24), "neck": (1, -44), "head": (2, -52), "sa": (-5, -42), "ea": (-13, -38), "ha": (-20, -44), "sb": (7, -42), "eb": (15, -52), "hb": (13, -62),
              "sword": ((13, -61), (24, -94)), "flow": (-12, 34),
              "ribbons": [[(-4, -42), (-16, -56), (-30, -52), (-40, -66)], [(4, -38), (18, -28), (30, -34), (44, -26)]]},
    "bow": {"hip": (0, -24), "neck": (-1, -44), "head": (-1, -52), "sa": (-6, -42), "ea": (-15, -44), "ha": (-6, -45), "sb": (5, -42), "eb": (14, -44), "hb": (23, -45),
            "spear": ((-18, -45), (32, -45)), "bow": ((24, -45), 15), "flow": (-16, 34),
            "ribbons": [[(-4, -42), (-20, -36), (-32, -46), (-48, -40)], [(2, -30), (-10, -18), (-24, -22), (-40, -12)]]},
    "bless": {"hip": (0, -24), "neck": (0, -44), "head": (0, -52), "sa": (-5, -42), "ea": (-13, -46), "ha": (-20, -54), "sb": (5, -42), "eb": (13, -46), "hb": (20, -54),
              "flow": (6, 34), "ribbons": [[(-5, -44), (-20, -60), (-34, -52), (-46, -64)], [(5, -44), (20, -60), (34, -52), (46, -64)]]},
}


def battle_left(r, k=1.0):
    """they fall on the oni out of the sky (the left panel; KEEP the feet at y 312 and over)"""
    cloud(r, 40, 228, 0.85)
    angel_fig(r, Place(42, 226, 0.8), ANGEL["dive"])
    cloud(r, 104, 218, 0.75)
    angel_fig(r, Place(104, 216, 0.66), ANGEL["bless"])
    cloud(r, 156, 226, 0.85, flip=True)
    angel_fig(r, Place(158, 224, 0.78, flip=True), ANGEL["bow"])
    bolt(r, (104, 224), (96, 262), 3)
    oni_fig(r, Place(40, 312, 0.82), ONI["brace"])
    oni_fig(r, Place(100, 312, 0.74), ONI["throw"])
    oni_fig(r, Place(158, 312, 0.86, flip=True), ONI["swing"])
    fire(r, 72, 314, 15, 0.8, 1)
    fire(r, 128, 314, 15, 0.8, 2)
    skull(r, 20, 307)
    skull(r, 178, 307)


def battle_right(r):
    """a guardian's sword, an oni falling, one climbing (the right panel)"""
    cloud(r, 486, 222, 0.85)
    angel_fig(r, Place(486, 220, 0.76), ANGEL["sword"])
    cloud(r, 546, 216, 0.75, flip=True)
    angel_fig(r, Place(546, 214, 0.68, flip=True), ANGEL["dive"])
    cloud(r, 602, 226, 0.85, flip=True)
    angel_fig(r, Place(602, 224, 0.72, flip=True), ANGEL["bless"])
    bolt(r, (602, 232), (612, 268), 7)
    oni_fig(r, Place(492, 312, 0.84), ONI["lunge"])
    oni_fig(r, Place(548, 306, 0.72, rot=0.45, flip=True), ONI["fall"])
    oni_fig(r, Place(604, 312, 0.78, flip=True), ONI["brace"])
    fire(r, 566, 314, 15, 0.8, 5)
    skull(r, 462, 307)
    skull(r, 624, 308)


# ── the dark: the dungeon ────────────────────────────────────────────────────────────────────

def pools(xx, yy, a=64, b=114, c=172):
    """the light's three steps, by the nearer torch: 3 in the first … 0 outside the last"""
    r = np.minimum(np.hypot(xx - TORCH_X[0], (yy - FLAME_Y) * 1.12), np.hypot(xx - TORCH_X[1], (yy - FLAME_Y) * 1.12))
    return np.where(r < a, 3, np.where(r < b, 2, np.where(r < c, 1, 0)))


def toward(xx, yy):
    """each pixel's 8-way step toward its nearer torch"""
    tx = np.where(np.abs(xx - TORCH_X[0]) < np.abs(xx - TORCH_X[1]), TORCH_X[0], TORCH_X[1])
    dx, dy = tx - xx, FLAME_Y - yy
    return (np.where(np.abs(dx) > 0.42 * np.abs(dy), np.sign(dx), 0).astype(int),
            np.where(np.abs(dy) > 0.42 * np.abs(dx), np.sign(dy), 0).astype(int))


class Light:
    def __init__(self):
        self.yy, self.xx = np.mgrid[0:H, 0:W]
        self.sx, self.sy = toward(self.xx, self.yy)

    def bevel(self, m):
        """m's edge pixels facing the light, and those facing away"""
        lit = m & ~m[np.clip(self.yy + self.sy, 0, H - 1), np.clip(self.xx + self.sx, 0, W - 1)]
        dark = m & ~m[np.clip(self.yy - self.sy, 0, H - 1), np.clip(self.xx - self.sx, 0, W - 1)]
        return lit, dark & ~lit

    def behind(self, m):
        """the ground just behind m, away from the light"""
        return m[np.clip(self.yy + self.sy, 0, H - 1), np.clip(self.xx + self.sx, 0, W - 1)] & ~m


def stones(rng):
    """castle stones (ishigaki, uchikomi-hagi): rounded blocks on loose courses, the coordinates
    warped so no joint runs straight; small wedge stones where a gap has room. → labels (-1: the
    joints), how many"""
    yy, xx = np.mgrid[0:H, 0:W]
    u = xx + 0.5 + ndi.gaussian_filter(rng.normal(0, 1, (H, W)), 9) * 27
    v = yy + 0.5 + ndi.gaussian_filter(rng.normal(0, 1, (H, W)), 9) * 18
    lab = np.full((H, W), -1, int)
    n, y = 0, -14.0
    while y < H + 14:
        h = float(rng.integers(17, 31))
        x = -float(rng.integers(0, 40))
        while x < W + 40:
            w = float(rng.integers(26, 72))
            cx, cy = x + w / 2, y + h / 2 + rng.normal(0, 1.4)
            hw, hh, p = w / 2 - 0.9, h / 2 - 0.9 + rng.normal(0, 0.8), float(rng.uniform(3.2, 5.5))
            m = (np.abs((u - cx) / hw) ** p + np.abs((v - cy) / hh) ** p) <= 1
            lab[m & (lab < 0)] = n
            n += 1
            x += w
        y += h
    gap = lab < 0
    centres, k = ndi.label(ndi.distance_transform_edt(gap) >= 1.6)
    for i in range(1, k + 1):
        m = centres == i
        if m.sum() >= 2:
            lab[ndi.binary_dilation(m) & gap] = n
            n += 1
    return lab, n


def raimon(x0, x1, y0):
    """the thunder key: a square spiral repeated, its line (one row of squares, 9 px tall)"""
    m = np.zeros((H, W), bool)
    s = [(0, 0), (8, 0), (8, 8), (2, 8), (2, 3), (5, 3), (5, 5)]
    for x in range(x0, x1, 12):
        for (a, b), (c, d) in zip(s, s[1:]):
            n = max(abs(c - a), abs(d - b))
            for i in range(n + 1):
                px = x + a + (c - a) * i // n
                if 0 <= px < W:
                    m[y0 + b + (d - b) * i // n, px] = True
    return m


def seigaiha(y0, y1, r=10):
    """the sea's waves: nested arcs, each scale hiding what is behind it"""
    a = np.zeros((H, W), bool)
    yy, xx = np.mgrid[0:H, 0:W]
    for row, yc in enumerate(range(y0 - r // 2, y1 + r, r // 2)):
        for xc in range(-r * 2 + (r if row % 2 else 0), W + r * 2, r * 2):
            d = np.hypot(xx + 0.5 - xc, yy + 0.5 - yc)
            up = yy + 0.5 <= yc + 0.5
            a[(d <= r) & up] = False
            for rad in (r - 0.5, r - 3.5, r - 6.5):
                a |= (np.abs(d - rad) < 0.55) & up
    m = np.zeros((H, W), bool)
    m[y0:y1] = True
    return a & m


def mandorla(r, cx, cy, base=92, short=30, long_=56, seed=3, n=30):
    """karaen, the flames behind a guardian: a mass round a ring, only the tongues' tips apart, each
    curling the same way"""
    rng = np.random.default_rng(seed)
    r.add(r.stroke([(cx + (base + 12) * math.cos(a), cy + (base + 12) * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 40)], 30))
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.03, 0.03)
        ln = (long_ if i % 3 == 1 else short + (long_ - short) * 0.45 if i % 3 == 2 else short) + rng.uniform(-5, 5)

        def at(rad, da):
            return (cx + rad * math.cos(a + da), cy + rad * math.sin(a + da))
        tip = base + ln
        r.add(r.stroke([at(base, -0.04), at(base + ln * 0.45, 0.03), at(base + ln * 0.75, 0.13), at(tip, 0.10)], 30, prof=lambda t: (1 - t) ** 1.25 + 0.02))
        r.line(r.stroke([at(base + 14, 0.0), at(base + ln * 0.45, 0.05), at(base + ln * 0.68, 0.12)]))


def rel_line(pts):
    return Canvas(W, H).stroke_mask(pts, 1.0)


def frieze(heaven=False):
    """the beam's carving: small fighters marching on the middle, clouds and fire between them —
    the oni on the dungeon's, the tennin on the temple's"""
    fz = Relief()
    for x, sgn in ((36, False), (604, True), (166, False), (474, True)):
        cloud(fz, x, 35, 0.5, sgn)
    for x in (98, 542, 232, 408):
        fire(fz, x, 41, 13, 0.55, x)
    if heaven:
        for x, kind, flip in ((64, "dive", False), (576, "dive", True), (134, "sword", False), (506, "sword", True), (198, "bow", False), (442, "bow", True)):
            angel_fig(fz, Place(x, 35, 0.4, flip=flip), ANGEL[kind])
    else:
        for x, kind, flip in ((64, "lunge", False), (576, "lunge", True), (134, "swing", False), (506, "swing", True), (198, "brace", False), (442, "brace", True)):
            oni_fig(fz, Place(x, 41, 0.42, flip=flip), ONI[kind])
    return fz


def tomoe(r, x, y, rad=10):
    """mitsudomoe: three commas in a ring, the crest of a temple's eaves"""
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.hypot(xx + 0.5 - x, yy + 0.5 - y)
    r.add(d < rad)
    for i in range(3):
        a = 2 * math.pi * i / 3 - math.pi / 2
        hx, hy = x + rad * 0.42 * math.cos(a), y + rad * 0.42 * math.sin(a)
        r.L |= (np.hypot(xx + 0.5 - hx, yy + 0.5 - hy) < rad * 0.27) & (d < rad)
        tail = [(hx, hy), (x + rad * 0.72 * math.cos(a + 0.8), y + rad * 0.72 * math.sin(a + 0.8)), (x + rad * 0.5 * math.cos(a + 1.75), y + rad * 0.5 * math.sin(a + 1.75))]
        r.L |= r.stroke(tail, rad * 0.32, 1.0) & (d < rad)


def lettered(quote):
    """The quote in Sumi UI at its own pixels (14 px a character, 2 px apart), cropped to its ink."""
    font = ImageFont.truetype(str(FONT), 14)
    text = Image.new("1", (16 * len(quote) + 8, 20), 0)
    td = ImageDraw.Draw(text)
    td.fontmode = "1"
    for i, ch in enumerate(quote):
        td.text((16 * i, 0), ch, font=font, fill=1)
    return text.crop(text.getbbox())


def dark_ground():
    """The dungeon without its head and flames: an image of the ramp's tones."""
    rng = np.random.default_rng(11)
    li = Light()
    xx, yy = li.xx, li.yy
    t = np.zeros((H, W), int)                 # the tone before the light; 0 stays 0: the joints, what is cut deep
    # the wall: castle stones, each its own tone; the pools step stone by stone
    lab, nst = stones(rng)
    joint = lab < 0
    base = rng.integers(0, 3, nst + 1) + 1
    ids = np.arange(1, nst + 2)
    with np.errstate(invalid="ignore"):
        mx, my = ndi.mean(xx + 0.5, labels=lab + 1, index=ids), ndi.mean(yy + 0.5, labels=lab + 1, index=ids)
    kst = pools(np.nan_to_num(mx), np.nan_to_num(my))
    stone = ~joint
    t[stone] = base[lab[stone]] + kst[lab[stone]]
    lit, dark = li.bevel(stone)
    t[lit] += 2
    t[dark] -= 1
    lit2, _ = li.bevel(stone & ~lit & ~dark)
    t[lit2] += 1
    # the stone's grain: chips, not speckle
    grain = ndi.gaussian_filter(rng.normal(0, 1, (H, W)), 1.1)
    t[stone & (grain > 0.34)] -= 1
    t[joint] = 0

    # carved flames behind the head
    r = Relief()
    mandorla(r, 320, 170)
    keep = np.zeros((H, W), bool)
    keep[49:318] = True
    fl = r.M & keep
    t[li.behind(fl)] = 0
    t[fl] = 1
    # (the flames cut dark in the wall, their lines and the edge the torch takes in the old paint's red)
    paint = np.zeros((H, W), "<U1")
    lit, dark = li.bevel(fl)
    paint[(fl & r.L) | lit] = "D"
    paint[lit & (np.hypot(xx + 0.5 - 320, yy + 0.5 - 170) > 128)] = "R"
    t[dark] = 0

    # the steps at the foot, the waves on the first
    t[318:] = 2
    t[318:320] = 4
    wave = seigaiha(322, 337)
    t[320:337] = 2
    t[wave] = 4
    t[337] = 0
    t[338] = 4
    t[339] = 3
    t[340:] = 2

    # the beam over all: the thunder key along it, the cornice
    t[:46] = 2
    t[0:2] = 3
    t[raimon(0, W, 3)] = 1
    t[13] = 1
    t[14] = 4
    t[42] = 1
    t[43:45] = 4
    t[45] = 5
    t[46:49] = 0

    # the frieze in the beam: the same war marching toward the middle, small
    fz = frieze()
    band = np.zeros((H, W), bool)
    band[16:42] = True
    fm = fz.M & band
    t[li.behind(fm) & band] = 0
    t[fm] = 4
    lit, dark = li.bevel(fm)
    t[lit] = 6
    t[dark] = 2
    t[fm & fz.L] = 1

    # on the stones in the light: crests cut long ago (mitsudomoe), cracks
    crests = Relief()
    for x, y in ((40, 112), (178, 96), (462, 96), (600, 112)):
        tomoe(crests, x, y)
    cm = crests.M & stone
    t[li.behind(cm) & stone] = np.maximum(t[li.behind(cm) & stone] - 1, 0)
    t[cm] += 1
    lit, _ = li.bevel(cm)
    t[lit] += 1
    t[cm & crests.L] = 1
    for _ in range(46):            # the cracks: a line that wanders across a stone or two
        x, y = rng.uniform(0, W), rng.uniform(49, 168)
        pts = [(x, y)]
        for _ in range(int(rng.integers(2, 5))):
            pts.append((pts[-1][0] + rng.uniform(-10, 10), pts[-1][1] + rng.uniform(2, 8)))
        t[rel_line(pts) & stone] = 0

    # the panels: carved battles
    rel = Relief()
    battle_left(rel)
    battle_right(rel)
    panels = ((8, 168, 192, 316), (448, 168, 632, 316))
    for x0, y0, x1, y1 in panels:
        out = np.zeros((H, W), bool)
        out[y0:y1, x0:x1] = True
        inside = np.zeros((H, W), bool)
        inside[y0 + 4:y1 - 4, x0 + 4:x1 - 4] = True
        t[out] = 4
        lit, dark = li.bevel(out)
        t[lit] = 7
        t[dark] = 2
        t[inside] = 1
        lit, dark = li.bevel(inside)
        t[dark & inside] = 3            # the sunk ground's far edge catches the light
        t[lit & inside] = 0
        for _ in range(34):             # the wind on the ground: faint cuts
            x, y = rng.uniform(x0 + 8, x1 - 8), rng.uniform(y0 + 8, y1 - 8)
            a, ln = rng.uniform(-0.4, 0.4), rng.uniform(6, 16)
            t[rel.stroke([(x - ln * math.cos(a), y - ln * math.sin(a)), (x, y + rng.uniform(-3, 3)), (x + ln * math.cos(a), y + ln * math.sin(a))]) & inside] = 2
        mr = rel.M & inside
        t[li.behind(mr) & inside] = 0
        t[mr] = 5
        lit, dark = li.bevel(mr)
        t[lit] = 7
        t[dark] = 3
        t[mr & rel.L] = 1
    # the light on what is carved: by the pixel, a step of dither at its edges
    carved = (yy < 49) | (yy >= 318)
    for x0, y0, x1, y1 in panels:
        carved[y0:y1, x0:x1] = True
    bay = np.array([[0, 2], [3, 1]])[yy % 2, xx % 2]
    rr = np.minimum(np.hypot(xx - TORCH_X[0], (yy - FLAME_Y) * 1.12), np.hypot(xx - TORCH_X[1], (yy - FLAME_Y) * 1.12)) + bay * 2.5
    k = np.where(rr < 80, 3, np.where(rr < 130, 2, np.where(rr < 190, 1, 0)))
    for x0, y0, x1, y1 in panels:      # (the panels' figures hold their tone: the light never burns them out)
        k[y0:y1, x0:x1] = np.minimum(k[y0:y1, x0:x1], 1)
    add = carved & (t > 0)
    t[add] += k[add]
    return np.clip(t, 0, len(RAMP["dark"]) - 1), paint


def tones_image(t, ramp):
    pal = np.array([rgb(c) for c in ramp], np.uint8)
    return Image.fromarray(pal[t], "RGB")


def sconce(img, tx):
    """an iron plate on the wall, a wooden haft through an iron ring, its head wrapped and
    pitch-soaked: the flame stands on it"""
    d = ImageDraw.Draw(img)
    px = img.load()
    iron, iron_hi, wood, wood_hi = rgb(D["edge2"]), rgb(D["art_umber"]), rgb(D["art_umber"]), rgb(D["art_olive"])
    lo, edge = rgb(D["lo"]), rgb(D["edge"])
    d.rectangle([tx - 9, 132, tx + 8, 162], fill=lo)            # the plate, its rivets, curls either side
    d.rectangle([tx - 8, 133, tx + 7, 161], fill=iron)
    d.line([(tx - 8, 133), (tx + 7, 133)], fill=iron_hi)
    d.line([(tx - 8, 133), (tx - 8, 161)], fill=iron_hi)
    for y in (135, 159):
        for x in (tx - 6, tx + 5):
            px[x, y] = lo
            px[x - 1, y - 1] = iron_hi
    for sgn in (-1, 1):
        for i, (x, y) in enumerate(((10, 146), (13, 145), (14, 143), (13, 141), (11, 141), (11, 143))):
            xx_ = tx + sgn * x - (sgn < 0)
            d.rectangle([xx_, y, xx_ + 1, y + 1], fill=iron_hi if i < 4 else lo)
    d.rectangle([tx - 4, 114, tx + 3, 152], fill=lo)            # the haft
    d.rectangle([tx - 3, 114, tx + 2, 151], fill=wood)
    d.line([(tx - 3, 114), (tx - 3, 151)], fill=wood_hi)
    for yy_ in (124, 136, 146):
        d.line([(tx - 3, yy_), (tx + 2, yy_)], fill=edge)
    d.rectangle([tx - 6, 128, tx + 5, 133], fill=lo)            # the ring
    d.rectangle([tx - 5, 129, tx + 4, 132], fill=iron)
    d.line([(tx - 5, 129), (tx + 4, 129)], fill=iron_hi)
    d.rectangle([tx - 6, 110, tx + 5, 118], fill=lo)            # its wrapped head
    d.rectangle([tx - 5, 111, tx + 4, 117], fill=edge)
    d.line([(tx - 5, 111), (tx + 4, 111)], fill=rgb(D["accent_lo"]))
    for x in range(tx - 4, tx + 4, 2):
        px[x, 113] = lo
        px[x + 1, 115] = lo


def rope(img, x0, x1, y0, sag):
    """shimenawa: twisted straw sagging from the beam, the paper (shide) and the straw's tassels"""
    px = img.load()
    straw, straw_hi, straw_lo = rgb(D["art_olive"]), rgb(D["gold"]), rgb(D["art_umber"])
    lo, paper, paper_lo = rgb(D["lo"]), rgb(D["strong"]), rgb(D["art_kinari"])
    n = x1 - x0
    for i in range(n + 1):
        x = x0 + i
        c = y0 + sag * (1 - (2 * i / n - 1) ** 2)
        th = 3.2 + 1.2 * (1 - (2 * i / n - 1) ** 2)              # (thicker in its middle)
        top, bot = round(c - th), round(c + th)
        for y in range(top - 1, bot + 2):
            if 0 <= x < W and 0 <= y < H:
                if y == top - 1 or y == bot + 1:
                    px[x, y] = lo
                else:
                    twist = (x - x0 + y * 2) % 9
                    px[x, y] = lo if twist == 0 else straw_hi if (twist < 3 and y < c) else straw_lo if y > c + th * 0.4 else straw
    # the paper: a lightning of folded white, at even steps; between them a tassel of straw
    for j in range(1, 5):
        xs = x0 + n * j // 5
        cy = round(y0 + sag * (1 - (2 * j / 5 - 1) ** 2) + 4)
        for k, (dx, ln) in enumerate(((0, 6), (2, 6), (-1, 6), (1, 6))):
            for y in range(ln):
                for x in range(5):
                    xx_, yy_ = xs - 2 + dx + x, cy + k * 5 + y
                    if 0 <= xx_ < W and yy_ < H:
                        px[xx_, yy_] = paper if x < 4 else paper_lo
            for x in range(5):
                px[xs - 2 + dx + x, cy + k * 5 + ln] = lo
        if j < 5:
            xt = x0 + n * (2 * j + 1) // 10
            ct = round(y0 + sag * (1 - (2 * (2 * j + 1) / 10 - 1) ** 2) + 4)
            for x in range(xt - 2, xt + 3):
                for y in range(ct, ct + 9 - abs(x - xt)):
                    px[x, y] = straw_hi if (x + y) % 3 == 0 else straw_lo


def gilded(img, inks):
    """the plaque: one stone over the head, lit from above, the quote cut in it and gilded"""
    px = img.load()
    d = ImageDraw.Draw(img)
    x0, x1, y0, y1 = LINTEL
    hi_, edge, edge2, lo = inks
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = hi_ if y == y0 or x == x0 else edge if y == y1 or x == x1 else edge2
    d.rectangle([x0 - 1, y0 - 1, x1 + 1, y1 + 1], outline=lo)
    text = lettered(QUOTES["dark"])
    gx, gy = (x0 + x1 + 1 - text.width) // 2, (y0 + y1 + 1 - text.height) // 2
    on = [(x, y) for y in range(text.height) for x in range(text.width) if text.getpixel((x, y))]
    for x, y in on:
        px[gx + x + 1, gy + y + 1] = lo
    for x, y in on:
        px[gx + x, gy + y] = rgb(D["gold"])


def oni_frames():
    return [bh.oni(o, w=240, h=324, f=0.8, top=64, horn=0.72).image("oni") for o in GATE_FRAMES]


def dark_scene():
    t, paint = dark_ground()
    img = tones_image(t, RAMP["dark"])
    px = img.load()
    for y, x in zip(*np.nonzero(paint), strict=True):
        px[int(x), int(y)] = rgb(D["accent_lo"] if paint[y, x] == "D" else D["accent"])
    rope(img, -6, 214, 52, 16)
    rope(img, 426, 646, 52, 16)
    gilded(img, (rgb(D["hi"]), rgb(D["edge"]), rgb(D["edge2"]), rgb(D["lo"])))
    for tx in TORCH_X:
        sconce(img, tx)
    # the base scene shows the gate open; lock-gate.png holds its frames over this ground
    return img


# ── the light: the sky of an old screen ─────────────────────────────────────────────────────

LAMP_X, LAMP_FIRE = TORCH_X, 85                        # the lanterns' middles, their fire boxes' middle
LAMP_FLAME = (8, 12)                                   # a lantern's flame frame (the torch's shape, smaller)


def lantern(img, lx):
    """A hanging temple lantern (tsuri-dōrō) at x LX: its chain from the beam, the jewel, a
    six-sided bronze roof with curled tips, the fire box — a lattice lit from inside round a clear
    window, where the module's flame burns —, its foot; ochre bronze lit from the left."""
    px = img.load()
    d = ImageDraw.Draw(img)
    br, br_hi, br_lo = rgb(L["yellow"]), rgb(L["gold"]), rgb(L["lo"])
    for y in range(46, 48):
        px[lx, y] = br
    d.ellipse([lx - 3, 48, lx + 2, 53], fill=br, outline=br_lo)  # the jewel
    px[lx - 1, 49] = br_hi
    for i, y in enumerate(range(54, 68)):                        # the roof: a temple's, swept — narrow
        hw = round(3 + 19 * (i / 13) ** 1.7)                     # near the jewel, flaring to the eave
        for x in range(lx - hw, lx + hw + 1):
            px[x, y] = br
        for x in range(lx - hw, lx - hw + 2):                    # (gilt along the lit slope's edge)
            px[x, y] = br_hi
        px[lx - hw, y] = px[lx + hw, y] = br_lo
    for x in range(lx - 22, lx + 23):                            # its eave, the tips curled up
        px[x, 68] = br_lo
    for t in (-1, 1):
        px[lx + t * 23, 67] = px[lx + t * 24, 66] = br_lo
    x0, x1, y0, y1 = lx - 11, lx + 10, 69, 101                   # the fire box
    d.rectangle([x0, y0, x1, y1], fill=br)
    d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], fill=rgb(L["key"]))
    for x in range(x0 + 2, x1 - 1):                              # the lattice, the window clear
        if (x - x0) % 3 == 1 and not lx - 5 <= x <= lx + 4:
            d.line([(x, y0 + 2), (x, y1 - 2)], fill=br)
    d.rectangle([lx - 5, y0 + 6, lx + 4, y1 - 6], outline=br)
    d.line([(x0, y0), (x1, y0)], fill=br_hi)
    d.line([(x0, y0), (x0, y1)], fill=br_hi)
    d.line([(x1, y0 + 1), (x1, y1)], fill=br_lo)
    for i, y in enumerate(range(102, 108)):                      # the foot, narrowing
        hw = 10 - i * 1.2
        d.line([(int(lx - hw), y), (int(lx + hw), y)], fill=br if i < 5 else br_lo)
        px[int(lx - hw), y] = br_hi
    d.rectangle([lx - 1, 108, lx, 111], fill=br)                 # its knob
    return (lx - LAMP_FLAME[0] // 2, (y0 + y1) // 2 - LAMP_FLAME[1] // 2 + 2)


def in_bar(xx, yy, x0, x1, y0, y1):
    """a bar with fully rounded ends"""
    r, yc = (y1 - y0) / 2, (y0 + y1) / 2
    cx = np.clip(xx + 0.5, x0 + r, x1 - r)
    return (xx + 0.5 - cx) ** 2 + (yy + 0.5 - yc) ** 2 <= r * r


def suyari(xx, yy, bars):
    """suyari-gasumi, the gold mist of the old screens: long straight bars laid one on the other
    (BARS: x0 x1 y0 y1), each with its fully rounded ends: where they step, the mist's edge. → its shape"""
    m = np.zeros(xx.shape, bool)
    for x0, x1, y0, y1 in bars:
        m |= in_bar(xx, yy, x0, x1, y0, y1)
    return m


def gold_mist(mist, xx, yy):
    """→ paints: 'G' gold leaf, 'y' its line, 'g' its inner line 2 px within (the brush lifting now
    and then), and kirikane: cut gold, squares and diamonds on a slanted lattice, sparing."""
    a = np.full(mist.shape, "", dtype="<U1")
    a[mist] = "G"
    in3 = erode(erode(erode(mist)))
    a[in3 & ~erode(in3) & ~(((xx * 3 + yy * 11) % 97) < 7)] = "g"
    a[mist & ~erode(mist)] = "y"
    k = np.zeros(mist.shape, bool)
    for j, y in enumerate(range(0, H, 7)):
        for i, x in enumerate(range((j % 2) * 14, W, 28)):
            if (i * 7 + j * 5) % 3 == 0:
                k[y, x] = True
                if (i + j) % 2:
                    k[max(y - 1, 0), x] = k[min(y + 1, H - 1), x] = k[y, max(x - 1, 0)] = k[y, min(x + 1, W - 1)] = True
    a[k & erode(in3)] = "y"
    return a


def scene_figures(a, b):
    """the battle in the sky, its tiers between the mist: A the tennin, B the oni (two carvings, one ink each)."""
    # the upper sky, by the lanterns
    cloud(a, 42, 120, 0.7)
    angel_fig(a, Place(42, 118, 0.6), ANGEL["bless"])
    cloud(a, 168, 128, 0.7, flip=True)
    angel_fig(a, Place(168, 126, 0.62, flip=True), ANGEL["dive"])
    cloud(a, 474, 128, 0.7)
    angel_fig(a, Place(474, 126, 0.62), ANGEL["bow"])
    cloud(a, 598, 120, 0.7, flip=True)
    angel_fig(a, Place(598, 118, 0.6, flip=True), ANGEL["sword"])
    # the middle: they meet
    cloud(a, 54, 214, 0.75)
    angel_fig(a, Place(54, 212, 0.68), ANGEL["sword"])
    oni_fig(b, Place(136, 236, 0.66, flip=True), ONI["lunge"])
    cloud(a, 586, 214, 0.75, flip=True)
    angel_fig(a, Place(586, 212, 0.68, flip=True), ANGEL["dive"])
    oni_fig(b, Place(504, 236, 0.66), ONI["swing"])
    # below: the oni's ground, their fire
    oni_fig(b, Place(38, 328, 0.74), ONI["brace"])
    oni_fig(b, Place(104, 328, 0.7), ONI["throw"])
    oni_fig(b, Place(168, 328, 0.72, flip=True), ONI["swing"])
    fire(b, 72, 330, 15, 0.8, 1)
    fire(b, 138, 330, 15, 0.8, 2)
    oni_fig(b, Place(476, 328, 0.74), ONI["lunge"])
    oni_fig(b, Place(540, 322, 0.66, rot=0.45, flip=True), ONI["fall"])
    oni_fig(b, Place(604, 328, 0.74, flip=True), ONI["brace"])
    fire(b, 510, 330, 15, 0.8, 5)
    fire(b, 570, 330, 15, 0.8, 6)


def angel_frames():
    return [bh.angel(o, eyes=o >= 0.5, w=240, h=338, f=0.82).image("angel") for o in GATE_FRAMES]


def plaque_light(img):
    """the plaque on the beam: a gilt frame, its paper, the quote in sumi, the seal in our red"""
    d = ImageDraw.Draw(img)
    px = img.load()
    x0, x1, y0, y1 = LINTEL
    d.rectangle([x0 - 2, y0 - 2, x1 + 2, y1 + 2], fill=rgb(L["strong"]))
    d.rectangle([x0 - 1, y0 - 1, x1 + 1, y1 + 1], fill=rgb(L["gold"]))
    d.rectangle([x0, y0, x1, y1], fill=rgb(L["key"]))
    d.line([(x0, y1), (x1, y1)], fill=rgb(L["edge"]))
    text = lettered(QUOTES["light"])
    gx, gy = (x0 + x1 + 1 - (text.width + 5 + 7)) // 2, (y0 + y1 + 1 - text.height) // 2
    for y in range(text.height):
        for x in range(text.width):
            if text.getpixel((x, y)):
                px[gx + x, gy + y] = rgb(L["strong"])
    sx = gx + text.width + 5
    d.rectangle([sx, gy + text.height - 7, sx + 6, gy + text.height - 1], fill=rgb(L["accent"]))
    d.rectangle([sx + 2, gy + text.height - 5, sx + 4, gy + text.height - 3], outline=rgb(L["key"]))


def light_scene():
    """→ the ground (what is behind her), the front (what is before her: the mist, the beam, the lanterns), the fires' places"""
    yy, xx = np.mgrid[0:H, 0:W]
    # the sky: paper, three stepped pools of paler paper round the lanterns, a step of dither between
    sky = np.array([rgb(L["ground"]), rgb(L["surface"]), rgb(L["view"]), rgb(L["key"])], np.uint8)
    rr = np.minimum(np.hypot(xx - LAMP_X[0], (yy - LAMP_FIRE) * 1.1), np.hypot(xx - LAMP_X[1], (yy - LAMP_FIRE) * 1.1))
    bay = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])[yy % 4, xx % 4] * 0.7
    img = Image.fromarray(sky[np.where(rr + bay < 56, 3, np.where(rr + bay < 116, 2, np.where(rr + bay < 186, 1, 0)))], "RGB")
    px = img.load()
    inks = {k_: rgb(v) for k_, v in bh.INKS["angel"].items()}
    inks.update(y=rgb(L["yellow"]), G=rgb(L["gold"]), g=rgb(L["yellow"]))     # (gold is the world's here, not hers)

    def put(mask, ink, on=px):
        c = inks[ink] if on is px else inks[ink] + (255,)
        for y, x in zip(*np.nonzero(mask), strict=True):
            on[int(x), int(y)] = c

    # the mandorla: gold flames behind her, the mist's own leaf
    r = Relief()
    mandorla(r, 320, 176, base=104, short=26, long_=44, seed=9)
    below = yy >= 46
    m = r.M & below
    put(m, "G")
    put(dilate(m) & ~m & below, "y")
    # the battle, its tiers: the oni in shu, the tennin in gofun, sumi's line round both
    fa, fb = Relief(), Relief()
    scene_figures(fa, fb)
    for rel, fill, acc in ((fb, "R", "G"), (fa, "P", "R")):
        mm = rel.M & below
        put(dilate(mm) & ~mm & below, "K")
        put(mm, fill)
        put(mm & rel.A, acc)
        put(mm & rel.L, "K")
    # what is before her
    front = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fp = front.load()
    bands = (((-40, 176, 130, 140), (-40, 208, 138, 149), (-40, 152, 147, 156)),                  # upper left
             ((470, 680, 128, 138), (432, 680, 136, 147), (500, 680, 145, 154)),                  # upper right
             ((-40, 150, 236, 245), (-40, 196, 243, 254), (-40, 120, 252, 260)),                  # lower left
             ((492, 680, 234, 243), (444, 680, 241, 252), (520, 680, 250, 258)),                  # lower right
             ((-60, 214, 330, 340), (426, 700, 330, 340), (-60, 700, 338, 360)))                  # the last, before her, where the words go
    for i, bars in enumerate(bands):
        paint = gold_mist(suyari(xx, yy, bars), xx, yy)
        if i == len(bands) - 1:                 # (the words' field stays plain gold)
            paint[(yy >= 342) & (yy < 356) & (xx >= 230) & (xx < 410)] = "G"
        for ink in ("G", "g", "y"):
            put(paint == ink, ink, fp)
    # the beam: vermilion lacquer, the thunder key in gold, clouds and fire along it, its cornice
    beam = yy < 46
    put(beam, "R", fp)
    put(yy < 2, "r", fp)
    put(raimon(0, W, 3), "G", fp)
    put((yy == 13) | (yy == 42), "r", fp)
    put(yy == 14, "G", fp)
    put((yy >= 43) & (yy < 45), "G", fp)
    put(yy == 45, "K", fp)
    fz = frieze(heaven=True)
    band = (yy >= 16) & (yy < 42)
    put(fz.M & band, "G", fp)
    put(fz.M & fz.L & band, "r", fp)
    plaque_light(front)
    fires = [lantern(front, lx) for lx in LAMP_X]
    return img, front, fires


def gate_strip(ground, frames, at, front=None):
    """the frames of the gate, cut to what differs among them: (x, y, w, h), the strip side by side;
    each frame's whole scene. FRONT lies before the frames."""
    full = []
    for f in frames:
        im = ground.convert("RGBA")
        im.paste(f, at, f)
        if front is not None:
            im.paste(front, (0, 0), front)
        full.append(np.asarray(im.convert("RGB")))
    diff = np.zeros((H, W), bool)
    for a in full[1:]:
        diff |= (a != full[0]).any(-1)
    ys, xs = np.nonzero(diff)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
    w, h = x1 - x0, y1 - y0
    strip = Image.new("RGB", (w * len(full), h))
    for i, a in enumerate(full):
        strip.paste(Image.fromarray(a[y0:y1, x0:x1]), (i * w, 0))
    return (x0, y0, w, h), strip, [Image.fromarray(a) for a in full]


# ── the torches' fire ────────────────────────────────────────────────────────────────────────

def flames(layers, ember, fw=FW, fh=FH, lick=0.0):
    """8 frames of a flame fw × fh: nested teardrops (LAYERS: ink, width and where it starts, the
    outer first), the tip swaying more than the foot, the body breathing, its edge licking by LICK;
    EMBER off the tip twice. The dark's torch: deep red, vermilion, orange, the cream core; the
    light's lantern: a small candle of the same shape."""
    strip = Image.new("RGBA", (fw * FRAMES, fh), (0, 0, 0, 0))
    sp = strip.load()
    base = fh - 2
    for f in range(FRAMES):
        ph = 2 * math.pi * f / FRAMES
        h = round((0.83 + 0.053 * math.sin(ph + 1.1)) * fh)
        hw = (0.355 + 0.033 * math.sin(2 * ph)) * fw
        sway = 0.063 * fh * math.sin(ph)
        for col, lw, kh in layers:
            top = base - h + kh * h
            for y in range(fh):
                if not top <= y <= base:
                    continue
                t = (y - top) / max(base - top, 1)              # 0 at the tip, 1 at the foot
                half = lw * hw * math.sqrt(t) * (1 - 0.55 * t ** 4) + lick * lw * math.sin(5 * t + 2 * ph) * t * (1 - t)
                mid = fw / 2 + sway * (1 - t) ** 2 + lick * 0.5 * math.sin(4 * t - ph) * (1 - t)
                for x in range(fw):
                    if abs(x + 0.5 - mid) < half:
                        sp[f * fw + x, y] = col + (255,)
        if f in (2, 5):
            sp[f * fw + int(fw / 2 + 1.5 * sway), max(base - h - 2 - (f == 5), 0)] = ember + (255,)
    return strip


def hexof(c):
    return "%02x%02x%02x" % c


def rim_ink(img):
    """The scene's commonest colour along its four edges: the ground drawn round it where the
    screen is not a whole multiple of it, so the scene seems to go on."""
    px = img.load()
    edge = [px[x, y] for x in range(W) for y in (0, H - 1)] + [px[x, y] for y in range(H) for x in (0, W - 1)]
    return max(set(edge), key=edge.count)


def placed(row, marks, plate, rim, words, gate, fires, frame):
    """lock-scene.txt: where the module draws on the scene, in the scene's own pixels."""
    lines = ["# lock-scene.txt — where kawa-lockmod draws on lock-scene.png, in its pixels (each shown",
             "# N × N on the screen, N whole: the most the screen holds). tools/build-lock.py writes it.",
             f"size {W} {H}",
             f"ground {hexof(rim)}   # round the scene: its edges' commonest colour",
             "gate {} {} {} {} {}   # lock-gate.png: its frames side by side, shut first: where they lie, each's size, how many".format(*gate, len(GATE_FRAMES)),
             f"frames {frame[0]} {frame[1]} {FRAMES}   # lock-flame.png: the frames side by side, 8 a second"]
    lines += [f"flame {x} {y}   # a flame's frame, its top-left" for x, y in fires]
    lines += [f"row {row[0]} {row[1]} {GATE_PITCH} {GATE_N}   # the password: the first mark's middle, the pitch, how many in sight",
              "mark {} {} {}   # a mark: its arms, its middle, its corners".format(*map(hexof, marks[:3])),
              f"caps {hexof(marks[3])}   # the arms while Caps Lock is on",
              f"caret {hexof(marks[4])}   # a bar as tall as a mark at the next place, once a second",
              "plate {} {} {}   # what shakes at a wrong password: its middle, its radius".format(*plate),
              "words {} {}   # the line of words (what PAM says): the rows it is centred in".format(*words)]
    return "\n".join(lines) + "\n"


def marks_on(img, row, marks, n=6):
    pp = img.load()
    arms, core, corner = marks[:3]
    for i in range(n):
        x, y = row[0] + GATE_PITCH * i, row[1]
        for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            pp[x + dx, y + dy] = corner
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            pp[x + dx, y + dy] = arms
        pp[x, y] = core


def write(mood, scene, strip, fire_, words):
    scene.convert("P", palette=Image.ADAPTIVE, colors=64).save(OUT / mood / "lock-scene.png", optimize=True)
    strip.convert("P", palette=Image.ADAPTIVE, colors=64).save(OUT / mood / "lock-gate.png", optimize=True)
    fire_.save(OUT / mood / "lock-flame.png", optimize=True)
    (OUT / mood / "lock-scene.txt").write_text(words)


def main():
    ap = argparse.ArgumentParser(description="the lock screen's scenes (T19q 8)")
    ap.add_argument("--preview", type=pathlib.Path, help="also write the 3 × 3 previews here")
    a = ap.parse_args()
    for mood in ("dark", "light"):
        (OUT / mood).mkdir(parents=True, exist_ok=True)
    first = 320 - (GATE_PITCH * (GATE_N - 1) + 1) // 2         # (the row's middle on the screen's)
    # dark
    gate, strip, full = gate_strip(dark_scene(), oni_frames(), ONI_AT)
    dstrip = flames([(rgb(D["accent_lo"]), 1.00, 0.00), (rgb(D["accent"]), 0.80, 0.08), (rgb(D["flame"]), 0.60, 0.30), (rgb(D["strong"]), 0.36, 0.55)], rgb(D["flame"]), lick=1.1)
    row = (first, round((220 + 64) * 0.8) + ONI_AT[1])
    marks = (rgb(D["flame"]), rgb(D["strong"]), rgb(D["accent_lo"]), rgb(D["asagi"]), rgb(D["flame"]))
    write("dark", full[-1], strip, dstrip, placed(row, marks, (320, 180, 120), rim_ink(full[-1]), (344, 354), gate, [(x - FW // 2, FLAME_TOP) for x in TORCH_X], (FW, FH)))
    # light
    ground, front, fires = light_scene()
    lgate, lstrip, lfull = gate_strip(ground, angel_frames(), ANGEL_AT, front)
    fstrip = flames([(rgb(L["accent"]), 1.00, 0.00), (rgb(L["gold"]), 0.70, 0.30), (rgb(L["hi"]), 0.35, 0.60)], rgb(L["gold"]), *LAMP_FLAME)
    lrow = (first, round((288 + bh.TOP_ANGEL) * 0.82) + ANGEL_AT[1])
    lmarks = (rgb(L["strong"]), rgb(L["strong"]), rgb(L["lo"]), rgb(L["asagi"]), rgb(L["accent"]))
    write("light", lfull[-1], lstrip, fstrip, placed(lrow, lmarks, (320, 176, 104), rim_ink(lfull[-1]), (344, 354), lgate, fires, LAMP_FLAME))
    if a.preview:
        a.preview.mkdir(parents=True, exist_ok=True)
        for mood, frames, st, r_, m_, spots, size in (("dark", full, dstrip, row, marks, [(x - FW // 2, FLAME_TOP) for x in TORCH_X], (FW, FH)),
                                                      ("light", lfull, fstrip, lrow, lmarks, fires, LAMP_FLAME)):
            one = st.crop((0, 0, *size))
            shut, opened = frames[0].convert("RGBA"), frames[-1].convert("RGBA")
            for im in (shut, opened):
                for fx, fy in spots:
                    im.paste(one, (fx, fy), one)
            o2 = opened.convert("RGB")
            marks_on(o2, r_, m_)
            shut.convert("RGB").resize((3 * W, 3 * H), Image.NEAREST).save(a.preview / f"lock-{mood}-shut-3x.png")
            o2.resize((3 * W, 3 * H), Image.NEAREST).save(a.preview / f"lock-{mood}-open-3x.png")


if __name__ == "__main__":
    main()
