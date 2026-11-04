#!/usr/bin/env python3
"""tools/build-cover.py — the Learn book's cover (the owner, 4 Nov 18:49): a full-bleed engraving, the
angel and the demon facing each other across the page, the day and the night of this desktop, with
Hokusai's wave, clouds and sakura between them; the title in a cartouche with a red hanko.

    python3 tools/build-cover.py [--scale 0.5] [--out DIR] [--pdf]

Writes DIR/cover.jpg (A4 at 200 dpi: the book's first page), and with no --out docs/learn/cover.jpg and
docs/learn/cover-thumb.png (what Super+U's pane shows). --pdf also puts the cover in as the first page of
docs/Fedokawaii-Learn.pdf (qpdf), until the book's next rebuild does it (docs/build/handbook.py).

Made of (all out of copyright; files and sha256 in art/cover/SOURCES.md, fetched into SRC, not kept here):
the demon is lane-ink's M1 (art/cover/demon-m1.png), the owner's choice: an engraver's cut of a Hannya
mask. The angel: Martin Schongauer, The Archangel Gabriel, c. 1490. The sea: Hokusai, The Great Wave off
Kanagawa, c. 1831. Clouds, sakura, the disc and the cartouche are drawn here, in the plate's own line: a
night is swelling parallel lines, as an engraver cuts one, never a gradient.
Needs Pillow (with raqm), numpy, scipy; the faces in FONTS (OFL, URLs in SOURCES.md)."""
import argparse
import math
import pathlib
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path.home() / ".cache/r27-ink/src"
FONTS = pathlib.Path.home() / ".cache/r27-learning-cover/fonts"
DEMON = ROOT / "art/cover/demon-m1.png"
PW, PH = 1654, 2340            # the page, A4 at 200 dpi


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255


PAPER, SUMI, AI2, GOLD = rgb("f3ead3"), rgb("141211"), rgb("6b8aa8"), rgb("c89b3c")
LIT, LINE, RED, RED_LO, SEAL = rgb("efdfba"), rgb("e6d3ab"), rgb("b5381f"), rgb("6d1c15"), rgb("b02e1a")
EMBER, CLOUD_N, SHADE_N = rgb("4a1a12"), rgb("2a1f18"), rgb("7a5636")

ap = argparse.ArgumentParser()
ap.add_argument("--scale", type=float, default=1.0)
ap.add_argument("--out")
ap.add_argument("--pdf", action="store_true")
args = ap.parse_args()
SS = 2                         # lines are cut at twice the size and reduced: a crisp edge, a grey pixel at most
K = args.scale * SS            # page units → canvas pixels
W, H = round(PW * K) // SS * SS, round(PH * K) // SS * SS
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
X, Y = xx / K, yy / K          # every field below is in page units
rng = np.random.default_rng(1490)


def smooth(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def over(colour, alpha):
    global canvas
    canvas = mix(canvas, colour, alpha).astype(np.float32)


def noise(sigma, seed):
    """smooth noise, about -1…1; sigma in page units"""
    n = max(1, round(sigma * K / 4))
    a = np.random.default_rng(seed).standard_normal((H // n + 2, W // n + 2)).astype(np.float32)
    a = ndi.gaussian_filter(a, sigma * K / n, mode="reflect")
    a /= a.std() * 2.2
    return np.asarray(Image.fromarray(a, "F").resize((W, H), Image.BICUBIC), np.float32)


WOB = noise(70, 3)


def hatch(c, pitch=8.0, ride=0.55):
    """one engraver's lines: coverage c (0…1) as parallel lines that swell, riding a slow wobble"""
    phase = Y / pitch + ride * WOB
    f = np.abs(phase - np.floor(phase) - 0.5) * 2
    return np.clip((c - f) * pitch * K / 2 + 0.5, 0, 1) * smooth(.004, .03, c)


def even(c):
    return np.full((H, W), c, np.float32)


def layer(draw):
    """a white-on-black picture of the canvas's size, drawn by draw(ImageDraw): as 0…1"""
    m = Image.new("L", (W, H), 0)
    draw(ImageDraw.Draw(m))
    return np.asarray(m, np.float32) / 255


# ── the night: an S between the two moods, its lines swelling the further from it ─────────────
T = [0, .14, .30, .46, .60, .74, .88, 1]
XB = [.60, .55, .49, .45, .41, .39, .46, .56]
xb = np.interp(np.arange(H, dtype=np.float32) / H, T, XB) * PW
xb = ndi.gaussian_filter1d(xb, 90 * K, mode="nearest")[:, None] + WOB * 26
night = smooth(-150, 150, X - xb)

# the disc behind the demon: the seal's red, as one more thing cut in lines
DX, DY, DR = 1240.0, 640.0, 480.0
r = np.hypot(X - DX, Y - DY)
disc = np.clip((DR - r) * K / 1.5 + .5, 0, 1)
rim = np.exp(-(np.maximum(r - DR, 0) / 190.0) ** 2) * (1 - disc)
canvas = mix(mix(PAPER, EMBER, night), mix(RED, RED_LO, smooth(.55, 1.0, r / DR)), disc).astype(np.float32)
sky = np.maximum(.10 * smooth(.26 * PH, 0, Y) * (1 - night), night * (1.08 - .62 * rim))
sky = sky * (1 - disc) + (.14 + .34 * (r / DR) ** 4) * disc
sky *= 1 - .46 * np.exp(-((Y - 1830) / 230) ** 2) * night * (1 - disc)        # the ember low on the horizon, behind the spray

# ── the demon: M1, turned toward her, the head a little tilted ────────────────────────────────
M1 = np.asarray(Image.open(DEMON).convert("L").resize((2048, 2048), Image.LANCZOS), np.float32) / 255
ink_d = np.clip((.62 - M1) / .30, 0, 1)
U = 2.0                        # the outlines below are in M1's 1024 → its pixels at 2048


def outline_of(points):
    m = Image.new("L", (2048, 2048), 0)
    ImageDraw.Draw(m).polygon([(x * U, y * U) for x, y in points], fill=255)
    return np.asarray(m, np.float32) / 255


MASK = [(497, 256), (560, 262), (625, 288), (668, 322), (703, 365), (738, 440), (738, 520), (722, 590), (726, 640), (714, 690), (692, 760),
        (652, 826), (600, 872), (530, 895), (470, 893), (408, 868), (352, 822), (316, 752), (293, 692), (281, 640), (279, 600), (264, 520),
        (268, 440), (296, 380), (328, 334), (373, 293), (435, 264)]
HORN_L = [(40, 0), (112, 66), (195, 142), (262, 180), (290, 235), (352, 318), (332, 362), (300, 336), (255, 282), (195, 210), (125, 118)]
HORN_R = [(985, 0), (905, 80), (835, 145), (768, 185), (735, 245), (682, 325), (705, 366), (735, 335), (780, 280), (830, 215), (898, 122)]
ROBE = [(0, 1024), (135, 925), (345, 856), (470, 880), (560, 880), (660, 856), (880, 925), (1024, 1024)]   # (the mist hides where it ends)
shape = np.maximum.reduce([outline_of(p) for p in (MASK, HORN_L, HORN_R)]) > .5
# (the outlines are rough: what the paper outside reaches, through the gaps of his lines, is no part of it)
lab_d = ndi.label(~ndi.binary_closing(M1 < .55, iterations=2))[0]
halo = np.isin(lab_d, np.setdiff1d(np.unique(lab_d[~shape]), [0]))
matte_d = ndi.binary_opening(ndi.binary_fill_holes(shape & ~halo), iterations=3).astype(np.float32)
robe_d = outline_of(ROBE) * (1 - matte_d)
Cx, Cy, k, tilt, turn, R = 1378.0, 755.0, 1.10, math.radians(6), math.radians(-17), 640.0
FX = Cx - R * math.sin(-turn) * k                     # the face's middle, once turned


def demon_fields():
    dx, dy = (X - Cx) / k, (Y - Cy) / k
    ca, sa = math.cos(tilt), math.sin(tilt)
    ux, uy = ca * dx + sa * dy, -sa * dx + ca * dy        # undo the tilt
    us = R * np.sin(np.arcsin(np.clip(ux / R, -1, 1)) - turn)   # undo the turn: a head is round
    u, v, ok = (us + 505) * U, (uy + 590) * U, np.abs(ux) < R * .998
    return [ndi.map_coordinates(a, [v, u], order=1, mode="constant") * ok for a in (ink_d, matte_d, robe_d)]


ink_d, matte_d, robe_d = demon_fields()
hair = ink_d * (1 - matte_d) * (1 - robe_d)
hair *= 1 - (1 - np.clip((DR - r) * K / 1.5 + .5, 0, 1)) * smooth(870, 930, Y)   # (past the disc, low down: no loose ends over the mist)
hair_ink = mix(SUMI, LINE, (1 - disc) * smooth(.45, .75, night))     # black on the disc and her paper, the plate's own colour on the black
sky = sky * (1 - .92 * smooth(0, .6, ndi.gaussian_filter(hair, 2 * K)))  # the night's lines give way round the mane

# ── the angel: Schongauer's line, kept; his paper taken away ──────────────────────────────────
G = np.asarray(Image.open(SRC / "schongauer-gabriel.jpg").convert("L"), np.float32) / 255
flat = G / np.maximum(ndi.gaussian_filter(G, 120), .2)
ink_a = np.clip((.70 - flat) / .22, 0, 1)
A_POLY = [(85, 530), (78, 400), (95, 200), (118, 100), (165, 50), (238, 28), (252, 52), (355, 5), (432, 40), (395, 130), (420, 190), (405, 235),
          (470, 255), (505, 190), (525, 245), (530, 50), (558, 15), (640, 110), (665, 195), (640, 250), (615, 285), (632, 395), (668, 470),
          (640, 525), (560, 530), (520, 455), (495, 430), (470, 462), (525, 650), (525, 845), (478, 880), (380, 885), (272, 952), (150, 932),
          (70, 865), (100, 805), (155, 790), (165, 715), (198, 620), (170, 520), (198, 430), (150, 430), (135, 480)]
pm = Image.new("L", (G.shape[1], G.shape[0]), 0)
ImageDraw.Draw(pm).polygon([(x * 4, y * 4) for x, y in A_POLY], fill=255)
pm = np.asarray(pm) > 127
ink_a *= pm
# the silhouette: what the outside cannot reach through his closed outlines
half = (G.shape[1] // 2, G.shape[0] // 2)
closed = ndi.binary_closing(np.asarray(Image.fromarray((ink_a > .45).astype(np.uint8) * 255).resize(half, Image.BOX)) > 40, iterations=4)
lab_a = ndi.label(~closed)[0]
pm2 = np.asarray(Image.fromarray(pm.astype(np.uint8) * 255).resize(half, Image.NEAREST)) > 127
sil = ndi.binary_opening(ndi.binary_fill_holes(~np.isin(lab_a, np.unique(lab_a[~pm2])) & pm2), iterations=2)
sil = np.asarray(Image.fromarray(sil.astype(np.uint8) * 255).resize((G.shape[1], G.shape[0]), Image.BILINEAR), np.float32) / 255
AS, AX, AY = .335, -122.0, 46.0     # scale, the plate's corner on the page


def angel(a):
    ix, iy = np.clip((X - AX) / AS, 0, a.shape[1] - 1), np.clip((Y - AY) / AS, 0, a.shape[0] - 1)
    inside = (X >= AX) & (Y >= AY) & (X < AX + a.shape[1] * AS) & (Y < AY + a.shape[0] * AS)
    # (reduced with a small blur first: his fine lines stay lines, without crawling)
    return ndi.map_coordinates(ndi.gaussian_filter(a, .42 / (AS * K)), [iy, ix], order=1) * inside


ink_a, sil_a = np.clip(angel(ink_a) * 1.5, 0, 1), angel(sil)        # (his finest lines, reduced, kept black)
HX, HY = AX + 1363 * AS, AY + 500 * AS     # her head, on Schongauer's plate
sky *= 1 - smooth(0, .35, ndi.gaussian_filter(sil_a, 26 * K)) * (1 - night)    # around her the sky's lines thin out

# the sky is cut: indigo-grey by day, sumi by night
over(mix(AI2 * .85, SUMI, smooth(.02, .35, night)), hatch(sky))


# ── clouds: the long mists of the old scrolls, one over the other, each its outline and lines at its foot ──
def lay_clouds(pills):
    fill, line, foot = [Image.new("L", (W, H), 0) for _ in range(3)]
    df, dl, dfo = [ImageDraw.Draw(i) for i in (fill, line, foot)]
    for x0_, x1_, y_, h_ in pills:
        box, rad = [x0_ * K, y_ * K, x1_ * K, (y_ + h_) * K], h_ / 2 * K
        df.rounded_rectangle(box, rad, fill=255)
        dl.rounded_rectangle(box, rad, fill=0, outline=255, width=max(1, round(2.0 * K)))
        dfo.rounded_rectangle(box, rad, fill=255)
        dfo.rounded_rectangle([box[0], box[1], box[2], box[3] - h_ * .44 * K], rad, fill=0)
    fill, line, foot = [np.asarray(i, np.float32) / 255 for i in (fill, line, foot)]
    over(PAPER, fill)
    over(CLOUD_N, fill * hatch(night * 1.1, pitch=5.0))    # dark by lines too
    over(mix(AI2, SHADE_N, night), foot * hatch(even(.5), pitch=5.0))
    over(mix(SUMI, LINE, smooth(.25, .6, night)), line)


lay_clouds([(1240, 1720, 28, 34), (1120, 1560, 58, 40), (1330, 1720, 94, 32),       # the night's, top right
            (600, 900, 930, 36), (620, 980, 962, 42), (590, 860, 1000, 34)])         # between them, behind her robe

# her ring of light
HR = 194.0
ring = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(ring)
for rr, wd in ((HR, 6.4), (HR + 11, 2.0)):
    d.ellipse([(HX - rr) * K, (HY - rr) * K, (HX + rr) * K, (HY + rr) * K], outline=255, width=max(1, round(wd * K)))
for j in range(72):
    a_ = j / 72 * 2 * math.pi
    r0, r1 = HR + 11, HR + (37 if j % 2 else 58)
    d.line([(HX + r0 * math.cos(a_)) * K, (HY + r0 * math.sin(a_)) * K, (HX + r1 * math.cos(a_)) * K, (HY + r1 * math.sin(a_)) * K],
           fill=255, width=max(1, round(2.4 * K)))
over(GOLD, np.asarray(ring, np.float32) / 255)

# the mane behind her scroll; she, a wash in her shadows; the mask and horns over all, lit, the plate's ink on them
over(hair_ink, hair)
over(mix(PAPER, AI2, .62 * np.clip(ndi.gaussian_filter(ink_a, 9 * K) * 1.9, 0, 1)), sil_a)
over(SUMI, ink_a)
over(mix(mix(LIT, rgb("c7a678"), smooth(0, 1, np.hypot(X - (FX - 90), Y - (Cy - 90)) / 560)), SUMI, ink_d), matte_d)

# the mist under the demon: his neck ends in it; the bank she stands on, her feet in it
lay_clouds([(1040, 1440, 1072, 38), (1320, 1720, 1082, 40), (650, 1050, 1090, 38), (910, 1450, 1104, 44), (730, 1170, 1142, 40),
            (1130, 1720, 1132, 46), (990, 1510, 1174, 42), (650, 1090, 1182, 44), (1210, 1720, 1210, 42), (890, 1370, 1228, 40),
            (-60, 300, 1210, 38), (120, 560, 1238, 42), (-60, 420, 1272, 44), (170, 640, 1308, 36)])

# ── the sea: the whole print, its paper white made ours; by night a dark lit from above ───────
P = np.asarray(Image.open(SRC / "hokusai-wave.jpg").convert("RGB"), np.float32) / 255
ph, pw = P.shape[:2]
vk = pw / 960                  # the keys below are in a 960-wide view of the print
tan = (P[..., 0] - P[..., 2]) > .085
lab_t = ndi.label(tan)[0]
sky_tan = np.isin(lab_t, np.setdiff1d(np.unique(lab_t[:8, :]), [0]))
foam = ndi.binary_opening(P.min(2) > .74, iterations=2)
keep = Image.new("L", (pw, ph), 255)
dk = ImageDraw.Draw(keep)
# (his title, his signature, and the white clouds behind the crest: no part of the sea)
dk.polygon([(x * vk, y * vk) for x, y in [(0, 0), (118, 0), (122, 150), (96, 196), (62, 222), (0, 238)]], fill=0)
dk.polygon([(x * vk, y * vk) for x, y in [(90, 96), (232, 96), (216, 118), (150, 158), (92, 168)]], fill=0)
dk.polygon([(x * vk, y * vk) for x, y in [(520, 60), (960, 0), (960, 262), (760, 232), (640, 212), (574, 214)]], fill=0)
keep = np.asarray(keep, np.float32) / 255
alpha = np.where(sky_tan, 0.0, 1.0).astype(np.float32) * keep
# the dark sky behind the curl is the page's own night, down to the horizon; the spray stays
vy = (np.arange(ph, dtype=np.float32) / vk)[:, None]
vx = (np.arange(pw, dtype=np.float32) / vk)[None, :]
blueness = ndi.gaussian_filter(P[..., 2] - P[..., 0], 5)
lum = P @ np.array([.3, .59, .11], np.float32)
spray = foam & ((vx < 565) | (lum - ndi.gaussian_filter(lum, 30) > .05))   # (a drop is lighter than the sky round it)
open_sky = (vx > 380) & (vy < 478) & (blueness < .045) & ~spray
alpha = np.where(open_sky, alpha * smooth(420, 478, vy), alpha)
alpha = np.where(spray & (vx > 370) & (vy > 215) & (vy < 478), np.maximum(alpha, keep), alpha)
alpha = ndi.gaussian_filter(alpha, .8)
tone = np.clip(P / np.maximum(np.percentile(P[1500:2400, 200:1200], 99, axis=(0, 1)), .5), 0, 1) * PAPER
SK = PW / pw * 1.15            # the print a little larger than the page: its left, the great wave, is what counts
BOTTOM = PH + 50               # its foot: under the page, so that Fuji clears the title


def sea(a):
    ix, iy = np.clip(X / SK, 0, pw - 1), np.clip((Y - (BOTTOM - ph * SK)) / SK, 0, ph - 1)
    inside = Y >= BOTTOM - ph * SK
    if a.ndim == 3:
        return np.stack([ndi.map_coordinates(a[..., i], [iy, ix], order=1) for i in range(3)], 2) * inside[..., None]
    return ndi.map_coordinates(a, [iy, ix], order=1) * inside


alpha_s, tone_s = sea(alpha), sea(tone)
over(np.clip(tone_s * mix(np.ones(3, np.float32), rgb("c49a78") * .84, smooth(.1, .9, night)), 0, 1).astype(np.float32), alpha_s)

# ── sakura between them, falling along the S ──────────────────────────────────────────────────
pa, li, he = [Image.new("L", (W, H), 0) for _ in range(3)]
dp, dl_, dh = [ImageDraw.Draw(i) for i in (pa, li, he)]


def petal(cx, cy, rad, rot, notch=.86, wide=.52):
    pts = [(t * rad, math.sin(t * math.pi) ** .8 * wide * rad) for t in np.linspace(0, 1, 14)]
    pts.append((rad * notch, 0))
    pts += [(t * rad, -math.sin(t * math.pi) ** .8 * wide * rad) for t in np.linspace(1, 0, 14)]
    return [((cx + x * math.cos(rot) - y * math.sin(rot)) * K, (cy + x * math.sin(rot) + y * math.cos(rot)) * K) for x, y in pts]


def blossom(cx, cy, rad, rot):
    for j in range(5):
        q = petal(cx, cy, rad, rot + j / 5 * 2 * math.pi)
        dp.polygon(q, fill=255)
        dl_.line(q + [q[0]], fill=255, width=max(1, round(1.8 * K)))
    for j in range(5):
        a_ = rot + (j + .5) / 5 * 2 * math.pi
        dl_.line([(cx + rad * .16 * math.cos(a_)) * K, (cy + rad * .16 * math.sin(a_)) * K, (cx + rad * .42 * math.cos(a_)) * K, (cy + rad * .42 * math.sin(a_)) * K],
                 fill=255, width=max(1, round(1.1 * K)))
    dh.ellipse([(cx - rad * .13) * K, (cy - rad * .13) * K, (cx + rad * .13) * K, (cy + rad * .13) * K], fill=255)


def clear(x, y):
    """never on a face, the mask, her hands or the title"""
    return not (np.hypot(x - HX, y - HY) < 150 or np.hypot(x - FX, y - Cy) < 350 or (400 < x < 700 and 300 < y < 620) or (180 < x < 1474 and 1990 < y < 2300))


def along_s(y_, spread):
    return float(np.interp(y_ * K, np.arange(H), xb[:, W // 2])) + rng.normal(0, spread)


placed = 0
while placed < 30:
    y_ = float(rng.uniform(30, 1780))
    x_ = along_s(y_, 190)
    if 12 < x_ < PW - 12 and clear(x_, y_):
        blossom(x_, y_, float(rng.uniform(13, 27)), float(rng.uniform(0, 6.28)))
        placed += 1
for _ in range(40):
    y_ = float(rng.uniform(30, 1900))
    x_ = along_s(y_, 290)
    if 12 < x_ < PW - 12 and clear(x_, y_):
        q = petal(x_, y_, float(rng.uniform(10, 17)), float(rng.uniform(0, 6.28)), .9, .36)
        dp.polygon(q, fill=255)
        dl_.line(q + [q[0]], fill=255, width=max(1, round(1.4 * K)))
over(mix(PAPER, rgb("ead9bd"), night), np.asarray(pa, np.float32) / 255)
over(mix(SUMI, rgb("3a1a12"), night), np.asarray(li, np.float32) / 255)
over(GOLD, np.asarray(he, np.float32) / 255)


# ── the cartouche: real type on its plate, the hanko at its end ───────────────────────────────
def font(name, size, wght=None):
    f = ImageFont.truetype(str(FONTS / name), round(size * K), layout_engine=ImageFont.Layout.RAQM)
    if wght:
        f.set_variation_by_axes([wght])
    return f


CW, CH = 1224.0, 232.0
CX, CY = PW / 2, 2160.0        # its centre: the page's axis
x0, y0, x1, y1 = CX - CW / 2, CY - CH / 2, CX + CW / 2, CY + CH / 2
N = 16.0                       # the corners' notch


def notched(a, b, c, e, n):
    return [(a + n, b), (c - n, b), (c - n, b + n), (c, b + n), (c, e - n), (c - n, e - n), (c - n, e), (a + n, e), (a + n, e - n), (a, e - n), (a, b + n), (a + n, b + n)]


outer, inner = notched(x0, y0, x1, y1, N), notched(x0 + 14, y0 + 14, x1 - 14, y1 - 14, N)
over(SUMI, layer(lambda d_: d_.polygon([((x + 10) * K, (y + 12) * K) for x, y in outer], fill=255)) * hatch(even(.62), pitch=4.0))
over(rgb("f7f0dc"), layer(lambda d_: d_.polygon([(x * K, y * K) for x, y in outer], fill=255)))


def frame(d_):
    for pts, wd in ((outer, 5.5), (inner, 1.8)):
        q = [(x * K, y * K) for x, y in pts]
        d_.line(q + [q[0], q[1]], fill=255, width=max(1, round(wd * K)))


over(SUMI, layer(frame))
TITLE, SUB = "fedokawaii — learn", "from your first command to a small language model of your own"
FEAT = ["kern", "liga", "onum"]
ft, fs = font("EBGaramond[wght].ttf", 124, 500), font("EBGaramond-Italic[wght].ttf", 37.5, 400)
HW, GAP, LEAD = 138.0, 38.0, 60.0   # the hanko's side, its gap from the words, baseline to baseline
tb, sb = ft.getbbox(TITLE, anchor="ls", features=FEAT), fs.getbbox(SUB, anchor="ls", features=FEAT)
tw, sw = (tb[2] - tb[0]) / K, (sb[2] - sb[0]) / K
LEFT = x0 + (CW - HW - GAP - max(tw, sw)) / 2
# the two lines' ink, from the title's tallest letter to the subtitle's deepest, in the plate's middle
base = CY - (tb[1] / K + LEAD + sb[3] / K) / 2


def words(d_):
    d_.text((LEFT * K - tb[0], base * K), TITLE, font=ft, fill=255, anchor="ls", features=FEAT)
    d_.text((LEFT * K - sb[0], (base + LEAD) * K), SUB, font=fs, fill=255, anchor="ls", features=FEAT)


over(SUMI, layer(words))
# the hanko: the seal's red, 学 cut out of it, its edge worn as a stone's is
hx0, hy0 = LEFT + max(tw, sw) + GAP, CY - HW / 2
hs = round(HW * K)
seal = Image.new("L", (hs, hs), 0)
ImageDraw.Draw(seal).rounded_rectangle([0, 0, hs - 1, hs - 1], radius=round(9 * K), fill=255)
cut = Image.new("L", (hs, hs), 0)
dc = ImageDraw.Draw(cut)
dc.rounded_rectangle([round(6 * K), round(6 * K), hs - 1 - round(6 * K), hs - 1 - round(6 * K)], radius=round(5 * K), outline=255, width=max(1, round(2.6 * K)))
dc.text((hs / 2, hs / 2), "学", font=ImageFont.truetype(str(FONTS / "ShipporiMincho-Bold.ttf"), round(HW * .74 * K)), fill=255, anchor="mm")
sa = np.asarray(seal, np.float32) / 255 * (1 - np.asarray(cut, np.float32) / 255)
wear = ndi.gaussian_filter(np.random.default_rng(7).standard_normal((hs, hs)).astype(np.float32), 1.1 * K)
wear /= wear.std()
sa = np.clip((ndi.gaussian_filter(sa, .45 * K) + wear * .13 - .46) * 7, 0, 1)
sa = ndi.gaussian_filter(np.where(np.random.default_rng(8).random((hs, hs)) < .004, 0, sa).astype(np.float32), .3 * K)
full = np.zeros((H, W), np.float32)
ox, oy = round(hx0 * K), round(hy0 * K)
full[oy:oy + hs, ox:ox + hs] = sa
over(SEAL, full)

# ── the page: reduced, a little of the paper's grain ──────────────────────────────────────────
out = canvas.reshape(H // SS, SS, W // SS, SS, 3).mean((1, 3))
grain = ndi.gaussian_filter(np.random.default_rng(9).standard_normal(out.shape[:2]).astype(np.float32), .7) * .010
page = Image.fromarray((np.clip(out + grain[..., None], 0, 1) * 255 + .5).astype(np.uint8))
dest = pathlib.Path(args.out) if args.out else ROOT / "docs/learn"
dest.mkdir(parents=True, exist_ok=True)
page.save(dest / "cover.jpg", quality=88, optimize=True, progressive=True, subsampling=0, dpi=(200, 200))
if args.out:
    page.save(dest / "cover.png")
else:
    # Super+U's pane: a small picture, drawn once (bin/kawa-learn-cover)
    page.resize((336, 475), Image.LANCZOS).save(dest / "cover-thumb.png", optimize=True)
if args.pdf:
    # the cover alone as a PDF: the JPEG as it is, on the book's page
    jpg = (dest / "cover.jpg").read_bytes()
    w_pt, h_pt = 595.92, 842.88
    c = f"q {w_pt} 0 0 {h_pt} 0 0 cm /I Do Q".encode()
    objs = [b"<< /Type /Catalog /Pages 2 0 R >>", b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {w_pt} {h_pt}] /Contents 4 0 R /Resources << /XObject << /I 5 0 R >> >> >>".encode(),
            b"<< /Length %d >>\nstream\n%s\nendstream" % (len(c), c),
            b"<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n%s\nendstream"
            % (page.width, page.height, len(jpg), jpg)]
    pdf, offs = b"%PDF-1.5\n", []
    for i, o in enumerate(objs, 1):
        offs.append(len(pdf))
        pdf += b"%d 0 obj\n%s\nendobj\n" % (i, o)
    xref = len(pdf)
    pdf += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1) + b"".join(b"%010d 00000 n \n" % o for o in offs)
    pdf += b"trailer << /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
    tmp = dest / "cover.tmp.pdf"
    tmp.write_bytes(pdf)
    book = ROOT / "docs/Fedokawaii-Learn.pdf"
    new = book.with_suffix(".new.pdf")
    subprocess.run(["qpdf", str(book), "--pages", str(tmp), "1", str(book), "2-z", "--", str(new)], check=True)
    new.replace(book)
    tmp.unlink()
print("cover:", dest / "cover.jpg", page.size, (dest / "cover.jpg").stat().st_size // 1024, "KB")
