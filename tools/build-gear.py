#!/usr/bin/env python3
"""tools/build-gear.py — quick settings' gear on the bar (d4): a brass gear of eight teeth, the chest fittings' brass
(P3 kanagu, tools/build-themes.py BRASS), its hub a rivet at rest and the vermilion seal's ink while it turns.

    python3 tools/build-gear.py [--sheet DIR]

    themes/MOOD/gear.png        16 × 160: the gear at rest on rows 0–15
    themes/MOOD/gear-turn.png   16 × 160: four poses of a turning gear, 40 rows apart (a tooth is 45°, a pose
                                11.25° on): style.css steps the picture up 40 rows a pose, so the tile's 20 rows of
                                paper only ever hold one

Each pose is drawn from the gear's outline at 8 × 8 samples a pixel, a pixel inked when half of it is brass: the
teeth's flanks stay one-pixel stairs at every pose. The light from the upper left (the lit rim), the shade lower
right, the outline in the shade's ink. --sheet DIR: every pose of both moods at 1× and 8× on the tile's paper.
Needs Pillow.
"""
import argparse
import math
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
THEMES = ROOT / "configs/home/.config/fedokawaii/themes"
AIR = (0, 0, 0, 0)
# (lit, body, shade, rivet): build-themes.py BRASS; the hub turning: the mood's accent; the tile's paper (sheet only)
BRASS = {"dark": ("d6c09a", "c5a56e", "746346", "111314"), "light": ("ebcb79", "e2b540", "957d38", "f8f3d8")}
HUB = {"dark": "eb5324", "light": "a84222"}
PAPER = {"dark": "25201a", "light": "f9f5de"}
SIZE, POSES, PITCH = 16, 4, 40
TEETH, R_TIP, R_ROOT, R_HOLE = 8, 8.0, 5.4, 1.9
TOOTH_TIP, TOOTH_ROOT = 0.50, 0.70        # the tooth's half-width at the tip and the root, as a share of its 45°


def rgba(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def brass(x, y, turn):
    """Is the point (x, y) (pixels from the gear's centre) on the gear turned by `turn` radians?"""
    r = math.hypot(x, y)
    if r <= R_HOLE or r > R_TIP:
        return False
    if r <= R_ROOT:
        return True
    pitch = 2 * math.pi / TEETH
    a = (math.atan2(y, x) - turn) % pitch - pitch / 2         # the angle from the nearest tooth's middle
    half = TOOTH_ROOT + (TOOTH_TIP - TOOTH_ROOT) * (r - R_ROOT) / (R_TIP - R_ROOT)
    return abs(a) <= half * pitch / 2


def mask(turn):
    c, n = SIZE / 2, 8
    out = set()
    for py in range(SIZE):
        for px in range(SIZE):
            hit = sum(brass(px + (i + 0.5) / n - c, py + (j + 0.5) / n - c, turn) for i in range(n) for j in range(n))
            if hit * 2 >= n * n:
                out.add((px, py))
    return out


def pose(turn, mood, turning):
    lit, body, shade, rivet = (rgba(v) for v in BRASS[mood])
    m = mask(turn)
    img = Image.new("RGBA", (SIZE, SIZE), AIR)
    for x, y in m:
        edge = any((x + dx, y + dy) not in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        r = math.hypot(x + 0.5 - SIZE / 2, y + 0.5 - SIZE / 2)
        if edge and r > R_HOLE + 1.2:                          # the outer outline (the hole's rim is the hub's)
            ink = shade
        elif (x + 0.5 - SIZE / 2) + (y + 0.5 - SIZE / 2) < -2.5 and r > R_ROOT - 2.2:
            ink = lit                                         # the lit upper left of the wheel and its teeth
        else:
            ink = body
        img.putpixel((x, y), ink)
    # the hub: a rivet ring round the hole at rest, the seal's ink while it turns (its four pixels round the middle)
    for x, y in ((7, 6), (8, 6), (6, 7), (9, 7), (6, 8), (9, 8), (7, 9), (8, 9)):
        img.putpixel((x, y), rgba(HUB[mood]) if turning else shade)
    for x, y in ((7, 7), (8, 7), (7, 8), (8, 8)):
        img.putpixel((x, y), rgba(HUB[mood]) if turning else rivet)
    return img


def strip(poses):
    img = Image.new("RGBA", (SIZE, PITCH * POSES), AIR)
    for k, p in enumerate(poses):
        img.paste(p, (0, k * PITCH))
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--sheet", type=pathlib.Path)
    a = ap.parse_args()
    sheet = []
    for mood in ("dark", "light"):
        turn = [pose(k * 2 * math.pi / TEETH / POSES, mood, True) for k in range(POSES)]
        rest = pose(0, mood, False)
        strip([rest]).save(THEMES / mood / "gear.png", optimize=True)
        strip(turn).save(THEMES / mood / "gear-turn.png", optimize=True)
        sheet.append((mood, [rest, *turn]))
    if a.sheet:
        a.sheet.mkdir(parents=True, exist_ok=True)
        z, gap = 8, 4
        w = (SIZE + gap) * 5
        out = Image.new("RGBA", (w * (z + 1), (SIZE + gap) * 2 * z), AIR)
        for row, (mood, poses) in enumerate(sheet):
            band = Image.new("RGBA", (w * (z + 1), (SIZE + gap) * z), rgba(PAPER[mood]))
            out.paste(band, (0, row * (SIZE + gap) * z))
            for k, p in enumerate(poses):
                out.paste(p, (k * (SIZE + gap) + 2, row * (SIZE + gap) * z + 2), p)
                big = p.resize((SIZE * z, SIZE * z), Image.NEAREST)
                out.paste(big, (w + k * (SIZE + gap) * z, row * (SIZE + gap) * z + gap * z // 2), big)
        out.save(a.sheet / "gear-sheet.png")


if __name__ == "__main__":
    main()
