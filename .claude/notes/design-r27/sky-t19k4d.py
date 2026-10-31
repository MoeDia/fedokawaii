#!/usr/bin/env python3
"""T19k-4 (d): the bar's weather as pictures — 14 × 14, a few inks of the palette (design-system
§13 lets the weather's pictures have more than one), laid on the weather tile's paper like the
face. Letters: S sun's disc, h its sheen, R its rays, M moon, T star, C cloud, O its edge, H its
shade, D rain, F snow, B lightning, G fog; '.' the paper.
    python3 sky-t19k4d.py OUT.png"""
import sys
from PIL import Image, ImageDraw, ImageFont

SKY = {
"clear": """
......RR......
.R....RR....R.
..R........R..
.....SSSS.....
....hSSSSS....
...hSSSSSSS...
RR.SSSSSSSS.RR
RR.SSSSSSSS.RR
...SSSSSSSS...
....SSSSSS....
.....SSSS.....
..R........R..
.R....RR....R.
......RR......
""",
"clear-night": """
...MMMM.......
..MMMM........
.MMMM......T..
.MMM......TTT.
MMMM.......T..
MMMM..........
MMMM..........
MMMMM.........
MMMMM.........
.MMMMM.......M
.MMMMMMM...MMM
..MMMMMMMMMMM.
...MMMMMMMMM..
.....MMMMM....
""",
"partly": """
...R..........
.R...SSS......
....SSSSS.....
...SSSSSSS....
R..SSSSOOO....
...SSSOCCCO...
....SOCCCCCOO.
.R..OCCCCCCCCO
...OCCCCCCCCCO
..OCCCCCCCCCCO
..OCCCCCCCCCCO
..OHHHHHHHHHHO
...OOOOOOOOOO.
..............
""",
"partly-night": """
..............
...MMM.....T..
..MMM.....TTT.
.MMM.......T..
.MMM...OOO....
MMM...OCCCO...
MMM..OCCCCCOO.
MMMMOCCCCCCCCO
.MMOCCCCCCCCCO
..OCCCCCCCCCCO
..OCCCCCCCCCCO
..OHHHHHHHHHHO
...OOOOOOOOOO.
..............
""",
"cloud": """
..............
..............
......OOO.....
.....OCCCO....
..OOOCCCCCOO..
.OCCCCCCCCCCO.
.OCCCCCCCCCCCO
OCCCCCCCCCCCCO
OCCCCCCCCCCCCO
OHHHHHHHHHHHHO
.OOOOOOOOOOOO.
..............
..............
..............
""",
"fog": """
......OOO.....
.....OCCCO....
..OOOCCCCCOO..
.OCCCCCCCCCCO.
OCCCCCCCCCCCCO
OHHHHHHHHHHHHO
.OOOOOOOOOOOO.
..............
.GGGGGGGGGG...
..............
...GGGGGGGGGG.
..............
.GGGGGG.GGGG..
..............
""",
"rain": """
......OOO.....
.....OCCCO....
..OOOCCCCCOO..
.OCCCCCCCCCCO.
OCCCCCCCCCCCCO
OCCCCCCCCCCCCO
OHHHHHHHHHHHHO
.OOOOOOOOOOOO.
..............
..D....D....D.
.D....D....D..
..............
...D....D.....
..D....D......
""",
"snow": """
......OOO.....
.....OCCCO....
..OOOCCCCCOO..
.OCCCCCCCCCCO.
OCCCCCCCCCCCCO
OCCCCCCCCCCCCO
OHHHHHHHHHHHHO
.OOOOOOOOOOOO.
..............
..F.....F.....
.FFF...FFF..F.
..F.....F..FFF
.....F......F.
....FFF.......
""",
"storm": """
......OOO.....
.....OCCCO....
..OOOCCCCCOO..
.OCCCCCCCCCCO.
OCCCCCCCCCCCCO
OCCCCCCBBCCCCO
OHHHHHBBHHHHHO
.OOOOBBOOOOOO.
....BBBBB.....
.......BB.....
......BB......
.....BB.......
.....B........
..............
""",
}

INK = {
    "dark": {"S": "eb5324", "h": "f1713b", "R": "e2b540", "M": "e2b540", "T": "fbe6a0", "C": "f1e1b4",
             "O": "d4bf9a", "H": "9a8767", "D": "a7d4e4", "F": "f1e1b4", "B": "e2b540", "G": "9a8767"},
    "light": {"S": "a84222", "h": "cb6336", "R": "986f2d", "M": "986f2d", "T": "986f2d", "C": "e8e3c2",
              "O": "586459", "H": "8b917f", "D": "006eb8", "F": "006eb8", "B": "986f2d", "G": "8b917f"},
}
TILE = {"dark": "25201a", "light": "f9f5de"}
TEXT = {"dark": "d4bf9a", "light": "122625"}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def pic(name, th):
    rows = SKY[name].strip("\n").split("\n")
    assert len(rows) == 14 and all(len(r) == 14 for r in rows), (name, [len(r) for r in rows])
    im = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                im.putpixel((x, y), rgb(INK[th][c]) + (255,))
    return im


def tile(name, th, font):
    """the weather tile: 20 rows of paper, the picture on rows 3–16 from column 8, 28° after"""
    im = Image.new("RGB", (60, 20), rgb(TILE[th]))
    im.paste(pic(name, th), (8, 3), pic(name, th))
    d = ImageDraw.Draw(im)
    d.text((30, 3), "28°", fill=rgb(TEXT[th]), font=font)
    return im


if __name__ == "__main__":
    font = ImageFont.truetype("/home/dia/repos/fedokawaii/system/fonts/SumiUI.ttf", 14)
    names = list(SKY)
    row = []
    out = Image.new("RGB", (len(names) * 64, 2 * 24), (128, 128, 128))
    for k, n in enumerate(names):
        for j, th in enumerate(("dark", "light")):
            out.paste(tile(n, th, font), (k * 64 + 2, j * 24 + 2))
    big = out.resize((out.width * 3, out.height * 3), Image.NEAREST)
    z = Image.new("RGB", (len(names) * 20 * 8, 2 * 20 * 8), (128, 128, 128))
    for k, n in enumerate(names):
        for j, th in enumerate(("dark", "light")):
            t = Image.new("RGB", (18, 18), rgb(TILE[th]))
            t.paste(pic(n, th), (2, 2), pic(n, th))
            z.paste(t.resize((18 * 8, 18 * 8), Image.NEAREST), (k * 160 + 8, j * 160 + 8))
    sheet = Image.new("RGB", (max(big.width, z.width), big.height + z.height + 8), (128, 128, 128))
    sheet.paste(big, (0, 0)); sheet.paste(z, (0, big.height + 8))
    sheet.save(sys.argv[1])
