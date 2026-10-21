#!/usr/bin/env python3
"""tools/build-ui-font.py — the desktop's UI face, "Sumi UI": Fusion Pixel 12 with its stems doubled.

    python3 tools/build-ui-font.py FUSION_12PX_JA.ttf OUT.ttf

Fusion Pixel 12's strokes are one pixel wide: crisp, but thin to read in the bar and the menus.
Here each straight upright stroke of a letter or digit (one column, three rows or more) is made
two pixels wide — the whole stroke one pixel to its right, or else to its left, or not at all:
only where every pixel it takes is paper with paper beyond it (a one-pixel counter or gap is
never closed: "m", "M", "W" keep their open spaces) and only inside the glyph's own ink box.
Diagonals, dots and horizontals keep their one pixel; signs (# % @ + / ...) and the wide glyphs
(kanji, kana: no pixel to spare) are as drawn. So nothing moves: every glyph keeps its advance
and the left and right edges of its ink, so every width, pad (measured to the ink), seal and
gap of docs/design-system.md §2/§3 stays where it was. All whole pixels: crisp at 12 px and at
its multiples (the lock's clock at 60).

A font of its own name (the SIL Open Font License asks a changed font to carry another), built
when Fusion Pixel is installed (lib/upstream.sh, install_fusion). Needs: python3-fonttools.
"""
import sys
import unicodedata

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import ttProgram

PX = 100        # one pixel of the 12 px grid (1200 units per em)
FAMILY = "Sumi UI"


def raster(g):
    """The glyph's pixels: {row (y of the pixel's bottom, in pixels): set of columns} (nonzero)."""
    coords, ends = list(g.coordinates), g.endPtsOfContours
    edges, s = [], 0
    for e in ends:
        pts = coords[s:e + 1]
        s = e + 1
        for i, (x0, y0) in enumerate(pts):
            x1, y1 = pts[(i + 1) % len(pts)]
            if x0 == x1 and y0 != y1:
                edges.append((x0, min(y0, y1), max(y0, y1), 1 if y1 > y0 else -1))
            elif x0 != x1 and y0 != y1:
                raise ValueError("not a pixel outline")
    rows = {}
    if not edges:
        return rows
    lo = min(e[1] for e in edges) // PX
    hi = -(-max(e[2] for e in edges) // PX)
    for r in range(lo, hi):
        yc = r * PX + PX // 2
        xs = sorted((x, d) for x, a, b, d in edges if a < yc < b)
        wind, on = 0, set()
        for i, (x, d) in enumerate(xs):
            prev = wind
            wind += d
            if prev == 0 and wind != 0:
                start = x
            elif prev != 0 and wind == 0:
                on.update(range(start // PX, x // PX))
        if on:
            rows[r] = on
    return rows


def stems(rows):
    """The straight upright strokes: (column, first row, last row), three rows or more, one
    pixel wide (no ink beside them in those rows)."""
    out = []
    for c in sorted({c for cols in rows.values() for c in cols}):
        r = None
        for y in range(min(rows) - 1, max(rows) + 2):
            cols = rows.get(y, ())
            alone = c in cols
            if alone and r is None:
                r = y
            elif not alone and r is not None:
                if y - r >= 3:
                    out.append((c, r, y - 1))
                r = None
    return out


def embolden(rows):
    """Each stem one pixel heavier, to its right or else its left, the whole stem or none of
    it: only where the pixel taken and the one beyond are paper all along it and in the rows
    just above and below (so no counter, gap or diagonal is closed), inside the ink box."""
    if not rows:
        return rows
    x0 = min(min(c) for c in rows.values())
    x1 = max(max(c) for c in rows.values())
    out = {r: set(cols) for r, cols in rows.items()}
    for c, lo, hi in stems(rows):
        for d in (1, -1):
            n, beyond = c + d, c + 2 * d
            if not x0 <= n <= x1:
                continue
            if all(n in rows[y] or beyond not in rows[y] for y in range(lo, hi + 1)) and \
               sum(n in rows[y] for y in range(lo, hi + 1)) * 2 < hi - lo + 1:
                for y in range(lo, hi + 1):
                    out[y].add(n)
                break
    return out


def rects(rows):
    """The pixels as rectangles: runs in a row, the same run in the rows above merged into it."""
    runs = {}
    for r, cols in rows.items():
        cs = sorted(cols)
        rr, a = [], cs[0]
        for i in range(1, len(cs) + 1):
            if i == len(cs) or cs[i] != cs[i - 1] + 1:
                rr.append((a, cs[i - 1] + 1))
                if i < len(cs):
                    a = cs[i]
        runs[r] = rr
    out, open_ = [], {}
    for r in sorted(runs):
        nxt = {}
        for run in runs[r]:
            if run in open_ and open_[run][1] == r:
                nxt[run] = (open_[run][0], r + 1)
            else:
                nxt[run] = (r, r + 1)
        for run, span in open_.items():
            if nxt.get(run, (None,))[0] != span[0]:
                out.append((run, span))
        open_ = nxt
    out += list(open_.items())
    return out


def main(src, out):
    # the original's metrics kept as they are: its head box is what Pango sizes a line by (a
    # box recomputed from every glyph is taller: a notice grew 4 px)
    f = TTFont(src, recalcBBoxes=False)
    if f["head"].unitsPerEm != 1200:
        sys.exit(f"build-ui-font: {src}: {f['head'].unitsPerEm} units per em, not 1200")
    glyf = f["glyf"]
    # letters and digits only: a sign (# % @ + / ...) is drawn tighter, its strokes meet
    words = {n for cp, n in f.getBestCmap().items() if unicodedata.category(chr(cp))[0] in "LN"}
    for name in f.getGlyphOrder():
        g = glyf[name]
        if g.isComposite():
            sys.exit(f"build-ui-font: {name} is a composite glyph (none expected)")
        if g.numberOfContours <= 0 or name not in words or f["hmtx"][name][0] > 600:
            continue          # a wide glyph (kanji, kana): its strokes have no pixel to spare
        try:
            rows = raster(g)
        except ValueError:
            continue          # not drawn on the grid: kept as it is
        coords, ends, flags = [], [], []
        for (a, b), (y0, y1) in rects(embolden(rows)):
            # clockwise: the outer contour of a TrueType glyph
            coords += [(a * PX, y0 * PX), (a * PX, y1 * PX), (b * PX, y1 * PX), (b * PX, y0 * PX)]
            ends.append(len(coords) - 1)
            flags += [1, 1, 1, 1]
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
    head = f["head"]
    box = head.xMin, head.yMin, head.xMax, head.yMax
    f["maxp"].recalc(f)                  # (which recomputes the head box too: put back)
    head.xMin, head.yMin, head.xMax, head.yMax = box
    f.save(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__.split("\n\n")[1].strip())
    main(sys.argv[1], sys.argv[2])
