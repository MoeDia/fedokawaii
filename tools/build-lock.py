#!/usr/bin/env python3
"""tools/build-lock.py — the lock screen's scenes as the desktop's own pixel art (T20), at the
wallpapers' grid: 640 × 360, shown 3 × 3 on 1080p (2 × 2, 4 × 4 … elsewhere: whole pixels).

    python3 tools/build-lock.py [--preview DIR]

dark: a dungeon wall lit by two torches — each stone one tone, the light pooling stone by stone —,
a stone lintel with the quote carved and gilded in it (口は禍の門, the mouth is the gate of
misfortune — design-system §0: Sumi UI at its own pixels), and between the torches the Hannya mask
(Ritsuō's Noh mask, the Met: art/masters/SOURCES.md) on its round stone plate, its lip lit from
above, its shadow on the wall; its open mouth a dark gate where the password glows, ember by ember.
The flames are 8 frames (8 fps, a second's loop), drawn over the scene by the lock's module
(src/kawa-lockmod): a teardrop that sways and breathes, an ember now and then.
light: a room of pale gold leaf (16 × 16 leaves, hairline seams, a fleck of gold here and there)
lit by two hanging chōchin, the quote in sumi on a wooden plaque with its red seal, and between the
lanterns a round window (marumado) in a wooden ring: through it Seiōbo, the Queen Mother of the
West (Kōgyo's Noh print, AIC: SOURCES.md), her masked face, her crown and the peach she offers;
the quote 言わぬが花 (better left unsaid); the password, mote by mote, in the window's calm sky
beside the peach.

Writes, for theme.sh to install, configs/home/.local/share/fedokawaii/MOOD/lock-scene.png (indexed)
and lock-scene.txt — where the module draws on it (the flames, the password's row, their inks) —
and dark/lock-flame.png (8 frames side by side, 18 × 30 each, transparent around the flame).
--preview DIR: each scene at 3 × 3 (the dark one with the first frame and six embers), the frames
at 8 × 8. Needs Pillow and numpy.
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
OUT = ROOT / "configs/home/.local/share/fedokawaii"
CACHE = pathlib.Path.home() / ".cache/r27-art"
FONT = pathlib.Path("/usr/local/share/fonts/fedokawaii/SumiUI.ttf")     # (theme.sh installs it)
_spec = importlib.util.spec_from_file_location("build_masters", ROOT / "tools/build-masters.py")
bm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bm)

W, H = 640, 360
BAY = bm.BAYER + 0.5                                   # (0 … 15/16)
QUOTES = {"dark": "口は禍の門", "light": "言わぬが花"}       # (design-system §0: proverbs about keeping words in)
MASK = ("hannya-mask.jpg", "1bb6dda639aa74e2f8ee0f4f79885628a21dd0961bbdbd04f7469da422dc3d1d")
SEIOBO = ("seiobo-noh.jpg", "c1d9bdd680571b492a095be35d4c524dfd9977e7d40ec7ee433891e3e8cac5bb")
TORCH_X, FLAME_Y = (106, 534), 112                     # the flames' middles
CX, CY, RD, RIM = 320, 189, 132, 5                     # the plate: its middle, the picture's radius, its lip
LINTEL = (248, 391, 13, 41)                            # x0 x1 y0 y1
FW, FH, FRAMES = 18, 30, 8                             # a flame's frame
FLAME_TOP = 87                                         # its frame's top (the flame stands on the haft's head)
GATE = (314, 364, 222, 7.0)                            # the mouth: its lens x0 x1, middle row, half height
GATE_PITCH, GATE_N = 5, 7                              # embers 5 px apart, the newest 7 in sight (the caret the 8th)


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
    return Image.fromarray(pal[idx], "RGB")


def ring(cx, cy, r0, r1):
    for y in range(int(cy - r1 - 1), int(cy + r1 + 2)):
        for x in range(int(cx - r1 - 1), int(cx + r1 + 2)):
            r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r0 <= r < r1:
                yield x, y, r


def lettered(quote):
    """The quote in Sumi UI at its own pixels (14 px a character, 2 px apart), cropped to its ink."""
    font = ImageFont.truetype(str(FONT), 14)
    text = Image.new("1", (16 * len(quote) + 8, 20), 0)
    td = ImageDraw.Draw(text)
    td.fontmode = "1"
    for i, ch in enumerate(quote):
        td.text((16 * i, 0), ch, font=font, fill=1)
    return text.crop(text.getbbox())


def gate(img, P):
    """The open mouth made a dark gate: from its middle row up and down while the lacquer's red
    goes on — the teeth stop it —, inside a lens that bounds it at the corners: the throat in the
    darkest ink, a step lighter by the teeth, deep red where it meets them. → (x, y) of the first
    ember's middle; the row holds GATE_N, GATE_PITCH apart."""
    px = img.load()
    red = {P["accent"], P["accent_lo"], P["flame"]}
    xl, xr, ym, hh = GATE
    for x in range(xl, xr + 1):
        if px[x, ym] not in red:
            continue
        t = min(max((x + 0.5 - xl) / (xr - xl), 0.0), 1.0)
        half = hh * math.sin(math.pi * t) ** 0.55
        top = bot = ym
        while top - 1 >= ym - half and px[x, top - 1] in red:
            top -= 1
        while bot + 1 <= ym + half and px[x, bot + 1] in red:
            bot += 1
        for y in range(top, bot + 1):
            e = min(y - top, bot - y)
            px[x, y] = P["accent_lo"] if e == 0 else P["ground"] if e == 1 else P["lo"]
    return xl + 6, ym


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
    text = lettered(QUOTES["dark"])
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
    disc = disc_of(CACHE / MASK[0], MASK[1], 2 * RD)
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
    return img, gate(img, P)


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


def lanternlight(x, y):
    return sum(1.0 / (1 + ((x - tx) ** 2 + ((y - LAMP_Y) * 1.15) ** 2) / 2200.0) for tx in TORCH_X)


LAMP_Y = 118                                           # the lanterns' middles (at the torches' x)


def window_of(path, sha, d):
    """Seiōbo through the round window: the circle on her face, crown and peach, at d × d in the
    light mood's inks."""
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != sha:
        sys.exit(f"build-lock: {path} is not the file art/masters/SOURCES.md names (sha256)")
    src = Image.open(path)
    cx, cy, r = 0.605 * src.width, 0.345 * src.height, 0.205 * src.width
    crop = [int(cx - r), int(cy - r), int(2 * r), int(2 * r)]
    bm.W, bm.H = d, d
    lab = bm.tones(bm.smooth(bm.oklab(bm.reduce(src, crop)), passes=3), {"tone": "keep", "lift": 0.0}, "light")
    idx = bm.quantise(lab, "light", 0.07, 40)
    pal = (bm.hexes(bm.PALETTE["light"]) * 255).round().astype(np.uint8)
    return Image.fromarray(pal[idx], "RGB")


def light_scene():
    P = inks("light")
    img = Image.new("RGB", (W, H))
    px = img.load()
    rng = np.random.default_rng(11)
    # 1 gold leaf: 16 × 16 leaves, a hairline seam where two overlap, each leaf one tone — its own
    # shade and the lanterns' light —, the tones close (leaf, not tiles); now and then a fleck of gold
    leaf = [P["edge"], P["ground"], P["view"], P["key"]]
    lw = 16
    shade = np.clip(rng.normal(0, 0.035, (H // lw + 2, W // lw + 2)), -0.05, 0.05)
    def tone(r, c):
        v = 0.30 + 0.70 * min(lanternlight(c * lw + lw / 2, r * lw + lw / 2), 1.0) + shade[r, c]
        return int(min(max(v * len(leaf), 0), len(leaf) - 1))
    for y in range(H):
        for x in range(W):
            i = tone(y // lw, x // lw)
            if y % lw == 0 or x % lw == 0:
                px[x, y] = leaf[max(i - 1, 0)] if i else P["edge2"]   # (a seam: a step under its leaf)
                continue
            px[x, y] = leaf[i]
            if rng.random() < 0.0025:
                px[x, y] = P["gold"]
    d = ImageDraw.Draw(img)
    # 2 the plaque: a wooden frame, its paper, the quote in sumi, the seal in our red at its end
    text = lettered(QUOTES["light"])
    x0, x1, y0, y1 = LINTEL
    d.rectangle([x0 - 2, y0 - 2, x1 + 2, y1 + 2], fill=P["lo"])
    d.rectangle([x0 - 1, y0 - 1, x1 + 1, y1 + 1], fill=P["edge2"])
    d.rectangle([x0, y0, x1, y1], fill=P["key"])
    d.line([(x0, y1), (x1, y1)], fill=P["edge"])
    # (the words and the seal after them, 6 px apart, centred together on the plaque)
    gx, gy = (x0 + x1 + 1 - (text.width + 6 + 8)) // 2, (y0 + y1 + 1 - text.height) // 2
    for y in range(text.height):
        for x in range(text.width):
            if text.getpixel((x, y)):
                px[gx + x, gy + y] = P["strong"]
    sx = gx + text.width + 6
    d.rectangle([sx, gy + text.height - 8, sx + 7, gy + text.height - 1], fill=P["accent"])   # the seal
    # 3 the round window: its shadow on the leaf, a wooden ring (lit above, a groove inside),
    # Seiōbo through it
    for x, y, _ in ring(CX, CY + 5, 0, RD + RIM + 3):
        c = px[x, y]
        px[x, y] = leaf[max((leaf.index(c) if c in leaf else 1) - 1, 0)]
    wood = [P["muted"], P["lo"], P["edge2"]]
    for x, y, r in ring(CX, CY, RD, RD + RIM):
        a = math.atan2(y + 0.5 - CY, x + 0.5 - CX)
        v = 0.55 - 0.40 * math.sin(a)
        if r >= RD + RIM - 1 or r < RD + 1:
            v -= 0.35
        px[x, y] = ramp_at(min(max(v, 0), 0.999), wood, x, y)
    pic = window_of(CACHE / SEIOBO[0], SEIOBO[1], 2 * RD)
    cut = Image.new("L", pic.size, 0)
    ImageDraw.Draw(cut).ellipse([0, 0, pic.width - 1, pic.height - 1], fill=255)
    img.paste(pic, (CX - RD, CY - RD), cut)
    # 4 two chōchin on their cords: a lacquered cap and foot, ribbed paper lit from inside, our red
    # mark on it
    for tx in TORCH_X:
        d.line([(tx, 0), (tx, LAMP_Y - 23)], fill=P["muted"])
        d.rectangle([tx - 6, LAMP_Y - 23, tx + 5, LAMP_Y - 20], fill=P["strong"])
        for yy in range(LAMP_Y - 19, LAMP_Y + 20):
            t = (yy - (LAMP_Y - 19)) / 38
            hw = 6 + 5 * math.sin(math.pi * t)
            for xx in range(int(tx - hw), int(tx + hw) + 1):
                px[xx, yy] = P["edge"] if (yy - LAMP_Y) % 5 == 0 else P["key"]
            px[int(tx - hw), yy] = px[int(tx + hw), yy] = P["edge2"]
        d.rectangle([tx - 6, LAMP_Y + 20, tx + 5, LAMP_Y + 23], fill=P["strong"])
        d.rectangle([tx - 2, LAMP_Y - 6, tx + 1, LAMP_Y + 5], fill=P["accent"])
    # the password's row: the window's calm sky, right of her crown and over the peach
    return img, (CX + 46, CY - 75)


def hexof(c):
    return "%02x%02x%02x" % c


def placed(mood, row, P, plate, flame_x=()):
    """lock-scene.txt: where the module draws on the scene, in the scene's own pixels."""
    marks = {"dark": (P["flame"], P["strong"], P["accent_lo"], P["asagi"], P["flame"]),
             "light": (P["yellow"], P["gold"], P["edge2"], P["asagi"], P["yellow"])}[mood]
    lines = ["# lock-scene.txt — where kawa-lockmod draws on lock-scene.png, in its pixels (each shown",
             "# N × N on the screen, N whole: the most the screen holds). tools/build-lock.py writes it.",
             f"size {W} {H}",
             f"ground {hexof(P['lo'] if mood == 'dark' else P['ground'])}   # round the scene",
             f"frames {FW} {FH} {FRAMES}   # lock-flame.png: the frames side by side, 8 a second"]
    lines += [f"flame {x - FW // 2} {FLAME_TOP}   # a flame's frame, its top-left" for x in flame_x]
    lines += [f"row {row[0]} {row[1]} {GATE_PITCH} {GATE_N}   # the password: the first mark's middle, the pitch, how many in sight",
              "mark {} {} {}   # a mark: its arms, its middle, its corners".format(*map(hexof, marks[:3])),
              f"caps {hexof(marks[3])}   # the arms while Caps Lock is on",
              f"caret {hexof(marks[4])}   # a bar 1 × 5 at the next place, once a second",
              "plate {} {} {}   # what shakes at a wrong password: its middle, its radius".format(*plate)]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description="the lock screen's scenes (T20)")
    ap.add_argument("--preview", type=pathlib.Path, help="also write the 3 × 3 previews here")
    a = ap.parse_args()
    for mood in ("dark", "light"):
        (OUT / mood).mkdir(parents=True, exist_ok=True)
    scene, row = dark_scene()
    strip = flames(inks("dark"))
    scene.convert("P", palette=Image.ADAPTIVE, colors=64).save(OUT / "dark/lock-scene.png", optimize=True)
    strip.save(OUT / "dark/lock-flame.png", optimize=True)
    (OUT / "dark/lock-scene.txt").write_text(placed("dark", row, inks("dark"), (CX, CY, RD + RIM + 1), TORCH_X))
    light, lrow = light_scene()
    light.convert("P", palette=Image.ADAPTIVE, colors=64).save(OUT / "light/lock-scene.png", optimize=True)
    (OUT / "light/lock-scene.txt").write_text(placed("light", lrow, inks("light"), (CX, CY, RD + RIM + 1)))
    if a.preview:
        a.preview.mkdir(parents=True, exist_ok=True)
        prev = scene.copy()
        one = strip.crop((0, 0, FW, FH))
        for tx in TORCH_X:
            prev.paste(one, (tx - FW // 2, FLAME_TOP), one)
        pp = prev.load()
        arms, core, corner = inks("dark")["flame"], inks("dark")["strong"], inks("dark")["accent_lo"]
        for i in range(6):
            x, y = row[0] + GATE_PITCH * i, row[1]
            for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
                pp[x + dx, y + dy] = corner
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                pp[x + dx, y + dy] = arms
            pp[x, y] = core
        prev.resize((3 * W, 3 * H), Image.NEAREST).save(a.preview / "lock-dark-3x.png")
        strip.resize((8 * FW * FRAMES, 8 * FH), Image.NEAREST).save(a.preview / "flame-dark-8x.png")
        light.resize((3 * W, 3 * H), Image.NEAREST).save(a.preview / "lock-light-3x.png")


if __name__ == "__main__":
    main()
