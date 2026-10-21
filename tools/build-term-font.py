#!/usr/bin/env python3
"""tools/build-term-font.py — the terminal's face, "Sumi Term": Fusion Pixel 10 one step heavier.

    python3 tools/build-term-font.py FUSION_10PX_JA.ttf OUT.ttf

Fusion Pixel's strokes are one pixel of its 10 px grid: at the terminal's 20 px, two screen
pixels — thin on a dark ground at reading distance. Each glyph here is the same drawing laid
over itself half a font pixel to the right (50 of its 1000 units): at 20 px every upright
stroke is three screen pixels wide instead of two, the horizontal ones as they were, every
edge still on whole screen pixels (crisp: no smoothing, 60-fedokawaii-pixel.conf). Nothing
moves or changes width — each glyph keeps its advance, the second copy is held inside it, so
a letter never reaches into the next cell. At 40 px (a screen at scale 2) the same, doubled.

First, the letters a terminal gives one cell but Fusion Pixel draws two cells wide — arrows,
dashes, the ellipsis, triangles, box lines, ① and the like: East Asian "ambiguous" or
"neutral" width, drawn for Japanese text — are drawn into their one cell, half as wide (each
font pixel one screen pixel across at 20 px, still whole): drawn two wide they ran over the
letter after them (btop's ▼ over its numbers, ↑ over "select", a footer's arrow over the
next word). A kanji, a kana, a full-width form — two cells to a terminal too — keep theirs.

A font of its own name (the original's is its authors'; the SIL Open Font License asks a
changed font to carry another), built when Fusion Pixel is installed (lib/upstream.sh,
install_fusion) from the pinned face. Needs: python3-fonttools.
"""
import sys
import unicodedata

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import ttProgram

SHIFT = 50  # half a pixel of the 10 px grid (1000 units per em, 100 a pixel)
FAMILY = "Sumi Term"


def main(src, out):
    f = TTFont(src)
    if f["head"].unitsPerEm != 1000:
        sys.exit(f"build-term-font: {src}: {f['head'].unitsPerEm} units per em, not 1000")
    glyf, hmtx = f["glyf"], f["hmtx"]
    # the glyphs a terminal gives one cell that are drawn two cells wide (and no wide letter
    # shares them)
    half, keep = set(), set()
    for cp, name in f.getBestCmap().items():
        (keep if unicodedata.east_asian_width(chr(cp)) in "WF" else half).add(name)
    half = {n for n in half - keep if hmtx[n][0] == 1000}
    for name in half:
        g = glyf[name]
        if g.numberOfContours > 0:
            g.coordinates = type(g.coordinates)([(x // 2, y) for x, y in g.coordinates])
        hmtx[name] = (500, hmtx[name][1] // 2)
    for name in f.getGlyphOrder():
        g = glyf[name]
        if g.isComposite():
            sys.exit(f"build-term-font: {name} is a composite glyph (none expected)")
        if g.numberOfContours <= 0:
            continue
        adv = hmtx[name][0]
        coords = list(g.coordinates)
        ends = list(g.endPtsOfContours)
        flags = list(g.flags)
        n = len(coords)
        coords += [(min(x + SHIFT, max(adv, x)), y) for x, y in coords]
        ends += [e + n for e in ends]
        flags += flags
        g.coordinates = type(g.coordinates)(coords)
        g.endPtsOfContours = ends
        g.numberOfContours = len(ends)
        g.flags = type(g.flags)(flags)
        g.program = ttProgram.Program()
        g.program.fromBytecode(b"")  # (no hinting: the font is drawn unhinted)
        g.recalcBounds(glyf)
    names = f["name"]
    for rec in list(names.names):
        if rec.nameID in (1, 16):
            rec.string = FAMILY
        elif rec.nameID == 4:
            rec.string = FAMILY + " Regular"
        elif rec.nameID == 6:
            rec.string = FAMILY.replace(" ", "") + "-Regular"
        elif rec.nameID == 3:
            rec.string = FAMILY + ": built from " + str(rec.toUnicode())
    f["maxp"].recalc(f)
    f.save(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__.split("\n\n")[1].strip())
    main(sys.argv[1], sys.argv[2])
