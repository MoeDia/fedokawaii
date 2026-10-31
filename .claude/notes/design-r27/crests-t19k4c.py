#!/usr/bin/env python3
"""T19k-4 (c) sketch: the mon sheet's crest pictures at 28 px, kamon style (bold one-ink shapes
from geometry, hand-tuned later), inside the 36 px seal — on (vermilion, a paper ring 2 px in,
the picture knocked out in paper) and off (the outline, the picture muted), both themes.
    python3 crests-t19k4c.py OUTDIR   → OUTDIR/crests.png (1× and 4×)"""
import math
import sys
from PIL import Image

N = 28                     # the picture's grid; its ink kept inside a circle 26 across
C = (N - 1) / 2


def disc(x, y, cx, cy, r):
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def moon():
    # a crescent (the dark mood): a disc less a disc set up and right — its horns point right
    return [[disc(x, y, C, C, 11.6) and not disc(x, y, C + 5.0, C - 3.2, 9.6) for x in range(N)] for y in range(N)]


def sun():
    # the light mood: a disc and eight wedge rays — each a polar wedge 3.4 px at its root, 1 px
    # at its tip, rasterised by pixel centres (the diagonals land on the 45° stair, never rounded)
    g = [[disc(x, y, C, C, 5.6) for x in range(N)] for y in range(N)]
    for y in range(N):
        for x in range(N):
            r = math.hypot(x - C, y - C)
            a = math.atan2(y - C, x - C)
            for k in range(8):
                r0, r1 = 7.6, (12.9 if k % 2 == 0 else 11.4)
                if not r0 <= r <= r1:
                    continue
                w = 3.4 + (1.0 - 3.4) * (r - r0) / (r1 - r0)
                d = abs((a - k * math.pi / 4 + math.pi) % (2 * math.pi) - math.pi)
                if r * math.sin(min(d, math.pi / 2)) <= w / 2 and d < math.pi / 2:
                    g[y][x] = True
    return g


def lantern():
    # the night light: a chōchin — an oval of paper (rx 8.6, ry 9.6) whose ribs show as paper
    # lines every third row, a lid and a foot (6 × 2) and the hook above the lid
    g = [[False] * N for _ in range(N)]
    for y in range(N):
        for x in range(N):
            if ((x - C) / 8.6) ** 2 + ((y - C) / 9.6) ** 2 <= 1 and (y - 5) % 3 != 0:
                g[y][x] = True
    for y in (2, 3, 24, 25):
        for x in range(int(C) - 3, int(C) + 5):
            g[y][x] = True
    g[0][13] = g[0][14] = g[1][13] = g[1][14] = True
    return g


THEMES = {"dark": {"ground": "181715", "accent": "eb5324", "key": "25201a", "edge2": "3c2f22", "muted": "9a8767"},
          "light": {"ground": "e8e3c2", "accent": "a84222", "key": "f9f5de", "edge2": "d7bc8c", "muted": "586459"}}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def crest(pic, th, on):
    t = THEMES[th]
    S, R = 44, 18
    im = Image.new("RGB", (S, S), rgb(t["ground"]))
    c = (S - 1) / 2
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - c, y - c)
            if on:
                if d <= R:
                    im.putpixel((x, y), rgb(t["accent"]))
                if R - 3 < d <= R - 2:
                    im.putpixel((x, y), rgb(t["key"]))
            elif R - 1 < d <= R:
                im.putpixel((x, y), rgb(t["edge2"]))
    o = (S - N) // 2
    for y in range(N):
        for x in range(N):
            if pic[y][x]:
                im.putpixel((x + o, y + o), rgb(t["key"] if on else t["muted"]))
    return im


if __name__ == "__main__":
    tiles = []
    for th in ("dark", "light"):
        for pic in (moon(), sun(), lantern()):
            for on in (True, False):
                tiles.append(crest(pic, th, on))
    one = Image.new("RGB", (len(tiles) * 48, 48), (128, 128, 128))
    for i, t in enumerate(tiles):
        one.paste(t, (i * 48 + 2, 2))
    big = one.resize((one.width * 4, one.height * 4), Image.NEAREST)
    sheet = Image.new("RGB", (big.width, big.height + 60), (128, 128, 128))
    sheet.paste(one, (0, 0)); sheet.paste(big, (0, 56))
    sheet.save(sys.argv[1] + "/crests.png")
