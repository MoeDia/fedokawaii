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
    crop    = [x, y, w, h]       in the source's pixels, 16:9 (the part that becomes the screen)
    tone    = "keep" | "lacquer" the dark mood's two ways with a print on light paper: kept (a
                                 night print already dark) or as maki-e — the paper black
                                 lacquer, the lines and colours light, as gold on lacquer
    lift    = 0.0                lightness added before the palette (−0.2 … 0.2)
    gain    = 1.0                contrast around the middle before the palette
writes art/masters/out/NAME.png: 640 × 360 pixels, every one a colour of its mood's palette
(an indexed PNG: a few dozen kilobytes) — the screen shows each as 3 × 3 (1920 × 1080; 2 × 2 on
1280 × 720, 4 × 4 on 2560 × 1440, 6 × 6 on 4K: always whole pixels, never smoothed).
--sheet FILE: every picture written, side by side at 1:1 and halved, for the grill.

How: the crop reduced to 640 × 360 in linear light (Lanczos: each pixel the mean of what it
covers, no darkening at edges), its tones set as the table asks, then each pixel given the
nearest colour of the palette in OKLab (lightness counted twice: shapes read by their
values), an ordered dither (Bayer 4 × 4) choosing between the two nearest where a colour falls
between them — the texture of old pixel art, stable from frame to frame, never noise.
Needs Pillow and numpy.
"""
import argparse
import hashlib
import pathlib
import sys
import tomllib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "art/masters/masters.toml"
OUT = ROOT / "art/masters/out"
CACHE = pathlib.Path.home() / ".cache/r27-art"
W, H = 640, 360

# each mood's inks (tools/build-themes.py's roles, the Wada palette): a ramp of neutrals, darkest
# first — the dark mood's sumi and lacquer browns up to ivory, the light mood's ink up to kinari
# paper — and a few accents a strongly coloured part may take, by its hue: vermilion above all.
# Fewer colours than a print has: what pixel art gives up, on purpose
RAMP = {
    "dark": ["111314", "181715", "2d251e", "3c2f22", "4a3826", "65583f", "9a8767", "c5a56e", "d4bf9a", "f1e1b4"],
    "light": ["121b1b", "122625", "586459", "8b917f", "96865e", "d7bc8c", "dfcc9c", "e8e3c2", "f8f3d8"],
}
ACCENT = {
    "dark": ["82241f", "eb5324", "f68c50", "82c1b4"],
    "light": ["953321", "a84222", "cb6336", "00726a", "437742", "006eb8", "e2b540"],
}
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


def reduce(img, crop):
    x, y, w, h = crop
    a = np.asarray(img.convert("RGB").crop((x, y, x + w, y + h)), dtype=np.float64) / 255
    lin = srgb_to_linear(a)
    # (Pillow resizes 8-bit or float images: each channel as a float plane, in linear light)
    planes = [Image.fromarray(lin[..., i].astype(np.float32), "F").resize((W, H), Image.LANCZOS)
              for i in range(3)]
    return np.clip(np.stack([np.asarray(p, dtype=np.float64) for p in planes], -1), 0, 1)


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


def tones(lab, spec, mood):
    """The picture's lightness stretched over its mood's ramp (1st to 99th percentile: a stray
    speck neither black nor white sets nothing), lacquered (inverted) where the table says, its
    contrast and lift as given; colour kept as it was (the accents read it)."""
    L = lab[..., 0]
    lo, hi = np.percentile(L, 1), np.percentile(L, 99)
    n = np.clip((L - lo) / max(hi - lo, 1e-6), 0, 1)
    if spec.get("tone", "keep") == "lacquer":
        n = 1 - n                                                         # the paper black lacquer
    n = np.clip((n - 0.5) * spec.get("gain", 1.0) + 0.5 + spec.get("lift", 0.0), 0, 1)
    ramp = oklab(srgb_to_linear(hexes(RAMP[mood])))
    out = lab.copy()
    out[..., 0] = ramp[0, 0] + n * (ramp[-1, 0] - ramp[0, 0])
    return out


def quantise(lab, mood, chroma=0.07, hue_deg=40, margin=0.1):
    """Each pixel: an accent where it is strongly coloured (chroma over CHROMA) and an accent's
    hue is within HUE_DEG of its own — the nearest such by OKLab —, else a step of the ramp by
    its lightness alone, two neighbouring steps mixed by a 4 × 4 Bayer threshold where it falls
    between them (the old ordered dither: stable, a texture, never noise)."""
    ramp = oklab(srgb_to_linear(hexes(RAMP[mood])))
    acc = oklab(srgb_to_linear(hexes(ACCENT[mood])))
    L = lab[..., 0]
    # the ramp: the step below and the step above, and how far between
    rl = ramp[:, 0]
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
    return np.where(use, len(rl) + best, ramp_idx)


def build(name, spec):
    src = CACHE / spec["source"]
    data = src.read_bytes()
    if hashlib.sha256(data).hexdigest() != spec["sha256"]:
        sys.exit(f"build-masters: {name}: {src} is not the file SOURCES.md names (sha256)")
    img = Image.open(src)
    lin = reduce(img, spec["crop"])
    lab = tones(smooth(oklab(lin)), spec, spec["theme"])
    idx = quantise(lab, spec["theme"], spec.get("chroma", 0.07), spec.get("hue", 40))
    out = Image.fromarray(idx.astype(np.uint8), "P")
    flat = (hexes(PALETTE[spec["theme"]]) * 255).round().astype(np.uint8).flatten().tolist()
    out.putpalette(flat + [0] * (768 - len(flat)))
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / f"{name}.png", optimize=True)
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--sheet")
    ap.add_argument("--spec", default=str(SPEC))
    a = ap.parse_args(argv)
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
