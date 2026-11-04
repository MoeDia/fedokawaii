#!/usr/bin/env python3
"""tools/build-ink.py — the demon and the angel, one painting each (the owner, 4 Nov 18:32, 19:11, 19:12:
"a Renaissance Japanese style painting, as detailed as possible"; no pixel art for the lock or the heads).

    python3 tools/build-ink.py [--preview DIR] [lock|heads|all]

Made from art/ink/SOURCES.md's plates and sources, cut in tools/ink_engrave.py's one hand. Writes the
lock's painting and its layers (configs/home/.local/share/fedokawaii/MOOD/lock-*), fetch's portrait
(head.six), the heads for menus and the bar (themes/MOOD/face*.png) and the prompt's glyphs.
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


def _load(name):
    sp = importlib.util.spec_from_file_location(name, ROOT / f"tools/{name}.py")
    m = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(m)
    return m


ie = _load("ink_engrave")
dr = _load("ink_draw")

CACHE = pathlib.Path.home() / ".cache/r27-ink"
SRC = CACHE / "src"
CAND = CACHE / "cand"
SW, SH = 1920, 1080


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255


# ── the Noh mask, its jaw at any opening ─────────────────────────────────────────────────

MASK_SRC = SRC / "hannya-noh.jpg"
AXIS = 1272                                 # the mask's middle, in the source's pixels
# the lower jaw: its inner edge from corner to corner round the lower teeth, closed under the chin
JAW = [(800, 1960), (845, 2130), (940, 2270), (1000, 2340), (1035, 2345), (1060, 2322), (1085, 2345), (1110, 2385),
       (1270, 2392), (1434, 2385), (1459, 2345), (1484, 2322), (1509, 2345), (1544, 2340), (1604, 2270), (1699, 2130),
       (1744, 1960), (1900, 2100), (1900, 2900), (640, 2900), (640, 2100)]
UPPER_FANGS = [[(998, 2160), (1062, 2160), (1058, 2250), (1030, 2290), (1004, 2250)],
               [(1482, 2160), (1546, 2160), (1540, 2250), (1514, 2290), (1486, 2250)]]
LIFT = 145                                  # what shuts it: the lower teeth meet the upper


def mask_source():
    """the mask's picture as a float array and its silhouette, the horns off (a painting's horns
    take over), the missing lower fang mirrored from the other"""
    a = np.asarray(Image.open(MASK_SRC).convert("RGB"), dtype=np.float32) / 255
    lum = a @ np.array([.3, .59, .11], dtype=np.float32)
    warm = a[..., 0] - a[..., 2]
    m = (warm > .035) | (lum < .30)
    m = ndi.binary_opening(m, iterations=5)
    lab, n = ndi.label(m)
    m = lab == (1 + int(np.argmax(ndi.sum(m, lab, range(1, n + 1)))))
    m = ndi.binary_fill_holes(ndi.binary_closing(m, iterations=14))
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]].astype(np.float32)
    head = ((xx - AXIS) / 800) ** 2 + ((yy - 1320) / 800) ** 2 < 1
    m &= head | (yy > 1100)
    # the fang the years took: the other's, mirrored
    y0, y1, x0, x1 = 2300, 2490, 1000, 1115
    fang = a[y0:y1, x0:x1][:, ::-1]
    fm = np.zeros((y1 - y0, x1 - x0), np.float32)
    im = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(im).polygon([(25, 190), (20, 100), (55, 22), (88, 100), (88, 190)], fill=255)
    fm = ndi.gaussian_filter(np.asarray(im, dtype=np.float32) / 255, 4)[:, ::-1]
    mx0 = 2 * AXIS - x1
    a[y0:y1, mx0:mx0 + (x1 - x0)] = a[y0:y1, mx0:mx0 + (x1 - x0)] * (1 - fm[..., None]) + fang * fm[..., None]
    return a, m


def jaw_at(a, m, o):
    """the mask with its jaw at opening o (0 shut, 1 as carved, more: wider): the part below the jaw's
    edge moves, the throat black between, the upper fangs in front of what rises"""
    H, W = a.shape[:2]
    lift = LIFT * (1 - o)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    jawm = Image.new("1", (W, H), 0)
    ImageDraw.Draw(jawm).polygon(JAW, fill=1)
    jawm = np.asarray(jawm, dtype=bool)
    # across: all of it under the teeth, nothing past the mouth's corners
    w = np.clip((560 - np.abs(xx - AXIS)) / 260, 0, 1)
    w = w * w * (3 - 2 * w)
    sy = yy + lift * w
    src = np.stack([ndi.map_coordinates(a[..., i], [sy, xx], order=1, mode="nearest") for i in range(3)], 2)
    srcm = ndi.map_coordinates(m.astype(np.float32), [sy, xx], order=1, mode="nearest") > .5
    here = ndi.map_coordinates(jawm.astype(np.float32), [sy, xx], order=0, mode="nearest") > .5
    out = np.where(here[..., None], src, a)
    throat = np.array([.02, .018, .016], np.float32)
    gone = jawm & ~here                     # the jaw has left: the throat shows (or nothing, past the chin)
    out[gone] = throat
    mm = np.where(here, srcm, m & ~gone | (gone & (yy < 2500)))
    if lift > 0:
        im = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(im)
        for f in UPPER_FANGS:
            d.polygon(f, fill=255)
        fm = np.asarray(im, dtype=np.float32) / 255
        fm = ndi.gaussian_filter(fm, 2)[..., None]
        out = out * (1 - fm) + a * fm
    return out, mm


# ── the demon's face in the engraver's hand ──────────────────────────────────────────────

def face_ink(a, m, scale=1.0):
    """the mask (float RGB, silhouette) cut in lines at 3 × its final size: (ink 0…1, alpha 0…1) at
    final size. scale: final pixels per source pixel × 3"""
    H, W = a.shape[:2]
    nw, nh = int(W * scale), int(H * scale)
    lum = a @ np.array([.3, .59, .11], dtype=np.float32)
    grey = a[..., 0] * .75 + lum * .25      # the red paint reads as form, not as darkness
    g = np.asarray(Image.fromarray((np.clip(grey, 0, 1) * 255).astype(np.uint8)).resize((nw, nh), Image.LANCZOS), dtype=np.float32) / 255
    mm = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((nw, nh), Image.BILINEAR), dtype=np.float32) / 255 > .5
    t = ie.blur(ndi.median_filter(g, size=5), 1.2)   # (the lacquer's craze stays, the photograph's grain goes)
    wide = ie.blur(t, 110 * scale / .9)
    t2 = np.clip(.72 + (t - wide) * 1.85 + (wide - .62) * .42, 0, 1)
    # the torches stand either side and above: temples and cheeks catch them, the middle falls away
    yy, xx = np.mgrid[0:nh, 0:nw].astype(np.float32)
    side = np.abs(xx - AXIS * scale) / (640 * scale)
    t2 = np.clip(t2 * (.86 + .30 * np.clip(side, 0, 1) ** 1.2), 0, 1)
    # the eyes: their gold plates stay bright, their holes black
    for ex in (AXIS - 318, AXIS + 318):
        d = ((xx / scale - ex) / 222) ** 2 + ((yy / scale - 1540) / 122) ** 2
        e = np.clip((1.05 - d) / .25, 0, 1)
        t2 = t2 * (1 - e) + np.clip(t * 1.25 - .05, 0, 1) * e
    t2 = np.where(mm, t2, 1.0)
    ink = ie.engrave(t2, pitch=14, ride=30, mirror_x=int(AXIS * scale), key_s=2.0)
    ink = np.where(mm, ink, 0)
    return ie.reduce3(ink), ie.reduce3(mm.astype(np.float32))


# ── the demon: M1, the engraver's Hannya, set in its hall ───────────────────────────────

K = 1.12                                    # final pixels per pixel of the figure's first drawing (1024 wide)
DX, DY = 2880, -180                         # where its middle and its top lie on the working plate


def U(x, y):
    """the first drawing's working units (3072 wide) on this plate"""
    return (DX + (x - 1536) * K, DY + y * K)


def UP(points):
    return np.array([U(x, y) for x, y in points])


TORCHES = ((114, 205), (1789, 205))         # the fires' middles on the screen, from the hall's plate
TORCH_RANGE = 640


def torch_light(H=SH, W=SW, scale=1):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    light = np.zeros((H, W), np.float32)
    for tx, ty in TORCHES:
        d = np.hypot(xx - tx * scale, (yy - ty * scale) * .85)
        light = np.maximum(light, np.exp(-(d / (TORCH_RANGE * scale)) ** 1.5))
    return light


def demon_back():
    """hair behind, horns, collar: (ink coverage, figure alpha) at final size, cut on the working plate"""
    W, H = SW * 3, SH * 3
    P = dr.Plate(W, H)
    rng = np.random.default_rng(7)
    CX, CY = U(1536, 0)[0], U(0, 1480)[1]
    for side in (-1, 1):
        for j in range(52):
            q = j / 51
            th = -math.pi / 2 + side * (.25 + q * 2.3)      # from the crown round to the shoulder
            x = CX + 640 * K * math.cos(th)
            y = CY + 700 * K * math.sin(th)
            out = th + side * rng.uniform(.05, .55)
            length = rng.uniform(620, 1300) * (.85 + .4 * q) * K
            dr.lock(P, rng, x, y, out, length, rng.integers(4, 8), rng.uniform(40, 110) * K, rng.uniform(14, 30) * K,
                    side * rng.uniform(.6, 1.6), side * rng.uniform(.3, 1.1) * rng.choice((-1, 1)))
    # the crown: locks rising between the horns, all the way up
    for j in range(26):
        q = j / 25
        th = -math.pi / 2 + (q - .5) * .9
        x, y = CX + 520 * K * math.cos(th), CY + 700 * K * math.sin(th)
        dr.lock(P, rng, x, y, th + rng.uniform(-.25, .25), rng.uniform(420, 1000) * K, rng.integers(4, 7), rng.uniform(40, 90) * K,
                rng.uniform(12, 26) * K, rng.choice((-1, 1)) * rng.uniform(.5, 1.2), rng.choice((-1, 1)) * rng.uniform(.3, 1.2))
    # the torches catch single strands: fine lines of light through the black, the mane's life on a dark wall
    lit = np.random.default_rng(41)
    for side in (-1, 1):
        for j in range(120):
            th = -math.pi / 2 + side * (.15 + j / 119 * 2.25)
            x = CX + 660 * K * math.cos(th)
            y = CY + 720 * K * math.sin(th)
            n, a, p_ = 22, th + side * lit.uniform(.0, .6), np.array([x, y], float)
            L, turn, pts = lit.uniform(480, 1250) * K, side * lit.uniform(.3, 1.4), []
            for i in range(n):
                a += turn * math.sin(i / n * math.pi * 1.6) * .08
                p_ = p_ + (L / n) * np.array([math.cos(a), math.sin(a)])
                pts.append(p_.copy())
            P.clear(dr.stroke_poly(dr.spline(pts[::2], 5), lit.uniform(3.4, 6.4), .8, ease=.8))
    # the robe: shoulders falling from the neck, folds in them
    robe = dr.spline([U(*q) for q in ((-500, 3500), (-120, 3060), (480, 2790), (980, 2640), (1536, 2600), (2092, 2640),
                                      (2592, 2790), (3192, 3060), (3572, 3500))], 16)
    P.fill(robe, .66)
    dr.seigaiha(P, robe, cell=int(66 * K), w=6)
    for x0, x1, bow in ((180, 620, 90), (420, 860, 60), (2892, 2452, -90), (2652, 2212, -60)):
        c = [U(x0, 2800 + abs(x0 - 1536) * .22), U((x0 + x1) / 2 + bow, 3000), U(x1, 3320)]
        P.stroke(c, 16 * K, 2, ease=.9)
    # the collar: a V under the chin, closing at the frame's foot: the throat black, a white band along each lapel's
    # inner edge, a black one outside it, a line of light down each
    def at(y, sgn):
        return 1536 + sgn * 300 * (3220 - y) / 500
    P.fill(UP([(at(2420, -1), 2420), (at(2420, 1), 2420), (at(3220, 1), 3220), (at(3220, -1), 3220)]), .10)
    for sgn in (1, -1):
        y0, y1 = 2420, 3220
        band = UP([(at(y0, sgn), y0), (at(y0, sgn) + sgn * 82, y0), (at(y1, sgn) + sgn * 82, y1), (at(y1, sgn), y1)])
        # (the black's top falls away from the jaw along the neck: no flat cut across the mane)
        black = UP([(at(y0, sgn) + sgn * 82, y0), (at(y0 + 260, sgn) + sgn * 300, y0 + 260), (at(y1, sgn) + sgn * 300, y1), (at(y1, sgn) + sgn * 82, y1)])
        P.fill(black, .14)
        P.fill(band, .96)
        for q, w in ((.12, 5), (.9, 5)):
            c = [U(at(y0, sgn) + sgn * 82 * q, y0), U(at(y1, sgn) + sgn * 82 * q, y1)]
            P.cut(dr.stroke_poly(np.array(c), w * K, w * K))
        c = [U(at(y0, sgn) + sgn * 210, y0), U(at(y1, sgn) + sgn * 210, y1)]
        P.clear(dr.stroke_poly(np.array(c), 5 * K, 5 * K))
        P.cut(dr.outline(black, 8))
    # hair falling in front of the shoulders, from behind the jaw, the join hidden
    for sgn in (-1, 1):
        for j in range(26):
            x, y = U(1536 + sgn * rng.uniform(430, 760), rng.uniform(1900, 2500))
            dr.lock(P, rng, x, y, math.pi / 2 - sgn * rng.uniform(.0, .55), rng.uniform(520, 1080) * K, rng.integers(3, 7), rng.uniform(30, 80) * K,
                    rng.uniform(12, 26) * K, sgn * rng.uniform(.4, 1.1), sgn * rng.uniform(.2, .9) * rng.choice((-1, 1)))
    # lit strands over the lapels' tops: the mane falls in front of the robe
    for sgn in (-1, 1):
        for j in range(46):
            x, y = U(1536 + sgn * lit.uniform(420, 860), lit.uniform(2050, 2480))
            n, a, p_ = 18, math.pi / 2 - sgn * lit.uniform(-.1, .5), np.array([x, y], float)
            L, turn, pts = lit.uniform(420, 1000) * K, sgn * lit.uniform(.2, 1.0), []
            for i in range(n):
                a += turn * math.sin(i / n * math.pi * 1.6) * .08
                p_ = p_ + (L / n) * np.array([math.cos(a), math.sin(a)])
                pts.append(p_.copy())
            P.clear(dr.stroke_poly(dr.spline(pts[::2], 5), lit.uniform(3.0, 5.6), .7, ease=.8))
    # the horns: long, thick, ringed, over the mane, their tips inside the frame
    for sgn in (-1, 1):
        c = [U(1536 + sgn * x, y) for x, y in ((430, 1010), (700, 800), (960, 620), (1200, 420), (1393, 209))]
        dr.tube(P, c, 262 * K, 14 * K, light=-.36 * sgn, base=.78, ring_every=.036, ring_depth=.54)
    tone = np.where(P.mask, P.tone, 1.0)
    ink = ie.engrave(tone, pitch=14, ride=30, mirror_x=DX, key_s=2.0)
    ink = np.where(P.mask, ink, 0)
    ink = np.maximum(ink, P.ink) * (1 - P.lit)
    alpha = np.maximum(np.maximum(P.mask.astype(np.float32), P.ink), P.lit)
    return ie.reduce3(ink), ie.reduce3(alpha)


def demon_front(fbox):
    """what lies on the mask, M1's own: scrolls and flames cut into brow and cheeks, strands over the temples:
    (ink, cleared) at final size"""
    W, H = SW * 3, SH * 3
    P = dr.Plate(W, H)
    rng = np.random.default_rng(23)
    fx0, fx1, fy0, fy1 = fbox
    fw, fh = fx1 - fx0, fy1 - fy0
    CX = DX
    for sgn in (-1, 1):
        st = lambda a: a if sgn > 0 else math.pi - a
        # the brow: cloud scrolls climbing from the knot between the eyes to the hairline
        dr.flame(P, (CX + sgn * .02 * fw, fy0 + .44 * fh), (CX + sgn * .23 * fw, fy0 + .10 * fh), bow=.20 * sgn, width=130 * K, lines=3, w=9 * K)
        dr.flame(P, (CX + sgn * .09 * fw, fy0 + .40 * fh), (CX + sgn * .38 * fw, fy0 + .25 * fh), bow=-.12 * sgn, width=70 * K, lines=2, w=8 * K)
        dr.scroll(P, CX + sgn * .30 * fw, fy0 + .255 * fh, 118 * K, sign=sgn, w=20 * K, start=st(1.0),
                  tail=[(CX + sgn * .20 * fw, fy0 + .325 * fh), (CX + sgn * .07 * fw, fy0 + .36 * fh)], squash=.8, tilt=sgn * .3)
        dr.scroll(P, CX + sgn * .385 * fw, fy0 + .13 * fh, 62 * K, sign=-sgn, w=14 * K, start=st(.4), tail=[(CX + sgn * .36 * fw, fy0 + .20 * fh)], squash=.85)
        # the cheeks: a large scroll under each eye, its tail along the fold, a flame licking up to the temple
        dr.scroll(P, CX + sgn * .345 * fw, fy0 + .625 * fh, 92 * K, sign=-sgn, w=16 * K, start=st(.1),
                  tail=[(CX + sgn * .42 * fw, fy0 + .72 * fh), (CX + sgn * .375 * fw, fy0 + .83 * fh)], squash=.9)
        dr.flame(P, (CX + sgn * .215 * fw, fy0 + .60 * fh), (CX + sgn * .47 * fw, fy0 + .44 * fh), bow=-.16 * sgn, width=64 * K, lines=2, w=8 * K)
    for sgn in (-1, 1):
        for j in range(12):
            x, y = CX + sgn * (.40 + .06 * j / 11) * fw, fy0 + (.06 + .19 * j / 11) * fh
            dr.lock(P, rng, x, y, math.pi / 2 - sgn * rng.uniform(.5, 1.25), rng.uniform(520, 1000) * K, rng.integers(3, 6), rng.uniform(30, 70) * K,
                    rng.uniform(12, 24) * K, sgn * rng.uniform(.5, 1.2), sgn * rng.uniform(.2, .9))
    for _ in range(70):
        sgn = rng.choice((-1, 1))
        x, y = CX + sgn * rng.uniform(.18, .46) * fw, fy0 + rng.uniform(0, .10) * fh
        a = math.pi / 2 - sgn * rng.uniform(.9, 1.5)
        L, n = rng.uniform(420, 900) * K, 22
        p, pts, k = np.array([x, y], float), [], rng.uniform(-1, 1)
        for i in range(n):
            q = i / n
            a += .5 * (k * .12 + .22 * math.sin(p[0] / 410 + p[1] / 330 + k * 3)) * (.25 + 1.4 * q * q)
            p = p + (L / n) * np.array([math.cos(a), math.sin(a)])
            pts.append(p.copy())
        P.stroke(pts, rng.uniform(6, 14), .5, ease=.8, n=6)
    return ie.reduce3(P.ink), ie.reduce3(P.lit)


def ornament(plate):
    """a scrollwork plate, drawn alone on white: (its coverage 0…1, its silhouette, soft)"""
    g = np.asarray(Image.open(plate).convert("L"), dtype=np.float32) / 255
    cov = np.clip((.66 - g) / .30, 0, 1)
    st = ndi.generate_binary_structure(2, 1)
    solid = ndi.binary_fill_holes(ndi.binary_closing(cov > .5, st, iterations=3))
    lab, n = ndi.label(solid)
    solid = np.isin(lab, 1 + np.nonzero(ndi.sum(solid, lab, range(1, n + 1)) > 60)[0])
    sil = ndi.gaussian_filter(ndi.binary_dilation(solid, st, iterations=3).astype(np.float32), 1.2)
    return cov, sil


def inlay(ink, orn, cx, cy, width, flip=False, clip=None, tilt=0.0):
    """the ornament cut into a coverage array, its middle at (cx, cy), `width` final pixels wide: where it lies,
    its own lines and paper replace the hatching"""
    cov, sil = orn
    w = int(width)
    h = int(cov.shape[0] * width / cov.shape[1])
    ci = Image.fromarray((cov * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)
    si = Image.fromarray((sil * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)
    if tilt:
        ci, si = ci.rotate(tilt, Image.BICUBIC, expand=False), si.rotate(tilt, Image.BICUBIC, expand=False)
    ci, si = np.asarray(ci, dtype=np.float32) / 255, np.asarray(si, dtype=np.float32) / 255
    if flip:
        ci, si = ci[:, ::-1], si[:, ::-1]
    y0, x0 = int(cy - h / 2), int(cx - w / 2)
    r = (slice(y0, y0 + h), slice(x0, x0 + w))
    if clip is not None:
        si = si * clip[r]
    ink[r] = ink[r] * (1 - si) + ci * si


def demon_mask(a, m, o):
    """the mask at jaw opening o on the screen: (ink, alpha, face box in working pixels)"""
    aa, mm = jaw_at(a, m, o)
    scale = .90 * K
    ink, alpha = face_ink(aa, mm, scale)
    ys, xs = np.nonzero(m)
    # placed as in the first drawing: its box's middle on the plate's, its chin at 2720 units
    ox = DX - int(AXIS * scale)
    oy = int(DY + 2720 * K - ys.max() * scale)
    full_i, full_a = np.zeros((SH, SW), np.float32), np.zeros((SH, SW), np.float32)
    fx, fy = ox // 3, oy // 3
    h, w = ink.shape
    y0, y1, x0, x1 = max(fy, 0), min(fy + h, SH), max(fx, 0), min(fx + w, SW)
    full_i[y0:y1, x0:x1] = ink[y0 - fy:y1 - fy, x0 - fx:x1 - fx]
    full_a[y0:y1, x0:x1] = alpha[y0 - fy:y1 - fy, x0 - fx:x1 - fx]
    box = (ox + xs.min() * scale, ox + xs.max() * scale, oy + ys.min() * scale, oy + ys.max() * scale)
    return full_i, full_a, box


def wall_dark(name="wd-1003"):
    """the hall in the engraver's hand: (ink coverage, the plate's tone 0…1, the fires' mask, the plate's own
    values) at final size"""
    im = Image.open(CAND / f"{name}.png").convert("L")
    w, h = im.size
    plate = np.asarray(im.crop((0, 4, w, h - 4)), dtype=np.float32) / 255
    g = np.asarray(Image.fromarray((plate * 255).astype(np.uint8)).resize((SW * 3, SH * 3), Image.LANCZOS), dtype=np.float32) / 255
    t = ie.blur(ndi.median_filter(g, size=3), 1.6)
    t = np.clip((t - .03) / .72, 0, 1) ** .82            # the relief first: deep black in its cuts, open where lit
    ink = ie.engrave(t, pitch=11, ride=26, angle=38, key_s=2.8, t2=.42, t3=.18)
    fire = np.zeros((SH, SW), bool)
    for x0, x1 in ((78, 150), (1752, 1826)):
        part = plate[108:272, x0:x1] > .80
        lab, n = ndi.label(part)
        part = lab == (1 + int(np.argmax(ndi.sum(part, lab, range(1, n + 1))))) if n else part
        fire[108:272, x0:x1] = part
    fire = ndi.binary_fill_holes(ndi.binary_closing(fire, iterations=3))
    return ie.reduce3(ink), ie.reduce3(t), fire, plate


def ramp(t, stops):
    xs = [s[0] for s in stops]
    cs = np.array([hexc(s[1]) for s in stops])
    return np.stack([np.interp(t, xs, cs[:, i]) for i in range(3)], 2)


NIGHT = ((0, "070708"), (.14, "120e0b"), (.34, "33271c"), (.55, "725f47"), (.76, "c4aa82"), (1, "f6e6bb"))
HOT = ((0, "9c2f12"), (.45, "ee7a36"), (.75, "ffc56e"), (1, "fff5d6"))
SUMI = hexc("0b0a09")


def compose_dark(wall_ink, wall_tone, fire, plate, fig_ink, fig_alpha):
    """ink over paper, the paper as far lit as the fire reaches, the figure in front"""
    light = torch_light()
    yy, xx = np.mgrid[0:SH, 0:SW].astype(np.float32)
    fill = .46 * np.exp(-((xx - 960) / 760) ** 2 - ((yy - 400) / 560) ** 2)
    g = ramp(np.clip(.05 + light * .80 + fill, 0, 1), NIGHT) * (.42 + .58 * wall_tone)[..., None]
    wall = g * (1 - wall_ink[..., None] * .96) + SUMI * wall_ink[..., None] * .96
    # the glow of the fire on the air
    glow = np.zeros((SH, SW), np.float32)
    for tx, ty in TORCHES:
        glow = np.maximum(glow, np.exp(-(np.hypot(xx - tx, yy - ty) / 150) ** 2))
    wall = np.clip(wall + hexc("c8641e") * (glow * .30)[..., None], 0, 1)
    hot = ramp(np.clip((plate - .30) / .62, 0, 1), HOT)
    a = ndi.gaussian_filter(fire.astype(np.float32), 1.0)[..., None]
    wall = wall * (1 - a) + hot * a
    wall = lay(wall, plaque_dark())
    # the figure: the same paper, always lit enough to carve it out of the dark, falling away towards the foot
    foot = np.clip((yy - 880) / 260, 0, 1)
    fl = np.clip((.86 + light * .25) * (1 - .52 * foot), 0, 1)
    fig = ramp(fl, NIGHT) * (1 - fig_ink[..., None]) + SUMI * fig_ink[..., None]
    a = fig_alpha[..., None]
    return wall * (1 - a) + fig * a, wall


def dark_layers():
    """what the painting's frames share: the mask's picture, the hair and the robe, the hall, what lies on the face"""
    a, m = mask_source()
    back = demon_back()
    wall = wall_dark()
    _, _, box = demon_mask(a, m, 0.0)
    return {"a": a, "m": m, "back": back, "wall": wall, "box": box, "front": demon_front(box)}


def dark_frame(L, o, a=None, flames=True):
    """the painting at jaw opening o (0 shut): float RGB, SH x SW. a: the mask's picture, another's (eyes shut …)"""
    mk_i, mk_a, _ = demon_mask(L["a"] if a is None else a, L["m"], o)
    bk_i, bk_a = L["back"]
    fr_i, fr_l = L["front"]
    ink = bk_i * (1 - mk_a) + mk_i * mk_a
    ink = np.maximum(ink, fr_i * mk_a) * (1 - fr_l * mk_a)
    alpha = np.maximum(np.maximum(bk_a, mk_a), fr_i)
    wall_i, wall_t, fire, plate = L["wall"]
    img, _ = compose_dark(wall_i, wall_t, fire if flames else np.zeros_like(fire), plate, ink, alpha)
    return np.clip(img, 0, 1)


def save(img, path):
    Image.fromarray((np.clip(img, 0, 1) * 255 + .5).astype(np.uint8)).save(path, optimize=True)


# ── the quotes (design-system §0): one per mood, on a plaque, as a temple's hall carries its name ─────

QUOTE_FONT = CACHE / "fonts/yujiboku/YujiBoku-Regular.ttf"    # Yuji Boku (google/fonts, OFL): a brush's own hand
QUOTES = {"dark": "口は禍の門", "light": "言わぬが花"}


def lettered(text, size, vertical=False, pitch=None):
    """the quote's coverage at 3 x: (float array)"""
    f = ImageFont.truetype(str(QUOTE_FONT), size * 3)
    p = (pitch or size + 4) * 3
    w, h = (size * 3 + 12, p * len(text) + 12) if vertical else (p * len(text) + 12, size * 3 + 12 + size)
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    for i, ch in enumerate(text):
        x, y = (w // 2, 6 + p * i + p // 2) if vertical else (6 + p * i + p // 2, h // 2)
        d.text((x, y), ch, font=f, fill=255, anchor="mm")
    return np.asarray(im, dtype=np.float32) / 255


def plaque_dark():
    """a stone tablet between the horns, the quote cut in and gilded: (rgb, alpha) at final size, its corner"""
    size, pitch = 40, 46
    t = lettered(QUOTES["dark"], size, pitch=pitch)
    tw, th = t.shape[1], t.shape[0]
    W, H = tw + 3 * 42, th + 3 * 8
    W -= W % 3
    H -= H % 3
    x0, y0 = (W - tw) // 2, (H - th) // 2
    letters = np.zeros((H, W), np.float32)
    letters[y0:y0 + th, x0:x0 + tw] = t
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    tone = .62 - .16 * ie.blur(letters, 8) + .10 * np.sin(xx / 330 + yy / 90)
    ink = ie.engrave(np.clip(tone, 0, 1), pitch=10, ride=12, angle=24, key_s=2.2)
    edge = np.zeros((H, W), bool)
    edge[:6], edge[-6:], edge[:, :6], edge[:, -6:] = True, True, True, True
    edge[15:18, 15:-15], edge[-18:-15, 15:-15], edge[15:-15, 15:18], edge[15:-15, -18:-15] = True, True, True, True
    ink = np.maximum(ink * (1 - letters), edge.astype(np.float32))
    # the cut: dark down its upper left, the gilt in it, a lit line at its lower right
    cut = np.clip(ndi.shift(letters, (-4, -4), order=0) - letters, 0, 1)
    lit = np.clip(ndi.shift(letters, (3, 3), order=0) - letters, 0, 1)
    rgb = np.ones((H, W, 3), np.float32) * hexc("9a8664")
    rgb = rgb * (1 - ie.blur(lit, .5)[..., None]) + hexc("d9c79a") * ie.blur(lit, .5)[..., None]
    rgb = rgb * (1 - ink[..., None]) + SUMI * ink[..., None]
    rgb = rgb * (1 - cut[..., None]) + SUMI * cut[..., None]
    rgb = rgb * (1 - letters[..., None]) + hexc("efc465") * letters[..., None]
    out = np.dstack([ie.reduce3(rgb[..., i]) for i in range(3)])
    return out, np.ones(out.shape[:2], np.float32), (SW // 2 - out.shape[1] // 2, 20)


def plaque_light():
    """a print's title slip, the quote down it in sumi, the red seal under: (rgb, alpha) at final size, its corner"""
    size, pitch = 44, 48
    t = lettered(QUOTES["light"], size, vertical=True, pitch=pitch)
    tw, th = t.shape[1], t.shape[0]
    seal = 34 * 3
    W, H = tw + 3 * 12, th + seal + 3 * 26
    W -= W % 3
    H -= H % 3
    x0, y0 = (W - tw) // 2, 3 * 8
    letters = np.zeros((H, W), np.float32)
    letters[y0:y0 + th, x0:x0 + tw] = t
    edge = np.zeros((H, W), bool)
    edge[:6], edge[-6:], edge[:, :6], edge[:, -6:] = True, True, True, True
    edge[12:14, 12:-12], edge[-14:-12, 12:-12], edge[12:-12, 12:14], edge[12:-12, -14:-12] = True, True, True, True
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    sx, sy = W // 2, y0 + th + seal // 2 + 3 * 3
    d.rounded_rectangle([sx - seal // 2, sy - seal // 2, sx + seal // 2, sy + seal // 2], 9, fill=255)
    shu = np.asarray(im, dtype=np.float32) / 255
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    for k in range(5):
        th_ = -math.pi / 2 + k / 5 * 2 * math.pi
        pts = [(t_ * 34, math.sin(t_ * math.pi) * 16) for t_ in np.linspace(0, 1, 12)] + [(29, 0)] + [(t_ * 34, -math.sin(t_ * math.pi) * 16) for t_ in np.linspace(1, 0, 12)]
        d.polygon([(sx + 4 * math.cos(th_) + a * math.cos(th_) - b * math.sin(th_), sy + 4 * math.sin(th_) + a * math.sin(th_) + b * math.cos(th_)) for a, b in pts], fill=255)
    d.ellipse([sx - 5, sy - 5, sx + 5, sy + 5], fill=0)
    shu = shu * (1 - np.asarray(im, dtype=np.float32) / 255)
    rgb = np.ones((H, W, 3), np.float32) * PAPER
    rgb = rgb * (1 - edge[..., None]) + SUMI_L * edge[..., None]
    rgb = rgb * (1 - letters[..., None]) + SUMI_L * letters[..., None]
    rgb = rgb * (1 - shu[..., None]) + SHU * shu[..., None]
    out = np.dstack([ie.reduce3(rgb[..., i]) for i in range(3)])
    return out, np.ones(out.shape[:2], np.float32), (556, 26)


def lay(img, plaque):
    """a plaque laid on a picture"""
    rgb, a, (x, y) = plaque
    h, w = a.shape
    img[y:y + h, x:x + w] = img[y:y + h, x:x + w] * (1 - a[..., None]) + rgb * a[..., None]
    return img


# ── what lives on the painting: lock-scene.txt's strips ──────────────────────────────────

def write_rgba(frames, path):
    """frames side by side: (rgb, alpha) floats"""
    rgb = np.hstack([f[0] for f in frames])
    a = np.hstack([f[1] for f in frames])
    save(np.dstack([rgb, a]), path)


def gate_strip(frames, path, keep=None):
    """the frames, shut first, cut to what moves (and `keep`, a box x0 y0 x1 y1 it must hold): (x, y, w, h, n)"""
    moved = np.zeros(frames[0].shape[:2], bool)
    for f in frames[1:]:
        moved |= np.abs(f - frames[0]).max(2) > 1 / 255
    ys, xs = np.nonzero(moved)
    x0, x1, y0, y1 = xs.min() - 2, xs.max() + 3, ys.min() - 2, ys.max() + 3
    if keep:
        x0, y0, x1, y1 = min(x0, keep[0]), min(y0, keep[1]), max(x1, keep[2]), max(y1, keep[3])
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, SW), min(y1, SH)
    save(np.hstack([f[y0:y1, x0:x1] for f in frames]), path)
    return x0, y0, x1 - x0, y1 - y0, len(frames)


def flame_frames(plate, fire, box, stops=None, n=8, lines=None, line_ink=None):
    """a fire cut from its plate, licking: n looped frames (rgb, alpha) of `box` x y w h; the root at the box's foot stays.
    lines: the plate's own ink on it, in line_ink"""
    x, y, w, h = box
    hot = ramp(np.clip((plate[y:y + h, x:x + w] - .30) / .62, 0, 1), stops or HOT)
    if lines is not None:
        li = lines[y:y + h, x:x + w, None]
        hot = hot * (1 - li) + line_ink * li
    a0 = ndi.gaussian_filter(fire.astype(np.float32), .6)[y:y + h, x:x + w]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    up = np.clip((h - yy) / h, 0, 1)
    out = []
    for k in range(n):
        ph = 2 * math.pi * k / n
        dx = up ** 1.3 * (6.5 * np.sin(ph + yy / 15) + 3.0 * np.sin(2 * ph + yy / 7 + 1.2))
        dy = up * (5 + 5 * math.sin(2 * ph + .7))
        sy, sx = yy + dy, xx - dx
        rgb = np.stack([ndi.map_coordinates(hot[..., i], [sy, sx], order=1, mode="nearest") for i in range(3)], 2)
        a = np.clip((ndi.map_coordinates(a0, [sy, sx], order=1, mode="constant") - .5) * 2.4 + .5, 0, 1)
        out.append((rgb, a))
    return out


def low_noise(rng, h, w, s=90):
    """a slow field in about -1…1"""
    n = rng.normal(0, 1, (max(h // 8, 2), max(w // 8, 2))).astype(np.float32)
    n = ndi.gaussian_filter(n, s / 8, mode="reflect")
    n /= max(np.abs(n).max(), 1e-6)
    return np.asarray(Image.fromarray(n).resize((w, h), Image.BICUBIC), dtype=np.float32)


# how far the fire has sunk, frame by frame (0: the painting as it is, its brightest): never a strobe, a breath
SINK = (0, .25, .1, .45, .7, .35)


def light_frames(box, torch, strength, colour, seed, R=640, calm=120):
    """the torch's breath on the stone: a dark veil of one colour over the painting, thin where the fire is high: ink stays
    ink, paper falls and rises with it, no colour pasted on the carvings. box x y w h; calm: the fire's own radius, where
    it thins out. Nothing at the box's edges inside the screen: no rectangle ever shows"""
    x, y, w, h = box
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[y:y + h, x:x + w].astype(np.float32)
    win = np.ones((h, w), np.float32)
    if x + w < SW:
        win *= np.clip((x + w - xx) / 140, 0, 1)
    if x > 0:
        win *= np.clip((xx - x) / 140, 0, 1)
    if y + h < SH:
        win *= np.clip((y + h - yy) / 140, 0, 1)
    if y > 0:
        win *= np.clip((yy - y) / 140, 0, 1)
    win = win * win * (3 - 2 * win)
    fields = [low_noise(rng, h, w) for _ in SINK]
    cols = np.ones((h, w, 3), np.float32) * hexc(colour)
    out = []
    for k, f in enumerate(SINK):
        th = 2 * math.pi * k / len(SINK) + seed
        cx, cy = torch[0] + 9 * math.sin(th), torch[1] + 5 * math.cos(2 * th)
        d = np.hypot(xx - cx, (yy - cy) * .85)
        near = np.exp(-(d / R) ** 1.5) * (1 - np.exp(-(d / calm) ** 2))
        out.append((cols, np.clip(strength * f * near * (1 + .4 * fields[k]) * win, 0, 1)))
    return out


def glint_frames(size, rim, ink="d8481c", n=8):
    """an eye's catch-light, the fire seen in the pupil: a point cut clean, the faintest red round it. n frames.
    rim: where the light comes from (-1 left, 1 right)"""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = size / 2
    out = []
    for k, f in enumerate((1, .7, .9, .5, 1, .75, .45, .85)[:n]):
        wob = math.sin(2 * math.pi * k / n)
        d1 = np.hypot(xx - (c + rim * 6 + wob * .6), (yy - (c - 6 + wob * .4)) * .8)
        spot = np.clip(2.6 - d1, 0, 1)
        glow = np.exp(-(np.hypot(xx - c, yy - c) / 15) ** 2) * .16
        a = np.maximum(spot, glow) * (.5 + .5 * f)
        rgb = np.ones((size, size, 3), np.float32) * hexc(ink)
        rgb = rgb * (1 - spot[..., None]) + hexc("ffe2ae") * spot[..., None]
        out.append((rgb, a * (np.hypot(xx - c, yy - c) < c - 2)))
    return out


def ember_marks(path, n=8, w=22, h=32):
    """the password's marks in the mouth: small drawn fires, no two alike"""
    S_ = 8
    frames = []
    for k in range(n):
        rng = np.random.default_rng(300 + k)
        lean = rng.uniform(-3.2, 3.2)
        W_, H_ = w * S_, h * S_
        def shape(scale):
            pts = [(0, 0), (-5.2 * scale, -4.6 * scale), (-3.6 * scale + lean * .2, -11 * scale), (-1.5 * scale + lean * .5, -15 * scale),
                   (lean * .9, -22 * scale), (2.8 * scale + lean * .5, -14 * scale), (4.8 * scale + lean * .2, -9 * scale), (5.0 * scale, -3.6 * scale), (0, 0)]
            return dr.spline([(w / 2 + a * 1.25, h - 3 + b * 1.14) for a, b in pts], 10) * S_
        def fill(scale, dy=0.0):
            im = Image.new("L", (W_, H_), 0)
            ImageDraw.Draw(im).polygon([(float(a), float(b - dy * S_)) for a, b in shape(scale)], fill=255)
            return np.asarray(im.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255
        outer, mid, core = fill(1.0), fill(.68), fill(.36, 1.0)
        rgb = np.ones((h, w, 3), np.float32) * hexc("e8561a")
        rgb = rgb * (1 - mid[..., None]) + hexc("ff9a3c") * mid[..., None]
        rgb = rgb * (1 - core[..., None]) + hexc("fff0c4") * core[..., None]
        halo = ndi.gaussian_filter(outer, 2.6) * .55
        frames.append((rgb, np.clip(np.maximum(outer, halo), 0, 1)))
    write_rgba(frames, path)


def scene_txt(path, gate, flame, flames, marks, row, words, anims, sparks, spawns, ink, caps, caret, ground):
    w = ["# lock-scene.txt: where kawa-lockmod draws on lock-scene.png, in its pixels: a painting, shown whole",
         "# (tools/build-ink.py writes it; lock-scene.png is the gate open, the strips lie over it).",
         f"size {SW} {SH}", f"ground {ground}   # round the painting on another screen's shape",
         "gate {} {} {} {} {}   # lock-gate.png: its frames side by side, shut first: where they lie, each's size, how many".format(*gate),
         "frames {} {} {}   # lock-flame.png: the frames side by side, 8 a second".format(*flame)]
    w += [f"flame {x} {y}   # a flame's frame, its top-left" for x, y in flames]
    w += ["markscale 2   # the caret's width, a spark, the shake", "marks {} {} {}   # lock-marks.png: mark i is the strip's i % N".format(*marks),
          "row {} {} {} {}   # the password: the first mark's middle, the pitch, how many in sight".format(*row),
          f"mark {ink[0]} {ink[1]} {ink[2]}   # a mark's main ink (its look is the strip's)", f"caps {caps}   # the marks' ink while Caps Lock is on",
          f"caret {caret}   # a bar as tall as a mark at the next place, once a second",
          "words {} {}   # the line of words (what PAM says): the rows it is centred in".format(*words)]
    w += ["anim {} {} {} {} {} {} {}   # lock-NAME.png: a looped strip with alpha, a frame every MS".format(*a) for a in anims]
    w += ["sparks {} {} {} {}   # particles: how many, their young ink and their old".format(*sparks)]
    w += ["spawn {} {} {} {}   # where they are born".format(*b) for b in spawns]
    pathlib.Path(path).write_text("\n".join(w) + "\n")


# ── the angel: M2, Schongauer's Gabriel over the waves, one continuous scene ──────────────

GAB_SRC = SRC / "schongauer-gabriel.jpg"
PAPER = hexc("f3ead3")
SUMI_L = hexc("1a1818")
AI = hexc("1f3a5f")
AI2 = hexc("6b8aa8")
GOLD = hexc("c89b3c")
AS = .26                                    # final pixels per pixel of the plate
AX, AY = 638, 65                            # where the plate's corner lies on the screen
HEAD = (985, 196)                           # the head's middle on the screen, the halo's
LANTERNS = ((397, 150), (1515, 150))        # the fires' middles on the screen
# what is kept of the plate: the figure, its sleeve and hands, the banderole left behind (plate's pixels)
FIG_POLY = [(340, 2120), (312, 1600), (380, 800), (472, 400), (660, 200), (952, 112), (1000, 225), (1420, 20), (1760, 150), (1760, 300), (1580, 520),
            (1680, 760), (1620, 940), (1790, 1005), (1860, 990), (1880, 900), (1905, 860), (1932, 800), (1940, 758), (1975, 752), (1990, 835), (2060, 770),
            (2085, 728), (2112, 732), (2104, 762), (2126, 738), (2134, 755), (2064, 850), (2084, 890), (2092, 922), (2062, 952), (2032, 1010), (2022, 1050),
            (2002, 1078), (1988, 1120), (1998, 1180), (1972, 1232), (1905, 1285), (1885, 1400), (1965, 1535), (2040, 1538), (2092, 1538), (2112, 1568),
            (2152, 1588), (2152, 1642), (2140, 1672), (2120, 1702), (2050, 1684), (1962, 1692), (1925, 1705), (1895, 1760), (1880, 1848), (2100, 2600),
            (2100, 3380), (1912, 3520), (1520, 3540), (1088, 3808), (600, 3728), (280, 3460), (400, 3220), (620, 3160), (660, 2860), (792, 2480), (680, 2080),
            (792, 1720), (600, 1720), (540, 1920)]
# the staff, from under the lily to its knob (the plate's own line, redrawn where the banderole hid it)
STAFF = ((2212, 250), (2102, 1812))


def APX(sx, sy):
    return AX + AS * sx, AY + AS * sy


def angel_figure():
    """the plate's line kept and strengthened to the sea's weight, its paper filled: (ink, silhouette, lily's ink) at final size"""
    g = np.asarray(Image.open(GAB_SRC).convert("L"), dtype=np.float32) / 255
    flat = g / np.maximum(ie.blur(g, 120), .2)
    ink = np.clip((.76 - flat) / .2, 0, 1)
    H, W = g.shape
    pm = Image.new("1", (W, H), 0)
    ImageDraw.Draw(pm).polygon(FIG_POLY, fill=1)
    pm = np.asarray(pm, dtype=bool)
    # the silhouette, from its own contour: its gaps closed at a quarter of the size, then all it holds
    q = 4
    small = np.asarray(Image.fromarray((ink * pm * 255).astype(np.uint8)).resize((W // q, H // q), Image.BOX), dtype=np.float32) / 255 > .16
    st = ndi.generate_binary_structure(2, 2)
    solid = ndi.binary_fill_holes(ndi.binary_closing(small, st, iterations=8))
    solid = ndi.binary_opening(solid, st, iterations=3)
    lab, n = ndi.label(solid)
    solid = lab == (1 + int(np.argmax(ndi.sum(solid, lab, range(1, n + 1)))))
    sil = ndi.gaussian_filter(np.asarray(Image.fromarray(solid.astype(np.uint8) * 255).resize((W, H), Image.BILINEAR), dtype=np.float32) / 255, 3) > .5
    sil &= pm
    keep = ndi.binary_dilation(sil, st, iterations=4)
    # the paper's specks out (on her cheek above all): only lines stay
    lab, n = ndi.label(ink > .5)
    sizes = ndi.sum(np.ones_like(lab), lab, np.arange(1, n + 1))
    ink = ink * ((sizes >= 140)[np.maximum(lab - 1, 0)] | (lab == 0))
    # the line's weight: the burin's cut, a little wider, for the final size
    heavy = ndi.grey_dilation(ink, size=(3, 3))
    # the lily on the staff's head
    lily = np.zeros_like(ink)
    lily[30:262, 2135:2285] = heavy[30:262, 2135:2285]
    def fit(a):
        w, h = int(W * AS * 3), int(H * AS * 3)
        b = np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS), dtype=np.float32) / 255
        out = np.zeros((SH * 3, SW * 3), np.float32)
        x, y = AX * 3, AY * 3
        y1, x1 = min(y + h, SH * 3), min(x + w, SW * 3)
        out[y:y1, x:x1] = b[:y1 - y, :x1 - x]
        return ie.reduce3(out)
    return fit(heavy * keep), fit(sil.astype(np.float32)), fit(lily)


def setting_light(name="bl-1103"):
    """the sea, the clouds, the pillars: the plate's lines in one ink, its washes in ai and a little sumi: (ink, wash RGB,
    fire's mask, the plate's light)"""
    im = Image.open(CAND / f"{name}.png").convert("RGB")
    w, h = im.size
    plate = np.asarray(im.crop((0, 4, w, h - 4)), dtype=np.float32) / 255
    L = plate @ np.array([.3, .59, .11], np.float32)
    big = np.asarray(Image.fromarray((L * 255).astype(np.uint8)).resize((SW * 3, SH * 3), Image.LANCZOS), dtype=np.float32) / 255
    local = ie.blur(big, 26)
    ink = ie.reduce3(np.clip((local * .87 - big) / .055, 0, 1))
    r, b = ie.blur(plate[..., 0], 1.0), ie.blur(plate[..., 2], 1.0)
    Ls = ie.blur(L, 1.4)
    blue = np.clip((b - r) / .27, 0, 1) ** .8 * .95
    ramp_ = np.clip((.66 - Ls) / .40, 0, 1)[..., None]
    col = AI2 * (1 - ramp_) + AI * ramp_
    wash = PAPER * (1 - blue[..., None]) + col * blue[..., None]
    stone = np.clip((.82 - ie.blur(L, 2.4)) / .62, 0, 1) * (1 - np.clip(blue * 1.6, 0, 1))
    wash = wash * (1 - .50 * stone[..., None]) + hexc("3a3734") * (.50 * stone)[..., None]
    # the fires: found on the plate, lifted off it (the strip brings them back, alive); their glow one soft wash of gold
    yy, xx = np.mgrid[0:SH, 0:SW].astype(np.float32)
    fire = np.zeros((SH, SW), bool)
    glow = np.zeros((SH, SW), np.float32)
    raw_ink = ink.copy()
    for (fx, fy), (ex, ey) in zip(LANTERNS, ((56, 72), (56, 96))):
        off = np.clip(1.4 * np.exp(-((xx - fx) / ex) ** 2 - ((yy - fy) / ey) ** 2), 0, 1)
        glow = np.maximum(glow, np.exp(-(np.hypot(xx - fx, (yy - fy) * .9) / 215) ** 2))
        ink = ink * (1 - off)
        wash = wash * (1 - off[..., None]) + hexc("f8e4ac") * off[..., None]
    wash = wash * (1 - (.55 * glow)[..., None]) + hexc("efc978") * (.55 * glow)[..., None]
    # the left fire's own shape, for the strip
    fx, fy = LANTERNS[0]
    boxm = (np.abs(xx - fx) < 70) & (np.abs(yy - fy) < 100)
    part = boxm & ((plate[..., 0] - plate[..., 2]) > .34) & (plate[..., 0] > .78)
    lab, n = ndi.label(part)
    if n:
        part = lab == (1 + int(np.argmax(ndi.sum(part, lab, range(1, n + 1)))))
    fire = ndi.binary_fill_holes(ndi.binary_closing(part, iterations=2))
    # the air's lines in ai, the rest in sumi: the print's blue block
    line = SUMI_L * (1 - (blue * (1 - ramp_[..., 0]))[..., None]) + AI * (blue * (1 - ramp_[..., 0]))[..., None]
    return ink, wash, fire, Ls, line, raw_ink


def blossom(ink, lit, gold, rng, cx, cy, r):
    """a sakura blossom on the working plates (3 x): paper petals, one ink, a gold heart"""
    rot = rng.uniform(0, 6.28)
    for k in range(5):
        a = rot + k / 5 * 2 * math.pi
        pts = [(t * r, math.sin(t * math.pi) * .52 * r) for t in np.linspace(0, 1, 14)] + [(r * .86, 0)] + [(t * r, -math.sin(t * math.pi) * .52 * r) for t in np.linspace(1, 0, 14)]
        q = [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]
        lit.polygon(q, fill=255)
        ink.line(q + [q[0]], fill=255, width=5)
    gold.ellipse([cx - r * .15, cy - r * .15, cx + r * .15, cy + r * .15], fill=255)


def sakura():
    """the blossoms in the air: (cover, ink, gold) at final size"""
    W, H = SW * 3, SH * 3
    a, b, c = [Image.new("L", (W, H), 0) for _ in range(3)]
    da, db, dc = [ImageDraw.Draw(i) for i in (a, b, c)]
    rng = np.random.default_rng(11)
    for x, y, r in ((560, 300, 12), (690, 92, 15), (470, 560, 11), (700, 480, 13), (610, 690, 15), (780, 300, 10), (1330, 560, 13),
                    (1290, 118, 12), (1440, 460, 15), (1360, 700, 11), (1600, 330, 10), (1630, 640, 14)):
        blossom(db, da, dc, rng, x * 3, y * 3, r * 3)
    return [ie.reduce3(np.asarray(i, dtype=np.float32) / 255) for i in (a, b, c)]


def halo_ring():
    W, H = 400 * 3, 400 * 3
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    c = W / 2
    d.ellipse([c - 375, c - 375, c + 375, c + 375], outline=255, width=16)
    d.ellipse([c - 398, c - 398, c + 398, c + 398], outline=255, width=5)
    return ie.reduce3(np.asarray(im, dtype=np.float32) / 255)


def halo_rays(turn):
    """the rays at a turn of 0…1 of two rays' pitch: 400 x 400"""
    W = 400 * 3
    im = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(im)
    c = W / 2
    for k in range(72):
        a = (k + 2 * turn) / 72 * 2 * math.pi
        r0, r1 = 398, (452 if k % 2 else 492)
        d.line([c + r0 * math.cos(a), c + r0 * math.sin(a), c + r1 * math.cos(a), c + r1 * math.sin(a)], fill=255, width=5)
    return ie.reduce3(np.asarray(im, dtype=np.float32) / 255)


def paste_box(a, box_xy, canvas_shape):
    out = np.zeros(canvas_shape, np.float32)
    x, y = box_xy
    h, w = a.shape
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, canvas_shape[1]), min(y + h, canvas_shape[0])
    out[y0:y1, x0:x1] = a[y0 - y:y1 - y, x0 - x:x1 - x]
    return out


# ── her scroll: the banderole become a sutra, rolled on the staff ───────────────────────────

SCROLL_Y = (255, 405)                       # the paper's rows on the screen
SCROLL_L = 360                              # how far it unrolls
SCROLL_Q = (0, .16, .4, .8, .92, .97, 1)    # the frames, shut first
LIGHT_ROW = (1250, 330, 32, 8)
SHU = hexc("b5301c")


def staff_x(y):
    """the staff's x on the screen at row y"""
    (sx0, sy0), (sx1, sy1) = STAFF
    x0, y0, x1, y1 = *APX(sx0, sy0), *APX(sx1, sy1)
    return x0 + (x1 - x0) * (y - y0) / (y1 - y0)


def scroll_plate(q):
    """the scroll at q (0 rolled and sealed, 1 open) and the staff: (ink, tone-paper alpha, gold, shu) at final size"""
    W, H = SW * 3, SH * 3
    P = dr.Plate(W, H)
    gold = np.zeros((H, W), np.float32)
    shu = np.zeros((H, W), np.float32)
    # the staff, whole
    st = [np.array(APX(*STAFF[0])) * 3, np.array(APX(*STAFF[1])) * 3]
    dr.tube(P, [st[0], (st[0] + st[1]) / 2, st[1]], 21, 21, light=-.4, base=.62)
    kx, ky = np.array(APX(*STAFF[1])) * 3
    P.fill(np.array(dr.volute(kx, ky, 20, turns=1, n=40)), .3)
    y0, y1 = SCROLL_Y[0] * 3, SCROLL_Y[1] * 3
    yc = (y0 + y1) / 2
    xr = staff_x(yc / 3) * 3
    rw = (56 - 22 * q) * 3                  # the roll thins as the paper leaves it
    L = q * SCROLL_L * 3
    xe = xr + L
    if q > 0:
        # the paper: a gentle wave along it, one tone: the engraver shades it towards both rolls
        n = 40
        xs = np.linspace(xr, xe, n)
        wob = 4.5 * np.sin((xs - xr) / 170)
        top = np.stack([xs, y0 + wob], 1)
        bot = np.stack([xs[::-1], (y1 + wob)[::-1]], 1)
        s, m = P.box(np.vstack([top, bot]))
        yy, xx = np.mgrid[s[0].start:s[0].stop, s[1].start:s[1].stop].astype(np.float32)
        tone = 1 - .42 * np.exp(-(xx - xr) / 60) - .42 * np.exp(-(xe - xx) / 46)
        P.tone[s][m] = np.clip(tone + .05, 0, 1)[m]
        P.mask[s] |= m
        # its frame: a double rule top and foot, gold columns between the marks
        for off, w in ((-15 * 3, 3.2), (-11.4 * 3, 1.4), (15 * 3, 3.2), (11.4 * 3, 1.4)):
            ys = ((y0 + abs(off)) if off < 0 else (y1 - abs(off))) + wob
            c = np.stack([xs, ys], 1)
            mg = Image.new("L", (W, H), 0)
            ImageDraw.Draw(mg).line([tuple(p) for p in c], fill=255, width=max(int(w), 1))
            gold = np.maximum(gold, np.asarray(mg, dtype=np.float32) / 255)
        mg = Image.new("L", (W, H), 0)
        dg = ImageDraw.Draw(mg)
        px = LIGHT_ROW[2] * 3
        col = LIGHT_ROW[0] * 3 - px / 2
        while col < xe - 18:
            if col > xr + 18:
                w_ = 4.5 * math.sin((col - xr) / 170)
                dg.line([(col, y0 + 42 + w_), (col, y1 - 42 + w_)], fill=255, width=3)
            col += px
        gold = np.maximum(gold, np.asarray(mg, dtype=np.float32) / 255)
        P.cut(dr.stroke_poly(top, 5, 5))
        P.cut(dr.stroke_poly(bot, 5, 5))
        # the free roll at its end
        c = [(xe, y0 - 20 + wob[-1]), (xe, yc + wob[-1]), (xe, y1 + 20 + wob[-1])]
        dr.tube(P, c, 54, 54, light=.30, base=.84)
        for yk in (y0 - 22 + wob[-1], y1 + 22 + wob[-1]):
            P.fill(np.array(dr.volute(xe, yk, 21, turns=1, n=40)), .34)
            P.cut(dr.outline(np.array(dr.volute(xe, yk, 21, turns=1, n=40)), 4))
    # the roll on the staff
    c = [(staff_x((y0 - 42) / 3) * 3, y0 - 42), (staff_x(yc / 3) * 3, yc), (staff_x((y1 + 42) / 3) * 3, y1 + 42)]
    dr.tube(P, c, rw, rw, light=.30, base=.86, ring_every=.11 if q == 0 else 0, ring_depth=.16)
    if q == 0:
        # sealed: a cord round its middle, the hanko over the knot
        P.cut(dr.stroke_poly(np.array([(xr - rw * .52, yc - 16), (xr + rw * .52, yc - 12)]), 7, 7))
        P.cut(dr.stroke_poly(np.array([(xr - rw * .52, yc + 12), (xr + rw * .52, yc + 16)]), 7, 7))
        sz = 66
        im = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([xr - sz, yc - sz, xr + sz, yc + sz], 12, fill=255)
        shu = np.asarray(im, dtype=np.float32) / 255
        # what the seal says: a sakura, cut out of the red, inside a hairline
        im = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([xr - sz + 9, yc - sz + 9, xr + sz - 9, yc + sz - 9], 7, outline=255, width=4)
        for k in range(5):
            th = -math.pi / 2 + k / 5 * 2 * math.pi
            pts = [(t * 44, math.sin(t * math.pi) * 21) for t in np.linspace(0, 1, 12)] + [(38, 0)] + [(t * 44, -math.sin(t * math.pi) * 21) for t in np.linspace(1, 0, 12)]
            d.polygon([(xr + 6 * math.cos(th) + a_ * math.cos(th) - b_ * math.sin(th), yc + 6 * math.sin(th) + a_ * math.sin(th) + b_ * math.cos(th)) for a_, b_ in pts], fill=255)
        d.ellipse([xr - 6, yc - 6, xr + 6, yc + 6], fill=0)
        shu = shu * (1 - np.asarray(im, dtype=np.float32) / 255)
    tone = np.where(P.mask, P.tone, 1.0)
    ink = ie.engrave(tone, pitch=12, ride=20, angle=70, key_s=1.6)
    ink = np.where(P.mask, ink, 0)
    ink = np.maximum(ink, P.ink) * (1 - P.lit)
    alpha = np.maximum(np.maximum(P.mask.astype(np.float32), P.ink), P.lit)
    return tuple(ie.reduce3(a) for a in (ink, alpha, gold, shu))


CREST = ((0, 1040), (520, 1040), (640, 1012), (760, 1001), (880, 992), (1000, 998), (1120, 992), (1240, 1004), (1340, 1012), (1500, 1040), (1920, 1040))


def light_layers():
    ink, wash, fire, Ls, line, raw_ink = setting_light()
    fig_i, fig_a, lily = angel_figure()
    body = np.ones((SH, SW, 3), np.float32) * PAPER
    shade = np.clip(ie.blur(fig_i, 5.0) * 2.0, 0, 1)[..., None]
    body = body * (1 - .74 * shade) + (AI2 * (1 - shade) + AI * shade) * (.74 * shade)
    base = wash * (1 - ink[..., None] * .96) + line * ink[..., None] * .96
    ring = paste_box(halo_ring(), (HEAD[0] - 200, HEAD[1] - 200), (SH, SW))
    base = base * (1 - ring[..., None]) + GOLD * ring[..., None]
    base = lay(base, plaque_light())
    sk = sakura()
    # the sea in front: the plate's own, from a line of its foam: she rises out of it
    yy, xx = np.mgrid[0:SH, 0:SW].astype(np.float32)
    c = dr.spline(CREST, 24)
    cy = np.interp(np.arange(SW), c[:, 0], c[:, 1]).astype(np.float32)
    front = np.clip(yy - cy[None, :], 0, 1)
    return {"base": base, "ink": ink, "raw_ink": raw_ink, "wash": wash, "fire": fire, "Ls": Ls, "fig_i": fig_i, "fig_a": fig_a, "lily": lily, "body": body, "sakura": sk, "front": front}


def light_frame(L, q, flames=False, a_ink=None, rays=None):
    """the painting with her scroll at q (0 rolled and sealed, 1 open): float RGB. a_ink: her lines, another's (eyes shut …)"""
    img = L["base"].copy()
    if rays is not None:
        r = paste_box(rays, (HEAD[0] - 200, HEAD[1] - 200), (SH, SW))
        img = img * (1 - r[..., None]) + GOLD * r[..., None]
    s_i, s_a, s_g, s_s = scroll_plate(q)
    paper = PAPER * .985
    sc = paper * (1 - s_i[..., None]) + SUMI_L * s_i[..., None]
    img = img * (1 - s_a[..., None]) + sc * s_a[..., None]
    img = img * (1 - s_g[..., None] * s_a[..., None]) + GOLD * (s_g * s_a)[..., None]
    img = img * (1 - s_s[..., None]) + SHU * s_s[..., None]
    lily = L["lily"][..., None]
    img = img * (1 - lily) + SUMI_L * lily
    a = L["fig_a"][..., None]
    fi = (L["fig_i"] if a_ink is None else a_ink)[..., None]
    fig = L["body"] * (1 - fi) + SUMI_L * fi
    img = img * (1 - a) + fig * a
    # outside the silhouette a line may still run a pixel on
    img = img * (1 - fi * (1 - a)) + SUMI_L * (fi * (1 - a))
    # the sea in front of her hem
    f = L["front"][..., None]
    base = L["base"]
    img = img * (1 - f) + base * f
    ca, ci, cg = L["sakura"]
    keep_clear = 1 - ndi.binary_dilation(L["fig_a"] > .5, iterations=6).astype(np.float32)
    ca, ci, cg = ca * keep_clear, ci * keep_clear, cg * keep_clear
    img = img * (1 - ca[..., None]) + PAPER * ca[..., None]
    img = img * (1 - ci[..., None]) + SUMI_L * ci[..., None]
    img = img * (1 - cg[..., None]) + GOLD * cg[..., None]
    return np.clip(img, 0, 1)


SHARE = ROOT / "configs/home/.local/share/fedokawaii"
OPENINGS = (0, .18, .4, .64, .88, 1.1, 1.3)     # the jaw's frames, shut first
DARK_ROW = (872, 834, 23, 8)


def build_dark(out):
    out.mkdir(parents=True, exist_ok=True)
    L = dark_layers()
    frames = [dark_frame(L, o, flames=False) for o in OPENINGS]
    save(frames[-1], out / "lock-scene.png")
    gate = gate_strip(frames, out / "lock-gate.png")
    _, _, fire, plate = L["wall"]
    fbox = (68, 98, 92, 176)
    write_rgba(flame_frames(plate, fire, fbox), out / "lock-flame.png")
    ember_marks(out / "lock-marks.png")
    left, right = (0, 0, 560, 760), (SW - 560, 0, 560, 760)
    write_rgba(light_frames(left, TORCHES[0], .40, "0a0604", 3), out / "lock-light-l.png")
    write_rgba(light_frames(right, TORCHES[1], .40, "0a0604", 8), out / "lock-light-r.png")
    write_rgba(glint_frames(44, -1), out / "lock-eye-l.png")
    write_rgba(glint_frames(44, 1), out / "lock-eye-r.png")
    scene_txt(out / "lock-scene.txt", gate, (92, 176, 8), [(68, 98), (1743, 98)], (22, 32, 8), DARK_ROW, (972, 1000),
              [("light-l", *left, 6, 150), ("light-r", *right, 6, 190), ("eye-l", 868 - 22, 560 - 22, 44, 44, 8, 120), ("eye-r", 1052 - 22, 558 - 22, 44, 44, 8, 135)],
              ("embers", 36, "f8b25c", "b4431a"), [(90, 110, 50, 70), (1765, 110, 50, 70)],
              ("f68c50", "f5ecc2", "82241f"), "82c1b4", "f8b25c", "070708")
    return L, frames


# the sutra's marks: strokes of one brush, never a letter, as (points in 0…1 of the mark, width at start, at end)
BRUSH = [[([(.5, .06), (.53, .5), (.46, .95)], 7.0, .8)],
         [([(.74, .08), (.5, .46), (.14, .93)], 7.0, .6)],
         [([(.24, .1), (.5, .5), (.88, .93)], 7.0, .6)],
         [([(.48, .08), (.58, .3)], 6.5, 2.2), ([(.4, .55), (.58, .93)], 7.0, .8)],
         [([(.64, .06), (.62, .6), (.38, .93), (.22, .76)], 6.5, .7)],
         [([(.72, .08), (.34, .34), (.68, .62), (.32, .93)], 5.6, .7)],
         [([(.26, .08), (.42, .26)], 6.0, 2.0), ([(.74, .3), (.46, .62), (.14, .93)], 6.5, .6)],
         [([(.18, .2), (.62, .08), (.84, .5), (.5, .93)], 6.0, .7)]]


def brush_marks(path, ink, n=8, w=26, h=40):
    """each typed character a brush mark, no word in any of them, no two alike: one ink, alpha its coverage"""
    k = 6
    frames = []
    for j in range(n):
        im = Image.new("L", (w * k, h * k), 0)
        d = ImageDraw.Draw(im)
        for pts, w0, w1 in BRUSH[j % len(BRUSH)]:
            c = dr.spline([((.08 + .84 * x) * w * k, (.04 + .92 * y) * h * k) for x, y in pts], 14)
            poly = dr.stroke_poly(c, w0 * k, w1 * k, ease=.8)
            d.polygon([(float(a), float(b)) for a, b in poly], fill=255)
            d.ellipse([c[0][0] - w0 * k / 2, c[0][1] - w0 * k / 2, c[0][0] + w0 * k / 2, c[0][1] + w0 * k / 2], fill=255)
        a = np.asarray(im.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255
        frames.append((np.ones((h, w, 3), np.float32) * ink, a))
    write_rgba(frames, path)


def build_light(out):
    out.mkdir(parents=True, exist_ok=True)
    L = light_layers()
    frames = [light_frame(L, q) for q in SCROLL_Q]
    save(frames[-1], out / "lock-scene.png")
    gate = gate_strip(frames, out / "lock-gate.png", keep=(LIGHT_ROW[0] - 20, LIGHT_ROW[1] - 40, LIGHT_ROW[0] + LIGHT_ROW[2] * LIGHT_ROW[3] + 20, LIGHT_ROW[1] + 40))
    # the fire: the left one's lines, licking; it stands on both cups
    ys, xs = np.nonzero(L["fire"])
    fw, fh = int(xs.max() - xs.min() + 40), int(ys.max() - ys.min() + 34)
    fx, fy = int(xs.min() - 20), int(ys.min() - 26)
    write_rgba(flame_frames(np.clip(L["Ls"] * 1.08, 0, 1), L["fire"], (fx, fy, fw, fh), stops=LIGHT_HOT, lines=L["raw_ink"], line_ink=hexc("6a1f0c")), out / "lock-flame.png")
    right = (fx + RIGHT_CUP[0] - LEFT_CUP[0], fy + RIGHT_CUP[1] - LEFT_CUP[1])
    brush_marks(out / "lock-marks.png", SUMI_L)
    boxl, boxr = (120, 0, 620, 520), (1180, 0, 620, 520)
    write_rgba(light_frames(boxl, LANTERNS[0], .24, "5c4a2c", 5, R=330, calm=60), out / "lock-light-l.png")
    write_rgba(light_frames(boxr, LANTERNS[1], .24, "5c4a2c", 9, R=330, calm=60), out / "lock-light-r.png")
    hbox = (HEAD[0] - 200, HEAD[1] - 200, 400, 400)
    x0, y0 = max(hbox[0], 0), max(hbox[1], 0)
    rays = []
    for k in range(10):
        r = paste_box(halo_rays(k / 10), hbox[:2], (SH, SW)) * (1 - np.clip(L["fig_a"] + L["fig_i"], 0, 1))
        rays.append((np.ones((400, 400, 3), np.float32) * GOLD, r[y0:y0 + 400, x0:x0 + 400]))
    write_rgba(rays, out / "lock-halo.png")
    scene_txt(out / "lock-scene.txt", gate, (fw, fh, 8), [(fx, fy), right], (26, 40, 8), LIGHT_ROW, LIGHT_WORDS,
              [("light-l", *boxl, 6, 170), ("light-r", *boxr, 6, 210), ("halo", x0, y0, 400, 400, 10, 150)],
              ("petals", 34, "eab0b4", "c98189"), [],
              ("1a1818", "1a1818", "96865e"), "00726a", "a84222", "f3ead3")
    return L, frames


# the fire in flat inks, as a block cuts them: shu, orange, gold, the pale heart
LIGHT_HOT = ((0, "b5301c"), (.46, "b5301c"), (.47, "ea7a2a"), (.70, "ea7a2a"), (.71, "f6c25e"), (.90, "f6c25e"), (.91, "fff3cc"), (1, "fff3cc"))
LEFT_CUP, RIGHT_CUP = (385, 188), (1527, 195)   # where the fires stand: the middle of each cup's rim
LIGHT_WORDS = (1040, 1070)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", help="write here, not into the repo's folders")
    ap.add_argument("what", nargs="?", default="all")
    args = ap.parse_args()
    root = pathlib.Path(args.out) if args.out else SHARE
    if args.what in ("dark", "lock", "all"):
        build_dark(root / "dark")
    if args.what in ("light", "lock", "all"):
        build_light(root / "light")
