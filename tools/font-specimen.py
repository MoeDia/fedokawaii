#!/usr/bin/env python3
"""tools/font-specimen.py — a font laid out the way the desktop would use it, unsmoothed, at the
pixel size it is drawn for, with the numbers that decide "no spacing fault": every printable ASCII
advance (one width for all, or not), the width of kana and kanji against two Latin cells, the
line's height, the ink's top and bottom.

  python3 -I tools/font-specimen.py FONT PX OUT.png [--title T] [--scale N] [--fg RRGGBB --bg RRGGBB]

FONT: a .ttf/.otf file; PX: the pixel size (its em); OUT: the sheet (each pixel a N×N square,
default 3). Prints the numbers; exit 0 · 1 the font cannot be read · 2 misuse.
"""
import sys

from PIL import Image, ImageDraw, ImageFont

LINES = [
    "the quick brown fox jumps over the lazy dog",
    "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
    "0123456789  1/2 3:45 67% 8.9 GB  -+=*",
    "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
    "il1| oO0 rn m vv w ,. ;: '\" `~ <>",
    "Tue 27/10/2026  03:54 AM  wallpaper",
    "volume 40% · brightness 70% · RAM 8% of 30 GB",
    "ひらがな カタカナ 火曜日 東京 日本語",
    "鍵は心にあり  門  音 明 暦 天 電 系",
]


def main(argv):
    args = argv[1:]
    if len(args) < 3 or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if args and args[0] in ("-h", "--help") else 2
    path, px, out = args[0], int(args[1]), args[2]
    opt = lambda n, d: args[args.index(n) + 1] if n in args else d
    scale = int(opt("--scale", "3"))
    fg = tuple(int(opt("--fg", "cfc3a6")[i:i + 2], 16) for i in (0, 2, 4))
    bg = tuple(int(opt("--bg", "0f0e0c")[i:i + 2], 16) for i in (0, 2, 4))
    try:
        font = ImageFont.truetype(path, px)
    except OSError as e:
        print(f"specimen: {path}: {e}", file=sys.stderr)
        return 1
    ascii_adv = {chr(c): font.getlength(chr(c)) for c in range(33, 127)}
    widths = sorted(set(round(v, 2) for v in ascii_adv.values()))
    cell = max(ascii_adv.values())
    kana, kanji = font.getlength("あ"), font.getlength("漢")
    asc, desc = font.getmetrics()
    title = opt("--title", path.rsplit("/", 1)[-1])
    lh = asc + desc + 2
    w = int(max(font.getlength(l) for l in LINES)) + 16
    h = lh * (len(LINES) + 1) + 12
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"                                  # (no smoothing: the pixels as drawn)
    small = ImageFont.truetype(path, px)
    d.text((8, 4), f"{title} · {px} px", font=small, fill=(208, 88, 58))
    for i, line in enumerate(LINES):
        d.text((8, 4 + lh * (i + 1)), line, font=font, fill=fg)
    im = im.resize((w * scale, h * scale), Image.NEAREST)
    im.save(out)
    mono = len(widths) == 1
    print(f"{title}: {px} px · ascii advances {widths if len(widths) <= 6 else str(len(widths)) + ' widths'}"
          f" ({'monospace' if mono else 'PROPORTIONAL'}) · kana {kana:g} kanji {kanji:g}"
          f" ({'= 2 cells' if mono and abs(kanji - 2 * cell) < 0.01 and abs(kana - 2 * cell) < 0.01 else 'not 2 cells'})"
          f" · ascent {asc} descent {desc} · sheet {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
