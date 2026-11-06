#!/usr/bin/env python3
"""tools/menu-options.py — the sheet of Super+U and Super+R tightened (r28 f14): each window cropped at 1:1 from the kit's
shots, real foot (tools/menu-options.mock), today's from the real menus; dark and light side by side.

    python3 tools/menu-options.py SHOTS U.jpg R.jpg     (SHOTS/dark, SHOTS/light: system books u1 u2 r1 r2 .png)
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

FONT = ImageFont.truetype("/usr/local/share/fonts/fedokawaii/SumiUI.ttf", 14)
SHEETS = ([("system", "Super+U now"), ("u1", "1 ichimai"), ("u2", "2 daifuku")],
          [("books", "Super+R now"), ("r1", "1 hon"), ("r2", "2 okuzuke")])
BACK = (32, 30, 27)
INK = (231, 207, 161)
GAP = 16


def crop(path):
    """The window: everything off the ground below the bar."""
    im = Image.open(path).convert("RGB")
    ground = Image.new("RGB", (1920, 1040), im.getpixel((960, 1070)))
    x0, y0, x1, y1 = ImageChops.difference(im.crop((0, 40, 1920, 1080)), ground).getbbox()
    return im.crop((x0, y0 + 40, x1, y1 + 40))


def sheet_of(shots, rows, out):
    cells = {(m, n): crop(f"{shots}/{m}/{n}.png") for m in ("dark", "light") for n, _ in rows}
    for (m, n), im in cells.items():
        print(m, n, im.size)
    w = 2 * max(i.width for i in cells.values()) + 3 * GAP
    h = sum(cells[("dark", n)].height + 20 + GAP for n, _ in rows) + GAP
    sheet = Image.new("RGB", (w, h), BACK)
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    y, half = GAP, (w - GAP) // 2
    for n, label in rows:
        im = cells[("dark", n)]
        d.text((GAP, y), f"{label}   {im.width} x {im.height}", font=FONT, fill=INK)
        y += 20
        sheet.paste(im, (half - im.width, y))
        sheet.paste(cells[("light", n)], (half + GAP, y))
        y += im.height + GAP
    for q in range(88, 49, -2):                    # the page takes 300 KB
        sheet.save(out, quality=q, subsampling=0, optimize=True)
        if os.path.getsize(out) <= 300_000:
            break
    print(out, sheet.size, "q", q, os.path.getsize(out))


if __name__ == "__main__":
    for rows, out in zip(SHEETS, sys.argv[2:]):
        sheet_of(sys.argv[1], rows, out)
