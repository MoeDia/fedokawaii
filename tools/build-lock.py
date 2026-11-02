#!/usr/bin/env python3
"""tools/build-lock.py — the lock screen's scenes as the desktop's own pixel art (T20), at the
wallpapers' grid: 640 × 360, shown 3 × 3 on 1080p (2 × 2, 4 × 4 … elsewhere: whole pixels).

    python3 tools/build-lock.py [--preview DIR]

dark: a dungeon wall lit by two torches — each stone one tone, the light pooling stone by stone —,
a stone lintel with the quote carved and gilded in it (「鍵は心にあり」, the key is in the heart:
Sumi UI at its own pixels), and between the torches the Hannya mask (Ritsuō's Noh mask, the Met:
art/masters/SOURCES.md) on its round stone plate, its lip lit from above, its shadow on the wall;
the password is typed in its open mouth. The flames are 8 frames (8 fps, a second's loop), drawn
over the scene by the lock's module: a teardrop that sways and breathes, an ember now and then.
(light: the Willow Kannon's scene — next.)

Writes art/lock/out/lock-dark.png (indexed) and flame-dark.png (8 frames side by side, 18 × 30
each, transparent around the flame); prints where the mouth is on a 1080p screen. --preview DIR:
the scene with the first frame at 3 × 3 and the frames at 8 × 8. Needs Pillow and numpy.
"""
import argparse
import hashlib
import importlib.util
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "art/lock/out"
CACHE = pathlib.Path.home() / ".cache/r27-art"
FONT = pathlib.Path("/usr/local/share/fonts/fedokawaii/SumiUI.ttf")     # (theme.sh installs it)
_spec = importlib.util.spec_from_file_location("build_masters", ROOT / "tools/build-masters.py")
bm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bm)

W, H = 640, 360
BAY = bm.BAYER + 0.5                                   # (0 … 15/16)
QUOTE = "鍵は心にあり"
MASK = ("hannya-mask.jpg", "1bb6dda639aa74e2f8ee0f4f79885628a21dd0961bbdbd04f7469da422dc3d1d")
TORCH_X, FLAME_Y = (106, 534), 112                     # the flames' middles
CX, CY, RD, RIM = 320, 189, 132, 5                     # the plate: its middle, the picture's radius, its lip
LINTEL = (248, 391, 13, 41)                            # x0 x1 y0 y1
FW, FH, FRAMES = 18, 30, 8                             # a flame's frame


def inks(mood):
    return {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))
            for k, v in bm._P[mood].items() if isinstance(v, str) and len(v) == 6}


def torchlight(x, y):
    return sum(1.0 / (1 + ((x - tx) ** 2 + ((y - FLAME_Y) * 1.15) ** 2) / 1900.0) for tx in TORCH_X)


def ramp_at(v, ramp, x, y):
    """v in 0…1 → one of the ramp's inks, ordered-dithered between the two nearest."""
    f = v * (len(ramp) - 1) + BAY[y % 4, x % 4] - 0.5
    return ramp[int(min(max(round(f), 0), len(ramp) - 1))]


def disc_of(path, sha, d):
    """The mask's round plate from the source: its circle at d × d in the dark mood's inks."""
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != sha:
        sys.exit(f"build-lock: {path} is not the file art/masters/SOURCES.md names (sha256)")
    src = Image.open(path)
    scx, scy, sr = 0.502 * src.width, 0.540 * src.height, 0.378 * src.width
    crop = [int(scx - sr), int(scy - sr), int(2 * sr), int(2 * sr)]
    bm.W, bm.H = d, d
    lab = bm.tones(bm.smooth(bm.oklab(bm.reduce(src, crop))), {"tone": "keep", "lift": 0.05}, "dark")
    idx = bm.quantise(lab, "dark", 0.07, 40)
    pal = (bm.hexes(bm.PALETTE["dark"]) * 255).round().astype(np.uint8)
    # the open mouth (SOURCES.md: x50–67 % y61–71 % of the source) in the disc's pixels
    mouth = ((0.50 * src.width - crop[0]) / crop[2] * d, (0.61 * src.height - crop[1]) / crop[3] * d,
             (0.67 * src.width - crop[0]) / crop[2] * d, (0.71 * src.height - crop[1]) / crop[3] * d)
    return Image.fromarray(pal[idx], "RGB"), mouth


def ring(cx, cy, r0, r1):
    for y in range(int(cy - r1 - 1), int(cy + r1 + 2)):
        for x in range(int(cx - r1 - 1), int(cx + r1 + 2)):
            r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r0 <= r < r1:
                yield x, y, r


def dark_scene():
    P = inks("dark")
    img = Image.new("RGB", (W, H))
    px = img.load()
    rng = np.random.default_rng(7)
    # 1 the wall: staggered blocks 24 × 12, 1 px mortar; each stone ONE tone — the light at its
    # middle and its own shade —, its top row a step lit where the torches reach, its foot a step
    # dark: the pools of light read stone by stone (no dither across a stone)
    bw, bh = 24, 12
    shade = rng.normal(0, 0.05, (H // bh + 2, W // bw + 2))
    wall = [P["ground"], P["edge"], P["edge2"], P["hi"], P["art_umber"]]
    for y in range(H):
        row = y // bh
        off = bw // 2 if row % 2 else 0
        for x in range(W):
            if y % bh == bh - 1 or (x + off) % bw == bw - 1:
                px[x, y] = P["lo"]
                continue
            col = (x + off) // bw
            light = min(torchlight(col * bw - off + bw / 2, row * bh + bh / 2), 1.0)
            i = int(min(max((0.06 + 1.10 * light + 0.9 * shade[row, col]) * (len(wall) - 1), 0), len(wall) - 1))
            if y % bh == 0 and light > 0.18:
                i = min(i + 1, len(wall) - 1)
            if y % bh == bh - 2 and i > 0:
                i -= 1
            px[x, y] = wall[i]
    d = ImageDraw.Draw(img)
    # 2 the lintel: one stone over the plate, lit from above (its top and left a step light, its
    # foot and right a step dark, a grain pixel here and there), the quote cut in it and gilded:
    # each stroke gold, its shadow a pixel under and right
    x0, x1, y0, y1 = LINTEL
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = (P["hi"] if y == y0 or x == x0 else P["edge"] if y == y1 or x == x1
                        else P["edge"] if rng.random() < 0.06 else P["edge2"])
    d.rectangle([x0 - 1, y0 - 1, x1 + 1, y1 + 1], outline=P["lo"])
    font = ImageFont.truetype(str(FONT), 14)
    text = Image.new("1", (16 * len(QUOTE) + 8, 20), 0)
    td = ImageDraw.Draw(text)
    td.fontmode = "1"
    for i, ch in enumerate(QUOTE):
        td.text((16 * i, 0), ch, font=font, fill=1)
    text = text.crop(text.getbbox())
    gx, gy = (x0 + x1 + 1 - text.width) // 2, (y0 + y1 + 1 - text.height) // 2
    on = [(x, y) for y in range(text.height) for x in range(text.width) if text.getpixel((x, y))]
    for x, y in on:
        px[gx + x + 1, gy + y + 1] = P["lo"]
    for x, y in on:
        px[gx + x, gy + y] = P["gold"]
    # 3 the plate: its shadow on the wall (the torches are above it), its thickness under its foot,
    # its lip (lit from above, a groove inside, rounding away outside), then the mask in the circle
    stone = [P["lo"], P["ground"], P["edge"], P["edge2"], P["hi"]]
    for x, y, _ in ring(CX, CY + 7, 0, RD + RIM + 4):
        c = px[x, y]
        px[x, y] = stone[max((stone.index(c) if c in stone else 1) - 1, 0)]
    for x, y, _ in ring(CX, CY + 4, 0, RD + RIM):
        px[x, y] = P["lo"] if (x + y) % 2 else P["ground"]
    for x, y, r in ring(CX, CY, RD, RD + RIM):
        a = math.atan2(y + 0.5 - CY, x + 0.5 - CX)
        v = 0.45 - 0.30 * math.sin(a) + 0.10 * abs(math.cos(a))
        if r >= RD + RIM - 1:
            v -= 0.25
        if r < RD + 1:
            v -= 0.20
        px[x, y] = ramp_at(min(max(v, 0), 0.999), stone[1:], x, y)
    disc, mouth = disc_of(CACHE / MASK[0], MASK[1], 2 * RD)
    cut = Image.new("L", disc.size, 0)
    ImageDraw.Draw(cut).ellipse([0, 0, disc.width - 1, disc.height - 1], fill=255)
    img.paste(disc, (CX - RD, CY - RD), cut)
    # 4 the sconces: an iron plate on the wall (lit edges, four rivets), a wooden haft through an
    # iron ring, its head wrapped and pitch-soaked (the flame sits on it)
    iron, iron_hi, wood, wood_hi = P["edge2"], P["hi"], P["art_umber"], P["art_olive"]
    for tx in TORCH_X:
        d.rectangle([tx - 5, 134, tx + 4, 156], fill=P["lo"])
        d.rectangle([tx - 4, 135, tx + 3, 155], fill=iron)
        d.line([(tx - 4, 135), (tx + 3, 135)], fill=iron_hi)
        d.line([(tx - 4, 135), (tx - 4, 155)], fill=iron_hi)
        d.point([(tx - 2, 137), (tx + 1, 137), (tx - 2, 153), (tx + 1, 153)], fill=P["lo"])
        d.rectangle([tx - 2, 116, tx + 1, 146], fill=wood)
        d.line([(tx - 2, 116), (tx - 2, 146)], fill=wood_hi)
        for yy in (124, 132, 140):
            d.line([(tx - 2, yy), (tx + 1, yy)], fill=P["edge"])
        d.rectangle([tx - 4, 127, tx + 3, 130], fill=P["lo"])
        d.rectangle([tx - 3, 128, tx + 2, 129], fill=iron)
        d.line([(tx - 3, 128), (tx + 2, 128)], fill=iron_hi)
        d.rectangle([tx - 3, 112, tx + 2, 117], fill=P["edge"])
        d.line([(tx - 3, 112), (tx + 2, 112)], fill=P["accent_lo"])
    mouth = tuple(round(3 * v) for v in (CX - RD + mouth[0], CY - RD + mouth[1], CX - RD + mouth[2], CY - RD + mouth[3]))
    return img, mouth


def flames(P):
    """8 frames of a torch flame: four nested teardrops (deep red, vermilion, orange, the cream
    core), the tip swaying more than the foot, the body breathing; an ember off the tip twice."""
    layers = [(P["accent_lo"], 1.00, 0.00), (P["accent"], 0.80, 0.08), (P["flame"], 0.60, 0.30),
              (P["strong"], 0.40, 0.55)]
    strip = Image.new("RGBA", (FW * FRAMES, FH), (0, 0, 0, 0))
    sp = strip.load()
    base = FH - 2
    for f in range(FRAMES):
        ph = 2 * math.pi * f / FRAMES
        h = 25 + round(1.6 * math.sin(ph + 1.1))
        hw = 6.4 + 0.6 * math.sin(2 * ph)
        sway = 1.9 * math.sin(ph)
        for col, kw, kh in layers:
            top = base - h + kh * h
            for y in range(FH):
                if not top <= y <= base:
                    continue
                t = (y - top) / max(base - top, 1)              # 0 at the tip, 1 at the foot
                half = kw * hw * math.sqrt(t) * (1 - 0.55 * t ** 4)
                mid = FW / 2 + sway * (1 - t) ** 2
                for x in range(FW):
                    if abs(x + 0.5 - mid) < half:
                        sp[f * FW + x, y] = col + (255,)
        if f in (2, 5):
            sp[f * FW + int(FW / 2 + 1.5 * sway), max(base - h - 2 - (f == 5), 0)] = P["flame"] + (255,)
    return strip


def main():
    ap = argparse.ArgumentParser(description="the lock screen's scenes (T20)")
    ap.add_argument("--preview", type=pathlib.Path, help="also write the 3 × 3 previews here")
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    scene, mouth = dark_scene()
    strip = flames(inks("dark"))
    scene.convert("P", palette=Image.ADAPTIVE, colors=64).save(OUT / "lock-dark.png", optimize=True)
    strip.save(OUT / "flame-dark.png", optimize=True)
    print("dark: the mouth on a 1080p screen x0 y0 x1 y1:", *mouth)
    if a.preview:
        a.preview.mkdir(parents=True, exist_ok=True)
        prev = scene.copy()
        one = strip.crop((0, 0, FW, FH))
        for tx in TORCH_X:
            prev.paste(one, (tx - FW // 2, 115 - FH + 2), one)
        prev.resize((3 * W, 3 * H), Image.NEAREST).save(a.preview / "lock-dark-3x.png")
        strip.resize((8 * FW * FRAMES, 8 * FH), Image.NEAREST).save(a.preview / "flame-dark-8x.png")


if __name__ == "__main__":
    main()
