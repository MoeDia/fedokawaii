#!/usr/bin/env python3
"""tools/build-fonts.py — the desktop's two faces, from the classic Japanese dot fonts.

    python3 tools/build-fonts.py SHINONOME16B.ttf KAPPA20B.ttf UNIFONT_JP.otf

Writes (committed, so an install needs neither the sources nor Python's fontTools; setup.sh
puts them in /usr/local/share/fonts/fedokawaii, for every account — the login screen too):
    system/fonts/SumiUI.ttf     "Sumi UI": bar, panels, menus, launcher, notices, lock and
        login — 東雲 (Shinonome) Gothic 16 Bold: a 16 px line, an 8 px cell (a kanji or kana
        16), capitals 13 px tall
    system/fonts/SumiTerm.ttf   "Sumi Term": the terminals — Kappa 20 Bold (kterm's face):
        a 20 px line, a 10 px cell (a kanji or kana 20), capitals 14 px tall

Both are drawn for their one size and nothing else: every pixel of the source becomes one
square of the outline, 100 units a pixel, so at 16 px (Sumi UI) and 20 px (Sumi Term) — and
at their whole multiples, the lock's clock — each lands on one screen pixel (never smoothed:
system/60-fedokawaii-pixel.conf). The sources are the JF Dot outlines of the bitmap fonts
(jfdotfont-20150527.zip, SHA-256 below: public domain, as the Shinonome and Kappa fonts
they draw) and GNU Unifont JP 17.0.05 (SIL OFL 1.1), read here pixel by pixel at their own
size:
    https://ftp.iij.ad.jp/pub/osdn.jp/users/8/8542/jfdotfont-20150527.zip
        8e574faaaa7e27294aec66464aaf427447b2f0ccec8fe00c50e69bbf509f14b1
        → JF-Dot-Shinonome16B.ttf, JF-Dot-Kappa20B.ttf
    https://unifoundry.com/pub/unifont/unifont-17.0.05/font-builds/unifont_jp-17.0.05.otf
        5f20737a09f40c3f0b7511e6c657e48ca1f683e02f0bc0b9565a3c363827a887

What each face takes from where:
  · its letters, digits and signs (ASCII), and every wide character (kanji, kana, the
    full-width forms) — the face's own drawing;
  · five ASCII signs the face draws the old Japanese way (JIS X 0201: ~ as an overline, \\ as
    the yen sign, ' and " curled, ` as an opening quote): redrawn for code — ' and " straight,
    \\ the face's own / mirrored, ~ a wave on the minus's row, ` a straight grave;
  · everything a terminal gives one cell that the face draws two cells wide or not at all
    (arrows, ·, —, …, °, ×, ●, ◆, ✓, box lines, accented letters, Greek, Cyrillic): Unifont's
    8 × 16 drawing, made one pixel bolder to the right as the face's bold is (never closing a
    one-pixel gap; box lines and blocks as drawn, so they still meet), on the face's baseline.
So a character is one cell exactly when the terminal and kawa-panel count it as one (East
Asian width W and F: two; every other: one), and nothing reaches into the next cell.

Needs: python3-fonttools, python3-pillow.
"""
import pathlib
import sys
import unicodedata

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables import ttProgram
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "system/fonts"
PX = 100                                    # units a pixel

# the faces: their size, cell, rows above the baseline (asc) and below (desc), the row of
# the baseline in a picture Pillow draws at y 0 (its own ascent), and the hand-drawn signs
FACES = {
    "ui": dict(family="Sumi UI", file="SumiUI.ttf", size=16, cell=8, asc=14, desc=2, base=14),
    "term": dict(family="Sumi Term", file="SumiTerm.ttf", size=20, cell=10, asc=17, desc=3, base=18),
}
# the signs, drawn on the face's grid (row 0 = the line's top, as Pillow draws it), regular
# weight: made bold as the Unifont additions are. "~" sits on the minus's row (found below).
HAND = {
    "ui": {
        "'": (0, ["...#....", "...#....", "...#....", "...#...."]),
        '"': (0, ["..#.#...", "..#.#...", "..#.#...", "..#.#..."]),
        "`": (1, ["..#.....", "...#....", "....#..."]),
        "~": (None, [".##.....", "#..#..#.", ".....##."]),
    },
    "term": {
        "'": (3, ["....#.....", "....#.....", "....#.....", "....#.....", "....#....."]),
        '"': (3, ["..#...#...", "..#...#...", "..#...#...", "..#...#...", "..#...#..."]),
        "`": (3, ["...#......", "....#.....", ".....#...."]),
        "~": (None, ["..##......", ".#..#.....", ".....#..#.", "......##.."]),   # (4 rows: a home's ~ read at a glance)
    },
}
# Unifont's characters taken: Latin, Greek, Cyrillic, and the signs, arrows, shapes and
# lines of U+2000–U+2BFF; never what the face draws wide (W, F) itself
BLOCKS = [(0x00A0, 0x024F), (0x0370, 0x03FF), (0x0400, 0x045F), (0x1E00, 0x1EFF),
          (0x2000, 0x2BFF)]
NO_BOLD = [(0x2500, 0x259F), (0x2800, 0x28FF)]   # box lines, blocks, braille: as drawn


def signs(kind, cell):
    """art/signs.txt: "= SIGN FACE ROW" and the drawing under it, in Pillow's rows."""
    out, cur = {}, None
    for n, line in enumerate((ROOT / "art/signs.txt").read_text().splitlines(), 1):
        if not line or line.startswith("# ") or line == "#":   # (a drawing's line has no space)
            cur = None
            continue
        if line.startswith("= "):
            sign, face, row = line[2:].split()
            cur = (sign, int(row)) if face == kind else None
            if cur:
                out[sign] = set()
            continue
        if cur is None:
            continue
        if len(line) != cell or set(line) - {"#", "."}:
            sys.exit(f"build-fonts: art/signs.txt:{n}: not {cell} of '#' and '.'")
        sign, row = cur
        out[sign] |= {(x, row) for x, v in enumerate(line) if v == "#"}
        cur = (sign, row + 1)
    return out


def wide(ch):
    return unicodedata.east_asian_width(ch) in ("W", "F")


def picture(font, ch, w, h):
    """The character as Pillow draws it from y 0, pixel for pixel: a set of (x, y)."""
    im = Image.new("1", (w, h), 0)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((0, 0), ch, font=font, fill=1)
    px = im.load()
    return {(x, y) for y in range(h) for x in range(w) if px[x, y]}


def bolder(pix, width):
    """One pixel more to the right of each, as the faces' bold is made — except where it
    would close a one-pixel gap (paper with ink just beyond) or leave the cell."""
    out = set(pix)
    for x, y in pix:
        n = (x + 1, y)
        if n in pix or x + 1 >= width:
            continue
        if (x + 2, y) in pix:
            continue
        out.add(n)
    return out


def rectangles(pix):
    """Runs of a row merged down while the run below is the same: non-overlapping boxes."""
    rows = {}
    for x, y in pix:
        rows.setdefault(y, set()).add(x)
    runs = {}
    for y, xs in rows.items():
        xs = sorted(xs)
        r, s = [], xs[0]
        for a, b in zip(xs, xs[1:] + [None]):
            if b != a + 1:
                r.append((s, a + 1))
                if b is not None:
                    s = b
        runs[y] = r
    boxes, open_ = [], {}
    for y in sorted(runs) + [None]:
        cur = set(runs.get(y, [])) if y is not None else set()
        for run in list(open_):
            if run not in cur or y != open_[run][1]:
                y0, y1 = open_.pop(run)
                boxes.append((run[0], y0, run[1], y1))
        for run in cur:
            if run in open_:
                open_[run] = (open_[run][0], y + 1)
            else:
                open_[run] = (y, y + 1)
    return boxes


def outline(pix, base):
    pen = TTGlyphPen(None)
    for x0, y0, x1, y1 in rectangles(pix):
        L, R = x0 * PX, x1 * PX
        T, B = (base - y0) * PX, (base - y1) * PX
        pen.moveTo((L, B)); pen.lineTo((L, T)); pen.lineTo((R, T)); pen.lineTo((R, B))
        pen.closePath()
    return pen.glyph()


def build(kind, face_path, unifont_path):
    c = FACES[kind]
    size, cell, asc, desc, base = c["size"], c["cell"], c["asc"], c["desc"], c["base"]
    top = base - asc                    # the first row of the line in Pillow's picture
    face = ImageFont.truetype(face_path, size)
    uni = ImageFont.truetype(unifont_path, 16)
    fcm = TTFont(face_path, lazy=True).getBestCmap()
    ucm = TTFont(unifont_path, lazy=True).getBestCmap()

    def in_line(pix, adv):
        bad = [(x, y) for x, y in pix if not (0 <= x < adv and top <= y < base + desc)]
        return not bad

    glyphs = {}                         # codepoint → (advance in px, pixels in Pillow rows)
    # 1. the face: ASCII and every wide character it draws
    for cp in fcm:
        ch = chr(cp)
        if 0x21 <= cp <= 0x7E or (wide(ch) and cp >= 0x2E80) or 0xFF61 <= cp <= 0xFF9F:
            adv = 2 * cell if wide(ch) else cell
            pix = picture(face, ch, adv + 2, base + desc + 2)
            pix = {(x, y) for x, y in pix if x < adv}
            if not in_line(pix, adv):
                sys.exit(f"build-fonts: {c['family']}: U+{cp:04X} leaves its cell")
            glyphs[cp] = (adv, pix)
    # 2. the five signs, by hand
    minus = sorted({y for x, y in glyphs[ord("-")][1]})
    mid = minus[len(minus) // 2]
    for ch, (row, art) in HAND[kind].items():
        if row is None:
            row = mid - len(art) // 2
        pix = {(x, row + i) for i, line in enumerate(art) for x, v in enumerate(line) if v == "#"}
        glyphs[ord(ch)] = (cell, bolder(pix, cell))
    slash = glyphs[ord("/")][1]
    xs = [x for x, _ in slash]
    lo, hi = min(xs), max(xs)
    glyphs[ord("\\")] = (cell, {(lo + hi - x, y) for x, y in slash})
    # 3. Unifont: what one cell holds that the face has not drawn one cell wide
    dx = (cell - 8) // 2                # Unifont's 8 px in the cell, centred
    dy = base - 14                      # its baseline (row 14) on the face's
    for a, b in BLOCKS:
        for cp in range(a, b + 1):
            ch = chr(cp)
            if cp not in ucm or wide(ch) or cp in glyphs:
                continue
            cat = unicodedata.category(ch)
            if cat.startswith(("M", "C", "Z")) and cp not in (0x00A0, 0x202F):
                continue
            if uni.getlength(ch) != 8:  # Unifont draws it two cells wide: not one cell's
                continue
            pix = picture(uni, ch, 10, 18)
            pix = {(x + dx, y + dy) for x, y in pix if x < 8}
            if not any(a2 <= cp <= b2 for a2, b2 in NO_BOLD):
                pix = bolder(pix, cell)
            if not in_line(pix, cell):
                continue                # taller than the line (a few stacked accents): left out
            glyphs[cp] = (cell, pix)
    # 4. the signs the desktop shows, drawn for this face (art/signs.txt): over the rest
    for ch, rows in signs(kind, cell).items():
        glyphs[ord(ch)] = (cell, rows)
    glyphs[0x20] = (cell, set())
    glyphs[0x3000] = (2 * cell, set())
    if 0xA0 in ucm:
        glyphs[0xA0] = (cell, set())

    # the font
    order = [".notdef"] + [f"u{cp:04X}" for cp in sorted(glyphs)]
    fb = FontBuilder(size * PX, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({cp: f"u{cp:04X}" for cp in glyphs})
    nd = {(x, y) for y in range(base - asc + 1, base) for x in range(1, cell - 1)
          if x in (1, cell - 2) or y in (base - asc + 1, base - 1)}
    gl = {".notdef": outline(nd, base)}
    met = {".notdef": (cell * PX, 0)}
    for cp, (adv, pix) in glyphs.items():
        gl[f"u{cp:04X}"] = outline(pix, base)
        met[f"u{cp:04X}"] = (adv * PX, 0)
    fb.setupGlyf(gl)
    glyf = fb.font["glyf"]
    for n in order:                     # lsb = the ink's left edge (FreeType's reference)
        g = glyf[n]
        g.recalcBounds(glyf)
        met[n] = (met[n][0], g.xMin if g.numberOfContours else 0)
    fb.setupHorizontalMetrics(met)
    A, D = asc * PX, -desc * PX
    fb.setupHorizontalHeader(ascent=A, descent=D, lineGap=0)
    fam = c["family"]
    fb.setupNameTable({
        "familyName": fam, "styleName": "Bold", "uniqueFontIdentifier": fam + " Bold",
        "fullName": fam + " Bold", "psName": fam.replace(" ", "") + "-Bold", "version": "Version 2.0",
        "copyright": ("Shinonome Gothic 16 Bold" if kind == "ui" else "Kappa 20 Bold")
        + " (public domain, via JF Dot fonts 2015-05-27) and GNU Unifont JP 17.0.05 "
        "(SIL Open Font License 1.1); this font under the SIL Open Font License 1.1.",
        "licenseDescription": "SIL Open Font License 1.1",
        "licenseInfoURL": "https://openfontlicense.org",
    })
    xh = sorted({y for x, y in glyphs[ord("x")][1]})
    cap = sorted({y for x, y in glyphs[ord("H")][1]})
    fb.setupOS2(sTypoAscender=A, sTypoDescender=D, sTypoLineGap=0, usWinAscent=A,
                usWinDescent=-D, sxHeight=(base - xh[0]) * PX, sCapHeight=(base - cap[0]) * PX,
                achVendID="SUMI", fsType=0, xAvgCharWidth=cell * PX,
                usWeightClass=700, fsSelection=0x20)
    # The face is bold (both sources are the Bold cuts) and says so: a toolkit asking for
    # bold (a GTK button, <b> in a notification) finds it as it is, and fontconfig's
    # 90-synthetic.conf never smears it a pixel wider — its only face serves regular too.
    fb.setupPost(isFixedPitch=1)
    fb.setupHead(unitsPerEm=size * PX, fontRevision=2.0, macStyle=1)
    fpgm = newTable("fpgm")             # "hinted by itself": FreeType's autohinter keeps out
    fpgm.program = ttProgram.Program()
    fpgm.program.fromAssembly(["SVTCA[0]"])
    fb.font["fpgm"] = fpgm
    gasp = newTable("gasp")             # never smoothed, whatever the program asks
    gasp.version = 1
    gasp.gaspRange = {0xFFFF: 0}
    fb.font["gasp"] = gasp
    OUT.mkdir(parents=True, exist_ok=True)
    fb.save(str(OUT / c["file"]))
    return len(glyphs)


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__.split("\n\n")[1])
    shinonome, kappa, unifont = argv
    for kind, src in (("ui", shinonome), ("term", kappa)):
        n = build(kind, src, unifont)
        print(f"{FACES[kind]['family']}: {n} characters → {OUT / FACES[kind]['file']}")


if __name__ == "__main__":
    main(sys.argv[1:])
