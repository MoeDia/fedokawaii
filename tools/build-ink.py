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
import hashlib
import importlib.util
import math
import pathlib

import numpy as np
from PIL import Image, ImageDraw
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


TORCHES = ((150, 268), (1772, 268))         # the fires' middles on the screen, from the hall's plate
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
        black = UP([(at(y0, sgn) + sgn * 82, y0), (at(y0, sgn) + sgn * 300, y0), (at(y1, sgn) + sgn * 300, y1), (at(y1, sgn) + sgn * 82, y1)])
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
    # the figure: the same paper, always lit enough to carve it out of the dark, falling away towards the foot
    foot = np.clip((yy - 880) / 260, 0, 1)
    fl = np.clip((.86 + light * .25) * (1 - .52 * foot), 0, 1)
    fig = ramp(fl, NIGHT) * (1 - fig_ink[..., None]) + SUMI * fig_ink[..., None]
    a = fig_alpha[..., None]
    return wall * (1 - a) + fig * a, wall


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    ap.add_argument("what", nargs="?", default="all")
    args = ap.parse_args()
