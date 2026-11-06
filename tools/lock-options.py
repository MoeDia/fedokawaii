#!/usr/bin/env python3
"""tools/lock-options.py — the options for the lock's quote cut into the wall (r28 f11): the real painting's plates and
figures, the quote a V-groove lit by the torches, cut in tools/ink_engrave.py's one hand, nothing built into the lock.

    python3 tools/lock-options.py render DIR      # DIR/{dark,light}-{1,2,3}.png, 1920 x 1080
    python3 tools/lock-options.py sheet DIR MOOD OUT   # one mood's sheet, a JPEG of 295 KB at most
"""
import importlib.util
import io
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

sys.dont_write_bytecode = True
ROOT = pathlib.Path(__file__).resolve().parent.parent
sp = importlib.util.spec_from_file_location("build_ink", ROOT / "tools/build-ink.py")
bi = importlib.util.module_from_spec(sp)
sp.loader.exec_module(bi)
ie = bi.ie
SW, SH = bi.SW, bi.SH
W3, H3 = SW * 3, SH * 3
SHARE = ROOT / "configs/home/.local/share/fedokawaii"
NAMES = {1: "hengaku, the great lintel", 2: "mon, the gate's arch", 3: "hashira, cut into the piers"}
YY, XX = np.mgrid[0:H3, 0:W3].astype(np.float32)


def blank():
    return np.zeros((H3, W3), np.float32)


def light_dir(torches):
    """towards the nearer torch, at every pixel of the plate"""
    d = [(np.hypot(XX - tx * 3, YY - ty * 3), tx * 3, ty * 3) for tx, ty in torches]
    near = d[0][0] < d[1][0]
    lx, ly = np.where(near, d[0][1], d[1][1]) - XX, np.where(near, d[0][2], d[1][2]) - YY
    n = np.hypot(lx, ly) + 1
    return lx / n, ly / n


def letters(items):
    """the letters' coverage at 3 x: items of (character, size, x, y, turn in degrees, clockwise), on the final pixels"""
    out = np.zeros((H3, W3), bool)
    for ch, size, x, y, turn in items:
        f = ImageFont.truetype(str(bi.QUOTE_FONT), size * 3)
        s = size * 5
        im = Image.new("L", (s, s), 0)
        ImageDraw.Draw(im).text((s // 2, s // 2), ch, font=f, fill=255, anchor="mm")
        im = im.rotate(-turn, resample=Image.BICUBIC)
        a = np.asarray(im) > 110
        a = ndi.binary_dilation(a, iterations=size // 14)     # the brush's thin strokes would never reach a floor
        x0, y0 = int(x * 3) - s // 2, int(y * 3) - s // 2
        ya, yb, xa, xb = max(y0, 0), min(y0 + s, H3), max(x0, 0), min(x0 + s, W3)
        out[ya:yb, xa:xb] |= a[ya - y0:yb - y0, xa - x0:xb - x0]
    return out


def box_of(m, pad=30):
    ys, xs = np.nonzero(m.any(1))[0], np.nonzero(m.any(0))[0]
    return max(ys[0] - pad, 0), min(ys[-1] + pad, H3), max(xs[0] - pad, 0), min(xs[-1] + pad, W3)


def bevel(m, b):
    """the height of a raised shape with a chamfer b wide, 0 outside and b on top, and its slope"""
    y0, y1, x0, x1 = box_of(m)
    d = blank()
    d[y0:y1, x0:x1] = np.minimum(ndi.distance_transform_edt(m[y0:y1, x0:x1]), b)
    h = ie.blur(d, .8)
    return d, h


def shade(h, lx, ly):
    """how far a slope faces the torch: -1 away, 1 towards"""
    gy, gx = np.gradient(h)
    return np.clip(-(gx * lx + gy * ly) * 1.4, -1, 1)


def cut(t, m, b, lx, ly, floor=.05):
    """a V-groove into the tone t: a black floor, the wall facing the fire lit to paper, the other black, a lit lip"""
    d, h = bevel(m, b)
    s = shade(-h, lx, ly)
    inside = m.astype(np.float32)
    v = np.where(d >= b - .5, floor, np.clip(.30 + s * .95, 0, 1))
    lip = np.clip(ie.blur(ndi.binary_dilation(m, iterations=7).astype(np.float32), .8) - inside, 0, 1) * .9 * np.clip(-(np.gradient(ie.blur(inside, 6))[1] * lx + np.gradient(ie.blur(inside, 6))[0] * ly) * 26, 0, 1)
    return np.clip(t * (1 - inside) + v * inside + lip, 0, 1)


def raise_(t, m, b, lx, ly, stone=.62):
    """a block standing out of the wall, chamfered, a shadow thrown away from the fire"""
    d, h = bevel(m, b)
    s = shade(h, lx, ly)
    inside = m.astype(np.float32)
    sx, sy = np.mean(lx[m]), np.mean(ly[m])
    away = ndi.shift(inside, (-sy * 16, -sx * 16), order=0)
    t = t * (1 - .75 * np.clip(ie.blur(away, 5) - inside, 0, 1))
    v = np.clip(stone + (d < b - .5) * s * .55, 0, 1)
    return t * (1 - inside) + v * inside


def incise(t, m, lit=.8, dark=.02):
    """a hair line cut with the graver: dark, with a lit line on one side"""
    f = m.astype(np.float32)
    rim = np.clip(ndi.shift(f, (3, 3), order=0) - f, 0, 1)
    t = t * (1 - f) + dark * f
    return np.clip(t + rim * lit * .6, 0, 1)


def draw(fn):
    im = Image.new("L", (W3, H3), 0)
    fn(ImageDraw.Draw(im))
    return np.asarray(im) > 0


def grain(seed, amount=.16):
    """the stone's own pits and breaks"""
    rng = np.random.default_rng(seed)
    n = rng.normal(0, 1, (H3 // 6, W3 // 6)).astype(np.float32)
    n = np.asarray(Image.fromarray(ndi.gaussian_filter(n, .8)).resize((W3, H3), Image.BICUBIC), np.float32)
    return 1 + np.clip(n, -2, 2) * amount


def cracks(seed, n, region):
    """branches wandering down the stone, final pixels"""
    rng = np.random.default_rng(seed)
    x0, y0, x1, y1 = region

    def fn(d):
        for _ in range(n):
            x, y = rng.uniform(x0, x1) * 3, rng.uniform(y0, y1) * 3
            th = rng.uniform(0, 2 * math.pi)
            pts = [(x, y)]
            for _ in range(int(rng.integers(6, 20))):
                th += rng.normal(0, .4)
                x, y = x + math.cos(th) * 21, y + math.sin(th) * 21
                pts.append((x, y))
            d.line(pts, fill=255, width=2)
    return draw(fn)


def seigaiha(mask, r=66, width=8):
    """the wave's scales, a fine cut filling a field"""
    y0, y1, x0, x1 = box_of(mask, 0)

    def fn(d):
        for row, y in enumerate(range(y0, y1 + r, r // 2)):
            for x in range(x0 - r, x1 + r, r * 2):
                cx = x + (r if row % 2 else 0)
                for k in (1, .72, .44):
                    q = r * k
                    d.arc([cx - q, y - q, cx + q, y + q], 180, 360, fill=255, width=width)
    return draw(fn) & mask


def raimon(mask, step=36, width=9):
    """the thunder meander along a band"""
    y0, y1, x0, x1 = box_of(mask, 0)
    h = y1 - y0
    s = max(step, h // 2)

    def fn(d):
        for x in range(x0, x1, s * 2):
            a, b = y0 + h * .15, y0 + h * .85
            d.line([(x, b), (x, a), (x + s * 1.6, a), (x + s * 1.6, b - h * .2), (x + s * .5, b - h * .2), (x + s * .5, a + h * .25), (x + s * 1.1, a + h * .25)], fill=255, width=width)
    return draw(fn) & mask


def karakusa(cx, cy, r, flip=False, width=8, turns=2.5):
    """one scroll of the vine: (the spiral, final pixels at cx cy, r)"""
    s = -1 if flip else 1
    pts = []
    for i in range(70):
        u = i / 69
        a = u * turns * 2 * math.pi
        q = r * (1 - u * .86)
        pts.append(((cx + s * q * math.cos(a)) * 3, (cy + q * math.sin(a)) * 3))
    return pts, width


def scrolls(mask, pitch=64, r=30):
    """a field of scrolls, turning in pairs"""
    y0, y1, x0, x1 = box_of(mask, 0)

    def fn(d):
        for i, x in enumerate(range(x0 // 3, x1 // 3, pitch)):
            y = (y0 + y1) / 6 + (r * .28 if i % 2 else -r * .28)
            pts, w = karakusa(x, y, r, flip=bool(i % 2))
            d.line(pts, fill=255, width=w)
    return draw(fn) & mask


def rect(x0, y0, x1, y1):
    m = np.zeros((H3, W3), bool)
    m[max(y0 * 3, 0):y1 * 3, x0 * 3:x1 * 3] = True
    return m


def ring(cx, cy, r0, r1, a0, a1):
    """part of a ring, angles from straight up, clockwise"""
    r = np.hypot(XX - cx * 3, YY - cy * 3) / 3
    a = np.degrees(np.arctan2(XX - cx * 3, cy * 3 - YY))
    return (r >= r0) & (r < r1) & (a >= a0) & (a < a1)


def joints(cx, cy, r0, r1, a0, a1, step, width=8):
    def fn(d):
        a = a0
        while a <= a1 + .01:
            s, c = math.sin(math.radians(a)), math.cos(math.radians(a))
            d.line([((cx + s * r0) * 3, (cy - c * r0) * 3), ((cx + s * r1) * 3, (cy - c * r1) * 3)], fill=255, width=width)
            a += step
    return draw(fn)


def bow(t, lx, ly, cx, cy, r0, r1, span, step, stone, clip=True):
    """an arch of voussoirs with its rims, dentils and scrolled band: (the tone, the whole ring)"""
    m = ring(cx, cy, r0, r1, -span, span) & clip
    t = raise_(t, m, 14, lx, ly, stone=stone)
    t = incise(t, joints(cx, cy, r0, r1, -span, span, step))
    for a, b in ((r0 + 7, r0 + 9), (r1 - 9, r1 - 7), (r0 + 24, r0 + 26), (r1 - 26, r1 - 24)):
        t = incise(t, ring(cx, cy, a, b, -span, span))
    t = incise(t, joints(cx, cy, r0 + 9, r0 + 24, -span, span, step / 8, 6))
    t = incise(t, joints(cx, cy, r1 - 24, r1 - 9, -span, span, step / 8, 6))
    return t, m


def flames_on(img, mood):
    """the first frame of the live flames over the picture, where the lock draws them"""
    fw, fh, at = 0, 0, []
    for line in (SHARE / mood / "lock-scene.txt").read_text().splitlines():
        p = line.split()
        if p and p[0] == "frames":
            fw, fh = int(p[1]), int(p[2])
        elif p and p[0] == "flame":
            at.append((int(p[1]), int(p[2])))
    strip = np.asarray(Image.open(SHARE / mood / "lock-flame.png").convert("RGBA"), np.float32)[:fh, :fw] / 255
    for x, y in at:
        a = strip[..., 3:]
        img[y:y + fh, x:x + fw] = img[y:y + fh, x:x + fw] * (1 - a) + strip[..., :3] * a
    return img


def strands_off(alpha, clear):
    """the mane stops short of the letters; the head and the horns stay in front"""
    keep = ndi.binary_dilation(ndi.binary_opening(alpha > .5, iterations=8), iterations=4).astype(np.float32)
    yy, xx = np.mgrid[0:SH, 0:SW].astype(np.float32)
    for tip, base in (((440, 16), (800, 300)), ((1480, 16), (1120, 300))):
        dx, dy = base[0] - tip[0], base[1] - tip[1]
        u = np.clip(((xx - tip[0]) * dx + (yy - tip[1]) * dy) / (dx * dx + dy * dy), 0, 1)
        keep = np.maximum(keep, np.hypot(xx - tip[0] - u * dx, yy - tip[1] - u * dy) < 6 + u * 56)
    return alpha * (1 - ndi.binary_dilation(clear, iterations=9) * (1 - keep))


# ── dark: the hall ─────────────────────────────────────────────────────────

def dark_plate(L):
    _, _, _, plate = L["wall"]
    g = np.asarray(Image.fromarray((plate * 255).astype(np.uint8)).resize((W3, H3), Image.LANCZOS), np.float32) / 255
    t = ie.blur(ndi.median_filter(g, size=3), 1.6)
    return np.clip((t - .03) / .72, 0, 1) ** .82


Q_D = bi.QUOTES["dark"]


def dark_option(n, t, lx, ly):
    """the wall's tone with option n cut in: (tone, the letters, where the fire is helped, gilt)"""
    t = t * grain(11 + n)
    t = incise(t, cracks(20 + n, 22, (0, 0, SW, 900)), lit=.3)
    lift = blank()
    gilt = blank()
    if n == 1:
        band = rect(170, 0, 1750, 204)
        t = np.clip(raise_(t, band, 18, lx, ly, stone=.86) * grain(5, .05), 0, 1)
        t = incise(t, seigaiha(rect(190, 34, 1730, 178) & ~rect(576, 10, 1344, 200), r=54))
        for y0 in (6, 180):
            t = incise(t, raimon(rect(186, y0, 1734, y0 + 20) & ~rect(576, 0, 1344, 204), step=30))
        panel = rect(590, 14, 1330, 194)
        t = np.clip(raise_(t, panel, 10, lx, ly, stone=.93) * grain(6, .04), 0, 1)
        t = incise(t, rect(602, 26, 1318, 28) | rect(602, 180, 1318, 182) | rect(602, 26, 604, 182) | rect(1316, 26, 1318, 182))
        m = letters([(c, 136, 676 + 142 * i, 104, 0) for i, c in enumerate(Q_D)])
        t = cut(t, m, 6, lx, ly)
        lift += ie.blur(band.astype(np.float32), 30) * .55
    elif n == 2:
        cx, cy, r0, r1 = 960, 640, 440, 640
        legs = rect(cx - r1, cy, cx - r0, 1000) | rect(cx + r0, cy, cx + r1, 1000)
        t = raise_(t, legs, 14, lx, ly, stone=.82)
        t, arch = bow(t, lx, ly, cx, cy, r0, r1, 90, 13, .86)
        arch = arch | legs
        t = np.clip(t * grain(6, .05), 0, 1)
        for x0 in (cx - r1, cx + r0):
            t = incise(t, rect(x0 + 12, cy + 8, x0 + 14, 1000) | rect(x0 + 186, cy + 8, x0 + 188, 1000) | rect(x0, cy - 2, x0 + 200, cy + 2))
            t = incise(t, seigaiha(rect(x0 + 16, cy + 10, x0 + 184, 1000), r=48))
        t = incise(t, ring(cx, cy, r0 + 26, r1 - 26, -90, 90) & ~ring(cx, cy, r0 + 26, r1 - 26, -72, 72) & seigaiha(rect(0, 0, SW, SH), r=48, width=6))
        mid = (r0 + r1) / 2
        items = []
        for c, a in zip(Q_D, (-54, -26, 0, 26, 54), strict=True):
            items.append((c, 130, cx + mid * math.sin(math.radians(a)), cy - mid * math.cos(math.radians(a)), a))
        m = letters(items)
        t = cut(t, m, 6, lx, ly)
        # the spandrels over the arch: scrolled panels
        out = (np.hypot(XX - cx * 3, YY - cy * 3) / 3 >= r1 + 8) & rect(200, 8, 1720, 150)
        t = incise(t, scrolls(out & rect(200, 8, 1720, 80), pitch=62, r=30))
        t = incise(t, seigaiha(out & rect(200, 80, 1720, 150), r=42, width=6))
        rng = np.random.default_rng(4)
        fl = np.asarray(Image.fromarray(ndi.gaussian_filter(rng.normal(0, 1, (H3 // 9, W3 // 9)).astype(np.float32), 1.6)).resize((W3, H3), Image.BICUBIC), np.float32)
        gilt = ndi.binary_erosion(m, iterations=3).astype(np.float32) * (fl > .55)
        lift += ie.blur(arch.astype(np.float32), 30) * .55
    else:
        left = rect(186, 26, 470, 800)
        right = rect(1450, 26, 1734, 800)
        t = np.clip(t, 0, 1)
        for x0, x1 in ((186, 470), (1450, 1734)):
            for y0 in (26, 780):
                t = raise_(t, rect(x0, y0, x1, y0 + 24), 6, lx, ly, stone=.88)
                t = incise(t, raimon(rect(x0 + 4, y0 + 2, x1 - 4, y0 + 22), step=26))
        m = letters([(Q_D[0], 226, 1592, 190, 0), (Q_D[1], 226, 1592, 442, 0),
                     (Q_D[2], 226, 328, 190, 0), (Q_D[3], 226, 328, 442, 0), (Q_D[4], 226, 328, 672, 0)])
        t = cut(t, m, 9, lx, ly)
        # the right pier's foot: the hall's crest in the slot of the missing letter
        cr = ring(1592, 672, 52, 94, -180, 180) & ~ring(1592, 672, 62, 84, -180, 180)
        t = cut(t, cr, 8, lx, ly)
        for k in range(3):
            pts, _ = karakusa(1592 + 26 * math.cos(k * 2.094), 672 + 26 * math.sin(k * 2.094), 26, turns=1.3)
            t = cut(t, draw(lambda d, p=pts: d.line(p, fill=255, width=26)), 8, lx, ly)
        lift += ie.blur((left | right).astype(np.float32), 30) * .34
    return np.clip(t, 0, 1), m, lift, gilt


def render_dark(out):
    L = bi.dark_layers()
    wall_i, wall_t, fire, plate = L["wall"]
    t0 = dark_plate(L)
    lx, ly = light_dir(bi.TORCHES)
    mk_i, mk_a, _ = bi.demon_mask(L["a"], L["m"], 0.0)
    bk_i, bk_a = L["back"]
    fr_i, fr_l = L["front"]
    ink = np.clip(bk_i * (1 - mk_a) + mk_i, 0, 1)
    ink = np.maximum(ink, fr_i * mk_a) * (1 - fr_l * mk_a)
    alpha = np.maximum(np.maximum(bk_a, mk_a), fr_i)
    bi.plaque_dark = lambda: (np.zeros((1, 1, 3), np.float32), np.zeros((1, 1), np.float32), (0, 0))
    base_light = bi.torch_light()
    for n in (1, 2, 3):
        t, m, lift, gilt = dark_option(n, t0, lx, ly)
        ink3 = ie.engrave(t, pitch=11, ride=26, angle=38, key_s=2.8, t2=.42, t3=.18)
        fill = np.clip(base_light + ie.reduce3(lift), 0, 1)
        bi.torch_light = lambda f=fill: f
        m1 = ie.reduce3(m.astype(np.float32)) > .25
        a = strands_off(alpha, m1)
        img, _ = bi.compose_dark(ie.reduce3(ink3), ie.reduce3(t), fire, plate, ink, a)
        g = (ie.reduce3(gilt) * (1 - a))[..., None]
        img = img * (1 - g * .92) + bi.hexc("e8b954") * g * .92
        img = flames_on(np.clip(img, 0, 1).astype(np.float32), "dark")
        bi.save(img, out / f"dark-{n}.png")
        print("dark", n, flush=True)


# ── light: the pillars and the sky ─────────────────────────────────────────

Q_L = bi.QUOTES["light"]
STONE_L = bi.hexc("e6dcc2")


def seal_at(x, y, s):
    """the red seal's square, a blossom left in the paper: (coverage at 3 x)"""
    def fn(d):
        d.rounded_rectangle([(x - s) * 3, (y - s) * 3, (x + s) * 3, (y + s) * 3], 15, fill=255)
    m = draw(fn).astype(np.float32)

    def petals(d):
        for k in range(5):
            a = -math.pi / 2 + k * 2 * math.pi / 5
            q = s * .46
            cx, cy = x + math.cos(a) * q, y + math.sin(a) * q
            d.ellipse([(cx - q * .62) * 3, (cy - q * .62) * 3, (cx + q * .62) * 3, (cy + q * .62) * 3], fill=255)
    return m * (1 - draw(petals))


def light_option(n, lx, ly):
    """(tone, where the stone stands, the letters, the floors' fill ink, the seal)"""
    t = blank() + .86
    seal = blank()
    fill_ink = bi.AI
    if n == 1:
        beam = rect(292, 0, 1640, 150)
        t = raise_(t, beam, 14, lx, ly, stone=.80)
        t = t * grain(7, .07)
        t = incise(t, raimon(rect(304, 124, 1628, 144), step=24), lit=.3)
        t = incise(t, rect(304, 118, 1628, 120) | rect(304, 8, 1628, 10), lit=.3)
        t = incise(t, cracks(9, 10, (300, 0, 1630, 150)), lit=.2)
        t = incise(t, scrolls(rect(860, 12, 1110, 116), pitch=52, r=24), lit=.3)
        xs = (531, 656, 781, 1189, 1314)
        m = letters([(c, 100, x, 62, 0) for c, x in zip(Q_L, xs, strict=True)])
        t = cut(t, m, 5, lx, ly, floor=.10)
        seal = seal_at(1439, 62, 40)
        stand = beam
    elif n == 2:
        cx, cy, r0, r1 = 985, 850, 680, 826
        t, stand = bow(t, lx, ly, cx, cy, r0, r1, 90, 10, .84, clip=rect(304, 0, 1631, 600))
        t = t * grain(7, .07)
        t = incise(t, cracks(9, 14, (300, 0, 1630, 600)) & stand, lit=.2)
        mid = (r0 + r1) / 2
        items = []
        for c, a in zip(Q_L, (-44, -34, -24, 24, 34), strict=True):
            items.append((c, 90, cx + mid * math.sin(math.radians(a)), cy - mid * math.cos(math.radians(a)), a))
        m = letters(items)
        t = cut(np.clip(t, 0, 1), m, 5, lx, ly, floor=.10)
        s = (cx + mid * math.sin(math.radians(44)), cy - mid * math.cos(math.radians(44)))
        seal = seal_at(s[0], s[1], 36)
        fill_ink = bi.SUMI_L
    else:
        stand = np.zeros((H3, W3), bool)
        items = []
        for cx, rows in ((1755, Q_L[:3]), (183, Q_L[3:])):
            tab = rect(cx - 82, 628, cx + 82, 960)
            stand |= tab
            t = raise_(t, tab, 12, lx, ly, stone=.78)
            t = incise(t, rect(cx - 72, 640, cx + 72, 642) | rect(cx - 72, 946, cx + 72, 948) | rect(cx - 72, 640, cx - 70, 948) | rect(cx + 70, 640, cx + 72, 948), lit=.3)
            for i, c in enumerate(rows):
                items.append((c, 104, cx, 690 + 106 * i, 0))
        t = t * grain(7, .07)
        t = incise(t, cracks(9, 20, (100, 628, 266, 960)) | cracks(10, 20, (1673, 628, 1837, 960)), lit=.2)
        m = letters(items)
        m &= stand
        t = cut(np.clip(t, 0, 1), m, 5, lx, ly, floor=.10)
        seal = seal_at(183, 902, 36)
    return np.clip(t, 0, 1), stand, m, fill_ink, seal


def render_light(out):
    bi.plaque_light = lambda: (np.zeros((1, 1, 3), np.float32), np.zeros((1, 1), np.float32), (0, 0))
    L = bi.light_layers()
    lx, ly = light_dir(bi.LANTERNS)
    base = L["base"].copy()
    for n in (1, 2, 3):
        t, stand, m, fill_ink, seal = light_option(n, lx, ly)
        ink = ie.reduce3(ie.engrave(t, pitch=11, ride=22, angle=38, key_s=2.4, t2=.44, t3=.16))
        cov = ie.reduce3((ndi.binary_dilation(stand, iterations=18) & (rect(304, 0, 1631, 604) if n == 2 else True)).astype(np.float32))[..., None]
        tone = ie.reduce3(t)[..., None]
        stone = STONE_L * (.62 + .38 * tone) * (1 - ink[..., None] * .95) + bi.SUMI_L * ink[..., None] * .95
        pic = base * (1 - cov) + stone * cov
        fl = ie.reduce3(ndi.binary_erosion(m, iterations=3).astype(np.float32))[..., None]
        pic = pic * (1 - fl * .88) + fill_ink * fl * .88
        sl = ie.reduce3(seal)[..., None]
        pic = pic * (1 - sl) + bi.SHU * sl
        L["base"] = pic
        img = bi.light_frame(L, 0.0)
        img = flames_on(img.astype(np.float32), "light")
        bi.save(img, out / f"light-{n}.png")
        print("light", n, flush=True)


# ── the sheet ──────────────────────────────────────────────────────────────

def sheet(d, mood, out):
    CW, CH, ZH, G = 760, 428, 130, 6
    zoom = {"dark": {1: (580, 40), 2: (580, 30), 3: (1160, 120)}, "light": {1: (400, 0), 2: (340, 170), 3: (1160, 640)}}[mood]
    font = ImageFont.truetype("/usr/local/share/fonts/fedokawaii/SumiUI.ttf", 16)
    im = Image.new("RGB", (CW, (CH + ZH + 2 * G) * 3 - G), "#141110")
    dr = ImageDraw.Draw(im)
    for r in (1, 2, 3):
        a = Image.open(d / f"{mood}-{r}.png").convert("RGB")
        y = (r - 1) * (CH + ZH + 2 * G)
        im.paste(a.resize((CW, CH), Image.LANCZOS), (0, y))
        zx, zy = zoom[r]
        im.paste(a.crop((zx, zy, zx + CW, zy + ZH)), (0, y + CH + G))
        label = f"{r} {NAMES[r]}"
        dr.rectangle([0, y + CH - 24, 12 + dr.textlength(label, font=font), y + CH], fill="#141110")
        dr.text((6, y + CH - 21), label, font=font, fill="#efc465")
    for q in range(82, 20, -4):
        b = io.BytesIO()
        im.save(b, "JPEG", quality=q, optimize=True, progressive=True)
        if b.tell() <= 295 * 1024:
            pathlib.Path(out).write_bytes(b.getvalue())
            print(out, b.tell() // 1024, "KB at q", q, im.size)
            return
    raise SystemExit("no quality fits")


if __name__ == "__main__":
    what, d = sys.argv[1], pathlib.Path(sys.argv[2])
    if what == "render":
        d.mkdir(parents=True, exist_ok=True)
        render_dark(d)
        render_light(d)
    else:
        sheet(d, sys.argv[3], sys.argv[4])
