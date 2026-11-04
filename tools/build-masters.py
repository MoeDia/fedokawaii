#!/usr/bin/env python3
"""tools/build-masters.py — the old masters' pictures as the desktop's own pixel art (T18):
demons for the dark mood, angels for the light, after public-domain prints and paintings
(art/masters/SOURCES.md says where each comes from and under which licence).

    python3 tools/build-masters.py [NAME…] [--sheet FILE]

Reads art/masters/masters.toml — one table a picture:
    [NAME]                       the picture's name (the wallpaper's)
    theme   = "dark" | "light"
    source  = "FILE"             in ~/.cache/r27-art (fetched by the source hunt; never in the repo)
    sha256  = "…"                the file as fetched: anything else is refused
    crop    = [x, y, w, h]       in the source's pixels, 16:9 (the part that becomes the screen);
                                 past the source's edge its ground is carried on
    tone    = "keep" | "lacquer" the dark mood's two ways with a print on light paper: kept (a
                                 night print already dark) or as maki-e — the paper black
                                 lacquer, the lines and colours light, as gold on lacquer
    lift    = 0.0                lightness added before the palette (−0.2 … 0.2)
    gain    = 1.0                contrast around the middle before the palette
    joins   = [[x0, x1], …]      the source's columns where two sheets of a print meet (a pale
                                 seam down the picture): filled across from either side
    clean   = [[x0, y0, x1, y1], …]  in the picture's pixels: what is not the picture (a cartouche,
                                 a seal, a poem card) made ground, filled in from all round it
    marks   = [[x0, y0, x1, y1], …]  in the picture's pixels: a print's writing on a ground that must
                                 stay (its clouds, their contour): only the ink in the box filled in,
                                 no patch left to see; a fifth number, how far below the ground ink
                                 starts (where the writing crosses a line paler than itself)
    fields  = [[[ax, ay], [x, y], …], …]  a large thing to take out, its outline in the picture's
                                 pixels: one colour, the print's own at ax, ay (or a line carried
                                 on across what was taken out)
    even    = [[x, reach], …]    two sheets of a print inked apart: the step in lightness across the
                                 picture's column x shared out between them, row by row, less and
                                 less over REACH columns each way
    dodge   = [[x0, y0, x1, y1, lift, gain], …]  a dark face lost in its ground: inside the box's
                                 ellipse its lightness raised by LIFT, its lines × GAIN
    fade    = [[x0, x1], …]      in the picture's columns: into the top's ink, the picture whole at
                                 x0 and gone at x1, an uneven edge as a wash has (a painting's own
                                 edge, carried on)
    paper   = 0.9                lightness (0 … 1 of the picture's) from which it is the bare paper:
                                 a stain or a ghost of old print goes, a light print's ground lies flat
    speck   = 4                  an accent in a group of fewer pixels than this is the ramp's: a faded
                                 print's flecks go, its one strong red stays
    smooth  = 2                  passes of the smoothing
writes art/masters/out/NAME.png: 640 × 360 pixels, every one a colour of its mood's palette
(an indexed PNG: a few dozen kilobytes) — the screen shows each as 3 × 3 (1920 × 1080; 2 × 2 on
1280 × 720, 4 × 4 on 2560 × 1440, 6 × 6 on 4K: always whole pixels, never smoothed).
--sheet FILE: every picture written, side by side at 1:1 and halved, for the grill.
--check FILE…: the edge check (below) on pictures already made — tests/static/test_masters.sh.

No paper at the edges: a picture whose side still holds the print's margin, its frame line or
a mount is refused (edges(): the outer 1–4 rows or columns against the 20 inside them, by
lightness) — the crop comes in until none is left.

How: the crop reduced to 640 × 360 in linear light (Lanczos: each pixel the mean of what it
covers, no darkening at edges), its tones set as the table asks, then each pixel given the
nearest colour of the palette in OKLab (lightness counted twice: shapes read by their
values), an ordered dither (Bayer 4 × 4) choosing between the two nearest where a colour falls
between them — the texture of old pixel art, stable from frame to frame, never noise.

Three inks, as a print has (art direction §4): a ramp of the mood's ink to its paper, the seal's
red, and in the light mood gold. And a calm top: its first TOP_FLAT rows (the 40 px under the bar)
a single ink, fading into the picture over the next TOP_FADE — ichimonji-bokashi, the band a
printer wiped across the top of the block. --check holds both.
Needs Pillow and numpy.
"""
import argparse
import hashlib
import importlib.util
import pathlib
import sys
import tomllib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "art/masters/masters.toml"
OUT = ROOT / "art/masters/out"
CACHE = pathlib.Path.home() / ".cache/r27-art"
W, H = 640, 360

# each mood's inks, by name from the Wada palette (tools/wada-palette.py): a ramp of neutrals,
# darkest first — the dark mood's sumi and lacquer browns up to ivory (with the three art tones
# between the stone and the cream), the light mood's ink up to kinari paper — and a few accents a
# strongly coloured part may take, by its hue: vermilion above all. Fewer colours than a print
# has: what pixel art gives up, on purpose
_spec = importlib.util.spec_from_file_location("wada_palette", ROOT / "tools/wada-palette.py")
_wada = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_wada)
_P = _wada.palette()[0]
RAMP = {
    "dark": [_P["dark"][k] for k in ("lo", "ground", "edge", "edge2", "hi", "art_umber", "art_olive", "gold", "art_kinari", "strong")],
    "light": [_P["light"][k] for k in ("strong", "art_ink", "art_umber", "lo", "art_olive", "edge2", "edge", "ground", "key")],
}
ACCENT = {
    "dark": [_P["dark"][k] for k in ("accent_lo", "accent", "flame")],
    "light": [_P["light"][k] for k in ("accent_lo", "accent", "gold")],
}
TOP_INK = {"dark": 1, "light": -1}       # the calm top's step of the ramp: the ground, the paper
TOP_FLAT, TOP_FADE = 14, 24              # its rows (at ×3 on 1080p: 42, the bar's 27 and its air)
PALETTE = {m: RAMP[m] + ACCENT[m] for m in RAMP}
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16 - 0.5


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def oklab(rgb):
    """linear sRGB (…, 3) → OKLab (…, 3) — Björn Ottosson's matrices."""
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                   [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                   [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    lms = np.cbrt(np.maximum(rgb @ m1.T, 0))
    return lms @ m2.T


def hexes(h):
    return np.array([[int(x[i:i + 2], 16) for i in (0, 2, 4)] for x in h]) / 255


def half(a):
    """a plane at half its size, each new pixel the mean of the four under it (an odd last row or column left out)"""
    hh, ww = a.shape[0] // 2 * 2, a.shape[1] // 2 * 2
    return (a[:hh:2, :ww:2] + a[1:hh:2, :ww:2] + a[:hh:2, 1:ww:2] + a[1:hh:2, 1:ww:2]) / 4


def heal(lab, hole):
    """HOLE (… × a mask) filled in from all round it, smoothly: push-pull, each scale filling what
    the finer one could not — a flat ground stays flat, a gradient goes on."""
    if not hole.any():
        return lab
    weight = (~hole).astype(np.float64)
    levels = [(lab * weight[..., None], weight)]
    while levels[-1][1].shape[0] > 2 and levels[-1][1].shape[1] > 2 and (levels[-1][1] == 0).any():
        val, wt = levels[-1]
        levels.append((half(val), half(wt)))
    val, wt = levels[-1]
    cur = val / np.maximum(wt, 1e-9)[..., None]
    if (wt == 0).any():                # (the rows ran out first: what is left, the mean of the rest)
        cur[wt == 0] = val.sum((0, 1)) / wt.sum()
    for val, wt in reversed(levels[:-1]):
        up = np.repeat(np.repeat(cur, 2, 0), 2, 1)
        up = np.pad(up, ((0, wt.shape[0] - up.shape[0]), (0, wt.shape[1] - up.shape[1]), (0, 0)), mode="edge")
        # (a soft step, so the coarse scale's blocks do not show; at the picture's edge it stops:
        # wrapped round, a hole at the left took a tone from the far right)
        up = np.pad(up, ((1, 1), (1, 1), (0, 0)), mode="edge")
        up = (up[:-2] + 2 * up[1:-1] + up[2:]) / 4
        up = (up[:, :-2] + 2 * up[:, 1:-1] + up[:, 2:]) / 4
        k = np.clip(wt, 0, 1)[..., None]
        cur = val + (1 - k) * up
    return np.where(hole[..., None], cur, lab)


def reduce(img, crop, joins=()):
    """→ the crop at 640 × 360 in linear light, and the mask of what lies past the source's edge"""
    x, y, w, h = crop
    src = img.convert("RGB")
    a = np.asarray(src.crop((x, y, x + w, y + h)), dtype=np.float64) / 255
    outside = np.ones((h, w), bool)
    outside[max(-y, 0):max(src.height - y, 0), max(-x, 0):max(src.width - x, 0)] = False
    for x0, x1 in joins:              # (each seam filled across, column by column, from its sides)
        lo, hi = x0 - x - 1, x1 - x + 1   # (the last column before it, the first after)
        if 0 <= lo and hi < w:
            t = (np.arange(lo + 1, hi) - lo)[None, :, None] / (hi - lo)
            a[:, lo + 1:hi] = a[:, lo:lo + 1] * (1 - t) + a[:, hi:hi + 1] * t
    lin = srgb_to_linear(a)
    # (Pillow resizes 8-bit or float images: each channel as a float plane, in linear light)
    planes = [Image.fromarray(lin[..., i].astype(np.float32), "F").resize((W, H), Image.LANCZOS)
              for i in range(3)]
    past = np.asarray(Image.fromarray((outside * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)) > 0
    return np.clip(np.stack([np.asarray(p, dtype=np.float64) for p in planes], -1), 0, 1), past


def smooth(lab, passes=2, sigma_l=0.06):
    """Edge-preserving smoothing (a 5 × 5 bilateral in OKLab, twice): the paper's grain and a
    print's mottled colour become the flat areas a woodblock has, its lines kept sharp."""
    for _ in range(passes):
        acc = np.zeros_like(lab)
        wsum = np.zeros(lab.shape[:2])
        pad = np.pad(lab, ((2, 2), (2, 2), (0, 0)), mode="edge")
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                nb = pad[2 + dy:2 + dy + lab.shape[0], 2 + dx:2 + dx + lab.shape[1]]
                w = np.exp(-(((nb - lab) ** 2).sum(-1)) / (2 * sigma_l ** 2) - (dx * dx + dy * dy) / 8)
                acc += nb * w[..., None]
                wsum += w
        lab = acc / wsum[..., None]
    return lab


def dark_marks(L, below=0.035):
    """L: a box of the picture's lightness. Its writing: what lies darker than the ground round it
    (a 15 × 15 median), and two pixels all round that (the ink's soft edge, else a pale ghost of it)."""
    im = Image.fromarray((np.clip(L, 0, 1) * 255).astype(np.uint8))
    ground = np.asarray(im.filter(ImageFilter.MedianFilter(15)), dtype=np.float64) / 255
    ink = Image.fromarray(((L < ground - below) * 255).astype(np.uint8))
    return np.asarray(ink.filter(ImageFilter.MaxFilter(5))) > 0


def even(lab, x, reach, wide=6, sigma=12, most=0.1):
    """The step in lightness across column X (WIDE columns each side, row by row, softened down the
    column so a figure crossing it sets nothing, and at most MOST) shared out: half off the lighter
    side, half onto the darker, less and less over REACH columns each way (taken from one side
    alone it leaves a dark line down the seam)."""
    L = lab[..., 0]
    step = L[:, x + 1:x + 1 + wide].mean(1) - L[:, x - wide:x].mean(1)
    k = np.exp(-(np.arange(-3 * sigma, 3 * sigma + 1) ** 2) / (2 * sigma ** 2))
    step = np.convolve(np.pad(step, 3 * sigma, mode="edge"), k / k.sum(), mode="valid")
    cols = np.arange(W)
    t = np.clip(1 - np.abs(cols - x) / reach, 0, 1) * np.where(cols > x, -0.5, 0.5)
    out = lab.copy()
    out[..., 0] = L + np.clip(step, -most, most)[:, None] * t[None, :]
    return out


def soft(L, passes=3):
    """L softened (1 2 1 along each axis, PASSES times)"""
    for _ in range(passes):
        for axis in (0, 1):
            L = (np.roll(L, 1, axis) + 2 * L + np.roll(L, -1, axis)) / 4
    return L


def dodge(lab, x0, y0, x1, y1, lift, gain):
    """Inside the box's ellipse (fading over its outer quarter) the lightness raised by LIFT and
    what stands out from its surroundings × GAIN: a dark face's lines come back."""
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.hypot((xx - (x0 + x1) / 2) / ((x1 - x0) / 2), (yy - (y0 + y1) / 2) / ((y1 - y0) / 2))
    m = np.clip((1 - r) / 0.25, 0, 1)
    m = m * m * (3 - 2 * m)
    L = lab[..., 0]
    out = lab.copy()
    out[..., 0] = L + m * (lift + (gain - 1) * (L - soft(L)))
    return out


def tones(lab, spec, mood, known):
    """The picture's lightness stretched over its mood's ramp (1st to 99th percentile of what is
    the print's own, KNOWN: a stray speck neither black nor white sets nothing, nor does a filled
    hole), lacquered (inverted) where the table says, its contrast and lift as given; colour kept
    as it was (the accents read it)."""
    L = lab[..., 0]
    lo, hi = np.percentile(L[known], 1), np.percentile(L[known], 99)
    n = np.clip((L - lo) / max(hi - lo, 1e-6), 0, 1)
    if spec.get("tone", "keep") == "lacquer":
        n = 1 - n                                                         # the paper black lacquer
    n = np.clip((n - 0.5) * spec.get("gain", 1.0) + 0.5 + spec.get("lift", 0.0), 0, 1)
    if "paper" in spec:
        n = np.where(n >= spec["paper"], 1.0, n)
    ramp = oklab(srgb_to_linear(hexes(RAMP[mood])))
    out = lab.copy()
    out[..., 0] = ramp[0, 0] + n * (ramp[-1, 0] - ramp[0, 0])
    return out


def wander(seed, reach):
    """A slow unevenness over the picture, H × W, within ± REACH: never a straight edge. The same
    every build."""
    rng = np.random.default_rng(seed)
    out = np.zeros((H, W))
    for rows, part in ((6, 0.65), (14, 0.25), (34, 0.1)):
        grid = rng.uniform(-1, 1, (rows, rows * 2)).astype(np.float32)
        out += part * np.asarray(Image.fromarray(grid, "F").resize((W, H), Image.BICUBIC), dtype=np.float64)
    return out * reach


def calm_top(lab, mood, fades=()):
    """ichimonji-bokashi: the first rows one ink, fading into the picture; the same ink over FADES
    (x0 x1: the picture whole at x0, gone at x1), where a painting's own edge would show."""
    ink = oklab(srgb_to_linear(hexes([RAMP[mood][TOP_INK[mood]]])))[0]
    t = np.clip((np.arange(H) - TOP_FLAT) / TOP_FADE, 0, 1)
    t = (t * t * (3 - 2 * t))[:, None, None]
    keep = np.tile(t, (1, W, 1))
    for x0, x1 in fades:
        f = np.clip((np.arange(W) + wander(x0, abs(x1 - x0) * 0.6) - x0) / (x1 - x0), 0, 1)
        keep = keep * (1 - f * f * (3 - 2 * f))[..., None]
    return lab * keep + ink * (1 - keep)


def quantise(lab, mood, chroma=0.07, hue_deg=40, least=None, margin=0.1):
    """Each pixel: an accent where it is strongly coloured (chroma over CHROMA) and an accent's
    hue is within HUE_DEG of its own — the nearest such by OKLab —, else a step of the ramp by
    its lightness alone, two neighbouring steps mixed by a 4 × 4 Bayer threshold where it falls
    between them (the old ordered dither: stable, a texture, never noise)."""
    ramp = oklab(srgb_to_linear(hexes(RAMP[mood])))
    acc = oklab(srgb_to_linear(hexes(ACCENT[mood])))
    L = lab[..., 0]
    # the ramp: the step below and the step above, and how far between
    rl = ramp[:, 0]
    if np.any(np.diff(rl) <= 0):     # (searchsorted needs a climbing ramp: one out of order inverts midtones)
        sys.exit(f"build-masters: the {mood} ramp is not in OKLab lightness order: {np.round(rl, 3).tolist()}")
    k = np.clip(np.searchsorted(rl, L) - 1, 0, len(rl) - 2)
    f = np.clip((L - rl[k]) / np.maximum(rl[k + 1] - rl[k], 1e-9), 0, 1)
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W] + 0.5
    ramp_idx = np.where(f > np.clip(thr, margin, 1 - margin), k + 1, k)
    # the accents
    c = np.hypot(lab[..., 1], lab[..., 2])
    h = np.arctan2(lab[..., 2], lab[..., 1])
    ah = np.arctan2(acc[:, 2], acc[:, 1])
    dh = np.abs(np.angle(np.exp(1j * (h[..., None] - ah[None, None, :])))) * 180 / np.pi
    d = (((lab[:, :, None, :] - acc[None, None, :, :]) * np.array([2.0, 1.0, 1.0])) ** 2).sum(-1)
    d = np.where(dh < hue_deg, d, np.inf)
    best = d.argmin(-1)
    use = (c > chroma) & np.isfinite(d.min(-1))
    use &= ~specks(use, least or ACCENT_MIN)
    return np.where(use, len(rl) + best, ramp_idx)


# an accent of fewer pixels than this, touching no other (8 ways round): a speck — at 3 × a stray
# vermilion dot in a brown field (the master's T18 review: up to 22 in a picture) — the ramp's
ACCENT_MIN = 4


def specks(mask, least=ACCENT_MIN):
    """The pixels of MASK in a group of fewer than LEAST (each group walked only that far)."""
    hh, ww = mask.shape
    small = np.zeros_like(mask)
    for y, x in zip(*np.nonzero(mask), strict=True):
        if small[y, x]:
            continue
        group, todo = {(y, x)}, [(y, x)]
        while todo and len(group) < least:
            cy, cx = todo.pop()
            for ny in range(max(cy - 1, 0), min(cy + 2, hh)):
                for nx in range(max(cx - 1, 0), min(cx + 2, ww)):
                    if mask[ny, nx] and (ny, nx) not in group:
                        group.add((ny, nx))
                        todo.append((ny, nx))
        if len(group) < least:           # (all of it seen, and small)
            for q in group:
                small[q] = True
    return small


# the edges a picture must not have (the master's T18 review: six had a print's paper margin,
# its frame line or a mount at the screen's edge), by lightness, side by side: flat lines at the
# edge (one ink across: paper, a mount) unlike the EDGE_IN after them (their median: a print's
# plain ground going on inside is its own, whatever lies on it); or the outer 1–EDGE_BAND lines stepping by more than EDGE_STEP
# from the EDGE_BAND just inside them (a frame line) — a painting's own gradient ramps, it does
# not step. (A margin of dithered paper wider than that is seen only by eye: lotus-sutra-gateway's)
EDGE_BAND, EDGE_IN, EDGE_STEP, EDGE_FLAT, EDGE_LINE = 4, 20, 0.08, 0.03, 0.05


def edges(L):
    """L: the picture's lightness (OKLab), H × W. What is wrong at its edges, a phrase each. Its top
    is the calm band's: one ink."""
    found = []
    if L[:TOP_FLAT].std() > 1e-6:
        found.append(f"top: its {TOP_FLAT} rows are not one ink (lightness spread {L[:TOP_FLAT].std():.3f})")
    for side, a in (("bottom", L[::-1]), ("left", L.T), ("right", L.T[::-1])):
        what = "row" if side in ("top", "bottom") else "column"
        k = 0
        while k < 40 and a[k].std() < EDGE_FLAT:
            k += 1
        if k:
            inner = np.median(a[k:k + EDGE_IN])
            if abs(a[:k].mean() - inner) > EDGE_LINE:
                found.append(f"{side}: {k} flat {what}{'s' * (k > 1)} at L {a[:k].mean():.2f}, inside {inner:.2f}")
                continue
        for n in range(1, EDGE_BAND + 1):
            band, nxt = a[:n].mean(), a[n:n + EDGE_BAND].mean()
            if abs(band - nxt) > EDGE_STEP:
                found.append(f"{side}: its outer {n} {what}{'s' * (n > 1)} at L {band:.2f}, the next {EDGE_BAND} {nxt:.2f}")
                break
    return found


def lightness(img):
    return oklab(srgb_to_linear(np.asarray(img.convert("RGB"), dtype=np.float64) / 255))[..., 0]


def build(name, spec):
    src = CACHE / spec["source"]
    data = src.read_bytes()
    if hashlib.sha256(data).hexdigest() != spec["sha256"]:
        sys.exit(f"build-masters: {name}: {src} is not the file SOURCES.md names (sha256)")
    img = Image.open(src)
    lin, past = reduce(img, spec["crop"], spec.get("joins", ()))
    lab = oklab(lin)
    for x0, y0, x1, y1 in spec.get("clean", ()):
        past[y0:y1, x0:x1] = True
    for x0, y0, x1, y1, *below in spec.get("marks", ()):
        past[y0:y1, x0:x1] |= dark_marks(lab[y0:y1, x0:x1, 0], *below)
    for (ax, ay), *poly in spec.get("fields", ()):
        mask = Image.new("1", (W, H), 0)
        ImageDraw.Draw(mask).polygon([tuple(q) for q in poly], fill=1)
        lab[np.asarray(mask, bool)] = lab[ay - 2:ay + 3, ax - 2:ax + 3].mean((0, 1))
        past[np.asarray(mask, bool)] = False       # (drawn: it stays over a hole it crosses)
    for x, reach in spec.get("even", ()):
        lab = even(lab, x, reach)
    for box in spec.get("dodge", ()):
        lab = dodge(lab, *box)
    # (the holes filled before the smoothing and after it: its edge-keeping never sees what was there)
    lab = smooth(heal(lab, past), passes=spec.get("smooth", 2))
    lab = calm_top(tones(heal(lab, past), spec, spec["theme"], ~past), spec["theme"], spec.get("fade", ()))
    idx = quantise(lab, spec["theme"], spec.get("chroma", 0.07), spec.get("hue", 40), spec.get("speck"))
    idx[:TOP_FLAT] = (TOP_INK[spec["theme"]] % len(RAMP[spec["theme"]]))
    if "paper" in spec:                # (what is left of a stain on the bare paper: a few pixels, gone)
        bare = len(RAMP[spec["theme"]]) - 1
        idx[specks(idx != bare, 16)] = bare
    out = Image.fromarray(idx.astype(np.uint8), "P")
    flat = (hexes(PALETTE[spec["theme"]]) * 255).round().astype(np.uint8).flatten().tolist()
    out.putpalette(flat + [0] * (768 - len(flat)))
    if bad := edges(lightness(out)):
        sys.exit(f"build-masters: {name}: paper at its edges — bring the crop in: " + "; ".join(bad))
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / f"{name}.png", optimize=True)
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--sheet")
    ap.add_argument("--spec", default=str(SPEC))
    ap.add_argument("--check", nargs="+", metavar="FILE")
    a = ap.parse_args(argv)
    if a.check:
        bad = 0
        for f in a.check:
            for b in edges(lightness(Image.open(f))):
                print(f"{pathlib.Path(f).stem}: {b}")
                bad += 1
        return 1 if bad else 0
    specs = tomllib.loads(pathlib.Path(a.spec).read_text())
    names = a.names or list(specs)
    made = []
    for n in names:
        if n not in specs:
            sys.exit(f"build-masters: no [{n}] in {a.spec}")
        made.append((n, build(n, specs[n])))
        print(f"{n}: art/masters/out/{n}.png")
    if a.sheet and made:
        tiles = [m.convert("RGB") for _, m in made]
        sheet = Image.new("RGB", (W + 12, (H + 12) * len(tiles)), (60, 60, 60))
        for i, t in enumerate(tiles):
            sheet.paste(t, (6, 6 + i * (H + 12)))
        sheet.save(a.sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
