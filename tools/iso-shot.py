#!/usr/bin/env python3
"""tools/iso-shot.py — what the installer's console says, read from a screenshot, exactly.

    python3 -I -B tools/iso-shot.py PNG FONT.psf            the screen's text, row by row
    python3 -I -B tools/iso-shot.py PNG FONT.psf "WORDS"    exit 0 when those words are on the screen

The console draws our own bitmap font on a fixed grid, so nothing here guesses: every cell's pixels
either are a glyph of the font (ink against the cell's ground) or the screen is not ours; a cell of
the Private Use Area reads as its code point's tile, "▪". Exit: 0 yes · 1 no · 2 misuse.
"""
import struct
import sys

from PIL import Image


def font(path):
    """{glyph bits: first code point} from a PSF2 with a Unicode table."""
    b = open(path, "rb").read()
    head = struct.unpack("<4B7I", b[:32])
    size, n, per, height, width = head[5], head[7], head[8], head[9], head[10]
    data = b[size:size + n * per]
    table = b[size + n * per:]
    rows = (width + 7) // 8
    out = {}
    for i, entry in enumerate(table.split(b"\xff")[:n]):
        bits = data[i * per:(i + 1) * per]
        if not entry or bits in out:
            continue
        out[bits] = entry.decode("utf-8", "replace")[0]
    return width, height, rows, out


def read(png, psf):
    w, h, rows, glyphs = font(psf)
    im = Image.open(png).convert("RGB")
    px = im.load()
    lines = []
    for r in range(im.height // h):
        line = []
        for c in range(im.width // w):
            x0, y0 = c * w, r * h
            cell = [[px[x0 + x, y0 + y] for x in range(w)] for y in range(h)]
            colours = {}
            for row in cell:
                for v in row:
                    colours[v] = colours.get(v, 0) + 1
            if len(colours) > 2:          # (not a character cell of this font)
                line.append("?")
                continue
            ground = max(colours, key=colours.get)
            best = None
            for inverted in (False, True):        # (a glyph with more ink than ground, say the solid tile)
                if inverted and len(colours) != 2:
                    continue
                g = min(colours, key=colours.get) if inverted else ground
                bits = bytearray()
                for row in cell:
                    v = 0
                    for p in row:
                        v = (v << 1) | (p != g)
                    bits += (v << (rows * 8 - w)).to_bytes(rows, "big")
                best = glyphs.get(bytes(bits))
                if best is not None:
                    break
            if best is None:
                line.append("?")
            elif ord(best) >= 0xE000:
                line.append("▪")
            else:
                line.append(best)
        lines.append("".join(line).rstrip())
    return lines


def main():
    if len(sys.argv) not in (3, 4):
        sys.stderr.write(__doc__)
        sys.exit(2)
    lines = read(sys.argv[1], sys.argv[2])
    if len(sys.argv) == 3:
        print("\n".join(line for line in lines if line.strip()))
        return
    sys.exit(0 if any(sys.argv[3] in line for line in lines) else 1)


main()
