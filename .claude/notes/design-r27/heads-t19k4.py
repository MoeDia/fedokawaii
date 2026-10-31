#!/usr/bin/env python3
"""T19k-4 sketch: the bar's mood face as multi-ink pixel art (dark: the hannya, after Hokusai's
Warai Hannya; light: the tennin) on the end tile's paper. Grids: '.' the tile shows through,
K sumi, W ivory, G gold, D lacquer (the mouth), R the tile's own red a step deeper.
    python3 heads-t19k4.py OUTDIR      → OUTDIR/heads.png (1× on the bar's tile + 10× zoom)"""
import sys
from PIL import Image

INK = {"dark": {"tile": "eb5324", "K": "111314", "W": "f1e1b4", "G": "e2b540", "D": "82241f", "R": "b8401f"},
       "light": {"tile": "a84222", "K": "111314", "W": "f8f3d8", "G": "e2b540", "D": "5e1a16", "R": "82241f"}}

HANNYA = """
..G............G..
.GG............GG.
.GG...KKKKKK...GG.
.GGGKKKKKKKKKKGGG.
..GGKKKKWWKKKKGG..
..KKKKKWWWWKKKKK..
..KWKKWWWWWWKKWK..
..KWWWKKWWKKWWWK..
..KWGGGWWWWGGGWK..
..KWWGKWWWWKGWWK..
..KKWWWKWWKWWWKK..
..KWKKKKKKKKKKWK..
..KWKWDDDDDDWKWK..
..KWKDWDDDDWDKWK..
..KWKKKKKKKKKKWK..
...KWWWWWWWWWWK...
....KWWWWWWWWK....
.....KKKKKKKK.....
"""

TENNIN = """
......GGGGGG......
....GG..KK..GG....
...G...KGGK...G...
..G...KKKKKK...G..
.G...KKKKKKKK...G.
.G..KKKKKKKKKK..G.
G..KKKKWWWWKKKK..G
G..KKWWWWWWWWKK..G
G..KKWWWDDWWWKK..G
G..KWWWWWWWWWWK..G
.G.KWKKKWWKKKWK.G.
.G.KWWWWWWWWWWK.G.
..GKWWWWWWWWWWKG..
...KWWWWWWWWWWK...
...KKWWWDDWWWKK...
...KKWWWWWWWWKK...
...KK.KWWWWK.KK...
...KK..KKKK..KK...
"""


HANNYA_OPEN = """
..G............G..
.GG............GG.
.GG...KKKKKK...GG.
.GGGKKKKKKKKKKGGG.
..GGKKKKWWKKKKGG..
..KKKKKWWWWKKKKK..
..KWKKWWWWWWKKWK..
..KWWWKKWWKKWWWK..
..KWGGGWWWWGGGWK..
..KWWGGWWWWGGWWK..
..KKWWWKWWKWWWKK..
..KWKKKKKKKKKKWK..
..KWKWDDDDDDWKWK..
..KWKDDDDDDDDKWK..
..KWKDWDDDDWDKWK..
...KKKKKKKKKKKK...
....KWWWWWWWWK....
.....KKKKKKKK.....
"""

TENNIN_OPEN = """
......GGGGGG......
....GG..KK..GG....
...G...KGGK...G...
..G...KKKKKK...G..
.G...KKKKKKKK...G.
.G..KKKKKKKKKK..G.
G..KKKKWWWWKKKK..G
G..KKWWWWWWWWKK..G
G..KKWWWDDWWWKK..G
G..KWWWWWWWWWWK..G
.G.KWKGKWWKGKWK.G.
.G.KWWWWWWWWWWK.G.
..GKWWWWWWWWWWKG..
...KWWWWWWWWWWK...
...KKWWDWWDWWKK...
...KKWWWDDWWWKK...
...KK.KWWWWK.KK...
...KK..KKKK..KK...
"""


def grid(t):
    return [r for r in t.strip("\n").split("\n")]


def draw(g, inks, scale):
    h, w = len(g), len(g[0])
    im = Image.new("RGB", (w + 6, h + 2), "#" + inks["tile"])
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != ".":
                im.putpixel((x + 3, y + 1), tuple(int(inks[c][i:i + 2], 16) for i in (0, 2, 4)))
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


if __name__ == "__main__":
    out = sys.argv[1]
    heads = [("dark", HANNYA), ("dark", HANNYA_OPEN), ("light", TENNIN), ("light", TENNIN_OPEN)]
    tiles = []
    for th, art in heads:
        g = grid(art)
        assert all(len(r) == len(g[0]) for r in g), [len(r) for r in g]
        tiles += [draw(g, INK[th], 1), draw(g, INK[th], 8)]
    W = sum(t.width for t in tiles) + 20 * len(tiles)
    H = max(t.height for t in tiles)
    sheet = Image.new("RGB", (W, H), "#181715")
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 20
    sheet.save(f"{out}/heads.png")
