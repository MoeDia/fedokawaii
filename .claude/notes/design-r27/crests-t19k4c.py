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
    # the light mood: a disc and eight rays between two circles, every second one longer
    g = [[disc(x, y, C, C, 5.6) for x in range(N)] for y in range(N)]
    for k in range(8):
        a = k * math.pi / 4
        r0, r1 = 8.2, (12.6 if k % 2 == 0 else 11.0)
        for t in range(0, 101):
            r = r0 + (r1 - r0) * t / 100
            for w in (-0.9, 0, 0.9):
                x = C + r * math.cos(a) - w * math.sin(a)
                y = C + r * math.sin(a) + w * math.cos(a)
                g[round(y)][round(x)] = True
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
        for pic in (moon(), sun()):
            for on in (True, False):
                tiles.append(crest(pic, th, on))
    one = Image.new("RGB", (len(tiles) * 48, 48), (128, 128, 128))
    for i, t in enumerate(tiles):
        one.paste(t, (i * 48 + 2, 2))
    big = one.resize((one.width * 4, one.height * 4), Image.NEAREST)
    sheet = Image.new("RGB", (big.width, big.height + 60), (128, 128, 128))
    sheet.paste(one, (0, 0)); sheet.paste(big, (0, 56))
    sheet.save(sys.argv[1] + "/crests.png")
